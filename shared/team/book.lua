--[[
  Livre de recettes du cerveau d'équipe — PUR (aucune API Factorio).

  Construit à partir des VRAIES recettes du jeu (runtime : game.recipe_prototypes ; tests : fixture générée
  par tests/datastage/harness.lua --dump-recipes). Répond à « comment obtenir N objets X à partir du stock » :
  liste ordonnée de fabrications à la main (ingrédients d'abord) + matières premières manquantes.

  Seules les recettes « crafting » à ingrédients solides et produit unique sont fabricables à la main (règle
  du personnage vanilla). Tout le reste (plaques, acier, briques : fours ; fluides : usines) est une matière
  « première » pour ce livre : le cerveau la fait produire par les avant-postes ou la fonderie.
]]

local Book = {}
Book.__index = Book

local MAX_DEPTH = 12

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- recipes = { [nom] = { category, energy, hidden, ingredients = {{type,name,amount}}, products = {...} } }
function Book.new(recipes, opts)
  opts = opts or {}
  local handcraft = opts.handcraft or { crafting = true }
  local b = setmetatable({ recipes = recipes, by_product = {} }, Book)
  for _, name in ipairs(sorted_keys(recipes)) do
    local r = recipes[name]
    local p = r.products[1]
    local ok = handcraft[r.category] and not r.hidden and #r.products == 1 and p and p.type ~= "fluid"
    if ok then
      for _, ing in ipairs(r.ingredients) do
        if ing.type == "fluid" then ok = false break end
      end
    end
    if ok and (opts.allowed == nil or opts.allowed(name)) then
      local cur = b.by_product[p.name]
      -- Préférence : la recette qui porte le nom du produit, sinon la première par ordre alphabétique.
      if not cur or (name == p.name and cur ~= p.name) then b.by_product[p.name] = name end
    end
  end
  return b
end

function Book:recipe_for(item)
  return self.by_product[item]
end

function Book:handcraftable(item)
  return self.by_product[item] ~= nil
end

--- Planifie l'obtention des `wants` ({ {objet, n}, ... }, dans l'ordre de priorité) à partir de `stock`
--- ({ [objet] = n }, non modifié). Renvoie :
---   crafts = { { recipe, runs, energy }, ... }  ordre exécutable (ingrédients avant produits)
---   raw    = { [objet] = n }                    matières à produire autrement (avant-postes, fonderie)
---   avail  = stock virtuel restant après le plan
---   uses   = { [objet] = n }                    objets à prélever dans le stock
function Book:plan(wants, stock)
  local avail = {}   -- stock réel restant
  for k, v in pairs(stock or {}) do avail[k] = v end
  local made = {}    -- surplus de fabrications du plan (ex. câbles produits par paires)
  local runs, order, raw, uses = {}, {}, {}, {}
  local recipes, by_product = self.recipes, self.by_product

  local function need(item, n, depth)
    local m = made[item] or 0
    if m > 0 then
      local t = m < n and m or n
      made[item] = m - t
      n = n - t
      if n <= 0 then return end
    end
    local have = avail[item] or 0
    local take = have < n and have or n
    if take > 0 then
      avail[item] = have - take
      uses[item] = (uses[item] or 0) + take
      n = n - take
      if n <= 0 then return end
    end
    local rname = depth < MAX_DEPTH and by_product[item] or nil
    if not rname then
      raw[item] = (raw[item] or 0) + n
      return
    end
    local r = recipes[rname]
    local per = r.products[1].amount
    local k = math.ceil(n / per)
    for _, ing in ipairs(r.ingredients) do need(ing.name, ing.amount * k, depth + 1) end
    if not runs[rname] then
      runs[rname] = 0
      order[#order + 1] = rname
    end
    runs[rname] = runs[rname] + k
    local surplus = k * per - n
    if surplus > 0 then made[item] = (made[item] or 0) + surplus end
  end

  for _, w in ipairs(wants) do need(w[1], w[2], 0) end
  local crafts = {}
  for _, rname in ipairs(order) do
    crafts[#crafts + 1] = { recipe = rname, runs = runs[rname], energy = recipes[rname].energy * runs[rname] }
  end
  return { crafts = crafts, raw = raw, avail = avail, uses = uses }
end

--- Matières premières totales d'une liste d'objets (sans stock) : pour l'affichage « il manque ».
function Book:raw_cost(wants)
  return self:plan(wants, {}).raw
end

--- Construit le livre depuis les prototypes du jeu (runtime). Mis en cache par le module appelant.
function Book.from_game(game_recipes, opts)
  local recipes = {}
  for name, r in pairs(game_recipes) do
    local ings, prods = {}, {}
    for _, i in ipairs(r.ingredients) do ings[#ings + 1] = { type = i.type, name = i.name, amount = i.amount } end
    for _, p in ipairs(r.products) do
      local amount = p.amount or ((p.amount_min and p.amount_max) and (p.amount_min + p.amount_max) / 2) or 1
      prods[#prods + 1] = { type = p.type, name = p.name, amount = amount }
    end
    recipes[name] = { category = r.category, energy = r.energy, hidden = r.hidden, ingredients = ings, products = prods }
  end
  return Book.new(recipes, opts)
end

return Book
