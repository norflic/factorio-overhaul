"""QG ÂGE 6 : ÉLECTRICITÉ (ère II Lourde, série du 31/10). Emprise 10×5. NEZ À DROITE (+X), tuyères à gauche.

Bible (DESIGN_EPOQUES §5, époque 6) : « Centrale de commandement : tour centrale ; 2 hautes piles d'isolateurs sur les côtés ;
tore de Tesla au sommet ; arcs entre les piles » ; céramique #D8D4C8 patinée, cuivre de bobine #B0703A, acier #5C6168, arcs
cyan #60D0FF, luminance 64, premier matériau clair ; clair, vertical, empilé.

Lecture : la tour sort de la cage des côtes, empilée (tambour, bobine, isolateurs, tore) ; à ses côtés, sur le radier, les
2 grandes piles et l'arc qui les relie ; devant, de biais, la salle des machines, ses transformateurs et sa grosse bobine ;
derrière, les condensateurs et le pylône ; les tuyères sont rebobinées en moteurs.
"""
import math

import carcasse as C
import ere2 as E
import geo as G
import mat as MT

PAL = dict(jaunes=[(0.36, 0.235, 0.03), (0.24, 0.16, 0.024), (0.46, 0.34, 0.06), (0.32, 0.18, 0.022)], sec=(0.44, 0.415, 0.35), sec2=(0.25, 0.235, 0.205),
           conduit=(0.14, 0.155, 0.175), rapiece=(0.13, 0.145, 0.165), rapiece2=(0.34, 0.14, 0.05), acier=(0.075, 0.085, 0.1), acier_clair=(0.22, 0.24, 0.27),
           cuivre=(0.43, 0.17, 0.05), bois=(0.2, 0.16, 0.11), poutre=(0.05, 0.05, 0.055), pierre=(0.15, 0.145, 0.13), toit=(0.1, 0.11, 0.125), ond=(0.33, 0.31, 0.26),
           boue=(0.075, 0.05, 0.028), flaque=(0.02, 0.02, 0.02), lum=(0.2, 0.68, 1.0), voy=(0.25, 0.75, 1.0), veil=(0.03, 0.06, 0.07), vitre=(0.012, 0.03, 0.04), vitre_r=(0.2, 0.35, 0.42),
           nu=(0.72, 0.72, 0.7))
PATINE = dict(ta=0.17, ra=0.26, ec=0.55, nu_k=1.3, ec_col=(0.11, 0.085, 0.055))
COQUE = [(0.3, "jaune0"), (0.42, "jaune1"), (0.49, "jaune2"), (0.56, "jaune3"), (0.82, "vdg"), (0.93, "rapiece"), (1.0, "rapiece2")]
TAU = G.TAU


def matieres(S):
    M = E.matieres(S, "q6", PAL, PATINE)
    sf = MT.surface
    cr = (0.012, 0.01, 0.008)
    M["pierre_cer"] = sf("q6_cer", (0.6, 0.565, 0.485), rough=0.28, met=0.0, coulures=0.8, rouille=(0.16, 0.1, 0.05), usure=0.25, nu=(0.85, 0.83, 0.78), crasse=0.9, crasse_col=cr, grain=0.09, graine=61)
    M["cer2"] = sf("q6_cer2", (0.36, 0.33, 0.27), rough=0.4, met=0.0, coulures=0.9, rouille=(0.16, 0.09, 0.04), usure=0.5, nu=(0.8, 0.78, 0.72), crasse=0.9, crasse_col=cr, pied=(0.5, 1.6, 0.5),
                    tole=(0.52, 0.3), joint=0.4, var=0.12, relief=0.6, grain=0.1, graine=62)
    M["bobine"] = sf("q6_bobine", (0.5, 0.2, 0.055), rough=0.32, met=0.85, usure=0.5, nu=(0.85, 0.5, 0.26), crasse=0.8, crasse_col=cr, coulures=0.5, rouille=(0.05, 0.17, 0.11), graine=63)
    M["alu"] = sf("q6_alu", (0.55, 0.57, 0.6), rough=0.3, met=0.75, usure=0.2, crasse=0.65, crasse_col=cr, graine=64)
    M["hazard"] = sf("q6_hazard", (0.36, 0.25, 0.03), rough=0.5, met=0.2, bandes=(0.2, (0.012, 0.011, 0.01), 0.5), usure=0.8, nu=(0.4, 0.38, 0.35), crasse=0.7, crasse_col=cr, coulures=0.6, graine=65)
    M["dalle"] = sf("q6_dalle", (0.115, 0.112, 0.1), rough=0.85, met=0.0, tole=(0.7, 0.44), joint=0.35, var=0.14, coulures=0.4, usure=0.5, nu=(0.32, 0.31, 0.29), crasse=0.85, crasse_col=cr, relief=0.5, grain=0.14, graine=66)
    M["radia"] = sf("q6_radia", (0.1, 0.115, 0.13), rough=0.5, met=0.6, usure=0.8, nu=(0.55, 0.57, 0.6), crasse=0.8, crasse_col=cr, coulures=0.7, rouille=(0.14, 0.07, 0.03), graine=67)
    M["arc"] = MT.lumiere(S, "q6_arc", (0.1, 0.55, 1.0), 2.6, main=0.3)
    M["coeur"] = S.mat_emissive("q6_coeur", (0.2, 0.68, 1.0), strength=2.8, base=(0.02, 0.06, 0.09), main_scale=0.55, crust=(9.0, 0.45, 5.0))
    return M


# ================================================================================================ pièces
def bobine_axe(lot, M, c, L, R, axe="x", n=None, rz=0.0):
    """Grosse bobine de cuivre : spires serrées (tores), joues d'acier, âme ; axe x local."""
    with E.dans(lot, c, rz):
        lot.put(M["noir"], G.tour([(-L / 2, R * 0.82), (L / 2, R * 0.82)], 30, "x"))
        n = n or int(L / 0.046)
        for k in range(n):
            x = -L / 2 + L * (k + 0.5) / n
            lot.put(M["bobine"], G.tour([(x + 0.021 * math.cos(TAU * j / 6), R + 0.021 * math.sin(TAU * j / 6)) for j in range(7)], 30, "x"))
        for s in (-1, 1):
            xj = s * (L / 2 + 0.03)
            lot.put(M["acier"], G.tour([(xj - 0.03, R * 1.16), (xj + 0.03, R * 1.16)], 30, "x", cap0=True, cap1=True))
            lot.put(M["riv"], G.rivets_le_long([((xj + s * 0.032, R * 1.05 * math.cos(TAU * k / 12), R * 1.05 * math.sin(TAU * k / 12)), (s, 0, 0)) for k in range(12)], 0.02, 0.014))


def bobine_z(lot, M, x, y, z0, z1, R):
    """Bobinage vertical autour d'un tambour : tores empilés (colonne crantée de cuivre)."""
    n = int((z1 - z0) / 0.044)
    for k in range(n):
        z = z0 + (z1 - z0) * (k + 0.5) / n
        lot.put(M["bobine"], E.tore(R, 0.02, (x, y, z), "z", 34, 6))


def transfo(lot, M, ra, c, rz, s=1.0):
    """Transformateur : cuve à ailettes, conservateur couché, 3 traversées (piles courtes de 3 hauteurs), barres de cuivre."""
    tops = []
    with E.dans(lot, c, rz):
        w, d, h = 0.86 * s, 0.56 * s, 0.68 * s
        lot.put(M["dalle"], G.boite((0, 0, 0.05), (w + 0.5, d + 0.5, 0.1)))
        lot.put(M["vdg2"], G.boite((0, 0, 0.1 + h / 2), (w, d, h)))
        lot.put(M["toit"], G.boite((0, 0, 0.1 + h + 0.02), (w + 0.06, d + 0.06, 0.04)))
        for k in range(9):                                               # ailettes de refroidissement, façade et joues
            lot.put(M["radia"], G.boite((-w / 2 + w * (k + 0.5) / 9, -d / 2 - 0.09, 0.1 + h * 0.48), (0.022, 0.18, h * 0.8)))
        for s_ in (-1, 1):
            for k in range(5):
                lot.put(M["radia"], G.boite((s_ * (w / 2 + 0.07), -d / 2 + d * (k + 0.5) / 5, 0.1 + h * 0.48), (0.14, 0.02, h * 0.76)))
        lot.put(M["vdg"], G.tour([(-w * 0.42, 0.11 * s), (w * 0.42, 0.11 * s)], 16, "x", (0.0, d / 2 - 0.05, 0.1 + h + 0.22 * s), cap0=True, cap1=True))
        for x in (-w * 0.3, w * 0.3):
            lot.put(M["acier"], G.boite((x, d / 2 - 0.05, 0.1 + h + 0.1 * s), (0.05, 0.05, 0.2 * s)))
        for (x, n) in ((-w * 0.32, 4), (0.0, 5), (w * 0.32, 3)):
            zt = E.pile_iso(lot, M, x, -d * 0.12, 0.1 + h + 0.03, n, 0.085 * s, 0.085)
            tops.append((x, -d * 0.12, zt))
        lot.put(M["hazard"], G.boite((0.0, -d / 2 - 0.005, 0.2), (w * 0.8, 0.02, 0.1)))
        lot.put(M["voyant"], G.boite((w * 0.42, -d / 2 - 0.2, 0.75 * s), (0.025, 0.01, 0.025)))
    return [G.add(G.rot_z(t, rz), c) for t in tops]


def salle(lot, M, ra):
    """Salle des machines, repère local : long volume clair, fenêtres toutes différentes, toit en 2 pentes à lanterneau, cabine haute."""
    u0, u1, v0, v1 = -2.0, 1.7, -0.62, 0.72
    ze, zf = 1.08, 1.5
    lot.put(M["dalle"], G.boite(((u0 + u1) / 2, (v0 + v1) / 2, 0.09), (u1 - u0 + 0.25, v1 - v0 + 0.25, 0.18)))
    # murs : panneaux de céramique et d'acier de largeurs tirées, ossature sombre
    x = u0
    while x < u1 - 0.02:
        w = min(ra.f(0.34, 0.74), u1 - x)
        m = M["cer2"] if ra.f() < 0.66 else (M["tole_ond"] if ra.f() < 0.65 else M["vdg2"])
        lot.put(m, G.boite((x + w / 2, v0, (0.18 + ze) / 2), (w - 0.012, 0.07, ze - 0.18)))
        lot.put(M["poutre"], G.boite((x, v0 - 0.03, (0.18 + ze) / 2), (0.07, 0.08, ze - 0.18)))
        x += w
    lot.put(M["poutre"], G.boite(((u0 + u1) / 2, v0 - 0.035, ze - 0.03), (u1 - u0 + 0.1, 0.09, 0.08)))
    lot.put(M["poutre"], G.boite(((u0 + u1) / 2, v0 - 0.035, 0.3), (u1 - u0, 0.07, 0.05)))
    for u in (u0, u1):
        lot.put(M["cer2"], G.boite((u, (v0 + v1) / 2, (0.18 + ze) / 2), (0.07, v1 - v0, ze - 0.18)))
    # toit : 3 sheds de hauteurs inégales (pentes de l'ère), une baie vitrée ; tôles rapiécées, jamais de grand aplat
    baies = (v0 - 0.1, -0.12, 0.3, v1 + 0.06)
    faits = (zf - 0.12, zf + 0.06, zf - 0.02)
    for i_ in range(3):
        vs, vn = baies[i_], baies[i_ + 1]
        zh_ = faits[i_]
        vitre = i_ == 1
        u = u0 - 0.1
        while u < u1 + 0.08:
            w = min(ra.f(0.17, 0.36), u1 + 0.1 - u)
            q = [(u + 0.012, vs, ze - 0.01), (u + w - 0.012, vs, ze - 0.01), (u + w - 0.012, vn, zh_), (u + 0.012, vn, zh_)]
            top = [G.add(p, (0, 0, 0.03)) for p in q]
            if vitre and ra.f() < 0.78:
                m = M["verre_sombre"]
            else:
                m = M["toit"] if ra.f() < 0.7 else (M["vdg2"] if ra.f() < 0.6 else M["rapiece"])
            lot.put(m, G.merge((top, [(0, 1, 2, 3)], [(p[0], p[1]) for p in top]), G.loft([[q[0], q[1]], [top[0], top[1]]], closed=False)))
            lot.put(M["acier"], G.tube([G.add(q[0], (0, 0, 0.04)), G.add(q[3], (0, 0, 0.04))], 0.012, 4))
            u += w
        lot.put(M["noir"], G.boite(((u0 + u1) / 2, vn, (ze + zh_) / 2 + 0.02), (u1 - u0, 0.03, zh_ - ze)))
        lot.put(M["bobine"], G.tube([(u0 - 0.1, vn, zh_ + 0.05), (u1 + 0.1, vn, zh_ + 0.05)], 0.024, 6))
        lot.put(M["acier"], G.tube([(u0 - 0.1, vs + 0.03, ze + 0.03), (u1 + 0.1, vs + 0.03, ze + 0.03)], 0.022, 5))
    C.evente(lot, M["acier"], M["noir"], (0.15, -0.38, ze + 0.13), 0.2, 0.34, 4, 0.0, 0.1)
    C.evente(lot, M["vdg2"], M["noir"], (1.25, 0.1, ze + 0.2), 0.2, 0.26, 3, 0.0, 0.1)
    # chemin de câbles et barre de cuivre sur isolateurs courts, sur le toit
    tt = []
    for (x_, y_, n_) in ((-0.2, -0.28, 3), (0.5, -0.33, 2), (1.1, -0.26, 4)):
        tt.append((x_, y_, E.pile_iso(lot, M, x_, y_, ze + 0.2, n_, 0.075, 0.08)))
    lot.put(M["bobine"], G.tube(tt, 0.016, 5))
    for (x_, y_) in ((0.82, 0.52), (-0.25, 0.5)):
        lot.put(M["acier"], G.tour([(ze + 0.05, 0.05), (ze + 0.42, 0.05), (ze + 0.44, 0.11), (ze + 0.5, 0.1), (ze + 0.53, 0.0)], 10, "z", (x_, y_, 0.0)))
    # cabine haute en encorbellement, vitres inclinées, côté ouest (empilement)
    cu, cv = -1.15, 0.05
    lot.put(M["acier"], G.boite((cu, cv, zf + 0.12), (0.7, 0.62, 0.3)))
    lot.put(M["cer2"], G.prisme([(cu - 0.48, cv - 0.38), (cu + 0.48, cv - 0.38), (cu + 0.48, cv + 0.34), (cu - 0.48, cv + 0.34)], zf + 0.27, zf + 0.72, top_scale=1.1))
    q = [(cu - 0.42, cv - 0.415, zf + 0.42), (cu + 0.42, cv - 0.415, zf + 0.42), (cu + 0.48, cv - 0.46, zf + 0.7), (cu - 0.48, cv - 0.46, zf + 0.7)]
    lot.put(M["verre_sombre"], E.dalle(q, (0.0, -1.0, 0.1), 0.0, 0.015))
    for t in (0.0, 0.33, 0.66, 1.0):
        lot.put(M["acier"], G.tube([G.add(G.lerp(q[0], q[1], t), (0, -0.015, 0)), G.add(G.lerp(q[3], q[2], t), (0, -0.015, 0))], 0.012, 4))
    lot.put(M["toit"], G.prisme([(cu - 0.6, cv - 0.5), (cu + 0.6, cv - 0.5), (cu + 0.6, cv + 0.42), (cu - 0.6, cv + 0.42)], zf + 0.72, zf + 0.82, top_scale=0.9))
    E.garde(lot, M, [(cu - 0.6, cv - 0.5, zf + 0.82), (cu + 0.6, cv - 0.5, zf + 0.82), (cu + 0.6, cv + 0.42, zf + 0.82)], 0.24, 0.28)
    for (dx, n) in ((-0.35, 6), (0.32, 4)):
        E.pile_iso(lot, M, cu + dx, cv - 0.05, zf + 0.84, n, 0.09, 0.09)
    # façade : porte, fenêtres inégales, armoires, chemin de câbles
    lot.put(M["noir"], G.boite((-1.42, v0 - 0.045, 0.52), (0.48, 0.04, 0.68)))
    lot.put(M["poutre"], G.boite((-1.42, v0 - 0.05, 0.52), (0.03, 0.05, 0.68)))
    lot.put(M["hazard"], G.boite((-1.42, v0 - 0.06, 0.92), (0.6, 0.04, 0.09)))
    lot.put(M["toit"], G.boite((-1.42, v0 - 0.22, 1.02), (0.68, 0.34, 0.03), 0.0, -0.2))
    C.hublot(lot, "carre", M["acier"], M["hublot"], (-0.72, v0 - 0.04, 0.72), (0.0, -1.0, 0.0), 0.1)
    C.hublot(lot, "barreaux", M["acier"], M["verre_sombre"], (-0.18, v0 - 0.04, 0.76), (0.0, -1.0, 0.0), 0.09)
    C.hublot(lot, "ovale", M["acier"], M["veilleuse"], (0.42, v0 - 0.04, 0.72), (0.0, -1.0, 0.0), 0.08)
    C.hublot(lot, "double", M["acier"], M["verre_sombre"], (1.28, v0 - 0.04, 0.78), (0.0, -1.0, 0.0), 0.07)
    lot.put(M["acier"], G.boite((0.85, v0 - 0.08, 0.5), (0.34, 0.11, 0.42)))
    lot.put(M["noir"], G.boite((0.85, v0 - 0.14, 0.5), (0.24, 0.012, 0.28)))
    lot.put(M["voyant"], G.boite((0.94, v0 - 0.15, 0.6), (0.03, 0.01, 0.03)))
    lot.put(M["acier"], G.boite(((u0 + u1) / 2 + 0.2, v0 - 0.09, 1.0), (3.1, 0.07, 0.025)))
    C.faisceau(lot, M["rouge"], M["noir"], (u0 + 0.5, v0 - 0.1, 1.03), (u1 - 0.35, v0 - 0.1, 1.03), 0.02, 3, 0.01, 0.02, ra)
    C.tuyau(lot, M["cuivre"], M["acier"], [(1.55, v0 - 0.08, 1.0), (1.55, v0 - 0.08, 0.3)], 0.03, rb=0.06, pas_bride=0.3)


def tour_centrale(lot, M, u, v):
    """La tour (empilée), repère courant : tambour dans la cage, bobine, isolateurs, tore. Rend le z du tore."""
    zp = E.Z_PONT
    c = (u, v, 0.0)
    prof = [(zp, 1.12), (1.9, 1.12), (1.98, 0.98), (2.04, 0.62)]
    lot.put(M["pierre_cer"], G.tour(prof, 56, "z", c))
    for z in (0.62, 0.95, 1.3, 1.62, 1.88):
        lot.put(M["acier"], G.tour([(z - 0.025, 1.125), (z - 0.02, 1.15), (z + 0.02, 1.15), (z + 0.025, 1.125)], 56, "z", c))
        pts = [((u + 1.15 * math.cos(TAU * k / 34), v + 1.15 * math.sin(TAU * k / 34), z), (math.cos(TAU * k / 34), math.sin(TAU * k / 34), 0.0)) for k in range(34)]
        lot.put(M["riv"], G.rivets_le_long(pts, 0.016, 0.01))
    # fente du cœur (cyan), coupée par des meneaux
    lot.put(M["coeur"], G.tour([(1.42, 1.135), (1.54, 1.135)], 56, "z", c))
    for k in range(24):
        a = TAU * k / 24
        lot.put(M["acier"], G.boite((u + 1.14 * math.cos(a), v + 1.14 * math.sin(a), 1.48), (0.04, 0.06, 0.15), a))
    # second étage : tambour clair, bobinage, balcon
    lot.put(M["cer2"], G.tour([(2.04, 0.6), (2.42, 0.6)], 40, "z", c))
    bobine_z(lot, M, u, v, 2.42, 3.02, 0.58)
    lot.put(M["acier"], G.tour([(2.4, 0.66), (2.44, 0.66)], 40, "z", c, cap1=True))
    lot.put(M["acier"], G.tour([(3.02, 0.66), (3.06, 0.66)], 40, "z", c, cap1=True))
    lot.put(M["pierre_cer"], G.tour([(3.06, 0.42), (3.42, 0.36), (3.46, 0.3)], 32, "z", c))
    for z in (3.14, 3.28):
        lot.put(M["acier"], G.tour([(z - 0.015, 0.42), (z + 0.015, 0.42)], 32, "z", c))
    # balcon annulaire au sommet du bobinage
    Rb = 0.88
    lot.put(M["acier"], G.tour([(3.03, Rb), (3.06, Rb), (3.07, 0.3)], 36, "z", c))
    pts = [(u + Rb * math.cos(TAU * k / 22), v + Rb * math.sin(TAU * k / 22), 3.06) for k in range(23)]
    E.garde(lot, M, pts, 0.26, 0.2)
    for k in range(6):
        a = TAU * k / 6 + 0.3
        lot.put(M["acier"], G.tube([(u + 0.6 * math.cos(a), v + 0.6 * math.sin(a), 2.5), (u + Rb * math.cos(a), v + Rb * math.sin(a), 3.03)], 0.016, 4))
    # mât d'isolateurs et tore
    zt = E.pile_iso(lot, M, u, v, 3.48, 9, 0.2, 0.115)
    zT = zt + 0.3
    lot.put(M["acier"], G.tour([(zt - 0.02, 0.09), (zT, 0.09)], 12, "z", c))
    lot.put(M["alu"], E.tore(0.56, 0.16, (u, v, zT), "z", 48, 14))
    lot.put(M["acier"], G.tour([(zT - 0.06, 0.17), (zT - 0.04, 0.12), (zT + 0.06, 0.12), (zT + 0.08, 0.15)], 20, "z", c, cap1=True))
    lot.put(M["acier"], G.tube([(u, v, zT + 0.05), (u, v, zT + 0.42)], 0.016, 5))
    lot.put(M["alu"], G.sphere((u, v, zT + 0.44), 0.05, 10, 5))
    for k in range(8):
        a = TAU * k / 8 + 0.2
        lot.put(M["acier"], G.tube([(u + 0.12 * math.cos(a), v + 0.12 * math.sin(a), zT), (u + 0.56 * math.cos(a), v + 0.56 * math.sin(a), zT)], 0.012, 4))
    return zT


def grande_pile(lot, M, x, y, n):
    """Grande pile d'isolateurs : socle à gradins, bride, disques, couronne de garde, pointe. Rend le sommet."""
    lot.put(M["dalle"], G.boite((x, y, 0.1), (0.95, 0.95, 0.2), 0.2))
    lot.put(M["acier"], G.prisme([(x - 0.33, y - 0.33), (x + 0.33, y - 0.33), (x + 0.33, y + 0.33), (x - 0.33, y + 0.33)], 0.2, 0.46, top_scale=0.72))
    for (dx, dy) in ((-0.28, -0.28), (0.28, -0.28), (0.28, 0.28), (-0.28, 0.28)):
        lot.put(M["riv"], G.rivets_le_long([((x + dx, y + dy, 0.205), (0, 0, 1))], 0.04, 0.03))
    z1 = E.pile_iso(lot, M, x, y, 0.53, n, 0.29, 0.165)
    for t in (0.33, 0.66):                                              # bagues de reprise
        z = 0.53 + 0.165 * n * t
        lot.put(M["acier"], G.tour([(z - 0.02, 0.17), (z + 0.02, 0.17)], 16, "z", (x, y, 0.0)))
    lot.put(M["bobine"], E.tore(0.3, 0.035, (x, y, z1 - 0.3), "z", 28, 8))
    lot.put(M["alu"], E.tore(0.27, 0.07, (x, y, z1 + 0.04), "z", 30, 10))
    for k in range(3):
        a = TAU * k / 3 + 0.4
        lot.put(M["acier"], G.tube([(x, y, z1), (x + 0.27 * math.cos(a), y + 0.27 * math.sin(a), z1 + 0.04)], 0.014, 4))
    lot.put(M["acier"], G.tube([(x, y, z1), (x, y, z1 + 0.34)], 0.018, 5))
    lot.put(M["alu"], G.sphere((x, y, z1 + 0.36), 0.04, 8, 4))
    return (x, y, z1 + 0.36)


def pylone(lot, M, x, y, h):
    """Pylône treillis à isolateurs, croisillons, 2 consoles (lignes fines)."""
    b = 0.34
    cs = [(-b, -b), (b, -b), (b, b), (-b, b)]
    for (dx, dy) in cs:
        lot.put(M["acier"], G.tube([(x + dx, y + dy, 0.0), (x + dx * 0.25, y + dy * 0.25, h)], 0.024, 4))
        lot.put(M["pierre"], G.boite((x + dx, y + dy, 0.06), (0.2, 0.2, 0.12)))
    n = 7
    for i in range(n):
        z0, z1 = h * i / n, h * (i + 1) / n
        k0, k1 = 1.0 - 0.75 * i / n, 1.0 - 0.75 * (i + 1) / n
        for j in range(4):
            a, c_ = cs[j], cs[(j + 1) % 4]
            lot.put(M["acier"], G.tube([(x + a[0] * k0, y + a[1] * k0, z0), (x + c_[0] * k1, y + c_[1] * k1, z1)], 0.009, 3))
            lot.put(M["acier"], G.tube([(x + a[0] * k1, y + a[1] * k1, z1), (x + c_[0] * k1, y + c_[1] * k1, z1)], 0.009, 3))
    ends = []
    for (z, w) in ((h * 0.92, 0.6), (h * 0.72, 0.8)):
        lot.put(M["acier"], G.tube([(x - w, y, z), (x + w, y, z)], 0.018, 4))
        lot.put(M["acier"], G.tube([(x - w, y, z), (x, y, z + 0.28)], 0.01, 3))
        lot.put(M["acier"], G.tube([(x + w, y, z), (x, y, z + 0.28)], 0.01, 3))
        for s in (-1, 1):
            zb = z - 0.3
            lot.put(M["pierre_cer"], G.tour([p for k in range(4) for p in ((zb + 0.07 * k, 0.03), (zb + 0.07 * k + 0.02, 0.055), (zb + 0.07 * k + 0.05, 0.03))], 10, "z", (x + s * w, y, 0.0)))
            ends.append((x + s * w, y, zb))
    return ends


def deco_nacelle(lot, M, R, s):
    """Tuyères rebobinées en moteurs : spires de cuivre, joues, boîte à bornes."""
    rr = R + 0.012
    for k in range(13):
        x = -1.0 - k * 0.032
        lot.put(M["bobine"], G.tour([(x + 0.018 * math.cos(TAU * j / 6), rr + 0.018 + 0.018 * math.sin(TAU * j / 6)) for j in range(7)], 32, "x"))
    for x in (-0.97, -1.42):
        lot.put(M["acier"], G.tour([(x - 0.02, rr + 0.005), (x - 0.02, rr + 0.075), (x + 0.02, rr + 0.075), (x + 0.02, rr + 0.005)], 32, "x"))
    lot.put(M["acier"], G.boite((-1.75, 0.0, rr + 0.09), (0.32, 0.26, 0.18)))
    for dy in (-0.07, 0.07):
        lot.put(M["pierre_cer"], G.tour([(rr + 0.18, 0.03), (rr + 0.2, 0.05), (rr + 0.23, 0.03), (rr + 0.26, 0.05), (rr + 0.3, 0.02)], 10, "z", (-1.75, dy, 0.0)))


def build(S, lot0):
    M = matieres(S)
    lot = E.LotK(lot0)
    P = C.Pose(**E.POSE)
    r = G.Rnd(6066)
    niv = P.niv
    mc = E.coque(M, COQUE)
    pieds = E.carcasse(lot, M, P, r, mc, deco_nac=deco_nacelle)
    E.menus_coque(lot, M, P, G.Rnd(6089))
    E.grille_coque(lot, M, P, ((3.0, math.pi / 2 - 0.7, 0.32, 0.4), (3.9, math.pi / 2 + 0.95, 0.26, 0.36), (-2.9, math.pi / 2 + 0.2, 0.3, 0.5)))
    E.mat_nez(lot, M, P)
    zp = E.Z_PONT
    rarc = G.Rnd(6600)

    # ======================================================================== le radier (dalles décalées) : dessous de tout
    for (cx, cy, sx, sy, rz, h) in ((-4.3, -2.6, 2.4, 1.9, 0.2, 0.05), (-0.45, -2.75, 6.0, 2.3, -0.1, 0.06), (3.75, -2.6, 2.3, 2.1, -0.22, 0.05)):
        lot.put(M["dalle"], G.boite((cx, cy, h / 2), (sx, sy, h), rz))
        lot.put(M["hazard"], G.boite(G.add((cx, cy, 0.06), G.rot_z((0.0, -sy / 2, 0.0), rz)), (sx * 0.45, 0.05, 0.08), rz))

    # ======================================================================== la tour, dans la cage
    lot.xf = niv
    lot.put(M["dalle"], G.boite((-0.15, 0.0, zp - 0.03), (4.9, 2.5, 0.06)))
    for u in (-2.5, -1.4, -0.3, 0.8, 1.9):
        for v in (-1.15, 0.0, 1.15):
            lot.put(M["poutre"], G.tour([(0.0, 0.07), (zp - 0.06, 0.065)], 8, "z", (u, v, 0.0), cap1=True))
    u_t, v_t = -0.15, -0.02
    zT = tour_centrale(lot, M, u_t, v_t)
    # barres de cuivre du tambour vers les jambes des côtes
    C.tuyau(lot, M["cuivre"], M["acier"], [(0.95, -0.72, 1.0), (1.6, -1.05, 1.0), (1.6, -1.05, 0.55)], 0.04, rb=0.1, pas_bride=0.35)
    C.tuyau(lot, M["cuivre"], M["acier"], [(-1.05, -0.5, 0.85), (-1.7, -1.05, 0.85), (-1.7, -1.05, 0.55)], 0.04, rb=0.1, pas_bride=0.35)
    lot.xf = None
    ct = niv((u_t, v_t, zT))

    # ======================================================================== les 2 hautes piles sur les côtés, l'arc qui les relie
    a = grande_pile(lot, M, -3.35, -2.2, 16)
    b = grande_pile(lot, M, 3.05, -2.55, 18)
    E.eclair(lot, M["arc"], G.add(a, (0.02, 0, 0.0)), G.add(b, (-0.02, 0, 0.0)), rarc, 19, 0.15, 0.011, 3)
    for (d0, d1) in (((-0.62, 0.05, 0.0), (-0.98, 0.0, -0.42)), ((0.64, -0.05, 0.02), (1.02, 0.02, 0.4))):      # aigrettes du tore
        E.eclair(lot, M["arc"], G.add(ct, d0), G.add(ct, d1), rarc, 4, 0.05, 0.006, 1)

    # ======================================================================== la salle des machines, de biais ; transformateurs ; grosse bobine
    ra = G.Rnd(6303)
    cS, rS = (-0.3, -2.3, 0.0), -0.14
    with E.dans(lot, cS, rS):
        salle(lot, M, ra)
    tA = transfo(lot, M, ra, (-1.85, -3.55, 0.0), 0.12, 0.9)
    tB = transfo(lot, M, ra, (1.5, -3.75, 0.0), -0.2, 1.05)
    bobine_axe(lot, M, (-0.1, -3.62, 0.56), 0.95, 0.38, rz=-0.08)
    with E.dans(lot, (-0.1, -3.62, 0.0), -0.08):
        for x in (-0.5, 0.5):
            lot.put(M["poutre"], G.boite((x, 0.0, 0.18), (0.14, 0.78, 0.36)))
        lot.put(M["acier"], G.boite((0.0, 0.0, 0.08), (1.45, 0.92, 0.1)))
        for (x, y) in ((-0.68, -0.42), (0.68, -0.42), (-0.68, 0.42), (0.68, 0.42)):
            lot.put(M["caoutchouc"], G.tour([(-0.04, 0.09), (0.04, 0.09)], 10, "y", (x, y, 0.08), cap0=True, cap1=True))
    for (p, q, fl) in ((tA[2], (-0.1, -3.62, 0.98), 0.08), (tB[0], (-0.1, -3.62, 0.98), 0.1), (tA[0], (-3.35, -2.2, 1.0), 0.12), (tB[2], (3.05, -2.55, 1.05), 0.1)):
        lot.put(M["cuivre"], G.tube(G.chainette(p, q, fl, 12), 0.016, 5))
    lot.put(M["pierre_cer"], G.tour([(0.92, 0.05), (0.95, 0.09), (0.99, 0.05), (1.02, 0.08), (1.06, 0.03)], 10, "z", (-0.1, -3.62, 0.0)))

    # ======================================================================== derrière : condensateurs de 3 hauteurs, pylône, lignes
    cC, rC = (2.75, 2.65, 0.0), 0.16
    with E.dans(lot, cC, rC):
        lot.put(M["dalle"], G.boite((0.0, 0.0, 0.09), (3.2, 1.7, 0.18)))
        lot.put(M["poutre"], G.boite((0.0, -0.8, 0.26), (3.1, 0.08, 0.16)))
        crt = G.Rnd(6401)
        for (x, y, R, h, n) in ((-1.1, -0.28, 0.27, 1.25, 8), (-0.5, -0.32, 0.3, 1.0, 6), (0.08, -0.25, 0.26, 1.55, 7), (0.7, -0.34, 0.31, 1.15, 5), (1.22, -0.2, 0.24, 1.4, 9),
                              (-0.85, 0.4, 0.3, 1.7, 7), (-0.15, 0.42, 0.33, 1.35, 6), (0.55, 0.4, 0.28, 1.9, 7), (1.15, 0.45, 0.27, 1.25, 8)):
            lot.put(M["vdg"] if crt.f() < 0.55 else M["acier_clair"], G.tour([(0.18, R), (h, R), (h + 0.05, R * 0.9)], 22, "z", (x, y, 0.0), cap1=True))
            for t in (0.3, 0.7):
                lot.put(M["acier"], G.tour([(h * t - 0.02, R + 0.008), (h * t + 0.02, R + 0.008)], 22, "z", (x, y, 0.0)))
            E.pile_iso(lot, M, x, y, h + 0.05, n % 4 + 2, R * 0.48, 0.085)
        lot.put(M["bobine"], G.tube([(-1.1, -0.28, 1.68), (0.08, -0.25, 1.82), (0.7, -0.34, 1.5), (1.22, -0.2, 1.72)], 0.018, 5))
    ends = pylone(lot, M, 5.0, 2.6, 3.55)
    for (p, q, fl) in ((ends[0], P.xf((3.9, 0.3, C.z_dessus(3.9) + 0.04)), 0.35), (ends[2], (3.5, 3.0, 1.9), 0.28), (ends[1], (5.95, 1.9, 2.15), 0.2), (ends[3], (5.95, 3.2, 1.7), 0.2)):
        lot.put(M["noir"], G.tube(G.chainette(p, q, fl, 16), 0.008, 3))
    # poteaux à isolateurs le long du front, câbles pendants
    ps = [(-5.2, -3.45), (-3.45, -3.92), (-0.1, -4.25), (3.1, -3.95), (4.7, -3.4)]
    tp = []
    for (x, y) in ps:
        lot.put(M["poutre"], G.tour([(0.0, 0.04), (1.05, 0.03)], 8, "z", (x, y, 0.0), cap1=True))
        lot.put(M["acier"], G.tube([(x - 0.17, y, 0.98), (x + 0.17, y, 0.98)], 0.012, 4))
        for s in (-1, 1):
            lot.put(M["pierre_cer"], G.tour([(0.98, 0.022), (1.0, 0.04), (1.03, 0.022), (1.05, 0.036), (1.08, 0.015)], 8, "z", (x + s * 0.17, y, 0.0)))
        tp.append((x, y, 1.08))
    for i in range(len(tp) - 1):
        for s in (-1, 1):
            lot.put(M["noir"], G.tube(G.chainette(G.add(tp[i], (s * 0.17, 0, 0)), G.add(tp[i + 1], (s * 0.17, 0, 0)), 0.16, 12), 0.006, 3))
    # ======================================================================== sud-ouest : tourets, caisses d'isolateurs, armoire ; sud-est : atelier
    with E.dans(lot, (-4.55, -2.75, 0.0), 0.22):
        for (x, y, R) in ((-0.55, 0.0, 0.34), (0.15, 0.25, 0.28)):
            for dy in (-0.14, 0.14):
                lot.put(M["bois"], G.tour([(dy - 0.02, R), (dy + 0.02, R)], 22, "y", (x, y, R), cap0=True, cap1=True))
            lot.put(M["bobine"], G.tour([(-0.12, R * 0.72), (0.12, R * 0.72)], 18, "y", (x, y, R)))
        for (x, y, s_, n) in ((0.7, -0.35, 0.34, 3), (0.32, -0.55, 0.3, 2)):
            lot.put(M["bois"], G.boite((x, y, s_ * 0.4 + 0.05), (s_, s_, s_ * 0.8), 0.3))
            E.pile_iso(lot, M, x, y, s_ * 0.8 + 0.08, n, 0.08, 0.075)
        lot.put(M["acier"], G.boite((-0.15, -0.6, 0.28), (0.3, 0.2, 0.46)))
        lot.put(M["voyant"], G.boite((-0.1, -0.705, 0.42), (0.03, 0.01, 0.03)))
    with E.dans(lot, (4.15, -2.55, 0.0), -0.2):
        lot.put(M["vdg2"], G.boite((0.0, 0.0, 0.42), (1.0, 0.7, 0.72)))
        lot.put(M["toit"], G.prisme([(-0.6, -0.42), (0.6, -0.42), (0.6, 0.42), (-0.6, 0.42)], 0.78, 0.94, top_scale=0.78))
        C.evente(lot, M["acier"], M["noir"], (0.15, 0.0, 0.94), 0.2, 0.34, 3, 0.0, 0.1)
        C.hublot(lot, "octo", M["acier"], M["verre_sombre"], (-0.2, -0.36, 0.5), (0.0, -1.0, 0.0), 0.075)
        lot.put(M["noir"], G.boite((0.22, -0.36, 0.42), (0.32, 0.03, 0.56)))
        for (dx, n) in ((-0.32, 3), (0.32, 4)):
            E.pile_iso(lot, M, dx, 0.0, 0.94, n, 0.08, 0.08)

    # ======================================================================== conduites, flexibles, câbles
    pv = niv
    C.tuyau(lot, M["conduit"], M["acier"], [(-3.3, -1.35, 0.55), (-3.3, -2.0, 0.55)], 0.06, rb=0.1)
    C.tuyau(lot, M["conduit"], M["acier"], [(-4.0, -2.15, 0.7), (-2.55, -2.05, 0.7), (-2.25, -1.95, 0.7)], 0.07, rb=0.14, pas_bride=0.45)
    C.tuyau(lot, M["cuivre"], M["acier"], [(-5.2, -3.3, 0.2), (-3.1, -3.95, 0.2), (0.0, -4.12, 0.2), (3.25, -3.72, 0.2)], 0.035, rb=0.14, pas_bride=0.55)
    C.tuyau(lot, M["conduit"], M["acier"], [pv((1.95, -1.15, 0.95)), pv((2.55, -1.4, 0.95)), (2.75, -2.15, 0.95), (2.85, -2.3, 0.75)], 0.05, rb=0.12, pas_bride=0.45)
    C.tuyau(lot, M["acier"], M["acier"], [(0.7, 2.7, 0.7), (0.2, 2.7, 0.7), (0.2, 1.95, 0.45)], 0.06, rb=0.13)
    for (a_, b_, c_) in (((-4.55, -1.4, 1.15), (-4.8, -1.75, 0.3), (-4.75, -2.5, 0.38)), ((-3.6, -1.15, 1.15), (-3.65, -1.55, 0.4), (-3.2, -2.0, 0.4)),
                         (pv((2.45, -0.9, 1.2)), (2.85, -1.45, 0.5), (3.3, -2.1, 0.5)), ((0.3, 2.2, 0.3), (0.55, 1.75, 0.1), (1.1, 1.85, 0.25)),
                         ((-2.2, -1.5, 0.9), (-2.3, -1.65, 0.3), (-1.7, -1.8, 0.5)), ((3.9, -2.25, 0.3), (3.6, -1.9, 0.08), (3.2, -2.2, 0.25))):
        C.flexible(lot, M["caoutchouc"], [a_, b_, c_], 0.046)
    fx = [(pieds[0][1], pieds[1][1], 0.4), (pieds[2][1], pieds[3][1], 0.34), (pieds[1][1], pieds[2][1], 0.45)]
    fx += [(P.xf((E.COTES[i] - 0.05, 0.25, C.z_dessus(E.COTES[i]) + 0.4)), P.xf((E.COTES[i + 1] - 0.05, 0.25, C.z_dessus(E.COTES[i + 1]) + 0.4)), 0.3) for i in (0, 2)]
    fx += [(P.xf((2.4, -0.9, 0.5)), P.xf((3.8, -0.75, 0.35)), 0.18), (P.xf((-3.3, -0.9, 0.3)), P.xf((-2.3, -1.05, 0.1)), 0.22)]
    ra2 = G.Rnd(6305)
    for (a_, b_, fl) in fx:
        C.faisceau(lot, M["rouge"], M["noir"], a_, b_, fl, 3, 0.011, 0.028, ra2)
    for x in (-3.0, 1.4):
        p = P.xf((x, 0.0, C.z_dessus(x) + 0.25))
        lot.put(M["acier"], G.tube([p, G.add(p, (0.0, 0.0, 0.8))], 0.012, 4))
        lot.put(M["pierre_cer"], G.tour([(p[2] + 0.05, 0.03), (p[2] + 0.09, 0.055), (p[2] + 0.13, 0.03), (p[2] + 0.17, 0.05), (p[2] + 0.21, 0.02)], 10, "z", (p[0], p[1], 0.0)))

    # ======================================================================== sol : butte, flaques, berceaux, débris
    nez = P.xf((5.0, 0.0, -0.3))
    lot.put(M["boue"], G.butte_polaire((nez[0] + 0.15, nez[1] - 0.1, 0.0), 1.05, 1.5, 0.62, r, 12, 48, 0.3, 0.14))
    for (x, y, a_, b_) in ((nez[0] + 0.9, nez[1] - 1.2, 0.45, 0.35), (nez[0] - 0.4, nez[1] + 1.25, 0.5, 0.3)):
        lot.put(M["boue"], G.butte_polaire((x, y, 0.0), a_, b_, 0.2, r, 6, 28, 0.3, 0.2))
    for (x, y) in ((-3.4, -1.2), (-3.6, 1.95), (-4.5, -1.75), (-4.6, 2.0)):
        for k in range(4):
            lot.put(M["poutre"], G.boite((x, y, 0.09 + 0.17 * k), (0.95 if k % 2 == 0 else 0.22, 0.22 if k % 2 == 0 else 0.95, 0.15), -0.1 + 0.06 * k))
        lot.put(M["acier"], G.tour([(0.7, 0.07), (1.05, 0.06)], 8, "z", (x, y, 0.0), cap1=True))
    E.debris(lot, M, [("plaque", -5.75, -1.3, 0.55, 0.38, 0.4), ("plaque", 5.1, -3.75, 0.5, 0.32, -0.7), ("plaque", -5.5, 3.3, 0.6, 0.42, 0.9),
                      ("fut", 5.45, -1.75, 1.4), ("fut", -5.8, -3.8, 0.3), ("caisse", -5.55, 1.5, 0.3, 0.3, -0.2), ("caisse", 1.3, 4.0, 0.32, 0.3, 0.7), ("tuyau", 3.95, -4.2, 0.9, 0.05, 0.25),
                      ("tuyau", -2.75, -4.3, 0.7, 0.04, -0.15), ("pneu", 1.25, -4.42, 0.17), ("plaque", 2.6, 4.0, 0.5, 0.3, 0.3)])
    E.ferraille(lot, M, G.Rnd(6306), 24, (-5.9, 5.9, -4.5, 3.9), 4.6, 3.9)
    return {"pose": E.POSE}
