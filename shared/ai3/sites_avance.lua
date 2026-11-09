--[[
  Lot EXPLORATION-FER (demande du chef d'équipe, 9/11 : « anticipe la demande d'exploration du fer : elle part quand les sites de fer connus
  hors avant-postes passent sous un seuil, au lieu d'attendre "sites 0" à 11-24 min »). PUR : aucune API Factorio, aucun nom d'objet (le type
  clé arrive en donnée : ressource la plus demandée déduite, shared/ai3/buts.lua B.key).

  Mesuré (fo-logs/2026-11-09_ZERO-IDLE-3, étape 1 guide) : le fer n'est cherché qu'une fois « plein et sites 0 » (shared/ai3/extension.lua,
  script/team/poles.lua) : exploration du fer demandée à 19,6 min (scarlet) et 10,9 min (votre équipe, rien trouvé en 30 min), pendant que
  le manque de plaques de fer tenait 7 PNJ sur 8 sans tâche. Un avant-poste de fer demande ~10 min pour se remplir : l'exploration, qui prend
  de 0,5 à 9 min, doit partir AVANT que le dernier site connu soit pris.

  Règle : pour le type clé, avec au moins un avant-poste, moins de `S.MIN_SITES` sites admissibles connus (hors avant-postes), ni menace sur le QG
  ni retenue de l'équipe : l'équipe veut `S.MIN_SITES` sites (f.site_needs) et l'exploration part dès qu'il en manque (script/ai3/exploration.lua,
  f.site_soon). Elle ne retire aucun PNJ d'une tâche : l'éclaireur est un PNJ libre (pick_idle).

  Déterminisme : entiers, aucune horloge.
]]

local S = {}

S.ON = false      -- ETEINT par defaut (fo-logs/2026-11-09_EXPLORATION-FER : 3 graines, demande de fer des 7 min mais 2e site pas plus tot, plaques a 94 % ; voir RD_LOG) ; vrai : la regle anticipee
S.MIN_SITES = 2 -- sites admissibles connus voulus pour le type clé avant que le dernier soit pris

--- Nombre de sites voulus d'avance pour le type clé (0 : la règle d'avant, rien d'anticipé).
--- a = { outposts = avant-postes du type clé, sites = sites admissibles connus du type, threat = QG menacé, hold = retenue (survie, effectif) }
function S.wanted(a)
  if not S.ON or not a or a.threat or a.hold then return 0 end
  if (a.outposts or 0) < 1 then return 0 end
  if (a.sites or 0) >= S.MIN_SITES then return 0 end
  return S.MIN_SITES
end

--- Le type est-il à court de sites, vu de l'exploration ? `available` : sites admissibles de la ressource, `need` : f.site_needs[ressource],
--- `soon` : f.site_soon[ressource] (nil : pas d'anticipation). Vrai : demande ouverte.
function S.short(available, need, soon)
  if (need or 0) <= 0 then return false end
  if (available or 0) == 0 then return true end
  return soon ~= nil and (available or 0) < soon
end

return S
