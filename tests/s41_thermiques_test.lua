--[[
  s41 thermiques (DC, partie de 3 h 30 : des foreuses thermiques restent ; lot ELAGAGE rejeté, E273 : boucle balayage / repose).
  Usage : lua5.2 tests/s41_thermiques_test.lua

  La boucle mesurée (fo-logs/2026-11-13_P120-ELAGAGE-314159265, scarlet, avant-poste 2 : 25 balayages, 145 paires en 120 min) : les paires
  balayées d'un gisement couvert étaient reposées par Outposts.extend sur le MÊME avant-poste (4 puis 2 paires), puis rebalayées 600 ticks
  plus tard. Preuve ici que la repose est impossible :
    1. règle pure Th.pairs_closed ;
    2. vrai script/faction/outposts.lua, moteur factice : Outposts.extend d'un avant-poste balayé rend 0 sans toucher la surface ni le porteur,
       même avec la porte de la famine ouverte et une migration en cours ; Outposts.reopen ne le rouvre pas ;
    3. modèle de la boucle : balayage / agrandissement rejoués 50 fois, une seule vague de retraits ;
    4. câblage (texte) : les deux retraits du balayage écrivent o.th_swept, la vue du cerveau le lit ;
    5. mutants : la garde retirée est vue.
]]
package.path = "./?.lua;" .. package.path
defines = { direction = { north = 0, east = 2, south = 4, west = 6 }, inventory = { chest = 1 } }
function log() end

local passes, failures = 0, 0
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. m) end end
local function read(path) local fh = assert(io.open(path, "rb")); local s = fh:read("*a"); fh:close(); return s end

-- 1. règle pure
local Th = require("shared.team.thermique")
check(Th.pairs_closed({ th_swept = 600 }) == true, "pur : avant-poste balayé -> fermé")
check(Th.pairs_closed({ th_swept = 0 }) == true, "pur : balayé au tick 0 -> fermé (0 n'est pas « jamais »)")
check(Th.pairs_closed({}) == false and Th.pairs_closed({ migr = "en cours", full = true }) == false, "pur : jamais balayé -> ouvert")
check(Th.pairs_closed(nil) == false and Th.pairs_closed(7) == false, "pur : entrée absente ou fausse -> ouvert, sans erreur")

-- 2. vrai Outposts.extend / Outposts.reopen
package.loaded["script.faction.state"] = { own = function() end, sorted_keys = function(t) local k = {} for a in pairs(t) do k[#k + 1] = a end table.sort(k) return k end }
package.loaded["script.faction.sites"] = {}
local PQ = dofile("script/ai3/places_qg.lua")
package.loaded["script.ai3.places_qg"] = { on_resource = function() return false end, is_reserved = PQ.is_reserved }
local famine_calls = 0
package.loaded["script.team.famine_fer"] = { open = function() famine_calls = famine_calls + 1; return true end, key_starved = function() return true end }
local OUT_SRC = read("script/faction/outposts.lua")
local function load_outposts(src)
  package.loaded["script.faction.outposts"] = nil
  return assert(load(src, "outposts", "t", _G))()
end
local touched
local function trap(label)
  return setmetatable({}, { __index = function(_, k) touched = touched + 1; error("moteur touché : " .. label .. "." .. tostring(k)) end })
end
local function extend_case(O, o)
  touched, famine_calls = 0, 0
  local f = { key = "ambre", force = "f1", id = 1, outposts = { [o.id] = o }, stats = {}, turrets = {} }
  local ok, n = pcall(O.extend, f, trap("surface"), o, trap("porteur"))
  return ok, n, touched, famine_calls
end
local function closed(O)
  local ok, n, t, fam = extend_case(O, { id = 2, kind = "iron", pos = { x = 0, y = 0 }, drills = 6, migr = "en cours", th_swept = 600, drill_list = {}, sinks = {} })
  local ok2, n2, t2 = extend_case(O, { id = 3, kind = "iron", pos = { x = 0, y = 0 }, drills = 6, th_swept = 600, drill_list = {}, sinks = {} })
  return ok and n == 0 and t == 0 and fam == 0 and ok2 and n2 == 0 and t2 == 0
end
local O = load_outposts(OUT_SRC)
check(closed(O), "extend : avant-poste balayé -> 0 paire, ni surface ni porteur touchés, la porte de la famine n'est même pas lue (migration en cours ou non)")
do
  -- témoin : le même avant-poste JAMAIS balayé passe la garde (il va plus loin : la suite lit la famine, les règles ou le moteur)
  local ok, n, t, fam = extend_case(O, { id = 4, kind = "iron", pos = { x = 0, y = 0 }, drills = 6, migr = "en cours", drill_list = {}, sinks = {} })
  check(not (ok and n == 0 and t == 0 and fam == 0), "extend, témoin : sans balayage, la garde s41 ne s'applique pas")
end
local function reopen_case(O2)
  local a = { id = 1, kind = "iron", full = true, full_by = "attente", drills = 4, th_swept = 600 }
  local b = { id = 2, kind = "iron", full = true, full_by = "attente", drills = 4 }
  O2.reopen({ outposts = { a, b } })
  return a.full == true and b.full == false
end
check(reopen_case(O), "reopen : l'avant-poste balayé reste plein, le témoin est rouvert")

-- 3. modèle de la boucle d'ELAGAGE : à chaque tour, le balayage puis l'agrandissement (vrai Outposts.extend derrière la garde)
local function loop(O2, rounds)
  local o = { id = 2, kind = "iron", pos = { x = 0, y = 0 }, drills = 6, migr = "en cours", drill_list = {}, sinks = {} }
  local pairs_up, waves, retired, reposed = 6, 0, 0, 0
  for r = 1, rounds do
    -- balayage (gisement couvert) : tout ce qui est debout est rendu au stock, l'avant-poste est marqué comme le fait l'exécutant
    if pairs_up > 0 then
      retired, waves, pairs_up = retired + pairs_up, waves + 1, 0
      o.th_swept = o.th_swept or r * 600
    end
    -- agrandissement demandé (famine ouverte, thermique permise) : la pose n'a lieu que si la garde laisse passer
    local ok, n, t = extend_case(O2, o)
    if not (ok and n == 0 and t == 0) then pairs_up, reposed = pairs_up + 6, reposed + 6 end
  end
  return waves, retired, reposed
end
do
  local waves, retired, reposed = loop(O, 50)
  check(waves == 1 and retired == 6 and reposed == 0, string.format("boucle : 50 tours, une seule vague de retraits, aucune repose (vagues %d, retirées %d, reposées %d)", waves, retired, reposed))
end

-- 4. câblage (texte)
local MIG = read("script/team/migration_champ.lua")
local _, n_marks = MIG:gsub("q%.th_swept = q%.th_swept or tick", "")
check(n_marks == 2, "câblage : le balayage et le retrait à sec marquent leurs avant-postes (" .. n_marks .. " sur 2)")
local _, n_cond = MIG:gsub("if removed > 0 then q%.th_swept", "")
check(n_cond == 2, "câblage : marque seulement quand une paire a été retirée")
check(read("script/team/team.lua"):find("or false or o.th_swept ~= nil,", 1, true) ~= nil, "câblage : la vue du cerveau donne l'avant-poste balayé pour plein (pas de tâche « extend » à vide)")
check(OUT_SRC:find("function Outposts.extend(f, surface, o, carrier)\n  if Th.pairs_closed(o) then return 0 end", 1, true) ~= nil
  or OUT_SRC:find("function Outposts.extend(f, surface, o, carrier)\r\n  if Th.pairs_closed(o) then return 0 end", 1, true) ~= nil,
  "câblage : la garde est la PREMIÈRE ligne de Outposts.extend (avant la famine)")

-- 5. mutants
local function mutate(src, old, new)
  local a, b = src:find(old, 1, true)
  assert(a, "mutant : texte introuvable : " .. old)
  return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local survivors = 0
do
  local M1 = load_outposts(mutate(OUT_SRC, "  if Th.pairs_closed(o) then return 0 end", "  "))
  if closed(M1) then survivors = survivors + 1; print("  MUTANT VIVANT : garde de extend retirée") end
  local w, _, rp = loop(M1, 50)
  if w == 1 and rp == 0 then survivors = survivors + 1; print("  MUTANT VIVANT : boucle sans garde") end
  local M2 = load_outposts(mutate(OUT_SRC, "not o.migr and not Th.pairs_closed(o) and not o.hold_until", "not o.migr and not o.hold_until"))
  if reopen_case(M2) then survivors = survivors + 1; print("  MUTANT VIVANT : reopen sans garde") end
  local TH_SRC = read("shared/team/thermique.lua")
  local Tm = assert(load(mutate(TH_SRC, "o.th_swept ~= nil", "o.th_swept == true"), "th", "t", _G))()
  if Tm.pairs_closed({ th_swept = 600 }) then survivors = survivors + 1; print("  MUTANT VIVANT : règle pure") end
end
check(survivors == 0, "mutants : 4 refusés sur 4 (" .. survivors .. " vivant(s))")
package.loaded["script.faction.outposts"] = O

print(string.format("[S41-THERMIQUES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
