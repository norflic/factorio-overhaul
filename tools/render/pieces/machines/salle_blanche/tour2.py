"""SALLE BLANCHE, DEUXIÈME TOUR de silhouettes (r1 à r4, 30/10 vers 11 h 15). S'exécute DANS Blender.

Critique du premier tour (planche sil1 et mesures du corps, hr-sb-sN-main.png) :
  - lecture « toit plat vu d'avion » : le dessus occupe l'essentiel de l'image, façades sud de 44 à 70 px ;
  - trop clair et trop plat : médiane du corps 94 à 117/255 contre 43 (raffinerie), 56 (assembleur 3) et 82 ± 10
    (bible, âge 10) ; p95 147 à 158 : aucun reflet franc ;
  - ambre presque invisible (sauf s3, verrière de toit) ; grille de FFU répétitive (« toit de centre commercial »).
Réponse : plus HAUT (façades sud plus grandes, masses étagées), plus SOMBRE (bardage moyen, ossature noire, arêtes claires
pour les reflets), verrières AMBRE grandes et tournées vers la caméra, rythme de pilastres noirs.
"""
import math

from mathutils import Vector as V

from kit import SQ2, TAU
from modele import (B, GROUPES_LED, _rotz, bande, bx, cheminee, coque, cta, facade, face_sud, ffu, gaine, grille_ffu,
                    led, prisme_x, rampe_leds, sas, socle, acrotere, boitier)


def pilastres(c, x0, x1, yn, z0, z1, pas=0.9, w=0.07):
    g, M = c.g, c.M
    n = max(1, int(round((x1 - x0) / pas)))
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        x = min(max(x, x0 + w / 2), x1 - w / 2)
        bx(g, x - w / 2, x + w / 2, yn - 0.045, yn + 0.005, z0, z1, M["sb_noir"], "hard", "pilastre")


def arete(c, x0, x1, yn, z, w=0.05):
    """Arête claire (couvertine) au bord sud d'un dessus : le reflet franc des bâtiments vanilla."""
    bx(c.g, x0, x1, yn - 0.03, yn + w, z, z + 0.035, c.M["sb_clair"], "soft", "couvertine")


def verriere_sud(c, x0, x1, yn, z0, z1, nb, prof=0.16):
    """Verrière verticale tournée vers le sud : fond ambre, outillage en ombres chinoises, meneaux noirs."""
    g, M = c.g, c.M
    if "sb_ambre2" in M:
        zm = z0 + (z1 - z0) * 0.45
        bx(g, x0, x1, yn + prof - 0.02, yn + prof, zm, z1, M["sb_ambre"], "flat", "fond_ambre")
        bx(g, x0, x1, yn + prof - 0.02, yn + prof, z0, zm, M["sb_ambre2"], "flat", "fond_ambre_bas")
        # rampe d'éclairage au plafond et colonnes optiques : l'intérieur se lit comme un volume
        bx(g, x0, x1, yn + 0.03, yn + prof - 0.02, z1 - 0.07, z1, M["sb_noir"], "hard", "rampe_int")
        for i in range(nb):
            xc = x0 + (x1 - x0) * (i + 0.5) / nb
            bx(g, xc - 0.025, xc + 0.025, yn + 0.05, yn + 0.1, z0 + (z1 - z0) * 0.3, z1 - 0.07, M["sb_noir"], "hard",
               "colonne_int")
    else:
        bx(g, x0, x1, yn, yn + prof, z0, z1, M["sb_ambre"], "flat", "fond_ambre")
    for i in range(nb):
        xa = x0 + (x1 - x0) * (i + 0.15 + 0.2 * c.rng.random()) / nb
        hh = (z1 - z0) * (0.18 + 0.25 * c.rng.random())
        bx(g, xa, xa + (x1 - x0) / nb * 0.45, yn - 0.01, yn + 0.02, z0, z0 + hh, M["sb_noir"], "hard", "outil_int")
    for i in range(nb + 1):
        x = x0 + (x1 - x0) * i / nb
        bx(g, x - 0.03, x + 0.03, yn - 0.05, yn + 0.01, z0, z1, M["sb_noir"], "hard", "meneau")
    bx(g, x0, x1, yn - 0.05, yn + 0.01, z0 - 0.04, z0, M["sb_noir"], "hard", "traverse")
    bx(g, x0, x1, yn - 0.05, yn + 0.01, z1, z1 + 0.04, M["sb_noir"], "hard", "traverse")
    zt = z0 + (z1 - z0) * 0.62
    bx(g, x0, x1, yn - 0.04, yn + 0.01, zt - 0.015, zt + 0.015, M["sb_noir"], "hard", "traverse")
    for i in range(nb):
        g.halo(tuple(B(x0 + (x1 - x0) * (i + 0.5) / nb, yn - 0.5, z0 + 0.2)), (1.0, 0.68, 0.22), 5.0)


def ventilo(c, x, yn, z, R, h=0.14, pales=6, bague="acier_tech"):
    """Grand ventilateur rond d'extraction : virole, fond noir, pales, bague, moyeu."""
    g, M = c.g, c.M
    ctr = B(x, yn, z)
    g.cyl(ctr + V((0, 0, h / 2)), "z", R * 1.12, h, M["gris_tech"], n=36, style="soft", what="virole")
    g.cyl(ctr + V((0, 0, h + 0.005)), "z", R, 0.012, M["sb_noir"], n=36, style="flat", what="fond")
    for i in range(pales):
        a = TAU * i / pales
        g.box(tuple(ctr + V((math.cos(a) * R * 0.48, math.sin(a) * R * 0.48, h + 0.015))), (R * 0.85, 0.065, 0.014),
              M["acier_tech"], "hard", R=_rotz(a + 0.35), what="pale")
    g.torus(ctr + V((0, 0, h + 0.01)), "z", R, 0.024, M[bague], n=36, m=6, what="bague")
    g.cyl(ctr + V((0, 0, h + 0.035)), "z", R * 0.18, 0.05, M["rivet_tech"], n=14, style="soft", what="moyeu")


def r1(c):
    """VOÛTE HAUTE : berceau surbaissé (faîte est-ouest) sur murs à baie ambre ; arcs noirs saillants à chaque travée ;
    grande verrière AMBRE dans la pente sud ; lanterneau de FFU au faîte ; centrales d'air hautes en pignons ; deux
    cheminées d'extraction au nord."""
    g, M = c.g, c.M
    X0, X1, Y0, Y1 = -2.38, 2.38, -2.0, 2.3
    L = 0.16
    Hm = L + 1.0
    rise = 1.45
    socle(c, X0, X1, Y0, Y1, L, pieds=6)
    xv0, xv1 = X0 + 0.62, X1 - 0.62
    coque(c, X0, X1, Y0 + 0.2, Y1, L, Hm)
    facade(c, X0, X1, Y0, L, Hm, 0.2, [(-0.55, 2.0, L + 0.22, Hm - 0.2)], nb_meneaux=6)
    pilastres(c, X0, -0.6, Y0, L, Hm, pas=0.6)
    bande(c, X0 + 0.02, -0.62, Y0 - 0.04, L + 0.5, h=0.06)
    arete(c, X0, X1, Y0, Hm)
    half = (Y1 - Y0 - 0.2) / 2.0 * SQ2
    yc = (Y0 + 0.2 + Y1) / 2.0
    R = (half ** 2 + rise ** 2) / (2 * rise)
    zc = Hm + rise - R
    a0 = math.asin(half / R)
    N = 28

    def arc(rr, a_from, a_to, n):
        return [(yc + rr * math.sin(a) / SQ2, zc + rr * math.cos(a)) for a in
                [a_from + (a_to - a_from) * i / n for i in range(n + 1)]]
    prisme_x(g, xv0, xv1, [(yc - half / SQ2, Hm)] + arc(R, -a0, a0, N) + [(yc + half / SQ2, Hm)], M["gris_tech"],
             "smooth", "voute")
    nlam = 6
    aa, ab = -a0 * 0.86, -a0 * 0.3
    for i in range(nlam):
        xa = xv0 + (xv1 - xv0) * i / nlam
        xb = xv0 + (xv1 - xv0) * (i + 1) / nlam
        prisme_x(g, xa + 0.05, xb - 0.05, arc(R + 0.03, -a0, a0, N) + arc(R + 0.002, a0, -a0, N),
                 M["sb_panneau"] if i % 2 else M["sb_panneau2"], "smooth", "lame_voute")
        prisme_x(g, xa + 0.11, xb - 0.11, arc(R + 0.055, aa, ab, 8) + arc(R + 0.02, ab, aa, 8), M["sb_ambre"],
                 "smooth", "verriere")
        xm = (xa + xb) / 2
        prisme_x(g, xm - 0.025, xm + 0.025, arc(R + 0.07, aa, ab, 8) + arc(R + 0.03, ab, aa, 8), M["sb_noir"],
                 "smooth", "meneau_verriere")
        for at in (aa, (aa + ab) / 2, ab):
            prisme_x(g, xa + 0.11, xb - 0.11, arc(R + 0.075, at - 0.012, at + 0.012, 2)
                     + arc(R + 0.03, at + 0.012, at - 0.012, 2), M["sb_noir"], "smooth", "traverse_verriere")
        g.halo(tuple(B(xm, Y0 - 0.6, 0.5)), (1.0, 0.68, 0.22), 4.0)
    for i in range(nlam + 1):
        x = xv0 + (xv1 - xv0) * i / nlam
        prisme_x(g, x - 0.05, x + 0.05, arc(R + 0.09, -a0, a0, N) + arc(R - 0.01, a0, -a0, N), M["sb_noir"], "smooth",
                 "arc")
    zr = zc + R + 0.05
    bx(g, xv0 + 0.15, xv1 - 0.15, yc - 0.38, yc + 0.5, zr - 0.12, zr + 0.1, M["anthracite"], "hard", "lanterneau")
    n = 5
    for i in range(n):
        xx = xv0 + 0.15 + (xv1 - xv0 - 0.3) * (i + 0.5) / n
        ffu(c, xx, yc + 0.06, zr + 0.1, s=min(0.6, (xv1 - xv0 - 0.3) / n - 0.05))
    cta(c, X0, xv0 + 0.06, Y0 + 0.35, Y1 - 0.15, Hm, 1.35, ventilos=1, leds_grp=0)
    cta(c, xv1 - 0.06, X1, Y0 + 0.35, Y1 - 0.15, Hm, 1.35, ventilos=1, leds_grp=1)
    sas(c, -2.2, -0.85, -2.46, Y0, L, 0.82)
    for x in (-0.3, 0.55, 1.4):
        led(c, x, Y0 - 0.02, Hm - 0.09, int((x + 1) * 2) % GROUPES_LED, s=0.11)
    cheminee(c, X1 - 0.33, Y1 - 0.38, Hm + 1.35, 0.17, 1.0)
    cheminee(c, X0 + 0.33, Y1 - 0.38, Hm + 1.35, 0.13, 0.7)


def r2(c):
    """SHEDS : trois travées en dents de scie dont les faces VERTICALES vitrées (ambre) regardent le sud ; pentes
    bardées vers le nord ; annexe basse au sud (sas, FFU) ; tour de traitement d'air à l'ouest ; cheminée haute."""
    g, M = c.g, c.M
    X0, X1 = -2.38, 2.38
    L = 0.16
    Ya0, Ya1 = -2.3, -1.15
    Y0, Y1 = -1.15, 2.32
    H = L + 1.05
    hs = 0.95
    xs0 = -1.15
    socle(c, X0, X1, Ya0, Y1, L, pieds=6)
    coque(c, xs0, X1, Y0, Y1, L, H, nv_s=2)
    nb = 3
    d = (Y1 - Y0) / nb
    for k in range(nb):
        yS, yN = Y0 + d * k, Y0 + d * (k + 1)
        prisme_x(g, xs0, X1, [(yS + 0.16, H), (yS + 0.16, H + hs), (yN, H + 0.02), (yN, H)], M["gris_tech"], "hard",
                 "shed")
        nl = 6
        for i in range(nl):
            xa = xs0 + (X1 - xs0) * i / nl + 0.012
            xb = xs0 + (X1 - xs0) * (i + 1) / nl - 0.012
            prisme_x(g, xa, xb, [(yS + 0.18, H + hs), (yS + 0.18, H + hs + 0.025), (yN, H + 0.045), (yN, H + 0.02)],
                     M["sb_panneau"] if (i + k) % 3 else M["sb_panneau2"], "hard", "lame_shed")
        bx(g, xs0, X1, yS + 0.1, yS + 0.24, H + hs, H + hs + 0.06, M["sb_clair"], "soft", "faitage")
        verriere_sud(c, xs0 + 0.08, X1 - 0.08, yS + 0.0, H + 0.06, H + hs - 0.05, 7, prof=0.16)
    rampe_leds(c, xs0 + 0.1, X1 - 0.1, Y0, H - 0.12, pas=0.5)
    pilastres(c, xs0, X1, Y0, L, H - 0.24, pas=0.85)
    bande(c, xs0, X1, Y0 - 0.04, L + 0.4, h=0.06)
    coque(c, X0, xs0, Y0 + 0.4, Y1, L, H + 1.25)
    arete(c, X0, xs0, Y0 + 0.4, H + 1.25)
    g.grille(face_sud(X0 + 0.15, xs0 - 0.15, Y0 + 0.4 - 0.02, L + 0.7, H + 1.05), 9, depth=0.035,
             slat_mat=M["acier_tech"])
    pilastres(c, X0, xs0, Y0 + 0.4, L, H + 1.25, pas=1.2)
    for yy in (0.2, 1.45):
        ventilo(c, (X0 + xs0) / 2, yy, H + 1.25, 0.44)
    led(c, X0 + 0.2, Y0 + 0.4 - 0.02, H + 1.12, 2, s=0.11)
    coque(c, X0 + 0.05, X1 - 0.05, Ya0 + 0.12, Ya1 + 0.02, L, L + 0.62, nv_s=1)
    arete(c, X0 + 0.05, X1 - 0.05, Ya0 + 0.12, L + 0.62)
    grille_ffu(c, 0.2, X1 - 0.15, Ya0 + 0.2, Ya1 - 0.05, L + 0.62, 4, 1)
    sas(c, -2.25, -1.05, -2.46, Ya0 + 0.12, L, 0.86)
    for x in (-0.6, -0.15):
        boitier(c, x, Ya0 + 0.12, L + 0.2, w=0.3, h=0.28)
    led(c, 0.0, Ya0 + 0.1, L + 0.5, 1, s=0.11)
    cheminee(c, 1.85, 2.0, H + 0.4, 0.2, 1.7)


def r3(c):
    """HALLE À GRADINS HAUTE : annexe basse au sud, grande halle haute (2,75) au nord dont la façade sud est un grand
    bandeau AMBRE de 9 travées ; centrales d'air et deux cheminées sur le toit de la halle."""
    g, M = c.g, c.M
    X0, X1 = -2.38, 2.38
    L = 0.16
    Ya0 = -2.3
    Yh0, Yh1 = -0.55, 2.34
    Ha = L + 0.85
    Hh = L + 2.75
    socle(c, X0, X1, Ya0, Yh1, L, pieds=6)
    coque(c, X0, X1, Yh0 + 0.2, Yh1, L, Hh)
    facade(c, X0, X1, Yh0, L, Hh, 0.2, [(-2.1, 2.1, Ha + 0.25, Hh - 0.4)], nb_meneaux=9)
    rampe_leds(c, -2.1, 2.1, Yh0, Hh - 0.2, pas=0.5)
    arete(c, X0, X1, Yh0, Hh)
    acrotere(c, X0, X1, Yh0, Yh1, Hh, m="sb_clair")
    coque(c, X0 + 0.1, X1 - 0.1, Ya0 + 0.2, Yh0 + 0.02, L, Ha)
    facade(c, X0 + 0.1, X1 - 0.1, Ya0, L, Ha, 0.2, [(0.3, 2.15, L + 0.25, Ha - 0.18)], nb_meneaux=4)
    pilastres(c, X0 + 0.1, 0.25, Ya0, L, Ha, pas=0.6)
    arete(c, X0 + 0.1, X1 - 0.1, Ya0, Ha)
    bande(c, X0 + 0.12, X1 - 0.12, Ya0 - 0.04, L + 0.1, h=0.05)
    sas(c, -2.0, -0.85, -2.46, Ya0 + 0.01, L, 0.72)
    grille_ffu(c, X0 + 0.25, X1 - 0.25, Ya0 + 0.32, Yh0 - 0.05, Ha, 6, 1)
    cta(c, -2.2, 0.2, 0.75, 2.2, Hh, 0.6, ventilos=2, leds_grp=2)
    grille_ffu(c, 0.4, 2.2, -0.3, 0.7, Hh, 3, 1)
    gaine(c, -1.3, -0.95, 0.4, 0.75, Hh, Hh + 0.32)
    cheminee(c, 1.0, 1.7, Hh, 0.22, 1.1)
    cheminee(c, 1.85, 1.7, Hh, 0.17, 0.8)


def r4(c):
    """SUR PIEDS : caisson levé sur une forêt de pieds au-dessus du sub-fab (pompes, cuves, collecteur) ; bandeau AMBRE
    tout le long de la façade ; plénum surélevé et deux grands ventilateurs ; palier et sas à l'ouest."""
    g, M = c.g, c.M
    X0, X1, Y0, Y1 = -2.38, 2.38, -1.8, 2.32
    L = 0.7
    H = L + 1.5
    bx(g, X0 + 0.05, X1 - 0.05, Y0 + 0.05, Y1 - 0.05, 0.0, 0.05, M["anthracite"], "hard", "dalle")
    for x in (X0 + 0.15, -0.8, 0.8, X1 - 0.15):
        for y in (Y0 + 0.15, 0.3, Y1 - 0.15):
            bx(g, x - 0.1, x + 0.1, y - 0.1, y + 0.1, 0.05, L, M["acier_tech"], "hard", "pied")
            bx(g, x - 0.15, x + 0.15, y - 0.15, y + 0.15, 0.05, 0.09, M["anthracite"], "hard", "semelle")
            bx(g, x - 0.14, x + 0.14, y - 0.14, y + 0.14, L - 0.08, L, M["anthracite"], "hard", "chapiteau")
    for x in (-1.6, -0.4, 0.4, 1.6):
        g.cyl(B(x, -1.0, 0.05 + 0.2), "z", 0.19, 0.4, M["gris_tech"], n=18, style="soft", what="pompe")
        g.cyl(B(x, -1.0, 0.05 + 0.43), "z", 0.11, 0.07, M["acier_tech"], n=14, style="soft", what="moteur")
        bx(g, x - 0.17, x + 0.17, -0.7, -0.48, 0.05, 0.32, M["sb_noir"], "hard", "skid")
    g.cyl(B(0, -0.35, 0.45), "x", 0.075, X1 - X0 - 0.4, M["acier_tech"], n=14, what="collecteur")
    for x in (-1.0, 1.0):
        g.cyl(B(x, 0.95, 0.05 + 0.3), "z", 0.32, 0.6, M["sb_panneau2"], n=24, style="smooth", what="cuve")
    bx(g, X0, X1, Y0, Y1, L - 0.08, L, M["sb_noir"], "hard", "plancher")
    coque(c, X0, X1, Y0 + 0.2, Y1, L, H)
    facade(c, X0, X1, Y0, L, H, 0.2, [(-1.25, 2.15, L + 0.22, H - 0.32)], nb_meneaux=7)
    rampe_leds(c, -1.25, 2.15, Y0, H - 0.16)
    pilastres(c, X0, -1.3, Y0, L, H, pas=0.5)
    arete(c, X0, X1, Y0, H)
    bx(g, -2.32, -1.5, -2.46, Y0, L - 0.05, L, M["grate"], "hard", "palier")
    for x in (-2.26, -1.56):
        bx(g, x - 0.05, x + 0.05, -2.44, -2.34, 0.0, L - 0.05, M["acier_tech"], "hard", "poteau_palier")
    sas(c, -2.32, -1.5, -2.46, Y0, L, 0.95)
    coque(c, -0.6, X1 - 0.12, -0.6, 1.3, H, H + 0.45, nv_s=1)
    arete(c, -0.6, X1 - 0.12, -0.6, H + 0.45)
    g.grille(face_sud(-0.45, X1 - 0.3, -0.6 - 0.02, H + 0.08, H + 0.37), 4, depth=0.03, slat_mat=M["acier_tech"])
    grille_ffu(c, -0.5, X1 - 0.22, -0.5, 1.2, H + 0.45, 4, 2)
    for x, y in ((-1.5, 0.15), (-1.5, 1.55)):
        ventilo(c, x, y, H, 0.53, h=0.3, pales=7, bague="sb_clair")
    cta(c, 0.0, 2.2, 1.45, 2.22, H, 0.4, ventilos=2, leds_grp=1)
    cheminee(c, -0.35, 1.95, H, 0.17, 1.0)


def r2b(c):
    """r2 (SHEDS) + passe de détails (30/10, 11 h 40) : intérieur des verrières en deux tons et en volume (rampe,
    colonnes), conduites de résine et vannes le long de la façade, cuves tampon à l'est, gaine de l'annexe vers les
    sheds, échelle et chemin de câbles sur la tour d'air."""
    g, M = c.g, c.M
    r2(c)
    L = 0.16
    Y0 = -1.15
    xs0, X1 = -1.15, 2.38
    # conduites de résine (2) le long de la façade sud des sheds, colliers, vannes à volant, bandes de repérage
    for k, (z, r) in enumerate(((L + 0.62, 0.055), (L + 0.78, 0.045))):
        yy = Y0 - 0.1 - 0.09 * k
        g.cyl(B((xs0 + 0.1 + 1.6) / 2, yy, z), "x", r, 1.6 - xs0 - 0.1, M["acier_tech"], n=14, what="conduite")
        for x in (xs0 + 0.25, 0.3, 1.1):
            g.cyl(B(x, yy, z), "x", r * 1.4, 0.05, M["anthracite"], n=14, style="hard", what="collier")
            bx(g, x - 0.02, x + 0.02, yy, Y0, z - 0.02, z + 0.02, M["anthracite"], "hard", "patte")
        g.cyl(B(-0.25 + 0.6 * k, yy, z), "x", r * 1.25, 0.12, M["bleu_tech"] if k else M["cable_r"], n=14,
              style="hard", what="repere")
        xv = 0.75 - 0.5 * k
        g.cyl(B(xv, yy, z), "x", r * 1.6, 0.1, M["sb_noir"], n=12, style="hard", what="vanne")
        g.cyl(B(xv, yy, z + r * 1.6 + 0.06), "z", 0.012, 0.12, M["acier_tech"], n=6, what="tige")
        g.torus(B(xv, yy, z + r * 1.6 + 0.12), "z", 0.07, 0.016, M["cable_r"], n=16, m=5, what="volant")
    # cuves tampon (résine, azote) à l'est, au pied des sheds, avec leurs piquages
    for k, x in enumerate((1.75, 2.15)):
        yy = Y0 - 0.32
        g.cyl(B(x, yy, L + 0.38), "z", 0.17, 0.76, M["sb_panneau"], n=24, style="smooth", what="cuve")
        g.sphere(B(x, yy, L + 0.76), 0.17, M["sb_panneau"], n=24, m=8, scale=(1, 1, 0.45), what="fond_cuve")
        for zz in (L + 0.15, L + 0.6):
            g.torus(B(x, yy, zz), "z", 0.172, 0.014, M["anthracite"], n=24, m=5, what="cerclage")
        bx(g, x - 0.06, x + 0.06, yy - 0.19, yy - 0.16, L + 0.32, L + 0.44, M["amber"] if k else M["sb_noir"], "flat",
           "etiquette")
        g.cyl(B(x, yy + 0.12, L + 0.62), "y", 0.035, 0.22, M["acier_tech"], n=10, what="piquage")
    # gaine de l'annexe vers les sheds (soufflage filtré)
    gaine(c, -0.75, -0.35, -1.75, -1.15, L + 0.62, L + 0.92)
    gaine(c, 0.0, 0.35, -1.75, -1.15, L + 0.62, L + 0.85)
    # tour d'air : échelle de visite et chemin de câbles
    X0 = -2.38
    xe = X0 + 0.22
    ye = Y0 + 0.4 - 0.06
    for xx in (xe - 0.09, xe + 0.09):
        bx(g, xx - 0.016, xx + 0.016, ye - 0.03, ye, L + 0.1, L + 2.25, M["acier_tech"], "hard", "montant")
    for i in range(14):
        z = L + 0.2 + 0.15 * i
        bx(g, xe - 0.09, xe + 0.09, ye - 0.03, ye, z, z + 0.022, M["acier_tech"], "hard", "barreau")
    bx(g, xs0 - 0.2, xs0 - 0.08, Y0 + 0.4 - 0.05, Y0 + 0.4, L + 0.1, L + 2.2, M["anthracite"], "hard", "chemin_cables")
    for k, m in enumerate(("cable_r", "cable_b")):
        xx = xs0 - 0.17 + 0.06 * k
        bx(g, xx - 0.016, xx + 0.016, Y0 + 0.4 - 0.07, Y0 + 0.4 - 0.05, L + 0.1, L + 2.2, M[m], "soft", "cable")


SILHOUETTES = {"r1": r1, "r2": r2, "r3": r3, "r4": r4, "r2b": r2b}
