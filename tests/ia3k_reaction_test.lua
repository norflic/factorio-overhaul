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
  local function lvl(n) return tur(18 + 0.4 * (n - 1), n <= 6 and 2 or (n <= 12 and 3 or 4)) end
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
  -- Mitrailleuse à niveaux contre le mitrailleur (20) : erreurs de la règle d'avant (portées brutes) aux niveaux 6 à 10.
  check(Re.outranges({ gunner }, { lvl(6) }) == true, "niveau 6 (20,0 ; 2×2) : débordée (le mitrailleur frappe depuis 21,27)")
  check(Re.outranges({ gunner }, { lvl(7) }) == true and Re.outranges({ gunner }, { lvl(8) }) == true,
    "niveaux 7 et 8 (20,4 et 20,8 ; 3×3, ± 1,2) : débordées (21,98 en diagonale, 21,4 sur l'axe)")
  check(Re.outranges({ gunner }, { lvl(10) }) == true, "niveau 10 (21,6) : débordée par la diagonale seule (21,98 ; l'axe dit 21,4)")
  check(Re.outranges({ gunner }, { lvl(11) }) == false and Re.outranges({ gunner }, { lvl(13) }) == false,
    "niveau 11 (22,0) et niveau 13 (22,8 ; 4×4, atteinte 22,69) : non")
  check(Re.outranges({ gunner }, { gun, laser }) == false, "une laser (24) au QG : non (une tourelle qu'aucun ennemi ne déborde protège)")
  check(Re.outranges({ gunner }, { laser, gun }) == false, "même chose dans l'autre ordre")
  check(Re.outranges({ gunner, grenadier }, { gun, laser }) == true and Re.outranges({ grenadier, gunner }, { laser, gun }) == true,
    "mitrailleur et grenadier : la laser débordée par le grenadier (27,27 > 24), la mitrailleuse par les deux")
  check(Re.outranges({ rifle, gunner }, { gun }) == true and Re.outranges({ gunner, rifle }, { gun }) == true,
    "groupe mêlé : le plus long compte, quel que soit l'ordre")
  check(Re.outranges({}, { gun }) == false and Re.outranges(nil, { gun }) == false, "portée d'attaque inconnue (personnage) : non")
  check(Re.outranges({ gunner }, {}) == false and Re.outranges({ gunner }, nil) == false, "aucune tourelle : non")
  check(Re.outranges({ gunner }, { "?", false }) == false, "tourelles de portée inconnue : non")
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
  -- Le refuge ne mène pas sur l'ennemi.
  check(Re.on_the_way({ x = 0, y = 0 }, { x = 100, y = 0 }, { x = 30, y = 5 }) == true, "ennemi sur le chemin")
  check(Re.on_the_way({ x = 0, y = 0 }, { x = 100, y = 0 }, { x = 30, y = 60 }) == false, "ennemi sur le côté")
  check(Re.on_the_way({ x = 0, y = 0 }, { x = 100, y = 0 }, { x = 130, y = 0 }) == false, "ennemi au-delà de la cible")
end

suite()

---------------------------------------------------------------------------------------------------
-- MUTANTS : chaque règle retirée doit faire échouer au moins un contrôle.
---------------------------------------------------------------------------------------------------
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
