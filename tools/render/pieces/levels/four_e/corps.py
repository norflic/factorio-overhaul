"""CORPS DE LIGNÉE du FOUR (lot F2-A, 25/10), aux 5 tailles de l'emprise (2×2 à 6×6). S'exécute DANS Blender.
Contrat : epoques.py ; cotes : cotes.py ; fiches : fo-logs/2026-10-25_F2/FICHES_FOUR.md.

Lignée MINCE, pour que la chambre de chaque âge change de nature (méthode de la mitrailleuse et du laser) :
  SOLE        dalle d'appui de toute l'emprise, motif du pont de l'âge (clé « plateforme »), cornières ;
  FOYER       caisson au milieu de la face sud, au ras du tablier, avec la GUEULE (signal de jeu fixe) : bouche en
              retrait, lit de braises (matière « emit » : éteint dans la couche principale, allumé dans la couche de
              lueur, donc séparable en jeu), grille de barreaux, linteau ; forme « rect », « arche » ou « ronde » ;
              halo de nuit devant la bouche ;
  FUMÉE       bouche_fumee() : lèvre de suie et fond noir de la bouche de fumée, relevée dans c.fumee (signal fixe,
              quart arrière droit, cotes.fumee_valide) ; l'organe qui la porte est celui de l'âge ;
  PATINS      dalles d'appui des pièces de coin (aucun îlot détaché).
Repère : comme la mitrailleuse (kit.py) : +X est, +Y nord, +Z haut ; une tuile de jeu vers le nord = √2 en Y
(repere.Y). Le four ne tourne pas : une seule pose.
"""
import math

from mathutils import Matrix, Vector  # noqa: F401 (Matrix : pour les fichiers d'âge)

import cotes
import formes as F
import parts as PT
from habillage import _lignee, capot, habille, mat, mats_habilles  # noqa: F401
from kit import SQ2, TAU
from pont import PONT_DEFAUT, _motif, _prisme, pont_cfg
from repere import Y, at  # noqa: F401

V = Vector

# dessus de la LIGNÉE (témoin, âge sans clé « plateforme ») : tôles rivetées d'acier
PONT_FOUR = dict(PONT_DEFAUT, motif="toles", mat="armor", mat2="armor2", fond="seam", bord="steel_dk",
                 boulons="steel_hi", pas=0.42, relief=0.2)


class Ctx:
    """g : accumulateur ; e : âge ; ep : module d'âge ; side : côté ; T : cotes de la taille ; hab : habillage ; Mh :
    palette habillée ; pont : réglage du motif du tablier ; fumee : (x, yn, z) de la bouche de fumée (bouche_fumee) ;
    G : géométrie du caisson du foyer (foyer)."""

    def __init__(self, g, e, ep, side, hab):
        self.g, self.M, self.e, self.ep, self.side, self.hab = g, g.M, e, ep, side, hab
        self.T = cotes.TAILLES[side]
        self.Mh = mats_habilles(g.M, hab)
        self.pont = pont_cfg(hab) or dict(PONT_FOUR)
        self.fumee = None
        self.G = None
        g.ctx = self


def coin(c, nom):
    """Place avant (« coin_SO », « coin_SE ») de la pièce du niveau pair : x, yn (centre), rw (demi-largeur), prof."""
    return c.T["coins"][nom]


def quad_sud(x0, x1, yb, z0, z1):
    """Quadrilatère de face SUD (vu de l'extérieur, normale −Y) en coordonnées Blender."""
    return [V((x0, yb, z0)), V((x1, yb, z0)), V((x1, yb, z1)), V((x0, yb, z1))]


def boite(g, x0, x1, yn0, yn1, z0, z1, mats, ins=(0.0, 0.0, 0.0), panel=0.4, faces="ts", rivets=True, t=0.03):
    """Caisson riveté (parts.hull) donné en coordonnées de JEU (yn) ; rend les 4 coins du haut (Blender)."""
    return PT.hull(g, x0, x1, Y(yn0), Y(yn1), z0, z1, ins=ins, panel=panel, mats=mats, rivets=rivets, faces=faces, t=t)


def P(x, yn, z=0.0):
    """Point Blender depuis des coordonnées de jeu (x, yn vers le nord, z)."""
    return V((x, Y(yn), z))


def cyl_v(g, x, yn, r, z0, z1, mat, n=24, r2=None, style="smooth", what="cyl"):
    """Cylindre (ou tronc de cône si r2) vertical au point de jeu (x, yn), de z0 à z1."""
    g.cyl((x, Y(yn), (z0 + z1) / 2.0), "z", r, z1 - z0, mat, n=n, r2=r2, style=style, what=what)


def tronc(g, B, T, mat, mats=None, faces="s", rivets=True, panel=0.3, core=None, t=0.022, rivet_step=0.12):
    """Tronc quelconque : B et T = 4 coins du bas et du haut (ordre SO, SE, NE, NO, Blender) ; noyau plein, plaques
    rivetées sur les faces listées (s, e, n, w, t)."""
    M = g.M
    B = [V(p) for p in B]
    T = [V(p) for p in T]
    g.hexa(B + T, core or M["seam"], "flat", "tronc")
    quads = {"s": [B[0], B[1], T[1], T[0]], "e": [B[1], B[2], T[2], T[1]], "n": [B[2], B[3], T[3], T[2]],
             "w": [B[3], B[0], T[0], T[3]], "t": [T[0], T[1], T[2], T[3]]}
    for f in faces:
        q = quads[f]
        lu, lv = (q[1] - q[0]).length, (q[3] - q[0]).length
        if lu < 0.05 or lv < 0.05:
            continue
        g.panels(q, max(1, int(round(lu / panel))), max(1, int(round(lv / panel))), mat, t=t,
                 rivet_mat=M["rivet"] if rivets else None, mats=mats or [mat], rivet_step=rivet_step)


def briques_sud(g, x0, x1, yn, z0, z1, mats, bw=0.13, bh=0.062):
    """Assises de briques (ou de pierre) sur une face SUD au plan yn (jeu)."""
    F.courses(g, quad_sud(x0, x1, Y(yn), z0, z1), mats, bw=bw, bh=bh)


def rect_arrondi(cx, cy, hx, hy, r, n=6):
    """Contour (Blender, sens direct) d'un rectangle de demi-côtés hx, hy à coins arrondis de rayon r."""
    pts = []
    for (sx, sy, a0) in ((1, -1, -math.pi / 2), (1, 1, 0.0), (-1, 1, math.pi / 2), (-1, -1, math.pi)):
        ox, oy = cx + sx * (hx - r), cy + sy * (hy - r)
        for k in range(n + 1):
            a = a0 + (math.pi / 2) * k / n
            pts.append((ox + r * math.cos(a), oy + r * math.sin(a)))
    return pts


def couronne_poly(g, Pout, Pin, z0, z1, m, what="bande"):
    """Bande pleine entre deux contours (Blender, même nombre de sommets, sens direct) de z0 à z1."""
    n = len(Pout)
    o0 = [(x, y, z0) for x, y in Pout]
    i0 = [(x, y, z0) for x, y in Pin]
    o1 = [(x, y, z1) for x, y in Pout]
    i1 = [(x, y, z1) for x, y in Pin]
    fs = []
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, 2 * n + j, 2 * n + i))
        fs.append((n + j, n + i, 3 * n + i, 3 * n + j))
        fs.append((2 * n + i, 2 * n + j, 3 * n + j, 3 * n + i))
        fs.append((j, i, n + i, n + j))
    g._add(m, "soft", o0 + i0 + o1 + i1, fs, what)


def prisme(g, pts, z0, z1, m, style="soft", what="prisme"):
    """Polygone (Blender, sens direct) extrudé de z0 à z1."""
    _prisme(g, pts, z0, z1, m, style, what)


def tube_v(g, x, yn, rayons, zs, mat, n=28, caps=True, what="coque"):
    """Coque de révolution verticale au point de jeu (x, yn) : rayons[i] à la hauteur zs[i] (tour de refroidissement,
    vasque, colonne galbée)."""
    pts = [V((x, Y(yn), z)) for z in zs]
    g.tube(pts, rayons[0], mat, n=n, radii=list(rayons), caps=caps, what=what)


# ------------------------------------------------------------------------------------------------
# SOLE
# ------------------------------------------------------------------------------------------------
@_lignee
def sole(g, c):
    """Dalle d'appui de toute l'emprise (rentrée de 0,05), motif du pont de l'âge, cornières sur les 4 bords."""
    M = g.M
    cfg = c.pont
    s = c.side
    h = c.T["sole_h"]
    e = s / 2.0 - 0.05
    P = [(-e, -Y(e)), (e, -Y(e)), (e, Y(e)), (-e, Y(e))]
    _prisme(g, P, 0.0, h, M[cfg["fond"]], "flat", "sole")
    _motif(g, M, cfg, P, h, 0.05, 9100 + 7 * s + (c.e or 0))
    b = 0.05
    for (x0, x1, y0, y1) in ((-e, e, -Y(e), -Y(e) + b * SQ2), (-e, e, Y(e) - b * SQ2, Y(e)),
                             (-e, -e + b, -Y(e), Y(e)), (e - b, e, -Y(e), Y(e))):
        g.box(((x0 + x1) / 2, (y0 + y1) / 2, h * 0.6), (x1 - x0, y1 - y0, h * 1.25), M[cfg["bord"]], "hard",
              what="corniere")
    if cfg.get("boulons"):
        n = max(4, int(2 * e / 0.22))
        for k in range(n + 1):
            x = -e + 0.025 + (2 * e - 0.05) * k / n
            g.bolt((x, -Y(e) + b * SQ2 / 2, h * 1.25), (0, 0, 1), 0.012, M[cfg["boulons"]])


# ------------------------------------------------------------------------------------------------
# FOYER ET GUEULE (signal de jeu fixe)
# ------------------------------------------------------------------------------------------------
def foyer(g, c):
    """Caisson du foyer au milieu de la face sud, bouche en retrait, braises, grille, linteau, halo de nuit. Rend et
    garde dans c.G la géométrie (Blender) : x0, x1, yf (face sud), yb (fond du caisson), z0, z1 (caisson), bouche
    (bx0, bx1, bz0, bz1), forme."""
    G = c.T["gueule"]
    forme = c.hab.get("gueule") or "rect"
    zs = c.T["sole_h"]
    x1 = G["wf"] / 2.0
    yf, yb = Y(G["y_face"]), Y(G["y_fond"])
    z0, z1 = zs, G["zb"] + G["hf"] - 0.06
    bx = G["w"] / 2.0
    bz0, bz1 = G["zb"], G["zb"] + G["h"]
    d = 0.16 + 0.03 * c.side                     # profondeur de la bouche (Blender, vers le nord)
    geo = dict(x0=-x1, x1=x1, yf=yf, yb=yb, z0=z0, z1=z1, bx0=-bx, bx1=bx, bz0=bz0, bz1=bz1, forme=forme, d=d)
    c.G = geo
    with habille(g, c):
        M = g.M
        cm = M[c.hab["foyer"]] if c.hab.get("foyer") else capot(c, "olive")
        cm2 = M[c.hab["foyer"]] if c.hab.get("foyer") else capot(c, "ochre")
        # noyau du caisson derrière la bouche (fond de la bouche = face sud du noyau)
        g.box((0, (yf + d + yb) / 2, (z0 + z1) / 2), (2 * x1, yb - yf - d, z1 - z0), M["seam"], "flat", what="caisson")
        # jambages, linteau, seuil : pleins, plaqués et rivetés côté sud
        for (a, b_) in ((-x1, -bx), (bx, x1)):
            g.box(((a + b_) / 2, yf + d / 2, (z0 + z1) / 2), (b_ - a, d, z1 - z0), cm, "hard", what="jambage")
            g.panels(quad_sud(a, b_, yf, z0, z1), 1, max(1, int(round((z1 - z0) / 0.3))), cm, t=0.02,
                     rivet_mat=M["rivet"], mats=[cm, cm2], rivet_step=0.1)
        g.box((0, yf + d / 2, (z0 + bz0) / 2), (2 * bx, d, bz0 - z0), M["steel_dk"], "hard", what="seuil")
        if forme == "arche":
            _linteau_arche(g, c, geo, cm)
        elif forme == "ronde":
            _linteau_rond(g, c, geo, cm)
        else:
            g.box((0, yf + d / 2, (bz1 + z1) / 2), (2 * bx, d, z1 - bz1), cm, "hard", what="linteau")
            g.panels(quad_sud(-bx, bx, yf, bz1, z1), max(1, int(round(2 * bx / 0.3))), 1, cm, t=0.02,
                     rivet_mat=M["rivet"], rivet_step=0.1)
            g.box((0, yf - 0.012, bz1 + 0.02), (2 * bx + 0.08, 0.03, 0.05), M["steel_hi"], "hard", what="cornière")
        # dessus du caisson (ronde 2 : une tôle sombre unie, vue comme une boîte noire devant chaque four) : plaques
        # rivetées aux capots de l'âge, cornière d'acier, trappe de chargement boulonnée au milieu
        g.box((0, (yf + yb) / 2, z1 + 0.008), (2 * x1 + 0.03, yb - yf + 0.02, 0.016), M["steel_dk"], "hard",
              what="chapeau")
        qt = [V((-x1, yf, z1 + 0.016)), V((x1, yf, z1 + 0.016)), V((x1, yb, z1 + 0.016)), V((-x1, yb, z1 + 0.016))]
        g.panels(qt, max(2, int(round(2 * x1 / 0.32))), max(1, int(round((yb - yf) / 0.4))), cm, t=0.02,
                 rivet_mat=M["rivet"], mats=[cm, cm2], rivet_step=0.1)
        g.box((0, yf + 0.015, z1 + 0.03), (2 * x1 + 0.04, 0.03, 0.03), M["steel_hi"], "hard", what="corniere")
        rh = 0.1 + 0.03 * c.side
        PT.hatch(g, (0, (yf + yb) / 2, z1 + 0.036), rh)
        # bouche : fond noir, lit de braises (emit), voûte rougeoyante, grille de barreaux
        g.box((0, yf + d - 0.01, (bz0 + bz1) / 2), (2 * bx, 0.02, bz1 - bz0), M["void"], "flat", what="fond_bouche")
        nb = max(5, int(2 * bx / 0.07))
        for k in range(nb):
            x = -bx + 2 * bx * (k + 0.5) / nb
            g.rng.random()
            g.box((x, yf + d * (0.35 + 0.4 * g.rng.random()), bz0 + 0.04 + 0.03 * g.rng.random()),
                  (2 * bx / nb * 0.9, d * 0.3, 0.06 + 0.04 * g.rng.random()), g.M["emit"], "soft", what="braise")
        g.box((0, yf + d - 0.02, bz0 + (bz1 - bz0) * 0.45), (2 * bx * 0.9, 0.012, (bz1 - bz0) * 0.5), M["emit_soft"],
              "flat", what="lueur_fond")
        nbar = max(4, int(2 * bx / 0.11))
        for k in range(nbar):
            x = -bx + 2 * bx * (k + 0.5) / nbar
            g.box((x, yf + 0.02, (bz0 + bz1) / 2), (0.022 + 0.003 * c.side, 0.03, bz1 - bz0), M["steel_dk"], "hard",
                  what="barreau")
        g.box((0, yf + 0.02, bz0 + (bz1 - bz0) * 0.55), (2 * bx, 0.026, 0.022), M["steel_dk"], "hard", what="traverse")
    g.halo((0, yf - 0.25, (bz0 + bz1) / 2), g.M["_emit_rgb"], c.T["halo"])
    if hasattr(c.ep, "gueule"):
        c.ep.gueule(g, c, geo)
    return geo


def _linteau_arche(g, c, geo, cm):
    """Linteau en plein cintre : la bouche rectangulaire monte jusqu'à 70 % ; au-dessus, demi-disque ouvert (fond
    rougeoyant), voussoirs en tranches verticales au-dessus de la courbe."""
    M = g.M
    bx, bz0, bz1, z1, yf, d = geo["bx1"], geo["bz0"], geo["bz1"], geo["z1"], geo["yf"], geo["d"]
    zr = bz0 + 0.7 * (bz1 - bz0)
    r = bx
    n = 12
    for k in range(n):
        xa, xb = -bx + 2 * bx * k / n, -bx + 2 * bx * (k + 1) / n
        xm = (xa + xb) / 2
        zc = zr + math.sqrt(max(0.0, r * r - xm * xm)) * min(1.0, (z1 - zr - 0.05) / r)
        if z1 - zc > 0.01:
            g.box((xm, yf + d / 2, (zc + z1) / 2), (xb - xa + 0.002, d, z1 - zc), cm, "hard", what="voussoir")
            g.box((xm, yf - 0.006, zc + 0.02), (xb - xa - 0.01, 0.02, 0.05), M["steel_hi"], "hard", what="claveau")
    geo["zr"] = zr


def _linteau_rond(g, c, geo, cm):
    """Hublot rond : linteau plein au-dessus du carré de la bouche, cadre annulaire qui couvre les coins."""
    M = g.M
    bx, bz0, bz1, z1, yf, d = geo["bx1"], geo["bz0"], geo["bz1"], geo["z1"], geo["yf"], geo["d"]
    g.box((0, yf + d / 2, (bz1 + z1) / 2), (2 * bx, d, z1 - bz1), cm, "hard", what="linteau")
    zc = (bz0 + bz1) / 2
    r = min(bx, (bz1 - bz0) / 2)
    g.tube_shell((0, yf - 0.01, zc), "y", r * 1.5, r * 0.98, 0.05, M["steel_dk"], n=32, what="cadre_hublot")
    for k in range(10):
        a = TAU * (k + 0.5) / 10
        g.dome((r * 1.24 * math.cos(a), yf - 0.04, zc + r * 1.24 * math.sin(a)), (0, -1, 0), 0.016, M["rivet"])


def bouche_fumee(g, c, x, yn, z, r, mat=None, levre=True):
    """Bouche de fumée (signal fixe) : lèvre de suie, fond noir ; relève (x, yn, z) dans c.fumee. Refuse une bouche hors
    du quart arrière droit (cotes.fumee_valide)."""
    if not cotes.fumee_valide(c.T, x, yn, z):
        raise ValueError("four âge %s : bouche de fumée hors règle (%.2f, %.2f, %.2f), quart arrière droit exigé"
                         % (c.e, x, yn, z))
    M = g.M
    y = Y(yn)
    if levre:
        g.tube_shell((x, y, z - 0.02), "z", r + 0.02, r * 0.8, 0.05, mat or M["soot"], n=24, what="levre_fumee")
    g.cyl((x, y, z - 0.03), "z", r * 0.82, 0.02, M["void"], n=20, style="flat", what="bouche_fumee")
    c.fumee = (x, yn, z)
    return c.fumee


# ------------------------------------------------------------------------------------------------
# SOCLE ET PIÈCE
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    """Niveau impair : sole, chambre de l'âge, foyer et gueule, fumée de l'âge, accents."""
    sole(g, c)
    c.ep.chambre(g, c)
    foyer(g, c)
    c.ep.fumee(g, c)
    if c.fumee is None:
        raise ValueError("four âge %s : fumee() doit finir par corps.bouche_fumee" % c.e)
    if hasattr(c.ep, "socle"):
        c.ep.socle(g, c)


def piece(g, c):
    """Pièce du niveau pair (couche ajoutée au socle) : à l'âge, sur les places avant."""
    c.ep.piece(g, c)


@_lignee
def patin(g, c, x, yn, w, l, h=0.03):
    """Dalle d'appui au sol (motif du tablier) sous une pièce de coin : (x, yn) centre, w × l tuiles."""
    M = g.M
    cfg = c.pont
    z = c.T["sole_h"]
    hw, hl = w / 2.0, Y(l) / 2.0
    y = Y(yn)
    P = [(x - hw, y - hl), (x + hw, y - hl), (x + hw, y + hl), (x - hw, y + hl)]
    _prisme(g, P, z, z + h, M[cfg["fond"]], "flat", "patin")
    _motif(g, M, cfg, P, z + h, 0.03, int(9300 + 37 * abs(x) + 53 * abs(yn)))
    for (a, b, cc, d_) in ((-hw, hw, -hl, -hl + 0.04), (-hw, hw, hl - 0.04, hl)):
        g.box((x + (a + b) / 2, y + (cc + d_) / 2, z + h * 0.6), (b - a, d_ - cc, h * 1.2), M[cfg["bord"]], "hard",
              what="corniere")


def bac(g, c, nom, mat_bac=None, mat_charge=None, h=None):
    """Pièce de coin par défaut : bac riveté plein de charge (minerai, charbon) sur un patin."""
    p = coin(c, nom)
    M = g.M
    w, l = 2 * p["rw"] * 0.9, p["prof"] * 0.85
    patin(g, c, p["x"], p["yn"], w, l)
    z0 = c.T["sole_h"] + 0.03
    hh = h or (0.18 + 0.05 * c.side)
    with habille(g, c):
        m = mat_bac or capot(c, "ochre")
        boite(g, p["x"] - w * 0.42, p["x"] + w * 0.42, p["yn"] - l * 0.4, p["yn"] + l * 0.4, z0, z0 + hh, [m],
              ins=(0.01, 0.01, 0.01), panel=0.3, faces="s")
    for k in range(7):
        a = TAU * k / 7
        F.lump(g,(p["x"] + w * 0.22 * math.cos(a), Y(p["yn"]) + Y(l) * 0.2 * math.sin(a), z0 + hh),
             0.05 + 0.012 * c.side, mat_charge or g.M["rawiron"], sz=0.7)
