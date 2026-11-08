# STATUS lot AMELIORATION (8/11, avant redémarrage du PC)
- SHA : b16520d860810c582cdcb24712fdc38f93c8345e (branche amelioration), déjà versé dans essai-0666 / 0.6.68. Rien d'autre à verser.
- Fait : montée par bloc (shared/ai3/amelioration.lua), chaîne Q16 secondaire, tapis/bras par bloc, gel reconstruction levé sauf manque, payable avant fabriquer.
- Preuves : amelioration_test 59 OK (10 mutants), capital_test 178, iag_test 480. Banc-4 (18 100 ticks, vieille sauvegarde) : 53 foreuses montées, assembleurs niv 2-3, bras rapides, 0 tapis rapide.
- Manque : tapis rapides jamais au stock (à fabriquer par lot par le mall, pas un à la fois : zone mall/intermediaires, pas la mienne) ; aucune mesure en partie neuve.
- Prochaine étape : UN banc en partie neuve à 20 et 40 min (niveaux des tapis, bras, assembleurs) sur une copie de la dernière version jouable, 18 100 ticks au plus, place unique, scénario amelioration-dc (scratchpad src-amel3, à recréer : tools/autotest/fo-autotest/scenarios/amelioration-dc.lua + KIT_EGAL).
- Rappels : un lua5.2 à la fois en nice -n 19 ; ne pas relancer un banc tué ; debug-cerveau lit f.team.capital.refus (cause « reconstruction » à ajouter à Lg.AM_CAUSES).
