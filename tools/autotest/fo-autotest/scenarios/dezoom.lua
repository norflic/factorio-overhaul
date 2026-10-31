-- Scénario greffé (dézoom étendu, 31/10) : Ctrl + molette vers le bas / le haut, par l'interface distante « fo-dezoom »
-- (un script ne lève pas un événement de touche : même fonction que la touche). Il faut un JOUEUR connecté (player.zoom
-- s'écrit sur un joueur) : session AVEC images, `banc.py --captures -- 260 dezoom <source>`.
--   5 appuis vers le bas : crans 1, 2, 3, 4, 4 (borné) ; 5 appuis vers le haut : 3, 2, 1, 0, 0 (rien à écrire au dernier).
-- Ce que le banc PROUVE : aucune erreur d'écriture de `player.zoom` à chaque cran, crans mémorisés par joueur. Ce qu'il ne
-- prouve PAS : la vue du joueur (zoom illisible, take_screenshot ne la montre pas) ni la limite réelle de la molette.

local X0, Y0 = 6000, -2400
local DOWN = { 1, 2, 3, 4, 4 }
local UP = { 3, 2, 1, 0, 0 }

return {
  description = "dezoom : crans du dézoom étendu, écriture de player.zoom sans erreur",
  base = nil,
  check_tick = 200,
  shots_delay = 150,

  init = function(ctx)
    local s = ctx.surface()
    ctx.prepare_area(X0 - 30, Y0 - 30, X0 + 30, Y0 + 30, "concrete")
    for i = 1, 6 do
      s.create_entity({ name = "wooden-chest", position = { X0 - 12 + i * 4, Y0 }, force = "player" })
    end
  end,

  tick = function(ctx, e)
    local p = game.connected_players[1]
    if not p then
      if e.tick == 60 then ctx.check(false, "un joueur connecte (session avec images)", 0) end
      return
    end
    local st = ctx.state()
    if e.tick == 60 then
      ctx.check(ctx.remote("fo-dezoom", "cran", p.index) == 0, "cran de depart 0", ctx.remote("fo-dezoom", "cran", p.index))
      st.seq = { down = {}, up = {} }
    end
    if e.tick >= 70 and e.tick < 75 then
      local k = e.tick - 69
      ctx.remote("fo-dezoom", "press", p.index, true)
      st.seq.down[k] = ctx.remote("fo-dezoom", "cran", p.index)
    elseif e.tick >= 80 and e.tick < 85 then
      local k = e.tick - 79
      ctx.remote("fo-dezoom", "press", p.index, false)
      st.seq.up[k] = ctx.remote("fo-dezoom", "cran", p.index)
    elseif e.tick == 90 then
      ctx.remote("fo-dezoom", "press", p.index, true) -- laisse la vue au cran 1 pour la capture
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local seq = st.seq
    if not seq then
      ctx.check(false, "sequence jouee (pas de joueur)", nil)
      return
    end
    for k = 1, 5 do
      ctx.check(seq.down[k] == DOWN[k], "vers le bas, appui " .. k .. " : cran " .. DOWN[k], seq.down[k])
      ctx.check(seq.up[k] == UP[k], "vers le haut, appui " .. k .. " : cran " .. UP[k], seq.up[k])
    end
    local p = game.connected_players[1]
    ctx.check(ctx.remote("fo-dezoom", "cran", p.index) == 1, "cran final 1 (dernier appui vers le bas)")
  end,

  shots = function(ctx, add)
    add("dezoom-scene", X0, Y0, 0.2, 0, { res = { 960, 540 } })
  end,
}
