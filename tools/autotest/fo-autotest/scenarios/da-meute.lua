-- Lot DANGER-ACTIF : une meute couvre le QG de votre équipe, du travail à l'opposé ; voir scenarios/da_meute_common.lua.
-- Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui DANGER-ACTIF -- 9700 da-meute <source>.
return require("scenarios/da_meute_common")({ tag = "DA-MEUTE",
  description = "DANGER-ACTIF : meute qui couvre le QG, travail a l'oppose (repos > 30 s, morts, sens des departs)" })
