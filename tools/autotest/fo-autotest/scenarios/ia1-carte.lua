-- Scénario greffé du lot IA1-0 (24/10) : expérience R6 (docs/EQUIPES_PNJ.md §14, §7.1) et visibilité des fantômes
-- d'une autre force (R2). IMAGES SEULEMENT : un dessin `rendering` et une étiquette de carte ne se voient que dans
-- une session avec rendu (sans images, rien n'est cartographié : F131).
--   & "<racine>\fo-captures.bat" ia1-carte "<source>"
-- Deux zones de 64 × 64 séparées de 16 tuiles, A en (552, 576)-(616, 640) et B en (632, 576)-(696, 640) :
--   zone A : bordure pointillée (draw_line, dash_length, gap_length, draw_on_ground) EN MODE ALT SEULEMENT, visible de
--            la seule force « player », texte « Zone A » en mode Alt seulement, 2 tourelles ;
--   zone B : la même bordure SANS only_in_alt_mode (témoin : visible en vue normale), texte « Zone B » ;
--   une étiquette de carte par zone (LuaForce.add_chart_tag), posée dès que les chunks sont cartographiés.
-- Fantômes (R2) : assembleur 2 en fantôme de « player » et de « ia1-fac », côte à côte, plus un assembleur bâti de
-- chaque force : le joueur voit-il le fantôme d'une autre force ? Essai 1 : visible sur les captures de la liste, absent
-- sur celles prises avec by_player et show_gui ; 4 variantes au même tick (x-ia1-fantomes-g1 à g4) pour trancher.
-- Captures de la liste (take_screenshot, vue du monde) : vue normale, mode Alt, nuit, zooms 0,34 et 0,15 ; fantômes au
-- zoom 2. Captures HORS liste, écrites par ce scénario (fo-shots\x-*.png, non indexées) :
--   x-ia1-fantomes-g1 à g4 : variantes de take_screenshot (player seul ; by_player ; show_gui ; sans player) ;
--   x-ia1-minimap-*.png : élément d'interface « minimap » (carte de la force) + show_gui, 5 ticks après sa création ;
--   x-ia1-open-map.png : LuaPlayer.open_map, puis take_screenshot (essai 1 : la capture ignore le mode carte).

local ZA = { 552, 576, 616, 640 }
local ZB = { 632, 576, 696, 640 }
local CENTER = { 624, 608 }
local GHOSTS = { 574, 620.5 }
local COLOR = { r = 0.55, g = 0.68, b = 0.80, a = 0.85 } -- couleur d'équipe désaturée (remarque du DC du 24/10)
local CHECK = 230
local T_CHART = 2
local T_G = 100
local T_MINI = 130
local T_MAP = 170

local function border(z, alt, ids)
  local s = game.surfaces[1]
  local pts = { { z[1], z[2] }, { z[3], z[2] }, { z[3], z[4] }, { z[1], z[4] } }
  for i = 1, 4 do
    local a, b = pts[i], pts[i % 4 + 1]
    ids[#ids + 1] = rendering.draw_line({ color = COLOR, width = 2, gap_length = 0.5, dash_length = 1, from = a, to = b,
      surface = s, forces = { "player" }, draw_on_ground = true, only_in_alt_mode = alt })
  end
  ids[#ids + 1] = rendering.draw_text({ text = alt and "Zone A (mode Alt)" or "Zone B (toujours)", surface = s,
    target = { (z[1] + z[3]) / 2, z[2] + 3 }, color = COLOR, scale = 2, alignment = "center", forces = { "player" },
    only_in_alt_mode = alt, draw_on_ground = true })
end

local function charted(force, s, z)
  for cx = math.floor(z[1] / 32), math.floor((z[3] - 1) / 32) do
    for cy = math.floor(z[2] / 32), math.floor((z[4] - 1) / 32) do
      if not force.is_chunk_charted(s, { cx, cy }) then return false end
    end
  end
  return true
end

--- Capture hors liste (fo-shots/x-*.png) ; tables littérales (contrôle api_lint).
local function shot_gui(path, player, position, zoom, info)
  game.take_screenshot({ path = "fo-shots/" .. path, resolution = { 1600, 900 }, force_render = true,
    allow_in_replay = true, anti_alias = false, player = player, by_player = player, position = position,
    zoom = zoom, show_gui = true, show_entity_info = info })
end

return {
  description = "IA1-0 R6 : dessins rendering et etiquettes de carte (vue normale, mode Alt, carte) ; fantomes de deux forces",
  base = nil,
  check_tick = CHECK,
  shots_delay = 240,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    if not game.forces["ia1-fac"] then game.create_force("ia1-fac") end
    game.forces["ia1-fac"].set_cease_fire("player", true)
    game.forces.player.set_cease_fire("ia1-fac", true)
    ctx.prepare_area(536, 556, 712, 660, "grass-1")
    local n_en = 0
    for _, e in ipairs(s.find_entities_filtered({ force = "enemy", area = { { 400, 400 }, { 900, 850 } } })) do
      e.destroy()
      n_en = n_en + 1
    end
    st.ids = {}
    border(ZA, true, st.ids)
    border(ZB, false, st.ids)
    st.turrets = {}
    for _, p in ipairs({ { 566, 590 }, { 602, 590 } }) do
      local t = s.create_entity({ name = "gun-turret", position = p, force = "player" })
      if t then
        t.insert({ name = "firearm-magazine", count = 10 })
        st.turrets[#st.turrets + 1] = t
      end
    end
    local x, y = GHOSTS[1] - 7.5, GHOSTS[2]
    st.ghosts = {
      s.create_entity({ name = "entity-ghost", inner_name = "assembling-machine-2", position = { x, y }, force = "player", expires = false }),
      s.create_entity({ name = "entity-ghost", inner_name = "assembling-machine-2", position = { x + 5, y }, force = "ia1-fac", expires = false }),
      s.create_entity({ name = "assembling-machine-2", position = { x + 10, y }, force = "player" }),
      s.create_entity({ name = "assembling-machine-2", position = { x + 15, y }, force = "ia1-fac" }),
    }
    local valid = 0
    for _, id in ipairs(st.ids) do if rendering.is_valid(id) then valid = valid + 1 end end
    ctx.check(valid == 10, "R6 : 8 traits pointilles et 2 textes dessines (zone A en mode Alt seulement, zone B toujours)",
      valid .. "/10 ; ennemis retires " .. n_en)
    local g = 0
    for _, e in ipairs(st.ghosts) do if e then g = g + 1 end end
    ctx.check(g == 4 and #st.turrets == 2, "R2 visibilite : fantomes de player et de ia1-fac, deux batiments, 2 tourelles",
      g .. "/4, tourelles " .. #st.turrets)
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    local player = game.connected_players[1]
    local f = game.forces.player
    if e.tick == T_CHART then
      f.chart(s, { { 536, 556 }, { 712, 660 } })
      ctx.log("chart demande au tick " .. e.tick .. ", joueur connecte : " .. tostring(player ~= nil))
    end
    if not st.tags and e.tick > T_CHART and e.tick % 5 == 0 and charted(f, s, { ZA[1], ZA[2], ZB[3], ZB[4] }) then
      st.tags = {
        f.add_chart_tag(s, { position = { 584, 600 }, icon = { type = "virtual", name = "signal-A" }, text = "Zone A" }),
        f.add_chart_tag(s, { position = { 664, 600 }, icon = { type = "virtual", name = "signal-B" }, text = "Zone B" }),
      }
      st.tag_tick = e.tick
      ctx.log("chunks cartographies au tick " .. e.tick .. " ; etiquettes : " .. tostring(st.tags[1] ~= nil) .. ", "
        .. tostring(st.tags[2] ~= nil))
    end
    if not player then return end
    if e.tick == T_G then
      local v = {}
      for i, g in ipairs(st.ghosts) do v[i] = g and g.valid and (g.name .. "/" .. g.force.name) or "invalide" end
      ctx.log("joueur de force " .. player.force.name .. " ; entites au tick " .. e.tick .. " : " .. table.concat(v, ", "))
      game.take_screenshot({ path = "fo-shots/x-ia1-fantomes-g1-player.png", player = player, position = GHOSTS, zoom = 2,
        resolution = { 1600, 900 }, force_render = true, allow_in_replay = true })
      game.take_screenshot({ path = "fo-shots/x-ia1-fantomes-g2-by_player.png", player = player, by_player = player,
        position = GHOSTS, zoom = 2, resolution = { 1600, 900 }, force_render = true, allow_in_replay = true })
      game.take_screenshot({ path = "fo-shots/x-ia1-fantomes-g3-show_gui.png", player = player, show_gui = true,
        position = GHOSTS, zoom = 2, resolution = { 1600, 900 }, force_render = true, allow_in_replay = true })
      game.take_screenshot({ path = "fo-shots/x-ia1-fantomes-g4-sans-player.png", surface = s, position = GHOSTS, zoom = 2,
        resolution = { 1600, 900 }, force_render = true, allow_in_replay = true })
    elseif e.tick == T_MINI then
      local res = player.display_resolution
      ctx.log(string.format("joueur : resolution %dx%d, echelle %.2f, mode de rendu %s", res.width, res.height,
        player.display_scale, tostring(player.render_mode)))
      local fr = player.gui.screen.add({ type = "frame", name = "ia1_mini", caption = "minimap (R6)", direction = "horizontal" })
      fr.location = { 40, 80 }
      local mm = fr.add({ type = "minimap", name = "mm", position = CENTER, surface_index = s.index, force = "player",
        zoom = 1 })
      mm.style.width = 640
      mm.style.height = 400
      local mm2 = fr.add({ type = "minimap", name = "mm2", position = CENTER, surface_index = s.index, force = "player",
        zoom = 3 })
      mm2.style.width = 640
      mm2.style.height = 400
    elseif e.tick == T_MINI + 5 then
      ctx.log("minimap : cadre present " .. tostring(player.gui.screen.ia1_mini ~= nil))
      shot_gui("x-ia1-minimap-gui.png", player, CENTER, 0.34, false)
      shot_gui("x-ia1-minimap-gui-alt.png", player, CENTER, 0.34, true)
    elseif e.tick == T_MINI + 15 then
      if player.gui.screen.ia1_mini then player.gui.screen.ia1_mini.destroy() end
    elseif e.tick == T_MAP then
      player.open_map(CENTER, 0.5)
    elseif e.tick == T_MAP + 5 then
      ctx.log("open_map : mode de rendu " .. tostring(player.render_mode) .. " (game = " .. tostring(defines.render_mode.game)
        .. ", chart = " .. tostring(defines.render_mode.chart) .. ", chart_zoomed_in = "
        .. tostring(defines.render_mode.chart_zoomed_in) .. ")")
      shot_gui("x-ia1-open-map.png", player, nil, nil, true)
    elseif e.tick == T_MAP + 10 then
      player.close_map()
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local valid = 0
    for _, id in ipairs(st.ids or {}) do if rendering.is_valid(id) then valid = valid + 1 end end
    ctx.check(valid == 10, "R6 : dessins toujours valides au tick " .. CHECK, valid .. "/10")
    if game.connected_players[1] then
      ctx.check(st.tags and st.tags[1] and st.tags[2], "R6 : etiquettes de carte posees (session avec images)",
        "tick " .. tostring(st.tag_tick))
    else
      ctx.log("sans images : rien n'est cartographie (F131), etiquettes " .. (st.tags and "posees" or "non posees"))
    end
  end,

  shots = function(ctx, add)
    add("zone-normale-z034", CENTER[1], CENTER[2], 0.34, 0, { info = false })
    add("zone-alt-z034", CENTER[1], CENTER[2], 0.34, 0, { info = true })
    add("zone-alt-nuit-z034", CENTER[1], CENTER[2], 0.34, 0.5, { info = true })
    add("zone-normale-z015", CENTER[1], CENTER[2], 0.15, 0, { info = false })
    add("zone-alt-z015", CENTER[1], CENTER[2], 0.15, 0, { info = true })
    add("fantomes-normal-z2", GHOSTS[1], GHOSTS[2], 2, 0, { info = false })
    add("fantomes-alt-z2", GHOSTS[1], GHOSTS[2], 2, 0, { info = true })
  end,
}
