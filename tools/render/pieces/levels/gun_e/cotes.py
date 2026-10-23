"""COTES DE LA LIGNÉE de la mitrailleuse (lot V3-E), Python PUR (importable hors Blender : accroches.py, outils).
FICHIER GELÉ pour les constructeurs. Déplacé de corps.py à la passe 5 (deuxième temps du kit) SANS changer une valeur :
corps.TAILLES est ce même dictionnaire (corps.py fait « from cotes import TAILLES »).
"""
import math

# canon du TÉMOIN du kit (ep00, lignée seule) par taille : interpolé entre les témoins n11, n21 et n29 de la première
# passe ; sert aussi de canon de référence aux places libres des points d'accroche (accroches.py)
CANON_TEMOIN = {2: dict(L=0.9, nb=4, rb=0.04, rr=0.075), 3: dict(L=1.35, nb=4, rb=0.045, rr=0.1),
                4: dict(L=1.7, nb=6, rb=0.05, rr=0.125), 5: dict(L=2.1, nb=6, rb=0.06, rr=0.145),
                6: dict(L=2.5, nb=6, rb=0.072, rr=0.175)}

# colonne : R rayon, h hauteur, rh hauteur de la couronne dentée, n pans, echelle angle de l'échelle
# tete    : R rayon de jupe, zs haut de jupe, rz hauteur de coupole, gx demi-écart des canons, zg hauteur des canons,
#           recv (y0, y1) de la culasse, wr largeur et hr demi-hauteur de la culasse
# tremie  : (x0, x1, y de jeu de la face sud, y Blender de la face nord, hauteur), goulotte (2 points) et largeur
# plateforme : retrait sous le contour, avant (y de jeu de la face sud), chanfrein avant par défaut (l'époque peut le
#           régler : remplissage de l'emprise, catalogue §A.5), rapport du chanfrein arrière
# piece   : coin avant de la pièce du niveau pair (x, y de jeu) et échelle des pièces de la plage basse
# nacelle : recul arrière, bas de coque ; echap : rayon et hauteur des échappements par défaut
# tourelleau : hauteur, rayon, périscopes, écart angulaire, dimensions ; trappe : rayon
TAILLES = {
    2: dict(colonne=dict(R=0.5, h=0.4, rh=0.07, n=10, echelle=-math.pi * 0.72),
            tete=dict(R=0.38, zs=0.7, rz=0.27, gx=0.56, zg=0.82, recv=(-0.22, 0.28), wr=0.19, hr=0.115),
            tremie=(-0.3, 0.3, -0.97, -0.74, 0.32), goulotte=None, goulotte_w=0.11,
            plateforme=dict(retrait=0.12, avant=0.99, chanfrein=0.36),
            piece=dict(x=0.74, yn=-0.74, s=1.0),
            nacelle=dict(recul=0.26, bas=0.2), echap=(0.045, 0.18),
            tourelleau=dict(h=0.12, r=0.14, n=2, pas=0.6, peri=(0.06, 0.045, 0.055), lentille=(0.045, 0.008, 0.026),
                            av=0.025),
            trappe=0.1, jupe_bandes=12, coupole_coutures=10, rangs=(0.62,)),
    3: dict(colonne=dict(R=0.8, h=0.6, rh=0.08, n=12, echelle=-math.pi * 0.72),
            tete=dict(R=0.68, zs=1.0, rz=0.42, gx=0.94, zg=1.15, recv=(-0.36, 0.5), wr=0.28, hr=0.16),
            tremie=(-0.38, 0.38, -1.42, -1.0, 0.46), goulotte=None, goulotte_w=0.14,
            plateforme=dict(retrait=0.12, avant=1.46, chanfrein=0.5),
            piece=dict(x=1.16, yn=-1.16, s=1.25),
            nacelle=dict(recul=0.26, bas=0.2), echap=(0.05, 0.21),
            tourelleau=dict(h=0.14, r=0.17, n=3, pas=0.6, peri=(0.06, 0.045, 0.055), lentille=(0.045, 0.008, 0.026),
                            av=0.025),
            trappe=0.12, jupe_bandes=12, coupole_coutures=10, rangs=(0.62,)),
    4: dict(colonne=dict(R=1.05, h=0.8, rh=0.1, n=14, echelle=-math.pi * 0.72),
            tete=dict(R=0.92, zs=1.3, rz=0.52, gx=1.24, zg=1.47, recv=(-0.5, 0.66), wr=0.37, hr=0.21),
            tremie=(-0.44, 0.44, -1.93, -1.3, 0.58), goulotte=None, goulotte_w=0.17,
            plateforme=dict(retrait=0.12, avant=1.97, chanfrein=0.7),
            piece=dict(x=1.55, yn=-1.55, s=1.65),
            nacelle=dict(recul=0.26, bas=0.2), echap=(0.055, 0.24),
            tourelleau=dict(h=0.16, r=0.2, n=4, pas=0.6, peri=(0.06, 0.045, 0.055), lentille=(0.045, 0.008, 0.026),
                            av=0.025),
            trappe=0.14, jupe_bandes=12, coupole_coutures=10, rangs=(0.5, 0.95)),
    5: dict(colonne=dict(R=1.3, h=0.98, rh=0.12, n=16, echelle=-math.pi * 0.7),
            tete=dict(R=1.12, zs=1.55, rz=0.62, gx=1.5, zg=1.74, recv=(-0.6, 0.8), wr=0.44, hr=0.25),
            tremie=(-0.46, 0.46, -2.4, -1.62, 0.66), goulotte=((0.0, -1.42, 0.92), (0.0, -1.1, 1.08)),
            goulotte_w=0.18,
            plateforme=dict(retrait=0.14, avant=2.44, chanfrein=0.55),
            piece=dict(x=1.5, yn=-2.64, s=1.0),
            nacelle=dict(recul=0.4, bas=0.22), echap=(0.065, 0.28),
            tourelleau=dict(h=0.18, r=0.22, n=4, pas=0.55, peri=(0.07, 0.05, 0.06), lentille=(0.05, 0.008, 0.03),
                            av=0.028),
            trappe=0.16, jupe_bandes=14, coupole_coutures=12, rangs=(0.5, 0.95)),
    6: dict(colonne=dict(R=1.6, h=1.16, rh=0.14, n=16, echelle=-math.pi * 0.68),
            tete=dict(R=1.38, zs=1.8, rz=0.74, gx=1.84, zg=2.0, recv=(-0.74, 0.95), wr=0.52, hr=0.3),
            tremie=(-0.54, 0.54, -2.75, -1.95, 0.78), goulotte=((0.0, -1.75, 1.08), (0.0, -1.38, 1.28)),
            goulotte_w=0.2,
            plateforme=dict(retrait=0.16, avant=2.78, chanfrein=0.7),
            piece=dict(x=1.22, yn=-2.97, s=1.0),
            nacelle=dict(recul=0.4, bas=0.22), echap=(0.065, 0.28),
            tourelleau=dict(h=0.18, r=0.22, n=5, pas=0.55, peri=(0.07, 0.05, 0.06), lentille=(0.05, 0.008, 0.03),
                            av=0.028),
            trappe=0.16, jupe_bandes=14, coupole_coutures=12, rangs=(0.5, 0.95)),
}
