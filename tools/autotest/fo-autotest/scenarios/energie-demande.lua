-- Lot CORR-ENERGIE : charge de 2,4 MW sur une centrale de 1,8 MW, regle de croissance ALLUMEE (voir energie_demande_common.lua).
return require("scenarios/energie_demande_common")("demande", { radars = 8, expect = "grow", check_tick = 40000 })
