"""DIRECTIONS ARTISTIQUES des modules de production (vitesse, productivité, efficacité), lot DESIGN-MODULES, 7/11 : PROPOSITION.

Demande du DC (7/11), citée : « d'ailleur, il faudrait redesigner les modules de vitesse, productivité etc car ils sont pas beau ».
Ce script ne remplace RIEN : graphics/modules et icones.py (lots MOD-V et MOD-3) restent tels quels jusqu'au verdict du DC. Il rend des
planches de comparaison (vanilla, actuel, trois directions) dans un dossier hors du dépôt.

Même rendu que les modules validés et que ceux des géants (champs de distance signée à 512 px, relief éclairé du nord-ouest, réduction en
lumière linéaire, chiffre romain au pixel à 32 px) ; couleurs par type de la décision D-17 (bleu, orange, vert : icones.TYPE_COULEURS).
Montée des 10 paliers, la même dans les trois directions (la forme change, critère D1) : I à III la pièce seule (éclat croissant) ;
IV à VII 1 à 4 griffes ou crochets ; VIII à X les 4 et 1 à 3 étoiles, X avec le bord allumé.

  A « Gemmes serties » : cristaux taillés à deux faces, dans l'esprit du cœur de rupture des géants. Vitesse : double chevron de cristal
    (« avance rapide ») ; productivité : gemme ronde taillée en brillant, sertie dans l'engrenage (D-17 « Engrenage ») ; efficacité :
    gemme navette en feuille, nervure lumineuse, tige de métal.
  B « Médaillons » : une lentille de verre allumée dans une bague, dans l'esprit du viseur des géants ; la bague garde la silhouette du
    type (goutte pointée vers la droite, couronne dentée, goutte en feuille) et le glyphe du type brille dans le verre.
  C « Cartouches » : une carte de module, comme les modules vanilla mais chargée : carte à pans coupés, fenêtre de verre et glyphe,
    ailettes, contacts dorés, et une JAUGE de 10 voyants dont le nombre allumé dit le palier.

  D « Plaquette (objet) » (icones_plaquette.py) : après la 1re critique (A, B, C : pictogrammes plats), le module redevient un objet
    comme en vanilla ; proposition principale (3e critique : « montrable »).
  A est gardée CORRIGÉE comme témoin (roles_dir : cadre de la matière du palier, sans griffes ni étoiles de 1 px, gemme à 3 facettes).

Usage : py -3.9 tools/render/pieces/modules/icones_directions.py --out <dossier> [--paliers 1,5,10] [--complet] [--directions D,A,B,C]
"""

import argparse
import io
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import icones as I  # noqa: E402
import icones_geants as G  # noqa: E402
import icones_plaquette as P  # noqa: E402

TYPES = ("speed", "productivity", "effectivity")
NOMS = {"speed": "Vitesse", "productivity": "Productivité", "effectivity": "Efficacité"}
DIRECTIONS = ("D", "A", "B", "C")
TITRES = {"A": "A. Gemmes (corrigée, témoin)", "B": "B. Médaillons", "C": "C. Cartouches", "D": "D. Plaquette (objet)"}
_ICONES = {}
OR = dict(rgb=(0.80, 0.52, 0.14), rough=0.22, met=0.92)
ACIER = dict(rgb=(0.32, 0.33, 0.36), rough=0.30, met=0.85)


def eclat10(k):
    return (k - 1) / 9.0


def griffes(k):
    """Nombre de griffes (ou crochets) du palier k : 0 de I à III, 1 à 4 de IV à VII, 4 ensuite."""
    return 0 if k <= 3 else min(4, k - 3)


def etoiles(k):
    return max(0, k - 7)


def _u(sds):
    out = None
    for s in sds:
        out = s if out is None else np.minimum(out, s)
    return out


def chevron(cx, cy, s):
    return [(cx - 0.95 * s, cy - s), (cx - 0.15 * s, cy - s), (cx + 0.85 * s, cy), (cx - 0.15 * s, cy + s), (cx - 0.95 * s, cy + s),
            (cx + 0.02 * s, cy)]


def navette(ax, ay, bx, by, W, n=40):
    """Gemme navette (ovale pointu) de A à B, demi-largeur W au milieu."""
    L = math.hypot(bx - ax, by - ay)
    ux, uy = (bx - ax) / L, (by - ay) / L
    nx, ny = -uy, ux
    us = [i / float(n) for i in range(n + 1)]
    haut = [(ax + ux * L * u + nx * W * math.sin(math.pi * u), ay + uy * L * u + ny * W * math.sin(math.pi * u)) for u in us]
    bas = [(ax + ux * L * u - nx * W * math.sin(math.pi * u), ay + uy * L * u - ny * W * math.sin(math.pi * u)) for u in reversed(us[1:-1])]
    return haut + bas, (ux, uy, nx, ny, L)


def etoiles_slots(slots, k):
    return slots[:etoiles(k)]


def griffe(cx, cy, a_deg, long=5.4, larg=2.0):
    a = math.radians(a_deg)
    return I.sd_segment(cx - math.cos(a) * long / 2, cy - math.sin(a) * long / 2, cx + math.cos(a) * long / 2, cy + math.sin(a) * long / 2, larg)


# ------------------------------------------------------------------------------------------------------------------
# A. Gemmes serties
# ------------------------------------------------------------------------------------------------------------------
def A_speed(k):
    av = chevron(36.0, 33.0, 24.0)
    ar = chevron(15.5, 33.0, 15.0)
    s_av, s_ar = I.sd_poly(av) - 0.8, I.sd_poly(ar) - 0.8
    sil = np.minimum(s_av, s_ar)
    champ = np.minimum(s_av + 2.6, s_ar + 2.4)
    haut = np.maximum(sil, Y_moins(33.0))
    faces = [(haut, 1.32)]
    arete = np.minimum(I.sd_segment(36.0, 33.0, 55.5, 33.0, 0.45), I.sd_segment(16.0, 33.0, 28.0, 33.0, 0.4))
    log, coe = [], []
    for pts, w in (([(27.0, 16.0), (50.0, 33.0), (27.0, 50.0)], 1.0), ([(9.5, 22.0), (24.5, 33.0), (9.5, 44.0)], 0.75)):
        log.append(I.sd_polyligne(pts, w + 1.0))
        coe.append((I.sd_polyligne(pts, w), True))
    return dict(sil=sil, champ=champ, logements=log, coeurs=coe, grad=None, slots=[], faces=faces, arete=arete, bord=(s_av, False))


def Y_moins(y0):
    """Demi-plan au-dessus de y0 (négatif dedans)."""
    return I.Y - y0


def A_productivity(k):
    cx, cy = 31.5, 32.0
    roue = I.sd_poly(I._engrenage(cx, cy, 8, 22.0, 28.5, 0.36, 0.56)) - 1.1
    gemme = I.sd_poly([(cx + 15.6 * math.cos(math.radians(22.5 + 45 * i)), cy + 15.6 * math.sin(math.radians(22.5 + 45 * i)))
                       for i in range(8)]) - 0.4
    sil = roue
    champ = np.maximum(roue + 2.4, -(gemme + 1.8))
    log = [gemme + 0.4]
    # gemme taillée en 3 facettes LARGES (critique du 7/11 : le brillant à 16 arêtes faisait une bouillie à 32 px)
    coe = [(gemme, True, 12.0)]
    traits = [I.sd_segment(cx, cy, cx + 15.5 * math.cos(math.radians(a)), cy + 15.5 * math.sin(math.radians(a)), 0.75) for a in (-90, 30, 150)]
    return dict(sil=sil, champ=champ, logements=log, coeurs=coe, grad=None, slots=[], reticule=_u(traits), bord=(roue, False))


def A_effectivity(k):
    pts, (ux, uy, nx, ny, L) = navette(9.0, 55.0, 57.0, 7.0, 15.5)
    gemme = I.sd_poly(pts) - 0.6
    tige = I.sd_segment(3.0, 61.0, 11.5, 52.5, 2.3)
    sil = np.minimum(gemme, tige)
    champ = gemme + 2.5
    cote = np.maximum(gemme, (I.X - 9.0) * nx + (I.Y - 55.0) * ny)      # moitié du côté de la normale : face claire
    p0, p1 = (9.0 + ux * L * 0.12, 55.0 + uy * L * 0.12), (9.0 + ux * L * 0.86, 55.0 + uy * L * 0.86)
    log = [I.sd_segment(p0[0], p0[1], p1[0], p1[1], 2.2)]
    coe = [(I.sd_segment(p0[0], p0[1], p1[0], p1[1], 1.1), True)]
    for u, sgn in ((0.35, 1), (0.55, -1), (0.7, 1)):
        q0 = (9.0 + ux * L * u, 55.0 + uy * L * u)
        q1 = (q0[0] + ux * 7.0 + nx * 8.0 * sgn, q0[1] + uy * 7.0 + ny * 8.0 * sgn)
        log.append(I.sd_segment(q0[0], q0[1], q1[0], q1[1], 1.3))
        coe.append((I.sd_segment(q0[0], q0[1], q1[0], q1[1], 0.55), k >= 2))
    return dict(sil=sil, champ=champ, logements=log, coeurs=coe, grad=None, slots=[], faces=[(cote, 1.3)], bord=(gemme, False))


# ------------------------------------------------------------------------------------------------------------------
# B. Médaillons : bague à la silhouette du type, lentille allumée, glyphe dans le verre
# ------------------------------------------------------------------------------------------------------------------
def _medaillon(bague, cx, cy, r_len, glyphe, k, slots_c, slots_e):
    lentille = I.sd_cercle(cx, cy, r_len)
    sil = bague
    champ = np.maximum(bague + 2.2, -(lentille + 0.4))
    log = [lentille]
    coe = [(lentille + 0.7, True, r_len * 0.8)]
    coe.append((glyphe, True))
    # index gravés dans la bague dès IV, allumés au X
    n_idx = 0 if k < 4 else (4 if k < 6 else 8)
    for i in range(n_idx):
        a = math.radians(45.0 / (2 if n_idx == 8 else 1) + i * 360.0 / n_idx)
        p0 = (cx + (r_len + 1.4) * math.cos(a), cy + (r_len + 1.4) * math.sin(a))
        p1 = (cx + (r_len + 4.4) * math.cos(a), cy + (r_len + 4.4) * math.sin(a))
        log.append(I.sd_segment(p0[0], p0[1], p1[0], p1[1], 0.95))
        coe.append((I.sd_segment(p0[0], p0[1], p1[0], p1[1], 0.5), k == 10))
    dessus = []
    cro = []
    for (ox, oy, sx, sy) in slots_c[:(griffes(k) if k < 8 else 4)]:
        cro.append(I.sd_segment(ox, oy, ox - sx * 7.5, oy, 1.8))
        cro.append(I.sd_segment(ox, oy, ox, oy - sy * 7.5, 1.8))
    if cro:
        c = _u(cro)
        sil = np.minimum(sil, c)
        dessus.append(c)
    return dict(sil=sil, champ=champ, logements=log, coeurs=coe, grad=None, slots=etoiles_slots(slots_e, k), dessus=dessus,
                bord=(bague, k == 10))


def B_speed(k):
    cx, cy = 28.0, 33.0
    bague = np.minimum(I.sd_cercle(cx, cy, 21.5), I.sd_poly([(cx + 8.0, cy - 19.5), (61.0, cy), (cx + 8.0, cy + 19.5)]) - 1.5)
    g = I.sd_polyligne([(cx - 5.0, cy - 8.0), (cx + 4.5, cy), (cx - 5.0, cy + 8.0)], 1.5)
    g = np.minimum(g, I.sd_polyligne([(cx - 11.0, cy - 6.0), (cx - 3.5, cy), (cx - 11.0, cy + 6.0)], 1.1))
    sc = [(cx + 24.0, cy + 24.0, 1, 1), (cx - 24.0, cy + 24.0, -1, 1), (cx + 24.0, cy - 24.0, 1, -1), (cx - 23.0, cy - 2.0, -1, 1)]
    se = [(cx, cy - 18.5), (cx, cy + 18.5), (cx - 18.5, cy)]
    return _medaillon(bague, cx, cy, 14.0, g, k, sc, se)


def B_productivity(k):
    cx, cy = 31.5, 32.0
    bague = I.sd_poly(I._engrenage(cx, cy, 10, 23.0, 28.5, 0.40, 0.58)) - 1.0
    g = np.minimum(np.abs(I.sd_cercle(cx, cy, 5.2)) - 1.3, I.sd_poly(I._engrenage(cx, cy, 6, 6.5, 9.0, 0.45, 0.6)) - 0.2)
    g = np.maximum(g, -(I.sd_cercle(cx, cy, 2.6)))
    sc = [(cx + 27.0, cy + 27.0, 1, 1), (cx - 27.0, cy + 27.0, -1, 1), (cx + 27.0, cy - 27.0, 1, -1), (cx - 27.0, cy - 2.0, -1, 1)]
    se = [(cx, cy - 19.5), (cx + 19.5, cy), (cx, cy + 19.5)]
    return _medaillon(bague, cx, cy, 14.5, g, k, sc, se)


def B_effectivity(k):
    cx, cy = 29.0, 35.0
    bague = np.minimum(I.sd_cercle(cx, cy, 21.5), I.sd_poly([(cx + 3.0, cy - 21.0), (59.0, 5.0), (cx + 21.0, cy - 3.0)]) - 1.5)
    pts, _ = navette(cx - 7.5, cy + 7.5, cx + 7.5, cy - 7.5, 5.8)
    g = np.abs(I.sd_poly(pts)) - 1.2
    g = np.minimum(g, I.sd_segment(cx - 7.5, cy + 7.5, cx + 6.0, cy - 6.0, 0.8))
    sc = [(cx + 24.0, cy + 24.0, 1, 1), (cx - 24.0, cy + 24.0, -1, 1), (cx + 26.0, cy - 6.0, 1, 1), (cx - 24.0, cy - 6.0, -1, 1)]
    se = [(cx, cy + 18.5), (cx - 18.5, cy), (cx + 18.5, cy + 2.0)]
    return _medaillon(bague, cx, cy, 14.0, g, k, sc, se)


# ------------------------------------------------------------------------------------------------------------------
# C. Cartouches : carte à pans coupés, fenêtre de verre et glyphe, ailettes, contacts dorés, jauge de 10 voyants
# ------------------------------------------------------------------------------------------------------------------
def _cartouche(glyphe_fn, k):
    x0, y0, x1, y1, c = 6.0, 4.0, 58.0, 58.0, 8.0
    carte = I.sd_poly([(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - 4.0), (x1 - 4.0, y1), (x0 + 4.0, y1), (x0, y1 - 4.0), (x0, y0 + c)]) - 0.6
    cx, cy = 29.5, 30.0
    fenetre = I.sd_cercle(cx, cy, 13.5)
    sil = carte
    champ = np.maximum(carte + 2.3, -(fenetre + 2.0))
    log = [fenetre]
    coe = [(fenetre + 0.7, True, 11.0), (glyphe_fn(cx, cy), True)]
    # ailettes (rainures) en haut, contacts dorés en bas
    grad = _u([I.sd_segment(x, y0 + 3.5, x, y0 + 8.5, 0.55) for x in np.arange(19.0, 47.0, 3.5)])
    contacts = _u([I.sd_boite(x - 1.5, y1 - 6.5, x + 1.5, y1 - 0.8, 0.4) for x in np.arange(14.0, 46.0, 4.0)])
    mats = [(contacts, OR, 0.8)]
    # jauge : 10 voyants à droite, k allumés
    for i in range(10):
        vy = y1 - 10.0 - i * 4.0
        log.append(I.sd_cercle(52.0, vy, 1.45))
        coe.append((I.sd_cercle(52.0, vy, 1.0), i < k))
    return dict(sil=sil, champ=champ, logements=log, coeurs=coe, grad=grad, slots=[], matieres=mats, bord=(carte, k == 10))


def C_speed(k):
    return _cartouche(lambda cx, cy: np.minimum(I.sd_polyligne([(cx - 6.0, cy - 7.5), (cx + 3.5, cy), (cx - 6.0, cy + 7.5)], 1.5),
                                                I.sd_polyligne([(cx + 0.5, cy - 7.5), (cx + 10.0, cy), (cx + 0.5, cy + 7.5)], 1.5)), k)


def C_productivity(k):
    def g(cx, cy):
        r = np.minimum(np.abs(I.sd_cercle(cx, cy, 5.5)) - 1.3, I.sd_poly(I._engrenage(cx, cy, 8, 7.0, 9.6, 0.42, 0.6)) - 0.2)
        return np.maximum(r, -(I.sd_cercle(cx, cy, 2.8)))
    return _cartouche(g, k)


def C_effectivity(k):
    def g(cx, cy):
        pts, _ = navette(cx - 8.0, cy + 8.0, cx + 8.0, cy - 8.0, 6.0)
        return np.minimum(np.abs(I.sd_poly(pts)) - 1.2, I.sd_segment(cx - 8.0, cy + 8.0, cx + 6.5, cy - 6.5, 0.8))
    return _cartouche(g, k)


FONCTIONS = {"A": {"speed": A_speed, "productivity": A_productivity, "effectivity": A_effectivity},
             "B": {"speed": B_speed, "productivity": B_productivity, "effectivity": B_effectivity},
             "C": {"speed": C_speed, "productivity": C_productivity, "effectivity": C_effectivity}}


def avec_bord(fn):
    """Bord allumé au palier X (filet lumineux sur le contour) et pièce de la montée du palier : ajoutés à la géométrie."""
    def f(k):
        g = fn(k)
        sd, allume = g.pop("bord", (None, False))
        if allume and sd is not None:
            g["coeurs"].append((np.abs(sd + 1.3) - 0.45, True))
        return g
    return f


_ROLES0 = G.roles


def roles_dir(t, k):
    """A corrigée (témoin) : le CADRE prend la matière du palier (bronze I à III, acier IV à VI, or VII à X : icones_plaquette.GARNITURE),
    à la place des griffes et des étoiles de 1 px (critique du 7/11) ; B et C inchangées."""
    R = _ROLES0(t, k)
    if t.startswith("A-"):
        R["cadre"] = dict(P.GARNITURE[P.marche(k)])
    return R


def installer():
    """Inscrit les 9 géométries dans le moteur de rendu des modules des géants (même éclairage, plaque des paliers 1 à 10)."""
    G.eclat = eclat10
    G.roles = roles_dir
    for d in ("A", "B", "C"):
        for t in TYPES:
            cle = "%s-%s" % (d, t)
            G.GEO[cle] = avec_bord(FONCTIONS[d][t])
            c = I.TYPE_COULEURS[t]
            G.COULEURS[cle] = dict(champ=c["champ"], cadre=c["cadre"], logement=c["logement"], lumiere=c["lumiere"], lumiere2=c["lumiere2"])


# ------------------------------------------------------------------------------------------------------------------
# Planche
# ------------------------------------------------------------------------------------------------------------------
def police(t, gras=False):
    try:
        return ImageFont.truetype("arialbd.ttf" if gras else "arial.ttf", t)
    except OSError:
        return ImageFont.load_default()


def tuile(bande, fond, w=212):
    im = Image.new("RGBA", (w, 134), fond + (255,))
    c64 = bande.crop((0, 0, 64, 64))
    c32 = bande.crop((64, 0, 96, 32)) if bande.size[0] >= 96 else c64.resize((32, 32), Image.LANCZOS)
    im.alpha_composite(c64.resize((128, 128), Image.LANCZOS), (0, 3))
    im.alpha_composite(c32, (134, 10))
    im.alpha_composite(c32.resize((64, 64), Image.NEAREST), (134, 52))
    return im


def vanilla(t, k):
    noms = I.VANILLA[t]
    racine = os.path.join("F:" + os.sep, "Factorio.v1.1.91 Modding", "Factorio.v1.1.91")   # données du jeu (icônes vanilla)
    p = os.path.join(racine, "data", "base", "graphics", "icons", "%s.png" % noms[min(k, 3) - 1])
    return Image.open(p).convert("RGBA") if k <= 3 else None


def actuel(t, k):
    return Image.open(os.path.join(I.MOD, "graphics", "modules", "%s.png" % I.nom_objet(t, k))).convert("RGBA")


def icone(d, t, k):
    """Bande 120 x 64 de la direction d (mise en cache : les planches sombre et claire reprennent les mêmes)."""
    cle = (d, t, k)
    if cle not in _ICONES:
        _ICONES[cle] = P.icone_objet(t, k)[0] if d == "D" else G.icone_objet("%s-%s" % (d, t), k)[0]
    return _ICONES[cle]


def planche(out, paliers, fond, nom_fichier, directions=DIRECTIONS):
    f_t, f_b, f_x = police(22, True), police(16, True), police(13)
    lignes = [("Vanilla", None), ("Actuel (MOD-V, MOD-3)", "actuel")] + [(TITRES[d], d) for d in directions]
    col = 220
    W = 230 + len(TYPES) * len(paliers) * col + 20
    H = 90 + len(lignes) * 150 + 20
    im = Image.new("RGB", (W, H), fond)
    d = ImageDraw.Draw(im)
    enc = (235, 235, 235) if sum(fond) < 300 else (20, 20, 20)
    d.text((14, 12), "Modules de production : directions artistiques (proposition, rien n'est remplacé)", fill=enc, font=f_t)
    d.text((14, 44), "Case : 64 px agrandis, 32 px réels (inventaire), 32 px agrandis au pixel. Paliers montrés : " +
           ", ".join(I.ROMAIN[k] for k in paliers) + ".", fill=enc, font=f_x)
    x = 230
    for t in TYPES:
        for k in paliers:
            d.text((x + 6, 68), "%s %s" % (NOMS[t], I.ROMAIN[k]), fill=enc, font=f_b)
            x += col
    y = 90
    for titre, cle in lignes:
        d.text((14, y + 56), titre, fill=enc, font=f_b)
        x = 230
        for t in TYPES:
            for k in paliers:
                if cle is None:
                    b = vanilla(t, k)
                elif cle == "actuel":
                    b = actuel(t, k)
                else:
                    b = icone(cle, t, k)
                if b is not None:
                    im.paste(tuile(b, fond).convert("RGB"), (x, y))
                else:
                    d.text((x + 10, y + 60), "(pas de palier %s en vanilla)" % I.ROMAIN[k], fill=enc, font=f_x)
                x += col
        y += 150
    im.save(os.path.join(out, nom_fichier))


def planche_paliers(out, d_cle, fond, nom_fichier):
    """Les 10 paliers d'une direction, pour les 3 types."""
    f_b = police(16, True)
    col = 220
    W = 200 + 10 * col
    H = 60 + 3 * 150
    im = Image.new("RGB", (W, H), fond)
    dr = ImageDraw.Draw(im)
    enc = (235, 235, 235) if sum(fond) < 300 else (20, 20, 20)
    dr.text((14, 14), "%s : les 10 paliers" % TITRES[d_cle], fill=enc, font=police(20, True))
    y = 50
    for t in TYPES:
        dr.text((14, y + 56), NOMS[t], fill=enc, font=f_b)
        for k in range(1, 11):
            b = icone(d_cle, t, k)
            im.paste(tuile(b, fond).convert("RGB"), (200 + (k - 1) * col, y))
        y += 150
    im.save(os.path.join(out, nom_fichier))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", required=True)
    ap.add_argument("--paliers", default="1,5,10")
    ap.add_argument("--complet", action="store_true", help="aussi les 10 paliers de chaque direction")
    ap.add_argument("--directions", default="D,A,B,C", help="directions des planches (D,A,B,C par défaut)")
    a = ap.parse_args(argv)
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass
    os.makedirs(a.out, exist_ok=True)
    installer()
    paliers = [int(x) for x in a.paliers.split(",")]
    dirs = tuple(x for x in a.directions.split(",") if x)
    planche(a.out, paliers, (49, 48, 49), "directions-sombre.png", dirs)
    planche(a.out, paliers, (214, 210, 200), "directions-clair.png", dirs)
    if a.complet:
        for dd in dirs:
            planche_paliers(a.out, dd, (49, 48, 49), "paliers-%s.png" % dd)
    print("[FO-MODULES-DIRECTIONS] planches dans %s" % a.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
