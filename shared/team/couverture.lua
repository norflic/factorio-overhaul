--[[
  Lot COUVERTURE « où poser les tourelles » (constat du DC, 28/10 : « les tourelles couvrent pas assez d'espace », « une
  tourelle mitrailleuse à deux cases d'une autre »). PUR : aucune API Factorio, testé hors jeu (tests/couverture_test.lua).

  Le problème, posé comme un joueur le résout. On a des BÂTIMENTS à protéger (position, valeur), des tourelles de portée R
  et des tuiles candidates libres. Une tourelle protège un bâtiment s'il est dans son rayon utile (Cov.COVER_PCT % de la
  portée : un assaillant s'arrête à quelques tuiles du bâtiment qu'il attaque). On veut choisir n positions qui maximisent
  la valeur protégée : c'est la COUVERTURE MAXIMALE (maximum coverage), NP-difficile en général, mais l'objectif

        F(S) = Σ_bâtiment  V(bâtiment) × H(k(bâtiment, S))        k = nombre de tourelles de S qui le couvrent

  avec H croissante et CONCAVE (H(1) = 100, puis des gains décroissants : une 2e tourelle sur le même bâtiment vaut moins
  que la 1re sur un bâtiment nu) est monotone et SOUS-MODULAIRE : le glouton (prendre à chaque tour la position au plus
  grand gain marginal) garantit F(glouton) ≥ (1 − 1/e) F(optimal), soit 63,2 %. Le test le vérifie contre la force brute sur
  des centaines de petites instances (et mesure le rapport réel, très au-dessus de 63 %).

  Trois règles s'y ajoutent, toutes de l'objectif ou du départage, jamais de noms du jeu :
    - EXPOSITION : la valeur d'un bâtiment est majorée (jusqu'à × 2, Cov.EXPO_PCT) selon sa proximité RELATIVE d'une menace
      connue (nid, ver, mort récente, bâtiment déjà détruit : `threats`). Le périmètre exposé se couvre en premier ;
    - ESPACEMENT : deux tourelles ne sont jamais plus proches que Cov.SEP_PCT % de la portée (le glouton écarte les
      candidats trop proches, puis relâche l'espacement par moitiés SEULEMENT si plus rien ne passe) ; la garantie 1 − 1/e
      est celle de l'objectif sans espacement, l'espacement est un FILTRE (le test mesure le rapport avec lui aussi) ;
    - DÉPARTAGE (à gain égal) : plus près de la menace connue ; sans menace, plus loin des autres tourelles (jusqu'à deux
      fois l'espacement : « tous les côtés ») ; puis plus près du centre de valeur ; puis l'ordre (y, x) : déterminisme.

  Entrées en valeurs entières (bâtiments regroupés par cases de Cov.CLUSTER tuiles : le coût ne dépend plus de leur nombre).
  Aucune trigonométrie, aucun hasard, aucun `pairs`. Les rôles viennent du moteur (shared/ai3/reglages.lua : R.ENTITY_ROLE).
]]

local D = require("shared.ai3.danger")

local Cov = {}

Cov.COVER_PCT = 75      -- rayon utile = 75 % de la portée de la tourelle
Cov.SEP_PCT = 40        -- espacement minimal entre deux tourelles : 40 % de la portée (7,2 tuiles pour une portée de 18)
Cov.STEP = 2            -- pas de la grille des candidats (une tourelle 2 × 2 est centrée sur une coordonnée entière)
Cov.CLUSTER = 4         -- tuiles : les bâtiments d'une même case sont regroupés (centre pondéré, valeurs additionnées)
Cov.MAX_CLUSTERS = 60   -- regroupements gardés (les plus précieux)
Cov.MAX_CANDS = 1500    -- candidats au plus (le pas de la grille double sinon)
Cov.EXPO_PCT = 100      -- majoration maximale de la valeur d'un bâtiment exposé (100 % : jusqu'au double)
Cov.THREAT_REACH = 120  -- tuiles : une menace plus loin ne compte pas
Cov.HITS_TTL = 30 * 3600 -- un bâtiment détruit compte comme menace pendant 30 min

-- Gain de la k-ième couverture d'un même bâtiment (centièmes de sa valeur) : 100, 15, 10, 7, 5, 3, 2, 1 puis 0. Concave.
-- Une 2e couverture ne vaut que 15 % de la 1re : couvrir de l'espace NU passe avant d'épaissir ce qui l'est déjà (constat du
-- DC : « les tourelles couvrent pas assez d'espace »). Avec 30 (premier essai), le glouton doublait la couverture d'un
-- laboratoire avant de couvrir un tapis isolé (4 % de valeur laissée à découvert sur 1 base sur 60, tests/couverture_test.lua §4).
Cov.H = { [0] = 0, 100, 115, 125, 132, 137, 140, 142, 143 }
Cov.H_MAX = 8
function Cov.h(k)
  if k <= 0 then return 0 end
  if k >= Cov.H_MAX then return Cov.H[Cov.H_MAX] end
  return Cov.H[k]
end

-- Valeur d'un bâtiment selon son RÔLE (shared/ai3/reglages.lua : R.ENTITY_ROLE ; mots du moteur, pas des noms du jeu). Ce
-- qui rapporte ou ce qui est cher à refaire vaut plus ; une pièce de logistique (tapis, poteau) vaut peu mais compte.
Cov.ROLE_VALUE = { labo = 8, generateur = 8, chauffe = 6, fabrique = 5, pompe = 4, foreuse = 3, logistique = 1 }
Cov.CHEST_VALUE = 10    -- le coffre d'équipe (tout le stock y dort) : le plus précieux
function Cov.role_value(role) return Cov.ROLE_VALUE[role] or 0 end

local function floor(x) return math.floor(x) end
local function d2(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return dx * dx + dy * dy end

---------------------------------------------------------------------------------------------------
-- Regroupement des bâtiments
---------------------------------------------------------------------------------------------------
--- assets : { {x, y, v} } (v entier > 0) -> regroupements { {x, y, v, n} } triés par clé de case, au plus MAX_CLUSTERS.
function Cov.cluster(assets, cell)
  cell = cell or Cov.CLUSTER
  local by, keys = {}, {}
  for _, a in ipairs(assets) do
    if (a.v or 0) > 0 then
      local k = (floor(a.x / cell) + 32768) * 65536 + (floor(a.y / cell) + 32768)
      local c = by[k]
      if not c then
        c = { sx = 0, sy = 0, v = 0, n = 0 }
        by[k] = c
        keys[#keys + 1] = k
      end
      c.sx, c.sy, c.v, c.n = c.sx + a.x * a.v, c.sy + a.y * a.v, c.v + a.v, c.n + 1
    end
  end
  table.sort(keys)
  local out = {}
  for _, k in ipairs(keys) do
    local c = by[k]
    out[#out + 1] = { x = c.sx / c.v, y = c.sy / c.v, v = c.v, n = c.n, key = k }
  end
  if #out > Cov.MAX_CLUSTERS then
    table.sort(out, function(a, b)
      if a.v ~= b.v then return a.v > b.v end
      return a.key < b.key
    end)
    local keep = {}
    for i = 1, Cov.MAX_CLUSTERS do keep[i] = out[i] end
    table.sort(keep, function(a, b) return a.key < b.key end)
    out = keep
  end
  return out
end

--- Exposition (0 à 100) de chaque regroupement : 100 pour le plus proche d'une menace, 0 pour le plus loin (parmi ceux qui
--- ont une menace à portée), RELATIVE : on couvre d'abord le côté d'où l'on est attaqué. Sans menace : 0 partout.
local function exposures(clusters, threats)
  local near, dmin, dmax = {}, nil, nil
  local reach2 = Cov.THREAT_REACH * Cov.THREAT_REACH
  for i, c in ipairs(clusters) do
    local best
    for _, t in ipairs(threats or {}) do
      local q = d2(c.x, c.y, t.x, t.y)
      if q <= reach2 and (not best or q < best) then best = q end
    end
    if best then
      local d = math.sqrt(best)
      near[i] = d
      if not dmin or d < dmin then dmin = d end
      if not dmax or d > dmax then dmax = d end
    end
  end
  local e = {}
  for i = 1, #clusters do
    if not near[i] then e[i] = 0
    elseif dmax - dmin < 1 then e[i] = 100
    else e[i] = floor(100 * (dmax - near[i]) / (dmax - dmin)) end
  end
  return e
end

---------------------------------------------------------------------------------------------------
-- État du choix
---------------------------------------------------------------------------------------------------
--- spec = {
---   assets  = { {x, y, v} },      bâtiments à protéger (v entier > 0)
---   range   = portée de la tourelle (tuiles, lue au prototype),
---   turrets = { {x, y} },         tourelles déjà posées (comptent dans la couverture et l'espacement),
---   threats = { {x, y} },         menaces connues (nids, vers, morts, bâtiments détruits),
---   blocked = function(x, y) -> true si la place est prise (facultatif),
---   candidates = { {x, y} }       facultatif : sinon la grille (pas Cov.STEP) autour des bâtiments
--- }
function Cov.new(spec)
  local range = spec.range or 18
  local rc = range * Cov.COVER_PCT / 100
  local st = {
    range = range, rc2 = rc * rc, sep = range * Cov.SEP_PCT / 100,
    clusters = Cov.cluster(spec.assets or {}), threats = spec.threats or {},
    turrets = {}, chosen = {}, cands = {},
  }
  local ex = exposures(st.clusters, st.threats)
  st.V, st.k = {}, {}
  local sx, sy, sv = 0, 0, 0
  for i, c in ipairs(st.clusters) do
    st.V[i] = c.v * (10000 + Cov.EXPO_PCT * ex[i])
    st.k[i] = 0
    sx, sy, sv = sx + c.x * c.v, sy + c.y * c.v, sv + c.v
  end
  st.cx, st.cy = (sv > 0) and (sx / sv) or 0, (sv > 0) and (sy / sv) or 0
  for _, t in ipairs(spec.turrets or {}) do
    st.turrets[#st.turrets + 1] = { x = t.x, y = t.y }
    for i, c in ipairs(st.clusters) do
      if d2(c.x, c.y, t.x, t.y) <= st.rc2 then st.k[i] = st.k[i] + 1 end
    end
  end
  -- candidats
  local list = spec.candidates
  if not list then
    list = {}
    if #st.clusters > 0 then
      local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
      for _, c in ipairs(st.clusters) do
        if c.x < x0 then x0 = c.x end
        if c.y < y0 then y0 = c.y end
        if c.x > x1 then x1 = c.x end
        if c.y > y1 then y1 = c.y end
      end
      local step = Cov.STEP
      while true do
        list = {}
        local ax, ay = floor((x0 - rc) / step) * step, floor((y0 - rc) / step) * step
        for gy = ay, y1 + rc, step do
          for gx = ax, x1 + rc, step do list[#list + 1] = { x = gx, y = gy } end
        end
        if #list <= Cov.MAX_CANDS * 4 then break end
        step = step * 2
      end
    end
  end
  for _, p in ipairs(list) do
    if not (spec.blocked and spec.blocked(p.x, p.y)) then
      local cov = {}
      for i, c in ipairs(st.clusters) do
        if d2(c.x, c.y, p.x, p.y) <= st.rc2 then cov[#cov + 1] = i end
      end
      if #cov > 0 then st.cands[#st.cands + 1] = { x = p.x, y = p.y, cov = cov } end
    end
  end
  -- Plafond : les candidats au plus grand gain de départ (mêmes ordres que le choix).
  if #st.cands > Cov.MAX_CANDS then
    for _, c in ipairs(st.cands) do
      local s = 0
      for _, i in ipairs(c.cov) do s = s + st.V[i] end
      c.g0 = s
    end
    table.sort(st.cands, function(a, b)
      if a.g0 ~= b.g0 then return a.g0 > b.g0 end
      if a.y ~= b.y then return a.y < b.y end
      return a.x < b.x
    end)
    for i = #st.cands, Cov.MAX_CANDS + 1, -1 do st.cands[i] = nil end
  end
  return st
end

--- Gain marginal (entier) d'une tourelle de plus en (cand).
local function gain(st, cand)
  local s = 0
  for _, i in ipairs(cand.cov) do
    local k = st.k[i]
    s = s + st.V[i] * (Cov.h(k + 1) - Cov.h(k))
  end
  return s
end

local function min_d2_turrets(st, x, y)
  local m
  for _, t in ipairs(st.turrets) do
    local q = d2(x, y, t.x, t.y)
    if not m or q < m then m = q end
  end
  return m
end

local function near_threat_d2(st, x, y)
  local m
  for _, t in ipairs(st.threats) do
    local q = d2(x, y, t.x, t.y)
    if not m or q < m then m = q end
  end
  return m
end

--- Prochaine position. `ok(x, y)` (facultatif) est l'épreuve du moteur (place réellement libre) : refusée, la position est
--- retirée et la suivante essayée. Rend { x, y, gain, relaxed } ou nil (plus aucun candidat).
function Cov.next(st, ok)
  local seps = { st.sep, st.sep / 2, 0 }
  local spread_cap2 = (2 * st.sep) * (2 * st.sep)
  local has_threat = #st.threats > 0
  for level, sep in ipairs(seps) do
    local sep2 = sep * sep
    local list = {}
    for _, c in ipairs(st.cands) do
      if not c.used then
        local m = min_d2_turrets(st, c.x, c.y)
        if not m or m >= sep2 then
          local e = { c = c, g = gain(st, c) }
          if has_threat then e.t1 = near_threat_d2(st, c.x, c.y) or math.huge
          else e.t1 = -math.min(m or math.huge, spread_cap2) end
          e.t2 = d2(c.x, c.y, st.cx, st.cy)
          list[#list + 1] = e
        end
      end
    end
    table.sort(list, function(a, b)
      if a.g ~= b.g then return a.g > b.g end
      if a.t1 ~= b.t1 then return a.t1 < b.t1 end
      if a.t2 ~= b.t2 then return a.t2 < b.t2 end
      if a.c.y ~= b.c.y then return a.c.y < b.c.y end
      return a.c.x < b.c.x
    end)
    for _, e in ipairs(list) do
      local c = e.c
      if not ok or ok(c.x, c.y) then
        c.used = true
        st.turrets[#st.turrets + 1] = { x = c.x, y = c.y }
        for _, i in ipairs(c.cov) do st.k[i] = st.k[i] + 1 end
        local pick = { x = c.x, y = c.y, gain = e.g, relaxed = level - 1 }
        st.chosen[#st.chosen + 1] = pick
        return pick
      end
      c.used = true -- refusée par le moteur : plus jamais proposée
    end
  end
  return nil
end

--- Choisit n positions (sans épreuve du moteur) : liste de { x, y, gain, relaxed }.
function Cov.plan(spec, n)
  local st = Cov.new(spec)
  local out = {}
  for _ = 1, n do
    local p = Cov.next(st)
    if not p then break end
    out[#out + 1] = p
  end
  return out, st
end

--- Objectif F(S) de l'état (tourelles déjà posées comprises) : Σ V × H(k).
function Cov.objective(st)
  local s = 0
  for i = 1, #st.clusters do s = s + st.V[i] * Cov.h(st.k[i]) end
  return s
end

--- Objectif d'un ensemble de positions donné (force brute et tests) : même spec, tourelles = spec.turrets + positions.
function Cov.objective_of(spec, positions)
  local sp = { assets = spec.assets, range = spec.range, threats = spec.threats, blocked = spec.blocked }
  local tur = {}
  for _, t in ipairs(spec.turrets or {}) do tur[#tur + 1] = t end
  for _, t in ipairs(positions) do tur[#tur + 1] = t end
  sp.turrets = tur
  sp.candidates = {}
  return Cov.objective(Cov.new(sp))
end

--- Part de la valeur (0 à 1) couverte au moins une fois par des tourelles de portée `range` : mesure des journaux, des
--- tests et des bancs. Bâtiments bruts (pas de regroupement).
function Cov.covered_fraction(assets, turrets, range)
  local rc = range * Cov.COVER_PCT / 100
  local rc2 = rc * rc
  local tot, cov = 0, 0
  for _, a in ipairs(assets) do
    local v = a.v or 0
    if v > 0 then
      tot = tot + v
      for _, t in ipairs(turrets) do
        if d2(a.x, a.y, t.x, t.y) <= rc2 then cov = cov + v break end
      end
    end
  end
  if tot == 0 then return 1 end
  return cov / tot
end

--- Plus petite distance entre deux tourelles (tuiles ; nil s'il y en a moins de deux) : « deux cases d'une autre ».
function Cov.min_gap(turrets)
  local m
  for i = 1, #turrets do
    for j = i + 1, #turrets do
      local q = d2(turrets[i].x, turrets[i].y, turrets[j].x, turrets[j].y)
      if not m or q < m then m = q end
    end
  end
  return m and math.sqrt(m) or nil
end

---------------------------------------------------------------------------------------------------
-- Menaces connues (carte du danger d'une équipe, shared/ai3/danger.lua) + bâtiments détruits récemment
---------------------------------------------------------------------------------------------------
--- map : carte du danger (ou nil) ; hits : { {x, y, t} } bâtiments détruits ; rend { {x, y} } triés, sans doublon.
function Cov.threat_points(map, hits, tick)
  local out, seen = {}, {}
  local function add(x, y)
    local k = floor(x / 4) * 100000 + floor(y / 4)
    if not seen[k] then
      seen[k] = true
      out[#out + 1] = { x = x, y = y }
    end
  end
  if map then
    for _, t in ipairs(map.threats or {}) do add(t.x, t.y) end
    for _, d in ipairs(map.deaths or {}) do
      if not d.home and tick - d.t < D.HOUR then add(d.x, d.y) end
    end
  end
  for _, h in ipairs(hits or {}) do
    if tick - h.t < Cov.HITS_TTL then add(h.x, h.y) end
  end
  table.sort(out, function(a, b)
    if a.y ~= b.y then return a.y < b.y end
    return a.x < b.x
  end)
  return out
end

return Cov
