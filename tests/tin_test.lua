--[[
  Tests hors jeu de la piste ÉTAIN (lot AMELIO-RESSOURCES, 30/10) : la cassitérite et la carte imprimée d'X3 (chaîne A,
  âge 4) mises en jeu telles qu'X3 les décrit, sans rien inventer (shared/content/tin.lua, shared/content/world.lua,
  shared/content/guarantee.lua contre shared/content/x3.lua), avec les objets du lot AMELIO-CRAFTS (verre, éthylène).

    lua5.2 tests/tin_test.lua
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(t) print("== " .. t) end

local Sn = require("shared.content.tin")
local W = require("shared.content.world")
local G = require("shared.content.guarantee")
local C = require("shared.content.crafts")

local function near(a, b) return a and math.abs(a - b) < 1e-9 end

---------------------------------------------------------------------------------------------------
section("Cassitérite : la ressource d'X3")
---------------------------------------------------------------------------------------------------
local cw = W.resources.cassiterite
local cx = Sn.x3_resource("fo-cassiterite")
check(cx and cx.epoch == 4 and cx.kind == "ore" and cx.category == "basic-solid", "fo-cassiterite : minerai d'X3, âge 4, basic-solid")
check(cw.resource == cx.name and cw.epoch == cx.epoch and cw.item == cx.products[1] and cw.category == nil and cw.biome == nil,
  "world.lua : nom, âge, produit, catégorie de X3 ; sans biome")
check(near(cw.mining_time, Sn.x3_recipe("fo-mine-cassiterite").time), "minage 1 s (X3)")
local ps = cx.placement.patch_set
local ap = cw.autoplace
check(ap.seed1 == ps.seed1 and ap.base_density == ps.base_density and ap.base_spots_per_km2 == ps.base_spots_per_km2
  and ap.random_spot_size_minimum == ps.random_spot_size_minimum and ap.random_spot_size_maximum == ps.random_spot_size_maximum,
  "jeu de gisements = patch_set d'X3 (graine 7302, densité, taches)")
check(ap.region.seed1 == ps.region.seed1 and ap.region.threshold == ps.region.threshold and ap.region.scale == ps.region.scale
  and ap.region.elevation_max == ps.region.elevation_max, "région de bruit = X3 (graine 7312, seuil, échelle, basses terres)")
check(ap.distance_min == cx.min_distance, "à plus de " .. cx.min_distance .. " tuiles (X3)")

---------------------------------------------------------------------------------------------------
section("Garantie : 2 gisements de 150 000 à 120-350 tuiles")
---------------------------------------------------------------------------------------------------
local gs = G.spec("cassiterite")
check(gs and gs.count == 2 and gs.dmin == 120 and gs.dmax == 350, "2 gisements à 120-350 tuiles (X3)")
check(gs and gs.tile == nil and gs.fill_tile ~= nil and gs.clear_trees, "sans sol posé, eau comblée, arbres retirés")
do
  local lo, hi = 1e18, 0
  for seed = 1, 200 do
    local L = G.layout(gs, -200, 90, seed * 104729, 1)
    if L.total < lo then lo = L.total end
    if L.total > hi then hi = L.total end
  end
  check(lo >= 140000 and hi <= 165000, string.format("site : %d à %d (environ 150 000, X3)", lo, hi))
  check(lo >= 1.5 * gs.min_total, "un site vaut au moins 1,5 × min_total")
end
local ig, ir = 0, 0
for i, k in ipairs(W.guarantee_order) do if k == "cassiterite" then ig = i end end
for i, k in ipairs(W.resource_order) do if k == "cassiterite" then ir = i end end
check(ig == #W.guarantee_order and ir == #W.resource_order, "cassitérite en dernier (sites et lettres d'avant inchangés)")

---------------------------------------------------------------------------------------------------
section("Objets, recettes, bâtiment : ceux d'X3, tout en jeu")
---------------------------------------------------------------------------------------------------
for _, n in ipairs(Sn.ITEMS) do
  local it = Sn.x3_item(n)
  check(it and it.type == "item" and it.epoch == 4 and it.stack >= 50, n .. " : objet d'X3, âge 4")
end
for _, n in ipairs(Sn.FLUIDS) do check(Sn.x3_item(n) and Sn.x3_item(n).type == "fluid", n .. " : fluide d'X3") end
local b = Sn.x3_building("fo-circuit-printer")
check(b.size[1] == 3 and b.kw == 300 and b.fluid_in == 1 and b.categories[1] == "fo-circuit-printing", "imprimante : 3 × 3, 300 kW, 1 entrée (X3)")
local VAN = { smelting = true, chemistry = true, crafting = true }
for _, rr in ipairs(Sn.RECIPES) do
  local r = Sn.x3_recipe(rr.name)
  check(VAN[r.category] or r.category == "fo-circuit-printing", rr.name .. " : catégorie en jeu (" .. r.category .. ")")
  for _, i in ipairs(r.ingredients) do check(Sn.present(i[1]), rr.name .. " : ingrédient en jeu " .. i[1]) end
  for _, p in ipairs(r.results) do check(Sn.present(p[1]), rr.name .. " : produit en jeu " .. p[1]) end
end
for _, i in ipairs(Sn.x3_recipe("fo-circuit-printer").ingredients) do
  check(Sn.present(i[1]), "imprimante : ingrédient en jeu " .. i[1])
end
check(C.present("fo-glass") and C.present("fo-ethylene"), "verre et éthylène : en jeu par AMELIO-CRAFTS")
local adv = Sn.x3_recipe("fo-pcb-advanced-circuit")
check(adv.variant_of == "advanced-circuit" and adv.results[1][1] == "advanced-circuit" and adv.results[1][2] == 2 and near(adv.time, 6),
  "variante : 2 circuits avancés en 6 s, la recette vanilla reste (nom propre)")
local k = Sn.per_advanced_circuit()
check(near(k.pcb, 0.5) and near(k.tin, 0.25) and near(k.cassiterite, 0.5),
  string.format("par circuit avancé : %.2f carte, %.2f étain, %.2f cassitérite", k.pcb, k.tin, k.cassiterite))

---------------------------------------------------------------------------------------------------
section("Technologie")
---------------------------------------------------------------------------------------------------
local t = Sn.TECHS[1]
local tx = Sn.x3_tech(t.x3)
check(tx and tx.epoch == t.epoch, "fo-printed-circuits : technologie d'X3, âge 4")
local same = #tx.unlocks == #t.unlocks
for i, u in ipairs(t.unlocks) do if tx.unlocks[i] ~= u then same = false end end
check(same, "déblocages = X3 (6)")
local known = {}
for _, ct in ipairs(C.TECHS) do known[ct.name] = true end
for _, p in ipairs(t.prerequisites) do check(known[p] or not p:find("^fo%-"), "prérequis en jeu : " .. p) end
check(Sn.tech_count(t) >= 10 and #Sn.packs(4) >= 3, "unités (règle QX9) et packs de l'âge 4 (" .. table.concat(Sn.packs(4), ", ") .. ")")

---------------------------------------------------------------------------------------------------
section("Mutants")
---------------------------------------------------------------------------------------------------
do
  local r = Sn.x3_recipe("fo-printed-circuit-board")
  local saved = r.results[1][2]
  r.results[1][2] = 1
  local k2 = Sn.per_advanced_circuit()
  check(not near(k2.tin, 0.25), "M1 : carte à 1 par fabrication détectée")
  r.results[1][2] = saved
  check(not Sn.present("fo-silicon-ingot"), "M2 : un objet d'X3 hors de la piste n'est pas déclaré en jeu")
end

print(string.format("[ETAIN] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
