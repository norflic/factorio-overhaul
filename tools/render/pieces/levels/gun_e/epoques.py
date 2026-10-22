"""REGISTRE DES ÉPOQUES et CONTRAT des modules epNN.py (lot V3-E, quatrième passe, 23/10). Python pur (importable
hors Blender par les outils). FICHIER GELÉ pour les constructeurs.

Un module d'époque epNN.py (N = 2 à 15) ne remplit QUE les emplacements d'époque du catalogue (§A.2) : arme (E1),
tuyaux et grands volumes annexes (E2), accents et matières d'accent (E3, E4), foyers (E5), signatures et pièce du
niveau pair (E6). Le corps de lignée (corps.py), les matières du corps et les règles de reflets (kit.py), les formes
communes (formes.py) et les outils sont communs et gelés. Contrat :

  EPOQUE = N ; NOM = "…"
  FOYER = dict(rgb=(r, g, b) linéaire, rgb2=… facultatif (2e couleur), nuit=False, doux=dict(force=0.7, base=…))
          la couleur doit tomber, MESURÉE sur la couche glow (mesures.py), dans la famille FAMILLES[N] ;
  CANON = dict(L=…, nb=…, rb=…, rr=…)      longueur et nombre de tubes, rayon d'un tube, rayon du faisceau ;
  HABILLAGE = dict(…)                      facultatif : clés de HABILLAGE_DEFAUT (accents permis sur le corps) ;
  PLATEFORME = dict(chanfrein=…)           facultatif : chanfrein avant de la plateforme (remplissage, §A.5) ;
  def matieres(metal, M)                   facultatif : matières propres (metal(clé, couleur, …) de kit.materials) ;
  def socle(g, c)        après plateforme, colonne et trémie : grands volumes, liaisons, accents, foyers, halos ;
  def piece(g, c)        pièce du niveau pair, en paire aux coins avant (couche ajoutée au socle) ;
  def arme(g, c, x, sx)  posée sur le bras de tourillon de la lignée (x : axe du canon, sx : côté) ; RÈGLE D'OR 1 :
                         elle AJOUTE son organe à la rosette du kit (corps.rosette, corps.bouche, corps.canon_lignee),
                         elle ne la recouvre jamais ;
  def tete(g, c)         après le noyau et les deux armes : plaques, liaisons, viseurs, signature de coupole… ;
  def masque(g, c)       facultatif : remplace le masque avant de la lignée (corps.masque_lignee) ;
  def nacelle(g, c)      facultatif : organe dorsal sur la nacelle (défaut : 2 échappements, corps.echappements).
c (corps.Ctx) porte : g, M, e, ep, side, B (colonne), H (tête + CANON), T (cotes de la taille), rt, hab, et pour la
tête Pf, Nf (coupole), nac (bx, yb0, yb1, ztop, yc), tour (cx, cy, z du dessus du tourelleau).
Époque 1 (Pionnier) : le niveau 1 est la mitrailleuse vanilla ; ep01 ne fournit que piece() (niveau 2).
Époque 0 (ep00) : la LIGNÉE SEULE (témoin du kit, variantes kS-…), sans organe d'époque.
"""
import importlib

COTE = {0: None, 1: 2, 2: 2, 3: 2, 4: 3, 5: 3, 6: 3, 7: 4, 8: 4, 9: 4, 10: 5, 11: 5, 12: 5, 13: 6, 14: 6, 15: 6}
ERE = {e: (1 if e <= 3 else 2 if e <= 6 else 3 if e <= 9 else 4 if e <= 12 else 5) for e in range(1, 16)}
NOMS = {0: "Lignée seule", 1: "Pionnier", 2: "Forge", 3: "Vapeur", 4: "Pétrole", 5: "Volcan", 6: "Électricité",
        7: "Cristal", 8: "Marais", 9: "Atome", 10: "Haute technologie", 11: "Titane", 12: "Supraconducteurs",
        13: "Fusion", 14: "Orbite", 15: "Légende"}
# plage de chaque constructeur (fichiers epNN.py qu'il possède)
PLAGE_BASSE = tuple(range(1, 10))
PLAGE_HAUTE = tuple(range(10, 16))

# habillage du corps permis à une époque (accents, catalogue §A.1 « seulement l'habillage ») : nom de matière
HABILLAGE_DEFAUT = dict(
    jupe_cerclage="brass",     # deux cerclages de la jupe
    tremie=None,               # peinture de la trémie (None : ocre de la lignée)
    pochoirs=True,             # marquages au pochoir sur la face sud de la trémie
    munitions=None,            # (étui, balle) des bandes visibles dans la trémie (None : laiton et cuivre)
    grille_nacelle="steel",    # lamelles de la grille arrière de la nacelle (2×2 à 4×4)
    tourelleau="ochre",        # caisson du tourelleau
    chapeau="brass",           # chapeau boulonné du tourillon
)

# FAMILLES DE COULEUR DES FOYERS (règle d'or 3) : teinte (degrés, intervalle circulaire) et saturation MESURÉES sur la
# couche glow (moyenne pondérée, protocole des juges, mesures.py). Deux époques voisines n'ont jamais de famille
# compatible (teintes ET saturations qui se recouvrent). Saturation : « pâle » < 0,2 ; « moyenne » 0,2 à 0,5 ;
# « forte » > 0,5 (une couleur franche mesurée tombe vers 0,35 à 0,75 : les cœurs saturent vers le blanc).
# Couleurs du catalogue §A.3 en regard (albédos de départ) ; mesures de la passe 3 entre crochets.
FAMILLES = {
    1: dict(nom="lanterne (nuit seule)", teinte=(20, 50), sat=(0.0, 1.0), nuit=True, catalogue="FFB060"),
    2: dict(nom="rouge-orange de forge", teinte=(6, 22), sat=(0.5, 1.0), catalogue="FF6A20"),        # [28°, 0,63]
    3: dict(nom="ambre de vapeur", teinte=(36, 52), sat=(0.2, 0.5), catalogue="FFC060"),             # [40°, 0,37]
    4: dict(nom="orange de torchère", teinte=(24, 34), sat=(0.5, 1.0), catalogue="FF8C1A"),          # [38°, 0,67]
    5: dict(nom="rouge braise", teinte=(345, 14), sat=(0.5, 1.0), catalogue="FF4A10"),               # [25°, 0,74]
    6: dict(nom="cyan électrique", teinte=(186, 202), sat=(0.25, 1.0), catalogue="60D0FF"),          # [195°, 0,37]
    7: dict(nom="violet de cristal", teinte=(255, 290), sat=(0.25, 1.0), catalogue="B070FF"),        # [270°, 0,31]
    8: dict(nom="jaune-vert acide", teinte=(60, 88), sat=(0.4, 1.0), catalogue="A8FF3A"),            # [81°, 0,51]
    9: dict(nom="vert uranium", teinte=(100, 135), sat=(0.3, 1.0), catalogue="5CFF4A"),             # [111°, 0,44]
    10: dict(nom="bleu électronique", teinte=(204, 228), sat=(0.3, 1.0), catalogue="3AA8FF"),       # [197°, 0,40]
    11: dict(nom="blanc bleuté", teinte=(180, 232), sat=(0.0, 0.2), catalogue="BFE6FF"),             # [195°, 0,08]
    12: dict(nom="cyan glacé", teinte=(170, 190), sat=(0.3, 1.0), catalogue="4AF0FF"),               # [180°, 0,39]
    13: dict(nom="magenta de plasma", teinte=(300, 336), sat=(0.3, 1.0), catalogue="FF4FD8"),        # [328°, 0,37]
    14: dict(nom="rouge de balise", teinte=(346, 12), sat=(0.4, 1.0), catalogue="FF2A2A"),           # [357°, 0,52]
    15: dict(nom="blanc doré", teinte=(36, 62), sat=(0.0, 0.2), catalogue="FFF2C0"),                 # [47°, 0,13]
}


# trous enfermés VOULUS (sol visible à travers une arche, un anneau…), déclarés par l'intégrateur du kit à la demande
# d'un constructeur : {(époque, partie « socle » | « tete » | « compo »): [(x, y, rayon) en tuiles depuis le centre]}
TROUS_VOULUS = {}


def _arc(t):
    a, b = t
    return [(a, b)] if a <= b else [(a, 360.0), (0.0, b)]


def _recouvre(i1, i2):
    return any(a1 < b2 and a2 < b1 for a1, b1 in _arc(i1) for a2, b2 in _arc(i2))


def compatibles(e1, e2):
    """Vrai si les familles de e1 et e2 se recouvrent (même teinte possible ET même saturation possible)."""
    f1, f2 = FAMILLES[e1], FAMILLES[e2]
    if f1.get("nuit") or f2.get("nuit"):
        return False
    s1, s2 = f1["sat"], f2["sat"]
    return _recouvre(f1["teinte"], f2["teinte"]) and s1[0] < s2[1] and s2[0] < s1[1]


def verifier_familles():
    """Contrôle de la table : aucune paire de voisines compatible. Lève une erreur sinon."""
    pb = [(e, e + 1) for e in range(1, 15) if compatibles(e, e + 1)]
    if pb:
        raise ValueError("familles de foyers en doublon entre voisines : %s" % pb)
    return True


def dans_famille(e, teinte, sat):
    """La couleur mesurée (teinte en degrés, saturation) tombe-t-elle dans la famille de l'époque e ?"""
    f = FAMILLES[e]
    t_ok = any(a <= teinte % 360.0 <= b for a, b in _arc(f["teinte"]))
    return t_ok and f["sat"][0] <= sat <= f["sat"][1]


def module(e):
    """Module de l'époque e (ep00 à ep15), contrôlé contre le contrat."""
    m = importlib.import_module("ep%02d" % e)
    besoin = ["NOM", "FOYER", "piece"] if e == 1 else ["NOM", "FOYER", "socle", "piece", "arme", "tete"]
    manque = [k for k in besoin if not hasattr(m, k)]
    if manque:
        raise AttributeError("ep%02d : il manque %s" % (e, ", ".join(manque)))
    return m


def habillage(ep):
    h = dict(HABILLAGE_DEFAUT)
    for k, v in getattr(ep, "HABILLAGE", {}).items():
        if k not in h:
            raise KeyError("habillage inconnu : %s (permis : %s)" % (k, ", ".join(sorted(h))))
        h[k] = v
    return h


verifier_familles()
