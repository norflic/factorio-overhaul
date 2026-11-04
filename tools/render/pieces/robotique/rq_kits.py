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
from rq_pieces import lum, prisme as _prisme

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


def sig_ecaille(L=5.0, R=1.35):
    """LONG corps cuirassé (environ 2 fois plus long que large, critique : un dôme faisait une tortue), dos en dos d'âne : bandes
    d'écailles d'acier et de cuivre, joints orange incandescents ENTRE les bandes, bloc de nez à l'avant (+x), crête à pointes."""
    a, c = L / 2, R * 1.05
    corps = SPH(1.0, 0, 0, 0, lum("joint_orange", force=0.9), seg=48, rings=24)
    corps.scale = (a * 0.97, R * 0.97, c * 0.97)
    nb, nk = 7, 7
    for i in range(nb):
        x = -a + (i + 0.5) * (2 * a / nb)
        f = math.sqrt(max(0.05, 1 - (x / a) ** 2))
        m = ("ecaille", "cuivre", "ecaille_rouille")[i % 3]
        for k in range(nk):
            phi = math.radians(12 + k * 26)
            p = Vector((x, R * f * math.cos(phi), c * f * math.sin(phi)))
            nv = Vector((x / a ** 2, p.y / R ** 2, p.z / c ** 2))
            tv = Vector((0.0, -math.sin(phi), math.cos(phi)))
            _plaque(p, nv, tv, (max(0.3, R * f * 0.47), (2 * a / nb) * 0.9, 0.14), m, inclinaison=12)
        lathe([(0.2, 0.0), (0.0, 0.5)], x, 0, c * f + 0.08, "fonte", verts=4, lisse=False)
    B(0.9, 1.7, 1.5, a - 0.25, 0, -0.55, "fonte", bev=0.16)
    for s in (-1, 1):
        B(0.06, 0.34, 0.14, a + 0.21, s * 0.42, 0.25, lum("joint_orange", force=1.4), bev=0)


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
    """Corps octogonal à bande jaune ; fût de mortier DROIT et épais à 2 frettes d'or, embouchure à 1,3 fois le fût, incliné
    d'environ 30° (tir de mortier), lueur verte au fond (critique : le pavillon évasé faisait un gramophone)."""
    lathe([(0, 0), (1.95, 0), (1.95, 0.75), (1.7, 0.95), (0, 0.95)], 0, 0, 0, "canon", verts=8, lisse=False, bev=0.03, phase=0.39)
    lathe([(1.97, 0.0), (1.97, 0.18), (0, 0.18)], 0, 0, 0.36, "jaune_danger", verts=8, lisse=False, phase=0.39)

    def fut():
        lathe([(1.0, 0.0), (1.0, 2.7), (1.3, 2.76), (1.32, 3.15), (1.0, 3.22), (0.78, 3.12), (0.76, 1.6), (0.0, 1.6)], 0, 0, 0,
              "canon", verts=56)
        CY(0.75, 0.03, 0, 0, 1.62, lum("voyant_vert", force=1.4), verts=40, bev=0)
        for k in range(6):
            a = 2 * math.pi * k / 6
            SPH(0.1, 0.4 * math.cos(a), 0.4 * math.sin(a), 1.7, lum("voyant_vert", force=1.6), seg=10, rings=6)
        for z in (0.75, 1.95):
            TOR(1.04, 0.11, 0, 0, z, "or", minor=10)
        for s in (-1, 1):
            CYX(0.32, 0.45, s * 1.15, 0, 0.55, "fonte", verts=20)
    pivoter(capte(fut), rot=(12, 30, 0), loc=(-0.3, 0.2, 0.95))


def sig_truelle():
    """Dôme argent ; anneau de voyants bleus à sa base (signature du sprite) ; petite parabole de 3/4, creux sombre et bras de
    cornet ; antenne fouet (critique : la parabole de face faisait une horloge, le câble latéral un bec de bouilloire)."""
    CY(1.88, 0.42, 0, 0, 0, "noir_mat", verts=64, bev=0.04)
    TOR(1.9, 0.1, 0, 0, 0.21, lum("voyant_bleu", force=1.3), minor=10)
    for k in range(12):
        a = 2 * math.pi * k / 12
        B(0.36, 0.08, 0.16, 1.95 * math.cos(a), 1.95 * math.sin(a), 0.13, "voyant_bleu", bev=0, rot=(0, 0, math.degrees(a) + 90))
    lathe([(1.82, 0.0), (1.8, 0.3), (1.6, 0.95), (1.25, 1.42), (0.72, 1.74), (0.0, 1.85)], 0, 0, 0.42, "chrome", verts=64)
    for (x, y, l, r) in ((0.6, -1.1, 0.7, 20), (-0.7, -1.0, 0.5, -30)):
        B(l, 0.5, 0.06, x, y, 1.6, "carenage_sombre", bev=0.01, rot=(35, 0, r))
    CY(0.09, 0.55, 0.55, 0.45, 2.05, "alu_sombre", verts=10)

    def parabole():
        o = lathe([(0.0, 0.0), (0.32, 0.03), (0.56, 0.11), (0.68, 0.2), (0.7, 0.25), (0.64, 0.26), (0.55, 0.18), (0.31, 0.1), (0.0, 0.07)],
                  0, 0, 0, "alliage_blanc", verts=40)
        o.data.materials.append(P.mat("fond_noir"))
        for poly in o.data.polygons:
            if poly.index >= 5 * 40:
                poly.material_index = 1
        tube([(0.62, 0, 0.25), (0.3, 0, 0.55), (0.0, 0, 0.62)], 0.035, "alu_sombre", res=6)
        CY(0.08, 0.16, 0, 0, 0.56, "alu_sombre", verts=10)
    pivoter(capte(parabole), rot=(40, 0, 60), loc=(0.55, 0.45, 2.55))
    CY(0.03, 1.2, -0.7, 0.4, 2.0, "alu_sombre", verts=6)


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


def sig_heliaste(panneaux=1, w=1.85, d=1.75, k=1.45):
    """Corps doré octogonal (k fois l'ancien), réservoirs d'or, ailes de panneaux solaires FACE CAMÉRA relevées en V (critique :
    vus par la tranche, ils ne faisaient qu'un trait à 32 px), parabole d'or."""
    lathe([(0, 0), (1.05 * k, 0), (1.15 * k, 0.2 * k), (1.15 * k, 1.25 * k), (0.95 * k, 1.55 * k), (0, 1.6 * k)], 0, 0, 0, "or",
          verts=8, lisse=False, bev=0.03, phase=0.39)
    for j in range(4):
        a = 2 * math.pi * j / 4 + 0.785
        SPH(0.36 * k, 1.15 * k * math.cos(a), 1.15 * k * math.sin(a), 0.45 * k, "or_sombre", seg=20, rings=10)
    for s in (-1, 1):
        CYX(0.12, 0.7, s * (1.15 * k + 0.3), 0, 0.85 * k, "alu_brosse", verts=10)
        for i in range(panneaux):
            cx = s * (1.15 * k + 0.6 + w / 2 + i * (w + 0.1))
            panneau(cx, 0, 0.85 * k - 0.4, w, d, rot=(62, -s * 22, 0))

    def parabole():
        lathe([(0.0, 0.0), (0.5, 0.04), (0.95, 0.18), (1.25, 0.38), (1.28, 0.44), (0.95, 0.26), (0.5, 0.12), (0.0, 0.08)], 0, 0, 0,
              "or", verts=48)
        CY(0.05, 0.75, 0, 0, 0.05, "alu_sombre", verts=8)
        SPH(0.1, 0, 0, 0.82, "or_sombre", seg=10, rings=6)
    pivoter(capte(parabole), rot=(-35, 0, 15), loc=(0, 0.1, 1.6 * k), s=0.85)


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


def sig_bobineur_robot():
    """Le Bobineur entier, pour sa technologie (critique : une colonne Tesla seule, sans corps ni pattes) : corps HORIZONTAL de
    cuivre à ailettes de radiateur, nez-foret, ressort de Tesla vertical, anneau et sphère bleus ; posé sur z = 0."""
    CYX(1.0, 2.6, 0, 0, 1.0, "cuivre", verts=40)
    for k in range(7):
        CYX(1.14, 0.1, -1.0 + k * 0.33, 0, 1.0, "alu_brosse", verts=40)
    CYX(0.95, 0.22, -1.42, 0, 1.0, "fonte", verts=40)
    o = lathe([(0.85, 0.0), (0.55, 0.55), (0.0, 1.3)], 1.3, 0, 1.0, "chrome", verts=24)
    o.rotation_euler = (0, math.radians(90), 0)
    CY(0.3, 1.9, -0.2, 0, 1.85, "noir_mat", verts=24)
    pts = []
    for i in range(5 * 12 + 1):
        a = 2 * math.pi * i / 12
        pts.append((-0.2 + 0.62 * math.cos(a), 0.62 * math.sin(a), 2.05 + 1.6 * i / 60))
    tube(pts, 0.12, "chrome", res=4)
    TOR(0.72, 0.21, -0.2, 0, 3.95, "chrome", minor=16)
    SPH(0.32, -0.2, 0, 3.95, lum("voyant_bleu", force=1.4))
    tube([(0.55, 0, 4.05), (1.0, 0.2, 4.35), (0.9, -0.1, 4.6), (1.35, 0.1, 4.9)], 0.05, lum("ligne_bleu_blanc", force=1.5), res=2)


SIGNATURES = {
    "steam-trotter": sig_trotte, "scalehide": sig_ecaille, "coiler": sig_bobineur, "needle": sig_aiguille,
    "bellwether": sig_cloche, "chamfer": sig_chanfrein, "trowel": sig_truelle, "finback": sig_aileron,
    "levite": sig_levite, "toroid": sig_torique, "heliast": sig_heliaste, "crowned": sig_couronne,
}


# ------------------------------------------------------------------------------------------------------------------
# Caisse et kits
# ------------------------------------------------------------------------------------------------------------------
def caisse(famille, W=4.4, D=3.0, H=1.9):
    """Caisse ouverte, parois à environ 1/3 de la hauteur de l'icône (critique : un plateau bas faisait un présentoir) : 4 rangs de
    lattes de bois sombre, poteaux d'angle, sangle et rebord à la couleur de la famille, voyant de famille en façade."""
    fam, rgb = peint(famille), lum_fam(famille, force=1.3)
    B(W - 0.1, D - 0.1, H - 0.25, 0, 0, 0, "fonte", bev=0.02)
    for k in range(4):
        z = 0.05 + k * (H - 0.1) / 4
        h = (H - 0.1) / 4 - 0.09
        B(W - 0.2, 0.12, h, 0, -D / 2, z, "bois_caisse", bev=0.02)
        B(W - 0.2, 0.12, h, 0, D / 2, z, "bois_caisse", bev=0.02)
        B(0.12, D - 0.2, h, -W / 2, 0, z, "bois_caisse", bev=0.02)
        B(0.12, D - 0.2, h, W / 2, 0, z, "bois_caisse", bev=0.02)
    for sx in (-1, 1):
        for sy in (-1, 1):
            B(0.46, 0.46, H + 0.08, sx * (W / 2 - 0.05), sy * (D / 2 - 0.05), 0, fam, bev=0.05)
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
    "steam-trotter": (1.15, 0.0, -0.95, (0, 0, -8)),
    "scalehide": (1.0, 0.0, 0.2, (0, 0, -18)),
    "coiler": (1.15, 0.0, -0.7, (0, 0, 0)),
    "needle": (1.3, 0.2, -0.65, (0, 0, -20)),
    "bellwether": (1.2, 0.0, -0.9, (0, 0, 0)),
    "chamfer": (1.15, 0.0, -0.95, (0, 0, 0)),
    "trowel": (1.15, 0.0, -0.6, (0, 0, 0)),
    "finback": (1.0, 0.0, 1.3, (0, -25, -24)),
    "levite": (1.1, 0.0, -0.7, (0, 0, 0)),
    "toroid": (0.95, 0.0, -0.45, (0, 0, 0)),
    "heliast": (1.0, 0.0, -0.75, (0, 0, -6)),
    "crowned": (1.15, 0.0, -0.7, (0, 0, 0)),
}


def berceau_aileron(H, dz, s):
    """Berceau du kit Aileron : 2 montants sombres de la caisse au ventre de l'avion (nez relevé de 25°, lacet de -24°)."""
    cp, sp = math.cos(math.radians(25)), math.sin(math.radians(25))
    cl, sl = math.cos(math.radians(-24)), math.sin(math.radians(-24))
    for x in (-0.7, 0.7):
        px, haut = s * x * cp, H + dz + s * (x * sp - 0.5)
        B(0.24, 0.24, haut - (H - 0.1), px * cl, px * sl, H - 0.1, "titane_sombre", bev=0.04)
        B(0.6, 0.5, 0.12, px * cl, px * sl, haut - 0.06, "titane_sombre", bev=0.03)


def kit(rid):
    s, dx, dz, rot = KIT[rid]
    H = caisse(FAMILLE[rid])
    if rid == "finback":
        berceau_aileron(H, dz, s)
    pivoter(capte(SIGNATURES[rid]), rot=rot, loc=(dx, 0, H + dz), s=s)


def _kit(rid):
    return lambda: kit(rid)


# ------------------------------------------------------------------------------------------------------------------
# Segments des géants (une pièce du géant, anneau de levage magenta du portique)
# ------------------------------------------------------------------------------------------------------------------
def anneau_levage(x, y, z):
    B(0.8, 0.5, 0.35, x, y, z, "peint_magenta", bev=0.06)
    TOR(0.42, 0.12, x, y, z + 0.75, "peint_magenta", rot=(90, 0, 0), minor=10)


def seg_torique():
    """Un cinquième du tore du Torique, à grand rayon (courbure douce), vu de 3/4 par-dessus : 4 tronçons SÉPARÉS, courts et épais
    (cuivre, noir, rose allumé, cuivre), joints visibles sur une âme sombre, brides boulonnées aux 2 bouts, crochet magenta au
    milieu (contre-relecture : un coude de tuyau)."""
    R, a0, a1, rt = 5.5, math.radians(-36), math.radians(36), 0.95
    cyc = ("cuivre", "noir_mat", lum("rose_tore", force=1.35), "cuivre")
    n = len(cyc)
    pas = (a1 - a0) / n
    for k in range(1, n):
        a = a0 + k * pas
        P.S.cylinder(rt * 0.55, R * pas * 0.4, (R * math.cos(a) - R, R * math.sin(a), rt), P.mat("fonte"), verts=24,
                     rot=(0, math.radians(90), a + math.pi / 2), bevel_w=0.02)
    for k in range(n):
        a = a0 + (k + 0.5) * pas
        mat = cyc[k] if not isinstance(cyc[k], str) else P.mat(cyc[k])
        P.S.cylinder(rt, R * pas * 0.78, (R * math.cos(a) - R, R * math.sin(a), rt), mat, verts=40,
                     rot=(0, math.radians(90), a + math.pi / 2), bevel_w=0.06)
    for a, sens in ((a0, -1), (a1, 1)):
        cx, cy = R * math.cos(a) - R, R * math.sin(a)
        t = Vector((-math.sin(a), math.cos(a), 0.0)) * sens
        u = Vector((math.cos(a), math.sin(a), 0.0))
        P.S.cylinder(rt + 0.3, 0.26, (cx + t.x * 0.05, cy + t.y * 0.05, rt), P.mat("fonte"), verts=40,
                     rot=(0, math.radians(90), a + math.pi / 2), bevel_w=0.04)
        for j in range(8):
            b = 2 * math.pi * j / 8
            q = Vector((cx, cy, rt)) + (u * math.cos(b) + Vector((0, 0, 1)) * math.sin(b)) * (rt + 0.16) + t * 0.2
            SPH(0.1, q.x, q.y, q.z, "vis", seg=10, rings=6)
    TOR(rt * 0.62, 0.14, 0.0, 0.0, rt, "peint_magenta", rot=(0, 90, 90), minor=10)
    anneau_levage(0.0, 0.0, rt * 1.55)
    pivoter(list(P.S.piece_objects()), rot=(0, 0, 80))


def panneau_epais(w, d, ep=0.22):
    """Panneau solaire épais (épaisseur visible) : dos alu sombre, verre bleu, cadre et grille d'alu ; centré, face inférieure à 0."""
    B(w, d, ep, 0, 0, 0, "alu_sombre", bev=0.03)
    B(w - 0.12, d - 0.12, 0.05, 0, 0, ep, "panneau_solaire", bev=0.01)
    for k in range(1, 3):
        B(0.05, d - 0.12, 0.07, -w / 2 + k * w / 3, 0, ep, "alu_brosse", bev=0)
    for k in range(1, 4):
        B(w - 0.12, 0.05, 0.07, 0, -d / 2 + k * d / 4, ep, "alu_brosse", bev=0)


def seg_heliaste():
    """Aile solaire repliée en ACCORDÉON (critique : un panneau plat se confondait avec le panneau solaire vanilla) : 3 panneaux
    épais en zigzag (silhouette en W), charnières d'or, longeron d'or dessous, anneau de levage magenta sur le longeron."""
    d, prof, ang = 1.7, 2.4, math.radians(46)
    pts = [(-2.0, 0.75)]
    for i in range(3):
        sgn = 1 if i % 2 == 0 else -1
        x0, z0 = pts[-1]
        pts.append((x0 + d * math.cos(ang), z0 + sgn * d * math.sin(ang)))
    for i in range(3):
        (x0, z0), (x1, z1) = pts[i], pts[i + 1]
        tilt = math.degrees(math.atan2(z1 - z0, x1 - x0))
        pivoter(capte(panneau_epais, d, prof), rot=(0, -tilt, 0), loc=((x0 + x1) / 2, 0, (z0 + z1) / 2))
    for (x, z) in pts[1:3]:
        CYX(0.15, prof + 0.15, x, 0, z + 0.1, "or", axe="y", verts=16)
    xa, xb = pts[0][0] - 0.3, pts[-1][0] + 1.3
    B(xb - xa, 0.5, 0.42, (xa + xb) / 2, 0, -0.1, "or", bev=0.06)
    for (x, z) in (pts[0], pts[2]):
        B(0.24, 0.24, z, x, 0, 0.0, "or_sombre", bev=0.03)
    anneau_levage(xb - 0.55, 0.0, 0.32)
    pivoter(list(P.S.piece_objects()), rot=(0, 0, 8))


def seg_couronne():
    """Pan de la couronne du Couronné (REFAIT, critique : un cadenas, du bois) : arc d'anneau en OR franc, fenêtre en lancette
    gothique haute et pointue (meneau, remplage, vitrail ambre sombre), flèches sur la crête, flèche centrale plus haute que le
    mur, anneau de levage sur un angle."""
    R, span, n, H, ep = 5.0, math.radians(64), 5, 3.2, 0.55
    Ls = 2 * R * math.sin(span / n / 2) * 1.04
    for k in range(n):
        a = -span / 2 + (k + 0.5) * span / n
        x, y = R * math.sin(a), R - R * math.cos(a)
        rz = math.degrees(a)
        B(Ls, ep, H, x, y, 0.0, "or_mur", bev=0.04, rot=(0, 0, rz))
        B(Ls, ep + 0.16, 0.42, x, y, 0.0, "or_sombre", bev=0.04, rot=(0, 0, rz))
        B(Ls, ep + 0.14, 0.3, x, y, H - 0.05, "or_sombre", bev=0.04, rot=(0, 0, rz))
        h = 2.6 if k == n // 2 else (1.1 if k % 2 == 0 else 0.8)
        lathe([(0.3, 0.0), (0.18, h * 0.4), (0.0, h)], x, y, H + 0.25, "or", verts=6, lisse=False)
    gemme = lum("rose_tore", force=1.1)
    SPH(0.16, 0, 0, H + 0.6, gemme, seg=12, rings=8)
    # fenêtre en lancette sur le pan central (face -y)
    arc = [(-0.62, 0.0), (0.62, 0.0), (0.62, 1.45), (0.5, 1.85), (0.3, 2.15), (0.0, 2.35), (-0.3, 2.15), (-0.5, 1.85), (-0.62, 1.45)]
    cadre = [(x * 1.22, z * 1.08 - 0.08) for (x, z) in arc]
    for poly, m, y0, e in ((cadre, "or_sombre", ep / 2, 0.07), (arc, lum("vitrail"), ep / 2 + 0.07, 0.03)):
        o = _prisme("lancette", poly, e, m, z=y0, bev=0.01)
        o.rotation_euler = (math.radians(90), 0, 0)
        o.location = (0, 0, 0.55)
    B(0.09, 0.08, 1.75, 0, -ep / 2 - 0.12, 0.55, "or", bev=0.01)
    TOR(0.2, 0.05, 0, -ep / 2 - 0.12, 0.55 + 1.95, "or", rot=(90, 0, 0), minor=8)
    for s in (-1, 1):
        B(0.32, 0.05, 0.05, s * 0.18, -ep / 2 - 0.12, 0.55 + 1.6, "or", bev=0, rot=(0, s * 40, 0))
    a = span / 2
    anneau_levage(R * math.sin(a) - 0.3, R - R * math.cos(a), H + 0.2)


