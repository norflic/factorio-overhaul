--[[
  Lot VIDEO-SAT (rang 12 de docs/TODO_VIDEO.md §I, ligne V79) : « a surplus … doesn't get so large that it prevents us from
  realizing that we don't have enough production capacity ». RÈGLE PURE (aucune API Factorio, aucun nom d'objet du jeu : les
  objets sont des clés opaques, règle anti-échelle d'IA-G, tests/iag_test.lua §8).

  Défaut (shared/ai3/buts.lua, B.saturated) : une matière est « saturée » dès que son stock atteint B.SAT_FACTOR × son besoin,
  que ce stock MONTE ou qu'il FONDE. Un gros stock qui baisse parce que la consommation dépasse la production coupe donc la
  croissance de l'extraction (B.targets, vague des bras libres), la reconstruction d'un avant-poste perdu (B.generate), la
  relève (Ex.releve), le fond (shared/team/fond.lua) et garde les tournées retirées (shared/ai3/cerveau.lua), jusqu'à ce que le
  stock passe sous le seuil : le manque de capacité ne se voit qu'au moment où il ne reste plus que le seuil.

  Règle :
    1. PENTE MESURÉE du stock libre de chaque matière suivie, un relevé toutes les Sa.PERIOD ticks (Sa.observe) : pente du
       relevé = variation du stock par minute ; moyenne des pentes (moyenne exacte des Sa.WINDOW premières, puis moyenne
       glissante de poids 1 / Sa.WINDOW). Le stock est celui que le cerveau lit (view.stock) : il voit aussi ce que les PNJ
       minent, fabriquent et posent à la main, que les statistiques de la force ne comptent pas (F319, shared/ai3/bilan.lua).
    2. FONTE DURABLE (Sa.drain) : au moins Sa.WINDOW pentes mesurées (la moyenne couvre Sa.WINDOW minutes ; une dépense isolée
       pèse 1 / Sa.WINDOW) et moyenne ≤ −Sa.MIN_RATE (en dessous : du bruit).
    3. SATURATION (Sa.holds) : stock ≥ seuil ET stock PROJETÉ à Sa.H minutes au rythme de la fonte ≥ seuil. Sans fonte durable,
       la règle d'avant (stock ≥ seuil) : une mesure absente ou trop courte n'ouvre jamais la croissance (garde fermée par
       défaut, comme le lot L13 : sans mesure, le garde-fou contre l'emballement, constat du DC du 25/10 « ils en ont a
       foison », reste en place).
  Avec Sa.H infini, c'est la lecture stricte de V79 (« saturée seulement si le débit net ≥ 0 ») ; Sa.H borne l'anticipation
  au délai d'une capacité nouvelle, pour qu'une fonte minime d'un stock immense (dizaines de milliers d'objets) ne relance pas
  l'extraction (PLAN_SATURATION.md §3).

  État (dans f.team.ia3.sat, via le cerveau) : nombres seulement ; une entrée par objet SUIVI (la liste passée à Sa.observe) :
  l'état reste borné. Déterminisme : objets dans l'ordre de la liste triée de l'appelant, aucun hasard, aucun pairs décisionnel,
  aucun temps mesuré (les pentes viennent des ticks de jeu).
]]

local Sa = {}

Sa.PERIOD = 3600   -- ticks entre deux relevés (1 min, comme Bi.PERIOD)
Sa.WINDOW = 4      -- pentes dans la moyenne (10 min, comme Dm.SAT_H) ; autant avant de croire la fonte
Sa.MIN_RATE = 2    -- objets par minute : en dessous, la pente est du bruit (comme Bi.MIN_RATE)
Sa.H = 20          -- minutes : horizon de la projection (délai d'une capacité nouvelle, SUPPOSÉ : à mesurer, PLAN_SATURATION.md §3)

--- Valeur de stock lisible : nombre fini, non négatif. nil sinon (l'historique de l'objet est alors rompu).
local function stock_of(v)
  if v == nil then return 0 end
  if type(v) ~= "number" or v ~= v or v < 0 or v == math.huge then return nil end
  return v
end

--- État neuf.
function Sa.new()
  return { tick = nil, items = {} }
end

--- Vrai si un relevé est dû.
function Sa.due(state, tick)
  return type(tick) == "number" and (state.tick == nil or tick - state.tick >= Sa.PERIOD)
end

--- Relevé : `stock` = { [objet] = stock libre } (absent : 0), `items` = liste TRIÉE des objets suivis. Rend vrai si le relevé a
--- été pris. Un objet hors de la liste est oublié ; un stock illisible rompt l'historique de l'objet (aucune pente inventée).
function Sa.observe(state, tick, stock, items)
  if not Sa.due(state, tick) then return false end
  local old, out = state.items or {}, {}
  stock = stock or {}
  for _, k in ipairs(items or {}) do
    local v = stock_of(stock[k])
    if v ~= nil then
      local e = old[k]
      if e and tick > e.t then
        local slope = (v - e.s) * Sa.PERIOD / (tick - e.t)
        local n = e.n + 1
        local w = n < Sa.WINDOW and n or Sa.WINDOW
        out[k] = { s = v, t = tick, n = n, m = e.m + (slope - e.m) / w }
      else
        out[k] = { s = v, t = tick, n = 0, m = 0 }
      end
    end
  end
  state.items = out
  state.tick = tick
  return true
end

--- Fonte durable d'un objet (objets par minute, > 0), ou nil.
function Sa.drain(state, item)
  local e = state and state.items and state.items[item]
  if not e or e.n < Sa.WINDOW then return nil end
  if e.m > -Sa.MIN_RATE then return nil end
  return -e.m
end

--- Fontes durables de tous les objets suivis : { [objet] = objets par minute } (lu par B.saturated, s.drain).
function Sa.drains(state)
  local items, ks = state and state.items or {}, {}
  for k in pairs(items) do ks[#ks + 1] = k end
  table.sort(ks)
  local out = {}
  for _, k in ipairs(ks) do
    local d = Sa.drain(state, k)
    if d then out[k] = d end
  end
  return out
end

--- Saturation d'un stock contre son seuil, à la fonte `drain` (objets par minute, nil : aucune fonte mesurée).
--- Rend (vrai) ou (faux, raison) : « seuil » sous le seuil, « pente » au-dessus du seuil mais projeté dessous à `h` minutes.
function Sa.holds(stock, threshold, drain, h)
  if not (stock >= threshold) then return false, "seuil" end
  if drain and drain > 0 and stock - drain * (h or Sa.H) < threshold then return false, "pente" end
  return true
end

return Sa
