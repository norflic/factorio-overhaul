"""GARNITURE DE LA LIGNÉE de l'assembleur (lot F3-A, ronde 4, 25/10). S'exécute DANS Blender.

Après la ronde 3 (bâti haut) : à côté de la mitrailleuse du même âge, l'assembleur garde de GRANDES SURFACES NUES (dessus
des joues, face sud du bâti) : la mitrailleuse est dense de petites pièces, l'assembleur non. La garniture pose, dans la
zone habillée de l'âge (matières de son acier, de ses rivets, de ses capots), des petites pièces de taille CONSTANTE
(règle des kits : une grande machine en porte plus, jamais de plus grosses) :
  « bati »  : face sud du bâti : collecteur horizontal à brides, raidisseurs entre les portes, plaques de marquage ;
  « joues » : dessus des joues, devant le montant du portique : trappes de visite, grilles d'aération, boîtes à bornes ;
              face sud des joues : grille et rangée de rivets.
Un âge choisit ses zones par GARNIR = ("bati", "joues") (défaut) ; () : aucune. Le dessus du dos n'est jamais garni (les
âges y posent leurs grands organes).
"""
import math

from mathutils import Vector

import parts as PT
from habillage import habille
from kit import SQ2

V = Vector


def _B(x, yn, z=0.0):
    return V((x, yn * SQ2, z))


def bati(g, c):
    M = g.M
    xb, h, ze, zs = c.xb, c.h, c.ze, c.zs
    y0 = -h + 0.02
    zc = ze + (zs - ze) * 0.82
    r = 0.035 + 0.004 * c.side
    # collecteur horizontal à brides le long du haut de la face (interrompu au milieu : bride du port S plus bas)
    for sx in (-1, 1):
        xa, xz = sx * 0.3, sx * (xb - 0.08)
        xa, xz = min(xa, xz), max(xa, xz)
        g.cyl(_B((xa + xz) / 2, y0 - 0.05, zc), "x", r, xz - xa, M["steel_dk"], n=12, what="collecteur")
        n = max(2, int((xz - xa) / 0.45))
        for k in range(n + 1):
            x = xa + (xz - xa) * k / n
            g.cyl(_B(x, y0 - 0.05, zc), "x", r * 1.5, 0.035, M["steel"], n=12, style="hard", what="bride")
            g.box(_B(x, y0 - 0.02, zc - r - 0.03), (0.03, 0.04, 0.06), M["steel_dk"], "hard", what="patte")
    # raidisseurs verticaux et rivets en rangée basse
    nr = max(4, int(2 * xb / 0.4))
    for k in range(nr + 1):
        x = -xb + 0.04 + (2 * xb - 0.08) * k / nr
        wd = min(0.5, xb * 0.5)      # portes de visite du bâti (corps.plateau) : pas de raidisseur dessus
        if abs(x) < 0.25 or abs(abs(x) - xb * 0.55) < wd / 2 + 0.03:
            continue
        g.box(_B(x, y0 - 0.015, (ze + zs) / 2), (0.03, 0.03, (zs - ze) * 0.9), M["steel_dk"], "hard", what="raidisseur")
    for k in range(int(2 * xb / 0.12)):
        x = -xb + 0.06 + 0.12 * k
        g.dome(_B(x, y0 - 0.012, ze + 0.05), (0, -1, 0), 0.014, M["rivet"])


def joues(g, c):
    M = g.M
    ytp = c.yt - c.wm * 0.8          # devant le montant du portique
    zf0 = c.zs + 0.1 * (c.Hj - c.zs)

    def zj_a(yn):
        if c.f_joues != "pente":
            return c.z_joue
        return zf0 + (c.Hj - zf0) * (yn - c.yf) / (c.yb - c.yf)
    for sx in (-1, 1):
        if c.plan == "L" and sx < 0:
            continue                # aile haute du plan L
        xc = sx * (c.xb + c.wj / 2)
        y0, y1 = c.yf + 0.12, ytp - 0.08
        if y1 - y0 < 0.25:
            continue
        L = y1 - y0
        # trappe de visite, grille, boîte à bornes, alignées du sud au nord
        PT.hatch(g, tuple(_B(xc - sx * c.wj * 0.15, y0 + L * 0.22, zj_a(y0 + L * 0.22))), min(0.12, c.wj * 0.22))
        w = min(0.32, c.wj * 0.55)
        za, zb = zj_a(y0 + L * 0.5) + 0.012, zj_a(y0 + L * 0.72) + 0.012
        q = [_B(xc - w / 2, y0 + L * 0.5, za), _B(xc + w / 2, y0 + L * 0.5, za),
             _B(xc + w / 2, y0 + L * 0.72, zb), _B(xc - w / 2, y0 + L * 0.72, zb)]
        g.grille(q, 5, depth=0.025)
        zbo = zj_a(y0 + L * 0.9)
        g.box(_B(xc + sx * c.wj * 0.18, y0 + L * 0.9, zbo + 0.05), (0.14, 0.1 * SQ2, 0.1), M["steel_dk"], "hard",
              what="boite_bornes")
        g.cyl(_B(xc + sx * c.wj * 0.18, y0 + L * 0.9 - 0.05, zbo + 0.06), "y", 0.02, 0.06, M["steel"], n=8,
              what="presse_etoupe")
        # face sud de la joue : grille et rivets
        ze = c.ze
        zf = zj_a(c.yf)
        if zf - ze > 0.25:
            gw = min(0.3, c.wj * 0.5)
            q2 = [_B(xc - gw / 2, c.yf - 0.025, ze + (zf - ze) * 0.35), _B(xc + gw / 2, c.yf - 0.025, ze + (zf - ze) * 0.35),
                  _B(xc + gw / 2, c.yf - 0.025, ze + (zf - ze) * 0.75), _B(xc - gw / 2, c.yf - 0.025, ze + (zf - ze) * 0.75)]
            g.grille(q2, 4, depth=0.02)


def garnir(g, c):
    zones = getattr(c.ep, "GARNIR", ("bati", "joues"))
    with habille(g, c):
        if "bati" in zones and c.plan in ("carre", "L", "portique"):
            bati(g, c)
        if "joues" in zones and c.f_joues in ("caisson", "basses", "pente") and c.plan in ("carre", "L"):
            joues(g, c)


# ------------------------------------------------------------------------------------------------
# GARNITURE DENSE (ronde F3-A2) : petites pièces semées sur les dessus (c.zones), hors des réserves
# ------------------------------------------------------------------------------------------------
PAS = 0.16         # pas de la grille (tuiles de jeu) : taille CONSTANTE, plus de pièces sur une grande machine


def zones_carre(c):
    """Zones des plans carre, L et portique (dessus du dos plat, des joues, marges du bâti, aile du plan L)."""
    out = []
    h, yb, xb = c.h, c.yb, c.xb
    if c.f_dos in ("plat", "gradins", "tours", "bas"):
        out.append(("toit", -h + 0.15, h - 0.15, yb + 0.08, h - 0.1))
    if c.plan == "L":
        out.append(("rect", -h + 0.08, -xb - 0.06, c.yf + 0.06, yb - 0.04, c.Hd))
        if c.f_joues in ("caisson", "basses", "socle"):
            out.append(("rect", xb + 0.06, h - 0.08, c.yf + 0.06, yb - 0.04, c.z_joue))
    elif c.f_joues in ("caisson", "basses", "socle"):
        for sx in (-1, 1):
            xa, xz = (xb + 0.06, h - 0.08) if sx > 0 else (-h + 0.08, -xb - 0.06)
            out.append(("rect", xa, xz, c.yf + 0.06, yb - 0.04, c.z_joue))
    tx, ty = c.T["table"]["tx"], c.T["table"]["ty"]
    for sx in (-1, 1):
        xa, xz = (tx + 0.08, xb - 0.05) if sx > 0 else (-xb + 0.05, -tx - 0.08)
        if xz - xa > 0.15:
            out.append(("rect", xa, xz, -h + c.epar + 0.12, yb - 0.06, c.zs))
    return out


def _libre(c, x, yn, r):
    for (rx, ry, rr) in c.reserves:
        if (x - rx) ** 2 + (yn - ry) ** 2 < (rr + r) ** 2:
            return False
    return True


def _piece(g, c, rng, x, yn, z, mats, emat, p_lampe):
    """Une petite pièce au hasard (local) : boîte rivetée, petit réservoir, vanne, grille, tronçon de tuyau, voyant."""
    M = g.M
    p = _B(x, yn, z)
    k = rng.random()
    m = mats[rng.randrange(len(mats))]
    if k < p_lampe and emat is not None:
        g.cyl(p + V((0, 0, 0.02)), "z", 0.03, 0.04, M["steel_dk"], n=10, what="socle_voyant")
        g.sphere(p + V((0, 0, 0.05)), 0.026, emat, n=10, m=5, what="voyant")
        return 1
    if k < 0.36:
        w, d, hh = 0.07 + 0.08 * rng.random(), 0.05 + 0.06 * rng.random(), 0.04 + 0.07 * rng.random()
        g.box(p + V((0, 0, hh / 2)), (w, d * SQ2, hh), m, "hard", what="boite")
        g.dome(p + V((w * 0.35, 0, hh)), (0, 0, 1), 0.012, M["rivet"])
        g.dome(p + V((-w * 0.35, 0, hh)), (0, 0, 1), 0.012, M["rivet"])
        if rng.random() < 0.4:
            g.box(p + V((0, -d * SQ2 / 2 - 0.004, hh * 0.55)), (w * 0.6, 0.008, hh * 0.3), M["steel_hi"], "flat",
                  what="plaque")
        return 3
    if k < 0.56:
        r, hh = 0.03 + 0.025 * rng.random(), 0.05 + 0.08 * rng.random()
        g.cyl(p + V((0, 0, hh / 2)), "z", r, hh, m, n=12, what="petit_reservoir")
        g.cyl(p + V((0, 0, hh + 0.006)), "z", r * 0.8, 0.012, M["steel_dk"], n=12, what="couvercle")
        g.tube_shell(p + V((0, 0, hh * 0.6)), "z", r + 0.006, r - 0.004, 0.014, M["steel"], n=12, what="cerclage")
        return 3
    if k < 0.68:
        g.cyl(p + V((0, 0, 0.03)), "z", 0.012, 0.06, M["steel_dk"], n=6, what="tige")
        g.torus(p + V((0, 0, 0.065)), "z", 0.03, 0.007, M["redpaint"] if rng.random() < 0.5 else M["steel"], n=10, m=4,
                what="volant")
        return 2
    if k < 0.82:
        w = 0.1 + 0.06 * rng.random()
        g.box(p + V((0, 0, 0.012)), (w, 0.07 * SQ2, 0.024), M["steel_dk"], "hard", what="grille_fond")
        for i in range(3):
            g.box(p + V((-w * 0.3 + w * 0.3 * i, 0, 0.028)), (0.012, 0.06 * SQ2, 0.01), M["seam"], "flat", what="fente")
        return 4
    L = 0.12 + 0.12 * rng.random()
    ax = "x" if rng.random() < 0.5 else "y"
    Lb = L if ax == "x" else L * SQ2
    g.cyl(p + V((0, 0, 0.04)), ax, 0.022, Lb, M["steel_dk"], n=10, what="troncon")
    for s in (-1, 1):
        off = V((s * Lb / 2, 0, 0)) if ax == "x" else V((0, s * Lb / 2, 0))
        g.cyl(p + off + V((0, 0, 0.04)), ax, 0.034, 0.016, M["steel"], n=10, style="hard", what="bride")
    return 3


def densifier(g, c):
    """Sème les petites pièces sur toutes les zones du plan (et du carré), hors des réserves. Densité de l'âge :
    DENSITE = dict(p=0,62, lampes=0,05) (proportion de cases garnies, part des voyants lumineux)."""
    import random
    dens = getattr(c.ep, "DENSITE", {})
    p_case = min(0.95, 1.3 * dens.get("p", 0.62))      # essai a2q : semis trop clair
    p_lampe = dens.get("lampes", 0.05)
    rng = random.Random(4100 + 37 * c.e + c.side)
    zones = list(c.zones)
    if c.plan in ("carre", "L", "portique"):
        zones += zones_carre(c)
    import corps
    n = 0
    with habille(g, c):
        M = g.M
        mats = [c.Mh["olive"], c.Mh["ochre"], c.Mh["steel_dk"], c.Mh["steel"]]
        emat = M["emit"] if p_lampe > 0 else None
        for z in zones:
            pts = []
            if z[0] in ("rect", "toit"):
                x0, x1, y0, y1 = z[1:5]
                nx, ny = max(1, int((x1 - x0) / PAS)), max(1, int((y1 - y0) / PAS))
                for i in range(nx):
                    for j in range(ny):
                        x = x0 + (i + 0.5 + 0.3 * (rng.random() - 0.5)) * (x1 - x0) / nx
                        y = y0 + (j + 0.5 + 0.3 * (rng.random() - 0.5)) * (y1 - y0) / ny
                        zz = corps.z_toit(c, x, y) if z[0] == "toit" else z[5]
                        pts.append((x, y, zz))
            else:
                _, R0, R1, a0, a1, zz, cy = z
                nr = max(1, int((R1 - R0) / PAS))
                for i in range(nr):
                    R = R0 + (i + 0.5) * (R1 - R0) / nr
                    na = max(1, int(R * (a1 - a0) / PAS))
                    for j in range(na):
                        a = a0 + (j + 0.5 + 0.3 * (rng.random() - 0.5)) * (a1 - a0) / na
                        pts.append((R * math.cos(a), cy + R * math.sin(a), zz))
            for (x, y, zz) in pts:
                if rng.random() > p_case or not _libre(c, x, y, 0.07):
                    continue
                n += _piece(g, c, rng, x, y, zz, mats, emat, p_lampe)
    c.n_garniture = n
    return n
