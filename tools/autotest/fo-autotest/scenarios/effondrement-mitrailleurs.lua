-- Lot CORR-RALLIEMENT : la vague de mitrailleurs, regle du debordement ALLUMEE ; scenarios/effondrement_mitrailleurs_common.lua.
-- 7/11 (0.6.59, decision du lead) : depuis la portee 16 du mitrailleur (b142714d), il ne deborde plus les mitrailleuses du QG (18 ;
-- ecart 16 - 18 + 0,99 = -1,01, point (C)). Le banc devient le TEMOIN DE NON-DEBORDEMENT. Attendus ECRITS AVANT
-- (fo-logs/2026-11-07_DANGER/BANCS-TENUE.md) : aucun debordement juge, ralliement, aucun eloignement ; PNJ perdus <= 2 (inchange).
return require("scenarios/effondrement_mitrailleurs_common")(false,
  { hq_expect = { hq_outranged = "zero", hq_rally = "pos", hq_away = "zero" } })
