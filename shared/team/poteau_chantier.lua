--[[
  Lot POTEAU-CHANTIER (0716) : règle PURE du repli des poteaux d'un CHANTIER en réserve. Le poteau prévu par le plan n'est pas fabricable
  faute de matière (partie 0.7.122 : « 8 projet(s) attendent de la matiere (manque medium-electric-pole 26) ») : le plan remplace ses poteaux
  par le meilleur poteau fabricable (shared/team/reconstruction.lua, Rc.pick_chain : même ordre que la reconstruction), pose des RELAIS sur les
  segments trop longs pour son fil (Rc.chain_points) et COMPENSE sa zone d'alimentation plus petite : chaque machine électrique du chantier que
  plus aucun poteau ne couvre reçoit un poteau à côté d'elle, relié au réseau par le fil.
  Lua pur : aucune API du jeu, aucun nom d'objet ; positions en tuiles, centres de tuile en x.5 ; listes triées.
]]

local Pc = {}

Pc.WAIT = 2 * 3600 -- ticks : le poteau prévu doit manquer (ni au coffre, ni fabricable) depuis 2 min avant le repli
Pc.RING = 3        -- tuiles : distance au bord de la machine essayée pour un poteau de compensation
Pc.RETRY = 1800    -- ticks : un repli impossible (tuiles prises) est réessayé 30 s plus tard (le chantier peut avoir bougé)

--- La zone d'alimentation (demi-côté `supply`) d'un poteau en (px, py) touche-t-elle la boîte { x0, y0, x1, y1 } ?
function Pc.covers(px, py, supply, box)
  return px + supply > box.x0 and px - supply < box.x1 and py + supply > box.y0 and py - supply < box.y1
end

local function dist(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

--- Poteaux de compensation. `machines` = { { key, box } } (triées par l'appelant) ; `poles` = { { x, y, supply } } (réseau prévu, après
--- substitution et relais) ; `supply`, `wire` : le poteau de repli ; `free(x, y)` : la tuile est libre. Rend (ajouts { {x, y} },
--- machines restées sans courant { key }).
function Pc.compensate(machines, poles, supply, wire, free)
  local net = {}
  for _, p in ipairs(poles) do net[#net + 1] = { x = p.x, y = p.y, supply = p.supply or supply } end
  local added, lost, taken = {}, {}, {}
  for _, m in ipairs(machines) do
    local ok = false
    for _, p in ipairs(net) do
      if Pc.covers(p.x, p.y, p.supply, m.box) then ok = true break end
    end
    if not ok then
      local best, bd = nil, math.huge
      for r = 1, Pc.RING do
        for ty = math.floor(m.box.y0) - r, math.ceil(m.box.y1) + r - 1 do
          for tx = math.floor(m.box.x0) - r, math.ceil(m.box.x1) + r - 1 do
            local c = { x = tx + 0.5, y = ty + 0.5 }
            if not taken[c.x .. "," .. c.y] and Pc.covers(c.x, c.y, supply, m.box) and free(c.x, c.y) then
              local near = math.huge
              for _, p in ipairs(net) do near = math.min(near, dist(c, p)) end
              if near <= wire and near < bd then best, bd = c, near end
            end
          end
        end
        if best then break end
      end
      if best then
        net[#net + 1] = { x = best.x, y = best.y, supply = supply }
        taken[best.x .. "," .. best.y] = true
        added[#added + 1] = best
      else
        lost[#lost + 1] = m.key
      end
    end
  end
  return added, lost
end

--- Relais d'UN segment, du poteau `a` au voisin `b`, au fil `wire` : points de Rc.chain_points (`pts`, dans l'ordre de a vers b), chacun
--- DÉCALÉ si sa tuile est prise vers la tuile libre la plus proche (jusqu'à Pc.NUDGE tuiles) qui garde chaque pas ≤ wire (point précédent
--- posé, point suivant prévu ; le dernier pas vers b est contrôlé à la fin). Rend la liste posée ou nil (aucune tuile ne tient).
Pc.NUDGE = 2
function Pc.place_chain(a, b, pts, wire, free)
  local out, prev = {}, a
  for i, q in ipairs(pts) do
    local nxt = pts[i + 1] or b
    local best, bd = nil, math.huge
    for r = 0, Pc.NUDGE do
      for dy = -r, r do
        for dx = -r, r do
          if math.max(math.abs(dx), math.abs(dy)) == r then
            local c = { x = q.x + dx, y = q.y + dy }
            if dist(c, prev) <= wire and dist(c, nxt) <= wire and free(c.x, c.y) then
              local d = dx * dx + dy * dy
              if d < bd then best, bd = c, d end
            end
          end
        end
      end
      if best then break end
    end
    if not best then return nil end
    out[#out + 1] = best
    prev = best
  end
  if dist(prev, b) > wire then return nil end
  return out
end

return Pc
