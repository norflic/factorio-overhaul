-- s43 scen-raid : déclaration raid_avant_poste, action « raid » du format et règle pure F.cible_raid.
-- Usage : lua5.2 tests/s43_scen-raid_test.lua (depuis la racine du mod).
package.path = "./?.lua;" .. package.path
local F = require("shared.scenarios.format")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

-- 1. La déclaration est valide et son raid tombe à la minute 25.
local s = require("shared.scenarios.raid_avant_poste")
check(F.valider(s) == nil, "raid_avant_poste valide : " .. tostring(F.valider(s)))
check(F.ticks(s) == 35 * 3600 + 600, "ticks")
local acts = F.actions_a(s, 25)
check(#acts == 1 and acts[1].action == "raid" and acts[1].n == 8, "raid a la minute 25")
check(#F.actions_a(s, 24) == 0, "rien a la minute 24")
check(#F.attendus_a(s, 35) >= 2, "attendus juges a la minute 35")

-- 2. Défauts de l'action raid.
local function with(a)
  local t = { nom = "x", duree_min = 10, description = { fr = "a", en = "b" }, mise_en_scene = { a },
    theorie = { { id = "a", texte = { fr = "a", en = "a" }, predicat = { type = "seuil", champ = "c", minute = 5, op = "<=", valeur = 1 } } } }
  return F.valider(t)
end
check(with({ minute = 2, action = "raid", attaquant = "scarlet", soldat = "rifleman", n = 4 }) == nil, "raid complet valide")
check(with({ minute = 2, action = "raid", soldat = "rifleman", n = 4 }) ~= nil, "raid sans attaquant refuse")
check(with({ minute = 2, action = "raid", attaquant = "scarlet", soldat = "rifleman", n = 0 }) ~= nil, "raid n = 0 refuse")
check(with({ minute = 2, action = "raid", attaquant = "scarlet", n = 2 }) ~= nil, "raid sans soldat refuse")

-- 3. F.cible_raid : la plus éloignée, égalités par x puis y, seuil de distance.
local hq = { x = 0, y = 0 }
local p, d = F.cible_raid({ { x = 10, y = 0 }, { x = 0, y = -90 }, { x = 50, y = 50 } }, hq, 40)
check(p and p.x == 0 and p.y == -90 and math.abs(d - 90) < 1e-9, "la plus eloignee")
p = F.cible_raid({ { x = 60, y = 0 }, { x = 0, y = 60 }, { x = -60, y = 0 }, { x = 0, y = -60 } }, hq, 40)
check(p and p.x == -60 and p.y == 0, "egalite : x le plus petit")
p = F.cible_raid({ { x = 0, y = 60 }, { x = 0, y = -60 } }, hq, 40)
check(p and p.y == -60, "egalite : puis y le plus petit")
local q = F.cible_raid({ { x = 0, y = -60 }, { x = 0, y = 60 } }, hq, 40)
check(q and q.y == -60, "independant de l'ordre de la liste")
p, d = F.cible_raid({ { x = 10, y = 10 } }, hq, 40)
check(p == nil and d and d > 14 and d < 15, "trop pres du QG : aucune cible, distance rendue")
p, d = F.cible_raid({}, hq, 40)
check(p == nil and d == nil, "aucune foreuse")

print(string.format("s43 scen-raid : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
