"""Tourelle laser, lot V3 phase 1 : modélisation paramétrique des 15 époques (s'exécute DANS Blender).

    build(S, C, level, part, heading_deg) -> dict

part = "base" : socle de l'époque (+ pièce si niveau pair) ; niveau 2 = pièce SEULE (posée sur le vanilla).
part = "head" : tête « prepared » de l'époque, cap heading_deg (0 = nord, 90 = est...), avec le socle de
               l'époque en CACHE (holdout) : ce qui est devant la tête la troue au pixel, comme en jeu
               (la tête, couche object, est dessinée par-dessus le socle, couche lower-object).

Conventions (tools/render/README.md, CALIBRATION §2) : 1 unité = largeur d'une tuile, +X est, +Y nord,
+Z haut, origine = position de l'entité au sol ; une tuile de jeu vers le sud = 1,414 unité en Y.
Repère écran (tuiles) : x = X ; y = -0,7071 (Y + Z). La tête est modélisée lentille vers +Y (nord),
pivot sur l'axe Z, puis tournée du cap demandé.

Chaque époque suit sa fiche (docs/DESIGN_EPOQUES.md §5, colonne Laser) : ère, signature commune (Q10),
matériaux et palette (§1.5), lumière (§1.6). La pièce paire se place DEVANT le socle (zone toujours
visible, F46 recalculée par measure_laser.py avec la tête de l'époque).
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import laser_design as D  # noqa: E402

T = 1.0 / math.cos(math.radians(45.0))   # une tuile vers le sud, en unités Blender (Y)


# ================================================================================================
# Contexte de construction
# ================================================================================================
class Ctx:
    def __init__(self, S, C, level):
        self.S, self.C, self.level = S, C, level
        self.e = D.epoch_of(level)
        self.head = []        # objets de la tête (tournés)
        self.base = []        # objets du socle (et de la pièce)
        self.back = []        # niveau 2 : objets DERRIÈRE le socle vanilla (masqués par son alpha)
        self.halos = []       # (loc locale, couleur, puissance relative, appartient à la tête)
        self.mats = {}
        self.cur = None       # liste courante où ranger les objets créés
        self.zp = PIVOT.get(self.e, 1.2)   # haut de la colonne fixe = bas de la tête (réglé sur O cible, §4)

    # -- rangement --
    def add(self, o):
        if o is not None and self.cur is not None:
            self.cur.append(o)
        return o


def _adopt(cx, o, mat, name):
    for c in list(o.users_collection):
        c.objects.unlink(o)
    cx.S.piece_collection().objects.link(o)
    o.name = name
    if mat is not None:
        o.data.materials.clear()
        o.data.materials.append(mat)
    return cx.add(o)


# ================================================================================================
# Primitives (en plus de fo_scene : box, cylinder, torus, sphere, rivet_ring)
# ================================================================================================
def box(cx, size, loc, mat, name, bevel=0.012, rot=None):
    o = cx.S.box(size, loc, mat, name, bevel_w=bevel)
    if rot:
        o.rotation_euler = rot
    return cx.add(o)


def cyl(cx, r, h, loc, mat, name, verts=32, rot=(0, 0, 0), bevel=0.006, r2=None, caps=True):
    return cx.add(cx.S.cylinder(r, h, loc, mat, name, verts=verts, rot=rot, bevel_w=bevel, radius2=r2, caps=caps))


def tor(cx, R, r, loc, mat, name, rot=(0, 0, 0), seg=48, mseg=10):
    return cx.add(cx.S.torus(R, r, loc, mat, name, rot=rot, major_seg=seg, minor_seg=mseg))


def sph(cx, r, loc, mat, name, seg=24, rings=12, scale=None):
    o = cx.S.sphere(r, loc, mat, name, seg=seg, rings=rings)
    if scale:
        o.scale = scale
    return cx.add(o)


def mesh(cx, verts, faces, mat, name, smooth=None, bevel=0.0, loc=(0, 0, 0), rot=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    me.validate()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.update()
    o = bpy.data.objects.new(name, me)
    o.location = loc
    o.rotation_euler = rot
    _adopt(cx, o, mat, name)
    if smooth:
        cx.S.smooth(o, smooth)
    if bevel:
        cx.S.bevel(o, bevel)
    return o


def lathe(cx, prof, mat, name, seg=32, loc=(0, 0, 0), rot=(0, 0, 0), smooth=60, phase=0.0):
    """Révolution autour de Z d'un profil [(r, z), ...] (r = 0 : pointe)."""
    verts, faces, rings = [], [], []
    for (r, z) in prof:
        if r < 1e-6:
            rings.append([len(verts)])
            verts.append((0.0, 0.0, z))
        else:
            idx = []
            for i in range(seg):
                a = phase + 2 * math.pi * i / seg
                idx.append(len(verts))
                verts.append((r * math.cos(a), r * math.sin(a), z))
            rings.append(idx)
    for k in range(len(rings) - 1):
        A, B = rings[k], rings[k + 1]
        if len(A) == 1 and len(B) == 1:
            continue
        if len(A) == 1:
            faces += [(A[0], B[(i + 1) % seg], B[i]) for i in range(seg)]
        elif len(B) == 1:
            faces += [(A[i], A[(i + 1) % seg], B[0]) for i in range(seg)]
        else:
            faces += [(A[i], A[(i + 1) % seg], B[(i + 1) % seg], B[i]) for i in range(seg)]
    if len(rings[0]) > 1:
        faces.append(tuple(reversed(rings[0])))
    if len(rings[-1]) > 1:
        faces.append(tuple(rings[-1]))
    return mesh(cx, verts, faces, mat, name, smooth=smooth, loc=loc, rot=rot)


def loft(cx, b, t, z0, z1, mat, name, bevel=0.01, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Tronc de pyramide rectangulaire : b, t = (cx, cy, w, d) en bas (z0) et en haut (z1)."""
    def rect(c, z):
        x, y, w, d = c
        return [(x - w / 2, y - d / 2, z), (x + w / 2, y - d / 2, z), (x + w / 2, y + d / 2, z), (x - w / 2, y + d / 2, z)]
    v = rect(b, z0) + rect(t, z1)
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return mesh(cx, v, f, mat, name, bevel=bevel, loc=loc, rot=rot)


def plate(cx, pts, thick, mat, name, axis="Y", loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.004):
    """Polygone 2D (u, v) extrudé de `thick` : axis = normale ('Y' : plan XZ, 'X' : plan YZ, 'Z' : plan XY)."""
    n = len(pts)
    def P(u, v, w):
        if axis == "Y":
            return (u, w, v)
        if axis == "X":
            return (w, u, v)
        return (u, v, w)
    verts = [P(u, v, -thick / 2) for (u, v) in pts] + [P(u, v, thick / 2) for (u, v) in pts]
    faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return mesh(cx, verts, faces, mat, name, bevel=bevel, loc=loc, rot=rot)


def crystal(cx, r, h, loc, mat, name, tilt=(0, 0), sides=6, base_frac=0.18, spin=0.0):
    """Cristal : prisme à pointe (bipyramide allongée), incliné de tilt = (rx, ry) radians."""
    prof = [(0.0, -base_frac * h), (r, 0.0), (r * 0.92, h * 0.62), (0.0, h)]
    return lathe(cx, prof, mat, name, seg=sides, loc=loc, rot=(tilt[0], tilt[1], spin), smooth=None)


def rivet_row(cx, p0, p1, n, rr, mat, name):
    objs = []
    for i in range(n):
        t = (i + 0.5) / n
        p = tuple(p0[k] + (p1[k] - p0[k]) * t for k in range(3))
        objs.append(cx.S.sphere(rr, p, mat, "%s_%d" % (name, i), seg=8, rings=4))
    o = cx.S.join(objs, name)
    return cx.add(o)


def rivet_ring(cx, R, z, n, rr, mat, name, center=(0.0, 0.0), phase=0.0):
    return cx.add(cx.S.rivet_ring(R, z, n, rr, mat, center=center, name=name, phase=phase))


def ring_y(cx, R, r, y, z, mat, name, x=0.0, seg=40):
    """Tore dont l'axe est Y (anneau autour d'un corps orienté vers l'avant)."""
    return tor(cx, R, r, (x, y, z), mat, name, rot=(math.pi / 2, 0, 0), seg=seg)


def tube_y(cx, r, y0, y1, z, mat, name, x=0.0, verts=32, r2=None, caps=True, bevel=0.006):
    """Cylindre d'axe Y entre y0 et y1 (r2 : rayon à y1)."""
    h = abs(y1 - y0)
    yc = (y0 + y1) / 2
    # cylindre d'axe Z tourné de -90° autour de X : +Z -> +Y
    o = cyl(cx, r, h, (x, yc, z), mat, name, verts=verts, rot=(-math.pi / 2, 0, 0), bevel=bevel, r2=r2, caps=caps)
    return o


def tube_x(cx, r, x0, x1, y, z, mat, name, verts=32, caps=True, bevel=0.006):
    h = abs(x1 - x0)
    return cyl(cx, r, h, ((x0 + x1) / 2, y, z), mat, name, verts=verts, rot=(0, math.pi / 2, 0), bevel=bevel, caps=caps)


def strut(cx, p0, p1, r, mat, name, verts=10):
    """Barre cylindrique entre deux points."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    o = cyl(cx, r, d.length, tuple((a + b) / 2), mat, name, verts=verts, bevel=0)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = d.normalized().to_track_quat("Z", "Y")
    return o


def ty(t):
    """Tuiles de jeu vers le sud -> Y Blender."""
    return -t * T


# ================================================================================================
# Matériaux par époque (couleurs : bible §1.5 ; gain d'albédo réglé sur la luminance médiane cible)
# ================================================================================================
def metal(cx, key, hexc, gain=1.0, rough=0.38, metallic=0.75, grain=0.18, rust=None, rust_amount=0.0, dirt=0.5, seed=1.0,
          grain_scale=55.0):
    k = "m_%s" % key
    if k not in cx.mats:
        col = D.hexlin(hexc, gain * EPOCH_GAIN.get(cx.e, 1.0))
        rcol = D.hexlin(rust, 1.0) if rust else None
        cx.mats[k] = cx.S.mat_metal("e%02d_%s" % (cx.e, key), col, rough=rough, metallic=metallic, grain=grain,
                                    grain_scale=grain_scale, rust=rcol, rust_amount=rust_amount, dirt=dirt, seed=seed)
    return cx.mats[k]


def flat(cx, key, hexc, gain=1.0, rough=0.6, metallic=0.0):
    k = "f_%s" % key
    if k not in cx.mats:
        cx.mats[k] = cx.S.mat_flat("e%02d_%s" % (cx.e, key), D.hexlin(hexc, gain * EPOCH_GAIN.get(cx.e, 1.0)),
                                   rough=rough, metallic=metallic)
    return cx.mats[k]


def glass(cx, key, hexc, gain=1.0, rough=0.08):
    """Verre rendu OPAQUE (bible §1.5, époque 8 : alpha ≥ 0,5 pour compter dans la silhouette)."""
    k = "g_%s" % key
    if k not in cx.mats:
        m = cx.S.mat_flat("e%02d_%s" % (cx.e, key), D.hexlin(hexc, gain), rough=rough, metallic=0.0)
        p = m.node_tree.nodes["Principled BSDF"]
        if "Coat Weight" in p.inputs:
            p.inputs["Coat Weight"].default_value = 0.6
            p.inputs["Coat Roughness"].default_value = 0.05
        cx.mats[k] = m
    return cx.mats[k]


def emis(cx, key, hexc=None, strength=1.3, base=(0.05, 0.03, 0.02)):
    """Zone lumineuse : de jour (draw_as_glow) dès l'époque 3 ; aux époques 1-2, de nuit seulement."""
    k = "e_%s" % key
    if k not in cx.mats:
        col = D.hexlin(hexc or D.EMISSIVE[cx.e])
        if cx.e in D.NIGHT_ONLY:
            cx.mats[k] = mat_night(cx, "e%02d_%s" % (cx.e, key), col, strength, base)
        else:
            cx.mats[k] = cx.S.mat_emissive("e%02d_%s" % (cx.e, key), col, strength=strength, base=base)
    return cx.mats[k]


def mat_night(cx, name, color, strength, base):
    """Émissif de NUIT seulement : sombre dans la couche principale, éteint dans la lueur, allumé dans le halo."""
    m = cx.S.mat_flat(name, base, rough=0.6)
    m["fo_kind"] = "night"
    m["fo_emit_color"] = list(color)
    m["fo_emit_strength"] = strength
    return m


# hauteur du pivot et échelle de la tête : données pures dans laser_design.py (partagées avec le manifeste)
PIVOT = D.PIVOT
HEAD_SCALE = D.HEAD_SCALE

# gain d'albédo par époque : réglé par mesure de la luminance médiane du corps (measure_laser.py, cible §1.5)
EPOCH_GAIN = {}
GAIN_FILE = os.path.join(HERE, "albedo_gain.txt")
if os.path.exists(GAIN_FILE):
    with open(GAIN_FILE, encoding="utf-8") as _f:
        for _line in _f:
            _p = _line.split("#")[0].split()
            if len(_p) == 2:
                EPOCH_GAIN[int(_p[0])] = float(_p[1])


def halo(cx, loc, power=1.0, color=None):
    """Source du halo de nuit (passe « light ») ; la couleur par défaut est l'émissif de l'époque."""
    cx.halos.append({"loc": tuple(loc), "color": D.hexlin(color or D.EMISSIVE[cx.e]), "power": power,
                     "head": cx.cur is cx.head})


# ================================================================================================
# Époque 1 · Pionnier (niveau 2 : pièce seule posée sur le vanilla)
# ================================================================================================
def piece_e01(cx):
    sand = metal(cx, "toile", "#8A7A5A", gain=1.25, rough=0.85, metallic=0.0, grain=0.35, grain_scale=30.0, dirt=0.6,
                 rust="#6B4F35", rust_amount=0.45, seed=11.0)
    sand2 = metal(cx, "toile2", "#7A6A4C", gain=1.25, rough=0.9, metallic=0.0, grain=0.35, grain_scale=30.0, dirt=0.6,
                  rust="#5A4632", rust_amount=0.5, seed=12.0)
    cable = flat(cx, "cable", "#1C1A18", rough=0.45)
    earth = metal(cx, "terre", "#4A3C2C", gain=1.0, rough=1.0, metallic=0.0, grain=0.45, grain_scale=25.0, dirt=0.4, seed=13.0)
    wood = metal(cx, "bois", "#6B4F35", gain=1.2, rough=0.8, metallic=0.0, grain=0.3, grain_scale=20.0, dirt=0.5, seed=14.0)
    # muret de sacs de sable en arc devant le socle : 2 rangs ; le bord avant dépasse de 0,15 tuile au sud
    bags = []
    R0 = 1.18                       # rayon (unités) du centre du muret, ellipse vue
    for row in range(2):
        n = 9 - row
        for i in range(n):
            a = math.radians(-160 + (140.0 * (i + 0.5 * row) / (n - 1 + 0.5 * row)))
            x = 0.92 * math.cos(a) * R0 / 1.18
            y = math.sin(a) * R0
            z = 0.055 + row * 0.095
            jitter = ((i * 7 + row * 3) % 5 - 2) * 0.012
            o = cx.S.box((0.27, 0.15, 0.10), (x, y + jitter, z), sand if (i + row) % 2 else sand2, "sac_%d_%d" % (row, i),
                         bevel_w=0)
            cx.S.bevel(o, 0.04, segments=3)
            o.rotation_euler = (0.03 * ((i % 3) - 1), 0.02 * ((i % 2) * 2 - 1), a + math.pi / 2 + 0.06 * ((i % 3) - 1))
            bags.append(o)
            # derrière le socle (bord avant du socle vanilla ≈ 0,62 tuile au sud) : masqué par l'alpha vanilla
            if y > ty(0.62):
                cx.back.append(o)
            cx.add(o)
    # câble d'alimentation : sort de sous le socle (derrière : masqué), court en tranchée vers le sud-est
    cx.cur, prev = cx.base, cx.cur
    pts = [(0.30, ty(0.15), 0.035), (0.42, ty(0.55), 0.03), (0.50, ty(0.85), 0.028), (0.56, ty(1.17), 0.028)]
    for k in range(len(pts) - 1):
        o = strut(cx, pts[k], pts[k + 1], 0.032, cable, "cable_%d" % k)
        if pts[k][1] > ty(0.62):
            cx.back.append(o)
    # tranchée : levées de terre de part et d'autre du câble (au-delà du socle)
    for side in (-1, 1):
        o = loft(cx, (0.0, 0.0, 0.07, 0.36 * T), (0.0, 0.0, 0.02, 0.33 * T), 0.0, 0.035, earth, "levee_%d" % side,
                 bevel=0.008, loc=(0.53 + side * 0.075, ty(1.0), 0.0))
    # piquet de bois qui tient le câble au bord
    cyl(cx, 0.022, 0.20, (0.66, ty(1.12), 0.10), wood, "piquet", verts=8, bevel=0.003)
    # lanterne à huile du kit d'époque 1 (bible §5), allumée la NUIT seulement (#FFB060) : halo de nuit du niveau 2
    # (D2-3) ; sur un piquet devant le muret, au sud-ouest (jamais derrière le socle vanilla)
    iron = metal(cx, "fer_brut", "#5A5048", gain=1.2, rough=0.5, metallic=0.6, rust="#6B4F35", rust_amount=0.4, seed=15.0)
    # verre ambré clair même éteint (lisible de jour) ; taille ×1,7 après l'aperçu (verre de 6 px hr : illisible)
    lamp = emis(cx, "lanterne", "#FFB060", strength=1.2, base=(0.55, 0.36, 0.12))
    px, py = -0.80, ty(0.95)
    cyl(cx, 0.03, 0.62, (px, py, 0.31), wood, "lanterne_piquet", verts=8, bevel=0.004)
    box(cx, (0.20, 0.035, 0.035), (px + 0.08, py, 0.60), wood, "lanterne_potence", bevel=0.004)
    cyl(cx, 0.075, 0.16, (px + 0.16, py, 0.44), lamp, "lanterne_verre", verts=16, bevel=0)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        cyl(cx, 0.008, 0.17, (px + 0.16 + 0.078 * math.cos(a), py + 0.078 * math.sin(a), 0.44), iron,
            "lanterne_montant_%d" % k, verts=6, bevel=0)
    cyl(cx, 0.09, 0.035, (px + 0.16, py, 0.535), iron, "lanterne_chapeau", verts=16, r2=0.03, bevel=0)
    cyl(cx, 0.085, 0.02, (px + 0.16, py, 0.355), iron, "lanterne_fond", verts=16, bevel=0)
    tor(cx, 0.03, 0.008, (px + 0.16, py, 0.575), iron, "lanterne_anse", rot=(math.pi / 2, 0, 0), seg=12, mseg=6)
    halo(cx, (px + 0.16, py - 0.12, 0.44), 0.6)
    cx.cur = prev


# ================================================================================================
# Époque 2 · Forge : cubes cerclés, boucliers plats, créneaux ; acier boulonné, cerclages, laiton
# ================================================================================================
def mats_e02(cx):
    return dict(steel=metal(cx, "acier", "#5C6168", gain=1.7, rough=0.32, metallic=0.8, rust="#5A3A2A", rust_amount=0.25),
                band=metal(cx, "cerclage", "#2E2C2A", gain=1.5, rough=0.4, metallic=0.7, seed=2.0),
                brass=metal(cx, "laiton", "#8C7440", gain=1.8, rough=0.22, metallic=0.95, grain=0.08, seed=3.0),
                lens=flat(cx, "lentille", "#3A0A06", rough=0.05, metallic=0.2),
                slit=emis(cx, "forge", "#FF6A20", strength=1.4))


def base_e02(cx):
    m = mats_e02(cx)
    cyl(cx, 0.80, 0.30, (0, 0, 0.15), m["steel"], "tambour", verts=8, rot=(0, 0, math.pi / 8), bevel=0.02)
    cyl(cx, 0.815, 0.05, (0, 0, 0.06), m["band"], "cercle_bas", verts=8, rot=(0, 0, math.pi / 8), bevel=0.005)
    cyl(cx, 0.815, 0.05, (0, 0, 0.26), m["band"], "cercle_haut", verts=8, rot=(0, 0, math.pi / 8), bevel=0.005)
    for i in range(8):
        a = math.pi / 8 + i * math.pi / 4 + math.pi / 8
        x, y = 0.755 * math.cos(a), 0.755 * math.sin(a)
        rivet_row(cx, (x - 0.2 * math.sin(a), y + 0.2 * math.cos(a), 0.16), (x + 0.2 * math.sin(a), y - 0.2 * math.cos(a), 0.16),
                  4, 0.017, m["brass"], "rivets_tambour_%d" % i)
    box(cx, (0.66, 0.66, 0.26), (0, 0, 0.43), m["steel"], "bloc", bevel=0.02)
    box(cx, (0.70, 0.70, 0.045), (0, 0, 0.53), m["band"], "cercle_bloc", bevel=0.006)
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl(cx, 0.035, 0.03, (sx * 0.27, sy * 0.27, 0.565), m["brass"], "boulon_%d_%d" % (sx, sy), verts=6, bevel=0.003)
    # condensateurs : 4 fûts d'acier cerclés aux angles
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        x, y = sx * 0.50, sy * 0.50
        cyl(cx, 0.10, 0.34, (x, y, 0.47), m["steel"], "condo_%d" % i, verts=16)
        tor(cx, 0.102, 0.014, (x, y, 0.38), m["band"], "condo_c1_%d" % i, seg=24)
        tor(cx, 0.102, 0.014, (x, y, 0.56), m["band"], "condo_c2_%d" % i, seg=24)
        cyl(cx, 0.045, 0.04, (x, y, 0.66), m["brass"], "condo_borne_%d" % i, verts=8)
    # fentes de forge (nuit) sur la face sud du bloc
    for k, x in enumerate((-0.14, 0.14)):
        box(cx, (0.16, 0.02, 0.05), (x, -0.335, 0.43), m["slit"], "fente_%d" % k, bevel=0)
    halo(cx, (0.0, -0.40, 0.43), 1.0)
    # poteau-pivot carré cerclé
    zp = cx.zp
    box(cx, (0.30, 0.30, zp - 0.64), (0, 0, (0.56 + zp - 0.08) / 2), m["steel"], "poteau", bevel=0.015)
    for z in (0.66, zp - 0.18):
        box(cx, (0.33, 0.33, 0.04), (0, 0, z), m["band"], "poteau_cercle_%.2f" % z, bevel=0.004)
    cyl(cx, 0.24, 0.08, (0, 0, zp - 0.04), m["band"], "couronne", verts=24)
    rivet_ring(cx, 0.245, zp - 0.04, 12, 0.015, m["brass"], "rivets_couronne")


def head_e02(cx):
    m = mats_e02(cx)
    z0 = cx.zp
    cyl(cx, 0.21, 0.08, (0, 0, z0 + 0.04), m["steel"], "plateau", verts=24)
    # caisson riveté autour de l'émetteur
    box(cx, (0.50, 1.02, 0.46), (0, 0.16, z0 + 0.33), m["steel"], "caisson", bevel=0.018)
    for k, y in enumerate((-0.18, 0.18, 0.52)):
        box(cx, (0.535, 0.05, 0.495), (0, y, z0 + 0.33), m["band"], "cerclage_%d" % k, bevel=0.005)
        rivet_row(cx, (0.27, y, z0 + 0.13), (0.27, y, z0 + 0.53), 4, 0.014, m["brass"], "rv_d_%d" % k)
        rivet_row(cx, (-0.27, y, z0 + 0.13), (-0.27, y, z0 + 0.53), 4, 0.014, m["brass"], "rv_g_%d" % k)
    # face avant : cadre de lentille en laiton, lentille rubis
    box(cx, (0.44, 0.06, 0.40), (0, 0.69, z0 + 0.33), m["band"], "face", bevel=0.01)
    tube_y(cx, 0.15, 0.70, 0.78, z0 + 0.31, m["brass"], "cadre_lentille")
    tube_y(cx, 0.115, 0.76, 0.80, z0 + 0.31, m["lens"], "lentille")
    # visière : bouclier plat incliné au-dessus de la lentille, qui dépasse en haut et sur les côtés
    plate(cx, [(-0.34, 0.0), (0.34, 0.0), (0.30, 0.34), (-0.30, 0.34)], 0.045, m["steel"], "visiere", axis="Y",
          loc=(0, 0.74, z0 + 0.48), rot=(math.radians(-58), 0, 0))
    rivet_row(cx, (-0.26, 0.80, z0 + 0.53), (0.26, 0.80, z0 + 0.53), 5, 0.014, m["brass"], "rv_visiere")
    # arrière : boîte d'alimentation et câble
    box(cx, (0.34, 0.20, 0.30), (0, -0.44, z0 + 0.26), m["steel"], "boite_arriere", bevel=0.012)
    strut(cx, (0.12, -0.52, z0 + 0.14), (0.16, -0.30, 0.70), 0.03, m["band"], "cable_arriere")


def piece_e02(cx):
    m = mats_e02(cx)
    # jupe de blindage boulonnée : 3 plaques inclinées, bord bas à 0,15 tuile au-delà de l'emprise sud
    yb = ty(1.15)
    a = math.radians(52)
    for k, (x, w, rz) in enumerate(((-0.52, 0.42, -0.42), (0.0, 0.62, 0.0), (0.52, 0.42, 0.42))):
        o = loft(cx, (0, 0, w, 0.06), (0, 0, w * 0.92, 0.06), 0.0, 0.66, m["steel"], "jupe_%d" % k, bevel=0.01)
        # plaque inclinée : pied en avant (sud), tête contre le tambour
        y0 = yb + 0.30 + abs(x) * 0.25
        o.location = (x, y0, 0.0)
        o.rotation_euler = (-a, 0, rz)
        # rangée de rivets POSÉE sur la face avant de la tôle, à 0,14 du pied : repère local de la plaque
        # (u, v, w) -> rotation X de -a puis Z de rz (Euler XYZ), puis translation au pied
        def xf(u, v, wz, x=x, y0=y0, rz=rz):
            yy = v * math.cos(a) + wz * math.sin(a)
            zz = -v * math.sin(a) + wz * math.cos(a)
            return (x + u * math.cos(rz) - yy * math.sin(rz), y0 + u * math.sin(rz) + yy * math.cos(rz), zz)
        rivet_row(cx, xf(-w * 0.36, -0.035, 0.14), xf(w * 0.36, -0.035, 0.14), 4, 0.018, m["brass"], "rv_jupe_bas_%d" % k)
    # semelle au pied de la plaque centrale (elle flottait 0,17 tuile au sud : défaut D3 vu sur l'aperçu)
    box(cx, (0.70, 0.10, 0.05), (0, yb + 0.30, 0.025), m["band"], "semelle", bevel=0.006)


# ================================================================================================
# Époque 3 · Vapeur : cheminées rondes, manomètres, tuyaux de cuivre ; 1re lueur de jour (ambre)
# ================================================================================================
def mats_e03(cx):
    return dict(iron=metal(cx, "fonte", "#3A3634", gain=2.2, rough=0.45, metallic=0.6, rust="#5A3A2A", rust_amount=0.35),
                copper=metal(cx, "cuivre", "#8A5A3A", gain=1.6, rough=0.25, metallic=0.95, grain=0.12, rust="#4F6B5A",
                             rust_amount=0.25, seed=5.0),
                brass=metal(cx, "laiton", "#9C7E45", gain=1.6, rough=0.22, metallic=0.95, grain=0.08, seed=6.0),
                soot=flat(cx, "suie", "#141210", rough=0.9),
                lens=flat(cx, "lentille", "#3A0A06", rough=0.05, metallic=0.2),
                amber=emis(cx, "ambre", "#FFC060", strength=1.5))


def base_e03(cx):
    m = mats_e03(cx)
    # tambour de chaudière plus petit que le tambour cerclé de l'époque 2 (IoU e3/e2 mesurée 0,867 > 0,85 en passe 2)
    lathe(cx, [(0.68, 0.0), (0.68, 0.05), (0.645, 0.07), (0.63, 0.26), (0.56, 0.30), (0.0, 0.30)], m["iron"], "tambour", seg=48)
    tor(cx, 0.665, 0.03, (0, 0, 0.06), m["brass"], "bride")
    rivet_ring(cx, 0.64, 0.17, 22, 0.016, m["brass"], "rivets_tambour")
    # boucle de tuyau de cuivre autour du tambour
    tor(cx, 0.72, 0.035, (0, 0, 0.14), m["copper"], "tuyau_boucle", seg=64)
    for a in (35, 145, 215, 325):
        r = math.radians(a)
        cyl(cx, 0.045, 0.05, (0.72 * math.cos(r), 0.72 * math.sin(r), 0.14), m["brass"], "collier_%d" % a, verts=12,
            rot=(math.pi / 2, 0, r))
    # manomètre en façade (cadran ambré, visible de jour)
    # cadran ambré de 0,21 unité : zone lumineuse d'au moins 8 × 8 px hr (bible §1.6 ; 7,7 px en passe 2)
    tube_y(cx, 0.155, -0.70, -0.62, 0.19, m["brass"], "manometre_boite")
    tube_y(cx, 0.13, -0.715, -0.70, 0.19, m["amber"], "manometre_cadran", caps=True)
    halo(cx, (0.0, -0.80, 0.18), 0.7)
    # cheminée ronde à collerette à l'arrière gauche (fût vertical qui dépasse)
    # cheminée HAUTE au coin arrière gauche, à 1,05 unité de l'axe : hors de la portée de la tête qui tourne
    # (0,88 unité) ; posée sur son propre socle et reliée au tambour par un tuyau de cuivre
    cx0, cy0 = -0.74, 0.74
    cyl(cx, 0.17, 0.10, (cx0, cy0, 0.05), m["iron"], "cheminee_socle", verts=8, bevel=0.01)
    cyl(cx, 0.115, 1.90, (cx0, cy0, 0.10 + 0.95), m["iron"], "cheminee", verts=24)
    for k, zc in enumerate((0.45, 0.95, 1.45)):
        tor(cx, 0.12, 0.018, (cx0, cy0, zc), m["brass"], "cheminee_c%d" % k, seg=24)
    cyl(cx, 0.115, 0.14, (cx0, cy0, 2.07), m["iron"], "cheminee_levre", verts=24, r2=0.16, caps=False, bevel=0)
    cyl(cx, 0.11, 0.02, (cx0, cy0, 2.05), m["soot"], "cheminee_suie", verts=24, bevel=0)
    strut(cx, (-0.40, 0.40, 0.24), (cx0 + 0.08, cy0 - 0.08, 0.30), 0.04, m["copper"], "cheminee_tuyau")
    # réservoirs-condensateurs en laiton à l'arrière droit
    for k, (x, y) in enumerate(((0.44, 0.36), (0.24, 0.52))):
        cyl(cx, 0.10, 0.30, (x, y, 0.45), m["brass"], "reservoir_%d" % k, verts=20)
        sph(cx, 0.10, (x, y, 0.60), m["brass"], "reservoir_dome_%d" % k, scale=(1, 1, 0.5))
    # colonne de fonte cerclée de cuivre
    zp = cx.zp
    cyl(cx, 0.17, zp - 0.37, (0, 0, (0.30 + zp - 0.07) / 2), m["iron"], "colonne", verts=24)
    for z in (0.45, zp - 0.43):
        tor(cx, 0.172, 0.022, (0, 0, z), m["copper"], "colonne_c_%.2f" % z, seg=32)
    cyl(cx, 0.25, 0.07, (0, 0, zp - 0.035), m["brass"], "couronne", verts=32)


def head_e03(cx):
    m = mats_e03(cx)
    zp = cx.zp
    z = zp + 0.265
    cyl(cx, 0.19, 0.10, (0, 0, zp + 0.045), m["iron"], "plateau", verts=24)
    box(cx, (0.16, 0.24, 0.16), (0, 0, zp + 0.125), m["iron"], "chape", bevel=0.01)
    tube_y(cx, 0.24, -0.40, 0.62, z, m["iron"], "fut")
    # serpentins de cuivre (spires serrées)
    for k in range(9):
        ring_y(cx, 0.255, 0.024, -0.26 + 0.075 * k, z, m["copper"], "spire_%d" % k)
    tube_y(cx, 0.27, 0.40, 0.56, z, m["brass"], "bague_avant")
    tube_y(cx, 0.28, -0.42, -0.36, z, m["brass"], "bague_arriere")
    # lentille cerclée de laiton : pavillon évasé PLUS LARGE que le fût (une optique de phare, pas une bouche)
    tube_y(cx, 0.26, 0.54, 0.68, z, m["brass"], "pavillon", r2=0.33)
    ring_y(cx, 0.33, 0.035, 0.68, z, m["brass"], "cercle_lentille")
    tube_y(cx, 0.30, 0.64, 0.70, z, m["lens"], "lentille")
    # évent court (cheminée ronde) sur le dos
    cyl(cx, 0.075, 0.30, (0, -0.12, z + 0.36), m["iron"], "event", verts=20)
    cyl(cx, 0.075, 0.06, (0, -0.12, z + 0.53), m["iron"], "event_levre", verts=20, r2=0.10, caps=False, bevel=0)
    # hublots ambrés (visibles de jour) sur les flancs
    for s in (-1, 1):
        cyl(cx, 0.075, 0.04, (s * 0.245, 0.12, z), m["brass"], "hublot_cadre_%d" % s, verts=20, rot=(0, math.pi / 2, 0))
        cyl(cx, 0.058, 0.02, (s * 0.268, 0.12, z), m["amber"], "hublot_%d" % s, verts=20, rot=(0, math.pi / 2, 0))
    # manomètre sur le dos
    cyl(cx, 0.07, 0.035, (0.12, 0.22, z + 0.25), m["brass"], "mano_tete", verts=20, rot=(math.radians(-30), 0, 0))
    halo(cx, (0.0, 0.12, z), 0.8)


def piece_e03(cx):
    m = mats_e03(cx)
    yc = ty(0.98)
    tube_x(cx, 0.17, -0.42, 0.42, yc, 0.24, m["iron"], "chaudiere")
    for x in (-0.42, 0.42):
        cyl(cx, 0.175, 0.04, (x, yc, 0.24), m["brass"], "chaudiere_bride_%d" % (x > 0), verts=32, rot=(0, math.pi / 2, 0))
    for x in (-0.25, 0.25):
        box(cx, (0.08, 0.30, 0.10), (x, yc, 0.05), m["iron"], "berceau_%d" % (x > 0), bevel=0.01)
    rivet_row(cx, (-0.36, yc - 0.17, 0.24), (0.36, yc - 0.17, 0.24), 8, 0.013, m["brass"], "rv_chaudiere")
    # hublot ambré face sud : le bord avant de la pièce dépasse de 0,15 tuile au sud
    tube_y(cx, 0.07, yc - 0.20, yc - 0.16, 0.24, m["brass"], "hublot_ch_cadre")
    tube_y(cx, 0.055, yc - 0.215, yc - 0.20, 0.24, m["amber"], "hublot_ch")
    cyl(cx, 0.04, 0.26, (0.28, yc, 0.52), m["iron"], "cheminee_ch", verts=16)
    strut(cx, (-0.30, yc + 0.10, 0.36), (-0.36, ty(0.45), 0.20), 0.03, m["copper"], "tuyau_ch")
    halo(cx, (0.0, yc - 0.25, 0.24), 0.6)


# ================================================================================================
# Époque 4 · Pétrole (ère II) : cuves horizontales, passerelles à garde-corps, torchère ; voyants orange
# ================================================================================================
def mats_e04(cx):
    return dict(yellow=metal(cx, "jaune", "#8C7A3A", gain=1.55, rough=0.42, metallic=0.35, rust="#5A3A2A", rust_amount=0.3,
                             seed=7.0),
                galva=metal(cx, "galva", "#6E7378", gain=1.35, rough=0.32, metallic=0.85, grain=0.12, seed=8.0),
                black=flat(cx, "noir", "#1E1E1E", rough=0.55),
                lens=flat(cx, "lentille", "#3A0A06", rough=0.05, metallic=0.2),
                orange=emis(cx, "orange", "#FF8C1A", strength=1.6))


def base_e04(cx):
    m = mats_e04(cx)
    # plate-forme carrée peinte, bande noire et jaune en rive
    box(cx, (1.56, 1.56, 0.16), (0, 0, 0.08), m["galva"], "plateforme", bevel=0.015)
    box(cx, (1.50, 1.50, 0.08), (0, 0, 0.20), m["yellow"], "pont", bevel=0.01)
    for k in range(7):
        box(cx, (0.10, 0.012, 0.075), (-0.6 + 0.2 * k, -0.785, 0.10), m["black"], "zebra_%d" % k, bevel=0,
            rot=(0, math.radians(35), 0))
    # garde-corps (lignes fines) sur 3 côtés et poteaux
    posts = [(-0.72, y) for y in (-0.72, -0.24, 0.24, 0.72)] + [(0.72, y) for y in (-0.72, -0.24, 0.24, 0.72)] + \
            [(x, 0.72) for x in (-0.24, 0.24)]
    for i, (x, y) in enumerate(posts):
        cyl(cx, 0.014, 0.30, (x, y, 0.39), m["yellow"], "poteau_%d" % i, verts=8, bevel=0)
    for s in (-1, 1):
        box(cx, (0.025, 1.46, 0.025), (s * 0.72, 0, 0.54), m["yellow"], "lisse_%d" % s, bevel=0)
        box(cx, (0.018, 1.46, 0.018), (s * 0.72, 0, 0.38), m["yellow"], "sous_lisse_%d" % s, bevel=0)
    box(cx, (1.46, 0.025, 0.025), (0, 0.72, 0.54), m["yellow"], "lisse_n", bevel=0)
    # 2 cuves horizontales à l'arrière, bandes noires
    for k, x in enumerate((-0.36, 0.36)):
        tube_y(cx, 0.15, 0.10, 0.66, 0.40, m["galva"], "cuve_%d" % k, x=x)
        for y in (0.22, 0.54):
            ring_y(cx, 0.152, 0.014, y, 0.40, m["black"], "cuve_b_%d_%.2f" % (k, y), x=x)
        box(cx, (0.24, 0.06, 0.16), (x, 0.38, 0.27), m["galva"], "berceau_%d" % k, bevel=0.006)
    # échelle à l'avant droit
    for s in (-1, 1):
        box(cx, (0.012, 0.012, 0.26), (0.55 + s * 0.06, -0.80, 0.10), m["galva"], "echelle_m_%d" % s, bevel=0)
    for k in range(3):
        box(cx, (0.12, 0.01, 0.01), (0.55, -0.80, 0.03 + 0.08 * k), m["galva"], "echelle_b_%d" % k, bevel=0)
    # colonne galvanisée à brides
    zp = cx.zp
    cyl(cx, 0.15, zp - 0.31, (0, 0, (0.24 + zp - 0.07) / 2), m["galva"], "colonne", verts=24)
    for z in (0.40, zp - 0.325):
        cyl(cx, 0.19, 0.04, (0, 0, z), m["galva"], "bride_%.2f" % z, verts=24)
        rivet_ring(cx, 0.175, z + 0.025, 10, 0.012, m["black"], "boulons_%.2f" % z)
    cyl(cx, 0.24, 0.07, (0, 0, zp - 0.035), m["yellow"], "couronne", verts=32)
    # voyant orange au pied de la colonne
    sph(cx, 0.065, (0.18, -0.14, 0.30), m["orange"], "voyant_socle")
    halo(cx, (0.16, -0.20, 0.30), 0.5)


def head_e04(cx):
    m = mats_e04(cx)
    z = cx.zp + 0.225
    cyl(cx, 0.20, 0.10, (0, 0, cx.zp + 0.045), m["galva"], "plateau", verts=24)
    box(cx, (0.48, 1.00, 0.34), (0, 0.10, z), m["yellow"], "carter", bevel=0.03)
    box(cx, (0.50, 0.06, 0.36), (0, -0.20, z), m["black"], "bande_carter", bevel=0.004)
    tube_y(cx, 0.15, 0.58, 0.70, z - 0.02, m["galva"], "nez")
    tube_y(cx, 0.115, 0.69, 0.73, z - 0.02, m["lens"], "lentille")
    # cuve de refroidissement horizontale dorsale, TRANSVERSALE (axe X) : posée le long du tir, elle se lisait
    # comme un canon (identité de la famille : une lentille, jamais de canon) ; fonds bombés
    zc = z + 0.36
    yc = -0.08
    tube_x(cx, 0.17, -0.42, 0.42, yc, zc, m["galva"], "cuve")
    sph(cx, 0.17, (0.42, yc, zc), m["galva"], "cuve_fond_d", scale=(0.45, 1, 1))
    sph(cx, 0.17, (-0.42, yc, zc), m["galva"], "cuve_fond_g", scale=(0.45, 1, 1))
    for x in (-0.24, 0.0, 0.24):
        tor(cx, 0.172, 0.016, (x, yc, zc), m["black"], "cuve_bande_%.2f" % x, rot=(0, math.pi / 2, 0), seg=40)
    for x in (-0.26, 0.26):
        box(cx, (0.06, 0.20, 0.14), (x, yc, z + 0.20), m["galva"], "selle_%.2f" % x, bevel=0.006)
    # tuyaux : des fonds de la cuve au carter (coudes)
    for s in (-1, 1):
        strut(cx, (s * 0.46, yc, zc - 0.06), (s * 0.27, yc + 0.10, z - 0.02), 0.028, m["galva"], "tuyau_%d" % s)
        strut(cx, (s * 0.27, yc + 0.10, z - 0.02), (s * 0.27, 0.45, z - 0.02), 0.028, m["galva"], "tuyau_long_%d" % s)
    # voyant orange (jour) sur la face avant de la cuve et vanne à volant
    sph(cx, 0.065, (0.20, yc + 0.17, zc + 0.02), m["orange"], "voyant")
    tor(cx, 0.06, 0.012, (-0.20, yc + 0.02, zc + 0.19), m["black"], "volant", seg=20)
    cyl(cx, 0.012, 0.05, (-0.20, yc + 0.02, zc + 0.165), m["galva"], "volant_tige", verts=8, bevel=0)
    halo(cx, (0.20, yc + 0.24, zc), 0.8)


def piece_e04(cx):
    m = mats_e04(cx)
    x, y = -0.86, ty(0.98)
    drum = metal(cx, "fut", "#5A2A22", gain=1.6, rough=0.45, metallic=0.4, rust="#3A2A20", rust_amount=0.3, seed=9.0)
    cyl(cx, 0.17, 0.44, (x, y, 0.22), drum, "fut", verts=28)
    for z in (0.10, 0.34):
        tor(cx, 0.172, 0.014, (x, y, z), m["black"], "fut_cercle_%.2f" % z, seg=28)
    cyl(cx, 0.17, 0.02, (x, y, 0.445), m["galva"], "fut_couvercle", verts=28, bevel=0.004)
    cyl(cx, 0.03, 0.04, (x + 0.08, y - 0.04, 0.47), m["galva"], "fut_bonde", verts=10)
    # vanne : petit tuyau vers le socle et volant
    strut(cx, (x + 0.15, y + 0.04, 0.30), (x + 0.42, y + 0.30, 0.30), 0.025, m["galva"], "vanne_tuyau")
    tor(cx, 0.07, 0.013, (x + 0.27, y + 0.14, 0.40), m["orange"] if False else m["yellow"], "vanne_volant", seg=20)
    cyl(cx, 0.012, 0.10, (x + 0.27, y + 0.14, 0.35), m["galva"], "vanne_tige", verts=8, bevel=0)
    box(cx, (0.20, 0.20, 0.05), (x + 0.10, y - 0.10, 0.025), m["black"], "bac", bevel=0.004)


# ================================================================================================
# Époque 5 · Volcan : blindage incliné en écailles, troncs de pyramide, rivets lourds, fentes de braise
# ================================================================================================
def mats_e05(cx):
    return dict(tung=metal(cx, "tungstene", "#3E3D42", gain=2.3, rough=0.30, metallic=0.85, rust="#5A3A2A", rust_amount=0.3),
                rust=metal(cx, "rouille", "#5A3A2A", gain=1.6, rough=0.6, metallic=0.3, seed=4.0),
                basalt=metal(cx, "basalte", "#2A2826", gain=2.0, rough=0.55, metallic=0.1, grain=0.35, grain_scale=30.0,
                             seed=12.0),
                rivet=metal(cx, "rivet", "#6A6670", gain=1.6, rough=0.25, metallic=0.9, seed=13.0),
                ember=emis(cx, "braise", "#FF4A10", strength=1.6))


def base_e05(cx):
    m = mats_e05(cx)
    loft(cx, (0, 0, 1.62, 1.62), (0, 0, 0.98, 0.98), 0.0, 0.42, m["tung"], "pyramide", bevel=0.02)
    loft(cx, (0, 0, 0.98, 0.98), (0, 0, 0.80, 0.80), 0.42, 0.52, m["rust"], "gradin", bevel=0.012)
    # contreforts inclinés aux 4 angles
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        o = loft(cx, (0, 0, 0.22, 0.40), (0, 0, 0.16, 0.10), 0.0, 0.50, m["tung"], "contrefort_%d" % i, bevel=0.012)
        o.location = (sx * 0.62, sy * 0.62, 0.0)
        o.rotation_euler = (0, 0, math.atan2(sy, sx) + math.pi / 2)
    # rivets lourds le long des arêtes de la face sud
    rivet_row(cx, (-0.62, -0.74, 0.12), (0.62, -0.74, 0.12), 7, 0.026, m["rivet"], "rv_sud")
    # fentes de braise (jour) sur la pente sud
    for k, z in enumerate((0.20, 0.31)):
        w = 0.70 - 0.18 * k
        o = box(cx, (w, 0.03, 0.09), (0, -0.70 + 0.12 * k, z), m["ember"], "fente_%d" % k, bevel=0)
        o.rotation_euler = (math.radians(-45), 0, 0)
    halo(cx, (0.0, -0.95, 0.25), 1.0)
    # colonne en tronc de pyramide
    loft(cx, (0, 0, 0.46, 0.46), (0, 0, 0.30, 0.30), 0.52, cx.zp - 0.05, m["tung"], "colonne", bevel=0.012)
    box(cx, (0.40, 0.40, 0.06), (0, 0, cx.zp - 0.03), m["rust"], "couronne", bevel=0.01)


def head_e05(cx):
    m = mats_e05(cx)
    z0 = cx.zp
    box(cx, (0.30, 0.30, 0.10), (0, 0, z0 + 0.05), m["tung"], "plateau", bevel=0.01)
    # capot trapézoïdal (tête en coin) : large et bas à l'avant, pente vers l'arrière
    loft(cx, (0, 0.10, 0.70, 1.12), (0, -0.06, 0.40, 0.72), z0 + 0.10, z0 + 0.56, m["tung"], "capot", bevel=0.02)
    loft(cx, (0, 0.10, 0.74, 1.16), (0, 0.10, 0.70, 1.12), z0 + 0.06, z0 + 0.12, m["rust"], "jupe_capot", bevel=0.006)
    # écailles de blindage sur le dessus
    for k in range(3):
        o = loft(cx, (0, 0, 0.42, 0.20), (0, 0, 0.38, 0.12), 0.0, 0.05, m["tung"], "ecaille_%d" % k, bevel=0.008)
        o.location = (0, 0.30 - 0.22 * k, z0 + 0.53)
        o.rotation_euler = (math.radians(-14), 0, 0)
    # fente d'émission rougeoyante (la « lentille » de l'époque)
    box(cx, (0.50, 0.04, 0.13), (0, 0.67, z0 + 0.28), m["ember"], "fente_emission", bevel=0)
    box(cx, (0.58, 0.05, 0.03), (0, 0.67, z0 + 0.35), m["rivet"], "levre_haute", bevel=0.005)
    box(cx, (0.58, 0.05, 0.03), (0, 0.67, z0 + 0.21), m["rivet"], "levre_basse", bevel=0.005)
    # ailettes de dissipation sur les flancs (dépassent)
    for s in (-1, 1):
        for k in range(5):
            plate(cx, [(-0.08, 0.0), (0.08, 0.0), (0.05, 0.30), (-0.05, 0.30)], 0.022, m["rust"], "ailette_%d_%d" % (s, k),
                  axis="X", loc=(s * 0.37, -0.25 + 0.16 * k, z0 + 0.16), rot=(0, math.radians(s * 20), 0))
    rivet_row(cx, (-0.30, 0.62, z0 + 0.48), (0.30, 0.62, z0 + 0.48), 5, 0.02, m["rivet"], "rv_capot")
    halo(cx, (0.0, 0.75, z0 + 0.28), 1.0)


def piece_e05(cx):
    m = mats_e05(cx)
    for s in (-1, 1):
        x, y = s * 0.80, ty(0.92)
        crystal(cx, 0.12, 0.66, (x, y, 0.02), m["basalt"], "basalte_%d" % s, tilt=(math.radians(-12), math.radians(s * 14)),
                sides=5, spin=0.3 * s)
        crystal(cx, 0.08, 0.42, (x + s * 0.13, y - 0.10, 0.0), m["basalt"], "basalte_p_%d" % s,
                tilt=(math.radians(-22), math.radians(s * 26)), sides=5, spin=0.9)
        crystal(cx, 0.06, 0.28, (x - s * 0.12, y - 0.08, 0.0), m["basalt"], "basalte_pp_%d" % s,
                tilt=(math.radians(-25), math.radians(-s * 10)), sides=5, spin=1.7)
        # fissure de braise au pied
        box(cx, (0.16, 0.05, 0.012), (x, y - 0.02, 0.006), m["ember"], "braise_pied_%d" % s, bevel=0)
    halo(cx, (0.0, ty(0.95), 0.05), 0.5)


# ================================================================================================
# Époque 6 · Électricité : piles d'isolateurs (colonnes crantées), bobines, arcs cyan
# ================================================================================================
def mats_e06(cx):
    return dict(cer=metal(cx, "ceramique", "#D8D4C8", gain=0.62, rough=0.25, metallic=0.0, grain=0.10, dirt=0.6, seed=14.0),
                copper=metal(cx, "cuivre", "#B0703A", gain=1.1, rough=0.25, metallic=0.95, grain=0.1, seed=15.0),
                steel=metal(cx, "acier", "#5C6168", gain=1.6, rough=0.32, metallic=0.85, seed=16.0),
                lens=flat(cx, "lentille", "#0A1A22", rough=0.05, metallic=0.2),
                cyan=emis(cx, "cyan", "#60D0FF", strength=1.6))


def insulator_stack(cx, m, x, y, z0, n, r, name, pitch=0.075):
    cyl(cx, r * 0.45, n * pitch, (x, y, z0 + n * pitch / 2), m["steel"], name + "_ame", verts=12, bevel=0)
    for k in range(n):
        cyl(cx, r, pitch * 0.5, (x, y, z0 + pitch * (k + 0.5)), m["cer"], "%s_%d" % (name, k), verts=20, r2=r * 0.78,
            bevel=0.004)


def base_e06(cx):
    m = mats_e06(cx)
    cyl(cx, 0.80, 0.18, (0, 0, 0.09), m["steel"], "plateau", verts=8, rot=(0, 0, math.pi / 8), bevel=0.015)
    cyl(cx, 0.60, 0.06, (0, 0, 0.21), m["copper"], "plaque_cuivre", verts=8, rot=(0, 0, math.pi / 8), bevel=0.006)
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        insulator_stack(cx, m, sx * 0.52, sy * 0.52, 0.18, 5, 0.075, "pile_%d" % i)
        sph(cx, 0.04, (sx * 0.52, sy * 0.52, 0.18 + 5 * 0.075 + 0.03), m["copper"], "borne_%d" % i)
    # cou-pivot : grande pile d'isolateurs (colonne crantée)
    n = max(4, int(round((cx.zp - 0.06 - 0.24) / 0.082)))
    pitch = (cx.zp - 0.06 - 0.24) / n
    insulator_stack(cx, m, 0, 0, 0.24, n, 0.19, "cou", pitch=pitch)
    cyl(cx, 0.24, 0.06, (0, 0, cx.zp - 0.03), m["steel"], "couronne", verts=24)
    # éclateur cyan au pied (lueur de jour) sur la face sud
    sph(cx, 0.05, (0.0, -0.62, 0.30), m["cyan"], "eclateur")
    box(cx, (0.20, 0.06, 0.08), (0.0, -0.60, 0.22), m["cer"], "eclateur_isolant", bevel=0.01)
    halo(cx, (0.0, -0.70, 0.30), 0.6)


def head_e06(cx):
    m = mats_e06(cx)
    zp = cx.zp
    z = zp + 0.26
    cyl(cx, 0.18, 0.10, (0, 0, zp + 0.04), m["steel"], "plateau", verts=24)
    box(cx, (0.14, 0.20, 0.14), (0, 0, zp + 0.12), m["steel"], "chape", bevel=0.01)
    tube_y(cx, 0.17, -0.40, 0.42, z, m["copper"], "corps")
    # bobine annulaire autour du corps (tore de cuivre enroulé)
    for k in range(5):
        ring_y(cx, 0.30, 0.035, -0.18 + 0.055 * k, z, m["copper"], "bobine_%d" % k)
    ring_y(cx, 0.34, 0.02, -0.21, z, m["steel"], "joue_ar")
    ring_y(cx, 0.34, 0.02, 0.07, z, m["steel"], "joue_av")
    # isolateurs empilés sur le dessus et le dessous (mini-bobine Tesla)
    for k, y in enumerate((-0.30, 0.25)):
        insulator_stack(cx, m, 0, y, z + 0.16, 4, 0.075, "iso_haut_%d" % k)
    tor(cx, 0.11, 0.04, (0, -0.30, z + 0.16 + 4 * 0.075 + 0.04), m["copper"], "tore_tesla", seg=32)
    # émetteur : cône de céramique et pointe cyan (lueur de jour)
    tube_y(cx, 0.16, 0.42, 0.66, z, m["cer"], "cone", r2=0.07)
    sph(cx, 0.075, (0, 0.70, z), m["cyan"], "pointe")
    for s in (-1, 1):
        insulator_stack(cx, m, s * 0.22, 0.48, z - 0.24, 3, 0.05, "iso_lat_%d" % s, pitch=0.06)
    halo(cx, (0.0, 0.75, z), 1.0)


def piece_e06(cx):
    m = mats_e06(cx)
    x, y = 0.30, ty(1.0)
    cyl(cx, 0.18, 0.06, (x, y, 0.03), m["cer"], "bobine_sol_pied", verts=24)
    for k in range(6):
        tor(cx, 0.13, 0.026, (x, y, 0.09 + 0.045 * k), m["copper"], "bobine_sol_%d" % k, seg=28)
    cyl(cx, 0.09, 0.30, (x, y, 0.21), m["steel"], "bobine_sol_ame", verts=16)
    tor(cx, 0.09, 0.03, (x, y, 0.39), m["copper"], "bobine_sol_tore", seg=24)
    insulator_stack(cx, m, -0.35, ty(0.95), 0.0, 4, 0.07, "pile_sol")
    # arc (statique en phase 1) entre la bobine et la pile, en lignes brisées lumineuses
    pts = [(x, y, 0.42), (x - 0.12, y + 0.05, 0.47), (x - 0.25, y + 0.02, 0.40), (x - 0.42, y + 0.08, 0.38),
           (-0.35, ty(0.95), 0.32)]
    for k in range(len(pts) - 1):
        strut(cx, pts[k], pts[k + 1], 0.012, m["cyan"], "arc_%d" % k, verts=6)
    halo(cx, (0.0, y, 0.40), 0.8)


# ================================================================================================
# Époque 7 · Cristal (ère III) : pointes de cristal asymétriques violettes ; bronze, pierre taillée
# ================================================================================================
def mats_e07(cx):
    return dict(stone=metal(cx, "pierre", "#4A4038", gain=1.9, rough=0.7, metallic=0.0, grain=0.35, grain_scale=22.0, seed=17.0),
                bronze=metal(cx, "bronze", "#6A5236", gain=1.7, rough=0.28, metallic=0.9, grain=0.12, rust="#4F6B5A",
                             rust_amount=0.25, seed=18.0),
                # émission 0,6 (et non 1,1) : à 1,1 le prisme saturait en blanc dans la couche principale (passe 1)
                crys=emis(cx, "cristal", "#B070FF", strength=0.6, base=(0.18, 0.06, 0.45)),
                crys_dark=glass(cx, "cristal_sombre", "#9A5CFF", gain=0.55))


def base_e07(cx):
    m = mats_e07(cx)
    lathe(cx, [(0.80, 0.0), (0.82, 0.10), (0.74, 0.20), (0.70, 0.30), (0.0, 0.30)], m["stone"], "socle_taille", seg=7,
          smooth=None, phase=0.2)
    tor(cx, 0.72, 0.03, (0, 0, 0.29), m["bronze"], "sertissure", seg=56)
    # éclats asymétriques aux angles (hauteurs irrégulières)
    shards = [(-0.62, 0.42, 0.58, 0.10, (-15, -25)), (0.58, 0.50, 0.40, 0.08, (-20, 25)), (-0.40, -0.55, 0.32, 0.07, (18, -20)),
              (0.66, -0.25, 0.26, 0.06, (5, 30))]
    for k, (x, y, h, r, (tx, tyy)) in enumerate(shards):
        crystal(cx, r, h, (x, y, 0.20), m["crys"] if k % 2 == 0 else m["crys_dark"], "eclat_%d" % k,
                tilt=(math.radians(tx), math.radians(tyy)), spin=0.4 * k)
        halo(cx, (x, y, 0.20 + h * 0.5), 0.4)
    # colonne de bronze et griffes
    cyl(cx, 0.15, cx.zp - 0.38, (0, 0, (0.30 + cx.zp - 0.08) / 2), m["bronze"], "colonne", verts=7, bevel=0.01)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.3
        strut(cx, (0.30 * math.cos(a), 0.30 * math.sin(a), 0.30), (0.10 * math.cos(a), 0.10 * math.sin(a), 0.75), 0.035,
              m["bronze"], "griffe_%d" % k)
    cyl(cx, 0.24, 0.08, (0, 0, cx.zp - 0.04), m["bronze"], "couronne", verts=7)


def head_e07(cx):
    m = mats_e07(cx)
    z = cx.zp + 0.25
    cyl(cx, 0.17, 0.12, (0, 0, cx.zp + 0.05), m["bronze"], "plateau", verts=14)
    tube_y(cx, 0.22, -0.45, 0.18, z, m["bronze"], "corps", verts=7)
    tube_y(cx, 0.25, 0.10, 0.22, z, m["bronze"], "sertissure_avant", verts=7)
    # grand prisme de cristal saillant vers l'avant (la lentille devient prisme)
    crystal(cx, 0.17, 1.05, (0, 0.10, z), m["crys"], "prisme", tilt=(math.radians(-90), 0), sides=6, base_frac=0.10)
    # griffes de bronze qui tiennent le prisme
    for k in range(3):
        a = 2 * math.pi * k / 3 + math.pi / 2
        strut(cx, (0.22 * math.cos(a), 0.14, z + 0.22 * math.sin(a)), (0.13 * math.cos(a), 0.45, z + 0.13 * math.sin(a)),
              0.025, m["bronze"], "griffe_t_%d" % k)
    # grappe asymétrique sur le dos
    crystal(cx, 0.08, 0.42, (0.06, -0.20, z + 0.18), m["crys"], "grappe_1", tilt=(math.radians(-15), math.radians(12)))
    crystal(cx, 0.06, 0.28, (-0.08, -0.30, z + 0.18), m["crys_dark"], "grappe_2", tilt=(math.radians(10), math.radians(-25)))
    halo(cx, (0.0, 0.70, z), 1.0)


def piece_e07(cx):
    m = mats_e07(cx)
    for k in range(7):
        a = math.radians(-155 + 130 * k / 6.0)
        x, y = 0.95 * math.cos(a), 1.30 * math.sin(a)
        h = (0.22, 0.34, 0.18, 0.30, 0.20, 0.36, 0.24)[k]
        crystal(cx, 0.055 + 0.02 * (k % 2), h, (x, y, 0.0), m["crys"] if k % 3 else m["crys_dark"], "anneau_cristal_%d" % k,
                tilt=(math.radians(-12 + 6 * (k % 3)), math.radians(15 * math.cos(a))), spin=0.7 * k)
        cyl(cx, 0.07, 0.04, (x, y, 0.02), m["stone"], "anneau_pierre_%d" % k, verts=6, bevel=0.005)
    halo(cx, (0.0, ty(0.85), 0.15), 0.7)


# ================================================================================================
# Époque 8 · Marais : bulbes et sphères de verre, conduits vert-de-gris ; liquide vert-jaune
# ================================================================================================
def mats_e08(cx):
    # passe 5 : liquide de l'ampoule à émission FAIBLE et fond sombre. La lueur (draw_as_glow) est dessinée PAR-DESSUS la
    # couche principale, qui montre déjà l'émission : les deux s'additionnent. Avec l'émission 0,35 sur fond clair de la
    # passe 4, l'ampoule (le plus grand émissif de la famille, 0,37 tuile de rayon) saturait en un disque JAUNE plat
    # (vert + vert = vert écrêté, rouge doublé). Ici : moitié de la couleur voulue dans chaque couche.
    return dict(verd=metal(cx, "vertdegris", "#4F6B5A", gain=1.7, rough=0.40, metallic=0.6, rust="#2A2A28", rust_amount=0.3,
                           seed=19.0),
                rubber=flat(cx, "caoutchouc", "#2A2A28", rough=0.7),
                glassm=glass(cx, "verre", "#8FBF4A", gain=0.75),
                plasma=emis(cx, "plasma", "#A8FF3A", strength=0.35, base=(0.15, 0.3, 0.05)),
                liquid=emis(cx, "liquide", "#A8FF3A", strength=0.16, base=(0.02, 0.05, 0.01)),
                bulbglass=glass(cx, "verre_ampoule", "#6E9A3A", gain=0.55))


def sphere_cap(cx, r, center, t0, t1, mat, name, seg=32, n=10):
    """Calotte de sphère de rayon r entre les angles polaires t0 < t1 (0 = pôle haut, pi = pôle bas), axe Z.
    Les bords non polaires sont fermés par un disque plat (surface du liquide)."""
    prof = []
    for i in range(n + 1):
        t = t0 + (t1 - t0) * i / n
        prof.append((max(0.0, r * math.sin(t)) if 1e-6 < t < math.pi - 1e-6 else 0.0, r * math.cos(t)))
    return lathe(cx, prof, mat, name, seg=seg, loc=center, smooth=70)


def bulb(cx, m, x, y, z, r, name, glow=True):
    sph(cx, r, (x, y, z), m["plasma"] if glow else m["glassm"], name, seg=28, rings=14)
    tor(cx, r * 0.55, r * 0.12, (x, y, z - r * 0.85), m["verd"], name + "_col", seg=24)


def base_e08(cx):
    m = mats_e08(cx)
    lathe(cx, [(0.78, 0.0), (0.80, 0.06), (0.74, 0.18), (0.58, 0.28), (0.30, 0.33), (0.0, 0.34)], m["verd"], "dome_socle",
          seg=48)
    tor(cx, 0.77, 0.035, (0, 0, 0.07), m["rubber"], "joint", seg=56)
    # 2 cuves-bulbes de verre aux angles arrière, sur pieds
    for k, (x, y) in enumerate(((-0.52, 0.52), (0.52, 0.52))):
        cyl(cx, 0.08, 0.22, (x, y, 0.30), m["verd"], "pied_bulbe_%d" % k, verts=16)
        sph(cx, 0.22, (x, y, 0.58), m["glassm"], "bulbe_%d" % k, seg=28, rings=14)
        sph(cx, 0.14, (x, y, 0.56), m["plasma"], "bulbe_coeur_%d" % k, seg=20, rings=10)
        tor(cx, 0.12, 0.025, (x, y, 0.40), m["verd"], "bulbe_col_%d" % k, seg=24)
        strut(cx, (x * 0.7, y * 0.7, 0.36), (x * 0.2, y * 0.2, 0.50), 0.035, m["rubber"], "conduit_%d" % k)
        halo(cx, (x, y, 0.58), 0.4)
    # colonne vert-de-gris à bagues de caoutchouc
    zp = cx.zp
    cyl(cx, 0.16, zp - 0.40, (0, 0, (0.30 + zp - 0.10) / 2), m["verd"], "colonne", verts=24)
    for k in range(3):
        z = 0.60 + (zp - 0.92) * k / 2.0
        tor(cx, 0.165, 0.03, (0, 0, z), m["rubber"], "bague_%d" % k, seg=32)
    sph(cx, 0.23, (0, 0, zp - 0.10), m["verd"], "rotule", scale=(1, 1, 0.45))


def head_e08(cx):
    m = mats_e08(cx)
    z = cx.zp + 0.22
    cyl(cx, 0.15, 0.14, (0, 0, cx.zp - 0.02), m["verd"], "plateau", verts=24)
    # corps en gélule
    tube_y(cx, 0.21, -0.40, 0.18, z, m["verd"], "gelule")
    sph(cx, 0.21, (0, -0.40, z), m["verd"], "gelule_ar", scale=(1, 0.8, 1))
    # ampoule frontale de plasma vert (passe 5) : calotte de verre en haut, liquide luminescent dessous (surface
    # horizontale), cerclage vert-de-gris au niveau du liquide ; le verre porte les reflets, le liquide la lueur.
    # Niveau à 42° du pôle : vu à 45°, le liquide occupe la moitié basse du disque de l'ampoule à l'écran (à 78°, essai
    # de la passe 5, on ne voyait qu'un croissant vert sous un casque de verre sombre).
    tor(cx, 0.22, 0.04, (0, 0.20, z), m["rubber"], "col_ampoule", rot=(math.pi / 2, 0, 0), seg=32)
    t_lvl = math.radians(42)
    sphere_cap(cx, 0.31, (0, 0.50, z), 0.0, t_lvl, m["bulbglass"], "ampoule_verre")
    sphere_cap(cx, 0.305, (0, 0.50, z), t_lvl, math.pi, m["liquid"], "ampoule_liquide")
    tor(cx, 0.31 * math.sin(t_lvl), 0.018, (0, 0.50, z + 0.31 * math.cos(t_lvl)), m["verd"], "ampoule_cerclage", seg=40)
    # conduits le long du corps
    for s in (-1, 1):
        strut(cx, (s * 0.22, -0.40, z - 0.05), (s * 0.20, 0.18, z - 0.02), 0.035, m["rubber"], "conduit_t_%d" % s)
    sph(cx, 0.12, (0, -0.15, z + 0.24), m["glassm"], "bulle_dos", seg=20, rings=10)
    halo(cx, (0.0, 0.50, z), 1.0)


def piece_e08(cx):
    m = mats_e08(cx)
    for s in (-1, 1):
        x, y = s * 0.78, ty(0.90)
        cyl(cx, 0.10, 0.12, (x, y, 0.06), m["verd"], "condo_pied_%d" % s, verts=20)
        sph(cx, 0.17, (x, y, 0.28), m["glassm"], "condo_verre_%d" % s, seg=24, rings=12)
        sph(cx, 0.10, (x, y, 0.27), m["plasma"], "condo_coeur_%d" % s, seg=16, rings=8)
        cyl(cx, 0.04, 0.08, (x, y, 0.48), m["verd"], "condo_borne_%d" % s, verts=12)
        strut(cx, (x, y + 0.15, 0.10), (x * 0.55, y + 0.45, 0.12), 0.03, m["rubber"], "condo_conduit_%d" % s)
        halo(cx, (x, y, 0.28), 0.5)


# ================================================================================================
# Époque 9 · Atome : blindage plombé chanfreiné (octogones), tours hyperboloïdes, hublots verts
# ================================================================================================
def mats_e09(cx):
    return dict(lead=metal(cx, "plomb", "#4A5058", gain=1.65, rough=0.42, metallic=0.7, seed=20.0),
                yellow=metal(cx, "jaune", "#C9A227", gain=0.75, rough=0.5, metallic=0.2, seed=21.0),
                black=flat(cx, "noir", "#1A1A1A", rough=0.5),
                concrete=metal(cx, "beton", "#7A7670", gain=1.0, rough=0.85, metallic=0.0, grain=0.3, grain_scale=25.0,
                               seed=22.0),
                green=emis(cx, "uranium", "#5CFF4A", strength=1.4, base=(0.05, 0.2, 0.05)),
                lens=flat(cx, "lentille", "#0A200A", rough=0.05, metallic=0.2))


def base_e09(cx):
    m = mats_e09(cx)
    r8 = (0, 0, math.pi / 8)
    cyl(cx, 0.80, 0.24, (0, 0, 0.12), m["lead"], "bloc", verts=8, rot=r8, bevel=0.03)
    cyl(cx, 0.80, 0.10, (0, 0, 0.29), m["lead"], "chanfrein", verts=8, rot=r8, r2=0.62, bevel=0.01)
    # bande d'avertissement jaune et noire
    cyl(cx, 0.81, 0.05, (0, 0, 0.12), m["yellow"], "bande", verts=8, rot=r8, bevel=0.003)
    for k in range(8):
        a = math.pi / 8 + k * math.pi / 4 + math.pi / 8
        o = box(cx, (0.08, 0.012, 0.055), (0.75 * math.cos(a), 0.75 * math.sin(a), 0.12), m["black"], "chevron_%d" % k,
                bevel=0)
        o.rotation_euler = (0, math.radians(35), a + math.pi / 2)
    # hublots verts (jour) sur les pans avant
    for k, x in enumerate((-0.30, 0.30)):
        tube_y(cx, 0.07, -0.76, -0.72, 0.22, m["lead"], "hublot_cadre_%d" % k, x=x, verts=8)
        tube_y(cx, 0.05, -0.775, -0.76, 0.22, m["green"], "hublot_%d" % k, x=x, verts=8)
    halo(cx, (0.0, -0.85, 0.22), 0.6)
    # tour de refroidissement hyperboloïde à l'arrière droit
    prof = [(0.22, 0.0), (0.18, 0.15), (0.155, 0.30), (0.16, 0.45), (0.19, 0.58)]
    lathe(cx, prof, m["concrete"], "tour_hyper", seg=32, loc=(0.48, 0.50, 0.30))
    lathe(cx, [(0.175, 0.0), (0.175, 0.01)], m["black"], "tour_bouche", seg=32, loc=(0.48, 0.50, 0.30 + 0.575))
    # colonne octogonale plombée
    zp = cx.zp
    cyl(cx, 0.19, zp - 0.42, (0, 0, (0.34 + zp - 0.08) / 2), m["lead"], "colonne", verts=8, rot=r8, bevel=0.01)
    cyl(cx, 0.195, 0.06, (0, 0, 0.80), m["yellow"], "colonne_bande", verts=8, rot=r8, bevel=0.003)
    cyl(cx, 0.26, 0.08, (0, 0, zp - 0.04), m["lead"], "couronne", verts=8, rot=r8)


def head_e09(cx):
    m = mats_e09(cx)
    z = cx.zp + 0.32
    cyl(cx, 0.18, 0.14, (0, 0, cx.zp + 0.06), m["lead"], "plateau", verts=8, rot=(0, 0, math.pi / 8))
    # corps en prisme octogonal chanfreiné (axe avant-arrière)
    o = tube_y(cx, 0.30, -0.42, 0.40, z, m["lead"], "corps", verts=8)
    o.rotation_euler = (-math.pi / 2, math.pi / 8, 0)
    o2 = tube_y(cx, 0.30, 0.40, 0.58, z, m["lead"], "chanfrein_av", verts=8, r2=0.18)
    o2.rotation_euler = (-math.pi / 2, math.pi / 8, 0)
    o3 = tube_y(cx, 0.30, -0.42, -0.56, z, m["lead"], "chanfrein_ar", verts=8, r2=0.20)
    o3.rotation_euler = (-math.pi / 2, math.pi / 8, 0)
    ring_y(cx, 0.305, 0.022, -0.05, z, m["yellow"], "bande_jaune")
    # hublot du cœur vert sur le dessus et les flancs
    cyl(cx, 0.12, 0.05, (0, 0.05, z + 0.29), m["lead"], "hublot_dessus_cadre", verts=8)
    cyl(cx, 0.09, 0.02, (0, 0.05, z + 0.32), m["green"], "coeur_dessus", verts=8)
    for s in (-1, 1):
        cyl(cx, 0.09, 0.04, (s * 0.29, 0.05, z), m["lead"], "hublot_flanc_cadre_%d" % s, verts=8, rot=(0, math.pi / 2, 0))
        cyl(cx, 0.065, 0.02, (s * 0.31, 0.05, z), m["green"], "coeur_flanc_%d" % s, verts=8, rot=(0, math.pi / 2, 0))
    tube_y(cx, 0.12, 0.57, 0.62, z, m["lens"], "lentille", verts=8)
    ring_y(cx, 0.13, 0.02, 0.60, z, m["green"], "anneau_lentille")
    # trèfle : 3 pales jaunes sur la face arrière
    halo(cx, (0.0, 0.05, z + 0.32), 1.0)


def piece_e09(cx):
    m = mats_e09(cx)
    for s in (-1, 1):
        x, y = s * 0.80, ty(0.92)
        cyl(cx, 0.10, 0.06, (x, y, 0.03), m["lead"], "event_pied_%d" % s, verts=8)
        cyl(cx, 0.075, 0.40, (x, y, 0.26), m["lead"], "event_fut_%d" % s, verts=16)
        for k in range(6):
            tor(cx, 0.078, 0.018, (x, y, 0.10 + 0.055 * k), m["concrete"], "event_anneau_%d_%d" % (s, k), seg=20)
        cyl(cx, 0.14, 0.05, (x, y, 0.50), m["yellow"], "event_chapeau_%d" % s, verts=16, r2=0.05)
        cyl(cx, 0.08, 0.03, (x, y, 0.46), m["green"], "event_lueur_%d" % s, verts=16, bevel=0)
        halo(cx, (x, y, 0.46), 0.4)


# ================================================================================================
# Époque 10 · Haute technologie (ère IV) : carénages lisses, dômes, antennes ; les corps se lèvent
# ================================================================================================
def mats_e10(cx):
    return dict(fair=metal(cx, "carenage", "#A8ADB3", gain=0.85, rough=0.22, metallic=0.25, grain=0.06, dirt=0.4, seed=23.0),
                black=metal(cx, "noir", "#222428", gain=1.0, rough=0.35, metallic=0.3, grain=0.05, seed=24.0),
                blue=emis(cx, "bleu", "#3AA8FF", strength=1.6))


def base_e10(cx):
    m = mats_e10(cx)
    # 3 pieds courts : vide visible sous le disque (passe 5 : disque relevé de 0,24 à 0,36 et pieds plus écartés ; à 0,24
    # le chant du disque cachait les pieds et le vide, « les corps se lèvent » ne se lisait pas)
    zd = 0.36
    for k in range(3):
        a = math.radians(90 + 120 * k)
        x, y = 0.50 * math.cos(a), 0.50 * math.sin(a)
        strut(cx, (x * 1.36, y * 1.36, 0.02), (x, y, zd + 0.02), 0.055, m["black"], "pied_%d" % k)
        cyl(cx, 0.10, 0.035, (x * 1.36, y * 1.36, 0.0175), m["black"], "patin_%d" % k, verts=16)
        sph(cx, 0.06, (x * 1.18, y * 1.18, zd * 0.45), m["fair"], "genou_%d" % k, seg=16, rings=8)
    lathe(cx, [(0.30, zd), (0.70, zd), (0.76, zd + 0.05), (0.74, zd + 0.12), (0.55, zd + 0.18), (0.0, zd + 0.20)],
          m["fair"], "disque", seg=48)
    lathe(cx, [(0.0, zd - 0.08), (0.30, zd - 0.08), (0.30, zd), (0.0, zd)], m["black"], "moyeu", seg=32)
    # bandeau de voyants bleus (jour) sur le chant avant
    for k in range(5):
        a = math.radians(-120 + 15 * k)
        o = box(cx, (0.11, 0.02, 0.085), (0.755 * math.cos(a), 0.755 * math.sin(a), zd + 0.08), m["blue"], "voyant_%d" % k,
                bevel=0)
        o.rotation_euler = (0, 0, a + math.pi / 2)
    halo(cx, (0.0, -0.80, zd + 0.08), 0.6)
    # cou caréné (passe 5 : rayon 0,10 -> 0,15 et manchon lisse plus haut ; le cou fin donnait une « sucette »)
    zp = cx.zp
    z0 = zd + 0.20
    cyl(cx, 0.15, zp - z0 - 0.10, (0, 0, (z0 + zp - 0.10) / 2), m["black"], "cou", verts=32)
    lathe(cx, [(0.24, zp - 0.16), (0.28, zp - 0.09), (0.21, zp), (0.0, zp)], m["fair"], "collier", seg=32)
    hm = min(0.55, 0.45 * (zp - z0))
    lathe(cx, [(0.0, z0 - 0.02), (0.26, z0 - 0.02), (0.20, z0 + hm * 0.7), (0.165, z0 + hm), (0.15, z0 + hm + 0.02)],
          m["fair"], "manchon", seg=32)


def head_e10(cx):
    m = mats_e10(cx)
    z = cx.zp + 0.34
    cyl(cx, 0.14, 0.12, (0, 0, cx.zp + 0.06), m["black"], "plateau", verts=32)
    # tête-dôme : coque lisse ovoïde allongée vers l'avant
    sph(cx, 0.40, (0, 0.06, z + 0.02), m["fair"], "dome", seg=40, rings=20, scale=(0.85, 1.15, 0.72))
    lathe(cx, [(0.36, 0.0), (0.34, 0.03), (0.0, 0.03)], m["black"], "jupe_dome", seg=40, loc=(0, 0.06, z - 0.10))
    # fente bleue frontale (la lentille de l'époque)
    o = box(cx, (0.36, 0.05, 0.10), (0, 0.50, z + 0.03), m["blue"], "fente", bevel=0)
    o.rotation_euler = (math.radians(-18), 0, 0)
    box(cx, (0.42, 0.04, 0.14), (0, 0.47, z + 0.03), m["black"], "fente_cadre", bevel=0.01, rot=(math.radians(-18), 0, 0))
    # antenne courte à l'arrière
    cyl(cx, 0.012, 0.42, (0.12, -0.26, z + 0.40), m["black"], "antenne", verts=8, bevel=0)
    sph(cx, 0.025, (0.12, -0.26, z + 0.62), m["blue"], "antenne_bout")
    # capteur optique latéral
    sph(cx, 0.07, (0.30, 0.18, z + 0.02), m["black"], "capteur")
    halo(cx, (0.0, 0.56, z + 0.03), 1.0)


def piece_e10(cx):
    m = mats_e10(cx)
    y = ty(0.95)
    o = box(cx, (0.78, 0.30, 0.22), (0.0, y, 0.15), m["fair"], "batterie", bevel=0.06)
    box(cx, (0.70, 0.31, 0.04), (0.0, y, 0.06), m["black"], "batterie_socle", bevel=0.01)
    for k in range(4):
        box(cx, (0.11, 0.02, 0.085), (-0.24 + 0.16 * k, y - 0.155, 0.17), m["blue"], "batterie_led_%d" % k, bevel=0)
    for s in (-1, 1):
        cyl(cx, 0.035, 0.06, (s * 0.25, y + 0.05, 0.29), m["black"], "borne_%d" % s, verts=12)
    strut(cx, (0.25, y + 0.12, 0.28), (0.20, ty(0.50), 0.40), 0.025, m["black"], "cable_batterie")
    halo(cx, (0.0, y - 0.20, 0.17), 0.5)


# ================================================================================================
# Époque 11 · Titane : ailerons triangulaires, silhouette en flèche, structures légères sur pieds
# ================================================================================================
def mats_e11(cx):
    return dict(white=metal(cx, "alliage", "#C9C6BE", gain=0.78, rough=0.28, metallic=0.4, grain=0.08, dirt=0.55,
                            rust="#8E8A80", rust_amount=0.25, seed=25.0),
                ti=metal(cx, "titane", "#8E9AA6", gain=0.95, rough=0.25, metallic=0.85, grain=0.06, seed=26.0),
                dark=flat(cx, "sombre", "#2A2E34", rough=0.4),
                line=emis(cx, "ligne", "#BFE6FF", strength=0.8))


def base_e11(cx):
    m = mats_e11(cx)
    # tripode : 3 pieds en V qui montent vers le mât (vides entre les pieds)
    for k in range(3):
        a = math.radians(90 + 120 * k)
        foot = (0.74 * math.cos(a), 0.74 * math.sin(a), 0.0)
        for d in (-0.12, 0.12):
            f2 = (foot[0] + d * math.cos(a + math.pi / 2), foot[1] + d * math.sin(a + math.pi / 2), 0.03)
            strut(cx, f2, (0.10 * math.cos(a), 0.10 * math.sin(a), 0.78), 0.032, m["white"], "pied_%d_%d" % (k, d > 0))
        cyl(cx, 0.07, 0.04, (foot[0], foot[1], 0.02), m["ti"], "patin_%d" % k, verts=12)
        # aileron de pied (triangle) le long du pied
        plate(cx, [(0.0, 0.0), (0.30, 0.0), (0.0, 0.42)], 0.025, m["white"], "aileron_pied_%d" % k, axis="Y",
              loc=(0.62 * math.cos(a) - 0.0, 0.62 * math.sin(a), 0.02), rot=(0, 0, a + math.pi / 2 + math.pi))
    sph(cx, 0.14, (0, 0, 0.80), m["ti"], "noeud", scale=(1, 1, 0.8))
    # mât élancé
    zp = cx.zp
    cyl(cx, 0.07, zp - 0.96, (0, 0, (0.88 + zp - 0.08) / 2), m["ti"], "mat", verts=16)
    lathe(cx, [(0.0, zp - 0.08), (0.17, zp - 0.08), (0.20, zp - 0.04), (0.0, zp)], m["white"], "collier", seg=32)
    # ligne lumineuse le long du mât
    zl = (0.95 + zp - 0.15) / 2
    box(cx, (0.05, 0.03, max(0.3, zp - 1.25)), (0, -0.075, zl), m["line"], "ligne_mat", bevel=0)
    halo(cx, (0.0, -0.12, zl), 0.5)


def head_e11(cx):
    m = mats_e11(cx)
    z = cx.zp + 0.24
    cyl(cx, 0.12, 0.14, (0, 0, cx.zp + 0.06), m["ti"], "plateau", verts=24)
    # fuseau : profil de révolution le long de Y, pointe avant = lentille
    prof = [(0.0, -0.66), (0.08, -0.60), (0.17, -0.40), (0.21, -0.10), (0.20, 0.20), (0.14, 0.52), (0.06, 0.74),
            (0.0, 0.80)]
    lathe(cx, prof, m["white"], "fuseau", seg=32, loc=(0, 0, z), rot=(-math.pi / 2, 0, 0))
    tube_y(cx, 0.045, 0.74, 0.86, z, m["line"], "lentille_pointe")
    # ailerons triangulaires de queue (dessus et flancs) : silhouette en flèche
    plate(cx, [(0.0, 0.0), (-0.42, 0.0), (-0.52, 0.40)], 0.03, m["white"], "aileron_dessus", axis="X",
          loc=(0, -0.08, z + 0.18))
    for s in (-1, 1):
        plate(cx, [(0.0, 0.0), (-0.40, 0.0), (-0.50, 0.30)], 0.025, m["white"], "aileron_flanc_%d" % s, axis="X",
              loc=(s * 0.17, -0.10, z), rot=(0, math.radians(s * 75), 0))
    plate(cx, [(0.0, 0.0), (0.30, 0.0), (0.05, 0.20)], 0.02, m["ti"], "aileron_nez", axis="X", loc=(0, 0.20, z + 0.18))
    # lignes bleu-blanc qui courent sur les flancs
    for s in (-1, 1):
        o = box(cx, (0.03, 0.62, 0.05), (s * 0.205, 0.05, z + 0.02), m["line"], "ligne_%d" % s, bevel=0)
    halo(cx, (0.0, 0.85, z), 1.0)


def piece_e11(cx):
    m = mats_e11(cx)
    y = ty(0.92)
    plate(cx, [(-0.32, 0.0), (0.36, 0.0), (-0.10, 0.62)], 0.05, m["white"], "aileron_condo", axis="Y", loc=(0.10, y, 0.03))
    box(cx, (0.78, 0.14, 0.05), (0.10, y, 0.025), m["ti"], "aileron_semelle", bevel=0.01)
    o = plate(cx, [(-0.30, 0.0), (0.34, 0.0), (-0.10, 0.58)], 0.012, m["line"], "aileron_ligne", axis="Y",
              loc=(0.10, y - 0.03, 0.05))
    o.scale = (0.85, 1, 0.85)
    halo(cx, (0.05, y - 0.10, 0.25), 0.5)


# ================================================================================================
# Époque 12 · Supraconducteurs : anneaux en lévitation, vides ; noir profond, chrome, givre
# ================================================================================================
def mats_e12(cx):
    return dict(black=metal(cx, "noir", "#26282E", gain=1.4, rough=0.25, metallic=0.6, grain=0.05, seed=27.0),
                chrome=metal(cx, "chrome", "#9AA3AD", gain=1.0, rough=0.12, metallic=1.0, grain=0.04, dirt=0.3, seed=28.0),
                frost=metal(cx, "givre", "#DDEEFF", gain=0.55, rough=0.8, metallic=0.0, grain=0.4, grain_scale=40.0,
                            seed=29.0),
                cyan=emis(cx, "cyan", "#4AF0FF", strength=1.5))


def base_e12(cx):
    m = mats_e12(cx)
    # plinthe basse noire
    cyl(cx, 0.64, 0.14, (0, 0, 0.07), m["black"], "plinthe", verts=6, rot=(0, 0, math.pi / 6), bevel=0.02)
    cyl(cx, 0.56, 0.03, (0, 0, 0.155), m["frost"], "givre_plinthe", verts=6, rot=(0, 0, math.pi / 6), bevel=0.005)
    # anneau chromé en lévitation au-dessus (vide entre plinthe et anneau)
    tor(cx, 0.56, 0.055, (0, 0, 0.42), m["chrome"], "anneau_flottant", seg=64)
    tor(cx, 0.56, 0.018, (0, 0, 0.42), m["cyan"], "anneau_lueur", seg=64, mseg=8)
    # 3 pylônes chromés
    for k in range(3):
        a = math.radians(90 + 120 * k)
        x, y = 0.40 * math.cos(a), 0.40 * math.sin(a)
        box(cx, (0.10, 0.10, 0.62), (x, y, 0.45), m["chrome"], "pylone_%d" % k, bevel=0.012)
        box(cx, (0.115, 0.115, 0.05), (x, y, 0.79), m["black"], "pylone_tete_%d" % k, bevel=0.008)
    # noyau noir vertical (pivot) : bloc flottant au-dessus d'un fût fin
    zp = cx.zp
    cyl(cx, 0.085, zp - 0.78, (0, 0, (0.15 + zp - 0.63) / 2), m["chrome"], "tige", verts=16)
    # passe 5 : 2 anneaux chromés en lévitation autour de la tige (signature d'époque ; la tige seule faisait « sucette »),
    # sans contact (vide de 0,08 entre tige et anneau)
    for k, f in enumerate((0.36, 0.66)):
        zr = 0.15 + (zp - 0.78) * f
        tor(cx, 0.21, 0.04, (0, 0, zr), m["chrome"], "anneau_tige_%d" % k, seg=48)
        tor(cx, 0.21, 0.013, (0, 0, zr + 0.035), m["cyan"], "anneau_tige_lueur_%d" % k, seg=48, mseg=8)
    box(cx, (0.24, 0.24, 0.62), (0, 0, zp - 0.32), m["black"], "noyau", bevel=0.03)
    box(cx, (0.25, 0.25, 0.05), (0, 0, zp - 0.50), m["frost"], "noyau_givre", bevel=0.01)
    halo(cx, (0.0, -0.60, 0.42), 0.6)


def head_e12(cx):
    m = mats_e12(cx)
    zp = cx.zp
    z = zp + 0.62
    # berceau magnétique : 2 bras chromés en fourche, la lentille flotte entre 2 anneaux (vides)
    box(cx, (0.20, 0.20, 0.10), (0, 0, zp + 0.05), m["black"], "plateau", bevel=0.02)
    for s in (-1, 1):
        strut(cx, (s * 0.08, 0.0, zp + 0.08), (s * 0.40, 0.05, z - 0.05), 0.035, m["chrome"], "bras_%d" % s)
        sph(cx, 0.05, (s * 0.40, 0.05, z - 0.05), m["black"], "bras_bout_%d" % s)
    for k, y in enumerate((-0.05, 0.42)):
        tor(cx, 0.32, 0.05, (0, y, z), m["chrome"], "anneau_%d" % k, rot=(math.pi / 2, 0, 0), seg=56)
        tor(cx, 0.27, 0.015, (0, y, z), m["cyan"], "anneau_lueur_%d" % k, rot=(math.pi / 2, 0, 0), seg=56, mseg=8)
    # lentille flottante (sphère aplatie) et noyau noir arrière flottant
    sph(cx, 0.17, (0, 0.20, z), m["cyan"], "lentille", seg=32, rings=16, scale=(1, 0.55, 1))
    tube_y(cx, 0.15, -0.55, -0.22, z, m["black"], "noyau_arriere")
    tube_y(cx, 0.155, -0.40, -0.36, z, m["frost"], "givre_arriere")
    halo(cx, (0.0, 0.20, z), 1.0)


def piece_e12(cx):
    m = mats_e12(cx)
    for s in (-1, 1):
        x, y = s * 0.80, ty(0.90)
        box(cx, (0.16, 0.16, 0.06), (x, y, 0.03), m["black"], "pyl_pied_%d" % s, bevel=0.01)
        box(cx, (0.09, 0.09, 0.46), (x, y, 0.29), m["chrome"], "pyl_%d" % s, bevel=0.01)
        o = box(cx, (0.10, 0.10, 0.10), (x, y, 0.64), m["cyan"], "pyl_cube_%d" % s, bevel=0.01)
        o.rotation_euler = (math.radians(35), math.radians(45), 0)
        halo(cx, (x, y, 0.64), 0.4)


# ================================================================================================
# Époque 13 · Fusion (ère V) : tore de plasma lumineux autour d'une sphère ; trépieds
# ================================================================================================
def mats_e13(cx):
    return dict(cer=metal(cx, "ceramique", "#D9D6CF", gain=0.62, rough=0.28, metallic=0.05, grain=0.08, dirt=0.55, seed=30.0),
                copper=metal(cx, "cuivre", "#B0703A", gain=1.1, rough=0.22, metallic=0.95, grain=0.08, seed=31.0),
                dark=flat(cx, "sombre", "#2A2624", rough=0.4),
                plasma=emis(cx, "plasma", "#FF4FD8", strength=1.5),
                core=emis(cx, "coeur", "#FF9A3A", strength=1.6))


def base_e13(cx):
    m = mats_e13(cx)
    for k in range(3):
        a = math.radians(90 + 120 * k)
        foot = (0.72 * math.cos(a), 0.72 * math.sin(a), 0.0)
        strut(cx, (foot[0], foot[1], 0.04), (0.18 * math.cos(a), 0.18 * math.sin(a), 0.62), 0.05, m["cer"], "pied_%d" % k)
        sph(cx, 0.07, (foot[0], foot[1], 0.05), m["copper"], "rotule_%d" % k)
        sph(cx, 0.05, (0.45 * math.cos(a), 0.45 * math.sin(a), 0.33), m["copper"], "genou_%d" % k)
    sph(cx, 0.30, (0, 0, 0.70), m["cer"], "sphere_moyeu", seg=40, rings=20)
    tor(cx, 0.30, 0.03, (0, 0, 0.70), m["copper"], "ceinture", seg=56)
    # petit tore de plasma horizontal autour du moyeu (signature)
    tor(cx, 0.42, 0.035, (0, 0, 0.70), m["plasma"], "tore_moyeu", seg=64)
    halo(cx, (0.0, -0.45, 0.70), 0.6)
    zp = cx.zp
    # passe 5 : cou 0,10 -> 0,15 en cuivre, gainé de 3 bagues de céramique (injecteurs) ; le cou fin faisait « sucette »
    cyl(cx, 0.15, zp - 1.01, (0, 0, (0.95 + zp - 0.06) / 2), m["copper"], "cou", verts=24)
    for k in range(3):
        zb = 0.95 + (zp - 1.01) * (0.25 + 0.25 * k)
        cyl(cx, 0.19, 0.09, (0, 0, zb), m["cer"], "cou_bague_%d" % k, verts=32, bevel=0.015)
    cyl(cx, 0.24, 0.06, (0, 0, zp - 0.03), m["cer"], "couronne", verts=32)


def head_e13(cx):
    m = mats_e13(cx)
    zp = cx.zp
    z = zp + 0.57
    cyl(cx, 0.13, 0.10, (0, 0, zp + 0.05), m["cer"], "plateau", verts=24)
    # fourche de céramique qui tient le tore
    for s in (-1, 1):
        strut(cx, (s * 0.06, 0.0, zp + 0.09), (s * 0.48, 0.02, z - 0.10), 0.04, m["cer"], "fourche_%d" % s)
    # tore de plasma VERTICAL (plan perpendiculaire au tir), anneau de confinement de céramique
    tor(cx, 0.48, 0.05, (0, 0.02, z), m["cer"], "confinement", rot=(math.pi / 2, 0, 0), seg=64)
    tor(cx, 0.48, 0.085, (0, 0.10, z), m["plasma"], "tore_plasma", rot=(math.pi / 2, 0, 0), seg=64, mseg=14)
    # émetteur au centre : sphère, buse de cuivre, cœur orange
    sph(cx, 0.22, (0, 0.05, z), m["cer"], "emetteur", seg=36, rings=18)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        strut(cx, (0.20 * math.cos(a), 0.05, z + 0.20 * math.sin(a)), (0.44 * math.cos(a), 0.05, z + 0.44 * math.sin(a)),
              0.018, m["copper"], "rayon_%d" % k)
    tube_y(cx, 0.10, 0.20, 0.42, z, m["copper"], "buse", r2=0.06)
    sph(cx, 0.06, (0, 0.44, z), m["core"], "coeur")
    tube_y(cx, 0.12, -0.45, -0.15, z, m["copper"], "injecteur_arriere")
    halo(cx, (0.0, 0.10, z), 1.0)


def piece_e13(cx):
    m = mats_e13(cx)
    x, y = 0.0, ty(0.95)
    for k in range(3):
        a = math.radians(90 + 120 * k)
        cyl(cx, 0.03, 0.12, (x + 0.24 * math.cos(a), y + 0.24 * math.sin(a), 0.06), m["cer"], "pied_tore_%d" % k, verts=10)
    tor(cx, 0.26, 0.06, (x, y, 0.15), m["plasma"], "petit_tore", seg=48)
    tor(cx, 0.26, 0.025, (x, y, 0.21), m["cer"], "petit_tore_cadre", seg=48)
    sph(cx, 0.07, (x, y, 0.15), m["core"], "petit_tore_coeur")
    halo(cx, (x, y, 0.18), 0.6)


# ================================================================================================
# Époque 14 · Orbite : panneaux dorés en ailes, paraboles, balises ; feuille d'or froissée
# ================================================================================================
def mats_e14(cx):
    return dict(gold=metal(cx, "or", "#C9A23A", gain=0.85, rough=0.30, metallic=1.0, grain=0.35, grain_scale=18.0, dirt=0.4,
                           seed=32.0),
                white=metal(cx, "blanc", "#CFCBC2", gain=0.66, rough=0.35, metallic=0.1, grain=0.08, dirt=0.55, seed=33.0),
                cells=metal(cx, "cellules", "#1E2A55", gain=1.4, rough=0.12, metallic=0.6, grain=0.05, seed=34.0),
                red=emis(cx, "balise", "#FF2A2A", strength=1.6),
                blue=emis(cx, "cellule_lueur", "#2F6BFF", strength=1.3))


def base_e14(cx):
    m = mats_e14(cx)
    # plate-forme blanche octogonale sur 4 pieds courts (vides) et feuille d'or
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        strut(cx, (sx * 0.58, sy * 0.58, 0.0), (sx * 0.45, sy * 0.45, 0.24), 0.045, m["white"], "pied_%d" % i)
    cyl(cx, 0.72, 0.12, (0, 0, 0.30), m["white"], "plateforme", verts=8, rot=(0, 0, math.pi / 8), bevel=0.02)
    cyl(cx, 0.66, 0.05, (0, 0, 0.385), m["gold"], "feuille_or", verts=8, rot=(0, 0, math.pi / 8), bevel=0.01)
    # 2 petites ailes de panneaux aux flancs
    for s in (-1, 1):
        o = box(cx, (0.30, 0.50, 0.02), (s * 0.82, 0.10, 0.42), m["cells"], "aile_%d" % s, bevel=0.004)
        o.rotation_euler = (0, math.radians(s * 25), 0)
        o = box(cx, (0.32, 0.52, 0.012), (s * 0.82, 0.10, 0.405), m["gold"], "aile_cadre_%d" % s, bevel=0.003)
        o.rotation_euler = (0, math.radians(s * 25), 0)
    # mât-balise à l'arrière gauche
    cyl(cx, 0.02, 1.25, (-0.45, 0.40, 0.42 + 0.62), m["white"], "mat_balise", verts=10, bevel=0)
    sph(cx, 0.06, (-0.45, 0.40, 1.70), m["red"], "balise")
    halo(cx, (-0.45, 0.40, 1.70), 0.5, color="#FF2A2A")
    # cou blanc et cardan doré
    zp = cx.zp
    cyl(cx, 0.14, zp - 0.49, (0, 0, (0.42 + zp - 0.07) / 2), m["white"], "cou", verts=24)
    # passe 5 : réservoir sphérique doré du kit d'époque, enfilé sur le cou (le cou nu faisait « sucette »)
    zt = 0.42 + 0.42 * (zp - 0.49)
    sph(cx, 0.27, (0, 0, zt), m["gold"], "reservoir", seg=40, rings=20)
    tor(cx, 0.27, 0.022, (0, 0, zt), m["white"], "reservoir_ceinture", seg=48)
    cyl(cx, 0.17, 0.05, (0, 0, zt - 0.27), m["white"], "reservoir_bride_bas", verts=24)
    cyl(cx, 0.17, 0.05, (0, 0, zt + 0.27), m["white"], "reservoir_bride_haut", verts=24)
    tor(cx, 0.20, 0.03, (0, 0, zp - 0.18), m["gold"], "cardan", rot=(math.pi / 2, 0, 0), seg=40)
    cyl(cx, 0.19, 0.07, (0, 0, zp - 0.035), m["white"], "couronne", verts=24)


def head_e14(cx):
    m = mats_e14(cx)
    zp = cx.zp
    z = zp + 0.615
    cyl(cx, 0.14, 0.12, (0, 0, zp + 0.055), m["white"], "plateau", verts=24)
    box(cx, (0.14, 0.24, 0.40), (0, -0.10, zp + 0.30), m["white"], "bras", bevel=0.02)
    # parabole dorée tournée vers l'avant (+Y) : coque de révolution, feuille d'or froissée
    prof = [(0.0, 0.00), (0.18, 0.025), (0.34, 0.09), (0.48, 0.19), (0.50, 0.215)]
    lathe(cx, prof, m["gold"], "parabole", seg=48, loc=(0, -0.06, z), rot=(-math.pi / 2, 0, 0), smooth=50)
    lathe(cx, [(0.0, -0.02), (0.16, -0.01), (0.30, 0.06), (0.30, 0.08), (0.0, 0.0)], m["white"], "dos_parabole", seg=32,
          loc=(0, -0.08, z), rot=(-math.pi / 2, 0, 0))
    tor(cx, 0.50, 0.02, (0, 0.155, z), m["white"], "levre", rot=(math.pi / 2, 0, 0), seg=64)
    # cornet d'émission au foyer, tenu par 3 haubans
    tube_y(cx, 0.06, 0.32, 0.52, z, m["white"], "cornet", r2=0.09)
    sph(cx, 0.07, (0, 0.53, z), m["blue"], "emetteur")
    for k in range(3):
        a = math.pi / 2 + 2 * math.pi * k / 3
        strut(cx, (0.44 * math.cos(a), 0.12, z + 0.44 * math.sin(a)), (0.06 * math.cos(a), 0.40, z + 0.06 * math.sin(a)),
              0.012, m["white"], "hauban_%d" % k)
    # balise rouge sur le dos
    cyl(cx, 0.015, 0.30, (0, -0.30, z + 0.30), m["white"], "mat_tete", verts=8, bevel=0)
    sph(cx, 0.045, (0, -0.30, z + 0.47), m["red"], "balise_tete")
    halo(cx, (0.0, 0.53, z), 1.0, color="#2F6BFF")


def piece_e14(cx):
    m = mats_e14(cx)
    for s in (-1, 1):
        x, y = s * 0.45, ty(0.95)
        cyl(cx, 0.02, 0.22, (x, y + 0.08, 0.11), m["white"], "panneau_pied_%d" % s, verts=8, bevel=0)
        o = box(cx, (0.54, 0.34, 0.025), (x, y, 0.24), m["cells"], "panneau_%d" % s, bevel=0.004)
        o.rotation_euler = (math.radians(38), 0, 0)
        o = box(cx, (0.56, 0.36, 0.012), (x, y + 0.01, 0.228), m["gold"], "panneau_cadre_%d" % s, bevel=0.003)
        o.rotation_euler = (math.radians(38), 0, 0)
        for k in range(3):
            o = box(cx, (0.012, 0.32, 0.03), (x - 0.18 + 0.18 * k, y, 0.243), m["blue"], "panneau_reflet_%d_%d" % (s, k),
                    bevel=0)
            o.rotation_euler = (math.radians(38), 0, 0)
    halo(cx, (0.0, ty(1.0), 0.25), 0.5, color="#2F6BFF")


# ================================================================================================
# Époque 15 · Légende : couronne de flèches, base flottante, halo ; or blanc, nacre
# ================================================================================================
def mats_e15(cx):
    return dict(wgold=metal(cx, "or_blanc", "#E8DCB0", gain=0.62, rough=0.20, metallic=0.95, grain=0.08, dirt=0.5, seed=35.0),
                nacre=metal(cx, "nacre", "#D8D2C8", gain=0.62, rough=0.3, metallic=0.15, grain=0.12, dirt=0.5, seed=36.0),
                light=emis(cx, "lumiere", "#FFF2C0", strength=0.8),
                crys=emis(cx, "cristal_clair", "#FFF2C0", strength=0.55, base=(0.6, 0.55, 0.45)),
                # passe 5 : gain 0,55 -> 0,85 (prismes GRIS TERNES au premier rendu de la passe 4 : la couronne de
                # l'époque la plus claire, cible 108, se lisait en métal gris)
                clear=glass(cx, "cristal_incolore", "#E2DCCB", gain=0.85))


def base_e15(cx):
    m = mats_e15(cx)
    # passe 5 : BASE FLOTTANTE lisible (signature d'époque, bible §5). Passe 4 : disque à 0,36 posé sur un pied de nacre
    # de 0,26 de rayon : vu à 45°, le chant du disque cachait le vide, la base se lisait comme un pied de coupe posé.
    # Ici : une sole basse et étroite (émetteur de lévitation) et le disque d'or blanc nettement au-dessus (vide de 0,52),
    # sans aucun contact ; la tour repart du disque.
    # sole ÉTROITE (rayon 0,26 ; 0,46 au premier essai : vue à 45°, cette rondelle blanche bouchait le vide sous le
    # disque, qui se lisait comme une bobine posée) ; en or blanc, plus sombre que la nacre
    lathe(cx, [(0.0, 0.0), (0.26, 0.0), (0.27, 0.03), (0.22, 0.07), (0.09, 0.10), (0.0, 0.10)], m["wgold"], "sole",
          seg=48)
    tor(cx, 0.16, 0.014, (0, 0, 0.088), m["light"], "sole_emetteur", seg=48, mseg=6)
    zd = 0.62
    lathe(cx, [(0.0, zd), (0.30, zd + 0.01), (0.60, zd + 0.03), (0.66, zd + 0.07), (0.62, zd + 0.12), (0.30, zd + 0.15),
               (0.0, zd + 0.16)], m["wgold"], "disque_flottant", seg=56)
    tor(cx, 0.645, 0.012, (0, 0, zd + 0.07), m["light"], "liseré_disque", seg=64, mseg=6)
    # pointe sous le disque (cône inversé) : le disque « tient » sur le vide
    cyl(cx, 0.16, 0.16, (0, 0, zd - 0.06), m["wgold"], "pointe_dessous", verts=32, r2=0.02, rot=(math.pi, 0, 0), bevel=0)
    # particules (statiques en phase 1), dans le vide entre la sole et le disque
    for k in range(7):
        a = 2.1 * k
        sph(cx, 0.025, (0.70 * math.cos(a), 0.70 * math.sin(a), 0.22 + 0.06 * (k % 3)), m["light"], "particule_%d" % k,
            seg=8, rings=4)
    # flèche centrale (cou) effilée, plus épaisse qu'en passe 4 (0,06 -> 0,10 au plus fin)
    zp = cx.zp
    z0 = zd + 0.15
    lathe(cx, [(0.22, z0), (0.13, z0 + 0.30), (0.10, zp - 0.40), (0.15, zp - 0.25), (0.0, zp - 0.22)], m["wgold"],
          "fleche", seg=32)
    tor(cx, 0.13, 0.022, (0, 0, (z0 + 0.30 + zp - 0.40) / 2), m["light"], "bague_lumiere", seg=32)
    halo(cx, (0.0, -0.40, zd + 0.07), 0.6)


def head_e15(cx):
    m = mats_e15(cx)
    z = cx.zp
    tor(cx, 0.26, 0.045, (0, 0, z), m["wgold"], "anneau_couronne", seg=56)
    sph(cx, 0.15, (0, 0, z + 0.04), m["nacre"], "coeur_couronne", seg=28, rings=14)
    # couronne de prismes émetteurs : 5 flèches inclinées vers l'extérieur, la plus grande vers l'avant (tir)
    spikes = [(90, 0.95, 0.10, -32), (90 + 72, 0.62, 0.07, 22), (90 - 72, 0.62, 0.07, 22), (90 + 144, 0.50, 0.06, 20),
              (90 - 144, 0.50, 0.06, 20)]
    for k, (adeg, h, r, tilt) in enumerate(spikes):
        a = math.radians(adeg)
        x, y = 0.26 * math.cos(a), 0.26 * math.sin(a)
        # inclinaison : vers l'extérieur (tilt > 0) ; l'émetteur principal penche vers l'avant (tilt < 0 = vers +Y)
        o = crystal(cx, r, h, (0, 0, 0), m["clear"], "prisme_%d" % k, tilt=(0, 0), sides=6, base_frac=0.15)
        t = math.radians(abs(tilt))
        sph(cx, r * (0.75 if k == 0 else 0.6), (x + h * math.sin(t) * math.cos(a), y + h * math.sin(t) * math.sin(a),
                                               z + h * math.cos(t)), m["crys"], "pointe_%d" % k, seg=16, rings=8)
        o.matrix_world = (Matrix.Translation((x, y, z)) @ Matrix.Rotation(a - math.pi / 2, 4, "Z") @
                          Matrix.Rotation(-math.radians(abs(tilt)), 4, "X"))
        cyl(cx, r * 1.15, 0.05, (x, y, z + 0.02), m["wgold"], "sertissure_%d" % k, verts=6)
    # halo : anneau lumineux flottant au-dessus de la couronne
    tor(cx, 0.36, 0.022, (0, -0.02, z + 0.62), m["light"], "halo", seg=64, mseg=8)
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.3
        sph(cx, 0.022, (0.42 * math.cos(a), 0.42 * math.sin(a), z + 0.30 + 0.06 * (k % 2)), m["light"], "particule_t_%d" % k,
            seg=8, rings=4)
    halo(cx, (0.0, 0.20, z + 0.40), 1.0)


def piece_e15(cx):
    m = mats_e15(cx)
    # anneau-halo au sol autour du socle (ellipse vue), qui dépasse de l'emprise sur les côtés
    tor(cx, 0.92, 0.022, (0, 0, 0.085), m["light"], "anneau_halo_sol", seg=96, mseg=8)
    tor(cx, 0.92, 0.06, (0, 0, 0.02), m["wgold"], "anneau_halo_berceau", seg=96, mseg=8)
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.2
        sph(cx, 0.03, (1.0 * math.cos(a), 1.0 * math.sin(a), 0.12 + 0.05 * (k % 2)), m["light"], "particule_sol_%d" % k,
            seg=8, rings=4)
    halo(cx, (0.0, -0.98, 0.05), 0.6)


# ================================================================================================
# Assemblage
# ================================================================================================
BASES = {2: base_e02, 3: base_e03, 4: base_e04, 5: base_e05, 6: base_e06, 7: base_e07, 8: base_e08, 9: base_e09,
         10: base_e10, 11: base_e11, 12: base_e12, 13: base_e13, 14: base_e14, 15: base_e15}
HEADS = {2: head_e02, 3: head_e03, 4: head_e04, 5: head_e05, 6: head_e06, 7: head_e07, 8: head_e08, 9: head_e09,
         10: head_e10, 11: head_e11, 12: head_e12, 13: head_e13, 14: head_e14, 15: head_e15}
PIECES = {1: piece_e01, 2: piece_e02, 3: piece_e03, 4: piece_e04, 5: piece_e05, 6: piece_e06, 7: piece_e07, 8: piece_e08,
          9: piece_e09, 10: piece_e10, 11: piece_e11, 12: piece_e12, 13: piece_e13, 14: piece_e14, 15: piece_e15}


def build(S, C, level, part, heading_deg=0.0):
    """Construit la scène d'une pose. Renvoie {'holdout': [...], 'back': [...], 'halos': [...], 'epoch': e}."""
    cx = Ctx(S, C, level)
    e = cx.e
    if level == 1:
        raise ValueError("niveau 1 = sprite vanilla : rien à modéliser")
    if part == "base":
        cx.cur = cx.base
        if level == 2:
            PIECES[1](cx)
        else:
            BASES[e](cx)
            if level % 2 == 0:
                PIECES[e](cx)
        holdout = []
    elif part == "head":
        if level == 2:
            raise ValueError("niveau 2 : tête vanilla")
        cx.cur = cx.base
        BASES[e](cx)
        cx.cur = cx.head
        HEADS[e](cx)
        holdout = list(cx.base)
        bpy.context.view_layer.update()
        s = HEAD_SCALE.get(e, 1.0)
        Ms = Matrix.Translation((0, 0, cx.zp)) @ Matrix.Scale(s, 4) @ Matrix.Translation((0, 0, -cx.zp))
        R = Matrix.Rotation(-math.radians(heading_deg), 4, "Z") @ Ms
        for o in cx.head:
            o.matrix_world = R @ o.matrix_world
        for h in cx.halos:
            if h["head"]:
                h["loc"] = tuple(R @ Vector(h["loc"]))
    else:
        raise ValueError(part)
    bpy.context.view_layer.update()
    # sources du halo : seulement celles de la partie rendue (tête : celles de la tête)
    halos = [h for h in cx.halos if (h["head"] if part == "head" else True)]
    return {"holdout": holdout, "back": list(cx.back), "halos": halos, "epoch": e, "head": list(cx.head),
            "base": list(cx.base)}
