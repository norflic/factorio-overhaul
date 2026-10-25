"""REGISTRE DES ÂGES et CONTRAT des modules epNN.py du FOUR (lot F2-A, 25/10). Python pur (importable hors Blender par
les outils). Fiches des 15 âges (font foi) : fo-logs/2026-10-25_F2/FICHES_FOUR.md.

Le four reprend la méthode de la mitrailleuse validée (kit commun ../commun, palettes d'âge commun/ages.py) avec SON
corps de lignée (corps.py), volontairement MINCE : une SOLE (dalle d'appui de toute l'emprise, motif du pont de l'âge),
le CAISSON DU FOYER et sa GUEULE au milieu de la face sud (signal de jeu fixe : « ça chauffe »), la BOUCHE DE FUMÉE
dans le quart arrière droit (signal de jeu fixe), les patins et les places. Tout le reste est l'ORGANE DE L'ÂGE : la
CHAMBRE DE CHAUFFE change de NATURE à chaque âge (hotte de forge, chaudière couchée, colonne à brûleurs, cratère, four
à arc, athanor, cloche de verre, bunker et tour de refroidissement, coque carénée, nacelle à réacteur, anneaux de
lévitation, sphère blindée, Porte dressée, vasque d'étoile captive) : c'est le rôle des canons de la mitrailleuse et
de l'émetteur du laser.

Un module d'âge epNN.py (N = 2 à 15) donne :
  EPOQUE = N ; NOM = ages.NOMS[N] ; TRIPLET = (« mot 1 », « mot 2 », « mot 3 ») : lecture « en 3 mots » propre au four
          (égal à TRIPLETS[N] ci-dessous) ;
  FOYER = ages.FOYER[N]                   même lumière que la mitrailleuse du même âge (familles : ages.FAMILLES) ;
  HABILLAGE = dict(ages.CORPS[N], …)      matière de TOUT le corps (clés communes) + clés propres au four ;
  def matieres(metal, M)                  ages.matieres(N, metal, M) d'abord, puis les alias de rôle ;
  def chambre(g, c)      OBLIGATOIRE : la chambre de chauffe de l'âge, dans l'enveloppe (cotes : x ±xa, yn de y_av à
                         y_ar, z ≤ zmax) ; elle pose sa face sud contre le caisson du foyer (corps.foyer le pose ensuite) ;
  def fumee(g, c)        OBLIGATOIRE : l'organe de fumée de l'âge (cheminée, torchère, fumerolle, tour de
                         refroidissement, évent…) ; il finit par corps.bouche_fumee(g, c, x, yn, z, r), qui relève la
                         bouche dans c.fumee ; règle : quart arrière droit (cotes.fumee_valide) ;
  def gueule(g, c, G)    facultatif : ornement de la gueule (arche, voussoirs, cristaux…) autour du caisson (G :
                         géométrie du caisson, corps.foyer) ; la bouche lumineuse reste celle de la lignée ;
  def socle(g, c)        facultatif : accents après la chambre, le foyer et la fumée (tablier, coins arrière…) ;
  def piece(g, c)        OBLIGATOIRE : pièce du niveau pair, en PAIRE sur les places avant (corps.coin(c, « coin_SO »)
                         et « coin_SE »), posée sur le tablier (aucun îlot détaché).
c (corps.Ctx) porte : g, M, Mh (palette habillée), e, ep, side, T (cotes.TAILLES[side]), hab, pont, fumee.

HABILLAGE (contrat commun : commun/habillage.py) : capots, acier, rivets, joints, danger, peinture, plateforme (motif du
tablier et des dessus). Clés PROPRES au four :
  gueule        None (« rect » : linteau droit) | « arche » (linteau en plein cintre) | « ronde » (hublot rond) : forme
                de la bouche ; la lumière, la grille et le caisson restent ceux de la lignée ;
  foyer         None (caisson aux capots de l'âge) | nom de matière : matière du caisson du foyer.
Toutes les clés à None : témoin de la lignée (ep00, variantes kS-…).
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

# même emprise que la mitrailleuse et le laser (shared/levels/config.lua, L.footprints : furnace 2, 3, 4, 5, 6)
COTE = {0: None, 1: 2, 2: 2, 3: 2, 4: 3, 5: 3, 6: 3, 7: 4, 8: 4, 9: 4, 10: 5, 11: 5, 12: 5, 13: 6, 14: 6, 15: 6}
ERE = ages.ERE
NOMS = ages.NOMS
FAMILLES = ages.FAMILLES

HABILLAGE_DEFAUT = dict(
    **_H.HABILLAGE_LIGNEE,     # capots, plateforme, acier, rivets, joints, danger, peinture (commun)
    gueule=None,               # forme de la bouche du foyer
    foyer=None,                # matière du caisson du foyer
)
FORMES_GUEULE = ("rect", "arche", "ronde")

# LECTURE « EN 3 MOTS » DU FOUR (fiches : fo-logs/2026-10-25_F2/FICHES_FOUR.md) : un triplet par âge, PROPRE au four (il
# nomme la chambre de l'âge), tous distincts, aucun mot répété (tests/test_four.py). Chaque mot nomme ce que montre la
# vignette au zoom 1 (pièce de 8 px au moins).
TRIPLETS = {
    1: ("four de série", "tuyau de poêle", "bûches"),
    2: ("hotte de fer", "briques rouges", "soufflet de cuir"),
    3: ("chaudière couchée", "dôme de vapeur", "cheminée cerclée"),
    4: ("colonne jaune", "brûleurs", "torchère"),
    5: ("cratère", "coulées de lave", "blocs de basalte"),
    6: ("trois électrodes", "cuve de porcelaine", "bras de cuivre"),
    7: ("athanor", "couronne de cristaux", "portail en arche"),
    8: ("cloche de verre", "bulles de gaz", "tuyaux vert-de-gris"),
    9: ("tour de refroidissement", "bunker", "hublots verts"),
    10: ("coque ivoire", "bandeau bleu", "ventilateurs"),
    11: ("nacelle à réacteur", "ailerons", "tuyère orange"),
    12: ("anneaux chromés", "creuset flottant", "givre"),
    13: ("sphère blindée", "bobines", "points violets"),
    14: ("anneau dressé", "ciel étoilé", "gradins indigo"),
    15: ("étoile captive", "vasque noire", "griffes d'or"),
}

# trous enfermés VOULUS : {(âge, « socle » | « compo »): [(x, y, rayon) en tuiles depuis le centre]} ; aucun à ce jour
TROUS_VOULUS = {}


def module(e):
    """Module de l'âge e (ep00 à ep15), contrôlé contre le contrat."""
    m = importlib.import_module("ep%02d" % e)
    besoin = ["NOM", "FOYER", "piece"] if e == 1 else ["NOM", "FOYER", "chambre", "fumee", "piece"]
    manque = [k for k in besoin if not hasattr(m, k)]
    if manque:
        raise AttributeError("four ep%02d : il manque %s" % (e, ", ".join(manque)))
    if e >= 1 and getattr(m, "TRIPLET", TRIPLETS[e]) != TRIPLETS[e]:
        raise ValueError("four ep%02d : TRIPLET %r différent de epoques.TRIPLETS (%r)" % (e, m.TRIPLET, TRIPLETS[e]))
    return m


def habillage(ep):
    """Habillage complet de l'âge (HABILLAGE_DEFAUT complété par ep.HABILLAGE), formes contrôlées."""
    h = _H.habillage(ep, HABILLAGE_DEFAUT)
    if h["gueule"] is not None and h["gueule"] not in FORMES_GUEULE:
        raise ValueError("gueule %r inconnue (%s)" % (h["gueule"], ", ".join(FORMES_GUEULE)))
    return h


ages.verifier_familles()
