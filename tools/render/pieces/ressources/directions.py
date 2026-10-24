"""Directions artistiques des gisements (lot M1, 24/10). Python PUR : lu par Blender (gisement.py) et par le
Python système (feuille.py, mesure.py).

Une direction décrit COMMENT un gisement est fait : quelles formes (roches, lames, blocs, grains), en quelles
matières, combien par stade, et s'il porte une couche d'effet (lueur). Le kit (gisement.py) sait poser ces formes
en feuille 8 stades × 8 variantes au format exact des minerais vanilla (feuille.py).

Couleurs : valeurs LINÉAIRES de Blender. Tailles : unités Blender (1 = largeur d'une tuile).

Règle des comptes : la ligne 0 de la feuille est le stade le PLUS RICHE (stage_counts vanilla décroissants) ; les
comptes par stade sont réglés pour que la couverture (part des pixels d'alpha > 0,5 d'une image de 128 px) suive la
vanilla : fer 0,313 / 0,277 / 0,245 / 0,200 / 0,174 / 0,141 / 0,097 / 0,056 (mesure.py --vanilla).
"""

# Couverture vanilla par stade (moyenne fer, cuivre, pierre, charbon ; hr ; mesure.py --vanilla, 24/10).
COUVERTURE_VANILLA = (0.316, 0.270, 0.231, 0.202, 0.165, 0.138, 0.090, 0.055)

# Matières communes (âge 5, Volcan : basalte noir 60 / rouille brûlée 30 / lave orange 10 ; commun/ages.py _m05 et
# PALETTE[5], valeurs recopiées, aucune importation pour ne pas lier le kit minerai au kit des familles).
MAT = {
    # wolframite : noir brunâtre, éclat submétallique (réfléchit le ciel froid)
    # (essai 1 : métallicité 0,6 à 0,95 sous le ciel faible du pipeline = métal NOIR, médiane 35 à 64/255, contre 88
    # pour le fer ; d'où des métaux moins métalliques et plus clairs, et le reflet froid du ciel par CALIB)
    "wolframite": dict(color=(0.040, 0.039, 0.046), rough=0.28, met=0.45, grain=0.25, gscale=40.0, dirt=0.4),
    # acier du tungstène : gris acier dense, reflets froids (couleur de base bleutée : un métal teinte son reflet
    # par sa couleur de base)
    "acier_w": dict(color=(0.40, 0.44, 0.52), rough=0.30, met=0.60, grain=0.12, gscale=55.0, dirt=0.5),
    # acier sombre (faces de blocs moins exposées)
    "acier_sombre": dict(color=(0.19, 0.21, 0.26), rough=0.32, met=0.55, grain=0.15, gscale=55.0, dirt=0.5),
    # basalte de l'âge 5 (basalte_capot de la mitrailleuse validée)
    "basalte": dict(color=(0.115, 0.112, 0.11), rough=0.75, met=0.05, grain=0.45, gscale=26.0, dirt=0.7),
    "basalte_sombre": dict(color=(0.075, 0.072, 0.07), rough=0.8, met=0.0, grain=0.5, gscale=26.0, dirt=0.7),
    # rouille brûlée (fonte_v), en accent sur les grains
    "rouille_brulee": dict(color=(0.27, 0.11, 0.05), rough=0.6, met=0.3, grain=0.3, gscale=30.0, dirt=0.75),
    # cendre (grains au sol)
    "cendre": dict(color=(0.085, 0.080, 0.078), rough=0.9, met=0.0, grain=0.4, gscale=30.0, dirt=0.3),
    # basalte des gisements : plus sombre que le capot de la mitrailleuse (essai 0 : le basalte_capot, éclairé de
    # dessus, sortait gris clair et se lisait « pierre vanilla »)
    "basalte_min": dict(color=(0.045, 0.043, 0.042), rough=0.8, met=0.0, grain=0.45, gscale=26.0, dirt=0.7),
    # cendre claire : grains fins du tapis (plus clairs que le sol de cendres, sinon invisibles)
    "cendre_claire": dict(color=(0.17, 0.16, 0.155), rough=0.9, met=0.0, grain=0.3, gscale=30.0, dirt=0.2),
}
# Tapis de grains fins (le « sable » autour des roches vanilla), commun aux directions : nombre par stade et matières
# (cendre claire, accent de rouille brûlée de l'âge 5, éclats d'acier).
FINS = (90, 78, 66, 56, 46, 36, 24, 14)
FIN_MATS = ("cendre_claire", "cendre_claire", "cendre_claire", "cendre", "rouille_brulee", "acier_w")
# Ronde 2 (A retenue) : les grains d'acier de la ronde 1 faisaient des points blancs épars (« sel ») : remplacés par
# de la wolframite et plus de rouille brûlée.
FIN_MATS_R2 = ("cendre_claire", "cendre_claire", "cendre", "wolframite", "hubnerite", "rouille_brulee")
MAT.update({
    # hübnerite (pôle manganèse de la wolframite) : brun-rouge sombre, l'ACCENT chaud (10 %) qui rappelle la rouille
    # brûlée de l'âge 5 et que ni le fer, ni le charbon, ni la pierre n'ont
    "hubnerite": dict(color=(0.16, 0.050, 0.022), rough=0.45, met=0.30, grain=0.3, gscale=40.0, dirt=0.4),
    # wolframite « miroir » : noir profond, éclat métallique franc (reflets du ciel nets sur fond noir)
    "wolframite_miroir": dict(color=(0.028, 0.028, 0.033), rough=0.20, met=0.75, grain=0.2, gscale=40.0, dirt=0.4),
})
# Lave de l'âge 5 (FOYER[5] = (1,0 ; 0,3 ; 0,02)) : filons émissifs de la direction C.
LAVE = dict(color=(1.0, 0.30, 0.02), strength=6.0, base=(0.06, 0.02, 0.01))

DIRECTIONS = {
    # A : touffes de LAMES de wolframite (cristaux tabulaires noirs à arêtes d'acier) sur un pied de basalte ;
    # silhouette hérissée, ombres longues : aucune roche vanilla n'a cette forme.
    "A": dict(
        nom="lames de wolframite",
        touffes=(6, 5, 5, 4, 3, 3, 2, 1),          # touffes (druses) de lames par stade
        lames=(3, 6),                               # lames par touffe (min, max)
        lame_long=(0.18, 0.34), lame_larg=(0.15, 0.24), lame_ep=(0.07, 0.11), lame_incl=(8, 42),
        lame_mats=("wolframite", "acier_w", "acier_w"),
        roches=(3, 3, 3, 2, 2, 1, 1, 1),            # roches de pied (basalte) par stade
        roche_taille=(0.17, 0.27), roche_mats=("basalte_min", "basalte_min", "wolframite"),
        blocs=(0, 0, 0, 0, 0, 0, 0, 0),
        grains=(14, 12, 10, 9, 7, 6, 4, 3), grain_mats=("cendre", "cendre", "wolframite", "acier_w"),
        rayon=0.60,
        effet="eclats",                             # éclats froids tirés des reflets (feuille.py)
    ),
    # B : BLOCS de métal dense (cuboïdes biseautés gris acier, reflets froids) mêlés d'éclats de wolframite ; angles
    # droits : se lit « métal » et non « roche ».
    "B": dict(
        nom="blocs de métal dense",
        touffes=(0, 0, 0, 0, 0, 0, 0, 0), lames=(0, 0),
        lame_long=(0.0, 0.0), lame_larg=(0.0, 0.0), lame_ep=(0.0, 0.0), lame_incl=(0, 0), lame_mats=("wolframite",),
        roches=(3, 3, 3, 2, 2, 2, 1, 1), roche_taille=(0.15, 0.22), roche_mats=("wolframite", "basalte_min"),
        blocs=(9, 8, 7, 6, 5, 4, 2, 1), bloc_taille=(0.24, 0.36), bloc_haut=(0.11, 0.20),
        bloc_mats=("acier_w", "acier_w", "acier_sombre"),
        grains=(14, 12, 10, 9, 7, 6, 4, 3), grain_mats=("cendre", "cendre", "acier_w", "wolframite"),
        rayon=0.60,
        effet="eclats",
    ),
    # C : VEINE VOLCANIQUE : blocs de basalte arrondis d'où sortent des prismes courts de wolframite, filons de lave
    # orange au sol (couche de lueur rendue par Blender).
    "C": dict(
        nom="veine volcanique",
        touffes=(3, 3, 3, 2, 2, 1, 1, 1), lames=(2, 4),
        lame_long=(0.17, 0.28), lame_larg=(0.13, 0.19), lame_ep=(0.06, 0.09), lame_incl=(10, 40),
        lame_mats=("wolframite", "acier_w"),
        roches=(7, 6, 5, 5, 4, 3, 2, 1), roche_taille=(0.22, 0.34), roche_mats=("basalte_min", "basalte_min", "basalte_sombre"),
        blocs=(0, 0, 0, 0, 0, 0, 0, 0),
        grains=(12, 10, 9, 8, 6, 5, 4, 3), grain_mats=("cendre", "rouille_brulee", "cendre"),
        filons=(3, 3, 2, 2, 2, 1, 1, 0),             # filons de lave par stade
        rayon=0.60,
        effet="lave",
    ),
}

# RONDE 2 (lot M1, 24/10) : la ronde 1 classe A en tête pour la FORME (druses de cristaux, aucune roche vanilla ne
# leur ressemble), mais sa COULEUR moyenne est à ΔE 8 du fer (B : 4 ; C : 11), mesure.py. Palette 60/30/10 de l'âge 5
# appliquée au minerai : 60 % wolframite NOIRE, 30 % acier froid (faces et reflets), 10 % brun-rouge (hübnerite,
# rouille brûlée). Deux variantes :
#   A2 : cristaux surtout noirs submétalliques, quelques cristaux d'acier, accent brun-rouge ;
#   A3 : cristaux noirs « miroir » (reflets froids nets), accent brun-rouge, roches de pied plus rares.
DIRECTIONS["A2"] = dict(DIRECTIONS["A"], nom="druses de wolframite noire (60/30/10)",
                        lame_mats=("wolframite", "wolframite", "wolframite", "acier_w", "acier_w", "hubnerite"),
                        roche_mats=("basalte_min", "wolframite", "hubnerite"),
                        grain_mats=("cendre", "wolframite", "hubnerite", "rouille_brulee"),
                        fin_mats=FIN_MATS_R2)
DIRECTIONS["A3"] = dict(DIRECTIONS["A"], nom="druses de wolframite miroir (60/30/10)",
                        touffes=(7, 6, 6, 5, 4, 3, 2, 1), roches=(2, 2, 2, 2, 1, 1, 1, 0),
                        lame_mats=("wolframite_miroir", "wolframite_miroir", "wolframite_miroir", "acier_w",
                                   "acier_w", "hubnerite"),
                        roche_mats=("basalte_min", "hubnerite"),
                        grain_mats=("cendre", "wolframite", "hubnerite", "rouille_brulee"),
                        fin_mats=FIN_MATS_R2)

# RONDE 3 : A2 et A3 s'écartent du fer (ΔE 17 et 19) mais tombent sur le CHARBON (ΔE 9 et 7) ; leurs reflets ont perdu
# l'acier (p95 119 contre 160 en ronde 1) ; et la hübnerite brun-rouge, rendue en roches lisses, se lit CUIVRE (vu sur la
# planche zoom.png de la ronde 2). A4 : cristaux moitié wolframite noire, moitié acier froid plus clair et plus bleu
# (le reflet froid qui manque au charbon) ; accent brun-rouge sombre réduit aux GRAINS du tapis (aucune roche cuivrée).
MAT["acier_froid"] = dict(color=(0.42, 0.48, 0.62), rough=0.28, met=0.60, grain=0.12, gscale=55.0, dirt=0.5)
MAT["hubnerite_sombre"] = dict(color=(0.07, 0.028, 0.016), rough=0.5, met=0.25, grain=0.3, gscale=40.0, dirt=0.4)
# Correction M1 (24/10, MAJEUR 2 de la vérification) : « 60/30/10 » ci-dessus est une répartition de MATIÈRES dans la
# scène, PAS ce qu'on voit : le reflet du ciel (SKY_GLOSSY_FACTOR) éclaircit la wolframite en gris. Couleurs VUES de la
# feuille A4 livrée (mesure.repartition, aussi dans son MANIFEST.json) : environ 25 % sombres, 72 % acier (42 % bleutés),
# 3 % chauds. Ni le 60/30/10 de matières, ni la palette de l'âge 5 (basalte noir 60 / rouille brûlée 30 / lave orange
# 10) ne sont ce qu'on voit : question au DC (NOTES.md du lot, section « Correction »).
DIRECTIONS["A4"] = dict(DIRECTIONS["A"], nom="druses de wolframite et d'acier froid (acier dominant, mesuré)",
                        touffes=(7, 6, 5, 4, 3, 3, 2, 1),
                        lame_mats=("wolframite", "wolframite", "wolframite", "acier_froid", "acier_froid", "acier_w"),
                        roche_mats=("basalte_min", "basalte_min", "wolframite"),
                        grain_mats=("cendre", "wolframite", "hubnerite_sombre"),
                        fin_mats=("cendre_claire", "cendre_claire", "cendre", "wolframite", "hubnerite_sombre",
                                  "rouille_brulee"))

# Réglages d'étalonnage passés à Blender (--set) : le ciel vu par les SEULS rayons spéculaires × 10 donne aux faces
# métalliques tournées vers le haut le reflet FROID du ciel (fo_calib.SKY_COLOR, bleuté) ; l'éclairage diffus (soleil,
# appoint, ciel × 1) ne change pas. Même mécanisme que la cheminée V0b (tools/render/README.md, SKY_GLOSSY_FACTOR).
CALIB = {k: {"SKY_GLOSSY_FACTOR": 10.0} for k in ("A", "B", "C")}
# Ronde 2 : à × 10, en moteur (captures-essai-A1, zoom 4), les faces du dessus des cristaux sortent BLANC saturé
# (« neige ») et les roches lisses brillent comme des galets mouillés : × 4.
CALIB.update({k: {"SKY_GLOSSY_FACTOR": 4.0} for k in ("A2", "A3")})
CALIB["A4"] = {"SKY_GLOSSY_FACTOR": 5.0}
# Roches anguleuses (ronde 2) : nombre de plans de cassure et angle de lissage (degrés ; ronde 1 : 3 et 38).
ROCHE_COUPES = {"A2": 5, "A3": 5, "A4": 7}
ROCHE_LISSE = {"A2": 22, "A3": 22, "A4": 22}
# A4 (après captures-essai-A4, zoom 2) : les roches de pied, aplaties et peu coupées, se lisaient en DISQUES lisses
# et brillants (galets) : cassures plus profondes (distance des plans 0,35 à 0,7 au lieu de 0,55 à 0,85), roche plus
# haute, basalte mat.
ROCHE_CASSURE = {"A4": (0.35, 0.70)}
ROCHE_APLAT = {"A4": 0.75}
MAT["basalte_brut"] = dict(color=(0.050, 0.047, 0.045), rough=0.95, met=0.0, grain=0.5, gscale=26.0, dirt=0.7)
DIRECTIONS["A4"]["roche_mats"] = ("basalte_brut", "basalte_brut", "wolframite")
# Icônes en gros plan (gisement.cellule_icone) : direction -> réglages. Sans entrée : cellule de gisement agrandie
# (rondes 1 à 3).
ICONE = {"A4": dict(lames=(5, 7), echelle=2.2, roche_mats=("wolframite", "basalte_brut"),
                    lame_mats=("acier_froid", "acier_froid", "wolframite", "acier_w"))}

# Couche d'effet « eclats » (feuille.couleur_effet) : direction -> réglages. Sans entrée : éclats seuls (reflets de
# luminance 0,52 à 0,85, teinte (0,55 ; 0,78 ; 1)), comme le commit a9038a9.
EFFET = {
    # Correction M1 (MAJEUR 1 : de nuit, en moteur, le tungstène ne se distinguait pas du fer) : variante « W2 » de
    # fo-logs/2026-10-24_M1/correction : lueur turquoise froide sur les faces des cristaux ET des galets de basalte, éclats
    # plus larges ; avec les alphas de shared/content/world.lua (0,008 à 0,012, multiplicateur d'obscurité 120) : presque
    # rien de jour, lueur franche de nuit (lisibilite_moteur.py : 7 OK sur les captures en moteur). Les cristaux seuls
    # (variante W6, galets éteints) ne passent pas la nuit : ΔE76 au fer 8,7.
    "A4": dict(teinte=(0.15, 1.0, 0.90), seuil=(0.25, 0.50),
               lueur=dict(lum=(0.03, 0.15), froid=(-0.08, -0.02), gain=1.0)),
}

# ------------------------------------------------------------------------------------------------
# ILMÉNITE (lot X1-TITANE, 25/10) : minerai du titane, âge 11, champs de cratères (docs/SCENARIO_EPOQUES.md).
# Forme PROPRE, ni les druses dressées du tungstène, ni les grains ronds du fer, ni les cailloux de la pierre :
# des NODULES lisses et des PLAQUETTES tabulaires (l'ilménite cristallise en tablettes épaisses), noir de fer à éclat
# submétallique BRUN (pas le reflet bleu-acier du tungstène : métal de base chaud, ciel spéculaire réduit), dont une
# partie porte la croûte d'altération CRÈME du leucoxène (l'altération réelle de l'ilménite) ; tapis de régolithe
# gris clair (poussière d'impact). Lumière de l'âge 11 (docs/DESIGN_EPOQUES.md §1.5) : bleu-blanc #BFE6FF, de nuit
# seulement (couche d'effet à alphas minuscules et grand multiplicateur, comme le tungstène corrigé).
# Choix provisoires, sans verdict du DC (critères D1 à D3).
# ------------------------------------------------------------------------------------------------
MAT.update({
    # ilménite : noir de fer légèrement brun-violet, éclat submétallique
    "ilmenite": dict(color=(0.050, 0.041, 0.042), rough=0.44, met=0.45, grain=0.25, gscale=40.0, dirt=0.4),
    # faces d'ilménite à éclat franc : métal gris BRUN (un métal teinte son reflet par sa couleur de base : chaud, pas
    # l'acier bleuté du tungstène)
    "ilmenite_eclat": dict(color=(0.30, 0.255, 0.24), rough=0.34, met=0.65, grain=0.15, gscale=50.0, dirt=0.4),
    # leucoxène : croûte d'altération crème, mate (la part claire du minerai)
    "leucoxene": dict(color=(0.56, 0.47, 0.32), rough=0.85, met=0.0, grain=0.35, gscale=30.0, dirt=0.5),
    # régolithe des cratères : poussière d'impact gris clair (tapis de grains fins)
    "regolithe": dict(color=(0.20, 0.195, 0.19), rough=0.95, met=0.0, grain=0.3, gscale=30.0, dirt=0.3),
    "regolithe_clair": dict(color=(0.34, 0.33, 0.31), rough=0.95, met=0.0, grain=0.3, gscale=30.0, dirt=0.2),
})
DIRECTIONS["I1"] = dict(
    nom="nodules et plaquettes d'ilménite à croûte de leucoxène",
    touffes=(0, 0, 0, 0, 0, 0, 0, 0), lames=(0, 0),
    lame_long=(0.0, 0.0), lame_larg=(0.0, 0.0), lame_ep=(0.0, 0.0), lame_incl=(0, 0), lame_mats=("ilmenite",),
    # nodules : le corps du gisement
    # essai 2 (32 éch.) : couverture 0,21 → 0,05 contre 0,32 → 0,06 en vanilla, même à l'échelle 1,45 (les places du
    # disque saturent) : production avec des pièces plus grosses et un disque plus large.
    roches=(9, 8, 7, 6, 5, 4, 3, 2), roche_taille=(0.15, 0.24),
    roche_mats=("ilmenite", "ilmenite", "ilmenite_eclat", "ilmenite", "leucoxene"),
    # plaquettes tabulaires, couchées (hauteur faible)
    blocs=(4, 4, 3, 3, 2, 2, 1, 1), bloc_taille=(0.17, 0.25), bloc_haut=(0.035, 0.06),
    bloc_mats=("ilmenite_eclat", "ilmenite", "ilmenite"),
    grains=(16, 14, 12, 10, 8, 6, 5, 3), grain_mats=("regolithe_clair", "leucoxene", "ilmenite"),
    fin_mats=("regolithe", "regolithe_clair", "regolithe_clair", "ilmenite", "leucoxene"),
    rayon=0.65,
    effet="eclats",
)
CALIB["I1"] = {"SKY_GLOSSY_FACTOR": 2.5}
ROCHE_COUPES["I1"] = 5       # essai 1 (2 coupes, lissé 60) : billes noires vernies ; essai 2 : nodules facettés
ROCHE_LISSE["I1"] = 28
ROCHE_APLAT["I1"] = 0.60
ROCHE_CASSURE["I1"] = (0.45, 0.80)
# Icône : 3 ou 4 gros nodules (dont un à croûte) et 2 plaquettes, sans lames (gisement.cellule_icone, réglages
# facultatifs ; le tungstène garde ses valeurs par défaut).
ICONE["I1"] = dict(lames=(0, 0), roches=(4, 5), roche_taille=(0.20, 0.27), roche_coupes=5, roche_cassure=(0.45, 0.80),
                   roche_aplat=0.7, roche_mats=("ilmenite", "leucoxene", "ilmenite_eclat", "leucoxene"),
                   blocs=2, bloc_taille=(0.30, 0.38), bloc_haut=(0.06, 0.09), bloc_mats=("ilmenite_eclat", "ilmenite"))
# Couche d'effet : bleu-blanc de l'âge 11 sur les faces claires (croûtes, éclats) et une lueur plus faible sur tout le
# minerai (froid = (-1, -0,95) : toutes les teintes ; gain 0,55).
EFFET["I1"] = dict(teinte=(0.75, 0.90, 1.0), seuil=(0.22, 0.45),
                   lueur=dict(lum=(0.02, 0.10), froid=(-1.0, -0.95), gain=0.55))

# Échelle des comptes (réglée par mesure de la couverture, feuille.py --couverture) : multiplie touffes, roches,
# blocs et grains d'une direction. 1,0 tant que rien n'est mesuré.
ECHELLE = {"A": 1.0, "B": 1.0, "C": 1.0, "A2": 1.0, "A3": 1.0, "A4": 1.0, "I1": 1.45}

# Graine de chaque direction (hasard local déterministe). A2 à A4 gardent la graine de A : mêmes positions.
GRAINE = {"A": 5101, "B": 5202, "C": 5303, "A2": 5101, "A3": 5101, "A4": 5101, "I1": 6111}

# Grille de rendu : 8 variantes (colonnes) × 8 stades (lignes) + une ligne d'icônes (icône + 3 images d'objet).
COLONNES = 8
STADES = 8
PAS = 3          # écart entre deux cellules, en tuiles (aucune ombre d'une cellule ne déborde sur sa voisine)
