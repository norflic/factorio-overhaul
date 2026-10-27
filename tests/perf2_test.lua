--[[
  Lot PERF2 : banc HORS JEU de la mémoire courte des refus de la porte (script/ai3/comportement.lua) et du décalage des
  créneaux de l'ordonnanceur (script/core/scheduler.lua), moteur simulé (même installation que tests/ia3k_moteur_test.lua).
    1. Équivalence : avec et sans mémoire (REFUS_TTL = 0), mêmes décisions de la porte, appel par appel, sur trois suites
       (escalade autour d'un but cerné de vers, but à portée d'un ver, morts près du but) ; moins d'itinéraires avec.
    2. Ce qui lève un refus gardé : carte effacée, menace oubliée DANS la boîte du trajet (map.gone_log ; hors de la boîte :
       rejoué), délai, autre case de départ, escorte devenue possible, menace éteinte vue par la SONDE ; minage : changement
       de site retenté au plus toutes les RETARGET_PERIOD ticks par destination (tâche neuve à chaque pensée).
    3. Mutants : rejeu sans compter l'attente (escalade retardée), mémoire qui ignore les oublis, sonde muette.
    4. Ordonnanceur : le premier membre d'une voie de 300 ticks n'est plus au créneau 1 (tick % 300 = 0) ; deux voies de
       300 ticks n'ont pas le même créneau ; global sérialisable.
  Lancement : lua5.2 tests/perf2_test.lua (depuis la racine du mod).
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

local Registry, C, R, D
local plans = 0
local MUTANT = nil -- fonction appliquée au module de la porte après chaque chargement (mutants)

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
  remote.call("fo-ia3k", "forget", "player")
  remote.call("fo-ia3k", "hold", "player", false)
  -- Le moteur simulé recharge les modules à chaque partie : on les reprend, et on recompte les itinéraires (R.plan).
  Registry = require("script.companion.registry")
  C = require("script.ai3.comportement")
  R = require("shared.ai3.route")
  D = require("shared.ai3.danger")
  local plan0 = R.plan
  R.plan = function(...) plans = plans + 1 return plan0(...) end
  if MUTANT then MUTANT(C) end
  return global.fo.pteam.team
end

local function first_agent(f)
  local ids = {}
  for id in pairs(f.engineers) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local a = Registry.get(id)
    if a and a.entity and a.entity.valid then return a end
  end
end

local RING = { { 40, 0 }, { 28, 28 }, { 0, 40 }, { -28, 28 }, { -40, 0 }, { -28, -28 }, { 0, -40 }, { 28, -28 } }

--- Une suite de jugements : renvoie la liste des décisions (« o » partie, « x » refusée) et le nombre d'itinéraires.
local function scenario(kind, ttl, n, gap)
  local f = setup()
  if ttl then C.REFUS_TTL = ttl end -- nil : délai du module
  local ag = first_agent(f)
  ag.entity.teleport({ x = 0, y = 10 })
  local steps, key
  if kind == "anneau" then
    local gx, gy = 120, -200
    for _, o in ipairs(RING) do remote.call("fo-ia3k", "mark", "player", gx + o[1], gy + o[2], "worm", 25) end
    steps, key = { { "home" }, { "goto", { x = gx, y = gy }, 3 }, { "act", "service" }, { "home" } }, "t:anneau"
  elseif kind == "portee" then
    remote.call("fo-ia3k", "mark", "player", 160, -140, "worm", 25)
    steps, key = { { "home" }, { "goto", { x = 165, y = -150 }, 3 }, { "act", "service" }, { "home" } }, "t:portee"
  else
    remote.call("fo-ia3k", "death", "player", -5, 130)
    remote.call("fo-ia3k", "death", "player", 0, 135)
    steps, key = { { "home" }, { "goto", { x = -5, y = 140 }, 3 }, { "act", "service" }, { "home" } }, "t:morts"
  end
  plans = 0
  local out = {}
  for _ = 1, n do
    local st = {}
    for i, s in ipairs(steps) do st[i] = { s[1], s[2], s[3] } end
    out[#out + 1] = C.gate(f, ag, { key = key, kind = "service" }, st, game.tick) and "o" or "x"
    if gap and gap > 0 then M.run_ticks(gap) end
  end
  return table.concat(out), plans, f, ag
end

---------------------------------------------------------------------------------------------------
section("1. Équivalence avec et sans mémoire")
local memo_total, full_total = 0, 0
for _, sc in ipairs({ { "anneau", 12, 0 }, { "anneau", 12, 60 }, { "portee", 10, 60 }, { "morts", 8, 60 } }) do
  local d_on, p_on = scenario(sc[1], nil, sc[2], sc[3])
  local d_off, p_off = scenario(sc[1], 0, sc[2], sc[3])
  check(d_on == d_off, string.format("%s (pas %d) : mêmes décisions avec et sans mémoire (%s contre %s)", sc[1], sc[3], d_on, d_off))
  check(p_on < p_off, string.format("%s (pas %d) : moins d'itinéraires avec la mémoire (%d contre %d)", sc[1], sc[3], p_on, p_off))
  memo_total, full_total = memo_total + p_on, full_total + p_off
  print(string.format("   %s pas %d : %s ; itinéraires %d avec, %d sans", sc[1], sc[3], d_on, p_on, p_off))
end
local d_ring = scenario("anneau", nil, 12, 60)
check(d_ring:sub(1, 5) == "xxxxo", "anneau : 4 attentes puis départ (escalade inchangée) : " .. d_ring)
print(string.format("   itinéraires : %d avec la mémoire, %d sans", memo_total, full_total))

---------------------------------------------------------------------------------------------------
section("2. Ce qui lève un refus gardé")
-- Un refus gardé, puis chaque événement : le jugement suivant calcule un itinéraire.
local function after_refusal(event)
  local _, _, f, ag = scenario("portee", nil, 1, 0)
  local steps = { { "home" }, { "goto", { x = 165, y = -150 }, 3 }, { "act", "service" }, { "home" } }
  plans = 0
  C.gate(f, ag, { key = "t:portee", kind = "service" }, steps, game.tick)
  local replayed = plans == 0
  event(f, ag)
  plans = 0
  local ok = C.gate(f, ag, { key = "t:portee", kind = "service" },
    { { "home" }, { "goto", { x = 165, y = -150 }, 3 }, { "act", "service" }, { "home" } }, game.tick)
  return replayed, plans, ok
end
local rep, p, ok = after_refusal(function() remote.call("fo-ia3k", "forget", "player") end)
check(rep, "refus répété sans événement : rejoué (aucun itinéraire)")
check(p > 0 and ok == true, string.format("carte effacée : jugement complet (%d itinéraire(s)), la tâche part", p))
rep, p, ok = after_refusal(function()
  local t = global.fo.ia3k.teams["player"]
  D.forget_unseen(t.map, 160, -140, 10, nil)
end)
check(p > 0 and ok == true, string.format("ver oublié par un regard (map.gone) : jugement complet (%d), la tâche part", p))
local function idle_ticks(ag, n)
  remote.call("fo-ia3k", "hold", "player", true)
  M.run_ticks(n)
  remote.call("fo-ia3k", "hold", "player", false)
  ag.entity.teleport({ x = 0, y = 10 }) -- même case de départ
end
rep, p = after_refusal(function(_, ag) idle_ticks(ag, C.REFUS_TTL + 1) end)
check(p > 0, string.format("délai passé (%d ticks) : jugement complet (%d)", C.REFUS_TTL + 1, p))
rep, p = after_refusal(function(_, ag) ag.entity.teleport({ x = 60, y = 40 }) end)
check(p > 0, string.format("autre case de départ : jugement complet (%d)", p))
rep, p = after_refusal(function() C.escort_free = function() return 3 end end)
check(p > 0, string.format("escorte devenue possible : jugement complet (%d)", p))
rep, p = after_refusal(function() M.run_ticks(60) end)
check(p == 0, "rien de changé, 60 ticks plus tard : rejoué")
-- La SONDE : le ver disparaît de la carte SANS passer par un oubli compté (décroissance, par exemple) : la sonde rejuge le
-- chemin gardé, le refus ne tient plus, jugement complet.
rep, p, ok = after_refusal(function() global.fo.ia3k.teams["player"].map.threats = {} end)
check(p > 0 and ok == true, string.format("menace éteinte sans oubli compté : la sonde rend la main (%d), la tâche part", p))
rep, p = after_refusal(function(_, ag) idle_ticks(ag, 1800) end)
check(p == 0, "30 s plus tard, ver toujours là : rejoué (sonde)")
-- Un lieu oublié HORS de la boîte du trajet ne rend pas la main (oubli ciblé, map.gone_log).
rep, p = after_refusal(function()
  local t = global.fo.ia3k.teams["player"]
  D.mark_seen(t.map, 900, 900, "worm", 25, game.tick)
  D.forget_unseen(t.map, 900, 900, 10, nil)
end)
check(p == 0, "ver oublié loin du trajet (900, 900) : refus rejoué")
-- Minage : le tableau remplace ses tâches libres à chaque pensée (task.ia3k_retarget perdu) ; le changement de site est
-- tenté au plus toutes les RETARGET_PERIOD ticks par destination, refus rejoués entre deux.
do
  local _, _, f, ag = scenario("portee", nil, 0, 0)
  local function mine_gate()
    local mt = { key = "t:mine-u", kind = "mine", resource = "uranium-ore", radius = 96, target = { x = 165, y = -150 } }
    local ms = { { "home" }, { "goto", { x = 165, y = -150 }, 1.5 }, { "mine", "uranium-ore", 10 }, { "home" } }
    plans = 0
    local ok = C.gate(f, ag, mt, ms, game.tick)
    return ok, plans
  end
  local ok1, p1 = mine_gate()
  idle_ticks(ag, 60)
  local ok2, p2 = mine_gate()
  idle_ticks(ag, C.RETARGET_PERIOD)
  local ok3, p3 = mine_gate()
  check(not ok1 and p1 > 0, string.format("minage vers un but gardé, sans autre site : refus complet (%d itinéraire(s))", p1))
  check(not ok2 and p2 == 0, string.format("même minage 60 ticks plus tard (tâche neuve) : refus rejoué (%d)", p2))
  check(not ok3 and p3 > 0, string.format("après RETARGET_PERIOD : jugement complet, changement de site retenté (%d)", p3))
end
local stt = remote.call("fo-ia3k", "status", "player")
check((stt.stats.refus_memo or 0) > 0, "statistique des refus rejoués publiée (" .. tostring(stt.stats.refus_memo) .. ")")
check(pcall(M.serialize, global), "global sérialisable (aucune fonction)")

---------------------------------------------------------------------------------------------------
section("3. Mutants")
MUTANT = function(Cm)
  local replay0 = Cm.refus_replay
  Cm.refus_replay = function(f, t, agent, task, dest, dk, r, tick)
    local w = t.waits and t.waits[dk]
    local n0 = w and w.n
    local a, b = replay0(f, t, agent, task, dest, dk, r, tick)
    if w then w.n = n0 end -- mutant : l'attente rejouée n'est pas comptée
    return a, b
  end
end
local m_on = scenario("anneau", nil, 12, 60)
local m_off = scenario("anneau", 0, 12, 60)
MUTANT = nil
check(m_on ~= m_off, "mutant « attente rejouée non comptée » : décisions changées, vu (" .. m_on .. " contre " .. m_off .. ")")
MUTANT = function(Cm)
  local hit0 = Cm.refus_hit
  Cm.refus_hit = function(t, task, dk, sk, B, Wn, prud, esc, tick)
    local r = t.refus and t.refus[dk]
    if r then r.uv, r.gone = t.uv or 0, t.map.gone or 0 end -- mutant : menaces oubliées ignorées
    local save = t.map
    t.map = { threats = save.threats_mutant or { { x = 160, y = -140, k = "worm", r = 25, t = tick } }, deaths = {}, cells = {} }
    local h = hit0(t, task, dk, sk, B, Wn, prud, esc, tick)
    t.map = save
    return h
  end
end
local _, p_m, ok_m = after_refusal(function() remote.call("fo-ia3k", "forget", "player") end)
MUTANT = nil
check(not ok_m and p_m == 0, "mutant « carte effacée ignorée » : refus rejoué à tort, vu")
MUTANT = function(Cm)
  Cm.refus_probe = function() return "wait", "bloque", false, 0, 0 end -- mutant : sonde qui refuse toujours
end
local _, p_s, ok_s = after_refusal(function() global.fo.ia3k.teams["player"].map.threats = {} end)
MUTANT = nil
check(not ok_s and p_s == 0, "mutant « sonde muette » : menace éteinte, refus rejoué à tort, vu")

---------------------------------------------------------------------------------------------------
section("4. Ordonnanceur : créneaux décalés")
setup()
local lanes = global.fo.sched.lanes
local slots300 = {}
for _, name in ipairs({ "fo-pteam", "fo-commander" }) do
  local st = lanes[name]
  if st and st.period == 300 then
    local ids = {}
    for id in pairs(st.slot_of) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
    if ids[1] then
      local s = st.slot_of[ids[1]]
      check(s ~= 1, string.format("%s : premier membre au créneau %d (et non 1, tick %% 300 = 0)", name, s))
      slots300[#slots300 + 1] = { name, s }
      print(string.format("   %s : créneau %d sur 300", name, s))
    end
  end
end
check(#slots300 >= 1, "au moins une voie de 300 ticks vue (" .. #slots300 .. ")")
if #slots300 >= 2 then check(slots300[1][2] ~= slots300[2][2], "deux voies de 300 ticks : créneaux différents") end
local per = {}
for _, name in ipairs({ "fo-pteam-prospect" }) do
  local st = lanes[name]
  if st then
    local ids = {}
    for id in pairs(st.slot_of) do ids[#ids + 1] = id end
    if ids[1] then per[#per + 1] = st.slot_of[ids[1]] end
  end
end
check(#per == 0 or per[1] >= 1, "voie de 30 ticks : créneau valide")

print(string.format("[PERF2] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
