-- Étape settings : uniquement des déclarations de paramètres.
-- Les paramètres sont "runtime-global" (synchronisés en multijoueur, modifiables sans recharger), sauf les réglages
-- propres à chaque joueur, en "runtime-per-user" (fo-levels-panneau, lot PANNEAU, 0.6.52).

data:extend({
  {
    type = "bool-setting",
    name = "fo-debug-render",
    setting_type = "runtime-global",
    default_value = false, -- surcouche de débogage (états, chemins) : désactivée en partie normale
    order = "a",
  },
  {
    -- Période de pilotage (ticks) des compagnons en mouvement. 1 = chaque tick.
    type = "int-setting",
    name = "fo-companion-steer-period",
    setting_type = "runtime-global",
    default_value = 4,
    minimum_value = 1,
    maximum_value = 30,
    order = "b",
  },
  {
    -- Période de décision (ticks) du cerveau de chaque compagnon.
    type = "int-setting",
    name = "fo-companion-brain-period",
    setting_type = "runtime-global",
    default_value = 60,
    minimum_value = 10,
    maximum_value = 600,
    order = "c",
  },
  {
    -- Requêtes de pathfinding scriptées en vol simultanément.
    -- Le moteur sert 10 CLIENTS au plus à la fois pour toute requête (max_clients_to_accept_any_new_request,
    -- partagés avec les biters ; ce n'est pas un nombre par tick, lot IA1-a), puis seulement les requêtes
    -- courtes : rester en dessous. Émissions par tick : fo-path-issue-per-tick (settings/team.lua). Maximum de 50
    -- gardé tel quel (une partie qui l'aurait réglé au-delà de 10 ne change pas) : à décider par l'intégrateur.
    type = "int-setting",
    name = "fo-path-max-inflight",
    setting_type = "runtime-global",
    default_value = 6,
    minimum_value = 1,
    maximum_value = 50,
    order = "d",
  },
  -- Lot IA0 : « fo-war-player-ceasefire » retiré : plus aucun code ne le lit, le réglage de partie
  -- « fo-pvp-difficulty » (settings/faction.lua) le remplace (« Paisible » = ancien comportement). Une
  -- sauvegarde qui en contient une valeur la perd sans erreur ; une guerre en cours reçoit son état PvP au
  -- chargement (script/faction/pvp.lua, PvP.ensure : hostilités existantes conservées).
  -- Lot V2c : « fo-level-time-factor » retiré : l'amélioration est instantanée (Q19), plus aucun code ne le
  -- lit. Une sauvegarde qui en contient une valeur la perd sans erreur (réglage inconnu ignoré au chargement).
})

-- Réglages par lot (un fichier par lot, requis ici par l'intégrateur).
require("settings.faction")
require("settings.team") -- lot IA1-a : taille des équipes de PNJ (shared/team/scale.lua)
require("settings.ia3b") -- lot IA3-b : place de marché, registre, manque de plaques (fo-war-ia3-marche)
require("settings.ia3c") -- lot IA3-c : cerveau par besoins (fo-war-ia3-cerveau, allumé par défaut depuis IA-V2)
require("settings.ia3k") -- lot IA3-k : comportements visibles des PNJ (fo-war-ia3-comportement)
require("settings.kit") -- lot KIT : kit de départ des factions (fo-war-kit-genereux, tests)
require("settings.ia3e") -- lot IA3-e : automatiser ce qui revient (fo-war-ia3e)
require("settings.capital") -- lot CAPITAL : améliorer et monter les époques (fo-war-capital, allumé par défaut, settings/capital.lua:25)
require("settings.capi") -- lot CAPIB : capitaliser (fo-war-capi, allumé par défaut ; agit avec fo-war-ia3e)
require("settings.adopte") -- lot ADOPTE : adopter les machines posées à la main (fo-war-adopte)
require("settings.fonderie") -- lot FONDERIE : fonderies des champs à tapis, charbon par tapis (fo-war-fonderie-tapis)
require("settings.mega_fonderie") -- lot MEGA-FONDERIE : méga-fonderies, bus de minerai et blocs de fonte (fo-war-mega-fonderie)
require("settings.petrole") -- lot PETROLE : aller au pétrole (fo-war-petrole, allumé par défaut, settings/petrole.lua:20)
require("settings.industrie") -- lot INDUSTRIE : réglage maître (fo-war-industrie ; I1 : le besoin est évalué, le reste du stock s'investit)
require("settings.robots") -- lot RB-1 : robots (fo-war-robots, fo-war-robots-cap)
require("settings.levels_panneau") -- lot PANNEAU : panneau « Évolution » au clic ou au survol (fo-levels-panneau, par joueur)
require("settings.video") -- lots VIDEO (feuille de route « Factorio Automated ») : fo-war-portes, fo-war-paliers, fo-war-lots-minerai, fo-debug-trace-carte (tous allumés depuis la 0.6.60)
require("settings.pilotage") -- lot TV-PILOTE : fo-war-armee-famille (V10) et fo-war-plafonds (G02), allumés par défaut
require("settings.exclusion") -- lot VIDEO-PLAFONDS (V99) : fo-war-exclusion (objets exclus de la demande, vide par défaut)
require("settings.tv_vapeur") -- lot TV-VAPEUR (V36, V89) : tampon de vapeur et dégradation graduée sous charge (allumés par défaut)
require("settings.tv_archi") -- lot TV-ARCHI (V23, V91) : fo-war-enveloppe, fo-war-quartiers (allumés)
require("settings.bus") -- lot RESEAU-GRAPHE : fo-war-bus, bus de produits par tapis (allumé par défaut)
require("settings.place") -- lot TV-PLACE (G37, G38, G57) : fo-war-sonde-30, fo-war-sites-10, fo-war-defrichage-prev, fo-war-place-simple (allumés)
require("settings.debug_cerveau") -- lot DEBUG-CERVEAU : réglages par joueur de la vue « Cerveau » (textes sur la carte allumés)
require("settings.flux") -- lot TV-FLUX (V42, G51) : fo-war-soupape, fo-war-barils (allumés par défaut)
require("settings.rapatriement") -- lot RAPATRIEMENT (8/11) : fo-war-rapatriement, sortie lointaine -> tapis -> tampon (allumé par défaut)
require("settings.rangees_asm") -- lot RANGEES-ASM (8/11) : fo-war-rangee-dyn, rangées d'assembleurs dynamiques (allumé par défaut)
require("settings.electrique") -- lot ELECTRIQUE (8/11) : fo-war-electrique, bascule tout-electrique des la premiere centrale (allume par defaut)
require("settings.mall") -- lot MALL (8/11) : fo-war-mall, secteur du mall centralise reserve par le terrain (allume par defaut)
require("settings.petrole_rangee") -- lot PETROLE-RANGEE (8/11) : fo-war-petrole-champ, extension du champ jusqu aux puits atteignables (allume par defaut)
require("settings.acier") -- lot ACIER (8/11) : fo-war-acier, rangee dynamique de fours d acier, coupure des tournees quand le bloc debite (allume par defaut)
require("settings.relais") -- lot MODULES-ORDRE (9/11) : fo-war-relais, une chaine faite a la main passe la porte du transport sature (allume par defaut)
