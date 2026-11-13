--[[
  Lot DEPENSES2 (4/11, demande du DC au QCM-4/11-SUITE : « Dépenses du stock dormant [...] et investir en recherche, armement ») :
  le stock qui DORT s'investit. Règle PURE (aucune API Factorio, aucun nom d'objet : matières opaques données par le runtime ;
  tests/depenses2_test.lua). Diagnostic : fo-logs/2026-11-04_DEPENSES2/RAPPORT.md.

  1. EXCÉDENT d'une matière = stock libre HORS BESOIN évalué − max(Dp.FLOOR, Dp.H_SEUIL × production par minute) ; une matière dont le
     besoin n'est pas couvert n'a aucun excédent (rien sous la réserve). Elle DORT après Dp.N_DORT ticks d'excédent d'un seul tenant.
  2. Ordre (décision du lead, 4/11) : la DÉFENSE des sites sensibles d'abord, sur sa DEMANDE (want, écrite par le périmètre), au plus
     Dp.DEF_PCT % de l'excédent de chaque matière, ou tout l'excédent d'une matière « défense seule » (matière brute : la pierre des
     murs) ; puis la RECHERCHE prend le reste des plaques : laboratoires de plus (un par Dp.LAB_PLATES, au plus Dp.LABS_MAX) ; puis
     l'armement (ce qui reste, rendu au journal).
  3. Interrupteur : inp.on faux -> rien, horloges oubliées. Un relevé manqué (plus de Dp.GAP ticks depuis le précédent) oublie les
     horloges : le sommeil doit être continu (revue DEPENSES2, D5).
  4. Revue DEPENSES2 (D1, BLOQUANT) : la cible de laboratoires est ABSOLUE, jamais relative au nombre présent (« nombre actuel + n » relevait
     la cible à chaque laboratoire posé, sans fin) : Dp.labs_target fige la BASE (laboratoires présents quand la recherche commence à
     recevoir le stock qui dort), vise base + n, jamais au-delà d'un plafond donné par l'appelant ; Dp.engaged débite les laboratoires
     encore à faire (Dp.LAB_COST plaques chacun) pour que la capitalisation ne dépense pas les mêmes plaques (D2).
  5. Armement (D3) : ce qui reste après les laboratoires relève la cible d'armée des factions, Dp.SOLDIER_PLATES plaques par soldat de
     plus, au plus Dp.SOLDIERS_MAX, jamais au-delà du plafond de soldats (Dp.soldiers, cible ABSOLUE elle aussi).
  6. Essai 3 (preuve de l'essai 2, C4 : Azur perd l'âge 2 dans 2 parties sur 4, son centre attendait 60 circuits pendant que la règle lui
     faisait fabriquer 4 laboratoires de 10 circuits) : le CENTRE D'ABORD. Tant que le centre est le but courant ou payable (inp.hold),
     la règle ne demande ni laboratoire ni soldat ; la défense reste servie. Essai 4 (accord du lead) : seuls les laboratoires sont
     retenus, les soldats passent (la part de la recherche va à l'armement pendant l'attente). La cible de laboratoires est MONOTONE pendant un sommeil
     (Dp.labs_target, prev : la plus haute atteinte, jamais au-delà de base + Dp.LABS_MAX) : elle n'oscille plus avec le surplus.
  7. Revue de l'essai 2 (E2, E4) : l'armement se compte PAR MATIÈRE (arms_by : la part de chaque matière après les laboratoires) ; les
     soldats ne se paient qu'avec la matière CLÉ (Dp.soldiers_extra, jamais quand elle manque : key_short) ; le débit des soldats engagés
     (Dp.reserved) est min(cible − cible du cerveau, cible − présents) × coût, porté par la matière clé, et rien n'est débité au-delà de
     l'excédent qui dort de chaque matière.
  8. Interface du périmètre (PERIMETRE2, accord du lead le 5/11) : ce que la défense a DÉJÀ dépensé de l'accord courant (spent, compté par
     Dp.debit, jamais au-delà de l'accord) sort de l'accord rendu (Dp.defense_left) et de la réserve (Dp.reserved) : le fer posé n'est
     pas retenu une seconde fois jusqu'au relevé suivant.
  Déterminisme : matières dans l'ordre de l'appelant, aucun hasard, aucun temps mesuré ; l'état ne garde que des nombres.
]]

local Dp = {}

Dp.H_SEUIL = 6         -- min de production gardées au coffre au-delà du besoin évalué
Dp.FLOOR = 100         -- unités gardées au moins par matière
Dp.N_DORT = 5 * 3600   -- ticks d'excédent continu avant que la matière « dorme »
Dp.PROD_KEEP = 700     -- ‰ de l'ancienne production gardés à chaque relevé
Dp.DEF_PCT = 30        -- % de l'excédent d'une matière offerts à la défense, au plus
Dp.LAB_PLATES = 1000   -- plaques dormantes (après la défense) par laboratoire de plus
Dp.LABS_MAX = 4        -- laboratoires de plus au plus
Dp.LAB_COST = 60       -- plaques débitées par laboratoire encore à faire (recette du laboratoire : environ 51 plaques, arrondi)
Dp.GAP = 3 * 3600      -- ticks sans relevé : le sommeil n'est plus continu, horloges oubliées
Dp.SOLDIER_PLATES = 500 -- plaques dormantes (après la défense et la recherche) par soldat de plus
Dp.SOLDIERS_MAX = 6    -- soldats de plus au plus
Dp.SOLDIER_COST = 60   -- REPLI seulement : plaques par soldat quand l'appelant ne donne pas le coût de l'équipement (relecture, point 2)

local function num(x) return type(x) == "number" and x == x and x or 0 end

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

function Dp.new() return { since = {}, prod = {} } end

function Dp.smooth(old, made, dt)
  if not dt or dt <= 0 then return num(old) end
  local per_min = num(made) * 3600 / dt
  if old == nil then return per_min end
  return (num(old) * Dp.PROD_KEEP + per_min * (1000 - Dp.PROD_KEEP)) / 1000
end

function Dp.excess(free, prod, missing)
  if missing then return 0 end
  return math.max(0, num(free) - math.max(Dp.FLOOR, Dp.H_SEUIL * math.max(0, num(prod))))
end

--- st = état (Dp.new) ; inp = { on, tick, products = { { key, free, made, missing, def_only } }, want = { [key] = n }, hold (centre en
--- attente : aucun laboratoire, la part de la recherche va à l'armement) }.
--- Rend st, res = { per = { [key] = excédent qui dort }, rper = { [key] = part de la recherche }, defense = { [key] = accordé },
--- research = plaques, labs, arms = plaques, arms_by = { [key] = plaques }, hold, why }.
function Dp.step(st, inp)
  st = st or Dp.new()
  st.since, st.prod = st.since or {}, st.prod or {}
  inp = inp or {}
  local tick = num(inp.tick)
  local res = { per = {}, rper = {}, defense = {}, research = 0, labs = 0, arms = 0, arms_by = {}, hold = inp.hold == true, why = "" }
  if not inp.on then
    st.since, st.prod, st.last = {}, {}, nil
    res.why = "eteint"
    return st, res
  end
  local dt = st.last and (tick - st.last) or nil
  if dt and dt > Dp.GAP then st.since, dt = {}, nil end
  st.last = tick
  local parts = {}
  local want = type(inp.want) == "table" and inp.want or {}
  for _, p in ipairs(inp.products or {}) do
    local k = tostring(p.key)
    if dt then st.prod[k] = Dp.smooth(st.prod[k], p.made, dt) end
    local exc = Dp.excess(p.free, st.prod[k], p.missing)
    if exc > 0 then st.since[k] = st.since[k] or tick else st.since[k] = nil end
    local sleeping = st.since[k] ~= nil and tick - st.since[k] >= Dp.N_DORT
    if sleeping then
      res.per[k] = exc
      local cap = p.def_only and exc or exc * Dp.DEF_PCT / 100
      local d = math.floor(math.min(math.max(0, num(want[k])), cap))
      res.defense[k] = d
      if not p.def_only then
        res.research = res.research + (exc - d)
        res.rper[k] = exc - d
      end
      parts[#parts + 1] = string.format("%s dort %d (defense %d)", k, math.floor(exc), d)
    end
  end
  -- Essai 3 : le centre d'abord. Essai 4 (accord du lead, 5/11) : tant qu'il attend, seuls les LABORATOIRES sont retenus (10 circuits
  -- chacun : ce que le centre attendait, C4 de l'essai 2) ; l'armement passe et reçoit la part de la recherche.
  res.labs = res.hold and 0 or math.min(Dp.LABS_MAX, math.floor(res.research / Dp.LAB_PLATES + 1e-9))
  -- Armement par matière (E4) : la part de chaque matière après les laboratoires (pris au prorata des parts de la recherche).
  local left = math.max(0, res.research - res.labs * Dp.LAB_PLATES)
  for _, p in ipairs(inp.products or {}) do
    local k = tostring(p.key)
    if res.rper[k] and res.research > 0 then res.arms_by[k] = res.rper[k] * left / res.research end
  end
  res.arms = left
  local ab = {}
  for _, p in ipairs(inp.products or {}) do
    local k = tostring(p.key)
    if res.arms_by[k] then ab[#ab + 1] = k .. " " .. math.floor(res.arms_by[k]) end
  end
  local lab_txt = res.hold and string.format("CENTRE EN ATTENTE : laboratoires retenus, recherche %d plaque(s) a l'armement", math.floor(res.research))
    or string.format("recherche %d plaque(s) -> %d laboratoire(s) de plus", math.floor(res.research), res.labs)
  res.why = string.format("%s | %s | armement %d plaque(s) {%s}",
    #parts > 0 and table.concat(parts, " ; ") or "rien ne dort", lab_txt, math.floor(res.arms), table.concat(ab, ", "))
  return st, res
end

--- Soldats de plus payés par la matière CLÉ (E4) : 0 si la clé manque (key_short) ou si elle ne dort pas. Essai 4 : le centre en
--- attente ne les retient plus.
function Dp.soldiers_extra(res, key, key_short)
  if not res or key_short or key == nil then return 0 end
  local a = num((res.arms_by or {})[key])
  return math.min(Dp.SOLDIERS_MAX, math.floor(a / Dp.SOLDIER_PLATES + 1e-9))
end

--- Cible ABSOLUE de laboratoires (revue D1). base = nombre figé (nil : pas encore figé), now = présents, extra = laboratoires de plus
--- voulus (Dp.step, res.labs), cap = plafond total de l'appelant. Rend (cible ou nil, base à garder ou nil) : rien ne dort -> (nil, nil),
--- la base est oubliée ; sinon base figée au premier appel, cible = min(cap, base + extra), jamais sous `now` retiré (la cible ne
--- démonte rien : l'appelant prend le plus grand de sa cible et de celle-ci).
function Dp.labs_target(base, now, extra, cap, prev)
  if num(extra) <= 0 then return nil, nil end
  base = base or math.max(0, math.floor(num(now)))
  local c = math.min(math.max(0, math.floor(num(cap))), base + Dp.LABS_MAX)
  local t = base + math.floor(num(extra))
  if type(prev) == "number" and prev > t then t = prev end -- essai 3 : monotone pendant un sommeil (la plus haute atteinte)
  return math.min(c, t), base
end

--- Sprint s41 (labos) : la base AVANCE quand la cible est atteinte, que les plaques dorment encore (extra > 0) et que les laboratoires
--- sont NOURRIS (fed : les packs de la recherche en cours sont au coffre). Avant : base + Dp.LABS_MAX était un plafond définitif tant
--- que le sommeil durait (3 h 30 de jeu, plaques en excédent, laboratoires figés). Ce n'est pas le défaut D1 : la base ne bouge que
--- cible ATTEINTE et laboratoires nourris, par pas de Dp.LABS_MAX au plus, sous le plafond de l'appelant ; des laboratoires affamés
--- (packs absents) arrêtent la croissance. Rend la base à garder.
function Dp.rebase(base, now, target, extra, fed)
  if not fed or base == nil or target == nil or num(extra) <= 0 then return base end
  local n = math.floor(num(now))
  if n >= target and n > base then return n end
  return base
end

--- Plaques encore engagées : (cible - présents) x coût, jamais négatif.
function Dp.engaged(target, now, cost)
  if target == nil then return 0 end
  return math.max(0, math.floor(num(target)) - math.floor(num(now))) * num(cost)
end

--- Ce que la règle a accordé ou engagé, par matière (D2, E2) : défense accordée + laboratoires encore à faire (au prorata des parts de la
--- recherche) + soldats encore à recruter AU-DESSUS de la cible du cerveau (min(t − brain, t − now) × coût, sur la matière clé) ; jamais
--- plus que l'excédent qui dort de chaque matière (res.per).
--- Accord de défense restant, par matière : accordé − déjà dépensé (spent, de Dp.debit), jamais négatif. Copie.
function Dp.defense_left(res, spent)
  local out = {}
  if not res then return out end
  for _, k in ipairs(sorted_keys(res.defense)) do
    out[k] = math.max(0, num(res.defense[k]) - num((spent or {})[k]))
  end
  return out
end

--- Débit d'une dépense de défense sur l'accord res : rend la quantité débitée = min(q, reste de l'accord), jamais négative ; spent (table
--- de l'appelant, par matière) est augmenté d'autant.
function Dp.debit(res, spent, k, q)
  if not (res and spent and k ~= nil) then return 0 end
  local used = num(spent[k])
  local n = math.max(0, math.min(num(q), num((res.defense or {})[k]) - used))
  if n > 0 then spent[k] = used + n end
  return n
end

--- sold_cost (relecture, point 2) = { [matière] = quantité } : coût matière d'UN soldat, calculé par l'appelant depuis l'équipement de
--- l'unité (T.kits, livre de recettes) ; absent ou vide : Dp.SOLDIER_COST sur la matière clé (repli des sauvegardes et des appels d'avant).
function Dp.reserved(res, lab_target, lab_now, sold_target, sold_brain, sold_now, key, spent, sold_cost)
  local out = {}
  if not res then return out end
  local left = Dp.defense_left(res, spent) -- (la défense déjà posée n'est plus retenue : elle a quitté le coffre)
  for _, k in ipairs(sorted_keys(left)) do out[k] = left[k] end
  local labs = res.hold and 0 or Dp.engaged(lab_target, lab_now, Dp.LAB_COST) -- (centre en attente : rien d'engagé pour les laboratoires)
  if labs > 0 and num(res.research) > 0 then
    for _, k in ipairs(sorted_keys(res.rper)) do out[k] = (out[k] or 0) + labs * num(res.rper[k]) / res.research end
  end
  if sold_target ~= nil and key ~= nil then
    local n = math.max(0, math.min(num(sold_target) - num(sold_brain), num(sold_target) - num(sold_now)))
    if n > 0 then
      if type(sold_cost) == "table" and next(sold_cost) ~= nil then
        for _, k in ipairs(sorted_keys(sold_cost)) do out[k] = (out[k] or 0) + n * math.max(0, num(sold_cost[k])) end
      else
        out[key] = (out[key] or 0) + n * Dp.SOLDIER_COST
      end
    end
  end
  for _, k in ipairs(sorted_keys(out)) do out[k] = math.min(out[k], num((res.per or {})[k])) end
  return out
end

--- Cible d'armée relevée (D3) : army = cible du cerveau, extra = soldats de plus (res.soldiers), max = plafond de soldats. Absolue :
--- elle ne dépend pas des soldats présents.
function Dp.soldiers(army, extra, max)
  local a = math.max(0, math.floor(num(army)))
  return math.max(a, math.min(math.max(0, math.floor(num(max))), a + math.max(0, math.floor(num(extra)))))
end

return Dp
