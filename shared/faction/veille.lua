--[[
  Lot VEILLE (essai 2, 29/10) : RECONNAISSANCE RÉGULIÈRE des factions, comme un joueur (D-24, DC : « elles doivent aussi faire de la
  reconnaissance comme un joueur »). PUR (aucune API Factorio, aucun nom d'objet ; testé hors jeu par tests/veille_test.lua).

  L'essai 1 envoyait un soldat d'un vivier réservé : environ 500 plaques de fer pour 10 éclaireurs, 7,4 tourelles de moins (mesuré). Ici
  l'éclaireur est un OUVRIER LIBRE de la faction, par la voie d'exploration d'IA3-f (script/ai3/exploration.lua) : aucun kit, aucun soldat.

  - Cadence : V.interval (10 min ÷ curiosité, allongé par la menace).
  - Rayon croissant : V.radius (R0 + pas × missions arrivées, plafonné) ; V.pick choisit parmi des secteurs candidats (jamais vus ou vus
    depuis V.STALE) le plus ancien d'abord, en alternant les octants.
  - Départ : V.want. Chaque refus a une raison de V.REASONS (compteurs de f.stats).
  Itérations triées, aucun hasard, aucune trigonométrie.
]]

local V = {}

V.INTERVAL = 10 * 3600     -- intervalle entre deux départs (curiosité 1 000, menace nulle)
V.CUR_MIN, V.CUR_MAX = 500, 2000
V.THREAT_K = 2             -- l'intervalle est multiplié par (1 000 + THREAT_K × menace) ÷ 1 000
V.START = 15 * 3600        -- aucun départ avant 15 min : la mise en place de la base ne perd pas un ouvrier (et le tour de fondation passe d'abord)
V.R0 = 300                 -- rayon de la première mission (tuiles du QG)
V.STEP = 150               -- rayon gagné par mission arrivée
V.RMAX = 1600              -- plafond (K.MAX_DIST de shared/ai3/carte.lua)
V.BAND = 96                -- un but est à R ± BAND tuiles du QG
V.STALE = 20 * 3600        -- un secteur vu depuis moins de 20 min n'est pas un but
V.THREAT_MAX = 100         -- au-delà (pour mille), les ouvriers restent au travail
V.IDLE_MIN = 2             -- PNJ libres exigés pour qu'un parte (un reste au QG)
V.IDLE_MIN_CRISIS = 3      -- quand une matière manque (crise), deux restent

V.REASONS = { "survie", "alerte", "menace", "delai", "tache libre", "ouvriers pris", "tour non fini", "demande de ressource",
  "aucun secteur", "pas de PNJ libre" }

--- Délai avant le prochain départ : V.INTERVAL ÷ curiosité, allongé par la menace.
function V.interval(curiosity, threat)
  local c = math.max(V.CUR_MIN, math.min(V.CUR_MAX, curiosity or 1000))
  local g = math.floor(V.INTERVAL * 1000 / c)
  return math.floor(g * (1000 + V.THREAT_K * math.max(0, threat or 0)) / 1000)
end

--- Rayon (tuiles du QG) de la mission numéro `trips` + 1.
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

--- PNJ libres en surplus : libres moins tâches libres prenables (jamais négatif).
function V.surplus(idle, open_tasks)
  return math.max(0, (idle or 0) - (open_tasks or 0))
end

--- Un ouvrier doit-il partir en veille ? c = { tick, next_at, threat, survive, alert, tour_done (le tour de fondation est fini ou
--- abandonné), request (une exploration de ressource est demandée), open_tasks (tâches libres au tableau), idle (PNJ libres), missing
--- (une matière manque : crise) }. Renvoie (oui, raison). L'ordre des refus est celui des compteurs.
function V.want(c)
  if c.survive then return false, "survie" end
  if c.alert then return false, "alerte" end
  if (c.threat or 0) > V.THREAT_MAX then return false, "menace" end
  if c.request then return false, "demande de ressource" end
  if c.tour_done == false then return false, "tour non fini" end
  if (c.idle or 0) < 1 then return false, "pas de PNJ libre" end
  local need = c.missing and V.IDLE_MIN_CRISIS or V.IDLE_MIN
  if (c.idle or 0) < need then return false, "ouvriers pris" end
  -- Lot CORR-RECON : un ouvrier part s'il y a des PNJ libres EN SURPLUS (libres moins tâches prenables, au moins `need`), et non plus
  -- seulement quand aucune tâche n'est prenable (10 433 refus « tache libre » alors que des PNJ libres attendaient, RAPPORT RECON 29/10).
  if V.surplus(c.idle, c.open_tasks) < need then return false, "tache libre" end
  if c.tick < (c.next_at or 0) then return false, "delai" end
  return true, "ok"
end

return V
