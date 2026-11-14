--[[
  s44 GISEMENTS : un ordre couvrir qui remplit à lui seul le reste du gisement ne doit plus être refusé par la boucle de couverture
  (« gisement sans place libre ») : les places libres relues dans le plan comptent déjà ses propres foreuses.
  lua5.2 tests/s44_gisements_test.lua -> [S44-GISEMENTS] BILAN : N OK, 0 ECHEC(S)
]]
package.path = "./?.lua;" .. package.path
local Cv = require("shared.ai3.couverture")
local pass, fail = 0, 0
local function check(ok, msg) if ok then pass = pass + 1 else fail = fail + 1 print("[S44-GISEMENTS] ECHEC : " .. msg) end end

-- Règle pure
check(Cv.free_before(0, 57) == 57, "free 0 + ordre de 57 -> 57 places avant l'ordre")
check(Cv.free_before(10, 6) == 16, "10 + 6 -> 16")
check(Cv.free_before(nil, 6) == nil, "free inconnu reste inconnu")
check(Cv.free_before(0 / 0, 6) == nil, "free NaN reste inconnu")
check(Cv.free_before(0, nil) == 0, "ordre sans n : 0")
check(Cv.free_before(-3, 2) == 2, "free négatif borné à 0")
check(Cv.free_before(0, math.huge) == 0, "n infini ignoré")

-- Branché sur Cv.loop comme script/ai3/capitalisation.lua (root_of)
local base = { kind = "couvrir", product = "p", saturated = {}, crisis = false }
local function loop(free, n)
  local a = {} for k, v in pairs(base) do a[k] = v end
  a.free = Cv.free_before(free, n)
  return Cv.loop(a)
end
local ok, why = loop(0, 57)
check(ok == true, "l'ordre qui remplit le gisement passe en boucle (avant : " .. tostring(why) .. ")")
ok = loop(0, 0)
check(ok == false, "gisement plein et ordre vide : refus gardé")
ok = loop(nil, 57)
check(ok == false, "free inconnu : refus gardé (pas d'ouverture à l'aveugle)")
local a = { kind = "couvrir", product = "p", saturated = { p = true }, free = Cv.free_before(0, 5) }
check(Cv.loop(a) == false, "produit saturé : refus gardé")

print(string.format("[S44-GISEMENTS] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
