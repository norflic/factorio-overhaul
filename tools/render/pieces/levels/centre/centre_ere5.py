"""Ère V stellaire (époques 13 à 15) : anneaux lumineux, ailes, couronnes, base flottante ; vide maximal
(V ≥ 17 à 25 % du masque du niveau 1 ; bible §1.2, §4, §5 ; Q8)."""
import math

from centre_ere2 import _ogive, _panel_xz
from centre_ere4 import _dish

R2 = 2.0 ** 0.5


# ----------------------------------------------------------------------------------------------------------
# Époque 13 · Citadelle-réacteur : sphère de confinement sur trépied ; tore de plasma horizontal autour ;
# flèche ; bunker de commande au sud (porte) ; plasma qui tourne (script, phase 2).
# ----------------------------------------------------------------------------------------------------------
def build_e13(k):
    cera = k.matte("ceramique", "#D9D6CF", rough=0.4, grain=0.07, dirt=0.5)
    cuivre = k.metal("cuivre", "#B0703A", rough=0.3, metallic=0.9, grain=0.1, rust="#4A6A58", rust_amount=0.12, dirt=0.35)
    acier = k.metal("acier", "#7A7E84", rough=0.35, metallic=0.8, grain=0.08, dirt=0.4)
    sombre = k.metal("sombre", "#2E3036", rough=0.5, metallic=0.5, dirt=0.3)
    plasma = k.emit("plasma", "#FF4FD8", strength=2.2)
    coeur = k.emit("coeur", "#FF9A3A", strength=1.7)

    sty, sz, R = -0.35, 4.65, 1.5
    # --- bunker de commande (porte au sud) ---
    bk = k.box(-0.75, 0.75, 0.45, 1.4, 0.0, 0.62, cera, "bunker", bevel=0)
    if bk is not None:
        k.S.bevel(bk, 0.1, segments=3)
    k.box(-0.26, 0.26, 1.37, 1.43, 0.0, 0.5, sombre, "porte", bevel=0.008)
    k.box(-0.3, 0.3, 1.38, 1.44, 0.5, 0.56, coeur, "porte_feu", bevel=0)
    for s in (-1, 1):
        k.box(s * 0.52 - 0.08, s * 0.52 + 0.08, 1.38, 1.43, 0.22, 0.4, coeur, "hublot_%d" % s, bevel=0)

    # --- trépied (3 pieds inclinés) et anneau de soutien ---
    k.torus(0.0, sty, sz - 1.05, 1.05, 0.09, cuivre, "anneau_soutien", minor_seg=14)
    cx, cy, _ = k.P(0.0, sty, 0)
    for i, (fx, fty) in enumerate(((-1.5, 1.25), (1.5, 1.25), (0.0, -1.68))):
        a = math.atan2(k.P(fx, fty)[1] - cy, k.P(fx, fty)[0] - cx)
        top = (cx + 1.05 * math.cos(a), cy + 1.05 * math.sin(a), sz - 1.05)
        foot = k.P(fx, fty, 0.08)
        k.cyl(fx, fty, 0.2, 0.0, 0.1, sombre, "patin_%d" % i, verts=24)
        k.rod(foot, top, 0.11, cera, "pied_%d" % i, verts=16)
        mid = tuple(foot[q] * 0.5 + top[q] * 0.5 for q in range(3))
        k.rod((mid[0], mid[1], mid[2] - 0.15), (mid[0], mid[1], mid[2] + 0.15), 0.14, cuivre, "pied_genou_%d" % i, verts=16)
    # conduit de plasma du bunker à la sphère
    k.rod(k.P(0.0, 0.75, 0.6), k.P(0.0, sty, sz - R + 0.05), 0.085, cuivre, "conduit_plasma", verts=16)

    # --- sphère de confinement ---
    k.sphere(0.0, sty, sz, R, cera, "sphere", seg=64, rings=32)
    for i, lat in enumerate((-0.42, 0.42)):
        k.torus(0.0, sty, sz + R * math.sin(lat), R * math.cos(lat) + 0.005, 0.03, cuivre, "sphere_bande_%d" % i, minor_seg=10)
    k.torus(0.0, sty, sz, R + 0.004, 0.02, acier, "sphere_couture", minor_seg=8)
    k.hcyl("y", sty + R / R2 * 0.92, sty + R / R2 * 0.92 + 0.04, 0.0, 0, sz - 0.35, 0.22, coeur, "sphere_hublot", verts=32,
           bevel=0)

    # --- tore de plasma horizontal et ses pinces ---
    k.torus(0.0, sty, sz, 1.78, 0.13, plasma, "tore_plasma", minor_seg=16, major_seg=96)
    for i in range(8):
        a = 2 * math.pi * (i + 0.5) / 8
        p0 = (cx + (R - 0.05) * math.cos(a), cy + (R - 0.05) * math.sin(a), sz)
        p1 = (cx + 1.62 * math.cos(a), cy + 1.62 * math.sin(a), sz)
        k.rod(p0, p1, 0.035, acier, "pince_%d" % i, verts=8, role="tige")

    # --- flèche (tige, point le plus haut) ---
    k.cyl(0.0, sty, 0.12, sz + R - 0.05, sz + R + 0.35, cuivre, "fleche_embase", verts=20)
    k.cyl(0.0, sty, 0.05, sz + R + 0.35, 7.45, cera, "fleche", verts=12, r2=0.008, bevel=0, role="tige")


# ----------------------------------------------------------------------------------------------------------
# Époque 14 · Spatioport de commandement : tour ; 2 ailes de panneaux dorés dépliées (L jusqu'à 3,86) ;
# grande parabole ; mât-balise (tige) ; balises rouges (clignotement par script en phase 2).
# ----------------------------------------------------------------------------------------------------------
def build_e14(k):
    or_ = k.metal("feuille_or", "#C9A23A", rough=0.38, metallic=0.95, grain=0.35, grain_scale=90.0, dirt=0.3)
    blanc = k.metal("blanc", "#CFCBC2", rough=0.4, metallic=0.25, grain=0.06, dirt=0.5)
    cell = k.metal("cellules", "#1E2A55", rough=0.18, metallic=0.6, grain=0.05, dirt=0.15, gain=1.0)
    sombre = k.metal("sombre", "#30333A", rough=0.5, metallic=0.5, dirt=0.3)
    gris = k.matte("aire", "#5A5C60", rough=0.85, grain=0.15)
    rouge = k.emit("balise", "#FF2A2A", strength=2.0)
    bleu = k.emit("bleu", "#2F6BFF", strength=1.3)

    tty = -0.5
    # --- aire d'envol (couche plate) ---
    k.ngon(0.0, 0.0, 1.75, 16, 0.0, 0.05, gris, "aire", sy=1.3, bevel=0, role="flat")
    k.ngon(0.0, 0.0, 1.55, 16, 0.05, 0.06, or_, "aire_cercle", sy=1.3, bevel=0, role="flat")
    # --- hangar (porte au sud) ---
    hg = k.box(-0.85, 0.85, 0.35, 1.45, 0.0, 0.66, blanc, "hangar", bevel=0)
    if hg is not None:
        k.S.bevel(hg, 0.06, segments=3)
    k.box(-0.32, 0.32, 1.43, 1.48, 0.0, 0.52, sombre, "porte", bevel=0.006)
    k.box(-0.36, 0.36, 1.44, 1.49, 0.52, 0.58, bleu, "porte_feu", bevel=0)
    # --- tour ---
    k.prism([(-0.4, tty - 0.4), (0.4, tty - 0.4), (0.4, tty + 0.4), (-0.4, tty + 0.4)], 0.0, 6.45, blanc, "tour",
            top_poly_game=[(-0.3, tty - 0.3), (0.3, tty - 0.3), (0.3, tty + 0.3), (-0.3, tty + 0.3)], bevel=0.012)
    for i, z in enumerate((1.0, 2.2, 3.1, 5.6)):
        w = 0.4 - 0.1 * z / 6.45 + 0.015
        k.prism([(-w, tty - w), (w, tty - w), (w, tty + w), (-w, tty + w)], z, z + 0.12, or_, "tour_bague_%d" % i, bevel=0.004)
    for i, z in enumerate((1.5, 2.6, 4.9)):
        w = 0.4 - 0.1 * z / 6.45
        k.box(-0.12, 0.12, tty + w, tty + w + 0.02, z, z + 0.22, bleu, "tour_hublot_%d" % i, bevel=0)

    # --- 2 ailes de panneaux dorés dépliées ---
    for s in (-1, 1):
        k.box(s * 0.3, s * 1.9, tty - 0.04, tty + 0.04, 4.05, 4.15, or_, "aile_poutre_%d" % s, bevel=0.004)
        k.rod(k.P(s * 0.3, tty, 3.0), k.P(s * 1.5, tty, 4.06), 0.035, blanc, "aile_hauban_%d" % s, verts=10, role="tige")
        for row, (z0, z1) in enumerate(((3.38, 4.0), (4.2, 4.82))):
            for j in range(3):
                x0 = 0.45 + j * 0.495
                xa, xb = (x0, x0 + 0.46) if s > 0 else (-x0 - 0.46, -x0)
                tilt = 0.18
                fr = [k.P(xa, tty + 0.02, z0), k.P(xb, tty + 0.02, z0), k.P(xb, tty - tilt, z1), k.P(xa, tty - tilt, z1)]
                bk = [(p[0], p[1] + 0.05, p[2] + 0.0) for p in fr]
                k.loft([fr, bk], or_, "panneau_%d_%d_%d" % (s, row, j), bevel=0.004)
                inset = [k.P(xa + 0.03, tty + 0.025, z0 + 0.03), k.P(xb - 0.03, tty + 0.025, z0 + 0.03),
                         k.P(xb - 0.03, tty - tilt + 0.005, z1 - 0.03), k.P(xa + 0.03, tty - tilt + 0.005, z1 - 0.03)]
                face = [(p[0], p[1] - 0.012, p[2] + 0.004) for p in inset]
                k.loft([inset, face], cell, "cellules_%d_%d_%d" % (s, row, j), bevel=0)
        k.sphere(s * 1.85, tty, 3.9, 0.07, rouge, "balise_aile_%d" % s, seg=16, rings=8)

    # --- grande parabole sur la face avant de la tour ---
    k.rod(k.P(0.0, tty + 0.3, 4.95), k.P(0.0, tty + 0.62, 5.05), 0.06, blanc, "parabole_bras", verts=12)
    _dish(k, 0.0, tty + 0.62, 4.95, 0.72, 0.26, math.radians(55), math.radians(-90), blanc, "parabole")
    k.rod(k.P(0.0, tty + 0.62, 5.0), k.P(0.0, tty + 1.0, 5.45), 0.02, sombre, "parabole_source", role="tige")

    # --- mât-balise (tige, point le plus haut) ---
    k.cyl(0.0, tty, 0.035, 6.45, 7.2, sombre, "mat_balise", verts=10, bevel=0, role="tige")
    k.sphere(0.0, tty, 7.25, 0.08, rouge, "balise_sommet", seg=16, rings=8, role="tige")


# ----------------------------------------------------------------------------------------------------------
# Époque 15 · Palais : couronne de 5 flèches en or blanc ; anneau-halo ; base flottante (vide sous la
# couronne) ; donjon de nacre à porte au sud ; grande flèche centrale (mât) ; particules en phase 2.
# ----------------------------------------------------------------------------------------------------------
def build_e15(k):
    orb = k.metal("or_blanc", "#E8DCB0", rough=0.28, metallic=0.9, grain=0.08, dirt=0.45, gain=0.95)
    nacre = k.matte("nacre", "#D8D2C8", rough=0.3, grain=0.06, dirt=0.45)
    sombre = k.metal("sombre", "#4A463E", rough=0.4, metallic=0.6, dirt=0.3)
    lum = k.emit("lumiere", "#FFF2C0", strength=1.9)
    lum_d = k.emit("lumiere_douce", "#FFF2C0", strength=1.1)

    bty = -0.1
    # --- émetteur au sol (couche plate) et marches flottantes ---
    k.ngon(0.0, bty, 1.15, 24, 0.0, 0.03, lum_d, "emetteur_sol", sy=1.0, bevel=0, role="flat")
    k.ngon(0.0, bty, 1.25, 24, 0.0, 0.025, sombre, "emetteur_bord", sy=1.0, bevel=0, role="flat")
    for i, (ty, z) in enumerate(((1.62, 0.22), (1.38, 0.5), (1.14, 0.78))):
        k.cyl(0.0, ty, 0.24, z, z + 0.07, orb, "marche_flottante_%d" % i, verts=32)
        k.cyl(0.0, ty, 0.2, z - 0.015, z, lum, "marche_lueur_%d" % i, verts=32, bevel=0)

    # --- base flottante (soucoupe) ---
    k.lathe(0.0, bty, [(0.0, 0.72), (0.3, 0.78), (0.8, 0.98), (1.3, 1.18), (1.64, 1.32), (1.72, 1.43), (1.68, 1.55),
                        (0.0, 1.56)], nacre, "base_flottante", segs=72)
    k.torus(0.0, bty, 1.43, 1.72, 0.04, orb, "base_bourrelet", minor_seg=10, major_seg=96)
    k.sphere(0.0, bty, 0.72, 0.13, lum, "base_emetteur", seg=24, rings=12)

    # --- donjon de nacre (porte en ogive au sud) ---
    kty = -0.15
    k.lathe(0.0, kty, [(0.8, 1.55), (0.82, 1.95), (0.74, 2.3), (0.86, 2.42), (0.86, 2.56), (0.62, 2.68), (0.0, 2.74)], nacre,
            "donjon", segs=64)
    k.torus(0.0, kty, 2.42, 0.87, 0.035, orb, "donjon_corniche", minor_seg=10)
    ty_d = kty + 0.81 / R2
    _panel_xz(k, [(x, z + 1.56) for x, z in _ogive(0.24, 0.3, 0.58)], ty_d - 0.02, ty_d + 0.02, orb, "porte_cadre")
    _panel_xz(k, [(x, z + 1.58) for x, z in _ogive(0.18, 0.28, 0.5)], ty_d + 0.01, ty_d + 0.035, lum, "porte_lumiere")

    # --- couronne de 5 flèches en or blanc ---
    cx, cy, _ = k.P(0.0, bty, 0)
    for i, (ang, ztip, rb) in enumerate(((90, 6.6, 0.25), (18, 5.0, 0.21), (162, 5.0, 0.21), (306, 3.65, 0.19), (234, 3.65, 0.19))):
        a = math.radians(ang)
        x, y = cx + 1.18 * math.cos(a), cy + 1.18 * math.sin(a)
        tx, ty = x, -y / R2
        k.ngon(tx, ty, rb, 8, 1.5, ztip, orb, "fleche_%d" % i, r_top=0.0, rot=math.pi / 8, bevel=0.006)
        zc = 1.5 + (ztip - 1.5) * 0.3
        k.ngon(tx, ty, rb * 0.95, 8, zc, zc + 0.12, nacre, "fleche_collier_%d" % i, rot=math.pi / 8, bevel=0.004)
        k.sphere(tx, ty, zc + 0.24, rb * 0.62, lum_d, "fleche_orbe_%d" % i, seg=20, rings=10)

    # --- anneau-halo ---
    k.torus(0.0, bty, 4.4, 1.32, 0.055, lum, "anneau_halo", minor_seg=12, major_seg=96)
    k.torus(0.0, bty, 4.29, 1.32, 0.03, orb, "anneau_or", minor_seg=10, major_seg=96)

    # --- grande flèche centrale (mât : tige, point le plus haut) ---
    k.cyl(0.0, kty, 0.11, 2.72, 3.4, orb, "fleche_centrale_embase", verts=16)
    k.cyl(0.0, kty, 0.06, 3.4, 8.0, orb, "fleche_centrale", verts=12, r2=0.006, bevel=0, role="tige")
    for z in (4.0, 5.2):
        k.torus(0.0, kty, z, 0.1, 0.02, lum, "fleche_centrale_anneau_%d" % int(z), minor_seg=8, role="tige")
