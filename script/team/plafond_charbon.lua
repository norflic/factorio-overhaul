--- Lot PURGE-FER-CHARBON : mesure EN JEU du plafond du combustible (règle pure : shared/team/bilan_charbon.lua). Lecteurs : la migration en
--- bandes (script/team/migration_champ.lua, start_next) et le planificateur (vue de script/team/team.lua, coal_cap). Aucun nom d'objet : le
--- combustible est T.fuel, un consommateur est une entité de la force à brûleur de sa catégorie (chaudières toujours, à pleine charge ; fours et
--- foreuses à brûleur s'ils marchent ou attendent leur combustible), une foreuse du combustible est celle dont la ressource rend T.fuel.
local T = require("shared.team.config")
local Bc = require("shared.team.bilan_charbon")
local Profiler = require("script.core.profiler") -- lot UPS : portées fines « ws: » (recherches sur toute la surface ; mesure seulement)
local RegT = require("script.team.registre_types") -- lot UPS : registre des machines par force et par type (plus de recherche sur toute la surface)

local Cap = {}
Cap.EVERY = 600 -- ticks : un relevé par force au plus toutes les 10 s (parcours de la surface)

function Cap.read(f, surface)
  local memo = f.coal_cap
  if memo and game.tick - memo.tick < Cap.EVERY then return memo end
  local fuel = game.item_prototypes[T.fuel]
  local consumers, drills, measured = {}, {}, {}
  local status = defines.entity_status
  Profiler.fstart("ws:cap")
  local found = RegT.list(surface, f.force, { "boiler", "furnace", "mining-drill" }, "cap") -- lot UPS : registre
  Profiler.fstop("ws:cap")
  for _, e in ipairs(found) do
    local p = e.prototype
    local b = p.burner_prototype
    if fuel and b and b.fuel_categories[fuel.fuel_category] then
      local w = (p.max_energy_usage or 0) * 60 / math.max(b.effectivity or 1, 1e-6)
      if e.type == "boiler" or e.status == status.working or e.status == status.no_fuel then measured[#measured + 1] = w end
      if Bc.consumer_counts(e.type, e.status, status) then consumers[#consumers + 1] = w end -- lot s45 charbon-besoin : nominal
    end
    local t = e.type == "mining-drill" and e.mining_target
    local mp = t and t.valid and t.prototype.mineable_properties
    if mp and mp.products and mp.products[1] and mp.products[1].name == T.fuel and Bc.drill_counts(e.status, status) then
      drills[#drills + 1] = p.mining_speed / math.max(mp.mining_time or 1, 1e-6)
    end
  end
  local fj = fuel and fuel.fuel_value or 0
  memo = Bc.cap(consumers, drills, fj)
  memo.need = Bc.need(Bc.cap(measured, nil, fj).need, memo.need) -- lot s45 charbon-besoin : max(mesure, nominal)
  memo.tick = game.tick
  f.coal_cap = memo
  return memo
end

return Cap
