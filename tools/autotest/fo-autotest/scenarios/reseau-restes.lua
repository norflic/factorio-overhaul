--[[
  Lot RESEAU-VIVANT : EXPÉRIENCE (29/10) sur ce qui reste d'une chaudière détruite et empêche de poser son fantôme. Mesuré dans
  l'essai court (20261020, 16 min) : fantôme de chaudière refusé « occupe » pendant 11 min, emprise = boiler-remnants (neutre) et
  deux item-on-ground (neutres), le projet « bloque ». Question posée au moteur : LEQUEL des trois bloque can_place_entity
  (build_check_type par défaut et ghost_revive), un fantôme, et une vraie chaudière posée par create_entity ?
  Lancement : banc.py ... -- 300 reseau-restes <source>. Lignes : [FO-RESEAU-RESTES].
]]
local X, Y = 216.5, 216.5
local TAG = "[FO-RESEAU-RESTES] "

local function footprint(x, y) return { { x - 1.6, y - 1.1 }, { x + 1.6, y + 1.1 } } end

local function can(s, check)
  return s.can_place_entity({ name = "boiler", position = { X, Y }, direction = defines.direction.north, force = "player",
    build_check_type = check })
end

local function snapshot(ctx, label)
  local s = ctx.surface()
  local names = {}
  for _, e in ipairs(s.find_entities_filtered({ area = footprint(X, Y) })) do names[#names + 1] = e.type .. ":" .. e.name end
  table.sort(names)
  local d = can(s, nil)
  local g = can(s, defines.build_check_type.ghost_revive)
  local m = can(s, defines.build_check_type.manual)
  ctx.log(TAG .. string.format("%s | emprise : %s | can_place defaut=%s ghost_revive=%s manual=%s", label, table.concat(names, " "),
    tostring(d), tostring(g), tostring(m)))
  return { default = d, ghost = g, manual = m }
end

return {
  description = "RESEAU-VIVANT : restes d'une chaudiere detruite (remnants, items) contre can_place_entity et create_entity",
  base = nil,
  check_tick = 280,

  init = function(ctx)
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    ctx.prepare_area(X - 16, Y - 16, X + 16, Y + 16, "grass-1")
    ctx.state().r = {}
  end,

  tick = function(ctx, e)
    local s = ctx.surface()
    local st = ctx.state()
    if e.tick == 30 then
      local b = s.create_entity({ name = "boiler", position = { X, Y }, direction = defines.direction.north, force = "player" })
      ctx.check(b ~= nil, "chaudiere posee")
      if b then b.insert({ name = "coal", count = 5 }) end
      st.r.avant = snapshot(ctx, "chaudiere vivante")
    elseif e.tick == 60 then
      local b = s.find_entities_filtered({ name = "boiler", position = { X, Y }, radius = 1, limit = 1 })[1]
      if b then b.die() end
    elseif e.tick == 120 then
      st.r.mort = snapshot(ctx, "apres die()")
    elseif e.tick == 140 then
      -- ghost sur les restes
      local gh = s.create_entity({ name = "entity-ghost", inner_name = "boiler", position = { X, Y }, direction = defines.direction.north,
        force = "player", expires = false })
      ctx.log(TAG .. "fantome cree sur les restes : " .. tostring(gh ~= nil))
      st.r.fantome_restes = gh ~= nil
      if gh then gh.destroy() end
    elseif e.tick == 160 then
      -- retrait des objets au sol seulement
      local n = 0
      for _, it in ipairs(s.find_entities_filtered({ area = footprint(X, Y), name = "item-on-ground" })) do it.destroy() n = n + 1 end
      ctx.log(TAG .. "objets au sol retires : " .. n)
      st.r.sans_items = snapshot(ctx, "sans item-on-ground")
    elseif e.tick == 180 then
      -- vraie chaudiere posee par create_entity sur les restes de corps (encore la)
      local b = s.create_entity({ name = "boiler", position = { X, Y }, direction = defines.direction.north, force = "player" })
      st.r.posee_sur_corps = b ~= nil
      ctx.log(TAG .. "create_entity d'une vraie chaudiere avec le corps encore la : " .. tostring(b ~= nil))
      st.r.apres_pose = snapshot(ctx, "apres create_entity")
      local left = {}
      for _, c in ipairs(s.find_entities_filtered({ area = footprint(X, Y) })) do left[#left + 1] = c.type .. ":" .. c.name end
      table.sort(left)
      ctx.log(TAG .. "apres la pose reelle : " .. table.concat(left, " "))
    end
  end,

  finish = function(ctx)
    local r = ctx.state().r
    ctx.check(r.avant and r.avant.default, "emprise libre avant : can_place_entity vrai")
    ctx.log(TAG .. string.format("RESUME : mort(defaut=%s ghost_revive=%s) fantome_sur_restes=%s sans_items(defaut=%s ghost_revive=%s) "
      .. "pose_reelle_sur_corps=%s", tostring(r.mort and r.mort.default), tostring(r.mort and r.mort.ghost), tostring(r.fantome_restes),
      tostring(r.sans_items and r.sans_items.default), tostring(r.sans_items and r.sans_items.ghost), tostring(r.posee_sur_corps)))
  end,
}
