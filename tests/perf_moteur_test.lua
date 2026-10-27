--[[
  Lot PERF (27/10) : le MÉMO des itinéraires sans tirage (script/ai3/comportement.lua, M.plan) ne change AUCUNE décision.
  Moteur simulé (même mise en place que tests/ia3k_moteur_test.lua) : la même suite est jouée deux fois, mémo ALLUMÉ
  (M.MEMO_MAX = 16) puis ÉTEINT (M.MEMO_MAX = 0 : chaque entrée part aussitôt rangée), table du mémo vidée entre les deux :
    - porte d'une tâche rejugée 12 fois au même tick puis de minute en minute (attentes, escalade, morts, vers marqués,
      décroissances), réponses et raisons comparées ;
    - tournées vers un but derrière un ver (regards, détours, rejugements après une mort) ;
    - état de l'équipe (carte du danger, statistiques, attentes) et des PNJ (global.fo.ia3k) sérialisé et comparé.
  Contrôle aussi que le mémo SERT (au moins 10 itinéraires rendus par lui dans la passe allumée) et qu'il reste hors de
  global (rien de nouveau dans global.fo.ia3k).
  Lancement : lua5.2 tests/perf_moteur_test.lua (depuis la racine du mod ; environ 20 s).
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
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
  for _, it in ipairs({ { "iron-plate", 400 }, { "coal", 200 }, { "pistol", 2 }, { "firearm-magazine", 40 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  remote.call("fo-ia3k", "hold", "player", true)
  M.run_ticks(600)
  return global.fo.pteam.team
end

local function agent_ids(f)
  local out = {}
  for id in pairs(f.engineers) do out[#out + 1] = id end
  table.sort(out)
  return out
end

local function play_trip(id, x, y, max_ticks)
  local Registry = require("script.companion.registry")
  local FSM = require("script.core.fsm")
  local ag = Registry.get(id)
  if not ag then return {} end
  ag.task, ag.steps, ag.pc = nil, { { "goto", { x = x, y = y }, 2 }, { "home" } }, 1
  FSM.set("worker", ag, "step", game.tick)
  local pts = {}
  for _ = 1, math.floor(max_ticks / 60) do
    M.run_ticks(60)
    ag = Registry.get(id)
    if not ag or not ag.entity.valid then break end
    local p = ag.entity.position
    pts[#pts + 1] = { x = p.x, y = p.y }
    if ag.state == "idle" then break end
  end
  return pts
end

local changed = false
local function run_suite(memo_max)
  local f = setup()
  local C = require("script.ai3.comportement")
  local Registry = require("script.companion.registry")
  C.MEMO_MAX = memo_max
  local h0 = C.memo_stats.hit
  local ids = agent_ids(f)
  local out = {}
  local function gate(ag, key, steps)
    local ok, why = C.gate(f, ag, { key = key, kind = "service" }, steps, game.tick)
    out[#out + 1] = tostring(ok) .. ":" .. tostring(why)
  end
  remote.call("fo-ia3k", "hold", "player", false)
  local ag = Registry.get(ids[4])
  -- 1. porte rejugée au même tick (le cas du PNJ au repos refusé), puis de minute en minute
  local gx, gy = 120, -200
  local ring = { { 40, 0 }, { 28, 28 }, { 0, 40 }, { -28, 28 }, { -40, 0 }, { -28, -28 }, { 0, -40 }, { 28, -28 } }
  for _, o in ipairs(ring) do remote.call("fo-ia3k", "mark", "player", gx + o[1], gy + o[2], "worm", 25) end
  local steps = { { "home" }, { "goto", { x = gx, y = gy }, 3 }, { "act", "service" }, { "home" } }
  for _ = 1, 12 do gate(ag, "perf:a", steps) end
  for k = 1, 30 do
    M.run_ticks(1200 + 37 * k)
    gate(ag, "perf:a", steps)
    gate(Registry.get(ids[3]) or ag, "perf:b", { { "home" }, { "goto", { x = -5, y = 140 }, 3 }, { "home" } })
    if k == 5 then remote.call("fo-ia3k", "death", "player", -5, 130) end
    if k == 9 then remote.call("fo-ia3k", "death", "player", 0, 135) end
    if k == 14 then remote.call("fo-ia3k", "mark", "player", 60, -60, "spawner", 30) end
  end
  -- 2. tournées vers un but derrière un ver (regards, détours, rejugements)
  game.surfaces[1].create_entity({ name = "small-worm-turret", position = { x = 165, y = 5 }, force = "enemy" })
  for k = 1, 3 do
    local p = play_trip(ids[1], 325, 5, 9000)
    out[#out + 1] = string.format("%.3f,%.3f,%d", p[#p] and p[#p].x or 0, p[#p] and p[#p].y or 0, #p)
    if k == 2 then remote.call("fo-ia3k", "death", "player", 200, 20) end
  end
  for k = 1, 6 do gate(ag, "perf:c", { { "home" }, { "goto", { x = 300, y = 10 + k }, 3 }, { "home" } }) end
  -- 3. la carte change AU MÊME TICK (ver vu sur le trajet, puis oublié) : le mémo doit le voir (sinon il rendrait
  -- l'itinéraire d'avant) ; même chose pour une décroissance (une heure plus tard).
  remote.call("fo-ia3k", "forget", "player")
  local sd = { { "home" }, { "goto", { x = 0, y = -220 }, 3 }, { "home" } }
  local p0 = ag.entity.position
  local function plan_sig(tag)
    local r = C.plan(f, ag, p0, { x = 0, y = -220 }, game.tick)
    local parts = { tag, tostring(r.astar), tostring(r.blocked), r.exact_max, r.exact_goal, r.max_d }
    for _, q in ipairs(r.pts) do parts[#parts + 1] = string.format("%.4f/%.4f", q.x, q.y) end
    local fp = table.concat(parts, ",")
    out[#out + 1] = fp
    return fp:sub(#tag + 2)
  end
  local r1 = plan_sig("vide")
  gate(ag, "perf:d", sd)
  remote.call("fo-ia3k", "mark", "player", 4, -110, "worm", 25)
  local r2 = plan_sig("ver")
  gate(ag, "perf:d", sd)
  remote.call("fo-ia3k", "mark", "player", 52, -128, "spawner", 30) -- sur le détour du ver
  local r3 = plan_sig("nid")
  M.run_ticks(3600 * 30)
  local r4 = plan_sig("plus-tard")
  changed = r1 ~= r2 and r2 ~= r3 and r3 ~= r4
  local hits = C.memo_stats.hit - h0
  return table.concat(out, ";") .. "|" .. M.serialize(global.fo.ia3k), hits, global.fo.ia3k
end

section("Mémo des itinéraires : mêmes décisions, allumé ou éteint")
local r_on, hits_on, g_on = run_suite(16)
local changed_on = changed
local r_off, hits_off = run_suite(0)
check(changed_on, "la carte changée au même tick (ver, nid, oubli) change l'itinéraire rendu (mémo allumé)")
print(string.format("  itinéraires rendus par le mémo : %d (allumé), %d (éteint)", hits_on, hits_off))
check(hits_on >= 10, "le mémo sert dans la passe allumée (" .. hits_on .. " itinéraires rendus)")
check(hits_off == 0, "aucun itinéraire rendu par le mémo quand il est éteint (" .. hits_off .. ")")
check(r_on == r_off, "mêmes portes, mêmes tournées, même global.fo.ia3k (" .. #r_on .. " caractères)")
if r_on ~= r_off then
  for i = 1, math.min(#r_on, #r_off) do
    if r_on:sub(i, i) ~= r_off:sub(i, i) then print("  première différence au caractère " .. i .. " : " .. r_on:sub(math.max(1, i - 80), i + 80)) break end
  end
end
local has_memo = false
for k in pairs(g_on.teams) do if g_on.teams[k].memo then has_memo = true end end
check(not has_memo and g_on.memo == nil, "mémo hors de global")
check(pcall(M.serialize, global), "global sérialisable (aucune fonction)")
-- Mémo allumé à nouveau, table vidée (comme après un chargement) : même résultat que la première passe.
local r_on2 = run_suite(16)
check(r_on2 == r_on, "deuxième passe allumée (mémo déjà garni par les passes précédentes) : identique")

print(string.format("[PERF-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
