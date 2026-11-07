--[[
  Lot X10-S10 « factions lointaines plus lentes », au moteur simulé (tests/mock_engine.lua) : le VRAI Commander.think (créneaux de la voie
  fo-commander, période 300) et le guet par tick (script/faction/commander.lua). Ce n'est pas une preuve en jeu ; la mesure du gain se
  fera avec M3, sur PC calme.
    §1 joueur LOIN, rien ne menace : les pensées d'une faction sont espacées de Cd.SLOW (600) ticks ; journal [FO-CADENCE] « LENTE » ;
    §2 RÉVEIL : le joueur entre dans la zone de la faction endormie : elle repense AU TICK SUIVANT (le premier tick joué après son
       arrivée), puis reprend la période de 300 tant qu'il reste ; journal « NORMALE (joueur proche) » ;
    §3 PERTE : une entité de la faction meurt loin de tout : la faction endormie repense au tick suivant (cause « perte ») ;
    §3 bis ARMÉE DEHORS (condition du lead) : une attaque en préparation (f.route_pending) tient la faction au rythme de 300 ;
    §4 votre équipe garde son rythme (aucune cadence posée sur elle) ; Commander.CADENCE faux : une pensée par créneau ;
    §5 mutant « jamais réveillée » (Cd.wake rend toujours faux) : le §2 échoue (la faction attend son créneau).
  Usage : lua5.2 tests/cadence_moteur_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1; if not quiet and os.getenv("FO_VERBOSE") then print("[CADENCE-MOTEUR] OK : " .. msg) end else failures = failures + 1; if not quiet then print("[CADENCE-MOTEUR] ECHEC : " .. msg) end end
  return cond
end
local function say(s) if not quiet then print("[CADENCE-MOTEUR] " .. s) end end
local function W() return M.world() end

M.new_world({ p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true })
M.load_mod()
M.dispatch(W().on_init)
local char = W().player.character
char.teleport({ x = 20000, y = 20000 }) -- le joueur loin de tout
M.command("fo-war", "start 2 30 30 320")
do
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 20005, y = 20005 }, force = "player" })
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
end

local Commander = require("script.faction.commander")
local Cd = require("shared.faction.cadence")
local f = global.fo.war.factions[1]
check(f and f.hq and f.hq.valid, "une faction avec son QG")

--- Joue n ticks et rend la liste des ticks où la faction a pensé (f.last_think change).
local function thinks_over(n)
  local out = {}
  local last = f.last_think
  for _ = 1, n do
    M.run_ticks(1)
    if f.last_think ~= last then out[#out + 1] = f.last_think last = f.last_think end
  end
  return out
end
local function logs_since(i0, pat)
  local out = {}
  for i = i0 + 1, #W().logs do local l = W().logs[i] if type(l) == "string" and l:find(pat, 1, true) then out[#out + 1] = l end end
  return out
end

local function scenes()
  -- Échauffement : la faction a pensé au moins une fois (zone relevée), plus d'alerte récente.
  M.run_ticks(2000)
  f.threatened_until, f.attack_alert_t, f.lost_t = 0, nil, nil
  char.teleport({ x = 20000, y = 20000 })
  -- §1 loin et calme.
  local i0 = #W().logs
  local th = thinks_over(2400)
  local gaps_ok, n = true, 0
  for i = 2, #th do
    n = n + 1
    if th[i] - th[i - 1] ~= Cd.SLOW then gaps_ok = false end
  end
  check(#th >= 3 and gaps_ok, "§1 : loin et calme : pensees espacees de " .. Cd.SLOW .. " ticks (" .. table.concat(th, " ") .. ")")
  local lente = logs_since(0, "[FO-CADENCE] " .. tostring(f.key) .. " : cadence LENTE")
  check(#lente >= 1, "§1 : journal [FO-CADENCE] « LENTE »")
  -- §2 réveil : attendre que la faction dorme (créneau sauté), puis amener le joueur à son QG.
  local guard = 0
  while not (f.cadence and f.cadence.asleep) and guard < 700 do M.run_ticks(1) guard = guard + 1 end
  check(f.cadence and f.cadence.asleep, "§2 : la faction dort (creneau saute)")
  local T = game.tick
  local before = f.last_think
  local i1 = #W().logs
  char.teleport({ x = f.hq_pos.x + 20, y = f.hq_pos.y })
  M.run_ticks(1)
  check(f.last_think == T + 1 and f.last_think ~= before, string.format("§2 : joueur arrive apres le tick %d : la faction repense au tick suivant (%s)", T, tostring(f.last_think)))
  local th2 = thinks_over(1300)
  local normal = #th2 >= 4
  for i = 2, #th2 do if th2[i] - th2[i - 1] > 300 then normal = false end end
  check(normal, "§2 : le joueur reste : rythme normal, aucun ecart au-dela de 300 (" .. table.concat(th2, " ") .. ")")
  local nor = logs_since(i1, "[FO-CADENCE] " .. tostring(f.key) .. " : cadence NORMALE (joueur proche)")
  check(#nor == 1, "§2 : journal « NORMALE (joueur proche) » (" .. #nor .. ")")
  -- §3 perte : le joueur repart, la faction se rendort, puis une de ses entités meurt.
  char.teleport({ x = 20000, y = 20000 })
  guard = 0
  while not (f.cadence and f.cadence.asleep) and guard < 1500 do M.run_ticks(1) guard = guard + 1 end
  check(f.cadence and f.cadence.asleep, "§3 : rendormie apres le depart du joueur")
  local T3 = game.tick
  f.lost_t = T3 -- (ce qu'écrit on_died pour toute entité de la faction : la mort elle-même est jouée par le moteur réel)
  M.run_ticks(1)
  check(f.last_think == T3 + 1, string.format("§3 : perte : la faction repense au tick suivant (%s, attendu %d)", tostring(f.last_think), T3 + 1))
  -- §3 bis armée dehors : le joueur reste loin, aucune alerte, mais une attaque est en préparation (itinéraire demandé).
  M.run_ticks(Cd.ALERT + 10)
  f.threatened_until, f.attack_alert_t, f.lost_t = 0, nil, nil
  local saved = f.route_pending
  f.route_pending = { ticket = -1, target_faction = -1, test = true }
  local th3 = thinks_over(1300)
  f.route_pending = saved
  local every = #th3 >= 4
  for i = 2, #th3 do if th3[i] - th3[i - 1] > 300 then every = false end end
  check(every, "§3 bis : armee dehors : rythme normal, aucun ecart au-dela de 300 (" .. table.concat(th3, " ") .. ")")
end

scenes()

-- §4 Votre équipe ; témoin éteint.
do
  local pf = global.fo.pteam and global.fo.pteam.team
  check(pf == nil or pf.cadence == nil, "§4 : votre equipe : aucune cadence posee")
  Commander.CADENCE = false
  char.teleport({ x = 20000, y = 20000 })
  f.threatened_until, f.attack_alert_t, f.lost_t = 0, nil, nil
  local th = thinks_over(1300)
  Commander.CADENCE = true
  local every = #th >= 4
  for i = 2, #th do if th[i] - th[i - 1] ~= 300 then every = false end end
  check(every, "§4 : CADENCE eteinte : une pensee par creneau de 300 (" .. table.concat(th, " ") .. ")")
end

-- §5 Mutant « jamais réveillée ».
do
  local o = Cd.wake
  Cd.wake = function() return false, nil end
  local p0, f0 = passes, failures
  quiet = true
  local ok, err = pcall(scenes)
  quiet = false
  Cd.wake = o
  local dead = (not ok) or failures > f0
  passes, failures = p0, f0
  print(string.format("[CADENCE-MOTEUR]   mutant jamais reveillee : %s", ok and (dead and "refuse" or "SURVIVANT") or ("PLANTAGE " .. tostring(err))))
  check(dead, "§5 : mutant « jamais reveillee » refuse")
end

print(string.format("[CADENCE-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
