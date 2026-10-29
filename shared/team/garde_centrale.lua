--[[
  Lot CENTRALE-GARDE : tourelles ARMÉES autour d'une centrale d'équipe finie. Règle PURE (aucune API Factorio, aucun nom d'objet),
  déterministe, testée hors jeu par tests/garde_centrale_test.lua (avec mutants).

  Constat (instrument [FO-CENTRALE-MORT], 29/10, 7 incidents) : toutes les centrales perdues le sont par de petits biters ; 5 sur 7 n'avaient
  aucune tourelle armée à moins de 25 tuiles, sites à 59-119 tuiles du QG.

  Données lues par l'appelant : pieces = { { x, y } } (chaudières, machines à vapeur, pompes) ; turrets = { { x, y, rounds } } (tourelles de
  l'équipe) ; range = portée de la tourelle lue au prototype ; low = seuil « armée » (munitions).
  - K (G.wanted) : tourelles armées voulues, selon le nombre de chaudières (une de plus qu'une chaudière, au moins G.MIN, au plus G.MAX) ;
  - une tourelle GARDE la centrale si elle est armée et si TOUTES les pièces sont à moins de `range` d'elle (G.guards) ;
  - G.sites : emplacements candidats, anneau autour du centre des pièces, rayon pris pour que toute pièce reste à portée ;
  - G.covers : une position de pose est acceptée si toutes les pièces sont à portée.
]]
local G = {}

G.MIN = 2
G.MAX = 6
G.MARGIN = 1   -- tuile gardée entre la portée et la pièce la plus éloignée

--- Tourelles armées voulues pour `boilers` chaudières.
function G.wanted(boilers)
  local k = 1 + (boilers or 1)
  if k < G.MIN then k = G.MIN end
  if k > G.MAX then k = G.MAX end
  return k
end

local function dist2(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return dx * dx + dy * dy end

--- Toutes les pièces à moins de `range` de (x, y) ?
function G.covers(pieces, x, y, range)
  if not pieces or #pieces == 0 then return false end
  local r2 = range * range
  for _, p in ipairs(pieces) do
    if dist2(p.x, p.y, x, y) > r2 then return false end
  end
  return true
end

--- Nombre de tourelles ARMÉES qui gardent la centrale (toutes les pièces à portée).
function G.guards(pieces, turrets, range, low)
  local n = 0
  for _, t in ipairs(turrets or {}) do
    if (t.rounds or 0) >= low and G.covers(pieces, t.x, t.y, range) then n = n + 1 end
  end
  return n
end

--- Centre des pièces et distance de la plus éloignée.
function G.center(pieces)
  local sx, sy = 0, 0
  for _, p in ipairs(pieces) do sx = sx + p.x; sy = sy + p.y end
  local n = #pieces
  local cx, cy = sx / n, sy / n
  local far = 0
  for _, p in ipairs(pieces) do
    local d = dist2(p.x, p.y, cx, cy)
    if d > far then far = d end
  end
  return cx, cy, math.sqrt(far)
end

-- Directions de l'anneau, de la plus utile à la moins utile (quatre côtés, puis les diagonales) ; entiers : pas de trigonométrie.
local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 } }

--- Emplacements candidats (au plus n) : sur un anneau de rayon rho autour du centre. rho = portée - pièce la plus éloignée - marge, au plus
--- G.RHO_MAX, au moins 3. Rend la liste { { x, y }, ... } et le centre { x, y }.
G.RHO_MAX = 9
function G.sites(pieces, range, n)
  if not pieces or #pieces == 0 then return {}, nil end
  local cx, cy, far = G.center(pieces)
  local rho = range - far - G.MARGIN
  if rho > G.RHO_MAX then rho = G.RHO_MAX end
  if rho < 3 then rho = 3 end
  local out = {}
  for i = 1, math.min(n or 4, #DIRS) do
    local d = DIRS[i]
    local k = (d[1] ~= 0 and d[2] ~= 0) and 0.7 or 1 -- diagonale : environ rho / racine de 2
    out[#out + 1] = { x = math.floor(cx + d[1] * rho * k + 0.5), y = math.floor(cy + d[2] * rho * k + 0.5) }
  end
  return out, { x = cx, y = cy }
end

--- Besoin d'une centrale : { wanted, have, missing, sites, center } ou nil sans pièce.
function G.need(pieces, boilers, turrets, range, low)
  if not pieces or #pieces == 0 then return nil end
  local want = G.wanted(boilers)
  local have = G.guards(pieces, turrets, range, low)
  local missing = want - have
  if missing < 0 then missing = 0 end
  local sites, center = G.sites(pieces, range, math.max(want, missing + 2))
  return { wanted = want, have = have, missing = missing, sites = sites, center = center }
end

return G
