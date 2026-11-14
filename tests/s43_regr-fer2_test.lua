--[[
  Sprint s43 (regr-fer2) : une bande de la plaque clé COMMENCÉE (entités bâties) mais sans progrès depuis F.STUCK ticks rouvre l'extension
  thermique tant que la plaque manque (shared/team/famine_cle.lua). Banc s43-parite-seule, graine 271828182, lot s42-gisements : bande 16 de
  votre équipe arrêtée à 348/382, 13 paires de fer à 12 min puis 1 à 39 min, fer 0.
    1. bande commencée qui avance (stalled < F.STUCK) : fermée (règle d'avant) ;
    2. bande commencée sans progrès depuis F.STUCK : ouverte si la plaque manque, fermée sinon ;
    3. appelant d'avant (stalled absent) : la règle d'avant ;
    4. MUTANT : sans la clause, la bande arrêtée garde l'extension fermée (vu).
  Usage : lua5.2 tests/s43_regr-fer2_test.lua
]]
package.path = "./?.lua;" .. package.path
local F = require("shared.team.famine_cle")
local pass, fail = 0, 0
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1 print("  ECHEC : " .. m) end end
local function i(o)
  local t = { starved = true, missing = 0, migr = "en cours", built = 348, project = "chantier" }
  for k, v in pairs(o or {}) do t[k] = v end
  return t
end
check(F.open(i({ stalled = F.STUCK - 1 })) == false, "1. bande commencee qui avance : fermee")
check(F.open(i({ stalled = F.STUCK })) == true, "2. bande arretee depuis F.STUCK, plaque en manque : ouverte")
check(F.open(i({ stalled = F.STUCK, starved = false, missing = 0 })) == false, "2. bande arretee, plaque sans manque : fermee")
check(F.open(i({ stalled = F.STUCK, starved = false, missing = 12 })) == true, "2. bande arretee, manque au besoin evalue : ouverte")
check(F.open(i({})) == false, "3. appelant d'avant (stalled absent) : fermee")
check(F.open(i({ built = 0, stalled = 0 })) == true, "3. bande qui n'a rien bati : ouverte (regle d'avant)")
local src = assert(io.open("shared/team/famine_cle.lua", "rb")):read("*a")
local mut = src:gsub("return %(i%.stalled or 0%) >= F%.STUCK end", "return false end", 1)
local Fm = assert(load(mut, "=famine-mutant", "t"))()
check(Fm.open(i({ stalled = F.STUCK })) == false, "4. MUTANT sans la clause : la bande arretee garde l'extension fermee (vu)")
print(string.format("[S43-REGR-FER2] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
