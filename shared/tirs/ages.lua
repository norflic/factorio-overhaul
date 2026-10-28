--[[
  Tirs des tourelles par âge (lot TIRS, 27/10) : DONNÉES SEULES, Lua pur (lu par l'étape data et par le runtime).

  Demande du Directeur Créatif (27/10, 13 h 40) : « […] on a l'impression qu'elle tire mais y a aucun effet spécial
  […] augmenter la puissance, et cetera, et de l'impact des [tirs] en fonction évidemment de l'âge. »
  Plan complet : fo-logs\2026-10-27_TIRS\PLAN.md ; ronde 4 (correcteur) : fo-logs\2026-10-27_TIRS\INTEGRATION.md.

  PROTOTYPE : 5 âges témoins de la mitrailleuse (1, 5, 8, 10, 15 ; l'âge 8 est le « niveau 15 » que le DC a regardé)
  et le laser à l'âge 15. Aucun code par âge : prototypes/tirs.lua (prototypes), prototypes/levels/gun.lua (son),
  prototypes/levels/laser.lua (faisceau) et script/tirs/tirs.lua (runtime) lisent cette table telle quelle.
  Un âge absent de `ages` garde l'IMAGE et le SON d'avant (éclat A4, flamme et étincelle vanilla de la munition, son
  S0 de l'ère). Mais PAS la simulation : l'effet `script` du chargeur est tiré par le moteur à CHAQUE tir de toute
  tourelle à balles (factions et vanilla comprises), ce qui ajoute un tirage aléatoire par tir et décale la suite des
  tirages de la carte (une partie de même graine diverge de main, F252, F238 ; constaté au lot, INTEGRATION.md §3).

  Mécanisme (mitrailleuse) : les 7 chargeurs « bullet » reçoivent un AmmoType propre aux tourelles
  (source_type = "turret") identique au leur, plus un effet `script` (ID) tiré par le moteur avec la probabilité
  `probabilite` ; script/tirs/tirs.lua décide par R.decider (shared/tirs/regles.lua, règle pure testée) :
    1. tourelle à plus de `proximite` tuiles de TOUT joueur connecté : pas d'habillage (aucun joueur connecté :
       pas de filtre, cas des bancs sans images) ;
    2. `part` des événements de l'âge (accumulateur entier, déterministe) ;
    3. `quota` de l'âge par tick, puis plafond commun `plafond_tick` (>= somme des quotas des témoins : chaque âge a
       son quota quel que soit l'ordre de mise à jour des tourelles) ;
  puis dessine la bouche ORIENTÉE (rendering.draw_animation vers la cible, lumière rendering.draw_light), crée la
  fumée, les dards (projectiles SANS dégâts ; le premier crée l'impact à l'arrivée) et le trait (faisceau sans action).
  Rien ne change aux règles du jeu : dégâts, cadence, portée, munitions consommées (contrôlé par tests/tirs_test.lua
  et par la garde de prototypes/tirs.lua : seuls des effets visuels ou sonores, voir shared/tirs/regles.lua).

  Couleurs : celles de tools/render/pieces/levels/commun/ages.py (FAMILLES, FOYER) ; une teinte ne fait que MULTIPLIER
  (F36) : textures choisies d'après leur couleur MESURÉE (moyenne pondérée alpha × max) :
    explosion-gunshot (1 ; 0,94 ; 0,65) presque blanc ; muzzle-flash d'artillerie (0,75 ; 0,48 ; 0,16) orange ;
    bullet.png (1 ; 0,80 ; 0,19) or ; laser-to-tint-medium (0,75) neutre ; explosion (0,85 ; 0,68 ; 0,33) chaud ;
    explosion-hit (1 ; 0,96 ; 0,32) jaune ; acid-splash (0,48 ; 0,48 ; 0,41) neutre ; smoke-fast (0,72) neutre.
  Chiffres PROVISOIRES, à juger sur capture par le DC (D1 à D3).
]]

local T = {}

T.ID = "fo-tir"              -- effect_id de l'effet script des chargeurs
T.PREFIXE = "fo-tir-"        -- préfixe des prototypes du lot (animations, explosions, dards, traits, particules, fumées)
T.probabilite = 0.5          -- part des tirs de TOURELLE à balles qui lèvent l'événement (tirée par le moteur)
T.plafond_tick = 8           -- tirs habillés au plus par tick, toute la carte (>= somme des quotas des témoins : 8)
T.proximite = 96             -- tuiles (distance de Tchebychev) entre la tourelle et le plus proche joueur connecté
T.releve = 60                -- ticks entre deux relevés des positions des joueurs connectés (état du jeu, déterministe)

-- Animations vanilla réutilisées, dessinées par rendering.draw_animation (prototype « animation » copié du même
-- fichier, mêmes cadres : aucune image nouvelle). `base` : distance (tuiles, échelle 1) du centre du cadre au pied de
-- la flamme, mesurée sur l'image (la flamme pointe vers le NORD du cadre, son pied en bas).
T.ANIMS = {
  -- flamme de bouche vanilla, 5 variations de 2 ou 3 images 34 × 38 (pied à 14 px sous le centre)
  gunshot = { filename = "__base__/graphics/entity/explosion-gunshot/explosion-gunshot.png", width = 34, height = 38,
    variations = { { x = 0, n = 2 }, { x = 68, n = 2 }, { x = 136, n = 3 }, { x = 238, n = 3 }, { x = 340, n = 3 } },
    base = 14 / 32 },
  -- flamme du canon d'artillerie vanilla, les 7 premières images (la flamme ; la suite est de la fumée), 138 × 192 et
  -- hr 276 × 382 à l'échelle 0,5 (pied à 90 px sous le centre)
  artillerie = { filename = "__base__/graphics/entity/artillery-cannon-muzzle-flash/muzzle-flash.png", width = 138,
    height = 192, n = 7, line_length = 7,
    hr = { filename = "__base__/graphics/entity/artillery-cannon-muzzle-flash/hr-muzzle-flash.png", width = 276,
      height = 382, scale = 0.5 },
    base = 90 / 32 },
}

-- Images vanilla des dards (projectiles : le moteur les oriente selon leur trajet, rotatable).
T.IMAGES = {
  -- traçante vanilla des obus (or, 3 × 50 : un dard fin et long)
  balle = { filename = "__base__/graphics/entity/bullet/bullet.png", width = 3, height = 50, frame_count = 1 },
  -- trait fin gris neutre (0,75), 12 × 33 : la traçante vanilla « laser » (teintes froides)
  fin = { filename = "__base__/graphics/entity/laser/laser-to-tint-medium.png", width = 12, height = 33,
    frame_count = 1 },
  -- éclaboussure acide vanilla (neutre, 26 images 106 × 116 ; hr 210 × 224 à l'échelle 0,5) : impact de l'âge 8
  eclaboussure = { filename = "__base__/graphics/entity/acid-splash/acid-splash-1.png", width = 106, height = 116,
    frame_count = 26, line_length = 8,
    hr_version = { filename = "__base__/graphics/entity/acid-splash/hr-acid-splash-1.png", width = 210, height = 224,
      frame_count = 26, line_length = 8, scale = 0.5 } },
}

-- Âges témoins, dans l'ordre (aucun ordre de pairs). Site SANS effet des bancs : l'âge 7 (niveau 13).
T.temoins = { 1, 5, 8, 10, 15 }
T.sans_effet = 7

--[[ Champs d'un âge :
  part     = { a, b } : a événements gardés sur b (accumulateur entier) ; part des tirs habillés = probabilite × a / b
  quota    = tirs habillés de l'âge au plus par tick (sous le plafond commun T.plafond_tick)
  bouche   = liste de flammes dessinées À LA BOUCHE, ORIENTÉES vers la cible (rendering.draw_animation, orientation_target) :
             anim (T.ANIMS), variation (gunshot), largeur et longueur (x_scale, y_scale : on étire dans l'axe du tir),
             teinte, duree (ticks). Le pied de la flamme est posé sur la bouche (oriented_offset = base × longueur).
             Une image basse définition (gunshot, 34 × 38) n'est pas agrandie de plus de ×2 dans l'axe, ×1,5 en largeur.
             devant (facultatif) : tuiles de plus vers la cible (la flamme sort de l'éclat A4 au lieu de le recouvrir).
  lumiere  = lumière de bouche (rendering.draw_light, light_medium du core) : taille (tuiles), intensite, couleur, duree
  fumee    = bouffées à la bouche (create_trivial_smoke) : source, couleur, nombre, debut et fin (échelle), duree (ticks)
  trace    = dards (projectiles sans dégâts) : image (T.IMAGES), echelle, teinte, vitesse (tuiles/tick), nombre (le
             premier porte l'impact, les autres partent moins vite : ralenti), lumiere, trainee (fumée, ères I et II)
  trait    = faisceau SANS action de la bouche à la cible : duree (<= 2 ticks), epaisseur (<= 1), teinte, coeur ; JAMAIS le
             faisceau du laser du même âge (tests/tirs_test.lua le refuse)
  impact   = liste d'explosions à la cible (créées par le premier dard à son arrivée) : source (explosion vanilla) OU
             image (T.IMAGES) ; echelle ; teinte ; duree ; enfle = { depart, ticks } (l'éclair enfle de depart à 1) ;
             lumiere { taille, intensite, couleur, onde (taille de départ), tenue (part de la vie à pleine intensité) } ;
             fumee { source, couleur, nombre, debut, fin, duree } ; etincelles { source, nombre, teinte, vitesse, montee } ;
             son { fichiers, volume, max }. Jamais `tourne` : une texture vanilla couchée paraît verticale (ronde 3).
  son      = { couches = { … } } : couches AJOUTÉES au son S0 de l'ère (LayeredSound), fichiers vanilla RÉFÉRENCÉS ;
             vitesse de lecture dans CHAQUE variation (SoundDefinition.min_speed / max_speed : posée sur la couche, le
             moteur l'ignore, doc 1.1.91 « Only loaded if variations […] are not defined » ; prouvé en session disk,
             tools/sound/tirs_couches.py) ; volumes réglés par tools/sound/tirs_sonie.py --cible sur le contrat de la
             RAFALE (PLAN.md §4, ronde 4), modèle « libre » MESURÉ en jeu (F360 : `max` ne limite pas la rafale)
  laser    = faisceau de la tourelle laser de l'âge (épaisseur, teintes)
  Couche de son : fichiers = { motif, premier, dernier } (motif avec %d) ; volume ; vitesse = { min, max } ;
    max = aggregation (count_already_playing, remove) ; F360 : ne limite PAS la rafale d'une tourelle (mesuré).
]]
T.ages = {
  [1] = {
    nom = "Pionnier", couleur = { 1.00, 0.69, 0.38 },
    part = { 2, 5 }, -- 1 tir sur 5 : la balle traçante d'une bande ; l'identité de l'ère est la FUMÉE de la poudre noire
    quota = 1,
    bouche = {
      { anim = "gunshot", variation = 5, largeur = 1.4, longueur = 2.0, teinte = { 1.00, 0.82, 0.55 }, duree = 5 },
    },
    lumiere = { taille = 6, intensite = 0.55, couleur = { 1.00, 0.62, 0.30 }, duree = 6 },
    -- la poudre noire fait une fumée BLANCHE épaisse (ronde 4, 1re capture : la fumée grise ne se voyait pas sur le sol)
    fumee = { source = "smoke-fast", couleur = { 0.80, 0.78, 0.74, 0.85 }, nombre = 5, debut = 1.0, fin = 2.6,
      duree = 110 },
    trace = { image = "balle", echelle = 1.3, teinte = { 1.00, 0.92, 0.75 }, vitesse = 1.6, nombre = 1,
      lumiere = { taille = 2, intensite = 0.35, couleur = { 1.00, 0.70, 0.35 } } },
    impact = {
      { source = "explosion-hit", echelle = 1.25, teinte = { 1.00, 0.85, 0.60 },
        lumiere = { taille = 3.5, intensite = 0.35, couleur = { 1.00, 0.69, 0.38 } },
        fumee = { source = "smoke-fast", couleur = { 0.45, 0.40, 0.34, 0.60 }, nombre = 1, debut = 0.4, fin = 0.9,
          duree = 45 },
        etincelles = { source = "spark-particle", nombre = 5, teinte = { 1.00, 0.80, 0.55 }, vitesse = 0.06,
          montee = 0.06 } },
    },
    -- son : celui de S0 (ère I), inchangé
  },

  [5] = {
    nom = "Volcan", couleur = { 1.00, 0.29, 0.06 },
    part = { 2, 3 }, -- 1 tir sur 3
    quota = 1,
    bouche = {
      -- halo de lave (flamme d'artillerie, orange mesuré, assombrie vers le rouge) derrière, cœur blanc-jaune devant
      { anim = "artillerie", largeur = 0.30, longueur = 0.36, teinte = { 1.00, 0.55, 0.30 }, duree = 6 },
      { anim = "gunshot", variation = 4, largeur = 1.1, longueur = 1.5, teinte = { 1.00, 0.78, 0.45 }, duree = 4 },
    },
    lumiere = { taille = 8, intensite = 0.70, couleur = { 1.00, 0.33, 0.08 }, duree = 7 },
    fumee = { source = "smoke-fast", couleur = { 0.20, 0.15, 0.13, 0.80 }, nombre = 2, debut = 0.6, fin = 1.4,
      duree = 80 }, -- cendre
    trace = { image = "balle", echelle = 1.35, teinte = { 1.00, 0.55, 0.30 }, vitesse = 1.5, nombre = 2, ralenti = 0.8,
      lumiere = { taille = 3, intensite = 0.55, couleur = { 1.00, 0.30, 0.06 } },
      trainee = { source = "smoke-fast", couleur = { 0.30, 0.12, 0.07, 0.55 }, frequence = 0.5 } },
    impact = {
      { source = "explosion", echelle = 1.3, teinte = { 1.00, 0.62, 0.42 }, enfle = { depart = 0.4, ticks = 4 },
        lumiere = { taille = 8, intensite = 0.70, couleur = { 1.00, 0.30, 0.06 }, tenue = 0.5 },
        etincelles = { source = "spark-particle", nombre = 9, teinte = { 1.00, 0.45, 0.20 }, vitesse = 0.08,
          montee = 0.08 } },
    },
    son = { couches = { -- coup lourd une quarte plus bas, claquement de fusil à pompe
      { fichiers = { "__base__/sound/fight/heavy-gunshot-%d.ogg", 1, 4 }, volume = 0.17, vitesse = { 0.74, 0.80 },
        max = 3 },
      { fichiers = { "__base__/sound/fight/pump-shotgun-%d.ogg", 1, 6 }, volume = 0.15, vitesse = { 0.85, 0.95 },
        max = 2 },
    } },
  },

  [8] = {
    nom = "Marais", couleur = { 0.66, 1.00, 0.23 },
    part = { 2, 3 }, -- 1 tir sur 3
    quota = 1,
    bouche = {
      -- bulle toxique : flamme vanilla (presque blanche) teintée vert acide
      { anim = "gunshot", variation = 3, largeur = 1.3, longueur = 1.6, teinte = { 0.66, 1.00, 0.25 }, duree = 6 },
    },
    lumiere = { taille = 10, intensite = 0.65, couleur = { 0.66, 1.00, 0.23 }, duree = 8 },
    fumee = { source = "smoke-fast", couleur = { 0.42, 0.70, 0.12, 0.55 }, nombre = 2, debut = 0.5, fin = 1.2,
      duree = 70 },
    trace = { image = "fin", echelle = 1.15, teinte = { 0.66, 1.00, 0.23 }, vitesse = 1.4, nombre = 2, ralenti = 0.8,
      lumiere = { taille = 3, intensite = 0.55, couleur = { 0.66, 1.00, 0.23 } },
      trainee = { source = "smoke-fast", couleur = { 0.40, 0.66, 0.10, 0.35 }, frequence = 0.5 } },
    impact = {
      -- globule qui éclate : éclaboussure acide vanilla (neutre) teintée, nuage acide qui reste
      { image = "eclaboussure", echelle = 0.6, teinte = { 0.66, 1.00, 0.23 }, duree = 16,
        lumiere = { taille = 9, intensite = 0.60, couleur = { 0.66, 1.00, 0.23 }, tenue = 0.5 },
        fumee = { source = "smoke-fast", couleur = { 0.48, 0.80, 0.14, 0.50 }, nombre = 3, debut = 0.7, fin = 1.8,
          duree = 110 } },
    },
    son = { couches = { -- bulle qui crève (capsule de poison, plus aiguë), coup lourd, fusil à pompe
      { fichiers = { "__base__/sound/fight/poison-capsule-explosion-%d.ogg", 1, 5 }, volume = 0.23,
        vitesse = { 1.20, 1.40 }, max = 3 },
      { fichiers = { "__base__/sound/fight/heavy-gunshot-%d.ogg", 1, 4 }, volume = 0.23, vitesse = { 0.80, 0.90 },
        max = 3 },
      { fichiers = { "__base__/sound/fight/pump-shotgun-%d.ogg", 1, 6 }, volume = 0.19, vitesse = { 0.95, 1.05 },
        max = 2 },
    } },
  },

  [10] = {
    nom = "Haute technologie", couleur = { 0.23, 0.66, 1.00 },
    part = { 2, 3 }, -- 1 tir sur 3
    quota = 2,
    bouche = {
      -- cœur blanc-bleu étiré dans l'axe, gaine bleue plus large et plus courte
      { anim = "gunshot", variation = 3, largeur = 1.5, longueur = 1.6, teinte = { 0.30, 0.62, 1.00 }, duree = 6 },
      { anim = "gunshot", variation = 5, largeur = 1.1, longueur = 2.0, teinte = { 0.62, 0.88, 1.00 }, duree = 6,
        devant = 0.3 },
    },
    lumiere = { taille = 12, intensite = 0.80, couleur = { 0.23, 0.66, 1.00 }, duree = 10 },
    -- dards de plasma (pas de trait : réservé au laser)
    -- ronde 4, 1re capture : dards de 1,3 tuile trop fins au zoom 0,5 ; ×2 : dards de 2 tuiles
    trace = { image = "fin", echelle = 2.0, teinte = { 0.50, 0.82, 1.00 }, vitesse = 2.4, nombre = 3, ralenti = 0.82,
      lumiere = { taille = 6, intensite = 0.90, couleur = { 0.23, 0.66, 1.00 } } },
    impact = {
      -- éclair de plasma qui enfle (fumée vanilla neutre en lueur additive), cœur blanc-bleu, gerbe d'étincelles qui monte
      { source = "explosion-hit", echelle = 2.2, teinte = { 0.55, 0.85, 1.00 }, enfle = { depart = 0.3, ticks = 4 },
        lumiere = { taille = 12, intensite = 0.75, couleur = { 0.23, 0.66, 1.00 }, onde = 0.4, tenue = 0.65 },
        etincelles = { source = "pole-spark-particle", nombre = 12, teinte = { 1.00, 1.00, 1.00 }, vitesse = 0.10,
          montee = 0.10 } },
    },
    son = { couches = { -- tir laser, coup lourd grave, claquement de fusil à pompe (plus aigu)
      { fichiers = { "__base__/sound/fight/laser-%d.ogg", 1, 3 }, volume = 0.34, vitesse = { 0.85, 0.95 }, max = 3 },
      { fichiers = { "__base__/sound/fight/heavy-gunshot-%d.ogg", 1, 4 }, volume = 0.20, vitesse = { 0.62, 0.68 },
        max = 3 },
      { fichiers = { "__base__/sound/fight/pump-shotgun-%d.ogg", 1, 6 }, volume = 0.22, vitesse = { 1.05, 1.15 },
        max = 2 },
    } },
  },

  [15] = {
    nom = "Néant", couleur = { 1.00, 0.90, 0.66 }, bord = { 1.00, 0.64, 0.28 },
    part = { 1, 1 }, -- 1 tir sur 2
    quota = 3,
    bouche = {
      -- l'éclat A4 de l'âge 15 est déjà une grande flamme blanc-or à bord ambre (validée) : le lot pousse DEVANT lui un
      -- jet blanc-or étiré (ronde 4, 1re capture : le halo d'artillerie posé dessus se lisait comme une tache rouge)
      { anim = "gunshot", variation = 5, largeur = 1.2, longueur = 2.0, teinte = { 1.00, 0.95, 0.80 }, duree = 6,
        devant = 0.6 },
    },
    lumiere = { taille = 16.5, intensite = 0.90, couleur = { 1.00, 0.85, 0.60 }, duree = 10 },
    -- rafale de dards d'or (la lumière fait la traînée : plus de fumée à l'âge du Néant)
    trace = { image = "balle", echelle = 1.7, teinte = { 1.00, 0.95, 0.80 }, vitesse = 2.2, nombre = 3, ralenti = 0.8,
      lumiere = { taille = 6, intensite = 0.85, couleur = { 1.00, 0.85, 0.60 } } },
    -- claquement : trait blanc, fin et bref (le faisceau or épais reste celui du laser)
    trait = { duree = 2, epaisseur = 0.7, teinte = { 1.00, 0.97, 0.92 }, coeur = { 1.00, 1.00, 1.00 } },
    impact = {
      { source = "explosion", echelle = 1.9, teinte = { 1.00, 0.92, 0.75 }, enfle = { depart = 0.3, ticks = 5 },
        lumiere = { taille = 20, intensite = 0.85, couleur = { 1.00, 0.78, 0.45 }, onde = 0.3, tenue = 0.65 },
        etincelles = { source = "spark-particle", nombre = 18, teinte = { 1.00, 0.90, 0.60 }, vitesse = 0.12,
          montee = 0.12 },
        son = { fichiers = { "__base__/sound/fight/medium-explosion-%d.ogg", 1, 5 }, volume = 0.30, max = 2 } },
      { source = "explosion-hit", echelle = 1.6, teinte = { 1.00, 1.00, 0.90 }, enfle = { depart = 0.5, ticks = 3 } },
    },
    son = { couches = { -- canon de char, coup d'artillerie (plus aigu), grave une octave sous le coup lourd
      { fichiers = { "__base__/sound/fight/tank-cannon-%d.ogg", 1, 5 }, volume = 0.22, vitesse = { 1.10, 1.22 },
        max = 2 },
      { fichiers = { "__base__/sound/fight/artillery-shoots-%d.ogg", 1, 2 }, volume = 0.24, vitesse = { 1.30, 1.50 },
        max = 3 },
      { fichiers = { "__base__/sound/fight/heavy-gunshot-%d.ogg", 1, 4 }, volume = 0.30, vitesse = { 0.52, 0.58 },
        max = 3 },
    } },
    -- faisceau du laser 15 : or, épaissi ×1,5 au plus tant que source_offset n'est pas recalé sur l'optique (défaut
    -- ouvert : le faisceau semble partir du socle)
    laser = { epaisseur = 1.5, teinte = { 1.00, 0.64, 0.28 }, coeur = { 1.00, 0.90, 0.66 }, sol = { 0.60, 0.38, 0.12 } },
  },
}

return T
