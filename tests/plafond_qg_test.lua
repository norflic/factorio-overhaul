--[[
  Lot STOCK-QG : plafonds de rapatriement au QG par catégorie d'objet (shared/team/plafond_qg.lua, règle pure ; script/team/plafond_qg.lua,
  lecture des prototypes ; script/team/stock.lua, branchement : Stock.skip_fn, Stock.grow, Stock.insert), avec des coffres et des prototypes
  simulés, et des MUTANTS de la règle pure.
  Usage, depuis la racine du mod :   lua5.2 tests/plafond_qg_test.lua
]]
package.path = "./?.lua;" .. package.path
local PATH = "shared/team/plafond_qg.lua"
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end
local SRC = read(PATH)

local ok_n, bad = 0, 0
local function check(name, cond, detail)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[STOCK-QG] ECHEC : " .. name .. (detail and (" (" .. tostring(detail) .. ")") or "")) end
end

---------------------------------------------------------------------------------------------------
-- Règle pure
---------------------------------------------------------------------------------------------------
local function suite(Pq)
  local res = {}
  local function c(name, cond, detail) res[#res + 1] = { name, cond and true or false, detail } end
  local CFG = { brut = 8, base = 40, declasse = 2, base_depth = 2, brut_demande = 4 }

  -- profondeur de recette
  local raw = { ore = true, coal = true }
  local recipes = {
    { ins = { "ore" }, outs = { "plate" } },
    { ins = { "plate" }, outs = { "gear" } },
    { ins = { "gear", "plate" }, outs = { "machine" } },
    { ins = {}, outs = { "acid" } },                      -- fluides seuls : 1
    { ins = { "plate" }, outs = { "plate2" } },
    { ins = { "gear" }, outs = { "plate2" } },             -- plus profonde : la moins profonde gagne
    { ins = { "machine" }, outs = { "ore" } },             -- recyclage : un brut reste à 0
    { ins = { "loop_b" }, outs = { "loop_a" } },
    { ins = { "loop_a" }, outs = { "loop_b" } },           -- cycle sans entrée : jamais atteint
    { ins = { "unknown_in" }, outs = { "orphan" } },
  }
  local d = Pq.depths(recipes, raw)
  c("profondeur : brut 0", d.ore == 0 and d.coal == 0)
  c("profondeur : plaque 1, engrenage 2, machine 3", d.plate == 1 and d.gear == 2 and d.machine == 3, tostring(d.machine))
  c("profondeur : fluides seuls = 1", d.acid == 1)
  c("profondeur : la recette la moins profonde gagne", d.plate2 == 2, tostring(d.plate2))
  c("profondeur : un brut fabriqué par recyclage reste a 0", d.ore == 0)
  c("profondeur : cycle sans entree et ingredient inconnu : inconnus", d.loop_a == nil and d.loop_b == nil and d.orphan == nil)

  -- bâtiments déclassés
  local all = function() return true end
  local b = {
    { item = "stone", group = "furnace", rating = 1 }, { item = "steel", group = "furnace", rating = 2 },
    { item = "elec", group = "furnace", rating = 2 }, { item = "drill1", group = "drill", rating = 0.35 },
    { item = "drill2", group = "drill", rating = 0.5 }, { item = "chest", rating = 1 }, { item = "norate", group = "furnace" },
  }
  local o = Pq.obsolete(b, all)
  c("declasse : le plus lent d'une famille", o.stone == true and o.drill1 == true)
  c("declasse : le plus rapide et les egaux jamais", not o.steel and not o.elec and not o.drill2)
  c("declasse : sans famille ni vitesse jamais", not o.chest and not o.norate)
  local o2 = Pq.obsolete(b, function(i) return i ~= "steel" and i ~= "elec" end)
  c("declasse : seulement si un meilleur est FABRICABLE par l'equipe", not o2.stone and o2.drill1 == true)
  local o3 = Pq.obsolete(b, function(i) return i == "stone" end)
  c("declasse : un meilleur non fabricable ne declasse pas", not o3.stone)

  -- catégories
  local items = {
    ore = { place = false, plain = true }, coal = { place = false, plain = true }, plate = { plain = true }, gear = { plain = true },
    machine = { plain = true }, acid = { plain = true }, stone = { place = true, plain = true }, steel = { place = true, plain = true },
    ammo = { plain = false }, tool = { plain = false }, wild = { plain = true }, chest = { place = true, plain = true },
    ghost_raw = { place = true, plain = true },
  }
  d.ammo, d.tool = 1, 1
  local cat = Pq.classify(items, { ore = true, coal = true, ghost_raw = true, extra_raw = true }, d, { stone = true }, CFG)
  c("categorie : brut", cat.ore == "brut" and cat.coal == "brut")
  c("categorie : un brut posable reste brut", cat.ghost_raw == "brut")
  c("categorie : un brut absent des objets entre quand meme", cat.extra_raw == "brut")
  c("categorie : intermediaire de base (profondeur <= 2)", cat.plate == "base" and cat.gear == "base" and cat.acid == "base")
  c("categorie : profondeur 3 = fini", cat.machine == "fini", tostring(cat.machine))
  c("categorie : bâtiment declasse", cat.stone == "declasse")
  c("categorie : bâtiment utile = fini", cat.steel == "fini" and cat.chest == "fini")
  c("categorie : munition ou pack (pas type item) = fini", cat.ammo == "fini" and cat.tool == "fini")
  c("categorie : profondeur inconnue = fini", cat.wild == "fini")
  local cat2 = Pq.classify(items, raw, d, nil, { brut = 8, base = 40, declasse = 2, base_depth = 1 })
  c("categorie : profondeur de base reglable (1)", cat2.plate == "base" and cat2.gear == "fini")

  -- plafonds
  c("plafond : brut 8 piles de 50 = 400", Pq.cap_count("brut", 50, CFG) == 400)
  c("plafond : base 40 piles de 100 = 4000, declasse 2 x 50 = 100", Pq.cap_count("base", 100, CFG) == 4000 and Pq.cap_count("declasse", 50, CFG) == 100)
  c("plafond : fini ou categorie inconnue ou pile inconnue : aucun", Pq.cap_count("fini", 50, CFG) == nil and Pq.cap_count(nil, 50, CFG) == nil
    and Pq.cap_count("brut", nil, CFG) == nil and Pq.cap_count("brut", 0, CFG) == nil)
  local C = { coal = "brut", plate = "base", stone = "declasse", gun = "fini", wood = "brut" }
  local S = { coal = 50, plate = 100, stone = 50, gun = 50, wood = 100 }
  local r = Pq.capped(C, { coal = 399, plate = 3999, stone = 99, gun = 1e6, wood = 799 }, S, nil, CFG)
  c("capped : sous le plafond rien", next(r) == nil)
  r = Pq.capped(C, { coal = 400, plate = 4000, stone = 100, gun = 1e6, wood = 800 }, S, nil, CFG)
  c("capped : exactement au plafond (>=)", r.coal == 400 and r.plate == 4000 and r.stone == 100 and r.wood == 800)
  c("capped : un objet fini n'est jamais plafonne", r.gun == nil)
  r = Pq.capped(C, { coal = 5000, plate = 9000, stone = 900 }, S, { coal = 100, plate = 100, stone = 100 }, CFG)
  c("capped : le brut reste plafonne meme demande (plafond dur)", r.coal == 5000)
  c("capped : base et declasse cedent devant une demande", r.plate == nil and r.stone == nil)
  r = Pq.capped(C, { coal = 1599 }, S, { coal = 1 }, CFG)
  c("capped : un brut DEMANDE a un plafond 4 fois plus haut (1599 < 1600 passe)", r.coal == nil)
  r = Pq.capped(C, { coal = 1600 }, S, { coal = 1 }, CFG)
  c("capped : un brut demande est plafonne a 1600 (>=)", r.coal == 1600)
  r = Pq.capped(C, { coal = 1000 }, S, nil, CFG)
  c("capped : le meme brut non demande est plafonne des 400", r.coal == 1000)
  r = Pq.capped(C, { coal = 1000, plate = 5000 }, S, { coal = 0, plate = 0 }, CFG)
  c("capped : une demande a zero (ou nulle) est une demande (clef presente)", r.coal == nil and r.plate == nil)
  r = Pq.capped(C, { coal = 5000, mystery = 9000 }, S, nil, CFG)
  c("capped : objet sans categorie ignore", r.mystery == nil and r.coal == 5000)
  r = Pq.capped(C, { coal = 5000, plate = 9000 }, { coal = 50 }, nil, CFG)
  c("capped : pile inconnue : ignore", r.plate == nil and r.coal == 5000)
  local nm = {}
  for k in pairs(Pq.capped(C, { coal = 5000, plate = 9000, stone = 900, wood = 5000 }, S, nil, CFG)) do nm[#nm + 1] = k end
  c("capped : 4 objets", #nm == 4)

  -- place restante
  c("room : brut 8 piles de 50, 100 au stock : 300 de place", Pq.room("brut", 100, 50, false, CFG) == 300)
  c("room : au plafond : 0, au-dela : 0 (jamais negatif)", Pq.room("brut", 400, 50, false, CFG) == 0 and Pq.room("brut", 900, 50, false, CFG) == 0)
  c("room : brut demande : 1600 - 450 = 1150", Pq.room("brut", 450, 50, true, CFG) == 1150)
  c("room : base ou declasse DEMANDE : aucun plafond (nil)", Pq.room("base", 9000, 100, true, CFG) == nil and Pq.room("declasse", 900, 50, true, CFG) == nil)
  c("room : base non demandee : 4000 - 100", Pq.room("base", 100, 100, false, CFG) == 3900)
  c("room : fini ou categorie inconnue : nil", Pq.room("fini", 5, 50, false, CFG) == nil and Pq.room(nil, 5, 50, false, CFG) == nil)
  c("room : pile inconnue : nil", Pq.room("brut", 5, nil, false, CFG) == nil)
  c("discards : brut et declasse se jettent, base et fini non", Pq.discards("brut") == true and Pq.discards("declasse") == true
    and not Pq.discards("base") and not Pq.discards("fini") and not Pq.discards(nil))

  -- cases de junk
  c("junk : brut 450/50 = 9 cases, declasse 120/50 = 3 cases", Pq.junk_slots(C, { coal = 450, stone = 120 }, S) == 12,
    tostring(Pq.junk_slots(C, { coal = 450, stone = 120 }, S)))
  c("junk : une base ou un fini ne compte pas", Pq.junk_slots(C, { plate = 9000, gun = 500 }, S) == 0)
  c("junk : pile entamee = une case", Pq.junk_slots(C, { coal = 1 }, S) == 1)
  c("junk : pile inconnue = 1 par objet", Pq.junk_slots(C, { coal = 3 }, {}) == 3)
  local u = Pq.grows(70, 96, 40)
  c("grows : cases prises moins le junk", u == 30)
  c("grows : jamais negatif", Pq.grows(10, 96, 40) == 0 and Pq.grows(nil, 96, nil) == 0)
  return res
end

local function run(Pq)
  local res = suite(Pq)
  return res
end

local Pq = load(SRC, "=" .. PATH)()
for _, r in ipairs(run(Pq)) do check(r[1], r[2], r[3]) end

local MUT = {
  { "profondeur : la plus profonde gagne", "if d[o] == nil or m + 1 < d[o] then d[o] = m + 1; changed = true end", "if d[o] == nil or m + 1 > d[o] then d[o] = m + 1; changed = true end" },
  { "profondeur : ingredient inconnu accepte", "if d[i] == nil then known = false break end", "if d[i] == nil then break end" },
  { "profondeur : ingredient oublie", "if d[i] > m then m = d[i] end", "" },
  { "declasse : egaux declasses", "b.rating < best[b.group]", "b.rating <= best[b.group]" },
  { "declasse : fabricabilite ignoree", "if b.group and type(b.rating) == \"number\" and available(b.item) then", "if b.group and type(b.rating) == \"number\" then" },
  { "declasse : famille ignoree", "if b.group and type(b.rating) == \"number\" and available(b.item) then", "if type(b.rating) == \"number\" and available(b.item) then" },
  { "categorie : le brut n'est plus brut", "    if raw and raw[it] then\n      out[it] = Pq.CAT.BRUT", "    if false then\n      out[it] = Pq.CAT.BRUT" },
  { "categorie : un declasse est fini", "(obsolete and obsolete[it]) and Pq.CAT.DECLASSE or Pq.CAT.FINI", "Pq.CAT.FINI" },
  { "categorie : profondeur stricte", "depths[it] <= cfg.base_depth", "depths[it] < cfg.base_depth" },
  { "categorie : munition de base", "info.plain and depths", "depths" },
  { "categorie : posable de base", "elseif info.place then", "elseif false then" },
  { "categorie : profondeur inconnue = base", "depths and depths[it] ~= nil and depths[it] <= cfg.base_depth", "(not depths or depths[it] == nil or depths[it] <= cfg.base_depth)" },
  { "plafond : pile nulle", "or type(stack) ~= \"number\" or stack <= 0 then return nil end", "or type(stack) ~= \"number\" then return nil end" },
  { "junk : declasse oublie", "if (cat == Pq.CAT.BRUT or cat == Pq.CAT.DECLASSE) and counts[it] > 0 then", "if cat == Pq.CAT.BRUT and counts[it] > 0 then" },
  { "junk : base comptee", "if (cat == Pq.CAT.BRUT or cat == Pq.CAT.DECLASSE) and counts[it] > 0 then", "if cat ~= Pq.CAT.FINI and counts[it] > 0 then" },
  { "junk : cases arrondies au-dessous", "n = n + math.ceil(counts[it] / math.max(1, stack_of[it] or 1))", "n = n + math.floor(counts[it] / math.max(1, stack_of[it] or 1))" },
  { "brut traite comme une base : la demande l'ecarte", "if cat == Pq.CAT.BRUT then cap = cap *", "if false then cap = cap *" },
  { "plafond strict (>)", "local room = cap - (count or 0)", "local room = cap - (count or 0) + 1" },
  { "brut demande sans plafond plus haut", "then cap = cap * (cfg_of(cfg).brut_demande or 1) else", "then cap = cap else" },
  { "brut demande sans borne", "then cap = cap * (cfg_of(cfg).brut_demande or 1) else", "then cap = 1e12 else" },
  { "room : negatif permis", "  return room > 0 and room or 0", "  return room" },
  { "room : base demandee plafonnee", "else return nil end", "end" },
  { "room : demande du brut sans effet", "if cat == Pq.CAT.BRUT then cap = cap * (cfg_of(cfg).brut_demande or 1) else return nil end", "if cat == Pq.CAT.BRUT then else return nil end" },
  { "discards : la base se jette", "return cat == Pq.CAT.BRUT or cat == Pq.CAT.DECLASSE", "return cat == Pq.CAT.BRUT or cat == Pq.CAT.DECLASSE or cat == Pq.CAT.BASE" },
  { "discards : le declasse reste en poche", "return cat == Pq.CAT.BRUT or cat == Pq.CAT.DECLASSE", "return cat == Pq.CAT.BRUT" },
  { "grows : negatif permis", "  if u < 0 then u = 0 end\n", "" },
  { "grows : junk ignore", "local u = (used or 0) - (junk or 0)", "local u = (used or 0)" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUT) do
  local a, z = SRC:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif introuvable)"
  else
    local chunk = load(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(z + 1), "=mutant")
    local seen = false
    if chunk then
      local okc, mod = pcall(chunk)
      if okc then
        local okr, rr = pcall(run, mod)
        if not okr then seen = true else for _, r in ipairs(rr) do if not r[2] then seen = true break end end end
      else
        seen = true
      end
    else
      seen = true
    end
    if seen then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(string.format("mutants refuses %d/%d%s", refused, #MUT, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""), refused == #MUT)
print(string.format("[STOCK-QG] mutants refuses %d/%d", refused, #MUT))

---------------------------------------------------------------------------------------------------
-- Stock avec des coffres et des prototypes simulés
---------------------------------------------------------------------------------------------------
defines = { inventory = { chest = 1 } }
local STACK = { coal = 50, stone = 50, wood = 100, ["iron-ore"] = 50, ["iron-plate"] = 100, ["iron-gear-wheel"] = 100, ["copper-plate"] = 100,
  ["copper-cable"] = 200, ["electronic-circuit"] = 200, sulfur = 50, ["stone-furnace"] = 50, ["steel-furnace"] = 50, inserter = 50,
  ["firearm-magazine"] = 200, ["iron-chest"] = 50, ["wooden-chest"] = 50, ["stone-brick"] = 100, ["burner-mining-drill"] = 50 }
local function item(type_, place) return { type = type_ or "item", place_result = place and { name = place } or nil } end
local ITEMS = {}
for name, st in pairs(STACK) do ITEMS[name] = { stack_size = st, type = "item" } end
ITEMS["stone-furnace"].place_result = { name = "stone-furnace" }
ITEMS["steel-furnace"].place_result = { name = "steel-furnace" }
ITEMS.inserter.place_result = { name = "inserter" }
ITEMS["iron-chest"].place_result = { name = "iron-chest" }
ITEMS["wooden-chest"].place_result = { name = "wooden-chest" }
ITEMS["burner-mining-drill"].place_result = { name = "burner-mining-drill" }
ITEMS["firearm-magazine"].type = "ammo"
local function recipe(ins, outs, hidden)
  local r = { hidden = hidden or false, ingredients = {}, products = {} }
  for _, i in ipairs(ins) do r.ingredients[#r.ingredients + 1] = i == "water" and { type = "fluid", name = i, amount = 1 } or { type = "item", name = i, amount = 1 } end
  for _, o in ipairs(outs) do r.products[#r.products + 1] = { type = "item", name = o, amount = 1 } end
  return r
end
local RECIPES = {
  ["iron-plate"] = recipe({ "iron-ore" }, { "iron-plate" }), ["copper-plate"] = recipe({ "copper-ore" }, { "copper-plate" }),
  ["iron-gear-wheel"] = recipe({ "iron-plate" }, { "iron-gear-wheel" }), ["copper-cable"] = recipe({ "copper-plate" }, { "copper-cable" }),
  ["electronic-circuit"] = recipe({ "iron-plate", "copper-cable" }, { "electronic-circuit" }),
  sulfur = recipe({ "water" }, { "sulfur" }), ["stone-brick"] = recipe({ "stone" }, { "stone-brick" }),
  ["stone-furnace"] = recipe({ "stone" }, { "stone-furnace" }), ["steel-furnace"] = recipe({ "stone-brick", "iron-gear-wheel" }, { "steel-furnace" }),
  inserter = recipe({ "electronic-circuit", "iron-gear-wheel", "iron-plate" }, { "inserter" }),
  ["firearm-magazine"] = recipe({ "iron-plate" }, { "firearm-magazine" }), ["iron-chest"] = recipe({ "iron-plate" }, { "iron-chest" }),
  ["wooden-chest"] = recipe({ "wood" }, { "wooden-chest" }), ["burner-mining-drill"] = recipe({ "iron-gear-wheel", "stone-furnace" }, { "burner-mining-drill" }),
  hidden_dup = recipe({ "wood" }, { "iron-plate" }, true), -- une recette cachée n'entre pas dans le graphe
}
local ENTITIES = {
  ["stone-furnace"] = { fast_replaceable_group = "furnace", crafting_speed = 1 },
  ["steel-furnace"] = { fast_replaceable_group = "furnace", crafting_speed = 2 },
  ["burner-mining-drill"] = { fast_replaceable_group = "mining-drill", mining_speed = 0.35 },
  inserter = { fast_replaceable_group = "inserter" },
  ["iron-chest"] = {}, ["wooden-chest"] = {},
}
local RES, TREES = {}, {}
for _, n in ipairs({ "iron-ore", "copper-ore", "coal", "stone" }) do RES[n] = { mineable_properties = { products = { { type = "item", name = n } } } } end
TREES.tree = { mineable_properties = { products = { { type = "item", name = "wood" } } } }
local FORCE = { recipes = {} }
for rn in pairs(RECIPES) do FORCE.recipes[rn] = { enabled = true } end
FORCE.recipes["steel-furnace"].enabled = false
game = {
  tick = 0, item_prototypes = ITEMS, recipe_prototypes = RECIPES, entity_prototypes = ENTITIES, forces = { x = FORCE },
  get_filtered_entity_prototypes = function(filter) return filter[1].type == "resource" and RES or TREES end,
}
local logs = {}
function log(s) logs[#logs + 1] = s end
local function count_logs(pat)
  local n = 0
  for _, l in ipairs(logs) do if l:find(pat) then n = n + 1 end end
  return n
end

local function new_chest(size)
  local e = { valid = true, items = {}, size = size }
  local function slots()
    local n = 0
    for k, v in pairs(e.items) do n = n + math.ceil(v / (STACK[k] or 50)) end
    return n
  end
  local inv = {}
  setmetatable(inv, { __len = function() return size end })
  inv.count_empty_stacks = function() return size - slots() end
  inv.get_contents = function()
    local out = {}
    for k, v in pairs(e.items) do out[k] = v end
    return out
  end
  inv.remove = function(s) e.remove_item(s) end
  e.get_inventory = function() return inv end
  e.get_item_count = function(name) return e.items[name] or 0 end
  e.remove_item = function(s)
    local n = math.min(s.count, e.items[s.name] or 0)
    if n > 0 then e.items[s.name] = e.items[s.name] - n; if e.items[s.name] == 0 then e.items[s.name] = nil end end
    return n
  end
  e.insert = function(s)
    local stack = STACK[s.name] or 50
    local have = e.items[s.name] or 0
    local room = math.ceil(have / stack) * stack - have + (size - slots()) * stack
    local n = math.min(s.count, room)
    if n > 0 then e.items[s.name] = have + n end
    return n
  end
  return e
end

package.loaded["script.ai3.places_qg"] = {
  is_reserved = function() return false end, -- (lot TUILES-RESERVEES : crochet unique des tuiles réservées ; aucune ici)
  place = function() error("les annexes passent par place_list") end,
  place_list = function(surface, name, force, origin, list, search, count, make)
    local placed = 0
    for _, o in ipairs(list) do
      if placed >= count then break end
      local r = make({ x = origin.x + o[1], y = origin.y + o[2] })
      if r == nil then break end
      if r then placed = placed + 1 end
    end
    return placed
  end,
}
local Stock = require("script.team.stock")
local Pqs = require("script.team.plafond_qg")

local function team(size)
  return { key = "test", force = "x", hq = new_chest(size), hq_pos = { x = 0, y = 0 }, stats = {}, started = 0 }
end

-- catégories lues aux prototypes
do
  local f = team(100)
  check("prototypes : brut (minerai, pierre, charbon, bois)", Pqs.category(f, "coal") == "brut" and Pqs.category(f, "stone") == "brut"
    and Pqs.category(f, "wood") == "brut" and Pqs.category(f, "iron-ore") == "brut")
  check("prototypes : intermediaire de base (plaque, engrenage, cable, soufre, brique)", Pqs.category(f, "iron-plate") == "base"
    and Pqs.category(f, "iron-gear-wheel") == "base" and Pqs.category(f, "copper-cable") == "base" and Pqs.category(f, "sulfur") == "base"
    and Pqs.category(f, "stone-brick") == "base")
  check("prototypes : circuit (profondeur 3), inserteur, munition, coffres = finis", Pqs.category(f, "electronic-circuit") == "fini"
    and Pqs.category(f, "inserter") == "fini" and Pqs.category(f, "firearm-magazine") == "fini" and Pqs.category(f, "iron-chest") == "fini")
  check("prototypes : four de pierre fini tant que le meilleur four n'est pas fabricable", Pqs.category(f, "stone-furnace") == "fini")
  FORCE.recipes["steel-furnace"].enabled = true
  check("prototypes : le declassement est relu toutes les Pqs.OBS_EVERY ticks (pas avant)", Pqs.category(f, "stone-furnace") == "fini")
  game.tick = Pqs.OBS_EVERY + 1
  check("prototypes : four de pierre DECLASSE quand le four d'acier est fabricable", Pqs.category(f, "stone-furnace") == "declasse")
  check("prototypes : le four d'acier reste fini, la foreuse a feu (sans meilleur) aussi", Pqs.category(f, "steel-furnace") == "fini"
    and Pqs.category(f, "burner-mining-drill") == "fini")
  check("determinisme : le declassement est un etat de l'EQUIPE (sauvegarde), des noms et des nombres seulement",
    f.stock_obs ~= nil and type(f.stock_obs.at) == "number" and f.stock_obs.set["stone-furnace"] == true)
  FORCE.recipes["steel-furnace"].enabled = false
  game.tick = 2 * Pqs.OBS_EVERY + 5
  check("prototypes : redevient fini si le meilleur four n'est plus fabricable", Pqs.category(f, "stone-furnace") == "fini")
  FORCE.recipes["steel-furnace"].enabled = true
  game.tick = 3 * Pqs.OBS_EVERY + 10
end

-- ramassage : Stock.skip_fn
do
  local f = team(400)
  f.hq.items.coal = 450      -- plafond brut : 8 piles de 50 = 400
  f.hq.items.stone = 100
  f.hq.items["iron-plate"] = 4500 -- plafond de base : 40 piles de 100 = 4000
  f.hq.items["stone-furnace"] = 120 -- declasse : 2 piles de 50 = 100
  f.hq.items.inserter = 2000
  local n0 = count_logs("plafond de rapatriement")
  local skip = Stock.skip_fn(f)
  check("skip : un predicat quand un objet est au plafond", type(skip) == "function")
  check("skip : charbon au plafond refuse", skip("coal") == true)
  check("skip : pierre sous le plafond acceptee", skip("stone") == false)
  check("skip : plaques de fer au plafond de base refusees", skip("iron-plate") == true)
  check("skip : four de pierre declasse au plafond refuse", skip("stone-furnace") == true)
  check("skip : un objet fini n'est jamais refuse", skip("inserter") == false)
  check("skip : un objet absent du stock est accepte", skip("wood") == false)
  check("journal : l'ensemble au plafond est ecrit une fois", count_logs("plafond de rapatriement au QG") == n0 + 1)
  check("journal : il nomme l'objet, son compte, son plafond et sa categorie",
    logs[#logs]:find("coal 450/400 (brut)", 1, true) ~= nil and logs[#logs]:find("stone-furnace 120/100 (declasse)", 1, true) ~= nil
    and logs[#logs]:find("iron-plate 4500/4000 (base)", 1, true) ~= nil, logs[#logs])
  skip = Stock.skip_fn(f)
  check("skip : une seconde lecture dans la minute ne refait pas la ligne", count_logs("plafond de rapatriement au QG") == n0 + 1)
  check("mesure : les ramassages refuses par plafond sont comptes", f.stock_in and f.stock_in.skips.coal ~= nil)
  -- une demande
  f.team = { ia3 = { short = { coal = 1000, ["iron-plate"] = 1000, ["stone-furnace"] = 50 } } }
  game.tick = game.tick + 120
  skip = Stock.skip_fn(f)
  check("demande : un brut demande passe au-dessus de 400 (450 < 1600) : la fonderie du QG et les bruleurs ne sont pas affames", skip == nil or skip("coal") == false)
  f.hq.items.coal = 2000
  game.tick = game.tick + 120
  skip = Stock.skip_fn(f)
  check("demande : le brut reste plafonne meme demande (plafond dur a 1600)", skip and skip("coal") == true)
  check("demande : une base demandee passe malgre le plafond", skip and skip("iron-plate") == false)
  check("demande : un declasse demande passe malgre le plafond", skip and skip("stone-furnace") == false)
  -- sous les plafonds : plus de predicat
  local g = team(100)
  g.hq.items.coal = 300
  g.hq.items["iron-plate"] = 100
  check("skip : sous les plafonds, aucun predicat (comme avant)", Stock.skip_fn(g) == nil)
  -- le charbon a 399 passe, 400 est refuse
  g.hq.items.coal = 399
  game.tick = game.tick + 120
  check("skip : 399 charbons : accepte", Stock.skip_fn(g) == nil)
  g.hq.items.coal = 400
  game.tick = game.tick + 120
  local sk = Stock.skip_fn(g)
  check("skip : 400 charbons : refuse", sk ~= nil and sk("coal") == true)
  -- annexes comptees dans le stock
  local h = team(100)
  h.annex = { new_chest(32), new_chest(32) }
  h.hq.items.stone = 250
  h.annex[1].items.stone = 100
  h.annex[2].items.stone = 100
  game.tick = game.tick + 120
  local sh = Stock.skip_fn(h)
  check("skip : le plafond compte le QG ET les annexes (450 pierres)", sh ~= nil and sh("stone") == true)
end

-- dépôt d'un PNJ : place restante et retrait de la poche
do
  local f = team(400)
  f.hq.items.coal = 100
  f.hq.items["iron-plate"] = 9000
  f.hq.items["stone-furnace"] = 120
  game.tick = game.tick + Pqs.OBS_EVERY + 1
  check("cap_room : 100 charbons sur 400 : 300 de place", Stock.cap_room(f, "coal") == 300)
  f.hq.items.coal = 450
  check("cap_room : charbon au plafond : 0", Stock.cap_room(f, "coal") == 0)
  f.team = { ia3 = { short = { coal = 100 } } }
  check("cap_room : charbon demande : 1600 - 450 = 1150", Stock.cap_room(f, "coal") == 1150)
  f.team = nil
  check("cap_room : une base (plaques) ne se jette pas : nil", Stock.cap_room(f, "iron-plate") == nil)
  check("cap_room : un objet fini : nil", Stock.cap_room(f, "inserter") == nil)
  check("cap_room : le declasse (120 fours de pierre, plafond 100) : 0", Stock.cap_room(f, "stone-furnace") == 0)
  check("cap_room : sans coffre du QG : nil", Stock.cap_room({ key = "z", force = "x" }, "coal") == nil)
  local before = count_logs("retires de la poche au depot %(stock au plafond%) : {[^}]*wood 300")
  Stock.note_cap_drop(f, "wood", 300)
  Stock.note_cap_drop(f, "wood", 0)
  game.tick = game.tick + Pqs.LOG
  Stock.grow(f, { create_entity = function() return nil end }, game.tick)
  check("journal : ce qui est retire de la poche au depot est ecrit", count_logs("retires de la poche au depot %(stock au plafond%) : {[^}]*wood 300") == before + 1,
    logs[#logs])
end

-- agrandissement : jamais pour du brut ou du declasse
do
  local made = {}
  local surface = { create_entity = function(s) local e = new_chest(32); e.name = s.name; made[#made + 1] = e; return e end }
  game.tick = game.tick + 120
  local f = team(10)
  f.hq.items.coal = 50 * 9      -- 9 cases sur 10, tout du brut
  f.hq.items["iron-chest"] = 3  -- coffres en main
  check("annexe : un QG plein de charbon n'ouvre pas d'annexe", not Stock.grow(f, surface, 0) and #made == 0)
  check("annexe : ni coffre voulu pour du brut", Stock.wanted(f) == 0)
  check("annexe : ni coffre urgent pour du brut", Stock.urgent(f) == false)
  local g = team(10)
  g.hq.items["iron-plate"] = 100 * 9 -- 9 cases de plaques (base)
  g.hq.items["iron-chest"] = 3
  game.tick = game.tick + 120
  check("annexe : un QG plein de plaques (base) ouvre une annexe", Stock.grow(g, surface, 0) and #made == 1)
  local n_ann = count_logs("FO%-ANNEXE.*dont 0 de brut")
  check("journal : l'annexe dit combien de cases de brut et de declasse n'ont pas compte", n_ann == 1)
  local h = team(10)
  h.hq.items["stone-furnace"] = 50 * 4 -- 4 cases de fours declasses
  h.hq.items.coal = 50 * 3             -- 3 cases de charbon
  h.hq.items["iron-plate"] = 100 * 2   -- 2 cases utiles
  h.hq.items["iron-chest"] = 3
  game.tick = game.tick + 120
  check("annexe : 9 cases dont 7 de brut et de declasse = 2 utiles : pas d'annexe", not Stock.grow(h, surface, 0) and #made == 1)
  -- un depot refuse de brut ne declenche pas la pose anticipee
  local k = team(10)
  k.hq.items["iron-plate"] = 100 * 10
  check("refus : du charbon refuse ne note pas de refus", Stock.insert(k, "coal", 100) == 0 and k.refused_at == nil)
  check("refus : un objet fini refuse note le refus", Stock.insert(k, "inserter", 10) == 0 and k.refused_at ~= nil)
  local m = team(10)
  m.hq.items["iron-plate"] = 100 * 10
  m.hq.items["stone-furnace"] = 0
  check("refus : un four declasse refuse ne note pas de refus", (function()
    FORCE.recipes["steel-furnace"].enabled = true
    game.tick = game.tick + Pqs.OBS_EVERY + 1
    return Stock.insert(m, "stone-furnace", 10) == 0 and m.refused_at == nil
  end)())
end

-- mesure : ce qui entre au stock
do
  local surface = { create_entity = function() return nil end }
  game.tick = game.tick + Pqs.OBS_EVERY + 1
  local f = team(100)
  f.started = 0
  check("mesure : un depot de charbon est compte", Stock.insert(f, "coal", 200) == 200 and f.stock_in ~= nil)
  Stock.insert(f, "coal", 100)
  Stock.insert(f, "stone", 40)
  Stock.insert(f, "inserter", 10)
  local seen_inserter, key_coal = false, nil
  for k, n in pairs(f.stock_in.by) do
    if k:find("^inserter") then seen_inserter = true end
    if k:find("^coal|brut|") then key_coal = k end
  end
  check("mesure : un objet fini n'est pas compte", not seen_inserter)
  check("mesure : l'appelant est nomme (fichier et ligne)", key_coal ~= nil and key_coal:find("plafond_qg_test.lua:%d+") ~= nil, key_coal)
  local before = count_logs("entrees au stock hors objets finis")
  game.tick = game.tick + Pqs.LOG
  Stock.grow(f, surface, game.tick)
  check("mesure : une ligne par fenetre", count_logs("entrees au stock hors objets finis") == before + 1)
  local line = logs[#logs]
  check("mesure : la ligne donne le brut, le total et l'appelant", line:find("coal (brut) 300 via", 1, true) ~= nil
    and line:find("stone (brut) 40", 1, true) ~= nil and line:find("plafond_qg_test.lua", 1, true) ~= nil, line)
  check("mesure : la fenetre repart a zero", f.stock_in == nil)
  Stock.grow(f, surface, game.tick + 10)
  check("mesure : rien a ecrire sans entree", count_logs("entrees au stock hors objets finis") == before + 1)
end

print(string.format("[STOCK-QG] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
