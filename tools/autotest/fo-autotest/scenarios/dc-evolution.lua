-- Demande du DC (31/10, 21 h) : « lancez une partie, analysez leur evolution, verifiez par image leur avancee ».
-- La partie du guide dans les reglages du retour du 31/10 (3 factions, 30 ouvriers), 2 h, session AVEC images :
-- banc.py --captures --visuel="--ticks 436000 --timeout 28800" --qui <lot> -- 436000 dc-evolution <source>
-- Toutes les 15 min, pour votre equipe et chaque faction : vue large de la base, gros plan du QG, ligne [FO-EVOL].
-- Les controles du guide (2 factions, 4 ouvriers) ne valent pas ici : le bilan dit seulement si la partie est allee au bout.
local base = require("scenarios/verif_guide_common")(30)
local CHECK, EVERY = 428000, 54000
local TYPES = { "assembling-machine", "furnace", "mining-drill", "lab", "boiler", "generator", "ammo-turret",
  "electric-turret", "container", "transport-belt", "inserter", "electric-pole", "wall" }
local PLATES = { "iron-plate", "copper-plate", "steel-plate", "electronic-circuit", "stone-brick" }
local CORE = { "assembling-machine", "furnace", "mining-drill", "lab", "boiler", "generator", "ammo-turret" }

local function teams()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  return ok and rows or {}
end

--- Centre et zoom de la vue large : boite des batiments de production de la force, plafonnee a 500 tuiles.
local function wide_view(s, force, center)
  local x0, y0, x1, y1
  for _, e in ipairs(s.find_entities_filtered({ force = force, type = CORE })) do
    local p = e.position
    if not x0 then x0, y0, x1, y1 = p.x, p.y, p.x, p.y end
    if p.x < x0 then x0 = p.x end
    if p.y < y0 then y0 = p.y end
    if p.x > x1 then x1 = p.x end
    if p.y > y1 then y1 = p.y end
  end
  if not x0 then return center, 0.5, 0, 0 end
  local w, h = x1 - x0 + 40, y1 - y0 + 40
  local px = math.max(w / 1920, h / 1080) * 32 -- tuiles par 32 px d'ecran
  local zoom = math.max(0.12, math.min(0.6, 1 / px))
  return { x = (x0 + x1) / 2, y = (y0 + y1) / 2 }, zoom, x1 - x0, y1 - y0
end

local function hq_position(s, row)
  local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = row.force, limit = 1 })[1]
  if hq and hq.valid then return hq.position end
  return game.forces.player.get_spawn_position(s)
end

local function checkpoint(ctx, tick)
  local s, p = ctx.surface(), game.connected_players[1]
  local minute = math.floor(tick / 3600)
  for _, row in ipairs(teams()) do
    local force = game.forces[row.force]
    local parts = {}
    for _, t in ipairs(TYPES) do
      parts[#parts + 1] = t .. "=" .. s.count_entities_filtered({ type = t, force = row.force })
    end
    local made = {}
    if force then
      for _, it in ipairs(PLATES) do
        made[#made + 1] = it .. "=" .. force.item_production_statistics.get_input_count(it)
      end
    end
    local center, zoom, w, h = wide_view(s, row.force, hq_position(s, row))
    ctx.log(string.format("[FO-EVOL] minute %d | %s | n=%d emprise=%dx%d | %s | produit %s", minute, row.key, row.n or -1, w, h,
      table.concat(parts, " "), table.concat(made, " ")))
    if p then
      for _, v in ipairs({ { "large", center, zoom }, { "qg", hq_position(s, row), 0.5 } }) do
        game.take_screenshot({ path = string.format("fo-shots/evol-%03dmin-%s-%s.png", minute, row.key, v[1]), player = p,
          surface = s, position = v[2], zoom = v[3], resolution = { 1920, 1080 }, daytime = 0, force_render = true,
          show_entity_info = true, allow_in_replay = true })
      end
    end
  end
end

local init0, tick0 = base.init, base.tick
base.description = "DC : partie de 2 h, 3 factions, 30 ouvriers, captures toutes les 15 min"
base.check_tick = CHECK
base.shots_delay = CHECK + 2000
base.init = function(ctx)
  init0(ctx)
  ctx.check(ctx.remote("factorio-overhaul", "war_setting", "fo-war-factions", 3) == 3, "3 factions")
end
base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick > 0 and e.tick % EVERY == 0 and e.tick <= CHECK then checkpoint(ctx, e.tick) end
end
base.shots = function(ctx, add)
  local s = ctx.surface()
  for _, row in ipairs(teams()) do
    local q = hq_position(s, row)
    add("evol-fin-" .. row.key, q.x, q.y, 0.5, 0)
  end
end
base.finish = function(ctx)
  local poi = ctx.call("points_of_interest")
  ctx.log("factions vivantes a la fin : " .. #poi.factions)
  ctx.check(true, "partie allee jusqu'au controle de 2 h", #poi.factions)
end
return base
