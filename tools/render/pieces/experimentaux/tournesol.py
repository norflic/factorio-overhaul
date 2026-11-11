"""TOURNESOL, expérimental de l'âge 14 (Orbite) : un miroir de 42 tuiles porté par 3 échasses, toujours tourné vers le soleil. Lot EXP2, 1/11.
Bible : ailes de panneaux dorés, paraboles, feuille d'or froissée, cellules bleu nuit, balises rouges. Il ne vise pas : il capte. Les miroirs regardent le soleil (l'ouest
de nos ombres), le faisceau part du foyer vers la cible : une image pour toutes les directions, sa logique même. La nuit, il ne tire pas.
"""
import math

import fam as F
import geo as G
import greb as R
import mat as MT

GROUPES = {"foyer": ("to_f",), "balises": ("to_b",), "cellules": ("to_c",)}
C_TETE = (0.0, 0.0, 39.0)
# axe du miroir : vers le soleil (fo_calib : élévation 48°, ouest), un peu vers la caméra pour qu'on voie la face
AXE = G.norm((-0.6, -0.33, 0.73))
R_MIR = 21.0


def repere():
    n = AXE
    e1 = G.norm(G.cross(n, (0.0, 1.0, 0.0)))
    e2 = G.cross(n, e1)
    return e1, e2, n


def sur_miroir(u, v, h=0.0):
    """Point du miroir : coordonnées polaires (rayon, angle) dans le plan, parabole douce."""
    e1, e2, n = repere()
    z = 0.0105 * u * u + h
    return G.add(G.add(C_TETE, G.mul(n, z + 2.6)), G.add(G.mul(e1, u * math.cos(v)), G.mul(e2, u * math.sin(v))))


def carreau(u0, u1, v0, v1, ep, gonfle=0.0):
    """Petit panneau du miroir, fermé, posé sur la parabole."""
    rings = []
    for u in (u0, (u0 + u1) / 2, u1):
        ring = []
        for v in (v0, (v0 + v1) / 2, v1):
            ring.append(sur_miroir(u, v, ep + gonfle))
        for v in (v1, (v0 + v1) / 2, v0):
            ring.append(sur_miroir(u, v, 0.0))
        rings.append(ring)
    return G.loft(rings, True, True)


def matieres(S):
    surf = F.surf_de("to")
    F.patine(ta=0.22, ra=0.25, ec=0.32, nu_k=1.3, ec_col=(0.09, 0.05, 0.015), sans=("or", "cell"))
    M = {}
    M["or"] = surf("or", (0.78, 0.53, 0.14), rough=0.27, met=0.55, tole=(1.6, 1.2), joint=0.5, joint_l=0.012, var=0.2, coulures=0.3, rouille=(0.2, 0.1, 0.03), usure=0.5, nu=(0.98, 0.84, 0.46), crasse=0.6,
                 crasse_col=(0.03, 0.016, 0.005), relief=0.8, graine=1)
    M["or2"] = surf("or2", (0.55, 0.32, 0.07), rough=0.33, met=0.55, tole=(0.9, 0.7), joint=0.5, joint_l=0.02, var=0.26, coulures=0.4, rouille=(0.16, 0.08, 0.02), usure=0.5, nu=(0.86, 0.68, 0.3), crasse=0.7,
                  crasse_col=(0.025, 0.013, 0.004), relief=0.8, graine=2)
    M["miroir"] = surf("miroir", (0.92, 0.82, 0.52), rough=0.13, met=0.86, coulures=0.15, rouille=(0.3, 0.18, 0.06), usure=0.3, nu=(1.0, 0.95, 0.75), crasse=0.35, crasse_col=(0.05, 0.03, 0.01), graine=3)
    M["cell"] = surf("cell", (0.02, 0.035, 0.11), rough=0.2, met=0.3, tole=(0.5, 0.5), joint=2.2, joint_l=0.03, var=0.18, usure=0.2, nu=(0.2, 0.28, 0.5), crasse=0.3, crasse_col=(0.005, 0.008, 0.02), relief=0.2, graine=4)
    M["blanc"] = surf("blanc", (0.6, 0.58, 0.52), rough=0.38, met=0.1, tole=(1.4, 0.8), joint=0.4, joint_l=0.02, var=0.1, coulures=0.7, rouille=(0.09, 0.07, 0.045), usure=0.45, nu=(0.82, 0.8, 0.75), crasse=0.8,
                    crasse_col=(0.022, 0.018, 0.012), relief=0.5, graine=5)
    M["acier"] = surf("acier", (0.11, 0.1, 0.095), rough=0.42, met=0.7, coulures=0.4, rouille=(0.09, 0.05, 0.02), usure=0.65, nu=(0.5, 0.46, 0.4), crasse=0.7, crasse_col=(0.006, 0.005, 0.004), graine=6)
    M["noir"] = surf("noir", (0.02, 0.019, 0.02), rough=0.5, met=0.4, usure=0.4, nu=(0.2, 0.19, 0.2), crasse=0.6, crasse_col=(0.003, 0.003, 0.003), graine=7)
    M["verre"] = MT.verre("to_verre", col=(0.012, 0.012, 0.02), reflet=(0.2, 0.2, 0.3))
    M["foyer"] = F.trio(S, "to_f", (1.0, 0.72, 0.28), 1.1, clair=(1.0, 0.97, 0.86))
    M["balise"] = F.trio(S, "to_b", (1.0, 0.05, 0.03), 1.1, clair=(1.0, 0.55, 0.45))
    M["cellule_l"] = S.mat_emissive("to_c", (0.1, 0.32, 1.0), strength=0.55, base=(0.01, 0.02, 0.08), main_scale=0.3, crust=(0.9, 0.7, 3))
    M["hublot"] = MT.lumiere(S, "to_b_h", (1.0, 0.82, 0.5), 1.05, main=0.25)
    return M


def miroir(lot, M, r):
    """Couronnes de carreaux qui ne se touchent pas : or froissé, miroir, cellules ; rayons de nervures dessous ; fines balises au bord."""
    couronnes = [(4.4, 7.4, 10), (7.6, 10.8, 14), (11.0, 14.4, 18), (14.6, 17.8, 22), (18.0, R_MIR, 28)]
    for c, (u0, u1, n) in enumerate(couronnes):
        for k in range(n):
            v0 = G.TAU * k / n + 0.008 + c * 0.14
            v1 = v0 + G.TAU / n - 0.022
            x = r.f()
            if c % 2 == 1 and x < 0.33:
                lot.put(M["cell"], carreau(u0, u1, v0, v1, 0.12))
                lot.put(M["cellule_l"], carreau(u0 + (u1 - u0) * 0.3, u0 + (u1 - u0) * 0.7, v0 + (v1 - v0) * 0.3, v0 + (v1 - v0) * 0.7, 0.14))
            else:
                # chaque carreau : cadre sombre puis 2 à 4 pétales d'or inégaux
                lot.put(M["acier"], carreau(u0, u1, v0, v1, 0.06))
                nb = r.i(2, 4)
                cu = sorted([0.0, 1.0] + [r.f(0.2, 0.8) for _ in range(nb - 1)])
                for j in range(len(cu) - 1):
                    a0, a1 = v0 + (v1 - v0) * cu[j] + 0.006, v0 + (v1 - v0) * cu[j + 1] - 0.006
                    x2 = r.f()
                    m = M["miroir"] if x2 < 0.45 else M["or"] if x2 < 0.82 else M["or2"]
                    lot.put(m, carreau(u0 + 0.1, u1 - 0.1, a0, a1, r.f(0.1, 0.24), r.f(0.0, 0.08)))
    # PÉTALES : 26 triangles d'or au-delà du bord, de longueurs inégales ; c'est eux qui font le tournesol et non une parabole de plus
    for k in range(26):
        v0 = G.TAU * k / 26.0
        v1 = v0 + G.TAU / 26.0 - 0.015
        vm = (v0 + v1) / 2.0
        L = R_MIR + 4.2 + 2.2 * ((k * 7) % 3) / 2.0
        a, b, c = sur_miroir(R_MIR - 0.1, v0, 0.04), sur_miroir(R_MIR - 0.1, v1, 0.04), sur_miroir(L, vm, 0.3)
        m = M["or"] if k % 2 else M["miroir"]
        n_loc = G.norm(G.cross(G.sub(b, a), G.sub(c, a)))
        e = G.mul(n_loc, 0.09)
        v = [G.add(a, e), G.add(b, e), G.add(c, e), G.sub(a, e), G.sub(b, e), G.sub(c, e)]
        lot.put(m, (v, [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], [(q[0], q[1]) for q in v]))
        lot.put(M["acier"], G.tube([sur_miroir(R_MIR - 0.1, vm, 0.1), sur_miroir(L - 0.6, vm, 0.34)], 0.07, 5))
    # nervures et cerclages
    e1, e2, n = repere()
    for k in range(14):
        v = G.TAU * k / 14
        pts = [sur_miroir(4.2 + (R_MIR - 4.2) * t / 8.0, v, -0.08) for t in range(9)]
        lot.put(M["acier"], G.tube(pts, 0.14, 6))
    for u in (4.3, 7.5, 10.9, 14.5, 17.9, R_MIR + 0.1):
        pts = [sur_miroir(u, G.TAU * t / 96.0, 0.02) for t in range(97)]
        lot.put(M["or2"] if u > R_MIR else M["acier"], G.tube(pts, 0.22 if u > R_MIR else 0.1, 6))
    # balises rouges, bord, 12 mâts
    for k in range(12):
        v = G.TAU * (k + 0.5) / 12
        p = sur_miroir(R_MIR + 0.2, v, 0.0)
        q = G.add(p, G.mul(G.norm(G.add(G.mul(n, 0.8), G.add(G.mul(e1, 0.5 * math.cos(v)), G.mul(e2, 0.5 * math.sin(v))))), 2.2))
        lot.put(M["acier"], G.tube([p, q], 0.07, 6))
        lot.put(M["balise"][1], G.sphere(q, 0.22, 8, 4))
        lot.put(M["balise"][2], G.sphere(q, 0.1, 8, 4))
    # dos : plateau-poutres vu sous le bord, côté sud
    for k in range(9):
        v = G.TAU * k / 9 + 0.2
        a = sur_miroir(R_MIR * 0.92, v, -0.15)
        lot.put(M["acier"], G.tube([G.add(C_TETE, G.mul(n, -1.0)), a], 0.2, 6))
    lot.put(M["or2"], G.oriente(G.tour([(-3.0, 0.5), (-2.2, 3.0), (-0.6, 4.2), (2.8, 4.5)], 40, "z"), C_TETE, n))


def foyer(lot, M, r):
    """Bras à 3 tiges du miroir au foyer ; la boule de lumière à 3 couches, sa cage."""
    e1, e2, n = repere()
    F_ = G.add(C_TETE, G.mul(n, 15.0))
    for k in range(3):
        v = G.TAU * k / 3 + 0.5
        a = sur_miroir(11.0, v, 0.1)
        lot.put(M["blanc"], G.tube([a, G.add(F_, G.mul(n, -1.2))], 0.26, 8))
    for (rr, m) in ((1.6, M["foyer"][0]), (1.15, M["foyer"][1]), (0.65, M["foyer"][2])):
        lot.put(m, G.sphere(F_, rr, 20, 10))
    for k in range(5):
        lot.put(M["acier"], G.oriente(G.tour([(-0.1, 2.0), (0.1, 2.0), (0.1, 1.85), (-0.1, 1.85), (-0.1, 2.0)], 40, "z"), F_, G.norm((math.sin(k * 0.9), math.cos(k * 1.3), math.sin(k * 2.1) + 0.2))))


def echasses(lot, M, r):
    """3 échasses télescopiques (en jeu : 3 pattes) ; fût à étages, cuves dorées, nacelle, escalier."""
    z = C_TETE[2]
    # fût central de la tête : tambour, nacelle à baies
    Pf = F.Prof([(z - 6.5, 1.7), (z - 5.0, 2.7), (z - 2.0, 3.5), (z, 4.0), (z + 1.2, 3.9)], lisse=False)
    lot.put(M["acier"], G.tour(Pf.pts, 32, "z"))
    F.blindage(lot, [M["blanc"], M["or2"], M["blanc"]], Pf, z - 5.8, z + 0.8, 4, 10, r, e=(0.06, 0.3), vis=0.75, poids=[0.5, 0.25, 0.25], Mdet=M["acier"])
    F.baies(lot, M["acier"], M["hublot"], M["verre"], Pf, z - 1.2, 40, r, ouvert=0.7, vis=0.65)
    F.baies(lot, M["acier"], M["hublot"], M["verre"], Pf, z - 3.3, 30, r, ouvert=0.6, vis=0.65)
    F.anneau(lot, M["acier"], z - 3.9, 2.6, 4.0, 0.14, n=64)
    F.rail(lot, M["acier"], 3.9, z - 3.83, n=32, vis=0.65)
    # cuves sphériques dorées sous le tambour
    for k in range(5):
        a = G.TAU * k / 5 - 0.7
        c = (3.9 * math.cos(a), 3.9 * math.sin(a), z - 6.8)
        lot.put(M["or"], G.sphere(c, 1.5, 20, 10))
        lot.put(M["acier"], G.tour([(c[2] - 0.06, 1.55), (c[2] + 0.06, 1.55)], 20, "z", (c[0], c[1], 0.0), cap0=True, cap1=True))
    # 3 échasses, très longues
    pieds = [(-math.pi / 2, 19.0), (-math.pi / 2 + 2.15, 22.0), (-math.pi / 2 - 2.15, 22.0)]
    for (a, ra) in pieds:
        ca, sa = math.cos(a), math.sin(a)
        ya = sa * ra * 1.25
        h = (3.0 * ca, 3.0 * sa, z - 4.5)
        g = (ca * ra, ya, 0.2)
        k_ = (ca * ra * 0.72, sa * ra * 0.9, 18.5)
        lot.put(M["blanc"], G.tube([h, k_], 0.95, 12))
        lot.put(M["acier"], G.tube([G.add(h, (0, 0, -0.4)), G.add(k_, (0, 0, -0.4))], 0.2, 6))
        lot.put(M["acier"], G.tube([k_, g], 0.58, 10))
        lot.put(M["or2"], G.sphere(k_, 1.05, 14, 7))
        lot.put(M["acier"], G.tour([(k_[2] - 0.3, 1.14), (k_[2] + 0.3, 1.14)], 14, "z", (k_[0], k_[1], 0.0), cap0=True, cap1=True))
        for t in (0.3, 0.55, 0.8):
            q = G.lerp(h, k_, t)
            lot.put(M["or"], G.oriente(G.tour([(-0.22, 0.7), (0.22, 0.7)], 10, "z", cap0=True, cap1=True), q, G.sub(k_, h)))
        # pied : plaque, griffes, tige hydraulique
        lot.put(M["acier"], G.prisme(R.octo((g[0], g[1]), 1.8, 8), 0.0, 0.7, top_scale=0.7))
        lot.put(M["or2"], G.prisme(R.octo((g[0], g[1]), 1.1, 8), 0.7, 1.35, top_scale=0.55))
        lot.put(M["balise"][1], G.sphere((g[0], g[1], 1.45), 0.2, 8, 4))
    # fût central et nacelle à mi-hauteur : ce qui donne l'échelle sous le miroir, cuves dorées, coursive, escalier
    lot.put(M["acier"], G.tour([(z - 7.0, 1.3), (17.0, 1.05), (15.5, 0.0)], 20, "z", cap0=False))
    Pn = F.Prof([(20.5, 1.3), (21.3, 3.2), (23.0, 4.3), (25.2, 4.6), (26.5, 3.9), (27.3, 1.6)])
    lot.put(M["noir"], G.tour(Pn.pts, 32, "z"))
    F.blindage(lot, [M["blanc"], M["or2"], M["blanc"]], Pn, 21.4, 26.4, 3, 12, r, e=(0.06, 0.28), vis=0.7, poids=[0.55, 0.2, 0.25], Mdet=M["acier"])
    F.baies(lot, M["acier"], M["hublot"], M["verre"], Pn, 24.2, 44, r, ouvert=0.75, vis=0.6)
    F.anneau(lot, M["acier"], 22.6, 2.8, 5.7, 0.14, n=64)
    F.rail(lot, M["acier"], 5.6, 22.68, n=32, vis=0.65)
    for k in range(6):
        a = G.TAU * k / 6 - 0.3
        c = (5.5 * math.cos(a), 5.5 * math.sin(a), 20.8)
        lot.put(M["or"], G.sphere(c, 1.35, 18, 9))
        lot.put(M["acier"], G.tour([(c[2] - 0.05, 1.42), (c[2] + 0.05, 1.42)], 18, "z", (c[0], c[1], 0.0), cap0=True, cap1=True))
        lot.put(M["balise"][1], G.sphere((c[0], c[1], c[2] + 1.42), 0.14, 8, 4))
    for (a, ra) in pieds:
        lot.put(M["acier"], G.tube([(4.0 * math.cos(a), 4.0 * math.sin(a), 22.4), (math.cos(a) * ra * 0.72, math.sin(a) * ra * 0.9, 18.5)], 0.2, 8))
    # petites paraboles et ailes latérales de panneaux : la silhouette de l'âge, à gauche et à droite du fût
    for s in (-1, 1):
        for j in range(3):
            x0 = s * (5.0 + 3.3 * j)
            x1 = x0 + s * 3.1
            lot.put(M["or2"] if j % 2 else M["cell"], G.boite(((x0 + x1) / 2, 0.0, z - 7.4 + j * 0.45), (3.1, 2.2, 0.1), ry=-s * 0.12))
            lot.put(M["acier"], G.boite(((x0 + x1) / 2, -1.14, z - 7.4 + j * 0.45), (3.1, 0.06, 0.16)))
        lot.put(M["acier"], G.tube([(s * 3.4, 0.0, z - 7.4), (s * 15.0, 0.0, z - 6.1)], 0.13, 6))
    p = (0.0, -4.0, z - 8.0)
    lot.put(M["blanc"], G.oriente(G.tour([(0.0, 0.0), (0.25, 1.0), (0.7, 1.9)], 24, "z"), p, (0.35, -0.75, 0.6)))
    lot.put(M["acier"], G.tube([(0.0, -2.2, z - 7.0), p], 0.12, 6))


def build(S, lot, variante="tournesol"):
    M = matieres(S)
    r = G.Rnd(1414)
    R.raz()
    miroir(lot, M, r)
    foyer(lot, M, r)
    echasses(lot, M, r)
    return dict(R.COMPTE)
