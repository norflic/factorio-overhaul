--[[
  Micro-banc « fonderie-bloc » du lot FONDERIE-BLOC (8/11) : le COFFRE DE CHARBON d'un champ (coffre de tête d'une colonne) relié par un tapis au
  charbon, contre le moteur réel (shared/team/fonderie_bloc.lua, script/team/fonderie_bloc.lua).
  Chaîne : projet de champ fini fictif (remote fo-fonderie-bloc inject) avec un coffre de tête (20, 6), charbon, débit 0,27/s -> le piquage
  (regle lue en jeu) ne trouve aucune source -> l'alimentation de quai est demandée -> ligne de foreuses sur le gisement de charbon de
  (62, 10) (rayon 5, à ~45 tuiles) + tapis + bras et poteau contre le coffre, bâtis par les PNJ -> le coffre est servi SANS voyage de PNJ.
  Terrain : herbe de 180 x 100 tuiles autour de (50, 0) ; coffre d'équipe en (0, 0), 8 PNJ, plan directeur « seul » (rayon 3), fo-war-ia3e coupé
  (le banc tient le rôle du cerveau). Courant : interface électrique + poteau moyen au coffre ; une autre au centre du gisement (comme l'arène
  de piquage-micro). Le banc ne pose PAS le tapis, les foreuses, le bras ni le poteau de l'alimentation : le mod les planifie et les PNJ les bâtissent.
  Fenêtre W (ouverte quand le projet est fini) : le coffre est ramené à 70 charbons et vidé à 0,27/s (la consommation de la colonne) :
  il ne passe pas sous 60 (Build.QUAI_LOW) et aucun PNJ ne porte de charbon.
  Lancement : banc.py ... --qui FONDERIE-BLOC -- 9500 fonderie-bloc <source> ; journal : [FO-FONDERIE-BLOC-BANC] + [FO-FONDERIE-BLOC] du mod.
]]

local ITEM = "coal"
local DOCK = { x = 20, y = 6 }
local PATCH = { x = 62, y = 10 }
local FLOW = 0.27
local BUF = 1e8
local W = 1500
local LOW = 60
local TAG = "FO-FONDERIE-BLOC-BANC"

local function chest_at(s, x, y) return s.find_entities_filtered({ position = { x + 0.5, y + 0.5 }, radius = 0.4, type = "container", limit = 1 })[1] end
local function count_of(s, x, y) local c = chest_at(s, x, y); return c and c.get_item_count(ITEM) or -1 end
local function set_count(s, x, y, n)
  local c = chest_at(s, x, y)
  if not c then return end
  local have = c.get_item_count(ITEM)
  if have > n then c.remove_item({ name = ITEM, count = have - n }) elseif have < n then c.insert({ name = ITEM, count = n - have }) end
end

local function stock_chest(chest)
  for _, it in ipairs({
    { "iron-plate", 2000 }, { "copper-plate", 400 }, { "coal", 300 }, { "transport-belt", 500 }, { "inserter", 40 },
    { "small-electric-pole", 60 }, { "medium-electric-pole", 30 }, { "iron-chest", 20 }, { "electric-mining-drill", 20 },
    { "underground-belt", 20 }, { "stone-furnace", 10 },
  }) do
    chest.insert({ name = it[1], count = it[2] })
  end
end

local function shape(ctx)
  local s = ctx.surface()
  s.request_to_generate_chunks({ 50, 0 }, 5)
  s.force_generate_chunk_requests()
  for _, e in ipairs(s.find_entities_filtered({ area = { { -40, -50 }, { 140, 50 } }, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
    if e.valid then e.destroy() end
  end
  local tiles = {}
  for y = -50, 49 do for x = -40, 139 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
  s.set_tiles(tiles, true)
end

local function patch(s, c, r, amount)
  local n = 0
  for dx = -r, r do
    for dy = -r, r do
      if dx * dx + dy * dy <= r * r then
        if s.create_entity({ name = "coal", position = { c.x + dx + 0.5, c.y + dy + 0.5 }, amount = amount }) then n = n + 1 end
      end
    end
  end
  return n
end

--- Source d'énergie : une interface électrique et un poteau moyen à côté (4 tuiles), le poteau relié à ce qui l'entoure par le moteur.
local function power_island(s, st, x, y)
  local eei = s.create_entity({ name = "electric-energy-interface", position = { x + 3, y }, force = "player" })
  if eei then eei.electric_buffer_size = BUF; eei.power_production = 0; eei.power_usage = 0; eei.energy = BUF; st.eeis[#st.eeis + 1] = eei end
  local pole = s.create_entity({ name = "medium-electric-pole", position = { x + 0.5, y + 0.5 }, force = "player" })
  return eei ~= nil and pole ~= nil
end

local function count_in(s, name, x0, y0, x1, y1)
  return #s.find_entities_filtered({ area = { { x0, y0 }, { x1, y1 } }, name = name, force = "player" })
end

return {
  description = "FONDERIE-BLOC : le coffre de charbon d'un champ relie par un tapis a une ligne de foreuses de charbon",
  base = nil,
  check_tick = 9300,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.eeis = {}
    shape(ctx)
    ctx.check(ctx.call("war_setting", "fo-war-ia3e", false) == false, "reglage fo-war-ia3e coupe (le banc est le cerveau)")
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
    local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if not chest then return end
    stock_chest(chest)
    local n = patch(s, PATCH, 5, 20000)
    ctx.check(n >= 60, "gisement de charbon pose", string.format("%d tuiles en (%d, %d)", n, PATCH.x, PATCH.y))
    ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 3 }) == true, "plan directeur active (rayon 3)")
    ctx.check(power_island(s, st, 24, 2), "courant au coffre du quai")
    ctx.check(power_island(s, st, PATCH.x, PATCH.y), "courant au gisement")
    local dock = s.create_entity({ name = "iron-chest", position = { DOCK.x + 0.5, DOCK.y + 0.5 }, force = "player" })
    ctx.check(dock ~= nil, "coffre de tete pose en (20, 6)")
    set_count(s, DOCK.x, DOCK.y, 400)
    local p = ctx.remote("fo-fonderie-bloc", "inject", "player", { quais = { { x = DOCK.x + 0.5, y = DOCK.y + 0.5, item = ITEM, flow = FLOW } },
      names = { arm = "inserter", pole = "small-electric-pole" } })
    ctx.check(p ~= nil, "projet de champ fini fictif injecte", tostring(p))
    ctx.check(ctx.remote("fo-fonderie-bloc", "set_param", "player", "sans_centrale", true) == true, "sans centrale (banc)")
    ctx.check(ctx.remote("fo-fonderie-bloc", "set_param", "player", "period", 120) == 120, "releve toutes les 120 ticks")
    ctx.check(ctx.remote("fo-piquage", "set_param", "player", "sans_centrale", true) == true, "piquage : sans centrale (banc)")
    ctx.check(ctx.remote("fo-piquage", "set_param", "player", "period", 120) == 120, "piquage : releve toutes les 120 ticks")
    ctx.check(ctx.remote("fo-piquage", "set_param", "player", "confirm", 1) == 1, "piquage : confirmation en un releve")
    ctx.check(ctx.remote("fo-piquage", "set_param", "player", "disc_every", 300) == 300, "piquage : decouverte toutes les 300 ticks")
    st.t0 = game.tick
    st.log_next = 0
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.t0 then return end
    local s = ctx.surface()
    local t = e.tick - st.t0
    for _, eei in ipairs(st.eeis) do if eei.valid then eei.energy = BUF end end
    local rep = ctx.remote("fo-ia1d", "report", "player")
    local fb = ctx.remote("fo-fonderie-bloc", "report", "player")
    local filled = rep and rep.filled or 0
    local link = fb and fb.links and fb.links[1]
    if link and link.done and not st.w then
      set_count(s, DOCK.x, DOCK.y, 70)
      st.w = { start = t, filled0 = filled, consumed = 0, acc = 0 }
      ctx.log(string.format("[%s] fenetre W ouverte a t=%d : coffre ramene a 70 charbons, PNJ ont porte %d jusqu'ici", TAG, t, filled))
    end
    if st.w and not st.w.closed then
      st.w.acc = st.w.acc + FLOW / 60
      if st.w.acc >= 1 then
        local n = math.floor(st.w.acc)
        st.w.acc = st.w.acc - n
        local c = chest_at(s, DOCK.x, DOCK.y)
        if c then st.w.consumed = st.w.consumed + c.remove_item({ name = ITEM, count = n }) end
      end
      local n = count_of(s, DOCK.x, DOCK.y)
      if n >= 0 and (not st.w.min or n < st.w.min) then st.w.min = n end
      if t - st.w.start >= W then
        st.w.closed = true
        st.w.filled = filled - st.w.filled0
        st.w.end_n = count_of(s, DOCK.x, DOCK.y)
        ctx.log(string.format("[%s] fenetre W close a t=%d : coffre min %s fin %d, consomme %d, PNJ ont porte %d", TAG, t, tostring(st.w.min), st.w.end_n, st.w.consumed, st.w.filled))
      end
    end
    if t % 30 == 0 and t >= st.log_next then
      st.log_next = t + 300
      ctx.log(string.format("[%s] t=%d : alimentation %s | coffre %d | foreuses %d | tapis %d | PNJ ont porte %d", TAG, t,
        link and (link.state .. (link.done and " (fini)" or "") .. (link.reason and (" : " .. link.reason) or "")) or "aucune",
        count_of(s, DOCK.x, DOCK.y), count_in(s, "electric-mining-drill", 20, -10, 100, 40), count_in(s, "transport-belt", 10, -10, 100, 40), filled))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local fb = ctx.remote("fo-fonderie-bloc", "report", "player")
    ctx.check(fb ~= nil and fb.demandes >= 1, "une alimentation de quai demandee par la regle", fb and tostring(fb.demandes))
    ctx.check(fb ~= nil and fb.finis >= 1, "l'alimentation est finie", fb and string.format("finis=%d refuses=%d", fb.finis, fb.refuses))
    local drills = count_in(s, "electric-mining-drill", 20, -10, 100, 40)
    local belts = count_in(s, "transport-belt", 10, -10, 100, 40)
    ctx.check(drills >= 1, "foreuses electriques bâties", tostring(drills))
    ctx.check(belts >= 20, "tapis bâti jusqu'au coffre", tostring(belts))
    -- le bras contre le coffre : il depose dans le coffre (20, 6)
    local arm_ok = false
    for _, a in ipairs(s.find_entities_filtered({ area = { { DOCK.x - 2, DOCK.y - 2 }, { DOCK.x + 3, DOCK.y + 3 } }, name = "inserter", force = "player" })) do
      local d = a.drop_position
      if d and math.floor(d.x) == DOCK.x and math.floor(d.y) == DOCK.y then arm_ok = true end
    end
    ctx.check(arm_ok, "un bras depose dans le coffre de tete")
    local w = st.w
    ctx.check(w ~= nil and w.closed == true, "fenetre W jouee jusqu'au bout")
    if w and w.closed then
      ctx.check(w.min ~= nil and w.min >= LOW, "fenetre W : le coffre ne passe jamais sous " .. LOW .. " (min " .. tostring(w.min) .. ")")
      ctx.check(w.filled == 0, "fenetre W : aucun objet porte par un PNJ (" .. tostring(w.filled) .. ")")
      ctx.check(w.consumed >= 0.9 * FLOW * W / 60 * 0.9, "fenetre W : la consommation a eu lieu (" .. w.consumed .. ")")
      ctx.log(string.format("[%s] BILAN : coffre min %s, PNJ ont porte %s, foreuses %d, tapis %d", TAG, tostring(w.min), tostring(w.filled), drills, belts))
    else
      ctx.log(string.format("[%s] BILAN : fenetre W jamais ouverte (alimentation non finie), foreuses %d, tapis %d", TAG, drills, belts))
    end
  end,
}
