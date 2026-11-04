-- Lot EXPERIMENTAUX (4/11), palier 3, session AVEC images (--captures) : un géant LIVRÉ (Cairn, corps `rendering`, pattes sans image)
-- marche 160 tuiles à travers un lac, un mur, une rangée de machines et des falaises, un joueur présent dans la partie.
-- Pourquoi : l'essai e1 (copie jetable, torse porté par le prototype) a vu la session avec images s'arrêter de jouer vers le tick 650
-- (captures 10 à 14 jamais prises), alors que la même partie sans images va au bout (e1b, 4 OK). Ce banc dit si le géant livré a le
-- même défaut, joueur présent.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache --ticks 2600" --qui EXPERIMENTAUX -- 2600 xp-geants-marche <source>
local X2, Y = 12400, 3400
local DEST = 160
local CHECK = 2400

local PLAN = {}
for k, t in ipairs({ 200, 400, 600, 800, 1000, 1200, 1600, 2000 }) do
  PLAN[#PLAN + 1] = { tick = t, nom = string.format("marche-%d", k), x = X2 + DEST / 2, y = Y - 10, zoom = 0.25 }
end
PLAN[#PLAN + 1] = { tick = CHECK + 20, nom = "marche-fin", x = X2 + DEST / 2, y = Y - 10, zoom = 0.25 }

return {
  description = "EXPERIMENTAUX : un geant livre marche a travers les obstacles, joueur present, session avec images",
  check_tick = CHECK,
  shots_delay = PLAN[1].tick,

  init = function(ctx)
    local st = ctx.state()
    game.map_settings.enemy_expansion.enabled = false
    local s = ctx.surface()
    ctx.prepare_area(X2 - 30, Y - 70, X2 + DEST + 40, Y + 40, "dry-dirt")
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X2 - 200, Y - 200 }, { X2 + 400, Y + 200 } } })) do en.destroy() end
    local tiles = {}
    for x = X2 + 40, X2 + 69 do
      for y = Y - 30, Y + 30 do tiles[#tiles + 1] = { name = "water", position = { x, y } } end
    end
    s.set_tiles(tiles)
    for y = Y - 25, Y + 25 do s.create_entity({ name = "stone-wall", position = { X2 + 90.5, y + 0.5 }, force = "player" }) end
    for y = Y - 24, Y + 24, 4 do s.create_entity({ name = "assembling-machine-2", position = { X2 + 110.5, y + 0.5 }, force = "player" }) end
    for k = 0, 8 do s.create_entity({ name = "cliff", position = { X2 + 128, Y - 16 + k * 4 }, cliff_orientation = "north-to-south" }) end
    remote.call("fo-robots", "set_age", "player", 15) -- sinon le plafond des géants (âge 1 : 0 géant) retire le Cairn
    st.g = s.create_entity({ name = "fo-xp-cairn", position = { X2, Y }, force = "player", raise_built = true })
    ctx.check(st.g ~= nil and st.g.valid, "le Cairn se pose (force du joueur)")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    local g = st.g
    if not (g and g.valid) then return end
    if t == 60 then g.autopilot_destination = { X2 + DEST, Y } end
    if t > 60 and not st.arrive then
      local dx, dy = g.position.x - (X2 + DEST), g.position.y - Y
      if dx * dx + dy * dy < 16 then
        st.arrive = t
        ctx.log(string.format("arrive au tick %d : %.3f tuile/tick", t, DEST / (t - 60)))
      end
    end
    if t % 200 == 0 then ctx.log(string.format("t%d en (%.1f, %.1f), joueurs %d", t, g.position.x - X2, g.position.y - Y, #game.connected_players)) end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.arrive ~= nil, "le Cairn arrive a travers lac, mur, machines et falaises, sans coincer",
      st.arrive and string.format("tick %d", st.arrive) or "pas arrive")
    ctx.check(game.tick >= CHECK, "la partie joue jusqu'au controle (pas d'arret de la session avec images)", "tick " .. game.tick)
  end,

  shots = function(ctx, add)
    for i, p in ipairs(PLAN) do
      local suivant = PLAN[i + 1]
      add(p.nom, p.x, p.y, p.zoom, 0, { res = { 1800, 1200 }, cadence = suivant and math.max(1, suivant.tick - p.tick) or nil, aa = true })
    end
  end,
}
