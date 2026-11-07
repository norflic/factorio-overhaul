--[[
  Lot CERVEAU-CENTRAL (P1, 5/11) : tri d'entités par distance à un point, positions lues UNE fois.

  Les deux tris des tuiles de minage (script/team/worker.lua, programme d'un minage ; script/ai3/comportement.lua,
  M.retarget_mine) lisaient `.position` (un appel au moteur qui fabrique une table) dans le comparateur : moteur simulé,
  4 factions × 30 PNJ, 250 tuiles en moyenne, 1 958 comparaisons, soit au moins 3 917 lectures par tri
  (fo-logs/2026-11-05_CERVEAU-CENTRAL/mesures). Ici, n lectures.

  Même ordre, égalités comprises : les réponses du comparateur sont les mêmes, paire par paire (mêmes nombres, même
  fonction de distance passée par l'appelant), et le tableau de départ est dans le même ordre ; `table.sort` ne dépend
  que de ces réponses, donc la permutation est la même. Preuve hors jeu : tests/cerveau_central_test.lua (ancien tri
  contre celui-ci, avec mutants).
]]

local Tp = {}

--- Trie `list` en place comme
---   table.sort(list, function(a, b)
---     local da, db = dist2(a.position, c), dist2(b.position, c)
---     if da ~= db then return da < db end
---     if a.position.x ~= b.position.x then return a.position.x < b.position.x end
---     return a.position.y < b.position.y
---   end)
--- mais en lisant `.position` une seule fois par élément. `dist2(p, c)` : la fonction de distance de l'appelant (la même
--- arithmétique que son ancien comparateur). Rend `list`.
function Tp.sort(list, c, dist2)
  local n = #list
  local recs = {}
  for i = 1, n do
    local e = list[i]
    local p = e.position
    recs[i] = { e = e, x = p.x, y = p.y, d = dist2(p, c) }
  end
  table.sort(recs, function(a, b)
    if a.d ~= b.d then return a.d < b.d end
    if a.x ~= b.x then return a.x < b.x end
    return a.y < b.y
  end)
  for i = 1, n do list[i] = recs[i].e end
  return list
end

return Tp
