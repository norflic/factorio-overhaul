"""ORGANES du kit ateliers (lot DA-ATELIERS, 3/11), COPIE de calcul_o/organes.py + organes d'atelier en fin de fichier
(volant, roche, tas, courroie, flamme, haubans, trémie). Pièces posées dans un « Lot » (geo.py), modelées pour se lire à
32 px par tuile : dessus et face sud seulement comptent (caméra à 45° plein nord).

Repère : 1 unité = 1 tuile en X ; en Y, une tuile vaut D = 1,4142 unités (CALIBRATION : TILE_DEPTH_UNITS). Une emprise
N × N couvre x dans [-N/2, N/2], y dans [-N/2·D, N/2·D]. +Z : une unité monte de 0,707 tuile à l'écran.
"""
import math

import geo as G

D = 1.0 / math.cos(math.radians(45.0))
TAU = 2.0 * math.pi


class Kit:
    """Pose d'organes : mat = clé du dictionnaire M. mobile = lot des pièces animées (mêmes matières)."""

    def __init__(self, lot, M, seed=1, phase=0.0, lot_mobile=None):
        self.lot, self.M, self.r, self.phase = lot, M, G.Rnd(seed), phase
        self.fixe, self.lot_mobile = lot, lot_mobile or lot

    def mobile(self, oui=True):
        self.lot = self.lot_mobile if oui else self.fixe

    def put(self, mat, mesh):
        self.lot.put(self.M[mat], mesh)

    # ---------------------------------------------------------------------------------------- volumes
    def b(self, mat, c, s, rz=0.0, rx=0.0, ry=0.0):
        self.put(mat, G.boite(c, s, rz, rx, ry))

    def bz(self, mat, x, y, z0, sx, sy, sz, rz=0.0):
        """Boîte posée : pied en z0."""
        self.b(mat, (x, y, z0 + sz / 2.0), (sx, sy, sz), rz)

    def caisson(self, mat, x, y, z0, sx, sy, sz, ch=0.05):
        """Caisson à arêtes de toit chanfreinées : le dessus accroche la lumière."""
        hx, hy = sx / 2.0, sy / 2.0
        pz = z0 + sz - ch
        c = [(x - hx, y - hy), (x + hx, y - hy), (x + hx, y + hy), (x - hx, y + hy)]
        self.put(mat, G.prisme(c, z0, pz))
        k = 1.0 - 2.0 * ch / max(0.01, min(sx, sy))
        self.put(mat, G.prisme(c, pz, z0 + sz, k))

    def poly(self, mat, pts, z0, z1, k=1.0):
        self.put(mat, G.prisme(pts, z0, z1, k))

    def rev(self, mat, x, y, prof, segs=28, a0=0.0, a1=TAU, cap=True):
        """Révolution verticale : prof = [(z, r)] du bas vers le haut."""
        self.put(mat, G.tour(prof, segs, "z", (x, y, 0.0), a0, a1, cap0=cap, cap1=cap))

    def cyl(self, mat, x, y, z0, z1, r, segs=28):
        self.rev(mat, x, y, [(z0, r), (z1, r)], segs)

    def cuve(self, mat, x, y, z0, z1, r, tete=0.35, segs=32):
        """Cuve verticale à fond bombé."""
        h = r * tete
        p = [(z0, r), (z1 - h, r)]
        for i in range(1, 7):
            a = i / 6.0 * math.pi / 2
            p.append((z1 - h + h * math.sin(a), max(0.0, r * math.cos(a))))
        self.rev(mat, x, y, p, segs)

    def dome(self, mat, x, y, z0, r, kz=1.0, segs=36, zmin=0.0):
        p = []
        a0 = math.asin(zmin)
        for i in range(0, 11):
            a = a0 + i / 10.0 * (math.pi / 2 - a0)
            p.append((z0 + r * kz * (math.sin(a) - zmin), max(0.0, r * math.cos(a))))
        self.rev(mat, x, y, p, segs)

    def axe(self, mat, a, b, r, segs=24, cap=True):
        """Cylindre entre deux points."""
        self.put(mat, G.tube([a, b], r, segs, cap, cap))

    def sph(self, mat, c, r, seg=28, rings=14):
        self.put(mat, G.sphere(c, r, seg, rings))

    def tore(self, mat, x, y, z, R, r, seg=48, minor=10, a0=0.0, a1=TAU):
        """Tore horizontal (arc si a1 - a0 < 2π)."""
        pts = [(x + R * math.cos(a0 + (a1 - a0) * i / seg), y + R * math.sin(a0 + (a1 - a0) * i / seg), z) for i in range(seg + 1)]
        self.put(mat, G.tube(pts, r, minor, False, False))

    def cerclages(self, mat, x, y, zs, r, e=0.018, h=0.03, segs=28):
        for z in zs:
            self.rev(mat, x, y, [(z - h, r), (z - h, r + e), (z + h, r + e), (z + h, r)], segs, cap=False)

    # ---------------------------------------------------------------------------------------- tuyauterie
    def tuyau(self, mat, pts, r=0.07, coude=0.14, brides=None, bride_mat=None, segs=14):
        self.put(mat, G.tube(G.coudee(pts, coude), r, segs))
        for t in (brides if brides is not None else (pts[0], pts[-1])):
            self.bride(bride_mat or mat, t, pts, r)

    def bride(self, mat, p, pts, r):
        """Bride sur le segment de la polyligne qui contient p (ou près de p)."""
        best, d = None, 1e9
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            ab = G.sub(b, a)
            t = max(0.0, min(1.0, G.dot(G.sub(p, a), ab) / max(1e-9, G.dot(ab, ab))))
            q = G.add(a, G.mul(ab, t))
            dd = G.length(G.sub(p, q))
            if dd < d:
                best, d = G.norm(ab), dd
        self.collier(mat, p, best, r)

    def collier(self, mat, p, n, r, e=0.022, h=0.03):
        m = G.tour([(-h, r), (-h, r + e), (h, r + e), (h, r)], 14, "z")
        self.put(mat, G.oriente(m, p, n))

    def vanne(self, corps, volant, p, r=0.05, hauteur=0.1):
        """Vanne à volant sur un tuyau horizontal : corps, tige, volant visible du dessus."""
        x, y, z = p
        self.cyl(corps, x, y, z, z + r * 1.1, r * 1.05, 10)
        self.cyl(corps, x, y, z + r, z + r + hauteur, r * 0.25, 6)
        zv = z + r + hauteur
        self.tore(volant, x, y, zv, r * 1.5, r * 0.28, 16, 6)
        self.b(volant, (x, y, zv), (r * 3.0, r * 0.35, r * 0.3))
        self.b(volant, (x, y, zv), (r * 0.35, r * 3.0, r * 0.3))

    def cable(self, mat, a, b, fl=0.12, r=0.018, segs=7):
        self.put(mat, G.tube(G.chainette(a, b, fl), r, segs))

    def flexible(self, mat, ctrl, r=0.03, pas=0.05):
        """Flexible annelé le long d'une courbe."""
        pts = G.catmull(ctrl, 10)
        self.put(mat, G.tube(pts, r, 8, rfun=lambda s, i: r * (1.0 + 0.16 * math.sin(s / pas * TAU))))

    # ---------------------------------------------------------------------------------------- charpente, abords
    def echelle(self, mat, x, y, z0, z1, l=0.16, axe="x"):
        """Échelle contre une face sud : montants et barreaux."""
        dx = (l / 2.0, 0.0) if axe == "x" else (0.0, l / 2.0)
        for sg in (-1, 1):
            self.axe(mat, (x + sg * dx[0], y + sg * dx[1], z0), (x + sg * dx[0], y + sg * dx[1], z1), 0.012, 6)
        n = max(2, int((z1 - z0) / 0.1))
        for i in range(1, n):
            z = z0 + (z1 - z0) * i / n
            self.axe(mat, (x - dx[0], y - dx[1], z), (x + dx[0], y + dx[1], z), 0.009, 5)

    def rambarde(self, mat, pts, h=0.17, pas=0.3):
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            self.axe(mat, (a[0], a[1], a[2] + h), (b[0], b[1], b[2] + h), 0.011, 6)
            self.axe(mat, (a[0], a[1], a[2] + h * 0.55), (b[0], b[1], b[2] + h * 0.55), 0.008, 5)
            L = G.length(G.sub(b, a))
            n = max(1, int(L / pas))
            for j in range(n + 1):
                p = G.lerp(a, b, j / float(n))
                self.axe(mat, p, (p[0], p[1], p[2] + h), 0.01, 5)

    def treillis(self, mat, a, b, h, n=4, r=0.012):
        """Poutre en treillis de a à b (membrure basse), hauteur h."""
        up = (0.0, 0.0, h)
        self.axe(mat, a, b, r * 1.3, 6)
        self.axe(mat, G.add(a, up), G.add(b, up), r * 1.3, 6)
        for i in range(n):
            p, q = G.lerp(a, b, i / float(n)), G.lerp(a, b, (i + 1) / float(n))
            self.axe(mat, p, G.add(p, up), r, 5)
            self.axe(mat, p, G.add(q, up), r, 5)
        self.axe(mat, b, G.add(b, up), r, 5)

    def pied(self, mat, x, y, z1, r=0.07, sabot=None):
        """Pied télescopique court (âge 10 : les corps se lèvent)."""
        self.rev(sabot or mat, x, y, [(0.0, r * 1.7), (0.03, r * 1.7), (0.05, r * 1.0), (z1 * 0.5, r * 1.0), (z1 * 0.5, r * 0.72), (z1, r * 0.72)], 12)

    def sol(self, mat, N, h=0.08, ch=0.18, y0=-1.0, y1=1.0):
        """Plus de semelle (essai 1 : un pont plat sous chaque machine, défaut déjà refusé) : le sol se voit entre les organes,
        comme sous la raffinerie vanilla. Deux patins bas seulement, cachés sous la masse."""
        a = N / 2.0 - 0.25
        for sg in (-1, 1):
            self.b("noir", (sg * a * 0.7, 0.0, 0.015), (0.16, a * 1.6 * D, 0.03))
        return
        a = N / 2.0 - 0.04
        ay0, ay1 = a * D * y0, a * D * y1
        p = [(-a + ch, ay0), (a - ch, ay0), (a, ay0 + ch * D), (a, ay1 - ch * D), (a - ch, ay1), (-a + ch, ay1), (-a, ay1 - ch * D), (-a, ay0 + ch * D)]
        self.put(mat, G.prisme(p, 0.0, h, 0.985))

    # ---------------------------------------------------------------------------------------- faces sud
    def persiennes(self, mat, x, y, z, l, h, n=None, fond="noir"):
        """Grille à lames sur une face sud (y = face) : fond sombre, lames qui attrapent le ciel."""
        self.b(fond, (x, y - 0.004, z + h / 2.0), (l, 0.02, h))
        n = n or max(3, int(h / 0.055))
        for i in range(n):
            zz = z + h * (i + 0.5) / n
            self.b(mat, (x, y - 0.018, zz), (l * 0.96, 0.03, h / n * 0.5), rx=math.radians(38))

    def armoire(self, mat, x, y, z, l, h, e=0.14, joint="noir", poignee="acier_clair", lampe=None):
        """Armoire contre une face sud : portes séparées par un joint, poignée, voyant."""
        self.caisson(mat, x, y + e / 2.0, z, l, e, h, 0.015)
        n = 2 if l > 0.45 else 1
        for i in range(n):
            xx = x - l / 2.0 + l * (i + 0.5) / n
            self.b(mat, (xx, y - 0.006, z + h / 2.0), (l / n - 0.03, 0.012, h - 0.04))
            self.b(poignee, (xx + l / n / 2.0 - 0.05, y - 0.016, z + h * 0.52), (0.014, 0.012, 0.07))
        if lampe:
            self.voyant(lampe, x - l / 2.0 + 0.07, y - 0.02, z + h - 0.06, 0.018)

    def voyant(self, mat, x, y, z, r=0.022, boitier="noir"):
        """Voyant sur face sud : culot sombre et lentille."""
        self.axe(boitier, (x, y + 0.02, z), (x, y - 0.006, z), r * 1.35, 8)
        self.put(mat, G.oriente(G.tour([(0.0, r), (r * 0.5, r * 0.8), (r * 0.8, 0.0)], 8, "z"), (x, y - 0.006, z), (0.0, -1.0, 0.0)))

    def voyant_h(self, mat, x, y, z, r=0.025, boitier="noir"):
        """Voyant sur un dessus."""
        self.cyl(boitier, x, y, z, z + 0.012, r * 1.4, 8)
        self.rev(mat, x, y, [(z + 0.012, r), (z + 0.012 + r * 0.5, r * 0.8), (z + 0.012 + r * 0.8, 0.0)], 8)

    def rivets(self, mat, pts, n, r=0.016):
        self.put(mat, G.rivets_le_long([(p, n) for p in pts], r, r * 0.7))

    def rivets_ligne(self, mat, a, b, k, n=(0.0, -1.0, 0.0), r=0.014):
        self.rivets(mat, [G.lerp(a, b, i / float(max(1, k - 1))) for i in range(k)], n, r)

    def plaque(self, mat, x, y, z, l=0.14, h=0.08):
        self.b(mat, (x, y - 0.004, z), (l, 0.01, h))

    def boulons_rond(self, mat, x, y, z, R, k, r=0.016):
        self.rivets(mat, [(x + R * math.cos(TAU * i / k), y + R * math.sin(TAU * i / k), z) for i in range(k)], (0.0, 0.0, 1.0), r)

    # ---------------------------------------------------------------------------------------- pièces marquées
    def ventilo(self, x, y, z, R, corps="noir", lame="acier_clair", grille="acier", moyeu="acier", ph=None, lames=7, garde=True):
        """Ventilateur à axe vertical : virole, lames (mobiles), grille. ph : phase (0 à 1) ; None = phase du kit."""
        self.rev(corps, x, y, [(z - 0.1, R * 1.14), (z + 0.03, R * 1.1), (z + 0.03, R * 1.0), (z - 0.12, R * 0.98)], 28, cap=False)
        self.cyl("noir", x, y, z - 0.13, z - 0.1, R, 24)
        a0 = (self.phase if ph is None else ph) * TAU / lames
        self.mobile(True)
        for i in range(lames):
            a = a0 + TAU * i / lames
            p0 = (x + R * 0.22 * math.cos(a), y + R * 0.22 * math.sin(a), z - 0.04)
            p1 = (x + R * 0.95 * math.cos(a + 0.26), y + R * 0.95 * math.sin(a + 0.26), z - 0.09)
            w = R * 0.34
            n = (-math.sin(a), math.cos(a), 0.0)
            q0, q1 = G.add(p0, G.mul(n, -w * 0.3)), G.add(p1, G.mul(n, -w * 0.5))
            q2, q3 = G.add(p1, G.mul(n, w * 0.5)), G.add(p0, G.mul(n, w * 0.3))
            quad = [q0, q1, (q2[0], q2[1], q2[2] + 0.035), (q3[0], q3[1], q3[2] + 0.03)]
            self.put(lame, (quad, [(0, 1, 2, 3)], [(0, 0), (1, 0), (1, 1), (0, 1)]))
        self.cyl(moyeu, x, y, z - 0.09, z - 0.015, R * 0.2, 12)
        self.mobile(False)
        if garde:
            for r in (R * 0.42, R * 0.72, R * 0.98):
                self.tore(grille, x, y, z + 0.022, r, 0.0075, 28, 4)
            for i in range(4):
                a = math.pi / 4 + i * math.pi / 2
                self.axe(grille, (x, y, z + 0.022), (x + R * math.cos(a), y + R * math.sin(a), z + 0.022), 0.0085, 4)

    def echangeur(self, x, y, z0, L, r, mat, bride="acier", axe="x", tetes=True, cerc=4):
        """Corps cylindrique horizontal (échangeur, tambour) à fonds bombés, viroles, sur berceaux."""
        zc = z0 + r
        c = (x, y, zc)
        prof = []
        for i in range(6):
            a = i / 5.0 * math.pi / 2
            prof.append((-L / 2.0 - r * 0.28 * math.cos(a), max(0.001, r * math.sin(a))))
        for i in range(6):
            a = i / 5.0 * math.pi / 2
            prof.append((L / 2.0 + r * 0.28 * math.sin(a), max(0.001, r * math.cos(a))))
        self.put(mat, G.tour(prof, 28, axe, c))
        if tetes:
            for t in (-L / 2.0, L / 2.0):
                self.put(bride, G.tour([(t - 0.03, r), (t - 0.03, r + 0.022), (t + 0.03, r + 0.022), (t + 0.03, r)], 28, axe, c))
        for i in range(cerc):
            t = -L / 2.0 + L * (i + 1.0) / (cerc + 1.0)
            self.put(bride, G.tour([(t - 0.012, r), (t - 0.012, r + 0.012), (t + 0.012, r + 0.012), (t + 0.012, r)], 28, axe, c))
        for t in (-L * 0.32, L * 0.32):
            px = (x + t, y) if axe == "x" else (x, y + t)
            sx, sy = (0.09, r * 1.5) if axe == "x" else (r * 1.5, 0.09)
            self.b(bride, (px[0], px[1], z0 + r * 0.32), (sx, sy, r * 0.65))

    def moteur(self, mat, x, y, z, L, r, ailette="noir", axe="x"):
        """Moteur à ailettes, couché : corps, ailettes, flasques."""
        c = (x, y, z + r)
        self.put(mat, G.tour([(-L / 2, 0.001), (-L / 2, r * 0.88), (L / 2, r * 0.88), (L / 2, 0.001)], 16, axe, c))
        n = int(L / 0.035)
        for i in range(1, n):
            t = -L / 2.0 + L * i / n
            self.put(ailette, G.tour([(t - 0.006, r * 0.86), (t - 0.006, r), (t + 0.006, r), (t + 0.006, r * 0.86)], 16, axe, c))

    def chevrons(self, x, y, z, l, h=0.07, mat="chevron"):
        self.b(mat, (x, y - 0.004, z), (l, 0.012, h))

    def pose_tole(self, mat, x, y, z, l, h):
        """Tôle de rapiéçage rivetée sur une face sud."""
        self.b(mat, (x, y - 0.007, z + h / 2.0), (l, 0.012, h))
        pts = [(x + sx * (l / 2.0 - 0.02), y - 0.014, z + (0.02 if sz < 0 else h - 0.02)) for sx in (-1, 1) for sz in (-1, 1)]
        self.rivets("riv", pts, (0.0, -1.0, 0.0), 0.011)

    # ---------------------------------------------------------------------------------------- organes d'atelier (DA-ATELIERS)
    def T(self, tx, ty, z=0.0):
        """Point en tuiles (tx est, ty nord) et hauteur z en unités."""
        return (tx, ty * D, z)

    def volant(self, c, R, axe="y", larg=0.12, rayons=6, jante="acier", moyeu="acier_clair", ph=0.0, ep=None, mobile=True,
               repere="jaune"):
        """Volant à rayons : jante épaisse, moyeu, rayons ; axe « y » (face à la caméra) ou « z » (à plat). ph : angle en tours."""
        ep = ep or R * 0.16
        x, y, z = c
        if mobile:
            self.mobile(True)
        h = larg / 2.0
        prof = [(-h, R - ep), (-h, R), (h, R), (h, R - ep), (-h, R - ep)]
        self.put(jante, G.tour(prof, 44, axe, c))
        self.put(jante, G.tour([(-h * 0.7, R * 0.2), (-h * 0.7, R * 0.25), (h * 0.7, R * 0.25), (h * 0.7, R * 0.2)], 20, axe, c))
        a0 = ph * TAU
        for i in range(rayons):
            a = a0 + TAU * i / rayons
            ca, sa = math.cos(a), math.sin(a)
            if axe == "y":
                p0, p1 = (x + R * 0.22 * ca, y, z + R * 0.22 * sa), (x + (R - ep * 0.6) * ca, y, z + (R - ep * 0.6) * sa)
            else:
                p0, p1 = (x + R * 0.22 * ca, y + R * 0.22 * sa, z), (x + (R - ep * 0.6) * ca, y + (R - ep * 0.6) * sa, z)
            self.axe(jante, p0, p1, max(0.022, R * 0.055), 8)
        self.put(moyeu, G.tour([(-h * 1.4, 0.001), (-h * 1.4, R * 0.19), (h * 1.4, R * 0.19), (h * 1.4, 0.001)], 18, axe, c))
        if repere and axe == "y":
            a = a0 + 0.4
            self.b(repere, (x + (R - ep * 0.5) * math.cos(a), y - h - 0.006, z + (R - ep * 0.5) * math.sin(a)),
                   (ep * 0.9, 0.012, ep * 0.55), ry=-a)
        if mobile:
            self.mobile(False)

    def roche(self, mat, c, r, kz=0.75, seg=7):
        """Morceau de roche : sphère grossière aux sommets bosselés (déterministe)."""
        v, f, u = G.sphere(c, r, seg, 4)
        out = []
        for p in v:
            d = G.sub(p, c)
            k = self.r.f(0.7, 1.2)
            out.append((c[0] + d[0] * k, c[1] + d[1] * k, c[2] + d[2] * k * kz))
        self.put(mat, (out, f, u))

    def roches(self, mat, x0, x1, y0, y1, z, n, r0=0.05, r1=0.1, mats=None, dz=0.03):
        for i in range(n):
            m = mats[i % len(mats)] if mats else mat
            self.roche(m, (self.r.f(x0, x1), self.r.f(y0, y1), z + self.r.f(-dz, dz)), self.r.f(r0, r1))

    def tas(self, mat, x, y, rx, ry, h, expo=1.6, bosses=0.2):
        """Tas au sol ; expo < 1 : cône (sommet pointu, pied évasé) ; 1,6 : galette (défaut de la phase 2)."""
        self.put(mat, G.butte_polaire((x, y, 0.0), rx, ry, h, self.r, nr=10, na=36, bosses=bosses, bord=0.14, expo=expo))

    def cone(self, mat, x, y, r, h, grains=None, n=10):
        """Tas en cône (sommet clair et pointu, pied évasé) avec quelques grains posés dessus (critique : « cônes ombrés »)."""
        # vu à 45°, un cône de pente 45° a son sommet SUR le contour et se lit comme un disque : il faut h ≥ 1,5 r
        self.rev(mat, x, y, [(0.0, r), (h * 0.06, r * 0.9), (h * 0.45, r * 0.52), (h * 0.85, r * 0.14), (h, 0.0)], 30)
        for i in range(n):
            a_ = self.r.f(0.0, TAU)
            t = self.r.f(0.15, 0.85)
            rr = r * (1.0 - t) * 0.95
            self.roche(grains or mat, (x + rr * math.cos(a_), y + rr * math.sin(a_), h * t * 0.95), self.r.f(0.018, 0.035))

    def courroie(self, mat, a, ra, b, rb, n_axe, larg=0.06, e=0.016):
        """Courroie entre deux poulies de centres a et b (même plan, normale n_axe) : deux brins tangents, aplatis."""
        d = G.norm(G.sub(b, a))
        perp = G.norm(G.cross(n_axe, d))
        for sg in (-1, 1):
            p = G.add(a, G.mul(perp, sg * ra))
            q = G.add(b, G.mul(perp, sg * rb))
            L = G.length(G.sub(q, p))
            mid = G.mul(G.add(p, q), 0.5)
            self.put(mat, _plat(mid, G.norm(G.sub(q, p)), n_axe, L, larg, e))

    def flamme(self, mat, x, y, z0, h, r, langues=5, penche=(0.12, 0.0)):
        """Flamme libre : plusieurs langues (révolutions bosselées) qui s'effilent et penchent ; dans le lot « flamme »
        (rendue dans les seules passes glow et light, batch_blender)."""
        lot = self.lot
        self.lot = getattr(self, "lot_flamme", lot)
        for i in range(langues):
            a = TAU * i / langues + self.r.f(-0.3, 0.3)
            ox, oy = r * 0.4 * math.cos(a), r * 0.4 * math.sin(a)
            hh = h * self.r.f(0.5, 0.85)
            rr = r * self.r.f(0.4, 0.7)
            if i == 0:
                ox = oy = 0.0
                hh, rr = h, r
            rings = []
            n = 16
            for j in range(n + 1):
                t = j / float(n)
                rad = rr * (math.sin(min(1.0, t * 2.2) * math.pi / 2) ** 0.5) * (1.0 - t) ** 1.1 + 0.003
                cx = x + ox + penche[0] * hh * t * t + 0.025 * math.sin(t * 9.0 + i * 1.7) * t
                cy = y + oy + penche[1] * hh * t * t + 0.025 * math.cos(t * 7.0 + i * 2.3) * t
                ring = []
                for q in range(18):
                    b_ = TAU * q / 18
                    w = 1.0 + 0.2 * math.sin(3 * b_ + i + t * 7.0) * t
                    ring.append((cx + rad * w * math.cos(b_), cy + rad * w * math.sin(b_), z0 + hh * t))
                rings.append(ring)
            self.put(mat, G.loft(rings, cap0=True, cap1=True))
        self.lot = lot

    def hauban(self, mat, a, b, r=0.009, fl=0.02):
        self.put(mat, G.tube(G.chainette(a, b, fl, 10), r, 5, False, False))

    def bandes_cyl(self, mats, x, y, z0, z1, r, n, segs=24):
        """Cylindre vertical peint en bandes alternées (balisage)."""
        for i in range(n):
            za, zb = z0 + (z1 - z0) * i / n, z0 + (z1 - z0) * (i + 1) / n
            self.rev(mats[i % len(mats)], x, y, [(za, r), (zb, r)], segs, cap=(i == n - 1))

    def tremie(self, mat, x, y, z0, z1, l0, p0, l1, p1):
        """Trémie en tronc de pyramide renversé : bas (l0 × p0) en z0, haut (l1 × p1) en z1 ; parois minces ouvertes en haut."""
        e = 0.03
        for (sx, sy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if sx:
                a0, a1 = (x + sx * l0 / 2.0, y), (x + sx * l1 / 2.0, y)
                pts = [(a0[0], y - p0 / 2.0, z0), (a0[0], y + p0 / 2.0, z0), (a1[0], y + p1 / 2.0, z1), (a1[0], y - p1 / 2.0, z1)]
            else:
                a0, a1 = (x, y + sy * p0 / 2.0), (x, y + sy * p1 / 2.0)
                pts = [(x - l0 / 2.0, a0[1], z0), (x + l0 / 2.0, a0[1], z0), (x + l1 / 2.0, a1[1], z1), (x - l1 / 2.0, a1[1], z1)]
            n = G.norm(G.cross(G.sub(pts[1], pts[0]), G.sub(pts[3], pts[0])))
            out = [G.add(p, G.mul(n, -e / 2.0)) for p in pts] + [G.add(p, G.mul(n, e / 2.0)) for p in pts]
            faces = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
            uvs = [(p[0] + p[2], p[1] + p[2]) for p in out]
            self.put(mat, (out, faces, uvs))
        # rebord du haut
        for (sx, sy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if sx:
                self.b(mat, (x + sx * l1 / 2.0, y, z1), (0.05, p1 + 0.05, 0.05))
            else:
                self.b(mat, (x, y + sy * p1 / 2.0, z1), (l1 + 0.05, 0.05, 0.05))


def _plat(mid, t, n, L, larg, e):
    """Bande plate centrée en mid, de longueur L le long de t, largeur larg le long de n, épaisseur e."""
    w = G.norm(G.cross(t, n))
    verts, uvs = [], []
    hs = (L / 2.0, larg / 2.0, e / 2.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                verts.append(G.add(mid, G.add(G.mul(t, sx * hs[0]), G.add(G.mul(n, sy * hs[1]), G.mul(w, sz * hs[2])))))
                uvs.append((sx * hs[0], sy * hs[1]))

    def idx(sx, sy, sz):
        return ((sx + 1) // 2) * 4 + ((sy + 1) // 2) * 2 + (sz + 1) // 2
    quads = (((-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1)), ((-1, -1, 1), (-1, 1, 1), (1, 1, 1), (1, -1, 1)),
             ((-1, -1, -1), (-1, -1, 1), (1, -1, 1), (1, -1, -1)), ((-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1)),
             ((-1, -1, -1), (-1, 1, -1), (-1, 1, 1), (-1, -1, 1)), ((1, -1, -1), (1, -1, 1), (1, 1, 1), (1, 1, -1)))
    faces = [tuple(idx(*c) for c in q) for q in quads]
    return verts, faces, uvs
