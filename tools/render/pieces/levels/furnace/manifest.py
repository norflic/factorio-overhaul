"""Manifeste de branchement du four (lot V3, phase 1) : tools/render/manifests/levels-furnace.json.

    python -P tools/render/pieces/levels/furnace/manifest.py

Lit les rendus d'APERÇU (tools/render/out/levels/furnace/nXX/spec.json) et les points clés de la famille
(furnace_levels.KEY, params.py). Écrit, pour chaque niveau, ce que la phase 2 doit poser par l'interface
de prototypes/levels/common.lua (dress(p, ctx), icons(icons, ctx)) : couches, tailles, ancrages (shift),
pièces, fumée, bouche, halo, drawing_box. Les tailles et shift sont ceux des aperçus : la phase 2 les
REGÉNÈRE au rendu final (mêmes règles : dimensions HR paires, shift multiples de 1/64 de tuile, générés par
le pipeline, jamais réglés à la main ; bible §1.8).
"""
import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import params as PRM  # noqa: E402

RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MOD_ROOT = os.path.dirname(os.path.dirname(RENDER))
OUT = os.path.join(RENDER, "out", "levels", "furnace")
DST = os.path.join(RENDER, "manifests", "levels-furnace.json")
S45 = PRM.S45


def load_piece():
    spec = importlib.util.spec_from_file_location("fo_furnace_meta", os.path.join(HERE, "furnace_levels.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


LAYER_FLAGS = {
    "main": {},
    "shadow": {"draw_as_shadow": True},
    "glow": {"draw_as_glow": True, "blend_mode": "additive"},
    "light": {"draw_as_light": True, "draw_as_sprite": False, "blend_mode": "additive"},
}


def layer_entry(n, e, layer, s):
    hr_name = "hr-furnace-n%02d-%s.png" % (n, layer)
    lr_name = "furnace-n%02d-%s.png" % (n, layer)
    base = "__factorio-overhaul__/graphics/levels/furnace/e%02d/" % e
    d = {"filename": base + lr_name, "width": s["width"] // 2, "height": s["height"] // 2, "shift": s["shift"],
         "hr_version": dict({"filename": base + hr_name, "width": s["width"], "height": s["height"], "shift": s["shift"],
                             "scale": 0.5}, **LAYER_FLAGS[layer])}
    d.update(LAYER_FLAGS[layer])
    d["sha256_apercu"] = s.get("sha256")
    return d


def screen(x, y, z):
    return [round(x, 4), round(y - S45 * (z or 0.0), 4)]


def main():
    mod = load_piece()
    KEY = mod.KEY
    levels = []
    levels.append({"n": 1, "epoque": 1, "step": 1, "vanilla": True,
                   "note": "four en acier vanilla inchangé (Q11) : référence D1-3 ; aucun fichier",
                   "fumee": [{"position": [0.7, -1.2], "source": "entities.lua:7268"}]})
    for n in PRM.RENDERED:
        e = PRM.epoch_of(n)
        step = 2 if n % 2 == 0 else 1
        p = os.path.join(OUT, "n%02d" % n, "spec.json")
        if not os.path.exists(p):
            levels.append({"n": n, "epoque": e, "step": step, "absent": "aperçu non rendu"})
            continue
        with open(p, encoding="utf-8") as f:
            sp = json.load(f)
        L = sp["layers"]
        lay = []
        order = ["shadow", "main", "glow", "light"]
        for k in order:
            if k in L:
                lay.append(dict(layer_entry(n, e, k, L[k]), couche=k))
        ch = KEY[e]["chimney"][-1] if n == 2 else KEY[e]["chimney"][0]
        smoke = screen(ch[0], ch[1], ch[2])
        ent = {"n": n, "epoque": e, "step": step, "epoque_nom": PRM.EPOCHS[e]["nom"], "ere": PRM.EPOCHS[e]["ere"],
               "corps": PRM.EPOCHS[e]["corps"] if n != 2 else "vanilla (four en acier inchangé)",
               "piece_paire": PRM.EPOCHS[e]["piece"] if step == 2 else None,
               "apercu": {"echantillons": sp["samples"], "graine": sp["seed"], "blender": sp["blender"],
                          "toile": sp["canvas"], "origine_px": sp["origin_px"]},
               "fumee": [{"position": smoke, "note": "haut de la cheminée de l'époque (écran, tuiles) : "
                                                     "energy_source.smoke[1].position"}]}
        if n == 2:
            ent["dress"] = {
                "principe": "vanilla conservé (animation, working_visualisations, water_reflection) ; la pièce "
                            "est une couche AJOUTÉE à p.animation.layers, AVANT le corps vanilla (elle passe "
                            "derrière : déjà masquée au pixel par l'alpha du sprite vanilla, comme la variante "
                            "« four » de V0) ; son ombre rejoint les ombres. Aucune lueur ni halo propre (époque 1 : "
                            "lumière de nuit seulement par la lanterne, absente du four ; bible §5) : la passe light "
                            "n'est pas rendue, ce qui évite le défaut F64/E31 (trou de lumière sur le toit du four)",
                "animation_layers_ajoutees": lay,
                "smoke": "p.energy_source.smoke[1].position = fumee[0].position (sortie sous le chapeau du conduit)",
            }
            mains = L["main"]
            hw, hh = mains["width"] / 128.0, mains["height"] / 128.0
            sx, sy = mains["shift"]
            # boîte du sprite vanilla (171 × 174 HR, shift (-1,25 ; 2) px) unie à la pièce
            vb = [[-0.0390625 - 171 / 128.0, 0.0625 - 174 / 128.0], [-0.0390625 + 171 / 128.0, 0.0625 + 174 / 128.0]]
            ent["drawing_box"] = [[round(min(vb[0][0], sx - hw), 4), round(min(vb[0][1], sy - hh), 4)],
                                  [round(max(vb[1][0], sx + hw), 4), round(max(vb[1][1], sy + hh), 4)]]
        else:
            ent["dress"] = {
                "principe": "p.animation = { layers = [shadow, main] } (rendu complet de l'époque, pièce "
                            "comprise au niveau pair en phase 1) ; lueur et halo dans p.working_visualisations "
                            "(feu de la bouche : effect = 'flicker', fadeout = true ; voir 'bouche') ; "
                            "p.water_reflection = nil (bible §1.8.5 : le reflet vanilla sous une autre "
                            "silhouette est un défaut D3) ; p.drawing_box = drawing_box",
                "animation_layers": [x for x in lay if x["couche"] in ("shadow", "main")],
                "working_visualisations": [
                    {"couche": x["couche"], "fadeout": True, "effect": "flicker", "animation": x}
                    for x in lay if x["couche"] in ("glow", "light")],
                "smoke": "p.energy_source.smoke[1].position = fumee[0].position",
            }
            mains = L["main"]
            hw, hh = mains["width"] / 128.0, mains["height"] / 128.0
            sx, sy = mains["shift"]
            ent["drawing_box"] = [[round(sx - hw, 4), round(sy - hh, 4)], [round(sx + hw, 4), round(sy + hh, 4)]]
            ent["bouche"] = [{"position_ecran": screen(x, y, z), "couleur": c,
                              "note": "zone émissive (lueur) ; la bouche au sud porte le feu animé de l'ère (phase 2)"}
                             for (x, y, z, c) in KEY[e]["emit"]]
            I, S = PRM.halo_intensity(n)
            hl = PRM.halo_layer(n)
            ent["halo"] = {"couche_light_max": round(hl["max"], 3), "flaque_centre": list(hl["center"]),
                           "rayons_plein_nul_tuiles": [round(hl["r0"], 3), round(hl["r1"], 3)],
                           "light_definition_proposee": {"intensity": round(I, 3), "size": round(S, 3),
                                                         "color": PRM.PALETTE[e]["emit"],
                                                         "note": "bible §1.6, I(N) = 0,05 + 0,02 N, S(N) = 2 (1 + 0,05 N)"}}
        ent["icone"] = {"source": "couche principale de la pose de référence (P.icon_strip : 64 px + 3 mipmaps)",
                        "fichier_phase2": "__factorio-overhaul__/graphics/levels/furnace/e%02d/furnace-n%02d-icon.png" % (e, n)}
        ent["o_cible"] = round(PRM.o_target(n), 3)
        levels.append(ent)
    man = {
        "famille": "furnace", "lot": "V3 phase 1", "entite": "steel-furnace (2x2, brûleur)",
        "statut": "APERÇU : tailles et shift issus des rendus d'aperçu (échantillons réduits) ; la phase 2 les "
                  "régénère au rendu final. Rien n'est vérifié en moteur réel. Design non validé (verdict du "
                  "Directeur Créatif requis).",
        "interface": "prototypes/levels/common.lua (en tête, version V2b de main) : le fichier "
                     "prototypes/levels/furnace.lua renvoie { dress = function(p, ctx), icons = function(icons, ctx) } ; "
                     "dress est appelée pour les niveaux 2 à 30 ; ctx.level, ctx.epoch, ctx.step (1 = la silhouette "
                     "change, 2 = une pièce s'ajoute) en lecture seule. Champs touchés : animation, "
                     "working_visualisations, water_reflection, drawing_box (GRAPHIC_KEYS) et "
                     "energy_source.smoke (sous-clé à mot visuel « smoke ») : tous permis par la garde inversée ; "
                     "aucun champ de jeu, emprise inchangée",
        "phase2": ["rendu final (256 échantillons après V0b), dimensions HR paires, shift générés ; la qualité "
                   "normale (32 px/tuile) RENDUE à sa taille (D4-2, Q21), pas réduite",
                   "niveau pair : la pièce devient une couche SÉPARÉE ajoutée au rendu impair (bible §1.9, §3.3) ; "
                   "en phase 1 le niveau pair est un rendu complet",
                   "lueur : séparer la lueur de la BOUCHE (working_visualisations, fadeout, feu animé de l'ère) "
                   "de la lueur de DÉCOR (cristaux, anneaux, voyants : always_draw = true), pour que le décor "
                   "reste visible four à l'arrêt",
                   "icône : rendu de la pose de référence (64 px + 3 mipmaps) et numéro de niveau, par icons()"],
        "emprise": {"collision_box": [[-0.7, -0.7], [0.7, 0.7]], "selection_box": [[-0.8, -1], [0.8, 1]],
                    "regle": "inchangées à tous les niveaux (D1-4)"},
        "arborescence_phase2": "graphics/levels/furnace/eNN/ (bible §1.9), hr (64 px/tuile, scale 0,5) + normale (32 px/tuile)",
        "pose_de_reference": "image unique (1 direction, pas de couleur d'équipe)",
        "niveaux": levels,
    }
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    with open(DST, "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, ensure_ascii=False)
    print(DST, sum(1 for x in levels if "absent" not in x), "niveaux")


if __name__ == "__main__":
    main()
