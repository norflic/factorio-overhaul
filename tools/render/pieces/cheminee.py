"""Pièce V0 : cheminée rivetée à couronne de braises (lot V0, hypothèse H-V1 ; corrections techniques V0b).

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
  four  : la même, posée DERRIÈRE le corps d'un four en acier (2×2), dans l'emprise. Règle V0b des pièces
          posées sur un bâtiment vanilla (README.md) : couches insérées AVANT celles du four (le jeu dessine
          le four par-dessus) ; passe halo avec un volume de remplacement du four ; pied caché marqué
          (mark_hidden : pas de liseré de contact, pas de « trou » dans le halo, ombre gardée) ; flaque au sol
          hors de la silhouette du four (masque par l'alpha du sprite vanilla).
Unités : largeur de tuile ; z vers le haut ; position (tx, ty) en tuiles de jeu (y vers le sud).

Corrections V0b (rapport <racine>/fo-logs/2026-10-21_V0_verif-captures/rapport.md ; style validé par le
Directeur Créatif le 21/10, inchangé) :
- garde-corps (poteaux de 1 px, tore de 1,2 px) remplacé par un parapet plein : plus aucun jour enfermé ;
- tout élément fait au moins 2 px HR (0,031 unité) : échelle, barreaux, rivets ;
- rivets moins nombreux et plus gros (lecture au zoom 1) ; chanfreins sur brides, collier et lèvre ;
- matériaux moins diffus (rugosités 0,15 à 0,30), grain réduit, creux plus sombres ; sol clair vu par les
  seuls reflets (PIECE["calib"]) : photométrie du corps dans les plages vanilla (CALIBRATION §5) ;
- braises : surface éteinte dans la couche principale, la lueur seule donne la couleur (comme le feu
  vanilla) ; lit de braises remonté (gueule visible sur plus de 8 px) ; 12 barreaux au lieu de 24 ;
- halo : sources orange de la lumière vanilla (1 ; 0,49 ; 0,05), flaque au sol seulement, plus compacte.
"""
import math

HALO_W = 300.0  # puissance totale (W) des 6 sources du halo, réglée sur le pic au sol visé (CALIBRATION §4.2)

PIECE = {
    "name": "cheminee",
    # halo (draw_as_light) : flaque AU SOL autour du pied (plein jusqu'à 0,55 tuile, nul à 1,05 tuile) ; plus
    # de fenêtre « cœur » autour des évents (elle débordait sur le sol vu derrière le sommet)
    "halo": [{"at": (0.0, 0.0, 0.0), "r": (0.55, 1.05)}],
    "margin_px": 96,          # marge du canevas autour de la pièce et de son ombre
    # surcharges d'étalonnage propres à la pièce (fo_calib), pour les seuls rayons spéculaires : sol clair
    # (reflets des faces tournées vers la caméra) et ciel noir (bords rasants sombres), comme les métaux
    # vanilla ; l'éclairage diffus étalonné (CALIBRATION §3) ne change pas. Balayage : CALIBRATION §5.
    "calib": {"GROUND_GLOSSY_ALBEDO": 0.8, "SKY_GLOSSY_FACTOR": 0.0},
    "variants": {
        "seule": {"dest": "vitrine/cheminee", "anchor_tiles": (0.0, 0.0)},
        "four": {
            "dest": "vitrine/cheminee",
            # ancre sur la grille de 1/32 de tuile (V0 : (-0,59 ; -0,62), hors grille)
            "anchor_tiles": (-0.5625, -0.625),
            # masque : sprite principal du four en acier vanilla, aux deux résolutions, avec son shift
            "mask": {
                "hr": {"file": "steel-furnace/hr-steel-furnace.png", "shift": (-0.0390625, 0.0625)},
                "lr": {"file": "steel-furnace/steel-furnace.png", "shift": (-0.046875, 0.046875)},
            },
            # volume de remplacement du corps du four (passe halo) : boîte INSCRITE dans la silhouette du sprite
            # (une boîte plus grande noircirait le sol vu juste au-dessus du toit) ; mesures sur
            # hr-steel-furnace.png : haut du corps à -51..-71 px HR, bas à +63 px
            "occluders": [{"box": (-0.80, -0.45, 0.80, 0.95), "h": 0.50}],
        },
    },
}

H_TOTAL = 2.36


def build(S, C, variant):
    v = PIECE["variants"][variant]
    tx, ty = v["anchor_tiles"]
    ox, oy, _ = C.tile_to_blender(tx, ty)
    on_furnace = variant == "four"

    def at(x, y, z):
        return (ox + x, oy + y, z)

    def hidden(o):
        # pied de la cheminée, caché derrière le corps du four dans la variante « four »
        return S.mark_hidden(o) if on_furnace else o

    # --- matériaux (valeurs linéaires ; plages vanilla : CALIBRATION.md §5) ---
    # V0 : rugosités 0,40 à 0,60 et grain 0,30 donnaient un rendu mat (corps : écart-type 0,131, p95 0,511).
    shell = S.mat_metal("cheminee_tole", (0.20, 0.17, 0.13), rough=0.22, metallic=0.85, grain=0.12,
                        grain_scale=30.0, rust=(0.26, 0.095, 0.035), rust_amount=0.5, rust_scale=5.0,
                        dirt=0.80, seed=1.0)
    band = S.mat_metal("cheminee_cerclage", (0.85, 0.64, 0.33), rough=0.18, metallic=0.9, grain=0.06,
                       grain_scale=70.0, rust=(0.30, 0.12, 0.05), rust_amount=0.1, dirt=0.6, seed=2.0)
    rivet = S.mat_metal("cheminee_rivet", (0.88, 0.78, 0.60), rough=0.15, metallic=0.9, grain=0.05, seed=3.0)
    plinth = S.mat_metal("cheminee_socle", (0.10, 0.095, 0.085), rough=0.45, metallic=0.5, grain=0.12,
                         grain_scale=35.0, rust=(0.18, 0.075, 0.03), rust_amount=0.3, dirt=0.7, seed=4.0)
    soot = S.mat_flat("cheminee_suie", (0.010, 0.009, 0.008), rough=0.9)
    deck = S.mat_metal("cheminee_passerelle", (0.52, 0.49, 0.44), rough=0.25, metallic=0.8, grain=0.06, dirt=0.5,
                       seed=5.0)
    rail = S.mat_metal("cheminee_echelle", (0.46, 0.43, 0.38), rough=0.25, metallic=0.8, grain=0.06, seed=6.0)
    lip = S.mat_metal("cheminee_levre", (0.40, 0.36, 0.30), rough=0.22, metallic=0.8, grain=0.08, dirt=0.6, seed=7.0)
    # braises : surface ÉTEINTE dans la couche principale (main_scale = 0), la lueur additive seule donne la
    # couleur (V0 : émission comptée deux fois, braises jaune pâle (243,201,100) contre (244,182,58) vanilla)
    ember = S.mat_emissive("cheminee_braises", (1.0, 0.34, 0.03), strength=1.1, main_scale=0.0)
    ember_top = S.mat_emissive("cheminee_gueule", (1.0, 0.28, 0.022), strength=1.0, main_scale=0.0)

    # --- socle boulonné ---
    hidden(S.box((0.62, 0.62, 0.10), at(0, 0, 0.05), plinth, "socle", bevel_w=0.02))
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        hidden(S.cylinder(0.03, 0.04, at(sx * 0.25, sy * 0.25, 0.115), rivet, "boulon_%d" % i, verts=12, bevel_w=0.006))
    hidden(S.cylinder(0.30, 0.06, at(0, 0, 0.13), band, "bride_basse", verts=64, bevel_w=0.015))
    hidden(S.rivet_ring(0.282, 0.165, 14, 0.020, rivet, center=(ox, oy), name="rivets_bride"))

    # --- fût inférieur (tôles rivetées, deux cerclages) ---
    S.cylinder(0.24, 1.08, at(0, 0, 0.16 + 0.54), shell, "fut_bas", verts=64)
    for k, z in enumerate((0.22, 0.58, 0.94)):
        S.rivet_ring(0.244, z, 14, 0.019, rivet, center=(ox, oy), name="rivets_bas_%d" % k, phase=0.11 * k)
    S.torus(0.248, 0.022, at(0, 0, 0.40), band, "cerclage_1")
    S.torus(0.248, 0.022, at(0, 0, 0.76), band, "cerclage_2")

    # --- collier et passerelle à parapet plein (V0 : poteaux de 1 px et tore de 1,2 px, ajourés) ---
    S.cylinder(0.285, 0.10, at(0, 0, 1.29), band, "collier", verts=64, bevel_w=0.015)
    S.rivet_ring(0.29, 1.29, 16, 0.019, rivet, center=(ox, oy), name="rivets_collier")
    S.cylinder(0.37, 0.04, at(0, 0, 1.235), deck, "passerelle", verts=64, bevel_w=0.01)
    S.cylinder(0.365, 0.10, at(0, 0, 1.305), deck, "parapet", verts=64, bevel_w=0, caps=False)
    S.torus(0.365, 0.02, at(0, 0, 1.355), band, "parapet_main_courante", minor_seg=10)

    # --- fût supérieur (légèrement conique) ---
    S.cylinder(0.225, 0.74, at(0, 0, 1.34 + 0.37), shell, "fut_haut", verts=64, radius2=0.206, caps=False)
    for k, z in enumerate((1.48, 1.84)):
        S.rivet_ring(0.222 - 0.022 * k, z, 12, 0.018, rivet, center=(ox, oy), name="rivets_haut_%d" % k)

    # --- couronne : bande d'évents incandescents derrière une grille, lèvre évasée ---
    # bande de 0,18 unité (8 px HR) et 12 barreaux de 2 px (V0 : 0,14 et 24 barreaux : braises hachées)
    S.cylinder(0.212, 0.18, at(0, 0, 2.17), ember, "events_braises", verts=64, bevel_w=0, caps=False)
    bars = []
    for i in range(12):
        a = 2 * math.pi * (i + 0.5) / 12
        b = S.box((0.032, 0.034, 0.19), at(0.216 * math.cos(a), 0.216 * math.sin(a), 2.17), band, "barreau_%d" % i,
                  bevel_w=0)
        b.rotation_euler = (0, 0, a)
        bars.append(b)
    S.join(bars, "grille_events")
    S.cylinder(0.226, 0.032, at(0, 0, 2.08), band, "bague_basse", verts=64, bevel_w=0.008)
    S.cylinder(0.206, 0.10, at(0, 0, 2.31), lip, "levre", verts=64, radius2=0.27, bevel_w=0, caps=False)
    S.torus(0.268, 0.024, at(0, 0, 2.36), band, "levre_bourrelet")
    # gueule : paroi intérieure couverte de suie, lit de braises remonté près de la lèvre (V0 : vu sur 7 px)
    S.cylinder(0.198, 0.12, at(0, 0, 2.30), soot, "gueule_suie", verts=64, bevel_w=0, caps=False)
    S.cylinder(0.198, 0.01, at(0, 0, 2.255), ember_top, "gueule_braises", verts=64, bevel_w=0)
    # lumière portée (passe halo seulement) : six sources juste devant la grille d'évents, couleur de la
    # lumière au sol du four vanilla (fo_calib.VANILLA_GROUND_LIGHT_RGB)
    for i in range(6):
        a = 2 * math.pi * (i + 0.5) / 6
        S.halo_light(at(0.27 * math.cos(a), 0.27 * math.sin(a), 2.17), C.VANILLA_GROUND_LIGHT_RGB, HALO_W / 6,
                     radius=0.05, name="halo_events_%d" % i)

    # --- échelle au sud-ouest (repère d'échelle humaine) : montants et barreaux de 2 px HR au moins ---
    ang = math.radians(235)
    rr = 0.272
    for side in (-1, 1):
        da = side * 0.19
        x = rr * math.cos(ang + da)
        y = rr * math.sin(ang + da)
        S.box((0.032, 0.032, 1.95), at(x, y, 0.2 + 0.975), rail, "echelle_montant_%d" % side, bevel_w=0)
    rungs = []
    for i in range(12):
        z = 0.30 + i * 0.16
        if 1.16 < z < 1.42:
            continue
        x = rr * math.cos(ang)
        y = rr * math.sin(ang)
        r = S.box((0.11, 0.032, 0.032), at(x, y, z), rail, "barreau_echelle_%d" % i, bevel_w=0)
        r.rotation_euler = (0, 0, ang + math.pi / 2)
        rungs.append(r)
    S.join(rungs, "echelle_barreaux")
