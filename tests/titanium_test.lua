--[[
  Tests hors jeu du lot X1-TITANE (25/10) : la chaîne du titane mise en jeu est celle du scénario X0, sans rien
  inventer (shared/content/titanium.lua, shared/content/world.lua, shared/levels/config.lua contre
  shared/content/epochs.lua).

    lua5.2 tests/titanium_test.lua
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(t) print("== " .. t) end

local X = require("shared.content.epochs")
local T = require("shared.content.titanium")
local W = require("shared.content.world")
local L = require("shared.levels.config")

local function x_res(name)
  for _, r in ipairs(X.resources) do if r.name == name then return r end end
end

---------------------------------------------------------------------------------------------------
section("Objets, fluides et machines : ceux de X")
---------------------------------------------------------------------------------------------------
for _, n in ipairs(T.ITEMS) do
  local it = T.x_item(n)
  check(it and it.type == "item", n .. " : objet de X")
  check(it and (it.epoch == 11 or n == "fo-coke"), n .. " : âge 11 (sauf le coke, âge 2)")
end
for _, n in ipairs(T.FLUIDS) do
  local it = T.x_item(n)
  check(it and it.type == "fluid", n .. " : fluide de X")
end
local cats = {}
for _, b in ipairs(T.BUILDINGS) do
  local x = T.x_building(b.name)
  check(x and x.proto == "assembling-machine", b.name .. " : machine à recette de X")
  check(x and x.size[1] == x.size[2], b.name .. " : carrée (" .. tostring(x and x.size[1]) .. ")")
  for _, c in ipairs(x and x.categories or {}) do cats[c] = true end
end
check(#T.new_categories() == 5, "5 catégories neuves (" .. table.concat(T.new_categories(), ", ") .. ")")

---------------------------------------------------------------------------------------------------
section("Recettes de procédé : celles de X, tous les ingrédients en jeu")
---------------------------------------------------------------------------------------------------
local made = {}
for _, rr in ipairs(T.RECIPES) do
  local r = T.process_recipe(rr.name)
  check(r and r.kind ~= "mining", rr.name .. " : recette de X")
  local ok = true
  for _, i in ipairs(r.ingredients) do if not T.present(i[1]) then ok = false end end
  for _, p in ipairs(r.results) do
    if not T.present(p[1]) then ok = false end
    made[p[1]] = true
  end
  check(ok, rr.name .. " : ingrédients et produits tous en jeu")
  check(cats[r.category] or r.category == "chemistry", rr.name .. " : catégorie " .. r.category .. " faite par une machine en jeu")
  if #r.results > 1 then
    local found = false
    for _, p in ipairs(r.results) do if p[1] == rr.main then found = true end end
    check(found, rr.name .. " : produit principal parmi les produits (" .. tostring(rr.main) .. ")")
  end
end
-- Chaque intermédiaire de la chaîne est fabriqué par une recette en jeu (ou miné / pompé).
for _, n in ipairs(T.ITEMS) do
  check(made[n] or n == W.resources.ilmenite.item, n .. " : fabriqué en jeu (ou miné)")
end
for _, n in ipairs(T.FLUIDS) do
  check(made[n] or n == W.resources.brine.fluid, n .. " : produit en jeu (ou pompé)")
end

---------------------------------------------------------------------------------------------------
section("Bilan matière d'une plaque (X : 16 minerais, 3 cokes, 30 chlores nets)")
---------------------------------------------------------------------------------------------------
do
  local function amount(r, name, list)
    for _, p in ipairs(r[list]) do if p[1] == name then return p[2] end end
    return 0
  end
  local conc = T.process_recipe("fo-ilmenite-concentrate")
  local smelt = T.process_recipe("fo-ilmenite-smelting")
  local chl = T.process_recipe("fo-chlorination")
  local kroll = T.process_recipe("fo-kroll-reduction")
  local mg = T.process_recipe("fo-magnesium-electrolysis")
  local plate = T.process_recipe("fo-titanium-plate")
  -- 1 plaque = 1 éponge = 40 TiCl4 = 1 laitier = 2 concentrés = 16 minerais
  local ore = amount(smelt, "fo-ilmenite-concentrate", "ingredients") * amount(conc, "fo-ilmenite-ore", "ingredients")
  check(ore == 16 and amount(plate, "fo-titanium-sponge", "ingredients") == 1
    and amount(chl, "fo-titanium-tetrachloride", "results") == amount(kroll, "fo-titanium-tetrachloride", "ingredients"),
    "16 minerais d'ilménite par plaque (" .. ore .. ")")
  local coke = amount(smelt, "fo-coke", "ingredients") + amount(chl, "fo-coke", "ingredients")
  check(coke == 3, "3 cokes par plaque (" .. coke .. ")")
  local cl_net = amount(chl, "fo-chlorine", "ingredients") - amount(kroll, "fo-magnesium-chloride", "results") * amount(mg, "fo-chlorine", "results")
  check(cl_net == 30, "30 chlores nets par plaque, la boucle du magnésium rend le reste (" .. cl_net .. ")")
  check(amount(kroll, "fo-magnesium", "ingredients") == amount(kroll, "fo-magnesium-chloride", "results")
    and amount(mg, "fo-magnesium", "results") == amount(mg, "fo-magnesium-chloride", "ingredients"),
    "boucle du magnésium fermée (2 magnésium -> 2 chlorures -> 2 magnésium)")
  -- Sous-produits de la saumure : le tungstène par voie humide consomme exactement l'hydrogène et la soude d'une électrolyse.
  local brine = T.process_recipe("fo-brine-electrolysis")
  local wet = T.process_recipe("fo-wet-tungsten")
  check(amount(brine, "fo-hydrogen", "results") == amount(wet, "fo-hydrogen", "ingredients")
    and amount(brine, "fo-caustic-soda", "results") == amount(wet, "fo-caustic-soda", "ingredients"),
    "hydrogène et soude d'une électrolyse de saumure = une fabrication de tungstène par voie humide")
end

---------------------------------------------------------------------------------------------------
section("Règle « déplier » (recettes des bâtiments)")
---------------------------------------------------------------------------------------------------
do
  local e, tr = T.expand({ { "fo-coil", 1 } })
  local got = {}
  for _, i in ipairs(e) do got[i[1]] = i[2] end
  -- 1 bobine = 4 fils émaillés (2 câbles + 1 plastique) + 2 tôles magnétiques (2 aciers + 1 sable = 0,5 pierre)
  check(got["copper-cable"] == 2 and got["plastic-bar"] == 1 and got["steel-plate"] == 2 and got["stone"] == 1,
    "1 bobine = 2 câbles + 1 plastique + 2 aciers + 1 pierre (0,5 arrondi au-dessus)")
  check(#tr == 4 and tr[1][1] == "fo-coil", "trace du dépliage : bobine, fil émaillé, tôle magnétique, sable (" .. #tr .. ")")
  local e10 = T.expand({ { "fo-coil", 10 } })
  local g10 = {}
  for _, i in ipairs(e10) do g10[i[1]] = i[2] end
  check(g10["stone"] == 5 and g10["steel-plate"] == 20, "arrondi À LA FIN : 10 bobines = 5 pierres, 20 aciers")
  check(#T.expand({ { "iron-plate", 3 }, { "fo-tungsten-plate", 2 } }) == 2, "rien à déplier : liste inchangée")
end
local all_unlocked = {}
for _, t in ipairs(T.TECHS) do for _, r in ipairs(t.unlocks) do all_unlocked[r] = true end end
for _, b in ipairs(T.BUILDINGS) do
  local r = T.building_recipe(b.name)
  local ok = true
  for _, i in ipairs(r.ingredients) do if not T.present(i[1]) then ok = false end end
  check(ok, b.name .. " : recette du bâtiment, ingrédients tous en jeu après dépliage")
  check(all_unlocked[b.name], b.name .. " : ouverte par une technologie du lot")
end
for _, rr in ipairs(T.RECIPES) do check(all_unlocked[rr.name], rr.name .. " : ouverte par une technologie du lot") end
do
  local r = T.building_recipe("fo-kroll-reactor")
  local g = {}
  for _, i in ipairs(r.ingredients) do g[i[1]] = i[2] end
  check(g["steel-plate"] == 50 and g["fo-tungsten-plate"] == 20 and g["processing-unit"] == 10 and g["copper-cable"] == 20,
    "réacteur de Kroll : 30 aciers + 20 tungstènes + 10 bobines (dépliées) + 10 processeurs")
end

---------------------------------------------------------------------------------------------------
section("Ressources de carte et biome : ceux de X")
---------------------------------------------------------------------------------------------------
local il, br = x_res("fo-ilmenite"), x_res("fo-brine")
check(il and W.resources.ilmenite.resource == il.name and W.resources.ilmenite.category == il.category
  and W.resources.ilmenite.item == il.products[1] and W.resources.ilmenite.epoch == il.epoch,
  "ilménite : nom, catégorie (minerai dur), produit et âge de X")
check(br and W.resources.brine.resource == br.name and W.resources.brine.fluid == br.products[1] and br.infinite
  and W.resources.brine.copy_resource == "crude-oil", "saumure : nom, produit de X ; infinie (copie du pétrole, part minimale 0,2)")
local tile_ok = false
for _, t in ipairs(X.tiles) do if t.name == "fo-crater-fields" and t.epoch == 11 and t.biome then tile_ok = true end end
local biome_ok = false
for _, b in ipairs(W.biomes) do if b.name == "fo-crater-fields" and b.region.seed1 and not b.region.seed then biome_ok = true end end
check(tile_ok and biome_ok and W.resources.ilmenite.biome == il.biome and W.resources.brine.biome == br.biome,
  "champs de cratères : biome de X, région à graine NUMÉRIQUE (aucune noise-layer neuve, F198)")
check(W.resources.ilmenite.sheet and W.resources.ilmenite.sheet.name == "ilmenite", "ilménite : feuille propre du kit minerai")

---------------------------------------------------------------------------------------------------
section("Monnaie de l'âge 11")
---------------------------------------------------------------------------------------------------
local c11 = X.currency_of(11)
local m11 = L.epoch_materials[11]
check(m11.item == c11.item and m11.value == c11.value and not m11.provisional,
  "config : plaque de titane, valeur de X (" .. tostring(m11.value) .. "), plus provisoire")
check(L.stack_size[m11.item] == c11.stack and T.x_item(m11.item).stack == c11.stack, "pile de X (" .. tostring(c11.stack) .. ")")
check(L.item_value[m11.item] == c11.value, "valeur unique (L.item_value)")
local any_lds = false
for _, f in ipairs(L.families) do
  for n = 2, f.max do
    for _, c in ipairs(L.cost(f, n)) do if c[1] == "low-density-structure" then any_lds = true end end
  end
end
check(not any_lds, "aucun niveau ne demande plus de structure basse densité")

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
