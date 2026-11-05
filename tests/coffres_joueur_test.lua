--[[
  Tests hors jeu du lot COFFRES-JOUEUR : les coffres posés par le joueur dans sa base comptent dans le stock de votre équipe, en
  lecture et en prise (jamais en dépôt). Règle pure : shared/team/coffres_joueur.lua ; branchement : script/team/coffres_joueur.lua,
  script/team/stock.lua (Stock.count, Stock.remove, Stock.contents).
  Usage, depuis la racine du mod :   lua5.2 tests/coffres_joueur_test.lua

  Remarque du DC (5/11, essai 0.6.53) : « Les ressources dans les coffres que j'ai posés n'ont jamais été utilisées, jamais, pas une
  fois. » Cas reproduit : un coffre du joueur plein de fer, une prise de fer que le coffre du QG ne peut pas servir.
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local CJ = require("shared.team.coffres_joueur")
local A = require("shared.faction.adversaire")

---------------------------------------------------------------------------------------------------
section("Règle pure : verdict")
do
  local base = { by_player = true, in_base = true }
  local function v(over)
    local c = {}
    for k, x in pairs(base) do c[k] = x end
    for k, x in pairs(over or {}) do c[k] = x end
    return CJ.verdict(c)
  end
  local ok, r = v()
  check(ok and r == "stock", "coffre posé par le joueur, dans la base : stock")
  ok, r = v({ by_player = false })
  check(not ok and r == "equipe", "coffre posé par l'équipe : ses tournées le gèrent")
  ok, r = v({ in_base = false })
  check(not ok and r == "hors-base", "hors de la base : non")
  ok, r = v({ mode = "requester" })
  check(not ok and r == "demande", "coffre demandeur : non")
  ok, r = v({ mode = "buffer" })
  check(not ok and r == "demande", "coffre tampon logistique : non")
  ok, r = v({ mode = "storage" })
  check(ok, "coffre de stockage logistique (filtré ou non) : oui")
  ok, r = v({ mode = "passive-provider" })
  check(ok, "coffre fournisseur passif : oui")
  ok, r = v({ feeds = true })
  check(not ok and r == "tampon", "un bras prend dedans (tampon d'une chaîne du joueur) : non")
  ok, r = v({ adopted = true })
  check(not ok and r == "avant-poste", "réception d'une foreuse adoptée : non")
end

section("Règle pure : ordre et plafond")
do
  local list = {}
  for i = 1, 5 do list[#list + 1] = { id = 10 - i, d2 = (i % 3) * 100, by_player = true, in_base = true } end
  list[#list + 1] = { id = 1, d2 = 0, by_player = false, in_base = true }
  local keep, why = CJ.select(list, 3)
  -- distances² : id 9 -> 100, 8 -> 200, 7 -> 0, 6 -> 100, 5 -> 200 ; id 1 (posé par l'équipe) -> 0.
  check(#keep == 3 and keep[1].id == 7 and keep[2].id == 6 and keep[3].id == 9,
    "du plus proche du QG au plus lointain, numéro à égalité (7, puis 6 et 9 à 100) ; plafond tenu")
  check(why.stock == 3 and why.plafond == 2 and why.equipe == 1, "motifs comptés (stock 3, plafond 2, équipe 1)")
end

---------------------------------------------------------------------------------------------------
section("Stock avec des coffres simulés")
defines = { inventory = { chest = 1 } }
game = { tick = 0, item_prototypes = setmetatable({}, { __index = function() return { stack_size = 100 } end }) }
local logs = {}
function log(s) logs[#logs + 1] = s end

local next_unit = 100
local function new_chest(size, x, y, opts)
  opts = opts or {}
  next_unit = next_unit + 1
  local e = { valid = true, items = {}, size = size, unit_number = next_unit, position = { x = x or 0, y = y or 0 },
    type = opts.type or "container", last_user = opts.last_user, prototype = { logistic_mode = opts.mode } }
  e.bounding_box = { left_top = { x = e.position.x - 0.4, y = e.position.y - 0.4 }, right_bottom = { x = e.position.x + 0.4, y = e.position.y + 0.4 } }
  local function slots()
    local n = 0
    for _, v in pairs(e.items) do n = n + math.ceil(v / 100) end
    return n
  end
  local inv = {}
  setmetatable(inv, { __len = function() return size end })
  inv.count_empty_stacks = function() return size - slots() end
  inv.is_empty = function() return next(e.items) == nil end
  inv.get_contents = function()
    local out = {}
    for k, v in pairs(e.items) do out[k] = v end
    return out
  end
  inv.remove = function(s) return e.remove_item(s) end
  e.get_inventory = function() return inv end
  e.get_item_count = function(name) return e.items[name] or 0 end
  e.remove_item = function(s)
    local n = math.min(s.count, e.items[s.name] or 0)
    if n > 0 then e.items[s.name] = e.items[s.name] - n; if e.items[s.name] == 0 then e.items[s.name] = nil end end
    return n
  end
  e.insert = function(s)
    local have = e.items[s.name] or 0
    local room = (math.ceil(have / 100) * 100 - have) + (size - slots()) * 100
    local n = math.min(s.count, room)
    if n > 0 then e.items[s.name] = have + n end
    return n
  end
  return e
end

-- Surface simulée : les coffres de la force et les bras posés.
local function new_surface(force)
  local s = { chests = {}, inserters = {}, finds = 0 }
  s.find_entities_filtered = function(t)
    s.finds = s.finds + 1
    if t.type == "inserter" then return s.inserters end
    local out = {}
    for _, e in ipairs(s.chests) do
      local p = e.position
      if e.valid and e.force == t.force and p.x >= t.area[1][1] and p.x <= t.area[2][1] and p.y >= t.area[1][2] and p.y <= t.area[2][2] then
        out[#out + 1] = e
      end
    end
    return out
  end
  return s
end

package.loaded["script.ai3.places_qg"] = { place = function() end, place_list = function() return 0 end }
local Stock = require("script.team.stock")
local CJs = require("script.team.coffres_joueur")
local PLAYER = { name = "DC" }

local function team(surface, hq_items)
  local hq = new_chest(10, 6, 6)
  hq.surface, hq.force = surface, "player"
  for k, v in pairs(hq_items or {}) do hq.items[k] = v end
  return { key = "player", is_player = true, force = "player", hq = hq, hq_pos = { x = 6, y = 6 }, annex = {}, stats = {}, started = 0 }
end
local function player_chest(surface, x, y, items, opts)
  opts = opts or {}
  local user = PLAYER
  if opts.team then user = nil end -- posé par l'équipe : aucun dernier utilisateur
  local e = new_chest(32, x, y, { type = opts.type, mode = opts.mode, last_user = user })
  e.force = opts.force or "player"
  for k, v in pairs(items or {}) do e.items[k] = v end
  surface.chests[#surface.chests + 1] = e
  return e
end

-- Le cas du DC : un coffre du joueur plein de fer (sortie de sa fonderie), le coffre du QG sans fer ; l'équipe a besoin de 50 fers.
do
  game.tick = 0
  local s = new_surface()
  local f = team(s, { ["iron-plate"] = 0, coal = 10 })
  local pc = player_chest(s, 20, 10, { ["iron-plate"] = 200 })
  check(Stock.count(f, "iron-plate") == 200, "le fer du coffre du joueur compte dans le stock (" .. Stock.count(f, "iron-plate") .. ")")
  local got = Stock.remove(f, "iron-plate", 50)
  check(got == 50 and pc.items["iron-plate"] == 150, string.format("une prise de 50 fers manquant au QG : prise dans le coffre du joueur (%d pris, %s restent)",
    got, tostring(pc.items["iron-plate"])))
  local c = Stock.contents(f)
  check(c["iron-plate"] == 150 and c.coal == 10, "contenu du stock : QG et coffre du joueur")
end

-- Ordre : le coffre du QG d'abord, puis le coffre du joueur ; jamais de dépôt chez le joueur.
do
  game.tick = 0
  local s = new_surface()
  local f = team(s, { ["iron-plate"] = 30 })
  local pc = player_chest(s, 20, 10, { ["iron-plate"] = 200 })
  check(Stock.remove(f, "iron-plate", 50) == 50 and f.hq.items["iron-plate"] == nil and pc.items["iron-plate"] == 180,
    "prise : le QG d'abord (30), puis le coffre du joueur (20)")
  for k in pairs(f.hq.items) do f.hq.items[k] = nil end
  f.hq.items.stone = 1000 -- coffre du QG plein (10 cases de 100)
  local put = Stock.insert(f, "iron-plate", 100)
  check(put == 0 and pc.items["iron-plate"] == 180, "dépôt : jamais dans le coffre du joueur (QG plein : rien déposé)")
  check(#Stock.inventories(f) == 1, "inventaires du stock (dépôts du moteur) : sans le coffre du joueur")
end

-- Exceptions : posé par l'équipe, hors de la base, demandeur, tampon d'une chaîne, réception d'une foreuse adoptée, autre force.
do
  game.tick = 0
  local s = new_surface()
  local f = team(s, {})
  player_chest(s, 12, 8, { ["iron-plate"] = 7 }, { team = true })
  player_chest(s, 66, 66, { ["iron-plate"] = 11 }) -- dans la boîte de recherche, à 85 tuiles du QG : hors de la base
  player_chest(s, 14, 8, { ["iron-plate"] = 13 }, { type = "logistic-container", mode = "requester" })
  local buf = player_chest(s, 16, 8, { ["iron-plate"] = 17 })
  s.inserters[1] = { valid = true, pickup_target = buf }
  local sink = player_chest(s, 18, 8, { ["iron-plate"] = 19 })
  f.adopt = { drills = { [55] = { oid = 1, sink = sink.unit_number } } }
  player_chest(s, 8, 8, { ["iron-plate"] = 23 }, { force = "fo-scarlet" })
  local ok = player_chest(s, 10, 8, { ["iron-plate"] = 29 }, { type = "logistic-container", mode = "storage" })
  check(Stock.count(f, "iron-plate") == 29, "seul le coffre de stockage du joueur compte (29), pas les 6 exceptions (" .. Stock.count(f, "iron-plate") .. ")")
  local last = logs[#logs] or ""
  local function has(t) return last:find(t, 1, true) ~= nil end
  check(has("[FO-COFFRES-JOUEUR]") and has("stock 1") and has("equipe 1") and has("hors-base 1") and has("demande 1") and has("tampon 1")
    and has("avant-poste 1"), "journal : motifs comptés (" .. last .. ")")
  check(ok.items["iron-plate"] == 29, "coffre retenu intact tant que rien n'est pris")
end

-- Zone du départ (lot QG-ZONE) : un coffre dans la base qui a grandi au-delà de 64 tuiles compte ; la boîte de la zone borne la recherche.
do
  game.tick = 0
  local s = new_surface()
  local f = team(s, {})
  local far = player_chest(s, 200, 6, { ["iron-plate"] = 40 })
  local cells = { [A.cell_key(A.cell_of(200, 6))] = true }
  CJs.base = function() return cells, { { x = 0, y = 0 }, { x = 6, y = 6 } }, { 0, 0, 208, 16 } end
  check(Stock.count(f, "iron-plate") == 40, "coffre dans la zone du départ, à 194 tuiles du QG : compte")
  cells = {}
  game.tick = CJ.REFRESH
  check(Stock.count(f, "iron-plate") == 0, "hors de la zone (même place, zone recalculée) : ne compte plus")
  CJs.base = nil
end

-- Coût : liste refaite au plus toutes les CJ.REFRESH ticks ; CJ.MAX coffres au plus, les plus proches du QG.
do
  game.tick = 0
  local s = new_surface()
  local f = team(s, {})
  for i = 1, CJ.MAX + 8 do player_chest(s, 6 + i, 20, { ["iron-plate"] = 1 }) end
  check(Stock.count(f, "iron-plate") == CJ.MAX, "plafond : " .. CJ.MAX .. " coffres du joueur lus au plus")
  local f0 = s.finds
  for t = 1, CJ.REFRESH - 1, 97 do game.tick = t; Stock.count(f, "iron-plate") end
  check(s.finds == f0, "aucune recherche avant " .. CJ.REFRESH .. " ticks")
  game.tick = CJ.REFRESH
  Stock.count(f, "iron-plate")
  check(s.finds > f0, "liste refaite après " .. CJ.REFRESH .. " ticks")
  local list = f.coffres_joueur.list
  check(#list == CJ.MAX and list[1].position.x == 7 and list[CJ.MAX].position.x == 6 + CJ.MAX, "les plus proches du QG d'abord")
  list[1].valid = false
  check(Stock.count(f, "iron-plate") == CJ.MAX - 1, "coffre disparu : retiré de la liste aussitôt")
end

-- Parité : une faction n'a pas de joueur ; le même coffre à côté de son QG ne change rien.
do
  game.tick = 0
  local s = new_surface()
  local g = team(s, { ["iron-plate"] = 5 })
  g.is_player, g.key, g.force = nil, "scarlet", "fo-scarlet"
  g.hq.force = "fo-scarlet"
  player_chest(s, 10, 8, { ["iron-plate"] = 100 }, { force = "fo-scarlet" })
  local f0 = s.finds
  check(Stock.count(g, "iron-plate") == 5 and Stock.remove(g, "iron-plate", 50) == 5 and s.finds == f0 and g.coffres_joueur == nil,
    "faction : le stock est son coffre seul (aucune recherche, aucun état)")
  check(CJs.chests(g) == CJs.chests({}) and #CJs.chests(g) == 0, "faction : liste vide (même table, aucune allocation)")
end

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
