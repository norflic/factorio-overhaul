--[[
  CHAÎNE DE POTEAUX PAR RECHERCHE DE CHEMIN (lot POTEAUX-ASTAR, 5e retour du DC 29/10 : « un algorithme sur une grille de
  portée de liaison, en diagonale ; si une montagne bloque, il contourne ou pose plus près pour remonter et redescendre »).
  Lua PUR : aucune API du jeu ; lu hors jeu (tests/poteaux_astar_test.lua) et en jeu par shared/team/plan.lua (P.pole_chain).

  GRAPHE (borné) : les nœuds sont des positions candidates de poteaux, un seul par cellule de côté `s` tuiles (entier,
  environ reach / 3 : 3 tuiles pour un poteau moyen de portée 9, 10 pour un grand de portée 30), la plus proche du centre de la
  cellule parmi les tuiles LIBRES (free(x, y), même contrat que l'ancienne chaîne) ; plus les poteaux CONNUS du couloir (coût
  nul : on les traverse au lieu d'en doubler un). Une arête relie deux nœuds à `reach` au plus (diagonales comprises).
  COULOIR : les cellules dont le centre est à `hw` au plus du segment a-b, avec hw = 1, 2 puis 3,5 fois reach (on n'élargit que
  si le couloir étroit n'a pas de chemin). PLAFOND : `max_cells` cellules résolues au plus par appel (600 par défaut) et `max_expand` nœuds développés (2 500) ; au-delà,
  nil (l'appelant garde l'ancienne chaîne gloutonne).

  A* : coût lexicographique (nombre de poteaux NEUFS d'abord, puis longueur de fil), codé par un poids W = 1e6 par poteau neuf
  (une longueur de fil n'approche jamais 1e6) ; heuristique : distance au but (+ borne du nombre de poteaux quand le graphe n'a
  aucun poteau connu : cohérente, car une arête réduit la distance d'au plus reach, donc la borne d'au plus un poteau).
  Départages : numéros de nœuds triés par y puis x ; aucun `pairs`, aucune trigonométrie (racine carrée seulement, comme
  l'ancienne chaîne).

  Rend la liste des poteaux NEUFS dans l'ordre de a vers b (a, b et les poteaux connus ne sont pas rendus), ou nil et la raison.
]]

local Q = {}

Q.MAX_CELLS = 600
Q.MAX_EXPAND = 2500            -- nœuds développés au plus par appel (tous couloirs confondus)
Q.DIV = 3
Q.WIDTHS = { 1, 2, 3.5 }       -- demi-largeurs du couloir, en portées de fil
Q.W = 1e6                       -- poids d'un poteau neuf devant la longueur de fil

--- Compteurs de diagnostic (jamais lus par une décision) : appels, chemins trouvés, échecs, cellules résolues, appels à `free`.
Q.STATS = { calls = 0, found = 0, none = 0, too_big = 0, cells = 0, free_calls = 0, expanded = 0 }

local floor, ceil, sqrt, max = math.floor, math.ceil, math.sqrt, math.max
local EPS = 1e-9

local function dist(p, q) local dx, dy = p.x - q.x, p.y - q.y; return sqrt(dx * dx + dy * dy) end

local function seg_d2(px, py, a, b)
  local dx, dy = b.x - a.x, b.y - a.y
  local l2 = dx * dx + dy * dy
  local t = 0
  if l2 > 0 then
    t = ((px - a.x) * dx + (py - a.y) * dy) / l2
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
  end
  local qx, qy = a.x + t * dx, a.y + t * dy
  return (px - qx) * (px - qx) + (py - qy) * (py - qy)
end

-- Tas binaire (min) à départage (f, h, numéro de nœud).
local function less(x, y)
  return x.f < y.f or (x.f == y.f and (x.h < y.h or (x.h == y.h and x.k < y.k)))
end
local function heap_push(h, n)
  h[#h + 1] = n
  local i = #h
  while i > 1 do
    local p = floor(i / 2)
    if less(h[p], h[i]) or not less(h[i], h[p]) then break end
    h[p], h[i] = h[i], h[p]
    i = p
  end
end
local function heap_pop(h)
  local top = h[1]
  local last = h[#h]
  h[#h] = nil
  local n = #h
  if n > 0 then
    h[1] = last
    local i = 1
    while true do
      local l, r, m = 2 * i, 2 * i + 1, i
      if l <= n and less(h[l], h[m]) then m = l end
      if r <= n and less(h[r], h[m]) then m = r end
      if m == i then break end
      h[m], h[i] = h[i], h[m]
      i = m
    end
  end
  return top
end

local function ckey(gx, gy) return (gx + 1048576) * 2097152 + (gy + 1048576) end
local function pkey(x, y) return (floor(x * 2 + 0.5) + 524288) * 1048576 + (floor(y * 2 + 0.5) + 524288) end

--- Chaîne de a vers b. opts (facultatif) : max_cells, div (tuiles par cellule = reach / div).
function Q.path(a, b, reach, big, free, known, opts)
  opts = opts or {}
  local S = Q.STATS
  S.calls = S.calls + 1
  if dist(a, b) <= reach + EPS then S.found = S.found + 1 return {} end
  local budget = opts.max_cells or Q.MAX_CELLS
  local work = opts.max_expand or Q.MAX_EXPAND
  local s = max(1, floor(reach / (opts.div or Q.DIV) + 0.5))
  local rc = ceil(reach / s - EPS)               -- portée en cellules
  local mid = (s - 1) / 2
  local shift = big and 0 or 0.5
  -- tuiles d'une cellule, de la plus proche du centre à la plus éloignée (égalités : y, puis x)
  local offs = {}
  for oy = 0, s - 1 do for ox = 0, s - 1 do offs[#offs + 1] = { ox, oy, (ox - mid) * (ox - mid) + (oy - mid) * (oy - mid) } end end
  table.sort(offs, function(p, q)
    if p[3] ~= q[3] then return p[3] < q[3] end
    if p[2] ~= q[2] then return p[2] < q[2] end
    return p[1] < q[1]
  end)
  -- Un grand poteau (2 x 2, centre sur un coin) couvre QUATRE tuiles, dont la tuile de `free(px, py)` n'est que la quatrième :
  -- contrôle des quatre (correction de la relecture : 86 chaînes sur 400 posaient un grand poteau sur une tuile bloquée).
  local function site_free(px, py)
    if not big then return free(px, py) end
    return free(px - 0.5, py - 0.5) and free(px + 0.5, py - 0.5) and free(px - 0.5, py + 0.5) and free(px + 0.5, py + 0.5)
  end
  local memo = {}                                 -- cellule -> candidat ou false (gardé d'un couloir à l'autre)
  local function cand_of(gx, gy)
    local key = ckey(gx, gy)
    local c = memo[key]
    if c ~= nil then return c or nil, false end
    for _, o in ipairs(offs) do
      local px, py = gx * s + o[1] + shift, gy * s + o[2] + shift
      S.free_calls = S.free_calls + 1
      if site_free(px, py) then
        local da = (px - a.x) * (px - a.x) + (py - a.y) * (py - a.y)
        local db = (px - b.x) * (px - b.x) + (py - b.y) * (py - b.y)
        if da >= 0.25 and db >= 0.25 then c = { x = px, y = py } break end
      end
    end
    memo[key] = c or false
    S.cells = S.cells + 1
    return c, true
  end

  local reason = "aucun chemin"
  for _, w in ipairs(Q.WIDTHS) do
    local hw = w * reach
    local hw2 = hw * hw
    -- cellules du couloir : centre à hw au plus du segment
    local minx, maxx = math.min(a.x, b.x) - hw, math.max(a.x, b.x) + hw
    local miny, maxy = math.min(a.y, b.y) - hw, math.max(a.y, b.y) + hw
    local gx0, gx1, gy0, gy1 = floor(minx / s), floor(maxx / s), floor(miny / s), floor(maxy / s)
    if (gx1 - gx0 + 1) * (gy1 - gy0 + 1) > 8 * budget then S.too_big = S.too_big + 1 return nil, "couloir trop grand" end
    local cells, fresh = {}, 0
    for gy = gy0, gy1 do
      for gx = gx0, gx1 do
        if seg_d2((gx + 0.5) * s, (gy + 0.5) * s, a, b) <= hw2 then
          cells[#cells + 1] = { gx, gy }
          if memo[ckey(gx, gy)] == nil then fresh = fresh + 1 end
        end
      end
    end
    if fresh > budget then S.too_big = S.too_big + 1 return nil, "couloir trop grand" end
    budget = budget - fresh
    -- nœuds : départ, candidats libres, poteaux connus du couloir
    local nodes, seen = { { x = a.x, y = a.y, start = true } }, {}
    seen[pkey(a.x, a.y)] = true
    local has_known = false
    for _, k in ipairs(known or {}) do
      local pk = pkey(k.x, k.y)
      if not seen[pk] and seg_d2(k.x, k.y, a, b) <= (hw + s) * (hw + s) then
        seen[pk] = true
        nodes[#nodes + 1] = { x = k.x, y = k.y, known = true }
        has_known = true
      end
    end
    for _, c in ipairs(cells) do
      local cd = cand_of(c[1], c[2])
      if cd and not seen[pkey(cd.x, cd.y)] then
        seen[pkey(cd.x, cd.y)] = true
        nodes[#nodes + 1] = { x = cd.x, y = cd.y }
      end
    end
    table.sort(nodes, function(p, q) if p.y ~= q.y then return p.y < q.y end return p.x < q.x end)
    local buckets, sid = {}, nil
    for id, n in ipairs(nodes) do
      n.id = id
      n.gx, n.gy = floor(n.x / s), floor(n.y / s)
      local key = ckey(n.gx, n.gy)
      local l = buckets[key]
      if not l then l = {} buckets[key] = l end
      l[#l + 1] = id
      if n.start then sid = id end
    end
    local GOAL = #nodes + 1
    local function h_of(n)
      local d = dist(n, b)
      if has_known then return d end
      local hp = ceil((d - reach) / reach - EPS)
      if hp < 0 then hp = 0 end
      return hp * Q.W + d
    end
    local g, parent, closed = {}, {}, {}
    g[sid] = 0
    local open = {}
    local h0 = h_of(nodes[sid])
    heap_push(open, { f = h0, h = h0, k = sid })
    local gGoal, pGoal = nil, nil
    local found = false
    while #open > 0 do
      local cur = heap_pop(open)
      if cur.k == GOAL then found = true break end
      if not closed[cur.k] then
        closed[cur.k] = true
        S.expanded = S.expanded + 1
        work = work - 1
        if work < 0 then S.too_big = S.too_big + 1 return nil, "budget de nœuds épuisé" end
        local n = nodes[cur.k]
        local db = dist(n, b)
        if db <= reach + EPS then
          local ng = g[cur.k] + db
          if not gGoal or ng < gGoal then
            gGoal, pGoal = ng, cur.k
            heap_push(open, { f = ng, h = 0, k = GOAL })
          end
        end
        for dy = -rc, rc do
          for dx = -rc, rc do
            local l = buckets[ckey(n.gx + dx, n.gy + dy)]
            if l then
              for _, mid_ in ipairs(l) do
                if not closed[mid_] then
                  local m = nodes[mid_]
                  local d = dist(n, m)
                  if d <= reach + EPS then
                    local ng = g[cur.k] + d + (m.known and 0 or Q.W)
                    if g[mid_] == nil or ng < g[mid_] then
                      g[mid_] = ng
                      parent[mid_] = cur.k
                      local hm = h_of(m)
                      heap_push(open, { f = ng + hm, h = hm, k = mid_ })
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
    if found then
      local out, id = {}, pGoal
      while id and id ~= sid do
        if not nodes[id].known then table.insert(out, 1, { x = nodes[id].x, y = nodes[id].y }) end
        id = parent[id]
      end
      if big then
        -- deux grands poteaux d'une même chaîne (ou un poteau et le départ ou le but) ne se chevauchent pas (cellules voisines,
        -- candidats au bord de leur cellule) : sinon la chaîne est refusée (l'appelant garde la gloutonne)
        local pts = { a, b }
        for _, p in ipairs(out) do pts[#pts + 1] = p end
        for i = 1, #pts do
          for j = i + 1, #pts do
            if i ~= 1 or j ~= 2 then
              if math.abs(pts[i].x - pts[j].x) < 2 and math.abs(pts[i].y - pts[j].y) < 2 then
                S.none = S.none + 1
                return nil, "chevauchement de grands poteaux"
              end
            end
          end
        end
      end
      S.found = S.found + 1
      return out
    end
    reason = "aucun chemin (couloir " .. w .. " portée)"
  end
  S.none = S.none + 1
  return nil, reason
end

return Q
