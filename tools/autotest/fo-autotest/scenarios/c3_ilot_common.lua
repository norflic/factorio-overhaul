--[[
  Banc « c3-ilot » du lot C3 EXTENSION (point 4 ÎLOTS ; AUDIT_PLAFONDS n°11 et 12 ; PLAN INDUSTRIE I8, D4) : l'enceinte ne fige plus la croissance, la
  base grandit en îlots hors du mur. 20 000 ticks, votre équipe + plan directeur « seul » (comme tests de la série ind-treillis), sans guerre.

  Cadre : terrain vidé et refait en herbe (corridor de 400 x 400 tuiles), coffre d'équipe en (0, 0), plan directeur au rayon 3 (l'équipe l'élargit
  d'elle-même à 5, Build.RADIUS_MAX) ; un TAPIS de minerai couvre tous les lots des anneaux 1 à 5 (état « gisement » : ni libre, ni utilisable par
  un module), si bien que le rayon 5 n'a plus aucun lot libre, comme une base dont tous les lots sont pris. Quand les lots sont évalués, une enceinte
  COMPLÈTE à contour serré est posée SANS murs (« fo-ext » stage_enclosure : les murs, leur fabrication et leur pose ne sont pas l'objet de ce banc,
  ils ont leur banc hors jeu, tests/enceinte_flux_test.lua et ilots_flux_test.lua).
  Attendu (réglage maître fo-war-industrie ALLUMÉ) : la porte des îlots s'ouvre (journal [FO-EXTENSION]), le treillis grandit AU-DELA du rayon de
  l'enceinte (6, puis plus si besoin, jusqu'à Build.RADIUS_ORE) parce qu'il manque de lots libres, et les lots neufs, dehors du contour, sont LIBRES
  et non écartés : des îlots possibles.
  Témoin (réglage maître ÉTEINT) : le rayon reste figé à celui de l'enceinte, aucun lot libre de plus.
  Non prouvé ici : un module POSÉ sur ces lots (il lui faut un réseau électrique : « pas de rue vers le reseau » à l'essai 3, aucune centrale en 5 min),
  le mur d'un îlot FINI et ses tourelles (aucun module n'est fini en 5 min) ; voir le rapport du lot.
  Lancement : banc.py ... -- 20000 c3-ilot <source> ; journal : [FO-C3-ILOT] + [FO-EXTENSION] du mod.
]]
local MIN = 3600
local CHECK = 19700 -- (le contrôle précède la fin du banc de 20 000 ticks)
local T_STAGE_MIN = 400

local function sorted_keys(t)
  local k = {}
  for x in next, t or {} do k[#k + 1] = x end
  table.sort(k, function(a, b) return tostring(a) < tostring(b) end)
  return k
end

local function stock_chest(chest)
  for _, it in ipairs({
    { "iron-plate", 3000 }, { "copper-plate", 800 }, { "coal", 1500 }, { "stone", 400 },
    { "inserter", 200 }, { "transport-belt", 400 }, { "medium-electric-pole", 100 }, { "small-electric-pole", 100 },
    { "assembling-machine-1", 20 }, { "iron-chest", 30 }, { "firearm-magazine", 200 }, { "stone-wall", 200 }, { "gun-turret", 10 },
  }) do
    chest.insert({ name = it[1], count = it[2] })
  end
end

local function shape(ctx)
  local s = ctx.surface()
  s.request_to_generate_chunks({ 0, 0 }, 8)
  s.force_generate_chunk_requests()
  local area = { { -200, -200 }, { 200, 200 } }
  for _, e in ipairs(s.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
    if e.valid then e.destroy() end
  end
  local tiles = {}
  for y = -200, 199 do for x = -200, 199 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
  s.set_tiles(tiles, true)
  -- Un TAPIS de minerai sur les lots des anneaux 1 à 5 (centre de lot = (28 i, 28 j), disque de 6 tuiles, 113 tuiles >= P.MIN_RES_TILES) : ces lots sont
  -- des « gisements », pas des lots libres : il ne reste de place qu'APRÈS l'anneau 5 (rayon maximal ordinaire).
  local n = 0
  for i = -5, 5 do
    for j = -5, 5 do
      if math.max(math.abs(i), math.abs(j)) >= 1 then
        for dy = -6, 6 do
          for dx = -6, 6 do
            if dx * dx + dy * dy <= 36 and s.create_entity({ name = "coal", position = { 28 * i + dx + 0.5, 28 * j + dy + 0.5 }, amount = 200 }) then n = n + 1 end
          end
        end
      end
    end
  end
  return n
end

--- Lots utilisés par un projet et entièrement dehors du contour (écart d'au moins 3 tuiles, comme I.outside).
local function outside_used(layout, bounds)
  local n, keys = 0, {}
  for _, l in ipairs(layout.lots or {}) do
    if l.used and l.state ~= "gisement" then
      local dx = math.max(l.x0 - (bounds[3] + 1), bounds[1] - l.x1, 0)
      local dy = math.max(l.y0 - (bounds[4] + 1), bounds[2] - l.y1, 0)
      if math.max(dx, dy) >= 3 then
        n = n + 1
        keys[#keys + 1] = l.i .. ":" .. l.j
      end
    end
  end
  return n, keys
end

--- on : réglage maître allumé (faux : le témoin).
return function(on)
  local TAG = "FO-C3-ILOT" .. (on and "" or "-TEMOIN")
  return {
    description = "C3 EXTENSION : le treillis grandit au-dela du mur, en ilots" .. (on and "" or " (temoin)"),
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local v = ctx.remote("factorio-overhaul", "war_setting", "fo-war-industrie", on)
      ctx.check(v == on, "reglage maitre fo-war-industrie " .. (on and "allume" or "eteint"), tostring(v))
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
      local carpet = shape(ctx)
      ctx.log(string.format("[%s] terrain : %d tuiles de charbon posees sur les lots des anneaux 1 a 5", "FO-C3-ILOT", carpet))
      local chest = ctx.surface().create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      if not chest then return end
      stock_chest(chest)
      ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 3 }) == true, "plan directeur active au rayon 3")
      local st = ctx.state()
      st.t0 = game.tick
      st.max_radius, st.gates, st.ids = 0, {}, {}
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.t0 then return end
      local t = e.tick - st.t0
      if t < T_STAGE_MIN or t % 60 ~= 0 then return end
      local rep = ctx.remote("fo-ia1d", "report", "player")
      local ext = ctx.remote("fo-ext", "status", "player")
      if not (rep and ext and ext.build) then return end
      st.max_radius = math.max(st.max_radius, ext.build.radius or 0)
      if ext.build.gate and not st.gates[ext.build.gate] then
        st.gates[ext.build.gate] = e.tick
        ctx.log(string.format("[%s] tick %d : porte des ilots %s", TAG, e.tick, ext.build.gate))
      end
      if not st.staged and (rep.queue or 1) == 0 then
        local r = ctx.remote("fo-ext", "stage_enclosure", "player")
        st.staged = e.tick
        st.bounds = r and r.bounds
        st.enc_r = ext.build.radius
        ctx.log(string.format("[%s] tick %d : enceinte complete posee (sans murs) : contour %s, rayon %s, %s lot(s) ecarte(s) ; %d lot(s) evalues",
          TAG, e.tick, r and table.concat(r.bounds, ",") or "?", tostring(st.enc_r), r and tostring(r.out) or "?", ext.build.lots or 0))
        ctx.check(r ~= nil, "enceinte complete posee")
      end
      if st.staged and st.bounds and t % 600 == 0 then
        st.free_max = math.max(st.free_max or 0, ext.build.free or 0)
        local lay = ctx.remote("fo-ia1d", "layout", "player")
        local n, keys = outside_used(lay or {}, st.bounds)
        st.outside = math.max(st.outside or 0, n)
        st.outside_keys = n > 0 and keys or st.outside_keys
        local states = {}
        for _, k in ipairs(sorted_keys(rep.lots or {})) do states[#states + 1] = k .. "=" .. rep.lots[k] end
        ctx.log(string.format("[%s] tick %d | rayon %s (enceinte %s) | porte %s | lots %s dont ecartes %s, libres %s {%s} | lots pris dehors du contour %d | ilots %s | projets %s",
          TAG, e.tick, tostring(ext.build.radius), tostring(st.enc_r), tostring(ext.build.gate), tostring(ext.build.lots), tostring(ext.build.lots_out),
          tostring(ext.build.free), table.concat(states, " "), n, tostring(ext.build.islands), table.concat(ext.build.projects or {}, " ")))
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local ext = ctx.remote("fo-ext", "status", "player")
      local b = ext and ext.build
      local gates = {}
      for _, g in ipairs(sorted_keys(st.gates or {})) do gates[#gates + 1] = g .. " @" .. st.gates[g] end
      ctx.log(string.format("[%s] fin : rayon %s (enceinte %s, maximum vu %s) ; lots libres au plus %s ; portes vues : %s",
        TAG, tostring(b and b.radius), tostring(st.enc_r), tostring(st.max_radius), tostring(st.free_max), table.concat(gates, " | ")))
      ctx.check(st.staged ~= nil, "l'enceinte a ete posee (cadre du banc)", tostring(st.staged))
      if on then
        local opened = false
        for _, g in ipairs(sorted_keys(st.gates or {})) do if g:find("ouverte", 1, true) then opened = true end end
        ctx.check(opened, "la porte des ilots s'est ouverte (journal)", table.concat(gates, " | "))
        ctx.check((st.max_radius or 0) > (st.enc_r or 99), "le treillis a grandi AU-DELA du rayon de l'enceinte", string.format("%s > %s", tostring(st.max_radius), tostring(st.enc_r)))
        ctx.check((st.free_max or 0) >= 3, "des lots LIBRES et non ecartes sont apparus hors du mur (ilots possibles)", tostring(st.free_max))
      else
        ctx.check((st.max_radius or 0) <= (st.enc_r or 0), "temoin : le rayon reste fige a celui de l'enceinte", string.format("%s <= %s", tostring(st.max_radius), tostring(st.enc_r)))
        ctx.check((st.free_max or 0) < 3, "temoin : aucun lot libre de plus (le treillis ne grandit pas)", tostring(st.free_max))
      end
    end,
  }
end
