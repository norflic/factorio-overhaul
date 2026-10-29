--[[
  Lot RESEAU-VIVANT : PONTS entre un îlot de poteaux et le réseau d'une centrale. PUR : aucune API Factorio, aucun nom d'objet
  (tests/reseau_pont_test.lua). Le moteur donne l'identifiant de réseau de chaque poteau ; cette règle cherche, pour chaque réseau
  qui porte des consommateurs SANS courant (un îlot), le plus court écart de poteau à poteau avec un réseau alimenté par une
  centrale, et répond la paire à relier. La pose elle-même (chaîne de poteaux, tuiles libres) est à l'appelant
  (shared/team/plan.lua P.pole_chain + script/team/build.lua Build.bridge).

  Constat (moteur réel, 4 graines du lot MESURES et RESEAUV) : des îlots de 13 à 20 tuiles du réseau principal restent 10 à 30 min
  (graine 1618033988 : 81 consommateurs) sans qu'aucun poteau PERDU ne les explique ; le plan de réparation par poteaux perdus
  (shared/team/reseau.lua R.repair) ne peut rien pour eux.
  Déterminisme : parcours par indices croissants, égalités à l'indice le plus petit.
]]

local B = {}

B.MAX_GAP = 45   -- tuiles : au-delà, ce n'est pas un pont mais une ligne (hors de ce lot)

--- poles[i] = { x, y, id, wire } ; need = { [id réseau] = true } réseaux à relier ; live = { [id réseau] = true } réseaux alimentés.
--- Rend une liste triée (écart croissant, puis id) de { id, a, b, d, reach } : a = poteau de l'îlot, b = poteau alimenté, d = écart
--- (tuiles), reach = portée de fil commune. `d <= reach` : déjà à portée de fil (rien à poser : le moteur ne les a pas reliés).
function B.gaps(poles, need, live, maxgap)
  maxgap = maxgap or B.MAX_GAP
  local best = {}
  local ids = {}
  for i, p in ipairs(poles) do
    if p.id and need[p.id] and not live[p.id] and best[p.id] == nil then
      best[p.id] = false
      ids[#ids + 1] = p.id
    end
  end
  table.sort(ids)
  local out = {}
  for _, id in ipairs(ids) do
    local bd, ba, bb
    for i, p in ipairs(poles) do
      if p.id == id then
        for j, q in ipairs(poles) do
          if q.id and live[q.id] then
            local dx, dy = p.x - q.x, p.y - q.y
            local d = math.sqrt(dx * dx + dy * dy)
            if not bd or d < bd - 1e-9 then bd, ba, bb = d, i, j end
          end
        end
      end
    end
    if bd and bd <= maxgap then
      local reach = math.min(poles[ba].wire or 0, poles[bb].wire or 0)
      out[#out + 1] = { id = id, a = ba, b = bb, d = bd, reach = reach }
    end
  end
  table.sort(out, function(x, y)
    if x.d ~= y.d then return x.d < y.d end
    return x.id < y.id
  end)
  return out
end

--- Un pont est-il utile ? Il faut un écart non nul et une portée de fil (un poteau sans portée ne relie rien).
function B.useful(g)
  return g.reach > 0 and g.d > 0
end

return B
