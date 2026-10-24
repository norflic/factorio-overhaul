"""CORPS DE LIGNÉE de la TOURELLE LASER (lot F1-A, 24/10), aux 5 tailles de l'emprise (2×2 à 6×6). S'exécute DANS
Blender. FICHIER GELÉ pour les constructeurs d'âge (contrat : epoques.py ; fiches : fo-logs/2026-10-24_F1/FICHES_LASER.md).

Même style et même précision que la mitrailleuse validée (kit commun ../commun : kit.Geo, parts*, formes, pont,
habillage), mais un corps PROPRE au laser, pour qu'un joueur ne confonde JAMAIS les deux tourelles au même âge :
  socle : AFFÛT ROND À GRADINS (2 à 4 gradins ronds à l'écran, flancs à plaques rivetées ou en assises, dessus au motif
          du pont de l'âge, arêtes de cornière, liseré lumineux facultatif) ; COURONNE DE CONDENSATEURS debout sur le
          premier gradin (n = 8 à 16, cerclés, couronne lumineuse à la couleur de l'âge) ; PIVOT (tambour nervuré à fente
          lumineuse, couronne boulonnée) ; LIAISONS radiales des condensateurs au pivot (organe de liaison de l'âge) ;
          AUCUNE trémie, aucune plateforme carrée, aucune colonne à couronne dentée (signes de la mitrailleuse) ;
  tête  : PLATINE tournante boulonnée ; SUPPORT de l'émetteur (forme_tete : étrier à deux joues et tourillons, berceau,
          anneau, fourche) ; CAISSON ARRIÈRE (refroidisseur à ailettes et grille) ; ÉMETTEUR de l'âge au centre, faisceau
          vers +Y, SANS CANON (règle F119 : rien de long ni de dressé) ; corps.lentille() pose la face avant (verre
          sombre, anneau lumineux, point focal).
Repère : comme la mitrailleuse (kit.py) : +X est, +Y nord, +Z haut, une tuile de jeu vers le nord = √2 en Y (repere.Y) ;
la tête est modélisée faisceau vers +Y et reçoit la rotation de la pose (kit.Geo.rotz).
"""
import math

from mathutils import Matrix, Vector

import cotes
import formes as F
import parts as PT
from habillage import (_lignee, capot, habille, mat, mats_habilles)  # noqa: F401
from kit import SQ2, TAU
from pont import PONT_DEFAUT, _motif, _prisme, pont_cfg
from repere import Y, at  # noqa: F401

V = Vector

# dessus des gradins de la LIGNÉE (âge 0 et âge sans clé « plateforme ») : tôles rivetées d'acier (pas de caillebotis :
# c'est le pont de la mitrailleuse)
PONT_LASER = dict(PONT_DEFAUT, motif="toles", mat="armor", mat2="armor2", fond="seam", bord="steel_dk",
                  boulons="steel_hi", pas=0.42, relief=0.2)
AFFUT_DEFAUT = dict(gradins=None, pans=None, profil="droit", flanc="olive", flanc2="ochre", assises=False,
                    lisere=None, rapport=None)


class Ctx:
    """g : accumulateur ; e : âge ; ep : module d'âge ; side : côté ; T : cotes de la taille (cotes.TAILLES) ; hab :
    habillage ; Mh : palette habillée ; pont : réglage du dessus des gradins ; affut : forme de l'affût (complétée) ;
    gradins : [(rayon du pied, rayon du haut, z0, z1)] (rempli par affut) ; env : enveloppe de l'émetteur ; zh, xc."""

    def __init__(self, g, e, ep, side, hab):
        self.g, self.M, self.e, self.ep, self.side, self.hab = g, g.M, e, ep, side, hab
        self.T = cotes.TAILLES[side]
        self.Mh = mats_habilles(g.M, hab)
        self.pont = pont_cfg(hab) or dict(PONT_LASER)
        a = dict(AFFUT_DEFAUT)
        a.update(hab.get("forme_affut") or {})
        a["gradins"] = int(a["gradins"] or self.T["affut"]["gradins"])
        a["rapport"] = float(a["rapport"] or self.T["affut"]["rapport"])
        self.affut = a
        self.forme_tete = hab.get("forme_tete") or "etrier"
        self.gradins = []
        t = self.T["tete"]
        self.zh, self.xc, self.re = t["zh"], t["xc"], t["re"]
        self.env = dict(x=t["re"], y0=t["y_ar"], y1=t["y_av"], z0=t["zh"] - t["re"], z1=t["zh"] + t["re"])
        g.ctx = self


# ------------------------------------------------------------------------------------------------
# Outils de forme (ronds à l'écran : demi-axe Y × √2)
# ------------------------------------------------------------------------------------------------
def anneau_pts(R, z, n, phase=0.0, rond=True):
    """n points d'un cercle de rayon R (tuiles) à la hauteur z ; rond=True : rond à l'écran (Y × √2)."""
    k = SQ2 if rond else 1.0
    return [V((R * math.cos(phase + TAU * i / n), k * R * math.sin(phase + TAU * i / n), z)) for i in range(n)]


def anneau_plat(g, R_out, R_in, z0, z1, m, n=48, rond=True, what="anneau"):
    """Anneau plein (couronne) d'épaisseur z1 − z0 entre R_in et R_out, rond à l'écran par défaut."""
    o0, i0 = anneau_pts(R_out, z0, n, rond=rond), anneau_pts(R_in, z0, n, rond=rond)
    o1, i1 = anneau_pts(R_out, z1, n, rond=rond), anneau_pts(R_in, z1, n, rond=rond)
    vs = [tuple(p) for p in o0 + i0 + o1 + i1]
    fs = []
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, 2 * n + j, 2 * n + i))
        fs.append((n + j, n + i, 3 * n + i, 3 * n + j))
        fs.append((2 * n + i, 2 * n + j, 3 * n + j, 3 * n + i))
        fs.append((j, i, n + i, n + j))
    g._add(m, "soft", vs, fs, what)


def place(c, nom=None):
    """Places libres des superstructures (cotes.places) à la taille de c : dict par nom ou la place nommée."""
    p = cotes.places(c.side)
    return p[nom] if nom else p


def z_gradin(c, x, yn):
    """Hauteur du dessus de l'affût au point (x, yn) en tuiles (0 hors de l'affût) : pour poser un organe d'âge SUR un
    gradin."""
    r = math.hypot(x, yn)
    z = 0.0
    for (Rb, Rt, z0, z1) in c.gradins:
        if r <= Rt:
            z = z1
    return z


# ------------------------------------------------------------------------------------------------
# SOCLE : affût rond à gradins
# ------------------------------------------------------------------------------------------------
@_lignee
def affut(g, c):
    """Gradins de l'affût (forme_affut) : flancs habillés, dessus au motif du pont de l'âge, cornière d'arête, boulons,
    liseré facultatif. Remplit c.gradins. Tout est PLEIN jusqu'au sol (aucun trou possible)."""
    M = g.M
    A = c.affut
    n = A["gradins"]
    radii = cotes.rayons_gradins(c.side, n, A["rapport"])
    zs = cotes.hauteurs_gradins(c.side, n)
    nseg = int(A["pans"]) if A["pans"] else c.T["affut"]["segments"]
    phase = math.pi / nseg if A["pans"] else 0.0
    bord = c.T["affut"]["bord"]
    flanc = M[A["flanc"]] if A["flanc"] in M else capot(c, "olive")
    flanc2 = M[A["flanc2"]] if A["flanc2"] in M else capot(c, "ochre")
    cfg = c.pont
    Rp = c.T["pivot"]["R"]
    c.gradins = []
    for i in range(n):
        R0 = radii[i]
        z0 = zs[i - 1] if i else 0.0
        z1 = zs[i]
        prof = A["profil"]
        if prof == "chanfrein":
            Rtop = R0 - (0.05 + 0.012 * c.side)
        elif prof == "cone":
            Rtop = radii[i + 1] + 0.02 if i + 1 < n else max(Rp + 0.1, R0 * 0.82)
        elif prof == "bombe":
            Rtop = R0 * 0.95
        else:
            Rtop = R0
        b = anneau_pts(R0, z0, nseg, phase)
        if prof == "bombe":
            zm = (z0 + z1) / 2
            m_ = anneau_pts(R0 * 1.03, zm, nseg, phase)
            t = anneau_pts(Rtop, z1, nseg, phase)
            _flancs(g, c, b, m_, flanc, flanc2, A)
            _flancs(g, c, m_, t, flanc, flanc2, A)
        else:
            t = anneau_pts(Rtop, z1, nseg, phase)
            _flancs(g, c, b, t, flanc, flanc2, A)
        # dessus : motif du pont de l'âge sur tout le disque du haut (le gradin suivant couvre le centre)
        P2 = [(p.x, p.y) for p in t]
        _prisme(g, P2, z1 - 0.012, z1, M[cfg["fond"]], "flat", "dessus")
        _motif(g, M, cfg, P2, z1, bord + 0.02, 8100 + 10 * c.side + i)
        # cornière d'arête (matière « bord » du pont), boulons, liseré
        anneau_plat(g, Rtop + 0.01, Rtop - bord, z1, z1 + 0.026, M[cfg["bord"]], n=nseg * 2 if not A["pans"] else nseg,
                    what="corniere")
        if cfg.get("boulons"):
            nb = max(8, int(TAU * Rtop / 0.24))
            for k in range(nb):
                a = TAU * (k + 0.5) / nb
                g.bolt(((Rtop - bord * 0.5) * math.cos(a), SQ2 * (Rtop - bord * 0.5) * math.sin(a), z1 + 0.026),
                       (0, 0, 1), 0.014, M[cfg["boulons"]])
        if A["lisere"]:
            anneau_plat(g, Rtop - bord * 0.25, Rtop - bord * 0.75, z1 + 0.026, z1 + 0.032, M[A["lisere"]],
                        n=nseg * 2 if not A["pans"] else nseg, what="lisere")
        c.gradins.append((R0, Rtop, z0, z1))
    return c.gradins


def _flancs(g, c, b, t, flanc, flanc2, A):
    """Flancs d'un tronc (anneaux b et t) : noyau plein, puis plaques rivetées (ou assises) sur les faces VISIBLES
    (faces sud et flancs ; les faces nord cachées par la tête restent en noyau habillé)."""
    M = g.M
    n = len(b)
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    g._add(M["seam"], "flat", [tuple(p) for p in b + t], faces, "noyau")
    for i in range(n):
        j = (i + 1) % n
        q = [b[i], b[j], t[j], t[i]]
        mid = (b[i] + b[j]) / 2
        lu = (q[1] - q[0]).length
        lv = (q[3] - q[0]).length
        if lu < 0.06 or lv < 0.04:
            continue
        if mid.y > 0.35 * max(abs(p.y) for p in b):   # face nord : derrière la tête, jamais vue de face
            g.slab(q, (q[1] - q[0]).cross(q[3] - q[0]).normalized(), 0.02, flanc, "hard", "plaque")
            continue
        if A["assises"]:
            F.courses(g, q, [flanc, flanc2], bw=0.13, bh=0.062)
        else:
            g.panels(q, max(1, int(round(lu / 0.28))), max(1, int(round(lv / 0.3))), flanc, t=0.022,
                     rivet_mat=M["rivet"], mats=[flanc, flanc, flanc2], rivet_step=0.12)


# ------------------------------------------------------------------------------------------------
# SOCLE : couronne de condensateurs, pivot, liaisons
# ------------------------------------------------------------------------------------------------
def places_condensateurs(c):
    """[(x, y Blender, z, r, h)] des condensateurs de la couronne (vide si l'âge n'en veut pas)."""
    cd = c.hab.get("condensateurs")
    if cd is False:
        return []
    T = c.T["condensateurs"]
    n = (cd or {}).get("n") or T["n"]
    r, h = T["r"], T["h"]
    R0, Rtop, z0, z1 = c.gradins[0]
    R2 = c.gradins[1][0] if len(c.gradins) > 1 else c.T["pivot"]["R"] + 0.1
    if Rtop - R2 >= 2 * r + 0.02:
        Rm, z = (Rtop + R2) / 2.0, z1 + 0.026
    else:
        Rm, z = R0 - 0.35 * r, 0.0      # adossés au flanc du premier gradin, posés au sol
    out = []
    for k in range(n):
        a = math.pi / n + TAU * k / n
        out.append((Rm * math.cos(a), SQ2 * Rm * math.sin(a), z, r, h))
    return out


def condensateurs(g, c):
    """Couronne de condensateurs (ou ceux de l'âge : ep.condensateur, même place)."""
    pl = places_condensateurs(c)
    for (x, y, z, r, h) in pl:
        if hasattr(c.ep, "condensateur"):
            c.ep.condensateur(g, c, x, y, z, r, h)
        else:
            condensateur_lignee(g, c, x, y, z, r, h)
    return pl


@_lignee
def condensateur_lignee(g, c, x, y, z, r, h):
    """Condensateur de la lignée : fût (capot olive habillé), bande de peinture, deux cerclages, chapeau d'acier,
    couronne lumineuse de l'âge, borne de cuivre."""
    M = g.M
    cer = M[c.hab["cerclages"]]
    g.cyl((x, y, z + h / 2), "z", r, h, capot(c, "olive"), n=20, style="soft", what="condensateur")
    g.tube_shell((x, y, z + h * 0.55), "z", r + 0.008, r - 0.01, h * 0.16, M["redpaint"], n=20, what="bande")
    for f in (0.12, 0.86):
        g.tube_shell((x, y, z + h * f), "z", r + 0.014, r - 0.01, 0.03, cer, n=20, what="cerclage")
    g.cyl((x, y, z + h + 0.012), "z", r * 0.92, 0.024, M["steel_dk"], n=20, style="soft", what="chapeau")
    g.tube_shell((x, y, z + h + 0.03), "z", r * 0.7, r * 0.52, 0.016, M["emit_soft"], n=20, what="couronne_lum")
    g.cyl((x, y, z + h + 0.05), "z", r * 0.22, 0.05, M["copper"], n=8, what="borne")


@_lignee
def pivot(g, c):
    """Tambour du pivot sur le dernier gradin : fût nervuré, fente lumineuse, couronne boulonnée, bande de danger."""
    M = g.M
    P = c.T["pivot"]
    R, h, z0 = P["R"], P["h"], c.gradins[-1][3]
    g.cyl((0, 0, z0 + h / 2), "z", R, h, capot(c, "olive"), n=64, style="soft", what="pivot")
    nb = max(10, int(TAU * R / 0.14))
    for k in range(nb):
        a = TAU * k / nb
        Rr = Matrix.Rotation(a, 3, "Z")
        g.box((math.cos(a) * (R + 0.012), math.sin(a) * (R + 0.012), z0 + h * 0.45), (0.03, 0.028, h * 0.8),
              M["steel_dk"], "hard", R=Rr, what="nervure")
    g.tube_shell((0, 0, z0 + h * 0.62), "z", R + 0.006, R - 0.02, 0.022, M["emit_soft"], n=64, what="fente")
    g.tube_shell((0, 0, z0 + h - 0.015), "z", R + 0.03, R - 0.06, 0.03, M["steel_dk"], n=64, what="couronne")
    nseg = 2 * max(6, int(TAU * R / 0.3))
    for i in range(nseg):
        a0, a1 = TAU * i / nseg, TAU * (i + 1) / nseg
        ro, ri = R + 0.02, R - 0.05
        q = [V((ri * math.cos(a0), ri * math.sin(a0), z0 + h)), V((ro * math.cos(a0), ro * math.sin(a0), z0 + h)),
             V((ro * math.cos(a1), ro * math.sin(a1), z0 + h)), V((ri * math.cos(a1), ri * math.sin(a1), z0 + h))]
        g.hexa(q + [p + V((0, 0, 0.014)) for p in q], M["hazy"] if i % 2 else M["hazk"], "flat", "danger")
    F.bolts_ring(g, (0, 0, z0 + h + 0.016), (0, 0, 1), R - 0.1, max(8, int(TAU * R / 0.16)), M["rivet"], r=0.018)
    return z0 + h


def liaison_defaut(g, pts, r):
    """Organe de liaison de la lignée (témoin) : gaine annelée de caoutchouc."""
    g.hose(pts, r, g.M["rubber"], step=0.03, n=10, what="gaine")


def liaisons_radiales(g, c, pl, pas=2, r=None):
    """Liaisons des condensateurs au pivot (organe de liaison de l'âge, ep.liaison ; défaut : gaine) : un sur `pas`,
    sur la moitié AVANT seulement (les autres sont derrière la tête)."""
    if not pl:
        return
    liaison = getattr(c.ep, "liaison", None) or liaison_defaut
    P = c.T["pivot"]
    zp = c.gradins[-1][3]
    r = r or (0.022 + 0.006 * c.side)
    for k, (x, y, z, rc, h) in enumerate(pl):
        if k % pas:
            continue
        a = math.atan2(y / SQ2, x)
        d = V((math.cos(a), math.sin(a), 0.0))
        p0 = V((x, y, z + h + 0.04))
        p2 = V((d.x * (P["R"] + 0.02), d.y * (P["R"] + 0.02), zp + P["h"] * 0.35))
        p1 = (p0 + p2) / 2 + V((0, 0, 0.12 + 0.02 * c.side))
        liaison(g, [p0, p1, p2], r)


def socle(g, c):
    """Base du niveau impair : affût, condensateurs, pivot, liaisons radiales (lignée), puis l'âge (ep.socle)."""
    affut(g, c)
    c.condos = condensateurs(g, c)
    c.zpivot = pivot(g, c)
    liaisons_radiales(g, c, c.condos)
    if hasattr(c.ep, "socle"):
        c.ep.socle(g, c)


def piece(g, c):
    """Pièce du niveau pair (couche ajoutée au socle, coins avant) : à l'âge (ep.piece). L'affût est calculé SANS être
    dessiné, pour que la pièce sache où se poser (c.gradins)."""
    _gradins_seuls(c)
    c.ep.piece(g, c)


def _gradins_seuls(c):
    A = c.affut
    n = A["gradins"]
    radii = cotes.rayons_gradins(c.side, n, A["rapport"])
    zs = cotes.hauteurs_gradins(c.side, n)
    c.gradins = [(radii[i], radii[i], zs[i - 1] if i else 0.0, zs[i]) for i in range(n)]


@_lignee
def patin(g, c, x, yn, w, l, h=0.035, rz=0.0):
    """Dalle d'appui au sol (même motif que le dessus des gradins) qui relie une pièce de coin au premier gradin :
    aucun îlot détaché (ilots.py). (x, yn) : centre ; w × l : largeur × longueur en tuiles ; rz : rotation."""
    M = g.M
    cfg = c.pont
    with at(g, x, yn, rz):
        hw, hl = w / 2.0, l * SQ2 / 2.0
        P = [(-hw, -hl), (hw, -hl), (hw, hl), (-hw, hl)]
        _prisme(g, P, 0.0, h, M[cfg["fond"]], "flat", "patin")
        _motif(g, M, cfg, P, h, 0.03, int(8300 + 37 * abs(x) + 53 * abs(yn)))
        for (a, b, cc, d_) in ((-hw, hw, -hl, -hl + 0.05), (-hw, hw, hl - 0.05, hl), (-hw, -hw + 0.05, -hl, hl),
                               (hw - 0.05, hw, -hl, hl)):
            g.box(((a + b) / 2, (cc + d_) / 2, h * 0.6), (b - a, d_ - cc, h * 1.2), M[cfg["bord"]], "hard",
                  what="corniere")


# ------------------------------------------------------------------------------------------------
# TÊTE (repère de la tête : faisceau vers +Y)
# ------------------------------------------------------------------------------------------------
@_lignee
def platine(g, c):
    """Platine tournante : disque boulonné (capot olive), jupe d'acier, couronne de rivets."""
    M = g.M
    t = c.T["tete"]
    z0, h, R = t["z0"], t["hpl"], t["Rt"]
    g.cyl((0, 0, z0 + h / 2), "z", R, h, capot(c, "olive"), n=64, style="soft", what="platine")
    g.tube_shell((0, 0, z0 + 0.018), "z", R + 0.03, R - 0.04, 0.036, M["steel_dk"], n=64, what="jupe")
    F.bolts_ring(g, (0, 0, z0 + h + 0.002), (0, 0, 1), R - 0.06, max(8, int(TAU * R / 0.13)), M["rivet"], r=0.016)
    return z0 + h


@_lignee
def support(g, c):
    """Support de l'émetteur selon forme_tete (étrier, berceau, anneau, fourche) ; axe des tourillons à c.zh."""
    M = g.M
    t = c.T["tete"]
    zb = t["z0"] + t["hpl"]
    re, xc, tc, zh = t["re"], t["xc"], t["tc"], c.zh
    cer = M[c.hab["cerclages"]]
    f = c.forme_tete
    if f in ("etrier", "berceau"):
        # étrier : joues hautes et étroites ; berceau : joues larges et basses (arrondi plus petit) sur un U plein
        ry = 0.72 * re if f == "etrier" else 0.5 * re
        for sx in (-1, 1):
            xa, xb = sorted((sx * xc, sx * (xc + tc)))
            PT.hull(g, xa, xb, -ry, ry, zb, zh, ins=(0.0, 0.03, 0.03), panel=0.22,
                    mats=[capot(c, "olive"), capot(c, "ochre")], faces="tsnew", rivet_step=0.12)
            g.cyl(((xa + xb) / 2, 0, zh), "x", ry, tc, capot(c, "olive"), n=32, style="soft", what="joue")
            _tourillon(g, c, sx, cer)
        if f == "berceau":
            PT.hull(g, -xc - tc, xc + tc, -0.62 * re, 0.62 * re, zb, zh - 0.72 * re, ins=(0.02, 0.03, 0.03),
                    panel=0.24, mats=[capot(c, "olive"), M["steel_dk"]], faces="tsnew", rivet_step=0.12)
    elif f == "anneau":
        Ra = re + 0.06 + 0.01 * c.side
        ra = 0.045 + 0.012 * c.side
        g.torus((0, 0, zh), "y", Ra, ra, capot(c, "olive"), n=64, m=10, what="anneau")
        g.tube_shell((0, 0, zh), "y", Ra + ra * 0.7, Ra - ra * 0.7, ra * 2.6, M["steel_dk"], n=64, what="bague")
        PT.hull(g, -0.45 * re, 0.45 * re, -0.35 * re, 0.35 * re, zb, zh - Ra + ra * 0.5, ins=(0.04, 0.02, 0.02),
                panel=0.22, mats=[capot(c, "olive"), capot(c, "ochre")], faces="tsnew", rivet_step=0.12)
        for sx in (-1, 1):
            g.tube([V((sx * 0.4 * re, 0, zb)), V((sx * Ra * 0.8, 0, zh - Ra * 0.5))], ra * 0.8, M["steel_dk"], n=10,
                   what="jambe")
    elif f == "fourche":
        for sx in (-1, 1):
            pts = [V((sx * 0.3 * re, -0.25 * re, zb)), V((sx * (xc + tc * 0.4), 0.0, zh - 0.3 * re)),
                   V((sx * (xc + tc * 0.4), 0.05 * re, zh))]
            g.tube(Vector_list(pts), tc * 0.55, capot(c, "olive"), n=14, what="bras")
            _tourillon(g, c, sx, cer)
        PT.hull(g, -0.4 * re, 0.4 * re, -0.4 * re, 0.2 * re, zb, zb + 0.12 + 0.02 * c.side, ins=(0.02, 0.02, 0.02),
                panel=0.22, mats=[capot(c, "olive"), M["steel_dk"]], faces="tsnew", rivet_step=0.12)
    else:
        raise ValueError(f)
    if f != "anneau" and getattr(c.ep, "AXE", True):
        # axe des tourillons : traverse l'émetteur d'une joue à l'autre (aucun émetteur ne flotte) ; un âge dont
        # l'émetteur est tenu autrement (AXE = False) le porte lui-même jusqu'à la platine
        g.cyl((0, 0, zh), "x", 0.22 * re, 2 * (xc + tc * 0.5), M["steel_dk"], n=16, what="axe")


def Vector_list(pts):
    return [V(p) for p in pts]


def _tourillon(g, c, sx, cer):
    M = g.M
    t = c.T["tete"]
    re, xc, tc, zh = t["re"], t["xc"], t["tc"], c.zh
    x = sx * (xc + tc + 0.025)
    g.cyl((x, 0, zh), "x", 0.36 * re, 0.05, cer, n=24, style="hard", what="chapeau")
    F.bolts_ring(g, (x + sx * 0.027, 0, zh), (sx, 0, 0), 0.25 * re, 6, M["rivet"], r=0.014)
    g.cyl((x + sx * 0.035, 0, zh), "x", 0.1 * re, 0.03, M["steel_hi"], n=10, what="moyeu")


@_lignee
def arriere_lignee(g, c):
    """Caisson arrière (refroidisseur) : caisson riveté, ailettes sur le dessus, grille sur la face arrière."""
    M = g.M
    t = c.T["tete"]
    zb = t["z0"] + t["hpl"]
    bx, y0, y1, z1 = t["bx"], t["yb0"], t["yb1"], t["zb1"]
    T = PT.hull(g, -bx, bx, y0, y1, zb, z1, ins=(0.03, 0.05, 0.0), panel=0.24,
                mats=[capot(c, "olive"), capot(c, "ochre")], rivet_step=0.11)
    nf = max(4, int((2 * bx - 0.12) / 0.07))
    for i in range(nf):
        x = -bx + 0.09 + (i + 0.5) * (2 * bx - 0.18) / nf
        g.box((x, (T[0].y + T[3].y) / 2, z1 + 0.035), (0.022, abs(T[3].y - T[0].y) * 0.8, 0.07), M["steel"], "hard",
              what="ailette")
    back = [V((-bx, y0, zb)), V((bx, y0, zb)), T[1], T[0]]
    g.grille(PT.lift(PT.face_quad(back, 0.12, 0.88, 0.2, 0.8), 0.01), 4 + c.side // 2, slat_mat=M["steel"])
    return T


def lentille(g, c, y, r, verre=None, cercle=None, anneau=True, point=True, n=40):
    """Face avant de l'émetteur (rôle de la BOUCHE de la mitrailleuse) en (0, y, zh), axe +Y : sertissure boulonnée
    (cercle), verre sombre, anneau lumineux de l'âge (largeur >= 1,5 px hr, F37), point focal. Dessinée hors zone
    habillée : l'âge choisit ses matières."""
    M = g.M
    zh = c.zh
    cm = cercle or M["steel_dk"]
    g.tube_shell((0, y, zh), "y", r + 0.035, r - 0.012, 0.05, cm, n=n, what="sertissure")
    F.bolts_ring(g, (0, y + 0.027, zh), (0, 1, 0), r + 0.012, max(6, int(TAU * r / 0.12)), M["rivet"], r=0.013)
    g.cyl((0, y + 0.004, zh), "y", r - 0.005, 0.03, verre or M["glass_dk"], n=n, style="smooth", what="verre")
    if anneau:
        F.lit_ring(g, (0, y + 0.02, zh), "y", r * 0.8, M["emit"], w=max(0.026, r * 0.14))
    if point:
        g.cyl((0, y + 0.022, zh), "y", max(0.03, r * 0.2), 0.012, M["emit2"], n=16, style="flat", what="foyer")


def emetteur_lignee(g, c):
    """Émetteur du TÉMOIN (âge 0) : boîtier rond à ailettes annulaires, lentille. Longueur 1,6 re pour 1,7 re de
    diamètre (pose N : rien de dressé)."""
    M = g.M
    re, zh = c.re, c.zh
    y0, y1 = -0.6 * re, 1.0 * re
    with habille(g, c):
        g.cyl((0, (y0 + y1) / 2, zh), "y", 0.85 * re, y1 - y0, capot(c, "olive"), n=40, style="soft", what="boitier")
        for k in range(4):
            yy = y0 + 0.15 * re + k * 0.22 * re
            g.tube_shell((0, yy, zh), "y", 0.93 * re, 0.8 * re, 0.05, M["steel_dk"], n=40, what="ailette")
    lentille(g, c, y1, 0.62 * re)


def tete(g, c):
    """Tête de la lignée : platine, support, caisson arrière (ou ep.arriere), émetteur (ep.emetteur), accents
    (ep.tete)."""
    platine(g, c)
    support(g, c)
    if hasattr(c.ep, "arriere"):
        c.ep.arriere(g, c)
    else:
        arriere_lignee(g, c)
    if hasattr(c.ep, "emetteur"):
        c.ep.emetteur(g, c)
    else:
        emetteur_lignee(g, c)
    if hasattr(c.ep, "tete"):
        c.ep.tete(g, c)
