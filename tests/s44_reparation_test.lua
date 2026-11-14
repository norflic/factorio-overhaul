-- Lot s44 reparation : règle « secteur sous attaque, sans couverture » (shared/team/secteur_attaque.lua).
package.path = "./?.lua;" .. package.path
local Sa = require("shared.team.secteur_attaque")

local ok, ko = 0, 0
local function check(cond, msg)
  if cond then ok = ok + 1 else ko = ko + 1 print("ECHEC : " .. msg) end
end

local m = Sa.new()
local no_cover = function() return false end
local cover = function() return true end

-- rien n'est mort : pas d'attente
check(not Sa.must_wait(m, "generator", 100, 100, 1000, no_cover), "calme : pas d'attente")

-- la centrale tombe en (113.5, 246.5) au tick 1000
Sa.note(m, 113.5, 246.5, 1000)
check(Sa.under_attack(m, 120.5, 232.5, 1000 + 1800), "30 s apres, a 15 tuiles : sous attaque")
check(Sa.must_wait(m, "transport-belt", 120.5, 232.5, 2800, no_cover), "sans tourelle active : la pose attend")
check(not Sa.must_wait(m, "transport-belt", 120.5, 232.5, 2800, cover), "tourelle active a portee : reprise")
check(not Sa.must_wait(m, "ammo-turret", 120.5, 232.5, 2800, no_cover), "la pose d'une tourelle n'est jamais retenue")
check(not Sa.must_wait(m, "electric-turret", 113.5, 246.5, 1001, no_cover), "tourelle electrique non retenue")
check(not Sa.must_wait(m, "transport-belt", 200, 246.5, 2800, no_cover), "hors secteur (86 tuiles) : pas d'attente")
check(not Sa.must_wait(m, "transport-belt", 120.5, 232.5, 1000 + Sa.T, no_cover), "attaque finie (1 min sans mort) : reprise")

-- cover_fn n'est consulte que sous attaque
local called = false
Sa.must_wait(m, "transport-belt", 500, 500, 2800, function() called = true return false end)
check(not called, "couverture non calculee hors attaque")

-- memoire bornee et oubli
for i = 1, Sa.MAX + 10 do Sa.note(m, i, 0, 5000 + i) end
check(#m.hits == Sa.MAX, "memoire bornee a Sa.MAX")
Sa.prune(m, 5000 + Sa.T + Sa.MAX + 20)
check(#m.hits == 0, "oubli apres Sa.T")

-- couverture
check(Sa.covered({ { x = 0, y = 0, range = 18, active = true } }, 10, 10), "tourelle active a 14 tuiles, portee 18 : couvre")
check(not Sa.covered({ { x = 0, y = 0, range = 18, active = false } }, 10, 10), "tourelle vide : ne couvre pas")
check(not Sa.covered({ { x = 0, y = 0, range = 10, active = true } }, 10, 10), "hors portee : ne couvre pas")
check(not Sa.covered({}, 0, 0), "aucune tourelle : ne couvre pas")
check(Sa.turret_active("ammo-turret", 5, 0, 0) and not Sa.turret_active("ammo-turret", 0, 0, 0), "munitions")
check(Sa.turret_active("electric-turret", 0, 1, 0) and not Sa.turret_active("electric-turret", 0, 0, 0), "energie")
check(Sa.turret_active("fluid-turret", 0, 0, 3) and not Sa.turret_active("fluid-turret", 0, 0, 0), "fluide")

print(string.format("s44_reparation : %d OK, %d ECHEC", ok, ko))
if ko > 0 then os.exit(1) end
