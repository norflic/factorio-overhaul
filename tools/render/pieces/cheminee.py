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

Corrections V0b (rapport <racine>/fo-logs/2026-10-21_V0_verif-captures/rapport.md) :
- garde-corps (poteaux de 1 px, tore de 1,2 px) remplacé par un parapet plein : plus aucun jour enfermé ;
- tout élément fait au moins 2 px HR (0,031 unité) : échelle, barreaux, rivets ;
- rivets moins nombreux et plus gros (lecture au zoom 1) ; chanfreins sur brides, collier et lèvre ;
- braises : surface éteinte (et mate) dans la couche principale, la lueur seule donne la couleur (comme le feu
  vanilla) ; lit de braises remonté (gueule visible sur plus de 8 px) ; 12 barreaux au lieu de 24 ;
- halo : sources orange de la lumière vanilla (1 ; 0,49 ; 0,05), flaque au sol seulement, plus compacte.

Ton et photométrie (correcteur V0b, vérification des captures V0b) : l'implémenteur V0b avait éclairci la pièce
(sol clair dans les reflets : médiane du corps 83-86/255, aspect argenté), ce qui changeait le style validé par
le Directeur Créatif le 21/10 sur V0 et enfreignait la règle 1 de la bible (époques 2 et 3 : 52 et 58 ± 10).
Le correcteur revient au TON de V0 (tôle brune sombre rouillée, cerclages laiton), un peu plus sombre (médiane
du corps 53/255 contre 64), avec une couronne suie, une lèvre et une grille noires, et non un éclaircissement
général. La photométrie du corps reste HORS des plages des bâtiments vanilla entiers (écart-type, p05, p95) ; face
à la cheminée du four en acier vanilla, l'écart-type est égal mais les noirs restent trop clairs (p05 0,10 contre
0,02 en jeu). Un environnement sombre dans les reflets donnait ces noirs, mais au prix de la cible de l'époque 3
(médiane 43-46) : non retenu (CALIBRATION §5 quater). Le ton final attend le verdict du Directeur Créatif
(planches côte à côte V0 / V0b / correcteur, <racine>/fo-logs/2026-10-21_V0b_vitrine-final/planches-dc).
"""
import math

HALO_W = 300.0  # puissance totale (W) des 6 sources du halo, réglée sur le pic au sol visé (CALIBRATION §4.2)

PIECE = {
    "name": "cheminee",
    # halo (draw_as_light) : flaque AU SOL autour du pied (plein jusqu'à 0,55 tuile, nul à 1,05 tuile) ; plus
    # de fenêtre « cœur » autour des évents (elle débordait sur le sol vu derrière le sommet)
    "halo": [{"at": (0.0, 0.0, 0.0), "r": (0.55, 1.05)}],
    "margin_px": 96,          # marge du canevas autour de la pièce et de son ombre
    # époques servies (four : 2 « Forge », 3 « Vapeur ») : règles de palette de la bible, bloquantes (médiane du
    # corps 52 ± 10 ET 58 ± 10, soit 48 à 62 /255)
    "epoque": (2, 3),
    # surcharges d'étalonnage propres à la pièce (fo_calib) : passe halo V0b (pièce découpée, README). Aucune
    # surcharge de l'éclairage : plus de sol clair dans les reflets (implémenteur V0b : aspect argenté, rejeté) ;
    # un environnement sombre dans les reflets donnait des noirs plus profonds mais une médiane de 43-46/255, sous
    # la cible de l'époque 3 (CALIBRATION §5 quater).
    "calib": {"LIGHT_HOLDOUT": True},
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

# Matériaux (couleurs LINÉAIRES ; paramètres de fo_scene.mat_metal). Correcteur V0b : retour au TON de V0 (style
# validé le 21/10 : tôle brune sombre rouillée, cerclages laiton), un peu plus sombre (médiane du corps 53/255
# contre 64 en V0 : cible de la bible 48-62 pour les époques 2 et 3) ; couronne suie (shell_top.soot), lèvre et
# grille noires, passerelle et échelle sombres, rivets mats (moins de « lucioles »), cerclages en tore plus
# rugueux que les bagues (ring : reflet du soleil sur un pixel, saturé en blanc à 0,28). Balayages r1 à r5 et
# choix : CALIBRATION §5 quater.
MAT = {
    "shell": dict(color=(0.2, 0.17, 0.13), rough=0.4, metallic=0.55, grain=0.3, grain_scale=45.0,
                  rust=(0.26, 0.095, 0.035), rust_amount=0.5, rust_scale=5.0, dirt=0.85, dirt_distance=0.35),
    "shell_top": dict(color=(0.2, 0.17, 0.13), rough=0.4, metallic=0.55, grain=0.3, grain_scale=45.0,
                      rust=(0.26, 0.095, 0.035), rust_amount=0.5, rust_scale=5.0, dirt=0.85, dirt_distance=0.35,
                      soot=(1.85, 2.07, 0.85)),
    "band": dict(color=(0.72, 0.54, 0.28), rough=0.28, metallic=0.9, grain=0.15, grain_scale=70.0,
                 rust=(0.3, 0.12, 0.05), rust_amount=0.2, dirt=0.35),
    "ring": dict(color=(0.72, 0.54, 0.28), rough=0.4, metallic=0.9, grain=0.15, grain_scale=70.0,
                 rust=(0.3, 0.12, 0.05), rust_amount=0.2, dirt=0.35),
    "rivet": dict(color=(0.36, 0.31, 0.24), rough=0.55, metallic=0.8, grain=0.1),
    "plinth": dict(color=(0.1, 0.095, 0.085), rough=0.6, metallic=0.5, grain=0.25, grain_scale=35.0,
                   rust=(0.18, 0.075, 0.03), rust_amount=0.3, dirt=0.5),
    "deck": dict(color=(0.22, 0.2, 0.17), rough=0.35, metallic=0.7, grain=0.1, dirt=0.5),
    "rail": dict(color=(0.3, 0.27, 0.23), rough=0.35, metallic=0.7, grain=0.1),
    "lip": dict(color=(0.06, 0.055, 0.05), rough=0.6, metallic=0.4, grain=0.2, grain_scale=45.0, dirt=0.5),
    "grille": dict(color=(0.05, 0.045, 0.04), rough=0.7, metallic=0.3, grain=0.1),
}
# Braises (couleur d'émission linéaire, sans bleu ; force ; croûte (échelle, part, graine) : lit non uniforme ;
# « base » : couleur de la surface ÉTEINTE, mate, vue dans la couche principale sous la lueur additive).
EMBER = {
    "vents": (1.0, 0.36, 0.0),
    "vents_strength": 1.1,
    "vents_crust": (14.0, 0.35, 3.0),
    "mouth": (1.0, 0.31, 0.0),
    "mouth_strength": 1.0,
    "mouth_crust": (10.0, 0.55, 5.0),
    "base": (0.008, 0.003, 0.001),
}


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

    # --- matériaux (valeurs linéaires ; table MAT ci-dessus) ---
    def metal(key, name, seed):
        m = dict(MAT[key])
        col = m.pop("color")
        return S.mat_metal(name, col, seed=seed, **m)

    shell = metal("shell", "cheminee_tole", 1.0)
    shell_top = metal("shell_top", "cheminee_tole_haut", 1.5)
    band = metal("band", "cheminee_cerclage", 2.0)
    rivet = metal("rivet", "cheminee_rivet", 3.0)
    # cerclages en TORE (section ronde) : leur reflet du soleil est un point d'un pixel, saturé en blanc si la
    # surface est trop lisse (correcteur V0b : « lucioles » de la vérification) ; matériau à part, plus rugueux
    ring = metal("ring", "cheminee_cerclage_tore", 2.5) if "ring" in MAT else band
    plinth = metal("plinth", "cheminee_socle", 4.0)
    deck = metal("deck", "cheminee_passerelle", 5.0)
    rail = metal("rail", "cheminee_echelle", 6.0)
    lip = metal("lip", "cheminee_levre", 7.0)
    grille = metal("grille", "cheminee_grille", 8.0)
    soot = S.mat_flat("cheminee_suie", (0.010, 0.009, 0.008), rough=0.9)
    # braises : surface ÉTEINTE dans la couche principale (main_scale = 0), la lueur additive seule donne la
    # couleur (V0 : émission comptée deux fois, braises jaune pâle) ; croûte (crust) : lit non uniforme
    ember = S.mat_emissive("cheminee_braises", EMBER["vents"], strength=EMBER["vents_strength"], main_scale=0.0,
                           crust=EMBER["vents_crust"], base=EMBER["base"])
    ember_top = S.mat_emissive("cheminee_gueule", EMBER["mouth"], strength=EMBER["mouth_strength"], main_scale=0.0,
                               crust=EMBER["mouth_crust"], base=EMBER["base"])
    # braises éteintes MATES dans la couche principale : sans cela, leur reflet spéculaire (diélectrique, gris
    # clair) s'ajoutait sous la lueur et bleuissait les braises (correcteur V0b : bleu/rouge 0,16 au lieu de 0,10)
    for m in (ember, ember_top):
        p = m.node_tree.nodes["Principled BSDF"]
        p.inputs["Roughness"].default_value = 1.0
        p.inputs["Specular IOR Level"].default_value = 0.0

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
    S.torus(0.248, 0.022, at(0, 0, 0.40), ring, "cerclage_1")
    S.torus(0.248, 0.022, at(0, 0, 0.76), ring, "cerclage_2")

    # --- collier et passerelle à parapet plein (V0 : poteaux de 1 px et tore de 1,2 px, ajourés) ---
    S.cylinder(0.285, 0.10, at(0, 0, 1.29), band, "collier", verts=64, bevel_w=0.015)
    S.rivet_ring(0.29, 1.29, 16, 0.019, rivet, center=(ox, oy), name="rivets_collier")
    S.cylinder(0.37, 0.04, at(0, 0, 1.235), deck, "passerelle", verts=64, bevel_w=0.01)
    S.cylinder(0.365, 0.10, at(0, 0, 1.305), deck, "parapet", verts=64, bevel_w=0, caps=False)
    S.torus(0.365, 0.02, at(0, 0, 1.355), ring, "parapet_main_courante", minor_seg=10)

    # --- fût supérieur (légèrement conique) ---
    S.cylinder(0.225, 0.74, at(0, 0, 1.34 + 0.37), shell_top, "fut_haut", verts=64, radius2=0.206, caps=False)
    for k, z in enumerate((1.48, 1.84)):
        S.rivet_ring(0.222 - 0.022 * k, z, 12, 0.018, rivet, center=(ox, oy), name="rivets_haut_%d" % k)

    # --- couronne : bande d'évents incandescents derrière une grille, lèvre évasée ---
    # bande de 0,18 unité (8 px HR) et 12 barreaux de 2 px (V0 : 0,14 et 24 barreaux : braises hachées)
    S.cylinder(0.212, 0.18, at(0, 0, 2.17), ember, "events_braises", verts=64, bevel_w=0, caps=False)
    bars = []
    for i in range(12):
        a = 2 * math.pi * (i + 0.5) / 12
        b = S.box((0.032, 0.034, 0.19), at(0.216 * math.cos(a), 0.216 * math.sin(a), 2.17), grille, "barreau_%d" % i,
                  bevel_w=0)
        b.rotation_euler = (0, 0, a)
        bars.append(b)
    S.join(bars, "grille_events")
    S.cylinder(0.226, 0.032, at(0, 0, 2.08), band, "bague_basse", verts=64, bevel_w=0.008)
    S.cylinder(0.206, 0.10, at(0, 0, 2.31), lip, "levre", verts=64, radius2=0.27, bevel_w=0, caps=False)
    S.torus(0.268, 0.024, at(0, 0, 2.36), ring, "levre_bourrelet")
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
