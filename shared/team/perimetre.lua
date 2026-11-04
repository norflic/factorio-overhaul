--[[
  Lot PERIMETRE (retour du DC du 3/11, RETOUR3 : « pas d'en mettre un peu partout, mais [...] au moins à côté des points sensibles » ;
  « aucune prévision » ; « un premier périmètre puis un deuxième périmètre » ; « une fois qu'une équipe roule sur l'or, elle peut se
  permettre d'investir une partie de ses ressources dans la protection »). Spécification : fo-logs/2026-11-03_PERIMETRE/SPEC.md.

  Lua PUR : aucune API du jeu, aucun nom d'objet (les rôles sont ceux de shared/ai3/reglages.lua, R.ENTITY_ROLE), aucun `pairs` dans une
  décision, aucune trigonométrie (racine carrée seulement), aucun hasard. Testé hors jeu : tests/perimetre_test.lua.

  1. POINTS SENSIBLES { x, y, role } : rôles de Pe.ROLE_W (fabrique, labo, chauffe, generateur, pompe, foreuse) et « qg » (le coffre).
  2. COUVERT : une tourelle à au plus rc = Pe.COVER_PCT % de sa portée (convention de Pose.COVER_PCT).
  3. POSTES « point » : glouton sur les points NON couverts (cases de Pe.CELL tuiles) ; un poste couvre ce qui est à moins de rc - Pe.HALF
     de son centre (ses deux tourelles sont à Pe.HALF du centre). Postes PERSISTANTS (renforcement) ; sans point à rc, le poste disparaît.
  4. PÉRIMÈTRES EMBOÎTÉS : boîte du CŒUR (points reliés au QG de proche en proche à au plus Pe.LINK, Chebyshev) élargie de Pe.MARGIN ; le
     mur de l'enceinte, quand il existe, devient l'anneau 1 (rentré de Pe.INSET). Anneaux FIGÉS ; un nouveau quand la boîte dépasse le
     dernier de Pe.GROW sur un côté (union : jamais plus petit), au plus Pe.MAX_RINGS (au-delà, le dernier est remplacé).
  5. POSTES D'ANNEAU : les coins, puis un poste tous les au plus Pe.SPACING_MUL × rc le long de chaque côté.
  6. GROUPES : Pe.GROUP tourelles (Pe.GROUP_THREAT si menacé) ; « déjà là » = tourelles à moins de Pe.HAVE_R du centre.
  7. ORDRE : postes « point » (menace, poids, numéro), puis anneaux 1, 2, 3 (menace, poids, numéro).
  8. BUDGET : tourelles du périmètre vivantes <= Pe.BUDGET_PCT % du surplus de fer / coût d'une tourelle armée (Pe.allowed), et rien
     sous Pe.RICH_IRON plaques de fer au stock (équipe riche seulement) ; avec le besoin évalué, Pe.FREE_PCT % du fer LIBRE hors besoin.
]]

local Pe = {}

Pe.COVER_PCT = 80      -- % de la portée : une tourelle couvre un point à moins de cela
Pe.MAX_DIST = 192      -- tuiles (Chebyshev) du QG : au-delà, aucun point sensible
Pe.CELL = 4            -- tuiles : cases d'agrégation des points non couverts
Pe.HALF = 3.5          -- tuiles : demi-écart des deux tourelles d'un groupe (écart 7 >= Pose.gap 6, et < portée)
Pe.MAX_POSTS = 24      -- postes « point » au plus
Pe.LINK = 32           -- tuiles (Chebyshev) : un point à moins de cela d'un point du cœur est du cœur
Pe.MARGIN = 5          -- tuiles entre la boîte du cœur et l'anneau
Pe.INSET = 3           -- tuiles entre le mur de l'enceinte et l'anneau (tourelles DERRIÈRE le mur)
Pe.GROW = 16           -- tuiles : la base a grandi d'autant sur un côté -> nouvel anneau
Pe.MAX_RINGS = 3
Pe.EVERY = 18000       -- ticks (5 min) : relevé (lu par l'appelant)
Pe.MIN_POINTS = 8      -- points sensibles du cœur avant toute prévision
Pe.SPACING_MUL = 2     -- pas des postes d'anneau : 2 × rc (chaque groupe tient ± rc du tronçon)
Pe.GROUP = 2           -- tourelles par poste
Pe.GROUP_THREAT = 3    -- ... par poste menacé
Pe.THREAT_R = 64       -- tuiles : une attaque ou un nid à moins de cela menace le poste
Pe.W_NEST = 500        -- poids de menace d'un nid (une cellule attaquée du front pèse son score, 400 à 4 000)
Pe.ACCEPT = 8          -- tuiles : une pose plus loin du centre du poste est refusée
Pe.HAVE_R = 10         -- tuiles : tourelles « déjà là » d'un poste
Pe.REST = 7200         -- ticks : repos d'un poste après une pose nulle (multiplié par les poses nulles de suite)
Pe.REST_MAX = 6
Pe.BUDGET_PCT = 15     -- % du surplus de fer que les tourelles du périmètre peuvent immobiliser
-- Essai 1 (verif-guide 1618033988, fer de 0 à 977 : une tourelle « payable » à 950 de fer, fabriquée puis prise par les autres postes, partie
-- divergente) : la prévision n'achète rien sous Pe.RICH_IRON plaques de fer au stock (le DC : « une fois qu'une équipe roule sur l'or »).
Pe.RICH_IRON = 2000
-- Tour 3 (lead, 4/11 : « puiser dans le stock libre hors besoin, jusqu'à 30 % » ; partie du DC à 140 min : 22 855 MU libres, besoins
-- couverts, 0 dépensé en défense) : avec le besoin évalué (shared/ai3/reserve.lua), la base du budget est le fer LIBRE une fois le besoin
-- payé (0 si le besoin n'est pas couvert), à Pe.FREE_PCT % ; sans besoin évalué, la règle du tour 2 (Pe.BUDGET_PCT % du fer au-dessus du plancher).
Pe.FREE_PCT = 30
Pe.ROLE_W = { fabrique = 3, labo = 3, chauffe = 3, generateur = 3, pompe = 2, foreuse = 1 }
Pe.HQ_W = 20
Pe.CAT = { fabrique = "fab", labo = "labo", chauffe = "centrale", generateur = "centrale", pompe = "centrale", foreuse = "foreuse", qg = "qg" }
Pe.CATS = { "fab", "centrale", "labo", "foreuse", "qg" }

local function d2(ax, ay, bx, by) local dx, dy = ax - bx, ay - by return dx * dx + dy * dy end

function Pe.role_w(role)
  if role == "qg" then return Pe.HQ_W end
  return Pe.ROLE_W[role] or 0
end

function Pe.cover_r(range) return (range or 0) * Pe.COVER_PCT / 100 end

function Pe.pct(a, b)
  if (b or 0) <= 0 then return 100 end
  return math.floor(100 * a / b + 0.5)
end

---------------------------------------------------------------------------------------------------
-- Mesure
---------------------------------------------------------------------------------------------------
--- points { {x, y, role} }, turrets { {x, y, range, armed} } -> { w, wc, n, nc, cats = { [cat] = { n, c } } } ; `armed_only` : seules
--- les tourelles armées couvrent.
function Pe.coverage(points, turrets, armed_only)
  local out = { w = 0, wc = 0, n = 0, nc = 0, cats = {} }
  for _, c in ipairs(Pe.CATS) do out.cats[c] = { n = 0, c = 0 } end
  for _, p in ipairs(points or {}) do
    local w = Pe.role_w(p.role)
    if w > 0 then
      local cov = false
      for _, t in ipairs(turrets or {}) do
        if t.armed or not armed_only then
          local r = Pe.cover_r(t.range)
          if d2(p.x, p.y, t.x, t.y) <= r * r then cov = true break end
        end
      end
      local cat = out.cats[Pe.CAT[p.role]]
      out.w, out.n, cat.n = out.w + w, out.n + 1, cat.n + 1
      if cov then out.wc, out.nc, cat.c = out.wc + w, out.nc + 1, cat.c + 1 end
    end
  end
  return out
end

--- Tourelles sans autre tourelle à leur portée (isolées).
function Pe.isolated(turrets)
  local n = 0
  for i, t in ipairs(turrets or {}) do
    local r2, alone = (t.range or 0) * (t.range or 0), true
    for j, u in ipairs(turrets) do
      if i ~= j and d2(t.x, t.y, u.x, u.y) <= r2 then alone = false break end
    end
    if alone then n = n + 1 end
  end
  return n
end

---------------------------------------------------------------------------------------------------
-- Cœur et anneaux
---------------------------------------------------------------------------------------------------
--- Boîte du cœur { x0, y0, x1, y1 } (QG compris) et nombre de points reliés au QG de proche en proche (Chebyshev <= link).
function Pe.core_box(points, hq, link)
  link = link or Pe.LINK
  local grid = {}
  local function key(cx, cy) return (cx + 32768) * 65536 + (cy + 32768) end
  for i, p in ipairs(points or {}) do
    local k = key(math.floor(p.x / link), math.floor(p.y / link))
    local g = grid[k]
    if not g then g = {} grid[k] = g end
    g[#g + 1] = i
  end
  local seen, queue = {}, {}
  local function reach(x, y)
    local cx, cy = math.floor(x / link), math.floor(y / link)
    for dx = -1, 1 do
      for dy = -1, 1 do
        for _, i in ipairs(grid[key(cx + dx, cy + dy)] or {}) do
          local p = points[i]
          if not seen[i] and math.abs(p.x - x) <= link and math.abs(p.y - y) <= link then
            seen[i] = true
            queue[#queue + 1] = i
          end
        end
      end
    end
  end
  local box = { x0 = hq.x, y0 = hq.y, x1 = hq.x, y1 = hq.y }
  reach(hq.x, hq.y)
  local head = 1
  while head <= #queue do
    local p = points[queue[head]]
    head = head + 1
    if p.x < box.x0 then box.x0 = p.x end
    if p.y < box.y0 then box.y0 = p.y end
    if p.x > box.x1 then box.x1 = p.x end
    if p.y > box.y1 then box.y1 = p.y end
    reach(p.x, p.y)
  end
  return box, #queue
end

--- Anneau voulu : boîte du cœur élargie de Pe.MARGIN ; `wall` (bornes { x0, y0, x1, y1 } du mur, tuiles du mur incluses) : le mur rentré
--- de Pe.INSET (rend aussi vrai).
function Pe.ring_box(core, wall)
  if wall then
    return { x0 = wall[1] + 1 + Pe.INSET, y0 = wall[2] + 1 + Pe.INSET, x1 = wall[3] - Pe.INSET, y1 = wall[4] - Pe.INSET }, true
  end
  return { x0 = core.x0 - Pe.MARGIN, y0 = core.y0 - Pe.MARGIN, x1 = core.x1 + Pe.MARGIN, y1 = core.y1 + Pe.MARGIN }, false
end

--- Anneaux figés `rings` (liste, modifiée) contre la boîte du cœur `core` et le mur `wall` (ou nil). Rend (quoi, indice) : « mur » (l'anneau 1
--- devient le mur), « nouveau », « remplace » (dernier anneau agrandi, au plus Pe.MAX_RINGS), ou nil (rien ne change).
function Pe.rings_update(rings, core, wall, tick)
  if wall and not (rings[1] and rings[1].wall) then
    local b = Pe.ring_box(core, wall)
    rings[1] = { x0 = b.x0, y0 = b.y0, x1 = b.x1, y1 = b.y1, wall = true, tick = tick }
    return "mur", 1
  end
  local env = Pe.ring_box(core, nil)
  local last = rings[#rings]
  if not last then
    rings[1] = { x0 = env.x0, y0 = env.y0, x1 = env.x1, y1 = env.y1, tick = tick }
    return "nouveau", 1
  end
  local grow = math.max(last.x0 - env.x0, last.y0 - env.y0, env.x1 - last.x1, env.y1 - last.y1)
  if grow < Pe.GROW then return nil end
  local r = { x0 = math.min(env.x0, last.x0), y0 = math.min(env.y0, last.y0), x1 = math.max(env.x1, last.x1),
    y1 = math.max(env.y1, last.y1), tick = tick }
  if #rings < Pe.MAX_RINGS then
    rings[#rings + 1] = r
    return "nouveau", #rings
  end
  rings[#rings] = r
  return "remplace", #rings
end

--- Postes d'un anneau : { x, y, tx, ty (tangente), nx, ny (normale vers l'intérieur), side, corner } ; coins d'abord sur chaque côté
--- (n, e, s, o), un poste tous les au plus Pe.SPACING_MUL × rc.
function Pe.ring_posts(box, rc)
  local step = math.max(8, Pe.SPACING_MUL * rc)
  local x0, y0, x1, y1 = box.x0, box.y0, box.x1, box.y1
  local sides = {
    { ax = x0, ay = y0, bx = x1, by = y0, tx = 1, ty = 0, nx = 0, ny = 1, side = "n" },
    { ax = x1, ay = y0, bx = x1, by = y1, tx = 0, ty = 1, nx = -1, ny = 0, side = "e" },
    { ax = x1, ay = y1, bx = x0, by = y1, tx = -1, ty = 0, nx = 0, ny = -1, side = "s" },
    { ax = x0, ay = y1, bx = x0, by = y0, tx = 0, ty = -1, nx = 1, ny = 0, side = "o" },
  }
  local s2 = math.sqrt(0.5)
  local out = {}
  for i, s in ipairs(sides) do
    local prev = sides[i == 1 and 4 or i - 1]
    local len = math.max(math.abs(s.bx - s.ax), math.abs(s.by - s.ay))
    local k = math.max(1, math.ceil(len / step))
    -- coin (début du côté) : la paire en travers de la diagonale (somme des tangentes), normale = somme des normales
    out[#out + 1] = { x = s.ax, y = s.ay, tx = (s.tx + prev.tx) * s2, ty = (s.ty + prev.ty) * s2,
      nx = (s.nx + prev.nx) * s2, ny = (s.ny + prev.ny) * s2, side = prev.side .. s.side, corner = true }
    for j = 1, k - 1 do
      out[#out + 1] = { x = s.ax + (s.bx - s.ax) * j / k, y = s.ay + (s.by - s.ay) * j / k, tx = s.tx, ty = s.ty, nx = s.nx, ny = s.ny, side = s.side }
    end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Postes « point »
---------------------------------------------------------------------------------------------------
--- Repère d'un poste « point » au centre (x, y) : normale vers le QG, tangente perpendiculaire (la paire en travers de l'arrivée).
function Pe.frame(x, y, hq)
  local dx, dy = hq.x - x, hq.y - y
  local l = math.sqrt(dx * dx + dy * dy)
  if l < 1 then return 1, 0, 0, 1 end
  local nx, ny = dx / l, dy / l
  return -ny, nx, nx, ny
end

--- Nouveaux centres de postes pour les points sensibles non couverts : ni tourelle à rc (`turrets` { {x, y, range} }), ni poste déjà en
--- mémoire à rc - Pe.HALF (`posts`). Glouton sur des cases de Pe.CELL tuiles ; au plus `max` centres { x, y, w }.
function Pe.point_posts(points, turrets, posts, rc, max)
  local out = {}
  if (max or 0) <= 0 or rc <= Pe.HALF then return out end
  local reach = rc - Pe.HALF
  local reach2 = reach * reach
  local by, keys = {}, {}
  for _, p in ipairs(points or {}) do
    local w = Pe.role_w(p.role)
    local cov = w <= 0
    if not cov then
      for _, t in ipairs(turrets or {}) do
        local r = Pe.cover_r(t.range)
        if d2(p.x, p.y, t.x, t.y) <= r * r then cov = true break end
      end
    end
    if not cov then
      for _, q in ipairs(posts or {}) do
        if d2(p.x, p.y, q.x, q.y) <= reach2 then cov = true break end
      end
    end
    if not cov then
      local k = (math.floor(p.x / Pe.CELL) + 32768) * 65536 + (math.floor(p.y / Pe.CELL) + 32768)
      local c = by[k]
      if not c then c = { sx = 0, sy = 0, w = 0, key = k } by[k] = c keys[#keys + 1] = k end
      c.sx, c.sy, c.w = c.sx + p.x * w, c.sy + p.y * w, c.w + w
    end
  end
  table.sort(keys)
  local cells = {}
  for _, k in ipairs(keys) do
    local c = by[k]
    cells[#cells + 1] = { x = c.sx / c.w, y = c.sy / c.w, w = c.w, key = k }
  end
  local near = {}
  for i, a in ipairs(cells) do
    local l = {}
    for j, b in ipairs(cells) do if d2(a.x, a.y, b.x, b.y) <= reach2 then l[#l + 1] = j end end
    near[i] = l
  end
  local done = {}
  while #out < max do
    local bi, bg
    for i in ipairs(cells) do
      local g = 0
      for _, j in ipairs(near[i]) do if not done[j] then g = g + cells[j].w end end
      if g > 0 and (bg == nil or g > bg) then bi, bg = i, g end
    end
    if not bi then break end
    for _, j in ipairs(near[bi]) do done[j] = true end
    out[#out + 1] = { x = cells[bi].x, y = cells[bi].y, w = bg }
  end
  return out
end

--- Poids sensible à moins de rc de (x, y).
function Pe.weight_near(points, x, y, rc)
  local s, r2 = 0, rc * rc
  for _, p in ipairs(points or {}) do
    if d2(p.x, p.y, x, y) <= r2 then s = s + Pe.role_w(p.role) end
  end
  return s
end

---------------------------------------------------------------------------------------------------
-- Relevé : anneaux et postes (état `st` = { rings, posts, next_id })
---------------------------------------------------------------------------------------------------
local function new_post(st, kind, ring, p)
  local id = st.next_id
  st.next_id = id + 1
  local post = { id = id, key = "p" .. id, kind = kind, ring = ring, x = p.x, y = p.y, tx = p.tx, ty = p.ty, nx = p.nx, ny = p.ny,
    side = p.side, w = p.w or 0 }
  st.posts[#st.posts + 1] = post
  return post
end

--- inp = { points, turrets { {x, y, range} }, hq { x, y }, wall (bornes ou nil), range, tick } -> événements { { what, ring, box, n } } et
--- { new = postes « point » créés, dropped = postes « point » retirés }. Rien sous Pe.MIN_POINTS points du cœur.
function Pe.update(st, inp)
  st.rings, st.posts, st.next_id = st.rings or {}, st.posts or {}, st.next_id or 1
  local ev, info = {}, { new = 0, dropped = 0, core = 0 }
  local rc = Pe.cover_r(inp.range)
  if rc <= Pe.HALF then return ev, info end
  local core, ncore = Pe.core_box(inp.points, inp.hq)
  info.core = ncore
  if ncore < Pe.MIN_POINTS then return ev, info end
  local what, idx = Pe.rings_update(st.rings, core, inp.wall, inp.tick)
  if what then
    local kept = {}
    for _, p in ipairs(st.posts) do
      if not (p.kind == "ring" and p.ring == idx) then kept[#kept + 1] = p end
    end
    st.posts = kept
    local list = Pe.ring_posts(st.rings[idx], rc)
    for _, p in ipairs(list) do new_post(st, "ring", idx, p) end
    local r = st.rings[idx]
    ev[#ev + 1] = { what = what, ring = idx, box = { r.x0, r.y0, r.x1, r.y1 }, n = #list }
  end
  -- postes « point » : ceux sans point sensible à rc sont retirés, les autres gardent leur place (le groupe entamé est complété)
  local kept, points_posts = {}, {}
  for _, p in ipairs(st.posts) do
    p.w = Pe.weight_near(inp.points, p.x, p.y, rc)
    if p.kind == "point" and p.w <= 0 then
      info.dropped = info.dropped + 1
    else
      kept[#kept + 1] = p
      if p.kind == "point" then points_posts[#points_posts + 1] = p end
    end
  end
  st.posts = kept
  for _, c in ipairs(Pe.point_posts(inp.points, inp.turrets, points_posts, rc, Pe.MAX_POSTS - #points_posts)) do
    local tx, ty, nx, ny = Pe.frame(c.x, c.y, inp.hq)
    new_post(st, "point", nil, { x = c.x, y = c.y, tx = tx, ty = ty, nx = nx, ny = ny, w = Pe.weight_near(inp.points, c.x, c.y, rc) })
    info.new = info.new + 1
  end
  return ev, info
end

---------------------------------------------------------------------------------------------------
-- Choix du poste à servir
---------------------------------------------------------------------------------------------------
local function count_near(list, x, y, r)
  local n, r2 = 0, r * r
  for _, t in ipairs(list or {}) do if d2(t.x, t.y, x, y) <= r2 then n = n + 1 end end
  return n
end

local function threat_near(list, x, y)
  local s, r2 = 0, Pe.THREAT_R * Pe.THREAT_R
  for _, t in ipairs(list or {}) do if d2(t.x, t.y, x, y) <= r2 then s = s + (t.w or 0) end end
  return s
end

--- spec = { posts, turrets { {x, y} }, threats { {x, y, w} }, rest = { [clé] = vrai }, allow = function(post) -> bool (facultatif) }
--- -> { pick = { key, kind, ring, x, y, have, want, threat } ou nil, rows (ordre de service), served, total }
function Pe.plan(spec)
  local rows = {}
  for _, p in ipairs(spec.posts or {}) do
    local th = threat_near(spec.threats, p.x, p.y)
    rows[#rows + 1] = { post = p, have = count_near(spec.turrets, p.x, p.y, Pe.HAVE_R), want = th > 0 and Pe.GROUP_THREAT or Pe.GROUP, threat = th }
  end
  table.sort(rows, function(a, b)
    local pa, pb = a.post, b.post
    if (pa.kind == "point") ~= (pb.kind == "point") then return pa.kind == "point" end
    if (pa.ring or 0) ~= (pb.ring or 0) then return (pa.ring or 0) < (pb.ring or 0) end
    if a.threat ~= b.threat then return a.threat > b.threat end
    if (pa.w or 0) ~= (pb.w or 0) then return (pa.w or 0) > (pb.w or 0) end
    return pa.id < pb.id
  end)
  local out = { rows = rows, served = 0, total = #rows }
  for _, r in ipairs(rows) do
    if r.have >= r.want then
      out.served = out.served + 1
    elseif not out.pick then
      if spec.rest and spec.rest[r.post.key] then
        r.skip = "repos"
      elseif spec.allow and not spec.allow(r.post) then
        r.skip = "ennemi"
      else
        local p = r.post
        out.pick = { key = p.key, kind = p.kind, ring = p.ring, x = p.x, y = p.y, have = r.have, want = r.want, threat = r.threat }
      end
    end
  end
  return out
end

--- Emplacements d'un poste, dans l'ordre : la paire en travers (± Pe.HALF sur la tangente), puis en arrière et en avant (2 × Pe.HALF sur la
--- normale), puis le centre.
function Pe.sites(post)
  local h, x, y = Pe.HALF, post.x, post.y
  local tx, ty, nx, ny = post.tx or 1, post.ty or 0, post.nx or 0, post.ny or 1
  return {
    { x = x + h * tx, y = y + h * ty }, { x = x - h * tx, y = y - h * ty },
    { x = x + 2 * h * nx, y = y + 2 * h * ny }, { x = x - 2 * h * nx, y = y - 2 * h * ny }, { x = x, y = y },
  }
end

--- Une pose en (x, y) appartient-elle au poste ? (à moins de Pe.ACCEPT tuiles de son centre)
function Pe.accepts(post, x, y) return d2(post.x, post.y, x, y) <= Pe.ACCEPT * Pe.ACCEPT end

--- Repos d'un poste après `zero` poses nulles de suite (ticks).
function Pe.rest_ticks(zero) return Pe.REST * math.min(math.max(zero or 1, 1), Pe.REST_MAX) end

--- Budget : s = { iron, floor, unit (fer d'une tourelle armée), pct, held (tourelles du périmètre vivantes), want, free (fer libre hors besoin,
--- facultatif) } -> tourelles commandables maintenant (0 à want). Les tourelles du périmètre n'immobilisent jamais plus de Pe.FREE_PCT % du fer
--- libre hors besoin (`free` donné), sinon de Pe.BUDGET_PCT % du fer au-dessus du plancher ; rien sous Pe.RICH_IRON de fer au stock.
function Pe.allowed(s)
  local unit = s.unit or 0
  local surplus, pct = (s.iron or 0) - (s.floor or 0), s.pct or Pe.BUDGET_PCT
  if s.free ~= nil then surplus, pct = s.free, s.pct or Pe.FREE_PCT end
  if unit <= 0 or surplus <= 0 or (s.iron or 0) < (s.rich or Pe.RICH_IRON) then return 0 end
  local a = math.floor(pct * surplus / (100 * unit)) - (s.held or 0)
  if a <= 0 then return 0 end
  return math.min(a, math.max(0, s.want or 0))
end

return Pe
