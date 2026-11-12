--[[
  Lot ECOLOGIE-5 (directive du DC, 12/11) : avec 5 équipes qui produisent sur la même carte, la pollution est multipliée par 5
  et déclenche des vagues de biters avant que les défenses soient posées. Règle pure : les réglages de carte sont mis à
  l'échelle du nombre d'équipes k, RELATIVEMENT aux valeurs de la carte (un réglage choisi à la création de la partie reste
  la référence), une seule fois par guerre (la valeur appliquée est retenue ; on ne multiplie jamais deux fois).
    - enemy_evolution.pollution_factor        / k   (l'évolution due à la pollution redevient celle d'une seule équipe)
    - pollution.enemy_attack_pollution_consumption_modifier x k (une attaque consomme k fois plus de pollution : k fois moins d'assaillants)
    - pollution.ageing                         x 2   (le sol absorbe deux fois plus : le nuage s'étend moins loin)
    - enemy_expansion.min/max_expansion_cooldown x 2 (les biters s'étendent deux fois moins souvent)
  Aucun réglage nouveau : comportement par défaut d'une guerre.
]]
local E = {}

E.AGEING = 2
E.COOLDOWN = 2

--- Facteurs à appliquer pour passer de l'échelle `applied` (nil ou 1 : rien d'appliqué) à `teams` équipes.
--- Renvoie nil si rien ne change.
function E.factors(teams, applied)
  local k = math.max(1, math.floor(teams or 1))
  local was = applied or 1
  if k == was then return nil end
  local function g(n) return n > 1 and 1 or 0 end -- vieillissement et délais : doublés dès 2 équipes, une seule fois
  local ag = (E.AGEING ^ g(k)) / (E.AGEING ^ g(was))
  local cd = (E.COOLDOWN ^ g(k)) / (E.COOLDOWN ^ g(was))
  return { evolution = was / k, consumption = k / was, ageing = ag, cooldown = cd, k = k }
end

--- Applique les facteurs à une table de réglages de carte (map_settings ou copie de test). Renvoie la nouvelle échelle.
function E.apply(ms, teams, applied)
  local fc = E.factors(teams, applied)
  if not fc then return applied or 1 end
  local ev, po, ex = ms.enemy_evolution, ms.pollution, ms.enemy_expansion
  ev.pollution_factor = ev.pollution_factor * fc.evolution
  po.enemy_attack_pollution_consumption_modifier = po.enemy_attack_pollution_consumption_modifier * fc.consumption
  po.ageing = po.ageing * fc.ageing
  local mn = math.floor(ex.min_expansion_cooldown * fc.cooldown + 0.5)
  local mx = math.floor(ex.max_expansion_cooldown * fc.cooldown + 0.5)
  -- le moteur refuse min > max : on écrit d'abord celui qui garde l'ordre
  if fc.cooldown >= 1 then ex.max_expansion_cooldown = mx; ex.min_expansion_cooldown = mn
  else ex.min_expansion_cooldown = mn; ex.max_expansion_cooldown = mx end
  return fc.k
end

return E
