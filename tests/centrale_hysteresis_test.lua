--[[
  Lot VIDEO-L12, partie 2 : hystérésis de la saturation de la centrale (shared/team/centrale.lua, C.observe : entrée à C.SAT pendant
  C.SAT_CHECKS relevés, sortie sous C.SAT_EXIT). Lancer depuis la racine du mod :
    lua5.2 tests/centrale_hysteresis_test.lua   -> [L12B] BILAN : N OK, 0 ECHEC(S)
  Mutants : substitution unique dans le source, module rechargé ; la suite doit ÉCHOUER. Coût : instructions (debug.sethook).
]]
package.path = "./?.lua;" .. package.path
local PATH = "shared/team/centrale.lua"
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[L12B] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local SRC = read(PATH)
local CAP = 30000

local function str(l) local o = {} for i, v in ipairs(l) do o[i] = v and "S" or "-" end return table.concat(o) end
local function run(C, loads)
  local st, out = {}, {}
  for i, x in ipairs(loads) do out[i] = C.observe(st, x * CAP, CAP) end
  return out, st
end

local function suite(C)
  local bad = {}
  local function want(ok, msg) if not ok then bad[#bad + 1] = msg end end
  -- entrée inchangée : 6 relevés à 80 % ou plus
  local a = run(C, { 0.85, 0.85, 0.85, 0.85, 0.85, 0.85 })
  want(str(a) == "-----S", "entree au 6e releve a 85 % (" .. str(a) .. ")")
  local b = run(C, { 0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75 })
  want(str(b) == "-------", "75 % sans saturation prealable : jamais saturee (" .. str(b) .. ")")
  -- hystérésis : saturée, la centrale le reste entre 70 et 80 % ; elle sort sous 70 %
  local osc = { 0.85, 0.85, 0.85, 0.85, 0.85, 0.85, 0.75, 0.82, 0.72, 0.79, 0.71, 0.69, 0.75 }
  local o, so = run(C, osc)
  want(str(o) == "-----SSSSSS--", "oscillation 72-82 % : saturee tenue, sortie a 69 %, pas de retour a 75 % (" .. str(o) .. ")")
  want(so.sat == 0, "sortie : compte remis a zero")
  -- la durée de saturation (C.HOLD_PASS) avance pendant le maintien
  local long = {}
  for i = 1, C.HOLD_PASS + 6 do long[i] = (i <= 6) and 0.85 or ((i % 2 == 0) and 0.74 or 0.83) end
  local _, sl = run(C, long)
  want(sl.saturated and sl.sat >= C.HOLD_PASS, "maintien entre 70 et 80 % : la duree avance jusqu'a C.HOLD_PASS (" .. tostring(sl.sat) .. ")")
  local n = { done = 1, pending = 0, refused = 0, hold = true }
  want(C.growth(sl, n) ~= nil, "repli de l'equipe leve apres C.HOLD_PASS releves de saturation tenue")
  -- capacité nulle, production nulle : jamais saturée, même après une saturation
  local z = run(C, { 0.85, 0.85, 0.85, 0.85, 0.85, 0.85, 0 })
  want(str(z) == "-----S-", "production nulle apres saturation : sortie (" .. str(z) .. ")")
  local stc = {}
  for _ = 1, 8 do C.observe(stc, 100, 0) end
  want(not stc.saturated, "capacite nulle : jamais saturee")
  -- la demande partie remesure (le chantier ouvert retient la deuxième demande)
  local _, sr = run(C, { 0.85, 0.85, 0.85, 0.85, 0.85, 0.85 })
  C.requested(sr)
  want(sr.saturated == false and sr.sat == 0 and C.growth(sr, { done = 1, pending = 0, refused = 0 }) == nil,
    "apres la demande : a remesurer (aucune deuxieme demande avant 6 releves)")
  return bad
end

local C = require("shared.team.centrale")
local bad = suite(C)
for _, m in ipairs(bad) do check(false, m) end
check(#bad == 0, "suite")
do -- l'AVANT : un seul relevé sous 80 % effaçait la saturation (mesuré sur la règle d'avant, reconstituée)
  local old = { observe = function(st, power, capacity)
    if capacity > 0 and power >= C.SAT * capacity then st.sat = (st.sat or 0) + 1 else st.sat = 0 end
    st.saturated = st.sat >= C.SAT_CHECKS
    return st.saturated
  end }
  local osc = { 0.85, 0.85, 0.85, 0.85, 0.85, 0.85, 0.75, 0.82, 0.72, 0.79, 0.71, 0.69, 0.75 }
  local ob = run(old, osc)
  local nb = run(C, osc)
  local function tog(l) local k, p = 0, false for _, v in ipairs(l) do if v ~= p then k = k + 1 end p = v end return k end
  print(string.format("[L12B] oscillation 69-85 %% sur 13 releves : avant %s (%d bascule(s)), apres %s (%d bascule(s))", str(ob), tog(ob), str(nb), tog(nb)))
  check(tog(ob) == 2 and tog(nb) == 2 and str(ob) == "-----S-------", "avant : saturee un seul releve ; apres : tenue jusqu'a 69 %")
end

local MUT = {
  { "seuil unique (sortie a C.SAT)", "local lim = st.saturated and C.SAT_EXIT or C.SAT", "local lim = C.SAT" },
  { "jamais de sortie", "st.saturated = (st.saturated and st.sat > 0) or st.sat >= C.SAT_CHECKS", "st.saturated = st.saturated or st.sat >= C.SAT_CHECKS" },
  { "entree sans anti-rebond", "st.saturated = (st.saturated and st.sat > 0) or st.sat >= C.SAT_CHECKS", "st.saturated = st.sat > 0" },
  { "sortie trop basse (seuil de sortie 0)", "C.SAT_EXIT = 0.7", "C.SAT_EXIT = 0" },
  { "demande sans remesure", "  st.sat, st.saturated = 0, false\n", "" },
  { "capacite nulle comptee", "if capacity > 0 and power >= lim * capacity then", "if power >= lim * capacity then" },
}
local refused = 0
for _, m in ipairs(MUT) do
  local s, nsub = SRC:gsub(m[2]:gsub("%p", "%%%0"), (m[3]:gsub("%%", "%%%%")))
  if nsub ~= 1 then
    check(false, "mutant introuvable (" .. nsub .. ") : " .. m[1])
  else
    local ok, Cm = pcall(function() return assert(load(s, "=" .. PATH, "t", _ENV))() end)
    local ran, sb = false, nil
    if ok then ran, sb = pcall(suite, Cm) end
    local killed = (not ok) or (not ran) or (#sb > 0)
    if killed then refused = refused + 1 else print("[L12B] mutant NON refuse : " .. m[1]) end
    check(killed, "mutant refuse : " .. m[1])
  end
end
print(string.format("[L12B] mutants refuses : %d sur %d", refused, #MUT))

local worst, st, k = 0, {}, 0
for _ = 1, 200 do
  k = k + 1
  local c = 0
  debug.sethook(function() c = c + 1 end, "", 1)
  C.observe(st, ((k % 5) * 0.05 + 0.6) * CAP, CAP)
  debug.sethook()
  if c > worst then worst = c end
end
print(string.format("[L12B] cout : C.observe pire %d instructions (sethook, compte de 1)", worst))
check(worst <= 60, "cout borne : 60 instructions par releve (" .. worst .. ")")

print(string.format("[L12B] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
