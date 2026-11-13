--[[
  Sprint s41 (labos) : la construction par robots est un OBJET VOULU de votre équipe. Lua PUR, aucun nom d'objet, de recette ni de
  technologie : seuls des TYPES de prototype du moteur (comme shared/ai3/reglages.lua).

  Constat du DC (3 h 30 de jeu) : la recherche qui ouvre la construction par robots n'était voulue par aucune règle. Les objets qui
  posent une entité d'un type de Cr.TYPES et dont AUCUNE recette n'est ouverte sont déclarés voulus (script/ai3/cerveau.lua,
  research_step) : le cerveau général (shared/ai3/general.lua) donne alors sa valeur à la technologie qui les ouvre et à sa chaîne, et
  la fait passer devant quand elle est proche (Gen.k1, « voulue proche devant »). Dès qu'une recette de l'objet est ouverte, il n'est
  plus voulu : rien d'autre ne change.
]]
local Cr = {}

-- Types d'entité du moteur de la construction par robots (ordre fixe ; seules données nommées : shared/ai3/reglages.lua).
Cr.TYPES = require("shared.ai3.reglages").ROBOT_BUILD_TYPES

--- list = { { item, recipe } } dans un ordre fixe (toutes les recettes qui produisent un objet de la construction par robots) ;
--- is_open(recette) -> vrai si la force sait déjà la faire. Rend { [objet] = vrai } des objets sans aucune recette ouverte, ou nil.
function Cr.wanted(list, is_open)
  local open, seen, order = {}, {}, {}
  for _, e in ipairs(list or {}) do
    if not seen[e.item] then seen[e.item] = true; order[#order + 1] = e.item end
    if is_open and is_open(e.recipe) then open[e.item] = true end
  end
  local out, n = {}, 0
  for _, it in ipairs(order) do
    if not open[it] then out[it] = true; n = n + 1 end
  end
  if n == 0 then return nil end
  return out
end

return Cr
