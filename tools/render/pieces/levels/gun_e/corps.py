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
  formes (passe 5, troisième temps) : FORME du pont, de la coupole, de la jupe et de la trémie par les clés
           forme_plateforme, forme_coupole, forme_jupe, forme_tremie (contrat « FORMES » dans epoques.py ; contours et
           hauteurs : silhouettes.py) ; None : code d'origine, empreinte identique. z_pont(c, x, yn) et z_coque(c, x, y)
           rendent la hauteur où poser un organe d'époque ; canon_effile() : proposition de lignée pour la pose N.
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
import silhouettes as SIL
from kit import SQ2, TAU
# lot K0 : repère, habillage de matière et primitives du pont sortis vers commun/ (mêmes noms, même code)
from repere import Y, at  # noqa: E402,F401

V = Vector

# longueur maximale d'une jaquette, carénage ou manchon d'époque posé SUR le faisceau, en part de la longueur des tubes
# (règle d'or 1) : au-delà, le faisceau et sa bouche ne se lisent plus
JAQUETTE_MAX = 0.5


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
        # FORMES des grandes pièces (passe 5, troisième temps ; silhouettes.py) : None = forme de la lignée
        self.formes = SIL.formes(hab)
        self.sil = SIL.plateforme(side, self.T, getattr(ep, "PLATEFORME", {}).get("chanfrein"),
                                  self.formes["forme_plateforme"])
        self.dz = self.sil["dz"]                  # surélévation de la colonne (0 : octogone de la lignée)
        self.tremie_z0 = self.sil["tremie_z0"]    # pied de la trémie
        self.prof = None                          # profil de la coupole (tete : None = demi-ellipsoïde)
        # dalle() (appelée par ep.piece sans contexte) retrouve l'habillage par g.ctx
        g.ctx = self


# ------------------------------------------------------------------------------------------------
# HABILLAGE DE MATIÈRE de la lignée : commun/habillage.py (lot K0, code inchangé)
# ------------------------------------------------------------------------------------------------
from habillage import (REMPLACE, _SECOND_SUIT, mats_habilles, habille, _lignee, mat, capot,
    capots_mats)  # noqa: E402,F401


# ------------------------------------------------------------------------------------------------
# PONT : matière ET motif de la plateforme : commun/pont.py (lot K0, code inchangé)
# ------------------------------------------------------------------------------------------------
from pont import (MOTIFS, PONT_DEFAUT, PAS_DEFAUT, JOINT_DEFAUT, pont_cfg, _demi_plan, _decoupe, _aire, _dedans,
    _prisme, _motif, _lisere)  # noqa: E402,F401


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
    continu et les cornières restent (aucun trou possible) ; None : code d'origine, géométrie identique.
    Clé « forme_plateforme » (passe 5, troisième temps) : CONTOUR, hauteur et bords du pont (_plateforme_forme)."""
    if c.formes["forme_plateforme"] is not None:
        with _hasard_local(g, 7300 + c.side):
            return _plateforme_forme(g, c)
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


# ------------------------------------------------------------------------------------------------
# FORMES DU PONT (clé « forme_plateforme », passe 5, troisième temps ; contours et hauteurs : silhouettes.py)
# ------------------------------------------------------------------------------------------------
# tables des formes du pont, hasard local, arêtes : commun/pont.py (lot K0, code inchangé)
from pont import (PONT_FORME, FLANC_FORME, MERLON, GARDE_CORPS_H, _hasard_local, _a_blanc, _PB, _aretes,
    _Rx)  # noqa: E402,F401


def _libre(c, x, yb):
    """Un point du bord (Blender) est-il hors de la trémie et des carrés de la pièce paire ? (bords, créneaux et
    garde-corps s'y interrompent : la pièce paire est une couche posée PAR-DESSUS le socle)."""
    yn = yb / SQ2
    if abs(x) < c.T["tremie"][1] + 0.08 and yn < -c.sil["fy"] + 0.35:
        return False
    P = c.T["piece"]
    s = max(1.0, P["s"])
    for sx in (-1, 1):
        if abs(x - sx * P["x"]) < 0.3 * s + 0.06 and abs(yn - P["yn"]) < 0.3 * s + 0.06:
            return False
    return True


def _segments(c, pa, pb, pas=0.02, mini=0.12):
    """Parties libres (_libre) de l'arête pa -> pb, chacune d'au moins `mini`."""
    L = (pb - pa).length
    k = max(2, int(L / pas))
    out, cur = [], None
    for i in range(k + 1):
        s = i / k
        p = pa.lerp(pb, s)
        ok = _libre(c, p.x, p.y)
        if ok and cur is None:
            cur = s
        if (not ok or i == k) and cur is not None:
            s1 = s if ok else (i - 1) / k
            if (s1 - cur) * L > mini:
                out.append((pa.lerp(pb, cur), pa.lerp(pb, s1)))
            cur = None
    return out


# parapets, garde-corps, filets, flancs et troncs : commun/pont.py (lot K0, code inchangé)
from pont import (_parapet, _garde_corps, _filet, _quad_flanc, _tronc)  # noqa: E402,F401


def _plateforme_forme(g, c):
    """Pont d'une FORME de silhouettes.FORMES["forme_plateforme"] (c.sil : contour, niveaux, hauteur). Le dessus porte le
    motif de la clé « plateforme » de l'époque (sinon celui de la forme, PONT_FORME) ; les flancs visibles (faces sud)
    sont habillés ; bords, créneaux et garde-corps s'interrompent devant la trémie et les carrés de la pièce paire.
    Tout volume est PLEIN jusqu'au sol (sauf les pieux du pilotis, ouverts vers le bas) : aucun trou enfermé."""
    M = g.M
    sil = c.sil
    f = sil["forme"]
    o = c.formes["forme_plateforme"]
    fl = M[o.get("flanc") or FLANC_FORME[f][0]]
    fl2 = M[o.get("flanc2") or FLANC_FORME[f][1]]
    if c.pont is not None:
        cfg = dict(c.pont)
    else:
        cfg = dict(PONT_DEFAUT)
        cfg.update(PONT_FORME[f] or {})
    if o.get("dessus"):
        cfg["mat"] = o["dessus"]
    lis = M[o["lisere"]] if o.get("lisere") else None
    H = sil["H"]
    PB = _PB(sil["contour"])
    graine = 7200 + c.side
    rivet = M["rivet"]
    if f in ("carre", "bastions"):
        _prisme(g, PB, 0.0, H * 0.45, M[cfg["fond"]], "flat", "tablier")
        _motif(g, M, cfg, PB, H * 0.45, 0.07, graine)
        gc = o.get("garde_corps", f == "carre")
        for pa, pb, nrm in _aretes(PB):
            L = (pb - pa).length
            d = (pb - pa).normalized()
            g.box((pa + pb) / 2 - nrm * 0.04 + V((0, 0, H * 0.5)), (L, 0.08, H), M[cfg["bord"]], "hard", R=_Rx(pb - pa),
                  what="corniere")
            if cfg["boulons"]:
                k = max(2, int(L / 0.3))
                for j in range(k):
                    g.bolt(pa + d * (L * (j + 0.5) / k) - nrm * 0.04 + V((0, 0, H)), (0, 0, 1), 0.016, M[cfg["boulons"]])
            if lis is not None:
                _filet(g, lis, pa, pb, nrm, H, 0.07)
            if gc:
                for qa, qb in _segments(c, pa, pb):
                    if nrm.y > 0.3:
                        _parapet(g, qa, qb, nrm, H, 0.05, 0.07, fl2, what="muret")
                    else:
                        _garde_corps(g, qa, qb, nrm, H, GARDE_CORPS_H + 0.015 * (c.side - 2), fl, fl2)
        for poly, z0, z1, role in sil["niveaux"]:
            if role != "bastion":
                continue
            Pt = _PB(poly)
            _prisme(g, Pt, 0.0, z1, M["seam"], "flat", "bastion")
            for pa, pb, nrm in _aretes(Pt):
                L = (pb - pa).length
                if nrm.y < -0.05:
                    g.panels(_quad_flanc(pa, pb, 0.0, z1), max(1, int(round(L / 0.3))), max(1, int(round(z1 / 0.24))),
                             fl, t=0.024, rivet_mat=rivet, rivet_step=0.12, mats=[fl, fl, fl2])
                _parapet(g, pa, pb, nrm, z1, 0.07, 0.035, fl2, merlons=(0.06, 0.09, 0.07), what="creneau")
            _prisme(g, SIL.rentre(Pt, 0.07), z1, z1 + 0.012, fl2, "hard", "toit_bastion")
        return sil["contour"]
    if f == "pilotis":
        wp = 0.06 + 0.01 * c.side
        pts = []
        for pa, pb, nrm in _aretes(PB):
            L = (pb - pa).length
            k = max(1, int(math.ceil(L / 0.45)))
            for j in range(k):
                p = pa.lerp(pb, j / k) - nrm * (wp / 2 + 0.03)
                if all((p - q).length > wp * 1.5 for q in pts):
                    pts.append(p)
        for p in pts:
            g.box(p + V((0, 0, (H - 0.05) / 2)), (wp, wp, H - 0.05), fl, "hard", what="pieu")
            g.box(p + V((0, 0, 0.012)), (wp + 0.04, wp + 0.04, 0.024), fl2, "hard", what="semelle_pieu")
        _prisme(g, PB, H - 0.05, H - 0.024, M[cfg["fond"]], "flat", "plancher")
        _motif(g, M, cfg, PB, H - 0.024, 0.06, graine)
        for pa, pb, nrm in _aretes(PB):
            L = (pb - pa).length
            d = (pb - pa).normalized()
            g.box((pa + pb) / 2 - nrm * 0.035 + V((0, 0, H - 0.03)), (L, 0.07, 0.06), fl2, "hard", R=_Rx(pb - pa),
                  what="poutre_rive")
            if cfg["boulons"]:
                k = max(2, int(L / 0.25))
                for j in range(k):
                    g.dome(pa + d * (L * (j + 0.5) / k) - nrm * 0.035 + V((0, 0, H)), (0, 0, 1), 0.016,
                           M[cfg["boulons"]])
            if lis is not None:
                _filet(g, lis, pa, pb, nrm, H, 0.035)
            if o.get("garde_corps"):
                for qa, qb in _segments(c, pa, pb):
                    if nrm.y > 0.3:
                        _parapet(g, qa, qb, nrm, H, 0.05, 0.07, fl2, what="muret")
                    else:
                        _garde_corps(g, qa, qb, nrm, H, GARDE_CORPS_H + 0.015 * (c.side - 2), fl2, fl)
        return sil["contour"]
    if f == "rond":
        _prisme(g, PB, 0.0, H, fl2, "flat", "plinthe")
        _motif(g, M, cfg, _PB(sil["dessus"][0]), H, 0.0, graine)
        for pa, pb, nrm in _aretes(PB):
            L = (pb - pa).length
            d = (pb - pa).normalized()
            if nrm.y < -0.05:
                g.panels(_quad_flanc(pa, pb, 0.008, H - 0.008), 1, 1, fl, t=0.02, rivet_mat=rivet, rivet_step=0.1,
                         rivet_r=0.016, rivet_inset=0.03)
            g.box((pa + pb) / 2 - nrm * 0.035 + V((0, 0, H + 0.016)), (L + 0.012, 0.07, 0.032), fl2, "hard",
                  R=_Rx(pb - pa), what="collerette")
            k = max(1, int(round(L / 0.12)))
            for j in range(k):
                g.dome(pa + d * (L * (j + 0.5) / k) - nrm * 0.035 + V((0, 0, H + 0.032)), (0, 0, 1), 0.016, rivet)
            if lis is not None:
                _filet(g, lis, pa, pb, nrm, H + 0.032, 0.012)
        return sil["contour"]
    if f == "hexagone":
        PD = _PB(sil["dessus"][0])
        _prisme(g, PB, 0.0, H - 0.03, fl2, "flat", "plinthe")
        _tronc(g, PB, PD, H - 0.03, H, M[cfg["bord"]], "hard", "biseau")
        _motif(g, M, cfg, PD, H, 0.0, graine)
        for pa, pb, nrm in _aretes(PB):
            L = (pb - pa).length
            if nrm.y < -0.05:
                g.panels(_quad_flanc(pa, pb, 0.006, H - 0.034), max(1, int(round(L / 0.32))), 1, fl, t=0.014,
                         gap=0.014, rivet_mat=None)
        if lis is not None:
            for pa, pb, nrm in _aretes(PD):
                _filet(g, lis, pa, pb, nrm, H, 0.008, w=0.014)
        return sil["contour"]
    if f == "pierre":
        PD = _PB(sil["dessus"][0])
        _prisme(g, PB, 0.0, H, M["seam"], "flat", "plinthe")
        _motif(g, M, cfg, PD, H, 0.0, graine)
        cren = o.get("crenaux", True)
        for pa, pb, nrm in _aretes(PB):
            L = (pb - pa).length
            if nrm.y < -0.05:
                F.courses(g, _quad_flanc(pa, pb, 0.0, H), [fl, fl2, fl], bw=0.22, bh=0.07, t=0.016, what="assise")
            g.box((pa + pb) / 2 - nrm * 0.05 + V((0, 0, H + 0.012)), (L, 0.1, 0.024), fl2, "hard", R=_Rx(pb - pa),
                  what="chaperon")
            if lis is not None:
                _filet(g, lis, pa, pb, nrm, H + 0.024, 0.09)
            if cren:
                for qa, qb in _segments(c, pa, pb):
                    _parapet(g, qa, qb, nrm, H + 0.024, 0.075, 0.045, fl, merlons=MERLON, what="creneau")
        return sil["contour"]
    if f == "gradins":
        ass = o.get("assises", False)
        cren = o.get("crenaux", False)
        niv = sil["niveaux"]
        for k, (poly, z0, z1, role) in enumerate(niv):
            Pk = _PB(poly)
            mk = fl if k % 2 == 0 else fl2
            _prisme(g, Pk, 0.0, z1, M["seam"] if ass else mk, "flat", role)
            for pa, pb, nrm in _aretes(Pk):
                L = (pb - pa).length
                zb = niv[k - 1][2] if k else 0.0
                if nrm.y < -0.05:
                    if ass:
                        F.courses(g, _quad_flanc(pa, pb, zb, z1), [mk, fl2 if k % 2 == 0 else fl, mk], bw=0.24,
                                  bh=0.074, t=0.016, what="assise")
                    else:
                        g.panels(_quad_flanc(pa, pb, zb + 0.004, z1 - 0.004), max(1, int(round(L / 0.3))), 1, mk,
                                 t=0.012, gap=0.014, rivet_mat=None)
                g.box((pa + pb) / 2 - nrm * 0.0175 + V((0, 0, z1 + 0.007)), (L, 0.035, 0.014), M[cfg["bord"]], "hard",
                      R=_Rx(pb - pa), what="arete_gradin")
                if lis is not None:
                    _filet(g, lis, pa, pb, nrm, z1 + 0.014, 0.0175, w=0.012)
                if cren and k == len(niv) - 1:
                    for qa, qb in _segments(c, pa, pb):
                        _parapet(g, qa, qb, nrm, z1 + 0.014, 0.05, 0.02, M[cfg["bord"]], merlons=(0.06, 0.07, 0.09),
                                 what="fleuron")
        _motif(g, M, cfg, _PB(sil["dessus"][0]), sil["H"], 0.0, graine)
        return sil["contour"]
    raise ValueError(f)


def z_pont(c, x, yn):
    """Hauteur du dessus du socle au point (x, yn) en tuiles de jeu (pont, plinthe, gradin, tour d'angle ; 0 hors du
    pont) : pour poser un organe d'époque SUR le pont d'une forme surélevée (corps.at(g, x, yn) puis z)."""
    return SIL.z_pont(c.sil, x, yn)


@_lignee
def colonne(g, c):
    """Colonne à goussets et couronne d'orientation dentée à bandes de danger (lignée). Forme de pont surélevée :
    le pied monte de c.dz (la semelle dépasse du pont comme sur l'octogone), le haut ne bouge pas."""
    M = g.M
    B = c.B
    mats = [capot(c, "olive"), M["steel_dk"], capot(c, "olive"), M["redpaint"]]
    if c.dz:
        # pied surélevé : dessin au hasard local, puis la colonne d'origine à blanc (même tirage pour la suite)
        with _hasard_local(g, 7400 + c.side):
            P2.pedestal(g, B["R"], c.dz, B["h"], B["n"], M, mats, ladder_at=B["echelle"])
        with _a_blanc(g):
            P2.pedestal(g, B["R"], 0.0, B["h"], B["n"], M, mats, ladder_at=B["echelle"])
    else:
        P2.pedestal(g, B["R"], 0.0, B["h"], B["n"], M, mats, ladder_at=B["echelle"])
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
    belt = tuple(M[k] for k in mun) if mun else None
    if c.formes["forme_tremie"] is None and not c.tremie_z0:
        out = P3.hopper_top(g, x0, x1, y0, y1, 0.0, h, M, paint=paint, stencils=c.hab["pochoirs"], belt_mats=belt)
    else:
        # forme de trémie ou pied surélevé : dessin au hasard local, puis la trémie d'origine à blanc
        with _hasard_local(g, 7500 + c.side):
            if c.formes["forme_tremie"] is not None:
                out = _tremie_forme(g, c, x0, x1, y0, y1, c.tremie_z0, h, paint or M["ochre"], belt)
            else:
                out = P3.hopper_top(g, x0, x1, y0, y1, c.tremie_z0, h, M, paint=paint, stencils=c.hab["pochoirs"],
                                    belt_mats=belt)
        with _a_blanc(g):
            P3.hopper_top(g, x0, x1, y0, y1, 0.0, h, M, paint=paint, stencils=c.hab["pochoirs"], belt_mats=belt)
    if c.T["goulotte"]:
        pts = [tuple(out)] + [tuple(p) for p in c.T["goulotte"]]
    else:
        R = c.B["R"]
        pts = [tuple(out), (0.0, -(R + 0.12), c.rt - 0.02), (0.0, -(R - 0.08), c.rt + 0.02)]
    P2.feed_chute(g, pts, c.T["goulotte_w"], M)
    return out, (x0, x1, y0, y1, h)


def _bandes_ouvertes(g, q, nrm, belt_mats):
    """Fond noir et rangées de cartouches couchées dans une ouverture q (dessus de trémie)."""
    g.slab(q, nrm, 0.004, g.M["void"], "flat", "trappe_fond")
    nrow = max(2, int((q[3] - q[0]).length / 0.085))
    for j in range(nrow):
        t = (j + 0.5) / nrow
        a = q[0].lerp(q[3], t) + nrm * 0.022
        b = q[1].lerp(q[2], t) + nrm * 0.022
        PT.belt(g, [a + (b - a) * 0.04, (a + b) / 2 + nrm * 0.01, b - (b - a) * 0.04], step=0.05, mats=belt_mats)


def _tremie_forme(g, c, x0, x1, y0, y1, z0, h, paint, belt_mats):
    """Trémie d'une FORME de silhouettes.FORMES["forme_tremie"], dans la MÊME boîte (x0..x1, y0..y1 Blender, z0..h ; le
    tambour et l'entonnoir peuvent déborder de 0,03 à 0,07 au sud et sur les côtés). Matières : option mat (défaut :
    peinture de la trémie, qui suit « tremie » puis « capots ») et mat2 (défaut : acier sombre habillé). Rend le point de
    sortie de la bande (la goulotte de la lignée part de là)."""
    M = g.M
    o = c.formes["forme_tremie"]
    f = o["forme"]
    pm = M[o["mat"]] if o.get("mat") else paint
    m2 = M[o.get("mat2") or "steel_dk"]
    rivet = M["rivet"]
    W, D = x1 - x0, y1 - y0
    xc = (x0 + x1) / 2
    if f == "tambour":
        # tambour-chargeur couché vers la colonne : sa FACE ronde (volant de chargeur) regarde la caméra
        r = min(W / 2 - 0.01, (h - z0) / 2 - 0.01)
        zc = z0 + r + 0.012
        ya, yb = y0 + 0.03, y1 - 0.02
        for yy in (ya + (yb - ya) * 0.2, ya + (yb - ya) * 0.8):
            g.box((xc, yy, z0 + r * 0.42), (r * 2.0, 0.09, r * 0.84), m2, "hard", what="berceau")
            for sx in (-1, 1):
                g.bolt((xc + sx * r * 0.82, yy - 0.045, z0 + 0.03), (0, -1, 0), 0.014, M["steel_hi"])
        g.cyl((xc, (ya + yb) / 2, zc), "y", r, yb - ya, pm, n=40, style="smooth", what="tambour")
        nh = max(3, int((yb - ya) / 0.32))
        for k in range(nh):
            yy = ya + 0.05 + (yb - ya - 0.1) * k / (nh - 1)
            g.tube_shell((xc, yy, zc), "y", r + 0.018, r - 0.01, 0.04, m2, n=40, what="cercle")
            F.bolts_ring(g, (xc, yy, zc), (0, 1, 0), r + 0.018, max(8, int(TAU * r / 0.12)), rivet, r=0.013,
                         phase=0.2, skip_down=-0.4)
        F.disc_wheel(g, (xc, ya - 0.012, zc), "y", r * 0.96, 0.05, m2, M[c.hab["chapeau"]], spokes=6, hub_mat=pm)
        F.hazard_ring(g, (xc, ya + 0.12, zc), "y", r + 0.004, 0.06, n=max(8, int(TAU * r / 0.1)))
        # fenêtre de chargement ouverte sur le dos du tambour, côté colonne (cartouches visibles)
        wq, lq = r * 1.1, min(0.36, (yb - ya) * 0.35)
        yq = yb - lq / 2 - 0.06
        zt = zc + r
        g.box((xc, yq, zt + 0.02), (wq + 0.06, lq + 0.06, 0.04), m2, "hard", what="cadre")
        q = [V((xc - wq / 2, yq - lq / 2, zt + 0.041)), V((xc + wq / 2, yq - lq / 2, zt + 0.041)),
             V((xc + wq / 2, yq + lq / 2, zt + 0.041)), V((xc - wq / 2, yq + lq / 2, zt + 0.041))]
        _bandes_ouvertes(g, q, V((0, 0, 1)), belt_mats)
        return V((xc, yq, zt + 0.06))
    if f == "silo":
        rs = min(W / 2, D / 2) - 0.02
        yc = y0 + rs + 0.03
        hs = z0 + (h - z0) * 1.3
        g.cyl((xc, yc, (z0 + hs) / 2), "z", rs, hs - z0, pm, n=40, style="smooth", what="silo")
        nb = max(2, int((hs - z0) / 0.14))
        for k in range(nb):
            zz = z0 + 0.04 + (hs - z0 - 0.08) * k / (nb - 1)
            g.tube_shell((xc, yc, zz), "z", rs + 0.016, rs - 0.01, 0.035, m2, n=40, what="virole")
            F.bolts_ring(g, (xc, yc, zz), (0, 0, 1), rs + 0.016, max(10, int(TAU * rs / 0.12)), rivet, r=0.013)
        g.cyl((xc, yc, hs + rs * 0.14), "z", rs + 0.02, rs * 0.28, m2, n=40, r2=rs * 0.3, style="soft", what="toit_silo")
        g.cyl((xc, yc, hs + rs * 0.3), "z", rs * 0.22, 0.05, M["steel_hi"], n=16, style="soft", what="lanterneau")
        P2.ladder(g, V((xc + rs + 0.02, yc, 0)), V((1, 0, 0)), z0 + 0.02, hs, 0.16, M)
        F.hazard_ring(g, (xc, yc, z0 + 0.12), "z", rs + 0.006, 0.07, n=max(10, int(TAU * rs / 0.1)))
        # caisson d'alimentation du pied du silo vers la colonne (plein : aucun jour)
        zf = z0 + (h - z0) * 0.62
        yfa, yfb = yc, y1
        g.box((xc, (yfa + yfb) / 2, (z0 + zf) / 2), (W * 0.62, yfb - yfa, zf - z0), pm, "hard", what="caisson_alim")
        for sx in (-1, 1):
            g.box((xc + sx * W * 0.31, (yfa + yfb) / 2, (z0 + zf) / 2), (0.03, yfb - yfa, zf - z0), m2, "hard",
                  what="nervure")
        wq = W * 0.5
        yq0, yq1 = yc + rs + 0.03, y1 - 0.04
        if yq1 - yq0 > 0.1:
            q = [V((xc - wq / 2, yq0, zf + 0.002)), V((xc + wq / 2, yq0, zf + 0.002)), V((xc + wq / 2, yq1, zf + 0.002)),
                 V((xc - wq / 2, yq1, zf + 0.002))]
            _bandes_ouvertes(g, q, V((0, 0, 1)), belt_mats)
            return V((xc, (yq0 + yq1) / 2, zf + 0.03))
        return V((xc, y1 - 0.05, zf + 0.03))
    if f == "entonnoir":
        e = min(0.07, 0.03 + 0.01 * c.side)
        zb = z0 + 0.42 * (h - z0)
        PT.hull(g, x0, x1, y0, y1, z0, zb, ins=(0.0, 0.0, 0.0), panel=0.3, mats=[pm, pm, m2], faces="sew",
                rivet_step=0.12)
        g.hazard(PT.lift(PT.face_quad([V((x0, y0, z0)), V((x1, y0, z0)), V((x1, y0, zb)), V((x0, y0, zb))],
                                      0.0, 1.0, 0.68, 0.94), 0.03), max(4, int(W / 0.1)))
        B = [V((x0, y0, zb)), V((x1, y0, zb)), V((x1, y1, zb)), V((x0, y1, zb))]
        T = [V((x0 - e, y0 - e, h)), V((x1 + e, y0 - e, h)), V((x1 + e, y1, h)), V((x0 - e, y1, h))]
        g.hexa(B + T, M["seam"], "flat", "entonnoir")
        for q in ([B[0], B[1], T[1], T[0]], [B[1], B[2], T[2], T[1]], [B[3], B[0], T[0], T[3]]):
            lu, lv = (q[1] - q[0]).length, (q[3] - q[0]).length
            g.panels(q, max(1, int(round(lu / 0.3))), max(1, int(round(lv / 0.26))), pm, t=0.024, rivet_mat=rivet,
                     rivet_step=0.12)
        nrm = V((0, 0, 1))
        fr = 0.055
        for (a, b, cc, dd) in ((x0 - e, x1 + e, y0 - e, y0 - e + fr), (x0 - e, x1 + e, y1 - fr, y1),
                               (x0 - e, x0 - e + fr, y0 - e, y1), (x1 + e - fr, x1 + e, y0 - e, y1)):
            g.box(((a + b) / 2, (cc + dd) / 2, h + 0.018), (b - a, dd - cc, 0.036), m2, "hard", what="cadre")
        k = max(3, int((x1 - x0 + 2 * e) / 0.12))
        for j in range(k):
            xx = x0 - e + (x1 - x0 + 2 * e) * (j + 0.5) / k
            g.dome((xx, y0 - e + fr / 2, h + 0.036), nrm, 0.015, rivet)
        q = [V((x0 - e + fr, y0 - e + fr, h + 0.001)), V((x1 + e - fr, y0 - e + fr, h + 0.001)),
             V((x1 + e - fr, y1 - fr, h + 0.001)), V((x0 - e + fr, y1 - fr, h + 0.001))]
        _bandes_ouvertes(g, q, nrm, belt_mats)
        if c.hab["pochoirs"]:
            s_ = [V((x0, y0, z0)), V((x1, y0, z0)), V((x1, y0, zb)), V((x0, y0, zb))]
            P2.stencil(g, PT.lift(PT.face_quad(s_, 0.08, 0.32, 0.25, 0.5), 0.03), 3, M["dial"])
        return V((xc, (y0 + y1) / 2, h + 0.02))
    raise ValueError(f)


def collecteur(g, c, liaison, r=None, z=None, angs=(-0.2, -0.85, -1.57, -2.29, -2.94)):
    """Collecteur qui ceinture le pied de la colonne, côté avant (toujours visible) : « tuyaux et câbles partout »
    (charte §4.2). liaison(g, pts, r) : la liaison de l'époque (fonction de epNN)."""
    B = c.B
    rr = B["R"] + 0.12 + 0.02 * (c.side - 2)
    zz = 0.15 + 0.03 * (c.side - 2) + c.dz if z is None else z
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
    hc, rc = Tt["h"], Tt["r"]
    if c.prof is None:
        zc = zs + rz * math.sqrt(max(0.0, 1 - (cx / R) ** 2 - (cy / (R * 1.06)) ** 2)) - 0.03
        g.cyl((cx, cy, zc + hc / 2), "z", rc, hc, M[c.hab["tourelleau"]], n=24, style="soft", what="tourelleau")
    else:
        # coque d'une autre forme : le tourelleau se pose au point le plus haut de son pied et descend jusqu'au plus
        # bas (aucun jour sous lui sur une coque en pente)
        hs = [z_coque(c, cx + rc * math.cos(TAU * k / 12), cy + rc * math.sin(TAU * k / 12)) for k in range(12)]
        hs.append(z_coque(c, cx, cy))
        zc = max(hs) - 0.03
        zb = min(hs) - 0.03
        g.cyl((cx, cy, (zb + zc + hc) / 2), "z", rc, zc + hc - zb, M[c.hab["tourelleau"]], n=24, style="soft",
              what="tourelleau")
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
    if c.prof is None:
        zh = zs + rz * math.sqrt(max(0.0, 1 - (hx / R) ** 2 - (hy / (R * 1.06)) ** 2)) - 0.02
        PT.hatch(g, (hx, hy, zh), c.T["trappe"])
    else:
        e = 0.02
        zh = z_coque(c, hx, hy) - 0.012
        nrm = V((-(z_coque(c, hx + e, hy) - z_coque(c, hx - e, hy)) / (2 * e),
                 -(z_coque(c, hx, hy + e) - z_coque(c, hx, hy - e)) / (2 * e), 1.0)).normalized()
        g.push_frame((hx, hy, zh), nrm, xdir=(1, 0, 0))
        PT.hatch(g, (0, 0, 0), c.T["trappe"])
        g.pop()
    return (cx, cy, zc + hc)


def z_coque(c, x, y):
    """Hauteur de la coupole au point (x, y) du repère de la tête (zs si hors de la coque) : pour poser un organe
    d'époque SUR une coupole de forme (c.Pf, c.Nf restent utilisables : même signature que la lignée)."""
    H = c.H
    if c.prof is None:
        return H["zs"] + H["rz"] * math.sqrt(max(0.0, 1 - (x / H["R"]) ** 2 - (y / (H["R"] * 1.06)) ** 2))
    h = SIL.haut_coupole(c.prof, H["R"], x, y)
    return H["zs"] + (h or 0.0)


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


# ------------------------------------------------------------------------------------------------
# FORMES DE LA TÊTE (clés « forme_jupe » et « forme_coupole », passe 5, troisième temps ; profils : silhouettes.py)
# ------------------------------------------------------------------------------------------------
def _jupe_forme(g, c, R, z0, z1, mats, nstrips, band_mat):
    """Jupe d'une FORME de silhouettes.FORMES["forme_jupe"] (même hauteur, rayon extérieur <= celui de la lignée : la
    place de la couronne ne rétrécit pas). Matières : option mat (défaut : capot olive habillé ; colonnade : capot
    ocre), mat2 (défaut : acier sombre habillé)."""
    M = g.M
    o = c.formes["forme_jupe"]
    f = o["forme"]
    m1 = M[o["mat"]] if o.get("mat") else mats[0]
    m2 = M[o["mat2"]] if o.get("mat2") else M["steel_dk"]
    h = z1 - z0
    rivet = M["rivet"]
    if f == "conique":
        # tronc de cône à pans rivetés : la tête se pose sur un col plus étroit que la coupole
        Rb = R * 0.8
        n = o.get("n") or nstrips
        g.cyl((0, 0, (z0 + z1) / 2), "z", Rb - 0.012, h, M["seam"], n=n, r2=R - 0.012, style="flat", what="ame")

        def p(a, r, z):
            return V((r * math.cos(a), r * math.sin(a), z))
        for k in range(n):
            a0, a1 = TAU * k / n, TAU * (k + 1) / n
            g.panels([p(a0, Rb, z0), p(a1, Rb, z0), p(a1, R, z1), p(a0, R, z1)], 1, max(1, int(round(h / 0.2))), m1,
                     t=0.026, gap=0.016, rivet_mat=rivet, rivet_step=0.11, mats=[m1, m1, m2])
        g.tube_shell((0, 0, z1 - 0.03), "z", R + 0.05, R - 0.02, 0.06, band_mat, n=64, what="cerclage")
        g.tube_shell((0, 0, z0 + 0.025), "z", Rb + 0.04, Rb - 0.03, 0.05, m2, n=64, what="cerclage")
        return
    if f == "colonnade":
        # colonnade : colonnes à base et chapiteau devant une âme sombre, stylobate, entablement
        mc = M[o["mat"]] if o.get("mat") else capot(c, "ochre")
        Rc = R * 0.82
        g.cyl((0, 0, (z0 + z1) / 2), "z", Rc, h, M["seam"], n=48, style="smooth", what="ame")
        g.tube_shell((0, 0, z0 + 0.022), "z", R + 0.02, Rc - 0.02, 0.044, m2, n=64, what="stylobate")
        he = min(0.07, h * 0.22)
        g.tube_shell((0, 0, z1 - he / 2), "z", R + 0.04, Rc - 0.02, he, mats[0], n=64, what="entablement")
        g.tube_shell((0, 0, z1 - he - 0.012), "z", R + 0.02, Rc, 0.024, band_mat, n=64, what="cerclage")
        rk = 0.03 + 0.004 * (c.side - 2)
        n = o.get("n") or max(12, int(TAU * R * 0.93 / 0.16))
        zb, zt = z0 + 0.044, z1 - he - 0.024
        for k in range(n):
            a = TAU * (k + 0.5) / n
            d = V((math.cos(a), math.sin(a), 0.0))
            R3 = Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()
            q = d * (R * 0.93)
            g.cyl(q + V((0, 0, (zb + zt) / 2)), "z", rk, zt - zb, mc, n=10, style="smooth", what="colonne_jupe")
            g.box(q + V((0, 0, zb + 0.012)), (rk * 2.6, rk * 2.6, 0.024), m2, "hard", R=R3, what="base_colonne")
            g.box(q + V((0, 0, zt - 0.012)), (rk * 2.9, rk * 2.9, 0.024), mc, "hard", R=R3, what="chapiteau")
        return
    if f == "ecailles":
        # écailles rivetées qui se recouvrent, en rangs décalés
        g.cyl((0, 0, (z0 + z1) / 2), "z", R - 0.006, h, M["seam"], n=64, style="smooth", what="ame")
        nr = max(2, int(round(h / 0.085)))
        hs = h / nr
        n = o.get("n") or max(16, int(TAU * R / 0.12))
        for j in range(nr):
            zc = z0 + hs * (j + 0.5)
            for k in range(n):
                a = TAU * (k + 0.5 * (j % 2)) / n
                d = V((math.cos(a), math.sin(a), 0.0))
                t = V((-d.y, d.x, 0.0))
                Rm = Matrix((t, d, V((0, 0, 1)))).transposed() @ Matrix.Rotation(0.22, 3, "X")
                m = (m1, m1, m2)[g.rng.randrange(3)]
                g.box(d * (R + 0.012) + V((0, 0, zc)), (TAU * R / n * 1.04, 0.014, hs * 1.28), m, "hard", R=Rm,
                      what="ecaille")
                g.dome(d * (R + 0.022) + V((0, 0, zc + hs * 0.38)), d, 0.014, rivet)
        g.tube_shell((0, 0, z1 - 0.025), "z", R + 0.05, R - 0.02, 0.05, band_mat, n=64, what="cerclage")
        g.tube_shell((0, 0, z0 + 0.02), "z", R + 0.045, R - 0.02, 0.04, m2, n=64, what="cerclage")
        return
    raise ValueError(f)


def _revolve(g, c, mat, style="smooth", nth=64, nt=24, what="coupole"):
    """Coque de révolution du profil c.prof (pans plats si c.prof["pans"]), fermée en bas."""
    H = c.H
    R, zs = H["R"], H["zs"]
    pr = c.prof
    ry = pr["ry"]
    rho, zeta = pr["rho"], pr["zeta"]
    pans = pr["pans"]
    ts = sorted(set([i / nt for i in range(nt + 1)] + list(pr["cassures"])))
    rings = [t for t in ts if rho(t) > 1e-4]
    apex = rho(ts[-1]) <= 1e-4
    if pans:
        ths = [math.pi / pans + TAU * j / pans for j in range(pans)]
    else:
        ths = [TAU * j / nth for j in range(nth)]
    n = len(ths)
    vs, fs = [], []
    for t in rings:
        r = rho(t)
        for th in ths:
            vs.append((R * r * math.cos(th), ry * R * r * math.sin(th), zs + zeta(t)))
    m = len(rings)
    for i in range(m - 1):
        for j in range(n):
            j2 = (j + 1) % n
            fs.append((i * n + j, i * n + j2, (i + 1) * n + j2, (i + 1) * n + j))
    if apex:
        vs.append((0.0, 0.0, zs + zeta(ts[-1])))
        top = len(vs) - 1
        for j in range(n):
            fs.append(((m - 1) * n + j, (m - 1) * n + (j + 1) % n, top))
    else:
        fs.append(tuple(range((m - 1) * n, m * n)))
    fs.append(tuple(range(n))[::-1])
    g._add(mat, style, vs, fs, what)


def _boucle(g, P, ph, k, r, mat, n=64, what="bourrelet"):
    pts = [P(TAU * i / n, ph, k) for i in range(n + 1)]
    g.tube(pts, r, mat, n=8, caps=False, what=what)


def _meridien(g, P, N, th, ph0, ph1, r, mat, rivet=None, pas=0.11, n=16, what="nervure"):
    pts = [P(th, ph0 + (ph1 - ph0) * i / n, 1.006) for i in range(n + 1)]
    g.tube(pts, r, mat, n=6, what=what)
    if rivet is not None:
        L = sum((pts[i + 1] - pts[i]).length for i in range(n))
        k = max(2, int(L / pas))
        for i in range(k):
            ph = ph0 + (ph1 - ph0) * (i + 0.5) / k
            g.dome(P(th, ph, 1.006) + N(th, ph) * (r * 0.7), N(th, ph), 0.015, rivet)


def _coupole_forme(g, c):
    """Coupole d'une FORME de silhouettes.FORMES["forme_coupole"]. Rend (P, N) de MÊME signature que la lignée :
    P(th, ph, k=1) point de la coque (ph de 0 à pi/2, de l'équateur au sommet), N(th, ph) normale sortante ; les
    appliques d'époque (P2.applique(g, c.Pf, c.Nf, …)) se posent donc sur toute forme. Matières : option mat (défaut
    capot olive habillé), mat2 (défaut acier sombre habillé), verre (cloche), epi (flèche du bulbe, de la pyramide)."""
    M = g.M
    H = c.H
    R, zs, rz = H["R"], H["zs"], H["rz"]
    pr = c.prof
    o = c.formes["forme_coupole"]
    f = pr["forme"]
    m1 = M[o["mat"]] if o.get("mat") else capot(c, "olive")
    m2 = M[o["mat2"]] if o.get("mat2") else M["steel_dk"]
    lis = M[o["lisere"]] if o.get("lisere") else None
    epi = M[o.get("epi") or c.hab["chapeau"]]
    rivet = M["rivet"]
    pans = pr["pans"]
    ph0 = math.pi / pans if pans else 0.0
    rho, zeta, ry = pr["rho"], pr["zeta"], pr["ry"]
    s2 = c.side - 2

    def P(th, ph, k=1.0):
        t = max(0.0, min(1.0, ph / (math.pi / 2)))
        r = rho(t) * SIL.facteur_pans(th, pans, ph0)
        return V((R * k * r * math.cos(th), ry * R * k * r * math.sin(th), zs + k * zeta(t)))

    def N(th, ph):
        t = max(0.0, min(0.995, ph / (math.pi / 2)))
        p_ = t * math.pi / 2
        e = 1e-3
        a = P(th + e, p_) - P(th - e, p_)
        b = P(th, p_ + e) - P(th, max(0.0, p_ - e))
        n_ = a.cross(b)
        if n_.length < 1e-9:
            return V((0.0, 0.0, 1.0))
        n_.normalize()
        if n_.dot(P(th, p_) - V((0.0, 0.0, zs + 0.3 * pr["hmax"]))) < 0:
            n_ = -n_
        return n_

    def ph_de(t):
        return t * math.pi / 2

    if f == "dome_bas":
        # dôme bas riveté à côtes serrées, trois rangs de rivets, bouton sommital
        hb = pr["hmax"]
        Pd, Nd = P2.dome_hull(g, (0, 0, zs), R, R * 1.06, hb, m1, M, seams=max(16, int(TAU * R / 0.2)),
                              band_mat=m2, ring_seams=(0.35, 0.75))
        g.cyl((0, 0, zs + hb + 0.012), "z", R * 0.2, 0.05, m2, n=32, style="soft", what="bouton")
        F.bolts_ring(g, (0, 0, zs + hb + 0.037), (0, 0, 1), R * 0.16, max(8, int(TAU * R * 0.16 / 0.07)), rivet, r=0.014)
        g.cyl((0, 0, zs + hb + 0.06), "z", R * 0.07, 0.04, epi, n=16, style="soft", what="bouton")
        return Pd, Nd
    if f == "tour":
        # tour cylindrique crénelée : assises sur une âme sombre, mâchicoulis, meurtrières, toit plat, créneaux
        hw = zeta(1.0)
        Rt = rho(0.0) * R
        _revolve(g, c, M["seam"], "smooth", nth=48)
        nc = max(3, int(round(hw / 0.075)))
        hb_ = hw / nc
        nb = max(12, int(TAU * Rt / 0.2))
        for j in range(nc):
            for k in range(nb):
                a = TAU * (k + 0.5 * (j % 2)) / nb
                d = V((math.cos(a), math.sin(a), 0.0))
                R3 = Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()
                th_ = 0.014 * (1.0 + 0.4 * (g.rng.random() - 0.5))
                g.box(d * (Rt + th_ / 2) + V((0, 0, zs + hb_ * (j + 0.5))), (TAU * Rt / nb - 0.014, th_, hb_ - 0.012),
                      m1, "hard", R=R3, what="assise")
        nm = max(10, int(TAU * Rt / 0.12))
        for k in range(nm):
            a = TAU * (k + 0.5) / nm
            d = V((math.cos(a), math.sin(a), 0.0))
            R3 = Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()
            g.box(d * (Rt + 0.03) + V((0, 0, zs + hw - 0.035)), (0.05, 0.05, 0.05), m2, "hard", R=R3,
                  what="machicoulis")
        g.tube_shell((0, 0, zs + hw + 0.022), "z", Rt + 0.055, Rt - 0.06, 0.044, m1, n=64, what="parapet")
        nme = max(8, int(TAU * Rt / (MERLON[1] + MERLON[2])))
        for k in range(nme):
            a = TAU * (k + 0.5) / nme
            d = V((math.cos(a), math.sin(a), 0.0))
            R3 = Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()
            g.box(d * Rt + V((0, 0, zs + hw + 0.044 + MERLON[0] / 2)), (MERLON[1], 0.1, MERLON[0]), m1, "hard", R=R3,
                  what="merlon")
        for k in range(8):
            a = TAU * (k + 0.5) / 8
            d = V((math.cos(a), math.sin(a), 0.0))
            R3 = Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()
            g.box(d * (Rt + 0.018) + V((0, 0, zs + hw * 0.5)), (0.028, 0.012, min(0.16, hw * 0.42)), M["void"], "flat",
                  R=R3, what="meurtriere")
        g.cyl((0, 0, zs + hw + 0.006), "z", Rt - 0.07, 0.012, m2, n=48, style="flat", what="toit")
        g.tube_shell((0, 0, zs + 0.03), "z", Rt + 0.035, Rt - 0.02, 0.06, m2, n=64, what="bourrelet")
        return P, N
    if f == "pyramide":
        # pyramide à pans plats : tôles rivetées par pan, arêtiers rivetés, plateau et flèche au sommet
        tc = pr["cassures"][0]
        zt = zs + zeta(tc)
        _revolve(g, c, M["seam"], "hard")

        def Pv(th, t, k=1.0):
            r = rho(t)
            return V((R * k * r * math.cos(th), ry * R * k * r * math.sin(th), zs + k * zeta(t)))
        for k in range(pans):
            a0 = ph0 + TAU * k / pans
            a1 = a0 + TAU / pans
            q = [Pv(a0, 0.02), Pv(a1, 0.02), Pv(a1, tc - 0.04), Pv(a0, tc - 0.04)]
            cen = (q[0] + q[1] + q[2] + q[3]) / 4
            q = [p + (cen - p).normalized() * 0.03 for p in q]
            lv = (q[3] - q[0]).length
            g.panels(q, 1, max(1, int(round(lv / 0.28))), m1, t=0.022, gap=0.016, rivet_mat=rivet, rivet_step=0.11)
            pts = [Pv(a0, tc * i / 12, 1.004) for i in range(13)]
            g.tube(pts, 0.02, m2, n=8, what="aretier")
            L = sum((pts[i + 1] - pts[i]).length for i in range(12))
            for i in range(max(2, int(L / 0.11))):
                tt = tc * (i + 0.5) / max(2, int(L / 0.11))
                p = Pv(a0, tt, 1.004)
                nrm = (p - V((0, 0, zs))).normalized()
                g.dome(p + nrm * 0.016, nrm, 0.014, rivet)
        top = [(R * rho(tc) * math.cos(ph0 + TAU * j / pans), ry * R * rho(tc) * math.sin(ph0 + TAU * j / pans))
               for j in range(pans)]
        _prisme(g, top, zt - 0.01, zt + 0.03, m2, "hard", "plateau")
        hf = 0.1 + 0.035 * s2
        g.cyl((0, 0, zt + 0.03 + hf / 2), "z", 0.026, hf, epi, n=12, r2=0.008, style="soft", what="fleche")
        g.sphere((0, 0, zt + 0.03 + hf * 0.3), 0.042, epi, n=16, m=8, what="pommeau")
        return P, N
    if f == "bulbe":
        # bulbe (oignon) à côtes rivetées, bandeau, flèche à pommeau
        _revolve(g, c, m1, "smooth", nth=56, nt=28)
        nr = max(8, int(TAU * R / 0.32))
        for k in range(nr):
            _meridien(g, P, N, TAU * (k + 0.5) / nr, ph_de(0.03), ph_de(0.93), 0.014, m2, rivet)
        _boucle(g, P, ph_de(0.02), 1.012, 0.026, m2)
        _boucle(g, P, ph_de(0.42), 1.008, 0.012, M[c.hab["jupe_cerclage"]], what="bandeau")
        ztop = zs + zeta(1.0)
        hf = 0.14 + 0.04 * s2
        g.cyl((0, 0, ztop + hf / 2 - 0.02), "z", 0.022, hf, epi, n=12, r2=0.006, style="soft", what="fleche")
        g.sphere((0, 0, ztop + hf * 0.32), 0.045, epi, n=16, m=8, what="pommeau")
        g.torus((0, 0, ztop + hf * 0.12), "z", 0.04, 0.012, epi, n=20, m=6, what="bague_fleche")
        return P, N
    if f == "cloche":
        # cloche de verre à meneaux, cerclée, couronnée d'isolateurs
        verre = M[o.get("verre") or "glass"]
        _revolve(g, c, verre, "smooth", nth=56, nt=24)
        nm = max(10, int(TAU * R / 0.24))
        for k in range(nm):
            _meridien(g, P, N, TAU * (k + 0.5) / nm, 0.0, ph_de(0.97), 0.013, m2, None, what="meneau")
        for t in (0.22, 0.5, 0.76):
            _boucle(g, P, ph_de(t), 1.006, 0.012, m2, what="cerce")
        g.tube_shell((0, 0, zs + 0.025), "z", R * rho(0.0) + 0.035, R * rho(0.0) - 0.04, 0.05, m1, n=64, what="socle_cloche")
        F.bolts_ring(g, (0, 0, zs + 0.05), (0, 0, 1), R * rho(0.0) + 0.005, max(12, int(TAU * R / 0.12)), rivet, r=0.014)
        ztop = zs + zeta(1.0)
        for i, rr_ in enumerate((0.07, 0.058, 0.046)):
            g.cyl((0, 0, ztop + 0.01 + 0.035 * i), "z", rr_, 0.022, M["ceramique"], n=20, style="soft", what="isolateur")
        g.cyl((0, 0, ztop + 0.125), "z", 0.02, 0.06, m2, n=10, what="borne")
        if lis is not None:
            g.sphere((0, 0, ztop + 0.165), 0.028, lis, n=12, m=6, what="bouton_lum")
        return P, N
    if f == "anneau":
        # noyau bas à côtes rivetées, deux anneaux horizontaux tenus par des bras, doublure lumineuse
        _revolve(g, c, m1, "smooth", nth=56)
        nr = 8
        for k in range(nr):
            _meridien(g, P, N, TAU * (k + 0.5) / nr, ph_de(0.03), ph_de(0.9), 0.013, m2, rivet)
        hb = zeta(1.0)
        ma = M[o["mat2"]] if o.get("mat2") else M["steel"]
        for zr, rr_, rt_ in ((zs + 0.18 * rz, 0.97 * R, 0.05 + 0.008 * s2), (zs + 0.62 * rz, 0.8 * R, 0.04 + 0.006 * s2)):
            g.torus((0, 0, zr), "z", rr_, rt_, ma, n=72, m=10, what="anneau")
            g.torus((0, 0, zr), "z", rr_ - rt_ * 0.9, rt_ * 0.35, lis or M["emit_soft"], n=72, m=6, what="doublure")
            nk = max(8, int(TAU * rr_ / 0.3))
            for k in range(nk):
                a = TAU * (k + 0.25) / nk
                d = V((math.cos(a), math.sin(a), 0.0))
                R3 = Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()
                g.box(d * rr_ + V((0, 0, zr)), (0.05, rt_ * 2.4, rt_ * 2.4), m2, "hard", R=R3, what="bride")
            u = (zr - zs) / hb
            if u < 0.98:
                rc = 0.6 * R * math.cos(math.asin(u))
                for k in range(6):
                    a = TAU * (k + 0.25) / 6
                    d = V((math.cos(a), math.sin(a), 0.0))
                    L = rr_ - rt_ - rc + 0.02
                    R3 = Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()
                    g.box(d * (rc + L / 2 - 0.01) + V((0, 0, zr)), (0.04, L, 0.04), m2, "hard", R=R3, what="bras_anneau")
        _boucle(g, P, ph_de(0.02), 1.02, 0.024, m2)
        return P, N
    if f == "coque":
        # coque lisse (super-ellipse) : lignes de panneaux affleurantes, visière sombre, aileron dorsal
        _revolve(g, c, m1, "smooth", nth=64, nt=24)
        for k in range(6):
            th = TAU * (k + 0.5) / 6
            pts = [P(th, ph_de(0.04 + 0.8 * i / 16), 1.002) for i in range(17)]
            g.tube(pts, 0.006, M["seam"], n=6, what="ligne_panneau")
        _boucle(g, P, ph_de(0.45), 1.002, 0.006, M["seam"], what="ligne_panneau")
        _boucle(g, P, ph_de(0.0), 1.01, 0.02, m2)
        # visière : bande sombre sur l'avant de la coque
        na, nv = 14, 2
        th0, th1 = math.radians(52), math.radians(128)
        tv0, tv1 = 0.2, 0.34
        vs, fs = [], []
        for i in range(na + 1):
            for j in range(nv + 1):
                vs.append(tuple(P(th0 + (th1 - th0) * i / na, ph_de(tv0 + (tv1 - tv0) * j / nv), 1.012)))
        for i in range(na):
            for j in range(nv):
                a = i * (nv + 1) + j
                fs.append((a, a + nv + 1, a + nv + 2, a + 1))
        g._add(M["glass_dk"], "smooth", vs, fs, "visiere")
        if lis is not None:
            _boucle(g, lambda th, ph, k=1.0: P(th, ph, k), ph_de(0.17), 1.01, 0.008, lis, what="filet_lum")
        # aileron dorsal (x = 0) entre le tourelleau et la trappe
        hf = 0.1 + 0.03 * s2
        ya, yb = -0.5 * R, 0.25 * R
        nf = 10
        vs, fs = [], []
        for i in range(nf + 1):
            y = ya + (yb - ya) * i / nf
            zb = z_coque(c, 0.0, y) - 0.02
            zt = zb + 0.02 + hf * (1.0 - i / nf) ** 0.7
            for x in (-0.016, 0.016):
                vs.append((x, y, zb))
                vs.append((x, y, zt))
        for i in range(nf):
            a = 4 * i
            b = 4 * (i + 1)
            fs += [(a, b, b + 1, a + 1), (a + 2, a + 3, b + 3, b + 2), (a + 1, b + 1, b + 3, a + 3),
                   (a, a + 2, b + 2, b)]
        fs += [(0, 1, 3, 2), (4 * nf, 4 * nf + 2, 4 * nf + 3, 4 * nf + 1)]
        g._add(m2, "hard", vs, fs, "aileron")
        return P, N
    raise ValueError(f)


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
        if c.formes["forme_jupe"] is None:
            jupe(g, R, z0 + 0.07, zs, [capot(c, "olive"), capot(c, "olive"), M["steel_dk"]],
                 max(c.T["jupe_bandes"], int(TAU * R / 0.26)), M[c.hab["jupe_cerclage"]])
        else:
            # forme de jupe : hasard local, puis la jupe d'origine à blanc (même tirage pour la suite de la tête)
            with _hasard_local(g, 7600 + c.side):
                _jupe_forme(g, c, R, z0 + 0.07, zs, [capot(c, "olive"), capot(c, "olive"), M["steel_dk"]],
                            max(c.T["jupe_bandes"], int(TAU * R / 0.26)), M[c.hab["jupe_cerclage"]])
            with _a_blanc(g):
                jupe(g, R, z0 + 0.07, zs, [capot(c, "olive"), capot(c, "olive"), M["steel_dk"]],
                     max(c.T["jupe_bandes"], int(TAU * R / 0.26)), M[c.hab["jupe_cerclage"]])
        if c.formes["forme_coupole"] is None:
            c.Pf, c.Nf = P2.dome_hull(g, (0, 0, zs), R, R * 1.06, rz, capot(c, "olive"), M,
                                      seams=max(c.T["coupole_coutures"], int(TAU * R / 0.3)), band_mat=M["steel_dk"],
                                      ring_seams=c.T["rangs"])
        else:
            c.prof = SIL.coupole(c.formes["forme_coupole"], R, rz)
            with _hasard_local(g, 7700 + c.side):
                c.Pf, c.Nf = _coupole_forme(g, c)
            with _a_blanc(g):
                P2.dome_hull(g, (0, 0, zs), R, R * 1.06, rz, capot(c, "olive"), M,
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
    if getattr(c, "bouchon", False):
        bouchon_arriere(g, c)


def bouchon_arriere(g, c):
    """BOUCHON ARRIÈRE (lot A2, 24/10) : vue de dos (poses S, SE, SO), une fente entre la coupole, la nacelle, le bras de
    tourillon et l'arceau laissait voir le sol aux âges 4 à 7 (rose d'A1 : trous enfermés de 42 à 249 px hr). Deux
    caissons sombres (matière « seam », sans rivet ni hasard) ferment le coin arrière de chaque côté, entre la nacelle et
    le bras, sous le haut de la nacelle. Posé EN DERNIER (aucun tirage ni aucune pièce d'avant ne change) et SEULEMENT
    quand piece.bouchon() le demande (secteur arrière d20 à d44) : jamais dans les poses validées N et E (d00, d16), qui
    restent identiques octet à octet (preuve : identite.py et construction.py --forte, lot A2).
    LIMITE MESURÉE (lot A2, bouchon_visibilite.py, rendus rapides à 16 échantillons) : ce bouchon N'EST PAS caché en N
    et en E. Posé de force (FO_BOUCHON=force), il change de 1 073 à 3 583 px de la couche principale hr (coin arrière,
    vu de dos par la caméra). Une forme plus mince (tôle au dos du bras, jusqu'à 0,10 au-dessus de la nacelle) changeait
    encore 720 à 1 954 px et laissait des trous de 38 à 39 px à l'âge 7 : refusée. Aucune pièce qui ferme la fente vue
    de dos ne peut être cachée vue de face (même région de l'espace, vue des deux côtés). Pour les 64 directions (A3) :
    choisir le secteur où le poser, et juger le saut à sa frontière."""
    M = g.M
    H = c.H
    zs = H["zs"]
    bx, yb0, yb1, ztop, yc = c.nac
    y_bras = H["recv"][0] - 0.34          # arrière du caisson de bras (bras(), deuxième hull)
    x_in = bx * 0.8                        # rentré sous le flanc de la nacelle
    x_out = H["gx"] - H["wr"] * 0.5        # face intérieure de la culasse
    z0, z1 = zs - 0.2, ztop - 0.02
    y0, y1 = yb0 + 0.02, y_bras + 0.04
    for sx in (-1, 1):
        g.box((sx * (x_in + x_out) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x_out - x_in, y1 - y0, z1 - z0), M["seam"],
              "flat", what="bouchon_arriere")


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


def canon_effile(g, x, y0, z, L, nb, rb, rr, jaquette=0.42, bague_mat="steel_dk", conv=0.6, frein=(0.64, 0.8),
                 guidon=True, mat=None, segments=12):
    """CANON EFFILÉ (passe 5, troisième temps ; proposition de lignée contre la « cheminée » de la pose N, règle
    d'or 7). En pose N, un tube horizontal dirigé vers le nord se projette EXACTEMENT comme un tube vertical (caméra à
    45° : y et z valent 0,707 chacun à l'écran) ; sa bouche regarde ailleurs que la caméra et ne se voit jamais. Ce qui
    sépare un canon d'une cheminée doit donc se lire DE DOS :
      1. un FAISCEAU QUI CONVERGE : tubes inclinés vers l'axe (rayon du faisceau rr à la culasse, conv × rr à la bouche)
         et légèrement amincis, âme conique : la silhouette va en POINTE vers la bouche (une cheminée garde sa largeur
         ou s'évase à son chapeau) ;
      2. une JAQUETTE CONIQUE perforée sur 0,35 de la longueur au plus, UNE seule bague (à la culasse) : aucune suite de
         bagues régulières (les bagues lues comme les viroles d'un conduit) ;
      3. un MANCHON À FENTES au ras du faisceau convergé (jamais plus large), RECULÉ entre 0,64 et 0,8 de la longueur :
         il tient les tubes (il fait le collier) ; fentes latérales visibles en pose E, côtés pleins en pose N ;
      4. le DERNIER CINQUIÈME des tubes NU, toujours convergent, POINTES ÉCLAIRÉES : le haut du canon en pose N est une
         gerbe de tubes fins qui se resserre sur des points lumineux, jamais un bloc sombre (premier essai, frein au bout :
         le bloc sombre se lisait encore comme un chapeau, constaté sur le témoin 4×4 au zoom 6) ;
      5. un GUIDON (lame de visée) dressé sur le manchon : signe d'arme en pose E.
    Rend les positions (x, z) des tubes à la culasse. conv : convergence (0,5 à 0,8) ; frein : (début, fin) du manchon en
    part de la longueur (None : aucun manchon, un collier sombre à 0,6) ; guidon : False pour le retirer ; jaquette :
    part de la longueur (au plus 0,35 ici : la gerbe de tubes doit dominer)."""
    M = g.M
    mat = mat or M["gun"]
    pos = []
    tl = 0.05 + 0.02 * L
    for i in range(nb):
        a = 0.3 + TAU * i / nb
        ca, sa = math.cos(a), math.sin(a)
        p0 = V((x + rr * ca, y0, z + rr * sa))
        p1 = V((x + rr * conv * ca, y0 + L, z + rr * conv * sa))
        d = p1 - p0
        g.cyl((p0 + p1) / 2, d, rb, d.length, mat, n=segments, r2=rb * 0.86, what="canon")
        dn = d.normalized()
        g.cyl(p1 + dn * 0.002, dn, rb * 0.55, 0.008, M["void"], n=10, style="flat", what="bouche")
        g.tube_shell(p1 - dn * (tl / 2), dn, rb * 0.86 + 0.012, rb * 0.86 - 0.006, tl, M["emit"], n=segments,
                     what="pointe_lum")
        pos.append((p0.x, p0.z))
    core = max(rr - rb * 0.55, rr * 0.55)
    g.cyl((x, y0 + L * 0.48, z), "y", core, L * 0.94, M["steel_dk"], n=14, r2=core * conv, what="ame")
    g.cyl((x, y0 + 0.02, z), "y", rr + rb + 0.01, 0.04, M["steel_dk"], n=24, style="soft", what="plaque_culasse")

    def r_fx(f_):
        """rayon extérieur du faisceau à la fraction f_ de la longueur"""
        return rr * (1 + (conv - 1) * f_) + rb * (1 - 0.14 * f_)
    if not frein:
        # sans manchon : un seul collier sombre, à 0,6 de la longueur
        yy = y0 + 0.6 * L
        g.tube_shell((x, yy, z), "y", r_fx(0.6) + 0.014, core * 0.8, 0.035, M[bague_mat], n=28, what="collier")
        F.bolts_ring(g, (x, yy, z), (0, 1, 0), r_fx(0.6) + 0.014, 6, M["rivet"], r=0.013, phase=0.5, skip_down=-0.3)
    # jaquette conique perforée (0,35 de la longueur au plus), une seule bague, à la culasse
    Lj = L * min(jaquette, JAQUETTE_MAX, 0.35)
    if Lj > 0.05:
        rs0 = rr + rb + 0.028
        rs1 = rr * (1 + (conv - 1) * Lj / L) + rb + 0.018
        g.cyl((x, y0 + Lj / 2, z), "y", rs0, Lj, M["gun"], n=28, r2=rs1, style="smooth", what="jaquette")
        nh_ax = max(2, int((Lj - 0.1) / 0.06))
        for i in range(nh_ax):
            f_ = (0.07 + (Lj - 0.14) * (i + 0.5) / nh_ax) / Lj
            rsi = rs0 + (rs1 - rs0) * f_
            nh_ang = max(8, int(TAU * rsi / 0.07))
            for j in range(nh_ang):
                a = TAU * j / nh_ang + (0.5 * TAU / nh_ang if i % 2 else 0.0)
                dd = V((math.cos(a), 0.0, math.sin(a)))
                if dd.z < -0.45:
                    continue
                g.cyl(V((x, y0 + f_ * Lj, z)) + dd * (rsi + 0.002), dd, 0.016, 0.006, M["void"], n=6, style="flat",
                      what="trou")
        g.tube_shell((x, y0 + 0.03, z), "y", rs0 + 0.022, rs0 - 0.01, 0.05, M[bague_mat], n=28, what="bague")
        F.bolts_ring(g, (x, y0 + 0.03, z), (0, 1, 0), rs0 + 0.024, 6, M["rivet"], r=0.015, phase=0.2, skip_down=-0.3)
    # manchon à fentes reculé, au ras du faisceau convergé : le dernier cinquième des tubes reste nu
    if frein:
        f0, f1 = frein
        yf0, yf1 = y0 + f0 * L, y0 + f1 * L
        lf = yf1 - yf0
        rf0, rf1 = r_fx(f0) + 0.006, r_fx(f1) + 0.006
        g.cyl((x, (yf0 + yf1) / 2, z), "y", rf0, lf, M[bague_mat], n=20, r2=rf1, style="soft", what="frein")
        rm = (rf0 + rf1) / 2
        for sx_ in (-1, 1):
            for k in range(3):
                yk = yf0 + lf * (0.22 + 0.28 * k)
                g.box((x + sx_ * (rm + 0.001), yk, z), (0.006, lf * 0.14, rm * 1.1), M["void"], "flat", what="fente")
        F.bolts_ring(g, (x, yf0 + 0.012, z), (0, 1, 0), rf0, 6, M["rivet"], r=0.012, phase=0.5, skip_down=-0.3)
        if guidon:
            hg = 0.035 + 0.012 * L
            g.box((x, yf0 + lf * 0.6, z + rm + hg / 2 - 0.004), (0.014, lf * 0.45, hg), M["steel"], "hard",
                  what="guidon")
    return pos


def canon_lignee(g, c, x, sx, recv_mats=("ochre", "olive"), jaquette=0.42, frein=True, frein_mat="steel",
                 bague_mat="steel_dk", masque_mats=("ochre", "olive"), alim=True,
                 alim_mats=("olive", "ochre"), effile=False):
    """Canon de lignée COMPLET, corrigé pour la pose N (règle d'or 7, passe 5) : culasse blindée, moteur arrière
    bobiné, rosette de tubes séparés en ACIER NU CLAIR, jaquette perforée sur la moitié arrière au plus, puis la
    COURONNE DE BOUCHE (couronne_bouche) : collerette sombre au ras du faisceau, JAMAIS plus large que lui, devant
    laquelle les tubes dépassent, pointes éclairées (rosette vue en bout). Le frein EN BLOC deux fois plus large de la
    passe 4 (« T » plat) est SUPPRIMÉ : les juges de la passe 4 l'ont lu comme le chapeau d'une cheminée (pose N).
    frein : True (défaut) = couronne de bouche ; False = tubes nus, pointes éclairées. frein_mat : ignoré (gardé pour
    les appels de la passe 4). Bagues sombres (aucune bague claire horizontale), caisse d'alimentation au pied qui
    déborde sur le côté extérieur (alim_mats : ses matières, passe 5), masque de canon. Une époque peut l'appeler tel
    quel et y AJOUTER son organe. effile (passe 5, troisième temps) : True ou dict d'options de canon_effile() :
    faisceau convergent, jaquette conique à une bague, frein à fentes et guidon à la place de la rosette, de la
    jaquette et de la couronne de bouche (défaut False : canon d'origine, empreinte identique)."""
    M = g.M
    H = c.H
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    L, nb, rb, rr = H["L"], H["nb"], H["rb"], H["rr"]
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=[M[k] for k in recv_mats])
    moteur_lignee(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6)
    if effile:
        pos = canon_effile(g, x, y1, zg, L, nb, rb, rr, jaquette=jaquette, bague_mat=bague_mat,
                           **(effile if isinstance(effile, dict) else {}))
    else:
        pos = rosette(g, x, y1, zg, L, nb, rb, rr, colliers=(0.62, 0.86), collier_mat=M[bague_mat], bouts=True)
    rs = rr + rb + 0.028
    Lj = L * min(jaquette, JAQUETTE_MAX)
    if Lj > 0.05 and not effile:
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
    if frein and not effile:
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
