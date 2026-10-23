"""SOLVEUR DES PLACES LIBRES (lot K0, 23/10) : distances signées au sol (polygone, rectangle, disque), meilleure
place d'une région (point le plus loin des obstacles, pas de 0,01), dégagements, hauteur libre sous une partie qui
tourne, lecture des littéraux d'un fichier d'âge (CANON, HABILLAGE… sans Blender). Sorti de gun_e/accroches.py SANS
changer une ligne (accroches.py réimporte ces noms). Python PUR. Une famille écrit SES obstacles (sa colonne, sa
trémie, sa goulotte, ses tuyaux) et SA table de places, puis appelle _place_socle(nom, région, distance, contour du
pont, profil, geo) : exemple complet, gun_e/accroches.py (calcul)."""
import math

import silhouettes as SIL

SQ2 = math.sqrt(2.0)
MARGE = 0.03
PAS = 0.01


def _Y(yn):
    return yn * SQ2


def _seg_dist(p, a, b):
    ax, ay = a
    bx, by = b
    px, py = p
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    t = 0.0 if L2 < 1e-12 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def _inside(p, poly):
    x, y = p
    ins = False
    n = len(poly)
    for i in range(n):
        (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % n]
        if (y0 > y) != (y1 > y) and x < x0 + (x1 - x0) * (y - y0) / (y1 - y0):
            ins = not ins
    return ins


def _d_poly(p, poly):
    """Distance signée au bord du polygone (positive dedans)."""
    d = min(_seg_dist(p, poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly)))
    return d if _inside(p, poly) else -d


def _d_rect(p, r):
    x0, x1, y0, y1 = r
    dx = max(x0 - p[0], 0.0, p[0] - x1)
    dy = max(y0 - p[1], 0.0, p[1] - y1)
    if dx == 0.0 and dy == 0.0:
        return -min(p[0] - x0, x1 - p[0], p[1] - y0, y1 - p[1])
    return math.hypot(dx, dy)


def _d_disc(p, c, r):
    return math.hypot(p[0] - c[0], p[1] - c[1]) - r


def _h_max(prof, d_in):
    """Hauteur libre sous la tête qui tourne pour une place dont le point le plus proche de l'axe est à d_in."""
    zs_ = [z for _, ro, z in prof if ro > d_in]
    return round(min(zs_) - 0.04, 3) if zs_ else None


def _meilleur(region, dist):
    """Point de la région (boîte Blender x0, x1, y0, y1) qui maximise la distance libre ; rend (x, y, d)."""
    x0, x1, y0, y1 = region
    best = (None, None, -1.0)
    nx = max(1, int((x1 - x0) / PAS))
    ny = max(1, int((y1 - y0) / PAS))
    for i in range(nx + 1):
        x = x0 + (x1 - x0) * i / nx
        for j in range(ny + 1):
            y = y0 + (y1 - y0) * j / ny
            d = dist((x, y))
            if d > best[2]:
                best = (x, y, d)
    return best


def _degagement(p, dist, ux, uy):
    k = 0.0
    while k < 6.0 and dist((p[0] + ux * (k + PAS), p[1] + uy * (k + PAS))) > 0.0:
        k += PAS
    return k


def _place_socle(nom, region, dist, poly, prof, geo=None):
    x, y, d = _meilleur(region, dist)
    if x is None or d <= MARGE:
        return dict(nom=nom, place=False)
    r = d - MARGE
    dxp = _degagement((x, y), dist, 1, 0)
    dxm = _degagement((x, y), dist, -1, 0)
    dyp = _degagement((x, y), dist, 0, 1)
    dym = _degagement((x, y), dist, 0, -1)
    # bord nord du pont au-dessus du centre (y Blender du dernier point du pont vers le nord)
    yn_bord = y + _degagement((x, y), lambda p: _d_poly(p, poly), 0, 1)
    out = dict(nom=nom, place=True, x=round(x, 3), yn=round(y / SQ2, 3), r=round(r, 3),
               dx=round(min(dxp, dxm) - MARGE, 3), dy=round(min(dyp, dym) - MARGE, 3),
               h_max=_h_max(prof, math.hypot(x, y) - r),
               h_ajour=round(max(0.0, yn_bord - (y + r)), 3))
    if geo is not None:
        # forme de pont : hauteur du sol à poser (dessus du pont, d'un gradin ou d'une tour d'angle) ; h_max et
        # h_ajour se comptent depuis le sol de la scène (z = 0), pas depuis z_sol
        out["z_sol"] = round(SIL.z_pont(geo, x, y / SQ2), 3)
    return out


def _valeur(v):
    """Littéral Python, y compris dict(clé=…) imbriqués (HABILLAGE des époques)."""
    import ast
    if isinstance(v, ast.Call) and getattr(v.func, "id", "") == "dict":
        return {k.arg: _valeur(k.value) for k in v.keywords}
    if isinstance(v, ast.Tuple):
        return tuple(_valeur(x) for x in v.elts)
    return ast.literal_eval(v)
