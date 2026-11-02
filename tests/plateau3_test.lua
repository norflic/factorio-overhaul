--[[
  Lot C4 PLATEAU 3 : tournee d'avant-poste arrivee malgre un chemin refuse (shared/team/arrivee.lua), branchee dans
  script/team/worker.lua (nav_failed) et script/faction/outposts.lua (Outposts.nearest_d2).
  Usage : lua5.2 tests/plateau3_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local function read(path) local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s end
local SRC = read("shared/team/arrivee.lua")
local function load_ar(src) local fn = assert(load(src, "=arrivee", "t")); return fn() end

local function suite(Ar)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m) if c then pass = pass + 1 else fail = fail + 1; msgs[#msgs + 1] = m end end
  -- plus proche batiment
  check(Ar.nearest_d2({}, 0, 0) == nil and Ar.nearest_d2(nil, 0, 0) == nil, "aucun batiment : nil")
  check(Ar.nearest_d2({ { x = 3, y = 4 } }, 0, 0) == 25, "un batiment a 3-4-5 : 25")
  check(Ar.nearest_d2({ { x = 30, y = 0 }, { x = 6, y = 0 }, { x = -10, y = 0 } }, 0, 0) == 36, "le plus proche des trois : 36")
  check(Ar.nearest_d2({ { x = 6, y = 8 }, { x = 0, y = 0 } }, 0, 0) == 0, "debout sur un batiment : 0")
  -- arrivee : cas mesures
  check(Ar.arrived("service", 5 * 5) and Ar.arrived("service", 7 * 7), "service a 5 et 7 tuiles (cas mesures a 4 a 7) : arrive")
  check(Ar.arrived("extend", 6 * 6) and Ar.arrived("fortify", 6 * 6), "extend et fortify : arrives")
  check(Ar.arrived("service", 64) and not Ar.arrived("service", 65), "limite a 8 tuiles : 64 oui, 65 non")
  check(not Ar.arrived("service", 38 * 38) and not Ar.arrived("service", 27 * 27), "27 et 38 tuiles : pas arrive")
  check(not Ar.arrived("build", 1) and not Ar.arrived("carry", 1) and not Ar.arrived(nil, 1), "autre tache : jamais")
  check(not Ar.arrived("service", nil), "avant-poste sans batiment : pas arrive")
  check(Ar.NEAR == 8, "seuil de 8 tuiles")
  -- immobilite
  local st, due = Ar.still(nil, 10, 10, 0)
  check(st and st.t == 0 and due == false, "premier relevé : horloge posée")
  st, due = Ar.still(st, 10.2, 10, Ar.STILL_TICKS - 1)
  check(due == false and st.t == 0, "119 s immobile : pas encore")
  local st2, due2 = Ar.still(st, 10.2, 10, Ar.STILL_TICKS)
  check(due2 == true and st2.t == Ar.STILL_TICKS, "2 min immobile : dégagé, horloge remise")
  local st3, due3 = Ar.still(st, 12, 10, Ar.STILL_TICKS)
  check(due3 == false and st3.t == Ar.STILL_TICKS and st3.x == 12, "il a bougé de 2 tuiles : horloge remise, pas dégagé")
  check(select(2, Ar.still({ x = 0, y = 0, t = 0 }, 0.5, 0, Ar.STILL_TICKS)) == false, "0,5 tuile = bougé")
  check(Ar.STILL_TICKS == 7200 and Ar.UNSTICK_MAX == 3 and Ar.GOAL_NEAR == 12, "constantes : 2 min, 3 dégagements, 12 tuiles")
  check(Ar.free_due(100, 0) and Ar.free_due(144, 2) and not Ar.free_due(145, 0), "près du but (12 tuiles) : dégager")
  check(not Ar.free_due(100, 3) and not Ar.free_due(nil, 0), "3 dégagements faits ou but inconnu : non")
  return pass, fail, msgs
end

local pass, fail, msgs = suite(load_ar(SRC))
local function chk(c, m) if c then pass = pass + 1 else fail = fail + 1; msgs[#msgs + 1] = m end end
local worker, outposts = read("script/team/worker.lua"), read("script/faction/outposts.lua")
local function has(s, t) return s:find(t, 1, true) ~= nil end
chk(has(worker, 'local Ar = require("shared.team.arrivee")'), "worker.lua lit la regle")
chk(has(worker, 'Ar.KINDS[agent.task.kind]') and has(worker, "Ar.arrived(agent.task.kind, Outposts.nearest_d2(o, ep.x, ep.y))"), "worker.lua : nav_failed interroge la regle")
chk(has(worker, "agent.pc = agent.pc + 1\n            set(agent, \"step\", tick)\n            return"), "worker.lua : la tache continue a l'etape suivante")
chk(has(worker, "f.stats.nav_arrived = (f.stats.nav_arrived or 0) + 1"), "worker.lua : arrivees comptees")
chk(has(outposts, "function Outposts.nearest_d2(o, x, y)") and has(outposts, "Ar.nearest_d2(pts, x, y)"), "outposts.lua : distance au batiment le plus proche")
-- l'arrivee est testee AVANT le crochet IA3-k et l'abandon
chk(has(worker, "Ar.still(agent.still, ent.position.x, ent.position.y, tick)") and has(worker, "Ar.free_due("), "worker.lua : immobilité et chemin refusé près du but")
chk(has(worker, "[FO-DEGAGE]") and has(worker, "find_non_colliding_position(e.name, p, Ar.FREE_RADIUS, 0.25)"), "worker.lua : dégagement journalisé vers la case libre")
chk(has(worker, "agent.unstick_n, agent.still = nil, nil"), "worker.lua : compteur remis à zéro par tâche")
local i_ar = worker:find("Ar.arrived(agent.task.kind", 1, true)
local i_hook = i_ar and worker:find("local H = Worker.hook", i_ar, true)
local i_abort = i_hook and worker:find('abort(agent, f, tick, "chemin")', i_hook, true)
chk(i_ar and i_hook and i_abort and i_ar < i_hook and i_hook < i_abort, "ordre : arrivee, puis crochet IA3-k, puis abandon")

local mutants, caught = 0, 0
local function mutant(label, edit)
  mutants = mutants + 1
  local src = edit(SRC)
  local ok, Ar = pcall(load_ar, src)
  local _, f = 0, 1
  if ok then local ok2, _p, ff = pcall(suite, Ar); if ok2 then f = ff end end
  if f > 0 then caught = caught + 1 else print("  MUTANT SURVIVANT : " .. label) end
end
local function sub(s, a, b) local i, j = s:find(a, 1, true); assert(i, a); return s:sub(1, i - 1) .. b .. s:sub(j + 1) end
mutant("seuil a 30 tuiles", function(s) return sub(s, "Ar.NEAR = 8 ", "Ar.NEAR = 30 ") end)
mutant("seuil a 2 tuiles", function(s) return sub(s, "Ar.NEAR = 8 ", "Ar.NEAR = 2 ") end)
mutant("limite exclue", function(s) return sub(s, "d2 <= Ar.NEAR * Ar.NEAR", "d2 < Ar.NEAR * Ar.NEAR") end)
mutant("toute tache", function(s) return sub(s, "return Ar.KINDS[kind] == true and d2 ~= nil", "return d2 ~= nil") end)
mutant("sans batiment : arrive", function(s) return sub(s, "and d2 ~= nil and", "and") end)
mutant("service retire", function(s) return sub(s, "service = true, ", "") end)
mutant("extend retire", function(s) return sub(s, "extend = true, ", "") end)
mutant("fortify retire", function(s) return sub(s, "fortify = true ", "") end)
mutant("le plus lointain", function(s) return sub(s, "if best == nil or d2 < best then", "if best == nil or d2 > best then") end)
mutant("immobile: jamais", function(s) return sub(s, "if tick - prev.t >= Ar.STILL_TICKS then", "if false then") end)
mutant("immobile: horloge jamais remise", function(s) return sub(s, "STILL_MOVE then return { x = x, y = y, t = tick }, false end", "STILL_MOVE then return prev, false end") end)
mutant("immobile: 10 min", function(s) return sub(s, "Ar.STILL_TICKS = 2 * 3600", "Ar.STILL_TICKS = 10 * 3600") end)
mutant("coince: sans borne", function(s) return sub(s, "and (done or 0) < Ar.UNSTICK_MAX", "") end)
mutant("coince: loin du but", function(s) return sub(s, "Ar.GOAL_NEAR = 12", "Ar.GOAL_NEAR = 200") end)
mutant("distance non carree", function(s) return sub(s, "local d2 = dx * dx + dy * dy", "local d2 = dx + dy") end)

for _, m in ipairs(msgs) do print("  ECHEC : " .. m) end
print(string.format("[PLATEAU3] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refuses", pass, fail, caught, mutants))
os.exit((fail == 0 and caught == mutants) and 0 or 1)
