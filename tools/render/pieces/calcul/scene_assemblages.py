"""Scène Blender des icônes d'ASSEMBLAGES du calcul (lot CALC-ICONES-B, 30/10). S'exécute DANS Blender.

Lancé par icones_assemblages.py (jamais à la main) :
    blender -b --factory-startup -noaudio -P scene_assemblages.py -- --quoi a,b,c --out <dossier> --samples N --taille PX

Chaque icône est un petit objet modélisé à ses vraies proportions, vu en 3/4 par une caméra orthographique (objets :
élévation 52°, technologies : 34°, comme les icônes vanilla), éclairé du haut gauche, fond transparent, cadré
automatiquement sur la boîte de l'objet. Les matériaux viennent de fo_scene (grain, crasse des creux) ; les couleurs
d'âge de icones_assemblages.COULEURS (relues ici sans numpy). Sortie : <out>/<quoi>.png (sRGB 16 bits, alpha).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ICI, "..", "..", "blender"))
sys.path.insert(0, os.path.join(ICI, "..", ".."))
sys.path.insert(0, ICI)
import fo_scene as S  # noqa: E402
import couleurs_calcul as K  # noqa: E402


# ------------------------------------------------------------------------------------------------------------------
# Matériaux
# ------------------------------------------------------------------------------------------------------------------
_M = {}


def mat(nom):
    if nom in _M:
        return _M[nom]
    c = K.MAT[nom]
    if c.get("emis"):
        m = S.mat_emissive("m_" + nom, c["rgb"], strength=c["emis"], base=c.get("base", (0.02, 0.02, 0.03)))
    elif c.get("plat"):
        m = S.mat_flat("m_" + nom, c["rgb"], rough=c.get("rough", 0.6), metallic=c.get("met", 0.0))
    else:
        m = S.mat_metal("m_" + nom, c["rgb"], rough=c.get("rough", 0.45), metallic=c.get("met", 0.6),
                        grain=c.get("grain", 0.06), grain_scale=c.get("grain_scale", 40.0), dirt=c.get("dirt", 0.35),
                        dirt_distance=c.get("dirt_d", 0.12), seed=1.0)
    _M[nom] = m
    return m


def B(sx, sy, sz, x, y, z, m, bev=0.01, rot=0.0):
    """Boîte de taille (sx, sy, sz) dont la FACE INFÉRIEURE est à z."""
    o = S.box((sx, sy, sz), (x, y, z + sz / 2.0), mat(m), bevel_w=bev)
    if rot:
        o.rotation_euler = (0, 0, rot)
    return o


def CY(r, h, x, y, z, m, verts=40, bev=0.006, rot=(0, 0, 0), r2=None):
    """Cylindre vertical dont la base est à z (rot : rotation appliquée autour du centre)."""
    if rot == (0, 0, 0):
        return S.cylinder(r, h, (x, y, z + h / 2.0), mat(m), verts=verts, bevel_w=bev, radius2=r2)
    return S.cylinder(r, h, (x, y, z), mat(m), verts=verts, bevel_w=bev, rot=rot, radius2=r2)


def TOR(R, r, x, y, z, m, rot=(0, 0, 0)):
    return S.torus(R, r, (x, y, z), mat(m), rot=rot, major_seg=96, minor_seg=16)


def SPH(r, x, y, z, m):
    return S.sphere(r, (x, y, z), mat(m), seg=24, rings=12)


def grouper(objs, rot_z=0.0, centre=(0.0, 0.0), dz=0.0):
    """Tourne un ensemble d'objets autour de l'axe Z passant par `centre` (radians)."""
    c, s = math.cos(rot_z), math.sin(rot_z)
    for o in objs:
        x, y, z = o.location
        x -= centre[0]
        y -= centre[1]
        o.location = (centre[0] + c * x - s * y, centre[1] + s * x + c * y, z + dz)
        o.rotation_euler = (o.rotation_euler[0], o.rotation_euler[1], o.rotation_euler[2] + rot_z)
    return objs


def nouveaux(avant):
    return [o for o in S.piece_objects() if o.name not in avant]


def noms():
    return set(o.name for o in S.piece_objects())


# ------------------------------------------------------------------------------------------------------------------
# Pièces communes
# ------------------------------------------------------------------------------------------------------------------
def puce_bga(x, y, z, sx, sy, h=0.10, m="puce_noire", marque=True):
    """Boîtier de puce (BGA) : corps noir à arêtes douces, 2 lignes de marquage gris et un point d'orientation."""
    out = [B(sx, sy, h, x, y, z, m, bev=0.012)]
    if marque:
        out.append(B(sx * 0.62, sy * 0.10, 0.004, x - sx * 0.05, y + sy * 0.12, z + h, "marquage", bev=0))
        out.append(B(sx * 0.42, sy * 0.08, 0.004, x - sx * 0.15, y - sy * 0.10, z + h, "marquage", bev=0))
        out.append(CY(min(sx, sy) * 0.06, 0.004, x - sx * 0.36, y - sy * 0.32, z + h, "marquage", verts=12, bev=0))
    return out


def doigts_or(x0, x1, y, z, n, larg=0.10, prof=0.30, trou=None, m="or"):
    """Rangée de contacts dorés le long d'un bord (de x0 à x1, centrée en y)."""
    out = []
    pas = (x1 - x0) / n
    for i in range(n):
        if trou is not None and trou[0] <= i < trou[1]:
            continue
        cx = x0 + pas * (i + 0.5)
        out.append(B(larg, prof, 0.012, cx, y, z, m, bev=0.002))
    return out


def ailettes(x, y, z, sx, sy, h, n, m="alu_brosse", axe="x", base_h=0.05):
    """Radiateur : semelle et n ailettes minces parallèles à l'axe donné."""
    out = [B(sx, sy, base_h, x, y, z, m, bev=0.008)]
    if axe == "x":
        pas = sy / n
        for i in range(n):
            out.append(B(sx, pas * 0.42, h, x, y - sy / 2 + pas * (i + 0.5), z + base_h, m, bev=0.004))
    else:
        pas = sx / n
        for i in range(n):
            out.append(B(pas * 0.42, sy, h, x - sx / 2 + pas * (i + 0.5), y, z + base_h, m, bev=0.004))
    return out


def ventilateur(x, y, z, r, m_cadre, m_pales="pale_sombre", m_moyeu="titane", n=9, cadre_carre=True, h=0.10):
    """Ventilateur vu de dessus : cadre (carré ou anneau), pales inclinées, moyeu avec pastille."""
    out = []
    if cadre_carre:
        c = 2 * r * 1.08
        # cadre carré creux : 4 barres
        e = r * 0.16
        out += [B(c, e, h, x, y - c / 2 + e / 2, z, m_cadre, bev=0.01), B(c, e, h, x, y + c / 2 - e / 2, z, m_cadre, bev=0.01),
                B(e, c, h, x - c / 2 + e / 2, y, z, m_cadre, bev=0.01), B(e, c, h, x + c / 2 - e / 2, y, z, m_cadre, bev=0.01)]
    out.append(TOR(r * 0.98, r * 0.06, x, y, z + h * 0.8, m_cadre))
    out.append(CY(r * 0.96, 0.02, x, y, z, "fond_noir", verts=48, bev=0))
    for i in range(n):
        a = 2 * math.pi * i / n
        L = r * 0.62
        cx, cy = x + math.cos(a) * (r * 0.30 + L / 2), y + math.sin(a) * (r * 0.30 + L / 2)
        p = B(L, r * 0.30, 0.012, cx, cy, z + h * 0.45, m_pales, bev=0.004)
        p.rotation_euler = (math.radians(18), 0, a + math.radians(18))
        out.append(p)
    out.append(CY(r * 0.30, h * 0.75, x, y, z + 0.01, m_moyeu, verts=32, bev=0.01))
    out.append(CY(r * 0.16, 0.006, x, y, z + h * 0.76 + 0.01, "etiquette", verts=24, bev=0))
    return out


def barrette(x, y, z, L=6.0, W=1.30, debout=False, simple=False):
    """Barrette de mémoire vive (DIMM). Couchée : carte à plat, puces vers le haut. Debout (dans une baie) : carte
    verticale le long de x, vue de dessus = tranche avec son liseré lumineux."""
    out = []
    if debout:
        e = 0.06
        out.append(B(L, e, W, x, y, z, "pcb", bev=0.004))
        n = 8
        for i in range(n):
            cx = x - L / 2 + L * (i + 0.5) / n
            out.append(B(L / n * 0.72, 0.05, W * 0.42, cx, y - e / 2 - 0.025, z + W * 0.42, "puce_noire", bev=0.006))
            out.append(B(L / n * 0.72, 0.05, W * 0.42, cx, y + e / 2 + 0.025, z + W * 0.42, "puce_noire", bev=0.006))
        out.append(B(L * 1.01, 0.20, 0.09, x, y, z + W, "carenage_clair", bev=0.02))
        out.append(B(L * 0.86, 0.05, 0.03, x, y - 0.04, z + W + 0.09, "voyant_bleu", bev=0))
        out.append(B(0.25, 0.30, W * 0.9, x - L / 2 - 0.12, y, z, "loquet", bev=0.02))
        out.append(B(0.25, 0.30, W * 0.9, x + L / 2 + 0.12, y, z, "loquet", bev=0.02))
        return out
    # carte
    out.append(B(L, W, 0.07, x, y, z, "pcb", bev=0.012))
    zt = z + 0.07
    # contacts dorés (bas = -y), avec l'encoche décalée
    out += doigts_or(x - L / 2 + 0.15, x + L / 2 - 0.15, y - W / 2 + 0.14, zt, 36, larg=0.10, prof=0.26, trou=(15, 16))
    # pistes fines dorées au-dessus des contacts
    for i in range(18):
        px = x - L / 2 + 0.3 + i * (L - 0.6) / 17
        out.append(B(0.025, 0.16, 0.004, px, y - W / 2 + 0.36, zt, "or_sombre", bev=0))
    # 8 puces DRAM
    n = 8
    pas = (L - 0.5) / n
    for i in range(n):
        cx = x - L / 2 + 0.25 + pas * (i + 0.5)
        out += puce_bga(cx, y + 0.06, zt, pas * 0.74, W * 0.42, h=0.10)
    if simple:
        return out
    # petits composants : condensateurs et résistances entre les puces
    for i in range(n - 1):
        cx = x - L / 2 + 0.25 + pas * (i + 1)
        out.append(B(0.06, 0.12, 0.04, cx, y + 0.12, zt, "composant", bev=0.004))
        out.append(B(0.06, 0.12, 0.04, cx, y - 0.10, zt, "composant_clair", bev=0.004))
    # puce SPD et étiquette
    out += puce_bga(x + L * 0.30, y - W / 2 + 0.52, zt, 0.30, 0.16, h=0.06, marque=False)
    out.append(B(0.9, 0.14, 0.006, x - L * 0.18, y - W / 2 + 0.52, zt, "etiquette", bev=0))
    # barre de maintien en aluminium clair de l'âge 10, sur le bord haut, avec son liseré de voyants bleus
    out.append(B(L * 0.98, 0.20, 0.16, x, y + W / 2 - 0.10, zt, "carenage_clair", bev=0.03))
    out.append(B(L * 0.80, 0.05, 0.02, x, y + W / 2 - 0.16, zt + 0.16, "voyant_bleu", bev=0))
    for sx in (-1, 1):
        out.append(CY(0.07, 0.03, x + sx * L * 0.45, y + W / 2 - 0.10, zt + 0.16, "vis", verts=16, bev=0.003))
    return out


def carte_mere(x, y, z, sx=4.6, sy=3.2, sockets=1, pistes=True):
    out = [B(sx, sy, 0.06, x, y, z, "pcb", bev=0.01)]
    zt = z + 0.06
    if pistes:
        # faisceaux de pistes dorées (fines lignes en L)
        for i in range(10):
            yy = y - sy * 0.40 + i * 0.07
            out.append(B(sx * 0.30, 0.018, 0.003, x - sx * 0.22, yy, zt, "or_sombre", bev=0))
        for i in range(8):
            xx = x + sx * 0.05 + i * 0.07
            out.append(B(0.018, sy * 0.30, 0.003, xx, y + sy * 0.25, zt, "or_sombre", bev=0))
    return out, zt


# ------------------------------------------------------------------------------------------------------------------
# Les icônes
# ------------------------------------------------------------------------------------------------------------------
def ic_memory_module():
    """Barrette de mémoire vive : DIMM à plat, 8 puces DRAM noires, contacts dorés, barre claire à voyants bleus."""
    av = noms()
    barrette(0, 0, 0, L=5.0, W=1.80)
    grouper(nouveaux(av), rot_z=math.radians(36))


def ic_motherboard():
    """Carte mère : socle du processeur (cadre clair, capot, levier), 4 fentes de mémoire, oscillateur à cristal,
    condensateurs, bloc d'entrées-sorties, pistes dorées."""
    av = noms()
    sx, sy = 4.6, 4.0
    out, zt = carte_mere(0, 0, 0, sx, sy)
    # socle du processeur
    B(1.30, 1.30, 0.10, -0.55, 0.45, zt, "carenage_clair", bev=0.02)
    B(1.00, 1.00, 0.08, -0.55, 0.45, zt + 0.10, "titane_sombre", bev=0.02)
    B(0.60, 0.60, 0.02, -0.55, 0.45, zt + 0.18, "voyant_bleu", bev=0)
    B(0.08, 1.2, 0.06, 0.20, 0.45, zt + 0.02, "vis", bev=0.01)
    # 4 fentes de mémoire (noires, loquets clairs)
    for i in range(4):
        xx = 0.95 + i * 0.26
        B(0.12, 2.6, 0.14, xx, 0.15, zt, "puce_noire", bev=0.01)
        B(0.14, 0.12, 0.18, xx, 0.15 - 1.32, zt, "loquet", bev=0.01)
        B(0.14, 0.12, 0.18, xx, 0.15 + 1.32, zt, "loquet", bev=0.01)
    # oscillateur à cristal (boîtier métal ovale)
    o = CY(0.22, 0.12, -1.75, -1.35, zt, "vis", verts=32)
    o.scale = (1.6, 1.0, 1.0)
    # condensateurs électrolytiques
    for i in range(6):
        CY(0.10, 0.26, -1.55 + i * 0.24, 1.55, zt, "condensateur", verts=24, bev=0.01)
        CY(0.07, 0.005, -1.55 + i * 0.24, 1.55, zt + 0.26, "vis", verts=16, bev=0)
    # bloc d'entrées-sorties (bord gauche)
    B(0.45, 1.6, 0.42, -2.0, 0.4, zt, "carenage_clair", bev=0.03)
    for i in range(3):
        B(0.30, 0.32, 0.12, -2.0, -0.1 + i * 0.45, zt + 0.42, "puce_noire", bev=0.01)
    # pont sud : puce sous petit radiateur
    out2 = ailettes(-0.3, -1.25, zt, 0.8, 0.8, 0.18, 7, m="alu_brosse")
    # connecteurs PCIe (2 fentes noires longues)
    for i in range(2):
        B(2.0, 0.12, 0.12, 1.0, -1.35 - i * 0.30, zt, "puce_noire", bev=0.01)
    grouper(nouveaux(av), rot_z=math.radians(-8))


def ic_server_blade():
    """Baie de serveurs (tiroir 1U, âge 10) : châssis gris clair ouvert, carte mère, 2 processeurs sous radiateurs à
    ailettes, 4 barrettes debout, 3 ventilateurs à l'arrière, façade à poignées et voyants bleus."""
    av = noms()
    LX, LY, H = 4.8, 4.6, 0.62
    # fond et flancs
    B(LX, LY, 0.08, 0, 0, 0, "carenage_clair", bev=0.02)
    B(0.10, LY, H, -LX / 2 + 0.05, 0, 0, "carenage_clair", bev=0.02)
    B(0.10, LY, H, LX / 2 - 0.05, 0, 0, "carenage_clair", bev=0.02)
    B(LX, 0.10, H, 0, LY / 2 - 0.05, 0, "carenage_clair", bev=0.02)
    # rails de glissière (bandes sombres sur les flancs)
    B(0.04, LY * 0.9, 0.12, -LX / 2 - 0.02, 0, 0.25, "noir_mat", bev=0.005)
    B(0.04, LY * 0.9, 0.12, LX / 2 + 0.02, 0, 0.25, "noir_mat", bev=0.005)
    # façade (côté -y, vers le joueur)
    fy = -LY / 2 - 0.08
    B(LX + 0.10, 0.18, H + 0.04, 0, fy, 0, "carenage_clair", bev=0.03)
    # grille d'aération de la façade
    for i in range(14):
        B(0.10, 0.02, 0.30, -1.1 + i * 0.17, fy - 0.095, 0.16, "fond_noir", bev=0)
    # poignées
    for sx in (-1, 1):
        B(0.12, 0.30, 0.10, sx * (LX / 2 - 0.35), fy - 0.18, 0.40, "titane_sombre", bev=0.02)
        B(0.12, 0.30, 0.10, sx * (LX / 2 - 0.35), fy - 0.18, 0.10, "titane_sombre", bev=0.02)
        B(0.12, 0.10, 0.40, sx * (LX / 2 - 0.35), fy - 0.30, 0.10, "titane_sombre", bev=0.02)
    # voyants bleus et étiquette
    for i in range(4):
        CY(0.05, 0.02, 1.35 + i * 0.16, fy - 0.09, 0.45, "voyant_bleu", verts=12, bev=0, rot=(math.radians(90), 0, 0))
    B(0.6, 0.01, 0.14, -1.55, fy - 0.095, 0.38, "etiquette", bev=0)
    # carte mère
    out, zt = carte_mere(0, -0.2, 0.08, LX - 0.4, LY - 1.2, pistes=False)
    # 2 processeurs : radiateurs à ailettes
    for sx in (-1, 1):
        ailettes(sx * 1.20, -0.45, zt, 1.25, 1.35, 0.42, 12, m="alu_brosse", axe="x")
        B(1.30, 0.10, 0.06, sx * 1.20, -0.45 - 0.72, zt, "titane_sombre", bev=0.01)
    # 4 barrettes debout, entre les processeurs
    for i in range(4):
        barrette(0, -1.00 + i * 0.32, zt, L=0.85, W=0.36, debout=True)
    for i in range(4):
        pass
    # 3 ventilateurs à l'arrière (rangée)
    for i in range(3):
        ventilateur(-1.45 + i * 1.45, 1.55, 0.08, 0.55, "noir_mat", m_moyeu="carenage_clair", h=0.42)
    # câbles plats
    B(0.30, 0.9, 0.02, -2.2, 0.6, zt, "cable_gris", bev=0)
    grouper(nouveaux(av), rot_z=0.0)


def carte_graphique(x, y, z, L=4.4, W=1.8, simple=False):
    """Carte graphique (âge 11) : PCB, carénage de titane à facettes, UN grand ventilateur, fenêtre d'ailettes,
    liseré bleu-blanc, contacts dorés PCIe en bas, équerre d'alliage blanc à gauche."""
    out = []
    out.append(B(L, W, 0.06, x, y, z, "pcb", bev=0.01))
    zt = z + 0.06
    out += doigts_or(x - L * 0.30, x + L * 0.40, y - W / 2 - 0.10, z, 26, larg=0.08, prof=0.22, trou=(6, 7))
    # carénage : coque de titane en deux plans (biseaux) et arête blanche
    hc = 0.34
    out.append(B(L * 0.94, W * 0.96, hc, x + L * 0.02, y, zt, "titane", bev=0.06))
    out.append(B(L * 0.90, 0.08, 0.04, x + L * 0.02, y - W * 0.48 + 0.04, zt + hc, "alliage_blanc", bev=0.01))
    out.append(B(L * 0.90, 0.08, 0.04, x + L * 0.02, y + W * 0.48 - 0.04, zt + hc, "alliage_blanc", bev=0.01))
    out.append(B(L * 0.70, 0.04, 0.02, x + L * 0.08, y - W * 0.48 + 0.04, zt + hc + 0.04, "ligne_bleu_blanc", bev=0))
    # ventilateur (côté droit)
    r = W * 0.40
    out += ventilateur(x + L * 0.24, y, zt + hc - 0.08, r, "titane_sombre", m_moyeu="alliage_blanc", h=0.14,
                       cadre_carre=False)
    out.append(TOR(r * 1.04, r * 0.035, x + L * 0.24, y, zt + hc + 0.02, "ligne_bleu_blanc"))
    if not simple:
        # fenêtre d'ailettes (côté gauche) : radiateur visible par l'ouverture
        out.append(B(L * 0.36, W * 0.70, 0.02, x - L * 0.20, y, zt + hc - 0.01, "fond_noir", bev=0))
        out += ailettes(x - L * 0.20, y, zt + hc - 0.10, L * 0.34, W * 0.66, 0.10, 12, m="alu_brosse", axe="y",
                        base_h=0.01)
        # 4 vis du carénage
        for dx, dy in ((-0.46, -0.40), (-0.46, 0.40), (0.46, -0.40), (0.46, 0.40)):
            out.append(CY(0.05, 0.02, x + L * dx, y + W * dy, zt + hc, "vis", verts=12, bev=0.003))
    # équerre (bracket) d'alliage blanc, ajourée
    out.append(B(0.08, W * 1.10, 0.62, x - L / 2 - 0.04, y, z - 0.08, "alliage_blanc", bev=0.01))
    for i in range(3):
        out.append(B(0.02, 0.24, 0.10, x - L / 2 - 0.09, y - 0.45 + i * 0.32, z + 0.15, "fond_noir", bev=0))
    return out


def ic_graphics_card():
    av = noms()
    carte_graphique(0, 0, 0)
    grouper(nouveaux(av), rot_z=math.radians(30))


def ic_gpu_blade():
    """Baie d'accélérateurs (tiroir 2U, âge 11) : châssis d'alliage blanc à rails de titane, 4 cartes graphiques
    couchées en 2 × 2 (4 ventilateurs bien lisibles), façade à ligne bleu-blanc continue (chenillard de l'âge 11),
    ailerons triangulaires aux poignées."""
    av = noms()
    LX, LY, H = 4.8, 4.6, 0.95
    B(LX, LY, 0.08, 0, 0, 0, "alliage_blanc", bev=0.02)
    B(0.12, LY, H, -LX / 2 + 0.06, 0, 0, "alliage_blanc", bev=0.02)
    B(0.12, LY, H, LX / 2 - 0.06, 0, 0, "alliage_blanc", bev=0.02)
    B(LX, 0.12, H, 0, LY / 2 - 0.06, 0, "alliage_blanc", bev=0.02)
    # rails de titane
    for sx in (-1, 1):
        B(0.06, LY * 0.92, 0.18, sx * (LX / 2 + 0.03), 0, 0.35, "titane", bev=0.01)
    # façade
    fy = -LY / 2 - 0.10
    B(LX + 0.12, 0.20, H + 0.05, 0, fy, 0, "titane", bev=0.03)
    B(LX * 0.80, 0.02, 0.07, 0, fy - 0.11, 0.62, "ligne_bleu_blanc", bev=0)
    for i in range(16):
        B(0.09, 0.02, 0.32, -1.6 + i * 0.213, fy - 0.105, 0.18, "fond_noir", bev=0)
    # poignées en aileron triangulaire (signature de l'âge 11)
    for sx in (-1, 1):
        a = B(0.14, 0.55, 0.70, sx * (LX / 2 - 0.30), fy - 0.30, 0.12, "alliage_blanc", bev=0.03)
        a.rotation_euler = (math.radians(-28), 0, 0)
    # 4 cartes graphiques en 2 × 2
    for ix, sx in enumerate((-1, 1)):
        for iy, sy in enumerate((-1, 1)):
            carte_graphique(sx * 1.13, sy * 1.02 + 0.05, 0.10, L=2.15, W=1.80, simple=True)
    grouper(nouveaux(av), rot_z=0.0)


def puce_qubits(x, y, z, c=1.0, lumiere=True):
    """Puce à qubits (âge 13) : boîtier de céramique blanche, couronne de plots de cuivre, puce de saphir avec circuit
    supraconducteur (lignes et croix dorées) et qubits magenta."""
    out = [B(c, c, 0.10 * c, x, y, z, "ceramique", bev=0.02 * c)]
    zt = z + 0.10 * c
    n = 7
    for i in range(n):
        t = -c * 0.38 + i * c * 0.76 / (n - 1)
        for (dx, dy, sx, sy) in ((t, -c * 0.44, 0.06, 0.10), (t, c * 0.44, 0.06, 0.10), (-c * 0.44, t, 0.10, 0.06),
                                 (c * 0.44, t, 0.10, 0.06)):
            out.append(B(sx * c, sy * c, 0.01 * c, x + dx, y + dy, zt, "cuivre", bev=0.002))
    out.append(B(c * 0.56, c * 0.56, 0.03 * c, x, y, zt, "saphir", bev=0.004))
    z2 = zt + 0.03 * c
    # lignes de lecture (en serpentin simplifié) et qubits en croix
    for i in range(4):
        a = i * math.pi / 2
        px, py = x + math.cos(a) * c * 0.15, y + math.sin(a) * c * 0.15
        out.append(B(c * 0.12, c * 0.025, 0.004 * c, px, py, z2, "or", bev=0, rot=a))
        out.append(B(c * 0.025, c * 0.12, 0.004 * c, px, py, z2, "or", bev=0, rot=a))
        out.append(CY(c * 0.028, 0.008 * c, px, py, z2, "plasma" if lumiere else "or", verts=16, bev=0))
        out.append(B(c * 0.20, c * 0.012, 0.003 * c, x + math.cos(a) * c * 0.22 * 0.9, y + math.sin(a) * c * 0.22 * 0.9,
                     z2, "or", bev=0, rot=a))
    return out


def lustre(x, y, z, echelle=1.0, plaques=4, avec_puce=True, lumiere=True):
    """Étage à dilution (« lustre ») : plaques dorées en cascade de rayon décroissant vers le bas, tiges, câbles
    coaxiaux de cuivre, échangeurs en spirale, bride supérieure de céramique blanche ; puce à qubits en bas."""
    e = echelle
    out = []
    rs = [1.25, 1.08, 0.92, 0.78, 0.66][:plaques]
    zs = [z + e * (3.4 - i * 0.80) for i in range(plaques)]
    # bride supérieure de céramique et collier de cuivre
    out.append(CY(e * 1.38, e * 0.16, x, y, zs[0] + e * 0.22, "ceramique", verts=64, bev=0.02))
    out.append(TOR(e * 1.30, e * 0.05, x, y, zs[0] + e * 0.38, "cuivre"))
    out.append(CY(e * 0.32, e * 0.30, x, y, zs[0] + e * 0.38, "cuivre", verts=32, bev=0.01))
    for i, (r, zz) in enumerate(zip(rs, zs)):
        out.append(CY(e * r, e * 0.07, x, y, zz, "or", verts=72, bev=0.012))
        # liseré de vis sur la plaque
        out.append(S.rivet_ring(e * r * 0.88, zz + e * 0.07, 14, e * 0.022, mat("or_sombre"), center=(x, y)))
        if i + 1 < plaques:
            # tiges entre les plaques
            for k in range(6):
                a = 2 * math.pi * k / 6 + 0.3
                rr = e * rs[i + 1] * 0.86
                out.append(CY(e * 0.035, zz - zs[i + 1], x + rr * math.cos(a), y + rr * math.sin(a), zs[i + 1], "or_sombre",
                              verts=12, bev=0))
            # échangeur : spirale de cuivre (suite de petits tores)
            for k in range(3):
                out.append(TOR(e * 0.30, e * 0.035, x, y, zs[i + 1] + e * (0.20 + 0.18 * k), "cuivre"))
            # câbles coaxiaux (côté avant)
            for k in range(4):
                a = math.radians(-110 + k * 14)
                rr = e * rs[i + 1] * 0.62
                out.append(CY(e * 0.026, zz - zs[i + 1], x + rr * math.cos(a), y + rr * math.sin(a), zs[i + 1], "cuivre",
                              verts=10, bev=0))
    # étage de la puce (porte-échantillon) sous la dernière plaque
    zb = zs[-1] - e * 0.55
    out.append(CY(e * 0.10, e * 0.55, x, y, zb, "or_sombre", verts=16, bev=0))
    out.append(B(e * 0.62, e * 0.62, e * 0.06, x, y, zb - e * 0.06, "cuivre", bev=0.01))
    if avec_puce:
        out += puce_qubits(x, y, zb - e * 0.06 - e * 0.10, c=e * 0.48, lumiere=lumiere)
    return out, zb


def ic_dilution_stage():
    lustre(0, 0, 0, plaques=4, avec_puce=False, lumiere=False)


def ic_qubit_chip():
    av = noms()
    puce_qubits(0, 0, 0, c=2.0)
    grouper(nouveaux(av), rot_z=math.radians(12))


def ic_quantum_processor():
    """Processeur quantique : le lustre à 4 plaques avec sa puce à qubits allumée, ceinturé d'un TORE de plasma
    magenta horizontal (signature de l'âge 13, « planète à anneau »)."""
    out, zb = lustre(0, 0, 0.0, plaques=4, avec_puce=True, lumiere=True)
    zt = zb + 1.0
    TOR(1.62, 0.09, 0, 0, zt, "plasma")
    TOR(1.62, 0.17, 0, 0, zt, "plasma_halo")
    # trois injecteurs de céramique qui tiennent le tore
    for k in range(3):
        a = math.radians(-90 + k * 120 + 40)
        B(0.16, 0.16, 0.36, 1.62 * math.cos(a), 1.62 * math.sin(a), zt - 0.18, "ceramique", bev=0.03)


def baie_rack(x, y, z, h=4.2, w=1.5, d=1.5):
    """Armoire de centre de calcul (technologie) : caisson gris clair, porte vitrée sombre, colonnes de voyants bleus,
    tiroirs visibles derrière la vitre, toit à grille."""
    out = [B(w, d, h, x, y, z, "carenage_clair", bev=0.04)]
    fy = y - d / 2
    out.append(B(w * 0.86, 0.04, h * 0.90, x, fy - 0.01, z + h * 0.05, "vitre_sombre", bev=0.01))
    for i in range(10):
        zz = z + h * 0.08 + i * h * 0.084
        out.append(B(w * 0.76, 0.02, h * 0.050, x, fy - 0.035, zz, "titane_sombre", bev=0.004))
        for k in range(3):
            out.append(B(0.06, 0.02, 0.05, x - w * 0.30 + k * 0.10, fy - 0.05, zz + h * 0.015, "voyant_bleu", bev=0))
    out.append(B(0.05, 0.08, h * 0.30, x + w * 0.40, fy - 0.06, z + h * 0.35, "vis", bev=0.01))
    # grille du toit
    for i in range(6):
        out.append(B(w * 0.8, 0.04, 0.02, x, y - d * 0.35 + i * d * 0.14, z + h, "fond_noir", bev=0))
    return out


def tech_data_centers():
    """Technologie « Centres de calcul » : rangée de 3 armoires (vue isométrique), chemin de câbles au-dessus, et la
    baie de serveurs tirée hors de l'armoire de devant."""
    for i in range(3):
        baie_rack(-1.7 + i * 1.7, 0.0 + i * 0.0, 0, h=4.0)
    # chemin de câbles
    B(5.4, 0.5, 0.10, 0, 0, 4.3, "titane_sombre", bev=0.02)
    for i in range(5):
        CY(0.06, 5.2, 0.0, 0.12 * (i - 2), 4.48, "cable_gris", verts=10, rot=(0, math.radians(90), 0))
    # baie de serveurs tirée hors de l'armoire du milieu, sur ses glissières
    zb, yc, LX, LY = 1.55, -1.75, 1.30, 1.90
    for sx in (-1, 1):
        B(0.05, LY + 0.4, 0.08, sx * (LX / 2 + 0.03), yc + 0.2, zb + 0.06, "titane_sombre", bev=0.005)
    B(LX, LY, 0.05, 0, yc, zb, "carenage_clair", bev=0.015)
    for sx in (-1, 1):
        B(0.05, LY, 0.24, sx * (LX / 2 - 0.025), yc, zb, "carenage_clair", bev=0.01)
    B(LX - 0.1, LY - 0.3, 0.03, 0, yc + 0.05, zb + 0.05, "pcb", bev=0.005)
    ailettes(-0.32, yc - 0.05, zb + 0.08, 0.46, 0.50, 0.20, 8)
    ailettes(0.32, yc - 0.05, zb + 0.08, 0.46, 0.50, 0.20, 8)
    for i in range(4):
        B(0.86, 0.035, 0.18, 0, yc + 0.40 + i * 0.09, zb + 0.08, "puce_noire", bev=0.004)
        B(0.80, 0.02, 0.012, 0, yc + 0.40 + i * 0.09, zb + 0.26, "voyant_bleu", bev=0)
    fy = yc - LY / 2 - 0.04
    B(LX + 0.06, 0.08, 0.28, 0, fy, zb, "carenage_clair", bev=0.015)
    for i in range(4):
        CY(0.028, 0.02, 0.25 + i * 0.08, fy - 0.045, zb + 0.16, "voyant_bleu", verts=8, bev=0, rot=(math.radians(90), 0, 0))
    for sx in (-1, 1):
        B(0.06, 0.12, 0.20, sx * (LX / 2 - 0.12), fy - 0.08, zb + 0.04, "titane_sombre", bev=0.01)

ICONES = {
    # nom : (fonction, genre, élévation de la caméra, azimut)
    "fo-memory-module": (ic_memory_module, "objet", 62.0, 22.0),
    "fo-motherboard": (ic_motherboard, "objet", 52.0, 22.0),
    "fo-server-blade": (ic_server_blade, "objet", 60.0, 18.0),
    "fo-graphics-card": (ic_graphics_card, "objet", 52.0, 22.0),
    "fo-gpu-blade": (ic_gpu_blade, "objet", 60.0, 18.0),
    "fo-qubit-chip": (ic_qubit_chip, "objet", 52.0, 22.0),
    "fo-dilution-stage": (ic_dilution_stage, "objet", 22.0, 20.0),
    "fo-quantum-processor": (ic_quantum_processor, "objet", 22.0, 20.0),
    "tech-fo-data-centers": (tech_data_centers, "techno", 30.0, 40.0),
}


# ------------------------------------------------------------------------------------------------------------------
# Caméra, lumières, cadrage
# ------------------------------------------------------------------------------------------------------------------
def direction(az_deg, el_deg):
    """Vecteur du point visé VERS la caméra : az 0 = caméra au sud, positif vers l'ouest... (sens trigonométrique)."""
    a, e = math.radians(az_deg), math.radians(el_deg)
    return Vector((-math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))


def soleil(scene, vers_soleil, force, couleur=(1.0, 0.97, 0.92), ombre=True, angle=4.0, nom="sun"):
    d = bpy.data.lights.new(nom, "SUN")
    d.energy = force
    d.color = couleur
    d.angle = math.radians(angle)
    d.use_shadow = ombre
    o = bpy.data.objects.new(nom, d)
    scene.collection.objects.link(o)
    o.rotation_euler = Vector(vers_soleil).normalized().to_track_quat("Z", "Y").to_euler()
    return o


def cadrer(scene, cam, remplir):
    """Caméra orthographique cadrée sur la boîte projetée de tous les sommets (modificateurs compris)."""
    dg = bpy.context.evaluated_depsgraph_get()
    R = cam.matrix_world.to_3x3()
    droite, haut = R.col[0], R.col[1]
    xs, ys = [], []
    for o in S.piece_objects():
        if o.type != "MESH":
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        mw = o.matrix_world
        for v in me.vertices:
            p = mw @ v.co
            xs.append(p.dot(droite))
            ys.append(p.dot(haut))
        ev.to_mesh_clear()
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    ext = max(max(xs) - min(xs), max(ys) - min(ys))
    cam.data.ortho_scale = ext / remplir
    cam.location = cam.location + droite * (cx - cam.location.dot(droite)) + haut * (cy - cam.location.dot(haut))


def rendre(quoi, out_dir, samples, taille):
    fn, genre, el, az = ICONES[quoi]
    scene = S.reset()
    _M.clear()
    S.setup_render(scene, taille, taille, samples=samples, seed=20261030)
    scene.cycles.max_bounces = 6
    fn()
    d = direction(az, el)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.clip_start = 0.1
    cam_data.clip_end = 400.0
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = d * 100.0
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    bpy.context.view_layer.update()
    cadrer(scene, cam, 0.97 if genre == "objet" else 0.92)
    R = cam.matrix_world.to_3x3()
    droite, haut = R.col[0], R.col[1]
    # lumière clé du haut gauche (comme les icônes vanilla), appoint froid à droite, contre-jour doux
    soleil(scene, (-droite * 0.75 + haut * 0.55 + d * 0.55 + Vector((0, 0, 0.6))), 4.4, nom="cle")
    soleil(scene, (droite * 0.9 + d * 0.5 + Vector((0, 0, 0.3))), 0.9, couleur=(0.85, 0.92, 1.0), ombre=False, nom="appoint")
    soleil(scene, (-d * 0.8 + Vector((0, 0, 0.7)) + droite * 0.3), 1.6, couleur=(1.0, 1.0, 1.0), ombre=False, nom="contre")
    w = bpy.data.worlds.new("monde")
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.55, 0.60, 0.68, 1.0)
    bg.inputs["Strength"].default_value = 0.70
    scene.world = w
    chemin = os.path.join(out_dir, quoi + ".png")
    scene.render.filepath = chemin
    bpy.ops.render.render(write_still=True)
    print("[CALC-ICONES-B] rendu %s -> %s" % (quoi, chemin))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    quoi, out, samples, taille = None, None, 12, 512
    i = 0
    while i < len(argv):
        if argv[i] == "--quoi":
            quoi = argv[i + 1].split(",")
        elif argv[i] == "--out":
            out = argv[i + 1]
        elif argv[i] == "--samples":
            samples = int(argv[i + 1])
        elif argv[i] == "--taille":
            taille = int(argv[i + 1])
        i += 2
    os.makedirs(out, exist_ok=True)
    for q in quoi:
        rendre(q, out, samples, taille)


main()
