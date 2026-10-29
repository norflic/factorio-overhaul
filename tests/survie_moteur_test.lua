--[[
  Lot SURVIE-PENURIE : banc HORS JEU de la CHAÎNE complète, moteur simulé (tests/mock_engine.lua). Votre équipe (coffre posé, 30
  plaques de fer, 8 fours, 200 charbons), réglage fo-war-ia3-comportement allumé, vers posé sur la carte de l'équipe.

    chaîne : refus de la porte (script/ai3/comportement.lua, M.gate) -> paralysie (shared/team/survie.lua) -> ENTRÉE à la pensée
    (script/team/survie.lua, Survie.think, appelée par Team.think) -> vue (view.survie) -> priorité / porte / tâches -> SORTIE
    quand la pénurie finit.

    1. porte, mode éteint : le comportement d'avant (2 morts -> attente) ;
    2. porte, mode allumé : tâche de ressources assouplie, tâche de défense non ; 3 morts, but à portée d'un ver : attente quand même ;
       escalade en 2 refus ;
    3. entrée : PNJ tous occupés (aucune paralysie) -> le mode ne s'allume PAS ; PNJ sans tâche -> il s'allume, une ligne [FO-SURVIE] ;
    4. pendant le mode : la production passe d'abord (view.survie -> priorité), les tâches de survie sont au tableau, le mode TIENT
       après un refus et après une pensée sans manque (hystérésis) ;
    5. sortie : la pénurie finit -> ligne « SORTIE » avec le bilan ; sauvegarde d'avant le lot (aucun état) : mode éteint, sans erreur ;
    6. global sérialisable, déterminisme (deux passages identiques).
  Lancement : lua5.2 tests/survie_moteur_test.lua (depuis la racine du mod).
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

local function enemy_search()
  local s = game.surfaces[1]
  s.find_nearest_enemy = function(t)
    local best, bd
    for _, e in ipairs(W().entities) do
      if e.valid and e.force and e.force.name == "enemy" then
        local dx, dy = e._x - t.position.x, e._y - t.position.y
        local d = dx * dx + dy * dy
        if d <= t.max_distance * t.max_distance and (not bd or d < bd) then best, bd = e, d end
      end
    end
    return best
  end
end

local function setup()
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0 })
  if W().remote["fo-ia3f"] then remote.call("fo-ia3f", "set_fog", false) end
  W().prototypes["small-worm-turret"] = { type = "turret", max_health = 200,
    collision_box = { left_top = { x = -0.9, y = -0.8 }, right_bottom = { x = 0.9, y = 0.8 } },
    attack_parameters = { range = 25 } }
  enemy_search()
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 30 }, { "coal", 200 }, { "stone-furnace", 8 }, { "pistol", 2 }, { "firearm-magazine", 40 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  M.run_ticks(600)
  return global.fo.pteam.team, chest
end

local function logs_with(tag)
  local out = {}
  for _, l in ipairs(W().logs) do if l:find(tag, 1, true) then out[#out + 1] = l end end
  return out
end

local function run_all()
  local trace = {}
  local f, chest = setup()
  local C = require("script.ai3.comportement")
  local Sv = require("shared.team.survie")
  local Survie = require("script.team.survie")
  local Registry = require("script.companion.registry")
  local ids = {}
  for id in pairs(f.engineers) do ids[#ids + 1] = id end
  table.sort(ids)
  local ag = Registry.get(ids[4])
  remote.call("fo-ia3k", "forget", "player")

  ---------------------------------------------------------------------------------------------------
  section("1. Porte, mode éteint : le comportement d'avant")
  ---------------------------------------------------------------------------------------------------
  check(C.enabled(), "comportements visibles allumés")
  check(not Survie.on(f), "mode éteint au départ (aucun état dans la sauvegarde neuve avant le premier refus)")
  local task_s = { key = "test:service", kind = "service" }
  local steps = { { "home" }, { "goto", { x = -5, y = 140 }, 3 }, { "act", "service" }, { "home" } }
  check(C.gate(f, ag, task_s, steps, game.tick) == true, "trajet sûr : la tâche part")
  -- Deux morts À CÔTÉ de la route (26 tuiles : dans le rayon « au même endroit » de 32, hors du disque de 24 qui bloquerait la
  -- route) : ce ni le but ni un chemin sans issue, seulement la règle « 2 morts de l'heure ».
  ag.entity.teleport({ x = 0, y = 10 }) -- le trajet jugé part du coffre
  remote.call("fo-ia3k", "death", "player", 26, 70)
  remote.call("fo-ia3k", "death", "player", 26, 76)
  check(C.gate(f, ag, task_s, steps, game.tick) == false, "2 morts de l'heure sur la route, mode éteint : attente")
  local n_waits0 = #Survie.state(f).waits
  check(n_waits0 >= 1, "le refus est noté pour la paralysie (" .. n_waits0 .. ")")

  ---------------------------------------------------------------------------------------------------
  section("2. Porte, mode allumé")
  ---------------------------------------------------------------------------------------------------
  local s = Survie.state(f)
  s.on, s.since, s.beat = true, game.tick, game.tick
  check(Survie.on(f), "mode allumé à la main (état de l'équipe)")
  check(C.gate(f, ag, { key = "test:service-sv", kind = "service" }, steps, game.tick) == true,
    "mode survie, tâche de ressources, 2 morts sur la route : la tâche part")
  check(s.relaxed >= 1 and (s.relax_why.morts or 0) >= 1, "la porte assouplie est comptée par motif (" .. tostring(s.relax_why.morts) .. " « morts »)")
  check(#logs_with("[FO-SURVIE]") >= 1 and logs_with("porte assouplie")[1] ~= nil, "journal : « porte assouplie » écrit")
  check(C.gate(f, ag, { key = "test:fortify-sv", kind = "fortify" }, steps, game.tick) == false,
    "mode survie, tâche de DÉFENSE (fortify), mêmes 2 morts sur la route : attente (porte ordinaire)")
  remote.call("fo-ia3k", "death", "player", 26, 73)
  check(C.gate(f, ag, { key = "test:service-sv3", kind = "service" }, steps, game.tick) == false,
    "mode survie, 3 morts de l'heure sur la route : attente quand même")
  remote.call("fo-ia3k", "forget", "player")
  -- But à portée d'un ver connu : jamais, mode survie ou non.
  remote.call("fo-ia3k", "mark", "player", 160, -140, "worm", 25)
  local steps_in = { { "home" }, { "goto", { x = 165, y = -150 }, 3 }, { "act", "service" }, { "home" } }
  local refused = 0
  for _ = 1, 8 do
    if not C.gate(f, ag, { key = "test:service-in", kind = "service" }, steps_in, game.tick) then refused = refused + 1 end
  end
  check(refused == 8, "mode survie : un but à portée d'un ver connu reste refusé (" .. refused .. " refus sur 8)")
  remote.call("fo-ia3k", "forget", "player")
  -- Escalade en 2 refus (4 en temps normal, test de D6 dans ia3k_moteur_test).
  local gx, gy = 120, -200
  local ring = { { 40, 0 }, { 28, 28 }, { 0, 40 }, { -28, 28 }, { -40, 0 }, { -28, -28 }, { 0, -40 }, { 28, -28 } }
  for _, o in ipairs(ring) do remote.call("fo-ia3k", "mark", "player", gx + o[1], gy + o[2], "worm", 25) end
  local steps2 = { { "home" }, { "goto", { x = gx, y = gy }, 3 }, { "act", "service" }, { "home" } }
  local refusals, went = 0, false
  for _ = 1, 8 do
    if C.gate(f, ag, { key = "test:service2", kind = "service" }, steps2, game.tick) then went = true break end
    refusals = refusals + 1
  end
  check(went and refusals == Sv.ESCALADE_W, "mode survie : escalade après " .. Sv.ESCALADE_W .. " refus (" .. refusals .. " observés ; 4 en temps normal)")
  remote.call("fo-ia3k", "forget", "player")

  ---------------------------------------------------------------------------------------------------
  section("3. Entrée : la paralysie est nécessaire")
  ---------------------------------------------------------------------------------------------------
  -- État neuf : l'équipe repart de zéro (mode éteint, aucun refus ancien).
  f.team.survie = nil
  local s2 = Survie.state(f)
  check(not s2.on and #s2.waits == 0, "état neuf : éteint, aucun refus")
  remote.call("fo-ia3k", "mark", "player", 160, -140, "worm", 25)
  local function burst(n)
    for _ = 1, n do C.gate(f, ag, { key = "test:service-in", kind = "service" }, steps_in, game.tick) end
  end
  -- Cinq minutes et plus de manque durable de fer ET de refus de la porte, mais les PNJ du moteur simulé travaillent : pas d'entrée.
  local busy_checks, idle_seen = 0, 0
  for _ = 1, 24 do
    M.run_ticks(900)
    burst(3)
    busy_checks = busy_checks + 1
  end
  check(s2.short_since ~= nil and game.tick - s2.short_since >= Sv.SHORT_TICKS, "le fer manque depuis plus de 5 min (" .. string.format("%.1f", (game.tick - (s2.short_since or game.tick)) / 3600) .. " min)")
  check(Sv.waits(s2, game.tick) >= Sv.PARA_WAITS, "la porte a refusé " .. Sv.waits(s2, game.tick) .. " tâches dans la fenêtre")
  check(not s2.on, "PNJ occupés (aucun sans tâche) : pas de paralysie, le mode ne s'allume PAS")
  -- Les PNJ restent sans tâche : seuil réglé à 0 % (le moteur simulé tient ses PNJ occupés ; la règle de seuil est testée dans survie_test.lua).
  local keep_pct = Sv.IDLE_PCT
  Sv.IDLE_PCT = 0
  M.run_ticks(900)
  check(s2.on, "paralysie (refus + seuil de PNJ sans tâche levé) et manque durable : le mode s'allume")
  Sv.IDLE_PCT = keep_pct
  local entree = logs_with("ENTREE en mode survie")
  check(#entree == 1 and entree[1]:find("iron-plate", 1, true) and entree[1]:find("paralysie par porte", 1, true),
    "journal : une ligne ENTREE avec la matière et la cause (" .. tostring(entree[1]) .. ")")

  ---------------------------------------------------------------------------------------------------
  section("4. Pendant le mode : la production d'abord, les tâches, l'hystérésis")
  ---------------------------------------------------------------------------------------------------
  M.run_ticks(600)
  local v_survie = nil
  local Team = require("script.team.team")
  local view = Team.view(f, game.tick)
  v_survie = view.survie
  check(v_survie == true, "Team.view publie view.survie pendant le mode")
  local pf = f.team.priorite_pf
  check(pf == true, "la pensée a décidé « production d'abord » (f.team.priorite_pf) pendant le mode")
  local survie_tasks = 0
  local Board = require("script.team.board")
  for _, t in ipairs(Board.get(f).list) do if t.survie then survie_tasks = survie_tasks + 1 end end
  check(survie_tasks >= 1 or s2.mines + s2.smelters + s2.extends >= 1,
    "tâches de survie au tableau ou déjà posées (" .. survie_tasks .. " au tableau, " .. s2.mines .. " minages, " .. s2.smelters .. " fours, " .. s2.extends .. " agrandissements)")
  for _, t in ipairs(Board.get(f).list) do
    if t.survie and t.kind == "mine" then
      check(t.danger_radius == Sv.MINE_DANGER_RADIUS and t.prudent == true and t.prio == Sv.PRIO, "minage de survie : rayon de danger, prudent, priorité " .. Sv.PRIO)
      break
    end
  end
  -- Hystérésis en moteur : un refus de plus, puis des pensées : le mode tient tant que le fer manque.
  burst(5)
  M.run_ticks(900)
  check(s2.on, "un refus de la porte de plus, le mode tient")
  -- La pénurie finit : fer et minerai au coffre en abondance.
  chest.insert({ name = "iron-plate", count = 4000 })
  chest.insert({ name = "stone", count = 2000 })
  chest.insert({ name = "copper-plate", count = 2000 })
  -- Le mode tient tant que moins de 5 min SANS manque se sont écoulées (le cerveau puise dans le fer ajouté : le manque peut revenir),
  -- puis s'éteint ; on lit les temps réels du moteur simulé plutôt qu'une durée fixe.
  local held_calm, exit_tick, calm_at_exit = false, nil, nil
  for _ = 1, 120 do
    M.run_ticks(600)
    if s2.on and s2.calm_since and game.tick - s2.calm_since >= 600 then held_calm = true end
    if not s2.on then exit_tick, calm_at_exit = game.tick, s2.calm_since break end
  end
  check(held_calm, "au moins une pensée SANS manque pendant que le mode tient encore (hystérésis observée)")
  check(exit_tick ~= nil and not s2.on, "la pénurie finie, le mode s'éteint (tick " .. tostring(exit_tick) .. ")")
  check(exit_tick ~= nil and calm_at_exit ~= nil and exit_tick - calm_at_exit >= Sv.EXIT_TICKS,
    "sortie seulement après 5 min SANS manque de suite (" .. tostring(exit_tick and calm_at_exit and string.format("%.1f", (exit_tick - calm_at_exit) / 3600)) .. " min)")
  local sortie = logs_with("SORTIE du mode survie")
  check(#sortie == 1 and sortie[1]:find("bilan du sejour", 1, true) ~= nil, "journal : une ligne SORTIE avec le bilan du séjour (" .. tostring(sortie[1]) .. ")")
  check(not Team.view(f, game.tick).survie, "view.survie retombe à faux")

  ---------------------------------------------------------------------------------------------------
  section("5. Sauvegarde d'avant le lot, état sérialisable, déterminisme")
  ---------------------------------------------------------------------------------------------------
  f.team.survie = nil
  check(not Survie.on(f) and not Team.view(f, game.tick).survie, "sauvegarde d'avant le lot (aucun état) : mode éteint, aucune erreur")
  M.run_ticks(1200)
  check(f.team.survie ~= nil and f.team.survie.on == false, "l'état est recréé en événement, éteint")
  check(pcall(M.serialize, global), "global sérialisable (aucune fonction)")
  trace.on, trace.entries, trace.tick = s2.entries, s2.entries, game.tick
  trace.log = table.concat(logs_with("[FO-SURVIE]"), "\n")
  return trace
end

local r1 = run_all()
print(string.format("[SURVIE-MOTEUR] premier passage : %d OK, %d ECHEC(S)", passes, failures))
local p1, f1 = passes, failures
passes, failures = 0, 0
local r2 = run_all()
section("6. Déterminisme : deux passages identiques")
check(r1.log == r2.log and r1.tick == r2.tick and r1.entries == r2.entries, "mêmes lignes [FO-SURVIE], même tick final, même nombre d'entrées")
print(string.format("[SURVIE-MOTEUR] BILAN : %d OK, %d ECHEC(S) (premier passage %d OK, %d ECHEC)", passes + p1, failures + f1, p1, f1))
os.exit((failures + f1) == 0 and 0 or 1)
