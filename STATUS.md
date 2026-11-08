# STATUS BLOCAGE-COMBUSTIBLE (8/11, avant redemarrage du PC)
- Branche blocage-combustible, SHA a36fd18f (base 8635c3f7 ; 6ffeab64 = journal [FO-RAVITAILLEMENT] seul). Tout est commite, dans la 0.6.67.
- Correction : le charbon des coffres PROPRES d'un avant-poste remplit ses bruleurs sur place meme si Stock.skip_fn l'ecarte (shared/team/ravitaillement.lua, outposts.lua) ; tournee futile = 60 s sans nouveau signal de manque.
- Mesure mesure-dc-temoin, minute 10, part no_fuel (depart 6ffeab64 -> apres a36fd18f) : emerald 40,1 -> 5,7 % (÷7) ; azure 38,0 -> 20,1 % (÷1,9, PAS ÷3) ; player 22,7 -> 11,1 ; scarlet 18,2 -> 20,8 ; amber 1,3 -> 0.
- Archives : fo-logs/2026-11-08_BLOCAGE-COMBUSTIBLE/ (CRITERES.md, depart/, apres/, lire_statuts.py).
- Manque : azure (fours no_fuel 26 %, no_ingredients 63 %) : cause NON lue (fours du plan directeur / tournees rares ?). iag_test §9 « sous 20 ms » a echoue sous charge : a rejouer seul.
- Prochaine etape exacte : sur accord du lead, remettre en file UN ticket 18 100 ticks, scenario mesure-dc-fuel (collect_probe par avant-poste + sac des PNJ), source = scratchpad bc/src-apres (a refaire : bc/prepare_source.sh <worktree> a36fd18f <dest> puis ajouter scenarios/mesure-dc-fuel.lua + KIT_EGAL) ; envoyer la lecture a fonderie-bloc et au lead ; aucun code nouveau sans accord du lead.
