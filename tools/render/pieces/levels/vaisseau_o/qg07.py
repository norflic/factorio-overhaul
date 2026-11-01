"""QG ÂGE 7 : CRISTAL (série du 31/10, brief 2026-10-31_QG). Emprise 12×6. NEZ À DROITE (+X), tuyères à gauche.

Bible (DESIGN_EPOQUES §5, époque 7) : « Sanctuaire de résonance : socle de pierre taillée ; grand cristal central (point
le plus haut) ; 4 éclats satellites ; armature de bronze » ; bronze #6A5236, pierre #4A4038, cristal #9A5CFF (opaque),
luisant #B070FF, luminance 55. Ère III : pointes organiques et asymétriques. Le QG reste le vaisseau de l'âge 8 un âge
plus tôt : plus de peau, mêmes côtes, même pose.

Lecture de gauche à droite : tuyères et dérive ; le grand cristal jaillit de la cage des côtes, tenu par des griffes et
deux cerceaux de bronze ; devant lui, sur le parvis de pierre, la chapelle (nefs à abside et pavillon à toits facettés de
bronze) entre deux reliquaires ; derrière, la tour au prisme, l'obélisque, et au nord-est la grappe dans sa charpente.
"""
import math

import bpy

import carcasse as C
import ere3 as E
import geo as G
import mat as MT

Z_PONT = 0.45
GRAND = (-0.5, -0.02)                              # grand cristal dans la cage (repère de la halle)
RELIQUES = ((2.72, -2.38, 0.86), (-3.42, -2.5, 0.62))   # reliquaires sud-est et sud-ouest (monde : x, y, rayon)
CHAP = dict(x0=-2.4, x1=1.55, y0=-2.85, y1=-1.5, z0=0.3)
LUIT = (0.434, 0.162, 1.0)                         # #B070FF


def lin(h):
    """Couleur de la bible (#RRGGBB, sRGB) en valeurs linéaires."""
    def f(c):
        c /= 255.0
        return c / 12.92 if c < 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (f(int(h[1:3], 16)), f(int(h[3:5], 16)), f(int(h[5:7], 16)))


def _cristal_surface(m, deep, pale, graine):
    """Couleur et reflet communs aux cristaux : une face profonde, pâle seulement en incidence rasante, à peine marbrée."""
    N, L = m.node_tree.nodes, m.node_tree.links
    p = N["Principled BSDF"]
    tc = N.new("ShaderNodeTexCoord")
    lw = N.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.3
    c = MT._mix(N, L, lw.outputs["Facing"], deep, pale)
    nz = MT._range(N, L, MT._bruit(N, L, tc.outputs["Object"], 2.4, 3.0, 0.5, (graine, 2.0, 1.0), (1.6, 1.6, 0.35)), 0.35, 0.65, 0.82, 1.1)
    L.new(MT._scale(N, L, c, nz), p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.26
    p.inputs["Metallic"].default_value = 0.0
    if "Specular IOR Level" in p.inputs:
        p.inputs["Specular IOR Level"].default_value = 0.4
    bev = N.new("ShaderNodeBevel")
    bev.inputs["Radius"].default_value = 0.012
    L.new(bev.outputs["Normal"], p.inputs["Normal"])
    return tc


def cristal(S, name, deep, pale, force, main=0.5, graine=0.0):
    """Facette de cristal OPAQUE qui luit (matière « emissive » du pipeline) ; l'émission varie peu : ce sont les écarts
    d'une facette à l'autre qui font le cristal, pas un nuage."""
    m = S.mat_emissive(name, LUIT, strength=force, base=deep, main_scale=main, crust=(1.0, 0.0, graine))
    tc = _cristal_surface(m, deep, pale, graine)
    N, L = m.node_tree.nodes, m.node_tree.links
    L.new(MT._range(N, L, MT._bruit(N, L, tc.outputs["Object"], 1.8, 2.0, 0.5, (graine + 5.0, 1.0, 3.0), (1.5, 1.5, 0.3)), 0.35, 0.65, 0.72, 1.0), N["fo_emit_strength"].inputs[0])
    return m


def cristal_mat(name, deep, pale, graine=0.0):
    """Facette de cristal éteinte (petits éclats, faces à l'ombre : ni lueur, ni foyer de plus)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    _cristal_surface(m, deep, pale, graine)
    m["fo_kind"] = "surface"
    return m


def matieres(S):
    MT.PATINE.update(ta=0.16, ra=0.28, ec=0.7, nu_k=1.45, ec_col=(0.028, 0.018, 0.008))
    sf = MT.surface
    cr = (0.008, 0.0065, 0.004)
    jaunes = [(0.36, 0.205, 0.013), (0.24, 0.135, 0.009), (0.5, 0.32, 0.025), (0.33, 0.15, 0.01)]
    M = E.mats_base(sf, "q7", jaunes, cr, MT)
    br = lin("#6A5236")
    pr = lin("#4A4038")
    bronze = (br[0] * 1.25, br[1] * 1.15, br[2] * 1.05)
    vdg = (0.05, 0.1, 0.07)
    M["patch"] = sf("q7_patch", (0.13, 0.078, 0.032), rough=0.5, met=0.45, coulures=0.8, rouille=vdg, usure=0.7, nu=(0.55, 0.38, 0.18),
                    crasse=0.8, crasse_col=cr, pied=(0.3, 1.1, 0.55), grain=0.12, graine=84)
    M["rapiece"] = sf("q7_rapiece", (0.15, 0.125, 0.105), rough=0.8, met=0.05, coulures=0.7, usure=0.5, crasse=0.75, crasse_col=cr, grain=0.14, graine=87)
    M["rapiece2"] = sf("q7_rapiece2", (0.2, 0.075, 0.03), rough=0.7, met=0.3, coulures=0.6, usure=0.5, nu=(0.3, 0.16, 0.08),
                       crasse=0.75, crasse_col=cr, grain=0.14, graine=88)
    M["bronze"] = sf("q7_bronze", bronze, rough=0.42, met=0.72, coulures=0.85, rouille=vdg, usure=0.8, nu=(0.72, 0.5, 0.25),
                     crasse=0.75, crasse_col=cr, grain=0.1, graine=86)
    M["bronze_s"] = sf("q7_bronze_s", (bronze[0] * 0.55, bronze[1] * 0.55, bronze[2] * 0.55), rough=0.55, met=0.5, coulures=0.7, rouille=vdg,
                       usure=0.6, nu=(0.5, 0.35, 0.18), crasse=0.8, crasse_col=cr, grain=0.12, graine=106)
    M["anneau"] = M["bronze"]
    M["toit"] = sf("q7_toit", (0.21, 0.122, 0.044), rough=0.5, met=0.3, coulures=0.7, rouille=vdg, usure=0.65, nu=(0.5, 0.33, 0.15),
                   crasse=0.8, crasse_col=cr, grain=0.13, graine=100)
    M["toit2"] = sf("q7_toit2", (0.085, 0.09, 0.05), rough=0.55, met=0.35, coulures=0.7, rouille=vdg, usure=0.6, nu=(0.42, 0.3, 0.15),
                    crasse=0.8, crasse_col=cr, grain=0.13, graine=107)
    M["pierre"] = sf("q7_pierre", (pr[0] * 1.5, pr[1] * 1.5, pr[2] * 1.5), rough=0.9, met=0.0, tole=(0.46, 0.2), joint=0.3, var=0.22, coulures=0.4,
                     rouille=(0.03, 0.03, 0.04), usure=0.65, nu=(0.28, 0.25, 0.22), crasse=0.8, crasse_col=cr, pied=(0.0, 0.4, 0.6),
                     relief=0.7, grain=0.16, graine=99)
    M["taille"] = sf("q7_taille", (pr[0] * 2.3, pr[1] * 2.3, pr[2] * 2.25), rough=0.88, met=0.0, usure=0.75, nu=(0.34, 0.31, 0.27), crasse=0.8,
                     crasse_col=cr, grain=0.18, graine=108)
    M["dalle"] = sf("q7_dalle", (pr[0] * 1.9, pr[1] * 1.85, pr[2] * 1.8), rough=0.88, met=0.0, usure=0.7, nu=(0.3, 0.27, 0.24), crasse=0.85,
                    crasse_col=cr, grain=0.34, graine=109)
    M["dalle2"] = sf("q7_dalle2", (pr[0] * 1.35, pr[1] * 1.3, pr[2] * 1.3), rough=0.9, met=0.0, usure=0.6, nu=(0.26, 0.23, 0.2), crasse=0.85,
                     crasse_col=cr, grain=0.34, graine=110)
    M["bois"] = sf("q7_bois", (0.2, 0.16, 0.11), rough=0.85, met=0.0, tole=(0.9, 0.115), joint=0.18, var=0.28, coulures=0.4,
                   rouille=(0.03, 0.045, 0.02), usure=0.5, nu=(0.22, 0.15, 0.08), crasse=0.75, crasse_col=cr, relief=0.5, grain=0.14, graine=97)
    M["cristal0"] = cristal(S, "q7_cristal0", (0.1, 0.028, 0.36), (0.28, 0.1, 0.8), 0.18, graine=11.0)
    M["cristal1"] = cristal(S, "q7_cristal1", (0.17, 0.055, 0.66), (0.36, 0.14, 0.95), 0.4, graine=23.0)
    M["cristal2"] = cristal_mat("q7_cristal2", (0.035, 0.009, 0.13), (0.24, 0.1, 0.55), graine=37.0)
    M["eteint0"] = cristal_mat("q7_eteint0", (0.09, 0.028, 0.3), (0.34, 0.15, 0.72), graine=41.0)
    M["eteint1"] = cristal_mat("q7_eteint1", (0.17, 0.055, 0.6), (0.36, 0.14, 0.9), graine=43.0)
    M["eteint2"] = M["cristal2"]
    M["vitrail"] = MT.verre("q7_vitrail", col=(0.03, 0.012, 0.075), reflet=(0.24, 0.14, 0.42))
    M["hublot"] = MT.lumiere(S, "q7_hublot", LUIT, 1.3, main=0.4)
    M["veilleuse"] = MT.verre("q7_veilleuse", col=(0.05, 0.02, 0.1), reflet=(0.28, 0.17, 0.42))
    M["voyant"] = MT.lumiere(S, "q7_voyant", (1.0, 0.09, 0.03), 7.0, main=0.4)
    return M


# ================================================================================================ cristaux
def eclat(c, h, r, rnd, n=6, pen=(0.0, 0.0), tete=0.3):
    """Pointe de cristal à n pans irréguliers, cassée de biais (pente pen, épaules à hauteurs tirées) : trois meshes, un par
    ton ; chaque facette a ses sommets, donc son arête nette et son reflet."""
    z0 = c[2]
    a0 = rnd.f(0.0, G.TAU)
    angs = [a0 + G.TAU * (k + rnd.f(-0.2, 0.2)) / n for k in range(n)]
    rad = [r * rnd.f(0.78, 1.18) for _ in range(n)]
    epaule = [z0 + h * (1.0 - tete * rnd.f(0.7, 1.35)) for _ in range(n)]

    def pos(a, rr, z):
        k = z - z0
        return (c[0] + rr * math.cos(a) + pen[0] * k, c[1] + rr * math.sin(a) + pen[1] * k, z)
    ta, tr = rnd.f(0.0, G.TAU), r * rnd.f(0.1, 0.35)
    pointe = pos(ta, tr, z0 + h)
    out = [([], [], []), ([], [], []), ([], [], [])]

    def face(pts, ton):
        v, f, u = out[ton]
        b = len(v)
        v.extend(pts)
        f.append(tuple(range(b, b + len(pts))))
        acc = 0.0
        for i, p in enumerate(pts):
            if i:
                acc += G.length(G.sub(p, pts[i - 1]))
            u.append((acc, p[2]))
    for k in range(n):
        k2 = (k + 1) % n
        ton = rnd.i(0, 2)
        a, b = angs[k], angs[k2]
        ra, rb = rad[k], rad[k2]
        p0, p1 = pos(a, ra * 0.92, z0), pos(b, rb * 0.92, z0)
        p2, p3 = pos(b, rb * 0.78, epaule[k2]), pos(a, ra * 0.78, epaule[k])
        if h >= 1.5:                                                 # plans de clivage : le pan se fend de biais en trois tons
            t1, t2 = rnd.f(0.22, 0.42), rnd.f(0.55, 0.8)
            d1, d2 = rnd.f(-0.12, 0.12), rnd.f(-0.1, 0.1)
            m0, m1 = G.lerp(p0, p3, t1 + d1), G.lerp(p1, p2, t1 - d1)
            n0, n1 = G.lerp(p0, p3, t2 + d2), G.lerp(p1, p2, t2 - d2)
            face([p0, p1, m1, m0], ton)
            face([m0, m1, n1, n0], (ton + rnd.i(0, 2)) % 3)
            face([n0, n1, p2, p3], (ton + rnd.i(0, 2)) % 3)
        else:
            face([p0, p1, p2, p3], ton)
        face([p3, p2, pointe], (ton + 1) % 3 if rnd.f() < 0.7 else ton)
    return out


def pose(lot, M, c, h, r, rnd, n=6, pen=(0.0, 0.0), tete=0.3, seuil=1.65):
    """Sous la hauteur seuil, l'éclat ne luit pas : les foyers restent le grand cristal et ses satellites."""
    cle = "cristal%d" if h >= seuil else "eteint%d"
    for ton, mesh in enumerate(eclat(c, h, r, rnd, n, pen, tete)):
        if mesh[0]:
            lot.put(M[cle % ton], mesh)


def grappe(lot, M, cx, cy, z, h, r, rnd, liste, n=6):
    """Grande pointe et pointes secondaires : liste de (dx, dy, part de h, part de r, ouverture vers l'extérieur)."""
    pose(lot, M, (cx, cy, z), h, r, rnd, n, (rnd.f(-0.05, 0.05), rnd.f(-0.04, 0.04)))
    for (dx, dy, kh, kr, ouv) in liste:
        d = math.hypot(dx, dy) or 1.0
        pose(lot, M, (cx + dx, cy + dy, z), h * kh, r * kr, rnd, 5 + (rnd.i(0, 1)), (ouv * dx / d, ouv * dy / d))


def griffes(lot, M, cx, cy, z, R, h, n, rnd, r=0.035):
    """Griffes de bronze : du cerceau au sol jusqu'au flanc du cristal, courbées vers l'intérieur."""
    for k in range(n):
        a = G.TAU * (k + rnd.f(-0.12, 0.12)) / n + 0.3
        rr = R * rnd.f(0.92, 1.05)
        hh = h * rnd.f(0.75, 1.1)
        pts = [(cx + rr * math.cos(a), cy + rr * math.sin(a), z), (cx + rr * 1.02 * math.cos(a), cy + rr * 1.02 * math.sin(a), z + hh * 0.42),
               (cx + rr * 0.74 * math.cos(a), cy + rr * 0.74 * math.sin(a), z + hh * 0.82), (cx + rr * 0.56 * math.cos(a), cy + rr * 0.56 * math.sin(a), z + hh)]
        lot.put(M["bronze"], G.tube(G.catmull(pts, 6), r, 6, rfun=lambda s, i: r * (1.15 - 0.03 * i)))
        q = pts[0]
        lot.put(M["bronze_s"], G.boite((q[0], q[1], z + 0.04), (0.16, 0.14, 0.09), a))


def socle_rond(lot, M, cx, cy, z0, R, marches=2, dz=0.14, rnd=None):
    """Socle rond de pierre taillée à gradins : pierres par quartiers irréguliers, joints sombres."""
    z = z0
    for g in range(marches):
        rg = R + 0.22 * (marches - 1 - g)
        a = rnd.f(0.0, 0.6)
        lot.put(M["noyau"], G.tour([(z, rg - 0.02), (z + dz - 0.01, rg - 0.02)], 36, "z", (cx, cy, 0.0), cap1=True))
        while a < G.TAU + 0.0:
            w = min(rnd.f(0.3, 0.62) / max(0.4, rg), G.TAU - a)
            if w < 0.04:
                break
            m = M["taille"] if rnd.f() < 0.72 else M["dalle2"]
            h = dz + rnd.f(-0.015, 0.015)
            lot.put(m, _quartier(cx, cy, rg + rnd.f(-0.015, 0.02), rg - 0.3, a + 0.012, a + w - 0.012, z, z + h))
            a += w
        z += dz
    return z


def _quartier(cx, cy, R, r0, a0, a1, z0, z1):
    n = max(2, int((a1 - a0) * R / 0.12) + 1)
    As = [a0 + (a1 - a0) * i / float(n) for i in range(n + 1)]
    ext = [(cx + R * math.cos(a), cy + R * math.sin(a)) for a in As]
    inn = [(cx + r0 * math.cos(a), cy + r0 * math.sin(a)) for a in As]
    rings = [[(p[0], p[1], z0) for p in ext], [(p[0], p[1], z1) for p in ext], [(p[0], p[1], z1) for p in inn]]
    return G.loft(rings, closed=False)


# ================================================================================================ chapelle
def _pavillon_fac(lot, M, cx, cy, rx, ry, z0, ze, zf, n, rr, lanterne=True):
    """Pavillon polygonal : murs de pierre à léger fruit, contreforts aux angles, bandeau de bronze, toit à pans de bronze,
    arêtiers et joints debout, lanterne à vitraux coiffée d'un éclat."""
    ang = [G.TAU * (k + rr.f(-0.09, 0.09)) / n + 0.2 for k in range(n)]
    pl = [(cx + rx * math.cos(a), cy + ry * math.sin(a)) for a in ang]
    ph = [(cx + rx * 0.95 * math.cos(a), cy + ry * 0.95 * math.sin(a)) for a in ang]
    lot.put(M["pierre"], E.tronc(pl, ph, z0, ze))
    for k in range(n):
        a = ang[k]
        q0 = (cx + (rx + 0.08) * math.cos(a), cy + (ry + 0.08) * math.sin(a))
        lot.put(M["taille"], G.boite((q0[0], q0[1], z0 + (ze - z0) * 0.4), (0.15, 0.15, (ze - z0) * 0.8), a))
        lot.put(M["bronze_s"], G.boite((q0[0], q0[1], z0 + (ze - z0) * 0.82), (0.17, 0.17, 0.05), a))
    bord = [(cx + (rx + 0.12) * math.cos(a), cy + (ry + 0.12) * math.sin(a), ze + 0.01) for a in ang]
    lot.put(M["bronze"], G.tube(bord + [bord[0]], 0.035, 6))
    haut = [(cx + 0.2 * rx * math.cos(a), cy + 0.2 * ry * math.sin(a), zf) for a in ang]
    for k in range(n):
        k2 = (k + 1) % n
        a0, a1, b1, b0 = bord[k], bord[k2], haut[k2], haut[k]
        # 3 à 4 lés de largeur tirée sur chaque pan
        t = 0.0
        while t < 0.999:
            w = min(rr.f(0.2, 0.42), 1.0 - t)
            if 1.0 - t - w < 0.12:
                w = 1.0 - t
            m = M["toit"] if rr.f() < 0.8 else (M["toit2"] if rr.f() < 0.5 else M["bronze_s"])
            q = [G.lerp(a0, a1, t + 0.012), G.lerp(a0, a1, t + w - 0.012), G.lerp(b0, b1, t + w - 0.012), G.lerp(b0, b1, t + 0.012)]
            top = [G.add(p, (0, 0, 0.025)) for p in q]
            lot.put(m, G.merge((top, [(0, 1, 2, 3)], [(p[0], p[1]) for p in top]), G.loft([[q[0], q[1]], [top[0], top[1]]], closed=False)))
            if t > 0:
                lot.put(M["bronze_s"], G.tube([G.add(q[0], (0, 0, 0.035)), G.add(q[3], (0, 0, 0.035))], 0.012, 4))
            t += w
        lot.put(M["bronze"], G.tube([G.add(a0, (0, 0, 0.03)), G.add(b0, (0, 0, 0.03))], 0.024, 5))
    if lanterne:
        rl = max(0.12, 0.2 * min(rx, ry))
        lot.put(M["pierre"], G.tour([(zf, rl + 0.02), (zf + 0.2, rl)], 6, "z", (cx, cy, 0.0), cap1=True))
        for k in range(6):
            a = G.TAU * k / 6 + 0.5
            lot.put(M["vitrail"], G.boite((cx + rl * math.cos(a), cy + rl * math.sin(a), zf + 0.11), (0.06, 0.03, 0.13), a + math.pi / 2))
        lot.put(M["bronze"], G.tour([(zf + 0.2, rl + 0.05), (zf + 0.24, rl + 0.05), (zf + 0.3, 0.05)], 6, "z", (cx, cy, 0.0)))
        pose(lot, M, (cx, cy, zf + 0.26), 0.42, 0.07, rr, 5, (0.02, 0.0))


def _nef(lot, M, x0, x1, y0, y1, z0, ze, zf, rr, abside):
    """Nef de pierre, contreforts au pas irrégulier, toit à deux pans de lés de bronze, abside à cinq pans au bout
    abside = -1 (ouest) ou +1 (est). Le pan sud, vu de trois quarts, porte lucarnes et verrières de cristal."""
    ym = (y0 + y1) / 2
    xa = x0 if abside < 0 else x1          # base de l'abside
    xo = x1 if abside < 0 else x0          # bout accolé
    prof = (y1 - y0) * 0.55
    mur = [(min(xa, xo), y0), (max(xa, xo), y0), (max(xa, xo), y1), (min(xa, xo), y1)]
    lot.put(M["pierre"], E.tronc(mur, E.retrait(mur, 0.03), z0, ze))
    # contreforts et lancettes, façade sud
    x = min(xa, xo) + 0.1
    kind = 0
    while x < max(xa, xo) - 0.1:
        v, f, u = E.tronc([(x - 0.07, y0 - 0.18), (x + 0.07, y0 - 0.18), (x + 0.07, y0), (x - 0.07, y0)],
                          [(x - 0.05, y0 - 0.02), (x + 0.05, y0 - 0.02), (x + 0.05, y0), (x - 0.05, y0)], z0, ze - 0.04)
        lot.put(M["taille"], (v, f, u))
        lot.put(M["bronze_s"], G.boite((x, y0 - 0.1, z0 + 0.34), (0.16, 0.18, 0.04)))
        lot.put(M["bronze"], G.tour([(ze - 0.05, 0.05), (ze + 0.03, 0.045), (ze + 0.3, 0.0)], 5, "z", (x, y0 - 0.1, 0.0)))
        xn = x + rr.f(0.42, 0.62)
        xl = (x + min(xn, max(xa, xo))) / 2
        if xn - x > 0.3 and xl < max(xa, xo) - 0.1:
            _lancette(lot, M, xl, y0, z0 + 0.15, ze - 0.14, 0.1 + 0.03 * (kind % 2), kind)
            kind += 1
        x = xn
    # abside : cinq pans autour de xa
    h2 = (y1 - y0) / 2
    ap = [(xa + abside * prof * math.cos(t), ym + h2 * math.sin(t)) for t in [-math.pi / 2 + math.pi * k / 5 for k in range(6)]]
    lot.put(M["pierre"], G.prisme(ap, z0, ze - 0.01))
    for p in ap[1:-1]:
        lot.put(M["taille"], G.boite((p[0] + abside * 0.05, p[1], z0 + (ze - z0) * 0.42), (0.14, 0.14, (ze - z0) * 0.85)))
    # toit à deux pans (lés irréguliers)
    deb = 0.12
    ridge0, ridge1 = (min(xa, xo), ym, zf), (max(xa, xo), ym, zf)
    for (ys, zs) in ((y0 - deb, ze - 0.03), (y1 + deb, ze - 0.03)):
        u = min(xa, xo) - (0.0 if abside < 0 else deb)
        umax = max(xa, xo) + (0.0 if abside > 0 else deb)
        while u < umax - 0.05:
            w = min(rr.f(0.16, 0.32), umax - u)
            lucarne = ys < ym and rr.f() < 0.16
            m = M["vitrail"] if lucarne else (M["toit"] if rr.f() < 0.8 else (M["toit2"] if rr.f() < 0.5 else M["bronze_s"]))
            q = [(u + 0.01, ys, zs), (u + w - 0.01, ys, zs), (u + w - 0.01, ym, zf), (u + 0.01, ym, zf)]
            top = [G.add(p, (0, 0, 0.03)) for p in q]
            lot.put(m, G.merge((top, [(0, 1, 2, 3)], [(p[0], p[1]) for p in top]), G.loft([[q[0], q[1]], [top[0], top[1]]], closed=False)))
            lot.put(M["bronze_s"], G.tube([G.add(q[0], (0, 0, 0.04)), G.add(q[3], (0, 0, 0.04))], 0.012, 4))
            if lucarne:
                for t in (0.25, 0.5, 0.75):
                    lot.put(M["bronze"], G.tube([G.add(G.lerp(q[0], q[3], t), (0, 0, 0.04)), G.add(G.lerp(q[1], q[2], t), (0, 0, 0.04))], 0.009, 4))
            u += w
    # croupe de l'abside
    xr = xa
    bord = [(p[0] + abside * 0.1 * abs(p[0] - xa) / max(prof, 0.01), p[1] + (p[1] - ym) * 0.08, ze - 0.03) for p in ap]
    for k in range(5):
        a, b = bord[k], bord[k + 1]
        tri_c = (xr, ym, zf)
        n_l = 3
        for j in range(n_l):
            t0, t1 = j / float(n_l), (j + 1) / float(n_l)
            q = [G.lerp(a, b, t0 + 0.012), G.lerp(a, b, t1 - 0.012), tri_c]
            top = [G.add(p, (0, 0, 0.03)) for p in q]
            lot.put(M["toit"] if rr.f() < 0.8 else M["bronze_s"], (top, [(0, 1, 2)], [(p[0], p[1]) for p in top]))
        lot.put(M["bronze"], G.tube([G.add(a, (0, 0, 0.035)), G.add(tri_c, (0, 0, 0.035))], 0.02, 5))
    lot.put(M["bronze"], G.tube(bord, 0.028, 5))
    lot.put(M["bronze"], G.tube([G.add(ridge0, (0, 0, 0.05)), G.add(ridge1, (0, 0, 0.05))], 0.04, 6))
    lot.put(M["bronze"], G.tube([(min(xa, xo), y0 - deb, ze), (max(xa, xo), y0 - deb, ze)], 0.028, 5))
    return ym


def _lancette(lot, M, x, y, z0, z1, w, kind):
    """Fenêtre en lancette : encadrement de pierre, vitrail, arc brisé ; meneau ou non selon kind."""
    zm = z1 - w * 1.2
    fr = [(x - w * 0.7, z0), (x + w * 0.7, z0), (x + w * 0.7, zm), (x, z1 + 0.04), (x - w * 0.7, zm)]
    gl = [(x - w * 0.42, z0 + 0.03), (x + w * 0.42, z0 + 0.03), (x + w * 0.42, zm), (x, z1 - 0.03), (x - w * 0.42, zm)]
    lot.put(M["taille"], ([(p[0], y - 0.012, p[1]) for p in fr], [tuple(range(5))], [(p[0], p[1]) for p in fr]))
    lot.put(M["vitrail"], ([(p[0], y - 0.022, p[1]) for p in gl], [tuple(range(5))], [(p[0], p[1]) for p in gl]))
    if kind % 3 != 2:
        lot.put(M["bronze_s"], G.boite((x, y - 0.026, (z0 + z1) / 2), (0.014, 0.008, z1 - z0 - 0.05)))
    if kind % 2 == 0:
        lot.put(M["bronze_s"], G.boite((x, y - 0.026, z0 + (z1 - z0) * 0.5), (w * 0.9, 0.008, 0.012)))


def dalles(lot, M, xa, xb, ya, yb, z, rr, trou=0.05):
    """Parvis de dalles de tailles tirées, rangs décalés ; le fond sombre se voit dans les joints et les manques."""
    lot.put(M["noyau"], G.boite(((xa + xb) / 2, (ya + yb) / 2, z - 0.05), (xb - xa, yb - ya, 0.06)))
    y = ya
    while y < yb - 0.02:
        hy = min(rr.f(0.26, 0.5), yb - y)
        x = xa
        while x < xb - 0.02:
            w = min(rr.f(0.3, 0.72), xb - x)
            if rr.f() > trou:
                m = M["dalle"] if rr.f() < 0.72 else M["dalle2"]
                lot.put(m, G.boite((x + w / 2, y + hy / 2, z - 0.03 + rr.f(-0.008, 0.008)), (w - 0.022, hy - 0.022, 0.06 + rr.f(0.0, 0.015)), rr.f(-0.004, 0.004)))
            x += w
        y += hy


def mur_sud(lot, M, xa, xb, y, z, rr):
    """Mur de soutènement au sud : gros blocs à fruit, assises décalées (le bord n'est jamais une règle)."""
    x = xa
    while x < xb - 0.02:
        w = min(rr.f(0.34, 0.74), xb - x)
        d = rr.f(-0.03, 0.05)
        lot.put(M["taille"] if rr.f() < 0.65 else M["pierre"], G.prisme([(x + 0.01, y + d - 0.12), (x + w - 0.01, y + d - 0.12), (x + w - 0.01, y + 0.1), (x + 0.01, y + 0.1)], 0.0, z + rr.f(-0.015, 0.02), 1.0, (0.0, 0.03)))
        x += w


def _borne(lot, M, x, y, z, rr, lum):
    """Borne de pierre et son petit éclat en coupelle de bronze."""
    lot.put(M["taille"], G.prisme([(x - 0.09, y - 0.09), (x + 0.09, y - 0.09), (x + 0.09, y + 0.09), (x - 0.09, y + 0.09)], z, z + 0.34, 0.75))
    lot.put(M["bronze"], G.tour([(z + 0.34, 0.08), (z + 0.38, 0.11), (z + 0.4, 0.08)], 8, "z", (x, y, 0.0), cap1=True))
    if lum:
        pose(lot, M, (x, y, z + 0.38), 0.32, 0.055, rr, 5, (0.03, 0.0))


# ================================================================================================ build
def build(S, lot):
    M = matieres(S)
    P = C.Pose(**E.POSE)
    r = G.Rnd(7077)
    rc = G.Rnd(7171)
    niv = P.niv
    TAU = G.TAU
    choix = E.mat_tirage(M, [("jaune0", 0.46), ("jaune1", 0.65), ("jaune2", 0.75), ("jaune3", 0.84), ("patch", 0.93), ("rapiece", 0.965), ("rapiece2", 1.0)])

    # ======================================================================================== 1. carcasse
    pieds = E.carcasse(lot, M, P, r, choix, ouverture=(-1.4, 1.65))
    E.grilles_coque(lot, M, P)
    for (pn, ps) in pieds:                                           # jambes : bronze sur dé de pierre
        for p in (pn, ps):
            h = p[2]
            lot.put(M["bronze_s"], G.boite((p[0], p[1], h / 2), (0.15, 0.17, h)))
            lot.put(M["bronze"], G.boite((p[0], p[1], h - 0.15), (0.24, 0.26, 0.12)))
            lot.put(M["taille"], G.prisme([(p[0] - 0.24, p[1] - 0.24), (p[0] + 0.24, p[1] - 0.24), (p[0] + 0.24, p[1] + 0.24), (p[0] - 0.24, p[1] + 0.24)], 0.0, 0.36, 0.8))
            pts = [((p[0] + dx, p[1] + dy, 0.385), (0, 0, 1)) for dx in (-0.09, 0.09) for dy in (-0.1, 0.1)]
            lot.put(M["riv"], G.rivets_le_long(pts, 0.022, 0.016))

    # ======================================================================================== 2. dans la cage : le grand cristal
    lot.xf = niv
    lot.put(M["pierre"], E.tronc(E.chanfrein(-2.7, 2.1, -1.35, 1.35, 0.5), E.chanfrein(-2.62, 2.02, -1.27, 1.27, 0.5), 0.0, Z_PONT))
    lot.xf = None
    gc = niv((GRAND[0], GRAND[1], 0.0))
    zs = socle_rond(lot, M, gc[0], gc[1], Z_PONT, 1.25, 2, 0.16, rc)
    lot.put(M["bronze"], E.cerceau(gc[0], gc[1], zs + 0.03, 1.22, 0.05, 40))
    griffes(lot, M, gc[0], gc[1], zs, 1.2, 1.7, 7, rc, 0.042)
    grappe(lot, M, gc[0], gc[1], zs - 0.05, 4.95, 0.62, rc,
           [(-0.62, 0.22, 0.68, 0.72, 0.13), (0.66, -0.16, 0.56, 0.62, 0.16), (0.12, -0.66, 0.42, 0.56, 0.2), (-0.5, -0.5, 0.36, 0.46, 0.22),
            (0.78, 0.4, 0.34, 0.42, 0.24), (-0.05, 0.7, 0.45, 0.5, 0.12), (-0.9, -0.08, 0.26, 0.36, 0.3), (0.42, -0.72, 0.22, 0.3, 0.32)])
    # deux cerceaux de résonance tenus par des lyres de bronze qui montent de la coque
    zr = (3.15, 3.95)
    Rr = (1.02, 0.62)
    lot.put(M["bronze"], E.cerceau(gc[0] + 0.1, gc[1], zr[0], Rr[0], 0.04, 36, (0.08, -0.12)))
    lot.put(M["bronze"], E.cerceau(gc[0] + 0.16, gc[1], zr[1], Rr[1], 0.03, 28, (-0.1, 0.1)))
    for k, (dd, xt) in enumerate(((1, 0.55), (-1, 0.55), (1, -0.85), (-1, -0.85))):
        e = P.xf(C.point(xt, E.A_TOP - dd * 0.75, 0.12))
        hautl = (gc[0] + 0.16 + 0.55 * (0.2 if k < 2 else -0.8), gc[1] + dd * 0.56, zr[1] + 0.05 * dd)
        mid = (gc[0] + 0.1 + (xt + 0.5) * 0.85, gc[1] + dd * 1.04, zr[0])
        lot.put(M["bronze"], G.tube(G.catmull([e, mid, hautl], 8), 0.032, 6))
    for k in range(3):                                               # pointes de lyre qui dépassent, en diapason
        a = 2.0 + k * 2.1
        q = (gc[0] + 0.16 + 0.62 * math.cos(a), gc[1] + 0.62 * math.sin(a), zr[1])
        lot.put(M["bronze"], G.tube([q, G.add(q, (0.02 * math.cos(a), 0.02 * math.sin(a), 0.5 - 0.1 * k))], 0.016, 5))
    # -- éclats qui ont percé la peau (queue, crâne) --
    for (x, a, h, rr_, pen) in ((-2.75, E.A_TOP + 0.75, 1.15, 0.2, (-0.12, -0.2)), (-2.95, E.A_TOP + 1.05, 0.7, 0.13, (-0.2, -0.2)),
                                (2.65, E.A_TOP + 0.55, 0.85, 0.15, (0.1, -0.25)), (2.45, E.A_TOP - 0.55, 1.05, 0.17, (0.12, 0.18))):
        q = P.xf(C.point(x, a, -0.03))
        pose(lot, M, q, h, rr_, rc, 5, pen)
        lot.put(M["bronze_s"], E.cerceau(q[0], q[1], q[2] + 0.1, rr_ * 1.25, 0.018, 12))

    # ======================================================================================== 3. tour au prisme et obélisque
    tw = (1.72, 3.05, 0.0)                                           # entre le grand cristal et la grappe, au-dessus du dos
    hexa = [(tw[0] + 0.62 * math.cos(0.3 + TAU * k / 6), tw[1] + 0.54 * math.sin(0.3 + TAU * k / 6)) for k in range(6)]
    hexb = [(tw[0] + 0.44 * math.cos(0.3 + TAU * k / 6), tw[1] + 0.4 * math.sin(0.3 + TAU * k / 6)) for k in range(6)]
    lot.put(M["pierre"], E.tronc(hexa, hexb, 0.0, 2.45))
    for z in (0.75, 1.5, 2.28):
        k = 1.0 - (z / 2.45) * 0.28
        pts = [(tw[0] + 0.64 * k * math.cos(0.3 + TAU * j / 6), tw[1] + 0.56 * k * math.sin(0.3 + TAU * j / 6), z) for j in range(7)]
        lot.put(M["bronze"], G.tube(pts, 0.028, 5))
    lot.put(M["bronze"], G.tour([(2.45, 0.52), (2.54, 0.56), (2.6, 0.32), (2.64, 0.06)], 6, "z", (tw[0], tw[1], 0.0), a0=0.3, a1=0.3 + TAU))
    for s in (-1, 1):                                                # fourche du prisme
        pts = [(tw[0], tw[1], 2.62), (tw[0] + s * 0.34, tw[1] + 0.02, 2.95), (tw[0] + s * 0.3, tw[1] + 0.02, 3.5)]
        lot.put(M["bronze"], G.tube(G.catmull(pts, 6), 0.03, 6))
    pose(lot, M, (tw[0] + 0.02, tw[1] + 0.02, 2.82), 0.95, 0.2, rc, 4, (0.0, 0.0), 0.45)
    lot.put(M["bronze"], E.cerceau(tw[0], tw[1], 3.2, 0.32, 0.018, 20, (0.1, 0.05)))
    for (dx, z) in ((-0.2, 0.25), (0.25, 1.05)):                     # archères
        lot.put(M["noir"], G.boite((tw[0] + dx, tw[1] - 0.54 + z * 0.06, z + 0.3), (0.07, 0.03, 0.3)))
    tq = (-1.85, 3.42)                                               # obélisque, nord, à droite de la dérive
    lot.put(M["taille"], E.tronc(E.chanfrein(tq[0] - 0.3, tq[0] + 0.3, tq[1] - 0.3, tq[1] + 0.3, 0.1), E.chanfrein(tq[0] - 0.14, tq[0] + 0.14, tq[1] - 0.14, tq[1] + 0.14, 0.05), 0.0, 2.2))
    lot.put(M["bronze"], G.tour([(2.2, 0.15), (2.26, 0.17), (2.32, 0.09)], 8, "z", (tq[0], tq[1], 0.0), cap1=True))
    pose(lot, M, (tq[0], tq[1], 2.28), 1.3, 0.16, rc, 5, (0.03, -0.02), seuil=1.2)
    griffes(lot, M, tq[0], tq[1], 2.26, 0.2, 0.34, 3, rc, 0.016)
    lot.put(M["pierre"], G.prisme(E.chanfrein(tq[0] - 0.46, tq[0] + 0.46, tq[1] - 0.46, tq[1] + 0.46, 0.14), 0.0, 0.24, 0.9))
    for k in range(3):
        a = TAU * k / 3 + 0.5
        lot.put(M["bronze_s"], G.tube([(tq[0], tq[1], 2.0), (tq[0] + 0.95 * math.cos(a), tq[1] + 0.75 * math.sin(a), 0.03)], 0.008, 3))

    # ======================================================================================== 4. grappe nord-est dans sa charpente
    gx, gy, gr = 4.15, 2.92, 0.95
    zg = socle_rond(lot, M, gx, gy, 0.0, gr + 0.2, 2, 0.2, rc)
    grappe(lot, M, gx, gy, zg - 0.06, 2.35, 0.46, rc,
           [(-0.42, 0.14, 0.76, 0.66, 0.1), (0.42, -0.2, 0.6, 0.6, 0.16), (0.08, -0.48, 0.42, 0.52, 0.22), (-0.4, -0.36, 0.34, 0.42, 0.24),
            (0.52, 0.28, 0.48, 0.42, 0.18)])
    cols = [(gx + (gr + 0.12) * math.cos(TAU * k / 8 + 0.2), gy + (gr + 0.12) * math.sin(TAU * k / 8 + 0.2)) for k in range(8)]
    for (x, y) in cols:
        lot.put(M["bronze"], G.boite((x, y, 0.95), (0.08, 0.08, 1.9)))
        lot.put(M["taille"], G.boite((x, y, 0.42), (0.16, 0.16, 0.12)))
    for (z, rt) in ((1.9, 0.04), (1.1, 0.028)):
        lot.put(M["bronze"], G.tube([(x, y, z) for (x, y) in cols] + [(cols[0][0], cols[0][1], z)], rt, 4))
    for k in range(8):
        a, b = cols[k], cols[(k + 1) % 8]
        for (za, zb_) in ((0.45, 1.1), (1.1, 1.9)):
            if k in (5, 6) and za < 1.0:                             # côté caméra : ouvert en bas
                continue
            lot.put(M["bronze_s"], G.tube([(a[0], a[1], za), (b[0], b[1], zb_)], 0.013, 4))
            lot.put(M["bronze_s"], G.tube([(b[0], b[1], za), (a[0], a[1], zb_)], 0.013, 4))
    for k in range(3):                                               # griffes de tête
        a = TAU * k / 3 + 0.8
        q = (gx + (gr + 0.12) * math.cos(a), gy + (gr + 0.12) * math.sin(a), 1.9)
        lot.put(M["bronze"], G.tube(G.catmull([q, (gx + 0.8 * math.cos(a), gy + 0.8 * math.sin(a), 2.2), (gx + 0.45 * math.cos(a), gy + 0.45 * math.sin(a), 2.35)], 5), 0.022, 5))

    # ======================================================================================== 5. chapelle et reliquaires
    K = CHAP
    rv = G.Rnd(7303)
    z0 = K["z0"]
    _nef(lot, M, K["x0"], -0.9, K["y0"] + 0.15, K["y1"] - 0.1, z0, 0.92, 1.42, rv, -1)
    _nef(lot, M, 0.3, K["x1"], K["y0"] + 0.22, K["y1"] - 0.08, z0, 0.88, 1.34, rv, 1)
    _pavillon_fac(lot, M, -0.3, -2.3, 0.82, 0.74, z0, 1.2, 2.08, 8, rv)
    C.hublot(lot, "rond", M["bronze"], M["hublot"], (-0.3, -3.0, 0.98), (0.0, -1.0, 0.25), 0.09)
    # porche du pavillon, marches
    lot.put(M["taille"], E.tronc([(-0.62, -3.14), (0.02, -3.14), (0.02, -2.92), (-0.62, -2.92)], [(-0.58, -3.1), (-0.02, -3.1), (-0.02, -2.92), (-0.58, -2.92)], z0, 0.84))
    lot.put(M["noir"], ([(-0.5, -3.115, z0 + 0.03), (-0.14, -3.115, z0 + 0.03), (-0.14, -3.115, 0.62), (-0.32, -3.115, 0.76), (-0.5, -3.115, 0.62)], [(0, 1, 2, 3, 4)], [(0, 0), (1, 0), (1, 1), (0.5, 1.2), (0, 1)]))
    lot.put(M["bronze"], G.tube([(-0.65, -3.13, 0.82), (-0.3, -3.13, 1.0), (0.05, -3.13, 0.82)], 0.03, 5))
    lot.put(M["bronze"], G.boite((-0.32, -3.12, z0 + 0.3), (0.03, 0.015, 0.58)))
    # cloître : petit toit de bronze qui relie nefs et pavillon au nord (les volumes se chevauchent)
    for (x0, x1) in ((-1.05, -0.95), (0.42, 0.56)):
        lot.put(M["pierre"], G.boite(((x0 + x1) / 2, -2.2, (z0 + 0.82) / 2), (x1 - x0 + 0.4, 0.9, 0.82 - z0)))
    # évents, cheminées et pointes sur les toits
    C.evente(lot, M["bronze"], M["noir"], (-1.75, -2.45, 1.08), 0.2, 0.3, 4, 0.0, 0.1)
    C.evente(lot, M["bronze_s"], M["noir"], (1.0, -2.35, 1.04), 0.18, 0.26, 3, 0.0, 0.1)
    lot.put(M["bronze"], G.tour([(1.05, 0.05), (1.62, 0.05), (1.64, 0.1), (1.72, 0.09), (1.76, 0.0)], 8, "z", (-1.28, -1.85, 0.0)))
    lot.put(M["bronze_s"], G.tour([(1.05, 0.04), (1.5, 0.04), (1.53, 0.08), (1.6, 0.0)], 8, "z", (0.72, -1.95, 0.0)))
    for (x, y, zb, h, rr_, pen) in ((-2.4, -2.18, 1.0, 0.55, 0.075, (-0.1, 0.0)), (1.48, -2.15, 0.95, 0.5, 0.07, (0.12, 0.0))):      # pointes au faîte des absides
        pose(lot, M, (x, y, zb), h, rr_, rv, 5, pen)
    # reliquaires
    zl = {}
    for i, (dx, dy, R) in enumerate(RELIQUES):
        zb = socle_rond(lot, M, dx, dy, 0.24, R + 0.14, 2, 0.14, rc)
        lot.put(M["bronze"], E.cerceau(dx, dy, zb + 0.03, R, 0.035, 28))
        griffes(lot, M, dx, dy, zb, R * 0.95, 0.72 + 0.42 * R, 5 if i == 0 else 4, rc, 0.03)
        if i == 0:
            grappe(lot, M, dx, dy, zb - 0.04, 2.5, 0.34, rc, [(-0.3, 0.14, 0.62, 0.68, 0.16), (0.32, -0.08, 0.5, 0.6, 0.2), (0.02, -0.34, 0.36, 0.5, 0.26), (-0.28, -0.26, 0.26, 0.42, 0.3)])
        else:
            grappe(lot, M, dx, dy, zb - 0.04, 1.75, 0.26, rc, [(0.22, 0.1, 0.62, 0.68, 0.18), (-0.24, 0.02, 0.5, 0.6, 0.22), (0.02, -0.24, 0.32, 0.5, 0.3)])
        zl[i] = zb
        q = (dx + R * 0.35, dy - R - 0.2, 0.3)                       # vanne et cadran au pied
        lot.put(M["bronze_s"], G.tube([q, G.add(q, (0, 0, 0.26)), G.add(q, (0.0, 0.12, 0.26))], 0.026, 6))
        lot.put(M["rouge"], G.tour([(0.56, 0.06), (0.58, 0.06)], 10, "z", (q[0], q[1], 0.0)))

    # ======================================================================================== 6. parvis
    zw = 0.3
    rd = G.Rnd(7404)
    yn = K["y0"] + 0.05
    segs = ((-4.9, -2.45, -3.3, zw), (-2.45, 0.8, -3.86, zw + 0.03), (0.8, 3.45, -3.4, zw - 0.02))
    for (dx, dy, R) in RELIQUES:
        socle_rond(lot, M, dx, dy - 0.12, 0.0, R + 0.72, 1, zw + 0.02, rd)
        lot.put(M["bronze_s"], E.cerceau(dx, dy - 0.12, zw + 0.03, R + 0.7, 0.018, 40))
    for (xa, xb, ya, za) in segs:
        dalles(lot, M, xa, xb, ya + 0.08, min(yn, -1.5) if (xa > -2.5 and xb < 1.0) else -1.45, za, rd)
        mur_sud(lot, M, xa, xb, ya, za + 0.03, rd)
        if xa < -0.5 < xb:
            E.garde(lot, {"acier": M["bronze_s"]}, (xa + 0.05, ya, za + 0.04), (-0.68, ya, za + 0.04), 0.3)
            E.garde(lot, {"acier": M["bronze_s"]}, (0.04, ya, za + 0.04), (xb, ya, za + 0.04), 0.3)
            for k in range(3):                                       # marches
                lot.put(M["taille"], G.boite((-0.32, ya - 0.14 - 0.17 * k, za - 0.09 * (k + 1) + 0.03), (0.72 + 0.1 * k, 0.17, 0.09)))
        else:
            E.garde(lot, {"acier": M["bronze_s"]}, (xa + 0.05, ya, za + 0.04), (xb, ya, za + 0.04), 0.3)
    for (x, y, lum) in ((-2.45, -3.82, True), (0.8, -3.82, True), (-4.8, -3.25, False), (3.42, -3.35, False), (-0.78, -3.82, False), (0.14, -3.82, False)):
        _borne(lot, M, x, y, zw, rd, lum)

    rm = G.Rnd(7606)
    petits = [M["bronze_s"], M["noyau"], M["taille"], M["riv"], M["dalle2"]]
    E.menus_sol(lot, petits, rm, -2.4, 0.75, -3.75, -3.0, zw + 0.03, 45)
    E.menus_sol(lot, petits, rm, -4.7, -2.5, -3.2, -1.6, zw, 30)
    E.menus_sol(lot, petits, rm, 1.6, 3.4, -3.3, -1.6, zw, 30)
    E.menus_mur(lot, [M["bronze_s"], M["noyau"], M["bronze"]], rm, K["x0"] + 0.1, -0.9, K["y0"] + 0.13, z0 + 0.1, 0.8, 22)
    E.menus_mur(lot, [M["bronze_s"], M["noyau"], M["bronze"]], rm, 0.3, K["x1"] - 0.1, K["y0"] + 0.2, z0 + 0.1, 0.78, 18)

    # ======================================================================================== 7. tuyauterie, flexibles, câbles
    pv = niv
    x0, x1, y0, y1 = K["x0"], K["x1"], K["y0"], K["y1"]
    C.tuyau(lot, M["bronze"], M["bronze_s"], [(-3.1, -1.55, 1.05), (-2.75, -1.55, 1.05), (-2.75, -2.05, 0.75), (x0 - 0.1, -2.05, 0.75)], 0.1, rb=0.2)
    C.tuyau(lot, M["bronze_s"], M["bronze"], [pv((-3.3, 0.15, 2.15)), pv((-2.65, 0.15, 2.15)), pv((-2.35, -0.45, 2.0)), pv((-2.0, -0.45, 1.6)), pv((-2.0, -0.45, 0.6))], 0.07)
    C.tuyau(lot, M["bronze"], M["bronze_s"], [(-2.5, -3.12, zw + 0.12), (-2.5, -3.62, zw + 0.15), (0.8, -3.62, zw + 0.15), (0.8, -3.2, zw + 0.12), (1.5, -3.2, zw + 0.12)], 0.038, rb=0.12, pas_bride=0.55)
    Rx = RELIQUES
    C.tuyau(lot, M["bronze"], M["bronze_s"], [(Rx[0][0] - 0.25, Rx[0][1] + 0.3, zl[0] + 0.8), (x1 - 0.2, Rx[0][1] + 0.3, zl[0] + 0.8), (x1 - 0.2, -2.3, 0.95)], 0.05, rb=0.14, pas_bride=0.45)
    C.tuyau(lot, M["bronze"], M["bronze_s"], [(Rx[1][0] + 0.2, Rx[1][1] + 0.2, zl[1] + 0.55), (x0 - 0.25, Rx[1][1] + 0.2, zl[1] + 0.55), (x0 - 0.25, -2.15, 0.85)], 0.045, rb=0.12, pas_bride=0.45)
    C.tuyau(lot, M["bronze"], M["bronze_s"], [(-1.2, y1 + 0.05, 1.3), (-1.2, y1 + 0.05, 1.5), (-1.2, gc[1] - 1.45, 1.5), (-1.2, gc[1] - 1.45, Z_PONT + 0.25)], 0.075, rb=0.16, pas_bride=0.5)
    C.tuyau(lot, M["bronze_s"], M["bronze"], [(gx - 0.75, gy - 0.72, 0.62), (gx - 0.75, 1.5, 0.62), (2.7, 1.5, 0.62), (2.7, 1.5, 1.0)], 0.085, rb=0.22)
    C.tuyau(lot, M["bronze_s"], M["bronze"], [(gx - 0.2, gy - gr - 0.02, 0.8), (gx - 0.2, gy - gr - 0.35, 0.8), (gx - 0.2, gy - gr - 0.35, 0.18), (gx - 0.75, gy - gr - 0.35, 0.18)], 0.055, rb=0.12)
    C.tuyau(lot, M["bronze"], M["bronze_s"], [(tw[0] + 0.5, tw[1] - 0.2, 1.5), (tw[0] + 0.95, tw[1] - 0.2, 1.5), (tw[0] + 0.95, tw[1] - 0.2, 0.15)], 0.042, rb=0.1, pas_bride=0.4)
    for (a, b, c) in (((gc[0] - 0.5, gc[1] - 1.42, Z_PONT + 0.25), (gc[0] - 0.9, gc[1] - 1.75, Z_PONT - 0.05), (-1.4, y1 + 0.02, 0.8)),
                      ((gc[0] + 0.9, gc[1] - 1.1, Z_PONT + 0.2), (gc[0] + 1.05, gc[1] - 1.5, 0.3), (0.55, y1 + 0.02, 0.8)),
                      ((-4.55, -1.4, 1.2), (-4.65, -2.05, zw + 0.1), (-4.25, -2.55, zw + 0.25)),
                      ((-3.6, -1.15, 1.15), (-3.9, -1.65, 0.35), (Rx[1][0] - 0.3, Rx[1][1] + 0.5, 0.55)),
                      ((Rx[0][0] - 0.75, Rx[0][1] + 0.35, 0.5), (Rx[0][0] - 0.95, Rx[0][1] + 0.1, 0.32), (x1 + 0.03, -2.0, 0.6)),
                      (pv((2.45, -0.9, 1.2)), (3.1, -1.25, 0.75), (Rx[0][0] + 0.2, Rx[0][1] + 0.85, 0.55)),
                      (P.xf((-0.3, 1.3, 0.25)), pv((-0.25, 1.35, 1.0)), pv((0.1, 1.2, 0.5))),
                      ((gx - 0.95, gy - 0.35, 0.5), (gx - 1.35, gy - 0.6, 0.12), (2.7, 1.5, 0.3))):
        C.flexible(lot, M["caoutchouc"], [a, b, c], 0.048)
    for (x, y, rr_) in ((-5.0, -1.7, 0.2), (1.1, -3.5, 0.16)):      # rouleaux de flexible
        for k in range(3):
            rk = rr_ - 0.032 * k
            lot.put(M["caoutchouc"], G.tube([(x + rk * math.cos(TAU * j / 18), y + rk * math.sin(TAU * j / 18), zw + 0.035 + 0.055 * k) for j in range(19)], 0.028, 6))
    ra = G.Rnd(7505)
    E.cablage(lot, M, P, pieds, ra)
    C.faisceau(lot, M["rouge"], M["noir"], P.xf((-1.4, 0.0, C.z_dessus(-1.4) + 0.3)), (tq[0] + 0.1, tq[1] - 0.1, 1.5), 0.25, 3, 0.011, 0.028, ra)
    C.faisceau(lot, M["rouge"], M["noir"], (gx - 1.0, gy - 0.55, 1.9), P.xf((2.9, 0.4, C.z_dessus(2.9) + 0.6)), 0.35, 3, 0.011, 0.028, ra)
    C.faisceau(lot, M["rouge"], M["noir"], (x1 - 0.1, y0 + 0.4, 1.0), (Rx[0][0] - 0.2, Rx[0][1] + 0.3, zl[0] + 0.9), 0.2, 3, 0.011, 0.028, ra)
    C.faisceau(lot, M["rouge"], M["noir"], (x0 + 0.1, y0 + 0.4, 1.0), (Rx[1][0] + 0.15, Rx[1][1] + 0.2, zl[1] + 0.6), 0.2, 3, 0.011, 0.028, ra)

    # ======================================================================================== 8. mâts et bossoir
    m0 = P.xf((2.9, 0.0, C.z_dessus(2.9) + 0.12))
    lot.put(M["bronze_s"], G.tube([m0, G.add(m0, (0, 0, 1.3))], 0.03, 6))
    for k in range(4):
        a = TAU * k / 4 + 0.4
        lot.put(M["bronze_s"], G.tube([G.add(m0, (0.13 * math.cos(a), 0.13 * math.sin(a), 0.0)), G.add(m0, (0.02 * math.cos(a), 0.02 * math.sin(a), 1.25))], 0.012, 4))
    for z in (0.5, 0.9):
        lot.put(M["bronze_s"], G.tube([G.add(m0, (-0.26, 0, z)), G.add(m0, (0.26, 0, z))], 0.013, 4))
    pose(lot, M, G.add(m0, (0, 0, 1.25)), 0.26, 0.04, rc, 5)
    for x in (-1.75, 1.95):                                          # diapasons sur l'épine : deux branches de bronze
        p = P.xf((x, 0.0, C.z_dessus(x) + 0.25))
        lot.put(M["bronze"], G.tube([p, G.add(p, (0, 0, 0.42))], 0.02, 5))
        for s in (-1, 1):
            lot.put(M["bronze"], G.tube(G.catmull([G.add(p, (0, 0, 0.4)), G.add(p, (s * 0.12, 0, 0.5)), G.add(p, (s * 0.12, 0, 0.92))], 5), 0.016, 5))
    bq = (-5.3, -2.6, zw)
    lot.put(M["bronze_s"], G.tube([bq, G.add(bq, (0, 0, 1.55))], 0.045, 8))
    lot.put(M["bronze_s"], G.tube([G.add(bq, (0, 0, 1.5)), G.add(bq, (0.78, -0.25, 1.7))], 0.03, 6))
    lot.put(M["bronze_s"], G.tube([G.add(bq, (0, 0, 0.85)), G.add(bq, (0.62, -0.2, 1.66))], 0.018, 5))
    hk = G.add(bq, (0.78, -0.25, 1.7))
    lot.put(M["noir"], G.tube([hk, G.add(hk, (0, 0, -0.85))], 0.007, 3))
    pose(lot, M, G.add(hk, (0, 0, -1.1)), 0.26, 0.07, rc, 5)         # un éclat levé au palan

    # ======================================================================================== 9. objets du parvis
    for (x, y, m) in ((-4.75, -2.25, "rapiece2"), (-4.95, -2.0, "patch"), (-4.55, -1.95, "rapiece2"), (1.65, -3.1, "patch"), (-2.05, -3.05, "rapiece2")):
        lot.put(M[m], G.tour([(zw, 0.15), (zw + 0.44, 0.15)], 16, "z", (x, y, 0.0), cap1=True))
        for z in (0.08, 0.36):
            lot.put(M["bronze_s"], G.tour([(zw + z - 0.015, 0.156), (zw + z + 0.015, 0.156)], 16, "z", (x, y, 0.0)))
        lot.put(M["bronze_s"], G.tour([(zw + 0.44, 0.03), (zw + 0.47, 0.03)], 8, "z", (x + 0.07, y, 0.0), cap1=True))
    for (x, y, sz, rz, m) in ((-2.2, -3.25, 0.4, 0.2, "bois"), (-1.6, -3.4, 0.3, -0.35, "bois"), (1.3, -3.08, 0.26, 0.6, "bois"),
                              (0.95, -3.12, 0.34, -0.15, "bois"), (-5.35, -2.2, 0.32, 0.4, "bois")):
        lot.put(M[m], G.boite((x, y, zw + sz / 2), (sz, sz * 0.85, sz), rz))
        lot.put(M["bronze_s"], G.boite((x, y, zw + sz + 0.01), (sz * 1.04, sz * 0.2, 0.02), rz))
        if sz > 0.33:                                                # caisse ouverte d'éclats
            pose(lot, M, (x, y, zw + sz - 0.02), 0.2, 0.05, rc, 5, (0.1, 0.0))
    for (x, y, sz, rz) in ((0.45, -3.5, 0.34, 0.25), (-1.0, -3.55, 0.28, -0.2)):
        lot.put(M["taille"], G.boite((x, y, zw + sz * 0.35), (sz, sz * 0.8, sz * 0.7), rz, 0.0, 0.08))

    # ======================================================================================== 10. sol : butte, cales de pierre, éclats, débris
    E.butte_nez(lot, M, P, r)
    for (x, y) in ((-3.4, -1.2), (-3.6, 1.95), (-4.5, -1.75), (-4.6, 2.0)):      # cales de pierre sous les tuyères
        for k in range(3):
            lot.put(M["taille"], G.boite((x, y, 0.13 + 0.25 * k), (0.92 - 0.12 * k, 0.72 - 0.08 * k, 0.24), -0.1 + 0.08 * k))
        lot.put(M["bronze_s"], G.tour([(0.7, 0.07), (1.05, 0.06)], 8, "z", (x, y, 0.0), cap1=True))
    for k in range(18):
        x, y = ra.f(-5.8, 5.8), ra.f(-4.1, 4.1)
        if abs(y) < 3.0 and abs(x) < 4.5:
            continue
        if ra.f() < 0.5:
            lot.put(M["bronze_s"] if ra.f() < 0.5 else M["jaune1"], G.boite((x, y, 0.02), (ra.f(0.08, 0.2), ra.f(0.05, 0.12), 0.03), ra.f(0, 3.0), ra.f(-0.3, 0.3)))
        else:
            lot.put(M["bronze_s"], G.boite((x, y, 0.03), (ra.f(0.25, 0.45), 0.04, 0.04), ra.f(0, 3.0)))
    for (x, y, h, rr_, pen) in ((5.3, -2.6, 0.62, 0.14, (0.15, -0.1)), (4.95, -2.4, 0.38, 0.09, (-0.2, -0.05)), (5.5, -2.25, 0.3, 0.08, (0.2, 0.1)),
                                (-5.75, -0.9, 0.5, 0.11, (-0.2, 0.0)), (-5.6, -1.2, 0.3, 0.07, (-0.1, -0.2)), (4.3, -3.75, 0.42, 0.1, (0.1, -0.2)),
                                (1.5, 3.95, 0.5, 0.11, (0.05, 0.1)), (1.2, 3.75, 0.28, 0.07, (-0.2, 0.0)), (-2.9, -4.05, 0.32, 0.08, (-0.1, -0.1))):
        pose(lot, M, (x, y, -0.02), h, rr_, rc, 5, pen)
    for (x, y, a, b, h) in ((5.25, -2.5, 0.42, 0.34, 0.08), (-5.7, -1.05, 0.34, 0.42, 0.07), (1.35, 3.85, 0.42, 0.28, 0.07)):
        lot.put(M["taille"], G.butte_polaire((x, y, 0.0), a, b, h, r, 4, 24, 0.5, 0.3))
    for (x, y, sx, sy, sz, rz) in ((-5.75, -1.6, 0.42, 0.34, 0.22, 0.3), (4.7, -3.45, 0.4, 0.3, 0.2, -0.5), (-5.45, 3.4, 0.46, 0.34, 0.24, 0.8),
                                   (5.5, 1.9, 0.36, 0.3, 0.2, 0.2), (2.6, 4.0, 0.42, 0.3, 0.18, 0.4), (-3.55, -4.0, 0.36, 0.26, 0.16, -0.2)):
        lot.put(M["taille"], G.boite((x, y, sz / 2 - 0.02), (sx, sy, sz), rz, 0.1, 0.08))
    for (x, y, rz) in ((5.3, -3.2, 1.4), (-5.8, -3.85, 0.3), (5.55, 2.6, 0.0)):
        lot.put(M["rapiece2"], E.couche(G.tour([(-0.22, 0.14), (0.22, 0.14)], 14, "x", cap0=True, cap1=True), (x, y), rz))
        lot.put(M["bronze_s"], E.couche(G.tour([(-0.13, 0.148), (-0.1, 0.148)], 14, "x"), (x, y), rz))
    for (x, y, a, b, rz) in ((-5.5, -1.95, 0.55, 0.38, 0.4), (4.85, -3.9, 0.5, 0.32, -0.7), (2.75, 4.05, 0.5, 0.3, 0.3)):
        lot.put(M["jaune1"] if a > 0.52 else M["patch"], G.boite((x, y, 0.06), (a, b, 0.03), rz, 0.35, 0.15))
    lot.put(M["bronze"], E.couche(G.tour([(-0.45, 0.1), (0.45, 0.1)], 10, "x", cap0=True, cap1=True), (4.15, -4.0), 0.25, 0.1))
    lot.put(M["caoutchouc"], G.tour([(0.0, 0.17), (0.06, 0.195), (0.12, 0.17)], 16, "z", (-2.4, -4.0, 0.0)))
    return {"pose": E.POSE}
