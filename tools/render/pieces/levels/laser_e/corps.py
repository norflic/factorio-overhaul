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

QUATRIÈME JET (correction du lot F1-A, 24/10, défauts M-1, M-4, M-5 et M-6 de la vérification ; le kit est gelé APRÈS) :
  - PROUE (M-1) : nez plat posé sur la platine, vers +Y, avec une fente lumineuse sur son axe : la tête montre où elle
    tire dans toutes les poses, même quand l'émetteur est vu par la tranche (pose E) ; les chapeaux de tourillons sont
    petits, bombés et mats, sans moyeu (ils ne se lisent plus comme une lentille tournée vers la caméra) ;
  - CAISSON ARRIÈRE bas et étroit (M-4, cotes.py) : l'émetteur le dépasse par le haut en pose N ;
  - ANNEAU penché de 35° vers l'avant (son plan n'est plus vu par la tranche en pose E) et fermé par un diaphragme (aucun
    jour enfermé : défaut m-5) ; corps.dans_anneau(g, c) donne le repère penché à l'émetteur de l'âge ;
  - options de forme de l'affût (M-5, M-6) : contour (lobes, étoile, dents), interstice lumineux au pied des gradins,
    pilotis, étoiles semées, rayons au sol (ailerons, contreforts) ; voir epoques.py (« forme_affut »).
Contrôle seulement : la variable d'environnement FO_LASER_SANS=emetteur fait une tête SANS émetteur (mesure de la part
de l'émetteur dans la silhouette, outil du lot F1-A) ; jamais en production.
"""
import math
import os
import random

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
                    lisere=None, rapport=None, contour=None, interstice=None, pilotis=None, etoiles=None, rayons=None)
INCLINAISON_ANNEAU = math.radians(35.0)   # anneau de la forme « anneau » : haut penché vers l'avant (+Y)


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


def contour_pts(prof, R, z, dr=0.0):
    """Sommets d'un gradin de profil `prof` (cotes.profil_contour) au rayon R (tuiles, rond à l'écran), à la hauteur z ;
    dr : retrait constant (cornière, liseré) appliqué après le facteur du contour."""
    return [V(((R * k - dr) * math.cos(a), SQ2 * (R * k - dr) * math.sin(a), z)) for (a, k) in prof]


def couronne(g, o0, i0, o1, i1, m, what="anneau"):
    """Couronne pleine entre deux contours (extérieur o, intérieur i ; bas 0, haut 1) de même nombre de sommets."""
    n = len(o0)
    vs = [tuple(p) for p in o0 + i0 + o1 + i1]
    fs = []
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, 2 * n + j, 2 * n + i))
        fs.append((n + j, n + i, 3 * n + i, 3 * n + j))
        fs.append((2 * n + i, 2 * n + j, 3 * n + j, 3 * n + i))
        fs.append((j, i, n + i, n + j))
    g._add(m, "soft", vs, fs, what)


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
    k = cotes.facteur_contour(c.affut.get("contour"), math.atan2(yn, x))
    z = 0.0
    for (Rb, Rt, z0, z1) in c.gradins:
        if r <= Rt * k:
            z = z1
    return z


# ------------------------------------------------------------------------------------------------
# SOCLE : affût rond à gradins
# ------------------------------------------------------------------------------------------------
@_lignee
def affut(g, c):
    """Gradins de l'affût (forme_affut) : flancs habillés, dessus au motif du pont de l'âge, cornière d'arête, boulons,
    liseré facultatif ; options du quatrième jet : contour (lobes, étoile, dents : le même pour tous les gradins),
    interstice lumineux au pied de chaque gradin (fermé : bande lumineuse en retrait, entretoises), pilotis, étoiles
    semées sur le dessus, rayons au sol (ailerons, contreforts). Remplit c.gradins. Tout est PLEIN jusqu'au sol (aucun
    trou possible)."""
    M = g.M
    A = c.affut
    n = A["gradins"]
    radii = cotes.rayons_gradins(c.side, n, A["rapport"])
    zs = cotes.hauteurs_gradins(c.side, n)
    nseg = int(A["pans"]) if A["pans"] else c.T["affut"]["segments"]
    phase = math.pi / nseg if A["pans"] else 0.0
    cont = A["contour"]
    prof_c = cotes.profil_contour(cont, nseg, phase)
    kmin = min(k for _, k in prof_c)
    bord = c.T["affut"]["bord"]
    flanc = M[A["flanc"]] if A["flanc"] in M else capot(c, "olive")
    flanc2 = M[A["flanc2"]] if A["flanc2"] in M else capot(c, "ochre")
    cfg = c.pont
    Rp = c.T["pivot"]["R"]
    # interstice (lévitation fermée) : bande lumineuse en retrait au pied de chaque gradin
    d_int = (0.03 + 0.008 * c.side) if A["interstice"] else 0.0
    e_int = 0.04 + 0.01 * c.side
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
        if d_int:
            _solide(g, contour_pts(prof_c, R0, z0, e_int), contour_pts(prof_c, R0, z0 + d_int, e_int),
                    M[A["interstice"]], "interstice")
            ne = max(6, int(TAU * R0 / 0.55))
            for k in range(ne):
                a = TAU * (k + 0.5) / ne
                rk = R0 * cotes.facteur_contour(cont, a) - e_int * 0.5
                g.box((rk * math.cos(a), SQ2 * rk * math.sin(a), z0 + d_int / 2), (0.05, 0.05, d_int),
                      M["steel_hi"], "hard", R=Matrix.Rotation(a, 3, "Z"), what="entretoise")
        b = contour_pts(prof_c, R0, z0 + d_int)
        if prof == "bombe":
            zm = (z0 + d_int + z1) / 2
            m_ = contour_pts(prof_c, R0 * 1.03, zm)
            t = contour_pts(prof_c, Rtop, z1)
            _flancs(g, c, b, m_, flanc, flanc2, A)
            _flancs(g, c, m_, t, flanc, flanc2, A)
        else:
            t = contour_pts(prof_c, Rtop, z1)
            _flancs(g, c, b, t, flanc, flanc2, A)
        # dessus : motif du pont de l'âge sur tout le disque du haut (le gradin suivant couvre le centre) ; contour non
        # convexe : le motif se pose sur le disque inscrit, les pointes restent en tôle pleine de la matière du motif
        P2 = [(p.x, p.y) for p in t]
        if cont:
            _prisme(g, P2, z1 - 0.014, z1 - 0.002, M[cfg["mat"]], "flat", "dessus")
            Pin = [(p.x, p.y) for p in anneau_pts(Rtop * kmin - bord, z1, 48)]
            _prisme(g, Pin, z1 - 0.012, z1, M[cfg["fond"]], "flat", "dessus")
            _motif(g, M, cfg, Pin, z1, 0.02, 8100 + 10 * c.side + i)
            couronne(g, contour_pts(prof_c, Rtop, z1, -0.01), contour_pts(prof_c, Rtop, z1, bord),
                     contour_pts(prof_c, Rtop, z1 + 0.026, -0.01), contour_pts(prof_c, Rtop, z1 + 0.026, bord),
                     M[cfg["bord"]], what="corniere")
        else:
            _prisme(g, P2, z1 - 0.012, z1, M[cfg["fond"]], "flat", "dessus")
            _motif(g, M, cfg, P2, z1, bord + 0.02, 8100 + 10 * c.side + i)
            # cornière d'arête (matière « bord » du pont), boulons, liseré ; gradins à PANS : la cornière suit les pans
            # (défaut du premier jet, vu sur les maquettes du quatrième : un anneau à n pans SANS le déphasage π/n du
            # gradin, qui croisait ses arêtes en étoile)
            if A["pans"]:
                couronne(g, contour_pts(prof_c, Rtop, z1, -0.01), contour_pts(prof_c, Rtop, z1, bord),
                         contour_pts(prof_c, Rtop, z1 + 0.026, -0.01), contour_pts(prof_c, Rtop, z1 + 0.026, bord),
                         M[cfg["bord"]], what="corniere")
            else:
                anneau_plat(g, Rtop + 0.01, Rtop - bord, z1, z1 + 0.026, M[cfg["bord"]], n=nseg * 2, what="corniere")
        if cfg.get("boulons"):
            nb = max(8, int(TAU * Rtop / 0.24))
            for k in range(nb):
                a = TAU * (k + 0.5) / nb
                rb = Rtop * _k_bord(A, cont, nseg, phase, a) - bord * 0.5
                g.bolt((rb * math.cos(a), SQ2 * rb * math.sin(a), z1 + 0.026), (0, 0, 1), 0.014, M[cfg["boulons"]])
        if A["lisere"]:
            if cont or A["pans"]:
                couronne(g, contour_pts(prof_c, Rtop, z1 + 0.026, bord * 0.25),
                         contour_pts(prof_c, Rtop, z1 + 0.026, bord * 0.75),
                         contour_pts(prof_c, Rtop, z1 + 0.032, bord * 0.25),
                         contour_pts(prof_c, Rtop, z1 + 0.032, bord * 0.75), M[A["lisere"]], what="lisere")
            else:
                anneau_plat(g, Rtop - bord * 0.25, Rtop - bord * 0.75, z1 + 0.026, z1 + 0.032, M[A["lisere"]],
                            n=nseg * 2 if not A["pans"] else nseg, what="lisere")
        c.gradins.append((R0, Rtop, z0, z1))
    if A["etoiles"]:
        _etoiles(g, c, A["etoiles"], kmin)
    if A["pilotis"]:
        _pilotis(g, c, A["pilotis"])
    if A["rayons"]:
        _rayons(g, c, A["rayons"])
    return c.gradins


def _k_bord(A, cont, nseg, phase, a):
    """Facteur de rayon du bord d'un gradin à l'angle a : contour, polygone à pans (sommets à phase + 2πi/n), ou 1."""
    if cont:
        return cotes.facteur_contour(cont, a)
    if A["pans"]:
        p = TAU / nseg
        u = (a - phase) % p
        return math.cos(p / 2) / math.cos(u - p / 2)
    return 1.0


def _solide(g, b, t, m, what):
    """Tronc plein entre deux contours de même nombre de sommets (fond et dessus fermés)."""
    n = len(b)
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    g._add(m, "flat", [tuple(p) for p in b + t], faces, what)


def _mat_opt(g, c, v, defaut):
    """Matière d'une option de l'affût : chaîne (nom de matière) ou dict(mat=…) ; défaut sinon."""
    nom = v if isinstance(v, str) else (v.get("mat") if isinstance(v, dict) else None)
    return g.M[nom] if nom in g.M else capot(c, defaut)


def _etoiles(g, c, v, kmin):
    """Étoiles semées sur le dessus des gradins (petits points lumineux, hasard LOCAL : graine fixe par taille et
    gradin) ; densité par tuile² de dessus visible (défaut 5)."""
    m = _mat_opt(g, c, v, "olive")
    dens = float(v.get("densite", 5.0)) if isinstance(v, dict) else 5.0
    bord = c.T["affut"]["bord"]
    Rp = c.T["pivot"]["R"]
    for i, (R0, Rtop, z0, z1) in enumerate(c.gradins):
        Ri = (c.gradins[i + 1][0] if i + 1 < len(c.gradins) else Rp) + 0.06
        Ro = Rtop * kmin - bord - 0.04
        if Ro <= Ri:
            continue
        rng = random.Random(8400 + 10 * c.side + i)
        for _ in range(int(dens * math.pi * (Ro * Ro - Ri * Ri))):
            r = math.sqrt(rng.uniform(Ri * Ri, Ro * Ro))
            a = rng.uniform(0.0, TAU)
            rs = rng.choice((0.013, 0.016, 0.02, 0.026))
            g.cyl((r * math.cos(a), SQ2 * r * math.sin(a), z1 + 0.034), "z", rs, 0.014, m, n=8, style="flat",
                  what="etoile")


def _hors_coins(c, x, yn, marge):
    """Vrai si le point (x, yn) (tuiles) est dans l'emprise et hors des quatre places de coin (superstructures et
    pièce paire), avec une marge."""
    s = c.side
    if abs(x) > s / 2.0 - 0.05 - marge or abs(yn) > s / 2.0 - 0.05 - marge:
        return False
    T = c.T["coin"]
    for sx in (-1, 1):
        for sy in (-1, 1):
            if math.hypot(x - sx * T["d"], yn - sy * T["d"]) < T["r"] + marge:
                return False
    return True


def _pilotis(g, c, v):
    """Pilotis : pieux debout serrés au pied du premier gradin (à moitié pris dedans), un peu plus hauts que lui, hors
    des places de coin."""
    m = _mat_opt(g, c, v, "olive")
    R0, Rtop, z0, z1 = c.gradins[0]
    cont = c.affut["contour"]
    rp = 0.035 + 0.008 * c.side
    h = z1 * 1.18
    n = int(v.get("n") or 0) if isinstance(v, dict) else 0
    n = n or max(12, int(TAU * R0 / 0.3))
    for k in range(n):
        a = math.pi / n + TAU * k / n
        r = R0 * cotes.facteur_contour(cont, a) + rp * 0.35
        x, yn = r * math.cos(a), r * math.sin(a)
        if not _hors_coins(c, x, yn, rp):
            continue
        g.cyl((x, SQ2 * yn, h / 2), "z", rp, h, m, n=10, style="soft", what="pieu")
        g.cyl((x, SQ2 * yn, h + 0.012), "z", rp * 1.08, 0.024, M_ou(g, "steel_dk"), n=10, style="soft", what="tete_pieu")


def M_ou(g, nom):
    return g.M[nom] if nom in g.M else g.M["steel_dk"]


def _rayons(g, c, v):
    """Rayons de l'affût : « aileron » (lame mince en triangle qui monte vers le centre et dépasse le dessus de l'affût :
    elle change la SILHOUETTE) ou « contrefort » (coin plein, plus large, et patin au sol) ; n à partir de `phase`
    (degrés, 0 = est, défaut : entre deux condensateurs pour n = 4 ou 8). Chaque rayon part du pied du DEUXIÈME gradin,
    passe par-dessus le premier et dépasse son flanc d'au plus 0,06 + 0,02 s, rogné pour rester dans l'emprise et hors
    des places de coin. Correction du premier dessin (rayons au sol seulement, hors de l'affût) : entre l'affût et le
    bord de l'emprise il ne reste que 0,03 s + 0,04 tuile ; à 3×3, les contreforts de la maquette 4 étaient trop courts
    et n'étaient pas posés (maquettes du 24/10)."""
    m = _mat_opt(g, c, v, "ochre")
    forme = v.get("forme", "aileron")
    n = int(v.get("n", 4))
    ph = math.radians(v.get("phase", 0.0))
    A = c.affut
    cont = A["contour"]
    nseg = int(A["pans"] or 0)
    phase = math.pi / nseg if nseg else 0.0
    R0, Rtop, z0, z1 = c.gradins[0]
    s = c.side
    Rp = c.T["pivot"]["R"]
    R2 = c.gradins[1][0] if len(c.gradins) > 1 else Rp + 0.1
    ztop = c.gradins[-1][3]
    z2 = c.gradins[1][3] if len(c.gradins) > 1 else z1
    hw = (0.02 + 0.005 * s) if forme == "aileron" else (0.06 + 0.014 * s)
    for k in range(n):
        a = ph + TAU * k / n
        kb = _k_bord(A, cont, nseg, phase, a)
        r_in = R2 * kb - 0.03
        r_bord = R0 * kb
        r1 = r_bord - 0.02
        r = r_bord
        while r <= r_bord + 0.06 + 0.02 * s:
            if not _hors_coins(c, r * math.cos(a), r * math.sin(a), hw):
                break
            r1 = r
            r += 0.02
        d = V((math.cos(a), math.sin(a), 0.0))
        p = V((-math.sin(a), math.cos(a), 0.0))

        def B(rr, w, z):
            q = d * rr + p * w
            return V((q.x, SQ2 * q.y, z))
        if forme == "aileron":
            h_in = ztop + 0.1 + 0.04 * s
            pts = [B(r_in, -hw, 0.0), B(r1, -hw, 0.0), B(r1, -hw, 0.06), B(r_in, -hw, h_in),
                   B(r_in, hw, 0.0), B(r1, hw, 0.0), B(r1, hw, 0.06), B(r_in, hw, h_in)]
            g.hexa(pts, m, "hard", "aileron")
            # liseré d'arête (matière d'acier sombre) le long du bord d'attaque
            e0, e1 = B(r_in, 0.0, h_in), B(r1, 0.0, 0.06)
            dd = e1 - e0
            g.box((e0 + e1) / 2, (hw * 2.4, dd.length, 0.03), M_ou(g, "steel_dk"), "hard",
                  R=Matrix.Rotation(math.atan2(-dd.x, dd.y), 3, "Z") @ Matrix.Rotation(
                      math.atan2(dd.z, math.hypot(dd.x, dd.y)), 3, "X"), what="arete_aileron")
        else:
            h_in = z2 * 0.98
            pts = [B(r_in, -hw, 0.0), B(r1, -hw, 0.0), B(r1, hw, 0.0), B(r_in, hw, 0.0),
                   B(r_in, -hw * 0.8, h_in), B(r1, -hw * 0.8, 0.08), B(r1, hw * 0.8, 0.08), B(r_in, hw * 0.8, h_in)]
            g.hexa(pts, m, "hard", "contrefort")
            g.cyl(tuple(B(r1 - 0.01, 0.0, 0.03)), "z", hw * 1.3, 0.06, M_ou(g, "steel_dk"), n=16, style="soft",
                  what="patin_contrefort")


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
    cont = c.affut.get("contour")
    out = []
    for k in range(n):
        a = math.pi / n + TAU * k / n
        # contour (quatrième jet) : la couronne suit les lobes, les pointes et les PANS (au premier jet, un condensateur
        # au milieu d'un pan débordait du gradin)
        A = c.affut
        kf = _k_bord(A, cont, int(A["pans"] or 0), math.pi / A["pans"] if A["pans"] else 0.0, a)
        if (Rtop - R2) * kf >= 2 * r + 0.02:
            Rm, z = (Rtop + R2) / 2.0 * kf, z1 + 0.026
        else:
            Rm, z = R0 * kf - 0.35 * r, 0.0      # adossés au flanc du premier gradin, posés au sol
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
    sur la moitié AVANT seulement (les autres sont derrière la tête). Correction F1-A (24/10, reprise) : le code posait
    aussi les liaisons de la moitié ARRIÈRE, contrairement à ce qu'il annonçait ; vues de la caméra (au sud), elles
    montaient au-dessus de leur condensateur et y enfermaient un jour sur le fond (trous de 10 à 55 px aux maquettes
    m05, m06 et m09) : seules les liaisons des condensateurs au sud de l'axe est-ouest (y < 0) sont posées."""
    if not pl:
        return
    liaison = getattr(c.ep, "liaison", None) or liaison_defaut
    P = c.T["pivot"]
    zp = c.gradins[-1][3]
    r = r or (0.022 + 0.006 * c.side)
    for k, (x, y, z, rc, h) in enumerate(pl):
        if k % pas or y > 0.0:
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
def proue(g, c):
    """PROUE (quatrième jet, M-1) : repère de direction de la lignée, lisible de dessus dans toutes les poses sans
    allonger l'émetteur (F119) : nez plat en pointe posé sur la platine, du centre vers +Y jusqu'à py1 (cotes.py),
    tôle bordée d'une cornière, FENTE LUMINEUSE de l'âge sur son axe et chevron lumineux près de la pointe. Bas : son
    dessus est à peine plus haut que la platine. Un âge peut la remplacer (def proue(g, c)), jamais la supprimer."""
    M = g.M
    t = c.T["tete"]
    z0, zb = t["z0"], t["z0"] + t["hpl"]
    y0, ye, y1 = t["py0"], t["py_ep"], t["py1"]
    w0, we = t["pw0"], t["pw_ep"]
    zt = zb + 0.02
    P = [(-w0, y0), (w0, y0), (we, ye), (0.0, y1), (-we, ye)]
    _prisme(g, P, z0 + 0.01, zt, capot(c, "olive"), "hard", "proue")
    # cornière du bord (acier sombre) sur les deux côtés en biais
    for (xa, ya), (xb, yb) in (((we, ye), (0.0, y1)), ((0.0, y1), (-we, ye)), ((w0, y0), (we, ye)),
                               ((-we, ye), (-w0, y0))):
        a, b = V((xa, ya, zt + 0.008)), V((xb, yb, zt + 0.008))
        d = b - a
        g.box((a + b) / 2, (0.03, d.length, 0.018), M["steel_dk"], "hard",
              R=Matrix.Rotation(math.atan2(-d.x, d.y), 3, "Z"), what="corniere_proue")
    # fente lumineuse sur l'axe, puis chevron près de la pointe
    fw = t["fente"]
    yf0, yf1 = y0 + 0.1 * (ye - y0), ye + 0.25 * (y1 - ye)
    g.box((0, (yf0 + yf1) / 2, zt + 0.004), (fw, yf1 - yf0, 0.012), M["emit"], "flat", what="fente_proue")
    for sx in (-1, 1):
        a = V((0.0, y1 - 0.1 * (y1 - ye), zt + 0.006))
        b = V((sx * we * 0.55, ye + 0.05 * (y1 - ye), zt + 0.006))
        d = b - a
        g.box((a + b) / 2, (fw * 0.8, d.length, 0.012), M["emit"], "flat",
              R=Matrix.Rotation(math.atan2(-d.x, d.y), 3, "Z"), what="chevron_proue")


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
            _tourillon(g, c, sx, cer, fleche=ry)
        if f == "berceau":
            PT.hull(g, -xc - tc, xc + tc, -0.62 * re, 0.62 * re, zb, zh - 0.72 * re, ins=(0.02, 0.03, 0.03),
                    panel=0.24, mats=[capot(c, "olive"), M["steel_dk"]], faces="tsnew", rivet_step=0.12)
        # PALIERS (quatrième jet) : un bloc plein sous l'axe, de chaque côté, entre l'émetteur et la joue ; le caisson
        # arrière bas ne bouche plus, en pose N, le jour entre la joue et l'émetteur sous l'axe (trous enfermés de 45 à
        # 586 px aux témoins k2 à k6, rendu r0c du 24/10)
        for sx in (-1, 1):
            xa, xb = sorted((sx * 0.5 * re, sx * (xc + 0.01)))
            PT.hull(g, xa, xb, -0.55 * re, 0.45 * re, zb, zh, ins=(0.0, 0.02, 0.02), panel=0.22,
                    mats=[capot(c, "olive"), M["steel_dk"]], faces="tsnew", rivet_step=0.12)
    elif f == "anneau":
        # anneau PENCHÉ de INCLINAISON_ANNEAU vers l'avant (quatrième jet, M-4 : vu par la tranche en pose E sinon),
        # fermé par un DIAPHRAGME (aucun jour enfermé au centre, m-5) ; l'émetteur de l'âge se dessine dans le même
        # repère (corps.dans_anneau)
        Ra, ra = rayons_anneau(c)
        Rx = Matrix.Rotation(-INCLINAISON_ANNEAU, 3, "X")

        def P(x, y, z):
            return Rx @ V((x, y, z)) + V((0, 0, zh))
        with dans_anneau(g, c):
            g.torus((0, 0, 0), "y", Ra, ra, capot(c, "olive"), n=64, m=10, what="anneau")
            g.tube_shell((0, 0, 0), "y", Ra + ra * 0.7, Ra - ra * 0.7, ra * 2.6, M["steel_dk"], n=64, what="bague")
            # diaphragme en TAMBOUR plein (reprise de la correction F1-A, 24/10) : le disque mince de 0,035 placé à
            # −0,3 re laissait en pose E un jour enfermé de 18 px entre le haut de l'anneau penché et l'émetteur
            # (m14-tete-E) ; le tambour remplit l'anneau de son plan jusqu'à −0,3 re
            g.cyl((0, -0.15 * re, 0), "y", Ra - ra * 0.3, 0.3 * re + 0.035, M["steel_dk"], n=64, style="soft",
                  what="diaphragme")
        yb = P(0, 0, -Ra).y
        PT.hull(g, -0.45 * re, 0.45 * re, yb - 0.35 * re, yb + 0.35 * re, zb, P(0, 0, -Ra).z + ra * 0.5,
                ins=(0.04, 0.02, 0.02), panel=0.22, mats=[capot(c, "olive"), capot(c, "ochre")], faces="tsnew",
                rivet_step=0.12)
        for sx in (-1, 1):
            g.tube([V((sx * 0.4 * re, yb, zb)), P(sx * Ra * 0.8, 0, -Ra * 0.5)], ra * 0.8, M["steel_dk"], n=10,
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


def rayons_anneau(c):
    """(Ra, ra) : rayon de l'anneau de la forme « anneau » et rayon de son tube."""
    return c.re + 0.06 + 0.01 * c.side, 0.045 + 0.012 * c.side


class dans_anneau:
    """Repère de l'anneau penché (forme « anneau ») : origine au centre de l'émetteur (0, 0, zh), axe y = axe de
    l'anneau, penché de INCLINAISON_ANNEAU (le haut vers l'avant). Pour l'émetteur d'un âge qui remplit l'anneau."""

    def __init__(self, g, c):
        self.g, self.c = g, c

    def __enter__(self):
        self.g.push((0, 0, self.c.zh), rx=-INCLINAISON_ANNEAU)
        return self.g

    def __exit__(self, *a):
        self.g.pop()


def _tourillon(g, c, sx, cer, fleche=None):
    """Tourillon (quatrième jet, M-1 et m-2) : chapeau PETIT, bombé et mat (capot de l'âge), quatre rivets, sans moyeu :
    il ne se lit plus comme une lentille tournée vers la caméra ; sur une joue (fleche = demi-hauteur de la joue), une
    NERVURE EN FLÈCHE horizontale pointe vers l'avant (+Y) : en pose E, la joue vue de face montre où tire la tête."""
    M = g.M
    t = c.T["tete"]
    re, xc, tc, zh = t["re"], t["xc"], t["tc"], c.zh
    x = sx * (xc + tc + 0.02)
    g.cyl((x, 0, zh), (sx, 0, 0), 0.2 * re, 0.05, capot(c, "olive"), r2=0.12 * re, n=20, style="soft",
          what="chapeau")
    F.bolts_ring(g, (x - sx * 0.01, 0, zh), (sx, 0, 0), 0.165 * re, 4, M["rivet"], r=0.012)
    if fleche:
        ry = fleche
        xf = sx * (xc + tc + 0.012)
        y0, y1, yp = -0.7 * ry, 0.62 * ry, ry + 0.08
        hz = 0.04 + 0.006 * c.side
        g.box((xf, (y0 + y1) / 2, zh), (0.026, y1 - y0, hz), cer, "hard", what="nervure")
        # pointe de flèche (triangle plein), dans le plan de la joue, qui dépasse un peu la joue vers l'avant
        w = hz * 2.6
        q = [V((xf - 0.013, y1, zh - w)), V((xf - 0.013, yp, zh)), V((xf - 0.013, yp, zh)), V((xf - 0.013, y1, zh + w))]
        g.hexa(q + [p + V((0.026, 0, 0)) for p in q], cer, "hard", "pointe")


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
    """Tête de la lignée : platine, proue (ou ep.proue), support, caisson arrière (ou ep.arriere), émetteur
    (ep.emetteur), accents (ep.tete). FO_LASER_SANS=emetteur (contrôle seulement) : tête sans émetteur."""
    platine(g, c)
    if hasattr(c.ep, "proue"):
        c.ep.proue(g, c)
    else:
        proue(g, c)
    support(g, c)
    if hasattr(c.ep, "arriere"):
        c.ep.arriere(g, c)
    else:
        arriere_lignee(g, c)
    if "emetteur" in os.environ.get("FO_LASER_SANS", ""):
        pass
    elif hasattr(c.ep, "emetteur"):
        c.ep.emetteur(g, c)
    else:
        emetteur_lignee(g, c)
    if hasattr(c.ep, "tete"):
        c.ep.tete(g, c)
