--[[
  Lot IA3-f : CAS DU DC du 25/10 vers 18 h 45 (OBJECTIFS §5 ; capture fo-logs\2026-10-25_DC-captures\
  pnj-inactifs-fer-ignore.png) : « ils farment de la pierre et du charbon et ils font rien de plus [...] mais n'explorent
  pas et regardent même pas autour d'eux ». Votre équipe seule (aucune faction), biters actifs (comme chez le DC).
  Monde préparé : tout le fer à moins de IRON_CLEAR tuiles du coffre est retiré ; charbon et pierre posés près du coffre
  (ce que les PNJ « farment ») ; UN gisement de fer posé à IRON_DIST tuiles, dans la première direction sans nid ni ver à
  120 tuiles : hors de l'œil du QG (160 + 32), donc inconnu au départ. Coffre : le kit du guide, mais 150 plaques de fer.

  Critère ajouté par le coordinateur (consigne du 25/10 vers 18 h 50) : un gisement de fer découvert PUIS exploité en
  moins de X min, sans mort d'éclaireur. X = 10 min depuis la pose du coffre : le tour du propriétaire (anneau de
  150 tuiles, environ 1 250 tuiles de marche à 9 tuiles par seconde : 2 min 30) voit le gisement avec un œil de 128 ;
  prospection (moins de 30 s), puis le constructeur marche 260 tuiles (30 s) et pose l'avant-poste ; un joueur qui
  arrive sans fer en vue fait de même en quelques minutes. Il reste plus de 5 min de marge pour une 2e mission si le
  tour est interrompu (fuite).
]]

local IaV2Off = require("scenarios/iav2_off") -- lot IA-V2 : témoin = bascules éteintes
local C = {}

C.IRON_CLEAR = 230
C.IRON_DIST = 260
C.X = 10 * 3600

local function key(p) return math.floor(p.x) .. "," .. math.floor(p.y) end

function C.setup(ctx, fog)
  local on = ctx.remote("fo-ia3f", "set_fog", fog)
  ctx.check(on == fog, "brouillard " .. (fog and "actif" or "coupe (avant le lot)"), tostring(on))
  -- Lot IA-V2 : le témoin rejoue 0.4.30 (cerveau d'avant, sans marché).
  if not fog then IaV2Off(ctx, { marche = false, cerveau = false }) end
  ctx.call("profiler", true)
  local s = ctx.surface()
  local c = game.forces.player.get_spawn_position(s)
  local chest_at = { x = math.floor(c.x) + 6.5, y = math.floor(c.y) + 6.5 }
  s.request_to_generate_chunks(chest_at, 11)
  s.force_generate_chunk_requests()
  -- Fer retiré autour du coffre.
  local removed = 0
  for _, e in ipairs(s.find_entities_filtered({ position = chest_at, radius = C.IRON_CLEAR, name = "iron-ore" })) do
    e.destroy()
    removed = removed + 1
  end
  -- Gisement de fer à IRON_DIST tuiles, première direction sûre (aucun nid ni ver à 120 tuiles, pas d'eau sous lui).
  local D = 0.70710678
  local dirs = { { 1, 0 }, { D, D }, { 0, 1 }, { -D, D }, { -1, 0 }, { -D, -D }, { 0, -1 }, { D, -D } }
  local site
  for _, d in ipairs(dirs) do
    local p = { x = math.floor(chest_at.x + d[1] * C.IRON_DIST) + 0.5, y = math.floor(chest_at.y + d[2] * C.IRON_DIST) + 0.5 }
    local enemies = s.count_entities_filtered({ position = p, radius = 120, force = "enemy", type = { "unit-spawner", "turret" }, limit = 1 })
    local water = s.count_tiles_filtered({ position = p, radius = 12, collision_mask = "water-tile", limit = 1 })
    if enemies == 0 and water == 0 then site = p break end
  end
  ctx.check(site ~= nil, "direction sure trouvee pour le gisement de fer", site and key(site) or "aucune")
  site = site or { x = chest_at.x + C.IRON_DIST, y = chest_at.y }
  local placed = 0
  for _, e in ipairs(s.find_entities_filtered({ position = site, radius = 11, type = { "tree", "simple-entity", "resource" } })) do e.destroy() end
  for dx = -9, 9 do
    for dy = -9, 9 do
      if dx * dx + dy * dy <= 81 then
        if s.create_entity({ name = "iron-ore", position = { site.x + dx, site.y + dy }, amount = 4000 }) then placed = placed + 1 end
      end
    end
  end
  -- Charbon et pierre près du coffre (ce que les PNJ du DC exploitaient).
  local function patch(name, dx, dy, r)
    local p = { x = chest_at.x + dx, y = chest_at.y + dy }
    for _, e in ipairs(s.find_entities_filtered({ position = p, radius = r + 1, type = { "tree", "simple-entity", "resource" } })) do e.destroy() end
    for x = -r, r do
      for y = -r, r do
        if x * x + y * y <= r * r then s.create_entity({ name = name, position = { p.x + x, p.y + y }, amount = 3000 }) end
      end
    end
  end
  patch("coal", -48, 10, 6)
  patch("stone", 10, -50, 5)
  local left = s.count_entities_filtered({ position = chest_at, radius = C.IRON_CLEAR, name = "iron-ore" })
  ctx.check(left == 0, "aucun fer a moins de " .. C.IRON_CLEAR .. " tuiles du coffre", string.format("%d retires, %d restants", removed, left))
  local dist = math.floor(math.sqrt((site.x - chest_at.x) ^ 2 + (site.y - chest_at.y) ^ 2))
  ctx.check(placed > 200, "gisement de fer pose hors de l'oeil du QG", string.format("%d tuiles en (%s), %d tuiles du coffre", placed, key(site), dist))
  local p = s.find_non_colliding_position("fo-team-chest", chest_at, 20, 1)
  local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
  if chest then
    for _, it in ipairs({ { "iron-plate", 150 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
      { "pistol", 3 }, { "firearm-magazine", 60 }, { "burner-mining-drill", 8 }, { "stone-furnace", 8 }, { "iron-chest", 4 } }) do
      chest.insert({ name = it[1], count = it[2] })
    end
  end
  ctx.check(chest ~= nil, "coffre d'equipe pose")
  local st = ctx.state()
  st.chest, st.site, st.placed_tick = chest, site, game.tick
end

local function report(ctx)
  local status = ctx.remote("fo-ia3f", "status")
  for _, r in ipairs(status.teams or {}) do if r.key == "player" then return r, status end end
  return nil, status
end

function C.poll(ctx, e, fog)
  local st = ctx.state()
  if e.tick == 120 and fog then
    st.seen_site0 = ctx.remote("fo-ia3f", "seen", "player", st.site.x, st.site.y)
    st.seen_chest0 = ctx.remote("fo-ia3f", "seen", "player", st.chest.position.x, st.chest.position.y)
  end
  if e.tick % 300 ~= 0 or e.tick == 0 then return end
  local r = report(ctx)
  if not r then return end
  st.r = r
  for _, x in ipairs(r.found or {}) do
    if x.res == "iron-ore" and not st.iron_found then st.iron_found = x.t end
  end
  local iron = r.outposts_at and r.outposts_at.iron or {}
  if iron[1] and not st.iron_out then st.iron_out = iron[1] end
  if r.site_at and r.site_at["iron-ore"] and not st.iron_site then st.iron_site = r.site_at["iron-ore"] end
  if fog and not st.seen_site and ctx.remote("fo-ia3f", "seen", "player", st.site.x, st.site.y) then st.seen_site = e.tick end
  if e.tick % 3600 == 0 then
    ctx.log(string.format("minute %d | secteurs %s | fer vu %s | site de fer %s | avant-poste de fer %s | missions %s fuites %s morts %s | tour %s | equipe : %s",
      e.tick / 3600, tostring(r.sectors), tostring(st.iron_found), tostring(st.iron_site), tostring(st.iron_out),
      tostring(r.missions), tostring(r.flees), tostring(r.deaths), tostring(r.tour), tostring((ctx.call("team_status") or ""):sub(1, 120))))
  end
end

function C.finish(ctx, fog)
  local st = ctx.state()
  local r = st.r or {}
  local t0 = st.placed_tick or 0
  ctx.log(string.format("MESURE %s joueur : fer_vu=%s site_fer=%s avant_poste_fer=%s (depuis la pose : %s ticks) morts=%s fuites=%s missions=%s secteurs=%s tour=%s audit=%s/%s",
    fog and "apres" or "avant", tostring(st.iron_found), tostring(st.iron_site), tostring(st.iron_out),
    tostring(st.iron_out and st.iron_out - t0), tostring(r.deaths), tostring(r.flees), tostring(r.missions), tostring(r.sectors),
    tostring(r.tour), tostring(r.audit_ok), tostring(r.audit_bad)))
  ctx.check(st.iron_out ~= nil and st.iron_out - t0 <= C.X, string.format("gisement de fer exploite (avant-poste) en moins de %d min",
    C.X / 3600), st.iron_out and string.format("%.1f min", (st.iron_out - t0) / 3600) or "jamais")
  return r
end

return C
