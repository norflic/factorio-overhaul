--[[
  Tests hors jeu du MODÈLE DE L'ADVERSAIRE (lot IA2-c) : shared/faction/adversaire.lua (pur).
  Usage, depuis la racine du mod :   lua5.2 tests/adversaire_test.lua

  Vérifie : secteurs vus (rayon + marge, sans doublon, déterministe), défense par côté (tourelle proche = tous les
  côtés, octant et voisins), côté d'arrivée (le moins défendu ; détour ; octant repoussé pénalisé ; hasard borné),
  go / no-go, moment (tempo dans ±20 %, 1re attaque Normal entre 20,8 et 31,2 min, ordre des niveaux pour tout tempo),
  styles (seuils), cible selon le style, mémoire des attaques (défense apprise, octants pénalisés, renonce).
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local A = require("shared.faction.adversaire")
local C = require("shared.faction.chef")
local Tr = require("shared.faction.traits")
local S = require("shared.faction.strategy")

local function drawer(seed) local st = Tr.new_stream(seed, 301) return function(n) return Tr.range(st, 1, n) end end

---------------------------------------------------------------------------------------------------
section("Secteurs vus")
do
  check(A.key(0, 0) == 32768 * 65536 + 32768, "clé du secteur (0, 0) = State.chunk_key")
  local sx, sy = A.xy(A.key(-3, 7))
  check(sx == -3 and sy == 7, "clé réversible")
  local list = A.visible({ { x = 0, y = 0, r = 96 } })
  local seen = {}
  local dup = false
  for _, k in ipairs(list) do
    if seen[k] then dup = true end
    seen[k] = true
  end
  check(not dup and #list > 0, "aucun doublon (" .. #list .. " secteurs)")
  check(seen[A.key(-2, 1)] == nil and seen[A.key(0, 0)], "QG à (0, 0), r = 96 : secteur (0, 0) vu, (-2, 1) (centre à 136 tuiles) non vu")
  local l2 = A.visible({ { x = 0, y = 0, r = A.VISION.scout } })
  local s2 = {}
  for _, k in ipairs(l2) do s2[k] = true end
  check(s2[A.key(-2, 1)], "éclaireur (r = 128 + 32) au départ du joueur : l'avant-poste à (-96, 96) est vu")
  local a1 = A.visible({ { x = 10, y = -30, r = 96 }, { x = 300, y = 40, r = 128 } })
  local a2 = A.visible({ { x = 10, y = -30, r = 96 }, { x = 300, y = 40, r = 128 } })
  local same = #a1 == #a2
  for i = 1, #a1 do if a1[i] ~= a2[i] then same = false end end
  check(same, "liste déterministe (même ordre)")
  check(A.sees({ { x = 0, y = 0, r = 10 } }, 6, 8) and not A.sees({ { x = 0, y = 0, r = 10 } }, 8, 8), "point vu (rayon exact)")
end

---------------------------------------------------------------------------------------------------
section("Défense par côté")
do
  local t = { x = 100, y = 100 }
  local s = A.side_defense({ { x = 102, y = 101 } }, t)
  local all = true
  for o = 0, 7 do if s[o] ~= 8 then all = false end end
  check(all, "tourelle à moins de 8 tuiles : 8 sur tous les côtés")
  s = A.side_defense({ { x = 120, y = 100 } }, t) -- à l'est (octant 0)
  check(s[0] == 8 and s[1] == 4 and s[7] == 4 and s[4] == 0 and s[2] == 0, "tourelle à l'est : octant 0 = 8, voisins 4, ouest 0")
  s = A.side_defense({ { x = 100, y = 160 } }, t)
  local zero = true
  for o = 0, 7 do if s[o] ~= 0 then zero = false end end
  check(zero, "tourelle au-delà de 40 tuiles : ignorée")
  check(A.turrets_near({ { x = 100, y = 130 }, { x = 100, y = 141 } }, t, 40) == 1, "tourelles à 40 tuiles")
end

---------------------------------------------------------------------------------------------------
section("Côté d'arrivée")
do
  -- Joueur défendu à l'est (5 tourelles), faction venant de l'est (direct = 0) : arrivée par un côté peu défendu.
  local t = { x = 0, y = 0 }
  local turrets = {}
  for i = 1, 5 do turrets[i] = { x = 20, y = -10 + 5 * i } end
  local sides = A.side_defense(turrets, t)
  local counts = {}
  for seed = 1, 200 do
    local o = A.pick_side(sides, 0, nil, drawer(seed))
    counts[o] = (counts[o] or 0) + 1
  end
  local defended = (counts[0] or 0) + (counts[1] or 0) + (counts[7] or 0)
  check(defended == 0, "5 tourelles à l'est, faction venant de l'est : jamais par l'est, le nord-est ou le sud-est (" .. defended .. " sur 200)")
  local bad = 0
  for o = 0, 7 do if (counts[o] or 0) > 0 and sides[o] > 0 then bad = bad + 1 end end
  check(bad == 0, "toujours par un côté sans défense vue")
  -- Sans défense : direct ; ex æquo : hasard borné entre options à 90 %.
  local zero = {}
  for o = 0, 7 do zero[o] = 0 end
  check(A.pick_side(zero, 3, nil, drawer(5)) == 3, "sans défense : côté direct")
  -- Octant pénalisé (attaque repoussée par le côté direct) : un autre côté.
  local o = A.pick_side(zero, 3, { [3] = true }, drawer(5))
  check(o ~= 3 and (o == 2 or o == 4), "côté direct repoussé : un voisin (" .. o .. ")")
  -- Une tourelle seule sur le côté direct : le voisin libre l'emporte (800 > 667).
  local one = {}
  for k = 0, 7 do one[k] = 0 end
  one[6] = 8
  local o2 = A.pick_side(one, 6, nil, drawer(9))
  check(o2 == 5 or o2 == 7, "une tourelle sur le côté direct : un voisin libre (" .. o2 .. ")")
end

---------------------------------------------------------------------------------------------------
section("Go / no-go")
check(A.go(20, 0.9, 8, 8), "défense inchangée : go")
check(A.go(20, 0.9, 8, 16), "défense doublée mais force suffisante (20 ≥ 0,9 × 16) : go")
check(not A.go(20, 0.9, 8, 48), "défense passée de 8 à 48, force 20 < 0,9 × 48 : renonce")
check(A.go(10, 0.9, 40, 48), "défense vue ≈ prévue (48 < 1,5 × 40 + 8) : go même sous le rapport de force (décision prise au départ)")
check(not A.go(10, 1.3, 0, 16), "rien de prévu, 2 tourelles vues, force 10 < 1,3 × 16 : renonce")

---------------------------------------------------------------------------------------------------
section("Moment")
do
  local lo, hi = 1e9, 0
  for seed = 1, 500 do
    local m = A.draw_tempo(drawer(seed))
    if m < lo then lo = m end
    if m > hi then hi = m end
  end
  check(lo >= 800 and hi <= 1200 and lo <= 810 and hi >= 1190, string.format("tempo dans ±20 %% (tirés : %d à %d)", lo, hi))
  local n_lo, n_hi = A.first_after(0, "normal", 800), A.first_after(0, "normal", 1200)
  check(n_lo >= 20 * 3600 and n_hi <= 32 * 3600, string.format("Normal : 1re attaque entre %.1f et %.1f min (D-16 : 20 à 32)", n_lo / 3600, n_hi / 3600))
  local ok = true
  for m = 800, 1200, 50 do
    if not (A.first_after(0, "easy", m) > A.first_after(0, "normal", m) and A.first_after(0, "normal", m) > A.first_after(0, "hard", m)
      and A.first_after(0, "hard", m) > A.first_after(0, "merciless", m)) then ok = false end
  end
  check(ok, "même tempo : Facile > Normal > Difficile > Impitoyable")
  check(A.first_after(0, "peaceful", 1000) == nil, "Paisible : aucun moment")
  -- Intervalle entre deux attaques × tempo : l'ordre strict des niveaux tient au pire tirage.
  local worst = true
  local L = { "easy", "normal", "hard", "merciless" }
  for i = 1, 3 do
    local slow = S.player_cooldown({ cooldown_mult = 800 }, L[i])
    local fast = S.player_cooldown({ cooldown_mult = 1200 }, L[i + 1])
    if not (slow > fast) then worst = false end
  end
  check(worst, "intervalle × tempo : un niveau plus dur reste plus rapide au pire tirage")
  check(S.player_cooldown(nil, "normal") == S.cooldown_ticks("normal"), "sans tempo : intervalle d'IA0")
end

---------------------------------------------------------------------------------------------------
section("Style")
check(A.classify({}) == "inconnu", "rien vu : inconnu")
check(A.classify({ units = 3, turrets = 9, growth = 0 }) == "tortue", "3 secteurs, 9 tourelles, sans croissance : tortue")
check(A.classify({ units = 3, turrets = 9, growth = 3 }) ~= "tortue", "tortue qui grandit vite : plus tortue")
check(A.classify({ units = 6, turrets = 2, growth = 3 }) == "expansionniste", "6 secteurs, +3 en 10 min, peu défendus : expansionniste")
check(A.classify({ units = 5, turrets = 2, growth = 0, spread = 300 }) == "expansionniste", "étendue de 300 tuiles : expansionniste")
check(A.classify({ units = 2, turrets = 0, growth = 1 }) == "batisseur", "petit, sans tourelle, qui grandit : bâtisseur")
check(A.classify({ units = 2, turrets = 2, growth = 0 }) == "equilibre", "ni l'un ni l'autre : équilibré")
check(A.classify({ units = 2, turrets = 9, hits = 3 }) == "agresseur", "3 coups reçus en 15 min : agresseur (avant tout)")
check(A.classify({ units = 2, turrets = 1, repulsed = 2 }) == "tortue", "2 attaques repoussées : tortue")
do
  local m = {}
  for i = 0, 12 do A.snap(m, { tick = i * 3600, units = i < 6 and 2 or 5, turrets = 0 }) end
  check(A.growth(m, 12 * 3600) == 3, "croissance sur 10 min (" .. A.growth(m, 12 * 3600) .. ")")
  for i = 13, 40 do A.snap(m, { tick = i * 3600, units = 5, turrets = 0 }) end
  check(#m.snaps == A.SNAPS, "relevés bornés à " .. A.SNAPS)
  check(A.recent({ 0, 10, 20 * 3600 }, 20 * 3600) == 1, "coups récents (15 min)")
end

---------------------------------------------------------------------------------------------------
section("Cible selon le style")
do
  local from = { x = 1000, y = 0 }
  local list = {
    { key = A.key(0, 0), x = 30, y = 30, def = 0 },        -- départ du joueur (en dernier)
    { key = A.key(10, 0), x = 650, y = 30, def = 40 },     -- proche de nous, défendu
    { key = A.key(5, 0), x = 330, y = 30, def = 0 },       -- loin, sans défense, isolé
    { key = A.key(9, 0), x = 590, y = 30, def = 8 },       -- voisin du défendu
  }
  check(A.pick_target(list, from, A.key(0, 0), "equilibre").key == A.key(10, 0), "par défaut : le plus proche (IA0)")
  check(A.pick_target(list, from, A.key(0, 0), "tortue").key == A.key(5, 0), "tortue : le moins défendu (harcèlement)")
  check(A.pick_target(list, from, A.key(0, 0), "expansionniste").key == A.key(5, 0), "expansionniste : le plus isolé")
  check(A.pick_target({ list[1] }, from, A.key(0, 0), "tortue").key == A.key(0, 0), "seul le départ connu : il est visé")
end

---------------------------------------------------------------------------------------------------
section("Mémoire des attaques données")
do
  local m = {}
  A.record_given(m, { gid = 1, key = 7, octant = 2, n = 15, tick = 100 })
  A.record_outcome(m, 1, "repoussee", 15, 6)
  check(m.learned[7] == 9 and m.repulsed == 1, "repoussée : défense apprise = soldats perdus (9)")
  check(A.penalized(m, 7)[2] and not A.penalized(m, 8)[2], "octant pénalisé pour ce secteur seulement")
  A.record_given(m, { gid = 2, key = 7, octant = 4, n = 20, tick = 200 })
  A.record_outcome(m, 2, "reussie", 20, 18)
  check(m.learned[7] == nil, "réussie : défense apprise effacée")
  A.record_given(m, { gid = 3, key = 8, octant = 1, n = 12, tick = 300 })
  A.record_outcome(m, 3, "renonce", 12, 12, 64)
  check(m.learned[8] == 32 and not A.penalized(m, 8)[1], "renonce : moitié de la défense vue, côté non pénalisé")
  for i = 4, 20 do A.record_given(m, { gid = i, key = 1, octant = 0, n = 5, tick = i }) end
  check(#m.given == A.MEMORY, "mémoire bornée à " .. A.MEMORY)
  check(A.record_outcome(m, 999, "reussie", 1, 1) == nil, "issue d'un groupe inconnu : ignorée")
end

---------------------------------------------------------------------------------------------------
section("Chef : côté d'arrivée et défense vue")
do
  local st = C.new(Tr.new_stream(1, 201), 0)
  local sides = {}
  for o = 0, 7 do sides[o] = 0 end
  sides[0], sides[1], sides[7] = 40, 20, 20
  local n0 = 0
  for seed = 1, 100 do
    local o = C.pick_side(st, 2, 100, 0, 1000, drawer(seed), sides)
    if o == 0 or o == 1 or o == 7 then n0 = n0 + 1 end
  end
  local m0 = 0
  for seed = 1, 100 do
    local o = C.pick_side(st, 2, 100, 0, 1000, drawer(seed))
    if o == 0 or o == 1 or o == 7 then m0 = m0 + 1 end
  end
  check(n0 < m0, string.format("défense vue à l'est : moins d'arrivées par l'est (%d contre %d sur 100 sans elle)", n0, m0))
  C.record_attack(st, { target = 2, octant = 3, n = 10, tick = 0, gid = 5 })
  local a = C.record_outcome(st, 5, "renonce", 10, 10, 100, 40)
  check(a and st.avoid[2] == 100 + C.AVOID_TICKS and st.extra_defense[2] == 20, "chef : renonce = cible évitée 10 min, défense apprise 20")
  C.record_received(st, 3, 10)
  C.record_received(st, 3, 20)
  C.record_received(st, "player", 30)
  check(C.received_recent(st, 3, 30, 100) == 2 and C.received_recent(st, "player", 30, 100) == 1, "attaques reçues par adversaire")
  C.record_loss(st, 40, 3)
  check(C.received_recent(st, 3, 40, 100) == 3, "site perdu = attaque reçue")
end

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
