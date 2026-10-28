--[[
  Lot CAPIB (27/10 soir) : banc « la capitalisation branchée » (critères (1) à (5) du DC, OBJECTIFS §4, 12 h 30 ;
  fo-logs/2026-10-27_CAPI/BRANCHEMENT.md). Le banc NE POSE RIEN à la place des factions : protocole ia1b-scale30
  (4 factions, 30 PNJ, Paisible, financées de 2 500 fer, frein par le travail levé), 90 min, et deux réglages de carte :
    variante « partie »  : fo-war-ia3e ET fo-war-capi ALLUMÉS (la capitalisation décide, l'automatisation exécute) ;
    variante « temoin »  : fo-war-ia3e allumé, fo-war-capi ÉTEINT (même partie : AUTO et SCALE décident).
  Toutes les 10 min, par faction ([FO-CAPI-<VARIANTE>] « courbe ») : foreuses électriques et à combustion, fours,
  assembleurs, laboratoires de la force (toute la surface), minerai extrait et plaques produites dans les 10 min
  (statistiques de production de la force), part des PNJ sans tâche, technologies faites. Toutes les 10 min aussi
  (« gisements ») : chaque gisement recensé par la capitalisation, sa couverture RELUE ICI (tuiles de minerai sous
  l'aire d'au moins une foreuse de la force, aire lue sur le prototype), indépendamment du runtime ; (« fonte ») : fours
  de la force sans ingrédient (affamés), foreuses dont la sortie est pleine (minerai qui s'entasse).
  Images (session avec images seulement : un joueur connecté) : ×8 hors des moments de photo ; à 30, 60 et 90 min, par
  faction, la base (zoom 0,18) et le gisement exploité le plus couvert, cadré sur sa boîte (1600 × 900).
  Lancement : banc.py --out <archive> --qui CAPIB [--graine N] -- 324200 capi-partie <source> ;
  images : banc.py ... --captures --visuel="--ticks 324400 --timeout 5400" -- 324400 capi-partie <source>.
  Lecture : py -3.9 -B tools/autotest/capi_mesures.py <archives>.
]]

local MIN = 3600
local T_END = 90 * MIN
local EVERY = 10 * MIN
local PHOTOS = { [30 * MIN] = "30min", [60 * MIN] = "60min", [90 * MIN] = "90min" }
local N = 30

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function factions(ctx)
  local out = {}
  for _, row in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if row.key ~= "player" then out[#out + 1] = row end
  end
  return out
end

local function capi_status(key)
  if not (remote.interfaces["fo-capi"] and remote.interfaces["fo-capi"].status) then return nil end
  return remote.call("fo-capi", "status", key)
end

local function hq_of(ctx, force)
  return ctx.surface().find_entities_filtered({ name = "fo-faction-hq", force = force, limit = 1 })[1]
end

local function place_team_chest(ctx)
  local s = ctx.surface()
  local c = game.forces.player.get_spawn_position(s)
  local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
  local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
  if not chest then return false end
  for _, it in ipairs({ { "iron-plate", 2500 }, { "copper-plate", 400 }, { "coal", 300 }, { "stone", 100 },
    { "burner-mining-drill", 8 }, { "stone-furnace", 8 }, { "iron-chest", 4 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  return true
end

local ORES = { "iron-ore", "copper-ore", "coal", "stone" }
local PLATES = { "iron-plate", "copper-plate", "stone-brick", "steel-plate", "iron-gear-wheel", "electronic-circuit",
  "automation-science-pack", "logistic-science-pack", "military-science-pack" }

--- Couverture RELUE d'un gisement (boîte et minerai du recensement) : tuiles de minerai sous l'aire d'une foreuse.
local function coverage(s, force, d)
  local idx = {}
  local n_res = 0
  for _, e in ipairs(s.find_entities_filtered({ area = { { d.x0, d.y0 }, { d.x1, d.y1 } }, name = d.resource })) do
    idx[math.floor(e.position.x) .. "," .. math.floor(e.position.y)] = true
    n_res = n_res + 1
  end
  local seen, n = {}, 0
  local drills = s.find_entities_filtered({ area = { { d.x0 - 3, d.y0 - 3 }, { d.x1 + 3, d.y1 + 3 } }, force = force,
    type = "mining-drill" })
  local kinds = {}
  for _, dr in ipairs(drills) do
    local r = dr.prototype.mining_drill_radius or 1
    local p = dr.position
    kinds[dr.name] = (kinds[dr.name] or 0) + 1
    for x = math.floor(p.x - r + 0.01), math.floor(p.x + r - 0.01) do
      for y = math.floor(p.y - r + 0.01), math.floor(p.y + r - 0.01) do
        local k = x .. "," .. y
        if idx[k] and not seen[k] then seen[k] = true n = n + 1 end
      end
    end
  end
  return n, n_res, #drills, kinds
end

local function snap(ctx, name, x, y, zoom)
  local player = game.connected_players[1]
  if not player then return false end
  game.take_screenshot({ player = player, surface = ctx.surface(), position = { x, y }, resolution = { 1600, 900 },
    zoom = zoom, path = "fo-shots/capi-" .. name .. ".png", show_entity_info = true, anti_alias = true, daytime = 0,
    allow_in_replay = true, force_render = true })
  ctx.log(string.format("capture capi-%s (%.1f, %.1f) zoom %.2f", name, x, y, zoom))
  return true
end

local function photos(ctx, moment)
  local s = ctx.surface()
  for _, row in ipairs(factions(ctx)) do
    local hq = hq_of(ctx, row.force)
    if hq then
      snap(ctx, row.key .. "-" .. moment .. "-base", hq.position.x, hq.position.y, 0.18)
      -- gisement exploité le plus couvert (foreuses de la force), cadré sur sa boîte
      local st = capi_status(row.key)
      local best, bn = nil, 0
      for _, d in ipairs(st and st.deps or {}) do
        local n = coverage(s, row.force, d)
        if n > bn then best, bn = d, n end
      end
      if best then
        local w, h = math.max(8, best.x1 - best.x0 + 8), math.max(8, best.y1 - best.y0 + 8)
        local zoom = math.min(1600 / (32 * w), 900 / (32 * h))
        if zoom > 1 then zoom = 1 end
        if zoom < 0.2 then zoom = 0.2 end
        snap(ctx, row.key .. "-" .. moment .. "-gisement", (best.x0 + best.x1) / 2, (best.y0 + best.y1) / 2, zoom)
      else
        -- sans gisement recensé (témoin) : le plus grand groupe de foreuses de la force près du QG
        local drills = s.find_entities_filtered({ position = hq.position, radius = 160, force = row.force, type = "mining-drill" })
        if #drills > 0 then
          local sx, sy = 0, 0
          for _, dr in ipairs(drills) do sx, sy = sx + dr.position.x, sy + dr.position.y end
          snap(ctx, row.key .. "-" .. moment .. "-foreuses", sx / #drills, sy / #drills, 0.35)
        end
      end
    end
  end
end

return function(variant)
  local CAPI_ON = variant ~= "temoin"
  local tag = variant
  return {
    description = "CAPIB : capitalisation (" .. tag .. ") : 4 factions x 30 PNJ, Paisible, 90 min",
    base = nil,
    check_tick = T_END + 60,

    init = function(ctx)
      local held = ctx.remote("fo-ia1", "set_setting", "fo-recruit-idle-max", 60)
      ctx.check(held == 60, "frein par le travail leve (fo-recruit-idle-max = 60)", held)
      local workers = ctx.remote("factorio-overhaul", "war_setting", "fo-war-workers", N)
      ctx.check(workers == N, "fo-war-workers regle a " .. N, workers)
      local a = ctx.call("war_setting", "fo-war-ia3e", true)
      ctx.check(a == true, "reglage fo-war-ia3e allume", tostring(a))
      local c = ctx.call("war_setting", "fo-war-capi", CAPI_ON)
      ctx.check(c == CAPI_ON, "reglage fo-war-capi " .. (CAPI_ON and "allume" or "eteint"), tostring(c))
      local ok = ctx.remote("fo-pvp", "set_difficulty", "peaceful")
      ctx.check(ok == true, "difficulte Paisible imposee avant la guerre")
      local started = ctx.call("war_start", 4, 100)
      ctx.check(started == true, "guerre lancee (4 factions)")
      local funded = ctx.call("war_fund", 2500)
      ctx.check(funded == 4, "4 factions financees (2 500 fer)", funded)
      ctx.check(place_team_chest(ctx), "coffre d'equipe pose et garni")
      ctx.call("profiler", true)
      local st = ctx.state()
      st.prev, st.prod = {}, {}
    end,

    tick = function(ctx, e)
      if #game.connected_players > 0 then
        local want = 8
        for t in pairs(PHOTOS) do if e.tick >= t - 600 and e.tick <= t + 120 then want = 1 end end
        if game.speed ~= want then game.speed = want end
        if PHOTOS[e.tick] then photos(ctx, PHOTOS[e.tick]) end
      end
      if e.tick % EVERY ~= 0 or e.tick == 0 then return end
      local st = ctx.state()
      local minute = e.tick / MIN
      local s = ctx.surface()
      for _, r in ipairs(factions(ctx)) do
        local force = game.forces[r.force]
        local prev = st.prev[r.key] or { n_sum = 0, idle_sum = 0 }
        local dn = r.n_sum - prev.n_sum
        local idle_pct = dn > 0 and (100 * (r.idle_sum - prev.idle_sum) / dn) or 0
        st.prev[r.key] = { n_sum = r.n_sum, idle_sum = r.idle_sum }
        local cnt = {}
        local drills_e, drills_b = 0, 0
        for _, d in ipairs(s.find_entities_filtered({ force = r.force, type = "mining-drill" })) do
          if d.prototype.electric_energy_source_prototype then drills_e = drills_e + 1 else drills_b = drills_b + 1 end
        end
        for _, ty in ipairs({ "furnace", "assembling-machine", "lab" }) do
          cnt[ty] = s.count_entities_filtered({ force = r.force, type = ty })
        end
        -- production des 10 min
        local stats = force and force.item_production_statistics
        local pp = st.prod[r.key] or {}
        local made = {}
        for _, it in ipairs(ORES) do
          local v = stats and stats.get_input_count(it) or 0
          made[it] = v - (pp[it] or 0)
          pp[it] = v
        end
        for _, it in ipairs(PLATES) do
          local v = stats and stats.get_input_count(it) or 0
          made[it] = v - (pp[it] or 0)
          pp[it] = v
        end
        st.prod[r.key] = pp
        local function mk(list)
          local o = {}
          for _, it in ipairs(list) do o[#o + 1] = it .. "=" .. made[it] end
          return table.concat(o, " ")
        end
        ctx.log(string.format("courbe minute %d | %s | foreuses_elec=%d foreuses_comb=%d fours=%d assembleurs=%d labos=%d | n=%d inactifs=%.1f%% tech=%d | extrait10 %s | produit10 %s",
          minute, r.key, drills_e, drills_b, cnt.furnace, cnt["assembling-machine"], cnt.lab, r.n, idle_pct, r.tech or -1,
          mk(ORES), mk(PLATES)))
        -- fonte : fours affamés, foreuses à sortie pleine
        -- fours classés : « paire » (nourri directement par une foreuse : avant-poste à combustion), « qg » (à moins de
        -- 40 tuiles du QG, nourris par les PNJ), « module » (les autres : fonderies du plan directeur, sur tapis)
        local fed = {}
        local full, dr = 0, 0
        for _, d in ipairs(s.find_entities_filtered({ force = r.force, type = "mining-drill" })) do
          dr = dr + 1
          if d.status == defines.entity_status.waiting_for_space_in_destination then full = full + 1 end
          local t = d.drop_target
          if t and t.valid and t.unit_number then fed[t.unit_number] = true end
        end
        local hq = hq_of(ctx, r.force)
        local cat = { paire = { 0, 0 }, qg = { 0, 0 }, module = { 0, 0 } }
        local starve, fur = 0, 0
        for _, fu in ipairs(s.find_entities_filtered({ force = r.force, type = "furnace" })) do
          fur = fur + 1
          local k = "module"
          if fed[fu.unit_number] then k = "paire"
          elseif hq and (fu.position.x - hq.position.x) ^ 2 + (fu.position.y - hq.position.y) ^ 2 <= 1600 then k = "qg" end
          cat[k][1] = cat[k][1] + 1
          if fu.status == defines.entity_status.no_ingredients then
            starve = starve + 1
            cat[k][2] = cat[k][2] + 1
          end
        end
        ctx.log(string.format("fonte minute %d | %s | fours %d affames %d | foreuses %d sortie_pleine %d | paire %d/%d qg %d/%d module %d/%d",
          minute, r.key, fur, starve, dr, full, cat.paire[2], cat.paire[1], cat.qg[2], cat.qg[1], cat.module[2], cat.module[1]))
        local cs = capi_status(r.key)
        local parts = {}
        for _, d in ipairs(cs and cs.deps or {}) do
          local n, nres, ndr, kinds = coverage(s, r.force, d)
          local ks = {}
          for _, k in ipairs(sorted_keys(kinds)) do ks[#ks + 1] = k .. ":" .. kinds[k] end
          parts[#parts + 1] = string.format("%s[%s] tuiles=%d/%d couvertes=%d foreuses=%d {%s}", d.id, d.resource, nres, d.tiles,
            n, ndr, table.concat(ks, ","))
        end
        if cs then
          local stats2 = {}
          for _, k in ipairs(sorted_keys(cs.stats or {})) do stats2[#stats2 + 1] = k .. "=" .. cs.stats[k] end
          ctx.log(string.format("gisements minute %d | %s | decisions %d ordres %d ouverts %d [%s] | %s", minute, r.key,
            cs.decisions or 0, cs.orders or 0, #(cs.open or {}), table.concat(stats2, " "), table.concat(parts, " ; ")))
        end
      end
    end,

    finish = function(ctx)
      local rows = factions(ctx)
      ctx.check(#rows >= 1, "factions vivantes a 90 min", #rows)
      local dec = 0
      for _, r in ipairs(rows) do
        local cs = capi_status(r.key)
        dec = dec + ((cs and cs.decisions) or 0)
        ctx.log(string.format("fin %s : tech %d, n %d, decisions capi %d, ordres %d", r.key, r.tech or -1, r.n,
          (cs and cs.decisions) or 0, (cs and cs.orders) or 0))
      end
      if CAPI_ON then
        ctx.check(dec > 0, "la capitalisation a decide (lignes [FO-CAPI])", dec)
      else
        ctx.check(dec == 0, "temoin : aucune decision de la capitalisation", dec)
      end
    end,

    shots = function(ctx, add)
      local s = ctx.surface()
      for _, row in ipairs(factions(ctx)) do
        local hq = hq_of(ctx, row.force)
        if hq then add("capi-" .. row.key .. "-fin", hq.position.x, hq.position.y, 0.18) end
      end
    end,
    shots_delay = T_END + 120,
  }
end
