-- Constantes du compagnon (spike R&D). Toute valeur ici est une hypothèse à calibrer : voir RD_LOG.md.

return {
  BODY = "fo-companion",
  MACHINE = "companion",
  LANE_BRAIN = "fo-brain",
  LANE_LOCO = "fo-loco",
  PATH_HANDLER = "fo-companion-path",

  PAUSE_MIN = 30,            -- ticks d'attente en idle entre deux déplacements (errance)
  PAUSE_MAX = 240,
  FOLLOW_PAUSE = 20,
  FOLLOW_START_DIST = 6,     -- tuiles : distance au joueur qui déclenche un déplacement
  FOLLOW_REPATH_DIST = 8,    -- tuiles : dérive de la cible qui force un recalcul en mouvement
  FOLLOW_RING = 3,           -- tuiles : rayon de l'anneau de suivi autour du joueur

  PATH_RADIUS = 1.5,         -- tuiles : tolérance d'arrivée demandée au pathfinder
  PATH_BBOX_PAD = 0.15,      -- H4 : marge ajoutée à la bbox du corps pour éviter de raser les coins
  PATH_GIVE_UP_TICKS = 2400, -- abandon d'une attente de chemin (au-delà du timeout du service)

  ARRIVE_MIN_RADIUS = 0.4,   -- tuiles : rayon minimal de validation d'un waypoint
  ARRIVE_STEER_FACTOR = 0.6, -- rayon = max(min, vitesse * période_pilotage * facteur)

  STUCK_RATIO = 0.2,         -- déplacement observé / attendu sous lequel on compte un blocage
  STUCK_LIMIT = 2,           -- blocages consécutifs avant abandon du chemin

  H1_THRESHOLD = 0.6,        -- efficacité minimale (mode lazy) pour confirmer H1
}
