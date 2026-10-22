"""Tourelle laser, lot V3 phase 1 : manifeste tools/render/manifests/levels-laser.json (branchement de la phase 2).

    python tools/render/pieces/levels/laser/manifest_laser.py

Conçu pour l'interface de visuel du lot V2 (en tête de prototypes/levels/common.lua) : prototypes/levels/laser.lua
renverra { dress = function(p, ctx) ... end, icons = ... } ; dress lira ce manifeste (converti en Lua par la phase 2,
comme graphics/<dest>/sprites.lua de tools/render/render.py) avec la clé "%02d" % ctx.level et posera les champs
GRAPHIQUES du prototype electric-turret qui y sont nommés, et eux seuls (garde de Common.dress) :
  base_picture, prepared_animation, folded_animation, preparing_animation, folding_animation,
  energy_glow_animation, glow_light_intensity, water_reflection, drawing_box,
  base_picture_render_layer, base_picture_secondary_draw_order, gun_animation_secondary_draw_order (correction V3,
  majeur 2 : socles qui montent au-dessus du bord nord de l'emprise ; champs admis par la garde, common.lua:169-170),
  attack_parameters.source_offset, attack_parameters.ammo_type.action.action_delivery.source_offset
(source_offset est une sous-clé visuelle autorisée : VISUAL_SUBKEYS). Les durées de jeu (preparing_speed,
folding_speed × nombre d'images) restent celles du vanilla : 15 images de déploiement, vitesse 0,05.

Pour chaque niveau : époque, pas (ctx.step), sources, couches (principale, ombre, lueur, halo) du socle et de la tête
N, E, S, O avec taille et shift du sprite RECADRÉ (hr 64 px/tuile, scale 0,5 ; lr 32 px/tuile), calculés comme
tools/render/render.py (fo_post.trim_box + sprite_def, grille paire) ; pièce ajoutée ; ancrages de tir proposés ;
drawing_box proposée ; halo de nuit ; sommes SHA-256 des aperçus. RIEN de ce manifeste n'est chargé par le jeu en
phase 1 : aperçus à 32 échantillons, 4 poses de tête sur 64, pas de masque de couleur d'équipe ni de déploiement.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import laser_design as D  # noqa: E402

RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(RENDER, "out", "levels", "laser")
MAN = os.path.join(RENDER, "manifests", "levels-laser.json")
K = math.sqrt(0.5)
FLAGS = {"main": {}, "shadow": {"draw_as_shadow": True},
         "glow": {"draw_as_glow": True, "blend_mode": "additive"},
         "light": {"draw_as_light": True, "blend_mode": "additive"}}
ROLE = {"main": "couleur", "shadow": "ombre", "glow": "lueur", "light": "halo"}
ORDER = ("main", "shadow", "glow", "light")


def rnd(v, n=6):
    return [round(x, n) for x in v] if isinstance(v, (list, tuple)) else round(v, n)


def part_spec(level, part, file_stem):
    """Couches d'une partie rendue : taille et shift recadrés, drapeaux moteur, fichier de phase 2, aperçu."""
    p = os.path.join(OUT, "L%02d" % level, "%s.json" % part)
    if not os.path.exists(p):
        return None
    with open(p, encoding="utf-8") as f:
        r = json.load(f)
    layers = []
    for k in ORDER:
        v = r["layers"].get(k)
        if v is None:
            continue
        lay = {"role": ROLE[k],
               "hr": {"width": v["hr"]["width"], "height": v["hr"]["height"], "shift": rnd(v["hr"]["shift"]),
                      "scale": 0.5},
               "lr": {"width": v["lr"]["width"], "height": v["lr"]["height"], "shift": rnd(v["lr"]["shift"]),
                      "scale": 1},
               "fichier_phase2": "__factorio-overhaul__/graphics/levels/laser/e%02d/%s-%s.png" % (
                   D.epoch_of(level), file_stem, ROLE[k]),
               "apercu": "tools/render/out/levels/laser/L%02d/%s-%s.png" % (level, part, k),
               "sha256_apercu": v["sha256_canvas"]}
        lay.update(FLAGS[k])
        layers.append(lay)
    rr = r["render"]
    return {"layers": layers, "rendu": {"echantillons": rr["samples"], "secondes": rr["seconds"], "blender": rr["blender"],
                                        "graine": rr["seed"]}}


def layer_fields(lv, m):
    """Couche du socle proposée. Vanilla : base_picture en « lower-object » (défaut). Un socle dont le haut dépasse le
    bord nord de l'emprise (colonne, mât, cheminée) serait recouvert par tout sprite « object » posé au nord (mur,
    autre tourelle) alors qu'il est devant : il passe en « object », sous la tête (secondary_draw_order 0 < 1)."""
    top = m.get("base_top") if m else None
    layer = m.get("base_layer", "lower") if m else "lower"
    if layer == "object":
        return {"base_picture_render_layer": "object", "base_picture_secondary_draw_order": 0,
                "gun_animation_secondary_draw_order": 1,
                "note_couche": ("haut du socle seul à y = %.2f tuile, au-dessus du bord nord de l'emprise (y = -1) : socle en "
                                "« object » sous la tête. Ordre de dessin NON VÉRIFIÉ en moteur (capture phase 2 : mur et "
                                "2e tourelle au nord)" % top)}
    return {"note_couche": "socle sous le bord nord de l'emprise (haut %s) : base_picture_render_layer vanilla "
                           "(lower-object) conservé" % ("%.2f" % top if top is not None else "-")}


def lens_world(e, heading):
    """Lentille de l'époque, cap donné : (dx, dy) au sol en tuiles depuis le centre et hauteur à l'écran (tuiles)."""
    x, y, z = D.LENS_LOCAL[e]
    s = D.HEAD_SCALE[e]
    zp = D.PIVOT[e]
    x, y, z = x * s, y * s, zp + z * s
    a = -math.radians(heading)
    X, Y = x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)
    return X, -Y * K, z * K          # x est, y sud (tuiles de jeu), hauteur à l'écran


def anchors(e):
    _, dy, h = lens_world(e, 0.0)
    ecran = {}
    for d in ("N", "E", "S", "W"):
        X, Y, hh = lens_world(e, D.DIRECTIONS[d])
        ecran[d] = rnd([X, Y - hh], 4)
    return {"attack_parameters.source_offset": [0, rnd(dy, 4)],
            "beam.source_offset": [0, rnd(-h, 4)],
            "lentille_ecran_par_pose": ecran,
            "note": ("proposition calculée sur la géométrie (même convention que le vanilla : source_offset = position "
                     "au sol de la lentille quand la tête vise le nord, tournée par source_direction_count = 64 ; "
                     "beam.source_offset = hauteur de la lentille à l'écran). Vanilla : {0, -0,8559} et {0, -1,3144}. "
                     "NON VÉRIFIÉ en moteur : le faisceau doit partir de la lentille à l'écran (capture phase 2).")}


def main():
    meas = {}
    mp = os.path.join(OUT, "mesures-d1.json")
    if os.path.exists(mp):
        with open(mp, encoding="utf-8") as f:
            meas = json.load(f)
    levels = {}
    missing = []
    for lv in D.LEVELS:
        e = D.epoch_of(lv)
        odd = lv if lv % 2 else lv - 1
        m_lv = meas.get("levels", {}).get(str(lv))
        ent = {"epoque": e, "nom_epoque": D.EPOCH_NAME[e], "ere": D.ERA_NAME[D.ERA[e]],
               "step": 1 if lv % 2 else 2,
               "silhouette": D.ODD_DESIGN[e], "piece": D.EVEN_PIECE[e] if lv % 2 == 0 else None,
               "collision_box": [[-0.7, -0.7], [0.7, 0.7]], "selection_box": [[-1, -1], [1, 1]],
               "halo_nuit": {"glow_light_intensity": round(D.halo_intensity(lv), 3),
                             "taille_tuiles": round(D.halo_size(lv), 3),
                             "source": "bible §1.6, D2-3 : I(N) = 0,05 + 0,02 N, S(N) = 2 (1 + 0,05 N) (proposition)",
                             "realisation_v3": ("couche draw_as_light du socle : flaque au sol de pic LIGHT_MAX × I(N)/I(30), "
                                                "pleine jusqu'à 0,25 S(N), nulle à 0,75 S(N) (rayon à mi-intensité S(N)/2), "
                                                "+ cœurs rendus autour des sources ; canevas propre des halos "
                                                "(origine %s px, %d × %d px hr)" % (list(D.LIGHT_ORIGIN_PX), D.LIGHT_W, D.LIGHT_H)),
                             "mesure": ({k: round(v, 3) for k, v in m_lv["halo"].items()} if (m_lv and "halo" in m_lv) else None)}}
        if lv == 1:
            ent["source"] = "vanilla inchangé (Q11) : data/base/prototypes/entity/turrets.lua:883-1041 ; dress n'est pas appelée"
        elif lv == 2:
            ent["source"] = ("vanilla + pièce d'époque 1 : couches AJOUTÉES en fin de base_picture.layers (après le socle et "
                             "son ombre vanilla), déjà masquées au pixel par l'alpha du socle vanilla (procédé V0 « four »)")
            piece = part_spec(2, "base", "piece-n02")
            if piece is None:
                missing.append("L02 base")
            ent["dress"] = {"base_picture": {"mode": "ajout_aux_couches_vanilla", "couches_ajoutees": piece},
                            "tete": "vanilla inchangée (prepared_animation, folded/preparing/folding, energy_glow_animation)",
                            "water_reflection": "vanilla (la silhouette du niveau 2 est celle du vanilla)"}
        else:
            base = part_spec(lv, "base", "socle-n%02d" % lv)
            heads = {d: part_spec(odd, d, "tete") for d in ("N", "E", "S", "W")}
            for d, h in heads.items():
                if h is None:
                    missing.append("L%02d %s" % (odd, d))
            if base is None:
                missing.append("L%02d base" % lv)
            ent["source"] = "rendu d'aperçu (phase 1) : tools/render/pieces/levels/laser/laser_model.py"
            ent["dress"] = {
                "base_picture": {"mode": "remplace", "direction_count": 1, "frame_count": 1,
                                 "note": ("socle de l'époque" + (" + pièce paire : socle complet re-rendu (1 pose, même coût "
                                                                  "qu'une couche de pièce séparée, ombres et liseré exacts)"
                                                                  if lv % 2 == 0 else "")),
                                 "couches": base},
                # correction V3 (vérification passe 5, majeur 2) : couche du socle (compose_laser.base_order_of)
                **layer_fields(lv, m_lv),
                "prepared_animation": {"mode": "remplace", "direction_count": 64, "frame_count": 1, "line_length": 8,
                                       "tete_du_niveau": odd,
                                       "poses_apercu": heads,
                                       "phase2": ("64 directions (image d = cap 360·d/64, sens horaire depuis le nord) ; "
                                                  "couches couleur, ombre (draw_as_shadow), lueur (draw_as_glow), halo "
                                                  "(draw_as_light) et MASQUE de couleur d'équipe (apply_runtime_tint) ; "
                                                  "même canevas pour les 64 directions (shift commun)")},
                "folded_animation": "phase 2 : image 0 du déploiement, 4 directions",
                "preparing_animation": "phase 2 : 15 images × 4 directions (Q12, aucune économie), vitesse vanilla 0,05",
                "folding_animation": "phase 2 : les mêmes images, run_mode = backward",
                "energy_glow_animation": "phase 2 : lueur de tir de la lentille, 64 directions, blend additive",
                "glow_light_intensity": round(D.halo_intensity(lv), 3),
                "water_reflection": None,
                "ancrages_tir": anchors(e),
                "pivot_z_unites": D.PIVOT[e], "tete_echelle": D.HEAD_SCALE[e],
            }
            ent["water_reflection_note"] = "retiré (bible §1.8-5 : garder le reflet vanilla sous une autre silhouette est un défaut D3)"
        m = m_lv
        if m:
            env = [min(p["left"] for p in m["poses"].values()), min(p["top"] for p in m["poses"].values()),
                   max(p["right"] for p in m["poses"].values()), max(p["bottom"] for p in m["poses"].values())]
            ent["enveloppe_4_poses_tuiles"] = rnd(env, 3)
            ent["drawing_box_proposee"] = [[round(min(env[0], -1.0), 2), round(env[1], 2)],
                                           [round(max(env[2], 1.0), 2), round(max(env[3], 1.0), 2)]]
            ent["O_max"] = round(m["O_max"], 3)
            ent["O_brut_max"] = round(m.get("O_brut_max", m["O_max"]), 3)
            ent["note_O"] = "O = sommet des masses (tiges < 0,15 tuile exclues, bible §1.4) ; O_brut = tiges comprises"
            if "dress" in ent:
                ent["dress"]["drawing_box"] = ent["drawing_box_proposee"]
        levels["%02d" % lv] = ent
    man = {
        "famille": "laser", "cle": "laser", "lot": "V3 phase 1", "type": "electric-turret", "vanilla": "laser-turret",
        "emprise": "2×2 inchangée (D1-4) : collision ±0,7, sélection ±1 (turrets.lua:891-892)",
        "statut": ("APERÇUS de phase 1 : 32 échantillons, socle + tête prepared N, E, S, O. Rien n'est chargé par le jeu ; "
                   "aucun design n'est validé (verdict du Directeur Créatif requis)."),
        "interface_v2": {"fichier": "prototypes/levels/laser.lua", "fonction": "dress(p, ctx)",
                         "cle_niveau": "string.format('%02d', ctx.level)",
                         "champs_poses": ["base_picture", "prepared_animation", "folded_animation", "preparing_animation",
                                          "folding_animation", "energy_glow_animation", "glow_light_intensity",
                                          "water_reflection", "drawing_box", "attack_parameters.source_offset",
                                          "attack_parameters.ammo_type.action.action_delivery.source_offset",
                                          "base_picture_render_layer", "base_picture_secondary_draw_order",
                                          "gun_animation_secondary_draw_order"],
                         "icons": "phase 2 : rendu de la pose de référence (tête N + socle), 64 px et 3 mipmaps, + numéro (lib.tier_icons)"},
        "conventions": {"hr": "64 px/tuile, scale 0,5", "lr": "32 px/tuile, scale 1 (réduction 2× en linéaire prémultiplié)",
                        "shift": "tuiles, multiples de 1/64, générés (jamais réglés à la main)",
                        "couches": "ordre : couleur, ombre (draw_as_shadow), lueur (draw_as_glow + additive), halo (draw_as_light + additive)",
                        "codage_additif": "RGB = c / max(c), A = max(c) (fo_post.additive_layer)",
                        "arborescence_phase2": "graphics/levels/laser/e<NN>/{socle-nNN,tete,piece-n02}-{couleur,ombre,lueur,halo,masque}.png (bible §1.9)"},
        "canevas_apercu": {"largeur": D.CANVAS_W, "hauteur": D.CANVAS_H, "origine_px": list(D.ORIGIN_PX),
                           "px_par_tuile": D.PPT, "note": "couches couleur, ombre et lueur : origine = position de l'entité",
                           "halo": {"largeur": D.LIGHT_W, "hauteur": D.LIGHT_H, "origine_px": list(D.LIGHT_ORIGIN_PX),
                                    "note": "couches halo (draw_as_light) sur un canevas plus grand, même grille (V3)"}},
        "phase2_a_rendre": {"tete_prepared": "64 directions (8 × 8, comme le vanilla), 1 image",
                            "deploiement": "15 images × 4 directions (Q12 : aucune économie)",
                            "masque_couleur_equipe": "à rendre (apply_runtime_tint), absent des aperçus",
                            "energy_glow_animation": "lueur de tir de la lentille, 64 directions, absente des aperçus",
                            "animations_socle": "époques 4 à 15 (flamme, braises, arcs...) : base_picture est une Animation4Way (F44 : défilement en moteur non vérifié)",
                            "qualite": "échantillons pleins (fo_calib.SAMPLES), après V0b"},
        "ancrages_vanilla": {"attack_parameters.source_offset": [0, -3.423489 / 4], "beam.source_offset": [0, -1.31439]},
        "manquants": missing,
        "niveaux": levels,
    }
    os.makedirs(os.path.dirname(MAN), exist_ok=True)
    with open(MAN, "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[manifeste] %s : %d niveaux, %d parties manquantes %s" % (MAN, len(levels), len(missing), missing))


if __name__ == "__main__":
    main()
