--[[
  FAMINE DE LA PLAQUE CLÉ (lot FAMINE-FER, partie neuve 1618033988, carte Normal 600 %) : règle PURE, aucun nom d'objet.
  Constat mesuré : l'avant-poste de la plaque clé s'arrête à 10 foreuses thermiques dès que sa migration vers le champ électrique DEMANDE une
  bande (script/team/migration_champ.lua : o.migr = "en cours", o.full = true, plus aucune paire de plus), et la bande reste en
  « reserve:materiaux » de 11 à 92 min (84 tapis et 10 foreuses électriques à payer avec du fer que l'équipe n'a pas) : 0 foreuse de fer de
  plus pendant toute la partie, 10 puis 0, contre 24 puis 47 chez scarlet. Boucle : peu de fer -> la bande ne se paie pas -> l'extension thermique
  est gelée en attendant la bande -> peu de fer.
  Règle : tant que la matière de l'avant-poste MANQUE (starved) et que sa bande n'a encore rien retiré ni commencé (étape « projet », 0 paire
  retirée, projet du plan en plan, réserve ou attente), l'extension thermique reste ouverte. Dès que la bande commence (paires retirées, chantier),
  la règle se ferme : la migration reprend la main.
]]
local F = {}

--- Projets du plan dont la bande n'a encore rien posé ni retiré.
F.WAITING = { plan = true, reserve = true, attente = true, demande = true }

--- i = { starved (la matière manque par rapport au besoin), migr (o.migr), stage (étape de la migration), retired (paires retirées),
---       project (état du projet de la bande) } -> vrai si l'extension thermique reste permise.
function F.open(i)
  if not (i and i.starved) then return false end
  if i.migr ~= "en cours" or i.stage ~= "projet" then return false end
  if (i.retired or 0) > 0 then return false end
  return F.WAITING[i.project or ""] == true
end

return F
