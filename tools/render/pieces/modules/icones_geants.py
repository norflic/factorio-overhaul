"""ICÔNES DES MODULES DES GÉANTS (lot DESIGN-MODULES, 5/11) : 2 types x 3 paliers, même rendu 2D que les modules validés.

Même chaîne que tools/render/pieces/modules/icones.py (lots MOD-V et MOD-3, validés par le DC), dont ce script IMPORTE les primitives
sans les modifier (champs de distance signée à 512 px, relief éclairé du nord-ouest, réduction en lumière linéaire, plaque du palier
au pixel à 32 px) : `icones.py --check` reste vert. Aucun hasard : deux passages donnent les mêmes octets (`--check`).

TYPES (le type se lit à la SILHOUETTE et à la COULEUR, distinctes du chevron bleu, de l'engrenage orange et de la feuille verte) :
  - portée    : ÉVENTAIL DE VISÉE violet, un émetteur au coin bas gauche et trois arcs qui s'ouvrent vers le haut droit, l'arc extérieur
                gradué (l'échelle d'un télémètre) ;
  - puissance : ÉCLAT D'IMPACT cramoisi, étoile à huit pointes (quatre longues, quatre courtes), cœur chauffé à blanc, fissures
                incandescentes le long des pointes.
MONTÉE DU PALIER (la forme change, pas seulement la couleur, critère D1) :
  - portée    : I un arc allumé, II deux, III trois et des étoiles sur l'arc extérieur ;
  - puissance : I fissures des quatre longues pointes, II aussi des quatre courtes, III onde de choc (quatre arcs autour de l'étoile)
                et étoiles ;
  - chiffre romain gravé en haut à gauche (même plaque que les modules), éclat du cœur et halo croissants, teinte du champ.

Sorties (dossier --out, par défaut graphics/modules-geants du mod) :
  <objet>.png             icône d'objet 64 px + 3 mipmaps (bande 120 x 64), icon_size 64, icon_mipmaps 4 ;
  equipement/<objet>.png  image dans la grille (2 x 2 cases) : 64 px, et hr-<objet>.png 128 px (scale 0,5) ;
  tech/<techno>.png       icône de technologie 256 px + 3 mipmaps (bande 480 x 256) ;
  MANIFEST.json, icons.lua (relu par prototypes/experimentaux_modules.lua).
Usage :
  py -3.9 tools/render/pieces/modules/icones_geants.py              # écrit graphics/modules-geants
  py -3.9 tools/render/pieces/modules/icones_geants.py --check      # régénère en mémoire, compare (code 1 si écart)
  py -3.9 tools/render/pieces/modules/icones_geants.py --planche <png> --sans-ecrire
"""

import argparse
import hashlib
import io
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import icones as I  # noqa: E402  (primitives des modules validés : lues, jamais modifiées)

MOD = I.MOD
N, U = I.N, I.U
X, Y = I.X, I.Y
VERSION = 1
TYPES = ("portee", "puissance")
PALIERS = (1, 2, 3)
AGE = {1: 10, 2: 12, 3: 14}   # shared/robots/experimentaux_modules.lua, M.TIERS (contrôlé par verifier_donnees)
PREFIX = "fo-xp-module-"
TECH_PREFIX = "fo-xp-modules-"


def nom_objet(t, k):
    return "%s%s-%d" % (PREFIX, t, k)


def nom_techno(t, k):
    return "%s%s-%d" % (TECH_PREFIX, t, k)


def verifier_donnees():
    """Relit shared/robots/experimentaux_modules.lua : mêmes types, mêmes paliers, mêmes âges, mêmes préfixes."""
    import re
    src = open(os.path.join(MOD, "shared", "robots", "experimentaux_modules.lua"), encoding="utf-8").read()
    pb = []
    if ('M.PREFIX = "%s"' % PREFIX) not in src:
        pb.append("préfixe des objets")
    if ('M.TECH_PREFIX = "%s"' % TECH_PREFIX) not in src:
        pb.append("préfixe des technologies")
    for k, a in AGE.items():
        if not re.search(r"\{\s*tier = %d, age = %d," % (k, a), src):
            pb.append("palier %d à l'âge %d" % (k, a))
    for t in TYPES:
        for k in PALIERS:
            if not re.search(r'\{\s*type = "%s", tier = %d, bonus = \d+' % (t, k), src):
                pb.append("module %s %d" % (t, k))
    if pb:
        raise SystemExit("[FO-XP-MODULES-ICONES] données : " + " ; ".join(pb))
    return True


# ------------------------------------------------------------------------------------------------------------------
# Couleurs (linéaires) : corps du type, plus sombre au palier I ; lumière du type ; fond de la case dans la grille
# ------------------------------------------------------------------------------------------------------------------
COULEURS = {
    "portee": dict(champ=(0.50, 0.19, 1.0), cadre=(0.075, 0.022, 0.21), logement=(0.022, 0.006, 0.070),
                   lumiere=(0.86, 0.66, 1.0), lumiere2=(0.95, 0.88, 1.0)),
    "puissance": dict(champ=(0.95, 0.018, 0.028), cadre=(0.21, 0.008, 0.012), logement=(0.065, 0.004, 0.006),
                      lumiere=(1.0, 0.62, 0.22), lumiere2=(1.0, 0.88, 0.62)),
}
# fond de la case dans la grille d'équipement (sRGB 0-1, alpha prémultiplié par le moteur : on donne la couleur nue)
FOND_GRILLE = {"portee": (0.32, 0.16, 0.55, 0.45), "puissance": (0.55, 0.12, 0.12, 0.45)}
BORD_GRILLE = {"portee": (0.62, 0.40, 1.0), "puissance": (1.0, 0.45, 0.30)}


def eclat(k):
    return (k - 1) / 2.0


def roles(t, k):
    c = COULEURS[t]
    e = eclat(k)
    montee = 0.74 + 0.26 * e
    return dict(champ=dict(rgb=tuple(v * montee for v in c["champ"]), rough=0.34, met=0.18),
                cadre=dict(rgb=c["cadre"], rough=0.40, met=0.35),
                logement=dict(rgb=c["logement"], rough=0.45, met=0.40),
                plaque=dict(rgb=c["logement"], rough=0.45, met=0.40),
                lumiere=tuple(c["lumiere"]), lumiere2=tuple(c["lumiere2"]))


# ------------------------------------------------------------------------------------------------------------------
# Géométrie (unités de 0 à 64, y vers le bas)
# ------------------------------------------------------------------------------------------------------------------
def _arc(cx, cy, r, a0, a1, n=48):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def _rot(px, py, cx, cy, a_deg):
    a = math.radians(a_deg)
    dx, dy = px - cx, py - cy
    return (cx + dx * math.cos(a) - dy * math.sin(a), cy + dx * math.sin(a) + dy * math.cos(a))


def _union(sds):
    out = None
    for s in sds:
        out = s if out is None else np.minimum(out, s)
    return out


def geo_portee_viseur(k):
    """VISEUR DE VERROUILLAGE : la lentille d'une optique vue de face, verre violet profond dont la lueur monte vers le centre, bague
    épaisse, réticule à montants (« duplex »). Le palier se lit à la forme :
    I : réticule simple ; II : points de mesure, anneau de distance et deux crochets de verrouillage (en bas) ; III : trois crochets hors
    de la bague et index allumés (le cercle de verrouillage du tir en jeu).
    Jets écartés : « wifi » (générique), « rapporteur » (banal, bruit à 32 px), « anneau percé » (lu ♂), « optique à tourelles » (lue
    chronomètre), bague crantée (lue engrenage, le module de productivité)."""
    cx, cy = 32.5, 33.0
    R_ext, R_len = 24.0, 18.0
    bague = I.sd_cercle(cx, cy, R_ext)
    pieces = [bague]
    dessus = []
    # crochets de verrouillage : II deux (en bas), III trois (jamais en haut à gauche : la plaque du palier y est)
    coins = {1: (), 2: ((1, 1), (-1, 1)), 3: ((1, 1), (-1, 1), (1, -1))}[k]
    if coins:
        crochets = []
        for sx, sy in coins:
            ox, oy = cx + sx * 27.5, cy + sy * 27.5
            crochets.append(I.sd_segment(ox, oy, ox - sx * 9.0, oy, 2.0))
            crochets.append(I.sd_segment(ox, oy, ox, oy - sy * 9.0, 2.0))
        cro = _union(crochets)
        pieces.append(cro)
        dessus.append(cro)
    sil = _union(pieces)
    lentille = I.sd_cercle(cx, cy, R_len)
    champ = np.maximum(bague + 2.2, -(lentille + 0.3))
    logements, coeurs = [], []
    logements.append(lentille)
    coeurs.append((lentille + 0.6, True, 14.0))          # verre : lueur qui monte vers le centre
    ret = []
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        ret.append(I.sd_segment(cx + dx * (R_len + 0.5), cy + dy * (R_len + 0.5), cx + dx * 7.0, cy + dy * 7.0, 1.7))
        ret.append(I.sd_segment(cx + dx * 7.0, cy + dy * 7.0, cx + dx * 1.8, cy + dy * 1.8, 0.6))
    if k >= 2:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            for r in (3.8, 5.4):
                ret.append(I.sd_cercle(cx + dx * r, cy + dy * r, 0.8))
        ret.append(np.abs(I.sd_cercle(cx, cy, 12.0)) - 0.5)
    reticule = _union(ret)
    coeurs.append((I.sd_cercle(cx, cy, 1.3), True))
    # index gravés dans la bague (entre les montants), allumés au palier III
    for a_deg in (30, 60, 120, 150, 210, 240, 300, 330):
        a = math.radians(a_deg)
        p0 = (cx + (R_len + 1.3) * math.cos(a), cy + (R_len + 1.3) * math.sin(a))
        p1 = (cx + (R_ext - 1.6) * math.cos(a), cy + (R_ext - 1.6) * math.sin(a))
        logements.append(I.sd_segment(p0[0], p0[1], p1[0], p1[1], 0.95))
        coeurs.append((I.sd_segment(p0[0], p0[1], p1[0], p1[1], 0.5), k == 3))
    return dict(sil=sil, champ=champ, logements=logements, coeurs=coeurs, grad=None, centre=(cx, cy), slots=[], dessus=dessus,
                reticule=reticule)


def geo_portee_lunette(k):
    """LUNETTE DE TIR DE PROFIL : tube long et fin, objectif et oculaire évasés, tourelle de réglage, lentille allumée ; elle S'ALLONGE
    avec le palier. I : courte ; II : plus longue, seconde tourelle (voyant), rail ; III : télémètre laser et son faisceau en tirets."""
    p0x, p0y = 4.5, 57.5
    a = math.radians(-40.0)
    ux, uy = math.cos(a), math.sin(a)
    tx, ty = uy, -ux

    def W(s, v):
        return (p0x + ux * s + tx * v, p0y + uy * s + ty * v)

    def boite(s0, s1, v0, v1, r=0.0):
        return I.sd_poly([W(s0, v0), W(s1, v0), W(s1, v1), W(s0, v1)]) - r

    L = {1: 52.0, 2: 58.0, 3: 60.0}[k]
    h_tube, h_ocu, h_obj = 3.6, 6.2, 7.6
    oculaire = I.sd_poly([W(0.0, -h_ocu), W(7.0, -h_ocu), W(14.0, -h_tube), W(14.0, h_tube), W(7.0, h_ocu), W(0.0, h_ocu)]) - 0.9
    tube = boite(12.0, L - 13.0, -h_tube, h_tube, 0.6)
    evase = I.sd_poly([W(L - 17.0, -h_tube), W(L - 9.0, -h_obj), W(L, -h_obj), W(L, h_obj), W(L - 9.0, h_obj), W(L - 17.0, h_tube)]) - 0.9
    s_t = L * 0.44
    tourelle = boite(s_t - 3.4, s_t + 3.4, h_tube - 0.5, h_tube + 5.6, 1.0)
    pieces = [oculaire, tube, evase, tourelle]
    dessus = [tourelle]
    voyants = []
    if k >= 2:
        rail = boite(L * 0.25, L * 0.62, -h_tube - 3.6, -h_tube - 0.8, 0.6)
        pieces.append(rail)
        voyants.append(W(s_t, 0.0))
    if k == 3:
        f0, f1 = W(L, 0.0), W(L + 30.0, 0.0)
        faisceau = I.sd_segment(f0[0], f0[1], f1[0], f1[1], 1.8)
        pieces.append(faisceau)
    sil = _union(pieces)
    champ = _union([oculaire + 1.9, tube + 1.3, evase + 2.0])
    logements, coeurs = [], []
    l0, l1 = W(L - 1.6, -h_obj + 1.6), W(L - 1.6, h_obj - 1.6)
    logements.append(I.sd_segment(l0[0], l0[1], l1[0], l1[1], 2.0))
    coeurs.append((I.sd_segment(l0[0], l0[1], l1[0], l1[1], 1.2), True))
    for vx, vy in voyants:
        logements.append(I.sd_cercle(vx, vy, 2.1))
        coeurs.append((I.sd_cercle(vx, vy, 1.2), True))
    r0, r1 = W(15.0, 0.0), W(L - 18.0, 0.0)
    logements.append(I.sd_segment(r0[0], r0[1], r1[0], r1[1], 1.2))
    coeurs.append((I.sd_segment(r0[0], r0[1], r1[0], r1[1], 0.55), True))
    if k == 3:
        s = 1.0
        while s < 30.0:
            q0, q1 = W(L + s, 0.0), W(L + min(s + 5.0, 30.0), 0.0)
            coeurs.append((I.sd_segment(q0[0], q0[1], q1[0], q1[1], 1.25), True))
            s += 8.0
    return dict(sil=sil, champ=champ, logements=logements, coeurs=coeurs, grad=None, centre=(p0x, p0y), slots=[], dessus=dessus)


PORTEE_VARIANTES = {"viseur": geo_portee_viseur, "lunette": geo_portee_lunette}
PORTEE_VARIANTE = "viseur"


def geo_portee(k):
    return PORTEE_VARIANTES[PORTEE_VARIANTE](k)


def _bezier(p0, p1, courbe, n=10):
    """Courbe douce de p0 à p1 (quadratique), bombée de `courbe` unités vers la gauche du trajet."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(dx, dy)
    nx, ny = -dy / L, dx / L
    c = ((p0[0] + p1[0]) / 2 + nx * courbe, (p0[1] + p1[1]) / 2 + ny * courbe)
    out = []
    for i in range(n + 1):
        t = i / float(n)
        out.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t * t * p1[0],
                    (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t * t * p1[1]))
    return out


def _quad(cx, cy, r, a_deg, allonge):
    """Débris irrégulier : quadrilatère tourné de a_deg, allongé de `allonge`."""
    pts = []
    for k, (ang, rr) in enumerate(((0, 1.0), (100, 0.7), (190, allonge), (275, 0.55))):
        a = math.radians(a_deg + ang)
        pts.append((cx + r * rr * math.cos(a), cy + r * rr * math.sin(a)))
    return pts


def geo_puissance(k):
    """CŒUR DE RUPTURE (3e jet, après la 2e critique du 5/11) : un CRISTAL cramoisi taillé, hexagone allongé à deux faces (arête au milieu,
    face droite plus claire), qui se fend puis éclate.
    I : cristal entier, une fissure courbe incandescente ; II : trois fissures courbes jusqu'aux bords, une épaule ébréchée (encoche, aucun
    éclat détaché) ; III : le cristal éclate en trois morceaux inégaux écartés, cœur chauffé à blanc dans les failles, débris irréguliers.
    Jets écartés : étoile à 8 pointes (« rose des vents », anneau lu « viseur ») ; losange (lu panneau de danger, carreau de carte ; son X
    blanc au palier II lu « supprimer », ses 4 pointes détachées lues croix de direction ; son palier III lu insecte)."""
    cx, cy = 32.0, 33.5
    T, TR, BR, B, BL, TL = (32.0, 3.5), (51.5, 17.0), (51.5, 49.5), (32.0, 62.5), (12.5, 49.5), (12.5, 17.0)
    hexa = [T, TR, BR, B, BL, TL]
    C0 = (cx, cy)
    face_droite = np.maximum(I.sd_poly([T, TR, BR, B]), -(X - 32.0))     # moitié droite, vers la lumière
    logements, coeurs = [], []
    if k == 1:
        corps = I.sd_poly(hexa) - 0.8
        morceaux = [corps]
        champ = corps + 2.7
        f1 = _bezier(C0, (45.5, 14.0), 3.5)
        f1b = _bezier(f1[5], (47.5, 30.0), -2.0, 6)
        for pts, w in ((f1, 1.0), (f1b, 0.8)):
            logements.append(I.sd_polyligne(pts, w + 1.0))
            coeurs.append((I.sd_polyligne(pts, w), True))
        noyau = None
    elif k == 2:
        # épaule haute droite ébréchée : encoche taillée dans la silhouette (pas d'éclat posé à côté)
        encoche = I.sd_poly([(44.0, 9.0), (54.0, 15.0), (52.0, 25.0), (45.5, 17.5)])
        corps = np.maximum(I.sd_poly(hexa) - 0.8, -encoche)
        morceaux = [corps]
        champ = np.maximum(I.sd_poly(hexa) + 1.9, -(encoche - 2.7))
        fiss = [_bezier(C0, (46.0, 17.5), 3.0), _bezier(C0, (17.0, 50.0), -4.0), _bezier(C0, (12.5, 30.0), 2.5),
                _bezier(C0, (44.0, 56.0), -2.5)]
        for j, pts in enumerate(fiss):
            w = 1.05 if j < 2 else 0.8
            logements.append(I.sd_polyligne(pts, w + 1.0))
            coeurs.append((I.sd_polyligne(pts, w), True))
        noyau = I.sd_cercle(cx, cy, 3.6)
        logements.append(noyau + 1.0)
        coeurs.append((noyau, True))
    else:
        # trois failles inégales (angles irréguliers : ni « Y », ni croix) ; P2 sur l'arête haute droite, P1 et P3 sur les flancs
        P1, P2, P3 = (12.5, 41.0), (41.0, 9.8), (51.5, 44.0)
        c1, c2, c3 = _bezier(C0, P1, 3.5), _bezier(C0, P2, -3.0), _bezier(C0, P3, 2.5)
        haut = [C0] + c1[1:] + [TL, T] + list(reversed(c2))[:-1]
        gauche = [C0] + c1[1:] + [BL, B, BR] + list(reversed(c3))[:-1]
        droite = [C0] + c3[1:] + [TR] + list(reversed(c2))[:-1]
        morceaux, champ_l = [], []
        for poly, (dx, dy) in ((haut, (-3.2, -3.0)), (gauche, (-1.0, 3.6)), (droite, (4.4, -1.2))):
            q = I.sd_poly([(px + dx, py + dy) for px, py in poly]) - 0.5
            morceaux.append(q)
            champ_l.append(q + 2.3)
        noyau = I.sd_cercle(cx, cy, 6.6)
        failles = _union([I.sd_polyligne(c, 2.0) for c in (c1, c2, c3)])
        morceaux += [noyau, failles]
        for d in (_quad(58.5, 52.0, 4.2, 20, 1.5), _quad(52.0, 3.8, 3.4, 140, 1.2), _quad(5.0, 55.0, 3.0, 250, 1.6),
                  _quad(58.0, 26.0, 2.6, 300, 1.3), _quad(26.0, 62.0, 2.2, 60, 1.4)):
            q = I.sd_poly(d) - 0.25
            morceaux.append(q)
            champ_l.append(q + 0.8)
        champ = _union(champ_l)
        logements.append(noyau + 1.1)
        coeurs.append((noyau, True))
        coeurs.append((failles + 0.7, True))
        for c in (c1, c2, c3):
            coeurs.append((I.sd_polyligne(c, 1.0), True))
    sil = _union(morceaux)
    return dict(sil=sil, champ=champ, logements=logements, coeurs=coeurs, grad=None, centre=(cx, cy), slots=[],
                faces=[(face_droite, 1.28)], arete=I.sd_segment(32.0, 5.5, 32.0, 60.5, 0.5) if k < 3 else None, noyau=noyau)


GEO = {"portee": geo_portee, "puissance": geo_puissance}
_CACHE = {}


def geo(t, k):
    cle = (t, k, PORTEE_VARIANTE if t == "portee" else "")
    if cle not in _CACHE:
        _CACHE[cle] = GEO[t](k)
    return _CACHE[cle]


# ------------------------------------------------------------------------------------------------------------------
# Rendu (même éclairage que icones.rendre_art)
# ------------------------------------------------------------------------------------------------------------------
def rendre_art(t, k, avec_plaque_vecteur=False):
    g = geo(t, k)
    R = roles(t, k)
    e = eclat(k)
    lum = np.asarray(R["lumiere"], float)
    lum2 = np.asarray(R["lumiere2"], float)

    a_sil = I.couv(g["sil"])
    a_champ = I.couv(g["champ"])

    H = 3.0 * I.profil(g["sil"], 2.2)
    H += 0.9 * I.profil(g["champ"], 1.2) * a_champ

    alb = np.zeros((N, N, 3))
    rough = np.zeros((N, N))
    met = np.zeros((N, N))

    def poser(a, mat):
        nonlocal alb, rough, met
        alb = I._melange(alb, mat["rgb"], a)
        rough = rough * (1 - a) + mat["rough"] * a
        met = met * (1 - a) + mat["met"] * a

    poser(a_sil, R["cadre"])
    poser(a_champ, R["champ"])

    if g["grad"] is not None:
        a_g = I.couv(g["grad"]) * a_champ
        poser(a_g, R["logement"])
        H -= 0.9 * a_g
    for sd in g.get("dessus") or []:
        # pièces posées PAR-DESSUS (lances qui traversent l'anneau) : relief plus haut, cadre redessiné autour
        a_d = I.couv(sd)
        H = H * (1 - a_d) + (3.0 * I.profil(sd, 2.0) + 2.4) * a_d
        poser(a_d, R["cadre"])
        a_dc = I.couv(sd + 1.9)
        poser(a_dc, R["champ"])
        H += 0.9 * I.profil(sd + 1.9, 1.2) * a_dc
    for sd, mult in g.get("faces") or []:
        # face du cristal tournée vers la lumière : plus claire, plus lisse
        a_f = I.couv(sd) * a_champ
        poser(a_f, dict(rgb=tuple(min(1.0, v * mult + 0.01) for v in R["champ"]["rgb"]), rough=0.26, met=0.14))
    if g.get("arete") is not None:
        # arête du cristal : reflet fin
        a_a = I.couv(g["arete"]) * a_champ
        alb = I._melange(alb, tuple(min(1.0, v * 1.9 + 0.08) for v in R["champ"]["rgb"]), a_a * 0.8)
        H += 0.6 * a_a
    if g.get("facette") is not None:
        # table du cristal : facette plus claire et plus lisse
        a_f = I.couv(g["facette"]) * a_champ
        poser(a_f, dict(rgb=tuple(min(1.0, v * 1.55 + 0.02) for v in R["champ"]["rgb"]), rough=0.22, met=0.12))
        H += 0.7 * I.profil(g["facette"], 2.5) * a_f

    emis = np.zeros((N, N, 3))
    a_coeur_tot = np.zeros((N, N))
    i_coeur = 1.0 + 2.4 * e
    blanc = 0.15 + 0.55 * e
    c_coeur = lum * (1 - blanc) + np.array([1.0, 1.0, 1.0]) * blanc
    for sd in g["logements"]:
        a_l = I.couv(sd)
        H -= 1.4 * I.profil(sd, 0.8) * a_l
        poser(a_l, R["logement"])
    for item in g["coeurs"]:
        sd, allume = item[0], item[1]
        verre = item[2] if len(item) > 2 else None
        a_c = I.couv(sd)
        if verre:
            # verre de lentille : violet profond, lueur qui monte vers le centre (pas un disque blanc)
            prof = I.profil(sd, verre)
            alb = I._melange(alb, lum * 0.10, a_c)
            rough = rough * (1 - a_c) + 0.12 * a_c
            emis += (lum[None, None, :] * (0.10 + 1.05 * prof ** 3)[..., None]) * a_c[..., None]
            H += 0.6 * prof * a_c
            continue
        H += 0.9 * I.profil(sd, 1.0) * a_c
        if allume:
            dome = I.profil(sd, 1.2)
            alb = I._melange(alb, lum * 0.25, a_c)
            emis += (c_coeur * i_coeur)[None, None, :] * (a_c * (0.55 + 0.45 * dome))[..., None]
            a_coeur_tot = np.maximum(a_coeur_tot, a_c)
        else:
            # filament éteint : verre sombre de la couleur du type
            alb = I._melange(alb, lum * 0.06, a_c)
            emis += (lum * 0.05)[None, None, :] * a_c[..., None]

    if g.get("reticule") is not None:
        a_r = I.couv(g["reticule"]) * a_sil
        emis = emis * (1 - a_r[..., None])
        poser(a_r, R["logement"])
        a_coeur_tot = a_coeur_tot * (1 - a_r)
    # étoiles du palier III (même dessin que les étoiles des modules 6 à 10)
    for sx, sy in g["slots"]:
        r = 3.0
        croix = np.minimum(I.sd_segment(sx - r, sy, sx + r, sy, 0.45), I.sd_segment(sx, sy - r, sx, sy + r, 0.45))
        point = I.sd_cercle(sx, sy, 1.15)
        a_c = I.couv(croix)
        a_p = I.couv(point)
        emis += (lum2 * 1.4)[None, None, :] * a_c[..., None] * 0.9
        emis += (lum * 2.6)[None, None, :] * a_p[..., None]
        alb = I._melange(alb, lum * 0.5, np.maximum(a_c, a_p) * 0.6)

    # halo des filaments allumés, dans la silhouette seulement
    sig = (1.2 + 2.2 * e) * U
    halo = ndimage.gaussian_filter(a_coeur_tot, sig)
    halo = halo / max(halo.max(), 1e-6)
    emis += (lum * (0.10 + 0.5 * e))[None, None, :] * (halo * (1 - a_coeur_tot))[..., None]

    k_plaque = k
    if avec_plaque_vecteur:
        a_pl, a_gl = I.plaque_vecteur(k_plaque)
        poser(a_pl, dict(R["plaque"], rgb=tuple(np.asarray(R["plaque"]["rgb"]) * 0.6 + 0.006)))
        H = H * (1 - a_pl) + (3.4 + 0.6 * I.profil(I.sd_plaque(k_plaque), 0.7)) * a_pl
        alb = I._melange(alb, lum * 0.3, a_gl)
        emis = emis * (1 - a_pl[..., None]) + couleur_glyphe(R, k)[None, None, :] * a_gl[..., None]
        a_sil = np.maximum(a_sil, a_pl)

    gy, gx = np.gradient(H * U)
    gx, gy = gx / U, gy / U
    nx, ny, nz = -gx * 2.2, -gy * 2.2, np.ones_like(H)
    nn = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / nn, ny / nn, nz / nn
    diff = np.clip(nx * I.LUM[0] + ny * I.LUM[1] + nz * I.LUM[2], 0.0, 1.0)
    diff_plat = I.LUM[2]
    nh = np.clip(nx * I.DEMI[0] + ny * I.DEMI[1] + nz * I.DEMI[2], 0.0, 1.0)
    p = 6.0 + (1.0 - rough) ** 2 * 90.0
    ks = 0.04 + 0.55 * (1.0 - rough) ** 2
    spec = ks * nh ** p
    creux = np.clip(ndimage.gaussian_filter(H, 1.2 * U) - H, 0.0, 3.0)
    occl = 1.0 - 0.22 * creux
    vert = 1.06 - 0.12 * (Y / 64.0)
    lit = alb * ((0.38 + 0.62 * diff / diff_plat) * occl * vert)[..., None]
    spec_col = (1.0 - met)[..., None] * 1.0 + met[..., None] * alb * 2.2
    lit = lit + spec[..., None] * spec_col + emis

    sil_tot = g["sil"] if not avec_plaque_vecteur else np.minimum(g["sil"], I.sd_plaque(k_plaque))
    a_tot = I.couv(sil_tot - 0.9)
    contour = np.asarray(R["logement"]["rgb"], float) * 0.35
    a_cont = np.clip(a_tot - a_sil, 0.0, 1.0)
    rgb = lit * a_sil[..., None] + contour[None, None, :] * a_cont[..., None] * 0.92
    alpha = a_sil + a_cont * 0.92
    return rgb, np.clip(alpha, 0.0, 1.0)


def couleur_glyphe(R, k):
    """Lumière des chiffres gravés, plus vive avec le palier (I, II, III : 3 paliers et non 10)."""
    e = eclat(k)
    lum = np.asarray(R["lumiere"], float)
    blanc = 0.40 + 0.40 * e
    return (lum * (1 - blanc) + blanc) * (1.4 + 0.8 * e)


def poser_plaque_pixel(img, k, R):
    """Plaque au pixel à 32 px : la fonction validée des modules, avec la couleur des chiffres de ce lot."""
    sauve = I.couleur_glyphe
    I.couleur_glyphe = couleur_glyphe
    try:
        return I.poser_plaque_pixel(img, k, 1, R)
    finally:
        I.couleur_glyphe = sauve


# ------------------------------------------------------------------------------------------------------------------
# Fichiers
# ------------------------------------------------------------------------------------------------------------------
def icone_objet(t, k):
    rgb, a = rendre_art(t, k)
    rgb_p, a_p = rendre_art(t, k, avec_plaque_vecteur=True)
    R = roles(t, k)
    bande = Image.new("RGBA", (120, 64), (0, 0, 0, 0))
    im64 = I.en_image(*I.reduire(rgb_p, a_p, 64))
    im32 = poser_plaque_pixel(I.en_image(*I.reduire(rgb, a, 32)), k, R)
    im16 = I.reduire_image(im32, 16)
    im8 = I.reduire_image(im16, 8)
    x = 0
    for im in (im64, im32, im16, im8):
        bande.paste(im, (x, 0))
        x += im.size[0]
    return bande, im64


def equipement(t, k):
    """Image dans la grille (2 x 2 cases de 32 px) : 128 px (hr, scale 0,5) et 64 px, plaque en vecteur."""
    rgb, a = rendre_art(t, k, avec_plaque_vecteur=True)
    return I.en_image(*I.reduire(rgb, a, 128)), I.en_image(*I.reduire(rgb, a, 64))


def icone_techno(t, k):
    rgb, a = rendre_art(t, k, avec_plaque_vecteur=True)
    bande = Image.new("RGBA", (480, 256), (0, 0, 0, 0))
    x = 0
    for taille in (256, 128, 64, 32):
        bande.paste(I.en_image(*I.reduire(rgb, a, taille)), (x, 0))
        x += taille
    return bande


def generer():
    fichiers = {}
    man = dict(version=VERSION, outil="tools/render/pieces/modules/icones_geants.py", objets={}, equipements={}, technos={})
    for t in TYPES:
        for k in PALIERS:
            o = nom_objet(t, k)
            bande, _ = icone_objet(t, k)
            b = I.png_octets(bande)
            fichiers["%s.png" % o] = b
            man["objets"][o] = dict(type=t, palier=k, age=AGE[k], fichier="%s.png" % o, icon_size=64, icon_mipmaps=4,
                                    sha256=hashlib.sha256(b).hexdigest())
            hr, lr = equipement(t, k)
            bh, bl = I.png_octets(hr), I.png_octets(lr)
            fichiers["equipement/hr-%s.png" % o] = bh
            fichiers["equipement/%s.png" % o] = bl
            man["equipements"][o] = dict(type=t, palier=k, fichier="equipement/%s.png" % o, largeur=64, hauteur=64,
                                         hr_fichier="equipement/hr-%s.png" % o, hr_largeur=128, hr_hauteur=128,
                                         sha256=hashlib.sha256(bl).hexdigest(), hr_sha256=hashlib.sha256(bh).hexdigest(),
                                         fond=list(FOND_GRILLE[t]), bord=list(BORD_GRILLE[t]))
            tn = nom_techno(t, k)
            bt = I.png_octets(icone_techno(t, k))
            fichiers["tech/%s.png" % tn] = bt
            man["technos"][tn] = dict(type=t, palier=k, fichier="tech/%s.png" % tn, icon_size=256, icon_mipmaps=4,
                                      sha256=hashlib.sha256(bt).hexdigest())
    return fichiers, man


def lua_table(man):
    L = ["-- GÉNÉRÉ par tools/render/pieces/modules/icones_geants.py (lot DESIGN-MODULES) : ne pas éditer à la main.",
         "-- Icônes des modules des géants : objets 64 px + 3 mipmaps, équipements 64 px (hr 128 px), technologies 256 px + 3 mipmaps.",
         "return {", "  version = %d," % man["version"], "  objets = {"]
    for o in sorted(man["objets"]):
        d = man["objets"][o]
        L.append('    ["%s"] = { fichier = "%s", icon_size = 64, icon_mipmaps = 4, palier = %d, age = %d },'
                 % (o, d["fichier"], d["palier"], d["age"]))
    L.append("  },")
    L.append("  equipements = {")
    for o in sorted(man["equipements"]):
        d = man["equipements"][o]
        f, b = d["fond"], d["bord"]
        L.append('    ["%s"] = { fichier = "%s", largeur = 64, hauteur = 64, hr_fichier = "%s", hr_largeur = 128, hr_hauteur = 128,'
                 % (o, d["fichier"], d["hr_fichier"]))
        L.append("      fond = { r = %.3f, g = %.3f, b = %.3f, a = %.3f }, bord = { r = %.3f, g = %.3f, b = %.3f } },"
                 % (f[0], f[1], f[2], f[3], b[0], b[1], b[2]))
    L.append("  },")
    L.append("  technos = {")
    for tn in sorted(man["technos"]):
        d = man["technos"][tn]
        L.append('    ["%s"] = { fichier = "%s", icon_size = 256, icon_mipmaps = 4 },' % (tn, d["fichier"]))
    L.append("  },")
    L.append("}")
    return "\n".join(L) + "\n"


# ------------------------------------------------------------------------------------------------------------------
# Planche (fond sombre et clair ; comparaison aux modules validés et aux équipements vanilla)
# ------------------------------------------------------------------------------------------------------------------
def _police(taille, gras=False):
    try:
        return ImageFont.truetype("arialbd.ttf" if gras else "arial.ttf", taille)
    except OSError:
        return ImageFont.load_default()


def planche(chemin, fichiers):
    f_t, f_x = _police(18, True), _police(13)
    cell = 150
    marge = 180
    larg = marge + 3 * cell + 3 * 112 + 40
    fonds = [("fond sombre (inventaire)", (49, 48, 49)), ("fond clair", (214, 210, 200))]
    rang_h = 64 + 6 + 64 + 18
    bloc_h = 2 * rang_h + 46
    H = 80 + len(fonds) * bloc_h + 10
    im = Image.new("RGB", (larg, H), (24, 24, 26))
    d = ImageDraw.Draw(im)
    d.text((16, 12), "Modules des géants : 2 types x 3 paliers (proposition, à juger)", fill=(235, 235, 235), font=f_t)
    d.text((16, 40), "Case : 64 px en haut à gauche, 32 px à droite (inventaire), 32 px agrandis x 2 dessous. À droite : modules validés "
                     "(référence de style).", fill=(200, 200, 200), font=f_x)
    noms = {"portee": "Portée : éventail violet", "puissance": "Puissance : éclat cramoisi"}
    refs = ["fo-speed-module-10", "fo-productivity-module-10", "fo-effectivity-module-10"]
    y = 80
    for libelle, fond in fonds:
        d.rectangle((0, y, larg, y + bloc_h - 10), fill=fond)
        enc = (230, 230, 230) if sum(fond) < 300 else (20, 20, 20)
        d.text((16, y + 8), libelle, fill=enc, font=f_x)
        for k in PALIERS:
            d.text((marge + (k - 1) * cell + 4, y + 8), "palier %s (âge %d)" % ("I" * k, AGE[k]), fill=enc, font=f_x)
        yy = y + 30
        for t in TYPES:
            d.text((16, yy + 50), noms[t], fill=enc, font=f_x)
            for k in PALIERS:
                b = Image.open(io.BytesIO(fichiers["%s.png" % nom_objet(t, k)])).convert("RGBA")
                x = marge + (k - 1) * cell
                c64, c32 = b.crop((0, 0, 64, 64)), b.crop((64, 0, 96, 32))
                tuile = Image.new("RGBA", (cell - 8, rang_h), fond + (255,))
                tuile.alpha_composite(c64, (2, 0))
                tuile.alpha_composite(c32, (72, 16))
                tuile.alpha_composite(c32.resize((64, 64), Image.NEAREST), (2, 70))
                im.paste(tuile.convert("RGB"), (x, yy))
            yy += rang_h
        # référence : modules validés
        xr = marge + 3 * cell + 10
        for i, n in enumerate(refs):
            p = os.path.join(MOD, "graphics", "modules", n + ".png")
            if os.path.exists(p):
                b = Image.open(p).convert("RGBA")
                tuile = Image.new("RGBA", (104, rang_h), fond + (255,))
                tuile.alpha_composite(b.crop((0, 0, 64, 64)), (2, 0))
                tuile.alpha_composite(b.crop((64, 0, 96, 32)), (70, 16))
                tuile.alpha_composite(b.crop((64, 0, 96, 32)).resize((64, 64), Image.NEAREST), (2, 70))
                im.paste(tuile.convert("RGB"), (xr + i * 108, y + 30 + (rang_h // 2)))
        y += bloc_h
    im.save(chemin)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=os.path.join(MOD, "graphics", "modules-geants"))
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--planche")
    ap.add_argument("--sans-ecrire", action="store_true")
    a = ap.parse_args(argv)
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass
    verifier_donnees()
    fichiers, man = generer()
    if a.check:
        ref = json.load(open(os.path.join(a.out, "MANIFEST.json"), encoding="utf-8"))
        pb = []
        for sec in ("objets", "equipements", "technos"):
            for o, dd in sorted(man[sec].items()):
                r = ref.get(sec, {}).get(o)
                if not r or r != dd:
                    pb.append("%s/%s" % (sec, o))
                    continue
                for cle_f, cle_h in (("fichier", "sha256"), ("hr_fichier", "hr_sha256")):
                    if cle_f in dd and hashlib.sha256(open(os.path.join(a.out, dd[cle_f]), "rb").read()).hexdigest() != dd[cle_h]:
                        pb.append("%s (fichier)" % dd[cle_f])
        if open(os.path.join(a.out, "icons.lua"), encoding="utf-8").read() != lua_table(man):
            pb.append("icons.lua")
        print("[FO-XP-MODULES-ICONES] contrôle : %d objet(s), %d équipement(s), %d techno(s), %d écart(s)%s"
              % (len(man["objets"]), len(man["equipements"]), len(man["technos"]), len(pb), (" : " + ", ".join(pb)) if pb else ""))
        return 1 if pb else 0
    if not a.sans_ecrire:
        for sous in ("tech", "equipement"):
            os.makedirs(os.path.join(a.out, sous), exist_ok=True)
        total = 0
        for rel, b in sorted(fichiers.items()):
            with open(os.path.join(a.out, rel), "wb") as f:
                f.write(b)
            total += len(b)
        with open(os.path.join(a.out, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(man, f, ensure_ascii=False, indent=1, sort_keys=True)
            f.write("\n")
        with open(os.path.join(a.out, "icons.lua"), "w", encoding="utf-8", newline="\n") as f:
            f.write(lua_table(man))
        print("[FO-XP-MODULES-ICONES] %d fichier(s) PNG, %.2f Mo, dans %s" % (len(fichiers), total / 1e6, a.out))
    if a.planche:
        planche(a.planche, fichiers)
        print("[FO-XP-MODULES-ICONES] planche : %s" % a.planche)
    return 0


if __name__ == "__main__":
    sys.exit(main())
