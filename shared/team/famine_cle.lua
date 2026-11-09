--[[
  FAMINE DE LA PLAQUE CLÉ (lot FAMINE-FER, partie neuve 1618033988, carte Normal 600 %) : règle PURE, aucun nom d'objet.
  Constat mesuré : l'avant-poste de la plaque clé s'arrête à 10 foreuses thermiques dès que sa migration vers le champ électrique DEMANDE une
  bande (script/team/migration_champ.lua : o.migr = "en cours", o.full = true, plus aucune paire de plus), et la bande reste en
  « reserve:materiaux » de 11 à 92 min (84 tapis et 10 foreuses électriques à payer avec du fer que l'équipe n'a pas) : 0 foreuse de fer de
  plus pendant toute la partie, 10 puis 0, contre 24 puis 47 chez scarlet. Boucle : peu de fer -> la bande ne se paie pas -> l'extension thermique
  est gelée en attendant la bande -> peu de fer.
  0.6.75 (chirurgie, graine 1618033988, archive fo-logs/2026-11-09_V0674-F) : `starved` (le manque de la PENSÉE : stock contre ce que la main
  vient de consommer, shared/team/gisement.lua) retombait à faux à 27,2 min pendant que le BESOIN ÉVALUÉ (shared/ai3/reserve.lua, noyau)
  manquait encore de 887 à 1 220 plaques : la famine se refermait, l'avant-poste redevenait « plein », 18 foreuses jusqu'à la fin. La bande
  qui attend en réserve est précisément ce besoin-là : la règle lit aussi `missing` (plaque clé manquante au noyau).
  Règle : tant que la matière de l'avant-poste MANQUE (starved, ou missing > 0) et que sa bande n'a encore rien retiré ni commencé (étape « projet », 0 paire
  retirée, projet du plan en plan, réserve ou attente), l'extension thermique reste ouverte. Dès que la bande commence (paires retirées, chantier),
  la règle se ferme : la migration reprend la main.
]]
local F = {}

--- Projets du plan dont la bande n'a encore rien posé ni retiré.
F.WAITING = { plan = true, reserve = true, attente = true, demande = true }

--- i = { starved (la matière manque par rapport au besoin de la pensée), missing (plaque clé manquante au besoin évalué, nombre), migr (o.migr), stage (étape de la migration), retired (paires retirées),
---       project (état du projet de la bande) } -> vrai si l'extension thermique reste permise.
function F.open(i)
  if not (i and (i.starved or (i.missing or 0) > 0)) then return false end
  if i.migr ~= "en cours" or i.stage ~= "projet" then return false end
  if (i.retired or 0) > 0 then return false end
  return F.WAITING[i.project or ""] == true
end

return F
