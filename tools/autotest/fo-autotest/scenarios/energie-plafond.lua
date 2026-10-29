-- Lot CORR-ENERGIE : charge de 6 MW, regle allumee : jamais plus de 3 centrales finies.
return require("scenarios/energie_demande_common")("plafond", { radars = 20, expect = "cap", check_tick = 60000 })
