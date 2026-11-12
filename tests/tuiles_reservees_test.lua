--[[
  Tests hors jeu du lot TUILES-RESERVEES (B2 : deux poseurs pour la même tuile). Le plan directeur réserve ses tuiles (b.occ) ; un
  poseur HORS du plan qui ne les lit pas coupe une ligne planifiée : fantôme refusé « occupé » en boucle, projet bloqué.
  Vu : fo-lvl-gun-2 d'amber en (-360, -327) sur le tapis d'entrée du projet 31 (mall-rangee-2, planifié à 44,2 min), 30 refus
  « occupé », reprise 2/3 (TETE-CHAMP, 2507543475) : la tourelle venait du REPLI de Outposts.fortify_at, qui ne gardait que deux
  des quatre interdits de la recherche (couloir, ressource) et oubliait la tuile réservée.
  Usage, depuis la racine du mod :   lua5.2 tests/tuiles_reservees_test.lua

  1. Q.is_reserved : sans crochet rien n'est réservé ; le crochet reçoit name, pos, dir, opts ; Q.skip_reserved lit la même règle ;
  2. Outposts.fortify_at (vrai script/faction/outposts.lua, moteur factice) : toutes les places autour de l'emplacement réservées ->
     AUCUNE tourelle (le repli lit la règle) ; moitié ouest réservée -> tourelle à l'est ; sans réserve -> posée comme avant ;
  3. crochet UNIQUE : build.lua pose un seul crochet de tuiles réservées (PlacesQG.reserved) ; plus aucun Outposts.reserved,
     Stock.reserved ni lecture de Build.reserved_entity dans hygiene.lua ; chaque poseur hors plan lit PlacesQG.is_reserved
     (avant-postes, tourelles, annexes, fours et labos du QG, centre de commandement des équipes et des factions, hygiène,
     remplacements de foreuse, adoption) ;
  4. mutants : le repli d'avant (rouge), la règle copiée au lieu d'être lue, chaque lecteur retiré.
]]
package.path = "./?.lua;" .. package.path
defines = { direction = { north = 0, east = 2, south = 4, west = 6 }, inventory = { chest = 1 } }
local logs = {}
function log(s) logs[#logs + 1] = s end

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local function read(path) local h = assert(io.open(path, "rb")); local s = h:read("*a"); h:close(); return (s:gsub("\r\n", "\n")) end

_G.game = { entity_prototypes = { ["gun-turret"] = { turret_range = 18, tile_width = 2, tile_height = 2 } } }

local PQ = dofile("script/ai3/places_qg.lua")

section("1. Q.is_reserved, règle unique")
do
  PQ.reserved = nil
  check(PQ.is_reserved({}, "x", { x = 0, y = 0 }) == false, "sans crochet : rien n'est réservé")
  local got
  PQ.reserved = function(f, name, pos, dir, opts) got = { f, name, pos, dir, opts } return pos.x < 0 end
  local f, o = {}, { keep = { 1, 2, 3, 4 } }
  check(PQ.is_reserved(f, "x", { x = -1, y = 0 }, 2, o) == true and got[1] == f and got[2] == "x" and got[4] == 2 and got[5] == o,
    "le crochet reçoit l'équipe, le nom, la place, la direction, les options")
  check(PQ.is_reserved(f, "x", { x = 1, y = 0 }) == false, "place libre : non réservée")
  local made = 0
  local mk = PQ.skip_reserved(f, "x", function() made = made + 1 return true end)
  check(mk({ x = -1, y = 0 }) == false and made == 0, "Q.skip_reserved lit la même règle : place réservée sautée")
  check(mk({ x = 1, y = 0 }) == true and made == 1, "Q.skip_reserved : place libre posée")
  check(got[5] and got[5].couloir == false, "Q.skip_reserved (QG) : tuiles du plan, sans les couloirs")
  PQ.reserved = nil
end

-- Moteur factice : tourelles 2 x 2, toute place libre hors des tourelles déjà posées ; recherche en spirale (comme le moteur).
package.loaded["script.faction.state"] = { own = function() end, sorted_keys = function(t) local k = {} for a in pairs(t) do k[#k + 1] = a end table.sort(k) return k end }
package.loaded["script.faction.sites"] = {}
package.loaded["script.ai3.places_qg"] = { on_resource = function() return false end, is_reserved = PQ.is_reserved }
local OUT_SRC = read("script/faction/outposts.lua")
local function load_outposts(src)
  package.loaded["script.faction.outposts"] = nil
  return assert(load(src, "=outposts", "t", _G))()
end
local function world()
  local turrets = {}
  local surface = {}
  local function free(x, y)
    for _, t in ipairs(turrets) do
      if math.abs(t.position.x - x) < 2 and math.abs(t.position.y - y) < 2 then return false end
    end
    return true
  end
  local SPIRAL = { { 0, 0 } }
  for r = 1, 4 do
    for _, v in ipairs({ { r, 0 }, { -r, 0 }, { 0, r }, { 0, -r }, { r, r }, { -r, -r }, { r, -r }, { -r, r } }) do SPIRAL[#SPIRAL + 1] = v end
  end
  surface.find_non_colliding_position = function(_, c)
    local x0, y0 = math.floor(c.x + 0.5), math.floor(c.y + 0.5)
    for _, v in ipairs(SPIRAL) do
      if free(x0 + v[1], y0 + v[2]) then return { x = x0 + v[1], y = y0 + v[2] } end
    end
    return nil
  end
  surface.find_entities_filtered = function() return {} end
  surface.count_entities_filtered = function() return 0 end
  surface.create_entity = function(q)
    if not free(q.position.x, q.position.y) then return nil end
    local e = { name = q.name, type = "ammo-turret", position = { x = q.position.x, y = q.position.y }, unit_number = 3000 + #turrets,
      valid = true, get_item_count = function() return 0 end, insert = function() end }
    turrets[#turrets + 1] = e
    return e
  end
  return surface, turrets
end
local function carrier(n) local c = { n = n }
  c.get_item_count = function(name) return name == "gun-turret" and c.n or 0 end
  c.remove = function(q) if q.name == "gun-turret" then c.n = c.n - q.count end return q.count end
  return c
end
local function fac() return { force = "f1", key = "amber", id = 1, turrets = {}, outposts = {}, stats = {} } end

-- Rend vrai si la pose respecte les tuiles réservées (et pose encore quand une place libre existe).
local function fortify_cases(O, quiet)
  local ok = true
  local function c(v, m) if not v then ok = false end if not quiet then check(v, m) end end
  O.corridors = nil
  -- A. tout autour de l'emplacement est au plan (tapis d'entrée d'une rangée du mall) : aucune tourelle, aucune sur une tuile réservée
  PQ.reserved = function(_, _, q) return math.abs(q.x) <= 12 and math.abs(q.y) <= 12 end
  local s, turrets = world()
  local cr = carrier(2)
  local n = O.fortify_at(fac(), s, "plant", { { x = 0, y = 0 } }, 1, cr)
  local bad = 0
  for _, t in ipairs(turrets) do if PQ.reserved(nil, nil, t.position) then bad = bad + 1 end end
  c(n == 0 and bad == 0 and cr.n == 2, string.format("places toutes réservées : aucune tourelle posée (%d posée(s), %d sur le plan)", n, bad))
  -- B. moitié ouest au plan : la tourelle est à l'est, jamais sur le plan
  PQ.reserved = function(_, _, q) return q.x < 3 end
  s, turrets = world()
  n = O.fortify_at(fac(), s, "plant", { { x = 0, y = 0 } }, 1, carrier(2))
  c(n == 1 and turrets[1] and turrets[1].position.x >= 3, string.format("ouest réservé : tourelle à l'est (%d, x = %s)", n,
    tostring(turrets[1] and turrets[1].position.x)))
  -- C. rien au plan : posée sur l'emplacement, comme avant
  PQ.reserved = nil
  s, turrets = world()
  n = O.fortify_at(fac(), s, "plant", { { x = 0, y = 0 } }, 1, carrier(2))
  c(n == 1 and turrets[1].position.x == 0 and turrets[1].position.y == 0, "sans réserve : posée sur l'emplacement")
  PQ.reserved = nil
  return ok
end

section("2. Outposts.fortify_at : la recherche ET le repli lisent la règle")
check(fortify_cases(load_outposts(OUT_SRC)), "pose des tourelles : tuiles réservées respectées")

-- Lecteurs de la règle unique (fichier, motif littéral, occurrences au moins).
local READERS = {
  { "script/faction/outposts.lua", "if spos and (PlacesQG.is_reserved(f, T.DRILL, pos, dir) or PlacesQG.is_reserved(f, spec.sink, spos)) then spos = nil end", 1, "avant-postes à brûleur" },
  { "script/faction/outposts.lua", "return PlacesQG.is_reserved(f, T.turret, q) or in_axe(q) ~= nil", 1, "tourelles (recherche et repli)" },
  { "script/faction/outposts.lua", "count, PlacesQG.skip_reserved(f, T.SMELTER, function(pos)", 1, "fours du QG" },
  { "script/ai3/cerveau.lua", "PlacesQG.skip_reserved(f, lab.entity, function(pos)", 1, "labos du QG" },
  { "script/team/stock.lua", "PlacesQG.is_reserved(f, item, p", 3, "annexes du QG" },
  { "script/team/hygiene.lua", "and not PlacesQG.is_reserved(f, name, { x = x, y = y }, 0)", 1, "hygiène (poteau remplaçant)" },
  { "script/team/foreuse_swap.lua", "PlacesQG.is_reserved(f, item, { x = cx, y = cy }, edir, { keep = keep, blocked = blocked })", 1, "remplacement de foreuse" },
  { "script/team/foreuse_swap.lua", "if PlacesQG.is_reserved(f, pole.name, { x = x, y = y }, 0) then return false end", 1, "poteaux de raccord des foreuses" },
  { "script/team/adopte.lua", "PlacesQG.is_reserved(f, ent.name, ent.position, ent.direction, { couloir = false })", 2, "adoption" },
  { "script/ai3/capital.lua", "if pos and not PlacesQG.is_reserved(f, name, pos) then\n      local e = surface.create_entity(", 1, "centre de commandement (capital)" },
  { "script/faction/centre_qg.lua", "if pos and not PlacesQG.is_reserved(f, name, pos) then\n      local e = surface.create_entity(", 1, "centre de commandement (factions)" },
}
local HOOK = "PlacesQG.reserved = function(f, name, pos, dir, opts) return Build.reserved_entity(f, name, pos, dir, opts) end"
local COPIES = { "Outposts.reserved", "Stock.reserved", "Build.reserved_entity(f, name, { x = x, y = y }, 0)" }
local FILES = { "script/team/build.lua", "script/faction/outposts.lua", "script/team/stock.lua", "script/team/hygiene.lua",
  "script/team/foreuse_swap.lua", "script/team/adopte.lua", "script/ai3/capital.lua", "script/faction/centre_qg.lua", "script/ai3/cerveau.lua" }

local function count(text, needle)
  local n, i = 0, 1
  while true do
    local a = text:find(needle, i, true)
    if not a then return n end
    n, i = n + 1, a + 1
  end
end
-- Rend vrai si le câblage est entier : un crochet, aucune copie, chaque lecteur présent.
local function wiring(texts, quiet)
  local ok = true
  local function c(v, m) if not v then ok = false end if not quiet then check(v, m) end end
  local _, hooks = texts["script/team/build.lua"]:gsub("%.reserved = function%(", "")
  c(hooks == 1 and count(texts["script/team/build.lua"], HOOK) == 1, "build.lua : UN crochet de tuiles réservées, PlacesQG.reserved (" .. hooks .. ")")
  for _, p in ipairs(FILES) do
    for _, cp in ipairs(COPIES) do c(count(texts[p], cp) == 0, p .. " : pas de copie de la règle (" .. cp .. ")") end
  end
  for _, r in ipairs(READERS) do
    c(count(texts[r[1]], r[2]) >= r[3], r[4] .. " : lit PlacesQG.is_reserved (" .. r[1] .. ")")
  end
  return ok
end

local function texts_now()
  local t = {}
  for _, p in ipairs(FILES) do t[p] = read(p) end
  return t
end

section("3. crochet unique, lu par chaque poseur hors plan")
check(wiring(texts_now()), "câblage entier")

section("4. mutants")
do
  -- repli d'avant (TETE-CHAMP) : couloir et ressource seulement
  local old = "if q and not in_axe(q) and not PlacesQG.on_resource(surface, T.turret, q) then pos = q end"
  local m, n = OUT_SRC:gsub("if q and not banned%(q%) then pos = q end", function() return old end, 1)
  check(n == 1 and not fortify_cases(load_outposts(m), true), "mutant : repli d'avant (sans la tuile réservée) vu")
  m, n = OUT_SRC:gsub("return PlacesQG%.is_reserved%(f, T%.turret, q%) or in_axe", "return in_axe", 1)
  check(n == 1 and not fortify_cases(load_outposts(m), true), "mutant : tourelles sans la règle vu")
  -- règle copiée au lieu d'être lue : un second crochet dans build.lua
  local t = texts_now()
  t["script/team/build.lua"] = t["script/team/build.lua"] .. "\nStock.reserved = function(f, name, pos) return Build.reserved_entity(f, name, pos) end\n"
  check(not wiring(t, true), "mutant : second crochet (copie) vu")
  -- chaque lecteur retiré
  for _, r in ipairs(READERS) do
    t = texts_now()
    local plain = r[2]:gsub("%p", "%%%0")
    local k
    t[r[1]], k = t[r[1]]:gsub(plain, "", r[3] > 1 and 1 or nil)
    check(k >= 1 and not wiring(t, true), "mutant : lecteur retiré (" .. r[4] .. ") vu")
  end
end

print(string.format("tuiles_reservees_test : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
