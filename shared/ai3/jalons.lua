--[[
  Lot VIDEO-TRACES, partie b (V03) : journal [FO-JALON] des factions, « époque atteinte à la minute t ». PUR : aucune API Factorio,
  testé hors jeu (tests/jalons_test.lua, avec mutants). Le runtime (script/ai3/jalons.lua) lit le niveau d'époque du centre de
  chaque faction et écrit la ligne. Rien ne décide d'après ce journal.

  Règle : une ligne par époque et par faction, JAMAIS deux fois. `seen[id]` = plus haut niveau déjà journalisé pour la faction
  `id` (mémoire persistante, dans l'état du runtime). Un niveau qui recule puis remonte ne redit rien. Un saut (0 à 3) donne les
  trois lignes, dans l'ordre. Le niveau est borné aux 15 époques (shared/content/epochs.lua).

  Aucun `pairs`, aucun hasard, aucun temps mesuré : l'appelant donne le tick.
]]

local J = {}

J.EPOCHS = 15 -- époques de la partie (shared/content/epochs.lua : 15 époques)

--- Époques à journaliser pour la faction `id` quand elle est au niveau `level`. `seen` = { [id] = plus haut niveau déjà
--- journalisé } (mutée). Rend la liste croissante des époques NOUVELLES (k), ou une liste vide.
function J.crossed(seen, id, level)
  local top = seen[id] or 0
  local to = math.min(math.max(math.floor(level or 0), 0), J.EPOCHS)
  local out = {}
  for k = top + 1, to do out[#out + 1] = k end
  if to > top then seen[id] = to end
  return out
end

--- Ligne du journal [FO-JALON] : époque `k` de la faction `id` atteinte à `minutes` minutes de partie.
function J.line(id, k, minutes)
  return string.format("[FO-JALON] %s : epoque %d atteinte a %.1f min", tostring(id), k, minutes)
end

return J
