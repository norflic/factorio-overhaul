--[[
  Garantie de placement des monnaies d'époque (lot M0) : exécution en moteur. Règles et données :
  shared/content/guarantee.lua (pur) ; forme des sites : shared/content/world.lua (champ guarantee).

  Quand :
  - on_init : partie neuve (tick 0 : site toujours posé) ou mod ajouté à une partie (tick > 0 : gisements déjà
    connus comptés) ;
  - on_configuration_changed : sauvegarde d'une version sans garantie (ressources qui manquent seulement) ;
  - filet on_nth_tick(600) : si la configuration n'a pas été rejouée (mod mis à jour sans changement de version
    ni de prototypes), la garantie est posée au premier passage. Coût hors travail : une boucle sur 3 clés.
  Chaque ressource n'est traitée qu'UNE fois par partie (global.fo.world.done[clé]).

  Le site : tuiles du biome (seulement sur un sol naturel de terre ferme : ni eau, ni dalle posée par un joueur),
  gisement ou puits, falaises du cœur retirées, décoratifs du biome régénérés, zone cartographiée pour la force
  « player » et marquée d'une étiquette de carte (icône de la ressource).

  Coût : une fois par ressource et par partie ; génération forcée des chunks d'un candidat s'ils n'existent pas
  (3 × 3 chunks, environ 20 ms mesurés en moteur réel par la sonde M0). Aucun coût par tick hors du filet.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local G = require("shared.content.guarantee")

local M = {}

local SURFACE = "nauvis"
local NET_PERIOD = 600
local TAG = "[FO-MONDE]"

Storage.declare("world", function()
  return { done = {}, sites = {}, tags = {}, runs = 0 }
end)

local function state()
  local fo = Storage.raw()
  if not fo.world then fo.world = { done = {}, sites = {}, tags = {}, runs = 0 } end
  return fo.world
end

---------------------------------------------------------------------------------------------------
-- Sol naturel de terre ferme : tuile placée par la génération de la carte (autoplace), sans couche d'eau.
-- Cache par nom, reconstruit à chaque chargement (aucune donnée dans global).
---------------------------------------------------------------------------------------------------
local land_cache = {}

local function natural_land(name)
  local v = land_cache[name]
  if v == nil then
    local p = game.tile_prototypes[name]
    v = p ~= nil and p.autoplace_specification ~= nil and not (p.collision_mask and p.collision_mask["water-tile"]) or false
    land_cache[name] = v
  end
  return v
end

local function area_of(sq)
  return { { sq.x0, sq.y0 }, { sq.x1 + 1, sq.y1 + 1 } }
end

local function chunks_of(sq)
  local out = {}
  for cy = math.floor(sq.y0 / 32), math.floor(sq.y1 / 32) do
    for cx = math.floor(sq.x0 / 32), math.floor(sq.x1 / 32) do out[#out + 1] = { x = cx, y = cy } end
  end
  return out
end

--- Génère (de force) les chunks qui couvrent le carré s'il en manque. Renvoie le nombre de chunks manquants.
local function ensure_generated(surface, sq)
  local missing = 0
  for _, c in ipairs(chunks_of(sq)) do
    if not surface.is_chunk_generated(c) then missing = missing + 1 end
  end
  if missing > 0 then
    local cx, cy = (sq.x0 + sq.x1) / 2, (sq.y0 + sq.y1) / 2
    local r = math.ceil(math.max(sq.x1 - sq.x0, sq.y1 - sq.y0) / 64) + 1
    surface.request_to_generate_chunks({ cx, cy }, r)
    surface.force_generate_chunk_requests()
  end
  return missing
end

--- Gisements déjà présents dans les chunks générés à moins de dmax du départ : quantité totale, nombre.
local function existing(surface, spec, spawn)
  local total, n = 0, 0
  for _, e in ipairs(surface.find_entities_filtered({ name = spec.resource, position = spawn, radius = spec.dmax })) do
    total = total + e.amount
    n = n + 1
  end
  return total, n
end

--- Motif de refus d'un candidat (nil : valable).
local function reject_reason(surface, spec, c, placed)
  if not G.far_enough(c.x, c.y, spec.site_radius, placed) then return "voisin" end
  local outer = G.square(c.x, c.y, spec.site_radius + math.ceil(G.EDGE_JITTER) + G.BUILD_MARGIN)
  ensure_generated(surface, outer)
  if surface.count_entities_filtered({ area = area_of(outer), force = { "enemy", "neutral" }, invert = true, limit = 1 }) > 0 then
    return "batiment"
  end
  local core = G.square(c.x, c.y, spec.core_radius + G.RESOURCE_MARGIN)
  if surface.count_entities_filtered({ area = area_of(core), type = "resource", limit = 1 }) > 0 then return "gisement" end
  local ground = G.square(c.x, c.y, spec.core_radius + 1)
  for _, t in ipairs(surface.find_tiles_filtered({ area = area_of(ground) })) do
    if not natural_land(t.name) then return "sol" end
  end
  return nil
end

--- Pose un site au centre c : tuiles, falaises, gisement ou puits, décoratifs. Renvoie { tiles, entities, total }.
local function place_site(surface, spec, c, map_seed, units, decor)
  local L = G.layout(spec, c.x, c.y, map_seed, units)
  local core = G.square(c.x, c.y, spec.core_radius + 1)
  for _, cl in ipairs(surface.find_entities_filtered({ area = area_of(core), type = "cliff" })) do
    if cl.valid then cl.destroy({ do_cliff_correction = true }) end
  end
  local tiles = {}
  local rows, row_order = {}, {}
  for _, t in ipairs(L.tiles) do
    local name = surface.get_tile(t.x, t.y).name
    if name ~= spec.tile and natural_land(name) then
      tiles[#tiles + 1] = { name = spec.tile, position = { t.x, t.y } }
      local r = rows[t.y]
      if not r then
        r = { x0 = t.x, x1 = t.x }
        rows[t.y] = r
        row_order[#row_order + 1] = t.y
      end
      if t.x < r.x0 then r.x0 = t.x end
      if t.x > r.x1 then r.x1 = t.x end
    end
  end
  -- Décor vanilla (herbes, plantes) retiré du disque, ligne par ligne : capture du 23/10, 16:10 : les plantes
  -- vertes restaient posées sur les cendres et sur le minerai. Celui du biome est régénéré plus bas.
  if decor then
    for _, y in ipairs(row_order) do
      local r = rows[y]
      surface.destroy_decoratives({ area = { { r.x0, y }, { r.x1 + 1, y + 1 } } })
    end
  end
  surface.set_tiles(tiles, true, false)
  local made, total = 0, 0
  local list = spec.kind == "fluid" and L.wells or L.ore
  for _, o in ipairs(list) do
    local e = surface.create_entity({ name = spec.resource, position = { o.x + 0.5, o.y + 0.5 }, amount = o.amount })
    if e then
      made = made + 1
      total = total + o.amount
    end
  end
  if decor and #spec.decoratives > 0 then
    local sq = G.square(c.x, c.y, spec.site_radius + math.ceil(G.EDGE_JITTER))
    surface.regenerate_decorative(spec.decoratives, chunks_of(sq))
  end
  return { tiles = #tiles, entities = made, total = total }
end

--- Garantie sur une surface. opts : keys (liste de clés, défaut toutes), check_natural (bool), decor (bool),
--- placed (sites déjà posés : { x, y, radius }, complété en place). Renvoie un rapport en données simples.
function M.apply(surface, spawn, opts)
  opts = opts or {}
  local map_seed = surface.map_gen_settings.seed
  local placed = opts.placed or {}
  local wanted = nil
  if opts.keys then
    wanted = {}
    for _, k in ipairs(opts.keys) do wanted[k] = true end
  end
  local report = { seed = map_seed, spawn = { x = spawn.x, y = spawn.y }, results = {} }
  local sx, sy = math.floor(spawn.x), math.floor(spawn.y)
  for _, spec in ipairs(G.specs()) do
    if not wanted or wanted[spec.key] then
      local res = { key = spec.key, resource = spec.resource, count = spec.count, dmin = spec.dmin, dmax = spec.dmax,
        found_total = 0, found_entities = 0, found = 0, to_place = spec.count, sites = {}, rejected = {}, ok = true }
      if opts.check_natural then
        res.found_total, res.found_entities = existing(surface, spec, spawn)
        res.found = G.units_found(spec, res.found_total, res.found_entities)
        res.to_place = G.units_to_place(spec, res.found)
      end
      local n_sites = G.sites_for(spec, res.to_place)
      local units_per_site = spec.kind == "fluid" and res.to_place or 1
      local cands = G.candidates(map_seed, spec, G.MAX_TRIES)
      local next_try = 1
      for _ = 1, n_sites do
        local chosen = nil
        while next_try <= #cands and not chosen do
          local c = { x = sx + cands[next_try].x, y = sy + cands[next_try].y }
          local why = reject_reason(surface, spec, c, placed)
          if why then
            res.rejected[#res.rejected + 1] = next_try .. ":" .. why
          else
            chosen = { x = c.x, y = c.y, try = next_try }
          end
          next_try = next_try + 1
        end
        if chosen then
          local p = place_site(surface, spec, chosen, map_seed, units_per_site, opts.decor)
          placed[#placed + 1] = { x = chosen.x, y = chosen.y, radius = spec.site_radius }
          res.sites[#res.sites + 1] = { x = chosen.x, y = chosen.y, try = chosen.try,
            dist = math.floor(G.dist(chosen.x, chosen.y, spawn.x, spawn.y) * 10 + 0.5) / 10,
            tiles = p.tiles, entities = p.entities, total = p.total, units = units_per_site }
        else
          res.ok = false
        end
      end
      report.results[#report.results + 1] = res
    end
  end
  return report
end

---------------------------------------------------------------------------------------------------
-- Étiquettes de carte (force « player ») : posées dès que le chunk du site est cartographié.
---------------------------------------------------------------------------------------------------
local function try_tag(t)
  local surface = game.surfaces[SURFACE]
  local force = game.forces.player
  if not (surface and force) then return true end
  local tag = force.add_chart_tag(surface, { position = { t.x + 0.5, t.y + 0.5 }, icon = { type = t.icon_type, name = t.icon_name } })
  return tag ~= nil
end

local function icon_of(spec)
  if spec.kind == "fluid" then return "fluid", spec.resource end
  return "item", spec.resource
end

local function pending_keys(st)
  local out = {}
  for _, spec in ipairs(G.specs()) do
    if not st.done[spec.key] then out[#out + 1] = spec.key end
  end
  return out
end

--- Pose les garanties qui manquent sur nauvis ; `phase` : "init", "config", "filet" (journal et état).
local function run(phase)
  local st = state()
  local keys = pending_keys(st)
  if #keys == 0 then return end
  local surface = game.surfaces[SURFACE]
  if not surface then return end
  local force = game.forces.player
  local spawn = force.get_spawn_position(surface)
  local check_natural = not (phase == "init" and game.tick == 0)
  local prof = game.create_profiler()
  local report = M.apply(surface, spawn, { keys = keys, check_natural = check_natural, decor = true, placed = st.sites })
  prof.stop()
  st.runs = st.runs + 1
  local parts = {}
  for _, res in ipairs(report.results) do
    local spec = G.spec(res.key)
    st.done[res.key] = { phase = phase, tick = game.tick, ok = res.ok, found = res.found, found_total = res.found_total,
      found_entities = res.found_entities, to_place = res.to_place, sites = res.sites, rejected = res.rejected,
      check_natural = check_natural }
    local itype, iname = icon_of(spec)
    for _, s in ipairs(res.sites) do
      local r = spec.site_radius + 2
      force.chart(surface, { { s.x - r, s.y - r }, { s.x + r + 1, s.y + r + 1 } })
      local t = { x = s.x, y = s.y, icon_type = itype, icon_name = iname, cx = math.floor(s.x / 32), cy = math.floor(s.y / 32) }
      if not try_tag(t) then st.tags[#st.tags + 1] = t end
      game.print({ "fo-monde.site-pose", "[" .. itype .. "=" .. iname .. "]", string.format("[gps=%d,%d]", s.x, s.y), math.floor(s.dist) })
    end
    local where = {}
    for _, s in ipairs(res.sites) do where[#where + 1] = string.format("(%d, %d) a %.1f tuiles, essai %d, %d entites, %d", s.x, s.y, s.dist, s.try, s.entities, s.total) end
    parts[#parts + 1] = string.format("%s : trouve %d (%d entites, %d), a poser %d, %s%s%s", res.key, res.found, res.found_entities,
      res.found_total, res.to_place, #where > 0 and table.concat(where, " ; ") or "rien pose", #res.rejected > 0 and (" ; refus " .. table.concat(res.rejected, ",")) or "",
      res.ok and "" or " ; ECHEC : aucun candidat valable")
  end
  log({ "", TAG .. " garanties (" .. phase .. ", tick " .. game.tick .. ", graine " .. report.seed .. ", gisements connus comptes : "
    .. tostring(check_natural) .. ") : " .. table.concat(parts, " | ") .. " ; duree ", prof })
end

Events.on_init(function() run("init") end)
Events.on_configuration_changed(function() run("config") end)

Events.on_nth_tick(NET_PERIOD, function()
  local fo = Storage.raw()
  local st = fo and fo.world
  if st then
    for _, spec in ipairs(G.specs()) do
      if not st.done[spec.key] then
        run("filet")
        return
      end
    end
  else
    run("filet")
  end
end)

Events.on(defines.events.on_chunk_charted, function(e)
  local fo = Storage.raw()
  local st = fo and fo.world
  if not (st and #st.tags > 0) then return end
  local surface = game.surfaces[SURFACE]
  if not (surface and e.surface_index == surface.index and e.force and e.force.name == "player") then return end
  local keep = {}
  for _, t in ipairs(st.tags) do
    if not (t.cx == e.position.x and t.cy == e.position.y and try_tag(t)) then keep[#keep + 1] = t end
  end
  st.tags = keep
end)

---------------------------------------------------------------------------------------------------
-- Interface distante « fo-monde » (bancs en moteur réel) : données simples seulement.
--   status()                          -> { runs, done = { { key, phase, ... } }, tags_pending }
--   specs()                           -> spécifications (shared/content/guarantee.lua)
--   candidates(surface, key, n)       -> n premiers candidats (positions absolues, départ de la force player)
--   apply(surface, opts)              -> rapport de M.apply (surface de banc : rien n'est gardé ni cartographié)
--   forget(key)                       -> banc seulement : la ressource redevient « à traiter » (filet)
---------------------------------------------------------------------------------------------------
remote.add_interface("fo-monde", {
  status = function()
    local st = state()
    local done = {}
    for _, spec in ipairs(G.specs()) do
      local d = st.done[spec.key]
      if d then
        done[#done + 1] = { key = spec.key, phase = d.phase, tick = d.tick, ok = d.ok, found = d.found, found_total = d.found_total,
          found_entities = d.found_entities, to_place = d.to_place, sites = d.sites, rejected = d.rejected, check_natural = d.check_natural }
      end
    end
    return { runs = st.runs, done = done, tags_pending = #st.tags }
  end,
  specs = function()
    return G.specs()
  end,
  candidates = function(surface_name, key, n)
    local surface = game.surfaces[surface_name]
    local spec = G.spec(key)
    if not (surface and spec) then return nil end
    local spawn = game.forces.player.get_spawn_position(surface)
    local out = {}
    for i, c in ipairs(G.candidates(surface.map_gen_settings.seed, spec, n or G.MAX_TRIES)) do
      out[i] = { x = math.floor(spawn.x) + c.x, y = math.floor(spawn.y) + c.y }
    end
    return out
  end,
  -- Banc seulement : oublie qu'une ressource a été traitée sur nauvis (les sites posés restent), pour rejouer le
  -- filet périodique en moteur réel. Renvoie vrai si la clé était connue.
  forget = function(key)
    local st = state()
    local known = st.done[key] ~= nil
    st.done[key] = nil
    return known
  end,
  apply = function(surface_name, opts)
    local surface = game.surfaces[surface_name]
    if not surface then return nil end
    opts = opts or {}
    local prof = game.create_profiler()
    local report = M.apply(surface, game.forces.player.get_spawn_position(surface),
      { keys = opts.keys, check_natural = opts.check_natural, decor = opts.decor })
    prof.stop()
    log({ "", TAG .. " banc apply sur " .. surface_name .. " (graine " .. report.seed .. ", gisements connus comptes : "
      .. tostring(opts.check_natural and true or false) .. ") : duree ", prof })
    return report
  end,
})

return M
