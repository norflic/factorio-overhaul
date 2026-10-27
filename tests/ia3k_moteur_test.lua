--[[
  Lot IA3-k : banc HORS JEU du branchement (script/ai3/comportement.lua sur script/team/worker.lua), moteur simulé.
  Votre équipe (coffre posé), cerveau retenu par l'interface « fo-ia3k » (hold), tournées injectées :
    - variation (C1) : tournées vers le même but par des points de passage différents ;
    - ver posé sur la route (C2) : vu, marqué, détour ; le PNJ ne passe jamais à sa portée ;
    - peur (C3) : PNJ blessé près d'une unité ennemie : fuite (refuge, tâche rendue) ; prudent avant audacieux ;
    - morts (C5) : porte d'une tâche vers un lieu de 1 puis 2 morts : attente ;
    - étiquettes (D1) ; réglage éteint : aucun effet ; déterminisme (deux passages identiques) ; global sérialisable.
  Le moteur simulé n'a pas de recherche d'ennemis : find_nearest_enemy est remplacé ici par une recherche réelle sur
  ses entités (force « enemy »).
  Lancement : lua5.2 tests/ia3k_moteur_test.lua (depuis la racine du mod).
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
    assert(t.position and t.max_distance and t.force, "find_nearest_enemy : arguments")
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

local function setup(opts)
  opts = opts or {}
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, ia3k = opts.ia3k })
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
  check(remote.call("fo-ia3k", "hold", "player", true) == true, "cerveau retenu (hold)")
  M.run_ticks(600) -- les PNJ rentrent au coffre, sans tâche
  return global.fo.pteam.team
end

local function agent_ids(f)
  local ids = {}
  for id in pairs(f.engineers) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end

local function pos_of(id)
  local a = require("script.companion.registry").get(id)
  return a and a.entity.valid and a.entity.position or nil
end

--- Joue une tournée de l'agent `id` vers (x, y) ; renvoie la liste des positions (toutes les 10 ticks) et la fin.
local function play_trip(id, x, y, max_ticks)
  local n = remote.call("fo-ia3k", "trip", "player", id, x, y, 30)
  local pts = {}
  local Registry = require("script.companion.registry")
  local t = 0
  while t < (max_ticks or 6000) do
    M.run_ticks(10)
    t = t + 10
    local a = Registry.get(id)
    if not a then break end
    local p = a.entity.position
    pts[#pts + 1] = { x = p.x, y = p.y }
    if not a.task and t > 120 then break end
  end
  -- Positions de l'ALLER seul (jusqu'à 5 tuiles du but).
  local out = {}
  for _, p in ipairs(pts) do
    out[#out + 1] = p
    local dx, dy = p.x - x, p.y - y
    if dx * dx + dy * dy <= 25 then break end
  end
  return pts, n, out
end

local function min_d(pts, x, y)
  local m = 1e9
  for _, p in ipairs(pts) do
    local dx, dy = p.x - x, p.y - y
    local d = math.sqrt(dx * dx + dy * dy)
    if d < m then m = d end
  end
  return m
end

---------------------------------------------------------------------------------------------------
section("Variation des tournées (C1)")
local f = setup()
local ids = agent_ids(f)
check(#ids >= 2, "au moins 2 PNJ (" .. #ids .. ")")
local R = require("shared.ai3.route")
local S0, G0 = { x = 5, y = 5 }, { x = 125, y = 5 }
local trips = {}
for k = 1, 8 do
  local _, _, out = play_trip(ids[1], G0.x, G0.y, 4000)
  trips[k] = out
end
local wide, meds = 0, {}
for k = 1, 7 do
  local med = R.median_gap(S0, G0, trips[k], trips[k + 1], 8)
  meds[#meds + 1] = string.format("%.1f", med)
  if med >= 4 then wide = wide + 1 end
end
local st = remote.call("fo-ia3k", "status", "player")
check(st.stats.via >= 8, "points de passage de variation tirés (" .. tostring(st.stats.via) .. ")")
check(wide >= 4, "écart médian ≥ 4 tuiles entre allers successifs : " .. wide .. " sur 7 (" .. table.concat(meds, " ") .. ")")
local reached, long_ok = 0, true
for k = 1, 8 do
  if min_d(trips[k], G0.x, G0.y) <= 5 then reached = reached + 1 end
  local L = 0
  for i = 2, #trips[k] do L = L + R.dist(trips[k][i - 1].x, trips[k][i - 1].y, trips[k][i].x, trips[k][i].y) end
  if L > 1.15 * 120 + 10 then long_ok = false end
end
check(reached == 8, "les 8 allers arrivent au but (" .. reached .. ")")
check(long_ok, "aucun aller allongé de plus de 15 % (+ 10 tuiles d'arrivée)")

---------------------------------------------------------------------------------------------------
section("Ver sur la route : vu, marqué, détour (C2)")
local s = game.surfaces[1]
-- Le ver est posé SUR l'itinéraire tiré (entre les deux points de passage de la variation), une fois la tournée partie.
local WX, WY = 165, 5
local function trip_with_worm(id, gx, gy)
  local Reg = require("script.companion.registry")
  remote.call("fo-ia3k", "trip", "player", id, gx, gy, 30)
  M.run_ticks(5)
  local a = global.fo.ia3k.agents[id]
  if a and a.pts and #a.pts == 2 then
    WX, WY = (a.pts[1].x + a.pts[2].x) / 2, (a.pts[1].y + a.pts[2].y) / 2
  end
  local w = s.create_entity({ name = "small-worm-turret", position = { x = WX, y = WY }, force = "enemy" })
  local pts = {}
  for _ = 1, 900 do
    M.run_ticks(10)
    local ag = Reg.get(id)
    if not ag then break end
    local p = ag.entity.position
    pts[#pts + 1] = { x = p.x, y = p.y }
    if not ag.task then break end
  end
  return pts, w
end
local pts, worm = trip_with_worm(ids[2], 325, 5)
check(worm ~= nil and worm.type == "turret", string.format("ver posé sur l'itinéraire tiré, en (%.0f, %.0f)", WX, WY))
st = remote.call("fo-ia3k", "status", "player")
check((st.stats.seen.worm or 0) >= 1, "ver vu (" .. tostring(st.stats.seen.worm) .. " regard(s))")
check((st.stats.actions.detour or 0) >= 1, "détour décidé (" .. tostring(st.stats.actions.detour) .. ")")
check(st.summary.worms == 1, "ver retenu sur la carte de l'équipe")
local md = min_d(pts, WX, WY)
check(md > 25, "le PNJ n'entre jamais à portée du ver (25 tuiles) : au plus près " .. string.format("%.1f", md))
check(min_d(pts, 325, 5) <= 5, "il arrive quand même au but par le détour")
local labels = 0
for _, r in pairs(W().renders) do
  if type(r.text) == "table" and r.text[1] == "fo-ia3k.etat-detour" then labels = labels + 1 end
end
check(labels >= 1, "état « Détour » affiché au-dessus du PNJ (D1)")
-- Deuxième tournée : le ver est connu, l'itinéraire l'évite d'emblée (A*), sans nouvel arrêt.
local d0 = st.stats.actions.detour or 0
local pts2 = play_trip(ids[2], 325, 5, 9000)
st = remote.call("fo-ia3k", "status", "player")
check(st.stats.astar >= 1, "itinéraire calculé autour du ver connu (A* " .. tostring(st.stats.astar) .. ")")
check(min_d(pts2, WX, WY) > 25, "deuxième tournée : jamais à portée (" .. string.format("%.1f", min_d(pts2, WX, WY)) .. ")")
check((st.stats.actions.detour or 0) == d0, "deuxième tournée sans nouvel arrêt (route déjà sûre)")

---------------------------------------------------------------------------------------------------
section("Peur (C3)")
local Registry = require("script.companion.registry")
local victim = Registry.get(ids[3])
remote.call("fo-ia3k", "trip", "player", ids[3], -150, 5, 600)
M.run_ticks(200)
local vp = victim.entity.position
local biter = s.create_entity({ name = "small-biter", position = { x = vp.x - 12, y = vp.y }, force = "enemy" })
victim.entity.health = 80 -- 32 % de vie
local t0 = game.tick
local fled_at
for _ = 1, 12 do
  M.run_ticks(10)
  local a = global.fo.ia3k.agents[ids[3]]
  if a and a.refuge and not fled_at then fled_at = game.tick end
end
check(fled_at ~= nil and fled_at - t0 <= 60, "fuite engagée en ≤ 1 s (" .. tostring(fled_at and fled_at - t0) .. " ticks)")
check(victim.task and victim.task.fail == "fuite", "la tournée est rendue (fuite)")
st = remote.call("fo-ia3k", "status", "player")
check((st.stats.actions.flee or 0) >= 1 and st.stats.refuges >= 1, "fuite comptée, refuge choisi")
biter.destroy()

---------------------------------------------------------------------------------------------------
section("Mémoire des morts (C5) : la porte")
local C = require("script.ai3.comportement")
local ag = Registry.get(ids[4])
local task = { key = "test:service", kind = "service" }
local steps = { { "home" }, { "goto", { x = -5, y = 140 }, 3 }, { "act", "service" }, { "home" } }
check(C.gate(f, ag, task, steps, game.tick) == false, "cerveau retenu : la porte refuse (banc)")
remote.call("fo-ia3k", "hold", "player", false)
check(C.gate(f, ag, task, steps, game.tick) == true, "trajet sûr : la tâche part")
remote.call("fo-ia3k", "death", "player", -5, 130)
check(C.gate(f, ag, task, steps, game.tick) == false, "1 mort près du but, pas d'escorte possible : attente")
remote.call("fo-ia3k", "death", "player", 0, 135)
check(C.gate(f, ag, task, steps, game.tick) == false, "2 morts dans l'heure : attente")
M.run_ticks(61 * 3600)
check(C.gate(f, ag, task, steps, game.tick) == true, "une heure plus tard : la tâche repart")
remote.call("fo-ia3k", "hold", "player", true)
-- Mort réelle d'un PNJ (cause ennemie) : marquée par le crochet du registre.
local d_before = remote.call("fo-ia3k", "status", "player").stats.deaths
local dv = Registry.get(ids[5])
dv.death_cause, dv.death_pos = "small-biter/enemy:physical", { x = 40, y = 90 }
Registry.remove(ids[5], true)
st = remote.call("fo-ia3k", "status", "player")
check(st.stats.deaths == d_before + 1 and st.summary.deaths >= 1, "mort d'un PNJ marquée sur la carte de l'équipe")
check(pcall(M.serialize, global), "global sérialisable (aucune fonction)")

---------------------------------------------------------------------------------------------------
section("Réglage éteint : aucun effet")
local f2 = setup({ ia3k = false })
local ids2 = agent_ids(f2)
s = game.surfaces[1]
s.create_entity({ name = "small-worm-turret", position = { x = 165, y = 5 }, force = "enemy" })
local pts3 = play_trip(ids2[1], 325, 5, 9000)
st = remote.call("fo-ia3k", "status", "player")
check(st.enabled == false and st.stats.looks == 0 and st.stats.plans == 0, "aucun regard, aucun itinéraire")
check(min_d(pts3, 165, 5) < 5, "sans le lot, le PNJ passe sur le ver (témoin : " .. string.format("%.1f", min_d(pts3, 165, 5)) .. ")")

---------------------------------------------------------------------------------------------------
section("Déterminisme : deux passages identiques")
local function run_once()
  local ff = setup()
  local ii = agent_ids(ff)
  game.surfaces[1].create_entity({ name = "small-worm-turret", position = { x = 165, y = 5 }, force = "enemy" })
  local out = {}
  for k = 1, 3 do
    local p = play_trip(ii[1], 325, 5, 9000)
    out[#out + 1] = string.format("%.3f,%.3f,%d", p[#p].x, p[#p].y, #p)
  end
  return table.concat(out, ";") .. "|" .. M.serialize(global.fo.ia3k.teams)
end
local r1, r2 = run_once(), run_once()
check(r1 == r2, "mêmes trajets et même carte du danger aux deux passages")

print(string.format("[IA3K-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
