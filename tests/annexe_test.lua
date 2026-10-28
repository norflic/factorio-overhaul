--[[
  Lot COFFRE : annexes du QG (shared/team/annexe.lua, règles pures ; script/team/stock.lua avec des coffres simulés).
    - le stock est le coffre du QG ET ses annexes : lecture, prise, dépôt, contenu, inventaires ;
    - le rangement ne déplace que des piles entières, les plus grosses d'abord, en laissant une pile au QG ;
    - un coffre se pose quand les cases se remplissent, jamais au-delà du maximum, pas quand il y a de la place ;
    - sans annexe : exactement le coffre du QG d'avant.
  Lancement : lua5.2 tests/annexe_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local A = require("shared.team.annexe")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

---------------------------------------------------------------------------------------------------
section("Règles pures")
check(A.fill(48, 96) == 0.5 and A.fill(0, 0) == 1, "remplissage")
check(not A.need_chest(60, 96, 0) and A.need_chest(68, 96, 0), "un coffre se pose à " .. T.annex.grow_at .. " de remplissage")
check(not A.need_chest(96, 96, T.annex.max), "jamais au-delà du maximum d'annexes")
check(A.wanted(60, 96, 0, 0) == 0 and A.wanted(90, 96, 0, 0) == T.annex.want and A.wanted(90, 96, 0, 1) == T.annex.want - 1
  and A.wanted(90, 96, 0, 5) == 0, "coffres demandés : rien sous le seuil, puis T.annex.want moins ceux en main")
local stack_of = { coal = 50, ["copper-plate"] = 100, wood = 100, ["firearm-magazine"] = 200, ["stone-furnace"] = 50 }
local c = { coal = 1816, ["copper-plate"] = 1521, wood = 1352, ["firearm-magazine"] = 200, ["stone-furnace"] = 30, ["unknown"] = 7 }
check(#A.park_plan(c, stack_of, 96, 70, 100) == 0, "sous le seuil de rangement : rien")
check(#A.park_plan(c, stack_of, 96, 90, 0) == 0, "aucune place aux annexes : rien")
local plan = A.park_plan(c, stack_of, 96, 90, 100)
local freed, ok_whole = 0, true
for _, m in ipairs(plan) do
  local stack = stack_of[m[1]] or 1
  if m[2] % stack ~= 0 then ok_whole = false end
  freed = freed + m[2] / stack
end
check(ok_whole, "piles entières seulement")
check(plan[1][1] == "coal", "le plus grand preneur de cases d'abord (" .. tostring(plan[1][1]) .. ")")
check(freed == 90 - math.floor(T.annex.park_to * 96), "libère exactement ce qu'il faut pour revenir à " .. T.annex.park_to .. " (" .. freed .. ")")
for _, m in ipairs(plan) do
  check(c[m[1]] - m[2] >= (stack_of[m[1]] or 1) * T.annex.keep, "une pile au moins reste au QG (" .. m[1] .. ")")
end
local plan2 = A.park_plan(c, stack_of, 96, 90, 5)
local f2 = 0
for _, m in ipairs(plan2) do f2 = f2 + m[2] / stack_of[m[1]] end
check(f2 == 5, "limité aux cases libres des annexes (" .. f2 .. ")")
local pa, pb = A.park_plan(c, stack_of, 96, 90, 100), A.park_plan(c, stack_of, 96, 90, 100)
local sa, sb = {}, {}
for i, m in ipairs(pa) do sa[i] = m[1] .. m[2] end
for i, m in ipairs(pb) do sb[i] = m[1] .. m[2] end
check(table.concat(sa, ",") == table.concat(sb, ","), "déterminisme")

---------------------------------------------------------------------------------------------------
section("Stock avec des coffres simulés")
defines = { inventory = { chest = 1 } }
local STACK = stack_of
game = { item_prototypes = setmetatable({}, { __index = function(_, k) return { stack_size = STACK[k] or 50 } end }) }
local logs = {}
function log(s) logs[#logs + 1] = s end

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
    local free_in_stacks = 0
    local have = e.items[s.name] or 0
    free_in_stacks = math.ceil(have / stack) * stack - have
    local room = free_in_stacks + (size - slots()) * stack
    local n = math.min(s.count, room)
    if n > 0 then e.items[s.name] = have + n end
    return n
  end
  return e
end

package.loaded["script.ai3.places_qg"] = {
  place = function(surface, name, force, origin, spec, need, count, make)
    local placed = 0
    for i = 1, need do
      if placed >= count then break end
      local r = make({ x = i, y = 0 })
      if r == nil then break end
      if r then placed = placed + 1 end
    end
    return placed
  end,
}
local Stock = require("script.team.stock")

local function team(size)
  return { key = "test", force = "x", hq = new_chest(size), hq_pos = { x = 0, y = 0 }, stats = {}, started = 0 }
end

do
  -- Sans annexe : exactement le coffre du QG.
  local f = team(10)
  f.hq.items.coal = 120
  check(Stock.count(f, "coal") == 120 and Stock.remove(f, "coal", 20) == 20 and Stock.count(f, "coal") == 100, "sans annexe : le coffre")
  check(Stock.insert(f, "coal", 450) == 400 and Stock.count(f, "coal") == 500, "dépôt : au plus la place du coffre")
  check(Stock.balance(f) == 0 and #Stock.inventories(f) == 1, "sans annexe : rien à ranger")
end
do
  local f = team(10)
  local a1, a2 = new_chest(10), new_chest(10)
  f.annex = { a1, a2 }
  f.hq.items.coal = 450 -- 9 cases sur 10
  f.hq.items["copper-plate"] = 100 -- 1 case : plein
  check(Stock.insert(f, "coal", 50) == 50, "QG plein : le dépôt passe à l'annexe")
  check(a1.items.coal == 50 and f.hq.items.coal == 450, "dépôt dans la première annexe")
  check(Stock.count(f, "coal") == 500, "le stock compte le QG et les annexes")
  local all = Stock.contents(f)
  check(all.coal == 500 and all["copper-plate"] == 100, "contenu réuni")
  check(#Stock.inventories(f) == 3, "inventaires : QG et annexes")
  check(Stock.remove(f, "coal", 480) == 480 and Stock.count(f, "coal") == 20, "prise : le QG d'abord puis les annexes")
  check(Stock.remove(f, "coal", 100) == 20, "prise : au plus ce qu'il y a")
  a2.valid = false
  check(#Stock.annexes(f) == 1 and #f.annex == 1, "annexe détruite : retirée de la liste")
end
do
  -- Rangement : le QG plein envoie ses grosses piles aux annexes, jusqu'au seuil bas.
  local f = team(20)
  local a1 = new_chest(20)
  f.annex = { a1 }
  f.hq.items.coal = 50 * 8
  f.hq.items.wood = 100 * 6
  f.hq.items["copper-plate"] = 100 * 3
  f.hq.items["firearm-magazine"] = 200 * 2 -- 19 cases sur 20
  local before = Stock.count(f, "coal") + Stock.count(f, "wood")
  local moved = Stock.balance(f)
  local inv = f.hq.get_inventory()
  local used = 20 - inv.count_empty_stacks()
  check(moved > 0 and used <= math.floor(T.annex.park_to * 20) + 0, "rangé : le QG revient à " .. used .. " cases sur 20")
  check(Stock.count(f, "coal") + Stock.count(f, "wood") == before, "rien de perdu ni de créé au rangement")
  check(f.hq.items.coal >= 50 and f.hq.items.wood >= 100, "une pile au moins de chaque reste au QG")
  check(Stock.balance(f) == 0, "sous le seuil : plus rien à ranger")
  check(f.stats.annex_parked == moved, "mesure : objets rangés")
end
do
  -- Pose d'un coffre : seulement quand les cases se remplissent, avec un coffre en main.
  local made = {}
  local surface = { create_entity = function(s) local e = new_chest(32); e.name = s.name; made[#made + 1] = e; return e end }
  local f = team(10)
  f.hq.items.coal = 50 * 3
  check(not Stock.grow(f, surface, 0), "30 % de remplissage : aucun coffre")
  f.hq.items.coal = 50 * 9
  check(not Stock.grow(f, surface, 0) and #made == 0, "plein sans coffre en main : rien posé")
  check(Stock.wanted(f) == T.annex.want, "plein sans coffre : on en demande " .. T.annex.want)
  f.hq.items["iron-chest"] = 3
  check(Stock.wanted(f) == 0, "coffres en main : on n'en redemande pas")
  check(Stock.grow(f, surface, 3600) and #made == 1 and made[1].name == "iron-chest", "plein avec un coffre : posé")
  check(#f.annex == 1 and f.hq.items["iron-chest"] == 2, "le coffre posé sort du stock et entre dans les annexes")
  check(#logs == 1 and logs[1]:find("FO%-ANNEXE"), "journal [FO-ANNEXE]")
  -- 9 cases + 0 sur 42 : 21 % : plus de pose
  check(not Stock.grow(f, surface, 3700), "le total QG + annexes a de la place : plus de pose")
  local g = team(10)
  g.hq.items.coal = 50 * 9
  g.hq.items["wooden-chest"] = 1
  check(Stock.grow(g, surface, 0) and made[#made].name == "wooden-chest", "à défaut de coffre de fer, un coffre de bois")
  local h = team(10)
  h.hq.items.coal = 50 * 10
  h.annex = {}
  for i = 1, T.annex.max do h.annex[i] = new_chest(0) end
  h.hq.items["iron-chest"] = 1
  check(not Stock.grow(h, surface, 0), "maximum d'annexes atteint : plus de pose")
end

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
