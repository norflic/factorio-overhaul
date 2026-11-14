--[[
  Lot CHARBON-JOUEUR : décompte périodique [FO-CHARBON-EQUIPE], LECTURE SEULE (aucune décision ne le lit). Partie du DC (0.7.114) : votre
  équipe n'avait que 3 à 7 fours actifs sur 50, coffre du QG à 0 charbon ; aucun journal ne donnait d'un coup d'œil, par équipe, les
  machines à combustible posées, en marche et à sec.
  Toutes les M.PERIOD ticks, pour chaque faction vivante (ids triés) : fours à combustible posés / en marche / à sec, foreuses à combustible
  posées / à sec, chaudières posées / alimentées (combustible dans l'entrée). Types et sources d'énergie lus au moteur (aucun nom d'objet).
  Branchement : require("script.team.charbon_compte") dans control.lua (intégrateur).
]]

local Events = require("script.core.events")
local State = require("script.faction.state")

local M = {}

M.PERIOD = 5 * 3600 -- ticks entre deux relevés (5 min)

local function burner_of(e)
  local ok, b = pcall(function() return e.burner end)
  return ok and b or nil
end

local function fuel_count(e)
  local ok, inv = pcall(function() return e.get_fuel_inventory() end)
  if ok and inv and inv.valid then return inv.get_item_count() end
  return 0
end

--- Comptes d'une faction : rend une table de nombres (nil si son QG n'est pas lisible).
function M.counts(f)
  local surface = f and f.hq and f.hq.valid and f.hq.surface
  if not surface then return nil end
  local S = defines.entity_status
  local c = { fours = 0, fours_marche = 0, fours_sec = 0, foreuses = 0, foreuses_sec = 0, chaud = 0, chaud_ok = 0 }
  for _, e in ipairs(surface.find_entities_filtered({ force = f.force, type = { "furnace", "mining-drill", "boiler" } })) do
    if e.valid and burner_of(e) then
      local st = e.status
      local dry = st == S.no_fuel or (fuel_count(e) == 0 and st ~= S.working)
      if e.type == "furnace" then
        c.fours = c.fours + 1
        if st == S.working then c.fours_marche = c.fours_marche + 1 end
        if dry then c.fours_sec = c.fours_sec + 1 end
      elseif e.type == "mining-drill" then
        c.foreuses = c.foreuses + 1
        if dry then c.foreuses_sec = c.foreuses_sec + 1 end
      else
        c.chaud = c.chaud + 1
        if fuel_count(e) > 0 then c.chaud_ok = c.chaud_ok + 1 end
      end
    end
  end
  return c
end

function M.scan(tick)
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    local c = f and M.counts(f)
    if c then
      log(string.format("[FO-CHARBON-EQUIPE] %s min %.0f | fours a combustible %d (en marche %d, a sec %d) | foreuses a combustible %d (a sec %d) | chaudieres %d (alimentees %d)",
        f.key or "player", (tick - (f.started or 0)) / 3600, c.fours, c.fours_marche, c.fours_sec, c.foreuses, c.foreuses_sec, c.chaud, c.chaud_ok))
    end
  end
end

Events.on_nth_tick(M.PERIOD, function(e) M.scan(e.tick) end)

return M
