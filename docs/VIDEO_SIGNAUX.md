# Signaux de défaut et leviers (lot VIDEO-TRACES, parties f et g)

Document de référence pour la vidéo : quand une équipe de PNJ (factions et votre équipe) tombe en panne, quel signal la
détecte et quel levier la boucle actionne. Tout ce qui suit est LU DANS LE CODE de la révision `video-traces` (base
45481fb4). Aucune mesure en moteur réel n'est apportée ici : les seuils sont ceux du code, cités tels quels.

Chemins : `shared/` = règles pures (testables hors jeu), `script/` = runtime (appels au moteur). Les numéros de ligne
renvoient à la révision de la base ; ils bougeront si ces fichiers sont modifiés.

---

## Partie f. Table « défaut → signal → levier »

| # | Défaut (ce qui se passe en partie) | Signal (qui le voit, à quel seuil) | Levier (ce que la boucle fait) | Journal |
|---|---|---|---|---|
| 1 | **Famine** : une matière clé manque longtemps et les PNJ restent au coffre, la porte refuse leurs trajets. | Entrée en mode survie : manque continu d'une matière clé pendant `Sv.SHORT_TICKS` (5 min, `shared/team/survie.lua:40`) ET paralysie : `Sv.PARA_WAITS` (6) refus de la porte sur `Sv.WINDOW` (5 min), avec `Sv.IDLE_PCT` (34 %) de PNJ sans tâche (`survie.lua:42-43`, `Sv.paralysed` :131-137, décision `Sv.decide` :147-167). Le manque vient de `Sv.shortages` (:99). Appelé par `script/team/survie.lua:125`. | Dans le mode survie, un but marqué seulement par des cases mobiles n'est plus une raison de rester : `Fa.goal` (`shared/team/famine.lua:55-68`) puis `Fa.decide` (:72-76) : attente jusqu'à `Fa.W` refus, puis escorte si 2 soldats libres, sinon départ seul. Appelé par `script/ai3/comportement.lua:997` et `:1040`. Le regard efface les cases mobiles vides (`Fa.clear`, :79, appelé `comportement.lua:1496`). | `[FO-FAMINE]` (`Fa.line` :82, `Fa.keep_line` :92) ; `[FO-SURVIE]` (entrée et sortie) |
| 2 | **Projet qui n'avance plus** : une équipe reste sur un chantier, un raccordement ou un plan sans progrès. | Signature de progrès = nombre d'entités bâties (`count_built`). Sans changement pendant `Bl.STALL_TICKS` (36 000 ticks = 10 min, `shared/team/blocage.lua:24`), `Bl.stall` (:80-92) rend la cause une seule fois par projet. Horloge tous les 600 ticks (`script/team/build.lua:4398-4414`). | Aucun levier général : la cause est seulement écrite. Le levier existe pour le cas le plus fréquent, une tourelle qui bloque un fantôme : `Bl.own_blockers` (:57, appelé `build.lua:3294` et `:4369-4371`) enlève ses propres tourelles ; `Bl.spots` (:28) puis `Bl.first_free` (:40) choisissent une autre place (`outposts.lua:670-671`, `build.lua:3301-3302`). | `[FO-BLOQUE]` (`build.lua:4418`), cause par `Bl.cause` (:66-74) |
| 3 | **Centrale détruite ou à sec** : des pièces de la centrale sont perdues, ou la production est nulle alors que la demande existe. | Entrées de `S.decide` (`shared/team/reseau_sante.lua:52-89`) : pièces manquantes (sources, machines, pompes, tuyaux), production lue (kW) contre demande, sources à sec, îlots de consommateurs, ennemis à portée du site. Seuils : `S.CONFIRM` = 2 relevés pour une production nulle (:29), `S.DANGER_SEEN` = 4 (:31), `S.MAX_TRIES` = 2 (:32), `S.SITE_LOSSES` = 2 (:33). Appelé par `script/team/reseau_vivant.lua:512`. | Une action par décision : `reposer` (pièces perdues, site sûr, :73) ; `autre_site` (site dangereux, :67, compteurs remis à zéro dans `S.applied` :110-117) ; `relier` (poteaux perdus, :81 et :86) ; `combustible` (sources à sec, :80) ; `attendre` (ennemis à portée, :72). La centrale de remplacement est suivie par `S.reloc_verdict` (:97-107, appelé `reseau_vivant.lua:453`). | `[FO-RESEAU]` (`script/team/reseau_vivant.lua:346`) |
| 4 | **Équipe qui défend mal ou qui se sacrifie à la défense** : effectif sous son plancher, QG menacé, postes de défense sous leur minimum. | Signaux de `Pi.signals` (`shared/ai3/pile.lua:425-463`) : `survive = "effectif"` si les PNJ sont sous le plancher et qu'une recrue est possible (:433), `survive = "qg"` si le QG est menacé (:434). Les cadres de la pile (rangs R0 à R3, `pile.lua:12-20`) s'ouvrent sur l'événement qui crée le signal : pièce détruite, poste sous son minimum, manque présent. Appelé par `shared/ai3/cerveau.lua:237` (`Pi.update`, :109). | Le sommet de la pile suspend les familles de rang supérieur : `Pi.allows` (:298-304) et `Pi.porte` (:338-345), rangs dans `Pi.FAMILY_RANK` (:50-54). Une matière en manque garde passage pour l'investissement de production (`Pi.INVEST_FAMILIES`, :331). Une menace ne coupe pas l'amélioration si la pile est complète ou bloquée (`Pi.threat_open`, :311-313). Appelé par `cerveau.lua:312`. | `[FO-PILE]` (`script/team/pile.lua:196`, toutes les `Pi.LOG_EVERY` = 5 min, `pile.lua:62`) ; refus `pile.lua:138` |
| 5 | **Défaut de ressources sans signal de famine** : la porte refuse, mais la paralysie n'est pas assez forte pour entrer en survie. | `Sv.paralysed` ne retient que la porte (:134) ou la menace (:135). Si la pile voit une matière en manque (`short`), elle la passe devant la défense : `Pi.porte` accepte l'investissement d'une matière qui manque (`pile.lua:343`, `script/team/pile.lua:115`). | Le même levier que la ligne 4 : la pile ouvre la production avant l'amélioration. | `[FO-PILE]` |

### Ce que la table ne couvre pas (écarts relevés au code)

- **Projet bloqué : signal sans levier général.** `Bl.stall` ne fait qu'écrire la cause (ligne 2). Le levier n'existe que
  pour la tourelle qui bloque un fantôme.
- **Production nulle sans cause lue.** `S.decide` rend `attendre` (`reseau_sante.lua:82`) : aucun levier, le diagnostic est
  incomplet.
- **Famine sans sortie garantie.** La sortie du mode survie demande `Sv.EXIT_TICKS` sans manque (`survie.lua:169`). Un manque
  qui revient au même niveau garde le mode.
- **Entrée commune (non vérifié).** Les lignes 1 et 4 touchent la même matière : la pile peut suspendre une famille que la
  famine rouvre (`Pi.porte` contre `Fa.decide`). Ce lot n'a pas vérifié si une suite de tests couvre les deux ensemble.

---

## Partie g. Paragraphes (sans mesure)

### V89 : performance sous 60 UPS

Le TODO (`docs/TODO_VIDEO.md:155`) demande que la performance tienne « quelques centaines de mégatuiles », puis cède. Ce
lot ne mesure rien : la mesure exige le mode `--seul` (toutes places prises, interdit n° 4 de `CLAUDE.md`) et un banc dédié.
Ce qui est en place dans le code : un profileur (`script/core/profiler.lua`) et des règles de plafonnement déjà posées
(files de pensées, `script/ai3/comportement.lua` avec ses `Events.on_nth_tick`). Le seuil de 60 UPS n'est donc ni vérifié
ni démenti. Une future mesure devra relever les UPS à plusieurs tailles de carte, et la dégradation, pas seulement la
moyenne.

### D02 : kit de départ minimal

Le TODO (`docs/TODO_VIDEO.md:257`) demande une liste minimale d'amorçage : le livre de recettes, un fût d'huile lourde et
un robot logistique, pour transplanter la racine. Ce lot n'écrit ni ne teste ce kit : la liste est une question de
conception, à trancher avec le Directeur Créatif. Aucun kit n'existe dans ce dépôt sous ce nom.

### D05 : temps de réglage

Le TODO (`docs/TODO_VIDEO.md:260`) constate que le gros du travail est le réglage. Dans ce dépôt, le réglage se vérifie
hors jeu : le moteur simulé (`tests/mock_engine.lua`) et les suites de tests par règle pure permettent de rejouer une
décision sans lancer le jeu. Le temps réel passé à régler n'est pas mesuré ici.

### C25 : résoudre sans casser ce qui marche (A/B octet à octet)

Le TODO (`docs/TODO_VIDEO.md:320`) demande une méthode : comparer l'ancien et le nouveau comportement octet à octet. Le
dépôt la pratique déjà. Exemple : `tests/rang_test.lua` §9 vérifie que le chemin rapide et le chemin complet du rang donnent
le même résultat sur les mêmes données, et `tests/levels_test.lua` contrôle les images de référence contre leurs sources.
La méthode vaut pour une règle pure ; elle ne dit rien d'une branche moteur sans test en moteur réel.
