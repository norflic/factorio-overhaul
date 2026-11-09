--[[
  Lot COUT-600 (9/11) : couverture d'un gisement par pensée (shared/ai3/cov_pas.lua), règles pures.
    1. Cp.covered rend EXACTEMENT le compte de la boucle d'avant (copiée ici, `old_covered`) sur des gisements et des foreuses tirés au hasard ;
    2. Cp.next_due : au plus un gisement par appel, le premier dû strictement après le curseur (cyclique), jamais deux lectures d'un même gisement
       à moins de `every` ticks, tout gisement présent est relu au moins une fois par fenêtre de `every` + (nombre de gisements) pensées, un
       gisement apparu ou disparu (même celui du curseur) ne casse rien, déterminisme ;
    3. coût (debug.sethook) : une lecture d'un gisement de 600 % contre les cinq gisements d'avant ;
    4. mutants.
  Usage, depuis la racine du mod : lua5.2 tests/cov_pas_test.lua
]]
package.path = "./?.lua;" .. package.path
local Cp = require("shared.ai3.cov_pas")

local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1; print("[COV-PAS] ECHEC : " .. msg) end
end
local seed = 20261109
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return math.floor(seed / 65536) % n end

local OFF = 1048576
local function tkey(x, y) return (x + OFF) * 2097152 + (y + OFF) end

-- la boucle d'avant, telle quelle (script/ai3/capitalisation.lua avant le lot)
local function old_covered(idx, drills)
  local seen, n = {}, 0
  for _, dp in ipairs(drills) do
    local r = dp.r
    for x = math.floor(dp.x - r + 0.01), math.floor(dp.x + r - 0.01) do
      for y = math.floor(dp.y - r + 0.01), math.floor(dp.y + r - 0.01) do
        local k = tkey(x, y)
        if idx[k] and not seen[k] then seen[k] = true n = n + 1 end
      end
    end
  end
  return n
end

local function gen(R, ndrills)
  local idx = {}
  for x = -R, R do for y = -R, R do if (x * x + y * y <= R * R) and rnd(100) < 85 then idx[tkey(x, y)] = true end end end
  local drills = {}
  for i = 1, ndrills do
    drills[i] = { x = rnd(2 * R + 1) - R + (rnd(2) == 0 and 0.5 or 0), y = rnd(2 * R + 1) - R + (rnd(2) == 0 and 0.5 or 0), r = ({ 1, 1.5, 2.5, 3 })[1 + rnd(4)] }
  end
  return idx, drills
end

---------------------------------------------------------------------------------------------------
-- 1. Cp.covered
---------------------------------------------------------------------------------------------------
local bad1 = 0
local function equiv(C, n)
  local bad = 0
  for i = 1, n do
    local idx, drills = gen(2 + rnd(30), rnd(80))
    if C(idx, drills, tkey) ~= old_covered(idx, drills) then bad = bad + 1 end
  end
  return bad
end
check(equiv(Cp.covered, 300) == 0, "1.a Cp.covered = la boucle d'avant sur 300 gisements")
check(Cp.covered({}, { { x = 0, y = 0, r = 2 } }, tkey) == 0 and Cp.covered({ [tkey(0, 0)] = true }, {}, tkey) == 0, "1.b gisement vide ou sans foreuse : 0")
check(Cp.covered({ [tkey(0, 0)] = true }, { { x = 0.5, y = 0.5, r = 1 }, { x = 0.5, y = 0.5, r = 1 } }, tkey) == 1, "1.c une tuile sous deux foreuses : comptée une fois")

---------------------------------------------------------------------------------------------------
-- 2. Cp.next_due
---------------------------------------------------------------------------------------------------
local function sorted_ids(set) local l = {} for k in pairs(set) do l[#l + 1] = k end table.sort(l) return l end
local function simulate(ND, pensees, churn, every)
  local present = {}
  for i = 1, ND do present["g" .. string.format("%02d", i)] = true end
  local last_read, cursor, reads_at = {}, nil, {}
  local ok_gap, ok_one, max_wait = true, true, 0
  local waiting = {}
  for p = 1, pensees do
    local tick = p * 300
    if churn and p % 17 == 0 then -- un gisement disparaît, un autre apparaît (même celui du curseur)
      local ids = sorted_ids(present)
      local gone = (p % 34 == 0 and cursor and present[cursor]) and cursor or ids[1 + rnd(#ids)]
      present[gone] = nil
      last_read[gone] = nil
      present["h" .. string.format("%03d", p)] = true
    end
    local ids = sorted_ids(present)
    local id = Cp.next_due(ids, cursor, function(i) return last_read[i] end, tick, every)
    if id then
      if not present[id] then ok_one = false end
      if last_read[id] and tick - last_read[id] < every then ok_gap = false end
      last_read[id] = tick
      cursor = id
      waiting[id] = 0
    end
    for _, k in ipairs(ids) do
      if k ~= id then
        waiting[k] = (waiting[k] or 0) + 1
        local due_since = (last_read[k] or 0)
        if waiting[k] > max_wait and (last_read[k] ~= nil) then max_wait = waiting[k] end
      end
    end
  end
  return ok_gap, ok_one, max_wait
end
for _, ND in ipairs({ 1, 3, 5, 9, 14 }) do
  local ok_gap, ok_one, max_wait = simulate(ND, 400, false, Cp.EVERY)
  -- chaque gisement est relu au plus ND + Cp.EVERY/300 pensées après sa lecture précédente (une pensée par lecture, EVERY = 10 pensées)
  check(ok_gap and ok_one, "2.a " .. ND .. " gisements : jamais deux lectures à moins de EVERY ticks, un seul par pensée")
  check(max_wait <= ND + Cp.EVERY / 300 + 1, string.format("2.b %d gisements : attente maximale %d pensées <= %d", ND, max_wait, ND + Cp.EVERY / 300 + 1))
end
do
  local ok_gap, ok_one = simulate(6, 600, true, Cp.EVERY)
  check(ok_gap and ok_one, "2.c gisements apparus et disparus (dont celui du curseur) : rien ne casse")
end
do
  local ids = { "a", "b", "c", "d" }
  local none = function() return nil end
  check(Cp.next_due(ids, nil, none, 0, 3000) == "a", "2.d sans curseur : le premier")
  check(Cp.next_due(ids, "b", none, 0, 3000) == "c", "2.e tous dus : le suivant le curseur")
  check(Cp.next_due(ids, "d", none, 0, 3000) == "a", "2.f après le dernier : retour au premier")
  check(Cp.next_due(ids, "bb", none, 0, 3000) == "c", "2.g curseur disparu : le premier identifiant après lui")
  check(Cp.next_due(ids, "zz", none, 0, 3000) == "a", "2.h curseur après tous : retour au premier")
  check(Cp.next_due({}, "a", none, 0, 3000) == nil, "2.i aucun gisement : rien")
  local fresh = function() return 100 end
  check(Cp.next_due(ids, nil, fresh, 200, 3000) == nil, "2.j tous relus récemment : rien")
  local mixed = function(i) return i == "c" and 0 or 5000 end
  check(Cp.next_due(ids, "c", mixed, 5500, 3000) == "c", "2.k un seul dû : lui, même s'il est le curseur")
  check(Cp.next_due(ids, "a", function(i) return i == "b" and 100 or 0 end, 3050, 3000) == "c", "2.l le plus proche après le curseur parmi les dus (b relu, c dû)")
end
do
  local a, b = simulate(5, 200, true, Cp.EVERY), simulate(5, 200, true, Cp.EVERY)
  check(a == b, "2.m déterminisme")
end

---------------------------------------------------------------------------------------------------
-- 3. Coût
---------------------------------------------------------------------------------------------------
local function instr(fn)
  local c = 0
  debug.sethook(function() c = c + 1 end, "", 100)
  fn()
  debug.sethook()
  return c * 100
end
local idx, drills = gen(32, 266)
local one = instr(function() Cp.covered(idx, drills, tkey) end)
print(string.format("[COV-PAS] cout : un gisement de 600 %% (266 foreuses) %d instructions de calcul ; cinq gisements d'avant dans une pensée : %d", one, 5 * one))
check(one <= 600000, "3.a un gisement de 600 % sous le budget d'une pensée (" .. one .. ")")

---------------------------------------------------------------------------------------------------
-- 4. Mutants
---------------------------------------------------------------------------------------------------
local f = assert(io.open("shared/ai3/cov_pas.lua", "rb")); local SRC = f:read("*a"); f:close()
local function variant(old, new)
  local a, b = SRC:find(old, 1, true)
  assert(a, "mutant introuvable : " .. old)
  assert(not SRC:find(old, b + 1, true), "mutant ambigu : " .. old)
  return load(SRC:sub(1, a - 1) .. new .. SRC:sub(b + 1), "mutant", "t")()
end
local MUTANTS = {
  { "tuiles comptées deux fois", "if idx[k] and not seen[k] then seen[k] = true n = n + 1 end", "if idx[k] then n = n + 1 end" },
  { "zone de minage trop petite", "for x = math.floor(dp.x - r + 0.01), math.floor(dp.x + r - 0.01) do", "for x = math.floor(dp.x - r + 0.01) + 1, math.floor(dp.x + r - 0.01) do" },
  { "curseur : >= au lieu de >", "if ids[i] > last then start = i break end", "if ids[i] >= last then start = i break end" },
  { "pas de retour au premier", "local i = (start - 1 + step) % n + 1", "local i = start + step; if i > n then return nil end" },
  { "jamais lu : pas dû", "if t == nil or tick - t >= every then return ids[i] end", "if t ~= nil and tick - t >= every then return ids[i] end" },
  { "toujours dû", "if t == nil or tick - t >= every then return ids[i] end", "if true then return ids[i] end" },
  { "dû trop tôt", "tick - t >= every", "tick - t >= 0" },
  { "sans curseur : le dernier", "local start = 1", "local start = n" },
}
local refused = 0
for _, m in ipairs(MUTANTS) do
  local ok, Mm = pcall(variant, m[2], m[3])
  local killed = not ok
  if ok then
    local ran, res = pcall(function()
      local bad = equiv(Mm.covered, 120)
      local g, o, w = simulate(5, 200, true, Cp.EVERY)
      local ids = { "a", "b", "c", "d" }
      local none = function() return nil end
      local s = Mm.next_due(ids, "b", none, 0, 3000) == "c" and Mm.next_due(ids, "d", none, 0, 3000) == "a" and Mm.next_due(ids, nil, none, 0, 3000) == "a"
        and Mm.next_due(ids, "a", function(i) return i == "b" and 100 or 0 end, 3050, 3000) == "c"
      local gap_ok = true
      do
        local last_read, cursor = {}, nil
        for p = 1, 100 do
          local tick = p * 300
          local id = Mm.next_due({ "a", "b", "c" }, cursor, function(i) return last_read[i] end, tick, Cp.EVERY)
          if id then
            if last_read[id] and tick - last_read[id] < Cp.EVERY then gap_ok = false end
            last_read[id] = tick
            cursor = id
          end
        end
      end
      return bad == 0 and s and gap_ok
    end)
    killed = (not ran) or not res
  end
  if killed then refused = refused + 1 end
  check(killed, "4. mutant refusé : " .. m[1])
end
print(string.format("[COV-PAS] mutants refusés : %d sur %d", refused, #MUTANTS))

print(string.format("[COV-PAS] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
