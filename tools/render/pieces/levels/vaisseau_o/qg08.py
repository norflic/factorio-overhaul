"""QG ÂGE 8 : MARAIS (refonte du 30/10, brief 2026-10-30_QG). Emprise 12×6. NEZ À DROITE (+X), tuyères à gauche.

Bible (DESIGN_EPOQUES §5, époque 8) : « Serre-laboratoire : bâtiment bas ; 3 dômes de verre de tailles décroissantes ;
conduits » ; verre #8FBF4A, vert-de-gris #4F6B5A, caoutchouc #2A2A28, liquide #A8FF3A, luminance 60.
Brief : la peau devient bâtiment par le ventre (30 % de peau) ; ventre en halle sur pilotis et ponton ; côtes
au-dessus du toit ; crâne et tuyères en coque ; lumière des 3 dômes et de 2 hublots seulement.

Lecture de gauche à droite : deux grosses tuyères cantées (cloches noires ouvertes vers la caméra) et la dérive ;
la halle-laboratoire sur pilotis sous la cage des côtes balayées « (((( » ; devant elle, sur le ponton, les trois
dômes de verre (liquide luminescent au fond, bulles) ; à droite le crâne à verrière et chevrons, le nez planté dans
une butte de vase. Derrière : aile nord dressée, château d'eau, gazomètre de méthane à charpente.
"""
import math

import bpy

import carcasse as C
import geo as G
import mat as MT

POSE = dict(T=(0.0, 0.55, 1.45), lacet=-0.105, tangage=0.04, roulis=0.17)
COTES = (-1.95, -0.85, 0.55, 1.55)
BALAI = 0.48
Z_PONT = 0.45
LABO = dict(u0=0.72, u1=2.2, v0=-0.98, v1=1.0)
GRAND = (-0.68, -0.08, 1.2)                     # grand dôme dans la cage (coordonnées de la halle : u, v, rayon)
DOMES = ((2.72, -2.38, 0.88), (-3.42, -2.5, 0.6))   # moyen (sud-est) et petit (sud-ouest), coordonnées du monde
BASSE = dict(x0=-2.35, x1=1.5, y0=-2.85, y1=-1.42, z0=0.3, ze=0.95, zf=1.3)


def verre_vert(name):
    """Verre vert épais (#8FBF4A en reflet rasant), brillant, opaque à la caméra (alpha 1 : il compte dans la masse)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    p = N["Principled BSDF"]
    lw = N.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.42
    c = MT._mix(N, L, lw.outputs["Facing"], (0.03, 0.075, 0.012), (0.27, 0.5, 0.075))
    tc = N.new("ShaderNodeTexCoord")
    nz = MT._range(N, L, MT._bruit(N, L, tc.outputs["Object"], 6.0, 4.0, 0.6, (3.0, 1.0, 2.0), (1.0, 1.0, 0.35)), 0.4, 0.7, 0.55, 1.0)
    c = MT._scale(N, L, c, nz)
    L.new(c, p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.09
    p.inputs["Metallic"].default_value = 0.0
    bev = N.new("ShaderNodeBevel")
    bev.inputs["Radius"].default_value = 0.02
    L.new(bev.outputs["Normal"], p.inputs["Normal"])
    m["fo_kind"] = "surface"
    return m


def matieres(S):
    M = {}
    MT.PATINE.update(ta=0.16, ra=0.28, ec=0.7, nu_k=1.45, ec_col=(0.028, 0.018, 0.008))
    sf = MT.surface
    cr = (0.008, 0.0065, 0.004)
    jaunes = [(0.36, 0.205, 0.013), (0.24, 0.135, 0.009), (0.5, 0.32, 0.025), (0.33, 0.15, 0.01)]
    for i, c in enumerate(jaunes):
        M["jaune%d" % i] = sf("q8_jaune%d" % i, c, rough=0.48, met=0.2, coulures=0.9, rouille=(0.16, 0.06, 0.02), usure=0.85,
                              nu=(0.62, 0.6, 0.56), crasse=0.95, crasse_col=cr, pied=(0.3, 1.1, 0.5), grain=0.11, graine=81 + i)
    M["vdg"] = sf("q8_vdg", (0.05, 0.155, 0.085), rough=0.55, met=0.3, coulures=0.8, rouille=(0.14, 0.07, 0.03), usure=0.7,
                  nu=(0.3, 0.2, 0.12), crasse=0.8, crasse_col=cr, pied=(0.3, 1.1, 0.55), grain=0.12, graine=84)
    M["vdg2"] = sf("q8_vdg2", (0.05, 0.11, 0.075), rough=0.55, met=0.3, coulures=0.8, rouille=(0.14, 0.07, 0.03), usure=0.7,
                   nu=(0.3, 0.2, 0.12), crasse=0.8, crasse_col=cr, grain=0.12, graine=85)
    M["conduit"] = sf("q8_conduit", (0.078, 0.147, 0.102), rough=0.42, met=0.55, coulures=0.7, rouille=(0.16, 0.08, 0.03),
                      usure=0.75, nu=(0.42, 0.3, 0.18), crasse=0.75, crasse_col=cr, grain=0.1, graine=86)
    M["rapiece"] = sf("q8_rapiece", (0.3, 0.29, 0.27), rough=0.45, met=0.5, coulures=0.8, usure=0.6, crasse=0.75,
                      crasse_col=cr, grain=0.12, graine=87)
    M["rapiece2"] = sf("q8_rapiece2", (0.2, 0.075, 0.03), rough=0.7, met=0.3, coulures=0.6, usure=0.5, nu=(0.3, 0.16, 0.08),
                       crasse=0.75, crasse_col=cr, grain=0.14, graine=88)
    M["noyau"] = sf("q8_noyau", (0.007, 0.006, 0.005), rough=0.6, met=0.6, usure=0.2, crasse=0.8, crasse_col=(0.004, 0.003, 0.002), graine=89)
    M["brule"] = sf("q8_brule", (0.01, 0.0085, 0.008), rough=0.75, met=0.4, usure=0.0, crasse=0.8, crasse_col=(0.003, 0.003, 0.003), graine=90)
    M["acier"] = sf("q8_acier", (0.085, 0.052, 0.03), rough=0.5, met=0.75, usure=0.85, nu=(0.72, 0.68, 0.6), crasse=0.7,
                    crasse_col=cr, coulures=0.5, graine=91)
    M["acier_clair"] = sf("q8_acier_clair", (0.2, 0.19, 0.175), rough=0.4, met=0.85, usure=0.4, crasse=0.6, crasse_col=cr, graine=92)
    M["riv"] = sf("q8_riv", (0.085, 0.065, 0.035), rough=0.6, met=0.3, usure=0.3, crasse=0.5, graine=93)
    M["chevron"] = sf("q8_chevron", jaunes[0], rough=0.5, met=0.2, bandes=(0.19, (0.012, 0.011, 0.01), 0.5), usure=0.8,
                      nu=(0.4, 0.38, 0.35), crasse=0.7, crasse_col=cr, coulures=0.6, graine=94)
    M["cuivre"] = sf("q8_cuivre", (0.27, 0.11, 0.045), rough=0.4, met=0.85, coulures=0.85, rouille=(0.05, 0.17, 0.11),
                     usure=0.6, nu=(0.6, 0.33, 0.17), crasse=0.7, crasse_col=cr, graine=95)
    M["caoutchouc"] = sf("q8_caoutchouc", (0.023, 0.023, 0.021), rough=0.72, met=0.0, usure=0.3, nu=(0.07, 0.07, 0.065),
                         crasse=0.5, crasse_col=cr, graine=96)
    M["bois"] = sf("q8_bois", (0.2, 0.16, 0.11), rough=0.85, met=0.0, tole=(0.9, 0.115), joint=0.18, var=0.28, coulures=0.4,
                   rouille=(0.03, 0.045, 0.02), usure=0.5, nu=(0.22, 0.15, 0.08), crasse=0.75, crasse_col=cr, relief=0.5, grain=0.14, graine=97)
    M["poutre"] = sf("q8_poutre", (0.06, 0.04, 0.024), rough=0.8, met=0.0, usure=0.6, nu=(0.15, 0.1, 0.06), crasse=0.7,
                     crasse_col=cr, grain=0.14, graine=98)
    M["pierre"] = sf("q8_pierre", (0.07, 0.072, 0.04), rough=0.9, met=0.0, tole=(0.38, 0.19), joint=0.35, var=0.2, coulures=0.4,
                     rouille=(0.03, 0.06, 0.03), usure=0.6, nu=(0.17, 0.16, 0.14), crasse=0.8, crasse_col=cr, pied=(0.0, 0.4, 0.6),
                     relief=0.6, grain=0.14, graine=99)
    M["toit"] = sf("q8_toit", (0.055, 0.17, 0.095), rough=0.55, met=0.35, coulures=0.7, rouille=(0.04, 0.06, 0.04), usure=0.6,
                   nu=(0.3, 0.17, 0.09), crasse=0.8, crasse_col=cr, grain=0.13, graine=100)
    M["tole_ond"] = sf("q8_tole_ond", (0.045, 0.135, 0.075), rough=0.55, met=0.4, tole=(0.12, 3.0), joint=0.3, var=0.08,
                       coulures=0.9, rouille=(0.17, 0.08, 0.03), usure=0.6, nu=(0.3, 0.2, 0.12), crasse=0.8, crasse_col=cr,
                       pied=(0.5, 1.2, 0.5), relief=0.6, grain=0.12, graine=101)
    M["boue"] = sf("q8_boue", (0.075, 0.048, 0.024), rough=0.85, met=0.0, usure=0.0, crasse=0.6, crasse_col=(0.01, 0.008, 0.004),
                   grain=0.2, graine=102)
    M["vase"] = sf("q8_vase", (0.018, 0.026, 0.008), rough=0.4, met=0.0, usure=0.0, crasse=0.5, crasse_col=(0.006, 0.008, 0.003),
                   grain=0.2, graine=103)
    M["rouge"] = sf("q8_rouge", (0.32, 0.02, 0.012), rough=0.55, met=0.0, usure=0.3, nu=(0.4, 0.2, 0.15), crasse=0.4, graine=104)
    M["noir"] = sf("q8_noir", (0.012, 0.012, 0.012), rough=0.7, met=0.0, usure=0.2, crasse=0.3, graine=105)
    M["verre"] = verre_vert("q8_verre")
    M["verre_sombre"] = MT.verre("q8_verre_sombre", col=(0.01, 0.025, 0.02), reflet=(0.12, 0.2, 0.15))
    M["liquide"] = S.mat_emissive("q8_liquide", (0.2, 1.0, 0.022), strength=1.7, base=(0.02, 0.06, 0.003), main_scale=0.6,
                                  crust=(7.0, 0.5, 8.0))
    M["bulle"] = M["liquide"]
    M["hublot"] = MT.lumiere(S, "q8_hublot", (0.5, 1.0, 0.07), 4.5, main=0.45)
    M["veilleuse"] = MT.verre("q8_veilleuse", col=(0.03, 0.05, 0.015), reflet=(0.25, 0.32, 0.14))
    M["flamme"] = MT.lumiere(S, "q8_flamme", (1.0, 0.62, 0.14), 7.0, main=0.5)
    M["voyant"] = MT.lumiere(S, "q8_voyant", (1.0, 0.09, 0.03), 7.0, main=0.4)
    return M


# ================================================================================================ build
def menus(lot, M, P, r, a_top):
    """Menus détails (3 à 10 px), clairs et sombres : équerres et regards sur la coque, sur la façade et sur le ponton."""
    mats = [M["acier"], M["noyau"], M["acier_clair"], M["riv"]]
    lot.xf = P.xf
    for k in range(90):
        x, a = r.f(-2.1, 5.0), a_top + r.f(-1.0, 1.0)
        p, n = C.point(x, a, 0.05), C.normale_s(C.surf_coque, x, a)
        lot.put(mats[k % 4], C.pose_plane(G.boite((0, 0, 0.02), (r.f(0.05, 0.14), r.f(0.04, 0.1), 0.05), rz=r.f(-0.7, 0.7)), p, n))
    lot.xf = P.niv
    B = BASSE
    for k in range(60):
        p = (r.f(B["x0"] + 0.1, B["x1"] - 0.1), B["y0"] - 0.01, r.f(0.5, B["ze"] - 0.03))
        lot.put(mats[k % 4], C.pose_plane(G.boite((0, 0, 0.012), (r.f(0.05, 0.12), r.f(0.04, 0.1), 0.03)), p, (0.0, -1.0, 0.0)))
    for k in range(50):
        p = (r.f(-3.4, 2.6), r.f(-3.0, -2.88), Z_PONT + 0.015)
        lot.put(mats[k % 4], G.boite(p, (r.f(0.05, 0.14), r.f(0.04, 0.11), 0.05), r.f(-0.5, 0.5)))
    lot.xf = None


def build(S, lot):
    M = matieres(S)
    P = C.Pose(**POSE)
    r = G.Rnd(8088)
    niv = P.niv

    def mats_coque(rr, xm, am):
        if 4.55 < xm < 4.8:
            return M["chevron"]
        x = rr.f()
        if x < 0.42:
            return M["jaune0"]
        if x < 0.6:
            return M["jaune1"]
        if x < 0.7:
            return M["jaune2"]
        if x < 0.8:
            return M["jaune3"]
        if x < 0.9:
            return M["vdg"]
        if x < 0.95:
            return M["rapiece"]
        return M["rapiece2"]

    # ======================================================================================== 1. carcasse (pose)
    lot.xf = P.xf
    sc = C.surf_coque
    TAU = G.TAU
    verriere = (3.05, 4.3, math.pi / 2 - 0.6, math.pi / 2 + 0.62)

    # -- crâne (coque entière) --
    C.noyau(lot, M["noyau"], sc, 2.2, 5.5, 0.0, TAU)
    C.blindage(lot, sc, 2.22, 5.45, -0.3, TAU - 0.3, mats_coque, r, Mriv=M["riv"], larg=(0.45, 0.95), arcs=(0.4, 0.85),
               saut=lambda x, a: verriere[0] < x < verriere[1] and verriere[2] < a < verriere[3])
    # verrière : bombée, cadre lourd irrégulier
    rings = []
    nx, na = 14, 16
    for i in range(nx + 1):
        x = verriere[0] + (verriere[1] - verriere[0]) * i / nx
        t = i / float(nx)
        bump = math.sin(math.pi * min(1.0, t * 1.15)) ** 0.7
        ring = []
        for j in range(na + 1):
            a = verriere[2] + (verriere[3] - verriere[2]) * j / na
            s = math.sin(math.pi * j / na)
            ring.append(C.point(x, a, 0.02 + 0.16 * bump * s ** 0.6))
        rings.append(ring)
    lot.put(M["verre_sombre"], G.loft(rings, closed=False))
    for i in (0, 4, 9, nx):
        lot.put(M["acier"], G.tube([G.add(p, (0, 0, 0.01)) for p in rings[i]], 0.035, 6))
    for j in (0, 6, 11, na):
        lot.put(M["acier"], G.tube([G.add(rr_[j], (0, 0, 0.01)) for rr_ in rings], 0.035, 6))
    # sourcils à chevrons (écailles en V devant et derrière la verrière)
    for (x0, x1, ga) in ((2.72, 2.9, 0.08),):
        C.bande(lot, sc, M["chevron"], x0, x1, math.pi / 2 - 0.85, math.pi / 2 + 0.85, 0.0, ga)
    # capteur du nez et antenne
    tip = C.point(5.5, math.pi / 2, 0.0)
    lot.put(M["acier"], G.tour([(5.38, 0.13), (5.5, 0.12), (5.72, 0.04), (5.8, 0.0)], 12, "x", (0.0, 0.0, tip[2] - 0.05)))
    lot.put(M["voyant"], G.sphere((5.62, 0.0, tip[2] + 0.02), 0.025, 6, 3))
    # canards
    for s in (-1, 1):
        y0 = s * 0.95
        poly = [(3.55, y0), (3.05, y0), (3.2, y0 + s * 0.75), (3.5, y0 + s * 0.8)]
        poly = poly if s > 0 else list(reversed(poly))
        v, f, u = G.prisme(poly, -0.03, 0.03)
        v = [(p[0], p[1], p[2] - 0.35 + abs(p[1] - y0) * 0.15) for p in v]
        lot.put(M["jaune1"] if s > 0 else M["vdg"], (v, f, u))
        lot.put(M["chevron"], G.tube([(3.22, y0 + s * 0.72, -0.24), (3.5, y0 + s * 0.78, -0.23)], 0.035, 6))
    # hublots du crâne (tous différents) : 2 forts, 2 veilleuses
    for (x, a, forme, lum, rr_) in ((2.62, math.pi / 2 + 1.0, "rond", "hublot", 0.085), (3.35, math.pi / 2 + 1.12, "ovale", "veilleuse", 0.07),
                                    (4.1, math.pi / 2 + 1.05, "octo", "veilleuse", 0.06), (2.55, math.pi / 2 - 1.1, "carre", "veilleuse", 0.07)):
        p = sc(x, a, 0.05)
        n = C.normale_s(sc, x, a)
        C.hublot(lot, forme, M["acier"], M[lum], p, n, rr_)
    # trappe d'accès sur le flanc sud du crâne, entrouverte (intérieur noir)
    p = sc(3.7, math.pi / 2 + 1.35, 0.06)
    n = C.normale_s(sc, 3.7, math.pi / 2 + 1.35)
    lot.put(M["acier"], C.pose_plane(G.boite((0, 0, 0.0), (0.62, 0.5, 0.05)), p, n))
    lot.put(M["noir"], C.pose_plane(G.boite((0, 0, 0.03), (0.5, 0.38, 0.03)), p, n))
    lot.put(M["jaune1"], C.pose_plane(G.boite((0.3, 0.0, 0.2), (0.06, 0.4, 0.4), 0.0, 0.9), p, n))

    # -- queue (dessus et flancs) --
    C.noyau(lot, M["noyau"], sc, -3.5, -2.18, -0.45, math.pi + 0.45)
    C.blindage(lot, sc, -2.2, -3.48, -0.42, math.pi + 0.42, mats_coque, r, Mriv=M["riv"], larg=(0.45, 0.9), arcs=(0.4, 0.85))
    lot.put(M["noyau"], G.loft([[sc(-3.5, -0.45 + (math.pi + 0.9) * j / 24.0, 0.0) for j in range(25)],
                                [(-3.52, 0.0, -0.2)] * 25], closed=False))
    # -- dos du ventre ouvert : bande dorsale à trous, lambeaux qui pendent --
    a_top = math.pi / 2

    def saut_dos(x, a):
        return -1.5 < x < 1.85 and not (a < a_top - 0.6 and (x < -1.0 or x > 0.75))
    # peau dorsale : restes aux deux bouts du ventre, cage ouverte au milieu (dôme et toit du labo visibles)
    C.noyau(lot, M["noyau"], sc, -2.2, -1.5, a_top - 0.95, a_top + 0.98, g=-0.01)
    C.noyau(lot, M["noyau"], sc, 1.85, 2.24, a_top - 0.95, a_top + 1.05, g=-0.01)
    C.blindage(lot, sc, -2.2, 2.24, a_top - 0.95, a_top + 0.98, mats_coque, r, Mriv=M["riv"], saut=saut_dos, gondole=0.3, larg=(0.42, 0.9), arcs=(0.4, 0.8))
    C.blindage(lot, sc, -2.2, -1.5, a_top + 0.98, a_top + 1.25, mats_coque, r, Mriv=M["riv"], gondole=0.5)
    # lisses (longerons) qui relient les côtes au-dessus de la cage
    for (a, rl) in ((a_top - 0.62, 0.045), (a_top + 0.6, 0.05), (a_top + 1.12, 0.04)):
        lot.put(M["acier"], G.tube([sc(x, a, 0.09) for x in [-1.55 + 0.17 * i for i in range(21)]], rl, 6))
    # lambeaux arrachés qui pendent des bords de peau (tôles tordues)
    for (x, a, l, w) in ((-1.42, a_top + 0.4, 0.55, 0.3), (-1.4, a_top + 0.95, 0.5, 0.26), (1.92, a_top + 0.75, 0.45, 0.28),
                         (-0.9, a_top - 0.66, 0.4, 0.3)):
        e = sc(x, a, 0.04)
        v, f, u = G.boite((w / 2 if x > 0 else -w / 2, 0.0, -l / 2), (w, 0.03, l))
        v = [G.add(e, G.rot_z(G.rot_x((q[0], q[1], q[2] + 0.05), -0.5 - 0.25 * r.f()), 0.3 * (1 if x > 0 else -1))) for q in v]
        lot.put(M["jaune1"] if r.f() < 0.6 else M["rapiece"], (v, f, u))

    # -- épine dorsale et vertèbres --
    ep = [(x, 0.0, C.z_dessus(x) + 0.13) for x in [-3.45 + 0.25 * i for i in range(31)] if x < 4.3]
    lot.put(M["acier"], G.tube(ep, 0.13, 4))
    lot.put(M["jaune2"], G.tube([G.add(p, (0, 0, 0.1)) for p in ep[2:-3]], 0.05, 6))
    for x in [-3.2, -2.55] + list(COTES) + [2.2, 2.75]:
        z0 = C.z_dessus(x) + 0.2
        h = 0.28 if x in COTES else 0.18
        lot.put(M["acier"], C.prisme_plan([(x + 0.14, z0), (x - 0.2, z0), (x - 0.34, z0 + h)], 0.05))

    # -- côtes balayées (((( et leurs jambes --
    pieds = []
    for i, xt in enumerate(COTES):
        e0, e1 = C.cote(lot, M["acier"], M["riv"], xt, -0.2, math.pi + 0.2, BALAI, g=0.1, haut=0.32)
        pieds.append((P.xf(e0), P.xf(e1)))
    for xt in (-2.2, 2.24):                                           # cloisons-couples aux deux bouts du ventre
        C.cote(lot, M["acier"], M["riv"], xt, -0.35, math.pi + 0.35, 0.12, g=0.06, prof=0.2, aile=0.26)

    # -- dérive dressée --
    z0 = C.z_dessus(-2.4)
    z1 = C.z_dessus(-3.45)
    fin = [(-2.3, z0 - 0.05), (-3.25, z0 + 1.8), (-3.95, z0 + 1.86), (-3.5, z1 - 0.05)]
    lot.put(M["jaune0"], C.prisme_plan(fin, 0.09))
    for (poly, m, y) in (([(-2.55, z0 + 0.35), (-3.1, z0 + 1.2), (-3.55, z0 + 1.2), (-3.4, z0 + 0.35)], "vdg", 0.05),
                         ([(-3.13, z0 + 1.25), (-3.28, z0 + 1.5), (-3.75, z0 + 1.5), (-3.62, z0 + 1.25)], "rapiece", 0.05),
                         ([(-2.6, z0 + 0.35), (-3.0, z0 + 0.95), (-3.3, z0 + 0.95), (-3.2, z0 + 0.35)], "jaune1", -0.05)):
        lot.put(M[m], C.prisme_plan(poly, 0.025, y0=y))
    lot.put(M["chevron"], C.prisme_plan([(-3.27, z0 + 1.55), (-3.33, z0 + 1.72), (-3.93, z0 + 1.76), (-3.86, z0 + 1.55)], 0.11))
    lot.put(M["acier"], G.tube([(-2.3, 0.0, z0 - 0.05), (-3.25, 0.0, z0 + 1.8)], 0.05, 8))
    lot.put(M["voyant"], G.sphere((-3.6, 0.0, z0 + 1.92), 0.04, 8, 4))
    lot.put(M["acier"], G.tube([(-3.5, 0.0, z0 + 1.86), (-3.6, 0.0, z0 + 2.45)], 0.014, 5))      # fouet d'antenne

    # -- aile nord dressée (dièdre), aile sud coupée --
    def aile(s, pts, zr, di, mats_):
        poly = pts if s > 0 else list(reversed(pts))
        v, f, u = G.prisme(poly, -0.05, 0.05)
        yr = pts[0][1]
        sh = lambda q: (q[0], q[1], q[2] + zr + abs(q[1] - yr) * di)
        lot.put(mats_[0], ([sh(q) for q in v], f, u))
        return sh
    yr = 1.88
    sh = aile(1, [(-2.65, yr), (-4.55, yr), (-5.3, 3.55), (-4.5, 3.6)], -0.42, 0.24, [M["jaune0"]])
    # panneaux de l'aile (tons dépareillés) : bord d'attaque BA(t), bord de fuite BF(t), t de l'emplanture au saumon
    BA = lambda t: (-2.65 + (-4.5 + 2.65) * t - 0.07, yr + (3.6 - yr) * t)
    BF = lambda t: (-4.55 + (-5.3 + 4.55) * t + 0.1, yr + (3.55 - yr) * t)
    for (a0, a1, m, f0, f1) in ((0.04, 0.4, "jaune1", 0.0, 0.55), (0.04, 0.33, "rapiece", 0.6, 1.0), (0.42, 0.66, "vdg", 0.0, 1.0),
                                (0.68, 0.96, "jaune2", 0.0, 0.7)):
        def pt(t, f):
            a, b = BA(t), BF(t)
            return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)
        quad = [pt(a0, f0), pt(a1, f0), pt(a1, f1), pt(a0, f1)]
        v, f, u = G.prisme(quad, 0.05, 0.075)
        lot.put(M[m], ([sh(q) for q in v], f, u))
    lot.put(M["chevron"], G.tube([sh((-4.52, 3.55, 0.06)), sh((-5.28, 3.5, 0.06))], 0.05, 6))
    lot.put(M["acier"], G.tube([sh((-2.65, yr, 0.06)), sh((-4.5, 3.6, 0.06))], 0.04, 6))
    lot.put(M["voyant"], G.sphere(sh((-4.9, 3.58, 0.1)), 0.035, 6, 3))
    sh2 = aile(-1, [(-2.7, -yr), (-4.0, -yr), (-4.25, -2.55), (-3.15, -2.62)], -0.42, 0.24, [M["vdg"]])
    for (x, y) in ((-3.2, -2.6), (-3.55, -2.58), (-3.95, -2.54)):              # bord coupé : longerons qui dépassent
        lot.put(M["acier"], G.tube([sh2((x, -2.45, 0.0)), sh2((x - 0.08, y - 0.22, 0.0))], 0.025, 5))

    # -- les deux tuyères (nacelles cantées, cloches relevées vers la caméra) --
    for s, rz, ry in ((-1, 0.33, 0.14), (1, -0.1, 0.0)):
        att = (-2.05, s * 1.25, -0.42)

        def nac(p, att=att, rz=rz, ry=ry):
            q = G.rot_y(p, ry)
            q = G.rot_z(q, rz)
            return G.add(q, att)
        lot.xf = P.compose(nac)
        R, xav, xar = 0.74, 0.0, -2.55
        sn = C.surf_nac(R, xav, xar)
        C.noyau(lot, M["noyau"], sn, 0.05, xar - 0.02, 0.0, TAU)
        C.blindage(lot, sn, -0.04, xar, 0.0, TAU, mats_coque, r, Mriv=M["riv"], larg=(0.38, 0.7), arcs=(0.38, 0.7))
        for xb in (-0.62, -1.48, -2.25):
            rr_ = C.r_nacelle(xb, R, xav, xar)
            lot.put(M["acier"], G.tour([(xb - 0.07, rr_ + 0.01), (xb - 0.06, rr_ + 0.1), (xb + 0.06, rr_ + 0.1), (xb + 0.07, rr_ + 0.01)], 32, "x"))
        re = C.r_nacelle(0.0, R, xav, xar)
        lot.put(M["acier"], G.tour([(-0.02, re * 1.03), (0.05, re * 1.06), (0.08, re * 0.85), (0.03, re * 0.62)], 32, "x"))
        lot.put(M["brule"], G.tour([(0.02, re * 0.64), (-0.18, 0.0)], 24, "x"))
        for k in range(7):                                             # aubes de l'entrée d'air
            a = TAU * k / 7
            lot.put(M["acier"], G.boite((0.0, re * 0.32 * math.cos(a), re * 0.32 * math.sin(a)), (0.03, 0.05, re * 0.62), 0.0, a))
        C.cloche(lot, M["acier"], M["acier"], M["brule"], M["cuivre"], xar, R)
        # flexible de récupération du méthane branché sur la cloche
        lot.put(M["cuivre"], G.tour([(-1.0, R + 0.02), (-1.0, R + 0.12), (-0.8, R + 0.12), (-0.8, R + 0.02)], 16, "x"))
        lot.xf = P.xf

    # ======================================================================================== 2. jambes des côtes
    lot.xf = None
    for (pn, ps) in pieds:
        for p in (pn, ps):
            h = p[2]
            lot.put(M["acier"], G.boite((p[0], p[1], h / 2), (0.15, 0.17, h)))
            lot.put(M["acier"], G.boite((p[0], p[1], h - 0.15), (0.24, 0.26, 0.12)))
            lot.put(M["pierre"], G.boite((p[0], p[1], 0.17), (0.44, 0.44, 0.34), 0.1))
            lot.put(M["acier"], G.boite((p[0], p[1], 0.36), (0.26, 0.28, 0.05)))
            pts = [((p[0] + dx, p[1] + dy, 0.385), (0, 0, 1)) for dx in (-0.09, 0.09) for dy in (-0.1, 0.1)]
            lot.put(M["riv"], G.rivets_le_long(pts, 0.022, 0.016))


    # ======================================================================================== 3. sous la cage (niveau, axe du vaisseau)
    lot.xf = niv
    zp = Z_PONT
    lot.put(M["bois"], G.boite((-0.15, 0.0, zp - 0.03), (4.9, 2.5, 0.06)))          # plancher sur pilotis sous la cage
    for u in (-2.5, -1.4, -0.3, 0.8, 1.9):
        for v in (-1.15, 0.0, 1.15):
            lot.put(M["poutre"], G.tour([(0.0, 0.07), (zp - 0.06, 0.065)], 8, "z", (u, v, 0.0), cap1=True))
    # -- le labo avant, sous l'arrière du crâne : un volume, toit à deux pans vu de trois-quarts --
    u0, u1, v0, v1 = LABO["u0"], LABO["u1"], LABO["v0"], LABO["v1"]
    ze, zf = 1.6, 2.04
    _volume(lot, M, u0, u1, v0, v1, zp, ze, zf, G.Rnd(81))
    lot.put(M["tole_ond"], G.boite((1.45, 0.0, zf + 0.12), (0.55, 0.42, 0.24)))         # lanterneau à volets
    lot.put(M["toit"], G.boite((1.45, 0.0, zf + 0.27), (0.65, 0.52, 0.05)))
    for k in range(3):
        lot.put(M["acier"], G.boite((1.27 + 0.18 * k, -0.215, zf + 0.12), (0.11, 0.02, 0.15), 0.0, 0.5))
    C.evente(lot, M["acier"], M["noir"], (0.98, -0.5, 1.72), 0.24, 0.36, 4, 0.0, 0.12)
    lot.put(M["acier"], G.tour([(1.7, 0.06), (2.25, 0.06), (2.27, 0.13), (2.35, 0.12), (2.39, 0.0)], 10, "z", (1.95, 0.45, 0.0)))
    lot.put(M["noir"], G.boite((1.95, -0.62, 1.86), (0.34, 0.28, 0.03), 0.0, -0.45))       # trappe ouverte du pan sud
    lot.put(M["acier"], G.boite((1.95, -0.44, 2.1), (0.36, 0.03, 0.3), 0.0, -0.2))
    lot.put(M["noir"], G.boite((1.15, v0 - 0.05, zp + 0.45), (0.42, 0.04, 0.8)))             # porte, auvent, lampe
    lot.put(M["poutre"], G.boite((1.15, v0 - 0.07, zp + 0.88), (0.56, 0.06, 0.08)))
    lot.put(M["toit"], G.boite((1.15, v0 - 0.25, zp + 1.0), (0.66, 0.42, 0.04), 0.0, -0.28))
    lot.put(M["veilleuse"], G.sphere((1.15, v0 - 0.1, zp + 0.93), 0.035, 8, 4))
    lot.put(M["poutre"], G.boite((1.82, v0 - 0.05, 1.2), (0.3, 0.05, 0.26)))
    lot.put(M["noir"], G.boite((1.82, v0 - 0.07, 1.2), (0.22, 0.02, 0.18)))
    lot.put(M["acier"], G.boite((0.86, v0 - 0.09, 1.15), (0.2, 0.12, 0.28)))
    lot.put(M["voyant"], G.boite((0.86, v0 - 0.155, 1.22), (0.03, 0.01, 0.03)))
    for x in (2.04, 2.26):                                                             # échelle vers le toit
        lot.put(M["acier"], G.tube([(x, v0 - 0.12, zp), (x, v0 - 0.12, 1.9)], 0.014, 5))
    for k in range(7):
        lot.put(M["acier"], G.tube([(2.04, v0 - 0.12, zp + 0.18 + 0.19 * k), (2.26, v0 - 0.12, zp + 0.18 + 0.19 * k)], 0.01, 4))
    # -- château d'eau au nord (dépasse au-dessus du dos) --
    tu, tv = -0.4, 2.1
    lot.put(M["pierre"], G.boite((tu, tv, 0.55), (1.2, 1.0, 1.1)))
    lot.put(M["tole_ond"], G.boite((tu, tv, 1.1 + 0.7), (1.1, 0.9, 1.4)))
    lot.put(M["toit"], G.boite((tu, tv, 2.54), (1.24, 1.04, 0.08)))
    lot.put(M["vdg"], G.tour([(2.58, 0.46), (3.15, 0.46), (3.27, 0.38), (3.4, 0.12), (3.45, 0.0)], 20, "z", (tu, tv, 0.0)))
    for z in (2.75, 3.0):
        lot.put(M["cuivre"], G.tour([(z - 0.03, 0.475), (z + 0.03, 0.475)], 20, "z", (tu, tv, 0.0)))
    pts = [(tu + 0.6 * math.cos(TAU * k / 12), tv + 0.6 * math.sin(TAU * k / 12), 2.58) for k in range(13)]
    for k in range(12):
        lot.put(M["acier"], G.tube([pts[k], G.add(pts[k], (0, 0, 0.32))], 0.012, 4))
    lot.put(M["acier"], G.tube([G.add(p, (0, 0, 0.32)) for p in pts], 0.014, 4))

    # ======================================================================================== 4. les trois dômes, la halle basse, les passerelles
    menus(lot, M, P, G.Rnd(8089), a_top)
    lot.xf = None
    gu, gv, gR = GRAND
    gc = niv((gu, gv, 0.0))
    zt_g = _bulbe(lot, M, r, gc[0], gc[1], zp, gR, 0.42, 16)
    zt_m = _bulbe(lot, M, r, DOMES[0][0], DOMES[0][1], 0.34, DOMES[0][2], 0.18, 13)
    zt_p = _bulbe(lot, M, r, DOMES[1][0], DOMES[1][1], 0.34, DOMES[1][2], 0.12, 10)
    # col de cygne du grand dôme vers l'épine (le dôme est branché sur le vaisseau)
    sp = P.xf((gu + 0.25, 0.0, C.z_dessus(gu + 0.25) + 0.05))
    C.tuyau(lot, M["conduit"], M["cuivre"], [(gc[0] + 0.1, gc[1], zt_g + 0.27), (gc[0] + 0.1, gc[1], zt_g + 0.45),
                                             (sp[0], gc[1] + 0.3, zt_g + 0.45), (sp[0], sp[1], sp[2] - 0.05)], 0.075, rb=0.18, pas_bride=0.5)
    # plateformes rondes des petits dômes (sur pieux)
    for (dx, dy, R) in DOMES:
        Rp = R + 0.32
        lot.put(M["bois"], G.tour([(0.28, Rp), (0.34, Rp), (0.345, 0.0)], 28, "z", (dx, dy, 0.0)))
        lot.put(M["poutre"], G.tour([(0.2, Rp + 0.03), (0.3, Rp + 0.03)], 28, "z", (dx, dy, 0.0)))
        for k in range(7):
            a = TAU * k / 7 + 0.3
            lot.put(M["poutre"], G.tour([(0.0, 0.065), (0.28, 0.06)], 8, "z", (dx + (Rp - 0.1) * math.cos(a), dy + (Rp - 0.1) * math.sin(a), 0.0), cap1=True))
    # -- halle basse à sheds (serre-laboratoire) devant la cage --
    B = BASSE
    x0, x1, y0, y1, z0, ze, zf = B["x0"], B["x1"], B["y0"], B["y1"], B["z0"], B["ze"], B["zf"]
    lot.put(M["pierre"], G.boite(((x0 + x1) / 2, (y0 + y1) / 2, z0 / 2 + 0.02), (x1 - x0 + 0.1, y1 - y0 + 0.1, z0 + 0.04)))
    lot.put(M["tole_ond"], G.boite(((x0 + x1) / 2, y0, (z0 + ze) / 2), (x1 - x0, 0.08, ze - z0)))
    lot.put(M["tole_ond"], G.boite(((x0 + x1) / 2, y1, (z0 + zf) / 2), (x1 - x0, 0.08, zf - z0)))
    for x in (x0, x1):
        lot.put(M["tole_ond"], G.boite((x, (y0 + y1) / 2, (z0 + ze) / 2), (0.08, y1 - y0, ze - z0)))
    for x in (x0, x0 + 1.35, x0 + 2.55, x1):
        lot.put(M["poutre"], G.boite((x, y0 - 0.02, (z0 + ze) / 2 + 0.02), (0.11, 0.11, ze - z0 + 0.04)))
    lot.put(M["poutre"], G.boite(((x0 + x1) / 2, y0 - 0.05, ze - 0.03), (x1 - x0 + 0.12, 0.09, 0.08)))
    baies = (y0 - 0.08, y0 + 0.48, y0 + 0.95, y1)
    rr_ = G.Rnd(83)
    for i in range(3):
        ys, yn = baies[i], baies[i + 1]
        verre = i == 1
        x = x0 - 0.06
        while x < x1 + 0.05:
            w = min(rr_.f(0.22, 0.4), x1 + 0.06 - x)
            if verre and rr_.f() < 0.8:
                m = M["verre"]
            else:
                m = M["toit"] if rr_.f() < 0.8 else (M["cuivre"] if rr_.f() < 0.5 else M["rapiece"])
            q = [(x + 0.012, ys, ze), (x + w - 0.012, ys, ze), (x + w - 0.012, yn, zf), (x + 0.012, yn, zf)]
            top = [G.add(p, (0, 0, 0.035)) for p in q]
            lot.put(m, G.merge((top, [(0, 1, 2, 3)], [(p[0], p[1]) for p in top]), G.loft([[q[0], q[1]], [top[0], top[1]]], closed=False)))
            lot.put(M["conduit"] if verre else M["toit"], G.tube([G.add(q[0], (0, 0, 0.045)), G.add(q[3], (0, 0, 0.045))], 0.016 if verre else 0.013, 4))
            x += w
        lot.put(M["verre_sombre"], G.boite(((x0 + x1) / 2, yn, (ze + zf) / 2 + 0.02), (x1 - x0, 0.03, zf - ze)))
        lot.put(M["cuivre"], G.tube([(x0 - 0.08, yn, zf + 0.05), (x1 + 0.08, yn, zf + 0.05)], 0.035, 6))
        lot.put(M["acier"], G.tube([(x0 - 0.08, ys + 0.02, ze + 0.02), (x1 + 0.08, ys + 0.02, ze + 0.02)], 0.03, 6))
    C.evente(lot, M["acier"], M["noir"], (-1.75, y0 + 0.24, 1.05), 0.22, 0.34, 4, 0.0, 0.12)
    C.evente(lot, M["vdg2"], M["noir"], (0.95, y0 + 1.2, 1.18), 0.22, 0.26, 3, 0.0, 0.14)
    lot.put(M["acier"], G.tour([(1.0, 0.055), (1.62, 0.055), (1.64, 0.12), (1.72, 0.11), (1.76, 0.0)], 10, "z", (-0.6, y0 + 0.75, 0.0)))
    # façade sud : porte double, hublot faible, fenêtre à barreaux, caisson, évent, tuyau le long du mur
    C.hublot(lot, "barreaux", M["acier"], M["noir"], (-1.45, y0 - 0.05, 0.66), (0.0, -1.0, 0.0), 0.09)
    C.hublot(lot, "double", M["acier"], M["hublot"], (0.85, y0 - 0.05, 0.66), (0.0, -1.0, 0.0), 0.07)
    lot.put(M["acier"], G.boite((-2.0, y0 - 0.06, 0.64), (0.34, 0.05, 0.26)))
    for k in range(4):
        lot.put(M["noir"], G.boite((-2.0, y0 - 0.09, 0.55 + 0.06 * k), (0.3, 0.02, 0.025)))
    lot.put(M["acier"], G.boite((0.35, y0 - 0.1, 0.62), (0.22, 0.12, 0.3)))
    lot.put(M["voyant"], G.boite((0.35, y0 - 0.165, 0.7), (0.03, 0.01, 0.03)))
    C.tuyau(lot, M["cuivre"], M["acier"], [(x0 + 0.1, y0 - 0.13, 0.86), (-0.75, y0 - 0.13, 0.86), (-0.75, y0 - 0.13, 0.45),
                                           (-0.62, y0 - 0.13, 0.4)], 0.035, rb=0.08, pas_bride=0.45)
    # pavillon d'entrée plus haut (pignon vers le ponton) : casse la longueur de la halle
    _pavillon(lot, M, -0.78, 0.18, y0 - 0.06, y0 + 0.8, z0, 1.28, 1.62)
    # -- l'aile sud détachée, remontée en auvent au-dessus de la porte --
    au = [(-0.95, y0 - 0.02), (0.35, y0 - 0.02), (0.25, y0 - 0.75), (-0.85, y0 - 0.72)]
    hz = lambda y: 1.1 + (y - y0) * 0.3
    v_, f_, u_ = G.prisme(au, -0.035, 0.035)
    lot.put(M["vdg"], ([(p[0], p[1], p[2] + hz(p[1])) for p in v_], f_, u_))
    v_, f_, u_ = G.prisme([(-0.85, y0 - 0.06), (-0.25, y0 - 0.06), (-0.3, y0 - 0.66), (-0.8, y0 - 0.64)], 0.035, 0.06)
    lot.put(M["jaune1"], ([(p[0], p[1], p[2] + hz(p[1])) for p in v_], f_, u_))
    lot.put(M["chevron"], G.tube([(-0.85, y0 - 0.74, hz(y0 - 0.74) + 0.03), (0.25, y0 - 0.77, hz(y0 - 0.77) + 0.03)], 0.04, 6))
    for (x, y) in ((-0.82, y0 - 0.68), (0.2, y0 - 0.7)):
        lot.put(M["poutre"], G.boite((x, y, (0.3 + hz(y)) / 2), (0.07, 0.07, hz(y) - 0.3)))
    # -- passerelles de planches (pas de dalle) --
    zw = 0.3
    wy0, wy1 = -3.68, y0 - 0.04
    # trois tronçons décalés (le bord sud n'est jamais droit sur plus de 3 tuiles), planches manquantes, pieux
    for (xa, xb, ya, za) in ((-4.5, -2.45, -3.58, zw), (-2.45, 0.75, -3.86, zw + 0.03), (0.75, 3.6, -3.62, zw - 0.02)):
        x = xa
        rr2 = G.Rnd(int(xa * 10) + 50)
        while x < xb - 0.02:
            w = min(rr2.f(0.14, 0.22), xb - x)
            if rr2.f() > 0.06:
                lot.put(M["bois"] if rr2.f() < 0.85 else M["poutre"], G.boite((x + w / 2, (ya + wy1) / 2, za - 0.025 + rr2.f(-0.008, 0.008)),
                                                                            (w - 0.018, wy1 - ya + rr2.f(-0.06, 0.06), 0.05)))
            x += w
        for yb in (ya + 0.06, wy1 - 0.08):
            lot.put(M["poutre"], G.boite(((xa + xb) / 2, yb, za - 0.08), (xb - xa, 0.08, 0.08)))
        x = xa + 0.05
        while x < xb:
            lot.put(M["poutre"], G.tour([(0.0, 0.06), (za - 0.1, 0.055)], 8, "z", (x, ya + 0.05, 0.0), cap1=True))
            x += 0.75 + 0.25 * r.f()
        if xa < -0.5 < xb:
            _garde(lot, M, (xa, ya + 0.05, za), (-0.62, ya + 0.05, za))
            _garde(lot, M, (0.02, ya + 0.05, za), (xb, ya + 0.05, za))
            for k in range(3):
                lot.put(M["bois"], G.boite((-0.3, ya - 0.15 - 0.19 * k, za - 0.1 * (k + 1) + 0.02), (0.6, 0.19, 0.05)))
        else:
            _garde(lot, M, (xa, ya + 0.05, za), (xb, ya + 0.05, za))
        lot.put(M["poutre"], G.tour([(0.0, 0.07), (za + 0.55, 0.06)], 8, "z", (xb - 0.02, ya + 0.02, 0.0), cap1=True))   # pieu d'amarrage
    # palier ouest (sud-ouest, sous la tuyère sud) et ponton du bossoir
    lot.put(M["bois"], G.boite((-4.95, -2.65, zw - 0.025), (1.2, 1.5, 0.05)))
    for (x, y) in ((-5.5, -3.35), (-4.4, -3.35), (-5.5, -1.95), (-4.4, -1.95)):
        lot.put(M["poutre"], G.tour([(0.0, 0.065), (zw - 0.05, 0.06)], 8, "z", (x, y, 0.0), cap1=True))
    _garde(lot, M, (-5.52, -3.38, zw), (-5.52, -1.95, zw))

    # ======================================================================================== 5. gazomètre nord-est (méthane)
    gx, gy, gr = 4.15, 2.92, 0.95
    lot.put(M["pierre"], G.tour([(0.0, gr + 0.22), (0.32, gr + 0.2), (0.36, gr + 0.1)], 36, "z", (gx, gy, 0.0), cap1=True))
    lot.put(M["vdg"], G.tour([(0.34, gr), (1.72, gr), (1.82, gr - 0.05), (2.0, gr * 0.6), (2.06, 0.0)], 40, "z", (gx, gy, 0.0)))
    for z in (0.72, 1.18, 1.6):
        lot.put(M["cuivre"], G.tour([(z - 0.03, gr + 0.025), (z + 0.03, gr + 0.025)], 40, "z", (gx, gy, 0.0)))
    cols = [(gx + (gr + 0.22) * math.cos(TAU * k / 8 + 0.2), gy + (gr + 0.22) * math.sin(TAU * k / 8 + 0.2)) for k in range(8)]
    for (x, y) in cols:
        lot.put(M["acier"], G.boite((x, y, 1.32), (0.09, 0.09, 2.64)))
    for (z, rt) in ((2.58, 0.045), (1.4, 0.03)):
        lot.put(M["acier"], G.tube([(x, y, z) for (x, y) in cols] + [(cols[0][0], cols[0][1], z)], rt, 4))
    for k in range(8):                                                  # croix de Saint-André
        a, b = cols[k], cols[(k + 1) % 8]
        for (za, zb_) in ((0.4, 1.4), (1.4, 2.58)):
            lot.put(M["acier"], G.tube([(a[0], a[1], za), (b[0], b[1], zb_)], 0.014, 4))
            lot.put(M["acier"], G.tube([(b[0], b[1], za), (a[0], a[1], zb_)], 0.014, 4))
    lot.put(M["acier"], G.tube([(gx, gy, 2.06), (gx, gy, 2.4)], 0.03, 6))
    lot.put(M["voyant"], G.sphere((gx, gy, 2.42), 0.03, 6, 3))
    # -- essai 4 : couvre-joints verticaux, rivets, échelle à crinoline et passerelle du gazomètre --
    for k in range(14):
        a = TAU * k / 14 + 0.1
        lot.put(M["acier"], G.tube([(gx + (gr + 0.012) * math.cos(a), gy + (gr + 0.012) * math.sin(a), 0.36),
                                    (gx + (gr + 0.012) * math.cos(a), gy + (gr + 0.012) * math.sin(a), 1.72)], 0.012, 4))
    for z in (0.5, 0.95, 1.4):
        pts = [((gx + (gr + 0.01) * math.cos(TAU * k / 40), gy + (gr + 0.01) * math.sin(TAU * k / 40), z),
                (math.cos(TAU * k / 40), math.sin(TAU * k / 40), 0.0)) for k in range(40)]
        lot.put(M["riv"], G.rivets_le_long(pts, 0.016, 0.01))
    for k in range(10):                                                 # côtes du toit bombé
        a = TAU * k / 10 + 0.3
        arc = [(gx + (gr * math.cos(t) + 0.01) * math.cos(a), gy + (gr * math.cos(t) + 0.01) * math.sin(a), 1.72 + 0.34 * math.sin(t))
               for t in [0.05 + 1.45 * i / 8.0 for i in range(9)]]
        lot.put(M["acier"], G.tube(arc, 0.011, 4))
    la = -math.pi / 2 - 0.35                                            # échelle côté caméra
    lx, ly = gx + (gr + 0.12) * math.cos(la), gy + (gr + 0.12) * math.sin(la)
    tx, ty = -math.sin(la), math.cos(la)
    for sgn in (-1, 1):
        lot.put(M["acier"], G.tube([(lx + sgn * 0.09 * tx, ly + sgn * 0.09 * ty, 0.35), (lx + sgn * 0.09 * tx, ly + sgn * 0.09 * ty, 2.0)], 0.011, 4))
    for k in range(11):
        z = 0.45 + 0.145 * k
        lot.put(M["acier"], G.tube([(lx - 0.09 * tx, ly - 0.09 * ty, z), (lx + 0.09 * tx, ly + 0.09 * ty, z)], 0.008, 3))
    for z in (1.0, 1.35, 1.7):
        ring = [(lx + 0.15 * math.cos(t) * math.cos(la) + 0.15 * math.sin(t) * tx * 0, ly + 0.15 * math.cos(t) * math.sin(la), z) for t in [-1.4 + 2.8 * i / 8.0 for i in range(9)]]
        ring = [(lx + 0.16 * (math.cos(t) * math.cos(la) - math.sin(t) * math.sin(la)) * 1.0, ly + 0.16 * (math.cos(t) * math.sin(la) + math.sin(t) * math.cos(la)), z)
                for t in [-1.4 + 2.8 * i / 8.0 for i in range(9)]]
        lot.put(M["acier"], G.tube(ring, 0.008, 3))
    # -- château d'eau : échelle, trop-plein, rivets --
    for sgn in (-1, 1):
        lot.put(M["acier"], G.tube([(tu + 0.3 + sgn * 0.08, tv - 0.5, 0.2), (tu + 0.3 + sgn * 0.08, tv - 0.5, 2.55)], 0.011, 4))
    for k in range(15):
        lot.put(M["acier"], G.tube([(tu + 0.22, tv - 0.5, 0.3 + 0.16 * k), (tu + 0.38, tv - 0.5, 0.3 + 0.16 * k)], 0.008, 3))
    C.tuyau(lot, M["conduit"], M["cuivre"], [(tu - 0.35, tv - 0.47, 2.3), (tu - 0.35, tv - 0.6, 2.2), (tu - 0.35, tv - 0.6, 0.15)], 0.04, rb=0.08, pas_bride=0.6)
    for z in (1.2, 1.75, 2.3):
        pts = [((tu + x, tv - 0.452, z), (0.0, -1.0, 0.0)) for x in [-0.5 + 0.1 * k for k in range(11)]]
        lot.put(M["riv"], G.rivets_le_long(pts, 0.016, 0.01))
    hn = niv((u1 + 0.15, 1.1, 0.0))
    C.tuyau(lot, M["conduit"], M["cuivre"], [(gx - 0.75, gy - 0.72, 0.62), (gx - 0.75, hn[1] + 0.1, 0.62), (hn[0] + 0.25, hn[1] + 0.1, 0.62),
                                             (hn[0] + 0.25, hn[1] + 0.1, 1.15)], 0.09, rb=0.22)

    # ======================================================================================== 6. tuyauterie, flexibles, câbles
    pv = niv
    C.tuyau(lot, M["conduit"], M["cuivre"], [(-3.1, -1.55, 1.05), (-2.75, -1.55, 1.05), (-2.75, -2.1, 0.75), (x0 - 0.05, -2.1, 0.75)], 0.11, rb=0.2)
    C.tuyau(lot, M["cuivre"], M["acier"], [pv((-3.3, 0.15, 2.15)), pv((-2.65, 0.15, 2.15)), pv((-2.35, -0.45, 2.0)),
                                           pv((-2.0, -0.45, 1.6)), pv((-2.0, -0.45, 0.6))], 0.07)
    C.tuyau(lot, M["cuivre"], M["acier"], [(-4.4, -3.38, zw + 0.1), (-2.5, -3.38, zw + 0.1), (-2.5, -3.6, zw + 0.13), (0.8, -3.6, zw + 0.13), (0.8, -3.4, zw + 0.1), (3.45, -3.4, zw + 0.1), (3.45, -2.3, zw + 0.1)], 0.04,
            rb=0.12, pas_bride=0.55)
    # cols de cygne des petits dômes vers la halle basse et le labo
    C.tuyau(lot, M["conduit"], M["cuivre"], [(DOMES[0][0] + 0.08, DOMES[0][1], zt_m + 0.27), (DOMES[0][0] + 0.08, DOMES[0][1], zt_m + 0.48),
                                             (DOMES[0][0] - 0.5, DOMES[0][1] + 0.4, zt_m + 0.48), (x1 - 0.2, DOMES[0][1] + 0.4, zt_m + 0.48),
                                             (x1 - 0.2, DOMES[0][1] + 0.4, zf + 0.1)], 0.055, rb=0.16, pas_bride=0.5)
    C.tuyau(lot, M["conduit"], M["cuivre"], [(DOMES[1][0] + 0.08, DOMES[1][1], zt_p + 0.27), (DOMES[1][0] + 0.08, DOMES[1][1], zt_p + 0.42),
                                             (x0 + 0.25, DOMES[1][1], zt_p + 0.42), (x0 + 0.25, DOMES[1][1], ze + 0.05)], 0.045, rb=0.14, pas_bride=0.5)
    for (u, v, z) in ((0.82, -1.06, 1.6), (2.12, -1.06, 1.6)):           # descentes du labo
        C.tuyau(lot, M["acier"], M["acier"], [pv((u, v, z)), pv((u, v - 0.12, z - 0.1)), pv((u, v - 0.12, zp + 0.05))], 0.035, rb=0.1)
    # flexibles annelés (caoutchouc)
    for (a, b, c) in (((gc[0] - 0.5, gc[1] - gR - 0.05, zp + 0.3), (gc[0] - 0.9, gc[1] - gR - 0.45, zp + 0.05), (-1.4, y1 + 0.02, 0.9)),
                      ((gc[0] + 0.7, gc[1] - gR + 0.2, zp + 0.25), (gc[0] + 0.85, gc[1] - gR - 0.35, 0.3), (0.45, y1 + 0.02, 1.0)),
                      ((-4.55, -1.4, 1.2), (-4.65, -2.05, zw + 0.1), (-4.25, -2.55, zw + 0.25)),
                      ((-3.6, -1.15, 1.15), (-3.9, -1.65, 0.35), (DOMES[1][0] - 0.3, DOMES[1][1] + 0.5, 0.55)),
                      ((DOMES[0][0] - 0.75, DOMES[0][1] + 0.35, 0.5), (DOMES[0][0] - 0.95, DOMES[0][1] + 0.1, 0.3), (x1 + 0.03, -2.0, 0.6)),
                      (pv((2.45, -0.9, 1.2)), (3.1, -1.25, 0.75), (DOMES[0][0] + 0.2, DOMES[0][1] + 0.85, 0.55))):
        C.flexible(lot, M["caoutchouc"], [a, b, c], 0.048)
    for (x, y, rr_) in ((-4.95, -3.0, 0.2), (2.0, -3.35, 0.16)):          # rouleaux de flexible
        for k in range(3):
            rk = rr_ - 0.032 * k
            lot.put(M["caoutchouc"], G.tube([(x + rk * math.cos(TAU * j / 18), y + rk * math.sin(TAU * j / 18), zw + 0.035 + 0.055 * k)
                                             for j in range(19)], 0.028, 6))
    # faisceaux de câbles rouges et noirs, pendants
    fx = [(P.xf((COTES[i] - 0.05, 0.25, C.z_dessus(COTES[i]) + 0.4)), P.xf((COTES[i + 1] - 0.05, 0.25, C.z_dessus(COTES[i + 1]) + 0.4)), 0.32)
          for i in range(3)]
    fx += [(pieds[0][1], pieds[1][1], 0.4), (pieds[2][1], pieds[3][1], 0.34), (pieds[1][1], pieds[2][1], 0.45)]
    fx += [(P.xf((-3.4, 0.0, C.z_dessus(-3.4) + 0.3)), pv((-2.55, -0.2, 2.35)), 0.25)]
    fx += [((-4.45, -3.53, zw + 1.3), (x0, y0, ze), 0.28), ((3.5, -3.57, zw + 1.3), (x1, y0, ze), 0.28)]
    fx += [((gx - 1.0, gy - 0.55, 2.5), P.xf((2.9, 0.4, C.z_dessus(2.9) + 0.6)), 0.35)]
    for (a, b, fl) in fx:
        C.faisceau(lot, M["rouge"], M["noir"], a, b, fl, 3, 0.011, 0.028, r)
    # compléments : tuyaux à brides (3 diamètres), flexibles, grilles de coque
    C.tuyau(lot, M["conduit"], M["cuivre"], [pv((0.85, 0.55, 2.0)), pv((1.6, 0.55, 2.0)), pv((1.6, 0.85, 1.82)), pv((2.35, 0.85, 1.82))],
            0.05, rb=0.12, pas_bride=0.45)                                    # conduite sur le toit du labo
    C.tuyau(lot, M["conduit"], M["cuivre"], [(-1.2, y1 + 0.05, zf + 0.05), (-1.2, y1 + 0.05, zf + 0.35), (-1.2, gc[1] - gR - 0.35, zf + 0.35),
                                             (-1.2, gc[1] - gR - 0.35, zp + 0.2)], 0.08, rb=0.16, pas_bride=0.5)    # pont de tuyaux
    C.tuyau(lot, M["acier"], M["cuivre"], [(gx - 0.2, gy - gr - 0.02, 0.9), (gx - 0.2, gy - gr - 0.35, 0.9), (gx - 0.2, gy - gr - 0.35, 0.2),
                                           (gx - 0.75, gy - gr - 0.35, 0.2)], 0.06, rb=0.12)                     # purge du gazomètre
    lot.put(M["rouge"], G.tour([(0.85, 0.09), (0.88, 0.09)], 12, "z", (gx - 0.2, gy - gr - 0.35 + 0.0, 0.0)))
    C.flexible(lot, M["caoutchouc"], [P.xf((-0.3, 1.3, 0.25)), pv((-0.25, 1.35, 1.0)), pv((0.1, 1.2, 0.5))], 0.045)
    C.flexible(lot, M["caoutchouc"], [(gx - 0.95, gy - 0.35, 0.5), (gx - 1.35, gy - 0.6, 0.12), (hn[0] + 0.4, hn[1] + 0.35, 0.3)], 0.05)
    for (x, a, w, l) in ((3.0, math.pi / 2 - 0.7, 0.32, 0.4), (3.9, math.pi / 2 + 0.95, 0.26, 0.36), (-2.9, math.pi / 2 + 0.2, 0.3, 0.5)):
        p = P.xf(C.point(x, a, 0.07))
        n = G.norm(G.sub(P.xf(C.point(x, a, 0.3)), p))
        lot.put(M["acier"], C.pose_plane(G.boite((0, 0, 0.0), (l + 0.06, w + 0.06, 0.04)), p, n))
        lot.put(M["noir"], C.pose_plane(G.boite((0, 0, 0.015), (l, w, 0.03)), p, n))
        for k in range(6):
            lot.put(M["acier"], C.pose_plane(G.boite((-l / 2 + l * (k + 0.5) / 6, 0, 0.035), (l / 6 * 0.45, w, 0.025)), p, n))

    # -- essai 3 : greebles de toit (aérateurs, chemin de câbles, bouches), câbles le long des flancs --
    ra = G.Rnd(8303)
    for (x, yy, kind) in ((-1.95, y0 + 0.48, "champi"), (-1.25, y0 + 0.95, "boite"), (0.55, y0 + 0.48, "champi"),
                          (1.15, y0 + 0.95, "champi"), (-2.1, y0 + 0.95, "boite"), (0.95, y0 + 0.48, "boite")):
        zr = zf + 0.04
        if kind == "champi":
            rr0 = ra.f(0.07, 0.1)
            lot.put(M["acier"], G.tour([(zr - 0.1, rr0), (zr + 0.14, rr0)], 10, "z", (x, yy, 0.0)))
            lot.put(M["vdg2"], G.tour([(zr + 0.13, rr0 * 1.9), (zr + 0.17, rr0 * 1.7), (zr + 0.22, 0.02)], 12, "z", (x, yy, 0.0)))
            lot.put(M["noir"], G.tour([(zr + 0.1, rr0 * 1.05), (zr + 0.13, rr0 * 1.05)], 10, "z", (x, yy, 0.0)))
        else:
            lot.put(M["acier"], G.boite((x, yy, zr + 0.05), (0.26, 0.18, 0.16), ra.f(-0.2, 0.2)))
            for k in range(3):
                lot.put(M["noir"], G.boite((x, yy - 0.092, zr + 0.01 + 0.045 * k), (0.2, 0.01, 0.02), 0.0))
    for (yy, zz) in ((y0 + 0.5, zf + 0.12), (y0 + 0.97, zf + 0.12)):                     # chemins de câbles sur supports
        lot.put(M["acier"], G.boite(((x0 + x1) / 2 - 0.4, yy, zz), (x1 - x0 - 1.2, 0.09, 0.025)))
        for x in [x0 + 0.3 + 0.55 * k for k in range(6)]:
            lot.put(M["acier"], G.boite((x, yy, zz - 0.06), (0.025, 0.07, 0.12)))
        C.faisceau(lot, M["rouge"], M["noir"], (x0 + 0.25, yy, zz + 0.03), (x1 - 0.9, yy, zz + 0.03), 0.02, 3, 0.01, 0.022, ra)
    for (a, b, fl) in ((P.xf((-1.9, -1.0, 0.2)), P.xf((0.4, -1.12, 0.1)), 0.3), (P.xf((0.4, -1.12, 0.1)), P.xf((2.0, -1.0, 0.25)), 0.25),
                       (P.xf((2.4, -0.9, 0.5)), P.xf((3.8, -0.75, 0.35)), 0.18), (P.xf((-3.3, -0.9, 0.3)), P.xf((-2.3, -1.05, 0.1)), 0.22)):
        C.faisceau(lot, M["rouge"], M["noir"], a, b, fl, 4, 0.011, 0.026, ra)
    for k in range(18):                                                  # ferraille au sol : boulons, éclats, cornières
        x, y = ra.f(-5.8, 5.8), ra.f(-4.1, 4.1)
        if abs(y) < 3.0 and abs(x) < 4.5:
            continue
        if ra.f() < 0.5:
            lot.put(M["acier"] if ra.f() < 0.5 else M["jaune1"], G.boite((x, y, 0.02), (ra.f(0.08, 0.2), ra.f(0.05, 0.12), 0.03), ra.f(0, 3.0), ra.f(-0.3, 0.3)))
        else:
            lot.put(M["acier"], G.boite((x, y, 0.03), (ra.f(0.25, 0.45), 0.04, 0.04), ra.f(0, 3.0)))

    # ======================================================================================== 7. mâts, torchère, bossoir, lampadaires
    m0 = P.xf((2.9, 0.0, C.z_dessus(2.9) + 0.12))
    lot.put(M["acier"], G.tube([m0, G.add(m0, (0, 0, 1.3))], 0.03, 6))
    for k in range(4):                                                  # mât treillis sur le crâne
        a = TAU * k / 4 + 0.4
        lot.put(M["acier"], G.tube([G.add(m0, (0.13 * math.cos(a), 0.13 * math.sin(a), 0.0)),
                                    G.add(m0, (0.02 * math.cos(a), 0.02 * math.sin(a), 1.25))], 0.012, 4))
    for z in (0.5, 0.9):
        lot.put(M["acier"], G.tube([G.add(m0, (-0.26, 0, z)), G.add(m0, (0.26, 0, z))], 0.013, 4))
    lot.put(M["voyant"], G.sphere(G.add(m0, (0, 0, 1.33)), 0.03, 6, 3))
    for x in (-1.3, 1.1):                                               # fouets d'antenne sur l'épine
        p = P.xf((x, 0.0, C.z_dessus(x) + 0.25))
        lot.put(M["acier"], G.tube([p, G.add(p, (0.0, 0.0, 0.9))], 0.012, 4))
        lot.put(M["acier"], G.tour([(p[2], 0.04), (p[2] + 0.08, 0.035)], 8, "z", (p[0], p[1], 0.0)))
    tq = (-3.75, 3.35)                                                  # torchère de méthane au nord-ouest
    lot.put(M["acier"], G.tube([(tq[0], tq[1], 0.2), (tq[0], tq[1], 3.4)], 0.055, 8))
    lot.put(M["pierre"], G.boite((tq[0], tq[1], 0.15), (0.4, 0.4, 0.3)))
    for z in (1.1, 2.1, 3.0):
        lot.put(M["acier"], G.tour([(z - 0.03, 0.08), (z + 0.03, 0.08)], 8, "z", (tq[0], tq[1], 0.0)))
    lot.put(M["acier"], G.tour([(3.4, 0.08), (3.47, 0.1), (3.51, 0.06)], 10, "z", (tq[0], tq[1], 0.0)))
    lot.put(M["flamme"], G.tour([(3.47, 0.03), (3.53, 0.035), (3.6, 0.018), (3.66, 0.0)], 10, "z", (tq[0], tq[1], 0.0)))
    for k in range(3):
        a = TAU * k / 3 + 0.5
        lot.put(M["acier"], G.tube([(tq[0], tq[1], 3.05), (tq[0] + 1.0 * math.cos(a), tq[1] + 0.8 * math.sin(a), 0.05)], 0.007, 3))
    C.tuyau(lot, M["conduit"], M["cuivre"], [(tq[0] + 0.1, tq[1] - 0.05, 0.5), (tq[0] + 1.1, tq[1] - 0.05, 0.5),
                                             (tq[0] + 1.1, tq[1] - 0.9, 0.5)], 0.06)
    bq = (-5.35, -3.2, zw)                                              # bossoir au sud-ouest
    lot.put(M["acier"], G.tube([bq, G.add(bq, (0, 0, 1.55))], 0.045, 8))
    lot.put(M["acier"], G.tube([G.add(bq, (0, 0, 1.5)), G.add(bq, (0.78, -0.25, 1.7))], 0.03, 6))
    lot.put(M["acier"], G.tube([G.add(bq, (0, 0, 0.85)), G.add(bq, (0.62, -0.2, 1.66))], 0.018, 5))
    hk = G.add(bq, (0.78, -0.25, 1.7))
    lot.put(M["noir"], G.tube([hk, G.add(hk, (0, 0, -0.85))], 0.007, 3))
    lot.put(M["acier"], G.boite(G.add(hk, (0, 0, -0.9)), (0.08, 0.08, 0.1)))
    lot.put(M["acier"], G.tour([(bq[0] - 0.08, 0.09), (bq[0] + 0.08, 0.09)], 12, "x", (0.0, bq[1], bq[2] + 0.65)))
    for (x, y) in ((-4.45, -3.53), (3.5, -3.57)):             # lampadaires
        q = (x, y, zw)
        lot.put(M["acier"], G.tube([q, G.add(q, (0, 0, 1.3))], 0.025, 6))
        lot.put(M["acier"], G.tube([G.add(q, (0, 0, 1.28)), G.add(q, (0.0, -0.22, 1.32))], 0.015, 4))
        lot.put(M["veilleuse"], G.sphere(G.add(q, (0.0, -0.22, 1.24)), 0.045, 8, 4))

    # ======================================================================================== 8. objets des passerelles
    for (x, y, m) in ((-4.75, -2.25, "rapiece2"), (-5.05, -2.15, "vdg2"), (-4.9, -2.45, "rapiece2"), (1.85, -3.3, "vdg"),
                      (-2.05, -3.3, "rapiece2")):
        lot.put(M[m], G.tour([(zw, 0.15), (zw + 0.44, 0.15)], 16, "z", (x, y, 0.0), cap1=True))
        for z in (0.08, 0.36):
            lot.put(M["acier"], G.tour([(zw + z - 0.015, 0.156), (zw + z + 0.015, 0.156)], 16, "z", (x, y, 0.0)))
        lot.put(M["acier"], G.tour([(zw + 0.44, 0.03), (zw + 0.47, 0.03)], 8, "z", (x + 0.07, y, 0.0), cap1=True))
    for (x, y, sz, rz, m) in ((-2.75, -3.3, 0.4, 0.2, "bois"), (-1.6, -3.4, 0.3, -0.35, "bois"), (2.35, -3.4, 0.26, 0.6, "vdg2"),
                              (3.15, -3.35, 0.34, -0.15, "bois"), (-5.15, -2.85, 0.32, 0.4, "bois")):
        lot.put(M[m], G.boite((x, y, zw + sz / 2), (sz, sz * 0.85, sz), rz))
        lot.put(M["poutre"], G.boite((x, y, zw + sz + 0.01), (sz * 1.04, sz * 0.2, 0.02), rz))
    for (x, y) in ((1.05, -3.4), (1.22, -3.48), (1.14, -3.27)):        # bouteilles de gaz
        lot.put(M["jaune2"], G.tour([(zw, 0.08), (zw + 0.5, 0.08), (zw + 0.56, 0.05), (zw + 0.62, 0.03)], 12, "z", (x, y, 0.0), cap1=True))
    c = (-4.75, -3.05, zw)                                              # pompe à volant
    lot.put(M["acier"], G.boite((c[0], c[1], c[2] + 0.2), (0.4, 0.32, 0.4)))
    lot.put(M["cuivre"], G.tour([(c[1] - 0.2, 0.19), (c[1] - 0.17, 0.19)], 16, "y", (c[0] + 0.05, 0.0, c[2] + 0.42)))
    lot.put(M["vdg"], G.tour([(c[2] + 0.4, 0.09), (c[2] + 0.62, 0.09), (c[2] + 0.68, 0.0)], 12, "z", (c[0] - 0.1, c[1] + 0.05, 0.0)))

    # ======================================================================================== 9. sol : vase, berceaux, débris
    nez = P.xf((5.0, 0.0, -0.3))
    lot.put(M["boue"], G.butte_polaire((nez[0] + 0.15, nez[1] - 0.1, 0.0), 1.05, 1.5, 0.62, r, 12, 48, 0.3, 0.14))
    for (x, y, a, b) in ((nez[0] + 0.9, nez[1] - 1.2, 0.45, 0.35), (nez[0] - 0.4, nez[1] + 1.25, 0.5, 0.3)):
        lot.put(M["boue"], G.butte_polaire((x, y, 0.0), a, b, 0.2, r, 6, 28, 0.3, 0.2))
    for (x, y, a, b) in ((4.6, -3.3, 0.8, 0.55), (-5.6, -0.4, 0.6, 1.1), (-0.9, -4.05, 0.9, 0.35), (2.2, 3.9, 0.9, 0.4)):
        lot.put(M["vase"], G.butte_polaire((x, y, 0.0), a, b, 0.025, r, 3, 36, 0.2, 0.22))
    for (x, y) in ((-3.4, -1.2), (-3.6, 1.95), (-4.5, -1.75), (-4.6, 2.0)):
        for k in range(4):
            lot.put(M["poutre"], G.boite((x, y, 0.09 + 0.17 * k), (0.95 if k % 2 == 0 else 0.22, 0.22 if k % 2 == 0 else 0.95, 0.15), -0.1 + 0.06 * k))
        lot.put(M["acier"], G.tour([(0.7, 0.07), (1.05, 0.06)], 8, "z", (x, y, 0.0), cap1=True))
    deb = [("plaque", -5.75, -1.3, 0.55, 0.38, 0.4), ("plaque", 4.75, -3.75, 0.5, 0.32, -0.7), ("plaque", -5.5, 3.3, 0.6, 0.42, 0.9),
           ("fut", 5.3, -2.55, 1.4), ("fut", -5.8, -3.9, 0.3), ("fut", 5.55, 2.2, 0.0), ("fut", 4.3, -3.15, 2.2),
           ("caisse", 4.85, -2.05, 0.36, 0.3, 0.5), ("caisse", -5.55, 1.5, 0.3, 0.3, -0.2), ("caisse", 1.3, 4.0, 0.32, 0.3, 0.7),
           ("tuyau", 4.15, -4.0, 0.9, 0.05, 0.25), ("tuyau", -3.6, -4.0, 0.7, 0.04, -0.15),
           ("bulbe", 5.55, -1.45, 0.18), ("bulbe", 3.65, -3.95, 0.13), ("pneu", -2.4, -4.0, 0.17), ("plaque", 2.6, 4.0, 0.5, 0.3, 0.3)]
    for d in deb:
        k, x, y = d[0], d[1], d[2]
        if k == "plaque":
            lot.put(M["jaune1"] if d[3] > 0.52 else M["vdg"], G.boite((x, y, 0.06), (d[3], d[4], 0.03), d[5], 0.35, 0.15))
        elif k == "fut":
            lot.put(M["rapiece2"], _couche(G.tour([(-0.22, 0.14), (0.22, 0.14)], 14, "x", cap0=True, cap1=True), (x, y), d[3]))
            lot.put(M["acier"], _couche(G.tour([(-0.13, 0.148), (-0.1, 0.148)], 14, "x"), (x, y), d[3]))
        elif k == "caisse":
            lot.put(M["bois"], G.boite((x, y, d[3] / 2), (d[3], d[4], d[3]), d[5], 0.0, 0.08))
        elif k == "tuyau":
            lot.put(M["conduit"], _couche(G.tour([(-d[3] / 2, d[4] * 2), (d[3] / 2, d[4] * 2)], 10, "x", cap0=True, cap1=True), (x, y), d[5], d[4] * 2))
        elif k == "bulbe":
            lot.put(M["verre"], G.sphere((x, y, d[3] * 0.6), d[3], 10, 5))
            lot.put(M["liquide"], G.sphere((x + 0.02, y - 0.02, 0.05), d[3] * 0.7, 8, 3, zmin=0.0))
        elif k == "pneu":
            lot.put(M["caoutchouc"], G.tour([(0.0, d[3]), (0.06, d[3] + 0.025), (0.12, d[3])], 16, "z", (x, y, 0.0)))
    return {"pose": POSE}


# ================================================================================================ pièces de l'âge 8
def _couche(mesh, q, rz, r=0.14):
    """Objet couché au sol (axe x local), tourné de rz, posé en q (x, y)."""
    v, f, u = mesh
    out = []
    for p in v:
        p = G.rot_z(p, rz)
        out.append((p[0] + q[0], p[1] + q[1], p[2] + r))
    return out, f, u


def _garde(lot, M, a, b, h=0.42):
    """Garde-corps : main courante, lisse, montants."""
    lot.put(M["acier"], G.tube([G.add(a, (0, 0, h)), G.add(b, (0, 0, h))], 0.018, 5))
    lot.put(M["acier"], G.tube([G.add(a, (0, 0, h * 0.5)), G.add(b, (0, 0, h * 0.5))], 0.012, 5))
    n = max(1, int(G.length(G.sub(b, a)) / 0.42))
    for j in range(n + 1):
        q = G.lerp(a, b, j / float(n))
        lot.put(M["acier"], G.tube([q, G.add(q, (0, 0, h))], 0.014, 5))


def _volume(lot, M, a0, a1, v0, v1, zp, ze, zf, rr_):
    """Volume de bâtiment (repère de la halle) : soubassement de pierre, tôle ondulée, poteaux, toit à deux pans à joints
    debout au pas irrégulier (tôles rapiécées), faîtière, rives."""
    for (v, sgn) in ((v0, -1), (v1, 1)):
        lot.put(M["pierre"], G.boite(((a0 + a1) / 2, v + sgn * 0.02, zp + 0.17), (a1 - a0 + 0.04, 0.12, 0.34)))
        lot.put(M["tole_ond"], G.boite(((a0 + a1) / 2, v, (zp + 0.34 + ze) / 2), (a1 - a0, 0.08, ze - zp - 0.34)))
    for u in (a0, a1):
        lot.put(M["tole_ond"], G.boite((u, (v0 + v1) / 2, (zp + ze) / 2), (0.08, v1 - v0, ze - zp)))
        for v in (v0, v1):
            lot.put(M["poutre"], G.boite((u, v, (zp + ze) / 2 + 0.02), (0.12, 0.12, ze - zp + 0.04)))
    lot.put(M["poutre"], G.boite(((a0 + a1) / 2, v0 - 0.05, ze - 0.03), (a1 - a0 + 0.1, 0.1, 0.09)))
    deb = 0.16
    vm = (v0 + v1) / 2
    for (vs, sgn) in ((v0 - deb, -1), (v1 + deb, 1)):
        u = a0 - deb
        while u < a1 + deb - 0.05:
            w = min(rr_.f(0.18, 0.34), a1 + deb - u)
            m = M["toit"] if rr_.f() < 0.8 else (M["cuivre"] if rr_.f() < 0.5 else M["rapiece"])
            q = [(u + 0.012, vs, ze - 0.02), (u + w - 0.012, vs, ze - 0.02), (u + w - 0.012, vm, zf), (u + 0.012, vm, zf)]
            top = [G.add(p, (0, 0, 0.04)) for p in q]
            lot.put(m, G.merge((top, [(0, 1, 2, 3)], [(p[0], p[1]) for p in top]), G.loft([[q[0], q[1]], [top[0], top[1]]], closed=False)))
            lot.put(M["toit"], G.tube([G.add(q[0], (0, 0, 0.05)), G.add(q[3], (0, 0, 0.05))], 0.014, 4))
            u += w
    lot.put(M["cuivre"], G.tube([(a0 - deb, vm, zf + 0.05), (a1 + deb, vm, zf + 0.05)], 0.05, 6))
    for v in (v0 - deb, v1 + deb):
        lot.put(M["poutre"], G.boite(((a0 + a1) / 2, v, ze - 0.04), (a1 - a0 + 2 * deb, 0.05, 0.08)))


def _pavillon(lot, M, x0, x1, y0, y1, z0, ze, zf):
    """Pavillon à pignon (faîtage nord-sud) : murs de tôle, pignon de planches, toit à deux pans vus de trois-quarts."""
    xm = (x0 + x1) / 2
    lot.put(M["tole_ond"], G.boite((xm, (y0 + y1) / 2, (z0 + ze) / 2), (x1 - x0, y1 - y0, ze - z0)))
    tri = [(x0, y0, ze), (x1, y0, ze), (xm, y0, zf)]
    lot.put(M["bois"], G.merge((tri, [(0, 1, 2)], [(p[0], p[2]) for p in tri]),
                               ([G.add(p, (0, 0.06, 0)) for p in tri], [(0, 2, 1)], [(p[0], p[2]) for p in tri])))
    for (xa, sgn) in ((x0 - 0.12, -1), (x1 + 0.12, 1)):
        q = [(xa, y0 - 0.12, ze - 0.06), (xa, y1 + 0.05, ze - 0.06), (xm, y1 + 0.05, zf + 0.02), (xm, y0 - 0.12, zf + 0.02)]
        top = [G.add(p, (0, 0, 0.045)) for p in q]
        lot.put(M["toit"], G.merge((top, [(0, 1, 2, 3)], [(p[0], p[1]) for p in top]), G.loft([[q[0], q[1]], [top[0], top[1]]], closed=False)))
        for t in (0.2, 0.45, 0.7):
            a = G.lerp(top[0], top[3], t)
            b = G.lerp(top[1], top[2], t)
            lot.put(M["toit"], G.tube([G.add(a, (0, 0, 0.01)), G.add(b, (0, 0, 0.01))], 0.012, 4))
    lot.put(M["cuivre"], G.tube([(xm, y0 - 0.14, zf + 0.08), (xm, y1 + 0.06, zf + 0.08)], 0.04, 6))
    lot.put(M["poutre"], G.tube([(x0 - 0.12, y0 - 0.13, ze - 0.03), (xm, y0 - 0.13, zf + 0.06), (x1 + 0.12, y0 - 0.13, ze - 0.03)], 0.03, 4))
    lot.put(M["noir"], G.boite((xm, y0 - 0.08, z0 + 0.36), (0.5, 0.04, 0.68)))
    lot.put(M["poutre"], G.boite((xm, y0 - 0.1, z0 + 0.36), (0.035, 0.05, 0.68)))
    lot.put(M["veilleuse"], G.sphere((xm + 0.32, y0 - 0.12, z0 + 0.78), 0.03, 8, 4))
    lot.put(M["noir"], G.tour([(0.0, 0.08), (0.03, 0.08)], 12, "y", (xm, y0 - 0.06, ze + 0.12)))
    lot.put(M["acier"], G.tour([(-0.02, 0.1), (0.01, 0.1), (0.01, 0.08)], 12, "y", (xm, y0 - 0.06, ze + 0.12)))


def _bulbe(lot, M, r, cx, cy, zb, R, cuve, nn):
    """Dôme de verre de l'âge 8 : socle de pierre, cuve de cuivre cerclée, bulbe (liquide luminescent au fond, verre
    au-dessus), nervures vert-de-gris, ceintures, bulles affleurantes côté caméra, chapeau à évent. Renvoie z du sommet."""
    TAU = G.TAU
    lot.put(M["pierre"], G.tour([(zb, R + 0.18), (zb + 0.2, R + 0.16), (zb + 0.24, R + 0.09)], 40, "z", (cx, cy, 0.0), cap1=True))
    z1 = zb + 0.22 + cuve
    if cuve > 0:
        lot.put(M["cuivre"], G.tour([(zb + 0.2, R + 0.07), (z1, R + 0.07), (z1 + 0.04, R + 0.02)], 40, "z", (cx, cy, 0.0)))
        for z in [zb + 0.24 + (cuve - 0.04) * t for t in ((0.15, 0.85) if cuve < 0.3 else (0.1, 0.5, 0.9))]:
            lot.put(M["acier"], G.tour([(z - 0.025, R + 0.08), (z - 0.02, R + 0.1), (z + 0.02, R + 0.1), (z + 0.025, R + 0.08)], 40, "z", (cx, cy, 0.0)))
            nr = int(14 * R + 6)
            pts = [((cx + (R + 0.1) * math.cos(a), cy + (R + 0.1) * math.sin(a), z), (math.cos(a), math.sin(a), 0.0))
                   for a in [TAU * k / nr for k in range(nr)]]
            lot.put(M["riv"], G.rivets_le_long(pts, 0.018, 0.012))
    zc = z1 + 0.04
    el_liq = 0.3      # m1 : bande de néon trop haute, « œuf au plat »
    prof_l = [(zc + R * math.sin(t), R * math.cos(t)) for t in [-0.1 + (el_liq + 0.1) * i / 6.0 for i in range(7)]]
    lot.put(M["liquide"], G.tour(prof_l, 48, "z", (cx, cy, 0.0)))
    prof_v = [(zc + R * math.sin(t), R * math.cos(t)) for t in [el_liq + (math.pi / 2 - el_liq) * i / 12.0 for i in range(13)]]
    prof_v[-1] = (zc + R, 0.0)
    lot.put(M["verre"], G.tour(prof_v, 48, "z", (cx, cy, 0.0)))
    for k in range(nn):
        a = TAU * (k + 0.5) / nn + 0.13 * R
        arc = [(cx + (R + 0.02) * math.cos(t) * math.cos(a), cy + (R + 0.02) * math.cos(t) * math.sin(a), zc + (R + 0.02) * math.sin(t))
               for t in [el_liq + 0.02 + (math.pi / 2 - 0.2 - el_liq) * i / 12.0 for i in range(13)]]
        lot.put(M["conduit"], G.tube(arc, 0.03 if R > 0.8 else 0.022, 5))
    for t in (el_liq, 0.82, 1.18):
        rr_ = (R + 0.02) * math.cos(t)
        z = zc + (R + 0.02) * math.sin(t)
        lot.put(M["cuivre"], G.tour([(z - 0.03, rr_), (z - 0.022, rr_ + 0.035), (z + 0.022, rr_ + 0.035), (z + 0.03, rr_ - 0.01)], 48, "z", (cx, cy, 0.0)))
    for k in range(5 + int(R * 6)):
        a = -math.pi / 2 + r.f(-1.05, 1.05)
        t = r.f(-0.05, el_liq - 0.05)
        rb = r.f(0.028, 0.06) * (0.8 + 0.3 * R)
        lot.put(M["bulle"], G.sphere((cx + R * math.cos(t) * math.cos(a), cy + R * math.cos(t) * math.sin(a), zc + R * math.sin(t)), rb, 8, 4))
    zt = zc + R
    lot.put(M["cuivre"], G.tour([(zt - 0.06, 0.2 * R + 0.07), (zt + 0.05, 0.2 * R + 0.07), (zt + 0.1, 0.11), (zt + 0.24, 0.085),
                                 (zt + 0.28, 0.12), (zt + 0.33, 0.0)], 16, "z", (cx, cy, 0.0)))
    q = (cx + R * 0.25, cy - R - 0.2, zb)                                    # vanne et manomètre au pied, côté caméra
    lot.put(M["acier"], G.tube([q, G.add(q, (0, 0, 0.3)), G.add(q, (0.0, 0.12, 0.3))], 0.03, 8))
    lot.put(M["rouge"], G.tour([(zb + 0.3, 0.07), (zb + 0.32, 0.07)], 12, "z", (q[0], q[1], 0.0)))
    lot.put(M["acier_clair"], G.tour([(-0.01, 0.045), (0.02, 0.045)], 12, "y", (q[0] + 0.08, q[1] - 0.02, zb + 0.2)))
    return zt
