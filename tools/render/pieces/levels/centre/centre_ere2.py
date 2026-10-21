"""Ère II lourde (époques 4 à 6) : cylindres, pentes, empilements ; plus large et plus haut (bible §1.2, §5)."""
import math

R2 = 2.0 ** 0.5


def _h(i, a=0.0):
    return math.sin(i * 12.9898 + a * 78.233) * 0.5 + math.sin(i * 4.1414 + a * 1.618) * 0.5


def _tank_x(k, x0, x1, ty, zc, r, mat, band, name, heads=0.55):
    """Cuve horizontale d'axe est-ouest à fonds bombés, deux bandes noires."""
    k.hcyl("x", x0, x1, 0, ty, zc, r, mat, name + "_virole", verts=48, bevel=0)
    for s, x in ((-1, x0), (1, x1)):
        o = k.sphere(x, ty, zc, r, mat, "%s_fond_%d" % (name, s), seg=40, rings=20)
        if o is not None:
            o.scale = (heads, 1, 1)
    for t in (0.22, 0.78):
        x = x0 + (x1 - x0) * t
        k.torus(x, ty, zc, r + 0.004, 0.022, band, "%s_bande_%d" % (name, int(t * 100)), rot=(0, math.pi / 2, 0),
                minor_seg=10)


def _saddle(k, x, ty, z0, zc, r, mat, name):
    """Berceau sous une cuve d'axe X : plaque verticale échancrée (approchée par une boîte + jambes)."""
    k.box(x - 0.05, x + 0.05, ty - 0.2, ty + 0.2, z0, zc - r * 0.55, mat, name, bevel=0.006)


# ----------------------------------------------------------------------------------------------------------
# Époque 4 · QG de raffinerie : bâtiment à toit-terrasse ; 2 cuves horizontales sur le toit ; passerelle à
# garde-corps ; torchère haute à l'arrière droit (tige et flamme).
# ----------------------------------------------------------------------------------------------------------
def build_e04(k):
    galva = k.metal("galva", "#6E7378", rough=0.4, metallic=0.7, grain=0.14, dirt=0.5)
    jaune = k.metal("jaune", "#8C7A3A", rough=0.5, metallic=0.3, rust="#5E4A2A", rust_amount=0.3, dirt=0.5)
    noir = k.metal("noir", "#232323", rough=0.6, metallic=0.3, grain=0.08, dirt=0.2)
    acier = k.metal("acier", "#55595E", rough=0.45, metallic=0.7, grain=0.12, dirt=0.5)
    vitre = k.glass("vitre", "#22262A")
    orange = k.emit("voyant", "#FF8C1A", strength=0.85)
    flamme = k.emit("flamme", "#FF8C1A", strength=1.2)
    fut_bleu = k.metal("fut_bleu", "#3E4A5A", rough=0.5, metallic=0.5, dirt=0.4)

    # --- corps à toit-terrasse ---
    k.box(-1.6, 1.6, -1.3, 1.3, 0.0, 1.15, galva, "corps", bevel=0.012)
    for i in range(16):
        x = -1.5 + i * 0.2
        if abs(x) < 0.45:
            continue
        k.box(x - 0.02, x + 0.02, 1.3, 1.315, 0.16, 1.1, galva, "nervure_%d" % i, bevel=0)
    # bande d'avertissement jaune et noire au pied
    k.box(-1.62, 1.62, 1.29, 1.32, 0.0, 0.15, jaune, "bande_jaune", bevel=0.004)
    stripes = []
    for i in range(14):
        x = -1.55 + i * 0.235
        stripes.append(k.prism([(x, 1.32), (x + 0.1, 1.32), (x + 0.1, 1.33), (x, 1.33)], 0.0, 0.15, noir,
                               "rayure_%d" % i, top_poly_game=[(x + 0.1, 1.32), (x + 0.2, 1.32), (x + 0.2, 1.33), (x + 0.1, 1.33)],
                               bevel=0))
    k.join(stripes, "rayures")
    # bandeau vitré de l'étage
    for s in (-1, 1):
        k.box(s * 0.5, s * 1.48, 1.29, 1.33, 0.70, 0.93, vitre, "bandeau_vitre_%d" % s, bevel=0.004)
        for x in (0.75, 1.0, 1.25):
            k.box(s * x - 0.015, s * x + 0.015, 1.31, 1.34, 0.70, 0.93, acier, "meneau_%d_%d" % (s, int(x * 100)), bevel=0)
    k.box(-1.64, 1.64, -1.34, 1.34, 1.10, 1.17, acier, "acrotere", bevel=0.006)
    k.railing([(-1.55, 1.25), (1.55, 1.25), (1.55, -1.25)], 1.17, 0.2, acier, "garde_corps_toit")

    # --- porte roulante et voyants orange ---
    k.box(-0.42, 0.42, 1.28, 1.36, 0.0, 0.72, jaune, "porte_cadre", bevel=0.006)
    k.box(-0.35, 0.35, 1.30, 1.37, 0.0, 0.66, acier, "porte_rideau", bevel=0.004)
    for z in (0.1, 0.2, 0.3, 0.4, 0.5, 0.6):
        k.box(-0.35, 0.35, 1.37, 1.38, z - 0.008, z + 0.008, noir, "porte_lame_%d" % int(z * 10), bevel=0)
    for s in (-1, 1):
        k.box(s * 0.58 - 0.08, s * 0.58 + 0.08, 1.30, 1.36, 0.40, 0.60, noir, "voyant_boitier_%d" % s, bevel=0.004)
        k.box(s * 0.58 - 0.065, s * 0.58 + 0.065, 1.355, 1.37, 0.415, 0.585, orange, "voyant_%d" % s, bevel=0)

    # --- cuve avant (sur berceaux, sur le toit) ---
    _saddle(k, -0.7, 0.35, 1.15, 1.65, 0.36, acier, "berceau_av_o")
    _saddle(k, 0.7, 0.35, 1.15, 1.65, 0.36, acier, "berceau_av_e")
    _tank_x(k, -1.15, 1.15, 0.35, 1.65, 0.36, jaune, noir, "cuve_av")

    # --- cuve arrière, haute, sur un châssis à 4 poteaux (empilement), passerelle à garde-corps ---
    zc, r = 2.75, 0.40
    for sx in (-1, 1):
        for ty in (-0.45, -1.05):
            k.box(sx * 0.95 - 0.045, sx * 0.95 + 0.045, ty - 0.032, ty + 0.032, 1.17, 2.32, acier,
                  "poteau_%d_%d" % (sx, int(-ty * 100)), bevel=0.004)
        k.rod(k.P(sx * 0.95, -0.45, 1.2), k.P(sx * 0.95, -1.05, 2.25), 0.018, acier, "contrevent_%d" % sx, role="tige")
    for ty in (-0.45, -1.05):
        k.rod(k.P(-0.95, ty, 1.25), k.P(0.95, ty, 2.25), 0.018, acier, "contrevent_t_%d" % int(-ty * 100), role="tige")
    k.box(-1.2, 1.2, -1.15, -0.35, 2.32, 2.37, acier, "passerelle", bevel=0.004)
    k.railing([(-1.18, -0.37), (1.18, -0.37)], 2.37, 0.2, acier, "garde_corps_passerelle")
    _saddle(k, -0.6, -0.75, 2.37, zc, r, acier, "berceau_ar_o")
    _saddle(k, 0.6, -0.75, 2.37, zc, r, acier, "berceau_ar_e")
    _tank_x(k, -1.2, 1.2, -0.75, zc, r, jaune, noir, "cuve_ar")
    # échelle (tige) et conduite descendante
    k.box(1.62, 1.66, 0.6, 0.62, 0.0, 1.17, acier, "echelle_montant_a", bevel=0, role="tige")
    k.box(1.62, 1.66, 0.85, 0.87, 0.0, 1.17, acier, "echelle_montant_b", bevel=0, role="tige")
    k.hcyl("y", -0.75, 0.35, 1.25, 0, 2.2, 0.05, galva, "conduite_cuves", verts=14, bevel=0)
    k.cyl(1.25, 0.35, 0.05, 1.7, 2.2, galva, "conduite_v", verts=14, bevel=0)
    k.torus(1.31, 0.0, 2.2, 0.09, 0.014, noir, "vanne_cuves", rot=(0, math.pi / 2, 0), minor_seg=8)

    # --- fûts (pied avant gauche) ---
    for j, (x, ty) in enumerate(((-1.42, 1.55), (-1.12, 1.62), (-1.48, 1.80))):
        k.cyl(x, ty, 0.13, 0.0, 0.38, fut_bleu if j != 1 else jaune, "fut_%d" % j, verts=24)
        for z in (0.12, 0.26):
            k.torus(x, ty, z, 0.132, 0.012, noir, "fut_cercle_%d_%d" % (j, int(z * 100)), minor_seg=8)

    # --- torchère (tige) et sa flamme, arrière droit : point le plus haut ---
    k.cyl(1.35, -1.35, 0.16, 0.0, 0.5, acier, "torchere_ballon", verts=24)
    k.cyl(1.35, -1.35, 0.06, 0.5, 4.05, acier, "torchere_fut", verts=14, bevel=0, role="tige")
    k.cyl(1.35, -1.35, 0.085, 3.95, 4.08, noir, "torchere_bec", verts=14, bevel=0, role="tige")
    for z in (1.5, 2.5, 3.5):
        k.torus(1.35, -1.35, z, 0.065, 0.012, noir, "torchere_bague_%d" % int(z), minor_seg=8, role="tige")
    k.lathe(1.35, -1.35, [(0.0, 4.06), (0.09, 4.12), (0.11, 4.22), (0.08, 4.36), (0.035, 4.48), (0.0, 4.55)], flamme,
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
    tung = k.metal("tungstene", "#3E3D42", rough=0.42, metallic=0.75, rust="#5A3A2A", rust_amount=0.35, dirt=0.55)
    ecaille = k.metal("ecaille", "#46444A", rough=0.38, metallic=0.8, rust="#5A3A2A", rust_amount=0.3, dirt=0.4)
    rouille = k.metal("rouille", "#5A3A2A", rough=0.7, metallic=0.3, grain=0.25, dirt=0.5)
    basalte = k.matte("basalte", "#2E2C30", rough=0.7, grain=0.3, grain_scale=30.0)
    rivet = k.metal("rivet", "#6A6670", rough=0.3, metallic=0.9, grain=0.08, dirt=0.2)
    braise = k.emit("braise", "#FF4A10", strength=0.6)
    braise_v = k.emit("braise_vive", "#FF7A30", strength=0.85)
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
        faces.append((bot[2][1], z0, top[2][1], z1))   # face avant : (ty, z) du bas et du haut
        k.rivets_line(k.P(-bot[1][0] + 0.12, bot[2][1] + 0.01, z0 + 0.06), k.P(bot[1][0] - 0.12, bot[2][1] + 0.01, z0 + 0.06),
                      int(bot[1][0] * 6), 0.028, rivet, name + "_rivets")
    # écailles de blindage sur la face avant du gradin 1 (deux rangs qui se chevauchent), hors avant-porte
    fc = faces[0]
    for row, (v0, v1) in enumerate(((0.10, 0.52), (0.45, 0.88))):
        n = 7
        for j in range(n):
            xa = -1.5 + j * (3.0 / n) + (0.1 if row else 0.0)
            xb = xa + 3.0 / n - 0.03
            if xb < -0.45 or xa > 0.45:
                _slab(k, [_face_pt(k, xa, v0, fc), _face_pt(k, xb, v0, fc), _face_pt(k, xb, v1, fc), _face_pt(k, xa, v1, fc)],
                      0.018, ecaille, "ecaille_%d_%d" % (row, j), push_bottom=0.035)
    # fentes de braise (lueur de jour) sur les faces avant
    for x in (-1.0, 1.0):
        _slab(k, [_face_pt(k, x - 0.16, 0.35, fc), _face_pt(k, x + 0.16, 0.35, fc), _face_pt(k, x + 0.16, 0.62, fc),
                  _face_pt(k, x - 0.16, 0.62, fc)], 0.03, braise, "fente_g1_%d" % int(x))
    f2 = faces[1]
    for x in (-0.55, 0.0, 0.55):
        _slab(k, [_face_pt(k, x - 0.15, 0.32, f2), _face_pt(k, x + 0.15, 0.32, f2), _face_pt(k, x + 0.15, 0.66, f2),
                  _face_pt(k, x - 0.15, 0.66, f2)], 0.03, braise, "fente_g2_%d" % int(x * 10))
    f3 = faces[2]
    _slab(k, [_face_pt(k, -0.2, 0.3, f3), _face_pt(k, 0.2, 0.3, f3), _face_pt(k, 0.2, 0.7, f3), _face_pt(k, -0.2, 0.7, f3)],
          0.03, braise, "fente_g3")
    # cratère de braise au sommet
    k.cyl(0.0, -0.3, 0.3, 2.2, 2.32, rouille, "cratere_levre", verts=32)
    k.cyl(0.0, -0.3, 0.22, 2.3, 2.33, braise_v, "cratere_braises", verts=32, bevel=0)

    # --- avant-porte et porte en ogive rougeoyante ---
    k.box(-0.45, 0.45, 1.20, 1.62, 0.0, 0.95, tung, "avant_porte", bevel=0.012)
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
            pout = (sx * 1.76, sy * 1.64)
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
# Époque 6 · Centrale de commandement : tour centrale ; 2 hautes piles d'isolateurs sur les côtés ; tore de
# Tesla au sommet ; arcs entre les piles (pose de référence ; animés par script en phase 2).
# ----------------------------------------------------------------------------------------------------------
def build_e06(k):
    acier = k.metal("acier", "#5C6168", rough=0.4, metallic=0.7, grain=0.14, dirt=0.5)
    cera = k.matte("ceramique", "#D8D4C8", rough=0.35, grain=0.08, dirt=0.45)
    cuivre = k.metal("cuivre", "#B0703A", rough=0.3, metallic=0.9, grain=0.12, rust="#4A6A58", rust_amount=0.15, dirt=0.35)
    alu = k.metal("alu", "#B8BCC0", rough=0.22, metallic=0.9, grain=0.06, dirt=0.25)
    sombre = k.metal("sombre", "#2A2C30", rough=0.5, metallic=0.5, dirt=0.3)
    cyan = k.emit("cyan", "#60D0FF", strength=0.6)
    arc = k.emit("arc", "#9FE6FF", strength=1.4)

    # --- salle de base ---
    k.box(-1.6, 1.6, -1.3, 1.35, 0.0, 0.70, acier, "salle", bevel=0.012)
    # Reprise V3 : le bandeau de céramique était une dalle PLEINE qui couvrait tout le toit (toit blanc
    # uniforme, L50 mesurée 160 pour une cible de 64). Bandeau sur les 4 murs seulement, toit d'acier sombre
    # à joints, trappes d'aération.
    for nm, (x0, x1, t0, t1) in (("av", (-1.63, 1.63, 1.33, 1.38)), ("ar", (-1.63, 1.63, -1.33, -1.28)),
                                 ("o", (-1.63, -1.58, -1.33, 1.38)), ("e", (1.58, 1.63, -1.33, 1.38))):
        k.box(x0, x1, t0, t1, 0.56, 0.74, cera, "bandeau_ceramique_%s" % nm, bevel=0.008)
    k.box(-1.58, 1.58, -1.28, 1.33, 0.70, 0.725, acier, "toit", bevel=0)
    for j, ty in enumerate((-0.95, -0.25, 0.45, 1.0)):
        k.box(-1.56, 1.56, ty - 0.015, ty + 0.015, 0.725, 0.745, acier, "toit_joint_%d" % j, bevel=0)
    for s in (-1, 1):
        k.box(s * 0.95 - 0.16, s * 0.95 + 0.16, 0.55, 0.85, 0.725, 0.80, acier, "aeration_%d" % s, bevel=0.006)
        for q in range(4):
            ty = 0.6 + q * 0.065
            k.box(s * 0.95 - 0.13, s * 0.95 + 0.13, ty, ty + 0.025, 0.80, 0.815, sombre, "aeration_lame_%d_%d" % (s, q), bevel=0)
    k.box(-1.63, 1.63, -1.33, 1.38, 0.0, 0.07, sombre, "socle", bevel=0.004)
    k.door(-0.3, 0.3, 1.36, 0.5, sombre, acier, name="porte")
    k.box(-0.17, 0.17, 1.36, 1.40, 0.555, 0.735, cyan, "voyant_porte", bevel=0)
    for x in (-1.25, -0.8, 0.8, 1.25):
        k.box(x - 0.12, x + 0.12, 1.34, 1.37, 0.20, 0.46, sombre, "fen_cadre_%d" % int((x + 2) * 100), bevel=0.004)
        k.box(x - 0.10, x + 0.10, 1.36, 1.38, 0.22, 0.44, cyan, "fen_%d" % int((x + 2) * 100), bevel=0)

    # --- tour centrale : fût d'acier, bobine de cuivre, col d'isolateurs, tore de Tesla ---
    cx, cty = 0.0, -0.45
    k.cyl(cx, cty, 0.6, 0.70, 1.52, acier, "tour_fut", verts=48)
    k.cyl(cx, cty, 0.5, 1.52, 2.56, sombre, "tour_noyau", verts=48)
    coil = [k.torus(cx, cty, 1.56 + i * 0.083, 0.52, 0.036, cuivre, "bobine_%d" % i, minor_seg=10) for i in range(13)]
    k.join(coil, "bobine")
    k.cyl(cx, cty, 0.6, 2.56, 2.8, acier, "tour_collier", verts=48)
    k.cyl(cx, cty, 0.16, 2.8, 3.32, cera, "col_noyau", verts=24)
    for i, z in enumerate((2.88, 3.0, 3.12, 3.24)):
        k.cyl(cx, cty, 0.3 - 0.02 * i, z, z + 0.055, cera, "col_disque_%d" % i, verts=32, bevel=0.012)
    k.torus(cx, cty, 3.48, 0.62, 0.19, alu, "tore_tesla", minor_seg=20)
    k.sphere(cx, cty, 3.5, 0.44, alu, "tore_dome", sz=0.42)
    k.mast(cx, cty, 3.6, 4.45, 0.022, cuivre, "paratonnerre")

    # --- 2 hautes piles d'isolateurs (colonnes crantées) ---
    for s in (-1, 1):
        x, ty = s * 1.3, -0.35
        k.box(x - 0.2, x + 0.2, ty - 0.2, ty + 0.2, 0.70, 0.92, acier, "pile_socle_%d" % s, bevel=0.008)
        k.cyl(x, ty, 0.085, 0.92, 2.86, cera, "pile_noyau_%d" % s, verts=20)
        discs = [k.cyl(x, ty, 0.22, 1.0 + i * 0.13, 1.05 + i * 0.13, cera, "pile_disque_%d_%d" % (s, i), verts=32, bevel=0.014)
                 for i in range(14)]
        k.join(discs, "pile_disques_%d" % s)
        k.cyl(x, ty, 0.12, 2.82, 2.9, cuivre, "pile_chapeau_%d" % s, verts=20)
        k.sphere(x, ty, 3.0, 0.13, cuivre, "pile_electrode_%d" % s, seg=24, rings=12)
        k.sphere(x - s * 0.1, ty, 3.06, 0.07, arc, "pile_etincelle_%d" % s, seg=16, rings=8, role="tige")
        # arc électrique (pose de référence) de l'électrode au tore
        pts = []
        n = 7
        a = k.P(x - s * 0.1, ty, 3.06)
        b = k.P(s * 0.62, cty, 3.46)
        for i in range(n + 1):
            t = i / n
            j = 0.0 if i in (0, n) else 0.07 * _h(i + 3 * s, 2)
            pts.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t + 0.5 * j,
                        a[2] + (b[2] - a[2]) * t + j + 0.12 * math.sin(math.pi * t)))
        segs = [k.rod(pts[i], pts[i + 1], 0.022, arc, "arc_%d_%d" % (s, i), verts=8, role="tige") for i in range(n)]
        k.join(segs, "arc_%d" % s)
