package.path = "./?.lua;" .. package.path
local F = require("shared.team.falaise")
assert(F.skip_refused(true, nil, false, 6, 6) == true, "mur a la limite")
assert(F.skip_refused(true, nil, false, 5, 6) == false, "mur sous la limite")
assert(F.skip_refused(nil, "mining-drill", true, 6, 6) == true, "foreuse refusee par falaise")
assert(F.skip_refused(nil, "mining-drill", nil, 6, 6) == false, "foreuse refusee sans falaise")
assert(F.skip_refused(nil, "transport-belt", true, 6, 6) == false, "tapis refuse par falaise : pas saute")
assert(F.skip_refused(nil, "mining-drill", true, 2, 6) == false, "foreuse sous la limite")
print("s50_falaises_test OK")
