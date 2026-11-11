# Audit V2 : incohérences décisionnelles (v0.7.4, 11/11/2026, 17 h 15)

**22 points prouvés, pas 50.** L'audit statique a tenu 21 points dans le temps imparti (familles : flux 1, placement 4, stockage 5, militaire 8, tâches 3) ; le n° 22 vient de l'agent P0-POTEAUX (maillon suspecté, non prouvé). Aucun ne reprend `AUDIT_50_ANGLES_MORTS.md` ni les faits F488-F557. Aucun n'est corrigé en 0.7.5 (seuls P0-centrale et l'élagage le sont).

Format : n°. famille | fichier:ligne | incohérence | impact | correction minimale | criticité 1-5

1. Flux | script/faction/outposts.lua:1441 | refill_group recalcule turret_groups pour un seul groupe (et group_pos l.1479) | coût O(tourelles) par tournée | passer le groupe déjà calculé | 2
2. Placement | script/ai3/capital.lua:56 / capitalisation.lua:118 | « au QG » = 64 tuiles d'un côté, 40 de l'autre | machines entre 40 et 64 tuiles classées des deux façons | une constante partagée | 3
3. Placement | capitalisation.lua:117 / shared/ai3/base.lua:39 | relevé de base 160 contre 320 tuiles | gisements entre 160 et 320 invisibles à la capitalisation | une seule valeur | 2
4. Placement | script/ai3/petrole.lua:78,85,791 | CLAIM_R 48 < FIELD_R 96 | deux équipes sur le même champ de pétrole | CLAIM_R >= FIELD_R | 3
5. Placement | script/ai3/prevision.lua:45,52,317 | champ fusionné à 40 tuiles d'un site qui ne relève qu'à 20-48 | champ absent de la prévision de menace | FIELD_SEP <= SITE_R | 4
6. Stockage | shared/team/ravitaillement.lua:70-72 | tournée futile seulement si rien posé | tournées en boucle pour 1 charbon | seuil en fraction du manque | 3
7. Stockage | shared/team/ravitaillement.lua:52-57 | brûleur injoignable classé « autre » | cause jamais traitée | verdict « non posé, porté suffisant » | 2
8. Stockage | script/faction/outposts.lua:1496-1503 | réceptacles rendus orphelins alors que l'avant-poste est gardé pour reconstruction | démontés avant la reconstruction | pas d'orphelin si keep | 3
9. Stockage | script/team/ruines.lua:190-192 | orphelins datés tick 0 | repris ou démontés en premier | game.tick | 2
10. Stockage | script/faction/outposts.lua:1455-1458 | tourelle avec une munition hors échelle jamais complétée | tourelle à moitié vide | vider puis recharger | 3
11. Militaire | outposts.lua:1381,1462-1468 | ravitaillement de toutes les tourelles du groupe sans distance | stock consommé sans trajet, exposition masquée | seulement à portée | 4
12. Militaire | prevision.lua:45 / outposts.lua:1375-1377 | tourelle comptée à 24 tuiles en prévision, par propriété au ravitaillement | ligne isolée comptée 0 en défense | compter par propriétaire | 4
13. Militaire | prevision.lua:50,296 | 8 avant-postes examinés au plus | avant-postes isolés sans estimation de menace | trier par risque avant de couper | 4
14. Militaire | prevision.lua:434-437 | tourelle électrique sans courant comptée pleine | base jugée défendue sans courant | test de courant de turret_works | 4
15. Militaire | prevision.lua:436 / comportement.lua:310-312 | « armée » = N chargeurs ici, 1 munition là | ralliement derrière des tourelles jugées vides | un seuil partagé | 3
16. Militaire | comportement.lua:333-334 / soldats.lua:327 | tourelles à 40 tuiles de home_spot, menace à 48 de hq_pos | anneau 40-48 incohérent | même centre et rayon | 3
17. Militaire | prevision.lua:47,49 | pertes à 64 tuiles, contact à 48 | menace gonflée par des pertes en route | LOSS_R = CONTACT_R | 2
18. Militaire | capitalisation.lua:702-705 | danger d'un gisement : n'importe quelle entité « enemy » à 40 tuiles ; factions rivales ignorées | gisements faussement dangereux ou sûrs | nids et tourelles hostiles pondérés | 3
19. Tâches | script/team/worker.lua:1137-1143 | release_stuck abandonne la tâche sans déplacer le PNJ | le PNJ se recoince | téléporter dès le 1er appel | 4
20. Tâches | worker.lua:1148-1157 | sans place libre, la tâche est finie et le PNJ reste coincé | PNJ bloqué pour toujours | élargir, sinon case du QG | 4
21. Tâches | script/faction/sites.lua:643-644,233-236,1072 / military.lua:312-313 | front_dry, unreachable_targets, site_fail jamais purgés ; un échec bloque toutes les attaques | tables qui gonflent, attaques gelées | purger les échéances, bloquer la seule cible | 3
22. Flux | script/ai3/industrie.lua:320 (suspect, non prouvé) | coffre du joueur à 0 poteau moyen, 92 attendus par 8 projets ; le bloc du mall des poteaux refusé « manque iron-plate 59/86 » alors que 6 085 plaques dorment dans les coffres de sortie des champs | 84 foreuses de bande sans courant (partie du DC 0.7.3, minute 61) | compter les plaques des sorties de champ dans le stock libre (à prouver) | 5
