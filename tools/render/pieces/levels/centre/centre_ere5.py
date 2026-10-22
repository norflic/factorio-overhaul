"""Ère V stellaire (époques 13 à 15) : anneaux lumineux, ailes, couronnes, base flottante ; vide maximal
(V >= 17 à 25 % du masque du niveau 1 ; bible §1.2, §4, §5 ; Q8).

Correction V3 du 22/10 (vérification adverse, problèmes majeurs 5 et 6, mineur 6) : le centre ne dominait plus
(aire de silhouette 9,2 à 10,3 t² aux époques 12, 14 et 15, autant que la cabane du niveau 1). La masse est
ajoutée EN HAUTEUR (au-dessus de v = -2,5, hors du masque du niveau 1 : sans coût sur D1-3) :
  - époque 13 : injecteurs et bobines autour du tore, ceinture équatoriale, trépied renforcé, bunker élargi ;
    dalle au sol (couche plate, exclue de D1-3) qui signale l'emprise ;
  - époque 14 : 3 rangs de panneaux par aile, tour élargie, réservoirs sphériques dorés, grande parabole ;
  - époque 15 : soucoupe et donjon plus massifs, COURONNE lisible (5 flèches à des x distincts, étagées,
    nettement au-dessus de l'anneau-halo, aucune dans l'axe d'une autre), marches flottantes supprimées.
"""
import math

from centre_ere2 import _ogive, _panel_xz
from centre_ere4 import _dish

R2 = 2.0 ** 0.5


# ----------------------------------------------------------------------------------------------------------
# Époque 13 · Citadelle-réacteur : sphère de confinement sur trépied ; tore de plasma horizontal autour ;
# flèche ; bunker de commande au sud (porte) ; plasma qui tourne (script, phase 2).
# ----------------------------------------------------------------------------------------------------------
def build_e13(k):
    cera = k.matte("ceramique", "#D9D6CF", rough=0.36, grain=0.26, dirt=0.55)
    cuivre = k.metal("cuivre", "#B0703A", rough=0.26, metallic=0.9, rust="#4A6A58", rust_amount=0.16, dirt=0.4)
    acier = k.metal("acier", "#7A7E84", rough=0.3, metallic=0.8, dirt=0.5)
    sombre = k.metal("sombre", "#2E3036", rough=0.45, metallic=0.5)
    vis = k.metal("vis", "#B0B4BA", rough=0.2, metallic=0.95, clean=True)
    beton = k.matte("dalle", "#5E5C58", rough=0.85, grain=0.3, grain_scale=30.0)
    plasma = k.emit("plasma", "#FF4FD8", strength=1.0)
    coeur = k.emit("coeur", "#FF9A3A", strength=1.0)

    sty, sz, R = -0.35, 4.62, 1.54
    # --- dalle au sol (couche plate : exclue du masque D1-3), qui signale l'emprise ---
    k.ngon(0.0, 0.0, 1.86, 8, 0.0, 0.05, beton, "dalle", rot=math.pi / 8, sy=1.31, bevel=0.004, role="flat")
    k.ngon(0.0, 0.0, 1.88, 8, 0.0, 0.02, acier, "dalle_bord", rot=math.pi / 8, sy=1.31, bevel=0, role="flat")
    k.ngon(0.0, -0.35, 1.2, 24, 0.05, 0.06, sombre, "dalle_cercle", sy=1.0, bevel=0, role="flat")
    # --- bunker de commande (porte au sud), élargi ---
    bk = k.box(-0.95, 0.95, 0.42, 1.42, 0.0, 0.66, cera, "bunker", bevel=0)
    if bk is not None:
        k.S.bevel(bk, 0.1, segments=3)
    k.panels(-0.85, 0.85, 0.52, 1.30, 0.0, 0.66, cera, "bunker_plaques", top=(4, 2), south=None, gap=0.03, thick=0.014)
    k.box(-0.28, 0.28, 1.38, 1.45, 0.0, 0.52, sombre, "porte", bevel=0.008)
    k.box(-0.012, 0.012, 1.45, 1.46, 0.02, 0.5, acier, "porte_joint", bevel=0)
    k.box(-0.32, 0.32, 1.39, 1.46, 0.52, 0.58, coeur, "porte_feu", bevel=0)
    for s in (-1, 1):
        k.box(s * 0.62 - 0.1, s * 0.62 + 0.1, 1.39, 1.45, 0.22, 0.42, coeur, "hublot_%d" % s, bevel=0)
        k.louvres(s * 0.62 - 0.12, s * 0.62 + 0.12, 1.43, 0.06, 0.17, 3, acier, "bunker_grille_%d" % s, depth=0.015)

    # --- trépied (3 pieds inclinés renforcés) et anneau de soutien ---
    k.torus(0.0, sty, sz - 1.08, 1.08, 0.1, cuivre, "anneau_soutien", minor_seg=14)
    k.ring_studs(0.0, sty, 1.19, sz - 1.08, 18, 0.022, vis, "anneau_soutien_boulons")
    cx, cy, _ = k.P(0.0, sty, 0)
    for i, (fx, fty) in enumerate(((-1.5, 1.25), (1.5, 1.25), (0.0, -1.68))):
        a = math.atan2(k.P(fx, fty)[1] - cy, k.P(fx, fty)[0] - cx)
        top = (cx + 1.08 * math.cos(a), cy + 1.08 * math.sin(a), sz - 1.08)
        foot = k.P(fx, fty, 0.08)
        k.cyl(fx, fty, 0.22, 0.0, 0.12, sombre, "patin_%d" % i, verts=24)
        k.rod(foot, top, 0.14, cera, "pied_%d" % i, verts=16)
        for t in (0.15, 0.3, 0.5, 0.7, 0.86):
            p = tuple(foot[q] * (1 - t) + top[q] * t for q in range(3))
            k.rod((p[0], p[1], p[2] - 0.12), (p[0], p[1], p[2] + 0.12), 0.165, cuivre, "pied_bague_%d_%d" % (i, int(t * 10)),
                  verts=16)
    # conduit de plasma du bunker à la sphère
    k.rod(k.P(0.0, 0.75, 0.62), k.P(0.0, sty, sz - R + 0.05), 0.09, cuivre, "conduit_plasma", verts=16)

    # --- sphère de confinement : ceinture équatoriale, coutures, hublot ---
    k.sphere(0.0, sty, sz, R, cera, "sphere", seg=64, rings=32)
    k.sphere_seams(0.0, sty, sz, R, acier, "sphere_coutures", lats=(-0.75, -0.4, 0.4, 0.75), mers=8, minor=0.012)
    k.sphere_tiles(0.0, sty, sz, R, cera, "sphere_tuiles", lat0=-0.25, lat1=1.25, nlat=8, lon0=math.pi * 0.9,
                   lon1=math.pi * 2.1, nlon=24, thick=0.024, gap=0.16)
    k.torus(0.0, sty, sz, R + 0.03, 0.09, cuivre, "sphere_ceinture", minor_seg=12)
    tp = []
    for j in range(20):
        a = math.pi + math.pi * (j + 0.5) / 20
        tp.append(((cx + (R + 0.11) * math.cos(a), cy + (R + 0.11) * math.sin(a), sz), (math.cos(a), math.sin(a), 0.0)))
    k.studs(tp, 0.024, vis, "ceinture_boulons")
    k.hcyl("y", sty + R / R2 * 0.92, sty + R / R2 * 0.92 + 0.04, 0.0, 0, sz - 0.45, 0.24, coeur, "sphere_hublot", verts=32,
           bevel=0)
    k.torus(0.0, sty + R / R2 * 0.92 + 0.03, sz - 0.45, 0.26, 0.03, acier, "sphere_hublot_cadre", rot=(math.pi / 2, 0, 0),
            minor_seg=8)

    # --- tore de plasma horizontal, ses pinces, injecteurs et bobines ---
    k.torus(0.0, sty, sz, 1.80, 0.12, plasma, "tore_plasma", minor_seg=16, major_seg=96)
    for i in range(8):
        a = 2 * math.pi * (i + 0.5) / 8
        p0 = (cx + (R + 0.05) * math.cos(a), cy + (R + 0.05) * math.sin(a), sz)
        p1 = (cx + 1.66 * math.cos(a), cy + 1.66 * math.sin(a), sz)
        k.rod(p0, p1, 0.04, acier, "pince_%d" % i, verts=8)
    # 6 injecteurs (kit de l'époque) sous l'équateur, tournés vers le sud et les côtés : rien ne dépasse le haut
    # de la sphère (première passe du 22/10 : injecteurs sur le haut, O 3,66 pour une cible de 3,14)
    for i, ang in enumerate((200, 235, 270, 305, 340, 160)):
        a = math.radians(ang)
        lat = math.radians(-12)
        px, py = cx + R * math.cos(lat) * math.cos(a), cy + R * math.cos(lat) * math.sin(a)
        pz = sz + R * math.sin(lat)
        nrm = (math.cos(lat) * math.cos(a), math.cos(lat) * math.sin(a), math.sin(lat))
        k.rod((px, py, pz), (px + 0.42 * nrm[0], py + 0.42 * nrm[1], pz + 0.42 * nrm[2]), 0.11, acier, "injecteur_%d" % i,
              verts=16)
        k.rod((px + 0.42 * nrm[0], py + 0.42 * nrm[1], pz + 0.42 * nrm[2]),
              (px + 0.52 * nrm[0], py + 0.52 * nrm[1], pz + 0.52 * nrm[2]), 0.075, cuivre, "injecteur_buse_%d" % i, verts=12)
    # 4 bobines de confinement (blocs) qui tiennent le tore
    for i in range(4):
        a = 2 * math.pi * i / 4 + math.pi / 4
        x, y = cx + 1.80 * math.cos(a), cy + 1.80 * math.sin(a)
        k.bbox(x, -y / R2, sz, 0.32, 0.32, 0.42, sombre, "bobine_%d" % i, rot=(0.0, 0.0, a), bevel=0.03)
        k.bbox(x, -y / R2, sz + 0.215, 0.24, 0.24, 0.02, cuivre, "bobine_chapeau_%d" % i, rot=(0.0, 0.0, a), bevel=0)

    # --- flèche (tige, point le plus haut) ---
    k.cyl(0.0, sty, 0.14, sz + R - 0.05, sz + R + 0.35, cuivre, "fleche_embase", verts=20)
    k.cyl(0.0, sty, 0.05, sz + R + 0.35, 7.45, cera, "fleche", verts=12, r2=0.008, bevel=0, role="tige")


# ----------------------------------------------------------------------------------------------------------
# Époque 14 · Spatioport de commandement : tour ; 2 ailes de panneaux dorés dépliées (L jusqu'à 3,86) ;
# grande parabole ; réservoirs sphériques dorés ; mât-balise (tige) ; balises rouges (clignotement par script).
# ----------------------------------------------------------------------------------------------------------
def build_e14(k):
    or_ = k.metal("feuille_or", "#C9A23A", rough=0.34, metallic=0.95, grain=0.38, grain_scale=90.0, dirt=0.5, bump=0.5)
    blanc = k.metal("blanc", "#CFCBC2", rough=0.34, metallic=0.3, dirt=0.55)
    cell = k.metal("cellules", "#1E2A55", rough=0.16, metallic=0.6, clean=True, gain=1.0)
    sombre = k.metal("sombre", "#30333A", rough=0.45, metallic=0.5)
    vis = k.metal("vis", "#B8BCC2", rough=0.2, metallic=0.95, clean=True)
    gris = k.matte("aire", "#5A5C60", rough=0.85, grain=0.26)
    rouge = k.emit("balise", "#FF2A2A", strength=1.0)
    bleu = k.emit("bleu", "#2F6BFF", strength=1.0)

    tty = -0.5
    # --- aire d'envol (couche plate) ---
    k.ngon(0.0, 0.0, 1.75, 16, 0.0, 0.05, gris, "aire", sy=1.3, bevel=0, role="flat")
    k.ngon(0.0, 0.0, 1.55, 16, 0.05, 0.06, or_, "aire_cercle", sy=1.3, bevel=0, role="flat")
    # --- hangar (porte au sud), élargi ---
    hg = k.box(-1.0, 1.0, 0.3, 1.45, 0.0, 0.72, blanc, "hangar", bevel=0)
    if hg is not None:
        k.S.bevel(hg, 0.06, segments=3)
    k.panels(-0.95, 0.95, 0.35, 1.40, 0.0, 0.72, blanc, "hangar_plaques", top=(4, 2), south=(6, 2), gap=0.03, thick=0.014,
             skip=lambda f, xa, xb, a, b: f == "south" and xb > -0.4 and xa < 0.4)
    k.box(-0.34, 0.34, 1.43, 1.48, 0.0, 0.56, sombre, "porte", bevel=0.006)
    for z in (0.12, 0.24, 0.36, 0.48):
        k.box(-0.34, 0.34, 1.48, 1.49, z - 0.006, z + 0.006, blanc, "porte_lame_%d" % int(z * 100), bevel=0)
    k.box(-0.38, 0.38, 1.44, 1.49, 0.56, 0.62, bleu, "porte_feu", bevel=0)
    # --- 2 réservoirs sphériques dorés sur pieds, de part et d'autre du hangar ---
    for s in (-1, 1):
        x, ty = s * 1.42, 0.95
        for a in (0.0, 2.1, 4.2):
            px, py, _ = k.P(x, ty, 0)
            k.rod((px + 0.22 * math.cos(a), py + 0.22 * math.sin(a), 0.0), (px + 0.12 * math.cos(a), py + 0.12 * math.sin(a), 0.4),
                  0.025, sombre, "reservoir_pied_%d_%d" % (s, int(a * 10)), verts=8)
        k.sphere(x, ty, 0.68, 0.34, or_, "reservoir_%d" % s, seg=40, rings=20)
        k.torus(x, ty, 0.68, 0.345, 0.02, blanc, "reservoir_ceinture_%d" % s, minor_seg=8)
    # --- tour élargie ---
    w0, w1 = 0.55, 0.36
    k.prism([(-w0, tty - w0), (w0, tty - w0), (w0, tty + w0), (-w0, tty + w0)], 0.0, 6.45, blanc, "tour",
            top_poly_game=[(-w1, tty - w1), (w1, tty - w1), (w1, tty + w1), (-w1, tty + w1)], bevel=0.012)
    for i, z in enumerate((0.9, 1.9, 2.8, 5.4, 6.0)):
        w = w0 + (w1 - w0) * z / 6.45 + 0.015
        k.prism([(-w, tty - w), (w, tty - w), (w, tty + w), (-w, tty + w)], z, z + 0.12, or_, "tour_bague_%d" % i, bevel=0.004)
    for i, z in enumerate((1.35, 2.3, 4.95)):
        w = w0 + (w1 - w0) * z / 6.45
        k.box(-0.14, 0.14, tty + w, tty + w + 0.02, z, z + 0.24, bleu, "tour_hublot_%d" % i, bevel=0)
    for i, (za, zb) in enumerate(((0.15, 0.85), (1.05, 1.85), (2.95, 3.0))):
        w = w0 + (w1 - w0) * za / 6.45
        if zb - za > 0.2:
            k.louvres(-w + 0.08, -0.22, tty + w + 0.005, za, zb, 5, sombre, "tour_grille_%d" % i, depth=0.015)

    # --- 2 ailes de panneaux dorés dépliées (3 rangs) ---
    for s in (-1, 1):
        k.box(s * 0.3, s * 1.88, tty - 0.05, tty + 0.05, 3.95, 4.07, or_, "aile_poutre_%d" % s, bevel=0.004)
        k.box(s * 0.3, s * 1.88, tty - 0.04, tty + 0.04, 3.15, 3.23, sombre, "aile_longeron_%d" % s, bevel=0.004)
        k.rod(k.P(s * 0.4, tty, 2.6), k.P(s * 1.55, tty, 3.96), 0.035, blanc, "aile_hauban_%d" % s, verts=10, role="tige")
        for row, (z0, z1) in enumerate(((3.25, 3.85), (4.1, 4.7), (4.85, 5.42))):
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
                # reflet bleu des cellules (lueur de jour, bible §5 époque 14) : panneau central du rang du milieu
                k.loft([inset, face], bleu if (row == 1 and j == 1) else cell, "cellules_%d_%d_%d" % (s, row, j), bevel=0)
                # quadrillage des cellules (fils d'argent) : 2 traverses par panneau
                for t in (0.33, 0.66):
                    za = z0 + (z1 - z0) * t
                    tya = tty + 0.02 + (-tilt - 0.02) * t - 0.012
                    k.box(xa + 0.03, xb - 0.03, tya - 0.004, tya + 0.004, za - 0.006, za + 0.006, vis,
                          "cellules_fil_%d_%d_%d_%d" % (s, row, j, int(t * 100)), bevel=0)
        k.sphere(s * 1.83, tty, 3.95, 0.075, rouge, "balise_aile_%d" % s, seg=16, rings=8)

    # --- grande parabole sur la face avant de la tour ---
    k.rod(k.P(0.0, tty + 0.42, 4.95), k.P(0.0, tty + 0.75, 5.05), 0.07, blanc, "parabole_bras", verts=12)
    _dish(k, 0.0, tty + 0.75, 4.95, 0.8, 0.28, math.radians(52), math.radians(-25), blanc, "parabole")
    k.rod(k.P(0.0, tty + 0.75, 5.0), k.P(0.45, tty + 0.93, 5.46), 0.022, sombre, "parabole_source", role="tige")

    # --- mât-balise (tige, point le plus haut) ---
    k.cyl(0.0, tty, 0.035, 6.45, 7.2, sombre, "mat_balise", verts=10, bevel=0, role="tige")
    k.sphere(0.0, tty, 7.25, 0.08, rouge, "balise_sommet", seg=16, rings=8, role="tige")


# ----------------------------------------------------------------------------------------------------------
# Époque 15 · Palais : COURONNE de 5 flèches en or blanc (x distincts, étagées) ; anneau-halo sous les pointes ;
# BASE FLOTTANTE (soucoupe) haute et massive (vide sous la couronne) ; donjon de nacre à porte au sud ; particules
# en phase 2. Sous la soucoupe : seuls un faisceau fin et l'émetteur au sol (couche plate).
# ----------------------------------------------------------------------------------------------------------
def build_e15(k):
    orb = k.metal("or_blanc", "#E8DCB0", rough=0.24, metallic=0.9, dirt=0.55, gain=0.95)
    orb_p = k.metal("or_blanc_poli", "#E8DCB0", rough=0.18, metallic=0.95, clean=True, gain=0.9)
    nacre = k.matte("nacre", "#D8D2C8", rough=0.28, grain=0.26, dirt=0.55)
    sombre = k.metal("sombre", "#4A463E", rough=0.4, metallic=0.6)
    lum = k.emit("lumiere", "#FFF2C0", strength=1.0)
    lum_a = k.emit("lumiere_anneau", "#FFF2C0", strength=0.8)   # anneau-halo (passe 6 : bords blancs sur la nacre)

    bty, z0 = -0.15, 2.45
    # --- émetteur au sol (couche plate) et faisceau (tige fine) ---
    k.ngon(0.0, bty, 1.25, 24, 0.0, 0.025, sombre, "emetteur_dalle", sy=1.0, bevel=0, role="flat")
    k.torus(0.0, bty, 0.03, 1.05, 0.03, orb, "emetteur_anneau", minor_seg=6, major_seg=72, role="flat")
    k.ngon(0.0, bty, 0.24, 24, 0.0, 0.035, lum, "emetteur_coeur", sy=1.0, bevel=0, role="flat")
    k.cyl(0.0, bty, 0.045, 0.03, z0, lum, "faisceau", verts=12, bevel=0, role="tige")
    for i in range(3):
        k.torus(0.0, bty, 0.5 + 0.55 * i, 0.12 - 0.02 * i, 0.012, orb, "faisceau_bague_%d" % i, minor_seg=6, role="tige")

    # --- base flottante (soucoupe), plus massive ---
    k.lathe(0.0, bty, [(0.0, z0), (0.4, z0 + 0.08), (0.95, z0 + 0.3), (1.48, z0 + 0.56), (1.82, z0 + 0.74),
                       (1.88, z0 + 0.86), (1.83, z0 + 0.98), (0.0, z0 + 0.99)], nacre, "base_flottante", segs=72)
    k.torus(0.0, bty, z0 + 0.86, 1.88, 0.05, orb, "base_bourrelet", minor_seg=10, major_seg=96)
    k.torus(0.0, bty, z0 + 0.45, 1.3, 0.032, lum, "base_anneau_lueur", minor_seg=8, major_seg=72)
    cx, cy, _ = k.P(0.0, bty, 0)
    rays = []
    for i in range(14):
        a = math.pi + math.pi * (i + 0.5) / 14
        rays.append(k.rod((cx + 1.1 * math.cos(a), cy + 1.1 * math.sin(a), z0 + 0.995),
                          (cx + 1.8 * math.cos(a), cy + 1.8 * math.sin(a), z0 + 0.985), 0.014, orb_p, "rayon_%d" % i, verts=6))
    k.join(rays, "base_rayons")
    pts = []
    for i in range(30):
        a = math.pi + math.pi * (i + 0.5) / 30
        pts.append(((cx + 1.85 * math.cos(a), cy + 1.85 * math.sin(a), z0 + 0.79), (math.cos(a), math.sin(a), 0.2)))
    k.studs(pts, 0.02, orb_p, "base_rivets")
    k.sphere(0.0, bty, z0, 0.15, lum, "base_emetteur", seg=24, rings=12)
    # balustrade de la terrasse (colonnettes d'or blanc) au bord de la soucoupe
    cols = []
    for i in range(22):
        a = math.pi + math.pi * (i + 0.5) / 22
        cols.append(k.rod((cx + 1.7 * math.cos(a), cy + 1.7 * math.sin(a), z0 + 0.98),
                          (cx + 1.7 * math.cos(a), cy + 1.7 * math.sin(a), z0 + 1.2), 0.022, orb, "colonnette_%d" % i, verts=6))
    k.join(cols, "balustrade")
    k.torus(0.0, bty, z0 + 1.2, 1.7, 0.02, orb, "balustrade_main", minor_seg=6, major_seg=96)

    # --- donjon de nacre, massif (porte en ogive au sud) ---
    kty, zb = -0.25, z0 + 0.98
    # donjon plus massif (passe 2 du 22/10 : aire de silhouette 10,5 t² pour une cible >= 13)
    k.lathe(0.0, kty, [(1.28, zb), (1.30, zb + 0.55), (1.18, zb + 1.05), (1.32, zb + 1.18), (1.32, zb + 1.36),
                       (1.0, zb + 1.55), (0.62, zb + 1.72), (0.0, zb + 1.8)], nacre, "donjon", segs=64)
    k.torus(0.0, kty, zb + 1.18, 1.33, 0.045, orb, "donjon_corniche", minor_seg=10)
    k.ribs(0.0, kty, 1.28, zb + 0.05, zb + 1.02, 14, orb, "donjon_pilastres", w=0.055, d=0.028)
    k.sphere_seams(0.0, kty, zb + 1.36, 1.0, orb, "donjon_dome_nervures", lats=(0.35,), mers=6, minor=0.014, sz=0.44)
    # lanterne du donjon (passe 4 : aire 11,9 t² à la passe 3 ; masse ajoutée AU-DESSUS de v = -2,5)
    k.lathe(0.0, kty - 0.05, [(0.78, zb + 1.5), (0.80, zb + 2.05), (0.86, zb + 2.12), (0.86, zb + 2.22), (0.6, zb + 2.38),
                              (0.3, zb + 2.5), (0.0, zb + 2.54)], nacre, "lanterne", segs=48)
    k.torus(0.0, kty - 0.05, zb + 2.12, 0.87, 0.035, orb, "lanterne_corniche", minor_seg=10)
    k.ribs(0.0, kty - 0.05, 0.79, zb + 1.55, zb + 2.05, 10, orb, "lanterne_pilastres", w=0.05, d=0.025)
    for s in (-1, 0, 1):
        x = s * 0.42
        tyl = kty - 0.05 + math.sqrt(max(0.0, 0.8 ** 2 - x * x)) / R2
        _panel_xz(k, [(xx, z + zb + 1.62) for xx, z in _ogive(0.08, 0.16, 0.32)], tyl - 0.02, tyl + 0.02, lum,
                  "lanterne_baie_%d" % (s + 1), dx=x)
    # carène sous la soucoupe (cône renversé, nacre) : la base flottante gagne en masse
    k.lathe(0.0, bty, [(0.0, z0 - 0.8), (0.3, z0 - 0.7), (0.75, z0 - 0.42), (1.15, z0 - 0.14), (1.45, z0 + 0.12),
                       (0.0, z0 + 0.13)], nacre, "carene", segs=56)
    k.sphere_seams(0.0, bty, z0 - 0.3, 0.9, orb, "carene_nervures", lats=(), mers=8, minor=0.012, sz=0.6)
    k.torus(0.0, bty, z0 - 0.42, 0.75, 0.035, lum, "carene_anneau", minor_seg=8)
    ty_d = kty + 1.29 / R2
    _panel_xz(k, [(x, z + zb) for x, z in _ogive(0.26, 0.32, 0.64)], ty_d - 0.02, ty_d + 0.02, orb, "porte_cadre")
    _panel_xz(k, [(x, z + zb + 0.02) for x, z in _ogive(0.19, 0.3, 0.55)], ty_d + 0.01, ty_d + 0.035, lum, "porte_lumiere")
    for s in (-1, 1):
        x = s * 0.62
        tyw = kty + math.sqrt(max(0.0, 1.29 ** 2 - x * x)) / R2
        _panel_xz(k, [(xx, z + zb + 0.3) for xx, z in _ogive(0.09, 0.18, 0.34)], tyw - 0.02, tyw + 0.02, lum,
                  "fenetre_%d" % s, dx=x)

    # --- couronne de 5 flèches (x distincts, hauteurs étagées ; la centrale fixe O = 3,60) ---
    # pointes visées à l'écran (v = ty - 0,707 z) : centrale -5,60 ; paire intérieure -5,08 ; paire extérieure -4,58
    crown = [(0.0, kty - 0.12, zb + 2.3, -5.60, 0.46),
             (-0.80, kty - 0.45, z0 + 0.98, -5.12, 0.40), (0.80, kty - 0.45, z0 + 0.98, -5.12, 0.40),
             (-1.47, kty + 0.02, z0 + 1.9, -4.64, 0.34), (1.47, kty + 0.02, z0 + 1.9, -4.64, 0.34)]
    # passe 5 : les 2 flèches extérieures se dressent sur des TOURELLES de nacre posées au bord de la soucoupe
    # (aire de silhouette 12,1 t² à la passe 4 pour une cible >= 13 ; masse au-dessus de v = -2,5)
    for s in (-1, 1):
        x, ty = s * 1.47, kty + 0.02
        k.cyl(x, ty, 0.36, z0 + 0.98, z0 + 1.72, nacre, "tourelle_%d" % (s + 1), verts=32)
        k.ribs(x, ty, 0.36, z0 + 1.0, z0 + 1.7, 6, orb, "tourelle_pilastres_%d" % (s + 1), w=0.04, d=0.02)
        k.cyl(x, ty, 0.42, z0 + 1.72, z0 + 1.84, orb, "tourelle_corniche_%d" % (s + 1), verts=32)
        k.cyl(x, ty, 0.40, z0 + 1.84, z0 + 1.96, nacre, "tourelle_couronne_%d" % (s + 1), verts=32, r2=0.30)
        _panel_xz(k, [(xx, z + z0 + 1.2) for xx, z in _ogive(0.07, 0.14, 0.28)], ty + 0.36 / R2 - 0.02, ty + 0.36 / R2 + 0.02,
                  lum, "tourelle_baie_%d" % (s + 1), dx=x)
    for i, (x, ty, zs, vtip, rb) in enumerate(crown):
        ztip = (ty - vtip) / 0.7071
        k.ngon(x, ty, rb, 8, zs, ztip, orb, "fleche_%d" % i, r_top=0.0, rot=math.pi / 8, bevel=0.006)
        zc = zs + (ztip - zs) * 0.22
        k.ngon(x, ty, rb * 0.98, 8, zc, zc + 0.14, nacre, "fleche_collier_%d" % i, rot=math.pi / 8, bevel=0.004)
        k.ngon(x, ty, rb * 0.6, 8, zc + 0.14 + (ztip - zc) * 0.35, zc + 0.2 + (ztip - zc) * 0.35, orb_p,
               "fleche_bague_%d" % i, rot=math.pi / 8, bevel=0.003)
        k.sphere(x, ty, zc + 0.3, rb * 0.62, lum, "fleche_orbe_%d" % i, seg=20, rings=10)

    # --- anneau-halo, sous les pointes de la couronne ---
    k.torus(0.0, kty - 0.1, 4.95, 1.18, 0.11, lum_a, "anneau_halo", minor_seg=12, major_seg=96)
    k.torus(0.0, kty - 0.1, 4.80, 1.18, 0.05, orb, "anneau_or", minor_seg=10, major_seg=96)
    # orbes de la couronne (« halo de particules », pose de référence) : 3 sphères d'or blanc en orbite
    for i, (a, z) in enumerate(((200, 4.55), (285, 5.75), (340, 4.85))):
        ar = math.radians(a)
        k.sphere(1.66 * math.cos(ar), kty - 0.1 - 1.66 * math.sin(ar) / R2 * 0.75, z, 0.25, orb_p, "orbe_%d" % i, seg=24,
                 rings=12)
