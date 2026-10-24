"""REGISTRE DES ÂGES et CONTRAT des modules epNN.py de la TOURELLE LASER (lot F1-A, 24/10). Python pur (importable
hors Blender par les outils). FICHIER GELÉ pour les constructeurs d'âge.

Le laser reprend la méthode de la mitrailleuse validée (kit commun ../commun, palettes d'âge commun/ages.py) avec SON
corps de lignée (corps.py) : AFFÛT ROND À GRADINS (ronds à l'écran), COURONNE DE CONDENSATEURS sur le premier gradin,
PIVOT, et une TÊTE TOURNANTE SANS CANON : platine, support de l'émetteur (étrier à deux joues, berceau ou anneau),
caisson arrière (refroidisseur), et au centre l'ÉMETTEUR, organe de l'âge. Fiches des 15 âges :
fo-logs/2026-10-24_F1/FICHES_LASER.md (fait foi pour les constructeurs).

Un module d'âge epNN.py (N = 2 à 15) ne remplit QUE les emplacements d'âge (catalogue §A.2, transposés au laser) :
  E1 ÉMETTEUR (rôle des canons de la mitrailleuse) : def emetteur(g, c) ;
  E2 LIAISONS (câbles de puissance, guides d'onde, conduits de refroidissement) : def liaison(g, pts, r) ;
  E3-E5 accents, matières (def matieres), foyers (FOYER = ages.FOYER[N]) ;
  E6 signatures du socle (def socle) et pièce du niveau pair (def piece).
Contrat :
  EPOQUE = N ; NOM = ages.NOMS[N] ; TRIPLET = (« mot 1 », « mot 2 », « mot 3 ») : lecture « en 3 mots » propre au
          laser (test à l'aveugle ; la liste des 15 est TRIPLETS ci-dessous, recopiée du fichier d'âge) ;
  FOYER = ages.FOYER[N]                   même lumière que la mitrailleuse du même âge (règle d'or 3, familles
                                          mesurées : ages.FAMILLES) ;
  FAISCEAU = dict(rgb=(r, g, b) linéaire, forme=« … », largeur=…)  faisceau de l'âge EN JEU (couleur et forme ; le
                                          prototype « beam » de l'âge le lira au lot d'intégration ; non rendu ici) ;
  HABILLAGE = dict(ages.CORPS[N], …)      matière de TOUT le corps (clés communes) + clés propres au laser (ci-dessous) ;
  def matieres(metal, M)                  ages.matieres(N, metal, M) d'abord, puis les alias de rôle du laser ;
  def socle(g, c)        après l'affût, la couronne de condensateurs et le pivot : grands volumes d'âge, liaisons,
                         accents, foyers, halos (places : corps.place(c, nom)) ;
  def piece(g, c)        pièce du niveau pair, en PAIRE aux coins avant (places coin_SO et coin_SE) ;
  def emetteur(g, c)     l'ÉMETTEUR, dans le repère de la tête (faisceau vers +Y), centré en (0, 0, c.T["zh"]),
                         DANS l'enveloppe c.env (x ±re, y de y_ar à y_av, z zh ± re) ; il change de NATURE d'un âge à
                         l'autre (lentille, prisme, bobine, ampoule, bouteille, anneau, disque…) ; sa face avant porte
                         la LENTILLE (corps.lentille : verre sombre, anneau lumineux de l'âge) ;
  def tete(g, c)         facultatif : accents de la tête après l'émetteur (plaques, câbles, voyants) ;
  def condensateur(g, c, x, y, z, r, h)   facultatif : remplace le condensateur de la lignée (bocal de Leyde,
                         bouteille magnétique…), MÊME place et même encombrement (r, h ± 25 %) ;
  def arriere(g, c)      facultatif : remplace le caisson arrière de la lignée (refroidisseur) ;
  def liaison(g, pts, r) facultatif : organe de liaison de l'âge (défaut : gaine de caoutchouc) ; la lignée s'en sert
                         aussi pour les liaisons radiales des condensateurs au pivot ;
  AXE = False            facultatif : la lignée ne trace pas l'axe des tourillons à travers l'émetteur (âge 15 : il
                         couperait le disque) ; l'âge porte alors lui-même son émetteur jusqu'à la platine.
c (corps.Ctx) porte : g, M, Mh (palette habillée), e, ep, side, T (cotes de la taille, cotes.TAILLES), hab, formes,
gradins [(rayon pied, rayon haut, z0, z1)], env (enveloppe de l'émetteur), et pour la tête : zh, xc (joues).

HABILLAGE (contrat commun : commun/habillage.py, gun_e/epoques.py « HABILLAGE ») : capots (olive : joues, platine,
caisson ; ocre : plaques du caisson et des gradins), acier, rivets, joints, danger (couronne du pivot), peinture
(fût des condensateurs), plateforme (motif du DESSUS des gradins). Clés PROPRES au laser :
  cerclages     matière des cerclages des condensateurs et des tourillons (défaut « brass ») ;
  forme_affut   None (3 gradins ronds droits, 2 en 2×2) | dict(gradins=2..4, pans=None|n (gradins polygonaux à n
                pans, n >= 6), profil="droit"|"chanfrein"|"cone"|"bombe", flanc=mat, flanc2=mat (flancs : plaques
                rivetées), assises=False|True (flancs en assises de briques ou de pierre), lisere=None|mat (filet lumineux
                sur l'arête de chaque gradin), rapport=0,6..0,9 (retrait d'un gradin au suivant)) ;
  forme_tete    None (« etrier » : deux joues pleines et tourillons) | "berceau" (U plein sous l'émetteur, joues
                basses) | "anneau" (anneau vertical autour de l'émetteur, axe = faisceau, sur un pied) | "fourche"
                (deux bras fins en V, tourillons en avant) ;
  condensateurs None (couronne de la lignée) | dict(n=…, garder=…) : nombre (pair, >= 6) ou False (aucun : l'âge pose
                sa propre réserve d'énergie ailleurs, à justifier dans la fiche).
Toutes les clés à None : témoin de la lignée (ep00, variantes kS-…).

POSE N (règle d'or 7, F119) : l'émetteur n'est JAMAIS un tube dressé ; longueur <= 1,1 × son diamètre (enveloppe :
y de −0,8 re à +1,25 re) ; ce qui le porte (joues, anneau, berceau) est plus large que haut. Aucun conduit vertical
plus haut que large au-dessus de la platine.
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

# même emprise que la mitrailleuse, une taille par ère (shared/levels/config.lua, L.footprints : laser 2, 3, 4, 5, 6)
COTE = {0: None, 1: 2, 2: 2, 3: 2, 4: 3, 5: 3, 6: 3, 7: 4, 8: 4, 9: 4, 10: 5, 11: 5, 12: 5, 13: 6, 14: 6, 15: 6}
ERE = ages.ERE
NOMS = ages.NOMS
FAMILLES = ages.FAMILLES
PLAGE_BASSE = tuple(range(1, 10))
PLAGE_HAUTE = tuple(range(10, 16))

HABILLAGE_DEFAUT = dict(
    cerclages="brass",         # cerclages des condensateurs et des tourillons
    **_H.HABILLAGE_LIGNEE,     # capots, plateforme, acier, rivets, joints, danger, peinture (commun)
    forme_affut=None,          # gradins de l'affût
    forme_tete=None,           # support de l'émetteur
    condensateurs=None,        # couronne de condensateurs
)
FORMES_TETE = ("etrier", "berceau", "anneau", "fourche")
PROFILS = ("droit", "chanfrein", "cone", "bombe")
CLES_AFFUT = ("gradins", "pans", "profil", "flanc", "flanc2", "assises", "lisere", "rapport")

# LECTURE « EN 3 MOTS » DU LASER (fiches : fo-logs/2026-10-24_F1/FICHES_LASER.md) : un triplet par âge, PROPRE au
# laser (il nomme l'émetteur de l'âge), tous distincts (aucun mot répété : tests/test_laser.py). Liste montrée aux
# lecteurs du test à l'aveugle, dans l'ordre 1 à 15 ; un fichier d'âge écrit le sien dans TRIPLET (contrôle : égal).
TRIPLETS = {
    1: ("sacs de sable", "bocaux de Leyde", "caisse de bois"),
    2: ("briques", "lentille à échelons", "volets de fer"),
    3: ("globe de cuivre", "serpentins", "cadrans"),
    4: ("bain d'huile", "bidons", "volants rouges"),
    5: ("cône de basalte", "obsidienne", "fente de lave"),
    6: ("bobine Tesla", "tore", "isolateurs"),
    7: ("prisme de cristal", "bronze", "temple"),
    8: ("ampoule", "liquide jaune", "durites"),
    9: ("tête octogonale", "cœur vert", "béton"),
    10: ("carénage ivoire", "visière bleue", "nappes de câbles"),
    11: ("roue à ailerons", "titane bleu", "pointe orange"),
    12: ("arceaux chromés", "givre", "lévitation"),
    13: ("bouteille magnétique", "bobinages", "point violet"),
    14: ("anneau à chevrons", "indigo", "étoiles"),
    15: ("sphère noire", "disque d'accrétion", "griffes d'or"),
}

# trous enfermés VOULUS : {(âge, « socle » | « tete » | « compo »): [(x, y, rayon) en tuiles depuis le centre]} ; la
# forme « anneau » de la tête ouvre un jour AU CENTRE de l'anneau seulement si l'âge le déclare ici (sinon l'émetteur
# doit remplir l'anneau)
TROUS_VOULUS = {}


def module(e):
    """Module de l'âge e (ep00 à ep15), contrôlé contre le contrat."""
    m = importlib.import_module("ep%02d" % e)
    besoin = ["NOM", "FOYER", "piece"] if e == 1 else ["NOM", "FOYER", "socle", "piece", "emetteur"]
    manque = [k for k in besoin if not hasattr(m, k)]
    if manque:
        raise AttributeError("laser ep%02d : il manque %s" % (e, ", ".join(manque)))
    if e >= 1 and getattr(m, "TRIPLET", TRIPLETS[e]) != TRIPLETS[e]:
        raise ValueError("laser ep%02d : TRIPLET %r différent de epoques.TRIPLETS (%r)" % (e, m.TRIPLET, TRIPLETS[e]))
    return m


def habillage(ep):
    """Habillage complet de l'âge (HABILLAGE_DEFAUT complété par ep.HABILLAGE), formes contrôlées."""
    h = _H.habillage(ep, HABILLAGE_DEFAUT)
    fa = h["forme_affut"]
    if fa is not None:
        inconnues = sorted(set(fa) - set(CLES_AFFUT))
        if inconnues:
            raise KeyError("forme_affut : clé(s) inconnue(s) %s (permises : %s)" % (inconnues, ", ".join(CLES_AFFUT)))
        if fa.get("profil", "droit") not in PROFILS:
            raise ValueError("forme_affut : profil %r inconnu (%s)" % (fa.get("profil"), ", ".join(PROFILS)))
        if not 2 <= int(fa.get("gradins", 3)) <= 4:
            raise ValueError("forme_affut : 2 à 4 gradins")
        if fa.get("pans") is not None and int(fa["pans"]) < 6:
            raise ValueError("forme_affut : au moins 6 pans")
    if h["forme_tete"] is not None and h["forme_tete"] not in FORMES_TETE:
        raise ValueError("forme_tete %r inconnue (%s)" % (h["forme_tete"], ", ".join(FORMES_TETE)))
    cd = h["condensateurs"]
    if cd is not None and cd is not False:
        n = cd.get("n")
        if n is not None and (n < 6 or n % 2):
            raise ValueError("condensateurs : n pair et >= 6")
    return h


ages.verifier_familles()
