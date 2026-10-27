-- Lot IA3-k (C1) : allers successifs vers les mêmes sites, sans ennemi ; écart latéral médian >= 4 tuiles dans >= 50 % des
-- paires, aller allongé de <= 15 % (scenarios/ia3k_common.lua). Lancement : banc.py ... -- 44100 ia3k-variete <source>.
return require("scenarios/ia3k_common").trips({ tag = "IA3K-VARIETE", mode = "variete", temoin = false, description = "IA3-k C1 : variete des trajets vers les memes sites" })
