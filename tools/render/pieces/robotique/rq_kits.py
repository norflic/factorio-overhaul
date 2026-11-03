"""KITS des 12 robots et SEGMENTS des 3 géants (s'exécute dans Blender, lot DA-ICONES).

Un kit = une caisse de transport ouverte aux couleurs de la FAMILLE (usine qui la fabrique : Atelier ambre, Hall violet,
Dock bleu, Portique magenta) d'où sort la SIGNATURE du robot, sa pièce la plus reconnaissable sur ses rendus
(fo-logs/2026-11-01_RBV1/<robot>/sprites). Les signatures servent aussi aux technologies (rq_technos.py).
Chaque signature est posée sur z = 0, centrée, d'environ 4 à 5 unités."""
import math
import random

from mathutils import Matrix, Vector

import scene_base as P
from scene_base import B, CY, CYX, SPH, TOR, capte, lathe, pivoter, tube
from rq_couleurs import lum as nom_lum, peint
from rq_pieces import lum

FAMILLE = {
    "steam-trotter": "ambre", "scalehide": "ambre", "coiler": "ambre",
    "needle": "violet", "bellwether": "violet", "chamfer": "violet",
    "trowel": "bleu", "finback": "bleu", "levite": "bleu",
    "toroid": "magenta", "heliast": "magenta", "crowned": "magenta",
}


def lum_fam(famille, force=None):
    return lum(nom_lum(famille), force=force)


# ------------------------------------------------------------------------------------------------------------------
# Signatures
# ------------------------------------------------------------------------------------------------------------------
def sig_trotte():
    """Chaudière de laiton couchée, cerclée de fonte, et sa cheminée en pavillon."""
    CYX(1.15, 3.4, 0, 0, 1.15, "laiton", verts=48, bev=0.03)
    for x in (-1.25, 0.0, 1.25):
        CYX(1.22, 0.2, x, 0, 1.15, "fonte", verts=48, bev=0.02)
    CYX(1.12, 0.14, 1.75, 0, 1.15, "laiton_sombre", verts=48, bev=0.02)
    for k in range(8):
        a = 2 * math.pi * k / 8
        SPH(0.08, 1.84, 0.8 * math.cos(a), 1.15 + 0.8 * math.sin(a), "fonte", seg=10, rings=6)
    CY(0.36, 1.0, 0.75, 0, 2.05, "laiton_sombre", verts=32)
    lathe([(0.34, 0.0), (0.42, 0.45), (0.66, 0.9), (0.98, 1.2), (1.04, 1.32), (0.9, 1.32), (0.58, 1.02), (0.28, 0.7), (0.0, 0.7)],
          0.75, 0, 2.95, "laiton", verts=56)
    CY(0.62, 0.02, 0.75, 0, 3.66, "fond_noir", verts=32, bev=0)
    # manomètre et soupape
    CYX(0.36, 0.14, -0.6, -1.1, 2.0, "laiton", axe="y", verts=24)
    CYX(0.28, 0.02, -0.6, -1.18, 2.0, "alliage_blanc", axe="y", verts=24, bev=0)
    CY(0.12, 0.5, -1.0, 0, 2.2, "laiton_sombre", verts=12)
    tube([(-0.6, -1.0, 1.75), (-0.8, -0.9, 2.1), (-1.0, -0.2, 2.3)], 0.07, "cuivre")


def _plaque(p, n, t, dims, m, inclinaison=14.0):
    """Écaille posée sur une surface : centre p, normale n, tangente t ; relevée de `inclinaison` degrés (tuiles)."""
    n = n.normalized()
    t = (t - n * t.dot(n)).normalized()
    y = n.cross(t)
    M = Matrix((t, y, n)).transposed()
    M = M @ Matrix.Rotation(math.radians(inclinaison), 3, "X")
    o = P.S.box(dims, (0, 0, 0), P.mat(m), bevel_w=0.025)
    o.matrix_world = Matrix.Translation(p + n * dims[2] * 0.5) @ M.to_4x4()
    return o


def sig_ecaille(a=2.3, b=1.75, c=1.55):
    """Carapace bombée d'écailles d'acier sombre qui se chevauchent ; joints orange incandescents dessous ; crête à pointes."""
    s = SPH(1.0, 0, 0, 0, lum("joint_orange", force=1.25), seg=48, rings=24)
    s.scale = (a * 0.97, b * 0.97, c * 0.97)
    rng = random.Random(12)
    for r, (phi, n) in enumerate(((8, 15), (26, 13), (44, 10), (62, 7))):
        f = math.radians(phi)
        for k in range(n):
            th = 2 * math.pi * (k + 0.5 * (r % 2)) / n
            p = Vector((a * math.cos(f) * math.cos(th), b * math.cos(f) * math.sin(th), c * math.sin(f)))
            nv = Vector((math.cos(f) * math.cos(th) / a, math.cos(f) * math.sin(th) / b, math.sin(f) / c))
            tv = Vector((-math.sin(th), math.cos(th), 0.0))
            larg = 2 * math.pi * a * math.cos(f) / n * 0.92
            m = "ecaille_rouille" if rng.random() < 0.28 else "ecaille"
            _plaque(p, nv, tv, (min(larg, 1.2), 0.95, 0.14), m)
    _plaque(Vector((0, 0, c)), Vector((0, 0, 1)), Vector((1, 0, 0)), (1.0, 0.9, 0.16), "ecaille", inclinaison=0)
    for k in range(5):
        x = -1.2 + k * 0.6
        z = c * math.sqrt(max(0.0, 1 - (x / a) ** 2))
        lathe([(0.2, 0.0), (0.0, 0.55)], x, 0, z - 0.05, "fonte", verts=4, lisse=False)
    # bouclier avant (tête)
    B(1.0, 1.6, 0.9, a - 0.15, 0, 0.0, "fonte", bev=0.12)


def sig_bobineur():
    """Tambour de cuivre cerclé, ressort de Tesla argent, anneau en tête et sa sphère bleue, étincelle."""
    CY(1.05, 1.4, 0, 0, 0, "cuivre", verts=48)
    for z in (0.25, 1.15):
        TOR(1.07, 0.09, 0, 0, z, "fonte", minor=10)
    CYX(0.22, 0.12, 0, -1.07, 0.7, lum("voyant_bleu", force=1.3), axe="y", verts=20)
    CY(0.38, 2.4, 0, 0, 1.4, "noir_mat", verts=24)
    pts = []
    tours, z0, z1, r = 6, 1.5, 3.65, 0.78
    for i in range(tours * 12 + 1):
        a = 2 * math.pi * i / 12
        pts.append((r * math.cos(a), r * math.sin(a), z0 + (z1 - z0) * i / (tours * 12)))
    tube(pts, 0.13, "chrome", res=4)
    TOR(0.85, 0.24, 0, 0, 4.0, "chrome", minor=16)
    SPH(0.36, 0, 0, 4.0, lum("voyant_bleu", force=1.4))
    eclair = lum("ligne_bleu_blanc", force=1.5)
    tube([(0.95, 0, 4.1), (1.45, 0.2, 4.45), (1.3, -0.1, 4.75), (1.85, 0.1, 5.1)], 0.05, eclair, res=2)
    tube([(-0.95, 0, 4.0), (-1.4, -0.2, 4.3), (-1.3, 0.1, 4.6)], 0.04, eclair, res=2)


def sig_aiguille():
    """Plateau hexagonal de fonte, grappe de cristaux violets, longue aiguille violette en biais à colliers d'or."""
    lathe([(0, 0), (1.5, 0), (1.5, 0.42), (1.3, 0.58), (0, 0.58)], 0, 0, 0, "fonte", verts=6, lisse=False, bev=0.03, phase=0.5)
    rng = random.Random(3)
    cr = lum("violet_cristal")
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.4
        h = rng.uniform(1.1, 1.7)
        o = lathe([(0.32, 0.0), (0.32, h * 0.7), (0.0, h)], 0.8 * math.cos(a), 0.8 * math.sin(a), 0.5, cr, verts=6, lisse=False)
        o.rotation_euler = (rng.uniform(-0.45, 0.45), rng.uniform(-0.45, 0.45), 0)

    def aiguille():
        CY(0.55, 0.4, 0, 0, 0, "or_sombre", verts=24)
        lathe([(0.46, 0.0), (0.44, 0.5), (0.38, 1.6), (0.28, 3.4), (0.15, 5.0), (0.0, 6.0)], 0, 0, 0.4, "violet_aiguille", verts=32)
        for z in (0.5, 1.6, 2.8):
            TOR(0.36 - z * 0.03, 0.07, 0, 0, z, "or", minor=10)
    pivoter(capte(aiguille), rot=(0, 34, 0), loc=(-0.6, 0, 0.5))


def sig_cloche():
    """Cloche de verre vert à côtes de cuivre, lumière verte interne, épi de cuivre au sommet."""
    prof = [(1.95, 0.0), (2.0, 0.12), (1.82, 0.38), (1.5, 1.0), (1.34, 1.8), (1.18, 2.35), (0.82, 2.78), (0.36, 2.98), (0.0, 3.03)]
    verre = lum("vert_cloche", force=0.95)
    lathe(prof, 0, 0, 0, verre, verts=72)
    for k in range(10):
        a = 2 * math.pi * k / 10
        pts = [((r + 0.04) * math.cos(a), (r + 0.04) * math.sin(a), z) for (r, z) in prof[1:-1]]
        tube(pts, 0.06, "cuivre", res=6)
    TOR(2.0, 0.13, 0, 0, 0.1, "cuivre", minor=12)
    TOR(1.4, 0.08, 0, 0, 1.45, "cuivre", minor=10)
    TOR(1.0, 0.07, 0, 0, 2.6, "cuivre", minor=10)
    CY(0.22, 0.4, 0, 0, 2.95, "cuivre", verts=16)
    lathe([(0.12, 0.0), (0.3, 0.25), (0.0, 1.0)], 0, 0, 3.3, "cuivre", verts=16)
    SPH(0.2, 0, 0, 3.35, "laiton", seg=16, rings=8)


def sig_chanfrein():
    """Socle octogonal à bande jaune, fût de mortier évasé à anneaux d'or, gueule à lueur verte."""
    lathe([(0, 0), (1.95, 0), (1.95, 0.55), (1.7, 0.75), (0, 0.75)], 0, 0, 0, "canon", verts=8, lisse=False, bev=0.03, phase=0.39)
    lathe([(1.97, 0.0), (1.97, 0.16), (0, 0.16)], 0, 0, 0.28, "jaune_danger", verts=8, lisse=False, phase=0.39)

    def fut():
        lathe([(1.05, 0.0), (1.0, 0.6), (0.95, 1.8), (1.05, 2.35), (1.38, 2.85), (1.52, 3.05), (1.5, 3.15), (1.22, 3.12),
               (0.98, 2.8), (0.76, 2.2), (0.72, 1.6), (0.0, 1.6)], 0, 0, 0, "canon", verts=56)
        CY(0.72, 0.03, 0, 0, 1.62, lum("voyant_vert", force=1.4), verts=40, bev=0)
        for k in range(6):
            a = 2 * math.pi * k / 6
            SPH(0.1, 0.4 * math.cos(a), 0.4 * math.sin(a), 1.7, lum("voyant_vert", force=1.6), seg=10, rings=6)
        for z in (0.35, 1.0):
            TOR(1.03, 0.08, 0, 0, z, "or", minor=10)
    pivoter(capte(fut), rot=(24, 0, 0), loc=(0, 0.25, 0.7))


def sig_truelle():
    """Dôme argent, ceinture noire à voyants bleus, parabole sur mât, bras-truelle."""
    CY(1.88, 0.42, 0, 0, 0, "noir_mat", verts=64, bev=0.04)
    for k in range(12):
        a = 2 * math.pi * k / 12
        B(0.3, 0.06, 0.14, 1.9 * math.cos(a), 1.9 * math.sin(a), 0.14, "voyant_bleu", bev=0, rot=(0, 0, math.degrees(a) + 90))
    lathe([(1.82, 0.0), (1.8, 0.3), (1.6, 0.95), (1.25, 1.42), (0.72, 1.74), (0.0, 1.85)], 0, 0, 0.42, "chrome", verts=64)
    for (x, y, l, r) in ((0.6, -1.1, 0.7, 20), (-0.7, -1.0, 0.5, -30)):
        B(l, 0.5, 0.06, x, y, 1.6, "carenage_sombre", bev=0.01, rot=(35, 0, r))
    CY(0.08, 0.7, 0.5, 0.5, 2.0, "alu_sombre", verts=10)

    def parabole():
        lathe([(0.0, 0.0), (0.35, 0.03), (0.7, 0.13), (0.95, 0.28), (0.98, 0.32), (0.7, 0.2), (0.35, 0.1), (0.0, 0.07)], 0, 0, 0,
              "alliage_blanc", verts=40)
        CY(0.04, 0.55, 0, 0, 0.05, "alu_sombre", verts=8)
        SPH(0.08, 0, 0, 0.6, "cable_rouge", seg=10, rings=6)
    pivoter(capte(parabole), rot=(40, 0, -30), loc=(0.5, 0.5, 2.65))
    CY(0.03, 1.2, -0.7, 0.4, 2.0, "alu_sombre", verts=6)
    # bras-truelle à droite
    tube([(1.7, -0.3, 0.6), (2.4, -0.5, 1.2), (2.9, -0.6, 0.6)], 0.12, "titane", res=6)
    B(0.9, 0.08, 0.6, 3.05, -0.6, 0.0, "chrome", bev=0.02, rot=(0, 0, 20))


def _prisme(nom, poly, ep, m, z=0.0):
    """Prisme d'une épaisseur ep (en z) sur un polygone convexe [(x, y), ...]."""
    n = len(poly)
    vs = [(x, y, z) for (x, y) in poly] + [(x, y, z + ep) for (x, y) in poly]
    fs = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, n + j, n + i))
    o = P._maille(nom, vs, fs, m, lisse=False)
    P.S.bevel(o, 0.02)
    return o


def sig_aileron():
    """Chasseur à aile delta (nez vers +x) : fuselage, ailes, dérives, verrière bleue, tuyère allumée."""
    def corps():
        o = lathe([(0.0, 0.0), (0.42, 0.15), (0.55, 0.6), (0.6, 2.0), (0.55, 3.3), (0.4, 4.2), (0.2, 4.85), (0.0, 5.3)],
                  0, 0, 0, "titane", verts=32)
        o.rotation_euler = (0, math.radians(90), 0)
        o.location = (-2.6, 0, 0)
        for s in (-1, 1):
            _prisme("aile", [(-2.3, 0.0), (0.9, 0.0), (-1.9, s * 2.7), (-2.4, s * 2.7)] if s > 0 else
                    [(-2.4, -2.7), (-1.9, -2.7), (0.9, 0.0), (-2.3, 0.0)], 0.1, "alu_brosse", z=-0.12)
            _prisme("plan", [(-2.6, 0.0), (-1.6, 0.0), (-2.4, s * 1.1)] if s > 0 else [(-2.4, -1.1), (-1.6, 0.0), (-2.6, 0.0)],
                    0.08, "titane", z=0.05)
        d = _prisme("derive", [(-2.6, 0.0), (-1.5, 0.0), (-2.5, 1.2)], 0.1, "titane_sombre")
        d.rotation_euler = (math.radians(90), 0, 0)
        d.location = (0, 0.05, 0.2)
        v = SPH(0.5, 0.9, 0, 0.42, lum("fibre", force=0.9), seg=24, rings=12)
        v.scale = (1.6, 0.7, 0.55)
        CYX(0.38, 0.1, -2.62, 0, 0, lum("ligne_bleu_blanc", force=1.4), verts=24, bev=0)
        for s in (-1, 1):
            B(0.6, 0.1, 0.06, -0.3, s * 1.55, 0.0, "cable_rouge" if s > 0 else "voyant_bleu", bev=0)
    pivoter(capte(corps), rot=(0, 0, 0))


def sig_levite():
    """Moyeu noir octogonal, colonne chromée et pile de 3 anneaux cyan lumineux, patin de lévitation."""
    TOR(2.0, 0.16, 0, 0, 0.12, lum("cyan_levite"), minor=12)
    TOR(2.0, 0.24, 0, 0, 0.12, "chrome", minor=12).scale = (1.0, 1.0, 0.5)
    lathe([(0, 0), (1.5, 0), (1.72, 0.3), (1.72, 1.0), (1.25, 1.6), (0.62, 1.85), (0, 1.9)], 0, 0, 0.2, "noir_brillant",
          verts=8, lisse=False, bev=0.03, phase=0.39)
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.39 + math.pi / 8
        B(0.5, 0.06, 0.12, 1.62 * math.cos(a), 1.62 * math.sin(a), 0.85, "voyant_teal", bev=0, rot=(0, 0, math.degrees(a) + 90))
    CY(0.22, 2.8, 0, 0, 1.9, "chrome", verts=16)
    for k in range(3):
        z = 2.45 + k * 0.62
        TOR(0.82, 0.17, 0, 0, z, lum("cyan_levite", force=1.25), minor=12)
        CY(0.32, 0.12, 0, 0, z - 0.06, "chrome", verts=16)
    lathe([(0.3, 0.0), (0.0, 0.45)], 0, 0, 4.7, "noir_brillant", verts=6, lisse=False)


def sig_torique(R=2.55, n=18):
    """Dôme de céramique à épi de cuivre, pris dans un tore de tronçons cuivre, noir et rose lumineux."""
    lathe([(1.6, 0.0), (1.58, 0.35), (1.4, 0.95), (1.05, 1.4), (0.55, 1.64), (0.0, 1.7)], 0, 0, 0.0, "ceramique", verts=64)
    for k in range(7):
        a = 2 * math.pi * k / 7
        B(0.32, 0.26, 0.05, 1.25 * math.cos(a), 1.25 * math.sin(a), 0.98, "noir_mat", bev=0, rot=(0, 30, math.degrees(a)))
    lathe([(0.3, 0.0), (0.0, 0.9)], 0, 0, 1.62, "cuivre", verts=16)
    rose = lum("rose_tore", force=1.3)
    cyc = ("cuivre", "cuivre", "noir_mat", rose)
    for k in range(n):
        a = 2 * math.pi * k / n
        P.S.cylinder(0.42, 2 * math.pi * R / n * 0.9, (R * math.cos(a), R * math.sin(a), 0.62), P.mat(cyc[k % 4]), verts=24,
                     rot=(0, math.radians(90), a + math.pi / 2), bevel_w=0.03)
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.3
        tube([(1.4 * math.cos(a), 1.4 * math.sin(a), 0.5), (R * 0.85 * math.cos(a), R * 0.85 * math.sin(a), 0.6)], 0.1, "noir_mat")


def panneau(x, y, z, w, d, rot=(0, 0, 0)):
    """Panneau solaire : verre bleu foncé, cadre et grille d'alu (posé à plat, centre (x, y), face inférieure à z)."""
    objs = []
    def p():
        B(w, d, 0.08, 0, 0, 0, "panneau_solaire", bev=0.01)
        for s in (-1, 1):
            B(w, 0.07, 0.12, 0, s * d / 2, 0, "alu_brosse", bev=0.01)
            B(0.07, d, 0.12, s * w / 2, 0, 0, "alu_brosse", bev=0.01)
        for k in range(1, 4):
            B(0.04, d, 0.1, -w / 2 + k * w / 4, 0, 0, "alu_brosse", bev=0)
        B(w, 0.04, 0.1, 0, 0, 0, "alu_brosse", bev=0)
    objs = capte(p)
    pivoter(objs, rot=rot, loc=(x, y, z))
    return objs


def sig_heliaste(panneaux=2):
    """Corps doré octogonal, réservoirs d'or, 2 ailes de panneaux solaires bleus (`panneaux` par aile), parabole d'or."""
    lathe([(0, 0), (1.05, 0), (1.15, 0.2), (1.15, 1.25), (0.95, 1.55), (0, 1.6)], 0, 0, 0, "or", verts=8, lisse=False, bev=0.03, phase=0.39)
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.785
        SPH(0.36, 1.15 * math.cos(a), 1.15 * math.sin(a), 0.45, "or_sombre", seg=20, rings=10)
    for s in (-1, 1):
        CYX(0.1, 1.2, s * 1.65, 0, 0.85, "alu_brosse", verts=10)
        for i in range(panneaux):
            panneau(s * (2.85 + i * 1.62), 0, 0.82, 1.55, 1.25, rot=(s * 12, 0, 0))

    def parabole():
        lathe([(0.0, 0.0), (0.5, 0.04), (0.95, 0.18), (1.25, 0.38), (1.28, 0.44), (0.95, 0.26), (0.5, 0.12), (0.0, 0.08)], 0, 0, 0,
              "or", verts=48)
        CY(0.05, 0.75, 0, 0, 0.05, "alu_sombre", verts=8)
        SPH(0.1, 0, 0, 0.82, "or_sombre", seg=10, rings=6)
    pivoter(capte(parabole), rot=(-35, 0, 15), loc=(0, 0.1, 1.65))


def sig_couronne():
    """Tour dorée octogonale à fenêtres en arc, couronne à flèches, flèche centrale, halo d'or."""
    lathe([(0, 0), (1.55, 0), (1.55, 1.15), (1.4, 1.3), (0, 1.3)], 0, 0, 0, "or_sombre", verts=8, lisse=False, bev=0.03, phase=0.39)
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.39 + math.pi / 8
        B(0.34, 0.08, 0.7, 1.45 * math.cos(a), 1.45 * math.sin(a), 0.25, "fond_noir", bev=0, rot=(0, 0, math.degrees(a) + 90))
        lathe([(0.17, 0.0), (0.0, 0.22)], 1.47 * math.cos(a), 1.47 * math.sin(a), 0.95, "fond_noir", verts=4, lisse=False)
    CY(1.42, 0.5, 0, 0, 1.3, "or", verts=48, bev=0.03)
    gemme = lum("rose_tore", force=1.1)
    for k in range(8):
        a = 2 * math.pi * k / 8
        h = 1.25 if k % 2 == 0 else 0.85
        lathe([(0.24, 0.0), (0.0, h)], 1.3 * math.cos(a), 1.3 * math.sin(a), 1.8, "or", verts=6, lisse=False)
        SPH(0.11, 1.44 * math.cos(a + 0.39), 1.44 * math.sin(a + 0.39), 1.55, gemme, seg=10, rings=6)
    lathe([(0.45, 0.0), (0.3, 0.6), (0.0, 2.3)], 0, 0, 1.8, "or", verts=8, lisse=False)
    TOR(1.7, 0.07, 0, 0, 3.75, lum("or_halo"), rot=(12, 0, 0), minor=10)


SIGNATURES = {
    "steam-trotter": sig_trotte, "scalehide": sig_ecaille, "coiler": sig_bobineur, "needle": sig_aiguille,
    "bellwether": sig_cloche, "chamfer": sig_chanfrein, "trowel": sig_truelle, "finback": sig_aileron,
    "levite": sig_levite, "toroid": sig_torique, "heliast": sig_heliaste, "crowned": sig_couronne,
}


# ------------------------------------------------------------------------------------------------------------------
# Caisse et kits
# ------------------------------------------------------------------------------------------------------------------
def caisse(famille, W=4.4, D=3.0, H=1.25):
    """Caisse ouverte : lattes de bois sombre ; poteaux d'angle, sangle et rebord à la couleur de la famille (lisible à 32 px) ;
    voyant de famille en façade."""
    fam, rgb = peint(famille), lum_fam(famille, force=1.3)
    B(W - 0.1, D - 0.1, H - 0.25, 0, 0, 0, "fonte", bev=0.02)
    for k in range(3):
        z = 0.05 + k * (H - 0.1) / 3
        h = (H - 0.1) / 3 - 0.08
        B(W - 0.2, 0.12, h, 0, -D / 2, z, "bois_caisse", bev=0.02)
        B(W - 0.2, 0.12, h, 0, D / 2, z, "bois_caisse", bev=0.02)
        B(0.12, D - 0.2, h, -W / 2, 0, z, "bois_caisse", bev=0.02)
        B(0.12, D - 0.2, h, W / 2, 0, z, "bois_caisse", bev=0.02)
    for sx in (-1, 1):
        for sy in (-1, 1):
            B(0.44, 0.44, H + 0.08, sx * (W / 2 - 0.05), sy * (D / 2 - 0.05), 0, fam, bev=0.05)
    zb = H * 0.3
    B(W + 0.04, 0.06, 0.42, 0, -D / 2 - 0.06, zb, fam, bev=0.01)
    B(W + 0.04, 0.06, 0.42, 0, D / 2 + 0.06, zb, fam, bev=0.01)
    B(0.06, D + 0.04, 0.42, -W / 2 - 0.06, 0, zb, fam, bev=0.01)
    B(0.06, D + 0.04, 0.42, W / 2 + 0.06, 0, zb, fam, bev=0.01)
    for sy in (-1, 1):
        B(W, 0.22, 0.16, 0, sy * D / 2, H - 0.06, fam, bev=0.03)
    for sx in (-1, 1):
        B(0.22, D, 0.16, sx * W / 2, 0, H - 0.06, fam, bev=0.03)
    B(1.1, 0.08, 0.3, 0, -D / 2 - 0.12, H * 0.68, "noir_mat", bev=0.02)
    B(0.9, 0.06, 0.16, 0, -D / 2 - 0.16, H * 0.68 + 0.07, rgb, bev=0)
    return H


# (échelle, décalage x, décalage z, rotation) de la signature de chaque kit : elle domine et peut déborder de la caisse,
# la caisse basse dit « kit » et porte la couleur de la famille.
KIT = {
    "steam-trotter": (1.15, 0.0, -0.6, (0, 0, -8)),
    "scalehide": (1.0, 0.0, 0.0, (0, 0, -14)),
    "coiler": (1.15, 0.0, -0.35, (0, 0, 0)),
    "needle": (1.3, 0.2, -0.3, (0, 0, -20)),
    "bellwether": (1.2, 0.0, -0.5, (0, 0, 0)),
    "chamfer": (1.2, 0.0, -0.6, (0, 0, 0)),
    "trowel": (1.15, -0.25, -0.25, (0, 0, 0)),
    "finback": (1.0, 0.0, 0.25, (0, -10, -24)),
    "levite": (1.1, 0.0, -0.35, (0, 0, 0)),
    "toroid": (0.95, 0.0, -0.1, (0, 0, 0)),
    "heliast": (1.4, 0.0, -0.35, (0, 0, -10)),
    "crowned": (1.15, 0.0, -0.35, (0, 0, 0)),
}


# Signature propre au kit quand celle du robot ne tient pas à 32 px (Héliaste : un seul panneau par aile, corps plus gros).
KIT_SIG = {"heliast": lambda: sig_heliaste(panneaux=1)}


def kit(rid):
    s, dx, dz, rot = KIT[rid]
    H = caisse(FAMILLE[rid])
    pivoter(capte(KIT_SIG.get(rid, SIGNATURES[rid])), rot=rot, loc=(dx, 0, H + dz), s=s)


def _kit(rid):
    return lambda: kit(rid)


# ------------------------------------------------------------------------------------------------------------------
# Segments des géants (une pièce du géant, anneau de levage magenta du portique)
# ------------------------------------------------------------------------------------------------------------------
def anneau_levage(x, y, z):
    B(0.8, 0.5, 0.35, x, y, z, "peint_magenta", bev=0.06)
    TOR(0.42, 0.12, x, y, z + 0.75, "peint_magenta", rot=(90, 0, 0), minor=10)


def seg_torique():
    """Un arc du tore : tronçons cuivre, noir et rose lumineux, brides de fonte aux deux bouts."""
    R, n, a0, a1 = 3.4, 6, math.radians(-55), math.radians(55)
    rose = lum("rose_tore", force=1.3)
    cyc = ("cuivre", "noir_mat", rose, "cuivre", "noir_mat", rose)
    L = R * (a1 - a0) / n
    for k in range(n):
        a = a0 + (k + 0.5) * (a1 - a0) / n
        P.S.cylinder(0.85, L * 0.94, (R * math.cos(a) - R, R * math.sin(a), 0.85), P.mat(cyc[k]), verts=32,
                     rot=(0, math.radians(90), a + math.pi / 2), bevel_w=0.04)
    for a in (a0, a1):
        P.S.cylinder(1.0, 0.3, (R * math.cos(a) - R, R * math.sin(a), 0.85), P.mat("fonte"), verts=32,
                     rot=(0, math.radians(90), a + math.pi / 2), bevel_w=0.04)
    anneau_levage(0.05, 0, 1.6)
    pivoter(list(P.S.piece_objects()), rot=(0, 0, 90))


def seg_heliaste():
    """Une aile solaire repliée en accordéon : 3 panneaux bleus sur un longeron d'or."""
    B(5.2, 0.5, 0.5, 0, 0, 0, "or", bev=0.06)
    for x in (-2.4, 2.4):
        B(0.5, 0.7, 0.7, x, 0, -0.1, "or_sombre", bev=0.06)
    for i in range(3):
        s = 1 if i % 2 == 0 else -1
        panneau(0.0, 0.0, 0.55 + i * 0.5, 4.4, 2.6, rot=(s * 9, 0, 0))
        B(0.2, 0.2, 0.5, 2.25 * s, 1.25 * s, 0.5 + i * 0.5, "or", bev=0.03)
    anneau_levage(0, -0.2, 2.0)


def seg_couronne():
    """Un pan de mur doré à arc gothique (lumière chaude derrière), contreforts, flèche au sommet."""
    B(3.6, 0.7, 3.2, 0, 0, 0, "or", bev=0.06)
    B(1.3, 0.1, 1.7, 0, -0.36, 0.45, "fond_noir", bev=0)
    chaud = lum("voyant_ambre", force=1.2)
    B(1.05, 0.08, 1.5, 0, -0.38, 0.5, chaud, bev=0)
    for s in (-1, 1):
        B(0.95, 0.12, 0.2, s * 0.32, -0.38, 2.05, "or", bev=0.02, rot=(0, s * 48, 0))
        B(0.55, 1.1, 3.6, s * 1.95, -0.1, 0, "or_sombre", bev=0.06)
        lathe([(0.32, 0.0), (0.0, 1.1)], s * 1.95, -0.1, 3.6, "or", verts=4, lisse=False, phase=0.785)
    B(3.8, 0.9, 0.3, 0, 0, 3.2, "or_sombre", bev=0.05)
    lathe([(0.4, 0.0), (0.25, 0.5), (0.0, 1.9)], 0, 0, 3.5, "or", verts=8, lisse=False)
    anneau_levage(0.0, 0.6, 3.5)
