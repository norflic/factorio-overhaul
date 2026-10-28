-- Lot FUITE : vague d'ennemis plus LENTS qu'un PNJ (0,12 tuile/tick, comme les fusiliers de faction ; prototype du mod de test
-- fo-autotest-slow-biter) sur le QG : un PNJ les distance, il n'a pas a les combattre un par un. scenarios/ia3k_vague_common.lua.
return require("scenarios/ia3k_vague_common")({ unit = "fo-autotest-slow-biter", n = 10, description = "FUITE : vague d'ennemis lents sur le QG (eloignement ou ralliement)" })
