-- Lot ENERGIE (2/11) : froid-temoin (voir energie_sante_common.lua).
return require("scenarios/energie_sante_common")("froid-temoin", { mode = "froid", boilers = 3, radars = 4, expect = "dead", off = true, check_tick = 108000 })
