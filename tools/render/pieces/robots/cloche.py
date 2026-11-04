"""CLOCHE (robot 5, âge 8 Marais, soutien, soigne alentour, classe M). Idée : une cloche de verre : grand bulbe vert où flotte un liquide luminescent, posé dans une cage de vert-de-gris à côtes, sur 4 pattes
courbes de caoutchouc ; autour du bas, un collier de petits bulbes, et 3 conduits qui plongent dedans. Elle ne porte aucune arme : c'est une infirmerie qui marche. Bible : verre #8FBF4A, vert-de-gris #4F6B5A,
caoutchouc #2A2A28, liquide #A8FF3A, luminance 60."""
import math

import formes as F
import gamme as Ga
import geo as G
import marionette as Mr

CAP = math.radians(-150.0)
Z0 = 1.25
PAS, BETA, LEVE = 0.86, 0.62, 0.15
L1, L2 = 0.66, 0.76
HX, HY, HZ = 0.42, 0.42, -0.1
TABLE = Ga.table_quatre(HX, HY, HZ, HX + 0.22, HY + 0.24, decs=(0.0, 0.5, 0.25, 0.75), opposes=False, genou=0.5)
# genoux vers l'extérieur : les pattes s'arquent comme celles d'une cloche sur son support
TABLE = tuple((n, h, p, d, (h[0] * 1.2, h[1] * 1.2, 0.6)) for n, h, p, d, _po in TABLE)


def verre_vert(name):
    """Verre vert épais et opaque (même recette que le QG de l'âge 8, validé par le DC)."""
    import bpy
    import mat as MT
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    p = N["Principled BSDF"]
    lw = N.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.42
    c = MT._mix(N, L, lw.outputs["Facing"], (0.03, 0.09, 0.012), (0.3, 0.55, 0.09))
    tc = N.new("ShaderNodeTexCoord")
    nz = MT._range(N, L, MT._bruit(N, L, tc.outputs["Object"], 6.0, 4.0, 0.6, (3.0, 1.0, 2.0), (1.0, 1.0, 0.35)), 0.4, 0.7, 0.6, 1.0)
    L.new(MT._scale(N, L, c, nz), p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.09
    p.inputs["Metallic"].default_value = 0.0
    bev = N.new("ShaderNodeBevel")
    bev.inputs["Radius"].default_value = 0.02
    L.new(bev.outputs["Normal"], p.inputs["Normal"])
    m["fo_kind"] = "surface"
    return m


def matieres(S):
    import mat as MT
    Ga.patine(ta=0.15, ra=0.25, ec=0.5, nu_k=1.4, ec_col=(0.028, 0.018, 0.008))
    cr = (0.008, 0.0065, 0.004)
    sf = F.surf
    M = {}
    M["vdg"] = sf("rb8_vdg", (0.08, 0.2, 0.12), rough=0.48, met=0.35, coulures=0.75, rouille=(0.15, 0.08, 0.03), usure=0.7, nu=(0.48, 0.34, 0.2), crasse=0.8, crasse_col=cr, grain=0.12, graine=801)
    M["cuivre"] = sf("rb8_cuivre", (0.34, 0.14, 0.055), rough=0.38, met=0.7, coulures=0.85, rouille=(0.05, 0.17, 0.11), usure=0.6, nu=(0.66, 0.36, 0.18), crasse=0.7, crasse_col=cr, graine=802)
    M["caout"] = sf("rb8_caout", (0.03, 0.03, 0.028), rough=0.65, met=0.0, usure=0.35, nu=(0.12, 0.12, 0.11), crasse=0.5, crasse_col=cr, graine=803)
    M["peint"] = sf("rb8_peint", (0.5, 0.5, 0.42), rough=0.45, met=0.25, usure=0.6, nu=(0.72, 0.7, 0.6), crasse=0.5, crasse_col=cr, graine=804)
    M["peint"]["fo_teinte"] = 1
    M["riv"] = sf("rb8_riv", (0.13, 0.1, 0.05), rough=0.55, met=0.4, usure=0.3, crasse=0.5, graine=805)
    M["verre"] = verre_vert("rb8_verre")
    M["liquide"] = S.mat_emissive("rb8_liquide", (0.2, 1.0, 0.022), strength=1.5, base=(0.02, 0.06, 0.003), main_scale=0.55, crust=(7.0, 0.5, 8.0))
    M["hublot"] = MT.lumiere(S, "rb8_hublot", (0.5, 1.0, 0.07), 1.4, main=0.45)
    return M


def squelette(phase, cap=CAP, pas=PAS):
    sq = Mr.Squelette()
    sq.os("racine", None, Mr.rz(cap))
    a, m = Ga.corps_marche(phase, Z0, bob=0.035, tangage=0.03, roulis=0.03)
    sq.os("corps", "racine", m)
    # le battant : un lourd pendule sous la cloche, il balance à contretemps
    sq.os("battant", "corps", Mr.autour((0.0, 0.0, -0.12), Mr.chaine(Mr.ry(0.32 * math.sin(a) if phase is not None else 0.0), Mr.rx(0.2 * math.cos(a) if phase is not None else 0.0))))
    Ga.pattes(sq, m, phase, pas, BETA, LEVE, L1, L2, TABLE, incl=0.5)
    return sq


def modele(lots, M, r, torse=False):
    c = lots("corps")
    # grand bulbe : cloche de verre (profil de cloche, évasée en bas), liquide au fond, bulles
    prof = [(-0.08, 0.72), (-0.02, 0.74), (0.1, 0.66), (0.28, 0.58), (0.55, 0.54), (0.8, 0.5), (1.0, 0.38), (1.12, 0.22), (1.18, 0.0)]
    c.put(M["verre"], G.tour(prof, 24, "z"))
    c.put(M["liquide"], G.tour([(0.02, 0.0), (0.02, 0.64), (0.08, 0.66), (0.36, 0.585)], 24, "z", cap1=False))
    for i in range(14):
        a, rr_ = r.f(0.0, G.TAU), r.f(0.3, 0.56)
        z_ = r.f(0.3, 0.86)
        c.put(M["hublot"], G.sphere((rr_ * math.cos(a), rr_ * math.sin(a), z_), r.f(0.02, 0.045), 7, 3))
    # cage de côtes vert-de-gris, plus resserrée en haut, une couronne au sommet
    n = 8
    for k in range(n):
        a = G.TAU * k / n + 0.2
        ca, sa = math.cos(a), math.sin(a)
        ctl = [(rr_ * 1.04 * ca, rr_ * 1.04 * sa, z_) for z_, rr_ in prof[1:-1]]
        ctl.append((0.03 * ca, 0.03 * sa, 1.2))
        pts = G.catmull(ctl, 3)
        c.put(M["vdg"], G.tube(pts, 0.026, 6))
        if k % 2 == 0:
            for i in (2, 7, 12):
                c.put(M["riv"], G.rivets_le_long([(pts[i], (ca, sa, 0.3))], 0.02, 0.012))
    for z_, rr_, w in ((0.0, 0.76, 0.06), (0.55, 0.57, 0.035), (0.8, 0.52, 0.03)):
        c.put(M["vdg"], F.bague((0.0, 0.0, z_), rr_ - 0.03, rr_ + 0.03, w, "z", 24, 0.008))
    c.put(M["peint"], F.bague((0.0, 0.0, 0.3), 0.585, 0.635, 0.06, "z", 24, 0.01))
    c.put(M["cuivre"], G.tour([(1.16, 0.2), (1.22, 0.18), (1.26, 0.1), (1.36, 0.07), (1.42, 0.12), (1.46, 0.0)], 12, "z", cap0=False))
    c.put(M["cuivre"], F.tore((0.0, 0.0, 1.5), 0.08, 0.022, "x", 12, 5))      # anse
    # socle à la bride, sous la cloche
    c.put(M["vdg"], G.tour([(-0.34, 0.2), (-0.26, 0.5), (-0.14, 0.78), (-0.06, 0.8), (-0.02, 0.0)], 16, "z", cap0=True))
    # collier de petits bulbes
    for k in range(9):
        a = G.TAU * k / 9 + 0.35
        rr_ = 0.86
        z_ = -0.1
        ra = 0.13 if k % 3 == 0 else 0.095
        p = (rr_ * math.cos(a), rr_ * math.sin(a), z_)
        c.put(M["verre"], G.sphere(p, ra, 12, 6))
        c.put(M["liquide"], G.sphere(G.add(p, (0.0, 0.0, -ra * 0.32)), ra * 0.72, 10, 4, zmin=-1.0))
        c.put(M["cuivre"], F.bague(G.add(p, (0.0, 0.0, -ra * 0.9)), ra * 0.3, ra * 0.62, 0.03, "z", 8, 0.006))
        c.put(M["caout"], G.tube(G.coudee([G.add(p, (0.0, 0.0, -ra * 0.95)), (0.72 * math.cos(a), 0.72 * math.sin(a), -0.26), (0.34 * math.cos(a), 0.34 * math.sin(a), -0.3)], 0.05, 3), 0.016, 6))
    # 3 conduits qui montent le long de la cloche, un bulbe au milieu
    for k in range(3):
        a = G.TAU * k / 3 + 1.0
        ca, sa = math.cos(a), math.sin(a)
        ct = [(0.72 * ca, 0.72 * sa, -0.02), (0.74 * ca, 0.74 * sa, 0.3), (0.66 * ca, 0.66 * sa, 0.72), (0.34 * ca, 0.34 * sa, 1.1), (0.12 * ca, 0.12 * sa, 1.2)]
        c.put(M["cuivre"], G.tube(G.catmull(ct, 4), 0.026, 7))
        p = (0.73 * ca, 0.73 * sa, 0.42)
        c.put(M["verre"], G.sphere(p, 0.085, 10, 5))
        c.put(M["hublot"], G.sphere(p, 0.05, 8, 4))
    # battant
    b = lots("battant")
    b.put(M["cuivre"], F.disque((0.0, 0.0, -0.4), 0.018, 0.56, "z", 6))
    b.put(M["cuivre"], G.tour([(-0.84, 0.0), (-0.8, 0.09), (-0.68, 0.13), (-0.6, 0.06), (-0.56, 0.0)], 10, "z"))
    b.put(M["peint"], F.bague((0.0, 0.0, -0.72), 0.11, 0.135, 0.03, "z", 10, 0.005))
    # pattes : caoutchouc annelé, pied en ventouse
    for nom, _h, _p, _d, _po in TABLE:
        cu = lots("cuisse_" + nom)
        cu.put(M["vdg"], F.disque((0.0, 0.0, 0.0), 0.1, 0.16, "y", 10))
        cu.put(M["caout"], F.disque((L1 / 2.0, 0.0, 0.0), 0.07, L1, "x", 10))
        for i in range(6):
            cu.put(M["caout"], F.tore((0.08 + 0.085 * i, 0.0, 0.0), 0.072, 0.014, "x", 10, 4))
        ti = lots("tibia_" + nom)
        ti.put(M["cuivre"], G.sphere((0.0, 0.0, 0.0), 0.085, 10, 5))
        ti.put(M["caout"], F.pose(G.tour([(0.0, 0.058), (L2 - 0.1, 0.044), (L2, 0.05)], 10, "x"), (0.0, 0.0, 0.0), (1.0, 0.0, 0.0)))
        for i in range(6):
            ti.put(M["caout"], F.tore((0.1 + 0.09 * i, 0.0, 0.0), 0.056 - 0.002 * i, 0.012, "x", 10, 4))
        pi = lots("pied_" + nom)
        pi.put(M["vdg"], G.tour([(0.0, 0.17), (0.02, 0.19), (0.05, 0.16), (0.1, 0.06), (0.14, 0.05)], 12, "z", cap1=True))
        pi.put(M["cuivre"], F.bague((0.0, 0.0, 0.06), 0.1, 0.15, 0.015, "z", 12, 0.004))
