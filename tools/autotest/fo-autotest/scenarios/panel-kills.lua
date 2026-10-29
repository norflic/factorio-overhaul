--[[
  Lot PANEL-STATS (correction du 29/10) : SENS de `kill_count_statistics` en moteur réel, par de VRAIES morts (aucun
  `set_*_count`). Lancement : « 900 panel-kills » (banc sans images). Journal : [FO-PANEL-KILLS].
    1. une tourelle de la force `player`, chargée, tue 3 petits mordeurs de la force `enemy` ;
    2. un coffre de la force `player` est détruit par `die("enemy")` (une entité DE la force, tuée par l'ennemi).
  Les contrôles lisent les deux tables des deux forces et le disent en toutes lettres ; le panneau (ia1-gui) s'aligne
  sur ce qui est établi ici.
]]

local X, Y = 216.5, 216.5

local function sum(t)
  local n = 0
  for _, v in pairs(t) do n = n + v end
  return n
end

local function dump(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(t[k]) end
  return "{" .. table.concat(parts, ", ") .. "}"
end

local function alive_biters(s)
  return #s.find_entities_filtered({ name = "small-biter", force = "enemy", area = { { X - 60, Y - 60 }, { X + 60, Y + 60 } } })
end

return {
  description = "panel-kills : sens de kill_count_statistics par de vraies morts (tourelle contre mordeurs, coffre detruit)",
  base = nil,
  check_tick = 800,

  init = function(ctx)
    local s = ctx.surface()
    ctx.prepare_area(X - 40, Y - 40, X + 40, Y + 40, "grass-1")
    local st = ctx.state()
    st.before = {
      p_in = sum(game.forces.player.kill_count_statistics.input_counts),
      p_out = sum(game.forces.player.kill_count_statistics.output_counts),
      e_in = sum(game.forces.enemy.kill_count_statistics.input_counts),
      e_out = sum(game.forces.enemy.kill_count_statistics.output_counts),
    }
    ctx.check(st.before.p_in == 0 and st.before.p_out == 0, "compteurs de kills de la force player a zero au depart",
      string.format("input %d output %d", st.before.p_in, st.before.p_out))
    local t = s.create_entity({ name = "gun-turret", position = { X, Y }, force = "player", raise_built = true })
    ctx.check(t ~= nil, "tourelle de la force player posee")
    if t then
      t.insert({ name = "firearm-magazine", count = 40 })
      st.turret = t.position
    end
    local n = 0
    for i = 1, 3 do
      local p = s.find_non_colliding_position("small-biter", { X + 14, Y - 4 + 4 * i }, 6, 0.5)
      local b = p and s.create_entity({ name = "small-biter", position = p, force = "enemy" })
      if b then n = n + 1 end
    end
    st.biters = n
    ctx.check(n == 3, "3 petits mordeurs poses", tostring(n))
    local c = s.create_entity({ name = "wooden-chest", position = { X - 20.5, Y + 10.5 }, force = "player" })
    ctx.check(c ~= nil, "coffre de la force player pose")
    st.chest = c and c.position
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == 400 and st.chest then
      local c = s.find_entity("wooden-chest", st.chest)
      st.chest_found = c ~= nil
      if c then c.die("enemy") end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local P, E = game.forces.player.kill_count_statistics, game.forces.enemy.kill_count_statistics
    ctx.log("player input_counts  " .. dump(P.input_counts))
    ctx.log("player output_counts " .. dump(P.output_counts))
    ctx.log("enemy  input_counts  " .. dump(E.input_counts))
    ctx.log("enemy  output_counts " .. dump(E.output_counts))
    ctx.check(alive_biters(s) == 0, "les 3 mordeurs sont morts (tues par la tourelle)", tostring(alive_biters(s)))
    ctx.check(st.chest_found == true, "le coffre existait au moment d'etre detruit")
    ctx.check((P.input_counts["small-biter"] or 0) == 3,
      "SENS : les 3 mordeurs tues par la force player sont dans player.input_counts (kills = input)",
      tostring(P.input_counts["small-biter"]))
    ctx.check((P.output_counts["small-biter"] or 0) == 0, "SENS : aucun mordeur dans player.output_counts",
      tostring(P.output_counts["small-biter"]))
    ctx.check((P.output_counts["wooden-chest"] or 0) == 1,
      "SENS : le coffre de la force player detruit par l'ennemi est dans player.output_counts (pertes = output)",
      tostring(P.output_counts["wooden-chest"]))
    ctx.check((P.input_counts["wooden-chest"] or 0) == 0, "SENS : aucun coffre dans player.input_counts")
    ctx.check((E.output_counts["small-biter"] or 0) == 3 and (E.input_counts["wooden-chest"] or 0) == 1,
      "SENS vu de l'ennemi : ses mordeurs perdus en output, le coffre detruit en input",
      string.format("output small-biter %s, input wooden-chest %s", tostring(E.output_counts["small-biter"]),
        tostring(E.input_counts["wooden-chest"])))
  end,
}
