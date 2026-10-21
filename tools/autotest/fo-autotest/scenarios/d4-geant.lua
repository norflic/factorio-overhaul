--[[
  Lot D4m (OBJECTIFS.md D4-2 et D4-5) : USINE GÉANTE dans le champ de la caméra, pour mesurer la mémoire vidéo
  et les images par seconde dans les deux qualités de sprites, et juger de loin la lisibilité et la sensation
  de gigantisme (Q21). Format des greffons : tools/autotest/README.md §4 ; procédure de mesure : §5.

  Usine : 288 tuiles de large, CYCLES fois la suite des familles à niveaux de shared/levels/config.lua
  (aujourd'hui 7 : centre, mitrailleuse, laser, mur, foreuse, four, assembleur), tournée pour que le mur ferme
  chaque cycle (le centre de l'usine montre alors les 7 familles même au zoom 0,5). Un BLOC par famille, en
  « sandwich » (aucune rangée vide), rangées du nord au sud :
      machines M1 | [bras] | tapis R1 | [bras] | machines M2
      machines M3 | [bras] | tapis R2 | [bras] | machines M4
  R1 et R2 forment une boucle fermée (vanilla : normal, rapide, express) : rien ne bouchonne. Chaque tapis
  sert les DEUX rangées de machines qui le bordent ; les machines se touchent (pas d'intervalle). Murs : deux
  rangées pleines. Tous les niveaux à la suite dans chaque rangée (1, 2, … max, puis on recommence, décalé
  d'une rangée à l'autre). Bras vanilla d'UNE case (normal, rapide, empileur) : le bras long prend à deux
  cases et ne servirait à rien collé au tapis (défaut de la version c5b1015, corrigé).
  Tout ce qui travaille travaille : assembleurs (paquets de science rouges, entrée et sortie par bras), fours
  (acier, charbon), foreuses (minerai sous chacune, sortie DIRECTE sur le tapis), tourelles chargées et
  ravitaillées, alimentation invisible (ctx.power : aucun poteau dans le champ).
  Les NOMS et le NOMBRE de niveaux viennent de la config (LV.name, f.max), la taille des bâtiments du prototype
  chargé (tile_width, tile_height) : le banc tourne tel quel quand les sprites V3 arrivent.

  CHAMP RÉEL (ce qui est dessiné) : le nombre d'entités dans le rectangle vu (demi-largeur = résolution /
  (64 × zoom) : 32 pixels par tuile au zoom 1) est compté par famille, avec les tapis et les bras, et écrit
  pour chaque champ de référence (contrôle du BILAN), chaque vue mesurée (résolution réelle de la fenêtre) et
  chaque capture :
    [FO-D4-GEANT] CHAMP <reference|vue|capture> <nom> <L>x<H> zoom <z> : <l> x <h> tuiles, batiments a niveaux
      <n> (machines <m>, murs <w>), tapis <t>, bras <b> ; familles <k>/<K> : <clé> <n> (<niveaux vus>/<max> niv.), …

  Session avec images (fo-captures.bat d4-geant) : la caméra du joueur (contrôleur spectateur) suit une suite
  de VUES fixes, chacune mesurée par un LuaProfiler (images de JEU par seconde : UPS ; aux repères, l'UPS de la
  simulation seule, presque rien n'étant dessiné) :
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
  Contrôles : à la création (pose) et au tick 120 (champ réel, bras et foreuses reliés, machines au travail),
  puis le BILAN [FO-D4-GEANT]. Banc sans images (fo-autotest.bat, 600 ticks) : pose et contrôles seulement.
  Essai à blanc (moteur simulé, sans le jeu) : tools/autotest/tests/d4_dryrun.lua.
]]
local LV = require("__factorio-overhaul__/shared/levels/config")

local FW = 288              -- largeur (tuiles) ; zoom 0,3 en 1920 × 1080 : 200 × 113 tuiles visibles
local CYCLES = 2            -- répétitions de la suite des familles (hauteur ≈ 188 tuiles aujourd'hui)
local X0, Y0 = 64, -96      -- coin nord-ouest : hors du départ (0, 0)
local FLOOR = "concrete"
local MARK = { x0 = -360, y0 = -60, x1 = -200, y1 = 40 } -- zone vide des vues repère (160 × 100 tuiles)
local BELTS = { "transport-belt", "fast-transport-belt", "express-transport-belt" }
local INSERTERS = { "inserter", "fast-inserter", "stack-inserter" } -- bras d'une case (prise et dépôt adjacents)
local SHIFT = 7             -- décalage des niveaux d'une rangée à la suivante

--- Champs de référence (centre de l'usine) : le premier porte le contrôle du BILAN.
local FIELDS = {
  { name = "z030-hd", zoom = 0.3, res = { 1920, 1080 } },
  { name = "z030", zoom = 0.3, res = { 1600, 900 } },
  { name = "z050-hd", zoom = 0.5, res = { 1920, 1080 } },
  { name = "z050", zoom = 0.5, res = { 1600, 900 } },
}
--- Seuils du champ z0,3 en 1920 × 1080 (contrôle du BILAN ; à blanc le 21/10 : voir README §5.2).
local FIELD_MIN_BUILDINGS = 2000 -- bâtiments à niveaux dessinés (murs compris)
local FIELD_MIN_MACHINES = 1500  -- dont machines (murs exclus)

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
--- Ordre des familles dans un cycle : la suite de la config, tournée pour que le mur (repéré par son TYPE)
--- FERME chaque cycle : le centre de l'usine, entre deux cycles, montre alors toutes les familles, même au zoom 0,5.
local ORDER = {}
do
  local nf, start = #LV.families, 1
  for i, f in ipairs(LV.families) do
    if f.type == "wall" then start = i % nf + 1 end
  end
  for k = 0, nf - 1 do ORDER[#ORDER + 1] = LV.families[(start - 1 + k) % nf + 1] end
end

local STARTS, MEASURE_END = {}, 0
for i, v in ipairs(TIMELINE) do
  STARTS[i] = MEASURE_END
  MEASURE_END = MEASURE_END + (v.ticks or 0)
end

--- Disposition d'un bloc selon le TYPE du prototype de la famille (jamais selon un nom).
---   io : un bras d'entrée et un bras de sortie par machine ; feed : un bras d'entrée ; drill : sortie directe.
local POLICY = {
  ["container"] = { io = true, lanes = { "iron-plate", "copper-plate" } },
  ["ammo-turret"] = { feed = true, ammo = true, lanes = { "firearm-magazine", "firearm-magazine" } },
  ["electric-turret"] = { lanes = { "battery", "electronic-circuit" } },
  ["wall"] = { wall = true },
  ["mining-drill"] = { drill = true }, -- tapis vides : les foreuses les remplissent
  ["furnace"] = { io = true, furnace = true, lanes = { "iron-plate", "coal" } },
  ["assembling-machine"] = { io = true, assembler = true, lanes = { "copper-plate", "iron-gear-wheel" } },
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

--- Tapis en BOUCLE fermée (x de xa à xb, rangées yT et yB, colonnes xa et xb entre elles) : rien ne bouchonne.
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

--- Hauteur d'un bloc : 4 rangées de machines, 2 tapis, [4 rangées de bras] ; murs : 2 rangées.
local function block_height(pol, size)
  if pol.wall then return 2 end
  return 4 * size + 2 + ((pol.io or pol.feed) and 4 or 0)
end

--- Un bloc de la famille f à partir de la rangée y ; renvoie la première rangée libre après lui.
local function block(s, acc, f, rep, y)
  local pol = POLICY[f.type] or {}
  local placed = acc.levels[f.key]
  local function building(n, x, y_, dir)
    local e = put(s, acc, LV.name(f, n), x, y_, dir)
    if e then
      acc.buildings = acc.buildings + 1
      placed[n] = (placed[n] or 0) + 1
    end
    return e
  end
  if pol.wall then
    for row = 0, 1 do
      for x = X0, X0 + FW - 1 do
        building((math.floor((x - X0) / 4) + (rep * 2 + row) * SHIFT) % f.max + 1, x + 0.5, y + row + 0.5)
      end
    end
    return y + block_height(pol, 1)
  end
  local size = acc.sizes[f.key]
  local i = (pol.io or pol.feed) and 1 or 0
  local yR1 = y + size + i
  local yM2 = yR1 + 1 + i
  local yM3 = yM2 + size
  local yR2 = yM3 + size + i
  local yM4 = yR2 + 1 + i
  local xa, xb = X0, X0 + FW - 1
  belt_loop(s, acc, BELTS[(rep + f.index) % #BELTS + 1], xa, xb, yR1, yR2, pol.lanes)
  -- above : la rangée est au nord de son tapis. Un bras tourné vers D prend du côté D et dépose à l'opposé
  -- (base : pickup_position {0, -1}, insert_position {0, 1.2} vers le nord) ; une foreuse dépose du côté D.
  local rows = {
    { y = y, above = true }, { y = yM2, above = false }, { y = yM3, above = true }, { y = yM4, above = false },
  }
  for r, row in ipairs(rows) do
    local y_ins = row.above and (row.y + size) or (row.y - 1)
    local dir_in = row.above and S or N   -- prise sur le tapis, dépôt dans la machine
    local dir_out = row.above and N or S  -- prise dans la machine, dépôt sur le tapis
    local inserter = INSERTERS[(rep + f.index + r) % #INSERTERS + 1]
    local k = 0
    for left = xa + 1, xb - size, size do
      local n = (k + ((rep * 4) + r - 1) * SHIFT) % f.max + 1
      if pol.drill then
        for dx = 0, size - 1 do
          for dy = 0, size - 1 do
            put(s, acc, "iron-ore", left + dx + 0.5, row.y + dy + 0.5, nil, 100000)
          end
        end
      end
      local e = building(n, left + size / 2, row.y + size / 2, pol.drill and (row.above and S or N) or nil)
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
      if pol.io or pol.feed then
        if put(s, acc, inserter, left + 0.5, y_ins + 0.5, dir_in) then acc.inserters = acc.inserters + 1 end
      end
      if pol.io then
        if put(s, acc, inserter, left + 1.5, y_ins + 0.5, dir_out) then acc.inserters = acc.inserters + 1 end
      end
      k = k + 1
    end
  end
  acc.blocks[#acc.blocks + 1] = { key = f.key, y = y, h = block_height(pol, size) }
  return y + block_height(pol, size) -- = yM4 + size
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

--- Noms des niveaux CHARGÉS de chaque famille (find_entities_filtered ne reçoit que des noms existants).
local function level_names()
  local per, all = {}, {}
  for _, f in ipairs(LV.families) do
    local names = {}
    for n = 1, f.max do
      local name = LV.name(f, n)
      if game.entity_prototypes[name] then
        names[#names + 1] = name
        all[#all + 1] = name
      end
    end
    per[f.key] = names
  end
  return per, all
end

--- Entités dans le champ réel d'une vue : rectangle centré en c, demi-côtés résolution / (64 × zoom) (32 pixels
--- par tuile au zoom 1). Une entité compte dès que sa boîte touche le rectangle (elle est dessinée, même en partie).
local function field(s, c, w, h, zoom)
  local hw, hh = w / (64 * zoom), h / (64 * zoom)
  local area = { { c.x - hw, c.y - hh }, { c.x + hw, c.y + hh } }
  local names = level_names()
  local r = { w = w, h = h, zoom = zoom, tw = 2 * hw, th = 2 * hh, n = 0, walls = 0, kinds = 0, all_levels = true, per = {} }
  for _, f in ipairs(LV.families) do
    local found = #names[f.key] > 0 and s.find_entities_filtered({ area = area, name = names[f.key], force = "player" }) or {}
    local seen, distinct = {}, 0
    for _, e in ipairs(found) do
      local _, lv = LV.parse(e.name)
      if lv and not seen[lv] then
        seen[lv] = true
        distinct = distinct + 1
      end
    end
    r.per[#r.per + 1] = { key = f.key, n = #found, levels = distinct, max = f.max }
    r.n = r.n + #found
    if f.type == "wall" then r.walls = r.walls + #found end
    if #found > 0 then r.kinds = r.kinds + 1 end
    if distinct < f.max then r.all_levels = false end
  end
  r.machines = r.n - r.walls
  r.belts = s.count_entities_filtered({ area = area, type = "transport-belt" })
  r.inserters = s.count_entities_filtered({ area = area, type = "inserter" })
  return r
end

local function field_line(kind, name, r)
  local per = {}
  for _, p in ipairs(r.per) do per[#per + 1] = string.format("%s %d (%d/%d niv.)", p.key, p.n, p.levels, p.max) end
  return string.format("CHAMP %s %s %dx%d zoom %.2f : %.0f x %.0f tuiles, batiments a niveaux %d (machines %d, murs %d), "
    .. "tapis %d, bras %d ; familles %d/%d : %s", kind, name, r.w, r.h, r.zoom, r.tw, r.th, r.n, r.machines, r.walls,
    r.belts, r.inserters, r.kinds, #LV.families, table.concat(per, ", "))
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
  if prev and PROF then
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
    -- Champ réel AVANT le chronomètre : résolution de la fenêtre du jeu (réduite : quelques pixels).
    local res = player.display_resolution
    ctx.log(field_line("vue", v.name, field(s, st.center, res.width, res.height, v.zoom)))
    ctx.log(string.format("PHASE debut %s tick %d zoom %.2f daytime %.2f", v.name, e.tick, v.zoom, v.daytime))
  else
    -- Repère (zone vide) : la simulation de l'usine tourne toujours, presque rien n'est dessiné. Son UPS mesure le
    -- coût de la SIMULATION seule (repere-debut contient les contrôles du tick 120 : ne pas s'en servir).
    player.teleport(st.mark)
    player.zoom = 1
    ctx.log(string.format("REPERE %s tick %d (zone vide)", v.name, e.tick))
    ctx.log(string.format("PHASE debut %s tick %d zoom %.2f daytime %.2f", v.name, e.tick, 1, s.daytime))
  end
  PROF = game.create_profiler()
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

--- Y a-t-il, au point p, une entité du filtre (petite boîte autour du point) ?
local function at(s, p, filter)
  filter.area = { { p.x - 0.05, p.y - 0.05 }, { p.x + 0.05, p.y + 0.05 } }
  return s.count_entities_filtered(filter) > 0
end

--- Bras reliés : prise sur un tapis et dépôt dans un bâtiment à niveaux, ou l'inverse (positions du moteur).
local function check_inserters(s, st, all_names)
  local area = { { X0, Y0 }, { X0 + FW, Y0 + st.height } }
  local ok, all, bad = 0, 0, nil
  local belt = { type = "transport-belt" }
  local bld = { name = all_names, force = "player" }
  for _, ins in ipairs(s.find_entities_filtered({ area = area, type = "inserter", force = "player" })) do
    all = all + 1
    local p, d = ins.pickup_position, ins.drop_position
    if (at(s, p, belt) and at(s, d, bld)) or (at(s, p, bld) and at(s, d, belt)) then
      ok = ok + 1
    elseif not bad then
      bad = string.format("%s en (%.1f, %.1f)", ins.name, ins.position.x, ins.position.y)
    end
  end
  return ok, all, bad
end

--- Foreuses : le point de dépôt est sur un tapis.
local function check_drills(s, st)
  local area = { { X0, Y0 }, { X0 + FW, Y0 + st.height } }
  local ok, all, bad = 0, 0, nil
  for _, d in ipairs(s.find_entities_filtered({ area = area, type = "mining-drill", force = "player" })) do
    all = all + 1
    if at(s, d.drop_position, { type = "transport-belt" }) then
      ok = ok + 1
    elseif not bad then
      bad = string.format("%s en (%.1f, %.1f)", d.name, d.position.x, d.position.y)
    end
  end
  return ok, all, bad
end

return {
  description = "D4m : usine geante (batiments a niveaux, tapis, bras) en vue eloignee, champ reel compte, "
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

    local acc = { protos = {}, refused = {}, levels = {}, sizes = {}, blocks = {}, buildings = 0, belts = 0, inserters = 0,
      items = 0 }
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

    -- Hauteur : somme des blocs (calculée comme block le fait).
    local height = 0
    for _ = 1, CYCLES do
      for _, f in ipairs(ORDER) do
        height = height + block_height(POLICY[f.type] or {}, acc.sizes[f.key])
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

    -- Usine : CYCLES fois la suite des familles (ORDER), un bloc chacune.
    local y = Y0
    for rep = 0, CYCLES - 1 do
      for _, f in ipairs(ORDER) do
        y = block(s, acc, f, rep, y)
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
    -- Détail (zoom 1 et 2) : premier bloc d'assembleurs (bras, tapis, machines), sinon le haut de l'usine.
    st.detail = { x = X0 + FW / 2, y = Y0 + 22 }
    for _, b in ipairs(acc.blocks) do
      if (POLICY[LV.by_key[b.key].type] or {}).assembler then
        st.detail = { x = X0 + FW / 2, y = b.y + b.h / 2 }
        break
      end
    end
    local per, all_levels = {}, true
    for _, f in ipairs(LV.families) do
      local got = 0
      for n = 1, f.max do if (acc.levels[f.key][n] or 0) > 0 then got = got + 1 end end
      if got < f.max then all_levels = false end
      per[#per + 1] = string.format("%s %d/%d", f.key, got, f.max)
    end
    local by_family = {}
    for _, f in ipairs(LV.families) do
      local n = 0
      for lv = 1, f.max do n = n + (acc.levels[f.key][lv] or 0) end
      by_family[#by_family + 1] = string.format("%s %d", f.key, n)
    end
    ctx.log(string.format("usine : %d x %d tuiles en (%d, %d), %d batiments a niveaux (%s), %d tapis, %d bras, %d objets "
      .. "sur les tapis, %d ennemis retires (le champ reel est compte au tick %d : lignes CHAMP)",
      FW, height, X0, Y0, acc.buildings, table.concat(by_family, ", "), acc.belts, acc.inserters, acc.items, enemies, 120))
    ctx.check(all_levels, "tous les niveaux de chaque famille poses", table.concat(per, ", "))
    ctx.check(acc.buildings >= 5000, "usine geante : batiments a niveaux poses dans l'usine entiere (au moins 5 000)",
      acc.buildings)
    ctx.check(acc.belts >= 5000 and acc.inserters >= 4000, "tapis et bras vanilla poses (5 000 et 4 000 au moins)",
      string.format("%d tapis, %d bras", acc.belts, acc.inserters))
    ctx.check(acc.items >= 10000, "objets sur les tapis", acc.items)
    ctx.check(#acc.refused == 0, "aucune pose refusee",
      #acc.refused > 0 and (#acc.refused .. " : " .. table.concat(acc.refused, " | ", 1, math.min(#acc.refused, 8))) or nil)
    ctx.check(powered == zones, "alimentation invisible sur toute l'usine", powered .. "/" .. zones .. " zones de 128 x 128")
    ctx.check(FW >= 200 and height >= 113 and y - Y0 == height, "l'usine depasse le champ z0,3 en 1920x1080 (200 x 113 tuiles)",
      string.format("usine %d x %d", FW, height))
  end,

  tick = function(ctx, e)
    camera(ctx, e)
  end,

  finish = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    -- Champ réel des vues de référence : ce que la caméra dessine vraiment (et non l'usine entière).
    local ref
    for _, v in ipairs(FIELDS) do
      local r = field(s, st.center, v.res[1], v.res[2], v.zoom)
      ctx.log(field_line("reference", v.name, r))
      ref = ref or r
    end
    ctx.check(ref.n >= FIELD_MIN_BUILDINGS and ref.machines >= FIELD_MIN_MACHINES,
      string.format("champ reel z0,3 en 1920x1080 : au moins %d batiments a niveaux dont %d machines (hors murs)",
        FIELD_MIN_BUILDINGS, FIELD_MIN_MACHINES),
      string.format("%d batiments (machines %d, murs %d), %d tapis, %d bras", ref.n, ref.machines, ref.walls, ref.belts,
        ref.inserters))
    ctx.check(ref.kinds == #LV.families and ref.all_levels,
      "champ reel z0,3 en 1920x1080 : toutes les familles et tous leurs niveaux",
      string.format("familles %d/%d, tous les niveaux %s", ref.kinds, #LV.families, ref.all_levels and "oui" or "NON"))
    local _, all_names = level_names()
    local io, ni, bad_i = check_inserters(s, st, all_names)
    ctx.check(ni > 0 and io == ni, "bras relies : prise et depot entre un tapis et un batiment a niveaux (tous)",
      io .. "/" .. ni .. (bad_i and (" ; premier fautif : " .. bad_i) or ""))
    local od, nd0, bad_d = check_drills(s, st)
    ctx.check(nd0 > 0 and od == nd0, "foreuses : depot sur un tapis (toutes)",
      od .. "/" .. nd0 .. (bad_d and (" ; premiere fautive : " .. bad_d) or ""))
    local wa, na = count_status(s, st, "assembling-machine")
    local wf, nf = count_status(s, st, "furnace")
    local wd, nd = count_status(s, st, "mining-drill")
    ctx.check(na > 0 and wa >= 0.8 * na, "assembleurs au travail (80 % au moins)", wa .. "/" .. na)
    ctx.check(nf > 0 and wf >= 0.8 * nf, "fours au travail (80 % au moins)", wf .. "/" .. nf)
    ctx.check(nd > 0 and wd >= 0.8 * nd, "foreuses au travail (80 % au moins : sortie directe sur un tapis)", wd .. "/" .. nd)
    local enemies = s.count_entities_filtered({ area = { { X0, Y0 }, { X0 + FW, Y0 + st.height } }, force = "enemy" })
    ctx.check(enemies == 0, "aucun ennemi dans l'usine", enemies)
    ctx.log(string.format("entites dans l'usine : %d", s.count_entities_filtered({ area = { { X0, Y0 }, { X0 + FW, Y0 + st.height } } })))
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    if not st.center then return end
    local s = ctx.surface()
    local c = st.center
    --- Chaque capture : son champ réel dans le journal (résolution des captures : 1600 × 900 par défaut, shots.lua).
    local function shot(name, x, y, zoom, daytime, opt)
      local res = opt.res or { 1600, 900 }
      ctx.log(field_line("capture", name, field(s, { x = x, y = y }, res[1], res[2], zoom)))
      add(name, x, y, zoom, daytime, opt)
    end
    for _, v in ipairs(TIMELINE) do
      if v.zoom then shot("usine-" .. v.name, c.x, c.y, v.zoom, v.daytime, { info = false }) end
    end
    shot("usine-z030-hd-jour", c.x, c.y, 0.3, 0, { info = false, res = { 1920, 1080 } })
    shot("usine-detail-z1-jour", st.detail.x, st.detail.y, 1, 0, { info = false })
    shot("usine-detail-z1-nuit", st.detail.x, st.detail.y, 1, 0.5, { info = false })
    shot("usine-detail-z2-jour", st.detail.x, st.detail.y, 2, 0, { info = false })
  end,
}
