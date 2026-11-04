"""Icônes des OBJETS de la chaîne du calcul (s'exécute dans Blender). Chaque fonction modèle un objet à environ 5,5 unités
de large, avec des pièces assez grosses pour se lire à 32 px (scene_base : règle d'échelle)."""
import math
import random

import scene_base as P
from scene_base import B, CY, CYX, SPH, TOR, capte, lathe, pivoter, roche, tube


# ------------------------------------------------------------------------------------------------------------------
# Silicium : lingot, tranches, masque
# ------------------------------------------------------------------------------------------------------------------
def lingot(L=5.6, R=1.08):
    """Lingot monocristallin (d'axe Z) : col de germe, épaule en cône, corps à stries de croissance, queue tronquée."""
    prof = [(0.0, 0.0), (0.13, 0.0), (0.15, 0.42), (0.34, 0.62), (0.62, 0.86), (R * 0.90, 1.14), (R, 1.42)]
    n = 26
    for i in range(1, n + 1):
        t = i / n
        z = 1.42 + t * (L - 1.72)
        r = R * (1 + 0.012 * math.sin(t * 46.0))
        prof.append((r, z))
    prof += [(R * 0.97, L - 0.18), (R * 0.84, L - 0.06), (R * 0.70, L), (0.0, L)]
    return lathe(prof, 0, 0, -L / 2, "silicium_lingot", verts=96)


def ic_silicon_ingot():
    def corps():
        L, R = 5.3, 1.5
        lingot(L, R)
        lathe([(0.0, 0.0), (R * 0.68, 0.0), (R * 0.68, 0.02), (0.0, 0.02)], 0, 0, L / 2, "silicium_poli", verts=64)
    pivoter(capte(corps), rot=(0, -52, 12))


IRIS = ["iris0", "iris1", "iris2", "iris3", "iris4", "iris5"]


def _iris():
    rgb = [(0.10, 0.62, 0.90), (0.30, 0.25, 0.95), (0.80, 0.14, 0.75), (0.95, 0.45, 0.12), (0.80, 0.78, 0.15), (0.12, 0.72, 0.42)]
    for nom, c in zip(IRIS, rgb):
        P.K.MAT[nom] = dict(rgb=c, rough=0.14, met=0.92, grain=0.05, creux=0.2, arete=0.5, bosse=0.05)


def galette(R=2.75, h=0.14, m="silicium_poli"):
    prof = [(0.0, 0.0), (R - 0.03, 0.0), (R, 0.03), (R, h - 0.03), (R - 0.03, h), (0.0, h)]
    return lathe(prof, 0, 0, 0, m, verts=120)


def tranche_gravee(R=2.75, pas=0.74):
    """Tranche gravée : disque, encoche, champ de puces à la diffraction arc-en-ciel d'une vraie tranche (bandes en
    diagonale), lignes de découpe sombres. Pas de 0,74 unité : au moins 4 px à 32 px, sinon c'est du bruit (critique A)."""
    _iris()
    galette(R, 0.16, "silicium")
    TOR(R - 0.02, 0.05, 0, 0, 0.09, "alu_brosse")
    B(0.34, 0.24, 0.05, 0, -R + 0.08, 0.14, "fond_noir", bev=0)
    n = int(R / pas) + 1
    for i in range(-n, n + 1):
        for j in range(-n, n + 1):
            x, y = (i + 0.5) * pas, (j + 0.5) * pas
            if math.hypot(abs(x) + pas * 0.42, abs(y) + pas * 0.42) > R - 0.12:
                continue
            u = (x * 0.78 + y * 0.62) / (R * 2) + 0.5
            k = int(u * len(IRIS) * 0.999) % len(IRIS)
            B(pas * 0.84, pas * 0.84, 0.05, x, y, 0.16, IRIS[k], bev=0.012)
            # coeur plus sombre de la puce : deux niveaux par puce, assez gros pour rester à 64 px
            B(pas * 0.36, pas * 0.36, 0.02, x - pas * 0.14, y + pas * 0.14, 0.21, "silicium", bev=0)


def ic_etched_wafer():
    pivoter(capte(tranche_gravee), rot=(0, 0, 14))


def ic_exposed_wafer():
    """Tranche insolée : film de résine ambre, champs déjà insolés (sombres) derrière la fente, et la tête de balayage :
    barre noire aussi large que le disque, nappe de lumière ultraviolette en dessous. Disque surmonté d'une BARRE : un
    objectif rond et un cône se lisaient comme une fiole (essai 1)."""
    R = 2.75
    galette(R, 0.16, "silicium")
    TOR(R - 0.02, 0.05, 0, 0, 0.09, "alu_brosse")
    lathe([(0.0, 0.0), (R - 0.14, 0.0), (R - 0.14, 0.03), (0.0, 0.03)], 0, 0, 0.16, "resine_film", verts=120)
    B(0.34, 0.24, 0.05, 0, -R + 0.08, 0.14, "fond_noir", bev=0)
    pas = 0.86
    for i in range(-3, 4):
        for j in range(-3, 4):
            x, y = (i + 0.5) * pas, (j + 0.5) * pas
            if math.hypot(abs(x) + pas * 0.42, abs(y) + pas * 0.42) > R - 0.2 or y < 0.2:
                continue
            B(pas * 0.82, pas * 0.82, 0.018, x, y, 0.19, "resine_expose", bev=0.004)
    # tête de balayage et nappe de lumière (au-dessus de la ligne y = 0)
    zt = 3.15
    v = P.mat_voile("voile_uv", (0.50, 0.22, 1.0), 0.72, 1.0)
    vs = [(-2.1, 0.05, zt), (2.1, 0.05, zt), (2.55, 0.05, 0.22), (-2.55, 0.05, 0.22)]
    n = P._maille("nappe", vs, [(0, 1, 2, 3)], v)
    n.visible_shadow = False
    B(5.1, 0.34, 0.03, 0, 0.05, 0.19, "lum_uv", bev=0)
    B(5.0, 1.15, 0.92, 0, 0.05, zt, "noir_mat", bev=0.06)
    B(4.4, 0.74, 0.08, 0, 0.05, zt - 0.08, "lum_uv", bev=0)
    B(5.2, 1.3, 0.20, 0, 0.05, zt + 0.92, "alu_brosse", bev=0.04)
    for s in (-1, 1):
        B(0.34, 1.4, 1.20, s * 2.72, 0.05, zt - 0.02, "alu_sombre", bev=0.04)


def ic_photomask():
    """Photomasque : plaque de quartz rétroéclairée vue en losange, couche de chrome sombre percée de 3 × 3 champs clairs,
    cadre de pellicule en aluminium. Lumineux par transparence, jamais blanc pur."""
    def corps():
        S = 4.6
        B(S, S, 0.22, 0, 0, 0, "verre_cyan", bev=0.04)
        B(S * 0.86, S * 0.86, 0.03, 0, 0, 0.22, "chrome_masque", bev=0.004)
        e = 0.26
        for sx in (-1, 1):
            B(e, S, 0.34, sx * (S / 2 - e / 2), 0, 0.22, "alu_brosse", bev=0.03)
            B(S, e, 0.34, 0, sx * (S / 2 - e / 2), 0.22, "alu_brosse", bev=0.03)
        c = 1.08
        for i in range(-1, 2):
            for j in range(-1, 2):
                x, y = i * (c + 0.16), j * (c + 0.16)
                B(c, c, 0.02, x, y, 0.25, "masque_clair", bev=0)
                # motif de chrome du champ : barres et plots, gros, pour 64 px
                B(c * 0.70, 0.17, 0.012, x, y + 0.26, 0.27, "chrome_masque", bev=0)
                B(0.17, c * 0.46, 0.012, x - 0.27, y - 0.14, 0.27, "chrome_masque", bev=0)
                B(0.30, 0.30, 0.012, x + 0.18, y - 0.20, 0.27, "chrome_masque", bev=0)
    pivoter(capte(corps), rot=(0, 0, 45))


def ic_crystal_laser():
    """Laser à cristal : le CRISTAL d'abord (gros prisme à pointe, facettes franches, lumière interne), serti dans une
    bague à griffes, bobines de cuivre, culot sombre, faisceau au sommet."""
    def corps():
        # culot, bague, bobines
        lathe([(0, 0), (1.62, 0), (1.72, 0.08), (1.72, 0.46), (1.46, 0.60), (1.26, 0.62), (1.22, 1.02), (1.36, 1.10), (1.36, 1.42),
               (0, 1.42)], 0, 0, 0, "noir_mat", verts=64)
        for k in range(3):
            TOR(1.36, 0.13, 0, 0, 0.66 + k * 0.17, "cuivre", minor=12)
        TOR(1.65, 0.07, 0, 0, 0.46, "alu_brosse")
        # cristal à facettes : hexagonal, pointe décentrée par la rotation
        cristal = P.mat_lum("cristal_z", P.K.LUM["cristal"][0], P.K.LUM["cristal"][1], 0.55, mode="z", z0=-0.1, z1=3.1)
        pc = cristal.node_tree.nodes["Principled BSDF"]
        pc.inputs["Base Color"].default_value = (0.05, 0.42, 0.66, 1)
        pc.inputs["Metallic"].default_value = 0.35
        pc.inputs["Roughness"].default_value = 0.10
        lathe([(1.05, 0.0), (1.24, 0.10), (1.24, 2.1), (0.40, 3.15), (0.0, 3.35)], 0, 0, 1.36, cristal, verts=6, lisse=False, bev=0.02,
              phase=0.25)
        # petites arêtes claires : la facette de devant, comme la fêlure du cristal
        for k in range(3):
            a = 0.25 + k * math.pi * 2 / 3
            x, y = 1.40 * math.cos(a), 1.40 * math.sin(a)
            griffe = B(0.40, 0.34, 1.35, x, y, 1.20, "alu_brosse", bev=0.05)
            griffe.rotation_euler = (0, 0, a)
        # faisceau : cône lumineux au sommet
        lathe([(0.27, 0.0), (0.12, 0.85), (0.03, 1.35)], 0, 0, 4.58, P.mat_lum("rayon", P.K.LUM["fibre_pointe"][0], P.K.LUM["fibre"][1], 1.5,
                                                                             mode="z", z0=0.0, z1=1.2), verts=16)
    pivoter(capte(corps), rot=(0, 10, 0))


# ------------------------------------------------------------------------------------------------------------------
# Puces (4 silhouettes : pattes sur 4 côtés, barrette à pattes, ziggourat, escalier en biais)
# ------------------------------------------------------------------------------------------------------------------
def pattes(sx, sy, n, L, larg, cotes, z=0.04, m="or"):
    for (dx, dy) in cotes:
        lg = sy if dx else sx
        pas = (lg - 0.6) / (n - 1)
        for i in range(n):
            t = -(lg - 0.6) / 2 + i * pas
            if dx:
                B(L, larg, 0.09, dx * (sx / 2 + L / 2 - 0.08), t, z, m, bev=0.012)
                B(0.14, larg, 0.20, dx * (sx / 2 + L - 0.10), t, z - 0.14, m, bev=0.012)
            else:
                B(larg, L, 0.09, t, dy * (sy / 2 + L / 2 - 0.08), z, m, bev=0.012)
                B(larg, 0.14, 0.20, t, dy * (sy / 2 + L - 0.10), z - 0.14, m, bev=0.012)


def bloc_coeur(cx, cy, s, z, base, clair, sombre, lignes=3):
    """Bloc fonctionnel d'une puce : plaque, canaux sombres, cellule claire."""
    B(s, s, 0.08, cx, cy, z, base, bev=0.015)
    for k in range(lignes - 1):
        t = -s / 2 + s * (k + 1) / lignes
        B(s * 0.9, 0.05, 0.012, cx, cy + t, z + 0.08, sombre, bev=0)
    B(s * 0.36, s * 0.26, 0.03, cx - s * 0.2, cy + s * 0.31, z + 0.08, clair, bev=0.004)
    B(s * 0.42, s * 0.26, 0.03, cx + s * 0.16, cy - s * 0.04, z + 0.08, clair, bev=0.004)


def puce_logique():
    S = 4.1
    B(S, S, 0.26, 0, 0, 0, "puce_noire", bev=0.05)
    pattes(S, S, 8, 0.62, 0.26, ((1, 0), (-1, 0), (0, 1), (0, -1)))
    B(3.1, 3.1, 0.10, 0, 0, 0.26, "silicium", bev=0.03)
    for sx in (-1, 1):
        B(3.0, 0.10, 0.03, 0, sx * 1.46, 0.36, "or", bev=0)
        B(0.10, 3.0, 0.03, sx * 1.46, 0, 0.36, "or", bev=0)
    c = 1.30
    for ix in (-1, 1):
        for iy in (-1, 1):
            bloc_coeur(ix * (c / 2 + 0.05), iy * (c / 2 + 0.05), c, 0.36, "logique", "logique_clair", "logique_sombre")


def ic_logic_die():
    pivoter(capte(puce_logique), rot=(0, 0, 16))


def puce_dram():
    Lx, Ly = 5.2, 2.3
    B(Lx, Ly, 0.28, 0, 0, 0, "puce_noire", bev=0.05)
    pattes(Lx, Ly, 10, 0.52, 0.24, ((0, 1), (0, -1)), m="vis")
    B(Lx - 0.5, Ly - 0.5, 0.08, 0, 0, 0.28, "silicium", bev=0.02)
    n, s = 4, 1.04
    for i in range(n):
        x = -(n - 1) * (s + 0.09) / 2 + i * (s + 0.09)
        B(s, Ly - 0.74, 0.08, x, 0, 0.36, "dram", bev=0.015)
        for k in range(3):
            B(s * 0.88, 0.07, 0.012, x, -0.42 + k * 0.42, 0.44, "dram_sombre", bev=0)
        B(s * 0.38, 0.26, 0.03, x - 0.22, 0.20 + 0.0, 0.44, "dram_clair", bev=0.004)
        B(s * 0.38, 0.26, 0.03, x + 0.20, -0.21, 0.44, "dram_clair", bev=0.004)


def ic_dram_die():
    pivoter(capte(puce_dram), rot=(0, 0, 34))


def puce_sram():
    """Ziggourat : trois étages empilés et retirés (cache 3D), rangées de vias d'or sur les paliers."""
    t = [(4.7, "sram_sombre", 0.80), (3.4, "sram", 0.80), (2.2, "sram", 0.70)]
    z = 0.0
    for i, (s, m, h) in enumerate(t):
        B(s, s, h, 0, 0, z, m, bev=0.05)
        z += h
        if i < 2:
            s2 = t[i + 1][0]
            r = (s + s2) / 4
            n = 7 if i == 0 else 5
            for k in range(n):
                v = -r + k * 2 * r / (n - 1)
                for (x, y) in ((v, -r), (v, r), (-r, v), (r, v)):
                    CY(0.10, 0.024, x, y, z, "or", verts=10, bev=0)
    # cellules du dernier étage
    c = 0.62
    for i in (-1, 0, 1):
        for j in (-1, 0, 1):
            B(c, c, 0.05, i * (c + 0.07), j * (c + 0.07), z, "sram_clair", bev=0.012)
            B(c * 0.5, c * 0.5, 0.012, i * (c + 0.07), j * (c + 0.07), z + 0.05, "sram_sombre", bev=0)


def ic_sram_die():
    pivoter(capte(puce_sram), rot=(0, 0, 45))


def puce_nand():
    """Empilement en biais, comme une vraie mémoire NAND : 5 puces décalées en escalier, fils d'or de palier en palier."""
    n, dx, dz = 5, 0.44, 0.52
    Lx, Ly = 3.5, 3.2
    B(Lx + (n - 1) * dx + 0.5, Ly + 0.4, 0.20, (n - 1) * dx / 2 - 0.9, 0, 0, "puce_noire", bev=0.04)
    for i in range(n):
        x = -0.9 + i * dx
        z = 0.20 + i * dz
        B(Lx, Ly, dz - 0.05, x, 0, z, "nand" if i % 2 == 0 else "nand_sombre", bev=0.03)
        zt = z + dz - 0.05
        for k in range(4):
            y = -1.14 + k * 0.76
            B(0.24, 0.40, 0.016, x - Lx / 2 + 0.18, y, zt, "or", bev=0)
            xb = x - Lx / 2 - (dx - 0.18 if i else 0.34)
            zb = z + 0.0 if i else 0.20
            tube([(x - Lx / 2 + 0.18, y, zt + 0.02), (x - Lx / 2 - 0.10, y, zt + 0.14), (xb, y, zb + 0.02)], 0.04, "or", res=8)
    x = -0.9 + (n - 1) * dx
    zt = 0.20 + n * dz - 0.05
    for i in (-1, 0, 1):
        B(0.86, Ly - 0.5, 0.06, x + 0.30 + i * 0.96, 0, zt, "nand_clair", bev=0.015)
        for k in range(3):
            B(0.76, 0.09, 0.012, x + 0.30 + i * 0.96, -0.80 + k * 0.80, zt + 0.06, "nand_sombre", bev=0)


def ic_nand_die():
    pivoter(capte(puce_nand), rot=(0, 0, -28))


# ------------------------------------------------------------------------------------------------------------------
# Composants
# ------------------------------------------------------------------------------------------------------------------
def ic_heat_sink():
    def corps():
        Lx, Ly, H = 4.4, 3.9, 3.0
        B(Lx + 0.1, Ly + 0.1, 0.56, 0, 0, 0, "cuivre", bev=0.05)
        n = 7
        pas = Ly / n
        for i in range(n):
            y = -Ly / 2 + pas * (i + 0.5)
            B(Lx, pas * 0.52, H, 0, y, 0.56, "alu_brosse", bev=0.035)
        # deux caloducs de cuivre qui traversent
        for s in (-1, 1):
            CYX(0.20, Ly + 0.5, s * 1.25, 0, 1.75, "cuivre", axe="y")
    pivoter(capte(corps), rot=(0, 0, 26))


def barrette(L=5.6, W=2.15):
    B(L, W, 0.10, 0, 0, 0, "pcb", bev=0.02)
    zt = 0.10
    n = 18
    for i in range(n):
        if i == 7:
            continue
        x = -L / 2 + 0.24 + (L - 0.48) * i / (n - 1)
        B(0.18, 0.52, 0.018, x, -W / 2 + 0.28, zt, "or", bev=0.003)
    m = 5
    pas = (L - 0.5) / m
    for i in range(m):
        x = -(L - 0.5) / 2 + pas * (i + 0.5)
        B(pas * 0.80, W * 0.46, 0.20, x, 0.28, zt, "puce_noire", bev=0.03)
        B(pas * 0.46, 0.09, 0.008, x - 0.08, 0.40, zt + 0.20, "marquage", bev=0)
        B(pas * 0.30, 0.09, 0.008, x - 0.16, 0.20, zt + 0.20, "marquage", bev=0)
    B(L * 0.98, 0.20, 0.13, 0, W / 2 - 0.10, zt, "dram", bev=0.03)
    B(L * 0.80, 0.08, 0.02, 0, W / 2 - 0.10, zt + 0.13, "voyant_teal", bev=0)


def ic_memory_module():
    pivoter(capte(barrette), rot=(0, 0, 40))


def ic_motherboard():
    def corps():
        Sx, Sy = 5.0, 4.8
        B(Sx, Sy, 0.12, 0, 0, 0, "pcb_vert", bev=0.02)
        zt = 0.12
        # faisceaux de pistes
        for i in range(6):
            B(1.9, 0.05, 0.006, -0.9, -1.3 + i * 0.12, zt, "or_sombre", bev=0)
            B(0.05, 1.0, 0.006, 0.28 + i * 0.12, -0.9, zt, "or_sombre", bev=0)
        # socle du processeur : gros bloc central
        B(1.9, 1.9, 0.14, -0.8, 0.55, zt, "alu_brosse", bev=0.03)
        B(1.5, 1.5, 0.10, -0.8, 0.55, zt + 0.14, "logique", bev=0.03)
        B(0.9, 0.9, 0.02, -0.8, 0.55, zt + 0.24, "logique_clair", bev=0.004)
        # 4 fentes de mémoire garnies (vert d'eau, comme la DRAM)
        for i in range(4):
            x = 0.90 + i * 0.42
            B(0.26, 3.5, 0.16, x, 0.45, zt, "puce_noire", bev=0.02)
            B(0.18, 3.1, 0.32, x, 0.45, zt + 0.16, "dram", bev=0.02)
        # bloc d'entrées-sorties, bien haut
        B(0.8, 2.0, 0.78, -2.05, 0.95, zt, "carenage_clair", bev=0.05)
        for i in range(3):
            B(0.14, 0.40, 0.22, -2.48, 0.35 + i * 0.58, zt + 0.32, "fond_noir", bev=0)
        # radiateur du pont, condensateurs
        B(1.15, 1.15, 0.08, -1.25, -1.45, zt, "alu_sombre", bev=0.02)
        for i in range(5):
            B(1.15, 0.13, 0.42, -1.25, -1.90 + i * 0.225, zt + 0.08, "alu_brosse", bev=0.012)
        for i in range(5):
            CY(0.20, 0.52, -1.2 + i * 0.46, 2.05, zt, "condensateur", verts=24, bev=0.02)
            CY(0.13, 0.012, -1.2 + i * 0.46, 2.05, zt + 0.52, "vis", verts=16, bev=0)
        # 2 fentes d'extension
        for i in range(2):
            B(2.7, 0.22, 0.18, 0.95, -1.42 - i * 0.48, zt, "puce_noire", bev=0.02)
            B(2.2, 0.06, 0.008, 1.05, -1.42 - i * 0.48, zt + 0.18, "or", bev=0)
    pivoter(capte(corps), rot=(0, 0, 14))


def ventilateur(x, y, z, r, cadre="noir_mat", pales="pale_sombre", moyeu="alliage_blanc", n=7, h=0.16, anneau="ligne_bleu_blanc"):
    """Ventilateur vu de dessus (axe Z) : pales larges et inclinées, moyeu clair : se lit jusqu'à 32 px."""
    CY(r * 1.02, 0.03, x, y, z, "fond_noir", verts=48, bev=0)
    TOR(r, r * 0.11, x, y, z + h * 0.8, cadre)
    if anneau:
        TOR(r * 1.0, r * 0.045, x, y, z + h * 0.8 + r * 0.09, anneau, minor=10)
    for i in range(n):
        a = 2 * math.pi * i / n
        Lp = r * 0.70
        cx, cy = x + math.cos(a) * (r * 0.28 + Lp / 2), y + math.sin(a) * (r * 0.28 + Lp / 2)
        p = B(Lp, r * 0.42, 0.016, cx, cy, z + h * 0.45, pales, bev=0.008)
        p.rotation_euler = (math.radians(24), 0, a + math.radians(14))
    CY(r * 0.34, h * 0.8, x, y, z + 0.02, moyeu, verts=32, bev=0.025)
    CY(r * 0.18, 0.01, x, y, z + h * 0.8 + 0.02, "titane_sombre", verts=24, bev=0)


def carte_graphique(L=5.5, W=2.8):
    """Carte graphique : long carénage de titane, 2 grands ventilateurs, liseré bleu-blanc, contacts PCIe, équerre."""
    B(L, W, 0.10, 0, 0, 0, "pcb", bev=0.02)
    zt = 0.10
    for i in range(16):
        if i == 4:
            continue
        B(0.15, 0.36, 0.03, -L * 0.28 + i * 0.205, -W / 2 - 0.16, 0.0, "or", bev=0.004)
    B(L * 0.97, W * 0.98, 0.42, 0.04, 0, zt, "titane", bev=0.10)
    B(L * 0.97, 0.16, 0.05, 0.04, -W * 0.49 + 0.08, zt + 0.42, "alliage_blanc", bev=0.015)
    B(L * 0.97, 0.16, 0.05, 0.04, W * 0.49 - 0.08, zt + 0.42, "alliage_blanc", bev=0.015)
    B(L * 0.78, 0.10, 0.02, 0.15, -W * 0.49 + 0.08, zt + 0.47, "ligne_bleu_blanc", bev=0)
    r = W * 0.40
    for s in (-1, 1):
        ventilateur(0.10 + s * (r + 0.13), 0, zt + 0.34, r, cadre="titane_sombre", h=0.12)
    B(0.10, W * 1.16, 0.95, -L / 2 - 0.05, 0, -0.14, "alliage_blanc", bev=0.015)
    for i in range(3):
        B(0.02, 0.34, 0.16, -L / 2 - 0.11, -0.72 + i * 0.72, 0.28, "fond_noir", bev=0)


def ic_graphics_card():
    pivoter(capte(carte_graphique), rot=(0, 0, 30))


def ic_degassed_ilmenite():
    """Ilménite dégazée : granulés anguleux noir violacé à éclats métalliques (poreux, le gaz est parti)."""
    rng = random.Random(1311)
    blocs = [(1.28, -0.6, 0.2, 0.75, "ilmenite"), (1.08, 1.25, -0.35, 0.62, "ilmenite_clair"), (0.95, -1.75, -1.0, 0.55, "ilmenite_clair"),
             (0.92, 0.5, -1.55, 0.55, "ilmenite"), (0.82, 1.35, 1.3, 0.5, "ilmenite"), (0.72, -1.7, 1.25, 0.45, "ilmenite_clair"),
             (0.62, -0.4, 1.75, 0.4, "ilmenite"), (0.52, 2.15, -1.55, 0.35, "ilmenite_clair")]
    for i, (r, x, y, z, m) in enumerate(blocs):
        roche(r, x, y, z, m, 400 + i, ecrase=0.82, rugueux=0.24)
    # pores : petites cavités sombres sur les plus gros blocs
    for i in range(10):
        a = rng.uniform(0, 6.28)
        d = rng.uniform(0.2, 0.9)
        SPH(0.075 + rng.uniform(0, 0.05), -0.6 + d * math.cos(a), 0.2 + d * math.sin(a), 1.62 - d * 0.5, "fond_noir", seg=10, rings=6)


# ------------------------------------------------------------------------------------------------------------------
# Disque flash, fibre, commutateur
# ------------------------------------------------------------------------------------------------------------------
def ic_flash_drive():
    """Disque flash 2,5 pouces : boîtier d'aluminium brossé épais, étiquette sombre à bande corail, connecteur doré."""
    def corps():
        Lx, Ly, H = 5.1, 3.5, 0.72
        B(Lx, Ly, H, 0, 0, 0, "alu_brosse", bev=0.09)
        B(Lx - 0.6, Ly - 0.5, 0.03, 0.04, 0, H, "noir_mat", bev=0.01)
        B(Lx - 0.9, 0.62, 0.012, 0.04, 0.72, H + 0.03, "nand", bev=0)
        B(1.45, 0.20, 0.008, -0.72, -0.25, H + 0.03, "marquage", bev=0)
        B(0.95, 0.20, 0.008, -0.97, -0.72, H + 0.03, "marquage", bev=0)
        for i in range(3):
            B(0.46, 0.46, 0.05, 0.75 + i * 0.58, -0.56, H + 0.03, "nand_clair", bev=0.012)
        CY(0.10, 0.02, 1.95, -1.32, H + 0.03, "voyant_corail", verts=12, bev=0)
        for sx in (-1, 1):
            for sy in (-1, 1):
                CY(0.11, 0.03, sx * (Lx / 2 - 0.20), sy * (Ly / 2 - 0.2), H, "vis", verts=12, bev=0.005)
        # connecteur
        B(0.32, 2.5, 0.40, Lx / 2 + 0.12, 0, 0.14, "puce_noire", bev=0.03)
        for i in range(7):
            B(0.08, 0.24, 0.20, Lx / 2 + 0.30, -0.96 + i * 0.32, 0.24, "or", bev=0.006)
    pivoter(capte(corps), rot=(0, 0, 30))


def ic_optical_fiber():
    """Fibre optique : gaine noire, virole de métal, faisceau qui s'évase en bouquet, pointes lumineuses."""
    rng = random.Random(77)
    bas = (-2.05, 0.0, -2.05)
    col = (-0.55, 0.0, -0.55)
    tube([bas, (-1.3, 0, -1.3), col], 0.42, "cable_jaune")
    n = 19
    for i in range(n):
        t = (i - (n - 1) / 2) / ((n - 1) / 2)
        a = math.radians(45 + t * 56)
        d = 3.45 + rng.uniform(-0.45, 0.25) - abs(t) * 0.25
        fin = (col[0] + d * math.cos(a), 0.45 * math.sin(t * 2.7 + i), col[2] + d * math.sin(a))
        am = a - t * 0.28      # le brin part serré, puis s'ouvre
        mil = (col[0] + d * 0.45 * math.cos(am), 0.2 * math.sin(i * 1.3), col[2] + d * 0.45 * math.sin(am))
        dep = (col[0] + 0.20 * math.cos(a), t * 0.18 * 0.6, col[2] + 0.20 * math.sin(a))
        tube([dep, mil, fin], 0.052, "fibre", res=10)
        SPH(0.135 + (0.03 if i % 3 == 0 else 0.0), fin[0], fin[1], fin[2], "fibre_pointe", seg=16, rings=10)


def _virole():
    """La virole du bouquet : cylindre d'axe (1, 0, 1)."""
    o = lathe([(0.44, -0.46), (0.54, -0.40), (0.54, 0.26), (0.40, 0.42), (0.26, 0.42)], 0, 0, 0, "alu_brosse", verts=40)
    o.location = (-0.75, 0.0, -0.75)
    o.rotation_euler = (0, math.radians(45), 0)


def ic_fiber_complet():
    ic_optical_fiber()
    _virole()


def ic_network_switch():
    """Commutateur réseau : boîtier 1U large, façade à 2 × 6 ports lumineux, trois câbles qui pendent devant."""
    def corps():
        Lx, Ly, H = 5.4, 3.1, 1.30
        B(Lx, Ly, H, 0, 0, 0, "carenage_clair", bev=0.05)
        B(Lx - 0.5, Ly - 0.6, 0.02, 0, 0.1, H, "carenage_sombre", bev=0.005)
        for i in range(9):
            B(0.18, 1.35, 0.012, -2.0 + i * 0.5, 0.45, H + 0.02, "fond_noir", bev=0)
        fy = -Ly / 2
        B(Lx - 0.14, 0.05, H - 0.14, 0, fy - 0.01, 0.07, "noir_mat", bev=0.008)
        for sx in (-1, 1):
            B(0.34, 0.14, H + 0.1, sx * (Lx / 2 + 0.04), fy - 0.02, -0.05, "alu_brosse", bev=0.03)
        for r in range(2):
            z = 0.16 + r * 0.54
            for c in range(6):
                x = -2.12 + c * 0.76
                B(0.56, 0.05, 0.40, x, fy - 0.045, z, "alu_sombre", bev=0.012)
                B(0.40, 0.03, 0.24, x, fy - 0.07, z + 0.04, "fond_noir", bev=0)
                B(0.14, 0.02, 0.09, x - 0.17, fy - 0.075, z + 0.29, "voyant_vert" if (c + r) % 3 else "voyant_ambre", bev=0)
                B(0.14, 0.02, 0.09, x + 0.17, fy - 0.075, z + 0.29, "voyant_vert", bev=0)
        for (c, r, m, dx) in ((0, 1, "cable_jaune", -0.3), (2, 1, "cable_bleu", 0.15), (4, 0, "cable_rouge", 0.35)):
            x = -2.12 + c * 0.76
            z = 0.16 + r * 0.54 + 0.16
            B(0.30, 0.22, 0.20, x, fy - 0.16, z - 0.10, m, bev=0.02)
            tube([(x, fy - 0.24, z), (x + dx * 0.4, fy - 0.72, z - 0.15), (x + dx, fy - 1.05, z - 0.95), (x + dx * 1.6, fy - 0.88, z - 1.95)], 0.09, m)
    pivoter(capte(corps), rot=(0, 0, 0))


# ------------------------------------------------------------------------------------------------------------------
# Quantique
# ------------------------------------------------------------------------------------------------------------------
def ic_qubit_chip():
    """Puce à qubits : boîtier doré, couronne de 8 connecteurs coaxiaux (silhouette), puce de saphir, 4 transmons en
    croix d'or, cœurs magenta."""
    def corps():
        S_ = 4.6
        B(S_, S_, 0.42, 0, 0, 0, "or_sombre", bev=0.05)
        B(S_ - 0.24, S_ - 0.24, 0.04, 0, 0, 0.42, "or", bev=0.012)
        pos = [(0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)]
        for sx, sy in pos:
            x, y = sx * 1.96, sy * 1.96
            CY(0.36, 0.42, x, y, 0.46, "alu_brosse", verts=24, bev=0.02)
            CY(0.22, 0.03, x, y, 0.88, "fond_noir", verts=16, bev=0)
            CY(0.09, 0.05, x, y, 0.88, "or", verts=12, bev=0)
        B(2.75, 2.75, 0.14, 0, 0, 0.46, "saphir", bev=0.03)
        zt = 0.60
        d = 0.70
        for sx in (-1, 1):
            for sy in (-1, 1):
                x, y = sx * d, sy * d
                B(0.98, 0.22, 0.015, x, y, zt, "or", bev=0)
                B(0.22, 0.98, 0.015, x, y, zt, "or", bev=0)
                CY(0.19, 0.03, x, y, zt, "plasma_fort", verts=16, bev=0)
        B(0.14, 1.6, 0.012, 0, 0, zt, "alu_brosse", bev=0)
        B(1.6, 0.14, 0.012, 0, 0, zt, "alu_brosse", bev=0)
    pivoter(capte(corps), rot=(0, 0, 14))


def lustre(rs=(2.25, 1.85, 1.45), pas=1.28, tiges="cuivre", chef="ceramique"):
    """Étage à dilution (« lustre ») : plaques dorées en cascade, rayon décroissant vers le bas, tiges épaisses, échangeurs
    de cuivre, bride de céramique au sommet. Rend la cote z de la dernière plaque (le haut est à z = 0 + total)."""
    n = len(rs)
    zs = [(n - 1 - i) * pas for i in range(n)]
    for i, (r, z) in enumerate(zip(rs, zs)):
        CY(r, 0.24, 0, 0, z, "or", verts=72, bev=0.035)
        TOR(r * 0.80, 0.045, 0, 0, z + 0.25, "or_sombre", minor=8)
        if i + 1 < n:
            for k in range(6):
                a = 2 * math.pi * k / 6 + 0.26
                rr = rs[i + 1] * 0.86
                CY(0.085, pas - 0.2, rr * math.cos(a), rr * math.sin(a), zs[i + 1] + 0.2, tiges, verts=12, bev=0)
            for k in range(3):
                TOR(0.56, 0.095, 0, 0, zs[i + 1] + 0.42 + k * 0.24, "cuivre", minor=10)
            CY(0.38, pas - 0.2, 0, 0, zs[i + 1] + 0.2, "alu_sombre", verts=24, bev=0)
    top = zs[0] + 0.24
    CY(rs[0] * 0.72, 0.30, 0, 0, top + 0.28, chef, verts=64, bev=0.04)
    CY(0.46, 0.34, 0, 0, top, "cuivre", verts=24, bev=0.02)
    CY(0.34, 0.5, 0, 0, top + 0.58, "cuivre", verts=24, bev=0.02)
    for k in range(6):
        a = 2 * math.pi * k / 6
        CY(0.08, 0.34, rs[0] * 0.52 * math.cos(a), rs[0] * 0.52 * math.sin(a), top, tiges, verts=10, bev=0)
    return zs[-1]


def ic_dilution_stage():
    lustre()
    # queue du dernier étage : porte-échantillon nu (le saphir et le magenta vont au processeur quantique)
    CY(0.2, 0.55, 0, 0, -0.55, "or_sombre", verts=16, bev=0)
    B(1.02, 1.02, 0.14, 0, 0, -0.69, "cuivre", bev=0.03)


def ic_quantum_processor():
    """Processeur quantique : boîtier carré à plots d'or, cœur sphérique magenta (dégradé, jamais blanc) tenu par un
    gyroscope à 2 anneaux dorés. Le lustre reste à l'étage à dilution ; ici, la silhouette est une sphère à anneaux."""
    def corps():
        S_ = 4.9
        B(S_, S_, 0.46, 0, 0, 0, "titane_sombre", bev=0.07)
        B(S_ - 0.44, S_ - 0.44, 0.05, 0, 0, 0.46, "saphir", bev=0.012)
        n = 8
        for k in range(n):
            t = -1.92 + k * 3.84 / (n - 1)
            for (x, y) in ((t, -2.28), (t, 2.28), (-2.28, t), (2.28, t)):
                B(0.26, 0.26, 0.05, x, y, 0.46, "cuivre", bev=0.01)
        lathe([(1.65, 0.0), (1.65, 0.08), (0.86, 0.34), (0.60, 0.78), (0.0, 0.78)], 0, 0, 0.50, "or", verts=64)
        zc = 2.62
        coeur = P.mat_lum("coeur_q", (0.92, 0.10, 0.58), (0.30, 0.004, 0.20), 0.92)
        SPH(1.30, 0, 0, zc, coeur)
        TOR(2.02, 0.18, 0, 0, zc, "or", rot=(60, 0, 20), minor=14)
        TOR(2.02, 0.18, 0, 0, zc, "ceramique", rot=(-54, 24, 0), minor=14)
        for k in range(3):
            a = math.radians(-90 + 30 + k * 120)
            x, y = 1.95 * math.cos(a), 1.95 * math.sin(a)
            CY(0.13, zc - 0.75, x, y, 0.5, "alu_brosse", verts=12, bev=0.01)
    corps()
