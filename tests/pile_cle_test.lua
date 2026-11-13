--[[
  Lot RUINES-ATTENTE : la fabrication qui refait l'EXTRACTION de la plaque clé est payée AVANT le plan permanent.
  Partie neuve 20261020 : [FO-PILE] « craft de pile : foreuse x3 à x24, parties 0, manque fer » pendant 25 min, alors que le coffre tient du fer :
  shared/ai3/cerveau.lua retirait au stock les consommations du plan permanent (tourelles, munitions, fonds de défense, recrues) avant de passer
  les crafts de réparation. Règle : shared/ai3/pile.lua (4e champ des crafts : r.key_extraction) + shared/ai3/cerveau.lua (paiement avant `used`).
  Lancement, depuis la racine du mod :   lua5.2 tests/pile_cle_test.lua
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Book = require("shared.team.book")
local S = require("shared.team.scale")

local book = Book.new(dofile("tests/fixtures/recipes.lua"))
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end

local IRON, ORE = T.outposts.iron.product, T.outposts.iron.resource
local ITEM = "burner-mining-drill"

local function load_all(mut_cerveau)
  for _, m in ipairs({ "shared.ai3.pile", "shared.ai3.buts", "shared.ai3.cerveau" }) do package.loaded[m] = nil end
  if mut_cerveau then
    local fh = assert(io.open("shared/ai3/cerveau.lua", "rb"))
    local src = fh:read("*a")
    fh:close()
    src = mut_cerveau(src)
    package.loaded["shared.ai3.cerveau"] = assert(load(src, "=cerveau_mute"))()
  end
  return require("shared.ai3.pile"), require("shared.ai3.buts"), require("shared.ai3.cerveau")
end

local function view(over)
  local v = {
    tech = 0, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {}, outposts = {},
    pending = {}, sites = {}, smelters = 2, smelters_pending = 0, smelter_task = false, smelter_output = 0,
    smelter_fuel_low = false, smelter_coal = 0, turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 10,
    workers_max = 30, workers_idle = 2, threatened = false, open = {}, workers_wanted = 10, no_research = true,
    ladder = T.player_ladder, hq_turrets = 0, defend_first = true, is_player = true,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end

-- Le QG est à 0 tourelle : le plan permanent consomme le fer (tourelles) avant les projets ; 80 fer (balayage : sans la règle, la foreuse n'est pas lancée).
local function think(C, B, key_flag, mut)
  local stock = { [IRON] = 80, stone = 300, [T.fuel] = 400, ["copper-plate"] = 200 }
  local st = C.new_state(0)
  st.targets = { iron = 1, coal = 1, copper = 1, stone = 0 }
  st.iron2_set = true
  local ctx = { tick = 0, is_player = true, weights = B.weights({}, nil), reach = { [ORE] = 60, [T.fuel] = 60 },
    pile = { repair = {
      { key = "d1", item = ITEM, value = 3, prio = 75, have = 0, craftable = true, key_extraction = key_flag },
    } } }
  local plan = C.think(view({ stock = stock }), book, st, ctx)
  local n, count = 0, 0
  for _, t in ipairs(plan.tasks) do if t.kind == "craft" and t.item == ITEM and tostring(t.key):find(":pile:", 1, true) then n = n + 1 count = count + (t.count or 0) end end
  return n, count, st, plan
end

local Pi, B, C = load_all()

-- 1. règle pure : le 4e champ n'existe que pour les pièces marquées, au nombre réel
local sig = { sources = {}, inputs = {}, raw_need = {}, posts = {}, repair = {
  { key = "a", item = ITEM, value = 3, prio = 75, have = 0, craftable = true, key_extraction = true },
  { key = "b", item = ITEM, value = 3, prio = 75, have = 0, craftable = true, key_extraction = true },
  { key = "c", item = ITEM, value = 3, prio = 75, have = 0, craftable = true },
  { key = "d", item = "iron-chest", value = 1, prio = 40, have = 0, craftable = true },
} }
local st = Pi.update(Pi.new(), sig, 0)
local cr = {}
for _, c in ipairs(st.crafts) do cr[#cr + 1] = c end
local keyed, plain = 0, 0
for _, c in ipairs(cr) do
  if c[1] == ITEM and c[4] then keyed = keyed + c[2] elseif c[1] == ITEM then plain = plain + c[2] end
end
check(keyed == 2 and plain == 1, "foreuses : 2 marquées (extraction de la plaque clé), 1 ordinaire (" .. keyed .. " / " .. plain .. ")")
for _, c in ipairs(cr) do if c[1] == "iron-chest" then check(not c[4], "le coffre n'est pas marqué") end end
local sig2 = { sources = {}, inputs = {}, raw_need = {}, posts = {}, repair = {
  { key = "a", item = ITEM, value = 3, prio = 75, have = 1, craftable = true, key_extraction = true } } }
local st2 = Pi.update(Pi.new(), sig2, 0)
check(#st2.crafts == 0, "l'objet est au stock : rien à fabriquer (au manque réel)")

-- 2. cerveau : sans marque, le plan permanent a pris le fer d'abord (défaut reproduit) ; avec la marque, la fabrication part
local n0 = think(C, B, nil)
local n1, c1 = think(C, B, true)
check(n1 >= 1 and c1 >= 1, "marquée : la fabrication de la foreuse part (" .. n1 .. " tâche(s), " .. c1 .. " objet(s))")
check(n0 == 0, "sans marque (défaut reproduit) : le plan permanent a pris le fer, la foreuse n'est pas lancée (" .. n0 .. ")")

-- 3. mutants : sans le paiement avant `used`, la marque ne change plus rien
local function mutant(f)
  local P2, B2, C2 = load_all(f)
  local a = think(C2, B2, true)
  load_all()
  return a
end
local m1 = mutant(function(src) return (src:gsub("if it%[4%] then", "if false then")) end)
check(m1 == 0, "mutant « la marque est ignorée » : retombe au défaut (" .. m1 .. ")")
-- 4. (s40 decision p1) deux fabrications clés d'objets différents ne paient pas la même plaque : le fer pris par les tâches de la pile tient au coffre
local ITEM2 = "iron-chest"
local function think2(C3, B3, iron)
  local stock = { [IRON] = iron, stone = 300, [T.fuel] = 400, ["copper-plate"] = 200 }
  local st3 = C3.new_state(0)
  st3.targets = { iron = 1, coal = 1, copper = 1, stone = 0 }
  st3.iron2_set = true
  local ctx = { tick = 0, is_player = true, weights = B3.weights({}, nil), reach = { [ORE] = 60, [T.fuel] = 60 },
    pile = { repair = {
      { key = "d1", item = ITEM, value = 3, prio = 75, have = 0, craftable = true, key_extraction = true },
      { key = "d2", item = ITEM2, value = 3, prio = 75, have = 0, craftable = true, key_extraction = true },
    } } }
  local plan = C3.think(view({ stock = stock }), book, st3, ctx)
  local iron_used, n = 0, 0
  for _, t in ipairs(plan.tasks) do
    if t.kind == "craft" and tostring(t.key):find(":pile:", 1, true) then
      n = n + 1
      for _, u in ipairs(t.uses or {}) do if u[1] == IRON then iron_used = iron_used + u[2] end end
    end
  end
  return iron_used, n
end
local cost1 = book:raw_cost({ { ITEM, 1 } })[IRON] or 0
local cost2 = book:raw_cost({ { ITEM2, 1 } })[IRON] or 0
local tight = math.max(cost1, cost2) -- paie l'un des deux, jamais les deux
check(cost1 > 0 and cost2 > 0, "les deux objets coûtent du fer (" .. cost1 .. " / " .. cost2 .. ")")
local u_t, n_t = think2(C, B, tight)
check(n_t >= 1 and u_t <= tight, "coffre à " .. tight .. " fer : les fabrications clés ne prennent pas plus que le coffre (" .. u_t .. " fer, " .. n_t .. " tâche(s))")
local u_w, n_w = think2(C, B, cost1 + cost2)
check(n_w == 2 and u_w == cost1 + cost2, "coffre à " .. (cost1 + cost2) .. " fer : les deux partent (" .. u_w .. " fer, " .. n_w .. " tâche(s))")
print(string.format("[PILE-CLE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
