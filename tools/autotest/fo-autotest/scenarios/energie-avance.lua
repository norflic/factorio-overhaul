-- Lot ENERGIE (2/11) : avance (voir energie_sante_common.lua).
return require("scenarios/energie_sante_common")("avance", { mode = "avance", boilers = 2, radars = 8, expect = "early", check_tick = 72000 })
