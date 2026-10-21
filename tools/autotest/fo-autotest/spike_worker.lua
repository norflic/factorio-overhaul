--[[
  Spike R&D (scénario "worker") : un corps "character" SANS joueur peut-il travailler comme un joueur ?
    H2 : miner une ressource (mining_state + update_selected_entity), réglé une fois puis à chaque tick ;
    H3 : fabriquer (begin_crafting) ;
    H-B2 : poser un bâtiment par script en consommant l'objet, puis le faire tourner (four alimenté).
  Résultats dans le journal : lignes [FO-SPIKE].
]]

local Spike = {}

local function log_s(msg) log("[FO-SPIKE] " .. msg) end

function Spike.start()
  local s = game.surfaces[1]
  local spawn = game.forces.player.get_spawn_position(s)
  local ore = s.find_entities_filtered({ name = "iron-ore", position = spawn, radius = 250, limit = 1 })[1]
  if not ore then
    log_s("aucun minerai de fer a moins de 250 tuiles du centre")
    return
  end
  local op = ore.position
  local pos = s.find_non_colliding_position("fo-companion", { x = op.x + 1.5, y = op.y }, 4, 0.25)
  local c = s.create_entity({ name = "fo-companion", position = pos, force = "player" })
  global.spike = { char = c, ore = ore, ore_pos = op, t0 = game.tick, phase = "mine_once", mined0 = 0 }
  c.update_selected_entity(op)
  c.mining_state = { mining = true, position = op }
  log_s(string.format("debut : corps en (%.1f,%.1f), minerai en (%.1f,%.1f), selection = %s, portee ressource = %.2f",
    pos.x, pos.y, op.x, op.y, tostring(c.selected and c.selected.name), c.resource_reach_distance))
end

local function count(c, name) return c.get_item_count(name) end

function Spike.on_tick(e)
  local S = global.spike
  if not S or not (S.char and S.char.valid) then return end
  local c, dt = S.char, e.tick - S.t0
  if S.phase == "mine_once" and dt == 300 then
    S.mined_once = count(c, "iron-ore")
    log_s("H2 minage regle UNE fois : " .. S.mined_once .. " minerai en 300 ticks (mining_state.mining = "
      .. tostring(c.mining_state.mining) .. ")")
    S.phase = "mine_every"
  elseif S.phase == "mine_every" then
    if S.ore.valid then
      c.update_selected_entity(S.ore_pos)
      c.mining_state = { mining = true, position = S.ore_pos }
    end
    if dt == 600 then
      local n = count(c, "iron-ore") - (S.mined_once or 0)
      log_s("H2 minage regle A CHAQUE TICK : " .. n .. " minerai en 300 ticks")
      c.mining_state = { mining = false }
      c.insert({ name = "iron-plate", count = 20 })
      local ok, res = pcall(c.begin_crafting, { count = 4, recipe = "iron-gear-wheel" })
      log_s("H3 begin_crafting : ok = " .. tostring(ok) .. ", retour = " .. tostring(res)
        .. ", file = " .. tostring(c.crafting_queue_size))
      S.phase = "craft"
    end
  elseif S.phase == "craft" and dt == 900 then
    log_s("H3 fabrication : " .. count(c, "iron-gear-wheel") .. " engrenages apres 300 ticks (4 demandes)")
    -- H-B2 : pose par script d'un four, consommé dans l'inventaire du corps, puis alimenté.
    c.insert({ name = "stone-furnace", count = 1 })
    c.insert({ name = "coal", count = 10 })
    local p = c.surface.find_non_colliding_position("stone-furnace", c.position, 10, 1)
    local f = p and c.surface.create_entity({ name = "stone-furnace", position = p, force = c.force, raise_built = true })
    if f then
      c.remove_item({ name = "stone-furnace", count = 1 })
      local ore_n = math.min(10, count(c, "iron-ore"))
      if ore_n > 0 then f.insert({ name = "iron-ore", count = c.remove_item({ name = "iron-ore", count = ore_n }) }) end
      f.insert({ name = "coal", count = c.remove_item({ name = "coal", count = 5 }) })
      S.furnace = f
      log_s("H-B2 four pose par script : ok, " .. ore_n .. " minerai et 5 charbon inseres")
    else
      log_s("H-B2 four : pose impossible")
    end
    S.phase = "smelt"
  elseif S.phase == "smelt" and dt == 1800 then
    local f = S.furnace
    local out = f and f.valid and f.get_output_inventory().get_item_count("iron-plate") or -1
    log_s("H-B2 four : " .. out .. " plaques produites en 900 ticks")
    S.phase = "done"
  end
end

return Spike
