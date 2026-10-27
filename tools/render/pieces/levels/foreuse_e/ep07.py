"""Foreuse · Âge 7 · Cristal (ère III, 5×5, niveaux 13 et 14). Lot F4-A (25/10). S'exécute DANS Blender.

En 3 mots : « diapason, dallage de pierre, cristaux dressés ». Foreuse à RÉSONANCE : un grand DIAPASON de bronze doré à
4 branches (deux se lisent de face dans toute direction) monte d'un socle de pierre claire ; entre les branches, une tige
porte le cristal de résonance violet ; le tablier est un DALLAGE DE PIERRE claire à joints violets ; quatre CRISTAUX
DRESSÉS violets, enchâssés dans des bagues de bronze, gardent les angles à la place des montants. Palette
(ages.PALETTE[7]) : bronze doré / pierre claire / violet (cristaux).
"""
import math

import ages
import corps as cp

EPOQUE = 7
NOM = ages.NOMS[7]
TRIPLET = ("diapason", "dallage de pierre", "cristaux dressés")
FOYER = ages.FOYER[7]
HABILLAGE = dict(ages.CORPS[7], forme_tablier="rond")
PAS_FIN = 0.12  # ronde F4-A3 : détail fin plus serré
PIED = 1.08
FIN = 1.0       # ronde F4-A3 : tablier entièrement garni de détail fin
# ronde F4-A2 : le socle de pierre à degrés est l'embase ; 2 conduites de bronze
EMBASE = dict(r=0.0, contreforts=0, haubans=0, conduites=2)


def matieres(metal, M):
    ages.matieres(7, metal, M)


def _cristal(g, x, y, z, r, h, M, n=6):
    g.cyl((x, y, z + h * 0.4), "z", r, h * 0.8, M["emit"], n=n, r2=r * 0.8, style="flat", what="cristal")
    g.cyl((x, y, z + h * 0.9), "z", r * 0.8, h * 0.2, M["emit"], n=n, r2=0.004, style="flat", what="pointe")


def tour(g, c):
    M = g.M
    rt, zt, H = c.rt, c.zt, c.H
    # socle de pierre à deux degrés
    cp.dalle(g, -rt, -rt, rt, rt, zt, zt + 0.16, M["pierre_claire"], what="degre")
    cp.dalle(g, -rt * 0.72, -rt * 0.72, rt * 0.72, rt * 0.72, zt + 0.16, zt + 0.32, M["pierre_claire2"], what="degre")
    for (x, y) in cp.sym4((rt * 0.86, rt * 0.86)):
        g.dome((x, y, zt + 0.165), (0, 0, 1), 0.04, M["bronze_clair"])
    # pied du diapason : fût de bronze, coupe carrée
    zf = zt + 0.32
    zu = zt + 0.30 * H
    cp.colonne(g, 0, 0, zf, zu, 0.16, M["bronze_sombre"], n=12, r2=0.12, what="pied")
    cp.dalle(g, -rt * 0.68, -rt * 0.68, rt * 0.68, rt * 0.68, zu, zu + 0.14, M["bronze_capot"], what="coupe")
    # 4 branches (lames de section rectangulaire, légèrement évasées) ; ronde 1 : plus larges, bronze clair (elles se
    # lisaient « table brune »), anneaux d'onde violets entre les branches (le diapason vibre)
    zb = H - 0.08
    rp = rt * 0.56
    for (x, y) in cp.sym4((rp, rp)):
        cp.poutre(g, (x, y, zu + 0.1), (x * 1.08, y * 1.08, zb), 0.25, M["bronze_clair"], "branche", h=0.17)
        g.box((x * 1.08, y * 1.08, zb + 0.03), (0.28, 0.28, 0.06), M["bronze_capot"], "hard", what="embout")
    for zz in (0.25, 0.45):     # ronde 2 : à 0,5 et 0,68 l'anneau arrière sortait du tablier à l'écran (trou enfermé)
        z = zu + (zb - zu) * zz
        rr = rp * (1.0 + 0.08 * (z - zu) / (zb - zu)) * 1.414
        g.torus((0, 0, z), "z", rr, 0.03, M["emit"], n=48, m=6, what="onde")
    # tige centrale et cristal de résonance
    cp.colonne(g, 0, 0, zu + 0.12, zt + 0.66 * H, 0.06, M["bronze_clair"], n=10, what="tige")
    cp.bague(g, 0, 0, zt + 0.66 * H, 0.14, 0.06, M["bronze_capot"], ep=0.03, n=12, what="sertissure")
    _cristal(g, 0, 0, zt + 0.66 * H, 0.17, H - (zt + 0.66 * H) - 0.05, M)
    cp.colonne(g, 0, 0, H - 0.08, H, 0.05, M["bronze_clair"], n=8, what="sommet")
    cp.halo(g, (0, -0.4, zt + 0.75 * H), M, 5.0)


def trepan(g, c):
    """Anneau de bronze vibrant posé sur la margelle, sans tige (la résonance creuse)."""
    M = g.M
    g.torus((0, 0, c.zt + 0.1), "z", c.rw * 0.8, 0.04, M["bronze_capot"], n=32, m=8, what="anneau_vibrant")


def montant(g, c, x, y):
    """Cristal dressé dans une bague de bronze sur un dé de pierre."""
    M = g.M
    w = c.T["montant"]["w"] * 1.3
    cp.dalle(g, x - w / 2, y - w / 2, x + w / 2, y + w / 2, 0.0, c.zt + 0.12, M["pierre_claire2"], what="de")
    cp.bague(g, x, y, c.zt + 0.16, w * 0.33, 0.08, M["bronze_capot"], ep=0.03, n=12, what="bague")
    _cristal(g, x, y, c.zt + 0.1, w * 0.3, 0.75, M)
    cp.halo(g, (x, y - 0.2, c.zt + 0.5), M, 2.0)


def _eclats(a):
    # ronde F4-A3 : 4 → 8 éclats (détail fin, charte D3)
    return ((-a * 0.5, -a * 0.25), (a * 0.25, a * 0.55), (-a * 0.3, a * 0.6), (a * 0.62, -a * 0.1),
            (-a * 0.62, a * 0.1), (a * 0.5, a * 0.25), (-a * 0.15, -a * 0.62), (a * 0.35, -a * 0.5))


def occupe(c):
    """Éclats de cristal sertis dans le dallage (la garniture et le détail fin les évitent)."""
    return [(x - 0.12, y - 0.12, x + 0.12, y + 0.12) for (x, y) in _eclats(c.a)]


def socle(g, c):
    M = g.M
    a, zt = c.a, c.zt
    # éclats de cristal sertis dans le dallage, le long des joints
    for (x, y) in _eclats(a):
        g.cyl((x, y, zt + 0.04), "z", 0.07, 0.1, M["emit"], n=6, r2=0.02, style="flat", what="eclat")
        cp.bague(g, x, y, zt + 0.02, 0.07, 0.04, M["bronze_sombre"], ep=0.02, n=6, what="serti")


def liaison(g, pts, r):
    M = g.M
    g.pipe(pts, r, M["bronze_capot"], fl_mat=M["bronze_sombre"], bolt_mat=M["bronze_clair"], what="raccord")


def moteur(g, c):
    """Moteur logé dans un coffre de pierre claire couronné de bronze."""
    M = g.M
    T = c.T["moteur"]
    mx, my, w, p, h = 0.42 * c.a, T["y"], T["w"], T["p"], T["h"]
    cp.dalle(g, mx - w / 2, my - p / 2, mx + w / 2, my + p / 2, c.zt, c.zt + h, M["pierre_claire"], what="coffre")
    cp.dalle(g, mx - w / 2 - 0.03, my - p / 2 - 0.03, mx + w / 2 + 0.03, my + p / 2 + 0.03, c.zt + h, c.zt + h + 0.06,
             M["bronze_capot"], what="couronne")
    g.box((mx, my - p / 2 - 0.005, c.zt + h * 0.55), (w * 0.5, 0.012, h * 0.3), M["emit"], "flat", what="fente")


def piece(g, c):
    """Grappe de cristaux violets sertie de bronze au sommet de la tige."""
    M = g.M
    z = c.H
    cp.colonne(g, 0, 0, z, z + 0.08, 0.12, M["bronze_capot"], n=8, what="serti")
    _cristal(g, 0, 0, z + 0.06, 0.09, 0.5, M)
    for k in range(4):
        x, y = cp.quart((0.11, 0.0), k)[:2]
        g.cyl((x * 1.3, y * 1.3, z + 0.2), (x, y, 0.25), 0.05, 0.3, M["emit"], n=6, r2=0.005, style="flat",
              what="cristal_oblique")
    cp.halo(g, (0, -0.2, z + 0.3), M, 3.0)
