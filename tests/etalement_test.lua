--[[
  Étalement des créneaux de l'ordonnanceur (lot OUTILLAGE, 28/10) : shared/core/etalement.lua (règle pure) puis
  script/core/scheduler.lua (option `spread`) sur le moteur simulé.
  Usage, depuis la racine du mod :   lua5.2 tests/etalement_test.lua   ->   [ETALEMENT] BILAN : n OK
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

---------------------------------------------------------------------------------------------------
-- 1. Règle pure : écarts des créneaux de n ids, comparés à la force brute sur de petites périodes
---------------------------------------------------------------------------------------------------
-- Écarts circulaires entre créneaux distincts triés ; rend (plus petit écart, plus grand écart, nb de créneaux distincts).
local function ecarts(slots, P)
  local seen, list = {}, {}
  for _, s in ipairs(slots) do
    if not seen[s] then seen[s] = true; list[#list + 1] = s end
  end
  table.sort(list)
  if #list == 1 then return P, P, 1 end
  local mn, mx = P, 0
  for i = 1, #list do
    local nxt = list[i % #list + 1]
    local g = (nxt - list[i]) % P
    if g == 0 then g = P end
    if g < mn then mn = g end
    if g > mx then mx = g end
  end
  return mn, mx, #list
end

-- Force brute : meilleur plus petit écart possible de n créneaux parmi P (tous les sous-ensembles de n créneaux).
local function meilleur_min(P, n)
  local best = 0
  local pick = {}
  local function rec(from, k)
    if k == n then
      local mn = ecarts(pick, P)
      if mn > best then best = mn end
      return
    end
    for s = from, P do
      pick[k + 1] = s
      rec(s + 1, k + 1)
    end
    pick[k + 1] = nil
  end
  rec(1, 0)
  return best
end

local function verifier(E, label)
  local f0 = failures
  -- valeurs connues (période 300 des factions et de votre équipe)
  local att = { 0, 150, 75, 225, 37, 187, 112, 262 }
  local ok = true
  for r = 0, 7 do if E.decalage(r, 300) ~= att[r + 1] then ok = false end end
  check(ok, label .. " : décalages 0, 150, 75, 225, 37, 187, 112, 262 sur 300")
  check(E.creneau(0, 300) == 1 and E.creneau(1, 300) == 151 and E.creneau(0, 300, 37) == 38,
        label .. " : créneaux 1-indexés, phase tournante")
  check(E.creneau(1, 300, 200) == (150 + 200) % 300 + 1, label .. " : phase modulo la période")
  -- jamais hors de 1..P, aucun créneau pour deux rangs d'une même série tant que n <= 256 (P = 300)
  local seen, dup, hors = {}, 0, 0
  for r = 0, 255 do
    local s = E.creneau(r, 300)
    if s < 1 or s > 300 then hors = hors + 1 end
    if seen[s] then dup = dup + 1 end
    seen[s] = true
  end
  check(hors == 0 and dup == 0, label .. " : 256 rangs, 256 créneaux distincts dans 1..300")
  -- écarts : deux valeurs au plus, jamais plus du double de l'idéal ; exactement l'idéal pour n = 2^k
  for _, P in ipairs({ 7, 12, 60, 64, 300 }) do
    for n = 2, 16 do
      local k = 0
      while 2 ^ (k + 1) <= n do k = k + 1 end
      -- Domaine : écart idéal d'au moins un tick (2^(k+1) <= P) ; au-delà, des ids partagent un créneau (autorisé : un créneau
      -- est une liste), la règle n'est pas faite pour des voies à plus de P/2 ids.
      if 2 ^ (k + 1) <= P then
        local slots = {}
        for r = 0, n - 1 do slots[#slots + 1] = E.creneau(r, P) end
        local mn, mx, d = ecarts(slots, P)
        local grand = math.ceil(P / 2 ^ k)
        local petit = math.floor(P / 2 ^ (k + 1))
        check(d == n and mx <= grand and mn >= petit,
              string.format("%s : P=%d n=%d : écarts %d..%d dans [%d, %d]", label, P, n, mn, mx, petit, grand))
        if 2 ^ k == n and P % n == 0 then
          check(mn == P / n and mx == P / n, string.format("%s : P=%d n=%d (puissance de 2) : écart idéal %d", label, P, n, P / n))
        end
      end
    end
  end
  -- contre la force brute : plus petit écart >= la moitié de l'optimum, et optimum atteint pour n = 2^k
  for _, c in ipairs({ { 12, 2 }, { 12, 3 }, { 12, 4 }, { 16, 4 }, { 10, 3 }, { 13, 5 } }) do
    local P, n = c[1], c[2]
    local slots = {}
    for r = 0, n - 1 do slots[#slots + 1] = E.creneau(r, P) end
    local mn = ecarts(slots, P)
    local opt = meilleur_min(P, n)
    check(2 * mn + 1 >= opt, string.format("%s : force brute P=%d n=%d : écart mini %d contre l'optimum %d", label, P, n, mn, opt))
    if n == 2 or n == 4 then
      check(mn >= opt - 1, string.format("%s : force brute P=%d n=%d (puissance de 2) : %d contre l'optimum %d", label, P, n, mn, opt))
    end
  end
  -- le cas du jeu : 4 factions puis votre équipe, période 300 : 5 créneaux distincts, écart mini >= 37
  local slots = {}
  for r = 0, 4 do slots[#slots + 1] = E.creneau(r, 300) end
  local mn = ecarts(slots, 300)
  check(mn >= 37, label .. " : 4 factions + 1 : écart mini " .. mn .. " >= 37 ticks")
  return failures == f0
end

local E = require("shared.core.etalement")
verifier(E, "règle")

---------------------------------------------------------------------------------------------------
-- 2. Mutants de la règle : chacun doit être refusé
---------------------------------------------------------------------------------------------------
local function source()
  local f = assert(io.open("shared/core/etalement.lua", "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = source()
local function mutant(nom, de, vers)
  local a, b = SRC:find(de, 1, true)
  check(a ~= nil, "mutant " .. nom .. " : motif trouvé")
  if not a then return end
  local src = SRC:sub(1, a - 1) .. vers .. SRC:sub(b + 1)
  local chunk = assert(load(src, "mutant-" .. nom, "t"))
  local Mu = chunk()
  local f0, p0 = failures, passes
  local sortie = print
  print = function() end -- les ECHEC du mutant sont attendus
  verifier(Mu, "mutant " .. nom)
  print = sortie
  local vus = failures - f0
  failures, passes = f0, p0 -- les échecs du mutant ne comptent pas comme des échecs du banc
  check(vus > 0, "mutant " .. nom .. " refusé (" .. vus .. " contrôle(s) en échec)")
end
mutant("consecutif", "return math.floor(Etalement.miroir(rang) * periode / TOUR)", "return rang % periode")
mutant("sans-phase", "return (Etalement.decalage(rang, periode) + (phase or 0)) % periode + 1",
       "return Etalement.decalage(rang, periode) % periode + 1")
mutant("zero-indexe", "return (Etalement.decalage(rang, periode) + (phase or 0)) % periode + 1",
       "return (Etalement.decalage(rang, periode) + (phase or 0)) % periode")
mutant("miroir-2-bits", "local BITS = 16", "local BITS = 2")
mutant("bit-inverse", "m = m * 2 + r % 2", "m = m * 2 + (1 - r % 2)")

---------------------------------------------------------------------------------------------------
-- 3. Ordonnanceur sur le moteur simulé : voie étalée
---------------------------------------------------------------------------------------------------
local M = require("tests.mock_engine")
local new_world, load_mod, run_ticks = M.new_world, M.load_mod, M.run_ticks
local W = setmetatable({}, { __index = function(_, k) return M.world()[k] end })

-- 3a. Quatre ids ajoutés : visites à 300 ticks exactement, créneaux aux décalages attendus.
new_world({ seed = 1 })
load_mod()
W.on_init()
local Scheduler = require("script.core.scheduler")
local visites = {}
local function noter(base)
  return function(id, tick)
    visites[base + id] = visites[base + id] or {}
    visites[base + id][#visites[base + id] + 1] = tick
  end
end
Scheduler.define_lane("t-spread", 300, noter(0), { spread = true })
Scheduler.define_lane("t-spread-phase", 300, noter(100), { spread = { phase = 37 } })
Scheduler.define_lane("t-rondes", 300, noter(200))
for i = 1, 4 do Scheduler.add("t-spread", i); Scheduler.add("t-rondes", i) end
Scheduler.add("t-spread-phase", 1)
run_ticks(900)
local ok_periode, ok_slots = true, true
local attendu = { 0, 150, 75, 225 }
for i = 1, 4 do
  local v = visites[i]
  if not v or #v < 3 then
    ok_periode = false
  else
    for j = 2, #v do if v[j] - v[j - 1] ~= 300 then ok_periode = false end end
    if v[1] % 300 ~= attendu[i] then ok_slots = false end
  end
end
check(ok_periode, "voie étalée : chaque id revient exactement tous les 300 ticks")
check(ok_slots, "voie étalée : les 4 premiers ids tombent aux ticks 0, 150, 75, 225 (mod 300)")
check(visites[101] and visites[101][1] % 300 == 37, "voie étalée avec phase 37 : tick 37 (mod 300)")
local consecutifs = true
for i = 1, 4 do
  if not visites[200 + i] or visites[200 + i][1] % 300 ~= i - 1 then consecutifs = false end
end
check(consecutifs, "voie sans option : tourniquet d'origine inchangé (ticks 0, 1, 2, 3)")

-- 3b. Sauvegarde d'avant l'étalement : créneaux consécutifs, sans signature -> ré-étalée une fois, ordre des rangs gardé.
local Storage = require("script.core.storage")
local st = Storage.ns("sched").lanes["t-spread"]
st.sig = nil
local b, so = {}, {}
for s = 1, 300 do b[s] = {} end
for i = 1, 4 do b[i][1] = i; so[i] = i end
st.buckets, st.slot_of, st.rr, st.count = b, so, 4, 4
for k in pairs(visites) do visites[k] = nil end
run_ticks(600)
local rang_ok = true
for i = 1, 4 do
  local v = visites[i]
  if not v or v[1] % 300 ~= attendu[i] then rang_ok = false end
end
check(rang_ok, "ancienne sauvegarde (créneaux 1, 2, 3, 4) : ré-étalée dans l'ordre des rangs (0, 150, 75, 225)")
check(st.sig == 1 and Scheduler.count("t-spread") == 4, "signature d'étalement posée, 4 ids gardés")

-- 3c. Stress avec ajouts et retraits pendant l'itération (mêmes invariants que tests/run.lua) sur une voie étalée.
for seed = 1, 5 do
  new_world({ seed = seed })
  load_mod()
  W.on_init()
  Scheduler = require("script.core.scheduler")
  local lane = "t-stress"
  local last, vis_tick, double, inexact = {}, {}, false, 0
  local live, live_list, next_id = {}, {}, 0
  local function add_one()
    next_id = next_id + 1
    Scheduler.add(lane, next_id)
    live_list[#live_list + 1] = next_id; live[next_id] = #live_list
  end
  local function drop(id)
    local pos = live[id]
    if not pos then return end
    local lastid = live_list[#live_list]
    live_list[pos] = lastid; live[lastid] = pos
    live_list[#live_list] = nil; live[id] = nil; last[id] = nil
  end
  Scheduler.define_lane(lane, 12, function(id, tick)
    if vis_tick[id] == tick then double = true end
    vis_tick[id] = tick
    if last[id] and tick - last[id] ~= 12 then inexact = inexact + 1 end
    last[id] = tick
    local r = math.random()
    if r < 0.03 then
      Scheduler.remove(lane, id); drop(id)
    elseif r < 0.065 then
      add_one()
    elseif r < 0.08 then
      Scheduler.remove(lane, id); drop(id); Scheduler.add(lane, id)
      live_list[#live_list + 1] = id; live[id] = #live_list
    end
  end, { spread = true })
  for _ = 1, 30 do add_one() end
  for _ = 1, 2000 do run_ticks(1) end
  check(not double and inexact == 0,
        "stress voie étalée (graine " .. seed .. ") : jamais deux passages, période exacte (" .. inexact .. " écarts)")
end

print(string.format("[ETALEMENT] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
