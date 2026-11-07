--[[
  Lot X10-CHEMINS (L5) : banc HORS JEU, moteur simulé (tests/mock_engine.lua, option water_paths : un chemin vers un disque sans
  terre échoue toujours, sans tirage). Critères : fo-logs/2026-11-07_X10/CHEMINS_CRITERES.md §1.2.
  Votre équipe (coffre posé, départ ordinaire) ; gisements à 60 tuiles du QG ; un ANNEAU d'eau entre le QG et eux : les points de
  passage de la variation (shared/ai3/route.lua) y tombent, comme dans la partie du DC (5 344 buts dans l'eau).
    1. témoin (L5 coupé dans la source du service) : des demandes partent vers un disque tout eau ;
    2. avec L5 : AUCUNE demande vers un disque tout eau ; les refus sont comptés (refused_water) ;
    3. mêmes livraisons : tâches réussies au moins celles du témoin à 2 % près ; blocages (stuck) pas plus nombreux ;
    4. déterminisme : deux passages avec L5 identiques.
  Lancement : lua5.2 tests/chemins_moteur_test.lua (depuis la racine du mod). Environ 1 à 2 min.
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end

local TICKS = tonumber(os.getenv("FO_CHEMINS_TICKS") or "") or 36000

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local PS_SRC = read("script/core/path_service.lua")
local function patch(src, old, new)
  local i, j = src:find(old, 1, true)
  assert(i, "texte introuvable : " .. old)
  assert(not src:find(old, j + 1, true), "texte en double : " .. old)
  return src:sub(1, i - 1) .. new .. src:sub(j + 1)
end
-- Témoin : L5 coupé (ni refus du but, ni demande sans marge) : le service d'avant le lot.
local OFF_SRC = patch(patch(PS_SRC, "if info and Ch.precheck(obs) == \"refuse_water\" then", "if false then"),
  "if Ch.precheck(obs) == \"unpad\" then", "if false then")

local function install(src)
  package.preload["script.core.path_service"] = src and function() return assert(load(src, "=path_service_temoin", "t"))() end or nil
  package.loaded["script.core.path_service"] = nil
end

local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.floor(math.cos(a) * 60 + 0.5), y = math.floor(math.sin(a) * 60 + 0.5), name = names[i % 4 + 1] }
  end
  return out
end

-- ANNEAU d'eau de 22 à 34 tuiles autour du QG (coffre en (0, 0)), sur le trajet de TOUS les gisements (à 60 tuiles) : le point de
-- passage tiré au tiers du trajet (20 tuiles, écart de 8 à 20) y tombe souvent (le moteur simulé ne bloque pas la marche dans l'eau).
local RING = { r0 = 22, r1 = 34 }
local function tile_at(x, y)
  local d2 = (x + 0.5) ^ 2 + (y + 0.5) ^ 2
  if d2 >= RING.r0 * RING.r0 and d2 <= RING.r1 * RING.r1 then return "water" end
  return "grass-1"
end

local function run(src, journal)
  install(src)
  M.new_game({ patches = patches(), tile_at = tile_at, water_paths = true, p_busy = 0, p_nopath = 0, p_lost = 0 })
  if journal then remote.call("fo-chemins", "journal", true) end
  -- Demandes reçues par le moteur vers un disque de rayon radius + 1,5 SANS terre (centre de tuile) : ce que L5 sait PROUVER
  -- impossible (shared/nav/chemins.lua). Le moteur simulé, lui, fait échouer tout but sans terre à moins de radius + 0,71 : l'écart
  -- (terre entre les deux rayons) est la marge qui garde la règle juste quelle que soit la façon dont le moteur compte les tuiles.
  local surf = game.surfaces[1]
  local rp = surf.request_path
  local proven = 0
  surf.request_path = function(t)
    local gx, gy, R = t.goal.x, t.goal.y, (t.radius or 1) + 1.5
    local land = false
    for ty = math.floor(gy - R), math.floor(gy + R) do
      for tx = math.floor(gx - R), math.floor(gx + R) do
        if (tx + 0.5 - gx) ^ 2 + (ty + 0.5 - gy) ^ 2 <= R * R and tile_at(tx, ty) ~= "water" then land = true end
      end
    end
    if not land then proven = proven + 1 end
    return rp(t)
  end
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 0.5, y = 0.5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 800 }, { "copper-plate", 300 }, { "coal", 400 }, { "stone", 200 }, { "pistol", 4 },
    { "firearm-magazine", 80 }, { "wood", 100 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  M.world().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  M.run_ticks(TICKS)
  local W = M.world()
  local fo = global.fo
  local ok, fail = 0, 0
  local f = fo.pteam and fo.pteam.team
  if f then
    local ts = f.team and f.team.task_stats or {}
    for _, k in ipairs((function() local ks = {} for k in pairs(ts) do ks[#ks + 1] = k end table.sort(ks) return ks end)()) do
      ok, fail = ok + ts[k].ok, fail + ts[k].fail
    end
  end
  local cs = fo.companion.stats
  local ps = fo.path.stats
  local res = { proven = proven, ok = ok, fail = fail, stuck = cs.stuck or 0, path_fail = cs.path_fail or 0, water_requests = W.water_requests or 0,
    path_requests = W.path_requests or 0, refused = ps.refused_water or 0, unpad = ps.start_unpadded or 0, requested = ps.requested or 0,
    agents = 0, dump = M.serialize(fo.path.stats) .. "|" .. M.serialize(fo.companion.stats), jl = 0, pl = 0 }
  for _, l in ipairs(W.logs) do
    if l:find("[FO-CHEMINS-J]", 1, true) then res.jl = res.jl + 1 end
    if l:find("[FO-CHEMINS-P]", 1, true) then res.pl = res.pl + 1 end
  end
  for _ in pairs(fo.companion.agents) do res.agents = res.agents + 1 end
  install(nil)
  return res
end

local function show(tag, r)
  print(string.format("  %s : %d PNJ, tâches ok %d, échouées %d, blocages %d, échecs de chemin %d ; demandes au service %d, au moteur %d dont %d vers un but sans terre à radius + 0,71 et %d sans terre à radius + 1,5 ; refus L5 %d ; sans marge %d",
    tag, r.agents, r.ok, r.fail, r.stuck, r.path_fail, r.requested, r.path_requests, r.water_requests, r.proven, r.refused, r.unpad))
end

section("1. Témoin (L5 coupé) : des demandes partent vers un disque tout eau")
local t = run(OFF_SRC)
show("témoin", t)
check(t.agents > 0 and t.ok > 0, "le témoin fait travailler des PNJ (" .. t.agents .. " PNJ, " .. t.ok .. " tâches)")
check(t.proven >= 10, "témoin : demandes au moteur vers un disque sans terre à radius + 1,5, 10 au moins (" .. t.proven .. ")")
check(t.refused == 0, "témoin : aucun refus (" .. t.refused .. ")")

section("2. Avec L5 : aucune demande vers un disque tout eau")
local a = run(nil)
show("L5", a)
check(a.proven == 0, "L5 : aucune demande au moteur vers un disque sans terre à radius + 1,5 (" .. a.proven .. ")")
check(a.refused == t.proven, string.format("L5 : chaque demande vouée à l'échec du témoin est refusée (%d refus, %d au témoin)", a.refused, t.proven))
check(a.water_requests < t.water_requests, string.format("demandes vouées à l'échec (radius + 0,71) en baisse : %d contre %d", a.water_requests, t.water_requests))

section("3. Mêmes livraisons, pas plus de blocages")
check(a.ok >= math.floor(t.ok * 0.98), string.format("tâches réussies : %d contre %d au témoin (au moins 98 %%)", a.ok, t.ok))
check(a.stuck <= t.stuck, string.format("blocages : %d contre %d au témoin", a.stuck, t.stuck))
check(a.path_requests < t.path_requests, string.format("demandes au moteur en baisse : %d contre %d", a.path_requests, t.path_requests))

section("4. Déterminisme ; le journal (relevé) ne change rien")
check(a.jl == 0 and a.pl == 0, "journal coupé par défaut : aucune ligne [FO-CHEMINS-J] ni [FO-CHEMINS-P] (" .. a.jl .. ", " .. a.pl .. ")")
local b = run(nil, true)
check(a.dump == b.dump and a.ok == b.ok, "second passage avec L5, journal allumé : mêmes compteurs du service et des PNJ")
check(b.jl > 0 and b.pl > 0, "journal allumé : lignes des demandes (" .. b.jl .. ") et des itinéraires (" .. b.pl .. ")")

print(string.format("[X10-CHEMINS-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
