"""CORPS DE LIGNÉE DU CENTRE DE COMMANDEMENT (lot F5-A, 27/10). S'exécute DANS Blender (mathutils).

Bastion à étages vu de trois quarts (contrat : epoques.py) : SOCLE, ÉTAGES (plan d'âge), TOIT, MÂT de l'âge, PORTE
blindée au sud, SATELLITES aux coins, FAÇADE (fenêtres éclairées, conduits d'angle), GARDE-CORPS de la terrasse du premier
étage, FEUX aux coins du socle, DÉTAIL FIN semé sur le socle libre. Repère des tuiles (x est, y nord, z haut), étiré de √2
en y par `repere` (même convention que la foreuse). Aides de forme recopiées de foreuse_e/corps.py (kit voisin, non
importé pour garder les kits indépendants).
"""
import math

from mathutils import Matrix, Vector

import cotes
from habillage import habille, mats_habilles
from kit import SQ2, TAU

V = Vector
LIGNEE_PONT = dict(motif="toles", mat="armor", mat2="armor2", fond="seam", bord="steel_dk", boulons="rivet",
                   lisere=None, pas=None)
RIVET = 0.024          # rivets visibles au zoom 1 (leçon de la foreuse F4-A3)


class Ctx:
    def __init__(self, g, e, ep, side, hab):
        self.g, self.M, self.e, self.ep, self.side, self.hab = g, g.M, e, ep, side, hab
        self.T = cotes.taille(side)
        self.Mh = mats_habilles(g.M, hab)
        T = self.T
        self.dd, self.zt = T["dd"], T["zt"]
        self.plan = hab.get("plan") or "carre"
        self.n_etages = int(hab.get("etages") or 2)
        self.toit = hab.get("toit") or "plat"
        p = hab.get("plateforme") or {}
        if isinstance(p, str):
            p = dict(motif=p)
        self.pont = dict(LIGNEE_PONT)
        self.pont.update({k: v for k, v in p.items() if k in LIGNEE_PONT and v is not None})
        self.occupe = list(ep.occupe(self)) if hasattr(ep, "occupe") else []
        self.z_etages = []
        g.ctx = self

    def m(self, cle):
        return self.Mh[cle] if cle in self.Mh else self.M[cle]

    def mat_etage(self, k):
        cle = self.hab.get("mat_e%d" % (k + 1))
        if cle:
            return self.m(cle)
        return self.m(("olive", "ochre", "olive")[k])


class repere:
    """Repère des tuiles du centre (y étiré de √2), comme corps.repere de la foreuse tournée vers le nord."""

    def __init__(self, g):
        self.g = g

    def __enter__(self):
        self.g.stack.append(self.g.stack[-1] @ Matrix.Diagonal((1.0, SQ2, 1.0, 1.0)))
        return self.g

    def __exit__(self, *exc):
        self.g.stack.pop()


# ------------------------------------------------------------------------------------------------
# Aides de forme
# ------------------------------------------------------------------------------------------------
def quart(p, k):
    x, y = p[0], p[1]
    for _ in range(k % 4):
        x, y = -y, x
    return (x, y) + tuple(p[2:])


def sym4(p):
    return [quart(p, k) for k in range(4)]


def poutre(g, p0, p1, w, m, what="poutre", h=None):
    """Poutre de section rectangulaire (w × h) entre deux points (copie de foreuse_e/corps.poutre)."""
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
    g.tube_shell((x, y, z), "z", r + ep, r - 0.002, h, m, n=n, what=what)


def dalle(g, x0, y0, x1, y1, z0, z1, m, style="hard", what="dalle"):
    g.box(((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0), (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), m, style,
          what=what)


def halo(g, p, M, power=3.0, cle="_emit_rgb"):
    g.halo(p, M[cle], power)


def prisme(g, pts, z0, z1, m, style="hard", what="prisme"):
    n = len(pts)
    vs = [(x, y, z0) for x, y in pts] + [(x, y, z1) for x, y in pts]
    fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, n + j, n + i))
    g._add(m, style, vs, fs, what)


def octogone(h, coupe=0.32):
    k = coupe * h
    pts = []
    for q in range(4):
        for p in ((h, -(h - k)), (h, h - k)):
            pts.append(quart(p, q)[:2])
    return pts


def cercle(h, n=40):
    return [(h * math.cos(TAU * i / n), h * math.sin(TAU * i / n)) for i in range(n)]


def contour(plan, h):
    """Contour (sens direct) d'une forme d'étage de demi-côté h (la croix rend None : deux rectangles)."""
    if plan == "rond":
        return cercle(h)
    if plan == "octo":
        return octogone(h)
    if plan in ("carre", "tours"):
        return [(-h, -h), (h, -h), (h, h), (-h, h)]
    return None


def dans_forme(plan, h, x, y, r=0.0):
    if plan == "rond":
        return math.hypot(x, y) < h - r
    if abs(x) > h - r or abs(y) > h - r:
        return False
    if plan == "octo":
        return abs(x) + abs(y) < 2 * h - 0.32 * h - r * SQ2
    if plan == "croix":
        b = 0.55 * h
        return abs(x) < b - r or abs(y) < b - r
    return True


def bande_danger(g, q, n=5):
    g.hazard([V(p) for p in q], n, t=0.008)


# ------------------------------------------------------------------------------------------------
# Socle
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    dd, zt = c.dd, c.zt
    zc = zt * 0.8
    pm = [c.m(c.pont["mat"]), c.m(c.pont["mat2"])]
    bou = c.pont.get("boulons")
    forme = "carre" if c.plan in ("carre", "tours", "croix") else c.plan
    if forme == "carre":
        g.box((0, 0, zc / 2.0), (2 * dd, 2 * dd, zc), M["steel_dk"], "hard", what="caisson")
        motif = c.pont["motif"]
        pas = c.pont.get("pas") or {"dalles": 0.5, "planches": 0.18}.get(motif, 0.6)
        pas = max(0.25, min(0.6, pas)) if motif != "planches" else max(0.15, pas)
        n = max(2, int(round(2 * dd / pas)))
        nu, nv = (n, 1) if motif == "planches" else (n, n)
        e = 0.04
        q = [V((-dd + e, -dd + e, zc)), V((dd - e, -dd + e, zc)), V((dd - e, dd - e, zc)), V((-dd + e, dd - e, zc))]
        g.box((0, 0, zc + 0.003), (2 * dd - 2 * e, 2 * dd - 2 * e, 0.006), c.m(c.pont["fond"]), "flat", what="fond")
        g.panels(q, nu, nv, pm[0], t=zt - zc, gap=0.025, rivet_mat=(c.m(bou) if bou else None), rivet_r=RIVET,
                 rivet_step=0.11, mats=pm, what="dessus")
        b = c.m(c.pont["bord"])
        for k in range(4):
            p0 = quart((-dd, dd - 0.03), k)
            p1 = quart((dd, dd - 0.03), k)
            sx, sy = (2 * dd, 0.06) if k % 2 == 0 else (0.06, 2 * dd)
            g.box(((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, zt + 0.01), (sx, sy, 0.06), b, "hard", what="corniere")
    else:
        ext = contour(forme, dd)
        prisme(g, ext, 0.0, zc, M["steel_dk"], what="caisson")
        # secteurs en damier, 4 bandes, rivets au bord de chaque plaque
        nsec = 24 if forme == "rond" else 16
        r0 = 0.25
        for i in range(nsec):
            a0, a1 = TAU * i / nsec, TAU * (i + 1) / nsec
            for b_, (t0, t1) in enumerate(((0.0, 0.3), (0.3, 0.55), (0.55, 0.78), (0.78, 1.0))):
                rr0, rr1 = r0 + (dd - 0.06 - r0) * t0, r0 + (dd - 0.06 - r0) * t1
                if forme == "octo":
                    # rayon du contour octogonal dans la direction de l'angle (approximation : rayon du pan)
                    f0 = _rayon_octo(dd - 0.06, (a0 + a1) / 2.0) / (dd - 0.06)
                    rr0, rr1 = rr0 * f0 if b_ else rr0, rr1 * f0
                quad = [(rr0 * math.cos(a0 + 0.01), rr0 * math.sin(a0 + 0.01)),
                        (rr1 * math.cos(a0 + 0.01), rr1 * math.sin(a0 + 0.01)),
                        (rr1 * math.cos(a1 - 0.01), rr1 * math.sin(a1 - 0.01)),
                        (rr0 * math.cos(a1 - 0.01), rr0 * math.sin(a1 - 0.01))]
                pts = [V((x, y, zc)) for x, y in quad] + [V((x, y, zt)) for x, y in quad]
                g.hexa(pts, pm[(i + b_) % 2], "hard", "secteur")
                if bou:
                    am = (a0 + a1) / 2.0
                    for t in (0.25, 0.75):
                        rr = rr0 + (rr1 - rr0) * t
                        g.dome((rr * math.cos(am), rr * math.sin(am), zt), (0, 0, 1), RIVET, c.m(bou))
        colonne(g, 0, 0, zc, zt, r0 + 0.02, pm[1], n=32, what="disque_central")
        b = c.m(c.pont["bord"])
        for i in range(len(ext)):
            a, bb = ext[i], ext[(i + 1) % len(ext)]
            poutre(g, (a[0], a[1], zt + 0.01), (bb[0], bb[1], zt + 0.01), 0.06, b, "corniere")
    if hasattr(c.ep, "socle"):
        c.ep.socle(g, c)


def _rayon_octo(d, a):
    """Distance du centre au contour octogonal (pan coupé 0,32) dans la direction a."""
    best = d / max(abs(math.cos(a)), abs(math.sin(a)), 1e-6)
    diag = (2 - 0.32) * d / SQ2 / max(abs(math.cos(a - math.pi / 4)), abs(math.cos(a + math.pi / 4)), 1e-6)
    return min(best, diag)


def sur_socle(c, x, y, r=0.0, marge=0.06):
    d = c.dd - marge - r
    if c.plan in ("carre", "tours", "croix"):
        return abs(x) < d and abs(y) < d
    if c.plan == "rond":
        return math.hypot(x, y) < d
    return abs(x) < d and abs(y) < d and abs(x) + abs(y) < 2 * c.dd - 0.32 * c.dd - (marge + r) * SQ2


# ------------------------------------------------------------------------------------------------
# Étages, toit
# ------------------------------------------------------------------------------------------------
def corps_forme(g, c, plan, h, z0, z1, m, what="etage"):
    if plan == "croix":
        b = 0.55 * h
        g.box((0, 0, (z0 + z1) / 2), (2 * h, 2 * b, z1 - z0), m, "hard", what=what)
        g.box((0, 0, (z0 + z1) / 2), (2 * b, 2 * h, z1 - z0), m, "hard", what=what)
        return
    if plan == "rond":
        colonne(g, 0, 0, z0, z1, h, m, n=48, style="smooth", what=what)
        return
    if plan == "octo":
        prisme(g, octogone(h), z0, z1, m, what=what)
        return
    g.box((0, 0, (z0 + z1) / 2), (2 * h, 2 * h, z1 - z0), m, "hard", what=what)
    if plan == "tours":
        rt = 0.3 * h
        for (x, y) in sym4((h * 0.92, h * 0.92)):
            colonne(g, x, y, z0, z1 + 0.18, rt, m, n=20, what="tour_angle")
            colonne(g, x, y, z1 + 0.18, z1 + 0.24, rt * 1.12, c_m(g, "steel_dk"), n=20, style="hard", what="couronne")


def c_m(g, cle):
    return g.ctx.m(cle)


def corniche(g, c, plan, h, z, m):
    if plan == "croix":
        b = 0.55 * h
        g.box((0, 0, z), (2 * h + 0.06, 2 * b + 0.06, 0.05), m, "hard", what="corniche")
        g.box((0, 0, z), (2 * b + 0.06, 2 * h + 0.06, 0.05), m, "hard", what="corniche")
    elif plan == "rond":
        colonne(g, 0, 0, z - 0.025, z + 0.025, h + 0.03, m, n=48, style="hard", what="corniche")
    elif plan == "octo":
        prisme(g, octogone(h + 0.03), z - 0.025, z + 0.025, m, what="corniche")
    else:
        g.box((0, 0, z), (2 * h + 0.06, 2 * h + 0.06, 0.05), m, "hard", what="corniche")


def fenetres(g, c, plan, h, z0, z1, k):
    """Fenêtres éclairées sur les faces visibles (sud, et est pour les plans carrés), en bandeau à mi-hauteur."""
    M = g.M
    zf = z0 + (z1 - z0) * 0.55
    hf = min(0.12, (z1 - z0) * 0.3)
    lum = M["emit_soft"]
    cad = c.m("steel_dk")
    if plan in ("rond", "octo"):
        n = max(5, int(2 * h * 1.6 / 0.32))
        for i in range(n):
            a = math.radians(205 + 130 * (i + 0.5) / n)
            r = h if plan == "rond" else _rayon_octo(h, a)
            x, y = (r + 0.004) * math.cos(a), (r + 0.004) * math.sin(a)
            g.push((x, y, zf), rz=a)
            g.box((0, 0, 0), (0.02, 0.13, hf + 0.04), cad, "hard", what="cadre")
            g.box((0.008, 0, 0), (0.012, 0.09, hf), lum, "flat", what="fenetre")
            g.pop()
        return
    faces = [("S", -1)]
    if plan in ("carre", "tours"):
        faces.append(("E", 1))
    for face, s in faces:
        n = max(2, int(2 * h * 0.8 / 0.3))
        for i in range(n):
            t = -h * 0.8 + 1.6 * h * (i + 0.5) / n
            if face == "S":
                if k == 0 and abs(t) < c.T["porte"]["w"] / 2 + 0.16:
                    continue
                x, y, sx, sy = t, -h - 0.006, 0.12, 0.02
                lx, ly = 0.085, 0.012
            else:
                x, y, sx, sy = h + 0.006, t, 0.02, 0.12
                lx, ly = 0.012, 0.085
            g.box((x, y, zf), (sx, sy, hf + 0.04), cad, "hard", what="cadre")
            g.box((x + (0.006 if face == "E" else 0), y - (0.006 if face == "S" else 0), zf), (lx, ly, hf), lum, "flat",
                  what="fenetre")


def etages(g, c):
    """Étages en retrait ; rend la cote du dessus du dernier étage."""
    T = c.T
    z = c.zt
    for k in range(c.n_etages):
        h, H = T["h"][k], T["H"][k]
        m = c.mat_etage(k)
        if c.plan in ("carre", "tours"):
            g.box((0, 0, z + 0.03), (2 * h + 0.08, 2 * h + 0.08, 0.06), c.m("steel_dk"), "hard", what="plinthe")
        corps_forme(g, c, c.plan, h, z, z + H, m)
        corniche(g, c, c.plan, h, z + H - 0.02, c.m("steel_dk"))
        fenetres(g, c, c.plan, h, z, z + H, k)
        c.z_etages.append((z, z + H, h))
        z += H
    return z


def toit(g, c, z):
    """Toit du dernier étage ; rend la cote où se pose le mât."""
    M = g.M
    h = c.T["h"][c.n_etages - 1]
    mt = c.m(c.hab.get("mat_toit") or "steel_dk")
    pa = c.T["parapet"]
    if c.toit in ("plat", "crenele"):
        # parapet le long du contour, dalle de toit, merlons si crénelé
        pts = contour(c.plan, h) or contour("carre", h)
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            poutre(g, (a[0], a[1], z + pa / 2), (b[0], b[1], z + pa / 2), 0.05, mt, "parapet", h=pa)
        if c.toit == "crenele":
            for i in range(len(pts)):
                a, b = pts[i], pts[(i + 1) % len(pts)]
                L = math.dist(a, b)
                n = max(1, int(L / 0.2))
                for j in range(n):
                    t = (j + 0.5) / n
                    g.box((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, z + pa + 0.05), (0.09, 0.09, 0.1), mt,
                          "hard", what="merlon")
        # équipements de toit (bouches d'aération, caissons)
        for (x, y) in ((-0.45 * h, 0.4 * h), (0.5 * h, 0.45 * h), (0.42 * h, -0.4 * h)):
            g.box((x, y, z + 0.05), (0.16, 0.12, 0.1), c.m("steel"), "hard", what="caisson_toit")
            g.box((x, y - 0.065, z + 0.05), (0.12, 0.012, 0.06), M["void"], "flat", what="bouche")
        return z
    if c.toit == "coupole":
        g.sphere((0, 0, z), h * 0.92, mt, n=40, m=16, scale=(1, 1, 0.62), what="coupole")
        bague(g, 0, 0, z + 0.02, h * 0.92, 0.05, c.m("steel_dk"), ep=0.03, n=40, what="anneau_coupole")
        for i in range(12):
            a = TAU * i / 12
            poutre(g, (h * 0.9 * math.cos(a), h * 0.9 * math.sin(a), z + 0.03),
                   (h * 0.5 * math.cos(a), h * 0.5 * math.sin(a), z + h * 0.92 * 0.62 * 0.86), 0.035, c.m("steel_dk"),
                   "nervure")
        return z + h * 0.92 * 0.62
    if c.toit == "pans":
        # deux pans (faîte est-ouest), pignons pleins
        hp = h * 0.55
        for s in (-1, 1):
            q = [V((-h - 0.05, s * (h + 0.06), z)), V((h + 0.05, s * (h + 0.06), z)), V((h + 0.05, 0.0, z + hp)),
                 V((-h - 0.05, 0.0, z + hp))]
            if s > 0:
                q = [q[1], q[0], q[3], q[2]]
            g.hexa(q + [p + V((0, 0, 0.05)) for p in q], mt, "hard", "pan")
        for sx in (-1, 1):
            pts = [V((sx * h, -h, z)), V((sx * h, h, z)), V((sx * h, 0.0, z + hp))]
            g._add(c.mat_etage(c.n_etages - 1), "hard", [tuple(p) for p in pts], [(0, 1, 2) if sx > 0 else (0, 2, 1)],
                   "pignon")
        poutre(g, (-h - 0.06, 0, z + hp + 0.02), (h + 0.06, 0, z + hp + 0.02), 0.06, c.m("steel_dk"), "faitage")
        return z + hp
    if c.toit == "gradins":
        zz = z
        hh = h
        for k in range(2):
            hh *= 0.72
            corps_forme(g, c, c.plan, hh, zz, zz + 0.12, mt, what="gradin")
            zz += 0.12
        return zz
    return z


# ------------------------------------------------------------------------------------------------
# Porte, satellites, façade, garde-corps, feux
# ------------------------------------------------------------------------------------------------
def porte(g, c):
    """PORTE BLINDÉE au milieu de la face sud du premier étage (signal de jeu fixe) et sa rampe."""
    M = g.M
    P = c.T["porte"]
    w, hp = P["w"], P["h"]
    h1 = c.T["h"][0]
    y = -h1 if c.plan != "rond" else -h1 + 0.02
    z0 = c.zt
    with habille(g, c):
        g.box((0, y - 0.03, z0 + hp / 2 + 0.03), (w + 0.16, 0.06, hp + 0.06), c.m("steel_dk"), "hard", what="chambranle")
        g.box((0, y - 0.05, z0 + hp / 2), (w, 0.02, hp), c.m("steel"), "hard", what="vantail")
        g.box((0, y - 0.062, z0 + hp / 2), (0.012, 0.004, hp * 0.95), M["void"], "flat", what="joint_porte")
        bande_danger(g, [(-w / 2, y - 0.064, z0 + 0.02), (w / 2, y - 0.064, z0 + 0.02), (w / 2, y - 0.064, z0 + 0.1),
                         (-w / 2, y - 0.064, z0 + 0.1)], n=6)
        g.box((0, y - 0.07, z0 + hp + 0.1), (w * 0.5, 0.03, 0.04), M["amber"], "flat", what="feu_porte")
        # rampe jusqu'au bord du socle
        dalle(g, -w / 2 - 0.06, -c.dd + 0.08, w / 2 + 0.06, y - 0.06, c.zt - 0.01, c.zt + 0.02, c.m("steel_dk"),
              what="rampe")
        bande_danger(g, [(-w / 2 - 0.06, -c.dd + 0.1, c.zt + 0.021), (w / 2 + 0.06, -c.dd + 0.1, c.zt + 0.021),
                         (w / 2 + 0.06, -c.dd + 0.2, c.zt + 0.021), (-w / 2 - 0.06, -c.dd + 0.2, c.zt + 0.021)], n=6)
    halo(g, (0, y - 0.35, z0 + hp + 0.15), M, 1.8, cle="_emit_rgb")
    c.occupe.append((-w / 2 - 0.2, -c.dd, w / 2 + 0.2, y + 0.05))
    if hasattr(c.ep, "porte"):
        c.ep.porte(g, c, y, z0)


def satellite_lignee(g, c, x, y, z, k):
    """Petite tourelle (satellite de la mitrailleuse) : fût, collier, tête et deux canons vers l'extérieur."""
    S = c.T["sat"]
    r = S["r"]
    ang = math.atan2(y, x)
    with habille(g, c):
        colonne(g, x, y, z, z + 0.14, r, c.m("steel_dk"), n=16, style="hard", what="sat_fut")
        bague(g, x, y, z + 0.14, r * 0.95, 0.03, c.m("ochre"), ep=0.02, n=16, what="sat_collier")
        colonne(g, x, y, z + 0.14, z + 0.27, r * 0.78, c.m("olive"), n=12, style="hard", what="sat_tete")
        g.sphere((x, y, z + 0.27), r * 0.7, c.m("olive"), n=16, m=8, scale=(1, 1, 0.55), what="sat_dome")
        for s in (-1, 1):
            u = (math.cos(ang), math.sin(ang))
            v = (-u[1] * 0.05 * s, u[0] * 0.05 * s)
            p0 = (x + u[0] * r * 0.5 + v[0], y + u[1] * r * 0.5 + v[1], z + 0.22)
            p1 = (x + u[0] * (r + 0.24) + v[0], y + u[1] * (r + 0.24) + v[1], z + 0.24)
            g.cyl(((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2),
                  (p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]), 0.022, math.dist(p0, p1), c.m("steel"), n=8,
                  what="sat_canon")
        for i in range(8):
            a = TAU * i / 8
            g.dome((x + r * 1.0 * math.cos(a), y + r * 1.0 * math.sin(a), z + 0.07), (math.cos(a), math.sin(a), 0),
                   RIVET, c.m("rivet"))
    g.dome((x, y, z + 0.27 + r * 0.38), (0, 0, 1), 0.03, g.M["emit"], what="sat_feu")


def satellites(g, c):
    S = c.T["sat"]
    d = c.dd - S["retrait"]
    coins = [(-d, -d), (d, -d)]
    if c.side >= 6:
        coins += [(d, d), (-d, d)]
    f = getattr(c.ep, "satellite", satellite_lignee)
    for k, (x, y) in enumerate(coins):
        f(g, c, x, y, c.zt, k)
        r = S["r"] + 0.12
        c.occupe.append((x - r, y - r, x + r, y + r))


def conduits(g, c):
    """Conduits d'angle de la façade sud du premier étage, du socle à la corniche, colliers boulonnés."""
    h1, H1 = c.T["h"][0], c.T["H"][0]
    if c.plan in ("rond", "octo"):
        pts = [(h1 * math.cos(math.radians(a)), h1 * math.sin(math.radians(a))) for a in (238, 302)]
        pts = [(x * 1.03, y * 1.03) for x, y in pts]
    elif c.plan == "croix":
        b = 0.55 * h1
        pts = [(-b - 0.06, -h1 - 0.04), (b + 0.06, -h1 - 0.04)]
    else:
        pts = [(-h1 * 0.92, -h1 - 0.05), (h1 * 0.92, -h1 - 0.05)]
    r = 0.04 + 0.004 * c.side
    lia = getattr(c.ep, "liaison", None)
    for (x, y) in pts:
        p = [(x, y, c.zt + 0.02), (x, y, c.zt + H1 * 0.5), (x, y, c.zt + H1 - 0.04)]
        if lia is not None:
            lia(g, p, r)
        else:
            with habille(g, c):
                g.pipe(p, r, c.m("steel"), fl_mat=c.m("steel_dk"), bolt_mat=c.m("rivet"), what="conduit")
        c.occupe.append((x - 0.15, y - 0.15, x + 0.15, y + 0.15))


def garde_corps(g, c):
    """Garde-corps sur la terrasse du premier étage (autour du second), poteaux tous les 0,17 t."""
    if c.n_etages < 2:
        return 0
    h1 = c.T["h"][0]
    z0 = c.z_etages[0][1]
    pts = contour(c.plan, h1 - 0.07)
    if pts is None:
        b = 0.55 * (h1 - 0.07)
        hh = h1 - 0.07
        pts = [(-hh, -b), (-b, -b), (-b, -hh), (b, -hh), (b, -b), (hh, -b), (hh, b), (b, b), (b, hh), (-b, hh), (-b, b),
               (-hh, b)]
    h2 = c.T["h"][1]
    mp = c.m("ochre")
    ml = g.M["steel_hi"]
    n = 0
    for i in range(len(pts)):
        a, b_ = pts[i], pts[(i + 1) % len(pts)]
        L = math.dist(a, b_)
        k = max(1, int(L / 0.17))
        prev = None
        for j in range(k + 1):
            t = j / float(k)
            x, y = a[0] + (b_[0] - a[0]) * t, a[1] + (b_[1] - a[1]) * t
            if dans_forme(c.plan, h2 + 0.05, x, y):
                prev = None
                continue
            g.cyl((x, y, z0 + 0.06), "z", 0.014, 0.12, mp, n=6, style="hard", what="poteau")
            n += 1
            if prev is not None:
                for zz in (0.12, 0.065):
                    g.tube([(prev[0], prev[1], z0 + zz), ((prev[0] + x) / 2, (prev[1] + y) / 2, z0 + zz), (x, y, z0 + zz)],
                           0.008, ml, n=5, what="lisse")
            prev = (x, y)
    return n


def feux(g, c):
    M = g.M
    d = c.dd - 0.16
    for (x, y) in sym4((d, d)):
        if not sur_socle(c, x, y, 0.05):
            x, y = x * 0.82, y * 0.82
        with habille(g, c):
            colonne(g, x, y, c.zt, c.zt + 0.22, 0.04, c.m("steel_dk"), n=8, style="hard", what="mat_feu")
        g.dome((x, y, c.zt + 0.22), (0, 0, 1), 0.04, M["emit"], what="feu")
        halo(g, (x, y, c.zt + 0.3), M, 1.2)
        c.occupe.append((x - 0.12, y - 0.12, x + 0.12, y + 0.12))


# ------------------------------------------------------------------------------------------------
# Détail fin (leçon de la foreuse F4-A3)
# ------------------------------------------------------------------------------------------------
def _f_boulons(g, c, x, y, z, rng, M):
    g.box((x, y, z + 0.006), (0.12, 0.12, 0.016), c.m("steel_dk"), "hard", what="platine")
    for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        g.dome((x + sx * 0.034, y + sy * 0.034, z + 0.014), (0, 0, 1), 0.022, M["steel_hi"], what="boulon")


def _f_bouchon(g, c, x, y, z, rng, M):
    g.cyl((x, y, z + 0.018), "z", 0.045, 0.036, c.m("steel"), n=12, style="hard", what="bouchon")
    g.cyl((x, y, z + 0.037), "z", 0.024, 0.004, M["void"], n=10, style="flat", what="bouchon_trou")


def _f_event(g, c, x, y, z, rng, M):
    g.box((x, y, z + 0.01), (0.15, 0.1, 0.02), c.m("steel"), "hard", what="event")
    for k in (-1, 0, 1):
        g.box((x, y + k * 0.028, z + 0.0205), (0.108, 0.016, 0.002), M["void"], "flat", what="fente")


def _f_plaquette(g, c, x, y, z, rng, M):
    m = M["steel_hi"] if rng.random() < 0.5 else c.m("ochre")
    g.box((x, y, z + 0.008), (0.1, 0.065, 0.016), m, "hard", what="plaquette")
    g.box((x - 0.02, y, z + 0.0165), (0.04, 0.012, 0.002), M["void"], "flat", what="inscription")


def _f_voyant(g, c, x, y, z, rng, M):
    g.cyl((x, y, z + 0.016), "z", 0.04, 0.032, c.m("steel_dk"), n=12, style="hard", what="boitier")
    g.dome((x, y, z + 0.032), (0, 0, 1), 0.026, M["emit"], what="voyant")


def _f_caisse(g, c, x, y, z, rng, M):
    w = 0.13 + 0.05 * rng.random()
    g.box((x, y, z + w * 0.4), (w, w * 0.8, w * 0.8), c.m("olive") if rng.random() < 0.5 else c.m("ochre"), "hard",
          what="caisse")
    g.box((x, y, z + w * 0.45), (w + 0.01, w * 0.8 + 0.01, 0.02), c.m("steel_dk"), "hard", what="sangle")


FINS = ((_f_boulons, 0.28), (_f_bouchon, 0.18), (_f_event, 0.14), (_f_plaquette, 0.14), (_f_caisse, 0.12))


def libre(c, x, y, r):
    if not sur_socle(c, x, y, r, 0.1):
        return False
    if dans_forme(c.plan, c.T["h"][0] + 0.06, x, y, -r):
        return False
    for (x0, y0, x1, y1) in c.occupe:
        if min(x0, x1) - r < x < max(x0, x1) + r and min(y0, y1) - r < y < max(y0, y1) + r:
            return False
    return True


def detail_fin(g, c):
    import random
    rng = random.Random(13000 + 31 * c.e + c.side)
    M = g.M
    pas = float(getattr(c.ep, "PAS_FIN", 0.15))
    part = float(getattr(c.ep, "FIN", 0.9))
    lampes = float(getattr(c.ep, "LAMPES", 0.14))
    tot = sum(w for _, w in FINS)
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
            if not libre(c, x, y, 0.07):
                continue
            if u4 < lampes:
                f = _f_voyant
            else:
                r = rng.random() * tot
                f = FINS[-1][0]
                for ff, w in FINS:
                    if r < w:
                        f = ff
                        break
                    r -= w
            f(g, c, x, y, z, rng, M)
            poses += 1
    return poses


# ------------------------------------------------------------------------------------------------
# Assemblage
# ------------------------------------------------------------------------------------------------
def centre(g, c):
    """Centre complet de l'âge (variante eNN-centre) ou témoin (kS-centre)."""
    with repere(g):
        with habille(g, c):
            socle(g, c)
        z = etages(g, c)
        with habille(g, c):
            zm = toit(g, c, z)
        porte(g, c)
        conduits(g, c)
        satellites(g, c)
        feux(g, c)
        c.n_garde_corps = garde_corps(g, c)
        if hasattr(c.ep, "facade"):
            c.ep.facade(g, c)
        c.ep.mat(g, c, zm)
        c.n_fin = detail_fin(g, c)
