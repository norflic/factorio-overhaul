--[[
  Lot PD-CENTRALE (décision du DC D-24 (1) : étang garanti supprimé, centrale à l'eau la plus proche atteignable reliée par
  une ligne de poteaux). Banc court en moteur réel.

  Terrain : carré de 320 × 320 tuiles autour du point d'apparition VIDÉ (herbe, ni eau, ni arbre, ni ressource), donc AUCUNE
  eau dans le treillis (rayon 5, lots de −152 à 152) ; toute eau naturelle à moins de 352 tuiles changée en herbe ; un lac de
  26 × 31 tuiles posé à l'est, seule eau de la zone. Votre équipe (coffre garni) reçoit le plan directeur et UNE demande : la
  centrale à vapeur.
  Deux variantes (paramètre LAKE_X0) :
    pd-centrale        lac en x 186..211 : dans l'œil du QG (160 tuiles, carte de connaissance), hors du treillis, assez loin
                       pour que le carrefour le plus proche de la centrale soit hors du treillis (ligne de Far.line) ;
    pd-centrale-explo  lac en x 280..305 : HORS de l'œil du QG ; la centrale attend l'exploration (« il faut aller plus loin » :
                       demande d'exploration de l'eau). En 9 500 ticks, l'éclaireur (tour du propriétaire d'abord) n'atteint
                       pas toujours le lac : si la centrale n'est pas planifiée, le bilan contrôle l'ATTENTE d'exploration
                       (pas de refus) et le reste est mesuré hors bilan.

  Contrôles : la centrale est planifiée (pas refusée) HORS du treillis, sa pompe devant l'eau ; aucune tuile d'eau posée dans
  le treillis (plus d'étang) ; les poteaux du projet ne sont pas sur l'eau et forment UN seul réseau à portée de fil (de la
  centrale au carrefour de bord) ; au moins un poteau de ligne entre le treillis et la centrale. Mesuré (hors bilan) : pièces
  bâties et machine à vapeur au réseau à la fin.
  Lancement : banc.py ... -- 7300 pd-centrale <source> ; banc.py ... -- 9800 pd-centrale-explo <source> ; journal :
  [FO-PD-CENTRALE] ou [FO-PD-CENTRALE-EXPLO] (et [FO-CENTRALE-LOIN], [FO-IA3F] du mod).
]]

return function(LAKE_X0, CHECK_TICK, EXPLO)
local HALF = 160
local CLEAR = 352 -- eau naturelle changée en herbe dans ce carré (le lac du banc est la seule eau que l'œil d'un éclaireur trouve)
local LAKE = { x0 = LAKE_X0, y0 = -15, x1 = LAKE_X0 + 25, y1 = 15 }
local EDGE = 5 * 28 + 12 -- bord du treillis de rayon 5 (P.PITCH 28, P.HALF 12)
local T_REQUEST = 120

local function water_at(s, x, y)
  local t = s.get_tile(math.floor(x), math.floor(y))
  return t and t.valid and t.collides_with("water-tile")
end

return {
  description = "PD-CENTRALE : centrale lointaine sans etang garanti",
  check_tick = CHECK_TICK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    s.request_to_generate_chunks({ 0, 0 }, 12)
    s.force_generate_chunk_requests()
    local wet = {}
    for _, t in ipairs(s.find_tiles_filtered({ area = { { -CLEAR, -CLEAR }, { CLEAR, CLEAR } }, collision_mask = "water-tile" })) do
      wet[#wet + 1] = { name = "grass-1", position = t.position }
    end
    if #wet > 0 then s.set_tiles(wet, true) end
    ctx.log("eau naturelle changee en herbe : " .. #wet .. " tuile(s) ; lac du banc en x " .. LAKE.x0 .. ".." .. LAKE.x1)
    local area = { { -HALF, -HALF }, { HALF, HALF } }
    for _, e in ipairs(s.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
      if e.valid then e.destroy() end
    end
    local tiles = {}
    for y = -HALF, HALF - 1 do for x = -HALF, HALF - 1 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
    s.set_tiles(tiles, true)
    -- le lac (et une bande de terre dégagée autour, pour la centrale)
    local land, water = {}, {}
    for y = LAKE.y0 - 20, LAKE.y1 + 20 do
      for x = LAKE.x0 - 30, LAKE.x1 + 10 do
        if x >= LAKE.x0 and x <= LAKE.x1 and y >= LAKE.y0 and y <= LAKE.y1 then water[#water + 1] = { name = "water", position = { x, y } }
        else land[#land + 1] = { name = "grass-1", position = { x, y } } end
      end
    end
    for _, e in ipairs(s.find_entities_filtered({ area = { { LAKE.x0 - 30, LAKE.y0 - 20 }, { LAKE.x1 + 11, LAKE.y1 + 21 } },
      type = { "tree", "simple-entity", "cliff", "resource", "fish" } })) do
      if e.valid then e.destroy() end
    end
    s.set_tiles(land, true)
    s.set_tiles(water, true)
    -- le banc tient le rôle du cerveau : l'automatisation (fo-war-ia3e) éteindrait le plan directeur vide (Auto.IDLE_OFF)
    local a = ctx.call("war_setting", "fo-war-ia3e", false)
    ctx.check(a == false, "reglage fo-war-ia3e coupe (le banc est le cerveau)", tostring(a))
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
    local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if not chest then return end
    for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 200 }, { "coal", 400 }, { "wood", 100 },
      { "medium-electric-pole", 100 }, { "small-electric-pole", 100 }, { "boiler", 2 }, { "steam-engine", 2 }, { "offshore-pump", 2 },
      { "burner-inserter", 10 }, { "inserter", 10 }, { "iron-chest", 10 }, { "wooden-chest", 10 }, { "pipe", 20 } }) do
      chest.insert({ name = it[1], count = it[2] })
    end
    local ok = ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 5 })
    ctx.check(ok == true, "plan directeur active")
    st.t0 = game.tick
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.t0 then return end
    local t = e.tick - st.t0
    if t == T_REQUEST then
      st.pid = ctx.remote("fo-ia1d", "request", "player", { gen = "steam", args = { 1 }, feed = true })
      ctx.log("centrale demandee : projet " .. tostring(st.pid))
    end
    if st.pid and t > T_REQUEST and t % 600 == 0 then
      local p = ctx.remote("fo-ia1d", "status", "player", st.pid)
      if p then
        ctx.log(string.format("%.1f min : projet %d %s (%s/%s%s)", e.tick / 3600, st.pid, tostring(p.state), tostring(p.built), tostring(p.total),
          p.reason and (" " .. tostring(p.reason)) or ""))
        if not st.planned_at and p.state ~= "attente" and p.state ~= "plan" and p.state ~= "refuse" then st.planned_at = t end
      end
    end
  end,

  finish = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    local p = st.pid and ctx.remote("fo-ia1d", "status", "player", st.pid)
    if EXPLO and p and not st.planned_at then
      -- lac hors de l'œil du QG, pas encore vu : la centrale attend l'exploration (pas de refus, pas d'étang)
      ctx.check(p.state == "attente" and tostring(p.reason):find("exploration", 1, true) ~= nil,
        "centrale en attente d'exploration de l'eau (pas refusee)", tostring(p.state) .. " " .. tostring(p.reason))
      local n_water = s.count_tiles_filtered({ area = { { -EDGE, -EDGE }, { EDGE, EDGE } }, collision_mask = "water-tile" })
      ctx.check(n_water == 0, "aucune tuile d'eau posee dans le treillis (plus d'etang garanti)", n_water)
      ctx.log("mesure (hors bilan) : lac pas encore vu par l'exploration au controle ; pose de la centrale non controlee")
      return
    end
    ctx.check(p ~= nil and st.planned_at ~= nil, "centrale planifiee (pas refusee)", p and (tostring(p.state) .. " " .. tostring(p.reason)) or "pas de projet")
    local lay = ctx.remote("fo-ia1d", "layout", "player")
    local ents = {}
    for _, en in ipairs(lay and lay.ents or {}) do if en.pid == st.pid then ents[#ents + 1] = en end end
    local pump, poles, line, wet = nil, {}, 0, 0
    for _, en in ipairs(ents) do
      if en.name == "offshore-pump" then pump = en end
      if en.name:find("electric%-pole") then
        poles[#poles + 1] = en
        if en.x > EDGE and en.x < LAKE.x0 - 8 then line = line + 1 end
        if water_at(s, en.x, en.y) then wet = wet + 1 end
      end
    end
    ctx.check(pump ~= nil and pump.x > EDGE and pump.x >= LAKE.x0 - 4, "pompe hors du treillis, au lac", pump and string.format("(%.1f, %.1f)", pump.x, pump.y) or "aucune")
    if pump then
      local v = ({ [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } })[pump.dir or 0] or { 0, 0 }
      ctx.check(water_at(s, pump.x + v[1], pump.y + v[2]), "la pompe regarde l'eau")
    end
    -- plus d'étang : aucune tuile d'eau dans le treillis
    local n_water = s.count_tiles_filtered({ area = { { -EDGE, -EDGE }, { EDGE, EDGE } }, collision_mask = "water-tile" })
    ctx.check(n_water == 0, "aucune tuile d'eau posee dans le treillis (plus d'etang garanti)", n_water)
    ctx.check(line >= 1, "poteaux de ligne entre le treillis et la centrale", line)
    ctx.check(#poles >= 2 and wet == 0, "aucun poteau du projet sur l'eau", #poles .. " poteaux, " .. wet .. " sur l'eau")
    -- un seul réseau à portée de fil
    local seen, stack, comp = { [1] = true }, { 1 }, 1
    if #poles == 0 then stack, comp = {}, 0 end
    while #stack > 0 do
      local i = table.remove(stack)
      local a = poles[i]
      local ra = game.entity_prototypes[a.name].max_wire_distance
      for j, b in ipairs(poles) do
        if not seen[j] then
          local rb = game.entity_prototypes[b.name].max_wire_distance
          local r = math.min(ra, rb)
          if (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 <= r * r + 1e-6 then seen[j] = true comp = comp + 1 stack[#stack + 1] = j end
        end
      end
    end
    ctx.check(#poles > 0 and comp == #poles, "poteaux du projet relies a portee de fil (un seul reseau)", comp .. "/" .. #poles)
    local pl = {}
    for i, en in ipairs(poles) do pl[#pl + 1] = string.format("%d:%s(%.1f,%.1f)%s", i, en.name, en.x, en.y, seen[i] and "" or "*") end
    ctx.log("mesure (hors bilan) : poteaux du projet (* hors du reseau du premier) " .. table.concat(pl, " "))
    -- mesuré (hors bilan) : chantier et machine à vapeur au réseau
    local eng = s.find_entities_filtered({ name = "steam-engine", force = "player" })[1]
    ctx.log(string.format("mesure (hors bilan) : %s/%s pieces baties, etat %s, machine a vapeur %s%s", tostring(p and p.built), tostring(p and p.total),
      tostring(p and p.state), eng and string.format("en (%.1f, %.1f)", eng.position.x, eng.position.y) or "absente",
      eng and (" reseau " .. tostring(eng.electric_network_id)) or ""))
    if st.planned_at then ctx.log(string.format("mesure (hors bilan) : centrale planifiee a %.1f min apres la demande", st.planned_at / 3600)) end
  end,
}
end
