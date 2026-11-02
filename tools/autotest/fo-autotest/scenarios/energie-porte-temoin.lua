-- Lot ENERGIE (2/11) : porte-temoin (voir energie_sante_common.lua).
return require("scenarios/energie_sante_common")("porte-temoin", { mode = "porte", boilers = 1, expect = "dead", off = true, check_tick = 72000 })
