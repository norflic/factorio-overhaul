"""Pièce V0 : cheminée rivetée à couronne de braises (lot V0, hypothèse H-V1).

Pourquoi cette pièce (rapport V0) :
- elle sert directement aux familles à niveaux : four (époques 2 « Forge » et 3 « Vapeur » : cheminées,
  plaques boulonnées, cerclages ; OBJECTIFS.md §6), assembleur et centre de commandement ;
- elle DÉPASSE la silhouette du bâtiment qui la porte (fait F42 : un socle sous un sprite plein est
  invisible ; une pièce doit dépasser) ;
- elle porte un élément lumineux (évents et gueule de braises) qui teste la lueur de jour
  (draw_as_glow) et le halo de nuit (draw_as_light) ;
- sa géométrie (cylindres, anneaux, rivets, échelle) exerce tout ce que les autres pièces demanderont.

Variantes :
  seule : cheminée seule, centrée sur sa tuile (entité 1×1 de vitrine) ;
  four  : la même, posée DERRIÈRE le corps d'un four en acier (2×2), dans l'emprise : le post-traitement
          la masque par l'alpha du sprite vanilla du four, elle n'apparaît qu'au-dessus du toit.
Unités : largeur de tuile ; z vers le haut ; position (tx, ty) en tuiles de jeu (y vers le sud).
"""
import math

PIECE = {
    "name": "cheminee",
    # halo (draw_as_light) borné : flaque au sol autour du pied, et cœur autour des évents (z = 2,19)
    "halo": [{"at": (0.0, 0.0, 0.0), "r": (1.1, 2.1)}, {"at": (0.0, 0.0, 2.19), "r": (0.45, 1.0)}],
    "margin_px": 96,          # marge du canevas : le halo au sol s'étend loin de la pièce
    "variants": {
        "seule": {"dest": "vitrine/cheminee", "anchor_tiles": (0.0, 0.0)},
        "four": {
            "dest": "vitrine/cheminee",
            "anchor_tiles": (-0.59, -0.62),
            # masque : sprite principal du four en acier vanilla, aux deux résolutions, avec son shift
            "mask": {
                "hr": {"file": "steel-furnace/hr-steel-furnace.png", "shift": (-0.0390625, 0.0625)},
                "lr": {"file": "steel-furnace/steel-furnace.png", "shift": (-0.046875, 0.046875)},
            },
        },
    },
}

H_TOTAL = 2.36


def build(S, C, variant):
    v = PIECE["variants"][variant]
    tx, ty = v["anchor_tiles"]
    ox, oy, _ = C.tile_to_blender(tx, ty)

    def at(x, y, z):
        return (ox + x, oy + y, z)

    # --- matériaux (valeurs linéaires ; plages vanilla : CALIBRATION.md §5) ---
    # Réglés sur la photométrie vanilla (maquette.py) : luminance moyenne 0,18-0,36, écart-type 0,18-0,24,
    # centile 95 0,66-0,84 (reflets francs sur cerclages et rivets), saturation 0,17-0,40, grain 0,04-0,08.
    shell = S.mat_metal("cheminee_tole", (0.25, 0.215, 0.165), rough=0.40, metallic=0.55, grain=0.30,
                        grain_scale=45.0, rust=(0.26, 0.095, 0.035), rust_amount=0.5, rust_scale=5.0,
                        dirt=0.55, seed=1.0)
    band = S.mat_metal("cheminee_cerclage", (0.66, 0.50, 0.27), rough=0.28, metallic=0.9, grain=0.15,
                       grain_scale=70.0, rust=(0.30, 0.12, 0.05), rust_amount=0.2, dirt=0.35, seed=2.0)
    rivet = S.mat_metal("cheminee_rivet", (0.80, 0.70, 0.52), rough=0.25, metallic=0.9, grain=0.1, seed=3.0)
    plinth = S.mat_metal("cheminee_socle", (0.10, 0.095, 0.085), rough=0.6, metallic=0.5, grain=0.25,
                         grain_scale=35.0, rust=(0.18, 0.075, 0.03), rust_amount=0.3, dirt=0.5, seed=4.0)
    soot = S.mat_flat("cheminee_suie", (0.010, 0.009, 0.008), rough=0.9)
    rail = S.mat_metal("cheminee_echelle", (0.40, 0.37, 0.32), rough=0.35, metallic=0.8, grain=0.1, seed=5.0)
    ember = S.mat_emissive("cheminee_braises", (1.0, 0.30, 0.045), strength=1.25)
    ember_top = S.mat_emissive("cheminee_gueule", (1.0, 0.20, 0.025), strength=0.85)

    # --- socle boulonné ---
    S.box((0.62, 0.62, 0.10), at(0, 0, 0.05), plinth, "socle", bevel_w=0.015)
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        S.cylinder(0.025, 0.035, at(sx * 0.25, sy * 0.25, 0.115), rivet, "boulon_%d" % i, verts=12, bevel_w=0.004)
    S.cylinder(0.30, 0.06, at(0, 0, 0.13), band, "bride_basse", verts=64)
    S.rivet_ring(0.285, 0.165, 16, 0.016, rivet, center=(ox, oy), name="rivets_bride")

    # --- fût inférieur (tôles rivetées, deux cerclages) ---
    S.cylinder(0.24, 1.08, at(0, 0, 0.16 + 0.54), shell, "fut_bas", verts=64)
    for k, z in enumerate((0.22, 0.58, 0.94)):
        S.rivet_ring(0.245, z, 18, 0.014, rivet, center=(ox, oy), name="rivets_bas_%d" % k, phase=0.09 * k)
    S.torus(0.248, 0.018, at(0, 0, 0.40), band, "cerclage_1")
    S.torus(0.248, 0.018, at(0, 0, 0.76), band, "cerclage_2")

    # --- collier et passerelle ---
    S.cylinder(0.285, 0.10, at(0, 0, 1.29), band, "collier", verts=64)
    S.rivet_ring(0.29, 1.29, 20, 0.015, rivet, center=(ox, oy), name="rivets_collier")
    S.cylinder(0.36, 0.025, at(0, 0, 1.235), rail, "passerelle", verts=64, bevel_w=0.004)
    posts = []
    for i in range(10):
        a = 2 * math.pi * i / 10 + 0.15
        posts.append(S.cylinder(0.008, 0.13, at(0.35 * math.cos(a), 0.35 * math.sin(a), 1.31), rail, "poteau_%d" % i,
                                verts=8, bevel_w=0))
    S.join(posts, "garde_corps_poteaux")
    S.torus(0.35, 0.009, at(0, 0, 1.375), rail, "garde_corps", minor_seg=8)

    # --- fût supérieur (légèrement conique) ---
    S.cylinder(0.225, 0.78, at(0, 0, 1.34 + 0.39), shell, "fut_haut", verts=64, radius2=0.205, caps=False)
    for k, z in enumerate((1.45, 1.80)):
        S.rivet_ring(0.222 - 0.025 * k, z, 16, 0.013, rivet, center=(ox, oy), name="rivets_haut_%d" % k)

    # --- couronne : bande d'évents incandescents derrière une grille, lèvre évasée ---
    S.cylinder(0.212, 0.14, at(0, 0, 2.19), ember, "events_braises", verts=64, bevel_w=0, caps=False)
    bars = []
    for i in range(24):
        a = 2 * math.pi * i / 24
        b = S.box((0.022, 0.03, 0.15), at(0.215 * math.cos(a), 0.215 * math.sin(a), 2.19), band, "barreau_%d" % i,
                  bevel_w=0)
        b.rotation_euler = (0, 0, a)
        bars.append(b)
    S.join(bars, "grille_events")
    S.cylinder(0.225, 0.03, at(0, 0, 2.105), band, "bague_basse", verts=64, bevel_w=0, caps=False)
    S.cylinder(0.205, 0.10, at(0, 0, 2.31), shell, "levre", verts=64, radius2=0.27, bevel_w=0, caps=False)
    S.torus(0.268, 0.02, at(0, 0, 2.36), band, "levre_bourrelet")
    # gueule : paroi intérieure couverte de suie, lit de braises au fond (vu en ellipse depuis la caméra)
    S.cylinder(0.198, 0.26, at(0, 0, 2.23), soot, "gueule_suie", verts=64, bevel_w=0, caps=False)
    S.cylinder(0.198, 0.01, at(0, 0, 2.105), ember_top, "gueule_braises", verts=64, bevel_w=0)
    # lumière portée (passe halo seulement) : six sources juste devant la grille d'évents
    for i in range(6):
        a = 2 * math.pi * (i + 0.5) / 6
        S.halo_light(at(0.27 * math.cos(a), 0.27 * math.sin(a), 2.19), (1.0, 0.42, 0.12), C.CHEMINEE_HALO_W / 6,
                     radius=0.05, name="halo_events_%d" % i)

    # --- échelle au sud-ouest (repère d'échelle humaine) ---
    ang = math.radians(235)
    rr = 0.275
    for side in (-1, 1):
        da = side * 0.07
        x = rr * math.cos(ang + da)
        y = rr * math.sin(ang + da)
        S.box((0.012, 0.012, 1.95), at(x, y, 0.2 + 0.975), rail, "echelle_montant_%d" % side, bevel_w=0)
    rungs = []
    for i in range(16):
        z = 0.28 + i * 0.12
        if 1.18 < z < 1.40:
            continue
        x = rr * math.cos(ang)
        y = rr * math.sin(ang)
        r = S.box((0.045, 0.008, 0.008), at(x, y, z), rail, "barreau_echelle_%d" % i, bevel_w=0)
        r.rotation_euler = (0, 0, ang + math.pi / 2)
        rungs.append(r)
    S.join(rungs, "echelle_barreaux")
