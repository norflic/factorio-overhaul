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
  -- Une tourelle seule sur le côté direct : le voisin libre l'emporte (800 > 1 000 × 8 / 16 = 500).
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
section("Cible : le départ en dernier, point d'apparition au coin de 4 secteurs (lot QG-DERNIER)")
do
  -- Le cas mesuré (tests/pvp_test.lua:1157 sur 0.6.51) : point d'apparition (0, 0), COIN des secteurs (0, 0), (0, -1), (-1, 0) et
  -- (-1, -1) ; la base de départ déborde sur (0, -1) (QG de l'équipe et ses tourelles, défense 39) et (-1, 0) ; l'avant-poste (-2, 1)
  -- est connu. Écarlate au nord, à 320 tuiles.
  local spawn = { x = 0, y = 0 }
  local from = { x = 0, y = -320 }
  local home = A.key(0, 0)
  local base = {
    { key = A.key(0, 0), x = 18, y = 10, def = 0 },
    { key = A.key(0, -1), x = 21, y = -1, def = 39 },
    { key = A.key(-1, 0), x = -4, y = 0, def = 0 },
  }
  local outpost = { key = A.key(-2, 1), x = -90, y = 96, def = 8 }
  local list = { base[1], base[2], base[3], outpost }
  check(A.pick_target(list, from, home, "equilibre").key == A.key(0, -1),
    "témoin (clé du secteur seule, la règle d'avant) : le secteur voisin du départ est visé, le défaut mesuré")
  for _, style in ipairs({ "equilibre", "tortue", "expansionniste", "inconnu" }) do
    local t = A.pick_target(list, from, home, style, { spawn })
    check(t and t.key == outpost.key, string.format("style %s : l'avant-poste connu passe avant toute la base de départ (visé (%s, %s))",
      style, tostring(t and t.x), tostring(t and t.y)))
  end
  local t2 = A.pick_target(base, from, home, "equilibre", { spawn })
  check(t2 and t2.key == A.key(0, -1), "seul le départ connu : il est visé (le plus proche de nous)")
  -- QG de votre équipe posé loin du point d'apparition : ses abords comptent aussi comme le départ ; le point d'apparition reste protégé.
  local hq = { x = 600, y = 40 }
  local near_hq = { key = A.key(9, 0), x = 590, y = 30, def = 16 }
  local far = { key = A.key(4, 3), x = 300, y = 220, def = 0 }
  local l3 = { near_hq, far, base[1] }
  local from3 = { x = 600, y = -320 }
  check(A.pick_target(l3, from3, home, "equilibre", { spawn }).key == near_hq.key, "QG d'équipe déplacé et non donné : ses abords visés d'abord (témoin)")
  check(A.pick_target(l3, from3, home, "equilibre", { spawn, hq }).key == far.key,
    "QG d'équipe déplacé : ses abords visés en dernier, comme le point d'apparition")
  -- Bord du rayon, et appel sans points (comme avant le lot).
  check(A.is_home({ key = 1, x = 64, y = 0 }, home, { spawn }) and not A.is_home({ key = 1, x = 64.5, y = 0 }, home, { spawn }),
    "rayon : 64 tuiles comprises, 64,5 non")
  check(A.is_home({ key = home, x = 999, y = 999 }, home, nil) and not A.is_home({ key = 1, x = 1, y = 1 }, home, nil),
    "sans points : la clé du secteur seule, comme avant")
  -- Mutants : chacun doit faire viser la base de départ dans le cas mesuré.
  local function refused(mut)
    local r0, i0 = A.HOME_RADIUS, A.is_home
    mut()
    local t = A.pick_target(list, from, home, "equilibre", { spawn })
    A.HOME_RADIUS, A.is_home = r0, i0
    return t ~= nil and t.key ~= outpost.key
  end
  check(refused(function() A.HOME_RADIUS = 0 end), "mutant refusé : rayon nul (la clé du secteur seule)")
  check(refused(function()
    local i0 = A.is_home
    A.is_home = function(s, h) return i0(s, h, nil) end
  end), "mutant refusé : points du départ ignorés")
end

---------------------------------------------------------------------------------------------------
section("Zone du départ : toute la base reliée au départ (lot QG-ZONE, choix du DC du 5/11)")
do
  -- Terrain simulé : bâtiments carrés de `w` tuiles posés sur la grille des tuiles, boîte de collision rentrée de 0,1 (comme le moteur) ;
  -- une maille est occupée quand une boîte la TOUCHE (intervalles fermés, F96 : le comptage moteur fait de même).
  local function bld(x, y, w)
    w = w or 3
    return { x0 = x + 0.1, y0 = y + 0.1, x1 = x + w - 0.1, y1 = y + w - 0.1, cx = x + w / 2, cy = y + w / 2, tx = x, ty = y, w = w,
      kind = "assembling-machine" }
  end
  -- `types` (facultatif) : types qui relient (A.link_types) ; un bâtiment d'un autre type n'occupe pas sa maille.
  local function terrain(boxes, types)
    local set
    if types then
      set = {}
      for _, ty in ipairs(types) do set[ty] = true end
    end
    return { boxes = boxes, calls = 0, types = set }
  end
  local function occupied(t, cx, cy)
    t.calls = t.calls + 1
    local c = A.ZONE_CELL
    local x0, y0, x1, y1 = cx * c, cy * c, cx * c + c, cy * c + c
    for _, b in ipairs(t.boxes) do
      if (not t.types or t.types[b.kind]) and b.x0 <= x1 and b.x1 >= x0 and b.y0 <= y1 and b.y1 >= y0 then return true end
    end
    return false
  end
  -- Calcul complet, pas à pas (budget A.ZONE_STEP) : renvoie l'état final et le plus grand nombre de comptages d'un pas.
  local function zone_of(homes, t, step_fn)
    local w = A.zone_begin(homes)
    local steps, worst, guard = 0, 0, 0
    local before = t.calls
    repeat
      local c0 = t.calls
      local done, used = (step_fn or A.zone_step)(w, occupied, A.ZONE_STEP, t)
      steps = steps + 1
      worst = math.max(worst, t.calls - c0, used)
      guard = guard + 1
    until done or guard > 100000
    return w, { steps = steps, worst = worst, calls = t.calls - before }
  end
  local function line(boxes, x_from, x_to, y, step, w)
    local x = x_from
    while x + (w or 3) <= x_to do
      boxes[#boxes + 1] = bld(x, y, w)
      x = x + step
    end
    return boxes
  end
  local function sector(b) return { key = A.key(A.sector_of(b.cx, b.cy)), x = b.cx, y = b.cy, def = 0 } end
  local spawn = { x = 0, y = 0 }
  local home = A.key(0, 0)
  local STYLES = { "equilibre", "tortue", "expansionniste", "inconnu" }

  -- A. La base grandit en ligne jusqu'à 400 tuiles du point d'apparition (bâtiments de 3 tuiles tous les 12 : trous de 9 tuiles) ; un
  -- avant-poste séparé au sud-ouest. Écarlate au nord du bout de la ligne : le bout est plus proche d'elle que l'avant-poste.
  do
    local boxes = line({}, 0, 400, 4, 12)
    local edge = boxes[#boxes]
    local op = { bld(-200, 200), bld(-196, 200), bld(-192, 204) }
    for _, b in ipairs(op) do boxes[#boxes + 1] = b end
    local t = terrain(boxes)
    local w = zone_of({ spawn }, t)
    local from = { x = 400, y = -320 }
    local list = { sector(boxes[1]), sector(edge), sector(op[1]) }
    local all_in = true
    for i = 1, #boxes - #op do if not A.in_zone(w.cells, boxes[i].cx, boxes[i].cy) then all_in = false end end
    check(all_in and edge.cx > 390, string.format("ligne de %d bâtiments jusqu'à %.0f tuiles du départ : toute dans la zone (%d mailles)",
      #boxes - #op, edge.cx, w.n))
    check(not A.in_zone(w.cells, op[1].cx, op[1].cy), "avant-poste séparé : hors de la zone")
    check(A.pick_target(list, from, home, "equilibre", { spawn }).key == list[2].key,
      "témoin (rayon de 64 tuiles seul, la règle de QG-DERNIER) : le bout de la base est visé avant l'avant-poste, le défaut relevé")
    for _, style in ipairs(STYLES) do
      local s = A.pick_target(list, from, home, style, { spawn }, w.cells)
      check(s and s.key == list[3].key, string.format("style %s : l'avant-poste séparé passe avant le bout de la base (visé (%s, %s))",
        style, tostring(s and s.x), tostring(s and s.y)))
    end
    local s2 = A.pick_target({ list[1], list[2] }, from, home, "equilibre", { spawn }, w.cells)
    check(s2 and s2.key == list[2].key, "seule la base connue : elle est visée (le plus proche de nous)")
  end

  -- B. Trou entre la base et un groupe de bâtiments : 20 tuiles, le groupe fait partie de la base ; 50 tuiles, c'est un avant-poste.
  do
    for _, g in ipairs({ 20, 50 }) do
      local boxes = line({}, 0, 180, 4, 12) -- dernier bâtiment : tuiles 168 à 170 (secteur 2)
      local last = boxes[#boxes]
      local start = last.tx + last.w + g -- première tuile du groupe, après `g` tuiles vides (groupe dans le secteur 3)
      local grp = { bld(start, 4), bld(start + 4, 4), bld(start + 8, 4) }
      for _, b in ipairs(grp) do boxes[#boxes + 1] = b end
      local w = zone_of({ spawn }, terrain(boxes))
      local from = { x = last.cx, y = -300 }
      local s = A.pick_target({ sector(last), sector(grp[3]) }, from, home, "equilibre", { spawn }, w.cells)
      if g == 20 then
        check(A.in_zone(w.cells, grp[3].cx, grp[3].cy), "trou de 20 tuiles : le groupe fait partie de la base de départ")
      else
        check(not A.in_zone(w.cells, grp[1].cx, grp[1].cy) and s and s.key == sector(grp[3]).key,
          "trou de 50 tuiles : avant-poste séparé, visé avant le bout de la base (plus proche de la faction)")
      end
    end
  end

  -- C. Le coffre protège toujours : QG de votre équipe posé loin du départ, sa base grandit à 150 tuiles de lui.
  do
    local boxes = line({}, 0, 40, 4, 12)
    local hq = { x = 1000, y = 1000 }
    line(boxes, 1000, 1150, 1000, 12)
    local op = bld(600, 1000)
    boxes[#boxes + 1] = op
    local t = terrain(boxes)
    local hq_edge = boxes[#boxes - 1]
    local from = { x = 1150, y = 700 }
    local list = { sector(hq_edge), sector(op) }
    local w = zone_of({ spawn, hq }, t)
    check(hq_edge.cx - hq.x > A.HOME_RADIUS and A.in_zone(w.cells, hq_edge.cx, hq_edge.cy),
      string.format("QG d'équipe loin du départ : sa base jusqu'à %.0f tuiles de lui est dans la zone", hq_edge.cx - hq.x))
    local s = A.pick_target(list, from, home, "equilibre", { spawn, hq }, w.cells)
    check(s and s.key == list[2].key, "QG d'équipe loin du départ : l'avant-poste passe avant le bout de sa base")
    local w0 = zone_of({ spawn }, terrain(boxes))
    local s0 = A.pick_target(list, from, home, "equilibre", { spawn, hq }, w0.cells)
    check(s0 and s0.key == list[1].key, "mutant refusé : le QG d'équipe n'est pas un point de départ de la zone (le bout de sa base est visé)")
  end

  -- D. Seuil du trou, mesuré dans 16 DIRECTIONS (les 8 du vent et les 8 pentes 2:1), 8 places sur la grille par direction : une chaîne
  -- de bâtiments d'une tuile tous les 24 tuiles part du point d'apparition dans la direction (trous de 23 tuiles : reliée), un bâtiment
  -- B au-delà de son bout A ; trou = distance entre les deux bâtiments (à vol d'oiseau). Attendu : moins de 32 tuiles, TOUJOURS relié ;
  -- plus de 51,2 tuiles (8 × √41 : les deux mailles reliées les plus éloignées), JAMAIS.
  local DIRS = { { 1, 0 }, { 2, 1 }, { 1, 1 }, { 1, 2 }, { 0, 1 }, { -1, 2 }, { -1, 1 }, { -2, 1 }, { -1, 0 }, { -2, -1 }, { -1, -1 },
    { -1, -2 }, { 0, -1 }, { 1, -2 }, { 1, -1 }, { 2, -1 } }
  local function tile(x, y) return bld(x, y, 1) end
  local function measure(dirs, gmin, gmax, step_fn)
    local recs = {}
    for di, d in ipairs(dirs) do
      local len = math.sqrt(d[1] * d[1] + d[2] * d[2])
      local ux, uy = d[1] / len, d[2] / len
      for j = 0, 7 do
        local ox, oy = j, (j * 3) % 8
        local chain = {}
        for k = 0, 4 do chain[#chain + 1] = tile(math.floor(ux * 24 * k + 0.5) + ox, math.floor(uy * 24 * k + 0.5) + oy) end
        local a = chain[#chain]
        local last_g = -1
        for k2 = 1, 90 do
          local bx, by = a.tx + math.floor(ux * k2 + 0.5), a.ty + math.floor(uy * k2 + 0.5)
          local gx, gy = math.max(math.abs(bx - a.tx) - 1, 0), math.max(math.abs(by - a.ty) - 1, 0)
          local g = math.sqrt(gx * gx + gy * gy)
          if g > last_g and g >= gmin and g <= gmax then
            last_g = g
            local boxes = {}
            for _, c in ipairs(chain) do boxes[#boxes + 1] = c end
            local b = tile(bx, by)
            boxes[#boxes + 1] = b
            local w = zone_of({ spawn }, terrain(boxes), step_fn)
            recs[#recs + 1] = { dir = di, g = g, linked = A.in_zone(w.cells, b.cx, b.cy) }
          end
        end
      end
    end
    return recs
  end
  local function summary(recs)
    local max_linked, min_cut, n = -1, math.huge, #recs
    local short_cut, long_linked = 0, 0
    for _, r in ipairs(recs) do
      if r.linked and r.g > max_linked then max_linked = r.g end
      if not r.linked and r.g < min_cut then min_cut = r.g end
      if r.g < 32 and not r.linked then short_cut = short_cut + 1 end -- seuil du DC (« environ 32 tuiles »), pas la constante mutée
      if r.g > 51.2 and r.linked then long_linked = long_linked + 1 end
    end
    return { max_linked = max_linked, min_cut = min_cut, n = n, short_cut = short_cut, long_linked = long_linked }
  end
  local recs = measure(DIRS, 0, 70)
  local sm = summary(recs)
  check(sm.short_cut == 0 and sm.n > 1000, string.format("trou de moins de 32 tuiles : TOUJOURS relié (%d places mesurées, 16 directions)", sm.n))
  check(sm.long_linked == 0, "trou de plus de 51,2 tuiles : JAMAIS relié")
  local by_class = { { "axes", { 1, 5, 9, 13 } }, { "diagonales", { 3, 7, 11, 15 } }, { "pentes 2:1", { 2, 4, 6, 8, 10, 12, 14, 16 } } }
  for _, cl in ipairs(by_class) do
    local sub, set = {}, {}
    for _, i in ipairs(cl[2]) do set[i] = true end
    for _, r in ipairs(recs) do if set[r.dir] then sub[#sub + 1] = r end end
    local s = summary(sub)
    print(string.format("  seuil mesuré (%s) : coupé dès %.1f tuiles, relié jusqu'à %.1f tuiles (%d places)", cl[1], s.min_cut, s.max_linked, s.n))
  end

  -- E. Mutants : chacun doit être refusé par un contrôle ci-dessus.
  do
    local g0 = A.ZONE_GAP
    A.ZONE_GAP = 16
    local m1 = summary(measure(DIRS, 20, 31.9))
    A.ZONE_GAP = g0
    check(m1.short_cut > 0, "mutant refusé : mailles reliées à moins de 16 tuiles (un trou de 20 à 31 tuiles coupe la base)")
    -- La règle d'avant la relecture : mailles de 16 tuiles reliées à 2 mailles sur chaque axe (Tchebychev) : la diagonale reliait
    -- jusqu'à 66 tuiles.
    local c0, o0 = A.ZONE_CELL, A.zone_offsets
    A.ZONE_CELL = 16
    A.zone_offsets = function()
      local l = {}
      for dy = -2, 2 do for dx = -2, 2 do if dx ~= 0 or dy ~= 0 then l[#l + 1] = dx * 262144 + dy end end end
      return l
    end
    local m2 = summary(measure({ { 1, 1 }, { -1, -1 } }, 51.3, 70))
    A.zone_offsets = function()
      local l = {}
      for _, kk in ipairs(o0()) do
        local dx = math.floor((kk + 131072) / 262144)
        if dx == 0 or kk - dx * 262144 == 0 then l[#l + 1] = kk end
      end
      return l
    end
    A.ZONE_CELL = c0
    local m3 = summary(measure({ { 1, 1 }, { -1, 1 } }, 20, 31.9))
    A.zone_offsets = o0
    check(m2.long_linked > 0, string.format("mutant refusé : mailles de 16 tuiles reliées par axe (la diagonale relie jusqu'à %.1f tuiles)", m2.max_linked))
    check(m3.short_cut > 0, "mutant refusé : voisines en croix seulement (une base qui grandit en diagonale est coupée)")
    -- Expansion depuis TOUTES les mailles testées (pas seulement les occupées) : la zone traverse les trous.
    local function flood_step(w, occ, budget, ctx)
      return A.zone_step(w, function() return true end, budget, ctx)
    end
    local boxes = line({}, 0, 200, 4, 12)
    local far = bld(260, 4)
    boxes[#boxes + 1] = far
    local wf = zone_of({ spawn }, terrain(boxes), flood_step)
    check(A.in_zone(wf.cells, far.cx, far.cy) and wf.capped, "mutant refusé : zone étendue sans bâtiment (l'avant-poste à 65 tuiles du bout de la base y entre)")
    local m0 = A.ZONE_MAX
    A.ZONE_MAX = 8
    local boxes2 = line({}, 0, 400, 4, 12)
    local wc = zone_of({ spawn }, terrain(boxes2))
    A.ZONE_MAX = m0
    check(wc.capped and not A.in_zone(wc.cells, boxes2[#boxes2].cx, boxes2[#boxes2].cy), "plafond de comptages : calcul arrêté, zone partielle signalée (capped)")
  end

  -- H. Les coffres ne relient pas (revue du lot : un coffre en bois tous les 31 tuiles faisait de toute la carte le départ) ; ils restent
  -- des cibles. Une base de machines jusqu'à 200 tuiles, puis une chaîne de coffres seuls tous les 31 tuiles (trous de 30) jusqu'à 600.
  do
    local INSTALL = { "assembling-machine", "furnace", "container", "logistic-container", "ammo-turret" }
    local lt = A.link_types(INSTALL)
    check(#lt == 3 and lt[1] == "assembling-machine" and lt[2] == "furnace" and lt[3] == "ammo-turret",
      "types qui relient : les installations sans les coffres (container, logistic-container), dans le même ordre")
    local function chest_world()
      local boxes = line({}, 0, 200, 4, 12)
      local x = 195 + 30
      while x <= 600 do
        local c = bld(x, 4, 1)
        c.kind = "container"
        boxes[#boxes + 1] = c
        x = x + 31
      end
      return boxes
    end
    local boxes = chest_world()
    local far = boxes[#boxes]
    local w = zone_of({ spawn }, terrain(boxes, lt))
    check(far.cx > 590 and not A.in_zone(w.cells, far.cx, far.cy) and A.in_zone(w.cells, boxes[1].cx, boxes[1].cy),
      string.format("chaîne de coffres seuls tous les 31 tuiles jusqu'à %.0f tuiles : hors de la zone (la base de machines y est)", far.cx))
    local u0 = A.ZONE_UNLINKED
    A.ZONE_UNLINKED = {}
    local wm = zone_of({ spawn }, terrain(chest_world(), A.link_types(INSTALL)))
    A.ZONE_UNLINKED = u0
    check(A.in_zone(wm.cells, far.cx, far.cy), "mutant refusé : les coffres relient (toute la chaîne entre dans la zone)")
  end

  -- F. Coût BORNÉ et mesuré. Base dense de 320 × 320 tuiles (40 × 40 mailles occupées) autour du point d'apparition : les mailles
  -- occupées et leur bande de voisines (comptées ici une à une), A.ZONE_STEP au plus par pas ; base de 2 000 × 2 000 tuiles : ZONE_MAX.
  do
    local occ_sq = function(t, cx, cy)
      t.calls = t.calls + 1
      return cx >= t.a and cx < t.b and cy >= t.a and cy < t.b
    end
    local side = math.floor(320 / A.ZONE_CELL)
    local t = { calls = 0, a = 0, b = side }
    local expect, seen_e = 0, {}
    for cy = 0, side - 1 do
      for cx = 0, side - 1 do
        local k0 = A.cell_key(cx, cy)
        local function add(k) if not seen_e[k] then seen_e[k] = true; expect = expect + 1 end end
        add(k0)
        for _, o in ipairs(A.zone_offsets()) do add(k0 + o) end
      end
    end
    local w = A.zone_begin({ { x = 160, y = 160 } })
    local steps, worst = 0, 0
    repeat
      local before = t.calls
      local done = A.zone_step(w, occ_sq, A.ZONE_STEP, t)
      steps = steps + 1
      worst = math.max(worst, t.calls - before)
    until done
    check(w.n == side * side and w.tests == expect and t.calls == expect and worst <= A.ZONE_STEP and steps == math.ceil(expect / A.ZONE_STEP),
      string.format("base de 320 × 320 tuiles : %d mailles, %d comptages (attendus %d) en %d pas, %d au plus par pas (budget %d)", w.n, w.tests, expect,
        steps, worst, A.ZONE_STEP))
    local R = 20 -- os.clock compte à la milliseconde sous Windows : 20 calculs entiers
    local c0 = os.clock()
    for _ = 1, R do
      local wr = A.zone_begin({ { x = 160, y = 160 } })
      repeat until A.zone_step(wr, occ_sq, A.ZONE_STEP, t)
    end
    local dt = (os.clock() - c0) / R
    print(string.format("  coût Lua (hors comptages moteur) : %.1f µs par pas, %.2f ms pour le calcul entier ; %d comptages en %d s de jeu (1 pas / 8 ticks)",
      dt * 1e6 / steps, dt * 1e3, expect, math.floor(steps * 8 / 60)))
    local half_side = math.floor(1000 / A.ZONE_CELL)
    local tb = { calls = 0, a = -half_side, b = half_side }
    local wb = A.zone_begin({ spawn })
    local n = 0
    repeat n = n + 1 until A.zone_step(wb, occ_sq, A.ZONE_STEP, tb) or n > 100000
    check(wb.capped and wb.tests == A.ZONE_MAX and tb.calls == A.ZONE_MAX,
      string.format("base de 2 000 × 2 000 tuiles : plafond de %d comptages tenu (%d), zone partielle (%d mailles)", A.ZONE_MAX, tb.calls, wb.n))
    -- Pensée d'une faction : 64 secteurs connus, zone de la base dense : lectures seulement.
    local list = {}
    for i = 0, 63 do list[#list + 1] = { key = A.key(i % 8, math.floor(i / 8)), x = (i % 8) * 64 + 20, y = math.floor(i / 8) * 64 + 20, def = i % 3 } end
    local N = 2000
    local c1 = os.clock()
    local s
    for _ = 1, N do s = A.pick_target(list, { x = 900, y = -300 }, home, "equilibre", { spawn, { x = 6, y = 6 } }, w.cells) end
    local d1 = os.clock() - c1
    local c2 = os.clock()
    for _ = 1, N do A.pick_target(list, { x = 900, y = -300 }, home, "equilibre", { spawn, { x = 6, y = 6 } }) end
    local d2 = os.clock() - c2
    check(s and not A.in_zone(w.cells, s.x, s.y), "64 secteurs connus : la cible est hors de la zone")
    print(string.format("  pensée (A.pick_target, 64 secteurs connus) : %.1f µs avec la zone, %.1f µs sans (règle de QG-DERNIER)",
      d1 * 1e6 / N, d2 * 1e6 / N))
  end

  -- G. Déterminisme : même terrain, mêmes points du départ dans l'autre ordre : même zone ; même ordre : même file.
  do
    local boxes = line({}, 0, 300, 4, 12)
    line(boxes, 1000, 1100, 1000, 12)
    local hq = { x = 1000, y = 1000 }
    local w1 = zone_of({ spawn, hq }, terrain(boxes))
    local w2 = zone_of({ hq, spawn }, terrain(boxes))
    local w3 = zone_of({ spawn, hq }, terrain(boxes))
    local same = w1.n == w2.n
    local keys = {}
    for i = 1, #w1.q do keys[#keys + 1] = w1.q[i] end
    table.sort(keys)
    for _, k in ipairs(keys) do if (w1.cells[k] or false) ~= (w2.cells[k] or false) then same = false end end
    local seq = #w1.q == #w3.q
    for i = 1, #w1.q do if w1.q[i] ~= w3.q[i] then seq = false end end
    check(same and seq and w1.n > 0, string.format("déterministe : %d mailles quel que soit l'ordre des points, même file à l'identique", w1.n))
    local cx, cy = A.cell_xy(A.cell_key(-70000, 123456))
    check(cx == -70000 and cy == 123456 and A.cell_key(-1, 0) ~= A.cell_key(0, -1), "clé de maille réversible sur toute la carte")
  end
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
