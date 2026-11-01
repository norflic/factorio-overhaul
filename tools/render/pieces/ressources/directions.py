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

# I2 (après les captures en moteur de I1, fo-logs/2026-10-25_X1/captures, tools/autotest/x1_lisibilite.py : 6 OK,
# 3 ECHEC) : la couleur MOYENNE de I1 (103 ; 98 ; 94) tombait à ΔE76 4,5 du fer de jour (noir + crème = gris moyen) et à
# 8 du tungstène de jour comme de nuit. Visée : moyenne plus claire et plus chaude (environ 120 ; 113 ; 100 : ΔE ≥ 10 du
# fer et du tungstène, ≥ 8 de la pierre) : croûte de leucoxène PLUS FRÉQUENTE (40 % des nodules au lieu de 20) et plus
# claire, reflets de l'ilménite bronze (métal de base brun), tapis de régolithe et de leucoxène ; lueur de nuit plus
# blanche et plus forte (gain 0,85) pour s'écarter du turquoise du tungstène.
MAT.update({
    "ilmenite_brun": dict(color=(0.060, 0.044, 0.038), rough=0.42, met=0.45, grain=0.25, gscale=40.0, dirt=0.4),
    "ilmenite_bronze": dict(color=(0.34, 0.26, 0.20), rough=0.32, met=0.65, grain=0.15, gscale=50.0, dirt=0.4),
    "leucoxene_clair": dict(color=(0.66, 0.58, 0.42), rough=0.85, met=0.0, grain=0.35, gscale=30.0, dirt=0.45),
})
DIRECTIONS["I2"] = dict(DIRECTIONS["I1"], nom="nodules d'ilménite bronze à croûte de leucoxène fréquente",
                        roche_mats=("ilmenite_brun", "ilmenite_bronze", "leucoxene_clair", "leucoxene_clair", "ilmenite_brun"),
                        bloc_mats=("ilmenite_bronze", "ilmenite_brun", "ilmenite_brun"),
                        grain_mats=("leucoxene_clair", "regolithe_clair", "leucoxene_clair", "ilmenite_brun"),
                        fin_mats=("regolithe_clair", "leucoxene_clair", "regolithe_clair", "leucoxene", "ilmenite_brun"))
CALIB["I2"] = dict(CALIB["I1"])
ROCHE_COUPES["I2"], ROCHE_LISSE["I2"] = ROCHE_COUPES["I1"], ROCHE_LISSE["I1"]
ROCHE_APLAT["I2"], ROCHE_CASSURE["I2"] = ROCHE_APLAT["I1"], ROCHE_CASSURE["I1"]
ICONE["I2"] = dict(ICONE["I1"], roche_mats=("ilmenite_brun", "leucoxene_clair", "ilmenite_bronze", "leucoxene_clair"),
                   bloc_mats=("ilmenite_bronze", "ilmenite_brun"))
EFFET["I2"] = dict(teinte=(0.85, 0.93, 1.0), seuil=(0.22, 0.45),
                   lueur=dict(lum=(0.02, 0.10), froid=(-1.0, -0.95), gain=0.85))

# I3 (25/10, 2 h 15, après les captures FRAÎCHES de I2 : 8 OK, 1 ECHEC ; la première capture de I2, à 1 h 53, montrait
# encore I1, cache des atlas non refait) : seul J1 échoue, ΔE76 ilménite / fer de jour 7,0 (zoom 1) et 6,8 (zoom 2),
# moyenne en capture (113 ; 108 ; 101). Moyenne en capture ≈ 0,44 × moyenne de la feuille (I1 → I2, 3 canaux) ; il faut
# environ (+12 ; +7 ; +6) en capture, soit (+27 ; +16 ; +14) sur la feuille, vers le ROUX (vers le clair seul, la moyenne
# rejoint le sol gris). Croûte de leucoxène MAJORITAIRE (2 nodules sur 3) dont une part rousse (leucoxène taché
# d'hématite et de rutile, l'altération réelle de l'ilménite), faces d'ilménite bronze-roux ; nuit de I2 inchangée.
# Essai 1 à 32 échantillons (leucoxène roux 0,62 ; 0,43 ; 0,30, ilménite rousse 0,42 ; 0,26 ; 0,18) : moyenne de la
# feuille (132 ; 116 ; 99), capture prédite (124 ; 116 ; 106), J1 prédit 10,6 : trop juste ; roux poussé (essai 2).
MAT.update({
    "leucoxene_roux": dict(color=(0.74, 0.45, 0.30), rough=0.85, met=0.0, grain=0.35, gscale=30.0, dirt=0.45),
    "ilmenite_roux": dict(color=(0.50, 0.28, 0.19), rough=0.32, met=0.65, grain=0.15, gscale=50.0, dirt=0.4),
})
DIRECTIONS["I3"] = dict(DIRECTIONS["I2"], nom="nodules d'ilménite bronze-roux sous croûte de leucoxène majoritaire",
                        roche_mats=("ilmenite_brun", "leucoxene_roux", "leucoxene_clair", "ilmenite_roux",
                                    "leucoxene_clair", "leucoxene_roux"),
                        bloc_mats=("ilmenite_roux", "ilmenite_brun", "leucoxene_roux"),
                        grain_mats=("leucoxene_clair", "leucoxene_roux", "leucoxene_clair", "ilmenite_brun"),
                        fin_mats=("leucoxene_roux", "leucoxene_clair", "regolithe_clair", "leucoxene", "ilmenite_brun"))
CALIB["I3"] = dict(CALIB["I1"])
ROCHE_COUPES["I3"], ROCHE_LISSE["I3"] = ROCHE_COUPES["I1"], ROCHE_LISSE["I1"]
ROCHE_APLAT["I3"], ROCHE_CASSURE["I3"] = ROCHE_APLAT["I1"], ROCHE_CASSURE["I1"]
ICONE["I3"] = dict(ICONE["I1"], roche_mats=("ilmenite_brun", "leucoxene_roux", "ilmenite_roux", "leucoxene_clair"),
                   bloc_mats=("ilmenite_roux", "ilmenite_brun"))
EFFET["I3"] = dict(EFFET["I2"])

# ------------------------------------------------------------------------------------------------
# MONAZITE (lot X2, 25/10) : minerai des terres rares, âge 12, SABLES NOIRS (docs/SCENARIO_EPOQUES.md : « sables
# noirs (rivages, ou dunes) »). Forme PROPRE : un PLACER, tas de grains arrondis (galets de plage) et de petits prismes
# trapus (la monazite cristallise en prismes en coin), éclat RÉSINEUX (rugosité moyenne, aucun métal), couleur MIEL
# à brun-rouge (la monazite réelle), mêlés de grains noirs de magnétite (le sable noir lui-même). Ni les druses
# dressées du tungstène, ni les nodules à croûte de l'ilménite, ni les blocs anguleux de la pierre. Pas de lueur bleue
# (défaut de l'ilménite, trop claire la nuit) : une couche d'effet très faible, AMBRE, sur les faces claires seulement
# (le thorium est faiblement radioactif ; à juger en moteur). Choix provisoires, sans verdict du DC.
# ------------------------------------------------------------------------------------------------
MAT.update({
    # monazite miel (cérium, lanthane) : jaune ambré résineux
    "monazite_miel": dict(color=(0.55, 0.27, 0.045), rough=0.38, met=0.0, grain=0.25, gscale=36.0, dirt=0.35),
    # monazite brun-rouge (thorium) : la part sombre et chaude
    "monazite_brun": dict(color=(0.26, 0.085, 0.022), rough=0.40, met=0.0, grain=0.3, gscale=36.0, dirt=0.4),
    # monazite claire (faces au soleil) : jaune paille
    "monazite_paille": dict(color=(0.70, 0.45, 0.12), rough=0.42, met=0.0, grain=0.2, gscale=36.0, dirt=0.3),
    # magnétite : grains noirs du sable noir, éclat métallique sourd
    "magnetite": dict(color=(0.030, 0.030, 0.034), rough=0.35, met=0.5, grain=0.2, gscale=40.0, dirt=0.3),
    # sable noir (tapis de grains fins, plus clair que le sol pour se lire)
    "sable_noir": dict(color=(0.060, 0.058, 0.060), rough=0.9, met=0.0, grain=0.3, gscale=30.0, dirt=0.2),
})
DIRECTIONS["Z1"] = dict(
    nom="placer de monazite miel et brun-rouge dans le sable noir",
    touffes=(0, 0, 0, 0, 0, 0, 0, 0), lames=(0, 0),
    lame_long=(0.0, 0.0), lame_larg=(0.0, 0.0), lame_ep=(0.0, 0.0), lame_incl=(0, 0), lame_mats=("monazite_miel",),
    # galets arrondis : le corps du placer (peu de coupes, très lissés : grains roulés par les vagues)
    roches=(10, 9, 8, 7, 6, 5, 3, 2), roche_taille=(0.11, 0.19),
    roche_mats=("monazite_miel", "monazite_miel", "monazite_brun", "monazite_paille", "magnetite"),
    # prismes trapus de monazite (cristaux en coin), hauts
    blocs=(5, 4, 4, 3, 3, 2, 1, 1), bloc_taille=(0.09, 0.14), bloc_haut=(0.07, 0.12),
    bloc_mats=("monazite_miel", "monazite_brun", "monazite_paille"),
    grains=(26, 22, 19, 16, 13, 10, 7, 4), grain_mats=("monazite_miel", "monazite_brun", "magnetite", "monazite_paille"),
    fins=(150, 130, 112, 95, 78, 62, 42, 24),
    fin_mats=("sable_noir", "monazite_miel", "magnetite", "monazite_brun", "monazite_miel"),
    rayon=0.62,
    effet="eclats",
)
CALIB["Z1"] = {"SKY_GLOSSY_FACTOR": 2.0}
ROCHE_COUPES["Z1"] = 4
ROCHE_LISSE["Z1"] = 38
ROCHE_APLAT["Z1"] = 0.70
ROCHE_CASSURE["Z1"] = (0.60, 0.90)
ICONE["Z1"] = dict(lames=(0, 0), roches=(5, 6), roche_taille=(0.15, 0.22), roche_coupes=3, roche_cassure=(0.60, 0.90),
                   roche_aplat=0.75, roche_mats=("monazite_miel", "monazite_brun", "monazite_paille", "monazite_miel"),
                   blocs=2, bloc_taille=(0.16, 0.22), bloc_haut=(0.10, 0.15), bloc_mats=("monazite_miel", "monazite_brun"))
# Couche d'effet : ambre très faible sur les faces claires seulement (aucune lueur sur tout le minerai).
EFFET["Z1"] = dict(teinte=(1.0, 0.62, 0.20), seuil=(0.40, 0.75))

# Z2 (25/10, après mesure.py sur Z1, 2e essai à 32 échantillons, couverture réglée : 0,257 → 0,055) : ΔE76 à la PIERRE
# vanilla 8 seulement (moyenne brun-beige, teinte 38°, saturation 0,48, contre 42° et 0,44 pour la pierre ; cuivre 21,
# fer 30, charbon 34, uranium 46). Visée : s'écarter de la pierre par la SATURATION et la teinte (miel doré franc, vers le
# jaune) et par la luminance (un tiers de magnétite noire : moyenne plus sombre que la pierre), brun-rouge rare.
MAT.update({
    "monazite_or": dict(color=(0.62, 0.40, 0.035), rough=0.36, met=0.0, grain=0.22, gscale=36.0, dirt=0.3),
    "monazite_soufre": dict(color=(0.78, 0.62, 0.11), rough=0.40, met=0.0, grain=0.2, gscale=36.0, dirt=0.3),
})
DIRECTIONS["Z2"] = dict(DIRECTIONS["Z1"], nom="placer de monazite miel doré dans le sable noir, un tiers de magnétite",
                        roche_mats=("monazite_or", "monazite_or", "magnetite", "monazite_soufre", "magnetite",
                                    "monazite_brun"),
                        bloc_mats=("monazite_or", "monazite_soufre", "monazite_or"),
                        grain_mats=("monazite_or", "magnetite", "monazite_soufre", "magnetite"),
                        fin_mats=("sable_noir", "monazite_or", "magnetite", "monazite_soufre", "sable_noir"))
CALIB["Z2"] = dict(CALIB["Z1"])
ROCHE_COUPES["Z2"], ROCHE_LISSE["Z2"] = 4, 38
ROCHE_APLAT["Z2"], ROCHE_CASSURE["Z2"] = 0.70, (0.60, 0.90)
ICONE["Z2"] = dict(ICONE["Z1"], roche_mats=("monazite_or", "magnetite", "monazite_soufre", "monazite_or"),
                   bloc_mats=("monazite_or", "monazite_soufre"))
EFFET["Z2"] = dict(teinte=(1.0, 0.70, 0.20), seuil=(0.40, 0.75))

# Z3 (après mesure de Z2 : ΔE76 à la pierre 6, PIRE) : la magnétite noire mêlée au miel donne en MOYENNE un brun-beige
# désaturé, celui de la pierre vanilla (L moy 98 contre 98 ; saturation 0,43 contre 0,44). Une moyenne loin de la pierre
# demande soit beaucoup plus sombre (on tombe sur le charbon), soit plus clair ET plus saturé : jaune d'or franc, qu'aucun
# minerai n'a (pierre beige, cuivre orange-rouge, uranium vert, ilménite saumon-crème). Galets et prismes or et soufre,
# brun-rouge rare, magnétite réduite aux grains fins (le sable noir du sol fait le contraste).
MAT["monazite_soufre_clair"] = dict(color=(0.86, 0.70, 0.16), rough=0.40, met=0.0, grain=0.18, gscale=36.0, dirt=0.25)
DIRECTIONS["Z3"] = dict(DIRECTIONS["Z1"], nom="placer de monazite jaune d'or dans le sable noir",
                        roche_mats=("monazite_soufre_clair", "monazite_or", "monazite_soufre", "monazite_or",
                                    "monazite_soufre_clair", "monazite_brun"),
                        bloc_mats=("monazite_soufre_clair", "monazite_or", "monazite_soufre"),
                        grain_mats=("monazite_soufre", "monazite_or", "monazite_soufre_clair", "magnetite"),
                        fin_mats=("monazite_or", "monazite_soufre", "sable_noir", "monazite_or", "magnetite"))
CALIB["Z3"] = dict(CALIB["Z1"])
ROCHE_COUPES["Z3"], ROCHE_LISSE["Z3"] = 4, 38
ROCHE_APLAT["Z3"], ROCHE_CASSURE["Z3"] = 0.70, (0.60, 0.90)
ICONE["Z3"] = dict(ICONE["Z1"], roche_mats=("monazite_soufre_clair", "monazite_or", "monazite_soufre", "monazite_brun"),
                   bloc_mats=("monazite_soufre_clair", "monazite_or"))
EFFET["Z3"] = dict(teinte=(1.0, 0.78, 0.25), seuil=(0.45, 0.80))
# Production de Z3 à 128 échantillons : stade 1 à 0,256 de couverture contre 0,316 (écart 0,060 > 0,05 toléré par
# check_gisement.py) ; les stades 1 et 2 reçoivent plus de galets et de grains (les autres inchangés).
DIRECTIONS["Z3"]["roches"] = (13, 10, 8, 7, 6, 5, 3, 2)
DIRECTIONS["Z3"]["grains"] = (34, 26, 19, 16, 13, 10, 7, 4)
DIRECTIONS["Z3"]["blocs"] = (6, 5, 4, 3, 3, 2, 1, 1)

# G1 (lot AMELIO-RESSOURCES, 30/10) : GALÈNE, minerai du plomb de l'âge 9 (Atome), gisements classiques hors biome (sol
# vanilla : herbe, terre, désert). Ce qui la distingue de tous les minerais : des CUBES (la galène cristallise en cubes,
# arêtes vives) gris ARGENT à éclat métallique franc, pris dans une gangue de CALCITE blanche ; accent rare de blende
# brun résine (la blende accompagne la galène). Visée : plus clair et plus neutre que le fer (bleu-gris), plus froid et
# plus gris que la pierre (beige), sans la croûte crème de l'ilménite ni le noir du tungstène. Choix provisoire, sans
# verdict du DC.
MAT.update({
    "galene": dict(color=(0.62, 0.63, 0.67), rough=0.22, met=0.70, grain=0.12, gscale=55.0, dirt=0.35),
    "galene_sombre": dict(color=(0.22, 0.23, 0.25), rough=0.28, met=0.60, grain=0.15, gscale=55.0, dirt=0.4),
    "calcite": dict(color=(0.70, 0.69, 0.64), rough=0.60, met=0.0, grain=0.30, gscale=30.0, dirt=0.45),
    "blende": dict(color=(0.30, 0.16, 0.04), rough=0.35, met=0.20, grain=0.25, gscale=40.0, dirt=0.4),
})
DIRECTIONS["G1"] = dict(
    nom="cubes de galène argentée dans une gangue de calcite",
    touffes=(0, 0, 0, 0, 0, 0, 0, 0), lames=(0, 0),
    lame_long=(0.0, 0.0), lame_larg=(0.0, 0.0), lame_ep=(0.0, 0.0), lame_incl=(0, 0), lame_mats=("galene",),
    # gangue : quelques roches de calcite (et de galène massive sombre)
    # essai 1 (32 éch.) : couverture 0,19 au stade 1 (0,32 en vanilla), pièces trop petites et galets de calcite épars
    # (« neige ») : cubes plus gros et plus nombreux, disque plus serré, calcite en grains seulement.
    # production 1 (128 éch.) : couverture 0,240 / 0,246 / 0,251 / 0,234 / 0,226 / 0,180 / 0,109 / 0,079 contre la vanilla
    # 0,316 / 0,270 / 0,231 / 0,202 / 0,165 / 0,138 / 0,090 / 0,055 (check_gisement : écart 0,076) : comptes recalés au
    # rapport vanilla / mesuré, stade par stade.
    roches=(4, 3, 3, 2, 1, 1, 1, 1), roche_taille=(0.16, 0.24),
    roche_mats=("galene_sombre", "calcite", "galene_sombre"),
    # cubes : le corps du gisement (hauteur = côté)
    blocs=(16, 11, 8, 7, 5, 4, 3, 1), bloc_taille=(0.15, 0.24), bloc_haut=(0.13, 0.22),
    bloc_mats=("galene", "galene", "galene", "galene_sombre", "blende"),
    grains=(24, 16, 12, 9, 7, 5, 4, 2), grain_mats=("galene", "galene_sombre", "calcite"),
    fins=(140, 100, 75, 60, 42, 35, 26, 13),
    fin_mats=("calcite", "galene_sombre", "calcite", "galene"),
    rayon=0.55,
    effet="eclats",
)
CALIB["G1"] = {"SKY_GLOSSY_FACTOR": 2.5}
ROCHE_COUPES["G1"] = 5
ROCHE_LISSE["G1"] = 28
ROCHE_APLAT["G1"] = 0.60
ROCHE_CASSURE["G1"] = (0.45, 0.80)
ICONE["G1"] = dict(lames=(0, 0), roches=(2, 3), roche_taille=(0.18, 0.24), roche_coupes=5, roche_cassure=(0.45, 0.80),
                   roche_aplat=0.7, roche_mats=("calcite", "calcite"),
                   blocs=4, bloc_taille=(0.20, 0.28), bloc_haut=(0.18, 0.26), bloc_mats=("galene", "galene", "galene_sombre"))
# Couche d'effet : éclats d'argent froid sur les faces les plus claires des cubes (de nuit surtout).
EFFET["G1"] = dict(teinte=(0.80, 0.90, 1.0), seuil=(0.45, 0.80))

# K1 (lot AMELIO-RESSOURCES, 30/10) : CRISTAL DE RÉSONANCE (âge 7, plaine de cristal). Avant : copie du minerai de fer
# teintée rose-violet (shared/content/world.lua). Retour du DC (29/10, 22 h 50) : « les pierres violettes/rose pas fou par
# contre les bleues claires sont jolies ». Druses de PRISMES bleu glacier dressés (la forme du tungstène, d'autres
# matières : verre de glace, pas de métal), pied de roche grise, givre blanc ; lueur bleu clair de nuit (gisements
# luminescents, X). Choix provisoire, sans verdict du DC.
MAT.update({
    "cristal_glacier": dict(color=(0.42, 0.68, 0.92), rough=0.10, met=0.0, grain=0.08, gscale=50.0, dirt=0.15),
    "cristal_profond": dict(color=(0.14, 0.34, 0.62), rough=0.12, met=0.0, grain=0.10, gscale=50.0, dirt=0.2),
    "cristal_givre": dict(color=(0.80, 0.90, 0.98), rough=0.30, met=0.0, grain=0.15, gscale=40.0, dirt=0.15),
    "roche_grise": dict(color=(0.16, 0.16, 0.18), rough=0.80, met=0.0, grain=0.40, gscale=26.0, dirt=0.6),
})
DIRECTIONS["K1"] = dict(
    nom="druses de prismes bleu glacier",
    touffes=(6, 5, 5, 4, 3, 3, 2, 1), lames=(3, 6),
    lame_long=(0.18, 0.32), lame_larg=(0.10, 0.16), lame_ep=(0.07, 0.11), lame_incl=(5, 35),
    lame_mats=("cristal_glacier", "cristal_glacier", "cristal_profond", "cristal_givre"),
    # essai 1 (32 éch.) : couverture 0,235 au stade 1 ; les galets « cristal_profond » sortaient en billes bleues lisses :
    # roches grises seulement, druses plus nombreuses (échelle 1,3).
    roches=(3, 3, 3, 2, 2, 1, 1, 1), roche_taille=(0.15, 0.24), roche_mats=("roche_grise",),
    blocs=(0, 0, 0, 0, 0, 0, 0, 0), bloc_taille=(0.1, 0.1), bloc_haut=(0.1, 0.1), bloc_mats=("cristal_glacier",),
    grains=(16, 14, 12, 10, 8, 6, 4, 3), grain_mats=("cristal_givre", "cristal_glacier", "roche_grise"),
    fin_mats=("cristal_givre", "roche_grise", "cristal_glacier", "cristal_givre"),
    rayon=0.60,
    effet="eclats",
)
CALIB["K1"] = {"SKY_GLOSSY_FACTOR": 4.0}
EFFET["K1"] = dict(teinte=(0.55, 0.85, 1.0), seuil=(0.30, 0.60),
                   lueur=dict(lum=(0.03, 0.15), froid=(-1.0, -0.95), gain=0.8))

# I2S (lot AMELIO-RESSOURCES, 30/10) : réponse du DC du 25/10 (D-17, RD_LOG) : « ilménite feuille I2 sombre, nuit
# assombrie ». I2 (déjà jugée par lui) avec moins de croûte claire : un nodule sur cinq en leucoxène clair au lieu de
# deux, un leucoxène plus sombre, tapis de régolithe sombre ; lueur de nuit réduite (gain 0,5 au lieu de 0,85 ; le
# multiplicateur d'obscurité baisse aussi dans shared/content/world.lua). Choix provisoire, sans verdict du DC.
MAT["leucoxene_sombre"] = dict(color=(0.42, 0.355, 0.25), rough=0.85, met=0.0, grain=0.35, gscale=30.0, dirt=0.5)
DIRECTIONS["I2S"] = dict(DIRECTIONS["I2"], nom="nodules d'ilménite bronze sombre, croûte de leucoxène rare",
                         roche_mats=("ilmenite_brun", "ilmenite_bronze", "leucoxene_sombre", "ilmenite_brun", "leucoxene_clair"),
                         grain_mats=("leucoxene_sombre", "regolithe", "ilmenite_brun", "leucoxene_clair"),
                         fin_mats=("regolithe", "leucoxene_sombre", "regolithe_clair", "ilmenite_brun", "regolithe"))
CALIB["I2S"] = dict(CALIB["I2"])
ROCHE_COUPES["I2S"], ROCHE_LISSE["I2S"] = ROCHE_COUPES["I2"], ROCHE_LISSE["I2"]
ROCHE_APLAT["I2S"], ROCHE_CASSURE["I2S"] = ROCHE_APLAT["I2"], ROCHE_CASSURE["I2"]
ICONE["I2S"] = dict(ICONE["I2"], roche_mats=("ilmenite_brun", "leucoxene_sombre", "ilmenite_bronze", "ilmenite_brun"))
EFFET["I2S"] = dict(teinte=(0.85, 0.93, 1.0), seuil=(0.22, 0.45),
                    lueur=dict(lum=(0.02, 0.10), froid=(-1.0, -0.95), gain=0.5))

# C1 (lot AMELIO-RESSOURCES, piste ÉTAIN, 30/10) : CASSITÉRITE, minerai de l'étain (âge 4, proposition X3 : « galets brun
# chocolat à éclat adamantin, éclats blancs de quartz (pour ne pas la confondre avec le charbon) »). Un PLACER comme la
# monazite (galets roulés et petits prismes), brun chocolat très brillant (éclat adamantin : rugosité basse, un peu de
# métal), grains de quartz blanc ; tapis de sable clair. Choix provisoire, sans verdict du DC.
MAT.update({
    "cassiterite_brun": dict(color=(0.13, 0.060, 0.028), rough=0.20, met=0.35, grain=0.2, gscale=40.0, dirt=0.35),
    "cassiterite_roux": dict(color=(0.30, 0.13, 0.05), rough=0.22, met=0.30, grain=0.2, gscale=40.0, dirt=0.35),
    "quartz_blanc": dict(color=(0.82, 0.82, 0.79), rough=0.25, met=0.0, grain=0.15, gscale=40.0, dirt=0.2),
    "sable_clair": dict(color=(0.42, 0.37, 0.29), rough=0.9, met=0.0, grain=0.3, gscale=30.0, dirt=0.2),
})
DIRECTIONS["C1"] = dict(DIRECTIONS["Z1"], nom="placer de galets de cassitérite brun chocolat et de quartz blanc",
                        roches=(13, 10, 8, 7, 6, 5, 3, 2),
                        roche_mats=("cassiterite_brun", "cassiterite_brun", "cassiterite_roux", "quartz_blanc", "cassiterite_brun"),
                        blocs=(6, 5, 4, 3, 3, 2, 1, 1),
                        bloc_mats=("cassiterite_brun", "cassiterite_roux", "quartz_blanc"),
                        grains=(34, 26, 19, 16, 13, 10, 7, 4),
                        grain_mats=("cassiterite_brun", "quartz_blanc", "cassiterite_roux", "cassiterite_brun"),
                        fin_mats=("sable_clair", "cassiterite_brun", "quartz_blanc", "sable_clair", "cassiterite_roux"))
CALIB["C1"] = dict(CALIB["Z1"])
ROCHE_COUPES["C1"], ROCHE_LISSE["C1"] = 4, 38
ROCHE_APLAT["C1"], ROCHE_CASSURE["C1"] = 0.70, (0.60, 0.90)
ICONE["C1"] = dict(ICONE["Z1"], roche_mats=("cassiterite_brun", "quartz_blanc", "cassiterite_roux", "cassiterite_brun"),
                   bloc_mats=("cassiterite_brun", "quartz_blanc"))
EFFET["C1"] = dict(teinte=(1.0, 0.97, 0.90), seuil=(0.45, 0.80))

# B1 (lot AMELIO-RESSOURCES, piste BAUXITE, 30/10) : BAUXITE, minerai de l'aluminium (âge 6, proposition X3 : « pisolithes
# mates brique-ocre dans une terre rouille »). Billes rondes (pisolithes : galets très lissés et peu aplatis) brique et
# ocre, MATES (rugosité haute, aucun métal), quelques nodules pâles de gibbsite ; tapis de terre rouille. Sans couche
# d'effet (minerai mat : rien ne luit, ni de jour ni de nuit). Choix provisoire, sans verdict du DC.
MAT.update({
    "bauxite_brique": dict(color=(0.30, 0.085, 0.035), rough=0.85, met=0.0, grain=0.35, gscale=36.0, dirt=0.4),
    "bauxite_ocre": dict(color=(0.46, 0.22, 0.06), rough=0.82, met=0.0, grain=0.35, gscale=36.0, dirt=0.4),
    "gibbsite_pale": dict(color=(0.56, 0.45, 0.33), rough=0.9, met=0.0, grain=0.3, gscale=36.0, dirt=0.3),
    "terre_rouille": dict(color=(0.19, 0.075, 0.035), rough=0.95, met=0.0, grain=0.4, gscale=30.0, dirt=0.3),
})
DIRECTIONS["B1"] = dict(DIRECTIONS["Z1"], nom="pisolithes de bauxite brique et ocre dans une terre rouille",
                        roches=(13, 10, 8, 7, 6, 5, 3, 2),
                        roche_mats=("bauxite_brique", "bauxite_ocre", "bauxite_brique", "gibbsite_pale", "bauxite_ocre"),
                        blocs=(3, 3, 2, 2, 1, 1, 1, 0),
                        bloc_mats=("bauxite_brique", "bauxite_ocre"),
                        grains=(40, 32, 25, 20, 16, 12, 8, 5),
                        grain_mats=("bauxite_ocre", "bauxite_brique", "gibbsite_pale", "bauxite_brique"),
                        fin_mats=("terre_rouille", "bauxite_brique", "bauxite_ocre", "terre_rouille", "gibbsite_pale"),
                        effet=None)
CALIB["B1"] = {"SKY_GLOSSY_FACTOR": 1.0}
ROCHE_COUPES["B1"], ROCHE_LISSE["B1"] = 3, 48
ROCHE_APLAT["B1"], ROCHE_CASSURE["B1"] = 0.88, (0.70, 0.95)
ICONE["B1"] = dict(ICONE["Z1"], roche_mats=("bauxite_brique", "bauxite_ocre", "gibbsite_pale", "bauxite_brique"),
                   bloc_mats=("bauxite_brique", "bauxite_ocre"), roche_aplat=0.88)

# S1 (lot AMELIO-RESSOURCES, piste ZINC, 30/10) : BLENDE, minerai du zinc (âge 3, proposition X3 : « tétraèdres résineux
# couleur miel à rouge rubis »). La forme de la galène G1 (cristaux à arêtes vives, ici plus petits et plus serrés) dans
# une gangue de QUARTZ gris ; matières résineuses (brillantes, sans métal) miel, ambre et rubis sombre. Éclats ambrés
# discrets (éclat résineux). Choix provisoire, sans verdict du DC.
MAT.update({
    "blende_miel": dict(color=(0.42, 0.22, 0.04), rough=0.18, met=0.05, grain=0.15, gscale=45.0, dirt=0.3),
    "blende_rubis": dict(color=(0.26, 0.05, 0.02), rough=0.18, met=0.05, grain=0.15, gscale=45.0, dirt=0.3),
    "blende_ambre": dict(color=(0.58, 0.36, 0.08), rough=0.20, met=0.05, grain=0.15, gscale=45.0, dirt=0.3),
    "quartz_gris": dict(color=(0.46, 0.45, 0.42), rough=0.55, met=0.0, grain=0.30, gscale=30.0, dirt=0.4),
})
DIRECTIONS["S1"] = dict(DIRECTIONS["G1"], nom="cristaux résineux de blende miel et rubis dans une gangue de quartz",
                        roche_mats=("quartz_gris", "blende_rubis", "quartz_gris"),
                        blocs=(18, 13, 10, 8, 6, 5, 3, 1), bloc_taille=(0.12, 0.20), bloc_haut=(0.10, 0.18),
                        bloc_mats=("blende_miel", "blende_ambre", "blende_rubis", "blende_miel"),
                        grain_mats=("blende_miel", "blende_rubis", "quartz_gris"),
                        fin_mats=("quartz_gris", "blende_rubis", "quartz_gris", "blende_miel"))
CALIB["S1"] = {"SKY_GLOSSY_FACTOR": 2.0}
ROCHE_COUPES["S1"], ROCHE_LISSE["S1"] = ROCHE_COUPES["G1"], ROCHE_LISSE["G1"]
ROCHE_APLAT["S1"], ROCHE_CASSURE["S1"] = ROCHE_APLAT["G1"], ROCHE_CASSURE["G1"]
ICONE["S1"] = dict(ICONE["G1"], roche_mats=("quartz_gris", "quartz_gris"), bloc_mats=("blende_miel", "blende_ambre", "blende_rubis"))
EFFET["S1"] = dict(teinte=(1.0, 0.78, 0.40), seuil=(0.45, 0.80))

# G2 (lot AMELIO-RESSOURCES, 30/10, 3 h) : G1 mesurée en production (mesure.py) à ΔE 6 du FER vanilla en couleur moyenne
# (reflets 14) : la gangue grise et les cubes argent font une moyenne bleu-gris, celle du fer. G2 la tire hors du fer :
# gangue de calcite CRÈME chaude (plus de grains et de fins), accents de blende résine plus nombreux, cubes un peu plus
# sombres (plomb) ; couverture du stade 1 relevée (0,233 contre 0,316 en vanilla : blocs × 1,3 au stade 1).
MAT.update({
    "calcite_creme": dict(color=(0.74, 0.66, 0.50), rough=0.60, met=0.0, grain=0.30, gscale=30.0, dirt=0.45),
    "galene_plomb": dict(color=(0.48, 0.49, 0.52), rough=0.24, met=0.70, grain=0.12, gscale=55.0, dirt=0.35),
})
DIRECTIONS["G2"] = dict(DIRECTIONS["G1"], nom="cubes de galène plombée dans une gangue de calcite crème",
                        roches=(5, 3, 3, 2, 1, 1, 1, 1),
                        roche_mats=("calcite_creme", "galene_sombre", "calcite_creme"),
                        blocs=(21, 11, 8, 7, 5, 4, 3, 1),
                        bloc_mats=("galene_plomb", "galene", "galene_plomb", "galene_sombre", "blende", "blende"),
                        grains=(30, 20, 15, 11, 8, 6, 4, 2), grain_mats=("calcite_creme", "galene_plomb", "blende", "calcite_creme"),
                        fin_mats=("calcite_creme", "calcite_creme", "galene_sombre", "blende"))
CALIB["G2"] = dict(CALIB["G1"])
ROCHE_COUPES["G2"], ROCHE_LISSE["G2"] = ROCHE_COUPES["G1"], ROCHE_LISSE["G1"]
ROCHE_APLAT["G2"], ROCHE_CASSURE["G2"] = ROCHE_APLAT["G1"], ROCHE_CASSURE["G1"]
ICONE["G2"] = dict(ICONE["G1"], roche_mats=("calcite_creme", "calcite_creme"), bloc_mats=("galene_plomb", "galene", "blende"))
EFFET["G2"] = dict(EFFET["G1"])

# S2 (30/10, 3 h 10) : S1 mesurée trop clairsemée (couverture 0,216 au stade 1 contre 0,316, écart 0,100) et trop proche de
# la PIERRE en couleur moyenne (ΔE 8 : la gangue de quartz gris y tire). S2 : cristaux plus gros et ×1,45 au stade 1 (comptes
# recalés stade par stade au rapport vanilla / mesuré), gangue presque retirée (grains), rubis plus présent.
DIRECTIONS["S2"] = dict(DIRECTIONS["S1"], nom="cristaux résineux de blende miel et rubis, gros et serrés",
                        roches=(3, 2, 2, 1, 1, 1, 1, 0), roche_mats=("blende_rubis", "quartz_gris", "blende_rubis"),
                        blocs=(26, 18, 12, 9, 7, 6, 4, 2), bloc_taille=(0.15, 0.24), bloc_haut=(0.12, 0.21),
                        bloc_mats=("blende_miel", "blende_rubis", "blende_ambre", "blende_rubis", "blende_miel"),
                        grain_mats=("blende_miel", "blende_rubis", "blende_ambre", "quartz_gris"),
                        fin_mats=("blende_rubis", "blende_miel", "quartz_gris", "blende_rubis"))
CALIB["S2"] = dict(CALIB["S1"])
ROCHE_COUPES["S2"], ROCHE_LISSE["S2"] = ROCHE_COUPES["S1"], ROCHE_LISSE["S1"]
ROCHE_APLAT["S2"], ROCHE_CASSURE["S2"] = ROCHE_APLAT["S1"], ROCHE_CASSURE["S1"]
ICONE["S2"] = dict(ICONE["S1"], roche_mats=("blende_rubis", "quartz_gris"))
EFFET["S2"] = dict(EFFET["S1"])

# C2 à C4 (retour du DC du 30/10, 9 h : « je n'aime pas du tout la forme de ces minerais : […] Cassitérite […]. Il faut
# les refaire. ») : la FORME de C1 est refaite, la couleur brun chocolat gardée. Pourquoi C1 déplaît (planche
# fo-logs/2026-10-30_RETOUR-MATIN/MINERAIS/cassiterite) : (1) silhouette = un DISQUE régulier, la vanilla fait 2 ou 3 tas
# irréguliers ; (2) galets ronds, petits, tous de la même taille, lissés et vernis : « dragées de chocolat », pas un
# minerai ; (3) densité uniforme, aucun gros morceau, aucun vide ; (4) au zoom 1, une tache brune grenue sans forme ;
# (5) même gabarit que la monazite et la bauxite (placer Z1), et le quartz blanc en œufs lisses fait « neige ».
# Trois formes, toutes en AMAS (gisement._places_amas) :
#   C2 : masses ANGULEUSES (cassures franches, peu lissées) de tailles variées, à la manière de la vanilla ;
#   C3 : cristaux BIPYRAMIDAUX (l'habitus réel de la cassitérite, gisement.bipyramide) en gerbes sur une gangue anguleuse ;
#   C4 : masses anguleuses de C2 hérissées de quelques bipyramides (mixte).
# Le quartz n'est plus qu'en esquilles (grains et fins) et en rares petits éclats anguleux. Choix provisoires, sans
# verdict du DC.
MAT.update({
    # éclat adamantin : faces planes très réfléchissantes, un peu de métal (reflets francs sur les cassures)
    "cassiterite_noir": dict(color=(0.065, 0.032, 0.018), rough=0.18, met=0.40, grain=0.2, gscale=40.0, dirt=0.4),
    "cassiterite_ambre": dict(color=(0.42, 0.20, 0.07), rough=0.20, met=0.25, grain=0.2, gscale=40.0, dirt=0.35),
    "sable_etain": dict(color=(0.30, 0.20, 0.12), rough=0.9, met=0.0, grain=0.3, gscale=30.0, dirt=0.2),
})
_C_AMAS = dict(n=(3, 3, 3, 2, 2, 2, 1, 1), etal=0.17, centre=0.60, ecart=0.55)
DIRECTIONS["C2"] = dict(DIRECTIONS["C1"], nom="masses anguleuses de cassitérite brun chocolat, en amas",
                        tas=_C_AMAS, roche_ecart=0.15,
                        roches=(12, 10, 8, 7, 5, 4, 3, 2), roche_taille=(0.09, 0.15), roche_gros=(0.35, (0.17, 0.24)),
                        roche_mats=("cassiterite_brun", "cassiterite_brun", "cassiterite_roux", "cassiterite_noir",
                                    "cassiterite_brun"),
                        blocs=(1, 1, 1, 1, 0, 0, 0, 0), bloc_taille=(0.06, 0.09), bloc_haut=(0.05, 0.08),
                        bloc_mats=("quartz_blanc",),
                        grains=(30, 24, 18, 15, 12, 9, 6, 4),
                        grain_mats=("cassiterite_brun", "cassiterite_roux", "cassiterite_noir", "quartz_blanc"),
                        fins=(160, 135, 115, 95, 78, 62, 42, 24),
                        fin_mats=("sable_etain", "sable_etain", "cassiterite_brun", "cassiterite_roux", "quartz_blanc"))
CALIB["C2"] = dict(CALIB["C1"])
ROCHE_COUPES["C2"], ROCHE_LISSE["C2"] = 7, 20
ROCHE_APLAT["C2"], ROCHE_CASSURE["C2"] = 0.72, (0.35, 0.70)
DIRECTIONS["C3"] = dict(DIRECTIONS["C2"], nom="gerbes de cristaux bipyramidaux de cassitérite sur gangue anguleuse",
                        roches=(6, 5, 4, 4, 3, 2, 2, 1), roche_taille=(0.08, 0.13), roche_gros=(0.25, (0.14, 0.19)),
                        roche_mats=("cassiterite_noir", "cassiterite_brun", "cassiterite_brun"),
                        touffes=(5, 4, 4, 3, 3, 2, 2, 1), lames=(2, 4), lame_forme="bipyramide", touffe_ecart=0.20,
                        lame_long=(0.15, 0.26), lame_larg=(0.09, 0.14), lame_ep=(0.0, 0.0), lame_incl=(15, 60),
                        lame_mats=("cassiterite_brun", "cassiterite_roux", "cassiterite_noir", "cassiterite_ambre"))
CALIB["C3"] = dict(CALIB["C1"])
ROCHE_COUPES["C3"], ROCHE_LISSE["C3"] = 7, 20
ROCHE_APLAT["C3"], ROCHE_CASSURE["C3"] = 0.72, (0.35, 0.70)
DIRECTIONS["C4"] = dict(DIRECTIONS["C2"], nom="masses anguleuses de cassitérite hérissées de cristaux bipyramidaux",
                        roches=(9, 8, 6, 5, 4, 3, 2, 2),
                        touffes=(3, 2, 2, 2, 1, 1, 1, 0), lames=(2, 3), lame_forme="bipyramide", touffe_ecart=0.20,
                        lame_long=(0.14, 0.24), lame_larg=(0.08, 0.13), lame_ep=(0.0, 0.0), lame_incl=(15, 55),
                        lame_mats=("cassiterite_brun", "cassiterite_roux", "cassiterite_ambre"))
CALIB["C4"] = dict(CALIB["C1"])
ROCHE_COUPES["C4"], ROCHE_LISSE["C4"] = 7, 20
ROCHE_APLAT["C4"], ROCHE_CASSURE["C4"] = 0.72, (0.35, 0.70)
for _k in ("C2", "C3", "C4"):
    EFFET[_k] = dict(EFFET["C1"])

# Essai 1 (16 échantillons, planche travail/essai1-cadres.png) : C2 sort en ÉCLATS PLATS (aplatissement et cassures
# profondes) trop petits ; les bipyramides de C3 en BÂTONNETS (prismes trop fins : « allumettes ») ; grains de quartz
# blanc épars = confettis ; couverture 0,18 au stade 1 (vanilla 0,32). Vanilla (fer) : GROS morceaux trapus (0,4 à 0,5
# tuile), hauts, serrés en tas, peu de grains, une poussière dessous. Essai 2 :
#   C5 : gros BLOCS trapus anguleux en tas (la manière vanilla), brun chocolat, aucun cristal ;
#   C6 : C5 dont un tiers des morceaux sont des bipyramides TRAPUES (pointe large, prisme court) : pépites pointues ;
#   C7 : tas de bipyramides trapues serrées sur quelques blocs (cristaux dominants).
# Le quartz n'est plus qu'une poussière (1 fin sur 8).
_C_AMAS2 = dict(n=(3, 3, 2, 2, 2, 2, 1, 1), etal=0.15, centre=0.55, ecart=0.60)
_C_FINS = ("sable_etain", "sable_etain", "sable_etain", "cassiterite_brun", "cassiterite_roux", "sable_etain",
           "cassiterite_noir", "quartz_blanc")
DIRECTIONS["C5"] = dict(DIRECTIONS["C1"], nom="gros blocs anguleux de cassitérite brun chocolat, en tas",
                        tas=_C_AMAS2, roche_ecart=0.17,
                        roches=(10, 9, 7, 6, 5, 4, 3, 2), roche_taille=(0.13, 0.19), roche_gros=(0.30, (0.21, 0.26)),
                        roche_mats=("cassiterite_brun", "cassiterite_brun", "cassiterite_roux", "cassiterite_noir",
                                    "cassiterite_brun", "cassiterite_ambre"),
                        blocs=(0, 0, 0, 0, 0, 0, 0, 0),
                        grains=(10, 8, 7, 6, 5, 4, 3, 2),
                        grain_mats=("cassiterite_brun", "cassiterite_roux", "cassiterite_noir"),
                        fins=(150, 130, 110, 90, 74, 58, 40, 22), fin_mats=_C_FINS)
CALIB["C5"] = dict(CALIB["C1"])
ROCHE_COUPES["C5"], ROCHE_LISSE["C5"] = 6, 25
ROCHE_APLAT["C5"], ROCHE_CASSURE["C5"] = 0.95, (0.45, 0.80)
DIRECTIONS["C6"] = dict(DIRECTIONS["C5"], nom="gros blocs de cassitérite et pépites bipyramidales trapues, en tas",
                        roches=(7, 6, 5, 4, 4, 3, 2, 1),
                        touffes=(3, 3, 2, 2, 2, 1, 1, 1), lames=(1, 3), lame_forme="bipyramide", touffe_ecart=0.18,
                        lame_long=(0.17, 0.26), lame_larg=(0.15, 0.21), lame_ep=(0.0, 0.0), lame_incl=(15, 50),
                        lame_mats=("cassiterite_brun", "cassiterite_roux", "cassiterite_noir", "cassiterite_ambre"))
CALIB["C6"] = dict(CALIB["C1"])
ROCHE_COUPES["C6"], ROCHE_LISSE["C6"] = 6, 25
ROCHE_APLAT["C6"], ROCHE_CASSURE["C6"] = 0.95, (0.45, 0.80)
DIRECTIONS["C7"] = dict(DIRECTIONS["C6"], nom="tas de bipyramides trapues de cassitérite sur quelques blocs",
                        roches=(4, 3, 3, 2, 2, 1, 1, 1), roche_taille=(0.11, 0.16), roche_gros=(0.2, (0.18, 0.22)),
                        roche_mats=("cassiterite_noir", "cassiterite_brun"),
                        touffes=(6, 5, 4, 4, 3, 2, 2, 1), lames=(2, 3))
CALIB["C7"] = dict(CALIB["C1"])
ROCHE_COUPES["C7"], ROCHE_LISSE["C7"] = 6, 25
ROCHE_APLAT["C7"], ROCHE_CASSURE["C7"] = 0.95, (0.45, 0.80)
for _k in ("C5", "C6", "C7"):
    EFFET[_k] = dict(EFFET["C1"])

# Essai 2 (16 échantillons ; travail/essai2-cadres.png, essai2-z1-sable.png, essai2-z2-herbe.png) : les formes tiennent
# (blocs trapus, pointes bipyramidales lisibles au zoom 2 et au-delà) ; C6 retenue (masse « à la vanilla » + signature
# en pointes ; C5 seule = un charbon brun, C7 = pointes illisibles au zoom 1). Défauts : couverture 0,20 au stade 1
# (vanilla 0,32), tas trop serrés au centre du cadre, faces sombres sans reflet franc sur le sable (lecture terne), fins
# brun foncé = miettes sales. C8 = C6 + tas plus nombreux et plus étalés, faces rousses et ambrées plus fréquentes,
# éclat adamantin un peu plus fort (ciel spéculaire × 3), poussière à la couleur du minerai, moins de fins.
DIRECTIONS["C8"] = dict(DIRECTIONS["C6"], nom="blocs et pépites bipyramidales de cassitérite brun chocolat, en tas",
                        tas=dict(n=(4, 3, 3, 3, 2, 2, 2, 1), etal=0.20, centre=0.80, ecart=0.45), roche_ecart=0.19,
                        roches=(10, 9, 7, 6, 5, 4, 3, 2), touffes=(4, 3, 3, 2, 2, 2, 1, 1),
                        roche_mats=("cassiterite_brun", "cassiterite_roux", "cassiterite_brun", "cassiterite_ambre",
                                    "cassiterite_noir", "cassiterite_roux"),
                        grain_mats=("cassiterite_roux", "cassiterite_brun", "cassiterite_ambre"),
                        fins=(110, 95, 80, 66, 54, 42, 28, 16),
                        fin_mats=("cassiterite_roux", "sable_etain", "cassiterite_ambre", "cassiterite_brun", "sable_etain",
                                  "quartz_blanc", "cassiterite_roux", "sable_etain"))
CALIB["C8"] = {"SKY_GLOSSY_FACTOR": 3.0}
ROCHE_COUPES["C8"], ROCHE_LISSE["C8"] = 6, 25
ROCHE_APLAT["C8"], ROCHE_CASSURE["C8"] = 0.95, (0.45, 0.80)
EFFET["C8"] = dict(EFFET["C1"])
# Icône en gros plan : 3 ou 4 blocs et 3 à 5 grosses pépites bipyramidales (gisement.cellule_icone).
ICONE["C8"] = dict(lames=(3, 5), echelle=1.5, roches=(3, 4), roche_taille=(0.17, 0.23), roche_coupes=6,
                   roche_cassure=(0.45, 0.80), roche_aplat=0.95,
                   roche_mats=("cassiterite_brun", "cassiterite_roux", "cassiterite_noir", "cassiterite_brun"),
                   lame_mats=("cassiterite_roux", "cassiterite_ambre", "cassiterite_brun"))

# C9 (mesure.py sur C8 à 16 échantillons) : couverture juste (0,292 → 0,070 contre 0,316 → 0,055) et loin de tous les
# minerais (ΔE76 : fer 23, cuivre 30, charbon 19, pierre 15, uranium 52), mais REFLETS FAIBLES : luminance p95 120 contre
# 186 à 215 pour la vanilla (fer 196, pierre 186, cuivre 216) : lecture terne sur le sable. Même forme ; éclat adamantin
# plus fort (ciel spéculaire × 5) et faces au soleil d'un brun cuir plus clair (la masse reste brun chocolat).
MAT["cassiterite_cuir"] = dict(color=(0.40, 0.19, 0.075), rough=0.20, met=0.30, grain=0.2, gscale=40.0, dirt=0.35)
DIRECTIONS["C9"] = dict(DIRECTIONS["C8"], nom="blocs et pépites bipyramidales de cassitérite brun chocolat à éclat adamantin",
                        roche_mats=("cassiterite_brun", "cassiterite_cuir", "cassiterite_brun", "cassiterite_ambre",
                                    "cassiterite_noir", "cassiterite_roux"),
                        lame_mats=("cassiterite_cuir", "cassiterite_roux", "cassiterite_noir", "cassiterite_ambre"))
CALIB["C9"] = {"SKY_GLOSSY_FACTOR": 5.0}
ROCHE_COUPES["C9"], ROCHE_LISSE["C9"] = 6, 25
ROCHE_APLAT["C9"], ROCHE_CASSURE["C9"] = 0.95, (0.45, 0.80)
EFFET["C9"] = dict(EFFET["C1"])
ICONE["C9"] = dict(ICONE["C8"], roche_mats=("cassiterite_brun", "cassiterite_cuir", "cassiterite_noir", "cassiterite_brun"),
                   lame_mats=("cassiterite_cuir", "cassiterite_ambre", "cassiterite_brun"))

# C10 (critique de directeur artistique, 30/10 vers 10 h 45, CRITIQUE.md de la page) : C9 se lit en jeu comme des
# « copeaux » et du gravier. Contre le charbon et le cuivre vanilla, trois écarts : (1) morceaux plats (cassures
# profondes) et trop nombreux, au lieu de quelques gros blocs trapus ; (2) pièces cuir et ambre claires qui se fondent
# dans le sable (bigarrure) au lieu d'une seule matière éclairée ; (3) grains ronds bien visibles et éclats de quartz
# blanc (gravier, paillettes) au lieu de la POUSSIÈRE sombre et fine qui ancre les tas vanilla au sol. C10 = C9 avec
# moins de morceaux plus gros, plus hauts et moins cassés ; brun chocolat et noir dominants (reflets par l'éclat
# adamantin, pas par la teinte) ; presque plus de grains ; poussière fine et sombre (clé `fin_taille`).
MAT["poussiere_etain"] = dict(color=(0.075, 0.042, 0.024), rough=0.9, met=0.0, grain=0.3, gscale=30.0, dirt=0.2)
DIRECTIONS["C10"] = dict(DIRECTIONS["C9"], nom="gros blocs trapus et pépites bipyramidales de cassitérite brun chocolat sur poussière sombre",
                         roches=(8, 7, 6, 5, 4, 3, 2, 2), roche_taille=(0.15, 0.21), roche_gros=(0.35, (0.22, 0.28)),
                         roche_mats=("cassiterite_brun", "cassiterite_brun", "cassiterite_noir", "cassiterite_roux",
                                     "cassiterite_brun", "cassiterite_noir"),
                         touffes=(3, 3, 2, 2, 2, 1, 1, 1),
                         lame_mats=("cassiterite_brun", "cassiterite_roux", "cassiterite_noir"),
                         grains=(3, 3, 2, 2, 2, 1, 1, 1), grain_mats=("cassiterite_brun", "cassiterite_noir"),
                         fins=(420, 360, 300, 250, 200, 160, 110, 70), fin_taille=(0.007, 0.012),
                         fin_mats=("poussiere_etain", "poussiere_etain", "poussiere_etain", "sable_etain",
                                   "cassiterite_noir"))
CALIB["C10"] = {"SKY_GLOSSY_FACTOR": 5.0}
ROCHE_COUPES["C10"], ROCHE_LISSE["C10"] = 5, 25
ROCHE_APLAT["C10"], ROCHE_CASSURE["C10"] = 1.15, (0.62, 0.88)
EFFET["C10"] = dict(EFFET["C1"])
ICONE["C10"] = dict(ICONE["C9"], roche_aplat=1.15, roche_cassure=(0.62, 0.88),
                    roche_mats=("cassiterite_brun", "cassiterite_noir", "cassiterite_roux", "cassiterite_brun"),
                    lame_mats=("cassiterite_roux", "cassiterite_brun", "cassiterite_noir"))
# C11 (essai C10 à 16 échantillons, essai5) : blocs trapus et matière unie, mieux ; mais la poussière reste en points
# discrets (gravier) et les blocs se soudent en une seule motte ; couverture un peu haute aux stades 2 et 3 (0,290 et
# 0,253 contre 0,270 et 0,231). C11 = C10 avec une poussière 3 fois plus dense et 2 fois plus fine (spray vanilla),
# des blocs un peu plus écartés et un de moins aux stades 2 et 3.
DIRECTIONS["C11"] = dict(DIRECTIONS["C10"], roche_ecart=0.23, roches=(8, 6, 5, 5, 4, 3, 2, 2),
                         fins=(1250, 1050, 880, 730, 590, 460, 320, 190), fin_taille=(0.0035, 0.0065))
CALIB["C11"] = dict(CALIB["C10"])
ROCHE_COUPES["C11"], ROCHE_LISSE["C11"] = ROCHE_COUPES["C10"], ROCHE_LISSE["C10"]
ROCHE_APLAT["C11"], ROCHE_CASSURE["C11"] = ROCHE_APLAT["C10"], ROCHE_CASSURE["C10"]
EFFET["C11"] = dict(EFFET["C10"])
ICONE["C11"] = dict(ICONE["C10"])
# C12 (essai C11, essai6) : la poussière de 0,0035 à 0,0065 tuile passe sous le pixel (64 px par tuile) et disparaît ;
# blocs inchangés. C12 = C11 avec des grains de poussière d'environ 1 px (0,008 à 0,013 tuile), 900 au stade 1.
DIRECTIONS["C12"] = dict(DIRECTIONS["C11"], fins=(900, 780, 650, 540, 430, 340, 230, 140), fin_taille=(0.008, 0.013))
CALIB["C12"] = dict(CALIB["C11"])
ROCHE_COUPES["C12"], ROCHE_LISSE["C12"] = ROCHE_COUPES["C11"], ROCHE_LISSE["C11"]
ROCHE_APLAT["C12"], ROCHE_CASSURE["C12"] = ROCHE_APLAT["C11"], ROCHE_CASSURE["C11"]
EFFET["C12"] = dict(EFFET["C11"])
ICONE["C12"] = dict(ICONE["C11"])
# C13 (essai C12, essai7) : poussière fine et sombre enfin lisible, blocs trapus d'une seule matière ; couverture du
# stade 1 un peu haute (0,342 contre 0,316, dans la tolérance de ± 0,05). C13 = C12 avec un bloc de moins au stade 1.
# Feuille de production (128 échantillons) proposée au DC à la place de C9.
DIRECTIONS["C13"] = dict(DIRECTIONS["C12"], roches=(7, 6, 5, 5, 4, 3, 2, 2))
CALIB["C13"] = dict(CALIB["C12"])
ROCHE_COUPES["C13"], ROCHE_LISSE["C13"] = ROCHE_COUPES["C12"], ROCHE_LISSE["C12"]
ROCHE_APLAT["C13"], ROCHE_CASSURE["C13"] = ROCHE_APLAT["C12"], ROCHE_CASSURE["C12"]
EFFET["C13"] = dict(EFFET["C12"])
ICONE["C13"] = dict(ICONE["C12"])
# C14 (production C13, 128 échantillons) : la direction tient (masse sombre, blocs, reflets), mais check_gisement ÉCHOUE :
# couverture 0,317 / 0,290 / 0,240 / 0,240 / 0,210 / 0,144 / 0,111 / 0,107 (stades 3 et 4 égaux ; stade 8 à + 0,052 de
# la vanilla). C14 = C13 avec moins de blocs aux stades 4, 5 et 8 et moins de poussière aux stades pauvres.
DIRECTIONS["C14"] = dict(DIRECTIONS["C13"], roches=(7, 6, 5, 4, 3, 3, 2, 1),
                         fins=(900, 740, 600, 480, 370, 280, 180, 100))
CALIB["C14"] = dict(CALIB["C13"])
ROCHE_COUPES["C14"], ROCHE_LISSE["C14"] = ROCHE_COUPES["C13"], ROCHE_LISSE["C13"]
ROCHE_APLAT["C14"], ROCHE_CASSURE["C14"] = ROCHE_APLAT["C13"], ROCHE_CASSURE["C13"]
EFFET["C14"] = dict(EFFET["C13"])
ICONE["C14"] = dict(ICONE["C13"])

# ------------------------------------------------------------------------------------------------
# MONAZITE, FORME REFAITE (lot design-minerai-monazite, 30/10). Retour du DC (30/10, vers 9 h) : « je n'aime pas du tout
# la forme de ces minerais : Blende, Cassitérite, Minerai d'ilménite, Minerai de monazite. Il faut les refaire. »
# Pourquoi Z3 déplaît (feuille comparée aux hr vanilla, cadres 128 px, et capture en moteur du 25/10, zoom 4) :
#   1. silhouette : galets CONVEXES, lisses et ronds (4 coupes, lissage 38°) ; une roche vanilla a des rentrants, des
#      arêtes et un côté d'ombre franc ;
#   2. taille : 20 à 30 pièces de taille presque égale par cadre ; la vanilla a 2 ou 3 gros morceaux, des moyens, des
#      petits ;
#   3. densité : un semis RÉGULIER qui remplit un disque parfait (cadre rond, écarts égaux) ; la vanilla fait des amas
#      qui se touchent et laissent des trous ;
#   4. lecture au zoom 1 : jaune pâle uniforme presque sans ombre propre, plus des confettis jaunes (grains et fins
#      dorés) : « pop-corn », « lentilles » ou bonbons (galets brun-rouge lisses), pas un minerai ;
#   5. ressemblance : par la taille et la forme, des cailloux de la pierre vanilla repeints en jaune.
# Trois formes à bas échantillonnage, même palette miel-or (la teinte n'était pas en cause : la carte et la chaîne la
# gardent), plus contrastée (moins de jaune paille, faces miel et brun résine, éclat résineux) :
#   M1 : ROGNONS anguleux (roches à encoches, 7 coupes, peu lissées), en amas, un ou deux gros par cadre ;
#   M2 : rognons de M1 moins nombreux d'où sortent des PRISMES courts et trapus (cristaux en coin dressés) ;
#   M3 : ÉCLATS EN COIN (gisement.coin : base polygonale, dessus incliné, arêtes vives) en amas, quelques rognons.
# Tapis : sable de magnétite brun-noir et grains miel épars (le « sable » sombre des minerais vanilla), plus de
# confettis dorés.
# ------------------------------------------------------------------------------------------------
MAT.update({
    # monazite résine : miel sombre (faces à l'ombre, brun résineux)
    "monazite_resine": dict(color=(0.36, 0.17, 0.028), rough=0.30, met=0.0, grain=0.25, gscale=36.0, dirt=0.45),
    # sable de magnétite brun (tapis : plus chaud et un peu plus clair que le sol de sables noirs)
    "sable_brun": dict(color=(0.10, 0.060, 0.035), rough=0.9, met=0.0, grain=0.3, gscale=30.0, dirt=0.2),
})
ROCHE_CREUX = {}
DIRECTIONS["M1"] = dict(
    nom="rognons anguleux de monazite miel en amas",
    touffes=(0, 0, 0, 0, 0, 0, 0, 0), lames=(0, 0),
    lame_long=(0.0, 0.0), lame_larg=(0.0, 0.0), lame_ep=(0.0, 0.0), lame_incl=(0, 0), lame_mats=("monazite_or",),
    roches=(13, 11, 9, 8, 7, 5, 3, 2), roche_taille=(0.10, 0.165),
    roche_mats=("monazite_or", "monazite_or", "monazite_miel", "monazite_resine", "monazite_soufre", "monazite_miel",
                "monazite_brun"),
    blocs=(0, 0, 0, 0, 0, 0, 0, 0), bloc_taille=(0.1, 0.1), bloc_haut=(0.1, 0.1), bloc_mats=("monazite_or",),
    grains=(14, 12, 10, 9, 7, 6, 4, 2), grain_mats=("monazite_miel", "monazite_resine", "magnetite", "monazite_or"),
    fins=(170, 150, 128, 108, 88, 70, 48, 28),
    fin_mats=("sable_brun", "magnetite", "sable_brun", "monazite_resine", "sable_noir", "monazite_miel"),
    amas=(3, 3, 3, 3, 2, 2, 2, 1), amas_etendue=0.17, amas_serre=0.72,
    gros=((2, 2, 2, 1, 1, 1, 1, 0), 1.55),
    rayon=0.62,
    effet="eclats",
)
CALIB["M1"] = {"SKY_GLOSSY_FACTOR": 3.0}
ROCHE_COUPES["M1"], ROCHE_LISSE["M1"] = 7, 24
ROCHE_APLAT["M1"], ROCHE_CASSURE["M1"] = 0.62, (0.40, 0.75)
ROCHE_CREUX["M1"] = 3
ICONE["M1"] = dict(lames=(0, 0), roches=(4, 5), roche_taille=(0.19, 0.26), roche_coupes=7, roche_cassure=(0.40, 0.75),
                   roche_aplat=0.7, roche_creux=3,
                   roche_mats=("monazite_or", "monazite_miel", "monazite_resine", "monazite_or", "monazite_soufre"))
# Production (128 éch.) : check_gisement refusait UN pixel d'effet hors du minerai (bord d'un rognon) avec le seuil de Z3
# (0,45 à 0,80) : seuil 0,48 à 0,82 (part du minerai allumée 56 %, Z3 : 62 %).
# Captures en moteur x2-supra (30/10, x2_lisibilite.py) au seuil 0,48 à 0,82 : 10 OK, 2 ECHEC (N1 : nuit, ΔE76 au cuivre
# 9,8 / 9,3 ; Z3 donnait 14,0 / 13,7 ; N6 en échec pour moitié comme Z3) : M1, plus sombre que Z3, allume moins de faces
# de nuit. Seuil abaissé à 0,40 à 0,75 (le pixel hors minerai est désormais éteint par feuille.post).
EFFET["M1"] = dict(teinte=(1.0, 0.78, 0.25), seuil=(0.40, 0.75))

DIRECTIONS["M2"] = dict(DIRECTIONS["M1"], nom="rognons de monazite hérissés de prismes en coin",
                        roches=(9, 8, 7, 6, 5, 4, 2, 2),
                        touffes=(4, 4, 3, 3, 2, 2, 1, 1), lames=(2, 4),
                        lame_long=(0.10, 0.17), lame_larg=(0.085, 0.125), lame_ep=(0.06, 0.09), lame_incl=(12, 48),
                        lame_mats=("monazite_or", "monazite_soufre", "monazite_miel", "monazite_or"),
                        roche_mats=("monazite_miel", "monazite_resine", "monazite_or", "monazite_brun", "monazite_miel"))
CALIB["M2"] = dict(CALIB["M1"])
ROCHE_COUPES["M2"], ROCHE_LISSE["M2"] = 7, 24
ROCHE_APLAT["M2"], ROCHE_CASSURE["M2"] = 0.62, (0.40, 0.75)
ROCHE_CREUX["M2"] = 3
ICONE["M2"] = dict(lames=(4, 6), echelle=1.7, roches=(3, 3), roche_taille=(0.18, 0.24), roche_coupes=7,
                   roche_cassure=(0.40, 0.75), roche_aplat=0.7, roche_creux=3,
                   roche_mats=("monazite_miel", "monazite_resine", "monazite_or"),
                   lame_mats=("monazite_or", "monazite_soufre", "monazite_miel"))
EFFET["M2"] = dict(EFFET["M1"])

DIRECTIONS["M3"] = dict(DIRECTIONS["M1"], nom="éclats en coin de monazite miel en amas",
                        roches=(3, 3, 2, 2, 2, 1, 1, 0), roche_taille=(0.09, 0.14),
                        roche_mats=("monazite_resine", "monazite_brun", "monazite_miel"),
                        coins=(12, 10, 9, 8, 6, 5, 3, 2), coin_taille=(0.17, 0.27), coin_haut=(0.07, 0.12),
                        coin_mats=("monazite_or", "monazite_or", "monazite_miel", "monazite_soufre", "monazite_resine",
                                   "monazite_miel"),
                        gros=None, gros_coins=((2, 2, 2, 1, 1, 1, 1, 0), 1.45))
CALIB["M3"] = dict(CALIB["M1"])
ROCHE_COUPES["M3"], ROCHE_LISSE["M3"] = 7, 24
ROCHE_APLAT["M3"], ROCHE_CASSURE["M3"] = 0.62, (0.40, 0.75)
ROCHE_CREUX["M3"] = 2
# Ronde 2 (essai à 12 échantillons, 9 h 27) : formes et amas justes, mais pièces DEUX FOIS trop petites et plates
# (couverture du stade 1 : M1 0,138, M2 0,159, M3 0,114 contre 0,316 en vanilla ; diamètre d'un rognon 17 px hr contre
# 25 à 35 px pour le fer) : tailles × 1,45, rognons plus hauts (aplat 0,78), prismes et coins plus grands.
DIRECTIONS["M1"].update(roche_taille=(0.15, 0.235))
DIRECTIONS["M2"].update(roche_taille=(0.15, 0.235), touffes=(3, 3, 3, 2, 2, 2, 1, 1),
                        lame_long=(0.15, 0.25), lame_larg=(0.11, 0.16), lame_ep=(0.08, 0.12))
DIRECTIONS["M3"].update(roche_taille=(0.13, 0.20), coin_taille=(0.25, 0.38), coin_haut=(0.10, 0.17))
for _k in ("M1", "M2", "M3"):
    ROCHE_APLAT[_k] = 0.78
# Ronde 3 (après l'essai à 12 échantillons de 9 h 43) : M1 RETENUE (rognons anguleux en amas : la silhouette, les tailles
# et les trous de la vanilla ; M2 : les prismes se lisent en bâtonnets, « frites » ; M3 : les coins, petits, se lisent en
# miettes ou en dés). Couverture de M1 0,205 → 0,036 contre 0,316 → 0,055 : rognons × 1,12 et comptes × 1,25 environ ;
# facettes trop « low poly » à 24° : lissage 34° (les plans de cassure restent vifs) ; icône : 4 ou 5 gros rognons
# plus sombres (miel et résine), comme les 4 gros morceaux des icônes vanilla.
DIRECTIONS["M1"].update(roche_taille=(0.165, 0.26), roches=(16, 14, 11, 10, 8, 7, 4, 3),
                        grains=(18, 15, 12, 11, 9, 7, 5, 3))
ROCHE_LISSE["M1"] = 34
ICONE["M1"] = dict(ICONE["M1"], roches=(4, 5), roche_taille=(0.24, 0.30), roche_aplat=0.8,
                   roche_mats=("monazite_or", "monazite_miel", "monazite_resine", "monazite_miel", "monazite_or"))
# Ronde 4 (essai 12 éch. de 9 h 46 : couverture 0,264 / 0,229 / 0,206 / 0,181 / 0,144 / 0,130 / 0,105 / 0,049, stade 1
# hors tolérance de 0,002) : rognons encore plats (lus « éclats de tuile ») et un gros rognon par cadre trop gros (× 1,55,
# 0,8 tuile) : rognons plus hauts et moins coupés (aplat 0,9, cassure 0,45 à 0,80), gros × 1,3, comptes des stades 1 à 5
# relevés ; icône : 4 gros rognons qui remplissent le cadre.
DIRECTIONS["M1"].update(roches=(20, 17, 13, 11, 9, 7, 4, 3), gros=((2, 2, 2, 1, 1, 1, 1, 0), 1.3))
ROCHE_APLAT["M1"], ROCHE_CASSURE["M1"] = 0.90, (0.45, 0.80)
ICONE["M1"] = dict(ICONE["M1"], roches=(4, 4), roche_taille=(0.27, 0.33), roche_aplat=0.9, roche_cassure=(0.45, 0.80))
# Ronde 5 (essai 12 éch. de 9 h 53 : couverture à 0,015 au plus de la vanilla à tous les stades) : les stades riches
# font UN tas serré (« tas de pommes de terre ») ; la vanilla garde des pièces distinctes et des jours : amas plus
# nombreux et plus larges, écart minimal plein (0,95), comptes des stades 1 à 3 un peu réduits.
DIRECTIONS["M1"].update(roches=(18, 15, 12, 11, 9, 7, 4, 3), amas=(4, 4, 3, 3, 3, 2, 2, 1), amas_etendue=0.21,
                        amas_serre=0.95)
# Critique du directeur artistique (30/10, 11 h, CRITIQUE.md de la page) : forme juste, MATIÈRE pas au niveau vanilla.
# (1) deux familles de teinte mêlées (jaune citron « soufre » et brun-rouge « brun ») : bruit de pixels au zoom 1,
# lecture « corn flakes », « feuilles mortes », et le brun-rouge rapproche du cuivre, de la bauxite et de la blende ;
# (2) faces mates (rugosité 0,36 à 0,40) : aucun reflet franc, alors que le cuivre et le fer vanilla en ont un et que
# la monazite réelle a un éclat RÉSINEUX ; (3) grains de magnétite tombés sur les rognons : points noirs au zoom 4.
# Correction de MATIÈRE seule : mêmes longueurs de listes de matières, donc mêmes tirages (rng.choice) et MÊME
# géométrie, même couverture que M1 production ; une seule famille or-miel-ambre, éclat résineux (rugosité 0,24 à
# 0,28), une pièce sur sept en résine sombre pour la profondeur, plus de soufre ni de brun-rouge ; grains sans magnétite
# (la magnétite reste dans le tapis de fins, au sol).
MAT.update({
    "monazite_or_v": dict(color=(0.62, 0.40, 0.035), rough=0.24, met=0.0, grain=0.22, gscale=36.0, dirt=0.3),
    "monazite_miel_v": dict(color=(0.50, 0.25, 0.040), rough=0.26, met=0.0, grain=0.25, gscale=36.0, dirt=0.35),
    "monazite_ambre": dict(color=(0.58, 0.33, 0.035), rough=0.24, met=0.0, grain=0.22, gscale=36.0, dirt=0.3),
})
DIRECTIONS["M1"].update(
    roche_mats=("monazite_or_v", "monazite_or_v", "monazite_miel_v", "monazite_ambre", "monazite_or_v",
                "monazite_miel_v", "monazite_resine"),
    grain_mats=("monazite_miel_v", "monazite_resine", "monazite_resine", "monazite_or_v"))
ICONE["M1"] = dict(ICONE["M1"], roche_mats=("monazite_or_v", "monazite_miel_v", "monazite_ambre", "monazite_miel_v",
                                            "monazite_or_v"))
ICONE["M3"] = dict(lames=(0, 0), roches=(1, 2), roche_taille=(0.14, 0.18), roche_coupes=7, roche_cassure=(0.40, 0.75),
                   roche_aplat=0.7, roche_creux=2, roche_mats=("monazite_resine", "monazite_miel"),
                   coins=4, coin_taille=(0.30, 0.40), coin_haut=(0.14, 0.20),
                   coin_mats=("monazite_or", "monazite_miel", "monazite_soufre", "monazite_or"))
EFFET["M3"] = dict(EFFET["M1"])

# Échelle des comptes (réglée par mesure de la couverture, feuille.py --couverture) : multiplie touffes, roches,
# blocs et grains d'une direction. 1,0 tant que rien n'est mesuré.
ECHELLE = {"A": 1.0, "B": 1.0, "C": 1.0, "A2": 1.0, "A3": 1.0, "A4": 1.0, "I1": 1.45, "I2": 1.45, "I3": 1.45,
           "Z1": 1.6, "Z2": 1.6, "Z3": 1.6, "G1": 1.45, "K1": 1.3, "I2S": 1.45, "C1": 1.6, "B1": 1.6, "S1": 1.45, "G2": 1.45, "S2": 1.45,
           "C2": 1.3, "C3": 1.3, "C4": 1.3, "C5": 1.3, "C6": 1.3, "C7": 1.3, "C8": 1.5, "C9": 1.5, "C10": 1.5, "C11": 1.5, "C12": 1.5, "C13": 1.5, "C14": 1.5,
           "M1": 1.0, "M2": 1.0, "M3": 1.0}

# Graine de chaque direction (hasard local déterministe). A2 à A4 gardent la graine de A : mêmes positions.
GRAINE = {"A": 5101, "B": 5202, "C": 5303, "A2": 5101, "A3": 5101, "A4": 5101, "I1": 6111, "I2": 6111, "I3": 6111,
          "Z1": 6212, "Z2": 6212, "Z3": 6212, "G1": 6313, "K1": 6414, "I2S": 6111, "C1": 6515, "B1": 6616, "S1": 6717, "G2": 6313, "S2": 6717,
          "C2": 6515, "C3": 6515, "C4": 6515, "C5": 6515, "C6": 6515, "C7": 6515, "C8": 6515, "C9": 6515, "C10": 6515, "C11": 6515, "C12": 6515, "C13": 6515, "C14": 6515,
          "M1": 6818, "M2": 6818, "M3": 6818}

# Grille de rendu : 8 variantes (colonnes) × 8 stades (lignes) + une ligne d'icônes (icône + 3 images d'objet).
COLONNES = 8
STADES = 8
PAS = 3          # écart entre deux cellules, en tuiles (aucune ombre d'une cellule ne déborde sur sa voisine)

# ------------------------------------------------------------------------------------------------
# BLENDE, REFAITE (lot DESIGN-BLENDE, 30/10, retour du DC du matin : « je n'aime pas du tout la forme de ces minerais :
# Blende, ... Il faut les refaire »). S2 (livrée) : petits CUBES biseautés (la recette de la galène G1, réutilisée) et
# galets rouges lisses : se lisait « dés et bonbons », doublon de forme de la galène, confettis au zoom 1, sans gros
# morceau dominant. Trois formes nouvelles, même teinte (miel, ambre, rubis) plus le noir résineux de la blende réelle
# (« black jack ») qui donne la profondeur que S2 n'avait pas :
#   S3 : MORCEAUX CLIVÉS (la blende massive se casse en faces planes brillantes, clivage parfait) : des blocs de la
#        taille des cailloux vanilla, à grandes facettes nettes, sur un tapis de poussière miel ;
#   S4 : DRUSES DE TÉTRAÈDRES tronqués (la forme cristalline de la sphalérite), pointes dressées, sur une matrice sombre ;
#   S5 : MIXTE : morceaux clivés sombres (noir résineux, rubis) d'où sortent des tétraèdres miel et ambre.
# ------------------------------------------------------------------------------------------------
MAT.update({
    # blende noire (« black jack », riche en fer) : brun-noir résineux, reflets francs
    "blende_noire": dict(color=(0.040, 0.018, 0.009), rough=0.14, met=0.08, grain=0.15, gscale=45.0, dirt=0.3),
    # poussière de blende : tapis de grains fins miel-brun (plus clair que la terre pour se lire)
    "poussiere_miel": dict(color=(0.30, 0.17, 0.05), rough=0.9, met=0.0, grain=0.3, gscale=30.0, dirt=0.2),
})
_S_BASE = dict(
    touffes=(0, 0, 0, 0, 0, 0, 0, 0), lames=(0, 0),
    lame_long=(0.0, 0.0), lame_larg=(0.0, 0.0), lame_ep=(0.0, 0.0), lame_incl=(0, 0), lame_mats=("blende_miel",),
    blocs=(0, 0, 0, 0, 0, 0, 0, 0), bloc_taille=(0.1, 0.1), bloc_haut=(0.1, 0.1), bloc_mats=("blende_miel",),
    grains=(16, 14, 12, 10, 8, 6, 4, 3), grain_mats=("blende_miel", "blende_noire", "blende_rubis", "blende_ambre"),
    fins=(110, 96, 82, 70, 58, 46, 30, 16),
    fin_mats=("poussiere_miel", "poussiere_miel", "blende_noire", "blende_rubis", "blende_miel"),
    rayon=0.60,
    effet="eclats",
)
DIRECTIONS["S3"] = dict(_S_BASE, nom="morceaux clivés de blende miel, rubis et noire",
                        roches=(9, 8, 7, 6, 5, 4, 3, 2), roche_taille=(0.24, 0.34),
                        roche_mats=("blende_noire", "blende_miel", "blende_rubis", "blende_miel", "blende_ambre",
                                    "blende_noire"))
DIRECTIONS["S4"] = dict(_S_BASE, nom="druses de tétraèdres de blende sur matrice sombre",
                        roches=(3, 3, 2, 2, 2, 1, 1, 1), roche_taille=(0.14, 0.22),
                        roche_mats=("blende_noire", "blende_noire", "blende_rubis"),
                        tetras=(7, 6, 5, 4, 4, 3, 2, 1), tetra_n=(2, 4), tetra_taille=(0.20, 0.30),
                        tetra_mats=("blende_miel", "blende_ambre", "blende_rubis", "blende_noire", "blende_miel"))
DIRECTIONS["S5"] = dict(_S_BASE, nom="morceaux clivés noirs et rubis hérissés de tétraèdres miel",
                        roches=(6, 5, 5, 4, 3, 3, 2, 1), roche_taille=(0.24, 0.32),
                        roche_mats=("blende_noire", "blende_rubis", "blende_noire", "blende_miel"),
                        tetras=(4, 4, 3, 3, 2, 2, 1, 1), tetra_n=(1, 3), tetra_taille=(0.18, 0.26),
                        tetra_mats=("blende_miel", "blende_ambre", "blende_miel", "blende_rubis"))
for _k in ("S3", "S4", "S5"):
    CALIB[_k] = {"SKY_GLOSSY_FACTOR": 2.0}
    ROCHE_COUPES[_k] = 9            # clivage : beaucoup de plans de cassure, faces planes
    ROCHE_LISSE[_k] = 10            # arêtes vives (lissé 10° seulement)
    ROCHE_APLAT[_k] = 0.62
    ROCHE_CASSURE[_k] = (0.30, 0.62)
    EFFET[_k] = dict(EFFET["S2"])
    ECHELLE[_k] = 1.0
    GRAINE[_k] = 6818

# Ronde 2 (DESIGN-BLENDE, 30/10, 9 h 25 ; planche variantes/planche-variantes.png à 16 échantillons) : S3 sort en FLOCONS
# couchés (les coupes profondes aplatissent les morceaux) : écartée. S4 (tétraèdres) a la meilleure silhouette, mais son
# miel sort KAKI et mat (même teinte que la terre dirt-4 : invisible sur le sol de la garantie), ses galets rubis de
# matrice restent des pastilles plates, et sa couverture est à 0,24 au stade 1 (vanilla 0,316). S6 : druses de S4 en noir
# résineux majoritaire (contraste sur la terre et l'herbe), ambre et rubis VIFS et brillants (l'éclat résineux), matrice
# noire TRAPUE (aplat 0,85, cassures moins profondes), tapis de poussière dense comme la vanilla ; comptes recalés au
# rapport vanilla / mesuré de S4 (× 1,3 ; stades 4 et 5 corrigés à part). S7 : la même forme, ambre majoritaire.
MAT.update({
    "blende_ambre_vif": dict(color=(0.80, 0.42, 0.05), rough=0.12, met=0.05, grain=0.15, gscale=45.0, dirt=0.3),
    "blende_rubis_vif": dict(color=(0.42, 0.040, 0.015), rough=0.12, met=0.05, grain=0.15, gscale=45.0, dirt=0.3),
})
DIRECTIONS["S6"] = dict(DIRECTIONS["S4"], nom="druses de tétraèdres de blende noire résineuse, ambre et rubis",
                        roches=(3, 3, 2, 2, 2, 1, 1, 1), roche_taille=(0.13, 0.20), roche_mats=("blende_noire",),
                        tetras=(7, 6, 5, 4.5, 3.4, 3, 2, 1), tetra_n=(2, 4), tetra_taille=(0.20, 0.30),
                        tetra_mats=("blende_noire", "blende_noire", "blende_rubis_vif", "blende_ambre_vif",
                                    "blende_noire", "blende_ambre_vif", "blende_rubis_vif"),
                        grain_mats=("blende_ambre_vif", "blende_noire", "blende_rubis_vif", "blende_noire"),
                        fins=(180, 155, 130, 110, 90, 70, 45, 25),
                        fin_mats=("poussiere_miel", "blende_noire", "poussiere_miel", "blende_rubis_vif", "blende_noire"))
DIRECTIONS["S7"] = dict(DIRECTIONS["S6"], nom="druses de tétraèdres de blende ambre, rubis et noire",
                        tetra_mats=("blende_ambre_vif", "blende_ambre_vif", "blende_rubis_vif", "blende_noire",
                                    "blende_ambre_vif"))
for _k in ("S6", "S7"):
    CALIB[_k] = {"SKY_GLOSSY_FACTOR": 3.0}
    ROCHE_COUPES[_k] = 6
    ROCHE_LISSE[_k] = 25
    ROCHE_APLAT[_k] = 0.85
    ROCHE_CASSURE[_k] = (0.50, 0.80)
    EFFET[_k] = dict(EFFET["S2"])
    ECHELLE[_k] = 1.3
    GRAINE[_k] = 6818
ICONE["S6"] = dict(lames=(0, 0), roches=(1, 2), roche_taille=(0.16, 0.22), roche_coupes=6, roche_cassure=(0.5, 0.8),
                   roche_aplat=0.85, roche_mats=("blende_noire",),
                   tetras=4, tetra_taille=(0.40, 0.50), tetra_mats=("blende_ambre_vif", "blende_noire", "blende_rubis_vif",
                                                                   "blende_ambre_vif"))
ICONE["S7"] = dict(ICONE["S6"])

# Ronde 3 (9 h 35, planche variantes/planche-S6-S7.png) : S6 et S7 ont la bonne silhouette mais se lisent en CONFETTIS
# tricolores (pièces noires, rouges et jaune moutarde séparées : un minerai vanilla est UNE matière qui varie en valeur),
# le jaune sort moutarde mat, et les faces plates sans reflet franc font « low poly » à côté du cuivre. S8 : une seule
# famille de teinte, brun-rouge résineux sombre → rubis → ambre rouge (le « miel à rubis » d'X3 sans la moutarde), matière
# plus lisse et reflets du ciel plus forts (éclat résineux net sur les facettes), tailles et troncatures plus variées.
MAT.update({
    "blende_brune": dict(color=(0.085, 0.026, 0.010), rough=0.09, met=0.05, grain=0.22, gscale=45.0, dirt=0.3),
    "blende_rubis_r": dict(color=(0.34, 0.050, 0.016), rough=0.08, met=0.05, grain=0.22, gscale=45.0, dirt=0.3),
    "blende_ambre_r": dict(color=(0.58, 0.22, 0.035), rough=0.08, met=0.05, grain=0.22, gscale=45.0, dirt=0.3),
})
DIRECTIONS["S8"] = dict(DIRECTIONS["S6"], nom="druses de tétraèdres de blende résineuse brun-rouge, rubis et ambre",
                        roche_mats=("blende_noire",),
                        tetras=(7.8, 6, 5, 4.5, 3.1, 2.85, 1.8, 1), tetra_taille=(0.17, 0.32), tetra_tronc=(0.10, 0.34),
                        tetra_mats=("blende_brune", "blende_brune", "blende_rubis_r", "blende_noire", "blende_rubis_r",
                                    "blende_brune", "blende_ambre_r"),
                        grain_mats=("blende_rubis_r", "blende_noire", "blende_ambre_r", "blende_brune"),
                        fin_mats=("poussiere_miel", "blende_brune", "poussiere_miel", "blende_rubis_r", "blende_noire"))
CALIB["S8"] = {"SKY_GLOSSY_FACTOR": 5.0}
ROCHE_COUPES["S8"], ROCHE_LISSE["S8"] = ROCHE_COUPES["S6"], ROCHE_LISSE["S6"]
ROCHE_APLAT["S8"], ROCHE_CASSURE["S8"] = ROCHE_APLAT["S6"], ROCHE_CASSURE["S6"]
EFFET["S8"] = dict(EFFET["S2"])
ECHELLE["S8"] = 1.3
GRAINE["S8"] = 6818
ICONE["S8"] = dict(ICONE["S6"], tetra_mats=("blende_rubis_r", "blende_brune", "blende_ambre_r", "blende_rubis_r"))
# Icône de S8 (après la production à 128 échantillons, icones.png) : un seul grand tétraèdre au centre se lisait « toit de
# tente ». Comme les icônes vanilla (3 ou 4 morceaux qui remplissent le cadre) : 5 tétraèdres moyens et un éclat noir.
ICONE["S8"] = dict(ICONE["S8"], roches=(1, 1), tetras=5, tetra_taille=(0.27, 0.34), tetra_tronc=(0.12, 0.28))

# Critique DA (30/10, 10 h 20, CRITIQUE.md de la page blende) : S8 a la bonne teinte et se distingue des autres minerais,
# mais (1) ses tétraèdres PARFAITS (faces planes, arêtes droites) se lisent « pyramides en papier / low poly » à côté des
# morceaux bosselés de la vanilla ; (2) sa matrice noire (aplat 0,85, cassures douces) sort en GOUTTES rondes et plates
# (« pastilles de chocolat ») ; (3) des points blancs isolés (reflet du soleil sur des matières très lisses) font du
# bruit. S9 : la forme de S8 (druses de tétraèdres tronqués) avec des sommets BRUITÉS (faces gauchies, cristal naturel),
# plus enfouis et plus serrés (druse intercroissante, moins de « tentes » isolées), matrice en morceaux anguleux clivés,
# matières sombres moins lisses (éclat résineux étalé, pas de point blanc). Icône : 2 ou 3 gros morceaux anguleux brun-rouge
# d'où sortent 3 cristaux, qui remplissent le cadre comme icons/iron-ore.png.
MAT.update({
    "blende_brune_s": dict(color=(0.085, 0.026, 0.010), rough=0.17, met=0.05, grain=0.30, gscale=45.0, dirt=0.35),
    "blende_noire_s": dict(color=(0.040, 0.018, 0.009), rough=0.22, met=0.08, grain=0.30, gscale=45.0, dirt=0.35),
})
DIRECTIONS["S9"] = dict(DIRECTIONS["S8"], nom="druses de cristaux de blende résineuse brun-rouge, faces gauchies, sur matrice clivée",
                        roche_taille=(0.15, 0.22), roche_mats=("blende_noire_s", "blende_brune_s", "blende_noire_s"),
                        tetra_n=(2, 4), tetra_bruit=0.16, tetra_enfoui=(0.22, 0.45), tetra_ecart=(0.06, 0.11),
                        tetra_mats=("blende_brune_s", "blende_brune_s", "blende_rubis_r", "blende_noire_s", "blende_rubis_r",
                                    "blende_brune_s", "blende_ambre_r"),
                        grain_mats=("blende_rubis_r", "blende_noire_s", "blende_ambre_r", "blende_brune_s"),
                        fin_mats=("poussiere_miel", "blende_brune_s", "poussiere_miel", "blende_rubis_r", "blende_noire_s"))
CALIB["S9"] = {"SKY_GLOSSY_FACTOR": 4.0}
ROCHE_COUPES["S9"], ROCHE_LISSE["S9"] = 7, 18
ROCHE_APLAT["S9"], ROCHE_CASSURE["S9"] = 0.78, (0.45, 0.75)
EFFET["S9"] = dict(EFFET["S2"])
ECHELLE["S9"] = 1.3
GRAINE["S9"] = 6818
ICONE["S9"] = dict(lames=(0, 0), roches=(2, 3), roche_taille=(0.24, 0.30), roche_coupes=8, roche_cassure=(0.45, 0.75),
                   roche_aplat=0.80, roche_mats=("blende_rubis_r", "blende_brune_s", "blende_rubis_r"),
                   tetras=3, tetra_taille=(0.26, 0.32), tetra_tronc=(0.12, 0.28), tetra_bruit=0.12,
                   tetra_enfoui=(0.25, 0.40), tetra_mats=("blende_ambre_r", "blende_rubis_r", "blende_brune_s"))

# ILMÉNITE, REFONTE DE LA FORME (lot MINERAI-ILMENITE, 30/10). Retour du DC (30/10, 9 h) : « je n'aime pas du tout la
# forme de ces minerais : Blende, Cassitérite, Minerai d'ilménite, Minerai de monazite. Il faut les refaire. »
# Pourquoi I2S déplaît (comparée aux hr-*.png vanilla, zoom 2) : (1) des GALETS plats et lisses (aplat 0,6, lissé 28°),
# sans relief ni ombre, et des plaquettes carrées posées à plat : on lit des dalles ou du gravier, pas un minerai ;
# (2) un DAMIER de deux couleurs (croûte crème contre noyau brun) qui se lit « pierre + charbon mêlés » ; (3) des pièces
# semées UNE PAR UNE à écart fixe dans un disque (pois réguliers), quand la vanilla les groupe en TAS qui se touchent ;
# (4) un tapis de grains épars (points) au lieu du halo de poussière colorée qui tache le sol sous chaque minerai vanilla ;
# (5) au zoom 1, sur le régolithe gris clair des cratères, la croûte crème disparaît et il reste des taches sombres.
# Langage vanilla visé : morceaux anguleux à facettes vives et à relief (ombre portée), en tas de 2 à 4, une couleur
# dominante (ilménite brun-noir à reflets bronze, la teinte « I2 sombre » choisie par le DC le 25/10), halo de poussière
# brun-rouille. Trois formes (essais à bas échantillonnage) :
#   J1 : AMAS de blocs anguleux (le langage du fer et du cuivre vanilla, en brun-noir bronze) ;
#   J2 : ROSES d'ilménite (rosettes de tablettes hexagonales minces en éventail, forme réelle du minéral) ;
#   J3 : amas de J1 d'où sortent 1 ou 2 TABLETTES (blocs + cristaux tabulaires).
# ------------------------------------------------------------------------------------------------
MAT.update({
    # ilménite de la refonte : brun-noir à éclat submétallique, entre ilmenite_brun et ilmenite_bronze (une seule
    # couleur dominante, les reflets font le reste)
    "ilmenite_j": dict(color=(0.13, 0.095, 0.075), rough=0.30, met=0.60, grain=0.22, gscale=45.0, dirt=0.45),
    # poussière d'altération brun-rouille (le halo coloré sous le gisement, comme la poussière rouge du fer vanilla)
    "poussiere_ilm": dict(color=(0.22, 0.13, 0.075), rough=0.95, met=0.0, grain=0.3, gscale=30.0, dirt=0.2),
})
_J_FINS = (300, 260, 225, 190, 155, 120, 85, 50)
_J_FIN_MATS = ("poussiere_ilm", "poussiere_ilm", "leucoxene_sombre", "ilmenite_brun", "poussiere_ilm", "regolithe")
DIRECTIONS["J1"] = dict(
    nom="amas de blocs anguleux d'ilménite brun-noir à reflets bronze",
    touffes=(0, 0, 0, 0, 0, 0, 0, 0), lames=(0, 0),
    lame_long=(0.0, 0.0), lame_larg=(0.0, 0.0), lame_ep=(0.0, 0.0), lame_incl=(0, 0), lame_mats=("ilmenite_j",),
    roches=(15, 13, 11, 9, 7, 6, 4, 2), roche_taille=(0.13, 0.20),
    roche_mats=("ilmenite_j", "ilmenite_j", "ilmenite_j", "ilmenite_brun", "ilmenite_bronze", "ilmenite_j"),
    amas_roches=dict(taille=(2, 4), rayon=0.13, ecart=0.34, incl=(0, 28), tete=1.25),
    blocs=(0, 0, 0, 0, 0, 0, 0, 0), bloc_taille=(0.1, 0.1), bloc_haut=(0.1, 0.1), bloc_mats=("ilmenite_j",),
    grains=(18, 16, 14, 12, 10, 8, 6, 4), grain_mats=("ilmenite_j", "ilmenite_bronze", "leucoxene_sombre"),
    fins=_J_FINS, fin_mats=_J_FIN_MATS,
    rayon=0.60,
    effet="eclats",
)
DIRECTIONS["J2"] = dict(
    nom="roses d'ilménite : rosettes de tablettes brun-noir à reflets bronze",
    touffes=(6, 5, 5, 4, 3, 3, 2, 1), lames=(5, 8),
    lame_long=(0.11, 0.17), lame_larg=(0.17, 0.25), lame_ep=(0.025, 0.040), lame_incl=(30, 65),
    lame_mats=("ilmenite_j", "ilmenite_j", "ilmenite_bronze", "ilmenite_brun"),
    roches=(3, 3, 3, 2, 2, 1, 1, 1), roche_taille=(0.10, 0.15), roche_mats=("ilmenite_brun", "ilmenite_j"),
    blocs=(0, 0, 0, 0, 0, 0, 0, 0), bloc_taille=(0.1, 0.1), bloc_haut=(0.1, 0.1), bloc_mats=("ilmenite_j",),
    grains=(18, 16, 14, 12, 10, 8, 6, 4), grain_mats=("ilmenite_j", "ilmenite_bronze", "leucoxene_sombre"),
    fins=_J_FINS, fin_mats=_J_FIN_MATS,
    rayon=0.60,
    effet="eclats",
)
DIRECTIONS["J3"] = dict(DIRECTIONS["J1"], nom="amas de blocs d'ilménite hérissés de tablettes",
                        roches=(12, 10, 9, 7, 6, 5, 3, 2),
                        amas_roches=dict(taille=(2, 3), rayon=0.12, ecart=0.36, incl=(0, 25), tete=1.2, lames=(1, 2)),
                        lame_long=(0.12, 0.18), lame_larg=(0.15, 0.22), lame_ep=(0.028, 0.042), lame_incl=(15, 50),
                        lame_mats=("ilmenite_j", "ilmenite_bronze", "ilmenite_j"))
for _k in ("J1", "J2", "J3"):
    CALIB[_k] = {"SKY_GLOSSY_FACTOR": 3.0}
    ROCHE_COUPES[_k], ROCHE_LISSE[_k], ROCHE_APLAT[_k], ROCHE_CASSURE[_k] = 8, 20, 0.80, (0.30, 0.62)
    EFFET[_k] = dict(EFFET["I2S"])
    ECHELLE[_k] = 1.0
    GRAINE[_k] = 6818
GRAINE["J2"] = 6919
ROCHE_APLAT["J2"] = 0.65
ICONE["J1"] = dict(lames=(0, 0), roches=(4, 5), roche_taille=(0.20, 0.27), roche_coupes=8, roche_cassure=(0.30, 0.62),
                   roche_aplat=0.85, roche_mats=("ilmenite_j", "ilmenite_j", "ilmenite_bronze", "ilmenite_brun"), blocs=0)
ICONE["J2"] = dict(lames=(6, 8), echelle=1.7, roches=(2, 2), roche_taille=(0.14, 0.18), roche_coupes=8,
                   roche_cassure=(0.30, 0.62), roche_aplat=0.7, roche_mats=("ilmenite_brun",),
                   lame_mats=("ilmenite_j", "ilmenite_bronze", "ilmenite_j"), blocs=0)
ICONE["J3"] = dict(lames=(2, 3), echelle=1.5, roches=(3, 4), roche_taille=(0.20, 0.26), roche_coupes=8,
                   roche_cassure=(0.30, 0.62), roche_aplat=0.85, roche_mats=("ilmenite_j", "ilmenite_j", "ilmenite_bronze"),
                   lame_mats=("ilmenite_j", "ilmenite_bronze"), blocs=0)

# Ronde 2 (essais à 16 échantillons, planche fo-logs/2026-10-30_RETOUR-MATIN/MINERAIS/ilmenite/essais, zoom 3 contre le fer
# vanilla) : J1 et J3 sortent en ÉCLATS PLATS (8 coupes profondes), trop petits (couverture 0,16 contre 0,32), et le tapis de
# fins se lit en couronne de GRAVIER rond (grains de 2 à 3 px ombrés, semés dans tout le disque) au lieu de la poussière
# de 1 px serrée SOUS les morceaux du fer vanilla ; J2 (rosettes) se lit en papier froissé : écartée. Ronde 2 : morceaux
# bosselés plus gros (bosses ±12 %, 5 coupes moins profondes), poussière fine concentrée autour des morceaux
# (gisement.cellule : fins_autour, fin_taille), reflets bronze plus francs.
MAT["ilmenite_k"] = dict(color=(0.15, 0.11, 0.085), rough=0.26, met=0.62, grain=0.22, gscale=45.0, dirt=0.45)
ROCHE_BOSSE = {}
_K_ROCHE_MATS = ("ilmenite_k", "ilmenite_k", "ilmenite_k", "ilmenite_brun", "ilmenite_bronze", "ilmenite_k")
DIRECTIONS["J4"] = dict(DIRECTIONS["J1"], nom="amas de morceaux bosselés d'ilménite brun-noir à reflets bronze",
                        roches=(17, 15, 12, 10, 8, 7, 4, 2), roche_taille=(0.17, 0.25), roche_mats=_K_ROCHE_MATS,
                        amas_roches=dict(taille=(2, 4), rayon=0.16, ecart=0.38, incl=(0, 25), tete=1.2),
                        grains=(10, 9, 8, 7, 6, 5, 4, 3), grain_mats=("ilmenite_k", "ilmenite_bronze", "leucoxene_sombre"),
                        fins=(700, 600, 520, 440, 360, 280, 200, 120), fin_taille=(0.007, 0.012), fins_autour=(0.75, 1.3),
                        fin_mats=("poussiere_ilm", "poussiere_ilm", "leucoxene_sombre", "ilmenite_brun", "poussiere_ilm",
                                  "regolithe"))
DIRECTIONS["J5"] = dict(DIRECTIONS["J4"], nom="amas de morceaux d'ilménite hérissés de tablettes",
                        roches=(15, 13, 11, 9, 7, 6, 4, 2),
                        amas_roches=dict(taille=(2, 3), rayon=0.16, ecart=0.38, incl=(0, 25), tete=1.2, lames=(1, 2)),
                        lame_long=(0.13, 0.19), lame_larg=(0.16, 0.22), lame_ep=(0.030, 0.045), lame_incl=(20, 50),
                        lame_mats=("ilmenite_k", "ilmenite_bronze", "ilmenite_k"))
DIRECTIONS["J6"] = dict(DIRECTIONS["J5"], nom="tas de tablettes épaisses d'ilménite sur morceaux",
                        roches=(11, 10, 8, 7, 6, 4, 3, 2),
                        amas_roches=dict(taille=(1, 2), rayon=0.14, ecart=0.38, incl=(0, 20), tete=1.1, lames=(2, 3)),
                        lame_long=(0.14, 0.20), lame_larg=(0.17, 0.24), lame_ep=(0.050, 0.070), lame_incl=(35, 70))
for _k in ("J4", "J5", "J6"):
    CALIB[_k] = {"SKY_GLOSSY_FACTOR": 5.0}
    ROCHE_COUPES[_k], ROCHE_LISSE[_k], ROCHE_APLAT[_k], ROCHE_CASSURE[_k] = 5, 34, 0.90, (0.50, 0.82)
    ROCHE_BOSSE[_k] = (0.86, 1.12)
    EFFET[_k] = dict(EFFET["I2S"])
    ECHELLE[_k] = 1.0
    GRAINE[_k] = 6818
ICONE["J4"] = dict(ICONE["J1"], roche_coupes=5, roche_cassure=(0.50, 0.82), roche_aplat=0.9,
                   roche_mats=("ilmenite_k", "ilmenite_k", "ilmenite_bronze", "ilmenite_brun"))
ICONE["J5"] = dict(ICONE["J3"], roche_coupes=5, roche_cassure=(0.50, 0.82), roche_aplat=0.9,
                   roche_mats=("ilmenite_k", "ilmenite_k", "ilmenite_bronze"), lame_mats=("ilmenite_k", "ilmenite_bronze"))
ICONE["J6"] = dict(ICONE["J5"], lames=(3, 4), roches=(2, 3))

# Ronde 3 (J4 à J6 au zoom 3 contre le fer : relief et reflets bronze justes, ni le bleu du fer ni le noir mat du charbon)
# : morceaux encore trop RONDS (galettes lisses ; les morceaux vanilla ont plusieurs bosses), poussière clairsemée,
# couverture à 75 % de la vanilla. J7 = J4 à morceaux COMPOSÉS (une tête et 1 ou 2 bosses soudées : amas serré), une
# tablette d'accent dans un tas sur deux (l'habitus tabulaire de l'ilménite, de J5), poussière plus dense et plus serrée,
# comptes recalés au rapport vanilla / mesuré de J4.
DIRECTIONS["J7"] = dict(DIRECTIONS["J4"], nom="morceaux bosselés d'ilménite brun-noir à reflets bronze, tablettes d'accent",
                        roches=(24, 20, 17, 14, 11, 9, 6, 3),
                        amas_roches=dict(taille=(2, 3), rayon=0.11, ecart=0.28, incl=(0, 25), tete=1.15, lames=(0, 1)),
                        lame_long=(0.12, 0.17), lame_larg=(0.14, 0.20), lame_ep=(0.035, 0.050), lame_incl=(25, 55),
                        lame_mats=("ilmenite_k", "ilmenite_bronze", "ilmenite_k"),
                        fins=(1000, 860, 740, 620, 500, 400, 280, 170), fin_taille=(0.010, 0.016), fins_autour=(0.85, 1.0),
                        rayon=0.62)
CALIB["J7"] = dict(CALIB["J4"])
ROCHE_COUPES["J7"], ROCHE_LISSE["J7"], ROCHE_APLAT["J7"], ROCHE_CASSURE["J7"] = 6, 30, 0.90, (0.45, 0.80)
ROCHE_BOSSE["J7"] = (0.84, 1.14)
EFFET["J7"] = dict(EFFET["I2S"])
ECHELLE["J7"], GRAINE["J7"] = 1.0, 6818
ICONE["J7"] = dict(ICONE["J4"], lames=(1, 2), echelle=1.4, lame_mats=("ilmenite_k", "ilmenite_bronze"))
# J7, nuit (captures en moteur de x1-titane, tools/autotest/x1_lisibilite.py, 30/10) : avec la couche d'effet de I2S, J7
# passe 4 critères sur 9 (I2S : 8 sur 9) ; de nuit, ses morceaux sombres allument moins (alpha moyen de l'effet sur le
# minerai livré 0,47 contre 0,62 pour I2S). Réglage recalé pour la MÊME énergie que I2S (environ 0,60), pas plus : le DC a
# demandé le 25/10 une nuit assombrie (D-17).
EFFET["J7"] = dict(teinte=(0.85, 0.93, 1.0), seuil=(0.18, 0.40),
                   lueur=dict(lum=(0.02, 0.10), froid=(-1.0, -0.95), gain=0.7))
