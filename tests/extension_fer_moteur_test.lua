--[[
  Lot EXTENSION-FER, branchement : Outposts.extend / Outposts.reopen (script/faction/outposts.lua) avec un moteur factice minimal
  (surface à collisions par tuile, gisement en tuiles, objets portés). Complète tests/pose_paires_test.lua (règle pure) :
  ici l'EXÉCUTANT est joué, y compris sur une sauvegarde d'avant le lot (avant-poste sans `ext_dead` ni `full_by`).
  Usage :  lua5.2 tests/extension_fer_moteur_test.lua   (depuis la racine du mod)
  Vérifie : lot PLAFOND-FOREUSES : agrandissements de suite à 8 foreuses chacun AU-DELÀ de l'ancien plafond de 20, jusqu'au
  balayage complet du gisement, sans recouvrement, `full_by` et `full_why` posés par la règle ; couverture Paires.KAPPA par des
  foreuses électriques : plein sans rien poser ; Outposts.uncap (migration du plafond supprimé) ;
  gisement trop petit : `full` après un balayage complet seulement, `ext_dead` vidé ; ouvrier sans objets : pas plein ; plafond d'essais :
  pas plein, reprise au même endroit ; sauvegarde ancienne (`ext_dead` absent) acceptée ; Outposts.reopen (rouvre le plein par
  l'ancien défaut, ne touche ni l'attente, ni le plein de la règle, ni le plafond) ; abonnement on_configuration_changed.
]]
package.path = "./?.lua;" .. package.path
defines = { direction = { north = 0, east = 2, south = 4, west = 6 }, inventory = { chest = 1 } }
local logs = {}
function log(s) logs[#logs + 1] = s end

local config_fns = {}
package.loaded["script.core.events"] = { on_configuration_changed = function(fn) config_fns[#config_fns + 1] = fn end }
local war = { factions = {} }
local pteam = { team = nil }
package.loaded["script.faction.state"] = {
  own = function() end,
  war = function() return war end,
  faction = function(id) if id == "player" then return pteam.team end return war.factions[id] end,
  sorted_keys = function(t) local k = {} for a in pairs(t) do k[#k + 1] = a end table.sort(k) return k end,
}
package.loaded["script.faction.sites"] = {}
package.loaded["script.ai3.places_qg"] = {}

local passes, failures = 0, 0
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. m) end end
local function section(name) print("== " .. name) end

local T = require("shared.team.config")
local P = require("shared.team.pose_paires")
local Outposts = require("script.faction.outposts")
check(#config_fns == 1, "outposts.lua s'abonne UNE fois à on_configuration_changed (à la charge du module)")

_G.game = { tick = 0, entity_prototypes = { [T.DRILL] = { tile_width = 2, tile_height = 2 } } }

local SPEC = T.outposts.iron
local HALF = { [T.DRILL] = 0.7, ["stone-furnace"] = 0.7, ["iron-chest"] = 0.35 }
local TYPE = { [T.DRILL] = "mining-drill", ["stone-furnace"] = "furnace", ["iron-chest"] = "container" }

--- Surface factice : `side` x `side` tuiles de minerai centrées sur (0, 0) ; collisions par tuile entre les objets posés.
local function world(side)
  local ents, uid = {}, 0
  for ix = 0, side - 1 do
    for iy = 0, side - 1 do
      ents[#ents + 1] = { name = SPEC.resource, type = "resource", valid = true,
        position = { x = ix - side / 2 + 0.5, y = iy - side / 2 + 0.5 } }
    end
  end
  local s = { ents = ents, creates = 0, can_place_calls = 0 }
  local function box_of(name, pos)
    local h = HALF[name]
    return P.box_tiles(pos.x - h, pos.y - h, pos.x + h, pos.y + h)
  end
  local function taken()
    local t = {}
    for _, e in ipairs(ents) do
      if e.valid and e.type ~= "resource" then
        for _, k in ipairs(box_of(e.name, e.position)) do t[k] = true end
      end
    end
    return t
  end
  s.find_entities_filtered = function(q)
    local out = {}
    local types
    if type(q.type) == "table" then types = {} for _, ty in ipairs(q.type) do types[ty] = true end
    elseif q.type then types = { [q.type] = true } end
    for _, e in ipairs(ents) do
      local ok = e.valid
      if ok and q.name and e.name ~= q.name then ok = false end
      if ok and types and not types[e.type] then ok = false end
      if ok and q.position and q.radius then
        ok = (e.position.x - q.position.x) ^ 2 + (e.position.y - q.position.y) ^ 2 <= q.radius ^ 2
      end
      if ok and q.area then
        ok = e.position.x >= q.area[1][1] and e.position.x <= q.area[2][1] and e.position.y >= q.area[1][2] and e.position.y <= q.area[2][2]
      end
      if ok then out[#out + 1] = e end
    end
    return out
  end
  s.can_place_entity = function(q)
    s.can_place_calls = s.can_place_calls + 1
    local t = taken()
    for _, k in ipairs(box_of(q.name, q.position)) do if t[k] then return false end end
    return true
  end
  s.create_entity = function(q)
    uid = uid + 1
    s.creates = s.creates + 1
    local h = HALF[q.name]
    local e = { name = q.name, type = TYPE[q.name], position = { x = q.position.x, y = q.position.y }, valid = true, unit_number = uid,
      bounding_box = { left_top = { x = q.position.x - h, y = q.position.y - h }, right_bottom = { x = q.position.x + h, y = q.position.y + h } },
      get_fuel_inventory = function() return { insert = function() end } end }
    e.destroy = function() e.valid = false end
    ents[#ents + 1] = e
    return e
  end
  return s
end

--- Objets portés : `drills` foreuses et autant de fours (chaque pose en retire un de chaque).
local function carrier(drills, furnaces)
  local c = { items = { [T.DRILL] = drills, [SPEC.sink] = furnaces or drills, wood = 0, coal = 0 } }
  c.get_item_count = function(n) return c.items[n] or 0 end
  c.remove = function(q) c.items[q.name] = (c.items[q.name] or 0) - q.count return q.count end
  c.insert = function(q) c.items[q.name] = (c.items[q.name] or 0) + q.count return q.count end
  return c
end

local function new_outpost(over)
  local o = { id = 7, kind = "iron", pos = { x = 0, y = 0 }, drills = 0, drill_list = {}, sinks = {} }
  for k, v in pairs(over or {}) do o[k] = v end
  return o
end
local function fac() return { force = "f1", key = "A", id = 1, turrets = {}, outposts = {}, stats = {} } end

--- Recouvrement : une tuile n'appartient qu'à un seul objet posé.
local function overlaps(s)
  local seen, dup = {}, 0
  for _, e in ipairs(s.ents) do
    if e.valid and e.type ~= "resource" then
      for _, k in ipairs(P.box_tiles(e.bounding_box.left_top.x, e.bounding_box.left_top.y, e.bounding_box.right_bottom.x, e.bounding_box.right_bottom.y)) do
        if seen[k] then dup = dup + 1 end
        seen[k] = true
      end
    end
  end
  return dup
end

---------------------------------------------------------------------------------------------------
section("1. Gisement large : 8 + 8 + 8 foreuses, AU-DELÀ de l'ancien plafond de 20, puis plein au balayage complet")
do
  check(T.max_drills("iron") == math.huge and T.max_drills("coal") == math.huge and T.max_drills("stone") == math.huge,
    "plus de plafond de foreuses, pour aucun minerai")
  local s, f, o, c = world(40), fac(), new_outpost(), carrier(400)
  local n1 = Outposts.extend(f, s, o, c)
  check(n1 == 8 and o.drills == 8 and not o.full, "1er agrandissement depuis un avant-poste vide : 8 posées, pas plein (" .. n1 .. ")")
  local n2 = Outposts.extend(f, s, o, c)
  check(n2 == 8 and o.drills == 16 and not o.full, "2e agrandissement : 8 de plus (reprend où le 1er s'est arrêté)")
  local n3 = Outposts.extend(f, s, o, c)
  check(n3 == 8 and o.drills == 24 and not o.full, "3e : 8 de plus, 24 > ancien plafond de 20, pas plein (" .. n3 .. ")")
  local calls = 3
  while not o.full and calls < 60 do
    Outposts.extend(f, s, o, c)
    calls = calls + 1
  end
  check(o.full and o.full_by == "pose_paires" and o.full_why == "gisement", "plein par le balayage complet (" .. tostring(o.full_why) .. ")")
  check(o.drills > 100, "gisement de 40 x 40 exploité : " .. o.drills .. " foreuses (20 avant le lot)")
  check(#o.drill_list == o.drills and #o.sinks == o.drills, "listes de l'avant-poste tenues à jour")
  check(overlaps(s) == 0, "aucun recouvrement entre les " .. (2 * o.drills) .. " objets posés")
  check(f.stats.extend_full == 1 and #logs >= 3, "compteurs et journal [FO-EXTEND]")
  check(logs[#logs]:find("%[FO%-EXTEND%]") and logs[#logs]:find("plein=oui") and logs[#logs]:find("couverture %d+/800 pour mille"),
    "dernière ligne du journal : plein=oui, couverture en pour mille")
  local cov = logs[#logs]:match("couverture (%d+)/")
  check(cov and tonumber(cov) < P.KAPPA, "foreuses à combustible en paires : couverture " .. tostring(cov) .. " pour mille, sous P.KAPPA (le balayage arrête)")
  print("  (gisement de 40 x 40 : " .. o.drills .. " foreuses en " .. calls .. " agrandissements, couverture " .. tostring(cov) .. " pour mille)")
end

---------------------------------------------------------------------------------------------------
section("2. Agrandissement d'un avant-poste déjà garni : les emplacements pris ne coûtent rien")
do
  local s, f, o, c = world(40), fac(), new_outpost(), carrier(40)
  Outposts.extend(f, s, o, c) -- la « construction » : 8 paires autour du centre
  o.full, o.full_by, o.ext_dead, o.ext_fails = nil, nil, nil, nil -- état d'une sauvegarde d'avant le lot
  s.can_place_calls = 0
  local n = Outposts.extend(f, s, o, c)
  check(n == 8, "sauvegarde ancienne (aucun ext_dead) : l'agrandissement pose 8 foreuses de plus (ancien code : 0, plein)")
  check(s.can_place_calls <= P.MAX_ATTEMPTS * 8, "essais au moteur bornés par le plafond d'essais (" .. s.can_place_calls .. ")")
  check(overlaps(s) == 0, "toujours aucun recouvrement")
end

---------------------------------------------------------------------------------------------------
section("3. Gisement trop petit : plein seulement après un balayage complet")
do
  local s, f, o, c = world(6), fac(), new_outpost(), carrier(40)
  local total, calls = 0, 0
  while not o.full and calls < 10 do
    total = total + Outposts.extend(f, s, o, c)
    calls = calls + 1
  end
  check(o.full and o.full_by == "pose_paires" and o.drills == total and total >= 1 and total < T.max_drills("iron"),
    "gisement de 6 x 6 : " .. total .. " foreuses posées puis plein sans atteindre le plafond")
  check(o.ext_dead == nil, "balayage complet : mémoire des échecs vidée")
  check(logs[#logs]:find("gisement"), "journal : motif « gisement »")
end

---------------------------------------------------------------------------------------------------
section("4. Ouvrier sans objets : pas plein ; plafond d'essais : pas plein, reprise")
do
  local s, f, o = world(40), fac(), new_outpost()
  local n = Outposts.extend(f, s, o, carrier(0))
  check(n == 0 and not o.full, "aucune foreuse portée : rien posé, PAS plein (l'ancien code disait plein)")
  check(logs[#logs]:find("objets"), "journal : motif « objets »")
  -- deux foreuses portées seulement
  local o2, c2 = new_outpost({ id = 8 }), carrier(2)
  local n2 = Outposts.extend(f, s, o2, c2)
  check(n2 == 2 and not o2.full, "deux foreuses portées : 2 posées, pas plein")
end

---------------------------------------------------------------------------------------------------
section("5. Outposts.reopen : seul le plein de l'ancien défaut est rouvert")
do
  local f = fac()
  f.outposts = {
    [1] = { id = 1, kind = "iron", drills = 8, full = true },                                       -- ancien défaut : rouvert
    [2] = { id = 2, kind = "iron", drills = 8, full = true, full_by = "pose_paires" },              -- plein par la règle : laissé
    [3] = { id = 3, kind = "iron", drills = 8, full = true, hold_until = 99999 },                    -- en attente (ADOPTE) : laissé
    [4] = { id = 4, kind = "iron", drills = 20, full = true },                                       -- à l'ancien plafond : rouvert (PLAFOND-FOREUSES)
    [5] = { id = 5, kind = "iron", drills = 8, full = false },                                       -- ouvert : inchangé
    [6] = { id = 6, kind = "coal", drills = 4, full = true, ext_dead = { [1] = true } },             -- rouvert, mémoire vidée
  }
  local n = Outposts.reopen(f)
  check(n == 3, "3 avant-postes rouverts (" .. n .. ")")
  check(not f.outposts[1].full and not f.outposts[6].full and f.outposts[6].ext_dead == nil, "1 et 6 rouverts, mémoire de 6 vidée")
  check(not f.outposts[4].full, "4 (ancien plafond, plafond supprimé) rouvert")
  check(f.outposts[2].full and f.outposts[3].full, "2 (règle), 3 (attente) intacts")
  check(not f.outposts[5].full, "5 inchangé")
  check(Outposts.reopen(f) == 0, "idempotent : un second passage ne rouvre rien")
  check(Outposts.reopen({}) == 0, "équipe sans avant-postes : 0")
end

---------------------------------------------------------------------------------------------------
section("6. Abonnement on_configuration_changed : factions et équipe du joueur, journal, aucun effet sans avant-poste")
do
  logs = {}
  war.factions = {
    [2] = { id = 2, outposts = { [1] = { id = 1, kind = "iron", drills = 8, full = true } } },
    [1] = { id = 1, outposts = { [1] = { id = 1, kind = "iron", drills = 8, full = true }, [2] = { id = 2, kind = "iron", drills = 8, full = true } } },
  }
  pteam.team = { outposts = { [1] = { id = 1, kind = "copper", drills = 3, full = true } } }
  config_fns[1]({})
  local open = 0
  for _, id in ipairs({ 1, 2 }) do
    for _, o in pairs(war.factions[id].outposts) do if not o.full then open = open + 1 end end
  end
  check(open == 3 and not pteam.team.outposts[1].full, "3 avant-postes de factions et celui de l'équipe du joueur rouverts")
  check(logs[1] and logs[1]:find("4 avant%-poste"), "journal de migration : 4 avant-poste(s)")
  logs = {}
  config_fns[1]({})
  check(#logs == 0, "second passage : rien rouvert, aucun message")
  war.factions, pteam.team = {}, nil
  local ok = pcall(config_fns[1], {})
  check(ok, "aucune guerre, aucune équipe : sans erreur")
end

---------------------------------------------------------------------------------------------------
section("7. Lot PLAFOND-FOREUSES : Outposts.uncap rouvre ce que l'ancien plafond avait fermé, rien d'autre")
do
  local f = fac()
  f.outposts = {
    [1] = { id = 1, kind = "iron", drills = 20, full = true, full_by = "pose_paires" },                    -- ancien plafond du fer : rouvert
    [2] = { id = 2, kind = "iron", drills = 14, full = true, full_by = "pose_paires" },                    -- balayage sous le plafond : laissé
    [3] = { id = 3, kind = "stone", drills = 8, full = true, full_by = "pose_paires" },                    -- ancien plafond de la pierre : rouvert
    [4] = { id = 4, kind = "coal", drills = 12, full = true, full_by = "pose_paires", ext_dead = { [5] = true } }, -- charbon (12) : rouvert, mémoire gardée
    [5] = { id = 5, kind = "iron", drills = 30, full = true, full_by = "pose_paires", full_why = "gisement" }, -- plein du nouveau verdict : laissé
    [6] = { id = 6, kind = "iron", drills = 20, full = true, full_by = "pose_paires", hold_until = 5 },     -- en attente : laissé
    [7] = { id = 7, kind = "iron", drills = 20, full = true, full_by = "migration", migr = "fini" },        -- migré : laissé
    [8] = { id = 8, kind = "copper", drills = 11, full = true, full_by = "pose_paires" },                  -- cuivre sous 12 : laissé
  }
  local n = Outposts.uncap(f)
  check(n == 3, "3 avant-postes rouverts (" .. n .. ")")
  check(not f.outposts[1].full and not f.outposts[3].full and not f.outposts[4].full and f.outposts[4].ext_dead ~= nil,
    "1 (fer 20), 3 (pierre 8), 4 (charbon 12) rouverts ; mémoire des échecs gardée")
  check(f.outposts[2].full and f.outposts[5].full and f.outposts[6].full and f.outposts[7].full and f.outposts[8].full, "2, 5, 6, 7, 8 intacts")
  check(Outposts.uncap(f) == 0, "idempotent")
  -- refermé ensuite par le balayage : full_why posé, plus jamais rouvert par la migration
  local s, o = world(4), new_outpost({ id = 9 })
  local c = carrier(40)
  local guard = 0
  while not o.full and guard < 10 do Outposts.extend(f, s, o, c) guard = guard + 1 end
  check(o.full and o.full_why ~= nil, "plein du nouveau verdict : motif écrit (" .. tostring(o.full_why) .. ")")
  o.drills = 25
  f.outposts = { [9] = o }
  check(Outposts.uncap(f) == 0, "un plein du nouveau verdict n'est jamais rouvert par la migration")
  -- journal de la migration
  logs = {}
  war.factions = { [1] = { id = 1, outposts = { [1] = { id = 1, kind = "iron", drills = 20, full = true, full_by = "pose_paires" } } } }
  config_fns[1]({})
  check(not war.factions[1].outposts[1].full, "abonnement : rouvert à la migration")
  local seen = false
  for _, l in ipairs(logs) do if l:find("%[FO%-PLAFOND%] migration : 1 avant%-poste") then seen = true end end
  check(seen, "journal [FO-PLAFOND] de la migration")
  war.factions = {}
end

---------------------------------------------------------------------------------------------------
section("8. Lot PLAFOND-FOREUSES : gisement couvert à P.KAPPA par des foreuses électriques : plein sans rien poser")
do
  local s, f = world(10), fac()
  local function electric(x, y)
    return { valid = true, position = { x = x, y = y }, prototype = { mining_drill_radius = 2.49 },
      bounding_box = { left_top = { x = x - 1.4, y = y - 1.4 }, right_bottom = { x = x + 1.4, y = y + 1.4 } } }
  end
  local o = new_outpost({ id = 11, drills = 4, drill_list = { electric(-2.5, -2.5), electric(2.5, -2.5), electric(-2.5, 2.5), electric(2.5, 2.5) } })
  local before = s.creates
  local n = Outposts.extend(f, s, o, carrier(40))
  check(n == 0 and s.creates == before, "rien posé (" .. n .. ")")
  check(o.full and o.full_why == "couverture", "plein par la couverture (" .. tostring(o.full_why) .. ")")
  check(logs[#logs]:find("couverture 1000/800"), "journal : couverture 1000 pour mille")
  -- moitié couverte : l'agrandissement pose
  local s2 = world(10)
  local o2 = new_outpost({ id = 12, drills = 2, drill_list = { electric(-2.5, -2.5), electric(2.5, -2.5) } })
  local n2 = Outposts.extend(f, s2, o2, carrier(40))
  check(n2 > 0 and not o2.full, "gisement couvert à moitié : " .. n2 .. " paire(s) posée(s), pas plein")
end

---------------------------------------------------------------------------------------------------
section("9. Lot PLAFOND-FOREUSES : charbon insuffisant pour un grand avant-poste : le plus à court d'abord")
do
  local function burner(kind, fuel)
    local e = { valid = true, type = kind, burner = true, fuel = fuel }
    e.get_fuel_inventory = function()
      return { get_item_count = function() return e.fuel end, insert = function(q) e.fuel = e.fuel + q.count return q.count end }
    end
    e.get_output_inventory = function() return { get_contents = function() return {} end } end
    return e
  end
  -- 3 foreuses pleines à 6, 2 fours vides : 12 charbons portés (l'ancien ordre : 4 + 4 + 4 aux foreuses, fours à 0)
  local o = { drill_list = { burner("mining-drill", 6), burner("mining-drill", 6), burner("mining-drill", 6) },
    sinks = { burner("furnace", 0), burner("furnace", 0) } }
  local c = carrier(0)
  c.items[T.fuel] = 12
  Outposts.service(o, c, 1)
  check(o.sinks[1].fuel == 10 and o.sinks[2].fuel == 2, "fours vides servis d'abord (" .. o.sinks[1].fuel .. ", " .. o.sinks[2].fuel .. ")")
  check(o.drill_list[1].fuel == 6 and o.drill_list[2].fuel == 6, "foreuses encore à 6 attendent la tournée suivante")
  check(c.items[T.fuel] == 0, "tout le charbon porté est posé")
  check(o.coal_short == 1, "le second four reste à 2, sous T.fuel_low : tournée courte comptée")
  -- 3 fours vides et 5 charbons : 2 restent sous T.fuel_low, tournée courte comptée et journalisée
  logs = {}
  local o2 = { drill_list = {}, sinks = { burner("furnace", 0), burner("furnace", 0), burner("furnace", 0) } }
  local c2 = carrier(0)
  c2.items[T.fuel] = 5
  Outposts.service(o2, c2, 2)
  check(o2.coal_short == 1 and logs[#logs] and logs[#logs]:find("%[FO%-CHARBON%]") and logs[#logs]:find("2 bruleur%(s%) sur 3"),
    "tournée courte : o.coal_short = 1, journal [FO-CHARBON] (" .. tostring(logs[#logs]) .. ")")
end

print(string.format("\n[EXTENSION-FER-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
