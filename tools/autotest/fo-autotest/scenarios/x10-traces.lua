--[[
  Lot X10, traces de pas (le DC, 7/11, 18 h 33 : « Les retirer aux PNJ ») : PREUVE PAR CAPTURE. Sur une bande de sable
  (« sand-1 », où le personnage vanilla laisse empreintes et poussière), deux marcheurs vont et viennent côte à côte :
    - au nord, un PNJ « fo-companion » (le prototype changé par le lot) ;
    - au sud, un témoin « character » (le personnage du joueur, inchangé).
  Avant le lot, les deux laissent des traces ; après, seul le témoin. Captures après 600 ticks de marche, de jour, au zoom
  2 sur les deux marcheurs puis au zoom 4 sur chacun. Le contrôle (tick 700) dit seulement que les deux ont marché :
  le jugement est sur les images.
]]

local X0, Y0, LONG = 20, 30, 40 -- bande de x = X0 à X0 + LONG, y = Y0 - 6 à Y0 + 6
local ALLER = 200                -- ticks par aller (environ 30 tuiles à la vitesse du personnage)

local S = {
  description = "X10 traces de pas : un PNJ et un personnage temoin marchent sur du sable",
  check_tick = 700,
  shots_delay = 600,
}

S.init = function(ctx)
  local surf = ctx.surface()
  local area = { { X0 - 2, Y0 - 8 }, { X0 + LONG + 2, Y0 + 8 } }
  for _, e in ipairs(surf.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff", "fish" } })) do
    e.destroy()
  end
  local tiles = {}
  for x = X0 - 2, X0 + LONG + 1 do
    for y = Y0 - 8, Y0 + 7 do tiles[#tiles + 1] = { name = "sand-1", position = { x, y } } end
  end
  surf.set_tiles(tiles) -- avant les entités (F135)
  local st = ctx.state()
  st.pnj = surf.create_entity({ name = "fo-companion", position = { X0 + 2, Y0 - 2 }, force = "player" })
  st.temoin = surf.create_entity({ name = "character", position = { X0 + 2, Y0 + 2 }, force = "player" })
  ctx.check(st.pnj ~= nil and st.temoin ~= nil, "deux marcheurs poses (fo-companion et character)")
  st.x0 = { pnj = X0 + 2, temoin = X0 + 2 }
  st.course = { pnj = 0, temoin = 0 }
end

S.tick = function(ctx, e)
  local st = ctx.state()
  if not (st.pnj and st.temoin) then return end
  local sens = (math.floor(e.tick / ALLER) % 2 == 0) and defines.direction.east or defines.direction.west
  for _, k in ipairs({ "pnj", "temoin" }) do
    local m = st[k]
    if m.valid then
      local x = m.position.x
      st.course[k] = st.course[k] + math.abs(x - (st.dernier and st.dernier[k] or x))
      st.dernier = st.dernier or {}
      st.dernier[k] = x
      m.walking_state = { walking = true, direction = sens }
    end
  end
end

S.finish = function(ctx)
  local st = ctx.state()
  for _, k in ipairs({ "pnj", "temoin" }) do
    local m = st[k]
    ctx.check(m and m.valid and st.course[k] > 20, k .. " a marche (plus de 20 tuiles)", string.format("%.1f tuiles", st.course[k] or 0))
  end
end

S.shots = function(ctx, add)
  local st = ctx.state()
  local cx = (st.pnj and st.pnj.valid) and st.pnj.position.x or (X0 + LONG / 2)
  add("x10-traces-deux", cx, Y0, 2, 0, {})
  if st.pnj and st.pnj.valid then add("x10-traces-pnj", st.pnj.position.x, st.pnj.position.y, 4, 0, {}) end
  if st.temoin and st.temoin.valid then add("x10-traces-temoin", st.temoin.position.x, st.temoin.position.y, 4, 0, {}) end
end

return S
