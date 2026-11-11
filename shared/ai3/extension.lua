--[[
  Lot C3 EXTENSION (1/11, demande du DC : « assurez moi que les bases s ameliore a l infini », « et s etendent aussi »). PUR (aucune API
  Factorio, aucun nom d'objet ; testé hors jeu par tests/extension_test.lua). Audit : fo-logs/2026-10-31_INDUSTRIE/AUDIT_PLAFONDS.md,
  entrées 11 à 13, 15, 24 à 30 ; critère n°6 de CRITERES_CROISSANCE.md.

  Constat (partie 0.6.29, Azure 4 avant-postes de 26 à 119 min, Emerald 5 de 47 à 119 min) : un avant-poste n'était demandé que si une
  capacité passait sous 0,75 x une cible fixe (shared/ai3/buts.lua, B.generate), jamais parce que tous les gisements déjà pris étaient
  PLEINS. Ce module rend ce qui manquait : une RÈGLE DE RELÈVE qui ÉMET un but quand un type n'a plus de place nulle part.

  1. RELÈVE (Ex.releve) : un type d'avant-poste exploité (n >= 1), sans place (aucun avant-poste agrandissable), sans chantier en cours,
     est relevé par un NOUVEAU site pour l'une de ces causes (la plus forte l'emporte) :
       manque      un produit qui manque durablement (B.GROW_SHORT pendant B.GROW_THINKS pensées) et n'est pas saturé ;
       plein       le produit n'est pas saturé (stock sous B.SAT_FACTOR x le besoin) alors que tout gisement pris est plein ;
       posture     la posture « expansion » domine et la base a moins d'avant-postes que Ex.desired (strategy.desired_outposts) ;
       extension   l'allure d'extension est échue (Ex.interval : le poids de l'extraction du chef, la posture, les bras libres) :
                   la base grandit MÊME SI tout est saturé (critère 6 : « la densité seule ne suffit pas »).
     Un type OPTIONNEL (sans besoin au dépliage) ne se relève que pour « manque ».
  2. SURVIE (Ex.guard) : jamais de relève tant qu'un avant-poste est sous sa cible de tourelles, qu'un PNJ est mort récemment en route
     vers un avant-poste (F239, F251), que l'équipe est menacée ; un site LOIN (Ex.SAFE_D, 160 tuiles comme comportement.lua) exige des
     soldats d'escorte (Ex.escort). La cause du refus est écrite (« attend : tourelles d'abord »).
  3. CONCURRENCE : au plus Ex.open_max relèves à la fois (1, plus une par Ex.HANDS_PER_SLOT bras libres, 3 au plus).
  4. PORTÉE (Ex.reach_bonus, Ex.base_radius, Ex.site_limits) : un seul rayon de base (l'étendue réelle de l'emprise + une marge) pour la
     capitalisation, la prospection et la valeur des sites ; sites gardés par ressource et en tout selon la capacité à les défendre.
  5. VEILLE (Ex.releve().push, Ex.block_params) : l'extension qui attend un site fait partir un éclaireur plus tôt et plus souvent, libère un PNJ
     (file sûre) au lieu de compter des refus, et les régions bloquées par un chemin raté rétrécissent quand elles se multiplient.

  Entiers, listes triées, aucun hasard, aucune trigonométrie, aucun `pairs` dans une décision.
]]

local Ex = {}

-- 1. Allure.
Ex.EVERY = 20 * 3600       -- ticks entre deux extensions de la base, au poids neutre (1 000) et sans bras libre
Ex.EVERY_MIN = 6 * 3600    -- plancher de l'allure (6 min)
Ex.HANDS_PER = 3           -- chaque tranche de 3 bras libres raccourcit l'allure (divisée par 1 + libres / 3)
Ex.W_MIN, Ex.W_MAX = 500, 2000
Ex.EXPANSION_BONUS = 2     -- la posture « expansion » (pour mille du mélange du chef) compte à moitié dans le poids
Ex.SHORT_THINKS = 6        -- manque durable : pensées de suite (B.GROW_THINKS)
Ex.SHORT_MIN = 100         -- manque durable : objets (B.GROW_SHORT)
Ex.DOMINANT = 400          -- pour mille : la posture « expansion » domine à partir de ce poids du mélange

-- 2. Relève et concurrence.
Ex.HANDS_PER_SLOT = 6      -- une relève de plus par 6 bras libres
Ex.SLOTS_MAX = 3
Ex.RANK = { manque = 1, plein = 2, posture = 3, extension = 4 }
Ex.VALUE = { manque = 62, plein = 52, posture = 48, extension = 44 } -- avant le poids du chef (B.generate)

-- 3. Survie.
Ex.SAFE_D = 160            -- tuiles du QG : au-delà, « loin » (script/ai3/comportement.lua, M.SAFE_RADIUS)
Ex.ESCORT_MIN = 2          -- soldats d'escorte pour un site juste au-delà de SAFE_D
Ex.ESCORT_STEP = 80        -- un soldat de plus par tranche de 80 tuiles au-delà
Ex.ESCORT_MAX = 8          -- (shared/ai3/expedition.lua, E.KIT.escorte.escort)
Ex.UNDEF_DIV = 3           -- au plus 1 avant-poste sur 3 sous sa cible de tourelles : les tourelles suivent chaque agrandissement (1 + foreuses / 8),
                           -- un retard d'une tourelle sur un avant-poste qui grandit n'arrête pas la base (essai c3-releve : « tourelles d'abord » battait)

-- 4. Portée.
Ex.RADIUS_MIN = 160        -- rayon de base minimal (capitalisation : Capi.SCAN_R d'avant)
Ex.RADIUS_MAX = 400        -- … et maximal (un recensement plus large coûterait trop de lecture au moteur)
Ex.RADIUS_MARGIN = 64      -- marge au-delà de l'avant-poste le plus lointain
Ex.REACH_STEP = 4          -- pour mille de portée de valeur gagnés par tuile d'étendue (au-delà de Ex.RADIUS_MIN - Ex.RADIUS_MARGIN)
Ex.PER_KIND = 3            -- sites gardés par ressource (script/faction/sites.lua, FACTION_MAX_PER_KIND)
Ex.TOTAL = 12              -- … et en tout (FACTION_MAX_PROSPECTS)
Ex.DEFEND_PER = 4          -- une capacité de défense (avant-poste défendu) de plus par 4 : un site de plus par ressource
Ex.SOLDIERS_PER = 6        -- un soldat sur 6 compte pour une capacité de défense (Ex.defense_capacity)
Ex.PER_KIND_MAX = 6
Ex.TOTAL_MAX = 30

-- 5. Veille.
Ex.BLOCK_R, Ex.BLOCK_TTL = 128, 30 * 3600 -- région bloquée par un chemin raté (script/ai3/exploration.lua : BLOCK_R, BLOCK_TTL)
Ex.BLOCK_FREE = 4          -- régions bloquées tolérées au rayon et à la durée pleins
Ex.BLOCK_R_MIN, Ex.BLOCK_TTL_MIN = 64, 10 * 3600

local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

--- État persistant neuf (st.ext de f.team.ia3) : nombres, chaînes et tables simples (global).
function Ex.new()
  return { last = nil, n_out = nil, grown = 0, why = {}, log = {}, seq = 0, open = {} }
end

local function push_log(es, tick, text)
  es.seq = (es.seq or 0) + 1
  es.log[#es.log + 1] = { seq = es.seq, tick = tick, text = text }
  while #es.log > 12 do table.remove(es.log, 1) end
end

---------------------------------------------------------------------------------------------------
-- 1. Allure et cible
---------------------------------------------------------------------------------------------------
--- Poids de l'extension (pour mille) : poids de la famille d'extraction du chef (B.weights, 500 à 2 000) + la moitié de la posture
--- « expansion » du mélange (0 à 1 000), borné.
function Ex.weight(w_ext, expansion)
  return clamp((w_ext or 1000) + math.floor((expansion or 0) / Ex.EXPANSION_BONUS), Ex.W_MIN, Ex.W_MAX)
end

--- Délai (ticks) entre deux extensions d'allure : Ex.EVERY ÷ poids, ÷ (1 + bras libres / Ex.HANDS_PER), au moins Ex.EVERY_MIN.
function Ex.interval(w_ext, expansion, spare)
  local w = Ex.weight(w_ext, expansion)
  local base = math.floor(Ex.EVERY * 1000 / w)
  local hands = 1000 + math.floor(1000 * math.max(0, spare or 0) / Ex.HANDS_PER)
  return math.max(Ex.EVERY_MIN, math.floor(base * 1000 / hands))
end

--- Avant-postes visés par la posture (strategy.desired_outposts : (3 + 2 tech) x avidité, pour mille ici).
function Ex.desired(tech, greed_pm)
  return math.floor((3 + 2 * math.max(0, tech or 0)) * (greed_pm or 1000) / 1000 + 0.5)
end

--- La posture « expansion » domine-t-elle le mélange ? mix = { { key, w }, ... } (C.think, poids pour mille).
--- Rend (poids de la posture, domine ?).
function Ex.posture(mix, key)
  local w, best = 0, 0
  for _, m in ipairs(mix or {}) do
    if m.key == key then w = w + (m.w or 0) end
    if (m.w or 0) > best then best = m.w or 0 end
  end
  return w, w > 0 and w >= best and w >= Ex.DOMINANT
end

--- Nombre de relèves ouvertes au plus : 1, plus une par Ex.HANDS_PER_SLOT bras libres, Ex.SLOTS_MAX au plus.
function Ex.open_max(spare)
  return clamp(1 + math.floor(math.max(0, spare or 0) / Ex.HANDS_PER_SLOT), 1, Ex.SLOTS_MAX)
end

---------------------------------------------------------------------------------------------------
-- 2. Survie
---------------------------------------------------------------------------------------------------
--- Soldats d'escorte exigés pour un site à `d` tuiles du QG (nil : distance inconnue = 0).
function Ex.escort(d)
  if (d or 0) <= Ex.SAFE_D then return 0 end
  return clamp(Ex.ESCORT_MIN + math.floor(((d or 0) - Ex.SAFE_D) / Ex.ESCORT_STEP), Ex.ESCORT_MIN, Ex.ESCORT_MAX)
end

--- Une relève peut-elle partir ? g = { undefended (avant-postes sous leur cible de tourelles), outposts (avant-postes en tout), lethal (avant-postes où un PNJ est mort
--- récemment), threatened, soldiers, near (distance du site admissible le plus proche) }. Rend (vrai) ou (faux, raison).
function Ex.guard(g)
  if (g.undefended or 0) > math.floor((g.outposts or 0) / Ex.UNDEF_DIV) then return false, "tourelles d'abord" end
  if (g.lethal or 0) > 0 then return false, "pertes recentes" end
  if g.threatened then return false, "menace" end
  local need = Ex.escort(g.near)
  if (g.soldiers or 0) < need then return false, "escorte " .. (g.soldiers or 0) .. "/" .. need end
  return true
end

---------------------------------------------------------------------------------------------------
-- 3. Relève
---------------------------------------------------------------------------------------------------
--- Met à jour l'état : l'étendue grandit quand le nombre d'avant-postes monte (la date de la dernière extension part de là).
function Ex.note(es, n_out, tick)
  if es.n_out ~= nil and n_out > es.n_out then
    es.grown = (es.grown or 0) + (n_out - es.n_out)
    es.last = tick
    push_log(es, tick, string.format("avant-poste gagne : %d -> %d (extensions %d)", es.n_out, n_out, es.grown))
  end
  if es.last == nil and n_out > 0 then es.last = tick end
  es.n_out = n_out
end

--- Cause d'un type (ou nil) : s = situation (voir Ex.releve), k = ligne du type, due = l'allure est échue, behind = moins d'avant-postes
--- que Ex.desired et la posture domine.
local function cause_of(k, due, behind)
  if (k.short_n or 0) >= Ex.SHORT_THINKS and (k.short or 0) >= Ex.SHORT_MIN and not k.saturated then return "manque" end
  if k.optional then return nil end
  if not k.saturated then return "plein" end
  if behind then return "posture" end
  if due then return "extension" end
  return nil
end

--- Les relèves de cette pensée. s = { tick, kinds = { { kind, n, cap, room, sites, near, pending, saturated, short, short_n, optional }, … }
--- (dans l'ordre des types), w_ext, expansion, dominant, desired, spare, soldiers, undefended, lethal, threatened, hold (vrai :
--- aucune extension d'allure, p. ex. l'équipe recrute) }, es = état (Ex.new).
--- Rend { goals = { { kind, why, rank, near } … } triés, blocked = { { kind, why, cause } … }, due, interval }.
function Ex.releve(s, es)
  local tick = s.tick or 0
  local n_out, pending = 0, 0
  for _, k in ipairs(s.kinds or {}) do
    n_out = n_out + (k.n or 0)
    pending = pending + (k.pending or 0)
  end
  Ex.note(es, n_out, tick)
  local interval = Ex.interval(s.w_ext, s.expansion, s.spare)
  local due = not s.hold and tick - (es.last or tick) >= interval
  local behind = s.dominant == true and s.desired ~= nil and n_out < s.desired
  local out = { goals = {}, blocked = {}, due = due, interval = interval, n_out = n_out, push = false }
  local slots = Ex.open_max(s.spare) - pending
  for _, k in ipairs(s.kinds or {}) do
    if (k.n or 0) > 0 and not k.room and (k.pending or 0) == 0 then
      local cause = cause_of(k, due, behind and not s.hold)
      if cause then
        local ok, why = Ex.guard({ undefended = s.undefended, outposts = n_out, lethal = s.lethal, threatened = s.threatened,
          soldiers = s.soldiers, near = k.near })
        if not ok then
          out.blocked[#out.blocked + 1] = { kind = k.kind, why = why, cause = cause }
        elseif slots <= 0 then
          out.blocked[#out.blocked + 1] = { kind = k.kind, why = "relèves ouvertes " .. Ex.open_max(s.spare), cause = cause, quiet = true }
        else
          out.goals[#out.goals + 1] = { kind = k.kind, why = cause, rank = Ex.RANK[cause], near = k.near, sites = k.sites or 0 }
        end
      end
    end
  end
  table.sort(out.goals, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    if (a.sites > 0) ~= (b.sites > 0) then return a.sites > 0 end
    return a.kind < b.kind
  end)
  while #out.goals > math.max(0, slots) do out.goals[#out.goals] = nil end
  for _, g in ipairs(out.goals) do if g.sites == 0 then out.push = true end end -- une relève attend un site : la veille est poussée (§5)
  -- Journal : une ligne par changement de cause d'un type (ou de sa raison de refus), pas par pensée.
  local seen = {}
  for _, g in ipairs(out.goals) do seen[g.kind] = "but " .. g.why end
  -- (une place de relève prise par un autre type n'est pas une cause : le dernier état écrit est gardé, le journal ne bat pas la mesure)
  for _, b in ipairs(out.blocked) do
    if not seen[b.kind] and not b.quiet then seen[b.kind] = "attend : " .. b.why .. " (" .. b.cause .. ")" end
  end
  for _, b in ipairs(out.blocked) do
    if b.quiet and not seen[b.kind] then seen[b.kind] = es.why[b.kind] end -- (état gardé : ce n'est pas une cause)
  end
  for _, k in ipairs(s.kinds or {}) do
    local now = seen[k.kind]
    if now ~= es.why[k.kind] then
      if now or es.why[k.kind] then
        push_log(es, tick, string.format("%s : %s ; avant-postes %d, capacite %s, place %s, sites %d%s, delai d'allure %d min, extensions %d",
          k.kind, now or "plus de but", k.n or 0, string.format("%.1f", k.cap or 0), k.room and "oui" or "non", k.sites or 0,
          k.near and (" (le plus proche a " .. math.floor(k.near) .. " tuiles)") or "", math.floor(interval / 3600), es.grown or 0))
      end
      es.why[k.kind] = now
    end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- 4. Portée : un seul rayon de base
---------------------------------------------------------------------------------------------------
--- Étendue (tuiles) : distance du QG à l'avant-poste le plus lointain. d2 = liste des distances au carré (tuiles²) ; sqrt exact
--- (arrondi IEEE) puis entier.
function Ex.extent(d2_list)
  local best = 0
  for _, d2 in ipairs(d2_list or {}) do
    if d2 > best then best = d2 end
  end
  return math.floor(math.sqrt(best))
end

--- Rayon de la base (tuiles du QG) : l'étendue + une marge, entre Ex.RADIUS_MIN et Ex.RADIUS_MAX.
function Ex.base_radius(extent)
  return clamp((extent or 0) + Ex.RADIUS_MARGIN, Ex.RADIUS_MIN, Ex.RADIUS_MAX)
end

--- Portée de valeur (pour mille, à multiplier avec V.reach) : 1 000 au rayon minimal, + Ex.REACH_STEP pour cent par tuile d'étendue.
function Ex.reach_bonus(extent)
  local e = math.max(0, (extent or 0) - Ex.RADIUS_MIN + Ex.RADIUS_MARGIN)
  return 1000 + e * Ex.REACH_STEP
end

--- Capacité à défendre : le QG, chaque avant-poste à sa cible de tourelles, et un soldat sur Ex.SOLDIERS_PER pour les sites à venir.
function Ex.defense_capacity(defended, soldiers)
  return 1 + math.max(0, defended or 0) + math.floor(math.max(0, soldiers or 0) / Ex.SOLDIERS_PER)
end

--- Sites gardés (par ressource, en tout) selon la capacité à les défendre : `defended` = avant-postes à leur cible de tourelles (le
--- QG compte pour un). Une faction : 3 et 12 d'avant, plus un site par ressource par Ex.DEFEND_PER capacités, jusqu'à 6 et 30.
function Ex.site_limits(defended)
  local d = math.max(0, defended or 0)
  local per = clamp(Ex.PER_KIND + math.floor(d / Ex.DEFEND_PER), Ex.PER_KIND, Ex.PER_KIND_MAX)
  local total = clamp(Ex.TOTAL + d, Ex.TOTAL, Ex.TOTAL_MAX)
  return per, total
end

---------------------------------------------------------------------------------------------------
-- 5. Veille poussée par l'extension
---------------------------------------------------------------------------------------------------
--- Rayon et durée des régions bloquées par un chemin raté : pleins jusqu'à Ex.BLOCK_FREE régions, puis ils rétrécissent d'un pas par
--- région en plus (la frontière entière n'est plus « bloquée » après quelques échecs), jusqu'à des planchers.
function Ex.block_params(n)
  local extra = math.max(0, (n or 0) - Ex.BLOCK_FREE)
  local r = clamp(Ex.BLOCK_R - 8 * extra, Ex.BLOCK_R_MIN, Ex.BLOCK_R)
  local ttl = clamp(Ex.BLOCK_TTL - 2 * 3600 * extra, Ex.BLOCK_TTL_MIN, Ex.BLOCK_TTL)
  return r, ttl
end

return Ex
