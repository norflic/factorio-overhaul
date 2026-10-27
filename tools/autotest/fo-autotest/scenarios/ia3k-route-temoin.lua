-- Lot IA3-k : TÉMOIN de ia3k-route, réglage fo-war-ia3-comportement éteint (comportement de main).
-- Lancement : banc.py ... -- 54700 ia3k-route-temoin <source>. Journal : [FO-IA3K-ROUTE-TEMOIN].
return require("scenarios/ia3k_common").trips({ tag = "IA3K-ROUTE-TEMOIN", mode = "route", temoin = true, description = "IA3-k temoin C2 : reglage eteint" })
