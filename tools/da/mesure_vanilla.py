# -*- coding: utf-8 -*-
"""
Mesure des bâtiments vanilla 1.1.91 (sprites hr, image 0, pose E pour les tourelles).

    python mesure_vanilla.py <dossier des dumps --dump-proto> <racine>/data <sortie.json> [dossier d'aperçus]

Les dumps viennent de : lua5.2 tests/datastage/harness.lua "<racine>/data" . --dump-proto <type>/<nom>
(29 prototypes, lus le 22/10/2026). Couches et décalages exacts du Lua vanilla : rien n'est recopié à la main.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import da_lib as D  # noqa: E402

DUMPS, DATA, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
PREV = sys.argv[4] if len(sys.argv) > 4 else None


def load(n):
    return D.parse_dump(open(os.path.join(DUMPS, n + ".txt"), encoding="utf-8", errors="replace").read())


def wv(d, i, key="animation", kind=None, root=None):
    src = (root or d).get("working_visualisations") or []
    if i < len(src) and key in src[i]:
        return (src[i][key], None, kind)
    return (None, None, None)


def fire_kind(node):
    return node


# (nom, dump, emprise (l, h), palier vanilla, groupe, fonction -> liste de (noeud, idx, kind forcé))
ENT = [
    ("steel-chest", "container_steel-chest", (1, 1), 1, "basique", lambda d: [(d["picture"], 0, None)]),
    ("stone-furnace", "furnace_stone-furnace", (2, 2), 1, "basique",
     lambda d: [(d["animation"], 0, None), wv(d, 0, kind="glow")]),
    ("boiler", "boiler_boiler", (3, 2), 1, "basique",
     lambda d: [(d["structure"], 0, None), (d["fire"], 0, "glow"), (d["fire_glow"], 0, "light")]),
    ("steam-engine", "generator_steam-engine", (5, 3), 1, "basique", lambda d: [(d["horizontal_animation"], 0, None)]),
    ("assembling-machine-1", "assembling-machine_assembling-machine-1", (3, 3), 1, "basique",
     lambda d: [(d["animation"], 0, None)]),
    ("gun-turret", "ammo-turret_gun-turret", (2, 2), 1, "basique",
     lambda d: [(d["base_picture"], 0, None), (d["prepared_animation"], "E", None)]),
    ("electric-mining-drill", "mining-drill_electric-mining-drill", (3, 3), 1, "basique",
     lambda d: [(d["graphics_set"]["animation"], 0, None),
                (d["graphics_set"]["working_visualisations"][2]["north_animation"], 0, None),
                (d["graphics_set"]["working_visualisations"][7]["north_animation"], 0, "light")]),
    ("radar", "radar_radar", (3, 3), 1, "avance", lambda d: [(d["pictures"], 0, None)]),
    ("lab", "lab_lab", (3, 3), 1, "avance", lambda d: [(d["on_animation"], 0, None)]),
    ("assembling-machine-2", "assembling-machine_assembling-machine-2", (3, 3), 2, "basique",
     lambda d: [(d["animation"], 0, None)]),
    ("steel-furnace", "furnace_steel-furnace", (2, 2), 2, "basique",
     lambda d: [(d["animation"], 0, None), wv(d, 0, kind="glow"), wv(d, 2, kind="light")]),
    ("pumpjack", "mining-drill_pumpjack", (3, 3), 2, "basique",
     lambda d: [(d["base_picture"], 0, None), (d["animations"], 0, None)]),
    ("storage-tank", "storage-tank_storage-tank", (3, 3), 2, "basique",
     lambda d: [(d["pictures"]["picture"], 0, None)]),
    ("oil-refinery", "assembling-machine_oil-refinery", (5, 5), 2, "avance",
     lambda d: [(d["animation"], 0, None), wv(d, 0, kind="glow"), wv(d, 1, "north_animation", "light")]),
    ("chemical-plant", "assembling-machine_chemical-plant", (3, 3), 2, "avance",
     lambda d: [(d["animation"], 0, None), wv(d, 0, "north_animation"), wv(d, 1, "north_animation")]),
    ("laser-turret", "electric-turret_laser-turret", (2, 2), 2, "avance",
     lambda d: [(d["base_picture"], 0, None), (d["prepared_animation"], "E", None),
                (d["energy_glow_animation"], "E", "light")]),
    ("accumulator", "accumulator_accumulator", (2, 2), 2, "avance", lambda d: [(d["charge_animation"], 0, None)]),
    ("substation", "electric-pole_substation", (2, 2), 3, "avance", lambda d: [(d["pictures"], 0, None)]),
    ("assembling-machine-3", "assembling-machine_assembling-machine-3", (3, 3), 3, "avance",
     lambda d: [(d["animation"], 0, None)]),
    ("electric-furnace", "furnace_electric-furnace", (3, 3), 3, "avance",
     lambda d: [(d["animation"], 0, None), wv(d, 0), wv(d, 2), wv(d, 3)]),
    ("beacon", "beacon_beacon", (3, 3), 3, "avance",
     lambda d: [(d["graphics_set"]["animation_list"][0]["animation"], 0, None),
                (d["graphics_set"]["animation_list"][1]["animation"], 0, None),
                (d["graphics_set"]["animation_list"][2]["animation"], 0, "light")]),
    ("roboport", "roboport_roboport", (4, 4), 3, "avance",
     lambda d: [(d["base"], 0, None), (d["base_patch"], 0, None), (d["door_animation_up"], 0, None),
                (d["door_animation_down"], 0, None), (d["base_animation"], 0, None)]),
    ("centrifuge", "assembling-machine_centrifuge", (3, 3), 3, "avance",
     lambda d: [(d["idle_animation"], 0, None), wv(d, 1, kind="light")]),
    ("steam-turbine", "generator_steam-turbine", (5, 3), 3, "avance", lambda d: [(d["horizontal_animation"], 0, None)]),
    ("heat-exchanger", "boiler_heat-exchanger", (3, 2), 3, "avance", lambda d: [(d["structure"], 0, None)]),
    ("artillery-turret", "artillery-turret_artillery-turret", (3, 3), 3, "avance",
     lambda d: [(d["base_picture"], 0, None), (d["cannon_base_pictures"], "E", None),
                (d["cannon_barrel_pictures"], "E", None)]),
    ("nuclear-reactor", "reactor_nuclear-reactor", (5, 5), 3, "avance",
     lambda d: [(d["lower_layer_picture"], 0, None), (d["picture"], 0, None),
                (d["working_light_picture"], 0, "light")]),
    ("rocket-silo", "rocket-silo_rocket-silo", (9, 9), 3, "avance",
     lambda d: [(d["hole_sprite"], 0, None), (d["door_back_sprite"], 0, None), (d["door_front_sprite"], 0, None),
                (d["base_day_sprite"], 0, None), (d["base_front_sprite"], 0, None),
                (d["red_lights_back_sprites"], 0, "glow"), (d["red_lights_front_sprites"], 0, "glow")]),
]


def save_preview(comp, path, maxw=None):
    b = comp["body"]
    im = Image.fromarray((np.clip(b, 0, 1) * 255).astype(np.uint8), "RGBA")
    bg = Image.new("RGBA", im.size, (40, 40, 40, 255))
    bg.alpha_composite(im)
    bg.convert("RGB").save(path)


results = []
for name, dump, side, tier, group, fn in ENT:
    d = load(dump)
    nodes = [n for n in fn(d) if n[0] is not None]
    layers = D.vanilla_layers(nodes, DATA)
    comp = D.compose(layers)
    r = D.measure(comp, side, name)
    r["palier_vanilla"] = tier
    r["groupe"] = group
    r["couches"] = [(l["file"], l["kind"]) for l in layers]
    results.append(r)
    if PREV:
        save_preview(comp, os.path.join(PREV, "vanilla-%s.png" % name))
    print("%-22s %-5s lap=%5.1f cont=%.3f pieces/t2=%5.1f cl7=%5.1f S=%.2f sat=%.3f satHL=%.3f O=%.2f fill=%.2f mass=%.2f massive=%.2f grain=%.2f creux=%.3f"
          % (name, r["cote_emprise"], r["laplacien_moyen"], r["part_contours"], r["petites_pieces_par_tuile2"],
             r["contraste_local_7px"], r["saturation_moyenne"], r["part_saturee"], r["part_saturee_hors_lumineux"],
             r["O_depassement_haut"], r["remplissage_emprise"], r["masse_par_tuile_emprise"], r["part_massive"],
             r["grain_surfaces"], r["part_creux_sombres"]))

json.dump(results, open(OUT, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
