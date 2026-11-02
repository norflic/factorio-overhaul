-- Lot ENERGIE (2/11) : panne-temoin (voir energie_sante_common.lua).
return require("scenarios/energie_sante_common")("panne-temoin", { mode = "panne", boilers = 1, radars = 3, expect = "dead", off = true, check_tick = 90000 })
