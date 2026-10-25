"""REGISTRE DES ÂGES et CONTRAT des modules epNN.py de la MACHINE D'ASSEMBLAGE (lot F3-A, 25/10). Python pur (importable
hors Blender par les outils et les tests).

Pourquoi (Directeur Créatif, 25/10 vers 10 h, OBJECTIFS §5) : « Le fait que seule la teinte change pour les fours ainsi
que les machines à construire et les foreuses, ça c'est complètement à bannir. » Chaque ÂGE a son propre design ; seule
la pièce paire (et, en jeu, une teinte éventuelle) distingue les deux niveaux d'un même âge. Fiches des 15 âges (font
foi) : fo-logs/2026-10-25_F3/FICHES_ASSEMBLEUR.md.

Méthode de la mitrailleuse et du laser (kit commun ../commun, palettes d'âge commun/ages.py), avec le CORPS DE LIGNÉE de
l'assembleur (corps.py) : un ATELIER CARRÉ vu de trois quarts : EMBASE carrée au motif du pont de l'âge ; DOS haut au
nord (bloc des mécanismes, face sud décorée) ; deux JOUES basses à l'est et à l'ouest ; entre elles la BAIE ouverte au
sud et la TABLE DE TRAVAIL au centre ; au-dessus, le PORTIQUE qui porte l'OUTIL de l'âge. Signaux de jeu FIXES, posés
par la lignée à tous les âges : brides de fluide au milieu des bords NORD (collecteur sur le dos) et SUD (au pied de la
baie) ; TRÉMIE D'ENTRÉE sur la joue ouest, BAC DE SORTIE sur la joue est ; coins AVANT libres (pièce du niveau pair) ;
centre de la machine sans foyer lumineux fort (l'icône de la recette s'y dessine en mode Alt).

Un module d'âge epNN.py (N = 2 à 15) remplit les emplacements d'âge :
  A1 OUTIL (organe qui TRAVAILLE : marteau, presse, électrodes, bras, rayon…) : def outil(g, c), sous le portique,
     dans l'enveloppe c.T["outil"] (x ±ox, yn yt ± oy, z de c.zt à c.zp) ; il change de NATURE à chaque âge ;
  A2 OUVRAGE (la pièce EN COURS sur la table : engrenage, lingot, circuit, aile…) : def ouvrage(g, c), posé sur la
     table (dessus à c.zt) ;
  A3 SIGNATURES (grands volumes d'âge, accents, foyers, halos, sur le dos, les joues et l'embase) : def socle(g, c) ;
  A4 PIÈCE DU NIVEAU PAIR (en PAIRE aux coins avant, places coin_SO et coin_SE) : def piece(g, c) ;
  A5 SORTIE (ronde F3-A2, OBLIGATOIRE aux âges 2 à 15) : def sortie(g, c, p) : le bac de sortie PROPRE à l'âge, posé à
     la place p = dict(x, yn, z, r) que donne le plan (corps.place_es) ; aide commune corps.bac(g, c, p, paroi, produit,
     forme) ;
  facultatifs : def dos(g, c) (remplace le dos de la lignée, MÊME emprise : x ±h, yn de c.yb à h), def entree(g, c, p)
  (trémie d'entrée de l'âge, même place p que la sortie, côté ouest), def liaison(g, pts, r) (organe de liaison :
  câbles, flexibles, conduites) ; GARNIR = ("bati", "joues") (défaut) : zones où la lignée pose ses petites pièces
  (garniture.py, ronde 4) ; () pour aucune ; DENSITE = dict(p=…, lampes=…) : garniture DENSE des dessus (ronde F3-A2,
  garniture.densifier : part des cases garnies, part des voyants) ; RAYONS = False : pas de rayons du croissant au moyeu
  (plans rond et octo) ; LIAISONS = False : pas de conduites du corps à l'outil (corps.liaisons).
Ronde F3-A2 (verdict R-QCM-25f du DC : « juste une plateforme et un truc posé dessus […] ils sont tous carré ») : la clé
  d'habillage `plan` choisit le PLAN du corps (plans.py) : "carre" (atelier de la lignée), "L" (aile haute à l'ouest),
  "portique" (deux pylônes et un pont qui porte l'outil), "tour" (socle rond, fût et annexes), "rond" (tambour à
  croissant), "octo" (tambour octogonal). Aux plans tour, rond et octo, l'outil pend du moyeu (c.hub) au-dessus du lit
  rond (centre (0, c.cy), dessus c.zt) ; dos, joues, table et portique de la lignée ne sont pas posés.
Contrat :
  EPOQUE = N ; NOM = ages.NOMS[N] ; TRIPLET = (« mot 1 », « mot 2 », « mot 3 ») : lecture « en 3 mots » PROPRE à
          l'assembleur (TRIPLETS ci-dessous ; aucun mot répété entre les 15) ;
  FOYER = ages.FOYER[N]                   même lumière que la mitrailleuse du même âge (règle d'or 3) ;
  TRAVAIL = dict(couches=…, images=…, organe=…)   ce qui BOUGERA quand la machine travaille (animation non rendue au lot
                                          F3-A : fiches §animation) ;
  HABILLAGE = dict(ages.CORPS[N], …)      matières de tout le corps (clés communes) + clés PROPRES ci-dessous ;
  def matieres(metal, M)                  ages.matieres(N, metal, M) d'abord, puis les alias de rôle.
HABILLAGE, clés PROPRES à l'assembleur :
  plan          "carre" (défaut) | "L" | "portique" | "tour" | "rond" | "octo" (ronde F3-A2, ci-dessus) ;
  forme_embase "carre" (défaut) | "chanfrein" (coins coupés) | "gradins" (deux marches) | "pieds" (dalle sur pieux) ;
  forme_dos     "plat" (défaut, caisson) | "pans" (toit à deux pans, faîte est-ouest) | "voute" (berceau en demi-cylindre)
                | "gradins" (trois gradins vers le nord) | "tours" (deux tours aux coins, milieu bas) | "coque" (dessus en
                pente vers le sud, arêtes adoucies) | "dome" (caisson bas et coupole) | "bas" (dos bas, F3-A2 :
                plan portique) ;
  forme_joues   "caisson" (défaut) | "pente" (dessus en pente vers le sud) | "basses" | "colonnes" (colonnade et
                linteau) | "socle" (F3-A2 : socles bas des pylônes du plan portique) ;
  forme_portique "poutre" (défaut : deux montants sur les joues, une poutre, un chariot) | "arche" (arc d'une joue à
                l'autre) | "cadre" (cadre de presse posé sur l'embase, dans la baie) | "aucun" (l'âge porte son outil
                autrement : potence, bras, anneau…) ;
  mat_dos, mat_joues, mat_portique, mat_table : matière (clé de M) du dos, des joues, du portique, de la table
                (None : capots de l'âge, olive puis ocre de la lignée, acier sombre, acier).
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

# emprise de l'assembleur, une taille par ère, PLAFOND 6×6 dès l'ère IV (shared/levels/config.lua, L.footprints :
# assembler = { era = { 3, 4, 5, 6, 6 } })
COTE = {0: None, 1: 3, 2: 3, 3: 3, 4: 4, 5: 4, 6: 4, 7: 5, 8: 5, 9: 5, 10: 6, 11: 6, 12: 6, 13: 6, 14: 6, 15: 6}
ERE = ages.ERE
NOMS = ages.NOMS
FAMILLES = ages.FAMILLES

FORMES_EMBASE = ("carre", "chanfrein", "gradins", "pieds")
FORMES_DOS = ("plat", "pans", "voute", "gradins", "tours", "coque", "dome", "bas")
FORMES_JOUES = ("caisson", "pente", "basses", "colonnes", "socle")
PLANS = ("carre", "L", "portique", "tour", "rond", "octo")
FORMES_PORTIQUE = ("poutre", "arche", "cadre", "aucun")

HABILLAGE_DEFAUT = dict(
    **_H.HABILLAGE_LIGNEE,     # capots, plateforme, acier, rivets, joints, danger, peinture (commun)
    plan=None,
    forme_embase=None,
    forme_dos=None,
    forme_joues=None,
    forme_portique=None,
    mat_dos=None,
    mat_joues=None,
    mat_portique=None,
    mat_table=None,
)

# LECTURE « EN 3 MOTS » DE L'ASSEMBLEUR (fiches : fo-logs/2026-10-25_F3/FICHES_ASSEMBLEUR.md) : un triplet par âge,
# PROPRE à l'assembleur (il nomme l'OUTIL ou l'ouvrage de l'âge et un trait de silhouette), aucun mot répété entre les 15
# (tests/test_assembleur.py). Un fichier d'âge écrit le sien dans TRIPLET (contrôle : égal).
TRIPLETS = {
    1: ("caisses clouées", "établi", "rouleaux de fil"),
    2: ("martinet", "enclume", "toit de briques"),
    3: ("grand volant", "chaudière couchée", "bielle"),
    4: ("presse jaune", "vérins", "flexibles"),
    5: ("poche de coulée", "moules", "pyramide de basalte"),
    6: ("soudeuse", "électrodes", "tours de porcelaine"),
    7: ("fronton", "prismes", "rayon violet"),
    8: ("bocaux", "siphon", "cabane sur pieux"),
    9: ("cellule chaude", "télémanipulateurs", "vitre verte"),
    10: ("bras robots", "coque ivoire", "écrans"),
    11: ("aile", "gabarit", "chevrons orange"),
    12: ("lévitation", "rails magnétiques", "conduites givrées"),
    13: ("tore", "faisceau d'annihilation", "spires"),
    14: ("porte étoilée", "ombilicaux", "nuit indigo"),
    15: ("sphère noire", "serres dorées", "couronne incandescente"),
}

# SILHOUETTES (plan, forme_embase, forme_dos, forme_joues, forme_portique) des 14 âges dessinés : recopiées des fichiers
# d'âge (contrôle : test). Ronde F3-A2 : deux âges VOISINS de même taille n'ont jamais le même PLAN (carre, L,
# portique, tour, rond, octo), et l'organe (outil) change de nature à chaque âge.
SILHOUETTES = {
    2: ("L", "carre", "pans", "basses", "aucun"),
    3: ("tour", "carre", "plat", "caisson", "aucun"),
    4: ("portique", "carre", "bas", "socle", "aucun"),
    5: ("octo", "carre", "plat", "caisson", "aucun"),
    6: ("tour", "carre", "plat", "caisson", "aucun"),
    7: ("carre", "gradins", "pans", "colonnes", "arche"),
    8: ("rond", "carre", "plat", "caisson", "aucun"),
    9: ("L", "chanfrein", "coque", "caisson", "aucun"),
    10: ("carre", "carre", "coque", "pente", "aucun"),
    11: ("portique", "chanfrein", "bas", "socle", "aucun"),
    12: ("rond", "carre", "plat", "caisson", "aucun"),
    13: ("tour", "carre", "plat", "caisson", "aucun"),
    14: ("octo", "carre", "plat", "caisson", "aucun"),
    15: ("portique", "gradins", "bas", "socle", "aucun"),
}

# trous enfermés VOULUS : {(âge, « machine » | « compo »): [(x, y, rayon) en tuiles depuis le centre]}
TROUS_VOULUS = {}


def module(e):
    """Module de l'âge e (ep00 à ep15), contrôlé contre le contrat."""
    m = importlib.import_module("ep%02d" % e)
    besoin = ["NOM", "FOYER", "piece"] if e in (0, 1) else ["NOM", "FOYER", "socle", "piece", "outil", "ouvrage"]
    manque = [k for k in besoin if not hasattr(m, k)]
    if manque:
        raise AttributeError("assembleur ep%02d : il manque %s" % (e, ", ".join(manque)))
    if e >= 1 and getattr(m, "TRIPLET", TRIPLETS[e]) != TRIPLETS[e]:
        raise ValueError("assembleur ep%02d : TRIPLET %r différent de epoques.TRIPLETS (%r)" % (e, m.TRIPLET,
                                                                                            TRIPLETS[e]))
    return m


def habillage(ep):
    """Habillage complet de l'âge (HABILLAGE_DEFAUT complété par ep.HABILLAGE), formes contrôlées."""
    h = _H.habillage(ep, HABILLAGE_DEFAUT)
    for cle, permis in (("plan", PLANS), ("forme_embase", FORMES_EMBASE), ("forme_dos", FORMES_DOS), ("forme_joues", FORMES_JOUES),
                        ("forme_portique", FORMES_PORTIQUE)):
        if h[cle] is not None and h[cle] not in permis:
            raise ValueError("%s %r inconnue (%s)" % (cle, h[cle], ", ".join(permis)))
    return h


def silhouette(hab):
    """(plan, embase, dos, joues, portique) d'un habillage complet (défauts de la lignée pour None)."""
    return (hab["plan"] or "carre", hab["forme_embase"] or "carre", hab["forme_dos"] or "plat",
            hab["forme_joues"] or "caisson", hab["forme_portique"] or "poutre")


def teinte_pair(e):
    """TEINTE du niveau PAIR (ronde F3-A2, demande du DC : « pièce plus grande + teinte ») : multiplication douce des
    couches principales de la machine vers la couleur du foyer de l'âge (0,8 + 0,2 × rgb ; F36 : une teinte ne fait que
    multiplier, jamais éclaircir). Appliquée par profil.level_layers à l'aperçu ; en jeu, champ tint des couches du
    niveau pair (intégration)."""
    rgb = ages.FOYER.get(e, {}).get("rgb", (1.0, 1.0, 1.0))
    t = tuple(0.8 + 0.2 * v for v in rgb)
    if max(t) - min(t) < 0.03:
        t = (0.88, 0.92, 1.0)
    return t


ages.verifier_familles()
