"""CAPTEUR GÉOTHERMIQUE (fo-geothermal-tap, 3×3, foreuse à sortie de fluide sur fumerolle) : forage incandescent dans
une cave croûtée de soufre, tête de puits à vannes rouges, séparateur cyclone à soufflante (pièce mobile), tuyau
calorifugé alu à lyre de dilatation jusqu'au raccord. Raccord : positions du chevalet vanilla, nord (1, -2), est (2, -1),
sud (-1, 2), ouest (-2, 1) en tuiles (k.dir) ; la planche montre « south ». Variantes : a tête de puits + cyclone,
b cloche de captage, c petit derrick.
"""
import math

import elements as E
import geo as G

D = E.D
TAU = E.TAU
HX, HY = 1.5, 1.5 * D
ZR = 0.22          # axe du tuyau au raccord


def raccord(direction):
    """(point au bord, direction vers l'extérieur) du raccord, en unités Blender."""
    return {"north": ((1.0, HY - 0.03, ZR), (0.0, 1.0)), "south": ((-1.0, -HY + 0.03, ZR), (0.0, -1.0)),
            "east": ((HX - 0.03, 1.0 * D, ZR), (1.0, 0.0)), "west": ((-HX + 0.03, -1.0 * D, ZR), (-1.0, 0.0))}[direction]


def _ligne(k, depart, direction, z=0.42, lyre=0.55, demi=0.3):
    """Tuyau alu calorifugé du départ (x, y, z) au raccord, avec une lyre de dilatation verticale sur le plus long trajet."""
    (ex, ey, ez), (dx, dy) = raccord(direction)
    ax, ay = ex - dx * 0.55, ey - dy * 0.55          # coude avant la sortie
    x0, y0, z0 = depart
    pts = [depart, (x0, y0, z)]
    if abs(ax - x0) >= 0.9:          # lyre sur le trajet est-ouest : dans le plan X-Z, face à la caméra
        m, sg = (x0 + ax) / 2.0, math.copysign(1.0, ax - x0)
        pts += [(x0, ay, z), (m - sg * demi, ay, z), (m - sg * demi, ay, z + lyre), (m + sg * demi, ay, z + lyre), (m + sg * demi, ay, z), (ax, ay, z)]
    else:
        m, sg = (y0 + ay) / 2.0, math.copysign(1.0, ay - y0)
        pts += [(x0, m - sg * demi, z), (x0, m - sg * demi, z + lyre), (x0, m + sg * demi, z + lyre), (x0, m + sg * demi, z), (x0, ay, z), (ax, ay, z)]
    pts += [(ax + dx * 0.2, ay + dy * 0.2, ZR), (ex, ey, ZR)]
    clean = [pts[0]]
    for p in pts[1:]:
        if G.length(G.sub(p, clean[-1])) > 0.04:
            clean.append(p)
    k.tuyau("alu", clean, r=0.075, coude=0.13, brides=[clean[0], (ex - dx * 0.06, ey - dy * 0.06, ZR)], bride_mat="acier", segs=14)
    for i in range(1, len(clean) - 2):
        p = clean[i]
        if p[2] > 0.3 and abs(p[2] - z) < 0.01:
            k.bz("acier", p[0], p[1], 0.0, 0.08, 0.08, z - 0.07)


def _cave(k, x, y, sx, sy, seed):
    """Cave de tête de puits : margelle de béton, fond noir, forage incandescent, caillebotis sans fond, soufre."""
    for (cx, cy, lx, ly) in ((x, y - sy / 2, sx + 0.16, 0.08), (x, y + sy / 2, sx + 0.16, 0.08), (x - sx / 2, y, 0.08, sy), (x + sx / 2, y, 0.08, sy)):
        k.caisson("beton", cx, cy, 0.0, lx, ly, 0.14, 0.02)
    k.b("cendre", (x, y, 0.01), (sx, sy, 0.02))
    k.put("forage", G.butte_polaire((x, y, 0.02), 0.3, 0.3, 0.03, G.Rnd(seed), nr=5, na=24, bosses=0.4, bord=0.25))
    E.croute(k, "soufre", x + 0.2, y - 0.25, 0.22, 0.16, 0.03, seed + 1)
    E.caillebotis(k, x, y + sy * 0.28, 0.13, sx - 0.06, sy * 0.42, 0.07, fond=None)
    for (cx, cy, rx, ry, s) in ((x - sx / 2 - 0.12, y - 0.2, 0.22, 0.3, 3), (x + sx / 2 + 0.1, y - sy / 2 - 0.05, 0.3, 0.18, 4),
                                (x - 0.3, y - sy / 2 - 0.12, 0.25, 0.14, 5)):
        E.croute(k, "soufre", cx, cy, rx, ry, 0.045, seed + s, 0.5)


def _tete(k, x, y, z0=0.02):
    """Tête de puits : bride de tubage, 2 vannes maîtresses à volant rouge (face caméra), croix, aile, chapeau, manomètre."""
    k.cyl("acier", x, y, z0, z0 + 0.1, 0.2, 20)
    k.boulons_rond("riv", x, y, z0 + 0.1, 0.17, 10, 0.014)
    k.cyl("car2", x, y, z0 + 0.1, z0 + 0.22, 0.1, 16)
    z = z0 + 0.22
    for i in range(2):
        k.caisson("rouge", x, y, z, 0.2, 0.17, 0.16, 0.02)
        k.cyl("acier", x, y, z - 0.01, z + 0.01, 0.13, 16)
        k.axe("acier", (x, y - 0.08, z + 0.08), (x, y - 0.2, z + 0.08), 0.018, 6)
        E.roue_xz(k, "rouge", x, y - 0.21, z + 0.08, 0.075, 0.012, 4, moyeu="acier")
        z += 0.2
    k.cyl("acier", x, y, z, z + 0.04, 0.13, 16)
    k.b("car2", (x, y, z + 0.12), (0.2, 0.2, 0.16))
    z += 0.2
    k.cyl("acier", x, y, z, z + 0.12, 0.08, 14)
    k.cyl("acier_clair", x, y, z + 0.12, z + 0.16, 0.1, 14)
    k.axe("noir", (x - 0.05, y - 0.09, z + 0.06), (x - 0.05, y - 0.14, z + 0.06), 0.045, 12)
    k.axe("ceramique", (x - 0.05, y - 0.14, z + 0.06), (x - 0.05, y - 0.15, z + 0.06), 0.035, 12)
    return z - 0.08


def _cyclone(k, x, y, h=1.3, r=0.28):
    for i in range(3):
        a = TAU * i / 3 + 0.3
        k.axe("acier", (x + r * 0.8 * math.cos(a), y + r * 0.8 * math.sin(a), 0.0), (x + r * 0.9 * math.cos(a), y + r * 0.9 * math.sin(a), 0.5), 0.025, 6)
    k.rev("car", x, y, [(0.18, 0.04), (0.5, r), (h, r)], 28)
    k.cerclages("acier", x, y, (0.55, h * 0.75), r, 0.02, 0.02, 28)
    k.rev("car", x, y, [(h, r), (h + 0.06, r * 0.9), (h + 0.06, 0.0)], 28)
    k.cyl("acier", x, y, 0.08, 0.18, 0.05, 10)
    k.ventilo(x, y, h + 0.2, r * 0.82, corps="noir")
    k.plaque("jaune", x, y - r - 0.004, h * 0.62, 0.2, 0.08)


def _vapeur(S, M):
    """Vapeur blanche translucide (visualisation de marche en phase 3 ; ici dans l'état clé)."""
    import bpy
    m = bpy.data.materials.new("c_vapeur")
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (0.82, 0.83, 0.85, 1.0)
    p.inputs["Roughness"].default_value = 1.0
    p.inputs["Alpha"].default_value = 0.32
    m["fo_kind"] = "surface"
    M["vapeur"] = m


def _cristaux(k, x, y, rx, ry, n, seed):
    """Dépôts cristallins de soufre : aiguilles et prismes inclinés, en grappes, autour de la tête de puits."""
    rnd = G.Rnd(seed)
    for i in range(n):
        t = rnd.f(0.0, TAU)
        rho = 0.55 + 0.45 * rnd.f()
        px, py = x + rx * rho * math.cos(t), y + ry * rho * math.sin(t)
        for j in range(rnd.i(2, 4)):
            h = rnd.f(0.12, 0.28)
            E.bipyramide(k, "soufre", px + rnd.f(-0.06, 0.06), py + rnd.f(-0.06, 0.06), 0.02, h, rnd.f(0.03, 0.055), 5, 0.35,
                         rx=rnd.f(-0.5, 0.5), ry=rnd.f(-0.5, 0.5))


def _tete_haute(k, x, y, n=3, R=0.125):
    """Tête de puits d'une tuile de haut : bride de tubage, n vannes à volant rouge de 0,25 tuile face caméra, croix et
    aile, chapeau à manomètre. Rend la hauteur de l'aile."""
    k.cyl("acier", x, y, 0.0, 0.12, 0.24, 24)
    k.boulons_rond("riv", x, y, 0.12, 0.21, 12, 0.016)
    z = 0.12
    k.cyl("car2", x, y, z, z + 0.12, 0.12, 16)
    z += 0.12
    for i in range(n):
        k.caisson("acier_clair", x, y, z, 0.24, 0.2, 0.2, 0.02)
        k.cyl("acier", x, y, z - 0.012, z + 0.012, 0.15, 18)
        k.axe("acier", (x, y - 0.1, z + 0.1), (x, y - 0.24, z + 0.1), 0.02, 6)
        E.roue_xz(k, "rouge", x, y - 0.25, z + 0.1, R, 0.02, 4, moyeu="acier")
        z += 0.24
    k.cyl("acier", x, y, z, z + 0.05, 0.15, 18)
    k.b("car2", (x, y, z + 0.15), (0.24, 0.24, 0.2))
    zw = z + 0.15
    z += 0.25
    k.cyl("acier", x, y, z, z + 0.14, 0.09, 14)
    k.cyl("acier_clair", x, y, z + 0.14, z + 0.19, 0.12, 14)
    k.axe("noir", (x - 0.06, y - 0.1, z + 0.07), (x - 0.06, y - 0.16, z + 0.07), 0.055, 14)
    k.axe("ceramique", (x - 0.06, y - 0.16, z + 0.07), (x - 0.06, y - 0.172, z + 0.07), 0.044, 14)
    return zw


def v_a(S, k):
    """Tête de puits d'une tuile au-dessus d'un forage incandescent, bourrelet de roche, croûte et cristaux de soufre,
    cyclone d'une tuile à soufflante et silencieux qui fume, châssis court, lyre alu (corrections du 3/11)."""
    M = E.matieres(S, k, "elec", "geo")
    E.lueurs(S, M)
    _vapeur(S, M)
    xw, yw = -0.42, 0.0
    # croûte de soufre en relief sur 1,5 tuile (amas bosselés, bords déchiquetés), bourrelet de roche, forage
    k.put("soufre", G.butte_polaire((xw + 0.05, yw - 0.05, 0.0), 0.95, 1.2, 0.05, G.Rnd(17), nr=10, na=48, bosses=0.9, bord=0.45, expo=0.8))
    rnd = G.Rnd(33)
    for i in range(14):
        t = TAU * i / 14 + rnd.f(-0.2, 0.2)
        r = rnd.f(0.62, 1.05)
        k.put("soufre", G.butte_polaire((xw + r * 0.9 * math.cos(t), yw + r * 1.1 * math.sin(t), 0.0), rnd.f(0.12, 0.24), rnd.f(0.1, 0.22),
                                        rnd.f(0.07, 0.15), G.Rnd(60 + i), nr=4, na=14, bosses=0.6, bord=0.35, expo=0.7))
    k.put("cendre", G.butte_polaire((xw, yw, 0.0), 0.62, 0.62, 0.16, G.Rnd(18), nr=8, na=36, bosses=0.6, bord=0.2, expo=0.6))
    rnd = G.Rnd(19)
    for i in range(11):
        t = TAU * i / 11 + rnd.f(-0.15, 0.15)
        r = 0.5 + rnd.f(-0.04, 0.06)
        k.put("roche", G.butte_polaire((xw + r * math.cos(t), yw + r * math.sin(t), 0.0), rnd.f(0.12, 0.18), rnd.f(0.11, 0.17),
                                       rnd.f(0.16, 0.26), G.Rnd(40 + i), nr=4, na=12, bosses=0.4, bord=0.25, expo=0.6))
    k.put("forage", G.butte_polaire((xw, yw, 0.1), 0.36, 0.36, 0.04, G.Rnd(21), nr=5, na=28, bosses=0.4, bord=0.2))
    _cristaux(k, xw, yw, 1.0, 1.2, 22, 23)
    # châssis court : tête de puits et coffret seulement
    k.caisson("car2", xw - 0.62, yw - 0.05, 0.0, 0.55, 0.75, 0.08, 0.02)
    zw = _tete_haute(k, xw, yw, 3)
    k.armoire("car", xw - 0.62, yw - 0.2, 0.08, 0.46, 0.66, 0.24, lampe="voyant_v")
    k.voyant("voyant_o", xw - 0.48, yw - 0.33, 0.66, 0.02)
    k.cable("noir", (xw - 0.45, yw - 0.1, 0.6), (xw - 0.1, yw, zw), 0.05)
    # cyclone d'une tuile, 1,5 tuile de haut, cône de fond, soufflante, silencieux et vapeur
    xc, yc, rc, hc = 0.82, 1.2, 0.45, 1.75
    for i in range(4):
        a = TAU * i / 4 + 0.4
        k.axe("acier", (xc + rc * 0.85 * math.cos(a), yc + rc * 0.85 * math.sin(a), 0.0), (xc + rc * 0.92 * math.cos(a), yc + rc * 0.92 * math.sin(a), 0.62), 0.035, 6)
    k.rev("car", xc, yc, [(0.22, 0.07), (0.62, rc), (hc, rc)], 32)
    k.cerclages("acier", xc, yc, (0.68, 1.15, hc - 0.08), rc, 0.024, 0.03, 32)
    k.rev("car", xc, yc, [(hc, rc), (hc + 0.08, rc * 0.92), (hc + 0.08, 0.0)], 32)
    k.cyl("acier", xc, yc, 0.08, 0.22, 0.07, 12)
    k.plaque("jaune", xc, yc - rc - 0.004, 1.0, 0.3, 0.1)
    k.ventilo(xc + 0.12, yc + 0.08, hc + 0.22, 0.24, corps="noir")
    xsil, ysil = xc - 0.24, yc - 0.18
    k.cyl("acier_clair", xsil, ysil, hc + 0.08, hc + 0.62, 0.12, 18)
    k.cerclages("acier", xsil, ysil, (hc + 0.25, hc + 0.45), 0.12, 0.016, 0.02, 18)
    k.rev("noir", xsil, ysil, [(hc + 0.62, 0.11), (hc + 0.62, 0.0)], 18)
    rnd = G.Rnd(29)
    for i in range(6):
        t = i / 5.0
        k.sph("vapeur", (xsil + 0.22 * t + rnd.f(-0.04, 0.04), ysil + 0.05 * t, hc + 0.75 + 0.75 * t), 0.12 + 0.17 * t, 16, 8)
    # aile vers le cyclone, lyre courte vers le raccord
    k.tuyau("acier", [(xw, yw, zw), (xw + 0.5, yw, zw), (xc - rc, yc - 0.1, 1.1)], r=0.06, coude=0.12, brides=[(xw + 0.14, yw, zw)])
    _ligne(k, (xc + 0.05, yc - rc, 0.9), k.dir, 0.36, lyre=0.32)


def v_b(S, k):
    M = E.matieres(S, k, "elec")
    E.lueurs(S, M)
    xw, yw = -0.3, 0.25
    k.b("cendre", (xw, yw, 0.01), (2.0, 1.9, 0.02))
    k.put("forage", G.butte_polaire((xw, yw, 0.02), 0.45, 0.42, 0.03, G.Rnd(21), nr=5, na=24, bosses=0.4, bord=0.25))
    for (cx, cy, s) in ((xw - 0.8, yw - 0.6, 1), (xw + 0.75, yw - 0.7, 2), (xw - 0.2, yw - 0.9, 3), (xw + 0.9, yw + 0.4, 4)):
        E.croute(k, "soufre", cx, cy, 0.3, 0.2, 0.05, 30 + s, 0.5)
    # cloche de captage sur 6 pieds : la lueur et le soufre se voient dessous
    R = 0.95
    for i in range(6):
        a = TAU * (i + 0.5) / 6
        k.axe("acier", (xw + R * math.cos(a), yw + R * math.sin(a), 0.0), (xw + R * math.cos(a), yw + R * math.sin(a), 0.24), 0.035, 8)
    k.rev("car", xw, yw, [(0.22, R), (0.32, R), (0.62, R * 0.62), (0.95, R * 0.3), (1.05, 0.2)], 36, cap=False)
    k.rev("noyau", xw, yw, [(0.23, R - 0.02), (0.6, R * 0.6), (0.95, 0.2)], 36, cap=False)
    k.tore("acier", xw, yw, 0.24, R, 0.03, 36, 6)
    k.tore("acier", xw, yw, 0.62, R * 0.62, 0.022, 36, 6)
    k.b("chevron", (xw, yw - R * 0.7, 0.48), (0.4, 0.02, 0.08), rx=math.radians(-40))
    k.cyl("car2", xw, yw, 1.05, 1.5, 0.17, 20)
    k.tuyau("car2", [(xw, yw, 1.5), (xw, yw, 1.65), (0.95, yw + 0.45, 1.65), (0.95, yw + 0.45, 1.2)], r=0.12, coude=0.18,
            brides=[(xw, yw, 1.55), (0.95, yw + 0.45, 1.3)], bride_mat="acier")
    # soufflante sur caisson, au nord-est
    k.caisson("car2", 0.95, 0.75, 0.0, 0.62, 0.95, 1.1, 0.03)
    k.persiennes("acier", 0.95, 0.275, 0.12, 0.5, 0.5, 6)
    k.ventilo(0.95, 1.0, 1.2, 0.2, corps="noir")
    _ligne(k, (0.95, 0.26, 0.75), k.dir)
    k.armoire("car2", -1.1, 1.6, 0.0, 0.36, 0.55, 0.16, lampe="voyant_v")


def v_c(S, k):
    M = E.matieres(S, k, "elec")
    E.lueurs(S, M)
    xw, yw = 0.0, 0.3
    _cave(k, xw, yw, 1.0, 1.15, 41)
    zt = _tete(k, xw, yw)
    # derrick : 4 jambes en treillis, moufle fixe, moufle mobile et crochet, feu rouge
    H = 2.75
    feet = [(xw + sx * 0.95, yw + sy * 0.95 * 1.05) for sx in (-1, 1) for sy in (-1, 1)]
    top = [(xw + sx * 0.18, yw + sy * 0.2) for sx in (-1, 1) for sy in (-1, 1)]
    for f, t in zip(feet, top):
        k.axe("rouge", (f[0], f[1], 0.0), (t[0], t[1], H), 0.035, 8)
        k.bz("beton", f[0], f[1], 0.0, 0.18, 0.18, 0.06)
    for i in range(5):
        u0, u1 = i / 5.0, (i + 1) / 5.0
        P = [G.lerp((f[0], f[1], 0.0), (t[0], t[1], H), u0) for f, t in zip(feet, top)]
        Q = [G.lerp((f[0], f[1], 0.0), (t[0], t[1], H), u1) for f, t in zip(feet, top)]
        for (a, b) in ((0, 2), (1, 3), (0, 1), (2, 3)):
            k.axe("rouge", P[a], Q[b], 0.012, 4)
            k.axe("rouge", Q[a], Q[b], 0.014, 4)
    k.caisson("car2", xw, yw, H, 0.5, 0.5, 0.14, 0.02)
    E.roue_xz(k, "acier_clair", xw, yw - 0.05, H + 0.24, 0.16, 0.015, 6)
    k.voyant_h("voyant_r", xw + 0.2, yw - 0.2, H + 0.14, 0.03)
    for dx in (-0.06, 0.06):
        k.axe("acier", (xw + dx, yw - 0.05, H + 0.1), (xw + dx, yw - 0.05, 1.75), 0.008, 4)
    k.caisson("jaune", xw, yw - 0.05, 1.5, 0.18, 0.14, 0.26, 0.02)
    k.axe("acier", (xw, yw - 0.05, 1.5), (xw, yw - 0.05, 1.32), 0.02, 6)
    k.tore("acier", xw, yw - 0.05, 1.3, 0.05, 0.014, 12, 5)
    # séparateur plus petit à l'est, raccord
    xc, yc = 1.25, 0.3
    _cyclone(k, xc, yc, 1.0, 0.22)
    k.tuyau("acier", [(xw, yw, zt), (xw + 0.5, yw, zt), (xc, yc + 0.22, 0.75)], r=0.05, coude=0.12, brides=[(xw + 0.12, yw, zt)])
    _ligne(k, (xc - 0.22, yc, 0.7), k.dir, 0.4)
    k.armoire("car2", -1.08, 1.5, 0.0, 0.36, 0.55, 0.16, lampe="voyant_v")
