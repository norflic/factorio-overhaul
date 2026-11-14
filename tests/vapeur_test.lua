--[[
  Tests hors jeu du lot VAPEUR (14/11) : demande nominale, capacité, extension (shared/team/vapeur.lua) et son branchement dans la
  croissance de la centrale (shared/team/centrale.lua, n.nominal_kw).
  Usage :   lua5.2 tests/vapeur_test.lua
]]
package.path = "./?.lua;" .. package.path
local V = require("shared.team.vapeur")
local C = require("shared.team.centrale")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

print("== 1. Demande et capacite nominales")
check(V.demand_kw({ { count = 10, kw = 90 }, { count = 2, kw = 150 } }) == 1200, "somme count x kW")
check(V.demand_kw({ { count = -1, kw = 90 }, { count = 3, kw = 0 / 0 } }) == 0, "valeurs absurdes ignorees")
check(V.demand_kw(nil) == 0, "rien : 0")
check(V.capacity_kw(1800, 1800) == 1800 and V.capacity_kw(3600, 1800) == 1800 and V.capacity_kw(900, 1800) == 900, "min machines / chaudieres")
check(V.capacity_kw(1800, nil) == 1800, "chaudieres inconnues : machines seules")

print("== 2. Extension a la demande nominale + 30 %")
check(V.missing_kw(1000, 1800, 0) == 0, "1300 <= 1800 : suffisante")
check(math.abs(V.missing_kw(1500, 1800, 0) - 150) < 1e-9, "1950 - 1800 = 150 kW manquants")
check(V.missing_kw(1500, 1800, 1800) == 0, "les chantiers ouverts comptent")
check(V.missing_kw(1384, 1800, 0) == 0 and V.missing_kw(1385, 1800, 0) > 0, "seuil a capacite / 1,3")
check(V.fed_share(1, 2) == 0.5 and V.fed_share(0, 0) == nil, "part alimentee")
check(V.line({ team = "player", tick = 108000, demand = 1500, cap = 1800, missing = 150, fed = 1, boilers = 1, auto = 1, plants = 1 }):find("[FO-VAPEUR] player", 1, true) ~= nil,
  "ligne de journal")

print("== 3. Branchement dans C.growth")
local function base() return { done = 1, pending = 0, refused = 0, hold = false, off = false, boiler_kw = 1800, load = 0.1 } end
local st = {}
local nb, why = C.growth(st, base())
check(nb == nil and why == "pas saturee", "sans declencheur : rien")
local n = base(); n.nominal_kw = 150
nb, why = C.growth({}, n)
check(nb == 1, "demande nominale au-dela : une chaudiere, malgre une charge mesuree de 10 % (" .. tostring(nb) .. ", " .. tostring(why) .. ")")
n = base(); n.nominal_kw = 4000
nb = C.growth({}, n)
check(nb == 3, "taille a la demande manquante : 4000 / 1800 -> 3 chaudieres (" .. tostring(nb) .. ")")
n = base(); n.nominal_kw = 150; n.coal_short = true
nb, why = C.growth({}, n)
check(nb == nil and why == C.COAL_REASON, "chaudieres a sec : le charbon d'abord")
n = base(); n.nominal_kw = 150; n.pending = 1
nb = C.growth({}, n)
check(nb == 1, "un chantier ouvert ne retient pas quand la demande nominale manque encore apres lui")
n = base(); n.nominal_kw = 150; n.pending = C.MAX_PARALLEL
nb, why = C.growth({}, n)
check(nb == nil and why == "un chantier de centrale est ouvert", "au plus C.MAX_PARALLEL chantiers")
n = base(); n.nominal_kw = 150; n.done = C.MAX_PLANTS
nb, why = C.growth({}, n)
check(nb == nil and why == "plafond de centrales", "plafond de centrales garde")
n = base(); n.nominal_kw = 150; n.cool = true
nb = C.growth({}, n)
check(nb == nil, "pause apres refus gardee")

print("== 4. Liaison au charbon : refus et parallele")
local Cv = require("shared.team.champ_vapeur")
local Cc = require("shared.team.charbon_centrale")
check(Cv.after_refusal("foreuses : pas de lot", true) == "grandir", "pas de lot : le treillis grandit (partie du DC 0.7.103)")
check(Cv.after_refusal("foreuses : pas de lot", false) == "attendre", "treillis au maximum : on attend")
check(Cc.MAX_OPEN >= 2, "deux projets d'alimentation a la fois")
check(Cc.RETRY_TICKS <= 7200 and Cc.LONG_RETRY_TICKS <= 36000, "pauses courtes : 2 min puis 10 min")

print(string.format("\nResultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
