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
        if getattr(c.ep, "MOTIF_DALLE", False) and motif == "dalles":
            # ronde 2b (âge 10) : motif fin à chaque dalle visible (pastille sombre et quatre plots), comme le tablier
            # de la foreuse de l'âge 10 (F4-A4)
            su, h1 = (2 * dd - 2 * e) / nu, c.T["h"][0]
            mm = c.m(getattr(c.ep, "MOTIF_MAT", "steel_dk"))
            c.n_pastilles = 0
            for i in range(nu):
                for j in range(nv):
                    x, y = -dd + e + (i + 0.5) * su, -dd + e + (j + 0.5) * su
                    if dans_forme(c.plan, h1 + 0.04, x, y, -su / 2):
                        continue
                    g.box((x, y, zt + 0.006), (su * 0.42, su * 0.42, 0.012), mm, "hard", what="pastille")
                    for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                        g.dome((x + sx * su * 0.32, y + sy * su * 0.32, zt), (0, 0, 1), 0.018, M["steel_hi"], what="plot")
                    c.n_pastilles += 1
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
                if getattr(c.ep, "MOTIF_SECTEUR", False) and b_ >= 1:
                    # ronde 2c : plaquettes claires le long de chaque secteur visible (hors du premier étage)
                    rm = (rr0 + rr1) / 2.0
                    nsub = max(1, int(rm * (a1 - a0) / 0.3))
                    for u in range(nsub):
                        au = a0 + (a1 - a0) * (u + 0.5) / nsub
                        xu, yu = rm * math.cos(au), rm * math.sin(au)
                        if dans_forme(c.plan, c.T["h"][0] + 0.04, xu, yu, -0.08):
                            continue
                        g.push((xu, yu, zt), rz=au)
                        g.box((0, 0, 0.006), (0.1, 0.12, 0.012), c.m(getattr(c.ep, "MOTIF_MAT", "steel_hi")), "hard",
                              what="plaquette_secteur")
                        g.pop()
                        c.n_plaquettes = getattr(c, "n_plaquettes", 0) + 1
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
    lum = M[getattr(c.ep, "FENETRES", "emit_soft")]
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


def assise_satellite(g, c, x, y, z, k):
    """Ronde F5-A2 : ASSISE de la mitrailleuse satellite (la mitrailleuse VALIDÉE du même âge est composée après le rendu
    par satellites.py, bible des familles : « satellites de la mitrailleuse ») : platine ronde boulonnée, au ras du socle."""
    r = cotes.cote_satellite(c.side) * 0.5
    with habille(g, c):
        colonne(g, x, y, z - 0.01, z + 0.03, r * 1.02, c.m("steel_dk"), n=24, style="hard", what="assise_sat")
    n = 12
    for i in range(n):
        a = TAU * (i + 0.5) / n
        g.dome((x + r * 0.9 * math.cos(a), y + r * 0.9 * math.sin(a), z + 0.03), (0, 0, 1), RIVET, c.m("rivet"))


def projecteur(g, c, x, y, z, k):
    """Coin arrière (emprises de 6 et plus) : mât de projecteur, lampe de la couleur de l'âge et halo de nuit."""
    M = g.M
    hm = 0.5 + 0.06 * c.side
    with habille(g, c):
        colonne(g, x, y, z, z + 0.08, 0.14, c.m("steel_dk"), n=12, style="hard", what="pied_projecteur")
        colonne(g, x, y, z + 0.08, z + hm, 0.04, c.m("steel"), n=8, what="mat_projecteur")
        g.box((x, y, z + hm + 0.05), (0.2, 0.12, 0.1), c.m("olive"), "hard", what="projecteur")
    g.box((x, y - 0.065, z + hm + 0.05), (0.15, 0.012, 0.07), M["emit"], "flat", what="lampe_projecteur")
    halo(g, (x, y - 0.25, z + hm), M, 2.0)


def satellites(g, c):
    """Avant : assises des mitrailleuses satellites (composées après le rendu) ; arrière : projecteurs. Avec
    ep.SATELLITES_3D (témoin) : les petites tourelles de la ronde 1."""
    avant, arriere = cotes.coins_satellites(c.side, c.plan)
    if getattr(c.ep, "SATELLITES_3D", False):
        f_av = f_ar = getattr(c.ep, "satellite", satellite_lignee)
    else:
        f_av, f_ar = assise_satellite, projecteur
    for k, (x, y) in enumerate(avant):
        f_av(g, c, x, y, c.zt, k)
        r = max(c.T["sat"]["r"], cotes.cote_satellite(c.side) * 0.5) + 0.12
        c.occupe.append((x - r, y - r, x + r, y + r))
    for k, (x, y) in enumerate(arriere):
        f_ar(g, c, x, y, c.zt, k)
        r = c.T["sat"]["r"] + 0.12
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
    # sur les diagonales, DANS le socle (ronde 1 : aux socles ronds, le feu tombait hors du socle : îlot de 67 px)
    if c.plan == "rond":
        d = (c.dd - 0.2) / SQ2
    elif c.plan == "octo":
        d = (1.188 * c.dd - 0.2) / SQ2
    else:
        d = c.dd - 0.16
    for (x, y) in sym4((d, d)):
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


def detail_toits(g, c, zm):
    """Détail fin sur les terrasses des étages (anneau entre l'étage k et l'étage k + 1, en retrait du garde-corps) et
    sur le toit plat du dernier étage (hors mât)."""
    if getattr(c.ep, "ARCHI", False):
        return _toits_archi(g, c)
    import random
    rng = random.Random(17000 + 31 * c.e + c.side)
    M = g.M
    pas = float(getattr(c.ep, "PAS_FIN", 0.15))
    lampes = float(getattr(c.ep, "LAMPES", 0.14))
    tot = sum(w for _, w in FINS)
    poses = 0
    n_et = len(c.z_etages)
    for k in range(n_et):
        z0, z1, h = c.z_etages[k]
        if k + 1 < n_et:
            hin = c.z_etages[k + 1][2] + 0.1
        elif c.toit in ("plat", "crenele"):
            hin = 0.32 * c.side / 4.5
        else:
            continue
        hout = h - (0.2 if k == 0 else 0.12)
        n = int(2 * hout / pas)
        o = -hout + (2 * hout - n * pas) / 2.0 + pas / 2.0
        for i in range(n):
            for j in range(n):
                u2, u3, u4, u5 = rng.random(), rng.random(), rng.random(), rng.random()
                x = o + i * pas + (u2 - 0.5) * pas * 0.35
                y = o + j * pas + (u3 - 0.5) * pas * 0.35
                # ronde 1b : terrasses moins garnies (0,85 → 0,45 : moucheté à la ronde 1)
                if u5 > (0.25 if getattr(c.ep, "ARCHI", False) else 0.45) or not dans_forme(c.plan, hout, x, y, 0.07) \
                        or dans_forme(c.plan, hin, x, y, -0.07) or (getattr(c.ep, "ARCHI", False) and k == 0 and y < 0):
                    continue
                if k + 1 == n_et and math.hypot(x, y) < hin:
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
                f(g, c, x, y, z1 - 0.012, rng, M)
                poses += 1
    return poses


def _lanterneau(g, c, x, y, z, M, lit):
    """Lanterneau de toit : cadre (sombre, ou clair si ep.CADRE_TOIT : ronde 2c), verre fumé (ou éclairé), traverse."""
    g.box((x, y, z + 0.016), (0.17, 0.15, 0.032), c.m(getattr(c.ep, "CADRE_TOIT", "steel_dk")), "hard", what="lanterneau")
    g.box((x, y, z + 0.035), (0.13, 0.11, 0.008), M["emit_soft"] if lit else c.m("glass_dk"), "hard", what="vitre_toit")
    g.box((x, y, z + 0.04), (0.012, 0.11, 0.004), c.m("steel_hi"), "flat", what="traverse")


def _toits_archi(g, c):
    """Ronde 2b (âges à ep.ARCHI) : terrasses et toit garnis en RANGÉES (lanterneaux et ouïes de ventilation en lignes
    alternées, un voyant de loin en loin) au lieu du moucheté au hasard ; la terrasse sud du premier étage est à la
    verrière."""
    import random
    rng = random.Random(29000 + 31 * c.e + c.side)
    M = g.M
    pas = float(getattr(c.ep, "PAS_TOIT", 0.28))
    poses = 0
    n_et = len(c.z_etages)
    for k in range(n_et):
        z0, z1, h = c.z_etages[k]
        reserve = None
        if k + 1 < n_et:
            hin = c.z_etages[k + 1][2] + 0.12
        elif c.toit in ("plat", "crenele"):
            hin = max(0.32 * c.side / 4.5, float(getattr(c.ep, "RAYON_MAT", 0.45)) * getattr(c, "echelle_mat", 1.0) + 0.08)
            if hasattr(c.ep, "TOIT_RESERVE"):      # ronde 2c : place prise par l'organe, donnée par l'âge (rectangle)
                reserve, hin = c.ep.TOIT_RESERVE(c), 0.0
        else:
            continue
        hout = h - (0.22 if k == 0 else 0.14)
        n = int(2 * hout / pas)
        o = -hout + (2 * hout - n * pas) / 2.0 + pas / 2.0
        for j in range(n):
            for i in range(n):
                x, y = o + i * pas, o + j * pas
                if not dans_forme(c.plan, hout, x, y, 0.09) or dans_forme(c.plan, hin, x, y, -0.09):
                    continue
                if k + 1 == n_et and math.hypot(x, y) < hin:
                    continue
                if reserve and reserve[0] < x < reserve[2] and reserve[1] < y < reserve[3]:
                    continue
                if k == 0 and y < 0 and 195 < math.degrees(math.atan2(y, x)) % 360 < 345:
                    continue
                if j % 2 == 0:
                    _lanterneau(g, c, x, y, z1 - 0.012, M, rng.random() < 0.2)
                elif i % 4 == 1:
                    _f_voyant(g, c, x, y, z1 - 0.012, rng, M)
                else:
                    _f_event(g, c, x, y, z1 - 0.012, rng, M)
                poses += 1
    return poses


def bornes(g, c):
    """Ronde 2b (âges à ep.ARCHI) : allée de BORNES autour du pied du premier étage, sur le socle (hors porte, hors
    satellites et feux : corps.libre)."""
    if not getattr(c.ep, "ARCHI", False):
        return 0
    h1, dd = c.T["h"][0], c.dd
    r = h1 + 0.3 * (dd - h1)
    plan = c.plan if c.plan in ("rond", "octo") else "carre"
    pas = 0.25
    n = int(2 * math.pi * r / pas) if plan == "rond" else int(8 * r / pas)
    poses = 0
    for i in range(n):
        a = math.tau * (i + 0.5) / n
        rr = _rayon_forme(plan, r, a)
        x, y = rr * math.cos(a), rr * math.sin(a)
        if not libre(c, x, y, 0.06):
            continue
        colonne(g, x, y, c.zt, c.zt + 0.07, 0.03, c.m("steel_dk"), n=8, style="hard", what="borne")
        g.dome((x, y, c.zt + 0.07), (0, 0, 1), 0.03, c.m("steel_hi") if i % 3 else g.M["emit"], what="tete_borne")
        c.occupe.append((x - 0.06, y - 0.06, x + 0.06, y + 0.06))
        poses += 1
    c.n_bornes = poses
    return poses



# ------------------------------------------------------------------------------------------------
# Ronde F5-A2 : ARCHITECTURE des grands étages (âges à ep.ARCHI) au lieu du « moucheté » des terrasses : CONTREFORTS
# le long des faces visibles, BALCON en saillie au sud du deuxième étage, VERRIÈRE en appentis sur la terrasse du premier
# étage (vitres sombres à meneaux, une sur trois éclairée la nuit), BAIES hautes éclairées entre les contreforts.
# ------------------------------------------------------------------------------------------------
def _rayon_forme(plan, h, a):
    if plan == "rond":
        return h
    if plan == "octo":
        return _rayon_octo(h, a)
    return h / max(abs(math.cos(a)), abs(math.sin(a)), 1e-6)


def _contreforts(g, c, k):
    z0, z1, h = c.z_etages[k]
    H = z1 - z0
    m = c.m("steel_dk")
    mc = c.mat_etage(k)
    porte = c.T["porte"]["w"] / 2 + 0.25
    n = max(5, int(3.2 * h / 0.55))
    for i in range(n):
        a = math.radians(200 + 140 * (i + 0.5) / n)
        r = _rayon_forme(c.plan if c.plan != "croix" else "carre", h, a)
        x, y = r * math.cos(a), r * math.sin(a)
        if c.plan == "croix" and not dans_forme("croix", h + 0.02, x * 0.98, y * 0.98):
            continue
        if k == 0 and abs(x) < porte and y < 0:
            continue
        g.push((x, y, z0), rz=a)
        g.box((0.06, 0, H * 0.36), (0.16, 0.11, H * 0.72), mc, "hard", what="contrefort")
        g.box((0.09, 0, H * 0.74), (0.12, 0.13, 0.05), m, "hard", what="chaperon")
        g.box((0.14, 0, H * 0.04), (0.08, 0.15, 0.08), m, "hard", what="sabot")
        for zz in (0.25, 0.5):
            g.dome((0.145, 0, H * zz), (1, 0, 0), RIVET, c.m("rivet"))
        g.pop()


def _baies(g, c, k):
    """Baies hautes éclairées sur la face sud de l'étage k (entre les contreforts)."""
    z0, z1, h = c.z_etages[k]
    H = z1 - z0
    M = g.M
    porte = c.T["porte"]["w"] / 2 + 0.3
    n = max(3, int(2 * h / 0.42))
    for i in range(n):
        a = math.radians(205 + 130 * (i + 0.5) / n)
        r = _rayon_forme(c.plan if c.plan != "croix" else "carre", h, a)
        x, y = r * math.cos(a), r * math.sin(a)
        if (k == 0 and abs(x) < porte) or (c.plan == "croix" and not dans_forme("croix", h + 0.02, x * 0.98, y * 0.98)):
            continue
        g.push((x, y, z0), rz=a)
        g.box((0.006, 0, H * 0.5), (0.02, 0.15, H * 0.62), c.m("steel_dk"), "hard", what="cadre_baie")
        g.box((0.016, 0, H * 0.5), (0.008, 0.1, H * 0.55), M["emit_soft"], "flat", what="baie")
        g.box((0.022, 0, H * 0.5), (0.006, 0.012, H * 0.55), c.m("steel"), "flat", what="meneau_baie")
        g.pop()


def _balcon(g, c, k):
    z0, z1, h = c.z_etages[k]
    H = z1 - z0
    w = min(1.1, 0.9 * h)
    zb = z0 + H * 0.42
    y = -h - 0.12
    if c.plan == "croix":
        y = -h - 0.12
    with habille(g, c):
        g.box((0, y, zb), (2 * w, 0.26, 0.05), c.m("steel_dk"), "hard", what="balcon")
        for s in (-1, 1):
            g.box((s * w * 0.8, -h - 0.05, zb - 0.12), (0.05, 0.12, 0.2), c.m("steel"), "hard", what="console")
    n = int(2 * w / 0.12)
    for i in range(n + 1):
        x = -w + 2 * w * i / n
        g.cyl((x, y - 0.11, zb + 0.07), "z", 0.011, 0.11, c.m("ochre"), n=6, style="hard", what="balustre")
    poutre(g, (-w, y - 0.11, zb + 0.13), (w, y - 0.11, zb + 0.13), 0.02, g.M["steel_hi"], "main_courante")


def _verriere(g, c):
    """Verrière en appentis sur la terrasse du premier étage, au sud, contre le deuxième étage."""
    if len(c.z_etages) < 2:
        return
    z0, z1, h1 = c.z_etages[0]
    h2 = c.z_etages[1][2]
    M = g.M
    plan = c.plan if c.plan != "croix" else "carre"
    n = max(6, int(4.0 * h1 / 0.3))
    import random
    rng = random.Random(23000 + 31 * c.e + c.side)
    lum = float(getattr(c.ep, "VERRIERE_LUM", 0.3))
    for i in range(n):
        a0 = math.radians(205 + 130 * i / n)
        a1 = math.radians(205 + 130 * (i + 1) / n)
        am = (a0 + a1) / 2
        if 262 < math.degrees(am) < 278:
            continue
        rin0, rin1 = _rayon_forme(plan, h2, a0) + 0.02, _rayon_forme(plan, h2, a1) + 0.02
        rout0, rout1 = _rayon_forme(plan, h1, a0) - 0.16, _rayon_forme(plan, h1, a1) - 0.16
        if c.plan == "croix":
            xm, ym = math.cos(am) * (rin0 + rout0) / 2, math.sin(am) * (rin0 + rout0) / 2
            if not dans_forme("croix", h1 - 0.1, xm, ym):
                continue
        if rout0 - rin0 < 0.18:
            continue
        p = [(rout0 * math.cos(a0), rout0 * math.sin(a0), z1 + 0.04), (rout1 * math.cos(a1), rout1 * math.sin(a1), z1 + 0.04),
             (rin1 * math.cos(a1), rin1 * math.sin(a1), z1 + 0.26), (rin0 * math.cos(a0), rin0 * math.sin(a0), z1 + 0.26)]
        # ronde 2b : la ronde 2 (une vitre par secteur, une sur trois lumineuse) se lisait en RAYONS de soleil ; châssis
        # sombre et vitres découpées le long de la pente (traverses), verre fumé, quelques carreaux éclairés au hasard
        pts = [V(q) for q in p] + [V((q[0], q[1], q[2] + 0.02)) for q in p]
        g.hexa(pts, c.m(getattr(c.ep, "CHASSIS", "steel_dk")), "hard", "chassis_verriere")   # ronde 2c : clair (ep)
        c.n_chassis = getattr(c, "n_chassis", 0) + 1
        L = math.hypot(p[3][0] - p[0][0], p[3][1] - p[0][1])
        ns = max(2, int(round(L / 0.2)))

        def Q(s, t):
            return tuple((1 - t) * ((1 - s) * p[0][d] + s * p[1][d]) + t * ((1 - s) * p[3][d] + s * p[2][d])
                         for d in range(3))
        for j in range(ns):
            t0, t1 = (j + 0.08) / ns, (j + 0.92) / ns
            qs = [Q(0.1, t0), Q(0.9, t0), Q(0.9, t1), Q(0.1, t1)]
            pts = [V((q[0], q[1], q[2] + 0.02)) for q in qs] + [V((q[0], q[1], q[2] + 0.032)) for q in qs]
            lit = rng.random() < lum
            g.hexa(pts, M["emit_soft"] if lit else c.m("glass_dk"), "hard", "vitre")
            c.n_vitres = getattr(c, "n_vitres", 0) + 1
        haut = 0.035
        poutre(g, (p[0][0], p[0][1], p[0][2] + haut), (p[3][0], p[3][1], p[3][2] + haut), 0.02, c.m("steel_hi"), "meneau")
        poutre(g, p[0], p[1], 0.03, c.m("steel_dk"), "bord_verriere")
        if i % 4 == 2:
            cx = sum(q[0] for q in p) / 4.0
            cy = sum(q[1] for q in p) / 4.0
            halo(g, (cx, cy, z1 + 0.45), M, 1.6)


def _hublots(g, c, k):
    """Ronde 2c (ep.HUBLOTS) : rang de hublots carrés à cadre clair au bas de la face sud de l'étage k (sous les baies),
    un sur trois éclairé."""
    z0, z1, h = c.z_etages[k]
    H = z1 - z0
    M = g.M
    plan = c.plan if c.plan != "croix" else "carre"
    porte = c.T["porte"]["w"] / 2 + 0.3
    arc = math.radians(130) * h
    n = max(6, int(arc / 0.16))
    for i in range(n):
        a = math.radians(205 + 130 * (i + 0.5) / n)
        r = _rayon_forme(plan, h, a)
        x, y = r * math.cos(a), r * math.sin(a)
        if (k == 0 and abs(x) < porte) or (c.plan == "croix" and not dans_forme("croix", h + 0.02, x * 0.98, y * 0.98)):
            continue
        g.push((x, y, z0), rz=a)
        g.box((0.006, 0, H * 0.18), (0.016, 0.1, 0.09), c.m("steel_hi"), "hard", what="cadre_hublot")
        g.box((0.015, 0, H * 0.18), (0.006, 0.066, 0.06), M["emit_soft"] if i % 3 == 1 else c.m("glass_dk"), "flat",
              what="hublot")
        g.pop()


def architecture(g, c):
    if not getattr(c.ep, "ARCHI", False):
        return
    for k in range(len(c.z_etages)):
        _contreforts(g, c, k)
        _baies(g, c, k)
        if getattr(c.ep, "HUBLOTS", False):
            _hublots(g, c, k)
    if len(c.z_etages) >= 2:
        _balcon(g, c, 1)
    _verriere(g, c)


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
        architecture(g, c)
        if hasattr(c.ep, "facade"):
            c.ep.facade(g, c)
        # le mât est dessiné pour une emprise de 4,5 t : mis à l'échelle de l'emprise autour de son pied (essai 1 : trop
        # petit sur les 7×7 et 8×8)
        # ronde 1b : × 1,4 (mâts peu lisibles en ronde 1), BORNÉ pour que le pied de l'organe (ep.RAYON_MAT, rayon de ce
        # qui touche le toit, avant échelle) reste sur le dernier étage (rien ne flotte) ; ep.ECHELLE_MAT force l'échelle
        h = c.T["h"][c.n_etages - 1] * {"gradins": 0.518, "coupole": 0.45}.get(c.toit, 1.0)
        k = min(1.4 * c.side / 4.5, 0.92 * h / float(getattr(c.ep, "RAYON_MAT", 0.45)))
        k = float(getattr(c.ep, "ECHELLE_MAT", k))
        c.echelle_mat = k
        g.stack.append(g.stack[-1] @ Matrix.Translation((0.0, 0.0, zm)) @ Matrix.Diagonal((k, k, k, 1.0))
                       @ Matrix.Translation((0.0, 0.0, -zm)))
        try:
            c.ep.mat(g, c, zm)
        finally:
            g.stack.pop()
        bornes(g, c)
        c.n_fin = detail_fin(g, c)
        c.n_fin_toits = detail_toits(g, c, zm)
