"""CORRODER (s43, 14/11, pilier D) : corps 3D de la famille d'ennemis TOXIQUE (shared/content/enemies.lua, families.toxic), à la place
des déchiqueteurs vanilla recolorés. Bête corrosive trapue, basse sur six pattes : carapace sombre RONGÉE (plaques trouées, bords
déchiquetés, dessous de chair à vif), POCHES D'ACIDE luisantes sur le dos et les flancs (couche de lueur rendue BLANCHE : le prototype la
teint par palier, vert-jaune bile -> vert acide -> turquoise toxique ; les cracheurs tirent vers l'ambre), gouttes et filets d'acide,
mandibules en crochets. Un seul modèle : les variantes (paliers, déchiqueteur ou cracheur) se distinguent par la TAILLE (échelle du
palier × taille de la famille) et la TEINTE (corps et lueur), lues dans les données (E.corroder_teinte).

Modèle paramétrique low-poly (kit des géants, geo.py) ANIMÉ comme les Écorchés : `build(S, lot, u, attaque=None)` ; 8 directions,
course 8 images, attaque 4 (la tête plonge, les mandibules s'ouvrent, les poches gonflent). Repère LOCAL : +x = avant, +y = gauche,
+z = haut, origine au sol sous le centre. 1 unité = 1 tuile à l'échelle de jeu 1 (le prototype multiplie par l'échelle du palier :
environ 1,3 tuile pour le petit, 3 et plus aux hauts paliers).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
XP = os.path.normpath(os.path.join(HERE, "..", "experimentaux"))
if XP not in sys.path:
    sys.path.insert(0, XP)
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import geo as G  # noqa: E402
import greb as R  # noqa: E402
import titans_mat as TM  # noqa: E402
from juggernaut import hexseg, pointe, plaque  # noqa: E402
from kaiju import pas, ik2, ellipse  # noqa: E402

PREFIX = "co_"
GRIS = os.environ.get("FO_GRIS", "") == "1"
SERIE = {"course": 8, "attaque": 4, "mort": 4, "densite": 48.0, "R": 2.2, "zmax": 1.9, "sol": 30.0}
AO = 0.35
GLOW_BLANC = True
AMP = 0.32
FOULEE = 2 * 0.32


def matieres(S):
    """Palette du Corroder : carapace noir-olive rongée, chair à vif violacée, acide émissif (lueur), bave d'acide, crochets d'os jaunis."""
    M = TM.matieres(S, PREFIX, GRIS)
    if GRIS:
        M["acide"] = M["conduit"]
        M["bave"] = M["conduit"]
        M["flaque"] = M["conduit"]
        M["poche"] = M["conduit"]
        M["chair"] = M["peau"]
        M["carapace"] = M["blind"]
        M["ronge"] = M["blind2"]
        return M
    import mat as MT
    M["carapace"] = MT.surface(PREFIX + "carapace", (0.050, 0.060, 0.030), rough=0.38, met=0.15, tole=(0.35, 0.25), joint=0.4, joint_l=0.04,
                               var=0.3, usure=0.45, nu=(0.30, 0.34, 0.14), crasse=0.7, crasse_col=(0.10, 0.13, 0.01), relief=1.0, graine=51)
    M["ronge"] = MT.surface(PREFIX + "ronge", (0.11, 0.10, 0.035), rough=0.55, met=0.05, tole=(0.2, 0.15), joint=0.6, joint_l=0.05,
                            var=0.4, usure=0.7, nu=(0.45, 0.42, 0.12), crasse=0.8, crasse_col=(0.20, 0.26, 0.02), relief=1.0, graine=52)
    M["chair"] = MT.surface(PREFIX + "chair", (0.16, 0.035, 0.09), rough=0.30, met=0.05, tole=(0.2, 0.5), joint=0.35, joint_l=0.03,
                            var=0.3, usure=0.2, nu=(0.45, 0.20, 0.30), crasse=0.5, crasse_col=(0.12, 0.16, 0.01), relief=0.9, graine=53)
    M["os"] = MT.surface(PREFIX + "crochet", (0.42, 0.38, 0.16), rough=0.35, met=0.0, usure=0.3, nu=(0.70, 0.66, 0.40), crasse=0.5,
                         crasse_col=(0.08, 0.10, 0.01), graine=54)
    M["acide"] = S.mat_emissive(PREFIX + "acide", (0.55, 1.00, 0.10), strength=3.2, base=(0.10, 0.22, 0.015), main_scale=0.3)
    M["bave"] = S.mat_emissive(PREFIX + "bave", (0.45, 0.95, 0.10), strength=1.8, base=(0.10, 0.22, 0.02), main_scale=0.45)
    # s43 tranche 3 : flaque du cadavre SOMBRE (acide qui fume, à peine lumineux : elle dominait la créature morte) ; poche du cracheur
    # moins saturée (membrane sombre, lueur au tiers : aplat jaune au palier 12)
    M["flaque"] = S.mat_emissive(PREFIX + "flaque", (0.40, 0.85, 0.10), strength=0.5, base=(0.030, 0.055, 0.012), main_scale=0.12)
    M["flaque"]["fo_glow_part"] = 0.25
    M["poche"] = S.mat_emissive(PREFIX + "poche", (0.50, 1.00, 0.10), strength=1.4, base=(0.05, 0.10, 0.010), main_scale=0.15)
    M["poche"]["fo_glow_part"] = 0.35
    return M


def plaque_rongee(lot, M, p, n, w, h, e, up, graine):
    """Plaque de carapace RONGÉE : la plaque, deux trous d'acide (pastilles de chair à vif, en creux) et un bord déchiqueté."""
    lot.put(M["carapace"], plaque(p, n, w, h, e, up=up, coins=0.6))
    nn = G.norm(n)
    upn = G.norm(up)
    side = G.norm(G.cross(nn, upn))
    for k in range(2):
        a = graine * 1.7 + k * 2.3
        q = G.add(G.add(p, G.mul(side, 0.28 * w * math.cos(a))), G.mul(upn, 0.25 * h * math.sin(a)))
        q = G.add(q, G.mul(nn, e * 0.9))
        lot.put(M["ronge"], G.sphere(q, 0.09 * w + 0.04, 6, 3))
    lot.put(M["ronge"], pointe(G.add(p, G.mul(side, 0.5 * w)), G.norm(G.add(side, G.mul(upn, -0.3))), 0.18 * w + 0.06, 0.05, 4))


def corps(lot, M, u, bob, gonfle, cracheur=False, dx=0.0):
    """Corps bas et large : loft de chair, carapace rongée en écailles, poches d'acide (dos, flancs), filets d'acide qui coulent."""
    sw = 0.06 * math.sin(G.TAU * u)
    ctrl = [(-1.25, -sw * 2, 0.40 + bob * 0.5), (-0.8, -sw, 0.62 + bob), (-0.2, 0.0, 0.78 + bob), (0.45, 0.0, 0.80 + bob), (0.95, 0.0, 0.72 + bob)]
    ctrl = [(c[0] + dx, c[1], c[2]) for c in ctrl]
    pts = G.catmull(ctrl, 5)
    n = len(pts)
    rings, prof = [], []
    for i, p in enumerate(pts):
        t = i / float(n - 1)
        if t < 0.35:
            k = (t / 0.35) ** 0.9
            w, h = 0.15 + 0.48 * k, 0.12 + 0.36 * k
        elif t < 0.8:
            k = (t - 0.35) / 0.45
            w, h = 0.63 + 0.08 * math.sin(math.pi * k), 0.48 + 0.06 * math.sin(math.pi * k)
        else:
            k = (t - 0.8) / 0.2
            w, h = 0.63 - 0.2 * k, 0.48 - 0.14 * k
        rings.append(ellipse(p, w, h, 10))
        prof.append((p, w, h, t))
    lot.put(M["chair"], G.loft(rings, True, True))
    # carapace rongée : écailles dorsales et de flanc, de la croupe à la nuque
    for i in range(2, n - 1, 2):
        p, w, h, t = prof[i]
        d = G.norm(G.sub(pts[min(n - 1, i + 1)], pts[i - 1]))
        plaque_rongee(lot, M, (p[0], p[1], p[2] + h * 0.86), G.norm((-0.2 * d[0], 0.0, 1.0)), w * 1.5, 0.42, 0.07, d, i)
        for s in (-1, 1):
            if t > 0.25:
                plaque_rongee(lot, M, (p[0], p[1] + s * w * 0.85, p[2] + h * 0.25), G.norm((0.0, s, 0.35)), 0.42, 0.36, 0.05, d, i + s)
    # poches d'acide : trois sur le dos (la plus grosse au milieu), deux sur chaque flanc ; elles gonflent à l'attaque
    poches = ((-0.75, 0.17, 0.0), (-0.2, 0.24, 0.05), (0.35, 0.16, 0.0))
    if cracheur:
        # CRACHEUR : une grosse POCHE D'ACIDE dorsale à l'arrière (le réservoir du crachat), cerclée de côtes rongées ; elle se vide à l'attaque
        i = min(range(n), key=lambda q: abs(pts[q][0] + 0.55))
        p, w, h, t = prof[i]
        rr = 0.46 * (1.0 - 0.1 * gonfle) if gonfle >= 0 else max(0.12, 0.46 * (1.0 + 0.6 * gonfle))   # carcasse : poche crevée, dégonflée
        c = (p[0] - 0.05, p[1], p[2] + h * 0.75 + rr * 0.55)
        lot.put(M["poche"], G.sphere(c, rr, 14, 7))
        for kk in range(5):
            a = -0.9 + 0.45 * kk
            lot.put(M["ronge"], G.oriente(G.tour([(-0.03, rr * 1.02), (0.03, rr * 1.02), (0.03, rr * 1.08), (-0.03, rr * 1.08)], 14, "z"), c,
                                          G.norm((math.cos(a), 0.0, math.sin(a)))))
        poches = ((0.35, 0.14, 0.0),)
    for x, r, dz in poches:
        i = min(range(n), key=lambda q: abs(pts[q][0] - x))
        p, w, h, t = prof[i]
        c = (p[0], p[1] + 0.08, p[2] + h * 0.92 + dz)
        rr = r * (1.0 + 0.25 * gonfle)
        lot.put(M["acide"], G.sphere(c, rr, 12, 6))
        lot.put(M["ronge"], G.tour([(0.0, rr * 1.15), (0.05, rr * 1.2), (0.12, rr * 1.0)], 12, "z", (c[0], c[1], c[2] - rr * 0.55)))
        for s in (-1, 1):
            if x > -0.6:
                cf = (p[0] + 0.1, p[1] + s * w * 0.95, p[2] - h * 0.05)
                lot.put(M["acide"], G.sphere(cf, r * 0.55 * (1.0 + 0.2 * gonfle), 10, 5))
                # filet d'acide qui coule de la poche vers le sol
                lot.put(M["bave"], G.tube([cf, (cf[0] - 0.05, cf[1] + s * 0.04, cf[2] - 0.25), (cf[0] - 0.08, cf[1] + s * 0.05, cf[2] - 0.42)], 0.025, 5))
    # dard de queue corrodé
    tip = pts[0]
    lot.put(M["os"], pointe(tip, G.norm((-1.0, 0.0, 0.5)), 0.45, 0.08, 5))
    lot.put(M["acide"], G.sphere(G.add(tip, (-0.05, 0.0, 0.05)), 0.07, 8, 4))
    return pts, prof


def patte(lot, M, hanche, pied0, u, s, l1, l2, avant):
    """Patte d'insecte coudée vers le haut : cuisse de carapace, tibia en crochet, pointe d'os au sol."""
    dx, dz = pas(u, AMP, 0.16)
    pied = (pied0[0] + dx, pied0[1], pied0[2] + dz)
    genou = ik2(hanche, pied, l1, l2, G.norm((0.3 if avant else -0.3, s * 0.6, 1.0)))
    lot.put(M["carapace"], hexseg(hanche, genou, 0.13, 0.10, 6, 0.2))
    lot.put(M["ronge"], G.sphere(genou, 0.085, 6, 3))
    lot.put(M["carapace"], hexseg(genou, G.lerp(genou, pied, 0.85), 0.075, 0.05, 6))
    lot.put(M["os"], pointe(G.lerp(genou, pied, 0.8), G.norm(G.sub(pied, genou)), G.length(G.sub(pied, genou)) * 0.25, 0.05, 4))


def tete(lot, M, base, ouverture, cracheur=False):
    """Tête large et plate (bilieux) : crâne de carapace rongée, yeux d'acide, mandibules en crochets qui s'ouvrent, gueule d'acide."""
    bx, by, bz = base
    pitch = -0.4 * ouverture

    def P(x, y, z):
        return (bx + x * math.cos(pitch) - z * math.sin(pitch), by + y, bz + x * math.sin(pitch) + z * math.cos(pitch))

    def sect(x, w, h):
        return [P(x, -w, -h * 0.4), P(x, -w * 0.8, h * 0.6), P(x, 0.0, h), P(x, w * 0.8, h * 0.6), P(x, w, -h * 0.4), P(x, 0.0, -h * 0.7)]
    lot.put(M["carapace"], G.loft([sect(-0.15, 0.40, 0.30), sect(0.15, 0.48, 0.30), sect(0.42, 0.38, 0.20), sect(0.58, 0.22, 0.10)], True, True))
    for s in (-1, 1):
        lot.put(M["acide"], G.sphere(P(0.32, s * 0.30, 0.14), 0.055, 8, 4))
        lot.put(M["ronge"], pointe(P(0.0, s * 0.36, 0.2), G.norm((-0.8, s * 0.5, 0.5)), 0.28, 0.05, 4))
        if cracheur:
            continue
        # mandibule en crochet : s'écarte avec l'ouverture
        a = 0.25 + 0.7 * ouverture
        m0 = P(0.45, s * 0.22, -0.1)
        m1 = P(0.70, s * (0.22 + 0.18 * a), -0.12)
        m2 = P(0.86, s * (0.10 + 0.20 * a), -0.14)
        lot.put(M["os"], G.tube([m0, m1, m2], 0.04, 5))
        lot.put(M["os"], pointe(m2, G.norm(G.sub(m2, m1)), 0.14, 0.04, 4))
    if cracheur:
        # BOUCHE DE CRACHAT : trompe d'os annelée qui se dresse à l'attaque, goutte d'acide au bout qui grossit
        b0, b1, b2 = P(0.45, 0.0, -0.02), P(0.72, 0.0, 0.02 + 0.06 * ouverture), P(0.95, 0.0, 0.10 + 0.14 * ouverture)
        lot.put(M["os"], G.tube([b0, b1, b2], 0.075, 7))
        for q in (0.3, 0.6, 0.9):
            lot.put(M["ronge"], G.sphere(G.lerp(b0, b2, q), 0.088, 7, 3))
        lot.put(M["acide"], G.sphere(b2, 0.065 + 0.10 * ouverture, 10, 5))
        lot.put(M["bave"], G.tube([b2, G.add(b2, (0.02, 0.0, -0.15)), G.add(b2, (0.03, 0.0, -0.3 + 0.1 * ouverture))], 0.02, 5))
        return
    # gueule d'acide (grossit à l'attaque) et bave qui pend
    g = P(0.55, 0.0, -0.12)
    lot.put(M["acide"], G.sphere(g, 0.08 + 0.08 * ouverture, 8, 4))
    lot.put(M["bave"], G.tube([g, G.add(g, (0.02, 0.0, -0.18)), G.add(g, (0.0, 0.0, -0.32 - 0.2 * ouverture))], 0.02, 5))


# CADAVRE (s43) : une pièce fixe par direction (batch_titans --piece mort) : la carcasse affalée, pattes repliées, poches crevées,
# flaque d'acide au sol ; lue par prototypes/corps3d.lua (corpse.animation).
PIECES = {"mort": {}}
COMP = float(os.environ.get("FO_CO_COMP", "0.0"))   # recul du corps par unité d'ouverture à l'attaque (tuiles)
LUNGE = float(os.environ.get("FO_CO_LUNGE", "0.08"))  # avancée de la tête à l'attaque (0,25 avant : gigue de 0,06 à 0,11 tuile en vue de face)
PLONGE = float(os.environ.get("FO_CO_PLONGE", "0.06"))  # descente de la tête à l'attaque (0,15 avant)
CRACHEUR = False          # corroder_cracheur.py le met à True (variante cracheur : poche dorsale et trompe de crachat)


def build(S, lot, u=0.0, attaque=None, mort=0.0):
    """Pose du Corroder : u = phase de course ; attaque = phase d'attaque (0 à 1) ou None ; mort = avancée de la chute (0 vivant,
    1 carcasse : corps affalé, pattes repliées, poches crevées, flaque)."""
    cracheur = CRACHEUR
    M = matieres(S)
    R.raz()
    m = float(mort or 0.0)
    if m > 0:
        e = m * m * (3.0 - 2.0 * m)       # chute qui s'accélère puis se pose
        bob, ouverture, gonfle, lunge = -0.42 * e, 0.1 + 0.5 * e, -0.9 * e, 0.0
        u = 0.0
    elif attaque is None:
        bob = 0.03 * math.sin(G.TAU * 2.0 * u)
        ouverture, gonfle, lunge = 0.1, 0.0, 0.0
    else:
        bob, u = 0.0, 0.0
        ouverture = math.sin(math.pi * min(1.0, attaque * 1.4))
        gonfle = math.sin(math.pi * attaque)
        lunge = LUNGE * ouverture
    # s43 tranche 4 : GIGUE d'attaque : la tête plonge et s'avance (lunge, ouverture) ; le corps (et les hanches) reculent pour que
    # le centre de masse de l'image reste en place (pieds plantés : les pattes absorbent) ; COMP mesuré sur les feuilles (gigue.py)
    dx = -COMP * ouverture if (attaque is not None and m == 0) else 0.0
    pts, prof = corps(lot, M, u, bob, gonfle, cracheur, dx)
    # six pattes : tripode alterné (AG, MD, PG) puis (AD, MG, PD) ; carcasse : pattes repliées vers le haut
    for nom, x, ph, avant in (("A", 0.55, 0.0, True), ("M", -0.05, 0.5, True), ("P", -0.65, 0.0, False)):
        for s in (-1, 1):
            p_ = ph if s > 0 else ph + 0.5
            if attaque is not None or m > 0:
                p_ = 0.15 if s > 0 else 0.4
            hanche = (x + dx, s * 0.5, 0.62 + bob)
            pied = (x + (0.25 if avant else -0.2), s * 1.05, 0.0)
            if m > 0:
                pm = (x + 0.15 * ((ord(nom) + s) % 3 - 1), s * 1.05, 0.75)
                pied = G.lerp(pied, pm, e)
            patte(lot, M, hanche, pied, u + p_, s, 0.62, 0.78, avant)
    nk = pts[-1]
    plonge = 0.15 if m > 0 else PLONGE
    tete(lot, M, (nk[0] + 0.15 + lunge, nk[1], nk[2] - 0.05 - plonge * ouverture), ouverture, cracheur)
    if m > 0:
        # flaque d'acide sous la carcasse, qui s'étale pendant la chute (lueur faible, le prototype la dose)
        rf = 0.8 * (0.3 + 0.7 * m)
        lot.put(M["flaque"], G.tour([(0.0, 0.0), (0.0, rf), (0.015, rf * 0.9), (0.02, 0.0)], 18, "z", (-0.1, 0.05, 0.0)))
    return {"pieces": lot.n, "u": u, "attaque": attaque}


def build_anime(S, lot, stage, u, attaque):
    """Entrée commune des titans animés (batch_titans.anime) : une seule série (les variantes sont des teintes et des tailles du jeu)."""
    return build(S, lot, u, attaque)


def build_mort(S, lot, stage, u):
    """Animation de MORT (batch_titans --anim mort, SERIE["mort"] images) : image i -> chute (i + 1) / n ; la dernière est la carcasse."""
    n = SERIE["mort"]
    return build(S, lot, mort=(round(u * n) + 1) / float(n))


def build_piece(S, lot, stage, piece):
    """Pièce fixe (batch_titans --piece) : la carcasse."""
    return build(S, lot, mort=1.0)