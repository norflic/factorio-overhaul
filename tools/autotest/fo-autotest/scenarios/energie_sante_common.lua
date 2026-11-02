--[[
  Lot ENERGIE (2/11 ; points 5 et 11 du retour du DC sur la 0.6.34) : centrale résiliente. Scénarios PROVOQUÉS et déterministes, sans cerveau
  (plan directeur « seul » ; le banc tient le rôle du cerveau, comme energie_demande_common.lua) :

    energie-panne        : centrale d'une chaudière en marche sous charge (radars) ; à t_fini + 1 min, le banc RETIRE les bras à combustion et deux
                           tuiles du tapis de charbon, vide les chaudières, et retire du coffre d'équipe les objets qui servent à reposer les pièces
                           (la reconstruction attend la matière, comme dans la partie du DC : Ambre, fer au stock 0) ; 6 min plus tard le banc rend
                           la matière. Mesure : secondes de production nulle, amorces à la main, pièces reposées, amorce arrêtée.
    energie-panne-temoin : même chose, règle COUPÉE (remote fo-ia1d set_option no_sante) : la production reste à 0 jusqu'à la matière rendue.
    energie-froid        : centrale de 3 chaudières dont le charbon vient de foreuses ÉLECTRIQUES (voie « tapis », aucun coffre : Emerald, 0 kW
                           pendant 125 min). Mesure : premier courant après la fin de la centrale, production durable.
    energie-froid-temoin : même chose, règle COUPÉE : 0 kW jusqu'à la fin (le démarrage à froid est impossible sans l'amorce).
  Lancement : banc.py --out <archive> --qui ENERGIE -- <ticks> energie-<variante> <source> ; journal : [FO-ENERGIE-<VARIANTE>].
]]

local MIN = 3600
local HALF = 140
local T_REQUEST = 120

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

--- Terrain : tout vidé puis herbe, deux lacs, charbon (le gisement proche d'un lac : la voie « tapis » du plan le choisit).
local function shape(ctx, c, coal_near, far)
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
  water_disc(water, c.x + 4, c.y + 78, 20)
  water_disc(water, c.x + 4, c.y - 78, 20)
  s.set_tiles(water, true) -- eau AVANT les entités (F135)
  if coal_near then
    deposit(s, "coal", c.x - (far and 84 or 40), c.y + 52, 8, 40000) -- far : ligne de poteaux plus longue (banc ilot)
  else
    deposit(s, "coal", c.x - 56, c.y - 56, 8, 30000)
  end
  deposit(s, "iron-ore", c.x + 56, c.y - 28, 6, 4000)
end

local FULL = {
  { "iron-plate", 1500 }, { "copper-plate", 300 }, { "coal", 1600 }, { "stone", 100 },
  { "electric-mining-drill", 8 }, { "stone-furnace", 6 }, { "transport-belt", 900 }, { "inserter", 60 },
  { "fast-inserter", 10 }, { "burner-inserter", 40 }, { "medium-electric-pole", 160 }, { "big-electric-pole", 10 },
  { "iron-chest", 10 }, { "boiler", 6 }, { "steam-engine", 12 }, { "offshore-pump", 4 },
  { "pistol", 4 }, { "firearm-magazine", 100 },
}
-- objets qui servent à reposer les pièces d'une centrale : retirés au moment de la panne, rendus plus tard
local SCARCE = { "burner-inserter", "transport-belt", "iron-plate" }

local function stock_chest(chest, only)
  local lost = {}
  local want = {}
  for _, it in ipairs(only or FULL) do want[#want + 1] = it end
  for _, it in ipairs(want) do
    local n = chest.insert({ name = it[1], count = it[2] })
    if n < it[2] then lost[#lost + 1] = it[1] end
  end
  return lost
end

local function scarce_amounts()
  local out = {}
  for _, it in ipairs(FULL) do
    for _, k in ipairs(SCARCE) do if it[1] == k then out[#out + 1] = it end end
  end
  return out
end

local function steam_power(s)
  local power, n = 0, 0
  for _, e in ipairs(s.find_entities_filtered({ name = "steam-engine", force = "player" })) do
    power = power + e.energy_generated_last_tick
    n = n + 1
  end
  return power, n
end

local function plant_state(r)
  local fini, open = 0, 0
  local pr
  for _, p in ipairs(r and r.projects or {}) do
    local pt = p.parts and p.parts[1]
    if pt and pt.kind == "centrale" then
      pr = pr or p
      if p.state == "fini" then fini = fini + 1 else open = open + 1 end
    end
  end
  return fini, open, pr
end

--- Charge : n radars par grappes de 8 autour d'un poteau moyen relié au réseau de la centrale (comme energie_demande_common.lua).
local function place_load(ctx, n, keep)
  local s = ctx.surface()
  local eng = s.find_entities_filtered({ name = "steam-engine", force = "player", limit = 1 })[1]
  if not eng then return 0, "pas de machine a vapeur" end
  local net = eng.electric_network_id
  local start
  local best = math.huge
  for _, pole in ipairs(s.find_entities_filtered({ type = "electric-pole", force = "player", position = eng.position, radius = 20 })) do
    if pole.electric_network_id == net then
      local d = (pole.position.x - eng.position.x) ^ 2 + (pole.position.y - eng.position.y) ^ 2
      if d < best then best, start = d, pole end
    end
  end
  if not start then return 0, "pas de poteau du reseau de la centrale" end
  local placed = 0
  local last = start
  local cx, cy = start.position.x + 12, start.position.y - 30
  local steps = 0
  while steps < 20 do
    local dx, dy = cx - last.position.x, cy - last.position.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist <= 6 then break end
    local k = 6.5 / dist
    local pos = s.find_non_colliding_position("medium-electric-pole", { last.position.x + dx * k, last.position.y + dy * k }, 2, 0.5)
    local pole = pos and s.create_entity({ name = "medium-electric-pole", position = pos, force = "player" })
    if not pole then return placed, "chaine de poteaux coupee" end
    if keep and pole.unit_number then keep[pole.unit_number] = true end
    pole.connect_neighbour(last)
    last = pole
    steps = steps + 1
  end
  local offsets = { { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 }, { 3, 3 }, { -3, 3 }, { 3, -3 }, { -3, -3 } }
  local cluster = 0
  while placed < n and cluster < 6 do
    cluster = cluster + 1
    local hub_pos = s.find_non_colliding_position("medium-electric-pole", { last.position.x + 5, last.position.y }, 3, 0.5)
    local hub = hub_pos and s.create_entity({ name = "medium-electric-pole", position = hub_pos, force = "player" })
    if not hub then return placed, "poteau de grappe impossible" end
    if keep and hub.unit_number then keep[hub.unit_number] = true end
    hub.connect_neighbour(last)
    for _, o in ipairs(offsets) do
      if placed < n then
        local r = s.create_entity({ name = "radar", position = { hub.position.x + o[1], hub.position.y + o[2] }, force = "player" })
        if r then placed = placed + 1 end
      end
    end
    last = hub
  end
  return placed, nil
end

--- Coupe : retire les bras à combustion, deux tuiles du tapis de charbon près des chaudières, vide les chaudières. Rend les comptes.
local function cut(ctx)
  local s = ctx.surface()
  local arms, belts, boilers = 0, 0, 0
  local boiler_list = s.find_entities_filtered({ name = "boiler", force = "player" })
  for _, a in ipairs(s.find_entities_filtered({ name = "burner-inserter", force = "player" })) do
    if a.valid then a.destroy(); arms = arms + 1 end
  end
  local b0 = boiler_list[1]
  if b0 then
    local list = s.find_entities_filtered({ name = "transport-belt", force = "player", position = b0.position, radius = 9 })
    table.sort(list, function(a, b)
      local da = (a.position.x - b0.position.x) ^ 2 + (a.position.y - b0.position.y) ^ 2
      local db = (b.position.x - b0.position.x) ^ 2 + (b.position.y - b0.position.y) ^ 2
      if da ~= db then return da < db end
      if a.position.x ~= b.position.x then return a.position.x < b.position.x end
      return a.position.y < b.position.y
    end)
    for i = 1, math.min(2, #list) do list[i].destroy(); belts = belts + 1 end
  end
  for _, b in ipairs(boiler_list) do
    if b.valid then
      b.get_fuel_inventory().clear()
      if b.burner then b.burner.remaining_burning_fuel = 0 end
      boilers = boilers + 1
    end
  end
  return arms, belts, boilers
end

local function team_chest_remove(chest, list)
  for _, it in ipairs(list) do chest.remove_item({ name = it[1], count = 1000000 }) end
end

local function count_ent(s, name)
  return s.count_entities_filtered({ name = name, force = "player" })
end

return function(variant, opts)
  local TAG = ""
  local CHECK = opts.check_tick
  return {
    description = "ENERGIE : centrale resiliente (" .. variant .. ")",
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local s = ctx.surface()
      local st = ctx.state()
      local c = { x = 0, y = 0 }
      st.c = c
      shape(ctx, c, opts.mode == "froid" or opts.mode == "ilot", opts.mode == "ilot")
      local a = ctx.call("war_setting", "fo-war-ia3e", false)
      ctx.check(a == false, "reglage fo-war-ia3e coupe (le banc est le cerveau)", tostring(a))
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
      local chest = s.create_entity({ name = "fo-team-chest", position = { c.x + 0.5, c.y + 0.5 }, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      if not chest then return end
      local lost = stock_chest(chest)
      ctx.check(#lost == 0, "coffre d'equipe garni en entier", table.concat(lost, ","))
      st.chest = chest
      local ok = ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 4 })
      ctx.check(ok == true, "plan directeur active")
      if opts.off then
        ctx.check(ctx.remote("fo-ia1d", "set_option", "player", "no_sante", true) == true, "regle de sante de la centrale COUPEE (temoin)")
      end
      if opts.off_coupure then
        ctx.check(ctx.remote("fo-ia1d", "set_option", "player", "no_coupure", true) == true, "chemin le plus court et second chemin des poteaux COUPES (temoin)")
      end
      st.t0 = game.tick
      st.rows = {}
      st.max_gap, st.gap, st.zero_after_cut = 0, 0, 0
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.t0 then return end
      local t = e.tick - st.t0
      local s = ctx.surface()
      if t == T_REQUEST then
        st.plant_id = ctx.remote("fo-ia1d", "request", "player", { gen = "steam", args = { opts.boilers }, feed = true })
        ctx.log(TAG .. "centrale demandee (" .. opts.boilers .. " chaudiere(s)), projet " .. tostring(st.plant_id))
      end
      if t <= T_REQUEST or t % 60 ~= 0 then return end
      local power, engines = steam_power(s)
      st.power_now = power
      -- 1 relevé du plan directeur toutes les 10 s
      local fini, open, pr = st.fini, st.open, st.plant
      if t % 600 == 0 then
        local r = ctx.remote("fo-ia1d", "report", "player")
        fini, open, pr = plant_state(r)
        st.fini, st.open, st.plant = fini, open, pr
        if pr then st.quais = #(pr.quais or {}) end
      end
      if (fini or 0) >= 1 and not st.fini_t then
        st.fini_t = t
        ctx.log(string.format("%scentrale FINIE a %.2f min (%d coffre(s) de quai au plan)", TAG, t / MIN, st.quais or -1))
      end
      -- premier courant
      if st.fini_t and power > 0 and not st.first_t then
        st.first_t = t
        ctx.log(string.format("%spremier courant a %.2f min (%.2f min apres la fin de la centrale) : %.0f J/tick", TAG, t / MIN, t / MIN, power))
      end
      -- charge (radars) posée une minute après le premier courant : une demande durable, la centrale doit tenir seule
      local base_t = st.first_t or (opts.mode == "avance" and st.fini_t or nil)
      if opts.radars and base_t and not st.load_t and t >= base_t + 1 * MIN then
        st.load_poles = {}
        local placed, why = place_load(ctx, opts.radars, st.load_poles)
        st.load_t, st.radars = t, placed
        ctx.log(string.format("%scharge posee a %.2f min : %d radar(s) (%s)", TAG, t / MIN, placed, tostring(why or "ok")))
      end
      if opts.mode == "ilot" then
        -- ligne de poteaux COUPEE (Scarlet, 100-125 min) : 3 min après la charge, les 10 poteaux du couloir foreuses de charbon -> centrale les plus
        -- proches de son milieu sont détruits ; les foreuses sont alors sur un îlot sans courant. Avec `enemy` : un ennemi immobile au milieu de
        -- la coupure (les poteaux retirés sont tenus : il n'y a pas de chemin sûr, seul un second chemin neuf peut les relier)
        if st.load_t and not st.cut_t and t >= st.load_t + 3 * MIN then
          st.cut_t = t
          local c = st.c
          -- jusqu'a 10 poteaux du couloir foreuses de charbon -> centrale, les plus proches de son milieu, sauf :
          --  * les poteaux de la CHARGE (poses par le banc, jamais au plan : personne ne les referait) ;
          --  * ceux a moins de 20 tuiles des foreuses : l'ilot garde ses poteaux (sinon les foreuses seraient « sous aucun poteau », un autre cas).
          local eng = s.find_entities_filtered({ name = "steam-engine", force = "player", limit = 1 })[1]
          local dx, dy, dn = 0, 0, 0
          for _, d in ipairs(s.find_entities_filtered({ name = "electric-mining-drill", force = "player" })) do
            dx, dy, dn = dx + d.position.x, dy + d.position.y, dn + 1
          end
          local D = dn > 0 and { x = dx / dn, y = dy / dn } or { x = c.x - 40, y = c.y + 52 }
          local E = eng and { x = eng.position.x, y = eng.position.y } or { x = c.x, y = c.y }
          st.drill_c = D
          local mid = { x = (D.x + E.x) / 2, y = (D.y + E.y) / 2 }
          local list = s.find_entities_filtered({ type = "electric-pole", force = "player", area = { { c.x - 110, c.y - 8 }, { c.x + 10, c.y + 75 } } })
          local function d2(p, q) return (p.x - q.x) ^ 2 + (p.y - q.y) ^ 2 end
          table.sort(list, function(a, b)
            local da, db = d2(a.position, mid), d2(b.position, mid)
            if da ~= db then return da < db end
            if a.position.x ~= b.position.x then return a.position.x < b.position.x end
            return a.position.y < b.position.y
          end)
          local rows = {}
          for _, pole in ipairs(list) do rows[#rows + 1] = string.format("(%.0f,%.0f)%s", pole.position.x, pole.position.y,
            (pole.unit_number and st.load_poles and st.load_poles[pole.unit_number]) and "c" or "") end
          ctx.log("poteaux du couloir (c = charge) : " .. table.concat(rows, " ") .. string.format(" ; foreuses (%.0f, %.0f), machine a vapeur (%.0f, %.0f)", D.x, D.y, E.x, E.y))
          local elig = {}
          for _, pole in ipairs(list) do
            local load = pole.unit_number and st.load_poles and st.load_poles[pole.unit_number]
            if not load and d2(pole.position, D) >= 20 ^ 2 and #elig < 10 then elig[#elig + 1] = pole end
          end
          if opts.enemy and #elig > 0 then
            -- avec un ennemi : le poteau eligible le plus proche du milieu du couloir et ceux a moins de 27 tuiles de lui (le ver est pose sur
            -- le premier : tous sont tenus). La ligne bâtie par le plan est faite de grands poteaux espaces de 28 tuiles : en general UN seul.
            -- Le ver reste ainsi a plus de 28 tuiles des foreuses (sinon le raccordement attend, a raison) et les poteaux vivants voisins
            -- sont les bouts du second chemin.
            local m = elig[1]
            local near = {}
            for _, pole in ipairs(elig) do
              if d2(pole.position, m.position) <= 27 ^ 2 then near[#near + 1] = pole end
            end
            elig = near
          end
          list = elig
          do -- état avant la coupe : combien de foreuses sont déjà hors du réseau de la machine à vapeur (doit être 0)
            local off0, all0 = 0, 0
            for _, d in ipairs(s.find_entities_filtered({ name = "electric-mining-drill", force = "player" })) do
              all0 = all0 + 1
              if eng and d.electric_network_id ~= eng.electric_network_id then off0 = off0 + 1 end
            end
            st.drills_off_before = off0
            ctx.log(string.format("AVANT la coupe : %d foreuse(s) electriques dont %d hors du reseau de la machine a vapeur ; %d poteau(x) a couper", all0, off0, #list))
          end
          local n, sx, sy = 0, 0, 0
          if opts.enemy and list[1] then st.worm_x, st.worm_y = list[1].position.x, list[1].position.y end
          for i = 1, #list do
            local pole = list[i]
            if pole.valid then sx, sy = sx + pole.position.x, sy + pole.position.y; pole.destroy(); n = n + 1 end
          end
          st.cut_n, st.poles_in_box = n, #list
          ctx.log(string.format("LIGNE COUPEE a %.2f min : %d poteau(x) detruit(s) sur %d du couloir (centre %.0f, %.0f)", t / MIN, n, #list,
            n > 0 and sx / n or 0, n > 0 and sy / n or 0))
          if opts.enemy and n > 0 then
            -- un ver (ennemi immobile, portee 25 : les poseurs restent a 28) au milieu des poteaux retires : ils sont tenus (28 tuiles), le chemin sur n'existe pas
            local biter = s.create_entity({ name = "small-worm-turret", position = { st.worm_x or (sx / n), st.worm_y or (sy / n) }, force = "enemy" })
            if biter then
              local okact = true
              st.biter = biter
              local dd = st.drill_c and math.sqrt((biter.position.x - st.drill_c.x) ^ 2 + (biter.position.y - st.drill_c.y) ^ 2) or -1
              ctx.log(string.format("ENNEMI (ver) pose en (%.0f, %.0f) a %.0f tuiles des foreuses : %s", biter.position.x, biter.position.y, dd, tostring(okact)))
            else
              ctx.log("ENNEMI : create_entity a echoue")
            end
          end
        end
        if st.cut_t then
          -- foreuse « sans courant » = hors du réseau de la machine à vapeur (le statut no_power ne se voit pas sur une foreuse à l'arrêt)
          local dark = 0
          local eng = s.find_entities_filtered({ name = "steam-engine", force = "player", limit = 1 })[1]
          local net = eng and eng.electric_network_id
          for _, d in ipairs(s.find_entities_filtered({ name = "electric-mining-drill", force = "player" })) do
            if d.electric_network_id ~= net or d.status == defines.entity_status.no_power then dark = dark + 1 end
          end
          if dark > 0 and t > st.cut_t then
            st.dark_s = (st.dark_s or 0) + 1
            st.gap_s = (st.gap_s or 0) + 1
            if st.gap_s > (st.max_gap_s or 0) then st.max_gap_s = st.gap_s end
            st.saw_dark = true
          elseif dark == 0 and st.saw_dark and not st.back_t then
            st.back_t = t
            st.gap_s = 0
            ctx.log(string.format("foreuses de nouveau alimentees a %.2f min (%.0f s apres la coupe)", t / MIN, (t - st.cut_t) / 60))
          elseif dark == 0 then
            st.gap_s = 0
          end
          st.dark_now = dark
          if t % MIN == 0 then
            ctx.log(string.format("foreuses hors du reseau de la machine a vapeur : %d", dark))
            -- diagnostic : les projets pas finis (le raccordement du second chemin est-il bloque, et ou ?)
            local r = ctx.remote("fo-ia1d", "report", "player")
            for _, pr in ipairs(r and r.projects or {}) do
              if pr.state ~= "fini" then
                ctx.log(string.format("projet %s : etat %s, raison %s", tostring(pr.id), tostring(pr.state), tostring(pr.reason)))
              end
            end
          end
        end
      end
      if opts.mode == "porte" then
        -- trois modules électriques demandés d'un coup 30 s après la fin de la centrale : la porte en laisse passer un, retient les autres
        -- jusqu'à la centrale de plus (demandée par la puissance retenue)
        if st.fini_t and not st.req_t and t >= st.fini_t + 30 * 60 then
          st.req_t, st.mods = t, {}
          for k = 1, 3 do st.mods[k] = ctx.remote("fo-ia1d", "request", "player", { gen = "gears", args = { 4 }, prio = 70, domain = "production" }) end
          ctx.log(string.format("modules demandes a %.2f min : projets %s", t / MIN, table.concat({ tostring(st.mods[1]), tostring(st.mods[2]), tostring(st.mods[3]) }, ", ")))
        end
        if st.req_t and t % 600 == 0 then
          local r = ctx.remote("fo-ia1d", "report", "player")
          local held, passed = 0, 0
          for _, p in ipairs(r and r.projects or {}) do
            for _, id in ipairs(st.mods) do
              if p.id == id then
                if p.state == "attente" and p.reason == "courant" then held = held + 1 elseif p.state ~= "attente" then passed = passed + 1 end
              end
            end
          end
          st.max_held = math.max(st.max_held or 0, held)
          st.passed = passed
          if st.last_held ~= held then
            ctx.log(string.format("a %.2f min : %d module(s) retenu(s) pour le courant, %d passe(s), %d centrale(s) finie(s), %d en projet", t / MIN, held, passed, fini or 0, open or 0))
            st.last_held = held
          end
        end
      end
      if opts.mode == "panne" then
        -- coupe 90 s après la charge ; matière rendue 6 min plus tard
        if st.load_t and not st.cut_t and t >= st.load_t + 90 * 60 then
          st.before = power
          st.cut_t = t
          team_chest_remove(st.chest, scarce_amounts())
          local arms, belts, boilers = cut(ctx)
          ctx.log(string.format("%sPANNE a %.2f min : %d bras et %d tuile(s) de tapis retires, %d chaudiere(s) videes, matiere de reconstruction retiree du coffre ; production avant %.0f J/tick",
            TAG, t / MIN, arms, belts, boilers, st.before))
        end
        if st.cut_t and not st.restock_t and t >= st.cut_t + 6 * MIN then
          st.restock_t = t
          local lost = stock_chest(st.chest, scarce_amounts())
          ctx.log(string.format("%smatiere rendue au coffre a %.2f min (%s)", TAG, t / MIN, #lost == 0 and "tout" or ("pas tout : " .. table.concat(lost, ","))))
        end
        if st.cut_t then
          -- secondes de production nulle de suite (charge presente : une production nulle est une panne)
          if power < 100 then
            st.gap = st.gap + 1
            st.zero_after_cut = st.zero_after_cut + 1
            if st.gap > st.max_gap then st.max_gap = st.gap end
          else
            st.gap = 0
          end
          if not st.recovered_t and t > st.cut_t + 20 and power > 0.2 * (st.before or 1) then
            st.recovered_t = t
            ctx.log(string.format("%sCOURANT REVENU a %.2f min (%.0f s apres la panne) : %.0f J/tick", TAG, t / MIN, (t - st.cut_t) / 60, power))
          end
        end
      end
      if t % MIN == 0 then
        local arms, boilers = count_ent(s, "burner-inserter"), count_ent(s, "boiler")
        local fuel = 0
        for _, b in ipairs(s.find_entities_filtered({ name = "boiler", force = "player" })) do fuel = fuel + b.get_fuel_inventory().get_item_count() end
        ctx.log(string.format("%sminute %d : centrale %s ; production %.0f J/tick (%.0f kW) ; %d machine(s) a vapeur, %d chaudiere(s) dont %d charbon(s) en soute, %d bras",
          TAG, math.floor(t / MIN), (fini or 0) >= 1 and "finie" or "pas finie", power, power * 60 / 1000, engines, boilers, fuel, arms))
        st.rows[#st.rows + 1] = { t = t, power = power, fuel = fuel, arms = arms }
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local s = ctx.surface()
      local power, engines = steam_power(s)
      local arms = count_ent(s, "burner-inserter")
      ctx.log(string.format("%sFIN : fini a %s, premier courant a %s ; production %.0f J/tick ; %d machine(s) a vapeur ; %d bras ; plus longue production nulle apres la panne %d s (%d s en tout)",
        TAG, st.fini_t and string.format("%.2f", st.fini_t / MIN) or "-", st.first_t and string.format("%.2f", st.first_t / MIN) or "-", power, engines, arms,
        st.max_gap or 0, st.zero_after_cut or 0))
      ctx.check(st.fini_t ~= nil, "la centrale est finie")
      if opts.mode == "froid" then
        ctx.check((st.quais or -1) == 0, "centrale SANS coffre de quai au plan (nourrie par des foreuses seules : le cas d'Emerald)", tostring(st.quais))
        if opts.expect == "dead" then
          ctx.check(st.first_t == nil, "SANS la regle : aucun courant, jamais (demarrage a froid impossible)")
          ctx.check(power == 0, "SANS la regle : production nulle a la fin")
        else
          ctx.check(st.first_t ~= nil and st.fini_t ~= nil and st.first_t - st.fini_t <= 3 * MIN,
            string.format("AVEC la regle : premier courant au plus 3 min apres la fin de la centrale (%s)", st.first_t and st.fini_t and string.format("%.2f min", (st.first_t - st.fini_t) / MIN) or "jamais"))
          local last3 = 0
          for _, row in ipairs(st.rows or {}) do if row.t >= (CHECK or 0) - 4 * MIN and row.power > 0 then last3 = last3 + 1 end end
          ctx.check(last3 >= 3, "AVEC la regle : production non nulle chaque minute des 4 dernieres, sous charge (" .. last3 .. ")")
          ctx.check(st.radars and st.radars >= opts.radars, "AVEC la regle : la charge a ete posee (" .. tostring(st.radars) .. " radars)")
        end
      elseif opts.mode == "ilot" then
        ctx.check(st.cut_t ~= nil and (st.cut_n or 0) >= (opts.enemy and 1 or 8), "la ligne a ete coupee (" .. tostring(st.cut_n) .. " poteau(x) sur " .. tostring(st.poles_in_box) .. " du couloir)")
        ctx.check((st.drills_off_before or 1) == 0, "avant la coupe, aucune foreuse hors du reseau (" .. tostring(st.drills_off_before) .. ")")
        ctx.check(st.saw_dark == true, "la coupe isole bien des foreuses (ilot sans courant)")
        if opts.enemy then ctx.check(st.biter ~= nil and st.biter.valid, "l'ennemi est pose et vivant a la fin") end
        if opts.expect == "dead" then
          ctx.check(st.back_t == nil, "SANS la regle : les foreuses ne sont jamais rallumees (ennemi sur la ligne, aucun second chemin)")
        else
          local limit = (opts.back_min or 4) * MIN
          ctx.check(st.back_t ~= nil and (st.back_t - (st.cut_t or 0)) <= limit,
            string.format("AVEC la regle : les foreuses sont rallumees en %d min au plus (%s)", opts.back_min or 4, st.back_t and string.format("%.0f s", (st.back_t - st.cut_t) / 60) or "jamais"))
          ctx.check((st.dark_now or 1) == 0, "AVEC la regle : plus aucune foreuse sans courant a la fin")
        end
        ctx.check(power > 0, "production non nulle a la fin")
      elseif opts.mode == "porte" then
        ctx.check(st.req_t ~= nil, "les trois modules ont ete demandes")
        if opts.expect == "dead" then
          ctx.check((st.max_held or 0) == 0, "SANS la regle : aucun module retenu (" .. tostring(st.max_held) .. ")")
          ctx.check((st.passed or 0) == 3, "SANS la regle : les trois modules passent aussitot (" .. tostring(st.passed) .. ")")
        else
          ctx.check((st.max_held or 0) >= 1, "AVEC la regle : au moins un module retenu pour le courant (" .. tostring(st.max_held) .. ")")
          ctx.check(st.fini == 2, "AVEC la regle : la centrale de plus est finie, demandee par la puissance retenue (" .. tostring(st.fini) .. " centrale(s) finie(s))")
          ctx.check((st.passed or 0) == 3, "AVEC la regle : les trois modules passent une fois la centrale agrandie (" .. tostring(st.passed) .. ")")
          ctx.check((st.last_held or 0) == 0, "AVEC la regle : plus aucun module retenu a la fin")
        end
      elseif opts.mode == "avance" then
        ctx.check(st.load_t ~= nil and (st.radars or 0) >= opts.radars, "la charge est posee (" .. tostring(st.radars) .. " radars)")
        if opts.expect == "dead" then
          ctx.check(st.fini == 1, "SANS la regle : 72 % de la capacite ne demande pas de centrale de plus (" .. tostring(st.fini) .. " finie(s))")
        else
          ctx.check(st.fini == 2, "AVEC la regle : la centrale de plus est finie AVANT la saturation (" .. tostring(st.fini) .. " finie(s))")
        end
        ctx.check(power <= 90000, "production dans la capacite")
      else
        ctx.check(st.cut_t ~= nil, "la panne a ete provoquee")
        ctx.check((st.before or 0) > 0, "production avant la panne non nulle", tostring(st.before))
        if opts.expect == "dead" then
          ctx.check((st.zero_after_cut or 0) >= 300, "SANS la regle : plus de 5 min de production nulle apres la panne (" .. tostring(st.zero_after_cut) .. " s)")
        else
          ctx.check((st.max_gap or 0) <= 90, "AVEC la regle : la production ne tombe pas a 0 plus de 90 s de suite (" .. tostring(st.max_gap) .. " s)")
          ctx.check((st.zero_after_cut or 0) <= 150, "AVEC la regle : au plus 150 s de production nulle en tout (" .. tostring(st.zero_after_cut) .. " s)")
        end
        ctx.check(st.restock_t ~= nil and arms >= 2, "les bras sont reposes a la fin (" .. arms .. ")")
        ctx.check(power > 0.2 * (st.before or 1), string.format("la production est revenue a la fin (%.0f J/tick pour %.0f avant)", power, st.before or 0))
      end
    end,
  }
end
