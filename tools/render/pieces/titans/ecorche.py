"""ÉCORCHÉS, mordeurs MUTANTS (lot KAIJUS-MUTANTS, 10/11) : la lignée que pond l'Écorcheur (ecorcheur.py) et que les nids proposent tard dans
l'évolution. Quadrupèdes de chair mauve écorchée, plaques sombres, cristaux bleu glacier (cohérence du Kaiju), conduits turquoise, cœur
lumineux dans la gueule. TROIS variantes (le « stade » du rendu = la variante, shared/robots/titans.lua T.ECORCHE.variants) :
  1 RÔDEUR : fin, haut sur pattes, rapide, peu de cristaux ;
  2 PORTEUR : trapu, dos chargé d'un amas de cristaux et de plaques (blindé) ;
  3 HURLEUR : tête énorme, gueule béante à cœur lumineux, crête d'os ; son cri frappe en zone (règle).
Modèle paramétrique low-poly ANIMÉ comme le Kaiju : `build_anime(S, lot, variante, u, attaque)`. Repère LOCAL : +x = avant, +y = gauche,
+z = haut ; origine = sous le centre du corps, au sol. Environ 4 tuiles du museau à la queue, 2 de haut (un titan parmi les mordeurs).
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

PREFIX = "em_"
GRIS = os.environ.get("FO_GRIS", "") == "1"
SERIE = {"course": 8, "attaque": 4, "densite": 32.0, "R": 3.2, "zmax": 3.2, "sol": 40.0}
AO = 0.3
GLOW_BLANC = True
AMP = 0.75
FOULEE = 2 * 0.75
# variante : (longueur du corps, hauteur au garrot, largeur, longueur de patte, cristaux (nombre, longueur), masse de la tête)
# Lot VISUELS-DISTINCTS (10/11) : les trois variantes se confondaient de loin (même chair mauve, même gabarit) ; chacune a désormais sa
# CHAIR et sa PEAU (couleurs de surface, ci-dessous) et son trait de silhouette : rôdeur FIN et CLAIR (corps étroit, hautes pattes,
# chair os pâle), porteur MASSIF et SOMBRE (large, plaques argent sur tout le dos), hurleur à COLLERETTE lumineuse (épines émissives
# autour de la nuque). La LUEUR en jeu est la couleur de la variante (shared/robots/titans.lua T.ECORCHE.variants[i].lueur).
VARIANTES = {
    1: {"L": 2.6, "h": 1.55, "w": 0.42, "patte": 1.65, "cristaux": (3, 0.45), "tete": 0.7, "plaques": 0.0,
        "chair": (0.78, 0.66, 0.68), "peau": (0.70, 0.64, 0.68), "collerette": 0},
    2: {"L": 3.0, "h": 1.25, "w": 1.0, "patte": 1.05, "cristaux": (7, 0.9), "tete": 0.9, "plaques": 1.0,
        "chair": (0.10, 0.035, 0.06), "peau": (0.07, 0.05, 0.065), "collerette": 0},
    3: {"L": 2.7, "h": 1.4, "w": 0.65, "patte": 1.3, "cristaux": (4, 0.6), "tete": 1.25, "plaques": 0.4,
        "chair": (0.40, 0.14, 0.25), "peau": (0.25, 0.15, 0.21), "collerette": 9},
}


def corps(lot, M, V, u, bob, cri):
    """Corps : loft de la queue à la nuque, plaques dorsales (porteur), épines de cristal, conduits de flanc ; amas de cristaux du porteur."""
    L, h, w = V["L"], V["h"], V["w"]
    sw = 0.08 * math.sin(G.TAU * u)
    ctrl = [(-L * 0.55, -sw * 1.5, h * 0.55), (-L * 0.3, -sw * 0.8, h * 0.75 + bob * 0.5), (0.0, 0.0, h * 0.85 + bob), (L * 0.25, 0.0, h * 0.9 + bob),
            (L * 0.45, 0.0, h * 0.95 + bob)]
    pts = G.catmull(ctrl, 5)
    n = len(pts)
    rings, prof = [], []
    for i, p in enumerate(pts):
        t = i / float(n - 1)
        if t < 0.35:
            rw, rh = 0.1 + (w - 0.1) * (t / 0.35) ** 1.3, 0.1 + (h * 0.4 - 0.1) * (t / 0.35) ** 1.3
        else:
            k = (t - 0.35) / 0.65
            rw, rh = w * (1.0 + 0.15 * math.sin(math.pi * k)) - 0.2 * k * w, h * 0.4 * (1.0 + 0.2 * math.sin(math.pi * k)) - 0.1 * k * h
        rings.append(ellipse(p, rw, rh, 8))
        prof.append((p, rw, rh, t))
    lot.put(M["chair"], G.loft(rings, True, True))
    for i in range(2, n - 2, 2):
        p, rw, rh, t = prof[i]
        d = G.norm(G.sub(pts[i + 1], pts[i - 1]))
        if t > 0.3:
            for s in (-1, 1):
                lot.put(M["peau"], plaque((p[0], p[1] + s * rw * 0.85, p[2] + rh * 0.3), G.norm((0.0, s * 0.9, 0.4)), 0.3, 0.42, 0.06, up=d, coins=0.6))
            if V["plaques"] > 0 and (V["plaques"] >= 1.0 or i % 4 == 2):   # porteur : une plaque à chaque anneau
                # porteur : plaques SOMBRES (struct) à chaque anneau, la masse lue noire de loin ; hurleur : plaques argent d'avant
                lot.put(M["struct" if V["plaques"] >= 1.0 else "blind2"], plaque((p[0], p[1], p[2] + rh * 0.9), (0.0, 0.0, 1.0), rw * 1.6, 0.5, 0.08,
                                                                              up=d, coins=0.65))
    nc, lc = V["cristaux"]
    for k in range(nc):
        t = 0.3 + 0.55 * (k + 0.5) / nc
        i = min(n - 2, int(t * (n - 1)))
        p, rw, rh, _ = prof[i]
        d = G.norm(G.sub(pts[i + 1], pts[i - 1]))
        Lc = lc * (0.7 + 0.6 * math.sin(math.pi * (k + 0.5) / nc))
        lot.put(M["cristal"], pointe((p[0], p[1], p[2] + rh * 0.9), G.norm((-0.6 * d[0], 0.0, 1.0)), Lc, 0.07 + 0.06 * Lc))
        if V["plaques"] >= 1.0:
            for s in (-1, 1):
                lot.put(M["cristal"], pointe((p[0] - 0.1, p[1] + s * rw * 0.5, p[2] + rh * 0.7), G.norm((-0.4, s * 0.8, 0.7)), Lc * 0.6, 0.08))
    for s in (-1, 1):
        line = [(pts[i][0], pts[i][1] + s * prof[i][1] * 0.95, pts[i][2] + prof[i][2] * 0.05) for i in range(int(n * 0.3), n - 1, 2)]
        lot.put(M["turq"], G.tube(line, 0.035, 5))
    # bout de la queue : pointe de cristal
    lot.put(M["cristal"], pointe(pts[0], G.norm(G.sub(pts[0], pts[2])), 0.45, 0.07))
    return pts, prof


def patte(lot, M, V, hanche, pied0, u, avant, s):
    """Patte sprawlée : cuisse (chair), tibia (os), pied à trois griffes."""
    dx, dz = pas(u, AMP, 0.35)
    pied = (pied0[0] + dx, pied0[1], pied0[2] + dz)
    l1 = l2 = V["patte"] * 0.56
    pole = G.norm((0.8 if avant else -0.8, s * 1.0, 0.3))
    genou = ik2(hanche, pied, l1, l2, pole)
    lot.put(M["chair"], G.sphere(hanche, 0.2, 8, 4))
    lot.put(M["chair"], hexseg(hanche, genou, 0.2, 0.13, 6, 0.1))
    lot.put(M["struct"], G.sphere(genou, 0.12, 6, 3))
    lot.put(M["os"], hexseg(genou, pied, 0.11, 0.07, 6, 0.1))
    lot.put(M["turq"], hexseg(G.add(hanche, (0.05, s * 0.18, -0.05)), G.add(genou, (0.02, s * 0.1, 0.02)), 0.025, 0.02))
    for ay in (0.0, 0.5, -0.5):
        lot.put(M["os"], pointe((pied[0] + 0.05, pied[1] + ay * 0.1, pied[2] + 0.05), G.norm((1.0, ay * 0.8, -0.3)), 0.28 if ay == 0 else 0.22, 0.045, 4))


def tete(lot, M, V, base, ouverture, cri):
    """Tête : crâne (loft), mâchoire ouverte sur un cœur lumineux, yeux, crête d'os (hurleur) ; `cri` : la gueule s'ouvre grand."""
    k = V["tete"]
    bx, by, bz = base
    def P(x, y, z):
        return (bx + x * k, by + y * k, bz + z * k)
    def sect(x, w, h, zc):
        return [P(x, -w, zc - h * 0.5), P(x, -w * 0.7, zc + h * 0.7), P(x, 0.0, zc + h), P(x, w * 0.7, zc + h * 0.7), P(x, w, zc - h * 0.5),
                P(x, w * 0.4, zc - h * 0.65), P(x, -w * 0.4, zc - h * 0.65)]
    lot.put(M["peau"], G.loft([sect(-0.2, 0.42, 0.36, 0.1), sect(0.35, 0.45, 0.38, 0.12), sect(0.8, 0.34, 0.26, 0.08), sect(1.15, 0.16, 0.1, 0.0)], True, True))
    ang = 0.75 * ouverture
    def J(x, y, z):
        xx = x - 0.1
        return P(0.1 + xx * math.cos(ang) + z * math.sin(ang), y, -xx * math.sin(ang) + z * math.cos(ang))
    jaw = [[J(0.1, -0.34, -0.14), J(0.1, 0.34, -0.14), J(0.1, 0.22, -0.32), J(0.1, -0.22, -0.32)],
           [J(0.7, -0.26, -0.16), J(0.7, 0.26, -0.16), J(0.7, 0.16, -0.3), J(0.7, -0.16, -0.3)],
           [J(1.1, -0.1, -0.12), J(1.1, 0.1, -0.12), J(1.1, 0.07, -0.2), J(1.1, -0.07, -0.2)]]
    lot.put(M["peau"], G.loft(jaw, True, True))
    for q in range(3):
        x = 0.3 + 0.28 * q
        for s in (-1, 1):
            lot.put(M["os"], pointe(P(x, s * (0.3 - 0.06 * q), -0.14), (0.0, 0.0, -1.0), 0.16, 0.035, 4))
            lot.put(M["os"], pointe(J(x, s * (0.22 - 0.04 * q), -0.16), (0.0, 0.0, 1.0), 0.13, 0.03, 4))
    rv = 0.1 + 0.12 * ouverture + 0.08 * cri
    lot.put(M["coeur"], G.sphere(P(0.4, 0.0, -0.12 - 0.1 * ouverture), rv, 8, 4))
    lot.put(M["halo"], G.sphere(P(0.5, 0.0, -0.12 - 0.1 * ouverture), rv * 1.7, 8, 4))
    for s in (-1, 1):
        lot.put(M["conduit"], G.boite(P(0.45, s * 0.4, 0.2), (0.08, 0.03, 0.05)))
        lot.put(M["os"], pointe(P(-0.1, s * 0.3, 0.3), G.norm((-0.7, s * 0.5, 0.6)), 0.4 * k, 0.05, 5))
    if V.get("collerette"):
        # collerette du hurleur : couronne d'épines émissives (couche lueur : teinte de la variante en jeu) autour de la nuque
        nc = V["collerette"]
        for q in range(nc):
            a = -math.pi * 0.85 + 1.7 * math.pi * q / (nc - 1)
            d = G.norm((-0.35, math.cos(a), math.sin(a) * 0.8 + 0.55))
            lot.put(M["accent"], pointe(P(-0.25, math.cos(a) * 0.32, 0.12 + math.sin(a) * 0.22), d, 0.55 * k, 0.05, 4))
        lot.put(M["accent"], G.tube([P(-0.25, math.cos(-math.pi * 0.85 + 1.7 * math.pi * q / 16.0) * 0.36,
                                       0.12 + math.sin(-math.pi * 0.85 + 1.7 * math.pi * q / 16.0) * 0.25) for q in range(17)], 0.035, 5))
    if V["tete"] > 1.0:
        for q in range(3):
            lot.put(M["os"], pointe(P(-0.15 - 0.12 * q, 0.0, 0.36 - 0.03 * q), G.norm((-0.6, 0.0, 1.0)), 0.55 - 0.1 * q, 0.06, 5))
    else:
        lot.put(M["cristal"], pointe(P(-0.1, 0.0, 0.35), G.norm((-0.5, 0.0, 1.0)), 0.4, 0.06))


def build_anime(S, lot, stage, u, attaque):
    """Pose d'un Écorché de la variante `stage` (1 à 3) : u = phase de course ; attaque = phase d'attaque (0 à 1) ou None."""
    V = VARIANTES[int(stage) if stage else 1]
    M = TM.matieres(S, PREFIX, GRIS)
    if not GRIS:
        # chair et peau propres à la variante (VISUELS-DISTINCTS) : mêmes réglages que titans_mat, couleur de la variante
        M["peau"] = TM.MT.surface(PREFIX + "peau", V["peau"], rough=0.52, met=0.20, tole=(0.45, 0.28), joint=0.25, joint_l=0.03, var=0.18,
                                  usure=0.3, nu=tuple(min(1.0, c * 1.6 + 0.12) for c in V["peau"]), crasse=0.55,
                                  crasse_col=(0.03, 0.012, 0.025), relief=0.8, graine=16)
        M["chair"] = TM.MT.surface(PREFIX + "chair", V["chair"], rough=0.62, met=0.05, usure=0.15,
                                   nu=tuple(min(1.0, c * 1.4 + 0.1) for c in V["chair"]), crasse=0.5, crasse_col=(0.06, 0.015, 0.04), graine=18)
        TM.iridescence(M["peau"], part=0.35, blend=0.5)
    R.raz()
    L, h, w = V["L"], V["h"], V["w"]
    if attaque is not None:
        a = attaque
        ouverture, cri = min(1.0, a * 2.0 + 0.2), max(0.0, a - 0.3)
        bob, uu = 0.0, 0.0
        phase = {"AG": 0.1, "PD": 0.1, "AD": 0.4, "PG": 0.4}
    else:
        ouverture, cri = 0.15, 0.0
        bob = 0.06 * math.sin(G.TAU * 2.0 * u)
        uu = u
        phase = {"AG": 0.0, "PD": 0.0, "AD": 0.5, "PG": 0.5}
    pts, prof = corps(lot, M, V, uu, bob, cri)
    hz = h * 0.75 + bob
    hanches = {"AG": (L * 0.22, w * 0.85, hz), "AD": (L * 0.22, -w * 0.85, hz), "PG": (-L * 0.2, w * 0.8, hz - 0.05), "PD": (-L * 0.2, -w * 0.8, hz - 0.05)}
    pieds = {"AG": (L * 0.32, w * 1.5, 0.0), "AD": (L * 0.32, -w * 1.5, 0.0), "PG": (-L * 0.28, w * 1.45, 0.0), "PD": (-L * 0.28, -w * 1.45, 0.0)}
    for k in ("PG", "PD", "AG", "AD"):
        patte(lot, M, V, hanches[k], pieds[k], uu + phase[k], k[0] == "A", 1 if k[1] == "G" else -1)
    hd = pts[-1]
    tete(lot, M, V, (hd[0] + 0.05, hd[1], hd[2] + 0.05 - 0.2 * cri), ouverture, cri)
    return {"variante": stage, "pieces": lot.n, "u": u, "attaque": attaque}
