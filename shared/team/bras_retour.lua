--[[
  Lot PLANDIR : migration des bras de la centrale. PUR (aucune API Factorio, aucun nom d'objet), testé hors jeu par
  tests/bras_retour_test.lua (avec mutants).

  Les versions 0.6.5 à 0.6.7 passaient les bras de la centrale (chaudières, quai) à l'électrique dès le premier courant et
  marquaient leur entrée du plan `was_burner = true`, en la renommant du bras électrique. Mesuré le 28/10 : sur une chaudière, un
  bras électrique est un blackout en attente (la centrale meurt en 1,5 à 3,5 min et ne repart pas). Une sauvegarde de ces
  versions peut en garder : au premier relevé du moniteur, ils repassent à combustion (le bras à combustion se recharge seul).

  Seules les entrées du plan de la centrale portant `was_burner` sont concernées : un bras du joueur, un bras d'un module (jamais
  marqué) et une entrée déjà à combustion ne sont jamais touchés.
]]
local B = {}

--- Indices des entrées à repasser à combustion : marquées `was_burner` et pas déjà du bras `burner`. Liste triée.
function B.to_restore(entries, burner)
  local out = {}
  for i, e in ipairs(entries or {}) do
    if e.was_burner and e.name ~= burner then out[#out + 1] = i end
  end
  return out
end

--- L'entrée `e` est repassée à combustion (l'appelant a remplacé le bras réel) : nom et objet du bras à combustion, marque levée.
function B.restored(e, burner)
  e.name, e.item, e.was_burner = burner, burner, nil
  return e
end

--- Entrées encore à repasser après un relevé : nombre (0 : migration finie, plus aucun travail aux relevés suivants).
function B.remaining(entries, burner)
  return #B.to_restore(entries, burner)
end

return B
