# STATUS DEBUG-CERVEAU (8/11, avant redemarrage du PC)
- Branche debug-cerveau, SHA 09c3941530d7b4308a08558f2405358ef1138672 (V2.4), integre dans 0.6.69 et 0.6.70. Rien de non commite hors ce fichier.
- Fait : panneau PNJ (tache, etapes, cause, 5 suivantes, sac, equipe, raison RIEN-A-FAIRE), blocs ENTREE/SORTIE, lignes quai/bus/piquage/rapatriement (rouge + cause), tampons, repartiteur, texte riche [item=X].
- Tests : debug_cerveau 207 OK, debug_cerveau_vue 114 OK, debug_liens 56, locales 1100, doublons 10, api_lint 3150/0 ; micro-banc 3 (V2.1) 6 OK.
- MANQUE 1 : captures en images (jamais vues). Scenario pret : tools/autotest/fo-autotest/scenarios/dbg-cerveau-photo.lua (lignes FICTIVES via remote demo).
  Commande : py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache --ticks 9700" --qui DEBUG-CERVEAU -- 9600 dbg-cerveau-photo <worktree>
  Seulement quand le lead l'autorise (une seule instance Factorio) ; regarder chaque x-dbgc-*.png.
- FAIT (V2.5) : gate_why/gate_tick et f.team.zero_idle.last lus (zero-idle, branche zero-idle-2, non fusionnes : champs absents = rien affiche).
- MANQUE 3 : Gel.status(e) quand X10-GEL est fusionne (lecture des statuts dans lecture.lua).
- Un seul lua5.2 a la fois, nice -n 19 (ordre du DC).
