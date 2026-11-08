--[[
  Lot MINAGE-MAIN : colle runtime (script/team/sources.lua) sur un moteur FACTICE (entités, surface, tableau et stock simulés ; les règles pures
  sont les vraies). Usage : lua5.2 tests/sources_glue_test.lua (depuis la racine du mod).
    §1 événements : pose d'un coffre puis d'un bras, ordre inverse, bras de retrait, retrait, mort, rotation, autre force
    §2 pensée E4 : 2 000 plaques dans une sortie de fonderie + manque de fer = minage libre retiré, tournée « fetch » posée
    §3 minage déjà pris barré ; cause écrite quand rien ne fournit ; tournée en pause ; crise injectée
    §4 objets attendus (view.incoming) ; stock qui refuse ; réceptacles d'avant-poste et coffre d'équipe écartés
    §5 acte de la tournée (sac, coffre, vide) ; §6 reprise d'une sauvegarde par tranches ; sorties déclarées du plan directeur
    §7 déterminisme (deux rejeux identiques)
]]
package.path = "./?.lua;" .. package.path

local logs = {}
log = function(m) logs[#logs + 1] = m end
defines = {
  inventory = { chest = 1 },
  events = {
    on_built_entity = 1, on_robot_built_entity = 2, script_raised_built = 3, script_raised_revive = 4, on_player_mined_entity = 5,
    on_robot_mined_entity = 6, script_raised_destroy = 7, on_player_rotated_entity = 8,
  },
}
game = { tick = 0 }

local handlers, died = {}, {}
package.preload["script.core.events"] = function()
  return {
    on = function(id, fn) handlers[id] = handlers[id] or {}; table.insert(handlers[id], fn) end,
    on_died = function(fn, interet) died[#died + 1] = { fn = fn, interet = interet } end,
    on_configuration_changed = function() end,
  }
end
local pteam
package.preload["script.core.storage"] = function() return { ns = function() return { team = pteam } end } end
package.preload["script.faction.state"] = function()
  local St = {}
  function St.by_force() return nil end
  function St.sorted_keys(t) local ks = {} for k in pairs(t or {}) do ks[#ks + 1] = k end table.sort(ks) return ks end
  return St
end
package.preload["script.team.board"] = function()
  local B = {}
  function B.get(f) f.team.board = f.team.board or { tasks = {}, cooldown = {} } return f.team.board end
  function B.drop_free(f, keep)
    local b = B.get(f)
    local keys = {}
    for k in pairs(b.tasks) do keys[#keys + 1] = k end
    table.sort(keys)
    local n = 0
    for _, k in ipairs(keys) do
      local t = b.tasks[k]
      if not t.worker and not keep(t) then b.tasks[k] = nil; n = n + 1 end
    end
    return n
  end
  function B.add(f, tasks, tick)
    local b = B.get(f)
    for _, t in ipairs(tasks) do
      local cd = b.cooldown[t.key]
      if not b.tasks[t.key] and not (cd and tick < cd) then b.tasks[t.key] = t end
    end
  end
  return B
end
local STOCK = { counts = {}, room = nil, skip = nil, annexes = {} }
package.preload["script.team.stock"] = function()
  return {
    annexes = function() return STOCK.annexes end,
    count = function(_, item) return STOCK.counts[item] or 0 end,
    room = function() return STOCK.room end,
    skip_fn = function() return STOCK.skip end,
  }
end
local LOSS = {}
package.preload["script.team.poles"] = function()
  return { DANGER_RADIUS = 40, near_loss = function(_, pos) return LOSS[math.floor(pos.x)] == true end }
end

local T = require("shared.team.config")
local Src = require("script.team.sources")
local PLATE, ORE = T.outposts.iron.product, T.outposts.iron.resource

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

---------------------------------------------------------------------------------------------------
-- Moteur factice
---------------------------------------------------------------------------------------------------
local WORLD
local next_uid
local function new_world()
  WORLD = { ents = {}, enemy_near = {} }
  next_uid = 100
  return WORLD
end

local surface = {}
function surface.find_entities_filtered(a)
  local out = {}
  local types = {}
  if type(a.type) == "table" then for _, t in ipairs(a.type) do types[t] = true end elseif a.type then types[a.type] = true end
  for _, e in ipairs(WORLD.ents) do
    if e.valid and (next(types) == nil or types[e.type]) and (not a.force or e.force.name == (type(a.force) == "table" and a.force.name or a.force)) then
      local ok = true
      if a.area then
        local p = e.position
        ok = p.x >= a.area[1][1] and p.x <= a.area[2][1] and p.y >= a.area[1][2] and p.y <= a.area[2][2]
      end
      if ok then out[#out + 1] = e end
    end
  end
  return out
end
function surface.count_entities_filtered(a)
  if a.force == "enemy" then
    local p = a.position
    return WORLD.enemy_near[math.floor(p.x)] and 1 or 0
  end
  return 0
end
function surface.find_entity(name, pos)
  for _, e in ipairs(WORLD.ents) do
    if e.valid and e.name == name and e.position.x == pos[1] and e.position.y == pos[2] then return e end
  end
  return nil
end

local function inventory(items)
  local inv = { items = items }
  function inv.get_contents() local c = {} for k, v in pairs(items) do if v > 0 then c[k] = v end end return c end
  function inv.get_item_count(name) return items[name] or 0 end
  function inv.remove(s) local n = math.min(s.count, items[s.name] or 0); items[s.name] = (items[s.name] or 0) - n return n end
  function inv.insert(s) items[s.name] = (items[s.name] or 0) + s.count return s.count end
  function inv.can_insert() return true end
  return inv
end

local function chest(x, y, items, force)
  local e = { valid = true, unit_number = next_uid, type = "container", name = "iron-chest", position = { x = x, y = y },
    force = { name = force or "player" }, surface = surface }
  next_uid = next_uid + 1
  e.inv = inventory(items or {})
  function e.get_inventory() return e.inv end
  WORLD.ents[#WORLD.ents + 1] = e
  return e
end

local function arm(x, y, drop, pick, force)
  local e = { valid = true, unit_number = next_uid, type = "inserter", name = "inserter", position = { x = x, y = y },
    force = { name = force or "player" }, surface = surface, drop_target = drop, pickup_target = pick }
  next_uid = next_uid + 1
  WORLD.ents[#WORLD.ents + 1] = e
  return e
end

local function fire(id, e)
  for _, fn in ipairs(handlers[id] or {}) do fn(e) end
end

local function team()
  return {
    key = "player", id = "player", force = "player", is_player = true, started = 0, hq_pos = { x = 0, y = 0 }, outposts = {}, stats = {},
    hq = { valid = true, unit_number = 1, surface = surface, position = { x = 0, y = 0 }, name = "fo-team-chest" },
    team = { collected = 0 },
  }
end

local function mine_task(res, key) return { key = key or ("mine:" .. res), kind = "mine", prio = 45, resource = res, count = 50, short = 400 } end

local function say_count(pattern)
  local n = 0
  for _, m in ipairs(logs) do if m:find(pattern) then n = n + 1 end end
  return n
end

---------------------------------------------------------------------------------------------------
-- §1 événements
---------------------------------------------------------------------------------------------------
new_world()
local f = team()
pteam = f
local c1 = chest(60, 0, { [PLATE] = 2000 })
fire(defines.events.on_built_entity, { created_entity = c1 })
check(f.team.sources and f.team.sources.chests[c1.unit_number], "un coffre posé entre au registre")
check(#Src.list(f, "sortie") == 0, "sans bras : neutre, pas une sortie")
local a1 = arm(61, 0, c1, nil)
fire(defines.events.on_built_entity, { created_entity = a1 })
check(#Src.list(f, "sortie") == 1 and Src.list(f)[1].uid == c1.unit_number, "un bras y dépose : sortie")
local a2 = arm(59, 0, nil, c1)
fire(defines.events.on_robot_built_entity, { created_entity = a2 })
check(#Src.list(f, "sortie") == 0, "un bras en retire : relais, plus une sortie")
fire(defines.events.on_player_mined_entity, { entity = a2 })
check(#Src.list(f, "sortie") == 1, "le bras de retrait est ramassé : sortie de nouveau")
-- ordre inverse : le bras d'abord (son coffre n'est pas encore au registre), le coffre ensuite
local c2 = chest(80, 0, { [PLATE] = 500 })
local a3 = arm(81, 0, c2, nil)
fire(defines.events.on_built_entity, { created_entity = a3 })
check(#Src.list(f, "sortie") == 1, "bras posé avant son coffre inconnu : rien encore")
fire(defines.events.script_raised_built, { entity = c2 })
check(#Src.list(f, "sortie") == 2, "le coffre posé ensuite étudie les bras voisins : sortie")
-- bras dont la cible n'est pas encore résolue (drop_target nil) mais dont le point de dépôt tombe sur le coffre : le coffre est trouvé par la position
do
  local c5 = chest(120, 0, { [PLATE] = 50 })
  fire(defines.events.on_built_entity, { created_entity = c5 })
  local a5 = arm(121, 0, nil, nil)
  a5.drop_position = { x = 120.1, y = 0 }
  a5.pickup_position = { x = 122, y = 0 }
  fire(defines.events.on_built_entity, { created_entity = a5 })
  check(f.team.sources.chests[c5.unit_number].nf == 1, "drop_target nil : le coffre au point de dépôt est retrouvé (banc 14 h)")
  fire(defines.events.on_player_mined_entity, { entity = a5 })
  fire(defines.events.script_raised_destroy, { entity = c5 })
end
-- foreuse qui dépose dans un coffre
local c3 = chest(100, 0, { [ORE] = 40 })
local drill = { valid = true, unit_number = 9000, type = "mining-drill", name = "electric-mining-drill", position = { x = 101, y = 1 }, force = { name = "player" },
  surface = surface, drop_target = c3 }
WORLD.ents[#WORLD.ents + 1] = drill
fire(defines.events.on_built_entity, { created_entity = c3 })
check(#Src.list(f, "sortie") == 3, "une foreuse y dépose : sortie")
-- rotation du bras : il dépose ailleurs
a3.drop_target = nil
fire(defines.events.on_player_rotated_entity, { entity = a3 })
check(#Src.list(f, "sortie") == 2, "bras tourné vers le sol : le coffre n'est plus une sortie")
a3.drop_target = c2
fire(defines.events.on_player_rotated_entity, { entity = a3 })
check(#Src.list(f, "sortie") == 3, "bras retourné : sortie de nouveau")
-- destruction
c3.valid = false
fire(defines.events.script_raised_destroy, { entity = { valid = true, type = "container", unit_number = c3.unit_number, force = c3.force } })
check(#Src.list(f, "sortie") == 2, "coffre détruit : retiré")
local died_ok = false
for _, d in ipairs(died) do
  check(d.interet and d.interet.ennemi == false and #d.interet.types == 3, "abonné aux morts : trois types, jamais la force ennemie")
  d.fn({ entity = a3 })
  died_ok = true
end
check(died_ok and #Src.list(f, "sortie") == 1, "mort d'un bras : sa sortie n'en est plus une qu'un déposant de moins (c2 neutre)")
-- autre force : ignoré
local foreign = chest(200, 0, {}, "enemy")
fire(defines.events.on_built_entity, { created_entity = foreign })
check(f.team.sources.chests[foreign.unit_number] == nil, "un coffre d'une autre force n'entre pas au registre")
-- règle coupée
f.team.sources_regle = false
local c4 = chest(300, 0, {})
fire(defines.events.on_built_entity, { created_entity = c4 })
check(f.team.sources.chests[c4.unit_number] == nil, "règle coupée (banc témoin) : rien n'est enregistré")
f.team.sources_regle = nil

---------------------------------------------------------------------------------------------------
-- §2 pensée E4
---------------------------------------------------------------------------------------------------
new_world()
logs = {}
f = team()
pteam = f
STOCK = { counts = { [PLATE] = 0 }, room = nil, skip = nil, annexes = {} }
local fond = chest(60, 0, { [PLATE] = 2000 })
fire(defines.events.on_built_entity, { created_entity = fond })
fire(defines.events.on_built_entity, { created_entity = arm(61, 0, fond, nil) })
local b = require("script.team.board").get(f)
b.tasks["mine:" .. ORE] = mine_task(ORE)
b.tasks["mine:" .. T.outposts.copper.resource] = mine_task(T.outposts.copper.resource)
b.tasks["crise:mine:" .. ORE] = mine_task(ORE, "crise:mine:" .. ORE)
b.tasks["other"] = { key = "other", kind = "craft", prio = 50 }
game.tick = 3600
local dropped = Src.think(f, 3600)
check(dropped == 1 and b.tasks["mine:" .. ORE] == nil, "manque de fer et 2 000 plaques en sortie : le minage de fer LIBRE est retiré")
check(b.tasks["mine:" .. T.outposts.copper.resource] ~= nil, "le minage de cuivre reste : aucune sortie de cuivre")
check(b.tasks["crise:mine:" .. ORE] ~= nil and b.tasks["other"] ~= nil, "une crise injectée par un banc et une autre tâche restent")
local key = "src:fetch:" .. PLATE .. ":" .. fond.unit_number
local ft = b.tasks[key]
check(ft and ft.kind == "fetch" and ft.item == PLATE and ft.count == 2000 and ft.prio == 89 and ft.no_rush and ft.pos.x == 60, "tournée « fetch » vers la sortie : 2 000 plaques, priorité 89, sans ruée")
check(say_count("prendre a la sortie " .. fond.unit_number) == 1 and say_count("extraire a la main copper%-ore : aucune source %(aucune sortie%)") == 1,
  "journal : « prendre à la sortie X » pour le fer, « extraire à la main : aucune source (cause) » pour le cuivre")
Src.think(f, 3700)
check(say_count("prendre a la sortie") == 1, "pas de doublon de ligne pour la même décision")
-- la tournée est prise : une nouvelle pensée ne la double pas
ft.worker = 7
Src.think(f, 4000)
local n_fetch = 0
for k, t in pairs(b.tasks) do if t.kind == "fetch" then n_fetch = n_fetch + 1 end end
check(n_fetch == 1, "une seule tournée pour un objet")
ft.worker = nil
-- une sortie plus proche apparaît : la tournée libre est retargetée
local near = chest(20, 0, { [PLATE] = 300 })
fire(defines.events.on_built_entity, { created_entity = near })
fire(defines.events.on_built_entity, { created_entity = arm(21, 0, near, nil) })
Src.think(f, 4300)
local k2 = "src:fetch:" .. PLATE .. ":" .. near.unit_number
check(b.tasks[k2] and b.tasks[key] == nil, "sortie plus proche : la tournée libre vers l'ancienne est remplacée")
check(b.tasks[k2].count == 300, "elle prend ce que la plus proche tient")

---------------------------------------------------------------------------------------------------
-- §3 programme d'un minage déjà pris
---------------------------------------------------------------------------------------------------
local ok, why, text = Src.hand_ok(f, ORE, 4300, false)
check(ok == false and why == "fetch" and text:find("prendre a la sortie"), "minage de fer déjà pris : barré, sortie nommée")
ok, why = Src.hand_ok(f, T.outposts.copper.resource, 4300, false)
check(ok == true, "cuivre : la main passe (aucune sortie)")
ok, why = Src.hand_ok(f, "ressource-inconnue", 4300, false)
check(ok == true and why == "rien", "une ressource non suivie : jamais barrée")
ok = Src.hand_ok(f, ORE, 4300, true)
check(ok == true, "crise injectée : la main passe")
-- tournées en pause (échec) : la main reprend avec sa cause
b.cooldown[k2] = 99999
b.cooldown[key] = 99999
ok, why = Src.hand_ok(f, ORE, 4300, false)
check(ok == true and why == "tournee en pause apres un echec", "les deux sorties en pause : la main reprend, cause écrite")
b.cooldown[k2] = nil
ok = Src.hand_ok(f, ORE, 4300, false)
check(ok == false, "une seule en pause : l'autre sert")
b.cooldown[key] = nil
-- danger
WORLD.enemy_near[20] = true
WORLD.enemy_near[60] = true
ok, why = Src.hand_ok(f, ORE, 4300, false)
check(ok == true and why == "sortie dangereuse", "nid près des sorties : la main reprend, cause « sortie dangereuse »")
WORLD.enemy_near[20], WORLD.enemy_near[60] = nil, nil
LOSS[20] = true
ok = Src.hand_ok(f, ORE, 4300, false)
check(ok == false, "perte récente près d'une seule sortie : l'autre sert")
LOSS[20] = nil
-- sortie vidée
near.inv.items[PLATE] = 0
fond.inv.items[PLATE] = 5
for _, t in ipairs({ 4400, 7300, 11000 }) do Src.think(f, t) end
ok, why = Src.hand_ok(f, ORE, 11000, false)
check(ok == true and why == "sorties vides", "sorties vidées : la main reprend, cause « sorties vides »")
check(say_count("extraire a la main iron%-ore : aucune source %(sorties vides%)") >= 1, "journal : cause « sorties vides »")

---------------------------------------------------------------------------------------------------
-- §4 objets attendus
---------------------------------------------------------------------------------------------------
fond.inv.items[PLATE] = 2000
near.inv.items[PLATE] = 300
for _, t in ipairs({ 12000, 12300, 12600, 12900, 13200 }) do Src.think(f, t) end -- la relecture passe par les deux sorties
local inc = Src.incoming(f, { [PLATE] = 10 }, 13200)
check(inc[PLATE] == 2310, "view.incoming : plaques déjà attendues + celles des deux sorties : " .. tostring(inc[PLATE]))
STOCK.room = 800
inc = Src.incoming(f, {}, 13200)
check(inc[PLATE] == 800, "bornées par la place du coffre d'équipe : " .. tostring(inc[PLATE]))
STOCK.room = nil
STOCK.skip = function(item) return item == PLATE end
inc = Src.incoming(f, {}, 13200)
check(inc[PLATE] == nil, "le stock refuse la plaque (saturée) : rien d'attendu")
STOCK.skip = nil
-- le coffre d'équipe, une annexe et un réceptacle d'avant-poste ne sont jamais des sorties comptées
local annex = chest(5, 5, { [PLATE] = 999 })
fire(defines.events.on_built_entity, { created_entity = annex })
fire(defines.events.on_built_entity, { created_entity = arm(6, 5, annex, nil) })
STOCK.annexes = { annex }
local sink = chest(150, 0, { [PLATE] = 777 })
fire(defines.events.on_built_entity, { created_entity = sink })
fire(defines.events.on_built_entity, { created_entity = arm(151, 0, sink, nil) })
f.outposts[1] = { sinks = { sink } }
for _, t in ipairs({ 14000, 14300, 14600, 14900, 15200 }) do Src.think(f, t) end
inc = Src.incoming(f, {}, 15200)
check(inc[PLATE] == 2300, "annexe et réceptacle d'avant-poste écartés (déjà comptés ailleurs) : " .. tostring(inc[PLATE]))

---------------------------------------------------------------------------------------------------
-- §5 acte de la tournée
---------------------------------------------------------------------------------------------------
local agent
agent = { entity = { position = { x = 62, y = 1 }, get_main_inventory = function() return agent.inv end } }
agent.inv = inventory({})
local task = { kind = "fetch", item = PLATE, uid = fond.unit_number, count = 1500, pos = { x = 60, y = 0 } }
local steps = Src.program(f, task)
check(steps and steps[1][1] == "home" and steps[2][1] == "goto" and steps[3][1] == "act" and steps[3][2] == "fetch" and steps[4][1] == "home",
  "programme : home, goto, act fetch, home")
check(Src.program(f, { kind = "fetch" }) == nil, "tâche sans coffre : pas de programme")
check(Src.act(agent, f, task, surface, 8300) == true and agent.inv.items[PLATE] == 1500 and fond.inv.items[PLATE] == 500, "la tournée prend 1 500 plaques au coffre")
check(f.team.sources.fetched == 1500 and f.team.sources.trips == 1 and f.team.collected == 1500, "compteurs de la tournée")
task.count = 9999
check(Src.act(agent, f, task, surface, 8310) == true and fond.inv.items[PLATE] == 0, "reste du coffre pris (borné au contenu)")
check(Src.act(agent, f, task, surface, 8320) == false and say_count("tournee a vide") == 1, "coffre vide : la tournée échoue, ligne de journal")
agent.entity.position = { x = 500, y = 500 }
fond.inv.items[PLATE] = 100
check(Src.act(agent, f, task, surface, 8330) == false and fond.inv.items[PLATE] == 100, "PNJ loin du coffre (chemin refusé) : échec, rien pris")
do
  local other = chest(64, 0, { [PLATE] = 900 }, "scarlet")
  f.team.sources.chests[other.unit_number] = { ent = other, x = 64, y = 0, feed = {}, take = {}, nf = 1, nt = 0, n = {}, grew = {} }
  local before = other.inv.items[PLATE]
  check(Src.act(agent, f, { kind = "fetch", item = PLATE, uid = other.unit_number, count = 500 }, surface, 8335) == false and other.inv.items[PLATE] == before
    and f.team.sources.chests[other.unit_number] == nil, "propriété : un coffre d'une autre force n'est jamais vidé, même s'il s'est glissé au registre")
end
fond.valid = false
agent.entity.position = { x = 62, y = 1 }
check(Src.act(agent, f, task, surface, 8340) == false and f.team.sources.chests[fond.unit_number] == nil, "coffre disparu : échec et retiré du registre")

---------------------------------------------------------------------------------------------------
-- §6 reprise d'une sauvegarde par tranches, sorties déclarées du plan directeur
---------------------------------------------------------------------------------------------------
new_world()
logs = {}
f = team()
pteam = f
STOCK = { counts = {}, room = nil, skip = nil, annexes = {} }
local want = {}
for i = 1, 100 do
  local c = chest(10 * i, 0, { [PLATE] = 100 + i })
  if i % 2 == 0 then arm(10 * i + 1, 0, c, nil) end -- 50 sorties, 50 coffres neutres
end
f.build = { order = { 1 }, projects = { [1] = { outs = { { x = 10, y = 0 } } } } } -- le coffre 1 est une sortie DÉCLARÉE, sans bras
local thinks = 0
repeat
  thinks = thinks + 1
  Src.think(f, 300 * thinks)
until f.team.sources.scanned or thinks > 10
check(f.team.sources.scanned and thinks == 3, "100 coffres étudiés par tranches de 40 : 3 pensées (" .. thinks .. ")")
check(f.team.sources.nchests == 100, "tous les coffres au registre : " .. f.team.sources.nchests)
local sorties = Src.list(f, "sortie")
check(#sorties == 51, "50 sorties à bras + 1 déclarée : " .. #sorties)
check(say_count("reprise de la sauvegarde finie : 100 coffre%(s%) etudie%(s%), 51 sortie") == 1, "ligne de fin de reprise")
check(f.team.sources.chests[WORLD.ents[1].unit_number].decl == true, "sortie déclarée marquée")
-- seules les sorties relues portent un contenu (tranches de 12) : après 5 pensées, les 51 sorties ont été lues au moins une fois
for k = 1, 5 do Src.think(f, 3000 + 300 * k) end
local read = 0
for _, s in ipairs(Src.list(f, "sortie")) do if s.read then read = read + 1 end end
check(read == 51, "toutes les sorties relues au moins une fois en 8 pensées : " .. read)

---------------------------------------------------------------------------------------------------
-- §8 le stock couvre : du cuivre miné à la main avec des milliers de plaques au coffre (DC, 8/11), aucun coffre de sortie
---------------------------------------------------------------------------------------------------
do
  new_world()
  logs = {}
  local g = team()
  pteam = g
  local CU, CU_PLATE = T.outposts.copper.resource, T.outposts.copper.product
  STOCK = { counts = { [CU_PLATE] = 21096, [CU] = 0 }, room = nil, skip = nil, annexes = {} }
  local bb = require("script.team.board").get(g)
  bb.tasks["ia3:mine:" .. CU .. ":1"] = mine_task(CU, "ia3:mine:" .. CU .. ":1")
  bb.tasks["manque:mine:" .. CU .. ":3"] = mine_task(CU, "manque:mine:" .. CU .. ":3")
  bb.tasks["survie:mine:" .. CU .. ":1"] = mine_task(CU, "survie:mine:" .. CU .. ":1")
  bb.tasks["fond:mine:" .. ORE] = mine_task(ORE, "fond:mine:" .. ORE)
  bb.tasks["crise:mine:" .. CU] = mine_task(CU, "crise:mine:" .. CU)
  STOCK.counts[PLATE] = 100
  local dropped2 = Src.think(g, 3600)
  check(dropped2 == 3 and bb.tasks["fond:mine:" .. ORE] ~= nil and bb.tasks["crise:mine:" .. CU] ~= nil,
    "21 096 plaques de cuivre au stock : les minages de cuivre libres (cerveau, manque, survie) sont retirés, le fer (100 plaques) et la crise restent : " .. dropped2)
  local okc, whyc, textc = Src.hand_ok(g, CU, 3700, false, 50)
  check(okc == false and whyc == "stock" and textc:find("le stock suffit"), "un minage de cuivre déjà pris est barré : le stock suffit")
  check(Src.hand_ok(g, ORE, 3700, false, 50) == true, "fer : 100 plaques seulement, la main reste permise")
  check(Src.hand_ok(g, CU, 3700, true, 50) == true, "crise injectée : la main passe")
  STOCK.counts[CU_PLATE] = 0
  STOCK.counts[CU] = 120
  check(Src.hand_ok(g, CU, 3700, false, 50) == false and Src.hand_ok(g, CU, 3700, false, 70) == true, "minerai en coffre : couvre une fournée de 50 (120 >= 100), pas une de 70 (140)")
  local dc = g.team.sources.dec[CU]
  check(dc and dc.choix and dc.raison and dc.tick, "décision par ressource lisible : choix, raison (mot fixe), n, d, tick")
  check(g.team.sources.dec[ORE].choix == "main" and g.team.sources.dec[ORE].raison == "aucune_sortie", "fer : choix main, raison aucune_sortie")
  STOCK.counts[CU_PLATE] = 21096
  Src.think(g, 4000)
  check(g.team.sources.dec[CU].choix == "stock" and g.team.sources.dec[CU].raison == "stock_suffit", "cuivre : choix stock, raison stock_suffit")
  check(say_count("pas de minage a la main de copper%-ore : le stock suffit") == 1, "journal : le stock suffit")
end

---------------------------------------------------------------------------------------------------
-- §9 liste complète pour le graphe, débit, plaques en route
---------------------------------------------------------------------------------------------------
do
  new_world()
  logs = {}
  local g = team()
  pteam = g
  STOCK = { counts = {}, room = nil, skip = nil, annexes = {} }
  local so = chest(60, 0, { [PLATE] = 100 })
  fire(defines.events.on_built_entity, { created_entity = so })
  fire(defines.events.on_built_entity, { created_entity = arm(61, 0, so, nil) })
  local en = chest(-60, 0, { [PLATE] = 1000 })
  fire(defines.events.on_built_entity, { created_entity = en })
  fire(defines.events.on_built_entity, { created_entity = arm(-61, 0, nil, en) })
  local ne = chest(0, 80, {})
  fire(defines.events.on_built_entity, { created_entity = ne })
  so.surface = { name = "nauvis", find_entities_filtered = surface.find_entities_filtered }
  Src.think(g, 300)
  local all = Src.list(g)
  local kinds = {}
  for _, r in ipairs(all) do kinds[r.kind] = (kinds[r.kind] or 0) + 1 end
  check(#all == 3 and kinds.sortie == 1 and kinds.entree == 1 and kinds.neutre == 1, "liste complète : une sortie, une entrée, un neutre")
  check(all[1].feeders + all[1].takers + all[2].feeders + all[2].takers + all[3].feeders + all[3].takers == 2, "bras comptés par coffre")
  local row_so
  for _, r in ipairs(all) do if r.uid == so.unit_number then row_so = r end end
  check(row_so.surface == "nauvis" and row_so.rate == nil, "surface lue ; débit nil tant qu'un seul relevé existe")
  so.inv.items[PLATE] = 400
  en.inv.items[PLATE] = 700
  Src.think(g, 3900)
  all = Src.list(g)
  local rs, re
  for _, r in ipairs(all) do
    if r.uid == so.unit_number then rs = r end
    if r.uid == en.unit_number then re = r end
  end
  check(rs.rate and rs.rate[PLATE] and rs.rate[PLATE] > 0, "sortie : débit d'entrée mesuré (objets par minute)")
  check(re.rate and re.rate[PLATE] and re.rate[PLATE] > 0, "entrée : consommation mesurée (le contenu baisse)")
  check(#Src.list(g, "entree") == 1 and Src.list(g, "entree")[1].uid == en.unit_number, "filtre par genre")
  -- plaques en route : tournée prise, déjà vidée, pas encore au stock
  local bb = require("script.team.board").get(g)
  bb.tasks["src:fetch:x"] = { key = "src:fetch:x", kind = "fetch", worker = 3, got = 250, item = PLATE }
  so.inv.items[PLATE] = 0
  Src.think(g, 20000)
  local inc9 = Src.incoming(g, {}, 20000)
  check(inc9[PLATE] == 250, "plaques déjà prises et en route : attendues une seule fois : " .. tostring(inc9[PLATE]))
end

---------------------------------------------------------------------------------------------------
-- §10 PNJ libres sans rien à construire : la cause écrite
---------------------------------------------------------------------------------------------------
do
  new_world()
  logs = {}
  local g = team()
  pteam = g
  STOCK = { counts = {}, room = nil, skip = nil, annexes = {} }
  g.build = { order = { 7, 8 }, projects = { [7] = { state = "reserve", ents = { 1, 2, 3 }, missing = { { PLATE, 900 } } }, [8] = { state = "fini", ents = {} } } }
  local bb = require("script.team.board").get(g)
  bb.tasks["craft:x"] = { key = "craft:x", kind = "craft", prio = 50 }
  Src.think(g, 3600, 0)
  check(say_count("RIEN%-A%-FAIRE") == 0, "aucun PNJ libre : aucune ligne")
  Src.think(g, 3700, 4)
  check(say_count("%[FO%-RIEN%-A%-FAIRE%] player : 4 PNJ libre%(s%) : rien a construire : 1 projet%(s%) attendent de la matiere %(manque iron%-plate 900%)") == 1,
    "4 PNJ libres, un projet attend 900 plaques : cause écrite")
  check(g.team.sources.idle and g.team.sources.idle.code == "matiere", "mot fixe lisible : matiere")
  Src.think(g, 3800, 4)
  check(say_count("RIEN%-A%-FAIRE") == 1, "au plus une ligne par minute")
  Src.think(g, 3700 + 3600, 4)
  check(say_count("RIEN%-A%-FAIRE") == 2, "une minute plus tard : une nouvelle ligne")
end

---------------------------------------------------------------------------------------------------
-- §7 déterminisme
---------------------------------------------------------------------------------------------------
local function run()
  new_world()
  logs = {}
  local g = team()
  pteam = g
  STOCK = { counts = {}, room = nil, skip = nil, annexes = {} }
  for i = 1, 6 do
    local c = chest(15 * i, 0, { [PLATE] = 100 * i })
    arm(15 * i + 1, 0, c, nil)
    fire(defines.events.on_built_entity, { created_entity = c })
  end
  local bb = require("script.team.board").get(g)
  bb.tasks["mine:" .. ORE] = mine_task(ORE)
  for t = 1, 6 do Src.think(g, 300 * t) end
  local keys = {}
  for k in pairs(bb.tasks) do keys[#keys + 1] = k end
  table.sort(keys)
  return table.concat(keys, ";") .. "|" .. table.concat(logs, "\n")
end
local r1 = run()
local r2 = run()
check(r1 == r2, "deux rejeux identiques (tâches et journal)")
check(r1:find("fetch:" .. PLATE .. ":", 1, true) ~= nil, "le rejeu pose bien une tournée")

print(string.format("[SOURCES-GLUE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
