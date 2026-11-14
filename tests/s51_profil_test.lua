-- Lot S51 : cumul par gestionnaire dans le bus d'événements (faux game.create_profiler). Usage : lua5.2 tests/s51_profil_test.lua
package.path = "./?.lua;" .. package.path
local ok, ko = 0, 0
local function check(c, m) if c then ok = ok + 1 else ko = ko + 1; print("  ECHEC : " .. m) end end

local created, calls = 0, 0
local function fake_profiler()
  created = created + 1
  local p = { ms = 0, running = true }
  p.restart = function() calls = calls + 1; p.ms = 0; p.running = true end
  p.stop = function() calls = calls + 1; p.running = false end
  p.reset = function() p.ms = 0; p.running = true end
  p.add = function(o) calls = calls + 1; p.ms = p.ms + (o.ms or 0) end
  return p
end
local logs = {}
_G.log = function(x) logs[#logs + 1] = x end
_G.defines = { events = { on_tick = 0, on_entity_died = 4, on_built_entity = 6 } }
_G.game = { create_profiler = function() return fake_profiler() end, entity_prototypes = {} }
local bound = {}
_G.script = {
  on_init = function() end, on_load = function() end, on_configuration_changed = function() end,
  on_event = function(id, f) bound["e" .. id] = f end,
  on_nth_tick = function(n, f) bound["n" .. n] = f end,
}
package.loaded["script.core.profiler"] = {
  start = function() end, stop = function() end, fine = function() return false end,
  fstart = function() end, fstop = function() end,
}
local Events = require("script.core.events")
local hits = 0
local function h1(e) hits = hits + 1 end
local function h2(e) hits = hits + 1 end
local function h3(e) hits = hits + 1 end
Events.on(defines.events.on_tick, h1)
Events.on(defines.events.on_tick, h2)
Events.on_nth_tick(60, h3)
Events.on(defines.events.on_built_entity, function() end) -- jamais appelé
Events.bind()

for t = 1, 7300 do
  bound.e0({ tick = t })
  if t % 60 == 0 then bound.n60({ tick = t }) end
end
check(hits == 7300 * 2 + 121, "les gestionnaires sont tous appelés : " .. hits)
check(created == 6, "deux profileurs par gestionnaire appelé, créés une fois : " .. created)
check(#Events.cumul_list() == 3, "gestionnaire jamais appelé : aucun cumul")
check(calls == (7300 * 2 + 121) * 3 + 6, "3 appels d'API par appel de gestionnaire (+ stop des 6 remises à zéro) : " .. calls)
local lignes = 0
for _, l in ipairs(logs) do
  local s = l[2]
  check(type(s) == "string" and s:match("^%[FO%-PERF%-CUMUL%] .+ appels=%d+ $"), "format : " .. tostring(s))
  check(type(l[3]) == "table" and l[3].add, "durée = le profileur cumulé")
  lignes = lignes + 1
end
check(lignes == 6, "deux écritures de 3 lignes (ticks 3601 et 7201) : " .. lignes)
check(logs[1] and logs[1][2]:find("event:on_tick@") and logs[1][2]:find("s51_profil_test.lua:"), "clé fichier:ligne : " .. tostring(logs[1] and logs[1][2]))
check(logs[1] and logs[1][2]:find("appels=3600 "), "appels comptés sur la période : " .. tostring(logs[1] and logs[1][2]))
check(logs[3] and logs[3][2]:find("^%[FO%-PERF%-CUMUL%] nth:60@") and logs[3][2]:find("appels=60 "), "nth:60 : " .. tostring(logs[3] and logs[3][2]))
for _, c in ipairs(Events.cumul_list()) do check(c.appels < 200, "remise à zéro après écriture") end

-- coût hors jeu : enveloppe contre appel nu (faux profileur, ordre de grandeur seulement)
local N = 200000
local t0 = os.clock(); for i = 1, N do h1() end; local nu = os.clock() - t0
t0 = os.clock(); for i = 1, N / 2 do bound.e0({ tick = 10000 }) end; local env = os.clock() - t0
print(string.format("  coût : nu %.3f s, enveloppé %.3f s pour %d appels (faux profileur)", nu, env, N))
print(string.format("%d OK, %d ECHEC", ok, ko))
os.exit(ko == 0 and 0 or 1)
