-- Lot ENERGIE (2/11) : froid (voir energie_sante_common.lua).
return require("scenarios/energie_sante_common")("froid", { mode = "froid", boilers = 3, radars = 4, expect = "start", check_tick = 108000 })
