--[[
  Lot MARGE-TIERS (13/11, P1 du DC) : test hors jeu de shared/ai3/marge.lua et de son branchement (marge_gate, Ca.options).
    §1 fenêtre glissante (Mg.push, Mg.rates) ; §2 marge (Mg.rows : capacité posée, stock, bruit, tiers) ; §3 hystérésis (Mg.step) ;
    §4 exemptions (défense, foreuses et fonderies) et gel (Mg.frozen) ; §5 décisions entières : gel sous 20 %, rien au-dessus,
    rien sous menace, rien sans mesure ; §6 état sans fonction, déterminisme.
  Usage : lua5.2 tests/marge_test.lua (depuis la racine du mod). Fichier de TEST : il nomme des objets vanilla.
]]
package.path = "./?.lua;" .. package.path
local F = require("tests.iag_fixture")
local Ca = require("shared.ai3.capitalisation")
local Mg = require("shared.ai3.marge")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end
local function sk(t) local ks = {} for k in pairs(t or {}) do ks[#ks + 1] = k end table.sort(ks) return ks end
local function has(s, pat) return s ~= nil and tostring(s):find(pat, 1, true) ~= nil end
local function no_function(v)
  if type(v) == "function" then return false end
  if type(v) == "table" then for k, x in pairs(v) do if not no_function(k) or not no_function(x) then return false end end end
  return true
end

-- §1 fenêtre
do
  local w = Mg.new()
  Mg.push(w, { t = 3600, dt = 1, made = { a = 100 }, used = { a = 50 } })
  Mg.push(w, { t = 7200, dt = 1, made = { a = 200 }, used = { a = 150, b = 10 } })
  local r, tot = Mg.rates(w)
  check(tot == 2 and r.a.p == 150 and r.a.c == 100 and r.b.p == 0 and r.b.c == 5, "§1 moyenne par minute sur la fenêtre")
  Mg.push(w, { t = 7200 + Mg.WINDOW, dt = 1, made = { a = 0 }, used = {} })
  r, tot = Mg.rates(w)
  check(#w.s == 1 and tot == 1, "§1 les relevés sortis de la fenêtre sont oubliés")
  Mg.push(w, { t = 99999, dt = 0, made = { a = 1 } })
  check(#w.s == 1, "§1 un relevé sans durée est ignoré")
  check(next(Mg.rates(Mg.new())) == nil, "§1 fenêtre vide : aucun débit")
end

-- §2 marge
do
  local rank = { ore = 0, plate = 1, gear = 2, circuit = 3 }
  local rates = { ore = { p = 100, c = 100 }, plate = { p = 100, c = 100 }, gear = { p = 10, c = 10 }, circuit = { p = 1, c = 50 },
    dust = { p = 0, c = 2 } }
  local rows = Mg.rows(rates, rank, { ore = 200, plate = 110 }, { gear = 30 }, {})
  local by = {}
  for _, r in ipairs(rows) do by[r.item] = r end
  check(by.circuit == nil, "§2 rang 3 : hors des tiers 0 et 1")
  check(by.dust == nil, "§2 sous MIN_RATE : bruit")
  check(math.abs(by.ore.pct - 100) < 1e-9, "§2 foreuses figées : la capacité posée compte (+100 %)")
  check(math.abs(by.plate.pct - 10) < 1e-9, "§2 fours presque pleins : +10 %")
  check(math.abs(by.gear.pct - 30) < 1e-9, "§2 le stock compte sur H minutes (+30 %)")
  check(rows[1].item == "plate", "§2 la plus faible marge d'abord")
  check(#Mg.rows(rates, rank, {}, {}, { plate = true, ore = true, gear = true }) == 0, "§2 objets écartés (fluides)")
end

-- §3 hystérésis
do
  local st = {}
  local low = { { item = "plate", rank = 1, pct = 5, supply = 105, c = 100 } }
  local ok = { { item = "plate", rank = 1, pct = 40, supply = 140, c = 100 } }
  check(not Mg.step(st, low).gel, "§3 un relevé sous la marge ne gèle pas encore")
  check(Mg.step(st, low).gel, "§3 deux relevés de suite : gel")
  check(Mg.step(st, ok).gel, "§3 un relevé au-dessus ne lève pas encore")
  check(not Mg.step(st, ok).gel, "§3 deux relevés au-dessus : levé")
  check(not Mg.step({}, {}).gel, "§3 rien de consommé : aucun gel")
end

-- §4 exemptions et gel, sur les données vanilla de la fixture
-- Exécutants comme en jeu (opts.exec) : foreuses et fours, assembleurs.
local EXEC = { ["burner-mining-drill"] = true, ["electric-mining-drill"] = true, ["stone-furnace"] = true, ["steel-furnace"] = true,
  ["assembling-machine-1"] = true, ["assembling-machine-2"] = true, ["lab"] = true }
local D = Ca.data(F.dump(), { exec = EXEC })
local RANK = { ["iron-plate"] = 1, ["iron-gear-wheel"] = 2, ["steel-plate"] = 2, pipe = 2, ["engine-unit"] = 3,
  ["electronic-circuit"] = 3, ["piercing-rounds-magazine"] = 3, ["gun-turret"] = 3 }
do
  local ex = Mg.exempt(D, RANK, { entity_role = { ["ammo-turret"] = "militaire" }, kit = {}, plant = {} })
  check(ex["piercing-rounds-magazine"] == "defense", "§4 munition : défense (type du moteur)")
  check(ex["electronic-circuit"] == "extraction", "§4 circuit : sert la foreuse électrique")
  check(ex["engine-unit"] == nil, "§4 moteur : ni défense ni extraction")
  local D2 = Ca.data(F.dump(), { exec = EXEC })
  if D2.items["gun-turret"] then D2.items["gun-turret"].place = "ammo-turret" end
  local ex2 = Mg.exempt(D2, RANK, { entity_role = { ["ammo-turret"] = "militaire" }, kit = {}, plant = {} })
  check(D2.items["gun-turret"] == nil or ex2["gun-turret"] == "defense", "§4 objet qui pose une tourelle : défense")
  local v = { gel = true, short = { { item = "iron-plate", rank = 1, pct = 5, supply = 105, c = 100 } }, rows = {} }
  check(Mg.frozen(v, { kind = "chaine", item = "engine-unit" }, RANK, ex), "§4 gel : chaîne de rang 3 non exemptée")
  check(not Mg.frozen(v, { kind = "chaine", item = "electronic-circuit" }, RANK, ex), "§4 gel : jamais ce qui sert les foreuses")
  check(not Mg.frozen(v, { kind = "chaine", item = "iron-gear-wheel" }, RANK, ex), "§4 gel : jamais un tier 1")
  check(not Mg.frozen(v, { kind = "packs", item = "engine-unit" }, RANK, ex), "§4 gel : seulement les chaînes")
  check(not Mg.frozen({ gel = false }, { kind = "chaine", item = "engine-unit" }, RANK, ex), "§4 sans gel : rien")
  check(has(Mg.cause(v), "iron-plate") and has(Mg.cause(v), "20 %"), "§4 cause écrite")
end

-- §5 décisions entières
local ALL = {}
local function dump()
  local d = F.dump()
  for _, e in ipairs(d.entities) do e.size = e.name == "burner-mining-drill" and 2 or 3 end
  for _, r in ipairs(d.resources) do r.mining_time = 1 end
  return d
end
for t in pairs(dump().techs) do ALL[t] = true end
local DD = Ca.data(dump(), { exec = EXEC })
local function scene(cons_plate, tweak)
  local inp = { data = DD, state = { techs = ALL }, stock = { coal = 3000 }, workers = 30, idle = 10,
    can_grow = true, traits = {}, weights = {}, open = {},
    deposits = { { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true, dist = 60 },
      { id = "dc", resource = "copper-ore", tiles = 200, amount = 5e5, open = true, dist = 80 },
      { id = "dk", resource = "coal", tiles = 200, amount = 5e5, open = true, dist = 50 } },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 40, deposit = "d1" },
      { entity = "electric-mining-drill", resource = "copper-ore", n = 20, deposit = "dc" },
      { entity = "electric-mining-drill", resource = "coal", n = 12, deposit = "dk" } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 40, where = "qg" },
      { entity = "stone-furnace", recipe = "copper-plate", n = 20, where = "dc" } },
    labs = { { entity = "lab", n = 4 } }, research = { queue = {}, rate = 100 },
    flows = { ["iron-ore"] = { made = 360 }, ["copper-ore"] = { made = 360 }, coal = { made = 100 },
      ["iron-plate"] = { made = 360 }, ["copper-plate"] = { made = 360 } },
    sinks = { { item = "engine-unit", rate = 20 } }, can_exec = function() return nil end }
  if cons_plate then
    inp.marge = { ["iron-plate"] = { p = 360, c = cons_plate }, ["copper-plate"] = { p = 100, c = 50 } }
  end
  if tweak then tweak(inp) end
  return inp
end
local function decide(inp, st)
  local J = Ca.decide_begin(inp, st)
  while not Ca.decide_step(J) do end
  return J, J.res
end
local function refus_of(res, key)
  for _, r in ipairs(res.refus) do if r.key == key then return r.why end end
  return nil
end
local function any_engine(res)
  for _, o in ipairs(res.orders) do if o.item == "engine-unit" then return true end end
  return false
end
do
  -- Capacité des fours de fer : 40 × 60 / 3,2 = 750 /min.
  local st, J, res = {}, nil, nil
  for _ = 1, 3 do J, res = decide(scene(700), st) end
  local why = refus_of(res, "chaine:engine-unit")
  check(res.marge ~= nil and res.marge.gel == true, "§5 consommation 700/min pour 750 de capacité : gel")
  check(has(why, "marge T0/T1") and has(why, "iron-plate"), "§5 la chaîne du moteur est refusée, cause écrite (" .. tostring(why) .. ")")
  check(not any_engine(res), "§5 aucun ordre de moteur sous le gel")
  check(st.marge ~= nil and no_function(st), "§5 état de l'hystérésis : nombres")
  local st2 = {}
  for _ = 1, 3 do J, res = decide(scene(500), st2) end
  check(res.marge ~= nil and res.marge.gel == false and not has(refus_of(res, "chaine:engine-unit"), "marge"),
    "§5 500/min pour 750 (+50 %) : aucun gel")
  local st3 = {}
  for _ = 1, 3 do J, res = decide(scene(nil), st3) end
  check(res.marge == nil and st3.marge == nil, "§5 sans mesure : la règle d'avant, aucun état")
  local st4 = {}
  for _ = 1, 3 do J, res = decide(scene(700, function(i) i.threat = true end), st4) end
  check(not has(refus_of(res, "chaine:engine-unit"), "marge T0/T1"), "§5 sous menace : rien n'est gelé")
  Mg.ON = false
  local st5 = {}
  for _ = 1, 3 do J, res = decide(scene(700), st5) end
  Mg.ON = true
  check(res.marge == nil, "§5 Mg.ON éteint : la règle d'avant")
  -- Déterminisme
  local a, b = {}, {}
  local ra, rb
  for _ = 1, 3 do _, ra = decide(scene(700), a) end
  for _ = 1, 3 do _, rb = decide(scene(700), b) end
  local ka, kb = {}, {}
  for _, o in ipairs(ra.orders) do ka[#ka + 1] = o.key end
  for _, o in ipairs(rb.orders) do kb[#kb + 1] = o.key end
  check(table.concat(ka, ",") == table.concat(kb, ","), "§6 deux décisions identiques donnent les mêmes ordres")
  local line = Mg.format("amber", 12, { gel = true, short = { 1 }, rows = ra.marge.rows }, 3, 5)
  check(has(line, "[FO-MARGE] amber minute 12") and has(line, "gel OUI"), "§6 journal")
end

print(string.format("[MARGE] %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
