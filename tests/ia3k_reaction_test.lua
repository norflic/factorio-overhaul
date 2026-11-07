--[[
  Lot FUITE : un PNJ en danger de mort FUIT même en plein travail (survie > défense > objectif). Banc HORS JEU de la règle
  pure shared/ai3/reaction.lua :
    - « back, back, puis flee avec refuge » : le deuxième demi-tour devant des unités mobiles est une fuite (poursuivi) ;
      devant une menace FIXE (ver, nid) le demi-tour reste un demi-tour ;
    - l'arrêt (alerte) est rompu par des unités qui franchissent portée + marge, jamais par une menace fixe ;
    - le refuge « loin de la menace » : le QG du côté de l'ennemi n'est pas un refuge ;
    - MUTANTS : chaque règle retirée fait échouer au moins un contrôle.
  Cause racine (journal fusion-60, PNJ 7, tué à 232 tuiles du QG) : script/ai3/comportement.lua (arrêt aveugle de 180 ticks,
  PNJ immobile jusqu'à sa pensée suivante après chaque réaction, QG du côté du danger) ; les valeurs ci-dessous reprennent ce
  cas : fusilier de faction (portée utile 30 = sa vue), 38 tuiles à l'arrêt, 22 au demi-tour, puis 25.
  Lancement : lua5.2 tests/ia3k_reaction_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local Re = require("shared.ai3.reaction")

local quiet = false
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC : " .. msg) end
  end
end
local function section(name) if not quiet then print("== " .. name) end end

local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

-- Le cas du journal : un fusilier (portée utile 30), le PNJ marche, armé, en pleine vie, seul contre 2.
local function unit_case(over)
  local s = { kind = "unit", range = 30, dist = 22, hp = 1000, armed = true, enemies = 2, allies = 0, walking = true,
    on_route = true }
  for k, v in pairs(over or {}) do s[k] = v end
  return s
end


-- Lot CORR-RALLIEMENT, seconde relecture (point A, coût) : RÉFÉRENCE de Re.away_pick, recopiée telle quelle du commit 878d3594
-- (e5bee46b), pour prouver que la version rapide (case mobile lue directement, filtre par direction, mémo) rend les mêmes résultats.
local D = require("shared.ai3.danger")
local AWAY_PREF = { 0, 1, 7, 2, 6, 3, 5, 4 }
local ROT = math.sqrt(0.5)
local function away_dirs(ux, uy)
  local v = { [0] = { ux, uy } }
  for k = 1, 7 do
    local x, y = v[k - 1][1], v[k - 1][2]
    v[k] = { (x - y) * ROT, (x + y) * ROT }
  end
  return v
end
local function ref_away_pick(map, tick, p, ep, range, B)
  local ex, ey = p.x - ep.x, p.y - ep.y
  local el = math.sqrt(ex * ex + ey * ey)
  if el < 1 then ex, ey, el = 1, 0, 1 end
  local ux, uy = ex / el, ey / el
  local L = Re.away_distance(range)
  local dirs = away_dirs(ux, uy)
  local m0 = D.exact_parts(map, p.x, p.y, tick).mobile
  -- Menaces fixes et morts PROCHES (au plus L + leur rayon du PNJ), poids décrus calculés une fois.
  local fx, fy, fr2, fp2, fw = {}, {}, {}, {}, {}
  for _, t in ipairs(map.threats or {}) do
    local K = D.KINDS[t.k] or D.KINDS.unit
    local r = t.r + D.EXACT_MARGIN
    local dx, dy = t.x - p.x, t.y - p.y
    local dd = dx * dx + dy * dy
    if dd <= (L + r) * (L + r) then
      local i = #fx + 1
      fx[i], fy[i], fr2[i], fp2[i] = t.x, t.y, r * r, dd
      fw[i] = math.floor(K.w * (K.fast and D.dec10(tick - t.t) or D.dec2(tick - t.t)) / 1000)
    end
  end
  local mx, my, mp2 = {}, {}, {}
  local R2 = D.DEATH_R * D.DEATH_R
  for _, d in ipairs(map.deaths or {}) do
    if not d.home and tick - d.t < D.HOUR then
      local dx, dy = d.x - p.x, d.y - p.y
      local dd = dx * dx + dy * dy
      if dd <= (L + D.DEATH_R) * (L + D.DEATH_R) then
        local i = #mx + 1
        mx[i], my[i], mp2[i] = d.x, d.y, dd
      end
    end
  end
  local best, best_k, best_v, safe = nil, nil, nil, 0
  for _, k in ipairs(AWAY_PREF) do
    local vx, vy = dirs[k][1], dirs[k][2]
    -- Rapproche de l'ennemi : (ep − p)·v > 0 (au-delà d'une tolérance de calcul).
    if (-ex) * vx + (-ey) * vy <= 1e-9 * el then
      local worst, dead = 0, {}
      local nd = 0
      local s = Re.AWAY_STEP
      while true do
        if s > L then s = L end
        local qx, qy = p.x + s * vx, p.y + s * vy
        local v = 0
        for i = 1, #fx do
          local dx, dy = fx[i] - qx, fy[i] - qy
          local dq = dx * dx + dy * dy
          if dq <= fr2[i] and (fp2[i] > fr2[i] or dq < fp2[i]) then v = v + fw[i] end
        end
        local mq = D.exact_parts(map, qx, qy, tick).mobile
        if mq > m0 then v = v + (mq - m0) end
        if v > worst then worst = v end
        for i = 1, #mx do
          if not dead[i] then
            local dx, dy = mx[i] - qx, my[i] - qy
            local dq = dx * dx + dy * dy
            if dq <= R2 and (mp2[i] > R2 or dq < mp2[i]) then dead[i], nd = true, nd + 1 end
          end
        end
        if s >= L then break end
        s = s + Re.AWAY_STEP
      end
      if nd == 0 and worst < (B or D.block(1000)) then
        safe = safe + 1
        if best_v == nil or worst < best_v then best, best_k, best_v = { x = p.x + L * vx, y = p.y + L * vy }, k, worst end
      end
    end
  end
  return best, { k = best_k, danger = best_v, safe = safe }
end

-- Cartes tirées au sort (générateur congruentiel, déterministe) autour d'un PNJ près de (0, 0), ennemi à l'est.
local function random_maps(n, seed0, nthreats, ndeaths)
  local seed = seed0
  local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648 return seed / 2147483648 end
  local kinds = { "worm", "pack", "spawner", "turret" }
  local out = {}
  for c = 1, n do
    local tick = 100000
    local m = D.new()
    for i = 1, nthreats do
      m.threats[i] = { x = (rnd() - 0.5) * 200, y = (rnd() - 0.5) * 200, k = kinds[i % 4 + 1], r = 8 + rnd() * 40,
        t = tick - math.floor(rnd() * 20000) }
    end
    for i = 1, ndeaths do
      m.deaths[i] = { x = (rnd() - 0.5) * 160, y = (rnd() - 0.5) * 160, t = tick - math.floor(rnd() * 4000), home = rnd() < 0.2 or nil }
    end
    for _ = 1, 40 do
      local k = D.key(math.floor((rnd() - 0.5) * 12), math.floor((rnd() - 0.5) * 12))
      m.cells[k] = { m = math.floor(rnd() * 900), t = tick - math.floor(rnd() * 20000) } -- jusqu'à 5,5 min : décroissance
    end
    local pp = { x = (rnd() - 0.5) * 10, y = (rnd() - 0.5) * 10 }
    local ep = { x = pp.x + 10 + rnd() * 30, y = pp.y + (rnd() - 0.5) * 40 }
    out[c] = { map = m, tick = tick, p = pp, ep = ep, range = 10 + rnd() * 30, B = 400 + math.floor(rnd() * 350) }
  end
  return out
end
local function same_pick(cases)
  local bad = 0
  for _, c in ipairs(cases) do
    local q1, i1 = ref_away_pick(c.map, c.tick, c.p, c.ep, c.range, c.B)
    local q2, i2 = Re.away_pick(c.map, c.tick, c.p, c.ep, c.range, c.B)
    local same = (q1 == nil) == (q2 == nil) and i1.k == i2.k and i1.danger == i2.danger and i1.safe == i2.safe
      and (q1 == nil or (q1.x == q2.x and q1.y == q2.y))
    if not same then bad = bad + 1 end
  end
  return bad
end
local SMALL_CASES = random_maps(40, 777, 12, 8)

local function suite()
  section("back, back, puis flee avec refuge")
  local a1, w1 = Re.decide(unit_case({ backs = 0 }))
  check(a1 == "back" and w1 == "trop-pres", "premier demi-tour devant des unités : back (" .. tostring(a1) .. ")")
  local a2, w2 = Re.decide(unit_case({ backs = 1 }))
  check(a2 == "flee" and w2 == "poursuivi", "deuxième : flee (poursuivi) (" .. tostring(a2) .. ", " .. tostring(w2) .. ")")
  check(Re.decide(unit_case({})) == "back", "sans compteur (nil) : comme 0")
  -- Le même compte vaut pour « insiste » (arrêts et détours répétés) et pour les unités qui sont à portée de vue.
  check(Re.decide(unit_case({ dist = 34, backs = 1, repeats = 2 })) == "flee", "insiste après un demi-tour : flee")
  check(Re.decide(unit_case({ dist = 34, backs = 0, repeats = 2 })) == "back", "insiste sans demi-tour : back")
  -- Les autres issues ne changent pas.
  check(Re.decide(unit_case({ dist = 34, backs = 1 })) == "detour", "entre portée et portée + marge, 1er passage : detour")
  check(Re.decide(unit_case({ dist = 45, backs = 1 })) == "stop", "au-delà de portée + marge : stop")
  check(Re.decide(unit_case({ dist = 22, backs = 1, allies = 5 })) == "engage", "en surnombre : engage, même après un demi-tour")
  check(Re.decide(unit_case({ walking = false, backs = 0 })) == "flee", "immobile à portée : flee")
  -- Lot DANGER-ACTIF (DC 4/11, 19 h 12 : « ... ou en défendant ») : sur un site de l'équipe attaqué (soldats alertés), l'ouvrier armé tient à PARITÉ
  -- (Re.SITE_RATIO) au lieu de 1 500 à 3 000 ; blessé ou désarmé, il fuit comme avant.
  check(Re.SITE_RATIO == 1000, "rapport d'engagement sur un site attaqué : la parité (1 000)")
  check(Re.decide(unit_case({ enemies = 1, allies = 0 })) ~= "engage", "hors site attaqué : seul contre 1 déchiqueteur moyen, pas d'engagement")
  check(Re.decide(unit_case({ enemies = 1, allies = 0, site_alert = true })) == "engage", "site attaqué : seul contre 1 déchiqueteur moyen, il se défend")
  check(Re.decide(unit_case({ enemies = 2, allies = 0, site_alert = true })) ~= "engage", "site attaqué : seul contre 2, la parité n'y est pas : il ne s'engage pas")
  check(Re.decide(unit_case({ enemies = 1, allies = 0, site_alert = true, armed = false })) == "flee", "site attaqué, désarmé : il fuit")
  check(Re.decide(unit_case({ enemies = 1, allies = 0, site_alert = true, hp = 300 })) == "flee", "site attaqué, blessé sous le seuil de peur : il fuit")
  -- Menace FIXE : le compteur d'unités ne la concerne pas.
  check(Re.decide({ kind = "worm", dist = 25, range = 30, hp = 1000, armed = true, walking = true, backs = 3 }) == "back",
    "ver à portée : back, quel que soit le compteur")
  check(Re.decide({ kind = "spawner", dist = 22, range = 24, hp = 1000, armed = true, walking = true, backs = 3 }) == "back",
    "nid à portée : back")
  -- La peur et l'absence d'arme restent des fuites d'emblée.
  check(Re.decide(unit_case({ hp = 300 })) == "flee", "blessé : flee")
  check(Re.decide(unit_case({ armed = false, dist = 30 })) == "flee", "sans munitions : flee")

  section("l'arrêt garde les yeux ouverts")
  check(Re.breach("unit", 22, 30) == true, "fusilier à 22 tuiles (portée 30) : l'arrêt est rompu")
  check(Re.breach("unit", 38, 30) == true, "à portée + marge exactement : rompu")
  check(Re.breach("unit", 39, 30) == false, "au-delà de portée + marge : l'arrêt continue")
  check(Re.breach("unit", 25, nil) == false and Re.breach("unit", 24, nil) == true, "portée absente : celle du genre (16) + marge")
  check(Re.breach("worm", 5, 30) == false, "un ver ne rompt jamais l'arrêt (on ne marche pas dessus : le regard le gère)")
  check(Re.breach("spawner", 5, 30) == false, "un nid non plus")
  check(Re.breach("character", 20, nil) == true, "un personnage ennemi proche : rompu")

  section("refuge loin de la menace")
  local p, home = { x = 170, y = 165 }, { x = 8, y = 7 }
  local ep = { x = 153, y = 151 } -- entre le PNJ et le QG (cas du journal)
  local aw = Re.away_point(p, home, ep, 30)
  check(aw ~= nil, "l'ennemi est du côté du QG : point d'éloignement")
  if aw then
    check(math.abs(dist(aw, p) - Re.away_distance(30)) < 1e-6, "à portée + marge + extra de lui")
    check(dist(aw, ep) > dist(p, ep) + 50, "et il s'éloigne de l'ennemi")
    check(Re.away_distance(30) == 30 + Re.MARGIN + Re.AWAY_EXTRA, "distance dérivée de la portée lue au prototype")
    check(Re.away_distance(48) > Re.away_distance(30), "plus grande portée, plus grande distance")
  end
  check(Re.away_point(p, home, { x = 190, y = 190 }, 30) == nil, "ennemi dans le dos (QG à l'opposé) : le QG reste le refuge")
  check(Re.away_point(p, home, { x = -400, y = -300 }, 30) == nil, "ennemi plus loin que le QG : le QG reste le refuge")
  check(Re.away_point(p, home, { x = 220, y = 114 }, 30) == nil, "ennemi à 90° du QG : le QG reste le refuge")
  check(Re.away_point(p, p, ep, 30) == nil, "PNJ au QG : rien")

  section("regard périodique d'un PNJ armé à l'arrêt")
  -- Jamais regardé : le premier regard est décalé par le numéro (étalé sur une période), puis toutes les IDLE_LOOK ticks.
  local firsts = {}
  for id = 1, 30 do
    local tk = 0
    while tk <= Re.IDLE_LOOK + 1 and not Re.idle_look_due(tk, nil, id) do tk = tk + 1 end
    check(tk <= Re.IDLE_LOOK, "le premier regard du PNJ " .. id .. " vient dans la période")
    firsts[id] = tk
  end
  local distinct = {}
  for id = 1, 30 do distinct[firsts[id]] = true end
  local nd = 0
  for _ in pairs(distinct) do nd = nd + 1 end
  check(nd >= 25, "30 PNJ : au moins 25 ticks de premier regard différents (" .. nd .. ")")
  check(Re.idle_look_due(1000, 1000 - Re.IDLE_LOOK + 1, 7) == false, "regardé il y a moins d'une période : pas dû")
  check(Re.idle_look_due(1000, 1000 - Re.IDLE_LOOK, 7) == true, "regardé il y a une période : dû")
  check(Re.idle_look_due(1000, 990, 7) == false, "regardé il y a 10 ticks : pas dû")

  section("rappel et mise à l'abri : la défense reste à son poste")
  check(Re.recall_exempt("garrison") and Re.recall_exempt("fortify") and Re.recall_exempt("mine", true), "garnison, fortification, defend : exemptées")
  check(not Re.recall_exempt("ghost") and not Re.recall_exempt("service", false) and not Re.recall_exempt(nil), "les autres tâches sont rappelées")

  section("QG attaqué : se regrouper sous les tourelles")
  local home2 = { x = 8, y = 7 }
  local tur = { { x = 14, y = 0 }, { x = 14, y = 14 }, { x = 300, y = 300 } } -- la 3e est à un avant-poste
  local rp = Re.rally_point(tur, home2)
  check(rp ~= nil, "tourelles du QG : point de ralliement")
  if rp then
    -- centre des 2 tourelles du QG = (14, 7) ; Re.RALLY_BEHIND tuiles derrière, vers le coffre (8, 7) : (4, 7)
    check(math.abs(rp.x - 4) < 1e-6 and math.abs(rp.y - 7) < 1e-6, "10 tuiles derrière le centre des tourelles du QG, côté coffre")
  end
  check(Re.rally_point({ { x = 300, y = 300 } }, home2) == nil, "aucune tourelle du QG (avant-poste seulement) : pas de ralliement")
  check(Re.rally_point({}, home2) == nil and Re.rally_point(nil, home2) == nil, "aucune tourelle : pas de ralliement")
  local rp1 = Re.rally_point({ { x = 8, y = 7 } }, home2)
  check(rp1 and rp1.x == 8 and rp1.y == 7, "tourelle sur le coffre : le point est la tourelle")
  check(Re.outrun(0.12, 0.15) == true and Re.outrun(0.2, 0.15) == false and Re.outrun(nil, 0.15) == false
    and Re.outrun(0.135, 0.15) == true, "distancer : vitesse de l'ennemi <= 90 % de la nôtre")
  -- Journal int-1 : 9 PNJ armés contre 5 soldats d'Azure (force pesée ~13).
  local base = { allies = 9, force = 13, prudence = 1000, agressivite = 1000 }
  local function hq(over) local i = {} for k, v in pairs(base) do i[k] = v end for k, v in pairs(over or {}) do i[k] = v end return Re.hq_response(i) end
  check(hq({ rally = rp }) == "rally", "9 contre force 13, tourelles, ennemi plus rapide : ralliement")
  check(hq({ rally = rp, outrun = true }) == "rally", "9 contre force 13, tourelles, ennemi plus lent : ralliement quand même (s'éloigner l'entraîne loin des tourelles)")
  check(hq({ rally = nil, outrun = true }) == "away", "sans tourelle, ennemi distancé : on s'éloigne")
  check(hq({ rally = nil, outrun = false }) == "stand", "sans tourelle, ennemi plus rapide : on se bat, groupés")
  check(hq({ allies = 30, rally = rp }) == "stand", "plus nombreux (30 contre 13) : on se bat")
  check(hq({ force = 2, allies = 4, rally = rp }) == "stand", "4 contre force 2 : on se bat")
  check(hq({ force = 2, allies = 2, rally = rp }) == "rally", "2 contre force 2 (ratio 2 000 requis) : ralliement")
  check(hq({ prudence = 600, agressivite = 1500, allies = 3, force = 2, rally = rp }) == "stand", "un audacieux se bat à 3 contre 2")

  section("QG attaqué par des unités qui DÉBORDENT ses tourelles (lot CORR-RALLIEMENT)")
  -- Partie du DC rejouée (graine 717152950) : 5 mitrailleurs d'Ambre (portée 20, vitesse 0,11, 600 PV : force pesée 40) contre
  -- les tourelles du QG (portée 18) ; les PNJ (0,15) ralliés sous elles meurent un par un.
  -- Relecture (revue-danger, 18 h 12) : profils lus aux prototypes. Soldats des factions en boîte à boîte (± 0,2 :
  -- prototypes/faction.lua), tourelles de centre à centre ; demi-boîte d'une tourelle à niveaux = côté / 2 − 0,3
  -- (shared/levels/footprint.lua, F.MARGIN) ; mitrailleuse à niveaux : 18 + 0,4 par niveau, 2×2 aux niveaux 1 à 6, 3×3 aux 7 à 12,
  -- 4×4 aux 13 à 18 (shared/levels/config.lua).
  local function soldier(r) return Re.profile(r, Re.BB, { { -0.2, -0.2 }, { 0.2, 0.2 } }) end
  local function tur(r, side, mode)
    local h = side / 2 - 0.3
    return Re.profile(r, mode, { left_top = { x = -h, y = -h }, right_bottom = { x = h, y = h } })
  end
  local gunner, grenadier, rifle = soldier(20), soldier(26), soldier(16)
  local gun, laser = tur(18, 2), tur(24, 2)
  -- Portée réelle du niveau n : 18 + 0,4 × (n − 1) + L.range_bonus = (côté − 2) / 2 (shared/levels/config.lua : la portée se mesure
  -- du centre, la tourelle qui grandit la gagne ; relecture de revue-danger).
  local function lvl(n)
    local side = n <= 6 and 2 or (n <= 12 and 3 or 4)
    return tur(18 + 0.4 * (n - 1) + (side - 2) / 2, side)
  end
  check(gunner.bb == true and gun.bb == false and math.abs(gun.hx - 0.7) < 1e-9 and math.abs(gunner.hy - 0.2) < 1e-9,
    "profils : soldat en boîte à boîte (± 0,2), mitrailleuse au centre (± 0,7)")
  check(Re.profile(nil, Re.BB, nil) == nil and Re.profile(18, nil, nil).hx == 0, "profil : portée inconnue = nil ; sans boîte : 0")
  -- Oracle par force brute : distance de boîte à boîte (la plus courte entre les deux boîtes) ≤ portée, sur 720 directions, par
  -- dichotomie ; la plus grande distance de centre à centre trouvée doit être Re.reach_on (à 1e-3 près).
  local function brute_reach(r, sx, sy)
    local best = 0
    for k = 0, 719 do
      local c, s = math.cos(k * math.pi / 360), math.sin(k * math.pi / 360)
      local lo, hi = 0, r + sx + sy + 2
      for _ = 1, 60 do
        local mid = (lo + hi) / 2
        local gx = math.max(0, math.abs(mid * c) - sx)
        local gy = math.max(0, math.abs(mid * s) - sy)
        if gx * gx + gy * gy <= r * r then lo = mid else hi = mid end
      end
      if lo > best then best = lo end
    end
    return best
  end
  check(math.abs(Re.reach_on(gunner, gun.hx, gun.hy) - brute_reach(20, 0.9, 0.9)) < 1e-3
    and math.abs(Re.reach_on(gunner, 1.2, 1.2) - brute_reach(20, 1.4, 1.4)) < 1e-3
    and math.abs(Re.reach_on(gunner, 0.7, 1.7) - brute_reach(20, 0.9, 1.9)) < 1e-3,
    "atteinte en boîte à boîte = oracle par force brute (720 directions ; boîtes carrées et rectangle)")
  check(Re.reach_on(gun, 0.2, 0.2) == 18, "atteinte de centre à centre : la portée seule")
  local rg = Re.reach_on(gunner, gun.hx, gun.hy)
  check(rg >= 21.2 and rg < 21.3 and 20 + 0.9 < 21.2,
    string.format("MESURÉ : mitrailleuse du QG tuée depuis 21,2 tuiles : dans l'atteinte (%.2f), au-delà de l'axe (20,9)", rg))
  check(Re.outranges({ gunner }, { gun, gun, gun }) == true, "mitrailleur (20) contre mitrailleuses (18) : débordées")
  check(Re.outranges({ grenadier }, { gun }) == true, "grenadier (26) : débordées")
  check(Re.outranges({ rifle }, { gun, gun }) == false, "fusilier (16 + 1,27 = 17,27 < 18) : non")
  check(Re.outranges({ soldier(18) }, { gun }) == true,
    "portée égale (18 contre 18) mais modes différents : débordée (le soldat frappe depuis 19,27)")
  check(Re.outranges({ Re.profile(18, nil, nil) }, { gun }) == false and Re.gap(Re.profile(18, nil, nil), gun) == 0,
    "atteinte égale (18 contre 18, deux centres) : non, chacun frappe l'autre")
  check(Re.outranges({ soldier(20) }, { Re.profile(20, Re.BB, { { -0.7, -0.7 }, { 0.7, 0.7 } }) }) == false
    and Re.outranges({ soldier(20.01) }, { Re.profile(20, Re.BB, { { -0.7, -0.7 }, { 0.7, 0.7 } }) }) == true,
    "deux boîtes à boîte : la portée seule compte (20 contre 20 : non ; 20,01 : oui)")
  check(Re.outranges({ Re.profile(18.25, nil, nil) }, { soldier(18) }) == true
    and Re.outranges({ Re.profile(18.15, nil, nil) }, { soldier(18) }) == false,
    "ennemi au centre contre tourelle en boîte (± 0,2 + 0 : l'axe, 18,2, est le plus court) : 18,25 déborde, 18,15 non")
  check(Re.outranges({ Re.profile(1.5, Re.BB, { { -0.2, -0.2 }, { 0.2, 0.2 } }) }, { gun }) == false
    and Re.outranges({ soldier(14) }, { gun }) == false, "mordeur (1,5), cracheur (14) : non")
  -- Mitrailleuse à niveaux contre le mitrailleur (20) : erreurs de la règle d'avant (portées brutes) aux niveaux 6 à 9.
  check(Re.outranges({ gunner }, { lvl(6) }) == true, "niveau 6 (20,0 ; 2×2) : débordée (le mitrailleur frappe depuis 21,27)")
  check(Re.outranges({ gunner }, { lvl(7) }) == true and Re.outranges({ gunner }, { lvl(8) }) == true,
    "niveaux 7 et 8 (20,9 et 21,3 ; 3×3, ± 1,2) : débordées (21,98 en diagonale ; l'axe dit 21,4)")
  check(Re.outranges({ gunner }, { lvl(9) }) == true, "niveau 9 (21,7) : débordée par la diagonale seule (21,98 ; l'axe dit 21,4)")
  check(Re.outranges({ gunner }, { lvl(10) }) == false and Re.outranges({ gunner }, { lvl(13) }) == false,
    "niveau 10 (22,1) et niveau 13 (23,8 ; 4×4, atteinte 22,69) : non")
  check(Re.outranges({ gunner }, { gun, laser }) == false, "une laser (24) au QG : non (une tourelle qu'aucun ennemi ne déborde protège)")
  check(Re.outranges({ gunner }, { laser, gun }) == false, "même chose dans l'autre ordre")
  check(Re.outranges({ gunner, grenadier }, { gun, laser }) == true and Re.outranges({ grenadier, gunner }, { laser, gun }) == true,
    "mitrailleur et grenadier : la laser débordée par le grenadier (27,27 > 24), la mitrailleuse par les deux")
  check(Re.outranges({ rifle, gunner }, { gun }) == true and Re.outranges({ gunner, rifle }, { gun }) == true,
    "groupe mêlé : le plus long compte, quel que soit l'ordre")
  check(Re.outranges({}, { gun }) == false and Re.outranges(nil, { gun }) == false, "portée d'attaque inconnue (personnage) : non")
  check(Re.outranges({ gunner }, {}) == false and Re.outranges({ gunner }, nil) == false, "aucune tourelle : non")
  check(Re.outranges({ gunner }, { "?", false }) == false, "tourelles de portée inconnue : non")
  -- Point 2 de la relecture : pas de refuge sous une tourelle débordée, à moins de l'atteinte ennemie (21,27) + Re.MARGIN (8).
  local ep0 = { x = 30, y = 0 }
  local function at(x) return { x = x, y = 0 } end
  check(Re.refuge_ok({ gunner }, gun, at(12), ep0) == false, "mitrailleuse à 18 tuiles d'un mitrailleur : pas un refuge")
  check(Re.refuge_ok({ gunner }, gun, at(5), ep0) == false and Re.refuge_ok({ gunner }, gun, at(1), ep0) == false,
    "à 25 et 29 tuiles (au-delà de l'atteinte, dans la marge) : pas un refuge")
  check(Re.refuge_ok({ gunner }, gun, at(0.5), ep0) == true and Re.refuge_ok({ gunner }, gun, at(-20), ep0) == true,
    "à 29,5 et 50 tuiles (au-delà de 29,27) : refuge")
  check(Re.refuge_ok({ gunner }, gun, { x = 30 - 18 / math.sqrt(2), y = 18 / math.sqrt(2) }, ep0) == false,
    "en diagonale à 18 tuiles : pas un refuge")
  check(Re.refuge_ok({ gunner }, laser, at(12), ep0) == true, "laser (24) à 18 tuiles : refuge (non débordée)")
  check(Re.refuge_ok({ rifle }, gun, at(12), ep0) == true, "fusilier (16) : la mitrailleuse reste un refuge")
  check(Re.refuge_ok({ rifle, gunner }, gun, at(12), ep0) == false and Re.refuge_ok({ gunner, rifle }, gun, at(12), ep0) == false,
    "groupe mêlé : le mitrailleur compte, quel que soit l'ordre")
  check(Re.refuge_ok({ gunner }, nil, at(12), ep0) == true and Re.refuge_ok({}, gun, at(12), ep0) == true
    and Re.refuge_ok(nil, gun, at(12), ep0) == true, "portées inconnues : refuge (règle d'avant)")
  local gun = { allies = 9, force = 40, prudence = 1000, agressivite = 1000, rally = rp }
  local function hqg(over) local i = {} for k, v in pairs(gun) do i[k] = v end for k, v in pairs(over or {}) do i[k] = v end return Re.hq_response(i) end
  check(hqg({ outranged = true, outrun = true }) == "away", "débordées, ennemi plus lent : on s'éloigne (pas de ralliement)")
  check(hqg({ outranged = true, outrun = false }) == "stand", "débordées, ennemi plus rapide : on se bat groupés (pas de ralliement)")
  check(hqg({ outranged = false, outrun = true }) == "rally", "non débordées : ralliement (inchangé)")
  check(hqg({ outranged = nil, outrun = true }) == "rally", "débordement inconnu (nil) : ralliement (inchangé)")
  check(hqg({ outranged = true, outrun = true, allies = 200 }) == "stand", "débordées mais assez nombreux : on se bat (inchangé)")
  check(hqg({ outranged = true, outrun = true, rally = nil }) == "away", "débordées et sans tourelle : comme sans tourelle")
  -- Règle d'avant inchangée quand `outranged` est absent : toute la grille de cas de la section précédente, sans le champ.
  local same = true
  for _, al in ipairs({ 0, 2, 9, 30 }) do
    for _, fo in ipairs({ 0.2, 2, 13, 40 }) do
      for _, ru in ipairs({ false, true }) do
        for _, ra in ipairs({ false, true }) do
          local i = { allies = al, force = fo, prudence = 1000, agressivite = 1000, rally = ra and rp or nil, outrun = ru }
          local r0 = Re.hq_response(i)
          i.outranged = false
          if Re.hq_response(i) ~= r0 then same = false end
          local need = Re.engage_ratio(1000, 1000) * math.max(0.2, fo)
          local old = (al * 1000 >= need) and "stand" or (ra and "rally") or (ru and "away") or "stand"
          if r0 ~= old then same = false end
        end
      end
    end
  end
  check(same, "sans débordement (nil ou false) : la réponse d'avant sur 64 cas")
  -- Point 4 de la relecture : seules les tourelles qui MARCHENT et COUVRENT le point de ralliement sont jugées (Re.rally_judge),
  -- au lieu de toutes celles à 40 tuiles du coffre. Point en (0, 0), ennemi : mitrailleurs.
  local R0 = { x = 0, y = 0 }
  local gunt = tur(18, 2) -- (« gun » désigne plus haut l'entrée de Re.hq_response)
  local function put(q, x, ok) return { x = x, y = 0, r = q.r, bb = q.bb, hx = q.hx, hy = q.hy, ok = ok } end
  check(Re.covers(put(gunt, 18), R0) == true and Re.covers(put(gunt, 18.01), R0) == false, "couvre : portée 18 de centre à centre")
  local rect = { x = 18.15, y = 0, r = 18, bb = true, hx = 0.2, hy = 1.2 }
  check(Re.covers(rect, R0) == true and Re.covers({ x = 18.5, y = 0, r = 18, bb = true, hx = 0.2, hy = 1.2 }, R0) == false,
    "couvre, tourelle en boîte (± 0,2 × ± 1,2) : portée + la plus petite demi-boîte (18,2)")
  check(Re.covers({ x = 1, y = 0, bb = false, hx = 0, hy = 0 }, R0) == false, "tourelle de portée inconnue : ne couvre rien")
  local v, n = Re.rally_judge({ gunner }, { put(gunt, 10, true), put(laser, 30, true) }, R0)
  check(v == "deborde" and n == 1, "laser à 30 tuiles (ne couvre pas le point) : seule la mitrailleuse est jugée, débordée (règle d'avant : couvert)")
  v, n = Re.rally_judge({ gunner }, { put(gunt, 10, true), put(laser, 20, true) }, R0)
  check(v == "couvert" and n == 2, "laser à 20 tuiles (couvre le point) : couvert")
  v = Re.rally_judge({ gunner }, { put(gunt, 10, false), put(laser, 20, true) }, R0)
  check(v == "couvert", "mitrailleuse vide, laser alimentée : couvert")
  v = Re.rally_judge({ gunner }, { put(gunt, 10, true), put(laser, 20, false) }, R0)
  check(v == "deborde", "laser sans courant : seule la mitrailleuse compte, débordée")
  v, n = Re.rally_judge({ rifle }, { put(gunt, 10, false), put(gunt, 12, false) }, R0)
  check(v == "sans-tourelle" and n == 0, "toutes vides : sans tourelle (s'y rallier ne protège de rien), même contre un fusilier")
  check(Re.rally_judge({}, { put(gunt, 10, true) }, R0) == "couvert", "portée ennemie inconnue, tourelle qui marche : couvert (règle d'avant)")
  check(Re.rally_judge({ gunner }, { put(gunt, 10, true) }, nil) == "sans-tourelle", "pas de point de ralliement : sans tourelle")
  check(Re.rally_judge({ rifle }, { put(gunt, 10, nil) }, R0) == "couvert", "état inconnu (ok absent) : comptée")
  -- Seconde relecture, point C : « couvre le point » n'est pas « protège le point ». Contre-exemple de la relectrice : ralliement en
  -- (0, 0), mitrailleuse en (5, 0), laser 24 en (20, 0), mitrailleur en (−20,5 ; 0). La laser couvre le point (20 <= 24) et n'est pas
  -- débordée, mais le mitrailleur frappe les PNJ au point depuis (−20,5 ; 0), à 40,5 tuiles d'elle. Une tourelle ne compte que si elle
  -- atteint aussi l'endroit d'où l'ennemi frappe le point (sa position, ou, s'il est plus loin, le point de son trajet à son atteinte).
  local EPC = { x = -20.5, y = 0 }
  local vc = Re.rally_judge({ gunner }, { put(gunt, 5, true), put(laser, 20, true) }, R0, nil, nil, EPC)
  check(vc ~= "couvert", "contre-exemple : laser qui couvre le point mais n'atteint pas le mitrailleur : PAS couvert (" .. tostring(vc) .. ")")
  vc = Re.rally_judge({ gunner }, { put(gunt, 5, true), put(laser, -10, true) }, R0, nil, nil, EPC)
  check(vc == "couvert", "laser en (−10, 0), à 10,5 du mitrailleur : couvert (" .. tostring(vc) .. ")")
  local bit = Re.profile(1.5, Re.BB, { { -0.2, -0.2 }, { 0.2, 0.2 } })
  vc = Re.rally_judge({ bit }, { put(gunt, 5, true) }, R0, nil, nil, { x = 30, y = 0 })
  check(vc == "couvert", "mordeurs à 30 tuiles : ils frapperont le point de tout près, la mitrailleuse y porte : couvert (" .. tostring(vc) .. ")")
  vc = Re.rally_judge({ gunner }, { put(laser, 20, true) }, R0, nil, nil, { x = -60, y = 0 })
  check(vc ~= "couvert", "mitrailleur à 60 tuiles à l'ouest, laser à l'est : il frappera le point depuis 20,3 à l'ouest, hors de portée (" .. tostring(vc) .. ")")
  vc = Re.rally_judge({ gunner }, { put(laser, -10, true) }, R0, nil, nil, { x = -60, y = 0 })
  check(vc == "couvert", "mitrailleur à 60 tuiles, laser entre lui et le point : couvert (" .. tostring(vc) .. ")")
  -- Seconde relecture, point B : une tourelle « en marche » (Re.turret_ready).
  check(Re.turret_ready({ type = "ammo-turret", ammo = true }) == true and Re.turret_ready({ type = "ammo-turret", ammo = false }) == false,
    "mitrailleuse : garnie oui, vide non")
  check(Re.turret_ready({ type = "electric-turret", energy = 900000, shot = 800000 }) == true, "laser : réserve d'un tir (0,9 MJ pour 0,8) : oui")
  check(Re.turret_ready({ type = "electric-turret", energy = 500000, shot = 800000 }) == false,
    "laser : réserve sous le coût d'un tir (0,5 MJ pour 0,8) : non (energy > 0 disait oui)")
  check(Re.turret_ready({ type = "electric-turret", energy = 900000, shot = 800000, off = true }) == false,
    "laser : statut sans courant ou courant faible, réserve pleine : non")
  check(Re.turret_ready({ type = "electric-turret", energy = 1 }) == true and Re.turret_ready({ type = "electric-turret", energy = 0 }) == false,
    "laser, coût d'un tir inconnu : réserve non nulle")
  check(Re.turret_ready({ type = "fluid-turret", fluid = 40 }) == true and Re.turret_ready({ type = "fluid-turret", fluid = 0 }) == false
    and Re.turret_ready({ type = "fluid-turret" }) == false, "lance-flammes : avec fluide oui, sans non")
  check(Re.turret_ready({ type = "artillery-turret" }) == true, "autre type : oui")
  -- Point 3 de la relecture : « s'éloigner » sur 8 directions jugées par la carte du danger (Re.away_pick). PNJ en (0, 0),
  -- ennemi à l'est (20, 0), vue 30 : 62 tuiles ; B = 600 (prudence neutre). Directions : k × 45° depuis l'ouest (0 : ouest,
  -- 1 : nord-ouest, 7 : sud-ouest, 2 : nord, 6 : sud).
  local Dg = require("shared.ai3.danger")
  local P0, E0, B0, T0 = { x = 0, y = 0 }, { x = 20, y = 0 }, Dg.block(1000), 7200
  local function pick(prep)
    local map = Dg.new()
    if prep then prep(map) end
    return Re.away_pick(map, T0, P0, E0, 30, B0)
  end
  local function is_at(q, x, y) return q ~= nil and math.abs(q.x - x) < 1e-6 and math.abs(q.y - y) < 1e-6 end
  local L0, c45 = Re.away_distance(30), math.sqrt(0.5)
  local q, info = pick()
  check(is_at(q, -L0, 0) and info.k == 0 and info.danger == 0 and info.safe == 5,
    "carte vide : tout droit à l'opposé (62 tuiles), 5 directions sûres (les 3 qui rapprochent de l'ennemi écartées)")
  q, info = pick(function(m) Dg.mark_seen(m, -50, 0, "worm", 30, T0) end)
  check(is_at(q, -L0 * c45, -L0 * c45) and info.k == 1, "ver sur la ligne droite : nord-ouest (le ver est à 35,4 tuiles du trajet)")
  q, info = pick(function(m) Dg.mark_seen(m, -50, 0, "worm", 30, T0) Dg.mark_seen(m, -36, -36, "worm", 30, T0) end)
  check(info.k == 7 and is_at(q, -L0 * c45, L0 * c45), "vers à l'ouest et au nord-ouest : sud-ouest")
  q, info = pick(function(m) Dg.mark_seen(m, -30, 0, "worm", 10, T0) end)
  check(info.k ~= 0, "petit ver (portée 10) au MILIEU du trajet, pas au bout : la ligne droite est écartée")
  q, info = pick(function(m)
    for _, w in ipairs({ { -40, 0 }, { -28, -28 }, { -28, 28 }, { 0, -40 }, { 0, 40 } }) do Dg.mark_seen(m, w[1], w[2], "worm", 30, T0) end
  end)
  check(q == nil and info.safe == 0, "vers dans les 5 directions qui éloignent, l'est libre : aucune sûre (nil : on se bat groupés)")
  q, info = pick(function(m) Dg.mark_death(m, -40, 0, T0 - 600) end)
  check(info.k == 1, "une mort de l'heure sur la ligne droite : nord-ouest")
  q, info = pick(function(m) Dg.mark_death(m, -40, 0, 0) end)
  local q2 = Re.away_pick((function() local m = Dg.new() Dg.mark_death(m, -40, 0, 0) return m end)(), Dg.HOUR + 7200, P0, E0, 30, B0)
  check(q2 and q2.x == -L0, "une mort de plus d'une heure : ignorée (tout droit)")
  q, info = pick(function(m) Dg.mark_death(m, -40, 0, T0 - 600, true) end)
  check(info.k == 0, "une mort au QG (home) : ignorée, comme la règle de l'heure (tout droit)")
  q, info = pick(function(m) Dg.mark_death(m, 2, 0, T0 - 600) end)
  check(info.k == 0, "une mort à 2 tuiles du PNJ, derrière lui : on s'en éloigne, elle ne compte pas (tout droit)")
  q, info = pick(function(m) Dg.mark_seen(m, 20, 0, "pack", 30, T0) end)
  check(info.k == 0, "la meute marquée autour de l'ennemi (zone qui contient le PNJ) : on s'en éloigne (tout droit)")
  q, info = pick(function(m) Dg.mark_seen(m, -20, 0, "worm", 30, T0) end)
  check(info.k == 2 and is_at(q, 0, -L0), "dans la zone d'un ver à l'ouest : ni l'ouest, ni les diagonales qui s'en rapprochent ; le nord")
  q, info = pick(function(m) for _ = 1, 5 do Dg.mark_seen(m, 20, 0, "unit", 30, T0) end end)
  check(info.k == 0, "cases mobiles de l'ennemi (5 unités, autour du PNJ aussi) : le danger AJOUTÉ seul compte (tout droit)")
  local heavy = function(m) for _ = 1, 5 do Dg.mark_seen(m, -40, 0, "unit", 6, T0) end end
  q, info = pick(heavy)
  local mw = (function() local m = Dg.new() heavy(m) return Dg.exact_parts(m, -40, 0, T0).mobile end)()
  check(mw >= B0 and info.k ~= 0 and info.danger < B0, string.format(
    "une autre meute (mobile %d) à l'ouest : pas la ligne droite (direction %s)", mw, tostring(info.k)))
  q, info = pick(function(m) Dg.mark_seen(m, -40, 0, "unit", 6, T0) end)
  check(info.k ~= 0 and info.danger == 0, "une seule unité (150, sous le seuil) à l'ouest : la direction la MOINS dangereuse (0)")
  -- Seconde relecture, point A (coût) : mêmes résultats que la référence 878d3594 (40 cartes ici ; 400 hors des mutants, plus bas).
  local bad = same_pick(SMALL_CASES)
  check(bad == 0, string.format("version rapide = référence 878d3594 sur 40 cartes tirées au sort (%d écart(s))", bad))
  local mc = Dg.new()
  for _ = 1, 3 do Dg.mark_seen(mc, -40, 0, "unit", 6, T0 - 7200) end -- 2 min : décrues
  local okm = true
  for _, pt in ipairs({ { -40, 0 }, { -25, 7 }, { 3, 3 }, { -55, -12 } }) do
    if Re.mobile_at(mc, T0, {}, pt[1], pt[2]) ~= Dg.exact_parts(mc, pt[1], pt[2], T0).mobile then okm = false end
  end
  check(okm, "case mobile lue directement = D.exact_parts(...).mobile (même décroissance)")
  -- Mémo d'un passage (Re.away_pass) : les PNJ d'une même case de 16 tuiles prennent la direction du premier.
  local calls = 0
  local ad = Re.away_dir
  Re.away_dir = function(...) calls = calls + 1 return ad(...) end
  local cache = Re.away_cache()
  local m1 = Dg.new()
  local qa = Re.away_pass(cache, m1, T0, { x = 1, y = 1 }, E0, 30, B0)
  local qb = Re.away_pass(cache, m1, T0, { x = 3, y = 5 }, E0, 30, B0)
  local qc = Re.away_pass(cache, m1, T0, { x = 20, y = 5 }, E0, 30, B0)
  Re.away_dir = ad
  check(calls == 2 and qa and qb and qc and math.abs((qb.x - 3) - (qa.x - 1)) < 1e-9 and math.abs((qb.y - 5) - (qa.y - 1)) < 1e-9,
    string.format("même case : direction du premier reprise sans calcul ; autre case : calculée (%d calculs)", calls))
  local m2 = Dg.new()
  for _, w in ipairs({ { -40, 0 }, { -28, -28 }, { -28, 28 }, { 0, -40 }, { 0, 40 } }) do Dg.mark_seen(m2, w[1], w[2], "worm", 30, T0) end
  calls = 0
  Re.away_dir = function(...) calls = calls + 1 return ad(...) end
  local c2 = Re.away_cache()
  local none = true
  for i = 1, 5 do if Re.away_pass(c2, m2, T0, { x = 1 + i, y = 2 }, E0, 30, B0) then none = false end end
  Re.away_dir = ad
  check(none and calls == 1, string.format("aucune direction sûre pour la case : nil pour ses 5 PNJ, un seul calcul (%d)", calls))
  local c3 = Re.away_cache()
  c3.dirs[Dg.key(0, 0)] = { x = 1, y = 0 } -- direction mémorisée qui mène sur l'ennemi (est) pour ce PNJ
  local q3 = Re.away_pass(c3, Dg.new(), T0, P0, E0, 30, B0)
  check(q3 ~= nil and q3.x < 0, "direction mémorisée qui RAPPROCHE ce PNJ de l'ennemi : refusée, calcul propre (ouest)")
  check(Re.on_the_way({ x = 0, y = 0 }, { x = 100, y = 0 }, { x = 30, y = 5 }) == true, "ennemi sur le chemin")
  check(Re.on_the_way({ x = 0, y = 0 }, { x = 100, y = 0 }, { x = 30, y = 60 }) == false, "ennemi sur le côté")
  check(Re.on_the_way({ x = 0, y = 0 }, { x = 100, y = 0 }, { x = 130, y = 0 }) == false, "ennemi au-delà de la cible")
end

suite()

---------------------------------------------------------------------------------------------------
-- MUTANTS : chaque règle retirée doit faire échouer au moins un contrôle.
---------------------------------------------------------------------------------------------------
do
  local bad = same_pick(random_maps(400, 4242, 48, 32))
  check(bad == 0, string.format("version rapide = référence 878d3594 sur 400 cartes pleines (48 menaces, 32 morts) (%d écart(s))", bad))
end
local base_fail = failures
print(string.format("[FUITE] suite de base : %d OK, %d ECHEC(S)", passes, failures))

local saved = {}
local function patch(t, k, v) saved[#saved + 1] = { t, k, t[k] } t[k] = v end
local function unpatch()
  for i = #saved, 1, -1 do saved[i][1][saved[i][2]] = saved[i][3] saved[i] = nil end
end
local killed, total = 0, 0
local function mutant(name, apply)
  total = total + 1
  local p0, f0 = passes, failures
  apply()
  quiet = true
  suite()
  quiet = false
  unpatch()
  local caught = failures > f0
  passes, failures = p0, f0
  if caught then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. name) end
end

mutant("jamais de fuite après un demi-tour", function()
  local d = Re.decide
  patch(Re, "decide", function(s) local a, r = d(s) if r == "poursuivi" then return "back", "trop-pres" end return a, r end)
end)
mutant("fuite dès le premier demi-tour", function() patch(Re, "BACKS", 0) end)
mutant("la menace fixe devient aussi une fuite", function()
  local d = Re.decide
  patch(Re, "decide", function(s)
    local a, r = d(s)
    if a == "back" and (s.backs or 0) >= 1 then return "flee", "poursuivi" end
    return a, r
  end)
end)
mutant("l'arrêt n'est jamais rompu", function() patch(Re, "breach", function() return false end) end)
mutant("un ver rompt l'arrêt", function() patch(Re, "breach", function(kind, d, r) return d <= (r or 16) + Re.MARGIN end) end)
mutant("marge oubliée à la rupture", function() patch(Re, "breach", function(kind, d, r) return kind == "unit" and d <= (r or 16) end) end)
mutant("regard périodique jamais dû", function() patch(Re, "idle_look_due", function() return false end) end)
mutant("regard de tous au même tick", function() patch(Re, "idle_look_due", function(tick, last) return tick - (last or 0) >= Re.IDLE_LOOK end) end)
mutant("regard à chaque pensée", function() patch(Re, "idle_look_due", function() return true end) end)
mutant("la garnison est rappelée", function() patch(Re, "recall_exempt", function(kind, defend) return defend == true end) end)
mutant("la défense est rappelée", function() patch(Re, "recall_exempt", function(kind) return Re.EXEMPT[kind] == true end) end)
mutant("tourelles d'avant-poste prises pour celles du QG", function() patch(Re, "RALLY_R", 1e6) end)
mutant("ralliement jamais", function() patch(Re, "rally_point", function() return nil end) end)
mutant("point de ralliement devant les tourelles", function() patch(Re, "RALLY_BEHIND", -10) end)
mutant("toujours plus lent que nous", function() patch(Re, "outrun", function() return true end) end)
mutant("jamais distancé", function() patch(Re, "outrun", function() return false end) end)
mutant("on se bat toujours", function() patch(Re, "hq_response", function() return "stand" end) end)
mutant("on se regroupe toujours", function() patch(Re, "hq_response", function(i) return i.rally and "rally" or "away" end) end)
mutant("éloignement avant ralliement", function()
  patch(Re, "hq_response", function(i)
    local need = Re.engage_ratio(i.prudence, i.agressivite) * math.max(0.2, i.force or 1)
    if (i.allies or 0) * 1000 >= need then return "stand" end
    if i.outrun then return "away" end
    if i.rally then return "rally" end
    return "stand"
  end)
end)
mutant("site attaqué sans effet", function() patch(Re, "SITE_RATIO", 1e9) end)
mutant("ratio d'engagement ignoré", function() patch(Re, "engage_ratio", function() return 1 end) end)
-- Lot CORR-RALLIEMENT
mutant("débordement ignoré (règle d'avant)", function()
  patch(Re, "hq_response", function(i)
    local need = Re.engage_ratio(i.prudence, i.agressivite) * math.max(0.2, i.force or 1)
    if (i.allies or 0) * 1000 >= need then return "stand" end
    if i.rally then return "rally" end
    if i.outrun then return "away" end
    return "stand"
  end)
end)
mutant("débordées : toujours s'éloigner, même plus lent que l'ennemi", function()
  local h = Re.hq_response
  patch(Re, "hq_response", function(i) local r = h(i) if i.outranged and r == "stand" and i.rally then return "away" end return r end)
end)
mutant("débordées : se rallier quand même", function()
  local h = Re.hq_response
  patch(Re, "hq_response", function(i) local r = h(i) if i.outranged and i.rally and r ~= "stand" then return "rally" end return r end)
end)
-- Relecture (revue-danger, 18 h 12) : portées ramenées au centre, tourelle par tourelle.
mutant("débordement dès l'atteinte égale", function() patch(Re, "RANGE_EPS", -1e-6) end)
mutant("portées brutes (règle d'avant : modes et boîtes ignorés)", function()
  patch(Re, "gap", function(e, t) return e.r - t.r end)
end)
mutant("axe seulement (diagonale oubliée)", function()
  patch(Re, "gap", function(e, t)
    if e.bb == t.bb then return e.r - t.r end
    local sx, sy = e.hx + t.hx, e.hy + t.hy
    if e.bb then return e.r + math.min(sx, sy) - t.r end
    return e.r - (t.r + math.min(sx, sy))
  end)
end)
mutant("demi-boîte de la tourelle oubliée", function()
  patch(Re, "gap", function(e, t)
    if e.bb == t.bb then return e.r - t.r end
    local sx, sy = e.hx, e.hy
    if e.bb then return e.r + math.sqrt(sx * sx + sy * sy) - t.r end
    return e.r - (t.r + math.min(sx, sy))
  end)
end)
mutant("ennemi au centre contre tourelle en boîte : diagonale prise", function()
  local g = Re.gap
  patch(Re, "gap", function(e, t)
    if t.bb and not e.bb then local sx, sy = e.hx + t.hx, e.hy + t.hy return e.r - (t.r + math.sqrt(sx * sx + sy * sy)) end
    return g(e, t)
  end)
end)
mutant("mode lu à l'envers", function()
  local p = Re.profile
  patch(Re, "profile", function(r, m, b) local q = p(r, m, b) if q then q.bb = not q.bb end return q end)
end)
mutant("une tourelle débordée suffit (au lieu de toutes)", function()
  patch(Re, "outranges", function(es, ts)
    for _, t in ipairs(ts or {}) do if type(t) == "table" and type(t.r) == "number" and Re.turret_outranged(es, t) then return true end end
    return false
  end)
end)
mutant("la première tourelle seule compte", function()
  patch(Re, "outranges", function(es, ts)
    local t = (ts or {})[1]
    return type(t) == "table" and type(t.r) == "number" and Re.turret_outranged(es, t)
  end)
end)
mutant("le premier ennemi seul compte", function()
  local tu = Re.turret_outranged
  patch(Re, "turret_outranged", function(es, t) return tu({ (es or {})[1] }, t) end)
end)
mutant("portée inconnue prise pour un débordement", function()
  local o = Re.outranges
  patch(Re, "outranges", function(es, ts) if es == nil or #es == 0 then return true end return o(es, ts) end)
end)
-- Point 2 : refuge
mutant("refuge sous une tourelle débordée (règle d'avant)", function() patch(Re, "refuge_ok", function() return true end) end)
mutant("toute tourelle à l'atteinte écartée, même non débordée", function()
  patch(Re, "refuge_ok", function(es, q, tp, ep)
    if type(q) ~= "table" or type(q.r) ~= "number" then return true end
    local dx, dy = tp.x - ep.x, tp.y - ep.y
    for _, e in ipairs(es or {}) do
      local lim = Re.reach_on(e, q.hx, q.hy) + Re.MARGIN
      if dx * dx + dy * dy <= lim * lim then return false end
    end
    return true
  end)
end)
mutant("refuge : marge oubliée", function()
  local m = Re.MARGIN
  local r = Re.refuge_ok
  patch(Re, "refuge_ok", function(...) Re.MARGIN = 0 local v = r(...) Re.MARGIN = m return v end)
end)
-- Seconde relecture, point C : protéger, pas seulement couvrir
mutant("protéger = couvrir (règle du point 4 : menace ignorée)", function()
  local j = Re.rally_judge
  patch(Re, "rally_judge", function(es, ts, r, px, py) return j(es, ts, r, px, py, nil) end)
end)
mutant("endroit du tir : toujours la position de la menace", function()
  patch(Re, "firing_spot", function(e, rally, ep) return { x = ep.x, y = ep.y } end)
end)
mutant("endroit du tir : le point de ralliement lui-même", function()
  patch(Re, "firing_spot", function(e, rally) return { x = rally.x, y = rally.y } end)
end)
-- Seconde relecture, point B : tourelle en marche
mutant("laser : réserve non nulle suffit (règle d'avant)", function()
  local tr = Re.turret_ready
  patch(Re, "turret_ready", function(s) if s.type == "electric-turret" then return (s.energy or 0) > 0 end return tr(s) end)
end)
mutant("laser : statut ignoré", function()
  local tr = Re.turret_ready
  patch(Re, "turret_ready", function(s) local c = {} for k, v in pairs(s) do c[k] = v end c.off = nil return tr(c) end)
end)
mutant("lance-flammes : toujours en marche", function()
  local tr = Re.turret_ready
  patch(Re, "turret_ready", function(s) if s.type == "fluid-turret" then return true end return tr(s) end)
end)
mutant("mitrailleuse vide en marche", function()
  local tr = Re.turret_ready
  patch(Re, "turret_ready", function(s) if s.type == "ammo-turret" then return true end return tr(s) end)
end)
-- Point 3 : « s'éloigner » sur 8 directions. Mutants SUR LA SOURCE (variables locales de Re.away_pick) : shared/ai3/reaction.lua
-- relu, un motif remplacé (unique, sinon le banc s'arrête), le module recompilé ; seul away_pick est pris du mutant.
local REACTION_SRC
local function src_mutant(name, old, new)
  mutant(name, function()
    if not REACTION_SRC then
      local fh = assert(io.open("shared/ai3/reaction.lua", "rb"))
      REACTION_SRC = fh:read("*a")
      fh:close()
    end
    local a, b = REACTION_SRC:find(old, 1, true)
    assert(a and not REACTION_SRC:find(old, b + 1, true), "mutant « " .. name .. " » : motif absent ou non unique")
    local R2 = assert(load(REACTION_SRC:sub(1, a - 1) .. new .. REACTION_SRC:sub(b + 1), "=reaction-mutant", "t"))()
    patch(Re, "away_pick", R2.away_pick)
  end)
end
mutant("s'éloigner : ligne droite seule (règle d'avant)", function()
  patch(Re, "away_pick", function(map, tick, p, ep, range) return Re.away_from(p, ep, range), { k = 0, danger = 0, safe = 1 } end)
end)
src_mutant("s'éloigner : menaces fixes ignorées", "then v = v + fw[i] end", "then v = v + 0 end")
src_mutant("s'éloigner : cases mobiles ignorées", "if mq > m0 then v = v + (mq - m0) end", "if false then end")
src_mutant("s'éloigner : cases mobiles en absolu (celle du PNJ comptée)", "if mq > m0 then v = v + (mq - m0) end", "v = v + mq")
src_mutant("s'éloigner : morts ignorées", "dead[i], nd = true, nd + 1", "dead[i] = true")
src_mutant("s'éloigner : zone fixe de départ comptée partout", "(fp2[i] > fr2[i] or dq < fp2[i])", "true")
src_mutant("s'éloigner : mort de départ comptée partout", "(mp2[i] > R2 or dq < mp2[i])", "true")
src_mutant("s'éloigner : morts de plus d'une heure comptées", "if not d.home and tick - d.t < D.HOUR then", "if not d.home then")
src_mutant("s'éloigner : morts au QG comptées", "if not d.home and tick - d.t < D.HOUR then", "if tick - d.t < D.HOUR then")
src_mutant("s'éloigner : directions vers l'ennemi permises", "if (-ex) * vx + (-ey) * vy <= 1e-9 * el then", "if true then")
src_mutant("s'éloigner : aucune sûre, ligne droite quand même", "return best, { k = best_k",
  "return best or { x = ux, y = uy }, { k = best_k")
src_mutant("s'éloigner : filtre par direction, menaces écartées", "if seg2(fx[i], fy[i], vx, vy) <= fr2[i] then", "if false then")
src_mutant("s'éloigner : filtre par direction, morts écartées", "if seg2(mx[i], my[i], vx, vy) <= R2 then", "if false then")
src_mutant("s'éloigner : filtre par direction, segment coupé à mi-chemin", "if s < 0 then s = 0 elseif s > L then s = L end",
  "if s < 0 then s = 0 elseif s > L / 2 then s = L / 2 end")
src_mutant("s'éloigner : case mobile sans décroissance", "m = c and math.floor(c.m * D.dec10(tick - c.t) / 1000) or 0",
  "m = c and c.m or 0")
mutant("passage : direction mémorisée reprise même si elle rapproche de l'ennemi", function()
  patch(Re, "away_pass", function(cache, map, tick, p, ep, range, B)
    local key = D.key(D.cell(p.x), D.cell(p.y))
    local c = cache.dirs[key]
    local L = Re.away_distance(range)
    if c == false then return nil end
    if c then return { x = p.x + L * c.x, y = p.y + L * c.y } end
    local v = Re.away_dir(map, tick, p, ep, range, B, cache.mob)
    cache.dirs[key] = v or false
    return v and { x = p.x + L * v.x, y = p.y + L * v.y } or nil
  end)
end)
mutant("passage : échec non mémorisé", function()
  local ap = Re.away_pass
  patch(Re, "away_pass", function(cache, ...)
    local q = ap(cache, ...)
    local ks = {}
    for k, v in pairs(cache.dirs) do if v == false then ks[#ks + 1] = k end end
    for _, k in ipairs(ks) do cache.dirs[k] = nil end
    return q
  end)
end)
src_mutant("s'éloigner : préférence ignorée (la dernière sûre)", "if best_v == nil or worst < best_v then",
  "if best_v == nil or worst <= best_v then")
src_mutant("s'éloigner : bout du trajet seul jugé", "local s = Re.AWAY_STEP", "local s = L")
-- Point 4 : tourelles jugées
mutant("ralliement : toutes les tourelles à 40 tuiles (règle d'avant)", function()
  local j = Re.rally_judge
  patch(Re, "rally_judge", function(es, ts, r, px, py)
    local all = {}
    for i, t in ipairs(ts or {}) do all[i] = { x = r and r.x or 0, y = r and r.y or 0, r = t.r, bb = t.bb, hx = t.hx, hy = t.hy, ok = t.ok } end
    return j(es, all, r, px, py)
  end)
end)
mutant("ralliement : tourelle vide ou sans courant comptée", function()
  local j = Re.rally_judge
  patch(Re, "rally_judge", function(es, ts, r, px, py)
    local all = {}
    for i, t in ipairs(ts or {}) do all[i] = { x = t.x, y = t.y, r = t.r, bb = t.bb, hx = t.hx, hy = t.hy } end
    return j(es, all, r, px, py)
  end)
end)
mutant("ralliement : sans tourelle pris pour couvert", function()
  local j = Re.rally_judge
  patch(Re, "rally_judge", function(...) local v, n = j(...) if v == "sans-tourelle" then return "couvert", n end return v, n end)
end)
mutant("couverture en boîte : la plus grande demi-boîte", function()
  patch(Re, "covers", function(t, pt, px, py)
    if type(t) ~= "table" or type(t.r) ~= "number" then return false end
    local reach = t.r
    if t.bb then reach = reach + math.max((t.hx or 0) + (px or 0), (t.hy or 0) + (py or 0)) end
    local dx, dy = t.x - pt.x, t.y - pt.y
    return dx * dx + dy * dy <= reach * reach
  end)
end)
mutant("couverture : tout couvre", function() patch(Re, "covers", function(t) return type(t) == "table" and type(t.r) == "number" end) end)
mutant("refuge : portée brute (atteinte au centre oubliée)", function()
  local ro = Re.reach_on
  local r = Re.refuge_ok
  patch(Re, "refuge_ok", function(...) Re.reach_on = function(a) return a.r end local v = r(...) Re.reach_on = ro return v end)
end)
mutant("débordement jamais", function() patch(Re, "outranges", function() return false end) end)
mutant("ennemi jamais sur le chemin", function() patch(Re, "on_the_way", function() return false end) end)
mutant("ennemi toujours sur le chemin", function() patch(Re, "on_the_way", function() return true end) end)
mutant("QG toujours le refuge", function() patch(Re, "away_point", function() return nil end) end)
mutant("éloignement vers l'ennemi", function()
  local f = Re.away_point
  patch(Re, "away_point", function(p, h, e, r)
    local q = f(p, h, e, r)
    if q then return { x = 2 * p.x - q.x, y = 2 * p.y - q.y } end
    return nil
  end)
end)
mutant("éloignement sans cône", function() patch(Re, "HOME_CONE", -1) end)
mutant("portée en dur pour l'éloignement", function() patch(Re, "away_distance", function() return 40 end) end)

print(string.format("[FUITE] MUTANTS : %d / %d refusés", killed, total))
print(string.format("[FUITE] BILAN : %d OK, %d ECHEC(S)%s", passes, failures + (total - killed),
  base_fail > 0 and " (suite de base en échec)" or ""))
os.exit((failures == 0 and killed == total) and 0 or 1)
