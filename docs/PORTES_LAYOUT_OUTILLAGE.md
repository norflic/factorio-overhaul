# Critères de mesure des lots LAYOUT et OUTILLAGE (écrits AVANT les parties des lots)

Écrit le 28/10/2026, avant toute partie de `mesure-layout` et `mesure-outillage`. Cadre : `docs/PORTES_MESURES.md`
(aucun seuil choisi après lecture, médianes et plages, forces mortes exclues). Les parties de la base commune
(`base-<graine>`, main 72ab9ed exact) et l'essai A/A (`aa-20261020`, main + un commentaire sans effet) existent déjà ;
les parties des lots ne sont pas lancées quand ce fichier est commité.

## Dispositif
- Témoin = `base-<graine>` (main 72ab9ed, scénario `etape1-guide`, 216 300 ticks, sans images, mêmes réglages).
- Lots = `layout-<graine>` (branche `layout` 8ea51c4 + main 72ab9ed, branche de mesure `mesure-layout`) et
  `outillage-<graine>` (branche `outillage` bd92853 + main 72ab9ed, branche `mesure-outillage`), mêmes scénario et
  arguments, 4 graines de JUGEMENT : 20261020, 123456789, 271828182, 1618033988. Une partie par graine et par lot,
  jouée une seule fois (pas de rejeu pour « corriger » une graine).
- Bruit de trajectoire : écart `aa-20261020` − `base-20261020` (même code de jeu, commentaire en plus). Il est donné à côté
  de chaque écart ; un écart de lot est dit « hors A/A » s'il dépasse en valeur absolue l'écart A/A de la même
  graine sur le même indicateur (si l'A/A est identique à la base, tout écart non nul est hors A/A : cela ne dit rien
  de plus qu'« il y a divergence », F252).
- Outil : `tools/autotest/lot_compare.py` (appariement par graine ; votre équipe et factions séparées ; forces
  mortes listées, pas moyennées). Les tableaux complets sont ceux de `fonction_mesures.py`.

## Règle de verdict, la même pour tout indicateur
Pour un indicateur et une minute (60 de référence, 40 et 20 donnés pour information) : l'écart apparié `d_s` de chaque
graine s = lot − base (pour les factions : médiane des factions vivantes dans les deux parties ; pour le joueur : sa
valeur, s'il est vivant dans les deux).
- **RÉGRESSION** : `d_s < 0` pour au moins 3 graines sur 4 ET médiane des `d_s` < 0.
- **GAIN** : `d_s > 0` pour au moins 3 graines sur 4 ET médiane > 0.
- **INDISTINCT** sinon : l'écart est dans la dispersion des trajectoires ; ce n'est ni une régression ni un gain.
- **Mort** : une force vivante dans la base à la minute 60 et morte (aucun corps de PNJ) dans le lot sur la même
  graine est une ALERTE à part, quelle que soit la règle ci-dessus.
Avec 4 graines, 3 sur 4 de même signe arrive une fois sur 3 par hasard (2 × 5/16) : un verdict RÉGRESSION ou GAIN est
un indice fort à confirmer sur d'autres graines, pas une preuve ; INDISTINCT n'est pas « sans effet ».

## LAYOUT (agencement des champs du plan directeur ; mêmes effectifs et réglages)
Critère demandé : pas de dégradation des soldats, des tourelles et des foreuses électriques en marche ; fours
productifs et foreuses en marche au moins égaux. Indicateurs (à 60 min ; détail 20, 40) :
1. soldats vivants par faction (lignes `[FO-VERIF-GUIDE] minute N`, champ `soldats`) ;
2. tourelles armées (nombre = `tourelles` posées × part `armees`) pour le joueur et les factions ;
3. foreuses électriques en marche (nombre = posées × part `working`) ;
4. foreuses en marche, électriques + à combustion (nombre) ;
5. fours productifs (nombre de fours à ≥ 50 % de la cadence nominale) et fours ayant produit ;
6. information (pas de verdict) : plaques/min des statistiques, fours alimentés structurellement, tapis utiles.
LAYOUT est « sans dégradation » si AUCUN des indicateurs 1 à 5 n'est en RÉGRESSION ni en ALERTE de mort ; il est
« au moins égal » sur 4 et 5 s'ils ne sont pas en RÉGRESSION. Un GAIN est noté, non exigé.

## OUTILLAGE (étalement des pensées de factions et outils du banc)
Critère demandé : aucune dégradation fonctionnelle, gels de pensées plus courts. L'étalement change le déterminisme
(F252) : une trajectoire différente n'est PAS une régression ; seul l'ensemble des 4 graines juge.
1. Fonctionnel : les mêmes indicateurs 1 à 5 que LAYOUT, même règle. « Aucune dégradation » = aucun en RÉGRESSION ni
   en ALERTE de mort.
2. Gels (lus au journal et à `benchmark-stdout`, hors jeu, par `lot_compare.py`) : pour chaque partie, après le tick
   3 600 (hors création de la carte) : `scriptUpdate` maximal d'un tick, 99e centile, nombre de pics (> max(4 × médiane,
   3 ms)), surcoût moyen des pics par tick, et le poste `faction:think` du profileur (ms par tick). « Plus courts » =
   le maximum, le 99e centile et le surcoût des pics sont plus petits que la base sur au moins 3 graines sur 4 ET en
   médiane ; sinon INDISTINCT.
3. Réserve : les durées au tick dépendent de la charge du PC et des parties voisines (F30). Ces parties ne sont pas
   lancées avec `--seul` : les temps ne sont qu'un indice, pas la mesure K10. Pour une mesure décisive, une paire
   base/outillage doit être jouée `--seul` (accord du DC), non lancée ici.

## Ce que ces critères ne prouvent pas
Qu'une base de PNJ soit « bien construite » (la lecture des tableaux complets reste nécessaire) ; que les effets dépassent
la variabilité entre graines au-delà des 4 jouées ; que les gels disparaissent sur la machine du DC en partie réelle.
