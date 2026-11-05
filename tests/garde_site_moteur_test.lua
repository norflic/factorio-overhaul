--[[
  Lot PERIMETRE2 : banc HORS JEU de la chaîne « garde des sites » au moteur simulé (tests/mock_engine.lua). Lancement :
  lua5.2 tests/garde_site_moteur_test.lua (racine du mod). Votre équipe riche ; un avant-poste attaqué (foreuse de l'équipe tuée, vague de 18) :
    1. la vague est notée au site ; le site veut un groupe de 4 ; le planificateur ouvre la tâche « garde » ; un PNJ pose un GROUPE (au moins
       3 tourelles à moins de 10 tuiles du centre du groupe, chacune à portée d'une autre) ;
    2. budget : coffre sous 2 000 de fer : aucune tourelle de la garde ;
    3. murs retirés par le joueur : la tuile est rendue POUR TOUJOURS (pièce abandonnée, jamais reposée, jamais replanifiée) ; un mur posé
       par le joueur rend sa zone non murable (usine du joueur) ; un mur DÉTRUIT par l'ennemi n'est pas rendu ; un mur du joueur hors des
       tuiles de l'équipe n'est pas retenu ; la règle est revérifiée à la pose du fantôme (Build.wall_veto) ;
    4. avant-poste disparu : son anneau quitte la réparation, son chantier rouvert est abandonné (relecture du lead, point A) ;
    5. avant-poste agrandi : l'ancien anneau est jeté, le nouveau suit l'emprise (point B) ;
    6. DEPENSES : repli quand il est absent, éteint ou périmé ; l'accordé est débité dès la dépense (risque C).
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
-- mesure du plancher (lecture seule, demande du lead du 5/11) : fer à la vague, budget 0 compté, perte sensible classée
local lv, lg, ll = logs("[FO-PERIMETRE] player : vague a l'avant-poste"), logs("[FO-PERTE] player garde a"), {}
for _, l in ipairs(logs("[FO-PERTE] player minute")) do if l:find("burner-mining-drill", 1, true) then ll[#ll + 1] = l end end
for _, l in ipairs({ lv[1], lg[#lg], ll[1] }) do print("    " .. tostring(l):sub(1, 260)) end
check(#lv >= 1 and lv[1]:find("(18 ennemis)", 1, true) and lv[1]:find("fer au stock", 1, true), "vague notée avec le fer au stock")
check(#lg >= 1 and lg[#lg]:match("budget 0 : (%d+) %(pauvre") ~= nil and tonumber(lg[#lg]:match("budget 0 : (%d+)")) > 0, "relevé : plans au budget 0 comptés, raison « pauvre »")
check(#ll >= 1 and ll[1]:find("| garde ", 1, true) ~= nil, "perte sensible à l'avant-poste : classée (groupe complet, budget 0, attente)")

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
  b.next_id = math.max(b.next_id or 1, pid + 1) -- (l'index des tuiles de murs suit les projets nouveaux par b.next_id)
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
    -- un mur du joueur démonté HORS des tuiles de l'équipe : rien retenu (walls_released ne grossit pas)
    local w3 = s3.create_entity({ name = "stone-wall", position = { x = 60.5, y = 60.5 }, force = "player" })
    W().events[defines.events.on_player_mined_entity]({ entity = w3, player_index = 1, tick = game.tick })
    w3.destroy()
    check(b.walls_released[P.tkey(60, 60)] == nil and #logs("mur retire par le joueur") == 1, "mur du joueur hors des tuiles de l'équipe : rien retenu")
    -- point 4 : la règle revérifiée au moment de poser le fantôme d'un mur (crochet de revive_one)
    check(Build.wall_veto(f3, s3, { x = 74.5, y = 70.5 }) == "joueur" and Build.wall_veto(f3, s3, { x = 40.5, y = 40.5 }) == "rendue"
      and Build.wall_veto(f3, s3, { x = 90.5, y = 90.5 }) == nil, "pose du fantôme : usine du joueur et tuile rendue refusées, ailleurs permis")
    f3.garde_temoin = true
    check(Build.wall_veto(f3, s3, { x = 74.5, y = 70.5 }) == nil, "témoin : aucun refus (comportement de main)")
    f3.garde_temoin = nil
  else
    check(false, "murs du banc posés")
  end
end
require("shared.team.config").enceinte_joueur = false

local function walls_ctx(rec)
  return { prio = 0, equiv = function() return 400 end, request = function() rec.req = (rec.req or 0) + 1 return nil, "banc" end,
    repair = function(h) rec.repair = #h.segs end }
end
local function fresh_garde(f)
  f.garde = { waves = {}, rest = {}, picks = {}, logs = 0, poses = 0, walls = { segs = {}, claimed = {}, rings = {}, done = {} } }
  return f.garde
end

section("4. Avant-poste disparu : son anneau est oublié (ni réparé ni rouvert)")
-- (le moteur simulé recharge les modules du mod à chaque partie : config et garde relus APRÈS setup)
local f4, s4 = setup(9000)
require("shared.team.config").garde_walls_on = true
Gd = require("script.team.garde_site")
f4.build = f4.build or { projects = {}, order = {}, occ = {} }
local st4 = fresh_garde(f4)
local gone = 9999
f4.outposts[gone] = { pos = { x = 120, y = 120 }, drills = 1 }
local b4 = f4.build
b4.projects[9101] = { id = 9101, state = "fini", spec = { enceinte = true, ilot = "ap" .. gone, walls = { { 117, 117 } } },
  ents = { { name = "stone-wall", x = 117.5, y = 117.5, wall = true, built = true } } }
b4.projects[9102] = { id = 9102, state = "reserve", reopened = 1, spec = { enceinte = true, ilot = "ap" .. gone, walls = { { 118, 117 } } },
  ents = { { name = "stone-wall", x = 118.5, y = 117.5, wall = true, built = false } } }
st4.walls.segs = { { pid = 9101, n = 1, oid = gone, walls = { { 117, 117 } } }, { pid = 9102, n = 1, oid = gone, walls = { { 118, 117 } } } }
st4.walls.claimed[require("shared.team.garde_site").tkey(117, 117)] = true
st4.walls.rings[gone] = { box = { x0 = 119, y0 = 119, x1 = 121, y1 = 121 } }
st4.waves[gone] = { n = 12, tick = game.tick }
f4.outposts[gone] = nil
local rec4 = {}
Gd.walls_step(f4, s4, game.tick, walls_ctx(rec4))
check(#st4.walls.segs == 0 and rec4.repair == 0, "segments de l'avant-poste disparu retirés AVANT la réparation (" .. tostring(rec4.repair) .. ")")
check(st4.walls.rings[gone] == nil and st4.waves[gone] == nil and next(st4.walls.claimed) == nil, "anneau, vague et tuiles oubliés")
local e2 = b4.projects[9102].ents[1]
check(e2.built == true and e2.dropped == true, "chantier rouvert (non annulable) : son mur non posé abandonné, aucun PNJ n'y retourne")
check(#logs("oublies (avant-poste disparu)") == 1, "journal : murs de l'avant-poste oubliés")

section("5. Avant-poste agrandi : l'ancien anneau est jeté, le nouveau suit l'emprise")
local f5, s5 = setup(9000)
require("shared.team.config").garde_walls_on = true
Gd = require("script.team.garde_site")
f5.build = f5.build or { projects = {}, order = {}, occ = {} }
local st5 = fresh_garde(f5)
local State = require("script.faction.state")
local oid5
for _, k in ipairs(State.sorted_keys(f5.outposts)) do if f5.outposts[k].pos then oid5 = k break end end
local o5 = f5.outposts[oid5]
local far = s5.create_entity({ name = "stone-furnace", position = { x = o5.pos.x + 12.5, y = o5.pos.y + 0.5 }, force = "player" })
State.own(far, f5.id, "sink", oid5)
local old = { x0 = math.floor(o5.pos.x) - 1, y0 = math.floor(o5.pos.y) - 1, x1 = math.floor(o5.pos.x) + 1, y1 = math.floor(o5.pos.y) + 1 }
st5.walls.rings[oid5] = { box = old }
f5.build.projects[9201] = { id = 9201, state = "fini", spec = { enceinte = true, walls = { { old.x0 - 3, old.y0 - 3 } } },
  ents = { { name = "stone-wall", x = old.x0 - 2.5, y = old.y0 - 2.5, wall = true, built = true } } }
st5.walls.segs = { { pid = 9201, n = 1, oid = oid5, walls = { { old.x0 - 3, old.y0 - 3 } } } }
st5.walls.done[oid5] = true
st5.waves[oid5] = { n = 12, tick = game.tick }
local rec5 = {}
Gd.walls_step(f5, s5, game.tick, walls_ctx(rec5))
local nb = st5.walls.rings[oid5] and st5.walls.rings[oid5].box
check(nb and nb.x1 >= math.floor(o5.pos.x) + 12, "nouvel anneau autour de la nouvelle emprise (x1 " .. tostring(nb and nb.x1) .. ")")
check(#st5.walls.segs == 0 and not st5.walls.done[oid5] and (rec5.req or 0) == 1, "ancien segment jeté, anneau rouvert, un segment redemandé")
check(#logs("oublies (avant-poste agrandi)") == 1, "journal : ancien anneau oublié")
require("shared.team.config").garde_walls_on = false

section("6. DEPENSES : repli quand il est absent, éteint ou périmé ; l'accordé débité dès la dépense")
local f6 = global.fo.pteam.team
local IRON = "iron-plate"
local calls = {}
local reply, info = {}, nil
Gd.set_dep({ defense = function() return reply, info end })
check(Gd.grant(f6, 1000, IRON) == nil, "accord vide sans état (éteint ou périmé) : repli")
reply, info = { [IRON] = 600 }, { etat = "perime", tick = 900 }
check(Gd.grant(f6, 1000, IRON) == nil, "état « perime » : repli")
reply, info = { [IRON] = 600 }, { etat = "eteint", tick = 900 }
check(Gd.grant(f6, 1000, IRON) == nil, "état « eteint » : repli")
reply, info = { [IRON] = 600 }, { etat = "actif", tick = 900 }
check(Gd.grant(f6, 1000, IRON) == 600, "état « actif » : 600 accordés")
Gd.debit(f6, IRON, 240)
check(Gd.grant(f6, 1100, IRON) == 360, "après une pose de 2 tourelles (240) : 360, jamais redépensés avant la prochaine émission")
reply, info = { [IRON] = 600 }, { etat = "actif", tick = 1200 }
check(Gd.grant(f6, 1300, IRON) == 600, "nouvelle émission : le compte repart de l'accord neuf")
reply, info = { [IRON] = 600 }, nil
check(Gd.grant(f6, 1300, IRON) == 600, "sans info (forme de corr-depenses2) : l'accord tel quel")
Gd.debit(f6, IRON, 480)
check(Gd.grant(f6, 1400, IRON) == 120 and Gd.grant(f6, 1300 + Gd.DEP_TTL, IRON) == 600, "sans info : débit tenu jusqu'à la péremption de DEPENSES (3 min)")
reply, info = { [IRON] = 0 }, { etat = "actif", tick = 2000 }
check(Gd.grant(f6, 2100, IRON) == 0, "actif sans fer accordé : 0 (DEPENSES décide, pas de repli en plus)")
Gd.set_dep({ defense = function() return { [IRON] = 600 }, { etat = "actif", tick = 3000 } end,
  debit = function(_, who, key, qty) calls[#calls + 1] = who .. ":" .. key .. ":" .. qty end })
Gd.debit(f6, IRON, 120)
check(calls[1] == "defense:" .. IRON .. ":120" and Gd.grant(f6, 3100, IRON) == 600, "Dep.debit présent : la dépense lui est rendue, pas de compte local")
Gd.set_dep(nil)
check(Gd.grant(f6, 3200, IRON) == nil, "sans module : repli")
section("7. G3 (essai 3, relecture D2 à D4) : briques à fondre de la pierre qui dort, bornées")
do
  local f7 = global.fo.pteam.team
  local Gs7 = require("shared.team.garde_site")
  local Rsv = require("script.ai3.reserve")
  local input0 = Rsv.input
  local stone_free, covered = 2000, true
  Rsv.input = function() return { covered = covered, free = { ["iron-plate"] = 0, stone = stone_free } } end
  f7.build = f7.build or { projects = {}, order = {}, occ = {} }
  f7.build.enc_need = { walls = 100, equiv = 0, tick = game.tick }
  local t0 = game.tick
  check(Gd.bricks_want(f7, t0, 0) == nil, "enceinte de votre équipe éteinte : aucune brique voulue")
  f7.garde_g3 = true
  local Stock = require("script.team.stock")
  local eq = Stock.count(f7, "stone-wall") + math.floor(Stock.count(f7, "stone-brick") / 5) -- (murs et briques déjà au coffre de l'équipe)
  local bw = Gd.bricks_want(f7, t0, 0)
  check(bw and bw.item == "stone-brick" and bw.n == 5 * (100 - eq) and bw.deficit == 100 - eq,
    "anneau de 100 murs, " .. eq .. " au coffre, 2 000 pierres libres : les briques de tout ce qui manque (" .. tostring(bw and bw.n) .. ")")
  stone_free = 10 * (100 - eq) - 1
  check(Gd.bricks_want(f7, t0, 0) == nil and #logs("aucune : pierre") >= 1, "D2 : la pierre libre ne paie pas tout : rien, cause au journal")
  stone_free, covered = 2000, false
  check(Gd.bricks_want(f7, t0, 0) == nil and #logs("aucune : besoin non couvert") >= 1, "D3 : besoin non couvert : rien")
  covered = true
  game.forces.player.recipes["stone-wall"].enabled = false
  check(Gd.bricks_want(f7, t0, 0) == nil and #logs("aucune : mur non recherche") >= 1, "D4 : mur non recherché par la force : rien")
  game.forces.player.recipes["stone-wall"].enabled = true
  check(Gd.bricks_want(f7, t0, 0) ~= nil and f7.garde.bricks_ep == t0, "demande reprise : la durée de la demande court depuis son début")
  f7.build.enc_need.tick = t0 + Gs7.BRICKS_MAX + 1
  check(Gd.bricks_want(f7, t0 + Gs7.BRICKS_MAX + 1, 0) == nil and #logs("aucune : delai") >= 1, "D2 : 30 min sans anneau payé : demande arrêtée, cause au journal")
  check(Gd.bricks_want(f7, t0 + Gs7.BRICKS_MAX + 2, 0) == nil and #logs("aucune : attente") >= 1, "D2 : pas de reprise avant 30 min")
  f7.build.enc_need.tick = t0 + 2 * Gs7.BRICKS_MAX + 10
  check(Gd.bricks_want(f7, t0 + 2 * Gs7.BRICKS_MAX + 10, 0) ~= nil, "D2 : reprise après le délai si la pierre paie toujours tout")
  check(Gd.bricks_want(f7, t0 + 2 * Gs7.BRICKS_MAX + 10 + 2 * require("shared.team.enceinte").CHECK_TICKS + 1, 0) == nil, "besoin périmé (plus écrit par l'enceinte) : rien")
  f7.garde_temoin = true
  check(Gd.bricks_want(f7, t0, 0) == nil, "témoin : rien")
  f7.garde_temoin, f7.garde_g3 = nil, nil
  f7.build.enc_need = nil
  Rsv.input = input0
end

print(string.format("[GARDE-SITE-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
