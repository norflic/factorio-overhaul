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

local last_search
package.loaded["script.ai3.places_qg"] = {
  place = function() error("les annexes passent par place_list") end,
  -- Moteur simulé : essaie les places de la liste dans l'ordre (comme le vrai), sans passe de secours quand search est nul.
  place_list = function(surface, name, force, origin, list, search, count, make)
    last_search = search
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

local function team(size)
  return { key = "test", force = "x", hq = new_chest(size), hq_pos = { x = 0, y = 0 }, stats = {}, started = 0 }
end

do
  -- Sans annexe : exactement le coffre du QG.
  local f = team(10)
  f.hq.items.coal = 120
  check(Stock.count(f, "coal") == 120 and Stock.remove(f, "coal", 20) == 20 and Stock.count(f, "coal") == 100, "sans annexe : le coffre")
  -- Lot STOCKAGE (essai 2) : le refus n'est plus perdu : 400 entrent, 50 ATTENDENT (f.stock_pending) ; Stock.insert rend tout accepté.
  check(Stock.insert(f, "coal", 450) == 450 and Stock.count(f, "coal") == 500 and Stock.pending(f) == 50,
    "dépôt : le coffre prend sa place, le reste attend (ni perdu ni au sol)")
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
  -- Lot STOCKAGE (essai 2) : le bloc plein n'arrête plus le stock : un anneau de plus s'ouvre et le coffre y est posé.
  check(Stock.grow(h, surface, 0) and h.annex_rings == 2 and #h.annex == T.annex.max + 1, "bloc plein (48) : anneau 2 ouvert, coffre posé")
  check(logs[#logs]:find("FO%-ANNEXE") and logs[#logs - 1]:find("FO%-STOCKAGE") and logs[#logs - 1]:find("anneau 2"), "journal [FO-STOCKAGE] anneau 2")
end

---------------------------------------------------------------------------------------------------
section("Lot STOCKAGE : règles pures (bloc, fenêtre, plafond)")
do
  -- Bloc des annexes : 48 places au sud, 32 au nord, toutes dans le lot (0, 0) du treillis (demi-côté 12), distinctes, de la
  -- plus proche à la plus lointaine, jamais au contact du QG (near).
  local S, N = A.slots(1, 1, 1), A.slots(-1, 1, 1)
  local B = T.annex.block
  check(#S == 48 and #N == 32 and T.annex.max == #S, "places du bloc : 48 au sud (= T.annex.max), 32 au nord")
  check(A.capacity(1, 1, 1) == 48 and A.capacity(-1, 1, 1) == 32, "capacité = nombre de places")
  local seen, inside, sorted = {}, true, true
  local prev
  for _, p in ipairs(S) do
    local k = p[1] .. ":" .. p[2]
    check(not seen[k], "place unique " .. k)
    seen[k] = true
    if math.abs(p[1]) > B.half_south or p[2] < B.near or p[2] > B.far then inside = false end
    local d = p[1] * p[1] + p[2] * p[2]
    if prev and d < prev then sorted = false end
    prev = d
  end
  local outward = true
  for _, p in ipairs(N) do
    if p[2] > -B.near or p[2] < -B.far or math.abs(p[1]) > B.half_north then outward = false end
  end
  check(inside, "le bloc sud reste dans le lot du QG (colonnes -11..11, rangées 5..11)")
  check(sorted, "du plus proche du QG au plus lointain (le bloc grandit vers l'extérieur)")
  check(outward, "le bloc nord est au nord, hors des fours (est) et des laboratoires (ouest)")
  check(#A.slots(1, 2, 2) > 0 and #A.slots(1, 2, 2) < #S, "un coffre plus grand : moins de places")
  check(A.outward(-40) == -1 and A.outward(40) == 1 and A.outward(0) == 1 and A.outward(nil) == 1, "face extérieure selon l'origine de la carte")
  -- Fenêtre : 60 % pendant 5 min, une baisse brève ne la relance pas, sous 55 % elle se ferme.
  local st = {}
  A.watch(st, 40, 96, 0)
  check(st.since == nil and not A.early_due(st, 99999), "42 % : pas de fenêtre")
  A.watch(st, 58, 96, 1000)
  check(st.since == 1000 and not A.early_due(st, 1000 + T.annex.early_ticks - 1), "60 % : la fenêtre s'ouvre, pas encore due")
  check(A.early_due(st, 1000 + T.annex.early_ticks), "60 % pendant 5 min : un coffre de plus")
  A.watch(st, 55, 96, 2000)
  check(st.since == 1000, "57 % (entre 55 et 60) : la fenêtre n'est pas relancée")
  A.watch(st, 50, 96, 3000)
  check(st.since == nil, "52 % : la fenêtre se ferme")
  A.watch(st, 0, 0, 3000)
  check(st.since == nil, "capacité inconnue : pas de fenêtre")
  check(A.early_due(nil, 5000, 4000) and not A.early_due(nil, 4000 + T.annex.refused_ticks + 1, 4000)
    and not A.early_due(nil, 3000, 4000), "dépôt refusé : anticipation pendant T.annex.refused_ticks seulement")
  check(not A.early_due({ placed_at = 4500 }, 5000, 4000), "juste après une pose : un refus ne redéclenche pas")
  local later = 4500 + T.annex.refused_ticks
  check(A.early_due({ placed_at = 4500 }, later, later - 10), "une minute après la pose : un refus redéclenche")
  check(A.need_chest(70, 100, 0, false) and not A.need_chest(65, 100, 0, false) and A.need_chest(65, 100, 0, true),
    "70 % : posé ; 65 % : seulement par anticipation")
  check(not A.need_chest(65, 100, 32, true, 32) and A.need_chest(65, 100, 32, true, 48), "plafond = capacité du bloc, anticipation comprise")
  check(A.wanted(65, 100, 0, 0, true) == T.annex.want and A.wanted(65, 100, 0, 0, false) == 0 and A.wanted(65, 100, 48, 0, true, 48) == 0,
    "coffres demandés par anticipation, jamais au plafond")
end

section("Lot STOCKAGE : Stock.grow avec des coffres simulés")
do
  local pos = {}
  local surface = { create_entity = function(s) local e = new_chest(32); e.name = s.name; pos[#pos + 1] = s.position; return e end }
  game.tick = 0
  -- Partie d'avant (annexes déjà posées) : face SUD gardée, même à y < 0.
  local f = team(10)
  f.hq_pos = { x = 0, y = -80 }
  f.annex = { new_chest(10) }
  Stock.grow(f, surface, 100)
  check(f.annex_sy == 1, "annexes déjà là : la face sud est gardée (migration)")
  -- QG neuf au nord de l'origine : bloc au nord ; 60 % pendant 5 min, sans arriver à 70 %.
  local g = team(10)
  g.hq_pos = { x = 0, y = -80 }
  g.hq.items.coal = 50 * 5
  g.hq.items["wooden-chest"] = 2 -- 6 cases sur 10 : 60 %
  check(not Stock.grow(g, surface, 1000) and g.annex_sy == -1, "QG au nord : bloc au nord")
  check(not Stock.grow(g, surface, 1000 + T.annex.early_ticks - 1), "avant 5 min : rien posé")
  check(Stock.grow(g, surface, 1000 + T.annex.early_ticks) and #g.annex == 1, "après 5 min à 60 % : un coffre posé par anticipation")
  check(pos[#pos].y < g.hq_pos.y and last_search == 0, "posé au nord du QG (extérieur), sans passe de secours")
  check(g.stock_watch.since == 1000 + T.annex.early_ticks and g.stock_watch.placed_at == g.stock_watch.since, "la fenêtre repart à la pose")
  check(not Stock.grow(g, surface, 1000 + T.annex.early_ticks + 1), "pas de seconde pose aussitôt")
  -- Position du QG pas encore connue : la face n'est pas figée au sud pour toujours.
  local u = team(10)
  u.hq_pos = nil
  check(Stock.wanted(u) >= 0 and u.annex_sy == nil, "sans position du QG : face non figée")
  u.hq_pos = { x = 0, y = -80 }
  Stock.wanted(u)
  check(u.annex_sy == -1, "position connue ensuite : face de l'extérieur (nord)")
  -- Dépôt refusé : un coffre sans attendre.
  local h = team(10)
  h.hq.items.coal = 50 * 9
  h.hq.items["wooden-chest"] = 1
  game.tick = 500
  check(Stock.insert(h, "coal", 500) == 500 and h.refused_at == 500 and Stock.pending(h) == 500, "dépôt refusé : noté, tout attend")
  check(Stock.wanted(h) == T.annex.want - 1, "un coffre en main : le fond en demande un de moins")
  check(Stock.grow(h, surface, 600) and #h.annex == 1 and h.refused_at == nil, "refus : coffre posé, refus consommé")
  local k = team(10)
  k.hq.items.coal = 50 * 10
  check(Stock.insert(k, "coal", 50) == 50 and Stock.wanted(k) == T.annex.want, "refus sans coffre en main : le fond en fabrique")
  -- Plan directeur : une place réservée est sautée ; sans place libre on réessaie plus tard.
  local r = team(10)
  r.hq.items.coal = 50 * 9
  r.hq.items["iron-chest"] = 1
  Stock.reserved = function() return true end
  check(not Stock.grow(r, surface, 0) and r.stock_watch.retry == T.annex.retry and #(r.annex or {}) == 0,
    "toutes les places réservées : rien posé, nouvel essai plus tard")
  Stock.reserved = function(_, _, p) return p.x < 0 end
  check(not Stock.grow(r, surface, T.annex.retry - 1), "attente après un échec de pose")
  check(Stock.grow(r, surface, T.annex.retry) and #r.annex == 1 and pos[#pos].x >= 0, "après l'attente : posé sur une place non réservée")
  Stock.reserved = nil
  -- Coffre réclamé par le plan directeur : pas posé en annexe.
  local d = team(10)
  d.hq.items.coal = 50 * 9
  d.hq.items["iron-chest"] = 1
  Stock.demand = function(_, item) return item == "iron-chest" and 1 or 0 end
  check(not Stock.grow(d, surface, 0) and Stock.wanted(d) == T.annex.want, "coffre déjà réclamé par le plan : ni posé ni compté en main")
  Stock.demand = nil
  game.tick = nil
end

section("Lot STOCKAGE (essai 2) : amélioration au même endroit, contenu gardé ; objets en attente ; borne des anneaux")
do
  local Sg = require("shared.team.stockage")
  game.tick = 0
  local function sum(f, names)
    local n = 0
    for _, k in ipairs(names) do n = n + Stock.count(f, k) end
    return n
  end
  local function named(size, name, x, y)
    local e = new_chest(size)
    e.name, e.position = name, { x = x, y = y }
    e.destroy = function() e.valid = false end
    return e
  end
  -- Bloc plein de 48 coffres en FER, chacun garni ; le QG plein ; un coffre en ACIER en main.
  local function full_iron_team()
    local f = team(10)
    f.hq.items.coal = 50 * 9
    f.hq.items["steel-chest"] = 1
    f.annex = {}
    for i = 1, T.annex.max do
      local a = named(32, "iron-chest", i, 7)
      a.items.wood = 100 * 30 -- 30 cases sur 32
      f.annex[i] = a
    end
    return f
  end
  -- (a) moteur qui remplace (fast_replace, F39) : l'ancien coffre disparaît, son contenu passe au nouveau.
  local f = full_iron_team()
  local wood0, chests0 = sum(f, { "wood" }), #f.annex
  local fr = 0
  local surf_fr = { create_entity = function(s)
    local e = named(48, s.name, s.position.x, s.position.y)
    if s.fast_replace then
      for _, o in ipairs(f.annex) do
        if o.valid and o.position.x == s.position.x and o.position.y == s.position.y then
          for k, v in pairs(o.items) do e.items[k] = v end
          o.items, o.valid = {}, false
          fr = fr + 1
        end
      end
    end
    return e
  end }
  check(Stock.grow(f, surf_fr, 0), "bloc plein de fer, acier en main : une action")
  check(fr == 1 and #Stock.annexes(f) == chests0, "un coffre en fer REMPLACÉ en acier à la même place (fast_replace), même nombre d'annexes")
  check(sum(f, { "wood" }) == wood0, "contenu GARDÉ : " .. sum(f, { "wood" }) .. " bois après, " .. wood0 .. " avant")
  check(Stock.count(f, "steel-chest") == 0 and Stock.count(f, "iron-chest") >= 1, "l'acier sort du stock, le coffre en fer retiré y revient")
  check(logs[#logs]:find("FO%-STOCKAGE") and logs[#logs]:find("ameliore"), "journal [FO-STOCKAGE] amélioration")
  -- (b) moteur qui ne remplace pas : transfert à la main, l'ancien retiré seulement vide.
  local g = full_iron_team()
  local wood1 = sum(g, { "wood" })
  local surf_plain = { create_entity = function(s) return named(48, s.name, s.position.x, s.position.y) end }
  check(Stock.grow(g, surf_plain, 0), "sans remplacement par le moteur : une action")
  check(sum(g, { "wood" }) == wood1, "contenu GARDÉ par transfert : " .. sum(g, { "wood" }) .. " sur " .. wood1)
  check(#Stock.annexes(g) == T.annex.max, "l'ancien, vidé, est retiré ; le nouveau prend sa place dans la liste")
  -- (c) objets en attente : un dépôt refusé attend, puis entre dès qu'un coffre est posé.
  local h = team(10)
  h.hq.items.coal = 50 * 10
  h.hq.items["iron-chest"] = 0
  game.tick = 100
  check(Stock.insert(h, "stone", 120) == 120 and Stock.pending(h) == 120 and Stock.count(h, "stone") == 0, "stock plein : 120 pierres en attente")
  h.hq.items.coal = 50 * 9 -- une case libérée (une prise), un coffre en main
  h.hq.items["iron-chest"] = 1
  local surf_new = { create_entity = function(s) return named(32, s.name, s.position.x, s.position.y) end }
  Stock.grow(h, surf_new, 200)
  check(Stock.pending(h) == 0 and Stock.count(h, "stone") == 120, "à la pensée suivante, les 120 pierres sont au stock (" .. Stock.pending(h) .. " en attente)")
  -- (d) borne : 5 anneaux pleins de coffres en acier, coffres en fer en main : rien, et le journal le dit UNE fois.
  local b = team(10)
  b.hq.items.coal = 50 * 9
  b.hq.items["iron-chest"] = 5
  b.annex_rings = Sg.MAX_RINGS
  b.annex = {}
  for i = 1, Sg.capacity(1, 1, 1, Sg.MAX_RINGS) do b.annex[i] = named(1, "steel-chest", i, 99) end
  for _, a in ipairs(b.annex) do a.items.wood = 100 end
  local nlogs = #logs
  check(not Stock.grow(b, surf_new, 300), "borne atteinte : rien posé")
  local said = 0
  for i = nlogs + 1, #logs do if logs[i]:find("FO%-STOCKAGE") and logs[i]:find("BORNE") then said = said + 1 end end
  b.stock_watch.retry = nil
  Stock.grow(b, surf_new, 300 + T.annex.retry)
  for i = nlogs + 1, #logs do if logs[i]:find("BORNE") then said = said + (i > nlogs + 1 and 0 or 0) end end
  local total = 0
  for i = nlogs + 1, #logs do if logs[i]:find("BORNE") then total = total + 1 end end
  check(said == 1 and total == 1, "journal [FO-STOCKAGE] BORNE écrit une seule fois (" .. total .. ")")
  -- (e) à la borne, l'attente grossit : ALERTE au journal au-delà de 1 000 objets, une fois par dépassement, réarmée sous le seuil.
  local function alerts(from)
    local a = 0
    for i = from + 1, #logs do if logs[i]:find("FO%-STOCKAGE") and logs[i]:find("ALERTE") then a = a + 1 end end
    return a
  end
  local n0 = #logs
  Stock.insert(b, "stone", 1500)
  b.stock_watch.retry = nil
  Stock.grow(b, surf_new, 400 + 2 * T.annex.retry)
  b.stock_watch.retry = nil
  Stock.grow(b, surf_new, 400 + 3 * T.annex.retry)
  check(Stock.pending(b) == 1500 and alerts(n0) == 1, "1 500 objets en attente : une ALERTE [FO-STOCKAGE], pas deux (" .. alerts(n0) .. ")")
  b.stock_pending = { stone = 10 }
  b.stock_watch.retry = nil
  Stock.grow(b, surf_new, 400 + 4 * T.annex.retry)
  check(b.pending_alert == nil, "repassée sous le seuil : l'alerte est réarmée")
  local n1 = #logs
  Stock.insert(b, "stone", 1200)
  b.stock_watch.retry = nil
  Stock.grow(b, surf_new, 400 + 5 * T.annex.retry)
  check(alerts(n1) == 1, "nouveau dépassement : nouvelle alerte")
  -- (f) essai 3 (remarque du DC, 21 h 47) : le REGISTRE SE RÉPARE. Un coffre en fer remplacé par-dessus par un coffre en acier (nouveau numéro
  -- d'unité, l'ancien devient invalide) et un coffre en acier posé par le joueur dans la zone sont RETROUVÉS et remplis ; jamais un coffre
  -- d'avant-poste, ni un coffre sur une ligne du joueur (bras au contact), ni un coffre hors de la zone.
  local Stt = require("script.faction.state")
  local owner0 = Stt.owner
  Stt.owner = function(u) return u == 9003 and { oid = 1 } or nil end
  local q = team(10)
  q.hq_pos = { x = 0, y = 0 }
  q.hq.items.stone = 50 * 10 -- QG plein
  local old = named(32, "iron-chest", 1, 5)
  old.unit_number = 9000
  q.annex = { old }
  local function ent(u, name, x, y) local e = named(48, name, x, y); e.unit_number, e.force = u, "x"; return e end
  local replaced = ent(9001, "steel-chest", 1, 5) -- par-dessus l'ancien
  local posed = ent(9002, "steel-chest", 11, 11) -- posé par le joueur, coin du bloc
  local owned = ent(9003, "steel-chest", -3, 7) -- réception d'avant-poste
  local lined = ent(9004, "steel-chest", 5, 9) -- un bras au contact
  local far = ent(9005, "steel-chest", 40, 40) -- hors de la zone
  local byplayer = ent(9006, "steel-chest", -5, 9) -- posé par un JOUEUR : l'affaire de COFFRES-JOUEUR (Stock.depot), pas du registre des annexes
  byplayer.last_user = { name = "DC" }
  local world = { replaced, posed, owned, lined, far, byplayer }
  local surf_scan = {
    create_entity = function(s) return named(32, s.name, s.position.x, s.position.y) end,
    find_entities_filtered = function(flt)
      local a = flt.area
      local out = {}
      if flt.type == "container" then
        for _, e in ipairs(world) do
          if e.valid and e.position.x >= a[1][1] and e.position.x <= a[2][1] and e.position.y >= a[1][2] and e.position.y <= a[2][2] then
            out[#out + 1] = e
          end
        end
      elseif a[1][1] < 5 and a[2][1] > 5 and a[1][2] < 9 and a[2][2] > 9 then
        out[1] = { valid = true, type = "inserter" }
      end
      return out
    end,
  }
  old.valid = false -- le joueur a posé le coffre en acier par-dessus : l'ancien n'existe plus
  local nl = #logs
  Stock.grow(q, surf_scan, 900)
  local ids = {}
  for _, e in ipairs(Stock.annexes(q)) do ids[#ids + 1] = e.unit_number end
  table.sort(ids)
  check(table.concat(ids, ",") == "9001,9002", "registre réparé : le coffre remplacé (9001) et celui posé par le joueur (9002) ; ni avant-poste, " ..
    "ni ligne du joueur, ni hors zone, ni coffre d'un joueur (" .. table.concat(ids, ",") .. ")")
  local found = 0
  for i = nl + 1, #logs do if logs[i]:find("FO%-STOCKAGE") and logs[i]:find("retrouve") then found = found + 1 end end
  check(found == 2, "journal [FO-STOCKAGE] : 2 coffres retrouvés (" .. found .. ")")
  Stock.balance(q)
  check((replaced.items.stone or 0) > 0 or (posed.items.stone or 0) > 0, "ils se REMPLISSENT : le rangement du QG plein y verse ses piles (" ..
    tostring(replaced.items.stone) .. ", " .. tostring(posed.items.stone) .. ")")
  -- mutant : sans la réparation, le registre reste vide
  local sc0 = Stock.scan
  Stock.scan = function() return 0 end
  local q2 = team(10)
  q2.hq_pos = { x = 0, y = 0 }
  q2.hq.items.stone = 50 * 10
  q2.annex = { old }
  Stock.grow(q2, surf_scan, 900)
  check(#Stock.annexes(q2) == 0, "mutant (réparation retirée) : aucun coffre retrouvé, la règle d'avant")
  Stock.scan = sc0
  Stt.owner = owner0
  -- (g) STOCKAGE x COFFRES-JOUEUR : un coffre du joueur ouvert aux dépôts (Stock.depot) reçoit les dépôts quand le QG et les annexes sont pleins,
  -- compte dans la place du stock (pas dans le nombre d'annexes), et reçoit les objets en attente.
  local dz = team(10)
  dz.hq.items.stone = 50 * 10 -- QG plein, aucune annexe
  local mine = named(48, "steel-chest", 3, 20)
  mine.last_user = { name = "DC" }
  Stock.depot = function(ff) return ff == dz and { mine } or {} end
  game.tick = 7000
  check(Stock.insert(dz, "coal", 100) == 100 and (mine.items.coal or 0) == 100 and Stock.pending(dz) == 0,
    "QG plein : le dépôt va au coffre du joueur ouvert aux dépôts, rien en attente")
  local used, size, n = 0, 0, 0
  dz.stock_watch = {}
  local wanted_with = Stock.wanted(dz)
  check(wanted_with == 0, "sa place compte dans le stock : l'équipe ne se croit pas pleine (coffres demandés : " .. wanted_with .. ")")
  dz.stock_pending = { wood = 50 }
  Stock.flush(dz)
  check((mine.items.wood or 0) == 50 and Stock.pending(dz) == 0, "les objets en attente y entrent aussi")
  Stock.depot = nil
  game.tick = nil
  game.tick = nil
end

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
