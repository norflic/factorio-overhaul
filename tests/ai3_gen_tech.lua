--[[
  IA3 (conception) : génère tests/fixtures/tech_ai3.lua, les TECHNOLOGIES vanilla 1.1.91 (nom, prérequis, recettes
  débloquées, coût en packs), lues dans <data>/base/prototypes/technology.lua avec des bouchons minimaux (data:extend,
  util). Sert au prototype pur du cerveau générique (shared/ai3/graphe.lua) et à son test hors jeu ; en jeu, la même
  information se lit dans game.technology_prototypes. Les technologies infinies (count_formula) sont omises.

  Usage : lua5.2 tests/ai3_gen_tech.lua "<racine>/data" tests/fixtures/tech_ai3.lua
]]

local data_dir, out_path = arg[1], arg[2]
assert(data_dir and out_path, "usage : lua5.2 tests/ai3_gen_tech.lua <data> <sortie>")

local techs = {}
_G.data = { extend = function(_, list) for _, p in ipairs(list) do techs[#techs + 1] = p end end }
_G.util = setmetatable({}, { __index = function() return function() return {} end end })

local chunk = assert(loadfile(data_dir .. "/base/prototypes/technology.lua"))
chunk()

local function ingredient(i)
  if i.name then return i.name, i.amount end
  return i[1], i[2]
end

local rows = {}
for _, t in ipairs(techs) do
  if t.type == "technology" then
    local body = t.normal or t
    local unit = body.unit or t.unit
    if unit and unit.count then
      local ings = {}
      for _, i in ipairs(unit.ingredients) do
        local n, a = ingredient(i)
        ings[#ings + 1] = string.format("{ %q, %d }", n, a)
      end
      local unlocks = {}
      for _, e in ipairs(body.effects or t.effects or {}) do
        if e.type == "unlock-recipe" then unlocks[#unlocks + 1] = string.format("%q", e.recipe) end
      end
      local pre = {}
      for _, p in ipairs(body.prerequisites or t.prerequisites or {}) do pre[#pre + 1] = string.format("%q", p) end
      rows[#rows + 1] = { t.name, string.format("  [%q] = { count = %d, time = %s, ingredients = { %s }, prerequisites = { %s }, unlocks = { %s } },",
        t.name, unit.count, tostring(unit.time), table.concat(ings, ", "), table.concat(pre, ", "), table.concat(unlocks, ", ")) }
    end
  end
end
table.sort(rows, function(a, b) return a[1] < b[1] end)

local lines = { "-- Généré par tests/ai3_gen_tech.lua (technologies vanilla 1.1.91, infinies omises). Ne pas éditer.", "return {" }
for _, r in ipairs(rows) do lines[#lines + 1] = r[2] end
lines[#lines + 1] = "}"
local f = assert(io.open(out_path, "wb"))
f:write(table.concat(lines, "\n"), "\n")
f:close()
print(string.format("[AI3-GEN-TECH] %d technologie(s) écrite(s) dans %s", #rows, out_path))
