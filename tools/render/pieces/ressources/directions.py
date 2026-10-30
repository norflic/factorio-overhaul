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

# Échelle des comptes (réglée par mesure de la couverture, feuille.py --couverture) : multiplie touffes, roches,
# blocs et grains d'une direction. 1,0 tant que rien n'est mesuré.
ECHELLE = {"A": 1.0, "B": 1.0, "C": 1.0, "A2": 1.0, "A3": 1.0, "A4": 1.0, "I1": 1.45, "I2": 1.45, "I3": 1.45,
           "Z1": 1.6, "Z2": 1.6, "Z3": 1.6, "G1": 1.45, "K1": 1.3, "I2S": 1.45, "C1": 1.6, "B1": 1.6, "S1": 1.45}

# Graine de chaque direction (hasard local déterministe). A2 à A4 gardent la graine de A : mêmes positions.
GRAINE = {"A": 5101, "B": 5202, "C": 5303, "A2": 5101, "A3": 5101, "A4": 5101, "I1": 6111, "I2": 6111, "I3": 6111,
          "Z1": 6212, "Z2": 6212, "Z3": 6212, "G1": 6313, "K1": 6414, "I2S": 6111, "C1": 6515, "B1": 6616, "S1": 6717}

# Grille de rendu : 8 variantes (colonnes) × 8 stades (lignes) + une ligne d'icônes (icône + 3 images d'objet).
COLONNES = 8
STADES = 8
PAS = 3          # écart entre deux cellules, en tuiles (aucune ombre d'une cellule ne déborde sur sa voisine)
