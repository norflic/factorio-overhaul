--[[
  Lot DEFENSE (retour du DC du 2/11 sur la 0.6.34, points 10 et 16) : « une quantité absolument faramineuse de tourelles autour du centre de
  commandement et pas du tout autour de là où ils se font attaquer » ; « c'est surtout au niveau des contours, de la protection de la base » ;
  « ils défendent les gisements mais pas du tout [...] la base [...] les assembleurs ». Règle PURE (aucune API Factorio, aucun nom d'objet :
  l'appelant passe des nombres, des rectangles et des points), déterministe, testée hors jeu par tests/ceinture_test.lua (avec mutants).

  Cause lue dans le code et au journal du DC (fo-logs/2026-11-02_DEFENSE/RAPPORT.md) :
    1. Le QG montait à Dc.HQ_CAP (8) tourelles dès que la base était « menacée » (une perte près du QG) ET que le fer les payait, QUELLE QUE SOIT la
       taille des vagues reçues (shared/team/defchoix.lua, D.turrets). Écarlate : 14 à 18 tourelles à 48 tuiles du QG, défense armée 8 927 à
       11 918 PV, menace reçue 19 à 738 PV en 30 min ([FO-SURVIE] recensement de la 0.6.34). Le plafond n'était pas proportionnel à la menace.
    2. Les tourelles d'un avant-poste ou du QG se posaient sur 8 emplacements fixes autour du CENTRE du site (anneau à 7 et 9 tuiles,
       script/faction/outposts.lua, pose_order), le surplus en anneaux voisins : un amas au milieu des bâtiments, jamais sur le contour, et
       sans égard au côté d'où viennent les attaques ni aux nids connus.
    3. Aucun bâtiment de production autre que les laboratoires n'était « à couvrir » (shared/team/front.lua, F.cover_clusters) : les assembleurs
       n'avaient de tourelle que par hasard.

  Règles (trois services) :
    HQ_CAP     Ce.hq_cap : tourelles qu'une base menacée et riche peut ajouter au QG = ce que la plus grosse vague REÇUE AU QG (pas ailleurs) exige,
               × Ce.COVER_PCT %, plus Ce.HQ_SLACK, jamais sous Ce.HQ_FLOOR ni sous ce que l'appelant veut déjà, au plus le plafond de l'appelant.
               Sans mesure de la menace (nil) : le plafond de l'appelant (comportement d'avant).
    CONTOUR    Ce.contour : les emplacements de ceinture d'un site = le bord extérieur de l'emprise de ses bâtiments élargie de Ce.MARGIN tuiles
               (trame de Ce.CELL tuiles, remplissage depuis l'extérieur : un trou au milieu du site n'est pas un contour), éclaircis à
               Ce.THIN tuiles d'écart.
    EXPOSITION Ce.heading : poids par octant (vu du centre du site) des points de menace (cellules attaquées, nids connus) ; Ce.choose pose
               d'abord la tourelle qui couvre le plus de bâtiments non couverts, multiplié par l'exposition de son côté (jusqu'à Ce.EXPO_PCT % de
               plus) ; l'écart minimal entre tourelles est respecté tant qu'il reste un emplacement qui le respecte.
  Les bâtiments à couvrir du front (Ce.cover_positions) : les mêmes que ceux des laboratoires, plus les groupes de machines de fabrication.

  Aucun `pairs` décisionnel (listes triées), aucune trigonométrie (octants par comparaisons entières), aucun hasard.
]]
local Pose = require("shared.team.pose_tourelles")

local Ce = {}

Ce.CELL = 2             -- tuiles : côté d'une case de la trame du contour (une tourelle occupe 2 x 2)
Ce.MARGIN = 3           -- tuiles : distance de la ceinture au bord des bâtiments (arrondie en cases)
Ce.THIN = 4             -- tuiles : écart minimal entre deux emplacements candidats gardés
Ce.MAX_BOXES = 600      -- rectangles pris en compte au plus (les plus proches du centre)
Ce.MAX_AREA = 40000     -- cases de la trame au plus (au-delà : aucun contour, l'appelant garde l'ancienne pose)
Ce.MAX_CANDS = 160      -- candidats de contour gardés au plus (borne le coût du choix)
Ce.EXPO_PCT = 100       -- bonus d'exposition maximal, en % du gain de couverture (100 : le côté le plus attaqué compte double)
Ce.SPILL_PCT = 50       -- % du poids d'un octant reversé à chacun de ses deux voisins
Ce.NEST_W = 40          -- centièmes de coup : poids d'un nid connu comme direction (une cellule attaquée pèse au moins 200)
Ce.COVER_PCT = 125      -- % : la défense visée vaut 1,25 × la vague reçue (comme shared/team/survie_qg.lua, Sq.COVER_PCT)
Ce.HQ_SLACK = 1         -- tourelle de plus au-delà de ce que la vague exige
Ce.HQ_FLOOR = 4         -- tourelles au QG au moins permises (les 4 du départ, T.defend_hq)
Ce.COVER_TYPES_MIN = 3  -- machines d'une case de 16 tuiles à partir desquelles le groupe est « à couvrir »

local function num(x)
  if type(x) ~= "number" or x ~= x then return 0 end
  return x
end

local floor, ceil = math.floor, math.ceil

---------------------------------------------------------------------------------------------------
-- 1. Plafond du QG
---------------------------------------------------------------------------------------------------

--- Tourelles qu'une base menacée et riche peut avoir au QG. a = { threat (PV de la plus grosse vague reçue AU QG en 30 min ; nil : inconnu),
--- value (PV d'une tourelle armée de plus), want (tourelles voulues sans cette règle), cap (plafond de l'appelant) }.
--- Rend un entier entre max(want, HQ_FLOOR) et cap (jamais sous ce que l'appelant veut déjà).
function Ce.hq_cap(a)
  a = a or {}
  local cap, want = num(a.cap), num(a.want)
  local floor_n = want > Ce.HQ_FLOOR and want or Ce.HQ_FLOOR
  if cap < floor_n then return cap > want and cap or want end
  local threat, value = a.threat, num(a.value)
  if type(threat) ~= "number" or threat ~= threat or value <= 0 then return cap end
  local need = ceil(threat * Ce.COVER_PCT / 100 / value - 1e-9) + Ce.HQ_SLACK
  if need < floor_n then need = floor_n end
  if need > cap then need = cap end
  return need
end

---------------------------------------------------------------------------------------------------
-- 2. Exposition (le côté d'où viennent les attaques)
---------------------------------------------------------------------------------------------------

--- Octant d'un vecteur vu du centre : 0 est, 1 sud-est, 2 sud, 3 sud-ouest, 4 ouest, 5 nord-ouest, 6 nord, 7 nord-est (y vers le bas) ;
--- nil pour un vecteur nul. Comparaisons entières (tan 22,5° ~ 0,414), pas de trigonométrie.
function Ce.octant(dx, dy)
  if dx == 0 and dy == 0 then return nil end
  local ax, ay = dx < 0 and -dx or dx, dy < 0 and -dy or dy
  if ay * 1000 < ax * 414 then return dx > 0 and 0 or 4 end
  if ax * 1000 < ay * 414 then return dy > 0 and 2 or 6 end
  if dx > 0 then return dy > 0 and 1 or 7 end
  return dy > 0 and 3 or 5
end

--- Poids par octant des points de menace vus de `center` : { [0..7] = poids, max = le plus grand }. threats = { { x, y, w } }.
--- Chaque octant reverse Ce.SPILL_PCT % de son poids à ses deux voisins (une attaque de biais compte des deux côtés).
function Ce.heading(center, threats)
  local raw = {}
  for i = 0, 7 do raw[i] = 0 end
  for _, t in ipairs(threats or {}) do
    local d = Ce.octant(num(t.x) - num(center.x), num(t.y) - num(center.y))
    if d and num(t.w) > 0 then raw[d] = raw[d] + t.w end
  end
  local out, max = {}, 0
  for i = 0, 7 do
    local w = raw[i] + floor((raw[(i + 1) % 8] + raw[(i + 7) % 8]) * Ce.SPILL_PCT / 100)
    out[i] = w
    if w > max then max = w end
  end
  out.max = max
  return out
end

---------------------------------------------------------------------------------------------------
-- 3. Contour d'un site
---------------------------------------------------------------------------------------------------

local function key(cx, cy) return (cx + 32768) * 65536 + (cy + 32768) end

--- Emplacements de ceinture. boxes = { { x0, y0, x1, y1 } } (emprises des bâtiments, en tuiles) ; o = { center = { x, y } (pour garder les
--- plus proches si trop nombreux) }. Rend { { x, y } } (centres de cases du bord extérieur de l'emprise élargie), triés par case ; vide si
--- aucune emprise ou si la trame dépasse Ce.MAX_AREA. Éclaircis à Ce.THIN tuiles.
function Ce.contour(boxes, o)
  o = o or {}
  local list = {}
  for _, b in ipairs(boxes or {}) do
    if num(b.x1) > num(b.x0) and num(b.y1) > num(b.y0) then list[#list + 1] = b end
  end
  if #list == 0 then return {} end
  if #list > Ce.MAX_BOXES then
    local c = o.center or { x = 0, y = 0 }
    table.sort(list, function(a, b)
      local da = ((a.x0 + a.x1) / 2 - c.x) ^ 2 + ((a.y0 + a.y1) / 2 - c.y) ^ 2
      local db = ((b.x0 + b.x1) / 2 - c.x) ^ 2 + ((b.y0 + b.y1) / 2 - c.y) ^ 2
      if da ~= db then return da < db end
      if a.x0 ~= b.x0 then return a.x0 < b.x0 end
      return a.y0 < b.y0
    end)
    while #list > Ce.MAX_BOXES do list[#list] = nil end
  end
  local cell = Ce.CELL
  local m = ceil(Ce.MARGIN / cell)
  local occ, minx, miny, maxx, maxy = {}, nil, nil, nil, nil
  for _, b in ipairs(list) do
    local x0, x1 = floor(b.x0 / cell), floor((b.x1 - 1e-6) / cell)
    local y0, y1 = floor(b.y0 / cell), floor((b.y1 - 1e-6) / cell)
    for cx = x0, x1 do
      for cy = y0, y1 do occ[key(cx, cy)] = true end
    end
    if not minx or x0 < minx then minx = x0 end
    if not maxx or x1 > maxx then maxx = x1 end
    if not miny or y0 < miny then miny = y0 end
    if not maxy or y1 > maxy then maxy = y1 end
  end
  -- Trame élargie : emprise + m cases (zone D) + 1 case de bord pour le remplissage depuis l'extérieur.
  local gx0, gx1, gy0, gy1 = minx - m - 1, maxx + m + 1, miny - m - 1, maxy + m + 1
  if (gx1 - gx0 + 1) * (gy1 - gy0 + 1) > Ce.MAX_AREA then return {} end
  -- Zone D : cases à moins de m cases (Tchebychev) d'une case occupée.
  local zone = {}
  for cx = minx, maxx do
    for cy = miny, maxy do
      if occ[key(cx, cy)] then
        for dx = -m, m do
          for dy = -m, m do zone[key(cx + dx, cy + dy)] = true end
        end
      end
    end
  end
  -- Remplissage depuis le coin extérieur à travers les cases hors zone D (4 voisins).
  local outside = {}
  local stack = { { gx0, gy0 } }
  outside[key(gx0, gy0)] = true
  while #stack > 0 do
    local c = stack[#stack]
    stack[#stack] = nil
    local cx, cy = c[1], c[2]
    local nb = { { cx + 1, cy }, { cx - 1, cy }, { cx, cy + 1 }, { cx, cy - 1 } }
    for _, n in ipairs(nb) do
      local nx, ny = n[1], n[2]
      if nx >= gx0 and nx <= gx1 and ny >= gy0 and ny <= gy1 then
        local k = key(nx, ny)
        if not outside[k] and not zone[k] then
          outside[k] = true
          stack[#stack + 1] = { nx, ny }
        end
      end
    end
  end
  -- Bord extérieur de D : cases de D (non occupées) touchant une case extérieure.
  local out = {}
  for cx = gx0, gx1 do
    for cy = gy0, gy1 do
      local k = key(cx, cy)
      if zone[k] and not occ[k] then
        if outside[key(cx + 1, cy)] or outside[key(cx - 1, cy)] or outside[key(cx, cy + 1)] or outside[key(cx, cy - 1)] then
          out[#out + 1] = { x = (cx + 0.5) * cell, y = (cy + 0.5) * cell }
        end
      end
    end
  end
  -- Éclaircissement : ordre de la trame (colonne puis ligne), un candidat est gardé s'il est à Ce.THIN tuiles au moins des gardés.
  local thin, lim = {}, Ce.THIN * Ce.THIN
  for _, c in ipairs(out) do
    local ok = true
    for _, t in ipairs(thin) do
      local dx, dy = c.x - t.x, c.y - t.y
      if dx * dx + dy * dy < lim then ok = false break end
    end
    if ok then thin[#thin + 1] = c end
    if #thin >= Ce.MAX_CANDS then break end
  end
  return thin
end

---------------------------------------------------------------------------------------------------
-- 4. Choix des emplacements
---------------------------------------------------------------------------------------------------

local function d2(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return dx * dx + dy * dy end

--- Choisit `count` emplacements parmi les candidats. spec = { cands = { { x, y } }, assets = { { x, y, w } } (bâtiments à couvrir),
--- range (portée de la tourelle), existing = { { x, y } } (tourelles déjà posées), count, gap (écart minimal entre centres), center = { x, y },
--- threats = { { x, y, w } } }. Rend { order = { { x, y } } (les emplacements choisis dans l'ordre de pose, PUIS les autres candidats par
--- exposition décroissante : repli de la pose), chosen = n, covered = poids couvert en plus, total = poids total }.
function Ce.choose(spec)
  local cands = spec.cands or {}
  local existing = spec.existing or {}
  local range = num(spec.range)
  local count = num(spec.count)
  local cells = Pose.cells(spec.assets)
  local out = { order = {}, chosen = 0, covered = 0, total = 0 }
  for _, c in ipairs(cells) do out.total = out.total + c.w end
  local expo, emax = { max = 0 }, 0
  if spec.center and spec.threats and #spec.threats > 0 then
    expo = Ce.heading(spec.center, spec.threats)
    emax = expo.max
  end
  local function exposure(p)
    if emax <= 0 or not spec.center then return 0 end
    local d = Ce.octant(p.x - spec.center.x, p.y - spec.center.y)
    return d and floor(1000 * expo[d] / emax) or 0
  end
  local rc = range * Pose.COVER_PCT / 100
  local rc2 = rc * rc
  local done = {}
  for i, c in ipairs(cells) do
    done[i] = false
    for _, t in ipairs(existing) do
      if d2(c.x, c.y, t.x, t.y) <= rc2 then done[i] = true break end
    end
  end
  local ex = {}
  for i, p in ipairs(cands) do ex[i] = exposure(p) end
  local picked, chosen_pts = {}, {}
  for _, t in ipairs(existing) do chosen_pts[#chosen_pts + 1] = t end
  local gap = num(spec.gap)
  local lim = gap > 0 and (gap - 1 / 256) * (gap - 1 / 256) or 0
  local n = #cands
  local k = count < n and count or n
  for _ = 1, k do
    local best, best_score, best_gain, best_spaced = nil, -1, 0, false
    for i = 1, n do
      if not picked[i] then
        local p = cands[i]
        local spaced = true
        if lim > 0 then
          for _, t in ipairs(chosen_pts) do
            if d2(p.x, p.y, t.x, t.y) < lim then spaced = false break end
          end
        end
        local gain = 0
        if rc > 0 then
          for j, c in ipairs(cells) do
            if not done[j] and d2(c.x, c.y, p.x, p.y) <= rc2 then gain = gain + c.w end
          end
        end
        -- Un emplacement espacé passe toujours avant un emplacement serré ; puis le gain pondéré par l'exposition ; puis l'exposition ; puis l'ordre.
        local score = gain * (1000 + floor(Ce.EXPO_PCT * ex[i] / 100)) + ex[i] / 1001
        local better
        if best == nil then better = true
        elseif spaced ~= best_spaced then better = spaced
        else better = score > best_score end
        if better then best, best_score, best_gain, best_spaced = i, score, gain, spaced end
      end
    end
    if not best then break end
    picked[best] = true
    out.order[#out.order + 1] = cands[best]
    chosen_pts[#chosen_pts + 1] = cands[best]
    out.covered = out.covered + best_gain
    for j, c in ipairs(cells) do
      if not done[j] and d2(c.x, c.y, cands[best].x, cands[best].y) <= rc2 then done[j] = true end
    end
  end
  out.chosen = #out.order
  -- Repli : les autres candidats, les plus exposés d'abord (ordre d'origine à égalité).
  local rest = {}
  for i = 1, n do if not picked[i] then rest[#rest + 1] = i end end
  table.sort(rest, function(a, b)
    if ex[a] ~= ex[b] then return ex[a] > ex[b] end
    return a < b
  end)
  for _, i in ipairs(rest) do out.order[#out.order + 1] = cands[i] end
  return out
end

---------------------------------------------------------------------------------------------------
-- 5. Bâtiments à couvrir du front
---------------------------------------------------------------------------------------------------

--- Positions des bâtiments « à couvrir » du front : tous les laboratoires, plus les machines de fabrication des cases de 16 tuiles qui en
--- comptent au moins Ce.COVER_TYPES_MIN (une machine isolée d'une ligne de four ne fait pas un site). labs = { { x, y } }, machines = { { x, y } }.
--- Rend { { x, y } } (labos d'abord, puis les machines retenues, dans l'ordre reçu).
function Ce.cover_positions(labs, machines, cell)
  cell = cell or 16
  local out = {}
  for _, p in ipairs(labs or {}) do out[#out + 1] = { x = p.x, y = p.y } end
  local count = {}
  for _, p in ipairs(machines or {}) do
    local k = key(floor(p.x / cell), floor(p.y / cell))
    count[k] = (count[k] or 0) + 1
  end
  for _, p in ipairs(machines or {}) do
    if (count[key(floor(p.x / cell), floor(p.y / cell))] or 0) >= Ce.COVER_TYPES_MIN then out[#out + 1] = { x = p.x, y = p.y } end
  end
  return out
end

return Ce
