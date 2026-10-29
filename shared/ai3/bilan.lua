--[[
  Lot BILAN « production moins consommation » : REGLE PURE (aucune API Factorio, aucun nom d'objet du jeu : les objets sont
  des clés opaques, règle anti-échelle d'IA-G, tests/iag_test.lua §8).

  Remarque 11 du DC : « concept de production / sous-production d'une ressource (production moins consommation), on cherche
  le bilan de chaque ressource ». Le cerveau décidait à partir des manques par objet ; il ne savait pas si la fabrication
  ou la récolte d'un objet suivait sa consommation.

  Entrée : toutes les Bi.PERIOD ticks, le runtime (script/ai3/bilan.lua) donne pour chaque objet suivi
    rows[objet] = { prod = débit produit par minute, cons = débit consommé par minute, stock = stock LIBRE de l'équipe }
  (débits : get_flow_count des statistiques de la force ; le moteur ne compte pas ce que les PNJ minent ou fabriquent à la
  main, F319 : c'est la pente du STOCK qui voit leur part).

  Règle, par objet et par relevé :
    bilan = prod − cons (par minute) ; pente = variation du stock par minute depuis le relevé précédent ;
    relevé « sous » : bilan ≤ −MIN_RATE ET le stock ne monte pas (pente < MIN_RATE) : les machines consomment plus qu'elles
                      ne produisent et personne ne comble la différence ;
    relevé « sur »  : pente ≥ MIN_RATE ET bilan ≥ 0 : le stock monte et les machines ne sont pas consommatrices nettes.
    Un compteur par objet monte d'un cran par relevé « sous » (« sur » : un second compteur), descend d'un cran sinon,
    borné à [0, SOUS_N + 2] : un niveau n'apparaît qu'après SOUS_N (SUR_N) relevés de suite (= minutes) et ne disparaît
    qu'après plusieurs relevés contraires (pas de clignotement).
    Niveau « sous » = sous-production DURABLE ; niveau « sur » = sur-production durable (« sous » l'emporte si les deux).

  Sortie : Bi.weights(state) -> { [objet] = points de priorité } : sous-production = + jusqu'à Bi.BONUS (selon la gravité
  du déficit rapporté à la consommation), sur-production = − Bi.MALUS. Le cerveau n'AJOUTE jamais un besoin : il pondère
  seulement les besoins qu'il a déjà demandés (récolte : shared/ai3/projets.lua, P.supply ; fabrication :
  shared/ai3/cerveau.lua, tâches « craft », seulement en hausse et jamais au niveau d'une urgence).

  Déterminisme : clés triées, aucun hasard, aucun pairs décisionnel. État (state) : nombres et chaînes seulement.
]]

local Bi = {}

Bi.PERIOD = 3600       -- ticks entre deux relevés (1 min)
Bi.SOUS_N = 3          -- relevés de suite avant le niveau « sous » (3 min)
Bi.SUR_N = 3           -- … et avant le niveau « sur »
Bi.CAP_EXTRA = 2       -- le compteur monte jusqu'à N + 2 : sortie du niveau après plusieurs relevés contraires
Bi.MIN_RATE = 2        -- objets par minute : en dessous, le bilan et la pente sont du bruit
Bi.BONUS = 8           -- points de priorité d'une sous-production (échelle des tâches : 40 à 85, urgences dès 90)
Bi.MALUS = 5           -- … retirés à une sur-production
Bi.PRIO_MIN = 20       -- bornes de la récolte pondérée
Bi.PRIO_MAX = 85
Bi.CRAFT_MAX = 89      -- une fabrication pondérée ne rejoint jamais une urgence (90)
Bi.MAX_ITEMS = 64      -- objets suivis (les plus actifs) : l'état reste borné
Bi.LOG_PERIOD = 5 * 3600
Bi.LOG_MAX = 6         -- objets par liste du journal

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function num(v) return type(v) == "number" and v == v and v or 0 end

--- État neuf (dans f.team.ia3.bilan : nombres et chaînes seulement).
function Bi.new()
  return { tick = nil, items = {}, logged = 0 }
end

--- Vrai si un relevé est dû.
function Bi.due(state, tick)
  return state.tick == nil or tick - state.tick >= Bi.PERIOD
end

--- Intègre un relevé. rows = { [objet] = { prod, cons, stock } }. Rend vrai si le relevé a été pris.
function Bi.update(state, tick, rows)
  if not Bi.due(state, tick) then return false end
  local dt = state.tick and (tick - state.tick) or nil
  -- Objets suivis : les MAX_ITEMS plus actifs (|prod| + |cons|), égalités par clé.
  local keys = sorted_keys(rows)
  if #keys > Bi.MAX_ITEMS then
    table.sort(keys, function(a, b)
      local ra, rb = num(rows[a].prod) + num(rows[a].cons), num(rows[b].prod) + num(rows[b].cons)
      if ra ~= rb then return ra > rb end
      return a < b
    end)
    while #keys > Bi.MAX_ITEMS do keys[#keys] = nil end
    table.sort(keys)
  end
  local old, items = state.items or {}, {}
  for _, k in ipairs(keys) do
    local r = rows[k]
    local prod, cons, stock = num(r.prod), num(r.cons), num(r.stock)
    local prev = old[k]
    local e = { s = stock, p = prod, c = cons, b = prod - cons, d = 0, n = prev and prev.n or 0, u = prev and prev.u or 0 }
    local slope = nil
    if prev and dt and dt > 0 then
      slope = (stock - prev.s) * Bi.PERIOD / dt
      e.d = slope
    end
    if slope ~= nil then
      local sous = e.b <= -Bi.MIN_RATE and slope < Bi.MIN_RATE
      local sur = slope >= Bi.MIN_RATE and e.b >= 0
      e.n = sous and math.min(Bi.SOUS_N + Bi.CAP_EXTRA, e.n + 1) or math.max(0, e.n - 1)
      e.u = sur and math.min(Bi.SUR_N + Bi.CAP_EXTRA, e.u + 1) or math.max(0, e.u - 1)
    end
    items[k] = e
  end
  state.items = items
  state.tick = tick
  return true
end

--- Niveau d'un objet : « sous », « sur » ou nil.
function Bi.level(state, item)
  local e = (state.items or {})[item]
  if not e then return nil end
  if e.n >= Bi.SOUS_N then return "sous" end
  if e.u >= Bi.SUR_N then return "sur" end
  return nil
end

--- Pondération : { [objet] = points de priorité } (nombres entiers non nuls seulement).
function Bi.weights(state)
  local out = {}
  for _, k in ipairs(sorted_keys(state.items)) do
    local lv = Bi.level(state, k)
    local e = state.items[k]
    if lv == "sous" then
      -- Gravité : déficit rapporté à la consommation (1 = les machines ne produisent rien de ce qu'elles consomment).
      local sev = math.min(1, math.max(0, -e.b) / math.max(e.c, 1))
      out[k] = math.ceil(Bi.BONUS * (0.5 + 0.5 * sev))
    elseif lv == "sur" then
      out[k] = -Bi.MALUS
    end
  end
  return out
end

--- Priorité pondérée d'une récolte (bornée).
function Bi.clamp(prio, delta)
  if not delta or delta == 0 then return prio end
  local p = prio + delta
  if delta > 0 then
    -- Une pondération en hausse ne fait pas descendre une tâche déjà au-dessus du plafond (amorçage, urgences).
    return math.max(prio, math.min(Bi.PRIO_MAX, p))
  end
  return math.min(prio, math.max(Bi.PRIO_MIN, p))
end

--- Priorité pondérée d'une fabrication : seulement en hausse, jamais jusqu'à une urgence.
function Bi.craft(prio, delta)
  if not delta or delta <= 0 or prio >= Bi.CRAFT_MAX + 1 then return prio end
  return math.max(prio, math.min(Bi.CRAFT_MAX, prio + delta))
end

--- Résumé pour le journal : { sous = { {objet, bilan, pente}... }, sur = {...}, n = objets suivis }.
--- « sous » du plus grand déficit au plus petit, « sur » de la plus forte pente ; égalités par clé.
function Bi.summary(state)
  local sous, sur, n = {}, {}, 0
  for _, k in ipairs(sorted_keys(state.items)) do
    n = n + 1
    local lv = Bi.level(state, k)
    local e = state.items[k]
    if lv == "sous" then sous[#sous + 1] = { k, e.b, e.d }
    elseif lv == "sur" then sur[#sur + 1] = { k, e.b, e.d } end
  end
  table.sort(sous, function(a, b) if a[2] ~= b[2] then return a[2] < b[2] end return a[1] < b[1] end)
  table.sort(sur, function(a, b) if a[3] ~= b[3] then return a[3] > b[3] end return a[1] < b[1] end)
  return { sous = sous, sur = sur, n = n }
end

--- Vrai (et note le tick) quand une ligne de journal est due : un relevé existe et LOG_PERIOD s'est écoulé.
function Bi.log_due(state, tick)
  if state.tick == nil then return false end
  if tick - (state.logged or 0) < Bi.LOG_PERIOD then return false end
  state.logged = tick
  return true
end

--- Ligne de journal « [FO-BILAN] … » (sans accents, comme les autres lignes du cerveau).
function Bi.format(key, tick, state)
  local s = Bi.summary(state)
  local function list(rows, field)
    local parts = {}
    for i, r in ipairs(rows) do
      if i > Bi.LOG_MAX then parts[#parts + 1] = "+" .. (#rows - Bi.LOG_MAX) break end
      parts[#parts + 1] = string.format("%s:%+.1f/min", r[1], r[field])
    end
    return table.concat(parts, " ")
  end
  local w = Bi.weights(state)
  local pondered = 0
  for _ in pairs(w) do pondered = pondered + 1 end
  return string.format("[FO-BILAN] %s partie %d min | sous [%s] | sur [%s] | ponderes %d | suivis %d", key or "player",
    math.floor(tick / 3600 + 0.5), list(s.sous, 2), list(s.sur, 3), pondered, s.n)
end

return Bi
