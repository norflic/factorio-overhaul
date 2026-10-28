--[[
  Lot LEVIERS : données et scènes communes aux tests de shared/ai3/leviers.lua (tests/leviers_test.lua). Ce fichier est du
  TEST : il nomme les prototypes vanilla et mod (comme le moteur) ; la règle n'en voit rien.
]]
package.path = "./?.lua;" .. package.path
local F = require("tests.iag_fixture")
local Ca = require("shared.ai3.capitalisation")

local C = {}

function C.sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

function C.deep(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = C.deep(v) end
  return c
end

local V_SPEED = { ["stone-furnace"] = 1, ["steel-furnace"] = 2, ["electric-furnace"] = 2, ["assembling-machine-1"] = 0.5,
  ["assembling-machine-2"] = 0.75, ["assembling-machine-3"] = 1.25, ["burner-mining-drill"] = 0.25,
  ["electric-mining-drill"] = 0.5, ["pumpjack"] = 1, ["lab"] = 1, ["chemical-plant"] = 1, ["oil-refinery"] = 1,
  ["centrifuge"] = 1 }
local V_AREA = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 5, ["pumpjack"] = 1 }
local V_SIZE = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 3, ["stone-furnace"] = 2, ["steel-furnace"] = 2 }
local V_KW = { ["stone-furnace"] = 90, ["steel-furnace"] = 90, ["electric-furnace"] = 180, ["burner-mining-drill"] = 150,
  ["electric-mining-drill"] = 90, ["assembling-machine-1"] = 75, ["assembling-machine-2"] = 150,
  ["assembling-machine-3"] = 375, ["lab"] = 60, ["boiler"] = 1800 }

--- Effets des modules en centièmes (barème D-17 : vitesse +20 puis +10 par palier, énergie 60 % du bonus ; productivité
--- +10 puis +5, malus de vitesse ; efficacité −30 % d'énergie). Recettes permises à la productivité : les plaques et
--- quelques intermédiaires (la liste vient des données).
C.PROD_LIMIT = { "iron-plate", "copper-plate", "steel-plate", "iron-gear-wheel", "electronic-circuit", "copper-cable",
  "automation-science-pack" }
C.MODULES = {
  ["speed-module"] = { speed = 20, consumption = 12 },
  ["speed-module-2"] = { speed = 30, consumption = 18 },
  ["speed-module-3"] = { speed = 40, consumption = 24 },
  ["productivity-module"] = { productivity = 10, speed = -2, consumption = 6, pollution = 5, limit = true },
  ["productivity-module-2"] = { productivity = 15, speed = -5, consumption = 9, pollution = 7, limit = true },
  ["effectivity-module"] = { consumption = -30 },
}
C.SLOTS = { ["electric-furnace"] = 2, ["assembling-machine-2"] = 2, ["assembling-machine-3"] = 4,
  ["electric-mining-drill"] = 3, ["lab"] = 2 }
C.TECHS = {
  ["mining-productivity-1"] = { { type = "mining-drill-productivity-bonus", modifier = 0.1 } },
  ["research-speed-1"] = { { type = "laboratory-speed", modifier = 0.2 } },
  ["worker-robots-speed-1"] = { { type = "worker-robot-speed", modifier = 0.35 } },
  ["physical-projectile-damage-1"] = { { type = "ammo-damage", modifier = 0.1 } },
}

--- Relevé `lv` (ce que script/ai3/capitalisation.lua lit sur les prototypes en jeu).
function C.lv(mut)
  local lv = { equip = {}, slots = {}, techs = {} }
  for name, e in pairs(C.MODULES) do
    lv.equip[name] = { effects = { speed = e.speed, consumption = e.consumption, productivity = e.productivity,
      pollution = e.pollution }, limit = e.limit and C.PROD_LIMIT or nil }
  end
  for ent, n in pairs(C.SLOTS) do
    lv.slots[ent] = { n = n, allowed = { speed = true, consumption = true, productivity = true, pollution = true } }
  end
  lv.techs = C.deep(C.TECHS)
  if mut then mut(lv) end
  return lv
end

function C.dump(mut, fopts, lvmut)
  local d = F.dump(fopts)
  for _, e in ipairs(d.entities) do
    if V_SPEED[e.name] then e.speed = V_SPEED[e.name] end
    e.mining_area = V_AREA[e.name]
    e.size = V_SIZE[e.name] or 3
    e.energy_kw = V_KW[e.name]
  end
  for _, t in ipairs(C.sorted_keys(d.techs)) do
    for _, r in ipairs(d.techs[t].unlocks) do if d.recipes[r] then d.recipes[r].enabled = false end end
  end
  for _, r in ipairs(d.resources) do r.mining_time = r.entity == "uranium-ore" and 2 or 1 end
  d.lv = C.lv(lvmut)
  if mut then mut(d) end
  return d
end

C.EXEC = { ["stone-furnace"] = true, ["steel-furnace"] = true, ["electric-furnace"] = true, ["burner-mining-drill"] = true,
  ["electric-mining-drill"] = true, ["assembling-machine-1"] = true, ["assembling-machine-2"] = true }
C.ROLES = { main = true, labo = true }

function C.data(mut, exec, fopts, lvmut)
  return Ca.data(C.dump(mut, fopts, lvmut), { exec = exec or C.EXEC, exec_roles = C.ROLES })
end

--- Entrée de base : de l'assemblage recherché, bras libres.
function C.input(D, over)
  local inp = { data = D, state = { techs = { automation = true } }, stock = {}, flows = {}, machines = {}, drills = {},
    labs = {}, deposits = {}, open = {}, sinks = {}, workers = 30, idle = 10, can_grow = true, traits = {}, weights = {} }
  for k, v in pairs(over or {}) do inp[k] = v end
  return inp
end

---------------------------------------------------------------------------------------------------
-- Renommage de TOUS les noms (preuve de généralisation, comme tests/ai3_capitalisation_test.lua §8e), relevé `lv` compris
---------------------------------------------------------------------------------------------------
function C.name_map(d)
  local names = {}
  local function n(x) if type(x) == "string" then names[x] = true end end
  for rn, r in pairs(d.recipes) do
    n(rn) n(r.category)
    for _, i in ipairs(r.ingredients or {}) do n(i.name) end
    for _, p in ipairs(r.products or {}) do n(p.name) end
  end
  for tn, t in pairs(d.techs) do
    n(tn)
    for _, x in ipairs(t.prerequisites or {}) do n(x) end
    for _, x in ipairs(t.unlocks or {}) do n(x) end
    for _, x in ipairs(t.ingredients or {}) do n(x[1]) end
  end
  for _, e in ipairs(d.entities) do
    n(e.name) n(e.item)
    for _, c in ipairs(e.crafting_categories or {}) do n(c) end
    for _, c in ipairs(e.resource_categories or {}) do n(c) end
    for _, c in ipairs(e.lab_inputs or {}) do n(c) end
  end
  for _, r in ipairs(d.resources) do
    n(r.entity) n(r.category)
    for _, p in ipairs(r.products or {}) do n(p.name) end
  end
  for k in pairs(d.items) do n(k) end
  for k, m in pairs(d.lv.equip) do
    n(k)
    for _, r in ipairs(m.limit or {}) do n(r) end
  end
  for k in pairs(d.lv.slots) do n(k) end
  for k in pairs(d.lv.techs) do n(k) end
  local map = {}
  for i, x in ipairs(C.sorted_keys(names)) do map[x] = string.format("z%05d", i) end -- l'ordre des noms est gardé
  return map
end

function C.rename(d, map)
  local function m(x) return (type(x) == "string" and map[x]) or x end
  local nd = { recipes = {}, techs = {}, entities = {}, resources = {}, items = {}, lv = { equip = {}, slots = {}, techs = {} } }
  for _, rn in ipairs(C.sorted_keys(d.recipes)) do
    local r = C.deep(d.recipes[rn])
    r.category = m(r.category)
    for _, i in ipairs(r.ingredients or {}) do i.name = m(i.name) end
    for _, p in ipairs(r.products or {}) do p.name = m(p.name) end
    nd.recipes[m(rn)] = r
  end
  for _, tn in ipairs(C.sorted_keys(d.techs)) do
    local t = C.deep(d.techs[tn])
    for i, x in ipairs(t.prerequisites or {}) do t.prerequisites[i] = m(x) end
    for i, x in ipairs(t.unlocks or {}) do t.unlocks[i] = m(x) end
    for _, x in ipairs(t.ingredients or {}) do x[1] = m(x[1]) end
    nd.techs[m(tn)] = t
  end
  for _, e0 in ipairs(d.entities) do
    local e = C.deep(e0)
    e.name, e.item = m(e.name), m(e.item)
    for i, c in ipairs(e.crafting_categories or {}) do e.crafting_categories[i] = m(c) end
    for i, c in ipairs(e.resource_categories or {}) do e.resource_categories[i] = m(c) end
    for i, c in ipairs(e.lab_inputs or {}) do e.lab_inputs[i] = m(c) end
    nd.entities[#nd.entities + 1] = e
  end
  for _, r0 in ipairs(d.resources) do
    local r = C.deep(r0)
    r.entity, r.category = m(r.entity), m(r.category)
    for _, p in ipairs(r.products or {}) do p.name = m(p.name) end
    nd.resources[#nd.resources + 1] = r
  end
  for _, k in ipairs(C.sorted_keys(d.items)) do nd.items[m(k)] = C.deep(d.items[k]) end
  for _, k in ipairs(C.sorted_keys(d.lv.equip)) do
    local e = C.deep(d.lv.equip[k])
    for i, r in ipairs(e.limit or {}) do e.limit[i] = m(r) end
    nd.lv.equip[m(k)] = e
  end
  for _, k in ipairs(C.sorted_keys(d.lv.slots)) do nd.lv.slots[m(k)] = C.deep(d.lv.slots[k]) end
  for _, k in ipairs(C.sorted_keys(d.lv.techs)) do nd.lv.techs[m(k)] = C.deep(d.lv.techs[k]) end
  return nd
end

function C.rename_input(inp, map, D2)
  local function m(x) return (type(x) == "string" and map[x]) or x end
  local function keys(t) local o = {} for _, k in ipairs(C.sorted_keys(t)) do o[m(k)] = C.deep(t[k]) end return o end
  local o = {}
  for k, v in pairs(inp) do if type(v) ~= "function" then o[k] = C.deep(v) else o[k] = v end end
  o.data = D2
  o.state = { techs = keys(inp.state.techs) }
  o.stock, o.flows = keys(inp.stock), keys(inp.flows)
  for _, x in ipairs(o.machines or {}) do
    x.entity, x.recipe = m(x.entity), m(x.recipe)
    if x.mods then x.mods = keys(x.mods) end
  end
  for _, x in ipairs(o.drills or {}) do
    x.entity, x.resource = m(x.entity), m(x.resource)
    if x.mods then x.mods = keys(x.mods) end
  end
  for _, x in ipairs(o.labs or {}) do x.entity = m(x.entity) end
  for _, x in ipairs(o.deposits or {}) do x.resource, x.smelt, x.smelter = m(x.resource), m(x.smelt), m(x.smelter) end
  for _, x in ipairs(o.sinks or {}) do x.item = m(x.item) end
  if o.research then
    for _, q in ipairs(o.research.queue or {}) do
      q.tech = m(q.tech)
      for _, p in ipairs(q.packs or {}) do p[1] = m(p[1]) end
    end
  end
  if type(inp.obtainable) == "function" then o.obtainable = inp.obtainable end
  if inp.can_exec then
    local un = {}
    for k, v in pairs(map) do un[v] = k end
    local f0 = inp.can_exec
    o.can_exec = function(kind, item) return f0(kind, un[item] or item) end
  end
  return o
end

return C
