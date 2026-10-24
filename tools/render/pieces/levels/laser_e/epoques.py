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
                sur l'arête de chaque gradin), rapport=0,6..0,9 (retrait d'un gradin au suivant)) ; options du
                QUATRIÈME JET (correction F1-A, M-5 et M-6 ; SILHOUETTE de l'affût propre à l'âge) :
                contour=None|dict(forme="lobes"|"etoile"|"dents", n=3..16, prof=0,08..0,35, phase=degrés (premier
                sommet, 90 = nord)) : contour non rond de TOUS les gradins (trèfle, quadrilobe, étoile, roue dentée),
                exclusif de pans ; interstice=None|mat : bande lumineuse en retrait au pied de chaque gradin, avec
                entretoises (la « lévitation » fermée, aucun vide) ; pilotis=None|mat|dict(mat=…, n=…) : pieux serrés au
                pied du premier gradin ; etoiles=None|mat|dict(mat=…, densite=points par tuile²) : points lumineux
                semés sur le dessus des gradins ; rayons=None|dict(forme="aileron"|"contrefort", n=2..8, mat=…,
                phase=degrés) : lames ou contreforts au sol autour du premier gradin, rognés hors des places de coin ;
  forme_tete    None (« etrier » : deux joues pleines et tourillons) | "berceau" (U plein sous l'émetteur, joues
                basses) | "anneau" (anneau autour de l'émetteur, axe = faisceau, PENCHÉ de 35° vers l'avant, fermé par
                un diaphragme, sur un pied ; l'émetteur de l'âge se dessine dans corps.dans_anneau(g, c)) | "fourche"
                (deux bras fins en V, tourillons en avant) ;
  proue         (pas une clé) toutes les têtes portent la PROUE de la lignée (repère de direction, quatrième jet, M-1) ;
                un âge peut la remplacer par def proue(g, c), jamais la supprimer ;
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
CLES_AFFUT = ("gradins", "pans", "profil", "flanc", "flanc2", "assises", "lisere", "rapport", "contour", "interstice",
              "pilotis", "etoiles", "rayons")
CONTOURS = ("lobes", "etoile", "dents")
RAYONS = ("aileron", "contrefort")

# MAQUETTES DES 15 AFFÛTS (quatrième jet, M-6) : la SILHOUETTE de l'affût et la forme de la tête de chaque âge, recopiées
# des fiches (FICHES_LASER.md §2, colonne « Affût », font foi). Elles servent : (1) aux variantes « maquette » mNN-socle
# et mNN-tete-N|E (lignée seule habillée aux matières de l'âge, sans organe d'âge : piece.py), pour mesurer gris.py
# sur les socles AVANT d'écrire les fichiers d'âge ; (2) de point de départ du HABILLAGE d'un fichier d'âge
# (dict(ages.CORPS[N], **MAQUETTES[N]) ; le constructeur peut s'en écarter, en le disant dans sa fiche).
# Règle (M-6) : deux âges voisins de MÊME taille n'ont jamais la même silhouette d'affût (contour, nombre de gradins,
# profil, rayons au sol).
MAQUETTES = {
    2: dict(cerclages="fer_noir", forme_tete="etrier",
            forme_affut=dict(gradins=2, pans=12, profil="droit", assises=True, flanc="brique", flanc2="brique_pave2")),
    3: dict(cerclages="laiton_capot", forme_tete="berceau",
            forme_affut=dict(gradins=3, profil="bombe", flanc="cuivre_capot", flanc2="cuivre_sombre", rapport=0.76)),
    4: dict(cerclages="galva_capot", forme_tete="berceau",
            forme_affut=dict(gradins=2, pans=8, profil="droit", flanc="jaune_capot", flanc2="noir_capot",
                             rayons=dict(forme="contrefort", n=4, mat="noir_capot"))),
    5: dict(cerclages="fonte_noire", forme_tete="fourche",
            forme_affut=dict(gradins=3, profil="cone", flanc="basalte_capot", flanc2="fonte_v", lisere="emit")),
    6: dict(cerclages="porcelaine", forme_tete="etrier",
            forme_affut=dict(gradins=3, profil="droit", flanc="bleu_machine", flanc2="fonte_bleue",
                             contour=dict(forme="dents", n=12, prof=0.13, phase=105.0))),
    7: dict(cerclages="bronze_capot", forme_tete="berceau",
            forme_affut=dict(gradins=4, pans=8, profil="droit", assises=True, flanc="pierre_claire",
                             flanc2="pierre_claire2", rapport=0.8)),
    8: dict(cerclages="cuivre_terni", forme_tete="etrier",
            forme_affut=dict(gradins=2, profil="droit", flanc="bois_mouille", flanc2="bois_mousse", rapport=0.62,
                             pilotis=dict(mat="bois_mouille"))),
    9: dict(cerclages="plomb_sombre", forme_tete="etrier",
            forme_affut=dict(gradins=3, profil="chanfrein", flanc="beton_capot", flanc2="concrete", rapport=0.78,
                             contour=dict(forme="lobes", n=3, prof=0.3, phase=90.0))),
    10: dict(cerclages="anthracite", forme_tete="etrier",
             forme_affut=dict(gradins=2, profil="chanfrein", flanc="blanc_casse", flanc2="gris_tech", rapport=0.62)),
    11: dict(cerclages="ring", forme_tete="fourche",
             forme_affut=dict(gradins=3, profil="chanfrein", flanc="titane_cl", flanc2="titane_md", lisere="emit",
                              contour=dict(forme="etoile", n=8, prof=0.16, phase=101.25),
                              rayons=dict(forme="aileron", n=4, mat="titane_dk"))),
    12: dict(cerclages="chrome_mat", forme_tete="etrier",
             forme_affut=dict(gradins=3, pans=6, profil="droit", flanc="frost", flanc2="chrome_mat",
                              interstice="emit_soft", rapport=0.78)),
    13: dict(cerclages="cuivre_bobine", forme_tete="berceau",
             forme_affut=dict(gradins=3, profil="chanfrein", flanc="acier_canon", flanc2="acier_canon2",
                              lisere="emit_soft", contour=dict(forme="lobes", n=4, prof=0.26, phase=45.0))),
    14: dict(cerclages="blanc_lunaire", forme_tete="anneau",
             forme_affut=dict(gradins=2, profil="chanfrein", flanc="indigo_nuit", flanc2="indigo_nuit2",
                              lisere="emit_soft", rapport=0.7, etoiles=dict(mat="emit", densite=5.0),
                              rayons=dict(forme="contrefort", n=8, mat="blanc_lunaire"))),
    15: dict(cerclages="or_chauffe", forme_tete="fourche",
             forme_affut=dict(gradins=4, profil="cone", flanc="noir_chaud", flanc2="cendre", lisere="emit",
                              rapport=0.8)),
}

# LECTURE « EN 3 MOTS » DU LASER (fiches : fo-logs/2026-10-24_F1/FICHES_LASER.md) : un triplet par âge, PROPRE au
# laser (il nomme l'émetteur de l'âge), tous distincts (aucun mot répété : tests/test_laser.py). Liste montrée aux
# lecteurs du test à l'aveugle, dans l'ordre 1 à 15 ; un fichier d'âge écrit le sien dans TRIPLET (contrôle : égal).
# Correction F1-A (M-2) : chaque mot nomme ce que montre la vignette E au zoom 1 (jamais une face avant, vue par la
# tranche en E, ni une pièce de moins de 8 px) ; mots changés aux âges 1, 2, 4, 5, 8 et 9 (FICHES_LASER.md §6) ;
# âge 1 encore à la reprise (« sacs de sable » → « tube ambré » : le muret ne se lit au zoom 1 que comme un rebord gris).
TRIPLETS = {
    1: ("tube ambré", "plancher de bois", "pied en ciseaux"),
    2: ("tambour de briques", "volets de fer", "soufflet"),
    3: ("globe de cuivre", "serpentins", "cadrans"),
    4: ("cuve couchée", "bidons", "volants rouges"),
    5: ("volcan", "orgues de basalte", "fente de lave"),
    6: ("bobine Tesla", "tore", "isolateurs"),
    7: ("prisme de cristal", "bronze", "temple"),
    8: ("ampoule", "liquide jaune", "pilotis"),
    9: ("trèfle de béton", "cœur vert", "fûts de plomb"),
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


class _Maquette:
    """Module d'âge « maquette » de l'âge e (variantes mNN-…) : HABILLAGE = ages.CORPS[e] + MAQUETTES[e], matières et
    foyer de l'âge, organes de la LIGNÉE seulement (condensateurs, liaisons, émetteur du témoin) ; aucun organe
    d'âge. Pour mesurer la silhouette des affûts (gris.py) avant d'écrire les fichiers d'âge."""

    def __init__(self, e):
        self.EPOQUE = e
        self.NOM = NOMS[e] + " (maquette)"
        self.TRIPLET = TRIPLETS[e]
        self.FOYER = ages.FOYER[e]
        self.FAISCEAU = dict(rgb=(1.0, 1.0, 1.0), forme="maquette", largeur=1.0)
        self.HABILLAGE = dict(ages.CORPS[e], **MAQUETTES[e])

    def matieres(self, metal, M):
        ages.matieres(self.EPOQUE, metal, M)

    def socle(self, g, c):
        return None

    def piece(self, g, c):
        import corps
        p = corps.place(c, "coin_SE")
        for sx in (-1, 1):
            corps.patin(g, c, sx * p["x"], p["yn"], 1.2 * p["r"], 1.2 * p["r"])

    def emetteur(self, g, c):
        import corps
        corps.emetteur_lignee(g, c)


def maquette(e):
    """Module « maquette » de l'âge e (2 à 15)."""
    if e not in MAQUETTES:
        raise KeyError("maquette laser : âge %r (2 à 15)" % e)
    return _Maquette(e)


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
        ct = fa.get("contour")
        if ct is not None:
            if fa.get("pans") is not None:
                raise ValueError("forme_affut : contour et pans s'excluent")
            if (ct.get("forme") not in CONTOURS or not 3 <= int(ct.get("n", 0)) <= 16
                    or not 0.08 <= float(ct.get("prof", 0)) <= 0.35):
                raise ValueError("forme_affut : contour = dict(forme=%s, n=3..16, prof=0,08..0,35)" % "|".join(CONTOURS))
        ry = fa.get("rayons")
        if ry is not None and (ry.get("forme") not in RAYONS or not 2 <= int(ry.get("n", 4)) <= 8):
            raise ValueError("forme_affut : rayons = dict(forme=%s, n=2..8)" % "|".join(RAYONS))
    if h["forme_tete"] is not None and h["forme_tete"] not in FORMES_TETE:
        raise ValueError("forme_tete %r inconnue (%s)" % (h["forme_tete"], ", ".join(FORMES_TETE)))
    cd = h["condensateurs"]
    if cd is not None and cd is not False:
        n = cd.get("n")
        if n is not None and (n < 6 or n % 2):
            raise ValueError("condensateurs : n pair et >= 6")
    return h


ages.verifier_familles()
