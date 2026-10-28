--[[
  Lot REMPLISSAGE (28/10, remarque du DC : « refill au maximum »). Règle PURE (Lua sans moteur, sans nom d'objet du jeu :
  tout vient en paramètres) de la charge des fours servis à la main (fonderie du QG, Outposts.service_smelters).

  Défaut mesuré (main 72ab9ed, base MESURES) : le PNJ chargeait 10 fabrications par four, seulement dans un four VIDE, et
  repassait toutes les 120 à 300 ticks (la tâche « smelt » renaissait dès qu'une plaque attendait en sortie ou qu'un
  produit manquait). Une case en accepte bien plus (pile de 50 minerais, de 100 plaques).

  Décision par défaut (question 7 du DC, docs/QUESTIONS_DC.md, option par défaut du lot) : de quoi tenir `horizon` ticks de
  fonte (10 minutes) au débit du four, borné par
    - la PILE de la case source (taille lue au prototype) ;
    - la demande restante (jamais plus que ce qui manque), sauf le plancher de main 0.6.7 (`base_fabs` fabrications) ;
    - une PART du stock libre de l'objet (`share`), pour ne pas immobiliser tout le coffre dans les fours.
  Un four déjà garni est COMPLÉTÉ quand il est sous `low` de sa cible. Une tournée n'est justifiée que s'il y a quelque
  chose à faire (`C.due`, `C.visit_due`) : de la place à charger ET de la matière au coffre, un combustible bas, ou une
  sortie qui s'accumule.

  Données :
    four   = { item = nom|nil (case source), n = nombre, fuel = charbons, out = objets en sortie, out_cap = pile de la
               sortie (0 si vide), crafting = bool }
    spec   = { input = objet d'entrée, per = entrée par fabrication, ticks = durée d'une fabrication (ticks, vitesse
               comprise), cap = pile de l'entrée }
    specs  = { [produit] = spec } (TOUS les produits de la fonderie), products = liste TRIÉE des produits demandés.
  Déterminisme : aucun `pairs` ne décide d'un résultat (clés triées), aucun temps mesuré.
]]

local C = {}

local function multiple(n, per) return n - n % per end

local function sorted_keys(t)
  local out = {}
  for k in pairs(t or {}) do out[#out + 1] = k end
  table.sort(out)
  return out
end

--- Paramètres par défaut (données, pas des objets du jeu) ; shared/team/config.lua les expose en T.charge.
C.DEFAULT = {
  horizon = 36000,  -- ticks de fonte visés (10 minutes)
  low = 0.5,        -- un four garni est complété sous cette part de sa cible
  share = 0.5,      -- part du stock libre d'un objet que les fours peuvent immobiliser
  base_fabs = 10,   -- plancher : les 10 fabrications de main 0.6.7, quelle que soit la part
  out_due = 0.25,   -- une sortie à cette part de sa pile justifie une tournée
  fuel_low = 0.5,   -- un combustible sous cette part de sa cible justifie une tournée
  fuel_min = 5,     -- ... à condition que le coffre ait au moins ce combustible libre (sinon la tournée reviendrait à vide)
}

local function P_of(P)
  local out = {}
  for k, v in pairs(C.DEFAULT) do out[k] = v end
  for k, v in pairs(P or {}) do out[k] = v end
  return out
end

--- Quantité d'entrée visée pour un four vide : horizon ÷ durée de fabrication fabrications, bornées par la pile, en
--- multiples de la recette (jamais moins d'une fabrication).
function C.target(spec, P)
  P = P_of(P)
  local per = spec.per
  local n = math.ceil(P.horizon / math.max(1, spec.ticks)) * per
  local cap = multiple(math.max(per, spec.cap or per), per)
  if n > cap then n = cap end
  if n < per then n = per end
  return n
end

--- Combustible visé : de quoi brûler `horizon` ticks, borné par la pile. burn_ticks = ticks qu'un objet brûle dans ce four.
function C.fuel_target(burn_ticks, cap, P)
  P = P_of(P)
  local n = math.ceil(P.horizon / math.max(1, burn_ticks))
  if cap and n > cap then n = cap end
  if n < 1 then n = 1 end
  return n
end

--- Entrées dont une fabrication exige plus d'un objet : { [objet] = exigence maximale }.
local function ratio_of(specs)
  local ratio = {}
  for _, p in ipairs(sorted_keys(specs)) do
    local s = specs[p]
    if s.per > 1 then ratio[s.input] = math.max(ratio[s.input] or 0, s.per) end
  end
  return ratio
end

--- Produit qui consomme cet objet (le premier par ordre alphabétique).
local function by_input_of(specs)
  local out = {}
  for _, p in ipairs(sorted_keys(specs)) do
    if out[specs[p].input] == nil then out[specs[p].input] = p end
  end
  return out
end

--- Four chargé de MOINS d'une fabrication, à l'arrêt : il ne fond jamais (acier : 5 plaques exigées, 1 à 4 en case).
local function underfilled(f, ratio)
  local item, n = f.item, f.n or 0
  return item ~= nil and n > 0 and not f.crafting and ratio[item] ~= nil and n < ratio[item]
end

--- Qui reçoit quoi. Rend { reclaim = { [i] = true }, loads = { [i] = { product, item, per, room } } }.
--- reclaim : le porteur reprend l'entrée d'un four sous-chargé (étape 1 du 27/10) ; le four compte alors comme vide.
--- loads : place à combler (multiple de la recette). Un four vide reçoit les produits demandés à tour de rôle (comme
--- avant) ; un four garni, son propre produit s'il est demandé et sous `low` de sa cible.
function C.assign(fs, products, specs, P)
  P = P_of(P)
  local res = { reclaim = {}, loads = {} }
  local ratio = ratio_of(specs)
  local by_input = by_input_of(specs)
  local wanted = {}
  for _, p in ipairs(products) do wanted[p] = true end
  local k = 0
  for i, f in ipairs(fs) do
    local item, n = f.item, f.n or 0
    if underfilled(f, ratio) then
      res.reclaim[i] = true
      item, n = nil, 0
    end
    if item == nil or n == 0 then
      if #products > 0 then
        k = k % #products + 1
        local p = products[k]
        local spec = specs[p]
        if spec then res.loads[i] = { product = p, item = spec.input, per = spec.per, room = C.target(spec, P) } end
      end
    else
      local p = by_input[item]
      if p and wanted[p] then
        local spec = specs[p]
        local target = C.target(spec, P)
        if n < P.low * target then
          local room = multiple(target - n, spec.per)
          if room >= spec.per then res.loads[i] = { product = p, item = item, per = spec.per, room = room } end
        end
      end
    end
  end
  return res
end

local function load_items(assign)
  local idx = {}
  for i in pairs(assign.loads) do idx[#idx + 1] = i end
  table.sort(idx)
  local items, by_item = {}, {}
  for _, i in ipairs(idx) do
    local item = assign.loads[i].item
    if not by_item[item] then by_item[item] = {}; items[#items + 1] = item end
    by_item[item][#by_item[item] + 1] = i
  end
  table.sort(items)
  return items, by_item
end

--- Répartit `avail` ({ [objet] = n } : ce que le porteur a) entre les fours à charger : à égalité, par fabrications
--- entières, sans dépasser la place de chacun. Rend { [i] = { item, n } } (fours qui reçoivent au moins une fabrication).
function C.distribute(assign, avail)
  local items, by_item = load_items(assign)
  local out = {}
  for _, item in ipairs(items) do
    local list = by_item[item]
    local per = assign.loads[list[1]].per
    local a = multiple(math.max(0, math.floor(avail[item] or 0)), per)
    local given = {}
    for _, i in ipairs(list) do given[i] = 0 end
    local progress = true
    while a >= per and progress do
      progress = false
      for _, i in ipairs(list) do
        if a >= per and given[i] + per <= assign.loads[i].room then
          given[i] = given[i] + per
          a = a - per
          progress = true
        end
      end
    end
    for _, i in ipairs(list) do
      if given[i] > 0 then out[i] = { item = item, n = given[i] } end
    end
  end
  return out
end

--- Ce que le porteur prend au coffre : { [objet] = n } (multiple de la recette). Pour chaque objet : la place totale à
--- combler, bornée par la demande (`demand[produit]`, en produits) et par `share` du stock libre, sauf le plancher
--- `base_fabs` fabrications par four ; jamais plus que le stock.
function C.take(assign, demand, stock, P)
  P = P_of(P)
  local items, by_item = load_items(assign)
  local out = {}
  for _, item in ipairs(items) do
    local room, base, dem = 0, 0, 0
    local per = assign.loads[by_item[item][1]].per
    local seen = {}
    for _, i in ipairs(by_item[item]) do
      local l = assign.loads[i]
      room = room + l.room
      base = base + math.min(l.room, l.per * P.base_fabs)
      if not seen[l.product] then -- la demande est celle du PRODUIT, comptée une seule fois
        seen[l.product] = true
        dem = dem + l.per * ((demand or {})[l.product] or 0)
      end
    end
    local s = math.max(0, math.floor(stock[item] or 0))
    local want = math.min(room, dem, math.floor(P.share * s))
    want = math.max(want, base)
    want = multiple(math.min(want, room, s), per)
    if want > 0 then out[item] = want end
  end
  return out
end

--- Combustible à apporter à un four : de son contenu à la cible (jamais négatif).
function C.fuel_missing(fuel, target)
  return math.max(0, target - (fuel or 0))
end

--- La tournée est-elle justifiée ? Rend due = { products = { [produit] = fabrications au coffre }, fuel = bool, out = bool }.
--- products[p] : au moins un four peut recevoir p ET le coffre a au moins une fabrication (le nombre de fabrications du
--- coffre est rendu ; C.visit_due exige qu'il vaille la tournée). fuel : un four sous `fuel_low` de sa cible ET du
--- combustible libre au coffre (`fuel_stock` >= `fuel_min` ; nil = non contrôlé).
function C.due(fs, specs, stock, fuel_target, P, fuel_stock)
  P = P_of(P)
  local due = { products = {}, fuel = false, out = false }
  local ratio = ratio_of(specs)
  for _, p in ipairs(sorted_keys(specs)) do
    local spec = specs[p]
    if (stock[spec.input] or 0) >= spec.per then
      local target = C.target(spec, P)
      for _, f in ipairs(fs) do
        local n = f.n or 0
        if f.item == nil or n == 0 or underfilled(f, ratio)
          or (f.item == spec.input and n < P.low * target and target - n >= spec.per) then
          due.products[p] = math.floor((stock[spec.input] or 0) / spec.per)
          break
        end
      end
    end
  end
  for _, f in ipairs(fs) do
    if fuel_target and (f.fuel or 0) < P.fuel_low * fuel_target and (fuel_stock == nil or fuel_stock >= P.fuel_min) then due.fuel = true end
    if (f.out or 0) > 0 and (f.out or 0) >= P.out_due * math.max(1, f.out_cap or 0) then due.out = true end
  end
  return due
end

--- Une tournée « smelt » vaut-elle d'être ouverte ? smelt = { [produit] = n } (demande). due == nil : ancien comportement
--- (vue sans relevé des fours). Une matière ne justifie la tournée que si le coffre en a de quoi `base_fabs`
--- fabrications, ou de quoi toute la demande si elle est plus petite (sinon la tournée charge 2 minerais et revient).
--- Le combustible urgent (< T.fuel_low) est compris dans due.fuel (même seuil, avec du combustible libre au coffre).
function C.visit_due(due, smelt, fuel_low, P)
  if due == nil then return true end
  P = P_of(P)
  if due.fuel or due.out then return true end
  for _, p in ipairs(sorted_keys(smelt)) do
    local d = smelt[p] or 0
    local have = due.products[p]
    if d > 0 and have then
      if have == true or have >= math.min(P.base_fabs, d) then return true end
    end
  end
  return false
end

return C
