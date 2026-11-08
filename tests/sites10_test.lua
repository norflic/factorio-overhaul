--[[
  Lot TV-PLACE, G57 : la prospection des sites des factions en fenêtres de 10 x 10 (script/faction/sites.lua, Sites.probe_at ->
  probe -> enough), sur une surface fictive à tuiles EXACTES (le moteur simulé range un gisement en grappe de 25 entités).
    lua5.2 tests/sites10_test.lua   -> [SITES10] BILAN : N OK, 0 ECHEC(S)
    1. un gisement coupé par la frontière de deux chunks (12 + 12 tuiles) est retenu par UN seul chunk, réglage allumé ;
    2. réglage éteint (ou absent) : l'ancien comportement, rien n'est retenu ;
    3. un gisement entier dans un chunk (>= 24 tuiles) est retenu comme avant (le test par chunk passe en premier) ;
    4. 23 tuiles : jamais ; tuiles éparpillées : jamais ;
    5. coût : une zone sans ressource ne coûte aucun appel de plus ; la lecture des positions n'a lieu qu'au-dessus du seuil ;
    6. journal [FO-SITES-10] et compteur f.stats.sonde10.
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
end

M.new_game({ seed = 4242, patches = {}, p_busy = 0, p_nopath = 0, p_lost = 0 })
M.command("fo-war", "start 2 100 10 320")
local war = global.fo.war
local Sites = require("script.faction.sites")
local f = war.factions[1]

local SET = { ["fo-war-sites-10"] = true }
local real_settings = settings
local function set_on(v) SET["fo-war-sites-10"] = v end
local LOGS = {}
local real_log = log
log = function(s) LOGS[#LOGS + 1] = s if real_log then real_log(s) end end
settings = { global = setmetatable({}, { __index = function(_, k)
  if SET[k] ~= nil then return { value = SET[k] } end
  return real_settings.global[k]
end }) }

--- Surface fictive : tuiles de minerai exactes { x, y, name }.
local function fake(tiles)
  local s = { calls = { count = 0, find = 0, find_big = 0 } }
  local function inside(t, a) return t.x >= a[1][1] and t.x < a[2][1] and t.y >= a[1][2] and t.y < a[2][2] end
  local function pick(a)
    local out = {}
    if not a.area then return out end
    for _, t in ipairs(tiles) do
      if inside(t, a.area) and (not a.name or a.name == t.name) then
        out[#out + 1] = { name = t.name, amount = 500, position = { x = t.x, y = t.y }, valid = true }
        if a.limit and #out >= a.limit then break end
      end
    end
    return out
  end
  s.is_chunk_generated = function() return true end
  s.count_entities_filtered = function(a)
    s.calls.count = s.calls.count + 1
    if a.area then return #pick(a) end
    return 0
  end
  s.find_entities_filtered = function(a)
    s.calls.find = s.calls.find + 1
    local r = pick(a)
    if a.area and a.area[2][1] - a.area[1][1] > 40 then s.calls.find_big = s.calls.find_big + 1 end
    return r
  end
  s.count_tiles_filtered = function() return 0 end
  return s
end
local function block(x, y, w, h, name, into)
  into = into or {}
  for dx = 0, w - 1 do for dy = 0, h - 1 do into[#into + 1] = { x = x + dx + 0.5, y = y + dy + 0.5, name = name or "iron-ore" } end end
  return into
end
local function fresh()
  f.prospects = {}
  f.stats = f.stats or {}
  f.stats.sonde10 = nil
  f.site_needs = { ["iron-ore"] = 1 }
  war.claims, war.claim_pos, war.unreachable = {}, {}, {}
  LOGS = {}
end
local TICK = 100000

-- 1. Gisement à cheval sur x = 5024 (frontière des chunks 156 et 157) : 4 colonnes de chaque côté, 3 rangées = 12 + 12.
local straddle = block(5020, 5000, 4, 3)
block(5024, 5000, 4, 3, "iron-ore", straddle)
fresh()
local s1 = fake(straddle)
local got157 = Sites.probe_at(f, s1, 5024, 5000, TICK)
check(got157 == true and #f.prospects == 1, "chunk (157,156) : le gisement a cheval est retenu (barycentre dans ce chunk)")
local site = f.prospects[1]
check(site and site.resource == "iron-ore" and math.abs(site.x - 5024) <= 1.5 and math.abs(site.y - 5001.5) <= 1.5, "site centre sur le gisement : (" ..
  tostring(site and site.x) .. ", " .. tostring(site and site.y) .. ")")
check(site and site.tiles == 24, "les 24 tuiles sont lues (zone centree sur la fenetre) : " .. tostring(site and site.tiles))
check(f.stats.sonde10 == 1, "compteur f.stats.sonde10 = 1")
check(#LOGS >= 1 and LOGS[1]:find("[FO-SITES-10]", 1, true) and LOGS[1]:find("24 tuile", 1, true) and LOGS[1]:find("12 dans le chunk seul", 1, true), "ligne [FO-SITES-10] : fenetre de 24, 12 dans le chunk seul")
fresh()
local got156 = Sites.probe_at(f, fake(straddle), 5008, 5000, TICK)
check(got156 == false and #f.prospects == 0, "chunk voisin (156,156) : ne retient pas le meme gisement (un seul chunk l'annonce)")

-- 2. Réglage éteint.
set_on(false)
fresh()
check(Sites.probe_at(f, fake(straddle), 5024, 5000, TICK) == false and #f.prospects == 0 and f.stats.sonde10 == nil, "reglage eteint : le gisement a cheval n'est pas vu (comportement d'avant)")
set_on(true)

-- 3. Gisement entier dans un chunk : comme avant, sans fenêtre.
fresh()
local whole = block(5040, 5040, 6, 5) -- 30 tuiles dans le chunk (157, 157)
local sw = fake(whole)
check(Sites.probe_at(f, sw, 5040, 5040, TICK) == true and #f.prospects == 1, "30 tuiles dans un chunk : retenu par le test par chunk")
check(f.stats.sonde10 == nil and sw.calls.find_big == 0, "le test par chunk passe en premier : aucune fenetre lue")

-- 4. Seuil et dispersion.
fresh()
local few = block(5020, 5000, 4, 3)
block(5024, 5000, 4, 2, "iron-ore", few) -- 12 + 8 = 20
check(Sites.probe_at(f, fake(few), 5024, 5000, TICK) == false and #f.prospects == 0, "20 tuiles a cheval : jamais")
fresh()
local sparse = {}
for i = 0, 29 do sparse[#sparse + 1] = { x = 5000 + i * 3 + 0.5, y = 5000 + i * 3 + 0.5, name = "iron-ore" } end
check(Sites.probe_at(f, fake(sparse), 5024, 5024, TICK) == false and #f.prospects == 0, "30 tuiles en diagonale espacee : aucune fenetre de 24")

-- 5. Coût.
fresh()
local empty = fake({})
Sites.probe_at(f, empty, 5024, 5000, TICK)
check(empty.calls.find == 0 and empty.calls.count <= 3, "zone sans ressource : aucune lecture de positions, peu de count (" .. empty.calls.count .. ")")
fresh()
local lone = fake(block(5000, 5000, 3, 3)) -- 9 tuiles: sous le seuil de la zone elargie
Sites.probe_at(f, lone, 5008, 5008, TICK)
check(lone.calls.find == 0, "9 tuiles dans la zone elargie : pas de lecture de positions (le count suffit)")
fresh()
local mid = fake(straddle)
Sites.probe_at(f, mid, 5024, 5000, TICK)
check(mid.calls.find_big >= 1, "au-dessus du seuil de la zone elargie : positions lues une fois")

-- 6. Source : le réglage absent (moteur simulé) laisse l'ancien comportement.
settings = real_settings
fresh()
local ok_set = pcall(function() return real_settings.global["fo-war-sites-10"].value end)
check(Sites.probe_at(f, fake(straddle), 5024, 5000, TICK) == false and #f.prospects == 0, "reglage absent ou non lu (" .. tostring(ok_set) .. ") : eteint, sans erreur")

print(string.format("[SITES10] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
