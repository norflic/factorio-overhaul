--[[
  Lot ENERGIE (2/11), santé du RÉSEAU : coupure d'une ligne de poteaux (Scarlet, journal du DC 0.6.34 : 40 poteaux perdus, ennemis à moins
  de 28 tuiles, centrale intacte mais « 147 consommateurs sur un îlot », 4 941 kW à 102 min, 323 kW à 122 min). PUR : aucune API du jeu,
  aucun nom d'objet ; testé hors jeu par tests/coupure_reseau_test.lua (mutants compris).

  Avant ce lot, script/team/reseau_vivant.lua rouvrait TOUS les poteaux perdus qu'aucun ennemi ne tient (28 tuiles), dans un ordre sans
  rapport avec la ligne, et ne faisait rien des poteaux tenus par un ennemi : l'îlot restait coupé jusqu'au plafond de réouvertures
  (Rv.POLE_REOPEN_MAX) ; script/team/raccord.lua, lui, « laissait la main » à reseau_vivant tant qu'un poteau perdu était à portée.

  DEUX DÉCISIONS (une seule fonction, K.plan) :
    1. CHEMIN LE PLUS COURT. Graphe de poteaux : sources = poteaux VIVANTS d'un réseau alimenté, cibles = poteaux VIVANTS d'un îlot qui porte
       des consommateurs, nœuds intermédiaires = poteaux PERDUS (à reposer). Une arête relie deux poteaux à portée de fil l'un de l'autre
       (la plus petite des deux portées). Coût d'un chemin = (nombre de poteaux perdus à reposer) x W + longueur de fil : moins de poteaux
       d'abord, puis le fil le plus court (même codage que shared/team/poteaux.lua). Un poteau perdu à moins de enemy_r d'un ennemi est
       INTERDIT (jamais de pose sous le feu). Rend les poteaux à reposer dans l'ordre DU CÔTÉ ALIMENTÉ VERS L'ÎLOT, îlots les plus proches
       d'abord, sans doublon : chaque poteau posé raccorde tout de suite au réseau alimenté.
    2. SECOND CHEMIN. Un îlot sans chemin sûr (la ligne passe près d'ennemis, ou les poteaux perdus ne suffisent pas à le joindre) est signalé
       dans `second` : le raccordement par recherche de chemin (script/team/raccord.lua) bâtit alors une chaîne NEUVE qui contourne les
       ennemis (`avoid`, K.avoid_zone). `second.recoverable` dit si un chemin existait en ignorant les ennemis (la ligne est sûre dès que
       l'ennemi part) ou non.
  Déterminisme : listes triées (y, x, numéro), aucune trigonométrie (racine carrée seulement), aucun `pairs`, aucune horloge.
]]

local K = {}

K.ENEMY_R = 28         -- tuiles : jamais de pose d'un poteau avec un ennemi à cette portée (= Rv.POLE_ENEMY_R)
K.AVOID_R = 40         -- tuiles : rayon de la zone qu'une chaîne NEUVE évite = le rayon de danger des poseurs (shared/ai3/danger.lua : portée 30 d'un ver ou
                       -- d'un nid + D.MARGIN 10) ; à 28 la chaîne était planifiée mais les PNJ refusaient de la bâtir (« danger », 14 min, banc energie-ilot-ennemi)
K.EXEMPT_R = 0         -- tuiles autour des bouts où la zone ne vaut pas : AUCUNE (un poteau posé dans la zone ne serait jamais bâti, le projet resterait
                       -- ouvert pour toujours) ; une chaîne qui ne peut pas sortir de la zone est refusée, honnêtement ("aucune chaine")
K.W = 1e6              -- poids d'un poteau perdu à reposer devant la longueur de fil
K.MAX_NODES = 600      -- nœuds au plus par décision (au-delà : les plus proches de la zone perdue, voir K.trim)
K.EDGE_SLACK = 1e-9

local sqrt = math.sqrt

local function dist(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return sqrt(dx * dx + dy * dy)
end

--- Un poteau est-il tenu par un ennemi ? (ennemis = { { x, y } })
function K.held(p, enemies, r)
  r = r or K.ENEMY_R
  for _, e in ipairs(enemies or {}) do
    local dx, dy = p.x - e.x, p.y - e.y
    if dx * dx + dy * dy <= r * r then return true end
  end
  return false
end

--- Zone à éviter pour une chaîne neuve : les ennemis, avec leur rayon. Rend au plus `max` ennemis (les plus proches de `near`, puis y, x).
function K.avoid_zone(enemies, near, max, r)
  local out = {}
  for _, e in ipairs(enemies or {}) do out[#out + 1] = { x = e.x, y = e.y, r = r or K.AVOID_R } end
  table.sort(out, function(a, b)
    local da = near and dist(a, near) or 0
    local db = near and dist(b, near) or 0
    if da ~= db then return da < db end
    if a.y ~= b.y then return a.y < b.y end
    return a.x < b.x
  end)
  while #out > (max or 6) do table.remove(out) end
  return out
end

--- Une position est-elle dans la zone à éviter ? Les bouts de la chaîne (rayon `exempt` autour de chacun) restent permis : une chaîne doit
--- pouvoir sortir de la zone qui tient son point de départ.
function K.in_zone(x, y, zone, exempt_pts, exempt_r)
  -- l'exemption ne vaut que pour un bout QUI EST DANS la zone (de plus d'une demi-tuile) : un bout au bord (28,0 tuiles de l'ennemi) n'exempte rien,
  -- sinon les premiers poteaux de la chaîne seraient posés à portée du ver (mesuré au banc energie-ilot-ennemi : 24 tuiles d'un ver de portée 25)
  for _, p in ipairs(exempt_pts or {}) do
    local inside = false
    for _, z in ipairs(zone or {}) do
      local ex, ey = p.x - z.x, p.y - z.y
      if ex * ex + ey * ey < (z.r - 0.5) * (z.r - 0.5) then inside = true end
    end
    local dx, dy = x - p.x, y - p.y
    if inside and dx * dx + dy * dy <= (exempt_r or 0) * (exempt_r or 0) then return false end
  end
  for _, z in ipairs(zone or {}) do
    local dx, dy = x - z.x, y - z.y
    if dx * dx + dy * dy <= z.r * z.r then return true end
  end
  return false
end

local KINDS = { live = true, isl = true, lost = true }

local function sort_nodes(nodes)
  table.sort(nodes, function(a, b)
    if a.y ~= b.y then return a.y < b.y end
    if a.x ~= b.x then return a.x < b.x end
    return (a.id or 0) < (b.id or 0)
  end)
end

-- Tas binaire (min) : { c = coût, k = numéro de nœud }, départage par le numéro (déterminisme).
local function lt(a, b) return a.c < b.c or (a.c == b.c and a.k < b.k) end
local function hpush(h, n)
  h[#h + 1] = n
  local i = #h
  while i > 1 do
    local p = math.floor(i / 2)
    if lt(h[p], h[i]) then break end
    h[p], h[i] = h[i], h[p]
    i = p
  end
end
local function hpop(h)
  local top = h[1]
  local last = table.remove(h)
  if #h > 0 then
    h[1] = last
    local i = 1
    while true do
      local l, r, m = i * 2, i * 2 + 1, i
      if l <= #h and lt(h[l], h[m]) then m = l end
      if r <= #h and lt(h[r], h[m]) then m = r end
      if m == i then break end
      h[m], h[i] = h[i], h[m]
      i = m
    end
  end
  return top
end

--- Recherche du plus court chemin depuis TOUTES les sources. `allow_held` : les poteaux tenus par un ennemi sont-ils permis ?
--- Rend { cost = {}, prev = {} } indexés par numéro de nœud (liste triée).
local function search(nodes, held, allow_held)
  local n = #nodes
  local cost, prev, done = {}, {}, {}
  local heap = {}
  for i = 1, n do
    if nodes[i].kind == "live" then cost[i] = 0; hpush(heap, { c = 0, k = i }) end
  end
  while #heap > 0 do
    local cur = hpop(heap)
    local u = cur.k
    if not done[u] and cost[u] == cur.c then
      done[u] = true
      local nu = nodes[u]
      if nu.kind ~= "isl" then -- on ne traverse pas un îlot : on y arrive
        for v = 1, n do
          local nv = nodes[v]
          if not done[v] and nv.kind ~= "live" and (allow_held or not held[v]) then
            local d = dist(nu, nv)
            local reach = math.min(nu.reach or 9, nv.reach or 9)
            if d <= reach + K.EDGE_SLACK then
              local c = cur.c + d + (nv.kind == "lost" and K.W or 0)
              if cost[v] == nil or c < cost[v] then
                cost[v], prev[v] = c, u
                hpush(heap, { c = c, k = v })
              end
            end
          end
        end
      end
    end
  end
  return { cost = cost, prev = prev }
end

--- inp = { poles = { { id, x, y, reach, kind = "live" | "isl" | "lost", net = n° de réseau de l'îlot (isl) } }, enemies = { { x, y } },
---         enemy_r = 28 }
--- Rend { action, order = { id des poteaux perdus à reposer, côté alimenté d'abord }, second = { { net, recoverable } }, held = n poteaux perdus
--- tenus, paths = { { net, lost = n poteaux perdus sur le chemin, len = longueur de fil } }, reason }.
--- action : "rien" (aucun îlot ou aucun poteau vivant côté alimenté), "chemin" (au moins un chemin sûr), "second" (aucun chemin sûr mais au
--- moins un îlot à joindre par une chaîne neuve), "repli" (rien à dire du graphe : l'appelant garde sa règle d'avant).
function K.plan(inp)
  local nodes = {}
  for _, p in ipairs(inp.poles or {}) do
    if KINDS[p.kind] and p.x and p.y then nodes[#nodes + 1] = p end
  end
  sort_nodes(nodes)
  local out = { action = "rien", order = {}, second = {}, held = 0, paths = {}, reason = "" }
  local n_live, n_isl, n_lost = 0, 0, 0
  for _, p in ipairs(nodes) do
    if p.kind == "live" then n_live = n_live + 1 elseif p.kind == "isl" then n_isl = n_isl + 1 else n_lost = n_lost + 1 end
  end
  if n_isl == 0 then out.reason = "aucun ilot avec des consommateurs" return out end
  if n_live == 0 then out.action = "repli" out.reason = "aucun poteau vivant d'un reseau alimente a portee" return out end
  if #nodes > K.MAX_NODES then out.action = "repli" out.reason = "trop de poteaux a lire" return out end
  local r = inp.enemy_r or K.ENEMY_R
  local held = {}
  for i, p in ipairs(nodes) do
    if p.kind == "lost" and K.held(p, inp.enemies, r) then held[i] = true; out.held = out.held + 1 end
  end
  local safe = search(nodes, held, false)
  local free = out.held > 0 and search(nodes, held, true) or safe
  -- îlots : pour chacun, le poteau d'arrivée le moins cher ; numéros de réseau triés
  local nets, best = {}, {}
  for i, p in ipairs(nodes) do
    if p.kind == "isl" then
      local net = p.net or 0
      if best[net] == nil then nets[#nets + 1] = net; best[net] = { safe = nil, free = nil } end
      local b = best[net]
      if safe.cost[i] and (not b.safe or safe.cost[i] < safe.cost[b.safe]) then b.safe = i end
      if free.cost[i] and (not b.free or free.cost[i] < free.cost[b.free]) then b.free = i end
    end
  end
  table.sort(nets)
  local rows = {}
  for _, net in ipairs(nets) do
    local b = best[net]
    if b.safe then
      rows[#rows + 1] = { net = net, i = b.safe, c = safe.cost[b.safe] }
    else
      out.second[#out.second + 1] = { net = net, recoverable = b.free ~= nil }
    end
  end
  table.sort(rows, function(a, b) if a.c ~= b.c then return a.c < b.c end return a.net < b.net end)
  local seen = {}
  for _, row in ipairs(rows) do
    local chain, k = {}, row.i
    while k do
      if nodes[k].kind == "lost" then chain[#chain + 1] = k end
      k = safe.prev[k]
    end
    for j = #chain, 1, -1 do -- du côté alimenté vers l'îlot
      local id = nodes[chain[j]].id
      if not seen[id] then seen[id] = true; out.order[#out.order + 1] = id end
    end
    out.paths[#out.paths + 1] = { net = row.net, lost = #chain, len = row.c - #chain * K.W }
  end
  if #out.order == 0 and #rows > 0 then
    -- des îlots à portée de fil d'un poteau vivant sans poteau perdu à reposer : un fil, pas un poteau (raccordement, ou règle d'avant)
    out.action = "repli"
    out.reason = string.format("%d ilot(s) a portee de fil d'un poteau vivant, aucun poteau perdu a reposer", #rows)
  elseif #out.order > 0 then
    out.action = "chemin"
    out.reason = string.format("%d poteau(x) a reposer sur le chemin le plus court (%d ilot(s) joint(s), %d sans chemin sur)", #out.order, #rows, #out.second)
  elseif #out.second > 0 then
    out.action = "second"
    out.reason = string.format("%d ilot(s) sans chemin sur (%d poteau(x) perdu(s) tenu(s) par un ennemi)", #out.second, out.held)
  end
  return out
end

--- Ne garde que `max` nœuds : tous les perdus, puis les vivants/îlots les plus proches du centre des perdus (x, y, id pour départager).
function K.trim(poles, max)
  max = max or K.MAX_NODES
  if #poles <= max then return poles end
  local sx, sy, n = 0, 0, 0
  for _, p in ipairs(poles) do if p.kind == "lost" then sx, sy, n = sx + p.x, sy + p.y, n + 1 end end
  local c = n > 0 and { x = sx / n, y = sy / n } or { x = 0, y = 0 }
  local lost, other = {}, {}
  for _, p in ipairs(poles) do if p.kind == "lost" then lost[#lost + 1] = p else other[#other + 1] = p end end
  table.sort(other, function(a, b)
    local da, db = dist(a, c), dist(b, c)
    if da ~= db then return da < db end
    if a.y ~= b.y then return a.y < b.y end
    if a.x ~= b.x then return a.x < b.x end
    return (a.id or 0) < (b.id or 0)
  end)
  local out = {}
  for _, p in ipairs(lost) do if #out < max then out[#out + 1] = p end end
  for _, p in ipairs(other) do if #out < max then out[#out + 1] = p end end
  return out
end

return K
