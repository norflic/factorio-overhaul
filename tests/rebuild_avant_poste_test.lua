--[[
  Lot REBUILD-AVANT-POSTE : test hors jeu (moteur simulé réduit) de la chaîne
    dernière foreuse détruite (Outposts.on_drill_lost) -> ruine (script/team/ruines.lua) -> pièces gardées au registre
    -> tâche « rebuild » -> pose de la première foreuse (Recon.act) -> avant-poste recréé (Ruines.recreate),
  des lâchers de ruine (expiration, champ refait ailleurs, site pris, rien au registre), de la patience (nids et vers), de la foreuse
  de remplacement (électrique perdue sans objet) et de l'exemption de pénalité de valeur du champ « à refaire en place ».
  Règles pures : shared/team/ruines.lua. Usage : lua5.2 tests/rebuild_avant_poste_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1 print("  ECHEC : " .. m) end end
local function read(path) local fh = assert(io.open(path, "rb")) local s = fh:read("*a") fh:close() return s end

local logs = {}
function log(s) logs[#logs + 1] = s end

local T = require("shared.team.config")
local Ru = require("shared.team.ruines")
local V = require("shared.faction.valeur")
local Rc = require("shared.team.reconstruction")

---------------------------------------------------------------------------------------------------
-- 1. Règle pure (la suite sert aussi aux mutants : chacun doit être refusé)
---------------------------------------------------------------------------------------------------
local function pure_suite(Ru)
  local ok, bad = 0, {}
  local function c(cond, m) if cond then ok = ok + 1 else bad[#bad + 1] = m end end
  local x = { x = 100, y = 100, kind = "iron", tick = 1000 }
  local function v(cx) cx.tick = cx.tick or 2000 return Ru.verdict(x, cx) end
  c(v({ pending = 3 }) == "garde", "ruine vivante : pièces à refaire, rien d'autre")
  local a, b = v({ pending = 3, record = true })
  c(a == "lache" and b == "refait", "l'enregistrement existe de nouveau : refait")
  a, b = v({ pending = 0 })
  c(a == "lache" and b == "pieces", "plus aucune pièce refaisable : lâchée")
  c(v({ pending = 1 }) == "garde", "une seule pièce suffit à garder la ruine")
  a, b = v({ pending = 3, tick = x.tick + Ru.TTL + 1 })
  c(a == "lache" and b == "expire", "plus de Ru.TTL sans retour : expirée")
  c(v({ pending = 3, tick = x.tick + Ru.TTL }) == "garde", "à Ru.TTL exactement : encore vivante")
  a, b = v({ pending = 3, live = { { kind = "iron", x = 110, y = 100 } } })
  c(a == "lache" and b == "remplace", "un avant-poste vivant de la même ressource à 10 tuiles : remplacée")
  c(v({ pending = 3, live = { { kind = "copper", x = 110, y = 100 } } }) == "garde", "une AUTRE ressource à 10 tuiles ne remplace pas")
  c(v({ pending = 3, live = { { kind = "iron", x = 100 + Ru.SUPERSEDE_R + 1, y = 100 } } }) == "garde", "même ressource mais ailleurs : ne remplace pas")
  c(v({ pending = 3, live = { { kind = "iron", x = 100 + Ru.SUPERSEDE_R, y = 100 } } }) == "lache", "à Ru.SUPERSEDE_R exactement : remplacée")
  a, b = v({ pending = 3, rival = true })
  c(a == "lache" and b == "rival", "site pris par une autre équipe : lâchée")
  c(Ru.TTL < 30 * 3600, "ruine plus courte que l'attente des réceptacles orphelins (30 min)")
  c(Ru.same_site({ x = 0, y = 0 }, { x = 8, y = 8 }) and not Ru.same_site({ x = 0, y = 0 }, { x = 13, y = 0 }), "même champ : 12 tuiles")
  c(Ru.same_site({ x = 0, y = 0 }, { x = 12, y = 0 }), "même champ : 12 tuiles incluses")

  -- Foreuse de remplacement : électrique 3x3 en (100.5, 100.5) vers le nord, four 2x2 en (100, 98)
  local sink = { x = 100, y = 98, w = 2, h = 2 }
  local burner = { size = 2, drop = T.drill_drop }
  local bx, by = Ru.burner_center(100.5, 100.5, 0, sink, burner, T.drill_electric.size)
  c(bx == 100 and by == 100, "foreuse à combustion : le dépôt tombe dans le même four, centre entier dans l'ancienne emprise")
  -- un four où le dépôt de la foreuse à combustion ne tombe pour aucun des quatre candidats
  c(Ru.burner_center(100.5, 100.5, 0, { x = 100, y = 90, w = 2, h = 2 }, burner, T.drill_electric.size) == nil, "réceptacle trop loin : aucune pose")
  -- une ancienne emprise trop petite pour contenir la foreuse à combustion décalée : aucun candidat
  c(Ru.burner_center(100.5, 100.5, 0, sink, burner, 2) == nil, "emprise d'origine trop petite : aucune pose")
  -- un four qui RECOUVRE les candidats : refusé
  c(Ru.burner_center(100.5, 100.5, 0, { x = 100, y = 100, w = 2, h = 2 }, burner, T.drill_electric.size) == nil, "réceptacle sous la foreuse : aucune pose")
  local found = Ru.sink_of(100.5, 100.5, 0, T.drill_electric.drop, { { x = 50, y = 50, w = 2, h = 2 }, sink })
  c(found == sink, "le réceptacle est celui qui contient le point de dépôt de l'électrique")
  c(Ru.sink_of(100.5, 100.5, 0, T.drill_electric.drop, { { x = 50, y = 50, w = 2, h = 2 } }) == nil, "aucun réceptacle sur le dépôt : nil")
  -- orientation sud (4) : le dépôt part vers le sud, le four est au sud
  local s_sink = { x = 101, y = 103, w = 2, h = 2 }
  c(Ru.sink_of(100.5, 100.5, 4, T.drill_electric.drop, { s_sink }) == s_sink, "orientation sud : le point de dépôt tourne avec la foreuse")
  c(Ru.sink_of(100.5, 100.5, 0, T.drill_electric.drop, { s_sink }) == nil, "orientation nord : le four du sud ne reçoit rien")
  local sx, sy = Ru.burner_center(100.5, 100.5, 4, s_sink, burner, T.drill_electric.size)
  c(sx ~= nil and math.abs(sx - 100.5) == 0.5 and math.abs(sy - 100.5) == 0.5, "orientation sud : centre dans l'ancienne emprise")
  return ok, bad
end

local ok0, bad0 = pure_suite(Ru)
pass = pass + ok0
for _, m in ipairs(bad0) do fail = fail + 1 print("  ECHEC : " .. m) end

-- Mutants de la règle : la suite doit tous les refuser
do
  local src = read("shared/team/ruines.lua")
  local MUT = {
    { "TTL : > devient >=", "c.tick - x.tick > Ru.TTL", "c.tick - x.tick >= Ru.TTL" },
    { "rival ignoré", "if c.rival then return \"lache\", \"rival\" end", "" },
    { "remplace : toute ressource", "if o.kind == x.kind then", "if true then" },
    { "remplace : rayon sans carré", "<= Ru.SUPERSEDE_R * Ru.SUPERSEDE_R", "<= Ru.SUPERSEDE_R" },
    { "remplace : rayon strict", "<= Ru.SUPERSEDE_R * Ru.SUPERSEDE_R", "< Ru.SUPERSEDE_R * Ru.SUPERSEDE_R" },
    { "enregistrement existant ignoré", "if c.record then return \"lache\", \"refait\" end", "" },
    { "sans pièce : gardée", "if (c.pending or 0) <= 0 then", "if (c.pending or 0) < 0 then" },
    { "même champ : rayon strict", "return dx * dx + dy * dy <= Ru.SAME_SITE_R * Ru.SAME_SITE_R", "return dx * dx + dy * dy < Ru.SAME_SITE_R * Ru.SAME_SITE_R" },
    { "dépôt non contrôlé", "if fits and S.inside(sink, bx + vx, by + vy) and not S.overlap(box, sink) then", "if fits and not S.overlap(box, sink) then" },
    { "recouvrement non contrôlé", "if fits and S.inside(sink, bx + vx, by + vy) and not S.overlap(box, sink) then", "if fits and S.inside(sink, bx + vx, by + vy) then" },
    { "emprise non contrôlée", "if fits and S.inside(sink, bx + vx, by + vy) and not S.overlap(box, sink) then", "if S.inside(sink, bx + vx, by + vy) and not S.overlap(box, sink) then" },
    { "dépôt sans rotation", "local vx, vy = S.rotate(dir, burner.drop[1], burner.drop[2])", "local vx, vy = burner.drop[1], burner.drop[2]" },
    { "réceptacle : rotation ignorée", "local vx, vy = S.rotate(dir, drop[1], drop[2])", "local vx, vy = drop[1], drop[2]" },
    { "TTL plus long que l'attente des orphelins", "Ru.TTL = 25 * 3600", "Ru.TTL = 40 * 3600" },
  }
  local refused = 0
  for _, mu in ipairs(MUT) do
    local at = src:find(mu[2], 1, true)
    if not at then
      fail = fail + 1 print("  ECHEC : mutant introuvable : " .. mu[1])
    else
      local mutated = src:sub(1, at - 1) .. mu[3] .. src:sub(at + #mu[2])
      local fn = load(mutated, "=ruines_mutant", "t")
      local okm, M = pcall(fn)
      local caught = not okm
      if okm then
        local okc, _, bad = pcall(pure_suite, M)
        caught = (not okc) or #bad > 0
      end
      if caught then refused = refused + 1 else fail = fail + 1 print("  ECHEC : mutant survivant : " .. mu[1]) end
    end
  end
  print(string.format("[REBUILD-AVANT-POSTE] mutants de la règle refusés : %d sur %d", refused, #MUT))
end

---------------------------------------------------------------------------------------------------
-- 2. Valeur : le champ « à refaire en place » n'est pas pénalisé, les autres le sont
---------------------------------------------------------------------------------------------------
do
  local ctx0 = { hq = { x = 0, y = 0 }, anchors = {}, rivals = {}, tick = 1000, ambition = 1000, prudence = 1000, appetite = 1000 }
  local function ctx_with(lost) local c = {} for k, v in pairs(ctx0) do c[k] = v end c.lost = lost return c end
  local site = { x = 100, y = 100, rich = 50000 }
  local clean = V.components(site, ctx_with({}))
  local lost = V.components(site, ctx_with({ { x = 100, y = 100, tick = 1000 } }))
  check(clean.danger == 0 and lost.danger == V.LOST, "site perdu à l'instant, sans drapeau : pénalité entière (comportement d'avant)")
  local kept = V.components(site, ctx_with({ { x = 100, y = 100, tick = 1000, keep = 5 } }))
  check(kept.danger == 0 and kept.value == clean.value, "site perdu « à refaire en place » : le champ lui-même n'est pas pénalisé")
  local near = V.components({ x = 130, y = 100, rich = 50000 }, ctx_with({ { x = 100, y = 100, tick = 1000, keep = 5 } }))
  check(near.danger > 0, "un AUTRE champ à 30 tuiles reste pénalisé (la perte compte pour ses voisins)")
  check(V.LOST_SAME_R == Ru.SAME_SITE_R, "même rayon dans la valeur et dans la règle de ruine")
end

---------------------------------------------------------------------------------------------------
-- 3. Exécutant : doublures
---------------------------------------------------------------------------------------------------
local handlers = {}
package.loaded["script.core.events"] = { on = function(id, fn) handlers[id] = fn end }
defines = { events = { on_entity_died = 1, on_player_mined_entity = 2, on_robot_mined_entity = 3 }, entity_status = { no_power = 7, working = 1 },
  direction = { north = 0, east = 2, south = 4, west = 6 }, inventory = setmetatable({}, { __index = function() return 1 end }),
  build_check_type = {}, flow_precision_index = {} }
local owners = {}
local war = { claims = {} }
local player
package.loaded["script.faction.state"] = {
  sorted_keys = function(t) local k = {} for key in next, t do k[#k + 1] = key end table.sort(k) return k end,
  owner = function(u) return owners[u] end,
  own = function(e, fid, kind, oid) owners[e.unit_number] = { f = fid, kind = kind, oid = oid } end,
  disown = function(u) owners[u] = nil end,
  faction = function(id) if id == "player" then return player end end,
  by_force = function() return nil end,
  alive = function() return {} end,
  war = function() return war end,
  site_key = function(pos) return math.floor(pos.x / 32) .. ":" .. math.floor(pos.y / 32) end,
}
local site_calls = { claim = 0, release = 0 }
package.loaded["script.faction.sites"] = {
  claim = function(f, pos) site_calls.claim = site_calls.claim + 1 site_calls.last = pos end,
  release = function() site_calls.release = site_calls.release + 1 end,
  room_for = function() return true end,
  note_lost = function(f, pos, tick, keep) -- même forme que script/faction/sites.lua (contrôlé en source plus bas)
    f.lost_sites = f.lost_sites or {}
    table.insert(f.lost_sites, { x = pos.x, y = pos.y, tick = tick, keep = keep })
  end,
}
package.loaded["script.ai3.places_qg"] = {}
local added = {}
package.loaded["script.team.board"] = {
  get = function(f) return f.team.board end,
  add = function(f, tasks)
    local n = 0
    for _, t in ipairs(tasks) do if not f.team.board.tasks[t.key] then f.team.board.tasks[t.key] = t; added[#added + 1] = t; n = n + 1 end end
    return n
  end,
}
package.loaded["script.team.stock"] = { count = function(f, item) return f.stock[item] or 0 end }
package.loaded["script.team.harvest"] = { names = function(item) return { item } end }
remote = { add_interface = function() end }

local DRILL, EDRILL, SINK = T.DRILL, T.DRILL_ELECTRIC, T.outposts.iron.sink
local PROTOS = {}
for _, n in ipairs({ DRILL, EDRILL, SINK }) do PROTOS[n] = { items_to_place_this = { { name = "item:" .. n } }, tile_width = 2, tile_height = 2 } end
PROTOS[EDRILL].tile_width, PROTOS[EDRILL].tile_height = 3, 3
game = { tick = 0, entity_prototypes = PROTOS }
local R = require("shared.ai3.reglages")
R.REBUILD_SWEEP = false
local Recon = require("script.team.reconstruction")
local Outposts = require("script.faction.outposts")
local Ruines = require("script.team.ruines")
local on_died = handlers[1]
check(on_died ~= nil, "l'exécutant s'abonne à on_entity_died")
--- Mort d'une entité : le moteur la rend invalide APRÈS l'événement (les gestionnaires la lisent encore).
local function died(e)
  on_died(e)
  if e.entity then e.entity.valid = false end
end

local unit = 1000
local function ent(name, ty, x, y, dir)
  unit = unit + 1
  return { valid = true, name = name, type = ty, unit_number = unit, position = { x = x, y = y }, direction = dir or 0, force = { name = "player" } }
end

local surface
local function new_surface()
  surface = { enemies = 0, foe = nil, placeable = true, created = {}, make_nil = false, sinks_world = {} }
  surface.find_enemy_units = function() local n = {} for i = 1, surface.enemies do n[i] = {} end return n end
  surface.find_nearest_enemy = function() return surface.foe end
  surface.find_entity = function() return nil end
  surface.find_entities = function() return {} end
  surface.find_entities_filtered = function(a)
    if a and a.name then return surface.sinks_world end
    return {}
  end
  surface.get_tile = function() return { name = "grass-1" } end
  surface.can_place_entity = function() return surface.placeable end
  surface.create_entity = function(spec)
    if surface.make_nil then return nil end
    local ty = (spec.name == SINK) and "furnace" or "mining-drill"
    local e = ent(spec.name, ty, spec.position.x, spec.position.y, spec.direction)
    surface.created[#surface.created + 1] = e
    return e
  end
  return surface
end

local function new_team()
  owners = {}
  added = {}
  war.claims = {}
  site_calls = { claim = 0, release = 0 }
  local f = { id = "player", key = "player", force = "player", is_player = true, started = 0,
    stats = { outposts_lost = 0, outposts_built = 0 }, hq = { valid = true, position = { x = 0, y = 0 }, unit_number = 1 },
    stock = { ["item:" .. DRILL] = 6, ["item:" .. EDRILL] = 0, ["item:" .. SINK] = 6 },
    outposts = {}, outposts_count = 0, turrets = {}, orphans = {}, prospects = {}, team = { board = { tasks = {} } } }
  player = f
  new_surface()
  return f
end

--- Avant-poste de fer en (100, 100) : deux foreuses à combustion, deux fours.
local function iron_outpost(f)
  local o = { id = 5, kind = "iron", pos = { x = 100, y = 100 }, drills = 2, drill_list = {}, sinks = {}, turret_list = {}, last_service = 0,
    site_info = { rich = 4000 } }
  f.outposts[5] = o
  f.outposts_count = 1
  local d1, d2 = ent(DRILL, "mining-drill", 98, 100), ent(DRILL, "mining-drill", 102, 100)
  local s1, s2 = ent(SINK, "furnace", 98, 98), ent(SINK, "furnace", 102, 98)
  for _, e in ipairs({ d1, d2 }) do owners[e.unit_number] = { f = "player", kind = "drill", oid = 5 } o.drill_list[#o.drill_list + 1] = e end
  for _, e in ipairs({ s1, s2 }) do owners[e.unit_number] = { f = "player", kind = "sink", oid = 5 } o.sinks[#o.sinks + 1] = e end
  return o, d1, d2, s1, s2
end

local function rebuild_task(f)
  local t
  for _, tk in pairs(f.team.board.tasks) do if tk.kind == "rebuild" and not tk.done then t = tk end end
  return t
end

--- Un tour de tâche : pensée, prise de la tâche, programme, pose. Rend la tâche et le nombre posé.
local function run_task(f, at, inv_items)
  Recon.think(f, surface, at)
  local t = rebuild_task(f)
  if not t then return nil, 0 end
  t.worker = 1
  Recon.program(f, t)
  local inv = { items = inv_items }
  inv.get_item_count = function(n) return inv.items[n] or 0 end
  inv.remove = function(sp) inv.items[sp.name] = (inv.items[sp.name] or 0) - sp.count end
  surface.created = {}
  Recon.act({ entity = { get_main_inventory = function() return inv end } }, f, t, surface)
  t.done = true
  return t, #surface.created
end

local function reset_board(f)
  f.team.board.tasks = {}
  for _, r in pairs(f.recon.lost) do r.claimed = nil end
end

---------------------------------------------------------------------------------------------------
-- 4. Perte totale : la ruine garde le plan, la première foreuse recrée l'avant-poste
---------------------------------------------------------------------------------------------------
do
  local f = new_team()
  local o, d1, d2, s1, s2 = iron_outpost(f)
  game.tick = 1000
  -- mort des deux foreuses et d'un four (s1) ; s2 survit (orphelin)
  died({ entity = d1, tick = 1000 })
  died({ entity = s1, tick = 1000 })
  died({ entity = d2, tick = 1001 })
  Outposts.on_drill_lost(f, 5) -- on_entity_destroyed de d1
  check(f.outposts[5] ~= nil and f.outposts[5].drills == 1, "première foreuse perdue : l'avant-poste vit encore")
  game.tick = 1001
  Outposts.on_drill_lost(f, 5) -- d2 : la dernière
  check(f.outposts[5] == nil and f.outposts_count == 0, "dernière foreuse perdue : l'enregistrement disparaît (comme avant)")
  local ru = f.recon and f.recon.ruins and f.recon.ruins[5]
  check(ru and ru.kind == "iron" and ru.x == 100 and ru.y == 100 and ru.site_info.rich == 4000 and ru.pieces == 3, "ruine : en-tête gardé (ressource, place, lectures du site, 3 pièces)")
  check(f.lost_sites and f.lost_sites[1].keep == 5, "site perdu marqué « à refaire en place » (lu par la valeur)")
  check(Ruines.keeps(f.recon, 5) and not Ruines.keeps(f.recon, 6), "Ruines.keeps : vrai pour la ruine, faux sinon")
  check(#f.orphans == 1 and f.orphans[1].e == s2, "le réceptacle survivant est un orphelin (comme le fait on_drill_lost)")

  -- une pensée après la patience : les pièces SONT gardées (avant : jetées, « avant-poste disparu »)
  Recon.think(f, surface, 1001 + Rc.CALM + 5)
  check(Rc.pending(f.recon) == 3, "pièces de l'avant-poste disparu GARDÉES au registre (2 foreuses + 1 four), plus jetées")
  check((f.recon.stats.discarded or 0) == 0, "aucune pièce jetée")
  local tk = rebuild_task(f)
  check(tk ~= nil and #tk.recs == 3, "une tâche « rebuild » pour le lot (3 pièces)")
  check(tk and tk.domain == "gisements", "tâche d'un champ de foreuses : domaine « gisements » (pôle extraction), pas « defense »")
  reset_board(f)

  -- la pose : le PNJ porte les objets
  local t, n = run_task(f, 1001 + Rc.CALM + 10, { ["item:" .. DRILL] = 2, ["item:" .. SINK] = 1 })
  check(t ~= nil and n == 3, "trois pièces posées")
  local o2 = f.outposts[5]
  check(o2 ~= nil and o2.kind == "iron" and o2.drills == 2 and #o2.drill_list == 2, "avant-poste RECRÉ au même numéro avec ses 2 foreuses")
  check(o2 and #o2.sinks == 2, "ses réceptacles : le four refait + le four resté sur place (repris des orphelins)")
  check(#f.orphans == 0, "le réceptacle orphelin est repris, plus démonté")
  check(f.outposts_count == 1, "compteur d'avant-postes remonté")
  check(site_calls.claim == 1 and site_calls.last.x == 100 and site_calls.last.resource == T.outposts.iron.resource, "site revendiqué de nouveau (ressource de l'avant-poste)")
  check(o2 and o2.pos.x == 100 and o2.site_info and o2.site_info.rich == 4000, "place et lectures du site conservées")
  check(Rc.pending(f.recon) == 0, "registre vidé")
  check(surface.created[1].type == "mining-drill" and surface.created[3].type == "furnace", "foreuses posées avant les réceptacles")
  -- le verdict suivant lâche la ruine (refaite) et le drapeau tombe
  Recon.think(f, surface, 1001 + Rc.CALM + 20)
  check(f.recon.ruins[5] == nil and f.lost_sites[1].keep == nil, "ruine lâchée (refaite) : drapeau tombé")
  check(f.recon.stats.revived == 1 and f.recon.stats.ruin_refait == 1 and f.stats.outposts_revived == 1, "compteurs : recréé 1 fois")
  local lg = false
  for _, l in ipairs(logs) do if l:find("FO-RUINE", 1, true) and l:find("recree", 1, true) then lg = true end end
  check(lg, "journal [FO-RUINE] : avant-poste recréé")
  -- perte partielle ensuite : le comportement d'avant (enregistrement vivant)
  died({ entity = o2.drill_list[1], tick = 5000 })
  Outposts.on_drill_lost(f, 5)
  check(f.outposts[5] ~= nil and f.outposts[5].drills == 1, "perte partielle d'un avant-poste recréé : il vit")
end

---------------------------------------------------------------------------------------------------
-- 5. Rien au registre : comportement d'avant (pénalité, rien gardé)
---------------------------------------------------------------------------------------------------
do
  local f = new_team()
  iron_outpost(f)
  Outposts.on_drill_lost(f, 5)
  Outposts.on_drill_lost(f, 5) -- foreuses retirées sans mort : aucune pièce au registre
  check(f.outposts[5] == nil and (f.recon == nil or f.recon.ruins == nil or next(f.recon.ruins) == nil), "aucune pièce au registre : pas de ruine")
  check(f.lost_sites and f.lost_sites[1].keep == nil, "site perdu sans drapeau : pénalité de valeur comme avant")
  check(#f.prospects == 1 and f.prospects[1].lost == true, "le gisement revient à la réserve (voie ordinaire)")
end

---------------------------------------------------------------------------------------------------
-- 6. Lâchers de ruine
---------------------------------------------------------------------------------------------------
local function ruined_team()
  local f = new_team()
  local _, d1, d2, _, s2 = iron_outpost(f)
  died({ entity = d1, tick = 1000 })
  died({ entity = d2, tick = 1000 })
  Outposts.on_drill_lost(f, 5)
  Outposts.on_drill_lost(f, 5)
  return f, s2
end
do
  -- expiration : pièces jetées, drapeau tombé
  local f = ruined_team()
  Recon.think(f, surface, 1000 + Ru.TTL + 10)
  check(f.recon.ruins[5] == nil and f.lost_sites[1].keep == nil, "expiration : ruine lâchée, drapeau tombé (la pénalité reprend)")
  Recon.think(f, surface, 1000 + Ru.TTL + 20)
  check(Rc.pending(f.recon) == 0 and f.recon.stats.discarded == 2, "expiration : les pièces sont jetées au tour suivant (règle d'avant)")
  check(f.recon.stats.ruin_expire == 1, "compteur d'expiration")
  -- champ refait par la voie ordinaire à 8 tuiles : remplacée, aucun doublon
  local g = ruined_team()
  g.outposts[9] = { id = 9, kind = "iron", pos = { x = 108, y = 100 }, drills = 3, drill_list = {}, sinks = {} }
  Recon.think(g, surface, 2000)
  check(g.recon.ruins[5] == nil and g.recon.stats.ruin_remplace == 1, "champ refait par un autre avant-poste : ruine remplacée")
  Recon.think(g, surface, 2010)
  check(Rc.pending(g.recon) == 0, "remplacée : les pièces ne sont pas posées en double")
  -- site pris par une autre équipe
  local h = ruined_team()
  war.claims["3:3"] = "autre"
  Recon.think(h, surface, 2000)
  check(h.recon.ruins[5] == nil and h.recon.stats.ruin_rival == 1, "site revendiqué par une autre équipe : ruine lâchée")
  war.claims = {}
  -- site pris au moment de poser : rien posé
  local k = ruined_team()
  Recon.think(k, surface, 1000 + Rc.CALM + 5)
  reset_board(k)
  Recon.think(k, surface, 1000 + Rc.CALM + 6)
  local tk = rebuild_task(k)
  war.claims["3:3"] = "autre" -- revendiqué entre la pensée et la pose
  tk.worker = 1
  Recon.program(k, tk)
  local inv = { items = { ["item:" .. DRILL] = 2, ["item:" .. SINK] = 1 } }
  inv.get_item_count = function(n) return inv.items[n] or 0 end
  inv.remove = function() end
  surface.created = {}
  Recon.act({ entity = { get_main_inventory = function() return inv end } }, k, tk, surface)
  check(k.outposts[5] == nil and #surface.created == 0, "site pris au moment de poser : aucune foreuse posée, aucun avant-poste recréé")
  war.claims = {}
  -- un réceptacle seul ne recrée pas l'avant-poste
  local m = ruined_team()
  local s = ent(SINK, "furnace", 98, 98)
  owners[s.unit_number] = { f = "player", kind = "sink", oid = 5 }
  died({ entity = s, tick = 1000 })
  m.team.board.tasks.autre = { key = "autre", kind = "craft", worker = 3 }
  for _, r in pairs(m.recon.lost) do if r.kind == "drill" then r.claimed = "autre" end end -- les foreuses sont prises par une autre tâche
  Recon.think(m, surface, 1000 + Rc.CALM + 5)
  local task = rebuild_task(m)
  check(task ~= nil and #task.recs == 1, "seul le réceptacle est dû")
  if task then
    task.worker = 1
    Recon.program(m, task)
    local inv2 = { items = { ["item:" .. SINK] = 1 } }
    inv2.get_item_count = function(n) return inv2.items[n] or 0 end
    inv2.remove = function() end
    surface.created = {}
    Recon.act({ entity = { get_main_inventory = function() return inv2 end } }, m, task, surface)
    check(#surface.created == 0 and m.outposts[5] == nil, "un réceptacle seul n'est pas posé et ne recrée aucun avant-poste")
  end
end

---------------------------------------------------------------------------------------------------
-- 6 bis. Réceptacles orphelins : jamais démontés tant que la ruine vit, démontables ensuite
---------------------------------------------------------------------------------------------------
do
  local f = ruined_team()
  check(#f.orphans == 2, "les deux fours sont orphelins après la perte")
  local late = 1000 + Outposts.ORPHAN_WAIT + 10
  check(#Outposts.orphan_groups(f, late) == 0, "ruine vivante : aucun groupe d'orphelins à démonter")
  Ruines.drop(f, f.recon, 5, "expire", late)
  check(#Outposts.orphan_groups(f, late) == 1, "ruine lâchée : les orphelins sont démontables (règle d'avant)")
end

---------------------------------------------------------------------------------------------------
-- 7. Pose refusée après coup : aucun avant-poste fantôme
---------------------------------------------------------------------------------------------------
do
  local f = ruined_team()
  surface.make_nil = true -- create_entity rend nil (F40 : un gestionnaire de raise_built détruit l'entité)
  run_task(f, 1000 + Rc.CALM + 10, { ["item:" .. DRILL] = 2, ["item:" .. SINK] = 1 })
  check(f.outposts[5] == nil and f.outposts_count == 0, "création échouée : l'enregistrement recréé est retiré (aucun avant-poste sans foreuse)")
  check(f.recon.ruins[5] ~= nil and f.recon.ruins[5].revived == nil, "la ruine reste vivante pour un nouvel essai")
  check(site_calls.release >= 1, "site relâché de nouveau")
  surface.make_nil = false
  reset_board(f)
  run_task(f, 1000 + Rc.CALM + 30, { ["item:" .. DRILL] = 2, ["item:" .. SINK] = 1 })
  check(f.outposts[5] ~= nil and f.outposts[5].drills == 2, "nouvel essai : avant-poste recréé")
end

---------------------------------------------------------------------------------------------------
-- 8. Patience : unités, nids et vers ; plafond de reports plus long pour une pièce d'avant-poste
---------------------------------------------------------------------------------------------------
do
  local f = ruined_team()
  surface.foe = { valid = true } -- un ver à portée
  Recon.think(f, surface, 1000 + Rc.CALM + 5)
  check(rebuild_task(f) == nil and f.recon.stats.deferred >= 1, "un nid ou un ver à portée : la pose est différée")
  -- 40 reports de 10 s : la pièce d'un avant-poste n'est pas abandonnée (plafond d'une pièce ordinaire : 20)
  local at = 1000 + Rc.CALM + 5
  for _ = 1, 40 do at = at + Rc.CALM + 10 Recon.think(f, surface, at) end
  local ab = 0
  for _, r in pairs(f.recon.lost) do if r.abandoned then ab = ab + 1 end end
  check(ab == 0 and Rc.pending(f.recon) == 2, "40 reports : les foreuses de l'avant-poste ne sont pas abandonnées")
  surface.foe = nil
  -- foreuse d'un avant-poste VIVANT : même patience longue
  local g = new_team()
  g.outposts[7] = { id = 7, kind = "iron", pos = { x = 0, y = 0 }, drills = 5, drill_list = {}, sinks = {} }
  local d = ent(DRILL, "mining-drill", 10, 10)
  owners[d.unit_number] = { f = "player", kind = "drill", oid = 7 }
  died({ entity = d, tick = 100 })
  local key = Rc.key({ name = DRILL, x = 10, y = 10 })
  surface.enemies = 3
  local at2 = 100 + Rc.CALM + 5
  for _ = 1, 25 do at2 = at2 + Rc.CALM + 10 Recon.think(g, surface, at2) end
  check(g.recon.lost[key] and g.recon.lost[key].abandoned == nil, "foreuse d'un avant-poste vivant : même patience longue (ressources d'abord)")
  surface.enemies = 0
  -- la règle pure garde l'ancien plafond par défaut
  local st = Rc.new()
  Rc.record(st, { name = "piece", x = 1, y = 1, item = "i", value = 1 }, 0)
  local kk = Rc.key({ name = "piece", x = 1, y = 1 })
  for i = 1, Rc.MAX_DEFERS + 1 do Rc.defer(st, kk, i, i) end
  check(st.lost[kk].abandoned == true, "Rc.defer sans plafond propre : l'ancien plafond (20)")
  local st2 = Rc.new()
  Rc.record(st2, { name = "piece", x = 1, y = 1, item = "i", value = 1 }, 0)
  for i = 1, Rc.MAX_DEFERS + 1 do Rc.defer(st2, kk, i, i, Ru.MAX_DEFERS) end
  check(st2.lost[kk].abandoned == nil, "Rc.defer avec plafond propre : la pièce attend")
  for i = 1, Ru.MAX_DEFERS do Rc.defer(st2, kk, i, i, Ru.MAX_DEFERS) end
  check(st2.lost[kk].abandoned == true, "…puis est abandonnée au-delà du plafond propre")
end

---------------------------------------------------------------------------------------------------
-- 9. Foreuse électrique perdue sans objet : foreuse à combustion à sa place, dépôt dans le même four
---------------------------------------------------------------------------------------------------
do
  local function lost_electric()
    local f = new_team()
    f.outposts[5] = { id = 5, kind = "iron", pos = { x = 100, y = 100 }, drills = 1, drill_list = {}, sinks = {}, turret_list = {}, site_info = {} }
    f.outposts_count = 1
    local ed = ent(EDRILL, "mining-drill", 100.5, 100.5)
    owners[ed.unit_number] = { f = "player", kind = "drill", oid = 5 }
    local sk = ent(SINK, "furnace", 100, 98)
    owners[sk.unit_number] = { f = "player", kind = "sink", oid = 5 }
    f.outposts[5].sinks[1] = sk
    surface.sinks_world = { sk } -- le four est resté sur place
    died({ entity = ed, tick = 1000 })
    Outposts.on_drill_lost(f, 5) -- dernière foreuse : ruine
    return f
  end
  local f = lost_electric()
  check(f.recon.ruins[5] ~= nil, "foreuse électrique perdue en dernier : ruine")
  local at = 1000 + Rc.CALM + 5
  Recon.think(f, surface, at)
  local r = f.recon.lost[Rc.key({ name = EDRILL, x = 100.5, y = 100.5 })]
  check(r and r.place == DRILL and r.item == "item:" .. DRILL and r.px == 100 and r.py == 100, "pas d'électrique au stock : foreuse à combustion à (100, 100), dépôt dans le four")
  check(f.recon.stats.drill_substituted == 1, "remplacement compté")
  reset_board(f)
  local _, n = run_task(f, at + 5, { ["item:" .. DRILL] = 1 })
  check(n == 1 and surface.created[1].name == DRILL and surface.created[1].position.x == 100 and surface.created[1].position.y == 100, "la foreuse à combustion est posée au centre calculé")
  check(f.outposts[5] and f.outposts[5].drills == 1 and #f.outposts[5].sinks == 1, "avant-poste recréé avec le four resté sur place")
  -- avec l'électrique au stock : l'électrique, pas de remplacement
  local g = lost_electric()
  g.stock["item:" .. EDRILL] = 1
  Recon.think(g, surface, at)
  local r2 = g.recon.lost[Rc.key({ name = EDRILL, x = 100.5, y = 100.5 })]
  check(r2 and r2.place == nil, "l'électrique est au stock : posée telle quelle")
  -- aucun four connu : pas de remplacement, la pièce attend son objet
  local h = lost_electric()
  surface.sinks_world = {}
  Recon.think(h, surface, at)
  local r3 = h.recon.lost[Rc.key({ name = EDRILL, x = 100.5, y = 100.5 })]
  check(r3 and r3.place == nil and r3.subst_fail == true, "réceptacle introuvable : pas de remplacement (essayé une fois)")
end

---------------------------------------------------------------------------------------------------
-- 10. Sources : câblage, ni pairs ni hasard, aucun nom du jeu
---------------------------------------------------------------------------------------------------
do
  local out = read("script/faction/outposts.lua")
  check(out:find("Ruines.on_total_loss(f, o, game.tick)", 1, true) and out:find("Sites.note_lost(f, o.pos, game.tick, keep and oid or nil)", 1, true),
    "Outposts.on_drill_lost appelle Ruines.on_total_loss puis Sites.note_lost avec le drapeau")
  local si = read("script/faction/sites.lua")
  check(si:find("function Sites.note_lost(f, pos, tick, keep)", 1, true) and si:find("keep = keep", 1, true), "Sites.note_lost range le drapeau")
  local rc = read("script/team/reconstruction.lua")
  check(rc:find("not Ruines.keeps(s, r.oid)", 1, true) and rc:find("Ruines.step(f, s, tick)", 1, true) and rc:find("Ruines.recreate(f, r.oid, game.tick)", 1, true),
    "Recon.think garde les pièces de la ruine, la fait juger, Recon.act la recrée")
  for _, file in ipairs({ "shared/team/ruines.lua", "script/team/ruines.lua", "script/team/reconstruction.lua" }) do
    local code = read(file):gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
    check(not code:find("[^i]pairs%(") and not code:find("math.random", 1, true), file .. " : ni pairs ni hasard")
    check(not code:find("global", 1, true), file .. " : pas de global")
    for _, nom in ipairs({ "iron%-plate", "gun%-turret", "stone%-furnace", "burner%-mining", "electric%-mining", "iron%-chest", "iron%-ore" }) do
      local hit = false
      for lit in code:gmatch('"([^"]*)"') do if lit:find(nom) then hit = true end end
      check(not hit, file .. " : aucun nom du jeu (" .. nom .. ")")
    end
  end
end

print(string.format("[REBUILD-AVANT-POSTE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
