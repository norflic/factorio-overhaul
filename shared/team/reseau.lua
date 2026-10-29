--[[
  RÉSEAU ÉLECTRIQUE des équipes de PNJ (lot RESEAU ; constat du DC en jouant : « c'est la seule source d'électricité de
  toute la base », des convoyeurs pleins non utilisés faute de courant, « ils sont incapables de détecter des zones qui ne
  sont pas couvertes », un poteau détruit lors d'une attaque n'est pas remplacé : « problème de connexité, théorie des
  graphes »). Lua PUR : aucune API du jeu, aucun nom d'objet ; tout vient des DONNÉES que l'appelant lit aux prototypes
  (portée de fil, aire d'alimentation, puissance) : testé hors jeu par tests/reseau_test.lua.

  MODÈLE (le même que le moteur) :
    - poteau { id, x, y, wire, supply } : deux poteaux sont reliés quand leur distance est au plus min(wire a, wire b) ;
      l'aire d'alimentation est le carré de demi-côté `supply` centré sur le poteau ;
    - consommateur { id, x0, y0, x1, y1, kw, starved } et producteur { id, x0, y0, x1, y1, kw, out_kw } : un bâtiment est
      alimenté quand sa boîte chevauche (surface strictement positive) l'aire d'un poteau d'une composante qui touche un
      producteur ; kw = puissance maximale lue au prototype, out_kw = puissance produite observée.

  CE QUE LA RÈGLE RÉPOND (une seule passe O(n + m + K), reprenable par tranches de travail : K10) :
    (a) COUVERTURE   R.analyse -> consommateurs hors de toute aire (`uncovered`), regroupés en ZONES (R.zones) ;
    (b) CONNEXITÉ    composantes (union-find), îlots sans producteur (`orphans`), POTEAUX PIVOTS (R.pivot_*, points
                     d'articulation et poteaux seuls à couvrir un bâtiment : ce que leur perte éteint) et plan de
                     RÉPARATION au coût minimal (R.repair : plus courts chemins répétés, heuristique de Steiner, puis
                     élagage) ;
    (c) CAPACITÉ     R.capacity, R.verdict : charge contre production, alerte à R.ALERT (80 %) AVANT la saturation,
                     nombre d'unités de centrale à ajouter pour revenir à R.TARGET ;
    (d) ÉTAT         consommateurs affamés (barre d'énergie basse) comptés, imputés à la capacité seulement si la
                     production est pleine (sinon : fil, combustible).
  Déterminisme : listes triées, aucun `pairs` dans une décision, aucune trigonométrie, aucun hasard ; les égalités se
  départagent par l'indice.
]]

local R = {}

R.ALERT = 0.8            -- demande du DC : alerte à 80 % de charge
R.TARGET = 0.6           -- charge visée après agrandissement (marge de croissance, pas d'ultra-maximisation)
R.FULL = 0.95            -- au-delà, la production est « pleine » : un consommateur affamé est imputé à la capacité
R.STARVED_FRACTION = 0.1 -- barre d'énergie sous 10 % du tampon : affamé
R.EPS = 1e-6
local EPS = R.EPS
local INF = math.huge

local floor, min, max = math.floor, math.min, math.max

local function gkey(cx, cy) return (cx + 1048576) * 2097152 + (cy + 1048576) end

---------------------------------------------------------------------------------------------------
-- Géométrie
---------------------------------------------------------------------------------------------------
--- Le carré d'alimentation du poteau `p` chevauche-t-il la boîte `b` (surface strictement positive) ?
function R.covers(p, b)
  local s = p.supply
  return b.x0 < p.x + s - EPS and b.x1 > p.x - s + EPS and b.y0 < p.y + s - EPS and b.y1 > p.y - s + EPS
end

--- Deux poteaux sont-ils reliés par un fil ?
function R.linked(p, q)
  local reach = min(p.wire, q.wire)
  if reach <= 0 then return false end
  local dx, dy = p.x - q.x, p.y - q.y
  return dx * dx + dy * dy <= reach * reach + EPS
end

--- Fils entre poteaux : liste de { i, j } (i < j) triée. Grille de côté = plus grande portée de fil (3 × 3 cases).
function R.links(poles)
  local n = #poles
  local maxw = 0
  for i = 1, n do if poles[i].wire > maxw then maxw = poles[i].wire end end
  local edges = {}
  if maxw <= 0 then return edges end
  local grid = {}
  for i = 1, n do
    local k = gkey(floor(poles[i].x / maxw), floor(poles[i].y / maxw))
    local g = grid[k]
    if not g then g = {}; grid[k] = g end
    g[#g + 1] = i
  end
  for i = 1, n do
    local p = poles[i]
    local cx, cy = floor(p.x / maxw), floor(p.y / maxw)
    for dx = -1, 1 do
      for dy = -1, 1 do
        local g = grid[gkey(cx + dx, cy + dy)]
        if g then
          for _, j in ipairs(g) do
            if j > i and R.linked(p, poles[j]) then edges[#edges + 1] = { i, j } end
          end
        end
      end
    end
  end
  table.sort(edges, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
  return edges
end

--- Listes d'adjacence triées.
function R.adjacency(n, edges)
  local adj = {}
  for i = 1, n do adj[i] = {} end
  for _, e in ipairs(edges) do
    adj[e[1]][#adj[e[1]] + 1] = e[2]
    adj[e[2]][#adj[e[2]] + 1] = e[1]
  end
  for i = 1, n do table.sort(adj[i]) end
  return adj
end

--- Composantes connexes : comp[i] numérotées par le plus petit indice de poteau, ncomp, listes de poteaux par composante.
--- `skip` : poteau ignoré (comp[skip] = nil).
function R.components(n, adj, skip)
  local comp, lists, nc = {}, {}, 0
  local stack = {}
  for s = 1, n do
    if s ~= skip and not comp[s] then
      nc = nc + 1
      local list = { s }
      comp[s] = nc
      stack[1] = s
      local top = 1
      while top > 0 do
        local v = stack[top]
        top = top - 1
        for _, w in ipairs(adj[v]) do
          if w ~= skip and not comp[w] then
            comp[w] = nc
            list[#list + 1] = w
            top = top + 1
            stack[top] = w
          end
        end
      end
      table.sort(list)
      lists[nc] = list
    end
  end
  return comp, nc, lists
end

--- Points d'articulation (Tarjan, itératif) : art[i] vrai si retirer le poteau i sépare sa composante.
function R.articulation(n, adj)
  local disc, low, art, parent = {}, {}, {}, {}
  local t = 0
  for s = 1, n do
    if not disc[s] then
      local stack, iter = { s }, { [s] = 1 }
      local top = 1
      local root_children = 0
      t = t + 1
      disc[s], low[s] = t, t
      while top > 0 do
        local v = stack[top]
        local i = iter[v]
        local nb = adj[v][i]
        if nb then
          iter[v] = i + 1
          if not disc[nb] then
            parent[nb] = v
            if v == s then root_children = root_children + 1 end
            t = t + 1
            disc[nb], low[nb] = t, t
            iter[nb] = 1
            top = top + 1
            stack[top] = nb
          elseif nb ~= parent[v] then
            if disc[nb] < low[v] then low[v] = disc[nb] end
          end
        else
          top = top - 1
          local p = parent[v]
          if p then
            if low[v] < low[p] then low[p] = low[v] end
            if p ~= s and low[v] >= disc[p] then art[p] = true end
          end
        end
      end
      if root_children > 1 then art[s] = true end
    end
  end
  return art
end

---------------------------------------------------------------------------------------------------
-- Analyse (couverture, composantes, état), par tranches de travail
---------------------------------------------------------------------------------------------------
-- net = { poles = {...}, consumers = {...}, producers = {...}, edges = (facultatif : fils réels du moteur) }
local PHASES = { "index", "links", "comps", "cover_c", "cover_p", "stats" }

--- Tâche d'analyse reprenable : R.job_step(job, travail) rend vrai à la fin ; le résultat est job.A.
function R.job(net)
  local job = { net = net, phase = 1, cur = 1, A = nil, work = 0 }
  job.n = #(net.poles or {})
  job.edges = net.edges
  return job
end

local function cover_of(job, list, grid, cell, maxs, k)
  local poles = job.net.poles
  local b = list[k]
  local out = {}
  local c0x, c1x = floor((b.x0 - maxs) / cell), floor((b.x1 + maxs) / cell)
  local c0y, c1y = floor((b.y0 - maxs) / cell), floor((b.y1 + maxs) / cell)
  local w = 0
  for cx = c0x, c1x do
    for cy = c0y, c1y do
      local g = grid[gkey(cx, cy)]
      if g then
        for _, i in ipairs(g) do
          w = w + 1
          if R.covers(poles[i], b) then out[#out + 1] = i end
        end
      end
    end
  end
  table.sort(out)
  return out, w + 1
end

function R.job_step(job, budget)
  local net = job.net
  local poles, cons, prods = net.poles or {}, net.consumers or {}, net.producers or {}
  local n = job.n
  while budget > 0 and job.phase <= #PHASES do
    local ph = PHASES[job.phase]
    if ph == "index" then
      if not job.gs then
        local maxs = 0
        for i = 1, n do if poles[i].supply > maxs then maxs = poles[i].supply end end
        job.maxs = maxs
        job.cell = max(1, 2 * maxs)
        job.gs = {}
      end
      while job.cur <= n and budget > 0 do
        local p = poles[job.cur]
        local k = gkey(floor(p.x / job.cell), floor(p.y / job.cell))
        local g = job.gs[k]
        if not g then g = {}; job.gs[k] = g end
        g[#g + 1] = job.cur
        job.cur = job.cur + 1
        budget = budget - 1
      end
      if job.cur > n then job.phase, job.cur = job.phase + 1, 1 end
    elseif ph == "links" then
      if job.edges then
        job.phase = job.phase + 1
      else
        -- les fils se calculent d'un bloc (grille de portée) : O(n × voisins), compté en entier
        job.edges = R.links(poles)
        budget = budget - n - #job.edges
        job.phase = job.phase + 1
      end
    elseif ph == "comps" then
      job.adj = R.adjacency(n, job.edges)
      job.comp, job.ncomp, job.comp_poles = R.components(n, job.adj)
      budget = budget - n - #job.edges
      job.cover_c, job.cover_p = {}, {}
      job.phase, job.cur = job.phase + 1, 1
    elseif ph == "cover_c" or ph == "cover_p" then
      local list = ph == "cover_c" and cons or prods
      local out = ph == "cover_c" and job.cover_c or job.cover_p
      while job.cur <= #list and budget > 0 do
        local c, w = cover_of(job, list, job.gs, job.cell, job.maxs, job.cur)
        out[job.cur] = c
        job.cur = job.cur + 1
        budget = budget - w
      end
      if job.cur > #list then job.phase, job.cur = job.phase + 1, 1 end
    else -- stats
      job.A = R.finish(job)
      budget = budget - #cons - #prods
      job.phase = job.phase + 1
    end
  end
  return job.phase > #PHASES
end

--- Résultat d'analyse depuis une tâche dont les couvertures sont prêtes.
function R.finish(job)
  local net = job.net
  local cons, prods = net.consumers or {}, net.producers or {}
  local comp, nc = job.comp, job.ncomp
  local touch = {}               -- composante -> vrai si un producteur la touche
  for k = 1, #prods do
    for _, i in ipairs(job.cover_p[k]) do touch[comp[i]] = true end
  end
  local A = {
    n = job.n, edges = job.edges, adj = job.adj, comp = comp, ncomp = nc, comp_poles = job.comp_poles,
    cover_c = job.cover_c, cover_p = job.cover_p, touch = touch,
    powered = {}, cons_comp = {}, prod_comp = {}, comps = {},
    uncovered = {}, orphans = {}, starved = {}, n_powered = 0,
  }
  for c = 1, nc do
    A.comps[c] = { poles = #job.comp_poles[c], prod = touch[c] or false, prod_kw = 0, out_kw = 0, dem_kw = 0, n_prod = 0, n_cons = 0,
      starved = 0, starved_kw = 0 }
  end
  -- un producteur compte dans la plus petite composante qui le touche (pas de double compte des kW)
  for k = 1, #prods do
    local cl = job.cover_p[k]
    local best
    for _, i in ipairs(cl) do if not best or comp[i] < best then best = comp[i] end end
    A.prod_comp[k] = best
    if best then
      local s = A.comps[best]
      s.n_prod = s.n_prod + 1
      s.prod_kw = s.prod_kw + (prods[k].kw or 0)
      s.out_kw = s.out_kw + (prods[k].out_kw or 0)
    end
  end
  for k = 1, #cons do
    local cl = job.cover_c[k]
    if #cl == 0 then
      A.uncovered[#A.uncovered + 1] = k
    else
      local live, any
      for _, i in ipairs(cl) do
        local c = comp[i]
        if touch[c] and (not live or c < live) then live = c end
        if not any or c < any then any = c end
      end
      A.powered[k] = live ~= nil
      A.cons_comp[k] = live or any
      local s = A.comps[A.cons_comp[k]]
      s.n_cons = s.n_cons + 1
      s.dem_kw = s.dem_kw + (cons[k].kw or 0)
      if live then
        A.n_powered = A.n_powered + 1
        if cons[k].starved then
          s.starved = s.starved + 1
          s.starved_kw = s.starved_kw + (cons[k].kw or 0)
          A.starved[#A.starved + 1] = k
        end
      else
        A.orphans[#A.orphans + 1] = k
      end
    end
  end
  -- îlots : composantes sans producteur qui portent des consommateurs ; antennes mortes : sans producteur ni consommateur
  A.islands, A.dead = {}, {}
  for c = 1, nc do
    local s = A.comps[c]
    if not s.prod then
      if s.n_cons > 0 then A.islands[#A.islands + 1] = c else A.dead[#A.dead + 1] = c end
    end
  end
  return A
end

--- Analyse complète d'un coup.
function R.analyse(net)
  local job = R.job(net)
  R.job_step(job, INF)
  return job.A
end

---------------------------------------------------------------------------------------------------
-- Poteaux pivots : ce que la perte d'un poteau éteint
---------------------------------------------------------------------------------------------------
--- Perte exacte si le poteau `p` disparaît : { n, kw, islands } = consommateurs alimentés avant et plus après, et nombre
--- de composantes qui perdent leur courant avec des consommateurs. Même définition que l'analyse (touche un producteur).
function R.loss(net, A, p)
  local cons, prods = net.consumers or {}, net.producers or {}
  local c0 = A.comp[p]
  local sub, nsub = {}, 0
  local list = A.comp_poles[c0]
  local stack = {}
  for _, s in ipairs(list) do
    if s ~= p and not sub[s] then
      nsub = nsub + 1
      sub[s] = nsub
      stack[1] = s
      local top = 1
      while top > 0 do
        local v = stack[top]
        top = top - 1
        for _, w in ipairs(A.adj[v]) do
          if w ~= p and not sub[w] then sub[w] = nsub; top = top + 1; stack[top] = w end
        end
      end
    end
  end
  local has = {}
  for k = 1, #prods do
    for _, i in ipairs(A.cover_p[k]) do
      if i ~= p and A.comp[i] == c0 then has[sub[i]] = true end
    end
  end
  local lost, kw = 0, 0
  local dark = {}
  for k = 1, #cons do
    if A.powered[k] then
      local cl = A.cover_c[k]
      local touches = false
      for _, i in ipairs(cl) do
        if i ~= p then
          if A.comp[i] == c0 then
            if has[sub[i]] then touches = true break end
          elseif A.touch[A.comp[i]] then touches = true break end
        end
      end
      if not touches then
        lost, kw = lost + 1, kw + (cons[k].kw or 0)
        for _, i in ipairs(cl) do if i ~= p and A.comp[i] == c0 then dark[sub[i]] = true end end
      end
    end
  end
  local islands = 0
  for _ in pairs(dark) do islands = islands + 1 end -- compte seulement : l'ordre est sans effet
  return { n = lost, kw = kw, islands = islands }
end

--- Poteaux à examiner : points d'articulation et poteaux SEULS à couvrir, dans une composante qui touche un producteur,
--- un bâtiment alimenté ou un producteur (tout autre poteau peut disparaître sans rien éteindre : sa composante reste
--- connexe, ses producteurs et ses bâtiments gardent une autre aire dans la même composante).
function R.pivot_candidates(net, A)
  local art = R.articulation(A.n, A.adj)
  local sole = {}
  local function mark(cl, only_live)
    local per = {}
    for _, i in ipairs(cl) do
      local c = A.comp[i]
      if not only_live or A.touch[c] then
        local e = per[c]
        if not e then per[c] = { i, 1 } else e[2] = e[2] + 1 end
      end
    end
    for _, e in pairs(per) do if e[2] == 1 then sole[e[1]] = true end end -- marquage seulement : l'ordre est sans effet
  end
  for k = 1, #(net.consumers or {}) do
    if A.powered[k] then mark(A.cover_c[k], true) end
  end
  for k = 1, #(net.producers or {}) do mark(A.cover_p[k], false) end
  local out = {}
  for i = 1, A.n do if art[i] or sole[i] then out[#out + 1] = i end end
  return out, art
end

--- Tâche de pivots reprenable : R.pivot_step(job, travail) -> fini ? ; résultat job.out triée (perte en kW décroissante,
--- puis en nombre, puis indice) : { pole, n, kw, islands }.
function R.pivot_job(net, A)
  local cand, art = R.pivot_candidates(net, A)
  return { net = net, A = A, cand = cand, art = art, cur = 1, out = {}, done = false }
end

function R.pivot_step(job, budget)
  while job.cur <= #job.cand and budget > 0 do
    local p = job.cand[job.cur]
    job.cur = job.cur + 1
    local l = R.loss(job.net, job.A, p)
    budget = budget - #job.A.comp_poles[job.A.comp[p]] - #(job.net.consumers or {}) / 8
    if l.n > 0 then job.out[#job.out + 1] = { pole = p, n = l.n, kw = l.kw, islands = l.islands, art = job.art[p] or false } end
  end
  if job.cur > #job.cand and not job.done then
    job.done = true
    table.sort(job.out, function(a, b)
      if a.kw ~= b.kw then return a.kw > b.kw end
      if a.n ~= b.n then return a.n > b.n end
      return a.pole < b.pole
    end)
  end
  return job.done
end

---------------------------------------------------------------------------------------------------
-- Réparation : quels poteaux perdus relever, au coût minimal
---------------------------------------------------------------------------------------------------
local function heap_push(h, d, v)
  local i = #h + 1
  h[i] = { d, v }
  while i > 1 do
    local p = floor(i / 2)
    local a, b = h[i], h[p]
    if a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) then h[i], h[p] = b, a; i = p else break end
  end
end

local function heap_pop(h)
  local top = h[1]
  local last = h[#h]
  h[#h] = nil
  if #h > 0 then
    h[1] = last
    local i, n = 1, #h
    while true do
      local l, r, s = 2 * i, 2 * i + 1, i
      if l <= n and (h[l][1] < h[s][1] or (h[l][1] == h[s][1] and h[l][2] < h[s][2])) then s = l end
      if r <= n and (h[r][1] < h[s][1] or (h[r][1] == h[s][1] and h[r][2] < h[s][2])) then s = r end
      if s == i then break end
      h[i], h[s] = h[s], h[i]
      i = s
    end
  end
  return top[1], top[2]
end

-- Plus courts chemins depuis les poteaux qui touchent un producteur ; coût d'un poteau = cost[v] (0 : déjà là).
local function shortest(A, nall, cost)
  local dist, prev, h = {}, {}, {}
  for v = 1, nall do dist[v] = INF end
  for k = 1, #A.cover_p do
    for _, q in ipairs(A.cover_p[k]) do
      if cost[q] < dist[q] then dist[q] = cost[q]; heap_push(h, dist[q], q) end
    end
  end
  while #h > 0 do
    local d, v = heap_pop(h)
    if d <= dist[v] then
      for _, w in ipairs(A.adj[v]) do
        local nd = d + cost[w]
        if nd < dist[w] - EPS then dist[w] = nd; prev[w] = v; heap_push(h, nd, w) end
      end
    end
  end
  return dist, prev
end

--- Plan de réparation. net = réseau ACTUEL (poteaux vivants) ; cands = poteaux perdus { x, y, wire, supply, cost? } (coût 1 par
--- défaut : un poteau à relever). Rend { chosen = indices de cands à relever (triés), cost, targets, restored,
--- unreachable } : `targets` = consommateurs éteints que les poteaux perdus, TOUS relevés, rallumeraient ; `restored` = ceux
--- que le plan rallume (tous les atteignables : `unreachable` pour les autres, faute de producteur à portée).
--- Lot RESEAU-VIVANT : `net.edges` (facultatif) = les fils REELS du moteur entre poteaux vivants ({ i, j }, i < j, sur net.poles). Le
--- modele « tous les poteaux a portee sont relies » SURESTIME la connexite (le moteur ne relie pas toute paire a portee : il plafonne le
--- nombre de voisins et evite les triangles) : des consommateurs sur un ilot reel etaient juges alimentes par le modele et le plan restait
--- vide (3 a 5 desaccords de couverture contre le moteur, branche reseau). Avec `edges`, les paires vivant-vivant sont celles du moteur ;
--- les paires ou entre un poteau perdu ou neuf restent calculees a la portee.
local function edges_with(net, poles, nlive)
  if not net.edges then return nil end
  local out = {}
  for _, e in ipairs(net.edges) do out[#out + 1] = e end
  for _, e in ipairs(R.links(poles)) do
    if e[2] > nlive then out[#out + 1] = e end
  end
  table.sort(out, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
  return out
end

function R.repair(net, cands)
  local nlive = #(net.poles or {})
  local all = {}
  for i = 1, nlive do all[i] = net.poles[i] end
  for j, c in ipairs(cands) do all[nlive + j] = c end
  local nall = #all
  local netall = { poles = all, consumers = net.consumers, producers = net.producers, edges = edges_with(net, all, nlive) }
  local A0 = R.analyse(net)
  local Aa = R.analyse(netall)
  local cons = net.consumers or {}
  local targets = {}
  for k = 1, #cons do if Aa.powered[k] and not A0.powered[k] then targets[#targets + 1] = k end end
  local cost = {}
  for v = 1, nall do cost[v] = v <= nlive and 0 or (all[v].cost or 1) end
  local chosen = {}
  local pending = {}
  for _, k in ipairs(targets) do pending[#pending + 1] = k end
  local unreachable = {}
  while #pending > 0 do
    local dist, prev = shortest(Aa, nall, cost)
    local best, bd, rest = nil, INF, {}
    for _, k in ipairs(pending) do
      local d = INF
      for _, q in ipairs(Aa.cover_c[k]) do if dist[q] < d then d = dist[q] end end
      if d == INF then
        unreachable[#unreachable + 1] = k
      elseif d > EPS then
        rest[#rest + 1] = k
        if d < bd - EPS then best, bd = k, d end
      end
    end
    pending = rest
    if not best then break end
    -- chemin vers le meilleur couvreur du consommateur choisi
    local q, qd = nil, INF
    for _, c in ipairs(Aa.cover_c[best]) do if dist[c] < qd - EPS then q, qd = c, dist[c] end end
    while q do
      if q > nlive and cost[q] > 0 then chosen[q - nlive] = true; cost[q] = 0 end
      q = prev[q]
    end
  end
  -- élagage : un poteau relevé en trop (par ordre de coût décroissant, indice décroissant) est retiré s'il ne rallume plus rien
  local order = {}
  for j in pairs(chosen) do order[#order + 1] = j end
  table.sort(order, function(a, b)
    local ca, cb = cands[a].cost or 1, cands[b].cost or 1
    if ca ~= cb then return ca > cb end
    return a > b
  end)
  local must = {}
  for _, k in ipairs(targets) do
    local lost = false
    for _, u in ipairs(unreachable) do if u == k then lost = true end end
    if not lost then must[#must + 1] = k end
  end
  local function restores(set)
    local poles = {}
    for i = 1, nlive do poles[i] = net.poles[i] end
    for j = 1, #cands do if set[j] then poles[#poles + 1] = cands[j] end end
    local A = R.analyse({ poles = poles, consumers = cons, producers = net.producers, edges = edges_with(net, poles, nlive) })
    for _, k in ipairs(must) do if not A.powered[k] then return false end end
    return true
  end
  for _, j in ipairs(order) do
    chosen[j] = nil
    if not restores(chosen) then chosen[j] = true end
  end
  local list, total = {}, 0
  for j in pairs(chosen) do list[#list + 1] = j end
  table.sort(list)
  for _, j in ipairs(list) do total = total + (cands[j].cost or 1) end
  return { chosen = list, cost = total, targets = #targets, restored = #must, unreachable = unreachable }
end

---------------------------------------------------------------------------------------------------
-- Zones non couvertes
---------------------------------------------------------------------------------------------------
--- Regroupe des boîtes en zones (écart entre boîtes au plus `gap` tuiles, chaînage) : liste triée par (y0, x0) de
--- { x0, y0, x1, y1, n, kw, items = indices }. Écart de deux boîtes = plus grand des écarts en x et en y (0 si elles se touchent).
function R.zones(items, gap)
  local n = #items
  local parent = {}
  for i = 1, n do parent[i] = i end
  local function find(x)
    while parent[x] ~= x do parent[x] = parent[parent[x]]; x = parent[x] end
    return x
  end
  local cell = max(1, gap)
  local grid = {}
  for i = 1, n do
    local b = items[i]
    for cx = floor((b.x0 - gap / 2) / cell), floor((b.x1 + gap / 2) / cell) do
      for cy = floor((b.y0 - gap / 2) / cell), floor((b.y1 + gap / 2) / cell) do
        local k = gkey(cx, cy)
        local g = grid[k]
        if not g then g = {}; grid[k] = g end
        g[#g + 1] = i
      end
    end
  end
  local function dist(a, b)
    local dx = max(a.x0 - b.x1, b.x0 - a.x1, 0)
    local dy = max(a.y0 - b.y1, b.y0 - a.y1, 0)
    return max(dx, dy)
  end
  local keys = {}
  for k in pairs(grid) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local g = grid[k]
    for a = 1, #g do
      for b = a + 1, #g do
        local i, j = g[a], g[b]
        if dist(items[i], items[j]) <= gap + EPS then
          local ri, rj = find(i), find(j)
          if ri ~= rj then if ri < rj then parent[rj] = ri else parent[ri] = rj end end
        end
      end
    end
  end
  local by, order = {}, {}
  for i = 1, n do
    local r = find(i)
    local z = by[r]
    if not z then
      z = { x0 = items[i].x0, y0 = items[i].y0, x1 = items[i].x1, y1 = items[i].y1, n = 0, kw = 0, items = {} }
      by[r] = z
      order[#order + 1] = z
    end
    local b = items[i]
    z.x0, z.y0, z.x1, z.y1 = min(z.x0, b.x0), min(z.y0, b.y0), max(z.x1, b.x1), max(z.y1, b.y1)
    z.n = z.n + 1
    z.kw = z.kw + (b.kw or 0)
    z.items[#z.items + 1] = i
  end
  table.sort(order, function(a, b)
    if a.y0 ~= b.y0 then return a.y0 < b.y0 end
    if a.x0 ~= b.x0 then return a.x0 < b.x0 end
    return a.items[1] < b.items[1]
  end)
  return order
end

---------------------------------------------------------------------------------------------------
-- Capacité
---------------------------------------------------------------------------------------------------
--- Totaux sur les composantes qui ont un producteur : production maximale, production observée, demande déclarée des
--- bâtiments alimentés, affamés.
function R.capacity(A)
  local cap = { prod_kw = 0, out_kw = 0, dem_kw = 0, starved = 0, starved_kw = 0, n_prod = 0, n_cons = 0, islands = #A.islands,
    uncovered = #A.uncovered }
  for c = 1, A.ncomp do
    local s = A.comps[c]
    if s.prod then
      cap.prod_kw = cap.prod_kw + s.prod_kw
      cap.out_kw = cap.out_kw + s.out_kw
      cap.dem_kw = cap.dem_kw + s.dem_kw
      cap.starved = cap.starved + s.starved
      cap.starved_kw = cap.starved_kw + s.starved_kw
      cap.n_prod = cap.n_prod + s.n_prod
      cap.n_cons = cap.n_cons + s.n_cons
    end
  end
  return cap
end

--- Moyenne glissante des `n` dernières valeurs (hist est modifiée).
function R.push(hist, v, n)
  hist[#hist + 1] = v
  while #hist > n do table.remove(hist, 1) end
  local s = 0
  for _, x in ipairs(hist) do s = s + x end
  return s / #hist
end

--- Verdict de capacité. cap : R.capacity (out_kw peut être lissé par l'appelant) ; opts : unit_kw (puissance d'une unité
--- de centrale à ajouter, lue aux prototypes), plan_kw (puissance des modules électriques déjà demandés mais pas bâtis),
--- alert, target. Rend { level = "sans_centrale" | "ok" | "alerte" | "sature", load, projected, add, need_kw, why }.
function R.verdict(cap, opts)
  opts = opts or {}
  local alert, target = opts.alert or R.ALERT, opts.target or R.TARGET
  local plan = opts.plan_kw or 0
  if cap.prod_kw <= EPS then
    return { level = "sans_centrale", load = 0, projected = 0, add = 0, need_kw = 0, why = "aucun producteur alimente" }
  end
  local load = cap.out_kw / cap.prod_kw
  local need = cap.out_kw + plan
  if load >= R.FULL then need = need + cap.starved_kw end
  local projected = need / cap.prod_kw
  local level = "ok"
  if load >= R.FULL then level = "sature" elseif projected >= alert - EPS then level = "alerte" end
  local add = 0
  if level ~= "ok" then
    local unit = opts.unit_kw or 0
    if unit > EPS then
      add = max(1, math.ceil((need / target - cap.prod_kw) / unit - 1e-9))
    end
  end
  local why = string.format("charge %.0f %%, projetee %.0f %% (production %.0f kW, besoin %.0f kW)", load * 100, projected * 100,
    cap.prod_kw, need)
  return { level = level, load = load, projected = projected, add = add, need_kw = need, why = why }
end

--- Un tampon d'énergie sous la fraction donnée est affamé.
function R.is_starved(energy, buffer, frac)
  if not buffer or buffer <= 0 then return false end
  return energy < buffer * (frac or R.STARVED_FRACTION)
end

return R
