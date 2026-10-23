"""CORPS DE LIGNÉE COMMUN de la mitrailleuse (lot V3-E, quatrième passe, 23/10), aux 5 tailles de l'emprise (2×2 à
6×6, shared/levels/config.lua L.footprints.gun). S'exécute DANS Blender. FICHIER GELÉ pour les constructeurs.

Corps retenu : celui de la PREMIÈRE PASSE (V3-S industriel, commit 265574d), que le Directeur Créatif a trouvé
« parfait », « très précis » ; c'est aussi celui que la plage haute de la passe 3 avait gardé (plateforme de
caillebotis sombre continue, coupole olive, masque ocre, nacelle olive et ocre, colonne olive et brun-rouge). Les
tailles 2×2 à 4×4 reprennent les cotes de la plage basse (seules à exister), le reste de la grammaire est celui de
la lignée : la rupture entre les époques 9 et 10 (dalles claires en croix contre plateforme sombre, coupole et colonne
recolorées par époque, reflets propres à l'ère I) disparaît.

Ce que le corps dessine (identique aux 15 époques, à la taille près) :
  socle  : plateforme de caillebotis (tablier bas continu : aucun trou enfermé), colonne à goussets et couronne
           dentée à bandes de danger, trémie à trappe ouverte et goulotte vers la couronne ;
  tête   : collier riveté, jupe blindée à bandes, coupole rivetée à nervures, masque avant (par défaut), nacelle
           arrière (coque, face arrière), tourelleau à périscopes, trappe, 2 bras de tourillon avec berceaux ;
  canon  : la ROSETTE (faisceau de tubes séparés à âme pleine, plaque de culasse, colliers de maintien, POINTES
           ÉCLAIRÉES ; tubes en acier nu clair) et la BOUCHE (rosace sombre cerclée, pourtour éclairé) sont fournies par
           rosette() et bouche() ; couronne_bouche() ferme le faisceau sans chapeau plus large que lui ; canon_lignee()
           est le canon de lignée complet corrigé pour la pose N (règle d'or 7, passe 5 : plus de frein en bloc) : c'est
           la base sur laquelle une époque AJOUTE son organe (règle d'or 1).
  habillage (passe 5) : MATIÈRE de TOUT le corps de lignée (capots, acier, rivets, joints, bandes de danger, peinture)
           et MATIÈRE ET MOTIF du pont (plateforme : caillebotis, planches, dalles, tôles ; liseré lumineux) par les
           clés d'habillage de l'époque (contrat dans epoques.py) : mats_habilles() fait la palette habillée c.Mh,
           habille() et @_lignee la posent sur g.M le temps des pièces de la lignée ; la géométrie ne change pas (sauf
           le motif du pont) ; toutes les clés à None : empreinte de construction identique (construction.py).
  accroches (passe 5) : accroche(c, nom) rend la place libre des points d'accroche des SUPERSTRUCTURES d'époque
           (coins du pont, côtés de la trémie, sommet de la coupole, couronne de la jupe ; accroches.py).
Variante de corps A (passe 4) ou B (valeurs groupées) : corps_choix.py, matières seulement (kit.corps_b).
Ce que l'époque dessine (epNN.py, emplacements du catalogue §A.2, contrat dans epoques.py) : arme, tuyaux et grands
volumes annexes, accents, foyers, pièce du niveau pair.
"""
import math

from mathutils import Matrix, Vector

import formes as F
import parts as PT
import parts2 as P2
import parts3 as P3
from kit import SQ2, TAU

V = Vector

# longueur maximale d'une jaquette, carénage ou manchon d'époque posé SUR le faisceau, en part de la longueur des tubes
# (règle d'or 1) : au-delà, le faisceau et sa bouche ne se lisent plus
JAQUETTE_MAX = 0.5


def Y(yn):
    """y de jeu en tuiles, vers le NORD -> Y Blender."""
    return yn * SQ2


class at:
    """Repère local posé en (x, y de jeu vers le nord, z), tourné de rz : `with at(g, x, yn, rz): ...`."""

    def __init__(self, g, x, yn, rz=0.0, z=0.0):
        self.g, self.a = g, ((x, Y(yn), z), rz)

    def __enter__(self):
        self.g.push(self.a[0], rz=self.a[1])
        return self.g

    def __exit__(self, *exc):
        self.g.pop()


# ------------------------------------------------------------------------------------------------
# Cotes de la lignée par taille d'emprise (côté en tuiles)
# ------------------------------------------------------------------------------------------------
# Cotes par taille (colonne, tête, trémie, plateforme, pièce, nacelle, tourelleau…) : cotes.py (Python pur, passe 5)
from cotes import TAILLES  # noqa: E402


# ------------------------------------------------------------------------------------------------
# Contexte d'un rendu (passé à toutes les fonctions d'époque)
# ------------------------------------------------------------------------------------------------
class Ctx:
    """g : accumulateur ; M : matières ; e : époque ; ep : module de l'époque ; side : côté ; B : colonne ; H : tête
    (cotes de la taille + paramètres de canon de l'époque : L, nb, rb, rr) ; T : toutes les cotes de la taille ;
    rt : haut de la couronne dentée ; hab : habillage de l'époque (epoques.HABILLAGE_DEFAUT complété).
    Remplis par tete() avant l'appel de ep.tete : Pf, Nf (paramétrage de la coupole), nac (bx, yb0, yb1, ztop, yc),
    tour (cx, cy, z du dessus du tourelleau). Mh : matières HABILLÉES de la lignée (clés d'habillage de matière,
    mats_habilles) ; c.M reste la palette d'origine."""

    def __init__(self, g, e, ep, side, hab):
        self.g, self.M, self.e, self.ep, self.side = g, g.M, e, ep, side
        self.T = TAILLES[side]
        self.B = dict(self.T["colonne"])
        self.H = dict(self.T["tete"])
        self.H.update(getattr(ep, "CANON", None) or getattr(ep, "CANON_PAR_COTE", {}).get(side, {}))
        self.rt = self.B["h"] + self.B["rh"]
        self.hab = hab
        self.Pf = self.Nf = self.nac = self.tour = None
        self.Mh = mats_habilles(g.M, hab)
        self.pont = pont_cfg(hab)
        # dalle() (appelée par ep.piece sans contexte) retrouve l'habillage par g.ctx
        g.ctx = self


# ------------------------------------------------------------------------------------------------
# HABILLAGE DE MATIÈRE de la lignée (passe 5, consigne du 23/10 : chaque âge change TOUT le bâtiment)
# ------------------------------------------------------------------------------------------------
# clé d'habillage -> matières de la LIGNÉE qu'elle remplace (contrat complet en tête de epoques.py). Une valeur simple
# remplace tout le groupe ; un couple remplace (premier, second) groupe.
REMPLACE = {
    "capots": (("olive",), ("ochre",)),                       # grands capots ; défaut du second : le premier
    "acier": (("steel_dk", "armor2", "armor"), ("steel", "steel_hi")),   # défaut du second : inchangé
    "rivets": (("rivet",),),
    "joints": (("seam",),),
    "danger": (("hazy",), ("hazk",)),                          # défaut du second : le premier
    "peinture": (("redpaint",),),
}
_SECOND_SUIT = ("capots", "danger")


def mats_habilles(M, hab):
    """Palette HABILLÉE de la lignée : une copie de M où les matières des groupes de REMPLACE sont remplacées par
    celles que l'époque donne (clés d'habillage). Aucune clé donnée : rend M lui-même (aucun changement possible).
    Les cibles se lisent dans M (palette d'origine) : jamais de remplacement en chaîne."""
    rep = {}
    for cle, groupes in REMPLACE.items():
        v = hab.get(cle)
        if not v:
            continue
        vals = (v,) if isinstance(v, str) else tuple(v)
        if len(vals) > len(groupes):
            raise ValueError("habillage %s : %d valeurs pour %d groupe(s)" % (cle, len(vals), len(groupes)))
        for i, grp in enumerate(groupes):
            if i < len(vals):
                cible = vals[i]
            elif cle in _SECOND_SUIT:
                cible = vals[0]
            else:
                continue
            if cible is None:
                continue
            for src in grp:
                rep[src] = cible
    if not rep:
        return M
    manque = sorted({t for t in rep.values() if t not in M})
    if manque:
        raise KeyError("habillage : matière(s) inconnue(s) %s (kit.materials ou ep.matieres)" % ", ".join(manque))
    Mh = dict(M)
    for src, cible in rep.items():
        Mh[src] = M[cible]
    return Mh


class habille:
    """Zone de la LIGNÉE : `with habille(g, c): …` met g.M sur la palette habillée (c.Mh) le temps de dessiner une
    pièce de la lignée (plateforme, dalle, colonne, trémie, collier, jupe, coupole, masque, nacelle, échappements,
    tourelleau, bras). Le canon (canon_lignee, rosette, bouche, moteur) et tout ce que l'époque dessine restent hors
    zone (palette d'origine) ; une époque qui veut la matière habillée la lit avec mat(c, clé). Réentrant."""

    def __init__(self, g, c=None):
        c = c if c is not None else getattr(g, "ctx", None)
        self.g, self.Mh = g, (c.Mh if c is not None else None)

    def __enter__(self):
        self.old = self.g.M
        if self.Mh is not None:
            self.g.M = self.Mh
        return self.g.M

    def __exit__(self, *exc):
        self.g.M = self.old


def _lignee(f):
    """Décorateur : la fonction de lignée f(g, c, …) dessine dans la zone habillée."""
    def w(g, c, *a, **k):
        with habille(g, c):
            return f(g, c, *a, **k)
    w.__name__, w.__doc__ = f.__name__, f.__doc__
    return w


def mat(c, cle):
    """Matière HABILLÉE de la lignée pour la clé `cle` (« steel_dk », « rivet », « olive »…) : pour une époque qui
    veut poser ses organes dans la matière de son corps."""
    return c.Mh[cle]


def capot(c, cle):
    """Matière d'un GRAND CAPOT du corps de lignée. cle : « olive » (capots principaux : coupole, bandes olive de la
    jupe, fût de la colonne, coque de la nacelle, bras de tourillon, masque) ou « ochre » (capots secondaires : plaques
    ocre de la nacelle et du masque). Habillage « capots » de l'époque (epoques.HABILLAGE_DEFAUT) : None = olive et
    ocre de la lignée ; « clé » = cette matière pour les deux ; (clé1, clé2) = clé1 pour l'olive, clé2 pour l'ocre.
    Seule la MATIÈRE change : géométrie, nombre de plaques et de rivets identiques."""
    return c.Mh[cle]


def capots_mats(c, keys):
    """Liste de matières HABILLÉES pour des noms de clés (« olive » et « ochre » suivent la clé capots)."""
    return [c.Mh[k] for k in keys]


# ------------------------------------------------------------------------------------------------
# PONT : matière ET motif de la plateforme (clé d'habillage « plateforme », passe 5)
# ------------------------------------------------------------------------------------------------
MOTIFS = ("caillebotis", "planches", "dalles", "toles")
PONT_DEFAUT = dict(motif="caillebotis", mat="grate", mat2=None, fond="tablier", bord="steel_dk", boulons="steel_hi",
                   lisere=None, pas=None, joint=None, relief=0.0)
# pas (tuiles de jeu) et joint (unités Blender) par défaut de chaque motif ; précision (règle d'or 4) : planches de
# 0,16 t, dalles de 0,28 t (tôles 0,22 à 0,30), tôles rivetées de 0,5 t (rivets de 0,016)
PAS_DEFAUT = {"planches": 0.16, "dalles": 0.28, "toles": 0.5}
JOINT_DEFAUT = {"planches": 0.014, "dalles": 0.016, "toles": 0.02}


def pont_cfg(hab):
    """Réglage du pont depuis la clé « plateforme » (None : caillebotis de la lignée, code d'origine)."""
    v = hab.get("plateforme")
    if not v:
        return None
    if isinstance(v, str):
        v = dict(motif=v)
    inconnues = sorted(set(v) - set(PONT_DEFAUT))
    if inconnues:
        raise KeyError("habillage plateforme : clé(s) inconnue(s) %s (permises : %s)"
                       % (", ".join(inconnues), ", ".join(sorted(PONT_DEFAUT))))
    cfg = dict(PONT_DEFAUT)
    cfg.update(v)
    if cfg["motif"] not in MOTIFS:
        raise ValueError("habillage plateforme : motif %r inconnu (%s)" % (cfg["motif"], ", ".join(MOTIFS)))
    return cfg


def _demi_plan(pts, a, b, d):
    """Garde la partie de pts à GAUCHE de a->b (intérieur d'un polygone direct), rentrée de d."""
    ex, ey = b[0] - a[0], b[1] - a[1]
    L = math.hypot(ex, ey)
    if L < 1e-9:
        return pts
    nx, ny = -ey / L, ex / L

    def s(p):
        return (p[0] - a[0]) * nx + (p[1] - a[1]) * ny - d
    out = []
    for i in range(len(pts)):
        p, q = pts[i], pts[(i + 1) % len(pts)]
        sp, sq = s(p), s(q)
        if sp >= 0:
            out.append(p)
        if (sp >= 0) != (sq >= 0):
            t = sp / (sp - sq)
            out.append((p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])))
    return out


def _decoupe(pts, poly, d=0.0):
    """Polygone convexe pts découpé par le polygone convexe direct poly rentré de d."""
    for i in range(len(poly)):
        pts = _demi_plan(pts, poly[i], poly[(i + 1) % len(poly)], d)
        if len(pts) < 3:
            return []
    return pts


def _aire(pts):
    return 0.5 * sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1]
                     for i in range(len(pts)))


def _dedans(p, poly, d=0.0):
    return all((p[0] - poly[i][0]) * -(poly[(i + 1) % len(poly)][1] - poly[i][1])
               + (p[1] - poly[i][1]) * (poly[(i + 1) % len(poly)][0] - poly[i][0])
               >= d * math.hypot(poly[(i + 1) % len(poly)][0] - poly[i][0], poly[(i + 1) % len(poly)][1] - poly[i][1])
               for i in range(len(poly)))


def _prisme(g, pts, z0, z1, m, style, what):
    n = len(pts)
    vs = [(x, y, z0) for x, y in pts] + [(x, y, z1) for x, y in pts]
    fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, n + j, n + i))
    g._add(m, style, vs, fs, what)


def _motif(g, M, cfg, P, zb, ins, graine):
    """Motif du pont sur le polygone convexe direct P (Blender), rentré de ins sous les cornières ; zb : dessus du
    tablier. Hasard LOCAL (graine) : le tirage du reste du bâtiment ne change pas."""
    import random
    rng = random.Random(graine)
    mats = [M[cfg["mat"]]] + ([M[cfg["mat2"]]] if cfg["mat2"] else [])
    motif = cfg["motif"]
    xs = [p[0] for p in P]
    ys = [p[1] for p in P]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    if motif == "caillebotis":
        hx = (x1 - x0) / 2.0
        xc = (x0 + x1) / 2.0
        nb = int((2 * hx - 0.1) / 0.09)
        for i in range(nb):
            x = xc - hx + 0.05 + (i + 0.5) * (2 * hx - 0.1) / nb
            band = _decoupe([(x - 0.015, y0 - 1), (x + 0.015, y0 - 1), (x + 0.015, y1 + 1), (x - 0.015, y1 + 1)], P, ins)
            if band:
                _prisme(g, band, zb, zb + 0.024, mats[i % len(mats)], "flat", "lame")
        return
    pas = cfg["pas"] or PAS_DEFAUT[motif]
    jt = cfg["joint"] if cfg["joint"] is not None else JOINT_DEFAUT[motif]
    ep_ = 0.022
    if motif == "planches":
        wy = pas * SQ2
        nrow = int(math.ceil((y1 - y0) / wy)) + 1
        for j in range(nrow):
            ya = y0 + j * wy
            yb = ya + wy
            xa = x0 - rng.random() * 0.5
            while xa < x1:
                L = 0.5 + 0.5 * rng.random()
                xb = xa + L
                q = _decoupe([(xa + jt / 2, ya + jt / 2), (xb - jt / 2, ya + jt / 2), (xb - jt / 2, yb - jt / 2),
                              (xa + jt / 2, yb - jt / 2)], P, ins)
                if q and _aire(q) > 0.004:
                    th = ep_ * (1.0 + cfg["relief"] * (rng.random() - 0.5))
                    _prisme(g, q, zb, zb + th, mats[rng.randrange(len(mats))], "hard", "planche")
                    if cfg["boulons"]:
                        for xx in (xa + 0.045, xb - 0.045):
                            for f in (0.3, 0.7):
                                p = (xx, ya + wy * f)
                                if _dedans(p, q, 0.012):
                                    g.dome((p[0], p[1], zb + th), (0, 0, 1), 0.014, M[cfg["boulons"]], what="clou")
                xa = xb
        return
    # dalles et tôles : grille alignée sur le centre (symétrique), cases de pas × pas tuiles de jeu
    px, py = pas, pas * SQ2
    i0, i1 = int(math.floor(x0 / px)) - 1, int(math.ceil(x1 / px)) + 1
    j0, j1 = int(math.floor(y0 / py)) - 1, int(math.ceil(y1 / py)) + 1
    for i in range(i0, i1):
        for j in range(j0, j1):
            xa, xb = i * px + jt / 2, (i + 1) * px - jt / 2
            ya, yb = j * py + jt / 2, (j + 1) * py - jt / 2
            q = _decoupe([(xa, ya), (xb, ya), (xb, yb), (xa, yb)], P, ins)
            if not q or _aire(q) < 0.004:
                continue
            th = ep_ * (1.0 + cfg["relief"] * (rng.random() - 0.5))
            m = mats[rng.randrange(len(mats))] if len(mats) > 1 else mats[0]
            _prisme(g, q, zb, zb + th, m, "hard", "dalle_pont" if motif == "dalles" else "tole_pont")
            if motif == "toles" and cfg["boulons"]:
                for p in ((xa + 0.035, ya + 0.035), (xb - 0.035, ya + 0.035), (xb - 0.035, yb - 0.035),
                          (xa + 0.035, yb - 0.035), ((xa + xb) / 2, ya + 0.035), ((xa + xb) / 2, yb - 0.035)):
                    if _dedans(p, q, 0.012):
                        g.dome((p[0], p[1], zb + th), (0, 0, 1), 0.016, M[cfg["boulons"]], what="rivet_pont")


def _lisere(g, M, cfg, p0, p1, nrm, z):
    """Liseré lumineux (clé plateforme.lisere) sur le dessus de la cornière, côté intérieur."""
    d = p1 - p0
    L = d.length
    d = d.normalized()
    R = Matrix((d, V((-d.y, d.x, 0)), V((0, 0, 1)))).transposed()
    g.box((p0 + p1) / 2 - nrm * 0.07 + V((0, 0, z + 0.003)), (L * 0.96, 0.012, 0.006), M[cfg["lisere"]], "flat", R=R,
          what="lisere")


# ------------------------------------------------------------------------------------------------
# Socle
# ------------------------------------------------------------------------------------------------
@_lignee
def plateforme(g, c, chanfrein=None, z=0.045):
    """Tablier bas continu de caillebotis (4,5 cm) qui relie TOUS les volumes du socle : aucun jour entre les machines,
    aucune pièce isolée. Octogone chanfreiné (avant : chanfrein ; arrière : 0,8 × chanfrein), rentré sous le contour :
    le contour du bâtiment reste fait des volumes qui le débordent. Lames sur chant au pas de 0,09, cornières
    boulonnées. Reprise de la plage haute de la passe 3 (apron), étendue aux 5 tailles.
    Clé d'habillage « plateforme » (passe 5) : matière ET motif du pont (pont_cfg, contrat dans epoques.py) ; le tablier
    continu et les cornières restent (aucun trou possible) ; None : code d'origine, géométrie identique."""
    if c.pont is not None:
        return _plateforme_habillee(g, c, chanfrein, z)
    M = g.M
    P_ = c.T["plateforme"]
    cf = P_["chanfrein"] if chanfrein is None else chanfrein
    cb = cf * 0.8
    side = c.side
    hx = side / 2.0 - P_["retrait"]
    hy = side / 2.0 - P_["retrait"]
    fy = P_["avant"]
    poly = [(-hx + cf, -fy), (hx - cf, -fy), (hx, -fy + cf), (hx, hy - cb), (hx - cb, hy), (-hx + cb, hy),
            (-hx, hy - cb), (-hx, -fy + cf)]
    P = [(x, Y(y)) for x, y in poly]
    n = len(P)
    vs = [(x, y, 0.0) for x, y in P] + [(x, y, z * 0.45) for x, y in P]
    fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, n + j, n + i))
    g._add(M["tablier"], "flat", vs, fs, "tablier")
    nb = int((2 * hx - 0.1) / 0.09)
    for i in range(nb):
        x = -hx + 0.05 + (i + 0.5) * (2 * hx - 0.1) / nb
        ys = []
        for j in range(n):
            (x0, y0), (x1, y1) = P[j], P[(j + 1) % n]
            if (x0 - x) * (x1 - x) <= 0 and x0 != x1:
                ys.append(y0 + (y1 - y0) * (x - x0) / (x1 - x0))
        if len(ys) < 2:
            continue
        ya, yb = min(ys) + 0.07, max(ys) - 0.07
        if yb > ya:
            g.box((x, (ya + yb) / 2, z * 0.45 + 0.012), (0.03, yb - ya, 0.024), M["grate"], "flat", what="lame")
    for i in range(n):
        p0, p1 = V((P[i][0], P[i][1], 0)), V((P[(i + 1) % n][0], P[(i + 1) % n][1], 0))
        d = p1 - p0
        L = d.length
        if L < 0.05:
            continue
        d.normalize()
        nrm = V((d.y, -d.x, 0))
        R = Matrix((d, V((-d.y, d.x, 0)), V((0, 0, 1)))).transposed()
        g.box((p0 + p1) / 2 - nrm * 0.04 + V((0, 0, z * 0.5)), (L, 0.08, z), M["steel_dk"], "hard", R=R,
              what="corniere")
        k = max(2, int(L / 0.3))
        for j in range(k):
            q = p0 + d * (L * (j + 0.5) / k) - nrm * 0.04 + V((0, 0, z))
            g.bolt(q, (0, 0, 1), 0.016, M["steel_hi"])
    return poly


def _plateforme_habillee(g, c, chanfrein, z):
    """Plateforme de la clé « plateforme » : même octogone, même tablier continu, mêmes cornières (matière « bord »,
    boulons « boulons » ou aucun), motif et matière du pont de l'époque, liseré lumineux facultatif."""
    M = g.M
    cfg = c.pont
    P_ = c.T["plateforme"]
    cf = P_["chanfrein"] if chanfrein is None else chanfrein
    cb = cf * 0.8
    side = c.side
    hx = side / 2.0 - P_["retrait"]
    hy = side / 2.0 - P_["retrait"]
    fy = P_["avant"]
    poly = [(-hx + cf, -fy), (hx - cf, -fy), (hx, -fy + cf), (hx, hy - cb), (hx - cb, hy), (-hx + cb, hy),
            (-hx, hy - cb), (-hx, -fy + cf)]
    P = [(x, Y(y)) for x, y in poly]
    n = len(P)
    _prisme(g, P, 0.0, z * 0.45, M[cfg["fond"]], "flat", "tablier")
    _motif(g, M, cfg, P, z * 0.45, 0.07, 7000 + side)
    for i in range(n):
        p0, p1 = V((P[i][0], P[i][1], 0)), V((P[(i + 1) % n][0], P[(i + 1) % n][1], 0))
        d = p1 - p0
        L = d.length
        if L < 0.05:
            continue
        d.normalize()
        nrm = V((d.y, -d.x, 0))
        R = Matrix((d, V((-d.y, d.x, 0)), V((0, 0, 1)))).transposed()
        g.box((p0 + p1) / 2 - nrm * 0.04 + V((0, 0, z * 0.5)), (L, 0.08, z), M[cfg["bord"]], "hard", R=R,
              what="corniere")
        if cfg["lisere"]:
            _lisere(g, M, cfg, p0, p1, nrm, z)
        if cfg["boulons"]:
            k = max(2, int(L / 0.3))
            for j in range(k):
                q = p0 + d * (L * (j + 0.5) / k) - nrm * 0.04 + V((0, 0, z))
                g.bolt(q, (0, 0, 1), 0.016, M[cfg["boulons"]])
    return poly


def dalle(g, x0, x1, y0, y1, z=0.045):
    """Dalle de caillebotis rectangulaire (même facture que la plateforme) : sous une pièce du niveau pair ou une
    machine posée hors de la plateforme, pour qu'aucun jour ne s'enferme entre elle et le socle. Suit la clé
    « plateforme » de l'époque (contexte g.ctx) : même motif, même matière que le pont."""
    with habille(g):
        c = getattr(g, "ctx", None)
        if c is not None and c.pont is not None:
            M = g.M
            cfg = c.pont
            x0, x1 = sorted((x0, x1))
            y0, y1 = sorted((y0, y1))
            P = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
            _prisme(g, P, 0.0, z * 0.45, M[cfg["fond"]], "flat", "dalle")
            _motif(g, M, cfg, P, z * 0.45, 0.05, int(7100 + 37 * abs(x0) + 53 * abs(y0)))
            for (a, b, cc, d_) in ((x0, x1, y0, y0 + 0.06), (x0, x1, y1 - 0.06, y1), (x0, x0 + 0.06, y0, y1),
                                   (x1 - 0.06, x1, y0, y1)):
                g.box(((a + b) / 2, (cc + d_) / 2, z * 0.5), (b - a, d_ - cc, z), M[cfg["bord"]], "hard",
                      what="corniere")
            return
        _dalle_lignee(g, x0, x1, y0, y1, z)


def _dalle_lignee(g, x0, x1, y0, y1, z):
    M = g.M
    g.box(((x0 + x1) / 2, (y0 + y1) / 2, z * 0.225), (x1 - x0, y1 - y0, z * 0.45), M["tablier"], "flat", what="dalle")
    nb = max(1, int((x1 - x0 - 0.1) / 0.09))
    for i in range(nb):
        x = x0 + 0.05 + (i + 0.5) * (x1 - x0 - 0.1) / nb
        g.box((x, (y0 + y1) / 2, z * 0.45 + 0.012), (0.03, y1 - y0 - 0.1, 0.024), M["grate"], "flat", what="lame")
    for (a, b, cc, d_) in ((x0, x1, y0, y0 + 0.06), (x0, x1, y1 - 0.06, y1), (x0, x0 + 0.06, y0, y1),
                           (x1 - 0.06, x1, y0, y1)):
        g.box(((a + b) / 2, (cc + d_) / 2, z * 0.5), (b - a, d_ - cc, z), M["steel_dk"], "hard", what="corniere")


@_lignee
def colonne(g, c):
    """Colonne à goussets et couronne d'orientation dentée à bandes de danger (lignée)."""
    M = g.M
    B = c.B
    P2.pedestal(g, B["R"], 0.0, B["h"], B["n"], M, [capot(c, "olive"), M["steel_dk"], capot(c, "olive"), M["redpaint"]],
                ladder_at=B["echelle"])
    PT.slewing_ring(g, B["R"] - 0.02, B["h"], B["rh"])


@_lignee
def tremie(g, c):
    """Trémie à trappe ouverte au sud (lignée), goulotte vers la couronne. Peinture, pochoirs et munitions visibles :
    habillage de l'époque (c.hab). Renvoie (point de sortie de la bande, boîte de la trémie)."""
    M = g.M
    x0, x1, yn0, y1, h = c.T["tremie"]
    y0 = Y(yn0)
    paint = M[c.hab["tremie"]] if c.hab["tremie"] else None
    mun = c.hab["munitions"]
    out = P3.hopper_top(g, x0, x1, y0, y1, 0.0, h, M, paint=paint, stencils=c.hab["pochoirs"],
                        belt_mats=tuple(M[k] for k in mun) if mun else None)
    if c.T["goulotte"]:
        pts = [tuple(out)] + [tuple(p) for p in c.T["goulotte"]]
    else:
        R = c.B["R"]
        pts = [tuple(out), (0.0, -(R + 0.12), c.rt - 0.02), (0.0, -(R - 0.08), c.rt + 0.02)]
    P2.feed_chute(g, pts, c.T["goulotte_w"], M)
    return out, (x0, x1, y0, y1, h)


def collecteur(g, c, liaison, r=None, z=None, angs=(-0.2, -0.85, -1.57, -2.29, -2.94)):
    """Collecteur qui ceinture le pied de la colonne, côté avant (toujours visible) : « tuyaux et câbles partout »
    (charte §4.2). liaison(g, pts, r) : la liaison de l'époque (fonction de epNN)."""
    B = c.B
    rr = B["R"] + 0.12 + 0.02 * (c.side - 2)
    zz = 0.15 + 0.03 * (c.side - 2) if z is None else z
    liaison(g, [(rr * math.cos(a), rr * math.sin(a), zz) for a in angs], 0.044 + 0.01 * (c.side - 2) if r is None else r)


def accroche(c, nom=None):
    """Places libres des POINTS D'ACCROCHE des superstructures d'époque (accroches.py) à la taille de c et pour le
    CANON et le chanfrein de l'époque : dict par nom (coin_NO, coin_NE, coin_SO, coin_SE, tremie_O, tremie_E, coupole,
    couronne) ; avec nom, la place de ce point seul. Socle : x, yn (tuiles de jeu, « with at(g, x, yn) »), r, dx, dy,
    h_max, h_ajour ; coupole : x, y, z (repère de la tête), r, entre_canons, z_canons ; couronne : r0, r1, z0, z1."""
    import accroches
    if getattr(c, "_accroches", None) is None:
        canon = {k: c.H[k] for k in ("L", "nb", "rb", "rr") if k in c.H}
        c._accroches = accroches.calcul(c.side, canon or None, getattr(c.ep, "PLATEFORME", {}).get("chanfrein"))
    return c._accroches[nom] if nom else c._accroches


def socle(g, c):
    """Base du niveau impair : plateforme, colonne, trémie (lignée), puis tout ce que l'époque y pose (ep.socle)."""
    plateforme(g, c, getattr(c.ep, "PLATEFORME", {}).get("chanfrein"))
    colonne(g, c)
    c.tremie_out, c.tremie_box = tremie(g, c)
    c.ep.socle(g, c)


def piece(g, c):
    """Pièce du niveau pair (couche ajoutée au socle, coins avant) : entièrement à l'époque (ep.piece)."""
    c.ep.piece(g, c)


# ------------------------------------------------------------------------------------------------
# Tête (repère de la tête : canons vers +Y)
# ------------------------------------------------------------------------------------------------
def jupe(g, R, z0, z1, mats, nstrips, band_mat):
    """Jupe blindée de la lignée : âme, bandes de blindage verticales rivetées, deux cerclages (habillage d'époque)."""
    M = g.M
    g.cyl((0, 0, (z0 + z1) / 2), "z", R, z1 - z0, M["seam"], n=64, style="smooth", what="ame")
    h = z1 - z0
    w = TAU * R / nstrips
    for k in range(nstrips):
        a = TAU * (k + 0.5) / nstrips
        d = V((math.cos(a), math.sin(a), 0.0))
        t = V((-math.sin(a), math.cos(a), 0.0))
        R3 = Matrix((t, d, V((0, 0, 1)))).transposed()
        m = mats[g.rng.randrange(len(mats))]
        th = 0.034 * (1 + 0.3 * (g.rng.random() - 0.5))
        g.box(d * (R + th / 2 - 0.004) + V((0, 0, z0 + h * 0.5)), (w * 0.9, th, h * 0.76), m, "hard", R=R3,
              what="bande")
        for s in (-1, 1):
            g.dome(d * (R + th) + t * (s * w * 0.34) + V((0, 0, z0 + h * 0.78)), d, 0.018, M["rivet"])
    for zz in (z0 + 0.03, z1 - 0.03):
        g.tube_shell((0, 0, zz), "z", R + 0.05, R - 0.02, 0.06, band_mat, n=64, what="cerclage")


@_lignee
def masque_lignee(g, c, mats=("ochre", "olive"), fentes=((0.0, 1.1),), visiere=("steel_hi", 0.03), coax=None):
    """Masque avant de la lignée entre les deux canons. fentes : (décalage x en part de mw, largeur en part de mw) ;
    visiere : (matière, profondeur) ; coax : None, ou dict(fut=matière, manchon=matière, manchon_y=0.3,
    manchon_r=0.046, manchon_L=0.12, anneau=bool) (mitrailleuse coaxiale sous le masque)."""
    M = g.M
    H = c.H
    R, zs, rz = H["R"], H["zs"], H["rz"]
    mw = R * 0.5
    PT.hull(g, -mw, mw, R * 0.55, R + 0.22, zs - 0.18, zs + rz * 0.5, ins=(0.04, 0.02, R * 0.26), panel=0.22,
            mats=capots_mats(c, mats), rivet_step=0.11)
    for dx, w in fentes:
        g.box((dx * mw, R + 0.235, zs + 0.02), (mw * w, 0.02, 0.04), M["emit"], "flat", what="fente")
    vm, vd = visiere
    g.box((0, R + 0.25 - (vd - 0.03) / 2, zs + 0.065), (mw * 1.3, vd, 0.025), M[vm], "hard", what="visiere")
    if coax:
        g.cyl((mw * 0.45, R + 0.2 + 0.18, zs - 0.06), "y", 0.03, 0.4, M[coax.get("fut", "steel_dk")], n=10, what="coax")
        g.cyl((mw * 0.45, R + 0.2 + coax.get("manchon_y", 0.28), zs - 0.06), "y", coax.get("manchon_r", 0.045),
              coax.get("manchon_L", 0.16), M[coax.get("manchon", "steel_hi")], n=12, what="coax_manchon")
        if coax.get("anneau"):
            F.lit_ring(g, (mw * 0.45, R + 0.2 + 0.365, zs - 0.06), "y", 0.04, M["emit"], w=0.01)


@_lignee
def nacelle_coque(g, c):
    """Nacelle arrière de la lignée : coque rivetée (olive et ocre), face arrière à grille (2×2 à 4×4) ou à deux
    grilles lumineuses (5×5 et 6×6). Renvoie le cadre (bx, yb0, yb1, ztop, yc) et le quadrilatère de la face arrière."""
    M = g.M
    H = c.H
    R, zs, rz = H["R"], H["zs"], H["rz"]
    N_ = c.T["nacelle"]
    bx = R * 0.62
    yb0, yb1 = -R - N_["recul"], -R * 0.5
    zb = zs - N_["bas"]
    T = PT.hull(g, -bx, bx, yb0, yb1, zb, zs + rz * 0.42, ins=(0.03, 0.04, 0.0), panel=0.24,
                mats=[capot(c, "olive"), capot(c, "ochre")], rivet_step=0.11)
    back =[V((-bx, yb0, zb)), V((bx, yb0, zb)), T[1], T[0]]
    if c.side >= 5:
        for (s0, s1) in ((0.08, 0.46), (0.54, 0.92)):
            PT.glow_grille(g, PT.lift(PT.face_quad(back, s0, s1, 0.2, 0.8), 0.03), 4, M["emit_soft"])
    else:
        g.grille(PT.lift(PT.face_quad(back, 0.15, 0.85, 0.2, 0.8), 0.01), 4, slat_mat=M[c.hab["grille_nacelle"]])
    ztop = zs + rz * 0.42
    return (bx, yb0, yb1, ztop, (yb0 + yb1) / 2), back


@_lignee
def echappements(g, c):
    """Organe dorsal par défaut de la nacelle : deux échappements (lignée)."""
    bx, yb0, yb1, ztop, yc = c.nac
    re, he = c.T["echap"]
    for sx in (-1, 1):
        PT.exhaust(g, (sx * bx * 0.7, yc - 0.05, ztop), re, he)


@_lignee
def tourelleau(g, c):
    """Tourelleau à périscopes et trappe (lignée). Renvoie (cx, cy, z du dessus)."""
    M = g.M
    H = c.H
    R, zs, rz = H["R"], H["zs"], H["rz"]
    Tt = c.T["tourelleau"]
    cx, cy = -R * 0.32, -R * 0.12
    zc = zs + rz * math.sqrt(max(0.0, 1 - (cx / R) ** 2 - (cy / (R * 1.06)) ** 2)) - 0.03
    hc, rc = Tt["h"], Tt["r"]
    g.cyl((cx, cy, zc + hc / 2), "z", rc, hc, M[c.hab["tourelleau"]], n=24, style="soft", what="tourelleau")
    g.torus((cx, cy, zc + hc), "z", rc - 0.02, 0.016 if c.side <= 4 else 0.018, M["steel_dk"], n=24, m=6, what="jonc")
    nper = Tt["n"]
    for k in range(nper):
        a = math.pi / 2 + (k - (nper - 1) / 2) * Tt["pas"]
        d = V((math.cos(a), math.sin(a), 0))
        Rr = Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()
        g.box(V((cx, cy, zc + hc * 0.6)) + d * rc, Tt["peri"], M["steel_dk"], "hard", R=Rr, what="periscope")
        g.box(V((cx, cy, zc + hc * 0.6)) + d * (rc + Tt["av"]), Tt["lentille"], M["emit"], "flat", R=Rr,
              what="lentille")
    hx, hy = R * 0.34, -R * 0.2
    zh = zs + rz * math.sqrt(max(0.0, 1 - (hx / R) ** 2 - (hy / (R * 1.06)) ** 2)) - 0.02
    PT.hatch(g, (hx, hy, zh), c.T["trappe"])
    return (cx, cy, zc + hc)


@_lignee
def bras(g, c, sx):
    """Bras de tourillon de la lignée (et ses deux berceaux, qui ferment les jours entre l'arme, la nacelle et la
    coupole), tourillon, chapeau boulonné. L'arme de l'époque se pose dessus (ep.arme)."""
    M = g.M
    H = c.H
    x = sx * H["gx"]
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    R = H["R"]
    xa, xb = sorted((sx * R * 0.8, x - sx * wr / 2))
    PT.hull(g, xa, xb, y0 + 0.1, y1 - 0.14, zg - hr * 0.7, zg + hr * 0.55, ins=(0.0, 0.02, 0.02), panel=0.22,
            mats=[capot(c, "olive"), M["steel_dk"]], faces="tsn", rivet_step=0.12)
    xc, xd = sorted((sx * R * 0.45, x))
    PT.hull(g, xc, xd, y0 - 0.34, y0 + 0.14, H["zs"] - 0.2, zg - hr * 0.55, ins=(0.02, 0.03, 0.0), panel=0.22,
            mats=[M["steel_dk"], capot(c, "olive")], faces="tsn", rivet_step=0.12)
    xe, xf = sorted((sx * R * 0.55, x))
    PT.hull(g, xe, xf, y1 - 0.2, y1 + 0.2, H["zs"] - 0.12, zg - hr * 0.35, ins=(0.02, 0.0, 0.04), panel=0.22,
            mats=[M["steel_dk"], capot(c, "olive")], faces="tsn", rivet_step=0.12)
    g.cyl(((xa + xb) / 2, (y0 + y1) / 2 - 0.04, zg - hr * 0.1), "x", hr * 0.62, abs(xb - xa) + 0.12, M["steel_dk"],
          n=20, what="tourillon")
    g.cyl((x + sx * (wr / 2 + 0.03), (y0 + y1) / 2 - 0.04, zg - hr * 0.1), "x", hr * 0.5, 0.06, M[c.hab["chapeau"]],
          n=16, style="hard", what="chapeau")
    F.bolts_ring(g, (x + sx * (wr / 2 + 0.062), (y0 + y1) / 2 - 0.04, zg - hr * 0.1), (sx, 0, 0), hr * 0.36, 6,
                 M["rivet"], r=0.015)
    return x


def tete(g, c):
    """Tête de la lignée, puis l'arme et les accents de l'époque. Les pièces de la lignée se dessinent dans la zone
    habillée (habille) ; l'arme (ep.arme), le masque, la nacelle et les accents de l'époque hors zone."""
    with habille(g, c):
        M = g.M
        H = c.H
        R, zs, rz = H["R"], H["zs"], H["rz"]
        z0 = c.rt
        g.cyl((0, 0, z0 + 0.035), "z", R + 0.07, 0.07, M["steel_dk"], n=56, style="soft", what="collier")
        nb = int(TAU * (R + 0.04) / 0.16)
        for k in range(nb):
            a = TAU * k / nb
            g.dome(((R + 0.04) * math.cos(a), (R + 0.04) * math.sin(a), z0 + 0.07), (0, 0, 1), 0.016, M["rivet"])
        jupe(g, R, z0 + 0.07, zs, [capot(c, "olive"), capot(c, "olive"), M["steel_dk"]],
             max(c.T["jupe_bandes"], int(TAU * R / 0.26)), M[c.hab["jupe_cerclage"]])
        c.Pf, c.Nf = P2.dome_hull(g, (0, 0, zs), R, R * 1.06, rz, capot(c, "olive"), M,
                                  seams=max(c.T["coupole_coutures"], int(TAU * R / 0.3)), band_mat=M["steel_dk"],
                                  ring_seams=c.T["rangs"])
    if hasattr(c.ep, "masque"):
        c.ep.masque(g, c)
    else:
        masque_lignee(g, c)
    c.nac, c.nac_face = nacelle_coque(g, c)
    if hasattr(c.ep, "nacelle"):
        c.ep.nacelle(g, c)
    else:
        echappements(g, c)
    c.tour = tourelleau(g, c)
    for sx in (-1, 1):
        x = bras(g, c, sx)
        c.ep.arme(g, c, x, sx)
    c.ep.tete(g, c)


# ------------------------------------------------------------------------------------------------
# Canon de lignée : rosette, bouche, canon complet corrigé pour la pose N (base des organes d'époque)
# ------------------------------------------------------------------------------------------------
def rosette(g, x, y0, z, L, nb, rb, rr, mat=None, phase=0.3, colliers=(0.8,), collier_mat=None, bouts=True,
            arr="ring", plaque=True, segments=12, pointes=None):
    """Faisceau de tubes de la lignée : tubes séparés, âme centrale pleine (aucun jour au travers), plaque de culasse,
    colliers de maintien boulonnés (on voit les tubes séparés entre l'organe d'époque et la bouche). arr : « ring »
    (faisceau rotatif), « row » (tubes côte à côte à plat), « square » (2 × 2 gros calibre). Renvoie les positions
    (x, z) des tubes. bouts : rosace sombre au bout de chaque tube (False si un frein la porte). pointes (défaut :
    comme bouts ; passe 5, pose N) : POINTE ÉCLAIRÉE de chaque tube, bague lumineuse de la couleur d'époque au bout
    du tube, visible de dessus : en pose N, la bouche se lit comme une rosette de tubes éclairés, jamais comme le
    chapeau d'une cheminée. Tubes par défaut en acier nu clair (M["gun"])."""
    M = g.M
    mat = mat or M["gun"]
    pointes = bouts if pointes is None else pointes
    tl = 0.05 + 0.02 * L
    pos = []
    if arr == "row":
        pitch = rb * 2.25
        for i in range(nb):
            pos.append((x + (i - (nb - 1) / 2) * pitch, z))
    elif arr == "square":
        for i in range(nb):
            a = math.pi / 4 + TAU * i / nb
            pos.append((x + rr * math.cos(a), z + rr * math.sin(a)))
    else:
        for i in range(nb):
            a = phase + TAU * i / nb
            pos.append((x + rr * math.cos(a), z + rr * math.sin(a)))
    for bx, bz in pos:
        g.cyl((bx, y0 + L / 2, bz), "y", rb, L, mat, n=segments, what="canon")
        if bouts:
            g.cyl((bx, y0 + L + 0.002, bz), "y", rb * 0.62, 0.008, M["void"], n=10, style="flat", what="bouche")
        if pointes:
            g.tube_shell((bx, y0 + L - tl / 2, bz), "y", rb + 0.012, rb - 0.006, tl, M["emit"], n=segments,
                         what="pointe_lum")
    cm = collier_mat or M["steel_dk"]
    if arr == "row":
        w = (nb - 1) * rb * 2.25
        g.box((x, y0 + L * 0.48, z - rb * 0.3), (w, L * 0.94, rb * 0.9), M["steel_dk"], "hard", what="ame")
        if plaque:
            g.box((x, y0 + 0.02, z), (w + 2 * rb + 0.03, 0.04, 2 * rb + 0.03), M["steel_dk"], "soft",
                  what="plaque_culasse")
        for f in colliers:
            yy = y0 + f * L
            g.box((x, yy, z), (w + 2 * rb + 0.03, 0.035, 2 * rb + 0.026), cm, "hard", what="collier")
            for s in (-1, 1):
                g.bolt((x + s * (w / 2 + rb * 0.4), yy, z + rb + 0.013), (0, 0, 1), 0.012, M["steel_hi"])
        return pos
    core = max(rr - rb * 0.55, rr * 0.55)
    g.cyl((x, y0 + L * 0.5, z), "y", core, L * 0.96, M["steel_dk"], n=14, what="ame")
    if plaque:
        g.cyl((x, y0 + 0.02, z), "y", rr + rb + 0.01, 0.04, M["steel_dk"], n=24, style="soft", what="plaque_culasse")
    for f in colliers:
        yy = y0 + f * L
        g.tube_shell((x, yy, z), "y", rr + rb + 0.016, core * 0.8, 0.035, cm, n=28, what="collier")
        F.bolts_ring(g, (x, yy, z), (0, 1, 0), rr + rb + 0.016, 6, M["rivet"], r=0.014, phase=0.5, skip_down=-0.3)
    return pos


def bouche(g, x, y, z, pos, rb, rim_mat, r_lum, w=0.026):
    """Bouche lisible (règle d'or 7) : rosace des bouts de tubes sombres cerclés, pourtour éclairé fin (couleur de
    l'époque, < 0,03 t²) de rayon r_lum."""
    F.bores(g, x, y, z, pos, rb, rim_mat)
    F.lit_ring(g, (x, y + 0.002, z), "y", r_lum, g.M["emit"], w=w)


def couronne_bouche(g, x, yb, z, L, rr, rb, mat, retrait=None):
    """COURONNE DE BOUCHE de la lignée (passe 5, pose N, règle d'or 7) : collerette sombre boulonnée AU RAS du
    faisceau (rayon rr + rb + 0,012 : jamais un chapeau plus large que le faisceau), posée en retrait de la bouche
    (retrait, défaut 0,06 + 0,03 L) : les tubes dépassent devant elle, séparés, leurs pointes éclairées (rosette()) ;
    vu de dessus en pose N, le bout du canon est une ROSETTE de tubes éclairés, pas le couvercle d'une cheminée. À
    utiliser par toute époque qui veut un bout de canon sans frein d'époque."""
    M = g.M
    rt = rr + rb + 0.012
    yc = yb - (0.06 + 0.03 * L if retrait is None else retrait)
    g.tube_shell((x, yc, z), "y", rt, max(rr - rb * 0.55, rr * 0.55) * 0.8, 0.045, mat, n=28, what="couronne_bouche")
    F.bolts_ring(g, (x, yc, z), (0, 1, 0), rt, 6, M["rivet"], r=0.013, phase=0.5, skip_down=-0.3)


def canon_lignee(g, c, x, sx, recv_mats=("ochre", "olive"), jaquette=0.42, frein=True, frein_mat="steel",
                 bague_mat="steel_dk", masque_mats=("ochre", "olive"), alim=True,
                 alim_mats=("olive", "ochre")):
    """Canon de lignée COMPLET, corrigé pour la pose N (règle d'or 7, passe 5) : culasse blindée, moteur arrière
    bobiné, rosette de tubes séparés en ACIER NU CLAIR, jaquette perforée sur la moitié arrière au plus, puis la
    COURONNE DE BOUCHE (couronne_bouche) : collerette sombre au ras du faisceau, JAMAIS plus large que lui, devant
    laquelle les tubes dépassent, pointes éclairées (rosette vue en bout). Le frein EN BLOC deux fois plus large de la
    passe 4 (« T » plat) est SUPPRIMÉ : les juges de la passe 4 l'ont lu comme le chapeau d'une cheminée (pose N).
    frein : True (défaut) = couronne de bouche ; False = tubes nus, pointes éclairées. frein_mat : ignoré (gardé pour
    les appels de la passe 4). Bagues sombres (aucune bague claire horizontale), caisse d'alimentation au pied qui
    déborde sur le côté extérieur (alim_mats : ses matières, passe 5), masque de canon. Une époque peut l'appeler tel
    quel et y AJOUTER son organe."""
    M = g.M
    H = c.H
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    L, nb, rb, rr = H["L"], H["nb"], H["rb"], H["rr"]
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=[M[k] for k in recv_mats])
    moteur_lignee(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6)
    pos = rosette(g, x, y1, zg, L, nb, rb, rr, colliers=(0.62, 0.86), collier_mat=M[bague_mat], bouts=True)
    rs = rr + rb + 0.028
    Lj = L * min(jaquette, JAQUETTE_MAX)
    if Lj > 0.05:
        g.cyl((x, y1 + Lj / 2, zg), "y", rs, Lj, M["gun"], n=28, style="smooth", what="jaquette")
        nh_ax = max(2, int((Lj - 0.1) / 0.06))
        nh_ang = max(8, int(TAU * rs / 0.07))
        for i in range(nh_ax):
            for j in range(nh_ang):
                a = TAU * j / nh_ang + (0.5 * TAU / nh_ang if i % 2 else 0.0)
                d = V((math.cos(a), 0.0, math.sin(a)))
                if d.z < -0.45:
                    continue
                p = V((x, y1 + 0.07 + (Lj - 0.14) * (i + 0.5) / nh_ax, zg)) + d * (rs + 0.002)
                g.cyl(p, d, 0.016, 0.006, M["void"], n=6, style="flat", what="trou")
        for yy in (y1 + 0.03, y1 + Lj - 0.02):
            g.tube_shell((x, yy, zg), "y", rs + 0.022, rs - 0.01, 0.05, M[bague_mat], n=28, what="bague")
            F.bolts_ring(g, (x, yy, zg), (0, 1, 0), rs + 0.024, 6, M["rivet"], r=0.015, phase=0.2, skip_down=-0.3)
    yb = y1 + L
    if frein:
        couronne_bouche(g, x, yb, zg, L, rr, rb, M[bague_mat])
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M[k] for k in masque_mats], rivet_step=0.11)
    if alim:
        # caisse d'alimentation au pied du canon, côté extérieur : elle déborde du faisceau (pose N : pas de fût lisse)
        xo = x + sx * (wr / 2 + 0.05)
        bw, bl, bh = 0.32 * wr / 0.4, 0.75 * L / 1.95, 0.5 * hr / 0.23
        bx0, bx1 = sorted((xo + sx * 0.02, xo + sx * (0.02 + bw)))
        PT.hull(g, bx0, bx1, y0 - 0.1, y0 - 0.1 + bl, zg - bh * 0.62, zg + bh * 0.42, ins=(0.015, 0.015, 0.015),
                panel=0.24, mats=[M[k] for k in alim_mats], rivet_step=0.11)
        bc = (bx0 + bx1) / 2
        # voile plein entre la culasse et la caisse, sous la goulotte (l'arche enfermait un jour : 9 px hr, témoin k4)
        xa_, xb_ = sorted((x + sx * wr / 2 - sx * 0.01, xo + sx * 0.03))
        g.box(((xa_ + xb_) / 2, y0 + bl * 0.45, zg + hr * 0.05), (xb_ - xa_, bl * 0.5, hr * 1.1), M["steel_dk"], "hard",
              what="voile")
        P2.feed_chute(g, [(bc, y0 - 0.1 + bl * 0.6, zg + bh * 0.42 + 0.02), (bc - sx * 0.05, y0 + bl * 0.55, zg + bh * 0.62),
                          (x + sx * wr * 0.2, y0 + bl * 0.5, zg + hr + 0.06)], 0.12 * wr / 0.4 + 0.04, M)
    return pos


def moteur_lignee(g, c, r, L, corps="steel_dk", flasque="olive", moyeu="brass"):
    """Moteur d'entraînement bobiné de la lignée : carter à ailettes, bobinage de cuivre apparent, flasque boulonnée."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z), "y", r, L, M[corps], n=28, style="soft", what="moteur")
    nf = int((L * 0.5) / 0.04)
    for k in range(nf):
        g.tube_shell((x, y - L / 2 + 0.04 + k * 0.04, z), "y", r + 0.03, r - 0.01, 0.016, M["steel_hi"], n=28,
                     what="ailette")
    for k in range(4):
        g.torus((x, y + L / 2 - 0.05 - k * 0.034, z), "y", r + 0.006, 0.017, M["copper"], n=28, m=6, what="bobinage")
    g.cyl((x, y - L / 2 - 0.03, z), "y", r * 0.85, 0.06, M[flasque], n=24, style="soft", what="flasque")
    for k in range(8):
        a = TAU * k / 8
        d = V((math.cos(a), 0, math.sin(a)))
        g.dome(V((x, y - L / 2 - 0.06, z)) + d * r * 0.66, V((0, -1, 0)), 0.016, M["rivet"])
    g.cyl((x, y - L / 2 - 0.08, z), "y", r * 0.3, 0.05, M[moyeu], n=12, what="moyeu")
