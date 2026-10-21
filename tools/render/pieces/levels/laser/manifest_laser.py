"""Tourelle laser, lot V3 phase 1 : manifeste tools/render/manifests/levels-laser.json (branchement de la phase 2).

    python tools/render/pieces/levels/laser/manifest_laser.py

Pour chaque niveau : époque, sources (vanilla / rendu), couches (principale, ombre, lueur, halo) du socle et de la
tête N, E, S, O avec la taille et le shift du sprite RECADRÉ (hr 64 px/tuile, scale 0,5 ; lr 32 px/tuile), comme les
calculerait tools/render/render.py (fo_post.trim_box + sprite_def, alignement sur la grille paire) ; pièce ajoutée ;
points d'ancrage de jeu proposés (lentille), drawing_box proposée, halo de nuit ; sommes SHA-256 des aperçus.
Rien de ce manifeste n'est chargé par le jeu en phase 1 (aperçus en qualité réduite, 4 poses de tête sur 64).
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


def part_spec(level, part):
    p = os.path.join(OUT, "L%02d" % level, "%s.json" % part)
    if not os.path.exists(p):
        return None
    with open(p, encoding="utf-8") as f:
        r = json.load(f)
    lay = {}
    for k, v in sorted(r["layers"].items()):
        lay[k] = {"hr": {"width": v["hr"]["width"], "height": v["hr"]["height"], "shift": v["hr"]["shift"]},
                  "lr": {"width": v["lr"]["width"], "height": v["lr"]["height"], "shift": v["lr"]["shift"]},
                  "flags": {"main": {}, "shadow": {"draw_as_shadow": True},
                            "glow": {"draw_as_glow": True, "blend_mode": "additive"},
                            "light": {"draw_as_light": True, "blend_mode": "additive"}}[k],
                  "apercu": "tools/render/out/levels/laser/L%02d/%s-%s.png" % (level, part, k),
                  "sha256_apercu": v["sha256_canvas"]}
    return {"layers": lay, "render": r["render"]}


def lens_screen(e, heading):
    """Position écran (tuiles) de la lentille / émetteur de l'époque pour un cap donné (proposition de source_offset)."""
    x, y, z = D.LENS_LOCAL[e]
    s = D.HEAD_SCALE[e]
    zp = D.PIVOT[e]
    x, y, z = x * s, y * s, zp + z * s
    a = -math.radians(heading)
    X, Y = x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)
    return [round(X, 4), round(-K * (Y + z), 4)]


def main():
    meas = {}
    mp = os.path.join(OUT, "mesures-d1.json")
    if os.path.exists(mp):
        with open(mp, encoding="utf-8") as f:
            meas = json.load(f)
    levels = {}
    for lv in D.LEVELS:
        e = D.epoch_of(lv)
        odd = lv if lv % 2 else lv - 1
        ent = {"epoch": e, "epoch_name": D.EPOCH_NAME[e], "era": D.ERA_NAME[D.ERA[e]],
               "silhouette": D.ODD_DESIGN[e], "piece": D.EVEN_PIECE[e] if lv % 2 == 0 else None,
               "collision_box": [[-0.7, -0.7], [0.7, 0.7]], "selection_box": [[-1, -1], [1, 1]],
               "halo_nuit": {"glow_light_intensity_propose": round(D.halo_intensity(lv), 3),
                             "taille_tuiles": round(D.halo_size(lv), 3), "source": "bible §1.6, D2-3 (proposition)"}}
        if lv == 1:
            ent["source"] = "vanilla inchangé (Q11) : turrets.lua:883-1041"
        elif lv == 2:
            ent["source"] = "vanilla + pièce d'époque 1 (couche ajoutée au base_picture, masquée au pixel par l'alpha du socle vanilla)"
            ent["base_vanilla"] = "laser-turret/hr-laser-turret-base.png (+ ombre)"
            ent["tete"] = "vanilla (prepared_animation, 64 directions)"
            ent["piece_layers"] = part_spec(2, "base")
        else:
            ent["source"] = "rendu d'aperçu (phase 1) : tools/render/pieces/levels/laser/laser_model.py"
            ent["base_picture"] = part_spec(lv, "base")
            ent["base_note"] = ("socle de l'époque" + (" + pièce (socle complet re-rendu : la pièce n'est pas une couche "
                                                      "séparée)" if lv % 2 == 0 else ""))
            ent["tete_de_niveau"] = odd
            ent["tete_prepared"] = {d: part_spec(odd, d) for d in ("N", "E", "S", "W")}
            ent["pivot_z"] = D.PIVOT[e]
            ent["tete_echelle"] = D.HEAD_SCALE[e]
            ent["lentille_ecran_propose"] = {d: lens_screen(e, D.DIRECTIONS[d]) for d in ("N", "E", "S", "W")}
        m = meas.get("levels", {}).get(str(lv))
        if m:
            env = [min(p["left"] for p in m["poses"].values()), min(p["top"] for p in m["poses"].values()),
                   max(p["right"] for p in m["poses"].values()), max(p["bottom"] for p in m["poses"].values())]
            ent["enveloppe_4_poses"] = [round(v, 3) for v in env]
            ent["drawing_box_proposee"] = [[round(min(env[0], -1.0), 2), round(env[1], 2)],
                                           [round(max(env[2], 1.0), 2), round(max(env[3], 1.0), 2)]]
            ent["O_max"] = round(m["O_max"], 3)
        levels["%02d" % lv] = ent
    man = {
        "famille": "laser", "lot": "V3 phase 1", "type": "electric-turret", "emprise": "2x2 (inchangée, D1-4)",
        "canevas_apercu": {"largeur": D.CANVAS_W, "hauteur": D.CANVAS_H, "origine_px": list(D.ORIGIN_PX),
                           "px_par_tuile": D.PPT},
        "poses_phase1": "socle (1 direction) ; tête prepared N, E, S, O = images 0, 16, 32, 48 de 64",
        "phase2_a_rendre": {"tete_prepared": "64 directions (8 × 8, comme le vanilla), 1 image",
                            "deploiement": "15 images × 4 directions (Q12 : aucune économie)",
                            "masque_couleur_equipe": "à rendre (apply_runtime_tint), absent des aperçus",
                            "energy_glow_animation": "lueur de tir de la lentille, 64 directions, absente des aperçus",
                            "qualite": "échantillons pleins (fo_calib.SAMPLES), après V0b"},
        "ancrages_vanilla": {"attack_parameters.source_offset": [0, -3.423489 / 4], "beam.source_offset": [0, -1.31439]},
        "niveaux": levels,
    }
    os.makedirs(os.path.dirname(MAN), exist_ok=True)
    with open(MAN, "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[manifeste] %s : %d niveaux" % (MAN, len(levels)))


if __name__ == "__main__":
    main()
