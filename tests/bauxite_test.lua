--[[
  Tests hors jeu de la piste BAUXITE (lot AMELIO-RESSOURCES, 30/10) : la bauxite et l'aluminium d'X3 (chaîne C, âge 6) mis
  en jeu tels qu'X3 les décrit, avec le pylône haute tension d'X0, sans rien inventer (shared/content/bauxite.lua,
  shared/content/world.lua, shared/content/guarantee.lua contre shared/content/x3.lua et shared/content/epochs.lua).

    lua5.2 tests/bauxite_test.lua
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(t) print("== " .. t) end

local B = require("shared.content.bauxite")
local W = require("shared.content.world")
local G = require("shared.content.guarantee")
local C = require("shared.content.crafts")
local T = require("shared.content.titanium")

local function near(a, b) return a and math.abs(a - b) < 1e-9 end

---------------------------------------------------------------------------------------------------
section("Bauxite : la ressource d'X3")
---------------------------------------------------------------------------------------------------
local bw = W.resources.bauxite
local bx = B.x3_resource("fo-bauxite")
check(bx and bx.epoch == 6 and bx.kind == "ore" and bx.category == "basic-solid", "fo-bauxite : minerai d'X3, âge 6, basic-solid")
check(bw.resource == bx.name and bw.epoch == bx.epoch and bw.item == bx.products[1] and bw.category == nil and bw.biome == nil,
  "world.lua : nom, âge, produit, catégorie de X3 ; sans biome")
check(near(bw.mining_time, B.recipe("fo-mine-bauxite").time), "minage 1 s (X3)")
local ps, ap = bx.placement.patch_set, bw.autoplace
check(ap.seed1 == ps.seed1 and ap.base_density == ps.base_density and ap.base_spots_per_km2 == ps.base_spots_per_km2
  and ap.random_spot_size_minimum == ps.random_spot_size_minimum and ap.random_spot_size_maximum == ps.random_spot_size_maximum,
  "jeu de gisements = patch_set d'X3 (graine 7303, densité, taches)")
check(ap.region.seed1 == ps.region.seed1 and ap.region.threshold == ps.region.threshold and ap.region.scale == ps.region.scale
  and ap.region.moisture_max == ps.region.moisture_max and ap.region.aux_min == ps.region.aux_min,
  "région = X3 (graine 7313, seuil, échelle, climat du désert rouge : humidité ≤ 0,3, aux ≥ 0,6)")
check(ap.distance_min == bx.min_distance and ap.distance_min == 300, "à plus de 300 tuiles (X3)")
do -- graines uniques parmi toutes les ressources en jeu (F198 : graines numériques, jamais une noise-layer de plus)
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

-- Couleur de carte : ΔE76 contre tous les minerais, fluides, sols et l'ennemi (sRGB D65 → Lab ; même formule que
-- tests/galena_test.lua).
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
    { "désert", { 138 / 255, 103 / 255, 58 / 255 } }, { "ennemi", { 1, 0, 0 } }, { "désert rouge", { 0.55, 0.30, 0.17 } },
  }
  for _, k in ipairs(W.resource_order) do
    if k ~= "bauxite" then local c = W.resources[k].map_color; REF[#REF + 1] = { k, { c.r, c.g, c.b } } end
  end
  for _, b in ipairs(W.biomes) do local c = b.map_color; REF[#REF + 1] = { b.name, { c.r / 255, c.g / 255, c.b / 255 } } end
  local bc = { bw.map_color.r, bw.map_color.g, bw.map_color.b }
  local worst, wn = 1e9, ""
  for _, r in ipairs(REF) do local d = de(bc, r[2]) if d < worst then worst, wn = d, r[1] end end
  print(string.format("  couleur de carte : ΔE76 %.1f (%s)", worst, wn))
  check(worst >= 45, string.format("couleur de carte : ΔE76 %.1f au plus proche (%s), >= 45", worst, wn))
end

---------------------------------------------------------------------------------------------------
section("Garantie : 3 gisements de 300 000 à 300-600 tuiles")
---------------------------------------------------------------------------------------------------
local gs = G.spec("bauxite")
check(gs and gs.count == 3 and gs.dmin == 300 and gs.dmax == 600, "3 gisements à 300-600 tuiles (X3)")
check(gs and gs.tile == nil and gs.fill_tile == "red-desert-0" and gs.clear_trees and #gs.decoratives == 0,
  "sans sol posé, eau comblée en désert rouge, arbres retirés, aucun décor")
check(gs and gs.icon == "fo-bauxite", "étiquette de carte : l'objet de la bauxite")
do
  local lo, hi = 1e18, 0
  for seed = 1, 200 do
    local L = G.layout(gs, 420, -60, seed * 104729, 1)
    if L.total < lo then lo = L.total end
    if L.total > hi then hi = L.total end
    if #L.wells ~= 0 then lo = -1 end
  end
  check(lo >= 290000 and hi <= 320000, string.format("site : %d à %d (environ 300 000, X3)", lo, hi))
  check(lo >= 1.5 * gs.min_total, "un site vaut au moins 1,5 × min_total")
end
check(G.units_found(gs, 3 * 190000, 40) == 3 and G.units_found(gs, 189999, 40) == 0, "gisement naturel connu : 190 000 = une unité")
do
  local ig, ir = 0, 0
  for i, k in ipairs(W.guarantee_order) do if k == "bauxite" then ig = i end end
  for i, k in ipairs(W.resource_order) do if k == "bauxite" then ir = i end end
  check(ig == 8 and ir == 9, "bauxite après la cassitérite (sites et lettres d'avant inchangés ; la piste GÉOTHERMIE en ajoute après)")
end

---------------------------------------------------------------------------------------------------
section("Objets, recettes, bâtiments : ceux d'X3 (et le pylône d'X0), tout en jeu")
---------------------------------------------------------------------------------------------------
for _, n in ipairs(B.ITEMS) do
  local it = B.x3_item(n)
  check(it and it.type == "item" and it.epoch == 6 and it.stack >= 50, n .. " : objet d'X3, âge 6")
end
local cell = B.building("fo-reduction-cell")
check(cell.size[1] == 4 and cell.kw == 6000 and cell.categories[1] == "fo-fused-salt-electrolysis" and not cell.fluid_in,
  "cuve : 4 × 4, 6 MW, électrolyse ignée, sans fluide (X3)")
local py = B.building("fo-ht-pylon")
check(py.proto == "electric-pole" and py.size[1] == 2 and py.wire_distance == 64 and py.supply_distance == 0.5 and py.epoch == 6,
  "pylône : poteau 2 × 2, fil de 64 (plafond moteur), alimentation 0,5 (X0)")
local CAT = { chemistry = true, crafting = true, ["fo-crushing"] = true, ["fo-arc-smelting"] = true,
              ["fo-fused-salt-electrolysis"] = true }
for _, rr in ipairs(B.all_recipes()) do
  local r = B.recipe(rr.name)
  check(r.epoch == 6, rr.name .. " : âge 6")
  check(CAT[r.category], rr.name .. " : catégorie en jeu (" .. tostring(r.category) .. ")")
  for _, i in ipairs(r.ingredients) do check(B.present(i[1]), rr.name .. " : ingrédient en jeu " .. i[1]) end
  for _, p in ipairs(r.results) do check(B.present(p[1]), rr.name .. " : produit en jeu " .. p[1]) end
end
check(C.present("fo-graphite") and C.present("fo-cement") and C.present("fo-slag") and C.present("fo-coil"),
  "graphite, ciment, laitier, bobine : en jeu par AMELIO-CRAFTS")
check(not C.present("fo-ht-pylon") and not T.present("fo-ht-pylon"), "le pylône n'était en jeu par aucun autre lot (aucun doublon)")
do -- la boue rouge a ses deux débouchés et chaque objet nouveau sert dans une recette du lot (D-17 : aucun sous-produit détruit)
  local used = {}
  for _, rr in ipairs(B.all_recipes()) do
    for _, i in ipairs(B.recipe(rr.name).ingredients) do used[i[1]] = (used[i[1]] or 0) + 1 end
  end
  check(used["fo-red-mud"] == 2, "boue rouge : deux débouchés (ciment, fer)")
  check(used["fo-bauxite"] and used["fo-alumina"] and used["fo-aluminium-plate"], "bauxite, alumine, aluminium : chacun consommé")
end
do
  local k = B.per_aluminium_plate()
  check(near(k.alumina, 2) and near(k.graphite, 0.5) and near(k.bauxite, 5) and near(k.stone, 1) and near(k.water, 20) and near(k.red_mud, 2),
    string.format("par plaque : %.1f bauxite, %.1f alumine, %.1f graphite, %.1f boue rouge (X3 : « 2 alumines et 0,5 anode »)",
      k.bauxite, k.alumina, k.graphite, k.red_mud))
  check(near(k.kj, 18000), string.format("énergie de la cuve : %.0f kJ par plaque (6 MW × 6 s / 2)", k.kj))
  local s = B.pylon_saving()
  check(s.steel == 4 and s.cable == 4 and s.aluminium == 2, "variante du pylône : 2 aluminiums pour 4 aciers et 4 câbles (X3)")
end

---------------------------------------------------------------------------------------------------
section("Technologies")
---------------------------------------------------------------------------------------------------
local known = {}
for _, ct in ipairs(C.TECHS) do known[ct.name] = true end
for _, t in ipairs(B.TECHS) do
  local src = B.source_tech(t)
  check(src and src.epoch == t.epoch, t.name .. " : technologie de " .. t.from .. ", âge " .. t.epoch)
  local same = src and #src.unlocks == #t.unlocks
  for i, u in ipairs(t.unlocks) do if not src or src.unlocks[i] ~= u then same = false end end
  check(same, t.name .. " : déblocages = " .. t.from)
  local pre = src and (src.prereq or src.prerequisites) or {}
  local same_pre = #pre == #t.prerequisites
  for i, p in ipairs(t.prerequisites) do if pre[i] ~= p then same_pre = false end end
  check(same_pre, t.name .. " : prérequis = " .. t.from)
  for _, p in ipairs(t.prerequisites) do
    local ok = known[p] or not p:find("^fo%-")
    for _, u in ipairs(B.TECHS) do if u.name == p then ok = true end end
    check(ok, t.name .. " : prérequis en jeu " .. p)
  end
  check(B.tech_count(t) >= 10 and #B.packs(6) >= 3, t.name .. " : unités (règle QX9) et packs de l'âge 6")
end
check(B.TECHS[1].count == B.source_tech(B.TECHS[1]).units, "haute tension : 180 unités d'X0")

---------------------------------------------------------------------------------------------------
section("Mutants")
---------------------------------------------------------------------------------------------------
do
  local r = B.recipe("fo-hall-heroult")
  local saved = r.results[1][2]
  r.results[1][2] = 1
  check(not near(B.per_aluminium_plate().alumina, 2), "M1 : électrolyse à 1 plaque détectée")
  r.results[1][2] = saved
  check(not B.present("fo-servo-motor"), "M2 : un objet d'X3 hors de la piste n'est pas déclaré en jeu")
  local a = W.resources.bauxite.autoplace
  local s = a.region.aux_min
  a.region.aux_min = 0.5
  local x = B.x3_resource("fo-bauxite").placement.patch_set.region
  check(a.region.aux_min ~= x.aux_min, "M3 : climat changé détecté")
  a.region.aux_min = s
end

print(string.format("[BAUXITE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
