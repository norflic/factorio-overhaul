"""CORPS DE LIGNÉE de la FOREUSE ÉLECTRIQUE (lot F4-A, 25/10), aux 4 tailles de l'emprise (3×3 à 6×6). S'exécute DANS
Blender. Contrat des fichiers d'âge : epoques.py ; fiches : fo-logs/2026-10-25_F4/FICHES_FOREUSE.md.

Même style et même précision que la mitrailleuse validée (kit commun ../commun : kit.Geo, habillage), mais un corps
PROPRE à la foreuse :
  TABLIER carré (caisson d'acier, dessus en plaques au motif du pont de l'âge, cornières de bord) ; 4 MONTANTS d'angle
  (fût, chapeau, bande de danger) ; PUITS au centre (fond noir, margelle boulonnée) ; GOULOTTE de sortie (auge inclinée
  à joues, lèvre de danger, FLÈCHE lumineuse à la couleur de l'âge) qui pointe le point de dépôt EXACT du prototype ;
  MOTEUR à l'arrière, décalé à l'est (carter, moteur à ailettes, boîte à bornes, câble vers la tour) ; RACCORDS du fluide
  de minage sur les 3 autres côtés (brides au bord, aux positions exactes du prototype, tuyaux vers le pied de la tour) ;
  TRÉPAN au centre (tige, colliers, tête d'injection) ; TOUR de l'âge (ep.tour), centrée, symétrique d'ordre 4.
Repère : TOUT est construit dans le repère des tuiles (cotes.py : x est, y NORD en tuiles, z en unités du monde) sous
repere(g, d), qui étire y de √2 et tourne d'un quart de tour selon la direction : les 4 directions sont exactes. Les
rondelles et rivets sont donc ronds À L'ÉCRAN (comme les gradins du laser).
"""
import math

from mathutils import Matrix, Vector

import cotes
import epoques as E
from habillage import habille, mats_habilles
from kit import SQ2, TAU, axv, basis

V = Vector
LIGNEE_PONT = dict(motif="toles", mat="armor", mat2="armor2", fond="seam", bord="steel_dk", boulons="rivet",
                   lisere=None, pas=None)


class Ctx:
    """Contexte d'une construction : cotes de la taille, habillage, palette habillée, direction."""

    def __init__(self, g, e, ep, side, hab, d="N"):
        self.g, self.M, self.e, self.ep, self.side, self.hab, self.d = g, g.M, e, ep, side, hab, d
        self.T = cotes.taille(side)
        self.Mh = mats_habilles(g.M, hab)
        T = self.T
        self.zt, self.H, self.rt, self.rw, self.a, self.dd = T["zt"], T["H"], T["rt"], T["rw"], T["a"], T["d"]
        p = hab.get("plateforme") or {}
        if isinstance(p, str):
            p = dict(motif=p)
        self.pont = dict(LIGNEE_PONT)
        self.pont.update({k: v for k, v in p.items() if k in LIGNEE_PONT and v is not None})
        self.pont["lisere"] = p.get("lisere")
        self.forme = hab.get("forme_tablier") or "carre"
        # zones du tablier occupées par les accents de l'âge (ep.occupe(c) -> [(x0, y0, x1, y1)] en tuiles, repère N) :
        # la garniture de lignée les évite
        self.occupe = list(ep.occupe(self)) if hasattr(ep, "occupe") else []
        g.ctx = self

    def m(self, cle):
        """Matière habillée de la lignée (ou matière de l'âge) par sa clé."""
        return self.Mh[cle] if cle in self.Mh else self.M[cle]


class repere:
    """Repère des tuiles de la foreuse tournée vers d : `with repere(g, "E"): …` (y étiré de √2 APRÈS la rotation)."""

    def __init__(self, g, d):
        self.g, self.d = g, d

    def __enter__(self):
        m = Matrix.Diagonal((1.0, SQ2, 1.0, 1.0)) @ Matrix.Rotation(E.ANGLE[self.d], 4, "Z")
        self.g.stack.append(self.g.stack[-1] @ m)
        return self.g

    def __exit__(self, *exc):
        self.g.stack.pop()


# ------------------------------------------------------------------------------------------------
# Outils de forme (repère des tuiles)
# ------------------------------------------------------------------------------------------------
def quart(p, k):
    """Point (x, y[, z]) tourné de k quarts de tour (sens trigonométrique) autour de l'axe."""
    x, y = p[0], p[1]
    for _ in range(k % 4):
        x, y = -y, x
    return (x, y) + tuple(p[2:])


def sym4(p):
    """Les 4 images d'un point par la symétrie d'ordre 4 de la tour."""
    return [quart(p, k) for k in range(4)]


def poutre(g, p0, p1, w, m, what="poutre", h=None):
    """Poutre de section carrée (w × h) entre deux points."""
    p0, p1 = V(p0), V(p1)
    d = (p1 - p0)
    if d.length < 1e-6:
        return
    d.normalize()
    u = d.cross(V((0, 0, 1)))
    if u.length < 1e-4:
        u = V((1, 0, 0))
    u.normalize()
    w2 = d.cross(u).normalized()
    a, b = w / 2.0, (h if h is not None else w) / 2.0
    cs = [(-a, -b), (a, -b), (a, b), (-a, b)]
    pts = [p0 + u * x + w2 * y for x, y in cs] + [p1 + u * x + w2 * y for x, y in cs]
    g.hexa(pts, m, "hard", what)


def colonne(g, x, y, z0, z1, r, m, n=16, r2=None, style="smooth", what="colonne", phase=0.0):
    g.cyl((x, y, (z0 + z1) / 2.0), "z", r, z1 - z0, m, n=n, r2=r2, style=style, phase=phase, what=what)


def bague(g, x, y, z, r, h, m, ep=0.025, n=24, what="bague"):
    g.tube_shell((x, y, z), "z", r + ep, max(0.005, r - 0.005), h, m, n=n, what=what)


def dalle(g, x0, y0, x1, y1, z0, z1, m, style="hard", what="dalle"):
    g.box(((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0), (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), m, style,
          what=what)


def rivets_cercle(g, x, y, z, R, n, r, m):
    for i in range(n):
        a = TAU * (i + 0.5) / n
        g.dome((x + R * math.cos(a), y + R * math.sin(a), z), (0, 0, 1), r, m)


def plaque_inclinee(g, x0, x1, y0, z0, y1, z1, t, m, what="plaque"):
    pts = [V((x0, y0, z0)), V((x1, y0, z0)), V((x1, y1, z1)), V((x0, y1, z1))]
    g.hexa(pts + [p + V((0, 0, t)) for p in pts], m, "hard", what)


def lame(g, q, t, m, what="lame"):
    """Lame mince d'épaisseur t sur le quadrilatère plan q (4 points), centrée sur son plan."""
    q = [V(p) for p in q]
    n = (q[1] - q[0]).cross(q[3] - q[0])
    if n.length < 1e-9:
        n = (q[2] - q[0]).cross(q[3] - q[1])
    n.normalize()
    g.slab([p - n * (t / 2.0) for p in q], n, t, m, "hard", what)


def halo(g, p, M, power=4.0, cle="_emit_rgb"):
    g.halo(p, M[cle], power)


# ------------------------------------------------------------------------------------------------
# Pièces de la lignée
# ------------------------------------------------------------------------------------------------
# ronde F4-A3 : rivets de 0,016 t (1 px en haute résolution) invisibles au zoom 1 et non comptés par la charte
# (blobs de 4 à 256 px) : 0,024 t
RIVET_PONT = 0.024
COUPE_OCTOGONE = 0.32     # pan coupé de l'octogone : 0,32 × demi-côté (le pan diagonal est à 1,19 × le demi-côté)


def contour_tablier(c, retrait=0.0):
    """Sommets du contour du tablier (repère des tuiles, sens direct), selon la forme : None si carré."""
    d = c.dd - retrait
    if c.forme == "rond":
        return [(d * math.cos(TAU * i / 48), d * math.sin(TAU * i / 48)) for i in range(48)]
    if c.forme == "octogone":
        k = COUPE_OCTOGONE * c.dd
        pts = []
        for q in range(4):
            for p in ((d, -(d - k)), (d, d - k)):
                pts.append(quart(p, q))
        return pts
    return None


def dans_tablier(c, x, y, r=0.0, marge=0.06):
    """Vrai si le disque (x, y, r) est sur le tablier (toutes formes)."""
    d = c.dd - marge - r
    if c.forme == "rond":
        return math.hypot(x, y) < d
    if abs(x) > d or abs(y) > d:
        return False
    if c.forme == "octogone":
        return abs(x) + abs(y) < 2 * c.dd - COUPE_OCTOGONE * c.dd - (marge + r) * SQ2
    return True


def prisme(g, pts, z0, z1, m, style="hard", what="prisme"):
    """Prisme droit sur un polygone convexe (sens direct) de z0 à z1."""
    n = len(pts)
    vs = [(x, y, z0) for x, y in pts] + [(x, y, z1) for x, y in pts]
    fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, n + j, n + i))
    g._add(m, style, vs, fs, what)


def tablier_forme(g, c):
    """Tablier ROND ou OCTOGONAL (ronde 2 : le DC a jugé l'assembleur « tous carrés ») : caisson prismatique, dessus en
    secteurs alternés au motif de l'âge (rivets au bord), disque central, rebord, liseré lumineux."""
    M = g.M
    zt = c.zt
    zc = zt * 0.80
    ext = contour_tablier(c)
    prisme(g, ext, 0.0, zc, M["steel_dk"], what="caisson")
    pm = [c.m(c.pont["mat"]), c.m(c.pont["mat2"])]
    # secteurs : chaque arête du contour est découpée en morceaux réguliers
    sub = 1 if c.forme == "rond" else 3
    pts = []
    for i in range(len(ext)):
        a, b = ext[i], ext[(i + 1) % len(ext)]
        for s in range(sub):
            t = s / float(sub)
            pts.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    r0 = c.rw + 0.12
    bou = c.pont.get("boulons")
    for i in range(len(pts)):
        p, q = pts[i], pts[(i + 1) % len(pts)]
        if c.forme == "rond" and i % 2:
            continue
        if c.forme == "rond":
            q = pts[(i + 2) % len(pts)]
        rp, rq = math.hypot(*p), math.hypot(*q)
        up, uq = (p[0] / rp, p[1] / rp), (q[0] / rq, q[1] / rq)
        P0 = V((up[0] * r0, up[1] * r0, zc))
        Q0 = V((uq[0] * r0, uq[1] * r0, zc))
        P1 = V((p[0] - up[0] * 0.05, p[1] - up[1] * 0.05, zc))
        Q1 = V((q[0] - uq[0] * 0.05, q[1] - uq[1] * 0.05, zc))
        k = i // (2 if c.forme == "rond" else 1)
        # trois bandes concentriques par secteur (plaques en damier, joints, rivets au bord de chaque plaque)
        # ronde F4-A3 : cinq bandes au lieu de trois (plaques plus petites, plus de rivets)
        for b_, (t0, t1) in enumerate(((0.0, 0.26), (0.26, 0.47), (0.47, 0.65), (0.65, 0.82), (0.82, 1.0))):
            A0, B0 = P0.lerp(P1, t0), Q0.lerp(Q1, t0)
            A1, B1 = P0.lerp(P1, t1), Q0.lerp(Q1, t1)
            mid = (A0 + B0 + A1 + B1) / 4.0
            quad = [A0.lerp(mid, 0.07), A1.lerp(mid, 0.05), B1.lerp(mid, 0.05), B0.lerp(mid, 0.07)]
            top = [v + V((0, 0, zt - zc)) for v in quad]
            g.hexa(quad + top, pm[(k + b_) % 2], "hard", "secteur")
            if bou:
                for t in (0.12, 0.31, 0.5, 0.69, 0.88):
                    e = quad[1].lerp(quad[2], t).lerp(mid, 0.12)
                    g.dome((e.x, e.y, zt), (0, 0, 1), RIVET_PONT, c.m(bou))
    colonne(g, 0, 0, zc, zt, r0 + 0.02, pm[1], n=32, what="disque_central")
    # rebord le long du contour
    b = c.m(c.pont["bord"])
    for i in range(len(ext)):
        a, bb = ext[i], ext[(i + 1) % len(ext)]
        poutre(g, (a[0], a[1], zt + 0.01), (bb[0], bb[1], zt + 0.01), 0.06, b, "corniere")
    if c.pont.get("lisere"):
        lm = M[c.pont["lisere"]] if c.pont["lisere"] in M else M["emit_soft"]
        lis = contour_tablier(c, retrait=-0.006)
        for i in range(len(lis)):
            a, bb = lis[i], lis[(i + 1) % len(lis)]
            poutre(g, (a[0], a[1], zc * 0.55), (bb[0], bb[1], zc * 0.55), 0.012, lm, "lisere", h=0.035)


def tablier(g, c):
    if c.forme in ("rond", "octogone"):
        return tablier_forme(g, c)
    M = g.M
    dd, zt = c.dd, c.zt
    zc = zt * 0.80
    g.box((0, 0, zc / 2.0), (2 * dd, 2 * dd, zc), M["steel_dk"], "hard", what="caisson")
    pm = [c.m(c.pont["mat"]), c.m(c.pont["mat2"])]
    motif = c.pont["motif"]
    pas = c.pont.get("pas") or {"dalles": 0.5, "planches": 0.18, "caillebotis": 0.5}.get(motif, 0.75)
    pas = max(0.25, pas) if motif != "planches" else max(0.15, pas)
    if not c.pont.get("pas") and motif not in ("planches",) and c.side >= 4:
        pas = min(pas, 0.5)       # ronde F4-A3 : plaques plus petites, plus de joints rivetés
    n = max(2, int(round(2 * dd / pas)))
    nu, nv = (n, 1) if motif == "planches" else (n, n)
    e = 0.04
    if c.pont.get("fond"):
        g.box((0, 0, zc + 0.003), (2 * dd - 2 * e, 2 * dd - 2 * e, 0.006), c.m(c.pont["fond"]), "flat", what="fond")
    q = [V((-dd + e, -dd + e, zc)), V((dd - e, -dd + e, zc)), V((dd - e, dd - e, zc)), V((-dd + e, dd - e, zc))]
    bou = c.pont.get("boulons")
    # (essai F4-A3 a3q5 : des joints de 0,045 t aux petites dalles FAISAIENT BAISSER la charte aux âges 6 et 10 : non retenu)
    g.panels(q, nu, nv, pm[0], t=zt - zc, gap=0.025, rivet_mat=(c.m(bou) if bou else None), rivet_r=RIVET_PONT,
             rivet_step=0.11, mats=pm, what="dessus")
    # ronde F4-A4 (âge 10 : « dalles ivoire à motif fin ») : sur chaque dalle, une pastille sombre et 4 plots
    if getattr(c.ep, "MOTIF_DALLE", False) and motif == "dalles":
        mp = c.m(getattr(c.ep, "MOTIF_MAT", "steel_dk"))
        mb = c.m(c.pont.get("bord") or "steel_dk")
        step = (2 * dd - 2 * e) / n
        for i in range(n):
            for j in range(n):
                cx, cy = -dd + e + (i + 0.5) * step, -dd + e + (j + 0.5) * step
                g.box((cx, cy, zt + 0.004), (step * 0.42, step * 0.42, 0.008), mp, "hard", what="pastille")
                for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    g.dome((cx + sx * step * 0.34, cy + sy * step * 0.34, zt), (0, 0, 1), 0.016, mb, what="plot")
    # cornières de bord (au-dessus du dessus : le tablier a un rebord)
    b = c.m(c.pont["bord"])
    w = 0.06
    for k in range(4):
        p0 = quart((-dd, dd - w / 2.0), k)
        p1 = quart((dd, dd - w / 2.0), k)
        cx, cy = (p0[0] + p1[0]) / 2.0, (p0[1] + p1[1]) / 2.0
        sx, sy = (2 * dd, w) if k % 2 == 0 else (w, 2 * dd)
        g.box((cx, cy, zt + 0.01), (sx, sy, 0.06), b, "hard", what="corniere")
    if c.pont.get("lisere"):
        lm = M[c.pont["lisere"]] if c.pont["lisere"] in M else M["emit_soft"]
        for k in range(4):
            p0 = quart((0, -dd - 0.004), k)
            sx, sy = (2 * dd - 0.3, 0.012) if k % 2 == 0 else (0.012, 2 * dd - 0.3)
            g.box((p0[0], p0[1], zc * 0.55), (sx, sy, 0.035), lm, "flat", what="lisere")


def puits(g, c):
    M = g.M
    zt, rw = c.zt, c.rw
    pm = c.m(c.hab.get("puits_mat") or "steel_dk")
    g.cyl((0, 0, zt + 0.006), "z", rw, 0.016, M["void"], n=40, style="flat", what="puits")
    bague(g, 0, 0, zt + 0.035, rw, 0.07, pm, ep=0.08, n=40, what="margelle")
    rivets_cercle(g, 0, 0, zt + 0.072, rw + 0.045, 12, 0.017, c.m("rivet"))


def montant_lignee(g, c, x, y):
    T = c.T["montant"]
    w, h = T["w"], T["h"]
    M = g.M
    g.box((x, y, h / 2.0), (w, w, h), c.m("olive"), "hard", what="montant")
    g.box((x, y, h + 0.03), (w * 1.18, w * 1.18, 0.06), c.m("ochre"), "hard", what="chapeau")
    g.box((x, y, 0.04), (w * 1.35, w * 1.35, 0.08), c.m("steel_dk"), "hard", what="semelle")
    # bande de danger sur les deux faces extérieures
    sx, sy = math.copysign(1, x), math.copysign(1, y)
    bande_danger(g, x, y, w, h - 0.16, h - 0.04, sx, sy)
    g.dome((x, y, h + 0.062), (0, 0, 1), 0.03, c.m("rivet"))


def bande_danger(g, x, y, w, z0, z1, sx, sy, n=3):
    """Bandes de danger sur les deux faces extérieures (normales +sx·x et +sy·y) d'un fût carré de côté w."""
    h = w / 2.0
    qx = [V((x + sx * h, y - sx * h, z0)), V((x + sx * h, y + sx * h, z0)), V((x + sx * h, y + sx * h, z1)),
          V((x + sx * h, y - sx * h, z1))]
    qy = [V((x + sy * h, y + sy * h, z0)), V((x - sy * h, y + sy * h, z0)), V((x - sy * h, y + sy * h, z1)),
          V((x + sy * h, y + sy * h, z1))]
    g.hazard(qx, n, t=0.008)
    g.hazard(qy, n, t=0.008)


def position_montant(c):
    """Demi-diagonale (x = y) des montants : coins du carré, ou sur la diagonale du tablier rond ou octogonal."""
    if c.forme == "rond":
        return (c.dd - 0.24) * 0.7071
    if c.forme == "octogone":
        return ((2 - COUPE_OCTOGONE) * c.dd / SQ2 - 0.26) * 0.7071
    return c.dd - c.T["montant"]["retrait"]


def montants(g, c):
    r = position_montant(c)
    f = getattr(c.ep, "montant", None)
    for (x, y) in ((-r, -r), (r, -r), (r, r), (-r, r)):
        if f is not None:
            f(g, c, x, y)
        else:
            with habille(g, c):
                montant_lignee(g, c, x, y)


def goulotte(g, c):
    """Goulotte de sortie : SIGNAL DE JEU (point de dépôt du prototype), géométrie identique aux 15 âges."""
    M = g.M
    G = c.T["goulotte"]
    x, y0, z0, y1, z1, w = G["x"], G["y0"], G["z0"], G["y1"], G["z1"], G["w"]
    gm = c.m(c.hab.get("goulotte_mat") or "steel")
    t = 0.035
    plaque_inclinee(g, x - w / 2, x + w / 2, y0, z0, y1, z1, t, gm, "goulotte")
    # fond noir de l'auge (minerai) et joues
    plaque_inclinee(g, x - w / 2 + 0.05, x + w / 2 - 0.05, y0 + 0.05, z0 + t, y1 - 0.18, z1 + t, 0.006, M["soot"],
                    "auge")
    hj = 0.10 + 0.02 * (c.side - 3)
    for sx in (-1, 1):
        xx = x + sx * (w / 2 - 0.018)
        pts = [V((xx - 0.018, y0, z0)), V((xx + 0.018, y0, z0)), V((xx + 0.018, y1, z1)), V((xx - 0.018, y1, z1))]
        g.hexa(pts + [p + V((0, 0, hj)) for p in pts], gm, "hard", "joue")
    # lèvre de danger au bout
    ql = [V((x - w / 2, y1 - 0.10, z1 + t + 0.002)), V((x + w / 2, y1 - 0.10, z1 + t + 0.002)),
          V((x + w / 2, y1 - 0.01, z1 + t + 0.002)), V((x - w / 2, y1 - 0.01, z1 + t + 0.002))]
    with habille(g, c):
        g.hazard(ql, 4, t=0.012)
    # FLÈCHE lumineuse (chevron) sur l'auge, pointe vers la sortie
    f = G["fleche"]
    ya = y1 - 0.22 - f * 0.6
    za = z0 + (z1 - z0) * (ya - y0) / (y1 - y0) + t + 0.012
    zb = z0 + (z1 - z0) * (ya + f * 0.6 - y0) / (y1 - y0) + t + 0.012
    for sx in (-1, 1):
        poutre(g, (x + sx * f / 2, ya, za), (x, ya + f * 0.6, zb), 0.06, M["emit"], "fleche", h=0.02)
    halo(g, (x, ya + 0.2, za + 0.15), M, 3.0)
    # béquille sous le bout (le bout dépasse le tablier)
    poutre(g, (x, c.dd - 0.08, 0.02), (x, y1 - 0.12, z1 - 0.01), 0.05, c.m("steel_dk"), "bequille")
    if hasattr(c.ep, "goulotte"):
        c.ep.goulotte(g, c)


def moteur_lignee(g, c):
    T = c.T["moteur"]
    M = g.M
    mx = 0.42 * c.a
    my, w, p, h = T["y"], T["w"], T["p"], T["h"]
    zt = c.zt
    g.box((mx, my, zt + 0.05), (w * 1.06, p * 1.1, 0.10), c.m("steel_dk"), "hard", what="berceau")
    rr = min(p, h) * 0.42
    g.cyl((mx, my, zt + 0.10 + rr), "x", rr, w * 0.78, c.m("olive"), n=20, what="moteur")
    for i in range(7):
        xx = mx - w * 0.32 + w * 0.64 * i / 6.0
        g.tube_shell((xx, my, zt + 0.10 + rr), "x", rr * 1.12, rr * 0.9, 0.018, c.m("steel"), n=20, what="ailette")
    g.cyl((mx + w * 0.42, my, zt + 0.10 + rr), "x", rr * 0.8, 0.07, c.m("ochre"), n=20, what="flasque")
    g.box((mx - w * 0.18, my, zt + 0.12 + 2 * rr), (w * 0.26, p * 0.5, 0.12), c.m("ochre"), "hard", what="bornes")
    g.cable((mx - w * 0.18, my + p * 0.2, zt + 0.16 + 2 * rr), (c.rt * 0.5, -c.rt * 0.6, zt + 0.25), 0.05, 0.022,
            M["redcable"])


def moteur(g, c):
    f = getattr(c.ep, "moteur", None)
    if f is not None:
        f(g, c)
    else:
        with habille(g, c):
            moteur_lignee(g, c)


def raccords(g, c):
    """Raccords du fluide de minage (O, E, S) : bride au bord, tuyau vers le pied de la tour."""
    M = g.M
    R = c.T["raccord"]
    r, L = R["r"], R["long"]
    zr = c.zt + r + 0.03
    lia = getattr(c.ep, "liaison", None)
    for nom in ("O", "E", "S"):
        px, py = c.T["raccords"][nom]
        if nom == "O":
            bx, by, ux, uy = -c.a, py, 1.0, 0.0
        elif nom == "E":
            bx, by, ux, uy = c.a, py, -1.0, 0.0
        else:
            bx, by, ux, uy = px, -c.a, 0.0, 1.0
        # bride au bord et contre-bride boulonnée
        with habille(g, c):
            g.cyl((bx + ux * 0.03, by + uy * 0.03, zr), (ux, uy, 0), r * 1.7, 0.06, c.m("steel_dk"), n=18,
                  style="hard", what="bride")
            g.box((bx + ux * 0.12, by + uy * 0.12, c.zt * 0.5 + 0.02), (0.16 if ux else r * 3, 0.16 if uy else r * 3,
                                                                       c.zt + 0.04), c.m("steel_dk"), "hard",
                  what="support")
        ex, ey = bx + ux * L, by + uy * L
        tx = -c.rt * 0.9 if nom == "O" else (c.rt * 0.9 if nom == "E" else bx)
        ty = by * 0.3 if nom != "S" else -c.rt * 0.9
        ctrl = [(bx + ux * 0.04, by + uy * 0.04, zr), (ex, ey, zr), ((ex + tx) / 2.0, (ey + ty) / 2.0, zr),
                (tx, ty, zr)]
        if nom == "S":
            ctrl = [(bx, by + 0.04, zr), (bx, ey, zr), (bx, (ey + ty) / 2.0, zr), (bx * 0.5, ty, zr)]
        if lia is not None:
            lia(g, ctrl, r)
        else:
            with habille(g, c):
                g.pipe(ctrl, r, c.m("steel"), fl_mat=c.m("steel_dk"), bolt_mat=c.m("rivet"), what="raccord")


def trepan_lignee(g, c):
    T = c.T["trepan"]
    M = g.M
    r, rh = T["r"], T["tete"]
    zt, H = c.zt, c.H
    colonne(g, 0, 0, zt - 0.02, zt + 0.82 * H, r, c.m("steel_hi"), n=8, style="hard", what="tige")
    for i in range(1, 4):
        bague(g, 0, 0, zt + 0.82 * H * i / 4.0, r, 0.05, c.m("steel_dk"), ep=0.02, n=12, what="collier")
    colonne(g, 0, 0, zt + 0.82 * H, zt + 0.82 * H + rh * 1.2, rh, c.m("olive"), n=16, what="tete_injection")
    g.box((0, 0, zt + 0.05), (c.rw * 1.1, c.rw * 1.1, 0.07), c.m("steel_dk"), "hard", what="table")


def trepan(g, c):
    f = getattr(c.ep, "trepan", None)
    if f is not None:
        f(g, c)
    else:
        with habille(g, c):
            trepan_lignee(g, c)


def tour_lignee(g, c):
    """Tour du TÉMOIN (âge 0) : derrick à 4 jambes, entretoises, moufle au sommet (sous z_treillis_max)."""
    M = g.M
    rt, zt, H = c.rt, c.zt, c.H
    hb = min(H, c.T["z_treillis_max"])
    w = 0.07 + 0.01 * (c.side - 3)
    for k in range(4):
        p0 = quart((rt * 0.92, rt * 0.92, zt), k)
        p1 = quart((rt * 0.22, rt * 0.22, hb), k)
        poutre(g, p0, p1, w, c.m("steel"), "jambe")
        g.box((p0[0], p0[1], zt + 0.04), (w * 2.2, w * 2.2, 0.08), c.m("steel_dk"), "hard", what="patin")
    for z in (0.3, 0.6, 0.85):
        zz = zt + (hb - zt) * z
        rr = rt * 0.92 + (rt * 0.22 - rt * 0.92) * z
        for k in range(4):
            a, b = quart((rr, rr, zz), k), quart((rr, -rr, zz), k)
            poutre(g, a, b, w * 0.7, c.m("steel_dk"), "entretoise")
    g.box((0, 0, hb + 0.08), (rt * 0.62, rt * 0.62, 0.16), c.m("olive"), "hard", what="moufle")
    if H > hb:
        colonne(g, 0, 0, hb + 0.16, H, rt * 0.16, c.m("olive"), what="flèche")


# ------------------------------------------------------------------------------------------------
# Garniture du tablier (ronde 1 : à côté de la mitrailleuse validée, la foreuse se lisait « grand tablier nu » ; la
# précision ne baisse jamais, règle d'or 4) : petits accessoires détaillés posés sur les zones LIBRES, aux matières
# habillées de l'âge (caisses rivetées, fûts, armoires à grille et voyant, bobines de câble, trappes à bord de danger,
# bonbonnes). Tirage déterministe (graine de l'âge et de la taille, jamais de la direction : les 4 directions portent
# la même garniture, tournée).
# ------------------------------------------------------------------------------------------------
def _libre(c, x, y, r):
    T = c.T
    d = c.dd
    if not dans_tablier(c, x, y, r):
        return False
    rp = c.rt * float(getattr(c.ep, "PIED", 1.08))
    if math.hypot(x, y) < rp + r or (abs(x) < c.rt + r and abs(y) < c.rt + r and rp >= 1.0 * c.rt):
        return False
    G = T["goulotte"]
    if y + r > G["y0"] - 0.1 and abs(x - G["x"]) < G["w"] / 2 + 0.14 + r:
        return False
    for nom, (px, py) in T["raccords"].items():
        if nom in ("O", "E"):
            if abs(y - py * 0.65) < 0.36 + r and abs(x) > c.rt * 0.5:
                return False
        elif abs(x - px * 0.75) < 0.36 + r and y < -c.rt * 0.5:
            return False
    m = T["moteur"]
    if abs(x - 0.42 * c.a) < m["w"] / 2 + 0.12 + r and abs(y - m["y"]) < m["p"] / 2 + 0.14 + r:
        return False
    mr = position_montant(c)
    if abs(abs(x) - mr) < T["montant"]["w"] + r and abs(abs(y) - mr) < T["montant"]["w"] + r:
        return False
    for (x0, y0, x1, y1) in c.occupe:
        if min(x0, x1) - r < x < max(x0, x1) + r and min(y0, y1) - r < y < max(y0, y1) + r:
            return False
    return True


def _caisse(g, c, x, y, rng):
    w = 0.24 + 0.1 * rng.random()
    h = 0.18 + 0.1 * rng.random()
    m = c.m("olive") if rng.random() < 0.6 else c.m("ochre")
    z = c.zt
    g.box((x, y, z + h / 2), (w, w * 0.85, h), m, "hard", what="caisse")
    g.box((x, y, z + h * 0.55), (w + 0.012, w * 0.85 + 0.012, 0.035), c.m("steel_dk"), "hard", what="sangle")
    for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        g.dome((x + sx * (w / 2 - 0.035), y + sy * (w * 0.425 - 0.035), z + h), (0, 0, 1), RIVET_PONT, c.m("rivet"))
    return h


def _fut(g, c, x, y, rng):
    r = 0.09 + 0.03 * rng.random()
    h = 0.26 + 0.06 * rng.random()
    m = c.m("redpaint") if rng.random() < 0.5 else c.m("olive")
    colonne(g, x, y, c.zt, c.zt + h, r, m, n=14, what="fut")
    for t in (0.2, 0.75):
        bague(g, x, y, c.zt + h * t, r, 0.025, c.m("steel_dk"), ep=0.01, n=14, what="cercle")
    colonne(g, x, y, c.zt + h, c.zt + h + 0.012, r * 0.85, c.m("steel_dk"), n=14, what="couvercle")
    g.dome((x + r * 0.45, y, c.zt + h + 0.012), (0, 0, 1), 0.022, c.m("steel"))


def _armoire(g, c, x, y, rng):
    w, p, h = 0.3, 0.17, 0.34 + 0.08 * rng.random()
    z = c.zt
    g.box((x, y, z + h / 2), (w, p, h), c.m("steel_dk"), "hard", what="armoire")
    g.box((x, y, z + h + 0.015), (w + 0.03, p + 0.03, 0.03), c.m("ochre"), "hard", what="toit")
    q = [V((x - w * 0.38, y - p / 2 - 0.003, z + h * 0.18)), V((x + w * 0.38, y - p / 2 - 0.003, z + h * 0.18)),
         V((x + w * 0.38, y - p / 2 - 0.003, z + h * 0.62)), V((x - w * 0.38, y - p / 2 - 0.003, z + h * 0.62))]
    g.grille(q, 4, depth=0.012, slat_mat=c.m("steel"))
    g.box((x + w * 0.3, y - p / 2 - 0.004, z + h * 0.82), (0.04, 0.008, 0.03), g.M["emit"], "flat", what="voyant")


def _bobine(g, c, x, y, rng):
    r = 0.12
    z = c.zt + r + 0.01
    g.cyl((x, y, z), "x", r * 0.75, 0.16, g.M["rubber"] if rng.random() < 0.5 else g.M["redcable"], n=14,
          what="bobine")
    for s in (-1, 1):
        g.cyl((x + s * 0.09, y, z), "x", r, 0.025, c.m("steel"), n=14, what="joue")
    g.box((x, y, c.zt + 0.02), (0.22, 0.12, 0.04), c.m("steel_dk"), "hard", what="cale")


def _trappe(g, c, x, y, rng):
    w = 0.36
    z = c.zt + 0.02
    g.box((x, y, z), (w, w, 0.04), c.m("steel_dk"), "hard", what="trappe")
    q = [V((x - w / 2, y - w / 2, z + 0.021)), V((x + w / 2, y - w / 2, z + 0.021)), V((x + w / 2, y - w / 2 + 0.06,
                                                                                         z + 0.021)),
         V((x - w / 2, y - w / 2 + 0.06, z + 0.021))]
    with habille(g, c):
        g.hazard(q, 4, t=0.006)
    for (sx, sy) in ((-1, 1), (1, 1)):
        g.dome((x + sx * (w / 2 - 0.04), y + sy * (w / 2 - 0.04), z + 0.02), (0, 0, 1), RIVET_PONT, c.m("rivet"))
    poutre(g, (x - 0.08, y + 0.05, z + 0.03), (x + 0.08, y + 0.05, z + 0.03), 0.025, c.m("steel"), "poignee")


def _bonbonne(g, c, x, y, rng):
    r = 0.08
    h = 0.3
    colonne(g, x, y, c.zt, c.zt + h, r, c.m("ochre"), n=14, what="bonbonne")
    g.sphere((x, y, c.zt + h), r, c.m("ochre"), n=14, m=6, scale=(1, 1, 0.6), what="ogive")
    colonne(g, x, y, c.zt + h + 0.03, c.zt + h + 0.08, 0.025, c.m("steel"), n=8, what="robinet")
    g.torus((x, y, c.zt + h + 0.09), "z", 0.04, 0.008, c.m("redpaint"), n=10, m=4, what="volant")


# --- machines SATELLITES (ronde F4-A2 : « plus de détails et de VOLUME partout », densité de la mitrailleuse) : 1 à 4
# machines plus volumineuses (0,6 à 0,9 t) posées sur les plus grandes zones libres, aux matières habillées de l'âge
def _reservoir(g, c, x, y, rng):
    L, r = 0.62, 0.19
    z = c.zt + r + 0.09
    ax = (1, 0, 0)
    g.cyl((x, y, z), ax, r, L, c.m("ochre"), n=20, what="reservoir")
    for s in (-1, 1):
        g.sphere((x + s * L / 2, y, z), r, c.m("ochre"), n=16, m=8, scale=(0.45, 1, 1), what="fond")
        g.box((x + s * L * 0.3, y, c.zt + 0.05), (0.08, r * 1.7, 0.1), c.m("steel_dk"), "hard", what="berceau")
    for t in (-0.32, 0.0, 0.32):
        g.tube_shell((x + t * L, y, z), ax, r * 1.06, r * 0.96, 0.035, c.m("steel_dk"), n=20, what="cercle")
    colonne(g, x - 0.12, y, z + r - 0.02, z + r + 0.12, 0.03, c.m("steel"), n=8, what="piquage")
    g.torus((x - 0.12, y, z + r + 0.13), "z", 0.055, 0.012, c.m("redpaint"), n=12, m=4, what="volant")
    g.cyl((x + 0.14, y - r * 0.75, z + r * 0.62), (0, -1, 0.8), 0.045, 0.02, g.M["dial"], n=12, what="manometre")
    g.pipe([(x + L / 2 + 0.05, y, z - 0.05), (x + L / 2 + 0.16, y, z - 0.05), (x + L / 2 + 0.16, y, c.zt + 0.04)],
           0.03, c.m("steel"), fl_mat=c.m("steel_dk"), bolt_mat=None, what="soutirage")


def _pompe(g, c, x, y, rng):
    z = c.zt
    g.box((x, y, z + 0.04), (0.72, 0.36, 0.08), c.m("steel_dk"), "hard", what="chassis")
    rr = 0.12
    g.cyl((x - 0.15, y, z + 0.08 + rr), "x", rr, 0.34, c.m("olive"), n=16, what="moteur")
    for i in range(5):
        g.tube_shell((x - 0.29 + 0.07 * i, y, z + 0.08 + rr), "x", rr * 1.12, rr * 0.9, 0.014, c.m("steel"), n=16,
                     what="ailette")
    g.cyl((x + 0.08, y, z + 0.08 + rr), "x", 0.04, 0.12, c.m("steel_hi"), n=8, what="accouplement")
    g.sphere((x + 0.22, y, z + 0.08 + rr), 0.14, c.m("ochre"), n=16, m=8, what="volute")
    g.pipe([(x + 0.22, y, z + 0.08 + 2 * rr + 0.02), (x + 0.22, y, z + 0.5), (x + 0.36, y, z + 0.5)], 0.035,
           c.m("steel"), fl_mat=c.m("steel_dk"), bolt_mat=c.m("rivet"), what="refoulement")
    g.box((x - 0.15, y + rr + 0.02, z + 0.08 + rr * 1.6), (0.12, 0.06, 0.1), c.m("ochre"), "hard", what="bornes")


def _radiateur(g, c, x, y, rng):
    z = c.zt
    w, p, h = 0.6, 0.34, 0.4
    g.box((x, y, z + h / 2), (w, p, h), c.m("steel_dk"), "hard", what="radiateur")
    q = [V((x - w * 0.44, y - p / 2 - 0.003, z + h * 0.12)), V((x + w * 0.44, y - p / 2 - 0.003, z + h * 0.12)),
         V((x + w * 0.44, y - p / 2 - 0.003, z + h * 0.9)), V((x - w * 0.44, y - p / 2 - 0.003, z + h * 0.9))]
    g.grille(q, 6, depth=0.014, slat_mat=c.m("steel"))
    for s in (-1, 1):
        colonne(g, x + s * w * 0.25, y, z + h, z + h + 0.03, 0.12, c.m("olive"), n=16, what="buse")
        colonne(g, x + s * w * 0.25, y, z + h + 0.03, z + h + 0.045, 0.03, c.m("steel_hi"), n=8, what="moyeu")
        for k in range(4):
            a = TAU * k / 4 + 0.4
            poutre(g, (x + s * w * 0.25, y, z + h + 0.04), (x + s * w * 0.25 + 0.1 * math.cos(a),
                                                             y + 0.1 * math.sin(a), z + h + 0.05), 0.04,
                   c.m("steel"), "pale", h=0.01)
    g.pipe([(x - w / 2 - 0.02, y + 0.06, z + h * 0.7), (x - w / 2 - 0.14, y + 0.06, z + h * 0.7),
            (x - w / 2 - 0.14, y + 0.06, z + 0.04)], 0.03, c.m("steel"), fl_mat=None, bolt_mat=None, flanges=False,
           what="retour")


def _armoire_haute(g, c, x, y, rng):
    z = c.zt
    w, p, h = 0.46, 0.26, 0.62
    g.box((x, y, z + h / 2), (w, p, h), c.m("olive"), "hard", what="armoire_haute")
    g.box((x, y, z + h + 0.02), (w + 0.04, p + 0.04, 0.04), c.m("steel_dk"), "hard", what="toit")
    for s in (-1, 1):
        g.box((x + s * w * 0.24, y - p / 2 - 0.006, z + h * 0.5), (w * 0.44, 0.012, h * 0.86), c.m("ochre"), "hard",
              what="porte")
        g.box((x + s * w * 0.06, y - p / 2 - 0.016, z + h * 0.5), (0.02, 0.012, 0.08), c.m("steel_hi"), "hard",
              what="poignee")
    for i in range(3):
        g.box((x - w * 0.3 + 0.07 * i, y - p / 2 - 0.016, z + h * 0.85), (0.035, 0.01, 0.03), g.M["emit"], "flat",
              what="voyant")
    g.cable((x + w * 0.3, y + p / 2, z + h * 0.8), (x + w * 0.5, y + p / 2 + 0.2, z + 0.03), 0.03, 0.018,
            g.M["redcable"])


SATELLITES = (_reservoir, _pompe, _radiateur, _armoire_haute)
RAYON_SAT = {_reservoir: 0.42, _pompe: 0.4, _radiateur: 0.36, _armoire_haute: 0.3}


def satellites(g, c, n):
    """Pose jusqu'à n machines satellites sur les zones libres, des plus loin de la tour aux plus près."""
    import random
    rng = random.Random(7000 + 31 * c.e + c.side)
    ordre = list(SATELLITES)
    rng.shuffle(ordre)
    cand = []
    pas = 0.2
    m = int(c.dd / pas)
    for i in range(-m, m + 1):
        for j in range(-m, m + 1):
            x, y = i * pas, j * pas
            cand.append((-round(math.hypot(x, y), 3), x, y))
    cand.sort()
    poses = 0
    for f in ordre * 2:
        if poses >= n:
            break
        r = RAYON_SAT[f]
        for (_, x, y) in cand:
            if _libre(c, x, y, r):
                f(g, c, x, y, rng)
                c.occupe.append((x - r, y - r, x + r, y + r))
                poses += 1
                break
    return poses


PROPS = (_caisse, _fut, _armoire, _bobine, _trappe, _bonbonne)
RAYON_PROP = {_caisse: 0.2, _fut: 0.14, _armoire: 0.19, _bobine: 0.15, _trappe: 0.22, _bonbonne: 0.1}


def garniture(g, c, densite=0.45):
    import random
    rng = random.Random(9000 + 31 * c.e + c.side)
    pas = 0.40
    n = int(2 * c.dd / pas)
    o = -c.dd + (2 * c.dd - n * pas) / 2.0 + pas / 2.0
    poses = 0
    for i in range(n):
        for j in range(n):
            if rng.random() > densite:
                rng.random()
                rng.random()
                continue
            f = PROPS[rng.randrange(len(PROPS))]
            x = o + i * pas + (rng.random() - 0.5) * 0.08
            y = o + j * pas + (rng.random() - 0.5) * 0.08
            if not _libre(c, x, y, RAYON_PROP[f]):
                continue
            f(g, c, x, y, rng)
            poses += 1
            # grappe (ronde F4-A2 : densité de petites pièces) : un petit voisin collé au premier (contrôlé AVANT que
            # le premier ne soit inscrit dans les zones occupées)
            if rng.random() < 0.55:
                f2 = (_fut, _bonbonne, _bobine)[rng.randrange(3)]
                r2 = RAYON_PROP[f2]
                ang = rng.random() * TAU
                x2 = x + math.cos(ang) * (RAYON_PROP[f] + r2 + 0.01)
                y2 = y + math.sin(ang) * (RAYON_PROP[f] + r2 + 0.01)
                if _libre(c, x2, y2, r2):
                    c.occupe.append((x2 - r2, y2 - r2, x2 + r2, y2 + r2))
                    f2(g, c, x2, y2, rng)
                    poses += 1
            c.occupe.append((x - RAYON_PROP[f], y - RAYON_PROP[f], x + RAYON_PROP[f], y + RAYON_PROP[f]))
    return poses


# ------------------------------------------------------------------------------------------------
# Liaisons tour-tablier (ronde F4-A2, verdict du DC du 25/10 : « Oui, enrichir nettement » ; la tour ne doit plus être
# « posée sur » le tablier : un seul corps). Réglage par âge : ep.EMBASE = dict(r=…, h=…, contreforts=n, cphase=degrés,
# hc=hauteur, haubans=n, hphase=degrés, zh=hauteur d'attache, rh=rayon d'attache, conduites=n, rc=…, zc=…) ou False.
# ------------------------------------------------------------------------------------------------
EMBASE_DEFAUT = dict(r=1.12, h=None, contreforts=4, cphase=45.0, hc=0.30, rin=0.80, haubans=0, hphase=45.0, zh=0.78,
                     rh=0.22, conduites=2, cdphase=62.0, rc=0.55, zc=0.42)
# secteurs libres autour de la tour (repère N) : la goulotte (nord), les raccords (ouest, est, sud), le moteur (sud-est)
# et les contreforts (diagonales) occupent les autres ; conduites à 62° et 242° par défaut


def liaisons_tour(g, c):
    cfg = getattr(c.ep, "EMBASE", None)
    if cfg is False:
        return
    E = dict(EMBASE_DEFAUT)
    E.update(cfg or {})
    M = g.M
    rt, zt, H = c.rt, c.zt, c.H
    r = rt * E["r"]
    h = E["h"] if E["h"] is not None else 0.13 + 0.02 * (c.side - 3)
    with habille(g, c):
        if r > 0:
            # embase à 8 pans, couronne boulonnée : le pied de la tour est noyé dans le tablier
            colonne(g, 0, 0, zt, zt + h, r, c.m("steel_dk"), n=8, phase=math.pi / 8, style="hard", what="embase")
            g.tube_shell((0, 0, zt + h), "z", r * 1.0, r * 0.86, 0.045, c.m("olive"), n=8, what="couronne_embase")
            for k in range(16):
                a = TAU * (k + 0.5) / 16
                g.dome((r * 0.93 * math.cos(a), r * 0.93 * math.sin(a), zt + h + 0.023), (0, 0, 1), 0.018,
                       c.m("rivet"))
        # contreforts (goussets) de la tour au tablier, arête d'acier et rivets
        for k in range(int(E["contreforts"])):
            a = math.radians(E["cphase"]) + TAU * k / int(E["contreforts"])
            u = (math.cos(a), math.sin(a))
            r0, r1 = rt * E["rin"], max(r, rt) + 0.28
            z1 = zt + E["hc"] * H
            q = [(u[0] * r0, u[1] * r0, zt + h), (u[0] * r1, u[1] * r1, zt + h), (u[0] * r1, u[1] * r1, zt + h + 0.1),
                 (u[0] * r0, u[1] * r0, z1)]
            lame(g, q, 0.07, c.m("olive"), "contrefort")
            poutre(g, q[2], q[3], 0.05, c.m("steel"), "arete")
            for t in (0.3, 0.6):
                p = (q[0][0] + (q[2][0] - q[0][0]) * t, q[0][1] + (q[2][1] - q[0][1]) * t, zt + h + (z1 - zt - h) * 0.3 * t)
                g.dome((p[0], p[1], p[2] + 0.05), (-u[1], u[0], 0), 0.016, c.m("rivet"))
            g.box((u[0] * r1, u[1] * r1, zt + 0.02), (0.18, 0.18, 0.04), c.m("steel_dk"), "hard", what="semelle")
            c.occupe.append((u[0] * r1 - 0.22, u[1] * r1 - 0.22, u[0] * r1 + 0.22, u[1] * r1 + 0.22))
    # haubans : câbles de la tour aux ancres du tablier (ridoir, platine)
    for k in range(int(E["haubans"])):
        a = math.radians(E["hphase"]) + TAU * k / int(E["haubans"])
        u = (math.cos(a), math.sin(a))
        ra = min(c.dd * 0.86, rt * 1.75)
        while ra > rt and not dans_tablier(c, u[0] * ra, u[1] * ra, 0.12):
            ra -= 0.1
        top = (u[0] * rt * E["rh"], u[1] * rt * E["rh"], zt + E["zh"] * (H - zt))
        bas = (u[0] * ra, u[1] * ra, zt + 0.1)
        g.tube([top, ((top[0] + bas[0]) / 2, (top[1] + bas[1]) / 2, (top[2] + bas[2]) / 2 - 0.03), bas], 0.014,
               M["steel_hi"], n=6, what="hauban")
        g.cyl(((top[0] * 0.15 + bas[0] * 0.85), (top[1] * 0.15 + bas[1] * 0.85), top[2] * 0.15 + bas[2] * 0.85),
              (top[0] - bas[0], top[1] - bas[1], top[2] - bas[2]), 0.03, 0.14, c.m("steel_dk"), n=8, what="ridoir")
        g.box((bas[0], bas[1], zt + 0.03), (0.2, 0.2, 0.06), c.m("steel_dk"), "hard", what="ancre")
        g.cyl((bas[0], bas[1], zt + 0.09), "z", 0.04, 0.06, c.m("steel"), n=8, what="oeil")
        c.occupe.append((bas[0] - 0.25, bas[1] - 0.25, bas[0] + 0.25, bas[1] + 0.25))
    # conduites de la tour au tablier (organe de liaison de l'âge)
    lia = getattr(c.ep, "liaison", None)
    for k in range(int(E["conduites"])):
        a = math.radians(E["cdphase"]) + TAU * k / max(1, int(E["conduites"]))
        u = (math.cos(a), math.sin(a))
        p0 = (u[0] * rt * E["rc"], u[1] * rt * E["rc"], zt + E["zc"] * (H - zt))
        rb = max(r, rt) + 0.18
        if not dans_tablier(c, u[0] * (rb + 0.15), u[1] * (rb + 0.15), 0.1):
            rb = rt * 1.05
        pts = [p0, (u[0] * rt * 0.95, u[1] * rt * 0.95, p0[2] - 0.05), (u[0] * rb, u[1] * rb, zt + 0.35),
               (u[0] * rb, u[1] * rb, zt + 0.04)]
        rr = 0.05 + 0.01 * (c.side - 3)
        if lia is not None:
            lia(g, pts, rr)
        else:
            with habille(g, c):
                g.pipe(pts, rr, c.m("steel"), fl_mat=c.m("steel_dk"), bolt_mat=c.m("rivet"), what="conduite")
        g.box((u[0] * rb, u[1] * rb, zt + 0.03), (0.22, 0.22, 0.06), c.m("steel_dk"), "hard", what="socle_conduite")
        c.occupe.append((u[0] * rb - 0.25, u[1] * rb - 0.25, u[0] * rb + 0.25, u[1] * rb + 0.25))


def chemins_de_cables(g, c):
    """Chemins de câbles le long des bords avant et ouest du tablier carré (sous les tuyaux), câbles rouge, noir, gaine."""
    if c.forme != "carre":
        return
    M = g.M
    d = c.dd
    m = position_montant(c) - c.T["montant"]["w"] - 0.1
    T = c.T
    px = T["raccords"]["S"][0]
    py = T["raccords"]["O"][1] * 0.65
    for bord in ("S", "O"):
        if bord == "S":
            segs = [(-m, px - 0.45), (px + 0.45, 0.42 * c.a - T["moteur"]["w"] / 2 - 0.15)]
        else:
            segs = [(-m, py - 0.5), (py + 0.5, T["goulotte"]["y0"] - 0.2)]
        for (s0, s1) in segs:
            if s1 - s0 < 0.3:
                continue
            for (o, mat_) in ((0.0, M["redcable"]), (0.035, M["rubber"]), (-0.035, M["soot"])):
                if bord == "S":
                    p0, p1 = (s0, -d + 0.14 + o, c.zt + 0.05), (s1, -d + 0.14 + o, c.zt + 0.05)
                else:
                    p0, p1 = (-d + 0.14 + o, s0, c.zt + 0.05), (-d + 0.14 + o, s1, c.zt + 0.05)
                g.tube([p0, ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, p0[2]), p1], 0.018, mat_, n=6, what="cable")
            with habille(g, c):
                if bord == "S":
                    g.box(((s0 + s1) / 2, -d + 0.14, c.zt + 0.02), (s1 - s0, 0.14, 0.04), c.m("steel_dk"), "hard",
                          what="chemin")
                    c.occupe.append((s0, -d, s1, -d + 0.24))
                else:
                    g.box((-d + 0.14, (s0 + s1) / 2, c.zt + 0.02), (0.14, s1 - s0, 0.04), c.m("steel_dk"), "hard",
                          what="chemin")
                    c.occupe.append((-d, s0, -d + 0.24, s1))


# ------------------------------------------------------------------------------------------------
# Ronde F4-A3 (27/10) : « enrichir nettement » AU ZOOM 1. La ronde A2 n'avait pas bougé la densité de petites pièces de
# la charte (12 à 36 par t², mitrailleuse 26 à 56) : les satellites sont de grosses pièces. Trois leviers de lignée :
# DÉTAIL FIN semé sur tout le tablier libre (boulons, bouchons, évents, plaquettes, voyants, bouts de câble), GARDE-CORPS
# sur les grands tabliers, FEUX DE POSITION sur les 4 montants (la nuit n'est plus noire). Réglages par âge : ep.FIN
# (part des cases garnies, 0,9), ep.PAS_FIN (pas de la grille, 0,14 t), ep.LAMPES (part des voyants, 0,14),
# ep.GARDE_CORPS (vrai à partir de 5×5), ep.FEUX (vrai).
# ------------------------------------------------------------------------------------------------
def _dist_seg(px, py, a, b):
    ax, ay = a
    bx, by = b
    vx, vy = bx - ax, by - ay
    L2 = vx * vx + vy * vy
    s = 0.0 if L2 < 1e-12 else max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / L2))
    return math.hypot(px - (ax + s * vx), py - (ay + s * vy))


def _tracés_raccords(c):
    """Polylignes (repère N) des tuyaux de raccord posés par raccords() : bord → bout droit → pied de la tour."""
    L = c.T["raccord"]["long"]
    out = []
    for nom in ("O", "E", "S"):
        px, py = c.T["raccords"][nom]
        if nom == "O":
            bx, by, ux, uy = -c.a, py, 1.0, 0.0
        elif nom == "E":
            bx, by, ux, uy = c.a, py, -1.0, 0.0
        else:
            bx, by, ux, uy = px, -c.a, 0.0, 1.0
        ex, ey = bx + ux * L, by + uy * L
        if nom == "S":
            out.append([(bx, by), (bx, ey), (bx * 0.5, -c.rt * 0.9)])
        else:
            tx = -c.rt * 0.9 if nom == "O" else c.rt * 0.9
            out.append([(bx, by), (ex, ey), (tx, by * 0.3)])
    return out


def _libre_fin(c, x, y, r):
    """Place libre pour le DÉTAIL FIN (ronde F4-A3) : comme _libre, mais au plus près des objets réels (tuyaux de
    raccord suivis à leur tracé, goulotte à sa largeur) au lieu des larges bandes réservées à la garniture."""
    if not dans_tablier(c, x, y, r):
        return False
    rp = c.rt * float(getattr(c.ep, "PIED", 1.08))
    if math.hypot(x, y) < rp + r or (abs(x) < c.rt + r and abs(y) < c.rt + r and rp >= 1.0 * c.rt):
        return False
    G = c.T["goulotte"]
    if y + r > G["y0"] - 0.05 and abs(x - G["x"]) < G["w"] / 2 + 0.05 + r:
        return False
    rr = c.T["raccord"]["r"] * 1.8 + 0.03 + r
    if not hasattr(c, "_tr_racc"):
        c._tr_racc = _tracés_raccords(c)
    for pl in c._tr_racc:
        for k in range(len(pl) - 1):
            if _dist_seg(x, y, pl[k], pl[k + 1]) < rr:
                return False
    m = c.T["moteur"]
    if abs(x - 0.42 * c.a) < m["w"] / 2 + 0.12 + r and abs(y - m["y"]) < m["p"] / 2 + 0.14 + r:
        return False
    mr = position_montant(c)
    if abs(abs(x) - mr) < c.T["montant"]["w"] + r and abs(abs(y) - mr) < c.T["montant"]["w"] + r:
        return False
    for (x0, y0, x1, y1) in c.occupe:
        if min(x0, x1) - r < x < max(x0, x1) + r and min(y0, y1) - r < y < max(y0, y1) + r:
            return False
    return True


# Habillage des FÛTS (ronde F4-A3) : pendant la construction de la tour, chaque cylindre construit par g.cyl (rayon
# ≥ 0,15 t, hauteur ≥ 0,12 t, ni verre, ni lumière, ni vide) est relevé avec sa matrice ; après la tour, des couronnes de
# boulons sont posées à ses deux bouts (et au milieu au-delà de 0,45 t), au pas de 0,12 t : les grandes surfaces lisses
# des tours portaient l'essentiel du manque de petites pièces (carte de la charte, NOTES F4-A3).
FUT_SAUTE_WHAT = ("lueur", "verre", "emit", "halo", "fente", "trou", "puits", "flamme", "voyant", "lanterne", "feu",
                  "horizon", "bocal", "boue", "singularite", "sphere", "lumiere", "glace", "cristal")
FUT_SAUTE_MAT = ("emit", "verre", "glass", "void", "light", "boue", "horizon", "glace", "cristal")


def _releve_cylindres(g, rmin=0.15, hmin=0.12):
    rec = []
    orig = g.cyl

    def cyl(cc, axis, r, h, mat, *args, **kw):
        r2 = kw.get("r2", args[1] if len(args) > 1 else None)
        what = str(kw.get("what", args[5] if len(args) > 5 else "cyl") or "")
        nm = str(getattr(mat, "name", "") or "").lower()
        if (r >= rmin and h >= hmin and not any(s in what for s in FUT_SAUTE_WHAT)
                and not any(s in nm for s in FUT_SAUTE_MAT)):
            rec.append((g.stack[-1], tuple(cc), axis, float(r), float(h), float(r if r2 is None else r2)))
        return orig(cc, axis, r, h, mat, *args, **kw)
    g.cyl = cyl
    orig_t = g.torus

    def torus(cc, axis, R, r, mat, *args, **kw):
        what = str(kw.get("what", "") or "")
        nm = str(getattr(mat, "name", "") or "").lower()
        if (R >= 0.25 and r >= 0.04 and not any(s in what for s in FUT_SAUTE_WHAT)
                and not any(s in nm for s in FUT_SAUTE_MAT)):
            rec.append((g.stack[-1], tuple(cc), axis, float(R), -float(r), 0.0))
        return orig_t(cc, axis, R, r, mat, *args, **kw)
    g.torus = torus
    return rec


def _poutre_rivetee(orig, g_ref):
    """Remplace corps.poutre pendant la tour : rivets sur les deux arêtes hautes des poutres longues (≥ 0,6 t, ≥ 0,07 t
    de large)."""
    def poutre_r(g, p0, p1, w, m, what="poutre", h=None):
        orig(g, p0, p1, w, m, what, h)
        L = math.dist(p0, p1)
        nm = str(getattr(m, "name", "") or "").lower()
        if g is not g_ref or L < 0.6 or w < 0.07 or any(s in nm for s in FUT_SAUTE_MAT) or any(
                s in str(what) for s in FUT_SAUTE_WHAT):
            return
        a = V(p1) - V(p0)
        a.normalize()
        up = V((0, 0, 1))
        s = a.cross(up)
        if s.length < 1e-3:
            return
        s.normalize()
        hh = (w if h is None else h) / 2.0
        n = int(L / 0.12)
        for i in range(1, n):
            q = V(p0) + a * (L * i / n)
            for sg in (-1, 1):
                g.dome(tuple(q + s * (sg * w * 0.32) + up * (hh + 0.002)), (0, 0, 1), 0.018, g_ref.ctx.m("rivet"),
                       what="rivet_poutre")
    return poutre_r


def _fin_releve(g):
    for k in ("cyl", "torus"):
        if k in g.__dict__:
            delattr(g, k)


def boulons_futs(g, c, rec, pas=0.12):
    if not getattr(c.ep, "BOULONS_FUTS", True):
        return 0
    mb = c.m("rivet")
    n_tot = 0
    for (Mx, cc, axis, r, h, r2) in rec:
        g.stack.append(Mx)
        try:
            a, u, w = basis(axv(axis))
            C = V(cc)
            if h < 0:
                # tore (R = r, tube = −h) : clous sur l'équateur extérieur
                R, rt_ = r, -h
                n = max(8, min(96, int(round(TAU * (R + rt_) / pas))))
                for i in range(n):
                    ang = TAU * (i + 0.5) / n
                    d = u * math.cos(ang) + w * math.sin(ang)
                    g.dome(tuple(C + d * (R + rt_ + 0.002)), tuple(d), 0.02, mb, what="clou_tore")
                    n_tot += 1
                continue
            e = min(0.07, h * 0.25)
            bagues = [(-h / 2 + e, r + (r2 - r) * e / h), (h / 2 - e, r2 - (r2 - r) * e / h)]
            if h > 0.45:
                bagues.append((0.0, (r + r2) / 2.0))
            if h >= 0.5 and min(r, r2) >= 0.3:
                # lignes verticales de rivets (joints des viroles)
                nl = max(6, int(TAU * (r + r2) / 2.0 / 0.42))
                k = int((h - 0.24) / 0.1)
                for il in range(nl):
                    ang = TAU * il / nl
                    d = u * math.cos(ang) + w * math.sin(ang)
                    for j in range(k + 1):
                        tz = -h / 2 + 0.12 + j * 0.1
                        rr = r + (r2 - r) * (tz + h / 2) / h
                        g.dome(tuple(C + a * tz + d * (rr + 0.004)), tuple(d), 0.018, mb, what="rivet_fut")
                        n_tot += 1
            for (tz, rr) in bagues:
                n = max(8, min(72, int(round(TAU * rr / pas))))
                for i in range(n):
                    ang = TAU * (i + 0.5) / n
                    d = u * math.cos(ang) + w * math.sin(ang)
                    p = C + a * tz + d * (rr + 0.004)
                    g.dome(tuple(p), tuple(d), 0.021, mb, what="boulon_fut")
                    n_tot += 1
        finally:
            g.stack.pop()
    return n_tot


def _f_boulons(g, c, x, y, z, rng, M):
    s = 0.034
    g.box((x, y, z + 0.006), (0.12, 0.12, 0.016), c.m("steel_dk"), "hard", what="platine")
    for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        g.dome((x + sx * s, y + sy * s, z + 0.014), (0, 0, 1), 0.022, M["steel_hi"], what="boulon")


def _f_bouchon(g, c, x, y, z, rng, M):
    g.cyl((x, y, z + 0.018), "z", 0.045, 0.036, c.m("steel"), n=12, style="hard", what="bouchon")
    g.cyl((x, y, z + 0.037), "z", 0.024, 0.004, M["void"], n=10, style="flat", what="bouchon_trou")


def _f_event(g, c, x, y, z, rng, M):
    w, p = 0.15, 0.1
    g.box((x, y, z + 0.01), (w, p, 0.02), c.m("steel"), "hard", what="event")
    for k in (-1, 0, 1):
        g.box((x, y + k * 0.028, z + 0.0205), (w * 0.72, 0.016, 0.002), M["void"], "flat", what="fente")


def _f_plaquette(g, c, x, y, z, rng, M):
    m = M["steel_hi"] if rng.random() < 0.5 else c.m("ochre")
    g.box((x, y, z + 0.008), (0.1, 0.065, 0.016), m, "hard", what="plaquette")
    g.box((x - 0.02, y, z + 0.0165), (0.04, 0.012, 0.002), M["void"], "flat", what="inscription")


def _f_voyant(g, c, x, y, z, rng, M):
    g.cyl((x, y, z + 0.016), "z", 0.04, 0.032, c.m("steel_dk"), n=12, style="hard", what="boitier")
    g.dome((x, y, z + 0.032), (0, 0, 1), 0.026, M["emit"], what="voyant")


def _f_cable(g, c, x, y, z, rng, M):
    a = rng.random() * math.pi
    u = (math.cos(a) * 0.08, math.sin(a) * 0.08)
    m = (M["rubber"], M["redcable"], M["soot"])[rng.randrange(3)]
    g.tube([(x - u[0], y - u[1], z + 0.018), (x, y, z + 0.024), (x + u[0], y + u[1], z + 0.018)], 0.014, m, n=6,
           what="bout_cable")
    for s in (-0.6, 0.6):
        g.box((x + u[0] * s, y + u[1] * s, z + 0.02), (0.03, 0.03, 0.03), M["steel_hi"], "hard", what="collier")


FINS = ((_f_boulons, 0.30), (_f_bouchon, 0.20), (_f_event, 0.14), (_f_plaquette, 0.14), (_f_cable, 0.08))


def detail_fin(g, c):
    """Détail fin semé sur le tablier libre (grille de pas PAS_FIN, décalage au hasard), APRÈS satellites et garniture
    (zones occupées évitées) ; rien n'est inscrit dans c.occupe (les cases sont disjointes)."""
    import random
    rng = random.Random(11000 + 31 * c.e + c.side)
    M = g.M
    pas = float(getattr(c.ep, "PAS_FIN", 0.14))
    part = float(getattr(c.ep, "FIN", 0.9))
    lampes = float(getattr(c.ep, "LAMPES", 0.14))
    poids = [(f, w) for f, w in FINS]
    tot = sum(w for _, w in poids)
    n = int(2 * c.dd / pas)
    o = -c.dd + (2 * c.dd - n * pas) / 2.0 + pas / 2.0
    z = c.zt - 0.012
    poses = 0
    for i in range(n):
        for j in range(n):
            u1, u2, u3, u4 = rng.random(), rng.random(), rng.random(), rng.random()
            if u1 > part:
                continue
            x = o + i * pas + (u2 - 0.5) * pas * 0.35
            y = o + j * pas + (u3 - 0.5) * pas * 0.35
            if not _libre_fin(c, x, y, 0.07) or (getattr(c, "n_garde_corps", 0) and not dans_tablier(c, x, y, 0.07, 0.2)):
                continue
            if u4 < lampes:
                f = _f_voyant
            else:
                r = rng.random() * tot
                f = poids[-1][0]
                for ff, w in poids:
                    if r < w:
                        f = ff
                        break
                    r -= w
            f(g, c, x, y, z, rng, M)
            poses += 1
    return poses


def garde_corps(g, c):
    """Garde-corps le long du bord du tablier (poteaux tous les 0,2 t, deux lisses), interrompu par la goulotte, les
    raccords, le moteur, les montants et tout ce qui occupe le bord."""
    if not getattr(c.ep, "GARDE_CORPS", c.side >= 5):
        return 0
    M = g.M
    ins = 0.11
    h = 0.12
    z0 = c.zt - 0.01
    ext = contour_tablier(c, retrait=ins)
    if ext is None:
        d = c.dd - ins
        ext = [(-d, -d), (d, -d), (d, d), (-d, d)]
    m_p = c.m("ochre")
    m_l = M["steel_hi"]
    poteaux = []
    for i in range(len(ext)):
        a, b = ext[i], ext[(i + 1) % len(ext)]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        k = max(1, int(L / 0.16))
        for s in range(k):
            t = s / float(k)
            poteaux.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    ok = [_libre_fin(c, x, y, 0.035) for (x, y) in poteaux]
    n = 0
    for i, (x, y) in enumerate(poteaux):
        if not ok[i]:
            continue
        g.cyl((x, y, z0 + h / 2), "z", 0.016, h, m_p, n=6, style="hard", what="poteau")
        n += 1
        j = (i + 1) % len(poteaux)
        if ok[j]:
            x2, y2 = poteaux[j]
            if math.hypot(x2 - x, y2 - y) < 0.3:
                for zz in (h, h * 0.55):
                    g.tube([(x, y, z0 + zz), ((x + x2) / 2, (y + y2) / 2, z0 + zz), (x2, y2, z0 + zz)], 0.009, m_l,
                           n=5, what="lisse")
    return n


def feux_montants(g, c):
    """Feu de position sur le chapeau de chacun des 4 montants (couleur du foyer de l'âge) et son halo de nuit."""
    if not getattr(c.ep, "FEUX", True):
        return
    M = g.M
    r = position_montant(c)
    hm = c.T["montant"]["h"]
    for (x, y) in ((-r, -r), (r, -r), (r, r), (-r, r)):
        g.cyl((x, y, hm + 0.09), "z", 0.04, 0.05, c.m("steel_dk"), n=10, style="hard", what="feu_socle")
        g.dome((x, y, hm + 0.115), (0, 0, 1), 0.036, M["emit"], what="feu")
        halo(g, (x, y, hm + 0.2), M, float(getattr(c.ep, "FEUX_PUISSANCE", 1.6)))


# ------------------------------------------------------------------------------------------------
# Assemblage
# ------------------------------------------------------------------------------------------------
def corps(g, c):
    """Corps complet de la foreuse tournée vers c.d (variante eNN-D)."""
    with repere(g, c.d):
        with habille(g, c):
            tablier(g, c)
            puits(g, c)
        montants(g, c)
        raccords(g, c)
        moteur(g, c)
        goulotte(g, c)
        trepan(g, c)
        rec = _releve_cylindres(g)
        _poutre0 = globals()["poutre"]
        globals()["poutre"] = _poutre_rivetee(_poutre0, g)
        try:
            if hasattr(c.ep, "tour"):
                c.ep.tour(g, c)
            else:
                with habille(g, c):
                    tour_lignee(g, c)
        finally:
            _fin_releve(g)
            globals()["poutre"] = _poutre0
        c.n_boulons_futs = boulons_futs(g, c, rec)
        liaisons_tour(g, c)
        if hasattr(c.ep, "socle"):
            c.ep.socle(g, c)
        chemins_de_cables(g, c)
        nsat = getattr(c.ep, "SATELLITES", {3: 1, 4: 2, 5: 3, 6: 4}[c.side])
        rec_s = _releve_cylindres(g, rmin=0.1, hmin=0.1)
        try:
            c.n_satellites = satellites(g, c, int(nsat))
        finally:
            _fin_releve(g)
        c.n_boulons_futs += boulons_futs(g, c, rec_s, pas=0.1)
        if getattr(c.ep, "GARNITURE", True):
            c.n_garniture = garniture(g, c, float(getattr(c.ep, "DENSITE", 0.85)))
        # ronde F4-A3 : garde-corps (avant le détail fin, qui évite ses poteaux), détail fin, feux de position
        c.n_garde_corps = garde_corps(g, c)
        c.n_fin = detail_fin(g, c)
        feux_montants(g, c)


def piece(g, c):
    """Pièce du niveau pair, posée sur le sommet de la tour (une fois pour les 4 directions). Ronde F4-A2 (niveau pair
    « plus distinct ») : agrandie de ECHELLE_PIECE autour de son point de pose (0, 0, H), sauf âge 1 (ep.ECHELLE)."""
    k = float(getattr(c.ep, "ECHELLE", ECHELLE_PIECE))
    with repere(g, "N"):
        m = (Matrix.Translation((0.0, 0.0, c.H)) @ Matrix.Diagonal((k, k, k, 1.0))
             @ Matrix.Translation((0.0, 0.0, -c.H)))
        g.stack.append(g.stack[-1] @ m)
        try:
            c.ep.piece(g, c)
        finally:
            g.stack.pop()


ECHELLE_PIECE = 1.6
