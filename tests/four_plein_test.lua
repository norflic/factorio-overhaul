--[[
  Tests hors jeu du lot FOUR-PLEIN (famine de fer de votre équipe, etape1-guide, graine 2507543475) : un laboratoire du QG posé à
  12,3 min (puis un autre à 32,0 min) sur les tuiles de la ligne de plaques que le projet 3 (bande -10 du champ de fer) avait
  réservées à 8,9 min (b.occ) ; fantôme de tapis refusé « occupé » (emprise : lab), projet bloqué, 14 fours sur 24 « sortie
  pleine », fer au coffre à 0 de 34 à 63 min. La pose du QG (script/ai3/places_qg.lua) ne vérifiait que can_place_entity.
  Usage, depuis la racine du mod :   lua5.2 tests/four_plein_test.lua

  1. Q.skip_reserved : une place réservée est sautée (make n'est pas appelé), la suivante reçoit le labo ; sans crochet : comme avant ;
     nil de make (plus d'objet) passe toujours ;
  2. câblage : labos (cerveau.lua) et fours du QG (outposts.lua) passent par Q.skip_reserved ; build.lua pose le crochet sur
     Build.reserved_entity (tuiles du plan, sans les couloirs) ;
  3. mutants : chaque coupe retirée est vue.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local function read(path) local h = assert(io.open(path, "rb")); local s = h:read("*a"); h:close(); return s end

-- Moteur réduit : un prototype 3 × 3 de type quelconque, sol sans ressource, toute place libre au moteur.
_G.game = { entity_prototypes = { box3 = { type = "lab", collision_box = { left_top = { x = -1.4, y = -1.4 }, right_bottom = { x = 1.4, y = 1.4 } } } } }
local surface = {
  can_place_entity = function() return true end,
  count_entities_filtered = function() return 0 end,
  find_non_colliding_position = function(_, c) return c end,
}

local function load_q(src)
  package.loaded["script.ai3.places_qg"] = nil
  if src then return assert(load(src, "=places_qg_mutant"))() end
  return require("script.ai3.places_qg")
end

local function run(Q)
  -- deux places à la file : (0, 0) puis (10, 0) ; la première tuile (0, 0) est au plan d'un projet
  local list = { { 0, 0 }, { 10, 0 } }
  local occ = { ["0,0"] = 3 }
  Q.reserved = function(f, name, pos)
    for ty = math.floor(pos.y - 1.5 + 0.01), math.floor(pos.y - 1.5 + 0.01) + 2 do
      for tx = math.floor(pos.x - 1.5 + 0.01), math.floor(pos.x - 1.5 + 0.01) + 2 do
        if f.occ[tx .. "," .. ty] then return true end
      end
    end
    return false
  end
  local f = { occ = occ }
  local made = {}
  local n = Q.place_list(surface, "box3", "player", { x = 0.5, y = 0.5 }, list, 0, 1, Q.skip_reserved(f, "box3", function(pos)
    made[#made + 1] = pos
    return true
  end))
  return n, made
end

section("1. Q.skip_reserved")
do
  local Q = load_q()
  local n, made = run(Q)
  check(n == 1 and #made == 1, "un labo posé (" .. n .. ")")
  check(made[1] and made[1].x == 10.5, "la place réservée du plan est sautée, labo à la place suivante (x = " .. tostring(made[1] and made[1].x) .. ")")
  Q.reserved = nil
  local m2 = {}
  local n2 = Q.place_list(surface, "box3", "player", { x = 0.5, y = 0.5 }, { { 0, 0 } }, 0, 1, Q.skip_reserved({}, "box3", function(pos)
    m2[#m2 + 1] = pos
    return true
  end))
  check(n2 == 1 and m2[1].x == 0.5, "sans crochet : la première place, comme avant")
  Q.reserved = function() return false end
  local calls = 0
  local n3 = Q.place_list(surface, "box3", "player", { x = 0.5, y = 0.5 }, { { 0, 0 }, { 10, 0 } }, 0, 2, Q.skip_reserved({}, "box3", function()
    calls = calls + 1
    return nil
  end))
  check(n3 == 0 and calls == 1, "plus d'objet (nil) : arrêt de la pose")
end

local SRC = {
  q = "script/ai3/places_qg.lua",
  cerveau = "script/ai3/cerveau.lua",
  outposts = "script/faction/outposts.lua",
  build = "script/team/build.lua",
}
local NEEDLES = {
  cerveau = "want - #labs, PlacesQG.skip_reserved(f, lab.entity, function(pos)",
  outposts = "count, PlacesQG.skip_reserved(f, T.SMELTER, function(pos)",
  build = "PlacesQG.reserved = function(f, name, pos, dir, opts) return Build.reserved_entity(f, name, pos, dir, opts) end", -- (lot TUILES-RESERVEES : crochet unique)
}

local function wiring(texts)
  local ok = true
  for _, k in ipairs({ "cerveau", "outposts", "build" }) do
    if not texts[k]:find(NEEDLES[k], 1, true) then ok = false end
  end
  return ok
end

section("2. câblage")
do
  local texts = {}
  for k, p in pairs(SRC) do texts[k] = read(p) end
  check(texts.cerveau:find(NEEDLES.cerveau, 1, true) ~= nil, "labos du QG : place réservée sautée")
  check(texts.outposts:find(NEEDLES.outposts, 1, true) ~= nil, "fours du QG : place réservée sautée")
  check(texts.build:find(NEEDLES.build, 1, true) ~= nil, "build.lua : crochet sur Build.reserved_entity (b.occ)")
  check(texts.build:find('local PlacesQG = require("script.ai3.places_qg")', 1, true) ~= nil, "build.lua : places_qg chargé au chargement")
end

section("3. mutants")
do
  local qsrc = read(SRC.q)
  local mut, nm = qsrc:gsub("if Q%.is_reserved%(f, name, pos, nil, opts or QG%) then return false end", "", 1)
  check(nm == 1, "mutant de Q.skip_reserved trouvé")
  local Q = load_q(mut)
  local _, made = run(Q)
  check(made[1] and made[1].x == 0.5, "mutant : sans le saut, le labo retombe sur la tuile du plan (vu)")
  for _, k in ipairs({ "cerveau", "outposts", "build" }) do
    local texts = {}
    for kk, p in pairs(SRC) do texts[kk] = read(p) end
    local plain = NEEDLES[k]:gsub("%p", "%%%0")
    local n
    texts[k], n = texts[k]:gsub(plain, "", 1)
    check(n == 1 and not wiring(texts), "mutant : câblage retiré dans " .. k .. " (vu)")
  end
end

print(string.format("four_plein_test : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
