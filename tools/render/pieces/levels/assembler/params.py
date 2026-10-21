"""Paramètres des 30 niveaux de la machine d'assemblage 2 (lot V3, phase 1). Python PUR (aucun bpy) : lu par
Blender (modélisation), par le pilote de rendu, par la mesure D1 et par les planches.

Source : docs/DESIGN_EPOQUES.md (bible, qui fait règle) : §2.8 (fiche technique), §4 (enveloppes), §5 (fiches
d'époque, ligne « Assembleur 2 »), §1.5 (palette), §1.6 (lumière) ; décisions Q6, Q8 à Q13 (OBJECTIFS §4).
"""

FAMILLE = "assembler"
NOM = "machine d'assemblage 2"
EMPRISE = 3                      # tuiles (collision ±1,2, sélection ±1,5 : inchangées, D1-4)
PLAFOND_O = 1.50                 # bible §1.4 (Q9) : dépassement maximal au-dessus de l'emprise, époque 15

# Enveloppes par époque (bible §4, colonne « Assembleur 2 ») : O, L (tuiles), V (% du masque du niveau 1)
ENVELOPPE = {
    1: (0.06, 2.56, 0), 2: (0.16, 2.60, 0), 3: (0.27, 2.64, 0), 4: (0.37, 2.68, 0), 5: (0.47, 2.71, 0),
    6: (0.57, 2.75, 0), 7: (0.68, 2.79, 0), 8: (0.78, 2.83, 0), 9: (0.88, 2.87, 0), 10: (0.99, 2.91, 6),
    11: (1.09, 2.95, 12), 12: (1.19, 2.98, 18), 13: (1.29, 3.02, 23), 14: (1.40, 3.06, 29), 15: (1.50, 3.10, 35),
}

# Époques : thème, ère, signature, silhouette impaire, pièce paire, lumière (bible §5, ligne « Assembleur 2 »)
EPOQUES = {
    1: dict(theme="Pionnier", ere="I", impair="vanilla (niveau 1 inchangé, Q11)",
            piece="potence de levage en bois avec palan, en haut à droite (+0,50 en haut, +0,10 à droite)",
            lumiere="lanterne de la potence, la nuit seulement", emissif="#FFB060", nuit_seule=True),
    2: dict(theme="Forge", ere="I", impair="caisse rivetée cerclée ; grand volant d'inertie sur le flanc droit ; arbre "
            "de transmission sur deux paliers au toit", piece="marteau-pilon vertical sur le toit (+0,30)",
            lumiere="fentes de forge, la nuit seulement", emissif="#FF6A20", nuit_seule=True),
    3: dict(theme="Vapeur", ere="I", impair="machine à vapeur sur le toit : cylindre à piston horizontal, bielle, "
            "poulie et courroie, cheminée ronde à collerette, manomètres", piece="régulateur à boules de Watt au sommet "
            "(+0,30)", lumiere="hublot et cadrans ambrés, de jour", emissif="#FFC060", nuit_seule=False),
    4: dict(theme="Pétrole", ere="II", impair="presse hydraulique : portique jaune sur le toit (2 montants, une "
            "traverse, vérin) ; cuves latérales horizontales ; garde-corps", piece="cuve de pression verticale sur le "
            "flanc droit (+0,15 à droite)", lumiere="voyants orange", emissif="#FF8C1A", nuit_seule=False),
    5: dict(theme="Volcan", ere="II", impair="presse blindée en tronc de pyramide à gradins, blindage en écailles, "
            "capot incliné, fente de marteau rougeoyante, deux pointes de basalte aux coins arrière",
            piece="contreforts inclinés à gauche et à droite (+0,15)",
            lumiere="fentes de braise", emissif="#FF4A10", nuit_seule=False),
    6: dict(theme="Électricité", ere="II", impair="bras de soudure à l'arc sur le toit ; piles d'isolateurs sur bobines "
            "aux quatre coins", piece="anneau de bobine vertical au-dessus (+0,30)", lumiere="arc de soudure cyan, "
            "voyants", emissif="#60D0FF", nuit_seule=False),
    7: dict(theme="Cristal", ere="III", impair="corps bas de pierre cerclé de bronze ; couronne de cristaux "
            "asymétriques sur le toit", piece="grand cristal central au-dessus (+0,30)", lumiere="cristaux violets",
            emissif="#B070FF", nuit_seule=False),
    8: dict(theme="Marais", ere="III", impair="corps arrondi vert-de-gris ; trois fioles-réacteurs bouillonnantes sur "
            "le toit, conduits", piece="grand bulbe central et serpentin (+0,30)", lumiere="liquide vert-jaune",
            emissif="#A8FF3A", nuit_seule=False),
    9: dict(theme="Atome", ere="III", impair="cellule chaude plombée : corps octogonal chanfreiné, grand hublot vert, "
            "deux bras télémanipulateurs sur le toit", piece="tour de refroidissement miniature (+0,30)",
            lumiere="hublot et cœur vert uranium", emissif="#5CFF4A", nuit_seule=False),
    10: dict(theme="Haute technologie", ere="IV", impair="coque lisse sur pieds courts ; dôme ; trois bras robotisés "
             "articulés ; bandeau de voyants", piece="antenne-parabole (+0,30)", lumiere="voyants et écran bleus",
             emissif="#3AA8FF", nuit_seule=False),
    11: dict(theme="Titane", ere="IV", impair="portique blanc à ailerons sur quatre pieds en V, côtés ouverts, "
             "plateau bas", piece="grue en flèche (+0,30)", lumiere="lignes bleu-blanc (chenillard)",
             emissif="#BFE6FF", nuit_seule=False),
    12: dict(theme="Supraconducteurs", ere="IV", impair="plateau de travail en lévitation entre quatre pylônes ; "
             "anneaux chromés flottants ; bloc noir flottant", piece="anneau vertical au-dessus (+0,30)",
             lumiere="anneaux cyan", emissif="#4AF0FF", nuit_seule=False),
    13: dict(theme="Fusion", ere="V", impair="noyau sphérique sur trépied dans un cadre ouvert ; tore de plasma "
             "horizontal", piece="couronne d'injecteurs (+0,20, plafond)", lumiere="plasma magenta, cœur orange",
             emissif="#FF4FD8", nuit_seule=False),
    14: dict(theme="Orbite", ere="V", impair="plate-forme sur pieds ; ailes de panneaux dorés ; parabole ; bras de "
             "grue", piece="réservoir sphérique doré (+0,10, plafond)", lumiere="cellules bleues, balises rouges",
             emissif="#2F6BFF", nuit_seule=False),
    15: dict(theme="Légende", ere="V", impair="couronne de flèches en or blanc et noyau flottant ; base flottante ; "
             "cadre ajouré", piece="halo de particules (anneau-halo et particules) au-dessus",
             lumiere="lumière blanche dorée, particules", emissif="#FFF2C0", nuit_seule=False),
}


def epoque(n):
    return (n + 1) // 2


def est_pair(n):
    return n % 2 == 0


def halo_fenetres(n):
    """Fenêtres du halo (draw_as_light) en tuiles relatives à l'entité : centre (dx, dy, z), rayons plein/nul.
    Rayon croissant avec le niveau (bible §1.6 : S(N) = s × (1 + 0,05·N), ici borné pour la couche rendue ;
    la lumière moteur de la phase 2 suivra la formule complète)."""
    k = 1.0 + 0.05 * n
    return [{"at": (0.0, 0.0, 0.0), "r": (0.55 * k, 1.05 * k)}]


def halo_cible(n):
    """Maximum visé de la couche halo AU SOL (bible §1.6 : intensité I(N) = 0,05 + 0,02·N, ramenée à la plage
    vanilla : 0,79 au sol du four en acier)."""
    return min(0.80, 0.25 + 0.0185 * n)


def halo_puissance(n):
    """Puissance totale (W) des sources ponctuelles du halo d'un niveau."""
    return 10.0 + 1.3 * n


# Niveau 2 : la pièce de l'époque 1 est posée sur le sprite vanilla, masquée au pixel par son alpha (variante
# « four » du lot V0). Sprites vanilla de la machine d'assemblage 2, image 0 (entities.lua:4752-4793).
VANILLA = {
    "main": {"file": "assembling-machine-2/hr-assembling-machine-2.png", "frame": (214, 218), "shift": (0.0, 0.125)},
    "shadow": {"file": "assembling-machine-2/hr-assembling-machine-2-shadow.png", "frame": (196, 163),
               "shift": (0.375, 0.1484375)},
    "main_lr": {"file": "assembling-machine-2/assembling-machine-2.png", "frame": (108, 110), "shift": (0.0, 0.125)},
    "shadow_lr": {"file": "assembling-machine-2/assembling-machine-2-shadow.png", "frame": (98, 82),
                  "shift": (0.375, 0.15625)},
}
