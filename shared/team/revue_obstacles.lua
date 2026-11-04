--[[
  Lot AGEBLOCAGE (curseur de la revue des obstacles) : règle PURE de la revue « à tour de rôle » des obstacles d'un projet
  (script/team/build.lua, review_obstacles). Aucun appel au moteur : `has_tree(o)` est donné par l'appelant.

  Défaut corrigé (reproduit hors jeu, mesuré au banc ageblocage-dc 717152950) : l'ancienne boucle faisait n pas à chaque appel ; son
  curseur revenait donc à son départ, et les mêmes Build.OBST_CHECKS obstacles ouverts étaient revus à chaque fois. Si ceux-là gardaient
  un arbre, tous les autres restaient ouverts pour toujours, même vides, et leurs tâches de défrichage revenaient sans fin (Azur : un
  point d'appui défriché 50 fois sur un rectangle vide).
  Règle : on part du curseur, on revoit au plus `checks` obstacles ouverts, et le curseur repart JUSTE APRÈS le dernier revu.
]]

local R = {}

--- obstacles : liste { { done = bool, ... } } ; cur : curseur (1..n, nil = 1) ; checks : obstacles ouverts revus au plus par appel ;
--- has_tree(o) : vrai si un arbre ou un rocher est encore à sa case. Marque `done` les obstacles revus sans arbre. Rend le nombre
--- d'obstacles encore ouverts et le nouveau curseur.
function R.review(obstacles, cur, checks, has_tree)
  local n, left, checked = #obstacles, 0, 0
  if n == 0 then return 0, 1 end
  cur = cur or 1
  if cur < 1 or cur > n then cur = 1 end
  local next_cur = nil
  for step = 0, n - 1 do
    local i = (cur - 1 + step) % n + 1
    local o = obstacles[i]
    if not o.done then
      if checked < checks then
        checked = checked + 1
        next_cur = i % n + 1
        if has_tree(o) then left = left + 1 else o.done = true end
      else
        left = left + 1
      end
    end
  end
  return left, next_cur or cur
end

return R
