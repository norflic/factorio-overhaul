--[[
  Lot PIQUAGE-DELAI (directive du DC du 8/11, vers 18 h 45 : « pourquoi avoir attendu 2h30 ? [...] dès que la technologie est disponible et qu'un besoin est mesuré [...]
  que ces liaisons automatisées remplacent les trajets manuels dès la première heure »). Mesures sur le journal de la partie du DC (0.6.71, fo-logs/2026-11-08_PARTIE-DC-0671) :
    - bilans [FO-PIQUAGE] : 100 à 230 objets par tournée « fill » (jamais les 340 de Build.QUAI_FILL - QUAI_LOW que le prix supposait) ;
    - amber, quai 10:q1 (cuivre en câble, 0,85/s, à 22 tuiles du QG) <- sortie 31:o1 à 33 tuiles : « retour 101 min > 90 min » de 64,2 à 153 min (89 min de refus) ;
    - la tournée « fill » d'un quai est à la priorité de son module + 3 (58), la liaison qui la supprime était à 56.
  §1 Li.worth lit la charge MESURÉE du quai (tours >= Li.MIN_TOURS), jamais au-dessus de la charge permise ; §2 le cas d'amber passe sous 90 min avec la charge mesurée
  du journal, et reste refusé sans mesure ; §3 Pq.worth et Pq.rank la transmettent ; §4 Li.prio ; §5 branchement (texte) ; §6 mutants.
  Usage : lua5.2 tests/piquage_delai_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end

local function load_mod(path, deps)
  local src = read(path)
  return src
end

local LI_SRC = read("shared/team/liaison.lua")
local PQ_SRC = read("shared/team/piquage.lua")
local function modules(li_src)
  local saved = package.loaded["shared.team.liaison"]
  local Li = assert(load(li_src or LI_SRC, "@liaison", "t", setmetatable({}, { __index = _G })))()
  package.loaded["shared.team.liaison"] = Li
  local Pq = assert(load(PQ_SRC, "@piquage", "t", setmetatable({}, { __index = _G })))()
  package.loaded["shared.team.liaison"] = saved
  return Li, Pq
end

local AMBER = { flow = 0.845, dist = 22, span = 33, fill = 400, low = 60 } -- journal : « retour 101 min > 90 min (2.31 PNJ-s/min, 45 tuiles, cout 83) »

local function suite(Li, Pq)
  local bad = {}
  local function c(cond, m) if not cond then bad[#bad + 1] = m end end
  -- 1. le modèle d'avant reproduit le journal (101 min, 2,31 PNJ-s/min, 45 tuiles, coût 83)
  local ok0, why0, d0 = Li.worth(AMBER)
  c(not ok0 and math.floor(d0.payback_min + 0.5) == 101 and d0.tiles == 45 and math.abs(d0.labor_s_min - 2.31) < 0.01, "sans mesure : le cas d'amber redonne 101 min (" .. tostring(d0.payback_min) .. ")")
  c(d0.measured == false and d0.per_trip == 340, "sans mesure : charge de 340")
  -- 2. avec la charge mesurée
  local function with(tours, load) local t = {} for k, v in pairs(AMBER) do t[k] = v end t.tours, t.load = tours, load return Li.worth(t) end
  local ok1, _, d1 = with(10, 150)
  c(ok1 and d1.payback_min < 90 and d1.measured and d1.per_trip == 150, "charge mesurée de 150 sur 10 tournées : le retour passe sous 90 min (" .. tostring(d1.payback_min) .. ")")
  c(math.abs(d1.payback_min - d0.payback_min * 150 / 340) < 1e-6, "le retour est proportionnel à la charge")
  local ok2 = with(2, 150)
  c(not ok2, "sous 3 tournées (Li.MIN_TOURS) : la mesure n'est pas crue")
  local ok3, _, d3 = with(10, 900)
  c(not ok3 and d3.per_trip == 340 and not d3.measured, "une charge mesurée au-dessus de la charge permise ne l'augmente pas")
  local _, _, d4 = with(10, 0)
  c(d4.per_trip == 340, "charge nulle : ignorée")
  local ok5 = with(10, 230)
  c(ok5 == false or select(3, with(10, 230)).payback_min < d0.payback_min, "une charge plus proche de 340 donne un retour plus proche")
  -- 3. Pq.worth et Pq.rank transmettent la mesure
  local okp0 = Pq.worth({ flow = 0.85, dist = 22, span = 6, fill = 400, low = 60 })
  local pw = Pq.worth({ flow = 0.85, dist = 22, span = 6, fill = 400, low = 60, tours = 10, load = 100 })
  local _, _, pd0 = Pq.worth({ flow = 0.85, dist = 22, span = 6, fill = 400, low = 60 })
  local _, _, pd1 = Pq.worth({ flow = 0.85, dist = 22, span = 6, fill = 400, low = 60, tours = 10, load = 100 })
  c(pd1.payback_min < pd0.payback_min and pd1.trips_min > pd0.trips_min, "Pq.worth : la charge mesurée augmente les tournées économisées")
  local dock = { key = "9:q1", item = "copper-cable", flow = 0.85, dist = 22, fill = 400, low = 60 }
  local outs = { { key = "31:o1", span = 33 } }
  local r0 = Pq.rank(dock, {}, outs, {})
  dock.tours, dock.load = 10, 150
  local r1 = Pq.rank(dock, {}, outs, {})
  c(r0[1] and r1[1] and r0[1].ok == false and r1[1].ok == true, "Pq.rank : la sortie à 33 tuiles ne se paie pas sans mesure, se paie avec (101 contre " .. tostring(r1[1] and r1[1].payback) .. ")")
  -- 4. priorité
  c(Li.prio(56, 55) == 58 and Li.prio(56, 63) == 66 and Li.prio(70, 55) == 70 and Li.prio(56, nil) == 56, "Li.prio : au moins la tournée du module (module + 3)")
  return bad
end

do
  local Li, Pq = modules()
  local bad = suite(Li, Pq)
  check(#bad == 0, "§1 à §4 : " .. table.concat(bad, " ; "))
  -- équivalence : sans mesure, rien ne change pour les appels d'avant (aucun champ tours/load)
  local _, w0 = Li.worth({ flow = 0.845, dist = 22, span = 33, fill = 400, low = 60 })
  check(w0:find("retour 101 min > 90 min (2.31 PNJ-s/min economisees, 45 tuiles, cout 8", 1, true) == 1, "texte du journal inchangé sans mesure : " .. tostring(w0))
end

-- §5 branchement (texte)
do
  local LIA, PIQ = read("script/team/liaison.lua"), read("script/team/piquage.lua")
  check(LIA:find("tours = q.tours or 0, load = (q.tours or 0) > 0 and (q.filled or 0) / q.tours or nil", 1, true) ~= nil, "5.1 liaison : le quai porte sa charge mesurée")
  check(LIA:find("tours = d.tours, load = d.load })", 1, true) ~= nil, "5.2 liaison : Ln.worth la reçoit")
  check(LIA:find("prio = Ln.prio(api.prio, dp and dp.prio)", 1, true) ~= nil, "5.3 liaison : priorité de la tournée remplacée")
  check(PIQ:find("tours = q.tours or 0, load = (q.tours or 0) > 0 and (q.filled or 0) / q.tours or nil", 1, true) ~= nil, "5.4 piquage : le quai porte sa charge mesurée")
  check(PIQ:find("tours = d.tours, load = d.load })", 1, true) ~= nil and PIQ:find("tours = lc.tours, load = lc.load })", 1, true) ~= nil,
    "5.5 piquage : le choix et le prix du tracé la reçoivent (même décision à la demande et au plan)")
  check(PIQ:find("flow = d.flow, tours = d.tours, load = d.load, arm = arm", 1, true) ~= nil, "5.6 piquage : la mesure voyage dans la demande")
  check(PIQ:find("prio = Li.prio(api.prio, dp and dp.prio)", 1, true) ~= nil, "5.7 piquage : priorité de la tournée remplacée")
  local PQ = read("shared/team/piquage.lua")
  check(select(2, PQ:gsub("tours = dock.tours, load = dock.load", "")) >= 2 and PQ:find("tours = inp.tours, load = inp.load", 1, true) ~= nil, "5.8 Pq.worth et Pq.rank transmettent la mesure")
end

-- §6 mutants
local function mutant(label, a, b)
  local s, n = LI_SRC:gsub(a, function() return b end, 1)
  if n == 0 then check(false, "6 mutant introuvable : " .. label) return end
  local ok, Li, Pq = pcall(modules, s)
  local refused = not ok
  if ok then local bad = suite(Li, Pq); refused = #bad > 0 end
  check(refused, "6 mutant refusé : " .. label)
end
mutant("mesure ignorée", "if %(inp%.tours or 0%) >= Li%.MIN_TOURS", "if false and (inp.tours or 0) >= Li.MIN_TOURS")
mutant("une seule tournée suffit", "Li%.MIN_TOURS = 3", "Li.MIN_TOURS = 0")
mutant("charge mesurée au-dessus du permis", "and inp%.load < per_trip then", "then")
mutant("priorité sans bonus", "return math%.max%(base or 0, %(dock_prio or 0%) %+ Li%.CARRY_BONUS%)", "return base or 0")
mutant("bonus de 1", "Li%.CARRY_BONUS = 3", "Li.CARRY_BONUS = 1")

print(string.format("[PIQUAGE-DELAI] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
