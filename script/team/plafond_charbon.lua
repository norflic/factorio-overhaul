--- Lot PURGE-FER-CHARBON : mesure EN JEU du plafond du combustible (règle pure : shared/team/bilan_charbon.lua). Lecteurs : la migration en
--- bandes (script/team/migration_champ.lua, start_next) et le planificateur (vue de script/team/team.lua, coal_cap). Aucun nom d'objet : le
--- combustible est T.fuel, un consommateur est une entité de la force à brûleur de sa catégorie, une foreuse du combustible est celle dont la
--- ressource rend T.fuel.
--- Lot charbon-dim (14/11, P0) : DIMENSIONNEMENT NOMINAL (Bc.dim). Besoin = toutes les machines à combustible POSÉES à pleine puissance de
--- prototype (rendement du brûleur compris), quel que soit leur état, + Bc.MARGE ; offre = débit nominal de toutes les foreuses posées sur le
--- combustible (Bc.drill_nominal : hors gisement épuisé et arrêt par script ou circuit). La mesure d'avant (machines en marche, foreuses en
--- marche) reste au relevé pour le journal [FO-CHARBON-DIM] (comparaison), elle ne décide plus.
local T = require("shared.team.config")
local Bc = require("shared.team.bilan_charbon")
local Profiler = require("script.core.profiler") -- lot UPS : portées fines « ws: » (recherches sur toute la surface ; mesure seulement)
local RegT = require("script.team.registre_types") -- lot UPS : registre des machines par force et par type (plus de recherche sur toute la surface)

local Cap = {}
Cap.EVERY = 600 -- ticks : un relevé par force au plus toutes les 10 s (parcours de la surface)
Cap.LOG_EVERY = 3600 -- ticks : une ligne [FO-CHARBON-DIM] par équipe au plus par minute, et à chaque changement de décision
Cap.TYPES = { "assembling-machine", "boiler", "furnace", "mining-drill" } -- types du moteur tenus par le registre qui peuvent brûler

function Cap.read(f, surface)
  local memo = f.coal_cap
  if memo and game.tick - memo.tick < Cap.EVERY then return memo end
  local fuel = game.item_prototypes[T.fuel]
  local consumers, drills, live_w, live_drills = {}, {}, {}, {}
  local status = defines.entity_status
  Profiler.fstart("ws:cap")
  local found = RegT.list(surface, f.force, Cap.TYPES, "cap") -- lot UPS : registre
  Profiler.fstop("ws:cap")
  for _, e in ipairs(found) do
    local p = e.prototype
    local b = p.burner_prototype
    if fuel and b and b.fuel_categories[fuel.fuel_category] then
      local w = (p.max_energy_usage or 0) * 60 / math.max(b.effectivity or 1, 1e-6)
      consumers[#consumers + 1] = w -- lot charbon-dim : toute machine posée, à pleine puissance
      if Bc.consumer_counts(e.type, e.status, status) then live_w[#live_w + 1] = w end -- (relevé d'avant, journal seulement)
    end
    local t = e.type == "mining-drill" and e.mining_target
    local mp = t and t.valid and t.prototype.mineable_properties
    if mp and mp.products and mp.products[1] and mp.products[1].name == T.fuel then
      local rate = p.mining_speed / math.max(mp.mining_time or 1, 1e-6)
      if Bc.drill_nominal(e.status, status) then drills[#drills + 1] = rate end -- lot charbon-dim : offre nominale
      if Bc.drill_counts(e.status, status) then live_drills[#live_drills + 1] = rate end -- (relevé d'avant, journal seulement)
    end
  end
  local fj = fuel and fuel.fuel_value or 0
  local old = memo
  memo = Bc.dim(consumers, drills, fj)
  local live = Bc.cap(live_w, live_drills, fj)
  memo.live_need, memo.live_capacity = live.need, live.capacity
  memo.n_consumers, memo.n_drills = #consumers, #drills
  memo.tick = game.tick
  memo.decision = old and old.decision or nil
  memo.logged_at = old and old.logged_at or nil
  memo.logged_decision = old and old.logged_decision or nil
  f.coal_cap = memo
  return memo
end

--- Décision du planificateur (plan.coal_dim, shared/team/planner.lua) notée au relevé de l'équipe ; une ligne [FO-CHARBON-DIM] à chaque
--- changement de décision, et au plus une par Cap.LOG_EVERY sinon.
function Cap.note(f, decision, tick)
  local memo = f.coal_cap
  if not memo then return end
  memo.decision = decision
  if memo.logged_decision == decision and memo.logged_at and tick - memo.logged_at < Cap.LOG_EVERY then return end
  memo.logged_decision, memo.logged_at = decision, tick
  log(string.format("[FO-CHARBON-DIM] %s ; mesure d'avant : besoin %.3f/s, offre %.3f/s", Bc.line(f.key, memo, math.floor(tick / 3600), decision),
    memo.live_need or 0, memo.live_capacity or 0))
end

return Cap
