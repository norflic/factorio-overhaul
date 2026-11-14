--[[
  Sprint s43, scénario de crise n° 2 (scen-energie) : GOULOT SUR UN BUS À HAUTE DENSITÉ.

  MISE EN SCÈNE (arène du micro-banc piquage, scenarios/piquage_micro_common.lua : herbe 180 x 100 autour de (50, 0), votre équipe de 8 PNJ,
  plan directeur « seul », fo-war-ia3e coupé, interface électrique et poteaux) :
    - le BUS : tapis plein de plaques de fer de (31, -10) à (89, -10) vers l'est, nourri par le script ; sa SORTIE EST BOUCHÉE (le bras du puits
      en (90, -10) est arrêté : active = false) : la ligne sature ;
    - le quai B (60, 6) d'un module fictif (plaques de fer, 1,0/s) à 16 tuiles du bus : servi à la main ;
    - trois quais A (50, 34), (60, 34), (70, 34) de modules fictifs PLUS GOURMANDS (2,0/s chacun), à portée d'un second tapis CLAIRSEMÉ
      (31..89, 40 ; une plaque toutes les 30 ticks, vidé au bout par le script) : ils sont « prêts » à chaque relevé mais aucun surplus n'y
      est observé (attente) ; hors de portée du bus (44 tuiles).
  THÉORIE : le cerveau voit la ligne saturée (tuiles denses, Pq.observe / Pq.tile_verdict) et pique le surplus vers le quai B (répartiteur
  priorité au bus, branche, bras), donc une demande de piquage pour B (ou une ligne, la liaison) en moins de T_MAX ticks ; les quais A
  n'empêchent rien (aucun quai prêt n'attend son évaluation indéfiniment).
  Défaut visé (partie du DC 0.7.96, amber, 12 quais figés en « attente/releves_insuffisants », 0 piquage en 4 h 15) : finish_cycle n'évaluait
  que les EVAL_MAX (3) premiers quais prêts par débit : les quais A monopolisaient l'évaluation et B n'était jamais évalué.
  RELEVÉ : rapport remote fo-piquage (liens par quai, demandes), densité d'une tuile du bus, journal [FO-PIQUAGE] du mod.
  Lancement : banc.py --out <archive> --qui s43-scen-energie -- 6000 scen-bus-goulot <source>. Journal : [FO-SCEN-BUS-GOULOT].
]]

local ITEM = "iron-plate"
local DOCK_B = { x = 60, y = 6 }
local DOCKS_A = { { x = 50, y = 34 }, { x = 60, y = 34 }, { x = 70, y = 34 } }
local SINK = { x = 91, y = -10 }
local BUF = 1e8
local T_MAX = 4800
local TAG = "scen-bus-goulot"

local function stock_chest(chest)
  for _, it in ipairs({
    { "iron-plate", 4000 }, { "copper-plate", 400 }, { "coal", 200 }, { "transport-belt", 300 }, { "inserter", 60 }, { "splitter", 3 },
    { "small-electric-pole", 40 }, { "medium-electric-pole", 20 }, { "iron-chest", 20 },
  }) do
    chest.insert({ name = it[1], count = it[2] })
  end
end

local function belt_at(s, x, y) return s.find_entities_filtered({ position = { x + 0.5, y + 0.5 }, radius = 0.4, type = "transport-belt", limit = 1 })[1] end
local function belt_items(s, x, y)
  local b = belt_at(s, x, y)
  if not b then return -1 end
  local n = 0
  for i = 1, 2 do n = n + b.get_transport_line(i).get_item_count() end
  return n
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

local function arena(ctx, st)
  local s = ctx.surface()
  local eei = s.create_entity({ name = "electric-energy-interface", position = { 36.5, 6.5 }, force = "player" })
  if eei then eei.electric_buffer_size = BUF; eei.power_production = 0; eei.power_usage = 0; eei.energy = BUF; st.eei = eei end
  local function pole(x, y) s.create_entity({ name = "medium-electric-pole", position = { x + 0.5, y + 0.5 }, force = "player" }) end
  for x = 36, 84, 8 do pole(x, 4) end
  pole(36, -2); pole(36, -8)
  for x = 44, 92, 8 do pole(x, -8) end
  for y = 10, 30, 6 do pole(36, y) end
  for x = 36, 84, 8 do pole(x, 32) end
  local n, m = 0, 0
  for x = 31, 89 do
    if s.create_entity({ name = "transport-belt", position = { x + 0.5, -9.5 }, direction = defines.direction.east, force = "player" }) then n = n + 1 end
    if s.create_entity({ name = "transport-belt", position = { x + 0.5, 40.5 }, direction = defines.direction.east, force = "player" }) then m = m + 1 end
  end
  ctx.check(n == 59 and m == 59, "bus et tapis clairseme poses (59 + 59 tuiles)", n .. "+" .. m)
  local sink_arm = s.create_entity({ name = "inserter", position = { 90.5, -9.5 }, direction = defines.direction.west, force = "player" })
  local sink = s.create_entity({ name = "iron-chest", position = { SINK.x + 0.5, SINK.y + 0.5 }, force = "player" })
  if sink_arm then sink_arm.active = false end -- SORTIE BOUCHÉE
  ctx.check(sink_arm ~= nil and sink ~= nil, "sortie du bus posee puis bouchee (bras arrete)")
  local ok = s.create_entity({ name = "iron-chest", position = { DOCK_B.x + 0.5, DOCK_B.y + 0.5 }, force = "player" }) ~= nil
  for _, d in ipairs(DOCKS_A) do ok = (s.create_entity({ name = "iron-chest", position = { d.x + 0.5, d.y + 0.5 }, force = "player" }) ~= nil) and ok end
  ctx.check(ok, "coffres de quai poses (B et trois A)")
end

local function feed(s, tick)
  local b = belt_at(s, 31, -10)
  if b then for i = 1, 2 do local l = b.get_transport_line(i); if l.can_insert_at_back() then l.insert_at_back({ name = ITEM, count = 1 }) end end end
  if tick % 30 == 0 then
    local c = belt_at(s, 31, 40)
    if c then local l = c.get_transport_line(1); if l.can_insert_at_back() then l.insert_at_back({ name = ITEM, count = 1 }) end end
  end
  local e = belt_at(s, 89, 40)
  if e then for i = 1, 2 do e.get_transport_line(i).clear() end end
end

local function set_count(s, x, y, n)
  local c = s.find_entities_filtered({ position = { x + 0.5, y + 0.5 }, radius = 0.4, type = "container", limit = 1 })[1]
  if c then c.clear_items_inside(); if n > 0 then c.insert({ name = ITEM, count = n }) end end
end

return {
  description = "s43 scen-energie : goulot sur un bus (sortie bouchee), trois quais plus gourmands sans surplus",
  base = nil,
  check_tick = 5900,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    shape(ctx)
    game.forces.player.recipes["splitter"].enabled = true
    ctx.check(ctx.call("war_setting", "fo-war-ia3e", false) == false, "reglage fo-war-ia3e coupe (le banc est le cerveau)")
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
    local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if not chest then return end
    stock_chest(chest)
    ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 1 }) == true, "plan directeur active")
    arena(ctx, st)
    set_count(s, DOCK_B.x, DOCK_B.y, 400)
    for _, d in ipairs(DOCKS_A) do set_count(s, d.x, d.y, 400) end
    local names = { arm = "inserter", pole = "small-electric-pole" }
    local pa = {}
    for i, d in ipairs(DOCKS_A) do
      pa[i] = ctx.remote("fo-piquage", "inject", "player", { quais = { { x = d.x + 0.5, y = d.y + 0.5, item = ITEM } }, inflow = { [ITEM] = 2.0 }, names = names })
    end
    st.pb = ctx.remote("fo-piquage", "inject", "player", { quais = { { x = DOCK_B.x + 0.5, y = DOCK_B.y + 0.5, item = ITEM } }, inflow = { [ITEM] = 1.0 }, names = names })
    ctx.check(st.pb ~= nil and pa[1] ~= nil and pa[2] ~= nil and pa[3] ~= nil, "quatre modules finis fictifs injectes", tostring(st.pb))
    ctx.check(ctx.remote("fo-piquage", "set_param", "player", "sans_centrale", true) == true, "sans centrale (banc)")
    ctx.check(ctx.remote("fo-piquage", "set_param", "player", "period", 120) == 120, "releve toutes les 120 ticks")
    ctx.check(ctx.remote("fo-piquage", "set_param", "player", "confirm", 1) == 1, "confirmation en un releve")
    ctx.check(ctx.remote("fo-piquage", "set_param", "player", "disc_every", 300) == 300, "decouverte toutes les 300 ticks (banc)")
    for _, b in ipairs(s.find_entities_filtered({ area = { { 30, -11 }, { 91, -9 } }, name = "transport-belt" })) do
      for i = 1, 2 do for _ = 1, 4 do b.get_transport_line(i).insert_at_back({ name = ITEM, count = 1 }) end end
    end
    st.t0 = game.tick
    st.log_next = 0
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.t0 then return end
    local s = ctx.surface()
    local t = e.tick - st.t0
    if st.eei and st.eei.valid then st.eei.energy = BUF end
    feed(s, e.tick)
    if t % 60 == 0 then
      st.dn, st.ds = (st.dn or 0) + 1, (st.ds or 0) + belt_items(s, 70, -10)
      st.cn, st.cs = (st.cn or 0) + 1, (st.cs or 0) + math.max(0, belt_items(s, 60, 40))
    end
    local pq = ctx.remote("fo-piquage", "report", "player")
    local kb = tostring(st.pb) .. ":q1"
    if pq and not st.t_b then
      for _, l in ipairs(pq.links or {}) do if l.dock == kb then st.t_b = t end end
    end
    if t >= st.log_next then
      st.log_next = t + 600
      ctx.log(string.format("[%s] t=%d : demandes %s | lien du quai B %s | tuile du bus (70) %d objet(s) | tuile clairsemee (60) %d", TAG, t,
        pq and tostring(pq.n.demandes) or "-", st.t_b and ("a t=" .. st.t_b) or "aucun", belt_items(s, 70, -10), belt_items(s, 60, 40)))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local pq = ctx.remote("fo-piquage", "report", "player")
    local dens = (st.ds or 0) / math.max(1, st.dn or 0)
    local sparse = (st.cs or 0) / math.max(1, st.cn or 0)
    ctx.check(dens >= 6, string.format("le bus est sature (densite moyenne %.1f objets par tuile)", dens))
    ctx.check(sparse < 6, string.format("le tapis des quais A n'est pas dense (%.1f)", sparse))
    local ok = st.t_b ~= nil and st.t_b <= T_MAX
    ctx.check(ok, "le goulot est vu : piquage (ou ligne) demande pour le quai B en moins de " .. T_MAX .. " ticks", tostring(st.t_b))
    ctx.log(string.format("[%s] RESULTAT densite_bus=%.1f densite_clairseme=%.1f demandes=%s lien_B_t=%s verdict=%s", TAG, dens, sparse,
      pq and tostring(pq.n.demandes) or "-", tostring(st.t_b or "jamais"), ok and "OK" or "ECHEC"))
  end,
}
