--[[
  Lot ADOPTE : machines posées à la main par le joueur, adoptées par son équipe (shared/team/adopte.lua, règles pures ;
  script/team/adopte.lua avec un moteur simulé réduit à ce qu'il touche).
    - règle : motifs de refus dans l'ordre, rayon, ligne lue en dernier, machine rendue ;
    - exécution : un four isolé est inscrit à f.smelters, un four sur ligne non, plan et avant-postes exclus, réglage coupé,
      machine rendue quand un bras est posé à côté, migration triée, aucun appel de destruction, déterminisme ;
    - aucun nom d'objet du jeu dans la règle ni dans l'exécutant (les types viennent de shared/ai3/reglages.lua).
  Lancement : lua5.2 tests/adopte_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local A = require("shared.team.adopte")
local R = require("shared.ai3.reglages")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

---------------------------------------------------------------------------------------------------
section("Règle pure")
local base = { on = true, registry = "smelters", burner_needed = true, burner = true, dist2 = 400, linked = false }
local function with(over)
  local c = {}
  for k, v in pairs(base) do c[k] = v end
  for k, v in pairs(over) do c[k] = v end
  return c
end
do
  local ok, why = A.decide(base)
  check(ok and why == "ok", "four isolé à 20 tuiles : adopté")
  check(select(2, A.decide(with({ on = false }))) == "coupe", "réglage coupé")
  check(select(2, A.decide(with({ registry = false }))) == "role", "type sans registre")
  check(select(2, A.decide(with({ burner = false }))) == "combustible", "machine sans combustion refusée par un registre à combustion")
  check(A.decide(with({ burner = false, burner_needed = false })), "registre sans exigence de combustion")
  check(select(2, A.decide(with({ already = true }))) == "deja", "déjà inscrite")
  check(select(2, A.decide(with({ reserved = true }))) == "plan", "tuile du plan directeur")
  check(select(2, A.decide(with({ dist2 = (A.RADIUS + 1) ^ 2 }))) == "loin", "hors du rayon de service")
  check(A.decide(with({ dist2 = A.RADIUS ^ 2 })), "pile au rayon : adoptée")
  check(select(2, A.decide(with({ radius = 10, dist2 = 200 }))) == "loin", "rayon donné en config")
  check(select(2, A.decide(with({ linked = true }))) == "ligne", "bras, tapis ou foreuse alentour")
  -- priorité : coupe avant tout
  check(select(2, A.decide(with({ on = false, reserved = true, linked = true }))) == "coupe", "motifs dans l'ordre")
  -- la ligne n'est lue qu'en dernier (fonction appelée si tout le reste passe)
  local calls = 0
  A.decide(with({ linked = function() calls = calls + 1 return false end, reserved = true }))
  check(calls == 0, "voisinage non lu quand un autre motif refuse déjà")
  A.decide(with({ linked = function() calls = calls + 1 return false end }))
  check(calls == 1, "voisinage lu une fois quand le reste est acquis")
  local s = A.sorted({ { unit = 9 }, { unit = 2 }, { unit = 5 } })
  check(s[1].unit == 2 and s[2].unit == 5 and s[3].unit == 9, "tri par numéro d'unité")
  local box = A.search_box({ x = 10, y = 20 }, 1, 1)
  check(box[1][1] == 10 - 1 - A.CLEAR and box[2][2] == 20 + 1 + A.CLEAR, "boîte de recherche")
end

do
  check(not A.hold(0) and not A.hold(A.HOLD_AFTER - 1) and A.hold(A.HOLD_AFTER) and A.hold(9), "mise en attente après A.HOLD_AFTER échecs de suite")
  check(A.deploy(13, 2, 0, 15) == A.DEPLOY_PER_THINK, "13 fours libres : " .. A.DEPLOY_PER_THINK .. " posés par fenêtre")
  do
    local w, lo = A.window(nil, 0, 8)
    check(w and lo == nil, "fenêtre ouverte au premier appel")
    w, lo = A.window(w, 100, 3)
    w, lo = A.window(w, A.IDLE_WINDOW - 1, 9)
    check(lo == nil, "pas fermée avant A.IDLE_WINDOW")
    w, lo = A.window(w, A.IDLE_WINDOW, 9)
    check(lo == 3, "fermée : minimum observé (" .. tostring(lo) .. ")")
    check(w.t0 == A.IDLE_WINDOW and w.lo == 9, "rouverte à l'état courant")
  end
  check(A.deploy(3, 2, 0, 15) == 1, "3 libres : un de posé, " .. A.IDLE_KEEP .. " gardés")
  check(A.deploy(2, 2, 0, 15) == 0 and A.deploy(0, 0, 0, 15) == 0, "pas d'excédent : rien")
  check(A.deploy(13, 15, 0, 15) == 0 and A.deploy(13, 14, 0, 15) == 1, "plafond du registre")
  check(A.deploy(13, 10, 5, 15) == 0, "commande en cours comptée")
  check(A.deploy(nil, nil, nil, nil) == 0, "valeurs absentes : rien")
end

---------------------------------------------------------------------------------------------------
section("Exécution avec un moteur simulé")
local handlers, config_fns = {}, {}
package.loaded["script.core.events"] = {
  on = function(id, fn) handlers[id] = handlers[id] or {}; table.insert(handlers[id], fn) end,
  on_configuration_changed = function(fn) config_fns[#config_fns + 1] = fn end,
}
-- Lot UPS : le registre des machines (script/team/registre_types.lua) et le vrai stockage s abonnent au chargement (on_init, on_load,
-- on_configuration_changed) : tout abonnement absent du bouchon est sans effet.
setmetatable(package.loaded["script.core.events"], { __index = function() return function() end end })
local ns = { pteam = {} }
package.loaded["script.core.storage"] = { ns = function(n) ns[n] = ns[n] or {}; return ns[n] end,
  declare = function() end } -- lot UPS : registre_types.lua déclare son espace au chargement
local owners = {} -- lot PARITE : propriété des entités (State.own / owner / disown)
package.loaded["script.faction.state"] = {
  sorted_keys = function(t)
    local k = {}
    for key in pairs(t) do k[#k + 1] = key end
    table.sort(k)
    return k
  end,
  own = function(e, fid, kind, oid) owners[e.unit_number] = { f = fid, kind = kind, oid = oid } end,
  owner = function(u) return u and owners[u] or nil end,
  disown = function(u) owners[u] = nil end,
}
local Outposts = { reserved = nil }
package.loaded["script.faction.outposts"] = Outposts
defines = { events = { on_built_entity = 1, on_robot_built_entity = 2, on_player_mined_entity = 3, on_robot_mined_entity = 4 } }
local setting_value = true
settings = { global = setmetatable({}, { __index = function(_, k)
  if k == "fo-war-adopte" then return { value = setting_value } end
end }) }
local remotes = {}
remote = { add_interface = function(name, t) remotes[name] = t end }
local logs = {}
function log(s) logs[#logs + 1] = s end
game = { tick = 7200 }

-- Les types du moteur viennent de la config : jamais de nom d'objet ici.
local FURNACE_TYPE, DRILL_TYPE, INSERTER_TYPE = "furnace", "mining-drill", "inserter"
check(R.ADOPT[FURNACE_TYPE] and R.ENTITY_ROLE[FURNACE_TYPE] == "fabrique", "R.ADOPT : le four est un type adoptable")

local world = { entities = {} }
local next_unit = 100
local destroyed = 0
local function new_entity(ty, x, y, over)
  next_unit = next_unit + 1
  local e = { valid = true, type = ty, name = "e-" .. ty, unit_number = next_unit, force = { name = "player" }, position = { x = x, y = y },
    direction = 0, prototype = { tile_width = 2, tile_height = 2 }, burner = {}, surface = nil }
  e.destroy = function() destroyed = destroyed + 1 end
  e.mine = e.destroy
  for k, v in pairs(over or {}) do e[k] = v end
  if e.no_burner then e.burner = nil end
  e.surface = world.surface
  world.entities[#world.entities + 1] = e
  return e
end
world.surface = {
  count_entities_filtered = function(t)
    local n = 0
    local blockers = {}
    for _, ty in ipairs(t.type) do blockers[ty] = true end
    for _, e in ipairs(world.entities) do
      if e.valid and blockers[e.type] and e.position.x >= t.area[1][1] and e.position.x <= t.area[2][1]
        and e.position.y >= t.area[1][2] and e.position.y <= t.area[2][2] then
        n = n + 1
        if t.limit and n >= t.limit then break end
      end
    end
    return n
  end,
  find_entities_filtered = function(t)
    local want = {}
    for _, ty in ipairs(t.type) do want[ty] = true end
    local out = {}
    for _, e in ipairs(world.entities) do
      if e.valid and want[e.type] and (t.force == nil or e.force.name == t.force) then
        if t.area then -- lot PARITE : recherche par boîte (voisins d'une paire)
          if e.position.x >= t.area[1][1] and e.position.x <= t.area[2][1] and e.position.y >= t.area[1][2] and e.position.y <= t.area[2][2] then
            out[#out + 1] = e
          end
        else
          local dx, dy = e.position.x - t.position.x, e.position.y - t.position.y
          if dx * dx + dy * dy <= t.radius * t.radius then out[#out + 1] = e end
        end
      end
    end
    -- ordre volontairement inversé : l'exécutant doit trier
    table.sort(out, function(a, b) return a.unit_number > b.unit_number end)
    return out
  end,
}

-- Lot TUILES-RESERVEES : crochet unique des tuiles réservées (vrai script/ai3/places_qg.lua : Q.is_reserved lit Q.reserved)
local PQ = dofile("script/ai3/places_qg.lua")
package.loaded["script.ai3.places_qg"] = PQ
local Adopte = require("script.team.adopte")
check(handlers[1] and handlers[2] and #config_fns == 1 and remotes["fo-adopte"], "abonnements, migration et interface distante déclarés")

local function new_team()
  local hq = { valid = true, position = { x = 0, y = 0 }, surface = world.surface }
  local f = { id = "player", key = "player", force = "player", hq = hq, hq_pos = { x = 0, y = 0 }, smelters = {}, outposts = {}, started = 0, stats = {} }
  ns.pteam.team = f
  return f
end
local function build(e) for _, h in ipairs(handlers[1]) do h({ created_entity = e }) end end
local function count(f) return #f.smelters end

-- s40 : une machine adoptée ramassée sort de f.adopt.units et de la liste d'équipe
do
  local n0 = #world.entities
  local f = new_team()
  local a = new_entity(FURNACE_TYPE, 20, 0)
  local keep = new_entity(FURNACE_TYPE, -20, 0)
  build(a)
  build(keep)
  check(count(f) == 2 and f.adopt.units[a.unit_number], "s40 : deux fours adoptés")
  for _, h in ipairs(handlers[3]) do h({ entity = a }) end
  check(count(f) == 1 and f.smelters[1] == keep and f.adopt.units[a.unit_number] == nil and f.adopt.units[keep.unit_number],
    "s40 : four adopté ramassé : retiré de l'état et de la liste, l'autre reste")
  local stranger = new_entity(FURNACE_TYPE, 95, 0)
  for _, h in ipairs(handlers[3]) do h({ entity = stranger }) end
  check(count(f) == 1, "s40 : four non adopté ramassé : rien ne change")
  for i = #world.entities, n0 + 1, -1 do table.remove(world.entities, i) end -- le monde simulé est rendu tel quel aux sections suivantes
end

do
  local f = new_team()
  local a = new_entity(FURNACE_TYPE, 20, 0)
  build(a)
  check(count(f) == 1 and f.smelters[1] == a, "four isolé à 20 tuiles du coffre : inscrit à f.smelters")
  check(f.adopt.units[a.unit_number] and f.adopt.n == 1 and f.stats.adopted == 1, "état et compteur d'adoption")
  build(a)
  check(count(f) == 1, "pose répétée : pas de doublon")
  -- four loin
  local far = new_entity(FURNACE_TYPE, 90, 0)
  build(far)
  check(count(f) == 1 and f.adopt.refused[far.unit_number] == "loin", "four hors du rayon : refusé (loin)")
  -- four sur ligne : un bras à côté
  local b = new_entity(FURNACE_TYPE, 0, 20)
  new_entity(INSERTER_TYPE, 1.5, 20)
  build(b)
  check(count(f) == 1 and f.adopt.refused[b.unit_number] == "ligne", "four avec un bras alentour : non adopté (témoin ligne)")
  -- ligne posée APRÈS l'adoption : la machine est rendue
  local c = new_entity(FURNACE_TYPE, -20, 0)
  build(c)
  check(count(f) == 2, "autre four isolé adopté")
  local drill = new_entity(DRILL_TYPE, -21.5, 0)
  build(drill)
  check(count(f) == 1 and not f.adopt.units[c.unit_number] and f.adopt.refused[c.unit_number] == "ligne",
    "foreuse posée contre un four adopté : rendu au joueur")
  check(c.valid and destroyed == 0, "aucun bâtiment du joueur n'a été détruit")
  -- machine d'un autre type de registre : pas de registre
  local lab = new_entity("lab", 5, 5)
  build(lab)
  check(count(f) == 1, "type hors R.ADOPT : ignoré")
  -- sans combustion
  local el = new_entity(FURNACE_TYPE, 10, 10, { no_burner = true })
  build(el)
  check(count(f) == 1, "four sans combustion : non adopté")
  -- autre force
  local foe = new_entity(FURNACE_TYPE, 12, 12, { force = { name = "fo-scarlet" } })
  build(foe)
  check(count(f) == 1, "machine d'une autre force : ignorée")
  -- tuile du plan directeur
  PQ.reserved = function(_, _, pos) return pos.x == 30 end
  local plan = new_entity(FURNACE_TYPE, 30, 0)
  build(plan)
  check(count(f) == 1 and f.adopt.refused[plan.unit_number] == "plan", "tuile du plan directeur : refusée (plan)")
  PQ.reserved = nil
  -- réceptacle d'avant-poste
  local sink = new_entity(FURNACE_TYPE, 0, -25)
  f.outposts = { [1] = { sinks = { sink } } }
  build(sink)
  check(count(f) == 1, "réceptacle d'avant-poste : jamais adopté")
  f.outposts = {}
  -- réglage coupé
  setting_value = false
  local off = new_entity(FURNACE_TYPE, 0, 25)
  build(off)
  check(count(f) == 1, "réglage coupé : aucune adoption")
  local taken, given = Adopte.migrate(f)
  check(taken == 0 and given == 1 and count(f) == 0, "réglage coupé : la migration rend la machine adoptée")
  setting_value = true
end

do
  -- laboratoires et annexes
  world.entities = {}
  local f = new_team()
  f.team = {}
  local lab = new_entity("lab", 15, 0)
  build(lab)
  check(#f.smelters == 0 and f.adopt == nil or f.adopt.units[lab.unit_number] == nil, "laboratoire avant l'état du cerveau : pas encore adopté (la migration le reprendra)")
  f.team.ia3 = {}
  build(lab)
  check(f.team.ia3.labs and f.team.ia3.labs[1] == lab and f.adopt.units[lab.unit_number], "laboratoire isolé : inscrit à f.team.ia3.labs")
  local lab2 = new_entity("lab", -15, 5)
  new_entity(INSERTER_TYPE, -15, 7)
  build(lab2)
  check(#f.team.ia3.labs == 1 and f.adopt.refused[lab2.unit_number] == "ligne", "laboratoire en ligne (bras à côté) : non adopté")
  local TT = require("shared.team.config")
  local chest = new_entity("container", 6, 6, { name = TT.annex.kinds[1].item, prototype = { tile_width = 1, tile_height = 1 } })
  build(chest)
  check(f.annex and f.annex[1] == chest, "coffre du stock posé à 8 tuiles : inscrit aux annexes")
  local far = new_entity("container", 30, 0, { name = TT.annex.kinds[1].item, prototype = { tile_width = 1, tile_height = 1 } })
  build(far)
  check(#f.annex == 1 and f.adopt.refused[far.unit_number] == "loin", "coffre à 30 tuiles : reste au joueur (rayon des annexes)")
  local other = new_entity("container", 5, -5, { name = "un-autre-coffre", prototype = { tile_width = 1, tile_height = 1 } })
  build(other)
  check(#f.annex == 1, "coffre d'un autre prototype : jamais une annexe")
  -- un bras posé contre l'annexe adoptée la rend
  local ins = new_entity(INSERTER_TYPE, 6, 7.5)
  build(ins)
  check(#f.annex == 0 and not f.adopt.units[chest.unit_number], "bras posé contre une annexe : rendue")
  check(destroyed == 0, "aucune destruction")
end

do
  -- migration : machines déjà posées, triées par numéro d'unité, QG déjà servi non redoublé
  world.entities = {}
  local f = new_team()
  local qg = new_entity(FURNACE_TYPE, 8, -7)
  f.smelters[1] = qg
  local m1 = new_entity(FURNACE_TYPE, 25, 0)
  local m2 = new_entity(FURNACE_TYPE, -25, 0)
  local line = new_entity(FURNACE_TYPE, 0, 30)
  new_entity("transport-belt", 0, 31)
  local far = new_entity(FURNACE_TYPE, 100, 0)
  local taken, given = Adopte.migrate(f)
  check(taken == 2 and given == 0, "migration : 2 adoptées (" .. tostring(taken) .. ")")
  check(f.smelters[1] == qg and f.smelters[2] == m1 and f.smelters[3] == m2, "migration : ordre des numéros d'unité")
  check(f.adopt.refused[line.unit_number] == "ligne" and not f.adopt.units[far.unit_number], "migration : ligne refusée, four hors du rayon non étudié")
  local t2 = Adopte.migrate(f)
  check(t2 == 0 and count(f) == 3, "migration rejouée : idempotente")
  -- déterminisme : même monde, même résultat
  local keys1 = {}
  for _, e in ipairs(f.smelters) do keys1[#keys1 + 1] = e.unit_number end
  local g = new_team()
  g.smelters[1] = qg
  Adopte.migrate(g)
  local keys2 = {}
  for _, e in ipairs(g.smelters) do keys2[#keys2 + 1] = e.unit_number end
  check(table.concat(keys1, ",") == table.concat(keys2, ","), "déterminisme de la migration")
  -- un four ramassé par le joueur (invalide) n'est plus compté ni appelé
  m1.valid = false
  local still = 0
  for _, e in ipairs(f.smelters) do if e.valid then still = still + 1 end end
  check(still == 2, "four ramassé : invalide dans la liste (purgée par Outposts.smelters)")
  check(destroyed == 0, "migration : aucune destruction")
  check(logs[1] and logs[1]:find("%[FO%-ADOPTE%]"), "ligne de trace [FO-ADOPTE]")
  local st = remotes["fo-adopte"].status()
  check(st.n >= 2, "interface distante : état")
end

---------------------------------------------------------------------------------------------------
section("Lot PARITE : foreuse posée à la main, adoptée comme avant-poste de l'équipe")
do
  local TT = require("shared.team.config")
  local kind1 = TT.OUTPOST_ORDER[1]
  local res1 = TT.outposts[kind1].resource
  local function team_of_hand()
    world.entities = {}
    for k in pairs(owners) do owners[k] = nil end
    local f = new_team()
    f.next_oid, f.outposts_count = 0, 0
    return f
  end
  -- une foreuse (2x2) en (x, y) qui dépose sur sa réception (four) posée à 2 tuiles à l'est
  local function pair(x, y, over)
    local d = new_entity(DRILL_TYPE, x, y, { mining_target = { valid = true, name = res1 }, drop_position = { x = x + 2, y = y } })
    for k, v in pairs(over or {}) do d[k] = v end
    local s = new_entity(FURNACE_TYPE, x + 2, y)
    return d, s
  end
  local function put(d, s) build(d); build(s) end -- la foreuse d'abord (sans réception), la réception ensuite : le cas du DC dans l'autre sens
  local f = team_of_hand()
  local s = new_entity(FURNACE_TYPE, 22, 0)
  build(s) -- le four isolé est d'abord adopté seul...
  check(count(f) == 1, "four posé seul : adopté à f.smelters")
  local d = new_entity(DRILL_TYPE, 20, 0, { mining_target = { valid = true, name = res1 }, drop_position = { x = 22, y = 0 } })
  build(d) -- ... puis la foreuse arrive à son flanc : la PAIRE devient un avant-poste
  local o = f.outposts[1]
  check(o and o.adopted and o.kind == kind1 and o.drills == 1 and o.drill_list[1] == d and o.sinks[1] == s, "foreuse + four adoptés : avant-poste adopté de la ressource (kind " .. tostring(kind1) .. ")")
  check(f.outposts_count == 1 and o.full == true and o.full_by == "pose_paires", "avant-poste plein : l'équipe n'y pose pas de paire de plus")
  check(count(f) == 0 and not f.adopt.units[s.unit_number], "le four de la paire sort de la fonderie du QG (il sert la paire)")
  check(owners[d.unit_number] and owners[d.unit_number].kind == "drill" and owners[d.unit_number].oid == 1 and owners[s.unit_number].kind == "sink",
    "propriété enregistrée : foreuse (drill) et réception (sink), sinon aucune perte ne serait vue")
  check(f.adopt.drills[d.unit_number] and f.adopt.drills[d.unit_number].oid == 1 and remotes["fo-adopte"].status().drills == 1, "état et interface distante : 1 foreuse adoptée")
  build(d)
  check(o.drills == 1 and f.outposts_count == 1, "pose répétée : pas de doublon")
  -- une ligne arrive : un bras contre la réception ; la paire est rendue sans perte
  local ins = new_entity(INSERTER_TYPE, 22, 1.5)
  build(ins)
  check(f.outposts[1] == nil and f.outposts_count == 0 and f.adopt.refused[d.unit_number] == "ligne" and owners[d.unit_number] == nil,
    "bras contre la réception : paire rendue au joueur (avant-poste retiré, propriété retirée)")
  check(d.valid and s.valid and destroyed == 0, "aucun bâtiment du joueur n'est détruit ni déplacé")

  -- l'ordre inverse : foreuse d'abord (sans réception), réception ensuite
  f = team_of_hand()
  d = new_entity(DRILL_TYPE, -20, 0, { mining_target = { valid = true, name = res1 }, drop_position = { x = -18, y = 0 } })
  build(d)
  check(f.outposts[1] == nil and f.adopt.refused[d.unit_number] == "sans-reception", "foreuse sans réception : non adoptée (sans-reception)")
  s = new_entity(FURNACE_TYPE, -18, 0)
  build(s)
  check(f.outposts[1] and f.outposts[1].drills == 1, "réception posée ensuite : la foreuse voisine est étudiée et adoptée")

  -- deuxième paire proche : rejoint l'avant-poste (même ressource à moins de A.JOIN_RADIUS)
  local d2, s2 = pair(-30, 0)
  put(d2, s2)
  check(f.outposts[1].drills == 2 and f.outposts_count == 1 and #f.outposts[1].sinks == 2, "deuxième paire à 10 tuiles : rejoint le même avant-poste (2 foreuses)")
  local d3, s3 = pair(-30, 12)
  d3.mining_target = { valid = true, name = "autre-ressource-inconnue" }
  put(d3, s3)
  check(f.outposts[1].drills == 2 and not f.adopt.drills[d3.unit_number], "ressource inconnue de l'équipe sous la foreuse : non adoptée")
  -- le joueur ramasse la foreuse adoptée : ni perte, ni pénalité
  local lost0 = f.stats.outposts_lost or 0
  for _, h in ipairs(handlers[3]) do h({ entity = d2 }) end
  check(f.outposts[1].drills == 1 and (f.stats.outposts_lost or 0) == lost0 and owners[d2.unit_number] == nil and f.adopt.refused[d2.unit_number] == "ramassee",
    "foreuse ramassée par le joueur : sort de l'avant-poste sans compter comme une perte")

  -- refus : sans combustion, loin, ligne déjà là, tuile du plan, réglage coupé, autre force
  f = team_of_hand()
  local e1, es1 = pair(10, 10)
  e1.burner = nil
  put(e1, es1)
  check(f.outposts[1] == nil, "foreuse sans combustion : non adoptée (rien à ravitailler)")
  local l1, ls1 = pair(90, 0)
  put(l1, ls1)
  check(f.outposts[1] == nil and f.adopt.refused[l1.unit_number] == "loin", "foreuse hors du rayon de service : reste au joueur (loin)")
  local n1, ns1 = pair(0, 20)
  new_entity("transport-belt", 0, 22.5)
  put(n1, ns1)
  check(f.outposts[1] == nil and f.adopt.refused[n1.unit_number] == "ligne", "foreuse avec un tapis à son flanc : ligne du joueur (ligne)")
  PQ.reserved = function(_, _, pos) return pos.x == 30 end
  local p1, ps1 = pair(30, -10)
  put(p1, ps1)
  check(f.outposts[1] == nil and f.adopt.refused[p1.unit_number] == "plan", "tuile du plan directeur : refusée (plan)")
  PQ.reserved = nil
  setting_value = false
  local c1, cs1 = pair(-10, -20)
  put(c1, cs1)
  check(f.outposts[1] == nil, "réglage coupé : aucune adoption de foreuse")
  setting_value = true
  local o1, os1 = pair(15, -25)
  o1.force = { name = "fo-scarlet" }
  put(o1, os1)
  check(f.outposts[1] == nil, "foreuse d'une autre force : ignorée")
  -- migration : paires déjà posées, ordre des numéros d'unité, idempotente ; réglage coupé : tout est rendu
  f = team_of_hand()
  local m1 = pair(25, 5)
  local m2 = pair(-25, -5)
  local taken = Adopte.migrate(f)
  check(taken == 2 and f.outposts_count == 2 and f.outposts[1].drill_list[1] == m1 and f.outposts[2].drill_list[1] == m2,
    "migration : deux paires adoptées, dans l'ordre des numéros d'unité (" .. tostring(taken) .. ")")
  check(Adopte.migrate(f) == 0 and f.outposts_count == 2, "migration rejouée : idempotente")
  setting_value = false
  local _, given = Adopte.migrate(f)
  check(given >= 2 and f.outposts_count == 0 and next(f.adopt.drills) == nil, "réglage coupé : la migration rend les deux paires (" .. tostring(given) .. ")")
  setting_value = true
  check(destroyed == 0, "aucune destruction")
  -- règle pure et mutants
  local dd = A.decide_drill
  local base = { on = true, kind = kind1, burner = true, sink = true, dist2 = 100, linked = false }
  local function with(over) local c = {} for k, v in pairs(base) do c[k] = v end for k, v in pairs(over) do c[k] = v end return c end
  check(dd(base) == true, "règle pure : paire isolée dans le rayon adoptée")
  check(not dd(with({ on = false })) and not dd(with({ burner = false })) and not dd(with({ sink = false }))
    and not dd(with({ already = true })) and not dd(with({ reserved = true })) and not dd(with({ dist2 = 99999 })) and not dd(with({ linked = true })),
    "règle pure : chaque refus est tenu (coupe, combustible, réception, deja, plan, loin, ligne)")
  check(not dd({ on = true, burner = true, sink = true, dist2 = 100, linked = false }), "règle pure : sans ressource connue, refusée")
  local pool = { { oid = 3, kind = "k", x = 0, y = 0 } }
  check(A.join_target(pool, "k", 10, 0) == 3 and A.join_target(pool, "k", 40, 0) == nil and A.join_target(pool, "autre", 1, 0) == nil,
    "règle pure : rejoindre = même ressource et moins de A.JOIN_RADIUS")
  local keep = A.JOIN_RADIUS
  A.JOIN_RADIUS = 0
  check(A.join_target(pool, "k", 10, 0) == nil, "mutant : JOIN_RADIUS nul, plus aucune jonction")
  A.JOIN_RADIUS = keep
end

section("Pose des fours dormants (Stock.deploy_idle)")
do
  local TT = require("shared.team.config")
  package.loaded["script.ai3.places_qg"] = { place = function() return 0 end, is_reserved = PQ.is_reserved }
  game.item_prototypes = setmetatable({}, { __index = function() return { stack_size = 50 } end })
  local Stock = require("script.team.stock")
  local function chest(items)
    local e = { valid = true, items = items }
    e.get_item_count = function(n) return e.items[n] or 0 end
    e.remove_item = function(sp)
      local n = math.min(sp.count, e.items[sp.name] or 0)
      e.items[sp.name] = (e.items[sp.name] or 0) - n
      return n
    end
    e.insert = function(sp) e.items[sp.name] = (e.items[sp.name] or 0) + sp.count return sp.count end
    return e
  end
  game.create_inventory = function()
    local inv = { items = {} }
    inv.insert = function(sp) inv.items[sp.name] = (inv.items[sp.name] or 0) + sp.count return sp.count end
    inv.get_contents = function() local o = {} for k, v in pairs(inv.items) do o[k] = v end return o end
    inv.destroy = function() end
    return inv
  end
  local reg = {}
  local f = { key = "player", is_player = true, hq = chest({ [TT.SMELTER] = 13, [TT.fuel] = 500 }), hq_pos = { x = 0, y = 0 }, stats = {},
    started = 0, engineers_count = 10 }
  local placed_calls = 0
  Stock.free_view = function(team, _) return { [TT.SMELTER] = team.hq.get_item_count(TT.SMELTER) - 3, [TT.fuel] = team.hq.get_item_count(TT.fuel) } end
  Stock.smelters = function() return reg end
  Stock.place_smelters = function(team, _, n, carrier)
    placed_calls = placed_calls + 1
    local have = carrier.items[TT.SMELTER] or 0
    local k = math.min(n, have)
    carrier.items[TT.SMELTER] = have - k
    carrier.items[TT.fuel] = (carrier.items[TT.fuel] or 0) - TT.fuel_per_burner * k
    for i = 1, k do reg[#reg + 1] = { valid = true } end
    return k
  end
  local W = A.IDLE_WINDOW
  check(Stock.deploy_idle(f, {}, 600) == 0 and #reg == 0, "première pensée : la fenêtre s'ouvre, rien n'est posé (le kit de départ reste aux avant-postes)")
  check(Stock.deploy_idle(f, {}, 600 + W - 1) == 0, "fenêtre pas fermée : rien")
  -- une tâche réclame 9 fours dans la fenêtre : le minimum libre observé tombe à 1 et rien n'est posé
  Stock.free_view = function(team, _) return { [TT.SMELTER] = 1, [TT.fuel] = team.hq.get_item_count(TT.fuel) } end
  Stock.deploy_idle(f, {}, 600 + W - 1)
  check(Stock.deploy_idle(f, {}, 600 + W) == 0 and #reg == 0, "fours repris par une tâche dans la fenêtre : jamais posés")
  Stock.free_view = function(team, _) return { [TT.SMELTER] = team.hq.get_item_count(TT.SMELTER) - 3, [TT.fuel] = team.hq.get_item_count(TT.fuel) } end
  Stock.deploy_idle(f, {}, 600 + W + 10)
  Stock.deploy_idle(f, {}, 600 + 2 * W + 10) -- ferme la fenêtre ouverte à l'état bas (1) : rien
  check(Stock.deploy_idle(f, {}, 600 + 3 * W + 20) == A.DEPLOY_PER_THINK and #reg == 4, "restés libres toute une fenêtre : quatre posés")
  check(f.hq.get_item_count(TT.SMELTER) == 9 and f.hq.get_item_count(TT.fuel) == 500 - 4 * TT.fuel_per_burner, "les fours et leur combustible sont sortis du coffre")
  for k = 4, 14 do Stock.deploy_idle(f, {}, 600 + k * W + 30) end
  check(#reg <= require("shared.ai3.bras").SMELT_HARD and f.stats.idle_deployed == #reg, "jamais au-delà de Br.SMELT_HARD (" .. #reg .. ")")
  check(f.hq.get_item_count(TT.SMELTER) >= 3, "les fours gardés restent au coffre")
  -- sans charbon libre : les fours sont posés à sec (la tournée de fonte les ravitaille)
  do
    local reg2 = {}
    local d = { key = "player", is_player = true, hq = chest({ [TT.SMELTER] = 9 }), hq_pos = { x = 0, y = 0 }, stats = {}, started = 0, engineers_count = 10 }
    Stock.free_view = function(team) return { [TT.SMELTER] = team.hq.get_item_count(TT.SMELTER) } end
    Stock.smelters = function() return reg2 end
    Stock.place_smelters = function(team, _, n, carrier)
      local k = math.min(n, carrier.items[TT.SMELTER] or 0)
      carrier.items[TT.SMELTER] = (carrier.items[TT.SMELTER] or 0) - k
      for i = 1, k do reg2[#reg2 + 1] = { valid = true } end
      return k
    end
    Stock.deploy_idle(d, {}, 0)
    check(Stock.deploy_idle(d, {}, A.IDLE_WINDOW) == A.DEPLOY_PER_THINK and #reg2 == A.DEPLOY_PER_THINK, "sans charbon libre : les fours sont posés à sec")
  end
  local g = { key = "scarlet", hq = chest({ [TT.SMELTER] = 13, [TT.fuel] = 500 }), hq_pos = { x = 0, y = 0 }, started = 0, engineers_count = 10 }
  check(Stock.deploy_idle(g, {}, 600) == 0, "une faction : jamais (ses vagues sont à elles)")
  setting_value = false
  settings.global = setmetatable({}, { __index = function(_, k) if k == "fo-war-adopte" then return { value = false } end end })
  local h = { key = "player", is_player = true, hq = chest({ [TT.SMELTER] = 13, [TT.fuel] = 500 }), hq_pos = { x = 0, y = 0 }, stats = {}, started = 0, engineers_count = 30 }
  check(Stock.deploy_idle(h, {}, 600) == 0, "réglage coupé : rien posé")
  setting_value = true
end

section("Anti-échelle : aucun nom d'objet du jeu dans la règle ni l'exécutant")
for _, path in ipairs({ "shared/team/adopte.lua", "script/team/adopte.lua", "script/team/stock.lua" }) do
  local fh = assert(io.open(path, "rb"))
  local src = fh:read("*a")
  fh:close()
  -- on ne lit que le code : les commentaires de ligne sont retirés
  local code = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  local bad = {}
  for _, w in ipairs({ "stone%-furnace", "steel%-furnace", "burner%-mining%-drill", "iron%-plate", "\"coal\"", "\"lab\"%s*[,%)]" }) do
    if code:find(w) then bad[#bad + 1] = w end
  end
  check(#bad == 0, path .. " : pas de nom d'objet en dur (" .. table.concat(bad, ",") .. ")")
end

print(string.format("[ADOPTE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
