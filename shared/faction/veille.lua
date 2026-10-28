--[[
  Lot VEILLE (28/10) : RECONNAISSANCE RÉGULIÈRE des factions, comme un joueur (D-24, DC : « elles doivent aussi faire de la
  reconnaissance comme un joueur »). PUR (aucune API Factorio, aucun nom d'objet ; testé hors jeu par tests/veille_test.lua).

  Le lot RECON (parqué) retenait un éclaireur sur la garnison : plancher de garnison, garde « guerre contre le joueur » et danger
  l'empêchaient de partir (mesuré : 0 départ en 21 000 ticks, Azure sans aucun départ sur 2 graines). Ici l'éclaireur ne vient PAS de
  la garnison : c'est un VIVIER réservé, un soldat marqué, payé en plus de l'armée et jamais compté dans la garnison. La visée des
  attaques est celle de main (aucune règle de connaissance).

  - Cadence : V.interval (10 min ÷ curiosité, allongé par la menace, doublé par perte récente).
  - Rayon croissant : V.radius (R0 + pas × trajets réussis, plafonné) ; V.pick choisit parmi des secteurs candidats (jamais vus ou vus
    depuis V.STALE) le plus ancien d'abord, en alternant les octants.
  - Départ : V.want ; fabrication du vivier : V.train_due. Chaque refus a une raison de V.REASONS (compteurs de f.stats).
  Itérations triées, entiers et flottants simples, aucune trigonométrie, aucun hasard.
]]

local V = {}

V.INTERVAL = 10 * 3600     -- intervalle entre deux départs (curiosité 1 000, menace nulle)
V.CUR_MIN, V.CUR_MAX = 500, 2000
V.THREAT_K = 2             -- l'intervalle est multiplié par (1 000 + THREAT_K × menace) ÷ 1 000
V.LOSS_CAP = 4             -- doublement de l'intervalle par perte récente, 2^4 au plus
V.R0 = 300                 -- rayon du premier trajet (tuiles du QG)
V.STEP = 150               -- rayon gagné par trajet réussi
V.RMAX = 1600              -- plafond (K.MAX_DIST de shared/ai3/carte.lua)
V.BAND = 96                -- un but est à R ± BAND tuiles du QG
V.STALE = 20 * 3600        -- un secteur vu depuis moins de 20 min n'est pas un but
V.QUIET = 5 * 3600         -- aucun départ dans les 5 min qui suivent la mort d'un soldat de la faction
V.THREAT_MAX = 100         -- au-delà (pour mille), le vivier reste au QG
V.START_ARMY = 10          -- armée de départ (objectif « army » de shared/team/config.lua) exigée, vivier HORS, pour fabriquer le vivier
V.VIVIER = 1               -- éclaireurs réservés à la fois
V.PLANNER_WAIT = 5 * 3600  -- le vivier est d'abord un soldat de PLUS dans la fournée de l'armée (le planificateur fabrique les
                           -- équipements) ; si aucune fournée ne vient en 5 min, il est payé directement sur le stock libre

V.REASONS = { "armee de depart", "defense du debut", "survie", "alerte", "menace", "ennemis pres du QG", "pertes recentes",
  "delai", "eclaireur en cours", "pas d'eclaireur", "aucun secteur", "fer insuffisant", "vivier plein" }

--- Délai avant le prochain départ ou la prochaine fabrication : V.INTERVAL ÷ curiosité, allongé par la menace, doublé par perte.
function V.interval(curiosity, threat, losses)
  local c = math.max(V.CUR_MIN, math.min(V.CUR_MAX, curiosity or 1000))
  local g = math.floor(V.INTERVAL * 1000 / c)
  g = math.floor(g * (1000 + V.THREAT_K * math.max(0, threat or 0)) / 1000)
  for _ = 1, math.min(losses or 0, V.LOSS_CAP) do g = g * 2 end
  return g
end

--- Rayon (tuiles du QG) du trajet numéro `trips` + 1.
function V.radius(trips)
  return math.min(V.R0 + V.STEP * math.max(0, trips or 0), V.RMAX)
end

--- Octant (0 à 7) du vecteur (dx, dy), sans trigonométrie : 0 = est, sens horaire à l'écran (y vers le bas).
function V.octant(dx, dy)
  local ax, ay = math.abs(dx), math.abs(dy)
  if ax == 0 and ay == 0 then return 0 end
  -- tan(22,5°) = 0,41421356 : axe si le petit côté vaut moins de 41,4 % du grand.
  if ay <= ax * 0.41421356 then return dx >= 0 and 0 or 4 end
  if ax <= ay * 0.41421356 then return dy >= 0 and 2 or 6 end
  if dx >= 0 then return dy >= 0 and 1 or 7 end
  return dy >= 0 and 3 or 5
end

--- Choix du but. cands = { { key, dh, octant, age (nil : jamais vu) }, ... } (déjà filtrés : générés, sûrs, dégagés). Les jamais vus
--- d'abord, puis les plus anciens ; à âge égal l'octant différent du précédent, puis le plus proche, puis la clé. nil : aucun.
function V.pick(cands, last_octant)
  local best
  local function better(a, b)
    local au, bu = a.age == nil, b.age == nil
    if au ~= bu then return au end
    if not au and a.age ~= b.age then return a.age > b.age end
    local ad, bd = a.octant ~= last_octant, b.octant ~= last_octant
    if ad ~= bd then return ad end
    if a.dh ~= b.dh then return a.dh < b.dh end
    return tostring(a.key) < tostring(b.key)
  end
  for _, c in ipairs(cands or {}) do
    if not best or better(c, best) then best = c end
  end
  return best
end

--- Le candidat est-il dans la bande du rayon ? (distance au QG dh)
function V.in_band(dh, radius)
  return dh >= radius - V.BAND and dh <= radius + V.BAND
end

--- Un secteur est-il un but possible côté âge ? age nil : jamais vu.
function V.stale(age)
  return age == nil or age >= V.STALE
end

--- Un éclaireur doit-il partir ? c = { ready (éclaireurs du vivier disponibles au QG), busy (un éclaireur en cours), tick, next_at,
--- threat, survive, alert, hq_ok (nil : non contrôlé), enemies, quiet_until }. Renvoie (oui, raison).
function V.want(c)
  if c.busy then return false, "eclaireur en cours" end
  if (c.ready or 0) < 1 then return false, "pas d'eclaireur" end
  if c.survive then return false, "survie" end
  if c.alert then return false, "alerte" end
  if c.hq_ok == false then return false, "defense du debut" end
  if c.enemies then return false, "ennemis pres du QG" end
  if c.tick < (c.quiet_until or 0) then return false, "pertes recentes" end
  if (c.threat or 0) > V.THREAT_MAX then return false, "menace" end
  if c.tick < (c.next_at or 0) then return false, "delai" end
  return true, "ok"
end

--- Faut-il fabriquer un éclaireur du vivier ? c = { have (éclaireurs vivants, en mission compris), soldiers (soldats HORS vivier), tick,
--- next_train, hq_ok, stock_ok (le kit est payable), survive, alert, threat }. Renvoie (oui, raison).
function V.train_due(c)
  if (c.have or 0) >= V.VIVIER then return false, "vivier plein" end
  if c.survive then return false, "survie" end
  if c.alert then return false, "alerte" end
  if c.hq_ok == false then return false, "defense du debut" end
  if (c.soldiers or 0) < V.START_ARMY then return false, "armee de depart" end
  if (c.threat or 0) > V.THREAT_MAX then return false, "menace" end
  if c.tick < (c.next_train or 0) then return false, "delai" end
  if not c.stock_ok then return false, "fer insuffisant" end
  return true, "ok"
end

return V
