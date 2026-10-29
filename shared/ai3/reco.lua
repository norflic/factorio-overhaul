--[[
  Lot RECO-DIRECTION : RECONNAISSANCE PAR LA DIRECTION DES ATTAQUES. Règle PURE (aucune API Factorio, aucun nom d'objet),
  déterministe, testée hors jeu par tests/reco_test.lua (avec mutants) ; exécution : script/ai3/reco.lua et la mission
  « reco » de script/ai3/exploration.lua.

  Demande du DC (29/10, vers 22 h 25, OBJECTIFS §4) : « pour les repérer (les nids de biters) il faudrait du coup détecter
  la direction dans laquelle ils viennent en gros, (comme un humain, et doivent envoyer un scout pour repérage et une fois
  qu'il l'a trouvé il revient si il meurt pas avant) ». Arbitrage PREVISION (22 h 15) : les IA voient « comme le joueur »
  (nids déjà vus, aucune triche sur la carte).

  Quatre services :
    1. DIRECTION des attaques (Rc.record, Rc.decay) : chaque pièce de l'équipe tuée par les biters donne un point (le tueur,
       sinon la pièce) ; son OCTANT vu du QG (8 directions, celles de V.octant : 0 = est, 2 = sud, 4 = ouest, 6 = nord)
       reçoit un poids et un point moyen. Décroissance entière à pas fixe (Rc.STEP ticks, Rc.NUM / Rc.DEN : demi-vie
       d'environ 15 min), jamais un temps mesuré.
    2. EXPLIQUÉ ? (Rc.explained) : une direction est expliquée par un nid CONNU de l'équipe (carte de connaissance,
       K.enemy_points : seulement ce qui a été vu) dans le même octant ou un octant voisin, à portée de ce que l'éclaireur
       fouillerait dans cette direction (Rc.reach + Rc.EYE tuiles du QG) : la même portée pour chercher et pour expliquer.
    3. ENVOI (Rc.pick, Rc.waypoint) : la direction non expliquée la plus attaquée (score au moins Rc.SEND_MIN, hors
       délai), un seul éclaireur à la fois par équipe ; il marche de proche en proche dans l'octant (étapes de Rc.LEG
       tuiles, en zigzag de ± Rc.LAT), jusqu'à voir un nid ou atteindre sa portée Rc.reach : Rc.MAX_R, ou Rc.BEYOND
       tuiles au-delà du point moyen des attaques s'il est plus loin (un avant-poste lointain attaqué).
    4. CARNET (Rc.c_*) et TRANSMISSION (Rc.deliver) : ce que l'éclaireur voit (secteurs, nids, vers, ennemis qui l'ont
       fait fuir) reste dans son carnet ; il n'entre dans la carte de connaissance de l'équipe qu'à son RETOUR (à
       Rc.HOME_R tuiles du QG). S'il meurt avant, le carnet est perdu : la direction reste suspecte (son score n'est pas
       touché) et un nouvel envoi n'est possible qu'après Rc.COOL_DEATH.

  Aucun `pairs` décisionnel (clés triées), aucune trigonométrie (vecteurs constants), aucun hasard.
]]

local V = require("shared.faction.veille")
local K = require("shared.ai3.carte")

local Rc = {}

Rc.STEP = 3600              -- ticks : un pas de décroissance
Rc.NUM, Rc.DEN = 955, 1000  -- facteur par pas (demi-vie d'environ 15 pas)
Rc.MAX_STEPS = 600          -- pas rattrapés d'un coup au plus (sauvegarde ancienne)
Rc.DROP = 20                -- centièmes : une direction en dessous est oubliée
Rc.HIT = 100                -- poids d'une pièce perdue (l'appelant peut passer le poids du front, F.weight)
Rc.SEND_MIN = 200           -- centièmes : deux pièces perdues (ou une tourelle) pour rendre une direction suspecte
Rc.MIN_DIST = 8             -- tuiles : une attaque au pied du QG ne dit rien de la direction
Rc.BEYOND = 192             -- tuiles : la reconnaissance va au moins jusque-là au-delà du point moyen des attaques
Rc.R0 = 96                  -- tuiles du QG : première étape de l'éclaireur
Rc.LEG = 64                 -- tuiles gagnées par étape (de proche en proche)
Rc.MAX_R = 480              -- tuiles du QG : portée maximale de la reconnaissance
Rc.LAT = 48                 -- tuiles : zigzag de part et d'autre de l'axe (l'octant fait 250 tuiles de large à 300)
Rc.EYE = 96                 -- tuiles : un nid à cette distance de l'éclaireur est vu
Rc.FLEE = 48                -- tuiles : un ennemi plus près le fait rentrer (il rapporte ce qu'il a vu)
Rc.HOME_R = 96              -- tuiles du QG : arrivée « à portée de la base », le carnet est transmis
Rc.MAX_TICKS = 8 * 3600     -- une reconnaissance rentre au bout de 8 min
Rc.COOL_FOUND = 5 * 3600    -- délai d'une direction après un retour avec nid (elle sera expliquée de toute façon)
Rc.COOL_EMPTY = 15 * 3600   -- délai après un retour sans nid (portée atteinte, chemin raté)
Rc.COOL_DEATH = 10 * 3600   -- délai après la mort de l'éclaireur (la direction reste suspecte)
Rc.HOLD_AFTER = 5 * 3600    -- la direction reste tenue (sans décroissance) ce temps APRÈS le délai : fenêtre du renvoi
Rc.DEATH_DOUBLE_MAX = 3     -- morts de suite dans une direction : le délai double à chaque fois, au plus 2^3 (10, 20, 40, 80 min)
Rc.CARNET_MAX = 64          -- secteurs notés au plus par carnet
Rc.MARKS_MAX = 8            -- ennemis notés au plus (fuites)
Rc.CARRY_MAX = 2            -- carnets portés par des PNJ dont la mission est finie mais qui ne sont pas encore rentrés

Rc.NAMES = { [0] = "E", "SE", "S", "SO", "O", "NO", "N", "NE" }

-- Vecteurs unitaires des octants (mêmes que K.DIRS : constants, aucune trigonométrie).
local D = 0.70710678
Rc.DIRS = { [0] = { 1, 0 }, { D, D }, { 0, 1 }, { -D, D }, { -1, 0 }, { -D, -D }, { 0, -1 }, { D, -D } }

local floor = math.floor

--- Octant (0 à 7) du vecteur (dx, dy), nil pour un point au pied du QG (moins de Rc.MIN_DIST tuiles).
function Rc.octant(dx, dy)
  if dx * dx + dy * dy < Rc.MIN_DIST * Rc.MIN_DIST then return nil end
  return V.octant(dx, dy)
end

--- Écart entre deux octants (0 à 4).
function Rc.gap(a, b)
  local g = (a - b) % 8
  return g > 4 and 8 - g or g
end

function Rc.name(d) return Rc.NAMES[d] or "?" end

--- État neuf d'une équipe (à `tick`).
function Rc.new(tick)
  return { sec = {}, cool = {}, hold = {}, t = tick or 0, sent = 0, back = 0, lost = 0, found = 0, hits = 0, carry = {} }
end

--- Décroissance jusqu'à `tick` (un pas par Rc.STEP écoulé). Rend le nombre de pas faits. Une direction TENUE (s.hold : éclaireur mort,
--- jusqu'à la fin de son délai) ne décroît pas pendant les pas qui finissent avant la fin de la tenue.
function Rc.decay(s, tick)
  local steps = floor((tick - s.t) / Rc.STEP)
  if steps <= 0 then return 0 end
  if steps > Rc.MAX_STEPS then steps = Rc.MAX_STEPS end
  local t0 = s.t
  s.t = s.t + steps * Rc.STEP
  s.hold = s.hold or {}
  for i = 1, 8 do
    local c = s.sec[i]
    if c then
      local w = c.w
      local n = steps
      local h = s.hold[i]
      if h then
        n = steps - math.max(0, math.min(steps, floor((h - t0) / Rc.STEP)))
        if h <= s.t then s.hold[i] = nil end
      end
      for _ = 1, n do
        w = floor(w * Rc.NUM / Rc.DEN)
        if w < Rc.DROP then break end
      end
      if w < Rc.DROP then s.sec[i] = nil else c.w = w end
    end
  end
  return steps
end

--- Une pièce perdue en (x, y) (le tueur, sinon la pièce), poids w. Rend l'octant (nil : au pied du QG) et vrai si la
--- direction vient de passer le seuil d'envoi avec ce coup.
function Rc.record(s, hq, x, y, w, tick)
  Rc.decay(s, tick)
  w = w or Rc.HIT
  if w <= 0 then return nil, false end
  local d = Rc.octant(x - hq.x, y - hq.y)
  if not d then return nil, false end
  local c = s.sec[d + 1]
  if not c then
    c = { w = 0, mx = 0, my = 0, n = 0 }
    s.sec[d + 1] = c
  end
  local before = c.w
  if c.w <= 0 then
    c.mx, c.my = floor(x), floor(y)
  else
    c.mx = floor((c.mx * c.w + x * w) / (c.w + w))
    c.my = floor((c.my * c.w + y * w) / (c.w + w))
  end
  c.w, c.n = c.w + w, c.n + 1
  s.hits = s.hits + 1
  return d, before < Rc.SEND_MIN and c.w >= Rc.SEND_MIN
end

--- Portée de la reconnaissance d'une direction (tuiles du QG) : Rc.MAX_R, ou Rc.BEYOND au-delà du point moyen des attaques s'il
--- est plus loin.
function Rc.reach(sec, hq)
  if not sec then return Rc.MAX_R end
  local dm = math.sqrt((sec.mx - hq.x) ^ 2 + (sec.my - hq.y) ^ 2)
  return math.max(Rc.MAX_R, floor(dm) + Rc.BEYOND)
end

--- Rayon (tuiles du QG) dans lequel un nid connu peut expliquer la direction : ce que l'éclaireur aurait vu de sa dernière étape.
function Rc.explain_r(sec, hq) return Rc.reach(sec, hq) + Rc.EYE end

--- La direction d est-elle expliquée par un nid connu ? points = { { x, y, kind = "spawner" | "worm" } } (carte de
--- connaissance). Le nid doit être dans l'octant d ou un voisin, à moins de Rc.explain_r tuiles du QG. Rend vrai et le nid, ou faux.
function Rc.explained(sec, d, hq, points)
  if not sec then return false end
  local r = Rc.explain_r(sec, hq)
  local r2 = r * r
  for _, p in ipairs(points or {}) do
    if p.kind ~= "worm" then
      local dx, dy = p.x - hq.x, p.y - hq.y
      local od = Rc.octant(dx, dy)
      if od and Rc.gap(od, d) <= 1 and dx * dx + dy * dy <= r2 then return true, p end
    end
  end
  return false
end

--- Directions candidates à l'envoi (score au moins Rc.SEND_MIN, hors délai), de la plus attaquée à la moins attaquée (à
--- égalité, l'octant le plus petit) : { { d, w, mx, my, n } }.
function Rc.candidates(s, tick)
  Rc.decay(s, tick)
  local out = {}
  for d = 0, 7 do
    local c = s.sec[d + 1]
    if c and c.w >= Rc.SEND_MIN and tick >= (s.cool[d + 1] or -1) then
      out[#out + 1] = { d = d, w = c.w, mx = c.mx, my = c.my, n = c.n }
    end
  end
  table.sort(out, function(a, b)
    if a.w ~= b.w then return a.w > b.w end
    return a.d < b.d
  end)
  return out
end

--- Direction à reconnaître : la première candidate NON expliquée. `explain(d, sec)` rend vrai si un nid connu l'explique
--- (l'appelant lit la carte de connaissance). Rend la candidate et la liste des candidates expliquées (journal), ou nil.
function Rc.pick(s, tick, explain)
  local skipped = {}
  for _, c in ipairs(Rc.candidates(s, tick)) do
    local ok, nest = explain(c.d, s.sec[c.d + 1])
    if not ok then return c, skipped end
    skipped[#skipped + 1] = { d = c.d, nest = nest }
  end
  return nil, skipped
end

--- Point de l'étape `leg` (1, 2, ...) dans l'octant d depuis le QG : rayon Rc.R0 + (leg - 1) × Rc.LEG, zigzag 0, +LAT,
--- -LAT. nil au-delà de la portée `reach` (défaut Rc.MAX_R : la reconnaissance est finie).
local ZIG = { 0, 1, -1 }
function Rc.waypoint(hq, d, leg, reach)
  local r = Rc.R0 + (leg - 1) * Rc.LEG
  if leg < 1 or r > (reach or Rc.MAX_R) then return nil end
  local v = Rc.DIRS[d]
  local o = ZIG[(leg - 1) % 3 + 1] * Rc.LAT
  return { x = floor(hq.x + v[1] * r - v[2] * o) + 0.5, y = floor(hq.y + v[2] * r + v[1] * o) + 0.5 }, r
end

--- Délais après la fin d'une reconnaissance.
function Rc.on_send(s, d)
  s.sent = s.sent + 1
  s.busy = d
end

function Rc.on_back(s, d, nests, tick)
  s.back = s.back + 1
  if s.deaths then s.deaths[d + 1] = nil end
  if nests > 0 then s.found = s.found + 1 end
  s.cool[d + 1] = tick + (nests > 0 and Rc.COOL_FOUND or Rc.COOL_EMPTY)
  if s.busy == d then s.busy = nil end
end

--- L'éclaireur n'est pas revenu : c'est un indice de plus. La direction reste suspecte (score tenu au moins à Rc.SEND_MIN, sans
--- décroissance jusqu'à Rc.HOLD_AFTER après la fin du délai) et un nouvel envoi n'est possible qu'après le délai : Rc.COOL_DEATH,
--- doublé à chaque mort de suite dans cette direction (au plus 2^Rc.DEATH_DOUBLE_MAX fois ; un retour remet le compte à zéro) :
--- on n'envoie pas un ouvrier à la mort toutes les 10 min. Rend le délai.
function Rc.on_lost(s, d, tick)
  Rc.decay(s, tick)
  s.lost = s.lost + 1
  s.deaths = s.deaths or {}
  local n = (s.deaths[d + 1] or 0) + 1
  s.deaths[d + 1] = n
  local cool = Rc.COOL_DEATH * 2 ^ math.min(n - 1, Rc.DEATH_DOUBLE_MAX)
  s.cool[d + 1] = tick + cool
  s.hold = s.hold or {}
  s.hold[d + 1] = tick + cool + Rc.HOLD_AFTER
  local c = s.sec[d + 1]
  if c then
    if c.w < Rc.SEND_MIN then c.w = Rc.SEND_MIN end
  end
  if s.busy == d then s.busy = nil end
  return cool
end

---------------------------------------------------------------------------------------------------
-- Carnet de l'éclaireur
---------------------------------------------------------------------------------------------------
function Rc.c_new() return { q = {}, inq = {}, obs = {}, n = 0, nests = 0, worms = 0, marks = {} } end

--- Secteur à noter (vu par l'œil de l'éclaireur). Faux si déjà noté, déjà en file ou carnet plein.
function Rc.c_want(c, key)
  if c.inq[key] or c.obs[key] or c.n + #c.q >= Rc.CARNET_MAX then return false end
  c.q[#c.q + 1] = key
  c.inq[key] = true
  return true
end

--- Prochain secteur à noter (ordre d'arrivée), ou nil.
function Rc.c_pop(c)
  local key = table.remove(c.q, 1)
  if key ~= nil then c.inq[key] = nil end
  return key
end

--- Ce que l'éclaireur a vu d'un secteur au tick t (obs : même forme que K.record).
function Rc.c_note(c, key, t, obs)
  if c.obs[key] then return end
  local e = { t = t, res = obs.res or {}, nests = obs.nests or {}, worms = obs.worms or {}, water = obs.water or nil }
  c.obs[key] = e
  c.n = c.n + 1
  c.nests = c.nests + #e.nests
  c.worms = c.worms + #e.worms
end

--- Ennemi qui l'a fait fuir (lieu, tick) : un incident à transmettre.
function Rc.c_mark(c, x, y, t)
  if #c.marks >= Rc.MARKS_MAX then return end
  c.marks[#c.marks + 1] = { x = floor(x), y = floor(y), t = t }
end

--- TRANSMISSION au retour : le carnet entre dans la carte de connaissance m. Un secteur que l'équipe a vu plus récemment
--- que l'éclaireur n'est pas réécrit. Le carnet est vidé. Rend { sectors, nests, worms, marks, fresh = { { key, t, names } } }.
function Rc.deliver(c, m)
  local out = { sectors = 0, nests = 0, worms = 0, marks = 0, fresh = {} }
  local keys = {}
  for key in pairs(c.obs) do keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local e = c.obs[key]
    local seen = K.seen(m, key)
    if not seen or seen < e.t then
      local names = K.record(m, key, e.t, e)
      out.sectors = out.sectors + 1
      out.nests = out.nests + #e.nests
      out.worms = out.worms + #e.worms
      if #names > 0 then out.fresh[#out.fresh + 1] = { key = key, t = e.t, names = names } end
    end
  end
  for _, mk in ipairs(c.marks) do
    K.mark(m, mk.x, mk.y, mk.t, 500)
    out.marks = out.marks + 1
  end
  c.q, c.inq, c.obs, c.n, c.nests, c.worms, c.marks = {}, {}, {}, 0, 0, 0, {}
  return out
end

--- Arrivé à portée de la base ?
function Rc.at_home(hq, x, y)
  local dx, dy = x - hq.x, y - hq.y
  return dx * dx + dy * dy <= Rc.HOME_R * Rc.HOME_R
end

return Rc
