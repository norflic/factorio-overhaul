"""Modèles paramétriques des 15 époques de la foreuse électrique (lot V3, phase 1). S'exécute DANS Blender.

Source de vérité : docs/DESIGN_EPOQUES.md (bible V1) §2.6 (fiche foreuse), §4 (enveloppes), §5 (fiches
d'époque, ligne « Foreuse »), §1.2 (ères), §1.5 (palette), §1.6 (lumière), décisions Q8 à Q13.

Identité invariante (bible §0) : cadre carré à 4 montants, tour (tige) centrale verticale, goulotte de sortie
du côté de l'orientation (repère N : au nord, vector_to_place_result {0, -1,85} inchangé). Les entrées de
fluide vanilla (-2, 0), (2, 0), (0, 2) restent dégagées au sol (milieux des côtés O, E et S).

Niveau impair 2e-1 = silhouette de l'époque e ; niveau pair 2e = la même + UNE pièce (au sommet de la tour,
dans un contexte `fixed()` : elle ne tourne pas avec la foreuse, donc 1 rendu suffit en phase 2).
Niveau 2 = sprite vanilla + chevalement en bois (masqué au pixel par l'alpha vanilla au post-traitement).

Budget de hauteur (kit.py) : sommet d'une masse en (a, b) : z <= (O + 1,5 - max(|a|, |b|)) / 0,7071. Les
hauteurs ci-dessous visent une hauteur O (masses, mesure measure_d1.py) qui ne décroît jamais, du niveau 1
(0,38) au plafond de l'époque 15 (1,60, bible §1.4, Q9). Les tiges fines (< 0,15 tuile) ne comptent pas.
"""
import math

import bpy
from mathutils import Matrix

from kit import K, srgb, scale

CP = 1.22          # coordonnée (tuiles) des montants d'angle, dans la boîte de collision (±1,4)
CHUTE_OUT = -1.60  # bout de la goulotte (tuiles) : sort de 0,10 de l'emprise, comme le vanilla
DAY_GAIN_E12 = 0.30  # émission de jour des lueurs « de nuit » des époques 1 et 2 (lanterne, forge)
EMIT_K = 0.40        # facteur des forces émissives de glow() (≈ 1 en sortie, comme la cheminée V0)


# ------------------------------------------------------------------------------------------------
# Matériaux
# ------------------------------------------------------------------------------------------------
def metal(ctx, key, hexc, rough=0.40, metallic=0.55, grain=0.20, gs=55.0, rust=None, ra=0.0, dirt=0.45, k=1.0):
    seed = float(sum(ord(c) for c in key) % 97) + 0.5
    return ctx.S.mat_metal(ctx.name(key), scale(srgb(hexc), k), rough=rough, metallic=metallic, grain=grain,
                           grain_scale=gs, rust=srgb(rust) if rust else None, rust_amount=ra, rust_scale=5.0,
                           dirt=dirt, seed=seed)


def paint(ctx, key, hexc, rough=0.48, grain=0.16, dirt=0.5, k=1.0, metallic=0.15, rust=None, ra=0.0):
    return metal(ctx, key, hexc, rough=rough, metallic=metallic, grain=grain, gs=40.0, rust=rust, ra=ra, dirt=dirt, k=k)


def glow(ctx, key, hexc, strength=2.0, base="#202020"):
    """Surface émissive. La force est multipliée par EMIT_K : à 2 à 3,2 (1re version), la passe principale
    saturait (cadran du manomètre BLANC au lieu d'ambre, aperçus du 21/10) ; ~1 comme la cheminée V0."""
    return ctx.S.mat_emissive(ctx.name(key), srgb(hexc), strength=strength * EMIT_K, base=srgb(base))


def glass(ctx, key, hexc, alpha=0.6, rough=0.06):
    m = bpy.data.materials.new(ctx.name(key))
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    c = srgb(hexc)
    p.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Alpha"].default_value = alpha
    m["fo_kind"] = "surface"
    return m


def I(n):
    """Intensité du halo de nuit proportionnelle au niveau (bible §1.6, D2-3) : I(N) = 0,05 + 0,02·N."""
    return 0.05 + 0.02 * n


def halo(ctx, a, b, z, hexc, watts):
    """Source de la seule passe halo (draw_as_light) ; puissance ∝ I(niveau) (= watts au niveau 10)."""
    p = ctx.P(a, b, z)
    c = srgb(hexc)
    ctx.S.halo_light(tuple(p), c, watts * I(ctx.level) / I(10), radius=0.06, name=ctx.name("halo"))


# ------------------------------------------------------------------------------------------------
# Éléments communs
# ------------------------------------------------------------------------------------------------
def chute(ctx, m_floor, m_wall, z_in, z_out, wid=0.46, b_in=-0.70, b_out=CHUTE_OUT, wall=0.14, lip=None):
    """Goulotte de sortie (repère N : vers le nord). Plancher + 2 joues, pente vers l'extérieur.
    Le dessus du plancher reçoit une tôle d'usure mate et sombre : en pose S, la pente (≈ 25°) tombe sur
    le reflet de l'appoint zénithal et une tôle brillante devenait une planche blanche (aperçus de la
    1re session)."""
    ctx.beam((0, b_in, z_in), (0, b_out, z_out), wid, m_floor, h=0.045, name="goulotte")
    worn = metal(ctx, "goulotte_usure", "#2E2B29", rough=0.68, metallic=0.35, grain=0.30, gs=40.0, rust="#4A2E1E",
                 ra=0.35, dirt=0.4)
    ctx.beam((0, b_in, z_in + 0.026), (0, b_out, z_out + 0.026), wid - 0.06, worn, h=0.012, bevel=0,
             name="goulotte_tole")
    for s in (-1, 1):
        ctx.beam((s * wid / 2, b_in, z_in + wall / 2), (s * wid / 2, b_out, z_out + wall / 2), 0.035, m_wall,
                 h=wall, name="goulotte_joue")
    if lip is not None:
        ctx.beam((-wid / 2 - 0.02, b_out, z_out + 0.01), (wid / 2 + 0.02, b_out, z_out + 0.01), 0.06, lip, h=0.06,
                 name="goulotte_levre")


def bit(ctx, m, z_top, r=0.20, z_bot=0.0, flights=3, m_flight=None):
    """Trépan : tige + vis (spires) + pointe conique (souvent à moitié caché, bible §3.3.5)."""
    ctx.cyl(0, 0, z_bot + 0.18, z_top, r * 0.55, m, name="tige")
    ctx.cyl(0, 0, z_bot, z_bot + 0.2, r, m, r2=r * 0.15, name="pointe")
    for i in range(flights):
        z = z_bot + 0.24 + i * (z_top - z_bot - 0.3) / max(1, flights)
        ctx.tor(0, 0, z, r * 0.85, r * 0.16, m_flight or m, rot=(0.18, 0, 0), name="spire")


def posts(ctx, m, z1, half=0.11, cap=None, cap_h=0.06, at=CP):
    for sa in (-1, 1):
        for sb in (-1, 1):
            a, b = sa * at, sb * at
            ctx.tbox(a - half, b - half * 0.8, a + half, b + half * 0.8, 0.0, z1, m, name="montant")
            if cap is not None:
                ctx.tbox(a - half - 0.03, b - half * 0.8 - 0.03, a + half + 0.03, b + half * 0.8 + 0.03, z1,
                         z1 + cap_h, cap, name="chapeau")


def lattice(ctx, z0, z1, w0, w1, member, m, rings=3, name="treillis"):
    """Tour en treillis à 4 jambes (positions de grille, demi-largeurs w0 -> w1 en tuiles)."""
    def corner(sa, sb, t):
        w = w0 + (w1 - w0) * t
        return (sa * w, sb * w, z0 + (z1 - z0) * t)
    cs = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    for sa, sb in cs:
        ctx.beam(corner(sa, sb, 0), corner(sa, sb, 1), member, m, name=name + "_jambe")
    for k in range(rings + 1):
        t = k / rings
        for i in range(4):
            p, q = cs[i], cs[(i + 1) % 4]
            ctx.beam(corner(p[0], p[1], t), corner(q[0], q[1], t), member * 0.8, m, name=name + "_ceinture")
        if k < rings:
            t2 = (k + 1) / rings
            for i in range(4):
                p, q = cs[i], cs[(i + 1) % 4]
                ctx.beam(corner(p[0], p[1], t), corner(q[0], q[1], t2), member * 0.6, m, name=name + "_croix")
                ctx.beam(corner(q[0], q[1], t), corner(p[0], p[1], t2), member * 0.6, m, name=name + "_croix")


def faces4(ctx, half, fn):
    """Appelle fn(a, b, nx, nb) au milieu de chacune des 4 faces d'un carré de demi-côté `half` (repère N).
    (nx, nb) = normale sortante en tuiles."""
    for (a, b, na, nb) in ((0, half, 0, 1), (0, -half, 0, -1), (half, 0, 1, 0), (-half, 0, -1, 0)):
        fn(a, b, na, nb)


# ------------------------------------------------------------------------------------------------
# Époque 1 · Pionnier : niveau 1 = vanilla ; niveau 2 = chevalement en bois (pièce posée sur le vanilla)
# ------------------------------------------------------------------------------------------------
def piece_e01(ctx):
    f = ctx.fixed()
    wood = metal(f, "e01_bois", "#6B4F35", rough=0.72, metallic=0.0, grain=0.35, gs=18.0, dirt=0.5)
    wood_d = metal(f, "e01_bois_sombre", "#4E3A28", rough=0.75, metallic=0.0, grain=0.3, gs=18.0, dirt=0.5)
    iron = metal(f, "e01_fer", "#5A5048", rough=0.5, metallic=0.6, grain=0.25, rust="#6A3A22", ra=0.5)
    rope = metal(f, "e01_corde", "#8A7A5A", rough=0.9, metallic=0.0, grain=0.2)
    flame = glow(f, "e01_flamme", "#FFB060", strength=3.0)
    # Le trépied coiffe la tour ; ses 2 jambes arrière partent des ANGLES ARRIÈRE du cadre (repère fixe :
    # nord de l'écran). La pièce est masquée au pixel par l'alpha vanilla (méthode « four » de V0, F42) :
    # seul ce qui DÉPASSE le haut de la silhouette vanilla se voit (bord haut à y ≈ -1,47 ; goulotte N
    # jusqu'à -1,89 au centre). 1re version (pieds autour de la tour, à 0,8) : seule la poulie dépassait.
    ca, cb = 0.0, -0.30                 # tête du chevalement, au-dessus de la tour vanilla
    apex = (ca, cb, 2.62)
    feet = [(-1.28, -1.25, 0.40), (1.28, -1.25, 0.40), (0.0, 0.55, 0.40)]
    for p in feet:
        f.beam(p, apex, 0.085, wood, name="chevalement_jambe")
    # entretoises entre les jambes arrière (au-dessus du vanilla) et croix de Saint-André
    pt = lambda p, t: tuple(p[i] + (apex[i] - p[i]) * t for i in range(3))
    m1 = [pt(p, 0.55) for p in feet[:2]]
    m2 = [pt(p, 0.30) for p in feet[:2]]
    f.beam(m1[0], m1[1], 0.06, wood_d, name="chevalement_traverse")
    f.beam(m2[0], m2[1], 0.06, wood_d, name="chevalement_traverse_basse")
    f.beam(m2[0], m1[1], 0.045, wood_d, name="chevalement_croix")
    f.beam(m2[1], m1[0], 0.045, wood_d, name="chevalement_croix")
    # tête : sellette, poulie face caméra, corde qui descend vers la tour
    f.box3(ca, cb, 2.66, (0.36, 0.12, 0.08), wood_d, name="sellette")
    f.wheel(ca, cb + 0.03, 2.84, 0.18, 0.024, iron, spokes=6, name="poulie")
    f.rod((ca + 0.18, cb + 0.03, 2.84), (ca + 0.18, -0.10, 1.90), 0.011, rope, name="corde")
    # lanterne au bout d'une potence sur la jambe arrière gauche (nuit seulement : bible §5 ép. 1)
    j = pt(feet[0], 0.45)
    la, lb, lz = j[0] - 0.25, j[1], j[2] - 0.08
    f.beam(j, (la, lb, j[2] + 0.04), 0.03, wood_d, name="potence_lanterne")
    f.rod((la, lb, j[2] + 0.04), (la, lb, lz + 0.015), 0.008, iron, name="lanterne_crochet")
    f.box3(la, lb, lz, (0.10, 0.10, 0.025), iron, name="lanterne_toit")
    f.box3(la, lb, lz - 0.14, (0.10, 0.10, 0.02), iron, name="lanterne_fond")
    for sx in (-1, 1):
        for sy in (-1, 1):
            f.box3(la + sx * 0.045, lb, lz - 0.07, (0.012, 0.012, 0.14), iron,
                   local=Matrix.Translation((0, sy * 0.045, 0)), name="lanterne_montant")
    f.sph(la, lb, lz - 0.07, 0.03, flame, name="lanterne_flamme")
    halo(f, la, lb, lz - 0.07, "#FFB060", 22.0)
    # volume de REMPLACEMENT de la foreuse vanilla (blender_batch.py) : cadre bas et tour centrale,
    # approchés sur les silhouettes vanilla (corps : y de -1,47 à +1,48 en pose N ; tige centrée en
    # by_pixel(1, -11)). Il ne sert qu'aux passes ombre (attrape-ombre) et halo (receveur), jamais à
    # l'image principale (masquée au pixel par l'alpha vanilla).
    prox = [f.tbox(-1.40, -1.40, 1.40, 1.40, 0.0, 0.40, None, bevel=0, name="proxy_cadre"),
            f.cyl(0.03, -0.10, 0.40, 1.95, 0.32, None, bevel=0, name="proxy_tour")]
    for o in prox:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        bpy.context.scene.collection.objects.link(o)
        o["fo_proxy"] = True


# ------------------------------------------------------------------------------------------------
# Époque 2 · Forge : acier boulonné, cerclages, cubes, créneaux ; tour en treillis
# ------------------------------------------------------------------------------------------------
def e02(ctx, piece):
    steel = metal(ctx, "e02_acier", "#5C6168", rough=0.34, metallic=0.55, grain=0.2, rust="#5A3A2A", ra=0.3, k=1.15)
    hoop = metal(ctx, "e02_cerclage", "#2E2C2A", rough=0.42, metallic=0.6, grain=0.15)
    brass = metal(ctx, "e02_laiton", "#8C7440", rough=0.26, metallic=0.9, grain=0.1, dirt=0.3)
    forge = glow(ctx, "e02_forge", "#FF6A20", strength=2.5)
    # rails au sol (poutres en I) et traverses
    for s in (-1, 1):
        ctx.tbox(s * CP - 0.10, -1.40, s * CP + 0.10, 1.40, 0.0, 0.13, hoop, name="rail")
        ctx.tbox(s * CP - 0.13, -1.38, s * CP + 0.13, 1.38, 0.13, 0.19, steel, name="rail_semelle")
        ctx.tbox(-CP, s * CP - 0.07, CP, s * CP + 0.07, 0.0, 0.12, steel, name="traverse")
    posts(ctx, steel, 0.80, half=0.12, cap=steel, cap_h=0.07)
    for sa in (-1, 1):
        for sb in (-1, 1):
            a, b = sa * CP, sb * CP
            for z0 in (0.22, 0.56):
                ctx.tbox(a - 0.145, b - 0.125, a + 0.145, b + 0.125, z0, z0 + 0.08, hoop, name="cerclage")
            ctx.sph(a, b, 0.90, 0.045, brass, name="boulon")
    # portique haut
    for s in (-1, 1):
        ctx.tbox(-CP, s * CP - 0.06, CP, s * CP + 0.06, 0.70, 0.82, steel, name="portique")
        ctx.tbox(s * CP - 0.06, -CP, s * CP + 0.06, CP, 0.70, 0.82, steel, name="portique")
        ctx.tbox(-CP, s * 0.48 - 0.06, CP, s * 0.48 + 0.06, 0.70, 0.82, steel, name="porteur")
    # carter cerclé (cube) et boucliers plats
    ctx.tbox(-0.56, -0.56, 0.56, 0.56, 0.82, 1.46, steel, bevel=0.02, name="carter")
    for z0 in (0.90, 1.32):
        ctx.tbox(-0.59, -0.59, 0.59, 0.59, z0, z0 + 0.07, hoop, name="carter_cerclage")
    # rivets en laiton sur les cerclages (4 faces)
    for z in (0.935, 1.355):
        for t in (-0.42, -0.14, 0.14, 0.42):
            for (a, b) in ((t, 0.60), (t, -0.60), (0.60, t), (-0.60, t)):
                ctx.sph(a, b, z, 0.022, brass, seg=10, rings=5, name="rivet")
    # fentes de forge (nuit seulement) sur les 4 faces
    def slits(a, b, na, nb):
        for k, dz in enumerate((1.08, 1.17, 1.26)):
            if na == 0:
                ctx.tbox(a - 0.24, b - 0.01 * nb, a + 0.24, b + 0.03 * nb, dz, dz + 0.035, forge, bevel=0, name="fente")
            else:
                ctx.tbox(a - 0.01 * na, b - 0.24, a + 0.03 * na, b + 0.24, dz, dz + 0.035, forge, bevel=0, name="fente")
    faces4(ctx, 0.56, slits)
    halo(ctx, 0.0, 0.75, 1.15, "#FF6A20", 18.0)
    halo(ctx, 0.0, -0.75, 1.15, "#FF6A20", 10.0)
    # tige et trépan sous le carter
    bit(ctx, hoop, 0.85, r=0.20)
    # tour en treillis HAUTE (1re version : sommet à 2,36, la tour ne se lisait pas au zoom 1)
    lattice(ctx, 1.46, 2.32, 0.40, 0.20, 0.06, steel, rings=3)
    ctx.tbox(-0.27, -0.27, 0.27, 0.27, 2.32, 2.48, steel, bevel=0.015, name="chapeau")
    for sa in (-1, 1):
        for sb in (-1, 1):
            ctx.tbox(sa * 0.27 - 0.07 * sa - 0.05, sb * 0.27 - 0.07 * sb - 0.045, sa * 0.27 - 0.07 * sa + 0.05,
                     sb * 0.27 - 0.07 * sb + 0.045, 2.48, 2.62, steel, bevel=0.008, name="merlon")
    chute(ctx, steel, hoop, z_in=0.95, z_out=0.30, lip=brass)
    if piece:
        f = ctx.fixed()
        f.level = ctx.level
        iron = metal(f, "e02p_fer", "#5C6168", rough=0.3, metallic=0.6, k=1.15)
        flame = glow(f, "e02p_flamme", "#FFB060", strength=3.0)
        # potence en A au-dessus du chapeau, grande poulie face caméra, lanterne de mine à l'est
        for s in (-1, 1):
            f.beam((s * 0.22, 0.0, 2.50), (s * 0.03, 0.0, 3.12), 0.05, iron, name="potence")
        f.wheel(0.0, 0.03, 3.10, 0.30, 0.04, iron, spokes=6, name="poulie")
        f.beam((0.0, 0.0, 3.12), (0.52, 0.0, 3.00), 0.045, iron, name="bras_lanterne")
        f.rod((0.50, 0.0, 3.00), (0.50, 0.0, 2.84), 0.009, iron, name="chaine")
        f.cyl(0.50, 0.0, 2.66, 2.84, 0.085, iron, name="lanterne")
        f.cyl(0.50, 0.0, 2.69, 2.81, 0.07, flame, name="lanterne_verre")
        halo(f, 0.50, 0.0, 2.75, "#FFB060", 20.0)


# ------------------------------------------------------------------------------------------------
# Époque 3 · Vapeur : chaudière verticale, cheminée ronde, volant, cuivre ; 1re lueur de jour
# ------------------------------------------------------------------------------------------------
def e03(ctx, piece):
    copper = metal(ctx, "e03_cuivre", "#8A5A3A", rough=0.30, metallic=0.7, grain=0.18, rust="#3E5A48", ra=0.25, k=1.1)
    brass = metal(ctx, "e03_laiton", "#9C7E45", rough=0.24, metallic=0.9, grain=0.1, dirt=0.3)
    iron = metal(ctx, "e03_fonte", "#3A3634", rough=0.5, metallic=0.5, grain=0.25, rust="#5A3A2A", ra=0.3, k=1.2)
    amber = glow(ctx, "e03_ambre", "#FFC060", strength=2.6)
    # socle en fonte : rails bas et pieds ronds à boule
    for s in (-1, 1):
        ctx.tbox(s * CP - 0.09, -1.36, s * CP + 0.09, 1.36, 0.0, 0.16, iron, name="rail")
        ctx.tbox(-CP, s * CP - 0.08, CP, s * CP + 0.08, 0.0, 0.14, iron, name="traverse")
    for sa in (-1, 1):
        for sb in (-1, 1):
            ctx.cyl(sa * CP, sb * CP, 0.0, 0.52, 0.11, iron, name="pied")
            ctx.tor(sa * CP, sb * CP, 0.40, 0.11, 0.025, brass, name="pied_bague")
            ctx.sph(sa * CP, sb * CP, 0.58, 0.10, brass, name="pied_boule")
            ctx.beam((sa * CP, sb * CP, 0.45), (sa * 0.35, sb * 0.35, 0.55), 0.07, iron, name="console")
    # plateau sous la chaudière
    ctx.cyl(0, 0, 0.18, 0.30, 0.78, iron, verts=48, name="plateau")
    # chaudière verticale (tour) : fût rivé, 4 cerclages en laiton, dôme ; plus haute que la 1re version
    # (dôme à 2,02 : O 0,10, la tour ne dépassait pas ; bible §4 rang 3 : O 0,55)
    R = 0.56
    ctx.cyl(0, 0, 0.30, 2.20, R, copper, verts=56, name="chaudiere")
    for z in (0.46, 1.06, 1.66, 2.12):
        ctx.tor(0, 0, z, R + 0.005, 0.028, brass, name="cerclage")
    for z in (0.76, 1.36, 1.90):
        for i in range(22):
            t = 2 * math.pi * i / 22
            ctx.sph(R * math.cos(t), -R * math.sin(t) / 1.4142, z, 0.017, brass, seg=8, rings=4, name="rivet")
    ctx.lathe(0, 0, [(R, 2.20), (R * 0.93, 2.38), (R * 0.70, 2.51), (R * 0.35, 2.58), (0.0, 2.60)], copper,
              name="dome")
    # dôme de vapeur et soupape
    ctx.cyl(0, 0, 2.53, 2.76, 0.17, brass, name="dome_vapeur")
    ctx.sph(0, 0, 2.76, 0.17, brass, sz=0.55, name="dome_vapeur_chapeau")
    ctx.cyl(0, 0, 2.78, 2.98, 0.035, brass, name="soupape")
    # hublots ambrés sur 4 côtés (≥ 8×8 px hr), cerclés de laiton
    for t in (-90.0, 0.0, 90.0, 180.0):
        tt = math.radians(t)
        x, y = (R + 0.01) * math.cos(tt), (R + 0.01) * math.sin(tt)
        o = ctx.S.cylinder(0.095, 0.03, (0, 0, 0), amber, ctx.name("hublot"), verts=24, bevel_w=0)
        ctx._finish(o, local=Matrix.Rotation(tt, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "Y"),
                    at=ctx.P(x, -y / 1.4142, 0.95))
        o2 = ctx.S.torus(0.10, 0.02, (0, 0, 0), brass, ctx.name("hublot_bague"), major_seg=24, minor_seg=6)
        ctx._finish(o2, local=Matrix.Rotation(tt, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "Y"),
                    at=ctx.P((R + 0.025) * math.cos(tt), -(R + 0.025) * math.sin(tt) / 1.4142, 0.95))
    halo(ctx, 0.0, 0.62, 0.95, "#FFC060", 16.0)
    # cheminée ronde au coin arrière gauche (opposé à la sortie), collerette et lèvre
    ca, cb = -0.62, 0.50
    ctx.cyl(ca, cb, 0.25, 1.90, 0.12, iron, verts=32, name="cheminee")
    ctx.tor(ca, cb, 1.1, 0.125, 0.02, brass, name="cheminee_bague")
    ctx.lathe(ca, cb, [(0.12, 1.86), (0.16, 1.96), (0.17, 2.00)], iron, caps=False, name="cheminee_levre")
    ctx.cyl(ca, cb, 1.90, 1.96, 0.10, metal(ctx, "e03_suie", "#151312", rough=0.9, metallic=0.0), name="suie")
    ctx.pipe_path([(ca + 0.12, cb, 0.70), (-0.40, cb - 0.05, 0.70)], 0.05, copper)
    # volant latéral (côté est), face caméra, et cylindre moteur
    ctx.wheel(1.02, 0.25, 0.62, 0.40, 0.04, iron, spokes=6, name="volant")
    ctx.cyl(0.86, 0.25, 0.20, 0.62, 0.05, iron, name="palier")
    ctx.rod((0.62, -0.25, 0.95), (1.02, 0.25, 0.80), 0.03, brass, name="bielle")
    ctx.beam((0.40, -0.25, 0.95), (0.85, -0.25, 0.95), 0.14, copper, name="cylindre_moteur")
    # tuyaux de cuivre vers la goulotte
    ctx.pipe_path([(0.0, -0.40, 1.60), (0.0, -0.75, 1.60), (0.0, -0.75, 0.95)], 0.045, copper)
    chute(ctx, copper, iron, z_in=0.88, z_out=0.38, lip=brass)
    bit(ctx, iron, 0.25, r=0.2)
    if piece:
        f = ctx.fixed()
        f.level = ctx.level
        brass2 = metal(f, "e03p_laiton", "#9C7E45", rough=0.22, metallic=0.9, grain=0.1, dirt=0.3)
        dial = glow(f, "e03p_cadran", "#FFC060", strength=2.6)
        # grand manomètre sur console, à gauche du dôme de vapeur (sort de la silhouette)
        f.beam((-0.12, 0.0, 2.63), (-0.42, 0.0, 2.90), 0.05, brass2, name="console_manometre")
        gz, ga = 3.00, -0.44
        tilt = Matrix.Rotation(math.radians(70), 4, "X")
        o = f.S.cylinder(0.24, 0.05, (0, 0, 0), brass2, f.name("manometre_boitier"), verts=40, bevel_w=0.006)
        f._finish(o, local=tilt, at=f.P(ga, 0.0, gz))
        o = f.S.cylinder(0.205, 0.012, (0, 0, 0), dial, f.name("manometre_cadran"), verts=40, bevel_w=0)
        f._finish(o, local=Matrix.Translation((0, -0.03, 0.01)) @ tilt, at=f.P(ga, 0.0, gz))
        f.box3(ga, -0.02, gz, (0.02, 0.012, 0.14), metal(f, "e03p_aiguille", "#1A1612", metallic=0.2),
               local=Matrix.Rotation(math.radians(35), 4, "Y") @ Matrix.Translation((0, -0.06, 0)), name="aiguille")
        # sifflet en laiton au sommet
        f.cyl(0.0, 0.0, 2.98, 3.20, 0.05, brass2, name="sifflet")
        f.lathe(0.0, 0.0, [(0.05, 3.20), (0.09, 3.28), (0.07, 3.36), (0.0, 3.38)], brass2, name="sifflet_cloche")
        halo(f, ga, -0.05, gz, "#FFC060", 10.0)


# ------------------------------------------------------------------------------------------------
# Époque 4 · Pétrole : châssis peint jaune, 2 vérins, cuve horizontale à l'arrière, passerelle sur le toit
# ------------------------------------------------------------------------------------------------
def e04(ctx, piece):
    yellow = paint(ctx, "e04_jaune", "#8C7A3A", rough=0.45, k=1.15, rust="#4A3A2A", ra=0.25)
    galva = metal(ctx, "e04_galva", "#6E7378", rough=0.36, metallic=0.6, grain=0.2, k=1.05)
    black = paint(ctx, "e04_noir", "#1E1E1E", rough=0.5)
    chrome = metal(ctx, "e04_chrome", "#B8BCC0", rough=0.15, metallic=0.95, grain=0.05, dirt=0.2)
    orange = glow(ctx, "e04_voyant", "#FF8C1A", strength=2.6)
    # pieds galvanisés et châssis jaune en poutres (le sol se voit entre les poutres)
    for sa in (-1, 1):
        for sb in (-1, 1):
            ctx.tbox(sa * CP - 0.11, sb * CP - 0.09, sa * CP + 0.11, sb * CP + 0.09, 0.0, 0.30, galva, name="pied")
    for s in (-1, 1):
        ctx.tbox(s * CP - 0.10, -1.38, s * CP + 0.10, 1.38, 0.30, 0.42, yellow, name="longeron")
        ctx.tbox(-1.38, s * CP - 0.09, 1.38, s * CP + 0.09, 0.30, 0.42, yellow, name="traverse")
        ctx.tbox(-CP, s * 0.45 - 0.07, CP, s * 0.45 + 0.07, 0.30, 0.40, yellow, name="porteur")
    # bandes noires d'avertissement sur les traverses avant et arrière
    for i in range(-5, 6, 2):
        for s in (-1, 1):
            ctx.tbox(i * 0.24 - 0.07, s * CP - 0.092, i * 0.24 + 0.07, s * CP + 0.092, 0.305, 0.425, black, bevel=0,
                     name="bande")
    # maison du moteur galvanisée + toit-passerelle à garde-corps
    ctx.tbox(-0.55, -0.55, 0.55, 0.55, 0.40, 1.30, galva, bevel=0.02, name="maison")
    ctx.tbox(-0.80, -0.80, 0.80, 0.80, 1.30, 1.36, metal(ctx, "e04_caillebotis", "#4E5256", rough=0.5), bevel=0.006,
             name="passerelle")
    rail_pts = [(-0.78, -0.78), (0.78, -0.78), (0.78, 0.78), (-0.78, 0.78)]
    for i in range(4):
        p, q = rail_pts[i], rail_pts[(i + 1) % 4]
        for z in (1.48, 1.60):
            ctx.beam((p[0], p[1], z), (q[0], q[1], z), 0.022, yellow, name="garde_corps")
        for k in range(4):
            t = k / 4
            x, y = p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t
            ctx.beam((x, y, 1.36), (x, y, 1.62), 0.02, yellow, name="poteau")
    # 2 vérins hydrauliques (fût jaune, tige chromée) et traverse
    for s in (-1, 1):
        ctx.cyl(s * 0.70, 0.0, 0.40, 1.20, 0.12, yellow, name="verin")
        ctx.tor(s * 0.70, 0.0, 1.18, 0.125, 0.02, black, name="verin_bague")
        ctx.cyl(s * 0.70, 0.0, 1.20, 1.70, 0.05, chrome, name="verin_tige")
    ctx.tbox(-0.82, -0.08, 0.82, 0.08, 1.70, 1.84, yellow, bevel=0.012, name="traverse_verins")
    # voyants orange (4 faces de la maison)
    def led(a, b, na, nb):
        if na == 0:
            ctx.tbox(a - 0.10, b - 0.01 * nb, a + 0.10, b + 0.03 * nb, 1.02, 1.20, orange, bevel=0, name="voyant")
        else:
            ctx.tbox(a - 0.01 * na, b - 0.10, a + 0.03 * na, b + 0.10, 1.02, 1.20, orange, bevel=0, name="voyant")
    faces4(ctx, 0.55, led)
    halo(ctx, 0.0, 0.70, 1.1, "#FF8C1A", 12.0)
    # colonne de pompe centrale (tour) et chapeau
    ctx.cyl(0, 0, 1.36, 2.74, 0.20, galva, name="colonne")
    for z in (1.80, 2.30):
        ctx.cyl(0, 0, z, z + 0.08, 0.215, yellow, name="colonne_bande")
    ctx.cyl(0, 0, 2.74, 2.86, 0.26, yellow, name="colonne_chapeau")
    # cuve horizontale à l'arrière (axe est-ouest dans le repère N), sur berceaux
    o = ctx.S.cylinder(0.30, 1.50, (0, 0, 0), galva, ctx.name("cuve"), verts=40, bevel_w=0.01)
    ctx._finish(o, local=Matrix.Rotation(math.pi / 2, 4, "Y"), at=ctx.P(0.0, 1.00, 0.72))
    for s in (-1, 1):
        o = ctx.S.sphere(0.30, (0, 0, 0), galva, ctx.name("cuve_fond"), seg=24, rings=12)
        o.data.transform(Matrix.Diagonal((0.35, 1, 1, 1)))
        ctx._finish(o, at=ctx.P(s * 0.75, 1.00, 0.72))
        ctx.tbox(s * 0.50 - 0.05, 0.80, s * 0.50 + 0.05, 1.20, 0.40, 0.55, black, name="berceau")
    for x in (-0.25, 0.25):
        o = ctx.S.torus(0.305, 0.02, (0, 0, 0), black, ctx.name("cuve_cerclage"), major_seg=32, minor_seg=6)
        ctx._finish(o, local=Matrix.Rotation(math.pi / 2, 4, "Y"), at=ctx.P(x, 1.00, 0.72))
    ctx.pipe_path([(0.0, 0.80, 0.90), (0.0, 0.55, 0.90)], 0.04, galva)
    chute(ctx, yellow, black, z_in=0.95, z_out=0.42, lip=black)
    bit(ctx, galva, 0.40, r=0.2)
    if piece:
        f = ctx.fixed()
        f.level = ctx.level
        steel = metal(f, "e04p_acier", "#6E7378", rough=0.35, metallic=0.6, k=1.05)
        lamp = glow(f, "e04p_feu", "#FF8C1A", strength=3.0)
        # petit derrick en treillis au-dessus du chapeau, moufle, feu au sommet
        # (1re version : treillis de 0,17 à la base, 0,09 t² ajoutés seulement, sous la cible 0,10)
        base, top, z0, z1 = 0.28, 0.07, 2.86, 3.48
        def c(sa, sb, t):
            w = base + (top - base) * t
            return (sa * w, sb * w * 0.75, z0 + (z1 - z0) * t)
        cs = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        for sa, sb in cs:
            f.beam(c(sa, sb, 0), c(sa, sb, 1), 0.055, steel, name="derrick_jambe")
        for t in (0.0, 0.5, 1.0):
            for i in range(4):
                p, q = cs[i], cs[(i + 1) % 4]
                f.beam(c(p[0], p[1], t), c(q[0], q[1], t), 0.04, steel, name="derrick_ceinture")
        for i in range(4):
            p, q = cs[i], cs[(i + 1) % 4]
            f.beam(c(p[0], p[1], 0), c(q[0], q[1], 0.5), 0.035, steel, name="derrick_croix")
            f.beam(c(p[0], p[1], 0.5), c(q[0], q[1], 1.0), 0.035, steel, name="derrick_croix")
        # plate-forme d'accrochage à mi-hauteur (débord vers l'est), moufle et feu au sommet
        f.box3(0.10, 0.0, z0 + (z1 - z0) * 0.5, (0.50, 0.30, 0.035), steel, name="plateforme_accrochage")
        f.box3(0, 0, z1 + 0.06, (0.22, 0.16, 0.12), steel, name="moufle")
        f.sph(0, 0, z1 + 0.19, 0.07, lamp, name="feu_derrick")
        halo(f, 0, 0, z1 + 0.19, "#FF8C1A", 14.0)


# ------------------------------------------------------------------------------------------------
# Époque 5 · Volcan : carcasse blindée en tronc de pyramide, écailles, braises
# ------------------------------------------------------------------------------------------------
def e05(ctx, piece):
    tung = metal(ctx, "e05_tungstene", "#3E3D42", rough=0.36, metallic=0.6, grain=0.25, rust="#5A3A2A", ra=0.35, k=1.25)
    tung_d = metal(ctx, "e05_tungstene_sombre", "#2C2B2F", rough=0.45, metallic=0.5, grain=0.25, k=1.2)
    basalt = metal(ctx, "e05_basalte", "#2A2624", rough=0.85, metallic=0.0, grain=0.45, gs=25.0)
    ember = glow(ctx, "e05_braise", "#FF4A10", strength=2.8)
    # contreforts inclinés aux 4 angles
    for sa in (-1, 1):
        for sb in (-1, 1):
            a0, a1 = sorted((sa * 1.42, sa * 0.98))
            b0, b1 = sorted((sb * 1.42, sb * 0.98))
            tr = (min(sa * 1.22, sa * 1.04), min(sb * 1.22, sb * 1.04), max(sa * 1.22, sa * 1.04), max(sb * 1.22, sb * 1.04))
            ctx.tfrustum(a0, b0, a1, b1, 0.0, 0.0, 0.95, tung_d, top_rect=tr, name="contrefort")
    # jupe d'écailles : 3 bandes en tronc de pyramide qui se chevauchent
    bands = [(1.30, 1.08, 0.04, 0.40), (1.12, 0.92, 0.36, 0.74), (0.96, 0.78, 0.70, 1.06)]
    for k, (h0, h1, z0, z1) in enumerate(bands):
        ctx.tfrustum(-h0, -h0, h0, h0, z0, h0 - h1, z1, tung if k % 2 == 0 else tung_d, name="ecaille")
    # fentes de braise sur les 4 faces de la bande médiane, et lueur du trépan sous la jupe
    def slits(a, b, na, nb):
        for t in (-0.45, 0.0, 0.45):
            if na == 0:
                ctx.box3(t, b * 1.0, 0.56, (0.20, 0.05, 0.07), ember, bevel=0, turn=True,
                         local=Matrix.Rotation(math.radians(-28) * nb, 4, "X"), name="fente")
            else:
                ctx.box3(a * 1.0, t, 0.56, (0.05, 0.28, 0.07), ember, bevel=0, turn=True,
                         local=Matrix.Rotation(math.radians(28) * na, 4, "Y"), name="fente")
    faces4(ctx, 1.035, slits)
    ctx.tbox(-0.70, 1.22, 0.70, 1.32, 0.0, 0.06, ember, bevel=0, name="lueur_trepan")
    halo(ctx, 0.0, 1.15, 0.45, "#FF4A10", 16.0)
    halo(ctx, 0.0, -1.15, 0.45, "#FF4A10", 8.0)
    # tourelle blindée rivetée, crête en pyramide
    ctx.tfrustum(-0.78, -0.78, 0.78, 0.78, 1.06, 0.26, 1.72, tung, name="tourelle")
    for z, h in ((1.12, 0.74), (1.66, 0.54)):
        for t in (-0.6, -0.3, 0.0, 0.3, 0.6):
            tt = t * h / 0.74
            for (a, b) in ((tt, h), (tt, -h), (h, tt), (-h, tt)):
                ctx.sph(a, b, z, 0.034, tung_d, seg=10, rings=5, name="rivet_lourd")
    ctx.tfrustum(-0.50, -0.50, 0.50, 0.50, 1.72, 0.32, 2.95, tung_d, name="crete")
    # fentes de braise sur la tourelle (face sud de chaque direction comprise)
    def slits2(a, b, na, nb):
        if na == 0:
            ctx.box3(0, b, 1.40, (0.40, 0.05, 0.06), ember, bevel=0,
                     local=Matrix.Rotation(math.radians(-22) * nb, 4, "X"), name="fente_haute")
        else:
            ctx.box3(a, 0, 1.40, (0.05, 0.55, 0.06), ember, bevel=0,
                     local=Matrix.Rotation(math.radians(22) * na, 4, "Y"), name="fente_haute")
    faces4(ctx, 0.66, slits2)
    # 2 pointes de basalte aux angles arrière
    for s in (-1, 1):
        ctx.cyl(s * 1.02, 1.02, 0.80, 1.48, 0.11, basalt, r2=0.0, verts=7, name="pointe_basalte")
    chute(ctx, tung, tung_d, z_in=0.95, z_out=0.50, wid=0.5, lip=tung_d)
    if piece:
        f = ctx.fixed()
        f.level = ctx.level
        basalt2 = metal(f, "e05p_basalte", "#2A2624", rough=0.85, metallic=0.0, grain=0.5, gs=25.0, k=1.2)
        ember2 = glow(f, "e05p_cratere", "#FF4A10", strength=3.2)
        # cône de cheminée volcanique coiffant la crête, cratère rougeoyant, coulées
        f.lathe(0, 0, [(0.54, 2.60), (0.42, 2.88), (0.25, 3.22), (0.17, 3.34), (0.13, 3.34), (0.10, 3.26)], basalt2,
                caps=True, name="cone_volcan", seg=11, smooth_deg=None)
        f.cyl(0, 0, 3.25, 3.29, 0.12, ember2, bevel=0, name="cratere")
        for t in (30.0, 150.0, 260.0):
            tt = math.radians(t)
            f.beam((0.16 * math.cos(tt), -0.16 * math.sin(tt) / 1.414, 3.25),
                   (0.40 * math.cos(tt), -0.40 * math.sin(tt) / 1.414, 2.71), 0.05, ember2, h=0.025, name="coulee")
        halo(f, 0, 0, 3.28, "#FF4A10", 14.0)


# ------------------------------------------------------------------------------------------------
# Époque 6 · Électricité : moteur bobiné au sommet, piles d'isolateurs aux angles arrière, arcs
# ------------------------------------------------------------------------------------------------
def insulator_stack(ctx, a, b, z0, n, r, pitch, cer, core, name="isolateurs"):
    ctx.cyl(a, b, z0, z0 + n * pitch + 0.04, r * 0.38, core, name=name + "_ame")
    for i in range(n):
        z = z0 + 0.04 + i * pitch
        ctx.lathe(a, b, [(r * 0.40, z), (r, z + pitch * 0.30), (r * 0.98, z + pitch * 0.45), (r * 0.40, z + pitch * 0.62)],
                  cer, seg=28, name=name + "_disque")
    return z0 + n * pitch + 0.04


def e06(ctx, piece):
    cer = metal(ctx, "e06_ceramique", "#D8D4C8", rough=0.30, metallic=0.0, grain=0.10, dirt=0.55, k=0.82)
    copper = metal(ctx, "e06_cuivre", "#B0703A", rough=0.28, metallic=0.8, grain=0.18, k=0.9)
    steel = metal(ctx, "e06_acier", "#5C6168", rough=0.34, metallic=0.55, grain=0.2, k=1.15)
    dark = metal(ctx, "e06_sombre", "#2A2C30", rough=0.45, metallic=0.5)
    cyan = glow(ctx, "e06_arc", "#60D0FF", strength=3.0)
    # cadre d'acier sur pieds isolés en céramique
    for sa in (-1, 1):
        for sb in (-1, 1):
            a, b = sa * CP, sb * CP
            insulator_stack(ctx, a, b, 0.0, 2, 0.12, 0.10, cer, dark, name="pied_isolant")
            ctx.tbox(a - 0.09, b - 0.07, a + 0.09, b + 0.07, 0.24, 0.72, steel, name="montant")
    for s in (-1, 1):
        ctx.tbox(-CP, s * CP - 0.06, CP, s * CP + 0.06, 0.40, 0.52, steel, name="longeron")
        ctx.tbox(s * CP - 0.06, -CP, s * CP + 0.06, CP, 0.40, 0.52, steel, name="longeron")
        ctx.tbox(-CP, s * 0.5 - 0.05, CP, s * 0.5 + 0.05, 0.40, 0.50, steel, name="porteur")
    # carter à persiennes
    ctx.tbox(-0.62, -0.62, 0.62, 0.62, 0.50, 1.10, steel, bevel=0.02, name="carter")
    def louvers(a, b, na, nb):
        for k in range(4):
            z = 0.62 + k * 0.11
            if na == 0:
                ctx.tbox(-0.45, b - 0.005 * nb, 0.45, b + 0.03 * nb, z, z + 0.04, dark, bevel=0, name="persienne")
            else:
                ctx.tbox(a - 0.005 * na, -0.45, a + 0.03 * na, 0.45, z, z + 0.04, dark, bevel=0, name="persienne")
    faces4(ctx, 0.62, louvers)
    # moteur bobiné : gros cylindre de cuivre, flasques d'acier, enroulement en spires
    ctx.cyl(0, 0, 1.10, 1.20, 0.54, steel, name="flasque")
    ctx.cyl(0, 0, 1.20, 2.20, 0.48, copper, name="bobine")
    for i in range(11):
        ctx.tor(0, 0, 1.27 + i * 0.085, 0.485, 0.03, copper, mseg=8, name="spire")
    ctx.cyl(0, 0, 2.20, 2.30, 0.54, steel, name="flasque_haut")
    for t in range(8):
        tt = 2 * math.pi * t / 8
        ctx.rod((0.50 * math.cos(tt), -0.50 * math.sin(tt) / 1.414, 1.10),
                (0.50 * math.cos(tt), -0.50 * math.sin(tt) / 1.414, 2.30), 0.022, steel, name="tirant")
    # pile d'isolateurs centrale (tour) et borne
    zt = insulator_stack(ctx, 0, 0, 2.30, 7, 0.17, 0.115, cer, dark, name="isolateurs_tour")
    ctx.sph(0, 0, zt + 0.05, 0.10, copper, name="borne")
    # 2 piles d'isolateurs aux angles arrière, reliées au moteur par des câbles ; arcs cyan
    for s in (-1, 1):
        a, b = s * 0.98, 0.98
        ctx.tbox(a - 0.13, b - 0.10, a + 0.13, b + 0.10, 0.52, 0.62, steel, name="socle_pile")
        top = insulator_stack(ctx, a, b, 0.62, 5, 0.12, 0.10, cer, dark, name="pile")
        ctx.sph(a, b, top + 0.05, 0.075, copper, name="pile_boule")
        ctx.sph(a, b, top + 0.05, 0.095, cyan, name="pile_aura")
        ctx.rod((a, b, top + 0.03), (s * 0.40, 0.25, 2.15), 0.016, copper, name="cable")
        # arc en zigzag (fixe en phase 1 ; animé en phase 2, feuille partagée de l'époque)
        pts = [(a, b, top + 0.10)]
        for k in range(1, 5):
            t = k / 5
            pts.append((a + (s * 0.30 - a) * t + (0.06 if k % 2 else -0.06), b + (0.20 - b) * t,
                        top + 0.10 + (2.25 - top - 0.10) * t + 0.10 * math.sin(t * math.pi)))
        pts.append((s * 0.30, 0.20, 2.25))
        for i in range(len(pts) - 1):
            ctx.rod(pts[i], pts[i + 1], 0.022, cyan, name="arc")
        halo(ctx, a, b, top + 0.10, "#60D0FF", 10.0)
    ctx.sph(0, 0, zt + 0.05, 0.13, cyan, name="borne_aura")
    halo(ctx, 0, 0, zt + 0.1, "#60D0FF", 10.0)
    chute(ctx, steel, dark, z_in=0.95, z_out=0.50, lip=copper)
    bit(ctx, dark, 0.50, r=0.2)
    if piece:
        f = ctx.fixed()
        f.level = ctx.level
        cer2 = metal(f, "e06p_ceramique", "#D8D4C8", rough=0.3, metallic=0.0, grain=0.1, dirt=0.5, k=0.82)
        copper2 = metal(f, "e06p_cuivre", "#B0703A", rough=0.26, metallic=0.85, k=0.9)
        arc = glow(f, "e06p_arc", "#60D0FF", strength=3.4)
        # éclateur à cornes : barre isolante, 2 cornes en V, boules, arc
        f.beam((-0.36, 0.0, zt + 0.16), (0.36, 0.0, zt + 0.16), 0.08, cer2, h=0.07, name="barre_isolante")
        for s in (-1, 1):
            f.rod((s * 0.10, 0.0, zt + 0.18), (s * 0.34, 0.0, zt + 0.62), 0.032, copper2, name="corne")
            f.sph(s * 0.34, 0.0, zt + 0.64, 0.06, copper2, name="corne_boule")
        for k in range(4):
            t0, t1 = k / 4, (k + 1) / 4
            def p(t):
                return (-0.30 + 0.60 * t, 0.0, zt + 0.62 + (0.05 if (k % 2) else -0.04) * math.sin(t * math.pi * 4))
            f.rod(p(t0), p(t1), 0.024, arc, name="arc_eclateur")
        halo(f, 0, 0, zt + 0.6, "#60D0FF", 12.0)


# ------------------------------------------------------------------------------------------------
# Époque 7 · Cristal : foreuse à résonance, 4 cristaux d'angle inclinés vers la tige, bronze et pierre
# ------------------------------------------------------------------------------------------------
def e07(ctx, piece):
    bronze = metal(ctx, "e07_bronze", "#6A5236", rough=0.30, metallic=0.75, grain=0.18, rust="#3E5A48", ra=0.25, k=1.2)
    stone = metal(ctx, "e07_pierre", "#4A4038", rough=0.85, metallic=0.0, grain=0.4, gs=22.0, k=1.15)
    crys = ctx.S.mat_emissive(ctx.name("e07_cristal"), srgb("#B070FF"), strength=0.9, base=srgb("#9A5CFF"))
    # 4 blocs de pierre taillée aux angles + barres de bronze
    for sa in (-1, 1):
        for sb in (-1, 1):
            a, b = sa * 1.14, sb * 1.14
            ctx.tfrustum(a - 0.26, b - 0.26, a + 0.26, b + 0.26, 0.0, 0.05, 0.42, stone, name="bloc")
            ctx.tbox(a - 0.20, b - 0.20, a + 0.20, b + 0.20, 0.42, 0.48, bronze, name="sertissure")
    for s in (-1, 1):
        ctx.tbox(-0.9, s * 1.14 - 0.05, 0.9, s * 1.14 + 0.05, 0.20, 0.30, bronze, name="barre")
        ctx.tbox(s * 1.14 - 0.05, -0.9, s * 1.14 + 0.05, 0.9, 0.20, 0.30, bronze, name="barre")
        ctx.beam((s * 1.0, -1.0, 0.40), (s * 0.30, -0.30, 0.85), 0.06, bronze, name="bras")
        ctx.beam((s * 1.0, 1.0, 0.40), (s * 0.30, 0.30, 0.85), 0.06, bronze, name="bras")
    # tour de résonance en bronze : colonne fuselée, bagues, berceau à griffes
    prof = [(0.44, 0.15), (0.40, 0.40), (0.30, 0.85), (0.36, 0.95), (0.36, 1.05), (0.26, 1.15), (0.22, 2.30),
            (0.30, 2.40), (0.30, 2.48), (0.20, 2.56), (0.17, 3.20), (0.0, 3.60)]
    ctx.lathe(0, 0, prof, bronze, seg=8, phase=math.pi / 8, smooth_deg=30, name="tour")
    for z in (1.55, 1.95):
        ctx.tor(0, 0, z, 0.235, 0.025, bronze, name="bague")
    # cristaux enchâssés dans la tour (lueur de jour)
    for t in (20.0, 140.0, 260.0):
        tt = math.radians(t)
        ctx.crystal((0.20 * math.cos(tt), -0.20 * math.sin(tt) / 1.414, 1.25),
                    (math.cos(tt) * 0.55, math.sin(tt) * 0.55, 1.0), 0.42, 0.075, crys, name="eclat")
    # 4 grands cristaux d'angle, asymétriques, inclinés vers la tige
    lens = {(-1, -1): 1.55, (1, -1): 1.20, (1, 1): 1.75, (-1, 1): 1.38}
    for (sa, sb), L in sorted(lens.items()):
        base = (sa * 1.06, sb * 1.06, 0.45)
        d = (-sa * 0.62, sb * 0.62 * 1.4142, 1.0)   # vers l'axe (Blender : y = -b·1,414)
        ctx.crystal(base, d, L, 0.15, crys, name="cristal")
        ctx.crystal((base[0] + sa * 0.06, base[1], 0.42), (sa * 0.3, -sb * 0.2, 1.0), L * 0.45, 0.08, crys,
                    name="cristal_satellite")
    halo(ctx, 0.0, 0.85, 1.0, "#B070FF", 12.0)
    halo(ctx, 0.0, -0.85, 1.0, "#B070FF", 8.0)
    chute(ctx, bronze, stone, z_in=0.95, z_out=0.55, lip=bronze)
    bit(ctx, bronze, 0.25, r=0.22)
    if piece:
        f = ctx.fixed()
        f.level = ctx.level
        crys2 = f.S.mat_emissive(f.name("e07p_cristal"), srgb("#B070FF"), strength=1.1, base=srgb("#9A5CFF"))
        # grappe de cristaux au sommet de la tour, en couronne irrégulière autour de la pointe
        # couronne irrégulière de 6 cristaux plantés autour de la pointe, très inclinés vers l'extérieur
        spec = [(15.0, 0.50, 0.10, 0.85), (75.0, 0.40, 0.085, 1.1), (160.0, 0.46, 0.09, 0.95),
                (220.0, 0.34, 0.08, 1.2), (285.0, 0.42, 0.085, 0.9), (340.0, 0.30, 0.07, 1.3)]
        for t, L, r, lean in spec:
            tt = math.radians(t)
            f.crystal((0.12 * math.cos(tt), -0.12 * math.sin(tt) / 1.414, 3.08),
                      (math.cos(tt) * lean, math.sin(tt) * lean, 1.0), L, r, crys2, name="grappe")
        halo(f, 0, 0, 3.25, "#B070FF", 12.0)


# ------------------------------------------------------------------------------------------------
# Époque 8 · Marais : lixiviation, 2 cuves sphériques en verre aux angles arrière, conduits vers la tige
# ------------------------------------------------------------------------------------------------
def e08(ctx, piece):
    vdg = metal(ctx, "e08_vertdegris", "#4F6B5A", rough=0.40, metallic=0.55, grain=0.22, rust="#2E3A32", ra=0.3, k=1.15)
    rubber = metal(ctx, "e08_caoutchouc", "#2A2A28", rough=0.8, metallic=0.0, grain=0.1)
    gl = glass(ctx, "e08_verre", "#8FBF4A", alpha=0.62)
    liq = glow(ctx, "e08_liquide", "#A8FF3A", strength=1.6, base="#5A7A20")
    # cadre de tuyaux : 4 poteaux ronds à dôme, rails-tuyaux au sol
    for sa in (-1, 1):
        for sb in (-1, 1):
            ctx.cyl(sa * CP, sb * CP, 0.0, 0.66, 0.11, vdg, name="poteau")
            ctx.sph(sa * CP, sb * CP, 0.66, 0.11, vdg, sz=0.7, name="poteau_dome")
            ctx.tor(sa * CP, sb * CP, 0.20, 0.115, 0.03, rubber, name="poteau_joint")
    for s in (-1, 1):
        ctx.rod((s * CP, -CP, 0.14), (s * CP, CP, 0.14), 0.07, vdg, verts=16, name="rail_tuyau")
        ctx.rod((-CP, s * CP, 0.14), (CP, s * CP, 0.14), 0.07, vdg, verts=16, name="rail_tuyau")
        ctx.rod((s * CP, -CP, 0.60), (s * CP, CP, 0.60), 0.05, vdg, verts=16, name="rail_haut")
    # socle rond et colonne de lixiviation (tour) à bagues de caoutchouc
    ctx.cyl(0, 0, 0.10, 0.36, 0.62, vdg, name="cuvette")
    ctx.lathe(0, 0, [(0.40, 0.36), (0.36, 0.80), (0.27, 1.10), (0.26, 2.20), (0.32, 2.30), (0.32, 2.40), (0.0, 2.42)],
              vdg, name="colonne")
    for z in (0.70, 1.30, 1.80):
        ctx.tor(0, 0, z, 0.29 if z > 1 else 0.36, 0.035, rubber, name="bague")
    # tube de verre lumineux au sommet, dans une cage, chapeau
    ctx.cyl(0, 0, 2.42, 3.21, 0.15, liq, name="tube_liquide")
    for t in range(4):
        tt = math.pi / 4 + t * math.pi / 2
        ctx.rod((0.19 * math.cos(tt), -0.19 * math.sin(tt) / 1.414, 2.40),
                (0.19 * math.cos(tt), -0.19 * math.sin(tt) / 1.414, 3.25), 0.022, vdg, name="cage")
    for zr in (2.70, 2.95):
        ctx.tor(0, 0, zr, 0.19, 0.022, vdg, name="cage_bague")
    ctx.lathe(0, 0, [(0.24, 3.21), (0.24, 3.29), (0.16, 3.37), (0.0, 3.41)], vdg, name="chapeau")
    # 2 cuves sphériques en verre aux angles arrière (liquide lumineux dans la moitié basse), berceaux
    for s in (-1, 1):
        a, b = s * 0.93, 0.93
        ctx.sph2(a, b, 0.86, 0.40, gl, liq, level=0.05, name="cuve_verre")
        ctx.tor(a, b, 0.66, 0.33, 0.04, vdg, name="berceau")
        for t in range(3):
            tt = 2 * math.pi * t / 3 + 0.4
            ctx.rod((a + 0.30 * math.cos(tt), b - 0.30 * math.sin(tt) / 1.414, 0.0),
                    (a + 0.33 * math.cos(tt), b - 0.33 * math.sin(tt) / 1.414, 0.66), 0.035, vdg, name="berceau_pied")
        ctx.cyl(a, b, 1.22, 1.34, 0.08, vdg, name="col")
        ctx.pipe_path([(a, b, 1.30), (a, b, 1.50), (s * 0.55, 0.40, 1.62), (s * 0.24, 0.12, 1.62)], 0.045, vdg)
        halo(ctx, a, b, 0.8, "#A8FF3A", 8.0)
    halo(ctx, 0, 0, 2.9, "#A8FF3A", 10.0)
    chute(ctx, vdg, rubber, z_in=0.95, z_out=0.55, lip=rubber)
    bit(ctx, vdg, 0.12, r=0.2)
    if piece:
        f = ctx.fixed()
        f.level = ctx.level
        gl2 = glass(f, "e08p_verre", "#8FBF4A", alpha=0.65)
        liq2 = glow(f, "e08p_liquide", "#A8FF3A", strength=1.8, base="#5A7A20")
        vdg2 = metal(f, "e08p_vertdegris", "#4F6B5A", rough=0.4, metallic=0.55, k=1.15)
        # bulbe-distillateur posé sur le chapeau, col de cygne qui part vers l'est et redescend
        f.cyl(0, 0, 3.37, 3.45, 0.06, vdg2, name="bulbe_col_bas")
        f.sph2(0, 0, 3.59, 0.17, gl2, liq2, level=0.0, name="bulbe")
        f.cyl(0, 0, 3.73, 3.83, 0.045, gl2, name="bulbe_col")
        arc = [(0.24 - 0.24 * math.cos(math.pi * k / 6), 0.0, 3.83 + 0.20 * math.sin(math.pi * k / 6)) for k in range(7)]
        f.pipe_path(arc, 0.035, gl2, name="col_de_cygne")
        f.cyl(0.48, 0.0, 3.23, 3.83, 0.035, gl2, name="col_descente")
        f.sph2(0.48, 0.0, 3.15, 0.11, gl2, liq2, level=0.2, name="recette")
        halo(f, 0, 0, 3.59, "#A8FF3A", 10.0)


# ------------------------------------------------------------------------------------------------
# Époque 9 · Atome : blindage octogonal plombé, évent hyperboloïde, vert uranium
# ------------------------------------------------------------------------------------------------
def octagon(h, ch):
    return [(-h + ch, -h), (h - ch, -h), (h, -h + ch), (h, h - ch), (h - ch, h), (-h + ch, h), (-h, h - ch), (-h, -h + ch)]


def e09(ctx, piece):
    lead = metal(ctx, "e09_plomb", "#4A5058", rough=0.42, metallic=0.5, grain=0.22, k=1.15)
    warn = paint(ctx, "e09_jaune", "#C9A227", rough=0.5, k=0.9)
    concrete = metal(ctx, "e09_beton", "#7A7670", rough=0.85, metallic=0.0, grain=0.3, gs=30.0, k=0.95)
    dark = metal(ctx, "e09_sombre", "#24262A", rough=0.6, metallic=0.3)
    green = glow(ctx, "e09_uranium", "#5CFF4A", strength=2.2, base="#1A5A14")
    # 4 piliers octogonaux en béton à bande jaune
    for sa in (-1, 1):
        for sb in (-1, 1):
            ctx.cyl(sa * CP, sb * CP, 0.0, 0.55, 0.17, concrete, verts=8, name="pilier")
            ctx.cyl(sa * CP, sb * CP, 0.40, 0.48, 0.175, warn, verts=8, name="pilier_bande")
    # carter octogonal plombé, bandeau jaune, hublots verts
    ctx.tprism(octagon(1.12, 0.42), 0.30, 1.16, lead, name="carter")
    ctx.tprism(octagon(1.15, 0.43), 1.06, 1.16, warn, name="bandeau")
    for i in range(-4, 5):
        ctx.tbox(i * 0.16 - 0.035, 1.14, i * 0.16 + 0.035, 1.17, 1.06, 1.16, dark, bevel=0, name="chevron")
    def port(a, b, na, nb):
        tt = math.atan2(-nb, na)
        o = ctx.S.cylinder(0.11, 0.04, (0, 0, 0), green, ctx.name("hublot"), verts=24, bevel_w=0)
        ctx._finish(o, local=Matrix.Rotation(tt, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "Y"),
                    at=ctx.P(a + 0.01 * na, b + 0.01 * nb, 0.70))
        o = ctx.S.torus(0.12, 0.025, (0, 0, 0), dark, ctx.name("hublot_bague"), major_seg=24, minor_seg=6)
        ctx._finish(o, local=Matrix.Rotation(tt, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "Y"),
                    at=ctx.P(a + 0.02 * na, b + 0.02 * nb, 0.70))
    faces4(ctx, 1.12, port)
    halo(ctx, 0, 1.25, 0.7, "#5CFF4A", 10.0)
    # pont octogonal supérieur
    ctx.tprism(octagon(0.72, 0.28), 1.16, 1.34, lead, name="pont")
    # évent hyperboloïde (tour de refroidissement) au-dessus de la tige, ouvert en haut, cœur vert
    prof = []
    for k in range(13):
        z = 1.34 + k * (3.18 - 1.34) / 12
        u = (z - 2.62) / 0.98
        prof.append((0.40 * math.sqrt(1 + u * u) * (1.0 if z < 2.62 else 0.94), z))
    ctx.lathe(0, 0, prof, concrete, seg=40, caps=False, name="event")
    inner = [(r - 0.04, z) for (r, z) in prof[6:]]
    ctx.lathe(0, 0, inner, dark, seg=40, caps=False, name="event_interieur")
    ctx.tor(0, 0, 3.18, prof[-1][0] - 0.02, 0.03, concrete, name="event_levre")
    ctx.cyl(0, 0, 2.62, 2.69, prof[6][0] - 0.03, green, bevel=0, name="coeur")
    ctx.cyl(0, 0, 2.10, 2.22, prof[4][0] + 0.005, warn, bevel=0, name="event_bande")
    halo(ctx, 0, 0, 3.0, "#5CFF4A", 12.0)
    # conduits annelés du carter vers l'évent
    for s in (-1, 1):
        pts = [(s * 0.85, 0.3, 1.20), (s * 0.85, 0.3, 1.55), (s * 0.40, 0.2, 1.75)]
        ctx.pipe_path(pts, 0.06, lead)
        for k in range(5):
            t = k / 4
            x = s * 0.85
            ctx.tor(x, 0.3, 1.22 + t * 0.32, 0.065, 0.015, dark, mseg=6, name="anneau")
    chute(ctx, lead, dark, z_in=0.95, z_out=0.55, lip=warn)
    bit(ctx, dark, 0.32, r=0.2)
    if piece:
        f = ctx.fixed()
        f.level = ctx.level
        warn2 = paint(f, "e09p_jaune", "#C9A227", rough=0.45, k=0.9)
        dark2 = metal(f, "e09p_sombre", "#24262A", rough=0.5, metallic=0.4)
        green2 = glow(f, "e09p_balise", "#5CFF4A", strength=3.0, base="#1A5A14")
        # balises de radiation sur consoles, de part et d'autre de la lèvre de l'évent
        for s in (-1, 1):
            f.beam((s * 0.30, 0.0, 3.10), (s * 0.68, 0.0, 3.10), 0.06, dark2, name="console_balise")
            f.cyl(s * 0.70, 0.0, 2.96, 3.30, 0.11, warn2, name="balise")
            for z in (3.03, 3.17):
                f.cyl(s * 0.70, 0.0, z, z + 0.04, 0.113, dark2, bevel=0, name="balise_bande")
            f.sph(s * 0.70, 0.0, 3.34, 0.09, green2, sz=1.2, name="balise_feu")
            f.rod((s * 0.70, 0.0, 3.40), (s * 0.70, 0.0, 3.62), 0.012, dark2, name="balise_antenne")
        halo(f, 0.70, 0, 3.34, "#5CFF4A", 8.0)
        halo(f, -0.70, 0, 3.34, "#5CFF4A", 8.0)


# ------------------------------------------------------------------------------------------------
# Époque 10 · Haute technologie : boîtier lisse sur pieds, dôme, mât de capteurs, voyants bleus
# ------------------------------------------------------------------------------------------------
def e10(ctx, piece):
    shell = paint(ctx, "e10_carenage", "#A8ADB3", rough=0.32, metallic=0.25, grain=0.08, dirt=0.4, k=0.85)
    black = paint(ctx, "e10_noir", "#222428", rough=0.45, metallic=0.3, grain=0.08)
    blue = glow(ctx, "e10_bleu", "#3AA8FF", strength=2.8)
    # 4 pieds télescopiques et patins (le corps se lève : vide sous le boîtier)
    for sa in (-1, 1):
        for sb in (-1, 1):
            a, b = sa * 1.12, sb * 1.12
            ctx.cyl(a, b, 0.0, 0.05, 0.16, black, name="patin")
            ctx.cyl(a, b, 0.05, 0.42, 0.085, black, name="pied_bas")
            ctx.cyl(a, b, 0.42, 0.86, 0.06, shell, name="pied_haut")
            ctx.tor(a, b, 0.42, 0.088, 0.02, blue, name="pied_voyant")
    # boîtier lisse aux arêtes arrondies, joint noir, bandeaux de voyants
    ctx.tbox(-1.0, -1.0, 1.0, 1.0, 0.86, 1.46, shell, bevel=0.11, name="boitier")
    ctx.tbox(-1.015, -1.015, 1.015, 1.015, 1.12, 1.17, black, bevel=0.02, name="joint")
    def leds(a, b, na, nb):
        if na == 0:
            ctx.tbox(-0.50, b - 0.01 * nb, 0.50, b + 0.025 * nb, 1.26, 1.36, blue, bevel=0, name="bandeau")
        else:
            ctx.tbox(a - 0.01 * na, -0.50, a + 0.025 * na, 0.50, 1.26, 1.36, blue, bevel=0, name="bandeau")
    faces4(ctx, 1.0, leds)
    halo(ctx, 0, 1.1, 1.3, "#3AA8FF", 12.0)
    # trépan sous le boîtier (dans le vide), anneau bleu
    ctx.cyl(0, 0, 0.12, 0.86, 0.22, black, name="tige")
    ctx.cyl(0, 0, 0.0, 0.14, 0.22, black, r2=0.06, name="pointe")
    ctx.tor(0, 0, 0.50, 0.23, 0.03, blue, name="anneau")
    # dôme lisse et capsule de capteurs (tour)
    ctx.sph(0, 0, 1.46, 0.70, shell, sz=0.55, name="dome")
    ctx.cyl(0, 0, 1.70, 3.48, 0.23, shell, name="capsule")
    ctx.sph(0, 0, 3.48, 0.23, shell, name="capsule_tete")
    for z in (2.10, 2.80):
        ctx.cyl(0, 0, z, z + 0.07, 0.235, black, bevel=0, name="capsule_bande")
    ctx.cyl(0, 0, 2.45, 2.57, 0.236, blue, bevel=0, name="capsule_voyant")
    o = ctx.S.cylinder(0.10, 0.04, (0, 0, 0), black, ctx.name("optique"), verts=24, bevel_w=0)
    ctx._finish(o, local=Matrix.Rotation(math.pi / 2, 4, "X"), at=ctx.P(0, 0.17, 3.10))
    # mât de capteurs (fin) et antennes fouet
    ctx.rod((0, 0, 3.68), (0, 0, 4.23), 0.03, black, name="mat")
    for z in (3.88, 4.08):
        ctx.sph(0.0, 0.0, z, 0.045, shell, name="capteur")
    ctx.sph(0, 0, 4.25, 0.04, blue, name="mat_feu")
    for s in (-1, 1):
        ctx.rod((s * 0.85, 0.85, 1.46), (s * 0.95, 0.95, 2.35), 0.012, black, name="antenne_fouet")
        ctx.sph(s * 0.95, 0.95, 2.36, 0.025, blue, name="antenne_feu")
    halo(ctx, 0, 0, 2.45, "#3AA8FF", 8.0)
    ctx.beam((0, -0.70, 1.05), (0, CHUTE_OUT, 0.55), 0.42, shell, h=0.10, name="goulotte_carenee")
    ctx.beam((0, -0.75, 1.10), (0, CHUTE_OUT + 0.05, 0.60), 0.44, black, h=0.03, name="goulotte_levre")
    if piece:
        f = ctx.fixed()
        f.level = ctx.level
        white = paint(f, "e10p_blanc", "#C4C7CB", rough=0.3, metallic=0.2, grain=0.06, k=0.85)
        black2 = paint(f, "e10p_noir", "#222428", rough=0.45, metallic=0.3)
        blue2 = glow(f, "e10p_bleu", "#3AA8FF", strength=3.0)
        # parabole tournée vers le ciel, sur pivot, au sommet de la capsule
        f.cyl(0, 0, 3.69, 3.79, 0.06, black2, name="pivot")
        prof = [(0.05, 3.79), (0.12, 3.805), (0.20, 3.83), (0.27, 3.865), (0.32, 3.90), (0.33, 3.92)]
        f.lathe(0, 0, prof, white, seg=48, caps=False, name="parabole")
        f.lathe(0, 0, [(r - 0.012, z + 0.012) for r, z in prof], black2, seg=48, caps=False, name="parabole_creux")
        for t in range(3):
            tt = 2 * math.pi * t / 3 + 0.5
            f.rod((0.30 * math.cos(tt), -0.30 * math.sin(tt) / 1.414, 3.91), (0, 0, 4.09), 0.008, black2, name="pied_source")
        f.sph(0, 0, 4.10, 0.035, blue2, name="source")
        halo(f, 0, 0, 4.03, "#3AA8FF", 6.0)


# ------------------------------------------------------------------------------------------------
# Époque 11 · Titane : tour élancée à ailerons, cadre léger sur pieds en V, lignes bleu-blanc
# ------------------------------------------------------------------------------------------------
def e11(ctx, piece):
    white = paint(ctx, "e11_alliage", "#C9C6BE", rough=0.34, metallic=0.3, grain=0.10, dirt=0.55, k=0.78)
    ti = metal(ctx, "e11_titane", "#8E9AA6", rough=0.30, metallic=0.75, grain=0.12, k=1.0)
    light = glow(ctx, "e11_ligne", "#BFE6FF", strength=2.4)
    # pieds en V aux 4 angles, cadre carré léger à z ≈ 0,85 (vide dessous)
    zf = 0.86
    for sa in (-1, 1):
        for sb in (-1, 1):
            a, b = sa * 1.20, sb * 1.20
            ctx.cyl(a, b, 0.0, 0.05, 0.12, ti, name="patin")
            ctx.beam((a, b, 0.04), (sa * 1.20, sb * 0.78, zf), 0.065, white, name="pied_v")
            ctx.beam((a, b, 0.04), (sa * 0.78, sb * 1.20, zf), 0.065, white, name="pied_v")
    for s in (-1, 1):
        ctx.tbox(-1.22, s * 1.20 - 0.05, 1.22, s * 1.20 + 0.05, zf - 0.05, zf + 0.05, white, bevel=0.015, name="cadre")
        ctx.tbox(s * 1.20 - 0.05, -1.22, s * 1.20 + 0.05, 1.22, zf - 0.05, zf + 0.05, white, bevel=0.015, name="cadre")
        ctx.tbox(-1.0, s * 1.20 - 0.02, 1.0, s * 1.20 + 0.025, zf + 0.05, zf + 0.10, light, bevel=0, name="ligne_cadre")
    # nacelle centrale suspendue par 4 haubans
    ctx.lathe(0, 0, [(0.10, 0.30), (0.32, 0.45), (0.40, 0.70), (0.40, 1.05), (0.30, 1.22)], ti, name="nacelle")
    for sa in (-1, 1):
        for sb in (-1, 1):
            ctx.beam((sa * 1.15, sb * 1.15, zf), (sa * 0.26, sb * 0.26, 1.10), 0.05, white, name="hauban")
    ctx.cyl(0, 0, 0.0, 0.32, 0.08, ti, r2=0.02, name="pointe")
    # flèche élancée (tour)
    prof = [(0.30, 1.20), (0.26, 1.90), (0.20, 2.70), (0.13, 3.40), (0.085, 3.86), (0.0, 4.08)]
    ctx.lathe(0, 0, prof, white, seg=32, name="fleche")
    for z in (1.70, 2.35, 3.00):
        r = 0.30 - (z - 1.2) * 0.075 + 0.006
        ctx.cyl(0, 0, z, z + 0.11, r, light, bevel=0, name="ligne_fleche")
    # 4 ailerons triangulaires (caps diagonaux), pointe balayée vers le bas
    for h in (45.0, 135.0, 225.0, 315.0):
        ctx.fin(0, 0, 1.25, 2.95, 0.88, -0.22, white, h, thick=0.045, name="aileron")
        hh = math.radians(h)
        ctx.beam((0.30 * math.cos(hh), -0.30 * math.sin(hh) / 1.414, 1.95),
                 (0.78 * math.cos(hh), -0.78 * math.sin(hh) / 1.414, 1.10), 0.03, light, h=0.06, name="ligne_aileron")
    halo(ctx, 0, 0.5, 1.6, "#BFE6FF", 10.0)
    halo(ctx, 0, 0, 2.6, "#BFE6FF", 8.0)
    ctx.beam((0, -0.45, 1.10), (0, CHUTE_OUT, 0.62), 0.36, white, h=0.08, name="goulotte_effilee")
    ctx.beam((0, -0.45, 1.16), (0, CHUTE_OUT, 0.68), 0.10, ti, h=0.05, name="goulotte_arete")
    if piece:
        f = ctx.fixed()
        f.level = ctx.level
        ti2 = metal(f, "e11p_titane", "#8E9AA6", rough=0.28, metallic=0.8, k=1.0)
        light2 = glow(f, "e11p_ligne", "#BFE6FF", strength=3.0)
        # flèche-capteur : collier, fût fin, pointe en losange, 3 ailettes
        # (1re version : fût fin et ailettes de 0,24 : 0,08 t² ajoutés, sous la cible 0,10)
        f.tor(0, 0, 3.92, 0.17, 0.04, ti2, name="collier")
        f.lathe(0, 0, [(0.0, 3.90), (0.09, 4.02), (0.10, 4.18), (0.06, 4.30), (0.0, 4.40)], ti2, seg=24,
                name="nacelle_capteur")
        f.rod((0, 0, 4.36), (0, 0, 4.66), 0.02, ti2, name="pointe_capteur")
        for h in (0.0, 120.0, 240.0):
            f.fin(0, 0, 3.90, 4.20, 0.36, -0.12, ti2, h, thick=0.035, name="ailette")
        f.sph(0, -0.06, 4.16, 0.055, light2, name="capteur_feu")
        halo(f, 0, 0, 4.2, "#BFE6FF", 6.0)


# ------------------------------------------------------------------------------------------------
# Époque 12 · Supraconducteurs : tige entourée d'anneaux en lévitation, pylônes noirs, givre
# ------------------------------------------------------------------------------------------------
def e12(ctx, piece):
    black = metal(ctx, "e12_noir", "#26282E", rough=0.30, metallic=0.6, grain=0.08, k=1.2)
    chrome = metal(ctx, "e12_chrome", "#9AA3AD", rough=0.14, metallic=0.95, grain=0.05, dirt=0.25, k=1.0)
    frost = metal(ctx, "e12_givre", "#DDEEFF", rough=0.75, metallic=0.0, grain=0.35, gs=30.0, k=0.78)
    cyan = glow(ctx, "e12_cyan", "#4AF0FF", strength=2.6)
    # 4 pylônes noirs effilés, coiffes chromées, givre au pied ; longerons flottants (interstices)
    for sa in (-1, 1):
        for sb in (-1, 1):
            a, b = sa * CP, sb * CP
            ctx.tfrustum(a - 0.13, b - 0.13, a + 0.13, b + 0.13, 0.0, 0.07, 1.10, black, name="pylone")
            ctx.tfrustum(a - 0.075, b - 0.075, a + 0.075, b + 0.075, 1.10, 0.04, 1.22, chrome, name="coiffe")
            ctx.tfrustum(a - 0.16, b - 0.16, a + 0.16, b + 0.16, 0.0, 0.03, 0.16, frost, name="givre")
    for s in (-1, 1):
        ctx.tbox(-0.98, s * CP - 0.05, 0.98, s * CP + 0.05, 0.86, 0.96, black, bevel=0.015, name="longeron_flottant")
        ctx.tbox(s * CP - 0.05, -0.98, s * CP + 0.05, 0.98, 0.86, 0.96, black, bevel=0.015, name="longeron_flottant")
        ctx.tbox(-0.80, s * CP - 0.012, 0.80, s * CP + 0.02, 0.80, 0.84, cyan, bevel=0, name="interstice")
    # tige centrale noire, segments chromés, collier de givre
    ctx.cyl(0, 0, 0.0, 3.82, 0.17, black, name="tige")
    ctx.cyl(0, 0, 0.0, 0.40, 0.25, frost, name="collier_givre")
    for z in (1.00, 1.75, 2.55, 3.30):
        ctx.cyl(0, 0, z, z + 0.10, 0.185, chrome, name="segment")
    ctx.cyl(0, 0, 3.82, 4.12, 0.17, chrome, r2=0.0, name="fuseau")
    # 3 anneaux chromés horizontaux en lévitation, liseré cyan
    for z, R in ((1.30, 0.98), (2.12, 0.76), (2.90, 0.56)):
        ctx.tor(0, 0, z, R, 0.07, chrome, mseg=14, name="anneau")
        ctx.tor(0, 0, z - 0.015, R - 0.055, 0.03, cyan, mseg=8, name="anneau_cyan")
    halo(ctx, 0, 0.5, 1.3, "#4AF0FF", 10.0)
    halo(ctx, 0, 0, 2.5, "#4AF0FF", 8.0)
    # goulotte flottante (sans appui)
    ctx.beam((0, -0.62, 0.95), (0, CHUTE_OUT, 0.62), 0.40, chrome, h=0.06, name="goulotte_flottante")
    ctx.beam((0, -0.62, 0.90), (0, CHUTE_OUT, 0.57), 0.30, cyan, h=0.02, name="goulotte_champ")
    if piece:
        f = ctx.fixed()
        f.level = ctx.level
        chrome2 = metal(f, "e12p_chrome", "#9AA3AD", rough=0.12, metallic=0.95, grain=0.05, dirt=0.2)
        cyan2 = glow(f, "e12p_cyan", "#4AF0FF", strength=3.0)
        f.tor(0, 0, 3.98, 0.42, 0.055, chrome2, mseg=12, name="anneau_sommet")
        f.tor(0, 0, 3.965, 0.375, 0.025, cyan2, mseg=8, name="anneau_sommet_cyan")
        halo(f, 0, 0, 3.98, "#4AF0FF", 6.0)


# ------------------------------------------------------------------------------------------------
# Époque 13 · Fusion : coque sphérique sur trépied, tore de plasma autour, tige
# ------------------------------------------------------------------------------------------------
def e13(ctx, piece):
    cer = metal(ctx, "e13_ceramique", "#D9D6CF", rough=0.32, metallic=0.05, grain=0.10, dirt=0.55, k=0.75)
    copper = metal(ctx, "e13_cuivre", "#B0703A", rough=0.26, metallic=0.85, grain=0.15, k=0.9)
    plasma = glow(ctx, "e13_plasma", "#FF4FD8", strength=3.0)
    core = glow(ctx, "e13_coeur", "#FF9A3A", strength=3.0)
    # trépied (repère N : pieds au nord, sud-ouest, sud-est)
    zc, R = 1.92, 0.80
    for t in (90.0, 210.0, 330.0):
        tt = math.radians(t)
        foot = (1.15 * math.cos(tt), -1.15 * math.sin(tt) / 1.414 * 1.25, 0.0)
        top = (0.42 * math.cos(tt), -0.42 * math.sin(tt) / 1.414, zc - 0.62)
        ctx.rod(foot, top, 0.065, cer, verts=16, name="jambe")
        ctx.cyl(foot[0], foot[1], 0.0, 0.06, 0.13, copper, name="patin")
        ctx.tor(foot[0] + (top[0] - foot[0]) * 0.5, foot[1] + (top[1] - foot[1]) * 0.5, zc * 0.4, 0.075, 0.02, copper,
                name="jambe_bague")
    # coque sphérique, coutures de cuivre
    ctx.sph(0, 0, zc, R, cer, seg=48, rings=24, name="coque")
    for dz, rr in ((0.40, 0.69), (-0.40, 0.69)):
        ctx.tor(0, 0, zc + dz, rr + 0.012, 0.025, copper, name="couture")
    # tore de plasma équatorial, pinces de cuivre
    ctx.tor(0, 0, zc, 1.26, 0.11, plasma, mseg=16, name="tore_plasma")
    for h in (45.0, 135.0, 225.0, 315.0):
        hh = math.radians(h)
        ctx.beam((0.78 * math.cos(hh), -0.78 * math.sin(hh) / 1.414, zc), (1.40 * math.cos(hh),
                 -1.40 * math.sin(hh) / 1.414, zc), 0.06, copper, h=0.08, name="pince")
    halo(ctx, 0, 0.9, zc, "#FF4FD8", 16.0)
    halo(ctx, 0, -0.9, zc, "#FF4FD8", 8.0)
    # trépan sous la coque : cône de cuivre à pointe de plasma
    ctx.cyl(0, 0, 0.12, zc - R + 0.05, 0.17, copper, r2=0.07, name="trepan")
    ctx.sph(0, 0, 0.10, 0.08, core, name="pointe_plasma")
    halo(ctx, 0, 0, 0.12, "#FF9A3A", 6.0)
    # tige au-dessus de la coque
    ctx.cyl(0, 0, zc + R - 0.08, 4.02, 0.15, cer, name="tige")
    for z in (3.10, 3.50, 3.85):
        ctx.cyl(0, 0, z, z + 0.07, 0.165, copper, name="tige_bague")
    ctx.sph(0, 0, 4.02, 0.15, copper, sz=0.6, name="tige_tete")
    # goulotte : tube de céramique de la coque vers le nord
    ctx.rod((0, -0.45, 1.55), (0, CHUTE_OUT + 0.1, 0.62), 0.13, cer, verts=20, name="goulotte_tube")
    ctx.cyl(0, CHUTE_OUT + 0.06, 0.50, 0.66, 0.15, copper, name="goulotte_bec")
    if piece:
        f = ctx.fixed()
        f.level = ctx.level
        copper2 = metal(f, "e13p_cuivre", "#B0703A", rough=0.24, metallic=0.85, k=0.9)
        plasma2 = glow(f, "e13p_plasma", "#FF4FD8", strength=3.2)
        # injecteur au sommet : couronne de cuivre, 3 buses inclinées, dard de plasma
        f.tor(0, 0, 4.11, 0.26, 0.05, copper2, name="injecteur_couronne")
        f.cyl(0, 0, 4.04, 4.26, 0.07, copper2, name="injecteur_corps")
        for t in (90.0, 210.0, 330.0):
            tt = math.radians(t)
            f.rod((0.22 * math.cos(tt), -0.22 * math.sin(tt) / 1.414, 4.11),
                  (0.36 * math.cos(tt), -0.36 * math.sin(tt) / 1.414, 4.38), 0.03, copper2, name="buse")
            f.sph(0.36 * math.cos(tt), -0.36 * math.sin(tt) / 1.414, 4.40, 0.065, plasma2, name="buse_feu")
        f.cyl(0, 0, 4.26, 4.56, 0.03, plasma2, r2=0.0, name="dard")
        halo(f, 0, 0, 4.31, "#FF4FD8", 8.0)


# ------------------------------------------------------------------------------------------------
# Époque 14 · Orbite : panneaux dorés en ailes, câble-mât, balises
# ------------------------------------------------------------------------------------------------
def e14(ctx, piece):
    gold = metal(ctx, "e14_or", "#C9A23A", rough=0.22, metallic=0.9, grain=0.45, gs=14.0, dirt=0.35, k=0.85)
    white = paint(ctx, "e14_blanc", "#CFCBC2", rough=0.35, metallic=0.2, grain=0.08, dirt=0.5, k=0.8)
    cells = ctx.S.mat_emissive(ctx.name("e14_cellules"), srgb("#2F6BFF"), strength=0.35, base=srgb("#1E2A55"))
    red = glow(ctx, "e14_balise", "#FF2A2A", strength=3.2)
    # jambes en treillis blanc des angles vers le tambour (vide dessous)
    for sa in (-1, 1):
        for sb in (-1, 1):
            a, b = sa * 1.15, sb * 1.15
            ctx.cyl(a, b, 0.0, 0.06, 0.12, gold, name="patin")
            ctx.beam((a, b, 0.05), (sa * 0.30, sb * 0.30, 0.95), 0.07, white, name="jambe")
            ctx.beam((a, b, 0.05), (sa * 0.55, sb * 0.55, 0.62), 0.04, white, name="jambe_jambette")
    for s in (-1, 1):
        ctx.beam((s * 0.80, -0.80, 0.42), (s * 0.80, 0.80, 0.42), 0.035, white, name="ceinture")
        ctx.beam((-0.80, s * 0.80, 0.42), (0.80, s * 0.80, 0.42), 0.035, white, name="ceinture")
    # tambour blanc ceint de feuille d'or froissée, réservoirs dorés
    ctx.cyl(0, 0, 0.90, 2.10, 0.40, white, name="tambour")
    ctx.cyl(0, 0, 1.15, 1.85, 0.415, gold, name="feuille_or")
    ctx.cyl(0, 0, 2.10, 2.20, 0.30, white, name="tambour_chapeau")
    ctx.cyl(0, 0, 0.40, 0.92, 0.12, gold, r2=0.05, name="trepan")
    for s in (-1, 1):
        ctx.sph(s * 0.52, 0.55, 0.95, 0.18, gold, name="reservoir")
    # 2 ailes de panneaux dorés (est / ouest dans le repère N), inclinées vers le sud
    for s in (-1, 1):
        ctx.beam((s * 0.40, 0.0, 1.70), (s * 0.60, 0.0, 1.70), 0.06, white, name="bras_aile")
        for k, (a0, a1) in enumerate(((0.58, 1.05), (1.08, 1.56))):
            ac = s * (a0 + a1) / 2
            w = a1 - a0
            tilt = Matrix.Rotation(math.radians(28), 4, "X")
            ctx.box3(ac, 0.0, 1.72, (w, 0.62, 0.025), gold, bevel=0.004, local=tilt, name="panneau_cadre")
            ctx.box3(ac, 0.0, 1.735, (w - 0.05, 0.56, 0.012), cells, bevel=0, local=tilt, name="panneau_cellules")
            for g in (-0.14, 0.14):
                ctx.box3(ac, 0.0, 1.745, (w - 0.05, 0.012, 0.006), gold, bevel=0,
                         local=tilt @ Matrix.Translation((0, g, 0)), name="panneau_grille")
        ctx.sph(s * 1.58, 0.0, 1.76, 0.05, red, name="balise_aile")
    halo(ctx, 0, 0.3, 1.8, "#2F6BFF", 8.0)
    # câble-mât : colonne blanche, haubans vers les bouts d'ailes, balise rouge au sommet
    ctx.cyl(0, 0, 2.20, 4.10, 0.10, white, name="mat")
    for z in (2.80, 3.40):
        ctx.cyl(0, 0, z, z + 0.06, 0.11, gold, name="mat_bague")
    ctx.sph(0, 0, 4.14, 0.075, red, name="balise")
    for s in (-1, 1):
        ctx.rod((0, 0, 3.98), (s * 1.50, 0.0, 1.80), 0.008, gold, name="hauban")
    halo(ctx, 0, 0, 4.14, "#FF2A2A", 6.0)
    ctx.beam((0, -0.40, 1.00), (0, CHUTE_OUT, 0.60), 0.40, gold, h=0.06, name="goulotte_or")
    ctx.beam((0, -0.40, 1.06), (0, CHUTE_OUT, 0.66), 0.42, white, h=0.025, name="goulotte_bord")
    if piece:
        f = ctx.fixed()
        f.level = ctx.level
        white2 = paint(f, "e14p_blanc", "#CFCBC2", rough=0.3, metallic=0.2, k=0.8)
        gold2 = metal(f, "e14p_or", "#C9A23A", rough=0.22, metallic=0.9, grain=0.4, gs=14.0, k=0.85)
        red2 = glow(f, "e14p_balise", "#FF2A2A", strength=3.0)
        # parabole sur console au flanc du mât, tournée vers le ciel (sud-ouest)
        f.beam((0.0, 0.0, 3.35), (-0.42, 0.0, 3.38), 0.05, white2, name="console")
        tilt = Matrix.Rotation(math.radians(25), 4, "X")
        prof = [(0.03, 0.0), (0.12, 0.012), (0.22, 0.04), (0.30, 0.08), (0.34, 0.11)]
        f.lathe(-0.48, 0.0, [(r, z) for r, z in prof], white2, seg=48, caps=False, z_base=3.38, local=tilt,
                name="parabole")
        f.lathe(-0.48, 0.0, [(r - 0.01, z + 0.01) for r, z in prof], gold2, seg=48, caps=False, z_base=3.38,
                local=tilt, name="parabole_or")
        f.rod((-0.48, 0.0, 3.40), (-0.48, -0.08, 3.62), 0.01, white2, name="source_pied")
        f.sph(-0.48, -0.08, 3.63, 0.035, red2, name="source")
        halo(f, -0.48, 0.0, 3.6, "#FF2A2A", 4.0)


# ------------------------------------------------------------------------------------------------
# Époque 15 · Légende : plate-forme flottante, tour-flèche, couronne de petites flèches, or blanc
# ------------------------------------------------------------------------------------------------
def e15(ctx, piece):
    wgold = metal(ctx, "e15_or_blanc", "#E8DCB0", rough=0.24, metallic=0.75, grain=0.12, dirt=0.55, k=0.62)
    nacre = paint(ctx, "e15_nacre", "#D8D2C8", rough=0.26, metallic=0.25, grain=0.10, dirt=0.5, k=0.62)
    light = glow(ctx, "e15_lumiere", "#FFF2C0", strength=2.6)
    crys = ctx.S.mat_emissive(ctx.name("e15_cristal"), srgb("#FFF2C0"), strength=0.5, base=srgb("#CFE4F0"))
    # plate-forme flottante (aucun appui) : ANNEAU octogonal ajouré au centre (Q8 : vides ; 1re version
    # pleine : IoU(niveau 1, niveau 30) = 0,47 en pose N, au-dessus de la cible 0,45) ; coussin de lumière
    zp0, zp1 = 0.84, 0.96
    ring = [(0.94, 0.78), (1.30, zp0), (1.32, zp1 - 0.04), (1.26, zp1), (0.82, zp1), (0.79, 0.90), (0.94, 0.78)]
    ctx.lathe(0, 0, ring, nacre, seg=8, phase=math.pi / 8, smooth_deg=None, caps=False, name="plateforme")
    ctx.lathe(0, 0, [(1.335, zp0 + 0.02), (1.335, zp1 - 0.05)], wgold, seg=8, phase=math.pi / 8, caps=False,
              smooth_deg=None, name="plateforme_bande")
    ctx.tor(0, 0, 0.50, 0.66, 0.045, light, name="coussin")
    # trépan de lumière vers le sol
    ctx.cyl(0, 0, 0.04, 0.52, 0.03, light, r2=0.16, name="trepan_lumiere")
    halo(ctx, 0, 0, 0.45, "#FFF2C0", 16.0)
    # 4 obélisques flottants aux angles (les « 4 montants » de l'identité)
    for sa in (-1, 1):
        for sb in (-1, 1):
            a, b = sa * 1.22, sb * 1.22
            ctx.lathe(a, b, [(0.09, 0.22), (0.11, 0.30), (0.07, 1.05), (0.0, 1.30)], wgold, seg=4,
                      smooth_deg=None, name="obelisque")
            ctx.sph(a, b, 0.14, 0.045, light, name="obelisque_feu")
    # tour-flèche centrale
    # tour-flèche centrale, elle aussi flottante (pointe vers le bas), tenue par 4 rayons
    prof = [(0.0, 0.46), (0.30, 0.72), (0.44, zp1), (0.40, 1.20), (0.30, 1.60), (0.24, 2.40), (0.17, 3.30),
            (0.10, 4.12), (0.0, 4.67)]
    ctx.lathe(0, 0, prof, wgold, seg=8, phase=math.pi / 8, smooth_deg=None, name="fleche")
    for z, r in ((1.62, 0.31), (2.50, 0.235), (3.40, 0.165)):
        ctx.tor(0, 0, z, r, 0.03, light, name="collier_lumiere")
    for k in range(4):
        t = math.pi / 4 + k * math.pi / 2
        ctx.beam((0.40 * math.cos(t), -0.40 * math.sin(t) / 1.414, zp1 - 0.04),
                 (0.86 * math.cos(t), -0.86 * math.sin(t) / 1.414, zp1 - 0.04), 0.06, wgold, h=0.05, name="rayon")
    # couronne de petites flèches autour de la base
    for i in range(8):
        t = 2 * math.pi * (i + 0.5) / 8
        hgt = 1.95 if i % 2 == 0 else 1.62
        a, b = 1.04 * math.cos(t), -1.04 * math.sin(t) / 1.414
        ctx.lathe(a, b, [(0.08, zp1), (0.06, hgt - 0.35), (0.0, hgt)], wgold, seg=4, smooth_deg=None,
                  name="petite_fleche")
        ctx.crystal((a, b, hgt - 0.38), (math.cos(t) * 0.25, math.sin(t) * 0.25, 1.0), 0.30, 0.045, crys,
                    name="eclat")
    halo(ctx, 0, 0.6, 1.4, "#FFF2C0", 12.0)
    halo(ctx, 0, 0, 3.0, "#FFF2C0", 8.0)
    # goulotte flottante
    ctx.beam((0, -0.75, 0.90), (0, CHUTE_OUT, 0.65), 0.38, wgold, h=0.05, name="goulotte_flottante")
    ctx.beam((0, -0.75, 0.85), (0, CHUTE_OUT, 0.60), 0.26, light, h=0.02, name="goulotte_lumiere")
    if piece:
        f = ctx.fixed()
        f.level = ctx.level
        light2 = glow(f, "e15p_halo", "#FFF2C0", strength=3.2)
        wgold2 = metal(f, "e15p_or_blanc", "#E8DCB0", rough=0.22, metallic=0.75, k=0.62)
        f.tor(0, 0, 3.78, 0.46, 0.045, light2, mseg=12, name="halo")
        f.tor(0, 0, 3.78, 0.53, 0.018, wgold2, mseg=8, name="halo_cercle")
        f.tor(0, 0, 4.02, 0.30, 0.03, light2, rot=(0.35, 0.0, 0.0), mseg=10, name="halo_incline")
        halo(f, 0, 0, 3.81, "#FFF2C0", 10.0)


BUILDERS = {2: e02, 3: e03, 4: e04, 5: e05, 6: e06, 7: e07, 8: e08, 9: e09, 10: e10, 11: e11, 12: e12, 13: e13,
            14: e14, 15: e15}


def build_level(ctx, level):
    """Construit le niveau `level` (2 à 30) dans la direction du contexte."""
    ctx.level = level
    e = (level + 1) // 2
    piece = level % 2 == 0
    if e == 1:
        piece_e01(ctx)       # niveau 2 : pièce seule, posée sur le sprite vanilla (masque au post-traitement)
    else:
        BUILDERS[e](ctx, piece)
    if e <= 2:
        # époques 1 et 2 : « de jour, aucune lueur » (bible §5) ; lanterne et fentes de forge ne
        # s'allument que dans la couche halo (nuit) : émission réduite dans la passe principale
        for m in bpy.data.materials:
            if m.get("fo_kind") == "emissive":
                m["fo_day_gain"] = DAY_GAIN_E12
