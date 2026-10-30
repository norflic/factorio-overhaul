--[[
  Lot PREVISION-CALIB (30/10) : MESURE en moteur réel de la CIBLE d'une vague de pollution (C6 de la prévision suppose que la
  vague va vers le site le plus attirant, émission ÷ distance²). Banc COURT (9 000 ticks), aucune faction, évolution 0.
    - un nid (biter-spawner) en N, tout ennemi retiré à 400 tuiles ;
    - site PROCHE : 2 fours en marche (force du joueur) à 48 tuiles à l'est du nid ;
    - site FORT : 24 fours en marche à 128 tuiles à l'ouest, et une injection de pollution sur leur case (300 toutes les
      60 ticks : un gros pollueur dont le nuage atteint le nid) ;
    - rassemblement fixé à 1 800 ticks.
  On relève l'ordre que le moteur donne au groupe quand il part (LuaUnitGroup.command) et où vont ses membres.
  Journal : [FO-PREV-CIBLE].
]]

local NX, NY = 3200, -3200
local CLEAR = 400

local function furnaces(s, x0, y0, n, force)
  local made = 0
  for i = 0, n - 1 do
    local p = { x0 + (i % 6) * 3, y0 + math.floor(i / 6) * 3 }
    local f = s.create_entity({ name = "stone-furnace", position = p, force = force })
    if f then
      f.insert({ name = "coal", count = 50 })
      f.insert({ name = "iron-ore", count = 50 })
      made = made + 1
    end
  end
  return made
end

local function feed(s, x0, y0, r)
  for _, f in ipairs(s.find_entities_filtered({ position = { x0, y0 }, radius = r, name = "stone-furnace" })) do
    if f.valid then
      f.insert({ name = "coal", count = 5 })
      f.insert({ name = "iron-ore", count = 10 })
      local out = f.get_output_inventory()
      if out then out.clear() end
    end
  end
end

return {
  description = "PREVISION-CALIB : cible d'une vague de pollution (moteur reel)",
  check_tick = 8900,

  init = function(ctx) end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == 60 then
      game.forces.enemy.evolution_factor = 0
      local ug = game.map_settings.unit_group
      ug.min_group_gathering_time = 1800
      ug.max_group_gathering_time = 1800
      ctx.prepare_area(NX - 170, NY - 60, NX + 90, NY + 60, "grass-1")
      for _, en in ipairs(s.find_entities_filtered({ position = { NX, NY }, radius = CLEAR, force = "enemy" })) do
        if en.valid then en.destroy() end
      end
      st.nest = s.create_entity({ name = "biter-spawner", position = { NX, NY }, force = "enemy" }) ~= nil
      st.near = furnaces(s, NX + 48, NY, 2, "player")
      st.far = furnaces(s, NX - 128, NY - 6, 24, "player")
      st.groups, st.seen = {}, {}
      ctx.log(string.format("nid %s en (%d, %d) ; proche : %d four(s) a 48 tuiles a l'est ; fort : %d four(s) a 128 tuiles a l'ouest",
        tostring(st.nest), NX, NY, st.near, st.far))
    end
    if not st.groups then return end
    if e.tick % 60 == 0 and e.tick <= 8400 then
      s.pollute({ NX - 120, NY }, 300)
    end
    if e.tick % 600 == 0 then
      feed(s, NX + 48, NY, 10)
      feed(s, NX - 120, NY, 20)
    end
    if e.tick % 30 == 0 then
      for _, u in ipairs(s.find_entities_filtered({ position = { NX, NY }, radius = 220, type = "unit" })) do
        local g = u.valid and u.unit_group
        if g and g.valid then
          local gn = g.group_number
          local r = st.groups[gn]
          if not r then
            r = { gn = gn, state = -1, n = 0 }
            st.groups[gn] = r
            st.seen[#st.seen + 1] = gn
          end
          if #g.members > r.n then r.n = #g.members end
          if g.state ~= r.state then
            r.state = g.state
            local c = g.command
            local d = c and (c.destination or (c.target and c.target.valid and c.target.position))
            local px, py, m = 0, 0, 0
            for _, mb in ipairs(g.members) do
              if mb.valid then px, py, m = px + mb.position.x, py + mb.position.y, m + 1 end
            end
            ctx.log(string.format("tick %d groupe %d : etat %s, %d membre(s), centre (%.0f, %.0f), ordre %s vers %s rayon %s",
              e.tick, gn, tostring(g.state), m, m > 0 and px / m or 0, m > 0 and py / m or 0, tostring(c and c.type),
              d and string.format("(%.0f, %.0f) [dx %+.0f par rapport au nid]", d.x, d.y, d.x - NX) or "-", tostring(c and c.radius)))
          end
        end
      end
    end
    if e.tick % 1200 == 0 then
      local alive_near = s.count_entities_filtered({ position = { NX + 48, NY }, radius = 10, name = "stone-furnace" })
      local alive_far = s.count_entities_filtered({ position = { NX - 120, NY }, radius = 20, name = "stone-furnace" })
      ctx.log(string.format("tick %d : pollution nid %.1f, fours proches %d, fours forts %d", e.tick, s.get_pollution({ NX, NY }),
        alive_near, alive_far))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.nest and (st.near or 0) == 2 and (st.far or 0) == 24, "nid et fours poses")
    local parts = {}
    for _, gn in ipairs(st.seen or {}) do parts[#parts + 1] = gn .. ":" .. st.groups[gn].n end
    ctx.check(#parts > 0, "au moins un groupe d'attaque forme", table.concat(parts, ", "))
  end,
}
