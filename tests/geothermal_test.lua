--[[
  Tests hors jeu de la piste GÉOTHERMIE (lot AMELIO-RESSOURCES, 30/10) : la fumerolle d'X0 (âge 5) mise en jeu telle que le
  scénario la décrit, sans rien inventer (shared/content/geothermal.lua, shared/content/world.lua,
  shared/content/guarantee.lua contre shared/content/epochs.lua).

    lua5.2 tests/geothermal_test.lua
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(t) print("== " .. t) end

local Gt = require("shared.content.geothermal")
local W = require("shared.content.world")
local G = require("shared.content.guarantee")
local C = require("shared.content.crafts")

local function near(a, b) return a and math.abs(a - b) < 1e-9 end

---------------------------------------------------------------------------------------------------
section("Fumerolle : la ressource d'X0")
---------------------------------------------------------------------------------------------------
local fw = W.resources.fumarole
local fx = Gt.x_resource()
check(fx and fx.epoch == 5 and fx.kind == "fluid" and fx.category == "fo-fumarole" and fx.infinite and fx.minimum_share == 0.2,
  "fo-fumarole : fluide infini d'X0, âge 5, catégorie propre, part minimale 0,2")
check(fw.resource == fx.name and fw.epoch == fx.epoch and fw.fluid == fx.products[1] and fw.category == fx.category
  and fw.biome == fx.biome, "world.lua : nom, âge, produit, catégorie et biome (cendres volcaniques) d'X0")
check(fw.copy_resource == "crude-oil", "copie du pétrole : infini, part minimale 60 000 / 300 000 = 0,2 (data/base)")
local mine = Gt.recipe("fo-capture-fumarole")
check(mine.kind == "mining" and mine.resource == fx.name and fw.yield == mine.results[1][2] and near(mine.time, 1),
  "captage : 200 gaz par cycle d'1 s (X0)")
check(Gt.x_item("fo-volcanic-gas").type == "fluid" and fw.fluid_temperature == Gt.x_item("fo-volcanic-gas").temperature,
  "gaz volcanique : fluide d'X0 à 300 °C")
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

-- Couleur de carte (même formule que tests/galena_test.lua) : un puits est un POINT ; seuil 35.
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
    { "eau", { 51 / 255, 83 / 255, 95 / 255 } }, { "ennemi", { 1, 0, 0 } },
  }
  for _, k in ipairs(W.resource_order) do
    if k ~= "fumarole" then local c = W.resources[k].map_color; REF[#REF + 1] = { k, { c.r, c.g, c.b } } end
  end
  for _, b in ipairs(W.biomes) do local c = b.map_color; REF[#REF + 1] = { b.name, { c.r / 255, c.g / 255, c.b / 255 } } end
  local mc = { fw.map_color.r, fw.map_color.g, fw.map_color.b }
  local worst, wn = 1e9, ""
  for _, r in ipairs(REF) do local d = de(mc, r[2]) if d < worst then worst, wn = d, r[1] end end
  print(string.format("  couleur de carte : ΔE76 %.1f (%s)", worst, wn))
  check(worst >= 35, string.format("couleur de carte : ΔE76 %.1f au plus proche (%s), >= 35", worst, wn))
end

---------------------------------------------------------------------------------------------------
section("Garantie : 2 fumerolles sur un disque de cendres à 250-600 tuiles")
---------------------------------------------------------------------------------------------------
local gs = G.spec("fumarole")
check(gs and gs.kind == "fluid" and gs.count == 2 and gs.dmin == 250 and gs.dmax == 600, "2 fumerolles à 250-600 tuiles (X0)")
check(gs and gs.tile == "fo-volcanic-ash" and gs.well_amount == 300000 and gs.icon == "fo-volcanic-gas",
  "disque de cendres volcaniques, puits à 100 %, étiquette : le gaz")
do
  local L = G.layout(gs, 400, 0, 20261020, 2)
  check(#L.wells == 2 and #L.ore == 0 and #L.tiles > 0, "un site : 2 puits, aucun minerai, un disque de sol")
  check(G.sites_for(gs, 2) == 1 and G.units_found(gs, 0, 2) == 2, "un seul site pour les 2 puits ; 2 puits connus = garantie tenue")
end
do
  local ig, ir = 0, 0
  for i, k in ipairs(W.guarantee_order) do if k == "fumarole" then ig = i end end
  for i, k in ipairs(W.resource_order) do if k == "fumarole" then ir = i end end
  check(ig == #W.guarantee_order and ir == #W.resource_order, "fumerolle en dernier (sites et lettres d'avant inchangés)")
end

---------------------------------------------------------------------------------------------------
section("Capteur, recettes, technologie : ceux d'X0, tout en jeu")
---------------------------------------------------------------------------------------------------
local tap = Gt.building("fo-geothermal-tap")
check(tap.proto == "mining-drill" and tap.size[1] == 3 and tap.kw == 300 and tap.mining_speed == 1 and tap.output_fluid
  and tap.resource_categories[1] == "fo-fumarole" and #tap.resource_categories == 1,
  "capteur : foreuse 3 × 3, 300 kW, vitesse 1, sortie de fluide, catégorie fo-fumarole seule (X0)")
for _, i in ipairs(Gt.recipe("fo-geothermal-tap").ingredients) do
  check(Gt.present(i[1]), "capteur : ingrédient en jeu " .. i[1])
end
check(C.present("fo-manometer") and C.present("fo-flare-stack"), "manomètre et torchère : en jeu par AMELIO-CRAFTS")
for _, rr in ipairs(Gt.RECIPES) do
  local r = Gt.recipe(rr.name)
  check(r.epoch == 5, rr.name .. " : recette d'X0, âge 5")
  check(r.category == "chemistry" or r.category == "fo-flaring", rr.name .. " : catégorie en jeu (" .. r.category .. ")")
  for _, i in ipairs(r.ingredients) do check(Gt.present(i[1]), rr.name .. " : ingrédient en jeu " .. i[1]) end
  for _, p in ipairs(r.results) do check(Gt.present(p[1]), rr.name .. " : produit en jeu " .. p[1]) end
end
do
  local tx = Gt.x_tech()
  local same = tx and #tx.unlocks == #Gt.TECH.unlocks
  for i, u in ipairs(Gt.TECH.unlocks) do if not tx or tx.unlocks[i] ~= u then same = false end end
  check(same, "fo-geothermal : déblocages d'X0 (capteur, séparation, torchère)")
  check(tx and tx.epoch == Gt.TECH.epoch and tx.units == Gt.TECH.count, "fo-geothermal : âge 5, 290 unités (X0)")
  local known = { ["fo-tungsten-processing"] = true }
  for _, ct in ipairs(C.TECHS) do known[ct.name] = true end
  for _, p in ipairs(Gt.TECH.prerequisites) do check(known[p], "prérequis en jeu : " .. p) end
  -- chaque ingrédient du mod déblocable : sa technologie est un prérequis (règle de x3_test)
  local by = { ["fo-tungsten-plate"] = "fo-tungsten-processing", ["fo-manometer"] = "fo-glassworks" }
  for _, i in ipairs(Gt.recipe("fo-geothermal-tap").ingredients) do
    if by[i[1]] then
      local ok = false
      for _, p in ipairs(Gt.TECH.prerequisites) do if p == by[i[1]] then ok = true end end
      check(ok, "le capteur demande " .. i[1] .. " : " .. by[i[1]] .. " est un prérequis")
    end
  end
  check(Gt.tech_count(Gt.TECH) >= 10 and #Gt.packs(5) >= 3, "unités (règle QX9) et packs de l'âge 5")
end
do
  local k = Gt.per_tap(1)
  check(near(k.gas, 200) and near(k.steam, 140) and near(k.sulfur, 2) and near(k.kw, 4200) and near(k.plants, 2),
    string.format("une fumerolle à 100 %% : %d gaz/s, %d vapeurs/s, %d soufres/s, %.1f MW, %d usines chimiques (SCENARIO : 4,2 MW)",
      k.gas, k.steam, k.sulfur, k.kw / 1000, k.plants))
  local k2 = Gt.per_tap(0.2)
  check(near(k2.kw, 840), "au plancher (20 %) : 0,84 MW")
end

---------------------------------------------------------------------------------------------------
section("Mutants")
---------------------------------------------------------------------------------------------------
do
  local r = Gt.recipe("fo-volcanic-gas-separation")
  local saved = r.results[1][2]
  r.results[1][2] = 50
  check(not near(Gt.per_tap(1).kw, 4200), "M1 : séparation à 50 vapeurs détectée")
  r.results[1][2] = saved
  check(not Gt.present("fo-helium"), "M2 : l'hélium (âge 12) n'est pas déclaré en jeu")
  local y = W.resources.fumarole.yield
  W.resources.fumarole.yield = 10
  check(W.resources.fumarole.yield ~= mine.results[1][2], "M3 : rendement du pétrole (10) détecté")
  W.resources.fumarole.yield = y
end

print(string.format("[GEOTHERMIE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
