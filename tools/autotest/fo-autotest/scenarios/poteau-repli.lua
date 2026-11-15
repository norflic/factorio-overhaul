--[[
  Lot POTEAU-REPLI (0716) : preuve du repli des poteaux. Partie de plastique-diag (60 min, site du pétrole bâti vers 30-40 min) ; à
  CUT_MIN, pour chaque faction dont une usine chimique a du courant : le poteau électrique le plus proche de l'usine dont le fil est plus
  long que celui du plus petit poteau du jeu est DÉTRUIT (die), sa recette est fermée pour la force et ses objets retirés du coffre du QG
  (« non fabricable faute de matière », comme l'acier absent dans la partie). Attendu : [FO-RECON] « ... pose a sa place » (repli), puis
  l'usine chimique repasse de no_power à working (lignes [FO-PLASTIQUE-DIAG]) ; ligne [FO-POTEAU-REPLI] chaque minute après la coupe.
]]
local base = require("scenarios/plastique-diag")
local MIN = 3600
local CUT_MIN = 42
local TAG = "[FO-POTEAU-REPLI] "
local CUT = {} -- equipe -> { x, y, usine = unit_number, pole = nom }

local function factions()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  local out = {}
  for _, row in ipairs(ok and rows or {}) do if row.key ~= "player" then out[#out + 1] = row end end
  return out
end

local function smallest_wire()
  local w = math.huge
  for _, p in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "electric-pole" } })) do
    if (p.max_wire_distance or 0) > 0 and p.max_wire_distance < w then w = p.max_wire_distance end
  end
  return w
end

local function cut(ctx)
  local s = ctx.surface()
  local wmin = smallest_wire()
  for _, row in ipairs(factions()) do
    local plants = s.find_entities_filtered({ name = "chemical-plant", force = row.force })
    table.sort(plants, function(a, b) return a.unit_number < b.unit_number end)
    local done = false
    for _, pl in ipairs(plants) do
      if done then break end
      if pl.status ~= defines.entity_status.no_power then
        local poles = s.find_entities_filtered({ type = "electric-pole", force = row.force, position = pl.position, radius = 12 })
        local best, bd = nil, math.huge
        for _, p in ipairs(poles) do
          local d = (p.position.x - pl.position.x) ^ 2 + (p.position.y - pl.position.y) ^ 2
          if p.prototype.max_wire_distance > wmin and d < bd then best, bd = p, d end
        end
        if best then
          local name, pos = best.name, best.position
          local item = best.prototype.items_to_place_this[1].name
          local force = game.forces[row.force]
          if force.recipes[item] then force.recipes[item].enabled = false end
          local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = row.force, limit = 1 })[1]
          local removed = 0
          if hq then removed = hq.get_inventory(defines.inventory.chest).remove({ name = item, count = 100000 }) end
          best.die()
          CUT[row.key] = { x = pos.x, y = pos.y, usine = pl.unit_number, pole = name }
          log(TAG .. string.format("coupe equipe=%s poteau %s detruit en (%.1f, %.1f), recette fermee, %d au coffre retires ; usine u%d",
            row.key, name, pos.x, pos.y, removed, pl.unit_number))
          done = true
        end
      end
    end
    if not done then log(TAG .. "coupe equipe=" .. row.key .. " : aucune usine chimique alimentee") end
  end
end

local function watch(ctx, tick)
  local s = ctx.surface()
  for _, row in ipairs(factions()) do
    local c = CUT[row.key]
    if c then
      local pl = nil
      for _, e in ipairs(s.find_entities_filtered({ name = "chemical-plant", force = row.force })) do
        if e.unit_number == c.usine then pl = e end
      end
      local here = s.find_entities_filtered({ type = "electric-pole", force = row.force, position = { c.x, c.y }, radius = 0.5 })[1]
      local st = "-"
      if pl then
        for k, v in pairs(defines.entity_status) do if v == pl.status then st = k end end
      end
      log(TAG .. string.format("minute=%d equipe=%s usine=%s poteau_a_la_place=%s", tick / MIN, row.key, st, here and here.name or "aucun"))
    end
  end
end

local tick0 = base.tick
base.description = "POTEAU-REPLI : plastique-diag, poteau du site detruit a " .. CUT_MIN .. " min sans matiere pour le refaire"
base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick == CUT_MIN * MIN + 30 then
    local ok, err = pcall(cut, ctx)
    if not ok then log(TAG .. "ERREUR " .. tostring(err)) end
  end
  if e.tick > CUT_MIN * MIN and e.tick % MIN == 30 then
    local ok, err = pcall(watch, ctx, e.tick)
    if not ok then log(TAG .. "ERREUR " .. tostring(err)) end
  end
end
return base
