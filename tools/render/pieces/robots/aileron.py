"""AILERON (robot 8, âge 11 Titane, assaut rapide, classe M). Idée : un coureur : fuselage en flèche couché à l'horizontale, grand aileron dorsal triangulaire blanc, 2 ailerons plus petits en V à la queue, 2 longues
pattes en V qui courent très loin devant ; deux canons fins à plat sous le nez. Rien d'humanoïde : c'est un flèche qui court. Bible : alliage blanc #C9C6BE patiné, titane #8E9AA6, lignes #BFE6FF, luminance forte."""
import math

import formes as F
import gamme as Ga
import geo as G
import marionette as Mr

CAP = math.radians(-160.0)
Z0 = 1.62
PAS, BETA, LEVE = 2.2, 0.52, 0.36
L1, L2 = 1.0, 1.15
TABLE = (("g", (-0.2, 0.22, -0.1), (-0.14, 0.26), 0.0, (1.0, 0.0, 0.1)), ("d", (-0.2, -0.22, -0.1), (-0.14, -0.26), 0.5, (1.0, 0.0, 0.1)))


def matieres(S):
    import mat as MT
    Ga.patine(ta=0.1, ra=0.2, ec=0.12, nu_k=1.15, ec_col=(0.06, 0.06, 0.07))
    cr = (0.03, 0.03, 0.035)
    sf = F.surf
    M = {}
    M["blanc"] = sf("rb11_blanc", (0.56, 0.55, 0.5), rough=0.3, met=0.1, coulures=0.4, rouille=(0.16, 0.14, 0.12), usure=0.35, nu=(0.75, 0.74, 0.7), crasse=0.75, crasse_col=cr, tole=(0.7, 0.34), joint=0.55, joint_l=0.006, var=0.05, relief=0.5, graine=1101)
    M["blanc2"] = sf("rb11_blanc2", (0.62, 0.61, 0.56), rough=0.28, met=0.1, coulures=0.3, rouille=(0.18, 0.16, 0.14), usure=0.35, nu=(0.8, 0.79, 0.75), crasse=0.7, crasse_col=cr, graine=1102)
    M["titane"] = sf("rb11_titane", (0.26, 0.3, 0.35), rough=0.3, met=0.75, usure=0.5, nu=(0.62, 0.66, 0.72), crasse=0.65, crasse_col=cr, graine=1103)
    M["noir"] = sf("rb11_noir", (0.02, 0.022, 0.026), rough=0.5, met=0.3, usure=0.3, crasse=0.4, graine=1104)
    M["peint"] = sf("rb11_peint", (0.6, 0.6, 0.58), rough=0.32, met=0.15, usure=0.35, nu=(0.8, 0.8, 0.78), crasse=0.45, crasse_col=cr, graine=1105)
    M["peint"]["fo_teinte"] = 1
    M["verre"] = MT.verre("rb11_verre", col=(0.012, 0.03, 0.05), reflet=(0.3, 0.45, 0.6))
    M["ligne"] = MT.lumiere(S, "rb11_ligne", (0.52, 0.8, 1.0), 1.4, main=0.5)
    M["reacteur"] = MT.lumiere(S, "rb11_reacteur", (0.35, 0.72, 1.0), 2.0, main=0.5)
    return M


def squelette(phase, cap=CAP, pas=PAS):
    sq = Mr.Squelette()
    sq.os("racine", None, Mr.rz(cap))
    a, m = Ga.corps_marche(phase, Z0, bob=0.05, tangage=0.03, roulis=0.05, lacet=0.05)
    sq.os("corps", "racine", m)
    sq.os("queue", "corps", Mr.autour((-0.9, 0.0, 0.0), Mr.chaine(Mr.rz(-0.09 * math.sin(a) if phase is not None else 0.0), Mr.ry(0.05 * math.sin(2.0 * a) if phase is not None else 0.0))))
    Ga.pattes(sq, m, phase, pas, BETA, LEVE, L1, L2, TABLE, incl=0.9)
    return sq


def _lame(poly3, ep=0.03):
    """Plaque triangulaire d'épaisseur ep, dans le plan XZ (contour : (x, z)), y centré."""
    v = [(p[0], -ep / 2.0, p[1]) for p in poly3] + [(p[0], ep / 2.0, p[1]) for p in poly3]
    n = len(poly3)
    faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, n + i, n + j, j))
    uv = [(p[0], p[1]) for p in poly3] * 2
    return v, faces, uv


def modele(lots, M, r, torse=False):
    c = lots("corps")
    # fuselage : section en losange aplati, pointe devant
    sec = [(1.72, 0.012, 0.012), (1.3, 0.11, 0.09), (0.7, 0.25, 0.2), (0.0, 0.32, 0.27), (-0.6, 0.3, 0.24), (-0.95, 0.2, 0.17)]
    rings = [[(x, a * math.cos(G.TAU * j / 8 + 0.39) / 0.92, b * math.sin(G.TAU * j / 8 + 0.39) / 0.92) for j in range(8)] for x, a, b in sec]
    c.put(M["blanc"], G.loft(rings, True, True))
    # verrière, bandeaux bleu-blanc sur les flancs, panneaux
    c.put(M["verre"], F.pose(F.poutre([(0.0, 0.2, 0.04, 0.0), (0.46, 0.09, 0.02, 0.0)], 0.5), (0.5, 0.0, 0.2), (1.0, 0.0, -0.19)))
    for s in (1.0, -1.0):
        ct = [(1.2, s * 0.11, 0.0), (0.55, s * 0.26, 0.0), (-0.2, s * 0.33, 0.0), (-0.8, s * 0.26, 0.0)]
        c.put(M["ligne"], G.tube(G.catmull(ct, 4), 0.012, 5))
        c.put(M["peint"], F.sur_face(F.plaque([(-0.2, -0.08), (0.2, -0.06), (0.14, 0.08), (-0.2, 0.08)], 0.012), (0.12, s * 0.28, 0.11), (0.0, s * 0.8, 0.6)))
        # canon fin à plat
        c.put(M["titane"], F.disque((0.92, s * 0.28, -0.14), 0.026, 1.0, "x", 8))
        c.put(M["noir"], F.bague((1.32, s * 0.28, -0.14), 0.026, 0.038, 0.14, "x", 8, 0.006))
        c.put(M["ligne"], F.bague((1.0, s * 0.28, -0.14), 0.026, 0.03, 0.05, "x", 8))
        c.put(M["blanc2"], F.bielle((0.4, s * 0.22, -0.1), (0.62, s * 0.28, -0.14), 0.08, 0.05))
    # grand aileron dorsal : triangle balayé vers l'arrière, avec lignes
    d = _lame([(0.42, 0.22), (-0.72, 0.2), (-1.08, 1.32), (-0.72, 1.32)], 0.04)
    c.put(M["blanc2"], d)
    c.put(M["titane"], _lame([(0.42, 0.23), (0.1, 0.2), (-0.72, 1.32), (-0.72 + 0.03, 1.325)], 0.052))
    c.put(M["ligne"], F.pose(F.disque((0.5, 0.0, 0.0), 0.009, 1.0, "x", 5), (-0.45, 0.0, 0.54), (-0.42, 0.0, 0.9)))
    c.put(M["peint"], _lame([(-0.5, 0.42), (-0.82, 0.42), (-0.96, 0.82), (-0.74, 0.82)], 0.05))
    # petits ailerons d'épaule, en V vers le bas : ils tiennent les hanches
    for s in (1.0, -1.0):
        c.put(M["titane"], F.bielle((-0.2, s * 0.22, -0.02), (-0.2, s * 0.24, -0.14), 0.2, 0.1))
    # le chargé : tôles, trappes, prises d'air, sondes, pods sous l'épaule
    def fus(rr):
        x_ = rr.f(-0.85, 1.15)
        a_ = 0.32 * (1.0 - ((x_ + 0.1) / 1.85) ** 2) + 0.03
        t_ = rr.f(0.15, math.pi - 0.15)
        n_ = (0.0, math.cos(t_), math.sin(t_))
        return (x_, a_ * n_[1], a_ * 0.85 * n_[2]), n_
    Ga.plaques(c, [M["blanc2"], M["titane"], M["noir"], M["blanc"]], r, 90, fus, (0.04, 0.16), 0.012)
    for s in (1.0, -1.0):
        c.put(M["noir"], F.pose(F.poutre([(0.0, 0.14, 0.14), (0.42, 0.12, 0.1)], 0.3), (0.18, s * 0.3, -0.02), (-1.0, s * 0.1, 0.0)))
        c.put(M["titane"], F.bague((0.18, s * 0.3, -0.02), 0.05, 0.095, 0.03, "x", 8, 0.006))
        for k in range(2):
            y_ = s * (0.44 + 0.12 * k)
            c.put(M["blanc2"], F.disque((-0.05, y_, -0.24), 0.05, 0.62, "x", 8))
            c.put(M["peint"], G.tour([(0.26, 0.05), (0.38, 0.0)], 8, "x", (0.0, y_, -0.24)))
        c.put(M["titane"], F.bielle((-0.05, s * 0.3, -0.12), (-0.05, s * 0.5, -0.2), 0.1, 0.04))
    # dessous : baie noire
    c.put(M["noir"], F.pose(F.poutre([(0.0, 0.26, 0.05), (1.0, 0.12, 0.03)], 0.4), (-0.3, 0.0, -0.22), (1.0, 0.0, 0.03)))
    # queue : tuyère et 2 ailerons en V ; elle balance
    q = lots("queue")
    q.put(M["titane"], G.tour([(-0.92, 0.2), (-1.08, 0.2), (-1.16, 0.15), (-1.18, 0.12)], 16, "x"))
    q.put(M["noir"], F.disque((-1.18, 0.0, 0.0), 0.12, 0.012, "x", 16))
    q.put(M["reacteur"], F.disque((-1.19, 0.0, 0.0), 0.08, 0.012, "x", 16))
    q.put(M["titane"], F.bague((-1.0, 0.0, 0.0), 0.2, 0.218, 0.05, "x", 16, 0.008))
    for s in (1.0, -1.0):
        v, f_, u = _lame([(-0.86, 0.04), (-1.22, 0.04), (-1.62, 0.66), (-1.34, 0.66)], 0.03)
        ang = s * 0.72
        v2 = [G.rot_x(p, ang) for p in v]
        q.put(M["blanc2"], (v2, f_, u))
    # pattes : cuisse-aile, tibia long, griffe à 2 doigts
    for nom, _h, _p, _d, _po in TABLE:
        cu = lots("cuisse_" + nom)
        cu.put(M["blanc"], F.poutre([(-0.1, 0.14, 0.3), (0.1, 0.14, 0.32), (L1 - 0.06, 0.09, 0.11), (L1 + 0.04, 0.09, 0.12)], 0.42))
        cu.put(M["titane"], F.disque((0.0, 0.0, 0.0), 0.11, 0.14, "y", 12))
        cu.put(M["ligne"], F.pose(F.disque((0.2, 0.0, 0.0), 0.007, 0.4, "x", 5), (0.15, 0.052, 0.0), (1.0, 0.0, 0.0)))
        ti = lots("tibia_" + nom)
        ti.put(M["titane"], F.disque((0.0, 0.0, 0.0), 0.07, 0.11, "y", 10))
        ti.put(M["blanc2"], F.poutre([(0.0, 0.11, 0.14), (0.5, 0.08, 0.1), (L2 - 0.1, 0.045, 0.05)], 0.42))
        ti.put(M["titane"], F.pose(F.disque((L2 / 2.0, 0.0, 0.0), 0.016, L2 - 0.3, "x", 6), (0.1, 0.0, -0.06), (1.0, 0.0, 0.0)))
        pi = lots("pied_" + nom)
        pi.put(M["titane"], F.disque((0.0, 0.0, 0.05), 0.04, 0.08, "z", 8))
        for ang, lg in ((0.36, 0.3), (-0.36, 0.3), (math.pi, 0.16)):
            pi.put(M["blanc2"], F.pose(F.poutre([(0.0, 0.05, 0.04), (lg, 0.016, 0.012, -0.012)], 0.3), (0.0, 0.0, 0.03), (math.cos(ang), math.sin(ang), -0.04)))
