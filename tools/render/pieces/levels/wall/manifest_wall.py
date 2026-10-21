"""Manifeste du mur pour le branchement de la phase 2 : tools/render/manifests/levels-wall.json.

    python -P tools/render/pieces/levels/wall/manifest_wall.py

Lit les aperçus (tools/render/out/levels/wall/render_results.json), les mesures D1 (mesures_d1.json, si
présentes) et les métadonnées d'époque (wall_piece.py). Pour chaque niveau 2 à 30 et chaque clé WallPictures
de la phase 1 (straight_horizontal, single) : couches dans l'ordre de dessin, drapeaux moteur, tailles et
shift (hr 64 px/tuile scale 0,5 ; lr 32 px/tuile), chemin cible de la phase 2, pièce et lumière.

Conçu pour l'interface V2 (prototypes/levels/common.lua) : wall.lua dress(p, ctx) posera
p.pictures[<clé>] = { layers = { ... } } pour ctx.level, à partir de ce manifeste, sans toucher aux
champs de jeu (garde de Common.dress). Les APERÇUS (échantillons réduits) ne sont PAS les sprites finaux :
tailles et shift seront régénérés par le rendu final de la phase 2 (mêmes scripts, même origine).
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import wall_layers as WL  # noqa: E402
import wall_piece  # noqa: E402

MANIFEST = os.path.join(RENDER, "manifests", "levels-wall.json")
GFX = "__factorio-overhaul__/graphics/levels/wall"
FLAGS = {
    "main": {},
    "shadow": {"draw_as_shadow": True},
    "glow": {"draw_as_glow": True, "blend_mode": "additive"},
    "light": {"draw_as_light": True, "blend_mode": "additive"},
}
ORDER = ("main", "glow", "light", "shadow")


def vanilla_layers(pose):
    v = wall_piece.VANILLA[pose]
    rel, w, h, shift = v["hr"]
    rel_l, wl, hl, shift_l = v["lr"]
    srel, sw, sh, sshift = v["shadow_hr"]
    srel_l, swl, shl, sshift_l = v["shadow_lr"]
    return [
        {"couche": "vanilla-main", "source": "vanilla", "drapeaux": {},
         "hr": {"filename": "__base__/graphics/entity/" + rel, "width": w, "height": h, "shift": list(shift)},
         "lr": {"filename": "__base__/graphics/entity/" + rel_l, "width": wl, "height": hl, "shift": list(shift_l)},
         "note": "image 0 en phase 1 (variation_count vanilla conservé en phase 2)"},
        {"couche": "vanilla-shadow", "source": "vanilla", "drapeaux": {"draw_as_shadow": True},
         "hr": {"filename": "__base__/graphics/entity/" + srel, "width": sw, "height": sh, "shift": list(sshift)},
         "lr": {"filename": "__base__/graphics/entity/" + srel_l, "width": swl, "height": shl, "shift": list(sshift_l)}},
    ]


def main():
    db = WL.results()
    mes = {}
    pm = os.path.join(WL.OUT, "mesures_d1.json")
    if os.path.exists(pm):
        with open(pm, encoding="utf-8") as f:
            mes = json.load(f)
    levels = {}
    for lv in wall_piece.LEVELS:
        e = wall_piece.epoch(lv)
        info = wall_piece.EPOCH_INFO[e]
        entry = {"epoque": e, "cle_epoque": info["cle"], "step": 1 if lv % 2 else 2,
                 "silhouette": info["silhouette"] if lv != 2 else wall_piece.EPOCH_INFO[1]["silhouette"],
                 "piece": info["piece"] if lv % 2 == 0 else None, "emissif": info["emissif"],
                 "base": "vanilla + pièce (masquée au pixel par l'alpha vanilla sous y = %.2f)" % wall_piece.L2_CUT_V
                 if lv == 2 else "rendu complet de l'époque" + (" + pièce" if lv % 2 == 0 else ""),
                 "cles": {}}
        for pose, key in wall_piece.POSE_KEYS.items():
            r = db.get("n%02d-%s" % (lv, pose))
            if r is None:
                entry["cles"][key] = {"etat": "non rendu"}
                continue
            layers = vanilla_layers(pose) if lv == 2 else []
            for layer in ORDER:
                if layer not in r["spec"]:
                    continue
                sd = r["spec"][layer]
                fn = "hr-wall-n%02d-%s-%s.png" % (lv, key, layer)
                layers.append({
                    "couche": layer, "source": "rendu", "drapeaux": FLAGS[layer],
                    "hr": {"filename": "%s/e%02d/%s" % (GFX, e, fn), "width": sd["hr"]["width"],
                           "height": sd["hr"]["height"], "shift": sd["hr"]["shift"]},
                    "lr": {"filename": "%s/e%02d/%s" % (GFX, e, fn[3:]), "width": sd["lr"]["width"],
                           "height": sd["lr"]["height"], "shift": sd["lr"]["shift"]},
                    "apercu": "tools/render/out/levels/wall/%s/%s" % (r["dir"], sd["hr"]["filename"]),
                })
            # ordre de dessin du moteur : ombres dans leur tampon, puis couches dans l'ordre de la liste
            k = {"pose": pose, "couches": layers, "variation_count": 1,
                 "repeat_count_note": "niveau 2 : la surcouche reçoit repeat_count = variation_count de la couche "
                                      "vanilla de la clé (6 pour straight_horizontal, 2 pour single)" if lv == 2 else None,
                 "rendu": {"echantillons": r["render"]["samples"], "secondes": r.get("seconds_total"),
                           "blender": r["render"]["blender"], "graine": r["render"]["seed"]}}
            if r.get("halo"):
                k["halo"] = {"I": r["halo"]["I"], "S": r["halo"]["S"]}
            mk = "%d-%s" % (lv, pose)
            if mes.get("niveaux", {}).get(mk):
                m = mes["niveaux"][mk]
                k["mesures"] = {x: m.get(x) for x in ("aire_t2", "L", "x", "y", "O_masses", "O_tout", "lum_p50", "lum_p95",
                                                      "sat", "iou_prec", "iou_epoque_prec", "piece_aire_ajoutee_t2")}
                k["mesures"]["lueur_delta_8x8"] = (m.get("lueur") or {}).get("best_delta")
            entry["cles"][key] = k
        entry["cles_phase2"] = list(wall_piece.PHASE2_KEYS)
        levels["%d" % lv] = entry
    man = {
        "famille": "wall", "lot": "V3 phase 1", "statut": "APERÇU (échantillons réduits) : non branché, non prouvé en moteur",
        "interface": "prototypes/levels/wall.lua : dress(p, ctx) -> p.pictures[cle] = {layers = ...} pour ctx.level ; "
                     "icons(icons, ctx) : rendu de la pose single (phase 2)",
        "niveau_1": "vanilla inchangé (Q11) : aucune image",
        "convention": {"hr": "64 px/tuile, scale = 0.5", "lr": "32 px/tuile, scale = 1",
                       "shift": "tuiles, multiples de 1/64 (hr) et 1/32 (lr), origine = position de l'entité",
                       "ombre": "draw_as_shadow, noir, alpha = part d'ombre (affichée à 50 % par le moteur)",
                       "lueur": "draw_as_glow, additive, RGB = c/max, A = max", "halo": "draw_as_light, additive, "
                       "hors de la silhouette du mur (F64), intensité I(N) = 0,05 + 0,02 N, rayon <= 1 tuile"},
        "raccord": "visual_merge_group = 0 : plinthe commune x [-0,5 ; 0,5], ty [0,28 ; 0,50], z [0 ; 0,22] "
                   "pour les époques 2 à 15 (wall_epochs.py)",
        "fichiers_phase2": GFX + "/eNN/hr-wall-nNN-<clé>-<couche>.png (+ version lr sans « hr- »)",
        "basse_qualite": "aperçus : lr = réduction 2x de la hr (fo_post.downsample2) ; D4-2 (Q21) demande des sprites "
                         "32 px/tuile RENDUS à leur taille : besoin envoyé au pipeline partagé, à faire en phase 2",
        "dress_lua": "pour ctx.level = n : L = niveaux[n] ; pour chaque clé c de L.cles : p.pictures[c] = { layers = "
                     "{ couches dans l'ordre : filename, width, height, shift, drapeaux, hr_version = { filename, "
                     "width, height, shift, scale = 0.5, drapeaux } } } ; clés pas encore produites (phase 2) : "
                     "image vanilla gardée ; aucun champ de jeu touché (garde de Common.dress)",
        "niveaux": levels,
    }
    if mes.get("d1_3"):
        man["d1_3"] = mes["d1_3"]
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, sort_keys=True, ensure_ascii=False)
    print(MANIFEST)


if __name__ == "__main__":
    main()
