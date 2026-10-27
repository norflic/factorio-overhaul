-- Lot IA3-k (C2, D1) : ennemis posés sur la route des tournées ; >= 90 % des PNJ changent de route ou s'arrêtent avant
-- d'entrer à portée (scenarios/ia3k_common.lua). Lancement : banc.py ... -- 44100 ia3k-route <source>. Journal : [FO-IA3K-ROUTE].
return require("scenarios/ia3k_common").trips({ tag = "IA3K-ROUTE", mode = "route", temoin = false, description = "IA3-k C2 : ennemis poses sur la route des tournees (reaction avant portee)" })
