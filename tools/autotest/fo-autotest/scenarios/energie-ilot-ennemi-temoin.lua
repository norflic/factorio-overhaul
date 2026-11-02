-- Lot ENERGIE (2/11) : ilot-ennemi-temoin, meme chose, second chemin coupe (regle d'avant : rien n'est reconstruit) (voir energie_sante_common.lua).
return require("scenarios/energie_sante_common")("ilot-ennemi-temoin", { mode = "ilot", boilers = 3, radars = 4, enemy = true, expect = "dead", off_coupure = true, check_tick = 72000 })
