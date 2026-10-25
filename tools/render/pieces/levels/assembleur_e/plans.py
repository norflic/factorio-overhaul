"""PLANS DE LA LIGNÉE de l'assembleur (ronde F3-A2, 25/10). S'exécute DANS Blender.

Verdict du DC (25/10 vers 12 h 50, R-QCM-25f) : « certains ont juste une plateforme et un truc posé dessus, ça fait pas
précis, pas détaillé et aussi ils sont tous carré, mais peut être qu'on peut aussi en faire des circulaires ». Réponse :
la clé d'habillage « plan » choisit le CORPS de la machine, où l'outil de l'âge s'intègre :
  carre     atelier carré (bâti, dos, joues : rondes 1 à 4) ;
  L         dos au nord et AILE haute à l'ouest (plan en L), joue est basse ;
  portique  deux PYLÔNES pleine hauteur et un PONT-CAISSON ; l'outil pend du pont ;
  tour      socle rond bas et TOUR centrale (fût, galerie, quatre contreforts) ; l'outil s'enroule autour ;
  rond      TAMBOUR rond, CROISSANT haut sur la moitié nord, RAYONS du croissant à un moyeu au-dessus du centre ;
  octo      la même chose à huit pans.
Chaque plan remplit dans le contexte c : c.cx, c.cy (centre de l'organe), c.zt (dessus du lit de travail), c.hub (point
d'accroche de l'outil, Blender), c.zones (surfaces que la garniture dense remplit), c.reserves (cercles interdits à la
garniture), c.pl_entree, c.pl_sortie (places d'entrée et de sortie : x, yn, z, r), c.coins (places de la pièce paire),
c.faces (faces sud décorables : x0, x1, yn, z0, z1).
"""
import math

from mathutils import Matrix, Vector

import parts as PT
from habillage import _lignee
from kit import SQ2, TAU
from pont import _motif, _prisme

V = Vector


def B(x, yn, z=0.0):
    return V((x, yn * SQ2, z))


def poly_b(pts):
    return [(x, yn * SQ2) for x, yn in pts]


def contour(R, n, cy=0.0, phase=None):
    """Contour (jeu) d'un cercle (n grand) ou d'un polygone régulier de rayon R centré en (0, cy)."""
    ph = (math.pi / n) if phase is None else phase
    return [(R * math.cos(ph + TAU * i / n), cy + R * math.sin(ph + TAU * i / n)) for i in range(n)]


def flancs_sud(g, pts, z0, z1, m, rivets=True):
    """Plaques des flancs sud-visibles d'un contour direct (jeu)."""
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L < 0.04 or dx <= 0.0:
            continue
        q = [B(a[0], a[1], z0), B(b[0], b[1], z0), B(b[0], b[1], z1), B(a[0], a[1], z1)]
        g.panels(q, max(1, int(round(L / 0.4))), max(1, int(round((z1 - z0) / 0.4))), m, t=0.016,
                 rivet_mat=g.M["rivet"] if rivets else None, rivet_step=0.15)


def secteur(g, R0, R1, a0, a1, z0, z1, m, cy=0.0, n=16, what="secteur"):
    """Secteur d'anneau plein (jeu : rayons R0 < R1, angles a0 < a1 en radians, 0 = est, π/2 = nord), de z0 à z1."""
    for i in range(n):
        t0, t1 = a0 + (a1 - a0) * i / n, a0 + (a1 - a0) * (i + 1) / n
        p = [(R1 * math.cos(t0), cy + R1 * math.sin(t0)), (R1 * math.cos(t1), cy + R1 * math.sin(t1)),
             (R0 * math.cos(t1), cy + R0 * math.sin(t1)), (R0 * math.cos(t0), cy + R0 * math.sin(t0))]
        pts8 = [B(x, y, z0) for x, y in p] + [B(x, y, z1) for x, y in p]
        g.hexa(pts8, m, "hard", what)


def face_exterieure(g, R, a0, a1, z0, z1, m, cy=0.0, n=12, rivets=True):
    """Plaques de la face EXTÉRIEURE (convexe) d'un secteur, sur sa partie sud."""
    for i in range(n):
        t0, t1 = a0 + (a1 - a0) * i / n, a0 + (a1 - a0) * (i + 1) / n
        if math.sin((t0 + t1) / 2) > -0.1:
            continue
        pa = (R * math.cos(t0), cy + R * math.sin(t0))
        pb = (R * math.cos(t1), cy + R * math.sin(t1))
        q = [B(pa[0], pa[1] - 0.004, z0), B(pb[0], pb[1] - 0.004, z0), B(pb[0], pb[1] - 0.004, z1),
             B(pa[0], pa[1] - 0.004, z1)]
        g.panels(q, 1, max(1, int(round((z1 - z0) / 0.35))), m, t=0.014, rivet_mat=g.M["rivet"] if rivets else None,
                 rivet_step=0.13)


def face_interieure(g, R0, a0, a1, z0, z1, m, cy=0.0, n=12, rivets=True):
    """Plaques de la face INTÉRIEURE (concave, tournée vers le centre) d'un croissant : visibles quand elles regardent
    le sud (moitié nord du cercle)."""
    for i in range(n):
        t0, t1 = a0 + (a1 - a0) * i / n, a0 + (a1 - a0) * (i + 1) / n
        pa = (R0 * math.cos(t1), cy + R0 * math.sin(t1))
        pb = (R0 * math.cos(t0), cy + R0 * math.sin(t0))
        q = [B(pa[0], pa[1] - 0.004, z0), B(pb[0], pb[1] - 0.004, z0), B(pb[0], pb[1] - 0.004, z1),
             B(pa[0], pa[1] - 0.004, z1)]
        g.panels(q, 1, max(1, int(round((z1 - z0) / 0.35))), m, t=0.016, rivet_mat=g.M["rivet"] if rivets else None,
                 rivet_step=0.14)


# ------------------------------------------------------------------------------------------------
# Cotes par plan (complètent cotes.TAILLES)
# ------------------------------------------------------------------------------------------------
LIGNEE = ("carre", "L", "portique", "croix", "H")      # plans bâtis avec le dos, les joues, le bâti et la table


def etendues(c):
    """Ronde F3-A3 (verdict du DC, 25/10 vers 15 h 20 : « DÉCOUPER les embases pour que le sol se voie ») : emprises du
    corps de lignée par plan, en tuiles de jeu. Parties CONVEXES de l'embase c.emb_parts [(x0, x1, y0, y1)] (le motif du
    pont ne découpe que des polygones convexes) ; dos c.dos_ext (x0, x1, y0, y1) ou None ; joues c.joue_ext[sx] ou None ;
    bâti c.bati_parts (vide : la baie est le SOL) ; pied de la table c.z_table0.
      L        coin NORD-EST vide (derrière la table, côté est) : sol entre l'aile et le dos ;
      portique plan en U : deux semelles sous les pylônes et le dos bas ; la baie est le sol, la table un socle posé dessus ;
      croix    croix grecque de bras c.a : le dos au nord, les joues à l'est et à l'ouest, le bâti au centre et au sud ;
               table au centre (yt = 0) ; quatre coins de sol (la pièce paire s'y pose) ;
      H        deux AILES pleine profondeur (les joues) reliées par le bâti au milieu ; sol devant et derrière ; pas de dos.
    """
    s, h = c.side, c.h
    tx, ty = c.T["table"]["tx"], c.T["table"]["ty"]
    e = 0.02
    c.decoupe = None
    if c.plan == "croix":
        a = 0.3 * s
        c.a = a
        c.xb, c.yb, c.yf, c.wj, c.dd = a, a, -a, h - a, h - a
        c.yt = 0.0
        c.xm = (a + h) / 2.0
    elif c.plan == "H":
        wW = 0.24 * s
        c.bH = 0.24 * s
        c.xb, c.wj = h - wW, wW
        c.yf, c.yb = -h + e, h - e
        c.yt = 0.0
        c.xm = h - wW / 2.0
    yb, yf, xb = c.yb, c.yf, c.xb
    c.dos_ext = (-h + e, h - e, yb, h - e)
    c.joue_ext = {-1: (-h + e, -xb, yf, yb), 1: (xb, h - e, yf, yb)}
    c.bati_parts = [(-xb - 0.01, xb + 0.01, -h + e, yb + 0.01)]
    c.emb_parts = [(-h, h, -h, h)]
    c.z_table0 = c.zs
    if c.plan == "L":
        # coin vide : tout le quart nord-est derrière la table (essai : au ras de la table, le coin ne faisait que 10 %
        # de l'emprise ; ici 16 à 17 %, le dos ne couvre plus que la moitié ouest)
        Lx = 0.06 * s + 0.12
        Ly = c.yt + ty + 0.08
        c.Lx, c.Ly = Lx, Ly
        c.emb_parts = [(-h, h, -h, Ly), (-h, Lx, Ly, h)]
        c.dos_ext = (-h + e, Lx, yb, h - e)
        c.joue_ext[1] = (xb, h - e, yf, Ly)
        if Lx < xb:
            c.bati_parts = [(-xb - 0.01, xb + 0.01, -h + e, Ly), (-xb - 0.01, Lx, Ly, yb + 0.01)]
        c.decoupe = (Lx, h, Ly, h)
    elif c.plan == "portique":
        c.emb_parts = [(-h, -xb, -h, h), (xb, h, -h, h), (-xb, xb, yb, h)]
        c.bati_parts = []
        c.z_table0 = 0.0
    elif c.plan == "croix":
        a = c.a
        c.emb_parts = [(-a, a, -h, h), (-h, -a, -a, a), (a, h, -a, a)]
        c.dos_ext = (-a + e, a - e, a, h - e)
        c.joue_ext = {-1: (-h + e, -a, -a + e, a - e), 1: (a, h - e, -a + e, a - e)}
        c.bati_parts = [(-a + e, a - e, -h + e, a + 0.01)]
    elif c.plan == "H":
        c.emb_parts = [(-h, -xb, -h, h), (xb, h, -h, h), (-xb, xb, -c.bH, c.bH)]
        c.dos_ext = None
        c.bati_parts = [(-xb - 0.01, xb + 0.01, -c.bH + e, c.bH - e)]
    c.emb_poly = contour_parts(c.emb_parts)


def contour_parts(parts):
    """Contour direct (sens trigonométrique, jeu) de l'union de rectangles alignés qui se touchent (L, U, croix, H) :
    marche le long des bords de la grille des abscisses et ordonnées des rectangles."""
    xs = sorted(set([p[0] for p in parts] + [p[1] for p in parts]))
    ys = sorted(set([p[2] for p in parts] + [p[3] for p in parts]))

    def dedans(x, y):
        return any(p[0] - 1e-6 <= x <= p[1] + 1e-6 and p[2] - 1e-6 <= y <= p[3] + 1e-6 for p in parts)
    # cellules pleines de la grille
    nx, ny = len(xs) - 1, len(ys) - 1
    plein = [[dedans((xs[i] + xs[i + 1]) / 2, (ys[j] + ys[j + 1]) / 2) for j in range(ny)] for i in range(nx)]

    def cel(i, j):
        return 0 <= i < nx and 0 <= j < ny and plein[i][j]
    # arêtes orientées du bord (intérieur à gauche), sur les sommets de la grille (i, j)
    succ = {}
    for i in range(nx):
        for j in range(ny):
            if not plein[i][j]:
                continue
            if not cel(i, j - 1):
                succ[(i, j)] = (i + 1, j)
            if not cel(i + 1, j):
                succ[(i + 1, j)] = (i + 1, j + 1)
            if not cel(i, j + 1):
                succ[(i + 1, j + 1)] = (i, j + 1)
            if not cel(i - 1, j):
                succ[(i, j + 1)] = (i, j)
    depart = min(succ)
    pts, p = [], depart
    while True:
        pts.append(p)
        p = succ[p]
        if p == depart:
            break
    # sommets alignés retirés
    out = []
    n = len(pts)
    for k in range(n):
        a, b, d = pts[k - 1], pts[k], pts[(k + 1) % n]
        if (b[0] - a[0]) * (d[1] - b[1]) - (b[1] - a[1]) * (d[0] - b[0]) != 0:
            out.append((xs[b[0]], ys[b[1]]))
    return out


def init(c):
    s, h = c.side, c.h
    c.zones, c.reserves, c.faces = [], [], []
    c.cx, c.cy = 0.0, c.yt
    c.hub = None
    tx = c.T["table"]["tx"]
    if c.plan in LIGNEE:
        etendues(c)
        c.cy = c.yt
        c.reserves.append((0.0, c.yt, tx * 1.05))
        if c.plan == "portique":
            c.wp = 0.14 * s + 0.06
            c.dp = 0.2 * s
            c.xp = h - c.wp / 2.0
            c.hb = 0.2 + 0.05 * s
            c.ztop = c.zp + c.hb
            c.hub = B(0.0, c.yt, c.zp)
        return
    # plans radiaux : tambour (rond, octo) ou socle et tour. Correction F3-A2 après l'essai a2q (âges 5 et 8 lus « une
    # plate-forme ronde et un truc posé dessus ») : tambour plus HAUT, croissant plus épais et plus haut, ANNEAU AVANT
    # (parapet) qui ferme la cuve ; tour : socle plus haut et deux annexes aux coins arrière.
    if c.plan in ("rond", "octo"):
        c.zr = c.ze + 0.3 + 0.1 * s                # dessus du tambour
        c.zt = c.zr + 0.06 + 0.02 * s              # dessus du lit de travail
        c.Rb = h - 0.04
        c.npans = 40 if c.plan == "rond" else 8
        c.cy = -0.06 * s
        c.ep_cr = 0.24 * s                         # épaisseur du croissant
        c.Hc = c.zr + 0.35 + 0.1 * s               # dessus du croissant
        c.ep_an = 0.1 * s                          # épaisseur de l'anneau avant
        c.Ha = c.zr + 0.12 + 0.03 * s              # dessus de l'anneau avant
        c.zhub = c.Hc + 0.15 + 0.05 * s
        c.hub = B(0.0, c.cy, c.zhub)
        c.tr = 0.15 * s + 0.05
        c.reserves.append((0.0, c.cy, c.tr * 1.05))
        Rd = c.Rb - 0.06
        R0 = Rd - c.ep_cr
        c.zones.append(("anneau", Rd - c.ep_an + 0.05, Rd - 0.05, math.radians(196), math.radians(344), c.Ha, 0.0))
        c.zones.append(("anneau", R0 + 0.05, Rd - 0.06, math.radians(16), math.radians(164), c.Hc, 0.0))
        c.zones.append(("anneau", c.tr + 0.1, Rd - c.ep_an - 0.05, math.radians(200), math.radians(340), c.zr, 0.0))
        rr = 0.06 * s + 0.06
        Rm = Rd - c.ep_an / 2.0
        for nom, ad in (("pl_entree", 205.0), ("pl_sortie", 335.0)):
            a = math.radians(ad)
            setattr(c, nom, dict(x=Rm * math.cos(a), yn=Rm * math.sin(a), z=c.Ha, r=rr))
    else:   # tour
        c.zr = c.ze + 0.25 + 0.08 * s              # dessus du socle
        c.zt = c.zr + 0.06 + 0.02 * s
        c.Rp = 0.4 * s
        c.Rt = 0.12 * s + 0.06
        c.Ht = c.Hd + 0.12 * s
        c.cy = 0.0
        c.yt = -(c.Rt + 0.1 * s)
        c.hub = B(0.0, 0.0, c.Ht)
        c.reserves.append((0.0, c.yt, 0.1 * s + 0.08))
        c.zones.append(("anneau", c.Rt + 0.14, c.Rp - 0.06, math.radians(15), math.radians(165), c.zr, 0.0))
        c.zones.append(("anneau", c.Rt * 0.75 + 0.12, c.Rp - 0.06, math.radians(195), math.radians(345), c.zr, 0.0))
        c.ann = 0.3 * s                            # côté des annexes des coins arrière
        c.Hann = c.zr + 0.15 + 0.08 * s
        for sx in (-1, 1):
            xa = sx * (h - c.ann / 2.0)
            ya = h - c.ann / 2.0
            c.zones.append(("rect", xa - c.ann / 2 + 0.06, xa + c.ann / 2 - 0.06, ya - c.ann / 2 + 0.06,
                            ya + c.ann / 2 - 0.06, c.Hann))
        rr = 0.05 * s + 0.07
        xe = min(h - rr - 0.03, c.Rp * 0.8 + rr)
        c.pl_entree = dict(x=-xe, yn=-0.2 * s, z=c.ze, r=rr)
        c.pl_sortie = dict(x=xe, yn=-0.2 * s, z=c.ze, r=rr)
    for p in (c.pl_entree, c.pl_sortie):
        c.reserves.append((p["x"], p["yn"], p["r"] + 0.05))


# ------------------------------------------------------------------------------------------------
# Corps des plans radiaux
# ------------------------------------------------------------------------------------------------
@_lignee
def tambour(g, c):
    """Plans rond et octo : tambour (dessus au pont de l'âge), croissant haut sur la moitié nord, lit de travail rond,
    rayons du croissant au moyeu."""
    M = g.M
    m1, m2 = c.Mh["olive"], c.Mh["ochre"]
    cfg = c.pont
    Rd = c.Rb - 0.06
    pts = contour(Rd, c.npans, 0.0, phase=(math.pi / 8 if c.plan == "octo" else None))
    fond = M[cfg["fond"]] if cfg["fond"] in M else M["seam"]
    _prisme(g, poly_b(pts), c.ze, c.zr, fond, "hard", "tambour")
    flancs_sud(g, pts, c.ze, c.zr, m1)
    _motif(g, M, dict(cfg, mat2=None), poly_b(pts), c.zr, 0.05, 1300 + c.e)
    n = len(pts)
    bord = M[cfg["bord"]] if cfg["bord"] in M else M["steel_dk"]
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        d = (B(*b) - B(*a))
        L = d.length
        R = Matrix((d.normalized(), V((-d.y, d.x, 0)).normalized(), V((0, 0, 1)))).transposed()
        g.box((B(*a) + B(*b)) / 2 + V((0, 0, c.zr + 0.02)), (L + 0.04, 0.05, 0.04), bord, "hard", R=R, what="corniere")
    # croissant : moitié nord, de 12° à 168°
    R1, R0 = Rd, Rd - c.ep_cr
    a0, a1 = math.radians(12), math.radians(168)
    nn = 14 if c.plan == "rond" else 4
    if c.plan == "octo":
        # quatre pans nord du polygone : secteur à pans droits
        for k in range(4):
            t0 = math.pi / 8 + k * math.pi / 4
            t1 = t0 + math.pi / 4
            p = [(R1 * math.cos(t0), R1 * math.sin(t0)), (R1 * math.cos(t1), R1 * math.sin(t1)),
                 (R0 * math.cos(t1), R0 * math.sin(t1)), (R0 * math.cos(t0), R0 * math.sin(t0))]
            g.hexa([B(x, y, c.zr) for x, y in p] + [B(x, y, c.Hc) for x, y in p], m1, "hard", "croissant")
            qa, qb = p[2], p[3]
            q = [B(qa[0], qa[1] - 0.004, c.zr), B(qb[0], qb[1] - 0.004, c.zr), B(qb[0], qb[1] - 0.004, c.Hc),
                 B(qa[0], qa[1] - 0.004, c.Hc)]
            g.panels(q, 2, max(1, int(round((c.Hc - c.zr) / 0.35))), m2, t=0.016, rivet_mat=M["rivet"],
                     rivet_step=0.14)
        c.a_cr = (math.pi / 8, math.pi * 7 / 8)
    else:
        secteur(g, R0, R1, a0, a1, c.zr, c.Hc, m1, 0.0, n=nn, what="croissant")
        face_interieure(g, R0, a0, a1, c.zr, c.Hc, m2, 0.0, n=nn)
        c.a_cr = (a0, a1)
    # couronne du croissant (cornière haute) et bouts du croissant
    for t in (c.a_cr[0], c.a_cr[1]):
        Rm = (R0 + R1) / 2.0
        g.box(B(Rm * math.cos(t), Rm * math.sin(t), c.Hc + 0.04), (0.16, 0.16 * SQ2, 0.08), M["steel_dk"], "hard",
              what="tete_croissant")
    # ANNEAU AVANT (parapet qui ferme la cuve au sud), face extérieure à plaques, voyants
    Ra = Rd - c.ep_an
    if c.plan == "octo":
        for k in range(4):
            t0 = math.pi + math.pi / 8 + k * math.pi / 4
            t1 = t0 + math.pi / 4
            p = [(Rd * math.cos(t0), Rd * math.sin(t0)), (Rd * math.cos(t1), Rd * math.sin(t1)),
                 (Ra * math.cos(t1), Ra * math.sin(t1)), (Ra * math.cos(t0), Ra * math.sin(t0))]
            g.hexa([B(x, y, c.zr) for x, y in p] + [B(x, y, c.Ha) for x, y in p], m2, "hard", "anneau_avant")
            q = [B(p[0][0], p[0][1] - 0.004, c.zr), B(p[1][0], p[1][1] - 0.004, c.zr), B(p[1][0], p[1][1] - 0.004, c.Ha),
                 B(p[0][0], p[0][1] - 0.004, c.Ha)]
            g.panels(q, 2, 1, m1, t=0.014, rivet_mat=M["rivet"], rivet_step=0.13)
    else:
        a0r, a1r = math.radians(192), math.radians(348)
        secteur(g, Ra, Rd, a0r, a1r, c.zr, c.Ha, m2, 0.0, n=14, what="anneau_avant")
        face_exterieure(g, Rd, a0r, a1r, c.zr, c.Ha, m1, n=14)
    for k in range(6):
        t = math.radians(210 + 24 * k)
        g.cyl(B((Rd + 0.01) * math.cos(t), (Rd + 0.01) * math.sin(t), (c.zr + c.Ha) / 2), "y", 0.028, 0.03, M["emit"],
              n=10, what="voyant_anneau")
    # lit de travail rond au centre
    g.cyl(B(0, c.cy, (c.zr + c.zt) / 2), "z", c.tr, c.zt - c.zr, M["steel_dk"], n=36, style="hard", what="lit")
    g.tube_shell(B(0, c.cy, c.zt - 0.01), "z", c.tr + 0.02, c.tr - 0.06, 0.03, M["steel"], n=36, what="jante_lit")
    for k in range(12):
        a = TAU * k / 12
        g.dome(V((c.tr * 0.85 * math.cos(a), B(0, c.cy).y + c.tr * 0.85 * math.sin(a), c.zt + 0.012)), (0, 0, 1),
               0.016, M["rivet"])


@_lignee
def rayons(g, c, angles=(50, 90, 130), mat=None):
    """Rayons-caissons du croissant au moyeu (au-dessus du centre) : l'outil y est accroché."""
    M = g.M
    m = mat or c.Mh["steel_dk"]
    R0 = c.Rb - 0.06 - c.ep_cr
    hub = c.hub
    for ad in angles:
        t = math.radians(ad)
        p0 = B((R0 + 0.06) * math.cos(t), (R0 + 0.06) * math.sin(t), c.Hc + 0.04)
        g.tube([p0, p0.lerp(hub, 0.5) + V((0, 0, 0.12)), hub], 0.045 + 0.006 * c.side, m, n=6, what="rayon")
    g.cyl(hub, "z", 0.13 + 0.02 * c.side, 0.12, m, n=20, style="hard", what="moyeu")
    g.tube_shell(hub - V((0, 0, 0.07)), "z", 0.15 + 0.02 * c.side, 0.1 + 0.02 * c.side, 0.03, M["steel"], n=20,
                 what="bague_moyeu")


@_lignee
def tour(g, c):
    """Plan tour : socle rond bas au pont de l'âge, fût central, galerie, quatre contreforts."""
    M = g.M
    m1, m2 = c.Mh["olive"], c.Mh["ochre"]
    cfg = c.pont
    pts = contour(c.Rp, 24, 0.0)
    fond = M[cfg["fond"]] if cfg["fond"] in M else M["seam"]
    _prisme(g, poly_b(pts), c.ze, c.zr, fond, "hard", "socle_tour")
    flancs_sud(g, pts, c.ze, c.zr, m1)
    _motif(g, M, dict(cfg, mat2=None), poly_b(pts), c.zr, 0.05, 1400 + c.e)
    # fût : vrai cylindre (rond dans Blender, comme les cuves et les fûts du kit), virole à plaques sur la moitié sud
    zb, zh = c.zr, c.Ht
    Rt = c.Rt
    g.cyl(V((0, 0, (zb + zh) / 2)), "z", Rt - 0.004, zh - zb, M["seam"], n=32, what="fut")
    n = 20
    for k in range(n):
        t0, t1 = TAU * k / n, TAU * (k + 1) / n
        if math.sin((t0 + t1) / 2) > 0.3:
            continue
        q = [V((Rt * math.cos(t0), Rt * math.sin(t0), zb)), V((Rt * math.cos(t1), Rt * math.sin(t1), zb)),
             V((Rt * math.cos(t1), Rt * math.sin(t1), zh)), V((Rt * math.cos(t0), Rt * math.sin(t0), zh))]
        g.panels(q, 1, max(1, int((zh - zb) / 0.35)), m1 if k % 3 else m2, t=0.014, rivet_mat=M["rivet"],
                 rivet_step=0.14)
    g.cyl(V((0, 0, zh + 0.03)), "z", Rt * 1.1, 0.06, M["steel_dk"], n=32, style="hard", what="chapiteau")
    # galerie à mi-hauteur : plancher annulaire, poteaux, lisse
    zg = zb + 0.55 * (zh - zb)
    c.zg = zg
    g.tube_shell(V((0, 0, zg + 0.015)), "z", Rt + 0.13, Rt - 0.01, 0.03, M["steel_dk"], n=36, what="galerie")
    for k in range(16):
        a = TAU * k / 16
        if math.sin(a) > 0.5:
            continue
        g.box(V(((Rt + 0.12) * math.cos(a), (Rt + 0.12) * math.sin(a), zg + 0.07)), (0.015, 0.015, 0.1), M["steel"],
              "hard", what="poteau")
    g.torus(V((0, 0, zg + 0.12)), "z", Rt + 0.12, 0.01, M["steel"], n=36, m=4, what="lisse")
    # deux ANNEXES aux coins arrière (caissons de machinerie), reliées au fût par des conduites
    for sx in (-1, 1):
        xa = sx * (c.h - c.ann / 2.0)
        ya = c.h - c.ann / 2.0
        x0, x1 = xa - c.ann / 2 + 0.02, xa + c.ann / 2 - 0.02
        PT.hull(g, x0, x1, (ya - c.ann / 2 + 0.02) * SQ2, (ya + c.ann / 2 - 0.02) * SQ2, c.ze, c.Hann,
                ins=(0.02, 0.02, 0.0), panel=0.45, mats=[m2], faces="st")
        p0 = B(xa - sx * c.ann * 0.3, ya - c.ann / 2, c.Hann - 0.12)
        p1 = V((sx * Rt * 0.7, Rt * 0.5, zb + 0.3 * (zh - zb)))
        g.pipe([p0, p0.lerp(p1, 0.5) + V((0, 0, 0.12)), p1], 0.035 + 0.005 * c.side, M["steel_dk"],
               fl_mat=M["steel"], bolt_mat=M["rivet"])
    # contreforts aux quatre diagonales, du bord du socle au fût
    for k in range(4):
        t = math.pi / 4 + k * math.pi / 2
        pb = B(0.92 * c.Rp * math.cos(t), 0.92 * c.Rp * math.sin(t), zb)
        d = V((pb.x, pb.y, 0)).normalized()
        w = V((-d.y, d.x, 0)) * 0.035
        pa = d * Rt + V((0, 0, zb + 0.5 * (zg - zb)))
        pc = d * Rt + V((0, 0, zb))
        vs = [pa + w, pb + w, pc + w, pa - w, pb - w, pc - w]
        fs = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
        g._add(m2, "hard", [tuple(v) for v in vs], fs, "contrefort")


@_lignee
def pylones(g, c):
    """Plan portique : deux pylônes pleine hauteur à croisillons et un pont-caisson riveté, cabine sur le pont."""
    M = g.M
    m1, m2 = c.Mh["olive"], c.Mh["ochre"]
    y0, y1 = c.yt - c.dp / 2.0, c.yt + c.dp / 2.0
    for sx in (-1, 1):
        xa, xb_ = (c.xp - c.wp / 2, c.xp + c.wp / 2)
        if sx < 0:
            xa, xb_ = -xb_, -xa
        PT.hull(g, xa, xb_, y0 * SQ2, y1 * SQ2, c.ze, c.ztop, ins=(0.0, 0.0, 0.0), panel=0.5, mats=[m1], faces="st")
        # pied élargi, croisillons sur la face sud, échelle
        g.box(B((xa + xb_) / 2, c.yt, c.ze + 0.06), (c.wp + 0.1, (c.dp + 0.1) * SQ2, 0.12), M["steel_dk"], "hard",
              what="pied_pylone")
        zl = [c.ze + 0.15 + (c.ztop - c.ze - 0.3) * k / 3 for k in range(4)]
        for k in range(3):
            for sgn in (-1, 1):
                pa = B(xa + 0.04 if sgn > 0 else xb_ - 0.04, y0 - 0.02, zl[k])
                pb = B(xb_ - 0.04 if sgn > 0 else xa + 0.04, y0 - 0.02, zl[k + 1])
                g.tube([pa, pb], 0.018, m2, n=6, what="croisillon")
        for xx in (xa + 0.03, xb_ - 0.03):
            g.box(B(xx, y0 - 0.025, (c.ze + c.ztop) / 2), (0.035, 0.03, c.ztop - c.ze), m2, "hard", what="montant")
    # pont-caisson
    L = 2 * (c.xp + c.wp / 2)
    db = 0.13 * c.side              # essai a2 : un pont large cachait la baie (grande plaque vue de dessus)
    g.box(B(0, c.yt, c.zp + c.hb / 2), (L, db * SQ2, c.hb), m1, "hard", what="pont_caisson")
    q = [B(-L / 2 + c.wp, c.yt - db / 2 - 0.005, c.zp + 0.02), B(L / 2 - c.wp, c.yt - db / 2 - 0.005, c.zp + 0.02),
         B(L / 2 - c.wp, c.yt - db / 2 - 0.005, c.zp + c.hb - 0.02), B(-L / 2 + c.wp, c.yt - db / 2 - 0.005,
                                                                         c.zp + c.hb - 0.02)]
    g.panels(q, max(2, int((L - 2 * c.wp) / 0.45)), 1, m2, t=0.016, rivet_mat=M["rivet"], rivet_step=0.12)
    g.hazard([B(-L / 2 + c.wp, c.yt - db / 2 - 0.03, c.zp + 0.01), B(L / 2 - c.wp, c.yt - db / 2 - 0.03, c.zp + 0.01),
              B(L / 2 - c.wp, c.yt - db / 2 - 0.03, c.zp + 0.06), B(-L / 2 + c.wp, c.yt - db / 2 - 0.03, c.zp + 0.06)],
             max(6, int(L / 0.14)), t=0.006)
    # cabine sur le pont
    xc = 0.28 * c.side
    g.box(B(xc, c.yt, c.ztop + 0.12), (0.34, 0.24 * SQ2, 0.24), m2, "hard", what="cabine")
    g.box(B(xc, c.yt - 0.125, c.ztop + 0.15), (0.26, 0.012, 0.1), M["emit_soft"], "flat", what="vitre_cabine")
    c.zones.append(("rect", -L / 2 + c.wp + 0.05, L / 2 - c.wp - 0.05, c.yt - db / 2 + 0.04, c.yt + db / 2 - 0.04, c.ztop))
    for sx in (-1, 1):
        c.zones.append(("rect", sx * c.xp - c.wp / 2 + 0.05, sx * c.xp + c.wp / 2 - 0.05, y0 + 0.05, y1 - 0.05,
                        c.ztop))
