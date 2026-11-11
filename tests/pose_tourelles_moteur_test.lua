--[[
  Lot TOURELLES, branchement : Outposts.fortify (script/faction/outposts.lua) avec un moteur factice minimal.
  Usage :  lua5.2 tests/pose_tourelles_moteur_test.lua
  Vérifie : mêmes emplacements qu'avant sans bâtiment lointain (ancien ordre), tourelle du côté du bâtiment lointain, nombre posé
  inchangé et limité par les objets portés, repli si le moteur refuse une pose, QG (sans id), rien de posé sans objet, journal.
]]
package.path = "./?.lua;" .. package.path
defines = { direction = { north = 0, east = 2, south = 4, west = 6 }, inventory = { chest = 1 } }
local logs = {}
function log(s) logs[#logs + 1] = s end
package.loaded["script.faction.state"] = { own = function() end, sorted_keys = function(t) local k = {} for a in pairs(t) do k[#k + 1] = a end table.sort(k) return k end }
package.loaded["script.faction.sites"] = {}
package.loaded["script.ai3.places_qg"] = { on_resource = function() return false end } -- (lot DECOUPLAGE : sol sans ressource)
package.loaded["shared.ai3.places"] = package.loaded["shared.ai3.places"] or nil

local passes, failures = 0, 0
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. m) end end

local T = require("shared.team.config")
local Outposts = require("script.faction.outposts")

local function bbox(x, y, s) return { left_top = { x = x - s / 2, y = y - s / 2 }, right_bottom = { x = x + s / 2, y = y + s / 2 } } end

local function world(buildings, refuse)
  local placed = {}
  local surface = {}
  surface.find_non_colliding_position = function(_, c) return { x = c.x, y = c.y } end
  -- lot CC-TOURELLES (F489) : la pose d'un avant-poste lit le minerai sous l'emprise (vrai moteur : toujours présent) ; aucun minerai ici
  surface.count_entities_filtered = function(q) return 0 end
  surface.find_entities_filtered = function(q)
    local out = {}
    if q.name then for _, p in ipairs(placed) do out[#out + 1] = p end return out end
    for _, b in ipairs(buildings) do out[#out + 1] = b end
    return out
  end
  surface.create_entity = function(q)
    if refuse and refuse[#placed + 1 + (refuse.n or 0)] and not refuse.done then refuse.done = true return nil end
    local e = { name = q.name, position = q.position, unit_number = 1000 + #placed, valid = true,
      get_item_count = function() return 0 end, insert = function() end }
    placed[#placed + 1] = e
    return e
  end
  return surface, placed
end
local function building(x, y, ty, s, un) return { position = { x = x, y = y }, type = ty, bounding_box = bbox(x, y, s), unit_number = un } end
local function carrier(n) local c = { n = n }
  c.get_item_count = function(name) return name == "gun-turret" and c.n or 0 end
  c.remove = function(q) if q.name == "gun-turret" then c.n = c.n - q.count end return q.count end
  return c
end
_G.game = { entity_prototypes = { ["gun-turret"] = { turret_range = 18 } } }
local function fac() return { force = "f1", key = "A", id = 1, turrets = {}, outposts = {}, stats = {} } end

-- 1. Aucun bâtiment lointain : l'ancien premier emplacement (7,7)
do
  local s, placed = world({ building(0, 0, "mining-drill", 3, 1) })
  local n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 1, carrier(5))
  check(n == 1 and placed[1].position.x == 7 and placed[1].position.y == 7, "petit avant-poste : (7,7) comme avant")
end
-- 2. Bâtiment lointain au nord-ouest
do
  local s, placed = world({ building(0, 0, "mining-drill", 3, 1), building(-14, -14, "mining-drill", 3, 2) })
  local n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 1, carrier(5))
  check(n == 1 and placed[1].position.x == -7 and placed[1].position.y == -7, "bâtiment au nord-ouest : (-7,-7)")
end
-- 3. Deux tourelles, deux côtés
do
  local s, placed = world({ building(0, 0, "lab", 3, 1), building(-14, -14, "mining-drill", 3, 2), building(14, 14, "furnace", 2, 3) })
  local n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 2, carrier(5))
  check(n == 2 and placed[1].position.x ~= placed[2].position.x, "deux côtés couverts")
end
-- 4. Limité par les objets portés et par le nombre voulu
do
  local s, placed = world({ building(0, 0, "mining-drill", 3, 1) })
  local c = carrier(1)
  local n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 3, c)
  check(n == 1 and c.n == 0, "une seule tourelle portée : une seule posée")
  n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 3, carrier(0))
  check(n == 0, "aucune tourelle portée : rien posé")
end
-- 5. Repli : le moteur refuse la première pose
do
  local s, placed = world({ building(0, 0, "mining-drill", 3, 1) }, { [1] = true })
  local n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 1, carrier(5))
  check(n == 1 and #placed == 1, "pose refusée une fois : le candidat suivant est essayé")
end
-- 6. QG (sans id) et journal
do
  local s, placed = world({ building(0, 0, "container", 2, 77), building(-20, 0, "furnace", 2, 3) })
  local f = fac()
  f.hq = { valid = true, unit_number = 77 }
  logs = {}
  local n = Outposts.fortify(f, s, { pos = { x = 0, y = 0 } }, 1, carrier(5))
  check(n == 1 and placed[1].position.x == -9 and placed[1].position.y == 0, "QG : (-9,0) couvre le coffre et le four lointain")
  -- (lot PD-ESPACEMENT : la pose écrit aussi une ligne [FO-TOUR-ECART], après celle-ci)
  check(#logs == 2 and logs[1]:find("%[FO%-TOUR%-POSE%]") and logs[1]:find("QG") and logs[2]:find("%[FO%-TOUR%-ECART%]"),
    "une ligne de journal [FO-TOUR-POSE] (puis [FO-TOUR-ECART])")
end
-- 7. Portée inconnue : ancien ordre
do
  _G.game.entity_prototypes["gun-turret"] = { turret_range = 0 }
  local s, placed = world({ building(0, 0, "mining-drill", 3, 1), building(-14, -14, "mining-drill", 3, 2) })
  local n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 1, carrier(5))
  check(n == 1 and placed[1].position.x == 7, "portée inconnue : ancien ordre")
end

-- 8. Repli ancien : tous les emplacements se replient sur le même point avant toute pose (doublons écartés) ; les tourelles
--    suivantes sont complétées une à une, la place cherchée après les tourelles déjà posées (comme avant le lot)
do
  _G.game.entity_prototypes["gun-turret"] = { turret_range = 18 }
  local s, placed = world({ building(0, 0, "mining-drill", 3, 1) })
  s.find_non_colliding_position = function(_, c)
    if #placed == 0 then return { x = 7, y = 7 } end
    return { x = c.x + #placed * 0.01, y = c.y }
  end
  local n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 3, carrier(5))
  check(n == 3, "emplacements confondus avant la pose : le nombre voulu est quand même posé (repli ancien)")
end

-- 9 à 13. Lot HQ-RECENSEMENT (relecture de QG-GROUPE2, mineur 3) : crochet Outposts.hq_slots (script/team/qg_groupe.lua, places libres des
--    lignes du QG de votre équipe). Il rend {} quand aucune place de la ligne n'est libre (eau, falaise, bâtiments) : la pose reprend les 8
--    emplacements d'avant (TURRET_OFFSETS, ajoutés par Outposts.fortify) ; nil (autre équipe, interrupteur) : la règle d'avant entière ; il n'est
--    jamais consulté pour un avant-poste.
local function hq_cases(O)
  _G.game.entity_prototypes["gun-turret"] = { turret_range = 18 }
  local r = {}
  local calls = 0
  local answer
  O.hq_slots = function() calls = calls + 1 return answer end
  local function qg() local f = fac(); f.hq = { valid = true, unit_number = 77 }; return f end
  local function at(placed, i) return placed[i] and (placed[i].position.x .. ":" .. placed[i].position.y) or "-" end
  -- 9. {} : aucune place libre dans la ligne -> premier emplacement d'avant (7, 7), dans l'ordre d'avant (et non (-9, 0), le choix de la
  --    règle d'avant entière dans ce monde : cas 11)
  answer = {}
  local s, placed = world({ building(0, 0, "container", 2, 77), building(-20, 0, "furnace", 2, 3) })
  local n = O.fortify(qg(), s, { pos = { x = 0, y = 0 } }, 1, carrier(5))
  r.empty = n .. "@" .. at(placed, 1) .. "#" .. calls
  -- 10. {} et 2 tourelles : les emplacements d'avant dans l'ordre, l'écart tenu
  s, placed = world({ building(0, 0, "container", 2, 77) })
  n = O.fortify(qg(), s, { pos = { x = 0, y = 0 } }, 2, carrier(5))
  r.empty2 = n .. "@" .. at(placed, 1) .. "," .. at(placed, 2)
  -- 11. nil : règle d'avant entière (même monde que le cas 6)
  answer = nil
  s, placed = world({ building(0, 0, "container", 2, 77), building(-20, 0, "furnace", 2, 3) })
  n = O.fortify(qg(), s, { pos = { x = 0, y = 0 } }, 1, carrier(5))
  r.none = n .. "@" .. at(placed, 1)
  -- 12. une place libre : la tourelle y est posée
  answer = { { x = 3, y = 10 } }
  s, placed = world({ building(0, 0, "container", 2, 77) })
  n = O.fortify(qg(), s, { pos = { x = 0, y = 0 } }, 1, carrier(5))
  r.one = n .. "@" .. at(placed, 1)
  -- 13. avant-poste (id) : le crochet n'est pas consulté
  local before = calls
  s, placed = world({ building(0, 0, "mining-drill", 3, 1) })
  n = O.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 1, carrier(5))
  r.outpost = n .. "@" .. at(placed, 1) .. "#" .. (calls - before)
  O.hq_slots = nil
  return r
end
local H = hq_cases(Outposts)
check(H.empty == "1@7:7#1", "hq_slots rend {} : la tourelle est posée au premier emplacement d'avant (7, 7) : " .. H.empty)
check(H.empty2 == "2@7:7,-7:-7", "hq_slots rend {} et 2 tourelles : (7, 7) puis (-7, -7) : " .. H.empty2)
check(H.none == "1@-9:0", "hq_slots rend nil : règle d'avant ((-9, 0), comme le cas 6) : " .. H.none)
check(H.one == "1@3:10", "hq_slots rend une place : la tourelle y est posée (3, 10) : " .. H.one)
check(H.outpost == "1@7:7#0", "avant-poste : hq_slots jamais consulté, (7, 7) comme avant : " .. H.outpost)
-- Mutants du branchement (script/faction/outposts.lua relu et muté, cas 9 à 13 rejoués)
do
  local fh = assert(io.open("script/faction/outposts.lua", "rb")); local SRC = fh:read("*a"); fh:close()
  local mutants = {
    { "{} pris pour nil", "    if slots then return slots end", "    if slots and #slots > 0 then return slots end" },
    { "repli d'avant retiré", "  for _, o in ipairs(TURRET_OFFSETS) do sites[#sites + 1]", "  for _, o in ipairs({}) do sites[#sites + 1]" },
    { "crochet pour un avant-poste", "  if outpost.id == nil and Outposts.hq_slots ~= nil then", "  if Outposts.hq_slots ~= nil then" },
  }
  local killed = 0
  for _, m in ipairs(mutants) do
    local a, b = SRC:find(m[2], 1, true)
    if not a then check(false, "mutant « " .. m[1] .. " » : texte introuvable")
    else
      local ok, M = pcall(function() return assert(load(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1), "@script.faction.outposts"))() end)
      local same = false
      if ok then
        local ok2, R = pcall(hq_cases, M)
        same = ok2
        if ok2 then for k, v in pairs(H) do if R[k] ~= v then same = false end end end
      end
      if not same then killed = killed + 1 end
      check(not same, "mutant « " .. m[1] .. " » détecté")
    end
  end
  print(string.format("[TOURELLES-MOTEUR] mutants du crochet hq_slots refusés : %d sur %d", killed, #mutants))
end

-- 14 et 15. Lot CC-TOURELLES (F489, règle du DC) : un avant-poste SUR un gisement pose ses tourelles au bord, jamais sur le minerai ;
--    gisement plus grand que la portée : repli sur les emplacements d'avant (aucune pose perdue, journal [FO-TOUR-PERIMETRE]).
local function ore_world(h)
  local s, placed = world({ building(0, 0, "mining-drill", 3, 1) })
  local function touches(a) return a[1][1] <= h and a[2][1] >= -h and a[1][2] <= h and a[2][2] >= -h end
  s.count_entities_filtered = function(q) if q.type == "resource" and q.area and touches(q.area) then return 1 end return 0 end
  return s, placed, function(x, y) return touches({ { x - 1, y - 1 }, { x + 1, y + 1 } }) end
end
do
  _G.game.entity_prototypes["gun-turret"] = { turret_range = 18, tile_width = 2, tile_height = 2 }
  local s, placed, on_ore = ore_world(10)
  local n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 4, carrier(5))
  local off = n == 4
  for _, e in ipairs(placed) do if on_ore(e.position.x, e.position.y) then off = false end end
  check(off, "gisement de 21 tuiles sous l'avant-poste : 4 tourelles posées, aucune sur le minerai (" .. n .. ")")
  local s0, placed0 = world({ building(0, 0, "mining-drill", 3, 1) })
  Outposts.fortify(fac(), s0, { id = 1, pos = { x = 0, y = 0 } }, 1, carrier(5))
  check(placed0[1] and placed0[1].position.x == 7 and placed0[1].position.y == 7, "sans minerai : (7,7) comme avant")
end
do
  local s, placed = ore_world(500)
  local n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 2, carrier(5))
  check(n == 2, "gisement plus grand que la portée : repli d'avant, 2 tourelles posées (" .. n .. ")")
end

print(string.format("[TOURELLES-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
