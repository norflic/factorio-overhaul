-- Lot INDUSTRIE I2 : témoin, file sûre ÉTEINTE (comportement de 0.6.28), même carte (scenarios/ind_inactifs_common.lua).
-- Lancement : banc.py --out <archive> --qui IND-I2 -- 5000 ind-inactifs-avant <source>. Journal : [FO-IND-INACTIFS-AVANT].
return require("scenarios/ind_inactifs_common")("ind-inactifs-avant", false)
