--[[
  Tests hors jeu du lot LAYOUT, partie exécutant (script/team/layout_runtime.lua) sur un moteur MINIMAL simulé : choix de la
  foreuse électrique débloquée la plus rapide (prototypes et recettes de la force), exclusions (à combustion, cachée, autre
  catégorie de ressource, emprise différente de celle du gabarit), relevé du champ (catégorie de la ressource, tuiles triées,
  bornes), plan d'une ligne pour un débit voulu et gabarit contrôlé. Le branchement dans Build.plan_drills se joue en moteur réel.
  Usage, depuis la racine du mod :   lua5.2 tests/layout_runtime_test.lua
]]

package.path = "./?.lua;" .. package.path
local M = require("shared.team.modules")
local L = require("shared.levels.config")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local fam = L.by_key.drill
local function lvl(n) return L.name(fam, n) end

-- prototypes simulés : tout est lu à M.spec, sauf les cas d'exclusion
local function proto_of(name, over)
  local sp = M.spec(name)
  local half = sp.w * 0.5 - 0.1
  local p = {
    name = name, type = "mining-drill", collision_box = { left_top = { x = -half, y = -half }, right_bottom = { x = half, y = half } },
    -- comme au moteur : `mining_drill_radius` se lit, `vector_to_place_result` NON (etape data seulement ; constat en jeu 28/10)
    mining_speed = sp.speed, mining_drill_radius = sp.radius,
    items_to_place_this = { { name = name } }, electric_energy_source_prototype = {}, resource_categories = { solide = true },
    has_flag = function() return false end,
  }
  for k, v in pairs(over or {}) do p[k] = v end
  return p
end

local PROTOS = {}
for _, n in ipairs({ "electric-mining-drill", lvl(3), lvl(5), lvl(9), lvl(20) }) do PROTOS[n] = proto_of(n) end
PROTOS["burner-mining-drill"] = proto_of("burner-mining-drill", { electric_energy_source_prototype = false })
PROTOS[lvl(6)] = proto_of(lvl(6), { has_flag = function() return true end }) -- cachée
PROTOS[lvl(7)] = proto_of(lvl(7), { collision_box = { left_top = { x = -1.4, y = -1.4 }, right_bottom = { x = 1.4, y = 1.4 } } }) -- 3 au lieu de 4
PROTOS[lvl(8)] = proto_of(lvl(8), { resource_categories = { liquide = true } })

local enabled = {}
local stock = {}
local function install()
  _G.game = {
    get_filtered_entity_prototypes = function(filters)
      assert(filters[1].filter == "type" and filters[1].type == "mining-drill")
      return PROTOS
    end,
    get_filtered_recipe_prototypes = function(filters)
      local item = filters[1].elem_filters[1].name
      return { [item] = { name = item } }
    end,
    entity_prototypes = { ["iron-ore"] = { resource_category = "solide" }, ["autre-minerai"] = { resource_category = "solide" },
      ["petrole"] = { resource_category = "liquide" } },
    forces = { eq = { recipes = setmetatable({}, { __index = function(_, n) return { enabled = enabled[n] or false } end }) } },
  }
end
install()

package.loaded["script.team.layout_runtime"] = nil
local RT = require("script.team.layout_runtime")
local function names(list) local t = {} for _, d in ipairs(list) do t[#t + 1] = d.name end return table.concat(t, ",") end

section("Foreuse débloquée la plus rapide")
do
  enabled = {}
  check(#RT.options("eq", "iron-ore", nil) == 0, "rien de débloqué : aucune option")
  enabled["electric-mining-drill"] = true
  local o = RT.options("eq", "iron-ore", nil)
  check(#o == 1 and o[1].name == "electric-mining-drill", "base seule : " .. names(o))
  enabled[lvl(3)] = true
  enabled[lvl(5)] = true
  o = RT.options("eq", "iron-ore", nil)
  check(o[1].name == lvl(5) and o[2].name == lvl(3) and o[3].name == "electric-mining-drill", "la plus rapide d'abord : " .. names(o))
  check(o[1].speed > o[2].speed and o[2].speed > o[3].speed, "vitesses décroissantes")
  check(o[1].drop and o[1].drop[2] == M.spec(lvl(5)).drop[2] and o[1].reach == M.spec(lvl(5)).radius, "sortie de la fiche du gabarit, rayon du prototype")
  -- exclusions : à combustion, cachée, emprise différente, autre catégorie de ressource
  enabled["burner-mining-drill"], enabled[lvl(6)], enabled[lvl(7)], enabled[lvl(8)] = true, true, true, true
  o = RT.options("eq", "iron-ore", nil)
  check(names(o) == lvl(5) .. "," .. lvl(3) .. ",electric-mining-drill", "exclusions (combustion, cachée, emprise, catégorie) : " .. names(o))
  check(names(RT.options("eq", "petrole", nil)) == lvl(8), "ressource liquide : seule la foreuse de cette categorie")
  -- au coffre sans recette ouverte
  stock[lvl(20)] = 2
  o = RT.options("eq", "iron-ore", function(n) return stock[n] or 0 end)
  check(o[1].name == lvl(20), "une foreuse de niveau 20 au coffre passe en tête : " .. names(o))
end

section("Relevé du champ")
do
  local ents = {}
  local function add(name, cat, x, y, amount) ents[#ents + 1] = { valid = true, name = name, position = { x = x + 0.5, y = y + 0.5 }, amount = amount,
    prototype = { resource_category = cat } } end
  for x = 0, 9 do for y = 0, 9 do add("iron-ore", "solide", x, y, 300) end end
  add("autre-minerai", "solide", 11, 3, 50)
  add("petrole", "liquide", 5, 5, 100000)
  add("iron-ore", "solide", 4, 4, 0)
  local surface = { find_entities_filtered = function(t)
    assert(t.type == "resource" and t.area)
    return ents
  end }
  local field = RT.field(surface, "iron-ore", 0, 0, 24, 24, function(x, y) return not (x == 3 and y == 3) end)
  check(field ~= nil, "champ lu")
  check(#field.tiles == 101, "100 tuiles de fer + 1 de l'autre minerai de la même catégorie ; ni le pétrole ni la tuile vide : " .. #field.tiles)
  check(field.bounds.x0 == 1 and field.bounds.x1 == 23 and field.bounds.y0 == 1 and field.bounds.y1 == 23, "bornes : lot rogné d'une tuile")
  check(field.blocked(3, 3) and not field.blocked(4, 4), "obstacle = tuile non libre")
  local ok = true
  for i = 2, #field.tiles do
    local a, b = field.tiles[i - 1], field.tiles[i]
    if a.x > b.x or (a.x == b.x and a.y > b.y) then ok = false end
  end
  check(ok, "tuiles triées (déterminisme)")
  check(RT.field({ find_entities_filtered = function() return {} end }, "iron-ore", 0, 0, 24, 24, function() return true end) == nil, "aucun minerai : pas de champ")
  check(RT.field(surface, "inconnu", 0, 0, 24, 24, function() return true end) == nil, "ressource inconnue : pas de champ")

  section("Plan d'une ligne pour un débit voulu")
  enabled[lvl(5)] = true
  local drills = RT.options("eq", "iron-ore", nil)
  for _, flow in ipairs({ 0.5, 2.0, 6.0 }) do
    local d = drills[1]
    local plan, g = RT.plan(field, d, "iron-ore", flow, { x = 40, y = 12 }, nil)
    check(plan ~= nil, "plan pour " .. flow .. "/s : " .. tostring(g))
    if plan then
      local want = math.max(1, math.ceil(flow / d.speed - 1e-9))
      check(plan.drills_n <= want and plan.drills_n >= 1, string.format("%.1f/s : %d foreuse(s), au plus %d", flow, plan.drills_n, want))
      check(#M.check(g) == 0, "gabarit sans défaut")
      check(g.origin and g.origin[1] and g.origin[2], "origine du gabarit en coordonnées du monde")
      check(#plan.exits == 1, "une seule sortie")
      local e = plan.exits[1]
      check(e.dir == 2 or e.dir == 0 or e.dir == 4, "sortie du côté de l'arrivée (est) ou le long du bord")
    end
  end
  -- aucune foreuse du tout : refus propre
  local plan, why = RT.plan({ tiles = {}, blocked = function() return false end, bounds = { x0 = 0, y0 = 0, x1 = 22, y1 = 22 } },
    drills[1], "iron-ore", 1, { x = 40, y = 12 }, nil)
  check(plan == nil and why == "aucun minerai", "champ vide : refus « aucun minerai »")
end

print(string.format("[LAYOUT-RT] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
