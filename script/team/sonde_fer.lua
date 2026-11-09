--[[
  Lot SONDE-FER (9/11, diagnostic LECTURE SEULE, aucune décision ne le lit) : d'où vient le manque de fer des premières minutes ?
  Une ligne [FO-SONDE-FER] par équipe et par minute (jusqu'à Sonde.UNTIL minutes) qui suit le fer de bout en bout :
    foreuses sur le minerai de fer (T.outposts.iron.resource) : posées, par état (en marche, sans combustible, minerai épuisé, sortie
      pleine, autre), thermiques et électriques ;
    fours : posés, en marche, sans combustible, sans entrée, sortie pleine, dont ceux qui fondent la plaque de fer (T.outposts.iron.product) ;
    flux de la minute lus aux statistiques de production de la force (F242 : compteurs, pas moyennes) : minerai sorti, plaques fondues ;
    coffre du QG : minerai, plaques, combustible (T.fuel) ;
  et les plaques DÉPENSÉES par poste sont au journal [FO-FER-SORTIE] (script/team/stock.lua). Aucun nom d'objet en dur : le fer vient de T.
  Compteur de module (jamais dans `global`) : une session rechargée repart de zéro, sans effet sur le jeu.
]]

local T = require("shared.team.config")
local Stock = require("script.team.stock")

local Sonde = {}

Sonde.UNTIL = 25 -- minutes sondées

local LAST = {}  -- équipe -> { minute, ore, plate } (compteurs de la minute d'avant)

local function status_names()
  local names = {}
  for k, v in pairs(defines.entity_status) do names[v] = k end
  return names
end

local function bucket(name)
  if name == "working" or name == "normal" then return "marche" end
  if name == "no_fuel" then return "sans_combustible" end
  if name == "no_minable_resources" then return "epuise" end
  if name == "waiting_for_space_in_destination" or name == "full_output" then return "sortie_pleine" end
  if name == "no_ingredients" then return "sans_entree" end
  return "autre"
end

local function tally(list, names)
  local t = { n = 0, marche = 0, sans_combustible = 0, epuise = 0, sortie_pleine = 0, sans_entree = 0, autre = 0 }
  for _, e in ipairs(list) do
    t.n = t.n + 1
    local b = bucket(names[e.status] or "autre")
    t[b] = t[b] + 1
  end
  return t
end

local function fmt(t)
  return string.format("%d (marche %d, sans combustible %d, epuise %d, sortie pleine %d, sans entree %d, autre %d)", t.n, t.marche,
    t.sans_combustible, t.epuise, t.sortie_pleine, t.sans_entree, t.autre)
end

--- Appelé à chaque pensée de l'équipe `f` ; écrit au plus une ligne par minute de jeu.
function Sonde.tick(f, tick)
  local minute = math.floor(tick / 3600)
  if minute > Sonde.UNTIL or not (f and f.hq and f.hq.valid and f.force) then return end
  local key = f.key or "player"
  local st = LAST[key]
  if st and st.minute == minute then return end
  local force = game.forces[f.force]
  if not force then return end
  local ore, plate = T.outposts.iron.resource, T.outposts.iron.product
  local stats = force.item_production_statistics
  local ore_n, plate_n = stats.get_input_count(ore), stats.get_input_count(plate)
  local prev = st
  LAST[key] = { minute = minute, ore = ore_n, plate = plate_n }
  local surface = f.hq.surface
  local names = status_names()
  local on_iron_th, on_iron_el, other_drills, furn, furn_iron = {}, {}, 0, {}, {}
  for _, e in ipairs(surface.find_entities_filtered({ force = f.force, type = "mining-drill" })) do
    local tgt = e.mining_target
    if tgt and tgt.valid and tgt.name == ore then
      if e.prototype.burner_prototype ~= nil then on_iron_th[#on_iron_th + 1] = e else on_iron_el[#on_iron_el + 1] = e end
    else
      other_drills = other_drills + 1
    end
  end
  for _, e in ipairs(surface.find_entities_filtered({ force = f.force, type = "furnace" })) do
    furn[#furn + 1] = e
    local ok, rec = pcall(function() return e.get_recipe() or e.previous_recipe end)
    if ok and rec and rec.valid ~= false and rec.name == plate then furn_iron[#furn_iron + 1] = e end
  end
  local d_ore = prev and (ore_n - prev.ore) or ore_n
  local d_plate = prev and (plate_n - prev.plate) or plate_n
  log(string.format("[FO-SONDE-FER] %s minute %d : foreuses thermiques sur le fer %s ; electriques %s ; autres foreuses %d ; fours %s dont a plaque de fer %s ; flux de la minute : minerai sorti %d, plaques fondues %d ; coffre : minerai %d, plaques %d, combustible %d",
    key, minute, fmt(tally(on_iron_th, names)), fmt(tally(on_iron_el, names)), other_drills, fmt(tally(furn, names)),
    fmt(tally(furn_iron, names)), d_ore, d_plate, Stock.count(f, ore), Stock.count(f, plate), Stock.count(f, T.fuel)))
end

return Sonde
