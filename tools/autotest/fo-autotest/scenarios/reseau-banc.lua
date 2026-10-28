--[[
  Lot RESEAU : le réseau électrique d'une équipe de PNJ en moteur réel (script/team/reseau_runtime.lua, interface « fo-reseau »).

  Terrain « plaine » du banc ia1-build (carré de 280 × 280 vidé, gisements de fer, de cuivre et de charbon, lac au sud).
  Votre équipe (coffre garni, 8 PNJ, plan directeur « seul ») bâtit une centrale (1 chaudière, 2 machines) et une fonderie
  de fer (foreuses électriques, bras, tapis). Puis, en phases (chacune JUGÉE sur le journal du mod, pas sur le banc) :
    1 relevé     le modèle voit ce que voit le moteur : composantes = réseaux du moteur (0 scission, 0 fusion), « hors de
                 portée » = « sans réseau » (0 désaccord) ;
    2 zones      trois assembleurs posés loin de tout poteau : deux zones non couvertes publiées, le moteur dit « sans réseau » ;
    3 poteau     le poteau PIVOT le plus lourd du relevé est tué (die) : le mod le relève (petit projet, PNJ, fantôme) et le
                 réseau revient (mêmes composantes, mêmes bâtiments alimentés) ;
    4 capacité   7 radars (300 kW chacun) sur un poteau de plus : la charge dépasse 80 % de la centrale, SANS seuil d'essai :
                 une centrale de plus est demandée, bâtie, et la production double.
  Lancement : fo-autotest.bat nopause 216000 reseau-banc <source> ; journal : [FO-RESEAU-BANC] + lignes [FO-RESEAU] du mod.
]]

local MIN = 3600
local HALF = 140
local T_REQUEST = 120
local T_BUILD_MAX = 40 * MIN
local WAIT_REPORT = 6000
local WAIT_REPAIR = 25 * MIN
local WAIT_PLANT = 40 * MIN
local CHECK = 215000

local function deposit(s, name, cx, cy, r, amount)
  for dy = -r, r do
    for dx = -r, r do
      if dx * dx + dy * dy <= r * r then s.create_entity({ name = name, position = { cx + dx + 0.5, cy + dy + 0.5 }, amount = amount }) end
    end
  end
end

local function shape(ctx, c)
  local s = ctx.surface()
  s.request_to_generate_chunks({ c.x, c.y }, 6)
  s.force_generate_chunk_requests()
  local area = { { c.x - HALF, c.y - HALF }, { c.x + HALF, c.y + HALF } }
  for _, e in ipairs(s.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
    if e.valid then e.destroy() end
  end
  local tiles = {}
  for y = c.y - HALF, c.y + HALF - 1 do for x = c.x - HALF, c.x + HALF - 1 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
  s.set_tiles(tiles, true)
  local water = {}
  for dy = -13, 13 do
    for dx = -13, 13 do
      if dx * dx + dy * dy <= 169 then water[#water + 1] = { name = "water", position = { c.x + 4 + dx, c.y + 76 + dy } } end
    end
  end
  s.set_tiles(water, true)
  deposit(s, "iron-ore", c.x + 56, c.y - 28, 10, 4000)
  deposit(s, "copper-ore", c.x - 56, c.y + 28, 10, 4000)
  deposit(s, "coal", c.x - 56, c.y - 56, 8, 3000)
end

local function stock_chest(chest)
  for _, it in ipairs({
    { "iron-plate", 3000 }, { "copper-plate", 800 }, { "coal", 2500 }, { "stone", 300 },
    { "electric-mining-drill", 20 }, { "stone-furnace", 30 }, { "transport-belt", 600 }, { "inserter", 150 },
    { "fast-inserter", 20 }, { "burner-inserter", 20 }, { "medium-electric-pole", 100 }, { "big-electric-pole", 30 },
    { "iron-chest", 30 }, { "boiler", 6 }, { "steam-engine", 12 }, { "offshore-pump", 4 },
    { "pistol", 10 }, { "firearm-magazine", 200 },
  }) do
    chest.insert({ name = it[1], count = it[2] })
  end
end

local function all_done(r)
  local n = 0
  for _, p in ipairs(r.projects) do
    if p.state ~= "fini" and p.state ~= "refuse" and p.state ~= "bloque" then return false end
    if p.state == "fini" then n = n + 1 end
  end
  return n >= 2
end

--- Réseaux distincts du moteur parmi les poteaux de la force (lecture du banc).
local function engine_networks(s)
  local ids, n, poles = {}, 0, 0
  for _, e in ipairs(s.find_entities_filtered({ type = "electric-pole", force = "player" })) do
    poles = poles + 1
    local id = e.electric_network_id
    if id and not ids[id] then ids[id] = true; n = n + 1 end
  end
  return n, poles
end

local function set_phase(st, name, tick)
  st.phase, st.t_phase, st.reqd = name, tick, nil
end

--- Relevé neuf demandé puis attendu (rend le rapport, ou nil tant qu'il n'est pas là).
local function fresh_report(ctx, st, e, alert)
  if not st.reqd then
    ctx.remote("fo-reseau", "survey_now", "player", alert)
    st.reqd = e.tick
    return nil
  end
  if (e.tick - st.reqd) % 60 ~= 0 then return nil end
  local r = ctx.remote("fo-reseau", "report", "player")
  if r and r.started and r.started >= st.reqd then return r end
  return nil
end

local function line(r)
  return string.format("poteaux %d, composantes %d, batiments %d (alimentes %d, hors de portee %d en %d zone(s), ilot %d), producteurs %d, production %.0f kW, sortie %.0f kW, niveau %s, moteur : scission %d fusion %d desaccord %d",
    r.poles, r.comps, r.consumers, r.powered, r.uncovered, r.n_zones or 0, r.orphans, r.producers, r.prod_kw or 0, r.out_kw or 0,
    tostring(r.level), r.check.comp_split, r.check.comp_merge, r.check.cover_disagree)
end

return {
  description = "RESEAU : relevé, zones non couvertes, poteau tué et relevé, centrale de plus (moteur réel)",
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    local c = { x = 0, y = 0 }
    st.c = c
    shape(ctx, c)
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
    local chest = s.create_entity({ name = "fo-team-chest", position = { c.x + 0.5, c.y + 0.5 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if not chest then return end
    stock_chest(chest)
    ctx.remote("factorio-overhaul", "profiler", true)
    ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 3 }) == true, "plan directeur active")
    st.t0 = game.tick
    st.phase = "build"
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.t0 then return end
    local t = e.tick - st.t0
    local s = ctx.surface()
    if t == T_REQUEST then
      st.ids = {
        plant = ctx.remote("fo-ia1d", "request", "player", { gen = "steam", args = { 1 }, feed = true }),
        iron = ctx.remote("fo-ia1d", "request", "player", { gen = "smelter", args = { "stone-furnace", "iron-ore", 3 }, feed = true }),
      }
      ctx.log(string.format("demandes : centrale %s, fer %s", tostring(st.ids.plant), tostring(st.ids.iron)))
      return
    end
    if t < T_REQUEST or st.finished then return end

    ---------------------------------------------------------------------------------------------
    if st.phase == "build" then
      if t % 600 == 0 then
        local r = ctx.remote("fo-ia1d", "report", "player")
        if r and all_done(r) then
          ctx.log(string.format("base finie a la minute %d", math.floor(t / MIN)))
          st.built = true
          set_phase(st, "releve", e.tick)
        elseif t > T_BUILD_MAX then
          ctx.check(false, "base finie dans les " .. (T_BUILD_MAX / MIN) .. " minutes")
          st.finished = true
        end
      end

    ---------------------------------------------------------------------------------------------
    elseif st.phase == "releve" then
      local r = fresh_report(ctx, st, e)
      if r then
        st.base = r
        ctx.log("RELEVE 1 : " .. line(r))
        ctx.check(r.poles >= 3 and r.producers >= 2 and r.consumers >= 1, "relevé 1 : poteaux, producteurs et bâtiments vus (" .. r.poles .. ", " .. r.producers .. ", " .. r.consumers .. ")")
        ctx.check(r.check.comp_split == 0 and r.check.comp_merge == 0, "relevé 1 : composantes du modèle = réseaux du moteur (scission " .. r.check.comp_split .. ", fusion " .. r.check.comp_merge .. ")")
        ctx.check(r.check.cover_disagree == 0, "relevé 1 : « hors de portée » du modèle = « sans réseau » du moteur (" .. r.check.cover_disagree .. " désaccord(s) sur " .. r.consumers .. " bâtiments)")
        ctx.check(r.powered > 0, "relevé 1 : des bâtiments alimentés (" .. r.powered .. ")")
        local nets, poles = engine_networks(s)
        ctx.log(string.format("moteur : %d reseau(x) pour %d poteau(x) ; modele : %d composante(s)", nets, poles, r.comps))
        ctx.check(nets == r.comps, "relevé 1 : " .. r.comps .. " composante(s) du modèle contre " .. nets .. " réseau(x) du moteur")
        set_phase(st, "zones", e.tick)
      elseif t - (st.t_phase - st.t0) > WAIT_REPORT * 2 then
        ctx.check(false, "relevé 1 publié")
        st.finished = true
      end

    ---------------------------------------------------------------------------------------------
    elseif st.phase == "zones" then
      if not st.zone_ents then
        st.zone_ents = {}
        for _, p in ipairs({ { 100.5, -100.5 }, { 104.5, -100.5 }, { -100.5, 100.5 } }) do
          local m = s.create_entity({ name = "assembling-machine-1", position = p, force = "player" })
          if m then st.zone_ents[#st.zone_ents + 1] = m end
        end
        ctx.check(#st.zone_ents == 3, "zones : 3 assembleurs posés loin de tout poteau (" .. #st.zone_ents .. ")")
        return
      end
      local r = fresh_report(ctx, st, e)
      if r then
        ctx.log("RELEVE 2 : " .. line(r))
        for i, z in ipairs(r.zones or {}) do ctx.log(string.format("zone %d : (%.1f, %.1f)-(%.1f, %.1f), %d batiment(s), %.0f kW", i, z.x0, z.y0, z.x1, z.y1, z.n, z.kw)) end
        ctx.check(r.uncovered == st.base.uncovered + 3, "zones : 3 bâtiments de plus hors de portée (" .. r.uncovered .. " contre " .. st.base.uncovered .. ")")
        ctx.check((r.n_zones or 0) == (st.base.n_zones or 0) + 2, "zones : 2 zones de plus (" .. tostring(r.n_zones) .. " contre " .. tostring(st.base.n_zones) .. ")")
        local found2, found1 = false, false
        for _, z in ipairs(r.zones or {}) do
          if z.n == 2 and z.x0 < 101 and z.x1 > 104 then found2 = true end
          if z.n == 1 and z.x0 < -100 and z.x1 > -101 then found1 = true end
        end
        ctx.check(found2 and found1, "zones : la zone de 2 (est) et celle de 1 (ouest) sont publiées aux bonnes places")
        ctx.check(r.check.cover_disagree == 0, "zones : le moteur confirme « sans réseau » (" .. r.check.cover_disagree .. " désaccord(s))")
        for _, m in ipairs(st.zone_ents) do if m.valid then m.destroy() end end
        set_phase(st, "tue", e.tick)
      end

    ---------------------------------------------------------------------------------------------
    elseif st.phase == "tue" then
      if not st.victim then
        local r = ctx.remote("fo-reseau", "report", "player")
        if not (r and r.pivots) or e.tick % 60 ~= 0 then
          if e.tick - st.t_phase > 6000 then ctx.check(false, "poteaux pivots publiés"); st.finished = true end
          return
        end
        local piv = r.pivots[1]
        ctx.log("POTEAUX PIVOTS : " .. #r.pivots .. " publie(s) sur " .. tostring(r.n_pivots) .. " ; le plus lourd : (" .. (piv and piv.x or "?") .. ", " .. (piv and piv.y or "?") .. ") coupe " .. (piv and piv.n or 0) .. " batiment(s), " .. (piv and piv.kw or 0) .. " kW")
        ctx.check(piv ~= nil and piv.n > 0, "pivots : au moins un poteau dont la perte éteint quelque chose")
        if not piv then st.finished = true return end
        local ents = s.find_entities_filtered({ position = { piv.x, piv.y }, radius = 0.4, type = "electric-pole", force = "player" })
        local v = ents[1]
        ctx.check(v ~= nil, "pivots : le poteau publié existe au moteur")
        if not v then st.finished = true return end
        st.victim = { x = v.position.x, y = v.position.y, name = v.name, n = piv.n }
        local nets, poles = engine_networks(s)
        st.victim.nets_before, st.victim.poles_before = nets, poles
        v.die("enemy")
        st.victim.t = e.tick
        local nets2, poles2 = engine_networks(s)
        ctx.log(string.format("poteau %s (%.1f, %.1f) tue : %d poteaux -> %d, reseaux du moteur %d -> %d", st.victim.name, st.victim.x, st.victim.y, poles, poles2, nets, nets2))
        ctx.check(poles2 == poles - 1, "pivots : le poteau est bien mort (" .. poles .. " -> " .. poles2 .. ")")
        return
      end
      if (e.tick - st.victim.t) % 300 == 0 then
        local rs = ctx.remote("fo-reseau", "state", "player")
        local back = s.find_entities_filtered({ position = { st.victim.x, st.victim.y }, radius = 0.4, type = "electric-pole", force = "player" })[1]
        if back then
          ctx.log(string.format("poteau releve %d ticks (%.1f min) apres sa mort", e.tick - st.victim.t, (e.tick - st.victim.t) / MIN))
          ctx.check(true, "poteau relevé à sa place par les PNJ en " .. string.format("%.1f", (e.tick - st.victim.t) / MIN) .. " min")
          st.repaired = true
          set_phase(st, "releve2", e.tick)
        elseif e.tick - st.victim.t > WAIT_REPAIR then
          ctx.log("etat des reparations : " .. (rs and (#rs.repairs .. " reparation(s)") or "aucune") .. ", " .. (rs and rs.died or 0) .. " mort(s) notee(s)")
          ctx.check(false, "poteau relevé dans les " .. (WAIT_REPAIR / MIN) .. " minutes")
          st.finished = true
        end
      end

    ---------------------------------------------------------------------------------------------
    elseif st.phase == "releve2" then
      -- laisser au projet de réparation le temps de se clore (fils), puis relever
      if e.tick - st.t_phase < 1200 then return end
      local r = fresh_report(ctx, st, e)
      if r then
        ctx.log("RELEVE 3 (apres reparation) : " .. line(r))
        ctx.check(r.comps == st.base.comps, "réparation : mêmes composantes qu'avant (" .. r.comps .. " contre " .. st.base.comps .. ")")
        ctx.check(r.powered == st.base.powered, "réparation : mêmes bâtiments alimentés qu'avant (" .. r.powered .. " contre " .. st.base.powered .. ")")
        ctx.check(r.uncovered == st.base.uncovered, "réparation : rien de plus hors de portée (" .. r.uncovered .. " contre " .. st.base.uncovered .. ")")
        ctx.check(r.check.comp_split == 0 and r.check.comp_merge == 0, "réparation : le modèle suit toujours le moteur")
        local nets = engine_networks(s)
        ctx.check(nets == st.victim.nets_before, "réparation : " .. nets .. " réseau(x) du moteur, comme avant la mort (" .. st.victim.nets_before .. ")")
        set_phase(st, "charge", e.tick)
      end

    ---------------------------------------------------------------------------------------------
    elseif st.phase == "charge" then
      if not st.radars then
        -- 7 radars sur un poteau de plus, à 7 tuiles d'un poteau du réseau le plus proche du coffre
        local poles = s.find_entities_filtered({ type = "electric-pole", force = "player" })
        table.sort(poles, function(a, b)
          local da, db = a.position.x ^ 2 + a.position.y ^ 2, b.position.x ^ 2 + b.position.y ^ 2
          if da ~= db then return da < db end
          if a.position.x ~= b.position.x then return a.position.x < b.position.x end
          return a.position.y < b.position.y
        end)
        local base = poles[1]
        local pole
        for _, d in ipairs({ { 7, 0 }, { -7, 0 }, { 0, 7 }, { 0, -7 }, { 11, 0 }, { -11, 0 }, { 0, 11 }, { 0, -11 } }) do
          local pos = s.find_non_colliding_position("medium-electric-pole", { base.position.x + d[1], base.position.y + d[2] }, 4, 0.5)
          if pos then
            local cand = s.create_entity({ name = "medium-electric-pole", position = pos, force = "player" })
            if cand then pole = cand break end
          end
        end
        ctx.check(pole ~= nil, "charge : poteau de la charge posé")
        if not pole then st.finished = true return end
        st.radars = {}
        local px, py = pole.position.x, pole.position.y
        for _, d in ipairs({ { -2.5, -2.5 }, { 2.5, -2.5 }, { -2.5, 2.5 }, { 2.5, 2.5 }, { 0, -3.5 }, { 0, 3.5 }, { -3.5, 0 }, { 3.5, 0 } }) do
          if #st.radars < 7 then
            local pos = s.find_non_colliding_position("radar", { px + d[1], py + d[2] }, 6, 0.5)
            local rad = pos and s.create_entity({ name = "radar", position = pos, force = "player" })
            if rad then st.radars[#st.radars + 1] = rad end
          end
        end
        ctx.check(#st.radars == 7, "charge : 7 radars posés (" .. #st.radars .. ")")
        st.base_prod = st.base.prod_kw
        ctx.log(string.format("charge : 7 radars (2100 kW) sur un poteau a (%.1f, %.1f), production avant : %.0f kW", px, py, st.base_prod or 0))
        st.t_charge = e.tick
        return
      end
      if (e.tick - st.t_charge) % 600 == 0 then
        local rs = ctx.remote("fo-reseau", "state", "player")
        local r = ctx.remote("fo-reseau", "report", "player")
        if rs and #rs.plants >= 1 and not st.plant_asked then
          st.plant_asked = e.tick
          ctx.log(string.format("centrale de plus demandee %.1f min apres la charge (projet %d) ; dernier releve : niveau %s, charge %.0f %%, projetee %.0f %%",
            (e.tick - st.t_charge) / MIN, rs.plants[1].pid, tostring(r and r.level), (r and r.load or 0) * 100, (r and r.projected or 0) * 100))
        end
        if rs and rs.plants[1] and rs.plants[1].state == "fini" then
          ctx.log("centrale de plus finie " .. string.format("%.1f", (e.tick - st.t_charge) / MIN) .. " min apres la charge")
          st.plant_done = true
          set_phase(st, "releve4", e.tick)
        elseif e.tick - st.t_charge > WAIT_PLANT then
          ctx.log("etat : " .. (rs and (#rs.plants .. " centrale(s) de plus, alertes " .. rs.alerts) or "aucun") .. " ; dernier releve : " .. (r and line(r) or "aucun"))
          ctx.check(st.plant_asked ~= nil, "capacité : une centrale de plus demandée sous charge")
          ctx.check(false, "capacité : centrale de plus finie dans les " .. (WAIT_PLANT / MIN) .. " minutes")
          st.finished = true
        end
      end

    ---------------------------------------------------------------------------------------------
    elseif st.phase == "releve4" then
      if e.tick - st.t_phase < 1800 then return end
      local r = fresh_report(ctx, st, e)
      if r then
        ctx.log("RELEVE 4 (centrale de plus) : " .. line(r))
        ctx.check(st.plant_asked ~= nil, "capacité : une centrale de plus demandée sous charge (alerte à 80 %, aucun seuil d'essai)")
        ctx.check(r.producers >= 4, "capacité : 4 machines à vapeur au moins (" .. r.producers .. ")")
        ctx.check(r.prod_kw >= 2 * (st.base_prod or 1) - 1, string.format("capacité : production doublée (%.0f kW contre %.0f kW)", r.prod_kw, st.base_prod or 0))
        ctx.check(r.check.comp_split == 0 and r.check.comp_merge == 0, "capacité : le modèle suit toujours le moteur")
        st.finished = true
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.finished == true, "toutes les phases jouées (phase atteinte : " .. tostring(st.phase) .. ")")
  end,
}
