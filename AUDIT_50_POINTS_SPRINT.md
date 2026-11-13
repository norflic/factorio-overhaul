# Audit 50 points — sprint 40 min (13/11, base v0.7.94)

Chaque point est un constat lu dans le code par l'agent de l'axe ; aucun n'a été mesuré en jeu.

## champ

# Audit s40 — champ (AXE 1, extraction)

1. Bande écartée une fois = écartée pour toujours, puis champ déclaré « posé »
script/team/migration_champ.lua:869-874 (et 1771-1774, 850-866) — un refus de Champ.band (« bande vide », place de fonderie prise à cet instant) met la bande dans st.bad sans plafond ni date ; l'ordre épuisé, Th.order_end rend « fini/partiel » dès qu'une bande a produit : les bandes écartées ne sont jamais relues.
Correctif : à l'ordre épuisé, si st.bad porte des bandes et qu'une bande a produit depuis le dernier tour, st.bad est vidé et l'ordre rejoué après CFG.revive (un tour sans nouvelle bande = fin comme avant). Effet attendu : un gisement ne s'arrête plus à une ou deux bandes parce que les autres ont été refusées une fois.

2. Trois refus du plan ferment un champ qui porte déjà des bandes
script/team/migration_champ.lua:723-729 — failed() : à CFG.max_fails (3) refus de suite, finish(« partiel ») si st.done > 0 (start_next:1631 ne le reprend plus jamais, seul Mig.want le rouvre), ou « abandon » puis new_state() (cadre refait sur un champ qui porte des bandes) si st.done == 0 et st.produced > 0 ; pourtant chaque bande refusée est déjà écartée (st.bad) et d'autres bandes de st.order restent.
Correctif : avec un cadre, un refus du plan dont la bande vient d'entrer dans st.bad (sous CFG.max_bad) et un champ qui a déjà migré ou produit ne ferme pas le champ : la bande suivante part (borne : max_bad, puis la fin d'ordre du point 1). Effet attendu : les bandes restantes sont essayées.

3. f.swap.retry jamais purgé
script/team/foreuse_swap.lua:288, 296, 332, 697, 769, 1032 — une entrée par position de foreuse, écrite à chaque échec, lue ligne 170, jamais retirée (global grossit toute la partie, sauvegarde comprise).
Correctif : au départ de chaque passe (Swap.think), les entrées échues sont retirées (clés triées). Effet attendu : table bornée, décisions identiques.

4. Champ.report relit trois fois chaque entité au moteur
script/team/champ.lua:1092-1097, 1124, 1152 — surface.find_entity par entité dans trois boucles par projet (état, voie de charbon, sans courant), pour tous les projets du champ, toutes les 5 min.
Correctif : une seule recherche par entité et par relevé (table locale), mêmes lignes de journal. Effet attendu : pic de la pensée du relevé réduit sur les grands champs.

5. Réseau du charbon demandé avant que la bande soit acceptée
script/team/migration_champ.lua:910 puis 914-919 — coal_projects() demande le projet du réseau avant Build.request de la bande ; si celle-ci échoue (retour ligne 918), le projet du charbon reste au plan sans bande (links_step ne lit que les projets liés, cs.link).
Correctif : annuler (Build.cancel) les projets du charbon demandés à cet appel quand la demande de la bande échoue. Effet attendu : plus de voie de charbon bâtie pour une bande absente.

## fonderie

# Audit s40 fonderie (AXE 1, points 6-10) — base v0.7.94

6. Rangée du mall figée après une section refusée
script/team/mall_rangee.lua:864-866 (et 782-784) — `last = r.projects[#r.projects]` prend la section MORTE (q.dead reste dans r.projects, jamais retirée) : `p.state == "fini"` est faux pour toujours, l'allongement à la demande (étape 2) et la liquidation du stock dormant ne repartent plus ; l'étape 2 ignore aussi `r.retry_at` posé ligne 850.
Lire la dernière section VIVANTE (Mr.derniere, pur) aux deux endroits et respecter retry_at à l'étape 2 : une rangée dont un raccord a été refusé une fois se rallonge de nouveau.

7. Découverte du piquage affamée par les quais de tête
script/team/piquage.lua:590-600 — au plus 3 découvertes par relevé, servies dans l'ordre du débit ; les quais de tête sans tapis redeviennent dus toutes les 3 min (EMPTY_RETRY), soit 18 créneaux par 3 min : un quai au-delà n'est jamais découvert ; et un quai dû mais hors quota n'est ni découvert ni relevé (le `else observe_tracks` est sauté).
Servir les 3 quais dus les plus anciens (st.disc croissant, puis ordre du débit) et relever les autres : chaque quai finit par être examiné, les relevés ne sautent plus.

8. Tables du piquage jamais purgées
script/team/piquage.lua:674-680 — seuls st.seen et st.quais sont purgés ; st.track (12 tuiles + observations), st.disc, st.tries, st.last_try, st.said, st.site_i (par quai) et st.flow (par projet) gardent à vie les quais et projets disparus (global qui grossit, sauvegarde et désync plus lourds).
Purger ces tables en fin de relevé pour les quais absents sans lien et les projets absents du plan.

9. Découverte : trois balayages de tout le plan par quai
script/team/piquage.lua:257-286 — opt_in et plan_ok reparcourent toutes les pièces de tous les projets finis à CHAQUE découverte (jusqu'à 3 par relevé), alors que seul le filtre `q.id ~= d.pid` dépend du quai.
Construire une fois par relevé (dans c, table du cycle hors décision) la carte tuile -> projet et opt_in ; pointe de calcul divisée par le nombre de découvertes.

10. Branche « coupée » jamais rétablie quand le répartiteur existe
script/team/piquage.lua:497-501 et 515-522 — après SPLIT_TRIES refus, link.cut = true ; si le répartiteur est ensuite trouvé (`have`), link.split passe à vrai mais link.cut reste : `if link.split and not link.cut` est faux pour toujours, le quai reste au verdict « coupe » et le PNJ continue les tournées à la main.
Lever link.cut (et split_tries) quand le répartiteur est constaté en place : le verdict repasse à actif/inerte selon la livraison.

## decision

# Audit decision (axe 2, points 11-15)

1. Stock virtuel rendu deux fois par les fabrications « extraction de la plaque clé » de la pile
shared/ai3/cerveau.lua:391-406 — chaque fabrication it[4] repart d'une copie NEUVE du coffre (`pre`) et réécrit `saved[k] = pre0[k] - paid - used[k]` : ce qu'une fabrication précédente de la boucle (clé ou non) a déjà pris sur le stock libre est RENDU, deux fabrications clés paient la même matière.
Stock brut courant partagé par la boucle, paiement cumulé, et `saved[k]` ne peut que baisser (min) : plus de fabrications émises que le coffre ne peut payer (tâches prises puis en attente de matière).

2. Plafond de fabrications atteint : jusqu'à 10 plans du livre perdus par besoin
shared/ai3/projets.lua:302-303 et 263-267 — P.want appelle craftable_count (1 à 9 book:plan) puis craft() calcule p0 avant de lire `room` ; à E.crafts = P.MAX_CRAFTS le résultat est toujours « 0 fabriqué », pour chaque objet de chaque projet suivant, à chaque pensée.
Sortie avant tout plan quand il n'y a plus de place (même résultat, mêmes manques) : pensée plus courte quand la file de fabrications est pleine.

3. craft() refait le même plan du livre quand la commande tient en un morceau
shared/ai3/projets.lua:263 et 274 — p0 = plan({item, n}) sert seulement à l'énergie ; avec chunks = 1 le premier tour de boucle refait plan({item, n}) sur le même E.avail (résultat identique).
Réutiliser p0 quand chunks = 1 : un plan de moins par fabrication courte (le cas courant), à chaque pensée.

4. Recherche : temps de laboratoire crédité pendant un refus d'add_research
script/ai3/cerveau.lua:616-620 — `return info` sur add_research refusé sort AVANT `lab.last = tick` : à la reprise, dt couvre toute la durée du refus et les unités (et leurs packs) sont payées d'un coup comme si les laboratoires avaient tourné.
Dater lab.last avant la sortie : l'avancement ne compte que le temps où la recherche était lancée.

5. Gisements à portée : carte de connaissance lue deux fois par ressource
script/ai3/cerveau.lua:757 et 765 — Ia3.known_deposits(f, res, tick) est appelé une fois pour `known`, puis rappelé dans la boucle des rayons (même f, res, tick) dès r > REACH_SEEN.
Réutiliser le premier résultat (`kd`) : une lecture de la carte par ressource au lieu de deux à chaque relecture des gisements.

## reinvest

# Audit s40 reinvest (AXE 2, points 16-20)

16. kW retenus par la répartition jamais comptés pour la centrale
shared/ai3/capitalisation.lua:2608-2641 (Ca.share_kw) — une option ramenée à sa part (a < o.n) ou refusée par la répartition n'ajoute rien à ctx.power_block ; Ca.blocked_kw (l.2511) ne lit que power_block, donc cs.kw_blocked (script l.2177) sous-compte ce que la centrale doit porter.
Correctif : share_kw inscrit (o.n - a) * kw_unit dans ctx.power_block pour chaque option rognée ou refusée ; la centrale (S.capi_kw) voit tout le courant retenu.

17. Courant « pris » lu sur la puissance MESURÉE : les machines à l'arrêt comptent 0 kW
script/ai3/capitalisation.lua:966-976 (Capi.power_input) — used_kw = g.power mesuré + chantiers ; des fours posés mais sans minerai ne pèsent rien, la règle revend ces kW à d'autres machines, la centrale sature quand tout tourne.
Correctif envisagé : plancher sur la somme nominale des machines relevées ; c'est le choix (a) du lead du 7/11 et un changement d'équilibre : NON appliqué sans banc (noté seulement).

18. Pose des modules d'effet : relevé du courant sans wait_plant
script/ai3/capitalisation.lua:2561 — Capi.power_input(f, Auto.plant_state(f)) ne passe pas wait_plant (calculé l.1417 pour la décision) : centrale demandée pas finie avec un module électrique ouvert = « amorce » ici, « fermee » dans la décision.
Correctif : passer le même wait_plant (slots.open > 0) ; les deux relevés disent la même chose.

19. Blocs morts du mall jamais purgés
script/ai3/industrie.lua:471-479 et 580 — un bloc refusé ou perdu (b.dead) reste pour toujours dans st.blocs : Auto.module relu à chaque décision et à chaque Ind.status, liste sauvée qui ne fait que grandir.
Correctif : retirer de st.blocs les blocs morts une fois leur report posé (st.hold) ; même décision, moins de travail par passe.

20. Lignes dites du mall jamais purgées
script/ai3/industrie.lua:516-529 — st.refus[objet] et st.said[label] ne sont jamais vidés quand le refus ou l'attente disparaît : un refus qui revient avec la même cause n'est plus écrit, les tables grandissent avec chaque combinaison de bloc.
Correctif : vider st.refus des objets absents de out.refus à chaque changement de signature ; journal fidèle, table bornée.

## ouvriers

# Audit ouvriers (axe 3, points 21-25) — base v0.7.94

21. Jeton de prise brûlé quand le tableau n'a aucune tâche libre
script/team/worker.lua:1868 — l'état « idle » prend Tokens.COST_CLAIM (20) AVANT Board.claim, même si aucune tâche n'est libre ; la part de l'équipe est entamée (used > 0), et tokens.lua:62 exige `used == 0` pour la grosse opération (plan 200, poteau 300) : un PNJ inactif sans rien à prendre la fait refuser au même tick.
Correctif : Board.any_free(f) (lecture de b.list) ; sans tâche libre, ni jeton ni prise, le retour au QG reste. Effet attendu : moins de pensées sans jeton, la part commune va aux plans et aux poses.

22. Réservation gardée pendant tout le retour d'une tâche abandonnée
script/team/worker.lua:1184 (abort) — abort remplace le programme par `{ home }` (plus aucune étape « take ») mais ne rend pas agent.resa_id ; la matière reste réservée au registre jusqu'à finish (arrivée au QG) : Board.prenable et le tri de claim_market (R.free) refusent les tâches qui la demandent, des PNJ attendent au coffre.
Correctif : Board.release(f, agent) dans abort. Effet attendu : la matière d'une tâche abandonnée est libre tout de suite pour la prise suivante.

23. Tournée de pose close au premier point d'appui qui ne tient pas
shared/team/tournee_pose.lua:83 — `if not j or not fits(...) then break end` : le plus proche qui dépasse les bornes ferme la tournée, alors qu'un autre point d'appui à portée (MAX_HOP) tiendrait ; il part dans une tournée de plus (un aller-retour de plus).
Correctif : le point qui ne tient pas est écarté pour cette tournée, on essaie le suivant le plus proche. Effet attendu : moins de tournées pour les mêmes pièces.

24. Tuile de minage réservée jamais rendue au refus de la porte
script/team/worker.lua:1894 — Worker.program réserve la tuile (claim_tile, l. 878) ; au refus de la porte (danger) la tâche finit sans que le PNJ parte, mais release_tile n'est appelé qu'à la fin d'un minage (l. 2249) : tuile écartée CLAIM_TTL = 9 000 ticks pour rien.
Correctif : release_tile(f, task.target) au refus de la porte. Effet attendu : les mineurs suivants reprennent la tuile la plus proche au lieu de s'éloigner.

25. Tâche d'un PNJ disparu finie sans Poles.task_done
script/team/worker.lua:2478 — Registry.on_removed appelle Board.finish mais pas Poles.task_done (appelé partout ailleurs : finish, sans-programme, refus) : la file sûre (Sur.done) ne compte pas ces fins.
Correctif : Poles.task_done(f, task, false, tick) après Board.finish. Effet attendu : comptes de la file sûre justes après une mort.

## routage

# Audit routage (AXE 3, points 26-30)

26. Départ de tronçon bouché : 8 réparations et 8 bandes interdites avant de défaire le tronçon fautif
shared/team/troncons.lua:395-398 — quand Tv.route rend « depart » (la tuile de pointe, juste après le dernier tronçon posé, est prise par le monde), run_leg interdit la bande de 5 cases de la CIBLE (innocente) et répare ; il faut Tc.TIP_FAILS = 8 échecs pour défaire le tronçon dont la pointe est bouchée.
Correctif : sur « depart » avec au moins un tronçon posé, défaire tout de suite le dernier tronçon sans interdire la bande de la cible ; effet attendu : un tronc de bus dont la pointe est bouchée repart en 1 réparation au lieu de 8, sans couloirs interdits à tort.

27. Validation finale : un tronçon cassé interdit les cases de tous les tronçons suivants
shared/team/troncons.lua:453 et :321 — validate défait le tronçon i et tous les suivants par drop_last_leg, qui interdit la case (leg.cx, leg.cy) de CHACUN ; les suivants sont intacts, et la tuile changée est déjà vue par ctx.cost.
Correctif : drop_last_leg(st, sans_interdit) dans validate ; effet attendu : après un obstacle apparu sous un tronçon fini, le nouveau plan garde le couloir d'origine au lieu de chercher un détour (ou d'échouer) pour des cases libres.

28. Liaison : une géométrie fausse au bout choisi refuse toute la liaison
script/team/liaison.lua:478-482 — Ln.verify et Tv.verify tournent APRÈS la boucle des bouts, sur le seul bout choisi ; un écart rend « geometrie fausse » sans essayer les bouts suivants (alors que pureté et poteaux, eux, passent au bout suivant dans la boucle).
Correctif : faire la preuve géométrique dans la boucle, un échec passe au bout suivant ; effet attendu : la liaison se pose par un autre bout au lieu d'être refusée entière.

29. Détours de gisement cherchés alors qu'aucun chemin de surface n'existe
shared/team/traversee.lua:526-536 — quand la phase A rend « aucun chemin » et que la base vient de la phase B (souterrains), les recherches « O<pen> » (sans souterrain, même graphe que A réduit à l'ellipse) sont lancées pour chaque palier de Tv.ORE_STEPS : elles ne peuvent qu'échouer.
Correctif : sauter la boucle des détours quand la phase A a prouvé « aucun chemin » ; effet attendu : même tracé, jusqu'à #ORE_STEPS recherches A* de moins par tracé qui franchit un mur.

30. BUS_CACHE et p.rs gardés après un refus précoce
script/team/liaison.lua:359-366 et :431 — les retours « coffre disparu », « pieces inconnues », « trop loin » sortent sans vider BUS_CACHE[p.id] (masques de toute la boîte) ni p.rs ; l'entrée n'est vidée qu'en fin de plan (:468).
Correctif : vider p.rs et BUS_CACHE[p.id] sur ces retours ; effet attendu : plus de masques retenus pour un projet refusé, pas d'état de reprise périmé.

## defense

# Audit defense (axe 4, points 31-35)

1. Défenseurs d'un site lointain rappelés par le chef
script/ai3/soldats.lua:713 — `far_role` ne compte que escort, clear et guard ; un soldat en « defense » ou « hunt » envoyé par une alerte de site (admise à toute distance, l.104-106) a `ia3k = nil`, et military.lua:512 rappelle tout soldat sans `ia3k` au-delà de 160 tuiles.
Drapeau posé aussi pour defense et hunt au-delà de Sd.NEAR_HQ (règle pure Re.far_role) : les soldats envoyés à un avant-poste attaqué n'en sont plus retirés par le rappel.

2. Ordre de défense réémis à chaque passage
shared/ai3/soldats.lua:186 + script/ai3/soldats.lua:446,704 — la clé d'ordre contient floor(x):floor(y) de la menace ; la menace du QG est une unité qui bouge, donc la clé change à chaque passage et `set_command` repart (attaque de zone relancée, chemin recalculé) pour tous les soldats.
Cible de défense gardée tant que la nouvelle reste dans la zone d'attaque déjà ordonnée (règle pure Re.same_area) : plus de commande refaite tant que l'ennemi est dans les 24 tuiles déjà visées.

3. Alerte de site absorbée par une alerte de chasse
script/ai3/soldats.lua:111-118 et 469 — une alerte « site » fusionnée dans une alerte « hunt » existante (à 24 tuiles) garde `role = "hunt"` et `n = 3` ; la branche `a.site and not a.role` ne la prend donc jamais : bâtiment attaqué traité comme un adversaire isolé.
À la fusion en mode site : `a.role = nil`, `a.n = 4` ; le site attaqué passe par Da.site_plan comme les autres.

4. Mise à l'abri de l'équipe du joueur faite deux fois
script/ai3/soldats.lua:810-816 et 819-834 — le gestionnaire de 30 ticks appelle déjà hq_threat (donc shelter) pour l'équipe sans soldats ; celui de 120 ticks refait la recherche d'ennemi et un second shelter sans réponse (« stand ») au même tick, compteurs (spared, shelter) doublés.
Gestionnaire de 120 ticks réduit au cas que l'autre ne couvre pas (aucun) : supprimé ; une recherche et un parcours des PNJ en moins toutes les 120 ticks.

5. Clés des avant-postes retriées pour chaque menace
script/ai3/soldats.lua:505-511 et 656 — `State.sorted_keys(f.outposts)` est recalculé dans la boucle des menaces (une fois par menace hors portée du QG) puis encore pour les avant-postes marqués, à chaque passage.
Liste triée une fois par passage et réutilisée : coût du passage sans dépendance au nombre de menaces × avant-postes.

## resilience

# Audit resilience (axe 4, points 36-40)

1. Poteaux perdus jamais rouverts après 5 réouvertures
script/team/reseau_vivant.lua:327 et :470 — `q.poles_reopened` n'est qu'incrémenté (aucune remise à zéro dans script/, shared/) : au 5e incident de la partie, `lost_poles` (et raccord.lua:205) ignore le projet pour toujours.
Remise à zéro du compteur quand un relevé du réseau lit 0 îlot et 0 consommateur sans poteau (réseau rétabli) : le plafond borne un incident, plus la partie entière.

2. Une pièce abîmée sous le feu bloque toutes les réparations
script/team/reconstruction.lua:769 — `repair_think` ne teste que `batch[1]` (la plus abîmée de toute la carte) ; ennemi à côté : `return 0`, et le relevé suivant retombe sur la même pièce. Rien d'autre n'est réparé tant qu'elle reste sous le feu.
Le lot sous le feu est écarté des candidats et le lot suivant est essayé (3 essais au plus par relevé) : les pièces abîmées ailleurs sont réparées.

3. Pièces d'une tâche « rebuild » ouverte reprises à chaque pensée
script/team/reconstruction.lua:440-498 — une pièce n'est « prise » qu'à Recon.program (ouvrier parti) ; tant que la tâche attend, ses pièces restent dans `due`, consomment les places `SEEDS_PER_THINK` (Board.add refuse la clé déjà ouverte) et peuvent entrer dans le lot d'une AUTRE graine (deux ouvriers pour la même pièce).
Les `recs` des tâches « rebuild » ouvertes sont marqués pris avant la boucle des graines : les places essayées vont aux pièces sans tâche.

4. Hygiène : poteau de remplacement détruit sans retour au coffre
script/team/hygiene.lua:431 et :439-441 — sur « coffre plein » (Stock.insert < 1), la branche d'échec détruit le remplaçant puis refait le même Stock.insert, qui échoue encore : un poteau perdu à chaque essai.
Le remplaçant n'est détruit que si son objet rentre au coffre ; sinon il reste posé (aucune matière perdue).

5. Adopte : machine adoptée ramassée jamais retirée de `st.units`
script/team/adopte.lua:389-394 — `on_mined` ne traite que les foreuses ; une machine adoptée (four, assembleur, labo) ramassée garde son numéro dans `st.units` et son entrée (invalide) dans la liste d'équipe.
`on_mined` retire le numéro de `st.units` et l'entité de la liste : table purgée, plus d'entrée morte dans les registres.

## ups-team

# Audit ups-team (axe 5, points 41-45)

41. Fours de l'équipe revalidés deux fois par pensée
script/team/team.lua:823 et 825 — Team.view appelle Outposts.smelters(f) deux fois de suite ; chaque appel refait valid_list (une table neuve et un .valid par four).
Un seul appel, résultat partagé par `smelters` et `smelter_coal` ; même vue, une revalidation de moins par pensée et par équipe.

42. Tri des tourelles pour un simple compte
script/team/team.lua:634 — State.sorted_keys(f.turrets) (table neuve + tri) à chaque pensée, alors que la boucle ne fait que compter les tourelles valides (résultat indépendant de l'ordre).
Compte direct sans liste ni tri ; n_turrets identique.

43. Tri des PNJ pour un simple compte (quartiers)
script/team/quartiers.lua:58 — idle_count trie f.engineers (State.sorted_keys) pour compter les PNJ sans tâche ; le compte ne dépend pas de l'ordre.
Compte direct sans liste ni tri ; s.idle identique.

44. Seuil de tourelles recalculé trois fois par avant-poste
script/team/team.lua:569, 703, 712 — T.defend_turrets(o.drills) est calculé à la construction de la vue, puis encore dans grow_due et dans les besoins de FerEquipe, pour les mêmes foreuses.
Valeur gardée dans une liste locale parallèle (la vue publiée ne change pas) ; mêmes décisions.

45. Prototype relu à chaque lecture par nom du registre
script/team/registre_types.lua:255 — Rt.named relit game.entity_prototypes[name].type (accès moteur) à chaque appel (script/team/electrique.lua:84 et 256, à chaque pensée).
Type gardé dans une table du module (jamais dans global, vidée à on_configuration_changed) ; même liste rendue.

## ups-ai3

# Audit ups-ai3 (axe 5, points 46-50)

46. Frontière triée deux fois et recalculée à chaque essai de cible
shared/ai3/carte.lua:405-424 et script/ai3/exploration.lua:609-614 — K.frontier trie TOUTES les clés de m.s (sorted_keys) alors que sa sortie est retriée (table.sort(out)) ; retarget appelle K.best_target jusqu'à 4 fois de suite, donc 4 frontières complètes sur la même carte inchangée.
Parcours sans tri préalable (sortie identique, triée) + frontière calculée une fois par retarget (ctx.frontier) : coût d'un choix de cible divisé, même cible.

47. Exclusion coûteuse évaluée avant le filtre de distance
shared/ai3/carte.lua:465-468 et script/ai3/exploration.lua:552-570 — best_target lit ctx.exclude[k] (métatable : blocked_near + enemies_near + boucle des autres éclaireurs) pour chaque secteur de frontière AVANT le test dh <= maxd ; la fermeture rappelle block_params(k) et K.center(K.xy(key)) deux fois par clé.
Test de distance d'abord (exclusion pure, résultat identique), block_params et centre calculés une fois : moins de travail par secteur hors de portée.

48. Listes triées des avant-postes refaites à chaque passe de l'œil
script/ai3/exploration.lua:933-950 (measure) et 915-930 (audit) — chaque passe EYE (brouillard coupé compris, ligne 1104) alloue et trie deux fois les clés de f.outposts ; measure ne fait qu'un comptage par type (indépendant de l'ordre), audit ne cherche que les identifiants non encore audités.
Comptage direct sans tri dans measure ; audit ne trie que les identifiants nouveaux : mêmes valeurs, mêmes lignes, moins d'allocations par passe.

49. k.audit.outposts jamais purgée
script/ai3/exploration.lua:917-918 — chaque avant-poste audité laisse une entrée à vie dans global alors que f.outposts[oid] est effacé ailleurs (script/faction/outposts.lua:1513, script/team/adopte.lua:284, script/team/ruines.lua:185).
Purge des identifiants disparus de f.outposts pendant l'audit : table bornée par les avant-postes vivants, sauvegarde plus légère.

50. Journal « toute la frontiere est en region bloquee » faux après un rejet scout_ok
script/ai3/exploration.lua:609-625 — la boucle écarte (rawset) jusqu'à 3 cibles NON bloquées refusées par K.scout_ok ; si l'essai suivant rend une cible douce, la ligne [FO-IA3F] et k.stats.soft annoncent que toute la frontière est bloquée, ce qui est faux.
La ligne dit le nombre de cibles libres écartées pour trajet près d'un nid, et le compteur « soft » ne compte que le vrai cas : diagnostic exact, aucune décision changée.
