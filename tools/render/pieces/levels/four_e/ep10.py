"""Four · Âge 10 · Haute technologie (ère IV, 5×5, niveaux 19 et 20). Lot F2-A (25/10) ; fiche : FICHES_FOUR.md, âge 10.
S'exécute DANS Blender.

En 3 mots : « coque ivoire, bandeau bleu, ventilateurs ». La chambre est un FOUR À INDUCTION CARÉNÉ : COQUE IVOIRE lisse
à coins arrondis et arête chanfreinée, sur socle anthracite, BANDEAU BLEU lumineux continu qui ceint la façade dans une
gorge anthracite, joints anthracite, grilles d'aération, écrans ; trois grands VENTILATEURS sur le toit dallé ; nappes de
câbles rouges et bleus au pied ; à l'arrière droit, tour d'extraction ivoire à persiennes et ventilateur (la fumée).
Palette 60/30/10 (ages.PALETTE[10]) : ivoire chaud / anthracite / câbles rouge et bleu ; voyants bleus.
"""
import math

import ages
import corps
import parts3 as P3
from kit import TAU
from repere import Y

EPOQUE = 10
NOM = ages.NOMS[10]
TRIPLET = ("coque ivoire", "bandeau bleu", "ventilateurs")
FOYER = ages.FOYER[10]
HABILLAGE = dict(ages.CORPS[10], foyer="anthracite")
HX, YN0, YN1, RR = 2.32, -1.9, 2.35, 0.5
Z0, Z1, Z2, Z3 = 0.3, 1.75, 1.95, 2.03


def matieres(metal, M):
    ages.matieres(10, metal, M)


def rr(d=0.0, n=6):
    cy = Y((YN0 + YN1) / 2)
    hy = Y((YN1 - YN0) / 2)
    return corps.rect_arrondi(0.0, cy, HX + d, hy + d, max(0.05, RR + d), n)


def tronc_poly(g, Pb, Pt, z0, z1, m, what="carene"):
    n = len(Pb)
    vs = [(x, y, z0) for x, y in Pb] + [(x, y, z1) for x, y in Pt]
    fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))] + [(k, (k + 1) % n, n + (k + 1) % n, n + k) for k in range(n)]
    g._add(m, "soft", vs, fs, what)


def chambre(g, c):
    M = g.M
    zs = c.T["sole_h"]
    corps.prisme(g, rr(0.04), zs, Z0, M["anthracite"], what="socle")
    corps.prisme(g, rr(), Z0, Z1, M["blanc_casse"], what="coque")
    tronc_poly(g, rr(), rr(-0.18), Z1, Z2, M["blanc_casse"])
    P = rr(-0.18)
    corps.prisme(g, P, Z2 - 0.01, Z2, M["anthracite"], style="flat", what="toit")
    corps._motif(g, M, c.pont, P, Z2, 0.12, 10101)
    # gorge anthracite et bandeau bleu continu
    corps.couronne_poly(g, rr(0.02), rr(-0.06), 1.12, 1.46, M["anthracite"], what="gorge")
    # ronde 2 (mesures.py : plus grand foyer 0,75 t², au-delà de 0,45) : bandeau en SEGMENTS de 0,5 tuile séparés par
    # des montants anthracite, au lieu d'une bande continue
    Po, Pi = rr(0.035, 6), rr(0.0, 6)
    n = len(Po)
    pas = 0
    for i in range(n):
        j = (i + 1) % n
        L = math.hypot(Po[j][0] - Po[i][0], Po[j][1] - Po[i][1])
        m = max(1, int(L / 0.22))
        for k in range(m):
            pas += 1
            if pas % 3 == 0:
                g.box(((Po[i][0] + (Po[j][0] - Po[i][0]) * (k + 0.5) / m), (Po[i][1] + (Po[j][1] - Po[i][1]) * (k + 0.5)
                                                                             / m), 1.28),
                      (0.05, 0.05, 0.14), M["anthracite"], "hard", what="montant")
                continue
            t0, t1 = k / m, (k + 1) / m
            q = [(Pi[i][0] + (Pi[j][0] - Pi[i][0]) * t, Pi[i][1] + (Pi[j][1] - Pi[i][1]) * t) for t in (t0, t1)]
            o = [(Po[i][0] + (Po[j][0] - Po[i][0]) * t, Po[i][1] + (Po[j][1] - Po[i][1]) * t) for t in (t0, t1)]
            pts = [q[0], q[1], o[1], o[0]]
            g.hexa([corps.V((x, y, 1.22)) for x, y in pts] + [corps.V((x, y, 1.34)) for x, y in pts], M["emit"], "flat",
                   "bandeau")
    yf = Y(YN0)
    # joints verticaux, grilles, écrans
    for x in (-1.75, -1.15, 1.15, 1.75):
        for (za, zb) in ((Z0, 1.12), (1.46, Z1)):
            g.box((x, yf - 0.006, (za + zb) / 2), (0.03, 0.02, zb - za), M["anthracite"], "hard", what="joint")
    for x in (-1.45, 1.45):
        g.grille([corps.V((x - 0.24, yf - 0.012, 0.45)), corps.V((x + 0.24, yf - 0.012, 0.45)),
                  corps.V((x + 0.24, yf - 0.012, 0.95)), corps.V((x - 0.24, yf - 0.012, 0.95))], 7,
                 slat_mat=M["gris_tech"])
    for x in (-0.6, 0.6):
        P3.screen(g, (x, yf - 0.012, 1.6), (0, -1, 0), 0.32, 0.14, M, M["emit"])
    P3.lamp_row(g, (-2.1, yf - 0.01, 1.62), (-1.0, yf - 0.01, 1.62), 4, (0, -1, 0), M["emit"], M, size=0.03)
    # nappes de câbles au pied
    for sx in (-1, 1):
        for k, m in enumerate(("cable_r", "cable_b", "cable_r", "cable_b")):
            z = 0.2 + 0.035 * k
            g.cable((sx * 0.85, yf - 0.05 - 0.01 * k, z), (sx * 2.25, yf - 0.05 - 0.01 * k, z), 0.03, 0.017, M[m])
        for x in (sx * 1.2, sx * 1.6, sx * 2.0):
            g.box((x, yf - 0.06, 0.24), (0.04, 0.08, 0.16), M["anthracite"], "hard", what="collier")
    for (x, yn) in ((-1.45, -0.15), (-0.15, -0.15), (-0.8, 1.3)):
        ventilateur(g, x, yn, Z2, 0.52)
    # ronde 1 : toit trop nu. Hublot rond de l'inducteur (lueur bleue) et trappes à voyants
    xh, yh = 1.2, Y(-0.3)
    g.tube_shell((xh, yh, Z2 + 0.05), "z", 0.5, 0.36, 0.1, M["anthracite"], n=40, what="cadre_hublot")
    g.cyl((xh, yh, Z2 + 0.03), "z", 0.37, 0.02, M["emit_soft"], n=36, style="flat", what="inducteur")
    for k in range(8):
        a = TAU * k / 8
        g.box((xh + 0.2 * math.cos(a), yh + 0.2 * math.sin(a), Z2 + 0.06), (0.3, 0.025, 0.02), M["gris_tech"], "hard",
              R=corps.Matrix.Rotation(a, 3, "Z"), what="spire")
    for (x, yn) in ((-1.75, 0.75), (0.35, 0.75)):
        corps.boite(g, x - 0.3, x + 0.3, yn - 0.2, yn + 0.2, Z2, Z2 + 0.12, [M["gris_tech"], M["anthracite"]],
                    panel=0.3, faces="ts", rivets=False)
        P3.lamp_row(g, (x - 0.2, Y(yn - 0.2) - 0.01, Z2 + 0.06), (x + 0.2, Y(yn - 0.2) - 0.01, Z2 + 0.06), 3,
                    (0, -1, 0), M["emit"], M, size=0.025)
    g.halo((0, yf - 0.4, 1.3), M["_emit_rgb"], 8.0)


def ventilateur(g, x, yn, z, R):
    M = g.M
    y = Y(yn)
    g.tube_shell((x, y, z + 0.08), "z", R, R - 0.07, 0.16, M["anthracite"], n=40, what="buse")
    g.cyl((x, y, z + 0.02), "z", R - 0.07, 0.02, M["void"], n=32, style="flat", what="fond")
    for k in range(7):
        a = TAU * k / 7
        g.box((x + 0.24 * R / 0.52 * math.cos(a), y + 0.24 * R / 0.52 * math.sin(a), z + 0.07),
              (0.36 * R / 0.52, 0.1, 0.012), M["gris_tech"], "hard", R=corps.Matrix.Rotation(a, 3, "Z")
              @ corps.Matrix.Rotation(0.4, 3, "X"), what="pale")
    g.cyl((x, y, z + 0.1), "z", 0.1, 0.05, M["blanc_casse"], n=16, what="moyeu")
    g.cyl((x, y, z + 0.13), "z", 0.035, 0.01, M["emit"], n=10, style="flat", what="voyant")
    for a in (0.0, math.pi / 2):
        g.box((x, y, z + 0.16), (2 * R - 0.06, 0.018, 0.018), M["anthracite"], "hard",
              R=corps.Matrix.Rotation(a + 0.3, 3, "Z"), what="garde")


def gueule(g, c, G):
    M = g.M
    g.box((0, G["yf"] - 0.015, G["z1"] - 0.06), (G["x1"] * 1.4, 0.02, 0.035), M["emit"], "flat", what="barre_etat")


def fumee(g, c):
    M = g.M
    x, yn = 1.45, 1.15
    y = Y(yn)
    z0, z1 = Z2, 3.25
    P = corps.rect_arrondi(x, y, 0.32, Y(0.32), 0.12, 4)
    corps.prisme(g, P, z0, z1, M["blanc_casse"], what="tour")
    ys = y - Y(0.32) - 0.012
    g.grille([corps.V((x - 0.22, ys, 2.2)), corps.V((x + 0.22, ys, 2.2)), corps.V((x + 0.22, ys, 2.9)),
              corps.V((x - 0.22, ys, 2.9))], 8, slat_mat=M["anthracite"])
    g.box((x, ys - 0.004, 3.05), (0.5, 0.02, 0.05), M["emit"], "flat", what="liseré")
    g.tube_shell((x, y, z1 + 0.04), "z", 0.3, 0.24, 0.08, M["anthracite"], n=28, what="buse")
    corps.bouche_fumee(g, c, x, yn, z1 + 0.08, 0.24, levre=False)


def piece(g, c):
    """Baies de supercondensateurs : armoires anthracite à écran et voyants bleus."""
    M = g.M
    zs = c.T["sole_h"] + 0.03
    for nom in ("coin_SO", "coin_SE"):
        p = corps.coin(c, nom)
        corps.patin(g, c, p["x"], p["yn"], 2 * p["rw"] * 0.9, p["prof"] * 0.85)
        w = 2 * p["rw"] * 0.38
        for dx in (-w * 0.55, w * 0.55):
            x0 = p["x"] + dx - w / 2
            with corps.habille(g, c):
                P3.cabinet(g, x0, x0 + w, Y(p["yn"]) - 0.25, Y(p["yn"]) + 0.2, zs, zs + 0.55, g.M, M["emit"], rows=2,
                           screen_=True)
