package.path = "./?.lua;" .. package.path
local Cc = require("shared.team.charbon_centrale")
local n = 0
local function ok(c, m) if not c then error("ECHEC : " .. m) end n = n + 1 end
ok(Cc.transient("attente"), "attente passagere")
ok(Cc.transient("budget tick"), "budget tick passager")
ok(not Cc.transient("minerai"), "minerai = vrai refus")
ok(not Cc.transient("pas de lot"), "pas de lot = vrai refus")
ok(not Cc.transient(nil), "nil = vrai refus")
ok(Cc.TRANSIENT_WAIT > 0 and Cc.TRANSIENT_WAIT < Cc.RETRY_TICKS, "attente plus courte que la pause de refus")
print(n .. " OK")
