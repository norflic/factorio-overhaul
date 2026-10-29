--[[
  Lot DETOUR-BOUCLE : banc HORS JEU de la boucle de détours (retour du DC sur 0.6.18, point 3 : « Ils font détour, détour,
  détour en boucle (mais au même endroit) et donc tournent un peu sur eux-même »).
    1. Règle pure (shared/ai3/detour.lua) : série de détours, boucle, échecs par but, éviction, issue ;
    2. moteur simulé : un but à portée + 6 d'un ver CONNU (portée 25 : la porte et l'itinéraire l'acceptent, au-delà de
       portée + 4 ; la réaction demande un détour jusqu'à portée + 8) :
       - témoin (Dt.MAX infini, comportement de 0.6.18) : le PNJ tourne en rond au même endroit, sans jamais arriver ;
       - avec le lot : au plus Dt.MAX + 2 détours, boucle cassée (demi-tour, tâche rendue), journal [FO-DETOUR], but refusé
         par la porte 5 min (« wait:boucle ») puis rendu ;
       - sans tâche (aller sans tâche) : la boucle cassée laisse le PNJ suivre son itinéraire, il arrive ;
       - déterminisme (deux passages identiques), global sérialisable.
  Lancement : lua5.2 tests/detour_boucle_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local function W() return M.world() end

---------------------------------------------------------------------------------------------------
section("Règle pure : série de détours, boucle, échecs par but")
local Dt = require("shared.ai3.detour")
local g = { x = 100, y = 50 }
local m = Dt.note(nil, { x = 10, y = 10 }, g, 1000)
check(m.n == 1 and not Dt.loop(m), "premier détour : série de 1, pas de boucle")
for k = 2, Dt.MAX do m = Dt.note(m, { x = 10 + k, y = 10 }, g, 1000 + 120 * k) end
check(m.n == Dt.MAX and not Dt.loop(m), "Dt.MAX détours au même endroit : pas encore une boucle")
local m2 = Dt.note(m, { x = 12, y = 11 }, g, 1000 + 120 * (Dt.MAX + 1))
check(m2 == m and Dt.loop(m2), "un détour de plus au même endroit, même but : boucle")
local mg = Dt.note({ x = 10, y = 10, gx = 100, gy = 50, n = 3, t0 = 0, t = 100 }, { x = 10, y = 10 }, { x = 140, y = 50 }, 200)
check(mg.n == 1, "autre but : nouvelle série")
local mp = Dt.note({ x = 10, y = 10, gx = 100, gy = 50, n = 3, t0 = 0, t = 100 }, { x = 10 + Dt.NEAR + 1, y = 10 }, g, 200)
check(mp.n == 1 and mp.x == 10 + Dt.NEAR + 1, "plus loin que Dt.NEAR du premier détour (le PNJ progresse) : nouvelle série")
local mw = Dt.note({ x = 10, y = 10, gx = 100, gy = 50, n = 3, t0 = 0, t = 100 }, { x = 10, y = 10 }, g, 100 + Dt.WINDOW + 1)
check(mw.n == 1, "plus de Dt.WINDOW ticks après le précédent : nouvelle série")
local mn = Dt.note({ x = 10, y = 10, n = 3, t0 = 0, t = 100 }, { x = 11, y = 10 }, nil, 200)
check(mn.n == 4, "sans but (nil), même endroit : même série")
local tab = {}
Dt.fail(tab, 100, 50, 5000)
check(Dt.failed(tab, 103, 52, 5001) ~= nil, "but refusé (même case de 16 tuiles)")
check(Dt.failed(tab, 100, 50, 5000 + Dt.FAIL_TICKS) == nil, "refus expiré après Dt.FAIL_TICKS")
check(Dt.failed(tab, 300, 50, 5001) == nil, "autre case : pas refusée")
check(Dt.failed(nil, 100, 50, 5001) == nil, "équipe sans mémoire : rien de refusé")
check(Dt.fail(tab, 100, 50, 6000).n == 2, "deuxième échec au même but : compté")
local big = {}
for i = 1, Dt.FAIL_MAX + 5 do Dt.fail(big, i * 32, 0, 1000 + i) end
local nk = 0
for _ in pairs(big) do nk = nk + 1 end
check(nk == Dt.FAIL_MAX, "au plus Dt.FAIL_MAX buts retenus (" .. nk .. ")")
check(Dt.failed(big, 32, 0, 2000) == nil and Dt.failed(big, (Dt.FAIL_MAX + 5) * 32, 0, 2000) ~= nil,
  "les plus anciens partent, le plus récent reste")
check(Dt.outcome(true, "goto") == "abandon" and Dt.outcome(true, "home") == "suivre" and Dt.outcome(false, "goto") == "suivre",
  "issue : abandon sur l'aller d'une tâche, sinon suivre")

---------------------------------------------------------------------------------------------------
-- Moteur simulé (même montage que tests/ia3k_moteur_test.lua)
---------------------------------------------------------------------------------------------------
local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end

local WX, WY = 160, 5     -- ver de portée 25
local GX, GY = 138, -17   -- but à 31,1 tuiles : au-delà de portée + 4 (porte, itinéraire), en deçà de portée + 8 (réaction)

local Registry, FSM, C -- modules du mod : rechargés à chaque partie du moteur simulé (setup)
local function setup()
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0 })
  if W().remote["fo-ia3f"] then remote.call("fo-ia3f", "set_fog", false) end
  W().prototypes["small-worm-turret"] = { type = "turret", max_health = 200,
    collision_box = { left_top = { x = -0.9, y = -0.8 }, right_bottom = { x = 0.9, y = 0.8 } },
    attack_parameters = { range = 25 } }
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
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "coal", 200 }, { "pistol", 2 }, { "firearm-magazine", 40 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  remote.call("fo-ia3k", "hold", "player", true)
  M.run_ticks(600)
  Registry = require("script.companion.registry")
  FSM = require("script.core.fsm")
  C = require("script.ai3.comportement")
  s.create_entity({ name = "small-worm-turret", position = { x = WX, y = WY }, force = "enemy" })
  remote.call("fo-ia3k", "mark", "player", WX, WY, "worm", 25) -- ver CONNU (vu plus tôt)
  local f = global.fo.pteam.team
  local ids = {}
  for id in pairs(f.engineers) do ids[#ids + 1] = id end
  table.sort(ids)
  return f, ids
end


local function dist(p, x, y) return math.sqrt((p.x - x) ^ 2 + (p.y - y) ^ 2) end

--- Joue `ticks` ticks de l'agent `id` (positions toutes les 10 ticks) ; s'arrête quand sa tâche est finie (si `until_done`).
local function follow(id, ticks, until_done)
  local pts = {}
  for k = 1, ticks / 10 do
    M.run_ticks(10)
    local ag = Registry.get(id)
    if not ag then break end
    local p = ag.entity.position
    pts[#pts + 1] = { x = p.x, y = p.y, t = game.tick, task = ag.task ~= nil }
    if until_done and not ag.task and k > 12 then break end
  end
  return pts
end

local function stats() return remote.call("fo-ia3k", "status", "player").stats end

--- Détours faits À MOINS DE Dt.NEAR tuiles d'un même point (le plus grand groupe) : « au même endroit ».
local function detours_same_place(marks)
  local best = 0
  for _, a in ipairs(marks) do
    local n = 0
    for _, b in ipairs(marks) do if dist(a, b.x, b.y) <= Dt.NEAR then n = n + 1 end end
    if n > best then best = n end
  end
  return best
end

--- Une tournée vers le but, en relevant le lieu de chaque détour.
local function trip_detours(id, ticks)
  remote.call("fo-ia3k", "trip", "player", id, GX, GY, 60)
  local marks, last = {}, stats().actions.detour or 0
  local reached = false
  for _ = 1, ticks / 10 do
    M.run_ticks(10)
    local ag = Registry.get(id)
    if not ag then break end
    local d = stats().actions.detour or 0
    if d > last then marks[#marks + 1] = { x = ag.entity.position.x, y = ag.entity.position.y } last = d end
    if dist(ag.entity.position, GX, GY) <= 4 then reached = true end
    if not ag.task then break end
  end
  return marks, reached
end

---------------------------------------------------------------------------------------------------
section("Témoin (comportement de 0.6.18 : aucune limite) : boucle de détours au même endroit")
local f, ids = setup()
require("shared.ai3.detour").MAX = 1e9 -- le module chargé par le mod (le moteur simulé recharge shared.* à chaque partie)
local marks0, reached0 = trip_detours(ids[1], 4000)
print(string.format("  mesure : %d détour(s) en 4 000 ticks, %d à moins de %d tuiles d'un même point, but atteint : %s", #marks0,
  detours_same_place(marks0), Dt.NEAR, tostring(reached0)))
check(#marks0 >= 15, "témoin : au moins 15 détours en 4 000 ticks (" .. #marks0 .. ")")
check(detours_same_place(marks0) >= 12, "témoin : au moins 12 détours à moins de " .. Dt.NEAR .. " tuiles d'un même point ("
  .. detours_same_place(marks0) .. ") : le PNJ tourne en rond")
check(not reached0, "témoin : le PNJ n'arrive jamais au but")
check((stats().dloops or 0) == 0, "témoin : aucune boucle cassée")

---------------------------------------------------------------------------------------------------
section("Avec le lot : boucle détectée et cassée, demi-tour, tâche rendue, journal")
f, ids = setup()
local nlog0 = #W().logs
local marks1 = trip_detours(ids[1], 4000)
local st = stats()
print(string.format("  mesure : %d détour(s), %d boucle(s) cassée(s), %d demi-tour(s)", #marks1, st.dloops or 0, st.actions.back or 0))
check(#marks1 <= Dt.MAX + 2, "au plus Dt.MAX + 2 détours (" .. #marks1 .. ")")
check((st.dloops or 0) == 1, "une boucle cassée (" .. tostring(st.dloops) .. ")")
check((st.actions.back or 0) >= 1, "demi-tour après la boucle (" .. tostring(st.actions.back) .. ")")
local ag1 = Registry.get(ids[1])
check(ag1 and not ag1.task, "la tâche est rendue (le PNJ ne la poursuit plus)")
local dl = {}
for i = nlog0 + 1, #W().logs do if W().logs[i]:find("[FO-DETOUR]", 1, true) then dl[#dl + 1] = W().logs[i] end end
check(#dl == 1 and dl[1]:find("tourne en rond", 1, true) and dl[1]:find("but refuse 5 min", 1, true),
  "journal [FO-DETOUR] : une ligne, boucle et issue (" .. tostring(dl[1]) .. ")")
print("  journal : " .. tostring(dl[1]))
local tm = global.fo.ia3k.teams["player"]
check(Dt.failed(tm.dfail, GX, GY, game.tick) ~= nil, "le but est retenu comme échec de l'équipe")
local pts1 = follow(ids[1], 3000, false)
check(dist(pts1[#pts1], GX, GY) > 60, "le PNJ quitte l'endroit de la boucle (rentré à "
  .. string.format("%.0f", dist(pts1[#pts1], GX, GY)) .. " tuiles du but)")
check(pcall(M.serialize, global), "global sérialisable (aucune fonction)")

---------------------------------------------------------------------------------------------------
section("La porte refuse ce but 5 min (autre tâche), puis le rend")
remote.call("fo-ia3k", "hold", "player", false)
local ag = Registry.get(ids[2])
local steps = { { "home" }, { "goto", { x = GX, y = GY }, 3 }, { "act", "service" }, { "home" } }
local r0 = stats().dloop_refus or 0
local ok1 = C.gate(f, ag, { key = "test:boucle", kind = "service" }, steps, game.tick)
check(ok1 == false and (stats().dloop_refus or 0) == r0 + 1, "but où l'on a tourné en rond : refusé par la porte")
check((stats().gate_why["wait:boucle"] or 0) >= 1, "motif compté au bilan de la porte (wait:boucle)")
local steps_other = { { "home" }, { "goto", { x = -120, y = 5 }, 3 }, { "act", "service" }, { "home" } }
check(C.gate(f, ag, { key = "test:autre", kind = "service" }, steps_other, game.tick) == true, "une autre tâche part (autre but)")
-- L'escalade d'IA3-k reste possible (« attendre n'est pas une fin ») : après W refus, départ « risque accepté », sans
-- détour devant une menace fixe : plus de boucle possible.
local refus_b, went_b = 1, false
for i = 1, 8 do
  if C.gate(f, ag, { key = "test:boucle-esc", kind = "service" }, steps, game.tick + i) then went_b = true break end
  refus_b = refus_b + 1
end
check(went_b and refus_b == 4 and global.fo.ia3k.agents[ag.id].risk == true,
  "escalade après 4 refus (neutre), départ « risque accepté » (" .. refus_b .. " refus)")
local later = game.tick + Dt.FAIL_TICKS + 60
check(C.gate(f, ag, { key = "test:boucle2", kind = "service" }, steps, later) == true,
  "5 min plus tard : le but est rendu à la porte (trajet jugé sûr)")
remote.call("fo-ia3k", "hold", "player", true)

---------------------------------------------------------------------------------------------------
section("Sans tâche : la boucle cassée laisse le PNJ suivre son itinéraire")
f, ids = setup()
local ag3 = Registry.get(ids[1]) -- même PNJ, même départ que le témoin
ag3.task = nil
ag3.steps, ag3.pc, ag3.failed = { { "goto", { x = GX, y = GY }, 3 } }, 1, nil
FSM.set(C.MACHINE, ag3, "step", game.tick)
local reached3, arrived_t = false, nil
for _ = 1, 400 do
  M.run_ticks(10)
  if dist(ag3.entity.position, GX, GY) <= 4 then reached3 = true arrived_t = arrived_t or game.tick end
  if reached3 then break end
end
st = stats()
check((st.dloops or 0) == 1 and (st.actions.back or 0) == 0, "boucle cassée sans demi-tour (" .. tostring(st.dloops) .. ", "
  .. tostring(st.actions.back) .. ")")
check(reached3, "le PNJ arrive au but (" .. tostring(arrived_t) .. ")")
check((st.actions.detour or 0) <= Dt.MAX + 2, "au plus Dt.MAX + 2 détours (" .. tostring(st.actions.detour) .. ")")
check(Dt.failed(global.fo.ia3k.teams["player"].dfail, GX, GY, game.tick) == nil, "pas de but refusé (aucune tâche rendue)")

---------------------------------------------------------------------------------------------------
section("Déterminisme : deux passages identiques")
local function run_once()
  local _, ii = setup()
  local mk = trip_detours(ii[1], 4000)
  local p = follow(ii[1], 1000, false)
  return string.format("%d|%.3f,%.3f|", #mk, p[#p].x, p[#p].y) .. M.serialize(global.fo.ia3k)
end
local a1, a2 = run_once(), run_once()
check(a1 == a2, "mêmes trajets, même mémoire des détours aux deux passages")

print(string.format("[DETOUR-BOUCLE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
