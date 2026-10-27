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
  check(A.releasable({ on = true, linked = true }) and A.releasable({ on = false, linked = false })
    and not A.releasable({ on = true, linked = false }), "machine rendue : ligne posée ou adoption coupée")
  local s = A.sorted({ { unit = 9 }, { unit = 2 }, { unit = 5 } })
  check(s[1].unit == 2 and s[2].unit == 5 and s[3].unit == 9, "tri par numéro d'unité")
  local box = A.search_box({ x = 10, y = 20 }, 1, 1)
  check(box[1][1] == 10 - 1 - A.CLEAR and box[2][2] == 20 + 1 + A.CLEAR, "boîte de recherche")
end

do
  check(A.deploy(13, 2, 0, 15, 500, 5) == A.DEPLOY_PER_THINK, "13 fours libres : deux posés par pensée")
  check(A.deploy(3, 2, 0, 15, 500, 5) == 1, "3 libres : un de posé, " .. A.IDLE_KEEP .. " gardés")
  check(A.deploy(2, 2, 0, 15, 500, 5) == 0 and A.deploy(0, 0, 0, 15, 500, 5) == 0, "pas d'excédent : rien")
  check(A.deploy(13, 15, 0, 15, 500, 5) == 0 and A.deploy(13, 14, 0, 15, 500, 5) == 1, "plafond du registre")
  check(A.deploy(13, 10, 5, 15, 500, 5) == 0, "commande en cours comptée")
  check(A.deploy(13, 2, 0, 15, 7, 5) == 1 and A.deploy(13, 2, 0, 15, 4, 5) == 0, "limité par le combustible libre")
  check(A.deploy(nil, nil, nil, nil, nil, nil) == 0, "valeurs absentes : rien")
end

---------------------------------------------------------------------------------------------------
section("Exécution avec un moteur simulé")
local handlers, config_fns = {}, {}
package.loaded["script.core.events"] = {
  on = function(id, fn) handlers[id] = handlers[id] or {}; table.insert(handlers[id], fn) end,
  on_configuration_changed = function(fn) config_fns[#config_fns + 1] = fn end,
}
local ns = { pteam = {} }
package.loaded["script.core.storage"] = { ns = function(n) ns[n] = ns[n] or {}; return ns[n] end }
package.loaded["script.faction.state"] = {
  sorted_keys = function(t)
    local k = {}
    for key in pairs(t) do k[#k + 1] = key end
    table.sort(k)
    return k
  end,
}
local Outposts = { reserved = nil }
package.loaded["script.faction.outposts"] = Outposts
defines = { events = { on_built_entity = 1, on_robot_built_entity = 2 } }
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
      if e.valid and want[e.type] and e.force.name == t.force then
        local dx, dy = e.position.x - t.position.x, e.position.y - t.position.y
        if dx * dx + dy * dy <= t.radius * t.radius then out[#out + 1] = e end
      end
    end
    -- ordre volontairement inversé : l'exécutant doit trier
    table.sort(out, function(a, b) return a.unit_number > b.unit_number end)
    return out
  end,
}

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
  Outposts.reserved = function(_, _, pos) return pos.x == 30 end
  local plan = new_entity(FURNACE_TYPE, 30, 0)
  build(plan)
  check(count(f) == 1 and f.adopt.refused[plan.unit_number] == "plan", "tuile du plan directeur : refusée (plan)")
  Outposts.reserved = nil
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

section("Pose des fours dormants (Stock.deploy_idle)")
do
  local TT = require("shared.team.config")
  package.loaded["script.ai3.places_qg"] = { place = function() return 0 end }
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
  check(Stock.deploy_idle(f, {}, 600) == 2 and #reg == 2, "13 fours au coffre dont 3 réservés : deux posés")
  check(f.hq.get_item_count(TT.SMELTER) == 11 and f.hq.get_item_count(TT.fuel) == 500 - 2 * TT.fuel_per_burner, "les deux fours et leur combustible sont sortis du coffre")
  Stock.deploy_idle(f, {}, 1200); Stock.deploy_idle(f, {}, 1800); Stock.deploy_idle(f, {}, 2400)
  check(#reg == 5 and f.stats.idle_deployed == 5, "plafond de la moitié de l'effectif (10 PNJ : 5 fours) : " .. #reg)
  check(f.hq.get_item_count(TT.SMELTER) == 8, "les fours restants restent au coffre")
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
