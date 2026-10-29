-- Banc hors jeu du lot CONVOYEURS : choix du tapis par les équipes (shared/team/convoyeurs.lua).
--   lua5.2 tests/convoyeurs_test.lua      -> [CONVOYEURS] BILAN : N OK, 0 ECHEC(S)
package.path = "./?.lua;" .. package.path
local C = dofile("shared/team/convoyeurs.lua")

local ok_n, fail_n = 0, 0
local function check(cond, what, detail)
  if cond then ok_n = ok_n + 1 else
    fail_n = fail_n + 1
    print("ECHEC " .. what .. (detail and (" : " .. tostring(detail)) or ""))
  end
end

-- Données fictives (noms sans rapport avec le jeu : la règle n'en connaît aucun)
local BELTS = { { name = "c", speed = 0.09375 }, { name = "a", speed = 0.03125 }, { name = "b", speed = 0.0625 },
  { name = "x", speed = 0 }, { name = "y" }, { speed = 0.5 } }
local ALL = function() return true end
local only = function(...) local s = {}; for _, n in ipairs({ ... }) do s[n] = true end; return function(n) return s[n] end end

-- tri et filtrage
local S = C.sorted(BELTS)
check(#S == 3 and S[1].name == "a" and S[2].name == "b" and S[3].name == "c", "tri par vitesse, invalides retirés")
check(#C.sorted(nil) == 0, "liste absente")
local tie = C.sorted({ { name = "z", speed = 1 }, { name = "m", speed = 1 } })
check(tie[1].name == "m", "égalité départagée par le nom")
check(BELTS[1].name == "c", "la liste d'entrée n'est pas modifiée")

-- capacité
check(math.abs(C.capacity(0.03125) - 7.5) < 1e-9, "capacité d'une voie 7,5/s")
check(math.abs(C.capacity(0.0625) - 15) < 1e-9, "capacité 15/s")

-- choix : le meilleur disponible
check(C.pick(BELTS, ALL) == "c", "meilleur de tous")
check(C.pick(BELTS, only("a", "b")) == "b", "meilleur parmi les débloqués")
check(C.pick(BELTS, only("a")) == "a", "un seul débloqué")
check(C.pick(BELTS, only()) == nil, "aucun débloqué : nil")
check(C.pick({}, ALL) == nil, "aucun tapis : nil")
check(C.pick(BELTS, nil) == "c", "sans prédicat : tout est disponible")
local n, sp = C.pick(BELTS, only("a", "b"))
check(n == "b" and sp == 0.0625, "la vitesse est rendue")
-- un tapis plus rapide NON débloqué n'est jamais choisi, quel que soit le besoin
check(C.pick(BELTS, only("a"), 99, { need_only = true }) == "a", "besoin énorme : plafonné aux débloqués")

-- choix selon le besoin
local need = { need_only = true }
check(C.pick(BELTS, ALL, 5, need) == "a", "besoin 5/s : le plus lent suffit")
check(C.pick(BELTS, ALL, 5.99, need) == "a", "besoin 5,99/s, sous 80 % de 7,5 : encore le plus lent")
check(C.pick(BELTS, ALL, 6, need) == "b", "6/s = 80 % : saturé, le suivant")
for _, v in ipairs({ 0, 3, 5.99, 6, 6.5, 11.99, 12, 14, 30 }) do
  local nm, spd = C.pick(BELTS, ALL, v, need)
  check(nm == "c" or not C.saturated(v, spd), "un tracé neuf choisi n'est jamais aussitôt amélioré, besoin " .. v)
  check(nm == "c" or C.upgrade_target(BELTS, ALL, nm, v) == nil, "pas d'amélioration d'un choix fait selon le besoin, " .. v)
end
check(C.pick(BELTS, ALL, 14, need) == "c", "besoin 14/s : le troisième (13,5 < 14)")
check(C.pick(BELTS, ALL, 100, need) == "c", "besoin hors de portée : le plus rapide")
check(C.pick(BELTS, ALL, nil, need) == "c", "besoin inconnu : le meilleur")
check(C.pick(BELTS, ALL, 5) == "c", "sans need_only le besoin est ignoré")
check(C.pick(BELTS, ALL, 0, need) == "a", "besoin nul")

-- saturation
check(not C.saturated(5.9, 0.03125), "5,9/s sur 7,5 : pas saturé")
check(C.saturated(6, 0.03125), "6/s = 80 % : saturé")
check(C.saturated(50, 0.03125), "très au-dessus : saturé")
check(not C.saturated(nil, 0.03125), "débit inconnu : pas saturé")

-- amélioration
check(C.upgrade_target(BELTS, ALL, "a", 6.5) == "b", "a sature : niveau supérieur b")
check(C.upgrade_target(BELTS, ALL, "b", 13) == "c", "b sature : c")
check(C.upgrade_target(BELTS, ALL, "c", 99) == nil, "déjà le meilleur")
check(C.upgrade_target(BELTS, ALL, "a", 3) == nil, "pas de saturation : rien")
check(C.upgrade_target(BELTS, only("a"), "a", 7) == nil, "niveau supérieur non débloqué : rien")
check(C.upgrade_target(BELTS, only("a", "c"), "a", 7) == "c", "b non débloqué : le suivant débloqué")
check(C.upgrade_target(BELTS, ALL, "inconnu", 7) == nil, "tapis inconnu : rien")
check(C.upgrade_target(BELTS, ALL, "b", 6.5) == nil, "b ne sature pas à 6,5/s")

-- lot de remplacements
local L = { { name = "a", built = true }, { name = "a" }, { name = "b", built = true }, { name = "a", built = true },
  { name = "a", built = true }, { name = "a", built = true } }
local bt = C.next_batch(L, "a", 2)
check(#bt == 2 and bt[1] == 1 and bt[2] == 4, "lot : bâties seulement, dans l'ordre, borné")
check(#C.next_batch(L, "a", 99) == 4, "lot non borné : les 4 bâties")
check(#C.next_batch(L, "zz", 5) == 0, "lot : aucun nom")
check(#C.next_batch(nil, "a", 5) == 0, "lot : liste absente")
check(#C.next_batch(L, "a", 0) == 0, "lot de taille nulle")

-- force brute : pour toute vitesse débloquée, le choix est débloqué, et monotone en le besoin
local speeds = { 0.03125, 0.0625, 0.09375, 0.125 }
local bad = 0
for mask = 0, 15 do
  local belts, avail = {}, {}
  for i, s in ipairs(speeds) do
    belts[i] = { name = "n" .. i, speed = s }
    if bit32.band(mask, bit32.lshift(1, i - 1)) ~= 0 then avail["n" .. i] = true end
  end
  local prev = 0
  for need_v = 0, 40, 1 do
    local name, s2 = C.pick(belts, function(x) return avail[x] end, need_v, need)
    if mask == 0 then
      if name ~= nil then bad = bad + 1 end
    else
      if not name or not avail[name] or s2 < prev then bad = bad + 1 end
      prev = s2 or prev
    end
  end
end
check(bad == 0, "force brute : disponible et monotone sur 16 masques x 41 besoins", bad)
local bad2 = 0
for mask = 1, 15 do
  local belts, avail = {}, {}
  for i, s in ipairs(speeds) do
    belts[i] = { name = "n" .. i, speed = s }
    if bit32.band(mask, bit32.lshift(1, i - 1)) ~= 0 then avail["n" .. i] = true end
  end
  local best, bs = nil, -1
  for i, s in ipairs(speeds) do if avail["n" .. i] and s > bs then best, bs = "n" .. i, s end end
  if C.pick(belts, function(x) return avail[x] end) ~= best then bad2 = bad2 + 1 end
  for i = 1, 4 do
    local t = C.upgrade_target(belts, function(x) return avail[x] end, "n" .. i, 1000)
    if t then
      local ts
      for j, s in ipairs(speeds) do if "n" .. j == t then ts = s end end
      if not avail[t] or ts <= speeds[i] then bad2 = bad2 + 1 end
    end
  end
end
check(bad2 == 0, "force brute : meilleur disponible et amélioration strictement plus rapide et débloquée", bad2)

-- branchement du plan : un tapis des données (inconnu de modules.lua) occupe une tuile ; la tête prend le tapis demandé
local P = dofile("shared/team/plan.lua")
local w, h = P.size("tapis-fictif-belt", 0)
check(w == 1 and h == 1, "tapis inconnu : 1 x 1")
local fd = P.feeder({ x = 10, y = 10, dir = 0, lanes = { "a", "b" } }, { "tapis", "quai" }, nil, "tapis-fictif-belt")
local heads, other = 0, 0
for _, e in ipairs(fd.entities) do if e.role == "tete" then heads = heads + (e.name == "tapis-fictif-belt" and 1 or 0) else other = other + 1 end end
check(heads == 3, "tête de 3 tuiles au tapis demandé", heads)
local fd0 = P.feeder({ x = 10, y = 10, dir = 0, lanes = { "a", "b" } }, { "tapis", "quai" })
local d0 = 0
for _, e in ipairs(fd0.entities) do if e.role == "tete" and e.name == "transport-belt" then d0 = d0 + 1 end end
check(d0 == 3, "sans tapis demandé : le tapis par défaut d'avant")

-- aucun nom d'objet en dur dans la règle
local fh = assert(io.open("shared/team/convoyeurs.lua", "rb"))
local src = fh:read("*a"); fh:close()
local code = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check(not code:find("belt\"") and not code:find("fast%-") and not code:find("express"), "aucun nom d'objet en dur")

print(string.format("[CONVOYEURS] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
