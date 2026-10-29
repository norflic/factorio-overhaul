--[[
  Lot TOURELLES-HORS-AXE (retour du DC du 29/10, en jouant la 0.6.18, défaut 4) : « le canon est en plein milieu. Donc si on
  voulait étendre sur la gauche [...] on pourrait pas parce que il y a la tourelle. Ou alors enfin, il faut contourner la tourelle
  et tout si c'est possible mais ça coupe un peu le pattern en fait. »
  PUR : aucune API Factorio, aucun nom d'objet du jeu ; testé hors jeu (tests/axe_test.lua).

  Les tuiles réservées du plan directeur (b.occ, lot FACTIONS-BLOQUEES) protègent les emprises POSÉES (ou planifiées) d'un module,
  pas l'axe le long duquel une ligne extensible grandit (ligne de fours à tapis, rangées de foreuses : leur longueur maximale est
  celle du lot, Ligne.rows_fit et P.fit). Une tourelle posée au bout d'une ligne, dans son lot, bloque son agrandissement.

  Règles :
  - `axis_of(dirs)`          : axe de la ligne ("x" ou "y") d'après la direction de ses tapis (le tapis court le long de la ligne) ;
  - `corridor(part, lot, axis, side)` : couloir d'extension = toute la longueur du lot le long de l'axe (longueur maximale prévue
                               de la ligne, bout du tapis et quai compris), sur la largeur du module plus `side` tuiles de chaque côté
                               (bras et coffres de sortie posés à côté du bout, Ligne.MAX_ARMS) ;
  - `tile_rect(x, y, w, h)`  : emprise en tuiles d'une entité w × h centrée en (x, y) ;
  - `hit(cors, x0, y0, x1, y1)` : premier couloir que l'emprise [x0, x1) × [y0, y1) recouvre (chevauchement STRICT, F96) ;
  - `side_spots(x, y, cors, w, h)` : si une entité w × h posée en (x, y) tombe dans un couloir, positions voisines SUR LE CÔTÉ de
                               la ligne (hors du couloir, à `GAP` tuiles), côté le plus proche d'abord, puis le long de l'axe.
  Aucun `pairs`, aucun hasard, aucune trigonométrie.
]]

local A = {}

A.SIDE = 1                        -- tuiles du couloir de chaque côté du module (bras et coffres de sortie du bout de la ligne)
A.GAP = 1                         -- tuiles libres entre le couloir et une tourelle posée sur le côté (passage des PNJ)
A.STEPS = { 0, 3, -3, 6, -6 }     -- décalages le long de l'axe des positions de côté (ordre fixe)

local floor, max, min = math.floor, math.max, math.min

--- Axe d'une ligne d'après les directions de ses tapis (0..7, nord = 0, est = 2, sud = 4, ouest = 6) : "y" si la majorité court
--- nord-sud, "x" si elle court est-ouest ; nil sans tapis ou à égalité (un virage seul ne dit pas l'axe).
function A.axis_of(dirs)
  local v, h = 0, 0
  for _, d in ipairs(dirs or {}) do
    if type(d) == "number" then
      if d % 4 == 0 then v = v + 1 elseif d % 4 == 2 then h = h + 1 end
    end
  end
  if v > h then return "y" end
  if h > v then return "x" end
  return nil
end

--- Couloir d'extension d'un module `part` = { x0, y0, x1, y1 } (tuiles, bornes hautes exclues) posé dans le lot `lot` (même forme) :
--- toute la longueur du lot le long de `axis`, la largeur du module plus `side` tuiles de chaque côté, rognée au lot.
--- Rend { x0, y0, x1, y1, axis } ou nil.
function A.corridor(part, lot, axis, side)
  if not (part and lot) or (axis ~= "x" and axis ~= "y") then return nil end
  side = side or A.SIDE
  local c
  if axis == "y" then
    c = { x0 = max(lot.x0, part.x0 - side), x1 = min(lot.x1, part.x1 + side), y0 = lot.y0, y1 = lot.y1, axis = "y" }
  else
    c = { x0 = lot.x0, x1 = lot.x1, y0 = max(lot.y0, part.y0 - side), y1 = min(lot.y1, part.y1 + side), axis = "x" }
  end
  if c.x1 <= c.x0 or c.y1 <= c.y0 then return nil end
  return c
end

--- Emprise en tuiles d'une entité w × h centrée en (x, y) : x0, y0, x1, y1 (bornes hautes exclues). Même arrondi que
--- Build.reserved_entity (positions du moteur en virgule fixe, F92).
function A.tile_rect(x, y, w, h)
  local x0, y0 = floor(x - w / 2 + 0.01), floor(y - h / 2 + 0.01)
  return x0, y0, x0 + w, y0 + h
end

--- Premier couloir (et son indice) que l'emprise [x0, x1) × [y0, y1) recouvre ; un simple contact par un bord ne compte pas.
function A.hit(cors, x0, y0, x1, y1)
  for i, c in ipairs(cors or {}) do
    if x0 < c.x1 and c.x0 < x1 and y0 < c.y1 and c.y0 < y1 then return c, i end
  end
  return nil
end

--- Positions voisines sur le côté de la ligne pour une entité w × h voulue en (x, y) : vide si elle ne tombe dans aucun couloir.
--- Les deux côtés longs du couloir touché, le plus proche du point d'abord (égalité : le côté des petites coordonnées), et pour
--- chacun les décalages A.STEPS le long de l'axe. Le centre est placé pour que l'emprise reste à A.GAP tuiles du couloir.
function A.side_spots(x, y, cors, w, h)
  local x0, y0, x1, y1 = A.tile_rect(x, y, w, h)
  local c = A.hit(cors, x0, y0, x1, y1)
  if not c then return {} end
  local out = {}
  if c.axis == "y" then
    local lo, hi = c.x0 - A.GAP - w / 2, c.x1 + A.GAP + w / 2
    local first, second = lo, hi
    if (x - c.x0) > (c.x1 - x) then first, second = hi, lo end
    for _, side in ipairs({ first, second }) do
      for _, s in ipairs(A.STEPS) do out[#out + 1] = { x = side, y = y + s } end
    end
  else
    local lo, hi = c.y0 - A.GAP - h / 2, c.y1 + A.GAP + h / 2
    local first, second = lo, hi
    if (y - c.y0) > (c.y1 - y) then first, second = hi, lo end
    for _, side in ipairs({ first, second }) do
      for _, s in ipairs(A.STEPS) do out[#out + 1] = { x = x + s, y = side } end
    end
  end
  return out
end

return A
