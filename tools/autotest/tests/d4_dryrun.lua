--[[
  Essai à blanc (Lua 5.2, HORS JEU) du greffon fo-autotest/scenarios/d4-geant.lua avec le VRAI greffons.lua, le
  VRAI terrain.lua et la VRAIE config des niveaux, sur un moteur SIMULÉ minimal :
    - create_entity refuse un chevauchement (grille d'occupation par tuile, emprise tile_width × tile_height ;
      gisements et alimentation invisible sans collision), un prototype inconnu lève une erreur (comme le moteur) ;
    - recherche par zone : une entité est trouvée si sa BOÎTE touche la zone (boîtes proches des vanilla :
      tapis ±0,4, bras ±0,15, bâtiment n×n : ±(n/2 − 0,3)) ; filtres name et type (chaîne ou liste), force ;
    - pickup_position et drop_position des bras (vecteurs de base : prise {0, −1}, dépôt {0, 1,2} vers le nord ;
      bras long {0, −2} et {0, 2,2}) et des foreuses (dépôt {0, −1,85} du 3×3 vanilla, porté au côté du niveau par
      la VRAIE règle des points, shared/levels/points.lua : {−0,5, −(côté/2 + 0,35)} sur un côté pair), tournés
      selon la direction ;
    - emprise de chaque niveau : la VRAIE table de la config (L.footprint, lot D4m-GÉANT ; avant, le côté de base de
      la famille pour tous les niveaux, d'où un essai à blanc vert sur un banc rouge en moteur réel, F128) ;
    - orientation des tourelles : un simple champ (écrite et relue telle quelle ; la tenue sans cible est un fait du
      moteur réel, F123) ;
    - un joueur connecté (fenêtre 1920 × 1080), le LuaProfiler (600 ticks = 10 000 ms simulées) et log().
  LIMITES (dites, pas cachées) : le statut des machines vaut toujours « au travail » et insert() réussit
  toujours : les contrôles « au travail » ne sont PAS exercés ici. Les tailles des niveaux sont celles de la
  table de la config (pas celles des prototypes chargés, qui la suivent : prototypes/levels/common.lua). Ne prouve RIEN du moteur réel : la logique, la disposition, la
  géométrie des bras et des foreuses, le champ réel et le format du journal seulement.

  Usage : lua5.2 tools/autotest/tests/d4_dryrun.lua <racine du mod> <journal de sortie>
  Code de sortie 0 si tout va bien ; la dernière ligne est « BILAN essai a blanc : n OK, m ECHEC(S) ».
]]
local ROOT, OUT = arg[1], arg[2]
assert(ROOT and OUT, "usage : lua5.2 d4_dryrun.lua <racine du mod> <journal de sortie>")
local FO = ROOT .. "/tools/autotest/fo-autotest/"
package.path = FO .. "?.lua;" .. package.path
table.insert(package.searchers or package.loaders, 2, function(name)
  local rel = name:match("^__factorio%-overhaul__/(.+)$")
  if rel then
    local path = ROOT .. "/" .. rel .. ".lua"
    local f = io.open(path)
    if f then f:close(); return assert(loadfile(path)) end
  end
end)

local LV = dofile(ROOT .. "/shared/levels/config.lua")
local Points = dofile(ROOT .. "/shared/levels/points.lua")
local lines = {}
local tick_now = 0
local function ls(v)
  if type(v) ~= "table" then return tostring(v) end
  if v._profiler then return string.format("Duration: %.6fms", v.ms) end
  local parts = {}
  for i = 2, #v do parts[#parts + 1] = ls(v[i]) end
  return table.concat(parts)
end
function log(v)
  local t = 5 + tick_now / 60
  lines[#lines + 1] = string.format("%8.3f Script @__fo-autotest__/scenarios/d4-geant.lua:1: %s", t, ls(v))
end

defines = {
  direction = { north = 0, east = 2, south = 4, west = 6 },
  controllers = { spectator = 5, character = 1 },
  entity_status = { working = 1, no_power = 2 },
}

-- Prototypes : familles de la config (taille et type), vanilla utilisés par le greffon.
local PROTOS = {}
local function proto(name, type_, w, collide, half)
  PROTOS[name] = { name = name, type = type_, tile_width = w, tile_height = w, collide = collide ~= false,
    half = half or (w / 2 - 0.3) }
end
for _, f in ipairs(LV.families) do
  for n = 1, f.max do proto(LV.name(f, n), f.type, LV.footprint(f, n)) end
end
for _, b in ipairs({ "transport-belt", "fast-transport-belt", "express-transport-belt" }) do proto(b, "transport-belt", 1, true, 0.4) end
local VECTORS = { -- base/prototypes/entity/entities.lua (1.1.91)
  ["inserter"] = { -1, 1.2 }, ["fast-inserter"] = { -1, 1.2 }, ["stack-inserter"] = { -1, 1.2 },
  ["filter-inserter"] = { -1, 1.2 }, ["long-handed-inserter"] = { -2, 2.2 },
}
for name in pairs(VECTORS) do proto(name, "inserter", 1, true, 0.15) end
proto("iron-ore", "resource", 1, false, 0.4)
proto("fo-autotest-power-pole", "electric-pole", 1, false, 0.4)
proto("fo-autotest-power-source", "electric-energy-interface", 1, false, 0.4)
local DRILL_VECTOR = { 0, -1.85 } -- base/prototypes/entity/mining-drill.lua : vector_to_place_result = {0, -1.85}

--- Vecteur (x, y) écrit pour le nord, tourné selon la direction (sens horaire, y vers le bas).
local function rot2(x, y, dir)
  dir = dir or 0
  if dir == 0 then return x, y end
  if dir == 2 then return -y, x end
  if dir == 4 then return -x, -y end
  return y, -x
end

--- Vecteur (0, dy) vers le nord, tourné selon la direction (sens horaire, y vers le bas).
local function rot(dy, dir)
  dir = dir or 0
  if dir == 0 then return 0, dy end
  if dir == 2 then return -dy, 0 end
  if dir == 4 then return 0, -dy end
  return dy, 0
end

local occ, entities, cells = {}, {}, {}
local stats = { created = 0, refused_overlap = 0, by_type = {} }
local function tiles_of(p, pos)
  local w = p.tile_width
  local x0, y0 = math.floor(pos[1] - w / 2 + 0.01), math.floor(pos[2] - w / 2 + 0.01)
  local t = {}
  for x = x0, x0 + w - 1 do for y = y0, y0 + w - 1 do t[#t + 1] = x .. ":" .. y end end
  return t
end

local surface = { name = "nauvis", daytime = 0.2, freeze_daytime = false }
function surface.request_to_generate_chunks(pos, r) assert(pos and r) end
function surface.force_generate_chunk_requests() end
function surface.set_tiles(t) assert(#t > 0) end
function surface.destroy_decoratives(o) assert(o.area) end

local function one_of(v, want)
  if want == nil then return true end
  if type(want) == "string" then return v == want end
  for _, w in ipairs(want) do if v == w then return true end end
  return false
end
local function match(e, o)
  if not e.valid then return false end
  if o.area then
    local a, b = o.area[1], o.area[2]
    local ax0, ay0, ax1, ay1 = a[1] or a.x, a[2] or a.y, b[1] or b.x, b[2] or b.y
    if not (e.box[3] > ax0 and e.box[1] < ax1 and e.box[4] > ay0 and e.box[2] < ay1) then return false end
  end
  if not one_of(e.type, o.type) then return false end
  if not one_of(e.name, o.name) then return false end
  if o.force and e.force ~= o.force then return false end
  return true
end
--- Index spatial : une cellule par tuile couverte par la boîte de l'entité.
local function candidates(o)
  if not o.area then return entities end
  local a, b = o.area[1], o.area[2]
  local ax0, ay0, ax1, ay1 = a[1] or a.x, a[2] or a.y, b[1] or b.x, b[2] or b.y
  local seen, out = {}, {}
  for x = math.floor(ax0) - 1, math.floor(ax1) + 1 do
    for y = math.floor(ay0) - 1, math.floor(ay1) + 1 do
      local c = cells[x .. ":" .. y]
      if c then
        for _, e in ipairs(c) do
          if not seen[e] then seen[e] = true; out[#out + 1] = e end
        end
      end
    end
  end
  table.sort(out, function(p, q) return p.id < q.id end)
  return out
end
function surface.find_entities_filtered(o)
  local r = {}
  for _, e in ipairs(candidates(o)) do if match(e, o) then r[#r + 1] = e end end
  return r
end
function surface.count_entities_filtered(o) return #surface.find_entities_filtered(o) end
function surface.create_entity(spec)
  local p = PROTOS[spec.name]
  if not p then error("Unknown entity name: " .. tostring(spec.name)) end
  local pos = spec.position
  local t = p.collide and tiles_of(p, pos) or {}
  for _, k in ipairs(t) do
    if occ[k] then
      stats.refused_overlap = stats.refused_overlap + 1
      if stats.refused_overlap <= 5 then print("CHEVAUCHEMENT", spec.name, pos[1], pos[2], "avec", occ[k]) end
      return nil
    end
  end
  for _, k in ipairs(t) do occ[k] = spec.name end
  local e = { id = #entities + 1, name = spec.name, type = p.type, position = { x = pos[1], y = pos[2] },
    force = spec.force or "neutral", valid = true, status = defines.entity_status.working, direction = spec.direction or 0 }
  e.box = { pos[1] - p.half, pos[2] - p.half, pos[1] + p.half, pos[2] + p.half }
  e.destroy = function() e.valid = false end
  e.set_recipe = function(r) assert(r == "automation-science-pack"); e.recipe = r end
  e.insert = function(it) assert(it.name and it.count); return it.count end
  e.get_transport_line = function(i)
    assert(i == 1 or i == 2)
    return { insert_at = function(position, items) assert(type(position) == "number" and items.name); return true end }
  end
  e.electric_buffer_size, e.power_production, e.energy = 0, 0, 0
  if p.type == "inserter" then
    local v = VECTORS[spec.name]
    local px, py = rot(v[1], e.direction)
    local dx, dy = rot(v[2], e.direction)
    e.pickup_position = { x = pos[1] + px, y = pos[2] + py }
    e.drop_position = { x = pos[1] + dx, y = pos[2] + dy }
  elseif p.type == "mining-drill" then
    local v = Points.move_point(DRILL_VECTOR, 3, p.tile_width)
    local dx, dy = rot2(v[1], v[2], e.direction)
    e.drop_position = { x = pos[1] + dx, y = pos[2] + dy }
  end
  for x = math.floor(e.box[1]), math.floor(e.box[3]) do
    for y = math.floor(e.box[2]), math.floor(e.box[4]) do
      local k = x .. ":" .. y
      cells[k] = cells[k] or {}
      table.insert(cells[k], e)
    end
  end
  entities[#entities + 1] = e
  stats.created = stats.created + 1
  stats.by_type[p.type] = (stats.by_type[p.type] or 0) + 1
  return e
end

local player = { name = "testeur", controller = 1, display_resolution = { width = 1920, height = 1080 } }
function player.set_controller(o) assert(o.type == defines.controllers.spectator); player.controller = o.type end
function player.teleport(pos) assert(pos.x and pos.y); player.position = pos; return true end
setmetatable(player, { __newindex = function(t, k, v) if k == "zoom" then rawset(t, "_zoom", v) else rawset(t, k, v) end end })

local connected = {}
game = {
  entity_prototypes = setmetatable({}, { __index = function(_, k) return PROTOS[k] end }),
  surfaces = { surface },
  connected_players = connected,
  map_settings = { enemy_expansion = { enabled = true }, pollution = { enabled = true } },
  forces = {
    player = { recipes = { ["steel-plate"] = { enabled = false } }, set_cease_fire = function() end },
    enemy = { set_cease_fire = function() end },
  },
  create_profiler = function()
    local p = { _profiler = true, t0 = tick_now, ms = 0 }
    p.stop = function() p.ms = (tick_now - p.t0) * 1000 / 60 end
    return p
  end,
}
remote = { interfaces = {}, call = function() error("remote.call inattendu") end }
global = {}

local ok, fail = 0, 0
local function expect(cond, what)
  if cond then ok = ok + 1 else fail = fail + 1; print("ECHEC essai a blanc : " .. what) end
end

local G = require("greffons")
local scen = G.load_scenario("d4-geant", {})
assert(scen, "greffon non charge : " .. tostring(G.missing))
G.scenario_init()
--- Copie des résultats après init : la carte sauvegardée après --create les contient (banc et session en repartent).
local function copy(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = copy(v) end
  return c
end
local after_init = copy(global.greffons.results)
print(string.format("pose : %d entites creees, %d chevauchements refuses", stats.created, stats.refused_overlap))
expect(stats.refused_overlap == 0, "aucun chevauchement")
local types = {}
for k in pairs(stats.by_type) do types[#types + 1] = k end
table.sort(types)
for _, k in ipairs(types) do print(string.format("  %-28s %6d", k, stats.by_type[k])) end
-- Banc sans images : 600 ticks sans joueur.
for t = 0, 600 do tick_now = t; G.scenario_tick({ tick = t }) end
local bilan_bench = lines[#lines]
-- Session avec images : nouvelle partie au tick 0 avec un joueur connecté (état du greffon remis comme au
-- chargement de la carte sauvegardée après --create : les résultats de init y sont déjà comptés, BILAN 17).
global.greffons.finished = nil
global.greffons.results = copy(after_init)
global.greffons.state["scenario:d4-geant"].cam = nil
connected[1] = player
for t = 0, 3500 do tick_now = t; G.scenario_tick({ tick = t }) end -- vues jusqu'au tick 3 420 (galerie des tetes)
local shots = {}
G.scenario_shots(function(name, x, y, zoom, daytime, opt) shots[#shots + 1] = string.format("%s (%.1f, %.1f) zoom %.2f jour %.2f%s",
  name, x, y, zoom, daytime, opt and opt.res and (" " .. opt.res[1] .. "x" .. opt.res[2]) or "") end)
print("captures : " .. #shots .. ", premiere apres " .. G.scenario_shot_delay() .. " ticks")
for _, s in ipairs(shots) do print("  " .. s) end
print("joueur : controleur " .. player.controller .. ", position finale " .. player.position.x .. "," .. player.position.y
  .. ", jour fige " .. tostring(surface.freeze_daytime))
local f = assert(io.open(OUT, "w"))
f:write("   0.000 2026-10-21 23:00:00; Factorio 1.1.91 (build 61680, win64, full)\n")
f:write("   0.300 Graphics options: [Graphics quality: normal] [Video memory usage: all] [DXT: high-quality] [Color: 32bit]\n")
for _, l in ipairs(lines) do f:write(l .. "\n") end
f:close()

local n_phase, n_champ, champ = 0, { reference = 0, vue = 0, capture = 0 }, {}
for _, l in ipairs(lines) do
  local body = l:sub(10)
  if l:find("BILAN") or l:find("ECHEC") or l:find("PHASE") or l:find("usine :") or l:find("OK ") or l:find("CHAMP") then
    print(body)
  end
  if l:find("PHASE fin", 1, true) then n_phase = n_phase + 1 end
  local kind, name, n, m = l:match("CHAMP (%S+) (%S+) .- batiments a niveaux (%d+) %(machines (%d+)")
  if kind then
    n_champ[kind] = (n_champ[kind] or 0) + 1
    champ[kind .. ":" .. name] = { n = tonumber(n), m = tonumber(m) }
  end
end
expect(bilan_bench and bilan_bench:find("BILAN : %d+ OK, 0 ECHEC") ~= nil, "BILAN du banc sans images sans echec : " .. tostring(bilan_bench))
expect(after_init.fail == 0, "aucun echec a la pose")
expect(global.greffons.results.fail == 0, "aucun echec au tick 120 de la session avec images")
expect(n_phase == 10, "10 phases chronometrees : 5 vues (dont z030-tetes) et 5 reperes (obtenu " .. n_phase .. ")")
expect(n_champ.reference == 10, "5 champs de reference (4 de l'usine, 1 de la galerie) x 2 (banc, session) (obtenu "
  .. n_champ.reference .. ")")
expect(n_champ.vue == 5, "un champ par vue mesuree (obtenu " .. n_champ.vue .. ")")
expect(n_champ.capture == #shots, "un champ par capture (obtenu " .. n_champ.capture .. " pour " .. #shots .. ")")
local hd = champ["reference:z030-hd"]
-- Seuils du greffon depuis le lot D4m-GÉANT (emprises de 0.4.3) : 900 bâtiments dont 550 machines, 58 % couverts.
expect(hd and hd.n >= 900 and hd.m >= 550, "champ z0,3 1920x1080 : au moins 900 batiments dont 550 machines")
local cover = nil
for _, l in ipairs(lines) do
  local c = l:match("CHAMP reference z030%-hd .- couverture %d+ tuiles %(([0-9.]+) %% du champ%)")
  if c then cover = tonumber(c) end
end
expect(cover and cover >= 58, "champ z0,3 1920x1080 : emprises sur 58 % du champ au moins (obtenu " .. tostring(cover) .. ")")
expect(bilan_bench and bilan_bench:find("BILAN : 18 OK, 0 ECHEC") ~= nil,
  "BILAN du banc : 18 OK (17 avant la galerie des tetes, 16 avant le lot D4m-GEANT)")
-- Galerie des têtes : la vue mesurée z030-tetes (fenêtre 1920 × 1080) dessine 64 poses de chacun des 15 âges ; le
-- champ z0,3 hd de l'usine n'en montre que 5 à 8 par âge (correction du lot D4m-GÉANT : le contrôle de 0a13534
-- comptait 64 valeurs de k sur l'usine entière, tous âges confondus).
local tv, tu
for _, l in ipairs(lines) do
  local n, a, lo, hi = l:match("TETES vue z030%-tetes 1920x1080 zoom 0%.30 : (%d+) tourelles entieres dans le champ, (%d+) ages, images par age (%d+) a (%d+)")
  if n then tv = { n = tonumber(n), a = tonumber(a), lo = tonumber(lo), hi = tonumber(hi) } end
  local un, ua, ulo, uhi = l:match("TETES reference usine%-z030%-hd 1920x1080 zoom 0%.30 : (%d+) tourelles entieres dans le champ, (%d+) ages, images par age (%d+) a (%d+)")
  if un then tu = { n = tonumber(un), a = tonumber(ua), lo = tonumber(ulo), hi = tonumber(uhi) } end
end
expect(tv and tv.n == 960 and tv.a == 15 and tv.lo == 64 and tv.hi == 64,
  "vue z030-tetes : 960 tourelles entieres, 15 ages, 64 images par age (obtenu " .. (tv and (tv.n .. ", " .. tv.a .. ", "
  .. tv.lo .. " a " .. tv.hi) or "rien") .. ")")
expect(tu and tu.lo < 64 and tu.hi < 64, "usine, champ z0,3 hd : moins de 64 images par age (obtenu "
  .. (tu and (tu.lo .. " a " .. tu.hi) or "rien") .. ")")
local vue = champ["vue:z030-jour"]
expect(vue and hd and vue.n == hd.n, "la vue mesuree z030-jour (fenetre 1920x1080) voit le champ de reference")
expect(#shots == 10, "10 captures (8 de l'usine, 2 de la galerie des tetes)")
print(string.format("BILAN essai a blanc : %d OK, %d ECHEC(S)", ok, fail))
os.exit(fail == 0 and 0 or 1)
