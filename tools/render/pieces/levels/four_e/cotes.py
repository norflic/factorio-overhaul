"""COTES DE LA LIGNÉE du FOUR (lot F2-A, 25/10), Python PUR (importable hors Blender : profil.py, outils, tests).

Unités : x et yn en TUILES DE JEU (yn vers le nord ; Blender Y = yn × √2, commun/repere.Y) ; z en unités Blender (une
unité de hauteur se lit 0,707 tuile à l'écran). La caméra du jeu regarde du SUD à 45° : seules les faces SUD et le
DESSUS se voient ; un flanc est ou ouest est vu par la tranche.

Formules (côté s = 2 à 6, emprise de l'ère, epoques.COTE) ; toutes croissantes en s (test : tests/test_four.py) :
  sole       dalle d'appui sur toute l'emprise, rentrée de 0,05 : hauteur 0,05 + 0,01 s ;
  tablier    bande AVANT de la sole, libre de la chambre : profondeur a = 0,26 + 0,06 s ; la face sud de la chambre est
             à y_av = −s/2 + a ; l'arrière de l'enveloppe à y_ar = s/2 − 0,08 ; x de l'enveloppe ±(s/2 − 0,08) ;
  chambre    hauteur de référence H = 0,45 + 0,5 s ; plafond de l'enveloppe zmax = H + 0,35 + 0,2 s (couronnes et
             cheminées comprises) ;
  gueule     SIGNAL DE JEU FIXE : bouche du foyer au milieu de la face sud, au ras du tablier ; largeur 0,36 + 0,16 s,
             hauteur 0,22 + 0,1 s, bas à sole + 0,06 ; le CAISSON DU FOYER qui la porte (largeur + 0,16 + 0,03 s, hauteur
             + 0,14 + 0,03 s) avance de 0,12 + 0,03 s sur le tablier et entre de 0,3 + 0,05 s dans la chambre ;
  fumée      SIGNAL DE JEU FIXE : la bouche de fumée est dans le quart ARRIÈRE DROIT (nord-est) : place conseillée
             (0,27 s ; 0,2 s), rayon 0,08 + 0,035 s ; l'âge choisit sa hauteur (corps.bouche_fumee la relève dans
             c.fumee : x, yn, z, pour la source de fumée du prototype au lot d'intégration) ;
  coins      deux places AVANT (coin_SO, coin_SE) sur le tablier, de part et d'autre du caisson du foyer : pièce du
             niveau pair ; demi-largeur rw, profondeur a, centre (±xc, yc).
  écran      PLAFOND À L'ÉCRAN (premier aperçu du témoin k6, 25/10 : sa cheminée sortait de la fenêtre des planches,
             côté + 3 tuiles) : rien ne monte à l'écran au-delà de ecran = 0,5 s + 1,35 tuiles au nord du centre
             (yn + 0,707 z ; 1,35 tuile au-dessus du bord nord de l'emprise ; le four en acier vanilla monte à 0,3) ;
             z_plafond(T, yn) donne la hauteur permise en yn ; la bouche de fumée y est contrôlée.
"""
import math

SQ2 = math.sqrt(2.0)
TAILLES_PERMISES = (2, 3, 4, 5, 6)


def _taille(s):
    sole_h = 0.05 + 0.01 * s
    a = 0.26 + 0.06 * s
    xa = s / 2.0 - 0.08
    y_av = -s / 2.0 + a
    y_ar = s / 2.0 - 0.08
    H = 0.45 + 0.5 * s
    zmax = H + 0.35 + 0.2 * s
    wg = 0.36 + 0.16 * s
    hg = 0.22 + 0.1 * s
    wf = wg + 0.16 + 0.03 * s
    hf = hg + 0.14 + 0.03 * s
    avance = 0.12 + 0.03 * s
    entre = 0.3 + 0.05 * s
    zb = sole_h + 0.06
    # coins avant : entre le caisson du foyer et le bord de l'emprise
    x_in = wf / 2.0 + 0.05
    x_out = s / 2.0 - 0.08
    rw = (x_out - x_in) / 2.0
    xc = (x_in + x_out) / 2.0
    yc = -s / 2.0 + 0.04 + a / 2.0
    return dict(
        s=s, sole_h=sole_h, tablier=a, xa=xa, y_av=y_av, y_ar=y_ar, H=H, zmax=zmax,
        gueule=dict(w=wg, h=hg, zb=zb, wf=wf, hf=hf, avance=avance, entre=entre,
                    y_face=y_av - avance, y_fond=y_av + entre),
        fumee=dict(x=0.27 * s, yn=0.2 * s, r=0.08 + 0.035 * s),
        coins=dict(coin_SO=dict(x=-xc, yn=yc, rw=rw, prof=a - 0.06),
                   coin_SE=dict(x=xc, yn=yc, rw=rw, prof=a - 0.06)),
        halo=4.0 + 2.0 * s,
        ecran=0.5 * s + 1.35,
    )


TAILLES = {s: _taille(s) for s in TAILLES_PERMISES}
K_ECRAN = 0.7071


def z_plafond(T, yn, marge=0.0):
    """Hauteur permise au point de jeu yn (plafond à l'écran), moins `marge` (rayon d'une pièce, tuiles)."""
    return (T["ecran"] - yn - marge) / K_ECRAN


def dans_enveloppe(T, x, yn, z, marge=0.0):
    """Vrai si le point (x, yn, z) est dans l'enveloppe de la chambre (tablier exclu), à `marge` près."""
    return (abs(x) <= T["xa"] + marge and T["y_av"] - marge - T["gueule"]["avance"] <= yn <= T["y_ar"] + marge
            and 0.0 <= z <= T["zmax"] + marge)


def fumee_valide(T, x, yn, z):
    """Règle du signal « fumée » : bouche dans le quart arrière droit (x > 0, yn > 0), dans l'enveloppe, au-dessus de
    la moitié de la hauteur de référence (elle se voit au-dessus de la chambre), sous le plafond à l'écran."""
    return (x > 0.0 and yn > 0.0 and dans_enveloppe(T, x, yn, z, 0.02) and z >= 0.5 * T["H"]
            and yn + K_ECRAN * z <= T["ecran"] + 1e-6)
