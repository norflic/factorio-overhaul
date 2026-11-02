-- Lot ENERGIE (2/11) : panne (voir energie_sante_common.lua).
return require("scenarios/energie_sante_common")("panne", { mode = "panne", boilers = 1, radars = 3, expect = "heal", check_tick = 90000 })
