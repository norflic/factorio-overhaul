--[[
  Sortie de spirale (EFFONDREMENT, partie du DC sur 0.6.58, 7/11 : votre équipe tombée à 2 PNJ, fer libre à 0 de 133 à
  177 min, aucune recrue). Décision du DC (QCM, 7/11 vers 14 h 25), mot pour mot : « je veux toujours n ouvriers minimum,
  donc 12 si 12 au départ. Au delas ça coute des ressources ».
  Lecture du lead : tant que votre équipe est SOUS son effectif de départ (view.recover_floor), la recrue est GRATUITE (ni
  plaques ni kit pris au stock) et ÉQUIPÉE comme une recrue ordinaire (Worker.recruit, free : kit offert, jamais rendu au
  coffre). Au-delà de l'effectif de départ, la recrue est payée comme avant (kit + (10 + effectif) fer, shared/team/org.lua).
  Les factions (view.emergency) ne changent pas.
  Avant (0.6.58) : la recrue de reprise n'était faite que si le livre trouvait TOUTES ses plaques au stock libre
  (shared/team/planner.lua, « Correction VERIF-NUIT ») ; sans elles, rien (boucle B1 de docs/IA_WORKFLOW.md).
  Lecteurs de la règle : le planificateur (recrue de reprise), le stock virtuel et le besoin évalué du cerveau
  (shared/ai3/cerveau.lua), le budget de la pile (shared/ai3/pile.lua), le paiement en E4 (script/team/team.lua).
  Lua PUR, arithmétique seule.
]]

local Sp = {}

--- La recrue de cette vue est-elle gratuite ? v = { workers, recover_floor (votre équipe), emergency (factions) }.
function Sp.free(v)
  if not v or v.emergency then return false end
  local floor = v.recover_floor
  return floor ~= nil and (v.workers or 0) < floor
end

--- Coût d'une recrue sous la règle : liste vide si elle est gratuite, sinon `cost` tel quel.
function Sp.cost(v, cost)
  if Sp.free(v) then return {} end
  return cost
end

--[[
  Journal [FO-RECRUE] (choix (1) du lead, 7/11 : la garde QGSURVIE est GARDÉE, la recrue gratuite attend la fin de la menace) : pour
  que le DC voie pourquoi personne ne revient, une ligne « recrue gratuite retenue : garde QG (biters à N tuiles, 0 tourelle armée) »,
  au plus une par Sp.LOG_EVERY ticks. Journal seul : aucune décision ne le lit.
]]
Sp.LOG_EVERY = 3600 -- 1 min

--- Une ligne [FO-RECRUE] est-elle due ? last = tick de la dernière ligne (nil : jamais), tick = maintenant.
function Sp.log_due(last, tick)
  return last == nil or (tick or 0) - last >= Sp.LOG_EVERY
end

--- Texte de la ligne. a = { key, dist (tuiles du coffre au biter le plus proche, nil : inconnu), biters, armed, workers, floor, minutes }.
function Sp.held_text(a)
  a = a or {}
  return string.format("[FO-RECRUE] %s : recrue gratuite retenue : garde QG (biters a %s tuiles, %d tourelle(s) armee(s)) ; " ..
    "%d biter(s) a portee du coffre, effectif %d/%d a %.1f min", tostring(a.key or "?"),
    a.dist and string.format("%d", math.floor(a.dist + 0.5)) or "?", a.armed or 0, a.biters or 0, a.workers or 0, a.floor or 0,
    a.minutes or 0)
end

return Sp
