-- tests/backoff_test.lua : shared/core/backoff.lua (pur). Usage : lua5.2 tests/backoff_test.lua
package.path = "./?.lua;" .. package.path
local Bo = require("shared.core.backoff")
local fails, passes = 0, 0
local function check(c, m) if c then passes = passes + 1 else fails = fails + 1; print("  ECHEC : " .. m) end end

local s = {}
check(Bo.due(s, "a", 0, 600), "jamais controle : du")
check(Bo.report(s, "a", 0, true, 600, 36000) == 1200, "sain : 600 -> 1200")
check(not Bo.due(s, "a", 1199, 600), "pas du avant 1200")
check(Bo.due(s, "a", 1200, 600), "du a 1200")
local iv = 1200
for i = 1, 10 do iv = Bo.report(s, "a", 1200 * i, true, 600, 36000) end
check(iv == 36000, "plafond MAX : " .. tostring(iv))
check(Bo.report(s, "a", 99999, false, 600, 36000) == 600, "degrade : retour a BASE")
Bo.report(s, "a", 100000, true, 600, 36000)
Bo.wake(s, "a", 600)
check(Bo.due(s, "a", 100001, 600), "wake : du tout de suite")
check(Bo.interval(s, "a", 600) == 600, "wake : intervalle BASE")
Bo.wake(s, "inconnu", 600)
check(s.inconnu == nil, "wake d'une cle inconnue : rien")
-- déterminisme : deux suites identiques donnent le même état
local s1, s2 = {}, {}
for t = 0, 50000, 700 do
  local sain = (t % 2100) ~= 0
  if Bo.due(s1, "k", t, 600) then Bo.report(s1, "k", t, sain, 600, 36000) end
  if Bo.due(s2, "k", t, 600) then Bo.report(s2, "k", t, sain, 600, 36000) end
end
check(s1.k.iv == s2.k.iv and s1.k.last == s2.k.last, "deterministe")
-- base = rythme d'avant : un bloc jamais sain garde exactement l'intervalle de base
local s3, n = {}, 0
for t = 0, 30000, 300 do if Bo.due(s3, "x", t, 3000) then n = n + 1; Bo.report(s3, "x", t, false, 3000, 36000) end end
check(n == 11, "non sain : rythme de base inchange (" .. n .. ")")
print(string.format("backoff_test : %d ok, %d echec(s)", passes, fails))
if fails > 0 then os.exit(1) end
