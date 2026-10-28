--[[
  Lot LEVIERS : exécutant de la tâche « equiper » (script/team/equiper.lua) au moteur simulé minimal : faux inventaires,
  fausse surface, fausse balise (script/modules/mult.lua remplacé). Le moteur réel est prouvé par le banc leviers-modules.
    §1 programme : prise stricte au coffre, une marche et une insertion par machine ;
    §2 insertion : modules pris dans les poches du PNJ, posés un par un, balise recalculée, ordre mis à jour ;
    §3 refus : machine disparue, aucun emplacement, insertion refusée par le moteur, PNJ sans module ;
    §4 déterminisme : même entrée, même sortie ; rien de non sérialisable dans l'ordre.
  Usage : lua5.2 tests/leviers_exec_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local refreshed = {}
package.loaded["script.modules.mult"] = { refresh = function(e, force) refreshed[#refreshed + 1] = { e = e, force = force } end }
local Equip = require("script.team.equiper")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1 print("[LEVIERS-EXEC] ECHEC : " .. msg) end
end

local function fake_inv(slots, accepts)
  local inv = { items = {}, slots = slots }
  function inv.can_insert(it) return accepts ~= false and inv.count() + it.count <= slots end
  function inv.insert(it)
    if not inv.can_insert(it) then return 0 end
    inv.items[it.name] = (inv.items[it.name] or 0) + it.count
    return it.count
  end
  function inv.count() local n = 0 for _, v in pairs(inv.items) do n = n + v end return n end
  function inv.get_item_count(name) if name then return inv.items[name] or 0 end return inv.count() end
  function inv.remove(it) inv.items[it.name] = (inv.items[it.name] or 0) - it.count return it.count end
  return inv
end

local function scene(opts)
  opts = opts or {}
  local machines = {}
  local surface = {}
  function surface.find_entities_filtered(q)
    local m = machines[q.position[1] .. "," .. q.position[2]]
    if m and m.valid and m.name == q.name then return { m } end
    return {}
  end
  local pockets = fake_inv(80)
  pockets.insert({ name = "productivity-module", count = opts.carry or 12 })
  local agent = { entity = { get_main_inventory = function() return pockets end } }
  local f = { force = "fo-x", team = { capi = { open = { { key = "equiper:k", kind = "equiper", exec = "equiper", done = {}, inserted = 0 } } } } }
  local targets = {}
  for i = 1, 4 do
    local m = { valid = true, name = "electric-furnace", unit_number = 100 + i, inv = fake_inv(opts.slots or 2, opts.accepts) }
    function m.get_module_inventory() if opts.no_inv then return nil end return m.inv end
    machines[(10 * i) .. ",5"] = m
    targets[#targets + 1] = { x = 10 * i, y = 5, u = 100 + i, entity = "electric-furnace" }
  end
  local task = { kind = "equiper", module = "productivity-module", per = 2, rec_key = "equiper:k", targets = targets,
    items = { { "productivity-module", 8 } } }
  return { f = f, agent = agent, surface = surface, task = task, machines = machines, pockets = pockets, targets = targets }
end

-- §1 programme
do
  local sc = scene()
  local steps = Equip.program(sc.f, sc.task)
  check(#steps == 2 + 2 * 4 + 1, "§1 2 + 2 par machine + retour : " .. #steps)
  check(steps[1][1] == "home" and steps[2][1] == "take" and steps[2].strict == true and steps[2][2] == sc.task.items,
    "§1 prise stricte des modules au coffre")
  check(steps[3][1] == "goto" and steps[3][2].x == 10 and steps[4][1] == "act" and steps[4][2] == "equiper"
    and steps[#steps][1] == "home", "§1 marche puis insertion, retour au QG")
  check(Equip.program(sc.f, { targets = {}, items = {} }) == nil, "§1 sans machine : pas de programme")
end

-- §2 insertion
do
  local sc = scene()
  Equip.program(sc.f, sc.task)
  for _ = 1, 4 do Equip.act(sc.agent, sc.f, sc.task, sc.surface, 0) end
  local rec = sc.f.team.capi.open[1]
  check(rec.inserted == 8 and #rec.done == 4 and (rec.refused or 0) == 0, "§2 8 modules posés sur 4 machines (" .. tostring(rec.inserted) .. ")")
  check(sc.pockets.get_item_count("productivity-module") == 4, "§2 les modules viennent des poches du PNJ (reste 4)")
  check(#refreshed == 4 and refreshed[1].force == true, "§2 balise recalculée tout de suite, une fois par machine")
  for i = 1, 4 do
    check(sc.machines[(10 * i) .. ",5"].inv.items["productivity-module"] == 2, "§2 machine " .. i .. " : 2 modules")
  end
end

-- §3 refus
do
  refreshed = {}
  local sc = scene()
  sc.machines["10,5"].valid = false
  Equip.program(sc.f, sc.task)
  Equip.act(sc.agent, sc.f, sc.task, sc.surface, 0)
  local rec = sc.f.team.capi.open[1]
  check(rec.inserted == 0 and rec.refused == 1 and rec.why_refused == "machine disparue" and #rec.done == 1, "§3 machine disparue : traitée, raison écrite")
  local sc2 = scene({ no_inv = true })
  Equip.program(sc2.f, sc2.task)
  Equip.act(sc2.agent, sc2.f, sc2.task, sc2.surface, 0)
  check(sc2.f.team.capi.open[1].why_refused == "aucun emplacement", "§3 aucun emplacement : raison écrite")
  local sc3 = scene({ accepts = false })
  Equip.program(sc3.f, sc3.task)
  Equip.act(sc3.agent, sc3.f, sc3.task, sc3.surface, 0)
  local r3 = sc3.f.team.capi.open[1]
  check(r3.inserted == 0 and r3.why_refused == "insertion refusee par le moteur", "§3 le moteur refuse : aucun module posé, aucun appel de balise")
  check(#refreshed == 0, "§3 pas de balise recalculée quand rien n'est posé")
  local sc4 = scene({ carry = 3 })
  Equip.program(sc4.f, sc4.task)
  for _ = 1, 4 do Equip.act(sc4.agent, sc4.f, sc4.task, sc4.surface, 0) end
  local r4 = sc4.f.team.capi.open[1]
  check(r4.inserted == 3 and r4.refused == 3 and r4.why_refused == "aucun module sur le PNJ", "§3 PNJ à court de modules : 3 posés, 3 machines à moitié ou vides comptées, raison écrite (" .. tostring(r4.inserted) .. "/" .. tostring(r4.refused) .. ")")
  local sc5 = scene()
  sc5.f.team.capi.open = {}
  Equip.program(sc5.f, sc5.task)
  local ok = Equip.act(sc5.agent, sc5.f, sc5.task, sc5.surface, 0)
  check(ok == true and sc5.machines["10,5"].inv.items["productivity-module"] == 2, "§3 ordre disparu : les modules sont posés quand même, sans erreur")
end

-- §4 déterminisme et sérialisation
do
  local a, b = scene(), scene()
  Equip.program(a.f, a.task) Equip.program(b.f, b.task)
  for _ = 1, 4 do Equip.act(a.agent, a.f, a.task, a.surface, 0) Equip.act(b.agent, b.f, b.task, b.surface, 0) end
  local ra, rb = a.f.team.capi.open[1], b.f.team.capi.open[1]
  check(ra.inserted == rb.inserted and table.concat(ra.done, ",") == table.concat(rb.done, ","), "§4 mêmes entrées, mêmes sorties")
  local function has_fn(t, seen)
    if type(t) == "function" then return true end
    if type(t) ~= "table" or seen[t] then return false end
    seen[t] = true
    for _, v in pairs(t) do if has_fn(v, seen) then return true end end
    return false
  end
  check(not has_fn(ra, {}), "§4 l'ordre ouvert ne contient aucune fonction (peut aller dans global)")
end

print(string.format("[LEVIERS-EXEC] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
