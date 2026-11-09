--[[
  Lot BUS-LONG (9/11) : micro-scénario en moteur réel de la LIGNE LONGUE planifiée par tronçons (shared/team/troncons.lua, script/team/rapatriement.lua). Critère : fo-logs/2026-11-09_BUS-LONG/CRITERES.md (M1).

  Terrain : le champ de rapatriement_common (260 x 100 tuiles autour de (90, 0), en herbe), avec une sortie à 150 tuiles du QG et, EN TRAVERS du tracé, une colonne de tapis (x = 70, de y = -50 à
  49) qui porte du CHARBON : l'A* à 4 voisins de la version d'avant n'y passait pas (« aucun chemin »), la ligne doit la franchir par une paire de souterrains. Après l'arrivée, aucun objet d'une ligne
  sur l'autre (jamais deux objets sur un même tapis). Le souterrain est débloqué pour la force, le coffre d'équipe en porte.

  Lancement : banc.py ... -- 9500 bus-long <source>. Journal : [FO-BUS-LONG] + [FO-RAPATRIEMENT] du mod.
]]
local ITEM, FOREIGN = "iron-plate", "coal"
local SRC = { x = 150, y = 0 }
local DOCKS = { { x = 26, y = 6 }, { x = 30, y = 14 } }
local BARX = 70
local BUF = 1e12
local W1 = 6200 -- tuile jaune : 32 ticks ; 130 tuiles = 4 200 ticks avant la première arrivée
local MIN_ARRIVES = 12

local function chest_at(s, x, y)
  return s.find_entities_filtered({ position = { x + 0.5, y + 0.5 }, radius = 0.4, type = "container", limit = 1 })[1]
end

local function line_items(belts, item)
  local n = 0
  for _, e in ipairs(belts) do
    for i = 1, 2 do
      local tl = e.get_transport_line(i)
      if tl then n = n + tl.get_item_count(item) end
    end
  end
  return n
end

local function shape(s)
  s.request_to_generate_chunks({ 90, 0 }, 8)
  s.force_generate_chunk_requests()
  local area = { { -40, -50 }, { 230, 50 } }
  for _, e in ipairs(s.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
    if e.valid then e.destroy() end
  end
  local tiles = {}
  for y = -50, 49 do for x = -40, 229 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
  s.set_tiles(tiles, true)
end

return {
  description = "BUS-LONG : ligne longue par troncons, colonne de tapis en travers franchie par souterrain",
  base = nil,
  check_tick = 9300,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    shape(s)
    ctx.check(ctx.call("war_setting", "fo-war-ia3e", false) == false, "reglage fo-war-ia3e coupe (le banc est le cerveau)")
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
    game.forces.player.recipes["underground-belt"].enabled = true
    game.forces.player.recipes["transport-belt"].enabled = true
    game.forces.player.recipes["inserter"].enabled = true
    local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if not chest then return end
    for _, it in ipairs({ { "iron-plate", 4000 }, { "copper-plate", 400 }, { "coal", 200 }, { "transport-belt", 800 }, { "underground-belt", 40 }, { "inserter", 60 },
      { "small-electric-pole", 60 }, { "medium-electric-pole", 40 }, { "iron-chest", 20 } }) do
      chest.insert({ name = it[1], count = it[2] })
    end
    st.hq = chest
    ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 1 }) == true, "plan directeur active")
    local eei = s.create_entity({ name = "electric-energy-interface", position = { -1, 6 }, force = "player" })
    if eei then
      eei.electric_buffer_size = BUF
      eei.power_production = 1e10
      eei.power_usage = 0
      eei.energy = BUF
      st.eei = eei
    end
    local poles = 0
    for x = 0, 184, 8 do
      if x ~= BARX then
        if s.create_entity({ name = "medium-electric-pole", position = { x + 0.5, 4.5 }, force = "player" }) then poles = poles + 1 end
      end
    end
    for _, dx in ipairs({ -4, 4 }) do
      if s.create_entity({ name = "medium-electric-pole", position = { SRC.x + dx + 0.5, 2.5 }, force = "player" }) then poles = poles + 1 end
    end
    ctx.check(poles >= 20, "arene alimentee", tostring(poles))
    ctx.check(s.create_entity({ name = "iron-chest", position = { SRC.x + 0.5, SRC.y + 0.5 }, force = "player" }) ~= nil, "coffre de sortie en (150, 0)")
    for _, d in ipairs(DOCKS) do
      ctx.check(s.create_entity({ name = "iron-chest", position = { d.x + 0.5, d.y + 0.5 }, force = "player" }) ~= nil, "coffre de quai")
    end
    -- la colonne de tapis en travers, chargée de charbon (la pureté)
    local coal = 0
    for y = -50, 49 do
      local b = s.create_entity({ name = "transport-belt", position = { BARX + 0.5, y + 0.5 }, direction = defines.direction.south, force = "player" })
      if b and y % 4 == 0 then
        local tl = b.get_transport_line(1)
        if tl and tl.insert_at_back({ name = FOREIGN, count = 1 }) then coal = coal + 1 end
      end
    end
    ctx.check(coal >= 10, "colonne de tapis chargee de charbon", tostring(coal))
    st.coal0 = coal
    local names = { arm = "inserter", pole = "small-electric-pole" }
    local p1 = ctx.remote("fo-rapatriement", "inject", "player", { outs = { { x = SRC.x + 0.5, y = SRC.y + 0.5 } }, names = names })
    local p2 = ctx.remote("fo-rapatriement", "inject", "player", { quais = { { x = DOCKS[1].x + 0.5, y = DOCKS[1].y + 0.5, item = ITEM } }, inflow = { [ITEM] = 1.0 }, names = names })
    local p3 = ctx.remote("fo-rapatriement", "inject", "player", { quais = { { x = DOCKS[2].x + 0.5, y = DOCKS[2].y + 0.5, item = ITEM } }, inflow = { [ITEM] = 1.0 }, names = names })
    ctx.check(p1 ~= nil and p2 ~= nil and p3 ~= nil, "modules fictifs injectes")
    ctx.check(ctx.remote("fo-rapatriement", "set_param", "player", "force_on", true) == true, "reglage force")
    ctx.check(ctx.remote("fo-rapatriement", "set_param", "player", "sans_centrale", true) == true, "sans centrale")
    ctx.check(ctx.remote("fo-rapatriement", "set_param", "player", "period", 120) == 120, "releve 120 ticks")
    ctx.check(ctx.remote("fo-rapatriement", "set_param", "player", "confirm", 1) == 1, "confirmation immediate")
    st.t0, st.produced, st.log_next = game.tick, 0, 0
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.t0 then return end
    local s = ctx.surface()
    local t = e.tick - st.t0
    if st.eei and st.eei.valid then st.eei.energy = BUF end
    if t > 0 and t % 60 == 0 then
      local c = chest_at(s, SRC.x, SRC.y)
      if c then st.produced = st.produced + c.insert({ name = ITEM, count = 1 }) end
    end
    if t % 30 ~= 0 then return end
    local rap = ctx.remote("fo-rapatriement", "report", "player")
    local line = rap and rap.lines and rap.lines[1]
    if t >= st.log_next then
      st.log_next = t + 300
      ctx.log(string.format("[FO-BUS-LONG] t=%d : ligne %s | sortie %d | tampon arrives %d", t, line and (line.state .. (line.done and " (finie)" or "") .. " " .. line.built .. " piece(s)" .. (line.reason and (" : " .. line.reason) or "")) or "aucune",
        (chest_at(s, SRC.x, SRC.y) or {}).valid and chest_at(s, SRC.x, SRC.y).get_item_count(ITEM) or -1, rap and rap.rapatrie or 0))
    end
    if not st.w1 and line and line.done then
      st.w1 = { start = t, arrived0 = rap and rap.rapatrie or 0 }
      ctx.log(string.format("[FO-BUS-LONG] ligne finie a t=%d, %s piece(s)", t, tostring(line.built)))
    end
    if st.w1 and not st.w1.closed and t - st.w1.start >= W1 then
      st.w1.closed = true
      st.w1.arrived = (rap and rap.rapatrie or 0) - st.w1.arrived0
      local area = { { -40, -50 }, { 200, 50 } }
      local all = s.find_entities_filtered({ area = area, type = "transport-belt" })
      local column, other = {}, {}
      for _, b in ipairs(all) do
        if math.floor(b.position.x) == BARX then column[#column + 1] = b else other[#other + 1] = b end
      end
      st.w1.belts = #other
      st.w1.ug = s.count_entities_filtered({ area = area, type = "underground-belt" })
      st.w1.foreign_on_line = line_items(other, FOREIGN)
      st.w1.iron_on_column = line_items(column, ITEM)
      ctx.log(string.format("[FO-BUS-LONG] fenetre close : %d objet(s) arrives, %d tapis, %d piece(s) souterraine(s), charbon sur la ligne %d, fer sur la colonne %d",
        st.w1.arrived, st.w1.belts, st.w1.ug, st.w1.foreign_on_line, st.w1.iron_on_column))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local rap = ctx.remote("fo-rapatriement", "report", "player")
    local w = st.w1
    ctx.check(rap ~= nil and rap.n.demandes >= 1, "la ligne est demandee par la regle", rap and tostring(rap.n.demandes))
    ctx.check(rap ~= nil and rap.n.refuses == 0, "aucun refus (avant : « aucun chemin » devant une colonne de tapis)", rap and tostring(rap.n.refuses))
    ctx.check(w ~= nil and w.closed == true, "la ligne est finie et la fenetre jouee jusqu'au bout", w and tostring(w.closed))
    if not (w and w.closed) then return end
    ctx.check(w.ug >= 2, "la colonne de tapis est franchie par une paire souterraine", tostring(w.ug))
    ctx.check(w.belts >= 60, "le tapis long est pose (>= 60 tuiles)", tostring(w.belts))
    ctx.check(w.arrived >= MIN_ARRIVES, "des objets arrivent au tampon par tapis (" .. tostring(w.arrived) .. " >= " .. MIN_ARRIVES .. ")")
    ctx.check(w.foreign_on_line == 0, "aucun charbon sur la ligne (jamais deux objets sur un tapis)", tostring(w.foreign_on_line))
    ctx.check(w.iron_on_column == 0, "aucun fer sur la colonne de charbon", tostring(w.iron_on_column))
    ctx.log(string.format("[FO-BUS-LONG] BILAN (arrives=%s, souterrains=%s, tapis=%s)", tostring(w.arrived), tostring(w.ug), tostring(w.belts)))
  end,
}
