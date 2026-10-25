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
from kit import SQ2, TAU

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
def tablier(g, c):
    M = g.M
    dd, zt = c.dd, c.zt
    zc = zt * 0.80
    g.box((0, 0, zc / 2.0), (2 * dd, 2 * dd, zc), M["steel_dk"], "hard", what="caisson")
    pm = [c.m(c.pont["mat"]), c.m(c.pont["mat2"])]
    motif = c.pont["motif"]
    pas = c.pont.get("pas") or {"dalles": 0.5, "planches": 0.18, "caillebotis": 0.5}.get(motif, 0.75)
    pas = max(0.25, pas) if motif != "planches" else max(0.15, pas)
    n = max(2, int(round(2 * dd / pas)))
    nu, nv = (n, 1) if motif == "planches" else (n, n)
    e = 0.04
    if c.pont.get("fond"):
        g.box((0, 0, zc + 0.003), (2 * dd - 2 * e, 2 * dd - 2 * e, 0.006), c.m(c.pont["fond"]), "flat", what="fond")
    q = [V((-dd + e, -dd + e, zc)), V((dd - e, -dd + e, zc)), V((dd - e, dd - e, zc)), V((-dd + e, dd - e, zc))]
    bou = c.pont.get("boulons")
    g.panels(q, nu, nv, pm[0], t=zt - zc, gap=0.025, rivet_mat=(c.m(bou) if bou else None), rivet_r=0.016,
             mats=pm, what="dessus")
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


def montants(g, c):
    r = c.dd - c.T["montant"]["retrait"]
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
    if abs(x) + r > d - 0.06 or abs(y) + r > d - 0.06:
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
    mr = d - T["montant"]["retrait"]
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
        g.dome((x + sx * (w / 2 - 0.035), y + sy * (w * 0.425 - 0.035), z + h), (0, 0, 1), 0.016, c.m("rivet"))
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
        g.dome((x + sx * (w / 2 - 0.04), y + sy * (w / 2 - 0.04), z + 0.02), (0, 0, 1), 0.016, c.m("rivet"))
    poutre(g, (x - 0.08, y + 0.05, z + 0.03), (x + 0.08, y + 0.05, z + 0.03), 0.025, c.m("steel"), "poignee")


def _bonbonne(g, c, x, y, rng):
    r = 0.08
    h = 0.3
    colonne(g, x, y, c.zt, c.zt + h, r, c.m("ochre"), n=14, what="bonbonne")
    g.sphere((x, y, c.zt + h), r, c.m("ochre"), n=14, m=6, scale=(1, 1, 0.6), what="ogive")
    colonne(g, x, y, c.zt + h + 0.03, c.zt + h + 0.08, 0.025, c.m("steel"), n=8, what="robinet")
    g.torus((x, y, c.zt + h + 0.09), "z", 0.04, 0.008, c.m("redpaint"), n=10, m=4, what="volant")


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
            c.occupe.append((x - RAYON_PROP[f], y - RAYON_PROP[f], x + RAYON_PROP[f], y + RAYON_PROP[f]))
            f(g, c, x, y, rng)
            poses += 1
    return poses


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
        if hasattr(c.ep, "tour"):
            c.ep.tour(g, c)
        else:
            with habille(g, c):
                tour_lignee(g, c)
        if hasattr(c.ep, "socle"):
            c.ep.socle(g, c)
        if getattr(c.ep, "GARNITURE", True):
            c.n_garniture = garniture(g, c, float(getattr(c.ep, "DENSITE", 0.6)))


def piece(g, c):
    """Pièce du niveau pair, posée sur le sommet de la tour (une fois pour les 4 directions)."""
    with repere(g, "N"):
        c.ep.piece(g, c)
