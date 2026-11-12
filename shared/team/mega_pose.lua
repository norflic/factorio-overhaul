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
  Ne prive pas la défense : refus en crise (survie ou QG menacé), refus si un ennemi est près du gisement. Lot BANDES-PARALLELES : une bande
  avec des paires thermiques dessous part aussi en avance ; son dégel (retrait des paires, matières réunies) est celui de la voie principale
  (Mp.reap : "degel"). Avant, elle était refusée (« paires dessous ») : la 3e bande du fer de départ (le dôme) n'était jamais bâtie.

  Mp.par_max(rec)      -> nombre de bandes en vol au plus pour la décision `rec` { lines }
  Mp.allow(c)          -> vrai/faux, cause. c = { on, power, crisis, enemy, inflight, par_max, main_ready, iron, band_iron }
  Mp.reap(p)           -> "attendre" | "posee" | "perdue" | "bloquee" | "degel" pour l'état d'un projet en avance { state, reason, degele,
                          blocked_for } ("degel" : matières réunies, ses paires thermiques à retirer)
  Mp.saturation(l, s)  -> lot SATURATION (directive du DC du 9/11 : « fabriquer 300 foreuses pour les laisser dans un coffre ne sert à rien ;
                          liez la condition de pose à l'inventaire disponible ») : les pièces d'une bande DÉJÀ au stock. l = { { name, n,
                          machine } } (machine : foreuse ou four), s = { [objet] = n }. Rend { machines (toutes les machines de la bande
                          dorment au stock), all (toutes les pièces), net = { { name, reste } } (ce qu'il reste à fabriquer), dormant, want }.
                          Lecteurs (script/team/migration_champ.lua) : une bande dont les machines dorment part SANS attendre que la plaque
                          manque (porte EXT_PLATES) ni qu'une capitalisation la veuille ; les bandes EN AVANCE s'ouvrent à tout champ ainsi
                          payé (par_cap), et leur fer se compte sur le reste à fabriquer, pas sur la bande entière.
  Déterminisme : aucune horloge, aucune itération sur pairs.
]]

local Mp = {}

Mp.CFG = {
  par_cap = 3,    -- bandes en vol au plus (principale comprise) ; borne aussi la demande de fer et de PNJ d'un seul gisement
  margin = 1.0,   -- bandes de fer qui restent libres en plus de la bande en avance (défense, mall) : fer libre >= (1 + margin) × fer de la bande
  block_max = 15 * 3600, -- ticks : une bande en avance bloquée (fantôme refusé) est laissée au plan et comptée posée (comme step_build)
  start_pct = 30, -- lot SATURATION (DC 9/11, 2e directive : « on pose ce qu'on a, on branche, on complète ensuite ») : part des machines de la
                  -- bande déjà au coffre à partir de laquelle la bande PART (banc V0675-B : bandes de 42 foreuses, 16 à 26 au coffre, seuil
                  -- « toutes » jamais atteint, 0 bande en 90 min)
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
  if (c.inflight or 0) <= 0 then return false, "rien en vol : voie principale" end
  if (c.inflight or 0) >= (c.par_max or 1) then return false, "parallelisme" end
  if not c.main_ready then return false, "matieres de la bande en cours pas reunies" end
  local need = (c.band_iron or 0) * (1 + cfg.margin)
  if (c.iron or 0) < need then return false, string.format("stock : fer libre %d sous %d", math.floor(c.iron or 0), math.ceil(need)) end
  return true, "libre"
end

--- Lot SATURATION : pièces d'une bande déjà au stock. l = { { name, n, machine } } (une entrée par nom), s = { [objet] = n }.
--- `starts` : la bande part sur le stock dormant (au moins cfg.start_pct % de ses machines au coffre) ; `machines` : toutes y sont.
function Mp.saturation(l, s, cfg)
  cfg = cfg or Mp.CFG
  s = s or {}
  local out = { machines = true, all = true, net = {}, dormant = 0, want = 0, starts = false }
  local any = false
  for _, e in ipairs(l or {}) do
    local n, have = e.n or 0, s[e.name] or 0
    if e.machine then
      any = true
      out.want = out.want + n
      out.dormant = out.dormant + math.min(have, n)
    end
    if n > have then
      out.all = false
      if e.machine then out.machines = false end
      out.net[#out.net + 1] = { e.name, n - have }
    end
  end
  if not any then out.machines = false end -- une bande sans machine (réseau seul) n'est jamais « payée par le stock dormant »
  out.starts = any and out.dormant * 100 >= out.want * cfg.start_pct
  return out
end

--- État d'un projet en avance : p = { state, reason, degele, blocked_for } (nil : le projet n'existe plus). "posee" : fini ; "bloquee" : fantôme
--- refusé depuis plus de block_max (laissée au plan, comptée posée) ; "perdue" : projet disparu ou annulé ; "degel" : matières réunies, le plan
--- attend le retrait des paires sous la bande (pas encore dégelée) ; sinon "attendre".
function Mp.reap(p, cfg)
  cfg = cfg or Mp.CFG
  if not p then return "perdue" end
  if p.state == "fini" then return "posee" end
  if p.state == "annule" or p.state == "refuse" then return "perdue" end
  if p.state == "reserve" and p.reason == "degel" and not p.degele then return "degel" end
  if p.state == "bloque" and (p.blocked_for or 0) > cfg.block_max then return "bloquee" end
  return "attendre"
end

return Mp
