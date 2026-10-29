--[[
  Tests hors jeu du lot AMELIO-RESSOURCES (30/10) : la galène (âge 9), le plomb, le blindage plombé, et la chaîne du
  thorium (âge 12) qui leur donne leur débouché, mis en jeu tels que le scénario X0 les décrit, avec un seul écart écrit
  (shared/content/galena.lua, shared/content/world.lua, shared/content/guarantee.lua contre shared/content/epochs.lua).

    lua5.2 tests/galena_test.lua
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
local P = require("shared.content.galena")
local W = require("shared.content.world")
local G = require("shared.content.guarantee")

local function x_res(name)
  for _, r in ipairs(X.resources) do if r.name == name then return r end end
end
local function near(a, b, eps) return a and math.abs(a - b) < (eps or 1e-9) end
local function same_list(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i][1] ~= b[i][1] or a[i][2] ~= b[i][2] then return false end
  end
  return true
end

---------------------------------------------------------------------------------------------------
section("Galène : la ressource de X, sans biome, loin du départ")
---------------------------------------------------------------------------------------------------
local gw = W.resources.galena
local gx = x_res("fo-galena")
check(gx ~= nil and gx.epoch == 9 and gx.kind == "ore", "fo-galena : minerai de X, âge 9")
check(gw.resource == gx.name and gw.epoch == gx.epoch and gw.kind == gx.kind, "world.lua : nom, âge, genre de X")
check(gw.item == gx.products[1], "objet du minerai = produit de X (" .. tostring(gw.item) .. ")")
check(gw.category == nil and gx.category == "basic-solid", "catégorie basic-solid : toutes les foreuses")
local mine = T.x_recipe("fo-mine-galena")
check(mine and mine.kind == "mining" and near(gw.mining_time, mine.time), "temps de minage = recette de minage de X (1 s)")
check(gw.biome == nil and gw.autoplace.distance_min == gx.min_distance,
  "sans biome ; autoplace à plus de " .. tostring(gx.min_distance) .. " tuiles (X.min_distance)")
local seeds = {}
local dup = false
for _, k in ipairs(W.resource_order) do
  local s = W.resources[k].autoplace.seed1
  if seeds[s] then dup = true end
  seeds[s] = true
end
check(not dup, "graines d'autoplace toutes différentes (jeu de gisements propre, F198)")
check(W.resource_order[#W.resource_order] == "galena" and W.guarantee_order[#W.guarantee_order] == "galena",
  "galène en DERNIER (lettres d'ordre et sites d'avant inchangés)")

-- Couleur de carte : ΔE76 contre tous les minerais, fluides et sols (sRGB D65 → Lab).
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
local REF = {
  { "fer", { 0.415, 0.525, 0.580 } }, { "cuivre", { 0.803, 0.388, 0.215 } }, { "charbon", { 0, 0, 0 } },
  { "pierre", { 0.690, 0.611, 0.427 } }, { "uranium", { 0, 0.7, 0 } }, { "pétrole", { 0.78, 0.2, 0.77 } },
  { "eau", { 51 / 255, 83 / 255, 95 / 255 } }, { "herbe", { 55 / 255, 53 / 255, 11 / 255 } },
  { "désert", { 138 / 255, 103 / 255, 58 / 255 } },
}
for _, k in ipairs(W.resource_order) do
  if k ~= "galena" then local c = W.resources[k].map_color; REF[#REF + 1] = { k, { c.r, c.g, c.b } } end
end
for _, b in ipairs(W.biomes) do
  local c = b.map_color
  REF[#REF + 1] = { b.name, { c.r / 255, c.g / 255, c.b / 255 } }
end
local gc = { gw.map_color.r, gw.map_color.g, gw.map_color.b }
local worst, worst_name = 1e9, ""
for _, r in ipairs(REF) do
  local d = de(gc, r[2])
  if d < worst then worst, worst_name = d, r[1] end
end
print(string.format("  couleur de carte : ΔE76 %.1f (%s)", worst, worst_name))
check(worst >= 45, string.format("couleur de carte : ΔE76 %.1f au plus proche (%s), >= 45", worst, worst_name))

---------------------------------------------------------------------------------------------------
section("Garantie : 2 gisements de 200 000 à 300-600 tuiles, sans disque de sol")
---------------------------------------------------------------------------------------------------
local gs = G.spec("galena")
check(gs and gs.count == gx.placement.guaranteed.count and gs.count == 2, "2 gisements (X)")
check(gs and gs.dmin == 300 and gs.dmax == 600, "300 à 600 tuiles (X)")
check(gs and gs.tile == nil and gs.fill_tile == "dirt-4" and gs.clear_trees == true and #gs.decoratives == 0,
  "aucun sol posé, eau comblée en dirt-4, arbres retirés du gisement, aucun décor régénéré")
check(gs and gs.icon == "fo-galena", "étiquette de carte : l'objet de la galène")
do
  local totals = {}
  local lo, hi = 1e18, 0
  for seed = 1, 200 do
    local L = G.layout(gs, 400, -50, seed * 7919, 1)
    if L.total < lo then lo = L.total end
    if L.total > hi then hi = L.total end
    totals[#totals + 1] = L.total
    if #L.tiles == 0 or #L.wells ~= 0 then lo = -1 end
  end
  check(lo >= 190000 and hi <= 215000, string.format("site : %d à %d minerais sur 200 graines (environ 200 000, X)", lo, hi))
  check(lo >= 1.5 * gs.min_total, "un site vaut au moins 1,5 × min_total (règle des autres sites)")
end
check(G.units_found(gs, 2 * 130000, 40) == 2 and G.units_found(gs, 129999, 40) == 0,
  "gisement naturel connu : 130 000 = une unité")

---------------------------------------------------------------------------------------------------
section("Objets : ceux de X")
---------------------------------------------------------------------------------------------------
local AGE = { ["fo-lead-plate"] = 9, ["fo-lead-shielding"] = 9, ["fo-thorium-salt-cell"] = 12, ["fo-spent-salt"] = 12 }
for _, n in ipairs(P.ITEMS) do
  local it = T.x_item(n)
  check(it and it.type == "item" and it.epoch == AGE[n], n .. " : objet de X, âge " .. AGE[n])
  check(it and P.stack(n) == it.stack and it.stack >= 50, n .. " : pile de X (" .. tostring(it and it.stack) .. ")")
  check(not T.present(n) or n == "fo-galena", n .. " : neuf (absent des lots X1)")
end
check(T.x_item("fo-galena") and T.x_item("fo-galena").epoch == 9, "fo-galena : objet de X, âge 9")
local fuel = P.fuel()
check(fuel.mj == 32000 and fuel.category == P.FUEL_CATEGORY and fuel.burnt == "fo-spent-salt",
  "cellule : 32 GJ, catégorie fo-thorium, reste fo-spent-salt (X)")

---------------------------------------------------------------------------------------------------
section("Recettes : celles de X, tous les ingrédients en jeu")
---------------------------------------------------------------------------------------------------
local VANILLA_CAT = { smelting = true, crafting = true, chemistry = true, centrifuging = true, ["advanced-crafting"] = true }
local MOD_CAT = {}
for _, b in ipairs(T.BUILDINGS) do for _, c in ipairs(T.x_building(b.name).categories or {}) do MOD_CAT[c] = true end end
for _, rr in ipairs(P.RECIPES) do
  local r = P.process_recipe(rr.name)
  check(r and r.epoch == rr.epoch, rr.name .. " : recette de X, âge " .. rr.epoch)
  check(VANILLA_CAT[r.category] or MOD_CAT[r.category], rr.name .. " : catégorie en jeu (" .. tostring(r.category) .. ")")
  for _, ing in ipairs(r.ingredients) do
    check(P.present(ing[1]), rr.name .. " : ingrédient en jeu " .. ing[1])
  end
  for _, p in ipairs(r.results) do
    check(P.present(p[1]), rr.name .. " : produit en jeu " .. p[1])
  end
  if #r.results > 1 then check(rr.main ~= nil, rr.name .. " : produit principal nommé") end
end
local lp = P.process_recipe("fo-lead-plate")
check(lp.category == "smelting" and near(lp.time, 3.2) and same_list(lp.ingredients, { { "fo-galena", 2 } })
  and same_list(lp.results, { { "fo-lead-plate", 1 } }), "plomb : 2 galènes → 1 plaque, 3,2 s au four (X)")
local ls = P.process_recipe("fo-lead-shielding")
check(ls.category == "crafting" and same_list(ls.ingredients, { { "fo-lead-plate", 3 }, { "steel-plate", 1 } }),
  "blindage plombé : 3 plombs + 1 acier (X)")
check(lp.prod and ls.prod, "plomb et blindage : productivité (X « prod »)")
local ro = P.process_recipe("fo-galena-roasting")
check(ro.category == "fo-arc-smelting" and ro.ingredients[2][1] == "fo-oxygen" and ro.results[2][1] == "sulfur",
  "grillage : four à arc, oxygène (sous-produit de l'électrolyse, lot X2) → soufre")
check(near(P.galena_per_shielding(), 6), "6 galènes par blindage plombé au four (" .. P.galena_per_shielding() .. ")")

---------------------------------------------------------------------------------------------------
section("Réacteur à sels fondus : celui de X, la cellule et le retraitement")
---------------------------------------------------------------------------------------------------
local rx = P.reactor_x()
check(rx.proto == "reactor" and rx.size[1] == 5 and rx.size[2] == 5, "réacteur de X : 5 × 5 (comme le réacteur nucléaire copié)")
check(rx.heat_kw == 160000 and rx.neighbour_bonus == 0 and rx.max_temperature == 1000 and rx.max_transfer_kw == 1000000,
  "160 MW, voisinage 0, 1 000 °C, 1 GW (X)")
check(rx.energy.type == "burner" and rx.energy.fuel_category == P.FUEL_CATEGORY and rx.burnt_inventory == true,
  "brûleur fo-thorium à reste (X)")
local burn = T.x_recipe("fo-burn-thorium-salt")
check(burn and near(P.cell_seconds(), burn.time) and near(P.cell_seconds(), 200),
  "une cellule dure 200 s à 160 MW (= combustion de X, " .. tostring(burn and burn.time) .. " s)")
local rr = P.reactor_recipe()
check(#rr.trace == 0, "recette du réacteur : aucun dépliage (tout est en jeu)")
check(same_list(rr.ingredients, T.x_recipe("fo-molten-salt-reactor").ingredients), "recette du réacteur = X (200 blindages plombés)")
check(near(P.oxide_net_per_cell(), 3.5), "oxyde de thorium net par cellule, retraitement compris : 3,5")
-- Débouché de l'oxyde (D-17) : le lessivage d'une monazite en rend 1 par concentré.
local leach = S.process_recipe("fo-monazite-leaching")
local oxide = 0
for _, p in ipairs(leach.results) do if p[1] == "fo-thorium-oxide" then oxide = p[2] end end
check(oxide == 1, "oxyde de thorium : sous-produit du lessivage (lot X2), consommé par la cellule (ce lot)")
local inside, missing = P.shielding_consumers()
local has_reactor = false
for _, n in ipairs(inside) do if n == "fo-molten-salt-reactor" then has_reactor = true end end
check(has_reactor, "blindage plombé : consommé en jeu par le réacteur (" .. table.concat(inside, ", ") .. ")")
check(#missing >= 5, "consommateurs de X pas encore en jeu notés (" .. #missing .. " : " .. table.concat(missing, ", ") .. ")")

---------------------------------------------------------------------------------------------------
section("Technologies")
---------------------------------------------------------------------------------------------------
local unlocked = {}
for _, t in ipairs(P.TECHS) do
  check(T.x_tech(t.x0) ~= nil, t.name .. " : reprend la technologie de X " .. t.x0)
  for _, u in ipairs(t.unlocks) do
    unlocked[u] = (unlocked[u] or 0) + 1
    local ok = (u == P.REACTOR.name)
    for _, r in ipairs(P.RECIPES) do if r.name == u then ok = true end end
    check(ok, t.name .. " : débloque une recette du lot (" .. u .. ")")
  end
  for _, pr in ipairs(t.prerequisites) do
    local known = pr:find("^fo%-") == nil
    for _, t2 in ipairs(P.TECHS) do if t2.name == pr then known = true end end
    for _, t2 in ipairs(S.TECHS) do if t2.name == pr then known = true end end
    for _, t2 in ipairs(T.TECHS) do if t2.name == pr then known = true end end
    check(known, t.name .. " : prérequis connu " .. pr)
  end
end
for _, r in ipairs(P.RECIPES) do check(unlocked[r.name] == 1, r.name .. " : débloquée une seule fois") end
check(unlocked[P.REACTOR.name] == 1, "réacteur débloqué une seule fois")
check(P.DEVIATIONS["fo-galena-roasting"] ~= nil, "écart écrit : le grillage (âge 9 dans X) attend l'oxygène des supraconducteurs")
local nd = 0
for _ in pairs(P.DEVIATIONS) do nd = nd + 1 end
check(nd == 1, "un seul écart au scénario (" .. nd .. ")")

---------------------------------------------------------------------------------------------------
section("Mutants (le banc doit les refuser)")
---------------------------------------------------------------------------------------------------
do
  -- M1 : recette de plomb altérée → la comparaison à X échoue.
  local r = P.process_recipe("fo-lead-plate")
  local saved = r.ingredients[1][2]
  r.ingredients[1][2] = 1
  check(not near(P.galena_per_shielding(), 6), "M1 : plomb à 1 galène détecté")
  r.ingredients[1][2] = saved
  -- M2 : garantie sans tuile de comblement → G.specs refuse (assert).
  local gu = W.resources.galena.guarantee
  local ft = gu.fill_tile
  gu.fill_tile = nil
  package.loaded["shared.content.guarantee"] = nil
  local G2 = require("shared.content.guarantee")
  local ok = pcall(G2.specs)
  check(not ok, "M2 : ressource sans biome ni fill_tile refusée")
  gu.fill_tile = ft
  package.loaded["shared.content.guarantee"] = G
  -- M3 : couleur de carte grise (fer) → ΔE trop faible.
  check(de({ 0.55, 0.55, 0.60 }, { 0.415, 0.525, 0.580 }) < 45, "M3 : gris de plomb trop près du fer (refusé par la règle ΔE)")
  -- M4 : réacteur à 40 MW (vanilla) → durée d'une cellule fausse.
  local saved_kw = rx.heat_kw
  rx.heat_kw = 40000
  check(not near(P.cell_seconds(), 200), "M4 : réacteur à 40 MW détecté (durée d'une cellule)")
  rx.heat_kw = saved_kw
end

print(string.format("[GALENE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
