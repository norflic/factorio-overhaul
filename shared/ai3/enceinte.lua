--[[
  Lot S42-DEFENSE (chantier 6.2 du DC : murs). TRACÉ DE L'ENCEINTE. PUR (aucune API Factorio, aucun nom d'objet), testé hors jeu par
  tests/s42_defense_test.lua. NON CÂBLÉ en jeu dans ce lot (règle et test seulement ; plan du câblage dans le compte rendu du lot).

  Règle :
    * l'emprise = l'UNION des rectangles de la base (QG, rangées, centrale) ET de ses gisements, chacun gonflé de `margin` tuiles : les murs
      passent à l'EXTÉRIEUR des gisements (jamais sur le minerai) et laissent une bande intérieure pour les tourelles ;
    * le mur = les cases HORS de l'emprise qui la touchent (8 voisines), atteintes depuis l'extérieur : un anneau fermé, d'un seul tenant
      par les côtés (aucun passage en diagonale) ; une cour intérieure fermée ne reçoit pas de mur ;
    * les portes = les cases de l'anneau sur la colonne et la ligne du centre (largeur En.GATE_W) : les PNJ sortent par les quatre côtés ;
    * les tourelles = sur l'anneau intérieur, à En.TURRET_GAP cases du mur, une tous les En.TURRET_STEP cases le long des côtés droits ;
    * `blocked(x, y)` (eau, falaise : donné par l'appelant) retire une case du tracé : l'obstacle naturel fait le mur ;
    * reconstruction : En.missing(plan, present) rend les cases du tracé qui ne sont plus posées, dans l'ordre du tracé.
  Sorties triées (y puis x), entiers, aucun hasard, aucun pairs décisionnel. Emprise bornée (En.MAX_SPAN) : au-delà, nil et la raison.
]]

local En = {}

En.MARGIN = 6        -- tuiles entre l'emprise utile (bâtiments, minerai) et le mur : bande des tourelles
En.TURRET_GAP = 3    -- tuiles entre le mur et la ligne des tourelles
En.TURRET_STEP = 8   -- une tourelle toutes les 8 cases le long d'un côté
En.GATE_W = 2        -- largeur d'une porte
En.MAX_SPAN = 600    -- côté de l'emprise au plus (tuiles)

local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge and v or nil end

local function by_yx(a, b)
  if a.y ~= b.y then return a.y < b.y end
  return a.x < b.x
end

--- Grille de l'union des rectangles gonflés de m. Rend { x0, y0, w, h, inside = { [clé] = true } } ou nil, raison.
local function grid_of(boxes, m)
  local x1, y1, x2, y2
  local rects = {}
  for _, b in ipairs(boxes or {}) do
    local ax, ay, bx, by = num(b.x1), num(b.y1), num(b.x2), num(b.y2)
    if ax and ay and bx and by and bx >= ax and by >= ay then
      local r = { math.floor(ax) - m, math.floor(ay) - m, math.ceil(bx) - 1 + m, math.ceil(by) - 1 + m } -- cases entières, bornes incluses
      if r[3] < r[1] then r[3] = r[1] end
      if r[4] < r[2] then r[4] = r[2] end
      rects[#rects + 1] = r
      if not x1 or r[1] < x1 then x1 = r[1] end
      if not y1 or r[2] < y1 then y1 = r[2] end
      if not x2 or r[3] > x2 then x2 = r[3] end
      if not y2 or r[4] > y2 then y2 = r[4] end
    end
  end
  if #rects == 0 then return nil, "aucun rectangle" end
  local g = { x0 = x1 - 2, y0 = y1 - 2, w = x2 - x1 + 5, h = y2 - y1 + 5, inside = {} }
  if g.w > En.MAX_SPAN or g.h > En.MAX_SPAN then return nil, "emprise trop grande : " .. g.w .. " x " .. g.h end
  for _, r in ipairs(rects) do
    for y = r[2], r[4] do
      local row = (y - g.y0) * g.w
      for x = r[1], r[3] do g.inside[row + (x - g.x0)] = true end
    end
  end
  return g
end

local function inside(g, x, y)
  local cx, cy = x - g.x0, y - g.y0
  if cx < 0 or cy < 0 or cx >= g.w or cy >= g.h then return false end
  return g.inside[cy * g.w + cx] == true
end

--- Cases hors de l'emprise atteintes depuis le coin de la grille (remplissage par les côtés) : { [clé] = true }.
local function outside_of(g)
  local out, stack, n = { [0] = true }, { 0 }, 1
  while n > 0 do
    local k = stack[n]
    stack[n] = nil
    n = n - 1
    local cx, cy = k % g.w, math.floor(k / g.w)
    local function push(nx, ny)
      if nx < 0 or ny < 0 or nx >= g.w or ny >= g.h then return end
      local nk = ny * g.w + nx
      if out[nk] or g.inside[nk] then return end
      out[nk] = true
      n = n + 1
      stack[n] = nk
    end
    push(cx + 1, cy) push(cx - 1, cy) push(cx, cy + 1) push(cx, cy - 1)
  end
  return out
end

--- Anneau des cases hors de l'emprise `g`, atteintes de l'extérieur, qui la touchent (8 voisines). Liste triée { { x, y } }.
local function ring_of(g)
  local out = outside_of(g)
  local ring = {}
  for cy = 0, g.h - 1 do
    for cx = 0, g.w - 1 do
      if out[cy * g.w + cx] then
        local x, y = cx + g.x0, cy + g.y0
        local touch = false
        for dy = -1, 1 do
          for dx = -1, 1 do
            if (dx ~= 0 or dy ~= 0) and inside(g, x + dx, y + dy) then touch = true end
          end
        end
        if touch then ring[#ring + 1] = { x = x, y = y } end
      end
    end
  end
  return ring -- déjà en ordre y puis x
end

--- Le tracé. boxes = { { x1, y1, x2, y2 } } (bâtiments et gisements, en tuiles) ; opts = { margin, center = { x, y } (portes ; défaut :
--- centre de l'emprise), blocked = function(x, y) (case impossible : retirée), gates = false (aucune porte) }.
--- Rend { walls = { {x,y} }, gates = { {x,y} }, turrets = { {x,y} }, box = { x1, y1, x2, y2 } (emprise gonflée) } ou nil, raison.
function En.plan(boxes, opts)
  opts = opts or {}
  local m = math.floor(num(opts.margin) or En.MARGIN)
  if m < En.TURRET_GAP + 1 then m = En.TURRET_GAP + 1 end
  local g, why = grid_of(boxes, m)
  if not g then return nil, why end
  local blocked = type(opts.blocked) == "function" and opts.blocked or nil
  local cx = opts.center and num(opts.center.x) and math.floor(opts.center.x) or math.floor(g.x0 + g.w / 2)
  local cy = opts.center and num(opts.center.y) and math.floor(opts.center.y) or math.floor(g.y0 + g.h / 2)
  local plan = { walls = {}, gates = {}, turrets = {}, box = { x1 = g.x0 + 2, y1 = g.y0 + 2, x2 = g.x0 + g.w - 3, y2 = g.y0 + g.h - 3 } }
  for _, c in ipairs(ring_of(g)) do
    if not (blocked and blocked(c.x, c.y)) then
      local gate = opts.gates ~= false
        and ((c.x >= cx and c.x < cx + En.GATE_W) or (c.y >= cy and c.y < cy + En.GATE_W))
      if gate then plan.gates[#plan.gates + 1] = c else plan.walls[#plan.walls + 1] = c end
    end
  end
  -- Tourelles : anneau de l'emprise gonflée de (m − TURRET_GAP − 1), donc À L'INTÉRIEUR du mur, le long des côtés droits.
  local gi = grid_of(boxes, m - En.TURRET_GAP - 1)
  if gi then
    for _, c in ipairs(ring_of(gi)) do
      local horiz = inside(gi, c.x, c.y + 1) ~= inside(gi, c.x, c.y - 1)
      local vert = inside(gi, c.x + 1, c.y) ~= inside(gi, c.x - 1, c.y)
      if ((horiz and not vert and c.x % En.TURRET_STEP == 0) or (vert and not horiz and c.y % En.TURRET_STEP == 0))
        and not (blocked and blocked(c.x, c.y)) then
        plan.turrets[#plan.turrets + 1] = c
      end
    end
  end
  table.sort(plan.walls, by_yx) table.sort(plan.gates, by_yx) table.sort(plan.turrets, by_yx)
  return plan
end

--- Reconstruction : cases de `list` (murs, portes ou tourelles du tracé) que `present(x, y)` ne trouve plus, dans l'ordre du tracé ;
--- au plus `max` (nil : toutes).
function En.missing(list, present, max)
  local out = {}
  for _, c in ipairs(list or {}) do
    if not present(c.x, c.y) then
      out[#out + 1] = c
      if max and #out >= max then break end
    end
  end
  return out
end

--- Le tracé est-il fermé ? Vrai si aucune case de l'emprise n'est atteinte depuis l'extérieur sans traverser un mur ou une porte (côtés
--- ET diagonales : un déchiqueteur ne passe pas entre deux murs en coin, mais la preuve est faite au plus strict). Sert au test et au
--- câblage (ne pas compter sur une enceinte ouverte). `extra(x, y)` : obstacle naturel compté comme fermé.
function En.closed(boxes, plan, opts)
  opts = opts or {}
  local m = math.floor(num(opts.margin) or En.MARGIN)
  if m < En.TURRET_GAP + 1 then m = En.TURRET_GAP + 1 end
  local g = grid_of(boxes, m)
  if not (g and plan) then return false end
  local wall = {}
  for _, l in ipairs({ plan.walls, plan.gates }) do
    for _, c in ipairs(l) do wall[(c.y - g.y0) * g.w + (c.x - g.x0)] = true end
  end
  local seen, stack, n = { [0] = true }, { 0 }, 1
  while n > 0 do
    local k = stack[n]
    stack[n] = nil
    n = n - 1
    local px, py = k % g.w, math.floor(k / g.w)
    for dy = -1, 1 do
      for dx = -1, 1 do
        local nx, ny = px + dx, py + dy
        if (dx ~= 0 or dy ~= 0) and nx >= 0 and ny >= 0 and nx < g.w and ny < g.h then
          local nk = ny * g.w + nx
          if not seen[nk] and not wall[nk] and not (opts.extra and opts.extra(nx + g.x0, ny + g.y0)) then
            if g.inside[nk] then return false end
            seen[nk] = true
            n = n + 1
            stack[n] = nk
          end
        end
      end
    end
  end
  return true
end

return En
