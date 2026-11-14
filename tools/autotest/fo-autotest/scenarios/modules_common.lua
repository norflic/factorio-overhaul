-- Lot MODULES-0716 (14/11) : la partie des jalons (30 min, 5 équipes, réglages du DC) où les technologies des modules du
-- PALIER 1 sont données à toutes les équipes à la minute TECH_MIN (une partie de 30 min ne les atteint pas d'elle-même :
-- DC 2 h 30 en 0.7.102, première techno de module vers 85 min). Les technologies sont LUES dans les prototypes (celles qui
-- débloquent une recette dont le produit est un module de palier 1, et leurs prérequis) : aucun nom en dur.
-- Chaque minute après TECH_MIN, une ligne [FO-MODULES-BANC] par équipe : modules fabriqués (statistiques de la force), modules
-- au coffre de l'équipe, modules POSÉS dans des machines (inventaires de modules des fours, assembleurs et foreuses), machines
-- équipées. Lecture : grep « FO-MODULES » dans benchmark.log.
-- KIT (partie-modules-kit-30) : à la même minute, le coffre de chaque équipe reçoit KIT_N fois les ingrédients de chaque recette de
-- module du palier 1 (lus dans les recettes) : la chaîne du plastique (pétrole) n'est pas atteinte en 30 min, le kit prouve le reste
-- (souhait de fabrication -> fabrication -> pose par un PNJ).
return function(KIT_N)
local base = require("scenarios/jalons_common")(30)
local MIN = 3600
local TECH_MIN = 8
local TAG = "[FO-MODULES-BANC] "

local function module_names()
  local out = {}
  local protos = game.get_filtered_item_prototypes({ { filter = "type", type = "module" } })
  for name, p in pairs(protos) do out[name] = p end
  return out
end

local function techs_to_give()
  local mods = module_names()
  local want, list = {}, {}
  local function add(t)
    if want[t.name] then return end
    want[t.name] = true
    for _, pre in pairs(t.prerequisites) do add(pre) end
    list[#list + 1] = t.name
  end
  local names = {}
  for name in pairs(game.technology_prototypes) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local t = game.technology_prototypes[name]
    for _, e in ipairs(t.effects or {}) do
      if e.type == "unlock-recipe" then
        local r = game.recipe_prototypes[e.recipe]
        for _, pr in ipairs(r and r.products or {}) do
          local m = mods[pr.name]
          if m and (m.tier or 1) <= 1 then add(t) end
        end
      end
    end
  end
  return list
end

local function hq_of(s, force)
  return s.find_entities_filtered({ name = "fo-faction-hq", force = force, limit = 1 })[1]
    or s.find_entities_filtered({ name = "fo-team-chest", force = force, limit = 1 })[1]
end

local function kit_items()
  local mods = module_names()
  local need, names = {}, {}
  local rnames = {}
  for name in pairs(game.recipe_prototypes) do rnames[#rnames + 1] = name end
  table.sort(rnames)
  for _, rn in ipairs(rnames) do
    local r = game.recipe_prototypes[rn]
    local m = r.main_product and mods[r.main_product.name]
    if m and (m.tier or 1) <= 1 and not r.hidden then
      for _, ing in ipairs(r.ingredients) do
        if ing.type == "item" then
          if not need[ing.name] then names[#names + 1] = ing.name end
          need[ing.name] = (need[ing.name] or 0) + ing.amount * KIT_N
        end
      end
    end
  end
  table.sort(names)
  return need, names
end

local function give(ctx)
  local list = techs_to_give()
  if KIT_N and KIT_N > 0 then
    local need, names = kit_items()
    local s = ctx.surface()
    for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
      local hq = row.force and hq_of(s, row.force)
      local inv = hq and hq.get_inventory(defines.inventory.chest)
      local put = {}
      for _, nm in ipairs(names) do
        local n = inv and inv.insert({ name = nm, count = need[nm] }) or 0
        put[#put + 1] = nm .. "=" .. n
      end
      log(TAG .. "kit equipe=" .. tostring(row.key) .. " : " .. table.concat(put, ","))
    end
  end
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    local force = row.force and game.forces[row.force]
    if force then
      for _, name in ipairs(list) do
        local t = force.technologies[name]
        if t then t.researched = true end
      end
    end
  end
  log(TAG .. "technologies donnees a toutes les equipes : " .. table.concat(list, ","))
end

local function bilan(ctx, tick)
  local s = ctx.surface()
  local mods = module_names()
  local mnames = {}
  for name in pairs(mods) do mnames[#mnames + 1] = name end
  table.sort(mnames)
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    local force = row.force and game.forces[row.force]
    if force then
      local made, posed, machines, eligible = 0, 0, 0, 0
      local st = force.item_production_statistics
      for _, nm in ipairs(mnames) do made = made + st.get_input_count(nm) end
      for _, e in ipairs(s.find_entities_filtered({ force = force, type = { "assembling-machine", "furnace", "mining-drill" } })) do
        local inv = e.get_module_inventory()
        if inv and #inv > 0 then
          eligible = eligible + 1
          local n = 0
          for _, nm in ipairs(mnames) do n = n + inv.get_item_count(nm) end
          if n > 0 then machines = machines + 1 posed = posed + n end
        end
      end
      local chest = 0
      for _, e in ipairs(s.find_entities_filtered({ force = force, type = { "container", "logistic-container" } })) do
        local inv = e.get_inventory(defines.inventory.chest)
        if inv then
          for _, nm in ipairs(mnames) do chest = chest + inv.get_item_count(nm) end
        end
      end
      log(TAG .. string.format("minute=%d equipe=%s modules_faits=%d modules_poses=%d machines_equipees=%d machines_a_emplacements=%d coffre=%d",
        tick / MIN, tostring(row.key), made, posed, machines, eligible, chest))
    end
  end
end

local tick0 = base.tick
base.description = "MODULES" .. ((KIT_N or 0) > 0 and (" (kit x" .. KIT_N .. ")") or "") .. " : partie des jalons 30 min, technologies des modules du palier 1 donnees a " .. TECH_MIN .. " min, [FO-MODULES-BANC] chaque minute"
base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick == TECH_MIN * MIN then
    local ok, err = pcall(give, ctx)
    if not ok then log(TAG .. "ERREUR " .. tostring(err)) end
  end
  if e.tick > TECH_MIN * MIN and e.tick % MIN == 0 then
    local ok, err = pcall(bilan, ctx, e.tick)
    if not ok then log(TAG .. "ERREUR " .. tostring(err)) end
  end
end
return base
end
