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
local TYPES = { ["modular-armor"] = "armor", ["firearm-magazine"] = "ammo" } -- type de prototype (le reste : « item »)
game = { item_prototypes = setmetatable({}, { __index = function(_, k) return { stack_size = STACK[k] or 50, type = TYPES[k] or "item" } end }) }
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
-- Lot TUILES-RESERVEES : crochet unique des tuiles réservées (vrai script/ai3/places_qg.lua : Q.is_reserved lit Q.reserved)
local PQ = dofile("script/ai3/places_qg.lua")
package.loaded["script.ai3.places_qg"] = {
  is_reserved = PQ.is_reserved,
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
  -- lot STOCKAGE-VITAL (point D3 de docs/IA_WORKFLOW.md) : le fond reçoit le besoin BRUT et retire lui-même les coffres en main hors
  -- demande du plan directeur ; des coffres réservés au plan ne sont pas en main
  check(Stock.wanted(f, true) == T.annex.want, "brut : coffres voulus sans retirer ceux en main (" .. Stock.wanted(f, true) .. ")")
  local saved_demand = Stock.demand
  Stock.demand = function(_, item) return item == "iron-chest" and 3 or 0 end
  check(Stock.wanted(f) == T.annex.want and Stock.annex_demand(f)["iron-chest"] == 3 and Stock.annex_demand(f)["wooden-chest"] == 0,
    "D3 : 3 coffres reserves au plan directeur -> pas en main, demande transmise au fond")
  Stock.demand = saved_demand
  check(Stock.grow(f, surface, 3600) and #made == 1 and made[1].name == "iron-chest", "plein avec un coffre : posé")
  check(#f.annex == 1 and f.hq.items["iron-chest"] == 2, "le coffre posé sort du stock et entre dans les annexes")
  -- lot STOCKAGE-VITAL : plein sans coffre en main, l'urgence est aussi au journal ([FO-STOCKAGE], avant la pose)
  local n_annexe, n_urgent = 0, 0
  for _, l in ipairs(logs) do
    if l:find("FO%-ANNEXE") then n_annexe = n_annexe + 1 end
    if l:find("FO%-STOCKAGE") and l:find("URGENT") then n_urgent = n_urgent + 1 end
  end
  check(n_annexe == 1, "journal [FO-ANNEXE]")
  check(n_urgent == 1, "journal [FO-STOCKAGE] : coffre urgent demande quand le stock est plein sans coffre en main")
  -- 9 cases + 0 sur 42 : 21 % : plus de pose
  check(not Stock.grow(f, surface, 3700), "le total QG + annexes a de la place : plus de pose")
  local g = team(10)
  g.hq.items.coal = 50 * 9
  g.hq.items["wooden-chest"] = 1
  check(Stock.grow(g, surface, 0) and made[#made].name == "wooden-chest", "à défaut de coffre de fer, un coffre de bois")
  local h = team(10)
  h.hq.items.coal = 50 * 10
  h.annex = {}
  for i = 1, Stock.capacity(h) do h.annex[i] = new_chest(0) end
  h.hq.items["iron-chest"] = 1
  check(not Stock.grow(h, surface, 0), "maximum d'annexes atteint : plus de pose")
end
do
  -- Lot STOCKAGE-VITAL : un coffre qu'un PNJ dépose dans un stock PLEIN est posé en annexe sur-le-champ (Stock.insert -> place_held) ;
  -- un dépôt refusé est au journal, au plus une ligne par Stock.REFUSED_LOG ticks.
  local made = {}
  local surface = { create_entity = function(s) local e = new_chest(16); e.name = s.name; made[#made + 1] = e; return e end }
  local f = team(10)
  f.hq.surface = surface
  f.hq.items.stone = 50 * 10 -- 10 cases sur 10 : plein de pierre
  local n0 = #logs
  check(Stock.insert(f, "wooden-chest", 1) == 1, "stock plein : le coffre en bois depose est pris (pose en annexe)")
  check(#made == 1 and made[1].name == "wooden-chest" and f.annex and #f.annex == 1 and f.hq.items["wooden-chest"] == nil,
    "le coffre refuse au depot est pose, pas range")
  local seen = false
  for i = n0 + 1, #logs do if logs[i]:find("FO%-ANNEXE") and logs[i]:find("depot d'un PNJ", 1, true) then seen = true end end
  check(seen, "journal [FO-ANNEXE] : pose au depot d'un PNJ")
  -- Un PNJ qui porte 100 coffres de fer, stock plein : UNE annexe posée, les 99 autres coffres rangés dedans (sauvegarde du DC, 7/11 :
  -- emerald posait une annexe par coffre porté, 79 d'un coup)
  local made9 = {}
  local g9 = team(10)
  g9.hq.surface = { create_entity = function(s) local e = new_chest(16); e.name = s.name; made9[#made9 + 1] = e; return e end }
  g9.hq.items.stone = 50 * 10
  local put9 = Stock.insert(g9, "iron-chest", 100)
  check(put9 == 100 and #made9 == 1 and made9[1].items["iron-chest"] == 99,
    "100 coffres refuses : une annexe posee, 99 coffres ranges dedans (" .. put9 .. ", " .. #made9 .. " annexe(s))")
  f.annex[1].items.stone = 16 * 50 -- l'annexe pleine aussi
  game.tick = 100
  local n1 = #logs
  check(Stock.insert(f, "stone", 10) == 0, "pierre refusee : stock plein")
  Stock.insert(f, "stone", 10)
  game.tick = 100 + Stock.REFUSED_LOG
  Stock.insert(f, "stone", 10)
  local nref = 0
  for i = n1 + 1, #logs do if logs[i]:find("FO%-STOCKAGE") and logs[i]:find("depot refuse", 1, true) then nref = nref + 1 end end
  check(nref == 2, "depot refuse au journal : une ligne par minute au plus (" .. nref .. " pour 3 refus sur 2 minutes)")
  local h = team(10)
  h.hq.surface = surface
  h.hq.items.stone = 50 * 10
  h.annex = {}
  for i = 1, Stock.capacity(h) do h.annex[i] = new_chest(0) end
  check(Stock.insert(h, "wooden-chest", 1) == 0 and #made == 1, "plafond d'annexes : le coffre refuse n'est pas pose")
  local g = team(10)
  g.hq.items.stone = 50 * 10 -- sans surface lisible (moteur simulé d'autres bancs) : rien n'est posé, rien ne plante
  check(Stock.insert(g, "wooden-chest", 1) == 0, "sans surface : refus simple")
  game.tick = nil
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
  check(Stock.insert(h, "coal", 500) == 0 and h.refused_at == 500, "dépôt refusé : noté")
  check(Stock.wanted(h) == T.annex.want - 1, "un coffre en main : le fond en demande un de moins")
  check(Stock.grow(h, surface, 600) and #h.annex == 1 and h.refused_at == nil, "refus : coffre posé, refus consommé")
  local k = team(10)
  k.hq.items.coal = 50 * 10
  check(Stock.insert(k, "coal", 50) == 0 and Stock.wanted(k) == T.annex.want, "refus sans coffre en main : le fond en fabrique")
  -- Plan directeur : une place réservée est sautée ; sans place libre on réessaie plus tard.
  local r = team(10)
  r.hq.items.coal = 50 * 9
  r.hq.items["iron-chest"] = 1
  PQ.reserved = function() return true end
  check(not Stock.grow(r, surface, 0) and r.stock_watch.retry == T.annex.retry and #(r.annex or {}) == 0,
    "toutes les places réservées : rien posé, nouvel essai plus tard")
  PQ.reserved = function(_, _, p) return p.x < 0 end
  check(not Stock.grow(r, surface, T.annex.retry - 1), "attente après un échec de pose")
  check(Stock.grow(r, surface, T.annex.retry) and #r.annex == 1 and pos[#pos].x >= 0, "après l'attente : posé sur une place non réservée")
  PQ.reserved = nil
  -- Coffre réclamé par le plan directeur : pas posé en annexe.
  local d = team(10)
  d.hq.items.coal = 50 * 9
  d.hq.items["iron-chest"] = 1
  Stock.demand = function(_, item) return item == "iron-chest" and 1 or 0 end
  check(not Stock.grow(d, surface, 0) and Stock.wanted(d) == T.annex.want, "coffre déjà réclamé par le plan : ni posé ni compté en main")
  Stock.demand = nil
  game.tick = nil
end

do
  print("== Lot STOCKAGE-VITAL : reserve des matieres vitales au depot, matieres ecartees du ramassage")
  local DEP = { reserve = true } -- dépôt d'un PNJ au QG (script/team/worker.lua) : la réserve des vitales s'applique
  local f = team(20) -- 20 cases ; reserve 15 % = 3 cases gardees au fer et au charbon
  local inv = f.hq.get_inventory()
  inv.get_insertable_count = function(name)
    local stack = STACK[name] or 50
    local have = f.hq.items[name] or 0
    return math.ceil(have / stack) * stack - have + inv.count_empty_stacks() * stack
  end
  local ss, si = STACK.stone or 50, STACK["iron-plate"] or 50
  f.hq.items.coal = (STACK.coal or 50) * 15 -- 15 cases prises, 5 vides
  f.refused_at = nil
  local put = Stock.insert(f, "stone", 10 * ss, DEP)
  check(put == 2 * ss, "pierre : 2 cases seulement (5 vides moins 3 gardees)", put)
  check(f.refused_at ~= nil, "pierre limitee : depot refuse note (pose anticipee d'un coffre)")
  local put2 = Stock.insert(f, "iron-plate", 10 * si, DEP)
  check(put2 == 3 * si, "fer : les 3 cases gardees", put2)
  -- un coffre d'annexe est du stockage : il entre dans les cases gardées (lot STOCKAGE-VITAL)
  f.hq.items["iron-plate"], f.hq.items.stone = nil, nil
  f.hq.items.coal = (STACK.coal or 50) * 18 -- 18 cases prises, 2 vides (sous la réserve de 3)
  check(Stock.insert(f, "stone", ss, DEP) == 0, "temoin : la pierre n'entre pas dans les 2 cases gardees (depot d'un PNJ)")
  check(Stock.insert(f, "stone", 5) == 5 and Stock.remove(f, "stone", 5) == 5, "hors depot d'un PNJ (remboursement d'un script) : la reserve ne s'applique pas")
  check(Stock.insert(f, "wooden-chest", 1, DEP) == 1 and f.hq.items["wooden-chest"] == 1, "coffre en bois : pris dans les cases gardees")
  f.hq.items["wooden-chest"] = nil
  -- Dépôt d'une non vitale : sortie tôt quand le dépôt tient dans les piles entamées du QG (aucune annexe lue), et piles entamées
  -- d'abord, coffre par coffre (déposer d'un bloc au QG prenait ses cases vides alors que la place était dans une annexe).
  local function readable(e)
    local iv = e.get_inventory()
    iv.reads = 0
    local ces = iv.count_empty_stacks
    iv.count_empty_stacks = function() iv.reads = iv.reads + 1 return ces() end
    iv.get_insertable_count = function(name)
      iv.reads = iv.reads + 1
      local stack = STACK[name] or 50
      local have = e.items[name] or 0
      return math.ceil(have / stack) * stack - have + ces() * stack
    end
    return iv
  end
  local g2 = team(20)
  readable(g2.hq)
  local an = new_chest(10)
  local ian = readable(an)
  g2.annex = { an }
  g2.hq.items.coal = (STACK.coal or 50) * 18 -- 18 cases sur 20, 2 vides (réserve du total de 30 cases : 5)
  g2.hq.items.stone = ss / 2 -- une pile entamée de la moitié
  local before_empty = g2.hq.get_inventory().count_empty_stacks()
  check(Stock.insert(g2, "stone", ss / 2 - 1, DEP) == ss / 2 - 1 and ian.reads == 0 and g2.hq.get_inventory().count_empty_stacks() == before_empty,
    "non vitale qui tient dans la pile entamee du QG : deposee, aucune annexe lue (" .. ian.reads .. " lecture(s))")
  local g3 = team(20)
  readable(g3.hq)
  local an3 = new_chest(10)
  readable(an3)
  g3.annex = { an3 }
  g3.hq.items.coal = (STACK.coal or 50) * 18 -- QG : 2 cases vides, aucune pierre
  an3.items.coal = (STACK.coal or 50) * 9
  an3.items.stone = ss / 2 -- annexe : pleine, une pile de pierre entamée
  local hq_empty = g3.hq.get_inventory().count_empty_stacks()
  local put3 = Stock.insert(g3, "stone", ss / 2 - 1, DEP)
  check(put3 == ss / 2 - 1 and an3.items.stone == ss - 1 and g3.hq.get_inventory().count_empty_stacks() == hq_empty and (g3.hq.items.stone or 0) == 0,
    "non vitale : la pile entamee de l'annexe d'abord, les cases vides du QG (sous la reserve) restent libres (" .. put3 .. ", QG vides " ..
    g3.hq.get_inventory().count_empty_stacks() .. "/" .. hq_empty .. ")")
  -- Réserve au seul coffre du QG (décision du lead, 7/11) : les annexes prennent les non vitales tant qu'elles ont de la place, puis le
  -- fer entre quand même dans les cases gardées du QG ; les refus sont comptés par objet.
  local g4 = team(20)
  readable(g4.hq)
  local an4 = new_chest(10)
  readable(an4)
  g4.annex = { an4 }
  g4.hq.items.coal = (STACK.coal or 50) * 17 -- QG : 3 cases vides = sa réserve (ceil(0,15 x 20))
  local put4 = Stock.insert(g4, "stone", ss * 12, DEP)
  check(put4 == ss * 10 and an4.items.stone == ss * 10 and (g4.hq.items.stone or 0) == 0 and g4.hq.get_inventory().count_empty_stacks() == 3,
    "reserve au QG seul : l'annexe prend 10 piles de pierre, le QG garde ses 3 cases (" .. put4 .. ")")
  check(g4.stats.refused and g4.stats.refused.stone == ss * 2, "refus comptes par objet (pierre " .. tostring(g4.stats.refused and g4.stats.refused.stone) .. ")")
  local put5 = Stock.insert(g4, "iron-plate", si * 3, DEP)
  check(put5 == si * 3 and g4.hq.items["iron-plate"] == si * 3 and g4.hq.get_inventory().count_empty_stacks() == 0,
    "annexe pleine de non vitales : le fer entre quand meme dans les 3 cases gardees du QG (" .. put5 .. ")")
  -- cases neuves d'une non vitale : les annexes d'abord, le QG ensuite (au-delà de sa réserve)
  local g5 = team(20)
  readable(g5.hq)
  local an5 = new_chest(10)
  readable(an5)
  g5.annex = { an5 }
  g5.hq.items.coal = (STACK.coal or 50) * 18 -- QG : 2 cases vides, sous sa réserve de 3
  an5.items.coal = (STACK.coal or 50) * 8 -- annexe : 2 cases vides
  local put6 = Stock.insert(g5, "stone", ss * 3, DEP)
  check(put6 == ss * 2 and an5.items.stone == ss * 2 and g5.hq.get_inventory().count_empty_stacks() == 2,
    "non vitale : les cases vides de l'annexe, jamais celles du QG sous sa reserve (" .. put6 .. ")")
  local g6 = team(20)
  readable(g6.hq)
  local an6 = new_chest(10)
  readable(an6)
  g6.annex = { an6 }
  g6.hq.items.coal = (STACK.coal or 50) * 14 -- QG : 6 cases vides, 3 au-delà de sa réserve
  an6.items.coal = (STACK.coal or 50) * 8 -- annexe : 2 cases vides
  local put7 = Stock.insert(g6, "stone", ss * 3, DEP)
  check(put7 == ss * 3 and an6.items.stone == ss * 2 and g6.hq.items.stone == ss and g6.hq.get_inventory().count_empty_stacks() == 5,
    "non vitale : l'annexe d'abord, puis le QG au-dela de sa reserve (" .. put7 .. ", QG vides " .. g6.hq.get_inventory().count_empty_stacks() .. ")")
  -- D1 (relecture revue-0659) : annexe pleine, QG dans sa reserve (3 cases vides sur 20), cuivre DEMANDE 2 piles : il entre au depot
  -- jusqu'a la quantite demandee, pas au-dela ; temoin sans demande : refuse (reserve gardee au fer et au charbon)
  local cs = STACK["copper-plate"] or 50
  local function scene_d1()
    local h = team(20)
    readable(h.hq)
    local an = new_chest(10)
    readable(an)
    h.annex = { an }
    h.hq.items.coal = (STACK.coal or 50) * 17
    an.items.coal = (STACK.coal or 50) * 10
    return h
  end
  local t0 = scene_d1()
  check(Stock.insert(t0, "copper-plate", 3 * cs, DEP) == 0 and t0.hq.get_inventory().count_empty_stacks() == 3,
    "D1 temoin : cuivre non demande, annexe pleine, QG dans sa reserve : refuse")
  local h1 = scene_d1()
  h1.team = { ia3 = { short = { ["copper-plate"] = 2 * cs } } }
  local d1 = Stock.insert(h1, "copper-plate", 3 * cs, DEP)
  check(d1 == 2 * cs and h1.hq.items["copper-plate"] == 2 * cs and h1.hq.get_inventory().count_empty_stacks() == 1,
    "D1 : cuivre demande (2 piles) mais refuse jusqu'ici : 2 piles entrent dans la reserve, pas 3 (" .. d1 .. ")")
  local d2 = Stock.insert(h1, "copper-plate", cs, DEP)
  check(d2 == 0, "D1 : au-dela de la quantite demandee (demande inchangee, deja entree) : refuse (" .. d2 .. ")")
  h1.team = { missing = { { "copper-plate", cs } } } -- pensee suivante : la demande recomptee nette du stock
  local d3 = Stock.insert(h1, "copper-plate", 2 * cs, DEP)
  check(d3 == cs and h1.hq.get_inventory().count_empty_stacks() == 0, "D1 : demande recomptee (objectif, 1 pile) : 1 pile de plus (" .. d3 .. ")")
  -- B1 (relecture de 3a276733) : 2 piles entrees, consommees, creux sans demande, puis la MEME quantite redemandee a une pensee neuve
  local h2 = scene_d1()
  h2.team = { ia3 = { short = { ["copper-plate"] = 2 * cs } } }
  local e1 = Stock.insert(h2, "copper-plate", 2 * cs, DEP)
  Stock.remove(h2, "copper-plate", 2 * cs) -- consommees par les fabrications
  h2.team = { ia3 = { short = {} } } -- pensee suivante : le stock couvrait, plus de demande
  local e2 = Stock.insert(h2, "copper-plate", cs, DEP)
  h2.team = { ia3 = { short = { ["copper-plate"] = 2 * cs } } } -- pensee neuve : la meme quantite revient
  local e3 = Stock.insert(h2, "copper-plate", 3 * cs, DEP)
  check(e1 == 2 * cs and e2 == 0 and e3 == 2 * cs, "B1 : la meme quantite redemandee a une pensee neuve entre de nouveau, bornee (" .. e1 .. ", " .. e2 .. ", " .. e3 .. ")")
  -- C1 de DIAG_CONSO (7/11) : courroies qui manquent a deux projets en RESERVE (modules 94 et 95 de la partie du DC, hors projet dominant),
  -- stock plein (annexe pleine, QG dans sa reserve) : elles entrent jusqu'a la somme des manques ; pas pour un projet fini ni abandonne ;
  -- relues au plus toutes les Stock.RESV_EVERY ticks ; bornees par ce que le stock en tient deja (la reserve les y reprend)
  local bs = STACK["transport-belt"] or 50
  local function scene_c1()
    local h = team(30)
    readable(h.hq)
    local an = new_chest(10)
    readable(an)
    h.annex = { an }
    h.hq.items.coal = (STACK.coal or 50) * 25 -- 5 cases vides = la reserve du QG (ceil(0,15 x 30))
    an.items.coal = (STACK.coal or 50) * 10
    h.build = { order = { 94, 95, 96, 97 }, projects = {
      [94] = { id = 94, state = "reserve", missing = { { "assembling-machine-2", 3 }, { "transport-belt", bs } } },
      [95] = { id = 95, state = "reserve", missing = { { "transport-belt", bs } } },
      [96] = { id = 96, state = "fini", missing = { { "transport-belt", 5 * bs } } },
      [97] = { id = 97, state = "reserve", abandoned = true, missing = { { "transport-belt", 5 * bs } } } } }
    return h
  end
  local saved_tick = game.tick
  game.tick = 7000
  local t1 = scene_c1()
  t1.build = nil
  check(Stock.insert(t1, "transport-belt", 3 * bs, DEP) == 0, "C1 temoin : sans projet en reserve, courroies refusees (stock plein)")
  local h3 = scene_c1()
  local c1 = Stock.insert(h3, "transport-belt", 3 * bs, DEP)
  check(c1 == 2 * bs, "C1 : courroies manquantes aux reserves 94 et 95 (1 pile chacune) : 2 piles entrent, pas celles du projet fini ni de l'abandonne (" .. c1 .. ")")
  check(Stock.insert(h3, "transport-belt", bs, DEP) == 0, "C1 : au-dela de la somme des manques (2 piles deja au stock) : refusees")
  Stock.remove(h3, "transport-belt", 2 * bs)                          -- les deux reserves reprennent leurs courroies au stock...
  h3.build.projects[94].missing = { { "assembling-machine-2", 3 } }
  h3.build.projects[95].missing = { { "transport-belt", 3 * bs } }   -- ...et 95 en redemande 3 piles (recompte net du stock)
  game.tick = 7000 + Stock.RESV_EVERY - 1
  local c2 = Stock.insert(h3, "transport-belt", 3 * bs, DEP)
  check(c2 == 2 * bs, "C1 : manques relus au plus toutes les Stock.RESV_EVERY ticks (encore 2 piles, stock vide : 2 piles) (" .. c2 .. ")")
  game.tick = 7000 + Stock.RESV_EVERY
  local c3 = Stock.insert(h3, "transport-belt", 2 * bs, DEP)
  check(c3 == bs, "C1 : manques relus (3 piles), 2 deja au stock : 1 pile de plus (" .. c3 .. ")")
  game.tick = 7000 + 2 * Stock.RESV_EVERY
  check(Stock.insert(h3, "transport-belt", bs, DEP) == 0 and h3.hq.get_inventory().count_empty_stacks() == 2,
    "C1 : rien repris par la reserve, meme manque relu : rien de plus (2 cases gardees vides)")
  local sk3 = Stock.skip_fn(h3)
  check(sk3 ~= nil and sk3("copper-plate") and not sk3("transport-belt"),
    "C1 : stock presque plein : le cuivre n'est plus ramasse, les courroies qui manquent a une reserve le sont toujours")
  -- C2 de DIAG_CONSO : charbon (vital) et pierre saturees au cerveau ; au plafond de 20 piles, plus ramassees ; sous le plafond, regle d'avant
  local h4 = scene_c1()
  h4.build = nil
  h4.team = { ia3 = { saturated = { coal = true, stone = true } } }
  h4.hq.items.stone = (STACK.stone or 50) * 2
  local n0 = #logs
  game.tick = 9000
  local sk4 = Stock.skip_fn(h4)
  check(sk4 ~= nil and sk4("coal") and not sk4("iron-plate") and not sk4("iron-ore"),
    "C2 : charbon sature a 35 piles (plafond 20) : plus ramasse ni collecte ; fer et minerai toujours")
  check(sk4 ~= nil and sk4("stone"), "C2 : pierre saturee sous le plafond, stock presque plein : ecartee (regle d'avant)")
  local over_logs = 0
  for i = n0 + 1, #logs do if logs[i]:find("plafond des saturees", 1, true) and logs[i]:find("coal 1750", 1, true) then over_logs = over_logs + 1 end end
  check(over_logs == 1, "C2 : une ligne [FO-STOCKAGE] « plafond des saturees » nommant le charbon et son compte (" .. over_logs .. ")")
  game.tick = 9000 + Stock.OVER_EVERY
  Stock.skip_fn(h4)
  local again = 0
  for i = n0 + 1, #logs do if logs[i]:find("plafond des saturees", 1, true) then again = again + 1 end end
  check(again == 1, "C2 : ensemble inchange a la relecture : pas de nouvelle ligne (" .. again .. ")")
  h4.team.missing = { { "coal", 40 } }
  game.tick = 9000 + 2 * Stock.OVER_EVERY
  check(not Stock.skip_fn(h4)("coal"), "C2 : charbon au plafond mais DEMANDE (objectif) : ramasse")
  h4.team.missing = nil
  h4.hq.items.coal = (STACK.coal or 50) * 19
  h4.annex[1].items.coal = nil
  game.tick = 9000 + 3 * Stock.OVER_EVERY
  local sk5 = Stock.skip_fn(h4)
  check(sk5 == nil or not sk5("coal"), "C2 : charbon sous le plafond (19 piles) : ramasse de nouveau")
  h4.hq.items.coal = (STACK.coal or 50) * 25
  game.tick = 9000 + 3 * Stock.OVER_EVERY + 1
  local sk6 = Stock.skip_fn(h4)
  check(sk6 == nil or not sk6("coal"), "C2 : plafond relu au plus toutes les Stock.OVER_EVERY ticks (verdict garde 1 tick plus tard)")
  game.tick = saved_tick
  f.team = { ia3 = { saturated = { stone = true } } }
  local skip = Stock.skip_fn(f)
  check(skip ~= nil and skip("stone") and skip("copper-plate") and not skip("coal") and not skip("iron-plate"),
    "stock plein : pierre (saturee) et cuivre plus ramasses, fer et charbon toujours")
  local g = team(20)
  g.hq.items.coal = (STACK.coal or 50) * 5 -- 25 % : seule la saturee est ecartee
  g.team = { ia3 = { saturated = { stone = true } } }
  local skip2 = Stock.skip_fn(g)
  check(skip2 ~= nil and skip2("stone") and not skip2("copper-plate"), "stock a 25 % : seule la pierre saturee est ecartee")
  g.team = nil
  check(Stock.skip_fn(g) == nil, "stock a 25 % sans saturee : rien d'ecarte")
end
do
  -- Relecture du 7/11 : stock à 90 %, plafond d'annexes atteint (80 annexes, deux faces), cuivre demandé -> le cuivre est encore ramassé aux
  -- avant-postes (plaque) et miné à la main (minerai : boucle de script/team/poles.lua sur Fond.MINE_TARGETS).
  local Fond = require("shared.team.fond")
  local ss = STACK.stone or 50
  local h = team(20)
  h.annex = {}
  for i = 1, Stock.capacity(h) do -- plafond des deux faces du lot (lot STOCKAGE-VITAL (d)) : 80 annexes d'une case
    local a = new_chest(1)
    a.items.stone = ss
    h.annex[i] = a
  end
  h.hq.items.coal = (STACK.coal or 50) * 10
  local used, size = Stock.fill(h)
  check(used == 90 and size == 100 and Stock.wanted(h) == 0, "scene : stock a 90 % (" .. used .. "/" .. size .. "), plafond d'annexes atteint")
  local function mined(skip)
    local out = {}
    for _, m in ipairs(Fond.MINE_TARGETS) do if not skip(m[1]) then out[m[1]] = true end end
    return out
  end
  h.team = { ia3 = { saturated = { stone = true }, short = { ["copper-plate"] = 40 }, other_short = true } }
  local sk = Stock.skip_fn(h)
  local mi = sk and mined(sk) or {}
  check(sk ~= nil and not sk("copper-plate") and mi["copper-ore"] and not mi.stone and mi.coal and mi["iron-ore"],
    "stock a 90 %, plafond atteint, cuivre manquant (cerveau) : le cuivre est encore ramasse et mine, la pierre non")
  h.team = { ia3 = { saturated = { stone = true } }, missing = { { "copper-plate", 30 } } }
  local sk2 = Stock.skip_fn(h)
  check(sk2 ~= nil and not sk2("copper-plate") and not sk2("copper-ore") and sk2("stone"),
    "stock a 90 %, plafond atteint, cuivre attendu par l'objectif : le cuivre est encore ramasse et mine")
  h.team = { ia3 = { saturated = { stone = true }, short = { ["copper-plate"] = 0 } } }
  local sk3 = Stock.skip_fn(h)
  check(sk3 ~= nil and sk3("copper-plate") and sk3("copper-ore"), "temoin : cuivre sans manque, stock a 90 % : ecarte")
end

do
  print("== Lot STOCKAGE-VITAL (a) : coffre en main, aucune place libre dans le bloc : pourquoi (Stock.annex_blockers, [FO-ANNEXE])")
  local A = require("shared.team.annexe")
  local slots = A.slots(1, 1, 1)
  local function at(i) return { x = math.floor(slots[i][1]) + 0.5, y = math.floor(slots[i][2]) + 0.5 } end
  local mine = new_chest(16)
  mine.unit_number, mine.name, mine.position = 901, "iron-chest", at(1)
  local world = { mine }
  for k = 1, 3 do world[#world + 1] = { valid = true, name = "item-on-ground", position = { x = at(2).x + 0.1 * k, y = at(2).y } } end
  world[#world + 1] = { valid = true, name = "stone-furnace", unit_number = 902, position = at(3) }
  local function inside(p, a) return p.x > a[1][1] and p.x < a[2][1] and p.y > a[1][2] and p.y < a[2][2] end
  local function key(p) return p.x .. "," .. p.y end
  local blocked = { [key(at(1))] = true, [key(at(2))] = true, [key(at(3))] = true }
  local surface = {
    can_place_entity = function(t) return not blocked[key(t.position)] end,
    find_entities_filtered = function(t)
      local out = {}
      if t.area then for _, e in ipairs(world) do if e.valid and inside(e.position, t.area) then out[#out + 1] = e end end end
      return out
    end,
    create_entity = function() return nil end,
  }
  local f = team(10)
  f.annex = { mine }
  f.annex_sy = 1
  local saved_reserved = PQ.reserved
  PQ.reserved = function(_, _, p) return key(p) == key(at(4)) end
  local rows = Stock.annex_blockers(f, surface, "iron-chest")
  check(#rows == 4 and rows[1].own and rows[2].ground == 3 and #rows[2].names == 0 and rows[3].names[1] == "stone-furnace[-, hors plan]"
    and rows[4].reserved, "places refusees : la notre, 3 objets au sol, un four (force, hors plan), une reserve du plan (" .. #rows .. ")")
  f.build = { occ = { [require("shared.team.plan").tkey(math.floor(at(3).x), math.floor(at(3).y))] = 7 } }
  world[#world].force = { name = "player" }
  local rows2 = Stock.annex_blockers(f, surface, "iron-chest")
  check(rows2[3].names[1] == "stone-furnace[player, projet 7]", "entite bloquante : sa force et le projet du plan (" .. tostring(rows2[3].names[1]) .. ")")
  f.build = nil
  -- Stock.grow : coffre en main, stock plein, aucune pose -> une ligne [FO-ANNEXE] « aucune place libre », bornée
  f.hq.items["iron-chest"] = 1
  f.hq.items.coal = (STACK.coal or 50) * 9
  mine.items.coal = (STACK.coal or 50) * 16 -- stock plein : QG et annexe
  for i = #logs, 1, -1 do logs[i] = nil end
  Stock.grow(f, surface, 100)
  f.stock_watch.retry = nil
  Stock.grow(f, surface, 200)
  local n, line = 0, nil
  for _, s in ipairs(logs) do if s:find("aucune place libre", 1, true) then n, line = n + 1, s end end
  check(n == 1 and line and line:find("sol 3", 1, true) and line:find("stone-furnace", 1, true) and line:find("reserve du plan", 1, true)
    and line:find("1 prise(s) par nos annexes", 1, true), "journal : une ligne bornee, avec chaque raison (" .. tostring(line) .. ")")
  PQ.reserved = saved_reserved
end

do
  print("== Lot STOCKAGE-VITAL (b) : place du bloc tenue par des objets au sol seulement : degagee, coffre pose, objets dedans")
  local A = require("shared.team.annexe")
  local slots = A.slots(1, 1, 1)
  local north = A.slots(-1, 1, 1)
  local function tile(p) return math.floor(p.x) .. "," .. math.floor(p.y) end
  local function make_world()
    local W = { ents = {}, spilled = {}, made = {} }
    local function on(p)
      local out = {}
      for _, e in ipairs(W.ents) do if e.valid and tile(e.position) == tile(p) then out[#out + 1] = e end end
      return out
    end
    W.surface = {
      can_place_entity = function(t) return #on(t.position) == 0 end,
      find_entities_filtered = function(t)
        if not t.area then return {} end
        return on({ x = (t.area[1][1] + t.area[2][1]) / 2, y = (t.area[1][2] + t.area[2][2]) / 2 })
      end,
      create_entity = function(t)
        if W.refuse or #on(t.position) > 0 then return nil end
        local e = new_chest(16)
        e.name, e.position, e.unit_number = t.name, t.position, 1000 + #W.made
        W.made[#W.made + 1] = e
        W.ents[#W.ents + 1] = e
        return e
      end,
      spill_item_stack = function(p, st) W.spilled[#W.spilled + 1] = { p = p, name = st.name, count = st.count } end,
    }
    function W.item(p, name, n, extra)
      local g = { valid = true, name = "item-on-ground", position = { x = p.x, y = p.y }, stack = { valid_for_read = true, name = name, count = n } }
      for k, v in pairs(extra or {}) do g.stack[k] = v end
      g.destroy = function() g.valid = false end
      W.ents[#W.ents + 1] = g
      return g
    end
    function W.block(p, name) W.ents[#W.ents + 1] = { valid = true, name = name, position = { x = p.x, y = p.y } } end
    return W
  end
  local function full_team()
    local f = team(10)
    f.hq.items.coal = 50 * 9
    f.hq.items["iron-chest"] = 1
    f.annex, f.annex_sy = {}, 1
    return f
  end
  local function pos(i) return { x = slots[i][1] + 0.5, y = slots[i][2] + 0.5 } end
  local function npos(i) return { x = north[i][1] + 0.5, y = north[i][2] + 0.5 } end
  -- toutes les places tenues par un four, sauf la 3e, tenue par 4 plaques et 2 charbons au sol
  local W = make_world()
  for i = 1, #slots do if i ~= 3 then W.block(pos(i), "stone-furnace") end end
  for i = 1, #north do W.block(npos(i), "stone-furnace") end
  local g1, g2 = W.item(pos(3), "copper-plate", 4), W.item(pos(3), "coal", 2)
  local f = full_team()
  for i = #logs, 1, -1 do logs[i] = nil end
  local placed = Stock.grow(f, W.surface, 100)
  local chest = W.made[1]
  check(placed and chest and tile(chest.position) == tile(pos(3)) and not g1.valid and not g2.valid
    and chest.items["copper-plate"] == 4 and chest.items.coal == 2 and #W.spilled == 0,
    "place degagee : coffre pose sur la place aux objets, les 4 plaques et 2 charbons DANS le coffre, rien au sol")
  local seen = false
  for _, s in ipairs(logs) do if s:find("degagee : 6 objet(s) au sol releve(s), 6 mis dans le coffre", 1, true) then seen = true end end
  check(seen, "journal : [FO-ANNEXE] place degagee")
  -- une pile speciale (armure) ou une autre entite sur la place : on n'y touche pas
  local W2 = make_world()
  for i = 1, #slots do if i ~= 3 then W2.block(pos(i), "stone-furnace") end end
  for i = 1, #north do W2.block(npos(i), "stone-furnace") end
  local arm = W2.item(pos(3), "modular-armor", 1)
  local p2 = W2.item(pos(3), "copper-plate", 4)
  check(not Stock.grow(full_team(), W2.surface, 100) and arm.valid and p2.valid and #W2.made == 0, "pile speciale sur la place : rien n'est touche")
  -- la pose echoue apres le releve : rien n'est perdu (au stock ou de nouveau au sol)
  local W3 = make_world()
  for i = 1, #slots do if i ~= 3 then W3.block(pos(i), "stone-furnace") end end
  for i = 1, #north do W3.block(npos(i), "stone-furnace") end
  W3.item(pos(3), "copper-plate", 4)
  W3.refuse = true
  local f3 = full_team()
  Stock.grow(f3, W3.surface, 100)
  local back = (f3.hq.items["copper-plate"] or 0)
  for _, s in ipairs(W3.spilled) do if s.name == "copper-plate" then back = back + s.count end end
  check(#W3.made == 0 and back == 4, "pose echouee : les 4 plaques reviennent (stock ou sol), aucune perdue (" .. back .. ")")
  print("== Lot STOCKAGE-VITAL (d) : la face nord apres la face du bloc ; plafond = places reelles")
  -- face sud tenue par le DC (coffres hors plan) sauf sa DERNIERE place : la derniere place sud passe avant la face nord
  local W4 = make_world()
  for i = 1, #slots - 1 do W4.block(pos(i), "steel-chest") end
  local f4 = full_team()
  check(Stock.grow(f4, W4.surface, 100) and W4.made[1] and tile(W4.made[1].position) == tile(pos(#slots)), "sud d'abord : la derniere place sud libre avant le nord")
  -- face sud entierement tenue, une de nos tourelles sur la 1re place nord : coffre sur la 2e place nord, tourelle intacte
  local W5 = make_world()
  for i = 1, #slots do W5.block(pos(i), "steel-chest") end
  W5.block(npos(1), "gun-turret")
  local turret = W5.ents[#W5.ents]
  local f5 = full_team()
  check(Stock.grow(f5, W5.surface, 100) and W5.made[1] and tile(W5.made[1].position) == tile(npos(2)) and turret.valid,
    "puis le nord : notre tourelle sautee, jamais retiree, coffre sur la place suivante")
  -- plafond : 48 places sud tenues par le DC, 32 annexes a nous au nord -> plus aucune place, Stock.wanted = 0 (jamais une place qui n'existe pas)
  local W6 = make_world()
  for i = 1, #slots do W6.block(pos(i), "steel-chest") end
  local f6 = full_team()
  f6.hq.items["iron-chest"] = nil
  f6.hq.items.coal = 50 * 10
  for i = 1, #north do
    local c = new_chest(0)
    c.name, c.position, c.unit_number = "iron-chest", npos(i), 2000 + i
    W6.ents[#W6.ents + 1] = c
    f6.annex[i] = c
  end
  Stock.grow(f6, W6.surface, 100)
  check(f6.annex_lost == #slots and Stock.capacity(f6) == #north and Stock.wanted(f6) == 0,
    "plafond suivi : " .. tostring(f6.annex_lost) .. " places tenues, plafond " .. Stock.capacity(f6) .. ", coffres voulus " .. Stock.wanted(f6))
  -- Garde de place_held (revue-s, lead, 7/11) : 100 dépôts refusés d'un coffre, bloc plein (deux faces tenues) : une seule recherche
  -- de place (au plus une vérification par place), pas une par dépôt ; T.annex.retry plus tard, une recherche de nouveau
  local W7 = make_world()
  for i = 1, #slots do W7.block(pos(i), "steel-chest") end
  for i = 1, #north do W7.block(npos(i), "steel-chest") end
  local calls = 0
  local cpe = W7.surface.can_place_entity
  W7.surface.can_place_entity = function(t) calls = calls + 1 return cpe(t) end
  local f7 = full_team()
  f7.hq.items["iron-chest"] = nil
  f7.hq.items.coal = 50 * 10 -- stock plein, aucun coffre en main
  f7.hq.surface = W7.surface
  f7.hq_pos = { x = 0, y = 0 }
  local saved_tick = game.tick
  game.tick = 5000
  local put7 = 0
  for _ = 1, 100 do put7 = put7 + Stock.insert(f7, "wooden-chest", 1, { reserve = true }) end
  local first = calls
  game.tick = 5000 + T.annex.retry
  Stock.insert(f7, "wooden-chest", 1, { reserve = true })
  local again = calls - first
  game.tick = saved_tick
  check(put7 == 0 and #W7.made == 0 and first >= 1 and first <= #slots + #north and again >= 1,
    "garde de place_held : 100 depots refuses, " .. first .. " verification(s) de place (une recherche), puis une recherche de nouveau apres T.annex.retry (" .. again .. ")")
end

do
  print("== Lot STOCKAGE-VITAL : compteurs des depots refuses et des poches pleines (une ligne chacun par minute)")
  local DEPR = { reserve = true }
  local f = team(10)
  f.hq.items.coal = 50 * 10 -- stock plein
  local saved_tick = game.tick
  local function has(pat) for _, s in ipairs(logs) do if s:find(pat, 1, true) then return s end end return nil end
  for i = #logs, 1, -1 do logs[i] = nil end
  game.tick = 1000
  Stock.insert(f, "stone", 30, DEPR)
  Stock.insert(f, "copper-plate", 20, DEPR) -- meme passage au QG (meme tick)
  Stock.insert(f, "stone", 5) -- hors depot d'un PNJ : pas compte
  game.tick = 1600
  Stock.insert(f, "stone", 10, DEPR) -- second passage
  local w = f.stock_refused_win
  check(w and w.visits == 2 and w.calls == 3 and w.items == 60, "depots refuses : 2 passages, 3 objets d'un depot, 60 objets (" .. (w and (w.visits .. "/" .. w.calls .. "/" .. w.items) or "nil") .. ")")
  local function inv(size, empty)
    local t = setmetatable({}, { __len = function() return size end })
    t.count_empty_stacks = function() return empty end
    return t
  end
  Stock.note_claim(f, inv(80, 4), 1000) -- 76/80 = 95 % : pleine
  Stock.note_claim(f, inv(80, 10), 1000) -- 70/80 = 87,5 % : non
  Stock.note_claim(f, inv(80, 8), 1000) -- 72/80 = 90 % : pleine (seuil compris)
  local q = f.stock_claim_win
  check(q and q.n == 3 and q.full == 2, "poches pleines : 2 prises sur 3 a 90 % ou plus (" .. (q and (q.full .. "/" .. q.n) or "nil") .. ")")
  Stock.grow(f, {}, 1000 + 1800) -- fenetre pas finie : aucune ligne
  check(not has("depots refuses de PNJ") and not has("poches pleines"), "fenetre en cours : aucune ligne")
  Stock.grow(f, {}, 1000 + Stock.COUNT_LOG)
  local l1, l2 = has("depots refuses de PNJ : 2 passage(s) au QG, 3 objet(s) d'un depot refuse(s), 60 objet(s)"), has("poches pleines : 2 prise(s) de tache sur 3")
  check(l1 ~= nil and l2 ~= nil and f.stock_refused_win == nil and f.stock_claim_win == nil, "fin de fenetre : une ligne chacun, compteurs remis")
  game.tick = saved_tick
end

do
  print("== Lot STOCKAGE-VITAL : le stock prend-il tout un contenu ? (Stock.room, Stock.can_take)")
  local function inv_readable(e)
    local iv = e.get_inventory()
    iv.get_insertable_count = function(name)
      local stack = STACK[name] or 50
      local have = e.items[name] or 0
      return math.ceil(have / stack) * stack - have + iv.count_empty_stacks() * stack
    end
  end
  local cs = STACK["copper-plate"] or 50
  local h = team(10)
  inv_readable(h.hq)
  h.hq.items.coal = (STACK.coal or 50) * 9
  h.hq.items["copper-plate"] = cs / 2 -- 1 case entamee : place pour cs / 2
  check(Stock.room(h, "copper-plate") == cs / 2 and Stock.room(h, "coal") == 0, "place : la pile entamee du cuivre, rien pour le charbon")
  check(Stock.can_take(h, { { "copper-plate", cs / 2 } }) == true and Stock.can_take(h, { { "copper-plate", cs / 2 + 1 } }) == false,
    "contenu : juste la place entamee, pas un de plus")
  check(Stock.can_take(h, { { "copper-plate", cs / 4 }, { "copper-plate", cs / 4 + 1 } }) == false, "contenu : un objet en deux lignes, additionne")
  check(Stock.can_take(h, { { "coal", 1 } }) == false, "contenu : charbon sans case vide ni pile entamee : refuse")
  local an = new_chest(2)
  inv_readable(an)
  h.annex = { an }
  check(Stock.can_take(h, { { "copper-plate", cs / 2 + 2 * cs } }) == true and Stock.can_take(h, { { "copper-plate", cs / 2 + 2 * cs + 1 } }) == false,
    "contenu : pile entamee du QG puis les 2 cases vides de l'annexe")
  check(Stock.room(h, "copper-plate") == cs / 2 + 2 * cs, "place : QG et annexe (" .. tostring(Stock.room(h, "copper-plate")) .. ")")
  local bare = team(10) -- coffre simulé sans get_insertable_count : capacité inconnue, l'appelant garde son chemin
  check(Stock.room(bare, "coal") == nil and Stock.can_take(bare, { { "coal", 1 } }) == true, "inventaire illisible : place inconnue, retrait permis")
end

do
  print("== Lot STOCKAGE-VITAL : objets au sol autour du QG repris par le stock (Stock.pick_ground)")
  local function ground(name, n, x, y)
    local g = { valid = true, position = { x = x, y = y }, stack = { valid_for_read = true, name = name, count = n } }
    g.destroy = function() g.valid = false end
    return g
  end
  local function surface_of(list)
    return { find_entities_filtered = function(q)
      local out = {}
      for _, g in ipairs(list) do
        if g.valid and q.name == "item-on-ground" then
          local dx, dy = g.position.x - q.position.x, g.position.y - q.position.y
          if not q.radius or dx * dx + dy * dy <= q.radius * q.radius then
            if q.limit and #out >= q.limit then break end
            out[#out + 1] = g
          end
        end
      end
      return out
    end }
  end
  local function has_log(pat)
    for _, s in ipairs(logs) do if s:find(pat, 1, true) then return true end end
    return false
  end
  -- 1) les piles du rayon reprises, celle de 12 tuiles laissée ; une ligne au journal
  local h = team(20)
  local a, b, c3, far = ground("copper-plate", 1, 3, 0), ground("copper-plate", 1, -2, 1), ground("coal", 1, 0, 5), ground("copper-plate", 1, 12, 0)
  for i = #logs, 1, -1 do logs[i] = nil end
  local took = Stock.pick_ground(h, surface_of({ a, b, c3, far }), 0)
  check(took == 3 and not a.valid and not b.valid and not c3.valid and far.valid and h.hq.items["copper-plate"] == 2 and h.hq.items.coal == 1,
    "sol du QG : 3 piles du rayon reprises, celle a 12 tuiles laissee (" .. took .. ")")
  check(has_log("[FO-STOCKAGE] test : sol du QG : 3 objet(s) repris sur 3"), "sol du QG : une ligne [FO-STOCKAGE] par passage")
  for i = #logs, 1, -1 do logs[i] = nil end
  check(Stock.pick_ground(h, surface_of({ far }), 0) == 0 and not has_log("sol du QG"), "rien dans le rayon : rien repris, aucune ligne")
  -- 2) pile entrée en partie : le reste au sol, compte réduit, jamais détruite
  local g = team(1)
  g.hq.items.coal = 47 -- place pour 3 charbons
  local p = ground("coal", 5, 1, 1)
  local t2 = Stock.pick_ground(g, surface_of({ p }), 0)
  check(t2 == 3 and p.valid and p.stack.count == 2 and g.hq.items.coal == 50, "pile entree en partie : 3 repris, 2 restent au sol (" .. t2 .. ")")
  -- 3) piles triées par position : place pour 1, la pile la plus à l'ouest d'abord
  local k = team(1)
  k.hq.items.coal = 49
  local east, west = ground("coal", 1, 4, 0), ground("coal", 1, -3, 0)
  Stock.pick_ground(k, surface_of({ east, west }), 0)
  check(not west.valid and east.valid, "piles triees par position : la pile en (-3, 0) avant celle en (4, 0)")
  -- 4) au plus Stock.GROUND_LIMIT par passage
  local m = team(20)
  local many = {}
  for i = 1, Stock.GROUND_LIMIT + 50 do many[i] = ground("coal", 1, (i % 9) - 4, math.floor(i / 9) % 9 - 4) end
  local t4 = Stock.pick_ground(m, surface_of(many), 0)
  local left = 0
  for _, x in ipairs(many) do if x.valid then left = left + 1 end end
  check(t4 == Stock.GROUND_LIMIT and left == 50, "au plus " .. Stock.GROUND_LIMIT .. " objets par passage (" .. t4 .. ", " .. left .. " restent)")
  -- 5) refusé (pierre, réserve des vitales du QG) : la pile reste entière
  local r = team(20)
  local rinv = r.hq.get_inventory()
  rinv.get_insertable_count = function(name)
    local stack = STACK[name] or 50
    local have = r.hq.items[name] or 0
    return math.ceil(have / stack) * stack - have + rinv.count_empty_stacks() * stack
  end
  r.hq.items.coal = (STACK.coal or 50) * 18 -- 2 cases vides, sous la réserve de 3
  local st = ground("stone", 1, 0, 1)
  check(Stock.pick_ground(r, surface_of({ st }), 0) == 0 and st.valid and st.stack.count == 1, "pierre refusee (reserve des vitales) : la pile reste au sol")
  -- 5 bis) B2 (relecture de 3a276733) : seules les piles simples sont reprises (armure, munitions entamées, objet abîmé : au sol)
  local sp = team(20)
  local armor, mag, hurt, plate = ground("modular-armor", 1, 1, 0), ground("firearm-magazine", 1, 2, 0), ground("iron-chest", 1, 3, 0),
    ground("copper-plate", 1, 4, 0)
  hurt.stack.health = 0.5
  local t5 = Stock.pick_ground(sp, surface_of({ armor, mag, hurt, plate }), 0)
  check(t5 == 1 and armor.valid and mag.valid and hurt.valid and not plate.valid and (sp.hq.items["modular-armor"] or 0) == 0,
    "piles simples seulement : armure, munitions et coffre abime restent au sol, la plaque est reprise (" .. t5 .. ")")
  -- 5 ter) journal : un passage qui ne reprend rien écrit au plus une ligne par Stock.REFUSED_LOG
  for i = #logs, 1, -1 do logs[i] = nil end
  local st2 = ground("stone", 1, 0, 2)
  Stock.pick_ground(r, surface_of({ st2 }), 100)
  Stock.pick_ground(r, surface_of({ st2 }), 200)
  local nl = 0
  for _, s in ipairs(logs) do if s:find("sol du QG", 1, true) then nl = nl + 1 end end
  check(nl <= 1, "journal : sans reprise, au plus une ligne par minute (" .. nl .. ")")
  -- 6) appelé par Stock.grow à chaque passage du stock
  local q = team(20)
  local z = ground("copper-plate", 1, 2, 2)
  Stock.grow(q, surface_of({ z }), 0)
  check(not z.valid and q.hq.items["copper-plate"] == 1, "Stock.grow reprend les objets au sol du QG")
end

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
