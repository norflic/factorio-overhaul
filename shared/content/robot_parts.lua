--[[
  Lot RB-4 GAMME (1/11) : le SOUS-ENSEMBLE d'X3 que les robots exigent, mis en jeu (PLAN fo-logs/2026-10-31_ROBOTS §2 : « à activer :
  servo, capteur, contrôleur (7), noyau (10, sa recette perd les 20 de calcul fluide, retirés par D-20 (4)), actionneur, module laser
  (12) »). Lua PUR (tests/robot_parts_test.lua) ; prototypes : prototypes/robot_parts.lua.

  Rien n'est inventé : noms, âges, quantités et durées viennent de shared/content/x3.lua (X3.items, X3.recipes), sauf les ÉCARTS
  déclarés ci-dessous (P.DEVIATIONS). Le reste d'X3 (drones, robot de combat, machines pilotées) reste PARQUÉ (Q26). X3 n'est pas
  modifié : « des voies, jamais une porte » ne s'applique pas ici (ces objets n'ont pas d'équivalent X0 : ce sont des pièces neuves).
]]

local X3 = require("shared.content.x3")

local P = {}

-- Objets en jeu (ordre d'affichage), recettes d'X3 qui les fabriquent, catégorie en jeu.
P.ITEMS = { "fo-servo-motor", "fo-optical-sensor", "fo-controller", "fo-guidance-core", "fo-magnetic-actuator", "fo-ndyag-rod", "fo-laser-module" }

-- Écarts à X3, déclarés. `ingredients`/`category`/`time` remplacent ceux d'X3 ; `why_fr` dit pourquoi.
P.OVERRIDES = {
  ["fo-guidance-core"] = {
    ingredients = { { "fo-controller", 1 }, { "fo-motherboard", 1 }, { "fo-optical-sensor", 2 } }, category = "advanced-crafting", time = 20,
    why_fr = "X3 demandait une carte graphique (âge 11 depuis le lot CALCUL) et 20 calculs : le calcul n'est plus stockable (D-20 (4)) ; la carte mère (âge 10) la remplace, la carte graphique ne sert plus qu'aux robots de l'âge 11",
  },
  ["fo-ndyag-rod"] = {
    category = "advanced-crafting",
    why_fr = "catégorie « fo-crystal-pulling » (tirage Czochralski) : sa machine n'est pas posée par ce lot ; l'assembleur la remplace",
  },
}
P.DEVIATIONS = {}
for _, n in ipairs(P.ITEMS) do
  if P.OVERRIDES[n] then P.DEVIATIONS[#P.DEVIATIONS + 1] = { name = n, why_fr = P.OVERRIDES[n].why_fr } end
end

-- Technologies (prérequis tous en jeu : aluminium, circuits imprimés, fonderie de puces, supraconducteurs).
P.TECHS = {
  { name = "fo-servo-mechanisms", epoch = 7, count = 200, time = 30, prerequisites = { "fo-aluminium", "fo-printed-circuits" },
    unlocks = { "fo-servo-motor", "fo-optical-sensor", "fo-controller" } },
  { name = "fo-robot-guidance", epoch = 10, count = 250, time = 30, prerequisites = { "fo-servo-mechanisms", "fo-chip-foundry" },
    unlocks = { "fo-guidance-core" } },
  { name = "fo-magnetic-drive", epoch = 12, count = 300, time = 30, prerequisites = { "fo-robot-guidance", "fo-superconductors" },
    unlocks = { "fo-magnetic-actuator", "fo-ndyag-rod", "fo-laser-module" } },
}

local item_by, recipe_by = {}, {}
for _, it in ipairs(X3.items) do item_by[it.name] = it end
for _, r in ipairs(X3.recipes) do if not recipe_by[r.name] then recipe_by[r.name] = r end end

--- Objet d'X3 (fr, en, stack, epoch).
function P.item(name) return assert(item_by[name], "robot_parts : objet absent d'X3 " .. name) end

--- Recette en jeu pour l'objet `name` : { name, category, time, ingredients, results, prod, epoch } (X3 + écarts).
function P.recipe(name)
  local x = assert(recipe_by[name], "robot_parts : recette absente d'X3 " .. name)
  local o = P.OVERRIDES[name] or {}
  return {
    name = x.name, epoch = x.epoch, category = o.category or x.category, time = o.time or x.time,
    ingredients = o.ingredients or x.ingredients, results = x.results, prod = x.prod == true,
  }
end

--- Les objets d'un âge donné (liste).
function P.of_epoch(k)
  local out = {}
  for _, n in ipairs(P.ITEMS) do if P.item(n).epoch == k then out[#out + 1] = n end end
  return out
end

local present = {}
for _, n in ipairs(P.ITEMS) do present[n] = true end
--- Cet objet est-il mis en jeu par ce lot ?
function P.present(name) return present[name] == true end

return P
