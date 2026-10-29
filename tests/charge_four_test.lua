--[[
  Lot FOURS : test hors jeu de la règle pure shared/team/charge_four.lua (charge d'un four à la pile, part du stock,
  répartition à égalité).
    §1 capacité et seuil ; §2 place ; §3 quantité emportée ; §4 répartition (force brute contre une référence écrite à part) ;
    §5 généralisation (aucun nom du jeu) ; §6 mutants : chaque ligne de décision altérée est vue (au moins 8).
  Usage : lua5.2 tests/charge_four_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/charge_four.lua")

local ok_n, fail_n = 0, 0
local function check(cond, label)
  if cond then ok_n = ok_n + 1 else fail_n = fail_n + 1; print("ECHEC : " .. label) end
end

local function load_mod(src)
  local fn = load(src, "=charge_four", "t")
  if not fn then return nil end
  local ok, mod = pcall(fn)
  if not ok or type(mod) ~= "table" then return nil end
  return mod
end

-- Suite de contrôles sur un module K ; rend le nombre d'échecs (utilisée telle quelle contre les mutants).
local function suite(K, report)
  local bad, n = 0, 0
  local function t(cond, label)
    n = n + 1
    if not cond then
      bad = bad + 1
      if report then report(label) end
    end
  end
  -- §1 capacité
  t(K.slot_cap(50, 1) == 50, "capacité d'une pile de 50 pour 1 par fabrication")
  t(K.slot_cap(100, 5) == 100, "pile de 100 pour 5 par fabrication : 100")
  t(K.slot_cap(50, 5) == 50, "pile de 50 pour 5 : 50")
  t(K.slot_cap(50, 3) == 48, "pile de 50 pour 3 : 48 (multiple inférieur)")
  t(K.slot_cap(2, 5) == 5, "pile plus petite qu'une fabrication : au moins une fabrication")
  t(K.slot_cap(50, 0) == 50 and K.slot_cap(50, nil) == 50, "rapport absent ou nul : 1")
  -- seuil du tiers
  t(K.needs_load(0, 50), "four vide : à charger")
  t(K.needs_load(16, 50), "16 sur 50 (au tiers, 48 < 50) : à charger")
  t(not K.needs_load(17, 50), "17 sur 50 (plus du tiers) : pas à charger")
  t(K.needs_load(33, 100) and not K.needs_load(34, 100), "tiers de 100")
  t(K.needs_load(16, 48) and K.needs_load(33, 99), "exactement au tiers : à charger")
  -- §2 place
  t(K.room(0, 50, 1) == 50, "four vide : 50 de place")
  t(K.room(10, 50, 1) == 40, "10 présents : 40 de place")
  t(K.room(30, 50, 1) == 0, "30 présents : pas à charger, place 0")
  t(K.room(0, 100, 5) == 100, "acier : 100 plaques de place")
  t(K.room(16, 50, 1) == 34, "au seuil : place complète jusqu'à la pile")
  -- §3 quantité emportée
  t(K.carry({ room = 200, stock = 3000, ratio = 1, loads = 4 }) == 200, "gros stock : tout ce qu'il faut (200)")
  t(K.carry({ room = 200, stock = 100, ratio = 1, loads = 4 }) == 50, "stock 100 : la moitié (50) car le plancher 40 est plus petit")
  t(K.carry({ room = 200, stock = 30, ratio = 1, loads = 4 }) == 30, "stock 30 : tout le stock, sous le plancher de 40")
  t(K.carry({ room = 200, stock = 60, ratio = 1, loads = 4 }) == 40, "stock 60 : le plancher (40) bat la moitié (30)")
  t(K.carry({ room = 20, stock = 3000, ratio = 1, loads = 1 }) == 20, "la place borne")
  t(K.carry({ room = 100, stock = 3000, ratio = 5, loads = 1, demand_crafts = 4 }) == 20, "la demande borne : 4 fabrications de 5")
  t(K.carry({ room = 100, stock = 3000, ratio = 5, loads = 1, demand_crafts = 0 }) == 0, "demande nulle : rien")
  t(K.carry({ room = 100, stock = 3000, ratio = 5, loads = 1 }) == 100, "sans borne de demande : la place")
  t(K.carry({ room = 100, stock = 7, ratio = 5, loads = 1 }) == 5, "multiple du rapport (7 -> 5)")
  t(K.carry({ room = 0, stock = 100, ratio = 1, loads = 1 }) == 0, "pas de place : 0")
  t(K.carry({ room = 100, stock = 0, ratio = 1, loads = 1 }) == 0, "pas de stock : 0")
  t(K.carry({ room = 48, stock = 3000, ratio = 3, loads = 1 }) == 48, "rapport 3 : 48")
  -- §4 répartition contre une référence écrite à part
  local function ref_split(avail, rooms, ratio)
    local out, left = {}, avail - avail % ratio
    for i = 1, #rooms do
      local rem = #rooms - i + 1
      local share = math.floor(left / rem)
      share = share - share % ratio
      if share < ratio then share = ratio end
      local n = math.min(share, rooms[i], left)
      n = n - n % ratio
      out[i] = n
      left = left - n
    end
    return out
  end
  local bad_split, total = 0, 0
  for _, ratio in ipairs({ 1, 2, 5 }) do
    for avail = 0, 60, 3 do
      for _, rooms in ipairs({ { 50 }, { 50, 50 }, { 50, 50, 50, 50 }, { 10, 50, 30 }, { 5, 5 }, { 0, 20 } }) do
        total = total + 1
        local a, b = K.split(avail, rooms, ratio), ref_split(avail, rooms, ratio)
        for i = 1, #rooms do
          if a[i] ~= b[i] then bad_split = bad_split + 1 break end
        end
      end
    end
  end
  t(total >= 300 and bad_split == 0, "répartition = référence sur " .. total .. " cas (" .. bad_split .. " écart(s))")
  local s = K.split(200, { 50, 50, 50, 50 }, 1)
  t(s[1] == 50 and s[2] == 50 and s[3] == 50 and s[4] == 50, "200 minerais pour 4 fours : 50 chacun")
  s = K.split(100, { 50, 50, 50, 50 }, 1)
  t(s[1] == 25 and s[2] == 25 and s[3] == 25 and s[4] == 25, "100 minerais pour 4 fours : 25 chacun (égalité)")
  s = K.split(10, { 50, 50, 50, 50 }, 5)
  t(s[1] == 5 and s[2] == 5 and s[3] == 0 and s[4] == 0, "10 plaques d'acier pour 4 fours : une fabrication aux deux premiers")
  s = K.split(40, { 10, 50 }, 1)
  t(s[1] == 10 and s[2] == 30, "un four presque plein ne prend que sa place, le reste va au suivant")
  local sum = 0
  s = K.split(77, { 50, 50, 50 }, 1)
  for i = 1, 3 do sum = sum + s[i] end
  t(sum == 77, "rien n'est perdu : 77 répartis")
  s = K.split(7, { 50, 50 }, 5)
  t(s[1] + s[2] == 5, "7 pour un rapport de 5 : une seule fabrication")
  return bad, n
end

local K = load_mod(SRC)
assert(K, "charge_four.lua ne se charge pas")
local fails = {}
local bad, nchecks = suite(K, function(l) fails[#fails + 1] = l end)
for _, l in ipairs(fails) do print("ECHEC : " .. l) end
check(bad == 0, "§1 à §4 : la suite entière passe sur le module (" .. bad .. " échec(s))")
ok_n = ok_n + nchecks - bad -- les contrôles de la suite, comptés un par un

-- §5 généralisation : les mêmes décisions pour d'autres rapports et piles, sans nom d'objet
check(not SRC:find("iron") and not SRC:find("coal") and not SRC:find("stone") and not SRC:find("plate"), "§5 aucun nom du jeu dans la règle")
do
  local ok_all = true
  for _, stack in ipairs({ 10, 33, 50, 64, 100, 200 }) do
    for _, ratio in ipairs({ 1, 2, 3, 5, 7 }) do
      local cap = K.slot_cap(stack, ratio)
      if cap % ratio ~= 0 or cap > math.max(stack, ratio) then ok_all = false end
      for present = 0, cap, 1 do
        local room = K.room(present, stack, ratio)
        if room < 0 or present + room > cap then ok_all = false end
        if (room > 0) ~= K.needs_load(present, cap) and cap - present > 0 then ok_all = false end
      end
    end
  end
  check(ok_all, "§5 invariants sur 30 couples pile/rapport : capacité multiple du rapport, jamais au-delà de la pile")
end
do
  local a1 = K.split(61, { 50, 20, 50 }, 3)
  local a2 = K.split(61, { 50, 20, 50 }, 3)
  check(a1[1] == a2[1] and a1[2] == a2[2] and a1[3] == a2[3], "§5 déterminisme")
end

-- §6 mutants : chaque altération doit être vue par la suite
local MUTANTS = {
  { "K.RELOAD_NUM, K.RELOAD_DEN = 1, 3", "K.RELOAD_NUM, K.RELOAD_DEN = 1, 2", "seuil à la moitié" },
  { "K.RELOAD_NUM, K.RELOAD_DEN = 1, 3", "K.RELOAD_NUM, K.RELOAD_DEN = 2, 3", "seuil aux deux tiers" },
  { "K.FLOOR_CRAFTS = 10", "K.FLOOR_CRAFTS = 1", "plancher d'une fabrication" },
  { "K.SHARE_NUM, K.SHARE_DEN = 1, 2", "K.SHARE_NUM, K.SHARE_DEN = 1, 1", "tout le stock" },
  { "K.SHARE_NUM, K.SHARE_DEN = 1, 2", "K.SHARE_NUM, K.SHARE_DEN = 1, 4", "quart du stock" },
  { "return (present or 0) * K.RELOAD_DEN <= cap * K.RELOAD_NUM", "return (present or 0) * K.RELOAD_DEN < cap * K.RELOAD_NUM",
    "seuil strict" },
  { "if cap < ratio then cap = ratio end", "", "capacité minimale retirée" },
  { "local cap = stack - stack % ratio", "local cap = stack", "capacité non arrondie au rapport" },
  { "if stock < n then n = stock end", "", "borne du stock retirée" },
  { "if d < n then n = d end", "", "borne de la demande retirée" },
  { "if cap < n then n = cap end", "", "borne plancher/part retirée" },
  { "n = n - n % ratio\n  return n > 0 and n or 0", "return n > 0 and n or 0", "quantité emportée non arrondie" },
  { "if share < ratio then share = ratio end", "", "une fabrication minimale par four retirée" },
  { "if left < n then n = left end", "", "borne du reste retirée" },
  { "left = left - n", "", "reste non décompté" },
  { "if share < n then n = share end", "", "égalité de la répartition retirée" },
}
local detected = 0
for _, m in ipairs(MUTANTS) do
  local i, j = SRC:find(m[1], 1, true)
  local seen = false
  if not i then
    print("ECHEC : mutant introuvable dans la source : " .. m[3])
  else
    local msrc = SRC:sub(1, i - 1) .. m[2] .. SRC:sub(j + 1)
    local M = load_mod(msrc)
    if not M then
      seen = true -- ne se charge plus : vu
    else
      local ok, b = pcall(suite, M, nil)
      seen = (not ok) or b > 0
    end
  end
  if seen then detected = detected + 1 else print("ECHEC : mutant NON vu : " .. m[3]) end
  check(seen, "§6 mutant vu : " .. m[3])
end
check(detected == #MUTANTS and #MUTANTS >= 8, "§6 " .. detected .. "/" .. #MUTANTS .. " mutants refusés")

print(string.format("[FOURS-CHARGE] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
