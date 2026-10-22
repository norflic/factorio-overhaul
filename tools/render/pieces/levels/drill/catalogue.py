"""Catalogue des 15 époques de la foreuse électrique (lot V3, phase 1) : ce que modélise epoques.py.

Python PUR (lu par build_manifest.py et le rapport). Source : docs/DESIGN_EPOQUES.md §5, ligne « Foreuse »
de chaque fiche ; « modèle » décrit ce qui est réellement construit par epoques.py (époque e : niveau
impair 2e-1 = silhouette, niveau pair 2e = la même + la pièce, au sommet de la tour, invariante par
rotation : construite dans le repère fixe N, elle ne tourne pas avec la foreuse).
"""

EPOCHS = {
    1: {"key": "pioneer", "nom": "Pionnier", "ere": "I Industrielle",
        "silhouette": "vanilla (niveau 1, Q11)",
        "piece": "chevalement en bois (trépied de poutres, sellette, poulie, corde) et lanterne pendue, posé "
                 "sur le sprite vanilla et masqué au pixel par son alpha (méthode « four » de V0)",
        "lumiere": "lanterne #FFB060 la nuit seulement (couche halo)", "emissif": "#FFB060"},
    2: {"key": "forge", "nom": "Forge", "ere": "I Industrielle",
        "silhouette": "rails en I et traverses ; 4 montants d'acier cerclés et boulonnés ; portique haut ; carter "
                      "cubique cerclé, rivets en laiton ; boucliers plats boulonnés aux angles est et ouest ; tour en treillis "
                      "d'acier et chapeau crénelé ; goulotte",
        "piece": "potence en A, grande poulie face caméra, lanterne de mine sur bras",
        "lumiere": "fentes de forge #FF6A20 et lanterne : la nuit seulement", "emissif": "#FF6A20"},
    3: {"key": "steam", "nom": "Vapeur", "ere": "I Industrielle",
        "silhouette": "chaudière verticale en cuivre rivé (tour) à dôme et dôme de vapeur ; cheminée ronde au coin "
                      "arrière gauche (opposé à la sortie) ; 8 hublots ambrés autour du fût ; 2 réservoirs d'eau en cuivre "
                      "aux angles avant ; volant latéral et bielle ; pieds en fonte à boules ; tuyaux de cuivre",
        "piece": "grand manomètre incliné sur console et sifflet en laiton au sommet",
        "lumiere": "hublots ambrés #FFC060 visibles de jour (1re lueur, D2-1)", "emissif": "#FFC060"},
    4: {"key": "oil", "nom": "Pétrole", "ere": "II Lourde",
        "silhouette": "châssis jaune en poutres sur pieds galvanisés, bandes d'avertissement ; maison du moteur et "
                      "toit-passerelle à garde-corps ; 2 vérins hydrauliques et traverse ; colonne de pompe ; longue cuve "
                      "horizontale à l'arrière sur 4 berceaux ; torchère à l'angle arrière gauche (kit d'époque) ; "
                      "4 feux ronds aux angles du garde-corps",
        "piece": "derrick en treillis avec plate-forme d'accrochage, moufle et feu au sommet",
        "lumiere": "feux d'angle orange #FF8C1A, flamme de torchère ; feu de derrick", "emissif": "#FF8C1A"},
    5: {"key": "volcano", "nom": "Volcan", "ere": "II Lourde",
        "silhouette": "carcasse en tronc de pyramide : 3 bandes d'écailles de tungstène, contreforts inclinés aux "
                      "angles (pied élargi), tourelle blindée rivetée à 4 gueules de braise et crête pyramidale ; 2 pointes "
                      "de basalte",
        "piece": "cône de cheminée volcanique à cratère rougeoyant et coulées",
        "lumiere": "fentes de braise #FF4A10 (pulsation en phase 2)", "emissif": "#FF4A10"},
    6: {"key": "electricity", "nom": "Électricité", "ere": "II Lourde",
        "silhouette": "cadre d'acier sur pieds isolants ; 2 bobines d'inductance latérales sur consoles ; carter "
                      "à persiennes ; moteur bobiné en cuivre (spires, "
                      "flasques, tirants) ; pile d'isolateurs centrale ; 2 piles d'isolateurs aux angles arrière "
                      "reliées par des arcs",
        "piece": "éclateur à cornes (barre isolante, 2 cornes en V, arc)",
        "lumiere": "arcs cyan #60D0FF (animés en phase 2)", "emissif": "#60D0FF"},
    7: {"key": "crystal", "nom": "Cristal", "ere": "III Exotique",
        "silhouette": "4 blocs de pierre taillée sertis de bronze (élargis vers l'extérieur) ; 4 grands cristaux "
                      "d'angle asymétriques inclinés "
                      "vers la tige ; tour de résonance octogonale en bronze à pointe",
        "piece": "grappe de 6 cristaux en couronne irrégulière au sommet",
        "lumiere": "cristaux violets #B070FF (respiration en phase 2)", "emissif": "#B070FF"},
    8: {"key": "swamp", "nom": "Marais", "ere": "III Exotique",
        "silhouette": "poteaux ronds et rails-tuyaux vert-de-gris ; colonne de lixiviation ; 2 grandes cuves "
                      "sphériques en verre aux angles arrière, débordant du cadre, liquide luminescent ; tube "
                      "lumineux dans une cage au sommet",
        "piece": "bulbe-distillateur et col de cygne vers une recette",
        "lumiere": "liquide vert-jaune #A8FF3A (bulles en phase 2)", "emissif": "#A8FF3A"},
    9: {"key": "atom", "nom": "Atome", "ere": "III Exotique",
        "silhouette": "piliers octogonaux en béton ; carter octogonal plombé à bandeau jaune et hublots verts ; "
                      "radiateurs de plomb à ailettes sur les faces est et ouest ; "
                      "évent hyperboloïde (tour de refroidissement) ouvert, cœur vert ; conduits annelés",
        "piece": "2 balises de radiation sur consoles",
        "lumiere": "vert uranium #5CFF4A (uranium-glow en phase 2)", "emissif": "#5CFF4A"},
    10: {"key": "hightech", "nom": "Haute technologie", "ere": "IV Haute techno",
         "silhouette": "boîtier compact aux arêtes arrondies LEVÉ sur 4 pieds fins (vide dessous) ; 2 nacelles "
                       "de capteurs latérales ; dôme ; capsule de capteurs à voyant bleu ; mât et antennes fouet",
         "piece": "parabole tournée vers le ciel, sur pivot",
         "lumiere": "voyants bleus #3AA8FF (clignotement en phase 2)", "emissif": "#3AA8FF"},
    11: {"key": "titanium", "nom": "Titane", "ere": "IV Haute techno",
         "silhouette": "cadre léger sur pieds en V (vide au sol) ; nacelle suspendue par haubans ; flèche élancée "
                       "et 4 grands ailerons en trapèze aux caps diagonaux (silhouette en flèche) ; goulotte en "
                       "titane patiné",
         "piece": "flèche-capteur : collier, nacelle fuselée en céramique claire, bague lumineuse, pointe, "
                  "3 ailettes et feu",
         "lumiere": "lignes bleu-blanc #BFE6FF (chenillard en phase 2)", "emissif": "#BFE6FF"},
    12: {"key": "superconductor", "nom": "Supraconducteurs", "ere": "IV Haute techno",
         "silhouette": "4 pylônes noirs effilés ; longerons flottants (interstices) ; tige noire à collier cyan ; "
                       "3 anneaux chromés horizontaux en lévitation, décroissants, l'anneau bas débordant du "
                       "cadre ; givre au pied",
         "piece": "anneau supplémentaire au sommet",
         "lumiere": "anneaux cyan #4AF0FF (rotation en phase 2)", "emissif": "#4AF0FF"},
    13: {"key": "fusion", "nom": "Fusion", "ere": "V Stellaire",
         "silhouette": "coque sphérique en céramique SUR TRÉPIED (vide dessous) ; grand tore de plasma équatorial "
                       "et pinces de cuivre ; tige au-dessus ; goulotte en tube",
         "piece": "injecteur (couronne, 3 buses, dard de plasma)",
         "lumiere": "plasma magenta #FF4FD8, cœur #FF9A3A (rotation en phase 2)", "emissif": "#FF4FD8"},
    14: {"key": "orbit", "nom": "Orbite", "ere": "V Stellaire",
         "silhouette": "jambes en treillis blanc (vide dessous) ; tambour ceint de feuille d'or ; 4 ailes de "
                       "panneaux dorés en X, horizontales, balise rouge au bout de chaque aile ; câble-mât, "
                       "haubans et balise de tête ; goulotte en or patiné",
         "piece": "parabole dorée sur console au flanc du mât",
         "lumiere": "cellules bleues #2F6BFF, balises rouges #FF2A2A (clignotement en phase 2)",
         "emissif": "#FF2A2A"},
    15: {"key": "legend", "nom": "Légende", "ere": "V Stellaire",
         "silhouette": "anneau octogonal FLOTTANT (aucun appui, centre ajouré) ; coussin de lumière ; 4 grands "
                       "obélisques flottants écartés aux angles ; tour-flèche flottante tenue par 4 rayons ; "
                       "couronne de 8 petites flèches et éclats",
         "piece": "halo : anneau de lumière, cercle d'or blanc et anneau incliné au sommet de la flèche",
         "lumiere": "blanc doré #FFF2C0 (particules en phase 2)", "emissif": "#FFF2C0"},
}
