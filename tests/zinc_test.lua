--[[
  Tests hors jeu de la piste ZINC (lot AMELIO-RESSOURCES, 30/10) : la blende et le laiton d'X3 (âge 3) mis en jeu tels
  qu'X3 les décrit, sans rien inventer (shared/content/zinc.lua, shared/content/world.lua, shared/content/guarantee.lua
  contre shared/content/x3.lua).

    lua5.2 tests/zinc_test.lua
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(t) print("== " .. t) end

local Z = require("shared.content.zinc")
local W = require("shared.content.world")
local G = require("shared.content.guarantee")
local C = require("shared.content.crafts")

local function near(a, b) return a and math.abs(a - b) < 1e-9 end

---------------------------------------------------------------------------------------------------
section("Blende : la ressource d'X3")
---------------------------------------------------------------------------------------------------
local sw = W.resources.sphalerite
local sx = Z.x3_resource("fo-sphalerite")
check(sx and sx.epoch == 3 and sx.kind == "ore" and sx.category == "basic-solid", "fo-sphalerite : minerai d'X3, âge 3, basic-solid")
check(sw.resource == sx.name and sw.epoch == sx.epoch and sw.item == sx.products[1] and sw.category == nil and sw.biome == nil,
  "world.lua : nom, âge, produit, catégorie de X3 ; sans biome")
check(near(sw.mining_time, Z.recipe("fo-mine-sphalerite").time), "minage 1 s (X3)")
local ps, ap = sx.placement.patch_set, sw.autoplace
check(ap.seed1 == ps.seed1 and ap.base_density == ps.base_density and ap.base_spots_per_km2 == ps.base_spots_per_km2
  and ap.random_spot_size_minimum == ps.random_spot_size_minimum and ap.random_spot_size_maximum == ps.random_spot_size_maximum,
  "jeu de gisements = patch_set d'X3 (graine 7301)")
check(ap.region.seed1 == ps.region.seed1 and ap.region.threshold == ps.region.threshold and ap.region.scale == ps.region.scale,
  "région = X3 (graine 7311, seuil, échelle)")
check(ap.distance_min == sx.min_distance and ap.distance_min == 150, "à plus de 150 tuiles (X3)")
do
  local seen, dup = {}, nil
  for _, k in ipairs(W.resource_order) do
    local a = W.resources[k].autoplace
    for _, s in ipairs({ a.seed1, a.region and a.region.seed1 }) do
      if seen[s] then dup = k .. " " .. s end
      seen[s] = true
    end
  end
  check(dup == nil, "graines d'autoplace toutes différentes (" .. tostring(dup) .. ")")
end

local function lab(c)
  local function lin(u) if u <= 0.04045 then return u / 12.92 end return ((u + 0.055) / 1.055) ^ 2.4 end
  local r, g, b = lin(c[1]), lin(c[2]), lin(c[3])
  local x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
  local y = 0.2126 * r + 0.7152 * g + 0.0722 * b
  local z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
  local function f(t) if t > 0.008856 then return t ^ (1 / 3) end return 7.787 * t + 16 / 116 end
  return { 116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)) }
end
local function de(a, b)
  local p, q = lab(a), lab(b)
  return math.sqrt((p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 + (p[3] - q[3]) ^ 2)
end
do
  local REF = {
    { "fer", { 0.415, 0.525, 0.580 } }, { "cuivre", { 0.803, 0.388, 0.215 } }, { "charbon", { 0, 0, 0 } },
    { "pierre", { 0.690, 0.611, 0.427 } }, { "uranium", { 0, 0.7, 0 } }, { "pétrole", { 0.78, 0.2, 0.77 } },
    { "eau", { 51 / 255, 83 / 255, 95 / 255 } }, { "herbe", { 55 / 255, 53 / 255, 11 / 255 } },
    { "désert", { 138 / 255, 103 / 255, 58 / 255 } }, { "ennemi", { 1, 0, 0 } },
  }
  for _, k in ipairs(W.resource_order) do
    if k ~= "sphalerite" then local c = W.resources[k].map_color; REF[#REF + 1] = { k, { c.r, c.g, c.b } } end
  end
  for _, b in ipairs(W.biomes) do local c = b.map_color; REF[#REF + 1] = { b.name, { c.r / 255, c.g / 255, c.b / 255 } } end
  local mc = { sw.map_color.r, sw.map_color.g, sw.map_color.b }
  local worst, wn = 1e9, ""
  for _, r in ipairs(REF) do local d = de(mc, r[2]) if d < worst then worst, wn = d, r[1] end end
  print(string.format("  couleur de carte : ΔE76 %.1f (%s)", worst, wn))
  check(worst >= 45, string.format("couleur de carte : ΔE76 %.1f au plus proche (%s), >= 45", worst, wn))
end

---------------------------------------------------------------------------------------------------
section("Garantie : 2 gisements de 200 000 à 150-400 tuiles")
---------------------------------------------------------------------------------------------------
local gs = G.spec("sphalerite")
check(gs and gs.count == 2 and gs.dmin == 150 and gs.dmax == 400, "2 gisements à 150-400 tuiles (X3)")
check(gs and gs.tile == nil and gs.fill_tile == "dirt-4" and gs.clear_trees and #gs.decoratives == 0 and gs.icon == "fo-sphalerite",
  "sans sol posé, eau comblée en terre, arbres retirés ; étiquette : l'objet")
do
  local lo, hi = 1e18, 0
  for seed = 1, 200 do
    local L = G.layout(gs, -250, 40, seed * 7919, 1)
    if L.total < lo then lo = L.total end
    if L.total > hi then hi = L.total end
  end
  check(lo >= 190000 and hi <= 215000, string.format("site : %d à %d (environ 200 000, X3)", lo, hi))
  check(lo >= 1.5 * gs.min_total, "un site vaut au moins 1,5 × min_total")
end
do
  local ig, ir = 0, 0
  for i, k in ipairs(W.guarantee_order) do if k == "sphalerite" then ig = i end end
  for i, k in ipairs(W.resource_order) do if k == "sphalerite" then ir = i end end
  check(ig == #W.guarantee_order and ir == #W.resource_order, "blende en dernier (sites et lettres d'avant inchangés)")
end

---------------------------------------------------------------------------------------------------
section("Objets, recettes : ceux d'X3, tout en jeu")
---------------------------------------------------------------------------------------------------
for _, n in ipairs(Z.ITEMS) do
  local it = Z.x3_item(n)
  check(it and it.type == "item" and it.epoch == 3 and it.stack >= 50, n .. " : objet d'X3, âge 3")
end
local CAT = { crafting = true, ["fo-coking"] = true, ["fo-blast-furnace"] = true }
for _, rr in ipairs(Z.RECIPES) do
  local r = Z.recipe(rr.name)
  check(r.epoch == 3 and CAT[r.category], rr.name .. " : âge 3, catégorie en jeu (" .. r.category .. ")")
  for _, i in ipairs(r.ingredients) do check(Z.present(i[1]), rr.name .. " : ingrédient en jeu " .. i[1]) end
  for _, p in ipairs(r.results) do check(Z.present(p[1]), rr.name .. " : produit en jeu " .. p[1]) end
end
check(C.present("fo-coke-oven") and C.present("fo-blast-furnace") and C.present("fo-glass") and C.present("fo-manometer"),
  "four à coke, haut fourneau, verre, manomètre : en jeu (X1, AMELIO-CRAFTS)")
check(Z.recipe("fo-manometer-brass").variant_of == "fo-manometer", "manomètre à tube de Bourdon : variante, la voie d'X0 reste")
do
  local k = Z.per_manometer()
  check(near(k.brass, 0.5) and near(k.zinc, 1 / 6) and near(k.copper, 1 / 3) and near(k.sphalerite, 1 / 3),
    string.format("par manomètre : %.2f laiton, %.3f zinc, %.3f cuivre, %.3f blende", k.brass, k.zinc, k.copper, k.sphalerite))
end
do
  local same = #Z.EXTEND.unlocks == 3
  for i, u in ipairs({ "fo-zinc-retort", "fo-brass", "fo-manometer-brass" }) do if Z.EXTEND.unlocks[i] ~= u then same = false end end
  check(same, "X3.extends : la verrerie débloque cornue, laiton, manomètre à tube de Bourdon")
  local glass
  for _, t in ipairs(C.TECHS) do if t.name == Z.EXTEND.tech then glass = t end end
  check(glass and glass.epoch == 3, "fo-glassworks : technologie en jeu (AMELIO-CRAFTS), âge 3")
end

---------------------------------------------------------------------------------------------------
section("Mutants")
---------------------------------------------------------------------------------------------------
do
  local r = Z.recipe("fo-brass")
  local saved = r.results[1][2]
  r.results[1][2] = 1
  check(not near(Z.per_manometer().zinc, 1 / 6), "M1 : laiton à 1 par fabrication détecté")
  r.results[1][2] = saved
  check(not Z.present("fo-servo-motor"), "M2 : un objet d'X3 hors des pistes n'est pas déclaré en jeu")
end

print(string.format("[ZINC] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
