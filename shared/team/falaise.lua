--[[
  Lot OBSTACLES « une falaise ne doit pas bloquer la construction ». PUR : aucune API Factorio, aucun nom d'objet du jeu ;
  testé hors jeu (tests/falaise_test.lua).

  Cause mesurée (journal [FO-IA1D], 4 parties sur 4 : graines 20261020, 123456789, 271828182 du lot REGARD et la partie du DC du
  2/11) : un fantôme de TAPIS refusé « occupe » par une falaise, projet « bloque » puis « abandon » après 3 reprises au même plan
  (alimentation de la centrale ; fonderie de Scarlet de 82 à 267 min sur 271828182). Diagnostic au moteur réel (3/11, graine
  271828182, falaise « east-to-none » en (358 ; −405,5)) : au moment du plan la tuile du tapis (357 ; −404) n'est pas dans les
  masques, et le moteur la refuse plus tard. `LuaEntity::bounding_box` est exacte pour les 4 falaises droites (west-to-east 4 × 3,
  north-to-south 2 × 4…) mais, pour les 16 falaises tournées (coins, entrées), c'est la petite boîte alignée du rectangle tourné :
  2,8 × 1,4 tuiles pour east-to-none, alors que le moteur refuse 9 tuiles (relevé des 20 orientations, scénario obstacles-falaise :
  222 tuiles refusées, tests/fixtures/falaise_moteur.txt). Les masques du plan (read_masks) ne bloquaient que `bounding_box` (F294
  le décrivait pour un poteau).

  Ici : l'emprise réelle d'une falaise (liste de tuiles) à partir de sa position, de son orientation et de l'échelle du prototype.
  - Les boîtes viennent des données de base (entities.lua:608 à 631), dans le repère de la falaise, y vers le sud. Prouvé au moteur
    réel le 3/11 : 0 tuile refusée par le moteur absente du modèle sur les 20 orientations (49 tuiles en trop, surtout aux coins).
  - Un rectangle tourné (coins, entrées) est pris tourné de ±45° AUTOUR DE SON CENTRE, UNIE à sa version non tournée : la
    documentation dit que le 3e membre d'une BoundingBox (l'orientation) est « inutilisé », et le moteur n'est pas lisible ici.
    Sur-bloquer quelques tuiles d'un coin coûte un détour ; sous-bloquer coûte un projet bloqué 3 fois de suite.
  - Une tuile est prise si l'intérieur de la tuile et celui de la boîte se recouvrent (un contact par le bord ne compte pas, F96).
  - Orientation inconnue ou absente : carré de 4 × 4 tuiles autour du centre (repli prudent).
  - Pas de trigonométrie : les rotations sont de ±45° exactement (cos = sin = √½).
  `learn` : mémoire bornée (`mem.t`, clés de tuiles) des tuiles où le moteur a refusé un fantôme à cause d'une falaise (le plan suivant les évite même si le
  modèle ci-dessus se trompait d'un coin).
  Aucun `pairs`, aucun hasard, aucun temps mesuré.
]]

local F = {}

F.REACH = 3.5      -- tuiles : distance maximale du centre à un bord de l'emprise réelle (échelle 1) ; sert aux zones de recherche
F.EPS = 0.001      -- une tuile est rognée de EPS de chaque côté (contact par le bord = pas de recouvrement)
F.LEARN_CAP = 600  -- tuiles apprises au plus, par équipe

local H = 0.7071067811865476      -- √½ : cos 45° = sin 45°
local DQ = 0.35355339059327373    -- √2 / 4 : dq(n) = DQ * n dans entities.lua

local function R(cx, cy, hw, hh, sign) return { rot = true, cx = cx, cy = cy, hw = DQ * hw, hh = DQ * hh, sign = sign } end
local function A(x0, y0, x1, y1) return { x0 = x0, y0 = y0, x1 = x1, y1 = y1 } end

-- repère de la falaise, échelle 1 ; sign = +1 pour l'angle 1/8 (+45°, sens horaire à l'écran), −1 pour 7/8 (−45°)
F.BOXES = {
  ["west-to-east"]   = A(-2, -1.5, 2, 1.5),
  ["north-to-south"] = A(-1, -2, 1, 2),
  ["east-to-west"]   = A(-2, -0.5, 2, 0.5),
  ["south-to-north"] = A(-1, -2, 1, 2),
  ["west-to-north"]  = R(-5 / 4, -3 / 4, 5.4, 3.6, -1),
  ["north-to-east"]  = R(5 / 4, -3 / 4, 5.4, 3.6, 1),
  ["east-to-south"]  = R(3 / 4, 5 / 4, 4.4, 2.6, -1),
  ["south-to-west"]  = R(-3 / 4, 5 / 4, 4.4, 2.6, 1),
  ["west-to-south"]  = R(-5 / 4, 3 / 4, 5.4, 3.6, 1),
  ["north-to-west"]  = R(-3 / 4, -5 / 4, 4.4, 2.6, -1),
  ["east-to-north"]  = R(3 / 4, -5 / 4, 4.4, 2.6, 1),
  ["south-to-east"]  = R(5 / 4, 3 / 4, 5.4, 3.6, -1),
  ["west-to-none"]   = A(-2, -1.5, 0, 1.5),
  ["none-to-east"]   = A(0, -1.5, 2, 1.5),
  ["north-to-none"]  = R(0.75, -0.75, 4.5, 2.5, 1),
  ["none-to-south"]  = R(0.6, 0.9, 4, 2, -1),
  ["east-to-none"]   = R(0.75, 0.75, 4, 2, -1),
  ["none-to-west"]   = R(-0.85, 0.85, 4, 2, 1),
  ["south-to-none"]  = R(-0.85, 0.85, 4, 2, 1),
  ["none-to-north"]  = R(-0.7, -0.7, 4.5, 2.5, -1),
}

local FALLBACK = A(-2, -2, 2, 2)

--- Orientation connue des données de base ?
function F.known(orientation) return F.BOXES[orientation] ~= nil end

local function scaled(b, s)
  if b.rot then return { rot = true, cx = b.cx * s, cy = b.cy * s, hw = b.hw * s, hh = b.hh * s, sign = b.sign } end
  return { x0 = b.x0 * s, y0 = b.y0 * s, x1 = b.x1 * s, y1 = b.y1 * s }
end

--- Polygones convexes (liste de 4 points { x, y }) de l'emprise réelle, dans le repère de la falaise, pour l'échelle `scale`.
--- Un rectangle tourné rend DEUX polygones : le tourné, puis le non tourné (union prudente, voir l'en-tête).
function F.polygons(orientation, scale)
  local b = scaled(F.BOXES[orientation] or FALLBACK, scale or 1)
  if not b.rot then
    return { { { b.x0, b.y0 }, { b.x1, b.y0 }, { b.x1, b.y1 }, { b.x0, b.y1 } } }
  end
  local c, s = H, H * b.sign
  local pts = {}
  for _, q in ipairs({ { -b.hw, -b.hh }, { b.hw, -b.hh }, { b.hw, b.hh }, { -b.hw, b.hh } }) do
    pts[#pts + 1] = { b.cx + q[1] * c - q[2] * s, b.cy + q[1] * s + q[2] * c }
  end
  local flat = { { b.cx - b.hw, b.cy - b.hh }, { b.cx + b.hw, b.cy - b.hh }, { b.cx + b.hw, b.cy + b.hh }, { b.cx - b.hw, b.cy + b.hh } }
  return { pts, flat }
end

-- Le polygone convexe `poly` (points dans l'ordre) recouvre-t-il le carré ouvert (x0, y0, x1, y1) ? Séparation par axes (SAT).
local function overlaps(poly, x0, y0, x1, y1)
  local minx, maxx, miny, maxy = math.huge, -math.huge, math.huge, -math.huge
  for _, p in ipairs(poly) do
    if p[1] < minx then minx = p[1] end
    if p[1] > maxx then maxx = p[1] end
    if p[2] < miny then miny = p[2] end
    if p[2] > maxy then maxy = p[2] end
  end
  if maxx <= x0 or minx >= x1 or maxy <= y0 or miny >= y1 then return false end
  local sq = { { x0, y0 }, { x1, y0 }, { x1, y1 }, { x0, y1 } }
  for i = 1, #poly do
    local a, b = poly[i], poly[i % #poly + 1]
    local nx, ny = -(b[2] - a[2]), b[1] - a[1]
    local pmin, pmax = math.huge, -math.huge
    for _, p in ipairs(poly) do
      local d = p[1] * nx + p[2] * ny
      if d < pmin then pmin = d end
      if d > pmax then pmax = d end
    end
    local smin, smax = math.huge, -math.huge
    for _, p in ipairs(sq) do
      local d = p[1] * nx + p[2] * ny
      if d < smin then smin = d end
      if d > smax then smax = d end
    end
    local tol = 1e-9 * (math.abs(nx) + math.abs(ny))
    if pmax <= smin + tol or smax <= pmin + tol then return false end
  end
  return true
end

--- Tuiles de l'emprise réelle d'une falaise posée en (cx, cy) : liste plate { tx1, ty1, tx2, ty2, ... }, triée (y puis x).
--- `orientation` : LuaEntity::cliff_orientation ; `scale` : demi-largeur de la boîte générique du prototype (1 pour la falaise de base).
function F.tiles(cx, cy, orientation, scale)
  local polys = F.polygons(orientation, scale)
  local lo_x, hi_x, lo_y, hi_y = math.huge, -math.huge, math.huge, -math.huge
  for _, poly in ipairs(polys) do
    for _, p in ipairs(poly) do
      lo_x, hi_x = math.min(lo_x, p[1]), math.max(hi_x, p[1])
      lo_y, hi_y = math.min(lo_y, p[2]), math.max(hi_y, p[2])
    end
  end
  local out = {}
  for ty = math.floor(cy + lo_y), math.ceil(cy + hi_y) - 1 do
    for tx = math.floor(cx + lo_x), math.ceil(cx + hi_x) - 1 do
      local hit = false
      for _, poly in ipairs(polys) do
        if overlaps(poly, tx - cx + F.EPS, ty - cy + F.EPS, tx + 1 - cx - F.EPS, ty + 1 - cy - F.EPS) then hit = true break end
      end
      if hit then out[#out + 1] = tx; out[#out + 1] = ty end
    end
  end
  return out
end

--- La tuile (tx, ty) est-elle dans l'emprise réelle de cette falaise ?
function F.blocks(cx, cy, orientation, scale, tx, ty)
  local t = F.tiles(cx, cy, orientation, scale)
  for i = 1, #t - 1, 2 do if t[i] == tx and t[i + 1] == ty then return true end end
  return false
end

--- Zone de recherche à donner au moteur pour voir toutes les falaises dont l'emprise réelle touche le rectangle (x0, y0, x1, y1) :
--- le rectangle élargi de F.REACH (échelle 1). Rend x0, y0, x1, y1.
function F.search_area(x0, y0, x1, y1, scale)
  local m = F.REACH * (scale or 1)
  return x0 - m, y0 - m, x1 + m, y1 + m
end

--- Mémoire des tuiles apprises : `mem` = { n = nombre, t = { [clé] = true } } (table sauvegardable), `key` = fonction (tx, ty) -> clé.
--- Ajoute les tuiles de la liste plate `flat` ; rend le nombre de tuiles NOUVELLES (0 au plafond F.LEARN_CAP).
function F.learn(mem, flat, key)
  mem.t = mem.t or {}
  local added = 0
  for i = 1, #flat - 1, 2 do
    local k = key(flat[i], flat[i + 1])
    if not mem.t[k] then
      if (mem.n or 0) >= F.LEARN_CAP then return added end
      mem.t[k] = true
      mem.n = (mem.n or 0) + 1
      added = added + 1
    end
  end
  return added
end

--- Décode une clé de tuile de shared/team/plan.lua (P.tkey = (x + 1048576) * 2097152 + (y + 1048576)) : tx, ty. Sert aux lecteurs qui
--- gardent leurs propres clés (champ de l'avant-poste) ; tests/falaise_test.lua contrôle l'aller-retour contre P.tkey.
function F.untkey(k)
  local ty = k % 2097152
  return (k - ty) / 2097152 - 1048576, ty - 1048576
end

--- Tuiles d'une boîte { x0, y0, x1, y1 } (une entité refusée) : liste plate, mêmes règles qu'ailleurs (contact par le bord = non).
function F.box_tiles(x0, y0, x1, y1)
  local out = {}
  for ty = math.floor(y0 + F.EPS), math.ceil(y1 - F.EPS) - 1 do
    for tx = math.floor(x0 + F.EPS), math.ceil(x1 - F.EPS) - 1 do out[#out + 1] = tx; out[#out + 1] = ty end
  end
  return out
end

--- s50 falaises : une pièce refusée au moteur est-elle sautée (abandonnée seule) au lieu de bloquer tout le projet ? Oui pour un mur
--- refusé à la limite, et pour une foreuse (type d'entité « mining-drill », lu au prototype) refusée à cause d'une falaise : la bande
--- garde ses autres foreuses. Règle pure.
function F.skip_refused(is_wall, entity_type, cliff_hit, fails, limit)
  if (fails or 0) < limit then return false end
  if is_wall then return true end
  return cliff_hit == true and entity_type == "mining-drill"
end

return F
