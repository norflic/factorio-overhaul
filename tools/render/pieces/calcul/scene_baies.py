"""Icônes des BAIES (s'exécute dans Blender) : une seule famille d'armoire compacte (châssis, montants, poignées, toit), et
une façade différente qui dit la fonction : tiroirs horizontaux, barrettes verticales, grille de disques, ports et câbles,
grand ventilateur et tuyaux, cartes graphiques, hublot quantique."""
import math

import scene_base as P
from scene_base import B, CY, TOR, capte, pivoter, tube
from scene_objets import ventilateur

W, D, H = 3.7, 2.5, 4.6
YF = -D / 2 - 0.02          # plan de la façade
AGES = {10: ("carenage_clair", "carenage_sombre", "noir_mat"),
        11: ("alliage_blanc", "titane", "titane_sombre"),
        13: ("ceramique", "cuivre", "titane_sombre")}


def chassis(age):
    corps, cadre, sombre = AGES[age]
    B(W, D, H, 0, 0, 0, corps, bev=0.07)
    B(W + 0.16, D + 0.16, 0.26, 0, 0, H, cadre, bev=0.05)
    B(W + 0.16, D + 0.16, 0.26, 0, 0, -0.26, cadre, bev=0.05)
    B(W - 0.46, 0.05, H - 0.42, 0, YF, 0.21, "fond_noir", bev=0)
    for s in (-1, 1):
        B(0.30, 0.14, H, s * (W / 2 - 0.15), YF - 0.02, 0, cadre, bev=0.03)
        # poignées : les « oreilles » de la famille, qui dépassent de la silhouette
        for z in (0.45, H - 1.15):
            B(0.22, 0.22, 0.70, s * (W / 2 + 0.11), YF + 0.06, z, sombre, bev=0.04)
    # flanc : lames d'aération (ombre interne)
    for i in range(7):
        B(0.03, D * 0.68, 0.20, -W / 2 - 0.005, 0.06, 0.65 + i * 0.48, "fond_noir", bev=0)
    # toit : grille
    for i in range(5):
        B(W * 0.72, 0.14, 0.02, 0, -0.66 + i * 0.33, H + 0.26, "fond_noir", bev=0)


def F(w, h, x, z, m, ep=0.08, bev=0.02, dy=0.0):
    """Élément de façade : (x, z) coin centre bas, ep : saillie depuis le plan de façade."""
    return B(w, ep, h, x, YF - ep / 2 - dy, z, m, bev=bev)


def ic_server_blade():
    """Trois tiroirs de serveur, à l'horizontale, avec poignée et voyants."""
    chassis(10)
    n = 3
    h = (H - 0.75) / n
    for i in range(n):
        z = 0.32 + i * (h + 0.04)
        F(W - 0.70, h - 0.06, 0, z, "carenage_clair", ep=0.16, bev=0.03)
        F(W - 1.25, 0.46, 0.26, z + h - 0.68, "noir_mat", ep=0.03, bev=0.01, dy=0.16)
        for k in range(7):
            F(0.14, 0.32, -0.42 + k * 0.28, z + h - 0.61, "fond_noir", ep=0.012, bev=0, dy=0.19)
        F(W - 1.25, 0.20, 0.26, z + 0.20, "voyant_bleu", ep=0.012, bev=0, dy=0.16)
        F(0.34, 0.34, 1.13, z + h - 0.62, "voyant_ambre", ep=0.012, bev=0, dy=0.19)
        F(0.30, h - 0.36, -1.32, z + 0.15, "titane_sombre", ep=0.16, bev=0.03, dy=0.14)


def ic_memory_rack():
    """Barrettes verticales serrées (vert d'eau), garnies de puces noires."""
    chassis(10)
    n = 6
    pas = (W - 0.80) / n
    for i in range(n):
        x = -(W - 0.80) / 2 + pas * (i + 0.5)
        F(pas * 0.72, H - 1.0, x, 0.50, "dram", ep=0.12, bev=0.012)
        for k in range(4):
            F(pas * 0.46, 0.46, x, 0.78 + k * 0.76, "puce_noire", ep=0.05, bev=0.012, dy=0.12)
        F(pas * 0.80, 0.30, x, H - 0.52, "dram", ep=0.20, bev=0.02)
        F(pas * 0.50, 0.11, x, H - 0.42, "voyant_teal", ep=0.012, bev=0, dy=0.20)
        F(pas * 0.80, 0.22, x, 0.26, "dram_sombre", ep=0.18, bev=0.02)


def ic_storage_rack():
    """Grille de 3 × 4 tiroirs à disques, une fente et un voyant corail par disque."""
    chassis(10)
    nx, nz = 3, 4
    sx, sz = (W - 0.80) / nx, (H - 0.62) / nz
    for i in range(nx):
        for k in range(nz):
            x = -(W - 0.80) / 2 + sx * (i + 0.5)
            z = 0.31 + k * sz
            F(sx - 0.10, sz - 0.10, x, z, "alu_brosse", ep=0.17, bev=0.03)
            F(sx - 0.34, 0.20, x - 0.02, z + sz * 0.46, "fond_noir", ep=0.012, bev=0, dy=0.17)
            F(0.30, 0.16, x + sx * 0.22, z + sz * 0.15, "voyant_corail", ep=0.012, bev=0, dy=0.17)
            F(0.34, 0.13, x - sx * 0.14, z + sz * 0.16, "noir_mat", ep=0.012, bev=0, dy=0.17)


def ic_network_rack():
    """Rangées de ports et voyants verts, cordons jaunes et bleus qui sortent de la façade et pendent sur le côté."""
    chassis(10)
    for r in range(4):
        z = 0.42 + r * 1.02
        F(W - 0.70, 0.80, 0, z, "noir_mat", ep=0.12, bev=0.02)
        for c in range(4):
            x = -1.05 + c * 0.70
            F(0.50, 0.40, x, z + 0.12, "fond_noir", ep=0.014, bev=0.004, dy=0.12)
            F(0.16, 0.10, x - 0.15, z + 0.60, "voyant_vert", ep=0.012, bev=0, dy=0.12)
            F(0.16, 0.10, x + 0.15, z + 0.60, "voyant_ambre" if (c + r) % 2 else "voyant_vert", ep=0.012, bev=0, dy=0.12)
    cordons = [(-1.05, 3.68, "cable_jaune", 1.1), (-0.35, 2.66, "cable_bleu", 0.6), (0.35, 3.68, "cable_bleu", 0.9), (1.05, 2.66, "cable_jaune", 0.4),
               (-0.35, 1.64, "cable_jaune", 0.4), (0.35, 0.62, "cable_bleu", 0.2)]
    for x, z, m, tombe in cordons:
        y0 = YF - 0.12
        F(0.32, 0.24, x, z - 0.08, m, ep=0.20, bev=0.02, dy=0.12)
        tube([(x, y0 - 0.20, z + 0.04), (x + 0.2, y0 - 0.60, z - 0.25), (W / 2 + 0.25 * tombe, y0 - 0.46, z - 1.0 - tombe * 0.3),
              (W / 2 + 0.34, y0 - 0.10, -0.1)], 0.085, m)


def ic_cooling_rack():
    """Un seul grand ventilateur à anneau froid, grille basse, et 2 gros tuyaux (eau glacée bleue, eau chaude rouge)."""
    chassis(10)
    r = 1.40
    zc = H * 0.60
    F(W - 0.70, H - 0.62, 0, 0.31, "noir_mat", ep=0.05, bev=0.012)
    def fan():
        ventilateur(0, 0, 0, r, cadre="alu_brosse", pales="alu_sombre", moyeu="carenage_clair", n=7, h=0.26, anneau="voyant_bleu")
    pivoter(capte(fan), rot=(90, 0, 0), loc=(0, YF - 0.05, zc))
    for i in range(3):
        F(W - 1.2, 0.09, 0, 0.46 + i * 0.17, "fond_noir", ep=0.012, bev=0, dy=0.05)
    # tuyaux sur le toit, qui replongent sur le flanc
    z1 = H + 0.26
    for x, m in ((-0.72, "tuyau_froid"), (0.72, "tuyau_chaud")):
        CY(0.36, 0.20, x, 0.1, z1, "alu_sombre", verts=24, bev=0.02)
        tube([(x, 0.1, z1 + 0.1), (x, 0.1, z1 + 0.62), (x + (0.7 if x > 0 else -0.4), 0.5, z1 + 0.88), (W / 2 + 0.55 if x > 0 else -W / 2 - 0.55, 0.9, z1 + 0.5)], 0.25, m)


def ic_gpu_blade():
    """Âge 11 : châssis d'alliage, 2 cartes graphiques debout, côte à côte, 2 grands ventilateurs par carte, liseré bleu-blanc."""
    chassis(11)
    n = 2
    pas = (W - 0.72) / n
    for i in range(n):
        x = -(W - 0.72) / 2 + pas * (i + 0.5)
        F(pas - 0.10, H - 0.68, x, 0.34, "titane_sombre", ep=0.20, bev=0.05)
        F(0.13, H - 0.90, x - pas / 2 + 0.17, 0.45, "ligne_bleu_blanc", ep=0.012, bev=0, dy=0.20)
        r = pas * 0.41
        for zz in (1.40, 3.20):
            def fan():
                ventilateur(0, 0, 0, r, cadre="alliage_blanc", pales="alu_brosse", moyeu="titane_sombre", n=7, h=0.12, anneau="ligne_bleu_blanc")
            pivoter(capte(fan), rot=(90, 0, 0), loc=(x + 0.09, YF - 0.20, zz))


def ic_quantum_rack():
    """Âge 13 : céramique et cuivre, grand hublot rond, coeur sphérique magenta et anneau d'or (comme le processeur), lignes cryogéniques."""
    chassis(13)
    zc = H * 0.54
    rh = 1.42
    F(W - 0.70, H - 0.62, 0, 0.31, "titane_sombre", ep=0.05, bev=0.012)
    def hublot():
        CY(rh + 0.05, 0.05, 0, 0, 0, "saphir", verts=64, bev=0)
        TOR(rh + 0.08, 0.17, 0, 0, 0.08, "cuivre", minor=12)
        coeur = P.mat_lum("coeur_b", (0.92, 0.10, 0.58), (0.30, 0.004, 0.20), 0.95)
        P.SPH(0.84, 0, 0, 0.10, coeur)
        TOR(1.10, 0.10, 0, 0, 0.14, "or", rot=(58, 0, 24), minor=10)
    pivoter(capte(hublot), rot=(90, 0, 0), loc=(0, YF - 0.05, zc))
    for i in range(3):
        F(0.46, 0.12, -0.60 + i * 0.60, 0.46, "voyant_ambre" if i == 1 else "plasma", ep=0.014, bev=0, dy=0.05)
    z1 = H + 0.26
    for i, x in enumerate((-0.95, 0.0, 0.95)):
        CY(0.30, 0.22, x, 0.1, z1, "or_sombre", verts=24, bev=0.02)
        CY(0.17, 0.62, x, 0.1, z1 + 0.22, "cuivre", verts=20, bev=0.015)
        TOR(0.21, 0.05, x, 0.1, z1 + 0.70, "or", minor=8)
