--[[
  CENTRALE LOINTAINE (lot PD-CENTRALE, décision du DC D-24 (1), 28/10 vers 7 h 50 : « si l'eau n'est pas utilisable, du coup
  il faut aller plus loin, évidemment. Si on pouvait avoir de l'eau [pompe] pour faire de l'électricité, bien, il faut avoir
  tout centrale plus loin » ; l'étang garanti (make_pond) est SUPPRIMÉ). RÈGLES PURES (aucune API du jeu ; testées hors jeu
  par tests/centrale_loin_test.lua) ; la lecture du moteur et la pose sont dans script/team/centrale_loin.lua.

  Quand aucun lot du treillis ne tient la centrale (pas de rive, ou une rive où la pompe ne tient pas) et que le treillis ne
  peut plus grandir, l'équipe cherche l'eau HORS du treillis, du secteur (64 × 64) le plus proche du QG au plus lointain
  (au plus Cl.MAX_DIST tuiles) ; dans un secteur, les rives (tuile de terre devant deux tuiles d'eau) du plus près du QG au
  plus loin ; le gabarit de la centrale est essayé dans un carré de Cl.WINDOW tuiles centré sur la rive. La centrale posée
  est reliée au carrefour de bord du treillis le plus proche par une ligne de poteaux tracée par recherche de chemin
  (shared/team/poteaux.lua) ; une ligne impossible ou trop longue écarte la rive (rive suivante au plan suivant).

  Déterminisme : tout est trié (distance, puis y, puis x ; secteurs : distance puis clé) ; aucune itération `pairs` dont
  l'ordre décide ; aucune trigonométrie (racine carrée seulement).
]]

local Cl = {}

-- Réglages du lot (jamais des noms d'objets du jeu).
Cl.SECTOR = 64            -- côté d'un secteur (même grille que la carte de connaissance, shared/ai3/carte.lua)
Cl.MAX_DIST = 512         -- secteurs dont le centre est à plus de 512 tuiles du QG : jamais candidats
Cl.WINDOW = 32            -- côté du carré d'essai du gabarit autour d'une rive (un lot de P.LOT = 24 tuiles et 4 de chaque côté)
Cl.SECTOR_MARGIN = 4      -- tuiles lues autour d'un secteur pour trouver ses rives (un lac au bord du secteur)
Cl.SHORE_GAP = 6          -- deux rives candidates d'un secteur sont à 6 tuiles au moins (Chebyshev)
Cl.SHORES_MAX = 12        -- rives candidates d'un secteur
Cl.FITS_PER_PASS = 4      -- gabarits essayés au moteur par passe de plan (un relevé de 32 × 32 chacun)
Cl.SECTORS_PER_PASS = 2   -- secteurs d'eau lus par passe de plan
Cl.PROBES_PER_PASS = 12   -- secteurs sondés (« y a-t-il de l'eau ? ») par passe, sans carte de connaissance
Cl.MAX_POLES = 80         -- poteaux de ligne au plus ; au-delà, la rive est écartée (« ligne trop longue »)
Cl.RETRY = 60             -- ticks avant la passe suivante d'une recherche en cours (budget de la passe épuisé)
Cl.POLL = 1200            -- ticks avant un nouvel essai quand le terrain de la ligne est en génération
Cl.LOGS = 40              -- lignes [FO-CENTRALE-LOIN] au plus, par équipe
Cl.WIDTH_MAX = 3.5        -- demi-largeur maximale du couloir de recherche (en portées de fil, Poteaux.WIDTHS)

local DIRS = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } } -- N, E, S, O

local floor, ceil, sqrt, max, min, abs = math.floor, math.ceil, math.sqrt, math.max, math.min, math.abs

--- Clé d'une rive (tuile entière).
function Cl.shore_key(x, y) return x .. ":" .. y end

--- Secteurs candidats. list = { { key, x, y } } (x, y : centre du secteur) ; hq = { x, y } ; done = { [key] = true } (épuisés).
--- Rend la liste triée par distance au QG (puis clé), sans les secteurs épuisés ni ceux au-delà de max_dist (défaut MAX_DIST).
function Cl.order_sectors(list, hq, done, max_dist)
  local lim = max_dist or Cl.MAX_DIST
  local out = {}
  for _, s in ipairs(list) do
    local d = sqrt((s.x - hq.x) * (s.x - hq.x) + (s.y - hq.y) * (s.y - hq.y))
    if d <= lim and not (done and done[s.key]) then out[#out + 1] = { key = s.key, x = s.x, y = s.y, d = d } end
  end
  table.sort(out, function(a, b) if a.d ~= b.d then return a.d < b.d end return a.key < b.key end)
  return out
end

--- Rives d'une zone. is_water(tx, ty) -> bool ; area = { x0, y0, x1, y1 } (tuiles, x1 et y1 exclus) ; toward = { x, y }.
--- Une rive est une tuile de TERRE dont la voisine et la suivante, dans une des 4 directions, sont de l'eau, et dont la voisine a
--- une voisine latérale en eau (la pompe de rive demande 2 tuiles d'eau devant elle : une mare d'une tuile n'en est pas une).
--- opts : gap (défaut SHORE_GAP), max (défaut SHORES_MAX), keep(x, y) -> bool (filtre : hors du treillis). Rend
--- { { x, y, dir (0 N, 2 E, 4 S, 6 O), d } } triées par distance (Manhattan) à `toward`, puis y, puis x, espacées de `gap`.
function Cl.shores(is_water, area, toward, opts)
  opts = opts or {}
  local gap = opts.gap or Cl.SHORE_GAP
  local cap = opts.max or Cl.SHORES_MAX
  local cands = {}
  for ty = area.y0, area.y1 - 1 do
    for tx = area.x0, area.x1 - 1 do
      if not is_water(tx, ty) and (not opts.keep or opts.keep(tx, ty)) then
        for di, d in ipairs(DIRS) do
          local x1, y1 = tx + d[1], ty + d[2]
          if is_water(x1, y1) and is_water(tx + 2 * d[1], ty + 2 * d[2])
            and (is_water(x1 - d[2], y1 + d[1]) or is_water(x1 + d[2], y1 - d[1])) then
            cands[#cands + 1] = { x = tx, y = ty, dir = (di - 1) * 2, d = abs(tx + 0.5 - toward.x) + abs(ty + 0.5 - toward.y) }
            break
          end
        end
      end
    end
  end
  table.sort(cands, function(a, b)
    if a.d ~= b.d then return a.d < b.d end
    if a.y ~= b.y then return a.y < b.y end
    return a.x < b.x
  end)
  local out = {}
  for _, c in ipairs(cands) do
    local near = false
    for _, o in ipairs(out) do
      if max(abs(o.x - c.x), abs(o.y - c.y)) < gap then near = true break end
    end
    if not near then
      out[#out + 1] = c
      if #out >= cap then break end
    end
  end
  return out
end

--- Carré d'essai du gabarit autour d'une rive : { x0, y0, x1, y1 } (x1, y1 exclus), WINDOW de côté.
function Cl.window(x, y)
  local h = Cl.WINDOW / 2
  return { x0 = x - h, y0 = y - h, x1 = x + h, y1 = y + h }
end

--- La rive (x, y) est-elle HORS du treillis évalué ? ext = { x0, y0, x1, y1 } (carré des lots, x1, y1 exclus). Le carré d'essai
--- (WINDOW) ne doit pas mordre sur les lots ni sur les rues : la rive est à plus de WINDOW / 2 tuiles du carré.
function Cl.outside(ext, x, y)
  local h = Cl.WINDOW / 2
  return x < ext.x0 - h or x >= ext.x1 + h or y < ext.y0 - h or y >= ext.y1 + h
end

--- Carrefour (i, j) ramené dans le carré [−R, R]² du treillis.
function Cl.clamp_node(R, i, j)
  local function c(v) if v < -R then return -R elseif v > R then return R end return v end
  return c(i), c(j)
end

--- Le carrefour le plus proche d'un poteau est-il hors du treillis (centrale lointaine) ?
function Cl.is_far(R, i, j)
  local ci, cj = Cl.clamp_node(R, i, j)
  return ci ~= i or cj ~= j
end

--- Options de shared/team/poteaux.lua (Q.path) pour une ligne de `dist` tuiles à portée `reach` : budget de cellules et de nœuds
--- assez grand pour le couloir le plus large (WIDTH_MAX portées), plus une marge. Même pas de cellule que Q.path (reach / 3).
function Cl.path_opts(dist, reach)
  local s = max(1, floor(reach / 3 + 0.5))
  local hw = Cl.WIDTH_MAX * reach
  local cells = ceil((dist + 2 * hw) / s) * ceil(2 * hw / s) + 64
  return { max_cells = cells, max_expand = 2 * cells }
end

--- Point d'appui d'un poteau de ligne : la tuile la plus proche de (x, y), à r tuiles au plus (Chebyshev), où stand(tx, ty) est
--- vrai ; à distance égale, y puis x. Rend tx + 0,5, ty + 0,5, ou nil.
function Cl.anchor_spot(stand, x, y, r)
  local x0, y0 = floor(x), floor(y)
  for k = 0, r do
    local ring = {}
    for dy = -k, k do
      for dx = -k, k do
        if max(abs(dx), abs(dy)) == k then ring[#ring + 1] = { dx, dy } end
      end
    end
    table.sort(ring, function(u, v)
      local du, dv = u[1] * u[1] + u[2] * u[2], v[1] * v[1] + v[2] * v[2]
      if du ~= dv then return du < dv end
      if u[2] ~= v[2] then return u[2] < v[2] end
      return u[1] < v[1]
    end)
    for _, d in ipairs(ring) do
      if stand(x0 + d[1], y0 + d[2]) then return x0 + d[1] + 0.5, y0 + d[2] + 0.5 end
    end
  end
  return nil
end

--- Ligne du journal [FO-CENTRALE-LOIN] (une par cause ; texte sans accent, comme les autres journaux du mod).
function Cl.line(team, text) return string.format("[FO-CENTRALE-LOIN] %s : %s", team or "player", text) end

return Cl
