--[[
  Lot RESEAU-GRAPHE, bus en jeu (script/team/bus.lua) : test hors jeu avec un moteur simulé minimal (réglage, équipe, relevé de la liaison de quai).
    §1 tracé accepté ; §2 réglage éteint ou absent : rien ; §3 calcul par tranches puis demande d'UNE liaison longue (bus = vrai), après confirmation ;
    §4 paires à portée de la liaison de quai laissées à elle ; §5 menace, ennemi, essais épuisés ; §6 journal [FO-BUS] ; §7 branchement lu comme texte.
  Usage : lua5.2 tests/bus_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end

local logs = {}
function log(s) logs[#logs + 1] = s end
settings = { global = {} }
local function set_bus(v) settings.global["fo-war-bus"] = v ~= nil and { value = v } or nil end

local Bus = require("script.team.bus")
local Ln = require("shared.team.liaison")
local Rg = require("shared.team.reseau_graphe")

-- §1 tracé
check(select(1, Bus.route_ok(100, 90)) == true, "1.1 100 tuiles pour 90 à vol d'oiseau : accepté")
check(select(1, Bus.route_ok(Rg.MAX_TRUNK + 1, 200)) == false, "1.2 au-delà de Rg.MAX_TRUNK : refusé")
check(select(1, Bus.route_ok(250, 50)) == false, "1.3 un détour de plus de deux fois la distance : refusé")
check(select(1, Ln.route_ok(100, 90)) == false, "1.4 (témoin) la liaison de quai refuse ce tracé de 100 tuiles")

-- §2 réglage
set_bus(nil)
check(Bus.on() == false, "2.1 réglage absent : éteint")
set_bus(false)
check(Bus.on() == false, "2.2 réglage éteint : éteint")
set_bus(true)
check(Bus.on() == true, "2.3 réglage allumé")

-- moteur simulé
local function world(span, extra)
  local f = { key = "player", hq = { valid = true, position = { x = 0, y = 0 } }, build = { projects = {}, order = {}, liaison = nil } }
  local b = f.build
  b.projects[1] = { id = 1, outs = { { x = -10, y = 0 } }, quais = {}, state = "fini", outflow = nil }
  b.projects[2] = { id = 2, outs = {}, quais = { { x = -10 + span, y = 0, item = "x" } }, state = "fini" }
  local st = { links = {}, tries = {}, last_try = {}, seen = {}, said = {}, src_item = {}, flow = {}, n = { demandes = 0, finis = 0, refuses = 0, coupees = 0 } }
  b.liaison = st
  local c = {
    docks = { { key = "2:q1", pid = 2, idx = 1, x = -10 + span, y = 0, item = "x", flow = 1.0, n = 5 } },
    srcs = { { key = "1:o1", pid = 1, idx = 1, x = -10, y = 0, item = "x", n = 300 } },
  }
  if extra then extra(f, b, st, c) end
  return f, b, st, c
end
local requests = {}
local api = { prio = 56, request = function(f, spec) requests[#requests + 1] = spec return 100 + #requests end }
local threat, enemy = false, false
local H = {
  max_open = function(free) return math.max(1, free) end,
  free_workers = function() return 3 end,
  hq_threat = function() return threat end,
  enemy_near = function() return enemy end,
  pick_names = function() return "inserter", "small-electric-pole" end,
  belt = function() return "transport-belt" end,
}
local function run(f, b, st, c, tick)
  local started = Bus.start(H, f, nil, tick, b, st, c)
  local asked = false
  local steps = 0
  while st.bus and st.bus.job and steps < 5000 do
    steps = steps + 1
    if Bus.advance(H, api, f, nil, tick) then asked = true end
  end
  return started, asked, steps
end

-- §3 calcul par tranches, confirmation, demande
do
  set_bus(true)
  local f, b, st, c = world(90)
  requests = {}
  local started, asked, steps = run(f, b, st, c, 1000)
  check(started and steps >= 2, "3.1 le calcul démarre et se fait par tranches (" .. steps .. " passes)")
  check(not asked and #requests == 0, "3.2 premier calcul : la paire est vue une fois, rien n'est demandé (confirmation)")
  local started2 = Bus.start(H, f, nil, 1500, b, st, c)
  check(not started2, "3.3 un second calcul n'a pas lieu avant Bus.PERIOD")
  local _, asked2 = run(f, b, st, c, 1000 + Bus.PERIOD + 10)
  check(asked2 and #requests == 1, "3.4 deuxième calcul : la paire est confirmée, UNE liaison est demandée")
  local sp = requests[1] and requests[1].liaison
  check(sp and sp.bus == true and sp.key == "2:q1" and sp.src.key == "1:o1" and sp.dock.x == 80, "3.5 la demande est une liaison de bus, du quai 2:q1 à la sortie 1:o1")
  check(st.links["2:q1"] and st.links["2:q1"].bus == true and st.n.demandes == 1, "3.6 le lien est suivi comme une liaison (bus = vrai)")
  local said = false
  for _, l in ipairs(logs) do if l:find("[FO-BUS]", 1, true) and l:find("bus 1 choisi", 1, true) and l:find("liaison demandee", 1, true) then said = true end end
  check(said, "6.1 le journal [FO-BUS] dit le bus choisi, la paire et le projet")
  -- une fois demandée, la même paire ne l'est plus
  requests = {}
  local _, asked3 = run(f, b, st, c, 1000 + 2 * Bus.PERIOD + 20)
  check(not asked3 and #requests == 0, "3.7 le quai est déjà relié (lien en cours) : pas de seconde demande")
end

-- §4 paire à portée de la liaison de quai : laissée à elle
do
  local f, b, st, c = world(30)
  requests = {}
  run(f, b, st, c, 1000)
  run(f, b, st, c, 1000 + Bus.PERIOD + 10)
  check(#requests == 0, "4.1 sortie et quai à 30 tuiles (moins de Li.MAX_SPAN) : le bus laisse la liaison de quai")
end

-- §5 gardes
do
  local f, b, st, c = world(90)
  requests = {}
  threat = true
  run(f, b, st, c, 1000)
  run(f, b, st, c, 1000 + Bus.PERIOD + 10)
  check(#requests == 0, "5.1 QG menacé : aucune demande")
  threat = false
  enemy = true
  local f2, b2, st2, c2 = world(90)
  run(f2, b2, st2, c2, 1000)
  run(f2, b2, st2, c2, 1000 + Bus.PERIOD + 10)
  check(#requests == 0, "5.2 ennemi à portée d'un coffre : aucune demande")
  enemy = false
  local f3, b3, st3, c3 = world(90, function(_, _, s) s.tries["2:q1"] = Ln.MAX_TRIES s.last_try["2:q1"] = 1000 end)
  run(f3, b3, st3, c3, 1000)
  run(f3, b3, st3, c3, 1000 + Bus.PERIOD + 10)
  check(#requests == 0, "5.3 essais épuisés récemment : aucune demande")
  set_bus(false)
  local f4, b4, st4, c4 = world(90)
  local started = Bus.start(H, f4, nil, 1000, b4, st4, c4)
  check(not started and st4.bus == nil, "5.4 réglage éteint : aucun calcul, aucun état")
  set_bus(true)
  local f5, b5, st5, c5 = world(90, function(_, _, _, c) c.srcs[1].n = 10 end)
  run(f5, b5, st5, c5, 1000)
  run(f5, b5, st5, c5, 1000 + Bus.PERIOD + 10)
  check(#requests == 0, "5.5 coffre de sortie presque vide et sans débit nominal : pas de producteur, pas de bus")
end

-- §7 branchement (texte)
local LIA = read("script/team/liaison.lua")
check(LIA:find('require("script.team.bus")', 1, true) ~= nil and LIA:find("Bus.start(BUS_H", 1, true) ~= nil and LIA:find("Bus.advance(BUS_H", 1, true) ~= nil,
  "7.1 liaison.lua appelle Bus.start (relevé fini) et Bus.advance (chaque passe)")
check(LIA:find("lc.bus and Bus.MAX_BOX", 1, true) ~= nil and LIA:find("Bus.route_ok", 1, true) ~= nil, "7.2 Liaison.plan élargit l'emprise et le tracé pour un bus")
check(LIA:find("tronc pose", 1, true) ~= nil and LIA:find("tronc refuse", 1, true) ~= nil, "7.3 les fins d'un tronc (posé, refusé avec sa cause) sont journalisées")
local SET = read("settings/bus.lua")
check(SET:find('name = "fo-war-bus"', 1, true) ~= nil and SET:find("default_value = true", 1, true) ~= nil, "7.4 réglage fo-war-bus allumé par défaut")
check(read("locale/fr/bus.cfg"):find("fo-war-bus", 1, true) ~= nil and read("locale/en/bus.cfg"):find("fo-war-bus", 1, true) ~= nil, "7.5 traductions FR et EN")
local code = read("script/team/bus.lua"):gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check(not code:find("iron%-") and not code:find("copper%-") and not code:find("math%.random") and not code:find("os%.clock"), "7.6 aucun nom d'objet, ni hasard, ni horloge")

print(string.format("[BUS] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
