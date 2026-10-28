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
    -- centre des 2 tourelles du QG = (14, 7) ; 3 tuiles derrière, vers le coffre (8, 7) : (11, 7)
    check(math.abs(rp.x - 11) < 1e-6 and math.abs(rp.y - 7) < 1e-6, "3 tuiles derrière le centre des tourelles du QG, côté coffre")
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
  check(hq({ rally = rp }) == "rally", "9 contre force 13, tourelles : ralliement")
  check(hq({ rally = nil, outrun = true }) == "away", "sans tourelle, ennemi distancé : on s'éloigne")
  check(hq({ rally = nil, outrun = false }) == "stand", "sans tourelle, ennemi plus rapide : on se bat, groupés")
  check(hq({ allies = 30, rally = rp }) == "stand", "plus nombreux (30 contre 13) : on se bat")
  check(hq({ force = 2, allies = 4, rally = rp }) == "stand", "4 contre force 2 : on se bat")
  check(hq({ force = 2, allies = 2, rally = rp }) == "rally", "2 contre force 2 (ratio 2 000 requis) : ralliement")
  check(hq({ prudence = 600, agressivite = 1500, allies = 3, force = 2, rally = rp }) == "stand", "un audacieux se bat à 3 contre 2")
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
mutant("point de ralliement devant les tourelles", function() patch(Re, "RALLY_BEHIND", -3) end)
mutant("toujours plus lent que nous", function() patch(Re, "outrun", function() return true end) end)
mutant("jamais distancé", function() patch(Re, "outrun", function() return false end) end)
mutant("on se bat toujours", function() patch(Re, "hq_response", function() return "stand" end) end)
mutant("on se regroupe toujours", function() patch(Re, "hq_response", function(i) return i.rally and "rally" or "away" end) end)
mutant("ratio d'engagement ignoré", function() patch(Re, "engage_ratio", function() return 1 end) end)
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
