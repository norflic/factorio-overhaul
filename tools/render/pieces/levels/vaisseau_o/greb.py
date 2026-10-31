"""PIÈCES FONCTIONNELLES du kit vaisseau_o (lot QG, 30/10) : ce que le brief QG compte sur l'épave vanilla et qui
manquait à nos états (flexibles annelés, tuyaux coudés à brides, faisceaux de câbles, évents et grilles, hublots tous
différents, mâts, garde-corps, échafaudages, débris, flèches, tourelles, tôles irrégulières).

Chaque fonction reçoit le lot, les matières et éventuellement une transformation `xf` (sinon celle du lot). Les pièces
sont COMPTÉES dans COMPTE (contrôle des minimums du brief, écrit dans render.json par build()).
Pas de trigonométrie de simulation ici : c'est de la géométrie de rendu, hors jeu.
"""
import math

import geo as G

COMPTE = {}


def compte(cle, n=1):
    COMPTE[cle] = COMPTE.get(cle, 0) + n


def raz():
    COMPTE.clear()


# ------------------------------------------------------------------------------------------------ outils
def repere(n, up=(0.0, 0.0, 1.0)):
    """Repère (ex, ey, ez) avec ez = n et ey aussi proche que possible de up (pose de pièces planes sur un mur)."""
    ez = G.norm(n)
    u = G.sub(up, G.mul(ez, G.dot(up, ez)))
    if G.length(u) < 1e-4:
        u = G.sub((0.0, 1.0, 0.0), G.mul(ez, ez[1]))
    ey = G.norm(u)
    ex = G.cross(ey, ez)
    return ex, ey, ez


def pose(mesh, p, n, up=(0.0, 0.0, 1.0)):
    """Maille modélisée à plat (X droite, Y haut, Z sortant) posée au point p, Z le long de n."""
    ex, ey, ez = repere(n, up)
    v, f, u = mesh
    return [G.add(p, G.add(G.add(G.mul(ex, q[0]), G.mul(ey, q[1])), G.mul(ez, q[2]))) for q in v], f, u


def reech(pts, pas):
    """Polyligne rééchantillonnée à pas constant (anneaux réguliers des flexibles)."""
    out = [pts[0]]
    acc = 0.0
    for i in range(1, len(pts)):
        a, b = pts[i - 1], pts[i]
        L = G.length(G.sub(b, a))
        t = pas - acc
        while t <= L:
            out.append(G.lerp(a, b, t / L))
            t += pas
        acc = L - (t - pas)
    if G.length(G.sub(out[-1], pts[-1])) > pas * 0.3:
        out.append(pts[-1])
    return out


def cyl(c, r, z0, z1, segs=16, cap=True):
    return G.tour([(z0, r), (z1, r)], segs, "z", (c[0], c[1], 0.0), cap0=cap, cap1=cap)


def cyl_axe(p, d, r, L, segs=14):
    """Cylindre de longueur L, de p dans la direction d."""
    return G.oriente(G.tour([(0.0, r), (L, r)], segs, "z", cap0=True, cap1=True), p, d)


def clampz(mesh, z=0.0):
    v, f, u = mesh
    return [(q[0], q[1], max(z, q[2])) for q in v], f, u


# ------------------------------------------------------------------------------------------------ tuyauterie
def flexible(lot, M, Mbague, ctrl, r, pas=0.055, xf=None):
    """Flexible annelé (Catmull-Rom par les points de contrôle), bagues aux deux bouts."""
    pts = reech(G.catmull(ctrl, 10), pas / 5.0)
    lot.put(M, clampz(G.tube(pts, r, 10, rfun=lambda s, i: r * (0.9 + 0.2 * (0.5 + 0.5 * math.cos(s * G.TAU / pas))))), xf)
    fr = G._frames(pts)
    for i in (0, len(pts) - 1):
        lot.put(Mbague, G.oriente(G.tour([(-0.04, r * 1.45), (0.04, r * 1.45)], 12, "z", cap0=True, cap1=True), pts[i],
                                  fr[i][0]), xf)
    compte("flexibles")


def tuyau(lot, M, Mbride, poly, r, rb=None, xf=None, pas_bride=1.1):
    """Tuyau rigide coudé (coudes arrondis) à brides : aux bouts, avant et après chaque coude, et tous les pas_bride."""
    rb = rb if rb is not None else max(0.08, r * 2.4)
    pts = G.coudee(poly, rb, 6)
    lot.put(M, clampz(G.tube(pts, r, 12)), xf)
    fr = G._frames(pts)
    acc, last = 0.0, -1e9
    for i, p in enumerate(pts):
        if i:
            acc += G.length(G.sub(p, pts[i - 1]))
        coude = 0 < i < len(pts) - 1 and G.dot(fr[i][0], fr[i - 1][0]) < 0.995 and G.dot(fr[i][0], fr[i + 1][0]) > 0.9999
        if i in (0, len(pts) - 1) or acc - last > pas_bride or coude:
            b = G.tour([(-0.022, r * 1.5), (0.022, r * 1.5)], 12, "z", cap0=True, cap1=True)
            lot.put(Mbride, G.oriente(b, p, fr[i][0]), xf)
            last = acc
    compte("tuyaux")
    compte("tuyaux_r%.3f" % r)


def faisceau(lot, Mr, Mn, a, b, fl, rnd, n=4, r=0.016, rouges=1, xf=None):
    """Faisceau de câbles qui pendent entre a et b (rouges et noirs), extrémités légèrement écartées."""
    for i in range(n):
        da = (rnd.f(-0.05, 0.05), rnd.f(-0.05, 0.05), rnd.f(-0.03, 0.03))
        db = (rnd.f(-0.05, 0.05), rnd.f(-0.05, 0.05), rnd.f(-0.03, 0.03))
        pts = G.chainette(G.add(a, da), G.add(b, db), fl * rnd.f(0.75, 1.3), 16)
        lot.put(Mr if i < rouges else Mn, clampz(G.tube(pts, r * rnd.f(0.8, 1.2), 6), 0.01), xf)
    compte("faisceaux")


def cable_droit(lot, M, a, b, r=0.014, xf=None):
    lot.put(M, G.tube([a, b], r, 6), xf)


# ------------------------------------------------------------------------------------------------ évents, hublots
def grille(lot, Mcadre, Mfond, p, n, w, h, lames=7, up=(0.0, 0.0, 1.0), xf=None):
    """Évent à lames posé sur une surface (p, normale n) : cadre, fond noir, lames inclinées."""
    cad = G.merge(G.boite((0, h / 2 + 0.025, 0.02), (w + 0.1, 0.05, 0.05)), G.boite((0, -h / 2 - 0.025, 0.02), (w + 0.1, 0.05, 0.05)),
                  G.boite((-w / 2 - 0.025, 0, 0.02), (0.05, h, 0.05)), G.boite((w / 2 + 0.025, 0, 0.02), (0.05, h, 0.05)))
    lot.put(Mcadre, pose(cad, p, n, up), xf)
    lot.put(Mfond, pose(G.boite((0, 0, -0.005), (w, h, 0.02)), p, n, up), xf)
    lm = []
    for i in range(lames):
        y = -h / 2 + h * (i + 0.5) / lames
        lm.append(G.boite((0, y, 0.018), (w * 0.98, h / lames * 0.55, 0.012), rx=0.6))
    lot.put(Mcadre, pose(G.merge(*lm), p, n, up), xf)
    compte("grilles")


HUBLOT_FORMES = ("rond", "ogive", "carre", "fente", "octo", "double", "losange", "demi")


def hublot(lot, Mcadre, Mv, p, n, forme, t=0.14, up=(0.0, 0.0, 1.0), xf=None):
    """Hublot de forme donnée (tous différents : forme et taille), vitre lumineuse ou sombre."""
    if forme == "rond":
        cad = G.tour([(0.0, t * 1.35), (0.035, t * 1.25), (0.04, t * 1.0), (0.02, t * 0.95)], 16, "z")
        vit = G.tour([(0.018, t * 0.98), (0.02, 0.0)], 16, "z")
    elif forme == "octo":
        cad = G.tour([(0.0, t * 1.4), (0.04, t * 1.3), (0.045, t * 1.02), (0.02, t * 0.97)], 8, "z")
        vit = G.tour([(0.018, t * 1.0), (0.02, 0.0)], 8, "z")
    elif forme == "ogive":
        cad = G.merge(G.boite((0, -t * 0.1, 0.02), (t * 1.5, t * 1.9, 0.04)), G.boite((0, t * 0.95, 0.025), (t * 0.7, t * 0.5, 0.05)))
        vit = G.merge(G.boite((0, -t * 0.15, 0.042), (t * 1.0, t * 1.4, 0.01)), G.boite((0, t * 0.68, 0.042), (t * 0.5, t * 0.35, 0.01)))
    elif forme == "carre":
        cad = G.boite((0, 0, 0.02), (t * 1.9, t * 1.9, 0.04))
        vit = G.boite((0, 0, 0.042), (t * 1.35, t * 1.35, 0.01))
    elif forme == "fente":
        cad = G.boite((0, 0, 0.02), (t * 3.4, t * 0.8, 0.04))
        vit = G.boite((0, 0, 0.042), (t * 2.9, t * 0.35, 0.01))
    elif forme == "double":
        cad = G.boite((0, 0, 0.02), (t * 2.6, t * 1.5, 0.04))
        vit = G.merge(G.boite((-t * 0.62, 0, 0.042), (t * 0.95, t * 1.05, 0.01)), G.boite((t * 0.62, 0, 0.042), (t * 0.95, t * 1.05, 0.01)))
    elif forme == "losange":
        cad = G.boite((0, 0, 0.02), (t * 1.7, t * 1.7, 0.04), rz=math.pi / 4)
        vit = G.boite((0, 0, 0.042), (t * 1.15, t * 1.15, 0.01), rz=math.pi / 4)
    else:  # demi
        cad = G.tour([(0.0, t * 1.35), (0.04, t * 1.25), (0.045, t * 1.0)], 12, "z", a0=0.0, a1=math.pi)
        vit = G.tour([(0.046, t * 0.95), (0.047, 0.0)], 12, "z", a0=0.0, a1=math.pi)
    lot.put(Mcadre, pose(cad, p, n, up), xf)
    lot.put(Mv, pose(vit, p, n, up), xf)
    compte("hublots")


# ------------------------------------------------------------------------------------------------ structure
def garde_corps(lot, M, pts, h=0.3, pas=0.28, r=0.012, xf=None):
    """Garde-corps le long d'une polyligne au sol de la passerelle : poteaux, main courante, lisse basse."""
    acc = 0.0
    for i in range(len(pts)):
        a = pts[i]
        if i:
            acc += G.length(G.sub(a, pts[i - 1]))
    top = [G.add(p, (0, 0, h)) for p in pts]
    mid = [G.add(p, (0, 0, h * 0.5)) for p in pts]
    lot.put(M, G.tube(top, r * 1.3, 6), xf)
    lot.put(M, G.tube(mid, r, 6), xf)
    for i in range(1, len(pts)):
        a, b = pts[i - 1], pts[i]
        L = G.length(G.sub(b, a))
        n = max(1, int(L / pas))
        for j in range(n + (1 if i == len(pts) - 1 else 0)):
            q = G.lerp(a, b, j / float(n))
            lot.put(M, G.tube([q, G.add(q, (0, 0, h))], r, 5, cap0=False), xf)
    compte("garde_corps")


def echafaudage(lot, M, Mplanche, x0, x1, y0, y1, z0, z1, etages=3, xf=None):
    """Échafaudage tubulaire : montants, lisses, diagonales, planchers."""
    xs = [x0 + (x1 - x0) * i / max(1, int((x1 - x0) / 0.55)) for i in range(int((x1 - x0) / 0.55) + 1)]
    zs = [z0 + (z1 - z0) * i / etages for i in range(etages + 1)]
    for x in xs:
        for y in (y0, y1):
            lot.put(M, G.tube([(x, y, z0), (x, y, z1)], 0.016, 5), xf)
    for z in zs[1:]:
        for y in (y0, y1):
            lot.put(M, G.tube([(x0, y, z), (x1, y, z)], 0.013, 5), xf)
        lot.put(Mplanche, G.boite(((x0 + x1) / 2, (y0 + y1) / 2, z - 0.02), (x1 - x0, abs(y1 - y0) * 0.95, 0.03)), xf)
    for i in range(len(xs) - 1):
        for k in range(len(zs) - 1):
            a, b = (xs[i], y0, zs[k]), (xs[i + 1], y0, zs[k + 1])
            if (i + k) % 2:
                a, b = (xs[i], y0, zs[k + 1]), (xs[i + 1], y0, zs[k])
            lot.put(M, G.tube([a, b], 0.011, 5), xf)
    compte("echafaudages")


def mat_antenne(lot, M, Mdet, Mlum, base, h, rnd, xf=None, lum=True):
    """Mât ou antenne : fût effilé, bras, haubans fins, voyant en tête (facultatif)."""
    x, y, z = base
    lot.put(M, G.tour([(z, 0.05), (z + h * 0.35, 0.035), (z + h, 0.012)], 8, "z", (x, y, 0.0), cap0=True, cap1=True), xf)
    for k in range(2):
        zz = z + h * (0.45 + 0.25 * k)
        L = 0.18 - 0.06 * k
        ang = rnd.f(0, math.pi)
        dx, dy = L * math.cos(ang), L * math.sin(ang)
        lot.put(Mdet, G.tube([(x - dx, y - dy, zz), (x + dx, y + dy, zz)], 0.01, 5), xf)
        lot.put(Mdet, G.boite((x + dx, y + dy, zz - 0.03), (0.03, 0.03, 0.08)), xf)
    for s in (-1, 1):
        lot.put(Mdet, G.tube([(x, y, z + h * 0.7), (x + s * h * 0.22, y + 0.1 * s, z + 0.01)], 0.005, 4), xf)
    if lum and Mlum is not None:
        lot.put(Mlum, G.sphere((x, y, z + h + 0.02), 0.035, 8, 4), xf)
    compte("mats")


def caisse(lot, M, Mdet, c, s, rz=0.0, xf=None):
    x, y, z = c
    lot.put(M, G.boite((x, y, z + s[2] / 2), s, rz), xf)
    for k in (-1, 1):
        q = G.rot_z((k * s[0] * 0.36, 0.0, 0.0), rz)
        lot.put(Mdet, G.boite((x + q[0], y + q[1], z + s[2] / 2), (0.03, s[1] + 0.02, s[2] + 0.02), rz), xf)
    compte("debris")


def fut(lot, M, Mdet, c, r=0.11, h=0.3, couche=False, rz=0.0, xf=None):
    x, y, z = c
    if couche:
        lot.put(M, G.oriente(G.tour([(0, r), (h, r)], 12, "z", cap0=True, cap1=True), (x, y, z + r), (math.cos(rz), math.sin(rz), 0)), xf)
    else:
        lot.put(M, G.tour([(z, r), (z + h, r)], 12, "z", (x, y, 0.0), cap0=True, cap1=True), xf)
        lot.put(Mdet, G.tour([(z + h * 0.3, r + 0.008), (z + h * 0.36, r + 0.008)], 12, "z", (x, y, 0.0)), xf)
        lot.put(Mdet, G.tour([(z + h * 0.7, r + 0.008), (z + h * 0.76, r + 0.008)], 12, "z", (x, y, 0.0)), xf)
    compte("debris")


def eclat(lot, M, c, h, r, rnd, inc=0.3, xf=None):
    """Éclat de cristal ou de pierre (prisme effilé incliné)."""
    n = rnd.i(4, 6)
    a0 = rnd.f(0, G.TAU)
    poly = [(c[0] + r * math.cos(a0 + G.TAU * i / n) * rnd.f(0.7, 1.1), c[1] + r * math.sin(a0 + G.TAU * i / n) * rnd.f(0.7, 1.1))
            for i in range(n)]
    poly = _convexe(poly)
    v, f, u = G.prisme(poly, c[2], c[2] + h, top_scale=rnd.f(0.05, 0.3), top_shift=(rnd.f(-inc, inc) * h, rnd.f(-inc, inc) * h))
    lot.put(M, (v, f, u), xf)
    compte("debris")


def bloc(lot, M, c, s, rnd, xf=None):
    """Bloc de pierre tombé, posé de travers."""
    lot.put(M, G.boite((c[0], c[1], c[2] + s[2] * 0.45), s, rz=rnd.f(0, 3.0), rx=rnd.f(-0.25, 0.25), ry=rnd.f(-0.25, 0.25)), xf)
    compte("debris")


def _convexe(pts):
    pts = sorted(set(pts))
    if len(pts) < 3:
        return pts

    def cr(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, hi = [], []
    for p in pts:
        while len(lo) >= 2 and cr(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(hi) >= 2 and cr(hi[-2], hi[-1], p) <= 0:
            hi.pop()
        hi.append(p)
    return lo[:-1] + hi[:-1]


def octo(c, r, n=8, a0=None):
    a0 = math.pi / n if a0 is None else a0
    return [(c[0] + r * math.cos(a0 + G.TAU * i / n), c[1] + r * math.sin(a0 + G.TAU * i / n)) for i in range(n)]


# ------------------------------------------------------------------------------------------------ architecture
def fleche(lot, Mtambour, Mor, Mnacre, Mv, Mpointe, c, z0, h, r, rnd, etages=3, xf=None, Mlum=None):
    """Flèche de couronne (3 tailles par r et h) : tambour octogonal à panneaux de nacre et baies, puis aiguille d'or à
    facettes en étages séparés par des colliers, pointe de cristal. Rend la position de la pointe."""
    x, y = c
    ht = h * 0.22
    lot.put(Mtambour, G.prisme(octo(c, r), z0, z0 + ht, top_scale=0.94), xf)
    for i in range(8):
        a = math.pi / 8 + G.TAU * i / 8 + math.pi / 8
        if i % 2 == 0:
            p = (x + r * 0.93 * math.cos(a), y + r * 0.93 * math.sin(a), z0 + ht * 0.55)
            n = (math.cos(a), math.sin(a), 0.0)
            lot.put(Mnacre, pose(G.boite((0, 0, 0.0), (r * 0.42, ht * 0.62, 0.03)), p, n), xf)
            if Mlum is not None and i in (4, 6):
                lot.put(Mlum, pose(G.boite((0, 0, 0.02), (r * 0.12, ht * 0.42, 0.02)), p, n), xf)
    lot.put(Mor, G.prisme(octo(c, r * 1.12), z0 + ht, z0 + ht + 0.06, top_scale=0.97), xf)
    zz, rr = z0 + ht + 0.06, r * 0.86
    reste = h - ht - 0.06
    for e in range(etages):
        he = reste * (0.42 if e == 0 else 0.33 if e == 1 else 0.25)
        sc = 0.62 if e < etages - 1 else 0.04
        lot.put(Mor, G.prisme(octo(c, rr), zz, zz + he, top_scale=sc), xf)
        # nervures d'arête
        for i in range(0, 8, 2):
            a = math.pi / 8 + G.TAU * i / 8
            p0 = (x + rr * math.cos(a), y + rr * math.sin(a), zz)
            p1 = (x + rr * sc * math.cos(a), y + rr * sc * math.sin(a), zz + he)
            lot.put(Mtambour, G.tube([p0, p1], 0.018, 4), xf)
        zz += he
        rr *= sc
        if e < etages - 1:
            lot.put(Mtambour, G.prisme(octo(c, rr * 1.35), zz - 0.03, zz + 0.05, top_scale=0.9), xf)
            lot.put(Mor, G.prisme(octo(c, rr * 1.2), zz + 0.05, zz + 0.09, top_scale=0.85), xf)
    pointe = (x, y, zz)
    lot.put(Mpointe, G.prisme(octo(c, r * 0.12, 4, 0.0), zz - 0.12, zz + 0.12, top_scale=0.05), xf)
    compte("fleches")
    return pointe


def tourelle(lot, Mmur, Mtoit, Mor, Mlum, Mcadre, c, r, z0, z1, toit, rnd, fenetres=2, xf=None):
    """Tour ronde : fût, mâchicoulis en encorbellement, toit conique à épi, fentes éclairées (pas deux pareilles)."""
    x, y = c
    lot.put(Mmur, G.tour([(z0, r), (z1, r * 0.96)], 20, "z", (x, y, 0.0), cap0=False), xf)
    lot.put(Mmur, G.tour([(z1 - 0.02, r * 0.96), (z1 + 0.1, r * 1.16), (z1 + 0.22, r * 1.16)], 20, "z", (x, y, 0.0)), xf)
    for i in range(10):
        a = G.TAU * (i + 0.5) / 10
        lot.put(Mcadre, G.boite((x + r * 1.08 * math.cos(a), y + r * 1.08 * math.sin(a), z1 + 0.04), (0.05, 0.05, 0.12), rz=a), xf)
    lot.put(Mtoit, G.tour([(z1 + 0.2, r * 1.24), (z1 + 0.26, r * 1.2), (z1 + 0.2 + toit, 0.02)], 20, "z", (x, y, 0.0), cap0=True), xf)
    lot.put(Mor, G.tour([(z1 + 0.18, r * 1.26), (z1 + 0.24, r * 1.26)], 20, "z", (x, y, 0.0), cap0=True, cap1=True), xf)
    lot.put(Mor, G.tour([(z1 + 0.1 + toit, 0.03), (z1 + 0.28 + toit, 0.006)], 6, "z", (x, y, 0.0), cap0=True), xf)
    lot.put(Mor, G.sphere((x, y, z1 + 0.16 + toit), 0.045, 8, 4), xf)
    for k in range(fenetres):
        a = -math.pi / 2 + rnd.f(-0.7, 0.7)
        zz = z0 + (z1 - z0) * (0.3 + 0.45 * k / max(1, fenetres - 1)) if fenetres > 1 else (z0 + z1) / 2
        p = (x + r * math.cos(a), y + r * math.sin(a), zz)
        n = (math.cos(a), math.sin(a), 0.0)
        hh = rnd.f(0.12, 0.26)
        lot.put(Mcadre, pose(G.boite((0, 0, 0.0), (0.12, hh + 0.08, 0.05)), p, n), xf)
        lot.put(Mlum if Mlum is not None else Mcadre, pose(G.boite((0, 0, 0.022), (0.05, hh, 0.02)), p, n), xf)
    compte("tours")


def plaques(lot, mats, rnd, x0, x1, z0, z1, y, cote, prof=0.02, n=10, xf=None, Mjoint=None):
    """Tôles IRRÉGULIÈRES de rapiéçage sur un mur vertical (plan y, face vers cote) : tailles et teintes tirées au
    hasard, jamais au pas, débordant parfois les unes sur les autres (pas de damier)."""
    for _ in range(n):
        w = rnd.f(0.18, 0.75)
        h = rnd.f(0.12, 0.5)
        x = rnd.f(x0 + w / 2, max(x0 + w / 2 + 1e-3, x1 - w / 2))
        z = rnd.f(z0 + h / 2, max(z0 + h / 2 + 1e-3, z1 - h / 2))
        m = mats[rnd.i(0, len(mats) - 1)]
        lot.put(m, G.boite((x, y + cote * prof / 2, z), (w, prof, h), ry=rnd.f(-0.04, 0.04)), xf)
        if Mjoint is not None and rnd.f() < 0.5:
            pts = [((x - w / 2 + 0.03, y + cote * (prof + 0.003), z + h / 2 - 0.03), (0, cote, 0)),
                   ((x + w / 2 - 0.03, y + cote * (prof + 0.003), z + h / 2 - 0.03), (0, cote, 0)),
                   ((x - w / 2 + 0.03, y + cote * (prof + 0.003), z - h / 2 + 0.03), (0, cote, 0)),
                   ((x + w / 2 - 0.03, y + cote * (prof + 0.003), z - h / 2 + 0.03), (0, cote, 0))]
            lot.put(Mjoint, G.rivets_le_long(pts, 0.018, 0.012), xf)
    compte("toles", n)


def tertre(c, rx, ry, h, rnd, na=40, nr=10, bord=0.18, bosses=0.25, pente=1.3):
    """Tertre de terre en grille POLAIRE (contour lisse et bosselé, pas d'escalier comme geo.butte) ; c = pied."""
    ph = [rnd.f(0, G.TAU) for _ in range(8)]
    verts, faces, uvs = [(c[0], c[1], c[2] + h)], [], [(c[0], c[1])]
    for i in range(1, nr + 1):
        f = i / float(nr)
        for j in range(na):
            a = G.TAU * j / na
            k = 1.0 + bord * (0.6 * math.sin(3 * a + ph[0]) + 0.4 * math.sin(7 * a + ph[1]))
            x, y = c[0] + rx * k * f * math.cos(a), c[1] + ry * k * f * math.sin(a)
            b = 1.0 + bosses * math.sin(5.1 * f * math.cos(a) + ph[2]) * math.sin(4.3 * f * math.sin(a) + ph[3])
            z = c[2] + max(0.0, h * (1.0 - f * f) ** pente * b) - (0.01 if i == nr else 0.0)
            verts.append((x, y, z))
            uvs.append((x, y))
    for j in range(na):
        faces.append((0, 1 + j, 1 + (j + 1) % na))
    for i in range(nr - 1):
        b0, b1 = 1 + i * na, 1 + (i + 1) * na
        for j in range(na):
            faces.append((b0 + j, b1 + j, b1 + (j + 1) % na, b0 + (j + 1) % na))
    return verts, faces, uvs
