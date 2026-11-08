-- Lot CORR-RALLIEMENT (tenue, 7/11, 0.6.59) : la vague d'effondrement avec des GRENADIERS (fo-amber-rocketeer : portee 26, boite a
-- boite), seuls a deborder encore les tourelles du QG depuis la portee 16 du mitrailleur (b142714d). Regle allumee : la tenue joue.
-- Attendus ECRITS AVANT (fo-logs/2026-11-07_DANGER/BANCS-TENUE.md) : debordement, eloignement, aucun ralliement, PNJ perdus <= 2 ;
-- lu au journal : 0 PNJ tue sur sa case du QG pendant la vague.
return require("scenarios/effondrement_mitrailleurs_common")(false, { unit = "fo-amber-rocketeer" })
