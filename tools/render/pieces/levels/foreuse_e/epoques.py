"""REGISTRE DES ÂGES et CONTRAT des modules epNN.py de la FOREUSE ÉLECTRIQUE (lot F4-A, 25/10). Python pur (importable
hors Blender). Fiches des 15 âges : fo-logs/2026-10-25_F4/FICHES_FOREUSE.md (fait foi).

La foreuse reprend la méthode de la mitrailleuse validée (kit commun ../commun, palettes d'âge commun/ages.py) avec SON
corps de lignée (corps.py) : TABLIER carré au motif du pont de l'âge, 4 MONTANTS d'angle, PUITS au centre, GOULOTTE de
sortie vers le point de dépôt (flèche lumineuse : signal de jeu fixe), MOTEUR à l'arrière, RACCORDS du fluide de minage
sur les 3 autres côtés (positions exactes du prototype), TRÉPAN au centre ; et la TOUR, organe de l'âge, centrée sur le
puits, symétrique d'ordre 4 (son sommet est le même dans les 4 directions : la pièce du niveau pair s'y pose et n'est
rendue qu'UNE fois).

4 DIRECTIONS : le corps est rendu pour N, E, S, O (variantes eNN-N, eNN-E, eNN-S, eNN-O) ; corps.repere() construit TOUT
dans le repère des tuiles (cotes.py) puis tourne d'un quart de tour et étire y de √2 : le rendu E est le rendu N tourné
dans le plan des tuiles, comme le moteur tourne les points de jeu. La lumière (ouest) ne tourne pas.

Un module d'âge epNN.py (N = 2 à 15) donne :
  EPOQUE, NOM = ages.NOMS[N], TRIPLET (= TRIPLETS[N]), FOYER = ages.FOYER[N] (même lumière que la mitrailleuse) ;
  HABILLAGE = dict(ages.CORPS[N], …)      matière de TOUT le corps (clés communes) + clés propres (ci-dessous) ;
  def matieres(metal, M)                  ages.matieres(N, metal, M) d'abord, puis ses alias et matières propres ;
  def tour(g, c)        OBLIGATOIRE : la TOUR de l'âge, du dessus du tablier (c.zt) à c.H, centrée, symétrique
                        d'ordre 4, pied dans le carré ±c.rt ; ce qui monte à l'écran au-dessus du bord arrière du
                        tablier (z > c.T["z_treillis_max"]) doit être PLEIN (aucun treillis ouvert sur le sol) ;
  def piece(g, c)       OBLIGATOIRE : pièce du niveau pair, posée SUR le sommet (0, 0, c.H), symétrique d'ordre 4,
                        rendue une fois pour les 4 directions ; elle DÉPASSE la silhouette (F42) ;
  def socle(g, c)       facultatif : accents du tablier (réservoirs, caisses, voyants, câbles) après la lignée ;
  def trepan(g, c)      facultatif : remplace le trépan de la lignée (tige, tête) ; même axe, même puits ;
  def moteur(g, c)      facultatif : remplace le moteur de la lignée (même place, c.T["moteur"]) ;
  def montant(g, c, x, y)  facultatif : remplace un montant d'angle (même place, même encombrement ± 25 %) ;
  def liaison(g, pts, r)   facultatif : organe de liaison de l'âge (raccords du fluide de minage, gaines) ;
  def goulotte(g, c)    facultatif : ACCENTS de la goulotte (jamais la goulotte elle-même : signal de jeu).
c (corps.Ctx) porte : g, M, Mh (palette habillée), e, ep, side, T (cotes.taille), hab, d (direction), et raccourcis
zt, H, rt, rw, a (demi-côté), dd (demi-côté du tablier).

HABILLAGE : clés communes (commun/habillage.py : capots → montants, moteur, capots de la lignée ; plateforme → dessus du
tablier ; acier, rivets, joints, danger → lèvre de la goulotte, peinture) ; clés PROPRES à la foreuse :
  goulotte_mat  matière de la goulotte (défaut : acier de structure habillé) ;
  puits_mat     matière de la margelle du puits (défaut : acier sombre habillé) ;
  forme_tablier None (carré) | "rond" | "octogone" : forme du tablier dans l'emprise carrée (ronde 2 : le DC a jugé
                l'assembleur « tous carrés » ; deux âges voisins de même taille n'ont pas la même forme).
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

# emprise par âge (shared/levels/config.lua, L.footprints : drill = { era = { 3, 4, 5, 6, 6 } } ; une ère = 3 âges)
COTE = {0: None, 1: 3, 2: 3, 3: 3, 4: 4, 5: 4, 6: 4, 7: 5, 8: 5, 9: 5, 10: 6, 11: 6, 12: 6, 13: 6, 14: 6, 15: 6}
ERE = ages.ERE
NOMS = ages.NOMS
FAMILLES = ages.FAMILLES
DIRECTIONS = ("N", "E", "S", "O")
# angle de la rotation de la foreuse (repère des tuiles, radians, sens trigonométrique) : N 0, E −90°, S 180°, O +90°
ANGLE = {"N": 0.0, "E": -1.5707963267948966, "S": 3.141592653589793, "O": 1.5707963267948966}
VANILLA_DIR = {"N": "north", "E": "east", "S": "south", "O": "west"}

HABILLAGE_DEFAUT = dict(
    **_H.HABILLAGE_LIGNEE,     # capots, plateforme, acier, rivets, joints, danger, peinture (commun)
    goulotte_mat=None,
    puits_mat=None,
    forme_tablier=None,        # None ou "carre" | "rond" | "octogone" (ronde 2, critique du DC : « tous carrés »)
)
FORMES_TABLIER = ("carre", "rond", "octogone")

# LECTURE « EN 3 MOTS » DE LA FOREUSE (fiches : fo-logs/2026-10-25_F4/FICHES_FOREUSE.md) : propre à la foreuse (nomme
# sa tour ou son trépan), tous distincts (aucun mot répété : tests/test_foreuse.py) ; chaque mot nomme ce qui se voit au
# zoom 1 en pose N ou E. Un fichier d'âge écrit le sien dans TRIPLET (contrôle : égal).
TRIPLETS = {
    1: ("chèvre de bois", "poulie", "lanterne"),
    2: ("balancier", "massif de briques", "foyer rouge"),
    3: ("chaudière de cuivre", "volant", "pistons"),
    4: ("derrick", "râtelier de tiges", "torchère"),
    5: ("cloche blindée", "lance thermique", "scories"),
    6: ("pylône", "électrodes", "moteur bleu"),
    7: ("diapason", "dallage de pierre", "cristaux dressés"),
    8: ("bocal de verre", "boue jaune", "ponton"),
    9: ("silo de béton", "chemise de plomb", "lueur verte"),
    10: ("portique", "colonne lisse", "bras articulés"),
    11: ("tripode", "ailerons", "balises orange"),
    12: ("pile de tores", "cryostat", "glace cyan"),
    13: ("bobinages", "bouteilles couchées", "puits violet"),
    14: ("anneau vertical", "horizon étoilé", "piliers lunaires"),
    15: ("singularité", "spirale d'or", "couronne noire"),
}

# TEINTE DU NIVEAU PAIR (ronde F4-A2, DC : niveau pair « plus distinct ») : le prototype du niveau 2N multiplie le corps
# par cette teinte (couleur du foyer de l'âge mêlée de blanc, 22 % : une teinte ne fait que MULTIPLIER, F36) ; la pièce
# paire, elle, garde ses couleurs. Les planches l'appliquent hors moteur (profil.level_layers).
def teinte_pair(e):
    rgb = ages.FOYER.get(e, {}).get("rgb") or (1.0, 1.0, 1.0)
    return tuple(round(0.78 + 0.22 * v, 4) for v in rgb)


TEINTE_PAIR = {e: teinte_pair(e) for e in range(1, 16)}

# trous enfermés VOULUS (ilots.py) : {(âge, « corps » | « compo »): [(x, y, rayon) en tuiles depuis le centre]} ; aucun
TROUS_VOULUS = {}


def module(e):
    """Module de l'âge e (ep00 à ep15), contrôlé contre le contrat."""
    m = importlib.import_module("ep%02d" % e)
    besoin = ["NOM", "FOYER", "piece"] if e == 1 else ["NOM", "FOYER", "tour", "piece"]
    manque = [k for k in besoin if not hasattr(m, k)]
    if manque:
        raise AttributeError("foreuse ep%02d : il manque %s" % (e, ", ".join(manque)))
    if e >= 1 and getattr(m, "TRIPLET", TRIPLETS[e]) != TRIPLETS[e]:
        raise ValueError("foreuse ep%02d : TRIPLET %r différent de epoques.TRIPLETS (%r)" % (e, m.TRIPLET, TRIPLETS[e]))
    return m


def habillage(ep):
    """Habillage complet de l'âge (HABILLAGE_DEFAUT complété par ep.HABILLAGE ; clé inconnue : KeyError)."""
    h = _H.habillage(ep, HABILLAGE_DEFAUT)
    if h["forme_tablier"] is not None and h["forme_tablier"] not in FORMES_TABLIER:
        raise ValueError("forme_tablier %r inconnue (%s)" % (h["forme_tablier"], ", ".join(FORMES_TABLIER)))
    return h


ages.verifier_familles()
