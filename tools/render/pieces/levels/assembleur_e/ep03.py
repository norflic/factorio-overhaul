"""Assembleur · Âge 3 · Vapeur (ère I, 3×3, niveaux 5 et 6). Lot F3-A, ronde F3-A2 ; fiche FICHES_ASSEMBLEUR.md, âge 3.
Dans Blender.

En 3 mots : « grand volant, chaudière couchée, bielle ». Plan en TOUR : la presse à vapeur EST la tour, fût vert
locomotive cerclé de laiton, galerie, quatre contreforts ; le GRAND VOLANT se dresse face au sud au sommet ; sa BIELLE
descend le long du fût jusqu'au coulisseau qui frappe la tôle de cuivre, au pied sud de la tour. La CHAUDIÈRE COUCHÉE
est allongée au pied ouest (foyer rougeoyant, dôme, soupape, manomètres) et envoie sa vapeur dans la tour par deux
conduites de cuivre.
Palette 60/30/10 (ages.PALETTE[3]) : cuivre rose / vert locomotive / laiton ; lumière ambre.
"""
import math

from mathutils import Vector

import ages
import corps
import formes as F
import parts2 as P2
import parts3 as P3
from corps import B, halo
from kit import SQ2, TAU

V = Vector

EPOQUE = 3
NOM = ages.NOMS[3]
TRIPLET = ("grand volant", "chaudière couchée", "bielle")
FOYER = ages.FOYER[3]
TRAVAIL = dict(couches=2, images=24, organe="volant qui tourne (24 positions de rayons), bielle et coulisseau qui "
                                           "montent et descendent ; jet de vapeur à la soupape, foyer (couche glow)")
HABILLAGE = dict(ages.CORPS[3], capots=("vert_loco", "cuivre_capot"), plan='tour', forme_embase='carre',
                 forme_dos='plat', forme_joues='caisson', forme_portique='aucun')
DENSITE = dict(p=0.65, lampes=0.16)     # ronde F3-A3 : nuit trop sombre


def matieres(metal, M):
    ages.matieres(3, metal, M)


def socle(g, c):
    """Cerclages de laiton du fût, chaudière couchée au pied ouest, conduites de vapeur, manomètres, lanternes."""
    M = g.M
    Rt, zr, Ht = c.Rt, c.zr, c.Ht
    for f in (0.12, 0.35, 0.8, 0.97):
        g.tube_shell(V((0, 0, zr + f * (Ht - zr))), "z", Rt + 0.025, Rt - 0.01, 0.04, M["laiton_capot"], n=32,
                     what="cerclage")
    # hublot et cadrans sur le fût (face sud)
    for k, z in enumerate((zr + 0.25 * (Ht - zr), zr + 0.68 * (Ht - zr))):
        P2.gauge(g, V((0.18 * (1 if k else -1), -Rt - 0.01, z)), (0, -1, 0), 0.07, M, face=M["emit_soft"])
    halo(g, 0, -Rt / SQ2 - 0.15, zr + 0.5 * (Ht - zr), 0.6)
    # ronde F3-A3 (nuit trop sombre) : HUBLOTS éclairés du fût (face sud) et fanal au sommet
    for ad, zf in ((235, 0.47), (305, 0.47), (250, 0.85), (290, 0.85)):
        a = math.radians(ad)
        p = V((Rt * math.cos(a), Rt * math.sin(a), zr + zf * (Ht - zr)))
        nrm = V((math.cos(a), math.sin(a), 0.0))
        g.cyl(p + nrm * 0.01, nrm, 0.055, 0.03, M["laiton_capot"], n=14, what="bague_hublot")
        g.cyl(p + nrm * 0.025, nrm, 0.04, 0.012, M["emit_soft"], n=14, what="hublot")
    halo(g, 0, -Rt / SQ2 - 0.3, zr + 0.65 * (Ht - zr), 0.9)
    # chaudière couchée au pied ouest, sur deux berceaux
    xc, yc, rb = -0.62, 0.32, 0.24
    zc = zr + rb + 0.05
    g.cyl(B(xc, yc, zc), "x", rb, 0.85, M["vert_loco"], n=28, what="chaudiere")
    for s in (-1, 1):
        g.sphere(B(xc + s * 0.425, yc, zc), rb, M["vert_loco"], n=20, m=10, scale=(0.35, 1, 1), what="fond")
    for f in (-0.3, 0.0, 0.3):
        g.tube_shell(B(xc + f, yc, zc), "x", rb + 0.02, rb - 0.01, 0.04, M["laiton_capot"], n=28, what="cerclage")
    for f in (-0.28, 0.28):
        g.box(B(xc + f, yc, zr + 0.06), (0.06, 0.3 * SQ2, 0.12), M["cuivre_sombre"], "hard", what="berceau")
    g.cyl(B(xc - 0.1, yc, zc + rb + 0.06), "z", 0.09, 0.12, M["laiton_capot"], n=18, what="dome_vapeur")
    g.sphere(B(xc - 0.1, yc, zc + rb + 0.12), 0.09, M["laiton_capot"], n=14, m=8, scale=(1, 1, 0.6), what="dome")
    g.cyl(B(xc + 0.22, yc, zc + rb + 0.07), "z", 0.035, 0.12, M["laiton_capot"], n=10, what="soupape")
    g.cyl(B(xc + 0.32, yc - 0.05, zc + rb + 0.08), "z", 0.02, 0.15, M["laiton_capot"], n=8, what="sifflet")
    # porte du foyer (bout ouest de la chaudière), grille rougeoyante
    g.box(B(xc - 0.43, yc - 0.17, zc - 0.05), (0.2, 0.04, 0.2), M["cuivre_sombre"], "hard", what="cadre_foyer")
    for k in range(4):
        g.box(B(xc - 0.5 + 0.045 * k, yc - 0.2, zc - 0.06), (0.025, 0.02, 0.14), M["emit"], "soft", what="grille")
    halo(g, xc - 0.43, yc - 0.3, zc - 0.05, 1.6)
    P2.gauge(g, B(xc + 0.1, yc - 0.18, zc + 0.05), (0, -1, 0.2), 0.06, M, face=M["emit_soft"])
    c.reserves.append((xc, yc, 0.55))
    # deux conduites de vapeur de la chaudière à la tour (cuivre, brides de laiton)
    for k, dz in enumerate((0.0, 0.25)):
        p0 = B(xc + 0.3, yc + 0.05, zc + rb * 0.6 + dz * 0.3)
        p1 = V((-Rt * 0.9, Rt * 0.3, zr + 0.35 * (Ht - zr) + dz))
        g.pipe([p0, p0.lerp(p1, 0.5) + V((0, 0, 0.15)), p1], 0.035, M["copper"], fl_mat=M["laiton_capot"],
               bolt_mat=M["laiton_rivet"])
    # caisse à charbon au pied est
    g.box(B(0.62, 0.35, zr + 0.08), (0.26, 0.2 * SQ2, 0.16), M["bois_verni"], "hard", what="caisse_charbon")
    for k in range(6):
        F.lump(g, B(0.53 + 0.035 * k, 0.35, zr + 0.16), 0.04, M["soot"])
    c.reserves.append((0.62, 0.35, 0.22))
    for x in (-0.7, 0.7):
        F.lantern(g, tuple(B(x, -0.75, zr)), M["emit"])
        halo(g, x, -0.75, zr + 0.1, 0.5)
        c.reserves.append((x, -0.75, 0.1))


def outil(g, c):
    """Grand volant au sommet de la tour, bielle le long du fût, coulisseau au pied sud entre deux guides."""
    M = g.M
    Rt, zr, Ht = c.Rt, c.zr, c.Ht
    Rv = 0.36
    zv = Ht + Rv + 0.04
    yv = -Rt * 0.3
    F.disc_wheel(g, V((0, yv, zv)), "y", Rv, 0.08, M["cuivre_sombre"], M["vert_loco"], spokes=8,
                 hub_mat=M["laiton_capot"])
    g.cyl(V((0, yv, zv)), "y", 0.05, 0.3, M["laiton_capot"], n=12, what="arbre")
    for s in (-1, 1):
        g.box(V((s * 0.13, 0.0, (Ht + zv) / 2)), (0.06, 0.1, zv - Ht + 0.04), M["cuivre_sombre"], "hard",
              what="palier")
    # maneton, BIELLE le long du fût, coulisseau
    a = 2.0
    pin = V((Rv * 0.65 * math.cos(a), yv - 0.07, zv + Rv * 0.65 * math.sin(a)))
    g.cyl(pin, "y", 0.03, 0.05, M["laiton_capot"], n=10, what="maneton")
    zc = c.zt + 0.45
    cross = B(0, c.yt, zc)
    g.tube([pin, V((pin.x * 0.6, -Rt - 0.12, (pin.z + zc) / 2)), cross + V((0, 0, 0.05))], 0.026, M["cuivre_sombre"],
           n=8, what="bielle")
    for sx in (-1, 1):
        g.cyl(B(sx * 0.16, c.yt + 0.02, (c.zt + zc + 0.15) / 2), "z", 0.022, zc + 0.15 - c.zt, M["laiton_capot"], n=8,
              what="guide")
    g.box(B(0, c.yt + 0.02, zc + 0.15), (0.4, 0.08 * SQ2, 0.05), M["cuivre_sombre"], "hard", what="traverse_haute")
    g.box(cross, (0.36, 0.09 * SQ2, 0.08), M["cuivre_sombre"], "hard", what="traverse")
    g.box(B(0, c.yt, zc - 0.13), (0.16, 0.11 * SQ2, 0.2), M["vert_loco"], "hard", what="coulisseau")
    g.box(B(0, c.yt, zc - 0.25), (0.2, 0.13 * SQ2, 0.04), M["steel"], "hard", what="poincon")
    # potence qui tient les guides au fût
    g.box(B(0, (c.yt - Rt / SQ2) / 2, zc + 0.15), (0.08, (abs(c.yt) - Rt / SQ2 + 0.05) * SQ2, 0.06),
          M["cuivre_sombre"], "hard", what="potence")


def ouvrage(g, c):
    M = g.M
    yt, zt = c.yt, c.zt
    g.cyl(B(0, yt, (c.zr + zt) / 2 + 0.02), "z", 0.22, zt - c.zr + 0.04, M["cuivre_sombre"], n=8, style="hard",
          what="enclume_presse")
    g.box(B(0, yt, zt + 0.07), (0.3, 0.2 * SQ2, 0.06), M["steel_dk"], "hard", what="matrice")
    g.cyl(B(0, yt, zt + 0.11), "z", 0.09, 0.02, M["cuivre_capot"], n=20, what="flan")
    for k in range(4):
        g.cyl(B(-0.32, yt + 0.05, zt + 0.015 + 0.02 * k), "z", 0.07, 0.016, M["cuivre_capot"], n=16, what="pile")


def entree(g, c, p):
    """Seau à charbon en tôle de cuivre (entrée)."""
    M = g.M
    g.cyl(B(p["x"], p["yn"], p["z"] + 0.1), "z", p["r"] * 0.85, 0.2, M["cuivre_sombre"], n=16, r2=p["r"],
          what="seau")
    for k in range(5):
        F.lump(g, B(p["x"] - 0.05 + 0.025 * k, p["yn"], p["z"] + 0.2), 0.035, M["soot"])


def sortie(g, c, p):
    """Plateau de laiton chargé de tôles de cuivre embouties (sortie)."""
    corps.bac(g, c, p, g.M["laiton_capot"], g.M["cuivre_capot"], forme="plaque")


def piece(g, c):
    """Niveau 6 (plus grande) : réservoir d'eau d'appoint debout (coin avant droit) ; seaux à charbon, pelle, burettes et
    lanterne (coin avant gauche)."""
    M = g.M
    po, pe = corps.place(c, "coin_SO"), corps.place(c, "coin_SE")
    z = po["z_sol"]
    # ronde F3-A3 (niveau pair peu visible) : SOUTE À CHARBON haute (coin gauche) avec fanal sur poteau ; réservoir
    # d'appoint plus haut (0,95), à cerclages de laiton (coin droit)
    x, yn = po["x"], po["yn"]
    g.box(B(x, yn, z + 0.22), (0.5, 0.42 * SQ2, 0.44), M["bois_verni"], "hard", what="soute")
    for f in (0.25, 0.75):
        g.box(B(x, yn - 0.215, z + 0.44 * f), (0.52, 0.012, 0.04), M["cuivre_sombre"], "hard", what="cerclage")
    for j in range(10):
        F.lump(g, B(x - 0.18 + 0.09 * (j % 5), yn - 0.1 + 0.15 * (j // 5), z + 0.44), 0.05, M["soot"])
    g.box(B(x - 0.2, yn + 0.12, z + 0.45), (0.04, 0.04 * SQ2, 0.9), M["cuivre_sombre"], "hard", what="poteau")
    F.lantern(g, tuple(B(x - 0.2, yn + 0.05, z + 0.86)), M["emit"])
    halo(g, x - 0.2, yn, z + 0.95, 0.7)
    P3.vtank(g, pe["x"], pe["yn"] * SQ2, 0.22, 0.95, M, paint=M["vert_loco"], z0=z, gauges=1, band=M["laiton_capot"])
    halo(g, pe["x"], pe["yn"] - 0.2, z + 0.5, 0.6)
    _ = TAU
