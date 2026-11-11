--[[
  Tests hors jeu du lot CC-ENERGIE (F491) : aucune chaudière ni machine à vapeur de plus tant que la demande MESURÉE reste sous
  C.GROW_LOAD (75 %) de la capacité bâtie vivante + celle des centrales neuves en chantier (shared/team/centrale.lua, C.grow_load,
  garde de C.growth ; câblage script/team/plant_arms.lua, PA.watch). Chiffres rejoués : partie du DC sur la 0.6.87, graine 3592985581
  (fo-logs/2026-11-10_PLAYTEST-0687/factorio-current.log, lignes [FO-ENERGIE] bilan). Avec mutants.
  Usage :   lua5.2 tests/centrale_charge_test.lua
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
end
local function section(name) if not quiet then print("== " .. name) end end

local KW = 1000 / 60 -- kW -> J/tick
local BOILER_KW = 1800

local function battery(C)
  local function n(t)
    local o = { done = 1, pending = 0, refused = 0, hold = false, off = false, boiler_kw = BOILER_KW, built = 1 }
    for k, v in pairs(t or {}) do o[k] = v end
    return o
  end
  local sat = function() return { saturated = true, sat = 10, def_n = 0 } end
  local def = function() return { saturated = false, sat = 0, def_n = 3 } end

  section("1. Seuil et charge mesurée")
  check(C.GROW_LOAD == 0.75, "seuil du DC : 75 %")
  check(C.grow_load(0, 1800 * KW, 0) == 0, "0 kW produits sur 1 800 : charge 0")
  check(math.abs(C.grow_load(1350 * KW, 1800 * KW, 0) - 0.75) < 1e-9, "1 350 kW sur 1 800 : 75 %")
  local l = C.grow_load(1368 * KW, 1800 * KW, 1800 * KW)
  check(l and math.abs(l - 0.38) < 1e-9, "1 368 kW sur 1 800 bâtis + 1 800 en chantier : 38 % (le chantier compte)")
  check(C.grow_load(500, 0, 0) == nil, "aucune capacité (première centrale, perte totale) : charge non mesurable (nil)")
  check(C.grow_load(nil, nil, nil) == nil, "rien de relevé : nil")
  check(C.grow_load(0, 0, 1800 * KW) == 0, "perte totale, secours en chantier : la capacité du chantier compte (0)")
  check(C.grow_load(-5, 1800 * KW, -100) == 0, "valeurs négatives bornées")

  section("2. Garde : chaque déclencheur retenu sous 75 %")
  local nb, why = C.growth(sat(), n({ load = 0.5 }))
  check(nb == nil and why == C.LOAD_REASON, "saturée (hystérésis) mais demande à 50 % : rien (" .. tostring(why) .. ")")
  nb, why = C.growth({ saturated = false, sat = 0 }, n({ load = 0.6, anticipate = true }))
  check(nb == nil and why == C.LOAD_REASON, "avance sur les chantiers à 60 % mesurés : rien")
  nb, why = C.growth(def(), n({ load = 0, deficit_kw = 8610 }))
  check(nb == nil and why == C.LOAD_REASON, "partie du DC, player 12,6 min : 8 610 kW retenus, 0 kW sur 1 800 : rien")
  nb, why = C.growth(def(), n({ load = C.grow_load(1368 * KW, 1800 * KW, 1800 * KW), pending = 1, pending_kw = 1800, deficit_kw = 8610 }))
  check(nb == nil and why == C.LOAD_REASON, "partie du DC, player 12,8 min : chantier EN PARALLELE à 38 % : rien")
  nb, why = C.growth(def(), n({ load = 0.2, lost = true, deficit_kw = 1170 }))
  check(nb == nil and why == C.LOAD_REASON, "perte partielle, les machines vivantes ne font que 20 % : pas de secours")
  check(C.growth(def(), n({ load = 180 / 5400, deficit_kw = 8000, done = 2 })) == nil, "player 18,1 min : 180 kW sur 5 400 : rien")
  check(C.growth(sat(), n({ load = 3356 / 7200, done = 4 })) == nil, "emerald 52,8 min : 3 356 kW sur 7 200 (47 %) : rien")
  check(C.growth(sat(), n({ load = 3812 / 14400, done = 5 })) == nil, "emerald 72,8 min : 3 812 sur 14 400 : rien")
  check(C.growth(sat(), n({ load = 0.749 })) == nil, "74,9 % : rien")

  section("2b. P0-CENTRALE : demande engagee au-dela de la capacite = 100 %")
  check(C.growth(sat(), n({ load = 1594 / 5400, engaged_kw = 2528, cap_kw = 1800 })) == 2, "partie du DC 0.7.3 : 2 528 kW engages sur 1 800, mesure 30 % : le champ")
  nb, why = C.growth(sat(), n({ load = 0.5, engaged_kw = 1800, cap_kw = 1800 }))
  check(nb == nil and why == C.LOAD_REASON, "engage egal a la capacite, mesure 50 % : rien")
  nb, why = C.growth(sat(), n({ load = 0.5, engaged_kw = 2528 }))
  check(nb == nil and why == C.LOAD_REASON, "capacite inconnue : la mesure decide")
  check(C.engaged_over(1979, 1800) and not C.engaged_over(1979, 0) and not C.engaged_over(nil, 1800), "C.engaged_over")

  section("3. À partir de 75 % : la croissance d'avant")
  check(C.growth(sat(), n({ load = 0.75, built = 8 })) == 4, "saturée à 75 % pile : le champ ordinaire (4 pour 8 vivantes)")
  check(C.growth(sat(), n({ load = 1 })) == 2, "saturée à 100 % : le champ de 2")
  check(C.growth(def(), n({ load = 0.78, deficit_kw = 1170 })) == 1, "1 400 kW sur 1 800 (78 %), déficit de 1 170 kW : une chaudière")
  check(C.growth(def(), n({ load = 0.78, deficit_kw = 3540 })) == 2, "78 %, déficit de 3 540 kW : deux chaudières")
  check(C.growth({ saturated = false, sat = 0 }, n({ load = 0.8, anticipate = true, built = 2 })) == 2, "avance à 80 % : le champ")
  check(C.growth(def(), n({ load = 0.8, pending = 1, pending_kw = 1800, deficit_kw = 5000 })) == 2, "chantier en parallèle à 80 % (avec le chantier) : 2")
  check(C.growth(def(), n({ load = nil, lost = true, deficit_kw = 1170 })) == C.SECOURS_BOILERS, "perte totale (charge nil) : l'unité de secours")
  check(C.growth(sat(), n({})) == 2, "sans charge relevée (anciens appels) : inchangé")

  section("4. Raisons inchangées hors du cas")
  nb, why = C.growth({ saturated = false, sat = 0 }, n({ load = 0.1 }))
  check(nb == nil and why == "pas saturee", "aucun déclencheur : « pas saturee », pas la garde (" .. tostring(why) .. ")")
  nb, why = C.growth(sat(), n({ load = 0.1, off = true }))
  check(nb == nil and why == "regle coupee", "règle coupée : sa raison d'abord")
  nb, why = C.growth(sat(), n({ load = 0.9, pending = 1 }))
  check(nb == nil and why == "un chantier de centrale est ouvert", "chantier ouvert à 90 % : la garde du chantier")
end

section("Règle réelle")
local real = require("shared.team.centrale")
battery(real)

section("Câblage de PA.watch (source)")
local function wiring(src)
  local ok = true
  ok = ok and src:find("local gate = C.grow_load(power + reopened_power, capacity + reopened_alive, new_kw * 1000 / 60)", 1, true) ~= nil
  ok = ok and src:find("C.growth(g, { load = gate,", 1, true) ~= nil
  ok = ok and src:find("if was_built then rebuilding = rebuilding + 1 else new_kw = new_kw + pk end", 1, true) ~= nil
  ok = ok and src:find("reopened_power = reopened_power + (r.energy_generated_last_tick or 0)", 1, true) ~= nil
  return ok
end
local fp = assert(io.open("script/team/plant_arms.lua", "rb"))
local pa = fp:read("*a")
fp:close()
check(wiring(pa), "PA.watch passe la charge mesurée (production vivante sur capacité vivante + centrales neuves en chantier)")
local pa_mutants = {
  { "charge non transmise", "C.growth(g, { load = gate,", "C.growth(g, {" },
  { "chantiers neufs hors de la capacité", "new_kw * 1000 / 60)", "0)" },
  { "reconstruction comptée comme neuve", "else new_kw = new_kw + pk end", "end new_kw = new_kw + pk" },
  { "production rouverte ignorée", "reopened_power = reopened_power + (r.energy_generated_last_tick or 0)", "reopened_power = reopened_power" },
}
for _, m in ipairs(pa_mutants) do
  local a, b = pa:find(m[2], 1, true)
  check(a ~= nil and not wiring(pa:sub(1, a - 1) .. m[3] .. pa:sub(b + 1)), "mutant du câblage refusé : " .. m[1])
end

section("Mutants")
local f = assert(io.open("shared/team/centrale.lua", "rb"))
local src = f:read("*a")
f:close()
local GATE = "if n.load ~= nil and n.load < C.GROW_LOAD and not C.engaged_over(n.engaged_kw, n.cap_kw) then return nil, C.LOAD_REASON end"
local TRIGGER = "  if not st.saturated and not n.lost and not n.anticipate and not deficit then return nil, \"pas saturee\" end\n"
local COMMENT = "  -- lot CC-ENERGIE (F491) : quel que soit le déclencheur, rien tant que la demande mesurée reste sous C.GROW_LOAD de la capacité\n"
local mutants = {
  { "garde retirée", GATE, "" },
  { "engage ignore (P0-CENTRALE)", " and not C.engaged_over(n.engaged_kw, n.cap_kw)", "" },
  { "seuil 75 -> 70 %", "C.GROW_LOAD = 0.75", "C.GROW_LOAD = 0.7" },
  { "seuil 75 -> 80 %", "C.GROW_LOAD = 0.75", "C.GROW_LOAD = 0.8" },
  { "75 % pile retenu (< -> <=)", "n.load < C.GROW_LOAD", "n.load <= C.GROW_LOAD" },
  { "charge absente prise pour 0", "n.load ~= nil and n.load < C.GROW_LOAD", "(n.load or 0) < C.GROW_LOAD" },
  { "perte exemptée", "n.load ~= nil and n.load < C.GROW_LOAD", "n.load ~= nil and not n.lost and n.load < C.GROW_LOAD" },
  { "déficit exempté", "n.load ~= nil and n.load < C.GROW_LOAD", "n.load ~= nil and not deficit and n.load < C.GROW_LOAD" },
  { "chantier en parallèle exempté", "n.load ~= nil and n.load < C.GROW_LOAD", "n.load ~= nil and n.pending == 0 and n.load < C.GROW_LOAD" },
  { "chantiers hors de la capacité", "math.max(0, built_j or 0) + math.max(0, pending_j or 0)", "math.max(0, built_j or 0)" },
  { "capacité nulle = charge 0", "if cap <= 0 then return nil end", "if cap <= 0 then return 0 end" },
  { "garde avant les déclencheurs", TRIGGER .. COMMENT .. "  " .. GATE, "  " .. GATE .. "\n" .. TRIGGER },
}
local refused = 0
for _, m in ipairs(mutants) do
  local a, b = src:find(m[2], 1, true)
  if not a then
    failures = failures + 1
    print("  ECHEC : mutant '" .. m[1] .. "' : motif introuvable dans la source")
  else
    local chunk, err = load(src:sub(1, a - 1) .. m[3] .. src:sub(b + 1), "=mutant", "t")
    if not chunk then
      failures = failures + 1
      print("  ECHEC : mutant '" .. m[1] .. "' ne compile pas : " .. tostring(err))
    else
      local ok, mod = pcall(chunk)
      local before = failures
      quiet = true
      local okb = pcall(battery, ok and mod or real)
      quiet = false
      local killed = (failures > before) or not okb or not ok
      failures = before
      if killed then refused = refused + 1; passes = passes + 1 else failures = failures + 1; print("  ECHEC : mutant SURVIVANT : " .. m[1]) end
    end
  end
end
print(string.format("  mutants refuses : %d sur %d", refused, #mutants))
print(string.format("[CENTRALE-CHARGE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
