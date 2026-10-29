--[[
  Tests hors jeu du lot INSTRUMENT-CENTRALE : la ligne [FO-CENTRALE-MORT] (shared/team/centrale_mort.lua). Usage :
  lua5.2 tests/centrale_mort_test.lua
  Vérifie : cause lue (« inconnue » sans événement), tourelles armées / vides / électriques / à fluide et la plus proche armée, ennemi
  présent ou absent, champs manquants sans erreur, déterminisme ; MUTANTS ; le module de script ne touche ni global ni control.lua.
]]
package.path = "./?.lua;" .. package.path
local C = require("shared.team.centrale_mort")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

section("1. Cause")
check(C.cause(nil) == "inconnue", "pas de tueur : inconnue")
check(C.cause({}) == "inconnue", "tueur sans champ : inconnue")
check(C.cause({ name = "x", type = "unit", force = "enemy" }) == "x/unit/enemy", "nom, type, force lus à l'événement")
check(C.cause({ name = "x" }) == "x/?/?", "champs manquants : points d'interrogation")
check(C.cause("texte") == "inconnue", "valeur inattendue : inconnue")

section("2. Tourelles")
local r = C.turrets({
  { kind = "munitions", rounds = 10, dist = 12 }, { kind = "munitions", rounds = 0, dist = 3 },
  { kind = "munitions", rounds = 5, dist = 20 }, { kind = "electrique", dist = 8 }, { kind = "fluide", dist = 9 },
})
check(r.armees == 2 and r.vides == 1 and r.electriques == 1 and r.fluides == 1, "comptes : 2 armées, 1 vide, 1 électrique, 1 à fluide")
check(r.nearest_armed == 12, "la plus proche ARMÉE est à 12 (la vide à 3 ne compte pas)")
check(r.nearest_any == 3, "la plus proche, armée ou non : 3")
local r0 = C.turrets({})
check(r0.armees == 0 and r0.nearest_armed == nil, "aucune tourelle : aucune armée, pas de distance")
check(C.turrets(nil).armees == 0, "liste absente : sans erreur")

section("3. Ligne")
local rec = { minute = 54.04, force = "player", type = "boiler", name = "boiler", x = 10.25, y = -20.5,
  cause = { name = "medium-biter", type = "unit", force = "enemy" }, killer_force = "enemy", damage = "physical", hq_dist = 123.44,
  turrets = { { kind = "munitions", rounds = 8, dist = 17.3 }, { kind = "munitions", rounds = 0, dist = 5 } },
  enemy = { type = "unit-spawner", name = "biter-spawner", dist = 88.9 } }
local l = C.line(rec)
check(l:find("%[FO%-CENTRALE%-MORT%] minute 54%.0 ") ~= nil, "préfixe et minute")
check(l:find("force player", 1, true) and l:find("boiler (boiler) en (10.2, -20.5)", 1, true) ~= nil or l:find("en (10.2, -20.5)", 1, true), "force, type et position")
check(l:find("cause medium-biter/unit/enemy", 1, true) ~= nil, "cause lue")
check(l:find("force tueuse enemy", 1, true) and l:find("degats physical", 1, true), "force tueuse et dégâts")
check(l:find("QG a 123.4 tuiles", 1, true) ~= nil, "distance au QG")
check(l:find("armees 1 (la plus proche armee a 17.3), electriques 0, fluides 0, vides 1", 1, true) ~= nil, "tourelles : 1 armée à 17,3, 1 vide")
check(l:find("ennemi le plus proche : unit-spawner/biter-spawner a 88.9 tuiles", 1, true) ~= nil, "ennemi le plus proche")
check(C.line(rec) == l, "déterministe")
local bare = C.line({})
check(bare:find("cause inconnue", 1, true) and bare:find("aucun a 150 tuiles", 1, true) and bare:find("QG a ?", 1, true), "enregistrement vide : sans erreur, inconnue partout")
check(not l:find("\n", 1, true), "une seule ligne")
local noenemy = rec.enemy
rec.enemy = nil
check(C.line(rec):find("aucun a 150 tuiles", 1, true) ~= nil, "pas d'ennemi à portée : « aucun a 150 tuiles »")
rec.enemy = noenemy

section("4. Mutants")
do
  -- (a) une tourelle vide compterait comme armée
  local list = { { kind = "munitions", rounds = 0, dist = 3 } }
  check(C.turrets(list).armees == 0 and C.turrets(list).nearest_armed == nil, "mutant « vide = armée » : détecté")
  -- (b) la tourelle électrique serait comptée avec les armées à munitions
  check(C.turrets({ { kind = "electrique", dist = 4 } }).armees == 0, "mutant « électrique = munitions » : détecté")
  -- (c) la cause serait lue d'ailleurs : sans événement elle doit rester « inconnue »
  check(C.cause(nil) == "inconnue", "mutant « cause inventée » : détecté")
  -- (d) la distance à la plus proche armée prendrait la plus proche tout court
  local two = { { kind = "munitions", rounds = 0, dist = 3 }, { kind = "munitions", rounds = 4, dist = 11 } }
  check(C.turrets(two).nearest_armed == 11, "mutant « la plus proche, armée ou non » : détecté (11 et non 3)")
end

section("5. Le module de script reste en lecture seule")
local f = io.open("script/team/centrale_mort.lua", "r")
local src = f and f:read("*a") or ""
if f then f:close() end
check(src ~= "", "module de script lu")
-- le code seul : sans le bloc d'en-tête ni les commentaires de fin de ligne
local code = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check(not code:find("global", 1, true) and not code:find("Storage", 1, true), "ni global ni Storage")
check(not code:find("[^i]pairs%(") and not code:find("^pairs%("), "aucune boucle pairs non triée")
check(not code:find("%.destroy") and not code:find("create_entity") and not code:find("%.damage%s*%(") and not code:find("%.die%s*%("),
  "aucun appel qui change la partie")
local ctl = io.open("control.lua", "r")
local csrc = ctl and ctl:read("*a") or ""
if ctl then ctl:close() end
check(not csrc:find("centrale_mort", 1, true), "control.lua ne mentionne pas le module")

print(string.format("[CENTRALE-MORT] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
