# D05 : « le temps de réglage » (TODO vidéo, l.260)

## Ce que dit la vidéo
« about six months total … most of that was tweaking » : le gros du temps de développement a été consacré au réglage,
pas à l'écriture des règles.

## Ce que cela vaut pour nous
Le point est un point de méthode, sans code. Il dit où le temps part : la plus grande part de notre travail sera le
réglage des seuils et des marches (portes, paliers, quotas, plafonds), et non l'écriture des règles pures.

## Comment on le mesure chez nous
- **Au moteur simulé** (tests/video_ab_test.lua, section 3) : le BILAN indique le coût d'un réglage en parties jouées et en
  minutes de jeu simulées (`coût : N parties, M minutes simulées`). Chaque réglage coûte une partie éteinte, une allumée et
  les mutants ; c'est le coût d'une vérification, pas celui d'un réglage. Au 8/11 : 17 parties, 136 minutes simulées
  (quatre réglages, 8 minutes de jeu chacune).
- **Au moteur réel**, le temps de réglage se lit dans les bancs : un réglage = un passage de `banc.py` par valeur
  (`--qui <lot>`), archivé dans `<racine>\fo-logs\<date>_<lot>\`, avec `done.txt` (horodatage de fin) et le BILAN du
  scénario. Le nombre d'archives par lot et l'écart entre leurs `done.txt` donnent le temps réel passé à régler.
- **Limite** : le moteur simulé mesure des minutes de jeu, pas un temps de travail humain ni le temps de calcul réel
  (interdit de décider par un temps mesuré, CLAUDE.md §6). La mesure au moteur simulé ne sert donc qu'à comparer deux
  réglages entre eux, par le nombre de parties et de minutes jouées.

## Décision proposée
Ne pas créer de tâche de code pour D05. Retenir le principe dans la méthode : chaque réglage vidéo se teste en A/B
(C25, `tests/video_ab_test.lua`) avant toute mise en série. Le gain de temps vient de la comparaison, pas d'une mesure.
