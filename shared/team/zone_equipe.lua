--[[
  Lot UPS-HYGIENE (Mode Démon du DC, 10/11) : ZONE D'UNE ÉQUIPE, règle pure (Lua sans moteur, testable hors jeu).

  Pourquoi : le relevé des poteaux de l'hygiène (script/team/hygiene.lua) et celui des balises (script/team/balises_teinte.lua)
  interrogeaient le moteur sur la BOÎTE ENTIÈRE des chunks générés (une recherche par type et par force sur toute la carte). Mesuré au
  banc UPS-MESURE (graine 123456789, 90 min, carte max) : une telle recherche coûte ≈ 12 ms quel que soit le nombre de résultats
  (0 balise : 12,1 ms ; 166 à 401 poteaux : 12,5 ms) : le prix est celui des chunks parcourus, pas des entités trouvées. Sur les
  0,019 ms/tick de l'hygiène : 0,008 pour le relevé des poteaux, 0,0066 pour celui des balises, 0,0009 pour tout l'audit.

  Règle : les entités d'une équipe sont là où son plan a posé des pièces : la zone d'une équipe est la réunion de RECTANGLES (tuiles
  entières) : un par projet du plan directeur (boîte de ses pièces, abandonné compris : ses poteaux sont encore debout), le QG, chaque
  avant-poste (position ± rayon de la sorte), les tuiles de la chaîne des foreuses (f.swap.pole_pos), le remplaçant en attente de
  l'hygiène ; chaque rectangle est élargi d'une MARGE (la portée de fil la plus longue des poteaux : un poteau posé hors plan par
  l'hygiène ou par un raccord est à portée de fil d'un poteau du plan). Les rectangles qui se touchent sont FUSIONNÉS jusqu'au point
  fixe (une ligne de poteaux entre deux projets est dans la boîte des deux), puis rognés à la boîte des chunks générés. Sans plan ni
  QG (équipe neuve, bancs minimaux) : la boîte entière, comme avant.

  Déterminisme : l'ordre des rectangles est trié (x0, y0, x1, y1) avant la fusion et à la sortie ; aucune lecture de `pairs` ne décide.
  Coût déclaré au jeton des travaux lourds : le nombre de chunks couverts par les rectangles (Ze.cost), à la place des chunks de la boîte.
]]

local Ze = {}

Ze.CHUNK = 32

--- Rectangle (tuiles entières, bornes comprises en x0/y0, exclues en x1/y1 comme une zone du moteur) autour de points { x, y },
--- élargi de `marge` tuiles ; nil sans point.
function Ze.rect_of_points(points, marge)
  local r
  for _, p in ipairs(points or {}) do
    local x, y = p.x or p[1], p.y or p[2]
    if x and y then
      if r then
        if x < r.x0 then r.x0 = x end
        if x > r.x1 then r.x1 = x end
        if y < r.y0 then r.y0 = y end
        if y > r.y1 then r.y1 = y end
      else
        r = { x0 = x, y0 = y, x1 = x, y1 = y }
      end
    end
  end
  if not r then return nil end
  marge = marge or 0
  return { x0 = math.floor(r.x0 - marge), y0 = math.floor(r.y0 - marge), x1 = math.ceil(r.x1 + marge) + 1, y1 = math.ceil(r.y1 + marge) + 1 }
end

--- Rectangle autour d'un centre (x, y) et d'un rayon `r` (tuiles), élargi de `marge`.
function Ze.rect_around(x, y, r, marge)
  local m = (r or 0) + (marge or 0)
  return { x0 = math.floor(x - m), y0 = math.floor(y - m), x1 = math.ceil(x + m) + 1, y1 = math.ceil(y + m) + 1 }
end

local function touch(a, b)
  return a.x0 <= b.x1 and b.x0 <= a.x1 and a.y0 <= b.y1 and b.y0 <= a.y1
end

local function less(a, b)
  if a.x0 ~= b.x0 then return a.x0 < b.x0 end
  if a.y0 ~= b.y0 then return a.y0 < b.y0 end
  if a.x1 ~= b.x1 then return a.x1 < b.x1 end
  return a.y1 < b.y1
end

--- Fusion des rectangles qui se touchent ou se chevauchent, jusqu'au point fixe ; liste triée (x0, y0, x1, y1).
function Ze.merge(rects)
  local list = {}
  for _, r in ipairs(rects or {}) do
    if r and r.x1 > r.x0 and r.y1 > r.y0 then list[#list + 1] = { x0 = r.x0, y0 = r.y0, x1 = r.x1, y1 = r.y1 } end
  end
  table.sort(list, less)
  local changed = true
  while changed do
    changed = false
    local i = 1
    while i <= #list do
      local a = list[i]
      local j = i + 1
      while j <= #list do
        local b = list[j]
        if touch(a, b) then
          if b.x0 < a.x0 then a.x0 = b.x0 end
          if b.y0 < a.y0 then a.y0 = b.y0 end
          if b.x1 > a.x1 then a.x1 = b.x1 end
          if b.y1 > a.y1 then a.y1 = b.y1 end
          table.remove(list, j)
          changed = true
        else
          j = j + 1
        end
      end
      i = i + 1
    end
  end
  table.sort(list, less)
  return list
end

--- Rognage à une boîte de tuiles { x0, y0, x1, y1 } (x1/y1 exclus) ; les rectangles vides disparaissent. Sans boîte : inchangé.
function Ze.clip(rects, box)
  if not box then return rects end
  local out = {}
  for _, r in ipairs(rects or {}) do
    local c = { x0 = math.max(r.x0, box.x0), y0 = math.max(r.y0, box.y0), x1 = math.min(r.x1, box.x1), y1 = math.min(r.y1, box.y1) }
    if c.x1 > c.x0 and c.y1 > c.y0 then out[#out + 1] = c end
  end
  return out
end

--- Boîte de chunks { x0, y0, x1, y1 } (bornes comprises, coordonnées de chunk) -> boîte de tuiles (x1/y1 exclus).
function Ze.box_tiles(box)
  if not box then return nil end
  local c = Ze.CHUNK
  return { x0 = box.x0 * c, y0 = box.y0 * c, x1 = (box.x1 + 1) * c, y1 = (box.y1 + 1) * c }
end

--- Chunks couverts par les rectangles (somme ; un chunk touché par deux rectangles compte deux fois : borne haute, coût déclaré).
function Ze.cost(rects)
  local c, n = Ze.CHUNK, 0
  for _, r in ipairs(rects or {}) do
    local cx = math.floor((r.x1 - 1) / c) - math.floor(r.x0 / c) + 1
    local cy = math.floor((r.y1 - 1) / c) - math.floor(r.y0 / c) + 1
    n = n + cx * cy
  end
  return n
end

--- Zone d'un rectangle au format du moteur : { { x0, y0 }, { x1, y1 } }.
function Ze.area(r) return { { r.x0, r.y0 }, { r.x1, r.y1 } } end

return Ze
