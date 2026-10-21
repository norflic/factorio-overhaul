--[[
  Lot D4m (OBJECTIFS.md D4-2 et D4-5) : USINE GÉANTE dans le champ de la caméra, pour mesurer la mémoire vidéo
  et les images par seconde dans les deux qualités de sprites, et juger de loin la lisibilité et la sensation
  de gigantisme (Q21). Format des greffons : tools/autotest/README.md §4 ; procédure de mesure : §5.

  Usine : 288 × 180 tuiles de béton, 4 fois la suite des familles à niveaux de shared/levels/config.lua
  (aujourd'hui 7 : centre, mitrailleuse, laser, mur, foreuse, four, assembleur), une BANDE par famille :
  tapis en boucle fermée (vanilla : normal, rapide, express), bras (vanilla : 4 sortes) de part et d'autre,
  bâtiments de la famille côte à côte, tous les niveaux à la suite (1, 2, … max, puis on recommence, décalé
  d'une bande à l'autre). Environ 4 200 bâtiments à niveaux, 14 000 tapis chargés d'objets, 2 500 bras.
  Tout ce qui travaille travaille : assembleurs (paquets de science rouges, 100 recettes), fours (acier,
  charbon), foreuses (minerai de fer sous chacune, sortie sur le tapis), tourelles chargées, alimentation
  invisible (ctx.power : aucun poteau dans le champ).
  Les NOMS et le NOMBRE de niveaux viennent de la config (LV.name, f.max), la taille des bâtiments du prototype
  chargé (tile_width, tile_height) : le banc tourne tel quel quand les sprites V3 arrivent.

  Session avec images (fo-captures.bat d4-geant) : la caméra du joueur (contrôleur spectateur) suit une suite
  de VUES fixes, chacune mesurée par un LuaProfiler (images de JEU par seconde : UPS) :
    repere-debut (zone vide)  180 ticks
    z030-jour  zoom 0,3, midi     600 ticks      repere-1 60 ticks
    z050-jour  zoom 0,5, midi     600 ticks      repere-2 60 ticks
    z030-nuit  zoom 0,3, minuit   600 ticks      repere-3 60 ticks
    z050-nuit  zoom 0,5, minuit   600 ticks
    repere-fin (zone vide) jusqu'à la fin : captures (take_screenshot rend hors écran, F51).
  Les vues « repère » montrent une zone vide (presque aucun sprite) : elles découpent le fichier de
  statistiques de rendu du jeu (--output-perf-stats) en phases (vram.py). Journal :
    [FO-D4-GEANT] PHASE debut <vue> tick <t> zoom <z> daytime <d>
    [FO-D4-GEANT] PHASE fin <vue> tick <t> ticks <n> Durée : <ms>ms
  Captures : vues 0,3 et 0,5 de jour et de nuit, 0,3 en 1920 × 1080, détail au zoom 1 (jour, nuit) et 2.
  Contrôles : à la création (pose) et au tick 120 (machines au travail), puis le BILAN [FO-D4-GEANT].
  Banc sans images (fo-autotest.bat, 600 ticks) : pose et contrôles seulement.
]]
local LV = require("__factorio-overhaul__/shared/levels/config")

local FW = 288              -- largeur (tuiles) ; zoom 0,3 en 1920 × 1080 : 200 × 113 tuiles visibles
local CYCLES = 4            -- répétitions de la suite des familles (hauteur ≈ 180 tuiles)
local X0, Y0 = 64, -96      -- coin nord-ouest : hors du départ (0, 0)
local FLOOR = "concrete"
local MARK = { x0 = -360, y0 = -60, x1 = -200, y1 = 40 } -- zone vide des vues repère (160 × 100 tuiles)
local BELTS = { "transport-belt", "fast-transport-belt", "express-transport-belt" }
local INSERTERS = { "inserter", "fast-inserter", "long-handed-inserter", "stack-inserter" }
local SHIFT = 7             -- décalage des niveaux d'une bande à la suivante

--- Suite des vues (la dernière dure jusqu'à la fin de la session).
local TIMELINE = {
  { name = "repere-debut", ticks = 180 },
  { name = "z030-jour", zoom = 0.3, daytime = 0, ticks = 600 },
  { name = "repere-1", ticks = 60 },
  { name = "z050-jour", zoom = 0.5, daytime = 0, ticks = 600 },
  { name = "repere-2", ticks = 60 },
  { name = "z030-nuit", zoom = 0.3, daytime = 0.5, ticks = 600 },
  { name = "repere-3", ticks = 60 },
  { name = "z050-nuit", zoom = 0.5, daytime = 0.5, ticks = 600 },
  { name = "repere-fin" },
}
local STARTS, MEASURE_END = {}, 0
for i, v in ipairs(TIMELINE) do
  STARTS[i] = MEASURE_END
  MEASURE_END = MEASURE_END + (v.ticks or 0)
end

--- Disposition d'une bande selon le TYPE du prototype de la famille (jamais selon un nom).
local POLICY = {
  ["container"] = { inserters = true, lanes = { "iron-plate", "copper-plate" } },
  ["ammo-turret"] = { inserters = true, ammo = true, lanes = { "firearm-magazine", "firearm-magazine" } },
  ["electric-turret"] = { inserters = false, lanes = { "battery", "electronic-circuit" } },
  ["wall"] = { wall = true },
  ["mining-drill"] = { inserters = false, drill = true }, -- tapis vides : les foreuses les remplissent
  ["furnace"] = { inserters = true, furnace = true, lanes = { "iron-plate", "coal" } },
  ["assembling-machine"] = { inserters = true, assembler = true, lanes = { "copper-plate", "iron-gear-wheel" } },
}

local PROF -- LuaProfiler de la vue mesurée en cours (jamais dans global : objet de la session seulement)

local N, E, S, W = defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west

--- Pose une entité ; compte réussites et refus (un nom inconnu n'appelle pas create_entity, qui lèverait une erreur).
local function put(s, acc, name, x, y, dir, amount)
  if not acc.protos[name] then
    acc.protos[name] = game.entity_prototypes[name] or false
  end
  if not acc.protos[name] then
    acc.refused[#acc.refused + 1] = name .. " (prototype absent)"
    return nil
  end
  -- Gisement (amount donné) : force neutre, comme le moteur les génère ; tout le reste : force du joueur.
  local e = s.create_entity({ name = name, position = { x, y }, direction = dir, force = amount and "neutral" or "player",
    raise_built = false, amount = amount })
  if not e then acc.refused[#acc.refused + 1] = string.format("%s (%.1f, %.1f)", name, x, y) end
  return e
end

--- Charge les deux voies d'un tapis : 2 objets par voie et par tuile (moitié de la densité maximale).
local function load_belt(e, lanes, acc)
  if not (e and lanes) then return end
  for li = 1, 2 do
    local line = e.get_transport_line(li)
    for _, pos in ipairs({ 0.125, 0.625 }) do
      if line.insert_at(pos, { name = lanes[li], count = 1 }) then acc.items = acc.items + 1 end
    end
  end
end

--- Tapis en BOUCLE fermée sur le pourtour de la bande (x de xa à xb, rangées yT et yB) : rien ne bouchonne.
local function belt_loop(s, acc, name, xa, xb, yT, yB, lanes)
  local function b(x, y, dir)
    local e = put(s, acc, name, x + 0.5, y + 0.5, dir)
    if e then
      acc.belts = acc.belts + 1
      load_belt(e, lanes, acc)
    end
  end
  for x = xa, xb - 1 do b(x, yT, E) end
  for y = yT, yB - 1 do b(xb, y, S) end
  for x = xb, xa + 1, -1 do b(x, yB, W) end
  for y = yB, yT + 1, -1 do b(xa, y, N) end
end

--- Taille d'une famille : la plus grande emprise de ses niveaux CHARGÉS (repli : la config).
local function family_size(f)
  local size = f.size
  for n = 1, f.max do
    local p = game.entity_prototypes[LV.name(f, n)]
    if p then size = math.max(size, p.tile_width, p.tile_height) end
  end
  return size
end

--- Hauteur d'une bande : tapis, [bras], bâtiments, [bras], tapis, rangée vide (murs : 2 rangées + 1 vide).
local function stripe_height(pol, size)
  if pol.wall then return 3 end
  return size + 3 + (pol.inserters and 2 or 0)
end

--- Une bande de la famille f à partir de la rangée y ; renvoie la première rangée libre après elle.
local function stripe(s, acc, f, rep, y)
  local pol = POLICY[f.type] or {}
  local placed = acc.levels[f.key]
  local function building(n, x, y_)
    local e = put(s, acc, LV.name(f, n), x, y_)
    if e then
      acc.buildings = acc.buildings + 1
      placed[n] = (placed[n] or 0) + 1
    end
    return e
  end
  if pol.wall then
    for row = 0, 1 do
      for x = X0, X0 + FW - 1 do
        building((math.floor((x - X0) / 4) + rep * SHIFT) % f.max + 1, x + 0.5, y + row + 0.5)
      end
    end
    return y + stripe_height(pol, 1)
  end
  local size = acc.sizes[f.key]
  local ins = pol.inserters
  local yT = y
  local yM = yT + 1 + (ins and 1 or 0)
  local yB = yM + size + (ins and 1 or 0)
  local xa, xb = X0, X0 + FW - 1
  belt_loop(s, acc, BELTS[rep % #BELTS + 1], xa, xb, yT, yB, pol.lanes)
  local inserter = INSERTERS[(rep + f.index) % #INSERTERS + 1]
  local k = 0
  for left = xa + 2, xb - 1 - size, size + 1 do
    local n = (k + rep * SHIFT) % f.max + 1
    if pol.drill then
      for dx = 0, size - 1 do
        for dy = 0, size - 1 do
          put(s, acc, "iron-ore", left + dx + 0.5, yM + dy + 0.5, nil, 100000)
        end
      end
    end
    local e = building(n, left + size / 2, yM + size / 2)
    if e then
      if pol.assembler then
        e.set_recipe("automation-science-pack")
        e.insert({ name = "copper-plate", count = 100 })
        e.insert({ name = "iron-gear-wheel", count = 100 })
      elseif pol.furnace then
        e.insert({ name = "coal", count = 50 })
        e.insert({ name = "iron-plate", count = 100 })
      elseif pol.ammo then
        e.insert({ name = "firearm-magazine", count = 20 })
      end
    end
    if ins then
      -- Direction nord : prise au nord, dépôt au sud (tapis → bâtiment en haut, bâtiment → tapis en bas).
      if put(s, acc, inserter, left + 0.5, yT + 1.5, N) then acc.inserters = acc.inserters + 1 end
      if put(s, acc, inserter, left + 0.5, yB - 0.5, N) then acc.inserters = acc.inserters + 1 end
    end
    k = k + 1
  end
  return y + stripe_height(pol, size) -- = yB + 2
end

--- Toutes les vues sont à l'intérieur de l'usine : elle remplit le champ.
local function center(st)
  return { x = X0 + FW / 2, y = Y0 + st.height / 2 }
end

local function view_index(t)
  local idx = 1
  for i = 1, #TIMELINE do
    if t >= STARTS[i] then idx = i end
  end
  return idx
end

--- Caméra du joueur (session avec images seulement) : une vue fixe par phase, mesurée par un LuaProfiler.
local function camera(ctx, e)
  local player = game.connected_players[1]
  if not player then return end -- banc sans images : rien à filmer
  local st = ctx.state()
  if not st.center then return end
  local s = ctx.surface()
  local cam = st.cam
  if not cam then
    cam = { t0 = e.tick, i = 0, start = e.tick }
    st.cam = cam
    player.set_controller({ type = defines.controllers.spectator })
    s.freeze_daytime = true
    ctx.log(string.format("camera : joueur %s en spectateur, vues de %d ticks en tout avant les captures",
      player.name, MEASURE_END))
  end
  local i = view_index(e.tick - cam.t0)
  if i == cam.i then return end
  local prev = TIMELINE[cam.i]
  if prev and prev.zoom and PROF then
    PROF.stop()
    log({ "", ctx.tag, " PHASE fin ", prev.name, " tick ", tostring(e.tick), " ticks ", tostring(e.tick - cam.start), " ", PROF })
    PROF = nil
  end
  cam.i, cam.start = i, e.tick
  local v = TIMELINE[i]
  if v.zoom then
    player.teleport(st.center)
    player.zoom = v.zoom
    s.daytime = v.daytime
    ctx.log(string.format("PHASE debut %s tick %d zoom %.2f daytime %.2f", v.name, e.tick, v.zoom, v.daytime))
    PROF = game.create_profiler()
  else
    player.teleport(st.mark)
    player.zoom = 1
    ctx.log(string.format("REPERE %s tick %d (zone vide)", v.name, e.tick))
  end
end

local function count_status(s, st, type_)
  local area = { { X0, Y0 }, { X0 + FW, Y0 + st.height } }
  local all, working = 0, 0
  for _, e in ipairs(s.find_entities_filtered({ area = area, type = type_, force = "player" })) do
    all = all + 1
    if e.status == defines.entity_status.working then working = working + 1 end
  end
  return working, all
end

return {
  description = "D4m : usine geante (milliers de batiments a niveaux, tapis, bras) en vue eloignee, "
    .. "memoire video et images par seconde",
  base = nil,
  check_tick = 120,               -- pendant la vue repère de début : la mesure n'est pas perturbée
  shots_delay = MEASURE_END + 30, -- captures APRÈS les vues mesurées

  init = function(ctx)
    local s = ctx.surface()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    game.map_settings.enemy_expansion.enabled = false
    game.map_settings.pollution.enabled = false
    local steel = game.forces.player.recipes["steel-plate"]
    if steel then steel.enabled = true end

    local acc = { protos = {}, refused = {}, levels = {}, sizes = {}, buildings = 0, belts = 0, inserters = 0, items = 0 }
    -- Prototypes de tous les niveaux de toutes les familles (noms : config).
    local missing, expected = {}, 0
    for _, f in ipairs(LV.families) do
      acc.levels[f.key] = {}
      acc.sizes[f.key] = family_size(f)
      for n = 1, f.max do
        expected = expected + 1
        if not game.entity_prototypes[LV.name(f, n)] then missing[#missing + 1] = LV.name(f, n) end
      end
    end
    ctx.check(#missing == 0, "prototypes de niveaux presents (noms lus dans la config)",
      #missing > 0 and table.concat(missing, ", ", 1, math.min(#missing, 10))
      or string.format("%d familles, %d niveaux", #LV.families, expected))

    -- Hauteur : somme des bandes (calculée comme stripe le fait).
    local height = 0
    for _ = 1, CYCLES do
      for _, f in ipairs(LV.families) do
        height = height + stripe_height(POLICY[f.type] or {}, acc.sizes[f.key])
      end
    end
    local st = ctx.state()
    st.height = height
    -- Terrain : alentours générés (vue 0,3 en 4K : 400 × 225 tuiles), usine et zone repère vides et pavées.
    local c = center(st)
    s.request_to_generate_chunks({ x = c.x, y = c.y }, 8)
    s.force_generate_chunk_requests()
    ctx.prepare_area(X0 - 2, Y0 - 2, X0 + FW + 2, Y0 + height + 2, FLOOR)
    ctx.prepare_area(MARK.x0, MARK.y0, MARK.x1, MARK.y1, "grass-1")
    local enemies = 0
    for _, en in ipairs(s.find_entities_filtered({ area = { { c.x - 320, c.y - 320 }, { c.x + 320, c.y + 320 } }, force = "enemy" })) do
      en.destroy()
      enemies = enemies + 1
    end

    -- Usine : CYCLES fois la suite des familles, une bande chacune.
    local y = Y0
    for rep = 0, CYCLES - 1 do
      for _, f in ipairs(LV.families) do
        y = stripe(s, acc, f, rep, y)
      end
    end
    -- Alimentation invisible : poteaux de portée 64 (128 × 128 tuiles chacun) sur toute l'usine.
    local zones, powered = 0, 0
    for px = X0 + 64, X0 + FW + 63, 128 do
      for py = Y0 + 64, Y0 + height + 63, 128 do
        zones = zones + 1
        if ctx.power(px, py) then powered = powered + 1 end
      end
    end

    st.center = center(st)
    st.mark = { x = (MARK.x0 + MARK.x1) / 2, y = (MARK.y0 + MARK.y1) / 2 }
    st.detail = { x = X0 + FW / 2, y = Y0 + 22 }
    local per, all_levels = {}, true
    for _, f in ipairs(LV.families) do
      local got = 0
      for n = 1, f.max do if (acc.levels[f.key][n] or 0) > 0 then got = got + 1 end end
      if got < f.max then all_levels = false end
      per[#per + 1] = string.format("%s %d/%d", f.key, got, f.max)
    end
    ctx.log(string.format("usine : %d x %d tuiles en (%d, %d), %d batiments a niveaux, %d tapis, %d bras, %d objets "
      .. "sur les tapis, %d ennemis retires ; vue zoom 0,3 en 1920x1080 : 200 x 113 tuiles",
      FW, height, X0, Y0, acc.buildings, acc.belts, acc.inserters, acc.items, enemies))
    ctx.check(all_levels, "tous les niveaux de chaque famille poses", table.concat(per, ", "))
    ctx.check(acc.buildings >= 3000, "usine geante : batiments a niveaux poses (au moins 3 000)", acc.buildings)
    ctx.check(acc.belts >= 10000 and acc.inserters >= 2000, "tapis et bras vanilla poses (10 000 et 2 000 au moins)",
      string.format("%d tapis, %d bras", acc.belts, acc.inserters))
    ctx.check(acc.items >= 10000, "objets sur les tapis", acc.items)
    ctx.check(#acc.refused == 0, "aucune pose refusee",
      #acc.refused > 0 and (#acc.refused .. " : " .. table.concat(acc.refused, " | ", 1, math.min(#acc.refused, 8))) or nil)
    ctx.check(powered == zones, "alimentation invisible sur toute l'usine", powered .. "/" .. zones .. " zones de 128 x 128")
    ctx.check(FW >= 200 and height >= 113 and y - Y0 == height, "l'usine remplit la vue 0,3 en 1920x1080 (200 x 113 tuiles)",
      string.format("usine %d x %d", FW, height))
  end,

  tick = function(ctx, e)
    camera(ctx, e)
  end,

  finish = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    local wa, na = count_status(s, st, "assembling-machine")
    local wf, nf = count_status(s, st, "furnace")
    local wd, nd = count_status(s, st, "mining-drill")
    ctx.check(na > 0 and wa >= 0.8 * na, "assembleurs au travail (80 % au moins)", wa .. "/" .. na)
    ctx.check(nf > 0 and wf >= 0.8 * nf, "fours au travail (80 % au moins)", wf .. "/" .. nf)
    ctx.check(nd > 0 and wd >= 0.25 * nd, "foreuses au travail (25 % au moins : sortie sur un tapis charge)", wd .. "/" .. nd)
    local enemies = s.count_entities_filtered({ area = { { X0, Y0 }, { X0 + FW, Y0 + st.height } }, force = "enemy" })
    ctx.check(enemies == 0, "aucun ennemi dans l'usine", enemies)
    ctx.log(string.format("entites dans l'usine : %d", s.count_entities_filtered({ area = { { X0, Y0 }, { X0 + FW, Y0 + st.height } } })))
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    if not st.center then return end
    local c = st.center
    for _, v in ipairs(TIMELINE) do
      if v.zoom then add("usine-" .. v.name, c.x, c.y, v.zoom, v.daytime, { info = false }) end
    end
    add("usine-z030-hd-jour", c.x, c.y, 0.3, 0, { info = false, res = { 1920, 1080 } })
    add("usine-detail-z1-jour", st.detail.x, st.detail.y, 1, 0, { info = false })
    add("usine-detail-z1-nuit", st.detail.x, st.detail.y, 1, 0.5, { info = false })
    add("usine-detail-z2-jour", st.detail.x, st.detail.y, 2, 0, { info = false })
  end,
}
