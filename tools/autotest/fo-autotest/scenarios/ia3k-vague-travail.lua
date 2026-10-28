-- Lot FUITE : la vague d'ennemis LENTS (comme int-1) tombe sur des PNJ AU TRAVAIL (tâche « ghost ») répartis sur son chemin
-- et autour des tourelles du QG ; scenarios/ia3k_vague_common.lua.
return require("scenarios/ia3k_vague_common")({ unit = "fo-autotest-slow-biter", n = 10, scatter = true,
  description = "FUITE : vague d'ennemis lents sur des PNJ au travail (rappel, abri, ralliement)" })
