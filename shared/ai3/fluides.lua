--[[
  Lot PETROLE (A9 « aller au pétrole, comme un joueur ») : l'EXÉCUTANT générique des chaînes à fluides et des machines
  sans lesquelles la main ne sait rien faire. PUR (aucune API Factorio) ; lu par script/ai3/petrole.lua (relevé des
  prototypes) et par tests/petrole_test.lua (relevé des fixtures).

  Aucun nom du jeu ici (test anti-échelle, tests/iag_test.lua §8) : tout se lit dans le RELEVÉ :
    rel.entities = { [entité] = { role (R.ENTITY_ROLE), item, w, h, categories = {..} (fabrication),
                     rescats = {..} (minage), fluid (pompe : fluide pompé), speed,
                     boxes = { { type = "input" | "output" | "input-output", conns = { [0|2|4|6] = {x, y} ... } } } } }
      (conns : positions des raccords par DIRECTION de l'entité, relatives à son centre, telles que le prototype les
      donne : la tuile voisine où un tuyau se raccorde) ;
    rel.recipes  = relevé du catalogue ({ [nom] = { category, energy, hidden, ingredients, products } }) ;
    rel.resources = relevé du catalogue ({ { entity, category, products } }) ;
    rel.hand = { [catégorie] = vrai } (catégories de la main).

  1. Fl.executors(rel, exec) : ce que l'exécutant SAIT poser et faire tourner, déduit des données :
       - l'EXTRACTEUR d'une ressource fluide (une foreuse dont les catégories de minage contiennent celle de la ressource
         et qui a une boîte à fluide de sortie) ;
       - pour chaque recette qu'aucun exécutant de `exec` ne fait déjà et que la main ne sait pas faire (catégorie hors
         de la main, ou un fluide en entrée ou en sortie) : les machines dont les catégories contiennent la sienne et
         dont les boîtes à fluide suffisent (entrées, sorties). Règles de l'exécutant (celles d'un joueur qui pose une
         cellule simple : coffre, bras, machine, bras, coffre, tuyaux) : au plus Fl.MAX_SOLID_IN ingrédients solides,
         Fl.MAX_FLUID_IN fluides, un seul produit solide (rapporté par un porteur) OU un seul produit fluide (il passe
         au tuyau à la machine suivante) : un sous-produit fluide sans débouché remplirait la machine et l'arrêterait.
     Rend (ajouts { [entité] = vrai | { [recette] = vrai } }, info { recipes = { [recette] = {machines} }, extract =
     { [fluide] = {entités} } }).
  2. Fl.chain(rel, info, targets, sources) : les CELLULES qui fabriquent les objets `targets` : la recette de chaque
     objet, puis, pour chaque fluide qu'elle mange, sa source : une ressource fluide (extracteur), la pompe d'un fluide
     (sources[fluide] = "pompe"), ou une autre cellule qui le produit (récursif). Les ingrédients solides viennent d'un
     coffre (quai rempli depuis le QG).
  3. Fl.layout(req) : l'IMPLANTATION (plan directeur d'un site) : extracteurs centrés sur les puits, cellules posées sur
     une place libre (la machine, une marge), quais d'entrée et de sortie (coffre et bras), tuyaux tracés par A* entre
     les raccords des boîtes à fluide LUS dans les prototypes (deux fluides ne se touchent jamais : un tuyau se raccorde
     à tous ses voisins), poteaux qui couvrent les machines, ligne de poteaux jusqu'au réseau de l'équipe.
  Déterminisme : listes triées, entiers, égalités départagées par les coordonnées puis le nom ; aucun hasard.
]]

local Fl = {}

Fl.MAX_SOLID_IN = 3
Fl.MAX_FLUID_IN = 2
Fl.MAX_DEPTH = 6        -- profondeur d'une chaîne de cellules (garde contre un cycle de recettes)
Fl.MARGIN = 2           -- tuiles libres autour d'une machine (bras, coffres, tuyaux)
Fl.SEARCH = 30          -- rayon de recherche d'une place (tuiles)
Fl.ASTAR_MAX = 20000    -- nœuds développés au plus par tuyau
Fl.ROUTE_R = 48         -- fenêtre d'un tuyau autour du site
Fl.EXTRACTORS = 2       -- puits équipés par site (au départ)
Fl.POLE_LINE_MAX = 400  -- tuiles au plus jusqu'au réseau

local DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }
Fl.DV = DV
local DIRS = { 0, 2, 4, 6 }

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function has(list, v)
  for _, x in ipairs(list or {}) do if x == v then return true end end
  return false
end

local function tkey(x, y) return (x + 1048576) * 2097152 + (y + 1048576) end
Fl.tkey = tkey

--- Fluides et solides d'une recette.
function Fl.split(r)
  local fi, si, fo, so = {}, {}, {}, {}
  for _, i in ipairs(r.ingredients or {}) do
    if i.type == "fluid" then fi[#fi + 1] = i.name else si[#si + 1] = i.name end
  end
  for _, p in ipairs(r.products or {}) do
    if p.type == "fluid" then fo[#fo + 1] = p.name else so[#so + 1] = p.name end
  end
  return fi, si, fo, so
end

local function box_counts(e)
  local nin, nout = 0, 0
  for _, b in ipairs(e.boxes or {}) do
    if b.type == "input" or b.type == "input-output" then nin = nin + 1 end
    if b.type == "output" or b.type == "input-output" then nout = nout + 1 end
  end
  return nin, nout
end

---------------------------------------------------------------------------------------------------
-- 1. Exécutants
---------------------------------------------------------------------------------------------------
--- Une recette est-elle déjà faite par un exécutant de `exec` (une entité exécutante de toutes ses recettes, ou qui la
--- liste) ?
local function done_by(rel, exec, rname, cat)
  for _, en in ipairs(sorted_keys(exec)) do
    local v = exec[en]
    local e = rel.entities[en]
    if v == true and e and has(e.categories, cat) then return true end
    if type(v) == "table" and v[rname] then return true end
  end
  return false
end

function Fl.executors(rel, exec)
  exec = exec or {}
  local add = {}
  local info = { recipes = {}, extract = {} }
  local names = sorted_keys(rel.entities)
  -- Extracteurs des ressources fluides.
  for _, r in ipairs(rel.resources or {}) do
    for _, p in ipairs(r.products or {}) do
      if p.type == "fluid" then
        for _, en in ipairs(names) do
          local e = rel.entities[en]
          local _, nout = box_counts(e)
          if e.role == "foreuse" and e.item and has(e.rescats, r.category) and nout >= 1 then
            info.extract[p.name] = info.extract[p.name] or {}
            if not has(info.extract[p.name], en) then info.extract[p.name][#info.extract[p.name] + 1] = en end
            add[en] = true
          end
        end
      end
    end
  end
  -- Recettes qui demandent une machine.
  for _, rname in ipairs(sorted_keys(rel.recipes)) do
    local r = rel.recipes[rname]
    local fi, si, fo, so = Fl.split(r)
    local needs = (#fi + #fo > 0) or not (rel.hand or {})[r.category]
    local fits = #si <= Fl.MAX_SOLID_IN and #fi <= Fl.MAX_FLUID_IN and #so + #fo == 1 and (#si + #fi) >= 1
    if needs and fits and not r.hidden and not done_by(rel, exec, rname, r.category) then
      for _, en in ipairs(names) do
        local e = rel.entities[en]
        if e.role == "fabrique" and e.item and has(e.categories, r.category) then
          local nin, nout = box_counts(e)
          if nin >= #fi and nout >= #fo then
            info.recipes[rname] = info.recipes[rname] or {}
            info.recipes[rname][#info.recipes[rname] + 1] = en
            if add[en] ~= true then
              add[en] = add[en] or {}
              add[en][rname] = true
            end
          end
        end
      end
    end
  end
  return add, info
end

---------------------------------------------------------------------------------------------------
-- 2. Chaîne de cellules
---------------------------------------------------------------------------------------------------
--- Recette qui produit `item` parmi celles de l'exécutant (la plus courte : moins de fluides, puis le nom).
local function recipe_for(rel, info, item)
  local best, bk
  for _, rname in ipairs(sorted_keys(info.recipes)) do
    local r = rel.recipes[rname]
    for _, p in ipairs(r.products or {}) do
      if p.name == item then
        local fi = Fl.split(r)
        local k = #fi * 1000 + #(r.ingredients or {})
        if not bk or k < bk then best, bk = rname, k end
      end
    end
  end
  return best
end
Fl.recipe_for = recipe_for

--- Machine d'une recette : la première de `choose(liste)` (le runtime choisit celle que l'équipe peut poser), sinon la
--- première de la liste.
function Fl.chain(rel, info, targets, sources, choose)
  sources = sources or {}
  local cells, by_recipe, why = {}, {}, nil
  local need_src = {}
  local function visit(item, depth)
    if depth > Fl.MAX_DEPTH then why = "chaine trop longue (" .. item .. ")" return nil end
    local rname = recipe_for(rel, info, item)
    if not rname then why = "aucune recette de l'executant pour " .. item return nil end
    if by_recipe[rname] then return by_recipe[rname] end
    local r = rel.recipes[rname]
    local fi, si, fo, so = Fl.split(r)
    local cell = { recipe = rname, fin = {}, sin = si, fout = fo[1], sout = so[1] }
    by_recipe[rname] = cell
    for _, fl in ipairs(fi) do
      if info.extract[fl] then
        cell.fin[#cell.fin + 1] = { fluid = fl, src = "extract" }
        need_src[fl] = "extract"
      elseif sources[fl] == "pompe" then
        cell.fin[#cell.fin + 1] = { fluid = fl, src = "pompe" }
        need_src[fl] = "pompe"
      else
        local up = visit(fl, depth + 1)
        if not up then by_recipe[rname] = nil return nil end
        cell.fin[#cell.fin + 1] = { fluid = fl, src = "cell", cell = up.recipe }
      end
    end
    local ms = info.recipes[rname]
    cell.machine = (choose and choose(ms, rname)) or ms[1]
    if not cell.machine then why = "aucune machine posable pour " .. rname by_recipe[rname] = nil return nil end
    cells[#cells + 1] = cell
    return cell
  end
  local made = {}
  for _, t in ipairs(targets) do
    if visit(t, 1) then made[#made + 1] = t end
  end
  if #cells == 0 then return nil, why or "rien a faire" end
  -- ordre de pose : les producteurs de fluide d'abord (ils sont visités avant leurs consommateurs)
  return { cells = cells, sources = need_src, made = made }, why
end

---------------------------------------------------------------------------------------------------
-- 3. Implantation
---------------------------------------------------------------------------------------------------
--[[
  req = {
    origin = {x, y}         centre de recherche de la place (tuiles) ;
    blocked = fn(tx, ty)    vrai si la tuile n'est pas constructible (eau, falaise, bâti, déjà réservée) ;
    ents = rel.entities ;   chain = Fl.chain(...) ;
    wells = { {x, y} } (centres des puits de la ressource fluide, s'il en faut) ;
    pumps = { {x, y, dir} } (places de pompe de rive possibles, s'il en faut) ;
    conduit, chest, arm = noms des pièces (données de l'exécutant) ;
    poles = { name, supply (demi-côté de l'aire), wire (portée) } ;
    network = {x, y} (poteau du réseau le plus proche) ou nil ;
    n_extract = puits à équiper ;
    block = {x, y} (facultatif) : centre de la place des machines (défaut : le centre des extracteurs) ;
  }
  Rend { ents = { {name, x, y, dir, recipe, role} }, quais = { {x, y, item} }, outs = { {x, y, item} }, box = {x0, y0,
  x1, y1}, pipes = n, poles = n, line = n } ou nil, raison.
]]

local function rot_size(e, dir)
  if dir == 2 or dir == 6 then return e.h, e.w end
  return e.w, e.h
end

local function rect_of(e, cx, cy, dir)
  local w, h = rot_size(e, dir)
  local x0, y0 = math.floor(cx - w / 2 + 0.01), math.floor(cy - h / 2 + 0.01)
  return x0, y0, x0 + w - 1, y0 + h - 1
end
Fl.rect_of = rect_of

--- Tuile d'un raccord (centre + position du prototype pour la direction).
local function conn_tile(cx, cy, pos)
  return math.floor(cx + pos[1] + 0.01), math.floor(cy + pos[2] + 0.01)
end

local Site = {}
Site.__index = Site

---------------------------------------------------------------------------------------------------
-- Ligne de poteaux contournant les obstacles (lot PETROLE 2)
---------------------------------------------------------------------------------------------------
Fl.POLE_ASTAR_MAX = 3000  -- nœuds (cellules de 3 × 3 tuiles) développés au plus par ligne de relais
Fl.POLE_CELL = 3          -- côté d'une cellule du treillis de recherche

--- Décalages (en cellules) d'un relais au suivant pour une portée de fil `wire` : tous les décalages dont le centre est à
--- portée (plus la marge du déplacement d'un relais dans sa cellule, 1 tuile de chaque côté) ; la distance exacte entre
--- les deux tuiles choisies est contrôlée à l'expansion. Triés (di, dj) : déterministe.
function Fl.pole_cells(wire)
  local out = {}
  local reach = math.floor((wire + Fl.POLE_CELL - 1) / Fl.POLE_CELL)
  for di = -reach, reach do
    for dj = -reach, reach do
      local d = Fl.POLE_CELL * math.sqrt(di * di + dj * dj)
      if (di ~= 0 or dj ~= 0) and d <= wire + 2 then out[#out + 1] = { di, dj } end
    end
  end
  return out
end

--- Relais d'une ligne de poteaux de `a` à `b` ({x, y} centres de tuiles) par A* sur un treillis de cellules de
--- Fl.POLE_CELL tuiles (le relais d'une cellule est sa tuile centrale libre, sinon l'une de ses 8 voisines, `free(tx, ty)`),
--- chaque saut d'au plus `wire` tuiles ; coût d'un saut = 10 + sa longueur (peu de poteaux d'abord). Rend la liste des
--- centres des relais intermédiaires (vide si `a` et `b` se touchent déjà) ou nil (aucun chemin dans `max_nodes`).
function Fl.pole_route(a, b, wire, free, max_nodes)
  local w2 = wire * wire
  local function d2(x1, y1, x2, y2) return (x1 - x2) ^ 2 + (y1 - y2) ^ 2 end
  if d2(a.x, a.y, b.x, b.y) <= w2 then return {} end
  local cells = Fl.pole_cells(wire)
  local C = Fl.POLE_CELL
  local ax, ay = math.floor(a.x), math.floor(a.y)
  local bx, by = b.x, b.y
  local per = (10 + wire) / wire -- coût minimal par tuile parcourue (saut de la portée entière) : heuristique cohérente
  local function h(tx, ty) return math.max(0, math.sqrt(d2(tx + 0.5, ty + 0.5, bx, by)) - wire) * per end
  local order = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }
  -- tuile du relais d'une cellule (mémoïsée : ne dépend que de la cellule) ; nil si aucune tuile libre
  local reps = {}
  local function rep(i, j)
    local ck = i * 8192 + j
    local r = reps[ck]
    if r ~= nil then return r or nil end
    for _, o in ipairs(order) do
      local tx, ty = ax + i * C + o[1], ay + j * C + o[2]
      if free(tx, ty) then r = { tx, ty }; break end
    end
    reps[ck] = r or false
    return r
  end
  -- tas binaire (f, puis clé) : déterministe
  local heap, hn = {}, 0
  local function less(p, q) if p.f ~= q.f then return p.f < q.f end return p.k < q.k end
  local function push(node)
    hn = hn + 1
    heap[hn] = node
    local i = hn
    while i > 1 do
      local par = math.floor(i / 2)
      if less(heap[i], heap[par]) then heap[i], heap[par] = heap[par], heap[i]; i = par else break end
    end
  end
  local function pop()
    local top = heap[1]
    heap[1] = heap[hn]
    heap[hn] = nil
    hn = hn - 1
    local i = 1
    while true do
      local l, r, m = 2 * i, 2 * i + 1, i
      if l <= hn and less(heap[l], heap[m]) then m = l end
      if r <= hn and less(heap[r], heap[m]) then m = r end
      if m == i then break end
      heap[i], heap[m] = heap[m], heap[i]
      i = m
    end
    return top
  end
  local g, parent, closed = {}, {}, {}
  local k0 = 0
  g[k0] = 0
  push({ k = k0, i = 0, j = 0, x = ax, y = ay, f = h(ax, ay) })
  local expanded = 0
  while hn > 0 do
    local cur = pop()
    if not closed[cur.k] then
      closed[cur.k] = true
      if cur.k ~= k0 and d2(cur.x + 0.5, cur.y + 0.5, bx, by) <= w2 then
        local chain, k = {}, cur.k
        while k ~= k0 do
          local nd = parent[k]
          chain[#chain + 1] = nd.tile
          k = nd.from
        end
        local path = {}
        for i = #chain, 1, -1 do path[#path + 1] = { x = chain[i][1] + 0.5, y = chain[i][2] + 0.5 } end
        return path
      end
      expanded = expanded + 1
      if expanded > (max_nodes or Fl.POLE_ASTAR_MAX) then return nil end
      for _, st in ipairs(cells) do
        local ni, nj = cur.i + st[1], cur.j + st[2]
        local nk = ni * 8192 + nj
        if nk ~= k0 and not closed[nk] then
          local r = rep(ni, nj)
          if r then
            local dd = d2(cur.x, cur.y, r[1], r[2])
            if dd <= w2 then
              local ng = g[cur.k] + 10 + math.sqrt(dd)
              if g[nk] == nil or ng < g[nk] then
                g[nk] = ng
                parent[nk] = { from = cur.k, tile = r }
                push({ k = nk, i = ni, j = nj, x = r[1], y = r[2], f = ng + h(r[1], r[2]) })
              end
            end
          end
        end
      end
    end
  end
  return nil
end

local function new_site(req)
  local s = setmetatable({ req = req, occ = {}, ents = {}, tube = {}, rsv = {}, quais = {}, outs = {}, npipes = 0 }, Site)
  return s
end

function Site:free(tx, ty)
  local k = tkey(tx, ty)
  if self.occ[k] or self.tube[k] or self.rsv[k] then return false end
  return not self.req.blocked(tx, ty)
end

function Site:rect_free(x0, y0, x1, y1)
  for ty = y0, y1 do for tx = x0, x1 do if not self:free(tx, ty) then return false end end end
  return true
end

function Site:put(name, cx, cy, dir, opt)
  local e = self.req.ents[name] or { w = 1, h = 1 }
  local x0, y0, x1, y1 = rect_of(e, cx, cy, dir)
  for ty = y0, y1 do for tx = x0, x1 do self.occ[tkey(tx, ty)] = #self.ents + 1 end end
  local ent = { name = name, x = cx, y = cy, dir = dir or 0, recipe = opt and opt.recipe, role = opt and opt.role,
    fluid = opt and opt.fluid }
  self.ents[#self.ents + 1] = ent
  return ent
end

--- Raccords d'une entité posée : { {tx, ty, type, box} } (boîte = indice dans les boîtes du prototype).
function Site:conns(ent)
  local e = self.req.ents[ent.name]
  local out = {}
  for bi, b in ipairs((e and e.boxes) or {}) do
    local pos = b.conns and b.conns[ent.dir or 0]
    if pos then
      for _, p in ipairs(pos) do
        local tx, ty = conn_tile(ent.x, ent.y, p)
        local fl = nil
        if ent.map then fl = ent.map[bi] or false end
        out[#out + 1] = { tx = tx, ty = ty, type = b.type, box = bi, fluid = fl }
      end
    end
  end
  return out
end

--- Fluide de chaque boîte d'une machine pour sa recette : règle du moteur (fluides des ingrédients, dans l'ordre, aux
--- boîtes d'entrée dans l'ordre ; produits aux boîtes de sortie) ; un seul fluide d'un sens : TOUTES les boîtes de ce
--- sens le prennent (le moteur peut le placer dans n'importe laquelle : on raccorde chacune).
local function assign_boxes(e, fin, fout)
  local res = {}
  local ins, outs = {}, {}
  for bi, b in ipairs(e.boxes or {}) do
    if b.type == "input" or b.type == "input-output" then ins[#ins + 1] = bi end
    if b.type == "output" or b.type == "input-output" then outs[#outs + 1] = bi end
  end
  if #fin == 1 then for _, bi in ipairs(ins) do res[bi] = fin[1] end
  else for i, fl in ipairs(fin) do if ins[i] then res[ins[i]] = fl end end end
  if #fout == 1 then for _, bi in ipairs(outs) do if not res[bi] then res[bi] = fout[1] end end
  else for i, fl in ipairs(fout) do if outs[i] then res[outs[i]] = fl end end end
  return res
end
Fl.assign_boxes = assign_boxes

--- Réserve les tuiles de raccord d'une entité : fluide attendu (ou faux : boîte sans fluide, à ne jamais toucher).
function Site:reserve_conns(ent, map)
  ent.map = map or {}
  for _, c in ipairs(self:conns(ent)) do
    local fl = map and map[c.box] or false
    local k = tkey(c.tx, c.ty)
    if self.rsv[k] == nil or self.rsv[k] == fl then self.rsv[k] = fl else self.rsv[k] = "*conflit*" end
    c.fluid = fl
  end
end

local function copy1(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end

--- Photo de l'état d'un site (essai d'une pompe : retour en arrière si son tuyau ne se trace pas) ; `nets` : réseaux de tuyaux
--- par fluide du plan en cours.
function Site:snapshot(nets)
  local n2 = {}
  for k, v in pairs(nets) do n2[k] = copy1(v) end
  return { occ = copy1(self.occ), tube = copy1(self.tube), rsv = copy1(self.rsv), nents = #self.ents, npipes = self.npipes,
    nquais = #self.quais, nouts = #self.outs, nets = n2 }
end

function Site:restore(snap, nets)
  self.occ, self.tube, self.rsv, self.npipes = snap.occ, snap.tube, snap.rsv, snap.npipes
  for i = #self.ents, snap.nents + 1, -1 do self.ents[i] = nil end
  for i = #self.quais, snap.nquais + 1, -1 do self.quais[i] = nil end
  for i = #self.outs, snap.nouts + 1, -1 do self.outs[i] = nil end
  for k in pairs(nets) do nets[k] = nil end
  for k, v in pairs(snap.nets) do nets[k] = v end
end

--- Une tuile peut-elle porter un tuyau du fluide `fl` ?
function Site:pipe_ok(tx, ty, fl)
  local k = tkey(tx, ty)
  if self.occ[k] then return false end
  if self.tube[k] then return self.tube[k] == fl end
  local r = self.rsv[k]
  if r ~= nil and r ~= fl then return false end
  if self.req.blocked(tx, ty) then return false end
  for _, d in ipairs(DIRS) do
    local nk = tkey(tx + DV[d][1], ty + DV[d][2])
    local p = self.tube[nk]
    if p and p ~= fl then return false end
    local rr = self.rsv[nk]
    if rr ~= nil and rr ~= false and rr ~= fl and not self.occ[nk] then return false end
  end
  return true
end

--- Tuyau du fluide `fl` d'une tuile de départ à l'ensemble `goal` ({ [clé] = vrai }) : A* sur la grille (4 voisins,
--- coût 1, heuristique de Manhattan vers la cible la plus proche) ; pose les tuyaux. Rend le nombre posé, ou nil.
function Site:route(sx, sy, goal, fl)
  local gl = {}
  for _, k in ipairs(sorted_keys(goal)) do
    local gx, gy = math.floor(k / 2097152) - 1048576, k % 2097152 - 1048576
    gl[#gl + 1] = { gx, gy }
  end
  if #gl == 0 then return nil end
  local sk = tkey(sx, sy)
  if goal[sk] then
    if not self.tube[sk] then self.tube[sk] = fl; self.npipes = self.npipes + 1 end
    return 0
  end
  if not self:pipe_ok(sx, sy, fl) then return nil end
  -- une cible dont aucun voisin n'accepte un tuyau de ce fluide est scellée (autres fluides, machines) : refus immédiat,
  -- sans développer l'A* (moteur réel, 28/10 : l'eau d'une usine entourée de tuyaux de brut)
  do
    local open_goal = false
    for _, g in ipairs(gl) do
      for _, d in ipairs(DIRS) do
        local nx, ny = g[1] + DV[d][1], g[2] + DV[d][2]
        if (nx == sx and ny == sy) or goal[tkey(nx, ny)] or self:pipe_ok(nx, ny, fl) then open_goal = true end
      end
      if open_goal then break end
    end
    if not open_goal then return nil end
  end
  local function h(x, y)
    local best = math.huge
    for _, g in ipairs(gl) do
      local d = math.abs(g[1] - x) + math.abs(g[2] - y)
      if d < best then best = d end
    end
    return best
  end
  -- fenêtre : le rectangle du départ et de la cible la plus proche, élargi de Fl.ROUTE_R / 2 (une liaison lointaine,
  -- l'eau d'une rive éloignée du gisement, garde sa fenêtre ; moteur réel, petrole-partie : rive à plus de 48 tuiles)
  local near, nd = gl[1], math.huge
  for _, g in ipairs(gl) do
    local d = math.abs(g[1] - sx) + math.abs(g[2] - sy)
    if d < nd then near, nd = g, d end
  end
  local ox, oy = (sx + near[1]) / 2, (sy + near[2]) / 2
  local R = math.max(math.abs(sx - near[1]), math.abs(sy - near[2])) / 2 + Fl.ROUTE_R / 2
  local open = { { f = h(sx, sy), g = 0, x = sx, y = sy } }
  local came, gs = { [sk] = false }, { [sk] = 0 }
  local n = 0
  local found
  while #open > 0 do
    -- tas binaire minimal (f, puis g décroissant, puis y, x : déterministe)
    local cur = open[1]
    local last = table.remove(open)
    if #open > 0 then
      open[1] = last
      local i = 1
      while true do
        local l, r2 = 2 * i, 2 * i + 1
        local m = i
        local function less(a, b)
          if a.f ~= b.f then return a.f < b.f end
          if a.g ~= b.g then return a.g > b.g end
          if a.y ~= b.y then return a.y < b.y end
          return a.x < b.x
        end
        if open[l] and less(open[l], open[m]) then m = l end
        if open[r2] and less(open[r2], open[m]) then m = r2 end
        if m == i then break end
        open[i], open[m] = open[m], open[i]
        i = m
      end
    end
    local ck = tkey(cur.x, cur.y)
    if cur.g == gs[ck] then
      n = n + 1
      self.req.spent = (self.req.spent or 0) + 1
      if n > Fl.ASTAR_MAX or self.req.spent > Fl.LAYOUT_BUDGET then return nil end
      for _, d in ipairs(DIRS) do
        local nx, ny = cur.x + DV[d][1], cur.y + DV[d][2]
        local nk = tkey(nx, ny)
        if goal[nk] then
          came[nk] = ck
          found = nk
          break
        end
        if math.abs(nx - ox) <= R and math.abs(ny - oy) <= R and self:pipe_ok(nx, ny, fl) then
          local g = cur.g + 1
          if gs[nk] == nil or g < gs[nk] then
            gs[nk] = g
            came[nk] = ck
            local node = { f = g + h(nx, ny), g = g, x = nx, y = ny }
            open[#open + 1] = node
            local i = #open
            while i > 1 do
              local p = math.floor(i / 2)
              local a, b = open[i], open[p]
              local lt = a.f < b.f or (a.f == b.f and (a.g > b.g or (a.g == b.g and (a.y < b.y or (a.y == b.y and a.x < b.x)))))
              if not lt then break end
              open[i], open[p] = open[p], open[i]
              i = p
            end
          end
        end
      end
      if found then break end
    end
  end
  if not found then return nil end
  local placed = 0
  local k = came[found]
  -- la tuile but est un raccord (ou un tuyau du réseau) : un tuyau y est posé s'il n'y en a pas
  if not self.tube[found] and not self.occ[found] then self.tube[found] = fl; placed = placed + 1 end
  while k do
    if not self.tube[k] then self.tube[k] = fl; placed = placed + 1 end
    k = came[k]
  end
  self.npipes = self.npipes + placed
  return placed
end

--- Place libre d'une machine (direction 0) au plus près de (x, y), avec la marge ; rend cx, cy ou nil.
function Site:find_spot(name, x, y)
  local e = self.req.ents[name]
  local m = Fl.MARGIN
  local ring = {}
  for r = 0, Fl.SEARCH do
    ring = {}
    for dy = -r, r do
      for dx = -r, r do
        if math.max(math.abs(dx), math.abs(dy)) == r then ring[#ring + 1] = { dx, dy } end
      end
    end
    table.sort(ring, function(u, v)
      local du, dv = u[1] * u[1] + u[2] * u[2], v[1] * v[1] + v[2] * v[2]
      if du ~= dv then return du < dv end
      if u[2] ~= v[2] then return u[2] < v[2] end
      return u[1] < v[1]
    end)
    for _, d in ipairs(ring) do
      local tx, ty = math.floor(x) + d[1], math.floor(y) + d[2]
      -- centre : un côté impair tombe au milieu d'une tuile, un côté pair sur un coin
      local cx = (e.w % 2 == 1) and (tx + 0.5) or tx
      local cy = (e.h % 2 == 1) and (ty + 0.5) or ty
      local x0, y0, x1, y1 = rect_of(e, cx, cy, 0)
      if self:rect_free(x0 - m, y0 - m, x1 + m, y1 + m) then return cx, cy end
    end
  end
  return nil
end

--- Quai d'une cellule : un bras et un coffre sur un côté de la machine (tuiles libres qui ne sont pas des raccords).
--- `into` : vrai pour un quai d'entrée (le bras prend au coffre et dépose dans la machine). Rend vrai ou faux.
function Site:quai(mach, item, into)
  local e = self.req.ents[mach.name]
  local x0, y0, x1, y1 = rect_of(e, mach.x, mach.y, mach.dir)
  local cands = {}
  for tx = x0, x1 do cands[#cands + 1] = { tx, y1 + 1, 4 }; cands[#cands + 1] = { tx, y0 - 1, 0 } end
  for ty = y0, y1 do cands[#cands + 1] = { x1 + 1, ty, 2 }; cands[#cands + 1] = { x0 - 1, ty, 6 } end
  for _, c in ipairs(cands) do
    local ax, ay, side = c[1], c[2], c[3]
    local bx, by = ax + DV[side][1], ay + DV[side][2]
    local ok = self:free(ax, ay) and self:free(bx, by)
    -- ni le bras ni le coffre à côté d'un raccord (un tuyau y viendra)
    if ok then
      for _, t in ipairs({ { ax, ay }, { bx, by } }) do
        for _, d in ipairs(DIRS) do
          local r = self.rsv[tkey(t[1] + DV[d][1], t[2] + DV[d][2])]
          if r ~= nil then ok = false end
        end
      end
    end
    if ok then
      -- bras « dirigé vers d » : prend en d, dépose à l'opposé (convention de shared/team/modules.lua)
      local dir = into and side or ((side + 4) % 8)
      self:put(self.req.arm, ax + 0.5, ay + 0.5, dir, { role = into and "bras-entree" or "bras-sortie" })
      self:put(self.req.chest, bx + 0.5, by + 0.5, 0, { role = into and "quai" or "sortie" })
      if into then self.quais[#self.quais + 1] = { x = bx + 0.5, y = by + 0.5, item = item }
      else self.outs[#self.outs + 1] = { x = bx + 0.5, y = by + 0.5, item = item } end
      return true
    end
  end
  return false
end

--- Poteaux : couvrir chaque entité électrique, puis relier tous les poteaux entre eux et au réseau.
function Site:power(electric)
  local pole = self.req.poles
  local s, wire = pole.supply, pole.wire
  local poles = {}
  local function covers(px, py, ent)
    local e = self.req.ents[ent.name] or { w = 1, h = 1 }
    local x0, y0, x1, y1 = rect_of(e, ent.x, ent.y, ent.dir)
    return px + s > x0 and px - s < x1 + 1 and py + s > y0 and py - s < y1 + 1
  end
  local function covered(ent)
    for _, p in ipairs(poles) do if covers(p.x, p.y, ent) then return true end end
    return false
  end
  local function try_put(px, py)
    local tx, ty = math.floor(px), math.floor(py)
    if not self:free(tx, ty) then return nil end
    -- un poteau ne touche aucun raccord (il n'est pas une entité à fluide : aucun risque, mais la tuile est au tuyau)
    if self.rsv[tkey(tx, ty)] ~= nil then return nil end
    local ent = self:put(pole.name, tx + 0.5, ty + 0.5, 0, { role = "poteau" })
    poles[#poles + 1] = ent
    return ent
  end
  for _, ent in ipairs(electric) do
    if not covered(ent) then
      local e = self.req.ents[ent.name] or { w = 1, h = 1 }
      local x0, y0, x1, y1 = rect_of(e, ent.x, ent.y, ent.dir)
      local best, bn
      for ty = y0 - 1, y1 + 1 do
        for tx = x0 - 1, x1 + 1 do
          if (tx < x0 or tx > x1 or ty < y0 or ty > y1) and self:free(tx, ty) and self.rsv[tkey(tx, ty)] == nil then
            local n = 0
            for _, o in ipairs(electric) do if not covered(o) and covers(tx + 0.5, ty + 0.5, o) then n = n + 1 end end
            if not bn or n > bn then best, bn = { tx, ty }, n end
          end
        end
      end
      if not best then return nil, "poteau : aucune place autour de " .. ent.name end
      try_put(best[1] + 0.5, best[2] + 0.5)
    end
  end
  -- relier : arbre couvrant, chaque composante rejoint la plus proche par une chaîne de relais
  local function d2(a, b) return (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 end
  -- Relais de `a` à `b` : d'abord en ligne droite (un relais tous les (wire - 1) tuiles, sur la tuile libre la plus proche,
  -- 4 tuiles au plus de côté) ; si la ligne droite bute (falaise, eau, bâtiments), A* sur les tuiles libres (Fl.pole_route).
  -- Rien n'est posé tant que la liste n'est pas complète (un essai raté ne laisse aucun poteau perdu).
  local function straight(a, b)
    local dist = math.sqrt(d2(a, b))
    local steps = math.ceil(dist / (wire - 1))
    local prev = a
    local out = {}
    for i = 1, steps - 1 do
      local x = a.x + (b.x - a.x) * i / steps
      local y = a.y + (b.y - a.y) * i / steps
      local done = nil
      for r = 0, 4 do
        for dy = -r, r do
          for dx = -r, r do
            if not done and math.max(math.abs(dx), math.abs(dy)) == r then
              local tx, ty = math.floor(x) + dx, math.floor(y) + dy
              local c = { x = tx + 0.5, y = ty + 0.5 }
              if d2(c, prev) <= wire * wire and self:free(tx, ty) and self.rsv[tkey(tx, ty)] == nil then done = c end
            end
          end
        end
      end
      if not done then return nil end
      out[#out + 1] = done
      prev = done
    end
    if d2(prev, b) > wire * wire then return nil end
    return out
  end
  local function relay(a, b)
    local pos = straight(a, b)
    if not pos then
      pos = Fl.pole_route(a, b, wire, function(tx, ty) return self:free(tx, ty) and self.rsv[tkey(tx, ty)] == nil end,
        Fl.POLE_ASTAR_MAX)
    end
    if not pos then return nil end
    local n = 0
    for _, c in ipairs(pos) do
      local done = try_put(c.x, c.y)
      if not done then return nil end
      done.role = "liaison"
      n = n + 1
    end
    return n
  end
  local comp = {}
  for i = 1, #poles do comp[i] = i end
  local function find(i) while comp[i] ~= i do i = comp[i] end return i end
  for i = 1, #poles do
    for j = i + 1, #poles do
      if d2(poles[i], poles[j]) <= wire * wire then comp[find(j)] = find(i) end
    end
  end
  local guard = 0
  while true do
    guard = guard + 1
    if guard > 64 then return nil, "poteaux : trop de composantes" end
    local roots = {}
    for i = 1, #poles do roots[find(i)] = true end
    local rl = sorted_keys(roots)
    if #rl <= 1 then break end
    -- composante de la racine la plus petite : sa paire la plus proche dans une autre composante
    local r0 = rl[1]
    local best, bi, bj
    for i = 1, #poles do
      if find(i) == r0 then
        for j = 1, #poles do
          if find(j) ~= r0 then
            local d = d2(poles[i], poles[j])
            if not best or d < best then best, bi, bj = d, i, j end
          end
        end
      end
    end
    local before = #poles
    if not relay(poles[bi], poles[bj]) then return nil, "poteaux : liaison interne impossible" end
    for k = before + 1, #poles do comp[k] = k end
    for k = before + 1, #poles do
      for j = 1, #poles do if j ~= k and d2(poles[k], poles[j]) <= wire * wire then comp[find(k)] = find(j) end end
    end
    comp[find(bj)] = find(bi)
  end
  local line = 0
  if self.req.network then
    local net = { x = self.req.network.x, y = self.req.network.y }
    local best, bp
    for _, p in ipairs(poles) do
      local d = d2(p, net)
      if not best or d < best then best, bp = d, p end
    end
    if bp and best > wire * wire then
      if math.sqrt(best) > Fl.POLE_LINE_MAX then return nil, "reseau trop loin (" .. math.floor(math.sqrt(best)) .. " tuiles)" end
      local n = relay(bp, net)
      if not n then return nil, "ligne de poteaux jusqu'au reseau impossible" end
      line = n
    end
  end
  return #poles, line
end

local function layout_once(req, shift)
  local s = new_site(req)
  Fl.last_site = s
  local ch = req.chain
  local origin = req.origin
  -- 1. Extracteurs centrés sur les puits (les plus proches de l'origine).
  local extractors = {}
  local need_extract = false
  for _, fl in ipairs(sorted_keys(ch.sources)) do if ch.sources[fl] == "extract" then need_extract = fl end end
  if need_extract then
    local wells = {}
    for _, w in ipairs(req.wells or {}) do wells[#wells + 1] = w end
    table.sort(wells, function(a, b)
      local da = (a.x - origin.x) ^ 2 + (a.y - origin.y) ^ 2
      local db = (b.x - origin.x) ^ 2 + (b.y - origin.y) ^ 2
      if da ~= db then return da < db end
      if a.y ~= b.y then return a.y < b.y end
      return a.x < b.x
    end)
    local ename = req.extractor
    local e = req.ents[ename]
    for _, w in ipairs(wells) do
      if #extractors >= (req.n_extract or Fl.EXTRACTORS) then break end
      local x0, y0, x1, y1 = rect_of(e, w.x, w.y, 0)
      if s:rect_free(x0, y0, x1, y1) then
        -- direction : le raccord de sortie libre le plus proche de l'origine
        local bd, bdist
        for _, d in ipairs(DIRS) do
          local ent = { name = ename, x = w.x, y = w.y, dir = d }
          for _, c in ipairs(s:conns(ent)) do
            if s:free(c.tx, c.ty) then
              local dd = (c.tx - origin.x) ^ 2 + (c.ty - origin.y) ^ 2
              if not bdist or dd < bdist then bd, bdist = d, dd end
            end
          end
        end
        if bd then
          local ent = s:put(ename, w.x, w.y, bd, { role = "extracteur", fluid = need_extract })
          local map = {}
          for bi, b in ipairs(e.boxes) do if b.type ~= "input" then map[bi] = need_extract end end
          s:reserve_conns(ent, map)
          extractors[#extractors + 1] = ent
        end
      end
    end
    if #extractors == 0 then return nil, "aucun puits libre pour l'extracteur" end
  end
  -- 2. Pompes de rive : candidates seulement. La place est choisie APRÈS les machines (la rive la plus proche du consommateur
  -- du fluide) et essayée une à une, avec retour en arrière si son tuyau ne se trace pas (sans tuyau souterrain, un tuyau
  -- d'un autre fluide posé avant peut fermer la route : moteur réel, étang au gisement, 28/10).
  local pumps = {}
  local pump_cands = {}
  for _, fl in ipairs(sorted_keys(ch.sources)) do
    if ch.sources[fl] == "pompe" then
      local list = {}
      for _, p in ipairs(req.pumps or {}) do if p.fluid == fl then list[#list + 1] = p end end
      table.sort(list, function(a, b)
        local da = (a.x - origin.x) ^ 2 + (a.y - origin.y) ^ 2
        local db = (b.x - origin.x) ^ 2 + (b.y - origin.y) ^ 2
        if da ~= db then return da < db end
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
      end)
      if #list == 0 then return nil, "aucune rive pour la pompe de " .. fl end
      pump_cands[fl] = list
    end
  end
  -- 3. Cellules : machines (producteurs de fluide d'abord), raccords réservés, quais.
  local cells = {}
  local cx0, cy0 = origin.x, origin.y
  if req.block then
    -- place des machines imposée (près de la rive quand l'eau est loin du gisement : le brut vient par un long tuyau)
    cx0, cy0 = req.block.x, req.block.y
  elseif #extractors > 0 then
    local sx, sy = 0, 0
    for _, x in ipairs(extractors) do sx, sy = sx + x.x, sy + x.y end
    cx0, cy0 = sx / #extractors, sy / #extractors
  end
  cx0, cy0 = cx0 + shift[1], cy0 + shift[2]
  for i, c in ipairs(ch.cells) do
    local x, y = s:find_spot(c.machine, cx0, cy0)
    if not x then return nil, "aucune place pour " .. c.machine .. " (" .. c.recipe .. ")" end
    local m = s:put(c.machine, x, y, 0, { role = "machine", recipe = c.recipe })
    local fin = {}
    for _, f in ipairs(c.fin) do fin[#fin + 1] = f.fluid end
    local map = assign_boxes(req.ents[c.machine], fin, c.fout and { c.fout } or {})
    s:reserve_conns(m, map)
    cells[i] = { cell = c, ent = m, map = map }
  end
  for _, cc in ipairs(cells) do
    for _, it in ipairs(cc.cell.sin) do
      if not s:quai(cc.ent, it, true) then return nil, "quai d'entree impossible (" .. it .. ")" end
    end
    if cc.cell.sout then
      if not s:quai(cc.ent, cc.cell.sout, false) then return nil, "quai de sortie impossible (" .. cc.cell.sout .. ")" end
    end
  end
  -- 4. Tuyaux : chaque raccord d'un fluide rejoint le réseau de ce fluide (source d'abord).
  local nets = {} -- [fluide] = { [clé] = vrai } : tuiles déjà au réseau (raccords de la source, tuyaux posés)
  local function add_net(fl, tx, ty)
    nets[fl] = nets[fl] or {}
    nets[fl][tkey(tx, ty)] = true
  end
  local function join(fl, conns)
    -- premier raccord : amorce le réseau ; les suivants le rejoignent
    for _, c in ipairs(conns) do
      if not nets[fl] or next(nets[fl]) == nil then
        add_net(fl, c.tx, c.ty)
        if not s.tube[tkey(c.tx, c.ty)] then s.tube[tkey(c.tx, c.ty)] = fl; s.npipes = s.npipes + 1 end
      elseif not nets[fl][tkey(c.tx, c.ty)] then
        local n = s:route(c.tx, c.ty, nets[fl], fl)
        if not n then return false, c end
        -- le réseau grandit des tuyaux posés
        for _, k in ipairs(sorted_keys(s.tube)) do if s.tube[k] == fl then nets[fl][k] = true end end
      end
    end
    return true
  end
  local function conns_of(ent, fl)
    local out = {}
    for _, c in ipairs(s:conns(ent)) do if c.fluid == fl then out[#out + 1] = c end end
    return out
  end
  -- a. liaisons INTERNES d'abord (courtes) : chaque fluide produit par une cellule rejoint ses consommateurs
  for _, cc in ipairs(cells) do
    local fo = cc.cell.fout
    if fo then
      local ok, c = join(fo, conns_of(cc.ent, fo))
      if not ok then return nil, string.format("tuyau de %s depuis %s impossible (raccord %d,%d)", fo, cc.ent.name, c.tx, c.ty) end
      for _, dd in ipairs(cells) do
        for _, f in ipairs(dd.cell.fin) do
          if f.fluid == fo then
            local ok2, c2 = join(fo, conns_of(dd.ent, fo))
            if not ok2 then return nil, string.format("tuyau de %s vers %s impossible (raccord %d,%d)", fo, dd.ent.name, c2.tx, c2.ty) end
          end
        end
      end
    end
  end
  -- b. sources (puits, rive) : les consommateurs d'abord (réseau amorcé au site), puis la source le rejoint ; la source la
  -- plus PROCHE des machines d'abord (sans tuyau souterrain, un long tuyau tracé avant couperait la route d'un court :
  -- moteur réel, petrole-site 271828182 : brut sur 155 tuiles tracé avant l'eau de la rive voisine, eau impossible)
  local function src_dist(fl)
    local best = math.huge
    local list = {}
    for _, x in ipairs(extractors) do if x.fluid == fl then list[#list + 1] = x end end
    if pump_cands[fl] then list[#list + 1] = pump_cands[fl][1] end
    for _, x in ipairs(list) do
      local d = math.abs(x.x - cx0) + math.abs(x.y - cy0)
      if d < best then best = d end
    end
    return best
  end
  local src_order = sorted_keys(ch.sources)
  table.sort(src_order, function(a, b)
    local da, db = src_dist(a), src_dist(b)
    if da ~= db then return da < db end
    return a < b
  end)
  local function route_sources(order_list)
  for _, fl in ipairs(order_list) do
    for _, cc in ipairs(cells) do
      for _, f in ipairs(cc.cell.fin) do
        if f.fluid == fl then
          local ok, c = join(fl, conns_of(cc.ent, fl))
          if not ok then return false, string.format("tuyau de %s vers %s impossible (raccord %d,%d)", fl, cc.ent.name, c.tx, c.ty) end
        end
      end
    end
    for _, x in ipairs(extractors) do
      if x.fluid == fl then
        local cs = conns_of(x, fl)
        if not join(fl, { cs[1] }) then return false, "tuyau d'un extracteur impossible" end
      end
    end
    if pump_cands[fl] then
      -- rives triées par la distance au consommateur du fluide (raccords d'entrée des machines), puis par le rang de départ
      local targets = {}
      for _, cc in ipairs(cells) do for _, c in ipairs(conns_of(cc.ent, fl)) do targets[#targets + 1] = c end end
      local order = {}
      for i, p in ipairs(pump_cands[fl]) do
        local d = math.huge
        for _, t in ipairs(targets) do d = math.min(d, math.abs(p.x - t.tx) + math.abs(p.y - t.ty)) end
        order[#order + 1] = { p = p, d = d, i = i }
      end
      table.sort(order, function(a, b) if a.d ~= b.d then return a.d < b.d end return a.i < b.i end)
      local placed, last_why = false, nil
      for _, it in ipairs(order) do
        local p = it.p
        local pe = req.ents[p.name]
        local px0, py0, px1, py1 = rect_of(pe, p.x, p.y, p.dir)
        if s:rect_free(px0, py0, px1, py1) then
          local snap = s:snapshot(nets)
          local ent = s:put(p.name, p.x, p.y, p.dir, { role = "pompe", fluid = fl })
          local map = {}
          for bi in ipairs(pe.boxes or {}) do map[bi] = fl end
          s:reserve_conns(ent, map)
          local pc = conns_of(ent, fl)
          if join(fl, pc) then
            pumps[fl] = ent
            placed = true
            break
          end
          local c = pc[1]
          last_why = string.format("tuyau de la pompe impossible (%s) : pompe (%.1f, %.1f) dir %d, raccord %s", fl, p.x, p.y, p.dir or 0,
            c and string.format("(%d, %d) %s", c.tx, c.ty, s:pipe_ok(c.tx, c.ty, fl) and "libre" or "bloque") or "absent")
          s:restore(snap, nets)
        end
      end
      if not placed then return false, last_why or ("aucune rive libre pour la pompe de " .. fl) end
    end
  end
  return true
  end
  -- Sans tuyau souterrain, l'ORDRE des tracés décide : un tuyau long tracé d'abord peut sceller l'entrée d'une machine. L'ordre
  -- par distance est essayé d'abord ; si un tuyau ne se trace pas, retour à l'état d'avant les sources et ordre suivant
  -- (permutations dans l'ordre lexicographique des positions, 4 sources au plus).
  local orders = { src_order }
  if #src_order >= 2 and #src_order <= 4 then
    local seen = { [table.concat(src_order, "|")] = true }
    local function perm(prefix, rest)
      if #rest == 0 then
        local key = table.concat(prefix, "|")
        if not seen[key] then seen[key] = true; orders[#orders + 1] = { table.unpack(prefix) } end
        return
      end
      for i = 1, #rest do
        local nrest = {}
        for j, v in ipairs(rest) do if j ~= i then nrest[#nrest + 1] = v end end
        local np = { table.unpack(prefix) }
        np[#np + 1] = rest[i]
        perm(np, nrest)
      end
    end
    perm({}, src_order)
  end
  local routed, why_route
  local base = s:snapshot(nets)
  for i, order_list in ipairs(orders) do
    local ok, why = route_sources(order_list)
    if ok then routed = true break end
    why_route = why_route or why
    if i < #orders then
      s:restore(base, nets)
      for k in pairs(pumps) do pumps[k] = nil end
      base = s:snapshot(nets)
    end
  end
  if not routed then return nil, why_route end
  for _, k in ipairs(sorted_keys(s.tube)) do
    local tx, ty = math.floor(k / 2097152) - 1048576, k % 2097152 - 1048576
    s:put(req.conduit, tx + 0.5, ty + 0.5, 0, { role = "tuyau", fluid = s.tube[k] })
  end
  -- 5. Électricité.
  local electric = {}
  for _, e in ipairs(s.ents) do
    local p = req.ents[e.name]
    if p and p.electric then electric[#electric + 1] = e end
  end
  local npoles, line = 0, 0
  if #electric > 0 then
    if not req.poles then return nil, "aucun poteau" end
    local a, b = s:power(electric)
    if not a then return nil, b end
    npoles, line = a, b
  end
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, e in ipairs(s.ents) do
    if e.role ~= "liaison" then
      x0, y0 = math.min(x0, math.floor(e.x)), math.min(y0, math.floor(e.y))
      x1, y1 = math.max(x1, math.floor(e.x)), math.max(y1, math.floor(e.y))
    end
  end
  return { ents = s.ents, quais = s.quais, outs = s.outs, box = { x0, y0, x1, y1 }, pipes = s.npipes, poles = npoles,
    line = line, extractors = #extractors }
end

--- Décalages essayés de la place des machines quand un tuyau ne se trace pas (sans tuyau souterrain, la disposition décide
--- des croisements impossibles) : l'écart est de Fl.SHIFT tuiles, dans un ordre fixe.
Fl.SHIFT = 14
Fl.LAYOUT_BUDGET = 80000 -- nœuds d'A* des tuyaux au plus pour toutes les tentatives d'une implantation

function Fl.layout(req)
  local k = Fl.SHIFT
  local shifts = { { 0, 0 }, { k, 0 }, { -k, 0 }, { 0, k }, { 0, -k }, { k, k }, { -k, -k }, { k, -k }, { -k, k } }
  req.spent = 0
  local first_why
  for _, sh in ipairs(shifts) do
    local lay, why = layout_once(req, sh)
    if lay then return lay end
    first_why = first_why or why
    -- le refus n'est pas une affaire de tuyau (aucune place, aucun puits, poteaux…) ou le budget est épuisé : inutile de continuer
    if req.spent > Fl.LAYOUT_BUDGET or not (tostring(why):find("tuyau", 1, true)) then break end
  end
  return nil, first_why
end

--- Contrôle d'une implantation (tests, journal) : réseaux de tuyaux (composantes 4-connexes) d'un seul fluide, chaque
--- raccord réservé couvert par un tuyau de son fluide. Rend (vrai) ou (faux, raison).
function Fl.check(lay, ents)
  local tubes = {}
  for _, e in ipairs(lay.ents) do
    if e.role == "tuyau" then tubes[tkey(math.floor(e.x), math.floor(e.y))] = e.fluid end
  end
  for _, k in ipairs(sorted_keys(tubes)) do
    local tx, ty = math.floor(k / 2097152) - 1048576, k % 2097152 - 1048576
    for _, d in ipairs(DIRS) do
      local nk = tkey(tx + DV[d][1], ty + DV[d][2])
      if tubes[nk] and tubes[nk] ~= tubes[k] then return false, string.format("deux fluides se touchent en %d,%d", tx, ty) end
    end
  end
  for _, e in ipairs(lay.ents) do
    local p = ents[e.name]
    if p and p.boxes and (e.role == "machine" or e.role == "extracteur" or e.role == "pompe") then
      local any = false
      for _, b in ipairs(p.boxes) do
        for _, pos in ipairs((b.conns and b.conns[e.dir]) or {}) do
          local tx, ty = conn_tile(e.x, e.y, pos)
          local fl = tubes[tkey(tx, ty)]
          if fl then any = true end
          if fl and e.fluid and e.role ~= "machine" and fl ~= e.fluid then return false, "fluide etranger a " .. e.name end
        end
      end
      if not any then return false, e.name .. " sans aucun tuyau" end
    end
  end
  return true
end

return Fl
