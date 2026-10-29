--[[
  PLAN DIRECTEUR des équipes de PNJ (lot IA1-d, docs/EQUIPES_PNJ.md §6.5 à §6.8 ; IA_ADAPTATIVE §B4). Lua PUR : aucune
  API du jeu ; lu hors jeu (tests/plan_test.lua) et en jeu (script/team/build.lua, qui fait les relevés du moteur).

  TREILLIS : un seul treillis par équipe, ancré au QG : lots de 24 × 24 séparés par des rues de 4 (pas de 28). Le lot
  (0, 0) contient le QG. Le carrefour (i, j) est le croisement au sud-est du lot (i, j). Un TRONÇON de rue relie deux
  carrefours voisins (« h:i:j » de (i, j) à (i + 1, j), « v:i:j » de (i, j) à (i, j + 1)) ; son rectangle comprend ses
  deux croisements.
  QUARTIERS (§B4, « quartiers, pas couronnes ») : la 1re couronne du QG est le CŒUR ; ailleurs, un lot sert la fonction
  du site qui le porte (gisement : extraction et fonderie ; rive : énergie) et un module va dans le lot libre qui
  minimise la distance à ses entrées et à ses consommateurs. Écart déclaré à §B4 : les quartiers partagent le treillis
  du QG (leurs rues se raccordent par construction) au lieu d'une grille tournée par site ; l'orientation se fait par
  quart de tour du gabarit (rotation alignée sur le grand axe du gisement, M.rotate).

  Ce fichier calcule : classement des lots et des tronçons depuis un relevé, chemin par les rues (parcours sur les
  carrefours ouverts), placement d'un gabarit dans un lot (foreuses sur le minerai, place des têtes d'alimentation),
  têtes d'alimentation (chargement latéral, quai), quais de sortie, tapis entre modules (A* borné), chaînes de poteaux,
  points d'appui (dans les rues, à 16 tuiles au plus), ordre de pose, contrôle des chevauchements.

  Déterminisme : listes triées, aucun `pairs` non trié, aucune trigonométrie ; égalités départagées par les
  coordonnées. Coordonnées : tuiles entières (coin nord-ouest) ; une entité porte son CENTRE (x, y).
]]

local function need(dotted, slashed)
  local ok, res = pcall(require, dotted)
  if ok and type(res) == "table" then return res end
  return require("__factorio-overhaul__/" .. slashed)
end
local M = need("shared.team.modules", "shared/team/modules")

local P = {}

P.LOT = 24
P.STREET = 4
P.PITCH = 28
P.HALF = 12
P.BUILD_DISTANCE = 16       -- O.SCRIPT_BUILD_DISTANCE
P.ANCHOR_STEP = 8           -- points d'appui tous les 8 tuiles le long d'une rue
P.MIN_RES_TILES = 24        -- un lot « gisement » porte au moins 24 tuiles d'une ressource
P.WATER_REFUSE = 0.5        -- part d'eau au-delà de laquelle un lot est refusé
P.DRILL_COVER = 0.6         -- part des tuiles minées par les foreuses qui doit porter le minerai
P.FEED_DEPTH = 3            -- profondeur d'une tête d'alimentation derrière un port d'entrée
P.AUTO_FLOW = 1.0           -- objets/s : au-delà, une voie est servie par tapis (règle d'automatisation, 60/min)
P.PLANT_WET = 0.2           -- part d'eau du gabarit d'eau de la centrale (lot IA3-e ; 0,6 avant)
P.STREET_COST = 3           -- coût d'une tuile de rue pour un tapis (traverser oui, longer non)
P.ASTAR_MAX = 6000          -- nœuds développés au plus par tracé

P.N, P.E, P.S, P.W = 0, 2, 4, 6
local DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }
P.DV = DV
local function dir_of(dx, dy)
  if dx == 0 and dy == -1 then return 0 end
  if dx == 1 and dy == 0 then return 2 end
  if dx == 0 and dy == 1 then return 4 end
  if dx == -1 and dy == 0 then return 6 end
  return nil
end
P.dir_of = dir_of
local function left_of(d) local v = DV[d]; return v[2], -v[1] end
P.left_of = left_of

local function floor(x) return math.floor(x) end
local function round(x) return math.floor(x + 0.5) end
local function tkey(x, y) return (x + 1048576) * 2097152 + (y + 1048576) end
P.tkey = tkey

---------------------------------------------------------------------------------------------------
-- 1. Treillis
---------------------------------------------------------------------------------------------------
--- Treillis ancré au QG (position du coffre ou du centre).
function P.lattice(hq) return { ox = floor(hq.x), oy = floor(hq.y) } end

--- Rectangle d'un lot : x0, y0 inclus, x1, y1 exclus (tuiles).
function P.lot_rect(lat, i, j)
  local x0, y0 = lat.ox + P.PITCH * i - P.HALF, lat.oy + P.PITCH * j - P.HALF
  return x0, y0, x0 + P.LOT, y0 + P.LOT
end

function P.lot_key(i, j) return i .. ":" .. j end

--- Centre du carrefour (i, j).
function P.node_pos(lat, i, j)
  return { x = lat.ox + P.PITCH * i + P.HALF + 2, y = lat.oy + P.PITCH * j + P.HALF + 2 }
end

--- Lot (i, j) qui contient la position, ou nil si elle est dans une rue.
function P.lot_of(lat, x, y)
  local i = floor((x - lat.ox + P.HALF) / P.PITCH)
  local j = floor((y - lat.oy + P.HALF) / P.PITCH)
  local x0, y0, x1, y1 = P.lot_rect(lat, i, j)
  if x >= x0 and x < x1 and y >= y0 and y < y1 then return i, j end
  return nil
end

--- Tuile dans une rue (croisements compris) ?
function P.in_street(lat, tx, ty)
  local rx = (tx - lat.ox + P.HALF) % P.PITCH
  local ry = (ty - lat.oy + P.HALF) % P.PITCH
  return rx >= P.LOT or ry >= P.LOT
end

--- Clé d'un tronçon : "h:i:j" ((i,j) → (i+1,j)) ou "v:i:j" ((i,j) → (i,j+1)).
function P.seg_key(kind, i, j) return kind .. ":" .. i .. ":" .. j end

function P.parse_seg(key)
  local kind, i, j = key:match("^([hv]):(%-?%d+):(%-?%d+)$")
  return kind, tonumber(i), tonumber(j)
end

--- Rectangle d'un tronçon (croisements compris) : x0, y0 inclus, x1, y1 exclus.
function P.seg_rect(lat, key)
  local kind, i, j = P.parse_seg(key)
  local n = P.node_pos(lat, i, j)
  if kind == "h" then return n.x - 2, n.y - 2, n.x + P.PITCH + 2, n.y + 2 end
  return n.x - 2, n.y - 2, n.x + 2, n.y + P.PITCH + 2
end

--- Tronçons qui bordent le lot (i, j) : nord, sud, ouest, est.
function P.lot_sides(i, j)
  return { P.seg_key("h", i - 1, j - 1), P.seg_key("h", i - 1, j), P.seg_key("v", i - 1, j - 1), P.seg_key("v", i, j - 1) }
end

--- Lots d'un carré de rayon r autour du lot (0, 0), du plus proche au plus loin (puis j, puis i).
function P.lots_within(r)
  local out = {}
  for j = -r, r do for i = -r, r do out[#out + 1] = { i = i, j = j, d = math.max(math.abs(i), math.abs(j)) } end end
  table.sort(out, function(a, b)
    if a.d ~= b.d then return a.d < b.d end
    local da, db = a.i * a.i + a.j * a.j, b.i * b.i + b.j * b.j
    if da ~= db then return da < db end
    if a.j ~= b.j then return a.j < b.j end
    return a.i < b.i
  end)
  return out
end

--- Tronçons d'un carré de carrefours de rayon r (ordre fixe : h puis v, j puis i).
function P.segs_within(r)
  local out = {}
  for j = -r - 1, r do for i = -r - 1, r - 1 do out[#out + 1] = P.seg_key("h", i, j) end end
  for j = -r - 1, r - 1 do for i = -r - 1, r do out[#out + 1] = P.seg_key("v", i, j) end end
  return out
end

---------------------------------------------------------------------------------------------------
-- 2. Classement d'un relevé (3 à 5 appels du moteur, faits par script/team/build.lua)
---------------------------------------------------------------------------------------------------
-- Relevé : { tiles, water, cliffs, trees, rocks, foreign, own, res = { [ressource] = tuiles }, nests }

--- Ressource majoritaire d'un relevé (nom, tuiles), départagée par le nom.
function P.main_resource(s)
  local best, n = nil, 0
  local names = {}
  for k in pairs(s.res or {}) do names[#names + 1] = k end
  table.sort(names)
  for _, k in ipairs(names) do if s.res[k] > n then best, n = k, s.res[k] end end
  return best, n
end

--- État d'un lot : libre, defricher, gisement, rive, occupe, refuse ; raison (refus) ou ressource (gisement).
function P.classify_lot(s)
  if (s.nests or 0) > 0 then return "refuse", "nid" end
  if (s.cliffs or 0) > 0 then return "refuse", "falaise" end
  if (s.foreign or 0) > 0 then return "refuse", "conteste" end
  if (s.water or 0) >= (s.tiles or P.LOT * P.LOT) * P.WATER_REFUSE then return "refuse", "eau" end
  if (s.own or 0) > 0 then return "occupe", "batiments" end
  if (s.water or 0) > 0 then return "rive", nil end
  local r, n = P.main_resource(s)
  if r and n >= P.MIN_RES_TILES then return "gisement", r end
  if (s.trees or 0) + (s.rocks or 0) > 0 then return "defricher", nil end
  return "libre", nil
end

--- État d'un tronçon : ouvert, encombre (arbres, rochers : défrichage), ferme (raison).
function P.classify_segment(s)
  if (s.water or 0) > 0 then return "ferme", "eau" end
  if (s.cliffs or 0) > 0 then return "ferme", "falaise" end
  if (s.nests or 0) > 0 then return "ferme", "nid" end
  if (s.foreign or 0) > 0 then return "ferme", "conteste" end
  if (s.own or 0) > 0 then return "ferme", "batiments" end
  if (s.trees or 0) + (s.rocks or 0) > 0 then return "encombre", nil end
  return "ouvert", nil
end

---------------------------------------------------------------------------------------------------
-- 3. Marche par les rues
---------------------------------------------------------------------------------------------------
--- Voisins d'un carrefour par les tronçons praticables (`ok(key)`), ordre fixe E, S, O, N.
local function neighbours(i, j, ok)
  local out = {}
  local cand = {
    { i + 1, j, P.seg_key("h", i, j) }, { i, j + 1, P.seg_key("v", i, j) },
    { i - 1, j, P.seg_key("h", i - 1, j) }, { i, j - 1, P.seg_key("v", i, j - 1) },
  }
  for _, c in ipairs(cand) do if ok(c[3]) then out[#out + 1] = c end end
  return out
end

--- Parcours en largeur de carrefour à carrefour (tronçons praticables) dans un carré de rayon `r` ; liste de
--- carrefours { i, j } de a à b, ou nil.
function P.route_nodes(a, b, ok, r)
  local start, goal = P.lot_key(a.i, a.j), P.lot_key(b.i, b.j)
  if start == goal then return { { i = a.i, j = a.j } } end
  local prev = { [start] = false }
  local queue, head = { { a.i, a.j } }, 1
  while head <= #queue do
    local cur = queue[head]
    head = head + 1
    for _, nb in ipairs(neighbours(cur[1], cur[2], ok)) do
      local k = P.lot_key(nb[1], nb[2])
      if prev[k] == nil and math.abs(nb[1]) <= r + 1 and math.abs(nb[2]) <= r + 1 then
        prev[k] = P.lot_key(cur[1], cur[2])
        if k == goal then
          local path = {}
          local x = k
          while x do
            local i, j = x:match("^(%-?%d+):(%-?%d+)$")
            table.insert(path, 1, { i = tonumber(i), j = tonumber(j) })
            x = prev[x] or nil
          end
          return path
        end
        queue[#queue + 1] = { nb[1], nb[2] }
      end
    end
  end
  return nil
end

--- Arbre du parcours en largeur depuis le carrefour a (mêmes règles et même ordre que P.route_nodes : le chemin lu
--- dans l'arbre vers b est celui que rend P.route_nodes(a, b)). Rend { [clé] = clé du parent | false }.
function P.route_tree(a, ok, r)
  local start = P.lot_key(a.i, a.j)
  local prev = { [start] = false }
  local queue, head = { { a.i, a.j } }, 1
  while head <= #queue do
    local cur = queue[head]
    head = head + 1
    local ck = P.lot_key(cur[1], cur[2])
    for _, nb in ipairs(neighbours(cur[1], cur[2], ok)) do
      local k = P.lot_key(nb[1], nb[2])
      if prev[k] == nil and math.abs(nb[1]) <= r + 1 and math.abs(nb[2]) <= r + 1 then
        prev[k] = ck
        queue[#queue + 1] = { nb[1], nb[2] }
      end
    end
  end
  return prev
end

--- Chemin lu dans un arbre de P.route_tree jusqu'au carrefour b, ou nil.
function P.tree_path(prev, b)
  local k = P.lot_key(b.i, b.j)
  if prev[k] == nil then return nil end
  local path = {}
  local x = k
  while x do
    local i, j = x:match("^(%-?%d+):(%-?%d+)$")
    table.insert(path, 1, { i = tonumber(i), j = tonumber(j) })
    x = prev[x] or nil
  end
  return path
end

--- Accès d'une position à la rue : point de la ligne médiane la plus proche (horizontale ou verticale) et les deux
--- carrefours du tronçon qui le porte. Rend une liste de 2 accès { point, seg, nodes = { a, b } }, le plus proche d'abord.
function P.street_access(lat, p)
  local out = {}
  -- rue horizontale la plus proche
  local j = round((p.y - lat.oy - P.HALF - 2) / P.PITCH)
  local yc = lat.oy + P.PITCH * j + P.HALF + 2
  local i = floor((p.x - lat.ox - P.HALF - 2) / P.PITCH)
  out[#out + 1] = { point = { x = p.x, y = yc }, d = math.abs(p.y - yc), seg = P.seg_key("h", i, j),
    nodes = { { i = i, j = j }, { i = i + 1, j = j } } }
  local i2 = round((p.x - lat.ox - P.HALF - 2) / P.PITCH)
  local xc = lat.ox + P.PITCH * i2 + P.HALF + 2
  local j2 = floor((p.y - lat.oy - P.HALF - 2) / P.PITCH)
  out[#out + 1] = { point = { x = xc, y = p.y }, d = math.abs(p.x - xc), seg = P.seg_key("v", i2, j2),
    nodes = { { i = i2, j = j2 }, { i = i2, j = j2 + 1 } } }
  table.sort(out, function(a, b) if a.d ~= b.d then return a.d < b.d end return a.seg < b.seg end)
  return out
end

--- Chemin par les rues de p à q (waypoints {x, y}) : accès à la rue, carrefours, accès à q. `ok(seg)` : tronçon
--- praticable SANS pathfinder (ouvert). nil si aucun chemin (le PNJ prend alors le pathfinder). `cache` (facultatif) :
--- table des arbres de parcours par carrefour de départ, valable tant que les tronçons ne changent pas (27/10 : un
--- parcours par départ au lieu de 16 par marche ; même résultat que P.route_nodes).
function P.street_path(lat, p, q, ok, r, cache)
  local best
  cache = cache or {}
  for _, a in ipairs(P.street_access(lat, p)) do
    if ok(a.seg) then
      for _, b in ipairs(P.street_access(lat, q)) do
        if ok(b.seg) then
          for _, na in ipairs(a.nodes) do
            local tk = P.lot_key(na.i, na.j)
            local tree = cache[tk]
            if not tree then tree = P.route_tree(na, ok, r); cache[tk] = tree end
            for _, nb in ipairs(b.nodes) do
              local nodes = P.tree_path(tree, nb)
              if nodes then
                local na_p, nb_p = P.node_pos(lat, na.i, na.j), P.node_pos(lat, nb.i, nb.j)
                local len = a.d + math.abs(a.point.x - na_p.x) + math.abs(a.point.y - na_p.y) + (#nodes - 1) * P.PITCH
                  + math.abs(b.point.x - nb_p.x) + math.abs(b.point.y - nb_p.y) + b.d
                -- même tronçon : directement le long de la rue
                if a.seg == b.seg then len = a.d + math.abs(a.point.x - b.point.x) + math.abs(a.point.y - b.point.y) + b.d end
                if not best or len < best.len - 1e-9 then best = { len = len, a = a, b = b, nodes = nodes, same = a.seg == b.seg } end
              end
            end
          end
        end
      end
    end
  end
  if not best then return nil end
  local wp = {}
  local function add(x, y)
    local last = wp[#wp]
    if not last or math.abs(last.x - x) + math.abs(last.y - y) > 0.25 then wp[#wp + 1] = { x = x, y = y } end
  end
  add(best.a.point.x, best.a.point.y)
  if not best.same then
    for _, n in ipairs(best.nodes) do local np = P.node_pos(lat, n.i, n.j); add(np.x, np.y) end
  end
  add(best.b.point.x, best.b.point.y)
  add(q.x, q.y)
  return wp, best.len
end

---------------------------------------------------------------------------------------------------
-- 4. Points d'appui : dans la rue la plus proche praticable, regroupés tous les P.ANCHOR_STEP tuiles
---------------------------------------------------------------------------------------------------
--- Point d'appui d'une entité (centre x, y) : { x, y, seg, key } ou nil (aucune rue praticable à 16 tuiles).
function P.anchor_for(lat, x, y, ok)
  for _, a in ipairs(P.street_access(lat, { x = x, y = y })) do
    if ok(a.seg) then
      local ax, ay = a.point.x, a.point.y
      local kind = a.seg:sub(1, 1)
      if kind == "h" then ax = lat.ox + P.HALF + 2 + P.ANCHOR_STEP * round((ax - lat.ox - P.HALF - 2) / P.ANCHOR_STEP)
      else ay = lat.oy + P.HALF + 2 + P.ANCHOR_STEP * round((ay - lat.oy - P.HALF - 2) / P.ANCHOR_STEP) end
      local dx, dy = ax - x, ay - y
      if dx * dx + dy * dy <= P.BUILD_DISTANCE * P.BUILD_DISTANCE then
        return { x = ax, y = ay, seg = a.seg, key = string.format("%d:%d", round(ax), round(ay)) }
      end
    end
  end
  return nil
end

---------------------------------------------------------------------------------------------------
-- 5. Géométrie des entités planifiées
---------------------------------------------------------------------------------------------------
--- Côtés d'une entité (nom connu de modules.lua ; grand poteau et coffres ajoutés ici).
local EXTRA = {
  ["big-electric-pole"] = { w = 2, h = 2, wire = 30 },
  ["iron-chest"] = { w = 1, h = 1 }, ["wooden-chest"] = { w = 1, h = 1 }, ["steel-chest"] = { w = 1, h = 1 },
  ["small-electric-pole"] = { w = 1, h = 1, wire = 7.5 }, ["medium-electric-pole"] = { w = 1, h = 1, wire = 9 },
}
--- Lot ESPACE : une pièce d'un lot (le mur de l'enceinte) déclare son emprise par son nom lu dans T, sans l'écrire ici.
local DECLARED = {}
function P.declare_size(name, w, h) DECLARED[name] = { w = w, h = h } end
function P.size(name, dir)
  local x = EXTRA[name] or DECLARED[name]
  if x then return x.w, x.h end
  return M.size(name, dir or 0)
end

function P.wire(name)
  local x = EXTRA[name]
  if x and x.wire then return x.wire end
  local s = M.spec(name)
  return s and s.wire or nil
end

--- Tuiles couvertes par une entité planifiée (liste {x, y}).
function P.tiles_of(e)
  local w, h = P.size(e.name, e.dir)
  local x0, y0 = round(e.x - w / 2), round(e.y - h / 2)
  local out = {}
  for ty = y0, y0 + h - 1 do for tx = x0, x0 + w - 1 do out[#out + 1] = { tx, ty } end end
  return out
end

--- Contrôle des chevauchements d'une liste d'entités planifiées : liste des paires { i, j } qui partagent une tuile.
function P.overlaps(list)
  local occ, bad = {}, {}
  for i, e in ipairs(list) do
    for _, t in ipairs(P.tiles_of(e)) do
      local k = tkey(t[1], t[2])
      if occ[k] then bad[#bad + 1] = { occ[k], i } else occ[k] = i end
    end
  end
  return bad
end

---------------------------------------------------------------------------------------------------
-- 6. Placement d'un gabarit dans un lot
---------------------------------------------------------------------------------------------------
--- Ports tapis d'un gabarit posé : { io, x, y (tuile de la tête ou de la queue), dir, lanes, ent }.
function P.belt_ports(inst)
  local out = {}
  for _, p in ipairs(inst.ports) do
    if p.kind == "tapis" then
      local e = inst.entities[p.ent]
      out[#out + 1] = { io = p.io, x = floor(e.position.x), y = floor(e.position.y), dir = e.direction or 0,
        lanes = p.lanes, ent = p.ent }
    end
  end
  return out
end

--- Tuiles réservées hors de l'emprise pour les ports tapis : têtes d'alimentation (3 tuiles derrière, ± 2 de côté)
--- et quais de sortie (2 tuiles devant). Liste {x, y}.
function P.port_room(inst)
  local out = {}
  for _, p in ipairs(P.belt_ports(inst)) do
    local v = DV[p.dir]
    local lx, ly = left_of(p.dir)
    if p.io == "in" then
      for k = 1, P.FEED_DEPTH do
        for s = -2, 2 do out[#out + 1] = { p.x - k * v[1] + s * lx, p.y - k * v[2] + s * ly } end
      end
    else
      for k = 1, 2 do out[#out + 1] = { p.x + k * v[1], p.y + k * v[2] } end
    end
  end
  return out
end

--- Meilleur placement d'un gabarit dans un rectangle (lot) : { k, ox, oy, cover, score } ou nil, raison.
--- opts : ore = { [tkey] = true } (tuiles de minerai de la ressource visée ; foreuses) ; toward = {x, y} (entrées et
--- consommateurs : le placement le plus proche gagne) ; free(tx, ty) -> bool (tuile utilisable : ni eau, ni falaise,
--- ni bâtiment) ; margin (tuiles libres entre l'emprise et les rues, défaut 1) ; step (défaut 1).
function P.fit(g, rect, opts)
  opts = opts or {}
  local margin = opts.margin or 1
  local best
  local tried = 0
  -- Somme cumulée 2D des tuiles bloquées du rectangle : emprise contrôlée en O(1) par position.
  local W, H = rect.x1 - rect.x0, rect.y1 - rect.y0
  local sat
  if opts.free then
    sat = {}
    for x = 0, W do sat[x] = 0 end
    for y = 1, H do
      sat[y * (W + 1)] = 0
      local row = 0
      for x = 1, W do
        if not opts.free(rect.x0 + x - 1, rect.y0 + y - 1) then row = row + 1 end
        sat[y * (W + 1) + x] = sat[(y - 1) * (W + 1) + x] + row
      end
    end
  end
  local function blocked(x0, y0, w, h)
    local a, b = y0 * (W + 1), (y0 + h) * (W + 1)
    return sat[b + x0 + w] - sat[a + x0 + w] - sat[b + x0] + sat[a + x0]
  end
  for k = 0, 3 do
    local r = (k == 0) and g or (not g.no_rotate and M.rotate(g, k) or nil)
    if r and r.w <= P.LOT - 2 * margin and r.h <= P.LOT - 2 * margin then
      local res = opts.ore and M.resource_tiles(r) or nil
      -- tuiles minées en rectangle plein (lignes de foreuses) : couverture par sommes cumulées du minerai, en O(1) par
      -- position (27/10 : 8,9 ms par lot essayé sans cela) ; sinon, décompte tuile par tuile
      local rect_res, ore_sat, ox0, oy0, ow
      if res and #res > 0 then
        local rx0, ry0, rx1, ry1 = math.huge, math.huge, -math.huge, -math.huge
        for _, t in ipairs(res) do
          if t.well then rx0 = nil break end
          rx0, ry0 = math.min(rx0, t[1]), math.min(ry0, t[2])
          rx1, ry1 = math.max(rx1, t[1]), math.max(ry1, t[2])
        end
        if rx0 and not opts.slow_cover and (rx1 - rx0 + 1) * (ry1 - ry0 + 1) == #res then
          rect_res = { rx0, ry0, rx1 - rx0 + 1, ry1 - ry0 + 1 }
          ox0, oy0 = rect.x0 + rx0 - 1, rect.y0 + ry0 - 1
          local ox1, oy1 = rect.x1 + rx1 + 1, rect.y1 + ry1 + 1
          ow = ox1 - ox0 + 1
          ore_sat = {}
          for x = 0, ow do ore_sat[x] = 0 end
          for y = 1, oy1 - oy0 + 1 do
            ore_sat[y * (ow + 1)] = 0
            local row = 0
            for x = 1, ow do
              if opts.ore[tkey(ox0 + x - 1, oy0 + y - 1)] then row = row + 1 end
              ore_sat[y * (ow + 1) + x] = ore_sat[(y - 1) * (ow + 1) + x] + row
            end
          end
        end
      end
      local room0 = P.port_room(M.instantiate(r, 0, 0, 0))
      -- pompe de rive (centrale) : la tuile devant la pompe et 60 % des tuiles d'eau du gabarit doivent être de l'eau
      local wt, adj, adj_side
      if r.water and #r.water > 0 then
        if not opts.water then return nil, "eau" end
        wt = r.water
        for _, e in ipairs(r.entities) do
          if e.name == "offshore-pump" then
            local v = DV[e.dir or 0]
            adj = { math.floor(e.x) + v[1], math.floor(e.y) + v[2] }
            adj_side = { -v[2], v[1] } -- perpendiculaire à la direction de la pompe
          end
        end
      end
      for oy = rect.y0 + margin, rect.y1 - margin - r.h, opts.step or 1 do
        for ox = rect.x0 + margin, rect.x1 - margin - r.w, opts.step or 1 do
          tried = tried + 1
          local ok = (not sat) or blocked(ox - rect.x0, oy - rect.y0, r.w, r.h) == 0
          -- place des ports dans le lot (marge 0 : la tête peut toucher le bord du lot)
          if ok then
            for _, t0 in ipairs(room0) do
              local tx, ty = ox + t0[1], oy + t0[2]
              if tx < rect.x0 or tx >= rect.x1 or ty < rect.y0 or ty >= rect.y1 then ok = false break end
              if opts.free and not opts.free(tx, ty) then ok = false break end
            end
          end
          if ok and wt then
            if adj and not opts.water[tkey(ox + adj[1], oy + adj[2])] then ok = false end
            -- Lot IA3-e : la pompe de rive demande 2 tuiles d'eau DEVANT elle (prototype vanilla : adjacent_tile_collision_box
            -- de 2 × 1) : la tuile devant et l'une de ses deux voisines latérales ; le reste du gabarit d'eau à P.PLANT_WET
            -- (60 % avant : sur les rives naturelles des factions, centrale refusée « pas de lot » ou « place » chez 3
            -- factions sur 4, moteur réel e3-usine graine 271828182).
            if ok and adj and adj_side then
              local s1 = opts.water[tkey(ox + adj[1] + adj_side[1], oy + adj[2] + adj_side[2])]
              local s2 = opts.water[tkey(ox + adj[1] - adj_side[1], oy + adj[2] - adj_side[2])]
              if not (s1 or s2) then ok = false end
            end
            if ok then
              local wet = 0
              for _, t in ipairs(wt) do if opts.water[tkey(ox + t[1], oy + t[2])] then wet = wet + 1 end end
              if wet < P.PLANT_WET * #wt then ok = false end
            end
          end
          local cover = 1
          if ok and res then
            local hit = 0
            if rect_res then
              local ax, ay = ox + rect_res[1] - ox0, oy + rect_res[2] - oy0
              local a0, a1 = ay * (ow + 1), (ay + rect_res[4]) * (ow + 1)
              hit = ore_sat[a1 + ax + rect_res[3]] - ore_sat[a0 + ax + rect_res[3]] - ore_sat[a1 + ax] + ore_sat[a0 + ax]
            else
              for _, t in ipairs(res) do if opts.ore[tkey(ox + t[1], oy + t[2])] then hit = hit + 1 end end
            end
            cover = #res > 0 and hit / #res or 0
            if cover < P.DRILL_COVER then ok = false end
          end
          if ok then
            local cx, cy = ox + r.w / 2, oy + r.h / 2
            local d = 0
            if opts.toward then d = math.abs(cx - opts.toward.x) + math.abs(cy - opts.toward.y) end
            local score = d - (res and cover * 100 or 0)
            if not best or score < best.score - 1e-9 then best = { k = k, ox = ox, oy = oy, cover = cover, score = score, w = r.w, h = r.h } end
          end
        end
      end
    end
  end
  if not best then return nil, tried == 0 and "trop grand" or (opts.ore and "minerai" or "place") end
  return best
end

---------------------------------------------------------------------------------------------------
-- 7. Têtes d'alimentation et quais de sortie
---------------------------------------------------------------------------------------------------
--- Tête d'alimentation d'un port d'entrée tapis (tête en (x, y), direction d, voies { a, b }) : sources = { "tapis" |
--- "quai", "tapis" | "quai" } par voie. Rend { entities = { {name, x, y, dir, role, item} }, arrivals = { { lane, item,
--- x, y, dir } } (tuile et direction de la dernière tuile d'un tapis qui arrive), chests = { {x, y, item, lane} } }.
--- Voie 1 = gauche du sens de marche. Un bras dépose sur la voie LOINTAINE : le quai d'une voie est de l'autre côté.
--- Un chargement latéral sur une seule voie exige un tapis DERRIÈRE la tuile chargée (sinon elle devient un virage) :
--- bout mort à 3 tuiles.
function P.feeder(port, sources, quai_inserter)
  local d = port.dir
  local v = DV[d]
  local lx, ly = left_of(d)
  local function at(k, s) return port.x - k * v[1] + s * lx, port.y - k * v[2] + s * ly end
  local ents, arrivals, chests = {}, {}, {}
  local any_belt = sources[1] == "tapis" or sources[2] == "tapis"
  local depth = any_belt and 3 or 1
  for k = 1, depth do
    local x, y = at(k, 0)
    ents[#ents + 1] = { name = "transport-belt", x = x + 0.5, y = y + 0.5, dir = d, role = "tete" }
  end
  for lane = 1, 2 do
    local item = port.lanes and port.lanes[lane]
    local side = (lane == 1) and 1 or -1 -- voie 1 à gauche
    if item and sources[lane] == "quai" then
      -- bras du côté OPPOSÉ à la voie (dépose sur la voie lointaine), coffre au-delà
      local ix, iy = at(1, -side)
      local cx, cy = at(1, -2 * side)
      ents[#ents + 1] = { name = quai_inserter or "inserter", x = ix + 0.5, y = iy + 0.5, dir = dir_of(-side * lx, -side * ly), role = "quai-bras" }
      ents[#ents + 1] = { name = "iron-chest", x = cx + 0.5, y = cy + 0.5, dir = 0, role = "quai", item = item }
      chests[#chests + 1] = { x = cx + 0.5, y = cy + 0.5, item = item, lane = lane }
    elseif item and sources[lane] == "tapis" then
      -- arrivée latérale à la 2e tuile, du côté de la voie
      local ax, ay = at(2, side)
      arrivals[#arrivals + 1] = { lane = lane, item = item, x = ax, y = ay, dir = dir_of(-side * lx, -side * ly) }
    end
  end
  return { entities = ents, arrivals = arrivals, chests = chests }
end

--- Quai de sortie d'un port tapis (queue en (x, y), direction d) : bras qui prend au bout du tapis, coffre devant.
function P.out_quai(port, inserter)
  local v = DV[port.dir]
  local ix, iy = port.x + v[1], port.y + v[2]
  local cx, cy = port.x + 2 * v[1], port.y + 2 * v[2]
  return {
    { name = inserter or "inserter", x = ix + 0.5, y = iy + 0.5, dir = dir_of(-v[1], -v[2]), role = "sortie-bras" },
    { name = "iron-chest", x = cx + 0.5, y = cy + 0.5, dir = 0, role = "sortie" },
  }
end

---------------------------------------------------------------------------------------------------
-- 8. Tapis entre modules : A* borné
---------------------------------------------------------------------------------------------------
--- Tas binaire (min) à départage déterministe : (f, h, clé).
local function heap_push(h, n)
  h[#h + 1] = n
  local i = #h
  while i > 1 do
    local p = floor(i / 2)
    local a, b = h[p], h[i]
    if a.f < b.f or (a.f == b.f and (a.h < b.h or (a.h == b.h and a.k <= b.k))) then break end
    h[p], h[i] = b, a
    i = p
  end
end
local function heap_pop(h)
  local top = h[1]
  local last = h[#h]
  h[#h] = nil
  if #h > 0 then
    h[1] = last
    local i = 1
    while true do
      local l, r, m = 2 * i, 2 * i + 1, i
      local function less(x, y)
        local a, b = h[x], h[y]
        return a.f < b.f or (a.f == b.f and (a.h < b.h or (a.h == b.h and a.k < b.k)))
      end
      if l <= #h and less(l, m) then m = l end
      if r <= #h and less(r, m) then m = r end
      if m == i then break end
      h[m], h[i] = h[i], h[m]
      i = m
    end
  end
  return top
end

--- Tracé d'un tapis de la tuile `s` à la tuile `t` (incluses) dans `bounds` {x0, y0, x1, y1} (inclus), 4 voisins.
--- cost(x, y) -> nil (interdit) ou coût ≥ 1. Rend la liste des tuiles {x, y, dir} (chaque tuile tournée vers la
--- suivante ; la dernière vers `t_dir`) et le nombre de nœuds développés, ou nil, raison.
function P.belt_route(s, t, t_dir, bounds, cost, opts)
  if not cost(s.x, s.y) then return nil, "depart" end
  if not cost(t.x, t.y) then return nil, "arrivee" end
  -- Lot AUTO : opts = { weight, max } (facultatif ; absent : A* exact, plafond P.ASTAR_MAX, comme avant). weight > 1 :
  -- A* PONDÉRÉ (heuristique × weight : chemin au plus weight fois plus cher que le meilleur, beaucoup moins de nœuds en
  -- forêt et entre les rues) ; max : nœuds développés au plus (la boîte entière : « aucun chemin » plutôt que « trop long »).
  local hw = (opts and opts.weight) or 1
  local cap = (opts and opts.max) or P.ASTAR_MAX
  local open = {}
  local g = { [tkey(s.x, s.y)] = 0 }
  local prev = {}
  local closed = {}
  local function hh(x, y) return (math.abs(x - t.x) + math.abs(y - t.y)) * hw end
  heap_push(open, { x = s.x, y = s.y, f = hh(s.x, s.y), h = hh(s.x, s.y), k = tkey(s.x, s.y) })
  local expanded = 0
  local ORDER = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }
  while #open > 0 do
    local cur = heap_pop(open)
    local ck = cur.k
    if not closed[ck] then
      closed[ck] = true
      expanded = expanded + 1
      if expanded > cap then return nil, "trop long" end
      if cur.x == t.x and cur.y == t.y then
        local tiles = {}
        local k = ck
        local x, y = cur.x, cur.y
        while true do
          table.insert(tiles, 1, { x = x, y = y })
          local p = prev[k]
          if not p then break end
          x, y, k = p[1], p[2], tkey(p[1], p[2])
        end
        for i = 1, #tiles - 1 do
          tiles[i].dir = dir_of(tiles[i + 1].x - tiles[i].x, tiles[i + 1].y - tiles[i].y)
        end
        tiles[#tiles].dir = t_dir
        return tiles, expanded
      end
      for _, o in ipairs(ORDER) do
        local nx, ny = cur.x + o[1], cur.y + o[2]
        if nx >= bounds.x0 and nx <= bounds.x1 and ny >= bounds.y0 and ny <= bounds.y1 then
          local nk = tkey(nx, ny)
          if not closed[nk] then
            local c = cost(nx, ny)
            if c then
              local ng = g[ck] + c
              if g[nk] == nil or ng < g[nk] then
                g[nk] = ng
                prev[nk] = { cur.x, cur.y }
                local h = hh(nx, ny)
                heap_push(open, { x = nx, y = ny, f = ng + h, h = h, k = nk })
              end
            end
          end
        end
      end
    end
  end
  return nil, "aucun chemin"
end

---------------------------------------------------------------------------------------------------
-- 9. Poteaux
---------------------------------------------------------------------------------------------------
--- Chaîne de poteaux de `a` à `b` (centres) : positions intermédiaires (centres de tuile pour un poteau 1 × 1, coin
--- pour un 2 × 2) à `reach` au plus l'une de l'autre, chacune sur une tuile libre (free(x, y) : centre). nil si
--- impossible. a et b ne sont pas rendus.
function P.pole_chain(a, b, reach, big, free)
  local out = {}
  local cur = { x = a.x, y = a.y }
  local function dist(p, q) local dx, dy = p.x - q.x, p.y - q.y; return math.sqrt(dx * dx + dy * dy) end
  for _ = 1, 64 do
    if dist(cur, b) <= reach + 1e-9 then return out end
    local d = dist(cur, b)
    local step = reach - 0.5
    local tx = cur.x + (b.x - cur.x) * step / d
    local ty = cur.y + (b.y - cur.y) * step / d
    local found
    for r = 0, 3 do
      local cands = {}
      for dy = -r, r do
        for dx = -r, r do
          if math.max(math.abs(dx), math.abs(dy)) == r then
            local px, py
            if big then px, py = round(tx) + dx, round(ty) + dy else px, py = floor(tx) + dx + 0.5, floor(ty) + dy + 0.5 end
            cands[#cands + 1] = { x = px, y = py }
          end
        end
      end
      table.sort(cands, function(p, q)
        local dp, dq = dist(p, b), dist(q, b)
        if dp ~= dq then return dp < dq end
        if p.y ~= q.y then return p.y < q.y end
        return p.x < q.x
      end)
      for _, c in ipairs(cands) do
        if dist(c, cur) <= reach + 1e-9 and dist(c, b) < dist(cur, b) - 0.5 and free(c.x, c.y) then found = c break end
      end
      if found then break end
    end
    if not found then return nil end
    out[#out + 1] = found
    cur = found
  end
  return nil
end

--- Position d'un poteau de carrefour (quart nord-ouest du croisement, hors des lignes de marche).
function P.node_pole(lat, i, j, big)
  local n = P.node_pos(lat, i, j)
  if big then return { x = n.x - 1, y = n.y - 1 } end
  return { x = n.x - 1.5, y = n.y - 1.5 }
end

---------------------------------------------------------------------------------------------------
-- 10. Ordre de pose (EQUIPES_PNJ §6.6, 4) : poteaux, machines, bras, coffres, puis tapis et tuyaux
---------------------------------------------------------------------------------------------------
local RANK = { pole = 1, machine = 2, inserter = 3, chest = 4, belt = 5, pipe = 6 }
function P.kind_rank(name)
  if name:find("electric%-pole") then return RANK.pole end
  if name:find("inserter") then return RANK.inserter end
  if name:find("chest") then return RANK.chest end
  if name:find("belt") or name:find("splitter") then return RANK.belt end
  if name:find("pipe") then return RANK.pipe end
  return RANK.machine
end

--- Trie une liste d'entités planifiées dans l'ordre de pose (rang, puis y, puis x, puis nom).
function P.sort_build(list)
  table.sort(list, function(a, b)
    local ra, rb = P.kind_rank(a.name), P.kind_rank(b.name)
    if ra ~= rb then return ra < rb end
    if a.y ~= b.y then return a.y < b.y end
    if a.x ~= b.x then return a.x < b.x end
    return a.name < b.name
  end)
  return list
end

return P
