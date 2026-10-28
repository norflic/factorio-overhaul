--[[
  Tests hors jeu du lot PLANDIR (T2) : bras de la centrale (shared/team/bras.lua) et choix du bras dans les données
  (shared/team/modules.lua : M.BURNER_ARM, M.ELECTRIC_ARMS, M.electric_arm). Usage :   lua5.2 tests/bras_test.lua
]]
package.path = "./?.lua;" .. package.path
local B = require("shared.team.bras")
local M = require("shared.team.modules")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

section("1. Données : bras à combustion et bras électriques")
check(M.BURNER_ARM == "burner-inserter", "le bras à combustion est lu dans les données")
check(#M.ELECTRIC_ARMS == 2 and M.ELECTRIC_ARMS[1] == "inserter" and M.ELECTRIC_ARMS[2] == "fast-inserter",
  "bras électriques de portée 1, du plus lent au plus rapide (le bras long est exclu)")
local all = function() return true end
check(M.electric_arm(all, 0.3) == "inserter", "0,3 objet/s : le bras simple")
check(M.electric_arm(all, 1.2) == "fast-inserter", "1,2 objet/s : le bras rapide")
check(M.electric_arm(function(n) return n == "inserter" end, 1.2) == "inserter", "seul le simple ouvert : le simple, même trop lent")
check(M.electric_arm(function(n) return n == "fast-inserter" end, 0.3) == "fast-inserter", "seul le rapide ouvert : le rapide")
check(M.electric_arm(function() return false end, 0.3) == nil, "aucun ouvert : nil")
local g = M.GEN.steam(1)
local burners, electric = 0, 0
for _, e in ipairs(g.entities) do
  if e.name == M.BURNER_ARM then burners = burners + 1 elseif M.spec(e.name).kind == "inserter" then electric = electric + 1 end
end
check(burners == 2 and electric == 0, "la centrale démarre avec deux bras à combustion par chaudière (" .. burners .. ")")

section("2. Machine à états")
local function run(seq, arms)
  local st = B.new()
  local acts, tick = {}, 0
  for _, o in ipairs(seq) do
    tick = tick + B.EVERY
    local a = B.observe(st, { power = o.p, dry = o.dry, arms = o.arms or arms or 3 }, tick)
    if a then acts[#acts + 1] = { a, tick }; B.applied(st, a, 3, tick) end
  end
  return st, acts, tick
end
local function rep(n, o) local t = {} for i = 1, n do t[i] = o end return t end
local function cat(...) local t = {} for _, l in ipairs({ ... }) do for _, x in ipairs(l) do t[#t + 1] = x end end return t end

local st, acts = run(rep(B.LIVE_CHECKS - 1, { p = 900 }))
check(#acts == 0 and st.mode == "burner", "pas de passage avant " .. B.LIVE_CHECKS .. " relevés de production")
st, acts = run(rep(B.LIVE_CHECKS, { p = 900 }))
check(#acts == 1 and acts[1][1] == "upgrade" and st.mode == "electric", "passage à l'électrique au relevé " .. B.LIVE_CHECKS)
st, acts = run(cat(rep(2, { p = 900 }), { { p = 0 } }, rep(3, { p = 900 })))
check(#acts == 1 and acts[1][1] == "upgrade", "un relevé sans production remet le compte à zéro")
st, acts = run(rep(10, { p = 900 }), 0)
check(#acts == 0 and st.mode == "burner", "aucun bras électrique au coffre : la centrale reste à combustion")
st, acts = run(cat(rep(5, { p = 900 }), rep(B.DEAD_CHECKS - 1, { p = 0, dry = true })))
check(#acts == 1 and st.mode == "electric", "panne trop courte (" .. B.DEAD_CHECKS - 1 .. " relevés) : pas de retour")
st, acts = run(cat(rep(5, { p = 900 }), rep(B.DEAD_CHECKS, { p = 0, dry = true })))
check(#acts == 2 and acts[2][1] == "revert" and st.mode == "burner" and st.reverts == 1, "panne verrouillée (courant nul, chaudière à sec) : retour à la combustion")
st, acts = run(cat(rep(5, { p = 900 }), rep(40, { p = 0, dry = false })))
check(#acts == 1 and st.mode == "electric", "courant nul mais chaudière garnie (aucune demande) : pas de retour")
-- après le retour : maintien de B.HOLD ticks, puis nouveau passage
local st2 = B.new()
local tick = 0
local function obs(o) tick = tick + B.EVERY; local a = B.observe(st2, o, tick); if a then B.applied(st2, a, 2, tick) end return a end
for _ = 1, B.LIVE_CHECKS do obs({ power = 1, arms = 3 }) end
for _ = 1, B.DEAD_CHECKS do obs({ power = 0, dry = true, arms = 3 }) end
check(st2.mode == "burner" and st2.hold_until == tick + B.HOLD, "retour à la combustion : maintien de " .. B.HOLD .. " ticks")
local early
for _ = 1, B.LIVE_CHECKS + 2 do early = obs({ power = 900, arms = 3 }) or early end
check(early == nil and st2.mode == "burner", "pendant le maintien : pas de nouveau passage")
tick = st2.hold_until
local late
for _ = 1, B.LIVE_CHECKS do late = obs({ power = 900, arms = 3 }) or late end
check(late == "upgrade" and st2.mode == "electric", "après le maintien : nouveau passage")
-- action sans effet (aucun bras remplacé) : état inchangé
local st3 = B.new()
B.applied(st3, "upgrade", 0, 0)
check(st3.mode == "burner" and st3.upgrades == 0, "aucun bras remplacé : l'état ne change pas (l'action sera redemandée)")

-- mutants
section("3. Mutants")
local saved = B.DEAD_CHECKS
B.DEAD_CHECKS = 0
local _, a_mut = run(cat(rep(5, { p = 900 }), rep(1, { p = 900 })))
check(#a_mut >= 2, "mutant « retour sans panne » : détecté (retour parasite)")
B.DEAD_CHECKS = saved
local obs_mut = B.observe
B.observe = function(s, o, t) o.dry = true; return obs_mut(s, o, t) end
local _, a2 = run(cat(rep(5, { p = 900 }), rep(40, { p = 0, dry = false })))
check(#a2 == 2, "mutant « chaudière toujours à sec » : le retour parasite est vu par le test « chaudière garnie »")
B.observe = obs_mut

print(string.format("[BRAS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
