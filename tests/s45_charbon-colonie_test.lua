package.path = "./?.lua;" .. package.path
local Ss = require("shared.team.site_sature")
local ok, n = 0, 0
local function check(c, m) n = n + 1; if c then ok = ok + 1 else print("ECHEC " .. m) end end
check(Ss.wants_site({ full = false, exploited = 1, growable = false, sites = 0 }), "sature sous effectif : site demande")
check(not Ss.wants_site({ full = false, exploited = 0, sites = 0 }), "non exploite sous effectif : rien")
check(Ss.wants_site({ full = true, exploited = 0, sites = 0 }), "ancienne garde gardee")
check(not Ss.wants_site({ full = true, exploited = 1, growable = true, sites = 0 }), "encore extensible : rien")
check(not Ss.wants_site({ full = false, exploited = 1, sites = 1 }), "site connu : rien")
check(not Ss.wants_site({ full = true, prudent = true, exploited = 1, sites = 0 }), "prudent : rien")
print(string.format("s45_charbon-colonie : %d/%d OK", ok, n))
if ok ~= n then os.exit(1) end
