--[[
  Lot EQUIPE (1/11) : banc HORS JEU, moteur simulé (tests/mock_engine.lua). Lancement : lua5.2 tests/equipe_moteur_test.lua (racine du mod).
  Votre équipe (coffre posé, fer et cuivre d'un départ pauvre) :
    1. la technologie de la tourelle passe en tête de sa recherche (« K1 : defense : tourelle avant le reste »), comme pour une faction ;
       déjà faite : aucune ligne de ce genre ;
    2. le planificateur du moteur simulé applique le premier palier (journal [FO-DEFENSE] « premiere tourelle ») ; sans lui (FIRST_N = 0,
       mutant), la ligne disparaît.
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end
local function W() return M.world() end

local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end

local function run(opts)
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0 })
  if opts.researched then game.forces.player.technologies["gun-turret"].researched = true end
  -- (le moteur simulé recharge les modules à chaque partie : la valeur se pose APRÈS new_game)
  if opts.no_defense_first then require("shared.ai3.general").defense_first = function() end end
  if opts.first_n then require("shared.team.premiere_tourelle").FIRST_N = opts.first_n end
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", opts.iron }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 }, { "pistol", 2 },
    { "firearm-magazine", 40 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  -- Lot PARITE : le QG naît avec les 4 tourelles d'une faction ; ce banc juge le PREMIER palier d'un QG SANS tourelle, elles sont retirées
  -- (tests/parite_test.lua prouve le départ lui-même ; opts.keep_turrets les garde).
  if not opts.keep_turrets then
    for _, e in ipairs(s.find_entities_filtered({ name = "gun-turret", force = "player" })) do e.destroy() end
  end
  M.run_ticks(opts.ticks)
  local logs, turrets = W().logs, 0
  for _, e in ipairs(W().entities) do
    if e.valid and e.name == "gun-turret" and e.force and e.force.name == "player" then turrets = turrets + 1 end
  end
  local function count(tag, tag2)
    local n = 0
    for _, l in ipairs(logs) do if l:find(tag, 1, true) and (not tag2 or l:find(tag2, 1, true)) then n = n + 1 end end
    return n
  end
  return { k1 = count("[FO-CERVEAU] player", "defense : tourelle avant le reste"), first = count("[FO-DEFENSE] player", "premiere tourelle"),
    turrets = turrets }
end

section("1. La technologie de la tourelle passe en tête de la recherche de votre équipe")
local a = run({ iron = 214, ticks = 1800 })
check(a.k1 >= 1, "recherche de la tourelle choisie « avant le reste » (" .. a.k1 .. " ligne(s))")
local b = run({ iron = 214, ticks = 7200, researched = true })
check(b.k1 == 0, "technologie déjà faite : aucune ligne « avant le reste » (" .. b.k1 .. ")")

local mu = run({ iron = 214, ticks = 1800, no_defense_first = true })
check(mu.k1 == 0, "mutant : sans la règle de palier (Gen.defense_first), la ligne disparaît (" .. mu.k1 .. ")")

section("2. Le fer d'un coffre pauvre paie la première tourelle")
check(b.first >= 1, "journal [FO-DEFENSE] : « premiere tourelle » (" .. b.first .. " ligne(s))")
-- Mutant : sans premier palier (FIRST_N = 0), le QG garde le plancher ordinaire et la ligne n'apparaît jamais.
local m = run({ iron = 214, ticks = 7200, researched = true, first_n = 0 })
check(m.first == 0, "mutant FIRST_N = 0 : plus de ligne « premiere tourelle » (" .. m.first .. ")")
-- Lot PARITE : un QG qui naît avec ses 4 tourelles (départ d'une faction) n'a plus de premier palier à payer.
local c = run({ iron = 214, ticks = 7200, researched = true, keep_turrets = true })
check(c.first == 0, "QG né avec ses 4 tourelles : aucune ligne « premiere tourelle » (" .. c.first .. ")")
check(c.turrets >= 4, "QG né avec ses 4 tourelles : au moins 4 tourelles à la fin (" .. c.turrets .. ")")
-- (Le nombre de tourelles posées n'est pas jugé ici : le moteur simulé dépense le fer du départ avant la première pensée de défense, et
-- le résultat varie avec la quantité de fer sans ordre ; la preuve du palier est au planificateur, tests/equipe_defense_test.lua.)
print(string.format("[EQUIPE-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
