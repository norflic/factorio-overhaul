--[[
  Lot TV-PLACE, point G57 (docs/TODO_VIDEO.md l.234 : « Sonde : 10 × 10 par tuile » ; script/faction/sites.lua:59, MIN_RESOURCES = 24 par
  CHUNK). Règle PURE, testée hors jeu : tests/sonde10_test.lua.

  Le défaut. La prospection des sites (script/faction/sites.lua, probe) compte les tuiles de ressource d'un CHUNK de 32 × 32 et exige
  MIN_RESOURCES = 24 : un gisement coupé par la frontière de deux chunks (12 + 12 tuiles) n'atteint le seuil dans aucun des deux et reste
  invisible (E16, session 4 : « sans cela 3 factions sur 4 ne trouvaient jamais de 2e gisement de fer »).

  La règle de la vidéo : sonder des FENÊTRES de 10 × 10, sans égard aux frontières. Ici elle COMPLÈTE le test par chunk (ce qui était trouvé
  l'est toujours) : un chunk qui n'atteint pas le seuil est relu sur sa zone élargie de S.REACH tuiles ; si une fenêtre de 10 × 10 y porte
  au moins S.MIN tuiles, le gisement est retenu, et lu sur une zone de 32 × 32 CENTRÉE sur la fenêtre. Pour qu'un gisement à cheval ne soit pas
  annoncé par ses quatre chunks, seul le chunk qui contient le centre de la fenêtre le retient.
  Le moteur ne fait qu'un `count` bon marché (zone élargie) avant d'appeler cette règle ; les positions ne sont lues que si le seuil y est atteint.
  Déterminisme : points triés (x, puis y), égalités départagées par la fenêtre la plus au nord-ouest.
]]

local S = {}

S.SIZE = 10        -- côté de la fenêtre de sonde (G57)
S.MIN = 24         -- tuiles de ressource par fenêtre (égal à MIN_RESOURCES de script/faction/sites.lua : le même seuil, sur une surface plus fine)
S.REACH = 10       -- tuiles lues au-delà du chunk
S.AREA = 32        -- côté de la zone de lecture du site, centrée sur la fenêtre
S.MAX_POINTS = 600 -- tuiles lues au plus (borne du coût)

--- Zone élargie d'un chunk (cx, cy) : x0, y0, x1, y1 en tuiles.
function S.expanded(cx, cy)
  return cx * 32 - S.REACH, cy * 32 - S.REACH, cx * 32 + 32 + S.REACH, cy * 32 + 32 + S.REACH
end

--- Meilleure fenêtre de S.SIZE × S.SIZE. points = liste de { x, y } (tuiles entières). Rend { x0, y0, n, cx, cy } (n tuiles, barycentre) ou nil.
function S.best_window(points, size)
  size = size or S.SIZE
  local pts = {}
  for _, p in ipairs(points or {}) do
    if type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" then pts[#pts + 1] = { x = math.floor(p.x), y = math.floor(p.y) } end
  end
  table.sort(pts, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
  while #pts > S.MAX_POINTS do pts[#pts] = nil end
  local best
  local last_x
  for idx, p in ipairs(pts) do
    local x0 = p.x
    if x0 ~= last_x then
      last_x = x0
      local col = {}
      for j = idx, #pts do
        if pts[j].x >= x0 + size then break end
        col[#col + 1] = pts[j]
      end
      table.sort(col, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
      local lo = 1
      for hi = 1, #col do
        while col[hi].y - col[lo].y >= size do lo = lo + 1 end
        local n = hi - lo + 1
        if not best or n > best.n then
          best = { x0 = x0, y0 = col[lo].y, n = n, lo = lo, hi = hi, col = col }
        end
      end
    end
  end
  if not best then return nil end
  local sx, sy = 0, 0
  for i = best.lo, best.hi do sx, sy = sx + best.col[i].x + 0.5, sy + best.col[i].y + 0.5 end
  return { x0 = best.x0, y0 = best.y0, n = best.n, cx = sx / best.n, cy = sy / best.n }
end

--- Le gisement de la fenêtre `win` est-il retenu par le chunk (ccx, ccy) ? Au moins S.MIN tuiles et barycentre dans ce chunk.
function S.retained(win, ccx, ccy)
  if not win or win.n < S.MIN then return false end
  return math.floor(win.cx / 32) == ccx and math.floor(win.cy / 32) == ccy
end

--- Zone de lecture du site (S.AREA × S.AREA centrée sur le barycentre de la fenêtre) : { { x0, y0 }, { x1, y1 } }.
function S.read_area(win)
  local x0 = math.floor(win.cx - S.AREA / 2 + 0.5)
  local y0 = math.floor(win.cy - S.AREA / 2 + 0.5)
  return { { x0, y0 }, { x0 + S.AREA, y0 + S.AREA } }
end

return S
