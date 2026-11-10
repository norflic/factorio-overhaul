--[[
  Lot CC-GISEMENT (F490, 10/11/2026) : test hors jeu du site d'avant-poste « hostile » (script/faction/sites.lua, probe).
  Usage, depuis la racine du mod :   lua5.2 tests/site_feu_test.lua

  Partie du DC sur la 0.6.87 (graine 3592985581, fo-logs/2026-11-10_PLAYTEST-0687) : au tick 180, les quatre sites de fer à
  23-31 tuiles du coffre d'équipe (6, 6) sont refusés « hostile » et écartés 30 min ; au tick 515 le seul site de la réserve est
  à 177 tuiles (rang 1 sur 1) et l'équipe y tire sa ligne de poteaux. Le test comptait TOUTE entité de la force « enemy » à
  48 tuiles : les flammes de l'épave de freeplay (crash-site-fire-flame, créées sans force : « enemy » par défaut du moteur,
  type « fire ») sont posées autour de (-5, -6).

  Vérifie, en moteur simulé, sur le module chargé depuis sa source (et sur chaque mutant de cette source) :
    §1 une flamme ennemie à 25 tuiles du gisement proche ne le fait pas refuser : il entre en réserve et c'est lui qui est
       remis (plus petite distance au QG) ; le gisement à 167 tuiles reste derrière ;
    §2 un ver, un nid, une unité ennemie au même endroit le font refuser « hostile », avec le combattant nommé dans la trace ;
       un ver à 60 tuiles ne le bloque pas (rayon de 48 tuiles) ;
    §3 l'origine de la spirale est le QG de l'équipe, pas (0, 0) : QG loin de l'origine, le gisement voisin du QG est remis ;
    §4 mutants de la source (au moins une propriété rouge chacun) ; §5 aucun nom d'objet du jeu dans la règle.
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("script/faction/sites.lua")

local ok_n, bad = 0, 0
local function check(name, cond)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[SITE-FEU] ECHEC : " .. name) end
end

M.new_game({ seed = 4242, patches = {}, p_busy = 0, p_nopath = 0, p_lost = 0 })
M.command("fo-war", "start 2 100 10 320")
local war = global.fo.war
local W = M.world()
local surf = game.surfaces[war.surface]
local Scheduler = require("script.core.scheduler")
require("script.faction.sites") -- le module du jeu (sa voie de prospection est définie une fois)

W.prototypes["crash-site-fire-flame"] = { type = "fire", max_health = 1 }
W.prototypes["small-worm-turret"] = { type = "turret", max_health = 200 }
W.prototypes["biter-spawner"] = { type = "unit-spawner", max_health = 350 }
W.prototypes["small-biter"] = { type = "unit", max_health = 15 }

--- Module chargé depuis une source (la vraie ou un mutant) : la voie de prospection n'est pas redéfinie.
local function load_sites(src)
  local saved = Scheduler.define_lane
  Scheduler.define_lane = function() end
  local fn = load(src, "=sites", "t")
  local ok, m = false, nil
  if fn then ok, m = pcall(fn) end
  Scheduler.define_lane = saved
  return ok and type(m) == "table" and m or nil
end

local TICK = 180
local QG = { x = 6, y = 6 }            -- coffre d'équipe de la partie du DC
local NEAR = { x = -16.5, y = 16.5 }   -- gisement voisin (chunk (-1, 0)), 25 tuiles du QG
local FAR = { x = 80.5, y = -143.5 }   -- gisement lointain (chunk (2, -5)), 167 tuiles du QG
local FIRE = { x = -5.5, y = -6.5 }    -- épave de freeplay (-5, -6)

local enemies = {}
local function clear()
  for _, e in ipairs(enemies) do if e.valid then e.destroy() end end
  enemies = {}
  war.unreachable, war.claims, war.claim_pos = {}, {}, {}
  W.patches = {}
  W.logs = {}
end
local function patch(p) W.patches[#W.patches + 1] = { x = p.x, y = p.y, name = "iron-ore", amount = 500000 } end
local function foe(name, p) enemies[#enemies + 1] = surf.create_entity({ name = name, position = { x = p.x, y = p.y }, force = "enemy" }) end
local function team(hq)
  return { is_player = true, key = "player", id = 99, hq_pos = hq, prospects = {}, stats = {}, outposts = {},
    site_needs = { ["iron-ore"] = 2 } }
end
local function scan(S, f)
  S.seen_filter = nil
  for _ = 1, 600 do S.prospect(f, surf, TICK) end
end
local function near_to(s, p) return s ~= nil and (s.x - p.x) ^ 2 + (s.y - p.y) ^ 2 < 9 end
local function logged(pattern)
  for _, l in ipairs(W.logs) do if l:find(pattern, 1, true) then return l end end
  return nil
end
local function hostile_case(S, name)
  clear()
  patch(NEAR) patch(FAR)
  foe(name, FIRE)
  local f = team(QG)
  scan(S, f)
  local first = S.find(f, surf, TICK, "iron-ore")
  return first, logged("motif hostile")
end

local function suite(S)
  local res = {}
  local function c(name, cond) res[#res + 1] = { name, cond and true or false } end
  if not S then c("module chargé", false) return res end
  -- §1 Flamme de l'épave (force « enemy », type « fire ») : pas hostile, le gisement voisin est remis.
  local first, line = hostile_case(S, "crash-site-fire-flame")
  c("flamme : le gisement voisin (25 tuiles) est remis le premier", near_to(first, NEAR))
  c("flamme : aucun refus hostile", line == nil)
  -- §1 bis Sans ennemi : le plus proche d'abord (spirale du QG vers l'extérieur).
  clear()
  patch(NEAR) patch(FAR)
  local f = team(QG)
  scan(S, f)
  c("sans ennemi : deux sites en réserve, le voisin en tête", #f.prospects == 2 and near_to(f.prospects[1], NEAR))
  c("sans ennemi : remis dans l'ordre des distances", near_to(S.find(f, surf, TICK, "iron-ore"), NEAR)
    and near_to(S.find(f, surf, TICK, "iron-ore"), FAR))
  -- §2 Combattants ennemis : refus hostile, combattant nommé ; le lointain prend la tête.
  for _, k in ipairs({ { "small-worm-turret", "turret" }, { "biter-spawner", "unit-spawner" }, { "small-biter", "unit" } }) do
    first, line = hostile_case(S, k[1])
    c(k[2] .. " a 25 tuiles : refus hostile", line ~= nil)
    c(k[2] .. " a 25 tuiles : le voisin n'est pas remis", not near_to(first, NEAR))
    c(k[2] .. " a 25 tuiles : combattant nomme dans la trace", line ~= nil and line:find(k[1], 1, true) ~= nil)
  end
  -- §2 bis Rayon de 48 tuiles : un ver à 60 tuiles du gisement ne le bloque pas.
  clear()
  patch(NEAR) patch(FAR)
  foe("small-worm-turret", { x = NEAR.x, y = NEAR.y + 60 })
  f = team(QG)
  scan(S, f)
  c("ver a 60 tuiles : le voisin est remis", near_to(S.find(f, surf, TICK, "iron-ore"), NEAR) and logged("motif hostile") == nil)
  -- §3 Origine de la spirale : le QG, pas (0, 0).
  clear()
  local q = { x = -294, y = 6 }
  local by_hq, by_origin = { x = -335.5, y = 16.5 }, { x = -16.5, y = 16.5 }
  patch(by_hq) patch(by_origin)
  f = team(q)
  f.site_needs = { ["iron-ore"] = 1 }
  scan(S, f)
  c("QG loin de l'origine : le gisement voisin du QG est remis", near_to(S.find(f, surf, TICK, "iron-ore"), by_hq))
  return res
end

-- §1-§3 sur la source du jeu.
local REAL = load_sites(SRC)
for _, r in ipairs(suite(REAL)) do check(r[1], r[2]) end

-- §4 Mutants : chacun doit faire rougir au moins une propriété.
local function mutant(name, from, to)
  local a, b = SRC:find(from, 1, true)
  if not a then check("mutant " .. name .. " : motif introuvable dans la source", false) return end
  local m = SRC:sub(1, a - 1) .. to .. SRC:sub(b + 1)
  local red = false
  for _, r in ipairs(suite(load_sites(m))) do if not r[2] then red = true end end
  check("mutant refuse : " .. name, red)
end
mutant("toute entite ennemie (defaut d'origine)", "type = HOSTILE_TYPES,", "")
mutant("vers oublies", "{ \"unit-spawner\", \"turret\", \"unit\" }", "{ \"unit-spawner\", \"unit\" }")
mutant("nids oublies", "{ \"unit-spawner\", \"turret\", \"unit\" }", "{ \"turret\", \"unit\" }")
mutant("unites oubliees", "{ \"unit-spawner\", \"turret\", \"unit\" }", "{ \"unit-spawner\", \"turret\" }")
mutant("rayon 20", "local ENEMY_CLEARANCE = 48", "local ENEMY_CLEARANCE = 20")
mutant("rayon 80", "local ENEMY_CLEARANCE = 48", "local ENEMY_CLEARANCE = 80")
mutant("spirale inversee (le plus loin d'abord)", "if p.d2 ~= q.d2 then return p.d2 < q.d2 end", "if p.d2 ~= q.d2 then return p.d2 > q.d2 end")
mutant("distance depuis (0, 0)", "local origin = front or f.hq_pos", "local origin = front or { x = 0, y = 0 }")

-- §5 La règle ne nomme aucun objet du jeu (types du moteur seulement).
local CODE = {}
for l in SRC:gmatch("[^\n]*") do CODE[#CODE + 1] = (l:gsub("%-%-.*$", "")) end
CODE = table.concat(CODE, "\n")
check("aucun nom de l'epave dans le code de la regle", not CODE:find("crash%-site") and not CODE:find("fire", 1, true))

print(string.format("[SITE-FEU] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
