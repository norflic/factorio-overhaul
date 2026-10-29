--[[
  IA3 « le cerveau des PNJ », lot IA3-f : CARTE DE CONNAISSANCE d'une équipe (PUR, aucune API Factorio ; testé hors jeu
  par tests/ai3_carte_test.lua). Conception : docs/IA3_CERVEAU.md §4.1 (trouver sous le brouillard), §4.2 (risque) ;
  revue M3 (fo-logs/2026-10-25_IA3-dev/REVUE.md) : la connaissance n'est faite QUE des regards du mod, identiques avec et
  sans images ; jamais la cartographie du moteur (`is_chunk_charted`, absente des bancs : F131).

  Ce que l'équipe SAIT, par secteur de 64 × 64 tuiles (même grille et mêmes clés que les yeux d'IA2-c,
  shared/faction/adversaire.lua : A.key, A.xy) :
    s[clé] = { t0 = 1er regard, t = dernier regard,
               r = { { name, n = tuiles, a = quantité estimée, x, y = centre estimé }, ... } (triés par nom),
               sp = { {x, y}, ... } nids vus, wm = { {x, y}, ... } vers vus (au plus K.NEST_KEEP chacun),
               w = true si de l'eau a été vue }
  Plus : found[ressource] = tick du premier gisement vu ; marks = incidents (fuite d'un éclaireur, PNJ tué) datés et
  pondérés, qui rendent une zone dangereuse pendant K.DANGER.mark_ttl.

  Requêtes (lues par le cerveau, nouveau ou ancien, et par l'exploration) :
    K.seen / K.seen_xy        secteur vu, et quand ;
    K.deposits(m, res, from)   gisements connus d'une ressource, du plus proche au plus lointain ;
    K.site_inputs(...)         entrées du risque d'une expédition (shared/ai3/expedition.lua, E.risk) : nids et vers vus
                               à 64 tuiles, nids près du chemin, part vue du voisinage, incidents, distance ;
    K.best_target(m, ctx)      où chercher : le secteur NON VU de la FRONTIÈRE (voisin d'un secteur vu) de meilleure note
                               note = a priori × sécurité ÷ (distance au QG + distance à l'éclaireur + 100)
                               (§4.1 : a priori × sécurité ÷ (distance au QG + 100) ; la distance à l'éclaireur est
                               AJOUTÉE pour qu'il balaie de proche en proche au lieu de traverser la base à chaque
                               cible : écart déclaré) ;
    K.ring(x, y, r)            8 points d'un anneau (tour du propriétaire), vecteurs constants : aucune trigonométrie.

  Déterminisme : clés triées partout (aucune décision sur l'ordre de `pairs`), entiers ou opérations IEEE identiques
  chez tous les pairs ; aucun hasard.
]]

local A = require("shared.faction.adversaire")
local E = require("shared.ai3.expedition")

local K = {}

K.SECTOR = A.SECTOR           -- 64
K.MARGIN = A.MARGIN           -- un secteur est vu quand son centre est à moins de r + 32 tuiles d'un œil
-- Rayons des yeux (§4.1) : QG, avant-postes, groupes, éclaireurs d'IA2-c ; PNJ en marche (nouveau) ; éclaireur d'IA3-f.
K.EYE = { hq = 160, outpost = 128, group = 96, scout = 128, walker = 48, explorer = 128 }
K.STEP = 64                   -- un PNJ en marche est regardé tous les 64 tuiles parcourues (revue M3)
K.RELOOK = { fixed = 30 * 3600, moving = 10 * 3600 } -- un secteur vu n'est regardé de nouveau qu'après ce délai
K.NEST_KEEP = 8
K.NEAR = 64                   -- nids et vers comptés autour d'un site (§4.2)
K.PATH = 32                   -- un nid « près du chemin » est à moins de 32 tuiles du segment QG → site
K.MARKS = 16                  -- incidents retenus
-- Danger d'un secteur pour l'exploration (pour mille) : nids et vers vus dans le secteur et ses 8 voisins, incidents
-- récents à 96 tuiles (décroissance linéaire), QG rival connu à moins de 256 tuiles. Un secteur à 900 ou plus n'est
-- jamais une cible.
K.DANGER = { nest = 250, worm = 100, mark_radius = 96, mark_ttl = 20 * 3600, rival = 600, rival_radius = 256,
  cap = 1000, skip = 900 }
K.MAX_DIST = 1600             -- aucune cible d'exploration au-delà de 1 600 tuiles du QG

---------------------------------------------------------------------------------------------------
-- Secteurs
---------------------------------------------------------------------------------------------------
function K.new() return { s = {}, n = 0, found = {}, marks = {}, cnt = {} } end

K.key, K.xy, K.center = A.key, A.xy, A.center

function K.key_of(x, y)
  local sx, sy = A.sector_of(x, y)
  return A.key(sx, sy)
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end
K.sorted_keys = sorted_keys

--- Tick du dernier regard sur le secteur, ou nil (jamais vu).
function K.seen(m, key)
  local s = m.s[key]
  return s and s.t or nil
end

function K.seen_xy(m, x, y) return K.seen(m, K.key_of(x, y)) end

--- Tick du PREMIER regard (nil : jamais vu).
function K.first_seen(m, key)
  local s = m.s[key]
  return s and s.t0 or nil
end

--- Un regard doit-il être (re)fait ? (jamais vu, ou vu il y a `relook` ticks ou plus)
function K.due(m, key, tick, relook)
  local s = m.s[key]
  return s == nil or tick - s.t >= relook
end

local function copy_points(list)
  local out = {}
  for i = 1, math.min(#(list or {}), K.NEST_KEEP) do
    local p = list[i]
    out[i] = { x = math.floor(p.x), y = math.floor(p.y) }
  end
  return out
end

--- Résultat d'un regard. obs = { res = { { name, n, a, x, y }, ... }, nests = { {x, y} }, worms = { {x, y} }, water }.
--- Renvoie la liste (triée) des ressources NOUVELLES dans ce secteur.
function K.record(m, key, tick, obs)
  local s = m.s[key]
  if not s then
    s = { t0 = tick }
    m.s[key] = s
    m.n = m.n + 1
  end
  s.t = tick
  local old = {}
  for _, r in ipairs(s.r or {}) do old[r.name] = true end
  local res = {}
  for _, r in ipairs(obs.res or {}) do
    if (r.n or 0) > 0 then
      res[#res + 1] = { name = r.name, n = r.n, a = r.a or 0, x = math.floor(r.x), y = math.floor(r.y) }
    end
  end
  table.sort(res, function(p, q) return p.name < q.name end)
  s.r = #res > 0 and res or nil
  local fresh = {}
  m.cnt = m.cnt or {}
  local now = {}
  for _, r in ipairs(res) do
    now[r.name] = true
    if not old[r.name] then
      fresh[#fresh + 1] = r.name
      m.cnt[r.name] = (m.cnt[r.name] or 0) + 1
    end
    if not m.found[r.name] then m.found[r.name] = tick end
  end
  for _, name in ipairs(sorted_keys(old)) do
    if not now[name] then m.cnt[name] = (m.cnt[name] or 1) - 1 end
  end
  local sp, wm = copy_points(obs.nests), copy_points(obs.worms)
  s.sp = #sp > 0 and sp or nil
  s.wm = #wm > 0 and wm or nil
  s.w = obs.water and true or nil
  return fresh
end

--- Incident (éclaireur en fuite, PNJ tué par l'ennemi) : la zone devient dangereuse pendant mark_ttl.
function K.mark(m, x, y, tick, w)
  m.marks[#m.marks + 1] = { x = math.floor(x), y = math.floor(y), t = tick, w = w or 500 }
  while #m.marks > K.MARKS do table.remove(m.marks, 1) end
end

---------------------------------------------------------------------------------------------------
-- Gisements et danger connus
---------------------------------------------------------------------------------------------------
--- Gisements connus d'une ressource : { key, x, y, n, a, t }, triés du plus proche de `from` au plus lointain (à
--- distance égale, par clé) ; sans `from`, par clé.
function K.deposits(m, res, from)
  local out = {}
  for _, k in ipairs(sorted_keys(m.s)) do
    local s = m.s[k]
    for _, r in ipairs(s.r or {}) do
      if r.name == res then
        local e = { key = k, x = r.x, y = r.y, n = r.n, a = r.a, t = s.t, t0 = s.t0 }
        if from then
          local dx, dy = r.x - from.x, r.y - from.y
          e.d2 = dx * dx + dy * dy
        end
        out[#out + 1] = e
      end
    end
  end
  if from then
    table.sort(out, function(p, q)
      if p.d2 ~= q.d2 then return p.d2 < q.d2 end
      return p.key < q.key
    end)
  end
  return out
end

--- Nombre de secteurs où un gisement de la ressource est vu (tenu à chaque regard : aucun parcours).
function K.count(m, res) return (m.cnt and m.cnt[res]) or 0 end

--- Ressources connues (au moins un gisement vu), triées.
function K.known_resources(m) return sorted_keys(m.found) end

--- Nids et vers VUS à moins de r tuiles de (x, y).
function K.enemies_near(m, x, y, r)
  local nests, worms = 0, 0
  local r2 = r * r
  local x0, x1 = math.floor((x - r) / K.SECTOR), math.floor((x + r) / K.SECTOR)
  local y0, y1 = math.floor((y - r) / K.SECTOR), math.floor((y + r) / K.SECTOR)
  for sy = y0, y1 do
    for sx = x0, x1 do
      local s = m.s[A.key(sx, sy)]
      if s then
        for _, p in ipairs(s.sp or {}) do
          if (p.x - x) ^ 2 + (p.y - y) ^ 2 <= r2 then nests = nests + 1 end
        end
        for _, p in ipairs(s.wm or {}) do
          if (p.x - x) ^ 2 + (p.y - y) ^ 2 <= r2 then worms = worms + 1 end
        end
      end
    end
  end
  return nests, worms
end

--- Incidents récents (moins de mark_ttl) à moins de r tuiles.
function K.marks_near(m, x, y, r, tick)
  local n = 0
  for _, mk in ipairs(m.marks) do
    if tick - mk.t < K.DANGER.mark_ttl and (mk.x - x) ^ 2 + (mk.y - y) ^ 2 <= r * r then n = n + 1 end
  end
  return n
end

-- Distance au carré d'un point P au segment [A, B] (produits scalaires seulement).
local function seg_d2(px, py, ax, ay, bx, by)
  local vx, vy = bx - ax, by - ay
  local wx, wy = px - ax, py - ay
  local vv = vx * vx + vy * vy
  local t = 0
  if vv > 0 then
    t = (wx * vx + wy * vy) / vv
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
  end
  local dx, dy = ax + t * vx - px, ay + t * vy - py
  return dx * dx + dy * dy
end

--- Nids vus à moins de K.PATH tuiles du segment from → site.
function K.path_nests(m, from, site)
  local n = 0
  local x0 = math.floor((math.min(from.x, site.x) - K.PATH) / K.SECTOR)
  local x1 = math.floor((math.max(from.x, site.x) + K.PATH) / K.SECTOR)
  local y0 = math.floor((math.min(from.y, site.y) - K.PATH) / K.SECTOR)
  local y1 = math.floor((math.max(from.y, site.y) + K.PATH) / K.SECTOR)
  local p2 = K.PATH * K.PATH
  for sy = y0, y1 do
    for sx = x0, x1 do
      local s = m.s[A.key(sx, sy)]
      if s then
        for _, p in ipairs(s.sp or {}) do
          if seg_d2(p.x, p.y, from.x, from.y, site.x, site.y) <= p2 then n = n + 1 end
        end
      end
    end
  end
  return n
end

--- Part VUE (0 à 100) du voisinage d'un point : le secteur et ses 8 voisins.
function K.seen_pct(m, x, y)
  local sx, sy = A.sector_of(x, y)
  local n = 0
  for dy = -1, 1 do
    for dx = -1, 1 do
      if m.s[A.key(sx + dx, sy + dy)] then n = n + 1 end
    end
  end
  return math.floor(n * 100 / 9)
end

--- Entrées du risque d'un site (E.risk, §4.2) tirées de la SEULE connaissance de l'équipe. enemy_zone : à l'appelant
--- (territoire des factions, IA2-c).
function K.site_inputs(m, site, from, tick, enemy_zone)
  local nests, worms = K.enemies_near(m, site.x, site.y, K.NEAR)
  local dx, dy = site.x - from.x, site.y - from.y
  return {
    spawners = nests, worms = worms, path_nests = K.path_nests(m, from, site),
    seen_pct = K.seen_pct(m, site.x, site.y), losses = K.marks_near(m, site.x, site.y, K.NEAR, tick),
    enemy_zone = enemy_zone or false, distance = math.floor(math.sqrt(dx * dx + dy * dy)),
  }
end

--- Risque (pour mille) et bande d'expédition d'un site (E.risk, E.decide de shared/ai3/expedition.lua).
function K.site_risk(m, site, from, tick, enemy_zone)
  local inputs = K.site_inputs(m, site, from, tick, enemy_zone)
  local risk, parts = E.risk(inputs)
  return risk, inputs, parts
end

---------------------------------------------------------------------------------------------------
-- Où chercher
---------------------------------------------------------------------------------------------------
--- Danger (pour mille) d'un secteur pour un éclaireur. rivals = { {x, y}, ... } (QG rivaux connus).
function K.sector_risk(m, key, tick, rivals)
  local D = K.DANGER
  local sx, sy = A.xy(key)
  local r = 0
  for dy = -1, 1 do
    for dx = -1, 1 do
      local s = m.s[A.key(sx + dx, sy + dy)]
      if s then r = r + D.nest * #(s.sp or {}) + D.worm * #(s.wm or {}) end
    end
  end
  local cx, cy = A.center(sx, sy)
  local mr2 = D.mark_radius * D.mark_radius
  for _, mk in ipairs(m.marks) do
    local age = tick - mk.t
    if age >= 0 and age < D.mark_ttl and (mk.x - cx) ^ 2 + (mk.y - cy) ^ 2 <= mr2 then
      r = r + math.floor(mk.w * (D.mark_ttl - age) / D.mark_ttl)
    end
  end
  local rr2 = D.rival_radius * D.rival_radius
  for _, h in ipairs(rivals or {}) do
    if (h.x - cx) ^ 2 + (h.y - cy) ^ 2 <= rr2 then r = r + D.rival end
  end
  if r > D.cap then r = D.cap end
  return r
end

--- Frontière : secteurs NON VUS voisins (8-connexité) d'un secteur vu, triés par clé.
function K.frontier(m)
  local out, added = {}, {}
  for _, k in ipairs(sorted_keys(m.s)) do
    local sx, sy = A.xy(k)
    for dy = -1, 1 do
      for dx = -1, 1 do
        if dx ~= 0 or dy ~= 0 then
          local nk = A.key(sx + dx, sy + dy)
          if not m.s[nk] and not added[nk] then
            added[nk] = true
            out[#out + 1] = nk
          end
        end
      end
    end
  end
  table.sort(out)
  return out
end

--- A priori (pour mille) d'une ressource JAMAIS vue par l'équipe : plus loin du point de départ de la carte, plus
--- probable (règle générique du jeu : les ressources rares ne sont pas dans la zone de départ, la richesse croît avec
--- la distance). Facteur 0,5 à 2 selon la distance du secteur au départ, rapportée à celle du QG (au moins 256).
--- Une ressource déjà vue quelque part : a priori uniforme (1 000).
function K.prior(m, res, key, spawn, hq)
  if res == nil or m.found[res] then return 1000 end
  local cx, cy = A.center(A.xy(key))
  local ds = math.sqrt((cx - spawn.x) ^ 2 + (cy - spawn.y) ^ 2)
  local dh = math.max(256, math.sqrt((hq.x - spawn.x) ^ 2 + (hq.y - spawn.y) ^ 2))
  local p = math.floor(1000 * ds / dh)
  if p < 500 then p = 500 elseif p > 2000 then p = 2000 end
  return p
end

--- Lot VEILLE : le trajet en ligne droite de `a` à `b` passe-t-il loin de tout nid et de tout ver VUS ? Un point échantillonné tous les
--- 64 tuiles (extrémités comprises) ne doit avoir ni nid ni ver à moins de K.PATH_CLEAR_NEST tuiles. Aucune trigonométrie.
K.PATH_CLEAR_NEST = 64
function K.path_clear(m, a, b)
  local dx, dy = b.x - a.x, b.y - a.y
  local n = math.max(1, math.floor(math.sqrt(dx * dx + dy * dy) / 64))
  for i = 0, n do
    local nests, worms = K.enemies_near(m, a.x + dx * i / n, a.y + dy * i / n, K.PATH_CLEAR_NEST)
    if nests + worms > 0 then return false end
  end
  return true
end

--- Meilleure cible d'exploration. ctx = { hq = {x, y}, me = {x, y}, tick, res (ou nil), spawn = {x, y},
--- rivals = { {x, y} }, exclude = { [clé] = true }, max_dist }. Renvoie clé, note (nil si aucune).
function K.best_target(m, ctx)
  local best, bs
  local maxd = ctx.max_dist or K.MAX_DIST
  local spawn = ctx.spawn or { x = 0, y = 0 }
  for _, k in ipairs(K.frontier(m)) do
    if not (ctx.exclude and ctx.exclude[k]) then
      local cx, cy = A.center(A.xy(k))
      local dh = math.sqrt((cx - ctx.hq.x) ^ 2 + (cy - ctx.hq.y) ^ 2)
      if dh <= maxd then
        local risk = K.sector_risk(m, k, ctx.tick, ctx.rivals)
        if risk < K.DANGER.skip then
          local me = ctx.me or ctx.hq
          local dm = math.sqrt((cx - me.x) ^ 2 + (cy - me.y) ^ 2)
          local score = K.prior(m, ctx.res, k, spawn, ctx.hq) * (1000 - risk) / (dh + dm + 100)
          if not bs or score > bs then best, bs = k, score end
        end
      end
    end
  end
  return best, bs
end

--- Point de passage vers une cible, à au plus `step` tuiles de l'éclaireur (reste dans la zone générée autour de
--- lui ; le chemin d'un personnage ne traverse pas une zone non générée).
function K.toward(me, target, step)
  local dx, dy = target.x - me.x, target.y - me.y
  local d = math.sqrt(dx * dx + dy * dy)
  if d <= step or d == 0 then return { x = target.x, y = target.y } end
  return { x = me.x + dx * step / d, y = me.y + dy * step / d }
end

-- Octants (mêmes vecteurs que C.DIRS de shared/faction/chef.lua, constants : aucune trigonométrie).
local D = 0.70710678
K.DIRS = { [0] = { 1, 0 }, { D, D }, { 0, 1 }, { -D, D }, { -1, 0 }, { -D, -D }, { 0, -1 }, { D, -D } }

--- Lot EXPLO : régions où un chemin a raté (lac, falaises, île) : { { ox, oy, x, y, tick } } (ox, oy : où était
--- l'éclaireur ; x, y : le point de passage raté). Un point est « bloqué » s'il est à moins de `radius` tuiles du point
--- raté, OU dans le cône de K.BLOCK_COS (cosinus de l'angle, 0,8 : environ 37°) autour de la direction éclaireur -> point
--- raté, au-delà de 70 % de cette distance : un chemin raté dit que toute la région derrière est mal desservie (moteur
--- réel, 28/10, graine 20261020 : Azur, lac de 200 tuiles à l'ouest du QG, 17 fins « chemin » sur 30 départs : les
--- secteurs voisins, un par un, échouaient tous). Pas de trigonométrie : produits scalaires.
K.BLOCK_COS = 0.8
function K.blocked_near(blocked, x, y, tick, radius, ttl)
  for _, b in ipairs(blocked or {}) do
    if tick - b.tick < ttl then
      if (b.x - x) ^ 2 + (b.y - y) ^ 2 < radius * radius then return true end
      local ux, uy = b.x - b.ox, b.y - b.oy
      local ud = math.sqrt(ux * ux + uy * uy)
      local vx, vy = x - b.ox, y - b.oy
      local vd = math.sqrt(vx * vx + vy * vy)
      if ud > 0 and vd >= 0.7 * ud and (vx * ux + vy * uy) >= K.BLOCK_COS * vd * ud then return true end
    end
  end
  return false
end

--- Ajoute un échec (éclaireur en ox, oy ; point de passage raté en x, y). Au plus `cap` entrées, les plus anciennes
--- d'abord oubliées ; un échec voisin (point raté à moins de 32 tuiles, origine à moins de 64) rafraîchit l'entrée.
function K.note_blocked(blocked, ox, oy, x, y, tick, cap)
  for _, b in ipairs(blocked) do
    if (b.x - x) ^ 2 + (b.y - y) ^ 2 < 32 * 32 and (b.ox - ox) ^ 2 + (b.oy - oy) ^ 2 < 64 * 64 then
      b.tick = tick
      return
    end
  end
  blocked[#blocked + 1] = { ox = ox, oy = oy, x = x, y = y, tick = tick }
  while #blocked > cap do table.remove(blocked, 1) end
end

--- Anneau du tour du propriétaire : 8 points à r tuiles autour de (x, y), en partant de l'octant `first` (0 à 7).
function K.ring(x, y, r, first)
  local out = {}
  for i = 0, 7 do
    local d = K.DIRS[((first or 0) + i) % 8]
    out[#out + 1] = { x = math.floor(x + d[1] * r) + 0.5, y = math.floor(y + d[2] * r) + 0.5 }
  end
  return out
end

--- Résumé (journal, fenêtre) : secteurs vus, gisements par ressource, nids et vers vus.
function K.summary(m)
  local deps, nests, worms = {}, 0, 0
  for _, k in ipairs(sorted_keys(m.s)) do
    local s = m.s[k]
    for _, r in ipairs(s.r or {}) do deps[r.name] = (deps[r.name] or 0) + 1 end
    nests = nests + #(s.sp or {})
    worms = worms + #(s.wm or {})
  end
  return { sectors = m.n, deposits = deps, nests = nests, worms = worms }
end

return K
