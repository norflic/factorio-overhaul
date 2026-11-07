--[[
  Lot STOCKAGE, coût par pensée (demande du lead, 7/11, 10 h 20 : sur la sauvegarde du DC, corr-coffres-stockage = 4,7 ms par tick et un pire
  tick de 1 067 ms, contre 3,2 ms et 263 ms avec l'étalement seul ; « mesurer au moteur simulé le coût par pensée de Stock.scan [...] et le
  ramener sous 2 ms par pensée »).
  Une pensée d'équipe = Stock.balance puis Stock.grow (script/team/team.lua:1104-1105). Le moteur simulé compte, par pensée :
    - le temps Lua (os.clock ; le moteur du jeu exécute le même Lua, les appels au moteur en plus) ;
    - les appels au moteur : find_entities_filtered (et les entités rendues), get_item_count, insert, remove_item, count_empty_stacks,
      get_contents, create_entity.
  Mondes : « dc » (base du DC autour du QG : QG plein, 20 annexes en fer pleines, 40 coffres du joueur dans la zone, sur des lignes, avec
  leurs bras) et « borne » (5 anneaux ouverts, 240 annexes pleines, 60 coffres du joueur sur des lignes).
  Lancement : lua5.2 tests/stock_cout_test.lua [--mesure] (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

defines = { inventory = { chest = 1 } }
local STACK = { stone = 50, ["iron-plate"] = 100, coal = 50, ["iron-chest"] = 50, ["steel-chest"] = 50, ["wooden-chest"] = 50 }
game = { tick = 0, item_prototypes = setmetatable({}, { __index = function(_, k) return { stack_size = STACK[k] or 50 } end }) }
function log() end

local C = {} -- compteurs d'appels au moteur
local function bump(k, n) C[k] = (C[k] or 0) + (n or 1) end

local UNIT = 0
local function new_chest(name, size, x, y)
  UNIT = UNIT + 1
  local e = { valid = true, items = {}, size = size, name = name, type = "container", force = "player", unit_number = UNIT,
    position = { x = x, y = y } }
  local function slots()
    local n = 0
    for k, v in pairs(e.items) do n = n + math.ceil(v / (STACK[k] or 50)) end
    return n
  end
  local inv = { valid = true }
  setmetatable(inv, { __len = function() return size end })
  inv.count_empty_stacks = function() bump("count_empty_stacks") return size - slots() end
  inv.get_contents = function()
    bump("get_contents")
    local out = {}
    for k, v in pairs(e.items) do out[k] = v end
    return out
  end
  e.get_inventory = function() return inv end
  e.get_item_count = function(name) bump("get_item_count") return e.items[name] or 0 end
  e.remove_item = function(s)
    bump("remove_item")
    local n = math.min(s.count, e.items[s.name] or 0)
    if n > 0 then e.items[s.name] = e.items[s.name] - n; if e.items[s.name] == 0 then e.items[s.name] = nil end end
    return n
  end
  e.insert = function(s)
    bump("insert")
    local stack = STACK[s.name] or 50
    local have = e.items[s.name] or 0
    local room = (math.ceil(have / stack) * stack - have) + (size - slots()) * stack
    local n = math.min(s.count, room)
    if n > 0 then e.items[s.name] = have + n end
    return n
  end
  inv.remove = function(s) return e.remove_item(s) end
  return e
end

-- Surface simulée : find_entities_filtered parcourt le monde (le moteur, lui, a un index par chunk : ce compte est celui des APPELS).
local WORLD = {}
local function select(flt)
    local a = flt.area
    local types = flt.type
    if type(types) == "string" then types = { types } end
    local tset = {}
    for _, t in ipairs(types or {}) do tset[t] = true end
    local out = {}
    for _, e in ipairs(WORLD) do
      if e.valid and (not types or tset[e.type]) and (not flt.force or e.force == flt.force)
        and e.position.x >= a[1][1] and e.position.x <= a[2][1] and e.position.y >= a[1][2] and e.position.y <= a[2][2] then
        out[#out + 1] = e
      end
    end
    return out
end
local surface = {
  find_entities_filtered = function(flt)
    bump("find_entities_filtered")
    bump(flt.type == "container" and "find_coffres" or flt.type == "inserter" and "find_bras_cj" or type(flt.type) == "table" and "find_zone_cj" or "find_lignes")
    local out = select(flt)
    bump("entites_rendues", #out)
    return out
  end,
  count_entities_filtered = function(flt) bump("count_entities_filtered") return #select(flt) end,
  create_entity = function(s) bump("create_entity") local e = new_chest(s.name, 32, s.position.x, s.position.y); WORLD[#WORLD + 1] = e; return e end,
}

package.loaded["script.ai3.places_qg"] = {
  place = function() error("les annexes passent par place_list") end,
  place_list = function(surf, name, force, origin, list, search, count, make)
    local placed = 0
    for _, o in ipairs(list) do
      if placed >= count then break end
      bump("can_place") -- le vrai essaie can_place_entity par place
      local r = make({ x = origin.x + o[1], y = origin.y + o[2] })
      if r == nil then break end
      if r then placed = placed + 1 end
    end
    return placed
  end,
}
local CJs = require("script.team.coffres_joueur")
local PLAYER = { name = "DC" }
local Stt = require("script.faction.state")
Stt.owner = function() return nil end
local A = require("shared.team.annexe")
local slots0 = A.slots
A.slots = function(...) bump("A.slots") return slots0(...) end -- places d'un bloc : recalculées à chaque appel avant le lot
local Stock = require("script.team.stock")

-- Monde : QG plein, `n_annex` annexes en fer pleines sur les places des anneaux 1..rings, `n_line` coffres du joueur dans la zone, chacun
-- avec un bras au contact (rejetés : « sur une ligne »).
local N_FREE = 23
local function build_world(n_annex, rings, n_line)
  WORLD = {}
  UNIT = 0
  local hq = new_chest("fo-team-chest", 96, 0, 0)
  hq.surface = surface
  hq.items.stone = 50 * 96
  local f = { key = "player", is_player = true, force = "player", hq = hq, hq_pos = { x = 0, y = 0 }, stats = {}, started = 0, annex = {}, annex_sy = 1,
    annex_rings = rings }
  local Sg = require("shared.team.stockage")
  local places = {}
  for r = 1, rings do for _, p in ipairs(Sg.ring_slots(1, 1, 1, r)) do places[#places + 1] = p end end
  for i = 1, math.min(n_annex, #places) do
    local p = places[i]
    local a = new_chest("iron-chest", 32, p[1] + 0.5, p[2] + 0.5)
    a.items.stone = 50 * 32
    f.annex[#f.annex + 1] = a
    WORLD[#WORLD + 1] = a
  end
  -- coffres du joueur sur des lignes, dans la zone (entre les places, décalés d'une demi-place), chacun avec un bras au contact
  for i = 1, n_line do
    local p = places[(i * 7) % #places + 1]
    local c = new_chest("iron-chest", 32, p[1] + 1.5, p[2] + 0.5)
    c.last_user = PLAYER
    c.bounding_box = { left_top = { x = c.position.x - 0.35, y = c.position.y - 0.35 }, right_bottom = { x = c.position.x + 0.35, y = c.position.y + 0.35 } }
    WORLD[#WORLD + 1] = c
    WORLD[#WORLD + 1] = { valid = true, type = "inserter", force = "player", position = { x = c.position.x + 1, y = c.position.y },
      drop_position = { x = c.position.x, y = c.position.y }, pickup_position = { x = c.position.x + 2, y = c.position.y } }
  end
  -- Base du DC (journal du 7/11, 255,4 min) : 23 coffres du joueur retenus dont 18 de dépôt : ici 23 coffres libres hors de la zone de
  -- stockage, à moins de 64 tuiles du QG.
  for i = 1, (N_FREE or 0) do
    local c = new_chest("iron-chest", 32, 40 + (i % 6) * 3, -20 + math.floor(i / 6) * 3)
    c.last_user = PLAYER
    c.bounding_box = { left_top = { x = c.position.x - 0.35, y = c.position.y - 0.35 }, right_bottom = { x = c.position.x + 0.35, y = c.position.y + 0.35 } }
    c.items["iron-plate"] = 10
    WORLD[#WORLD + 1] = c
  end
  return f
end

local function think(f, tick)
  game.tick = tick
  Stock.balance(f)
  Stock.grow(f, surface, tick)
end

-- Mesure : `n` pensées (une toutes les 300 ticks, comme think_period) ; rend le temps Lua moyen (ms), le pire, et les appels par pensée.
local function measure(f, n)
  for k in pairs(C) do C[k] = nil end
  local tick, worst, total = 1000000, 0, 0
  for _ = 1, n do
    tick = tick + 300
    local t0 = os.clock()
    think(f, tick)
    local dt = (os.clock() - t0) * 1000
    total = total + dt
    if dt > worst then worst = dt end
  end
  local per = {}
  for k, v in pairs(C) do per[k] = v / n end
  return total / n, worst, per
end

local function show(name, ms, worst, per)
  local keys = {}
  for k in pairs(per) do keys[#keys + 1] = k end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = string.format("%s %.1f", k, per[k]) end
  print(string.format("  [%s] Lua %.3f ms par pensée (pire %.3f) ; appels par pensée : %s", name, ms, worst, table.concat(parts, ", ")))
end

section("coût par pensée (moteur simulé)")
local R = {}
for _, w in ipairs({ { "dc", 20, 1, 40 }, { "borne", 240, 5, 60 } }) do
  local f = build_world(w[2], w[3], w[4])
  measure(f, 2) -- premières pensées : relevé complet, places calculées
  local ms, worst, per = measure(f, 24) -- 2 min de pensées sans changement, stock plein
  show(w[1], ms, worst, per)
  R[w[1]] = { ms = ms, worst = worst, per = per, f = f }
  -- Estimation du coût au moteur réel (DÉDUITE, pas mesurée) : Lua simulé + 10 µs par recherche, 1 µs par appel court.
  local small = (per.count_empty_stacks or 0) + (per.get_item_count or 0) + (per.insert or 0) + (per.remove_item or 0) + (per.get_contents or 0)
    + (per.count_entities_filtered or 0)
  print(string.format("  [%s] estimation au moteur réel : %.2f ms par pensée (Lua %.2f + recherches %.2f + appels courts %.2f)", w[1],
    ms + 0.010 * (per.find_entities_filtered or 0) + 0.001 * small, ms, 0.010 * (per.find_entities_filtered or 0), 0.001 * small))
end
for _, k in ipairs({ "dc", "borne" }) do
  local per = R[k].per
  check((per["A.slots"] or 0) == 0, k .. " : places des anneaux et zone calculées une seule fois (A.slots par pensée : " .. (per["A.slots"] or 0) .. ")")
  check((per.find_lignes or 0) == 0, k .. " : un coffre rejeté (sur une ligne) n'est pas réexaminé à chaque pensée (recherches de bras par pensée : "
    .. (per.find_lignes or 0) .. ")")
  check((per.find_coffres or 0) == 0, k .. " : rien n'a changé dans la zone : pas de relevé complet des coffres (" .. (per.find_coffres or 0) .. " par pensée)")
end

section("ce que le relevé doit toujours voir")
do
  local f = build_world(20, 1, 40) -- monde « dc » neuf (build_world remplace le monde de la surface)
  measure(f, 3)
  local Sg = require("shared.team.stockage")
  local tick = 2000000
  -- (a) coffre en acier posé par le joueur dans la zone, stock plein : inscrit à la pensée suivante
  -- le joueur dégage la dernière place du bloc (son coffre et son bras voisins retirés) et y pose un coffre en acier
  local p = Sg.ring_slots(1, 1, 1, 1)[48]
  for _, e in ipairs(WORLD) do
    local dx, dy = math.abs(e.position.x - (p[1] + 0.5)), math.abs(e.position.y - (p[2] + 0.5))
    if e.valid and ((dx < 1 and dy < 1) or (e.type == "inserter" and dx <= 1.7 and dy <= 1.7)) then e.valid = false end
  end
  local b = new_chest("steel-chest", 48, p[1] + 0.5, p[2] + 0.5)
  WORLD[#WORLD + 1] = b
  local n0 = #f.annex
  think(f, tick)
  local has_b = false
  for _, e in ipairs(f.annex) do if e == b then has_b = true end end
  check(has_b and #f.annex > n0, "coffre posé dans la zone, stock plein : inscrit à la pensée suivante")
  -- (b) annexe remplacée par-dessus (l'ancienne invalide, la neuve à la même place) : inscrite à la pensée suivante
  local old -- une annexe qu'aucun bras ne touche (sinon la neuve serait « sur une ligne », à bon droit)
  for _, e in ipairs(f.annex) do
    local free = e.valid and e ~= b
    for _, x in ipairs(WORLD) do
      if x.valid and x.type == "inserter" and math.abs(x.position.x - e.position.x) <= 1.7 and math.abs(x.position.y - e.position.y) <= 1.7 then free = false end
    end
    if free then old = e break end
  end
  assert(old, "monde dc : aucune annexe sans bras voisin")
  old.valid = false
  local a2 = new_chest("steel-chest", 48, old.position.x, old.position.y)
  WORLD[#WORLD + 1] = a2
  think(f, tick + 300)
  local seen = false
  for _, e in ipairs(f.annex) do if e == a2 then seen = true end end
  check(seen, "annexe remplacée par-dessus : la neuve est inscrite à la pensée suivante")
  -- (c) coffre du joueur rejeté (bras au contact) dont le bras est retiré : inscrit au relevé complet (5 min), pas avant
  local lined, arm
  for i, e in ipairs(WORLD) do
    if e.type == "inserter" then arm = e; lined = WORLD[i - 1] break end
  end
  arm.valid = false
  local t = tick + 600
  local at = nil
  for i = 1, 70 do
    think(f, t + 300 * i)
    for _, e in ipairs(f.annex) do if e == lined and not at then at = i end end
  end
  check(at ~= nil and at <= Stock.SCAN_FULL / 300 + 1, "bras retiré : le coffre est inscrit au relevé complet, au plus 5 min plus tard (pensée "
    .. tostring(at) .. ")")
end

section("rangement : s'arrête dès qu'il a la place")
do
  local f = build_world(20, 1, 0)
  for _, a in ipairs(f.annex) do a.items = {} end -- annexes vides, QG plein
  for k in pairs(C) do C[k] = nil end
  game.tick = 3000000
  local moved = Stock.balance(f)
  local need = 96 - math.floor(T.annex.park_to * 96)
  check(moved == need * 50, "le rangement libère exactement ce qu'il faut (" .. moved .. " pierres, attendu " .. need * 50 .. ")")
  check((C.count_empty_stacks or 0) <= 1 + math.ceil(need / 32), "place des annexes lue jusqu'à ce qu'il y en ait assez (" ..
    (C.count_empty_stacks or 0) .. " lectures pour " .. #f.annex .. " annexes)")
end

print(string.format("Résultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
