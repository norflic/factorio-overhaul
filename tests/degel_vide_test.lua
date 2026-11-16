--[[
  Lot n102-rangee : test hors jeu du dégel SANS OBJET (Mg.thaw_moot, shared/team/migration_champ.lua) et de son effet sur le départ
  progressif (Cp.go, shared/team/chantier_progressif.lua), avec mutant et relecture du câblage (script/team/migration_champ.lua).
  Valeurs rejouées : partie du DC en 0.9.10, équipe player, projet 10 (bande -70 de l'avant-poste 1, fer) :
    11,4 min : plan, « 5 paire(s) thermique(s) dessous (81,91,290,294,298) » -> spec.degel ;
    17,5 min : « 14 paire(s) thermique(s) retiree(s) de force » (toutes les paires de l'avant-poste 1) ;
    29,8 min : kit 250/351 [electric-mining-drill 33/33, inserter 60/60, iron-chest 12/12, small-electric-pole 39/39, stone-furnace 24/24,
               transport-belt 82/183] ; 34,8 min : transport-belt 132/183 ; 36,6 min : kit complet, « partie retiree : 0 foreuse(s) ».
  Usage : lua5.2 tests/degel_vide_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1 print("  ECHEC : " .. m) end end
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end

local Cp = require("shared.team.chantier_progressif")
local MG_SRC = read("shared/team/migration_champ.lua")
local function load_mg(src)
  local fn = assert(load(src, "=migration_champ", "t"))
  return fn()
end

-- noms neutres (la règle ne lit aucun nom) : a = foreuse (tête), b = bras, c = coffre, d = poteau, e = four, f = tapis
local NEED = { a = 33, b = 60, c = 12, d = 39, e = 24, f = 183 }
local LEAD = { a = true }
local function stock(belts) return { a = 33, b = 60, c = 12, d = 39, e = 24, f = belts } end
local function band(belts, degele)
  return { state = "reserve", reason = "materiaux", reopened = nil, degele = degele,
    spec = { champ = { oid = 1, pr = -70 }, degel = { oid = 1, tiles = { 0, 0 } } },
    need = NEED, stock = stock(belts), lead = LEAD }
end

--- La chaîne du symptôme : relevé des paires (present) -> Mg.thaw_moot -> p.degele -> Cp.go. Rend le départ (ok) à `belts` tapis au coffre.
local function chain(Mg, present, belts)
  local p = band(belts, nil)
  if Mg.thaw_moot(p, { present = present }) then p.degele = true end
  return (Cp.go(p)), p
end

local function suite(Mg)
  local ok, bad = 0, {}
  local function c(cond, m) if cond then ok = ok + 1 else bad[#bad + 1] = m end end
  -- 1. la règle pure
  c(Mg.thaw_moot({ state = "reserve", reason = "materiaux" }, { present = 0 }) == true, "aucune paire debout : degel sans objet")
  c(Mg.thaw_moot({ state = "reserve", reason = "materiaux" }, { present = 5 }) == false, "5 paires debout : le degel reste")
  c(Mg.thaw_moot({ state = "reserve", reason = "degel" }, { present = 0 }) == false, "raison degel : le retrait vide garde son chemin")
  c(Mg.thaw_moot({ state = "reserve", reason = "materiaux", degele = true }, { present = 0 }) == false, "degel deja fait : rien a ecrire")
  c(Mg.thaw_moot({ state = "fantomes" }, { present = 0 }) == false, "hors reserve : rien")
  c(Mg.thaw_moot({ state = "reserve", reason = "materiaux" }, {}) == false, "pas de releve : rien")
  c(Mg.thaw_moot(nil, { present = 0 }) == false, "pas de projet : rien")
  -- 2. la chaîne, valeurs du journal (paires retirées de force à 17,5 min : present = 0)
  local go34 = chain(Mg, 0, 132)
  c(go34 == true, "34,8 min, 132/183 tapis, 0 paire debout : la bande part (plancher 122)")
  local go29 = chain(Mg, 0, 82)
  c(go29 == false, "29,8 min, 82/183 tapis : sous le plancher, elle attend encore")
  local go_real = chain(Mg, 5, 132)
  c(go_real == false, "paires encore debout : toute la voie avant le retrait (garde SORTIE-PLAQUES gardee)")
  return ok, bad
end

-- 1. règle livrée
do
  local ok, bad = suite(load_mg(MG_SRC))
  for _, m in ipairs(bad) do check(false, m) end
  check(#bad == 0, "suite verte sur la regle livree (" .. ok .. " OK)")
end

-- 2. l'état d'avant la coupe : dégel au plan, jamais relevé avant le kit complet (Cp.go en tout-ou-rien)
do
  local p = band(132, nil)
  check(Cp.go(p) == false, "ancien chemin : 132/183 tapis et degel au plan -> la bande dort (symptome du DC)")
end

-- 3. mutant : la règle qui ne déclare jamais le dégel sans objet (l'ancien comportement) doit faire échouer la suite
do
  local mut = MG_SRC:gsub("return env%.present == 0\n", "return false\n", 1)
  check(mut ~= MG_SRC, "mutant applique")
  local _, bad = suite(load_mg(mut))
  check(#bad > 0, "mutant refuse (" .. #bad .. " echec(s))")
end

-- 4. câblage
do
  local S = read("script/team/migration_champ.lua")
  local a = S:find("local function thaw_gate(", 1, true)
  local seg = a and S:sub(a, a + 2600) or ""
  check(seg:find("Mg.thaw_moot(p, { present = present0 })", 1, true) ~= nil, "thaw_gate consulte Mg.thaw_moot sur le releve des paires")
  check(seg:find("p.degele, p.reserve_next = true, nil", 1, true) ~= nil, "thaw_gate pose p.degele (un seul ecrivain : migration_champ)")
  check(seg:find("purge_recon(f, o)", 1, true) ~= nil, "registre de reconstruction ecarte comme au retrait vide")
  local B = read("script/team/build.lua")
  check(B:find("degele = p.degele, spec = p.spec", 1, true) ~= nil, "build.lua : Cp.go lit p.degele")
  check(not MG_SRC:find("transport%-belt") and not MG_SRC:find("electric%-mining%-drill"), "aucun nom d'objet en dur dans la regle")
end

print(string.format("[DEGEL-VIDE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
