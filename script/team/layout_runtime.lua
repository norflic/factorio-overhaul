--[[
  Lot LAYOUT, côté exécutant : relevé d'un champ de minerai au moteur, choix de la foreuse électrique la meilleure DÉBLOQUÉE
  (lue aux prototypes : type, taille, rayon de captation, vitesse, sortie), appel de la règle pure shared/team/layout_mine.lua
  et gabarit résultant (M.mine_template). Aucun nom d'objet ici : tout vient des prototypes et des recettes de la force.

  Branché par Build.plan_drills (script/team/build.lua), qui garde l'ancien gabarit en repli quand rien ne tient.
]]

local M = require("shared.team.modules")
local LM = require("shared.team.layout_mine")

local LayoutRT = {}

LayoutRT.MAX_OPTIONS = 3  -- foreuses essayées par lot (les plus rapides débloquées)
LayoutRT.MARGIN = 1       -- tuiles gardées libres entre les foreuses et le bord du lot
LayoutRT.SEE = 4          -- tuiles lues au-delà du lot : minerai voisin qu'une foreuse du bord captera aussi

local function try(fn, ...)
  local ok, v = pcall(fn, ...)
  if ok then return v end
  return nil
end

-- Prototypes de foreuses (cache LOCAL : jamais dans `global`, rempli à la demande).
local protos = nil
local function drill_protos()
  if protos then return protos end
  local list = {}
  local all = game.get_filtered_entity_prototypes({ { filter = "type", type = "mining-drill" } })
  local names = {}
  for n in pairs(all) do names[#names + 1] = n end
  table.sort(names)
  local why = {}
  local function no(r) why[r] = (why[r] or 0) + 1 end
  for _, n in ipairs(names) do
    local p = all[n]
    local sp = M.spec(n)
    local cb = try(function() return p.collision_box end)
    local items = try(function() return p.items_to_place_this end)
    local hidden = try(function() return p.has_flag("hidden") end)
    local electric = try(function() return p.electric_energy_source_prototype end)
    if not sp then no("pas de fiche de gabarit")
    elseif sp.kind ~= "drill" or not sp.usage_kw then no("pas electrique pour le gabarit")
    elseif not cb then no("boite de collision")
    elseif not (items and items[1]) then no("pas d'objet pour la poser")
    elseif hidden then no("cachee")
    elseif not electric then no("pas electrique au prototype")
    else
      local w = math.ceil(cb.right_bottom.x - cb.left_top.x - 1e-6)
      local h = math.ceil(cb.right_bottom.y - cb.left_top.y - 1e-6)
      -- Le vecteur de sortie (`vector_to_place_result`) n'existe QU'A L'ETAPE DATA : au moteur (LuaEntityPrototype) il n'est
      -- pas lisible (constat en jeu, 28/10 : « vitesse, rayon ou sortie illisibles » pour les 30 foreuses). Il vient de la
      -- fiche du gabarit (M.spec), calculee comme l'etape data deplace les points de jeu ; le rayon se lit au prototype.
      local drop = sp.drop
      local speed = try(function() return p.mining_speed end)
      local radius = try(function() return p.mining_drill_radius end) or sp.radius
      -- l'emprise du gabarit (M.spec) et celle du prototype doivent être les mêmes : sinon la foreuse n'est pas posable ici
      if w ~= h or w ~= sp.w then no("emprise differente du gabarit")
      elseif not (speed and speed > 0 and radius and drop) then no("vitesse, rayon ou sortie illisibles")
      else
        list[#list + 1] = { name = n, item = items[1].name, w = w, reach = radius, speed = speed,
          drop = { drop[1] or drop.x, drop[2] or drop.y }, cats = try(function() return p.resource_categories end) or {} }
      end
    end
  end
  local parts = {}
  local keys = {}
  for r in pairs(why) do keys[#keys + 1] = r end
  table.sort(keys)
  for _, r in ipairs(keys) do parts[#parts + 1] = why[r] .. " " .. r end
  LayoutRT.proto_why = #names .. " foreuse(s) au total, ecartees : " .. (#parts > 0 and table.concat(parts, ", ") or "aucune")
  table.sort(list, function(a, b)
    if a.speed ~= b.speed then return a.speed > b.speed end
    return a.name < b.name
  end)
  protos = list
  return list
end

-- Recettes (prototypes) qui donnent un objet, cache LOCAL ; l'objet est « débloqué » pour la force quand l'une est activée.
local recipes_of = {}
local function unlocked(force, item)
  local r = recipes_of[item]
  if not r then
    r = {}
    for n in pairs(game.get_filtered_recipe_prototypes({ { filter = "has-product-item",
        elem_filters = { { filter = "name", name = item } } } })) do
      r[#r + 1] = n
    end
    table.sort(r)
    recipes_of[item] = r
  end
  for _, n in ipairs(r) do
    local rc = force and force.recipes[n]
    if rc and rc.enabled then return true end
  end
  return false
end

--- Foreuses électriques utilisables sur `item` (nom d'une ressource) par la force `fname`, la plus rapide d'abord : leur
--- objet est débloqué (une recette ouverte) ou déjà au coffre (`in_stock(objet) > 0`). Liste de { name, w, reach, speed, drop }.
function LayoutRT.options(fname, item, in_stock)
  local force = game.forces[fname]
  local proto = game.entity_prototypes[item]
  local cat = proto and try(function() return proto.resource_category end)
  local out = {}
  local protos_n, cat_n = 0, 0
  for _, d in ipairs(drill_protos()) do
    protos_n = protos_n + 1
    if cat and d.cats[cat] then
      cat_n = cat_n + 1
      if unlocked(force, d.item) or (in_stock and in_stock(d.item) > 0) then out[#out + 1] = d end
    end
  end
  -- raison d'une liste vide (journal [FO-LAYOUT]) : prototypes retenus, de la bonne catégorie
  LayoutRT.last_why = string.format("%d foreuse(s) electrique(s) retenue(s) aux prototypes, %d de la categorie %s, %d debloquee(s) ; %s",
    protos_n, cat_n, tostring(cat), #out, tostring(LayoutRT.proto_why))
  return out
end

--- Champ de minerai d'un lot : { tiles, blocked, bounds } ou nil. `free(tx, ty)` : tuile utilisable (ni eau, ni falaise,
--- ni bâtiment, ni réservée). Seules les ressources de la même catégorie que `item` comptent (une foreuse ne capte que
--- celles-là). bounds : le lot rogné de MARGIN.
function LayoutRT.field(surface, item, x0, y0, x1, y1, free)
  local proto = game.entity_prototypes[item]
  local cat = proto and try(function() return proto.resource_category end)
  if not cat then return nil end
  local s = LayoutRT.SEE
  local tiles = {}
  local list = surface.find_entities_filtered({ area = { { x0 - s, y0 - s }, { x1 + s, y1 + s } }, type = "resource" })
  for _, e in ipairs(list) do
    if e.valid and e.prototype.resource_category == cat and (e.amount or 0) > 0 then
      tiles[#tiles + 1] = { x = math.floor(e.position.x), y = math.floor(e.position.y), res = e.name, amount = e.amount }
    end
  end
  if #tiles == 0 then return nil end
  table.sort(tiles, function(a, b)
    if a.x ~= b.x then return a.x < b.x end
    return a.y < b.y
  end)
  local m = LayoutRT.MARGIN
  return { tiles = tiles, blocked = function(tx, ty) return not free(tx, ty) end,
    bounds = { x0 = x0 + m, y0 = y0 + m, x1 = x1 - m, y1 = y1 - m } }
end

--- Plan d'une ligne de foreuses `drill` pour le débit `flow` (objets/s) vers `toward` ({x, y} : l'arrivée du tapis). Rend
--- (plan, gabarit) ou (nil, raison). `pole` : poteau du projet (repli : poteau par défaut).
function LayoutRT.plan(field, drill, item, flow, toward, pole)
  local n = math.max(1, math.ceil(flow / drill.speed - 1e-9))
  local plan, why = LM.plan(field, { w = drill.w, reach = drill.reach, speed = drill.speed, drop = drill.drop },
    { mode = "single", max_drills = n, gap = 1, toward = toward, belt_rate = M.BELT_RATE, only = item })
  if not plan then return nil, why end
  local g, gwhy = M.with_pole(pole, M.mine_template, plan, item, drill.name)
  if g and #M.check(g) > 0 and pole and pole ~= M.DEFAULT_POLE then g, gwhy = M.mine_template(plan, item, drill.name) end
  if not g then return nil, gwhy or "gabarit" end
  local errs = M.check(g)
  if #errs > 0 then return nil, "gabarit : " .. tostring(errs[1]) end
  return plan, g
end

return LayoutRT
