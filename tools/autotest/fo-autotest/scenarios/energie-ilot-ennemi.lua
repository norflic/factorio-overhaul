-- Lot ENERGIE (2/11) : ilot-ennemi, 10 poteaux retires et un ennemi immobile au milieu (second chemin) (voir energie_sante_common.lua).
return require("scenarios/energie_sante_common")("ilot-ennemi", { mode = "ilot", boilers = 3, radars = 4, enemy = true, expect = "heal", back_min = 10, check_tick = 72000 })
