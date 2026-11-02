-- Lot ENERGIE (2/11) : porte (voir energie_sante_common.lua).
return require("scenarios/energie_sante_common")("porte", { mode = "porte", boilers = 1, expect = "gate", check_tick = 72000 })
