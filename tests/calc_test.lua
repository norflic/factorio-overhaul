--[[
  Tests hors jeu du CALCULATEUR D'ÉQUILIBRE (piste CALCULS, nuit du 29 au 30/10) : tools/calc/mu.lua (matière brute
  par programme linéaire), tools/calc/modele.lua (modules, chaînes, calendrier), tools/calc/equilibre.lua (document).
  Usage, depuis la racine du mod : lua5.2 tests/calc_test.lua   (environ 3 s)

  Partie 1 : fixtures minuscules, une règle par contrôle, un MUTANT par règle (la règle cassée doit faire échouer).
  Partie 2 : données réelles (tools/calc/donnees.lua, `harness.lua --dump-calc`) : repères vanilla, uranium, aucune
  boucle productive sous la productivité maximale, calendrier déclaré = calendrier X0, document à jour.
]]

package.path = "./?.lua;" .. package.path
local MU = require("tools.calc.mu")

local ok_n, fail_n = 0, 0
local function check(cond, msg)
  if cond then ok_n = ok_n + 1 else fail_n = fail_n + 1; print("ECHEC : " .. msg) end
end
local function near(a, b, tol) return math.abs(a - b) <= (tol or 1e-6) * math.max(1, math.abs(b)) end

local function item(n, a, extra)
  local t = { type = "item", name = n, amount = a }
  for k, v in pairs(extra or {}) do t[k] = v end
  return t
end
local function fluid(n, a) return { type = "fluid", name = n, amount = a } end

--- Fixture : minerai, plaque, uranium (traitement probabiliste, Kovarex), gisement fluide, gisement à acide,
--- pile combustible (résidu), satellite (lancement), objet inaccessible.
local function fixture()
  return {
    resources = {
      ore = { category = "basic-solid", mining_time = 1, results = { item("ore", 1) } },
      uore = { category = "basic-solid", mining_time = 2, results = { item("uore", 1) }, required_fluid = "acid", fluid_amount = 10 },
      oil = { category = "basic-fluid", mining_time = 1, results = { fluid("oil", 10) } },
    },
    recipes = {
      plate = { category = "smelting", energy = 3.2, ingredients = { item("ore", 1) }, products = { item("plate", 1) } },
      acid = { category = "chemistry", energy = 1, ingredients = { fluid("oil", 10), fluid("water", 100) }, products = { fluid("acid", 50) } },
      proc = { category = "centrifuging", energy = 12, ingredients = { item("uore", 10) },
        products = { item("u235", 1, { probability = 0.007 }), item("u238", 1, { probability = 0.993 }) } },
      kov = { category = "centrifuging", energy = 60, ingredients = { item("u235", 40), item("u238", 5) },
        products = { item("u235", 41, { catalyst_amount = 40 }), item("u238", 2, { catalyst_amount = 2 }) } },
      ["rocket-part"] = { category = "rocket-building", energy = 1, ingredients = { item("plate", 10) }, products = { item("rocket-part", 1) } },
      sat = { category = "crafting", energy = 1, ingredients = { item("plate", 100) }, products = { item("sat", 1) } },
      cell = { category = "crafting", energy = 10, ingredients = { item("plate", 10), item("u235", 1), item("u238", 19) }, products = { item("cell", 10) } },
      repro = { category = "centrifuging", energy = 60, ingredients = { item("used", 5) }, products = { item("u238", 3) } },
      ghost = { category = "crafting", energy = 1, ingredients = { item("nothing", 1) }, products = { item("ghost", 1) } },
      unghost = { category = "crafting", energy = 1, ingredients = { item("ghost", 1) }, products = { item("nothing", 1) } },
      ["fo-lot10-plate"] = { category = "smelting", energy = 32, ingredients = { item("ore", 1) }, products = { item("plate", 100) } },
      ["empty-x-barrel"] = { category = "crafting", energy = 1, ingredients = { item("ore", 1) }, products = { item("plate", 50) } },
    },
    items = {
      cell = { burnt_result = "used" },
      sat = { launch = { item("pack", 1000) } },
    },
    machines = { ["rocket-silo"] = { rocket_parts_required = 100 } },
  }
end

local function mu_of(data, target, opts)
  local G = MU.graph(data, opts)
  return (MU.solve_target(G, target)), G
end

---------------------------------------------------------------------------------------------------
-- Partie 1 : règles
---------------------------------------------------------------------------------------------------
local D = fixture()
check(near((mu_of(D, "plate")), 1), "plaque = 1 minerai = 1 MU")
check(near((mu_of(D, "acid")), 10 * 0.1 / 50), "fluide de gisement à 0,1 MU l'unité, eau gratuite : acide = 0,02 MU")
-- Règle 1 : probabilité. Traitement : 10 minerais (+ 1 acide chacun) → 0,993 U238 attendu.
local uore = 1 + 0.02
check(near((mu_of(D, "uore")), uore), "gisement à fluide exigé : minerai d'uranium = 1 + 1 acide (fluid_amount / 10)")
local u238 = (mu_of(D, "u238"))
check(near(u238, 10 * uore / 0.993, 1e-6), string.format("probabilité : U238 = 10 minerais / 0,993 (%.4f)", u238))
do -- mutant : probabilité ignorée
  local orig = MU.expected
  MU.expected = function(p) return p.amount or 0 end
  local m = (mu_of(D, "u238"))
  MU.expected = orig
  check(not near(m, 10 * uore / 0.993, 1e-6), "MUTANT probabilité ignorée : détecté")
end
-- Règle 2 et 3 : Kovarex. Sans productivité, U235 ≤ 3 U238 ; avec productivité 2, seule la part HORS catalyseur
-- double (41 − 40 = 1 → 2) : 2 U235 pour 3 U238.
local u235 = (mu_of(D, "u235"))
check(u235 <= 3 * u238 + 1e-9 and u235 > 2.5 * u238, string.format("Kovarex : U235 (%.3f) ≈ 3 U238 (%.3f), part nette du catalyseur", u235, u238))
local prod2 = function(name) return name == "kov" and 2 or 1 end
local u235p = (mu_of(D, "u235", { prod = prod2 }))
local u238p = (mu_of(D, "u238", { prod = prod2 }))
-- Kovarex seul : 2 U235 pour 3 U238 (1,5) ; le traitement, qui rend un peu d'U235 en sous-produit, peut faire mieux.
check(u235p <= 1.5 * u238p + 1e-9 and u235p > 1.4 * u238p, string.format("productivité hors catalyseur : U235 ≈ 1,5 U238 (%.4f / %.4f)", u235p, u238p))
do -- mutant : catalyseurs oubliés (la productivité multiplie les 41 U235 : 82 − 40 = 42 nets)
  local Dm = fixture()
  for _, p in ipairs(Dm.recipes.kov.products) do p.catalyst_amount = nil end
  local m = (mu_of(Dm, "u235", { prod = prod2 }))
  check(m < 0.5 * u235p, string.format("MUTANT catalyseur oublié : détecté (%.4f contre %.4f)", m, u235p))
end
-- Productivité simple et minière.
check(near((mu_of(D, "plate", { prod = function(n) return n == "plate" and 1.5 or 1 end })), 1 / 1.5), "productivité × 1,5 : plaque = 0,667 MU")
check(near((mu_of(D, "plate", { mining_prod = 2 })), 0.5), "productivité minière × 2 : plaque = 0,5 MU")
-- Règle 4 : lancement (satellite 100 plaques + 100 pièces de 10 plaques → 1 000 packs) et résidu de combustion.
check(near((mu_of(D, "pack")), (100 + 100 * 10) / 1000), "lancement : pack = (satellite + 100 pièces) / 1 000 = 1,1 MU")
do
  local _, G = mu_of(D, "plate")
  local has = false
  for _, x in ipairs(G.recipes) do if x.name == "combustion:cell" then has = true end end
  check(has, "résidu de combustion : pseudo-recette pile → pile usée")
end
-- Exclusions : lots MOD-2 et vidage de baril ne fixent pas les prix (sinon la plaque vaudrait 0,01 / 0,02).
check(near((mu_of(D, "plate")), 1), "lots MOD-2 et vidages de baril exclus")
do -- mutant : exclusions supprimées
  local orig = MU.excluded
  MU.excluded = function() return false end
  local m = (mu_of(D, "plate"))
  MU.excluded = orig
  check(not near(m, 1), "MUTANT sans exclusions : détecté")
end
-- Inaccessible : ghost n'a qu'un cycle sans entrée → ∞ ; bruts sans source signalés.
local vg, Gg = mu_of(D, "ghost")
check(vg == math.huge, "objet sans chaîne depuis un gisement : ∞")
check(#Gg.orphans == 0, "aucun brut orphelin dans la fixture (nothing est produit par unghost)")
-- Filtre d'époque : une recette écartée rend son produit inaccessible, sans en faire un brut orphelin.
do
  local v, G = mu_of(D, "rocket-part", { allow = function(n) return n ~= "rocket-part" end })
  check(v == math.huge and #G.orphans == 0, "recette pas encore débloquée : produit inaccessible, pas un brut à 1 MU")
end
-- Cycles : la boucle uranium (pile → usée → retraitement) devient rentable avec une forte productivité.
do
  local p = function(n) return (n == "cell" or n == "repro") and 3 or 1 end
  local v, x = MU.solve_target(MU.graph(D, { prod = p }), "u238")
  check(v < u238 / 2 and x["combustion:cell"] ~= nil, string.format("productivité × 3 sur la pile et le retraitement : U238 refait sans minerai (%.3f MU)", v))
  check(MU.cycle(x) ~= nil, "cycle détecté dans la chaîne (pile → usée → U238 → pile)")
  local _, x0 = MU.solve_target(MU.graph(D), "u238")
  check(MU.cycle(x0) == nil, "aucun cycle dans la chaîne sans productivité")
  -- Boucle de matière infinie stricte (aucune matière brute) : ghost ⇄ nothing avec productivité.
  local p2 = function(n) return (n == "ghost" or n == "unghost") and 1.5 or 1 end
  check(MU.free_loop(MU.graph(D, { prod = p2 }), "ghost") ~= nil, "boucle stricte ghost ⇄ nothing avec productivité : détectée")
  check(MU.free_loop(MU.graph(D), "ghost") == nil, "sans productivité : pas de boucle")
end
-- Déterminisme : deux résolutions identiques au bit près.
do
  local a = (mu_of(fixture(), "u235"))
  local b = (mu_of(fixture(), "u235"))
  check(a == b, "déterminisme : deux résolutions identiques")
end

---------------------------------------------------------------------------------------------------
-- Partie 2 : données réelles
---------------------------------------------------------------------------------------------------
local R = dofile("tools/calc/donnees.lua")
local Mo = require("tools.calc.modele")
local Eq = require("tools.calc.equilibre")
local L = Mo.L
local cache = Mo.new_cache(R)
for _, row in ipairs({ { "iron-plate", 1 }, { "copper-plate", 1 }, { "iron-gear-wheel", 2 }, { "electronic-circuit", 2.5 },
  { "steel-plate", 5 }, { "stone-brick", 2 }, { "engine-unit", 9 } }) do
  check(near(cache.mu(row[1], "H0", 1), row[2]), "repère vanilla : " .. row[1] .. " = " .. row[2] .. " MU")
end
local r238, r235 = cache.mu("uranium-238", "H0", 1), cache.mu("uranium-235", "H0", 1)
check(r238 > 10 and r238 < 13, string.format("uranium 238 : 10 minerais + acide / 0,993 (%.2f)", r238))
check(r235 > 2.5 * r238 and r235 <= 3 * r238 + 1e-9, string.format("uranium 235 par Kovarex ≈ 3 U238 (%.2f)", r235))
check(cache.mu("fo-titanium-plate", "H0", 1) < math.huge, "titane : chaîne de Kroll complète (boucle du chlore comprise)")
check(cache.mu("space-science-pack", "H0", 1) < math.huge, "pack spatial : lancement d'un satellite")
-- Correctif de la piste : aucune productivité sur le cycle de l'uranium (data-final-fixes.lua).
do
  local lim = {}
  for _, r in ipairs(R.modules["productivity-module"].limitation) do lim[r] = true end
  check(not lim["uranium-fuel-cell"] and not lim["nuclear-fuel-reprocessing"], "limitation : pile d'uranium et retraitement exclus")
  check(lim["kovarex-enrichment-process"] and lim["uranium-processing"] and lim["processing-unit"], "limitation : le reste de la liste vanilla gardé")
end
local cur = {}
for e = 2, L.EPOCHS do cur[#cur + 1] = { e = e, item = L.epoch_materials[e].item, value = L.epoch_materials[e].value } end
local inc = Eq.incoherences(R, cache, (function()
  local rows = {}
  for _, c in ipairs(cur) do
    local mu0 = cache.mu(c.item, "H0", c.e)
    rows[#rows + 1] = { e = c.e, item = c.item, value = c.value, mu0 = mu0, ratio = c.value / mu0,
      provisional = L.epoch_materials[c.e].provisional, stack_l = L.stack_size[c.item], stack_d = R.stacks[c.item] }
  end
  return rows
end)())
local loops, machine_faults, value_faults = {}, {}, {}
for _, r in ipairs(inc) do
  if r[1] == "FAUX" and r[2]:find("déclarée") then value_faults[#value_faults + 1] = r[2] end
  if r[2]:find("Boucle productive") then loops[#loops + 1] = r[2] end
  if r[2]:find("^fo%-lvl") or r[2]:find("Machine absente") or r[2]:find("Pile de") then machine_faults[#machine_faults + 1] = r[2] end
end
check(#value_faults == 0, "monnaies non provisoires : valeur déclarée à × 1,5 près de la matière brute réelle (sauf rareté voulue)"
  .. (#value_faults > 0 and (" : " .. value_faults[1]) or ""))
check(#loops == 0, "aucune boucle productive sous la productivité maximale de chaque époque" .. (#loops > 0 and (" : " .. loops[1]) or ""))
check(#machine_faults == 0, "machines des niveaux (vitesse, cases, emprise) et piles : étape data = config" .. (#machine_faults > 0 and (" : " .. machine_faults[1]) or ""))
do -- mutant : la pile d'uranium remise dans la limitation → la boucle revient
  local lim = R.modules["productivity-module"].limitation
  lim[#lim + 1] = "uranium-fuel-cell"
  lim[#lim + 1] = "nuclear-fuel-reprocessing"
  local c2 = Mo.new_cache(R)
  local found = false
  for e = 1, L.EPOCHS do
    local v, x = c2.mu("uranium-238", "H2", e)
    if v < math.huge and MU.cycle(x) then found = true break end
  end
  lim[#lim] = nil; lim[#lim] = nil
  check(found, "MUTANT pile d'uranium productive : la boucle est détectée")
end
-- Calendrier déclaré : le calculateur retrouve le modèle de levels_test (59 h 30 du calendrier X0, à 1 % près).
do
  local tot, cal = 0, 0
  for e = 1, L.EPOCHS do
    tot = tot + Mo.implied_hours(e, Mo.spend(e, function(c) return L.cost_value(c) end))
    cal = cal + L.target.epoch_hours(e)
  end
  check(math.abs(tot - cal) / cal < 0.01, string.format("durée impliquée déclarée %.2f h ≈ calendrier X0 %.2f h", tot, cal))
end
-- Palier de module disponible : vitesse 1 à l'époque 6, 5 à l'époque 10, 10 à l'époque 14.
check(Mo.tier_available("speed", 5) == nil and Mo.tier_available("speed", 6) == 1 and Mo.tier_available("productivity", 10) == 5
  and Mo.tier_available("productivity", 14) == 10, "paliers de modules par époque (X.base_recipe_epochs)")
-- Document à jour.
do
  local fh = io.open("docs/CALCULS_EQUILIBRE.md", "rb")
  local doc = fh and fh:read("*a") or ""
  if fh then fh:close() end
  check(doc == Eq.render(R), "docs/CALCULS_EQUILIBRE.md est la sortie du calculateur (sinon : lua5.2 tools/calc/equilibre.lua)")
end

print(string.format("[CALC] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
