# Critères de la reconnaissance régulière (lot VEILLE, branche `recon-eclaireurs`)

Écrits AVANT toute mesure (28/10, demande du lead après le lot RECON parqué). La visée est celle de `main` : la règle « ne viser que ce
qu'on a reconnu » reste sur la branche `recon` (parquée). Ce lot n'ajoute que la reconnaissance régulière (D-24, DC : « elles doivent
aussi faire de la reconnaissance comme un joueur »).

## Règle (shared/faction/veille.lua, pure)
- Un vivier réservé : un soldat marqué éclaireur, payé en plus de l'armée (kit du stock libre), jamais compté dans la garnison. Il est
  fabriqué seulement quand l'armée de départ (10 soldats hors éclaireur) et les tourelles du QG sont en place, puis REMPLACÉ s'il est
  perdu (délai doublé par perte récente, 4 doublements au plus).
- Cadence : un départ par intervalle, 10 min ÷ curiosité (500 à 2 000 pour mille), allongé de (1 000 + 2 × menace) ÷ 1 000.
- Rayon croissant : R = 300 tuiles + 150 par trajet réussi, 1 600 au plus ; le but est un secteur GÉNÉRÉ de la bande R ± 96 tuiles autour
  du QG, jamais vu ou vu depuis plus de 20 min, le plus ancien d'abord, en alternant les octants ; trajet dégagé de tout nid ou ver vu.
- Pas de départ : survie, QG en alerte, tourelles du QG incomplètes, ennemi (unité ou nid) à 100 tuiles du QG, mort d'un soldat de la
  faction depuis moins de 5 min, menace > 100. La guerre contre le joueur N'empêche PAS le départ (le vivier n'est pas la réserve).
- Chaque refus est compté par raison dans `f.stats.veille_refus` (une pensée du commandant = une unité) et publié par ligne `[FO-VEILLE]`.

## Critères de mesure (4 graines : 20261020, 123456789, 271828182, 1618033988, contre `MESURES/base-<graine>`, 60 min)
1. Éclaireurs partis : au moins 0,5 par faction et par 10 min, mesuré sur les fenêtres où le vivier existe et le QG est calme
   (premier départ possible dès que l'armée de départ est faite). Une faction qui n'atteint jamais l'armée de départ est signalée,
   pas comptée contre la règle.
2. Perdus : au plus 30 % des éclaireurs partis (par graine, toutes factions).
3. Secteurs reconnus (champ `k.m.n` de la carte de connaissance, lignes `[FO-IA3F]` / `[FO-VEILLE]`) à 20, 40 et 60 min : au moins ceux de
   la base sur 3 graines au moins, et en hausse sur au moins 2.
4. Défense : aucune faction sous la base de plus de 2 soldats ou 1 tourelle à 12, 40 et 60 min (soldats HORS vivier), ni PNJ de votre
   équipe en moins (compte de l'équipe du joueur et pertes), ni attaque de plus vers le joueur.
5. Coût du vivier : plaques de fer et kits consommés par les éclaireurs (lignes `[FO-VEILLE]`), comparés au fer au coffre et à l'effectif
   de la base ; rapportés, non bloquants.
6. Aucune attaque, aucune cible, aucune décision de visée ne change : lignes `[FO-STRAT] attaque` identiques à la base tant que les
   garnisons sont identiques (contrôle par diff des attaques aux 4 graines).

Verdict par graine : tenu / non tenu pour chaque critère, avec la cause quand une graine dégrade ; pas de fusion si une graine dégrade
sans cause établie (règle du DC).
