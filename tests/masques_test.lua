--[[
  Tests hors jeu du relevé paresseux des masques par chunk (lot POTEAUX-MASQUES ; shared/team/masques.lua, pur).
  Usage, depuis la racine du mod :   lua5.2 tests/masques_test.lua

  Vérifie :
    1. arithmétique des chunks : négatifs, clés distinctes, demi-largeur du couloir ;
    2. couloir : chunks du segment, sans doublon, ordre le long du segment, plafond, négatifs, segment nul, plusieurs legs ;
    3. budget : l'accord grandit de BUDGET par essai, jamais plus que la liste, ne dépend pas du cache ; lectures bornées par
       l'accord ; le cache évite les relectures ;
    4. cache : péremption (TTL), horloge qui recule, invalidation par rectangle (seuls les chunks touchés), effacement ;
    5. vue : octet pour octet comme la base dans le rectangle relevé (bord exclu), chunk relevé hors rectangle, inconnu = libre
       (compté), tuiles réservées lues à chaque appel (jamais en cache), défrichable ;
    6. de bout en bout (monde synthétique + P.pole_chain) : une crête à mi-chemin d'une longue liaison, hors du rectangle relevé :
       SANS la vue la chaîne traverse la crête ; AVEC la vue elle la contourne ; essais et lectures comptés ; résultat identique
       depuis un cache vide (chargement) ; relevé périmé relu ;
    7. déterminisme ;
    8. mutants : 14 variantes fautives du module sont refusées par la même batterie.
]]

package.path = "./?.lua;" .. package.path

local P = require("shared.team.plan")
local Q0 = require("shared.team.masques")

local passes, failures = 0, 0
local verbose = true
local function section(name) if verbose then print("== " .. name) end end

local function battery(Q, is_real)
  local fails = 0
  local function check(cond, msg)
    if cond then
      if is_real then passes = passes + 1 end
    else
      fails = fails + 1
      if is_real then failures = failures + 1; print("  ECHEC : " .. msg) end
    end
  end
  local tkey = P.tkey

  ---------------------------------------------------------------------------------------------------------------
  section("1. Arithmétique des chunks")
  check(Q.chunk_of(0) == 0 and Q.chunk_of(31) == 0 and Q.chunk_of(32) == 1, "chunk_of positif")
  check(Q.chunk_of(-1) == -1 and Q.chunk_of(-32) == -1 and Q.chunk_of(-33) == -2, "chunk_of négatif (plancher)")
  local seenk, dup = {}, false
  for cy = -3, 3 do for cx = -3, 3 do local k = Q.ckey(cx, cy); if seenk[k] then dup = true end; seenk[k] = true end end
  check(not dup, "clés de chunk distinctes sur 7 × 7")
  check(Q.margin(9) == 18 and Q.margin(3) == 16 and Q.margin(30) == 32 and Q.margin(100) == 32 and Q.margin(0) == 16,
    "demi-largeur du couloir : 2 × portée bornée à 16..32 (" .. Q.margin(9) .. ", " .. Q.margin(3) .. ", " .. Q.margin(30) .. ")")

  ---------------------------------------------------------------------------------------------------------------
  section("2. Couloir")
  do
    local legs = { { a = { x = 0.5, y = 0.5 }, b = { x = 120.5, y = 0.5 } } }
    local list, total = Q.corridor(legs, 18)
    -- bande y de -17,5 à 18,5 : chunks -1 et 0 ; x de -17,5 à 138,5 : chunks -1 à 4
    check(total == 12 and #list == 12, "segment horizontal de 120 tuiles, demi-largeur 18 : 6 × 2 = 12 chunks (" .. total .. ")")
    local seen, ok_dup = {}, true
    for _, c in ipairs(list) do local k = Q.ckey(c.cx, c.cy); if seen[k] then ok_dup = false end; seen[k] = true end
    check(ok_dup, "aucun doublon")
    check(seen[Q.ckey(0, 0)] and seen[Q.ckey(3, 0)] and seen[Q.ckey(3, -1)], "chunks du départ, du milieu et de l'arrivée")
    check(list[1].cx <= 0 and list[#list].cx >= 3, "ordonné le long du segment (début au départ, fin à l'arrivée)")
    local mono = true
    for i = 2, #list do if list[i].cx < list[i - 1].cx - 1 then mono = false end end
    check(mono, "l'abscisse ne recule jamais de plus d'un chunk (ordre le long du segment)")
    local list2 = Q.corridor(legs, 18)
    local same = #list2 == #list
    for i = 1, #list do if same and (list[i].cx ~= list2[i].cx or list[i].cy ~= list2[i].cy) then same = false end end
    check(same, "deux appels : même liste")
  end
  do
    -- couloir étroit : la marge compte (chunk à 40 tuiles du segment hors de la marge)
    local legs = { { a = { x = 10, y = 10 }, b = { x = 20, y = 10 } } }
    local list = Q.corridor(legs, 4)
    check(#list == 1 and list[1].cx == 0 and list[1].cy == 0, "marge 4 autour d'un petit segment : un seul chunk (" .. #list .. ")")
    local list_w = Q.corridor(legs, 40)
    check(#list_w > 4, "marge 40 : couloir plus large (" .. #list_w .. ")")
    local l0 = Q.corridor({ { a = { x = 5, y = 5 }, b = { x = 5, y = 5 } } }, 4)
    check(#l0 == 1, "segment nul : le chunk du point")
  end
  do
    -- négatifs et diagonale
    local legs = { { a = { x = -100.5, y = -100.5 }, b = { x = -10.5, y = -10.5 } } }
    local list = Q.corridor(legs, 16)
    local seen = {}
    for _, c in ipairs(list) do seen[Q.ckey(c.cx, c.cy)] = true end
    check(seen[Q.ckey(-4, -4)] and seen[Q.ckey(-1, -1)], "diagonale négative : chunks des deux bouts")
    check(not seen[Q.ckey(0, -4)] and not seen[Q.ckey(-4, 0)], "diagonale : les coins opposés ne sont pas au couloir")
    -- plusieurs legs : dédoublonnage, l'ordre suit les legs
    local two = Q.corridor({ { a = { x = 0.5, y = 0.5 }, b = { x = 60.5, y = 0.5 } }, { a = { x = 60.5, y = 0.5 }, b = { x = 60.5, y = 90.5 } } }, 16)
    local s2, dupl = {}, false
    for _, c in ipairs(two) do local k = Q.ckey(c.cx, c.cy); if s2[k] then dupl = true end; s2[k] = true end
    check(not dupl, "deux legs qui se touchent : pas de doublon")
    check(s2[Q.ckey(1, 0)] and s2[Q.ckey(1, 2)], "deux legs : chunks de chacun")
  end
  do
    -- plafond
    local legs = { { a = { x = 0, y = 0 }, b = { x = 2000, y = 0 } } }
    local list, total = Q.corridor(legs, 16)
    check(#list == Q.MAX_CHUNKS and total > Q.MAX_CHUNKS, "couloir de " .. total .. " chunks plafonné à " .. Q.MAX_CHUNKS .. " (" .. #list .. ")")
    check(list[1].cx == -1 or list[1].cx == 0, "le plafond garde le début du couloir")
  end

  ---------------------------------------------------------------------------------------------------------------
  section("3. Budget")
  do
    check(Q.grant(1, 12) == Q.BUDGET and Q.grant(2, 12) == 2 * Q.BUDGET and Q.grant(3, 12) == 12, "accord : BUDGET, 2 × BUDGET, puis la liste (" .. Q.grant(3, 12) .. ")")
    check(Q.grant(99, 7) == 7, "jamais plus que la liste")
    check(Q.grant(0, 7) == Q.BUDGET and Q.grant(nil, 7) == Q.BUDGET, "essai 0 ou absent : un premier accord")
    check(Q.grant(1, 2) == 2, "liste plus courte que le budget : toute la liste")
    local n = 17
    local attempts = 0
    repeat attempts = attempts + 1 until Q.grant(attempts, n) >= n
    check(attempts == math.ceil(n / Q.BUDGET), "essais pour couvrir " .. n .. " chunks : " .. attempts)
    -- l'accord ne dépend pas du cache : même résultat cache chaud ou vide
    local c = Q.new()
    local calls = { n = 0 }
    local reader = function(cx, cy) calls.n = calls.n + 1; return { water = {}, blocked = {}, clear = {} } end
    local list = {}
    for i = 1, 10 do list[i] = { cx = i, cy = 0 } end
    local ready, reads, hits = Q.ensure(c, list, 4, 100, reader)
    check(reads == 4 and hits == 0 and calls.n == 4, "cache vide, accord de 4 : 4 lectures (" .. reads .. ")")
    local cnt = 0
    for _ in pairs(ready) do cnt = cnt + 1 end
    check(cnt == 4, "4 chunks prêts, pas un de plus (" .. cnt .. ")")
    check(ready[Q.ckey(1, 0)] and ready[Q.ckey(4, 0)] and not ready[Q.ckey(5, 0)], "ce sont les 4 premiers de la liste")
    ready, reads, hits = Q.ensure(c, list, 4, 101, reader)
    check(reads == 0 and hits == 4 and calls.n == 4, "même accord au tick suivant : 0 lecture, 4 au cache (" .. reads .. ", " .. hits .. ")")
    ready, reads, hits = Q.ensure(c, list, 8, 102, reader)
    check(reads == 4 and hits == 4 and calls.n == 8, "accord de 8 : seulement les 4 nouveaux lus (" .. reads .. ", " .. hits .. ")")
    local c2 = Q.new()
    local _, r2 = Q.ensure(c2, list, 8, 103, reader)
    check(r2 == 8, "cache vide (après chargement), accord de 8 : 8 lectures, bornées par l'accord (" .. r2 .. ")")
  end

  ---------------------------------------------------------------------------------------------------------------
  section("4. Cache : péremption, invalidation")
  do
    local c = Q.new()
    local d = { water = {}, blocked = {}, clear = {} }
    Q.put(c, 2, 3, 1000, d)
    check(Q.get(c, 2, 3, 1000) == d and Q.get(c, 2, 3, 1000 + Q.TTL - 1) == d, "relevé frais rendu")
    check(Q.get(c, 2, 3, 1000 + Q.TTL) == nil, "relevé périmé à TTL ticks : retiré")
    check(c.n == 0, "compteur de relevés remis à jour (" .. c.n .. ")")
    Q.put(c, 2, 3, 1000, d)
    check(Q.get(c, 2, 3, 900) == nil, "horloge qui recule (autre partie) : relevé refusé")
    -- invalidation
    local c3 = Q.new()
    for cy = 0, 3 do for cx = 0, 3 do Q.put(c3, cx, cy, 5, d) end end
    check(c3.n == 16, "16 relevés")
    -- rectangle de tuiles 40..70 × 10..20 : chunks x 1..2, y 0
    local dropped = Q.invalidate(c3, 40, 10, 70, 20)
    check(dropped == 2 and c3.n == 14, "invalidation d'un rectangle sur 2 chunks : 2 retirés (" .. dropped .. ")")
    check(Q.get(c3, 1, 0, 6) == nil and Q.get(c3, 2, 0, 6) == nil and Q.get(c3, 0, 0, 6) == d and Q.get(c3, 3, 0, 6) == d and Q.get(c3, 1, 1, 6) == d,
      "seuls les chunks touchés sont retirés")
    -- un rectangle à cheval sur une frontière de chunk
    local dropped2 = Q.invalidate(c3, 31, 31, 32, 32)
    check(dropped2 == 3 and c3.n == 11, "rectangle sur un coin de 4 chunks dont un déjà retiré : 3 retirés (" .. dropped2 .. ")")
    check(Q.invalidate(c3, 1000, 1000, 1010, 1010) == 0, "rectangle sans relevé : 0")
    -- un relevé retiré est relu
    local calls = { n = 0 }
    local reader = function() calls.n = calls.n + 1; return d end
    Q.ensure(c3, { { cx = 1, cy = 0 } }, 1, 7, reader)
    check(calls.n == 1, "chunk invalidé : relu")
    Q.ensure(c3, { { cx = 1, cy = 0 } }, 1, 8, reader)
    check(calls.n == 1, "puis de nouveau au cache")
    Q.ensure(c3, { { cx = 1, cy = 0 } }, 1, 8 + Q.TTL, reader)
    check(calls.n == 2, "puis relu quand il est périmé")
    Q.clear(c3)
    check(c3.n == 0 and Q.get(c3, 0, 0, 6) == nil, "effacement")
  end

  ---------------------------------------------------------------------------------------------------------------
  section("5. Vue")
  do
    local base_blocked = {}
    for x = 5, 7 do for y = 5, 7 do base_blocked[tkey(x, y)] = true end end
    local base_clear = { [tkey(2, 2)] = true }
    local base = {
      free = function(tx, ty) return not base_blocked[tkey(tx, ty)] end,
      clear = base_clear,
    }
    local rect = { x0 = 0, y0 = 0, x1 = 20, y1 = 20 }
    local chunk_d = { water = { [tkey(40, 40)] = true }, blocked = { [tkey(41, 40)] = true }, clear = { [tkey(42, 40)] = true } }
    local ready = { [Q.ckey(1, 1)] = chunk_d }
    local reserved = {}
    local v = Q.view(base, rect, ready, tkey, function(tx, ty) return not reserved[tkey(tx, ty)] end)
    local same = true
    for ty = 0, 19 do for tx = 0, 19 do
      if v.free(tx, ty) ~= base.free(tx, ty) then same = false end
      if v.clear(tx, ty) ~= (base_clear[tkey(tx, ty)] == true) then same = false end
    end end
    check(same, "dans le rectangle relevé : même réponse que la base, tuile par tuile")
    check(v.stats.base == 400 and v.stats.chunk == 0 and v.stats.unknown == 0, "compteurs : 400 interrogations du rectangle")
    check(v.free(20, 5) == true and v.stats.unknown == 1, "x1 exclu du rectangle : tuile 20 hors rectangle, hors chunk relevé : inconnue donc libre")
    check(v.free(40, 40) == false, "eau d'un chunk relevé : pas libre")
    check(v.free(41, 40) == false, "bloqué d'un chunk relevé : pas libre")
    check(v.free(43, 40) == true, "tuile libre d'un chunk relevé")
    check(v.clear(42, 40) == true and v.clear(43, 40) == false, "défrichable d'un chunk relevé")
    check(v.stats.chunk == 3, "compteur de tuiles lues dans un chunk relevé (" .. v.stats.chunk .. ")")
    check(v.free(100, 100) == true and v.clear(100, 100) == false, "tuile d'un chunk non relevé : libre, pas défrichable")
    -- réservation lue à chaque appel
    reserved[tkey(43, 40)] = true
    check(v.free(43, 40) == false, "tuile réservée par nos projets APRÈS le relevé : refusée aussitôt (jamais en cache)")
    reserved[tkey(43, 40)] = nil
    check(v.free(43, 40) == true, "puis libérée")
    -- sans rectangle : tout est à la base
    local v2 = Q.view(base, nil, ready, tkey, function() return true end)
    check(v2.free(41, 40) == true and v2.free(6, 6) == false, "sans rectangle : la base seule répond")
  end

  ---------------------------------------------------------------------------------------------------------------
  section("6. De bout en bout : une crête hors du rectangle relevé")
  do
    local a, b = { x = 0.5, y = 0.5 }, { x = 120.5, y = 0.5 }
    local function ridge(tx, ty) return tx >= 58 and tx <= 66 and ty >= -12 and ty <= 12 end
    local counter = { n = 0 }
    local function reader_for(cnt)
      return function(cx, cy)
        cnt.n = cnt.n + 1
        local d = { water = {}, blocked = {}, clear = {} }
        for ty = cy * 32, cy * 32 + 31 do for tx = cx * 32, cx * 32 + 31 do
          if ridge(tx, ty) then d.blocked[tkey(tx, ty)] = true end
        end end
        return d
      end
    end
    -- la base : le rectangle autour du module, lu au moteur (la crête n'y est pas)
    local rect = { x0 = -8, y0 = -8, x1 = 32, y1 = 8 }
    local base = { free = function(tx, ty) return not ridge(tx, ty) end, clear = {} }
    local function chain_with(view)
      local free = function(x, y) local tx, ty = math.floor(x), math.floor(y); return view.free(tx, ty) and not view.clear(tx, ty) end
      return P.pole_chain(a, b, 9, false, free, {})
    end
    local function in_world(chain)
      if not chain then return false end
      for _, c in ipairs(chain) do if ridge(math.floor(c.x), math.floor(c.y)) then return false end end
      return true
    end
    local function valid_reach(chain)
      local prev = a
      for _, c in ipairs(chain) do
        if math.sqrt((c.x - prev.x) ^ 2 + (c.y - prev.y) ^ 2) > 9 + 1e-6 then return false end
        prev = c
      end
      return math.sqrt((b.x - prev.x) ^ 2 + (b.y - prev.y) ^ 2) <= 9 + 1e-6
    end
    -- SANS la vue : tout ce qui est hors du rectangle est libre (le comportement d'avant le lot)
    local naive = Q.view(base, rect, {}, tkey, function() return true end)
    local c_naive = chain_with(naive)
    check(c_naive ~= nil and not in_world(c_naive), "sans relevé du couloir : la chaîne traverse la crête (le défaut du lot)")
    -- AVEC la vue
    local legs = { { a = a, b = b } }
    local list = Q.corridor(legs, Q.margin(9))
    local cache = Q.new()
    local attempts, view = 0, nil
    local reads_by_attempt = {}
    repeat
      attempts = attempts + 1
      local granted = Q.grant(attempts, #list)
      local before = counter.n
      local ready = Q.ensure(cache, list, granted, 1000 + attempts * Q.WAIT_TICKS, reader_for(counter))
      reads_by_attempt[attempts] = counter.n - before
      if granted >= #list then view = Q.view(base, rect, ready, tkey, function() return true end) end
    until view
    check(attempts == math.ceil(#list / Q.BUDGET), "essais jusqu'au couloir complet : " .. attempts .. " pour " .. #list .. " chunks")
    local maxr = 0
    for _, r in ipairs(reads_by_attempt) do maxr = math.max(maxr, r) end
    check(maxr <= Q.BUDGET, "au plus BUDGET lectures par essai (cache chaud) : " .. maxr)
    check(counter.n == #list, "chaque chunk du couloir lu une fois : " .. counter.n .. " lectures pour " .. #list)
    local c_view = chain_with(view)
    check(c_view ~= nil and in_world(c_view), "avec le relevé du couloir : la chaîne contourne la crête")
    check(c_view and valid_reach(c_view), "portée de chaque maillon et arrivée respectées")
    check(c_view and #c_view >= math.ceil((120 - 9) / 9) - 1, "au moins le minimum théorique de poteaux (" .. tostring(c_view and #c_view) .. ")")
    -- même résultat depuis un cache vide (après un chargement)
    local counter2 = { n = 0 }
    local ready2 = Q.ensure(Q.new(), list, #list, 5000, reader_for(counter2))
    local c_cold = chain_with(Q.view(base, rect, ready2, tkey, function() return true end))
    local same = c_cold ~= nil and c_view ~= nil and #c_cold == #c_view
    if same then for i = 1, #c_view do if c_cold[i].x ~= c_view[i].x or c_cold[i].y ~= c_view[i].y then same = false end end end
    check(same, "chaîne identique depuis un cache vide (déterminisme au chargement)")
    check(counter2.n == #list, "cache vide : le couloir entier lu d'un coup, borné par le plafond (" .. counter2.n .. " <= " .. Q.MAX_CHUNKS .. ")")
    check(counter2.n <= Q.MAX_CHUNKS, "lecture à froid bornée par MAX_CHUNKS")
    -- relevé périmé : relu et la crête déplacée est vue
    local ridge2 = false
    local old_ridge = ridge
    ridge = function(tx, ty) if ridge2 then return tx >= 58 and tx <= 66 and ty >= -40 and ty <= 40 end return old_ridge(tx, ty) end
    ridge2 = true
    local cnt3 = { n = 0 }
    Q.ensure(cache, list, #list, 1000 + 99 * Q.WAIT_TICKS, reader_for(cnt3))
    check(cnt3.n == #list, "relevés périmés (TTL) : relus (" .. cnt3.n .. ")")
    local ready3 = Q.ensure(cache, list, #list, 1000 + 99 * Q.WAIT_TICKS, reader_for(cnt3))
    local base3 = { free = function(tx, ty) return not ridge(tx, ty) end, clear = {} }
    local c3 = chain_with(Q.view(base3, rect, ready3, tkey, function() return true end))
    check(c3 == nil or in_world(c3), "crête élargie après relecture : jamais de poteau sur la crête")
    ridge = old_ridge
  end

  return fails
end

---------------------------------------------------------------------------------------------------------------
local f0 = battery(Q0, true)
local _ = f0

section("7. Déterminisme")
do
  local legs = { { a = { x = 3.5, y = 7.5 }, b = { x = 140.5, y = 90.5 } }, { a = { x = 140.5, y = 90.5 }, b = { x = 20.5, y = 200.5 } } }
  local l1, t1 = Q0.corridor(legs, 18)
  local l2, t2 = Q0.corridor(legs, 18)
  local ok = #l1 == #l2 and t1 == t2
  for i = 1, #l1 do if ok and (l1[i].cx ~= l2[i].cx or l1[i].cy ~= l2[i].cy) then ok = false end end
  if ok then passes = passes + 1 else failures = failures + 1; print("  ECHEC : couloir non déterministe") end
  local src = io.open("shared/team/masques.lua", "rb"):read("*a")
  local code = src:gsub("%-%-%[%[.-%]%]", "")
  code = code:gsub("%-%-[^\n]*", "")
  if code:find("%f[%w_]pairs%(") or code:find("math%.sin") or code:find("math%.cos") or code:find("os%.clock") or code:find("os%.time") or code:find("math%.random") then
    failures = failures + 1; print("  ECHEC : pairs, trigonométrie, temps ou hasard dans masques.lua")
  else
    passes = passes + 1
  end
end

section("8. Mutants")
do
  local fh = io.open("shared/team/masques.lua", "rb")
  local src = fh:read("*a")
  fh:close()
  local old_print = print
  local function mutant(label, from, to)
    local esc = from:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    local s, n = src:gsub(esc, (to:gsub("%%", "%%%%")), 1)
    if n ~= 1 then failures = failures + 1; print("  ECHEC : mutant « " .. label .. " » : motif introuvable dans masques.lua") return end
    local chunk = load(s, "=mutant", "t", _ENV)
    local M = chunk()
    verbose = false
    local ok, nf = pcall(battery, M, false)
    verbose = true
    if not ok then nf = 1 end -- un plantage compte comme refusé
    if nf >= 1 then passes = passes + 1 else failures = failures + 1; print("  ECHEC : mutant « " .. label .. " » NON refusé") end
  end
  mutant("accord de tout le couloir d'un coup", "return min(n, max(1, floor(attempt or 1)) * Q.BUDGET)", "return n")
  mutant("tuile inconnue = bloquée", "if not d then st.unknown = st.unknown + 1; return true end", "if not d then st.unknown = st.unknown + 1; return false end")
  mutant("bord x1 du rectangle inclus", "tx >= rect.x0 and tx < rect.x1", "tx >= rect.x0 and tx <= rect.x1")
  mutant("relevé jamais périmé", "if tick - e.tick >= Q.TTL or tick < e.tick then", "if false then")
  mutant("invalidation sans effet", "if c.ch[k] then", "if false then")
  mutant("ordre inversé le long du segment", "if p.t ~= q.t then return p.t < q.t end", "if p.t ~= q.t then return p.t > q.t end")
  mutant("couloir sans largeur", "if d <= margin then", "if d <= 0 then")
  mutant("plafond du couloir retiré", "while #list > Q.MAX_CHUNKS do list[#list] = nil end", "")
  mutant("tuile réservée ignorée dans un chunk", "return not d.water[k] and not d.blocked[k] and occ_free(tx, ty)", "return not d.water[k] and not d.blocked[k]")
  mutant("défrichable d'un chunk ignoré", "return d ~= nil and d.clear[k] == true", "return false")
  mutant("eau d'un chunk ignorée", "return not d.water[k] and not d.blocked[k] and occ_free(tx, ty)", "return not d.blocked[k] and occ_free(tx, ty)")
  mutant("cache jamais lu", "local d = Q.get(c, ch.cx, ch.cy, tick)", "local d = nil")
  mutant("lectures au-delà de l'accord", "for i = 1, min(granted, #list) do", "for i = 1, #list do")
  mutant("demi-largeur fixe", "return max(Q.MARGIN_MIN, min(Q.MARGIN_MAX, 2 * (reach or 0)))", "return Q.MARGIN_MIN")
end

print(string.format("[MASQUES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
