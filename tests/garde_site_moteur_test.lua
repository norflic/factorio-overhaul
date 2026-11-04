--[[
  Lot PERIMETRE2 : banc HORS JEU de la chaîne « garde des sites » au moteur simulé (tests/mock_engine.lua). Lancement :
  lua5.2 tests/garde_site_moteur_test.lua (racine du mod). Votre équipe riche ; un avant-poste attaqué (foreuse de l'équipe tuée, vague de 18) :
    1. la vague est notée au site ; le site veut un groupe de 4 ; le planificateur ouvre la tâche « garde » ; un PNJ pose un GROUPE (au moins
       3 tourelles à moins de 10 tuiles du centre du groupe, chacune à portée d'une autre) ;
    2. budget : coffre sous 2 000 de fer : aucune tourelle de la garde ;
    3. murs retirés par le joueur : la tuile est rendue POUR TOUJOURS (pièce abandonnée, jamais reposée, jamais replanifiée) ; un mur posé
       par le joueur rend sa zone non murable (usine du joueur) ; un mur DÉTRUIT par l'ennemi n'est pas rendu.
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")
local passes, failures = 0, 0
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. m) end end
local function section(n) print("== " .. n) end
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

local function setup(iron)
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0 })
  game.forces.player.technologies["gun-turret"].researched = true
  W().prototypes["gun-turret"].turret_range = 18
  -- besoin évalué : fer libre hors besoin (le cerveau l'écrit en jeu ; ici donné)
  require("script.ai3.reserve").input = function() return { covered = true, free = { ["iron-plate"] = iron - 500 } } end
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", iron }, { "copper-plate", 3000 }, { "coal", 400 }, { "stone", 400 }, { "pistol", 2 },
    { "firearm-magazine", 400 }, { "gun-turret", 10 }, { "stone-furnace", 8 }, { "burner-mining-drill", 8 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  M.run_ticks(9000)
  return global.fo.pteam.team, s
end

local function attack(f, s)
  local State = require("script.faction.state")
  -- une foreuse de l'équipe à un avant-poste, tuée par un mordeur au milieu d'une vague de 18
  local oid
  for _, k in ipairs(State.sorted_keys(f.outposts)) do if f.outposts[k].pos then oid = k break end end
  if not oid then return nil end
  local o = f.outposts[oid]
  local drill = s.create_entity({ name = "burner-mining-drill", position = { x = o.pos.x + 2, y = o.pos.y + 2 }, force = "player" })
  State.own(drill, f.id, "drill", oid)
  local biters = {}
  for i = 1, 18 do biters[i] = s.create_entity({ name = "small-biter", position = { x = o.pos.x + 30, y = o.pos.y + i - 9 }, force = "enemy" }) end
  -- (à 30 tuiles du site : la vague est comptée autour de la pièce morte, à 30 tuiles)
  for _, b in ipairs(biters) do b.teleport({ x = o.pos.x + 2 + (b.position.y - o.pos.y) * 0.5, y = o.pos.y + 20 }) end
  W().events[defines.events.on_entity_died]({ entity = drill, force = game.forces.enemy, cause = biters[1], tick = game.tick })
  drill.destroy()
  for _, b in ipairs(biters) do b.destroy() end -- partis : la pose se fait au calme
  return oid, o
end

local function logs(tag)
  local out = {}
  for _, l in ipairs(W().logs) do if l:find(tag, 1, true) then out[#out + 1] = l end end
  return out
end

section("1. Avant-poste attaqué, équipe riche : un groupe posé")
local f, s = setup(9000)
local oid, o = attack(f, s)
check(oid ~= nil, "un avant-poste de l'équipe existe")
local Gd = require("script.team.garde_site")
check(f.garde and f.garde.waves[oid] and f.garde.waves[oid].n == 18, "vague de 18 notée au site " .. tostring(oid))
M.run_ticks(20000)
local lw = logs("[FO-PERIMETRE] player : groupe voulu a l'avant-poste " .. tostring(oid) .. " (vague vue 18)")
local lp = logs("[FO-PERIMETRE] player : pose de")
for i = 1, math.min(2, #lw) do print("    " .. lw[i]:sub(1, 220)) end
for i = 1, math.min(3, #lp) do print("    " .. lp[i]:sub(1, 200)) end
check(#lw >= 1 and lw[1]:find("sur 4,", 1, true) ~= nil, "groupe voulu : 4 tourelles (vague de 18)")
local pk = f.garde.picks[oid]
local g = pk and require("shared.team.garde_site").spots(o.pos, pk.nx, pk.ny)
local group = {}
for _, e in ipairs(W().entities) do
  if g and e.valid and e.name == "gun-turret" and e.force and e.force.name == "player" then
    local d = math.sqrt((e.position.x - g.x) ^ 2 + (e.position.y - g.y) ^ 2)
    if d <= 10 then group[#group + 1] = e.position end
  end
end
local covered = #group >= 3
for i, a in ipairs(group) do
  local ok = false
  for j, b in ipairs(group) do if i ~= j and math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) <= 18 then ok = true end end
  if not ok then covered = false end
end
check(#lp >= 1 and covered, "au moins 3 tourelles en groupe à moins de 10 tuiles du centre, chacune à portée d'une autre (" .. #group .. ")")

section("2. Budget : équipe sous 2 000 de fer")
local f2, s2 = setup(1500)
attack(f2, s2)
M.run_ticks(15000)
check(#logs("[FO-PERIMETRE] player : pose de") == 0, "aucune tourelle de la garde sous 2 000 de fer")

section("3. Murs retirés par le joueur, usine du joueur")
local f3, s3 = setup(9000)
-- (l'enceinte de votre équipe est éteinte par défaut depuis l'essai 2 : allumée ici pour juger le mécanisme des murs rendus)
require("shared.team.config").enceinte_joueur = true
-- (le moteur simulé ne bâtit pas de plan directeur pour votre équipe : son état minimal, lu par le crochet et la réparation)
f3.build = f3.build or { projects = {}, order = {}, occ = {} }
W().prototypes["stone-wall"] = W().prototypes["stone-wall"] or { type = "wall", max_health = 350,
  collision_box = { left_top = { x = -0.29, y = -0.29 }, right_bottom = { x = 0.29, y = 0.29 } }, collision_mask = W().prototypes["gun-turret"].collision_mask }
local b = f3.build
if b then
  -- un segment de murs de l'équipe, fini, avec deux murs posés
  local P = require("shared.team.plan")
  local pid = 9001
  b.projects[pid] = { id = pid, state = "fini", spec = { enceinte = true, ilot = "ap-test", walls = { { 40, 40 }, { 41, 40 } } },
    ents = { { name = "stone-wall", x = 40.5, y = 40.5, wall = true, built = true }, { name = "stone-wall", x = 41.5, y = 40.5, wall = true, built = true } } }
  b.order[#b.order + 1] = pid
  local w1 = s3.create_entity({ name = "stone-wall", position = { x = 40.5, y = 40.5 }, force = "player" })
  local w2 = s3.create_entity({ name = "stone-wall", position = { x = 41.5, y = 40.5 }, force = "player" })
  if w1 and w2 then
    W().events[defines.events.on_player_mined_entity]({ entity = w1, player_index = 1, tick = game.tick })
    w1.destroy()
    local e1, e2 = b.projects[pid].ents[1], b.projects[pid].ents[2]
    check(e1.dropped == true and e1.built == true, "mur retiré par le joueur : pièce abandonnée (jamais reposée par la réparation)")
    check(b.walls_released and b.walls_released[P.tkey(40, 40)] == true, "tuile rendue au joueur, pour toujours")
    local Build = require("script.team.build")
    local mask = Build.wall_mask(f3, s3, { { 30, 30, 50, 50 } })
    check(mask and mask(40, 40) == "rendue", "tuile rendue jamais replanifiée")
    -- un mur DÉTRUIT par l'ennemi n'est pas rendu (la réparation le repose)
    W().events[defines.events.on_entity_died]({ entity = w2, force = game.forces.enemy, tick = game.tick })
    w2.destroy()
    check(not e2.dropped and not b.walls_released[P.tkey(41, 40)], "mur détruit par l'ennemi : pas rendu, la réparation le reposera")
    -- un mur posé par le JOUEUR (pas à l'équipe) : sa zone n'est pas murée par l'équipe
    s3.create_entity({ name = "stone-wall", position = { x = 70.5, y = 70.5 }, force = "player" })
    local mask2 = Build.wall_mask(f3, s3, { { 60, 60, 80, 80 } })
    check(mask2 and mask2(74, 70) == "joueur" and mask2(77, 70) == nil, "usine du joueur : rien à moins de 6 tuiles de ses bâtiments")
    check(#logs("mur retire par le joueur") == 1, "journal : une ligne « mur retiré par le joueur »")
  else
    check(false, "murs du banc posés")
  end
end
print(string.format("[GARDE-SITE-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
