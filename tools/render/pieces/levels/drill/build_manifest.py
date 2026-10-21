"""Manifeste de branchement de la foreuse (lot V3, phase 1) : tools/render/manifests/levels-drill.json.

    python -P tools/render/pieces/levels/drill/build_manifest.py

Lit les aperçus (tools/render/out/levels/drill/spec.json), les mesures D1 (mesures_d1.json) et le
catalogue des époques ; écrit, pour chaque niveau 2 à 30 et chaque direction : couches, tailles hr et
basse résolution, shift (tuiles, multiples de 1/64), drapeaux moteur, pièces ; plus le plan de branchement
de la phase 2 dans l'interface dress(p, ctx) de prototypes/levels/common.lua (non modifiée en phase 1).
Les tailles et shift sont ceux des APERÇUS (même cadrage que le rendu final si la géométrie ne change
pas ; à régénérer en phase 2 avec les rendus définitifs).
"""
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import catalogue  # noqa: E402
import levels_io as IO  # noqa: E402

RENDER = IO.RENDER
MOD_ROOT = os.path.dirname(os.path.dirname(RENDER))
DEST = os.path.join(RENDER, "manifests", "levels-drill.json")
DIR_KEY = {"N": "north", "E": "east", "S": "south", "W": "west"}
FLAGS = {
    "main": {},
    "shadow": {"draw_as_shadow": True},
    "glow": {"draw_as_glow": True, "blend_mode": "additive"},
    "light": {"draw_as_light": True, "blend_mode": "additive"},
}


def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def main():
    spec = IO.load_spec()
    mpath = os.path.join(IO.OUT, "mesures_d1.json")
    mes = json.load(open(mpath, encoding="utf-8")) if os.path.exists(mpath) else {"levels": {}}
    src = {}
    for fn in sorted(os.listdir(HERE)):
        if fn.endswith(".py"):
            src[fn] = sha(os.path.join(HERE, fn))
    levels = {}
    for lvl in range(2, 31):
        e = (lvl + 1) // 2
        ep = catalogue.EPOCHS[e]
        key = "L%02d" % lvl
        lv = spec["levels"].get(key)
        if not lv:
            continue
        dirs = {}
        x0 = y0 = 1e9
        x1 = y1 = -1e9
        for d in IO.DIRS:
            if d not in lv:
                continue
            layers = {}
            for layer in ("main", "shadow", "glow", "light"):
                sd = lv[d].get(layer)
                if not sd:
                    continue
                final = "__factorio-overhaul__/graphics/levels/drill/e%02d/hr-drill-%s-%s-%s.png" % (e, key, d, layer)
                layers[layer] = dict({
                    "apercu": sd["file"], "sha256_apercu": sd["sha256"],
                    "hr": {"filename": final, "width": sd["width"], "height": sd["height"], "shift": sd["shift"],
                           "scale": 0.5},
                    "lr": {"filename": final.replace("/hr-", "/"), "width": sd["width"] // 2,
                           "height": sd["height"] // 2, "shift": sd["shift"], "scale": 1},
                }, **FLAGS[layer])
                if layer == "main":
                    w, h = sd["width"] / 64.0, sd["height"] / 64.0
                    x0, x1 = min(x0, sd["shift"][0] - w / 2), max(x1, sd["shift"][0] + w / 2)
                    y0, y1 = min(y0, sd["shift"][1] - h / 2), max(y1, sd["shift"][1] + h / 2)
            m = mes["levels"].get(key, {}).get(d, {})
            dirs[DIR_KEY[d]] = {"layers": layers, "mesures": {k: m[k] for k in ("O", "O_tige", "L", "area", "added",
                                                                                 "iou_prev") if k in m}}
        entry = {
            "level": lvl, "epoch": e, "epoch_key": ep["key"], "epoch_nom": ep["nom"], "ere": ep["ere"],
            "step": 1 if lvl % 2 == 1 else 2,
            "silhouette": ep["silhouette"],
            "pieces": ([ep["piece"]] if lvl % 2 == 0 else []),
            "piece_invariante": lvl % 2 == 0,
            "lumiere": ep["lumiere"],
            "lueur_de_jour": e >= 3,
            "drawing_box": [[round(x0, 4), round(y0, 4)], [round(x1, 4), round(y1, 4)]],
            "directions": dirs,
        }
        if lvl == 2:
            entry["sur_vanilla"] = ("couches AJOUTÉES au graphics_set vanilla (animation et visualisations "
                                    "inchangées) ; couches main et glow masquées au pixel par l'alpha vanilla de "
                                    "chaque direction ; pièce rendue une fois (pose N, repère fixe)")
        levels[key] = entry
    manifest = {
        "famille": "drill", "base": "electric-mining-drill", "lot": "V3 phase 1 (aperçus)",
        "statut": "APERÇUS : tailles et shift valables pour la géométrie actuelle ; rendu définitif, "
                  "toutes images et branchement en jeu : phase 2 (après V0b et V2). Design NON validé "
                  "(verdict du Directeur Créatif requis).",
        "pipeline": {"px_par_tuile_hr": 64, "projection": "orthographique 45° (F60)", "soleil": "ouest, 48°",
                     "apercus": "Cycles CPU, échantillons réduits (voir spec.json : samples)",
                     "sources_sha256": src},
        "interface_dress": {
            "fichier": "prototypes/levels/drill.lua (dress(p, ctx), en tête de prototypes/levels/common.lua)",
            "selection": "e = ctx.epoch ; niveau = ctx.level ; ctx.step == 1 : silhouette de l'époque ; "
                         "ctx.step == 2 : même chose + pièce (couches du niveau pair, qui CONTIENNENT déjà la pièce)",
            "graphics_set.animation": "Animation4Way : north/east/south/west = { layers = { main, shadow } } "
                                      "(frame_count 1, repeat_count = nombre d'images du trépan si celui-ci reste animé)",
            "graphics_set.working_visualisations": [
                "{ always_draw = true, <dir>_animation = { layers = { glow } } } : lueur de jour (époques 3+) ; "
                "effect/frame_sequence par époque en phase 2 (pulsation, arcs, bulles, uranium-glow…)",
                "{ always_draw = true, draw_as_light, <dir>_animation = { layers = { light } } } : halo de nuit, "
                "OU LightDefinition proportionnelle au niveau (bible §1.6 : I = 0,05 + 0,02·N)",
                "retirer aux niveaux 3+ les visualisations vanilla de la tige (electric_mining_drill_animation, "
                "_horizontal_*) : chaque époque porte sa propre tour ; trépan animé par ère en phase 2 (bible §3.3-5)",
                "garder la fumée et la poussière (teinte du minerai) et les DEL d'état, à repositionner si besoin"],
            "wet_mining_graphics_set": "NON rendu en phase 1 : fenêtres de fluide par ère en phase 2 ; d'ici là, "
                                       "reprendre graphics_set (la foreuse humide aurait sinon le visuel vanilla)",
            "integration_patch": "inchangé (vanilla) en phase 1 ; patch 3×3 par époque partagé avec l'assembleur "
                                 "(bible §3.3-6) en phase 2",
            "drawing_box": "par niveau : champ drawing_box ci-dessous (union des 4 directions, couche principale)",
            "invariants_de_jeu": "collision_box, selection_box, vector_to_place_result {0, -1,85}, entrées de "
                                 "fluide et resource_searching_radius inchangés (D1-4, garde de dress)",
            "circuit_connector": "les points vanilla tombent sur l'ancienne géométrie : à redéfinir par époque "
                                 "en phase 2 (défaut D3 sinon)",
            "icons": "icons(icons, ctx) : rendu de la pose N (64 px, 4 mipmaps) + numéro de niveau, en phase 2",
        },
        "levels": levels,
    }
    os.makedirs(os.path.dirname(DEST), exist_ok=True)
    with open(DEST, "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=1, sort_keys=True, ensure_ascii=False)
    print(DEST, len(levels), "niveaux")


if __name__ == "__main__":
    main()
