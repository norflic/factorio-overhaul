--[[
  Lot RESEAU-VIVANT : COUVRIR les consommateurs qu'aucun poteau n'alimente (constat du DC, 28/10 : « ils sont incapables de détecter
  des zones qui ne sont pas couvertes »). Mesuré le 29/10 sur 20261020 (relevé [FO-FONCTION] reseau, minute 60) : chaque équipe a 3 ou
  4 consommateurs sous AUCUN poteau (les laboratoires), 0 sur le réseau, alors que les poteaux perdus ne l'expliquent pas.
  Lua PUR : aucune API du jeu, aucun nom d'objet. Cette règle ne fait que PROPOSER des positions candidates de poteaux (tuiles
  libres autour des consommateurs découverts et le long d'un couloir vers le poteau vivant le plus proche) ; le choix du plus petit
  ensemble qui relie tout est fait par R.repair (shared/team/reseau.lua, coût minimal), l'exécution par script/team/build.lua.
  Déterminisme : candidats triés (y, x) ; aucune horloge, aucun hasard, aucun pairs.
]]

local C = {}

C.STEP = 2        -- pas (tuiles) de la grille de couloir
C.MAX = 360       -- candidats au plus par décision (coût de R.repair)
C.REACH_MAX = 36  -- tuiles : un consommateur plus loin que cela du poteau vivant le plus proche n'est pas traité

local floor, max, min = math.floor, math.max, math.min

local function center(b) return (b.x0 + b.x1) / 2, (b.y0 + b.y1) / 2 end

--- boxes : consommateurs découverts { x0, y0, x1, y1 } ; poles : poteaux vivants { x, y } (réseau d'une centrale) ;
--- free(tx, ty) : la tuile peut recevoir un poteau ; o = { supply = demi-côté de l'aire d'alimentation (2,5), wire, step, max }.
--- Rend { cands = liste { x, y, wire, supply, cost = 1 } triée (y, x), skipped = consommateurs hors d'atteinte, near = {box -> indice du
--- poteau vivant le plus proche} }.
function C.candidates(boxes, poles, free, o)
  o = o or {}
  local supply, wire = o.supply or 2.5, o.wire or 7.5
  local step, limit = o.step or C.STEP, o.max or C.MAX
  local seen, cover, grid = {}, {}, {}
  local skipped = {}
  local order = {}
  for i = 1, #boxes do order[i] = i end
  table.sort(order, function(a, b)
    if boxes[a].y0 ~= boxes[b].y0 then return boxes[a].y0 < boxes[b].y0 end
    if boxes[a].x0 ~= boxes[b].x0 then return boxes[a].x0 < boxes[b].x0 end
    return a < b
  end)
  -- les tuiles sont d'abord seulement NOTÉES ; `free` (coûteux : une question au moteur) n'est posée qu'en ordre de tri, jusqu'à la borne
  local function add(list, tx, ty)
    local k = tx * 200003 + ty
    if seen[k] then return end
    seen[k] = true
    list[#list + 1] = { tx = tx, ty = ty }
  end
  for _, i in ipairs(order) do
    local b = boxes[i]
    local cx, cy = center(b)
    local qi, qd
    for j, p in ipairs(poles) do
      local d = (p.x - cx) ^ 2 + (p.y - cy) ^ 2
      if not qd or d < qd - 1e-9 then qi, qd = j, d end
    end
    if not qi or qd > C.REACH_MAX * C.REACH_MAX then
      skipped[#skipped + 1] = i
    else
      local q = poles[qi]
      -- tuiles dont l'aire d'alimentation chevauche la boîte : ce sont elles qui COUVRENT le consommateur
      local x0, y0 = floor(b.x0 - supply), floor(b.y0 - supply)
      local x1, y1 = floor(b.x1 + supply), floor(b.y1 + supply)
      for ty = y0, y1 do for tx = x0, x1 do add(cover, tx, ty) end end
      -- couloir vers le poteau vivant : grille de pas `step` dans le rectangle englobant, marge 2
      local rx0, ry0 = floor(min(b.x0, q.x)) - 2, floor(min(b.y0, q.y)) - 2
      local rx1, ry1 = floor(max(b.x1, q.x)) + 2, floor(max(b.y1, q.y)) + 2
      for ty = ry0, ry1 do
        if (ty - ry0) % step == 0 then
          for tx = rx0, rx1 do
            if (tx - rx0) % step == 0 then add(grid, tx, ty) end
          end
        end
      end
    end
  end
  local out = {}
  local function emit(list)
    table.sort(list, function(a, b) if a.ty ~= b.ty then return a.ty < b.ty end return a.tx < b.tx end)
    for _, t in ipairs(list) do
      if #out >= limit then return end
      if free(t.tx, t.ty) then out[#out + 1] = { x = t.tx + 0.5, y = t.ty + 0.5, wire = wire, supply = supply, cost = 1 } end
    end
  end
  emit(cover)
  emit(grid)
  table.sort(out, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
  return { cands = out, skipped = skipped }
end

return C
