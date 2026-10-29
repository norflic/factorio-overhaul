--[[
  Lot RECO-DIRECTION : test hors jeu de la règle PURE shared/ai3/reco.lua (direction des attaques, nid connu qui l'explique, envoi,
  marche de proche en proche, carnet transmis au retour seulement, perte à la mort).

  Ce qu'il prouve :
    1. octants (8 directions, attaque au pied du QG sans direction) ;
    2. relevé : poids, point moyen, seuil d'envoi franchi une fois ; 3. décroissance entière (demi-vie, oubli, point moyen gardé) ;
    4. « expliqué » : nid connu du même octant ou d'un voisin, près du point moyen ; un ver n'explique rien ;
    5. choix : la plus attaquée non expliquée, délais respectés ; 6. étapes : dans l'octant, rayon croissant, zigzag, fin à MAX_R ;
    7. carnet : rien dans la carte de connaissance avant la transmission ; tout après ; secteur plus frais non réécrit ;
    8. mort : carnet perdu, direction toujours suspecte, renvoi après le délai seulement ;
    9. SIMULATION sur un monde caché (nids invisibles au départ) : attaques venues de l'est, éclaireur envoyé à l'est, nid vu, rentré,
       nid connu SEULEMENT après le retour ; éclaireur tué : rien de connu ; nouvel envoi après le délai, puis trouvé ;
   10. déterminisme : ordre des attaques sans effet sur le choix ;
   11. MUTANTS : chaque règle cassée fait échouer au moins un contrôle.

  Usage : lua5.2 tests/reco_test.lua   (depuis la racine du mod)
]]

package.path = "./?.lua;" .. package.path
local K = require("shared.ai3.carte")

local function load_rc()
  package.loaded["shared.ai3.reco"] = nil
  local Rc = require("shared.ai3.reco")
  package.loaded["shared.ai3.reco"] = nil
  return Rc
end

local function suite(Rc, quiet)
  local pass, fail = 0, 0
  local function check(cond, msg)
    if cond then pass = pass + 1 else fail = fail + 1; if not quiet then print("[RECO] ECHEC : " .. msg) end end
  end
  local HQ = { x = 0, y = 0 }

  -- 1. Octants.
  do
    local want = { { 100, 0, 0 }, { 100, 100, 1 }, { 0, 100, 2 }, { -100, 100, 3 }, { -100, 0, 4 }, { -100, -100, 5 }, { 0, -100, 6 },
      { 100, -100, 7 }, { 100, 30, 0 }, { 100, -30, 0 }, { 30, -100, 6 }, { -100, 45, 3 } }
    for _, w in ipairs(want) do
      check(Rc.octant(w[1], w[2]) == w[3], "octant de (" .. w[1] .. ", " .. w[2] .. ") = " .. w[3] .. " (" .. tostring(Rc.octant(w[1], w[2])) .. ")")
    end
    check(Rc.octant(3, 4) == nil, "attaque au pied du QG : aucune direction")
    check(Rc.gap(0, 7) == 1 and Rc.gap(7, 0) == 1 and Rc.gap(2, 6) == 4 and Rc.gap(1, 4) == 3, "écart entre octants (cyclique)")
    check(Rc.name(6) == "N" and Rc.name(0) == "E" and Rc.name(3) == "SO", "noms des directions")
  end

  -- 2. Relevé.
  do
    local s = Rc.new(0)
    local d, crossed = Rc.record(s, HQ, 120, 10, 100, 10)
    check(d == 0 and not crossed, "1re pièce perdue à l'est : octant E, seuil pas encore franchi")
    local d2, crossed2 = Rc.record(s, HQ, 140, -10, 100, 20)
    check(d2 == 0 and crossed2, "2e pièce : le seuil d'envoi est franchi")
    local _, crossed3 = Rc.record(s, HQ, 100, 0, 100, 30)
    check(not crossed3, "seuil franchi une seule fois")
    local c = s.sec[1]
    check(c.w == 300 and c.n == 3, "poids et nombre d'attaques (" .. c.w .. ", " .. c.n .. ")")
    check(c.mx >= 115 and c.mx <= 125 and math.abs(c.my) <= 5, "point moyen pondéré des attaques (" .. c.mx .. ", " .. c.my .. ")")
    check(Rc.record(s, HQ, 2, 2, 100, 40) == nil and s.hits == 3, "attaque au pied du QG : rien")
    check(Rc.record(s, HQ, 0, 200, 0, 40) == nil, "poids nul : rien")
  end

  -- 3. Décroissance.
  do
    local s = Rc.new(0)
    Rc.record(s, HQ, 0, -200, 1000, 0)
    Rc.decay(s, 15 * Rc.STEP)
    local w = s.sec[7].w
    check(w >= 480 and w <= 520, "demi-vie d'environ 15 min (" .. w .. ")")
    check(s.sec[7].mx == 0 and s.sec[7].my == -200, "point moyen gardé par la décroissance")
    Rc.decay(s, 15 * Rc.STEP + Rc.STEP - 1)
    check(s.sec[7].w == w, "aucun pas avant Rc.STEP ticks")
    Rc.decay(s, 200 * Rc.STEP)
    check(s.sec[7] == nil, "direction oubliée sous Rc.DROP")
    local s2 = Rc.new(0)
    Rc.record(s2, HQ, 0, -200, 300, 0)
    check(Rc.decay(s2, 10 ^ 9) == Rc.MAX_STEPS, "rattrapage borné (Rc.MAX_STEPS)")
  end

  -- 4. Expliqué par un nid connu.
  do
    local sec = { w = 300, mx = 150, my = 0, n = 3 }
    check(Rc.explained(sec, 0, HQ, { { x = 350, y = 20, kind = "spawner" } }), "nid connu à l'est, près des attaques : expliqué")
    check(Rc.explained(sec, 0, HQ, { { x = 300, y = 170, kind = "spawner" } }), "nid de l'octant voisin (SE) : expliqué")
    check(not Rc.explained(sec, 0, HQ, { { x = -300, y = 0, kind = "spawner" } }), "nid à l'opposé : pas expliqué")
    check(not Rc.explained(sec, 0, HQ, { { x = 0, y = 300, kind = "spawner" } }), "nid à 2 octants (S) : pas expliqué")
    check(not Rc.explained(sec, 0, HQ, { { x = 100, y = 250, kind = "spawner" } }), "nid proche des attaques mais au sud du QG : pas expliqué")
    check(not Rc.explained(sec, 0, HQ, { { x = 900, y = 0, kind = "spawner" } }), "nid hors de portée de la reconnaissance : pas expliqué")
    check(not Rc.explained(sec, 0, HQ, { { x = 300, y = 0, kind = "worm" } }), "un ver n'explique pas les attaques")
    check(not Rc.explained(sec, 0, HQ, {}), "aucun nid connu : pas expliqué")
    -- Cas du moteur simulé : attaques au pied de la base (59 tuiles), nid trouvé par l'éclaireur à 415 tuiles : expliqué.
    check(Rc.explained({ w = 200, mx = 64, my = 0, n = 2 }, 0, HQ, { { x = 420, y = 30, kind = "spawner" } }),
      "nid trouvé à la portée de l'éclaireur : il explique des attaques tombées près du QG")
    -- Portée : MAX_R, ou BEYOND au-delà d'attaques lointaines (avant-poste).
    check(Rc.reach({ mx = 64, my = 0 }, HQ) == Rc.MAX_R, "portée ordinaire : MAX_R")
    local far = { w = 200, mx = 400, my = 0, n = 2 }
    local R = Rc.reach(far, HQ)
    check(R == 400 + Rc.BEYOND, "attaques à 400 tuiles : portée " .. R)
    local p8 = Rc.waypoint(HQ, 0, 8, R)
    check(p8 ~= nil and Rc.waypoint(HQ, 0, 8) == nil, "les étapes vont au-delà de MAX_R quand les attaques sont lointaines")
    check(Rc.explained(far, 0, HQ, { { x = 640, y = 0, kind = "spawner" } }) and not Rc.explained(far, 0, HQ, { { x = 800, y = 0, kind = "spawner" } }),
      "explication à la même portée que la recherche")
  end

  -- 5. Choix de la direction.
  do
    local s = Rc.new(0)
    Rc.record(s, HQ, 200, 0, 100, 0)
    check(#Rc.candidates(s, 10) == 0, "une seule pièce : aucune candidate")
    Rc.record(s, HQ, 210, 5, 100, 5)
    Rc.record(s, HQ, 0, -200, 100, 6)
    Rc.record(s, HQ, 5, -210, 100, 7)
    Rc.record(s, HQ, -3, -220, 100, 8)
    local cs = Rc.candidates(s, 10)
    check(#cs == 2 and cs[1].d == 6 and cs[2].d == 0, "candidates de la plus attaquée à la moins attaquée (N puis E)")
    local none = function() return false end
    local c = Rc.pick(s, 10, none)
    check(c and c.d == 6, "choix : la plus attaquée (N)")
    local north_known = function(d) return d == 6, { x = 0, y = -300 } end
    local c2, skipped = Rc.pick(s, 10, north_known)
    check(c2 and c2.d == 0 and #skipped == 1 and skipped[1].d == 6, "nord expliqué : l'est est choisi, le nord noté expliqué")
    check(Rc.pick(s, 10, function() return true end) == nil, "tout expliqué : aucun envoi")
    Rc.on_send(s, 6)
    Rc.on_lost(s, 6, 100)
    local c3 = Rc.pick(s, 200, none)
    check(c3 and c3.d == 0, "nord en délai après la mort de l'éclaireur : l'est passe")
    check(s.sec[7] and s.sec[7].w >= Rc.SEND_MIN, "nord toujours suspect après la mort (score gardé)")
    local c4 = Rc.pick(s, 100 + Rc.COOL_DEATH, none)
    check(c4 and c4.d == 6, "délai écoulé, sans nouvelle attaque : le nord (tenu) est de nouveau choisi")
    check(s.sec[1] == nil or s.sec[1].w < s.sec[7].w, "la direction tenue n'a pas décru, l'autre si")
    local c5 = Rc.pick(s, 100 + Rc.COOL_DEATH + Rc.HOLD_AFTER - Rc.STEP, none)
    check(c5 and c5.d == 6, "le nord reste candidat pendant la fenêtre qui suit le délai (aucune nouvelle attaque)")
    Rc.on_back(s, 0, 1, 1000)
    check(s.cool[1] == 1000 + Rc.COOL_FOUND and s.found == 1, "retour avec nid : délai court")
    Rc.on_back(s, 0, 0, 2000)
    check(s.cool[1] == 2000 + Rc.COOL_EMPTY, "retour sans nid : délai long")
    check(s.sent == 1 and s.lost == 1 and s.back == 2, "compteurs d'envois, de pertes et de retours")
    -- Morts de suite : le délai double (10, 20, 40, 80 min au plus), un retour le remet à zéro.
    local s2 = Rc.new(0)
    Rc.record(s2, HQ, 0, -200, 300, 0)
    local cools = {}
    for i = 1, 6 do cools[i] = Rc.on_lost(s2, 6, i * 100) end
    check(cools[1] == Rc.COOL_DEATH and cools[2] == 2 * Rc.COOL_DEATH and cools[3] == 4 * Rc.COOL_DEATH, "délai doublé à chaque mort de suite")
    check(cools[4] == 8 * Rc.COOL_DEATH and cools[6] == 8 * Rc.COOL_DEATH, "délai plafonné (80 min)")
    Rc.on_back(s2, 6, 1, 1000)
    check(Rc.on_lost(s2, 6, 2000) == Rc.COOL_DEATH, "un retour remet le compte des morts à zéro")
  end

  -- 6. Étapes de proche en proche.
  do
    local last = 0
    local legs = 0
    for d = 0, 7 do
      local prev = -1
      local ended = false
      for leg = 1, 20 do
        local p, r = Rc.waypoint(HQ, d, leg)
        if not p then
          ended = true
          check(Rc.R0 + (leg - 1) * Rc.LEG > Rc.MAX_R, "fin des étapes seulement au-delà de MAX_R (" .. d .. ", " .. leg .. ")")
          break
        end
        legs = legs + 1
        check(r > prev, "rayon croissant")
        prev = r
        check(Rc.octant(p.x - HQ.x, p.y - HQ.y) == d, "étape dans l'octant visé (" .. d .. ", " .. leg .. " : " .. p.x .. ", " .. p.y .. ")")
        local dd = math.sqrt(p.x ^ 2 + p.y ^ 2)
        check(dd <= Rc.MAX_R + Rc.LAT + 1, "étape à portée")
        last = math.max(last, r)
      end
      check(ended, "les étapes finissent (direction " .. d .. ")")
    end
    check(last == Rc.MAX_R - (Rc.MAX_R - Rc.R0) % Rc.LEG, "dernière étape au plus près de MAX_R (" .. last .. ")")
    local a, b = Rc.waypoint(HQ, 0, 1), Rc.waypoint(HQ, 0, 2)
    local c = Rc.waypoint(HQ, 0, 3)
    check(a.y ~= b.y and b.y ~= c.y and (b.y - a.y) * (c.y - a.y) < 0, "zigzag de part et d'autre de l'axe")
    check(Rc.waypoint(HQ, 0, 0) == nil, "étape 0 : aucune")
    check(legs >= 8 * 5, "au moins 5 étapes par direction (" .. legs .. ")")
  end

  -- 7. Carnet : rien avant la transmission, tout après.
  do
    local m = K.new()
    local c = Rc.c_new()
    local k1, k2 = K.key_of(400, 10), K.key_of(330, 10)
    check(Rc.c_want(c, k1) and not Rc.c_want(c, k1), "secteur mis en file une fois")
    Rc.c_want(c, k2)
    check(Rc.c_pop(c) == k1 and Rc.c_pop(c) == k2 and Rc.c_pop(c) == nil, "file dans l'ordre d'arrivée")
    Rc.c_note(c, k1, 500, { res = {}, nests = { { x = 410, y = 12 } }, worms = { { x = 400, y = 30 } } })
    Rc.c_note(c, k2, 450, { res = { { name = "r1", n = 40, a = 1000, x = 330, y = 10 } }, nests = {}, worms = {} })
    Rc.c_note(c, k1, 900, { res = {}, nests = {}, worms = {} })
    check(c.n == 2 and c.nests == 1 and c.worms == 1, "carnet : 2 secteurs, 1 nid, 1 ver")
    check(not Rc.c_want(c, k1), "secteur déjà noté : pas remis en file")
    Rc.c_mark(c, 380, 0, 480)
    check(#K.enemy_points(m, 400, 10, 100) == 0 and K.seen(m, k1) == nil and #m.marks == 0, "AVANT le retour : la carte ne sait rien")
    -- Secteur vu plus récemment par l'équipe : pas réécrit par le carnet.
    K.record(m, k2, 600, { res = {}, nests = {}, worms = {} })
    local out = Rc.deliver(c, m)
    check(out.sectors == 1 and out.nests == 1 and out.worms == 1 and out.marks == 1, "transmission : 1 secteur (l'autre plus frais), 1 nid, 1 ver, 1 incident")
    local pts = K.enemy_points(m, 400, 10, 100)
    check(#pts == 2 and K.seen(m, k1) == 500, "APRÈS le retour : nid et ver connus, datés du regard de l'éclaireur")
    check(#K.deposits(m, "r1", HQ) == 0, "gisement d'un secteur plus frais : non réécrit")
    check(c.n == 0 and #c.q == 0 and #c.marks == 0, "carnet vidé")
    local full = Rc.c_new()
    for i = 1, Rc.CARNET_MAX + 10 do Rc.c_want(full, K.key(i, 0)) end
    check(#full.q == Rc.CARNET_MAX and #full.q <= 64, "carnet plafonné (" .. #full.q .. ")")
    check(Rc.at_home(HQ, Rc.HOME_R - 1, 0) and not Rc.at_home(HQ, Rc.HOME_R + 1, 0), "arrivée à portée de la base")
  end

  -- 9. Simulation sur un monde caché.
  do
    local NEST = { x = 360, y = 40 }
    -- Monde : le nid est invisible tant qu'un œil n'est pas à Rc.EYE tuiles ; la carte de l'équipe ne voit que le QG (160).
    local function simulate(kill_at_leg)
      local m = K.new()
      local s = Rc.new(0)
      local log = {}
      local tick = 0
      -- Le QG voit autour de lui : rien (le nid est à 362 tuiles).
      check(#K.enemy_points(m, 0, 0, 160) == 0, "monde caché : rien de connu au départ")
      -- Trois vagues tuent des pièces à l'est (tueur à 60 tuiles du QG, côté est).
      for i = 1, 3 do
        tick = tick + 600
        Rc.record(s, HQ, 60 + i, 5 - i, 100, tick)
      end
      local explain = function(d, sec) return Rc.explained(sec, d, HQ, K.enemy_points(m, HQ.x, HQ.y, Rc.explain_r(sec, HQ))) end
      local c = Rc.pick(s, tick, explain)
      if not c then return { sent = false } end
      Rc.on_send(s, c.d)
      local carnet = Rc.c_new()
      local found, dead, leg = false, false, 0
      local pos = { x = 0, y = 0 }
      while true do
        leg = leg + 1
        local wp = Rc.waypoint(HQ, c.d, leg)
        if not wp then break end
        pos = wp
        tick = tick + 600
        if kill_at_leg and leg >= kill_at_leg then dead = true break end
        if (NEST.x - pos.x) ^ 2 + (NEST.y - pos.y) ^ 2 <= Rc.EYE * Rc.EYE then
          Rc.c_note(carnet, K.key_of(NEST.x, NEST.y), tick, { res = {}, nests = { NEST }, worms = {} })
          found = true
          break
        end
      end
      local known_before = #K.enemy_points(m, NEST.x, NEST.y, 10)
      if dead then
        Rc.on_lost(s, c.d, tick)
        return { sent = true, d = c.d, dead = true, known_before = known_before, known_after = #K.enemy_points(m, NEST.x, NEST.y, 10), s = s, m = m, tick = tick }
      end
      tick = tick + 1200 -- le retour
      local out = Rc.deliver(carnet, m)
      Rc.on_back(s, c.d, out.nests, tick)
      return { sent = true, d = c.d, found = found, leg = leg, known_before = known_before,
        known_after = #K.enemy_points(m, NEST.x, NEST.y, 10), s = s, m = m, tick = tick, explain = explain }
    end
    local r = simulate(nil)
    check(r.sent and r.d == 0, "attaques de l'est : éclaireur envoyé à l'est")
    check(r.found, "le nid est vu en marchant de proche en proche (étape " .. tostring(r.leg) .. ")")
    check(r.known_before == 0, "nid vu mais pas encore connu tant que l'éclaireur n'est pas rentré")
    check(r.known_after == 1, "nid connu au retour")
    check(Rc.pick(r.s, r.tick + Rc.COOL_FOUND, r.explain) == nil, "après le retour, la direction est expliquée : plus d'envoi")
    local d = simulate(2)
    check(d.sent and d.dead and d.known_after == 0, "éclaireur tué en route : rien n'entre dans la carte")
    local again = Rc.pick(d.s, d.tick + 60, function(dd, sec) return Rc.explained(sec, dd, HQ, K.enemy_points(d.m, HQ.x, HQ.y, Rc.explain_r(sec, HQ))) end)
    check(again == nil, "tout de suite après la mort : pas de renvoi (délai)")
    -- La direction reste suspecte : les attaques continuent, nouvel envoi après le délai.
    Rc.record(d.s, HQ, 70, 0, 100, d.tick + Rc.COOL_DEATH)
    local later = Rc.pick(d.s, d.tick + Rc.COOL_DEATH, function(dd, sec) return Rc.explained(sec, dd, HQ, K.enemy_points(d.m, HQ.x, HQ.y, Rc.explain_r(sec, HQ))) end)
    check(later and later.d == 0, "délai écoulé, direction toujours suspecte : nouvel envoi vers l'est")
  end

  -- 10. Déterminisme : l'ordre des attaques ne change pas le choix.
  do
    local hits = { { 200, 0 }, { 0, 220 }, { 210, 10 }, { 0, 230 }, { 220, -5 }, { -200, 0 }, { -210, 3 } }
    local function run(order)
      local s = Rc.new(0)
      for i, j in ipairs(order) do Rc.record(s, HQ, hits[j][1], hits[j][2], 100, i) end
      local out = {}
      for _, c in ipairs(Rc.candidates(s, 100)) do out[#out + 1] = c.d .. ":" .. c.w end
      return table.concat(out, " ")
    end
    local a = run({ 1, 2, 3, 4, 5, 6, 7 })
    local b = run({ 7, 6, 5, 4, 3, 2, 1 })
    check(a == b and a == "0:300 2:200 4:200", "ordre des attaques sans effet (" .. a .. " / " .. b .. ")")
  end

  return pass, fail
end

local Rc = load_rc()
local pass, fail = suite(Rc, false)

-- 11. Mutants : chaque règle cassée doit faire échouer au moins un contrôle.
local mutants = {
  { "octant sans garde du pied du QG", function(M) M.octant = function(dx, dy) if dx == 0 and dy == 0 then return 0 end return require("shared.faction.veille").octant(dx, dy) end end },
  { "écart d'octant non cyclique", function(M) M.gap = function(a, b) return math.abs(a - b) end end },
  { "aucune décroissance", function(M) M.decay = function() return 0 end end },
  { "seuil d'envoi à zéro", function(M) M.SEND_MIN = 0 end },
  { "expliqué sans regarder l'octant", function(M)
      M.explained = function(sec, d, hq, points)
        for _, p in ipairs(points or {}) do
          if p.kind ~= "worm" and (p.x - hq.x) ^ 2 + (p.y - hq.y) ^ 2 <= M.explain_r(sec, hq) ^ 2 then return true, p end
        end
        return false
      end
    end },
  { "un ver explique", function(M)
      local e = M.explained
      M.explained = function(sec, d, hq, points)
        local pts = {}
        for _, p in ipairs(points or {}) do pts[#pts + 1] = { x = p.x, y = p.y, kind = "spawner" } end
        return e(sec, d, hq, pts)
      end
    end },
  { "délai ignoré", function(M)
      local c = M.candidates
      M.candidates = function(s, tick) local saved = s.cool; s.cool = {}; local r = c(s, tick); s.cool = saved; return r end
    end },
  { "mort sans délai", function(M) M.COOL_DEATH = 0 end },
  { "délai non doublé après des morts de suite", function(M) M.DEATH_DOUBLE_MAX = 0 end },
  { "tenue ignorée (la direction décroît pendant le délai)", function(M)
      local d = M.decay
      M.decay = function(s, tick) s.hold = {}; return d(s, tick) end
    end },
  { "mort efface la direction", function(M)
      local l = M.on_lost
      M.on_lost = function(s, d, tick) l(s, d, tick); s.sec[d + 1] = nil end
    end },
  { "étapes sans limite", function(M)
      local w = M.waypoint
      M.waypoint = function(hq, d, leg) return w(hq, d, leg, 10 ^ 6) end
    end },
  { "étapes hors de l'octant", function(M)
      local w = M.waypoint
      M.waypoint = function(hq, d, leg) return w(hq, (d + 2) % 8, leg) end
    end },
  { "carnet transmis tout de suite (noter = écrire dans la carte)", function(M)
      local K2 = require("shared.ai3.carte")
      local n, new, maps = M.c_note, K2.new, {}
      K2.new = function() local m = new(); maps[#maps + 1] = m; return m end
      M.c_note = function(c, key, t, obs)
        n(c, key, t, obs)
        for _, m in ipairs(maps) do K2.record(m, key, t, obs) end
      end
      M._restore = function() K2.new = new end
    end },
  { "secteur plus frais réécrit", function(M)
      local K2 = require("shared.ai3.carte")
      M.deliver = function(c, m)
        local out = { sectors = 0, nests = 0, worms = 0, marks = 0, fresh = {} }
        local keys = {}
        for key in pairs(c.obs) do keys[#keys + 1] = key end
        table.sort(keys)
        for _, key in ipairs(keys) do
          local e = c.obs[key]
          K2.record(m, key, e.t, e)
          out.sectors = out.sectors + 1; out.nests = out.nests + #e.nests; out.worms = out.worms + #e.worms
        end
        for _, mk in ipairs(c.marks) do K2.mark(m, mk.x, mk.y, mk.t, 500); out.marks = out.marks + 1 end
        c.q, c.inq, c.obs, c.n, c.nests, c.worms, c.marks = {}, {}, {}, 0, 0, 0, {}
        return out
      end
    end },
  { "carnet sans plafond", function(M) M.CARNET_MAX = 10 ^ 6 end },
  { "point moyen non pondéré (dernier coup)", function(M)
      local r = M.record
      M.record = function(s, hq, x, y, w, tick)
        local d, cr = r(s, hq, x, y, w, tick)
        if d then s.sec[d + 1].mx, s.sec[d + 1].my = math.floor(x), math.floor(y) end
        return d, cr
      end
    end },
}

local killed = 0
for _, mu in ipairs(mutants) do
  local M = load_rc()
  if os.getenv("RECO_DEBUG") then io.stderr:write("mutant " .. mu[1] .. string.char(10)) end
  mu[2](M)
  local ok, p, f = pcall(suite, M, true)
  if M._restore then M._restore() end
  local dead = (not ok) or f > 0
  if dead then killed = killed + 1 else print("[RECO] ECHEC : mutant SURVIVANT : " .. mu[1]) end
  if dead then pass = pass + 1 else fail = fail + 1 end
end
print(string.format("[RECO] mutants : %d/%d refusés", killed, #mutants))
print(string.format("[RECO] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
