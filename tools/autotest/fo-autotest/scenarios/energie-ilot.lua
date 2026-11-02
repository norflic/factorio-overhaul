-- Lot ENERGIE (2/11) : ilot, 10 poteaux retires, aucun ennemi (regle allumee) (voir energie_sante_common.lua).
return require("scenarios/energie_sante_common")("ilot", { mode = "ilot", boilers = 3, radars = 4, expect = "heal", check_tick = 72000 })
