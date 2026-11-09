--[[
  Solveur récursif d'arbres de recettes — PUR (aucune API Factorio, aucun nom d'objet du jeu).
  Lot RECIPE-SOLVER (directive du DC) : « machines = débit × temps de recette ÷ (quantité produite par cycle × vitesse) ;
  récursion sur chaque ingrédient qui n'est pas une matière du bus ; interdit à chaque tick : cache, lecture O(1) ».

  Entrées : un livre (shared/team/book.lua : `book.recipes[nom] = { energy, hidden, ingredients = {{name, amount}},
  products = {{name, amount}} }`, `book.by_product`) et un ensemble `bus = { [objet] = true }` des matières considérées
  comme FOURNIES (plaques, pierre, charbon… : décidé par l'appelant, jamais ici).

  Arbre rendu par `Solver.solve` (jamais nil, zéro blocage) :
    { item, rate, machines, recipe, nodes = { sous-arbres des ingrédients hors bus, ordre de la recette },
      bus_needs = { [matière du bus ou brute] = débit/s agrégé sur tout l'arbre },
      total_machines = { [recette] = machines agrégées sur tout l'arbre },
      bus = true (racine fournie par le bus) | raw = true (aucune recette connue) | cycle = true (coupe d'un cycle) }
  Les ingrédients du bus n'ont pas de sous-arbre (besoin direct) ; une matière brute est une feuille `raw` de `nodes`.

  Mémoïsation : l'arbre NORMALISÉ (débit 1) est mis en cache par `s.cache[item][speed]` ; toute lecture le met à l'échelle
  (linéaire en le débit) : après le premier calcul, aucune récursion sur le livre. Un arbre dont un cycle est coupé sur
  un ANCÊTRE n'entre pas au cache (il dépend du chemin de descente) ; un cycle coupé sur l'objet lui-même est admis.
]]

local Solver = {}
Solver.__index = Solver

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Index produit -> recette. Préférence du livre (`by_product` : recettes de la main) ; sinon la recette visible qui porte
--- le nom du produit, sinon la première par ordre alphabétique dont un produit est l'objet (fours, usines avancées, chimie).
local function build_index(book)
  local idx = {}
  local recipes = book.recipes or {}
  for _, name in ipairs(sorted_keys(recipes)) do
    local r = recipes[name]
    if not r.hidden then
      for _, p in ipairs(r.products or {}) do
        local cur = idx[p.name]
        if not cur or (name == p.name and cur ~= p.name) then idx[p.name] = name end
      end
    end
  end
  for item, name in pairs(book.by_product or {}) do idx[item] = name end -- affectation par clé : l'ordre est sans effet
  return idx
end

--- Quantité de `item` produite par cycle de la recette `r` (1 si la recette ne le dit pas).
local function product_amount(r, item)
  for _, p in ipairs(r.products or {}) do
    if p.name == item then
      local a = p.amount or ((p.amount_min and p.amount_max) and (p.amount_min + p.amount_max) / 2)
      if a and a > 0 then return a end
      return 1
    end
  end
  return 1
end

--- Copie d'un arbre normalisé mise à l'échelle du débit `rate` (linéaire : débits et machines multipliés).
local function scale(node, rate)
  local out = { item = node.item, rate = node.rate * rate, machines = node.machines * rate, recipe = node.recipe,
    bus = node.bus, raw = node.raw, cycle = node.cycle, nodes = {}, bus_needs = {}, total_machines = {} }
  for k, v in pairs(node.bus_needs) do out.bus_needs[k] = v * rate end
  for k, v in pairs(node.total_machines) do out.total_machines[k] = v * rate end
  for i, sub in ipairs(node.nodes) do out.nodes[i] = scale(sub, rate) end
  return out
end

--- Ajoute `src` dans `acc` clé par clé (sommes indépendantes par clé : l'ordre de parcours est sans effet).
local function add_into(acc, src)
  for _, k in ipairs(sorted_keys(src)) do acc[k] = (acc[k] or 0) + src[k] end
end

--- Feuille normalisée : `bus` (fournie), `raw` (sans recette : comptée en matière brute) ou `cycle` (coupe).
local function leaf(item, kind)
  local n = { item = item, rate = 1, machines = 0, nodes = {}, bus_needs = {}, total_machines = {} }
  if kind == "cycle" then
    n.cycle = true
  else
    n.bus_needs[item] = 1
    n[kind] = true
  end
  return n
end

local compute

--- Vrai si un objet développé dans un arbre du cache est en cours de visite (le cache serait alors faux : la descente
--- aurait coupé un cycle sur cet ancêtre). L'ensemble en visite est petit (profondeur de la descente).
local function touches(items, visiting)
  for item in pairs(visiting) do -- simple test d'appartenance : l'ordre est sans effet
    if items[item] then return true end
  end
  return false
end

--- Lecture mémoïsée de l'arbre normalisé (débit 1) de `item` à la vitesse `speed`.
--- Rend : arbre, ensemble des objets développés dedans, ensemble des coupes de cycle sur des ancêtres STRICTS.
--- Un arbre n'entre au cache que sans coupe sur un ancêtre (ses propres cycles, coupés sur lui-même, sont admis) ;
--- un arbre du cache n'est pas relu quand il développe un objet en cours de visite : le résultat ne dépend donc pas
--- de l'historique des appels.
local function lookup(s, item, speed, visiting)
  local by_item = s.cache[item]
  local hit = by_item and by_item[speed]
  if hit and not touches(hit.items, visiting) then
    s.hits = s.hits + 1
    return hit.tree, hit.items, {}
  end
  s.misses = s.misses + 1
  local tree, items, cuts = compute(s, item, speed, visiting)
  if next(cuts) == nil then
    by_item = by_item or {}
    s.cache[item] = by_item
    by_item[speed] = { tree = tree, items = items }
  end
  return tree, items, cuts
end

--- Calcul de l'arbre normalisé : machines par unité de débit = energy ÷ (quantité par cycle × vitesse) ; chaque ingrédient
--- du bus est un besoin direct (aucun sous-arbre) ; chaque autre ingrédient est résolu (via le cache) puis mis à l'échelle
--- de `amount ÷ quantité par cycle`.
compute = function(s, item, speed, visiting)
  if s.bus[item] then return leaf(item, "bus"), {}, {} end
  if visiting[item] then return leaf(item, "cycle"), {}, { [item] = true } end
  local rname = s.index[item]
  local r = rname and s.book.recipes[rname]
  if not r then return leaf(item, "raw"), {}, {} end
  local per = product_amount(r, item)
  local machines = (r.energy or 0.5) / (per * speed)
  local n = { item = item, rate = 1, recipe = rname, machines = machines, nodes = {}, bus_needs = {},
    total_machines = { [rname] = machines } }
  local items, cuts = { [item] = true }, {}
  visiting[item] = true
  for _, ing in ipairs(r.ingredients or {}) do
    local need = (ing.amount or 1) / per
    if s.bus[ing.name] then
      n.bus_needs[ing.name] = (n.bus_needs[ing.name] or 0) + need
    else
      local tree, sub_items, sub_cuts = lookup(s, ing.name, speed, visiting)
      local sub = scale(tree, need)
      n.nodes[#n.nodes + 1] = sub
      if sub.cycle then n.cycle = true end
      add_into(n.bus_needs, sub.bus_needs)
      add_into(n.total_machines, sub.total_machines)
      for k in pairs(sub_items) do items[k] = true end -- unions d'ensembles : l'ordre est sans effet
      for k in pairs(sub_cuts) do cuts[k] = true end
    end
  end
  visiting[item] = nil
  cuts[item] = nil
  return n, items, cuts
end

--- Solveur lié à un livre et à un ensemble `bus = { [objet] = true }`. `opts.speed` : vitesse par défaut (1).
function Solver.new(book, bus, opts)
  opts = opts or {}
  local s = { book = book, bus = bus or {}, index = build_index(book), cache = {}, hits = 0, misses = 0,
    speed = opts.speed or 1 }
  return setmetatable(s, Solver)
end

local function speed_of(s, speed)
  if type(speed) == "number" and speed > 0 then return speed end
  return s.speed
end

--- Arbre de `item` au débit `rate` (objets/s) avec des machines de vitesse `speed`. O(1) en récursion après le premier calcul.
function Solver.solve(s, item, rate, speed)
  local tree = lookup(s, item, speed_of(s, speed), {})
  return scale(tree, type(rate) == "number" and rate or 0)
end

--- Compteurs du cache : { hits, misses } (lectures servies sans calcul / calculs d'arbres normalisés).
function Solver.stats(s)
  return { hits = s.hits, misses = s.misses }
end

local function by_rate_then_name(a, b)
  if a.rate ~= b.rate then return a.rate > b.rate end
  return a.item < b.item
end

--- Les `k` intermédiaires les plus sollicités : `demands = { { item, rate [, speed] } }` ; agrège les débits (et machines) de
--- chaque ingrédient INTERMÉDIAIRE (hors bus, avec recette, hors racines demandées) sur tous les arbres ; liste triée
--- { { item, rate, machines } } par débit décroissant puis nom. `k` nil : toute la liste.
function Solver.hubs(s, demands, k)
  local acc = {}
  local function walk(node, root)
    if not root and node.recipe then
      local a = acc[node.item] or { rate = 0, machines = 0 }
      a.rate = a.rate + node.rate
      a.machines = a.machines + node.machines
      acc[node.item] = a
    end
    for _, sub in ipairs(node.nodes) do walk(sub, false) end
  end
  for _, d in ipairs(demands or {}) do
    local item = d[1] or d.item
    if item ~= nil then walk(Solver.solve(s, item, d[2] or d.rate, d[3] or d.speed), true) end
  end
  local list = {}
  for _, item in ipairs(sorted_keys(acc)) do
    list[#list + 1] = { item = item, rate = acc[item].rate, machines = acc[item].machines }
  end
  table.sort(list, by_rate_then_name)
  if k and #list > k then
    for i = #list, k + 1, -1 do list[i] = nil end
  end
  return list
end

--- « Ratio d'usines » : machines par unité de débit (1 objet/s) de `item`, pour chaque recette de l'arbre ; lu au cache.
function Solver.ratio(s, item, speed)
  local tree = lookup(s, item, speed_of(s, speed), {})
  local out = {}
  for k, v in pairs(tree.total_machines) do out[k] = v end
  return out
end

return Solver
