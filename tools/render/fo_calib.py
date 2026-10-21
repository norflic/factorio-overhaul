"""Constantes d'étalonnage du pipeline de rendu (lot V0, hypothèse H-V1).

Python PUR (aucune dépendance) : importé à la fois par Blender (scène) et par le Python système
(post-traitement, mesures). Chaque valeur est justifiée par une mesure sur les sprites vanilla de
Factorio 1.1.91 : voir tools/render/CALIBRATION.md (section indiquée en commentaire).
"""
import math

BLENDER_VERSION = "5.2.2 LTS"          # seule version validée (sommes SHA-256 dans README.md)

# --- Projection (CALIBRATION §2) ---------------------------------------------------------------
# Caméra orthographique inclinée de THETA depuis la verticale, regardant le nord.
# Écran : u = X, v (vers le bas) = -(Y·cos θ + Z·sin θ), en unités Blender × PX_PER_UNIT_HR.
THETA_DEG = 45.0
PX_PER_UNIT_HR = 64.0                   # 1 unité Blender en X = 1 tuile = 64 px HR (32 px au zoom 1)
COS_T = math.cos(math.radians(THETA_DEG))
SIN_T = math.sin(math.radians(THETA_DEG))
# Une tuile de jeu vers le sud = 64 px à l'écran = 1/cos θ unité Blender en Y (la grille de sol est
# étirée en profondeur pour que les tuiles restent carrées à l'écran, comme les tuyaux vanilla).
TILE_DEPTH_UNITS = 1.0 / COS_T


def tile_to_blender(tx, ty, z=0.0):
    """Coordonnées de jeu (tuiles, y vers le sud, origine = position de l'entité) -> Blender."""
    return (tx, -ty * TILE_DEPTH_UNITS, z)


def blender_to_screen_px(x, y, z):
    """Projection d'un point Blender en pixels HR relatifs à la position de l'entité (u droite, v bas)."""
    return (x * PX_PER_UNIT_HR, -(y * COS_T + z * SIN_T) * PX_PER_UNIT_HR)


# --- Lumière (CALIBRATION §3) ------------------------------------------------------------------
# Soleil à l'ouest (ombres plein est à l'écran), élévation mesurée sur les ombres des poteaux et
# des coffres ; angle apparent nul (ombres vanilla nettes : rampe d'anticrénelage de 1 à 2 px).
SUN_ELEV_DEG = 48.0
SUN_AZIMUTH_DEG = 270.0                 # 0 = nord, 90 = est, 180 = sud, 270 = ouest (d'où VIENT la lumière)
SUN_ANGLE_DEG = 0.0
SUN_STRENGTH = 1.9                      # W/m² Cycles ; avec FILL, SKY et GROUND : rapport façade/dessus des coffres (§3.3)
SKY_STRENGTH = 0.08                     # ciel uniforme faible : façades sud sombres comme en vanilla (§3.3)
SKY_COLOR = (0.80, 0.86, 1.00)          # léger bleu du ciel, réchauffé par le soleil
SUN_COLOR = (1.00, 0.95, 0.86)
FILL_STRENGTH = 1.5                     # appoint zénithal SANS ombre : profils des tuyaux vanilla (§3.4)
FILL_ELEV_DEG = 90.0
FILL_AZIMUTH_DEG = 180.0

# --- Ombres (CALIBRATION §4) ------------------------------------------------------------------
# Moteur (data/core/graphics/shaders/shadow-a8.frag) : alpha affiché = alpha du sprite × 0,5.
# Les sprites d'ombre vanilla sont noirs, alpha 1 au cœur ; on produit la même chose.
ENGINE_SHADOW_FACTOR = 0.5

# --- Rendu ------------------------------------------------------------------------------------
SAMPLES = 256
SEED = 20261021
MAX_BOUNCES = 6
FILTER_WIDTH_PX = 1.5
AO_DISTANCE = 0.38                      # portée de l'occlusion de contact (unités), réglée sur le liseré vanilla (§4.2)
AO_STRENGTH = 5.5                       # alpha du liseré = min(1, AO_STRENGTH × occlusion^AO_GAMMA) (§4.2)
AO_GAMMA = 2.0
AO_COLOR = (0.035, 0.030, 0.025)        # couleur droite du liseré (vanilla : luminance 0,03 à 0,16)
STEEL_BASE = (0.45, 0.43, 0.40)         # acier de référence (couleur linéaire), réglé sur hr-pipe-* (§3.4)
STEEL_METALLIC = 0.6
STEEL_ROUGH = 0.5
LIGHT_EMIT_GAIN = 2.0                   # passe halo : surfaces émissives × gain (cœur du halo autour de la source)
CHEMINEE_HALO_W = 40.0                  # puissance (W) de la source de halo de la cheminée (essais)
LIGHT_RADIUS_TILES = (1.2, 2.2)         # halo borné : plein jusqu'à 1,2 tuile du pied, nul à 2,2 (vanilla : flaques compactes)
LIGHT_MAX = 0.80                       # halo normalisé : maximum AU SOL (vanilla : 0,79, sol du four en acier)
GROUND_ALBEDO = 0.15                    # sol neutre : lumière rebondie sur les façades (§3.3)


def recompute():
    """Recalcule les constantes dérivées après une surcharge (--set THETA_DEG=...)."""
    global COS_T, SIN_T, TILE_DEPTH_UNITS
    COS_T = math.cos(math.radians(THETA_DEG))
    SIN_T = math.sin(math.radians(THETA_DEG))
    TILE_DEPTH_UNITS = 1.0 / COS_T


def sun_vector():
    """Vecteur unitaire du sol vers le soleil (repère Blender)."""
    e = math.radians(SUN_ELEV_DEG)
    a = math.radians(SUN_AZIMUTH_DEG)
    # azimut 0 = nord (+Y), 90 = est (+X)
    return (math.cos(e) * math.sin(a), math.cos(e) * math.cos(a), math.sin(e))
