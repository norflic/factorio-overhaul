-- Lot CORR-RALLIEMENT (tenue, 7/11, 0.6.59) : la meme vague de grenadiers, regle du debordement ETEINTE (temoin). Premiere mesure de
-- cette unite : morts lues SANS seuil (pas de lost_min ni de turret_far) ; controles : aucun debordement juge, ralliement.
-- 8/11 (0.6.64) : sur 30405558, l'equipe prenait fin au tick 2972 (coffre perdu, aucun PNJ vivant) : hq_* lus a vide au constat
-- et « perdus <= 2 » applique malgre seuils = false. Corrige dans les scenarios communs (releve des stats, lost_free) ; attendus
-- ecrits avant : fo-logs/2026-11-07_DANGER/BANCS-TENUE.md §4.
return require("scenarios/effondrement_mitrailleurs_common")(true, { unit = "fo-amber-rocketeer", seuils = false })
