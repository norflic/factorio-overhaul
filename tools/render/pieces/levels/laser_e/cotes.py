"""COTES DE LA LIGNÉE de la tourelle LASER (lot F1-A, 24/10), Python PUR (importable hors Blender : profil.py, outils,
tests). FICHIER GELÉ pour les constructeurs d'âge (une retouche se demande à l'intégrateur du kit) ; gelé APRÈS le
quatrième jet (correction du lot F1-A, 24/10 : défauts M-1, M-4, M-5 de la vérification).

Unités : x et yn en TUILES DE JEU (yn vers le nord ; Blender Y = yn × √2, commun/repere.Y) ; z en unités Blender (une
unité de hauteur se lit 0,707 tuile à l'écran). Les rayons de l'AFFÛT sont des rayons « ronds à l'écran » (cercle au sol
de jeu : ellipse en Blender, demi-axe Y × √2) ; les pièces de la TÊTE sont de vrais volumes de révolution (le cylindre
de la platine est rond dans Blender).

Formules (côté s = 2 à 6, emprise de l'ère, epoques.COTE) ; toutes CROISSANTES en s (test : tests/test_laser.py) :
  affût      R1 = 0,47 s − 0,04 (rayon du 1er gradin) ; H = 0,2 + 0,12 s (hauteur totale des gradins) ;
             gradins par défaut : 2 en 2×2, 3 au-delà ; retrait d'un gradin au suivant : RAPPORT_GRADIN (0,74) ;
  pivot      tambour sur le dernier gradin : Rp = 0,16 s + 0,08, hauteur 0,12 + 0,08 s ;
  condensateurs  couronne de n condensateurs debout sur le 1er gradin (n = 8, 12, 12, 16, 16), rayon 0,05 + 0,022 s,
             hauteur 0,22 + 0,07 s, posés à R1 − r − 0,04 ;
  tête       platine Rt = 0,2 s + 0,1 ; émetteur de rayon re = 0,2 s + 0,05, logé entre deux joues (étrier) à
             x = ±(re + 0,05 + 0,01 s) ; axe des tourillons à zh ; caisson arrière (refroidisseur) BAS ET ÉTROIT
             derrière l'émetteur (quatrième jet, M-4) : x ±0,5 re, dessus à zh − 0,3 re (SOUS l'axe des tourillons),
             pour que l'émetteur le dépasse par le haut en pose N ;
  proue      repère de direction de la lignée (quatrième jet, M-1) : nez plat posé sur la platine, du centre jusqu'à
             y = 1,45 re (DANS le rayon balayé par l'émetteur, 1,6 re), épaule à 1,15 re, fente lumineuse sur son
             axe ; bas (au ras de la platine) : rien de dressé (F119) ;
             ENVELOPPE de l'émetteur : y de −0,8 re à +1,25 re (longueur 2,05 re pour un diamètre 2 re : rapport 1,03,
             règle de la pose N, F119 : jamais un tube dressé) ;
  places     coins de l'emprise hors du 1er gradin : centre (±(s/2 − rc), ±(s/2 − rc)), rayon libre
             rc = (√2 s/2 − R1) / (1 + √2) ; les coins AVANT (sud) portent la pièce du niveau pair (bande toujours
             visible, hors de la zone balayée par la tête : test_laser.py).
Historique (24/10) : premier jet (H = 0,14 + 0,075 s ; re = 0,115 s + 0,04 ; Rt = 0,16 s + 0,06 ; pivot 0,15 s + 0,07
et 0,06 + 0,035 s ; condensateurs 0,045 + 0,018 s et 0,16 + 0,05 s ; retrait 0,78 ; bx = 0,85 xc) : au témoin, affût
plat (« couvercle »), tête petite. Deuxième jet (vers 9 h 05 : H, condensateurs, pivot 0,1 + 0,06 s, re = 0,14 s + 0,05,
Rt = 0,18 s + 0,08) : aux aperçus 3, 9 et 15 à côté de la mitrailleuse, l'émetteur ne portait pas l'âge au zoom 1 et
le caisson arrière laissait des jours aux joues en pose N. Troisième jet (vers 9 h 25) : émetteur et tête agrandis,
caisson arrière jusqu'aux joues (bx = xc + tc / 2, dessus à zh + 0,45 re). Quatrième jet (correction F1-A, 24/10 vers
11 h) : le caisson du troisième jet CACHAIT l'émetteur en pose N (M-4) : caisson bas et étroit ; proue (M-1). Les autres
valeurs sont celles du troisième jet.
"""
import math

SQ2 = math.sqrt(2.0)
RAPPORT_GRADIN = 0.74
N_CONDENSATEURS = {2: 8, 3: 12, 4: 12, 5: 16, 6: 16}


def _taille(s):
    R1 = 0.47 * s - 0.04
    H = 0.2 + 0.12 * s
    rc_cond = 0.05 + 0.022 * s
    re = 0.2 * s + 0.05
    Rt = 0.2 * s + 0.1
    xc = re + 0.05 + 0.01 * s
    tc = 0.05 + 0.012 * s
    hp = 0.12 + 0.08 * s
    zp = H + hp                         # dessus du pivot = dessous de la platine de la tête
    hpl = 0.05 + 0.01 * s               # épaisseur de la platine
    zh = zp + hpl + re + 0.06 + 0.02 * s  # axe des tourillons (centre de l'émetteur)
    r_coin = (SQ2 * s / 2.0 - R1) / (1.0 + SQ2)
    return dict(
        affut=dict(R1=R1, H=H, gradins=2 if s == 2 else 3, rapport=RAPPORT_GRADIN, segments=24 + 4 * s,
                   bord=0.03 + 0.006 * s),
        pivot=dict(R=0.16 * s + 0.08, h=hp, z0=H),
        condensateurs=dict(n=N_CONDENSATEURS[s], r=rc_cond, h=0.22 + 0.07 * s, Rm=R1 - rc_cond - 0.04),
        tete=dict(Rt=Rt, z0=zp, hpl=hpl, re=re, xc=xc, tc=tc, zh=zh,
                  y_av=1.25 * re, y_ar=-0.8 * re,
                  # caisson arrière (refroidisseur) : x ±bx, y de yb0 à yb1, z de la platine à zb1 ; quatrième jet :
                  # bas (sous l'axe des tourillons) et étroit (M-4)
                  bx=0.5 * re, yb0=-(0.8 * re + 0.12 + 0.03 * s), yb1=-0.45 * re, zb1=zh - 0.3 * re,
                  # proue (repère de direction, M-1) : y de py0 à py1 (pointe), épaule à py_ep ; demi-largeurs
                  py0=0.3 * re, py_ep=1.15 * re, py1=1.45 * re, pw0=0.5 * re, pw_ep=0.3 * re,
                  ph=hpl * 0.8, fente=0.035 + 0.008 * s),
        coin=dict(r=r_coin, d=s / 2.0 - r_coin),
        piece=dict(x=s / 2.0 - r_coin, yn=-(s / 2.0 - r_coin), r=r_coin, s=1.0 + 0.25 * (s - 2)),
    )


TAILLES = {s: _taille(s) for s in (2, 3, 4, 5, 6)}


def rayons_gradins(s, n=None, rapport=None):
    """Rayons (« ronds à l'écran », tuiles) du pied de chaque gradin, du bas vers le haut."""
    A = TAILLES[s]["affut"]
    n = n or A["gradins"]
    k = A["rapport"] if rapport is None else rapport
    # le dernier gradin garde la place du pivot (Rp + 0,08 au moins)
    Rp = TAILLES[s]["pivot"]["R"]
    rs = [A["R1"] * (k ** i) for i in range(n)]
    return [max(r, Rp + 0.08) for r in rs]


def hauteurs_gradins(s, n=None):
    """Hauteurs (z Blender) du dessus de chaque gradin, du bas vers le haut (gradins égaux)."""
    A = TAILLES[s]["affut"]
    n = n or A["gradins"]
    return [A["H"] * (i + 1) / n for i in range(n)]


def places(s):
    """Places libres des SUPERSTRUCTURES d'âge (tuiles de jeu ; z_sol : hauteur du support ; r : rayon libre) :
    coins de l'emprise hors du 1er gradin (NO, NE à l'arrière ; SO, SE à l'avant, réservés à la pièce paire) et
    flancs du 1er gradin (O, E : sur le gradin, entre deux condensateurs, à R1 − 0,5 × largeur de l'anneau)."""
    T = TAILLES[s]
    d, r = T["coin"]["d"], T["coin"]["r"]
    R1 = T["affut"]["R1"]
    R2 = rayons_gradins(s)[1] if T["affut"]["gradins"] > 1 else R1 * 0.7
    z1 = hauteurs_gradins(s)[0]
    out = {}
    for nom, sx, sy in (("coin_NO", -1, 1), ("coin_NE", 1, 1), ("coin_SO", -1, -1), ("coin_SE", 1, -1)):
        out[nom] = dict(x=sx * d, yn=sy * d, z_sol=0.0, r=r)
    rf = (R1 + R2) / 2.0
    for nom, sx in (("flanc_O", -1), ("flanc_E", 1)):
        out[nom] = dict(x=sx * rf, yn=0.0, z_sol=z1, r=(R1 - R2) / 2.0)
    return out


CONTOURS = ("lobes", "etoile", "dents")


def facteur_contour(cont, a):
    """Facteur de rayon (0 < k <= 1) du CONTOUR d'un gradin à l'angle a (radians, plan « rond à l'écran ») : 1 au sommet
    d'un lobe, d'une pointe ou d'une dent, 1 − prof au creux. cont : None (rond) ou dict(forme=lobes|etoile|dents,
    n=nombre, prof=profondeur relative, phase=angle du premier sommet en degrés, 90 par défaut : au nord)."""
    if not cont:
        return 1.0
    n, d = int(cont["n"]), float(cont["prof"])
    u = ((a - math.radians(cont.get("phase", 90.0))) * n / (2 * math.pi)) % 1.0
    f = cont["forme"]
    if f == "lobes":
        return 1.0 - d * (1.0 - abs(math.cos(math.pi * u)))
    if f == "etoile":
        return 1.0 - d * (1.0 - abs(1.0 - 2.0 * u))
    if f == "dents":
        return 1.0 if (u <= 0.25 or u >= 0.75) else 1.0 - d
    raise ValueError("contour %r inconnu (%s)" % (f, ", ".join(CONTOURS)))


def profil_contour(cont, nseg, phase=0.0):
    """[(angle, facteur)] des sommets d'un gradin : nseg sommets réguliers (rond ou pans) si cont est None ; sinon les
    sommets du contour (lobes : 16 par lobe ; étoile : 2 par pointe ; dents : 4 par dent, flancs presque droits). Le
    même profil sert à TOUS les gradins (mêmes sommets : flancs entre deux gradins)."""
    tau = 2 * math.pi
    if not cont:
        return [(phase + tau * i / nseg, 1.0) for i in range(nseg)]
    n, d = int(cont["n"]), float(cont["prof"])
    ph = math.radians(cont.get("phase", 90.0))
    f = cont["forme"]
    if f == "lobes":
        m = 16 * n
        return [(ph + tau * i / m, facteur_contour(cont, ph + tau * i / m)) for i in range(m)]
    if f == "etoile":
        return [(ph + tau * i / (2 * n), 1.0 if i % 2 == 0 else 1.0 - d) for i in range(2 * n)]
    if f == "dents":
        p = tau / n
        eps = 0.03 * p
        out = []
        for k in range(n):
            t0 = ph + k * p
            out += [(t0 - 0.25 * p, 1.0), (t0 + 0.25 * p, 1.0), (t0 + 0.25 * p + eps, 1.0 - d),
                    (t0 + 0.75 * p - eps, 1.0 - d)]
        return out
    raise ValueError("contour %r inconnu (%s)" % (f, ", ".join(CONTOURS)))


def enveloppe_tete(s):
    """Rayon (tuiles de jeu, au sol) que balaie la tête en tournant : max de la platine, des tourillons et de la pointe
    de l'émetteur (pour la règle de la pièce paire : la tête ne doit pas la recouvrir de dessus)."""
    T = TAILLES[s]["tete"]
    return max(T["Rt"], math.hypot(T["xc"] + T["tc"] + 0.06, 0.0), math.hypot(T["re"], T["y_av"]),
               math.hypot(T["bx"], -T["yb0"]), T["py1"])
