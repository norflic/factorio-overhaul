--[[
  Garantie de placement des monnaies d'époque (lot M0) : exécution en moteur. Règles et données :
  shared/content/guarantee.lua (pur) ; forme des sites : shared/content/world.lua (champ guarantee).

  Quand :
  - on_init : partie neuve (tick 0 : site toujours posé) ou mod ajouté à une partie (tick > 0 : gisements déjà
    connus comptés) ;
  - on_configuration_changed : sauvegarde d'une version sans garantie (ressources qui manquent seulement) ;
  - filet on_nth_tick(600) : si la configuration n'a pas été rejouée (mod mis à jour sans changement de version
    ni de prototypes), la garantie est posée au premier passage. Coût hors travail : une boucle sur 4 clés (3 avant le lot X1-TITANE).
  Une ressource RÉUSSIE n'est traitée qu'une fois par partie (global.fo.world.done[clé], ok vrai). Une ressource
  ÉCHOUÉE (aucun candidat valable) n'est PAS marquée traitée (correction M-1 de la vérification) :
  global.fo.world.fails[clé] compte les échecs, le filet la reprend après G.retry_delay (10 s, 20 s, 40 s... au
  plus 10 min de jeu), avec une autre suite de candidats et des critères assouplis par paliers (G.rules : eau du
  bord comblée au niveau 2, anneau allongé au niveau 3) ; chaque échec est annoncé aux joueurs (game.print) ;
  on_configuration_changed reprend tout échec sans attendre le délai.

  Le site : tuiles du biome (seulement sur un sol naturel de terre ferme : ni eau, ni dalle posée par un joueur),
  gisement ou puits, falaises du cœur retirées, décoratifs du biome régénérés, zone cartographiée pour la force
  « player » et marquée d'une étiquette de carte (icône de la ressource).

  Coût : une réussite par ressource et par partie (plus un passage par échec, espacés par G.retry_delay) ; génération forcée des chunks d'un candidat s'ils n'existent pas
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
  return { done = {}, fails = {}, sites = {}, tags = {}, runs = 0 }
end)

local function state()
  local fo = Storage.raw()
  if not fo.world then fo.world = { done = {}, fails = {}, sites = {}, tags = {}, runs = 0 } end
  if not fo.world.fails then fo.world.fails = {} end -- état d'avant la correction M-1 (développement du lot)
  return fo.world
end

---------------------------------------------------------------------------------------------------
-- Sol naturel de terre ferme : tuile placée par la génération de la carte (autoplace), sans couche d'eau.
-- Cache par nom, reconstruit à chaque chargement (aucune donnée dans global).
---------------------------------------------------------------------------------------------------
local land_cache = {}

local water_cache = {}

local function natural_land(name)
  local v = land_cache[name]
  if v == nil then
    local p = game.tile_prototypes[name]
    v = p ~= nil and p.autoplace_specification ~= nil and not (p.collision_mask and p.collision_mask["water-tile"]) or false
    land_cache[name] = v
  end
  return v
end

--- Eau naturelle (placée par la génération de la carte) : comblée par le sol du biome à partir du niveau 2.
local function natural_water(name)
  local v = water_cache[name]
  if v == nil then
    local p = game.tile_prototypes[name]
    v = p ~= nil and p.autoplace_specification ~= nil and (p.collision_mask and p.collision_mask["water-tile"]) and true or false
    water_cache[name] = v
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

--- Gisements déjà présents dans les chunks générés à moins de dmax du départ : quantité totale, nombre ; pour un champ
--- (X1-TITANE), aussi le nombre de puits de sa ressource fluide.
local function existing(surface, spec, spawn)
  local total, n = 0, 0
  for _, e in ipairs(surface.find_entities_filtered({ name = spec.resource, position = spawn, radius = spec.dmax })) do
    total = total + e.amount
    n = n + 1
  end
  local wells = nil
  if spec.field_wells then
    wells = surface.count_entities_filtered({ name = spec.field_wells.resource, position = spawn, radius = spec.dmax })
  end
  return total, n, wells
end

--- Motif de refus d'un candidat (nil : valable). rules : G.rules(essai).
local function reject_reason(surface, spec, c, placed, rules)
  if not G.far_enough(c.x, c.y, spec.site_radius, placed) then return "voisin" end
  local outer = G.square(c.x, c.y, spec.site_radius + math.ceil(G.EDGE_JITTER) + G.BUILD_MARGIN)
  ensure_generated(surface, outer)
  if surface.count_entities_filtered({ area = area_of(outer), force = { "enemy", "neutral" }, invert = true, limit = 1 }) > 0 then
    return "batiment"
  end
  local core = G.square(c.x, c.y, spec.core_radius + G.RESOURCE_MARGIN)
  if surface.count_entities_filtered({ area = area_of(core), type = "resource", limit = 1 }) > 0 then return "gisement" end
  local ground = G.square(c.x, c.y, spec.core_radius + 1)
  local land, water = 0, 0
  for _, t in ipairs(surface.find_tiles_filtered({ area = area_of(ground) })) do
    if natural_land(t.name) then
      land = land + 1
    elseif natural_water(t.name) and rules.fill_water then
      water = water + 1
    else
      return "sol" -- dalle d'un joueur, ou eau aux niveaux 0 et 1
    end
  end
  return G.ground_verdict(rules, land, water, 0)
end

--- Pose un site au centre c : tuiles, falaises, gisement ou puits, décoratifs. Renvoie { tiles, entities, total }.
local function place_site(surface, spec, c, map_seed, units, decor, fill_water)
  local L = G.layout(spec, c.x, c.y, map_seed, units)
  local core = G.square(c.x, c.y, spec.core_radius + 1)
  for _, cl in ipairs(surface.find_entities_filtered({ area = area_of(core), type = "cliff" })) do
    if cl.valid then cl.destroy({ do_cliff_correction = true }) end
  end
  local tiles = {}
  local filled = 0
  local rows, row_order = {}, {}
  for _, t in ipairs(L.tiles) do
    local name = surface.get_tile(t.x, t.y).name
    local wet = fill_water and natural_water(name)
    if wet then filled = filled + 1 end
    -- Sans biome (spec.tile nil, galène) : le sol naturel reste ; seule l'eau comblée prend spec.fill_tile ; toutes les
    -- tuiles de terre du disque comptent dans les lignes (décor et arbres retirés sur le gisement).
    local paint = spec.tile and name ~= spec.tile and (natural_land(name) or wet)
    local keep = (not spec.tile) and (natural_land(name) or wet)
    if paint or keep then
      if paint or wet then tiles[#tiles + 1] = { name = spec.tile or spec.fill_tile, position = { t.x, t.y } } end
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
  if decor and spec.tile then -- sans biome (galène) : le décor naturel reste autour du gisement
    for _, y in ipairs(row_order) do
      local r = rows[y]
      surface.destroy_decoratives({ area = { { r.x0, y }, { r.x1 + 1, y + 1 } } })
    end
  end
  -- Champ de cratères (X1-TITANE, spec.clear_trees) : arbres et rochers retirés du disque, ligne par ligne (régolithe
  -- stérile ; neutres, ils n'empêchent pas le site). Les sites d'avant (cendres, cristal, marais) gardent les leurs.
  if spec.clear_trees then
    for _, y in ipairs(row_order) do
      local r = rows[y]
      for _, e in ipairs(surface.find_entities_filtered({ area = { { r.x0, y }, { r.x1 + 1, y + 1 } }, type = { "tree", "simple-entity" } })) do
        if e.valid then e.destroy() end
      end
    end
  end
  -- Eau comblée (niveau >= 2) : les entités qui ne vivent que sur l'eau (poissons) sont retirées.
  surface.set_tiles(tiles, true, filled > 0)
  local made, total = 0, 0
  local list = spec.kind == "fluid" and L.wells or L.ore
  for _, o in ipairs(list) do
    local e = surface.create_entity({ name = o.name or spec.resource, position = { o.x + 0.5, o.y + 0.5 }, amount = o.amount })
    if e then
      made = made + 1
      total = total + o.amount
    end
  end
  -- Champ (X1-TITANE) : puits de la ressource fluide du champ, sur le même disque.
  local wells, well_total = 0, 0
  if spec.field_wells then
    for _, o in ipairs(L.wells) do
      local e = surface.create_entity({ name = o.name, position = { o.x + 0.5, o.y + 0.5 }, amount = o.amount })
      if e then
        wells = wells + 1
        well_total = well_total + o.amount
      end
    end
  end
  if decor and #spec.decoratives > 0 then
    local sq = G.square(c.x, c.y, spec.site_radius + math.ceil(G.EDGE_JITTER))
    surface.regenerate_decorative(spec.decoratives, chunks_of(sq))
  end
  return { tiles = #tiles, entities = made, total = total, filled = filled, wells = wells, well_total = well_total }
end

--- Garantie sur une surface. opts : keys (liste de clés, défaut toutes), check_natural (bool), decor (bool),
--- placed (sites déjà posés : { x, y, radius }, complété en place), attempts ({ [clé] = échecs passés }, défaut 0 :
--- suite de candidats et palier d'assouplissement, G.rules). Renvoie un rapport en données simples.
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
      local attempt = opts.attempts and opts.attempts[spec.key] or 0
      local rules = G.rules(attempt)
      local res = { key = spec.key, resource = spec.resource, count = spec.count, dmin = spec.dmin, dmax = spec.dmax,
        found_total = 0, found_entities = 0, found = 0, to_place = spec.count, sites = {}, rejected = {}, ok = true,
        attempt = attempt, level = rules.level, dmax_used = G.dmax(spec, attempt) }
      if opts.check_natural then
        res.found_total, res.found_entities, res.found_wells = existing(surface, spec, spawn)
        res.found = G.units_found(spec, res.found_total, res.found_entities, res.found_wells)
        res.to_place = G.units_to_place(spec, res.found)
      end
      local n_sites = G.sites_for(spec, res.to_place)
      local units_per_site = spec.kind == "fluid" and res.to_place or 1
      local cands = G.candidates(map_seed, spec, G.MAX_TRIES, attempt)
      local next_try = 1
      for _ = 1, n_sites do
        local chosen = nil
        while next_try <= #cands and not chosen do
          local c = { x = sx + cands[next_try].x, y = sy + cands[next_try].y }
          local why = reject_reason(surface, spec, c, placed, rules)
          if why then
            res.rejected[#res.rejected + 1] = next_try .. ":" .. why
          else
            chosen = { x = c.x, y = c.y, try = next_try }
          end
          next_try = next_try + 1
        end
        if chosen then
          local p = place_site(surface, spec, chosen, map_seed, units_per_site, opts.decor, rules.fill_water)
          placed[#placed + 1] = { x = chosen.x, y = chosen.y, radius = spec.site_radius }
          res.sites[#res.sites + 1] = { x = chosen.x, y = chosen.y, try = chosen.try,
            dist = math.floor(G.dist(chosen.x, chosen.y, spawn.x, spawn.y) * 10 + 0.5) / 10,
            tiles = p.tiles, entities = p.entities, total = p.total, units = units_per_site, filled = p.filled,
            wells = spec.field_wells and p.wells or nil, well_total = spec.field_wells and p.well_total or nil }
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
  if spec.kind == "fluid" then return "fluid", spec.icon or spec.resource end
  return "item", spec.icon or spec.resource
end

--- La ressource est-elle réussie ? (un état « ok = faux » d'avant la correction M-1 compte comme non traité)
local function succeeded(st, key)
  local d = st.done[key]
  return d ~= nil and d.ok ~= false
end

--- Clés à traiter : jamais réussies ; si `now` est donné (filet), seulement celles dont le délai de reprise est
--- écoulé.
local function pending_keys(st, now)
  local out = {}
  local fails = st.fails or {}
  for _, spec in ipairs(G.specs()) do
    if not succeeded(st, spec.key) then
      local f = fails[spec.key]
      if now == nil or f == nil or now >= f.next_tick then out[#out + 1] = spec.key end
    end
  end
  return out
end

--- Pose les garanties qui manquent sur nauvis ; `phase` : "init", "config", "filet" (journal et état).
local function run(phase)
  local st = state()
  local keys = pending_keys(st, phase == "filet" and game.tick or nil)
  if #keys == 0 then return end
  local surface = game.surfaces[SURFACE]
  if not surface then return end
  local force = game.forces.player
  local spawn = force.get_spawn_position(surface)
  local check_natural = not (phase == "init" and game.tick == 0)
  local prof = game.create_profiler()
  local attempts = {}
  for _, k in ipairs(keys) do
    local f = st.fails[k]
    attempts[k] = f and f.count or 0
  end
  local report = M.apply(surface, spawn, { keys = keys, check_natural = check_natural, decor = true, placed = st.sites, attempts = attempts })
  prof.stop()
  st.runs = st.runs + 1
  local parts = {}
  for _, res in ipairs(report.results) do
    local spec = G.spec(res.key)
    local itype, iname = icon_of(spec)
    local prev = st.fails[res.key]
    local retry = ""
    if res.ok then
      -- Réussite : marquée traitée ; l'historique des échecs éventuels est gardé (failures).
      st.done[res.key] = { phase = phase, tick = game.tick, ok = true, found = res.found, found_total = res.found_total,
        found_entities = res.found_entities, found_wells = res.found_wells, to_place = res.to_place, sites = res.sites, rejected = res.rejected,
        check_natural = check_natural, attempt = res.attempt, level = res.level, failures = prev and prev.history or nil }
      st.fails[res.key] = nil
    else
      -- Échec : NON marquée traitée (correction M-1). Un site éventuellement posé reste dans st.sites et compte à la
      -- reprise (gisements connus). Reprise par le filet après le délai, essai suivant (autres candidats, critères
      -- assouplis).
      st.done[res.key] = nil
      local count = (prev and prev.count or 0) + 1
      local delay = G.retry_delay(count)
      local history = prev and prev.history or {}
      history[#history + 1] = { phase = phase, tick = game.tick, attempt = res.attempt, level = res.level, rejected = res.rejected }
      st.fails[res.key] = { count = count, next_tick = game.tick + delay, history = history }
      retry = string.format(" ; reprise au tick %d (essai %d, niveau %d)", game.tick + delay, count, G.rules(count).level)
      game.print({ "fo-monde.site-echec", "[" .. itype .. "=" .. iname .. "]", count, math.floor(delay / 60) })
    end
    for _, s in ipairs(res.sites) do
      local r = spec.site_radius + 2
      force.chart(surface, { { s.x - r, s.y - r }, { s.x + r + 1, s.y + r + 1 } })
      local t = { x = s.x, y = s.y, icon_type = itype, icon_name = iname, cx = math.floor(s.x / 32), cy = math.floor(s.y / 32) }
      if not try_tag(t) then st.tags[#st.tags + 1] = t end
      game.print({ "fo-monde.site-pose", "[" .. itype .. "=" .. iname .. "]", string.format("[gps=%d,%d]", s.x, s.y), math.floor(s.dist) })
    end
    local where = {}
    for _, s in ipairs(res.sites) do
      where[#where + 1] = string.format("(%d, %d) a %.1f tuiles, candidat %d, %d entites, %d, eau comblee %d%s", s.x, s.y, s.dist, s.try,
        s.entities, s.total, s.filled or 0, s.wells and string.format(", puits du champ %d (%d)", s.wells, s.well_total or 0) or "")
    end
    parts[#parts + 1] = string.format("%s (essai %d, niveau %d) : trouve %d (%d entites, %d), a poser %d, %s%s%s%s", res.key, res.attempt,
      res.level, res.found, res.found_entities, res.found_total, res.to_place, #where > 0 and table.concat(where, " ; ") or "rien pose",
      #res.rejected > 0 and (" ; refus " .. table.concat(res.rejected, ",")) or "",
      res.ok and "" or " ; ECHEC : aucun candidat valable, joueurs prevenus", retry)
  end
  log({ "", TAG .. " garanties (" .. phase .. ", tick " .. game.tick .. ", graine " .. report.seed .. ", gisements connus comptes : "
    .. tostring(check_natural) .. ") : " .. table.concat(parts, " | ") .. " ; duree ", prof })
end

Events.on_init(function() run("init") end)
Events.on_configuration_changed(function() run("config") end)

Events.on_nth_tick(NET_PERIOD, function(e)
  local fo = Storage.raw()
  local st = fo and fo.world
  if st then
    -- Coût hors travail : une boucle sur 4 clés ; une ressource échouée n'est reprise qu'après son délai.
    local fails = st.fails or {}
    for _, spec in ipairs(G.specs()) do
      if not succeeded(st, spec.key) then
        local f = fails[spec.key]
        if f == nil or e.tick >= f.next_tick then
          run("filet")
          return
        end
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
--   status()                          -> { runs, done = { { key, phase, ... } }, fails = { { key, count, next_tick, history } },
--                                          tags_pending }
--   specs()                           -> spécifications (shared/content/guarantee.lua)
--   candidates(surface, key, n, k)    -> n premiers candidats de l'essai k (défaut 0) (positions absolues, départ de la
--                                        force player)
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
          found_entities = d.found_entities, found_wells = d.found_wells, to_place = d.to_place, sites = d.sites, rejected = d.rejected, check_natural = d.check_natural,
          attempt = d.attempt, level = d.level, failures = d.failures }
      end
    end
    local fails = {}
    for _, spec in ipairs(G.specs()) do
      local f = st.fails[spec.key]
      if f then fails[#fails + 1] = { key = spec.key, count = f.count, next_tick = f.next_tick, history = f.history } end
    end
    return { runs = st.runs, done = done, fails = fails, tags_pending = #st.tags }
  end,
  specs = function()
    return G.specs()
  end,
  candidates = function(surface_name, key, n, attempt)
    local surface = game.surfaces[surface_name]
    local spec = G.spec(key)
    if not (surface and spec) then return nil end
    local spawn = game.forces.player.get_spawn_position(surface)
    local out = {}
    for i, c in ipairs(G.candidates(surface.map_gen_settings.seed, spec, n or G.MAX_TRIES, attempt)) do
      out[i] = { x = math.floor(spawn.x) + c.x, y = math.floor(spawn.y) + c.y }
    end
    return out
  end,
  -- Banc seulement : oublie qu'une ressource a été traitée sur nauvis (les sites posés restent), pour rejouer le
  -- filet périodique en moteur réel. Renvoie vrai si la clé était connue.
  forget = function(key)
    local st = state()
    local known = st.done[key] ~= nil or st.fails[key] ~= nil
    st.done[key] = nil
    st.fails[key] = nil
    return known
  end,
  apply = function(surface_name, opts)
    local surface = game.surfaces[surface_name]
    if not surface then return nil end
    opts = opts or {}
    local prof = game.create_profiler()
    local report = M.apply(surface, game.forces.player.get_spawn_position(surface),
      { keys = opts.keys, check_natural = opts.check_natural, decor = opts.decor, attempts = opts.attempts })
    prof.stop()
    log({ "", TAG .. " banc apply sur " .. surface_name .. " (graine " .. report.seed .. ", gisements connus comptes : "
      .. tostring(opts.check_natural and true or false) .. ") : duree ", prof })
    return report
  end,
})

return M
