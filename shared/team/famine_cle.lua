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
  Règle : tant que la matière de l'avant-poste MANQUE (starved, ou missing > 0) et que sa bande n'a encore rien BÂTI (projet du plan en vol, 0 entité
  bâtie), l'extension thermique reste ouverte. Dès que la bande commence (une entité bâtie au moins), la règle se ferme : la migration reprend la main.
  CHANTIER-GELE (B5, graine 123456789, archive fo-logs/2026-11-09_V0675-B) : « commencée » valait « étape chantier ou paires retirées » : la bande -30
  (projet 5) passait en « chantier » par le dégel à 85,9 min avec 3 paires retirées et 0 entité bâtie sur 720 ; la famine se fermait (iron=plein à
  86-90 min) alors que rien n'était bâti. Directive du DC (9/11) : une bande n'est commencée qu'avec une entité bâtie au moins.
]]
local F = {}

--- s43 regr-fer2 : ticks sans entité de plus posée au-delà desquels une bande commencée ne ferme plus l'extension thermique (seuil du
--- chantier lent de shared/team/migration_retour.lua).
F.STUCK = 15 * 3600

--- États d'un projet du plan dont la bande est EN VOL (demandée, pas finie ni refusée) : avec 0 entité bâtie, elle n'a pas commencé.
F.WAITING = { plan = true, reserve = true, attente = true, demande = true, defrichage = true, fantomes = true, chantier = true, raccordement = true, bloque = true }

--- i = { starved (la matière manque par rapport au besoin de la pensée), missing (plaque clé manquante au besoin évalué, nombre), migr (o.migr),
---       built (entités bâties du projet de la bande), project (état du projet de la bande, nil sans bande en vol),
---       stalled (s43 : ticks sans progrès de la bande, facultatif) } -> vrai si l'extension thermique reste permise.
function F.open(i)
  if not (i and (i.starved or (i.missing or 0) > 0)) then return false end
  if i.migr ~= "en cours" then return false end
  -- s43 regr-fer2 (banc s43-parite-seule, graine 271828182, lot s42-gisements) : la bande de fer de votre équipe, partie avec toute sa matière,
  -- a retiré 5 paires puis s'est arrêtée à 348 entités sur 382 (tapis, charbon, bras sans fer) ; « presque finie », elle n'est jamais reposée
  -- (shared/team/migration_retour.lua, near_done) et l'extension thermique restait fermée : 13 paires de fer à 12 min, 1 à 39 min, fer 0.
  -- Une bande commencée mais SANS PROGRÈS depuis F.STUCK ticks (i.stalled) rouvre l'extension thermique tant que la plaque clé manque.
  if (i.built or 0) > 0 then return (i.stalled or 0) >= F.STUCK end
  return F.WAITING[i.project or ""] == true
end

return F
