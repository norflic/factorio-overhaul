"""Formes simples d'étalonnage (CALIBRATION.md) : chacune reproduit une géométrie MESURÉE sur un
sprite vanilla, pour comparer le rendu au sprite à l'échelle du pixel.

Variantes :
  plate  : plaque d'une tuile au sol (vérifie 64 px × 64 px et l'ancrage) ;
  chest  : boîte aux proportions du coffre en bois vanilla (dessus 37 px, façade 31 px, 60 px de large,
           bord avant à +30,5 px) ;
  pipes  : tuyau nord-sud et tuyau est-ouest de rayon 0,305 (39 px de diamètre, comme hr-pipe-*) ;
  pole   : poteau vertical de 3 unités de haut (ombre, élévation du soleil) ;
  stack  : cheminée verticale (ellipse du sommet, rapport cos θ) et disque face caméra (sin θ) ;
  dome   : demi-sphère (contour circulaire en projection orthographique).
"""
import math

PIECE = {"name": "calib"}


def build(S, C, variant):
    grey = S.mat_flat("grey50", (0.214, 0.214, 0.214), rough=0.6)   # 0,5 en sRGB
    metal = S.mat_metal("metal", C.STEEL_BASE, rough=C.STEEL_ROUGH, metallic=C.STEEL_METALLIC, grain=0.0)
    if variant == "plate":
        d = C.TILE_DEPTH_UNITS
        S.box((1.0, d, 0.02), (0, 0, 0.01), grey, "plate", bevel_w=0)
    elif variant == "chest":
        W = 60 / 64.0
        D = 37 / (64.0 * C.COS_T)
        H = 31 / (64.0 * C.SIN_T)
        y_front = -30.5 / (64.0 * C.COS_T)
        S.box((W, D, H), (0.0, y_front + D / 2, H / 2), grey, "chest", bevel_w=0.01)
    elif variant == "pipes":
        r = 19.5 / 64.0
        L = 2.0 * C.TILE_DEPTH_UNITS
        # nord-sud, centré en x = -1,5 tuile ; est-ouest centré en x = +1,5 tuile ; axes à z = r
        S.cylinder(r, L, (-1.5, 0.0, r), metal, "pipe_ns", rot=(math.pi / 2, 0, 0), bevel_w=0)
        S.cylinder(r, 2.0, (1.5, 0.0, r), metal, "pipe_ew", rot=(0, math.pi / 2, 0), bevel_w=0)
    elif variant == "pole":
        S.cylinder(0.05, 3.0, (0.0, 0.0, 1.5), grey, "pole", bevel_w=0)
    elif variant == "stack":
        S.cylinder(0.25, 1.0, (-0.6, 0.0, 0.5), grey, "stack", bevel_w=0)
        S.cylinder(0.4, 0.05, (0.6, 0.0, 0.45), grey, "disc", rot=(math.pi / 2, 0, 0), bevel_w=0)
    elif variant == "dome":
        S.sphere(1.0, (0.0, 0.0, 0.0), grey, "dome", seg=96, rings=48)
    else:
        raise ValueError("variante inconnue : " + variant)
