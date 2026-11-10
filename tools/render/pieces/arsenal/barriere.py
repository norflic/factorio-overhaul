"""Pièce ASSAUTS-TITANESQUES (10/11) : BORNE DE BARRIÈRE DE PÉRIMÈTRE (entité 1×1, lignée Bastion : acier argent, cyan).

Une borne électrique qui projette un champ entre ses voisines : socle d'acier boulonné, fût à pans, deux anneaux
émetteurs cyan (lueur de jour, halo de nuit), tête à quatre ailettes et sphère d'émission. Mêmes règles que les autres
pièces (CALIBRATION.md §2 : unité = largeur d'une tuile, +Z haut, origine = position de l'entité au sol) ; aucun élément
sous 2 px HR. Le prototype (prototypes/arsenal_ages.lua) pose ce rendu en `base_picture` de la tourelle électrique et
garde une tête vanilla réduite par-dessus (le moteur tourne la tête, pas le socle).
"""
import math

PIECE = {
    "name": "barriere",
    "halo": [{"at": (0.0, 0.0, 0.0), "r": (0.45, 1.25)}],
    "margin_px": 64,
    "epoque": (12,),  # dernier âge de l'ère 4 (âge d'armement de la borne) : médiane 60 ± 10
    "variants": {
        "borne": {"dest": "arsenal/barriere", "anchor_tiles": (0.0, 0.0)},
    },
}

MAT = {
    # acier argent pâle de la lignée Bastion / titans (TM : #9FA8B8), creux sombres
    "steel": dict(color=(0.96, 0.97, 1.00), rough=0.42, metallic=0.85, grain=0.14, grain_scale=60.0,
                  rust=(0.12, 0.13, 0.15), rust_amount=0.04, dirt=0.15, dirt_distance=0.2),
    "dark": dict(color=(0.16, 0.17, 0.20), rough=0.5, metallic=0.8, grain=0.2, grain_scale=40.0, dirt=0.5),
    "plinth": dict(color=(0.55, 0.57, 0.62), rough=0.55, metallic=0.6, grain=0.25, grain_scale=35.0, dirt=0.25),
    "bolt": dict(color=(0.45, 0.47, 0.52), rough=0.5, metallic=0.85, grain=0.1),
}
CYAN = (0.10, 0.90, 1.00)


def build(S, C, variant):
    v = PIECE["variants"][variant]
    tx, ty = v["anchor_tiles"]
    ox, oy, _ = C.tile_to_blender(tx, ty)

    def at(x, y, z):
        return (ox + x, oy + y, z)

    def metal(key, name, seed):
        m = dict(MAT[key])
        col = m.pop("color")
        return S.mat_metal(name, col, seed=seed, **m)

    steel = metal("steel", "barriere_acier", 1.0)
    dark = metal("dark", "barriere_creux", 2.0)
    plinth = metal("plinth", "barriere_socle", 3.0)
    bolt = metal("bolt", "barriere_boulon", 4.0)
    glow = S.mat_emissive("barriere_cyan", CYAN, strength=6.0, main_scale=0.35, base=(0.01, 0.05, 0.06))
    core = S.mat_emissive("barriere_coeur", (0.55, 0.98, 1.0), strength=9.0, main_scale=0.5, base=(0.02, 0.08, 0.09))

    # --- socle boulonné (0,86 tuile, dans l'emprise 1×1) ---
    S.box((0.86, 0.86, 0.12), at(0, 0, 0.06), plinth, "socle", bevel_w=0.02)
    S.box((0.62, 0.62, 0.08), at(0, 0, 0.16), steel, "socle_haut", bevel_w=0.015)
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        S.cylinder(0.035, 0.05, at(sx * 0.34, sy * 0.34, 0.135), bolt, "boulon_%d" % i, verts=12, bevel_w=0.006)

    # --- fût à huit pans, gorge sombre, anneau émetteur bas ---
    S.cylinder(0.20, 0.55, at(0, 0, 0.20 + 0.275), steel, "fut_bas", verts=8, bevel_w=0.012)
    S.cylinder(0.165, 0.08, at(0, 0, 0.52), dark, "gorge_1", verts=32, bevel_w=0)
    S.torus(0.215, 0.028, at(0, 0, 0.52), glow, "anneau_1", minor_seg=10)
    S.cylinder(0.185, 0.50, at(0, 0, 0.56 + 0.25), steel, "fut_haut", verts=8, radius2=0.16, bevel_w=0.010)
    S.cylinder(0.14, 0.08, at(0, 0, 1.03), dark, "gorge_2", verts=32, bevel_w=0)
    S.torus(0.195, 0.028, at(0, 0, 1.03), glow, "anneau_2", minor_seg=10)

    # --- tête : collerette, quatre ailettes, sphère d'émission ---
    S.cylinder(0.20, 0.06, at(0, 0, 1.10), steel, "collerette", verts=32, bevel_w=0.012)
    fins = []
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        f = S.box((0.05, 0.30, 0.34), at(0.17 * math.cos(a), 0.17 * math.sin(a), 1.30), steel, "ailette_%d" % i,
                  bevel_w=0.008)
        f.rotation_euler = (0, 0, a + math.pi / 2)
        fins.append(f)
    S.join(fins, "ailettes")
    S.cylinder(0.075, 0.30, at(0, 0, 1.28), dark, "colonne_tete", verts=16, bevel_w=0)
    S.sphere(0.13, at(0, 0, 1.50), core, "sphere_emission")
    S.torus(0.17, 0.02, at(0, 0, 1.50), glow, "anneau_tete", minor_seg=8)
    # halo de nuit : sources dans la sphère et au ras du sol (lumière portée sans bruit)
    S.halo_light(at(0, 0, 1.50), CYAN, 90.0, radius=0.12, name="halo_tete")
    S.halo_light(at(0, 0, 0.55), CYAN, 60.0, radius=0.15, name="halo_bas")
