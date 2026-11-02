-- Lot ENERGIE (2/11) : ilot (ligne de poteaux coupee ; voir energie_sante_common.lua).
return require("scenarios/energie_sante_common")("ilot", { mode = "ilot", boilers = 3, radars = 4, expect = "heal", check_tick = 108000 })
