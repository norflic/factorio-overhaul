--[[
  Lot COUVERTURE (micro-banc, 300 ticks) : les positions de tourelles proposées par la couverture maximale
  (script/team/couverture.lua, interface « fo-couverture ») sur une base construite à la main, contre les 4 diagonales fixes
  d'avant ; épreuves du moteur réelles (turret_range du prototype, find_entities_filtered par types et par force,
  can_place_entity). Rien n'est posé par le mod ; le banc pose lui-même les tourelles aux positions rendues pour prouver
  qu'elles sont posables.
  Base : une ligne de 6 fours (est-ouest), 3 laboratoires au nord, une chaudière et deux machines à vapeur à l'ouest, deux
  foreuses au sud ; force « couv » (sans joueur). Menace : un nid d'ennemis à 90 tuiles à l'est, vu par la carte du danger
  seulement quand une équipe est branchée (ici aucune : le banc contrôle l'espacement, la couverture et la posabilité).
  Lancement : fo-autotest.bat nopause 300 couverture-prev <source> ; journal : [FO-COUVERTURE-PREV].
]]

local X, Y = 200, 200

local function dist(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end

return {
  description = "COUVERTURE : positions de tourelles par couverture maximale (moteur reel)",
  check_tick = 240,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(X - 90, Y - 70, X + 90, Y + 70, "grass-1")
    if not game.forces.couv then game.create_force("couv") end
    local made = 0
    local function put(name, x, y, dir)
      local e = s.create_entity({ name = name, position = { x, y }, force = "couv", direction = dir })
      if e then made = made + 1 end
      return e
    end
    for i = 0, 5 do put("stone-furnace", X - 25 + i * 10, Y, nil) end
    for i = 0, 2 do put("lab", X - 12 + i * 12, Y - 18, nil) end
    put("boiler", X - 40, Y + 4, defines.direction.north)
    put("steam-engine", X - 40, Y + 12, defines.direction.north)
    put("steam-engine", X - 40, Y + 19, defines.direction.north)
    put("electric-mining-drill", X - 5, Y + 20, defines.direction.north)
    put("electric-mining-drill", X + 25, Y + 20, defines.direction.north)
    st.made = made
    ctx.check(made >= 12, "base posee (" .. made .. " batiment(s))")
    local proto = game.entity_prototypes["gun-turret"]
    st.range = proto and proto.turret_range or 0
    ctx.check(st.range > 0, "portee lue au prototype (turret_range)", st.range)
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick ~= 60 or st.done then return end
    st.done = true
    local s = ctx.surface()
    local prev = ctx.remote("fo-couverture", "preview", "couv", X, Y, 4, 60)
    st.prev = prev
    if not prev then return end
    st.placed = 0
    local turrets = {}
    for _, p in ipairs(prev.positions) do
      local ok = s.can_place_entity({ name = "gun-turret", position = { p.x, p.y }, force = "couv" })
      local t = ok and s.create_entity({ name = "gun-turret", position = { p.x, p.y }, force = "couv" })
      if t then st.placed = st.placed + 1 end
      turrets[#turrets + 1] = { x = p.x, y = p.y }
    end
    -- couverture mesurée par le banc lui-même, sur les bâtiments réels de la force (hors tourelles), au rayon utile
    local rc = st.range * (prev.cover_pct or 75) / 100
    local function covered(list)
      local n, tot = 0, 0
      for _, en in ipairs(s.find_entities_filtered({ position = { X, Y }, radius = 60, force = "couv" })) do
        if en.valid and en.type ~= "ammo-turret" then
          tot = tot + 1
          for _, t in ipairs(list) do
            if dist(en.position.x, en.position.y, t.x, t.y) <= rc then n = n + 1 break end
          end
        end
      end
      return n, tot
    end
    st.cov_new, st.total = covered(turrets)
    st.cov_old = covered({ { x = X + 7, y = Y + 7 }, { x = X - 7, y = Y - 7 }, { x = X + 7, y = Y - 7 }, { x = X - 7, y = Y + 7 } })
    local gap
    for i = 1, #turrets do
      for j = i + 1, #turrets do
        local d = dist(turrets[i].x, turrets[i].y, turrets[j].x, turrets[j].y)
        if not gap or d < gap then gap = d end
      end
    end
    st.gap = gap
  end,

  finish = function(ctx)
    local st = ctx.state()
    local prev = st.prev
    ctx.check(prev ~= nil, "l'interface fo-couverture repond")
    if not prev then return end
    ctx.log(string.format("FAIT %d batiment(s) vus par la couverture, portee %s, %d menace(s), %d epreuve(s) du moteur, %d position(s)",
      prev.assets or 0, tostring(prev.range), prev.threats or 0, prev.tries or 0, #prev.positions))
    for i, p in ipairs(prev.positions) do
      ctx.log(string.format("FAIT position %d : (%.0f, %.0f) gain %s relache %s", i, p.x, p.y, tostring(p.gain), tostring(p.relaxed)))
    end
    ctx.log(string.format("FAIT batiments couverts (rayon utile) : %s sur %s avec la couverture, %s avec les 4 diagonales d'avant ; ecart minimal %s tuiles",
      tostring(st.cov_new), tostring(st.total), tostring(st.cov_old), st.gap and string.format("%.1f", st.gap) or "-"))
    ctx.check(prev.assets and prev.assets >= 10, "la couverture voit les batiments de la force (fours, labos, machines, foreuses)", prev.assets)
    ctx.check(#prev.positions == 4, "4 positions proposees", #prev.positions)
    ctx.check(st.placed == 4, "les 4 positions sont posables par le moteur", st.placed)
    ctx.check(st.gap ~= nil and st.gap >= st.range * 0.4 - 0.01, "aucune tourelle plus proche d'une autre que 40 % de la portee", st.gap)
    ctx.check(st.cov_new ~= nil and st.cov_old ~= nil and st.cov_new >= st.cov_old, "au moins autant de batiments couverts que les 4 diagonales", st.cov_new)
    ctx.check(st.cov_new ~= nil and st.total ~= nil and st.cov_new >= 0.9 * st.total, "90 % au moins des batiments couverts", st.cov_new)
  end,
}
