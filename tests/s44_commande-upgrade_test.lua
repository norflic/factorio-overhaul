--[[
  Lot s44 COMMANDE-UPGRADE : banc HORS JEU de la zone d'amélioration prioritaire du joueur.
  Lancement : lua5.2 tests/s44_commande-upgrade_test.lua (racine du mod).
    1. règle pure (shared/ai3/commande.lua) : ordre « amelioration » posé, listé, annulé ; rang 0 dedans, 1 dehors ;
    2. décision (shared/ai3/capital.lua) : un remplacement dans la zone passe devant un meilleur score hors zone ; sans zone, rien ne change ;
    3. câblage (sources) : outil (Maj + bouton droit), relevé des machines de la zone, ctx.zones, textes FR et EN.
]]
package.path = "./?.lua;" .. package.path
local Co = require("shared.ai3.commande")
local Cap = require("shared.ai3.capital")
local L = require("shared.levels.config")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function read(path)
  local fh = assert(io.open(path, "r"))
  local s = fh:read("*a")
  fh:close()
  return s
end

print("== 1. règle pure")
do
  local st = Co.new_state()
  local id = Co.add(st, { kind = "amelioration", x = 100, y = 100, r = 20, tick = 5, surface = 1 })
  check(id == 1, "zone d'amélioration acceptée")
  Co.add(st, { kind = "liaison", x = 0, y = 0, r = 10 })
  local z = Co.upgrade_zones(st)
  check(#z == 1 and z[1].id == 1, "seules les zones d'amélioration sont listées")
  check(Co.upgrade_rank(z, 105, 110) == 0, "dans la zone : rang 0")
  check(Co.upgrade_rank(z, 130, 130) == 1, "hors de la zone : rang 1")
  check(Co.upgrade_rank({}, 105, 110) == 1 and Co.upgrade_rank(nil, 1, 1) == 1, "sans zone : rang 1")
  check(Co.upgrade_rank(z, nil, nil) == 1, "position inconnue : rang 1")
  check(#Co.hit(st, 95, 95, 105, 105) >= 1, "le bouton droit touche la zone")
  Co.cancel(st, id)
  check(#Co.upgrade_zones(st) == 0, "zone annulée : plus de priorité")
  check(#Co.upgrade_zones(nil) == 0, "état absent : aucune zone")
end

print("== 2. décision")
do
  local protos = {
    ["lent-a"] = { type = "furnace", group = "g", w = 2, h = 2, energy = "burner", cats = { s = true }, speed = 1, item = "lent-a" },
    ["vite-a"] = { type = "furnace", group = "g", w = 2, h = 2, energy = "burner", cats = { s = true }, speed = 4, item = "vite-a" },
    ["lent-b"] = { type = "assembling-machine", group = "h", w = 3, h = 3, energy = "electric", cats = { c = true }, speed = 1, item = "lent-b" },
    ["vite-b"] = { type = "assembling-machine", group = "h", w = 3, h = 3, energy = "electric", cats = { c = true }, speed = 1.2, item = "vite-b" },
  }
  local names = { "lent-a", "lent-b", "vite-a", "vite-b" }
  local unit = { ["vite-a"] = 10, ["vite-b"] = 10 }
  local function ctx(zones)
    return { proto = function() return nil end, unit_cost = function(i) return unit[i] end, stock = { ["vite-a"] = 1, ["vite-b"] = 1 },
      weights = {}, mproto = function(n) return protos[n] end, machines = names, zones = zones }
  end
  local census = { list = {}, center = nil, no_center = true,
    machines = { { id = 1, name = "lent-a", working = true, x = 0, y = 0, block = "qg" },
      { id = 2, name = "lent-b", working = true, x = 200, y = 200, block = "zone1" } } }
  local d0 = Cap.choose(L, census, ctx(nil))
  check(d0.replace and d0.replace.from == "lent-a", "sans zone : le meilleur score (x4) passe d'abord (" .. tostring(d0.key) .. ")")
  local zones = { { id = 1, kind = "amelioration", x = 200, y = 200, r = 10 } }
  local d1 = Cap.choose(L, census, ctx(zones))
  check(d1.replace and d1.replace.from == "lent-b" and d1.zone == true, "dans la zone : rang 0 devant tout (" .. tostring(d1.key) .. ")")
  check(d1.key and d1.key:sub(1, #"remplacer:z|") == "remplacer:z|", "le groupe de la zone est à part (clé z|)")
  local far = { { id = 1, kind = "amelioration", x = 900, y = 900, r = 10 } }
  local d2 = Cap.choose(L, census, ctx(far))
  check(d2.replace and d2.replace.from == "lent-a" and not d2.zone, "zone vide de machines : décision inchangée")
  -- Mutant : sans la clé de tri de zone, la zone ne passerait pas devant.
  local src = read("shared/ai3/capital.lua")
  check(src:find("if za ~= zb then return za > zb end", 1, true) ~= nil, "tri : la zone est la première clé")
end

print("== 3. câblage")
do
  local gui = read("script/gui/commande.lua")
  check(gui:find("on_player_alt_reverse_selected_area", 1, true) ~= nil, "outil : Maj + bouton droit pose la zone")
  check((gui:find('kind = "amelioration"', 1, true) or gui:find('zone_order("amelioration")', 1, true)) ~= nil, "outil : ordre « amelioration »")
  local cap = read("script/ai3/capital.lua")
  check(cap:find("zones = Co.upgrade_zones(f.team and f.team.commande)", 1, true) ~= nil, "décision : ctx.zones lu dans l'état de l'équipe")
  check(cap:find("for _, z in ipairs(Co.upgrade_zones(", 1, true) ~= nil, "relevé : machines de la zone")
  check(not read("shared/ai3/commande.lua"):find("game%."), "shared/ai3/commande.lua pur (aucune API du jeu)")
  for _, lang in ipairs({ "fr", "en" }) do
    local t = read("locale/" .. lang .. "/commande.cfg")
    for _, k in ipairs({ "aide-amelioration=", "ligne-amelioration=", "carte-amelioration=", "pose-amelioration=" }) do
      check(t:find(k, 1, true) ~= nil, lang .. " : " .. k)
    end
  end
end

print(string.format("s44 commande-upgrade : %d OK, %d ECHEC", passes, failures))
if failures > 0 then os.exit(1) end
