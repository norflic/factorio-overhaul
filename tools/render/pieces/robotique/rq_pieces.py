"""Icônes des PIÈCES de robots, des circuits, du silicium et des bobinages (s'exécute dans Blender, lot DA-ICONES).
Chaque fonction modèle un objet d'environ 5,5 unités de large (règle d'échelle de calcul/scene_base : 1 unité = 11 px à 64 px)."""
import math
import random

import scene_base as P
import scene_objets as O
from scene_base import B, CY, CYX, SPH, TOR, capte, lathe, pivoter, roche, tube
from rq_couleurs import LUM


def lum(nom, mode="face", force=None, z0=0.0, z1=1.0, cle=None):
    c, b, f = LUM[cle or nom]
    return P.mat_lum("l_" + nom + mode, c, b, force if force is not None else f, mode=mode, z0=z0, z1=z1)


def engrenage(r, h, n, x, y, z, m, dent=0.22, moyeu="chrome"):
    """Roue dentée d'axe Z : disque, n dents carrées, moyeu."""
    CY(r - dent * 0.6, h, x, y, z, m, verts=48, bev=0.02)
    for k in range(n):
        a = 2 * math.pi * k / n
        B(dent * 1.3, dent * 1.1, h, x + (r - dent * 0.35) * math.cos(a), y + (r - dent * 0.35) * math.sin(a), z, m, bev=0.02,
          rot=(0, 0, math.degrees(a)))
    CY(r * 0.32, h + 0.08, x, y, z, moyeu, verts=24, bev=0.02)


# ------------------------------------------------------------------------------------------------------------------
# Pièces de robots
# ------------------------------------------------------------------------------------------------------------------
def servo():
    """Carter alu à ailettes, embout bleu, réducteur sombre, roue de laiton, palonnier noir en croix."""
    CY(1.25, 0.32, 0, 0, -0.32, "moyeu_bleu", verts=48, bev=0.03)
    CY(1.2, 2.7, 0, 0, 0, "alu_brosse", verts=48, bev=0.03)
    for k in range(6):
        TOR(1.25, 0.075, 0, 0, 0.35 + k * 0.38, "alu_sombre", minor=10)
    B(3.4, 2.5, 0.75, 0.6, 0, 2.7, "titane_sombre", bev=0.08)
    engrenage(1.0, 0.28, 14, 1.3, 0.05, 3.45, "laiton")
    engrenage(0.5, 0.28, 9, -0.3, -0.45, 3.45, "laiton_sombre")
    CY(0.22, 0.5, 1.3, 0.05, 3.7, "chrome", verts=20)
    B(3.0, 0.5, 0.22, 1.3, 0.05, 4.1, "alliage_blanc", bev=0.06, rot=(0, 0, 28))
    B(1.8, 0.5, 0.22, 1.3, 0.05, 4.1, "alliage_blanc", bev=0.06, rot=(0, 0, 118))
    for t in (-1.05, 1.05):
        a = math.radians(28)
        CY(0.09, 0.03, 1.3 + t * math.cos(a), 0.05 + t * math.sin(a), 4.32, "fond_noir", verts=12, bev=0)
    for i, c in enumerate(("cable_rouge", "cable_gris", "cable_jaune")):
        tube([(-1.2, -0.25 + i * 0.25, 2.9), (-1.9, -0.25 + i * 0.3, 2.4), (-2.3, -0.4 + i * 0.35, 1.2)], 0.08, c)


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
    """Calculateur de bord : carte verte, gros microcontrôleur à coeur ambre, barrette de broches, voyants."""
    B(5.2, 3.8, 0.18, 0, 0, 0, "pcb_vert", bev=0.03)
    for (x, y, l, r) in ((-1.5, 1.2, 1.6, 0), (1.6, -1.15, 1.6, 0), (-2.0, -0.4, 1.4, 90), (2.1, 0.6, 1.2, 90), (0.0, -1.55, 2.6, 0)):
        B(l, 0.08, 0.02, x, y, 0.18, "or", bev=0, rot=(0, 0, r))
    S = 2.1
    B(S, S, 0.3, 0, 0, 0.26, "puce_noire", bev=0.05)
    O.pattes(S, S, 6, 0.42, 0.18, ((1, 0), (-1, 0), (0, 1), (0, -1)), z=0.22)
    B(1.2, 1.2, 0.06, 0, 0, 0.56, "logique", bev=0.02)
    B(0.5, 0.4, 0.04, -0.2, 0.2, 0.62, "logique_clair", bev=0.01)
    # barrette de broches, au bord du fond
    B(4.2, 0.5, 0.5, 0, 1.55, 0.18, "noir_mat", bev=0.04)
    for k in range(10):
        B(0.13, 0.13, 0.5, -1.9 + k * 0.42, 1.55, 0.6, "or", bev=0.01)
    # voyants et condensateurs
    B(0.34, 0.34, 0.18, -2.1, -1.4, 0.18, "voyant_vert", bev=0.03)
    B(0.34, 0.34, 0.18, -1.6, -1.4, 0.18, "voyant_ambre", bev=0.03)
    CY(0.28, 0.6, 2.05, -0.95, 0.18, "condensateur", verts=24)
    CY(0.28, 0.6, 2.05, -0.2, 0.18, "condensateur", verts=24)
    B(0.8, 0.4, 0.3, -1.9, 0.2, 0.18, "chrome", bev=0.15)


def ic_controller():
    pivoter(capte(controleur), rot=(0, 0, 16))


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
    """Vérin à aimants (axe x) : anneaux rouges et bleus alternés, flasques alu, tige chromée, chapes."""
    for k in range(6):
        CYX(0.98, 0.42, -1.45 + k * 0.46, 0, 0, "aimant_rouge" if k % 2 == 0 else "aimant_bleu", verts=48, bev=0.03)
    for x in (-2.1, 1.35):
        CYX(1.06, 0.32, x, 0, 0, "alu_brosse", verts=48, bev=0.04)
        for k in range(4):
            a = math.pi / 4 + k * math.pi / 2
            CYX(0.09, 0.42, x, 0.85 * math.cos(a), 0.85 * math.sin(a), "vis", verts=10)
    CYX(0.32, 2.2, 2.5, 0, 0, "chrome", verts=32)
    # chape avant et chape arrière
    B(0.6, 0.7, 0.75, 3.75, 0, -0.38, "titane_sombre", bev=0.08)
    CYX(0.16, 0.9, 3.85, 0, 0, "chrome", axe="y", verts=16)
    B(0.5, 0.6, 0.6, -2.55, 0, -0.3, "titane_sombre", bev=0.08)
    TOR(0.4, 0.12, -3.0, 0, 0, "titane_sombre", rot=(90, 0, 0), minor=10)


def ic_magnetic_actuator():
    pivoter(capte(actionneur), rot=(0, -16, -28))


def barreau():
    """Barreau de grenat lilas lumineux (axe x), bagues-miroirs aux bouts, 2 colliers dorés."""
    CYX(0.7, 4.6, 0, 0, 0, lum("lilas_yag"), verts=40, bev=0.03)
    for x in (-2.45, 2.45):
        CYX(0.82, 0.38, x, 0, 0, "chrome", verts=40, bev=0.04)
        CYX(0.6, 0.06, x + (0.21 if x > 0 else -0.21), 0, 0, "alliage_blanc", verts=40, bev=0)
    for x in (-1.0, 1.0):
        TOR(0.74, 0.08, x, 0, 0, "or", rot=(0, 90, 0), minor=10)


def ic_ndyag_rod():
    pivoter(capte(barreau), rot=(0, -18, 32))


def tete_laser():
    """Module laser (axe x, nez vers +x) : culasse à ailettes, 2 bobines de cuivre, nez chromé, lentille rouge, faisceau."""
    CYX(1.05, 1.6, -1.9, 0, 0, "noir_mat", verts=40, bev=0.04)
    for k in range(7):
        CYX(1.3, 0.08, -2.55 + k * 0.2, 0, 0, "alu_brosse", verts=40, bev=0.01)
    CYX(0.8, 2.2, 0.0, 0, 0, "titane_sombre", verts=40, bev=0.03)
    for x in (-0.55, 0.45):
        CYX(1.0, 0.7, x, 0, 0, "cuivre", verts=40, bev=0.03)
        for k in range(5):
            TOR(1.0, 0.04, x - 0.28 + k * 0.14, 0, 0, "or_sombre", rot=(0, 90, 0), minor=8)
    lathe([(0.85, 0), (0.85, 0.3), (0.62, 0.9), (0.55, 1.15), (0, 1.15)], 1.05, 0, 0, "chrome", verts=40).rotation_euler = (0, math.radians(90), 0)
    CYX(0.52, 0.06, 2.22, 0, 0, lum("rouge_laser", force=1.4), verts=32, bev=0)
    rayon = lum("rouge_laser", mode="z", force=1.6, z0=0.0, z1=1.4)
    o = lathe([(0.32, 0.0), (0.16, 0.9), (0.04, 1.4)], 2.25, 0, 0, rayon, verts=16)
    o.rotation_euler = (0, math.radians(90), 0)
    B(2.6, 1.2, 0.3, -0.6, 0, -1.25, "alu_sombre", bev=0.05)


def ic_laser_module():
    pivoter(capte(tete_laser), rot=(0, -6, -128))


# ------------------------------------------------------------------------------------------------------------------
# Circuits
# ------------------------------------------------------------------------------------------------------------------
def carte_nue():
    """Carte imprimée nue (âge 4) : plaque verte, pistes et pastilles étamées, trous, connecteur de bord doré."""
    B(5.4, 3.8, 0.18, 0, 0, 0, "pcb_vert", bev=0.03)
    pistes = [(-1.6, 0.9, 2.2, 0), (-0.5, 0.0, 1.8, 90), (0.8, -0.9, 2.6, 0), (1.8, 0.3, 1.6, 90), (-1.9, -0.6, 1.4, 90),
              (0.6, 1.3, 2.0, 0), (-0.9, -1.4, 1.6, 0)]
    for (x, y, l, r) in pistes:
        B(l, 0.16, 0.03, x, y, 0.18, "etain", bev=0, rot=(0, 0, r))
    pastilles = [(-2.7 + 0.0, 0.9), (-0.5, 0.9), (-0.5, -0.9), (2.1, -0.9), (1.8, 1.1), (1.8, -0.5), (-1.9, 0.1), (-1.9, -1.3),
                 (-0.4, 1.3), (1.6, 1.3), (-1.7, -1.4), (-0.1, -1.4)]
    for (x, y) in pastilles:
        CY(0.24, 0.05, x, y, 0.18, "etain", verts=24, bev=0)
        CY(0.09, 0.06, x, y, 0.19, "fond_noir", verts=12, bev=0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            CY(0.26, 0.04, sx * 2.35, sy * 1.55, 0.18, "etain", verts=24, bev=0)
            CY(0.13, 0.05, sx * 2.35, sy * 1.55, 0.19, "fond_noir", verts=16, bev=0)
    for k in range(9):
        B(0.28, 0.6, 0.03, -1.6 + k * 0.4, -1.62, 0.18, "or", bev=0)


def ic_printed_circuit_board():
    pivoter(capte(carte_nue), rot=(0, 0, 18))


def oscillateur():
    """Boîtier HC-49 : ovale argent debout, socle sombre, 2 pattes d'or, fenêtre sur le quartz cyan lumineux."""
    B(2.0, 1.15, 2.6, 0, 0, 0.35, "chrome", bev=0.05)
    for sx in (-1, 1):
        CY(0.575, 2.6, sx * 1.0, 0, 0.35, "chrome", verts=32, bev=0.03)
    B(3.4, 1.4, 0.4, 0, 0, 0.0, "noir_mat", bev=0.06)
    for sx in (-1, 1):
        CY(0.13, 1.2, sx * 0.9, 0, -1.2, "or", verts=12)
        B(0.26, 0.26, 0.12, sx * 0.9, 0, -1.25, "or", bev=0.02)
    CYX(0.95, 0.06, 0, -0.6, 1.75, "noir_mat", axe="y", verts=40, bev=0)
    CYX(0.82, 0.08, 0, -0.62, 1.75, lum("quartz"), axe="y", verts=40, bev=0)
    CYX(0.36, 0.1, 0, -0.64, 1.75, "or", axe="y", verts=32, bev=0)
    for k in range(3):
        B(1.5, 0.04, 0.08, 0, -0.6, 0.65 + k * 0.17, "marquage", bev=0)


def ic_crystal_oscillator():
    pivoter(capte(oscillateur), rot=(0, 0, 22))


# ------------------------------------------------------------------------------------------------------------------
# Silicium
# ------------------------------------------------------------------------------------------------------------------
def ic_metallurgical_silicon():
    """3 blocs gris foncé à éclat métallique, facettes franches."""
    roche(1.55, -0.6, 0.4, 1.1, "silicium_met", 31, ecrase=0.75, rugueux=0.32, subdiv=1)
    roche(1.25, 1.35, -0.4, 0.85, "silicium_met", 32, ecrase=0.8, rugueux=0.3, subdiv=1)
    roche(0.95, -0.4, -1.4, 0.6, "silicium_met", 33, ecrase=0.8, rugueux=0.3, subdiv=1)


def barreau_poly(L, R, graine):
    """Tronçon de barreau Siemens (axe Z) : surface en chou-fleur (rayon bosselé), cassures irrégulières aux bouts."""
    rng = random.Random(graine)
    prof = [(0.0, 0.0), (R * 0.55, rng.uniform(-0.12, 0.05)), (R * 0.85, 0.12)]
    n = 18
    for i in range(1, n):
        z = 0.12 + (L - 0.24) * i / n
        prof.append((R * (1 + 0.06 * math.sin(i * 2.1) + rng.uniform(-0.04, 0.04)), z))
    prof += [(R * 0.82, L - 0.1), (R * 0.5, L + rng.uniform(-0.05, 0.12)), (0.0, L)]
    return lathe(prof, 0, 0, -L / 2, "polysilicium", verts=28, lisse=False, bev=0.01)


def ic_pure_silicon():
    pivoter(capte(barreau_poly, 4.8, 0.9, 5), rot=(0, 84, 30), loc=(-0.3, 0.9, 0.9))
    pivoter(capte(barreau_poly, 4.2, 0.85, 6), rot=(0, 84, 30), loc=(0.5, -1.0, 0.85))
    roche(0.55, 2.2, 0.2, 0.45, "polysilicium", 7, ecrase=0.8, rugueux=0.3, subdiv=1)


def ic_silicon_wafer():
    """Pile de 3 tranches nues, miroir bleu-gris, méplat (même galette que la tranche gravée du calcul)."""
    for i in range(3):
        def une():
            O.galette(2.6, 0.14, "silicium_poli")
            TOR(2.58, 0.05, 0, 0, 0.07, "alu_brosse")
            B(1.3, 0.3, 0.16, 0, -2.52, 0.0, "fond_noir", bev=0)
        pivoter(capte(une), rot=(0, 0, 8 + i * 9), loc=(i * 0.18, i * 0.32, i * 0.55))


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


def ruban(points, larg, z, m):
    """Ruban plat vertical suivant des points (x, y), de largeur larg en z (une face, deux côtés rendus)."""
    vs, fs = [], []
    for (x, y) in points:
        vs.append((x, y, z))
        vs.append((x, y, z + larg))
    for i in range(len(points) - 1):
        fs.append((2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1))
    return P._maille("ruban", vs, fs, m)


def galette_ruban():
    """Galette plate de ruban YBCO sur moyeu bleu, bout déroulé, liseré de givre cyan."""
    CY(2.35, 0.75, 0, 0, 0, "ruban_ybco", verts=96, bev=0.02)
    for k in range(7):
        TOR(0.95 + k * 0.22, 0.012, 0, 0, 0.75, "noir_mat", minor=6)
    CY(0.85, 0.9, 0, 0, -0.08, "moyeu_bleu", verts=48, bev=0.04)
    CY(0.35, 0.95, 0, 0, -0.08, "fond_noir", verts=24, bev=0.02)
    TOR(2.36, 0.06, 0, 0, 0.75, lum("givre_lum"), minor=8)
    TOR(2.36, 0.06, 0, 0, 0.0, lum("givre_lum"), minor=8)
    pts = []
    for i in range(12):
        t = i / 11
        a = -1.0 + t * 1.6
        r = 2.36 + t * t * 1.4
        pts.append((r * math.cos(a), r * math.sin(a) - t * 0.3))
    r = ruban(pts, 0.7, 0.03, "ruban_ybco")
    r.modifiers.new("ep", "SOLIDIFY").thickness = 0.05
    rng = random.Random(4)
    for k in range(5):
        a = rng.uniform(0, 6.28)
        lathe([(0.14, 0.0), (0.0, 0.35)], 2.3 * math.cos(a), 2.3 * math.sin(a), 0.75, "givre", verts=6, lisse=False)


def ic_superconducting_tape():
    pivoter(capte(galette_ruban), rot=(0, 0, 10))
