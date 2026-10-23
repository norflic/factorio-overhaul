"""Lot A3 (24/10) : trous enfermés ACCEPTÉS dans les 60 nouvelles directions des têtes (règle des rendus : ≤ 8 px hr).

Source : masques rapides des 64 directions de tous les âges (masques.py trous, fo-logs/2026-10-24_A3/trous/
trous-production.txt : 72 poses au-delà de 8 px, hors bande du bouchon), chaque groupe REGARDÉ sur des rendus rapides
(fo-logs/2026-10-24_A3/trous/gros-plans.png, gros-plans-2.png, planche-age11.png : trou en rouge à côté du rendu).
Aucun n'est comblé (une pièce de fond changerait l'éclairage des poses validées : identité octet à octet non tenable
sans un objet vu de la seule caméra, non fait) ; chacun est ACCEPTÉ avec sa classe et sa raison ci-dessous. Le plafond
d'une pose = trou du masque + MARGE px (écart masque / production mesuré sur 56 poses : 3 px au plus, validation.txt).
produire_a3.py refuse (« HORS REGLE ») une tête dont le trou de production dépasse son plafond ou n'est pas listée.
"""
MARGE = 6

CLASSES = {
    "trappe": ("volet de trappe ouvert",
               "TROU VOULU DU PROFIL : jour entre le volet levé de la trappe et la coupole, vu par la tranche sur 1 ou 2 "
               "directions (angle rasant) ; c'est le dessous d'un volet ouvert, pas une fente du corps"),
    "ailettes": ("ailettes et tubes de l'âge 11",
                 "TROU VOULU DU PROFIL : ailettes triangulaires détachées le long des canons et tubes séparés du "
                 "faisceau (corps.rosette : « on voit les tubes séparés ») ; le sol se voit entre une ailette et la coque "
                 "ou entre deux tubes, comme entre deux pièces distinctes ; plus grand en d09 à d13 (ailette vue à plat)"),
    "jonction": ("jour entre bras et coque",
                 "ANGLE RASANT : petit jour compact entre le bras de tourillon (ou la culasse) et la coque, visible sur "
                 "2 à 4 directions voisines d'une diagonale ; 10 à 44 px hr (au plus environ 7 × 7 px hr, 3 × 3 px en "
                 "normale) ; NON comblé, à montrer au DC"),
    "petit": ("petit jour entre pièces",
              "ANGLE RASANT : jour de 9 à 15 px hr entre deux pièces (culasse, bobine, couronne), sur des directions "
              "isolées ou voisines"),
}

# (pose : (classe, trou du masque à 16 échantillons, px hr))
POSES = {}


def _ajoute(classe, valeurs):
    for n, v in valeurs.items():
        POSES[n] = (classe, v)


_ajoute("trappe", {"e04-tete-d10": 16, "e06-tete-d13": 17, "e07-tete-d14": 20, "e08-tete-d08": 11, "e08-tete-d09": 40,
                   "e08-tete-d51": 10, "e09-tete-d08": 11, "e13-tete-d10": 10})
_ajoute("jonction", {"e09-tete-d12": 44, "e09-tete-d13": 43, "e09-tete-d14": 31, "e09-tete-d15": 19,
                     "e09-tete-d49": 19, "e09-tete-d50": 35, "e09-tete-d51": 43, "e09-tete-d52": 41,
                     "e10-tete-d50": 28, "e12-tete-d08": 22, "e12-tete-d09": 15, "e12-tete-d55": 20,
                     "e12-tete-d56": 17, "e04-tete-d43": 11, "e04-tete-d44": 10})
_ajoute("petit", {"e02-tete-d29": 11, "e02-tete-d30": 15, "e02-tete-d31": 12, "e02-tete-d33": 10, "e02-tete-d34": 14,
                  "e02-tete-d35": 9, "e03-tete-d04": 12, "e03-tete-d05": 9, "e03-tete-d06": 9, "e03-tete-d07": 15,
                  "e03-tete-d28": 10, "e03-tete-d29": 11, "e03-tete-d30": 15, "e03-tete-d31": 11,
                  "e03-tete-d33": 10, "e03-tete-d34": 11, "e03-tete-d35": 9, "e03-tete-d57": 15,
                  "e03-tete-d60": 14, "e06-tete-d17": 10, "e13-tete-d31": 12})
_ajoute("ailettes", {"e11-tete-d01": 15, "e11-tete-d06": 9, "e11-tete-d07": 12, "e11-tete-d08": 23,
                     "e11-tete-d09": 382, "e11-tete-d10": 266, "e11-tete-d11": 165, "e11-tete-d12": 84,
                     "e11-tete-d13": 78, "e11-tete-d14": 38, "e11-tete-d15": 10, "e11-tete-d21": 11,
                     "e11-tete-d24": 14, "e11-tete-d25": 20, "e11-tete-d26": 20, "e11-tete-d30": 11,
                     "e11-tete-d38": 20, "e11-tete-d39": 28, "e11-tete-d40": 14, "e11-tete-d49": 10,
                     "e11-tete-d50": 34, "e11-tete-d51": 72, "e11-tete-d52": 75, "e11-tete-d53": 85,
                     "e11-tete-d54": 9, "e11-tete-d56": 23, "e11-tete-d62": 9, "e11-tete-d63": 16})
# 62 autres poses ont un trou de 6 à 8 px au masque : la production (128 échantillons) peut le trouver à 9 ou 11 px
# (écart masque / production : 3 px au plus sur 56 poses). Une telle pose est acceptée jusqu'à son trou de masque + 3 px
# (classe « écart d'échantillonnage ») ; au-delà, ou si le masque passait déjà mieux, « HORS REGLE ».
ECART_MASQUE = 3


def accepte(nom, trou_masque=None):
    """{« classe », « raison », « plafond »} si le trou de la pose est accepté, sinon None. trou_masque : plus grand trou
    du masque rapide de la même pose (produire_a3.controler le calcule)."""
    if nom in POSES:
        c, v = POSES[nom]
        return {"classe": CLASSES[c][0], "raison": CLASSES[c][1], "plafond": v + MARGE}
    if trou_masque is not None and trou_masque <= 8:
        return {"classe": "écart d'échantillonnage",
                "raison": "le masque rapide (16 échantillons) passe la règle (%d px) ; la production à 128 échantillons "
                          "peut lire 3 px de plus au bord d'un trou (validation des masques)" % trou_masque,
                "plafond": trou_masque + ECART_MASQUE}
    return None


assert len(POSES) == 72, len(POSES)
