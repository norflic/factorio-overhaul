--[[
  Banc « ia1-build » du lot IA1-d (docs/EQUIPES_PNJ.md §16) : le plan directeur et la construction par les PNJ, sur 5
  terrains (scénarios ia1-build-plaine, -eau, -falaises, -foret, -reseau ; ce fichier est leur partie commune).

  Terrain : un carré de 280 × 280 tuiles autour du point d'apparition de nauvis est VIDÉ (ressources, arbres, rochers,
  falaises, eau) puis FAÇONNÉ par une graine propre à chaque variante (générateur congruentiel, aucun hasard du jeu) :
  gisements de fer (lot (2, −1)), de cuivre (lot (−2, 1)) et de charbon (lot (−2, −2)), un lac au sud (lot (0, 3)) ;
  puis les obstacles de la variante :
    plaine   : rien ;
    eau      : une rivière nord-sud qui coupe les rues de la colonne 1 et des étangs (rues fermées, lots de rive) ;
    falaises : deux lignes de falaises naturelles (lots refusés, rues fermées) ;
    foret    : forêt dense (40 % des tuiles, arbres et rochers) partout hors du QG et du lac (défrichage des lots et
               des rues, R13) ;
    reseau   : falaises en RÉSEAU le long des rues (2 tronçons sur 3 fermés sur 4 lignes ; détours, replis).
  Votre équipe (coffre d'équipe, 8 PNJ) reçoit le plan directeur (« seul » : le banc tient le rôle du cerveau IA3-c ;
  fantômes posés d'avance), puis 3 demandes : centrale à vapeur, fonderie de fer (6 fours) alimentée, fonderie de cuivre
  (4 fours) alimentée ; chaque fonderie demande ses foreuses (tapis) et ses quais (charbon par porteurs, sorties).
  Quand tout est fini (ou à 30 min), le coffre d'équipe est détruit : l'équipe est RENVOYÉE (aucun PNJ), et la marche
  de la fonderie de fer est mesurée 5 min SANS PNJ (products_finished des fours, plaques au quai de sortie).

  Contrôles (§16) : 0 chevauchement entre nos bâtiments ; aucun bâtiment sur l'eau ou une falaise ; au moins 90 % des
  modules commencés finis ; refus de lots et fermetures de rues classés par raison (publiés) ; marches par les rues,
  PNJ bloqués et replis vers le PathService par minute (publiés) ; fonderie de fer en marche 5 min sans PNJ (chaque
  minute) à 70 % au moins du débit des fours ; réseau électrique alimenté.
  Lancement : fo-autotest.bat nopause 132000 ia1-build-<variante> <source> ; journal : [FO-IA1-BUILD-<VARIANTE>].
]]

local MIN = 3600
local HALF = 140
local T_REQUEST = 120
local T_DISMISS_MAX = 30 * MIN
local AUTONOMY = 5 * MIN
local CHECK = T_DISMISS_MAX + AUTONOMY + 600

local TREES = { "tree-01", "tree-02", "tree-03", "tree-04", "tree-05", "tree-06", "tree-07", "tree-08", "tree-09" }
local ROCKS = { "rock-big", "sand-rock-big" }

local SEEDS = { plaine = 11, eau = 23, falaises = 37, foret = 41, reseau = 53 }

local function lcg(seed)
  local s = seed % 2147483647
  return function(n)
    s = (s * 48271) % 2147483647
    return s % n
  end
end

local function sorted_keys(t)
  local k = {}
  for x in pairs(t) do k[#k + 1] = x end
  table.sort(k, function(a, b) return tostring(a) < tostring(b) end)
  return k
end

--- Disque de minerai.
local function deposit(s, name, cx, cy, r, amount)
  for dy = -r, r do
    for dx = -r, r do
      if dx * dx + dy * dy <= r * r then s.create_entity({ name = name, position = { cx + dx + 0.5, cy + dy + 0.5 }, amount = amount }) end
    end
  end
end

local function water_disc(tiles, cx, cy, r)
  for dy = -r, r do
    for dx = -r, r do
      if dx * dx + dy * dy <= r * r then tiles[#tiles + 1] = { name = "water", position = { cx + dx, cy + dy } } end
    end
  end
end

local function cliff_line(s, x0, y0, x1, y1)
  local n = 0
  if y0 == y1 then
    for x = x0, x1, 4 do if s.create_entity({ name = "cliff", position = { x, y0 }, cliff_orientation = "west-to-east" }) then n = n + 1 end end
  else
    for y = y0, y1, 4 do if s.create_entity({ name = "cliff", position = { x0, y }, cliff_orientation = "north-to-south" }) then n = n + 1 end end
  end
  return n
end

--- Terrain de la variante (tout à l'init, avant le coffre).
local function shape(ctx, variant, c)
  local s = ctx.surface()
  local rnd = lcg(SEEDS[variant] * 7919 + 1)
  s.request_to_generate_chunks({ c.x, c.y }, 6)
  s.force_generate_chunk_requests()
  local area = { { c.x - HALF, c.y - HALF }, { c.x + HALF, c.y + HALF } }
  for _, e in ipairs(s.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
    if e.valid then e.destroy() end
  end
  local tiles = {}
  for y = c.y - HALF, c.y + HALF - 1 do for x = c.x - HALF, c.x + HALF - 1 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
  s.set_tiles(tiles, true)
  -- eau AVANT les entités (F135)
  local water = {}
  water_disc(water, c.x + 4, c.y + 76, 13) -- lac au sud : rive dans le lot (0, 2)
  if variant == "eau" then
    -- rivière nord-sud dans la colonne de lots 1 (x de 22 à 27) qui coupe les rues horizontales, et deux étangs
    for y = c.y - 130, c.y + 40 do for x = c.x + 22, c.x + 27 do water[#water + 1] = { name = "water", position = { x, y } } end end
    water_disc(water, c.x - 30, c.y - 70, 7)
    water_disc(water, c.x + 70, c.y + 35, 6)
  end
  s.set_tiles(water, true)
  -- gisements
  deposit(s, "iron-ore", c.x + 56, c.y - 28, 10, 4000)
  deposit(s, "copper-ore", c.x - 56, c.y + 28, 10, 4000)
  deposit(s, "coal", c.x - 56, c.y - 56, 8, 3000)
  local n_obst = 0
  if variant == "falaises" then
    n_obst = n_obst + cliff_line(s, c.x - 110, c.y - 66, c.x + 18, c.y - 66)
    n_obst = n_obst + cliff_line(s, c.x - 80, c.y - 30, c.x - 80, c.y + 100)
  elseif variant == "reseau" then
    -- lignes de falaises le long des rues : 2 tronçons sur 3 fermés (brèches réservées)
    for _, i in ipairs({ -2, 1 }) do
      local x = c.x + 28 * i + 14
      for j = -4, 3 do
        if (j + i) % 3 ~= 0 then n_obst = n_obst + cliff_line(s, x, c.y + 28 * j + 18, x, c.y + 28 * j + 38) end
      end
    end
    for _, j in ipairs({ -2, 1 }) do
      local y = c.y + 28 * j + 14
      for i = -4, 3 do
        if (i - j) % 3 ~= 0 then n_obst = n_obst + cliff_line(s, c.x + 28 * i + 18, y, c.x + 28 * i + 38, y) end
      end
    end
  elseif variant == "foret" then
    for y = c.y - 130, c.y + 129 do
      for x = c.x - 130, c.x + 129 do
        local dx, dy = x - c.x, y - c.y
        if dx * dx + dy * dy > 14 * 14 and rnd(100) < 40 then
          local name = rnd(20) == 0 and ROCKS[rnd(#ROCKS) + 1] or TREES[rnd(#TREES) + 1]
          if s.can_place_entity({ name = name, position = { x + 0.5, y + 0.5 } }) then
            if s.create_entity({ name = name, position = { x + 0.5, y + 0.5 } }) then n_obst = n_obst + 1 end
          end
        end
      end
    end
  end
  return n_obst
end

local function stock_chest(chest)
  for _, it in ipairs({
    { "iron-plate", 2000 }, { "copper-plate", 600 }, { "coal", 1500 }, { "stone", 200 },
    { "electric-mining-drill", 20 }, { "stone-furnace", 30 }, { "transport-belt", 500 }, { "inserter", 120 },
    { "fast-inserter", 20 }, { "burner-inserter", 10 }, { "medium-electric-pole", 80 }, { "big-electric-pole", 30 },
    { "iron-chest", 20 }, { "boiler", 2 }, { "steam-engine", 4 }, { "offshore-pump", 2 },
    { "pistol", 10 }, { "firearm-magazine", 200 },
  }) do
    chest.insert({ name = it[1], count = it[2] })
  end
end

--- Projets de la fonderie de fer (fours, sorties) depuis le relevé du plan.
local function iron_furnaces(layout, pid)
  local out = {}
  for _, e in ipairs(layout.ents) do
    if e.pid == pid and e.name == "stone-furnace" then out[#out + 1] = { x = e.x, y = e.y } end
  end
  return out
end

local function report_line(ctx, r, t)
  local states = {}
  for _, p in ipairs(r.projects) do
    states[#states + 1] = string.format("%d:%s(%d/%d%s)", p.id, p.state, p.built, p.total, p.reason and (" " .. p.reason) or "")
  end
  ctx.log(string.format("minute %d | projets %s | fantomes %d refuses %d ravives %d echecs %d | defriches %d | quais +%d -%d | rues : marches %d arrivees %d bloques %d | modules %d/%d",
    math.floor(t / MIN), table.concat(states, " "), r.ghosts, r.ghost_refused, r.revived, r.revive_fail, r.cleared,
    r.filled, r.collected, r.street_walks, r.street_ok, r.street_stuck, r.modules_done, r.modules_started))
end

local function kv(t)
  local parts = {}
  for _, k in ipairs(sorted_keys(t or {})) do parts[#parts + 1] = k .. "=" .. tostring(t[k]) end
  return table.concat(parts, " ")
end

return function(variant)
  local TAG = "ia1-build-" .. variant
  return {
    description = "IA1-d : plan directeur et construction par les PNJ (" .. variant .. ")",
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local s = ctx.surface()
      local st = ctx.state()
      local c = { x = 0, y = 0 }
      st.c = c
      st.obstacles = shape(ctx, variant, c)
      ctx.log("terrain " .. variant .. " : " .. st.obstacles .. " obstacle(s) poses")
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
      local chest = s.create_entity({ name = "fo-team-chest", position = { c.x + 0.5, c.y + 0.5 }, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      if not chest then return end
      stock_chest(chest)
      st.chest = chest
      local ok = ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 3 })
      ctx.check(ok == true, "plan directeur active")
      st.t0 = game.tick
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.t0 then return end
      local t = e.tick - st.t0
      if t == T_REQUEST then
        st.ids = {
          plant = ctx.remote("fo-ia1d", "request", "player", { gen = "steam", args = { 1 }, feed = true }),
          iron = ctx.remote("fo-ia1d", "request", "player", { gen = "smelter", args = { "stone-furnace", "iron-ore", 3 }, feed = true }),
          copper = ctx.remote("fo-ia1d", "request", "player", { gen = "smelter", args = { "stone-furnace", "copper-ore", 2 }, feed = true }),
        }
        ctx.log(string.format("demandes : centrale %s, fer %s, cuivre %s", tostring(st.ids.plant), tostring(st.ids.iron), tostring(st.ids.copper)))
      end
      if st.dismissed then
        -- marche sans PNJ : relevé chaque minute
        if (e.tick - st.dismissed) % MIN == 0 and e.tick > st.dismissed and #st.auto < 5 then
          local s = ctx.surface()
          local made = 0
          for _, p in ipairs(st.furnaces) do
            local f = s.find_entity("stone-furnace", { p.x, p.y })
            if f then made = made + f.products_finished end
          end
          st.auto[#st.auto + 1] = made
          local prev = (#st.auto > 1) and st.auto[#st.auto - 1] or st.made0
          ctx.log(string.format("sans PNJ, minute %d : %d plaques de fer (fours)", #st.auto, made - prev))
        end
        return
      end
      if t > T_REQUEST and t % 600 == 0 then
        local r = ctx.remote("fo-ia1d", "report", "player")
        if not r then return end
        st.last_report = r
        if t % MIN == 0 then report_line(ctx, r, t) end
        -- tout est fini (ou refusé, bloqué) et les quais de charbon sont garnis : l'équipe est renvoyée
        local open = 0
        local quais_ok = true
        for _, p in ipairs(r.projects) do
          if p.state ~= "fini" and p.state ~= "refuse" and p.state ~= "bloque" then open = open + 1 end
          for _, q in ipairs(p.quais or {}) do if p.state == "fini" and q.count < 100 then quais_ok = false end end
        end
        if (open == 0 and quais_ok and #r.projects > 0) or t >= T_DISMISS_MAX then
          st.final = r
          st.layout = ctx.remote("fo-ia1d", "layout", "player")
          st.teams = ctx.remote("fo-ia1", "teams")
          st.path = ctx.remote("fo-ia1", "path")
          st.furnaces = iron_furnaces(st.layout, st.ids.iron)
          local s = ctx.surface()
          st.made0 = 0
          for _, p in ipairs(st.furnaces) do
            local f = s.find_entity("stone-furnace", { p.x, p.y })
            if f then st.made0 = st.made0 + f.products_finished end
          end
          st.auto = {}
          st.dismiss_t = t
          ctx.log(string.format("equipe renvoyee a %.1f min (projets ouverts %d) : coffre d'equipe detruit", t / MIN, open))
          if st.chest and st.chest.valid then st.chest.destroy({ raise_destroy = true }) end
          st.dismissed = e.tick
        end
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local s = ctx.surface()
      local r = st.final
      ctx.check(r ~= nil, "releve final du plan directeur")
      if not r then return end
      ctx.log("lots : " .. kv(r.lots))
      ctx.log("troncons : " .. kv(r.segs))
      ctx.log("refus de lots (evaluation) : " .. kv(r.lots_refused) .. " | fermetures de rues : " .. kv(r.segs_closed)
        .. " | refus au plan : " .. kv(r.plan_refused))
      for _, p in ipairs(r.projects) do
        local parts = {}
        for _, pt in ipairs(p.parts) do parts[#parts + 1] = string.format("%s %s lot %s (%d,%d) r%d", pt.kind, pt.key, pt.lot, pt.x, pt.y, pt.rotation) end
        ctx.log(string.format("projet %d : %s%s, %d/%d entites, %d fils ; %s", p.id, p.state, p.reason and (" (" .. p.reason .. ")") or "",
          p.built, p.total, p.wires or 0, table.concat(parts, " ; ")))
      end
      -- PNJ bloqués et replis, par minute (compteurs cumulés relevés à chaque pensée)
      local prev
      local lines = {}
      for _, m in ipairs(r.minutes or {}) do
        if prev then
          lines[#lines + 1] = string.format("%d:%d/%d/%d", m.m, m.walks - prev.walks, m.ok - prev.ok, m.stuck - prev.stuck)
        end
        prev = m
      end
      ctx.log("rues par minute (marches/arrivees/bloques-replis) : " .. table.concat(lines, " "))
      local nav_fail = 0
      for _, row in ipairs(st.teams or {}) do if row.key == "player" then nav_fail = row.nav_fail end end
      ctx.log(string.format("marches par les rues %d, arrivees %d, bloques puis rendus au PathService %d ; echecs de chemin de l'equipe %d ; PathService : demandes %d, echecs %d, en vol au plus %d",
        r.street_walks, r.street_ok, r.street_stuck, nav_fail, st.path and st.path.requested or -1, st.path and st.path.fail or -1,
        st.path and st.path.inflight_max or -1))
      ctx.log(string.format("fantomes poses %d, refuses %d, ravives %d, echecs de ravivage %d, defriches %d, quais remplis %d, sorties videes %d",
        r.ghosts, r.ghost_refused, r.revived, r.revive_fail, r.cleared, r.filled, r.collected))
      -- 1. modules commencés finis
      local pct = r.modules_started > 0 and r.modules_done / r.modules_started or 0
      ctx.check(r.modules_started >= 3 and pct >= 0.9, string.format("au moins 90 %% des modules commences finis : %d/%d", r.modules_done, r.modules_started))
      -- 2. chevauchements entre nos bâtiments
      local occ, conflicts, n_ent = {}, 0, 0
      local area = { { st.c.x - HALF, st.c.y - HALF }, { st.c.x + HALF, st.c.y + HALF } }
      local ents = s.find_entities_filtered({ area = area, force = "player", collision_mask = "object-layer" })
      table.sort(ents, function(a, b) return a.unit_number < b.unit_number end)
      local on_water, on_cliff = 0, 0
      for _, e in ipairs(ents) do
        if e.type ~= "character" then
          n_ent = n_ent + 1
          local bb = e.bounding_box
          local x0, y0 = math.floor(bb.left_top.x + 0.01), math.floor(bb.left_top.y + 0.01)
          local x1, y1 = math.ceil(bb.right_bottom.x - 0.01) - 1, math.ceil(bb.right_bottom.y - 0.01) - 1
          for y = y0, y1 do
            for x = x0, x1 do
              local k = x * 100000 + y
              if occ[k] then conflicts = conflicts + 1 else occ[k] = e.unit_number end
            end
          end
          if e.name ~= "offshore-pump" and s.count_tiles_filtered({ area = { { x0, y0 }, { x1 + 1, y1 + 1 } }, collision_mask = "water-tile" }) > 0 then on_water = on_water + 1 end
          for _, cl in ipairs(s.find_entities_filtered({ area = { { x0, y0 }, { x1 + 1, y1 + 1 } }, type = "cliff" })) do
            local b = cl.bounding_box
            if b.left_top.x < x1 + 1 and b.right_bottom.x > x0 and b.left_top.y < y1 + 1 and b.right_bottom.y > y0 then on_cliff = on_cliff + 1 end
          end
        end
      end
      ctx.check(n_ent >= 50 and conflicts == 0, string.format("0 chevauchement entre nos batiments (%d batiments, %d tuiles en conflit)", n_ent, conflicts))
      ctx.check(on_water == 0 and on_cliff == 0, string.format("aucun batiment sur l'eau ni sur une falaise (eau %d, falaise %d)", on_water, on_cliff))
      -- 3. refus et fermetures classés par raison (publiés)
      local classified = true
      for _, k in ipairs(sorted_keys(r.lots_refused or {})) do if k == "nil" then classified = false end end
      ctx.check(classified, "refus de lots et fermetures de rues classes par raison (publies)")
      -- 4. marche sans PNJ
      local fin = 0
      for _, row in ipairs(ctx.remote("fo-ia1", "teams")) do if row.key == "player" then fin = row.n end end
      ctx.check(fin == 0 and st.dismissed ~= nil, "equipe renvoyee : aucun PNJ pendant la mesure (" .. fin .. ")")
      local iron = nil
      for _, p in ipairs(r.projects) do if p.id == st.ids.iron then iron = p end end
      local nfurn = #(st.furnaces or {})
      local rate = nfurn * (1 / 3.2) * 60 -- plaques par minute des fours (four en pierre, 3,2 s)
      local per_min = {}
      local prev2 = st.made0 or 0
      local all_run = #(st.auto or {}) == 5
      local min_ratio = math.huge
      for _, v in ipairs(st.auto or {}) do
        local d = v - prev2
        per_min[#per_min + 1] = d
        local ratio = rate > 0 and d / rate or 0
        if ratio < min_ratio then min_ratio = ratio end
        if d <= 0 then all_run = false end
        prev2 = v
      end
      ctx.check(iron ~= nil and iron.state == "fini" and nfurn >= 6, "fonderie de fer finie (" .. nfurn .. " fours)")
      ctx.check(all_run and min_ratio >= 0.7, string.format("fonderie de fer : 5 min SANS PNJ, chaque minute >= 70 %% de %.1f plaques/min (%s ; pire %.2f)",
        rate, table.concat(per_min, ", "), min_ratio == math.huge and 0 or min_ratio))
      -- 5. réseau électrique : foreuses de fer alimentées
      local drills, powered = 0, 0
      for _, e in ipairs(st.layout and st.layout.ents or {}) do
        if e.name == "electric-mining-drill" then
          local d = s.find_entity(e.name, { e.x, e.y })
          if d then
            drills = drills + 1
            if d.is_connected_to_electric_network() then powered = powered + 1 end
          end
        end
      end
      ctx.check(drills >= 4 and powered == drills, string.format("foreuses electriques reliees au reseau (%d/%d)", powered, drills))
      local gen = 0
      for _, e in ipairs(s.find_entities_filtered({ area = area, name = "steam-engine", force = "player" })) do gen = gen + e.energy_generated_last_tick end
      ctx.log(string.format("machines a vapeur : %.0f kW produits au dernier tick", gen * 60 / 1000))
    end,

    shots_delay = nil,
  }
end
