"""CORPS DE LIGNÉE de la MACHINE D'ASSEMBLAGE (lot F3-A, 25/10), aux 4 tailles de l'emprise (3×3 à 6×6). S'exécute DANS
Blender. Contrat : epoques.py ; cotes : cotes.py ; fiches : fo-logs/2026-10-25_F3/FICHES_ASSEMBLEUR.md.

Même style et même précision que la mitrailleuse validée (kit commun ../commun : kit.Geo, parts*, formes, pont,
habillage), avec un corps PROPRE à l'assembleur, pour qu'il ne se confonde ni avec la mitrailleuse (pont carré, tourelle
à canons), ni avec le laser (gâteau rond à gradins), ni avec le four et la foreuse :
  EMBASE carrée (ou chanfreinée, à gradins, sur pieux) au motif du pont de l'âge, cornière au bord ;
  DOS haut au nord (bloc des mécanismes) : sa FACE SUD et son DESSUS sont les grandes surfaces vues de la caméra ;
  JOUES est et ouest, plus basses, jusqu'aux coins avant (laissés libres) ;
  BAIE ouverte au sud, TABLE DE TRAVAIL au centre (l'OUVRAGE de l'âge y est posé) ;
  PORTIQUE au-dessus de la table (poutre, arche, cadre de presse, ou aucun) : il porte l'OUTIL de l'âge ;
  SIGNAUX DE JEU fixes : brides de fluide N (collecteur sur le dos) et S (pied de la baie), trémie d'entrée (joue ouest),
  bac de sortie (joue est).
Vue de trois quarts depuis le sud (comme le jeu) : seules les faces SUD et les DESSUS se voient ; les faces est et ouest
sont vues par la tranche. Repère : +X est, +Y nord (une tuile de jeu = √2 en Y, repere.Y), +Z haut.
"""
import math

from mathutils import Matrix, Vector

import cotes
import formes as F
import parts as PT
import parts2 as P2
from habillage import (_lignee, habille, mat, mats_habilles)  # noqa: F401
from kit import SQ2, TAU
from pont import PONT_DEFAUT, _lisere, _motif, _prisme, pont_cfg
from repere import Y, at  # noqa: F401

V = Vector

# dessus de l'embase de la LIGNÉE (âge 0 et âge sans clé « plateforme ») : tôles rivetées d'acier sombre
PONT_ASM = dict(PONT_DEFAUT, motif="toles", mat="armor", mat2="armor2", fond="seam", bord="steel_dk",
                boulons="steel_hi", pas=0.5, relief=0.2)


class Ctx:
    """g : accumulateur ; e : âge ; ep : module d'âge ; side : côté ; T : cotes (cotes.TAILLES) ; hab : habillage ;
    Mh : palette habillée ; pont : réglage du dessus de l'embase ; formes : embase, dos, joues, portique ; raccourcis :
    h, ze, yb, Hd, Hj, xb, wj, yf, yt, zt, zp."""

    def __init__(self, g, e, ep, side, hab):
        self.g, self.M, self.e, self.ep, self.side, self.hab = g, g.M, e, ep, side, hab
        self.T = cotes.TAILLES[side]
        self.Mh = mats_habilles(g.M, hab)
        self.pont = pont_cfg(hab) or dict(PONT_ASM)
        self.f_embase = hab.get("forme_embase") or "carre"
        self.f_dos = hab.get("forme_dos") or "plat"
        self.f_joues = hab.get("forme_joues") or "caisson"
        self.f_portique = hab.get("forme_portique") or "poutre"
        T = self.T
        self.h, self.ze = T["h"], T["embase"]["ze"]
        self.yb, self.Hd, self.dd = T["dos"]["yb"], T["dos"]["Hd"], T["dos"]["dd"]
        self.Hj, self.xb, self.wj, self.yf = T["joues"]["Hj"], T["joues"]["xb"], T["joues"]["wj"], T["joues"]["yf"]
        self.yt, self.zt = T["table"]["yt"], T["table"]["zt"]
        self.zs, self.hpar, self.epar = T["plateau"]["zs"], T["plateau"]["hpar"], T["plateau"]["epar"]
        # hauteurs des formes du dos, comptées depuis le PLATEAU (troisième jet : sous zs, la face est cachée)
        dz = self.Hd - self.zs
        self.zw_pans = self.zs + 0.5 * dz         # haut des murs sous le toit à deux pans
        self.zw_voute = self.zs + 0.3 * dz        # naissance du berceau
        self.hs_gradins = [self.zs + 0.45 * dz, self.zs + 0.75 * dz, self.Hd]
        self.zm_tours = self.zs + 0.5 * dz        # milieu bas entre les deux tours
        self.z_tours = self.Hd + 0.08 * side      # les deux tours dépassent le dos
        self.zc_coque = self.zs + 0.4 * dz        # haut de la face droite de la coque
        self.zb_dome = self.zs + 0.35 * dz        # caisson sous la coupole
        self.zp, self.bp, self.xm, self.wm = (T["portique"]["zp"], T["portique"]["bp"], T["portique"]["xm"],
                                              T["portique"]["wm"])
        self.z_joue = self.Hj       # dessus réel des joues (rempli par joues())
        self.z_nord = self.Hd       # hauteur du dos au bord nord (bride N)
        # ronde F3-A2 : PLAN du corps (plans.py) ; dos « bas » (portique) au ras du bâti
        self.plan = hab.get("plan") or "carre"
        self.z_bas = self.zs + 0.12 + 0.03 * side
        g.ctx = self
        import plans
        plans.init(self)
        self.reserves += _reserves_carre(self) if self.plan in ("carre", "L", "portique") else []


def place(c, nom=None):
    """Places de la lignée (cotes.places), corrigées par le plan : coins de la pièce paire hors du tambour (rond,
    octo), entrée et sortie (place_es)."""
    p = dict(cotes.places(c.side))
    plan = getattr(c, "plan", "carre")
    if plan in ("rond", "octo"):
        h = c.h
        for nom_, sx in (("coin_SO", -1), ("coin_SE", 1)):
            p[nom_] = dict(x=sx * 0.8 * h, yn=-0.8 * h, z_sol=0.0, r=0.17 * h)
    return p[nom] if nom else p


def place_es(c, quoi):
    """Place de l'ENTRÉE (« entree ») ou de la SORTIE (« sortie ») selon le plan : dict(x, yn, z, r)."""
    if c.plan in ("rond", "octo", "tour"):
        return dict(c.pl_entree if quoi == "entree" else c.pl_sortie)
    if c.plan == "portique":
        # sur le bâti, devant la table, aux deux bouts du parapet (les pylônes cachent l'arrière des joues)
        r = 0.06 * c.side + 0.06
        sx = -1 if quoi == "entree" else 1
        return dict(x=sx * (c.xb - r - 0.08), yn=-c.h + c.epar + r + 0.12, z=c.zs, r=r)
    pl = cotes.places(c.side)["joue_O" if quoi == "entree" else "joue_E"]
    z = c.Hd if (c.plan == "L" and quoi == "entree") else c.z_joue
    return dict(x=pl["x"], yn=pl["yn"], z=z, r=pl["r"])


def _reserves_carre(c):
    out = []
    pl = cotes.places(c.side)
    for nom in ("joue_O", "joue_E"):
        out.append((pl[nom]["x"], pl[nom]["yn"], pl[nom]["r"] + 0.05))
    out.append((0.0, c.h - 0.3, 0.2))           # collecteur N
    if c.plan in ("carre", "L") and c.f_portique == "poutre":
        for sx in (-1, 1):
            out.append((sx * c.xm, c.yt, c.wm + 0.05))
    if c.plan == "portique":
        r = 0.06 * c.side + 0.06
        for sx in (-1, 1):
            out.append((sx * (c.xb - r - 0.08), -c.h + c.epar + r + 0.12, r + 0.05))
            out.append((sx * c.xp, c.yt, c.dp * 0.7))
    return out


def mat_de(c, cle, defaut):
    """Matière d'habillage propre (mat_dos…) ou la matière habillée par défaut."""
    v = c.hab.get(cle)
    return c.M[v] if v else c.Mh[defaut]


# ------------------------------------------------------------------------------------------------
# Outils de forme
# ------------------------------------------------------------------------------------------------
def B(x, yn, z=0.0):
    """Point de jeu (x, yn en tuiles, z) -> Vector Blender."""
    return V((x, Y(yn), z))


def poly_b(pts):
    """Polygone de jeu [(x, yn)] -> polygone Blender [(X, Y)]."""
    return [(x, Y(yn)) for x, yn in pts]


def prisme_x(g, x0, x1, poly_yz, m, style="hard", what="prisme_x"):
    """Prisme d'axe X : polygone (Y, Z) Blender, sens direct vu depuis +X, extrudé de x0 à x1."""
    n = len(poly_yz)
    vs = [(x0, y, z) for y, z in poly_yz] + [(x1, y, z) for y, z in poly_yz]
    fs = [tuple(range(n)), tuple(range(n, 2 * n))[::-1]]
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, n + i, n + j, j))
    g._add(m, style, vs, fs, what)


def face_s(g, x0, x1, yn, z0, z1, mat_, nu=None, nv=None, rivets=True, t=0.022, mats=None, pas=0.38):
    """Habille une face SUD (plan yn) de plaques rivetées."""
    q = [B(x0, yn, z0), B(x1, yn, z0), B(x1, yn, z1), B(x0, yn, z1)]
    nu = nu or max(1, int(round((x1 - x0) / pas)))
    nv = nv or max(1, int(round((z1 - z0) / pas)))
    g.panels(q, nu, nv, mat_, t=t, rivet_mat=g.M["rivet"] if rivets else None, mats=mats, rivet_step=0.15)
    return q


def dessus(g, x0, x1, y0, y1, z, mat_, pas=0.42, rivets=True, mats=None, t=0.02):
    """Habille un dessus horizontal (jeu) de plaques."""
    q = [B(x0, y0, z), B(x1, y0, z), B(x1, y1, z), B(x0, y1, z)]
    nu = max(1, int(round((x1 - x0) / pas)))
    nv = max(1, int(round((y1 - y0) / pas)))
    g.panels(q, nu, nv, mat_, t=t, rivet_mat=g.M["rivet"] if rivets else None, mats=mats, rivet_step=0.15)


def corniere(g, pts, z, m, w=0.05, hgt=0.04):
    """Cornière le long d'un contour de jeu fermé [(x, yn)] à la hauteur z."""
    n = len(pts)
    for i in range(n):
        a, b = B(*pts[i], z), B(*pts[(i + 1) % n], z)
        d = b - a
        L = d.length
        if L < 1e-6:
            continue
        R = Matrix((d.normalized(), V((-d.y, d.x, 0)).normalized(), V((0, 0, 1)))).transposed()
        g.box((a + b) / 2 + V((0, 0, hgt / 2)), (L + w, w, hgt), m, "hard", R=R, what="corniere")


def chevron(g, x, yn, z, sens, m, k=0.12):
    """Flèche plate (chevron) au sol ou sur un dessus : sens = +1 vers l'est, −1 vers l'ouest."""
    for i in range(2):
        xx = x + sens * i * k * 0.7
        pts = [(xx - sens * k * 0.4, yn + k * 0.5), (xx + sens * k * 0.15, yn), (xx - sens * k * 0.4, yn - k * 0.5),
               (xx - sens * k * 0.2, yn - k * 0.5), (xx + sens * k * 0.35, yn), (xx - sens * k * 0.2, yn + k * 0.5)]
        pb = poly_b(pts)
        if sens < 0:
            pb = pb[::-1]
        _prisme(g, pb, z, z + 0.008, m, "flat", "chevron")


# ------------------------------------------------------------------------------------------------
# EMBASE
# ------------------------------------------------------------------------------------------------
def contour_embase(c, ins=0.0):
    h = c.h - ins
    if getattr(c, "plan", "carre") == "rond":
        import plans
        return plans.contour(h, 40)
    if getattr(c, "plan", "carre") == "octo":
        k = 0.586 * h
        return [(-h + k, -h), (h - k, -h), (h, -h + k), (h, h - k), (h - k, h), (-h + k, h), (-h, h - k), (-h, -h + k)]
    if c.f_embase == "chanfrein":
        k = c.T["embase"]["chanfrein"]
        return [(-h + k, -h), (h - k, -h), (h, -h + k), (h, h - k), (h - k, h), (-h + k, h), (-h, h - k), (-h, -h + k)]
    return [(-h, -h), (h, -h), (h, h), (-h, h)]


@_lignee
def embase(g, c):
    M = g.M
    ze = c.ze
    f = c.f_embase
    cfg = c.pont
    z0 = 0.0
    if f == "gradins":
        # DEUX MARCHES sur tout le bord SUD (perron) : dalle basse pleine, dalle haute reculée de « marche » au sud
        # seulement (les joues, le dos et les coins arrière restent au ras de l'emprise : aucun porte-à-faux)
        mch = c.T["embase"]["marche"]
        bas = contour_embase(c)
        fond0 = M[cfg["fond"]] if cfg["fond"] in M else M["seam"]
        _prisme(g, poly_b(bas), 0.0, ze * 0.5, fond0, "hard", "marche")
        _flancs(g, c, bas, 0.0, ze * 0.5, M["steel_dk"])
        _motif(g, M, cfg, poly_b([(-c.h, -c.h), (c.h, -c.h), (c.h, -c.h + mch), (-c.h, -c.h + mch)]), ze * 0.5, 0.03,
               990 + c.e)
        z0 = ze * 0.5
        haut = [(x, max(yn, -c.h + mch)) for x, yn in bas]
    elif f == "pieds":
        z0 = ze * 0.55
        haut = contour_embase(c)
        h = c.h - 0.08
        n = max(3, int(round(2 * h / 0.45)) + 1)
        for i in range(n):
            for j in range(n):
                x = -h + 2 * h * i / (n - 1)
                yn = -h + 2 * h * j / (n - 1)
                if 0 < i < n - 1 and 0 < j < n - 1:
                    continue
                g.cyl(B(x, yn, z0 / 2), "z", 0.05, z0, M["steel_dk"], n=8, style="soft", what="pieu")
        # sous-face sombre (le jour sous la dalle reste ouvert vers le bas de l'image : jamais enfermé)
        _prisme(g, poly_b(contour_embase(c, 0.1)), 0.02, z0, M["seam"], "flat", "ame")
    else:
        haut = contour_embase(c)
    fond = M[cfg["fond"]] if cfg["fond"] in M else M["seam"]
    _prisme(g, poly_b(haut), z0, ze, fond, "hard", "embase")
    _flancs(g, c, haut, z0, ze, M["steel_dk"])
    _motif(g, M, cfg, poly_b(haut), ze, 0.05, 1000 + 7 * c.side + c.e)
    bord = M[cfg["bord"]] if cfg["bord"] in M else M["steel_dk"]
    corniere(g, haut, ze, bord)
    if cfg.get("lisere"):
        n = len(haut)
        for i in range(n):
            a, b = B(*haut[i]), B(*haut[(i + 1) % n])
            d = (b - a).normalized()
            nrm = V((d.y, -d.x, 0))
            _lisere(g, M, cfg, a, b, nrm, ze + 0.04)


def _flancs(g, c, pts, z0, z1, m):
    """Plaques des flancs SUD-visibles d'un contour (arêtes dont la normale a une composante sud)."""
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L < 0.05 or z1 - z0 < 0.05:
            continue
        nx, ny = dy / L, -dx / L      # normale extérieure (contour direct)
        if ny > -0.3:
            continue
        q = [B(a[0], a[1], z0), B(b[0], b[1], z0), B(b[0], b[1], z1), B(a[0], a[1], z1)]
        g.panels(q, max(1, int(round(L / 0.45))), 1, m, t=0.016, rivet_mat=g.M["rivet"], rivet_step=0.15)


# ------------------------------------------------------------------------------------------------
# DOS (bloc nord)
# ------------------------------------------------------------------------------------------------
@_lignee
def dos(g, c):
    if hasattr(c.ep, "dos"):
        c.ep.dos(g, c)
        return
    M = g.M
    m1 = mat_de(c, "mat_dos", "olive")
    m2 = c.Mh["ochre"]
    h, yb, ze, Hd = c.h, c.yb, c.ze, c.Hd
    f = c.f_dos
    x0, x1 = -h + 0.02, h - 0.02
    y0, y1 = yb, h - 0.02
    if f == "bas":
        zb_ = c.z_bas
        PT.hull(g, x0, x1, Y(y0), Y(y1), ze, zb_, ins=(0.02, 0.0, 0.0), panel=0.55, mats=[m1], faces="st")
        corniere(g, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)], zb_, M["steel_dk"], w=0.05, hgt=0.04)
        c.z_nord = zb_
    elif f == "plat":
        PT.hull(g, x0, x1, Y(y0), Y(y1), ze, Hd, ins=(0.02, 0.0, 0.0), panel=0.55, mats=[m1], faces="st")
        corniere(g, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)], Hd, M["steel_dk"], w=0.05, hgt=0.05)
        c.z_nord = Hd
    elif f == "pans":
        zw = c.zw_pans
        PT.hull(g, x0, x1, Y(y0), Y(y1), ze, zw, ins=(0.0, 0.0, 0.0), panel=0.55, mats=[m1], faces="s")
        ym = (y0 + y1) / 2.0
        roof = [(Y(y0) - 0.08, zw - 0.04), (Y(y1) + 0.08, zw - 0.04), (Y(ym), Hd)]
        prisme_x(g, x0 - 0.06, x1 + 0.06, roof, M["seam"], "hard", "toit")
        # tuiles du versant sud (plaques en rangées)
        q = [V((x0 - 0.06, Y(y0) - 0.08, zw - 0.04)), V((x1 + 0.06, Y(y0) - 0.08, zw - 0.04)),
             V((x1 + 0.06, Y(ym), Hd)), V((x0 - 0.06, Y(ym), Hd))]
        g.panels(q, max(2, int((x1 - x0) / 0.32)), max(2, int((Hd - zw) / 0.14)), m2, t=0.02, gap=0.025,
                 rivet_mat=None, mats=[m2, m1])
        g.cyl(V((0, Y(ym), Hd + 0.01)), "x", 0.05, x1 - x0 + 0.14, M["steel_dk"], n=10, style="soft", what="faitage")
        c.z_nord = zw
    elif f == "voute":
        zw = c.zw_voute
        PT.hull(g, x0, x1, Y(y0), Y(y1), ze, zw, ins=(0.0, 0.0, 0.0), panel=0.55, mats=[m1], faces="s")
        ry = (Y(y1) - Y(y0)) / 2.0
        rz = Hd - zw
        yc = (Y(y0) + Y(y1)) / 2.0
        arc = [(yc + ry * math.cos(math.pi * i / 16), zw + rz * math.sin(math.pi * i / 16)) for i in range(17)]
        prisme_x(g, x0, x1, arc, m1, "smooth", "voute")
        nb = max(3, int((x1 - x0) / 0.45))
        for k in range(nb + 1):
            x = x0 + 0.05 + (x1 - x0 - 0.1) * k / nb
            arc2 = [(yc + (ry + 0.03) * math.cos(math.pi * i / 16), zw + (rz + 0.03) * math.sin(math.pi * i / 16))
                    for i in range(17)]
            prisme_x(g, x - 0.025, x + 0.025, arc2, M["steel_dk"], "soft", "cerclage")
        c.z_nord = zw
    elif f == "gradins":
        hs = c.hs_gradins
        for k, zz in enumerate(hs):
            yy0 = y0 + (y1 - y0) * k / 3.0
            ins = 0.06 * k
            PT.hull(g, x0 + ins, x1 - ins, Y(yy0), Y(y1), ze, zz, ins=(0.0, 0.0, 0.0), panel=0.42,
                    mats=[m1] if k % 2 == 0 else [m2], faces="st")
            corniere(g, [(x0 + ins, yy0), (x1 - ins, yy0), (x1 - ins, y1), (x0 + ins, y1)], zz, M["steel_dk"],
                     w=0.04, hgt=0.03)
        c.z_nord = Hd
    elif f == "tours":
        wt = 0.26 * c.side
        zm = c.zm_tours
        PT.hull(g, x0 + wt, x1 - wt, Y(y0), Y(y1), ze, zm, ins=(0.0, 0.0, 0.0), panel=0.55, mats=[m2],
                faces="st")
        for sx in (-1, 1):
            xa, xb_ = (x0, x0 + wt) if sx < 0 else (x1 - wt, x1)
            PT.hull(g, xa, xb_, Y(y0 - 0.04), Y(y1), ze, c.z_tours, ins=(0.0, 0.03, 0.0), panel=0.4,
                    mats=[m1], faces="st")
            corniere(g, [(xa + 0.03, y0), (xb_ - 0.03, y0), (xb_ - 0.03, y1), (xa + 0.03, y1)], c.z_tours,
                     M["steel_dk"], w=0.04, hgt=0.04)
        c.z_nord = zm
    elif f == "coque":
        zc = c.zc_coque
        PT.hull(g, x0, x1, Y(y0), Y(y1), ze, zc, ins=(0.0, 0.0, 0.0), panel=0.5, mats=[m1, m1], faces="s",
                rivets=False)
        Bq = [V((x0, Y(y0), zc)), V((x1, Y(y0), zc)), V((x1, Y(y1), zc)), V((x0, Y(y1), zc))]
        Tq = [V((x0, Y(y0) + 0.02, zc + 0.04)), V((x1, Y(y0) + 0.02, zc + 0.04)), V((x1, Y(y1), Hd)),
              V((x0, Y(y1), Hd))]
        g.hexa(Bq + Tq, m1, "soft", "coque")
        rn = 0.07 * c.side
        g.cyl(V((0, Y(y0) + rn * 0.3, zc)), "x", rn, x1 - x0, m1, n=20, style="smooth", what="nez")
        g.panels([Tq[0], Tq[1], Tq[2], Tq[3]], max(2, int((x1 - x0) / 0.6)), 2, m2, t=0.012, gap=0.03,
                 rivet_mat=None)
        c.z_nord = Hd
    elif f == "dome":
        zb_ = c.zb_dome
        PT.hull(g, x0, x1, Y(y0), Y(y1), ze, zb_, ins=(0.0, 0.0, 0.0), panel=0.55, mats=[m2], faces="st")
        ym = (y0 + y1) / 2.0
        rx = min(h * 0.62, 0.55 * c.side)
        ry = (Y(y1) - Y(y0)) / 2.0 * 0.92
        rz = Hd - zb_
        r = max(rx, ry, rz)
        g.sphere(V((0, Y(ym), zb_)), r, m1, n=40, m=20, scale=(rx / r, ry / r, rz / r), what="coupole")
        # ceinture ELLIPTIQUE comme la coupole (ronde 3 : un tore rond de rayon rx débordait de 1,3 tuile au nord et au
        # sud de la coupole, cercle noir et trou enfermé de 5 454 px à l'âge 13)
        pts = [V((rx * 0.99 * math.cos(TAU * i / 48), Y(ym) + ry * 0.99 * math.sin(TAU * i / 48), zb_ + 0.02))
               for i in range(49)]
        g.tube(pts, 0.035, M["steel_dk"], n=8, what="ceinture")
        c.z_nord = zb_
    # face sud : soubassement sombre (garde le pied net quel que soit le dos)
    g.box(B(0, y0 - 0.015, ze + 0.04), (x1 - x0, 0.03 * SQ2, 0.08), M["steel_dk"], "hard", what="plinthe")


# ------------------------------------------------------------------------------------------------
# JOUES
# ------------------------------------------------------------------------------------------------
@_lignee
def joues(g, c):
    M = g.M
    m1 = mat_de(c, "mat_joues", "olive")
    m2 = c.Mh["ochre"]
    f = c.f_joues
    ze, Hj, yf, yb = c.ze, c.Hj, c.yf, c.yb
    for sx in (-1, 1):
        xa, xb_ = (-c.h + 0.02, -c.xb) if sx < 0 else (c.xb, c.h - 0.02)
        if c.plan == "L" and sx < 0:
            # AILE du plan L : joue ouest à pleine hauteur du dos, face sud à plaques
            PT.hull(g, xa, xb_, Y(yf), Y(yb), ze, c.Hd, ins=(0.0, 0.0, 0.0), panel=0.5, mats=[m1], faces="st")
            corniere(g, [(xa, yf), (xb_, yf), (xb_, yb), (xa, yb)], c.Hd, M["steel_dk"], w=0.05, hgt=0.04)
            continue
        if f == "socle":
            zz = c.zs + 0.06
            PT.hull(g, xa, xb_, Y(yf), Y(yb), ze, zz, ins=(0.015, 0.0, 0.0), panel=0.55, mats=[m1], faces="st")
            corniere(g, [(xa, yf), (xb_, yf), (xb_, yb), (xa, yb)], zz, M["steel_dk"], w=0.04, hgt=0.03)
            c.z_joue = zz
        elif f in ("caisson", "basses"):
            zz = Hj if f == "caisson" else c.zs + 0.45 * (Hj - c.zs)
            PT.hull(g, xa, xb_, Y(yf), Y(yb), ze, zz, ins=(0.015, 0.0, 0.0), panel=0.55, mats=[m1],
                    faces="st")
            corniere(g, [(xa, yf), (xb_, yf), (xb_, yb), (xa, yb)], zz, M["steel_dk"], w=0.04, hgt=0.03)
            c.z_joue = zz
        elif f == "pente":
            zf = c.zs + 0.1 * (Hj - c.zs)
            Bq = [B(xa, yf, ze), B(xb_, yf, ze), B(xb_, yb, ze), B(xa, yb, ze)]
            Tq = [B(xa, yf, zf), B(xb_, yf, zf), B(xb_, yb, Hj), B(xa, yb, Hj)]
            g.hexa(Bq + Tq, M["seam"], "flat", "joue")
            g.panels([Bq[0], Bq[1], Tq[1], Tq[0]], max(1, int((xb_ - xa) / 0.4)), 1, m1, t=0.02,
                     rivet_mat=M["rivet"], rivet_step=0.15)
            g.panels([Tq[0], Tq[1], Tq[2], Tq[3]], max(1, int((xb_ - xa) / 0.4)), max(1, int((yb - yf) / 0.4)), m1,
                     t=0.02, rivet_mat=M["rivet"], mats=[m1], rivet_step=0.15)
            c.z_joue = Hj
        elif f == "colonnes":
            zs = c.zs
            _prisme(g, poly_b([(xa, yf), (xb_, yf), (xb_, yb), (xa, yb)]), ze, zs, m2, "hard", "socle_joue")
            n = max(2, int(round((yb - yf) / 0.38)))
            xc = (xa + xb_) / 2.0
            rc = min(0.09 + 0.01 * c.side, (xb_ - xa) * 0.3)
            for k in range(n + 1):
                yn = yf + 0.1 + (yb - yf - 0.2) * k / n
                g.cyl(B(xc, yn, (zs + Hj) / 2), "z", rc, Hj - zs - 0.08, m1, n=14, style="soft", what="colonne")
                g.box(B(xc, yn, zs + 0.025), (rc * 2.6, rc * 2.6 * SQ2, 0.05), m2, "hard", what="base_col")
                g.box(B(xc, yn, Hj - 0.06), (rc * 2.6, rc * 2.6 * SQ2, 0.05), m2, "hard", what="chapiteau")
            _prisme(g, poly_b([(xa, yf), (xb_, yf), (xb_, yb), (xa, yb)]), Hj - 0.035, Hj + 0.05, m2, "hard",
                    "linteau")
            c.z_joue = Hj + 0.05


# ------------------------------------------------------------------------------------------------
# PLATEAU DE BAIE (troisième jet), TABLE et PORTIQUE
# ------------------------------------------------------------------------------------------------
@_lignee
def plateau(g, c):
    """Plateau de baie surélevé entre les joues (la machine se lit comme un bloc ; les coins avant restent au sol) :
    face sud à plaques, motif du pont de l'âge sur le dessus, parapet au bord sud (bandes de danger de l'âge)."""
    M = g.M
    cfg = c.pont
    xb, h, ze, zs = c.xb + 0.01, c.h, c.ze, c.zs
    y0, y1 = -h + 0.02, c.yb + 0.01
    fond = M[cfg["fond"]] if cfg["fond"] in M else M["seam"]
    _prisme(g, poly_b([(-xb, y0), (xb, y0), (xb, y1), (-xb, y1)]), ze, zs, fond, "hard", "plateau_baie")
    face_s(g, -xb, xb, y0, ze, zs, c.Mh["olive"], nv=1, pas=0.6)
    for sx in (-1, 1):
        xd = sx * xb * 0.55
        wd, hd = min(0.5, xb * 0.5), (zs - ze) * 0.62
        g.box(B(xd, y0 - 0.02, ze + 0.04 + hd / 2), (wd, 0.03, hd), c.Mh["ochre"], "hard", what="porte_bati")
        g.box(B(xd + sx * wd * 0.32, y0 - 0.04, ze + 0.04 + hd * 0.5), (0.03, 0.03, hd * 0.3), M["steel_hi"],
              "hard", what="poignee")
        for f in (0.2, 0.8):
            g.box(B(xd - sx * wd * 0.5, y0 - 0.035, ze + 0.04 + hd * f), (0.04, 0.03, 0.06), M["steel_dk"], "hard",
                  what="gond")
    cfg1 = dict(cfg, mat2=None)
    _motif(g, M, cfg1, poly_b([(-xb, y0), (xb, y0), (xb, y1), (-xb, y1)]), zs, 0.04, 1200 + 7 * c.side + c.e)
    bord = M[cfg["bord"]] if cfg["bord"] in M else M["steel_dk"]
    corniere(g, [(-xb, y0), (xb, y0), (xb, y1), (-xb, y1)], zs, bord, w=0.04, hgt=0.03)
    # parapet du bord sud, ouvert au milieu (la tubulure et l'icône restent dégagées)
    ep, hp = c.epar, c.hpar
    for sx in (-1, 1):
        xa, xz = sx * 0.28, sx * xb
        xa, xz = min(xa, xz), max(xa, xz)
        g.box(B((xa + xz) / 2, y0 + ep / 2, zs + hp / 2), (xz - xa, ep * SQ2, hp), c.Mh["olive"], "hard",
              what="parapet")
        g.hazard([B(xa + 0.02, y0 - 0.004, zs + hp * 0.35), B(xz - 0.02, y0 - 0.004, zs + hp * 0.35),
                  B(xz - 0.02, y0 - 0.004, zs + hp * 0.85), B(xa + 0.02, y0 - 0.004, zs + hp * 0.85)],
                 max(4, int((xz - xa) / 0.12)), t=0.006)
        g.box(B((xa + xz) / 2, y0 + ep / 2, zs + hp + 0.012), (xz - xa + 0.02, ep * SQ2 + 0.02, 0.024), bord, "hard",
              what="lisse")


@_lignee
def table(g, c):
    M = g.M
    m = mat_de(c, "mat_table", "steel_dk")
    tx, ty, yt, zt, ze = c.T["table"]["tx"], c.T["table"]["ty"], c.yt, c.zt, c.zs
    g.box(B(0, yt, (ze + zt - 0.04) / 2), (2 * tx * 0.86, 2 * ty * 0.86 * SQ2, zt - 0.04 - ze), M["seam"], "hard",
          what="pied_table")
    face_s(g, -tx * 0.86, tx * 0.86, yt - ty * 0.86, ze, zt - 0.04, m, nv=1)
    g.box(B(0, yt, zt - 0.02), (2 * tx, 2 * ty * SQ2, 0.04), M["steel"], "hard", what="plateau")
    corniere(g, [(-tx, yt - ty), (tx, yt - ty), (tx, yt + ty), (-tx, yt + ty)], zt - 0.01, M["steel_dk"], w=0.03,
             hgt=0.025)
    # brides de serrage aux quatre coins
    for sx in (-1, 1):
        for sy in (-1, 1):
            g.box(B(sx * tx * 0.82, yt + sy * ty * 0.78, zt + 0.02), (0.05, 0.05 * SQ2, 0.04), M["steel_hi"], "hard",
                  what="bride_table")


@_lignee
def portique(g, c):
    M = g.M
    f = c.f_portique
    if f == "aucun":
        return
    m = mat_de(c, "mat_portique", "steel_dk")
    yt, zp, bp, xm, wm = c.yt, c.zp, c.bp, c.xm, c.wm
    if f == "poutre":
        for sx in (-1, 1):
            g.box(B(sx * xm, yt, (c.z_joue + zp + bp) / 2), (wm, wm * SQ2, zp + bp - c.z_joue), m, "hard",
                  what="montant")
            g.box(B(sx * xm, yt, c.z_joue + 0.03), (wm * 1.6, wm * 1.6 * SQ2, 0.06), M["steel_dk"], "hard",
                  what="semelle")
        L = 2 * xm + wm
        g.box(B(0, yt, zp + bp / 2), (L, wm * 0.9 * SQ2, bp), m, "hard", what="poutre")
        g.hazard([B(-L / 2 + 0.05, yt - wm * 0.45 - 0.004, zp + 0.01), B(L / 2 - 0.05, yt - wm * 0.45 - 0.004, zp + 0.01),
                  B(L / 2 - 0.05, yt - wm * 0.45 - 0.004, zp + bp - 0.01),
                  B(-L / 2 + 0.05, yt - wm * 0.45 - 0.004, zp + bp - 0.01)][::1], max(6, int(L / 0.12)), t=0.006)
        # chariot au centre
        g.box(B(0, yt, zp + bp + 0.04), (0.22 + 0.03 * c.side, wm * 1.3 * SQ2, 0.08), M["steel"], "hard",
              what="chariot")
        for sx in (-1, 1):
            g.cyl(B(sx * 0.08, yt - wm * 0.62, zp + bp + 0.02), "y", 0.035, 0.03, M["steel_hi"], n=10, what="galet")
    elif f == "arche":
        n = 14
        pts = []
        for i in range(n + 1):
            a = math.pi * i / n
            pts.append(B(-xm * math.cos(a), yt, c.z_joue + (zp + bp - c.z_joue) * math.sin(a)))
        g.tube(pts, wm * 0.55, m, n=8, what="arche")
        g.box(B(0, yt, zp + bp + 0.02), (wm * 1.4, wm * 1.3 * SQ2, wm * 1.2), M["steel"], "hard", what="clef")
        for sx in (-1, 1):
            g.box(B(sx * xm, yt, c.z_joue + 0.04), (wm * 1.8, wm * 1.8 * SQ2, 0.08), M["steel_dk"], "hard",
                  what="sommier")
    elif f == "cadre":
        xc = c.xb * 0.92
        top = zp + bp
        for sx in (-1, 1):
            g.box(B(sx * xc, c.yt, (c.ze + top) / 2), (wm * 1.2, wm * 1.6 * SQ2, top - c.ze), m, "hard",
                  what="colonne_presse")
            face_s(g, sx * xc - wm * 0.6, sx * xc + wm * 0.6, c.yt - wm * 0.8, c.ze, top, m, nu=1)
        g.box(B(0, c.yt, top + 0.08), (2 * xc + wm * 1.6, wm * 2.0 * SQ2, 0.16 + 0.02 * c.side), m, "hard",
              what="chapeau")
        face_s(g, -xc - wm * 0.8, xc + wm * 0.8, c.yt - wm, top, top + 0.16 + 0.02 * c.side, m, nv=1)


# ------------------------------------------------------------------------------------------------
# SIGNAUX DE JEU : brides de fluide, entrée, sortie
# ------------------------------------------------------------------------------------------------
@_lignee
def ports(g, c):
    """Brides de fluide au milieu des bords NORD et SUD, selon le plan."""
    M = g.M
    r = 0.07 + 0.01 * c.side
    if c.plan in ("rond", "octo"):
        ys, zs_ = -(c.Rb - 0.06) * (0.924 if c.plan == "octo" else 1.0), c.ze + (c.zr - c.ze) * 0.5
    elif c.plan == "tour":
        ys, zs_ = -c.Rp, c.ze + (c.zr - c.ze) * 0.5
    else:
        ys, zs_ = -c.h, c.ze + (c.zs - c.ze) * 0.5
    g.cyl(B(0, ys + 0.06, zs_), "y", r, 0.2, M["steel_dk"], n=14, what="port_s")
    g.cyl(B(0, ys, zs_), "y", r * 1.5, 0.05, M["steel"], n=16, style="hard", what="bride_s")
    for k in range(6):
        a = TAU * k / 6 + 0.3
        g.dome(B(r * 1.25 * math.cos(a), ys - 0.02, zs_ + r * 1.25 * math.sin(a)), (0, -1, 0), 0.016, M["steel_hi"])
    if c.plan in ("rond", "octo", "tour"):
        # NORD : conduite au ras du sol du bord nord au corps (croissant ou pied de la tour), coude qui y entre
        yn0 = c.h - 0.04
        if c.plan == "tour":
            yn1, z1 = c.Rt / SQ2 + 0.05, c.zr + 0.15
        else:
            yn1, z1 = c.Rb - 0.06 - c.ep_cr * 0.5, c.Hc + 0.05
        zn = c.ze + r + 0.03 if c.plan == "tour" else z1 + r
        if c.plan == "tour":
            g.tube([B(0, yn0, zn), B(0, (yn0 + yn1) / 2, zn), B(0, yn1 + 0.05, z1)], r, M["steel_dk"], n=14,
                   what="port_n")
        else:
            g.tube([B(0, yn0, zn), B(0, yn1, zn), B(0, yn1 - 0.05, z1 - 0.05)], r, M["steel_dk"], n=14, what="port_n")
        g.cyl(B(0, yn0, zn), "y", r * 1.5, 0.05, M["steel"], n=16, style="hard", what="bride_n")
        return
    zn = c.z_nord + r + 0.03
    yn0 = c.h - 0.04
    yn1 = c.h - min(0.45, c.dd * 0.45)
    g.tube([B(0, yn0, zn), B(0, yn1, zn), B(0, yn1 - 0.05, zn - 0.08), B(0, yn1 - 0.06, c.z_nord - 0.05)], r,
           M["steel_dk"], n=14, what="port_n")
    g.cyl(B(0, yn0, zn), "y", r * 1.5, 0.05, M["steel"], n=16, style="hard", what="bride_n")
    g.box(B(0, (yn0 + yn1) / 2, c.z_nord + 0.02), (r * 2.2, 0.06 * SQ2, zn - c.z_nord), M["steel_dk"], "hard",
          what="selle_n")


@_lignee
def entree(g, c):
    """ENTRÉE : trémie (ou objet propre à l'âge : def entree(g, c, p)) et chevron vers la machine."""
    p = place_es(c, "entree")
    if hasattr(c.ep, "entree"):
        c.ep.entree(g, c, p)
    else:
        r = p["r"]
        P2.hopper(g, p["x"] - r, p["x"] + r, Y(p["yn"] - r), Y(p["yn"] + r), p["z"], p["z"] + 0.18 + 0.03 * c.side,
                  g.M, paint=c.Mh["ochre"])
    chevron(g, p["x"] + p["r"] * 0.2, p["yn"] - p["r"] - 0.1, p["z"] + 0.005, +1, c.Mh["hazy"], k=0.1)


@_lignee
def sortie(g, c):
    """SORTIE : bac PROPRE À L'ÂGE (def sortie(g, c, p), obligatoire depuis la ronde F3-A2) et chevron vers l'extérieur."""
    p = place_es(c, "sortie")
    if hasattr(c.ep, "sortie"):
        c.ep.sortie(g, c, p)
    else:
        bac(g, c, p, c.Mh["ochre"], g.M["steel_hi"])
    chevron(g, p["x"] - p["r"] * 0.2, p["yn"] - p["r"] - 0.1, p["z"] + 0.005, +1, c.Mh["hazy"], k=0.1)


def bac(g, c, p, paroi, produit, forme="engrenage"):
    """Bac ouvert à la place p, parois `paroi`, produits finis `produit` (engrenage, lingot, sphère, plaque)."""
    M = g.M
    r, z = p["r"], p["z"]
    sx, sy, sz = 2 * r, 2 * r * SQ2 * 0.9, 0.1 + 0.02 * c.side
    cx, cy = p["x"], Y(p["yn"])
    t = 0.03
    for (px, py, w, d) in ((cx, cy - sy / 2 + t / 2, sx, t), (cx, cy + sy / 2 - t / 2, sx, t),
                           (cx - sx / 2 + t / 2, cy, t, sy), (cx + sx / 2 - t / 2, cy, t, sy)):
        g.box((px, py, z + sz / 2), (w, d, sz), paroi, "hard", what="bac")
    g.box((cx, cy, z + sz * 0.4), (sx - 2 * t, sy - 2 * t, sz * 0.8), M["seam"], "flat", what="fond_bac")
    k = 0
    for i in (-1, 1):
        for j in (-1, 1):
            q = V((cx + i * sx * 0.22, cy + j * sy * 0.22, z + sz * 0.8 + 0.012 * (k % 2)))
            rr = 0.05 + 0.005 * c.side
            if forme == "engrenage":
                g.cyl(q, "z", rr, 0.03, produit, n=12, style="hard", what="produit")
                g.cyl(q + V((0, 0, 0.017)), "z", rr * 0.35, 0.012, M["steel_dk"], n=8, what="moyeu")
            elif forme == "lingot":
                g.box(q + V((0, 0, 0.02)), (rr * 1.8, rr * 0.9 * SQ2, 0.04), produit, "hard", what="produit")
            elif forme == "sphere":
                g.sphere(q + V((0, 0, rr * 0.7)), rr * 0.75, produit, n=12, m=6, what="produit")
            else:
                g.box(q + V((0, 0, 0.012)), (rr * 1.9, rr * 1.9 * SQ2, 0.02), produit, "hard", what="produit")
            k += 1


@_lignee
def liaisons(g, c):
    """Conduites qui RELIENT le corps à l'outil (plans carre, L, portique et tour ; les plans rond et octo ont les rayons) :
    deux tuyaux à brides et un faisceau de câbles. Un âge les retire par LIAISONS = False."""
    if not getattr(c.ep, "LIAISONS", True) or c.plan in ("rond", "octo"):
        return
    M = g.M
    r = 0.028 + 0.004 * c.side
    if c.plan == "tour":
        for sx in (-1, 1):
            p0 = B(sx * c.Rp * 0.75, -c.Rp * 0.35, c.zr)
            p1 = V((sx * c.Rt * 0.8, -c.Rt * 0.6, c.zr + 0.35 * (c.Ht - c.zr)))
            g.pipe([p0, p0.lerp(p1, 0.5) + V((0, 0, 0.1)), p1], r, M["steel_dk"], fl_mat=M["steel"],
                   bolt_mat=M["rivet"])
        return
    tx, ty = c.T["table"]["tx"], c.T["table"]["ty"]
    if c.plan == "portique":
        for sx in (-1, 1):
            p0 = B(sx * (c.xp - c.wp / 2), c.yt - c.dp / 2 - 0.02, c.zs + 0.3)
            p1 = B(sx * tx * 0.7, c.yt - ty * 0.5, c.zt + 0.08)
            g.hose([p0, p0.lerp(p1, 0.5) + V((0, 0, 0.12)), p1], r, M["rubber"], step=0.04)
        return
    for sx in (-1, 1):
        p0 = B(sx * tx * 0.55, c.yb - 0.02, c.zs + 0.25)
        p1 = B(sx * tx * 0.45, c.yt + ty * 0.7, c.zt + 0.1)
        g.pipe([p0, p0.lerp(p1, 0.5) + V((0, 0, 0.15)), p1], r, M["steel_dk"], fl_mat=M["steel"], bolt_mat=M["rivet"])
    g.cable(B(0.15, c.yb - 0.02, c.zs + 0.35), B(0.1, c.yt + ty * 0.6, c.zt + 0.2), 0.08, 0.02, M["rubber"])


# ------------------------------------------------------------------------------------------------
# Pièces et machine
# ------------------------------------------------------------------------------------------------
def machine(g, c):
    """Machine du niveau impair : corps du plan + organes de l'âge + liaisons + garniture dense."""
    import garniture
    import plans
    embase(g, c)
    if c.plan in ("carre", "L", "portique"):
        dos(g, c)
        joues(g, c)
        plateau(g, c)
        table(g, c)
        if c.plan == "portique":
            plans.pylones(g, c)
        else:
            portique(g, c)
    elif c.plan in ("rond", "octo"):
        plans.tambour(g, c)
    else:
        plans.tour(g, c)
    ports(g, c)
    entree(g, c)
    sortie(g, c)
    garniture.garnir(g, c)
    ep = c.ep
    if hasattr(ep, "socle"):
        ep.socle(g, c)
    if hasattr(ep, "ouvrage"):
        ep.ouvrage(g, c)
    if hasattr(ep, "outil"):
        ep.outil(g, c)
    if c.plan in ("rond", "octo") and getattr(ep, "RAYONS", True):
        plans.rayons(g, c)
    liaisons(g, c)
    garniture.densifier(g, c)


def piece(g, c):
    """Pièce du niveau pair (couche dessinée PAR-DESSUS la machine, aux coins avant)."""
    c.ep.piece(g, c)


def caisse(g, c, x, yn, z, s, m, cercle=None):
    """Petite caisse (clouée ou cerclée) posée en (x, yn, z), côté s (tuiles)."""
    g.box(B(x, yn, z + s / 2), (s, s * SQ2, s), m, "hard", what="caisse")
    cm = cercle or g.M["steel_dk"]
    for f in (0.2, 0.8):
        g.box(B(x, yn - s / 2 - 0.004, z + s * f), (s * 1.01, 0.012, 0.025), cm, "hard", what="cercle")
    g.box(B(x, yn, z + s + 0.006), (s * 0.9, s * 0.9 * SQ2, 0.012), m, "hard", what="couvercle")


def z_toit(c, x, yn):
    """Hauteur du DESSUS du dos de la lignée en (x, yn) (tuiles) selon forme_dos (0 hors du dos) : pour poser un organe
    d'âge sur le toit. Un âge qui remplace le dos (def dos) remplace aussi ce calcul s'il pose des choses dessus."""
    h, yb, ze, Hd = c.h, c.yb, c.ze, c.Hd
    y0, y1 = yb, h - 0.02
    if not (y0 <= yn <= y1 and abs(x) <= h):
        return 0.0
    f = c.f_dos
    if f == "bas":
        return c.z_bas
    ym, half = (y0 + y1) / 2.0, (y1 - y0) / 2.0
    if f == "pans":
        zw = c.zw_pans
        return zw + (Hd - zw) * max(0.0, 1.0 - abs(yn - ym) / (half + 0.06))
    if f == "voute":
        zw = c.zw_voute
        u = (yn - ym) / half
        return zw + (Hd - zw) * math.sqrt(max(0.0, 1.0 - u * u))
    if f == "gradins":
        hs = c.hs_gradins
        k = min(2, int((yn - y0) / ((y1 - y0) / 3.0)))
        return hs[k]
    if f == "tours":
        wt = 0.26 * c.side
        return c.z_tours if abs(x) > h - 0.02 - wt else c.zm_tours
    if f == "coque":
        zc = c.zc_coque
        return zc + 0.04 + (Hd - zc - 0.04) * (yn - y0) / (y1 - y0)
    if f == "dome":
        zb_ = c.zb_dome
        rx = min(h * 0.62, 0.55 * c.side)
        ry = half * 0.92
        u = (x / rx) ** 2 + ((yn - ym) / ry) ** 2
        return zb_ + (Hd - zb_) * math.sqrt(1.0 - u) if u < 1.0 else zb_
    return Hd


def halo(g, x, yn, z, k=1.0, rgb=None):
    """Source de halo (passe light, nuit) en (x, yn, z) ; puissance proportionnelle à k."""
    g.halo(tuple(B(x, yn, z)), rgb or g.M["_emit_rgb"], 6.0 * k)


def fenetre(g, x, yn, z, w, hgt, verre, cadre, croisillon=True):
    """Fenêtre sur une face sud (plan yn) : cadre, verre (souvent lumineux), croisillon."""
    g.box(B(x, yn - 0.028, z), (w + 0.05, 0.03, hgt + 0.05), cadre, "hard", what="cadre_fenetre")
    g.box(B(x, yn - 0.036, z), (w, 0.02, hgt), verre, "flat", what="vitre")
    if croisillon:
        g.box(B(x, yn - 0.046, z), (0.022, 0.012, hgt), cadre, "hard", what="croisillon")
        g.box(B(x, yn - 0.046, z), (w, 0.012, 0.022), cadre, "hard", what="croisillon")


def lampe(g, p, r, emat, cage=None):
    """Voyant rond posé sur une surface horizontale (p : Vector Blender)."""
    g.cyl(p + V((0, 0, r * 0.4)), "z", r, r * 0.8, emat, n=12, style="soft", what="voyant")
    if cage is not None:
        g.torus(p + V((0, 0, r * 0.5)), "z", r * 1.15, r * 0.18, cage, n=12, m=5, what="cage")


def lampe_face(g, x, yn, z, r, emat, cadre):
    """Voyant rond sur une face sud (plan yn)."""
    g.cyl(B(x, yn - 0.03, z), "y", r * 1.3, 0.03, cadre, n=12, style="hard", what="bague")
    g.cyl(B(x, yn - 0.045, z), "y", r, 0.025, emat, n=12, style="soft", what="voyant")
