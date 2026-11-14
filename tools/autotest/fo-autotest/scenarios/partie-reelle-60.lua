-- Lot PARTIE-REELLE : comme partie-reelle-120, captures à 60 min (scenarios/pavage_common.lua, base "partie").
-- s43 sonde-charbon : combustible du QG par minute et par équipe, sans plafond (scenarios/sonde_charbon.lua, lignes [FO-SONDE-CHARBON]).
return require("scenarios/sonde_charbon")(require("scenarios/pavage_common")(60, "partie"), 60)
