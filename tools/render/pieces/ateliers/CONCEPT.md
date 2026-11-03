# DA-ATELIERS : concept des 5 bâtiments d'atelier (phase 1, 3/11 vers 23 h)

Brief : `fo-logs/2026-11-04_DA/BRIEF_DA.md`. Worktree `.claude/worktrees/da-ateliers` (branche `design-da-ateliers`, depuis
`main` f8d83417, 0.6.46). Kit de rendu : `tools/render/pieces/ateliers/` (copie des organes et matières du kit `calcul_o`
du worktree `calcul-design`, lecture seule, pour rester cohérent avec la chaîne du calcul sans la copier).

## Données vérifiées dans le code (emprises INCHANGÉES)
| Bâtiment | Prototype | Âge | Emprise (X0, `shared/content/epochs.lua`) | Énergie | Fluide (`prototypes/crafts.lua` `fluid_box`) | Visuel actuel |
|---|---|---|---|---|---|---|
| Concasseur | `fo-crusher` | 2 | 2×2 (l. 730) | COMBUSTION 120 kW (foyer de four en pierre, fumée) | aucun | assembleur 1 ×2/3, teinte (0.78, 0.70, 0.58) |
| Broyeur à mâchoires | `fo-jaw-crusher` | 6 | 3×3 (l. 762) | électrique 500 kW, vitesse 2 | aucun | assembleur 2, teinte (0.70, 0.72, 0.80) |
| Bobineuse | `fo-coil-winder` | 6 | 2×2 (l. 756) | électrique 200 kW | 1 entrée, (−0,5 ; −1,5) : nord de la tuile ouest | assembleur 2 ×2/3, teinte (0.98, 0.80, 0.55) |
| Torchère | `fo-flare-stack` | 4 | 2×2 (l. 738) | électrique 50 kW (allumage) | 1 entrée, (−0,5 ; −1,5) | assembleur 1 ×2/3, teinte (1.00, 0.55, 0.40) |
| Taillerie | `fo-lapidary` | 7 | 3×3 (l. 764) | électrique 400 kW | 1 entrée, (0 ; −2) : nord, au centre | assembleur 2, teinte (0.62, 0.86, 1.00) |

Convention de vue (brief) : UNE vue, façade et sortie au SUD ; un seul design pour tous les âges ; un seul visuel pour
toutes les recettes. Machines à fluide (bobineuse, torchère, taillerie) : la bride du corps est au NORD (direction par
défaut du prototype) ; les trois autres directions passent par `pipe_picture` (4 tronçons rendus dans le style du kit, ou
ceux de l'assembleur 2 vanilla d'aujourd'hui : à trancher en phase 3), comme l'assembleur 2 vanilla.

## 1. Concasseur `fo-crusher` (2×2, âge 2, combustion) : BOCARD à pilons
- Fonction : pierre ou laitier versés dans une trémie tombent dans un mortier de fonte ; trois pilons lourds, levés par
  les cames d'un arbre horizontal puis lâchés, les réduisent en poudre (sable, ciment ; météorites à l'âge 14) ; la poudre
  sort par une grille et une goulotte au SUD. Un petit foyer à charbon et sa machine entraînent l'arbre par un volant.
- Silhouette (1 s) : portique étroit et haut d'où dépassent 3 tiges verticales de pilons ; foyer bas et cheminée.
- 3 éléments : les 3 pilons (tiges, sabots, cames) ; la trémie remplie de pierres au nord-ouest ; le foyer en fonte à
  porte rougeoyante, sa cheminée et le volant à rayons à l'est.
- Mobile et lueur : les 3 pilons montent et tombent en décalé, le volant tourne ; lueur orange de la bouche du foyer
  (visible de jour), la fumée du brûleur (`energy_source.smoke`) recalée sur la cheminée.
- Raccords : aucun fluide ; goulotte et petit tas de sable au sud (sortie lisible), trémie au nord (entrée).

## 2. Broyeur à mâchoires `fo-jaw-crusher` (3×3, âge 6, électrique) : le bloc et ses deux volants
- Fonction : la roche tombe dans une chambre en V entre une mâchoire fixe et une mâchoire mobile ; un arbre excentrique
  porté par DEUX GRANDS VOLANTS fait osciller la mâchoire mobile (bielle) qui écrase la roche contre la fixe ; le gravier
  calibré sort par le bas, sur une goulotte au SUD ; un moteur électrique entraîne un volant par courroies trapézoïdales.
- Silhouette : un caisson d'acier trapu et bas, flanqué à l'est et à l'ouest de deux roues à rayons plus hautes que lui.
- 3 éléments : les 2 volants (rayons, jante épaisse) ; la gueule en V vue de dessus, pleine de roches ; le moteur à
  ailettes et son carter de courroies au nord, sur un socle de béton.
- Mobile et lueur : volants qui tournent, bielle qui monte et descend ; gyrophare ambre et projecteur dirigé dans la
  gueule (lentille chaude), voyants de l'armoire : lueur de jour.
- Raccords : aucun fluide ; goulotte de sortie et tas de gravier au sud, trémie évasée au nord. Successeur du concasseur
  (sa recette le consomme) : même vocabulaire de carrière (fonte, chevrons jaune et noir), en plus lourd.

## 3. Bobineuse `fo-coil-winder` (2×2, âge 6, électrique, entrée de fluide) : le tour à bobiner
- Fonction : le fil de cuivre se dévide d'un touret, traverse un bain d'émail et une tour de cuisson (fil émaillé), puis
  un guide-fil en va-et-vient le range en spires sur un mandrin qui tourne, autour du noyau d'acier magnétique (bobine) ;
  à l'âge 12, ruban supraconducteur refroidi à l'azote liquide (entrée de fluide au nord, givre).
- Silhouette : un tour horizontal portant une GROSSE BOBINE DE CUIVRE, une tour fine à fente orange derrière.
- 3 éléments : la bobine de cuivre brillante sur son mandrin (axe est-ouest, flanc au sud) ; le touret d'alimentation et
  le fil tendu qui descend vers le guide-fil ; la tour de cuisson de l'émail.
- Mobile et lueur : la bobine tourne, le chariot guide-fil va et vient ; lueur orange de la fente de cuisson, voyants.
- Raccords : bride d'entrée au NORD de la tuile ouest (−0,5 ; −1,5), conduite isolée et givrée vers le mandrin ;
  bobines finies posées au sud.

## 4. Torchère `fo-flare-stack` (2×2, âge 4, électrique, entrée de fluide) : la haute cheminée à flamme
- Fonction : le gaz ou le liquide en trop arrive par une conduite, traverse un ballon séparateur (purge des liquides) et
  un pot de garde hydraulique (anti-retour de flamme), puis monte dans une haute cheminée ; au sommet, la tête de
  torchère, ses brûleurs pilotes (allumage électrique) et son pare-vent l'enflamment : flamme libre, aucun produit.
- Silhouette : la plus haute de la famille ; une cheminée fine à bandes rouges et blanches (balisage), haubanée, et une
  flamme au sommet, lisible de très loin.
- 3 éléments : la cheminée balisée et ses haubans ; la tête noircie de suie avec pare-vent et pilotes ; au pied, ballon
  séparateur horizontal, pot de garde, échelle à crinoline et armoire d'allumage.
- Mobile et lueur : la FLAMME, animée (proposition phase 3 : l'animation vanilla `fire-flame` en `draw_as_glow`, posée sur
  la tête, ou une flamme rendue) ; lueur forte de jour, halo au sol la nuit ; voyant d'allumage.
- Raccords : bride d'entrée au NORD de la tuile ouest (−0,5 ; −1,5), conduite jusqu'au ballon.

## 5. Taillerie `fo-lapidary` (3×3, âge 7, électrique, entrée d'eau) : la meule et le cristal
- Fonction : le cristal de résonance brut est bridé dans une tête porte-pièce (quadrant de facettage) au-dessus d'une
  GRANDE MEULE diamantée horizontale qui tourne ; des buses d'eau refroidissent et emportent la poudre (boue) vers un bac
  de décantation ; une scie circulaire refend (plaquettes de silicium à l'âge 10) ; cristal taillé et lentille au sud.
- Silhouette : un établi de fonte lourd portant un grand disque rond et brillant, et un cristal cyan qui luit.
- 3 éléments : la meule (disque à bord diamanté, rayures radiales) ; le bras de facettage qui tient le CRISTAL CYAN ;
  le bac de boue laiteuse et la rampe de buses d'eau.
- Mobile et lueur : la meule tourne, le bras pivote ; lueur cyan du cristal (de jour), lampe de travail.
- Raccords : bride d'eau au NORD au centre (0 ; −2), conduite vers la rampe de buses ; présentoir de cristaux au sud.

## Palette commune (pas d'ère : un seul design)
Acier sombre patiné et fonte des organes du kit `calcul_o` (mêmes matières, mêmes usures) ; accents par fonction :
chevrons jaune et noir d'engin de carrière (concasseur, broyeur) ; cuivre brillant (bobineuse) ; rouge et blanc de balisage
(torchère) ; cyan du cristal et eau laiteuse (taillerie). Lueurs par la couche `glow` (`draw_as_glow`), halo seulement pour
la flamme de la torchère.

## Phase 2 prévue
Trois variantes par bâtiment (A : référence de ce concept ; B : plus chargée ; C : autre parti), rendues à 16 échantillons,
planche `etats-cles.png` (zoom 2, jour) avec, à côté, le sprite actuel (vanilla mis à l'échelle et teinté comme en jeu),
plus la même planche au zoom 1 et de nuit.

## Phase 2 faite (3/11, 23 h) : planches et reproduction
- Planches : `etats-cles.png` (zoom 2, jour), `etats-cles-z1.png` (zoom 1), `etats-cles-nuit.png` (zoom 2, nuit approchée, sans
  halo au sol). Colonne de gauche : visuel ACTUEL en jeu (assembleur vanilla mis à l'échelle et teinté comme `prototypes/crafts.lua`).
- Rendus : `e16b/<variante>/` (post-traités) et `cache_e16b/` ; 16 échantillons débruités (`FO_DENOISE=1`), étalonnage des usines
  validées `FO_GRADE=0.001,1,0.42,1.68,1.15,1.12` ; passe 1 sans débruitage ni étalonnage gardée dans `e16/` (comparaison).
- Commandes (racine du worktree `da-ateliers`, kit NON commité) :
  `FO_DENOISE=1 py -3.9 tools/render/pieces/ateliers/rendre.py --names <variantes> --out <racine>/fo-logs/2026-11-04_DA-ATELIERS/e16b --samples 16`
  puis `FO_GRADE=... rendre.py --names ... --out ... --post-only`, puis `bash tools/render/pieces/ateliers/planches.sh <e16b> <dossier> a,b,c`.
- Corrections faites entre les passes (jugement propre) : dalles de béton pleines retirées (lecture « boîte ») ; concasseur :
  volant devant et cheminée derrière, trémie relevée (pierres visibles), tablier étroit (grille visible) ; bobineuse : bobine
  plus grosse et cuivre plus clair, banc sur pieds ; torchère : balisage rouge et blanc éclairci ; taillerie : caisse de
  cristaux bruts lumineux, cristal plus gros, jets d'eau, plateau sombre. Goulottes : signe de l'inclinaison corrigé.
