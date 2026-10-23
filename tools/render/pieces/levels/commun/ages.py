"""REGISTRE COMMUN DES 15 ÂGES (lot K0, 23/10) : noms, ères, FAMILLES DE COULEUR des foyers, et PALETTE de chaque âge
(foyer, matière du corps et du pont, matières propres). Python pur à l'import (les fonctions _mNN ne font qu'appeler
metal(), dans Blender). Partagé par TOUTES les familles (mitrailleuse, laser, four, assembleur, foreuse, centre, mur) :
un même âge porte la même matière et la même famille de couleur, quelle que soit la famille de bâtiment.

ORIGINE : les données ci-dessous sont COPIÉES MOT POUR MOT des fichiers gun_e/epNN.py de la mitrailleuse validée par
le Directeur Créatif le 23/10 à 14 h 50 (âges 1 à 12 de la passe 5, ère V cosmique 6d0e961) : FOYER, clés de matière
du HABILLAGE, appels metal() de def matieres, dans le MÊME ORDRE (l'ordre des appels fixe les graines de bruit). Preuve :
construction.py --tout donne des empreintes identiques avant et après l'extraction (journal du lot K0,
fo-logs/2026-10-23_suite/K0/). NE PAS RETOUCHER une valeur : ce serait changer un design validé.

Usage dans un fichier d'âge d'une famille (exemple : gun_e/ep05.py) :
    import ages
    FOYER = ages.FOYER[5]
    HABILLAGE = dict(ages.CORPS[5], <clés propres à la famille : formes, pièces de la famille>)
    def matieres(metal, M):
        ages.matieres(5, metal, M)      # toutes les matières de l'âge, dans l'ordre d'origine
        M["<rôle de la famille>"] = M["<matière de l'âge>"]     # alias de rôle (facultatif)
La PALETTE 60/30/10 d'un âge (dominante 60 %, secondaire 30 %, accent 10 %) se lit avec palette(N) : la dominante est
la matière des grands capots (CORPS[N]["capots"][0]), la secondaire celle des capots secondaires (["capots"][1]), le
pont et l'acier suivent CORPS ; l'accent est le FOYER (lumière) de l'âge, dans sa famille de couleur (FAMILLES[N]).

Âge 0 : la LIGNÉE SEULE (témoin du kit), sans palette d'âge. Âge 1 (Pionnier) : le niveau 1 est le bâtiment vanilla ;
la mitrailleuse n'a qu'une pièce de niveau 2 et aucune matière propre (palette vide, foyer de NUIT).
Les ALIAS DE RÔLE de la mitrailleuse (jacket, ring, trim, pipe, pipe2, cable_a, cable_b, spec, accent…) restent dans
gun_e/epNN.py : ils nomment des organes de la mitrailleuse. Attention : certaines matières de l'âge PORTENT un nom de
rôle (âges 10 à 12 : « jacket », « ring », « trim », « pipe », « cable_a »…) parce qu'elles sont créées par metal() sous
ce nom ; elles font partie de la palette (CORPS[11] et CORPS[12] les lisent).
"""

NOMS = {0: "Lignée seule", 1: "Pionnier", 2: "Forge", 3: "Vapeur", 4: "Pétrole", 5: "Volcan", 6: "Électricité",
        7: "Cristal", 8: "Marais", 9: "Atome", 10: "Haute technologie", 11: "Titane", 12: "Supraconducteurs",
        13: "Antimatière", 14: "La Porte", 15: "Néant"}
# lot K0 : ère V COSMIQUE (DC, 23/10, 12 h 40 : Fusion, Orbite et Légende refusés ; ère V refaite, validée à 14 h 50)
ERE = {e: (1 if e <= 3 else 2 if e <= 6 else 3 if e <= 9 else 4 if e <= 12 else 5) for e in range(1, 16)}

# FAMILLES DE COULEUR DES FOYERS (règle d'or 3) : teinte (degrés, intervalle circulaire) et saturation MESURÉES sur la
# couche glow (moyenne pondérée, protocole des juges, mesures.py). Deux âges voisins n'ont jamais de famille
# compatible (teintes ET saturations qui se recouvrent). Saturation : « pâle » < 0,2 ; « moyenne » 0,2 à 0,5 ;
# « forte » > 0,5 (une couleur franche mesurée tombe vers 0,35 à 0,75 : les cœurs saturent vers le blanc).
# Entre crochets : MESURE de la mitrailleuse validée (passe 5 pour 1 à 12 : fo-logs/2026-10-23_V3E-p5/juges/mesures/
# mesures.txt §2 ; ère V cosmique : fo-logs/2026-10-23_V3E-ereV/controles/mesures.txt §2), poses E et N.
# LOT K0 (23/10), sans changer un seul rendu (seule la TABLE change) :
#   - âge 5 : la mitrailleuse validée mesure 31° et 0,87 (lave ORANGE de la ronde 3), hors de l'ancienne famille
#     « rouge braise » (345 à 14°). Élargir la teinte jusqu'à 36° la rendait compatible avec l'âge 4 (24 à 34°, 0,5 à
#     1,0 ; mesuré 30°, 0,67) : les deux âges sont DÉSORMAIS SÉPARÉS PAR LA SATURATION (4 : 0,50 à 0,77 ; 5 : 0,77 à
#     1,0), marge 0,10 de chaque côté. C'est une séparation FAIBLE (même teinte, saturation seule) : la mitrailleuse
#     distingue 4 et 5 par la forme (validée par le DC) ; une autre famille aux âges 4 et 5 doit le faire aussi ;
#   - âge 6 : mesuré 210°, 0,48 (bleu électrique de la ronde 3), hors de 186 à 202° : intervalle porté à 186-214°.
#     Conséquence (non voisins, permis par la règle) : 6 recouvre désormais 10 (204 à 228°) ;
#   - ère V cosmique : familles de FICHES_ERE_V.md §6, CONFIRMÉES par la mesure des sprites de production (251-252°,
#     0,37 ; 222°, 0,04-0,05 ; 38°, 0,30-0,31).
#   Compatibilités entre NON-voisins après K0 (compatibilites_lointaines(), permises par la règle, que le test à
#   l'aveugle peut sanctionner) : 2-5, 3-15, 4-15, 6-10, 6-12, 6-14, 7-13, 11-14.
FAMILLES = {
    1: dict(nom="lanterne (nuit seule)", teinte=(20, 50), sat=(0.0, 1.0), nuit=True, catalogue="FFB060"),
    2: dict(nom="rouge-orange de forge", teinte=(6, 22), sat=(0.5, 1.0), catalogue="FF6A20"),        # [16°, 0,85]
    3: dict(nom="ambre de vapeur", teinte=(36, 52), sat=(0.2, 0.5), catalogue="FFC060"),             # [40°, 0,36]
    4: dict(nom="orange de torchère", teinte=(24, 34), sat=(0.5, 0.77), catalogue="FF8C1A"),         # [30°, 0,67]
    5: dict(nom="braise vive (rouge à orange, très saturé)", teinte=(345, 36), sat=(0.77, 1.0),
            catalogue="FF4A10"),                                                                       # [31°, 0,87]
    6: dict(nom="bleu électrique", teinte=(186, 214), sat=(0.25, 1.0), catalogue="60D0FF"),          # [210°, 0,48]
    7: dict(nom="violet de cristal", teinte=(255, 290), sat=(0.25, 1.0), catalogue="B070FF"),        # [270°, 0,32]
    8: dict(nom="jaune-vert acide", teinte=(60, 88), sat=(0.4, 1.0), catalogue="A8FF3A"),            # [76°, 0,80]
    9: dict(nom="vert uranium", teinte=(100, 135), sat=(0.3, 1.0), catalogue="5CFF4A"),             # [112°, 0,43]
    10: dict(nom="bleu électronique", teinte=(204, 228), sat=(0.3, 1.0), catalogue="3AA8FF"),       # [215°, 0,61]
    11: dict(nom="blanc bleuté", teinte=(180, 232), sat=(0.0, 0.2), catalogue="BFE6FF"),             # [200°, 0,10]
    12: dict(nom="cyan glacé", teinte=(170, 190), sat=(0.3, 1.0), catalogue="4AF0FF"),               # [183°, 0,43]
    13: dict(nom="violet d'annihilation", teinte=(232, 285), sat=(0.3, 1.0), catalogue="8F4BFF"),    # [251°, 0,37]
    14: dict(nom="blanc stellaire", teinte=(205, 250), sat=(0.0, 0.28), catalogue="F4F6FF"),         # [222°, 0,05]
    15: dict(nom="incandescence blanc-or", teinte=(24, 50), sat=(0.2, 0.7), catalogue="FFE6A8"),     # [38°, 0,31]
}

# MESURES de la mitrailleuse validée (teinte en degrés, saturation ; poses E puis N), pour le contrôle de la table
# (verifier_mesures) : un changement de FAMILLES qui sortirait un âge validé de sa famille est une erreur.
MESURES_MITRAILLEUSE = {
    2: ((16, 0.85), (16, 0.84)), 3: ((40, 0.36), (40, 0.36)), 4: ((30, 0.67), (30, 0.67)),
    5: ((31, 0.87), (31, 0.87)), 6: ((210, 0.48), (210, 0.48)), 7: ((270, 0.32), (270, 0.32)),
    8: ((76, 0.80), (76, 0.80)), 9: ((112, 0.43), (112, 0.43)), 10: ((215, 0.61), (215, 0.63)),
    11: ((200, 0.10), (200, 0.11)), 12: ((183, 0.43), (183, 0.43)), 13: ((251, 0.37), (252, 0.37)),
    14: ((222, 0.05), (222, 0.04)), 15: ((38, 0.31), (38, 0.30)),
}


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


def verifier_mesures():
    """Chaque mesure de la mitrailleuse validée tombe dans la famille de son âge. Lève une erreur sinon."""
    pb = [(e, m) for e, ms in sorted(MESURES_MITRAILLEUSE.items()) for m in ms if not dans_famille(e, *m)]
    if pb:
        raise ValueError("mesures validées hors de leur famille : %s" % pb)
    return True


def compatibilites_lointaines():
    """Paires NON voisines compatibles (permises par la règle, à surveiller au test à l'aveugle)."""
    return [(a, b) for a in range(2, 16) for b in range(a + 2, 16) if compatibles(a, b)]


def matieres(e, metal, M):
    """Crée les matières propres de l'âge e (appels metal() d'origine, même ordre : mêmes graines). Âges 0 et 1 :
    aucune."""
    f = MATIERES.get(e)
    if f is not None:
        f(metal, M)


def palette(e):
    """Palette 60/30/10 de l'âge e, lue dans CORPS et FOYER : dominante (grands capots), secondaire (capots
    secondaires), acier (sombre, clair), pont (motif et matières), accent (foyer : rgb, rgb2, famille)."""
    c = CORPS.get(e, {})
    cap = c.get("capots")
    cap = (cap, cap) if isinstance(cap, str) else (cap or (None, None))
    ac = c.get("acier")
    ac = (ac, None) if isinstance(ac, str) else (ac or (None, None))
    pt = c.get("plateforme") or {}
    pt = dict(motif=pt) if isinstance(pt, str) else pt
    f = FOYER.get(e, {})
    return dict(age=e, nom=NOMS[e], dominante=cap[0], secondaire=cap[1], acier=ac[0], acier_clair=ac[1],
                rivets=c.get("rivets"), joints=c.get("joints"), danger=c.get("danger"), peinture=c.get("peinture"),
                pont=dict(motif=pt.get("motif"), mat=pt.get("mat"), mat2=pt.get("mat2"), bord=pt.get("bord"),
                          lisere=pt.get("lisere")),
                accent=dict(rgb=f.get("rgb"), rgb2=f.get("rgb2"), nuit=bool(f.get("nuit")),
                            famille=FAMILLES.get(e, {}).get("nom")),
                matieres=CLES_MATIERES.get(e, ()))


# --------------------------------------------------------------------------------------------------------------------
# PALETTES D'ÂGE (copiées de gun_e/epNN.py, lot K0)
# --------------------------------------------------------------------------------------------------------------------
FOYER = {
    1: dict(rgb=(1.0, 0.69, 0.376), nuit=True),
    2: dict(rgb=(1.0, 0.13, 0.025)),
    3: dict(rgb=(1.0, 0.753, 0.376)),
    4: dict(rgb=(1.0, 0.42, 0.1)),
    5: dict(rgb=(1.0, 0.3, 0.02)),
    6: dict(rgb=(0.25, 0.55, 1.0)),
    7: dict(rgb=(0.69, 0.44, 1.0), doux=dict(force=0.5, base=(0.1, 0.045, 0.15))),
    8: dict(rgb=(0.6, 1.0, 0.04), doux=dict(force=0.75, base=(0.05, 0.075, 0.01))),
    9: dict(rgb=(0.361, 1.0, 0.29), doux=dict(force=0.9)),
    10: dict(rgb=(0.09, 0.33, 1.0), rgb2=(0.09, 0.33, 1.0)),
    11: dict(rgb=(0.749, 0.902, 1.0), rgb2=(0.749, 0.902, 1.0)),
    12: dict(rgb=(0.29, 0.94, 1.0), rgb2=(0.29, 0.94, 1.0), doux=dict(force=1.0)),
    13: dict(rgb=(0.561, 0.294, 1.0), rgb2=(0.29, 0.482, 1.0)),
    14: dict(rgb=(0.957, 0.965, 1.0), rgb2=(0.749, 0.831, 1.0), doux=dict(force=0.8)),
    15: dict(rgb=(1.0, 0.902, 0.659), rgb2=(1.0, 0.639, 0.278), doux=dict(force=1.0)),
}

CORPS = {
    2: dict(
        capots=("fer_martele", "brique"),
        acier=("fer_noir", "fer_clair_f"),
        rivets="fer_clair_f",
        joints="mortier",
        danger=("brique", "fer_noir"),
        peinture="brique",
        plateforme=dict(motif="dalles", pas=0.17, joint=0.02, mat="brique_pave", mat2="brique_pave2",
                        fond="mortier", bord="fer_noir", boulons=None, relief=0.45)),
    3: dict(
        capots=("cuivre_capot", "laiton_capot"),
        acier=("cuivre_sombre", "laiton_capot"),
        rivets="laiton_rivet",
        joints="bois_joint",
        danger=("laiton_capot", "vert_loco"),
        peinture="vert_loco",
        plateforme=dict(motif="toles", pas=0.34, mat="vert_pont", mat2="vert_pont2", fond="bois_joint",
                        bord="laiton_capot", boulons="laiton_rivet", relief=0.3)),
    4: dict(
        capots=("jaune_capot", "noir_capot"),
        acier=("noir_capot", "galva_capot"),
        rivets="galva_capot",
        joints="rubber",
        danger=("jaune_capot", "noir_capot"),
        plateforme=dict(motif="toles", pas=0.5, mat="tole_larmee", mat2="tole_larmee2", bord="jaune_capot",
                        boulons="galva_capot", relief=0.2)),
    5: dict(
        capots=("basalte_capot", "fonte_v"),
        acier=("fonte_noire", "fonte_v"),
        rivets="burnrust",
        joints="braise_sombre",
        danger=("braise_sombre", "fonte_noire"),
        peinture="burnrust",
        plateforme=dict(motif="dalles", pas=0.34, joint=0.022, mat="basalte_dalle", mat2="basalte_dalle2",
                        fond="fonte_noire", bord="fonte_noire", boulons=None, relief=0.7)),
    6: dict(
        capots=("porcelaine_capot", "bleu_machine"),
        acier=("fonte_bleue", "copper_pol"),
        rivets="copper_pol",
        joints="bakelite",
        plateforme=dict(motif="dalles", pas=0.25, joint=0.012, mat="carreau", mat2="carreau2",
                        fond="bakelite", bord="fonte_bleue", boulons=None)),
    7: dict(
        capots=("bronze_capot", "pierre_claire"),
        acier=("bronze_sombre", "bronze_clair"),
        rivets="bronze_clair",
        joints="joint_violet",
        danger=("pierre_claire", "bronze_sombre"),
        peinture="bronze_sombre",
        plateforme=dict(motif="dalles", pas=0.36, joint=0.014, mat="pierre_claire", mat2="pierre_claire2",
                        # ronde 5 : plus de liseré lumineux au bord du pont (la lumière est le privilège
                        # des âges plus évolués de l'ère : marais et atome)
                        fond="joint_violet", bord="bronze_capot", boulons=None, lisere=None,
                        relief=0.3)),
    8: dict(
        capots=("vdg_capot", "cuivre_terni"),
        acier=("rubber", "vdg_capot"),
        rivets="cuivre_terni",
        joints="rubber",
        danger=("vdg_capot", "rubber"),
        peinture="cuivre_terni",
        plateforme=dict(motif="planches", pas=0.15, mat="bois_mouille", mat2="bois_mousse", fond="tablier",
                        bord="rubber", boulons="cuivre_terni", relief=0.5)),
    9: dict(
        capots=("beton_capot", "lead"),
        acier=("plomb_sombre", "lead"),
        rivets="lead",
        joints="joint_beton",
        plateforme=dict(motif="dalles", pas=0.5, joint=0.018, mat="beton_dalle", mat2="beton_dalle2",
                        fond="joint_beton", bord="plomb_sombre", boulons=None, lisere="emit")),
    10: dict(
        capots=("blanc_casse", "gris_tech"),
        acier=("anthracite", "acier_tech"),
        rivets="rivet_tech",
        danger=("blanc_casse", "bleu_tech"),
        peinture="bleu_tech",
        plateforme=dict(motif="dalles", pas=0.28, joint=0.014, mat="dalle_tech", mat2="dalle_tech2",
                        fond="void", bord="anthracite", boulons=None, lisere=None)),
    11: dict(
        capots=("titane_cl", "titane_md"),
        acier=("titane_dk", "ring"),
        rivets="rivet_ti",
        danger=("orange_aero", "titane_dk"),
        peinture="orange_aero",
        plateforme=dict(motif="toles", mat="tole_ti", mat2="tole_ti2", fond="void", bord="titane_dk",
                        boulons="rivet_ti", relief=0.25, lisere="emit")),
    12: dict(
        capots=("frost", "chrome_mat"),
        acier=("jacket", "ring"),
        rivets="chrome_mat",
        danger=("trim", "jacket"),
        peinture="frost",
        plateforme=dict(motif="dalles", pas=0.28, joint=0.022, mat="noir_miroir", mat2="noir_miroir2",
                        fond="trim", bord="jacket", boulons="chrome_mat", lisere="emit_soft")),
    13: dict(
        capots=("acier_canon", "cuivre_plaque"),
        acier=("acier_noir", "chrome_fin"),
        rivets="chrome_fin",
        joints="acier_noir",
        danger=("cuivre_bobine", "acier_noir"),
        peinture="cuivre_bobine",
        plateforme=dict(motif="toles", mat="acier_canon", mat2="acier_canon2", fond="acier_noir",
                        bord="acier_noir", boulons="chrome_fin", lisere="emit_soft")),
    14: dict(
        capots=("indigo_nuit", "blanc_lunaire"),
        acier=("noir_spatial", "blanc_lunaire"),
        rivets="blanc_lunaire",
        joints="noir_spatial",
        danger=("blanc_lunaire", "indigo_nuit"),
        peinture="indigo_nuit",
        plateforme=dict(motif="toles", mat="indigo_nuit", mat2="indigo_nuit2", fond="noir_spatial",
                        bord="blanc_lunaire", boulons="blanc_lunaire", lisere="emit_soft")),
    15: dict(
        capots=("noir_chaud", "noir_chaud2"),
        acier=("noir_profond", "cendre"),
        rivets="cendre",
        joints="noir_profond",
        danger=("or_chauffe", "noir_profond"),
        peinture="noir_chaud",
        plateforme=dict(motif="dalles", pas=0.28, joint=0.012, mat="noir_chaud", mat2="noir_chaud2",
                        fond="noir_profond", bord="cendre", boulons=None, lisere="emit")),
}


def _m02(metal, M):
    """Tôle de bouclier forgée (acier martelé plus clair que le corps, arêtes usées très claires : le bouclier se lit
    au zoom 1 comme la tôle claire de la mitrailleuse vanilla) et fer chaud (bout de barre sortant du foyer)."""
    metal("forgeplate", (0.46, 0.43, 0.38), rough=0.46, met=0.45, grain=0.24, gscale=30.0, rust=(0.22, 0.08, 0.03),
          ra=0.16, dirt=0.8, stain=0.6, sscale=5.0, wear=2.8, streak=0.45, mottle=0.35)
    # passe 5 : matières du CORPS de forge (grandes masses peu métalliques : un métal pur reste sombre sous ce soleil)
    rust = (0.24, 0.085, 0.03)
    # ronde 2 (test des écarts de la ronde 1 : la forge lue « petit poste sombre rafistolé », prise pour le pionnier) :
    # FER GRIS clair martelé, froid et métallique, à l'opposé du bois brun du pionnier (C1 ≥ 60 des juges) ; les
    # grandes masses montent d'environ 45 %, le fer noir de structure reste sombre mais moins noir
    metal("fer_martele", (0.37, 0.35, 0.325), rough=0.5, met=0.4, grain=0.3, gscale=22.0, rust=rust, ra=0.14,
          dirt=0.7, stain=0.45, sscale=5.0, wear=2.2, mottle=0.45)
    metal("tole_forge", (0.3, 0.29, 0.27), rough=0.55, met=0.4, grain=0.3, gscale=22.0, rust=rust, ra=0.2,
          dirt=0.75, stain=0.5, sscale=5.0, wear=1.6, mottle=0.4)
    metal("tole_forge2", (0.25, 0.24, 0.225), rough=0.55, met=0.4, grain=0.3, gscale=22.0, rust=rust, ra=0.28,
          dirt=0.75, stain=0.5, sscale=5.0, wear=1.6, mottle=0.4)
    metal("fer_noir", (0.1, 0.095, 0.088), rough=0.5, met=0.5, grain=0.3, rust=rust, ra=0.22, dirt=0.7, stain=0.4,
          wear=2.4)
    metal("fer_clair_f", (0.36, 0.34, 0.31), rough=0.45, met=0.45, grain=0.12, dirt=0.4, stain=0.1, wear=0.8,
          reflet="fin")
    # ronde 3 : briques plus franches (rouge brique, moins sales) et pavés du pont en deux tons
    metal("brique_pave", (0.42, 0.135, 0.065), rough=0.85, met=0.0, grain=0.4, gscale=26.0, dirt=0.6, stain=0.45,
          sscale=5.0, wear=0.8, mottle=0.35)
    metal("brique_pave2", (0.34, 0.1, 0.05), rough=0.85, met=0.0, grain=0.4, gscale=26.0, dirt=0.6, stain=0.45,
          sscale=5.0, wear=0.8, mottle=0.35)
    metal("brique", (0.46, 0.14, 0.065), rough=0.85, met=0.0, grain=0.4, gscale=26.0, dirt=0.85, stain=0.6, sscale=5.0,
          wear=0.8, mottle=0.35)
    metal("mortier", (0.1, 0.085, 0.07), rough=0.9, met=0.0, grain=0.2, dirt=0.4, stain=0.0)


def _m03(metal, M):
    """Passe 5 : matières du CORPS de la vapeur (grandes masses claires peu métalliques, règle de reflets du kit)."""
    # ronde 3 : cuivre ROSE poli, plus clair et plus propre (0,56 ; 0,24 ; 0,11 se lisait brun au zoom 1)
    metal("cuivre_capot", (0.7, 0.33, 0.21), rough=0.3, met=0.4, grain=0.1, gscale=30.0, rust=(0.1, 0.2, 0.12),
          ra=0.04, dirt=0.45, stain=0.3, sscale=5.0, wear=0.6)
    metal("cuivre_sombre", (0.26, 0.11, 0.065), rough=0.35, met=0.4, grain=0.12, gscale=30.0, dirt=0.6, stain=0.35,
          sscale=5.0, wear=1.0)
    metal("laiton_pont", (0.6, 0.45, 0.17), rough=0.34, met=0.4, grain=0.14, gscale=30.0, rust=(0.2, 0.12, 0.04),
          ra=0.05, dirt=0.55, stain=0.4, sscale=5.0, wear=0.7)
    metal("laiton_pont2", (0.5, 0.36, 0.13), rough=0.34, met=0.4, grain=0.14, gscale=30.0, rust=(0.2, 0.12, 0.04),
          ra=0.08, dirt=0.55, stain=0.4, sscale=5.0, wear=0.7)
    metal("laiton_capot", (0.68, 0.5, 0.17), rough=0.3, met=0.45, grain=0.1, gscale=30.0, rust=(0.2, 0.12, 0.04),
          ra=0.04, dirt=0.45, stain=0.3, sscale=5.0, wear=0.7)
    metal("laiton_rivet", (0.7, 0.52, 0.22), rough=0.3, met=0.45, grain=0.05, dirt=0.25, stain=0.0, reflet="fin")
    # ronde 5 : tôles du pont en vert locomotive verni, assez clair pour se lire VERT au zoom 1
    metal("vert_pont", (0.06, 0.24, 0.12), rough=0.28, met=0.1, grain=0.12, gscale=30.0, dirt=0.5, stain=0.35,
          sscale=5.0, wear=1.0)
    metal("vert_pont2", (0.045, 0.19, 0.095), rough=0.28, met=0.1, grain=0.12, gscale=30.0, dirt=0.5, stain=0.35,
          sscale=5.0, wear=1.0)
    metal("vert_loco", (0.04, 0.12, 0.065), rough=0.35, met=0.3, grain=0.12, gscale=30.0, dirt=0.65, stain=0.4,
          sscale=5.0, wear=1.4)
    metal("bois_verni", (0.24, 0.085, 0.035), rough=0.3, met=0.0, grain=0.35, gscale=18.0, dirt=0.6, stain=0.35,
          sscale=6.0, wear=0.6, streak=0.3)
    metal("bois_verni2", (0.18, 0.06, 0.026), rough=0.3, met=0.0, grain=0.35, gscale=18.0, dirt=0.6, stain=0.35,
          sscale=6.0, wear=0.6, streak=0.3)
    metal("bois_joint", (0.03, 0.015, 0.008), rough=0.8, met=0.0, grain=0.1, dirt=0.3, stain=0.0)


def _m04(metal, M):
    """Test noir et blanc de la passe 3 : le galvanisé des grands aplats est plus clair (× 1,35)."""
    rust = (0.24, 0.085, 0.03)
    # ronde 3 : la clé « galva » (conduites, frein, jaquette, bagues des cuves) devient de l'acier PEINT EN NOIR satiné
    # (secondaire noir de la palette jaune et noir) ; le nom reste pour ne pas toucher au dessin
    # ronde 3 : acier nu clair du canon (jaquette perforée, frein) : un métal pur vers le nord reste noir (kit, pose N)
    metal("acier_canon", (0.4, 0.39, 0.37), rough=0.4, met=0.35, grain=0.12, gscale=30.0, dirt=0.5, stain=0.3,
          sscale=5.0, wear=1.0)
    metal("noir_capot", (0.045, 0.044, 0.042), rough=0.42, met=0.1, grain=0.15, gscale=30.0, rust=(0.24, 0.085, 0.03),
          ra=0.08, dirt=0.55, stain=0.4, sscale=5.0, wear=2.2, streak=0.3)
    metal("galva", (0.06, 0.059, 0.057), rough=0.38, met=0.3, grain=0.3 * 0.62, gscale=30.0, rust=rust, ra=0.2, dirt=0.8,
          stain=0.75, stain2=0.32, sscale=5.0, wear=1.6, streak=0.45, tone=1.35)
    # passe 5 : jaune délavé des GRANDS CAPOTS (clé « capots ») : matière de corps, ni vive ni réfléchissante, plus
    # claire et moins sale que le jaune des accents (« yellowpaint ») pour se lire jaune au zoom 1
    # ronde 2 (lecteurs de la ronde 1 : « olive laiton », « couleur laiton ») : PEINTURE jaune de chantier délavée,
    # mate et presque pas métallique (un jaune métallique se lit laiton), plus claire et plus pâle
    # (essai a de la ronde 2 : (0,58 ; 0,46 ; 0,12) restait kaki au zoom 1 : la saleté et les taches l'assombrissent ;
    # jaune franc, moins sale)
    # ronde 4 (test des écarts de la ronde 3 : 4 jugé PLUS évolué que 5 par les deux lecteurs, et que 6 par un
    # lecteur : « O doré à dôme ») : la peinture jaune perd son éclat d'or : jaune plus pâle et moins saturé (vraiment
    # « délavé »), écaillée sur la rouille (ra 0,1 -> 0,26), plus sale ; c'est le PREMIER âge de l'ère II, le plus brut
    # ronde 5 (test à l'aveugle de la ronde 4 : 4 lu « laiton, dôme, tuyaux de vapeur », pris pour la VAPEUR) : le
    # jaune pâle (0,7 ; 0,6 ; 0,13) se lisait laiton : il garde sa clarté mais devient un JAUNE DE SIGNALISATION citron
    # franc (bleu presque nul), toujours mat et écaillé : une peinture de chantier, jamais un métal
    metal("jaune_capot", (0.72, 0.6, 0.025), rough=0.75, met=0.0, grain=0.26, gscale=30.0, rust=rust, ra=0.26,
          dirt=0.65, stain=0.55, sscale=5.0, wear=2.4, streak=0.5)
    # jaune des cuves et des fûts : même teinte que la bibliothèque, un peu plus clair et moins sale (aperçu de ronde 1 :
    # il tournait à l'olive brun au zoom 1) ; ronde 2 : mat, comme les capots
    # ronde 5 : même jaune citron que les capots (l'ancien (0,64 ; 0,46 ; 0,07) tirait à l'or et au laiton)
    metal("yellowpaint", (0.66, 0.54, 0.02), rough=0.7, met=0.0, grain=0.2, gscale=30.0, rust=rust, ra=0.2,
          dirt=0.55, stain=0.55, sscale=5.0, wear=2.4, streak=0.5)
    # passe 5 : galvanisé du CORPS (peu métallique : grande masse claire, règle de reflets du kit) et tôles larmées
    metal("galva_capot", (0.32, 0.33, 0.33), rough=0.42, met=0.4, grain=0.15, gscale=30.0, rust=rust, ra=0.12,
          dirt=0.7, stain=0.55, sscale=5.0, wear=1.2, streak=0.35)
    metal("galva_sombre", (0.12, 0.125, 0.13), rough=0.42, met=0.45, grain=0.15, gscale=30.0, rust=rust, ra=0.2,
          dirt=0.75, stain=0.5, wear=1.4)
    # ronde 3 : tôles larmées gris anthracite (plus de galvanisé clair : palette jaune et noir)
    metal("tole_larmee", (0.15, 0.148, 0.145), rough=0.45, met=0.4, grain=0.5, gscale=70.0, rust=rust, ra=0.15,
          dirt=0.8, stain=0.6, sscale=5.0, wear=0.8)
    metal("tole_larmee2", (0.12, 0.118, 0.115), rough=0.45, met=0.4, grain=0.5, gscale=70.0, rust=rust, ra=0.22,
          dirt=0.8, stain=0.6, sscale=5.0, wear=0.8)


def _m05(metal, M):
    """Passe 5 : matières du CORPS du volcan (basalte rugueux non métallique, fonte peu métallique)."""
    metal("basalte_capot", (0.115, 0.112, 0.11), rough=0.75, met=0.05, grain=0.45, gscale=26.0, dirt=0.7, stain=0.55,
          sscale=4.0, wear=1.6, mottle=0.5)
    metal("basalte_dalle", (0.1, 0.097, 0.095), rough=0.8, met=0.0, grain=0.5, gscale=26.0, dirt=0.7, stain=0.6,
          sscale=4.0, wear=1.2, mottle=0.5)
    metal("basalte_dalle2", (0.075, 0.072, 0.07), rough=0.8, met=0.0, grain=0.5, gscale=26.0, dirt=0.7, stain=0.6,
          sscale=4.0, wear=1.2, mottle=0.5)
    # ronde 3 : la fonte des plaques secondaires devient ROUILLE BRÛLÉE (couleur secondaire chaude du volcan)
    metal("fonte_v", (0.27, 0.11, 0.05), rough=0.6, met=0.3, grain=0.3, gscale=30.0, rust=(0.22, 0.07, 0.03),
          ra=0.2, dirt=0.75, stain=0.5, wear=1.6)
    metal("fonte_noire", (0.05, 0.047, 0.045), rough=0.55, met=0.45, grain=0.3, rust=(0.22, 0.07, 0.03), ra=0.15,
          dirt=0.7, stain=0.4, wear=2.0)
    metal("braise_sombre", (0.22, 0.03, 0.008), rough=0.7, met=0.0, grain=0.3, dirt=0.3, stain=0.2)


def _m06(metal, M):
    """Porcelaine des isolateurs (passe 4 : « piles d'isolateurs blancs » ; patinée, arêtes claires, jamais un blanc pur :
    C8) ; elle devient l'accent de l'époque (PT.insulators, peignes et anneaux)."""
    # gris clair chaud des cuves de transformateur (grand volume de l'ouest : se distingue en gris des bunkers noirs
    # du volcan, test de FORME)
    # ronde 2 (test des écarts de la ronde 1 : l'électricité jugée MOINS évoluée que le volcan et que le pétrole,
    # « même octogone, D clair ») : dernier âge de l'ère II, donc le plus riche et le plus clair des trois : porcelaine
    # presque blanche, carreaux blancs, vert d'eau clair de salle des machines, transformateur gris clair.
    metal("transfo", (0.4, 0.39, 0.36), rough=0.42, met=0.3, grain=0.11, gscale=30.0, rust=(0.2, 0.09, 0.04),
          ra=0.12, dirt=0.8, stain=0.7, sscale=5.0, wear=2.0, streak=0.45, mottle=0.35)
    # passe 5 : matières du CORPS (grandes masses claires non métalliques)
    metal("porcelaine_capot", (0.74, 0.73, 0.69), rough=0.28, met=0.0, grain=0.07, gscale=30.0, dirt=0.5, stain=0.25,
          sscale=5.0, wear=0.3, mottle=0.1)
    # ronde 3 (DC, 23/10 9 h 50 : « trop uniforme en terme de palette ») : porcelaine BLANCHE dominante, BLEU
    # ÉLECTRIQUE en secondaire (plaques, flasques, carters, tourelleau, acier de structure : l'ancien vert d'eau), arcs
    # bleus et cuivre des bobines en accent
    metal("bleu_machine", (0.07, 0.2, 0.55), rough=0.34, met=0.15, grain=0.12, gscale=30.0, rust=(0.2, 0.09, 0.04),
          ra=0.04, dirt=0.5, stain=0.35, sscale=5.0, wear=1.0)
    metal("bakelite", (0.035, 0.024, 0.018), rough=0.32, met=0.0, grain=0.1, dirt=0.5, stain=0.2, wear=0.8)
    # acier de structure : fonte peinte BLEU NUIT (ronde 2 : vert sombre ; la bakélite presque noire couvrait tout)
    metal("fonte_bleue", (0.035, 0.07, 0.19), rough=0.4, met=0.3, grain=0.15, dirt=0.6, stain=0.35, wear=1.2)
    metal("carreau", (0.55, 0.555, 0.53), rough=0.3, met=0.0, grain=0.07, dirt=0.55, stain=0.3, sscale=5.0, wear=0.3)
    metal("carreau2", (0.47, 0.48, 0.46), rough=0.3, met=0.0, grain=0.07, dirt=0.55, stain=0.3, sscale=5.0,
          wear=0.3)


def _m07(metal, M):
    """Test noir et blanc de la passe 3 : la pierre des grands aplats est plus sombre (× 0,85)."""
    metal("stone", (0.075, 0.056, 0.044), rough=0.85, met=0.0, grain=0.5 * 0.62, gscale=26.0, dirt=0.9, stain=0.8,
          stain2=0.32, sscale=5.0, wear=2.2, tone=0.85)
    # passe 5 : matières du CORPS du sanctuaire (pierre claire non métallique, bronze peu métallique)
    # ronde 2 (test des écarts de la ronde 1 : le cristal jugé PLUS évolué que le marais et que l'atome, « cristaux et
    # or, dalle blanche ») : premier âge de l'ère III, il descend d'un cran : pierre de grès gris-mauve plus sombre
    # (plus de dalle blanche), bronze patiné brun au lieu du bronze doré ; les cristaux violets restent la signature
    # (essai a : 0,33 se lisait encore « dalle blanche » au zoom 1 ; 0,22)
    metal("pierre_claire", (0.22, 0.2, 0.21), rough=0.85, met=0.0, grain=0.32, gscale=26.0, dirt=0.8, stain=0.55,
          sscale=5.0, wear=0.8, mottle=0.35)
    metal("pierre_claire2", (0.185, 0.168, 0.176), rough=0.85, met=0.0, grain=0.32, gscale=26.0, dirt=0.8, stain=0.55,
          sscale=5.0, wear=0.8, mottle=0.35)
    # ronde 5 (le dôme lu « or » à la ronde 4) : bronze ANCIEN, moins métallique (0,45 -> 0,3) et couvert de patine
    # vert-de-gris (ra 0,12 -> 0,3) : un métal de temple, pas un or
    metal("bronze_capot", (0.36, 0.22, 0.1), rough=0.5, met=0.3, grain=0.14, gscale=30.0, rust=(0.1, 0.2, 0.14),
          ra=0.3, dirt=0.7, stain=0.45, sscale=5.0, wear=0.9)
    metal("bronze_sombre", (0.16, 0.095, 0.045), rough=0.4, met=0.45, grain=0.15, rust=(0.1, 0.2, 0.14), ra=0.1,
          dirt=0.7, stain=0.4, wear=1.2)
    # ronde 3 (test des écarts de la ronde 2 : le cristal encore jugé plus évolué que le marais et l'atome, « dôme doré »)
    # : bronze clair moins doré, plus patiné ; les cristaux violets restent la signature
    metal("bronze_clair", (0.5, 0.33, 0.15), rough=0.36, met=0.45, grain=0.05, dirt=0.25, stain=0.0, reflet="fin")
    metal("joint_violet", (0.06, 0.025, 0.08), rough=0.7, met=0.0, grain=0.1, dirt=0.3, stain=0.0)


def _m08(metal, M):
    """Passe 5 : reflet clair du verre (bande verticale fine sur les cuves : le cylindre se lit verre, pas fût peint)."""
    metal("reflet_verre", (0.5, 0.56, 0.5), rough=0.12, met=0.0, grain=0.05, dirt=0.25, stain=0.1)
    # ronde 4 : verre de la CLOCHE (coupole) : liquide toxique jaune soufré vu à travers un verre épais et brillant
    # ronde 5 : verre VERT ACIDE plus clair (l'olive (0,36 ; 0,34 ; 0,02) tirait au kaki et au jaune du pétrole)
    metal("verre_toxique", (0.3, 0.46, 0.04), rough=0.06, met=0.0, grain=0.06, dirt=0.25, stain=0.2, sscale=4.0)
    # matières du CORPS (vert-de-gris clair peu métallique, cuivre terni, bois mouillé)
    # ronde 2 (test des écarts de la ronde 1 : le marais jugé MOINS évolué que le cristal, « G sombre ») : âge du
    # milieu de l'ère III, il monte d'un cran en clarté : vert-de-gris clair, pont de BOIS FLOTTÉ gris argent (le bois
    # de marais lavé et blanchi) au lieu du bois mouillé presque noir
    metal("vdg_capot", (0.27, 0.46, 0.39), rough=0.55, met=0.2, grain=0.28, gscale=26.0, rust=(0.36, 0.2, 0.1),
          ra=0.14, dirt=0.7, stain=0.5, sscale=4.0, wear=1.4, mottle=0.4)
    metal("cuivre_terni", (0.3, 0.18, 0.1), rough=0.5, met=0.4, grain=0.25, rust=(0.15, 0.3, 0.24), ra=0.4,
          dirt=0.75, stain=0.5, sscale=5.0, wear=1.2)
    # ronde 3 : bois flotté un peu plus chaud (il se lisait « carrelage gris » comme le béton de l'atome)
    metal("bois_mouille", (0.33, 0.27, 0.19), rough=0.6, met=0.0, grain=0.42, gscale=18.0, dirt=0.8, stain=0.6,
          sscale=6.0, wear=0.6, streak=0.45)
    metal("bois_mousse", (0.23, 0.26, 0.18), rough=0.65, met=0.0, grain=0.45, gscale=18.0, dirt=0.8, stain=0.6,
          sscale=6.0, wear=0.6, streak=0.45)


def _m09(metal, M):
    """Passe 4 : PLOMB GRIS MAT (« fûts plombés gris mat » : gris neutre plus clair que le corps, très rugueux, peu
    métallique, sans reflet) ; béton plus clair (× 1,45, test noir et blanc de la passe 3) ; jaune des plaques de
    signalisation (patiné, jamais vif : C5)."""
    # ronde 2 (test des écarts de la ronde 1 : l'atome jugé MOINS évolué que le cristal et que le marais, « gris
    # radioactif ») : dernier âge de l'ère III, le plus clair des trois : béton presque blanc, plomb gris clair, plomb
    # de structure gris moyen (il était presque noir et assombrissait toute la machine)
    metal("lead", (0.25, 0.285, 0.34), rough=0.66, met=0.3, grain=0.28 * 0.62, rust=(0.13, 0.12, 0.105), ra=0.2,
          dirt=0.8, stain=0.55, stain2=0.32, sscale=5.0, wear=1.4, streak=0.4)
    # passe 5 : béton CLAIR (juges de la passe 4 : tours de refroidissement « en béton CLAIR ») : 0,25 -> 0,4 -> 0,56
    # ronde 5 : béton des tours presque blanc (0,56 -> 0,66), comme les capots
    metal("concrete", (0.66, 0.65, 0.62), rough=0.92, met=0.0, grain=0.28, gscale=30.0, dirt=0.85, stain=0.7,
          stain2=0.3, sscale=5.0, wear=1.0, streak=0.45)
    metal("beton_capot", (0.64, 0.63, 0.6), rough=0.85, met=0.0, grain=0.22, gscale=30.0, dirt=0.75, stain=0.55,
          sscale=5.0, wear=0.8, streak=0.3)
    metal("beton_dalle", (0.57, 0.56, 0.53), rough=0.9, met=0.0, grain=0.28, gscale=30.0, dirt=0.8, stain=0.6,
          sscale=5.0, wear=0.6, streak=0.3)
    metal("beton_dalle2", (0.5, 0.495, 0.47), rough=0.9, met=0.0, grain=0.28, gscale=30.0, dirt=0.8, stain=0.6,
          sscale=5.0, wear=0.6, streak=0.3)
    metal("joint_beton", (0.07, 0.07, 0.068), rough=0.9, met=0.0, grain=0.1, dirt=0.3, stain=0.0)
    metal("plomb_sombre", (0.13, 0.155, 0.2), rough=0.6, met=0.3, grain=0.15, dirt=0.7, stain=0.4, wear=1.0)


def _m10(metal, M):
    """Haute technologie : carénage gris clair patiné, noir mat, câbles rouges et bleus, écrans.
    Passe 5, ronde 1 : matières du corps entier (clés d'habillage) ; carénage blanc cassé, peu métallique (une grande
    masse claire reste sous 0,5 de métallicité)."""
    rust = (0.24, 0.085, 0.03)
    # passe 5, ronde 3 (DC, 23/10 : « trop uniforme en terme de palette de couleur » ; 10, 11 et 12 lus « même acier
    # gris », écart 2 et 2 entre 10 et 11) : règle 60/30/10 de l'âge 10 = IVOIRE CHAUD dominant (capots, carénages,
    # pont), ANTHRACITE en second (plaques, acier, goulottes), câbles ROUGE et BLEU vifs et voyants bleus en accent.
    # Ivoire nettement jaune-crème (et non gris clair) : l'âge 11 prend le BLEU, l'âge 12 le blanc glacé et le noir.
    metal("blanc_casse", (0.78, 0.68, 0.46), rough=0.42, met=0.12, grain=0.08, gscale=30.0, dirt=0.4, stain=0.25,
          sscale=6.0, wear=0.5, streak=0.3, mottle=0.15)
    metal("gris_tech", (0.15, 0.155, 0.165), rough=0.45, met=0.3, grain=0.08, gscale=30.0, dirt=0.5, stain=0.3,
          sscale=6.0, wear=0.8)
    metal("anthracite", (0.055, 0.058, 0.064), rough=0.45, met=0.45, grain=0.08, gscale=36.0, dirt=0.5, stain=0.3,
          wear=1.0)
    metal("acier_tech", (0.3, 0.31, 0.33), rough=0.35, met=0.45, grain=0.08, dirt=0.3, stain=0.1, wear=0.5)
    metal("rivet_tech", (0.2, 0.205, 0.215), rough=0.4, met=0.4, grain=0.05, dirt=0.2, stain=0.0, reflet="fin")
    metal("bleu_tech", (0.015, 0.09, 0.45), rough=0.4, met=0.1, grain=0.08, dirt=0.35, stain=0.15, wear=0.5)
    # ronde 2 : pont en DALLES DE FAUX PLANCHER gris chaud clair (salle informatique), joints noirs : le pont noir
    # passe à l'âge 12 (noir à joints de givre). Ronde 3 : dalles BEIGE IVOIRE (dominante de l'âge), plus claires
    metal("dalle_tech", (0.52, 0.45, 0.32), rough=0.55, met=0.08, grain=0.06, dirt=0.35, stain=0.2, sscale=5.0)
    metal("dalle_tech2", (0.44, 0.38, 0.27), rough=0.55, met=0.08, grain=0.06, dirt=0.35, stain=0.2, sscale=5.0)
    # passe 5, ronde 2 : carénage CRÈME chaud (plastique et tôle peinte des années 80), peu métallique, peu sali ;
    # ronde 3 : crème plus franc (ivoire jaune), moins sali
    metal("jacket", (0.76, 0.64, 0.42), rough=0.48, met=0.06, grain=0.08, gscale=30.0, rust=rust, ra=0.02,
          dirt=0.4, stain=0.25, sscale=6.0, wear=0.6, streak=0.3, mottle=0.18)
    metal("pipe", (0.11, 0.108, 0.104), rough=0.5, met=0.2, grain=0.1, dirt=0.6, stain=0.4, wear=1.0)
    metal("cable_b", (0.01, 0.1, 0.62), rough=0.5, met=0.0, grain=0.12, dirt=0.25, stain=0.0)   # bleu vif (ronde 3)
    metal("cable_r", (0.55, 0.03, 0.015), rough=0.5, met=0.0, grain=0.12, dirt=0.25, stain=0.0)  # rouge vif (ronde 3)
    metal("spec", (0.012, 0.03, 0.05), rough=0.15, met=0.3, grain=0.05, dirt=0.2, stain=0.0)       # écrans


def _m11(metal, M):
    """Titane : titane patiné (moyen), alliage blanc PATINÉ (accents larges : manchons, ailerons, colliers).
    Passe 5, ronde 1 : titane et alliage en métal semi-diffus (métallicité 0,45 au lieu de 0,88 et 0,55 : un métal
    pur renvoie le ciel sombre et se lit noir vu de dessus, fait du kit en pose N), titane légèrement bleuté, alliage
    bleu-blanc clair (juges de la passe 4 : « titane brossé bleu-blanc clair ») ; ailerons radiaux 1,4 fois plus
    grands (envergure 0,6 t au lieu de 0,42)."""
    rust = (0.24, 0.085, 0.03)
    # passe 5, ronde 2 (test des écarts : 10 contre 11 noté 2 et 2, « même plan gris » ; 11 lu « acier nu ») : TITANE
    # BROSSÉ nettement plus CLAIR et plus BLEU, moins sali, sur tout le bâtiment ; l'alliage des ailerons et manchons
    # bleu-blanc. L'âge 11 devient le bâtiment CLAIR, FROID et LISSE de l'ère, entre l'électronique crème et anthracite
    # (10) et le givre noir et cyan (12).
    # passe 5, ronde 3 (DC, 23/10 : « trop uniforme en terme de palette de couleur » ; 10 et 11 encore notés 2 et 2,
    # « même acier gris ») : règle 60/30/10 de l'âge 11 = BLEU TITANE franc dominant (titane anodisé : capots, pont,
    # caissons), ALLIAGE blanc bleuté pâle et BLEU NUIT de structure en second, ORANGE aéronautique en accent (bandes
    # de danger, repères des ailerons). Le bleu est saturé et moyen-clair : ni l'ivoire de 10, ni le blanc glacé et
    # le noir de 12.
    # passe 5, ronde 5 (test des écarts de la ronde 4 : 11 jugé MOINS évolué que 10 par un lecteur, « acier bleu
    # massif contre dôme crème câblé » ; lu « char bleu acier ») : tout le titane monte d'environ un cran de valeur
    # (bleu plus lumineux, même teinte) et le liseré du pont passe à pleine lumière : l'âge 11 se lit plus clair,
    # plus net et plus « technique » que l'électronique crème de 10, sans aller au blanc glacé de 12
    metal("jacket", (0.22, 0.38, 0.72), rough=0.32, met=0.3, grain=0.12, gscale=40.0, rust=rust, ra=0.01,
          dirt=0.4, stain=0.2, sscale=6.0, wear=0.6, streak=0.6)
    metal("ring", (0.62, 0.7, 0.84), rough=0.38, met=0.3, grain=0.12, gscale=30.0, rust=(0.2, 0.1, 0.05),
          ra=0.02, dirt=0.45, stain=0.3, sscale=5.0, wear=0.5, streak=0.6)
    # corps entier en titane (passe 5, ronde 1) : brossé = traînées longues (streak), semi-diffus ; ronde 3 : BLEU
    metal("titane_cl", (0.3, 0.5, 0.86), rough=0.32, met=0.3, grain=0.1, gscale=60.0, dirt=0.3, stain=0.18,
          sscale=6.0, wear=0.35, streak=0.7)
    metal("titane_md", (0.16, 0.29, 0.6), rough=0.34, met=0.3, grain=0.1, gscale=60.0, dirt=0.35, stain=0.22,
          sscale=6.0, wear=0.5, streak=0.6)
    metal("titane_dk", (0.035, 0.055, 0.13), rough=0.35, met=0.4, grain=0.1, gscale=50.0, dirt=0.45, stain=0.2,
          wear=0.7, streak=0.4)
    metal("tole_ti", (0.27, 0.44, 0.78), rough=0.36, met=0.3, grain=0.08, gscale=60.0, dirt=0.35, stain=0.2,
          sscale=5.0, streak=0.6)
    metal("tole_ti2", (0.2, 0.35, 0.68), rough=0.36, met=0.3, grain=0.08, gscale=60.0, dirt=0.35, stain=0.2,
          sscale=5.0, streak=0.6)
    metal("rivet_ti", (0.5, 0.6, 0.78), rough=0.35, met=0.35, grain=0.05, dirt=0.2, stain=0.0, reflet="fin")
    metal("bleu_nuit", (0.02, 0.03, 0.075), rough=0.4, met=0.2, grain=0.06, dirt=0.4, stain=0.2)
    metal("orange_aero", (0.8, 0.2, 0.02), rough=0.4, met=0.05, grain=0.06, dirt=0.3, stain=0.15, wear=0.4)


def _m12(metal, M):
    """Supraconducteurs : noir profond, chrome (reflets francs dans la limite commune), givre.
    Passe 5, ronde 1 (lu « bobines empilées, voyants cyan électriques » = Électricité, et « noir à lueurs cyan » en
    passe 4) : le chrome à métallicité 1 renvoyait le ciel sombre et se lisait NOIR vu de dessus (même fait que les
    tubes en pose N, kit passe 5) ; il passe en métal semi-diffus clair (métallicité 0,45, albédo 0,7) : de dessus,
    une bande ARGENT franche. Les grands capots du corps (coupole, jupe, colonne, nacelle, bras, masque) passent en
    GIVRE (gris bleuté pâle mat, clé « capots ») et les plaques ocre en chrome satiné : la tourelle entière se lit
    « froide », sans cuivre (le cuivre est la matière de l'Électricité)."""
    metal("jacket", (0.04, 0.042, 0.047), rough=0.3, met=0.6, grain=0.1, gscale=40.0, dirt=0.5, stain=0.3,
          wear=1.5)
    metal("ring", (0.7, 0.73, 0.76), rough=0.22, met=0.45, grain=0.06, gscale=60.0, dirt=0.4, stain=0.1,
          wear=0.3)
    metal("chrome_mat", (0.48, 0.51, 0.54), rough=0.4, met=0.45, grain=0.1, gscale=50.0, dirt=0.6, stain=0.25,
          wear=0.6)
    # passe 5, ronde 3 (DC, 23/10 : « trop uniforme en terme de palette de couleur » ; 10, 11 et 12 lus « même acier
    # gris ») : règle 60/30/10 de l'âge 12 = BLANC GLACÉ teinté CYAN dominant (capots givrés, givre, mousse des
    # conduites), NOIR MIROIR et CHROME en second (pont, structure, anneaux), CYAN lumineux en accent. Le givre passe
    # d'un gris bleuté à un blanc cyan franc, moins sali : l'âge 11 garde le bleu saturé, l'âge 10 l'ivoire.
    metal("frost", (0.56, 0.84, 0.92), rough=0.75, met=0.05, grain=0.3, gscale=60.0, dirt=0.3, stain=0.3,
          sscale=5.0, wear=0.6, mottle=0.3)                                                     # capots givrés
    metal("noir_miroir", (0.025, 0.03, 0.04), rough=0.2, met=0.5, grain=0.04, gscale=50.0, dirt=0.3, stain=0.1)
    metal("noir_miroir2", (0.04, 0.047, 0.06), rough=0.2, met=0.5, grain=0.04, gscale=50.0, dirt=0.3, stain=0.1)
    metal("grille_chrome", (0.3, 0.33, 0.37), rough=0.3, met=0.45, grain=0.06, gscale=50.0, dirt=0.4, stain=0.1)
    metal("trim", (0.78, 0.94, 0.98), rough=0.9, met=0.0, grain=0.3, gscale=80.0, dirt=0.15, stain=0.15)  # givre
    metal("pipe", (0.56, 0.78, 0.86), rough=0.9, met=0.0, grain=0.35, gscale=50.0, rust=(0.3, 0.4, 0.45),
          ra=0.12, dirt=0.45, stain=0.4, sscale=5.0, streak=0.4)                                  # mousse givrée
    metal("cable_a", (0.018, 0.018, 0.02), rough=0.55, met=0.0, grain=0.1, dirt=0.3, stain=0.0)


def _m13(metal, M):
    """Antimatière : acier canon gris froid à reflet prune (60), cuivre rouge de bobinage (30), verre fumé violet-noir,
    chrome fin, acier noir. Albédos de la fiche convertis en linéaire ; l'acier canon est remonté d'un cran (risque 1
    de la fiche : trois corps sombres de suite, éclaircir 13 d'abord)."""
    # ronde 2 (test à l'aveugle : 13 lu « disque violet sombre, vortex » et pris pour le Néant ; « même squelette » que
    # 14) : acier canon ÉCLAIRCI d'un cran (risque 1 de la fiche : éclaircir 13 d'abord) ; l'ère V descend désormais
    # nettement en valeur, 13 gris moyen, 14 indigo sombre, 15 noir
    metal("acier_canon", (0.2, 0.19, 0.245), rough=0.35, met=0.4, grain=0.1, gscale=34.0, rust=(0.1, 0.06, 0.08),
          ra=0.08, dirt=0.55, stain=0.35, sscale=5.0, wear=1.4, streak=0.35, mottle=0.25)
    metal("acier_canon2", (0.17, 0.16, 0.21), rough=0.36, met=0.4, grain=0.1, gscale=34.0, dirt=0.55, stain=0.35,
          sscale=5.0, wear=1.2, mottle=0.25)
    metal("acier_noir", (0.02, 0.02, 0.028), rough=0.4, met=0.5, grain=0.12, dirt=0.5, stain=0.2, wear=1.6)
    # cuivre de bobinage : métallicité 0,6 au plus (un cuivre à 0,9 sort sombre de dessus, ronde 3)
    metal("cuivre_bobine", (0.46, 0.14, 0.05), rough=0.35, met=0.6, grain=0.16, gscale=60.0, rust=(0.06, 0.12, 0.08),
          ra=0.06, dirt=0.55, stain=0.25, sscale=6.0, wear=0.9)
    metal("cuivre_plaque", (0.36, 0.115, 0.045), rough=0.4, met=0.5, grain=0.12, gscale=36.0, rust=(0.06, 0.12, 0.08),
          ra=0.1, dirt=0.7, stain=0.4, sscale=5.0, wear=1.4, streak=0.4)
    metal("chrome_fin", (0.33, 0.35, 0.4), rough=0.22, met=0.7, grain=0.08, dirt=0.35, stain=0.0, reflet="fin")
    # verre fumé de la cloche : violet-noir, lisse, OPAQUE (aucun sol vu au travers)
    # ronde 1 (aperçu r1a : la cloche se lisait « dôme de cuivre ») : verre plus VIOLET et un peu plus clair
    metal("verre_fume", (0.075, 0.03, 0.17), rough=0.08, met=0.0, grain=0.04, dirt=0.2, stain=0.12, sscale=4.0)
    metal("verre_meneau", (0.055, 0.022, 0.125), rough=0.12, met=0.0, grain=0.04, dirt=0.2, stain=0.1, sscale=4.0)
    # couronne d'isolateurs de la cloche (matière « ceramique » du kit) : acier noir, pour ne pas rappeler l'Électricité
    metal("ceramique", (0.02, 0.02, 0.028), rough=0.4, met=0.5, grain=0.12, dirt=0.5, stain=0.2)


def _m14(metal, M):
    """La Porte : indigo de nuit SATURÉ et mat (doit se lire BLEU au zoom 1, jamais noir : valeur remontée par rapport
    à l'albédo de la fiche, risque 2), blanc lunaire mat patiné de régolithe gris, noir spatial, horizon de la Porte
    (indigo très sombre), roche de météorite."""
    metal("indigo_nuit", (0.034, 0.045, 0.24), rough=0.5, met=0.1, grain=0.08, gscale=30.0, rust=(0.1, 0.1, 0.11),
          ra=0.05, dirt=0.45, stain=0.3, sscale=5.0, wear=1.2, streak=0.3, mottle=0.2)
    metal("indigo_nuit2", (0.028, 0.037, 0.2), rough=0.52, met=0.1, grain=0.08, gscale=30.0, dirt=0.45, stain=0.3,
          sscale=5.0, wear=1.0, mottle=0.2)
    metal("noir_spatial", (0.008, 0.009, 0.016), rough=0.5, met=0.2, grain=0.1, dirt=0.4, stain=0.1, wear=1.2)
    metal("blanc_lunaire", (0.55, 0.57, 0.63), rough=0.6, met=0.05, grain=0.08, gscale=30.0, rust=(0.2, 0.2, 0.2),
          ra=0.06, dirt=0.55, stain=0.25, sscale=5.0, wear=0.4, mottle=0.12)
    metal("horizon_porte", (0.006, 0.008, 0.04), rough=0.3, met=0.0, grain=0.04, dirt=0.1, stain=0.0)
    metal("roche", (0.035, 0.03, 0.028), rough=0.85, met=0.05, grain=0.5, gscale=26.0, dirt=0.7, stain=0.6, wear=2.0)
    # ronde 2 : TUBES des canons en acier BLEUI indigo, satiné (test à l'aveugle de la ronde 1 : les tubes d'acier nu
    # clair à pointes blanches se lisaient « cheminées » en pose N ; fiche §3 E1 : jaquette indigo)
    metal("acier_bleui", (0.05, 0.062, 0.25), rough=0.3, met=0.45, grain=0.08, gscale=40.0, dirt=0.35, stain=0.15,
          sscale=6.0, wear=0.9)


def _m15(metal, M):
    """Néant : noir chaud anthracite brun satiné (patiné : arêtes usées plus claires), or chauffé (patiné, plus mat dans
    les creux), or blanc chaud au contact du disque, horizon (seul vrai noir, lisse). Le noir chaud est remonté d'un
    cran par rapport à l'albédo de la fiche (plancher C1 >= 43 : un corps noir sans arêtes se lirait comme un bloc)."""
    metal("noir_chaud", (0.05, 0.04, 0.031), rough=0.35, met=0.4, grain=0.1, gscale=34.0, rust=(0.12, 0.07, 0.03),
          ra=0.06, dirt=0.5, stain=0.3, sscale=5.0, wear=2.0, streak=0.35, mottle=0.25)
    metal("noir_chaud2", (0.04, 0.032, 0.025), rough=0.36, met=0.4, grain=0.1, gscale=34.0, dirt=0.5, stain=0.3,
          sscale=5.0, wear=1.8, mottle=0.25)
    metal("noir_profond", (0.012, 0.01, 0.008), rough=0.4, met=0.4, grain=0.12, dirt=0.4, stain=0.15, wear=1.6)
    metal("or_chauffe", (0.69, 0.37, 0.06), rough=0.3, met=0.5, grain=0.14, gscale=40.0, rust=(0.2, 0.1, 0.03),
          ra=0.05, dirt=0.55, stain=0.3, sscale=6.0, wear=0.6, mottle=0.15)
    metal("or_blanc_chaud", (0.82, 0.62, 0.3), rough=0.3, met=0.45, grain=0.1, gscale=40.0, dirt=0.35, stain=0.15,
          sscale=6.0, wear=0.4)
    metal("or_rivet", (0.62, 0.36, 0.08), rough=0.45, met=0.45, grain=0.05, dirt=0.25, stain=0.0, reflet="fin")
    # HORIZON : diélectrique lisse presque noir (6 à 8 % de la surface vue au plus)
    metal("horizon", (0.003, 0.003, 0.004), rough=0.06, met=0.0, grain=0.02, dirt=0.05, stain=0.0)
    # ronde 2 : OR VIF de la laisse (griffes, bord du disque) ; CENDRE : usure claire du corps (dents, rivets, boulons,
    # grilles, arêtes du pont), à la place de l'or ; TUBES des canons en acier bruni chaud (les tubes d'acier nu clair à
    # pointes crème se lisaient « cheminées » en pose N)
    metal("or_vif", (0.8, 0.5, 0.1), rough=0.25, met=0.55, grain=0.1, gscale=40.0, dirt=0.3, stain=0.15, sscale=6.0,
          wear=0.4)
    metal("cendre", (0.11, 0.098, 0.085), rough=0.42, met=0.35, grain=0.1, gscale=34.0, dirt=0.4, stain=0.2,
          sscale=5.0, wear=1.6)
    metal("acier_brule", (0.17, 0.13, 0.095), rough=0.3, met=0.6, grain=0.1, gscale=40.0, dirt=0.35, stain=0.15,
          sscale=6.0, wear=1.0)


MATIERES = {
    2: _m02,
    3: _m03,
    4: _m04,
    5: _m05,
    6: _m06,
    7: _m07,
    8: _m08,
    9: _m09,
    10: _m10,
    11: _m11,
    12: _m12,
    13: _m13,
    14: _m14,
    15: _m15,
}
CLES_MATIERES = {
    2: ('forgeplate', 'fer_martele', 'tole_forge', 'tole_forge2', 'fer_noir', 'fer_clair_f', 'brique_pave',
        'brique_pave2', 'brique', 'mortier'),
    3: ('cuivre_capot', 'cuivre_sombre', 'laiton_pont', 'laiton_pont2', 'laiton_capot', 'laiton_rivet', 'vert_pont',
        'vert_pont2', 'vert_loco', 'bois_verni', 'bois_verni2', 'bois_joint'),
    4: ('acier_canon', 'noir_capot', 'galva', 'jaune_capot', 'yellowpaint', 'galva_capot', 'galva_sombre',
        'tole_larmee', 'tole_larmee2'),
    5: ('basalte_capot', 'basalte_dalle', 'basalte_dalle2', 'fonte_v', 'fonte_noire', 'braise_sombre'),
    6: ('transfo', 'porcelaine_capot', 'bleu_machine', 'bakelite', 'fonte_bleue', 'carreau', 'carreau2'),
    7: ('stone', 'pierre_claire', 'pierre_claire2', 'bronze_capot', 'bronze_sombre', 'bronze_clair', 'joint_violet'),
    8: ('reflet_verre', 'verre_toxique', 'vdg_capot', 'cuivre_terni', 'bois_mouille', 'bois_mousse'),
    9: ('lead', 'concrete', 'beton_capot', 'beton_dalle', 'beton_dalle2', 'joint_beton', 'plomb_sombre'),
    10: ('blanc_casse', 'gris_tech', 'anthracite', 'acier_tech', 'rivet_tech', 'bleu_tech', 'dalle_tech',
         'dalle_tech2', 'jacket', 'pipe', 'cable_b', 'cable_r', 'spec'),
    11: ('jacket', 'ring', 'titane_cl', 'titane_md', 'titane_dk', 'tole_ti', 'tole_ti2', 'rivet_ti', 'bleu_nuit',
         'orange_aero'),
    12: ('jacket', 'ring', 'chrome_mat', 'frost', 'noir_miroir', 'noir_miroir2', 'grille_chrome', 'trim', 'pipe',
         'cable_a'),
    13: ('acier_canon', 'acier_canon2', 'acier_noir', 'cuivre_bobine', 'cuivre_plaque', 'chrome_fin', 'verre_fume',
         'verre_meneau', 'ceramique'),
    14: ('indigo_nuit', 'indigo_nuit2', 'noir_spatial', 'blanc_lunaire', 'horizon_porte', 'roche', 'acier_bleui'),
    15: ('noir_chaud', 'noir_chaud2', 'noir_profond', 'or_chauffe', 'or_blanc_chaud', 'or_rivet', 'horizon',
         'or_vif', 'cendre', 'acier_brule'),
}


verifier_familles()
verifier_mesures()
