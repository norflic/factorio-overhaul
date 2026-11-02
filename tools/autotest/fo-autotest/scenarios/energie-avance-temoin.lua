-- Lot ENERGIE (2/11) : avance-temoin (voir energie_sante_common.lua).
return require("scenarios/energie_sante_common")("avance-temoin", { mode = "avance", boilers = 2, radars = 9, expect = "dead", off = true, check_tick = 72000 })
