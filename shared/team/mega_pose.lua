--[[
  MÉGA-FONDERIE, tranche 2 (A2) : RÈGLE PURE du parallélisme des bandes d'un gisement à méga-fonderie décidée (lot MEGA-FONDERIE,
  docs/MEGA_FONDERIE.md). Lua pur : aucun moteur, aucun nom d'objet.

  Problème (mesuré, partie géants-b36e23b2 : votre équipe 1,6 pour mille d'un gisement géant, 0 foreuse électrique) : la migration du champ
  (script/team/migration_champ.lua) ne bâtit qu'UNE bande à la fois par gisement (créneau, Th.free_slot : un chantier par minerai) ; une bande
  attend ses matières, puis ses PNJ, puis son courant, et la suivante ne part qu'à la fin. Sur un gisement de 1 000 tuiles (122 foreuses en
  bandes) la couverture de 50 % à 40 min est hors d'atteinte en file simple.

  Levier A2 (validé par le lead le 8/11 avec ses garde-fous) : une bande DE PLUS (« bande en avance ») est demandée au plan directeur pendant
  que la bande principale est déjà au chantier. Le parallélisme est BORNÉ :
    1. par le nombre de lignes de bus décidé (Mp.par_max : au plus Mp.CFG.par_cap bandes en vol, jamais plus que de lignes) ;
    2. par ce que le stock PAIE : le fer libre (déjà net des réserves des projets en cours) couvre la bande en avance ET une marge d'une
       bande (Mp.CFG.margin) qui reste à la défense et au mall ;
    3. par l'ÉTAT de la bande principale : ses matières sont réunies (elle est au chantier), sinon deux bandes se disputeraient les mêmes
       pièces ; la première bande part toujours par la voie principale (inflight 0 : « voie principale »).
  Ne prive pas la défense : refus en crise (survie ou QG menacé), refus si un ennemi est près du gisement. Une bande avec des paires
  thermiques dessous passe par la voie principale (retrait, dégel, retour en arrière) : jamais en avance.

  Mp.par_max(rec)      -> nombre de bandes en vol au plus pour la décision `rec` { lines }
  Mp.allow(c)          -> vrai/faux, cause. c = { on, power, crisis, enemy, pairs_under, inflight, par_max, main_ready, iron, band_iron }
  Mp.reap(p)           -> "attendre" | "posee" | "perdue" | "bloquee" pour l'état d'un projet en avance { state, blocked_for }
  Déterminisme : aucune horloge, aucune itération sur pairs.
]]

local Mp = {}

Mp.CFG = {
  par_cap = 3,    -- bandes en vol au plus (principale comprise) ; borne aussi la demande de fer et de PNJ d'un seul gisement
  margin = 1.0,   -- bandes de fer qui restent libres en plus de la bande en avance (défense, mall) : fer libre >= (1 + margin) × fer de la bande
  block_max = 15 * 3600, -- ticks : une bande en avance bloquée (fantôme refusé) est laissée au plan et comptée posée (comme step_build)
}

--- Bandes en vol au plus pour une décision { lines } : jamais plus que de lignes de bus, au plus par_cap, au moins 1.
function Mp.par_max(rec, cfg)
  cfg = cfg or Mp.CFG
  local lines = math.floor(tonumber(rec and rec.lines) or 1)
  if lines < 1 then lines = 1 end
  return math.min(cfg.par_cap, lines)
end

--- Une bande de plus peut-elle partir en avance ? Rend (vrai, "libre") ou (faux, cause).
function Mp.allow(c, cfg)
  cfg = cfg or Mp.CFG
  if not c.on then return false, "decision absente" end
  if c.crisis then return false, "crise" end
  if not c.power then return false, "aucun reseau qui produit" end
  if c.enemy then return false, "ennemi" end
  if (c.pairs_under or 0) > 0 then return false, "paires dessous : voie principale" end
  if (c.inflight or 0) <= 0 then return false, "rien en vol : voie principale" end
  if (c.inflight or 0) >= (c.par_max or 1) then return false, "parallelisme" end
  if not c.main_ready then return false, "matieres de la bande en cours pas reunies" end
  local need = (c.band_iron or 0) * (1 + cfg.margin)
  if (c.iron or 0) < need then return false, string.format("stock : fer libre %d sous %d", math.floor(c.iron or 0), math.ceil(need)) end
  return true, "libre"
end

--- État d'un projet en avance : p = { state, blocked_for } (nil : le projet n'existe plus). "posee" : fini ; "bloquee" : fantôme refusé depuis
--- plus de block_max (laissée au plan, comptée posée) ; "perdue" : projet disparu ou annulé ; sinon "attendre".
function Mp.reap(p, cfg)
  cfg = cfg or Mp.CFG
  if not p then return "perdue" end
  if p.state == "fini" then return "posee" end
  if p.state == "annule" or p.state == "refuse" then return "perdue" end
  if p.state == "bloque" and (p.blocked_for or 0) > cfg.block_max then return "bloquee" end
  return "attendre"
end

return Mp
