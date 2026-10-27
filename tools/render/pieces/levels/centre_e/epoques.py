"""REGISTRE DES ÂGES et CONTRAT des modules epNN.py du CENTRE DE COMMANDEMENT (lot F5-A, 27/10). Python pur
(importable hors Blender par les outils et les tests).

Pourquoi (Directeur Créatif, 25/10 vers 10 h, OBJECTIFS §5) : « Le fait que seule la teinte change […] c'est complètement
à bannir. » Le centre a 15 NIVEAUX = 15 ÂGES (shared/levels/config.lua : command, max = 15) : 15 silhouettes complètes,
aucune pièce paire. Bible des familles (fo-logs/2026-10-23_plan-suite/familles.md §1.1) : corps de lignée = BASTION À
ÉTAGES, PORTE BLINDÉE AU SUD, SATELLITES de la mitrailleuse ; organe principal = MÂT DE COMMANDEMENT, sa tête et la porte ;
organe de liaison = conduits et câbles de façade, passerelles ; ère V (§1.3) : 13 cuve de confinement ceinte de bouteilles
couchées, 14 grand anneau de la Porte sur pieds, 15 sphère noire au sommet, disque en segments sur entretoises.

Corps de lignée (corps.py), vu de trois quarts : SOCLE carré (rond ou octogonal selon le plan) au motif du pont de
l'âge ; ÉTAGES (2 ou 3) en retrait, de PLAN d'âge ; TOIT de l'âge sur le dernier étage ; MÂT de l'âge au sommet ; PORTE
blindée au milieu de la face SUD du premier étage (signal de jeu FIXE : bandes de danger, feu au linteau, rampe) ;
SATELLITES (petites tourelles aux coins avant du socle, aux quatre coins dès 6×6) ; FAÇADE (fenêtres éclairées, conduits
d'angle) ; GARDE-CORPS sur la terrasse du premier étage ; FEUX aux coins du socle ; DÉTAIL FIN semé sur le socle libre
(leçon de la foreuse F4-A3 : la densité de petites pièces se joue au détail fin).

Un module d'âge epNN.py (N = 1 à 15) :
  EPOQUE, NOM, TRIPLET (lecture « en 3 mots », TRIPLETS ci-dessous), FOYER = ages.FOYER[N], HABILLAGE = dict(...),
  def matieres(metal, M) (ages.matieres(N, ...) d'abord) ;
  def mat(g, c, z) : le MÂT DE COMMANDEMENT et sa tête, posé au sommet (0, 0, z) du dernier étage (OBLIGATOIRE) ;
  facultatifs : def socle(g, c) (signatures de l'âge sur le socle), def satellite(g, c, x, y, z, k) (tourelle de l'âge),
  def porte(g, c, y, z) (décor de la porte), def facade(g, c) (décor des étages).
HABILLAGE, clés propres au centre :
  plan      "carre" | "tours" (carré à 4 tours d'angle) | "rond" | "octo" | "croix" ;
  etages    2 ou 3 ;
  toit      "plat" (parapet) | "crenele" (merlons) | "coupole" | "pans" (deux pans) | "gradins" ;
  mat_e1, mat_e2, mat_e3 : matière (clé de M) des étages (None : capots olive, ocre, olive de la lignée) ;
  mat_toit  : matière du toit (None : acier sombre).
Toutes à None : témoin de la lignée (ep00, variantes kS-centre).
"""
import importlib
import os
import sys

_ICI = os.path.dirname(os.path.abspath(__file__))
COMMUN = os.path.join(os.path.dirname(_ICI), "commun")
for _d in (COMMUN, _ICI):
    if _d not in sys.path:
        sys.path.insert(0, _d)
import ages  # noqa: E402
import habillage as _H  # noqa: E402

# emprise du centre (shared/levels/config.lua, L.footprints : command = { era = { 4, 5, 6, 7, 8 } }) : niveau = âge
COTE = {0: None, 1: 4, 2: 4, 3: 4, 4: 5, 5: 5, 6: 5, 7: 6, 8: 6, 9: 6, 10: 7, 11: 7, 12: 7, 13: 8, 14: 8, 15: 8}
ERE = ages.ERE
NOMS = ages.NOMS
FAMILLES = ages.FAMILLES

PLANS = ("carre", "tours", "rond", "octo", "croix")
TOITS = ("plat", "crenele", "coupole", "pans", "gradins")

HABILLAGE_DEFAUT = dict(
    **_H.HABILLAGE_LIGNEE,
    plan=None,
    etages=None,
    toit=None,
    mat_e1=None,
    mat_e2=None,
    mat_e3=None,
    mat_toit=None,
)

# LECTURE « EN 3 MOTS » DU CENTRE : un triplet par âge, aucun mot répété entre les 15 (tests/test_centre.py).
TRIPLETS = {
    1: ("palissade", "tour de guet", "fanion"),
    2: ("donjon de briques", "beffroi", "brasero"),
    3: ("rotonde de cuivre", "horloge", "sifflet"),
    4: ("QG jaune", "mât radio", "torchère"),
    5: ("citadelle de basalte", "obélisque", "lave"),
    6: ("tour Tesla", "isolateurs", "arcs bleus"),
    7: ("ziggourat", "cristal géant", "griffes de bronze"),
    8: ("pilotis", "serre", "bocal vert"),
    9: ("bunker", "dôme de confinement", "radôme"),
    10: ("tour de contrôle", "paraboles", "vitrage"),
    11: ("radar tournant", "fuseau", "ailerons orange"),
    12: ("anneau supraconducteur", "givre", "voyants cyan"),
    13: ("cuve de confinement", "bouteilles couchées", "éclairs violets"),
    14: ("anneau de la Porte", "horizon étoilé", "pieds lunaires"),
    15: ("sphère noire", "disque segmenté", "entretoises d'or"),
}

# (plan, étages, toit) des 15 âges : recopiés des fichiers d'âge (contrôle : test). Deux âges VOISINS de même taille
# n'ont jamais le même plan.
SILHOUETTES = {
    1: ("carre", 2, "pans"),
    2: ("tours", 2, "crenele"),
    3: ("rond", 2, "coupole"),
    4: ("carre", 3, "plat"),
    5: ("octo", 2, "crenele"),
    6: ("croix", 2, "plat"),
    7: ("rond", 3, "gradins"),
    8: ("carre", 2, "pans"),
    9: ("octo", 2, "coupole"),
    10: ("carre", 3, "plat"),
    11: ("rond", 2, "plat"),
    12: ("octo", 3, "plat"),
    13: ("croix", 2, "plat"),
    14: ("rond", 2, "plat"),
    15: ("octo", 3, "plat"),
}

# trous enfermés VOULUS : {(âge, « centre » | « compo »): [(x, y, rayon) en tuiles depuis le centre]} (aucun en ronde 1)
TROUS_VOULUS = {}


def module(e):
    """Module de l'âge e (ep00 à ep15), contrôlé contre le contrat."""
    m = importlib.import_module("ep%02d" % e)
    manque = [k for k in ("NOM", "FOYER", "mat") if not hasattr(m, k)]
    if manque:
        raise AttributeError("centre ep%02d : il manque %s" % (e, ", ".join(manque)))
    if e >= 1 and getattr(m, "TRIPLET", TRIPLETS[e]) != TRIPLETS[e]:
        raise ValueError("centre ep%02d : TRIPLET %r différent de epoques.TRIPLETS (%r)" % (e, m.TRIPLET, TRIPLETS[e]))
    return m


def habillage(ep):
    """Habillage complet de l'âge (HABILLAGE_DEFAUT complété par ep.HABILLAGE), formes contrôlées."""
    h = _H.habillage(ep, HABILLAGE_DEFAUT)
    if h["plan"] is not None and h["plan"] not in PLANS:
        raise ValueError("plan %r inconnu (%s)" % (h["plan"], ", ".join(PLANS)))
    if h["toit"] is not None and h["toit"] not in TOITS:
        raise ValueError("toit %r inconnu (%s)" % (h["toit"], ", ".join(TOITS)))
    if h["etages"] is not None and h["etages"] not in (2, 3):
        raise ValueError("etages %r : 2 ou 3" % (h["etages"],))
    return h


def silhouette(hab):
    return (hab["plan"] or "carre", hab["etages"] or 2, hab["toit"] or "plat")


ages.verifier_familles()
