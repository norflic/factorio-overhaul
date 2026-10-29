--[[
  RELEVÉ PARESSEUX DES MASQUES PAR CHUNK LE LONG D'UN COULOIR (lot POTEAUX-MASQUES ; limite n° 2 du rapport de POTEAUX-ASTAR :
  « plan_power ne voit les obstacles que dans le rectangle de read_masks ; au-delà, masks.free répond libre partout, donc la
  recherche de chemin des poteaux ne contourne pas une montagne à mi-chemin d'une longue rue »).
  Lua PUR : aucune API du jeu. Lu hors jeu (tests/masques_test.lua) et en jeu par script/team/build.lua (plan_power).

  PRINCIPE
    - Les legs de la liaison (segments a-b que `P.pole_chain` doit relier) définissent un COULOIR : les chunks (32 × 32 tuiles,
      alignés sur la grille du jeu) dont le rectangle est à `margin` tuiles au plus d'un des segments. Liste ORDONNÉE (leg par
      leg, le long du segment, départage cy puis cx), sans doublon, plafonnée à MAX_CHUNKS (le reste du couloir reste « inconnu »,
      c'est-à-dire libre, comme avant le lot).
    - BUDGET : un essai de plan ne dispose que des `attempt × BUDGET` premiers chunks de la liste (ACCORD). Quand l'accord ne couvre
      pas toute la liste, l'appelant rend le projet en attente (Q.WAIT_TICKS) et le prochain essai accorde BUDGET chunks de plus.
      L'accord est un nombre ENTIER porté par le projet (sauvegardé) : la décision « attendre ou planifier » ne dépend donc jamais
      du contenu du cache (qui, lui, est LOCAL, jamais dans global, et vide à chaque chargement).
    - CACHE par surface : chunk → relevé { water, blocked, clear } daté. Un relevé vit TTL ticks (Q.TTL) et tombe aussi quand une
      construction touche le chunk (Q.invalidate). Un relevé périmé est relu, jamais deviné.
    - VUE (Q.view) : une tuile du rectangle déjà relevé par l'appelant (`rect`) répond comme avant le lot (octet pour octet) ;
      une tuile d'un chunk relevé répond d'après le chunk ; toute autre répond « libre » (inconnue, comptée).

  Déterminisme : aucune itération `pairs`, aucun temps mesuré, aucune trigonométrie ; flottants identiques d'un appel
  à l'autre (recherche ternaire à 40 pas fixes).
]]

local Q = {}

Q.CHUNK = 32              -- côté d'un chunk (tuiles)
Q.BUDGET = 4              -- chunks accordés de plus à chaque essai de plan
Q.MAX_CHUNKS = 20         -- couloir plafonné (5 essais au plus)
Q.TTL = 600               -- vie d'un relevé en cache (ticks)
Q.WAIT_TICKS = 10         -- attente entre deux essais d'un projet qui attend ses chunks
Q.MARGIN_MIN, Q.MARGIN_MAX = 16, 32  -- demi-largeur du couloir : 2 × portée de fil, bornée

local floor, max, min, sqrt = math.floor, math.max, math.min, math.sqrt

--- Demi-largeur du couloir (tuiles) pour une portée de fil.
function Q.margin(reach) return max(Q.MARGIN_MIN, min(Q.MARGIN_MAX, 2 * (reach or 0))) end

function Q.chunk_of(t) return floor(t / Q.CHUNK) end

--- Clé numérique d'un chunk (coordonnées de chunk entières, |c| < 2^20).
function Q.ckey(cx, cy) return (cx + 1048576) * 2097152 + (cy + 1048576) end

--- Distance (tuiles) d'un point au rectangle [x0, x1] × [y0, y1] (0 dedans).
local function rect_dist(px, py, x0, y0, x1, y1)
  local dx = max(x0 - px, 0, px - x1)
  local dy = max(y0 - py, 0, py - y1)
  return sqrt(dx * dx + dy * dy)
end

--- Distance minimale du segment a-b au rectangle (convexe le long du segment : recherche ternaire, 40 pas fixes) et paramètre t
--- (0 à 1) du point le plus proche.
local function seg_rect(a, b, x0, y0, x1, y1)
  local lo, hi = 0, 1
  local function at(t) return rect_dist(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, x0, y0, x1, y1) end
  for _ = 1, 40 do
    local m1, m2 = lo + (hi - lo) / 3, hi - (hi - lo) / 3
    if at(m1) <= at(m2) then hi = m2 else lo = m1 end
  end
  local t = (lo + hi) / 2
  return at(t), t
end

--- Couloir des legs { {a = {x, y}, b = {x, y}}, … } : liste ordonnée de { cx, cy } (au plus Q.MAX_CHUNKS) et nombre total de chunks
--- du couloir avant plafond.
function Q.corridor(legs, margin)
  local list, seen = {}, {}
  for _, leg in ipairs(legs) do
    local a, b = leg.a, leg.b
    local cx0, cx1 = Q.chunk_of(min(a.x, b.x) - margin), Q.chunk_of(max(a.x, b.x) + margin)
    local cy0, cy1 = Q.chunk_of(min(a.y, b.y) - margin), Q.chunk_of(max(a.y, b.y) + margin)
    local row = {}
    for cy = cy0, cy1 do
      for cx = cx0, cx1 do
        local k = Q.ckey(cx, cy)
        if not seen[k] then
          local d, t = seg_rect(a, b, cx * Q.CHUNK, cy * Q.CHUNK, (cx + 1) * Q.CHUNK, (cy + 1) * Q.CHUNK)
          if d <= margin then row[#row + 1] = { cx = cx, cy = cy, t = t, k = k } end
        end
      end
    end
    table.sort(row, function(p, q)
      if p.t ~= q.t then return p.t < q.t end
      if p.cy ~= q.cy then return p.cy < q.cy end
      return p.cx < q.cx
    end)
    for _, c in ipairs(row) do
      seen[c.k] = true
      list[#list + 1] = { cx = c.cx, cy = c.cy }
    end
  end
  local total = #list
  while #list > Q.MAX_CHUNKS do list[#list] = nil end
  return list, total
end

--- Chunks accordés à l'essai n° `attempt` (1 pour le premier) : attempt × BUDGET, jamais plus que la liste.
function Q.grant(attempt, n)
  return min(n, max(1, floor(attempt or 1)) * Q.BUDGET)
end

---------------------------------------------------------------------------------------------------
-- Cache par surface
---------------------------------------------------------------------------------------------------
function Q.new()
  return { ch = {}, n = 0, stats = { reads = 0, hits = 0, expired = 0, invalidated = 0 } }
end

--- Relevé du chunk s'il est en cache et encore frais, sinon nil (un relevé périmé est retiré).
function Q.get(c, cx, cy, tick)
  local k = Q.ckey(cx, cy)
  local e = c.ch[k]
  if not e then return nil end
  if tick - e.tick >= Q.TTL or tick < e.tick then
    c.ch[k] = nil
    c.n = c.n - 1
    c.stats.expired = c.stats.expired + 1
    return nil
  end
  return e.data
end

function Q.put(c, cx, cy, tick, data)
  local k = Q.ckey(cx, cy)
  if not c.ch[k] then c.n = c.n + 1 end
  c.ch[k] = { tick = tick, data = data }
end

--- Une construction a touché le rectangle de tuiles [x0, x1] × [y0, y1] : les relevés des chunks concernés tombent. Rend leur nombre.
function Q.invalidate(c, x0, y0, x1, y1)
  local dropped = 0
  for cy = Q.chunk_of(y0), Q.chunk_of(y1) do
    for cx = Q.chunk_of(x0), Q.chunk_of(x1) do
      local k = Q.ckey(cx, cy)
      if c.ch[k] then
        c.ch[k] = nil
        c.n = c.n - 1
        dropped = dropped + 1
      end
    end
  end
  c.stats.invalidated = c.stats.invalidated + dropped
  return dropped
end

function Q.clear(c) c.ch, c.n = {}, 0 end

--- Les `granted` premiers chunks de `list` : relevé du cache, ou lecture par reader(cx, cy) -> données. Rend la table
--- ckey → données, le nombre de lectures faites, le nombre de relevés pris au cache.
function Q.ensure(c, list, granted, tick, reader)
  local ready, reads, hits = {}, 0, 0
  for i = 1, min(granted, #list) do
    local ch = list[i]
    local d = Q.get(c, ch.cx, ch.cy, tick)
    if d then
      hits = hits + 1
    else
      d = reader(ch.cx, ch.cy)
      Q.put(c, ch.cx, ch.cy, tick, d)
      reads = reads + 1
    end
    ready[Q.ckey(ch.cx, ch.cy)] = d
  end
  c.stats.reads = c.stats.reads + reads
  c.stats.hits = c.stats.hits + hits
  return ready, reads, hits
end

---------------------------------------------------------------------------------------------------
-- Vue : rectangle déjà relevé + chunks relevés + inconnu
---------------------------------------------------------------------------------------------------
--- base : { free(tx, ty), clear = { [clé] = true } } relevé à l'intérieur de `rect` { x0, y0, x1, y1 } (x0, y0 inclus, x1, y1
--- exclus), ou sans rect (tout est alors à base). ready : table ckey → { water, blocked, clear } (clés de tuile par `tkey`).
--- occ_free(tx, ty) : tuile non réservée par nos projets (lue à chaque appel, jamais en cache).
--- Rend { free(tx, ty), clear(tx, ty), stats = { base, chunk, unknown } }.
function Q.view(base, rect, ready, tkey, occ_free)
  local st = { base = 0, chunk = 0, unknown = 0 }
  local function in_rect(tx, ty)
    return rect and tx >= rect.x0 and tx < rect.x1 and ty >= rect.y0 and ty < rect.y1
  end
  local function data_of(tx, ty)
    return ready[Q.ckey(Q.chunk_of(tx), Q.chunk_of(ty))]
  end
  local v = { stats = st }
  function v.free(tx, ty)
    if not rect or in_rect(tx, ty) then st.base = st.base + 1; return base.free(tx, ty) end
    local d = data_of(tx, ty)
    if not d then st.unknown = st.unknown + 1; return true end
    st.chunk = st.chunk + 1
    local k = tkey(tx, ty)
    return not d.water[k] and not d.blocked[k] and occ_free(tx, ty)
  end
  function v.clear(tx, ty)
    local k = tkey(tx, ty)
    if not rect or in_rect(tx, ty) then return base.clear[k] == true end
    local d = data_of(tx, ty)
    return d ~= nil and d.clear[k] == true
  end
  return v
end

return Q
