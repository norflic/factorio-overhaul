"""REGISTRE DES ÉPOQUES et CONTRAT des modules epNN.py (lot V3-E, quatrième passe, 23/10 ; habillage complet et
points d'accroche : passe 5, deuxième temps du kit, 23/10). Python pur (importable
hors Blender par les outils). FICHIER GELÉ pour les constructeurs.

Un module d'époque epNN.py (N = 2 à 15) ne remplit QUE les emplacements d'époque du catalogue (§A.2) : arme (E1),
tuyaux et grands volumes annexes (E2), accents et matières d'accent (E3, E4), foyers (E5), signatures et pièce du
niveau pair (E6). Le corps de lignée (corps.py), les matières du corps et les règles de reflets (kit.py), les formes
communes (formes.py) et les outils sont communs et gelés. Contrat :

  EPOQUE = N ; NOM = "…"
  FOYER = dict(rgb=(r, g, b) linéaire, rgb2=… facultatif (2e couleur), nuit=False, doux=dict(force=0.7, base=…))
          la couleur doit tomber, MESURÉE sur la couche glow (mesures.py), dans la famille FAMILLES[N] ;
  CANON = dict(L=…, nb=…, rb=…, rr=…)      longueur et nombre de tubes, rayon d'un tube, rayon du faisceau ;
  HABILLAGE = dict(…)                      facultatif : clés de HABILLAGE_DEFAUT (voir « HABILLAGE » ci-dessous) ;
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
VARIANTE DE CORPS (passe 5) : corps_choix.py, UN fichier d'UNE ligne, CORPS = "A" (corps de la passe 4, défaut) ou
"B" (valeurs groupées : grandes masses plus claires, micro-contrastes resserrés ; kit.corps_b). C'est le SEUL fichier
commun que les constructeurs ont le droit de modifier ; rendre.py --corps A|B l'emporte sur lui pour un rendu (essais
du kit), et la variante utilisée est écrite dans render.json et spec.json de chaque sprite.
HABILLAGE (passe 5, consigne du Directeur Créatif du 23/10 : d'un âge à l'autre, la différence doit être aussi franche
qu'entre deux évolutions d'une défense de Clash of Clans). Une époque change la MATIÈRE et le MOTIF de TOUT le corps de
lignée depuis son seul fichier, SANS toucher à la géométrie commune (mêmes pièces, mêmes sommets, même précision ;
seule la clé « plateforme » redessine le MOTIF du pont, à la même précision) :
HABILLAGE = dict(clé=valeur, …) dans epNN.py, et ses matières propres dans def matieres(metal, M). Toute clé absente ou
None laisse la lignée telle quelle (contrôle de construction : construction.py, empreinte identique). Une valeur
nomme une matière de kit.materials (lignée, bibliothèque d'accents) ou de ep.matieres ; une matière inconnue est une
erreur au chargement (KeyError). Les cibles se lisent dans la palette d'ORIGINE : jamais de remplacement en chaîne.
Où s'applique l'habillage : aux pièces de la LIGNÉE (plateforme, dalle, colonne, couronne dentée, trémie et goulotte,
collier, jupe, coupole, masque de lignée, nacelle, échappements, tourelleau, trappe, bras de tourillon) ; corps.habille
met g.M sur la palette habillée (c.Mh) le temps de les dessiner. NE s'applique PAS : au canon (canon_lignee, rosette,
bouche, moteur ; l'époque passe recv_mats, masque_mats, alim_mats, bague_mat à canon_lignee si elle veut sa matière)
ni à ce que l'époque dessine (socle, piece, arme, tete, masque et nacelle d'époque) : pour poser un organe dans la
matière de son corps, l'époque lit corps.mat(c, "steel_dk"), corps.capot(c, "olive"), etc.
Clés de MATIÈRE (valeur simple : tout le groupe ; couple : (premier groupe, second groupe)) :
  capots     "clé" | ("clé1", "clé2") : clé1 remplace l'OLIVE (coupole, bandes olive de la jupe, fût de la colonne,
             coque de la nacelle, bras de tourillon, masque, joues de la goulotte), clé2 l'OCRE (plaques ocre de la
             nacelle et du masque ; trémie et tourelleau quand « tremie » et « tourelleau » gardent leur défaut) ;
             valeur simple : les deux. Ex. capots=("nacre", "or_blanc").
  acier      "clé" | ("sombre", "clair") : sombre remplace l'acier SOMBRE de structure (steel_dk, armor2, armor :
             collier, nervures et bourrelet de la coupole, ceinture, semelle et goussets de la colonne, couronne dentée,
             berceaux, tourillons, périscopes, nervures et porte de la trémie, maillons de la goulotte, cornières du pont
             quand « plateforme » ne dit pas « bord ») ; clair remplace l'acier CLAIR (steel, steel_hi : dents de la
             couronne, échelle, boulons, poignées, lamelles de grille) ; valeur simple : le sombre seul.
             Ex. acier=("fer_brut", "fer_clair").
  rivets     "clé" : rivets et têtes bombées de la lignée (rivet). Ex. rivets="or_rivet".
  joints     "clé" : joints et âmes sombres entre les plaques (seam : âme de la jupe, caissons, fond de la couronne,
             fond d'échelle). Ex. joints="joint_gris". Les bouches, trous et creux (void) restent noirs.
  danger     "clé" | ("clair", "sombre") : bandes de danger de la couronne dentée et de la trémie (hazy, hazk) ;
             valeur simple : les deux (bande unie). Ex. danger=("corde", "poutre").
  peinture   "clé" : peinture rouge de la colonne (redpaint). Ex. peinture="magenta_sombre".
  tremie, tourelleau, chapeau, jupe_cerclage, grille_nacelle (clés de la passe 4) : matière de cette pièce ; se lisent
             dans la palette habillée (« ochre », défaut du tourelleau, suit donc « capots »).
Clé de MOTIF du pont :
  plateforme None (caillebotis de la lignée, code d'origine) | "motif" | dict(motif=…, mat=…, mat2=…, fond=…, bord=…,
             boulons=…, lisere=…, pas=…, joint=…, relief=…) :
     motif   "caillebotis" (lames sur chant au pas de 0,09) | "planches" (planches de 0,16 t le long de x, longueurs de
             0,5 à 1 t décalées, deux clous à chaque bout) | "dalles" (dalles carrées de 0,28 t à joints fins) |
             "toles" (tôles de 0,5 t, 6 rivets chacune) ;
     mat     matière des lames, planches, dalles ou tôles (défaut "grate") ; mat2 : seconde matière tirée au hasard
             (planches ou dalles dépareillées ; défaut aucune) ;
     fond    tablier continu sous le motif, visible dans les joints (défaut "tablier", noir) ;
     bord    cornières du pourtour (défaut "steel_dk", qui suit « acier ») ;
     boulons boulons des cornières, clous des planches, rivets des tôles (défaut "steel_hi" ; None : aucun) ;
     lisere  matière LUMINEUSE d'un liseré fin sur le dessus des cornières (défaut None ; ex. "emit_soft" : âges
             lumineux) ;
     pas     pas du motif en tuiles de jeu (défauts : planches 0,16, dalles 0,28, tôles 0,5) ; joint : largeur des joints
             (unités Blender ; défauts 0,014, 0,016, 0,02) ; relief : écart d'épaisseur des pièces (0 à 1, défaut 0).
     Le tablier reste continu et les cornières restent : aucun trou possible. corps.dalle (pièce du niveau pair) suit le
     même motif. Hasard LOCAL (graine fixe) : le tirage du reste du bâtiment ne change pas.
     Ex. plateforme=dict(motif="planches", mat="planche", mat2="planche2", bord="poutre", boulons="clou", relief=0.4).
EXEMPLES COMPLETS (essais du kit sur le témoin) : habillages.py (pionnier, fusion, legende) ; rendu avec
rendre.py --kit S --habillage NOM. Règle de reflets inchangée (kit.REFLETS) ; une grande masse claire doit rester peu
métallique (métallicité <= 0,5) : un métal pur sous ce soleil reste sombre (fait mesuré en pose N, passe 5).
SUPERSTRUCTURES (passe 5) : points d'accroche et places libres par taille dans accroches.py (coins du pont, côtés de la
trémie, sommet de la coupole, couronne de la jupe) ; dans Blender, corps.accroche(c, nom) rend la place libre pour le
canon de l'époque.
POSE N (passe 5, règle d'or 7) : les tubes par défaut sont en acier nu clair (M["gun"]) ; corps.rosette éclaire la
pointe de chaque tube (pointes=…) ; corps.couronne_bouche remplace le frein en bloc de la passe 4 ; un frein d'époque
ne doit pas faire de chapeau plat plus large que le faisceau.
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
    tremie=None,               # peinture de la trémie (None : ocre de la lignée, qui suit « capots »)
    pochoirs=True,             # marquages au pochoir sur la face sud de la trémie
    munitions=None,            # (étui, balle) des bandes visibles dans la trémie (None : laiton et cuivre)
    grille_nacelle="steel",    # lamelles de la grille arrière de la nacelle (2×2 à 4×4)
    tourelleau="ochre",        # caisson du tourelleau
    chapeau="brass",           # chapeau boulonné du tourillon
    # --- MATIÈRE et MOTIF de TOUT le corps (passe 5 ; contrat « HABILLAGE » ci-dessus) : None = lignée inchangée
    capots=None,               # grands capots : clé, ou (remplace l'olive, remplace l'ocre)
    plateforme=None,           # pont : motif (caillebotis, planches, dalles, toles), matières, liseré
    acier=None,                # acier de structure : clé, ou (sombre, clair)
    rivets=None,               # rivets et têtes bombées de la lignée
    joints=None,               # joints et âmes sombres entre les plaques
    danger=None,               # bandes de danger : clé, ou (clair, sombre)
    peinture=None,             # peinture rouge de la colonne
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
