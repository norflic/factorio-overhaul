-- Banc hors jeu du lot MOD-2 : recettes par lots (shared/content/recipe_lots.lua).
--   lua5.2 tests/recipe_lots_test.lua      -> BILAN : N OK, 0 ECHEC(S) ; mutants refusés M / M
-- Contrôles : noms, fabrication d'un lot (formes courte et longue, normal/expensive, catalyseurs, probabilités,
-- plafond uint16), contrôle R.verify_lot, choix du lot (montée, descente, hystérésis, stabilité pour toute vitesse
-- fixe, aucune boucle), débit affiché. Mutants : chaque règle faussée doit faire échouer au moins un contrôle.

package.path = "./?.lua;" .. package.path
local R0 = dofile("shared/content/recipe_lots.lua")

local ok_n, fail_n = 0, 0
local function check(cond, what, detail)
  if cond then
    ok_n = ok_n + 1
  else
    fail_n = fail_n + 1
    print("ECHEC " .. what .. (detail and (" : " .. tostring(detail)) or ""))
  end
end

local GEAR = {
  type = "recipe", name = "iron-gear-wheel",
  normal = { ingredients = { { "iron-plate", 2 } }, result = "iron-gear-wheel" },
  expensive = { ingredients = { { "iron-plate", 4 } }, result = "iron-gear-wheel" },
}
local CABLE = { type = "recipe", name = "copper-cable", ingredients = { { "copper-plate", 1 } }, result = "copper-cable",
  result_count = 2 }
local ACID = { type = "recipe", name = "sulfuric-acid", category = "chemistry", energy_required = 1,
  ingredients = { { type = "item", name = "sulfur", amount = 5 }, { type = "item", name = "iron-plate", amount = 1 },
    { type = "fluid", name = "water", amount = 100 } },
  results = { { type = "fluid", name = "sulfuric-acid", amount = 50 } }, subgroup = "fluid-recipes" }
local KOVAREX = { type = "recipe", name = "kovarex-enrichment-process", category = "centrifuging", energy_required = 60,
  ingredients = { { "uranium-235", 40 }, { "uranium-238", 5 } },
  results = { { name = "uranium-235", amount = 41 }, { name = "uranium-238", amount = 2 } }, main_product = "" }
local URANIUM = { type = "recipe", name = "uranium-processing", category = "centrifuging", energy_required = 12,
  ingredients = { { "uranium-ore", 10 } },
  results = { { name = "uranium-235", probability = 0.007, amount = 1 }, { name = "uranium-238", probability = 0.993, amount = 1 } } }
local RANGE = { type = "recipe", name = "range", ingredients = { { "a", 1 } },
  results = { { name = "b", amount_min = 1, amount_max = 3, probability = 0.5, catalyst_amount = 1 } } }
local BIG = { type = "recipe", name = "big", ingredients = { { "steel-plate", 1000 } }, result = "x" }
local OFF = { type = "recipe", name = "off", normal = false, expensive = { ingredients = { { "a", 1 } }, result = "b" } }

local function run_all(R)
  ok_n, fail_n = 0, 0
  -- Noms
  check(R.name("iron-gear-wheel", 10) == "fo-lot10-iron-gear-wheel", "nom du lot x10")
  local b, k = R.parse("fo-lot100-iron-gear-wheel")
  check(b == "iron-gear-wheel" and k == 100, "relecture du lot x100", tostring(b) .. " " .. tostring(k))
  check(R.parse("iron-gear-wheel") == nil and not R.is_lot("fo-lotx-a"), "recette ordinaire : pas un lot")
  local b2, k2 = R.parse("fo-lot10-fo-lot10-a")
  check(b2 == "fo-lot10-a" and k2 == 10, "relecture : premier préfixe seulement")

  -- Lots fabriqués
  for _, kk in ipairs({ 10, 100 }) do
    local g = R.lot_recipe(GEAR, kk)
    check(g and g.normal and g.expensive, "engrenage x" .. kk .. " : normal et expensive")
    if g then
      check(g.normal.ingredients[1].amount == 2 * kk and g.expensive.ingredients[1].amount == 4 * kk,
        "engrenage x" .. kk .. " : ingrédients", g.normal.ingredients[1].amount)
      check(g.normal.results[1].amount == kk and g.normal.results[1].name == "iron-gear-wheel", "engrenage x" .. kk .. " : produits")
      check(g.normal.energy_required == 0.5 * kk, "engrenage x" .. kk .. " : durée (0,5 s par défaut)", g.normal.energy_required)
      check(g.normal.hidden == true and g.normal.enabled == false and g.normal.hide_from_player_crafting == true
        and g.expensive.hidden == true, "engrenage x" .. kk .. " : caché, désactivé, jamais à la main")
      check(g.normal.requester_paste_multiplier == math.max(1, math.floor(30 / kk)), "engrenage x" .. kk .. " : collage ramené au lot")
      check(#R.verify_lot(g, GEAR) == 0, "engrenage x" .. kk .. " : contrôle R.verify_lot", table.concat(R.verify_lot(g, GEAR), " ; "))
      check(g.category == "crafting", "engrenage x" .. kk .. " : même catégorie")
    end
    local c = R.lot_recipe(CABLE, kk)
    check(c and c.results[1].amount == 2 * kk and c.ingredients[1].amount == kk and c.energy_required == 0.5 * kk,
      "câble x" .. kk .. " : forme courte, result_count")
    check(c and #R.verify_lot(c, CABLE) == 0, "câble x" .. kk .. " : contrôle")
    local a = R.lot_recipe(ACID, kk)
    check(a and a.ingredients[3].amount == 100 * kk and a.results[1].amount == 50 * kk and a.category == "chemistry"
      and a.energy_required == kk, "acide x" .. kk .. " : fluides multipliés (la boîte suit la recette, E151)")
    check(a and R.max_fluid(R.block_of(a)) == 100 * kk, "acide x" .. kk .. " : plus grand fluide")
    local kv = R.lot_recipe(KOVAREX, kk)
    check(kv and kv.results[1].amount == 41 * kk and kv.ingredients[1].amount == 40 * kk and kv.main_product == "",
      "kovarex x" .. kk .. " : catalyseur, produit principal vide gardé")
    local u = R.lot_recipe(URANIUM, kk)
    check(u and u.results[1].probability == 0.007 and u.results[1].amount == kk, "uranium x" .. kk .. " : probabilité gardée")
    local rg = R.lot_recipe(RANGE, kk)
    check(rg and rg.results[1].amount_min == kk and rg.results[1].amount_max == 3 * kk and rg.results[1].catalyst_amount == kk,
      "intervalle x" .. kk .. " : bornes et catalyseur")
    check(rg and #R.verify_lot(rg, RANGE) == 0, "intervalle x" .. kk .. " : contrôle")
    local o = R.lot_recipe(OFF, kk)
    check(o and o.normal == false and o.expensive and o.expensive.ingredients[1].amount == kk, "normal = false gardé x" .. kk)
  end
  local big10, why = R.lot_recipe(BIG, 10)
  check(big10 and big10.ingredients[1].amount == 10000, "1 000 acier x10 = 10 000 (uint16)", why)
  local big100, why100 = R.lot_recipe(BIG, 100)
  check(big100 == nil and why100 and why100:find("65535"), "1 000 acier x100 refusé (uint16)", why100)
  -- La base n'est pas modifiée.
  check(GEAR.normal.ingredients[1][2] == 2 and GEAR.normal.result == "iron-gear-wheel", "base intacte")

  -- Contrôle : un lot faussé est refusé.
  local g10 = R.lot_recipe(GEAR, 10)
  if g10 then
    local bad = R.copy(g10)
    bad.normal.energy_required = 4
    check(#R.verify_lot(bad, GEAR) > 0, "contrôle : durée fausse refusée")
    bad = R.copy(g10)
    bad.expensive.ingredients[1].amount = 20
    check(#R.verify_lot(bad, GEAR) > 0, "contrôle : ingrédient expensive faux refusé")
    bad = R.copy(g10)
    bad.normal.hidden = false
    check(#R.verify_lot(bad, GEAR) > 0, "contrôle : lot visible refusé")
  end
  local n, nb, errs = R.verify({ ["iron-gear-wheel"] = GEAR, ["fo-lot10-iron-gear-wheel"] = R.lot_recipe(GEAR, 10),
    ["fo-lot100-iron-gear-wheel"] = R.lot_recipe(GEAR, 100), ["fo-lot10-absent"] = R.lot_recipe(CABLE, 10) })
  check(n == 3 and nb == 1 and #errs == 1, "R.verify : 3 lots, 1 base, 1 base absente", n .. " " .. nb .. " " .. #errs)

  -- Choix du lot. Engrenage 0,5 s (500 ms) ; vitesse en millièmes.
  local AV = { 1, 10, 100 }
  local E = 500
  local function v(rate) return rate * E end -- vitesse (millièmes) qui donne `rate` fabrications/s
  check(R.choose(1, v(60), E, AV) == 1, "60 /s : lot 1 (le plafond est atteint, pas dépassé)")
  check(R.choose(1, v(60) + 1, E, AV) == 10, "60 /s + 1 millième : lot 10")
  check(R.choose(1, v(600) + 1, E, AV) == 100, "600 /s + : lot 100 directement")
  check(R.choose(1, v(1636), E, AV) == 100, "1 636 /s (niveau 30, 34 x P10) : lot 100")
  check(R.choose(100, v(1636), E, AV) == 100, "lot 100 tenu à 1 636 /s")
  check(R.choose(10, v(50), E, AV) == 10, "lot 10 gardé à 50 /s (bande 45-60)")
  check(R.choose(10, v(45), E, AV) == 1, "lot 10 -> 1 à 45 /s")
  check(R.choose(100, v(500), E, AV) == 100, "lot 100 gardé à 500 /s")
  check(R.choose(100, v(450), E, AV) == 10, "lot 100 -> 10 à 450 /s")
  check(R.choose(100, v(40), E, AV) == 1, "lot 100 -> 1 à 40 /s")
  check(R.choose(100, v(7000), E, AV) == 100, "7 000 /s : lot 100 (plafond, rien de plus grand)")
  check(R.choose(1, v(7000), E, { 1, 10 }) == 10, "lot 100 absent : lot 10 au plafond")
  check(R.choose(10, v(100), E, { 1 }) == 1, "lot courant absent des lots disponibles : le plus petit qui tient")
  check(R.choose(1, 0, E, AV) == 1, "machine arrêtée : lot 1")
  check(R.choose(10, 0, E, AV) == 1, "machine arrêtée au lot 10 : lot 1")
  -- Stabilité et absence de boucle : pour toute vitesse FIXE, après une bascule, la décision suivante ne bouge plus ;
  -- le lot choisi tient toujours sous 60 /s quand un lot le permet ; jamais de descente au-dessus de 45 /s.
  local unstable, over, early = 0, 0, 0
  local cnt = 0
  for rate10 = 0, 80000, 7 do -- de 0 à 8 000 /s par pas de 0,7
    local speed = rate10 * E / 10
    for _, cur in ipairs(AV) do
      cnt = cnt + 1
      local k1 = R.choose(cur, speed, E, AV)
      local k2 = R.choose(k1, speed, E, AV)
      if k2 ~= k1 then unstable = unstable + 1 end
      if rate10 / 10 <= 6000 and rate10 / (10 * k1) > 60 then over = over + 1 end
      if k1 < cur and rate10 / (10 * k1) > 45 then early = early + 1 end
    end
  end
  check(unstable == 0, "aucune bascule en boucle à vitesse fixe (" .. cnt .. " cas)", unstable)
  check(over == 0, "le lot choisi tient sous 60 /s quand c'est possible", over)
  check(early == 0, "descente seulement si le lot inférieur tient sous 45 /s", early)
  -- Montée puis descente le long d'une rampe : bascules comptées (une par seuil).
  local cur, switches = 1, 0
  for rate = 0, 2000, 5 do
    local kk = R.choose(cur, v(rate), E, AV)
    if kk ~= cur then switches = switches + 1 cur = kk end
  end
  for rate = 2000, 0, -5 do
    local kk = R.choose(cur, v(rate), E, AV)
    if kk ~= cur then switches = switches + 1 cur = kk end
  end
  check(switches == 4 and cur == 1, "rampe 0 -> 2 000 -> 0 /s : 4 bascules (1->10->100->10->1)", switches)

  -- Débit affiché
  check(R.rate_cents(100, R.milli(818.388), R.milli(0.5)) == 1637, "débit affiché : 818,388 / 50 s = 16,37 lots/s",
    R.rate_cents(100, R.milli(818.388), R.milli(0.5)))
  check(R.rate_cents(1, R.milli(0.75), R.milli(0.5)) == 150, "débit affiché : 1,50 /s")
  check(R.milli(246.5025) == 246503 and R.milli(0.5) == 500, "millièmes arrondis")
  return ok_n, fail_n
end

local ok, fail = run_all(R0)

-- Mutants : chacun fausse une règle ; le banc doit le refuser (au moins un ECHEC).
local function mutant(label, patch)
  local M = dofile("shared/content/recipe_lots.lua")
  patch(M)
  local saved = print
  print = function() end
  local okc, _, f = pcall(run_all, M)
  print = saved
  if not okc then return true, label .. " (plantage)" end
  return f > 0, label
end
local mutants = {
  { "sans hystérésis (descente dès 60 /s)", function(M) M.DOWN = M.CAP end },
  { "plafond 61", function(M) M.CAP = 61 end },
  { "durée non multipliée", function(M)
    local mb = M.multiply_block
    M.multiply_block = function(b, k) local o, w = mb(b, k) if o then o.energy_required = b.energy_required end return o, w end
  end },
  { "catalyseur oublié", function(M)
    local mb = M.multiply_block
    M.multiply_block = function(b, k)
      local o, w = mb(b, k)
      if o then for _, p in ipairs(o.results) do if p.catalyst_amount then p.catalyst_amount = p.catalyst_amount / k end end end
      return o, w
    end
  end },
  { "lot visible", function(M)
    local mb = M.multiply_block
    M.multiply_block = function(b, k) local o, w = mb(b, k) if o then o.hidden = false end return o, w end
  end },
  { "uint16 non contrôlé", function(M) M.UINT16 = 1e9 end },
  { "montée au plus grand lot", function(M)
    M.choose = function(cur, speed_m, energy_ms, avail)
      if speed_m > M.CAP * energy_ms then return avail[#avail] end
      return 1
    end
  end },
  { "comparaison stricte (60 /s monte au lot 10)", function(M) M.fits = function(k, cap, s, e) return s < cap * k * e end end },
  { "contrôle sans les produits", function(M)
    local vl = M.verify_lot
    M.verify_lot = function(lot, base)
      local errs = vl(lot, base)
      local out = {}
      for _, e in ipairs(errs) do if not e:find("results", 1, true) then out[#out + 1] = e end end
      return out
    end
    local lr = M.lot_recipe
    M.lot_recipe = function(b, k)
      local r, w = lr(b, k)
      local p = r and r.results and r.results[1]
      if p and p.amount then p.amount = p.amount + 1 end
      return r, w
    end
  end },
  { "expensive ignoré", function(M)
    local lr = M.lot_recipe
    M.lot_recipe = function(b, k) local r, w = lr(b, k) if r and r.expensive then r.expensive = R0.copy(b.expensive) end return r, w end
  end },
}
local refused = 0
for _, m in ipairs(mutants) do
  local caught, label = mutant(m[1], m[2])
  if caught then refused = refused + 1 else print("MUTANT NON REFUSE : " .. label) end
end

print(string.format("  mutants refusés : %d / %d", refused, #mutants))
local total_fail = fail + (#mutants - refused)
print(string.format("BILAN : %d OK, %d ECHEC(S)", ok, total_fail))
os.exit(total_fail == 0 and 0 or 1)
