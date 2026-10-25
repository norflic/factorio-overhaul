"""ORNEMENTS DU LASER (lot F1-B, 25/10/2026) : outils de DÉTAIL pour les fichiers d'âge. S'exécute DANS Blender.

Verdict du DC (24/10, « 2) A ») : garder la direction des essais (tour ronde sans canons, émetteur lumineux) et
l'ENRICHIR ; les essais du lot F1-A étaient plus pauvres en détails que la mitrailleuse validée du même âge (mesure de
la charte : petites pièces D3 = 20 par t² à l'âge 15, plancher 26). Ce module AJOUTE au kit des outils de placement ; il
ne change NI la lignée gelée (corps.py, cotes.py, epoques.py, piece.py) NI le kit commun (../commun) ni la mitrailleuse.

Les positions se calculent sur c.gradins (rempli par corps.affut AVANT ep.socle ; corps.piece le calcule aussi, sans
dessiner) et sur les cotes de la taille (c.T). Repère : x est, y Blender = yn × √2 (repere.Y), z haut ; un angle a est
pris dans le plan « rond à l'écran » (0 = est, π/2 = nord), comme corps.affut.

  rayon_flanc(c, i, a, f)          rayon (tuiles) du flanc du gradin i à l'angle a, à la fraction f de sa hauteur ;
  flanc(c, i, a, f=0.5, dr=0)      (p, nrm, tan) : point du flanc, normale sortante et tangente (sens direct),
                                   horizontales, calculées sur le contour réel (pans, lobes, étoile, dents) ;
  sur_flanc(g, c, i, angles, fn)   repère local posé sur le flanc (z = normale sortante, x = tangente, y = haut) :
                                   fn(g, k, h) avec h la hauteur du gradin ;
  dessus(c, i, a, t=0.5)           point sur le DESSUS du gradin i, entre le pied du gradin suivant (ou le pivot) et
                                   l'arête (t = 0 côté centre, 1 côté arête) ;
  sur_dessus(g, c, i, angles, fn)  repère local posé sur le dessus (x radial sortant, z haut) : fn(g, k, largeur) ;
  entre_condensateurs(c)           angles des milieux entre deux condensateurs de la couronne ;
  visibles(angles)                 angles de la moitié vue par la caméra (sud, est et ouest) ;
  ceinture(g, c, i, f, r, mat)     tube fermé qui ceint le gradin i (colliers facultatifs) ;
  rivets_flanc(g, c, i, f, mat)    rangée de rivets sur la moitié visible du flanc ;
  pods(c)                          deux places libres à l'ARRIÈRE de la platine de la tête (x, y, largeur), hors des
                                   paliers, du caisson arrière et de l'émetteur (la tête est modélisée faisceau vers +Y).
Aucun de ces outils ne laisse de vide sous une pièce (tout est posé ou enfoncé dans la surface).
"""
import math

from mathutils import Vector

import cotes
from kit import SQ2, TAU

V = Vector


def _k(c, a):
    """Facteur du contour (pans, lobes, étoile, dents) du bord des gradins à l'angle a (comme corps._k_bord)."""
    A = c.affut
    cont = A.get("contour")
    if cont:
        return cotes.facteur_contour(cont, a)
    if A.get("pans"):
        n = int(A["pans"])
        p = TAU / n
        u = (a - math.pi / n) % p
        return math.cos(p / 2) / math.cos(u - p / 2)
    return 1.0


def rayon_flanc(c, i, a, f=0.5):
    R0, Rt, z0, z1 = c.gradins[i]
    prof = c.affut.get("profil", "droit")
    if prof == "bombe":
        r = R0 + (R0 * 1.03 - R0) * (f / 0.5) if f <= 0.5 else R0 * 1.03 + (Rt - R0 * 1.03) * ((f - 0.5) / 0.5)
    else:
        r = R0 + (Rt - R0) * f
    return r * _k(c, a)


def _pt(r, a, z):
    return V((r * math.cos(a), SQ2 * r * math.sin(a), z))


def flanc(c, i, a, f=0.5, dr=0.0):
    """(p, nrm, tan) sur le flanc du gradin i ; dr > 0 : sorti du flanc de dr (Blender, le long de la normale)."""
    R0, Rt, z0, z1 = c.gradins[i]
    z = z0 + (z1 - z0) * f
    da = 0.01
    p0 = _pt(rayon_flanc(c, i, a - da, f), a - da, z)
    p1 = _pt(rayon_flanc(c, i, a + da, f), a + da, z)
    p = _pt(rayon_flanc(c, i, a, f), a, z)
    tan = (p1 - p0)
    tan.z = 0.0
    tan.normalize()
    nrm = tan.cross(V((0, 0, 1))).normalized()
    if nrm.dot(V((math.cos(a), math.sin(a), 0))) < 0:
        nrm = -nrm
    return p + nrm * dr, nrm, tan


def sur_flanc(g, c, i, angles, fn, f=0.5, dr=0.0):
    """Pour chaque angle : repère local sur le flanc (z = normale sortante, x = tangente, y = haut), fn(g, k, h)."""
    R0, Rt, z0, z1 = c.gradins[i]
    for k, a in enumerate(angles):
        p, nrm, tan = flanc(c, i, a, f, dr)
        g.push_frame(tuple(p), tuple(nrm), tuple(tan))
        fn(g, k, z1 - z0)
        g.pop()


def bornes_dessus(c, i, a):
    """(rayon intérieur, rayon extérieur) libres du dessus du gradin i à l'angle a (tuiles)."""
    R0, Rt, z0, z1 = c.gradins[i]
    k = _k(c, a)
    if i + 1 < len(c.gradins):
        rin = c.gradins[i + 1][0] * k + 0.04
    else:
        rin = c.T["pivot"]["R"] + 0.06
    rout = Rt * k - c.T["affut"]["bord"] - 0.03
    return rin, rout


def dessus(c, i, a, t=0.5):
    rin, rout = bornes_dessus(c, i, a)
    z1 = c.gradins[i][3]
    return _pt(rin + (rout - rin) * t, a, z1 + 0.012)


def sur_dessus(g, c, i, angles, fn, t=0.5):
    """Pour chaque angle : repère local sur le dessus du gradin i (x radial sortant à l'écran, z haut), fn(g, k, w) avec
    w la largeur libre de l'anneau (tuiles)."""
    for k, a in enumerate(angles):
        rin, rout = bornes_dessus(c, i, a)
        p = dessus(c, i, a, t)
        g.push(tuple(p), rz=math.atan2(SQ2 * math.sin(a), math.cos(a)))
        fn(g, k, max(0.0, rout - rin))
        g.pop()


def entre_condensateurs(c):
    """Angles des milieux entre deux condensateurs (la couronne est à π/n + 2πk/n)."""
    cd = c.hab.get("condensateurs")
    n = (cd or {}).get("n") if isinstance(cd, dict) else None
    n = n or c.T["condensateurs"]["n"]
    return [TAU * k / n for k in range(n)]


def visibles(angles, nord=0.3):
    """Angles vus par la caméra (au sud, en hauteur) : sin(a) <= nord."""
    return [a for a in angles if math.sin(a) <= nord]


def ceinture(g, c, i, f, r, mat, colliers=None, n=72, dr=0.0, pas=0.0):
    """Tube fermé autour du gradin i, à la fraction f de sa hauteur, enfoncé de moitié dans le flanc ; colliers : matière
    de colliers posés tous les `pas` (tuiles, défaut 0,45)."""
    pts = []
    for k in range(n + 1):
        a = TAU * k / n
        p, nrm, _ = flanc(c, i, a, f, dr + r * 0.45)
        pts.append(p)
    g.tube(pts, r, mat, n=8, style="soft", what="ceinture")
    if colliers is not None:
        pas = pas or 0.45
        R = c.gradins[i][0]
        m = max(6, int(TAU * R / pas))
        for k in range(m):
            a = TAU * (k + 0.5) / m
            p, nrm, tan = flanc(c, i, a, f, dr + r * 0.45)
            g.push_frame(tuple(p), tuple(nrm), tuple(tan))
            g.box((0, 0, 0), (r * 1.6, r * 2.6, r * 2.6), colliers, "hard", what="collier")
            g.pop()


def rivets_flanc(g, c, i, f, mat, pas=0.12, r=0.013, nord=0.3):
    """Rangée de rivets sur la moitié visible du flanc du gradin i."""
    R = c.gradins[i][0]
    m = max(8, int(TAU * R * 1.2 / pas))
    for k in range(m):
        a = TAU * (k + 0.5) / m
        if math.sin(a) > nord:
            continue
        p, nrm, _ = flanc(c, i, a, f, 0.004)
        g.bolt(tuple(p), tuple(nrm), r, mat)


def pods(c):
    """Deux places libres à l'arrière de la platine (repère de la tête) : [(x, y, w)] ; w : demi-côté conseillé."""
    t = c.T["tete"]
    re = t["re"]
    return [(sx * 0.62 * re, -0.72 * re, 0.11 * re + 0.02) for sx in (-1, 1)]


def zb(c):
    """Dessus de la platine (repère de la tête)."""
    t = c.T["tete"]
    return t["z0"] + t["hpl"]


def lampe(g, p, nrm, r, emat, cadre):
    """Petit voyant à visière : boîtier, verre lumineux (r >= 0,02 : lisible au zoom 1, F37)."""
    a = V(nrm).normalized()
    p = V(p)
    g.cyl(p + a * 0.01, a, r * 1.45, 0.02, cadre, n=12, style="soft", what="boitier_voyant")
    g.cyl(p + a * 0.024, a, r, 0.012, emat, n=12, style="flat", what="voyant")
