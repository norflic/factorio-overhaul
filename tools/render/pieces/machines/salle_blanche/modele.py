"""SALLE BLANCHE (fo-cleanroom, 5x5, âge 10) : modèle Blender, lot CALC-SALLE-BLANCHE (30/10). S'exécute DANS Blender.

Repère (tools/render/README.md) : 1 unité = 1 tuile en X ; y de JEU vers le NORD (yn) -> Y Blender = yn × √2 ; z en
unités (1 unité = 45,25 px HR à l'écran). Emprise : x et yn de −2,5 à +2,5. La caméra regarde du SUD : ne se voient que
les DESSUS et les faces SUD (les faces est, ouest et nord ne comptent que pour l'ombre).

Langage (DESIGN_EPOQUES, âge 10, ère IV) : volume clos et lisse gris clair / noir mat, sas, filtres à air (FFU) et
centrales de traitement d'air sur le toit, baies montrant l'intérieur AMBRE (éclairage inactinique de lithographie),
voyants bleus, pieds courts. Quatre SILHOUETTES (s1 à s4) partagent les pièces ci-dessous ; seule change la masse.

Les voyants enregistrent leur position à l'écran (c.leds : u, v en px HR relatifs à l'entité, groupe) : feuilles.py
s'en sert pour découper la couche lueur en groupes qui clignotent (animation de travail, frame_sequence de l'âge 10).
"""
import math

from mathutils import Vector as V

from kit import SQ2, TAU

GROUPES_LED = 3


def B(x, yn, z=0.0):
    return V((x, yn * SQ2, z))


class Ctx:
    def __init__(self, g, C, M):
        self.g, self.C, self.M = g, C, M
        self.leds = []
        self.rng = g.rng


# ---------------------------------------------------------------------------------------------------------------------
# primitives en coordonnées de jeu
# ---------------------------------------------------------------------------------------------------------------------
def bx(g, x0, x1, y0, y1, z0, z1, m, style="hard", what="box"):
    g.box(((x0 + x1) / 2.0, (y0 + y1) / 2.0 * SQ2, (z0 + z1) / 2.0), (x1 - x0, (y1 - y0) * SQ2, z1 - z0), m, style,
          what=what)


def prisme_x(g, x0, x1, pts, m, style="hard", what="prisme"):
    """Polygone [(yn, z)] extrudé de x0 à x1 (normales recalculées à la création)."""
    P = [(y * SQ2, z) for y, z in pts]
    n = len(P)
    vs = [(x0, y, z) for y, z in P] + [(x1, y, z) for y, z in P]
    fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, n + j, n + i))
    g._add(m, style, vs, fs, what)


def face_sud(x0, x1, yn, z0, z1):
    return (B(x0, yn, z0), B(x1, yn, z0), B(x1, yn, z1), B(x0, yn, z1))


def dessus(x0, x1, y0, y1, z):
    return (B(x0, y0, z), B(x1, y0, z), B(x1, y1, z), B(x0, y1, z))


def led(c, x, yn, z, grp, s=0.13, sur="sud"):
    """Voyant carré (au moins 8 px HR, règle D2-1) dans un cadre noir, sur une face sud ou sur un dessus."""
    g, M = c.g, c.M
    if sur == "sud":
        bx(g, x - s * 0.75, x + s * 0.75, yn - 0.02, yn + 0.01, z - s * 0.75, z + s * 0.75, M["sb_noir"], "hard",
           "cadre_led")
        bx(g, x - s / 2, x + s / 2, yn - 0.035, yn - 0.015, z - s / 2, z + s / 2, M["emit"], "flat", "led")
        p = B(x, yn - 0.03, z)
    else:
        bx(g, x - s * 0.75, x + s * 0.75, yn - s * 0.75, yn + s * 0.75, z, z + 0.025, M["sb_noir"], "hard",
           "cadre_led")
        bx(g, x - s / 2, x + s / 2, yn - s / 2, yn + s / 2, z + 0.02, z + 0.04, M["emit"], "flat", "led")
        p = B(x, yn, z + 0.04)
    w = g.W(p)
    u, v = c.C.blender_to_screen_px(w.x, w.y, w.z)
    c.leds.append((round(u, 2), round(v, 2), int(grp)))


def rampe_leds(c, x0, x1, yn, z, pas=0.42, s=0.12):
    """Bandeau noir et voyants bleus sur une face sud (groupes alternés : chenillard lent)."""
    g, M = c.g, c.M
    bx(g, x0, x1, yn - 0.03, yn + 0.01, z - 0.11, z + 0.11, M["sb_noir"], "hard", "bandeau")
    n = max(2, int((x1 - x0 - 0.2) / pas) + 1)
    for i in range(n):
        x = x0 + 0.12 + (x1 - x0 - 0.24) * i / (n - 1)
        led(c, x, yn - 0.03, z, i % GROUPES_LED, s=s)


# ---------------------------------------------------------------------------------------------------------------------
# pièces
# ---------------------------------------------------------------------------------------------------------------------
def socle(c, x0, x1, y0, y1, lift, pieds=4):
    """Corps LEVÉ (âge 10) : plinthe noire en retrait et pieds courts en acier, semelles."""
    g, M = c.g, c.M
    r = 0.16
    bx(g, x0 + r, x1 - r, y0 + r, y1 - r, 0.0, lift + 0.01, M["sb_noir"], "hard", "plinthe")
    xs = [x0 + 0.13, x1 - 0.13] if pieds <= 4 else [x0 + 0.13, (x0 + x1) / 2.0, x1 - 0.13]
    ys = [y0 + 0.13, y1 - 0.13]
    for x in xs:
        for y in ys:
            bx(g, x - 0.15, x + 0.15, y - 0.15, y + 0.15, 0.0, 0.035, M["anthracite"], "hard", "semelle")
            bx(g, x - 0.09, x + 0.09, y - 0.09, y + 0.09, 0.035, lift + 0.01, M["acier_tech"], "hard", "pied")
            for dx, dy in ((-0.11, -0.11), (0.11, -0.11), (0.11, 0.11), (-0.11, 0.11)):
                g.bolt(B(x + dx, y + dy, 0.035), (0, 0, 1), 0.017, M["rivet_tech"])


def coque(c, x0, x1, y0, y1, z0, z1, nu=None, nv_s=2, nv_t=None, mat="sb_panneau"):
    """Caisson lisse : âme sombre + bardage de panneaux clairs à joints fins sur la face sud et le dessus."""
    g, M = c.g, c.M
    bx(g, x0, x1, y0, y1, z0, z1, M["gris_tech"], "soft", "ame")
    nu = nu or max(2, int(round((x1 - x0) / 0.62)))
    nv_t = nv_t or max(2, int(round((y1 - y0) / 0.62)))
    mats = [M[mat], M[mat], M[mat + "2"]]
    g.panels(face_sud(x0 + 0.02, x1 - 0.02, y0, z0 + 0.02, z1 - 0.02), nu, nv_s, M[mat], t=0.014, gap=0.018,
             rivet_mat=None, jitter=0.0, mats=mats, what="bardage")
    g.panels(dessus(x0 + 0.02, x1 - 0.02, y0 + 0.02, y1 - 0.02, z1), nu, nv_t, M[mat], t=0.014, gap=0.018,
             rivet_mat=None, jitter=0.0, mats=mats, what="toit")


def acrotere(c, x0, x1, y0, y1, z, h=0.07, w=0.06, m="sb_panneau2"):
    g, M = c.g, c.M
    for a in ((x0, x1, y0, y0 + w), (x0, x1, y1 - w, y1), (x0, x0 + w, y0, y1), (x1 - w, x1, y0, y1)):
        bx(g, a[0], a[1], a[2], a[3], z, z + h, M[m], "hard", "acrotere")


def ffu(c, x, yn, z, s=0.62):
    """Filtre à air à ventilateur (FFU) : caisson carré, grille ronde, moyeu, barreaux."""
    g, M = c.g, c.M
    h = s / 2.0
    bx(g, x - h, x + h, yn - h, yn + h, z, z + 0.07, M["gris_tech"], "hard", "ffu_caisson")
    bx(g, x - h + 0.035, x + h - 0.035, yn - h + 0.035, yn + h - 0.035, z + 0.07, z + 0.085, M["sb_panneau"], "hard",
       "ffu_capot")
    R = h * 0.74
    ctr = B(x, yn, z + 0.09)
    g.cyl(ctr, "z", R, 0.012, M["sb_noir"], n=24, style="flat", what="ffu_fond")
    g.torus(ctr + V((0, 0, 0.012)), "z", R, 0.022, M["acier_tech"], n=24, m=6, what="ffu_bague")
    for k in range(5):
        t = -R * 0.8 + R * 1.6 * k / 4
        L = math.sqrt(max(0.0, R * R - t * t)) * 0.95
        g.box((x, yn * SQ2 + t, z + 0.105), (2 * L, 0.036, 0.02), M["acier_tech"], "hard", what="ffu_barreau")
    g.cyl(ctr + V((0, 0, 0.03)), "z", R * 0.22, 0.04, M["rivet_tech"], n=12, style="soft", what="ffu_moyeu")
    for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        g.dome(B(x + dx * (h - 0.06), yn + dy * (h - 0.06), z + 0.085), (0, 0, 1), 0.016, M["rivet_tech"])


def grille_ffu(c, x0, x1, y0, y1, z, nx, ny, allee=None):
    g, M = c.g, c.M
    sx, sy = (x1 - x0) / nx, (y1 - y0) / ny
    s = min(sx, sy) - 0.06
    for i in range(nx):
        for j in range(ny):
            if allee is not None and i == allee:
                continue
            ffu(c, x0 + sx * (i + 0.5), y0 + sy * (j + 0.5), z, s)
    if allee is not None:
        xa = x0 + sx * (allee + 0.5)
        caillebotis(c, xa - sx * 0.32, xa + sx * 0.32, y0 + 0.04, y1 - 0.04, z)


def caillebotis(c, x0, x1, y0, y1, z):
    """Passerelle de toit : cadre et lames de caillebotis."""
    g, M = c.g, c.M
    bx(g, x0, x1, y0, y1, z, z + 0.02, M["sb_noir"], "flat", "passerelle_fond")
    n = max(3, int((y1 - y0) / 0.07))
    for k in range(n):
        y = y0 + (y1 - y0) * (k + 0.5) / n
        bx(g, x0 + 0.03, x1 - 0.03, y - 0.017, y + 0.017, z + 0.02, z + 0.045, M["grate"], "hard", "lame")
    for xx in (x0, x1 - 0.035):
        bx(g, xx, xx + 0.035, y0, y1, z + 0.02, z + 0.06, M["acier_tech"], "hard", "longeron")


def cta(c, x0, x1, y0, y1, z, h, ventilos=2, leds_grp=0):
    """Centrale de traitement d'air : caisson, persiennes au sud, ventilateurs ronds sur le dessus, voyants."""
    g, M = c.g, c.M
    bx(g, x0, x1, y0, y1, z, z + 0.05, M["anthracite"], "hard", "cta_socle")
    coque(c, x0 + 0.03, x1 - 0.03, y0 + 0.03, y1 - 0.03, z + 0.05, z + h, nv_s=1, mat="sb_panneau")
    zt = z + h
    w = x1 - x0
    nl = max(1, int(w / 0.75))
    for k in range(nl):
        a = x0 + 0.12 + (w - 0.24) * k / nl
        b = x0 + 0.12 + (w - 0.24) * (k + 1) / nl - 0.07
        g.grille(face_sud(a, b, y0 + 0.03 - 0.016, z + 0.12, zt - 0.14), 5, depth=0.03, slat_mat=M["acier_tech"])
    d = (y1 - y0)
    R = min(w / ventilos, d) * 0.36
    for k in range(ventilos):
        xc = x0 + w * (k + 0.5) / ventilos
        yc = (y0 + y1) / 2.0
        ctr = B(xc, yc, zt)
        g.cyl(ctr + V((0, 0, 0.04)), "z", R * 1.12, 0.08, M["gris_tech"], n=28, style="soft", what="virole")
        g.cyl(ctr + V((0, 0, 0.085)), "z", R, 0.012, M["sb_noir"], n=28, style="flat", what="ventilo_fond")
        for i in range(6):
            a = TAU * i / 6 + 0.3
            p0 = ctr + V((0, 0, 0.095))
            g.box(tuple(p0 + V((math.cos(a) * R * 0.5, math.sin(a) * R * 0.5, 0))), (R * 0.9, 0.05, 0.012),
                  M["acier_tech"], "hard", R=_rotz(a), what="pale")
        g.torus(ctr + V((0, 0, 0.1)), "z", R, 0.02, M["acier_tech"], n=28, m=6, what="ventilo_bague")
        g.cyl(ctr + V((0, 0, 0.11)), "z", R * 0.2, 0.04, M["rivet_tech"], n=12, style="soft", what="moyeu")
        for i in range(2):
            a = TAU * i / 4 + TAU / 8
            g.box(tuple(ctr + V((0, 0, 0.115))), (2.02 * R, 0.035, 0.018), M["acier_tech"], "hard", R=_rotz(a),
                  what="croisillon")
    led(c, x1 - 0.14, y0 + 0.03 - 0.02, zt - 0.1, leds_grp, s=0.11)
    led(c, x1 - 0.32, y0 + 0.03 - 0.02, zt - 0.1, (leds_grp + 1) % GROUPES_LED, s=0.11)


def _rotz(a):
    from mathutils import Matrix
    return Matrix.Rotation(a, 3, "Z")


def gaine(c, x0, x1, y0, y1, z0, z1, m="gris_tech"):
    """Gaine rectangulaire avec brides tous les 0,5."""
    g, M = c.g, c.M
    bx(g, x0, x1, y0, y1, z0, z1, M[m], "soft", "gaine")
    longx = (x1 - x0) >= (y1 - y0)
    L = (x1 - x0) if longx else (y1 - y0)
    n = max(1, int(L / 0.5))
    for k in range(n + 1):
        t = k / n
        if longx:
            x = x0 + 0.03 + (x1 - x0 - 0.06) * t
            bx(g, x - 0.02, x + 0.02, y0 - 0.025, y1 + 0.025, z0 - 0.0, z1 + 0.025, M["acier_tech"], "hard", "bride")
        else:
            y = y0 + 0.03 + (y1 - y0 - 0.06) * t
            bx(g, x0 - 0.025, x1 + 0.025, y - 0.02, y + 0.02, z0, z1 + 0.025, M["acier_tech"], "hard", "bride")


def cheminee(c, x, yn, z, r, h):
    """Cheminée d'extraction (laveur de gaz) : fût, cerclages, chapeau, échelle de visite."""
    g, M = c.g, c.M
    g.cyl(B(x, yn, z + 0.06), "z", r * 1.35, 0.12, M["anthracite"], n=24, style="soft", what="embase")
    g.cyl(B(x, yn, z + h / 2), "z", r, h, M["sb_panneau"], n=28, style="smooth", what="fut")
    for k in range(4):
        zz = z + 0.25 + (h - 0.4) * k / 3
        g.torus(B(x, yn, zz), "z", r + 0.008, 0.022, M["acier_tech"], n=28, m=6, what="cerclage")
    g.tube_shell(B(x, yn, z + h + 0.03), "z", r * 1.06, r * 0.8, 0.06, M["anthracite"], n=28, what="levre")
    g.cyl(B(x, yn, z + h + 0.01), "z", r * 0.8, 0.02, M["sb_noir"], n=24, style="flat", what="bouche")
    g.tube_shell(B(x, yn, z + h * 0.62), "z", r * 1.08, r, 0.14, M["bleu_tech"], n=28, what="bande_bleue")


def tuyau_x(c, x0, x1, yn, z, r, m="acier_tech", supports=True):
    g, M = c.g, c.M
    g.cyl(B((x0 + x1) / 2, yn, z), "x", r, x1 - x0, M[m], n=14, style="smooth", what="tuyau")
    n = max(1, int((x1 - x0) / 0.7))
    for k in range(n + 1):
        x = x0 + 0.06 + (x1 - x0 - 0.12) * k / n
        g.cyl(B(x, yn, z), "x", r * 1.35, 0.04, M["anthracite"], n=14, style="hard", what="collier")
        if supports:
            bx(g, x - 0.025, x + 0.025, yn - 0.03, yn + 0.03, z - r - 0.2, z - r, M["anthracite"], "hard",
               "support")


def goulotte(c, x0, x1, yn, z, w=0.16):
    """Goulotte de câbles (rouge et bleu, accent de l'âge 10) posée sur le toit."""
    g, M = c.g, c.M
    bx(g, x0, x1, yn - w / 2, yn + w / 2, z, z + 0.02, M["anthracite"], "hard", "goulotte")
    for s in (-1, 1):
        bx(g, x0, x1, yn + s * w / 2 - 0.016, yn + s * w / 2 + 0.016, z, z + 0.06, M["anthracite"], "hard",
           "goulotte_bord")
    for k, m in enumerate(("cable_r", "cable_b", "cable_b", "cable_r")):
        yy = yn - w / 2 + 0.035 + (w - 0.07) * k / 3
        g.cyl(B((x0 + x1) / 2, yy, z + 0.04), "x", 0.017, x1 - x0, M[m], n=8, style="smooth", what="cable")


def boitier(c, x, yn, z, w=0.22, h=0.18, d=0.08):
    """Coffret électrique sur une face sud : porte, poignée, étiquette."""
    g, M = c.g, c.M
    bx(g, x - w / 2, x + w / 2, yn - d, yn, z, z + h, M["gris_tech"], "hard", "coffret")
    bx(g, x - w / 2 + 0.02, x + w / 2 - 0.02, yn - d - 0.01, yn - d, z + 0.02, z + h - 0.02, M["sb_panneau2"],
       "hard", "porte_coffret")
    bx(g, x + w / 2 - 0.06, x + w / 2 - 0.035, yn - d - 0.025, yn - d - 0.01, z + h * 0.35, z + h * 0.65,
       M["sb_noir"], "hard", "poignee")
    bx(g, x - w / 2 + 0.04, x - 0.01, yn - d - 0.014, yn - d - 0.01, z + h - 0.07, z + h - 0.04, M["bleu_tech"],
       "flat", "etiquette")


def baie(c, x0, x1, yn, z0, z1, prof=0.2, nb=3, interieur=True, halo_k=1.0):
    """BAIE VITRÉE vers l'intérieur ambre : à poser dans une OUVERTURE de la façade (l'âme est en retrait de prof).
    Fond lumineux ambre (éteint dans la couche principale, la lueur seule le colore), silhouettes noires de l'outillage
    (photorépéteur, colonne optique, robot), meneaux et appui."""
    g, M = c.g, c.M
    yb = yn + prof
    bx(g, x0, x1, yb - 0.02, yb, z0, z1, M["sb_ambre"], "flat", "fond_ambre")
    bx(g, x0 - 0.02, x1 + 0.02, yn, yb, z0 - 0.02, z0, M["sb_noir"], "hard", "tableau_bas")
    bx(g, x0 - 0.02, x1 + 0.02, yn, yb, z1, z1 + 0.02, M["sb_noir"], "hard", "tableau_haut")
    if interieur:
        w = x1 - x0
        k = 0
        x = x0 + 0.1
        while x < x1 - 0.25:
            ww = min(0.3 + 0.12 * c.rng.random(), x1 - 0.06 - x)
            hh = (z1 - z0) * (0.28 + 0.2 * c.rng.random())
            bx(g, x, x + ww, yb - 0.17, yb - 0.04, z0, z0 + hh, M["sb_noir"], "hard", "outil_int")
            if k % 2 == 0:
                cx = x + ww * 0.5
                g.cyl(B(cx, yb - 0.1, z0 + hh + (z1 - z0) * 0.2), "z", 0.05, (z1 - z0) * 0.4, M["sb_noir"], n=10,
                      style="smooth", what="colonne_int")
                bx(g, cx - 0.09, cx + 0.09, yb - 0.15, yb - 0.05, z0 + hh + (z1 - z0) * 0.38,
                   z0 + hh + (z1 - z0) * 0.46, M["sb_noir"], "hard", "tete_int")
            x += ww + 0.12 + 0.1 * c.rng.random()
            k += 1
        bx(g, x0, x1, yb - 0.19, yb - 0.02, z1 - 0.07, z1, M["sb_noir"], "hard", "rampe_int")
    # meneaux et traverse (front de la baie), appui saillant
    for i in range(nb + 1):
        x = x0 + (x1 - x0) * i / nb
        bx(g, x - 0.025, x + 0.025, yn - 0.03, yn + 0.02, z0, z1, M["sb_panneau2"], "hard", "meneau")
    zt = z0 + (z1 - z0) * 0.72
    bx(g, x0, x1, yn - 0.03, yn + 0.02, zt - 0.018, zt + 0.018, M["sb_panneau2"], "hard", "traverse")
    bx(g, x0 - 0.05, x1 + 0.05, yn - 0.07, yn + 0.02, z0 - 0.04, z0, M["sb_panneau2"], "hard", "appui")
    for i in range(nb):
        x = x0 + (x1 - x0) * (i + 0.5) / nb
        g.halo(tuple(B(x, yn - 0.45, z0 + 0.25)), (1.0, 0.68, 0.22), 7.0 * halo_k)


def facade(c, x0, x1, yn, z0, z1, prof, baies, nb_meneaux=None):
    """Façade sud à ouvertures. baies : [(xa, xb, za, zb)] ; pose les trumeaux, allèges et linteaux autour, à la
    profondeur prof (l'âme du caisson commence à yn + prof)."""
    g, M = c.g, c.M
    ys0, ys1 = yn, yn + prof
    xs = sorted(baies)
    x = x0
    for (xa, xb, za, zb) in xs:
        if xa - x > 0.01:
            bx(g, x, xa, ys0, ys1, z0, z1, M["sb_panneau"], "soft", "trumeau")
        bx(g, xa, xb, ys0, ys1, z0, za, M["sb_panneau"], "soft", "allege")
        bx(g, xa, xb, ys0, ys1, zb, z1, M["sb_panneau"], "soft", "linteau")
        x = xb
    if x1 - x > 0.01:
        bx(g, x, x1, ys0, ys1, z0, z1, M["sb_panneau"], "soft", "trumeau")
    # joints verts. de bardage (rainures noires) sur les trumeaux et les allèges
    for (xa, xb, za, zb) in xs:
        nb = nb_meneaux or max(2, int(round((xb - xa) / 0.55)))
        baie(c, xa, xb, ys0, za, zb, prof=prof, nb=nb)


def sas(c, x0, x1, y0, y1, z0, h):
    """SAS (vestiaire, douche d'air) en saillie au sud : caisson, porte vitrée ambre, feu d'état, bande bleue."""
    g, M = c.g, c.M
    coque(c, x0, x1, y0, y1, z0, z0 + h, nv_s=1, mat="sb_panneau")
    xm = (x0 + x1) / 2
    dw = min(0.42, (x1 - x0) * 0.45)
    zd = z0 + 0.04
    bx(g, xm - dw / 2 - 0.05, xm + dw / 2 + 0.05, y0 - 0.04, y0 + 0.01, zd, zd + h * 0.78, M["acier_tech"], "hard",
       "huisserie")
    bx(g, xm - dw / 2, xm + dw / 2, y0 - 0.05, y0 - 0.03, zd, zd + h * 0.74, M["sb_noir"], "hard", "porte")
    bx(g, xm - dw / 2 + 0.06, xm + dw / 2 - 0.06, y0 - 0.06, y0 - 0.045, zd + h * 0.38, zd + h * 0.66,
       M["sb_ambre"], "flat", "hublot_porte")
    bx(g, xm + dw / 2 - 0.08, xm + dw / 2 - 0.05, y0 - 0.075, y0 - 0.05, zd + h * 0.3, zd + h * 0.4,
       M["acier_tech"], "hard", "poignee")
    g.halo(tuple(B(xm, y0 - 0.4, zd + 0.3)), (1.0, 0.68, 0.22), 3.0)
    led(c, xm, y0 - 0.05, zd + h * 0.86, 0, s=0.12)
    for xx in (x0 + 0.05, x1 - 0.05 - 0.035):
        bx(g, xx, xx + 0.035, y0 - 0.03, y0, z0, z0 + h, M["sb_noir"], "hard", "joint_angle")
    # toit du sas : petit groupe de soufflage de la douche d'air
    zt = z0 + h
    cx0, cx1 = x0 + 0.12, x1 - 0.12
    bx(g, cx0, cx1, y0 + 0.12, y1 - 0.15, zt, zt + 0.16, M["gris_tech"], "soft", "souffleur")
    g.grille(face_sud(cx0 + 0.06, cx1 - 0.06, y0 + 0.12 - 0.012, zt + 0.03, zt + 0.13), 3, depth=0.02,
             slat_mat=M["acier_tech"])


def bande(c, x0, x1, yn, z, h=0.07):
    """Bande bleue de l'âge (peinture bleu_tech) sur une face sud."""
    bx(c.g, x0, x1, yn - 0.012, yn + 0.004, z, z + h, c.M["bleu_tech"], "flat", "bande")


# ---------------------------------------------------------------------------------------------------------------------
# SILHOUETTES
# ---------------------------------------------------------------------------------------------------------------------
def s1(c):
    """HANGAR : une seule masse basse et large ; toit couvert d'une grille de FFU (3 × 2) et d'une passerelle ;
    centrales d'air au nord ; baie ambre sur toute la façade ; sas en saillie au sud-ouest ; cheminée au nord-est."""
    g, M = c.g, c.M
    X0, X1, Y0, Y1 = -2.36, 2.36, -1.92, 2.32
    L = 0.16
    H = L + 1.38
    P = 0.22
    socle(c, X0, X1, Y0, Y1, L, pieds=6)
    coque(c, X0, X1, Y0 + P, Y1, L, H)
    facade(c, X0, X1, Y0, L, H, P, [(-0.62, 2.12, L + 0.36, H - 0.34)])
    acrotere(c, X0, X1, Y0, Y1, H)
    bx(g, X0, X1, Y0, Y0 + P + 0.05, H, H + 0.015, M["sb_panneau2"], "hard", "couvertine")
    rampe_leds(c, -0.62, 2.12, Y0, H - 0.17)
    bande(c, X0 + 0.02, X1 - 0.02, Y0, L + 0.17)
    sas(c, -2.12, -0.86, -2.42, Y0, L, 1.02)
    boitier(c, -0.36, Y0, L + 0.4)
    grille_ffu(c, X0 + 0.12, X1 - 0.12, Y0 + 0.12, 0.62, H, 4, 2, allee=1)
    cta(c, -2.18, -0.28, 1.0, 2.14, H, 0.62, ventilos=2, leds_grp=1)
    cta(c, 0.05, 1.25, 1.0, 2.14, H, 0.5, ventilos=1, leds_grp=2)
    gaine(c, -1.6, -1.2, 0.62, 1.0, H, H + 0.3)
    gaine(c, 0.45, 0.85, 0.62, 1.0, H, H + 0.26)
    cheminee(c, 1.82, 1.6, H, 0.24, 1.2)
    goulotte(c, X0 + 0.15, 1.45, 0.82, H)
    tuyau_x(c, 1.4, X1 - 0.08, 2.2, H + 0.25, 0.06)


def s2(c):
    """GRADINS : annexe basse au sud (sas, vestiaires) et grande halle haute au nord ; la façade de la halle montre
    un large BANDEAU AMBRE au-dessus du toit de l'annexe ; FFU sur les deux toits ; cheminée haute au nord-est."""
    g, M = c.g, c.M
    X0, X1 = -2.36, 2.36
    L = 0.16
    Ya0, Ya1 = -2.3, -0.42          # annexe
    Yh0, Yh1 = -0.42, 2.34          # halle
    Ha = L + 0.92
    Hh = L + 2.05
    P = 0.2
    socle(c, X0, X1, Ya0, Yh1, L, pieds=6)
    # halle
    coque(c, X0, X1, Yh0 + P, Yh1, L, Hh)
    facade(c, X0, X1, Yh0, L, Hh, P, [(-2.05, 2.05, Ha + 0.2, Hh - 0.3)], nb_meneaux=8)
    acrotere(c, X0, X1, Yh0, Yh1, Hh)
    rampe_leds(c, -2.0, 2.0, Yh0, Hh - 0.15, pas=0.5)
    # annexe
    coque(c, X0 + 0.1, X1 - 0.1, Ya0 + P, Yh0 + 0.02, L, Ha)
    facade(c, X0 + 0.1, X1 - 0.1, Ya0, L, Ha, P, [(0.25, 1.15, L + 0.3, Ha - 0.2), (1.35, 2.15, L + 0.3, Ha - 0.2)],
           nb_meneaux=2)
    acrotere(c, X0 + 0.1, X1 - 0.1, Ya0, Yh0 + 0.02, Ha)
    bande(c, X0 + 0.12, X1 - 0.12, Ya0, L + 0.12)
    sas(c, -1.95, -0.85, -2.46, Ya0 + 0.01, L, 0.78)
    boitier(c, -0.35, Ya0, L + 0.3)
    led(c, -0.05, Ya0 - 0.02, Ha - 0.16, 1)
    grille_ffu(c, X0 + 0.2, X1 - 0.2, Ya0 + 0.3, Yh0 - 0.06, Ha, 6, 1)
    # toit de la halle
    grille_ffu(c, X0 + 0.12, 0.9, Yh0 + 0.12, 1.2, Hh, 4, 2, allee=2)
    cta(c, -2.15, -0.15, 1.3, 2.2, Hh, 0.55, ventilos=2, leds_grp=2)
    gaine(c, -1.4, -1.05, 1.2, 1.3, Hh, Hh + 0.3)
    cta(c, 1.05, 2.18, -0.2, 0.75, Hh, 0.45, ventilos=1, leds_grp=0)
    cheminee(c, 1.62, 1.7, Hh, 0.26, 1.35)
    goulotte(c, 0.1, 1.2, 1.55, Hh)
    tuyau_x(c, X0 + 0.1, 1.2, 2.22, Hh + 0.22, 0.055)


def s3(c):
    """VOÛTE : murs bas et toit en berceau surbaissé (faîte est-ouest) ; bandeau AMBRE dans la pente sud de la
    voûte ; lanterneau de FFU sur le faîte ; centrales d'air aux deux bouts ; sas au sud."""
    g, M = c.g, c.M
    X0, X1 = -2.36, 2.36
    Y0, Y1 = -1.95, 2.3
    L = 0.16
    Hm = L + 0.72
    rise = 1.05
    socle(c, X0, X1, Y0, Y1, L, pieds=6)
    xv0, xv1 = X0 + 0.55, X1 - 0.55
    # murs bas (pignons couverts par les centrales d'air)
    coque(c, X0, X1, Y0 + 0.2, Y1, L, Hm)
    facade(c, X0, X1, Y0, L, Hm, 0.2, [(-0.4, 1.95, L + 0.2, Hm - 0.14)], nb_meneaux=5)
    bande(c, X0 + 0.02, X1 - 0.02, Y0, L + 0.1, h=0.05)
    # voûte : arc de cercle de la corde (Y0+0.2 -> Y1) et de flèche rise
    half = (Y1 - Y0 - 0.2) / 2.0 * SQ2
    yc = (Y0 + 0.2 + Y1) / 2.0
    R = (half ** 2 + rise ** 2) / (2 * rise)
    zc = Hm + rise - R
    a0 = math.asin(half / R)
    N = 24

    def arc(rr, a_from, a_to, n):
        return [(yc + rr * math.sin(a) / SQ2, zc + rr * math.cos(a)) for a in
                [a_from + (a_to - a_from) * i / n for i in range(n + 1)]]
    pts = arc(R, -a0, a0, N)
    prisme_x(g, xv0, xv1, [(yc - half / SQ2, Hm)] + pts + [(yc + half / SQ2, Hm)], M["gris_tech"], "smooth", "voute")
    # bardage en lames de la voûte (côtes) : panneaux courbes séparés par des joints
    nlam = 7
    for i in range(nlam):
        xa = xv0 + (xv1 - xv0) * i / nlam + 0.012
        xb = xv0 + (xv1 - xv0) * (i + 1) / nlam - 0.012
        outer = arc(R + 0.03, -a0, a0, N)
        inner = arc(R + 0.002, a0, -a0, N)
        prisme_x(g, xa, xb, outer + inner, M["sb_panneau"] if i % 3 else M["sb_panneau2"], "smooth", "lame_voute")
    # bandeau ambre dans la pente sud (angle -a0*0.78 à -a0*0.35)
    aa, ab = -a0 * 0.8, -a0 * 0.42
    for i in range(nlam):
        if i in (0,):
            continue
        xa = xv0 + (xv1 - xv0) * i / nlam + 0.07
        xb = xv0 + (xv1 - xv0) * (i + 1) / nlam - 0.07
        win = arc(R + 0.05, aa, ab, 6) + arc(R + 0.035, ab, aa, 6)
        prisme_x(g, xa, xb, win, M["sb_ambre"], "smooth", "verriere")
        xm = (xa + xb) / 2
        win2 = arc(R + 0.06, aa, ab, 6) + arc(R + 0.03, ab, aa, 6)
        prisme_x(g, xm - 0.02, xm + 0.02, win2, M["sb_panneau2"], "smooth", "meneau_verriere")
        ym, zm = arc(R, (aa + ab) / 2, (aa + ab) / 2, 1)[0]
        g.halo(tuple(B(xm, Y0 - 0.5, 0.6)), (1.0, 0.68, 0.22), 5.0)
    # lanterneau de faîte : rangée de FFU
    zr = zc + R + 0.03
    bx(g, xv0 + 0.1, xv1 - 0.1, yc - 0.42, yc + 0.42, zr - 0.08, zr + 0.06, M["anthracite"], "hard", "lanterneau")
    n = 6
    for i in range(n):
        xx = xv0 + 0.1 + (xv1 - xv0 - 0.2) * (i + 0.5) / n
        ffu(c, xx, yc, zr + 0.06, s=min(0.56, (xv1 - xv0 - 0.2) / n - 0.05))
    # centrales d'air en pignons
    cta(c, X0, xv0 + 0.05, Y0 + 0.4, Y1 - 0.2, Hm, 1.0, ventilos=1, leds_grp=0)
    cta(c, xv1 - 0.05, X1, Y0 + 0.4, Y1 - 0.2, Hm, 1.0, ventilos=1, leds_grp=1)
    sas(c, -2.15, -0.75, -2.42, Y0, L, 0.66)
    boitier(c, -0.6, Y0, L + 0.25)
    for x in (-0.25, 0.6, 1.4):
        led(c, x, Y0 - 0.02, Hm - 0.07, int(x * 3) % GROUPES_LED, s=0.1)
    cheminee(c, X1 - 0.3, Y1 - 0.45, Hm + 1.0, 0.16, 0.6)


def s4(c):
    """SUR PIEDS : le caisson de la salle est levé sur une forêt de pieds au-dessus du « sub-fab » (pompes, cuves,
    collecteurs visibles dessous) ; toit à deux grands ventilateurs ronds et FFU ; baie ambre ; escalier vers le sas."""
    g, M = c.g, c.M
    X0, X1, Y0, Y1 = -2.36, 2.36, -1.75, 2.32
    L = 0.55
    H = L + 1.22
    P = 0.2
    # dalle et pieds
    bx(g, X0 + 0.05, X1 - 0.05, Y0 + 0.05, Y1 - 0.05, 0.0, 0.05, M["anthracite"], "hard", "dalle")
    for x in (X0 + 0.15, -0.8, 0.8, X1 - 0.15):
        for y in (Y0 + 0.15, 0.3, Y1 - 0.15):
            bx(g, x - 0.1, x + 0.1, y - 0.1, y + 0.1, 0.05, L, M["acier_tech"], "hard", "pied")
            bx(g, x - 0.15, x + 0.15, y - 0.15, y + 0.15, 0.05, 0.09, M["anthracite"], "hard", "semelle")
    # sub-fab : pompes, cuves, collecteur
    for i, x in enumerate((-1.6, -0.4, 0.4, 1.6)):
        g.cyl(B(x, -0.9, 0.05 + 0.17), "z", 0.17, 0.34, M["gris_tech"], n=18, style="soft", what="pompe")
        g.cyl(B(x, -0.9, 0.05 + 0.36), "z", 0.1, 0.06, M["acier_tech"], n=14, style="soft", what="moteur")
        bx(g, x - 0.16, x + 0.16, -0.62, -0.42, 0.05, 0.28, M["sb_noir"], "hard", "skid")
    g.cyl(B(0, -0.3, 0.38), "x", 0.07, X1 - X0 - 0.4, M["acier_tech"], n=14, what="collecteur")
    for x in (-1.0, 1.0):
        g.cyl(B(x, 0.9, 0.05 + 0.24), "z", 0.3, 0.48, M["sb_panneau2"], n=24, style="smooth", what="cuve")
    coque(c, X0, X1, Y0 + P, Y1, L, H)
    facade(c, X0, X1, Y0, L, H, P, [(-1.3, 2.1, L + 0.26, H - 0.3)], nb_meneaux=6)
    bx(g, X0, X1, Y0, Y0 + P, L - 0.06, L, M["sb_noir"], "hard", "sous_face")
    acrotere(c, X0, X1, Y0, Y1, H)
    rampe_leds(c, -1.3, 2.1, Y0, H - 0.15)
    bande(c, X0 + 0.02, X1 - 0.02, Y0, L + 0.08)
    # palier et escalier du sas (ouest)
    bx(g, -2.3, -1.55, -2.42, Y0, L - 0.04, L, M["grate"], "hard", "palier")
    for x in (-2.24, -1.61):
        bx(g, x - 0.05, x + 0.05, -2.4, -2.3, 0.0, L - 0.04, M["acier_tech"], "hard", "poteau_palier")
    sas(c, -2.3, -1.55, -2.45, Y0, L, 0.95)
    grille_ffu(c, -0.3, X1 - 0.12, Y0 + 0.4, 1.0, H, 3, 2)
    for x, y in ((-1.45, 0.05), (-1.45, 1.55)):
        ctr = B(x, y, H)
        g.cyl(ctr + V((0, 0, 0.12)), "z", 0.62, 0.24, M["gris_tech"], n=36, style="soft", what="virole")
        g.cyl(ctr + V((0, 0, 0.245)), "z", 0.55, 0.012, M["sb_noir"], n=36, style="flat", what="fond")
        for i in range(7):
            a = TAU * i / 7
            g.box(tuple(ctr + V((math.cos(a) * 0.27, math.sin(a) * 0.27, 0.255))), (0.48, 0.07, 0.014),
                  M["acier_tech"], "hard", R=_rotz(a + 0.35), what="pale")
        g.torus(ctr + V((0, 0, 0.25)), "z", 0.56, 0.025, M["acier_tech"], n=36, m=6, what="bague")
        g.cyl(ctr + V((0, 0, 0.28)), "z", 0.1, 0.06, M["rivet_tech"], n=14, style="soft", what="moyeu")
    cta(c, 0.1, 2.2, 1.25, 2.2, H, 0.42, ventilos=2, leds_grp=1)
    cheminee(c, -0.1, 1.95, H, 0.18, 0.9)
    goulotte(c, -0.45, 2.1, 1.1, H)


SILHOUETTES = {"s1": s1, "s2": s2, "s3": s3, "s4": s4}
