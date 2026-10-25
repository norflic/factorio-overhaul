"""Laser · Âge 3 · Vapeur (ère I, 2×2, niveaux 5 et 6). EXEMPLE du kit laser_e (lot F1-A, aperçu d'essai) ; fiche :
fo-logs/2026-10-24_F1/FICHES_LASER.md, âge 3 (fait foi). S'exécute DANS Blender.

En 3 mots : « globe de cuivre, serpentins, cadrans ». Un laser de salon de locomotive : l'émetteur est un GLOBE DE
CUIVRE rose cerclé de laiton, ceint d'un SERPENTIN de refroidissement, la lentille ambrée dans une sertissure de laiton ;
il repose dans un BERCEAU ; derrière lui, une petite chaudière couchée (en travers du faisceau, jamais dressée).
Affût BOMBÉ à 3 gradins de cuivre (comme une chaudière), dessus en tôles vertes de locomotive, rivets de laiton ;
condensateurs = accumulateurs de vapeur à CADRAN ; liaisons en tuyaux de cuivre à brides de laiton.
Palette 60/30/10 (ages.PALETTE[3]) : cuivre rose / vert locomotive / laiton ; lumière ambre #FFC060.
Même âge que la mitrailleuse 3 (même cuivre, même vert, même ambre) ; jamais confondue avec elle : affût rond à gradins,
aucun canon, aucune trémie.
"""
import math

from mathutils import Vector

import ages
import corps
import formes as F
import orne as O
import parts2 as P2
from kit import SQ2, TAU
from repere import Y, at

V = Vector

EPOQUE = 3
NOM = ages.NOMS[3]
TRIPLET = ("globe de cuivre", "serpentins", "cadrans")
FOYER = ages.FOYER[3]
FAISCEAU = dict(rgb=(1.0, 0.72, 0.3), forme="ruban ambré, cœur blanc, bords ondulés (vapeur)", largeur=0.9)
HABILLAGE = dict(ages.CORPS[3],
                 cerclages="laiton_capot",
                 forme_affut=dict(gradins=3, profil="bombe", flanc="cuivre_capot", flanc2="cuivre_sombre",
                                  rapport=0.76),
                 forme_tete="berceau",
                 # lot F1-B : POINTS BLANCS (13,8 au socle et 15,0 à la pièce, plafond 13,2, essai r0b du lot F1-A) :
                 # rivets et boulons du dessus en laiton de capot (mat) au lieu du laiton de rivet (reflet fin)
                 rivets="laiton_capot",
                 plateforme=dict(ages.CORPS[3]["plateforme"], boulons="laiton_capot"))


def matieres(metal, M):
    ages.matieres(3, metal, M)
    M["globe"] = M["cuivre_capot"]
    M["serpentin"] = M["cuivre_sombre"]


def _halo(g, pts, power):
    for p in pts:
        g.halo(p, g.M["_emit_rgb"], power)


def _cadran(g, p, nrm, r, M, face=None):
    """Manomètre MAT (lot F1-B) : boîtier de laiton de capot (le laiton poli de parts2.gauge fait des points blancs),
    cadran ambré faible, aiguille sombre."""
    a = V(nrm).normalized()
    p = V(p)
    g.cyl(p + a * 0.012, a, r, 0.024, M["laiton_capot"], n=14, style="hard", what="manometre")
    g.cyl(p + a * 0.026, a, r * 0.76, 0.006, face or M["emit_soft"], n=14, style="flat", what="cadran")
    g.cyl(p + a * 0.03, a, r * 0.12, 0.006, M["cuivre_sombre"], n=8, style="flat", what="axe_aiguille")


def _robinet(g, k, h):
    """Robinet de vapeur sur le flanc (repère du flanc) : piquage de cuivre, petit volant de laiton mat, cadran."""
    M = g.M
    g.cyl((0, 0, 0.025), "z", 0.025, 0.05, M["cuivre_sombre"], n=10, what="piquage")
    g.torus((0, 0, 0.055), "z", 0.035, 0.009, M["laiton_capot"], n=14, m=5, what="volant")
    g.box((0, 0, 0.055), (0.07, 0.01, 0.01), M["laiton_capot"], "hard", what="rayon")
    if k % 2 == 0:
        _cadran(g, (0.07, h * 0.15, 0.0), (0, 0, 1), 0.035, M)


def _sifflet(g, k, w):
    """Dessus du dernier gradin : sifflet couché, burette, petite caisse de charbon."""
    M = g.M
    if k % 3 == 0:
        g.cyl((0, 0, 0.03), "y", 0.022, 0.1, M["laiton_capot"], n=10, what="sifflet")
        g.cyl((0, 0.05, 0.03), "y", 0.03, 0.02, M["cuivre_sombre"], n=10, what="pavillon")
    elif k % 3 == 1:
        g.cyl((0, 0, 0.03), "z", 0.03, 0.06, M["cuivre_capot"], n=10, r2=0.012, what="burette")
    else:
        g.box((0, 0, 0.025), (0.07, 0.05, 0.05), M["bois_verni"], "hard", what="caisse")
        g.box((0, 0, 0.051), (0.06, 0.04, 0.006), M["soot"], "flat", what="charbon")


def liaison(g, pts, r):
    """Tuyau de cuivre à brides de laiton boulonnées."""
    M = g.M
    g.pipe(pts, r, M["cuivre_capot"], fl_mat=M["laiton_capot"], bolt_mat=M["laiton_rivet"])


def condensateur(g, c, x, y, z, r, h):
    """Accumulateur de vapeur : cylindre vert locomotive à deux cerclages de laiton, dôme de cuivre, CADRAN tourné vers
    l'extérieur (ambre faible), soupape."""
    M = g.M
    g.cyl((x, y, z + h * 0.45), "z", r, h * 0.9, M["vert_loco"], n=20, style="soft", what="accumulateur")
    for f in (0.12, 0.78):
        g.tube_shell((x, y, z + h * f), "z", r + 0.012, r - 0.01, 0.028, M["laiton_capot"], n=20, what="cerclage")
    g.sphere((x, y, z + h * 0.9), r * 0.95, M["cuivre_capot"], n=16, m=8, scale=(1, 1, 0.55), what="dome")
    d = V((x, y / SQ2, 0)).normalized()
    if d.y < 0.3:   # cadran sur les accumulateurs vus de face
        p = V((x, y, z + h * 0.5)) + V((d.x, d.y * SQ2, 0)).normalized() * (r + 0.004)
        _cadran(g, p, (d.x, d.y, 0.25), r * 0.62, M, face=M["emit_soft"])
    g.cyl((x, y, z + h * 0.9 + r * 0.6), "z", r * 0.2, 0.06, M["laiton_capot"], n=8, what="soupape")


def socle(g, c):
    """Machine à vapeur verticale à volant au coin arrière gauche, petit réservoir au coin arrière droit, tuyaux de
    cuivre vers le pivot, manomètres ; halos ambrés."""
    M = g.M
    pNO, pNE = corps.place(c, "coin_NO"), corps.place(c, "coin_NE")
    zp = c.gradins[-1][3]
    # dynamo à vapeur (NO) : bâti de fonte, cylindre, volant de laiton, posée contre le premier gradin
    with at(g, pNO["x"] + 0.04, pNO["yn"] - 0.04):
        g.box((0, 0, 0.05), (0.32, 0.26, 0.1), M["vert_loco"], "hard", what="bati")
        g.cyl((0.02, 0, 0.2), "z", 0.07, 0.2, M["cuivre_capot"], n=16, style="soft", what="cylindre")
        g.tube_shell((0.02, 0, 0.28), "z", 0.08, 0.06, 0.03, M["laiton_capot"], n=16, what="cerclage")
        g.cyl((0.02, 0, 0.32), "z", 0.035, 0.05, M["laiton_capot"], n=10, what="regulateur")
        for k in range(2):
            a = TAU * k / 2
            g.sphere((0.02 + 0.05 * math.cos(a), 0.05 * math.sin(a), 0.35), 0.018, M["laiton_capot"], n=10, m=6,
                     what="boule")
    F.disc_wheel(g, (pNO["x"] - 0.1, Y(pNO["yn"] - 0.18), 0.16), "x", 0.14, 0.04, M["fer_noir"] if "fer_noir" in M
                 else M["steel_dk"], M["laiton_capot"], spokes=6)
    # réservoir (NE) : cylindre vert, cerclages, manomètre
    with at(g, pNE["x"] - 0.03, pNE["yn"] - 0.05):
        g.cyl((0, 0, 0.17), "z", 0.12, 0.34, M["vert_loco"], n=20, style="soft", what="reservoir")
        for f in (0.06, 0.3):
            g.tube_shell((0, 0, f), "z", 0.132, 0.11, 0.03, M["laiton_capot"], n=20, what="cerclage")
        g.sphere((0, 0, 0.34), 0.12, M["cuivre_capot"], n=16, m=8, scale=(1, 1, 0.5), what="dome")
        _cadran(g, (-0.09, -0.09, 0.22), (-0.6, -0.8, 0.2), 0.05, M, face=M["emit_soft"])
    # tuyaux de cuivre : dynamo et réservoir vers le pivot
    for (x0, yn0) in ((pNO["x"] + 0.1, pNO["yn"] - 0.1), (pNE["x"] - 0.1, pNE["yn"] - 0.1)):
        liaison(g, [(x0, Y(yn0), 0.24), (x0 * 0.6, Y(yn0 * 0.6), zp + 0.2), (x0 * 0.3, Y(yn0 * 0.25), zp + 0.08)],
                0.028)
    # lot F1-B (enrichissement) : conduite de vapeur de cuivre sombre à colliers de laiton qui ceint le premier gradin,
    # robinets et cadrans sur les flancs, sifflets, burettes et caisses à charbon sur les gradins
    O.ceinture(g, c, 0, 0.32, 0.014, M["cuivre_sombre"], colliers=M["laiton_capot"], pas=0.28)
    O.ceinture(g, c, 1, 0.45, 0.012, M["cuivre_sombre"], colliers=M["laiton_capot"], pas=0.28)
    O.sur_flanc(g, c, 0, [math.radians(a) for a in (212, 250, 290, 328)], _robinet, f=0.32, dr=0.02)
    O.sur_dessus(g, c, 1, [math.radians(a) for a in (205, 240, 300, 335)], _sifflet)
    O.sur_dessus(g, c, 2, [math.radians(a) for a in (230, 310)], _sifflet, t=0.6)
    _halo(g, [(0.0, Y(-0.85), 0.25), (-0.75, Y(0.1), 0.3), (0.75, Y(0.1), 0.3)], 6.0)


def tete(g, c):
    """Lot F1-B : bâche à eau et pompe à main à l'arrière de la platine, cadran."""
    M = g.M
    zb = O.zb(c)
    (xl, yl, wl), (xr, yr, wr) = O.pods(c)
    g.cyl((xl, yl, zb + wl * 0.8), "z", wl, wl * 1.6, M["vert_loco"], n=14, style="soft", what="bache")
    g.tube_shell((xl, yl, zb + wl * 1.2), "z", wl * 1.08, wl * 0.9, 0.02, M["laiton_capot"], n=14, what="cerclage")
    g.cyl((xr, yr, zb + wl * 0.6), "z", wr * 0.5, wl * 1.2, M["cuivre_capot"], n=10, what="pompe")
    g.box((xr, yr, zb + wl * 1.25), (wr * 2.2, 0.014, 0.014), M["laiton_capot"], "hard", what="levier")
    _cadran(g, (xr, yr - wr * 0.6, zb + wl * 0.8), (0, -1, 0.3), 0.03, M)


def piece(g, c):
    """Niveau 6 : deux accumulateurs de vapeur debout aux coins avant (cuivre, cerclages de laiton, grand manomètre
    ambré), sur un patin de tôles vertes relié au premier gradin."""
    M = g.M
    p = corps.place(c, "coin_SE")
    for sx in (-1, 1):
        x, yn = sx * (p["x"] + 0.02), p["yn"] + 0.02
        corps.patin(g, c, x - sx * 0.08, yn + 0.08, 0.42, 0.42, rz=sx * 0.785)
        with at(g, x, yn, z=0.035):
            g.cyl((0, 0, 0.2), "z", 0.13, 0.4, M["cuivre_capot"], n=24, style="soft", what="accumulateur")
            for f in (0.05, 0.2, 0.36):
                g.tube_shell((0, 0, f), "z", 0.142, 0.12, 0.03, M["laiton_capot"], n=24, what="cerclage")
            g.sphere((0, 0, 0.4), 0.13, M["cuivre_capot"], n=18, m=8, scale=(1, 1, 0.55), what="dome")
            _cadran(g, (0, -0.13, 0.27), (0, -1, 0.2), 0.07, M, face=M["emit_soft"])
            g.cyl((0, 0, 0.5), "z", 0.025, 0.07, M["laiton_capot"], n=8, what="soupape")
            liaison(g, [(-sx * 0.08, 0.1, 0.32), (-sx * 0.25, 0.3, 0.3), (-sx * 0.32, 0.42, 0.18)], 0.024)
        g.halo((x, Y(yn), 0.3), M["_emit_rgb"], 5.0)


def arriere(g, c):
    """Chaudière couchée EN TRAVERS du faisceau (axe x : jamais dressée), vert locomotive cerclé de laiton, dôme et
    soupape, foyer ambré à l'arrière."""
    M = g.M
    t = c.T["tete"]
    zb = t["z0"] + t["hpl"]
    yc = (t["yb0"] + t["yb1"]) / 2
    r = (t["zb1"] - zb) * 0.5
    L = 2 * t["bx"]
    g.box((0, yc, zb + r * 0.3), (L * 0.8, r * 1.4, r * 0.6), M["vert_loco"], "hard", what="selle")
    g.cyl((0, yc, zb + r), "x", r, L, M["vert_loco"], n=28, style="soft", what="chaudiere")
    for f in (-0.4, 0.0, 0.4):
        g.tube_shell((f * L, yc, zb + r), "x", r + 0.012, r - 0.01, 0.03, M["laiton_capot"], n=28, what="cerclage")
    g.sphere((L * 0.22, yc, zb + 1.9 * r), r * 0.45, M["cuivre_capot"], n=14, m=7, scale=(1, 1, 0.7), what="dome")
    g.cyl((-L * 0.25, yc, zb + 2.0 * r), "z", 0.02, 0.07, M["laiton_capot"], n=8, what="soupape")
    g.cyl((0, yc - r * 0.9, zb + r * 0.7), "y", r * 0.3, 0.02, M["emit"], n=16, style="flat", what="foyer")


def emetteur(g, c):
    """GLOBE DE CUIVRE (sphère de rayon 0,82 re) à méridiens de laiton, SERPENTIN de cuivre sombre enroulé autour de
    l'axe du faisceau, lentille ambrée dans une sertissure de laiton (face avant), manomètre sur le dessus."""
    M = g.M
    re, zh = c.re, c.zh
    rg = 0.82 * re
    g.sphere((0, 0, zh), rg, M["globe"], n=32, m=16, what="globe")
    for k in range(3):
        g.torus((0, 0, zh), (math.cos(k * math.pi / 3), 0, math.sin(k * math.pi / 3)), rg + 0.004, 0.012,
                M["laiton_capot"], n=40, m=6, what="meridien")
    # serpentin : hélice autour de l'axe y, de l'arrière à l'avant du globe
    pts = []
    nt, tours = 60, 3.0
    for i in range(nt + 1):
        s = i / nt
        y = (-0.55 + 1.0 * s) * rg
        rr = math.sqrt(max(0.0, rg * rg - y * y)) + 0.025
        a = TAU * tours * s
        pts.append(V((rr * math.cos(a), y, zh + rr * math.sin(a))))
    g.tube(pts, 0.018, M["serpentin"], n=8, what="serpentin")
    corps.lentille(g, c, 0.9 * rg, 0.45 * rg, cercle=M["laiton_capot"])
    _cadran(g, (0, -0.2 * rg, zh + rg * 0.98), (0, -0.3, 1), 0.05, M, face=M["emit_soft"])
