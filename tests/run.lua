--[[
  Banc de tests hors-jeu (Lua 5.2, la version de Factorio 1.1).
  Usage, depuis la racine du mod :   lua5.2 tests/run.lua

  Moteur simulé : tests/mock_engine.lua (partagé avec tests/war_test.lua).

  Ce banc ne remplace PAS le test en jeu : il valide la logique, l'absence d'erreurs Lua, la
  sérialisabilité de `global`, le déterminisme et la tenue des invariants de l'ordonnanceur.
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

---------------------------------------------------------------------------------------------------
-- Moteur simulé (tests/mock_engine.lua)
---------------------------------------------------------------------------------------------------
local M = require("tests.mock_engine")
local W = setmetatable({}, {
  __index = function(_, k) return M.world()[k] end,
  __newindex = function(_, k, v) M.world()[k] = v end,
})
local new_world, load_mod, run_ticks = M.new_world, M.load_mod, M.run_ticks
local serialize, deepcopy_global, new_game = M.serialize, M.deepcopy_global, M.new_game
local function command(text) M.command("fo-bench", text) end

local function last_report()
  local out = {}
  for i = #W.prints, 1, -1 do
    table.insert(out, 1, W.prints[i])
    if W.prints[i]:match("^%[FO%-BENCH%] tick=") then break end
  end
  return table.concat(out, "\n")
end

---------------------------------------------------------------------------------------------------
-- 1. Unités pures
---------------------------------------------------------------------------------------------------
section("Geometry.direction8")
new_game()
local Geometry = require("script.core.geometry")
local D = defines.direction
local cases = {
  { 0, -1, D.north }, { 1, -1, D.northeast }, { 1, 0, D.east }, { 1, 1, D.southeast },
  { 0, 1, D.south }, { -1, 1, D.southwest }, { -1, 0, D.west }, { -1, -1, D.northwest },
  { 0.3, -1, D.north }, { 0.5, -1, D.northeast }, { 1, 0.4, D.east }, { 1, 0.45, D.southeast },
}
for _, c in ipairs(cases) do
  check(Geometry.direction8(c[1], c[2]) == c[3], string.format("direction8(%s,%s)", c[1], c[2]))
end

section("RNG")
local RNG = require("script.core.rng")
local seq1 = {}
for i = 1, 5 do seq1[i] = RNG.next() end
global.fo.rng.state = 20261020
local same = true
for i = 1, 5 do if RNG.next() ~= seq1[i] then same = false end end
check(same, "RNG reproductible à état égal")
local okr, okf = true, true
for _ = 1, 20000 do
  local r = RNG.range(3, 9); if r < 3 or r > 9 or r % 1 ~= 0 then okr = false end
  local f = RNG.float(); if f < 0 or f >= 1 then okf = false end
end
check(okr, "RNG.range dans [3,9] entier")
check(okf, "RNG.float dans [0,1)")

---------------------------------------------------------------------------------------------------
-- 2. Invariants de l'ordonnanceur
---------------------------------------------------------------------------------------------------
section("Scheduler : invariants sous ajouts/retraits pendant l'itération")
local Scheduler
for _, PERIOD in ipairs({ 1, 3, 7, 60 }) do
  for seed = 1, 5 do
    new_world({ seed = seed })
    load_mod()
    W.on_init()
    Scheduler = require("script.core.scheduler")
    local lane = "t"
    local last_visit, joined = {}, {}
    local visits_this_tick = {}
    local max_gap, double_visit, inexact = 0, false, 0
    local live = {} -- ensemble des ids vivants côté test (liste + index)
    local live_list = {}
    local next_id = 0
    local function track_add(id)
      if live[id] then return end
      live_list[#live_list + 1] = id
      live[id] = #live_list
      joined[id] = game.tick
      last_visit[id] = nil
    end
    local function track_remove(id)
      local pos = live[id]
      if not pos then return end
      local last = live_list[#live_list]
      live_list[pos] = last
      live[last] = pos
      live_list[#live_list] = nil
      live[id] = nil
      joined[id] = nil
      last_visit[id] = nil
    end
    local function add_one()
      next_id = next_id + 1
      Scheduler.add(lane, next_id)
      track_add(next_id)
    end
    Scheduler.define_lane(lane, PERIOD, function(id, tick)
      if visits_this_tick[id] == tick then double_visit = true end
      visits_this_tick[id] = tick
      if last_visit[id] and tick - last_visit[id] ~= PERIOD then inexact = inexact + 1 end
      last_visit[id] = tick
      local r = math.random()
      if r < 0.03 then
        Scheduler.remove(lane, id); track_remove(id)
      elseif r < 0.05 then
        local other = live_list[math.random(#live_list)]
        if other then Scheduler.remove(lane, other); track_remove(other) end
      elseif r < 0.065 then
        add_one()
      elseif r < 0.08 then
        -- retrait puis ré-ajout du même id dans le même tick (cas limite)
        Scheduler.remove(lane, id); track_remove(id)
        Scheduler.add(lane, id); track_add(id)
      end
    end)
    for _ = 1, 40 do add_one() end
    local count_ok = true
    for _ = 1, 3000 do
      run_ticks(1)
      local tick = game.tick
      local st = global.fo.sched.lanes[lane]
      local cnt = 0
      for _ in pairs(st.slot_of) do cnt = cnt + 1 end
      if cnt ~= st.count or cnt ~= #live_list then count_ok = false end
      for id, t0 in pairs(joined) do
        local gap = tick - (last_visit[id] or t0)
        if gap > max_gap then max_gap = gap end
      end
      if st.count < 5 then for _ = 1, 10 do add_one() end end
    end
    local tag = string.format(" [P=%d, graine %d]", PERIOD, seed)
    check(count_ok, "compteur cohérent avec les ids vivants à chaque tick" .. tag)
    check(not double_visit, "aucun id traité deux fois dans le même tick" .. tag)
    check(max_gap <= PERIOD, "attente max <= P (obtenu " .. max_gap .. ")" .. tag)
    check(inexact == 0, "période exacte entre deux passages (écarts inexacts : " .. inexact .. ")" .. tag)
  end
end

---------------------------------------------------------------------------------------------------
-- 3. Intégration compagnon : H1 vraie (walking_state persistant)
---------------------------------------------------------------------------------------------------
section("Intégration : 60 compagnons, H1 vraie, mode lazy")
new_game({ h1 = true })
command("spawn 60 30")
run_ticks(3600)
command("report")
local rep = last_report()
local Locomotion = require("script.companion.locomotion")
local Registry = require("script.companion.registry")
check(Registry.count() == 60, "60 agents vivants")
check(Locomotion.stats().arrivals > 100, "arrivées > 100 (obtenu " .. Locomotion.stats().arrivals .. ")")
check(rep:find("H1 CONFIRMEE", 1, true) ~= nil, "verdict H1 confirmée")
check(global.fo.path.stats.timeout > 0, "les requêtes perdues finissent en timeout")
check(global.fo.path.stats.retry > 0, "les réponses 'busy' sont relancées")
check(W.lines_drawn > 0, "chemins dessinés (rendu debug)")
check(W.files["fo-bench/report.txt"] ~= nil, "rapport écrit dans script-output")
local writes_lazy = Locomotion.stats().writes
print(rep)

section("Sérialisabilité de global")
local ok_ser, err_ser = pcall(serialize, global)
check(ok_ser, "global ne contient ni fonction ni userdata (" .. tostring(err_ser) .. ")")

---------------------------------------------------------------------------------------------------
-- 4. H1 fausse : le banc doit le détecter, puis le mode every k=1 doit compenser
---------------------------------------------------------------------------------------------------
section("Intégration : H1 fausse, détection puis compensation")
new_game({ h1 = false })
command("spawn 40 30")
run_ticks(3600)
command("report")
rep = last_report()
check(rep:find("H1 REJETEE", 1, true) ~= nil, "verdict H1 rejetée détecté")
print(rep)
W.settings["fo-companion-steer-period"] = 1
W.events[defines.events.on_runtime_mod_setting_changed]({ tick = game.tick, setting = "fo-companion-steer-period", setting_type = "runtime-global" })
command("mode every")
run_ticks(3600)
command("report")
rep = last_report()
local eff = tonumber(rep:match("Efficacite de deplacement: ([%d%.]+)"))
check(eff and eff >= 0.6, "mode every k=1 : efficacité >= 0.6 (obtenu " .. tostring(eff) .. ")")
print(rep)

---------------------------------------------------------------------------------------------------
-- 5. Déterminisme : deux parties identiques produisent le même global
---------------------------------------------------------------------------------------------------
section("Déterminisme")
local function scenario()
  new_game({ h1 = true, seed = 7 })
  command("spawn 30 25")
  run_ticks(1500)
  return serialize(global)
end
local s1, s2 = scenario(), scenario()
check(s1 == s2, "même état global après 1500 ticks sur deux exécutions")

---------------------------------------------------------------------------------------------------
-- 6. Sauvegarde / rechargement en cours de route
---------------------------------------------------------------------------------------------------
section("Sauvegarde / rechargement")
new_game({ h1 = true, seed = 11 })
command("spawn 30 25")
run_ticks(1800)
local arrivals_before = Locomotion.stats().arrivals
local saved = deepcopy_global(global)
-- rechargement : nouvel état Lua (tables locales perdues), global restauré, on_load
load_mod()
_G.global = saved
local ok_load, err_load = pcall(function() W.on_load() end)
check(ok_load, "on_load sans erreur (" .. tostring(err_load) .. ")")
local ok_run, err_run = pcall(run_ticks, 1800)
check(ok_run, "simulation continue après rechargement (" .. tostring(err_run) .. ")")
Locomotion = require("script.companion.locomotion")
check(Locomotion.stats().arrivals > arrivals_before, "les agents continuent d'arriver après rechargement")

---------------------------------------------------------------------------------------------------
-- 7. Suivi du joueur
---------------------------------------------------------------------------------------------------
section("Comportement follow")
new_game({ h1 = true, seed = 3, p_busy = 0, p_nopath = 0, p_lost = 0 })
command("follow 5")
local pc = W.player.character
for _ = 1, 20 do
  pc._x = pc._x + 2 -- le joueur marche vers l'est
  run_ticks(30)
end
run_ticks(600)
Registry = require("script.companion.registry")
local far = 0
for _, id in ipairs(Registry.ids()) do
  local p = Registry.get(id).entity.position
  local dx, dy = p.x - pc._x, p.y - pc._y
  if dx * dx + dy * dy > 10 * 10 then far = far + 1 end
end
check(far == 0, "les 5 suiveurs sont à moins de 10 tuiles du joueur (éloignés : " .. far .. ")")

---------------------------------------------------------------------------------------------------
-- 8. Nettoyage
---------------------------------------------------------------------------------------------------
section("Clear")
new_game({ h1 = true })
command("spawn 20 20")
run_ticks(300)
command("clear")
run_ticks(2)
Registry = require("script.companion.registry")
Scheduler = require("script.core.scheduler")
local labels = 0
for _ in pairs(W.renders) do labels = labels + 1 end
check(Registry.count() == 0, "plus aucun agent")
check(Scheduler.count("fo-brain") == 0 and Scheduler.count("fo-loco") == 0, "voies vides")
check(labels == 0, "étiquettes de rendu détruites")
run_ticks(2000) -- les résultats de chemin en retard doivent être ignorés sans erreur
check(true, "résultats périmés ignorés sans erreur")

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
