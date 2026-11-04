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
Dp.SOLDIER_COST = 60   -- plaques débitées par soldat de plus encore à recruter

local function num(x) return type(x) == "number" and x == x and x or 0 end

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

--- st = état (Dp.new) ; inp = { on, tick, products = { { key, free, made, missing, def_only } }, want = { [key] = n } }.
--- Rend st, res = { per = { [key] = excédent qui dort }, rper = { [key] = part de la recherche }, defense = { [key] = accordé },
--- research = plaques, labs, arms = plaques, soldiers, why }.
function Dp.step(st, inp)
  st = st or Dp.new()
  st.since, st.prod = st.since or {}, st.prod or {}
  inp = inp or {}
  local tick = num(inp.tick)
  local res = { per = {}, rper = {}, defense = {}, research = 0, labs = 0, arms = 0, soldiers = 0, why = "" }
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
  res.labs = math.min(Dp.LABS_MAX, math.floor(res.research / Dp.LAB_PLATES + 1e-9))
  res.arms = math.max(0, res.research - res.labs * Dp.LAB_PLATES)
  res.soldiers = math.min(Dp.SOLDIERS_MAX, math.floor(res.arms / Dp.SOLDIER_PLATES + 1e-9))
  res.why = string.format("%s | recherche %d plaque(s) -> %d laboratoire(s) de plus | armement %d plaque(s) -> %d soldat(s) de plus",
    #parts > 0 and table.concat(parts, " ; ") or "rien ne dort", math.floor(res.research), res.labs, math.floor(res.arms), res.soldiers)
  return st, res
end

--- Cible ABSOLUE de laboratoires (revue D1). base = nombre figé (nil : pas encore figé), now = présents, extra = laboratoires de plus
--- voulus (Dp.step, res.labs), cap = plafond total de l'appelant. Rend (cible ou nil, base à garder ou nil) : rien ne dort -> (nil, nil),
--- la base est oubliée ; sinon base figée au premier appel, cible = min(cap, base + extra), jamais sous `now` retiré (la cible ne
--- démonte rien : l'appelant prend le plus grand de sa cible et de celle-ci).
function Dp.labs_target(base, now, extra, cap)
  if num(extra) <= 0 then return nil, nil end
  base = base or math.max(0, math.floor(num(now)))
  return math.min(math.max(0, math.floor(num(cap))), base + math.floor(num(extra))), base
end

--- Plaques encore engagées : (cible - présents) x coût, jamais négatif.
function Dp.engaged(target, now, cost)
  if target == nil then return 0 end
  return math.max(0, math.floor(num(target)) - math.floor(num(now))) * num(cost)
end

--- Cible d'armée relevée (D3) : army = cible du cerveau, extra = soldats de plus (res.soldiers), max = plafond de soldats. Absolue :
--- elle ne dépend pas des soldats présents.
function Dp.soldiers(army, extra, max)
  local a = math.max(0, math.floor(num(army)))
  return math.max(a, math.min(math.max(0, math.floor(num(max))), a + math.max(0, math.floor(num(extra)))))
end

return Dp
