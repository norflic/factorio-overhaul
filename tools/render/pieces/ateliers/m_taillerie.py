"""TAILLERIE fo-lapidary (3×3, âge 7, électrique, UNE entrée d'eau au nord, au centre) : la meule et le cristal.
Le cristal de résonance brut, bridé dans la tête d'un bras de facettage, est usé contre une GRANDE MEULE diamantée qui
tourne ; des buses d'eau refroidissent et emportent la poudre vers un bac de décantation ; une scie refend. a : meule à plat
et bras ; b : deux postes (meule et scie à refendre, bac plus grand) ; c : meule verticale face au sud (polisseuse).
"""
import math

import communs as CO
import geo as G

Y = CO.Y
TAU = 2.0 * math.pi


def _cristal(k, c, axe, L=0.34, r=0.075, mat="cristal"):
    """Cristal hexagonal à deux pointes, le long de axe (vecteur)."""
    n = G.norm(axe)
    prof = [(-L / 2.0, 0.0), (-L / 2.0 + r * 1.2, r), (L / 2.0 - r * 1.4, r), (L / 2.0, 0.0)]
    m = G.tour(prof, 6, "z", (0.0, 0.0, 0.0))
    k.put(mat, G.oriente(m, c, n))


def _bac_cristaux(k, x, y):
    """Caisse cerclée pleine de cristaux de résonance bruts, en gerbe, qui luisent (lueur cyan de jour)."""
    lx, ly, h = 0.82, Y(0.5), 0.34
    k.caisson("bois", x, y, 0.0, lx, ly, h, 0.02)
    for sx in (-1, 1):
        k.b("acier", (x + sx * (lx / 2.0 - 0.06), y - ly / 2.0 - 0.006, h / 2.0), (0.04, 0.012, h))
    k.b("noyau", (x, y, h - 0.005), (lx - 0.08, ly - 0.08, 0.01))
    for i in range(11):
        px = x + k.r.f(-lx / 2.0 + 0.1, lx / 2.0 - 0.1)
        py = y + k.r.f(-ly / 2.0 + 0.08, ly / 2.0 - 0.08)
        L = k.r.f(0.2, 0.38)
        ax = (k.r.f(-0.45, 0.45), k.r.f(-0.45, 0.45), 1.0)
        n = G.norm(ax)
        _cristal(k, (px + n[0] * L * 0.3, py + n[1] * L * 0.3, h + n[2] * L * 0.3), ax, L=L, r=k.r.f(0.045, 0.07))
    k.plaque("plaque", x, y - ly / 2.0, h * 0.55, 0.2, 0.1)
    CO.halo(k.S, k, (x, y - 0.55, 0.7), (0.2, 0.75, 1.0), 25.0, r=(0.6, 1.5))


def _etabli(k, x0, x1, ty0, ty1, zt):
    """Établi en fonte : piétement à caissons, plateau épais, tiroirs et persiennes au sud."""
    xm, lx = (x0 + x1) / 2.0, x1 - x0
    ym, ly = Y((ty0 + ty1) / 2.0), Y(ty1 - ty0)
    for sx in (-1, 1):
        k.caisson("car", xm + sx * (lx / 2.0 - 0.28), ym, 0.0, 0.5, ly - 0.1, zt - 0.08, 0.03)
    k.caisson("fonte", xm, ym, zt - 0.08, lx + 0.06, ly + 0.06, 0.08, 0.02)
    k.bz("noir", xm, ym, 0.0, lx - 1.0, ly - 0.3, 0.18)
    yf = ym - ly / 2.0
    for sx in (-1, 1):
        k.armoire("car2", xm + sx * (lx / 2.0 - 0.28), yf + 0.05 - 0.002, 0.08, 0.44, zt - 0.22, e=0.04, lampe="voyant_v" if sx > 0 else None)
    k.chevrons(xm, yf - 0.03, zt - 0.05, lx - 0.1, 0.05)
    return yf


def _meule(k, cx, cy, z, R, ph):
    """Meule horizontale : carter anti-éclaboussures, plateau, disque diamanté qui tourne, pellicule d'eau."""
    k.rev("acier", cx, cy, [(z - 0.12, R + 0.1), (z + 0.08, R + 0.1), (z + 0.08, R + 0.08), (z - 0.1, R + 0.08)], 48, cap=False)
    k.rev("noir", cx, cy, [(z - 0.1, R + 0.08), (z - 0.1, 0.0)], 48)
    k.mobile(True)
    k.put("meule", G.tour([(z - 0.06, 0.0), (z - 0.06, R - 0.06), (z, R - 0.06), (z, 0.0)], 48, "z", (cx, cy, 0.0)))
    k.put("chrome", G.tour([(z - 0.06, R - 0.07), (z - 0.06, R), (z + 0.01, R), (z + 0.01, R - 0.07)], 48, "z", (cx, cy, 0.0)))
    k.put("or", G.tour([(z - 0.004, R * 0.18), (z + 0.004, R * 0.18), (z + 0.004, R * 0.12), (z - 0.004, R * 0.12)], 24, "z", (cx, cy, 0.0)))
    for i in range(10):
        a = TAU * (ph / 10.0 + i / 10.0)
        k.b("acier_clair", (cx + R * 0.55 * math.cos(a), cy + R * 0.55 * math.sin(a), z + 0.002), (R * 0.75, 0.014, 0.006), rz=a)
    k.mobile(False)
    k.rev("eau", cx, cy, [(z + 0.004, R * 0.92), (z + 0.006, R * 0.6), (z + 0.006, 0.0)], 40)
    k.cyl("acier_clair", cx, cy, z, z + 0.06, 0.07, 14)


def taillerie(S, k, v):
    if v == "d":
        return taillerie_d(S, k)
    M = k.M = CO.matieres(S)
    k.sol("noir", 3)
    zt = 0.62
    # bride d'eau au nord, au centre, et conduite vers la rampe de buses
    # arrivée d'eau : tronçon de raccord (pipe_picture) ; ici la colonne montante sortie du sol vers la rampe de buses
    k.rev("acier", 0.0, Y(1.05), [(0.0, 0.11), (0.06, 0.11), (0.06, 0.07)], 16, cap=False)
    k.tuyau("bleu", [(0.0, Y(1.05), 0.02), (0.0, Y(1.05), 1.0), (0.0, Y(0.5), 1.0)], r=0.06, coude=0.15, bride_mat="acier")
    k.collier("acier", (0.0, Y(1.05), 0.45), (0.0, 0.0, 1.0), 0.07)
    # caisse de cristaux bruts au nord-ouest (le signe de la machine), cuve de clarification au nord-est
    _bac_cristaux(k, -0.88, Y(1.0))
    k.cuve("car2", 0.95, Y(1.0), 0.06, 0.95, 0.32, 0.25, 30)
    k.cerclages("acier", 0.95, Y(1.0), (0.3, 0.7), 0.32, segs=30)
    k.tuyau("bleu", [(0.62, Y(1.0), 0.75), (0.25, Y(1.0), 0.75), (0.25, Y(1.1), 0.3)], r=0.04, coude=0.1, brides=[])
    if v == "c":
        return _verticale(k, zt)
    yf = _etabli(k, -1.35, 1.35, -1.05, 0.55, zt)
    cx, cy = (-0.35, Y(-0.25)) if v == "a" else (-0.6, Y(-0.25))
    R = 0.62 if v == "a" else 0.52
    _meule(k, cx, cy, zt + 0.08, R, k.phase)
    k.tuyau("boue", [(cx - R - 0.08, cy + 0.2, zt + 0.02), (cx - R - 0.2, Y(0.62), zt + 0.02)], r=0.045, coude=0.08, brides=[])
    # rampe de buses au-dessus de la meule
    zr = zt + 0.5
    k.tuyau("bleu", [(0.0, Y(0.5), 1.0), (cx + 0.15, cy + 0.42, zr), (cx - 0.2, cy + 0.32, zr)], r=0.03, coude=0.1, brides=[])
    for t in (0.0, 0.5, 1.0):
        p = (cx + 0.15 - 0.35 * t, cy + 0.42 - 0.1 * t, zr)
        k.axe("acier_clair", p, (p[0], p[1] - 0.06, p[2] - 0.12), 0.014, 6)
        k.put("jet", G.tube(G.catmull([(p[0], p[1] - 0.06, p[2] - 0.12), (p[0] + 0.02, p[1] - 0.2, zt + 0.25),
                                       (p[0] + 0.05, p[1] - 0.3, zt + 0.1)], 6), 0.016, 6))
    # bras de facettage : colonne, bras, tête porte-cristal, quadrant gradué
    xb = cx + R + 0.35
    k.bz("car2", xb, cy + 0.2, zt, 0.18, 0.18, 0.85)
    k.caisson("car", xb, cy + 0.2, zt + 0.85, 0.24, 0.24, 0.12, 0.02)
    a = 0.25 * math.sin(TAU * k.phase)
    hx, hy = cx + 0.2 * math.cos(a), cy + 0.05 + 0.2 * math.sin(a)
    k.mobile(True)
    k.axe("acier_clair", (xb, cy + 0.2, zt + 0.92), (hx, hy, zt + 0.52), 0.035, 10)
    k.put("acier", G.tour([(-0.012, 0.13), (-0.012, 0.16), (0.012, 0.16), (0.012, 0.13)], 24, "y", (hx + 0.1, hy, zt + 0.55)))
    k.cyl("noir", hx, hy, zt + 0.42, zt + 0.55, 0.04, 10)
    _cristal(k, (hx - 0.02, hy, zt + 0.32), (0.2, 0.0, 1.0), L=0.42, r=0.1)
    k.mobile(False)
    # lampe de travail
    k.axe("acier", (xb + 0.05, cy + 0.25, zt + 0.97), (cx + 0.3, cy + 0.15, zt + 1.3), 0.018, 6)
    k.axe("noir", (cx + 0.32, cy + 0.15, zt + 1.32), (cx + 0.24, cy + 0.1, zt + 1.24), 0.06, 12)
    k.put("projecteur", G.oriente(G.tour([(0.0, 0.05), (0.01, 0.045), (0.016, 0.0)], 12, "z"), (cx + 0.23, cy + 0.09, zt + 1.23),
                                   (-0.5, -0.4, -0.75)))
    # présentoir de cristaux taillés au bord sud de l'établi
    xs0 = 0.55 if v == "a" else -0.1
    k.bz("noir", xs0 + 0.3, yf + 0.18, zt, 0.7, 0.22, 0.04)
    for i in range(4):
        _cristal(k, (xs0 + 0.05 + i * 0.17, yf + 0.18, zt + 0.12), (0.0, 0.25, 1.0), L=0.18, r=0.04)
    if v == "b":
        # scie à refendre : lame verticale face au sud, capot, buse
        sx, sy = 0.62, Y(-0.2)
        k.caisson("car2", sx, sy, zt, 0.5, Y(0.55), 0.06, 0.02)
        k.volant((sx, sy, zt + 0.12), 0.3, "y", larg=0.02, rayons=8, jante="chrome", moyeu="acier", ph=k.phase, ep=0.05, repere=None)
        k.put("car", G.tour([(-0.05, 0.31), (-0.05, 0.36), (0.05, 0.36), (0.05, 0.31)], 24, "y", (sx, sy, zt + 0.12), 0.0, math.pi))
        k.bz("pierre2", sx + 0.05, sy, zt + 0.06, 0.32, 0.22, 0.14)
        k.tuyau("bleu", [(0.0, Y(0.5), 1.0), (sx, Y(0.3), 1.0), (sx, sy + 0.1, zt + 0.5)], r=0.03, coude=0.1, brides=[])
        k.moteur("car2", 1.12, sy, zt, 0.3, 0.1, axe="y")


def _verticale(k, zt):
    """Variante c : polisseuse à meule verticale (disque face au sud), bras porte-cristal contre la face, carter en coquille."""
    yf = _etabli(k, -1.3, 1.3, -1.0, 0.45, zt)
    cx, cy, zc = -0.15, Y(-0.05), zt + 0.72
    R = 0.62
    k.put("car", G.tour([(-0.18, R + 0.02), (-0.18, R + 0.1), (0.12, R + 0.1), (0.12, R + 0.02)], 40, "y", (cx, cy, zc), 0.0, math.pi * 1.2))
    k.bz("car2", cx, cy + 0.3, zt, 0.42, 0.3, zc - zt)
    k.moteur("car2", cx, cy + 0.55, zc - 0.13, 0.4, 0.15, axe="y")
    k.mobile(True)
    k.put("meule", G.tour([(-0.04, 0.0), (-0.04, R - 0.05), (0.04, R - 0.05), (0.04, 0.0)], 48, "y", (cx, cy, zc)))
    k.put("chrome", G.tour([(-0.045, R - 0.05), (-0.045, R), (0.045, R), (0.045, R - 0.05)], 48, "y", (cx, cy, zc)))
    for i in range(8):
        a = TAU * (k.phase / 8.0 + i / 8.0)
        k.b("acier_clair", (cx + R * 0.55 * math.cos(a), cy - 0.045, zc + R * 0.55 * math.sin(a)), (R * 0.7, 0.008, 0.016), ry=-a)
    k.mobile(False)
    k.axe("acier_clair", (cx, cy - 0.08, zc), (cx, cy + 0.4, zc), 0.07, 14)
    # bras porte-cristal contre la face de la meule
    k.bz("car2", 0.85, Y(-0.55), zt, 0.2, 0.2, 0.7)
    k.axe("acier_clair", (0.85, Y(-0.55), zt + 0.62), (cx + 0.32, cy - 0.22, zc + 0.12), 0.035, 10)
    k.cyl("noir", cx + 0.32, cy - 0.22, zc + 0.05, zc + 0.2, 0.04, 10)
    _cristal(k, (cx + 0.3, cy - 0.14, zc + 0.08), (-0.2, 1.0, 0.1), L=0.3, r=0.07)
    k.tuyau("bleu", [(0.0, Y(0.5), 1.0), (cx + 0.1, cy + 0.1, zc + R + 0.25), (cx + 0.1, cy - 0.1, zc + R + 0.15)], r=0.03, coude=0.1, brides=[])
    k.b("boue", (cx, cy - 0.15, zt + 0.01), (1.0, 0.4, 0.012))
    for i in range(4):
        _cristal(k, (0.5 + i * 0.17, yf + 0.18, zt + 0.12), (0.0, 0.25, 1.0), L=0.18, r=0.04)
    k.bz("noir", 0.75, yf + 0.18, zt, 0.7, 0.22, 0.04)


# ------------------------------------------------------------------------------------------------ version d (critique du 3/11)
def _prisme_cristal(k, c, axe, L, r, mat="cristal_f"):
    """Prisme hexagonal à pointes facettées (deux étages de facettes à chaque bout)."""
    prof = [(-L / 2.0, 0.0), (-L / 2.0 + r * 0.6, r * 0.62), (-L / 2.0 + r * 1.3, r), (L / 2.0 - r * 1.5, r),
            (L / 2.0 - r * 0.7, r * 0.6), (L / 2.0, 0.0)]
    k.put(mat, G.oriente(G.tour(prof, 6, "z", (0.0, 0.0, 0.0), 0.3, 0.3 + TAU), c, axe))


def _brillant(k, c, axe, r, mat="cristal_f2"):
    """Gemme taillée en brillant : culasse en cône, rondiste, couronne, table (8 facettes)."""
    h = r * 1.3
    prof = [(-h * 0.62, 0.0), (0.0, r), (h * 0.06, r), (h * 0.3, r * 0.62), (h * 0.3, 0.0)]
    k.put(mat, G.oriente(G.tour(prof, 8, "z", (0.0, 0.0, 0.0), 0.2, 0.2 + TAU), c, axe))


def taillerie_d(S, k):
    """REFAITE d'après la critique (CRITIQUE.md §5) : bâti en fonte sur pieds jusqu'au bord sud ; meule de 1,5 tuile (anneau
    diamanté, rayures, axe), carter ouvert au sud ; colonne de facettage qui monte à 1,2 tuile, bras articulé, quadrant en laiton et
    mandrin qui tient le cristal contre la meule ; lampe de travail ; rampe de buses et filets d'eau ; bac de décantation laiteux au
    sud-est (niveau, surverse) ; caisse de cristaux bruts en oursin au nord-ouest ; présentoir incliné de brillants au sud-ouest."""
    k.M = CO.matieres(S, v2=True)
    k.sol("noir", 3)
    zt = 0.58
    # bâti : longerons et traverses peints, pieds de fonte (le sol et les ombres se voient dessous)
    for x in (-1.25, 0.42):
        k.bz("bleu_machine", x, Y(-0.42), zt - 0.1, 0.12, Y(2.0), 0.1)
        for ty in (-1.38, 0.52):
            k.bz("fonte", x, Y(ty), 0.0, 0.1, 0.1, zt - 0.1)
            k.bz("fonte", x, Y(ty), 0.0, 0.18, 0.18, 0.04)
    for ty in (-1.38, 0.52):
        k.bz("bleu_machine", -0.42, Y(ty), zt - 0.1, 1.79, 0.12, 0.1)
    k.chevrons(-0.42, Y(-1.38) - 0.062, zt - 0.05, 1.7, 0.05)
    # meule : pied, moteur, disque, anneau diamanté, rayures, axe ; carter ouvert au sud ; pellicule d'eau
    cx, cy, zl, R = -0.42, Y(-0.38), zt + 0.2, 0.75
    k.rev("fonte", cx, cy, [(0.0, 0.34), (0.06, 0.3), (0.12, 0.22), (zl - 0.1, 0.18), (zl - 0.06, 0.26), (zl - 0.04, 0.26)], 28)
    k.moteur("car2", cx + 0.55, cy + 0.15, 0.06, 0.4, 0.14, axe="x")
    k.mobile(True)
    k.put("meule", G.tour([(zl - 0.05, 0.0), (zl - 0.05, R - 0.1), (zl, R - 0.1), (zl, 0.0)], 56, "z", (cx, cy, 0.0)))
    k.put("diamant", G.tour([(zl - 0.05, R - 0.1), (zl - 0.05, R), (zl + 0.012, R), (zl + 0.012, R - 0.1)], 56, "z", (cx, cy, 0.0)))
    for i in range(12):
        a = TAU * (k.phase / 12.0 + i / 12.0)
        k.b("noir", (cx + R * 0.5 * math.cos(a), cy + R * 0.5 * math.sin(a), zl + 0.003), (R * 0.7, 0.035, 0.006), rz=a)
    k.mobile(False)
    k.cyl("acier_clair", cx, cy, zl, zl + 0.07, 0.09, 16)
    k.cyl("acier", cx, cy, zl + 0.07, zl + 0.11, 0.05, 6)
    k.put("eau", G.tour([(zl + 0.006, R * 0.86), (zl + 0.009, R * 0.55)], 40, "z", (cx, cy, 0.0), 2.2, 4.4))
    k.put("bleu_machine", G.tour([(zl - 0.08, R + 0.07), (zl + 0.16, R + 0.07), (zl + 0.16, R + 0.1), (zl - 0.08, R + 0.1)], 40, "z",
                                (cx, cy, 0.0), -0.15, math.pi + 0.15))
    k.put("acier", G.tour([(zl + 0.16, R + 0.06), (zl + 0.19, R + 0.06), (zl + 0.19, R + 0.12), (zl + 0.16, R + 0.12)], 40, "z",
                         (cx, cy, 0.0), -0.15, math.pi + 0.15))
    # colonne de facettage à l'est de la meule, bras articulé, quadrant en laiton, mandrin et cristal contre la meule
    xc, yc = 0.62, Y(-0.3)
    k.rev("bleu_machine", xc, yc, [(zt - 0.1, 0.17), (zt + 0.02, 0.15), (zt + 0.06, 0.1), (2.3, 0.085), (2.34, 0.11), (2.42, 0.11), (2.44, 0.0)], 20)
    k.rivets_ligne("riv", (xc - 0.06, yc - 0.08, zt + 0.2), (xc - 0.06, yc - 0.08, 2.2), 10, r=0.012)
    pe = (0.12, Y(-0.33), 1.62)
    pm = (-0.04, Y(-0.38), zl + 0.42)
    a = 0.12 * math.sin(TAU * k.phase)
    pm = (pm[0] + 0.06 * math.cos(a), pm[1] + 0.06 * math.sin(a), pm[2])
    k.mobile(True)
    k.axe("acier_clair", (xc, yc, 2.36), pe, 0.04, 10)
    k.axe("acier_clair", pe, (pm[0], pm[1], pm[2] + 0.1), 0.035, 10)
    k.put("or", G.tour([(-0.012, 0.03), (-0.012, 0.19), (0.012, 0.19), (0.012, 0.03)], 20, "y", (pe[0], pe[1] - 0.05, pe[2]), math.pi, TAU))
    for i in range(7):
        aa = math.pi + math.pi * (i + 0.5) / 7
        k.b("noir", (pe[0] + 0.17 * math.cos(aa), pe[1] - 0.064, pe[2] + 0.17 * math.sin(aa)), (0.012, 0.006, 0.035), ry=-aa)
    k.cyl("acier", pe[0], pe[1], pe[2] - 0.05, pe[2] + 0.05, 0.05, 12)
    k.cyl("noir", pm[0], pm[1], pm[2], pm[2] + 0.14, 0.045, 12)
    _prisme_cristal(k, (pm[0] - 0.02, pm[1], pm[2] - 0.18), (0.15, 0.0, 1.0), 0.42, 0.1)
    k.mobile(False)
    CO.halo(S, k, (pm[0], pm[1] - 0.45, zl + 0.3), (0.2, 0.75, 1.0), 8.0, r=(0.4, 1.1))
    # lampe de travail sur bras (lueur chaude), braquée sur la meule
    k.axe("acier", (xc, yc, 2.0), (0.22, Y(-0.05), 2.12), 0.022, 8)
    k.axe("noir", (0.24, Y(-0.04), 2.13), (0.14, Y(-0.12), 2.02), 0.08, 14)
    k.put("projecteur", G.oriente(G.tour([(0.0, 0.07), (0.012, 0.062), (0.02, 0.0)], 14, "z"), (0.13, Y(-0.13), 2.01), (-0.35, -0.45, -0.8)))
    CO.halo(S, k, (-0.1, Y(-0.9), 1.0), (1.0, 0.8, 0.5), 13.0, r=(0.5, 1.4))
    # eau : colonne montante (bride par les tronçons), rampe au-dessus de la meule, buses, filets, éclaboussures
    k.rev("acier", 0.0, Y(1.05), [(0.0, 0.11), (0.06, 0.11), (0.06, 0.07)], 16, cap=False)
    rampe = [(0.0, Y(1.05), 0.02), (0.0, Y(1.05), 1.25), (-0.25, Y(0.2), 1.25), (-0.75, Y(0.05), 1.22), (-1.0, Y(-0.25), 1.18)]
    k.tuyau("bleu", rampe, r=0.05, coude=0.15, bride_mat="acier")
    for p in ((-0.3, Y(0.15), 1.24), (-0.62, Y(0.06), 1.22), (-0.9, Y(-0.12), 1.2)):
        k.axe("acier_clair", p, (p[0], p[1] - 0.04, p[2] - 0.12), 0.018, 6)
        bas = (p[0] + 0.03, p[1] - 0.16, zl + 0.01)
        k.put("jet", G.tube(G.catmull([(p[0], p[1] - 0.04, p[2] - 0.12), (p[0] + 0.01, p[1] - 0.1, (p[2] + zl) / 2.0), bas], 6), 0.016, 6))
        for j in range(4):
            aa = TAU * j / 4 + 0.4
            k.sph("jet", (bas[0] + 0.05 * math.cos(aa), bas[1] + 0.05 * math.sin(aa), zl + 0.02), 0.018, 8, 4)
    # bac de décantation laiteux au sud-est : niveau, surverse, jauge
    xb_, yb_ = 0.88, Y(-0.98)
    lxb, lyb, hb, e = 0.95, Y(0.72), 0.58, 0.04          # bac OUVERT : parois, eau laiteuse visible à 0,08 sous le bord
    k.bz("bleu_machine", xb_, yb_, 0.0, lxb, lyb, 0.1)
    for sy in (-1, 1):
        k.bz("bleu_machine", xb_, yb_ + sy * (lyb - e) / 2.0, 0.1, lxb, e, hb - 0.1)
    for sx in (-1, 1):
        k.bz("bleu_machine", xb_ + sx * (lxb - e) / 2.0, yb_, 0.1, e, lyb, hb - 0.1)
    k.b("boue", (xb_, yb_, 0.5), (lxb - 2 * e, lyb - 2 * e, 0.012))
    k.roches("boue", xb_ - 0.3, xb_ + 0.3, yb_ - 0.2, yb_ + 0.2, 0.505, 6, 0.02, 0.035)
    k.b("acier", (xb_, yb_, 0.6), (0.05, Y(0.66), 0.05))
    yfb = yb_ - Y(0.36)
    k.tuyau("acier", [(xb_ - 0.3, yfb + 0.02, 0.48), (xb_ - 0.3, yfb - 0.12, 0.48), (xb_ - 0.3, yfb - 0.16, 0.4)], r=0.03, coude=0.05, brides=[])
    k.put("jet", G.tube([(xb_ - 0.3, yfb - 0.16, 0.38), (xb_ - 0.3, yfb - 0.17, 0.0)], 0.014, 6))
    k.axe("verre", (xb_ + 0.3, yfb - 0.02, 0.08), (xb_ + 0.3, yfb - 0.02, 0.52), 0.025, 8)
    k.b("boue", (xb_ + 0.3, yfb - 0.045, 0.24), (0.02, 0.006, 0.3))
    k.put("boue", G.tube([(cx + R * 0.7, cy - R * 0.5, zl - 0.04), (0.45, Y(-0.85), 0.62), (xb_ - 0.2, yb_ + 0.1, 0.62)], 0.035, 8))
    # caisse de cristaux bruts en oursin au nord-ouest
    xk, yk = -0.95, Y(0.95)
    lx, ly, h = 0.85, Y(0.55), 0.3
    k.caisson("chene", xk, yk, 0.0, lx, ly, h, 0.02)
    for sx in (-1, 1):
        k.b("acier", (xk + sx * (lx / 2.0 - 0.06), yk - ly / 2.0 - 0.006, h / 2.0), (0.04, 0.012, h))
    k.b("noyau", (xk, yk, h - 0.005), (lx - 0.08, ly - 0.08, 0.01))
    for i in range(13):
        ang = TAU * i / 13 + k.r.f(-0.2, 0.2)
        rr = k.r.f(0.05, 0.25)
        px, py_ = xk + rr * math.cos(ang) * 1.3, yk + rr * math.sin(ang)
        ax = (math.cos(ang) * k.r.f(0.4, 0.9), math.sin(ang) * k.r.f(0.4, 0.9), 1.0)
        L = k.r.f(0.24, 0.42)
        n = G.norm(ax)
        _prisme_cristal(k, (px + n[0] * L * 0.3, py_ + n[1] * L * 0.3, h + n[2] * L * 0.3), ax, L, k.r.f(0.05, 0.08))
    CO.halo(S, k, (xk, yk - 0.55, 0.7), (0.2, 0.75, 1.0), 15.0, r=(0.6, 1.5))
    # présentoir incliné de brillants au sud-ouest
    xp, yp = -0.95, Y(-1.22)
    k.bz("fonte", xp, yp + 0.06, 0.0, 0.5, 0.1, 0.32)
    k.b("noir", (xp, yp, 0.36), (0.62, 0.36, 0.04), rx=math.radians(28))
    k.b("bleu_machine", (xp, yp - 0.17, 0.27), (0.64, 0.03, 0.06))
    for i in range(4):
        u = -0.21 + i * 0.14
        _brillant(k, (xp + u, yp - 0.02 + 0.03 * (i % 2), 0.42 + 0.015 * (i % 2)), (0.0, -0.45, 1.0), 0.055)
    # cuve de clarification au nord-est, reliée à la colonne montante
    k.cuve("bleu_machine", 0.95, Y(1.0), 0.0, 0.95, 0.32, 0.25, 30)
    k.cerclages("acier", 0.95, Y(1.0), (0.3, 0.7), 0.32, segs=30)
    k.tuyau("bleu", [(0.62, Y(1.0), 0.75), (0.25, Y(1.0), 0.75), (0.25, Y(1.05), 0.3), (0.07, Y(1.05), 0.3)], r=0.04, coude=0.1, brides=[])
