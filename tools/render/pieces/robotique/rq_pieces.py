"""Icônes des PIÈCES de robots, des circuits, du silicium et des bobinages (s'exécute dans Blender, lot DA-ICONES).
Chaque fonction modèle un objet d'environ 5,5 unités de large (règle d'échelle de calcul/scene_base : 1 unité = 11 px à 64 px)."""
import math
import random

import scene_base as P
from scene_base import B, CY, CYX, SPH, TOR, capte, lathe, pivoter, roche, tube
from rq_couleurs import LUM


def lum(nom, mode="face", force=None, z0=0.0, z1=1.0, cle=None):
    c, b, f = LUM[cle or nom]
    return P.mat_lum("l_" + nom + mode, c, b, force if force is not None else f, mode=mode, z0=z0, z1=z1)


def mat_verre(nom, rgb, rough=0.06, ior=1.82):
    """Cristal translucide (transmission) : on voit à travers lui ce qu'il contient (cœur lumineux du barreau laser)."""
    m = P.bpy.data.materials.new(nom)
    nt, N, L = P.S._nodes(m)
    p = N["Principled BSDF"]
    p.inputs["Base Color"].default_value = tuple(rgb) + (1,)
    p.inputs["Roughness"].default_value = rough
    p.inputs["IOR"].default_value = ior
    p.inputs["Transmission Weight"].default_value = 1.0
    return m


def mat_irise(nom, R):
    """Miroir de silicium sombre à BANDE IRISÉE bleu-violet-or en diagonale (couleur de base d'un métal : elle teinte le reflet)."""
    m = P.bpy.data.materials.new(nom)
    nt, N, L = P.S._nodes(m)
    p = N["Principled BSDF"]
    p.inputs["Metallic"].default_value = 0.85
    p.inputs["Roughness"].default_value = 0.10
    tc = N.new("ShaderNodeTexCoord")
    sz = N.new("ShaderNodeSeparateXYZ")
    L.new(tc.outputs["Object"], sz.inputs[0])
    mx = N.new("ShaderNodeMath")
    mx.operation = "MULTIPLY_ADD"
    L.new(sz.outputs["X"], mx.inputs[0])
    mx.inputs[1].default_value = 0.6 / (2 * R)
    my = N.new("ShaderNodeMath")
    my.operation = "MULTIPLY_ADD"
    L.new(sz.outputs["Y"], my.inputs[0])
    my.inputs[1].default_value = 0.8 / (2 * R)
    L.new(mx.outputs[0], my.inputs[2])
    mx.inputs[2].default_value = 0.5
    rampe = N.new("ShaderNodeValToRGB")
    r = rampe.color_ramp
    r.elements[0].position, r.elements[0].color = 0.0, (0.16, 0.20, 0.30, 1)
    r.elements[1].position, r.elements[1].color = 1.0, (0.16, 0.20, 0.30, 1)
    for pos, c in ((0.36, (0.16, 0.20, 0.30, 1)), (0.46, (0.10, 0.22, 0.75, 1)), (0.55, (0.42, 0.12, 0.70, 1)), (0.64, (0.85, 0.55, 0.10, 1)),
                   (0.74, (0.16, 0.20, 0.30, 1))):
        e = r.elements.new(pos)
        e.color = c
    L.new(my.outputs[0], rampe.inputs["Fac"])
    L.new(rampe.outputs["Color"], p.inputs["Base Color"])
    return m


def engrenage(r, h, n, x, y, z, m, dent=0.22, moyeu="chrome"):
    """Roue dentée d'axe Z : disque, n dents carrées, moyeu."""
    CY(r - dent * 0.6, h, x, y, z, m, verts=48, bev=0.02)
    for k in range(n):
        a = 2 * math.pi * k / n
        B(dent * 1.3, dent * 1.1, h, x + (r - dent * 0.35) * math.cos(a), y + (r - dent * 0.35) * math.sin(a), z, m, bev=0.02,
          rot=(0, 0, math.degrees(a)))
    CY(r * 0.32, h + 0.08, x, y, z, moyeu, verts=24, bev=0.02)


def prisme(nom, poly, ep, m, z=0.0, bev=0.02):
    """Prisme d'épaisseur ep (en z) sur un polygone convexe [(x, y), ...], face inférieure à z."""
    n = len(poly)
    vs = [(x, y, z) for (x, y) in poly] + [(x, y, z + ep) for (x, y) in poly]
    fs = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, n + j, n + i))
    o = P._maille(nom, vs, fs, m, lisse=False)
    if bev:
        P.S.bevel(o, bev)
    return o


# ------------------------------------------------------------------------------------------------------------------
# Pièces de robots
# ------------------------------------------------------------------------------------------------------------------
def servo():
    """Carter LISSE en alu brossé (2 ailettes en pied seulement : 9 ailettes faisaient un ressort, critique), embout bleu,
    réducteur sombre, roues de laiton, grand palonnier blanc en croix qui déborde du réducteur, 3 fils."""
    CY(1.25, 0.32, 0, 0, -0.32, "moyeu_bleu", verts=48, bev=0.03)
    CY(1.2, 2.7, 0, 0, 0, "alu_brosse", verts=48, bev=0.03)
    for z in (0.22, 0.52):
        TOR(1.25, 0.085, 0, 0, z, "alu_sombre", minor=10)
    B(3.4, 2.5, 0.75, 0.6, 0, 2.7, "titane_sombre", bev=0.08)
    engrenage(1.0, 0.28, 14, 1.3, 0.05, 3.45, "laiton")
    engrenage(0.5, 0.28, 9, -0.3, -0.45, 3.45, "laiton_sombre")
    CY(0.28, 0.6, 1.3, 0.05, 3.7, "chrome", verts=20)
    a = math.radians(28)
    B(4.7, 0.78, 0.32, 1.3, 0.05, 4.2, "alliage_blanc", bev=0.1, rot=(0, 0, 28))
    B(2.8, 0.78, 0.32, 1.3, 0.05, 4.2, "alliage_blanc", bev=0.1, rot=(0, 0, 118))
    for t in (-2.0, -1.4, 1.4, 2.0):
        CY(0.12, 0.04, 1.3 + t * math.cos(a), 0.05 + t * math.sin(a), 4.5, "fond_noir", verts=12, bev=0)
    for i, c in enumerate(("cable_rouge", "cable_gris", "cable_jaune")):
        tube([(-1.2, -0.25 + i * 0.25, 2.9), (-1.9, -0.25 + i * 0.3, 2.4), (-2.3, -0.4 + i * 0.35, 1.2)], 0.09, c)


def ic_servo_motor():
    pivoter(capte(servo), rot=(0, 0, 0))


def capteur():
    """Oeil de robot : boîtier sombre, bague chromée, grosse lentille cyan, iris et pupille ; oscillateur argent à côté."""
    lathe([(0, 0), (1.95, 0), (2.15, 0.2), (2.15, 1.15), (1.95, 1.38), (0, 1.38)], 0, 0, 0, "noir_mat", verts=72)
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.3
        B(0.55, 0.4, 1.0, 2.1 * math.cos(a), 2.1 * math.sin(a), 0.18, "alu_sombre", bev=0.05, rot=(0, 0, math.degrees(a)))
    TOR(1.72, 0.16, 0, 0, 1.4, "chrome", minor=14)
    lentille = lum("cristal", force=0.85)
    lathe([(1.55, 0), (1.45, 0.3), (1.05, 0.58), (0.5, 0.72), (0, 0.76)], 0, 0, 1.3, lentille, verts=72)
    TOR(0.92, 0.07, 0, 0, 1.86, "noir_mat", minor=10)
    CY(0.36, 0.06, 0, 0, 2.02, "fond_noir", verts=32, bev=0)
    CY(0.12, 0.03, -0.18, 0.18, 2.08, "alliage_blanc", verts=16, bev=0)
    # oscillateur à cristal en capsule argent sur le flanc
    B(0.75, 1.0, 0.55, 2.45, 0.2, 0.42, "chrome", bev=0.2)
    B(0.85, 1.1, 0.12, 2.45, 0.2, 0.32, "fond_noir", bev=0.02)


def ic_optical_sensor():
    pivoter(capte(capteur), rot=(58, 0, 14))


def controleur():
    """Boîtier de commande : boîte plate en alu à COUVERCLE LISSE (plaque d'étiquette en relief), pattes de fixation, GROS
    connecteur noir trapézoïdal multibroche en façade d'où sort UN câble noir épais, 2 voyants (contre-relecture : les ailettes
    et les 3 fils colorés le confondaient avec le radiateur et le commutateur réseau du calcul)."""
    B(4.4, 3.0, 1.25, 0, 0, 0, "alu_brosse", bev=0.16)
    B(2.6, 1.5, 0.07, -0.3, 0.35, 1.25, "etiquette", bev=0.02)
    for k in range(3):
        B(1.8 - k * 0.4, 0.1, 0.02, -0.55 + k * 0.2, 0.62 - k * 0.27, 1.32, "marquage", bev=0)
    for sx in (-1, 1):
        B(0.75, 3.4, 0.16, sx * 2.45, 0, 0, "alu_sombre", bev=0.03)
        for sy in (-1, 1):
            CY(0.13, 0.2, sx * 2.55, sy * 1.35, 0.0, "fond_noir", verts=12, bev=0)
    trap = [(-1.35, 0.0), (1.35, 0.0), (1.1, 0.95), (-1.1, 0.95)]
    o = prisme("connecteur", trap, 0.62, "noir_mat", z=1.5, bev=0.06)
    o.rotation_euler = (math.radians(90), 0, 0)
    o.location = (-0.55, 0, 0.16)
    for row, n in ((0, 8), (1, 7)):
        for k in range(n):
            B(0.13, 0.06, 0.13, -0.55 - (n - 1) * 0.135 + k * 0.27, -2.14, 0.38 + row * 0.32, "or", bev=0)
    B(0.34, 0.12, 0.34, 1.2, -1.53, 0.5, "voyant_vert", bev=0.03)
    B(0.34, 0.12, 0.34, 1.75, -1.53, 0.5, "voyant_ambre", bev=0.03)
    tube([(-1.95, -1.85, 0.55), (-2.3, -2.6, 0.4), (-2.6, -3.25, 0.05)], 0.2, "cable_gris", res=8)


def ic_controller():
    pivoter(capte(controleur), rot=(0, 0, -14))


def noyau():
    """Noyau de pilotage : boîtier noir blindé à arêtes d'or, 2 yeux cyan en façade, gyroscope d'or allumé dessus."""
    B(3.6, 3.2, 2.4, 0, 0, 0, "noir_mat", bev=0.28)
    for sx in (-1, 1):
        B(0.22, 0.22, 2.3, sx * 1.75, -1.55, 0.05, "or", bev=0.05)
        B(0.22, 0.22, 2.3, sx * 1.75, 1.55, 0.05, "or", bev=0.05)
        B(0.22, 3.2, 0.22, sx * 1.75, 0, 2.25, "or", bev=0.05)
        B(3.6, 0.22, 0.22, 0, sx * 1.55, 2.25, "or", bev=0.05)
    oeil = lum("fibre", force=1.1)
    for sx in (-1, 1):
        CYX(0.5, 0.3, sx * 0.85, -1.62, 1.15, "chrome", axe="y", verts=32)
        CYX(0.38, 0.32, sx * 0.85, -1.66, 1.15, oeil, axe="y", verts=32)
    for k in range(4):
        B(1.4, 0.06, 0.12, 0, -1.62, 0.3 + k * 0.12, "alu_sombre", bev=0)
    # gyroscope
    CY(0.55, 0.3, 0, 0, 2.4, "titane_sombre", verts=32)
    CY(0.14, 1.2, 0, 0, 2.6, "chrome", verts=16)
    TOR(1.3, 0.11, 0, 0, 3.55, "or", rot=(90, 0, 25), minor=12)
    TOR(1.05, 0.10, 0, 0, 3.55, "or", rot=(0, 90, 25), minor=12)
    TOR(0.8, 0.08, 0, 0, 3.55, "or_sombre", rot=(30, 0, 0), minor=12)
    SPH(0.42, 0, 0, 3.55, lum("voyant_bleu", force=1.3))


def ic_guidance_core():
    pivoter(capte(noyau), rot=(0, 0, 0))


def actionneur():
    """Vérin à aimants (axe x), GROS (critique : il se lisait comme une résistance) : 3 paires d'anneaux rouges et bleus épais,
    flasques alu boulonnées, tige chromée, chape en fourche franche avec son axe, oeil arrière."""
    R = 1.55
    for k in range(6):
        CYX(R, 0.6, -1.55 + k * 0.62, 0, 0, "aimant_rouge" if k % 2 == 0 else "aimant_bleu", verts=56, bev=0.04)
    for x in (-2.2, 1.9):
        CYX(R + 0.1, 0.36, x, 0, 0, "alu_brosse", verts=56, bev=0.05)
        for k in range(6):
            a = math.pi / 6 + k * math.pi / 3
            CYX(0.11, 0.46, x, 1.38 * math.cos(a), 1.38 * math.sin(a), "vis", verts=10)
    CYX(0.46, 2.0, 3.05, 0, 0, "chrome", verts=32)
    B(0.5, 1.4, 1.0, 4.2, 0, -0.5, "titane_sombre", bev=0.06)
    for s in (-1, 1):
        B(1.1, 0.34, 1.0, 4.9, s * 0.53, -0.5, "titane_sombre", bev=0.06)
    CYX(0.2, 1.7, 5.05, 0, 0, "chrome", axe="y", verts=16)
    B(0.6, 0.9, 0.9, -2.7, 0, -0.45, "titane_sombre", bev=0.08)
    TOR(0.5, 0.17, -3.25, 0, 0, "titane_sombre", rot=(90, 0, 0), minor=10)


def ic_magnetic_actuator():
    pivoter(capte(actionneur), rot=(0, -26, -36))


def barreau():
    """Barreau de grenat lilas SOMBRE et saturé, ligne de lumière vive au coeur (dégradé de face) ; faces d'extrémité en miroirs
    polis sertis d'une bague fine (critique : les 2 bagues du milieu et les capuchons mats en faisaient un fusible)."""
    CYX(0.78, 4.8, 0, 0, 0, mat_verre("grenat", (0.42, 0.10, 0.80)), verts=48, bev=0.03)
    CYX(0.2, 4.7, 0, 0, 0, lum("lilas_yag", force=2.2), verts=16, bev=0)
    for x in (-2.48, 2.48):
        CYX(0.86, 0.2, x, 0, 0, "chrome", verts=48, bev=0.03)
        CYX(0.7, 0.04, x + (0.11 if x > 0 else -0.11), 0, 0, "miroir", verts=48, bev=0)


def ic_ndyag_rod():
    pivoter(capte(barreau), rot=(0, -10, 30))


def tete_laser(faisceau=1.6, rayon0=0.38, nez=1.15, lueur=False):
    """Module laser (axe x, nez vers +x) : culasse à ailettes, 2 bobines de cuivre, nez chromé, lentille rouge, faisceau rouge.
    lueur : faisceau fin et saturé avec une gaine translucide (icône de l'objet ; contre-relecture : le cône opaque faisait une
    pointe de crayon) ; par défaut, celui de la technologie « Entraînement magnétique » (VALIDE)."""
    CYX(1.05, 1.6, -1.9, 0, 0, "noir_mat", verts=40, bev=0.04)
    for k in range(7):
        CYX(1.3, 0.08, -2.55 + k * 0.2, 0, 0, "alu_brosse", verts=40, bev=0.01)
    CYX(0.8, 2.2, 0.0, 0, 0, "titane_sombre", verts=40, bev=0.03)
    for x in (-0.55, 0.45):
        CYX(1.0, 0.7, x, 0, 0, "cuivre", verts=40, bev=0.03)
        for k in range(5):
            TOR(1.0, 0.04, x - 0.28 + k * 0.14, 0, 0, "or_sombre", rot=(0, 90, 0), minor=8)
    k = nez / 1.15
    lathe([(0.85, 0), (0.85, 0.3 * k), (0.62, 0.9 * k), (0.55, 1.15 * k), (0, 1.15 * k)], 1.05, 0, 0, "chrome", verts=40).rotation_euler = (0, math.radians(90), 0)
    xl = 1.05 + nez
    CYX(0.6, 0.06, xl + 0.02, 0, 0, lum("rouge_laser", force=1.5), verts=32, bev=0)
    if faisceau > 0 and not lueur:
        rayon = lum("rouge_laser", mode="z", force=1.6, z0=0.0, z1=faisceau)
        o = lathe([(rayon0, 0.0), (rayon0 * 0.2 / 0.38, faisceau * 0.65), (rayon0 * 0.05 / 0.38, faisceau)], xl + 0.05, 0, 0, rayon, verts=16)
        o.rotation_euler = (0, math.radians(90), 0)
    elif faisceau > 0:
        coeur = lum("faisceau", mode="z", z0=faisceau, z1=0.0)
        o = lathe([(rayon0, 0.0), (rayon0 * 0.8, faisceau * 0.75), (rayon0 * 0.3, faisceau)], xl + 0.05, 0, 0, coeur, verts=16)
        o.rotation_euler = (0, math.radians(90), 0)
        o.visible_shadow = False
    B(2.6, 1.2, 0.3, -0.6, 0, -1.25, "alu_sombre", bev=0.05)


def ic_laser_module():
    """Tête de PROFIL sur la diagonale (critique : vue dans l'axe, elle se confondait avec le capteur optique)."""
    pivoter(capte(tete_laser, 3.2, 0.1, 0.7, True), rot=(0, 14, -62))


# ------------------------------------------------------------------------------------------------------------------
# Circuits
# ------------------------------------------------------------------------------------------------------------------
def carte_nue():
    """Carte imprimée nue (âge 4), vue plongeante : plaque verte, grille de trous percés, grosses pastilles étamées, pistes
    larges, connecteur de bord doré sur toute l'arête avant ; aucune puce (critique : se distinguer du contrôleur et de la
    carte mère)."""
    B(5.4, 3.8, 0.18, 0, 0, 0, "pcb_vert", bev=0.03)
    pistes = [(-1.3, 1.0, 2.2, 0), (-0.15, 0.25, 1.5, 90), (1.0, -0.45, 2.3, 0), (2.4, 0.45, 1.8, 90), (-2.2, 0.15, 1.3, 90)]
    for (x, y, l, r) in pistes:
        B(l, 0.24, 0.03, x, y, 0.18, "etain", bev=0, rot=(0, 0, r))
    for (x, y) in ((-2.4, 1.0), (-0.15, 1.0), (-0.15, -0.45), (2.4, -0.45), (2.4, 1.35), (-2.2, -0.5)):
        CY(0.36, 0.05, x, y, 0.18, "etain", verts=28, bev=0)
        CY(0.12, 0.06, x, y, 0.19, "fond_noir", verts=12, bev=0)
    for i in range(4):
        for j in range(3):
            x, y = 0.45 + i * 0.45, 0.35 + j * 0.45
            CY(0.17, 0.04, x, y, 0.18, "etain", verts=16, bev=0)
            CY(0.1, 0.06, x, y, 0.19, "fond_noir", verts=12, bev=0)
    for sx in (-1, 1):
        CY(0.26, 0.04, sx * 2.4, 1.6 if sx < 0 else -0.05, 0.18, "etain", verts=24, bev=0)
    for k in range(15):
        B(0.24, 0.9, 0.03, -2.45 + k * 0.35, -1.42, 0.18, "or", bev=0)


def ic_printed_circuit_board():
    pivoter(capte(carte_nue), rot=(0, 0, 18))


def oscillateur():
    """Boîtier HC-49 en ARGENT BROSSÉ clair, dessus arrondi, socle sombre, 2 longues pattes d'or fines ; dans la fenêtre, un DISQUE
    de quartz cyan incliné (sa tranche, plus sombre, se voit) tenu par 2 fils de contact fins (contre-relecture : un aplat pâle
    faisait une LED)."""
    W, H, r, ep = 2.8, 3.0, 1.0, 1.15
    pts = [(-W / 2, 0.0), (W / 2, 0.0)]
    for k in range(9):
        a = math.radians(k * 90 / 8)
        pts.append((W / 2 - r + r * math.cos(a), H - r + r * math.sin(a)))
    for k in range(9):
        a = math.radians(90 + k * 90 / 8)
        pts.append((-W / 2 + r + r * math.cos(a), H - r + r * math.sin(a)))
    o = prisme("hc49", pts, ep, "argent_hc49", z=-ep / 2, bev=0.06)
    o.rotation_euler = (math.radians(90), 0, 0)
    B(W + 0.25, ep + 0.25, 0.32, 0, 0, -0.32, "noir_mat", bev=0.05)
    for sx in (-1, 1):
        CY(0.07, 2.3, sx * 0.75, 0, -2.6, "or", verts=10)
    zf, yf = 1.55, -ep / 2
    TOR(0.98, 0.08, 0, yf - 0.03, zf, "chrome", rot=(90, 0, 0), minor=10)
    CYX(0.94, 0.04, 0, yf - 0.01, zf, "fond_noir", axe="y", verts=48, bev=0)
    d = CYX(0.7, 0.12, 0, yf - 0.12, zf, lum("quartz2"), axe="y", verts=48, bev=0.02)
    d.rotation_euler = (math.radians(68), 0, math.radians(-20))
    t = TOR(0.7, 0.05, 0, yf - 0.12, zf, "noir_mat", minor=8)
    t.rotation_euler = (math.radians(68), 0, math.radians(-20))
    for sx in (-1, 1):
        tube([(sx * 0.5, yf - 0.18, zf - 0.35), (sx * 0.58, yf - 0.1, zf - 0.7), (sx * 0.62, yf - 0.03, zf - 0.88)], 0.035, "or", res=6)


def ic_crystal_oscillator():
    pivoter(capte(oscillateur), rot=(0, 0, 24))


# ------------------------------------------------------------------------------------------------------------------
# Silicium
# ------------------------------------------------------------------------------------------------------------------
def ic_metallurgical_silicon():
    """3 blocs EMPILÉS (2 en bas, 1 dessus), de tailles inégales, à reflets métalliques bleutés (critique : en Y, un shuriken)."""
    roche(1.45, -1.05, 0.25, 0.95, "silicium_met", 31, ecrase=0.75, rugueux=0.3, subdiv=1)
    roche(1.15, 1.25, -0.2, 0.8, "silicium_met", 32, ecrase=0.8, rugueux=0.3, subdiv=1)
    roche(1.0, 0.15, 0.05, 2.2, "silicium_met", 34, ecrase=0.85, rugueux=0.28, subdiv=1)


def troncon_poly(L, R, graine):
    """Tronçon de barreau Siemens (axe x) : âme, GROS nodules de chou-fleur (4 rangs), bouts cassés à plat à section claire."""
    rng = random.Random(graine)
    CYX(R, L, 0, 0, 0, "polysilicium", verts=32)
    for i in range(4):
        x = -L / 2 + L * (i + 0.5) / 4
        for k in range(7):
            a = 2 * math.pi * k / 7 + rng.uniform(0, 0.6) + i * 0.45
            r = R * rng.uniform(0.4, 0.52)
            SPH(r, x + rng.uniform(-0.15, 0.15), (R - r * 0.35) * math.cos(a), (R - r * 0.35) * math.sin(a), "polysilicium", seg=20, rings=10)
    for s in (-1, 1):
        CYX(R * 0.98, 0.04, s * (L / 2 + 0.02), 0, 0, "silicium_casse", verts=32, bev=0)


def ic_pure_silicon():
    """2 tronçons CROISÉS en X (critique : parallèles, ils faisaient des saucisses et rappelaient le lingot du calcul)."""
    pivoter(capte(troncon_poly, 4.8, 0.72, 5), rot=(0, 0, 34), loc=(0, 0, 0.8))
    pivoter(capte(troncon_poly, 4.8, 0.72, 6), rot=(0, 0, -34), loc=(0, 0, 2.15))


def tranche_nue(R=2.6, h=0.14):
    """Tranche nue : disque à méplat taillé en corde droite, miroir sombre à reflet irisé (couche mince)."""
    m = mat_irise("m_tranche_irisee", R)
    demi = math.radians(26)
    a0, a1 = -math.pi / 2 + demi, 3 * math.pi / 2 - demi
    n = 90
    pts = [(R * math.cos(a0 + (a1 - a0) * i / n), R * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]
    prisme("tranche", pts, h, m, bev=0.02)


def ic_silicon_wafer():
    """Pile de 3 tranches nues, moins exposée (critique : des assiettes blanches), méplat en corde droite, reflet irisé."""
    for i in range(3):
        pivoter(capte(tranche_nue), rot=(0, 0, 8 + i * 9), loc=(i * 0.18, i * 0.32, i * 0.5))


# ------------------------------------------------------------------------------------------------------------------
# Bobinages
# ------------------------------------------------------------------------------------------------------------------
def bobineau():
    """Bobineau d'axe x : fil laqué rouge cuivré, joues noires, un bout libre en boucle."""
    for x in (-1.75, 1.75):
        CYX(2.15, 0.28, x, 0, 0, "noir_mat", verts=64, bev=0.04)
        CYX(0.5, 0.36, x, 0, 0, "alu_sombre", verts=24, bev=0.02)
    CYX(1.55, 3.22, 0, 0, 0, "laque_cuivre", verts=64, bev=0.02)
    for k in range(16):
        TOR(1.56, 0.045, -1.5 + k * 0.2, 0, 0, "laque_cuivre", rot=(0, 90, 0), minor=8)
    tube([(0.9, -0.6, 1.45), (1.3, -1.5, 1.6), (0.6, -2.4, 1.0), (-0.4, -2.3, 0.4), (-0.8, -2.0, -0.6)], 0.09, "laque_cuivre")


def ic_enameled_wire():
    pivoter(capte(bobineau), rot=(0, 0, -30))


def bobine():
    """Bobine de moteur : noyau en E de tôles feuilletées (axe y = empilement), enroulement de cuivre sur la branche du milieu."""
    n = 8
    for k in range(n):
        y = -0.7 + k * 0.2
        m = "tole" if k % 2 == 0 else "alu_sombre"
        B(4.6, 0.17, 0.8, 0, y, 0.0, m, bev=0.01)
        for x in (-1.95, 0.0, 1.95):
            B(0.7, 0.17, 2.6, x, y, 0.8, m, bev=0.01)
    CY(1.3, 2.1, 0, 0, 0.95, "cuivre", verts=48, bev=0.03)
    for k in range(11):
        TOR(1.32, 0.06, 0, 0, 1.05 + k * 0.18, "cuivre", minor=8)
    tube([(0.9, -0.95, 2.9), (1.3, -1.8, 3.2), (1.9, -2.2, 2.8)], 0.07, "cuivre")
    tube([(-0.9, -0.95, 2.9), (-1.3, -1.8, 3.3), (-2.0, -2.1, 3.1)], 0.07, "cuivre")


def ic_coil():
    pivoter(capte(bobine), rot=(0, 0, 22))





def ruban3(points, larg, m):
    """Ruban plat qui suit des points (x, y, z) et s'étend de larg vers le haut (une face, épaissie par SOLIDIFY)."""
    vs, fs = [], []
    for (x, y, z) in points:
        vs.append((x, y, z))
        vs.append((x, y, z + larg))
    for i in range(len(points) - 1):
        fs.append((2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1))
    o = P._maille("ruban", vs, fs, m)
    o.modifiers.new("ep", "SOLIDIFY").thickness = 0.05
    return o


def galette_ruban():
    """3 galettes de ruban YBCO empilées : la tranche montre les couches (critique : un disque plat se lisait comme un CD) ;
    bout libre large qui se relève ; givre en liseré cyan sur la tranche seulement ; moyeu bleu."""
    for k in range(3):
        z = k * 0.44
        CY(2.3, 0.38, 0, 0, z, "ruban_ybco", verts=96, bev=0.02)
        if k < 2:
            CY(2.26, 0.06, 0, 0, z + 0.38, "ruban_sombre", verts=96, bev=0)
    zt = 2 * 0.44 + 0.38
    for k in range(6):
        TOR(1.0 + k * 0.22, 0.014, 0, 0, zt, "ruban_sombre", minor=6)
    CY(0.85, zt + 0.14, 0, 0, -0.06, "moyeu_bleu", verts=48, bev=0.04)
    CY(0.35, zt + 0.18, 0, 0, -0.08, "fond_noir", verts=24, bev=0.02)
    TOR(2.31, 0.035, 0, 0, 0.63, lum("givre_lum"), minor=8)
    pts = []
    for i in range(14):
        t = i / 13
        a = -0.9 + t * 1.4
        r = 2.32 + t * t * 1.3
        pts.append((r * math.cos(a), r * math.sin(a) - t * 0.4, zt - 0.5 + t * t * 1.4))
    ruban3(pts, 0.6, "alu_brosse")


def ic_superconducting_tape():
    pivoter(capte(galette_ruban), rot=(0, 0, 10))
