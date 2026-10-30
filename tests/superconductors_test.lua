--[[
  Tests hors jeu du lot X2 (25/10) : la chaîne de la monnaie de l'âge 12 (bobine supraconductrice) mise en jeu est celle
  du scénario X0, avec UN écart écrit (cryostat : plastique au lieu du biopolymère) et rien d'inventé
  (shared/content/superconductors.lua, shared/content/world.lua, shared/levels/config.lua contre shared/content/epochs.lua).

    lua5.2 tests/superconductors_test.lua
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(t) print("== " .. t) end

local X = require("shared.content.epochs")
local T = require("shared.content.titanium")
local S = require("shared.content.superconductors")
local W = require("shared.content.world")
local L = require("shared.levels.config")

local function x_res(name)
  for _, r in ipairs(X.resources) do if r.name == name then return r end end
end
local function near(a, b) return a and math.abs(a - b) < 1e-9 end

---------------------------------------------------------------------------------------------------
section("Objets, fluides et machines : ceux de X")
---------------------------------------------------------------------------------------------------
local AGE = { ["fo-cryostat"] = 11, ["fo-oxygen"] = 8 }
for _, n in ipairs(S.ITEMS) do
  local it = T.x_item(n)
  check(it and it.type == "item", n .. " : objet de X")
  check(it and it.epoch == (AGE[n] or 12), n .. " : âge " .. tostring(AGE[n] or 12) .. " (" .. tostring(it and it.epoch) .. ")")
  check(it and it.stack == 100, n .. " : pile de X (100)")
end
for _, n in ipairs(S.FLUIDS) do
  local it = T.x_item(n)
  check(it and it.type == "fluid" and it.epoch == (AGE[n] or 12), n .. " : fluide de X, âge " .. tostring(AGE[n] or 12))
end
check(T.x_item("fo-liquid-nitrogen").temperature == -196 and T.x_item("fo-liquid-oxygen").temperature == -183,
  "températures de X des fluides liquéfiés (-196, -183)")
local AGEB = { ["fo-cryogenic-unit"] = 12, ["fo-extraction-column"] = 12, ["fo-sintering-furnace"] = 5, ["fo-coil-winder"] = 6 }
for _, b in ipairs(S.BUILDINGS) do
  local x = T.x_building(b.name)
  check(x and x.proto == "assembling-machine" and x.epoch == AGEB[b.name], b.name .. " : machine à recette de X, âge " .. AGEB[b.name])
  check(x and x.size[1] == x.size[2], b.name .. " : carrée (" .. tostring(x and x.size[1]) .. ")")
end
check(T.x_building("fo-cryogenic-unit").fluid_in == 2 and T.x_building("fo-cryogenic-unit").fluid_out == 3,
  "unité cryogénique : 2 entrées, 3 sorties (la raffinerie copiée a les mêmes : contrôlé à l'étape data)")
check(#S.new_categories() == 3, "3 catégories neuves, la 4e (fo-winding, bobineuse) vient d'AMELIO-CRAFTS (" .. table.concat(S.new_categories(), ", ") .. ")")
for _, c in ipairs(S.new_categories()) do
  local clash = false
  for _, c2 in ipairs(T.new_categories()) do if c == c2 then clash = true end end
  check(not clash, c .. " : catégorie absente du lot X1")
end

---------------------------------------------------------------------------------------------------
section("Recettes de procédé : celles de X, un seul écart, tout en jeu")
---------------------------------------------------------------------------------------------------
local n_dev = 0
for _, rr in ipairs(S.RECIPES) do
  local r, dev = S.process_recipe(rr.name)
  local xr = T.x_recipe(rr.name)
  check(xr and xr.kind ~= "mining" and r.category == xr.category and r.time == xr.time, rr.name .. " : recette de X (catégorie, durée)")
  local ok = true
  for _, i in ipairs(r.ingredients) do if not S.present(i[1]) then ok = false end end
  for _, p in ipairs(r.results) do if not S.present(p[1]) then ok = false end end
  check(ok, rr.name .. " : ingrédients et produits tous en jeu")
  -- produits et quantités identiques à X ; ingrédients identiques sauf l'écart écrit
  local same = #r.results == #xr.results and #r.ingredients == #xr.ingredients
  for i, p in ipairs(xr.results) do if r.results[i][1] ~= p[1] or r.results[i][2] ~= p[2] then same = false end end
  for i, ing in ipairs(xr.ingredients) do
    local want = dev and dev.replace[ing[1]] or ing[1]
    if r.ingredients[i][1] ~= want or r.ingredients[i][2] ~= ing[2] then same = false end
  end
  check(same, rr.name .. " : quantités de X")
  if dev then n_dev = n_dev + 1 end
  local m = S.machine_for(rr.name)
  check(m ~= nil, rr.name .. " : une machine en jeu la fait (" .. tostring(m) .. ")")
end
check(n_dev == 1 and S.DEVIATIONS["fo-cryostat"].replace["fo-biopolymer"] == "plastic-bar" and not S.present("fo-biopolymer"),
  "un seul écart : cryostat, plastique au lieu du biopolymère (absent du jeu)")
local cr = T.x_recipe("fo-cryostat")
local bio_ok = false
for _, i in ipairs(cr.ingredients) do if i[1] == "fo-biopolymer" and i[2] == 2 then bio_ok = true end end
check(bio_ok, "X n'est pas modifié : son cryostat demande toujours 2 biopolymères")
local vb, vp = X.currency_of(8).value, X.currency_of(4).value
local v_x = X.currency_of(11).value + 2 * vb + X.currency_of(10).value
local v_g = X.currency_of(11).value + 2 * vp + X.currency_of(10).value
check(v_x == 103 and v_g == 101, string.format("cryostat : valeur %d MU au lieu de %d (écart de %.0f %%)", v_g, v_x, 100 * (v_x - v_g) / v_x))
check(S.machine_for("fo-superconducting-coil") == "fo-coil-winder" and S.machine_for("fo-air-distillation") == "fo-cryogenic-unit"
  and S.machine_for("fo-water-electrolysis") == "fo-electrolyzer" and S.machine_for("fo-monazite-concentrate") == "fo-ore-concentrator"
  and S.machine_for("fo-monazite-leaching") == "chemistry" and S.machine_for("fo-superconducting-tape") == "fo-sintering-furnace",
  "machines : bobineuse, unité cryogénique, électrolyseur et concentrateur (lot X1), usine chimique, four de frittage")
check(#T.x_recipe("fo-air-distillation").ingredients == 0, "distillation de l'air : sans ingrédient (X)")

---------------------------------------------------------------------------------------------------
section("Recettes des machines : celles de X, dépliées (règle du lot X1)")
---------------------------------------------------------------------------------------------------
for _, b in ipairs(S.BUILDINGS) do
  local r = S.building_recipe(b.name)
  local ok = true
  for _, i in ipairs(r.ingredients) do if not S.present(i[1]) then ok = false end end
  check(ok and #r.ingredients > 0, b.name .. " : ingrédients tous en jeu")
end
local col = S.building_recipe("fo-extraction-column")
local stone, glass = 0, false
for _, i in ipairs(col.ingredients) do
  if i[1] == "stone" then stone = i[2] end
  if i[1] == "fo-glass" then glass = true end
end
check(stone == 20 and not glass and #col.trace == 2,
  "colonne d'extraction : 10 verres dépliés en 40 sables puis 20 pierres (" .. stone .. ")")
check(#S.building_recipe("fo-cryogenic-unit").trace == 0 and #S.building_recipe("fo-sintering-furnace").trace == 0
  and #S.building_recipe("fo-coil-winder").trace == 0, "unité cryogénique, four de frittage, bobineuse : rien à déplier")
-- La règle du lot X1 garde son comportement (présence par défaut).
-- (Fusion avec AMELIO-CRAFTS : la bobine de l'électrolyseur est en jeu ; le verre, lui, reste déplié par la règle du lot X1.)
check(#select(2, T.expand({ { "fo-glass", 1 } })) > 0, "lot X1 : T.expand garde sa règle de présence par défaut")

---------------------------------------------------------------------------------------------------
section("Technologies")
---------------------------------------------------------------------------------------------------
local unlocked = {}
for _, t in ipairs(S.TECHS) do
  check(T.x_tech(t.x0) ~= nil, t.name .. " : reprend la technologie " .. t.x0 .. " de X")
  for _, r in ipairs(t.unlocks) do
    check(not unlocked[r], r .. " : ouverte une seule fois")
    unlocked[r] = t.name
  end
end
for _, rr in ipairs(S.RECIPES) do check(unlocked[rr.name], rr.name .. " : ouverte par une technologie") end
for _, b in ipairs(S.BUILDINGS) do
  if b.external then
    -- machine d'un autre lot (bobineuse : AMELIO-CRAFTS) : ouverte par SA technologie, pas par celles de ce lot
    local C = require("shared.content.crafts")
    local by = nil
    for _, t in ipairs(C.TECHS) do for _, u in ipairs(t.unlocks) do if u == b.name then by = t.name end end end
    check(by ~= nil and not unlocked[b.name], b.name .. " : ouverte par la technologie de " .. b.external .. " (" .. tostring(by) .. ")")
  else
    check(unlocked[b.name], b.name .. " : ouverte par une technologie")
  end
end
check(unlocked["fo-cryostat"] == "fo-cryostat" and unlocked["fo-superconducting-coil"] == "fo-superconductors",
  "cryostat (âge 11) et bobine (âge 12) : leurs technologies de X")
local xpack = T.x_tech("fo-magnetic-pack")
local all_x = true
for _, r in ipairs(xpack.unlocks) do
  if r ~= "fo-magnetic-pack" and not r:find("^fo%-flare%-") and not unlocked[r] then all_x = false end
end
check(all_x, "tout ce qu'ouvre la technologie de l'âge 12 de X est ouvert, sauf le pack magnétique et les torchères")

---------------------------------------------------------------------------------------------------
section("Monnaie de l'âge 12 et bilan matière")
---------------------------------------------------------------------------------------------------
local cur = X.currency_of(12)
local m = L.epoch_materials[12]
check(cur.item == "fo-superconducting-coil" and m.item == cur.item and m.value == cur.value and not m.provisional
  and L.stack_size[m.item] == cur.stack, "config : monnaie de l'âge 12 = bobine de X (valeur 60, pile 100), plus provisoire")
local pc = S.per_coil()
check(near(pc["fo-monazite-ore"], 8) and near(pc["sulfuric-acid"], 20) and near(pc["light-oil"], 10)
  and near(pc["copper-plate"], 3) and near(pc["water"], 40) and near(pc["fo-titanium-plate"], 1)
  and near(pc["plastic-bar"], 2) and near(pc["processing-unit"], 1),
  string.format("par bobine : 8 monazites, 20 acides, 10 huiles légères, 3 cuivres, 40 eaux, 1 titane, 2 plastiques, 1 processeur"))
check(near(pc["fo-neodymium"], -2) and near(pc["fo-thorium-oxide"], -1) and near(pc["fo-hydrogen"], -40)
  and near(pc["fo-liquid-oxygen"], -6), "sous-produits par bobine : 2 néodymes, 1 oxyde de thorium, 40 hydrogènes, 6 oxygènes liquides")
-- Le minerai garanti suffit : 2 taches × environ 400 000 minerais, à 8 par bobine.
local G = require("shared.content.guarantee")
local spec = G.spec("monazite")
local lay = G.layout(spec, 0, 0, 20261020, 1)
check(lay.total / pc["fo-monazite-ore"] * spec.count >= 80000,
  string.format("2 taches garanties : %d bobines (au moins 80 000)", math.floor(lay.total / 8 * spec.count)))

---------------------------------------------------------------------------------------------------
section("Monazite et sables noirs : ceux de X")
---------------------------------------------------------------------------------------------------
local mz = W.resources.monazite
local xm = x_res("fo-monazite")
check(xm and mz.resource == xm.name and mz.item == xm.products[1] and mz.epoch == xm.epoch, "monazite : ressource, produit, âge de X")
check((mz.category or "basic-solid") == xm.category, "monazite : catégorie de X (" .. xm.category .. ")")
local mine = T.x_recipe("fo-mine-monazite")
check(mine and mz.mining_time == mine.time, "monazite : minage 2 s (pseudo-recette de X)")
check(mz.biome == xm.biome, "monazite : biome des sables noirs (X)")
local tile_ok = false
for _, t in ipairs(X.tiles) do if t.name == "fo-black-sands" and t.epoch == 12 then tile_ok = true end end
local biome
for _, b in ipairs(W.biomes) do if b.name == "fo-black-sands" then biome = b end end
check(tile_ok and biome and biome.ground and W.grain.seed1["fo-black-sands"] and biome.region.seed1,
  "sables noirs : tuile de X, sol ferme, graines numériques (F198)")
local seeds = {}
local dup = false
for _, b in ipairs(W.biomes) do
  local sd = b.region.seed1
  if sd then if seeds[sd] then dup = true end seeds[sd] = true end
end
for _, k in ipairs(W.resource_order) do
  local sd = W.resources[k].autoplace.seed1
  if seeds[sd] then dup = true end
  seeds[sd] = true
end
check(not dup, "graines numériques des régions et des gisements toutes distinctes")
check(mz.sheet and mz.sheet.name == "monazite", "monazite : feuille propre du kit minerai (pas une teinte vanilla, F36)")

---------------------------------------------------------------------------------------------------
section("Mutants (le banc doit les refuser)")
---------------------------------------------------------------------------------------------------
local function mutant(name, f)
  local p, fl = passes, failures
  local ok, refused = pcall(f)
  passes, failures = p, fl
  check(ok and refused, "mutant « " .. name .. " » refusé")
end
mutant("écart retiré (biopolymère gardé)", function()
  local save = S.DEVIATIONS["fo-cryostat"]
  S.DEVIATIONS["fo-cryostat"] = nil
  local r = S.process_recipe("fo-cryostat")
  S.DEVIATIONS["fo-cryostat"] = save
  for _, i in ipairs(r.ingredients) do if not S.present(i[1]) then return true end end
  return false
end)
mutant("bobine sans cryostat", function()
  local r = S.process_recipe("fo-superconducting-coil")
  local copy = {}
  for _, i in ipairs(r.ingredients) do if i[1] ~= "fo-cryostat" then copy[#copy + 1] = i end end
  return #copy ~= #T.x_recipe("fo-superconducting-coil").ingredients
end)
mutant("machine sans catégorie de la bobine", function()
  local b = T.x_building("fo-coil-winder")
  local save = b.categories
  b.categories = { "fo-autre" }
  local m2 = S.machine_for("fo-superconducting-coil")
  b.categories = save
  return m2 ~= "fo-coil-winder"
end)

print(string.format("Résultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
