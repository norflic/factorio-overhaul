# Critères de la reconnaissance régulière, essai 2 (lot VEILLE, branche `recon-veille`)

Écrits AVANT toute mesure (29/10). Essai 1 (`recon-eclaireurs`, parqué) : un vivier de soldats réservé coûtait environ 500 plaques de fer
pour 10 éclaireurs (31 plaques par départ), soit 7,4 tourelles de moins et 6,9 soldats de moins en moyenne sur 8 factions, pour 0,33 départ
par faction et par 10 min. Les ouvriers des factions explorent déjà (153 missions dans les 4 bases MESURES, 0 perdu). L'essai 2 n'envoie
donc AUCUN soldat : un OUVRIER LIBRE part à intervalle, sans kit, par la voie d'exploration d'IA3-f. La visée des attaques est celle de main.

## Règle (shared/faction/veille.lua, pure ; mission dans script/ai3/exploration.lua)
- Premier départ à 15 min au plus tôt (la mise en place de la base d'abord). Un départ par intervalle : 10 min ÷ curiosité (500 à 2 000 pour mille), allongé de (1 000 + 2 × menace) ÷ 1 000.
- Rayon croissant : R = 300 tuiles + 150 par mission arrivée, 1 600 au plus ; but = secteur GÉNÉRÉ de la bande R ± 96 tuiles du QG, jamais vu
  ou vu depuis plus de 20 min, le plus ancien d'abord, octants alternés, trajet dégagé de tout nid ou ver vu.
- Pas de départ : exploration d'une ressource demandée (elle a priorité), tour de fondation non fini, survie, alerte du QG, menace > 100,
  tâche libre PRENABLE au tableau (matière stricte libre au registre : un ouvrier utile ne part pas), moins de 2 PNJ libres (3 quand une matière manque : une crise garde ses ouvriers),
  délai non écoulé. Factions seulement (jamais votre équipe).
- La mission est celle d'exploration existante : l'ouvrier fuit à la vue d'un ennemi, rentre au bout de 10 min, écarte les chemins ratés.

## Critères de mesure (4 graines 20261020, 123456789, 271828182, 1618033988 ; lot contre TÉMOIN = même source, veille éteinte, scénario
## `veille-temoin` ; base-<graine> de MESURES en référence)
1. Départs : au moins 0,5 par faction et par 10 min, mesuré sur les périodes où la faction avait un PNJ libre et aucune autre exploration.
2. Pertes : au plus 30 % des départs finis « perdu ».
3. Secteurs reconnus (bilans `[FO-VEILLE]` de 10 min) à 20, 40 et 60 min : au moins ceux du témoin sur 3 graines au moins (somme des deux
   factions à 60 min), et en hausse sur au moins 2.
4. Défense : aucun écart de plus de 2 soldats ou 1 tourelle contre le témoin, à 12, 40 et 60 min, dans 7 cas sur 8 (faction par graine) ;
   aucun PNJ de votre équipe en moins ; aucune attaque de plus vers le joueur.
5. Coût en fer par éclaireur : au plus 5 plaques-équivalent d'armée perdue par départ (pertes × 50 plaques ÷ départs ; un ouvrier perdu
   coûte son kit, un soldat rien de plus qu'avant).
6. Coût en travail : minutes d'ouvrier absent (somme des durées de mission de veille) rapportées par faction et par heure, avec le nombre de
   PNJ libres moyen ; non bloquant, mais un ouvrier jamais retiré pendant une tâche libre au tableau (contrôlé au code et par test).
7. La visée ne change pas : aucun fichier de visée touché (diff) ; lignes `[FO-STRAT] attaque` identiques avant la première mission de veille.

Verdict par graine : tenu / non tenu pour chaque critère, avec la cause quand une graine dégrade ; pas de fusion si une graine dégrade
sans cause établie (règle du DC).

## Tolérances ajoutées le 29/10 AVANT la lecture des parties de l'essai 2 (décision du lead : un seuil se déclare avant, il ne se règle pas après)
- Secteurs reconnus (critère 3) : une graine compte « au moins le témoin » si la SOMME des deux factions à 60 min est d'au moins 95 % de celle
  du témoin (bruit de trajectoire : un secteur de plus ou de moins vu par hasard), et « en hausse » si elle dépasse 110 %. Les relevés à 20 et
  40 min sont rapportés, jamais bloquants. Une faction à 0 mission de veille est rapportée mais comptée dans la somme.
- Minutes d'ouvrier absent (critère 6) : tenu si la somme des durées de mission de veille ne dépasse pas 15 min par faction et par heure
  (environ 3 % du temps de travail d'une équipe de 8 PNJ). Au-delà : NON TENU pour le travail, bloquant seulement si la défense ou les PNJ de
  l'équipe sont aussi en baisse (alors la cause est l'absence des ouvriers).
- Étiquetage des causes (rapporté, non bloquant) : part des missions finies en « fini » (but vu), « fuite » (ennemi à 64 tuiles), « perdu »,
  « chemin », « rien », « duree » ; pour chaque écart de défense, cause étiquetée mesuré / déduit / supposé.
- Le test `war_test` « scarlet : avant-poste de pierre reconstruit » (104 OK sur 105) est consigné tel quel : passe veille éteinte (105), passe
  avec un premier départ à 12 ou 17 min (105) ; sensibilité de trajectoire, non corrigée par une constante.
