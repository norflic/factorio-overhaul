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
Fl.ASTAR_MAX = 30000    -- nœuds développés au plus par tuyau
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
      if n > Fl.ASTAR_MAX then return nil end
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
  local function relay(a, b)
    -- relais tous les (wire - 1) tuiles sur le segment, chacun sur la tuile libre la plus proche (2 tuiles au plus)
    local dist = math.sqrt(d2(a, b))
    local steps = math.ceil(dist / (wire - 1))
    local prev = a
    local n = 0
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
              if d2(c, prev) <= wire * wire and self:free(tx, ty) and self.rsv[tkey(tx, ty)] == nil then
                done = try_put(c.x, c.y)
                if done then done.role = "liaison" end
              end
            end
          end
        end
      end
      if not done then return nil end
      prev = done
      n = n + 1
    end
    if d2(prev, b) > wire * wire then return nil end
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

function Fl.layout(req)
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
  -- 2. Pompes de rive.
  local pumps = {}
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
      local p = list[1]
      if not p then return nil, "aucune rive pour la pompe de " .. fl end
      local ent = s:put(p.name, p.x, p.y, p.dir, { role = "pompe", fluid = fl })
      local map = {}
      for bi in ipairs(req.ents[p.name].boxes or {}) do map[bi] = fl end
      s:reserve_conns(ent, map)
      pumps[fl] = ent
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
  -- b. sources (puits, rive) : les consommateurs d'abord (réseau amorcé au site), puis la source le rejoint
  for _, fl in ipairs(sorted_keys(ch.sources)) do
    for _, cc in ipairs(cells) do
      for _, f in ipairs(cc.cell.fin) do
        if f.fluid == fl then
          local ok, c = join(fl, conns_of(cc.ent, fl))
          if not ok then return nil, string.format("tuyau de %s vers %s impossible (raccord %d,%d)", fl, cc.ent.name, c.tx, c.ty) end
        end
      end
    end
    for _, x in ipairs(extractors) do
      if x.fluid == fl then
        local cs = conns_of(x, fl)
        if not join(fl, { cs[1] }) then return nil, "tuyau d'un extracteur impossible" end
      end
    end
    if pumps[fl] then
      local pc = conns_of(pumps[fl], fl)
      if not join(fl, pc) then
        local c = pc[1]
        return nil, string.format("tuyau de la pompe impossible (%s) : pompe (%.1f, %.1f) dir %d, raccord %s", fl,
          pumps[fl].x, pumps[fl].y, pumps[fl].dir or 0,
          c and string.format("(%d, %d) %s", c.tx, c.ty, s:pipe_ok(c.tx, c.ty, fl) and "libre" or "bloque") or "absent")
      end
    end
  end
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
