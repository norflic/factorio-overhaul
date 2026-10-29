--[[
  Lot CRAFT-PARALLELE (retour du DC du 29/10, 0.6.18 : « ils peuvent fabriquer et faire autre chose en même temps […] vérifiez ça ») :
  la file de fabrication d'un PNJ avance pendant qu'il fait autre chose (script/team/worker.lua, agent.bg ; règles pures
  shared/team/craft_bg.lua ; porte de la place de marché script/team/board.lua).
  Usage : lua5.2 tests/craft_bg_test.lua   (depuis la racine du mod ; environ 30 s)
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

---------------------------------------------------------------------------------------------------
section("1. Règles pures (shared/team/craft_bg.lua)")
---------------------------------------------------------------------------------------------------
local CB = require("shared.team.craft_bg")
local ING = {
  ["gear"] = { { "plate", 2 } },
  ["turret"] = { { "gear", 10 }, { "plate", 20 }, { "copper", 10 } },
  ["fluide"] = {},
}
local ing = function(r) return ING[r] end
local list = { { recipe = "gear", runs = 10, energy = 5 }, { recipe = "turret", runs = 1, energy = 8 } }
local k1 = CB.keep(list, 1, ing)
check(k1.plate == 40 and k1.gear == 10 and k1.copper == 10, "réserve avant tout lancement : 40 plaques, 10 engrenages, 10 cuivre")
local k2 = CB.keep(list, 2, ing)
check(k2.plate == 20 and k2.gear == 10 and k2.copper == 10, "réserve après l'étape 1 lancée : ingrédients de la tourelle seuls")
local k3 = CB.keep(list, 3, ing)
check(next(k3) == nil, "tout lancé : rien en réserve")
local kj = CB.keep_jobs({ { list = list, i = 2 }, { list = { { recipe = "gear", runs = 3 } }, i = 1 } }, ing)
check(kj.plate == 26 and kj.gear == 10, "réserve de deux travaux additionnée (20 + 6 plaques)")
check(CB.left_s(list, 1) == 13 and CB.left_s(list, 2) == 13 and CB.left_s(list, 3) == 8, "file restante : étape en cours comptée entière")
check(CB.left_s({ { recipe = "x", runs = 4 } }, 1) == 2, "étape sans energy : 0,5 s par fabrication")
check(CB.left_jobs({ { list = list, i = 3, ready = true }, { list = list, i = 2 } }) == 13, "travail fini ignoré dans la file restante")
check(CB.fits("mine", 60, 0, 100, 13) == false, "minage de 60 s pendant 13 s de file : refusé")
check(CB.fits("mine", 30, 0, 100, 13) == true, "30 s pendant 13 s + 20 s de marge : accepté")
check(CB.fits("mine", 600, 100, 100, 0) == true, "urgence : toujours acceptée")
check(CB.fits("craft", 600, 0, 100, 0) == true, "fabrication (au QG) : pas de borne de durée")
check(CB.allowed("garrison") == false and CB.allowed("build") == false and CB.allowed("mine") == true, "garde et avant-poste exclus")
check(CB.allowed("craft", false) == true and CB.allowed("craft", true) == false, "fabrication de plus : jusqu'à MAX_JOBS")
local shared_cannot = { garrison = true, design = true }
local c = CB.cannot_with(shared_cannot, true)
check(c.build and c.garrison and c.design and c.craft, "genres interdits augmentés (plein : craft)")
check(shared_cannot.build == nil and shared_cannot.craft == nil, "table d'entrée jamais modifiée (constante partagée de board.lua)")
check(CB.cannot_with(nil, false).craft == nil, "pas plein : fabrication permise")
local team = {}
local w = CB.window(team)
check(team.craft_bg == w and CB.window(team) == w, "fenêtre créée une fois sous l'équipe")
check(CB.due(w, 100) == false and CB.due(w, 100 + CB.REPORT_EVERY - 1) == false and CB.due(w, 100 + CB.REPORT_EVERY) == true,
  "bilan dû toutes les 5 min (premier appel : armement)")
w.started, w.done, w.failed, w.causes = 3, 2, 1, { mort = 1 }
w.bg_ticks, w.work_ticks, w.delay_ticks = 600, 450, 240
local line = CB.report_line("player", 18000, w, 2, 1)
check(line:find("[FO-CRAFT] player", 1, true) and line:find("2 PNJ fabriquent", 1, true) and line:find("dont 1 au travail", 1, true)
  and line:find("{mort:1}", 1, true) and line:find("(75 %)", 1, true) and line:find("2.0 s apres", 1, true), "ligne du bilan : " .. line)
CB.reset(w, 18000)
check(w.started == 0 and w.t == 18000 and next(w.causes) == nil, "fenêtre remise à zéro")

---------------------------------------------------------------------------------------------------
-- Partie au moteur simulé (scénario de pteam_test : équipe du joueur, coffre garni)
---------------------------------------------------------------------------------------------------
local M = require("tests.mock_engine")
local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end
local Registry, State, Board, Worker -- chargés après la première partie (le moteur simulé pose `defines`)
local function new_team(seed)
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0, seed = seed })
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
    { "pistol", 2 }, { "firearm-magazine", 40 }, { "burner-mining-drill", 6 }, { "stone-furnace", 6 }, { "iron-chest", 4 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  M.world().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  -- Le moteur simulé recharge le mod à chaque partie : modules repris ici (un réglage posé avant serait perdu).
  Registry = require("script.companion.registry")
  State = require("script.faction.state")
  Board = require("script.team.board")
  Worker = require("script.team.worker")
  return global.fo.pteam.team
end

--- Échantillonne chaque seconde : PNJ immobiles en « craft », PNJ qui fabriquent ET travaillent, invariants.
local function sample(f, seconds, inv)
  local r = { n = 0, craft = 0, bg = 0, both = 0, max_jobs = 0, bad_board = 0, bad_hold = 0 }
  for _ = 1, seconds do
    M.run_ticks(60)
    f = global.fo.pteam.team
    local b = Board.get(f)
    for _, id in ipairs(State.sorted_keys(f.engineers)) do
      local a = Registry.get(id)
      if a then
        r.n = r.n + 1
        if a.state == "craft" then r.craft = r.craft + 1 end
        if a.bg then
          r.bg = r.bg + 1
          if a.task then r.both = r.both + 1 end
          if #a.bg.jobs > r.max_jobs then r.max_jobs = #a.bg.jobs end
          for _, j in ipairs(a.bg.jobs) do
            -- La tâche « craft » reste PRISE au tableau, à son nom, jusqu'à la livraison (Board.incoming la compte).
            if not (b.tasks[j.task.key] == j.task and j.task.worker == a.id) then r.bad_board = r.bad_board + 1 end
          end
          for _, item in ipairs(State.sorted_keys(a.bg.hold)) do if a.bg.hold[item] <= 0 then r.bad_hold = r.bad_hold + 1 end end
        end
      end
    end
    if inv then inv(f) end
  end
  return r
end

---------------------------------------------------------------------------------------------------
section("2. Vingt minutes au moteur simulé : fabriquer ET travailler")
---------------------------------------------------------------------------------------------------
local f = new_team(42)
check(Worker.CRAFT_BG == true, "fabrication en arrière-plan allumée par défaut")
local inc_ok = true
local r = sample(f, 20 * 60, function(ff)
  -- Board.incoming compte les travaux en arrière-plan (le cerveau ne refait pas ce qui se fabrique)
  local inc = Board.incoming(ff)
  for _, id in ipairs(State.sorted_keys(ff.engineers)) do
    local a = Registry.get(id)
    if a and a.bg then
      for _, j in ipairs(a.bg.jobs) do if (inc[j.task.item] or 0) < (j.task.count or 0) then inc_ok = false end end
    end
  end
end)
f = global.fo.pteam.team
print(string.format("  %d échantillons PNJ x s : immobiles %d, en arrière-plan %d dont %d avec une tâche ; travaux par PNJ au plus %d",
  r.n, r.craft, r.bg, r.both, r.max_jobs))
check(r.craft == 0, "aucun PNJ immobile dans l'état « craft » (" .. r.craft .. ")")
check(r.both >= r.n / 10, "des PNJ fabriquent ET travaillent (" .. r.both .. " échantillons sur " .. r.n .. ")")
check(r.max_jobs >= 1 and r.max_jobs <= CB.MAX_JOBS, "au plus " .. CB.MAX_JOBS .. " travaux par PNJ (" .. r.max_jobs .. ")")
check(r.bad_board == 0, "tâche « craft » prise au tableau à son nom jusqu'à la livraison (" .. r.bad_board .. " écarts)")
check(r.bad_hold == 0, "réserve sans quantité nulle ou négative")
check(inc_ok, "Board.incoming compte les travaux en arrière-plan")
local ts = f.team.task_stats.craft or { ok = 0, fail = 0 }
check(ts.ok >= 100, "fabrications livrées (" .. ts.ok .. ")")
check(ts.fail <= 2, "fabrications perdues : au plus 2 (" .. ts.fail .. " ; 8 sur l'ancien PNJ bloqué, même partie)")
check((f.stats.crafted or 0) == ts.ok, "stats.crafted = fabrications livrées")
local nlog, nrep = 0, 0
for _, l in ipairs(M.world().logs) do
  if l:find("[FO-CRAFT]", 1, true) then
    nlog = nlog + 1
    if l:find("PNJ fabriquent en arriere-plan", 1, true) then nrep = nrep + 1 end
  end
end
check(nrep >= 3, "bilan [FO-CRAFT] toutes les 5 min (" .. nrep .. " lignes)")
check(pcall(M.serialize, global), "global sérialisable (travaux, réserve)")

---------------------------------------------------------------------------------------------------
section("3. Mutant : l'ancien PNJ bloqué (Worker.CRAFT_BG = false)")
---------------------------------------------------------------------------------------------------
f = new_team(42)
Worker.CRAFT_BG = false
local r0 = sample(f, 20 * 60)
f = global.fo.pteam.team
local ts0 = f.team.task_stats.craft or { ok = 0, fail = 0 }
print(string.format("  immobiles %d sur %d (%.1f %%), fabrications %d livrées, %d perdues", r0.craft, r0.n, 100 * r0.craft / r0.n, ts0.ok, ts0.fail))
check(r0.craft >= r0.n / 5, "mutant détecté : plus de 20 % du temps immobile en « craft » (" .. r0.craft .. ")")
check(r0.bg == 0, "mutant : aucun travail en arrière-plan")

---------------------------------------------------------------------------------------------------
section("3b. Mutant : sans réserve (ingrédients des étapes suivantes laissés en poche)")
---------------------------------------------------------------------------------------------------
f = new_team(42)
local keep_jobs = CB.keep_jobs
require("shared.team.craft_bg").keep_jobs = function() return {} end -- module rechargé par la partie : on mute celui du mod
sample(f, 10 * 60)
f = global.fo.pteam.team
local tsm = f.team.task_stats.craft or { ok = 0, fail = 0 }
print(string.format("  sans réserve : %d livrées, %d perdues", tsm.ok, tsm.fail))
check(tsm.fail >= 20, "mutant détecté : le passage au QG de la tâche suivante dépose les ingrédients, l'étape suivante échoue ("
  .. tsm.fail .. " perdues)")
require("shared.team.craft_bg").keep_jobs = keep_jobs

---------------------------------------------------------------------------------------------------
section("4. Sauvegarde 0.6.18 : PNJ arrêté en pleine fabrication (état « craft »)")
---------------------------------------------------------------------------------------------------
f = new_team(7)
Worker.CRAFT_BG = false
local stuck
for _ = 1, 600 do
  M.run_ticks(30)
  f = global.fo.pteam.team
  for _, id in ipairs(State.sorted_keys(f.engineers)) do
    local a = Registry.get(id)
    if a and a.state == "craft" and a.entity.crafting_queue_size > 0 then stuck = a break end
  end
  if stuck then break end
end
check(stuck ~= nil, "un PNJ en pleine fabrication à l'ancienne")
Worker.CRAFT_BG = true
if stuck then
  local key = stuck.task.key
  M.run_ticks(120)
  check(stuck.state ~= "craft", "repris en arrière-plan à sa pensée (état " .. tostring(stuck.state) .. ")")
  check(stuck.bg ~= nil and stuck.bg.jobs[1].task.key == key, "même tâche, devenue travail en arrière-plan")
  local delivered = false
  for _ = 1, 300 do
    M.run_ticks(60)
    if not (stuck.bg and stuck.bg.jobs[1] and stuck.bg.jobs[1].task.key == key) then delivered = true break end
  end
  check(delivered and not Board.get(global.fo.pteam.team).tasks[key], "fabrication reprise livrée et tâche close")
end

---------------------------------------------------------------------------------------------------
section("5. PNJ tué pendant une fabrication en arrière-plan")
---------------------------------------------------------------------------------------------------
f = new_team(42)
local victim
for _ = 1, 1200 do
  M.run_ticks(30)
  f = global.fo.pteam.team
  for _, id in ipairs(State.sorted_keys(f.engineers)) do
    local a = Registry.get(id)
    if a and a.bg and not a.bg.jobs[1].ready and a.entity.valid then victim = a break end
  end
  if victim then break end
end
check(victim ~= nil, "un PNJ qui fabrique en arrière-plan")
if victim then
  local keys = {}
  for _, j in ipairs(victim.bg.jobs) do keys[#keys + 1] = j.task.key end
  local fails0 = (f.team.task_stats.craft and f.team.task_stats.craft.fail) or 0
  local ok_die = pcall(function() victim.entity.die() M.run_ticks(2) end)
  check(ok_die, "mort sans erreur")
  f = global.fo.pteam.team
  local still = false
  for _, k in ipairs(keys) do if Board.get(f).tasks[k] then still = true end end
  check(not still, "ses tâches « craft » quittent le tableau (replanifiables)")
  check(((f.team.task_stats.craft and f.team.task_stats.craft.fail) or 0) == fails0 + #keys, "comptées en échec")
  local seen = false
  for _, l in ipairs(M.world().logs) do if l:find("perdue : mort", 1, true) then seen = true end end
  check(seen, "journal [FO-CRAFT] « perdue : mort »")
end

print(string.format("[CRAFT-BG] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
