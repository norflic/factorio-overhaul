"""Lot EXPERIMENTAUX (3/11), palier 2 : COPIE JETABLE du mod pour les essais E-XP1 et E-XP2 (FAISABILITE, scénario greffé xp-corps).

    py -3.9 tools/autotest/xp/jetable.py --dest <dossier neuf, hors du dépôt> [--src <racine du mod>]

1. Recopie la source du mod (par défaut : ce dépôt ou ce worktree) dans --dest, sans .git, .claude, tools/render ni __pycache__
   (mêmes exclusions que fo-autotest.bat). Les PNG hors de git (D-6) sont COPIÉS (exFAT : pas de liens durs).
2. Y ajoute graphics/xp-essai/torse.png : le corps du Cairn (rendu validé, 40 px/tuile, environ 48 × 50 tuiles), rogné, et
   xp_jetable_data.lua (prototypes d'essai), appelé en fin de data-final-fixes.lua :
   - fo-xp-essai-torse : `spider-vehicle` dont le PROTOTYPE porte le torse (graphics_set.animation, direction_count = 1) ; pattes du
     Bourdon (sans image, sans collision) : E-XP1 (la position sort de l'écran : le torse reste-t-il dessiné ?) ;
   - fo-xp-essai-geant : même corps, 4 pattes de géant SANS image (montage ±4, sol ±14, part_length 15) : E-XP2 (marche, arrivée,
     vitesse, rien ne coince).
Le mod livré n'est jamais modifié. Banc : banc.py --captures ... -- 2500 xp-corps "<dest>".
"""
import argparse
import json
import os
import shutil

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
EXCLUS = {".git", ".claude", "__pycache__"}
LOGS = os.path.join("F:" + os.sep, "Factorio.v1.1.91 Modding", "Factorio.v1.1.91", "fo-logs")
SRC_CAIRN = os.path.join(LOGS, "2026-10-31_ROBOTS", "experimentaux", "final", "sprites", "cairn")

DATA = r'''-- COPIE JETABLE (lot EXPERIMENTAUX, palier 2) : prototypes d'essai E-XP1 et E-XP2. Ne jamais livrer.
local T = __TORSE__
local base = data.raw["spider-vehicle"]["fo-bourdon"]
assert(base, "xp-essai : prototype fo-bourdon absent")

local function patte(nom, part, speed)
  local p = table.deepcopy(data.raw["spider-leg"]["fo-bourdon-patte-1"])
  p.name = nom
  p.part_length = part
  p.initial_movement_speed = speed
  p.movement_acceleration = speed * 0.5
  p.movement_based_position_selection_distance = part
  p.graphics_set = {}
  return p
end

local function corps(nom, legs)
  local s = table.deepcopy(base)
  s.name = nom
  s.localised_name = { "entity-name.fo-bourdon" }
  s.graphics_set = {
    render_layer = "air-object", base_render_layer = "object", autopilot_destination_visualisation_render_layer = "object",
    animation = { layers = { { filename = T.filename, width = T.width, height = T.height, scale = T.scale, shift = T.shift,
      direction_count = 1, frame_count = 1, priority = "medium" } } },
  }
  s.spider_engine = { legs = legs, military_target = "spidertron-military-target" }
  s.drawing_box = { { -26, -52 }, { 26, 4 } }
  return s
end

local protos = {}
-- E-XP1 : pattes du Bourdon (4 pattes, ±3, part_length 3,5)
local legs1 = {}
local POSES1 = { { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }
for n = 1, 4 do
  protos[#protos + 1] = patte("fo-xp-essai-patte-" .. n, 3.5, 0.025)
  legs1[n] = { leg = "fo-xp-essai-patte-" .. n, mount_position = { POSES1[n][1] * 0.3, POSES1[n][2] * 0.3 }, ground_position = POSES1[n],
    blocking_legs = { 5 - n } }
end
protos[#protos + 1] = corps("fo-xp-essai-torse", legs1)
-- E-XP2 : pattes de géant (4 pattes, montage ±4, sol ±14, part_length 15)
local legs2 = {}
local POSES2 = { { -14, -14 }, { 14, -14 }, { -14, 14 }, { 14, 14 } }
for n = 1, 4 do
  protos[#protos + 1] = patte("fo-xp-essai-gpatte-" .. n, 15, 0.1)
  legs2[n] = { leg = "fo-xp-essai-gpatte-" .. n, mount_position = { POSES2[n][1] * 4 / 14, POSES2[n][2] * 4 / 14 }, ground_position = POSES2[n],
    blocking_legs = { 5 - n } }
end
protos[#protos + 1] = corps("fo-xp-essai-geant", legs2)
data:extend(protos)
'''


def rogne(a):
    ys, xs = np.nonzero(a[..., 3] > 2)
    return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1], int(xs.min()), int(ys.min())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", required=True)
    ap.add_argument("--src", default=MOD)
    a = ap.parse_args()
    src, dest = os.path.abspath(a.src), os.path.abspath(a.dest)
    if os.path.exists(dest):
        raise SystemExit("--dest existe déjà (copie jetable : dossier NEUF) : %s" % dest)
    if not os.path.exists(os.path.join(src, "info.json")):
        raise SystemExit("source sans info.json : %s" % src)
    render = os.path.join(src, "tools", "render")

    def ignorer(d, noms):
        return [n for n in noms if n in EXCLUS or os.path.join(d, n) == render]

    shutil.copytree(src, dest, ignore=ignorer)
    # torse du Cairn, rogné ; décalage recalculé (tuiles, centre de l'image depuis la position)
    spec = json.load(open(os.path.join(SRC_CAIRN, "spec.json"), encoding="utf-8"))
    info, px = spec["layers"]["main"], float(spec["px"])
    im = np.asarray(Image.open(os.path.join(SRC_CAIRN, info["file"])).convert("RGBA"))
    h, w = im.shape[0], im.shape[1]
    c, x0, y0 = rogne(im)
    sx = info["shift"][0] + ((x0 + c.shape[1] / 2.0) - w / 2.0) / px
    sy = info["shift"][1] + ((y0 + c.shape[0] / 2.0) - h / 2.0) / px
    gdir = os.path.join(dest, "graphics", "xp-essai")
    os.makedirs(gdir, exist_ok=True)
    Image.fromarray(c, "RGBA").save(os.path.join(gdir, "torse.png"))
    torse = ('{ filename = "__factorio-overhaul__/graphics/xp-essai/torse.png", width = %d, height = %d, scale = %.6f, shift = { %.4f, %.4f } }'
             % (c.shape[1], c.shape[0], 32.0 / px, sx, sy))
    with open(os.path.join(dest, "xp_jetable_data.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(DATA.replace("__TORSE__", torse))
    dff = os.path.join(dest, "data-final-fixes.lua")
    with open(dff, "a", encoding="utf-8", newline="\n") as f:
        f.write('\nrequire("xp_jetable_data") -- COPIE JETABLE, lot EXPERIMENTAUX : essais E-XP1, E-XP2\n')
    print("[XP-JETABLE] copie : %s ; torse %d x %d px (%.1f x %.1f tuiles), decalage (%.2f, %.2f)"
          % (dest, c.shape[1], c.shape[0], c.shape[1] / px, c.shape[0] / px, sx, sy))


if __name__ == "__main__":
    main()
