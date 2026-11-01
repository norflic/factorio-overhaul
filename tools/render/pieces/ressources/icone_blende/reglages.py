"""Icône du minerai « blende » (lot ICONE-BLENDE, 30/10/2026). Python PUR : lu par Blender (piece.py) et par le Python
système (icones.py). Aucun hasard ailleurs que dans les graines déclarées ici.

Retour du DC (30/10, vers 10 h 40) : « je viens de revoir les minerais, changez les icones mais si non c est pas mal ».
Les formes S8 (druses de tétraèdres tronqués brun-rouge, rubis et ambre, sur matrice noire) sont acceptées ; les icônes
S8 (gisement.cellule_icone : tétraèdres plats, « origamis ») ne le sont pas.

Ce que fait l'icône (même MODÈLE que le gisement S8, pas une autre pierre) :
  - chaque MORCEAU est un bloc de matrice de blende brun-noir résineux, taillé par des plans de clivage de la sphalérite
    (dodécaèdre {110} : 12 normales (±1, ±1, 0) et permutations) puis bosselé, d'où sortent 1 à 3 TÉTRAÈDRES TRONQUÉS
    rubis ou ambre (la forme cristalline de S8, avec des sommets un peu bruités : cristal naturel, pas géométrie) ;
  - matières : celles de S8 (directions.MAT : blende_noire, blende_brune, blende_rubis_r, blende_ambre_r), relevées en
    matière « minérale » (marbrure, relief fin de cassure, indice 2,37 de la sphalérite : éclat résineux/adamantin) ;
  - composition des icônes vanilla (icons/iron-ore.png, copper-ore.png…) : 3 à 5 morceaux qui remplissent le cadre de
    64 px, vus de 3/4 (caméra du pipeline, 45°), lumière de l'ouest (haut-gauche à l'écran).
Coordonnées : tuiles de jeu (x vers l'est, y vers le sud), relatives au centre de l'image ; tailles en tuiles.
"""

PX_PAR_TUILE = 320.0          # rendu fin (au lieu de 64 px par tuile) : un tas d'environ 0,9 tuile fait ~290 px
ECART = 2.0                   # distance (tuiles) entre les 4 tas d'une même scène
CADRE = 2 * 320               # côté (px) du recadrage autour du centre d'un tas avant réduction à 64 px

# Matières du gisement S8 (noms de directions.MAT) et leur rôle dans l'icône
CORPS = ("blende_noire", "blende_brune")          # matrice (sombre, marbrée de rouge)
RESSERRE = 0.80              # positions des morceaux × ce facteur (essai 2 : trous trop larges entre morceaux)
VEINE = "blende_rubis_r"                          # marbrure rouge dans la matrice
CRISTAUX = ("blende_rubis_r", "blende_rubis_r", "blende_rubis_r", "blende_ambre_r")   # tétraèdres (ambre en accent :
# essai 2, l'ambre majoritaire tirait l'icône vers l'orange du cuivre)

# Les 4 images (icone.png puis icone-1.png à icone-3.png, `pictures` de l'objet). Un morceau : (x, y, rayon, cristaux),
# cristaux = nombre de tétraèdres qui en sortent ; ordre = de l'arrière vers l'avant (sans effet sur le rendu, lisible).
TAS = (
    # icône : 4 morceaux comme iron-ore.png, le plus gros devant à droite
    ((-0.20, -0.20, 0.200, 1), (0.21, -0.21, 0.170, 1), (-0.20, 0.15, 0.185, 2), (0.17, 0.12, 0.235, 2)),
    # pictures (au sol, sur tapis) : variations de 3 à 5 morceaux
    ((-0.17, -0.17, 0.235, 2), (0.22, -0.12, 0.165, 1), (0.02, 0.20, 0.205, 2)),
    ((-0.22, -0.10, 0.180, 1), (0.10, -0.22, 0.190, 2), (0.24, 0.12, 0.160, 1), (-0.08, 0.20, 0.215, 2)),
    ((-0.18, -0.20, 0.165, 1), (0.18, -0.18, 0.215, 2), (-0.24, 0.12, 0.150, 1), (0.02, 0.06, 0.120, 1),
     (0.20, 0.20, 0.175, 1)),
)

GRAINE = 30101040             # graine de base ; morceau k de l'image i : GRAINE + 1000 × i + k
COUPES = (9, 12)              # plans de clivage par morceau (sur les 12)
CASSURE = (0.48, 0.76)        # distance des plans au centre (1 = surface de la sphère) : facettes larges
APLAT = (0.70, 0.88)          # hauteur / largeur d'un morceau (les icônes vanilla : morceaux trapus, pas des galets)
BOSSES = 0.16                 # bosses basse fréquence (part du rayon)
CRISTAL_TAILLE = (0.75, 1.00) # côté d'un tétraèdre / rayon de son morceau
CRISTAL_TRONC = (0.14, 0.28)  # troncature des pointes (S8 : 0,10 à 0,34)
CRISTAL_BRUIT = 0.07          # bruit des sommets (part de la taille) : faces un peu gauchies
CRISTAL_ENFOUI = (0.38, 0.52) # part de la hauteur du cristal sous la surface du morceau

# Réglages de rendu passés à render_piece (--set) : reflet du ciel modéré (S8 : 5,0 donnait des points blancs isolés)
GROSSIT = 1.08               # rayons des morceaux × ce facteur (essai 4 : tas trop clairsemé)
CALIB = {"PX_PER_UNIT_HR": PX_PAR_TUILE, "SKY_GLOSSY_FACTOR": 1.0}
