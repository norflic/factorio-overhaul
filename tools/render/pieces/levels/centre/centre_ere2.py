"""Ère II lourde (époques 4 à 6) : cylindres, pentes, empilements ; plus large et plus haut (bible §1.2, §5).

Correction V3 du 22/10 (vérification adverse, problème majeur 4) : le même corps-boîte servait de l'époque 2 à
l'époque 8 (IoU des corps 0,86 à 0,94) ; l'ère ne se lisait pas. Chaque époque de l'ère II a maintenant un CORPS
propre, en cylindres et en empilements :
  - époque 4 : la masse principale EST une grande cuve horizontale sur berceaux, une seconde cuve empilée
    au-dessus sur un portique, une cabine de contrôle basse devant (porte au sud) ; vides sous les cuves ;
  - époque 5 : pyramide tronquée à gradins (inchangée : déjà propre), plus de rivets et d'écailles ;
  - époque 6 : tour centrale RONDE partant du sol et 2 hautes piles d'isolateurs posées AU SOL de chaque côté
    (fiche E6 : « tour centrale » ; l'ancienne salle-boîte est supprimée).
"""
import math

R2 = 2.0 ** 0.5


def _h(i, a=0.0):
    return math.sin(i * 12.9898 + a * 78.233) * 0.5 + math.sin(i * 4.1414 + a * 1.618) * 0.5


def _tank_x(k, x0, x1, ty, zc, r, mat, band, name, heads=0.55, nb=(0.22, 0.78)):
    """Cuve horizontale d'axe est-ouest à fonds bombés, bandes noires."""
    k.hcyl("x", x0, x1, 0, ty, zc, r, mat, name + "_virole", verts=48, bevel=0)
    for s, x in ((-1, x0), (1, x1)):
        o = k.sphere(x, ty, zc, r, mat, "%s_fond_%d" % (name, s), seg=40, rings=20)
        if o is not None:
            o.scale = (heads, 1, 1)
    for t in nb:
        x = x0 + (x1 - x0) * t
        k.torus(x, ty, zc, r + 0.004, 0.022, band, "%s_bande_%d" % (name, int(t * 100)), rot=(0, math.pi / 2, 0),
                minor_seg=10)


def _tank_seams(k, x0, x1, ty, zc, r, n, mat, stud_mat, name):
    """Viroles soudées : joints circulaires (tores fins) et goujons sur la génératrice avant-haute."""
    objs = []
    for i in range(1, n):
        x = x0 + (x1 - x0) * i / n
        objs.append(k.torus(x, ty, zc, r + 0.002, 0.009, mat, "%s_joint_%d" % (name, i), rot=(0, math.pi / 2, 0),
                            minor_seg=6))
    k.join(objs, name + "_joints")
    pts = []
    for i in range(n * 5):
        x = x0 + (x1 - x0) * (i + 0.5) / (n * 5)
        for ang in (0.55, 1.0, 1.45):     # génératrices visibles (dessus et face sud), angle depuis +y Blender
            cx, cy, _ = k.P(x, ty, 0)
            ny, nz = -math.sin(ang), math.cos(ang)
            pts.append(((x, cy + ny * r, zc + nz * r), (0.0, ny, nz)))
    k.studs(pts, 0.012, stud_mat, name + "_rivets")


def _saddle(k, x, ty, z0, zc, r, mat, name):
    """Berceau sous une cuve d'axe X : plaque verticale échancrée (approchée par une boîte)."""
    k.box(x - 0.05, x + 0.05, ty - 0.22, ty + 0.22, z0, zc - r * 0.55, mat, name, bevel=0.006)


# ----------------------------------------------------------------------------------------------------------
# Époque 4 · QG de raffinerie : grande cuve horizontale (corps) sur berceaux ; seconde cuve empilée sur un
# portique ; passerelle à garde-corps ; cabine de contrôle (porte au sud) ; torchère haute (tige et flamme).
# ----------------------------------------------------------------------------------------------------------
def build_e04(k):
    galva = k.metal("galva", "#6E7378", rough=0.34, metallic=0.72, dirt=0.55)
    jaune = k.metal("jaune", "#8C7A3A", rough=0.45, metallic=0.3, rust="#5E4A2A", rust_amount=0.32, dirt=0.55)
    noir = k.metal("noir", "#232323", rough=0.55, metallic=0.3)
    acier = k.metal("acier", "#55595E", rough=0.38, metallic=0.72, dirt=0.55)
    boulon = k.metal("boulon", "#9A9CA0", rough=0.22, metallic=0.95, clean=True)
    vitre = k.glass("vitre", "#22262A")
    orange = k.emit("voyant", "#FF8C1A", strength=1.0)
    flamme = k.emit("flamme", "#FF8C1A", strength=1.0)
    fut_bleu = k.metal("fut_bleu", "#3E4A5A", rough=0.45, metallic=0.5, dirt=0.5)

    # --- grande cuve horizontale (corps principal) sur 3 berceaux ---
    tz, tty, tr = 1.0, -0.28, 0.62
    for x in (-0.95, 0.0, 0.95):
        _saddle(k, x, tty, 0.0, tz, tr, acier, "berceau_%d" % int((x + 1) * 10))
        k.box(x - 0.16, x + 0.16, tty - 0.26, tty + 0.26, 0.0, 0.06, noir, "berceau_semelle_%d" % int((x + 1) * 10),
              bevel=0.006)
    _tank_x(k, -1.42, 1.42, tty, tz, tr, jaune, noir, "cuve", nb=(0.12, 0.88))
    _tank_seams(k, -1.42, 1.42, tty, tz, tr, 4, noir, boulon, "cuve")
    # trou d'homme et évent sur la génératrice haute, échelle à crinoline côté est (tige)
    k.cyl(-0.55, tty, 0.14, tz + tr - 0.05, tz + tr + 0.08, galva, "cuve_trou_homme", verts=24)
    k.ring_studs(-0.55, tty, 0.14, tz + tr + 0.03, 8, 0.012, boulon, "cuve_trou_homme_boulons", a0=0, a1=2 * math.pi)
    k.cyl(0.6, tty, 0.05, tz + tr - 0.05, tz + tr + 0.22, galva, "cuve_event", verts=12)
    # bande d'identification noire et inscription (plaque claire) sur la face sud de la cuve
    k.box(-0.35, 0.35, tty + 0.30, tty + 0.34, tz - 0.06, tz + 0.18, galva, "cuve_plaque", bevel=0.006)
    k.stud_row(-0.32, 0.32, tty + 0.34, tz + 0.15, 6, 0.011, boulon, "cuve_plaque_vis")

    # --- cuve haute empilée, sur portique (arrière) ---
    hz, hty, hr = 2.05, -1.2, 0.46
    for sx in (-1, 1):
        for ty in (-0.95, -1.45):
            k.box(sx * 1.0 - 0.045, sx * 1.0 + 0.045, ty - 0.035, ty + 0.035, 0.0, hz - hr * 0.6, acier,
                  "poteau_%d_%d" % (sx, int(-ty * 100)), bevel=0.004)
        k.rod(k.P(sx * 1.0, -0.95, 0.15), k.P(sx * 1.0, -1.45, hz - hr * 0.7), 0.016, acier, "contrevent_%d" % sx, role="tige")
    for ty in (-0.95, -1.45):
        k.box(-1.05, 1.05, ty - 0.04, ty + 0.04, hz - hr * 0.6 - 0.08, hz - hr * 0.6, acier, "longeron_%d" % int(-ty * 100),
              bevel=0.004)
    _saddle(k, -0.55, hty, hz - hr * 0.6, hz, hr, acier, "berceau_haut_o")
    _saddle(k, 0.55, hty, hz - hr * 0.6, hz, hr, acier, "berceau_haut_e")
    _tank_x(k, -1.12, 1.12, hty, hz, hr, galva, noir, "cuve_haute")
    _tank_seams(k, -1.12, 1.12, hty, hz, hr, 3, noir, boulon, "cuve_haute")

    # --- passerelle à caillebotis entre les cuves, garde-corps (tige), escalier (tige) ---
    pz = tz + tr + 0.12
    k.box(-1.3, 1.3, -0.82, -0.62, pz - 0.03, pz, acier, "passerelle", bevel=0.004)
    gr = [k.box(x - 0.008, x + 0.008, -0.82, -0.62, pz, pz + 0.008, noir, "caillebotis_%d" % i, bevel=0)
          for i, x in enumerate([-1.25 + 0.1 * j for j in range(26)])]
    k.join(gr, "caillebotis")
    k.railing([(-1.3, -0.64), (1.3, -0.64)], pz, 0.2, acier, "garde_corps_passerelle")
    k.railing([(-1.3, tty + 0.2), (1.3, tty + 0.2)], tz + tr, 0.18, acier, "garde_corps_cuve")
    for i in range(7):
        z = 0.1 + i * (pz - 0.1) / 7
        k.box(1.55, 1.70, 0.40 - i * 0.12, 0.47 - i * 0.12, z, z + 0.025, acier, "marche_esc_%d" % i, bevel=0, role="tige")
    k.rod(k.P(1.55, 0.47, 0.35), k.P(1.55, -0.40, pz + 0.2), 0.012, acier, "rampe_esc", role="tige")

    # --- cabine de contrôle (avant, porte au sud) ---
    c0, c1, ch = 0.52, 1.42, 0.82
    k.box(-0.95, 0.95, c0, c1, 0.0, ch, galva, "cabine", bevel=0.015)
    k.panels(-0.95, 0.95, c0, c1, 0.0, ch, galva, "cabine_plaques", top=(4, 2), south=(6, 2), gap=0.03,
             skip=lambda f, xa, xb, a, b: f == "south" and (xb > -0.38 and xa < 0.38 or a > 0.38))
    k.box(-0.97, 0.97, c1 - 0.01, c1 + 0.02, 0.0, 0.14, jaune, "bande_jaune", bevel=0.004)
    stripes = []
    for i in range(9):
        x = -0.93 + i * 0.21
        stripes.append(k.prism([(x, c1 + 0.02), (x + 0.09, c1 + 0.02), (x + 0.09, c1 + 0.03), (x, c1 + 0.03)], 0.0, 0.14,
                               noir, "rayure_%d" % i, top_poly_game=[(x + 0.09, c1 + 0.02), (x + 0.18, c1 + 0.02),
                                                                     (x + 0.18, c1 + 0.03), (x + 0.09, c1 + 0.03)],
                               bevel=0))
    k.join(stripes, "rayures")
    for s in (-1, 1):
        k.box(s * 0.42, s * 0.88, c1, c1 + 0.03, 0.46, 0.70, vitre, "vitrage_%d" % s, bevel=0.004)
        for x in (0.57, 0.73):
            k.box(s * x - 0.012, s * x + 0.012, c1 + 0.02, c1 + 0.04, 0.46, 0.70, acier, "meneau_%d_%d" % (s, int(x * 100)),
                  bevel=0)
        k.box(s * 0.62 - 0.08, s * 0.62 + 0.08, c1, c1 + 0.04, 0.20, 0.36, noir, "voyant_boitier_%d" % s, bevel=0.004)
        k.box(s * 0.62 - 0.06, s * 0.62 + 0.06, c1 + 0.035, c1 + 0.05, 0.22, 0.34, orange, "voyant_%d" % s, bevel=0)
    k.box(-0.36, 0.36, c1 - 0.02, c1 + 0.05, 0.0, 0.68, jaune, "porte_cadre", bevel=0.006)
    k.box(-0.30, 0.30, c1 + 0.02, c1 + 0.06, 0.0, 0.62, acier, "porte_rideau", bevel=0.004)
    for z in (0.08, 0.16, 0.24, 0.32, 0.40, 0.48, 0.56):
        k.box(-0.30, 0.30, c1 + 0.06, c1 + 0.07, z - 0.008, z + 0.008, noir, "porte_lame_%d" % int(z * 100), bevel=0)
    k.box(-0.34, 0.34, c1 + 0.03, c1 + 0.07, 0.70, 0.76, orange, "porte_feu", bevel=0)
    k.railing([(-0.93, c1 - 0.03), (0.93, c1 - 0.03), (0.93, c0 + 0.03)], ch, 0.18, acier, "garde_corps_cabine")
    k.box(-0.62, -0.22, 0.75, 1.05, ch, ch + 0.16, galva, "cabine_clim", bevel=0.01)
    k.louvres(-0.60, -0.24, 1.05, ch + 0.02, ch + 0.14, 4, noir, "cabine_clim_grille")

    # --- conduites et vannes entre cuves et cabine ---
    k.hcyl("y", -1.2, 0.6, 1.25, 0, 0.42, 0.05, galva, "conduite_basse", verts=14, bevel=0)
    k.cyl(1.25, -1.2, 0.05, 0.42, hz - 0.2, galva, "conduite_montante", verts=14, bevel=0)
    k.torus(1.25, 0.25, 0.42, 0.09, 0.014, noir, "vanne_basse", rot=(0, math.pi / 2, 0), minor_seg=8)
    k.cyl(-1.25, -0.6, 0.05, 0.0, tz, galva, "conduite_ouest", verts=14, bevel=0)

    # --- fûts (pied avant gauche) ---
    for j, (x, ty) in enumerate(((-1.42, 1.0), (-1.15, 1.22), (-1.46, 1.42), (1.25, 1.35))):
        k.cyl(x, ty, 0.13, 0.0, 0.38, fut_bleu if j % 2 == 0 else jaune, "fut_%d" % j, verts=24)
        k.bands(x, ty, 0.13, (0.12, 0.26), noir, "fut_cercle_%d" % j, minor=0.012)

    # --- torchère (tige) et sa flamme, arrière droit : point le plus haut ---
    fx, fty = 1.45, -1.55
    k.cyl(fx, fty, 0.16, 0.0, 0.5, acier, "torchere_ballon", verts=24)
    k.cyl(fx, fty, 0.06, 0.5, 4.05, acier, "torchere_fut", verts=14, bevel=0, role="tige")
    k.cyl(fx, fty, 0.085, 3.95, 4.08, noir, "torchere_bec", verts=14, bevel=0, role="tige")
    for z in (1.5, 2.5, 3.5):
        k.torus(fx, fty, z, 0.065, 0.012, noir, "torchere_bague_%d" % int(z), minor_seg=8, role="tige")
    for a in (0.0, 2.1, 4.2):
        k.rod(k.P(fx, fty, 2.6), (fx + 0.5 * math.cos(a), -fty * R2 + 0.5 * math.sin(a), 0.0), 0.006, acier,
              "torchere_hauban_%d" % int(a * 10), role="tige")
    k.lathe(fx, fty, [(0.0, 4.06), (0.10, 4.13), (0.12, 4.24), (0.09, 4.40), (0.04, 4.54), (0.0, 4.62)], flamme,
            "torchere_flamme", segs=24, role="tige")


def _slab(k, corners, thick, mat, name, push_bottom=0.0, role="mass"):
    """Plaque posée sur une face : 4 coins Blender coplanaires (bas-gauche, bas-droit, haut-droit, haut-gauche),
    épaisseur vers l'extérieur (normale orientée vers le sud ou le haut) ; push_bottom écarte le bord bas
    (écaille)."""
    from mathutils import Vector
    p = [Vector(c) for c in corners]
    n = (p[1] - p[0]).cross(p[3] - p[0]).normalized()
    if n.y > 0 and abs(n.y) >= abs(n.z):
        n = -n
    if n.z < 0 and abs(n.z) > abs(n.y):
        n = -n
    top = [p[0] + n * (thick + push_bottom), p[1] + n * (thick + push_bottom), p[2] + n * thick, p[3] + n * thick]
    return k.loft([[tuple(v) for v in p], [tuple(v) for v in top]], mat, name, role=role)


def _face_pt(k, x, v, face):
    """Point d'une face avant inclinée : face = (ty_bas, z_bas, ty_haut, z_haut) ; v de 0 (bas) à 1 (haut)."""
    tb, zb, th, zh = face
    return k.P(x, tb + (th - tb) * v, zb + (zh - zb) * v)


def _face_n(face):
    """Normale (Blender) d'une face avant inclinée."""
    tb, zb, th, zh = face
    dy, dz = -(th - tb) * R2, zh - zb
    L = math.hypot(dy, dz)
    return (0.0, -dz / L, dy / L)


def _ogive(w, h_rect, h_tip, n=10):
    """Contour (x, z) d'une porte en ogive : rectangle de demi-largeur w puis arc brisé jusqu'à h_tip."""
    pts = [(-w, 0.0), (w, 0.0), (w, h_rect)]
    for i in range(1, n):
        t = i / n
        pts.append((w * math.cos(t * math.pi / 2) ** 0.85, h_rect + (h_tip - h_rect) * math.sin(t * math.pi / 2)))
    pts.append((0.0, h_tip))
    for i in range(n - 1, 0, -1):
        t = i / n
        pts.append((-w * math.cos(t * math.pi / 2) ** 0.85, h_rect + (h_tip - h_rect) * math.sin(t * math.pi / 2)))
    pts.append((-w, h_rect))
    return pts


def _panel_xz(k, pts_xz, ty0, ty1, mat, name, dx=0.0):
    """Panneau vertical (face sud) découpé selon un contour (x, z), entre ty0 et ty1."""
    r0 = [k.P(dx + x, ty0, z) for x, z in pts_xz]
    r1 = [k.P(dx + x, ty1, z) for x, z in pts_xz]
    return k.loft([r0, r1], mat, name)


# ----------------------------------------------------------------------------------------------------------
# Époque 5 · Citadelle volcanique : pyramide tronquée à gradins en blindage sombre ; contreforts inclinés aux
# 4 coins ; porte en ogive rougeoyante ; 2 pointes de basalte ; fentes de braise (lueur de jour).
# ----------------------------------------------------------------------------------------------------------
def build_e05(k):
    tung = k.metal("tungstene", "#3E3D42", rough=0.36, metallic=0.78, rust="#5A3A2A", rust_amount=0.35, dirt=0.6)
    ecaille = k.metal("ecaille", "#4A484E", rough=0.32, metallic=0.82, rust="#5A3A2A", rust_amount=0.3, dirt=0.5)
    rouille = k.metal("rouille", "#5A3A2A", rough=0.7, metallic=0.3, grain=0.3, dirt=0.55)
    basalte = k.matte("basalte", "#2E2C30", rough=0.65, grain=0.34, grain_scale=30.0)
    rivet = k.metal("rivet", "#A29EA8", rough=0.2, metallic=0.95, clean=True)
    braise = k.emit("braise", "#FF4A10", strength=1.0)
    braise_v = k.emit("braise_vive", "#FF4A10", strength=1.0)
    banniere = k.matte("banniere", "#4A1E18", rough=0.85)

    tiers = [
        ("gradin_1", [(-1.7, -1.55), (1.7, -1.55), (1.7, 1.55), (-1.7, 1.55)],
         [(-1.45, -1.3), (1.45, -1.3), (1.45, 1.3), (-1.45, 1.3)], 0.0, 0.75),
        ("gradin_2", [(-1.25, -1.25), (1.25, -1.25), (1.25, 0.95), (-1.25, 0.95)],
         [(-1.0, -1.05), (1.0, -1.05), (1.0, 0.75), (-1.0, 0.75)], 0.75, 1.45),
        ("gradin_3", [(-0.8, -1.0), (0.8, -1.0), (0.8, 0.45), (-0.8, 0.45)],
         [(-0.55, -0.85), (0.55, -0.85), (0.55, 0.25), (-0.55, 0.25)], 1.45, 2.2),
    ]
    faces = []
    for name, bot, top, z0, z1 in tiers:
        k.prism(bot, z0, z1, tung, name, top_poly_game=top, bevel=0.012)
        fc = (bot[2][1], z0, top[2][1], z1)
        faces.append(fc)   # face avant : (ty, z) du bas et du haut
        nrm = _face_n(fc)
        # rangées de rivets lourds en bas et en haut de chaque gradin (goujons à la normale de la face)
        pts = []
        for v in (0.12, 0.38, 0.62, 0.86):
            w = abs(bot[1][0]) + (abs(top[1][0]) - abs(bot[1][0])) * v - 0.1
            n = int(w * 9)
            for i in range(n):
                x = -w + 2 * w * (i + 0.5) / n
                pts.append((_face_pt(k, x, v, fc), nrm))
        k.studs(pts, 0.028, rivet, name + "_rivets")
        # joints verticaux de plaques (bandes sombres en relief)
        w0 = abs(bot[1][0])
        for i, x in enumerate([-w0 + 0.6 * j for j in range(1, int(2 * w0 / 0.6) + 1)]):
            if abs(x) < 0.5 and name == "gradin_1":
                continue
            _slab(k, [_face_pt(k, x - 0.015, 0.02, fc), _face_pt(k, x + 0.015, 0.02, fc), _face_pt(k, x + 0.015, 0.98, fc),
                      _face_pt(k, x - 0.015, 0.98, fc)], 0.012, rouille, "%s_joint_%d" % (name, i))
        # plaques du dessus (palier) : tôles boulonnées
        tb = top[2][1]
        if name != "gradin_3":
            k.panels(top[0][0] + 0.05, top[1][0] - 0.05, top[0][1] + 0.05, tb - 0.05, 0, z1, ecaille, name + "_palier",
                     top=(int((top[1][0] - top[0][0]) / 0.5), 2), south=None, gap=0.03, thick=0.012)
    # écailles de blindage sur la face avant des gradins 1 et 2 (deux rangs qui se chevauchent), hors avant-porte
    for fi, fc in enumerate(faces[:3]):
        for row, (v0, v1) in enumerate(((0.10, 0.52), (0.45, 0.88))):
            n = (7, 5, 3)[fi]
            W = (3.0, 2.1, 1.25)[fi]
            for j in range(n):
                xa = -W / 2 + j * (W / n) + (0.1 if row else 0.0)
                xb = xa + W / n - 0.03
                if fi >= 1 and abs((xa + xb) / 2) < 0.3:
                    continue
                if xb < -0.45 or xa > 0.45 or fi >= 1:
                    _slab(k, [_face_pt(k, xa, v0, fc), _face_pt(k, xb, v0, fc), _face_pt(k, xb, v1, fc),
                              _face_pt(k, xa, v1, fc)], 0.018, ecaille, "ecaille_%d_%d_%d" % (fi, row, j), push_bottom=0.035)
    # fentes de braise (lueur de jour) sur les faces avant
    fc = faces[0]
    for x in (-1.0, 1.0):
        _slab(k, [_face_pt(k, x - 0.17, 0.33, fc), _face_pt(k, x + 0.17, 0.33, fc), _face_pt(k, x + 0.17, 0.64, fc),
                  _face_pt(k, x - 0.17, 0.64, fc)], 0.03, braise, "fente_g1_%d" % int(x))
    f2 = faces[1]
    for x in (-0.55, 0.0, 0.55):
        _slab(k, [_face_pt(k, x - 0.16, 0.30, f2), _face_pt(k, x + 0.16, 0.30, f2), _face_pt(k, x + 0.16, 0.68, f2),
                  _face_pt(k, x - 0.16, 0.68, f2)], 0.03, braise, "fente_g2_%d" % int(x * 10))
    f3 = faces[2]
    _slab(k, [_face_pt(k, -0.22, 0.28, f3), _face_pt(k, 0.22, 0.28, f3), _face_pt(k, 0.22, 0.72, f3), _face_pt(k, -0.22, 0.72, f3)],
          0.03, braise, "fente_g3")
    # cratère de braise au sommet
    k.cyl(0.0, -0.3, 0.3, 2.2, 2.32, rouille, "cratere_levre", verts=32)
    k.ring_studs(0.0, -0.3, 0.3, 2.26, 10, 0.02, rivet, "cratere_rivets", a0=0, a1=2 * math.pi)
    k.cyl(0.0, -0.3, 0.22, 2.3, 2.33, braise_v, "cratere_braises", verts=32, bevel=0)

    # --- avant-porte et porte en ogive rougeoyante ---
    k.box(-0.45, 0.45, 1.20, 1.62, 0.0, 0.95, tung, "avant_porte", bevel=0.012)
    k.stud_row(-0.4, 0.4, 1.62, 0.9, 8, 0.02, rivet, "avant_porte_rivets")
    k.prism([(-0.5, 1.15), (0.5, 1.15), (0.5, 1.66), (-0.5, 1.66)], 0.95, 1.08, rouille, "avant_porte_toit",
            top_poly_game=[(-0.36, 1.25), (0.36, 1.25), (0.36, 1.52), (-0.36, 1.52)], bevel=0.008)
    _panel_xz(k, _ogive(0.27, 0.42, 0.80), 1.62, 1.635, rouille, "ogive_cadre")
    _panel_xz(k, _ogive(0.20, 0.40, 0.70), 1.63, 1.645, braise, "ogive_braise")
    bars = [k.box(x - 0.016, x + 0.016, 1.645, 1.665, 0.0, 0.62 - 0.5 * abs(x), rouille, "ogive_barreau_%d" % i, bevel=0)
            for i, x in enumerate((-0.12, 0.0, 0.12))]
    k.join(bars, "ogive_herse")

    # --- contreforts inclinés aux 4 coins ---
    for sx in (-1, 1):
        for sy in (-1, 1):
            nx, ny = -sy * 0.075, sx * 0.075
            pin = (sx * 1.30, sy * 1.18)
            pout = (sx * 1.70, sy * 1.60)
            ring0 = [k.P(pin[0] - nx, pin[1] - ny, 0.0), k.P(pin[0] + nx, pin[1] + ny, 0.0),
                     k.P(pout[0] + nx, pout[1] + ny, 0.0), k.P(pout[0] - nx, pout[1] - ny, 0.0)]
            ring1 = [k.P(pin[0] - nx, pin[1] - ny, 1.18), k.P(pin[0] + nx, pin[1] + ny, 1.18),
                     k.P(pout[0] + nx, pout[1] + ny, 0.10), k.P(pout[0] - nx, pout[1] - ny, 0.10)]
            k.loft([ring0, ring1], ecaille, "contrefort_%d_%d" % (sx, sy), bevel=0.01)

    # --- 2 pointes de basalte (asymétriques) ---
    k.ngon(-1.32, -1.2, 0.22, 6, 0.75, 3.02, basalte, "pointe_basalte_o", r_top=0.025, rot=0.3, bevel=0.006)
    k.ngon(1.30, -1.05, 0.19, 6, 0.75, 2.6, basalte, "pointe_basalte_e", r_top=0.02, rot=0.1, bevel=0.006)
    for x, ty, z in ((-1.32, -1.2, 1.2), (1.30, -1.05, 1.15)):
        k.ngon(x, ty, 0.235, 6, z, z + 0.08, rivet, "pointe_collier_%d" % int(x * 10), rot=0.2, bevel=0.004)

    # --- mât à bannière (tige, point le plus haut) ---
    k.mast(0.0, -0.62, 2.2, 4.35, 0.03, rivet, "mat")
    k.flag(0.0, -0.62, 4.25, 0.36, 0.26, banniere, "banniere", side=1)


# ----------------------------------------------------------------------------------------------------------
# Époque 6 · Centrale de commandement : TOUR CENTRALE ronde partant du sol (porte au sud) ; 2 hautes piles
# d'isolateurs POSÉES AU SOL de chaque côté ; tore de Tesla au sommet ; arcs entre les piles et le tore (pose de
# référence ; animés par script en phase 2) ; transformateurs au pied des piles.
# ----------------------------------------------------------------------------------------------------------
def build_e06(k):
    acier = k.metal("acier", "#5C6168", rough=0.34, metallic=0.75, dirt=0.55)
    cera = k.matte("ceramique", "#D8D4C8", rough=0.32, grain=0.26, dirt=0.55, gain=0.55)
    cuivre = k.metal("cuivre", "#B0703A", rough=0.26, metallic=0.92, rust="#4A6A58", rust_amount=0.2, dirt=0.4)
    alu = k.metal("alu", "#B8BCC0", rough=0.2, metallic=0.92, clean=True, gain=0.7)
    sombre = k.metal("sombre", "#2A2C30", rough=0.45, metallic=0.5)
    boulon = k.metal("boulon", "#A0A4A8", rough=0.22, metallic=0.95, clean=True)
    beton = k.matte("beton", "#6A6862", rough=0.85, grain=0.3, grain_scale=35.0)
    cyan = k.emit("cyan", "#60D0FF", strength=1.0)
    arc = k.emit("arc", "#60D0FF", strength=1.0)

    cx, cty = 0.0, -0.2
    # --- socle rond (dalle épaisse) et tour d'acier ---
    k.cyl(cx, cty, 1.08, 0.0, 0.22, beton, "socle", verts=64)
    k.ring_studs(cx, cty, 1.08, 0.11, 14, 0.02, boulon, "socle_boulons")
    k.cyl(cx, cty, 0.74, 0.22, 2.55, acier, "tour", verts=64)
    k.ribs(cx, cty, 0.74, 0.3, 2.5, 10, sombre, "tour_nervures", w=0.04, d=0.02)
    k.bands(cx, cty, 0.75, (0.32, 0.95, 2.48), cera, "tour_bagues", minor=0.035)
    # bobine de cuivre enroulée autour de la tour
    coil = [k.torus(cx, cty, 1.1 + i * 0.075, 0.78, 0.032, cuivre, "bobine_%d" % i, minor_seg=10) for i in range(17)]
    k.join(coil, "bobine")
    k.cyl(cx, cty, 0.82, 2.55, 2.78, acier, "tour_collier", verts=64)
    k.ring_studs(cx, cty, 0.82, 2.66, 12, 0.018, boulon, "collier_boulons")
    # col d'isolateurs (disques empilés) et tore de Tesla
    k.cyl(cx, cty, 0.18, 2.78, 3.55, cera, "col_noyau", verts=24)
    discs = [k.cyl(cx, cty, 0.34 - 0.02 * i, 2.86 + i * 0.13, 2.91 + i * 0.13, cera, "col_disque_%d" % i, verts=32,
                   bevel=0.012) for i in range(5)]
    k.join(discs, "col_disques")
    k.torus(cx, cty, 3.78, 0.64, 0.2, alu, "tore_tesla", minor_seg=20)
    k.sphere(cx, cty, 3.8, 0.46, alu, "tore_dome", sz=0.42)
    tp = []
    ccx, ccy, _ = k.P(cx, cty, 0)
    for i in range(16):
        a = math.pi + math.pi * (i + 0.5) / 16
        tp.append(((ccx + 0.64 * math.cos(a), ccy + 0.64 * math.sin(a), 3.78 + 0.2), (0.0, 0.0, 1.0)))
    k.studs(tp, 0.016, sombre, "tore_goujons")
    k.mast(cx, cty, 3.9, 4.6, 0.022, cuivre, "paratonnerre")

    # --- porche et porte au sud de la tour, fenêtres cyan ---
    p0 = cty + 0.74 / R2 - 0.08
    k.box(-0.36, 0.36, p0, p0 + 0.38, 0.22, 0.92, acier, "porche", bevel=0.015)
    k.prism([(-0.42, p0 - 0.02), (0.42, p0 - 0.02), (0.42, p0 + 0.42), (-0.42, p0 + 0.42)], 0.92, 1.0, sombre, "porche_toit",
            top_poly_game=[(-0.40, p0), (0.40, p0), (0.40, p0 + 0.32), (-0.40, p0 + 0.32)], bevel=0.006)
    k.door(-0.22, 0.22, p0 + 0.38, 0.72, sombre, acier, name="porte")
    k.box(-0.18, 0.18, p0 + 0.40, p0 + 0.44, 0.76, 0.86, cyan, "voyant_porte", bevel=0)
    for i, x in enumerate((-0.42, 0.0, 0.42)):
        ty = cty + math.sqrt(max(0.0, 0.74 ** 2 - x * x)) / R2 + 0.005
        k.box(x - 0.07, x + 0.07, ty - 0.03, ty + 0.01, 1.55, 2.25, sombre, "fen_cadre_%d" % i, bevel=0.004)
        k.box(x - 0.05, x + 0.05, ty, ty + 0.02, 1.6, 2.2, cyan, "fen_%d" % i, bevel=0)

    # --- 2 hautes piles d'isolateurs posées au sol (colonnes crantées), transformateurs ---
    for s in (-1, 1):
        x, ty = s * 1.56, 0.15
        k.box(x - 0.2, x + 0.2, ty - 0.2, ty + 0.2, 0.0, 0.34, acier, "pile_socle_%d" % s, bevel=0.012)
        k.stud_row(x - 0.16, x + 0.16, ty + 0.2, 0.28, 3, 0.016, boulon, "pile_socle_boulons_%d" % s)
        k.cyl(x, ty, 0.085, 0.34, 2.72, cera, "pile_noyau_%d" % s, verts=20)
        dd = [k.cyl(x, ty, 0.22, 0.44 + i * 0.13, 0.49 + i * 0.13, cera, "pile_disque_%d_%d" % (s, i), verts=32, bevel=0.014)
              for i in range(17)]
        k.join(dd, "pile_disques_%d" % s)
        k.cyl(x, ty, 0.12, 2.68, 2.78, cuivre, "pile_chapeau_%d" % s, verts=20)
        k.sphere(x, ty, 2.9, 0.14, cuivre, "pile_electrode_%d" % s, seg=24, rings=12)
        k.sphere(x - s * 0.12, ty, 2.96, 0.07, arc, "pile_etincelle_%d" % s, seg=16, rings=8, role="tige")
        # transformateur à ailettes au pied de la pile (vers la tour)
        tx = s * 1.05
        k.box(tx - 0.2, tx + 0.2, 0.55, 0.95, 0.0, 0.5, sombre, "transfo_%d" % s, bevel=0.012)
        k.louvres(tx - 0.17, tx + 0.17, 0.95, 0.06, 0.44, 6, acier, "transfo_ailettes_%d" % s)
        for j, dx in enumerate((-0.1, 0.1)):
            k.cyl(tx + dx, 0.75, 0.035, 0.5, 0.68, cera, "transfo_borne_%d_%d" % (s, j), verts=12)
        # câble au sol de la pile au transformateur, puis à la tour (tige)
        k.rod(k.P(x - s * 0.15, ty + 0.1, 0.05), k.P(tx, 0.75, 0.05), 0.02, sombre, "cable_%d" % s, role="tige")
        # arc électrique (pose de référence) de l'électrode au tore
        pts = []
        n = 8
        a = k.P(x - s * 0.12, ty, 2.96)
        b = k.P(s * 0.62, cty, 3.76)
        for i in range(n + 1):
            t = i / n
            j = 0.0 if i in (0, n) else 0.07 * _h(i + 3 * s, 2)
            pts.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t + 0.5 * j,
                        a[2] + (b[2] - a[2]) * t + j + 0.14 * math.sin(math.pi * t)))
        segs = [k.rod(pts[i], pts[i + 1], 0.024, arc, "arc_%d_%d" % (s, i), verts=8, role="tige") for i in range(n)]
        k.join(segs, "arc_%d" % s)
