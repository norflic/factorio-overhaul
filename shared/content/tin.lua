--[[
  Lot AMELIO-RESSOURCES, piste ÉTAIN (30/10) : la chaîne A d'X3 (« imprimer les puces », âge 4) EN JEU : cassitérite →
  plaque d'étain ; éthylène (lot AMELIO-CRAFTS) + huile lourde → résine époxy ; cuivre + verre (AMELIO-CRAFTS) + résine →
  stratifié cuivré ; imprimante de circuits ; stratifié + étain + acide sulfurique → CARTE DE CIRCUIT IMPRIMÉ ; carte +
  circuits + plastique + câble → CIRCUIT AVANCÉ (variante d'X3 : 2 circuits en 6 s, la voie vanilla reste).
  Lua PUR (tests/tin_test.lua) ; prototypes : prototypes/tin.lua ; gisement : shared/content/world.lua (cassiterite).

  Rien n'est inventé : noms, recettes, bâtiment et technologie viennent de shared/content/x3.lua (proposition X3, règle
  « des voies, jamais une porte » : aucune recette vanilla ni d'X0 n'est touchée, la cassitérite n'est jamais obligatoire).
  Dépend du lot AMELIO-CRAFTS (verre, éthylène, technologies fo-glassworks et fo-steam-cracking, fenêtre de packs).
]]

local X3 = require("shared.content.x3")
local C = require("shared.content.crafts")

local Sn = {}

Sn.ORE = "fo-cassiterite"
Sn.ITEMS = { "fo-tin-plate", "fo-copper-clad-laminate", "fo-printed-circuit-board" }
Sn.FLUIDS = { "fo-epoxy-resin" }
-- Recettes d'X3 mises en jeu (ordre d'affichage). variant : la recette rend un objet vanilla par une autre voie.
Sn.RECIPES = {
  { name = "fo-tin-plate" },
  { name = "fo-epoxy-resin" },
  { name = "fo-copper-clad-laminate" },
  { name = "fo-printed-circuit-board" },
  { name = "fo-pcb-advanced-circuit", variant = "advanced-circuit" },
}
-- Bâtiment : imprimante de circuits (X3 : 3 × 3, 300 kW, une entrée de fluide ; « copie teintée d'assembling-machine-2 »).
Sn.BUILDINGS = {
  { name = "fo-circuit-printer", copy = "assembling-machine-2", side = 3, tint = { r = 0.62, g = 0.92, b = 0.70 } },
}
-- Technologie d'X3 (âge 4) ; unités : le compte des technologies de l'âge 4 du lot AMELIO-CRAFTS (200), règle QX9 par
-- C.tech_count ; prérequis : ceux d'X3 en jeu + la verrerie (verre du stratifié) + les circuits avancés vanilla.
Sn.TECHS = {
  { name = "fo-printed-circuits", x3 = "fo-printed-circuits", epoch = 4, count = 200, time = 30,
    prerequisites = { "fo-steam-cracking", "fo-glassworks", "advanced-electronics" },
    unlocks = { "fo-tin-plate", "fo-epoxy-resin", "fo-copper-clad-laminate", "fo-circuit-printer", "fo-printed-circuit-board",
                "fo-pcb-advanced-circuit" } },
}

---------------------------------------------------------------------------------------------------
-- Index d'X3
---------------------------------------------------------------------------------------------------
local item_by, recipe_by, building_by, tech_by = {}, {}, {}, {}
for _, it in ipairs(X3.items) do item_by[it.name] = it end
for _, r in ipairs(X3.recipes) do if not recipe_by[r.name] then recipe_by[r.name] = r end end
for _, b in ipairs(X3.buildings) do building_by[b.name] = b end
for _, t in ipairs(X3.technologies) do tech_by[t.name] = t end
function Sn.x3_item(n) return item_by[n] end
function Sn.x3_recipe(n) return assert(recipe_by[n], "étain : recette X3 absente " .. n) end
function Sn.x3_building(n) return assert(building_by[n], "étain : bâtiment X3 absent " .. n) end
function Sn.x3_tech(n) return tech_by[n] end
function Sn.x3_resource(n)
  for _, r in ipairs(X3.resources) do if r.name == n then return r end end
end

local IN_GAME = { [Sn.ORE] = true }
for _, n in ipairs(Sn.ITEMS) do IN_GAME[n] = true end
for _, n in ipairs(Sn.FLUIDS) do IN_GAME[n] = true end
for _, b in ipairs(Sn.BUILDINGS) do IN_GAME[b.name] = true end

--- En jeu avec ce lot (et CRAFTS, X1) ?
function Sn.present(name)
  return IN_GAME[name] == true or C.present(name)
end

--- Est-ce un fluide (X3, puis CRAFTS / X0 par la règle de C) ?
function Sn.is_fluid(name)
  local it = item_by[name]
  if it then return it.type == "fluid" end
  return nil
end

--- Unités et packs de la technologie (règles du lot AMELIO-CRAFTS).
function Sn.tech_count(t) return C.tech_count(t) end
function Sn.packs(k) return C.packs(k) end

--- Bilan : plaques d'étain et galènes... par circuit avancé de la variante (une fabrication de chaque à la proportion).
function Sn.per_advanced_circuit()
  local pcb = Sn.x3_recipe("fo-printed-circuit-board")
  local adv = Sn.x3_recipe("fo-pcb-advanced-circuit")
  local tin = Sn.x3_recipe("fo-tin-plate")
  local pcb_per_adv = adv.ingredients[1][2] / adv.results[1][2]
  local tin_per_pcb = 0
  for _, i in ipairs(pcb.ingredients) do if i[1] == "fo-tin-plate" then tin_per_pcb = i[2] / pcb.results[1][2] end end
  local cass_per_tin = tin.ingredients[1][2] / tin.results[1][2]
  return { pcb = pcb_per_adv, tin = pcb_per_adv * tin_per_pcb, cassiterite = pcb_per_adv * tin_per_pcb * cass_per_tin }
end

return Sn
