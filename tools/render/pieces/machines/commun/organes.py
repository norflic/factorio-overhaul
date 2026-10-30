"""ORGANES du kit machines (lot DESIGN-CALCUL CALC-MACHINES-AMONT, 30/10) : pièces industrielles fonctionnelles
(caissons rivetés, cuves, brides boulonnées, tuyauterie, vannes à volant, garde-corps, échelles, grilles, armoires,
moteurs, ailettes, voyants) posées dans un geo.Lot. Charte DA_FACTORIO §4 : chaque volume a une fonction lisible ;
les petites pièces (rivets, boulons, brides, montants) portent la densité de détail (≈ 29 par tuile²).

Repère : celui de tools/render/README.md (1 unité = 1 tuile en X ; +Y nord ; une tuile de jeu en Y vaut SQ2 unités ;
z vers le haut, 1 unité de hauteur = 45 px HR). Épaisseur minimale d'un élément : 2 px HR = 0,031 unité.
Rien n'importe bpy ici (géométrie pure, testable hors Blender) ; les matières sont des clés du dictionnaire M.
"""
import math

import geo
from geo import TAU, boite, coudee, merge, oriente, tour, tube

SQ2 = 1.0 / math.cos(math.radians(45.0))
EP = 0.032          # épaisseur minimale (2 px HR)


def Y(yn):
    """y de jeu (tuiles, vers le NORD) -> Y Blender."""
    return yn * SQ2


class Kit:
    """Pose des organes : lot (geo.Lot), M (matières par clé), rnd (geo.Rnd). Compte les petites pièces posées."""

    def __init__(self, lot, M, seed=1):
        self.lot = lot
        self.M = M
        self.rnd = geo.Rnd(seed)
        self.petites = 0

    # ------------------------------------------------------------------------------------------ bas niveau
    def put(self, mat, mesh, petite=False):
        self.lot.put(self.M[mat], mesh)
        if petite:
            self.petites += 1

    def box(self, mat, c, s, rz=0.0, rx=0.0, ry=0.0, petite=False):
        self.put(mat, boite(c, s, rz, rx, ry), petite)

    def rivets(self, pts_normals, mat="rivet", r=0.02, h=0.014):
        if not pts_normals:
            return
        self.put(mat, geo.rivets_le_long(pts_normals, r, h))
        self.petites += len(pts_normals)

    def ligne(self, a, b, pas):
        """Points régulièrement espacés entre a et b (bouts exclus d'un demi-pas)."""
        L = geo.length(geo.sub(b, a))
        n = max(1, int(L / pas))
        return [geo.lerp(a, b, (i + 0.5) / n) for i in range(n)]

    # ------------------------------------------------------------------------------------------ caissons
    def caisson(self, mat, x0, x1, y0, y1, z0, z1, rivets=True, pas=0.13, rebord="trim", rebord_h=0.035,
                faces=("top", "south", "east", "west"), rmat="rivet"):
        """Caisson de tôle (boîte), rebord saillant autour du dessus, rivets le long des arêtes visibles."""
        c = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
        self.box(mat, c, (x1 - x0, y1 - y0, z1 - z0))
        if rebord:
            e = 0.028
            for (cx, cy, sx, sy) in (((x0 + x1) / 2, y0, x1 - x0 + 2 * e, 2 * e), ((x0 + x1) / 2, y1, x1 - x0 + 2 * e, 2 * e),
                                     (x0, (y0 + y1) / 2, 2 * e, y1 - y0), (x1, (y0 + y1) / 2, 2 * e, y1 - y0)):
                self.box(rebord, (cx, cy, z1 - rebord_h / 2), (sx, sy, rebord_h))
        if not rivets:
            return
        pn = []
        d = 0.05
        if "top" in faces:
            for a, b in (((x0 + d, y0 + d, z1), (x1 - d, y0 + d, z1)), ((x0 + d, y1 - d, z1), (x1 - d, y1 - d, z1)),
                         ((x0 + d, y0 + d, z1), (x0 + d, y1 - d, z1)), ((x1 - d, y0 + d, z1), (x1 - d, y1 - d, z1))):
                pn += [(p, (0, 0, 1)) for p in self.ligne(a, b, pas)]
        if "south" in faces and z1 - z0 > 0.15:
            for x in (x0 + d, x1 - d):
                pn += [(p, (0, -1, 0)) for p in self.ligne((x, y0, z0 + d), (x, y0, z1 - d), pas)]
            pn += [(p, (0, -1, 0)) for p in self.ligne((x0 + d, y0, z1 - d), (x1 - d, y0, z1 - d), pas)]
        for side, x, n in (("east", x1, (1, 0, 0)), ("west", x0, (-1, 0, 0))):
            if side in faces and z1 - z0 > 0.15:
                pn += [(p, n) for p in self.ligne((x, y0 + d, z1 - d), (x, y1 - d, z1 - d), pas * 1.4)]
        self.rivets(pn, rmat)

    def plinthe(self, cote, h=0.1, mat="socle", marge=0.06, boulons=True, bord="structure", retrait=0.0, flanc=None):
        """Socle de la machine sur toute l'emprise (cote × cote tuiles). retrait > 0 (r4) : SOCLE MASSIF à flancs
        inclinés (grammaire des assembleurs vanilla : le corps remplit l'emprise, la machinerie est posée dessus) ;
        flancs en tôle `flanc` (défaut : mat) à panneaux rivetés, grilles au sud, bande de danger en pied. Rend le z
        du pont."""
        hx = cote / 2 - marge
        hy = Y(cote / 2 - marge)
        tx, ty = hx - retrait, hy - Y(retrait)
        bot = [(-hx, -hy, 0.0), (hx, -hy, 0.0), (hx, hy, 0.0), (-hx, hy, 0.0)]
        top = [(-tx, -ty, h), (tx, -ty, h), (tx, ty, h), (-tx, ty, h)]
        fl = flanc or mat
        # flancs (4 quadrilatères), uv en unités
        for i in range(4):
            a, b, c, d = bot[i], bot[(i + 1) % 4], top[(i + 1) % 4], top[i]
            L = geo.length(geo.sub(b, a))
            H = geo.length(geo.sub(d, a))
            self.put(fl, ([a, b, c, d], [(0, 1, 2, 3)], [(0, 0), (L, 0), (L, H), (0, H)]))
        self.put(mat, ([top[0], top[1], top[2], top[3]], [(0, 1, 2, 3)], [(p[0], p[1]) for p in top]))
        zt = h
        self.box(mat, (0.0, 0.0, zt + 0.012), (2 * tx - 0.08, 2 * ty - 0.08, 0.024))
        zt += 0.024
        e = 0.07
        for (cx, cy, sx_, sy_) in ((0.0, -ty + e / 2, 2 * tx, e), (0.0, ty - e / 2, 2 * tx, e),
                                   (-tx + e / 2, 0.0, e, 2 * ty), (tx - e / 2, 0.0, e, 2 * ty)):
            self.box(bord, (cx, cy, h + 0.03), (sx_, sy_, 0.06))
        pn = [(p, (0, 0, 1)) for p in self.ligne((-tx + 0.05, -ty + e / 2, h + 0.06), (tx - 0.05, -ty + e / 2, h + 0.06), 0.2)]
        for x in (-tx + e / 2, tx - e / 2):
            pn += [(p, (0, 0, 1)) for p in self.ligne((x, -ty + 0.1, h + 0.06), (x, ty - 0.1, h + 0.06), 0.28)]
        self.rivets(pn, "boulon", 0.022, 0.015)
        if boulons:
            for sx in (-1, 1):
                for sy in (-1, 1):
                    self.boulon((sx * (tx - 0.14), sy * (ty - 0.14), zt), (0, 0, 1), 0.04)
        if retrait > 0 and h > 0.2:
            # flanc sud incliné : raidisseurs, grilles d'aération, rivets le long des arêtes, pied de danger
            n = max(2, int(2 * hx / 0.55))
            ang = math.atan2(retrait * SQ2, h)        # inclinaison du flanc sud (vers le nord en montant)
            for j in range(n + 1):
                x = -hx + 2 * hx * j / n
                xt = x * tx / hx
                self.put(bord, tube([(x, -hy - 0.012, 0.0), (xt, -ty - 0.012, h)], 0.03, 6))
                if j < n:
                    xm = (x + (-hx + 2 * hx * (j + 1) / n)) / 2 * (0.5 + 0.5 * tx / hx)
                    ym = (-hy - ty) / 2 - 0.02
                    if j % 2 == 0:
                        self.box("grille", (xm, ym, h * 0.55), (2 * hx / n * 0.55, 0.02, h * 0.35), rx=-ang, petite=True)
                        for q in range(3):
                            self.box("noir", (xm, ym - 0.004, h * (0.42 + 0.1 * q)), (2 * hx / n * 0.5, 0.012, 0.02),
                                     rx=-ang)
                    else:
                        self.box(bord, (xm, ym, h * 0.55), (2 * hx / n * 0.6, 0.016, h * 0.4), rx=-ang)
                        self.rivets([((xm + dx, ym - 0.012, h * zz), (0, -0.8, 0.6)) for dx in (-0.12, 0.12)
                                     for zz in (0.4, 0.72)], "rivet", 0.018, 0.012)
            pn = [(p, (0, -0.7, 0.7)) for p in self.ligne((-tx + 0.05, -ty - 0.01, h - 0.03), (tx - 0.05, -ty - 0.01, h - 0.03),
                                                          0.14)]
            pn += [(p, (0, -0.7, 0.7)) for p in self.ligne((-hx + 0.05, -hy - 0.01, 0.05), (hx - 0.05, -hy - 0.01, 0.05),
                                                           0.14)]
            self.rivets(pn, "rivet", 0.018, 0.012)
            # flancs est et ouest : raidisseurs
            for sx in (-1, 1):
                for j in range(1, 4):
                    yy = -hy + 2 * hy * j / 4
                    self.put(bord, tube([(sx * (hx + 0.012), yy, 0.0), (sx * (tx + 0.012), yy * ty / hy, h)], 0.028, 6))
        else:
            self.panneau_danger((0.0, -hy, h * 0.5), 2 * hx, h * 0.8)
        return zt

    def socle(self, cote, h=0.42, retrait=0.16, mat="socle", flanc=None, z_ref=0.125):
        """Socle massif (r4), puis DÉCALAGE vertical de tout ce qui est posé ensuite (lot.xf) : le code d'une variante
        écrit ses hauteurs comme sur l'ancienne plinthe plate (pont à z_ref) ; on rend z_ref. Les raccords de bord
        se posent AVANT (hauteur du sol)."""
        zt = self.plinthe(cote, h, mat, retrait=retrait, flanc=flanc)
        dz = zt - z_ref
        self.dz = dz
        self.lot.xf = lambda v: (v[0], v[1], v[2] + dz)
        return z_ref

    def halo(self, S, loc, col, power, r=0.2):
        S.halo_light((loc[0], loc[1], loc[2] + getattr(self, "dz", 0.0)), col, power, r)

    def boulon(self, p, n, r=0.03, mat="boulon"):
        """Tête de boulon hexagonale + rondelle."""
        prof = [(0.0, r * 1.25), (0.008, r * 1.25), (0.008, r), (r * 0.7, r), (r * 0.75, 0.0)]
        self.put(mat, oriente(tour(prof, 6, "z", cap0=True), p, n), True)

    def boulons_cercle(self, c, r, n, normal, rb=0.022, mat="boulon"):
        e1, e2 = _base(normal)
        for i in range(n):
            a = TAU * (i + 0.5) / n
            p = geo.add(c, geo.add(geo.mul(e1, r * math.cos(a)), geo.mul(e2, r * math.sin(a))))
            self.boulon(p, normal, rb, mat)

    # ------------------------------------------------------------------------------------------ cuves
    def cuve_v(self, mat, cx, cy, r, z0, z1, segs=36, cerclages=(), cmat="trim", dome=0.35, rivets=True,
               dome_mat=None):
        """Cuve verticale : fût, cerclages (avec rivets), fond bombé ; rend la hauteur du sommet."""
        self.put(mat, tour([(z0, r), (z1, r)], segs, "z", (cx, cy, 0.0)))
        top = z1
        if dome:
            hd = r * dome
            prof = [(z1, r)] + [(z1 + hd * math.sin(math.pi / 2 * i / 6), r * math.cos(math.pi / 2 * i / 6))
                                for i in range(1, 7)]
            prof[-1] = (z1 + hd, 0.0)
            self.put(dome_mat or mat, tour(prof, segs, "z", (cx, cy, 0.0)))
            top = z1 + hd
        for zc in cerclages:
            self.put(cmat, tour([(zc - 0.03, r + 0.022), (zc + 0.03, r + 0.022)], segs, "z", (cx, cy, 0.0), cap0=True,
                                cap1=True))
            if rivets:
                pn = []
                for i in range(int(TAU * r / 0.16)):
                    a = TAU * i / int(TAU * r / 0.16)
                    if math.sin(a) > 0.35:      # face nord : jamais vue
                        continue
                    pn.append(((cx + (r + 0.022) * math.cos(a), cy + (r + 0.022) * math.sin(a), zc),
                               (math.cos(a), math.sin(a), 0.0)))
                self.rivets(pn, "rivet", 0.017, 0.012)
        return top

    def cuve_h(self, mat, c, r, L, axe="x", cerclages=2, cmat="trim", berceaux=True, bmat="acier"):
        """Cuve horizontale à fonds bombés, cerclages et berceaux (selle au sol)."""
        cx, cy, cz = c
        prof = [(-L / 2 - r * 0.35, 0.0)] + [(-L / 2 - r * 0.35 * math.cos(math.pi / 2 * i / 5),
                                              r * math.sin(math.pi / 2 * i / 5)) for i in range(1, 6)]
        prof += [(L / 2, r)] + [(L / 2 + r * 0.35 * math.sin(math.pi / 2 * i / 5), r * math.cos(math.pi / 2 * i / 5))
                                for i in range(1, 6)]
        prof[-1] = (L / 2 + r * 0.35, 0.0)
        self.put(mat, tour(prof, 32, axe, (cx, cy, cz) if axe != "x" else (0.0, cy, cz)) if axe != "x"
                 else _shift(tour(prof, 32, "x", (0.0, cy, cz)), (cx, 0, 0)))
        for i in range(cerclages):
            t = -L / 2 + L * (i + 0.5) / cerclages
            ring = tour([(t - 0.03, r + 0.02), (t + 0.03, r + 0.02)], 32, axe, (0.0, cy, cz) if axe == "x" else (cx, 0.0, cz),
                        cap0=True, cap1=True)
            self.put(cmat, _shift(ring, (cx, 0, 0)) if axe == "x" else _shift(ring, (0, cy, 0)))
            if berceaux:
                if axe == "x":
                    self.box(bmat, (cx + t, cy, (cz - r * 0.6) / 2), (0.08, r * 1.5, cz - r * 0.6))
                    self.box(bmat, (cx + t, cy, 0.02), (0.14, r * 1.7, 0.04))
                else:
                    self.box(bmat, (cx, cy + t, (cz - r * 0.6) / 2), (r * 1.5, 0.08, cz - r * 0.6))
                    self.box(bmat, (cx, cy + t, 0.02), (r * 1.7, 0.14, 0.04))

    # ------------------------------------------------------------------------------------------ tuyauterie
    def bride(self, c, n, r, mat="trim", boulons=6):
        e = 0.03
        self.put(mat, oriente(tour([(-e, r * 1.55), (e, r * 1.55)], 20, "z", cap0=True, cap1=True), c, n), True)
        self.boulons_cercle(geo.add(c, geo.mul(geo.norm(n), e)), r * 1.3, boulons, geo.norm(n), max(0.016, r * 0.28))

    def tuyau(self, mat, pts, r=0.07, coude=0.16, brides=True, bmat="trim", pas_brides=1.1):
        """Tuyau le long d'une polyligne à coudes arrondis ; brides boulonnées aux bouts et le long du tracé."""
        path = coudee(pts, coude, 6)
        self.put(mat, tube(path, r, 14))
        if not brides:
            return
        self.bride(pts[0], geo.sub(pts[0], pts[1]), r, bmat)
        self.bride(pts[-1], geo.sub(pts[-1], pts[-2]), r, bmat)
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            L = geo.length(geo.sub(b, a))
            n = int(L / pas_brides)
            for j in range(1, n + 1):
                t = j / (n + 1.0)
                if L * t < coude * 1.5 or L * (1 - t) < coude * 1.5:
                    continue
                self.bride(geo.lerp(a, b, t), geo.sub(b, a), r, bmat, 6)

    def vanne(self, c, axe=(1, 0, 0), r=0.07, mat="acier", volant="rouge"):
        """Vanne à volant : corps, chapeau, tige, volant à 4 rayons (vers le haut)."""
        x, y, z = c
        self.put(mat, oriente(tour([(-r * 1.2, r * 1.1), (r * 1.2, r * 1.1)], 12, "z", cap0=True, cap1=True), c, axe), True)
        self.box(mat, (x, y, z + r * 1.4), (r * 1.1, r * 1.1, r * 1.2), petite=True)
        self.put("acier", tour([(z + r * 2.0, 0.018), (z + r * 3.4, 0.018)], 8, "z", (x, y, 0), cap1=True))
        R = r * 2.0
        zt = z + r * 3.2
        self.put(volant, tube([(x + R * math.cos(TAU * i / 16), y + R * math.sin(TAU * i / 16), zt) for i in range(17)],
                              0.018, 6, False, False), True)
        for i in range(4):
            a = TAU * i / 4 + 0.4
            self.put(volant, tube([(x, y, zt), (x + R * math.cos(a), y + R * math.sin(a), zt)], 0.014, 5))

    def raccord(self, x, yn_bord, sens, mat="tuyau", r=0.15, z=0.32, bmat="trim", long=0.55):
        """Raccord de fluide au bord de l'emprise (x, y de jeu du bord, sens = +1 nord / -1 sud) : tubulure sortant
        du corps jusqu'au bord, bride boulonnée sur le bord (le tuyau du joueur s'y branche)."""
        yb = Y(yn_bord)
        y0 = yb - sens * long
        self.put(mat, tube([(x, y0, z), (x, yb, z)], r, 18))
        self.bride((x, yb, z), (0, sens, 0), r, bmat, 8)
        self.bride((x, y0 + sens * 0.06, z), (0, -sens, 0), r, bmat, 8)
        self.box("acier", (x, yb - sens * long * 0.5, z / 2 - 0.02), (0.12, 0.06, z - 0.1))   # support

    # ------------------------------------------------------------------------------------------ circulation
    def garde_corps(self, pts, h=0.42, mat="rampe", pas=0.42, plinthe=True):
        """Garde-corps le long d'une polyligne posée (z du plancher dans chaque point) : montants, 2 lisses, plinthe."""
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            L = geo.length(geo.sub(b, a))
            n = max(1, int(L / pas))
            for j in range(n + 1 if i == len(pts) - 2 else n):
                p = geo.lerp(a, b, j / float(n))
                self.put(mat, tour([(p[2], 0.018), (p[2] + h, 0.018)], 6, "z", (p[0], p[1], 0.0), cap1=True), True)
        up = [geo.add(p, (0, 0, h)) for p in pts]
        mid = [geo.add(p, (0, 0, h * 0.5)) for p in pts]
        self.put(mat, tube(up, 0.019, 6))
        self.put(mat, tube(mid, 0.016, 6))
        if plinthe:
            for i in range(len(pts) - 1):
                a, b = pts[i], pts[i + 1]
                d = geo.sub(b, a)
                L = geo.length(d)
                ang = math.atan2(d[1], d[0])
                m = geo.lerp(a, b, 0.5)
                self.box(mat, (m[0], m[1], m[2] + 0.04), (L, EP, 0.08), rz=ang)

    def caillebotis(self, x0, x1, y0, y1, z, mat="caillebotis", pas=0.09):
        """Plancher en caillebotis : cadre + barreaux (petites pièces)."""
        self.box("acier", ((x0 + x1) / 2, (y0 + y1) / 2, z - 0.03), (x1 - x0, y1 - y0, 0.03))
        n = max(2, int((x1 - x0) / pas))
        for i in range(n + 1):
            x = x0 + (x1 - x0) * i / n
            self.box(mat, (x, (y0 + y1) / 2, z + 0.008), (0.022, y1 - y0, 0.022), petite=i % 3 == 0)
        for y in (y0, y1):
            self.box("acier", ((x0 + x1) / 2, y, z), (x1 - x0, 0.04, 0.05))

    def echelle(self, x, y, z0, z1, mat="rampe", larg=0.26, cage=True):
        """Échelle verticale contre une face sud (montants, barreaux tous les 0,12), crinoline au-dessus de 0,6."""
        for dx in (-larg / 2, larg / 2):
            self.put(mat, tour([(z0, 0.017), (z1 + 0.25, 0.017)], 6, "z", (x + dx, y, 0.0), cap1=True))
        z = z0 + 0.1
        while z < z1:
            self.put(mat, tube([(x - larg / 2, y, z), (x + larg / 2, y, z)], 0.013, 5), True)
            z += 0.12
        if cage and z1 - z0 > 0.8:
            zc = z0 + 0.6
            while zc < z1 + 0.2:
                pts = [(x + (larg / 2 + 0.08) * math.cos(a), y - 0.12 - 0.14 * math.sin(a), zc)
                       for a in [math.pi * i / 8 for i in range(9)]]
                self.put(mat, tube(pts, 0.012, 5, False, False))
                zc += 0.3

    # ------------------------------------------------------------------------------------------ équipements
    def grille(self, c, w, h, face=(0, -1, 0), n=None, mat="grille", cadre="trim"):
        """Grille d'aération à lames inclinées dans un cadre, sur une face (sud par défaut)."""
        x, y, z = c
        n = n or max(3, int(h / 0.06))
        if face[1]:
            s = face[1]
            self.box(cadre, (x, y + s * 0.015, z), (w + 0.06, 0.03, h + 0.06))
            self.box("noir", (x, y + s * 0.02, z), (w, 0.03, h))
            for i in range(n):
                zz = z - h / 2 + h * (i + 0.5) / n
                self.box(mat, (x, y + s * 0.04, zz), (w - 0.02, 0.022, h / n * 0.75), rx=s * 0.6, petite=True)
        else:
            s = face[0]
            self.box(cadre, (x + s * 0.015, y, z), (0.03, w + 0.06, h + 0.06))
            self.box("noir", (x + s * 0.02, y, z), (0.03, w, h))
            for i in range(n):
                zz = z - h / 2 + h * (i + 0.5) / n
                self.box(mat, (x + s * 0.04, y, zz), (0.022, w - 0.02, h / n * 0.75), ry=-s * 0.6, petite=True)

    def armoire(self, c, s, mat="armoire", voyants=(), poignee="trim", grille=True):
        """Armoire électrique : caisse, portes à joints, poignées, presse-étoupes, voyants (matières lumineuses)."""
        x, y, z0 = c
        w, d, h = s
        self.caisson(mat, x - w / 2, x + w / 2, y - d / 2, y + d / 2, z0, z0 + h, pas=0.1)
        nd = max(1, int(w / 0.35))
        for i in range(nd):
            xd = x - w / 2 + w * (i + 0.5) / nd
            self.box("noir", (x - w / 2 + w * i / nd, y - d / 2 - 0.004, z0 + h / 2), (0.014, 0.01, h * 0.9))
            self.box(poignee, (xd + w / nd * 0.32, y - d / 2 - 0.02, z0 + h * 0.55), (0.03, 0.03, 0.12), petite=True)
        self.box(mat, (x, y - d / 2 + 0.02, z0 + h + 0.03), (w + 0.06, d + 0.06, 0.04))      # toit débordant
        for k, (col, dx) in enumerate(voyants):
            self.voyant((x - w / 2 + 0.08 + dx, y - d / 2 - 0.01, z0 + h * 0.85), col, 0.028, (0, -1, 0))
        if grille and h > 0.4:
            self.grille((x, y - d / 2, z0 + h * 0.25), w * 0.6, h * 0.22)
        for i in range(3):
            self.put("acier", tour([(z0 - 0.05, 0.022), (z0, 0.03)], 8, "z", (x - w / 3 + i * w / 3, y, 0.0)), True)

    def voyant(self, p, col, r=0.03, n=(0, 0, 1), cerclage="trim"):
        """Voyant : lentille lumineuse (col = clé de matière émissive) dans une couronne."""
        self.put(cerclage, oriente(tour([(0.0, r * 1.5), (0.012, r * 1.5), (0.012, r * 1.15)], 12, "z", cap0=True), p, n), True)
        self.put(col, oriente(geo.sphere((0, 0, 0.004), r, 10, 4, zmin=0.0), p, n))

    def moteur(self, c, axe="x", r=0.16, L=0.5, mat="moteur", ailettes=10):
        """Moteur électrique à carcasse ailetée : fût, ailettes, flasques, ventilateur grillagé, boîte à bornes, pattes."""
        cx, cy, cz = c
        if axe == "x":
            self.put(mat, _shift(tour([(-L / 2, r), (L / 2, r)], 20, "x", (0, cy, cz), cap0=True, cap1=True), (cx, 0, 0)))
            for i in range(ailettes):
                t = -L / 2 + L * (i + 0.5) / ailettes
                self.put(mat, _shift(tour([(t - 0.012, r + 0.035), (t + 0.012, r + 0.035)], 20, "x", (0, cy, cz), cap0=True, cap1=True),
                                     (cx, 0, 0)), True)
            self.put("trim", _shift(tour([(L / 2, r * 0.95), (L / 2 + 0.06, r * 0.8), (L / 2 + 0.08, 0.04)], 20, "x",
                                         (0, cy, cz), cap1=True), (cx, 0, 0)))
            self.put("grille", _shift(tour([(-L / 2 - 0.14, r * 1.02), (-L / 2, r * 1.02)], 20, "x", (0, cy, cz), cap0=True),
                                      (cx, 0, 0)))
            self.box(mat, (cx, cy - r * 0.2, cz + r + 0.05), (0.14, 0.12, 0.1), petite=True)
            for dx in (-L / 3, L / 3):
                self.box("acier", (cx + dx, cy, (cz - r * 0.7) / 2 + 0.01), (0.06, r * 1.6, cz - r * 0.7))
        else:
            self.put(mat, tour([(cz - L / 2, r), (cz + L / 2, r)], 20, "z", (cx, cy, 0), cap0=True, cap1=True))
            for i in range(ailettes):
                t = cz - L / 2 + L * (i + 0.5) / ailettes
                self.put(mat, tour([(t - 0.012, r + 0.035), (t + 0.012, r + 0.035)], 20, "z", (cx, cy, 0), cap0=True, cap1=True), True)
            self.put("grille", tour([(cz + L / 2, r * 1.02), (cz + L / 2 + 0.1, r * 1.02), (cz + L / 2 + 0.11, 0.0)], 20,
                                    "z", (cx, cy, 0)))

    def ailettes(self, c, w, d, h, n, mat="ailette", axe="x"):
        """Bloc d'ailettes de refroidissement (radiateur) : n lames parallèles."""
        x, y, z = c
        for i in range(n):
            t = -0.5 + (i + 0.5) / n
            if axe == "x":
                self.box(mat, (x + t * w, y, z), (EP, d, h), petite=True)
            else:
                self.box(mat, (x, y + t * d, z), (w, EP, h), petite=True)
        self.box("acier", (x, y, z - h / 2 - 0.02), (w + 0.04, d + 0.04, 0.04))

    def cable(self, a, b, fl=0.08, r=0.02, mat="cable"):
        self.put(mat, tube(geo.chainette(a, b, fl), r, 6))

    def panneau_danger(self, c, w, h, face=(0, -1, 0)):
        """Bande de danger jaune et noir (chevrons) sur une face."""
        x, y, z = c
        n = max(2, int(w / 0.09))
        for i in range(n):
            xx = x - w / 2 + w * (i + 0.5) / n
            mat = "danger_j" if i % 2 == 0 else "danger_n"
            self.box(mat, (xx, y + face[1] * 0.006, z), (w / n, 0.012, h), ry=0.5)


def _base(n):
    n = geo.norm(n)
    ref = (1.0, 0.0, 0.0) if abs(n[0]) < 0.9 else (0.0, 1.0, 0.0)
    e1 = geo.norm(geo.cross(ref, n))
    return e1, geo.cross(n, e1)


def _shift(mesh, d):
    v, f, u = mesh
    return [geo.add(p, d) for p in v], f, u
