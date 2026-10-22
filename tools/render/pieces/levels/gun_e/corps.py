"""CORPS DE LIGNÉE COMMUN de la mitrailleuse (lot V3-E, quatrième passe, 23/10), aux 5 tailles de l'emprise (2×2 à
6×6, shared/levels/config.lua L.footprints.gun). S'exécute DANS Blender. FICHIER GELÉ pour les constructeurs.

Corps retenu : celui de la PREMIÈRE PASSE (V3-S industriel, commit 265574d), que le Directeur Créatif a trouvé
« parfait », « très précis » ; c'est aussi celui que la plage haute de la passe 3 avait gardé (plateforme de
caillebotis sombre continue, coupole olive, masque ocre, nacelle olive et ocre, colonne olive et brun-rouge). Les
tailles 2×2 à 4×4 reprennent les cotes de la plage basse (seules à exister), le reste de la grammaire est celui de
la lignée : la rupture entre les époques 9 et 10 (dalles claires en croix contre plateforme sombre, coupole et colonne
recolorées par époque, reflets propres à l'ère I) disparaît.

Ce que le corps dessine (identique aux 15 époques, à la taille près) :
  socle  : plateforme de caillebotis (tablier bas continu : aucun trou enfermé), colonne à goussets et couronne
           dentée à bandes de danger, trémie à trappe ouverte et goulotte vers la couronne ;
  tête   : collier riveté, jupe blindée à bandes, coupole rivetée à nervures, masque avant (par défaut), nacelle
           arrière (coque, face arrière), tourelleau à périscopes, trappe, 2 bras de tourillon avec berceaux ;
  canon  : la ROSETTE (faisceau de tubes séparés à âme pleine, plaque de culasse, colliers de maintien) et la BOUCHE
           (rosace sombre cerclée, pourtour éclairé) sont fournies par rosette() et bouche() ; canon_lignee() est le
           canon de lignée complet corrigé pour la pose N (règle d'or 7) : c'est la base sur laquelle une époque
           AJOUTE son organe (règle d'or 1).
Ce que l'époque dessine (epNN.py, emplacements du catalogue §A.2, contrat dans epoques.py) : arme, tuyaux et grands
volumes annexes, accents, foyers, pièce du niveau pair.
"""
import math

from mathutils import Matrix, Vector

import formes as F
import parts as PT
import parts2 as P2
import parts3 as P3
from kit import SQ2, TAU

V = Vector

# longueur maximale d'une jaquette, carénage ou manchon d'époque posé SUR le faisceau, en part de la longueur des tubes
# (règle d'or 1) : au-delà, le faisceau et sa bouche ne se lisent plus
JAQUETTE_MAX = 0.5


def Y(yn):
    """y de jeu en tuiles, vers le NORD -> Y Blender."""
    return yn * SQ2


class at:
    """Repère local posé en (x, y de jeu vers le nord, z), tourné de rz : `with at(g, x, yn, rz): ...`."""

    def __init__(self, g, x, yn, rz=0.0, z=0.0):
        self.g, self.a = g, ((x, Y(yn), z), rz)

    def __enter__(self):
        self.g.push(self.a[0], rz=self.a[1])
        return self.g

    def __exit__(self, *exc):
        self.g.pop()


# ------------------------------------------------------------------------------------------------
# Cotes de la lignée par taille d'emprise (côté en tuiles)
# ------------------------------------------------------------------------------------------------
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


# ------------------------------------------------------------------------------------------------
# Contexte d'un rendu (passé à toutes les fonctions d'époque)
# ------------------------------------------------------------------------------------------------
class Ctx:
    """g : accumulateur ; M : matières ; e : époque ; ep : module de l'époque ; side : côté ; B : colonne ; H : tête
    (cotes de la taille + paramètres de canon de l'époque : L, nb, rb, rr) ; T : toutes les cotes de la taille ;
    rt : haut de la couronne dentée ; hab : habillage de l'époque (epoques.HABILLAGE_DEFAUT complété).
    Remplis par tete() avant l'appel de ep.tete : Pf, Nf (paramétrage de la coupole), nac (bx, yb0, yb1, ztop, yc),
    tour (cx, cy, z du dessus du tourelleau)."""

    def __init__(self, g, e, ep, side, hab):
        self.g, self.M, self.e, self.ep, self.side = g, g.M, e, ep, side
        self.T = TAILLES[side]
        self.B = dict(self.T["colonne"])
        self.H = dict(self.T["tete"])
        self.H.update(getattr(ep, "CANON", None) or getattr(ep, "CANON_PAR_COTE", {}).get(side, {}))
        self.rt = self.B["h"] + self.B["rh"]
        self.hab = hab
        self.Pf = self.Nf = self.nac = self.tour = None


# ------------------------------------------------------------------------------------------------
# Socle
# ------------------------------------------------------------------------------------------------
def plateforme(g, c, chanfrein=None, z=0.045):
    """Tablier bas continu de caillebotis (4,5 cm) qui relie TOUS les volumes du socle : aucun jour entre les machines,
    aucune pièce isolée. Octogone chanfreiné (avant : chanfrein ; arrière : 0,8 × chanfrein), rentré sous le contour :
    le contour du bâtiment reste fait des volumes qui le débordent. Lames sur chant au pas de 0,09, cornières
    boulonnées. Reprise de la plage haute de la passe 3 (apron), étendue aux 5 tailles."""
    M = g.M
    P_ = c.T["plateforme"]
    cf = P_["chanfrein"] if chanfrein is None else chanfrein
    cb = cf * 0.8
    side = c.side
    hx = side / 2.0 - P_["retrait"]
    hy = side / 2.0 - P_["retrait"]
    fy = P_["avant"]
    poly = [(-hx + cf, -fy), (hx - cf, -fy), (hx, -fy + cf), (hx, hy - cb), (hx - cb, hy), (-hx + cb, hy),
            (-hx, hy - cb), (-hx, -fy + cf)]
    P = [(x, Y(y)) for x, y in poly]
    n = len(P)
    vs = [(x, y, 0.0) for x, y in P] + [(x, y, z * 0.45) for x, y in P]
    fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, n + j, n + i))
    g._add(M["void"], "flat", vs, fs, "tablier")
    nb = int((2 * hx - 0.1) / 0.09)
    for i in range(nb):
        x = -hx + 0.05 + (i + 0.5) * (2 * hx - 0.1) / nb
        ys = []
        for j in range(n):
            (x0, y0), (x1, y1) = P[j], P[(j + 1) % n]
            if (x0 - x) * (x1 - x) <= 0 and x0 != x1:
                ys.append(y0 + (y1 - y0) * (x - x0) / (x1 - x0))
        if len(ys) < 2:
            continue
        ya, yb = min(ys) + 0.07, max(ys) - 0.07
        if yb > ya:
            g.box((x, (ya + yb) / 2, z * 0.45 + 0.012), (0.03, yb - ya, 0.024), M["grate"], "flat", what="lame")
    for i in range(n):
        p0, p1 = V((P[i][0], P[i][1], 0)), V((P[(i + 1) % n][0], P[(i + 1) % n][1], 0))
        d = p1 - p0
        L = d.length
        if L < 0.05:
            continue
        d.normalize()
        nrm = V((d.y, -d.x, 0))
        R = Matrix((d, V((-d.y, d.x, 0)), V((0, 0, 1)))).transposed()
        g.box((p0 + p1) / 2 - nrm * 0.04 + V((0, 0, z * 0.5)), (L, 0.08, z), M["steel_dk"], "hard", R=R,
              what="corniere")
        k = max(2, int(L / 0.3))
        for j in range(k):
            q = p0 + d * (L * (j + 0.5) / k) - nrm * 0.04 + V((0, 0, z))
            g.bolt(q, (0, 0, 1), 0.016, M["steel_hi"])
    return poly


def dalle(g, x0, x1, y0, y1, z=0.045):
    """Dalle de caillebotis rectangulaire (même facture que la plateforme) : sous une pièce du niveau pair ou une
    machine posée hors de la plateforme, pour qu'aucun jour ne s'enferme entre elle et le socle."""
    M = g.M
    g.box(((x0 + x1) / 2, (y0 + y1) / 2, z * 0.225), (x1 - x0, y1 - y0, z * 0.45), M["void"], "flat", what="dalle")
    nb = max(1, int((x1 - x0 - 0.1) / 0.09))
    for i in range(nb):
        x = x0 + 0.05 + (i + 0.5) * (x1 - x0 - 0.1) / nb
        g.box((x, (y0 + y1) / 2, z * 0.45 + 0.012), (0.03, y1 - y0 - 0.1, 0.024), M["grate"], "flat", what="lame")
    for (a, b, cc, d_) in ((x0, x1, y0, y0 + 0.06), (x0, x1, y1 - 0.06, y1), (x0, x0 + 0.06, y0, y1),
                           (x1 - 0.06, x1, y0, y1)):
        g.box(((a + b) / 2, (cc + d_) / 2, z * 0.5), (b - a, d_ - cc, z), M["steel_dk"], "hard", what="corniere")


def colonne(g, c):
    """Colonne à goussets et couronne d'orientation dentée à bandes de danger (lignée)."""
    M = g.M
    B = c.B
    P2.pedestal(g, B["R"], 0.0, B["h"], B["n"], M, [M["olive"], M["steel_dk"], M["olive"], M["redpaint"]],
                ladder_at=B["echelle"])
    PT.slewing_ring(g, B["R"] - 0.02, B["h"], B["rh"])


def tremie(g, c):
    """Trémie à trappe ouverte au sud (lignée), goulotte vers la couronne. Peinture, pochoirs et munitions visibles :
    habillage de l'époque (c.hab). Renvoie (point de sortie de la bande, boîte de la trémie)."""
    M = g.M
    x0, x1, yn0, y1, h = c.T["tremie"]
    y0 = Y(yn0)
    paint = M[c.hab["tremie"]] if c.hab["tremie"] else None
    mun = c.hab["munitions"]
    out = P3.hopper_top(g, x0, x1, y0, y1, 0.0, h, M, paint=paint, stencils=c.hab["pochoirs"],
                        belt_mats=tuple(M[k] for k in mun) if mun else None)
    if c.T["goulotte"]:
        pts = [tuple(out)] + [tuple(p) for p in c.T["goulotte"]]
    else:
        R = c.B["R"]
        pts = [tuple(out), (0.0, -(R + 0.12), c.rt - 0.02), (0.0, -(R - 0.08), c.rt + 0.02)]
    P2.feed_chute(g, pts, c.T["goulotte_w"], M)
    return out, (x0, x1, y0, y1, h)


def collecteur(g, c, liaison, r=None, z=None, angs=(-0.2, -0.85, -1.57, -2.29, -2.94)):
    """Collecteur qui ceinture le pied de la colonne, côté avant (toujours visible) : « tuyaux et câbles partout »
    (charte §4.2). liaison(g, pts, r) : la liaison de l'époque (fonction de epNN)."""
    B = c.B
    rr = B["R"] + 0.12 + 0.02 * (c.side - 2)
    zz = 0.15 + 0.03 * (c.side - 2) if z is None else z
    liaison(g, [(rr * math.cos(a), rr * math.sin(a), zz) for a in angs], 0.044 + 0.01 * (c.side - 2) if r is None else r)


def socle(g, c):
    """Base du niveau impair : plateforme, colonne, trémie (lignée), puis tout ce que l'époque y pose (ep.socle)."""
    plateforme(g, c, getattr(c.ep, "PLATEFORME", {}).get("chanfrein"))
    colonne(g, c)
    c.tremie_out, c.tremie_box = tremie(g, c)
    c.ep.socle(g, c)


def piece(g, c):
    """Pièce du niveau pair (couche ajoutée au socle, coins avant) : entièrement à l'époque (ep.piece)."""
    c.ep.piece(g, c)


# ------------------------------------------------------------------------------------------------
# Tête (repère de la tête : canons vers +Y)
# ------------------------------------------------------------------------------------------------
def jupe(g, R, z0, z1, mats, nstrips, band_mat):
    """Jupe blindée de la lignée : âme, bandes de blindage verticales rivetées, deux cerclages (habillage d'époque)."""
    M = g.M
    g.cyl((0, 0, (z0 + z1) / 2), "z", R, z1 - z0, M["seam"], n=64, style="smooth", what="ame")
    h = z1 - z0
    w = TAU * R / nstrips
    for k in range(nstrips):
        a = TAU * (k + 0.5) / nstrips
        d = V((math.cos(a), math.sin(a), 0.0))
        t = V((-math.sin(a), math.cos(a), 0.0))
        R3 = Matrix((t, d, V((0, 0, 1)))).transposed()
        m = mats[g.rng.randrange(len(mats))]
        th = 0.034 * (1 + 0.3 * (g.rng.random() - 0.5))
        g.box(d * (R + th / 2 - 0.004) + V((0, 0, z0 + h * 0.5)), (w * 0.9, th, h * 0.76), m, "hard", R=R3,
              what="bande")
        for s in (-1, 1):
            g.dome(d * (R + th) + t * (s * w * 0.34) + V((0, 0, z0 + h * 0.78)), d, 0.018, M["rivet"])
    for zz in (z0 + 0.03, z1 - 0.03):
        g.tube_shell((0, 0, zz), "z", R + 0.05, R - 0.02, 0.06, band_mat, n=64, what="cerclage")


def masque_lignee(g, c, mats=("ochre", "olive"), fentes=((0.0, 1.1),), visiere=("steel_hi", 0.03), coax=None):
    """Masque avant de la lignée entre les deux canons. fentes : (décalage x en part de mw, largeur en part de mw) ;
    visiere : (matière, profondeur) ; coax : None, ou dict(fut=matière, manchon=matière, manchon_y=0.3,
    manchon_r=0.046, manchon_L=0.12, anneau=bool) (mitrailleuse coaxiale sous le masque)."""
    M = g.M
    H = c.H
    R, zs, rz = H["R"], H["zs"], H["rz"]
    mw = R * 0.5
    PT.hull(g, -mw, mw, R * 0.55, R + 0.22, zs - 0.18, zs + rz * 0.5, ins=(0.04, 0.02, R * 0.26), panel=0.22,
            mats=[M[k] for k in mats], rivet_step=0.11)
    for dx, w in fentes:
        g.box((dx * mw, R + 0.235, zs + 0.02), (mw * w, 0.02, 0.04), M["emit"], "flat", what="fente")
    vm, vd = visiere
    g.box((0, R + 0.25 - (vd - 0.03) / 2, zs + 0.065), (mw * 1.3, vd, 0.025), M[vm], "hard", what="visiere")
    if coax:
        g.cyl((mw * 0.45, R + 0.2 + 0.18, zs - 0.06), "y", 0.03, 0.4, M[coax.get("fut", "steel_dk")], n=10, what="coax")
        g.cyl((mw * 0.45, R + 0.2 + coax.get("manchon_y", 0.28), zs - 0.06), "y", coax.get("manchon_r", 0.045),
              coax.get("manchon_L", 0.16), M[coax.get("manchon", "steel_hi")], n=12, what="coax_manchon")
        if coax.get("anneau"):
            F.lit_ring(g, (mw * 0.45, R + 0.2 + 0.365, zs - 0.06), "y", 0.04, M["emit"], w=0.01)


def nacelle_coque(g, c):
    """Nacelle arrière de la lignée : coque rivetée (olive et ocre), face arrière à grille (2×2 à 4×4) ou à deux
    grilles lumineuses (5×5 et 6×6). Renvoie le cadre (bx, yb0, yb1, ztop, yc) et le quadrilatère de la face arrière."""
    M = g.M
    H = c.H
    R, zs, rz = H["R"], H["zs"], H["rz"]
    N_ = c.T["nacelle"]
    bx = R * 0.62
    yb0, yb1 = -R - N_["recul"], -R * 0.5
    zb = zs - N_["bas"]
    T = PT.hull(g, -bx, bx, yb0, yb1, zb, zs + rz * 0.42, ins=(0.03, 0.04, 0.0), panel=0.24,
                mats=[M["olive"], M["ochre"]], rivet_step=0.11)
    back = [V((-bx, yb0, zb)), V((bx, yb0, zb)), T[1], T[0]]
    if c.side >= 5:
        for (s0, s1) in ((0.08, 0.46), (0.54, 0.92)):
            PT.glow_grille(g, PT.lift(PT.face_quad(back, s0, s1, 0.2, 0.8), 0.03), 4, M["emit_soft"])
    else:
        g.grille(PT.lift(PT.face_quad(back, 0.15, 0.85, 0.2, 0.8), 0.01), 4, slat_mat=M[c.hab["grille_nacelle"]])
    ztop = zs + rz * 0.42
    return (bx, yb0, yb1, ztop, (yb0 + yb1) / 2), back


def echappements(g, c):
    """Organe dorsal par défaut de la nacelle : deux échappements (lignée)."""
    bx, yb0, yb1, ztop, yc = c.nac
    re, he = c.T["echap"]
    for sx in (-1, 1):
        PT.exhaust(g, (sx * bx * 0.7, yc - 0.05, ztop), re, he)


def tourelleau(g, c):
    """Tourelleau à périscopes et trappe (lignée). Renvoie (cx, cy, z du dessus)."""
    M = g.M
    H = c.H
    R, zs, rz = H["R"], H["zs"], H["rz"]
    Tt = c.T["tourelleau"]
    cx, cy = -R * 0.32, -R * 0.12
    zc = zs + rz * math.sqrt(max(0.0, 1 - (cx / R) ** 2 - (cy / (R * 1.06)) ** 2)) - 0.03
    hc, rc = Tt["h"], Tt["r"]
    g.cyl((cx, cy, zc + hc / 2), "z", rc, hc, M[c.hab["tourelleau"]], n=24, style="soft", what="tourelleau")
    g.torus((cx, cy, zc + hc), "z", rc - 0.02, 0.016 if c.side <= 4 else 0.018, M["steel_dk"], n=24, m=6, what="jonc")
    nper = Tt["n"]
    for k in range(nper):
        a = math.pi / 2 + (k - (nper - 1) / 2) * Tt["pas"]
        d = V((math.cos(a), math.sin(a), 0))
        Rr = Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()
        g.box(V((cx, cy, zc + hc * 0.6)) + d * rc, Tt["peri"], M["steel_dk"], "hard", R=Rr, what="periscope")
        g.box(V((cx, cy, zc + hc * 0.6)) + d * (rc + Tt["av"]), Tt["lentille"], M["emit"], "flat", R=Rr,
              what="lentille")
    hx, hy = R * 0.34, -R * 0.2
    zh = zs + rz * math.sqrt(max(0.0, 1 - (hx / R) ** 2 - (hy / (R * 1.06)) ** 2)) - 0.02
    PT.hatch(g, (hx, hy, zh), c.T["trappe"])
    return (cx, cy, zc + hc)


def bras(g, c, sx):
    """Bras de tourillon de la lignée (et ses deux berceaux, qui ferment les jours entre l'arme, la nacelle et la
    coupole), tourillon, chapeau boulonné. L'arme de l'époque se pose dessus (ep.arme)."""
    M = g.M
    H = c.H
    x = sx * H["gx"]
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    R = H["R"]
    xa, xb = sorted((sx * R * 0.8, x - sx * wr / 2))
    PT.hull(g, xa, xb, y0 + 0.1, y1 - 0.14, zg - hr * 0.7, zg + hr * 0.55, ins=(0.0, 0.02, 0.02), panel=0.22,
            mats=[M["olive"], M["steel_dk"]], faces="tsn", rivet_step=0.12)
    xc, xd = sorted((sx * R * 0.45, x))
    PT.hull(g, xc, xd, y0 - 0.34, y0 + 0.14, H["zs"] - 0.2, zg - hr * 0.55, ins=(0.02, 0.03, 0.0), panel=0.22,
            mats=[M["steel_dk"], M["olive"]], faces="tsn", rivet_step=0.12)
    xe, xf = sorted((sx * R * 0.55, x))
    PT.hull(g, xe, xf, y1 - 0.2, y1 + 0.2, H["zs"] - 0.12, zg - hr * 0.35, ins=(0.02, 0.0, 0.04), panel=0.22,
            mats=[M["steel_dk"], M["olive"]], faces="tsn", rivet_step=0.12)
    g.cyl(((xa + xb) / 2, (y0 + y1) / 2 - 0.04, zg - hr * 0.1), "x", hr * 0.62, abs(xb - xa) + 0.12, M["steel_dk"],
          n=20, what="tourillon")
    g.cyl((x + sx * (wr / 2 + 0.03), (y0 + y1) / 2 - 0.04, zg - hr * 0.1), "x", hr * 0.5, 0.06, M[c.hab["chapeau"]],
          n=16, style="hard", what="chapeau")
    F.bolts_ring(g, (x + sx * (wr / 2 + 0.062), (y0 + y1) / 2 - 0.04, zg - hr * 0.1), (sx, 0, 0), hr * 0.36, 6,
                 M["rivet"], r=0.015)
    return x


def tete(g, c):
    """Tête de la lignée, puis l'arme et les accents de l'époque."""
    M = g.M
    H = c.H
    R, zs, rz = H["R"], H["zs"], H["rz"]
    z0 = c.rt
    g.cyl((0, 0, z0 + 0.035), "z", R + 0.07, 0.07, M["steel_dk"], n=56, style="soft", what="collier")
    nb = int(TAU * (R + 0.04) / 0.16)
    for k in range(nb):
        a = TAU * k / nb
        g.dome(((R + 0.04) * math.cos(a), (R + 0.04) * math.sin(a), z0 + 0.07), (0, 0, 1), 0.016, M["rivet"])
    jupe(g, R, z0 + 0.07, zs, [M["olive"], M["olive"], M["steel_dk"]],
         max(c.T["jupe_bandes"], int(TAU * R / 0.26)), M[c.hab["jupe_cerclage"]])
    c.Pf, c.Nf = P2.dome_hull(g, (0, 0, zs), R, R * 1.06, rz, M["olive"], M,
                              seams=max(c.T["coupole_coutures"], int(TAU * R / 0.3)), band_mat=M["steel_dk"],
                              ring_seams=c.T["rangs"])
    if hasattr(c.ep, "masque"):
        c.ep.masque(g, c)
    else:
        masque_lignee(g, c)
    c.nac, c.nac_face = nacelle_coque(g, c)
    if hasattr(c.ep, "nacelle"):
        c.ep.nacelle(g, c)
    else:
        echappements(g, c)
    c.tour = tourelleau(g, c)
    for sx in (-1, 1):
        x = bras(g, c, sx)
        c.ep.arme(g, c, x, sx)
    c.ep.tete(g, c)


# ------------------------------------------------------------------------------------------------
# Canon de lignée : rosette, bouche, canon complet corrigé pour la pose N (base des organes d'époque)
# ------------------------------------------------------------------------------------------------
def rosette(g, x, y0, z, L, nb, rb, rr, mat=None, phase=0.3, colliers=(0.8,), collier_mat=None, bouts=True,
            arr="ring", plaque=True, segments=12):
    """Faisceau de tubes de la lignée : tubes séparés, âme centrale pleine (aucun jour au travers), plaque de culasse,
    colliers de maintien boulonnés (on voit les tubes séparés entre l'organe d'époque et la bouche). arr : « ring »
    (faisceau rotatif), « row » (tubes côte à côte à plat), « square » (2 × 2 gros calibre). Renvoie les positions
    (x, z) des tubes. bouts : rosace sombre au bout de chaque tube (False si un frein la porte)."""
    M = g.M
    mat = mat or M["gun"]
    pos = []
    if arr == "row":
        pitch = rb * 2.25
        for i in range(nb):
            pos.append((x + (i - (nb - 1) / 2) * pitch, z))
    elif arr == "square":
        for i in range(nb):
            a = math.pi / 4 + TAU * i / nb
            pos.append((x + rr * math.cos(a), z + rr * math.sin(a)))
    else:
        for i in range(nb):
            a = phase + TAU * i / nb
            pos.append((x + rr * math.cos(a), z + rr * math.sin(a)))
    for bx, bz in pos:
        g.cyl((bx, y0 + L / 2, bz), "y", rb, L, mat, n=segments, what="canon")
        if bouts:
            g.cyl((bx, y0 + L + 0.002, bz), "y", rb * 0.62, 0.008, M["void"], n=10, style="flat", what="bouche")
    cm = collier_mat or M["steel_dk"]
    if arr == "row":
        w = (nb - 1) * rb * 2.25
        g.box((x, y0 + L * 0.48, z - rb * 0.3), (w, L * 0.94, rb * 0.9), M["steel_dk"], "hard", what="ame")
        if plaque:
            g.box((x, y0 + 0.02, z), (w + 2 * rb + 0.03, 0.04, 2 * rb + 0.03), M["steel_dk"], "soft",
                  what="plaque_culasse")
        for f in colliers:
            yy = y0 + f * L
            g.box((x, yy, z), (w + 2 * rb + 0.03, 0.035, 2 * rb + 0.026), cm, "hard", what="collier")
            for s in (-1, 1):
                g.bolt((x + s * (w / 2 + rb * 0.4), yy, z + rb + 0.013), (0, 0, 1), 0.012, M["steel_hi"])
        return pos
    core = max(rr - rb * 0.55, rr * 0.55)
    g.cyl((x, y0 + L * 0.5, z), "y", core, L * 0.96, M["steel_dk"], n=14, what="ame")
    if plaque:
        g.cyl((x, y0 + 0.02, z), "y", rr + rb + 0.01, 0.04, M["steel_dk"], n=24, style="soft", what="plaque_culasse")
    for f in colliers:
        yy = y0 + f * L
        g.tube_shell((x, yy, z), "y", rr + rb + 0.016, core * 0.8, 0.035, cm, n=28, what="collier")
        F.bolts_ring(g, (x, yy, z), (0, 1, 0), rr + rb + 0.016, 6, M["rivet"], r=0.014, phase=0.5, skip_down=-0.3)
    return pos


def bouche(g, x, y, z, pos, rb, rim_mat, r_lum, w=0.026):
    """Bouche lisible (règle d'or 7) : rosace des bouts de tubes sombres cerclés, pourtour éclairé fin (couleur de
    l'époque, < 0,03 t²) de rayon r_lum."""
    F.bores(g, x, y, z, pos, rb, rim_mat)
    F.lit_ring(g, (x, y + 0.002, z), "y", r_lum, g.M["emit"], w=w)


def canon_lignee(g, c, x, sx, recv_mats=("ochre", "olive"), jaquette=0.42, frein=True, frein_mat="steel",
                 bague_mat="steel_dk", masque_mats=("ochre", "olive"), alim=True):
    """Canon de lignée COMPLET, corrigé pour la pose N (règle d'or 7) : culasse blindée, moteur arrière bobiné,
    rosette, jaquette perforée sur la moitié arrière au plus, frein de bouche EN BLOC près de deux fois plus large que
    le faisceau, à évents latéraux et ouïes éclairées sur le dessus (en pose N, le bout du canon fait un « T » plat,
    jamais un chapeau de cheminée : vérifié sur le témoin k3 et k5 le 23/10), rosace éclairée en face avant,
    bagues sombres (aucune bague claire horizontale), caisse d'alimentation au pied qui déborde sur le côté extérieur,
    masque de canon. Une époque peut l'appeler tel quel et y AJOUTER son organe, ou s'en inspirer."""
    M = g.M
    H = c.H
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    L, nb, rb, rr = H["L"], H["nb"], H["rb"], H["rr"]
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=[M[k] for k in recv_mats])
    moteur_lignee(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6)
    pos = rosette(g, x, y1, zg, L, nb, rb, rr, colliers=(0.62, 0.86), collier_mat=M[bague_mat], bouts=not frein)
    # âme prolongée jusque dans le frein : sinon le sol se voit entre les tubes juste derrière la collerette (trou
    # enfermé de 9 à 10 px hr en pose N, témoins k4 et k6 du 23/10)
    g.cyl((x, y1 + L * 0.99, zg), "y", max(rr - rb * 0.55, rr * 0.55), L * 0.04 + 0.03, M["steel_dk"], n=14,
          what="ame_bout")
    rs = rr + rb + 0.028
    Lj = L * min(jaquette, JAQUETTE_MAX)
    if Lj > 0.05:
        g.cyl((x, y1 + Lj / 2, zg), "y", rs, Lj, M["steel"], n=28, style="smooth", what="jaquette")
        nh_ax = max(2, int((Lj - 0.1) / 0.06))
        nh_ang = max(8, int(TAU * rs / 0.07))
        for i in range(nh_ax):
            for j in range(nh_ang):
                a = TAU * j / nh_ang + (0.5 * TAU / nh_ang if i % 2 else 0.0)
                d = V((math.cos(a), 0.0, math.sin(a)))
                if d.z < -0.45:
                    continue
                p = V((x, y1 + 0.07 + (Lj - 0.14) * (i + 0.5) / nh_ax, zg)) + d * (rs + 0.002)
                g.cyl(p, d, 0.016, 0.006, M["void"], n=6, style="flat", what="trou")
        for yy in (y1 + 0.03, y1 + Lj - 0.02):
            g.tube_shell((x, yy, zg), "y", rs + 0.022, rs - 0.01, 0.05, M[bague_mat], n=28, what="bague")
            F.bolts_ring(g, (x, yy, zg), (0, 1, 0), rs + 0.024, 6, M["rivet"], r=0.015, phase=0.2, skip_down=-0.3)
    yb = y1 + L
    if frein:
        # frein de bouche en BLOC rectangulaire, près de deux fois plus large que le faisceau : vu de dessus (pose N),
        # le bout du canon fait un « T » plat, jamais le chapeau rond d'une cheminée ; évents latéraux sombres, ouïes
        # sur le dessus avec une lueur de bouche (petit foyer, < 0,03 t²), collerette sombre, rosace éclairée devant
        Lb = 0.1 + 0.05 * L
        wb = 2 * rs * 1.9
        hb = 2 * (rr + rb) + 0.06   # plus haut que le faisceau : ni bout de tube ni anneau ne dépasse (aucune boucle)
        g.box((x, yb + Lb / 2, zg), (wb, Lb, hb), M[frein_mat], "hard", what="frein")
        for s in (-1, 1):
            for k in range(2):
                g.box((x + s * (wb / 2 + 0.002), yb + Lb * (0.3 + 0.4 * k), zg), (0.006, Lb * 0.22, hb * 0.6),
                      M["void"], "flat", what="event")
        for k in range(2):
            yy = yb + Lb * (0.3 + 0.4 * k)
            g.box((x, yy, zg + hb / 2 + 0.002), (wb * 0.7, Lb * 0.14, 0.006), M["void"], "flat", what="ouie")
            g.box((x, yy, zg + hb / 2 + 0.005), (wb * 0.45, Lb * 0.06, 0.004), M["emit"], "flat", what="ouie_lum")
        g.box((x, yb - 0.01, zg), (wb * 0.9, 0.025, hb * 0.9), M[bague_mat], "hard", what="collerette")
        for s in (-1, 1):
            g.dome((x + s * wb * 0.38, yb + Lb * 0.5, zg + hb / 2 + 0.002), (0, 0, 1), 0.016, M["rivet"])
        bouche(g, x, yb + Lb + 0.002, zg, pos, rb, M[bague_mat], min(rs, hb / 2 - 0.02))
    else:
        F.lit_ring(g, (x, yb + 0.004, zg), "y", rr + rb + 0.004, M["emit"], w=0.02)
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M[k] for k in masque_mats], rivet_step=0.11)
    if alim:
        # caisse d'alimentation au pied du canon, côté extérieur : elle déborde du faisceau (pose N : pas de fût lisse)
        xo = x + sx * (wr / 2 + 0.05)
        bw, bl, bh = 0.32 * wr / 0.4, 0.75 * L / 1.95, 0.5 * hr / 0.23
        bx0, bx1 = sorted((xo + sx * 0.02, xo + sx * (0.02 + bw)))
        PT.hull(g, bx0, bx1, y0 - 0.1, y0 - 0.1 + bl, zg - bh * 0.62, zg + bh * 0.42, ins=(0.015, 0.015, 0.015),
                panel=0.24, mats=[M["olive"], M["ochre"]], rivet_step=0.11)
        bc = (bx0 + bx1) / 2
        # voile plein entre la culasse et la caisse, sous la goulotte (l'arche enfermait un jour : 9 px hr, témoin k4)
        xa_, xb_ = sorted((x + sx * wr / 2 - sx * 0.01, xo + sx * 0.03))
        g.box(((xa_ + xb_) / 2, y0 + bl * 0.45, zg + hr * 0.05), (xb_ - xa_, bl * 0.5, hr * 1.1), M["steel_dk"], "hard",
              what="voile")
        P2.feed_chute(g, [(bc, y0 - 0.1 + bl * 0.6, zg + bh * 0.42 + 0.02), (bc - sx * 0.05, y0 + bl * 0.55, zg + bh * 0.62),
                          (x + sx * wr * 0.2, y0 + bl * 0.5, zg + hr + 0.06)], 0.12 * wr / 0.4 + 0.04, M)
    return pos


def moteur_lignee(g, c, r, L, corps="steel_dk", flasque="olive", moyeu="brass"):
    """Moteur d'entraînement bobiné de la lignée : carter à ailettes, bobinage de cuivre apparent, flasque boulonnée."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z), "y", r, L, M[corps], n=28, style="soft", what="moteur")
    nf = int((L * 0.5) / 0.04)
    for k in range(nf):
        g.tube_shell((x, y - L / 2 + 0.04 + k * 0.04, z), "y", r + 0.03, r - 0.01, 0.016, M["steel_hi"], n=28,
                     what="ailette")
    for k in range(4):
        g.torus((x, y + L / 2 - 0.05 - k * 0.034, z), "y", r + 0.006, 0.017, M["copper"], n=28, m=6, what="bobinage")
    g.cyl((x, y - L / 2 - 0.03, z), "y", r * 0.85, 0.06, M[flasque], n=24, style="soft", what="flasque")
    for k in range(8):
        a = TAU * k / 8
        d = V((math.cos(a), 0, math.sin(a)))
        g.dome(V((x, y - L / 2 - 0.06, z)) + d * r * 0.66, V((0, -1, 0)), 0.016, M["rivet"])
    g.cyl((x, y - L / 2 - 0.08, z), "y", r * 0.3, 0.05, M[moyeu], n=12, what="moyeu")
