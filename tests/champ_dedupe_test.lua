--[[
  Lot COMBUSTIBLE-MIGRATION (suite, 9/11) : déduplication des pièces d'un projet de champ (shared/team/champ_dedupe.lua) et son branchement dans
  Build.SITES.champ (script/team/champ.lua). Défaut cherché : INTEG candidat 1d7c6218, projet 9 : 24 tapis et 4 poteaux du réseau du charbon écartés parce que
  leurs tuiles sont au plan du projet 11 (rien ne vérifiait ce que le projet 11 y pose).
  Lancement : lua5.2 tests/champ_dedupe_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local quiet = false
local function check(c, msg) if c then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end end
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end

local function battery(Cd)
  local belt = { name = "b", role = "champ-charbon", dir = 2 }
  check(Cd.same(belt, { name = "b", role = "champ-charbon", dir = 2 }) == true, "même nom, rôle, direction : doublon légitime")
  check(Cd.same(belt, { name = "b", role = "champ-charbon", dir = 4 }) == false, "autre direction : pas un doublon (le tronc irait de travers)")
  check(Cd.same(belt, { name = "b", role = "champ-tapis", dir = 2 }) == false, "autre rôle (tapis d'un autre flux) : pas un doublon")
  check(Cd.same(belt, { name = "u", role = "champ-charbon", dir = 2 }) == false, "autre nom : pas un doublon")
  check(Cd.same({ name = "p", role = "x" }, { name = "p", role = "x", dir = 0 }) == true, "direction absente = 0")
  check(Cd.same(belt, nil) == false, "aucune pièce chez le détenteur : pas un doublon")
  check(Cd.verdict(belt, {}) == "garder", "rien de pris : gardée")
  check(Cd.verdict(belt, { { pid = 11, ent = { name = "b", role = "champ-charbon", dir = 2 } } }) == "ecarter", "une tuile, doublon : écartée")
  check(Cd.verdict(belt, { { pid = 11, ent = { name = "b", role = "champ-charbon", dir = 2 } }, { pid = 11, ent = { name = "b", role = "champ-tapis", dir = 2 } } }) == "conflit",
    "deux tuiles dont une portée par un autre flux : conflit")
  check(Cd.verdict(belt, { { pid = 11, ent = nil } }) == "conflit", "tuile prise sans pièce chez le détenteur : conflit")
  check(Cd.cuts_trunk("conflit", true) == true and Cd.cuts_trunk("conflit", false) == false and Cd.cuts_trunk("ecarter", true) == false and Cd.cuts_trunk("garder", true) == false,
    "seul un conflit sur une pièce du réseau du charbon coupe le tronc")
end

local Cd0 = dofile("shared/team/champ_dedupe.lua")
battery(Cd0)

-- branchement dans l'exécutant (lecture du code)
local src = read("script/team/champ.lua")
check(src:find('require("shared.team.champ_dedupe")', 1, true) ~= nil, "champ.lua requiert la règle")
check(src:find("Cd.verdict(e, held)", 1, true) ~= nil and src:find('Cd.cuts_trunk(Cd.verdict(e, held), e.role == "champ-charbon")', 1, true) ~= nil,
  "Build.SITES.champ : le verdict lit ce que le détenteur porte sur la tuile")
check(src:find("TRONC COUPE", 1, true) ~= nil and src:find("Champ.CFG.cut_wait", 1, true) ~= nil and src:find("cut_wait = 5 * 3600", 1, true) ~= nil,
  "tronc coupé : journal et attente bornée (jamais une impasse)")
local i = src:find("if cut > 0 then", 1, true)
local blk = i and src:sub(i, i + 2200) or ""
check(blk:find("if waiting then return nil", 1, true) ~= nil, "l'attente rend « attendre » (3e valeur vraie), pas un refus définitif")

local function load_with(path, from, to)
  local s = read(path)
  local a, b = s:find(from, 1, true)
  assert(a, "motif de mutant introuvable : " .. from)
  assert(not s:find(from, b + 1, true), "motif de mutant ambigu : " .. from)
  return assert(load(s:sub(1, a - 1) .. to .. s:sub(b + 1), "=" .. path))()
end
local function mutant(label, from, to)
  local Cd = load_with("shared/team/champ_dedupe.lua", from, to)
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(battery, Cd)
  quiet = false
  local caught = failures > f0 or not ok
  passes, failures = p0, f0
  check(caught, "mutant refuse : " .. label)
end
local P = "shared/team/champ_dedupe.lua"
mutant("tronc coupé par un autre flux (rôle ignoré)", "e.name == h.name and e.role == h.role and (e.dir or 0) == (h.dir or 0)", "e.name == h.name and (e.dir or 0) == (h.dir or 0)")
mutant("tronc coupé par un tapis dans l'autre sens (direction ignorée)", "e.name == h.name and e.role == h.role and (e.dir or 0) == (h.dir or 0)", "e.name == h.name and e.role == h.role")
mutant("tronc coupé par une autre pièce (nom ignoré)", "e.name == h.name and e.role == h.role and (e.dir or 0) == (h.dir or 0)", "e.role == h.role and (e.dir or 0) == (h.dir or 0)")
mutant("détenteur vide pris pour un doublon", "if not (e and h) then return false end", "if not e then return false end if not h then return true end")
mutant("la première tuile seule est lue", "for _, x in ipairs(held) do\n    if not M.same(e, x.ent) then return \"conflit\" end\n  end", "if not M.same(e, held[1].ent) then return \"conflit\" end")
mutant("tout conflit coupe le tronc", "return verdict == \"conflit\" and role_coal == true", "return verdict == \"conflit\"")
mutant("aucun conflit ne coupe le tronc", "return verdict == \"conflit\" and role_coal == true", "return false")

print(string.format("[CHAMP-DEDUPE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
