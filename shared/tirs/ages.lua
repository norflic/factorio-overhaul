--[[
  Tirs des tourelles par âge (lot TIRS, 27/10) : DONNÉES SEULES, Lua pur (lu par l'étape data et par le runtime).

  Demande du Directeur Créatif (27/10, 13 h 40) : « […] on a l'impression qu'elle tire mais y a aucun effet spécial
  […] augmenter la puissance, et cetera, et de l'impact des [tirs] en fonction évidemment de l'âge. »
  Plan complet : fo-logs\2026-10-27_TIRS\PLAN.md.

  PROTOTYPE : 4 âges témoins de la mitrailleuse (1, 5, 10, 15) et le laser à l'âge 15. Un âge absent de `ages` garde
  l'effet d'avant (éclat A4, flamme et étincelle vanilla de la munition, son S0 de l'ère). Aucun code par âge :
  prototypes/tirs.lua (prototypes), prototypes/levels/gun.lua (son), prototypes/levels/laser.lua (faisceau) et
  script/tirs/tirs.lua (runtime) lisent cette table telle quelle.

  Mécanisme (mitrailleuse) : les 7 chargeurs « bullet » reçoivent un AmmoType propre aux tourelles
  (source_type = "turret") identique au leur, plus un effet `script` (ID) tiré par le moteur avec la probabilité
  `probabilite` ; script/tirs/tirs.lua garde `part` des événements de l'âge (accumulateur entier, déterministe) sous
  un plafond de `plafond_tick` tirs habillés par tick (toute la carte), puis crée les explosions de bouche, la
  traçante (projectile SANS dégâts dont l'action crée l'impact à l'arrivée) et le trait (faisceau sans action).
  Rien ne change en jeu : dégâts, cadence, portée, munitions consommées (contrôlé par tests/tirs_test.lua et par la
  garde de prototypes/tirs.lua : seuls des effets visuels ou sonores, voir shared/tirs/regles.lua).

  Couleurs : celles de tools/render/pieces/levels/commun/ages.py (FAMILLES, FOYER) ; une teinte ne fait que MULTIPLIER
  (F36) : textures choisies d'après leur couleur MESURÉE (PLAN.md §2).
  Chiffres PROVISOIRES, à juger sur capture par le DC (D1 à D3).
]]

local T = {}

T.ID = "fo-tir"              -- effect_id de l'effet script des chargeurs
T.PREFIXE = "fo-tir-"        -- préfixe des prototypes du lot (explosions, traçantes, traits, particules, fumées)
T.probabilite = 0.5          -- part des tirs de TOURELLE à balles qui lèvent l'événement (tirée par le moteur)
T.plafond_tick = 6           -- tirs habillés au plus par tick, toute la carte (unités de travail, jamais un temps)

-- Images vanilla réutilisées (aucun fichier nouveau ; couleur mesurée, PLAN.md §2).
T.IMAGES = {
  -- trait fin gris neutre (0,75), 12 × 33 : la traçante vanilla « laser » (rouge teinté)
  fin = { filename = "__base__/graphics/entity/laser/laser-to-tint-medium.png", width = 12, height = 33,
    frame_count = 1 },
  -- gerbe blanche du bout du laser vanilla (lumière, LA blanc), 8 images 110 × 62
  gerbe_blanche = { filename = "__base__/graphics/entity/laser-turret/hr-laser-end-light.png", width = 110,
    height = 62, frame_count = 8, line_length = 8, scale = 0.5 },
  -- (hr-tileable-beam-END-light.png, blanc aussi, écarté : la vanilla ne le charge pas, ce serait une image de plus
  -- dans l'atlas, plein au plancher, F186 ; harness : « CHEMIN A VERIFIER »)
}

-- Âges témoins, dans l'ordre (aucun ordre de pairs).
T.temoins = { 1, 5, 10, 15 }

--[[ Champs d'un âge :
  part     = { a, b } : a événements gardés sur b (accumulateur entier) ; part des tirs habillés = probabilite × a / b
  bouche   = liste d'explosions créées à la bouche (position source de l'effet)
  trace    = traçante (projectile sans dégâts) : image, echelle, teinte, vitesse (tuiles/tick), lumiere, trainee
  trait    = faisceau sans action de la bouche à la cible : duree (ticks), epaisseur (× sprite), teinte, coeur
  impact   = liste d'explosions à la cible (créées par la traçante à son arrivée, sinon tout de suite)
  son      = { couches = { … } } : couches AJOUTÉES au son S0 de l'ère (LayeredSound), fichiers vanilla RÉFÉRENCÉS
  laser    = faisceau de la tourelle laser de l'âge (épaisseur, teintes)
  Explosion : source (explosion vanilla dont on copie les animations) OU image (T.IMAGES) ; echelle ; teinte ;
    duree (ticks de l'animation ; absent : celle de la source) ; lumiere { taille, intensite, couleur, onde = facteur
    de taille au départ (la lumière grandit jusqu'à 1) } ; fumee { source, couleur, nombre } ;
    etincelles { source (particule vanilla), nombre, teinte, vitesse } ; son { fichiers, volume, max }.
  Couche de son : fichiers = { motif, premier, dernier } (motif avec %d) ; volume ; vitesse = { min, max } ;
    max = sons au plus en même temps (aggregation : count_already_playing, remove).
]]
T.ages = {
  [1] = {
    nom = "Pionnier", couleur = { 1.00, 0.69, 0.38 },
    part = { 2, 5 }, -- 1 tir sur 5 (balle traçante dans une bande)
    bouche = {
      { source = "explosion-gunshot", echelle = 1.3, teinte = { 1.00, 0.80, 0.55 }, duree = 4,
        lumiere = { taille = 3.9, intensite = 0.34, couleur = { 1.00, 0.69, 0.38 } },
        fumee = { source = "smoke-fast", couleur = { 0.46, 0.44, 0.42, 0.80 }, nombre = 3 } }, -- poudre noire
    },
    trace = { image = "fin", echelle = 0.32, teinte = { 1.00, 0.80, 0.42 }, vitesse = 1.6,
      lumiere = { taille = 1.6, intensite = 0.25, couleur = { 1.00, 0.70, 0.35 } } },
    impact = {
      { source = "explosion-hit", echelle = 1.1, teinte = { 1.00, 0.85, 0.60 },
        lumiere = { taille = 3, intensite = 0.25, couleur = { 1.00, 0.69, 0.38 } },
        etincelles = { source = "spark-particle", nombre = 3, teinte = { 1.00, 0.80, 0.55 }, vitesse = 0.05 } },
    },
    -- son : celui de S0 (ère I), inchangé (plan : Δ −0,5 dB à l'âge 1)
  },

  [5] = {
    nom = "Volcan", couleur = { 1.00, 0.29, 0.06 },
    part = { 1, 2 }, -- 1 tir sur 4
    bouche = {
      { source = "explosion-gunshot", echelle = 1.8, teinte = { 1.00, 0.45, 0.16 }, duree = 6,
        lumiere = { taille = 7.5, intensite = 0.50, couleur = { 1.00, 0.33, 0.08 } },
        fumee = { source = "smoke-fast", couleur = { 0.24, 0.18, 0.16, 0.70 }, nombre = 2 } }, -- cendre
    },
    trace = { image = "fin", echelle = 0.55, teinte = { 1.00, 0.40, 0.10 }, vitesse = 1.5, -- scorie incandescente
      lumiere = { taille = 3, intensite = 0.45, couleur = { 1.00, 0.30, 0.06 } },
      trainee = { source = "smoke-fast", couleur = { 0.32, 0.12, 0.07, 0.55 }, frequence = 0.5 } },
    impact = {
      { source = "explosion", echelle = 0.7, teinte = { 1.00, 0.62, 0.42 },
        lumiere = { taille = 6, intensite = 0.50, couleur = { 1.00, 0.30, 0.06 } },
        etincelles = { source = "spark-particle", nombre = 6, teinte = { 1.00, 0.45, 0.20 }, vitesse = 0.07 } },
    },
    son = { couches = {
      { fichiers = { "__base__/sound/fight/heavy-gunshot-%d.ogg", 1, 4 }, volume = 0.16, vitesse = { 0.74, 0.80 },
        max = 2 },
    } },
  },

  [10] = {
    nom = "Haute technologie", couleur = { 0.23, 0.66, 1.00 },
    part = { 2, 3 }, -- 1 tir sur 3
    bouche = {
      { image = "gerbe_blanche", echelle = 1.0, teinte = { 0.45, 0.75, 1.00 }, duree = 6,
        lumiere = { taille = 12, intensite = 0.70, couleur = { 0.23, 0.66, 1.00 } } },
    },
    trace = { image = "fin", echelle = 0.80, teinte = { 0.40, 0.75, 1.00 }, vitesse = 2.4, -- trait de plasma
      lumiere = { taille = 4, intensite = 0.70, couleur = { 0.23, 0.66, 1.00 } } },
    impact = {
      { image = "gerbe_blanche", echelle = 1.6, teinte = { 0.55, 0.82, 1.00 }, duree = 12,
        lumiere = { taille = 12, intensite = 0.60, couleur = { 0.23, 0.66, 1.00 }, onde = 0.4 },
        etincelles = { source = "pole-spark-particle", nombre = 8, teinte = { 1.00, 1.00, 1.00 }, vitesse = 0.08 } },
    },
    son = { couches = {
      { fichiers = { "__base__/sound/fight/laser-%d.ogg", 1, 3 }, volume = 0.20, vitesse = { 0.72, 0.80 }, max = 2 },
      { fichiers = { "__base__/sound/fight/heavy-gunshot-%d.ogg", 1, 4 }, volume = 0.12, vitesse = { 0.62, 0.68 },
        max = 1 },
    } },
  },

  [15] = {
    nom = "Néant", couleur = { 1.00, 0.90, 0.66 }, bord = { 1.00, 0.64, 0.28 },
    part = { 1, 1 }, -- 1 tir sur 2 (la bouche reste allumée : l'explosion dure plus que l'intervalle des tirs)
    bouche = {
      { source = "explosion-gunshot", echelle = 3.0, teinte = { 1.00, 0.72, 0.36 }, duree = 9,
        lumiere = { taille = 16.5, intensite = 0.90, couleur = { 1.00, 0.82, 0.55 } } },
    },
    trait = { duree = 5, epaisseur = 2.5, teinte = { 1.00, 0.64, 0.28 }, coeur = { 1.00, 0.90, 0.66 } },
    trace = { image = "fin", echelle = 1.30, teinte = { 1.00, 0.90, 0.66 }, vitesse = 2.0, -- boule incandescente
      lumiere = { taille = 6, intensite = 0.80, couleur = { 1.00, 0.85, 0.60 } },
      trainee = { source = "smoke-fast", couleur = { 0.95, 0.75, 0.35, 0.35 }, frequence = 1 } },
    impact = {
      { source = "explosion", echelle = 1.5, teinte = { 1.00, 0.92, 0.75 },
        lumiere = { taille = 20, intensite = 0.80, couleur = { 1.00, 0.75, 0.40 }, onde = 0.3 },
        etincelles = { source = "spark-particle", nombre = 16, teinte = { 1.00, 0.88, 0.55 }, vitesse = 0.10 },
        son = { fichiers = { "__base__/sound/fight/medium-explosion-%d.ogg", 1, 5 }, volume = 0.22, max = 2 } },
      { image = "gerbe_blanche", echelle = 2.2, teinte = { 1.00, 0.70, 0.32 }, duree = 12 },
    },
    son = { couches = {
      { fichiers = { "__base__/sound/fight/tank-cannon-%d.ogg", 1, 5 }, volume = 0.18, vitesse = { 1.10, 1.22 },
        max = 1 },
      { fichiers = { "__base__/sound/fight/heavy-gunshot-%d.ogg", 1, 4 }, volume = 0.15, vitesse = { 0.52, 0.58 },
        max = 2 },
    } },
    laser = { epaisseur = 2.5, teinte = { 1.00, 0.64, 0.28 }, coeur = { 1.00, 0.90, 0.66 }, sol = { 0.60, 0.38, 0.12 } },
  },
}

return T
