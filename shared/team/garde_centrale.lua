--[[
  Lot CENTRALE-GARDE : tourelles ARMÉES autour d'une centrale d'équipe finie. Règle PURE (aucune API Factorio, aucun nom d'objet),
  déterministe, testée hors jeu par tests/garde_centrale_test.lua (avec mutants).

  Constat (instrument [FO-CENTRALE-MORT], 29/10, 7 incidents) : toutes les centrales perdues le sont par de petits biters ; 5 sur 7 n'avaient
  aucune tourelle armée à moins de 25 tuiles, sites à 59-119 tuiles du QG.

  Données lues par l'appelant : pieces = { { x, y } } (chaudières, machines à vapeur, pompes) ; turrets = { { x, y, rounds } } (tourelles de
  l'équipe) ; range = portée de la tourelle lue au prototype ; low = seuil « armée » (munitions).
  - K (G.wanted) : tourelles armées voulues, selon le nombre de chaudières (une de plus qu'une chaudière, au moins G.MIN, au plus G.MAX) ;
  - une tourelle GARDE la centrale si elle est armée et si TOUTES les pièces sont à moins de `range` d'elle (G.guards) ; une tourelle
    à portée de toutes les pièces OCCUPE une place même vide (G.near) : sous 8 chargeurs elle n'est plus armée mais on la ravitaille
    (groupe « oplant »), on n'en pose pas une de plus par-dessus (borne de la sur-pose, correctif du 2e relecteur) ;
  - une centrale trop étendue pour qu'un même point voie toutes ses pièces à portée est INFAISABLE (G.feasible) : aucune pose ;
  - G.sites : emplacements candidats, anneau autour du centre des pièces, rayon pris pour que toute pièce reste à portée ;
  - G.covers : une position de pose est acceptée si toutes les pièces sont à portée.

  Lot GARDE-MULTI (plusieurs centrales, ajoutées par CORR-ENERGIE) : CHAQUE centrale finie (la principale et les supplémentaires) est un
  poste à garder. G.plan lit la liste des centrales et la liste commune des tourelles de l'équipe, et choisit LA centrale à garder
  maintenant : la moins gardée d'abord (places occupées / tourelles voulues, la plus basse ; à égalité, moins de places occupées, puis
  l'ordre de la liste). Le budget est partagé : une seule tâche de garde est ouverte par équipe à la fois (le planificateur n'en ouvre
  qu'une, clé « fortify:plant »), et les tourelles de garde de toute l'équipe ne dépassent pas G.TEAM_MAX (comptées une fois même si une
  tourelle garde deux centrales voisines).
]]
local G = {}

G.MIN = 2
G.MAX = 6
G.MARGIN = 1   -- tuile gardée entre la portée et la pièce la plus éloignée
G.TEAM_MAX = 12 -- tourelles de garde de centrale, au plus, par équipe (toutes centrales confondues : 2 centrales à 6 au plus)

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

--- Nombre de tourelles à portée de toutes les pièces, armées ou non (places occupées).
function G.near(pieces, turrets, range)
  local n = 0
  for _, t in ipairs(turrets or {}) do
    if G.covers(pieces, t.x, t.y, range) then n = n + 1 end
  end
  return n
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
  if rho < 3 then rho = math.min(3, range - far - G.MARGIN) end -- jamais au-delà de ce que la portée permet (centrale presque infaisable)
  local out = {}
  for i = 1, math.min(n or 4, #DIRS) do
    local d = DIRS[i]
    local k = (d[1] ~= 0 and d[2] ~= 0) and 0.7 or 1 -- diagonale : environ rho / racine de 2
    out[#out + 1] = { x = math.floor(cx + d[1] * rho * k + 0.5), y = math.floor(cy + d[2] * rho * k + 0.5) }
  end
  return out, { x = cx, y = cy }
end

--- Un même point voit-il toutes les pièces à portée (avec la marge) ? Faux pour une centrale trop étendue.
function G.feasible(pieces, range)
  if not pieces or #pieces == 0 then return false end
  local _, _, far = G.center(pieces)
  return range - far - G.MARGIN >= 1
end

--- Besoin d'une centrale : { wanted, have (armées), near (places occupées), missing, sites, center } ou nil sans pièce ou si infaisable.
--- missing = wanted - near : une tourelle vide occupe sa place (elle est ravitaillée, pas remplacée).
function G.need(pieces, boilers, turrets, range, low)
  if not G.feasible(pieces, range) then return nil end
  local want = G.wanted(boilers)
  local have = G.guards(pieces, turrets, range, low)
  local near = G.near(pieces, turrets, range)
  local missing = want - near
  if missing < 0 then missing = 0 end
  local sites, center = G.sites(pieces, range, math.max(want, missing + 2))
  return { wanted = want, have = have, near = near, missing = missing, sites = sites, center = center }
end

--- Tourelles (armées ou non) à portée de toutes les pièces d'AU MOINS une centrale de la liste, chacune comptée une fois.
function G.near_any(plants, turrets, range)
  local n = 0
  for _, t in ipairs(turrets or {}) do
    for _, pl in ipairs(plants or {}) do
      if G.covers(pl.pieces, t.x, t.y, range) then n = n + 1; break end
    end
  end
  return n
end

--- Plan de garde de l'équipe : plants = { { id, pieces, boilers } } (centrales vivantes, dans l'ordre de la liste), turrets = tourelles de
--- l'équipe, cap = plafond de tourelles de garde de l'équipe (défaut G.TEAM_MAX). Rend { pick, rows, total, left } ou nil sans centrale
--- faisable. rows = { { id, need } } (need = G.need de la centrale, nil si infaisable) ; total = places occupées par l'équipe ;
--- left = places restantes sous le plafond ; pick = { id, need, missing, pieces } ou nil : la centrale à garder maintenant, `missing`
--- étant bornée par `left`. Rien à garder (tout est gardé) ou plafond atteint : pick = nil.
function G.plan(plants, turrets, range, low, cap)
  cap = cap or G.TEAM_MAX
  local rows, best = {}, nil
  for _, pl in ipairs(plants or {}) do
    local need = G.need(pl.pieces, pl.boilers, turrets, range, low)
    if need then
      local row = { id = pl.id, need = need, pieces = pl.pieces }
      rows[#rows + 1] = row
      -- la moins gardée : near/wanted le plus bas (produit en croix, pas de division), puis le moins de places occupées ; égalité : la première
      if need.missing > 0 then
        if not best then best = row
        else
          local a, b = need.near * best.need.wanted, best.need.near * need.wanted
          if a < b or (a == b and need.near < best.need.near) then best = row end
        end
      end
    end
  end
  if #rows == 0 then return nil end
  local total = G.near_any(plants, turrets, range)
  local left = cap - total
  if left < 0 then left = 0 end
  local pick = nil
  if best and left > 0 then
    pick = { id = best.id, need = best.need, pieces = best.pieces, missing = math.min(best.need.missing, left) }
  end
  return { pick = pick, rows = rows, total = total, left = left }
end

return G
