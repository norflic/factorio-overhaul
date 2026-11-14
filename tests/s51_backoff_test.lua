-- 0.7.110 : attente croissante du tapis de charbon d'une centrale après un échec passager du tracé (2 min, 5 min, puis 15 min)
package.path = "./?.lua;" .. package.path
local Cc = require("shared.team.charbon_centrale")
local ok, ko = 0, 0
local function check(c, m) if c then ok = ok + 1 else ko = ko + 1 print("  ECHEC : " .. m) end end
check(Cc.transient_wait(0) == 7200, "premier essai passager : 2 min")
check(Cc.transient_wait(1) == 18000, "deuxième : 5 min")
check(Cc.transient_wait(2) == 54000, "troisième : 15 min")
check(Cc.transient_wait(9) == 54000, "ensuite : 15 min (borné)")
check(Cc.transient_wait(nil) == 7200, "sans compteur : 2 min")
local h = assert(io.open("script/team/build.lua", "rb")); local src = h:read("*a"); h:close()
check(src:find("Cc.transient_wait(p.transient_n - 1)", 1, true) ~= nil, "câblage : plan_alim lit l'attente croissante")
print(string.format("s51 backoff : %d OK, %d ECHEC", ok, ko))
if ko > 0 then os.exit(1) end
