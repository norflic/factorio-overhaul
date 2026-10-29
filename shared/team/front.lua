--[[
  Lot DEFENSE-FRONT : la défense suit le FRONT. Règle PURE (aucune API Factorio, aucun nom d'objet), déterministe, testée hors jeu par
  tests/front_test.lua (avec mutants).

  Constat du DC (29/10, 1 h 30 de partie sur 0.6.13) : « on place des tourelles là où il y a le plus d'attaques, on rajoute une
  tourelle en plus là où il y a le plus d'attaques [...] s'ils attaquent deux fois au même endroit, autant défendre un peu plus cet
  endroit-là qu'un autre » ; « il faut placer des tourelles au niveau des améliorateurs, ça coûte pas grand-chose ». Avant le lot, les
  tourelles étaient à 8 emplacements fixes autour de chaque avant-poste (Outposts.fortify) et de la centrale : aucune mémoire de OÙ
  les attaques arrivent.

  Trois services, tous sur une GRILLE de F.CELL tuiles :
    1. MÉMOIRE des attaques (F.record, F.decay, F.top) : à la mort d'une pièce de l'équipe tuée par un ennemi, la cellule reçoit un
       poids (F.ROLE_WEIGHT : une tourelle ou un mur pèse plus qu'un tapis) ; le centre de la cellule est la moyenne pondérée des
       lieux de mort. Décroissance entière à pas fixe (F.STEP ticks, facteur F.DECAY_NUM / F.DECAY_DEN : demi-vie de 20 min), jamais un
       temps mesuré. Une cellule sous F.DROP disparaît.
    2. TOURELLES VOULUES (F.want, F.plan) : les F.MAX_CELLS cellules les plus attaquées (score au moins F.MIN_SCORE, deux coups)
       veulent F.BASE tourelles à moins de F.NEAR tuiles de leur centre, une de plus par F.PER_TURRET de score, au plus F.CELL_CAP par
       cellule. Le manque est posé par lots d'au plus F.BATCH, sous un plafond F.TEAM_CAP par équipe (tourelles du front, toutes
       cellules confondues). Une tourelle détruite fait baisser `have` : elle est REMPLACÉE par le même mécanisme.
    3. COUVERTURE MINIMALE des bâtiments d'amélioration (F.cover_clusters) : chaque groupe de ces bâtiments (une cellule de la grille)
       veut F.COVER_WANT tourelles à portée, attaqué ou non ; ces places passent APRÈS celles des cellules attaquées et ne mangent
       jamais les F.ATTACK_RESERVE dernières places du plafond.
  Une cellule n'est servie que si le moteur l'autorise (callback `allow(row)` de F.plan : bâtiments de l'équipe à proximité, pas
  d'ennemi sur place) : la règle ne lit rien d'autre.

  Aucun `pairs` non trié, aucune trigonométrie, aucun hasard.
]]
local F = {}

F.CELL = 16               -- tuiles : côté d'une cellule de la mémoire
F.HIT = 100               -- centièmes de coup par mort (poids de base)
F.ROLE_WEIGHT = { militaire = 200 } -- rôle (shared/ai3/reglages.lua) -> poids ; un rôle absent pèse F.HIT
F.STEP = 3600             -- ticks : un pas de décroissance
F.DECAY_NUM, F.DECAY_DEN = 966, 1000 -- facteur par pas (demi-vie de 20 pas)
F.DROP = 20               -- centièmes : une cellule en dessous est oubliée
F.MAX_STEPS = 600         -- pas de décroissance rattrapés d'un coup au plus (une sauvegarde très ancienne)
F.MIN_SCORE = 200         -- centièmes : deux coups pour compter
F.MAX_CELLS = 3           -- cellules les plus attaquées prises en compte
F.BASE = 2                -- tourelles voulues autour d'une cellule attaquée
F.PER_TURRET = 400        -- une tourelle de plus par tranche de score
F.CELL_CAP = 5            -- plafond par cellule
F.TEAM_CAP = 16           -- plafond d'équipe (tourelles du front)
F.ATTACK_RESERVE = 6      -- places du plafond gardées aux cellules attaquées (la couverture ne les prend pas)
F.BATCH = 2               -- tourelles posées par voyage au plus
F.NEAR = 14               -- tuiles : une tourelle « couvre » une cellule à moins de cette distance de son centre
F.COVER_WANT = 2          -- tourelles voulues près d'un groupe de bâtiments d'amélioration
F.MAX_COVER = 4           -- groupes de bâtiments d'amélioration suivis
F.RING = 6                -- tuiles : rayon de l'anneau des emplacements candidats
F.ACCEPT = 10             -- tuiles : une pose plus loin du centre est refusée
F.ASSET_R = 24            -- tuiles : une cellule attaquée n'est servie que s'il y a un bâtiment de l'équipe à moins de cela (lu par l'appelant)
F.CALM_R = 30             -- tuiles : pas de pose tant qu'un ennemi est plus près de la cellule (lu par l'appelant)
F.REST = 7200             -- ticks : repos d'une cellule dont la pose n'a rien posé (lu par l'appelant)
F.CHECK_EVERY = 600       -- ticks : durée de validité d'un « le moteur autorise » (lu par l'appelant)
F.COVER_EVERY = 1800      -- ticks : relevé des bâtiments d'amélioration (lu par l'appelant)

-- Lot DEFENSE-FACTIONS (audit tourelles-danger du 29/10 ; constantes ICI et non dans shared/team/config.lua, partagé avec d'autres lots) :
F.SCAN = 8                -- cellules examinées AVANT la coupe à F.MAX_CELLS : une cellule que le moteur refuse (rasée, ennemi sur place) ne compte pas dans la coupe (D5)
F.NEAR_HQ = 40            -- tuiles : une cellule à moins de cela du QG passe AVANT la centrale et les avant-postes non défendus (D5)
F.HIGH_SCORE = 400        -- centièmes : « score élevé » (deux morts de tourelle ou de mur) : le plancher de fer baisse pour le front (D4)
F.FLOOR_IRON = 60         -- plaques de fer gardées au coffre quand le front est servi à plancher réduit (T.defend_iron_floor = 150 sinon) : jamais 0
F.FLOOR_COPPER = 10       -- plaques de cuivre gardées (T.defend_copper_floor = 30 sinon)
F.PARTIAL_COUNT = 1       -- tourelles d'une commande partielle (D4)
F.PARTIAL_AMMO = 10       -- chargeurs par tourelle d'une commande partielle (D4 ; commande complète : T.defend_ammo)
F.HQ_POST = 2             -- tourelles voulues au QG d'une faction qui en a perdu une sous attaque (D3)
F.HQ_MEMORY = 108000      -- ticks (30 min) : le QG compte comme « attaqué » ce temps après la dernière occupation par les biters (D3)
F.LOG_EVERY = 18000       -- ticks (5 min) : une ligne [FO-DEFENSE] au plus par faction (D1)

--- D3 : tourelles voulues au QG d'une FACTION. a = { turrets = tourelles du QG, peak = le plus grand nombre déjà vu, ago = ticks depuis la
--- dernière occupation du QG par les biters (nil : jamais) }. 0 tant que le QG n'a pas perdu de tourelle OU n'a pas été attaqué récemment
--- (la tourelle offerte au départ, F.HQ_POST ensuite : une faction ne refait pas un QG de 4 tourelles, elle en garde 2).
function F.hq_post(a)
  local lost = (a.turrets or 0) < (a.peak or 0)
  local attacked = a.ago ~= nil and a.ago >= 0 and a.ago < F.HQ_MEMORY
  if lost and attacked then return F.HQ_POST end
  return 0
end

--- D4 : planchers de fer et de cuivre du front. Plancher réduit seulement si la cellule a un score élevé ET si l'équipe produit encore du fer
--- (`producing` : sinon le coffre est la dernière réserve du redémarrage et la défense n'y touche pas : remarque du DC du 29/10, « si on manque
--- cruellement de ressources, l'objectif est ces ressources, la défense vient juste après »). `base_iron`, `base_copper` : planchers ordinaires.
--- Rend fer, cuivre, réduit (vrai si réduit).
function F.floors(score, producing, base_iron, base_copper)
  if producing and (score or 0) >= F.HIGH_SCORE then
    return math.min(base_iron, F.FLOOR_IRON), math.min(base_copper, F.FLOOR_COPPER), true
  end
  return base_iron, base_copper, false
end

local function d2(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return dx * dx + dy * dy end

local function floor(x) return math.floor(x) end

--- Cellule d'une position : cx, cy, clé texte.
function F.cell_of(x, y)
  local cx, cy = floor(x / F.CELL), floor(y / F.CELL)
  return cx, cy, cx .. "," .. cy
end

--- Mémoire neuve (à `tick`).
function F.new(tick) return { cells = {}, tick = tick or 0, hits = 0 } end

local function sorted_keys(cells)
  local keys = {}
  for k in pairs(cells) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b)
    local ca, cb = cells[a], cells[b]
    if ca.cx ~= cb.cx then return ca.cx < cb.cx end
    return ca.cy < cb.cy
  end)
  return keys
end

--- Poids d'une mort selon le rôle de la pièce.
function F.weight(role) return F.ROLE_WEIGHT[role] or F.HIT end

--- Une mort en (x, y) de poids w : la cellule reçoit le poids, son centre se déplace vers le lieu.
function F.record(mem, x, y, w)
  w = w or F.HIT
  if w <= 0 then return nil end
  local cx, cy, key = F.cell_of(x, y)
  local c = mem.cells[key]
  if not c then
    c = { cx = cx, cy = cy, n = 0, sx = 0, sy = 0, sw = 0 }
    mem.cells[key] = c
  end
  c.n, c.sx, c.sy, c.sw = c.n + w, c.sx + x * w, c.sy + y * w, c.sw + w
  mem.hits = (mem.hits or 0) + 1
  return key
end

--- Décroissance jusqu'à `tick` : un pas par F.STEP écoulé (au plus F.MAX_STEPS). Rend le nombre de pas faits.
function F.decay(mem, tick)
  local steps = floor((tick - mem.tick) / F.STEP)
  if steps <= 0 then return 0 end
  if steps > F.MAX_STEPS then steps = F.MAX_STEPS end
  mem.tick = mem.tick + steps * F.STEP
  for _, key in ipairs(sorted_keys(mem.cells)) do
    local c = mem.cells[key]
    local n0 = c.n
    for _ = 1, steps do
      c.n = floor(c.n * F.DECAY_NUM / F.DECAY_DEN)
      if c.n < F.DROP then break end
    end
    if c.n < F.DROP then
      mem.cells[key] = nil
    elseif n0 > 0 then
      local k = c.n / n0 -- le centre garde sa place : mêmes sommes, même rapport
      c.sx, c.sy, c.sw = c.sx * k, c.sy * k, c.sw * k
    end
  end
  return steps
end

--- Les cellules d'au moins `min` de score (défaut F.MIN_SCORE), les plus attaquées d'abord (score décroissant, puis cx, cy), au plus
--- `n` (défaut F.MAX_CELLS) : { { key, cx, cy, score, x, y } }.
function F.top(mem, n, min)
  min = min or F.MIN_SCORE
  n = n or F.MAX_CELLS
  local list = {}
  for _, key in ipairs(sorted_keys(mem.cells)) do
    local c = mem.cells[key]
    if c.n >= min and c.sw > 0 then
      list[#list + 1] = { key = key, cx = c.cx, cy = c.cy, score = c.n, x = c.sx / c.sw, y = c.sy / c.sw }
    end
  end
  table.sort(list, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    if a.cx ~= b.cx then return a.cx < b.cx end
    return a.cy < b.cy
  end)
  while #list > n do list[#list] = nil end
  return list
end

--- Tourelles voulues autour d'une cellule de ce score.
function F.want(score)
  local k = F.BASE + floor((score or 0) / F.PER_TURRET)
  if k > F.CELL_CAP then k = F.CELL_CAP end
  return k
end

--- Tourelles (liste { x, y }) à moins de `near` tuiles de (x, y).
function F.count_near(turrets, x, y, near)
  local r2, n = near * near, 0
  for _, t in ipairs(turrets or {}) do
    if d2(t.x, t.y, x, y) <= r2 then n = n + 1 end
  end
  return n
end

--- Groupes de bâtiments d'amélioration : positions { x, y } -> au plus F.MAX_COVER cellules { key, x, y, n } (centre = moyenne), les
--- plus fournies d'abord (puis cx, cy).
function F.cover_clusters(positions)
  local by, keys = {}, {}
  for _, p in ipairs(positions or {}) do
    local cx, cy, key = F.cell_of(p.x, p.y)
    local c = by[key]
    if not c then
      c = { key = key, cx = cx, cy = cy, n = 0, sx = 0, sy = 0 }
      by[key] = c
      keys[#keys + 1] = key
    end
    c.n, c.sx, c.sy = c.n + 1, c.sx + p.x, c.sy + p.y
  end
  local out = {}
  for _, key in ipairs(keys) do
    local c = by[key]
    out[#out + 1] = { key = key, cx = c.cx, cy = c.cy, n = c.n, x = c.sx / c.n, y = c.sy / c.n }
  end
  table.sort(out, function(a, b)
    if a.n ~= b.n then return a.n > b.n end
    if a.cx ~= b.cx then return a.cx < b.cx end
    return a.cy < b.cy
  end)
  while #out > F.MAX_COVER do out[#out] = nil end
  return out
end

-- Directions de l'anneau (entiers : pas de trigonométrie) : quatre côtés puis les diagonales.
local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 } }

--- Emplacements candidats autour de (x, y) : l'anneau de F.RING tuiles, le plus ÉCARTÉ des tourelles déjà là d'abord (la nouvelle ne
--- s'empile pas sur une ancienne), à égalité l'ordre des directions. Rend { { x, y } } (les 8, tous essayés par la pose).
function F.sites(x, y, turrets)
  local cand = {}
  for i, d in ipairs(DIRS) do
    local k = (d[1] ~= 0 and d[2] ~= 0) and 0.7 or 1
    local sx, sy = floor(x + d[1] * F.RING * k + 0.5), floor(y + d[2] * F.RING * k + 0.5)
    local best = math.huge
    for _, t in ipairs(turrets or {}) do
      local dd = d2(t.x, t.y, sx, sy)
      if dd < best then best = dd end
    end
    cand[#cand + 1] = { x = sx, y = sy, away = best, i = i }
  end
  table.sort(cand, function(a, b)
    if a.away ~= b.away then return a.away > b.away end
    return a.i < b.i
  end)
  local out = {}
  for _, c in ipairs(cand) do out[#out + 1] = { x = c.x, y = c.y } end
  return out
end

--- Une pose en (px, py) est-elle assez près du centre voulu ?
function F.accepts(cx, cy, px, py) return d2(cx, cy, px, py) <= F.ACCEPT * F.ACCEPT end

--- Plan de l'équipe. Entrées (table p) :
---   cells   = F.top(mem, F.SCAN) : cellules attaquées (au plus F.MAX_CELLS sont gardées APRÈS le contrôle du moteur, lot DEFENSE-FACTIONS D5) ;
---   cover   = F.cover_clusters(...) : bâtiments d'amélioration ;
---   turrets = { { x, y } } toutes les tourelles de l'équipe (armées ou non) ;
---   placed  = tourelles du front déjà posées (plafond d'équipe) ;
---   near    = portée de couverture (défaut F.NEAR) ;
---   rest    = { [clé] = vrai } cellules au repos (porteur tué en route, pose sans résultat) ;
---   pause   = vrai : rien ;
---   hq      = { x, y } : le QG (facultatif ; sert à marquer `near_hq` la cellule choisie, D5) ;
---   allow   = function(row) -> vrai si le moteur autorise ce lieu (facultatif ; appelée pour une cellule en manque qui n'est pas au repos).
--- Rend { rows, pick, left } : rows = { { key, kind = "attaque"|"couverture", x, y, score, have, want, missing, skip } } dans l'ordre de service
--- (skip : pourquoi la ligne n'est pas servie, pour le journal [FO-DEFENSE] : "servie", "repos", "refus", "doublon", "plafond") ;
--- pick = { key, kind, x, y, score, have, want, count, sites, near_hq } ou nil ; left = places restantes sous le plafond.
function F.plan(p)
  local near = p.near or F.NEAR
  local turrets = p.turrets or {}
  local left = F.TEAM_CAP - (p.placed or 0)
  if left < 0 then left = 0 end
  local rows = {}
  -- Lot DEFENSE-FACTIONS D5 : le moteur est consulté AVANT la coupe à F.MAX_CELLS. Avant, les 3 cellules les plus attaquées étaient
  -- gardées puis seulement jugées : si elles étaient rasées (aucun bâtiment à portée) ou sous les nids, rien n'était servi même
  -- quand une 4e cellule l'aurait été. Une cellule refusée ne compte plus dans la coupe.
  local kept = 0
  for _, c in ipairs(p.cells or {}) do
    if kept >= F.MAX_CELLS then break end
    local have = F.count_near(turrets, c.x, c.y, near)
    local want = F.want(c.score)
    local row = { key = c.key, kind = "attaque", x = c.x, y = c.y, score = c.score, have = have, want = want,
      missing = math.max(0, want - have) }
    if row.missing > 0 and not (p.rest and p.rest[c.key]) and p.allow and not p.allow(row) then
      row.skip = "refus"
    else
      kept = kept + 1
    end
    rows[#rows + 1] = row
  end
  for _, c in ipairs(p.cover or {}) do
    local have = F.count_near(turrets, c.x, c.y, near)
    rows[#rows + 1] = { kind = "couverture", key = c.key, x = c.x, y = c.y, score = 0, have = have, want = F.COVER_WANT,
      missing = math.max(0, F.COVER_WANT - have) }
  end
  local pick = nil
  if not p.pause and left > 0 then
    for _, r in ipairs(rows) do
      local room = left
      if r.kind == "couverture" then room = left - F.ATTACK_RESERVE end -- la couverture ne prend pas les places des cellules attaquées
      -- une cellule déjà servie par une cellule attaquée voisine (même clé) n'est pas dupliquée en couverture
      local dup = false
      if r.kind == "couverture" then
        for _, a in ipairs(rows) do if a.kind == "attaque" and a.key == r.key then dup = true end end
      end
      local resting = p.rest and p.rest[r.key]
      if r.skip == "refus" then
        -- déjà jugée par le moteur plus haut
      elseif r.missing <= 0 then
        r.skip = "servie"
      elseif room <= 0 then
        r.skip = "plafond"
      elseif dup then
        r.skip = "doublon"
      elseif resting then
        r.skip = "repos"
      elseif r.kind == "couverture" and p.allow and not p.allow(r) then
        r.skip = "refus"
      else
        local count = math.min(r.missing, F.BATCH, room)
        pick = { key = r.key, kind = r.kind, x = r.x, y = r.y, score = r.score, have = r.have, want = r.want, count = count,
          sites = F.sites(r.x, r.y, turrets) }
        if p.hq then pick.near_hq = d2(r.x, r.y, p.hq.x, p.hq.y) <= F.NEAR_HQ * F.NEAR_HQ end
        break
      end
    end
  elseif p.pause or left <= 0 then
    for _, r in ipairs(rows) do if r.missing > 0 and not r.skip then r.skip = p.pause and "pause" or "plafond" end end
  end
  return { rows = rows, pick = pick, left = left }
end

return F
