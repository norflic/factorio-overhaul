--[[
  Lot BRIQUES : journal [FO-BRIQUES] (LECTURE SEULE : aucune décision n'en dépend). Une ligne toutes les 5 min par FACTION : la chaîne
  « demande de briques -> tournée de fonte -> fours du QG » lue maillon par maillon (la demande du plan, la tournée avant et après
  le filtre des tournées inutiles, l'état des fours). Sert à désigner le maillon cassé de la fabrication des briques du centre.
]]
local T = require("shared.team.config")
local ChaineMain = require("shared.team.chaine_main")
local Outposts = require("script.faction.outposts")

local L = {}
L.EVERY = 5 * 3600

local function sorted(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local STATUS
local function status_name(s)
  if not STATUS then
    STATUS = {}
    for _, k in ipairs(sorted(defines.entity_status)) do STATUS[defines.entity_status[k]] = k end
  end
  return STATUS[s.status] or tostring(s.status)
end

local PRODUCTS = sorted(T.smelter_inputs)

local function count_smelt(tasks)
  local n, prio = 0, 0
  for _, t in ipairs(tasks or {}) do
    if t.kind == "smelt" then
      n = n + 1
      if (t.prio or 0) > prio then prio = t.prio end
    end
  end
  return n, prio
end

--- `pre` : les tâches du plan avant le filtre ; `plan.tasks` : après.
function L.think(f, view, plan, pre, tick)
  if f.is_player or not f.team then return end
  local st = f.team.briques_log
  if not st then
    st = { t = -L.EVERY }
    f.team.briques_log = st
  end
  if tick - st.t < L.EVERY then return end
  st.t = tick
  local n_pre, p_pre = count_smelt(pre)
  local n_post, p_post = count_smelt(plan.tasks)
  local smelt = {}
  for _, k in ipairs(sorted(plan.smelt)) do smelt[#smelt + 1] = k .. "=" .. tostring(plan.smelt[k]) end
  local worth, why, kept = ChaineMain.smelt_worth({ smelt = plan.smelt, inputs = T.smelter_inputs, stock = view.stock,
    output = view.smelter_output, fuel_low = view.smelter_fuel_low, fuel_stock = view.stock[T.fuel] or 0,
    free = view.smelters_free, loads = view.smelter_loads, collect_min = T.smelt_collect_min })
  local stocks = {}
  for _, p in ipairs(PRODUCTS) do
    stocks[#stocks + 1] = p .. "=" .. (view.stock[p] or 0)
    local inp = T.smelter_inputs[p]
    if inp and view.stock[inp[1]] then stocks[#stocks + 1] = inp[1] .. "=" .. view.stock[inp[1]] end
  end
  local loads = {}
  for _, k in ipairs(sorted(view.smelter_loads)) do loads[#loads + 1] = k .. "=" .. view.smelter_loads[k] end
  local fours = {}
  for _, s in ipairs(Outposts.smelters(f)) do
    local src = s.get_inventory(defines.inventory.furnace_source)[1]
    local out = s.get_output_inventory()
    local fuel = s.get_fuel_inventory()
    local o = {}
    for _, name in ipairs(PRODUCTS) do
      local n = out.get_item_count(name)
      if n > 0 then o[#o + 1] = name .. n end
    end
    fours[#fours + 1] = string.format("[%s %s fuel%d %s]", (src and src.valid_for_read) and (src.name .. src.count) or "vide",
      table.concat(o, "+"), fuel and fuel.get_item_count() or 0, status_name(s))
  end
  log(string.format("[FO-BRIQUES] %s a %.1f min : stock libre {%s} | demande plan {%s} | tournees avant filtre %d (prio %d), apres %d (prio %d), "
    .. "ouverte au tableau %s | filtre utile=%s raison=%s gardes {%s} | fours libres %s, a completer {%s}, sortie %s, charbon bas %s | %d four(s) : %s",
    f.key or "?", tick / 3600, table.concat(stocks, " "), table.concat(smelt, " "), n_pre, p_pre, n_post, p_post,
    tostring(view.smelter_task), tostring(worth), tostring(why), table.concat(sorted(kept), " "), tostring(view.smelters_free),
    table.concat(loads, " "), tostring(view.smelter_output), tostring(view.smelter_fuel_low), #Outposts.smelters(f), table.concat(fours, " ")))
end

return L
