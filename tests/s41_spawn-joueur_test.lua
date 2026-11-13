--[[
  Sprint s41, chantier « spawn-joueur » : règles pures du départ de l'équipe du joueur (centre de commandement ancré au point d'apparition,
  coffre d'office hors gisement, couronne de secours des annexes) et leur branchement (lecture du texte des scripts).
  Lancement : lua5.2 tests/s41_spawn-joueur_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local function check(c, msg) if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end end
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end

local C = require("shared.levels.centre")
local D = require("shared.team.depart")
local A = require("shared.team.annexe")
local T = require("shared.team.config")

-- 1. Ancre du centre : le point d'apparition de l'équipe, le joueur à défaut (partie du DC : joueur né en (-62, 15), apparition en (0, 0))
local a = C.start_anchor({ x = 0, y = 0 }, { x = -62, y = 15 })
check(a.x == 0 and a.y == 0, "ancre : le point d'apparition, pas le joueur")
a = C.start_anchor(nil, { x = -62, y = 15 })
check(a.x == -62 and a.y == 15, "ancre : le joueur si le point d'apparition est inconnu")
local sp = { x = 3, y = 4 }
check(C.start_anchor(sp, sp) ~= sp, "ancre : table neuve")
check(C.START_SPOTS[1][1] == C.START_OFFSET.x and C.START_SPOTS[1][2] == C.START_OFFSET.y, "première place = l'ancien décalage (8, 0)")

-- 2. Place du centre : première place trouvée et non refusée ; secours sinon
local same = function(w) return w end
local pos, rank = C.start_pos({ x = 0, y = 0 }, C.START_SPOTS, same, function() return false end, function() return "secours" end)
check(rank == 1 and pos.x == 8 and pos.y == 0, "terrain libre : (8, 0) comme avant")
pos, rank = C.start_pos({ x = 0, y = 0 }, C.START_SPOTS, same, function(p) return p.x > 0 end, function() return "secours" end)
check(rank == 2 and pos.x == 0 and pos.y == 8, "première place sur une ressource : la suivante")
pos, rank = C.start_pos({ x = 0, y = 0 }, C.START_SPOTS, function(w) if w.x < 0 then return w end end, function() return false end,
  function() return "secours" end)
check(rank == 3 and pos.x == -8, "place introuvable : la suivante")
pos, rank = C.start_pos({ x = 0, y = 0 }, C.START_SPOTS, same, function() return true end, function() return "secours" end)
check(rank == 0 and pos == "secours", "tout sur une ressource : l'ancienne recherche")
pos, rank = C.start_pos({ x = 0, y = 0 }, C.START_SPOTS, same, function() return true end, function() return nil end)
check(pos == nil and rank == 0, "aucune place : nil")
for _, o in ipairs(C.START_SPOTS) do
  check(math.abs(o[1]) + C.START_NEAR <= 24 and math.abs(o[2]) + C.START_NEAR <= 24, "place du centre à 24 tuiles au plus du point d'apparition")
end

-- 3. Coffre d'office : première place libre sans ressource, sinon la moins chargée, sinon rien
check(D.CHEST_SPOTS[1][1] == D.CHEST_OFFSET[1] and D.CHEST_SPOTS[1][2] == D.CHEST_OFFSET[2], "première place du coffre = l'ancien décalage")
check(D.pick_chest({ { pos = {}, ore = 0 } }) == 1, "pas de ressource : place 1 comme avant")
check(D.pick_chest({ { pos = {}, ore = 40 }, { pos = nil, ore = 0 }, { pos = {}, ore = 0 }, { pos = {}, ore = 0 } }) == 3, "gisement : première place libre sans ressource")
check(D.pick_chest({ { pos = {}, ore = 40 }, { pos = {}, ore = 12 }, { pos = {}, ore = 12 }, { pos = {}, ore = 30 } }) == 2, "partout du minerai : le moins, la première à égalité")
check(D.pick_chest({ { pos = nil }, { pos = nil } }) == nil and D.pick_chest({}) == nil and D.pick_chest(nil) == nil, "aucune place libre : nil (ancienne recherche)")

-- 4. Couronne de secours des annexes : hors du bloc, bornée, triée, sans doublon, stable
local b = T.annex.block
local o1, o2 = A.outer_slots(1, 1), A.outer_slots(1, 1)
check(#o1 > 0 and #o1 == #o2, "couronne non vide et stable")
local seen, ok_out, ok_bound, ok_sort, ok_same, last = {}, true, true, true, true, -1
for i, o in ipairs(o1) do
  local k = o[1] .. ":" .. o[2]
  if seen[k] then ok_out = false end
  seen[k] = true
  if math.abs(o[2]) <= b.far then ok_out = false end
  if math.abs(o[2]) > b.far + A.OUTER or math.abs(o[1]) > math.max(b.half_south, b.half_north) + A.OUTER then ok_bound = false end
  local d = o[1] * o[1] + o[2] * o[2]
  if d < last then ok_sort = false end
  last = d
  if o2[i][1] ~= o[1] or o2[i][2] ~= o[2] then ok_same = false end
end
check(ok_out, "couronne : aucune place dans les rangées du bloc, aucun doublon")
check(ok_bound, "couronne : bornée à A.OUTER tuiles au-delà du bloc")
check(ok_sort and ok_same, "couronne : de la plus proche à la plus lointaine, même ordre à chaque appel")
local inner = {}
for _, sy in ipairs({ 1, -1 }) do for _, o in ipairs(A.slots(sy, 1, 1)) do inner[o[1] .. ":" .. o[2]] = true end end
local clash = false
for _, o in ipairs(o1) do if inner[o[1] .. ":" .. o[2]] then clash = true end end
check(not clash, "couronne : aucune place commune avec le bloc")

-- 5. Branchement
local centre = read("script/levels/centre.lua")
check(centre:find("C.start_anchor(force.get_spawn_position(player.surface), player.position)", 1, true) ~= nil, "le départ lit l'ancre au point d'apparition")
check(centre:find("Centre.place_wreck(force, player.surface, near)", 1, true) ~= nil, "le centre est posé à l'ancre")
check(centre:find("Centre.place_wreck(force, player.surface, player.position)", 1, true) == nil, "plus de pose à la position du joueur")
check(centre:find("C.start_pos(near, C.START_SPOTS", 1, true) ~= nil and centre:find("PlacesQG.on_resource(surface, name, p)", 1, true) ~= nil,
  "place_wreck essaie les places voisines hors ressource")
local pt = read("script/team/player_team.lua")
check(pt:find("Depart.pick_chest(cands)", 1, true) ~= nil and pt:find("Depart.CHEST_SPOTS", 1, true) ~= nil, "found_default choisit la place du coffre")
local st = read("script/team/stock.lua")
check(st:find("A.outer_slots(w, h)", 1, true) ~= nil and st:find("if on_ore then", 1, true) ~= nil, "place_one : couronne seulement si le bloc touche une ressource")

print(string.format("s41 spawn-joueur : %d OK, %d ECHEC", passes, failures))
os.exit(failures == 0 and 0 or 1)
