-- Mod de test (jamais activé en partie normale) : alimentation INVISIBLE pour la vitrine (vitrine.lua).
-- Un poteau sans image, à grande portée, et une source d'énergie sans image : les bâtiments de la vitrine
-- tournent (lumières de travail visibles la nuit) sans aucun poteau dans le cadre des captures.

local EMPTY = { filename = "__core__/graphics/empty.png", priority = "extra-high", width = 1, height = 1, direction_count = 1 }
local FLAGS = { "placeable-neutral", "placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable",
  "not-selectable-in-game", "hidden", "not-upgradable", "not-in-kill-statistics" }

local pole = table.deepcopy(data.raw["electric-pole"]["substation"])
pole.name = "fo-autotest-power-pole"
pole.flags = FLAGS
pole.minable = nil
pole.collision_mask = {}
pole.selection_box = nil
pole.drawing_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }
pole.supply_area_distance = 64
pole.maximum_wire_distance = 1
pole.pictures = EMPTY
pole.connection_points = { pole.connection_points[1] }
pole.water_reflection = nil
pole.draw_copper_wires = false
pole.draw_circuit_wires = false

local src = table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
src.name = "fo-autotest-power-source"
src.flags = FLAGS
src.minable = nil
src.collision_mask = {}
src.selection_box = nil
src.drawing_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }
src.picture = { filename = "__core__/graphics/empty.png", priority = "extra-high", width = 1, height = 1 }
src.gui_mode = "none"
src.water_reflection = nil

data:extend({ pole, src })
