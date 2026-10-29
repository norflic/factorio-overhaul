--[[
  Lot CORR-ENERGIE (remarque 10 du DC : la centrale doit s'adapter à la demande). Scénario PROVOQUÉ et déterministe, sans cerveau
  (plan directeur « seul » : le banc tient le rôle du cerveau, comme ia1-build) :
    1. terrain vidé et façonné (herbe, lac au sud, gisement de charbon) ; coffre d'équipe garni (de quoi bâtir 4 centrales) ;
    2. la centrale (1 chaudière, 2 machines à vapeur : 1,8 MW) est demandée au plan directeur et bâtie par les PNJ ;
    3. centrale finie : le banc pose une CHARGE (des radars, 300 kW chacun, sur des poteaux moyens reliés au réseau de la
       centrale) supérieure à la production ;
    4. mesures : production des machines à vapeur (J/tick), centrales finies, radars en « low_power » ou en marche.
  Variantes (chacune dans son fichier scenarios/energie-*.lua, même code) :
    energie-demande          : 8 radars (2,4 MW), règle allumée → une 2e centrale apparaît, le courant revient ;
    energie-demande-temoin   : mêmes 8 radars, règle COUPÉE par le réglage de banc no_grow → le réseau reste saturé ;
    energie-plafond          : 20 radars (6 MW), règle allumée → jamais plus de 3 centrales finies.
  Lancement : banc.py --out <archive> --qui ENERGIE -- <ticks> energie-<variante> <source> ; journal : [FO-ENERGIE-<VARIANTE>].
]]

local MIN = 3600
local HALF = 140
local T_REQUEST = 120

local function sorted_keys(t)
  local k = {}
  for x in pairs(t) do k[#k + 1] = x end
  table.sort(k, function(a, b) return tostring(a) < tostring(b) end)
  return k
end

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

--- Terrain : tout vidé puis herbe, deux lacs (nord et sud : de la rive pour plusieurs centrales), charbon.
local function shape(ctx, c, lake)
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
  water_disc(water, c.x + 4, c.y + 78 + (lake - 20), lake)
  water_disc(water, c.x + 4, c.y - 78 - (lake - 20), lake)
  s.set_tiles(water, true) -- eau AVANT les entités (F135)
  deposit(s, "coal", c.x - 56, c.y - 56, 8, 30000)
  deposit(s, "iron-ore", c.x + 56, c.y - 28, 6, 4000)
end

--- Coffre d'équipe garni (96 cases : 15 de fer, 3 de cuivre, 32 de charbon…). Rend les objets qui n'ont PAS tous tenu.
local function stock_chest(chest)
  local lost = {}
  for _, it in ipairs({
    { "iron-plate", 1500 }, { "copper-plate", 300 }, { "coal", 1600 }, { "stone", 100 },
    { "electric-mining-drill", 4 }, { "stone-furnace", 6 }, { "transport-belt", 600 }, { "inserter", 60 },
    { "fast-inserter", 10 }, { "burner-inserter", 40 }, { "medium-electric-pole", 120 }, { "big-electric-pole", 10 },
    { "iron-chest", 10 }, { "boiler", 4 }, { "steam-engine", 8 }, { "offshore-pump", 4 },
    { "pistol", 4 }, { "firearm-magazine", 100 },
  }) do
    local n = chest.insert({ name = it[1], count = it[2] })
    if n < it[2] then lost[#lost + 1] = it[1] end
  end
  return lost
end

local function status_names()
  local names = {}
  for k, v in pairs(defines.entity_status) do names[v] = k end
  return names
end

--- Production (J/tick) et nombre de machines à vapeur de la force du joueur.
local function steam_power(s)
  local power, n = 0, 0
  for _, e in ipairs(s.find_entities_filtered({ name = "steam-engine", force = "player" })) do
    power = power + e.energy_generated_last_tick
    n = n + 1
  end
  return power, n
end

--- Centrales finies du rapport du plan directeur.
local function plants_of(r)
  local fini, open, refused = 0, 0, 0
  for _, p in ipairs(r and r.projects or {}) do
    local pt = p.parts and p.parts[1]
    if pt and pt.kind == "centrale" then
      if p.state == "fini" then fini = fini + 1 elseif p.state == "refuse" then refused = refused + 1 else open = open + 1 end
    elseif not pt and p.state == "attente" then
      open = open + 1
    end
  end
  return fini, open, refused
end

--- Charge : n radars par grappes de 8 autour d'un poteau moyen ; les grappes sont reliées au réseau de la centrale par une
--- chaîne de poteaux moyens (pas de 7 tuiles) vers le nord. Rend le nombre de radars posés.
local function place_load(ctx, n)
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
  local prev = start
  local placed, cluster = 0, 0
  local cx, cy = start.position.x + 12, start.position.y - 30 -- vers le nord-est du poteau : hors des rives
  -- chaîne de poteaux moyens de `start` jusqu'à (cx, cy)
  local last = prev
  local steps = 0
  while steps < 20 do
    local dx, dy = cx - last.position.x, cy - last.position.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist <= 6 then break end
    local k = 6.5 / dist
    local tx, ty = last.position.x + dx * k, last.position.y + dy * k
    local pos = s.find_non_colliding_position("medium-electric-pole", { tx, ty }, 2, 0.5)
    local pole = pos and s.create_entity({ name = "medium-electric-pole", position = pos, force = "player" })
    if not pole then return placed, "chaine de poteaux coupee" end
    pole.connect_neighbour(last)
    last = pole
    steps = steps + 1
  end
  local offsets = { { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 }, { 3, 3 }, { -3, 3 }, { 3, -3 }, { -3, -3 } }
  while placed < n do
    cluster = cluster + 1
    local hub_pos = s.find_non_colliding_position("medium-electric-pole", { last.position.x + 5, last.position.y }, 3, 0.5)
    local hub = hub_pos and s.create_entity({ name = "medium-electric-pole", position = hub_pos, force = "player" })
    if not hub then return placed, "poteau de grappe impossible" end
    hub.connect_neighbour(last)
    for _, o in ipairs(offsets) do
      if placed < n then
        local r = s.create_entity({ name = "radar", position = { hub.position.x + o[1], hub.position.y + o[2] }, force = "player" })
        if r then placed = placed + 1 end
      end
    end
    last = hub
    if cluster > 4 then break end
  end
  return placed, nil
end

--- Radars de la charge : { en marche, low_power, autres }.
local function radar_state(s)
  local names = status_names()
  local working, low, other = 0, 0, 0
  for _, r in ipairs(s.find_entities_filtered({ name = "radar", force = "player" })) do
    local st = names[r.status or -1]
    if st == "working" or st == "normal" then working = working + 1
    elseif st == "low_power" then low = low + 1
    else other = other + 1 end
  end
  return working, low, other
end

return function(variant, opts)
  local TAG = "[FO-ENERGIE-" .. string.upper(variant) .. "] "
  local CHECK = opts.check_tick
  return {
    description = "CORR-ENERGIE : centrale qui s'adapte a la demande (" .. variant .. ")",
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local s = ctx.surface()
      local st = ctx.state()
      local c = { x = 0, y = 0 }
      st.c = c
      shape(ctx, c, opts.lake or 20)
      -- le banc tient le rôle du cerveau : l'automatisation (fo-war-ia3e) éteindrait le plan directeur vide (Auto.IDLE_OFF)
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
      if opts.no_grow then
        ctx.check(ctx.remote("fo-ia1d", "set_option", "player", "no_grow", true) == true, "regle de croissance COUPEE (reglage de banc)")
      end
      st.t0 = game.tick
      st.timeline = {}
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.t0 then return end
      local t = e.tick - st.t0
      local s = ctx.surface()
      if t == T_REQUEST then
        st.plant_id = ctx.remote("fo-ia1d", "request", "player", { gen = "steam", args = { 1 }, feed = true })
        ctx.log(TAG .. "centrale demandee, projet " .. tostring(st.plant_id))
      end
      if t <= T_REQUEST or t % 600 ~= 0 then return end
      local r = ctx.remote("fo-ia1d", "report", "player")
      if not r then return end
      local fini, open, refused = plants_of(r)
      local power = steam_power(s)
      -- la charge est posée une minute après la fin de la première centrale (chaudière allumée, machines en marche)
      if fini >= 1 and not st.fini_t then st.fini_t = t end
      if st.fini_t and not st.load_t and t >= st.fini_t + MIN then
        local placed, why = place_load(ctx, opts.radars)
        st.load_t, st.radars = t, placed
        ctx.log(string.format("%scharge posee a %.1f min : %d radar(s) sur %d voulus (%s) ; production avant %.0f J/tick",
          TAG, t / MIN, placed, opts.radars, tostring(why or "ok"), power))
      end
      local working, low, other = radar_state(s)
      local row = { t = t, power = power, fini = fini, open = open, refused = refused, working = working, low = low }
      st.timeline[#st.timeline + 1] = row
      if t % (MIN) == 0 then
        ctx.log(string.format("%sminute %d : %d centrale(s) finie(s), %d ouverte(s), %d refusee(s) ; production %.0f J/tick (%.0f kW) ; radars en marche %d, low_power %d, autres %d",
          TAG, math.floor(t / MIN), fini, open, refused, power, power * 60 / 1000, working, low, other))
      end
      st.last = row
    end,

    finish = function(ctx)
      local st = ctx.state()
      local s = ctx.surface()
      local r = ctx.remote("fo-ia1d", "report", "player")
      local fini, open, refused = plants_of(r)
      local power, engines = steam_power(s)
      local working, low, other = radar_state(s)
      -- production maximale vue sur la fin (un relevé isolé peut tomber sur un tick creux)
      local peak = 0
      for _, row in ipairs(st.timeline or {}) do if row.t >= (st.load_t or 0) and row.power > peak then peak = row.power end end
      ctx.log(string.format("%sFIN : %d centrale(s) finie(s), %d ouverte(s), %d refusee(s), %d machine(s) a vapeur ; production %.0f J/tick (crete %.0f) ; radars en marche %d, low_power %d, autres %d",
        TAG, fini, open, refused, engines, power, peak, working, low, other))
      for _, p in ipairs(r and r.projects or {}) do
        local pt = p.parts and p.parts[1]
        local miss = {}
        for _, m in ipairs(p.missing or {}) do miss[#miss + 1] = tostring(m[1]) .. "x" .. tostring(m[2]) end
        ctx.log(string.format("%sprojet %d : %s%s, %d/%d entites, %s ; manque %s", TAG, p.id, p.state, p.reason and (" (" .. p.reason .. ")") or "", p.built, p.total,
          pt and (pt.kind .. " " .. pt.key) or "pas planifie", table.concat(miss, " ")))
      end
      ctx.check(fini >= 1, "la premiere centrale est finie")
      ctx.check(st.load_t ~= nil and (st.radars or 0) == opts.radars, string.format("charge posee : %d radars sur %d", st.radars or 0, opts.radars))
      local CAP1 = 30000 -- une chaudiere, deux machines : 2 x 900 kW = 1,8 MW = 30 000 J/tick
      if opts.expect == "grow" then
        ctx.check(fini == 2, "AVEC la regle : une 2e centrale est finie (" .. fini .. " centrale(s))")
        ctx.check(peak > CAP1 * 1.05, string.format("AVEC la regle : production au-dela de la centrale seule (%.0f J/tick > %d)", peak, CAP1))
        ctx.check(working >= opts.radars - 1, string.format("AVEC la regle : le courant est revenu (%d radars en marche sur %d)", working, opts.radars))
      elseif opts.expect == "stay" then
        ctx.check(fini == 1 and engines == 2, "SANS la regle : une seule centrale (" .. fini .. " finie(s), " .. engines .. " machines)")
        ctx.check(peak <= CAP1 * 1.001, string.format("SANS la regle : la production reste plafonnee a 30 000 J/tick (crete %.0f)", peak))
        ctx.check(low >= opts.radars - 2, string.format("SANS la regle : le reseau reste sature (%d radars en low_power sur %d)", low, opts.radars))
      elseif opts.expect == "cap" then
        ctx.check(fini <= 3, "plafond : jamais plus de 3 centrales finies (" .. fini .. ")")
        ctx.check(fini >= 2, "plafond : la croissance a bien eu lieu (" .. fini .. " centrales finies)")
        ctx.check(engines <= 6, "plafond : au plus 6 machines a vapeur (" .. engines .. ")")
      end
    end,
  }
end
