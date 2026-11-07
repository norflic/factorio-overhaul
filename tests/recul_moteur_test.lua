--[[
  EFFONDREMENT, filet de RECUL de la recrue gratuite (décision du DC, QCM du 7/11 vers 16 h 56 : « Oui, avec le filet (Recommandé) »),
  au MOTEUR SIMULÉ avec le vrai câblage : script/team/worker.lua (mort d'une recrue gratuite → Sp.recul_death), script/team/team.lua
  (vue : Sp.recul_ready → view.recul_wait ; E4 : agent.free_born, Sp.recul_spawn), shared/team/planner.lua (bloc de reprise).
  Partie : votre équipe (effectif de départ 8), réduite à 2 PNJ ; un « campeur » tue chaque recrue gratuite 10 s (600 ticks) après son
  arrivée, pendant 30 min (le cas de la partie du DC : mitrailleurs de faction à 6 tuiles du QG). Attendu (demande du lead) : environ
  25 recrues en 30 min avec le filet, environ 360 sans (témoin : Sp.recul_death neutralisé, même partie).
  Puis le campeur s'en va : l'équipe revient à son effectif de départ.
  Lancement : lua5.2 tests/recul_moteur_test.lua (depuis la racine du mod ; environ 1 à 3 min).
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")
local Sp = require("shared.team.spirale")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
end

local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end

--- Une partie : rend { spawns (recrues gratuites), killed, workers (fin), floor, waits (attentes vues à chaque mort rapide), recul }.
local function game_run(minutes, camp_minutes, filet)
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0 })
  local Registry = require("script.companion.registry")
  -- M.new_game recharge les modules du mod : le témoin neutralise la règle dans la table chargée par CETTE partie
  local SpG = package.loaded["shared.team.spirale"]
  local real_death = SpG.recul_death
  if not filet then SpG.recul_death = function(st) return st or SpG.recul_new() end end
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "copper-plate", 500 }, { "coal", 400 }, { "firearm-magazine", 194 } }) do chest.insert({ name = it[1], count = it[2] }) end
  M.world().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  local f = global.fo.pteam.team
  local floor = f.engineers_count
  M.run_ticks(60)
  local ids = {}
  for id in pairs(f.engineers) do ids[#ids + 1] = id end
  table.sort(ids)
  for i = 3, #ids do
    local a = Registry.get(ids[i])
    if a and a.entity and a.entity.valid then a.entity.die() end
  end
  M.run_ticks(1)
  local fr0 = (f.stats and f.stats.free_recruits) or 0
  local killed, waits, last_wait = 0, {}, 0
  local camp_end = game.tick + camp_minutes * 3600
  local stop = game.tick + minutes * 3600
  while game.tick < stop do
    M.run_ticks(10)
    local w = f.team.recul and f.team.recul.wait or 0
    if w ~= last_wait then
      waits[#waits + 1] = w
      last_wait = w
    end
    if game.tick < camp_end then
      local list = {}
      for id in pairs(f.engineers) do list[#list + 1] = id end
      table.sort(list)
      for _, id in ipairs(list) do
        local a = Registry.get(id)
        if a and a.free_born and game.tick - a.free_born >= 600 and a.entity and a.entity.valid then
          a.entity.die()
          killed = killed + 1
        end
      end
    end
  end
  SpG.recul_death = real_death
  return { spawns = ((f.stats and f.stats.free_recruits) or 0) - fr0, killed = killed, workers = f.engineers_count, floor = floor,
    waits = waits, recul = f.team.recul }
end

print("== Filet allume : campeur 30 min")
local on = game_run(30, 30, true)
print(string.format("   recrues gratuites %d, tuees %d, attentes %s", on.spawns, on.killed, table.concat(on.waits, ",", 1, math.min(8, #on.waits))))
check(on.floor >= 8, "effectif de depart " .. tostring(on.floor))
check(on.spawns >= 15 and on.spawns <= 40, "filet : environ 25 recrues en 30 min sous le campeur (" .. on.spawns .. ")")
check(#on.waits == 4 and on.waits[1] == 600 and on.waits[2] == 1200 and on.waits[3] == 2400 and on.waits[4] == 3600,
  "attentes vues : 600, 1 200, 2 400, puis 3 600 tenu jusqu'au bout (" .. table.concat(on.waits, ",") .. ")")

print("== Temoin : meme partie, filet neutralise (Sp.recul_death sans effet)")
local off = game_run(30, 30, false)
print(string.format("   recrues gratuites %d, tuees %d", off.spawns, off.killed))
check(off.spawns >= 300, "sans filet : une recrue par pensee, environ 360 en 30 min (" .. off.spawns .. ")")

print("== Campeur 10 min, puis partie calme 20 min")
local back = game_run(30, 10, true)
local ready = back.recul == nil or Sp.recul_ready(back.recul, game.tick)
print(string.format("   recrues gratuites %d, effectif final %d/%d, attente %s", back.spawns, back.workers, back.floor,
  tostring(back.recul and back.recul.wait)))
check(back.workers >= back.floor, "le campeur parti, l'equipe revient a son effectif de depart (" .. back.workers .. "/" .. back.floor .. ")")
check(ready and (back.recul == nil or back.recul.wait == 0), "5 min sans mort rapide : attente remise a 0")

print(string.format("[RECUL-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
