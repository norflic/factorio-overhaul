--[[
  Sprint s43, scen-energie : tour d'évaluation du piquage (shared/team/piquage.lua, Pq.eval_turn, Pq.seen_lost) et son câblage dans
  script/team/piquage.lua (lu comme texte). Défaut : les EVAL_MAX quais prêts au plus fort débit monopolisaient l'évaluation à chaque relevé.
  Usage : lua5.2 tests/s43_scen-energie_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function read(path) local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s end

local Pq = require("shared.team.piquage")

-- 1. jamais évalués d'abord, dans l'ordre du débit
local ready = { "1:q1", "2:q1", "3:q1", "4:q1", "5:q1" }
local last = {}
local t = Pq.eval_turn(ready, last, 3)
check(t["1:q1"] and t["2:q1"] and t["3:q1"] and not t["4:q1"], "premier relevé : les trois premiers par débit")

-- 2. simulation de relevés : chaque quai prêt est évalué en au plus ceil(N / quota) relevés (l'ancien code : jamais pour 4 et 5)
local seen_eval = {}
for tick = 1, 4 do
  local turn = Pq.eval_turn(ready, last, 3)
  for _, k in ipairs(ready) do if turn[k] then last[k] = tick; seen_eval[k] = (seen_eval[k] or 0) + 1 end end
end
for _, k in ipairs(ready) do check((seen_eval[k] or 0) >= 2, "quai " .. k .. " évalué au moins deux fois en 4 relevés (" .. tostring(seen_eval[k]) .. ")") end
local turn2 = Pq.eval_turn(ready, { ["1:q1"] = 9 }, 3)
check(turn2["2:q1"] and turn2["3:q1"] and turn2["4:q1"] and not turn2["1:q1"], "le quai évalué le plus récemment passe après")
check(next(Pq.eval_turn({}, {}, 3)) == nil, "aucun quai prêt : rien")
-- déterminisme : même entrée, même sortie
local a, b = Pq.eval_turn(ready, { ["3:q1"] = 2, ["1:q1"] = 2 }, 2), Pq.eval_turn(ready, { ["3:q1"] = 2, ["1:q1"] = 2 }, 2)
check(a["2:q1"] and a["4:q1"] and b["2:q1"] and b["4:q1"], "déterministe (égalité : ordre du débit)")

-- 3. confirmation : gardée pour un quai non évalué, perdue pour un quai évalué sans la paire
check(Pq.seen_lost("4:q1>10:-3", {}, { ["1:q1"] = true }) == false, "paire d'un quai non évalué : confirmation gardée")
check(Pq.seen_lost("4:q1>10:-3", {}, { ["4:q1"] = true }) == true, "paire d'un quai évalué, non revue : confirmation perdue")
check(Pq.seen_lost("4:q1>10:-3", { ["4:q1>10:-3"] = true }, { ["4:q1"] = true }) == false, "paire revue : gardée")

-- 4. câblage
local S = read("script/team/piquage.lua")
check(S:find("Pq.eval_turn(ready0, st.evald, Piquage.EVAL_MAX)", 1, true) ~= nil, "finish_cycle calcule le tour d'évaluation")
check(S:find("and not asked and eturn[d.key] then", 1, true) ~= nil, "l'évaluation suit le tour")
check(S:find("st.evald[d.key], evaluated[d.key] = tick, true", 1, true) ~= nil, "l'évaluation est datée")
check(S:find("Pq.seen_lost(k, seen_now, evaluated)", 1, true) ~= nil, "la confirmation ne se perd que pour un quai évalué")
check(S:find('{ "track", "disc", "evald" }', 1, true) ~= nil, "les dates d'évaluation sont purgées avec le quai")

-- 5. déclaration du blackout au format déclaratif, et jugement sur des relevés fictifs
local F = require("shared.scenarios.format")
local B = require("shared.scenarios.blackout_centrale")
check(F.valider(B) == nil, "blackout_centrale valide au format (" .. tostring(F.valider(B)) .. ")")
check(F.ACTIONS.assecher_centrale == true, "action assecher_centrale connue du format")
local bad = { nom = "x", duree_min = 3, description = { fr = "a", en = "b" }, mise_en_scene = { { minute = 1, action = "assecher_centrale", tapis_coupes = 1.5 } },
  theorie = { { id = "a", predicat = { type = "seuil", champ = "c", minute = 1, op = ">=", valeur = 0 } } } }
check(F.valider(bad) ~= nil, "tapis_coupes non entier refusé")
local function rel(sat_after, dry_after)
  local r = {}
  for m = 1, B.duree_min do
    if m < 25 then r[m] = { elec_sat = 0.98, elec_kw = 900, chaudieres_a_sec = 0 }
    elseif m == 25 then r[m] = { elec_sat = 0.1, elec_kw = 0, chaudieres_a_sec = 2 }
    else r[m] = { elec_sat = sat_after(m), elec_kw = 500, chaudieres_a_sec = dry_after(m) } end
  end
  return r
end
local function verdicts(r)
  local out = {}
  for _, att in ipairs(B.theorie) do out[att.id] = F.juger(att.predicat, r) end
  return out
end
local good = verdicts(rel(function(m) return m >= 28 and 0.97 or 0.3 end, function(m) return m >= 27 and 0 or 2 end))
check(good["centrale-en-marche"] == "OK" and good["coupe-posee"] == "OK" and good["chaudieres-rallumees"] == "OK"
  and good["satisfaction-revenue"] == "OK" and good["satisfaction-tenue"] == "OK", "retour en 3 min : tous les attendus OK")
local badv = verdicts(rel(function() return 0.2 end, function() return 2 end))
check(badv["satisfaction-revenue"] == "ECHEC" and badv["chaudieres-rallumees"] == "ECHEC", "aucun retour : ECHEC")

-- 6. scénarios de crise déclarés (fichiers du banc)
for _, n in ipairs({ "scen-blackout", "scen-blackout-centrale", "scen-bus-goulot" }) do
  local ok = io.open("tools/autotest/fo-autotest/scenarios/" .. n .. ".lua", "rb")
  check(ok ~= nil, "scénario " .. n .. " présent")
  if ok then ok:close() end
end

print(string.format("s43_scen-energie : %d OK, %d ECHEC", ok_n, fail_n))
if fail_n > 0 then os.exit(1) end
