--[[
  Lot CAPIB « brancher la capitalisation » (demandes du DC du 27/10 : 12 h 05 « Le scaling des IA est aussi et surtout
  dans la maximisation des gisements, de la fonte et des crafts en fait, c'est le concept de capitalisation qu'il faut
  implémenter » ; 12 h 15 « A ne pas oublier toute la partie plus de gisements. Plus de fours (dans la limite de ce qu'on
  peut faire fondre évidemment), si assembleurs disponibles alors on ajoute des chaînes de production etc etc. » ; 12 h 30
  « un joueur […] aurait maximisé vraiment tout le gisement, il aurait mis des foreuses partout »).
  Côté RUNTIME de la règle pure shared/ai3/capitalisation.lua (conception : docs/IA_CAPITALISATION.md ; plan de
  branchement : fo-logs/2026-10-27_CAPI/INTEGRATION.md §5). Factions ET votre équipe de PNJ (Capi.on n'exclut pas is_player),
  réglage de carte fo-war-capi (ALLUMÉ par défaut depuis le 27/10 au soir) ET automatisation
  allumée (fo-war-ia3e, allumé par défaut : sans son exécutant, ni foreuses électriques ni chaînes). Mesuré le 29/10 sur
  la partie du DC : 691 décisions [FO-CAPI] en 198 min, branchée et tournante ; texte « éteint par défaut, factions seulement »
  périmé et corrigé ici (lot CAPI-REPLI + CAPI-MESURE).

  Cycle d'une faction : une pensée sur 12 (une minute à une pensée toutes les 300 ticks), chaque pensée à son créneau
  de l'ordonnanceur (les factions sont décalées) et UNE seule étape coûteuse par pensée (coût étalé : jamais deux lectures
  de la carte dans la même pensée) :
    étape 0     relevé des machines, foreuses et laboratoires de la force autour du QG (un find_entities_filtered),
                foreuses des avant-postes lointains (listes de l'exécutant), graines de gisements ;
    étape 1     couverture MESURÉE de chaque gisement exploité : tuiles de minerai sous l'aire d'au moins une foreuse
                (aire lue sur le prototype, mining_drill_radius) ;
    étapes 2-9  RECENSEMENT d'un gisement par pensée (Sites.census : composante connexe ENTIÈRE, plus de 64 tuiles),
                relu toutes les Capi.CENSUS_EVERY ;
    étape 10    DÉCISION (Ca.decide) et ENVOI des ordres aux exécutants ; ligne « [FO-CAPI] <faction> minute M » ;
    toutes      suivi des ordres ouverts (état de l'exécutant, manques), buts de FOND du cerveau (Ca.goals).
  Exécutants (un seul décideur par levier ; périmètre RÉDUIT après les bancs p1 et p2 du lot, BRANCHEMENT.md §3) :
    couvrir/ouvrir, foreuse électrique  fonderies du plan directeur (gabarit à foreuses et tapis d'AUTO, Auto.submit), au
                                        débit des foreuses commandées, découpé en modules d'au plus A.FIRST_RATE_MAX
                                        objets/min : leurs fours sont dimensionnés par le gabarit sur le minerai des
                                        foreuses (critère (2)) ;
    chaine, packs                       rangées d'assembleurs du plan directeur (A.method_for, A.sized, Auto.submit) ;
    labos                               laboratoires du QG (research_step : nombre visé, Capi.labs_want) ;
    energie                             la centrale est demandée par AUTO avant le premier module électrique.
  Restent à leur décideur d'avant (refus écrit) : les avant-postes à COMBUSTION (croissance des buts, vagues de SCALE :
  leur charbon est porté par les PNJ, travail récurrent que la règle ne compte pas) et les fours du QG nourris par les PNJ
  (Br.smelters). CONTRADICTION NON TRANCHÉE (audit 29/10, T10) : ce texte dit aussi, plus bas, que « les vagues de fours
  de SCALE (Br.smelters) s'éteignent » sous la capitalisation ; execute() refuse bien les ordres « fours » (decideur SCALE), mais
  qui des deux sert réellement les fours du QG n'a pas été relu ni mesuré dans ce lot.
  Ce qui s'éteint sous la capitalisation : les demandes d'A.decide (il mesure encore), les vagues d'extraction et la
  croissance des capacités par manque (B.targets : s.capi), les vagues de fours de SCALE (Br.smelters) et le plafond de
  laboratoires (Br.labs_max, Ia3.LABS_MAX).
  Lot CAPI-REPLI (29/10) : le repli d'un module refusé par le plan directeur est porté par (produit, gisement) et non plus
  par le produit (shared/ai3/repli.lua) : remis à zéro par un module terminé, décroissant avec le temps, plafonné à 5 min
  quand la couverture est sous 50 % et le besoin non servi ; un échec « materiaux introuvables » ne ferme pas le gisement
  (module suivant réduit, objets manquants gardés en but de fabrication Rp.PREP_TTL). Lot CAPI-MESURE : journaux
  [FO-CAPI-COUV] (par gisement toutes les 5 min : couverture, places libres, raison de drill_for = "", repli, refus de la
  règle, ordres) et [FO-CAPI-ALERTE] (capacité posée qui produit 0/min mesurés). Lot CAPI-DEBIT (30/10) : EMPLACEMENTS du
  plan directeur (shared/ai3/emplacements.lua) : un module figé en chantier depuis 10 min ne tient plus d'emplacement, un
  stock libre riche des produits des fonderies en ouvre jusqu'à 2 de plus, le plafond vaut pour la décision entière ; journal
  [FO-CAPI-EMPLACEMENTS] (à chaque changement). Aucun nom du jeu ici (anti-échelle, tests/iag_test.lua §8) : objets,
  recettes, machines viennent des prototypes, des données de l'exécutant (shared/team/config.lua,
  shared/team/automatisation_donnees.lua par A.METHODS) et de la règle.
  Déterminisme : listes triées, aucun hasard, aucun temps mesuré ; état dans f.team.capi (global : nombres, chaînes,
  tables) ; cache LOCAL du relevé des prototypes seulement.
]]

local T = require("shared.team.config")
local Ca = require("shared.ai3.capitalisation")
local Rf = require("shared.ai3.refus") -- lot VIDEO-REFUS (C6) : décompte des refus par sorte, ligne [FO-CAPI-REFUS]
local RangTrace = require("script.ai3.rang_trace") -- lot VIDEO-TRACES (G34) : journal [FO-RANG]
local Pil = require("script.ai3.pilotage") -- lot TV-PILOTE : plafonds de sûreté (G02), kit d'amorçage (D02)
local Excl = require("script.ai3.exclusion") -- lot VIDEO-PLAFONDS (V99) : réglage fo-war-exclusion (objets exclus de la demande), journal [FO-EXCLU]
local Cf = require("shared.ai3.confirmation") -- lot VIDEO-L5 : capacité CONFIRMÉE (première production observée)
local Sante = require("script.team.sante_centrale") -- étape 5a de VIDEO-INTEG : consommateurs en chantier (vue de la porte du plan directeur)
local Sc = require("shared.team.sante_centrale") -- étape 5a : S.DRAW (part de sa puissance nominale qu'un chantier tire)
local Rs = require("shared.ai3.reserve") -- lot INDUSTRIE I1 : description du besoin évalué (journal [FO-RESERVE])
local L = require("shared.levels.config") -- intégration 0.6.28 : vitesse de plan des bâtiments à niveaux
local Rp = require("shared.ai3.repli") -- lot CAPI-REPLI : repli par (produit, gisement), matériaux, plafond
local Dep = require("script.ai3.depenses") -- lot DEPENSES2 : le stock qui dort (défense, recherche, armement)
local Em = require("shared.ai3.emplacements") -- lot CAPI-DEBIT : emplacements du plan directeur (figés, stock riche, décision)
local A = require("shared.ai3.automatiser")
local R = require("shared.ai3.reglages")
local Pl = require("shared.team.plan")
local Tr = require("shared.team.treillis") -- lot INDUSTRIE I3 : portée du plan directeur vers un gisement (règles pures)
local State = require("script.faction.state")
local Stock = require("script.team.stock") -- lot COFFRE : stock = coffre du QG + annexes
local Sites = require("script.faction.sites")
local Profiler = require("script.core.profiler")
local Events = require("script.core.events") -- lot CAPI-DECIDE : recherche finie pendant une décision, configuration changée
local General = require("script.ai3.general")
local Auto = require("script.ai3.automatisation")
local Build = require("script.team.build")
local Harvest = require("script.team.harvest") -- lot KIT : matières naturelles récoltables à portée
local Book = require("shared.team.book") -- lot CORR-CHAMP-MANQUE : livre de recettes de la force (banc « bench_order » seulement)
local Adopte = require("script.team.adopte") -- lot ADOPTE : machines du joueur que personne ne sert
local Equip = require("script.team.equiper") -- lot LEVIERS : tâche « equiper »
local Lv = require("shared.ai3.leviers")
local MM = require("shared.content.module_mult")
local Survie = require("script.team.survie") -- lot SURVIE-PENURIE : mode survie (la production passe avant la défense)
local Sv = require("shared.team.survie")
local Pv = require("shared.ai3.prevision") -- lot PREVISION (C12) : prix de la défense induite
local Prev = require("script.ai3.prevision") -- lot PREVISION : estimateur unique de la menace (relevé de l'équipe)
local Ml = require("shared.ai3.mall") -- lot PILE-MALL (relecture) : la demande du mall est un puits de la capitalisation
local Mq = require("shared.ai3.manque_local") -- lot VIDEO-L3 : manques mesurés des modules finis, puits de la capitalisation (Mq.sinks)
local AmRt = require("script.ai3.amorce_rt") -- lot VIDEO L7 : retrait de la main à la 1re production observée (L5)
local TC = require("script.ai3.trace_carte") -- lot VIDEO L11 : trace des ordres sur la carte (réglage fo-debug-trace-carte)
local Rsv = require("script.ai3.reserve") -- lot INDUSTRIE I1 : le besoin évalué, le stock hors besoin s'investit
local Dm = require("shared.ai3.demande") -- lot C2 : puits ouvert, emplacements selon les bras libres
local Ind = require("script.ai3.industrie") -- lot INDUSTRIE I6 : choix du patron (rangée ou bloc de mall), lecture des prototypes
local PileRt = require("script.team.pile") -- lot FUITES-PILE : la porte de la pile (ordres neufs, équipement en modules)
local Pi = require("shared.ai3.pile")
local BdRt = require("script.ai3.budget_defense") -- lot S42-DEFENSE : part de la defense selon les pertes recentes
local Pe = require("shared.ai3.portes_extension") -- lot VIDEO-L6 : portes avant d'étendre (Capi.portes, decide_finish)
local Cv = require("shared.ai3.couverture") -- lot COUVERTURE : la couverture en boucle passe la porte du transport, modules posés cumulés
local Pal = require("shared.ai3.palier") -- lot VIDEO-L10 : marches de stabilité, variante B (Capi.palier, decide_start)
local Ext = require("script.ai3.extension") -- lot C3 EXTENSION : rayon de base (étendue des avant-postes)
local Mg = require("shared.ai3.marge") -- lot MARGE-TIERS : fenêtre glissante production / consommation, journal [FO-MARGE]
local MigChamp = require("script.team.migration_champ") -- lot CHAMP : « couvrir / ouvrir » d'un minerai à fondre passent par le champ

local Capi = {}
-- Lot DEBUG-CERVEAU : anneau des ordres envoyés et refusés AVEC leur raison, lu par la seule vue « Cerveau » (jamais par une décision). Champ, pas une locale (199 sur 200).
Capi.Anneau = require("script.debug.anneau")
Capi.MS = require("script.ai3.modules_stock") -- lot MODULES-POSES : disposition du stock de modules (champ de Capi : aucune locale de plus)
Capi.Mega = require("script.team.mega_fonderie") -- lot MEGA-FONDERIE : décision du bloc de fonte nourri par un bus (étape 11 ; champ, aucune locale de plus)

Capi.SETTING = "fo-war-capi"
Capi.ENABLED = true
Capi.CYCLE = 12              -- pensées par cycle (une minute à une pensée toutes les 300 ticks)
Capi.Cov = require("shared.ai3.cov_pas") -- lot COUT-600 : couverture d'un gisement par pensée (règles pures ; champ de Capi : pas de locale de plus en tête de fichier)
Capi.SCAN_R = 160            -- tuiles autour du QG : machines, foreuses, gisements connus
Capi.HQ_R = 40               -- une machine à moins de 40 tuiles du QG est « au QG »
Capi.DEP_MAX = 16            -- gisements suivis au plus par faction (les plus proches)
Capi.CENSUS_EVERY = 5 * 3600 -- un gisement est relu toutes les 5 min
Capi.ORDER_TTL = 30 * 3600   -- un ordre qui n'avance plus depuis 30 min est retiré (refus écrit)
Capi.LOG_ORDERS = 64         -- lignes d'ordres gardées pour l'interface des bancs
Capi.QUEUE_MAX = 12          -- technologies au plus dans la file de recherche vue par la règle (recherche élastique)
Capi.BACKOFF = 10 * 3600     -- une clé de levier (équiper, technologie) refusée n'est plus demandée pendant 10 min × 2^(refus - 1),
Capi.BACKOFF_MAX = 40 * 3600 -- au plus 40 min (banc p3 du lot : 63 demandes refusées d'un même produit en 50 min, un plan
                             -- coûte 25 à 40 ms : comme AUTO, un refus vaut tant que le contexte n'a pas changé).
                             -- Les MODULES du plan directeur (fonderies à foreuses, chaînes) n'utilisent plus ce repli depuis
                             -- le lot CAPI-REPLI (29/10) : ils passent par shared/ai3/repli.lua, par (produit, gisement).
Capi.COUV_EVERY = 5 * 3600   -- lot CAPI-MESURE : une ligne [FO-CAPI-COUV] par gisement toutes les 5 min
Capi.UNITS_MAX = 48          -- lot LEVIERS : machines gardées par groupe au relevé (positions, pour la tâche « equiper »)
Capi.MallRt = require("script.team.mall_rangee") -- lot MALL (tranche 2) : les ordres « chaine » vont dans une rangée du mall (champ, pas une locale)
Capi.RaRt = require("script.ai3.rangees_asm") -- lot RANGEES-ASM : rangées agrandies au lieu d'îlots (champ, pas une locale)
Capi.MODULES_PER_ORDER = 1   -- modules du plan directeur au plus par ordre (chacun au plus A.FIRST_RATE_MAX objets/min :
                             -- un gabarit plus grand ne tient pas dans un lot, moteur réel p1, « pas de lot », « trop grand »).
                             -- 3 avant le banc p4 : le plan directeur RÉSERVE au coffre toute la matière d'un module dès sa
                             -- demande (Build.reserve) ; plusieurs modules à la fois vidaient le fer du QG (« stock iron=5 »)
                             -- et l'économie s'arrêtait (3 factions sur 4 à plus de 60 % de PNJ sans tâche après 40 min).

-- Lot CAPI-DEBIT : sortes d'ordres que l'exécutant pose en MODULE du plan directeur (fonderies à foreuses, rangées).
Capi.MODULE_KINDS = { couvrir = true, ouvrir = true, chaine = true, packs = true }

local function sorted_keys(t) return State.sorted_keys(t or {}) end

local function minutes(f, tick)
  local war = State.war()
  return (tick - (f.started or (war and war.started) or 0)) / 3600
end

local function get(obj, k)
  local ok, v = pcall(function() return obj[k] end)
  if ok then return v end
  return nil
end

function Capi.on(f)
  -- Votre équipe aussi (27/10 au soir) : « si elles ont des ressources, elles veulent encore plus de ressources ».
  if not (Capi.ENABLED and f and f.team and f.team.ia3 and f.hq and f.hq.valid) then return false end
  local war = State.war()
  if war and war.capi_off then return false end
  local s = settings.global[Capi.SETTING]
  if not (s and s.value == true) then return false end
  return Auto.on() and true or false
end

-- Ordres nouveaux au plus par décision (Ca.MAX_ORDERS : 24 dans la règle pure) : le glouton recalcule TOUTES les options
-- après chaque ordre retenu ; l'exécutant n'en prend de toute façon que A.MAX_OPEN à la fois. Banc p4 du lot : décision à
-- 1,45 ms en médiane dans son tick, 5,2 ms au p90, 37 % au-dessus de 2 ms (banc non seul).
Capi.MAX_ORDERS = 4
Ca.MAX_ORDERS = Capi.MAX_ORDERS

-- Sous la capitalisation, A.decide ne demande plus rien (il mesure encore) : un seul décideur.
Auto.decide_off = function(f) return Capi.on(f) end

---------------------------------------------------------------------------------------------------
-- Relevé des prototypes (cache LOCAL : prototypes seulement, identiques chez tous les pairs)
---------------------------------------------------------------------------------------------------
local data_cache = {}
local elec_drill = nil

--- Lot LEVIERS : relevé des modules (effets en centièmes, recettes permises), des emplacements de chaque machine et des
--- recherches à effet (types de R.LEVER_EFFECT) : ce que lit shared/ai3/leviers.lua (Lv.build). Prototypes seulement.
local function lever_dump(d)
  local lv = { equip = {}, slots = {}, techs = {} }
  local protos = game.get_filtered_item_prototypes({ { filter = "type", type = R.ITEM_MODULE } })
  for _, name in ipairs(sorted_keys(protos)) do
    -- les modules cachés du complément de la balise (MOD-0) ne sont pas à vendre
    if name:sub(1, #MM.PREFIX) ~= MM.PREFIX then
      local p = protos[name]
      local eff, me = {}, get(p, "module_effects") or {}
      for _, ef in ipairs(sorted_keys(me)) do eff[ef] = MM.runtime_cents(me[ef].bonus) end
      local lim = get(p, "limitations")
      lv.equip[name] = { effects = eff, limit = (lim and #lim > 0) and lim or nil }
    end
  end
  for _, e in ipairs(d.entities) do
    local p = game.entity_prototypes[e.name]
    local n = p and get(p, "module_inventory_size") or 0
    if n and n > 0 then lv.slots[e.name] = { n = n, allowed = get(p, "allowed_effects") or {} } end
  end
  for _, name in ipairs(sorted_keys(game.technology_prototypes)) do
    local t = game.technology_prototypes[name]
    if not t.research_unit_count_formula then
      local list = {}
      for _, e in ipairs(t.effects or {}) do
        if R.LEVER_EFFECT[e.type] and e.modifier then list[#list + 1] = { type = e.type, modifier = e.modifier } end
      end
      if #list > 0 then lv.techs[name] = list end
    end
  end
  return lv
end

local function dump_full()
  local d = General.dump()
  for _, e in ipairs(d.entities) do
    local p = game.entity_prototypes[e.name]
    if p then
      local conv = Ca.entity_of({ crafting_speed = get(p, "crafting_speed"), mining_speed = get(p, "mining_speed"),
        researching_speed = get(p, "researching_speed"), resource_searching_radius = get(p, "mining_drill_radius"),
        tile_width = get(p, "tile_width"), energy_usage = get(p, "energy_usage") or get(p, "max_energy_usage"),
        emissions_per_second = Prev.emit_per_min(p, e.name) / 60 }) -- lot PREVISION (C12) : avec le repli sur la source d'énergie
      e.speed = e.speed or conv.speed
      -- Intégration 0.6.28 (EQUILIBRE × capitalisation) : bras et tapis ne suivent pas × 1,15 par niveau (L.plan_stat). Une machine améliorée
      -- ne livre que ce que son gabarit transporte : compter la vitesse du prototype gonflait plan.N (× 1,85 au niveau 10 pour une foreuse,
      -- × 4,9 au niveau 20) et plus aucun ordre n'était passé, et l'exécutant (A.sized) dimensionne déjà sur la vitesse de plan.
      local fam = L.parse(e.name)
      local p1 = fam and game.entity_prototypes[fam.base]
      if p1 then e.speed = L.plan_speed(e.name, get(p1, "crafting_speed") or get(p1, "mining_speed")) or e.speed end
      e.mining_area = conv.mining_area
      e.size = conv.size
      e.energy_kw = conv.energy_kw
      e.emit = conv.emit
    end
  end
  for _, r in ipairs(d.resources) do
    local p = game.entity_prototypes[r.entity]
    local mp = p and get(p, "mineable_properties")
    r.mining_time = (mp and mp.mining_time) or 1
  end
  d.lv = lever_dump(d)
  return d
end

--- Données de la règle (Ca.data) pour l'état du réglage de l'automatisation (exécutants).
function Capi.data()
  local on = Auto.on() and true or false
  local D = data_cache[on]
  if D then return D end
  Profiler.start("capi:data")
  local d = dump_full()
  local eo = General.exec_opts(on, d.recipes)
  local exec = {}
  for _, k in ipairs(sorted_keys(eo.exec)) do if eo.exec[k] then exec[k] = true end end
  D = Ca.data(d, { exec = exec, exec_roles = eo.exec_roles, cat = General.catalogue() })
  data_cache[on] = D
  -- Foreuse électrique de l'exécutant : celle que pose le gabarit de fonderie (entités d'AUTO), alimentée au courant.
  local auto_set = {}
  for _, n in ipairs(Auto.exec_entities()) do auto_set[n] = true end
  elec_drill = nil
  for _, m in ipairs(D.drills) do
    if auto_set[m.name] and m.energy == "electric" and not elec_drill then elec_drill = m.name end
  end
  Profiler.stop("capi:data")
  log(string.format("[FO-CAPI] releve des prototypes : %d recettes, %d fabriques, %d foreuses, %d laboratoires, combustible %s, foreuse electrique de l'executant %s",
    #D.recipe_list, #D.makers, #D.drills, #D.labs, tostring(D.fuel), tostring(elec_drill)))
  return D
end

---------------------------------------------------------------------------------------------------
-- État de la faction (global)
---------------------------------------------------------------------------------------------------
local function state_of(f)
  local t = f.team
  t.capi = t.capi or { v = 1, n = 0, st = {}, deps = {}, seeds = {}, open = {}, done = {}, refused = {}, prod = {},
    flows = {}, scan = nil, cov = {}, census_i = 0, decisions = 0, orders = 0, stats = {}, series = {}, cf = Cf.new() }
  t.capi.cf = t.capi.cf or Cf.new() -- lot VIDEO-L5 : carnet de confirmation (partie sauvée avant lui : créé ici)
  return t.capi
end

---------------------------------------------------------------------------------------------------
-- Méthodes de l'exécutant (fonderies à foreuses d'AUTO) : minerai -> méthode
---------------------------------------------------------------------------------------------------
local METHOD_OF_ORE = {}
for _, m in ipairs(A.METHODS) do if m.ore and not METHOD_OF_ORE[m.ore] then METHOD_OF_ORE[m.ore] = m end end
local KIND_OF_RES = {}
for _, kind in ipairs(T.OUTPOST_ORDER) do KIND_OF_RES[T.outposts[kind].resource] = kind end
-- Lot CAPI-DEBIT : produits des fonderies à foreuses (données de l'exécutant, dans leur ordre) : leur stock libre ouvre des
-- emplacements de plus (Em.extra).
local PLATE_PRODUCTS = {}
do
  local seen = {}
  for _, m in ipairs(A.METHODS) do
    if m.ore and m.product and not seen[m.product] then seen[m.product] = true PLATE_PRODUCTS[#PLATE_PRODUCTS + 1] = m.product end
  end
end
-- Lot CORR-CHAMP-MANQUE : minerai de chaque produit des fonderies (le premier de A.METHODS), pour Em.short.
local ORE_OF_PRODUCT = {}
for _, m in ipairs(A.METHODS) do
  if m.ore and m.product and not ORE_OF_PRODUCT[m.product] then ORE_OF_PRODUCT[m.product] = m.ore end
end
-- Lot DEPENSES2 : matières jugées par la règle du stock qui dort : les plaques des fonderies, puis les matières brutes des avant-postes
-- (« défense seule » : la pierre des murs ; la recherche ne les prend pas).
local DEP_PRODUCTS = {}
do
  local seen = {}
  for _, p in ipairs(PLATE_PRODUCTS) do seen[p] = true DEP_PRODUCTS[#DEP_PRODUCTS + 1] = { key = p } end
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local r = T.outposts[kind].resource
    if r and not seen[r] then seen[r] = true DEP_PRODUCTS[#DEP_PRODUCTS + 1] = { key = r, def_only = true } end
  end
end

--- Une fonderie à foreuses de ce minerai peut-elle se poser MAINTENANT (tous ses objets fabricables ou au coffre) ?
--- Rend vrai, ou faux et les objets manquants (la recherche qui les débloque prend de la valeur : Auto.wanted).
--- Gabarit d'une méthode au débit `rate`, RÉDUIT (paramètre agrandi pas à pas vers 1) jusqu'à ce que l'équipe sache
--- fabriquer tous ses objets (comme A.decide : un module plus grand demande des bras rapides ou d'autres objets pas encore
--- recherchés ; banc p4 du lot : modules à 150/min en réserve 15 min sur « fast-inserter », jamais recherché). Rend
--- (gabarit, args) ou (nil, objets manquants de la plus petite taille).
local function fit_module(meth, rate, book, stock, has_plant, harvest, belt_flow)
  -- lot PLANDIR : poteau du gabarit = le moins cher dont la recette est débloquée (A.choose_pole)
  local pole = A.choose_pole(book, stock, harvest) -- lot KIT : le bois à portée compte (les factions n'en ont plus au départ)
  local arms = A.choose_arms(book, stock) -- lot RECHERCHE-BRAS : bras obtenables (nil : tous)
  local g, args = A.sized(meth, rate, pole, arms)
  if not g then return nil, {} end
  local function missing_of(gg)
    local _, items = A.cost(meth, gg, { has_plant = has_plant, belt_flow = belt_flow })
    local miss = {}
    for _, name in ipairs(sorted_keys(items)) do
      if not (book:handcraftable(name) or (stock[name] or 0) > 0) then miss[#miss + 1] = name end
    end
    return miss
  end
  local miss = missing_of(g)
  while #miss > 0 and g.ext and (args[g.ext.arg] or 1) > 1 do
    local a2 = {}
    for i = 1, #args do a2[i] = args[i] end
    a2[g.ext.arg] = args[g.ext.arg] - 1
    local g2 = A.template(meth.gen, a2, pole)
    local g2 = A.template(meth.gen, a2, pole, arms)
    g, args = g2, a2
    miss = missing_of(g)
  end
  if #miss > 0 then return nil, miss end
  return g, args
end

Capi.fit_module = fit_module -- lot ACIER : la rangée de fours d'acier (script/team/acier.lua) dimensionne son gabarit comme un ordre de la capitalisation

local function module_ok(meth, book, stock, has_plant, rate, harvest, belt_flow)
  local g, miss = fit_module(meth, math.min(rate or A.FIRST_RATE_MAX, A.FIRST_RATE_MAX), book, stock, has_plant, harvest, belt_flow)
  if not g then return false, miss end
  return true, {}
end

---------------------------------------------------------------------------------------------------
-- Étape 0 : relevé des machines, foreuses, laboratoires ; graines de gisements
---------------------------------------------------------------------------------------------------
-- Types du moteur relevés : ceux des rôles fabrique, foreuse, laboratoire (shared/ai3/reglages.lua, seules données
-- nommées admises par l'anti-échelle).
local SCAN_ROLES = { fabrique = true, foreuse = true, labo = true }
local SCAN_TYPES = {}
for _, ty in ipairs(R.ENTITY_TYPES) do if SCAN_ROLES[R.ENTITY_ROLE[ty]] then SCAN_TYPES[#SCAN_TYPES + 1] = ty end end

local function dist(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

local function dep_at(cs, res, x, y)
  for _, id in ipairs(sorted_keys(cs.deps)) do
    local d = cs.deps[id]
    if d.resource == res and x >= d.x0 - 3 and x <= d.x1 + 3 and y >= d.y0 - 3 and y <= d.y1 + 3 then return d end
  end
  return nil
end

--- Lot LEVIERS : modules posés dans une machine ({ [objet] = nombre } ou nil) et leur signature (clé de groupe).
local function modules_of(e)
  local ok, inv = pcall(function() return e.get_module_inventory() end)
  if not ok or not inv or #inv == 0 then return nil, "-" end
  local c = inv.get_contents()
  if next(c) == nil then return nil, "-" end
  local mods = {}
  for _, nm in ipairs(sorted_keys(c)) do mods[nm] = c[nm] end
  return mods, Lv.sig(mods)
end

--- Lot C3 EXTENSION (audit n°13) : UN rayon de base. Capi.SCAN_R (160) est le plancher ; la base qui s'étend (étendue des avant-postes + marge,
--- shared/ai3/extension.lua, Ex.base_radius) est recensée en entier, 400 tuiles au plus.
local function scan_radius(f)
  local es = Ext.info(f)
  return es and es.radius and es.radius > Capi.SCAN_R and es.radius or Capi.SCAN_R
end

-- Lot VIDEO-L5 (confirmation observée, PLAN_L3_L5_L13 étape 3) : cause d'un arrêt lue au statut (noms de defines.entity_status,
-- API 1.1.91) ; working et normal : aucune.
local CONF_CAUSE = {}
do
  local by_cause = {
    { "courant", { "no_power", "low_power", "not_plugged_in_electric_network" } },
    { "entree", { "no_ingredients", "item_ingredient_shortage", "fluid_ingredient_shortage", "missing_required_fluid", "no_input_fluid",
      "low_input_fluid", "no_fuel", "no_minable_resources", "waiting_for_source_items" } },
    { "sortie", { "full_output", "waiting_for_space_in_destination" } },
    { "recette", { "no_recipe" } },
  }
  for _, c in ipairs(by_cause) do
    for _, name in ipairs(c[2]) do
      local v = defines.entity_status[name]
      if v ~= nil then CONF_CAUSE[v] = c[1] end
    end
  end
end

--- Lot VIDEO-L5 : suit une unité posée (id = numéro d'unité) sous l'objet `item`, compteur `count` (monotone : produits finis d'une
--- machine ; ou non : objets d'un coffre). Engagée au premier relevé (base 0 : une machine qui a déjà produit est confirmée tout de
--- suite) ; objet changé (recette changée) : intention nouvelle, comptée depuis le compteur d'aujourd'hui.
local function conf_track(cs, obs, g, u, item, count, cause, tick)
  local old = cs.cf.ids[u]
  local base = 0
  if old and old.item ~= item then
    Cf.forget(cs.cf, u)
    old, base = nil, count
  end
  if not old then Cf.engage(cs.cf, { id = u, item = item, base = base }, tick) end
  obs[u] = { count = count, cause = cause }
  g.ids[#g.ids + 1] = u
end

--- Lot VIDEO-L5 : unités CONFIRMÉES d'un groupe : n moins les unités suivies qui ne comptent pas (engagées, arrêtées hors sortie
--- pleine, en échec) ; une unité sans compteur (foreuse sur un tapis, recette inconnue) reste comptée comme avant.
local function conf_group(cs, g)
  local off = 0
  for _, u in ipairs(g.ids) do if not Cf.counts(cs.cf, u) then off = off + 1 end end
  g.n_cap = math.max(0, g.n - off)
  g.ids = nil
end

--- Lot VIDEO-L5 : journal [FO-CAPI-CONF] d'un relevé : échecs et arrêts qui retirent la capacité (avec la cause), puis le bilan.
local function conf_log(f, cs, res, tick)
  local key = f.key or "?"
  local mn = minutes(f, tick)
  for _, e in ipairs(res.failed_now) do
    log(string.format("[FO-CAPI-CONF] %s : echec %s (unite %s) cause %s : %s a %.1f min", key, e.item, tostring(e.id), tostring(e.cause),
      tostring(e.why), mn))
  end
  for _, e in ipairs(res.stopped_now) do
    if not e.keep then
      log(string.format("[FO-CAPI-CONF] %s : arret %s (unite %s) cause %s a %.1f min", key, e.item, tostring(e.id), tostring(e.cause), mn))
    end
  end
  local held = sorted_keys(res.hold)
  log(string.format("[FO-CAPI-CONF] %s : bilan : %d engage(s), %d confirme(s), %d arrete(s), %d echec(s), %d confirme(s) a ce releve, %d perdu(s) ; suspendus : %s a %.1f min",
    key, res.n.engage, res.n.confirme, res.n.arrete, res.n.echec, #res.confirmed_now, #res.lost_now,
    #held > 0 and table.concat(held, " ") or "aucun", mn))
end

local function scan(f, cs, tick)
  local surface = f.hq.surface
  local hq = f.hq_pos
  local scan_r = scan_radius(f)
  Profiler.fstart("scan:find") -- lot X10-S0 : mesure seulement
  local found = surface.find_entities_filtered({ area = { { hq.x - scan_r, hq.y - scan_r },
    { hq.x + scan_r, hq.y + scan_r } }, force = f.force, type = SCAN_TYPES })
  Profiler.fstop("scan:find")
  Profiler.fstart("scan:liste")
  local seen = {}
  local list = {}
  for _, e in ipairs(found) do
    if e.valid and e.unit_number and not seen[e.unit_number] then seen[e.unit_number] = true list[#list + 1] = e end
  end
  -- Foreuses des avant-postes lointains (listes de l'exécutant).
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    for _, d in ipairs(f.outposts[oid].drill_list or {}) do
      if d.valid and d.unit_number and not seen[d.unit_number] then seen[d.unit_number] = true list[#list + 1] = d end
    end
  end
  table.sort(list, function(a, b) return a.unit_number < b.unit_number end)
  Profiler.fstop("scan:liste")
  Profiler.fstart("scan:types")
  local machines, drills, labs = {}, {}, {}
  local mk, dk, lk = {}, {}, {}
  local drill_pos = {}
  -- Lot VIDEO-L5 : observations du relevé (Capi.MUT.sans_conf : tests seulement, le relevé d'avant, sans confirmation)
  local conf = not Capi.MUT.sans_conf
  local obs = conf and {} or nil
  local D = conf and Capi.data() or nil
  for _, e in ipairs(list) do
    local p = e.position
    local role = R.ENTITY_ROLE[e.type]
    if role == "foreuse" then
      local tgt = e.mining_target
      local res = tgt and tgt.valid and tgt.name or nil
      if res then
        local d = dep_at(cs, res, p.x, p.y)
        local did = d and d.id or "?"
        local mods, sig = modules_of(e)
        local k = e.name .. "|" .. res .. "|" .. did .. "|" .. sig
        if not dk[k] then
          dk[k] = { entity = e.name, resource = res, n = 0, deposit = did, mods = mods, sig = sig, units = {}, ids = conf and {} or nil }
          drills[#drills + 1] = dk[k]
        end
        dk[k].n = dk[k].n + 1
        if #dk[k].units < Capi.UNITS_MAX then dk[k].units[#dk[k].units + 1] = { x = p.x, y = p.y, u = e.unit_number } end
        if conf then
          -- compteur de la cible : produits finis du four nourri, ou minerai du coffre ; sans l'un ni l'autre (tapis), pas suivie
          local t = get(e, "drop_target")
          if t and t.valid then
            local count = nil
            if R.ENTITY_ROLE[t.type] == "fabrique" then count = get(t, "products_finished")
            elseif R.KIT_TYPE[t.type] == "coffre" then
              local ok, c = pcall(function() return t.get_item_count(res) end)
              if ok then count = c end
            end
            if count ~= nil then conf_track(cs, obs, dk[k], e.unit_number, res, count, CONF_CAUSE[get(e, "status")], tick) end
          end
        end
        drill_pos[#drill_pos + 1] = { x = p.x, y = p.y, r = get(e.prototype, "mining_drill_radius") or 1, res = res, dep = did }
      end
    elseif role == "labo" then
      if not lk[e.name] then lk[e.name] = { entity = e.name, n = 0 } labs[#labs + 1] = lk[e.name] end
      lk[e.name].n = lk[e.name].n + 1
    elseif Adopte.unserved(f, e) then
      -- lot ADOPTE : machine posée à la main, isolée et non servie par l'équipe (hors rayon, réglage coupé) : pas une capacité
    else
      local r = nil
      local ok = pcall(function() r = e.get_recipe() end)
      if not ok or not r then pcall(function() r = e.previous_recipe end) end
      if r then
        local where = dist(p, hq) <= Capi.HQ_R and Ca.HQ or "?"
        if where ~= Ca.HQ then
          -- fonte sur place : un four sur le bord d'un gisement de son minerai
          for _, ing in ipairs(r.ingredients) do
            local d = dep_at(cs, ing.name, p.x, p.y)
            if d then where = d.id break end
          end
          if where == "?" then where = "loin" end
        end
        local mods, sig = modules_of(e)
        local k = e.name .. "|" .. r.name .. "|" .. where .. "|" .. sig
        if not mk[k] then
          mk[k] = { entity = e.name, recipe = r.name, n = 0, where = where, mods = mods, sig = sig, units = {}, ids = conf and {} or nil }
          machines[#machines + 1] = mk[k]
        end
        mk[k].n = mk[k].n + 1
        if #mk[k].units < Capi.UNITS_MAX then mk[k].units[#mk[k].units + 1] = { x = p.x, y = p.y, u = e.unit_number } end
        if conf then
          -- objet suivi : le premier produit de la recette (relevé des prototypes) ; compteur : produits finis de la machine (sans
          -- compteur lisible : pas suivie, comptée comme avant)
          local rr = D.recipes[r.name]
          local item = rr and rr.products and rr.products[1] and rr.products[1].name
          local count = item and get(e, "products_finished")
          if count ~= nil then conf_track(cs, obs, mk[k], e.unit_number, item, count, CONF_CAUSE[get(e, "status")], tick) end
        end
      end
    end
  end
  Profiler.fstop("scan:types")
  -- Lot VIDEO-L5 : un pas de la confirmation (toutes les unités suivies vues : une absente est perdue), unités confirmées de chaque
  -- groupe (n_cap), objets dont une décision attend (hold, lu par la décision : build_input) ; nil sans confirmation (comme avant).
  local hold = nil
  if conf then
    local cfr = Cf.step(cs.cf, obs, tick, { complete = true })
    if cfr then
      for _, g in ipairs(machines) do conf_group(cs, g) end
      for _, g in ipairs(drills) do conf_group(cs, g) end
      hold = cfr.hold
      conf_log(f, cs, cfr, tick)
      -- lot VIDEO L7 : la main de l'amorce est retirée à la 1re production d'une MACHINE (confirmed_now de L5), jamais sur les
      -- statistiques de la force (votre équipe partage la force du joueur : ses fabrications à la main y entrent)
      local ml = f.team.ia3 and f.team.ia3.mall
      if ml then
        for _, line in ipairs(AmRt.lines(f, ml, AmRt.observe(f, cs, ml, cfr, cs.cf, tick), minutes(f, tick))) do log(line) end
        Pil.kit(f, cs, ml, tick, minutes(f, tick)) -- lot TV-PILOTE (D02) : kit minimal écrit contre le compteur d'amorce
      end
    else
      for _, g in ipairs(machines) do g.ids = nil end
      for _, g in ipairs(drills) do g.ids = nil end
    end
  end
  cs.scan = { tick = tick, machines = machines, drills = drills, labs = labs, drill_pos = drill_pos, hold = hold }
  Profiler.fstart("scan:graines")
  -- Graines de gisements : avant-postes, foreuses, gisements connus (carte d'IA3-f), sites prospectés, lots de gisement
  -- du plan directeur. Une graine déjà dans un gisement recensé n'est pas relue (sauf à l'échéance du recensement).
  local seeds = {}
  local function seed(res, x, y)
    if not (res and x and y) then return end
    if dist({ x = x, y = y }, hq) > scan_r + 64 then return end
    seeds[#seeds + 1] = { res = res, x = math.floor(x), y = math.floor(y) }
  end
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    seed(T.outposts[o.kind] and T.outposts[o.kind].resource, o.pos.x, o.pos.y)
  end
  for _, dp in ipairs(drill_pos) do seed(dp.res, dp.x, dp.y) end
  local Ia3 = package.loaded["script.ai3.cerveau"]
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local res = T.outposts[kind].resource
    local kd = Ia3 and Ia3.known_deposits and Ia3.known_deposits(f, res, tick) or nil
    for i, d in ipairs(kd or {}) do
      if i > 4 then break end
      if (d.distance or 0) <= scan_r then seed(res, d.x, d.y) end
    end
  end
  for _, s in ipairs(f.prospects or {}) do seed(s.resource, s.x, s.y) end
  local b = f.build
  if b then
    for _, k in ipairs(sorted_keys(b.lots)) do
      local l = b.lots[k]
      if l.state == "gisement" and (l.res or l.ore) then
        local x0, y0, x1, y1 = Pl.lot_rect(b.lat, l.i, l.j)
        seed(l.res or l.ore, (x0 + x1) / 2, (y0 + y1) / 2)
      end
    end
  end
  table.sort(seeds, function(a, c)
    local da, dc = dist(a, hq), dist(c, hq)
    if da ~= dc then return da < dc end
    if a.res ~= c.res then return a.res < c.res end
    if a.x ~= c.x then return a.x < c.x end
    return a.y < c.y
  end)
  cs.seeds = seeds
  Profiler.fstop("scan:graines")
  -- graines oubliées après deux échéances du recensement
  for _, k in ipairs(sorted_keys(cs.seed_seen or {})) do
    if tick - cs.seed_seen[k] >= 2 * Capi.CENSUS_EVERY then cs.seed_seen[k] = nil end
  end
end

---------------------------------------------------------------------------------------------------
-- Étape 1 : couverture mesurée des gisements exploités
---------------------------------------------------------------------------------------------------
local OFF = 1048576
local function tkey(x, y) return (x + OFF) * 2097152 + (y + OFF) end

-- Lot COUT-600 : UN gisement par pensée (le plus ancien dû après le curseur cs.cov_last, shared/ai3/cov_pas.lua) au lieu de tous dans la même
-- pensée (382 k instructions par gisement de 600 %, 1,9 M à cinq gisements). Chaque gisement garde la valeur d'avant (Capi.Cov.covered = la boucle
-- d'avant) et est relu au plus toutes les Capi.Cov.EVERY ticks (le rythme d'avant : une fois par cycle). cs.cov_last et d.cov_tick sont dans cs
-- (global, par le stockage de state_of) ; lecteurs : cette fonction. Un gisement apparu ou disparu change la liste triée, jamais le curseur.
local function coverage(f, cs, tick)
  local sc = cs.scan
  if not sc then return end
  local surface = f.hq.surface
  local by_dep = {}
  for _, dp in ipairs(sc.drill_pos) do
    if dp.dep ~= "?" then
      by_dep[dp.dep] = by_dep[dp.dep] or {}
      local l = by_dep[dp.dep]
      l[#l + 1] = dp
    end
  end
  cs.cov = cs.cov or {}
  for _, id in ipairs(sorted_keys(cs.cov)) do
    if not by_dep[id] then cs.cov[id] = nil end
  end
  local ids = {}
  for _, id in ipairs(sorted_keys(by_dep)) do
    if cs.deps[id] then ids[#ids + 1] = id end
  end
  local id = Capi.Cov.next_due(ids, cs.cov_last, function(i) return cs.deps[i].cov_tick end, tick, Capi.Cov.EVERY)
  if not id then return end
  cs.cov_last = id
  local d = cs.deps[id]
  d.cov_tick = tick
  Profiler.fstart("cov:find") -- lot X10-S0 : mesure seulement
  local idx = {}
  for _, e in ipairs(surface.find_entities_filtered({ area = { { d.x0, d.y0 }, { d.x1, d.y1 } }, name = d.resource })) do
    idx[tkey(math.floor(e.position.x), math.floor(e.position.y))] = true
  end
  Profiler.fstop("cov:find")
  local n = Capi.Cov.covered(idx, by_dep[id], tkey)
  cs.cov[id] = n
  d.covered = n
end

---------------------------------------------------------------------------------------------------
-- Étapes 2 à 9 : recensement d'un gisement
---------------------------------------------------------------------------------------------------
local function census_one(f, cs, tick)
  local surface = f.hq.surface
  local seeds = cs.seeds or {}
  local n = #seeds
  if n == 0 then return end
  for _ = 1, n do
    cs.census_i = (cs.census_i % n) + 1
    local s = seeds[cs.census_i]
    local d = dep_at(cs, s.res, s.x, s.y)
    -- une graine relue il y a moins de Capi.CENSUS_EVERY n'est pas relue (une graine HORS de la boîte de son gisement :
    -- centre de site prospecté, gisement connu ; banc p3 : le même gisement recensé à chaque pensée, 4 s de script)
    local sk = s.res .. "@" .. s.x .. "," .. s.y
    cs.seed_seen = cs.seed_seen or {}
    local fresh = cs.seed_seen[sk] and tick - cs.seed_seen[sk] < Capi.CENSUS_EVERY
    if not fresh and (not d or tick - (d.tick or 0) >= Capi.CENSUS_EVERY) then
      cs.seed_seen[sk] = tick
      -- lot COUT-600 : le gisement déjà connu (d) donne la boîte à relire au lieu du carré de 96, puis de 192 tuiles (même résultat)
      local c = Sites.census(surface, s.res, { x = s.x + 0.5, y = s.y + 0.5 }, d)
      if c then
        -- une composante déjà connue sous un autre identifiant (coin épuisé) : la même entrée, mise à jour
        local old = dep_at(cs, s.res, c.cx, c.cy)
        if old and old.id ~= c.id then cs.deps[old.id] = nil end
        local hostile = surface.count_entities_filtered({ position = { x = c.cx, y = c.cy }, radius = 40, force = "enemy",
          limit = 1 }) > 0
        cs.deps[c.id] = { id = c.id, resource = s.res, tiles = c.tiles, amount = c.amount, x0 = c.x0, y0 = c.y0, x1 = c.x1,
          y1 = c.y1, cx = c.cx, cy = c.cy, tick = tick, cut = c.cut, danger = hostile or nil,
          covered = old and old.covered or (cs.deps[c.id] and cs.deps[c.id].covered) or nil,
          cov_tick = (old and old.cov_tick) or (cs.deps[c.id] and cs.deps[c.id].cov_tick) or nil,
          full = (old and old.full) or (cs.deps[c.id] and cs.deps[c.id].full) or nil } -- (lot PAVAGE-GEANT : verdict gardé jusqu'à la décision suivante)
        -- au plus Capi.DEP_MAX gisements : les plus lointains sont oubliés
        local ids = sorted_keys(cs.deps)
        if #ids > Capi.DEP_MAX then
          table.sort(ids, function(a, b)
            local da, db = dist({ x = cs.deps[a].cx, y = cs.deps[a].cy }, f.hq_pos), dist({ x = cs.deps[b].cx, y = cs.deps[b].cy }, f.hq_pos)
            if da ~= db then return da < db end
            return a < b
          end)
          for i = Capi.DEP_MAX + 1, #ids do cs.deps[ids[i]] = nil end
        end
      end
      return
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Entrée de la règle
---------------------------------------------------------------------------------------------------
--- Débits par objet sur la minute écoulée (statistiques de production de la force : machines et foreuses ; la fabrication
--- par script des PNJ n'y entre pas, F244). Rend { [objet] = { made } }.
local function flows_of(f, cs)
  local force = game.forces[f.force]
  local stats = nil
  pcall(function() stats = force.item_production_statistics end)
  local cur = {}
  if stats then pcall(function() cur = stats.input_counts end) end
  local out = {}
  local prev = cs.prod or {}
  for _, k in ipairs(sorted_keys(cur)) do
    local d = (cur[k] or 0) - (prev[k] or 0)
    if d > 0 and prev[k] ~= nil then out[k] = { made = d } end
  end
  cs.prod = cur
  -- Fabrication À LA MAIN des PNJ (insérée par script : hors des statistiques, F244) : compteurs de l'automatisation
  -- (f.team.ia3e.hand_all, objets fabriqués). Elle nourrit aujourd'hui (couverture d'un ingrédient, packs des
  -- laboratoires) sans être du capital (Ca.HAND_CAPITAL = 0).
  local ha = (f.team.ia3e and f.team.ia3e.hand_all) or {}
  local hp = cs.hand_prev or {}
  for _, k in ipairs(sorted_keys(ha)) do
    local d = (ha[k] or 0) - (hp[k] or 0)
    if d > 0 and hp[k] ~= nil then
      local o = out[k] or { made = 0 }
      o.made = (o.made or 0) + d
      o.hand = (o.hand or 0) + d
      out[k] = o
    end
  end
  local copy = {}
  for _, k in ipairs(sorted_keys(ha)) do copy[k] = ha[k] end
  cs.hand_prev = copy
  return out
end

--- Lot MARGE-TIERS : relevé de la fenêtre glissante (shared/ai3/marge.lua) après flows_of : fabriqués = cs.flows (machines, foreuses
--- et main des PNJ), consommés = écart des compteurs cumulés output_counts des statistiques de la force depuis la décision précédente.
--- État : cs.marge_win (relevés), cs.cons (compteurs), cs.marge_t (tick du relevé précédent) : nombres seulement.
local function marge_sample(f, cs, tick)
  local force = game.forces[f.force]
  local stats = nil
  pcall(function() stats = force.item_production_statistics end)
  local cur = {}
  if stats then pcall(function() cur = stats.output_counts end) end
  local used, prev = {}, cs.cons
  for _, k in ipairs(sorted_keys(cur)) do
    local d = (cur[k] or 0) - ((prev or {})[k] or 0)
    if prev ~= nil and d > 0 and prev[k] ~= nil then used[k] = d end
  end
  local copy = {}
  for _, k in ipairs(sorted_keys(cur)) do copy[k] = cur[k] end
  cs.cons = copy
  local made = {}
  for _, k in ipairs(sorted_keys(cs.flows or {})) do
    local m = cs.flows[k].made or 0
    if m > 0 then made[k] = m end
  end
  cs.marge_win = cs.marge_win or Mg.new()
  if prev ~= nil and cs.marge_t ~= nil and tick > cs.marge_t then
    Mg.push(cs.marge_win, { t = tick, dt = (tick - cs.marge_t) / 3600, made = made, used = used })
  end
  cs.marge_t = tick
  return Mg.rates(cs.marge_win)
end

--- File de recherche : la technologie en cours (unités restantes) puis les suivantes du cerveau général.
local function research_of(f, cs)
  local st = f.team.ia3
  local c = General.catalogue()
  local q = {}
  local lab = st.lab or {}
  local function add(tech, left)
    local spec = c.techs[tech]
    if not spec or left <= 0 then return end
    local packs = {}
    for _, ing in ipairs(spec.ingredients or {}) do packs[#packs + 1] = { ing[1], ing[2] } end
    q[#q + 1] = { tech = tech, left = left, time = spec.time or 1, packs = packs }
  end
  if lab.tech and c.techs[lab.tech] then add(lab.tech, c.techs[lab.tech].count - (lab.units or 0)) end
  local g = f.team.iag
  local seen = { [lab.tech or ""] = true }
  for _, t in ipairs((g and g.next) or {}) do
    if not seen[t] and not (st.techs or {})[t] and c.techs[t] then
      seen[t] = true
      add(t, c.techs[t].count)
    end
  end
  -- Recherche ÉLASTIQUE (lot CAPIB, banc p3 : « recherche=47 s/min, labos=1 » à 60 min, épargne de 19 000 MU sans ordre) :
  -- un joueur ne s'arrête pas à la technologie suivante. La file vue par la règle compte aussi les technologies que la
  -- force peut chercher avec les packs qu'elle sait déjà fabriquer (recettes de packs ouvertes), les moins chères
  -- d'abord (unités × temps, puis le nom), au plus Capi.QUEUE_MAX : la demande de packs grandit avec la règle (g par
  -- cycle, jamais plus de Ca.LEAD × ce qui tourne), et avec elle les chaînes et l'extraction en amont.
  local force = game.forces[f.force]
  local open_pack = {}
  for _, p in ipairs(c.pack_list or {}) do
    local r = force and force.recipes[p]
    if r and r.enabled then open_pack[p] = true end
  end
  local extra = {}
  for _, t in ipairs(c.tech_list or sorted_keys(c.techs)) do
    local spec = c.techs[t]
    if spec and not seen[t] and not (st.techs or {})[t] then
      local ok = #(spec.ingredients or {}) > 0
      for _, ing in ipairs(spec.ingredients or {}) do if not open_pack[ing[1]] then ok = false end end
      if ok then extra[#extra + 1] = { t = t, cost = (spec.count or 1) * (spec.time or 1) } end
    end
  end
  table.sort(extra, function(a, b) if a.cost ~= b.cost then return a.cost < b.cost end return a.t < b.t end)
  for i = 1, math.min(Capi.QUEUE_MAX, #extra) do add(extra[i].t, c.techs[extra[i].t].count) end
  -- débit de recherche MESURÉ (secondes de laboratoire par minute) : unités payées depuis la minute précédente
  local key = tostring(lab.tech) .. ":" .. tostring(lab.started or 0)
  local units = lab.units or 0
  local rate = 0
  if cs.r_key == key and cs.r_units then
    local du = units - cs.r_units
    local spec = lab.tech and c.techs[lab.tech]
    if du > 0 and spec then rate = du * (spec.time or 1) end
  end
  cs.r_key, cs.r_units = key, units
  -- laboratoires affamés : des laboratoires, une technologie en cours, et un de ses packs absent du coffre du QG (‰)
  local nlabs = 0
  for _, e in ipairs(st.labs or {}) do if e.valid then nlabs = nlabs + 1 end end
  local starved = 0
  local spec = lab.tech and c.techs[lab.tech]
  if nlabs > 0 and spec and f.hq and f.hq.valid then
    for _, ing in ipairs(spec.ingredients or {}) do
      if Stock.count(f, ing[1]) < (ing[2] or 1) then starved = 1000 end
    end
  end
  return { queue = q, rate = rate, starved = starved }, nlabs
end

--- Clé en repli après un refus (leviers « equiper » et « techno » seulement depuis CAPI-REPLI ; les modules du plan
--- directeur passent par shared/ai3/repli.lua) : rend la raison, ou nil.
local function held(cs, product, tick)
  local b = (cs.backoff or {})[product]
  if b and tick < b.until_tick then
    return string.format("repli apres %d refus du plan directeur (%s) jusqu'a %.0f min", b.n, tostring(b.why), b.until_tick / 3600)
  end
  return nil
end

local function hold(cs, product, why, tick)
  cs.backoff = cs.backoff or {}
  local b = cs.backoff[product] or { n = 0 }
  b.n = b.n + 1
  b.why = why
  b.until_tick = tick + math.min(Capi.BACKOFF_MAX, Capi.BACKOFF * 2 ^ (b.n - 1))
  cs.backoff[product] = b
end

--- Lot CAPI-REPLI : livre des replis des modules, par (produit, gisement) (shared/ai3/repli.lua). Créé à la demande, dans un
--- événement (jamais à on_load) ; une sauvegarde d'avant le lot n'a que cs.backoff, dont les clés de produit ne sont plus lues.
local function repli_book(cs)
  cs.repli = cs.repli or {}
  return cs.repli
end

--- Couverture (‰) d'un gisement suivi et « besoin non servi » de son produit (pénurie mesurée du cerveau) : ce que lit le
--- plafond court du repli (Rp.held).
local function repli_opts(f, d, product)
  local kappa = (d and (d.tiles or 0) > 0) and math.floor(1000 * (d.covered or 0) / d.tiles) or 1000
  local short = (f.team.ia3 and f.team.ia3.short) or {}
  return { kappa = kappa, unserved = product ~= nil and (short[product] or 0) > 0 }
end

-- Lot LEVIERS : machines supérieures de chaque machine posée, lues aux prototypes par le lot AMELIORER (Cap.successors, via
-- Capital.successors_of : aucune logique de successeur ici). Cache LOCAL (prototypes seulement). Nil : la fonction n'existe pas.
local succ_cache = {}
local function successors_for(cs)
  local Cp = package.loaded["script.ai3.capital"]
  if not (Cp and Cp.successors_of) then return nil end
  local out = {}
  for _, m in ipairs(cs.scan and cs.scan.machines or {}) do
    if out[m.entity] == nil then
      local l = succ_cache[m.entity]
      if l == nil then
        l = Cp.successors_of(m.entity) or {}
        succ_cache[m.entity] = l
      end
      out[m.entity] = l
    end
  end
  return out
end

--- Lot PREVISION (C12) : prix de la défense induite (MU par pollution/min de plus) : PV de vague en plus par pollution/min (relevé
--- de la prévision) × marge ÷ valeur d'une tourelle × MU d'une tourelle garnie (valeurs de la règle) ; nil sans relevé ni nid.
local function defense_input(f, D)
  local dv = Prev.capi_defense(f)
  local tmu = D.mu and D.mu[T.turret]
  if not (dv and tmu) then return nil end
  local mu = tmu + ((D.mu[T.turret_ammo] or 0) * T.defend_ammo)
  local price = Pv.defense_price(dv.hp_per_emit, dv.turret_value, mu, dv.marge)
  if price <= 0 then return nil end
  -- Journal [FO-PREVISION] (une ligne par cause : le prix de la défense induite change de plus de 20 %).
  local pst = f.prevision
  -- (relecture de la revue : sous le même plafond de lignes que le reste du journal de la prévision, Prev.LOGS_MAX par équipe)
  if pst and (pst.logs or 0) < Prev.LOGS_MAX
    and (not pst.price_logged or math.abs(price - pst.price_logged) > 0.2 * pst.price_logged) then
    pst.price_logged = price
    pst.logs = (pst.logs or 0) + 1
    log(string.format("[FO-PREVISION] %s DEFENSE INDUITE comptee par la capitalisation : %.2f MU par pollution/min (%.1f PV de vague par pollution/min, tourelle %d PV pour %d MU)",
      tostring(f.key or "player"), price, dv.hp_per_emit, math.floor(dv.turret_value), math.floor(mu)))
  end
  return { price = price, hp_per_emit = dv.hp_per_emit, turret_mu = mu }
end

--- Étape 5a de VIDEO-INTEG (RD_LOG F391 : input.power n'était jamais rempli, la branche du courant de Ca.decide était morte en jeu) :
--- courant disponible = machines à vapeur VIVANTES des centrales finies (PA.watch, script/team/plant_arms.lua : f.build.grow.capacity,
--- J/tick, toutes les 300 ticks). nil sans centrale finie (make_can_exec refuse déjà les modules électriques) ou sans capacité relevée.
--- used_kw : la vue de la PORTE du plan directeur (S.admit, script/team/sante_centrale.lua) : puissance MESURÉE + S.DRAW × consommateurs
--- en chantier (choix (a) du lead, 7/11 vers 17 h 05 : la somme nominale des machines relevées dépasse vite la capacité, la capitalisation
--- refuserait des foreuses que la porte admet) ; la somme nominale va au journal [FO-CAPI-KW], pour comparer. plant : nil (la centrale
--- grandit par C.growth et Sante, pas par un levier de la capitalisation). Capi.MUT.sans_courant, Capi.MUT.nominal : tests seulement.
local JTICK_KW = 60 / 1000 -- J/tick -> kW
Capi.COURANT_LOGS = 40 -- lot TV-ENERGIE (W02) : lignes [FO-CAPI-COURANT] au plus par équipe
function Capi.power_input(f, plant_state, plant_why, wait_plant)
  if Capi.MUT.sans_courant then return nil end
  if plant_state ~= "fini" then
    -- Lot TV-ENERGIE (W02, fin) : sans centrale finie, plus de nil (« aucune borne » : l'électrique passait Ca.decide et n'était refusée qu'à
    -- l'exécutant, make_can_exec). Deux états EXPLICITES (règle pure : Pf.power_missing, Ca.spend_amorce) : centrale refusée, ou demandée
    -- avec un module électrique déjà ouvert (wait_plant) : relevé FERMÉ, refus écrit en amont ; sinon (aucune centrale demandée, ou demandée
    -- sans module électrique ouvert) : AMORÇAGE, un seul ordre électrique par décision (celui qui fait demander la centrale).
    if plant_state == "refuse" then return { fermee = "centrale refusee (" .. tostring(plant_why) .. ")" } end
    if wait_plant then return { fermee = "centrale demandee, pas finie (" .. tostring(plant_state) .. ")" } end
    return { amorce = true, etat = plant_state ~= nil and tostring(plant_state) or "aucune centrale demandee" }
  end
  local g = f.build and f.build.grow
  local cap = g and g.capacity
  -- W02 (lots 5 et 5b) : capacité non lue = relevé VIDE (garde fermée), pas « aucune borne » ; capacité ≤ 0 (centrale finie, plus aucune machine à
  -- vapeur vivante : centrale détruite) = de même (avant : nil, la base posait de l'électrique sans courant). La RECONSTRUCTION de la centrale ne passe
  -- pas par une option de cette règle (plant_arms, Sante) ; les kW retenus par le relevé vide font même grandir la centrale (S.capi_kw).
  if type(cap) ~= "number" or cap <= 0 then
    if type(cap) == "number" and Capi.MUT.cap_ouvert then return nil end -- mutant (tests seulement) : l'ancien comportement
    return {}
  end
  if Capi.MUT.nominal then return { have_kw = cap * JTICK_KW } end -- mutant : la somme nominale de la règle (plan.kw_used)
  local measured = type(g.power) == "number" and g.power > 0 and g.power * JTICK_KW or 0
  -- lot COURANT-LIBRE : un ordre de champ OUVERT réserve déjà ses foreuses à poser (n_left, Ca.apply) : son projet de bande n'est pas compté
  -- une seconde fois parmi les chantiers (avant : 1,6 x les kW de la bande tant que l'ordre durait)
  local except
  for _, rec in ipairs(f.team and f.team.capi and f.team.capi.open or {}) do
    if rec.exec == "champ" and rec.pid and not Capi.MUT.champ_compte_deux then -- (mutant : le projet compté une seconde fois)
      except = except or {}
      except[rec.pid] = true
    end
  end
  return { have_kw = cap * JTICK_KW, used_kw = measured + Sc.DRAW * Sante.committed(f, except) }
end

--- Lot CAPI-DEBIT : emplacements du plan directeur (règle pure shared/ai3/emplacements.lua). Les ordres « module » ouverts, avec
--- l'état de chacun de leurs modules (Auto.module), leur dernier progrès (follow : entités bâties) ; le stock libre des produits des
--- fonderies. Journal [FO-CAPI-EMPLACEMENTS] quand le plafond, le compte ou les modules figés changent (jamais à l'horloge).
function Capi.slots(f, cs, stock, tick, book)
  local mods = {}
  for _, o in ipairs(cs.open or {}) do
    if o.exec == "module" then
      local states = {}
      -- lot DIAG-USINE : suspendu par la pile = chaque module non fini est en réserve « pile » (objets rendus au coffre)
      local suspended = false
      local nmiss = 0 -- lot VIDEO-SIEGES (C4) : objets qui manquent encore aux modules en réserve
      for _, id in ipairs(o.mod_ids or { o.module }) do
        local m = Auto.module(f, id)
        states[#states + 1] = m and tostring(m.state) or "perdu"
        if m and m.state == "reserve" then for _, it in ipairs(m.missing or {}) do nmiss = nmiss + (it[2] or 0) end end
        if m and m.state == "reserve" and m.reason == "pile" then suspended = true
        elseif not (m and m.state == "fini") then suspended = false break end
      end
      -- relecture : entrée en chantier (aussi tenue par follow à chaque pensée) ; sauvegarde 0.6.21 : nil -> posée ici, prudente
      o.work_tick = Em.work_tick(o.work_tick, states, tick)
      o.pile_tick = Em.pile_tick(o.pile_tick, suspended, tick)
      o.mat_tick, o.mat_n, o.mat_s = Em.mat_tick(o.mat_tick, o.mat_n, o.mat_s, states, nmiss, tick) -- lot VIDEO-SIEGES (C4)
      mods[#mods + 1] = { key = o.key, states = states, progress_tick = o.progress_tick, opened = o.opened, work_tick = o.work_tick,
        pile_tick = o.pile_tick, mat_tick = o.mat_tick }
    end
  end
  local plates = {}
  for _, p in ipairs(PLATE_PRODUCTS) do plates[#plates + 1] = (stock or {})[p] or 0 end
  -- Lot C2 : emplacements de chantier selon les bras libres et les ordres retenus faute de place (puits ouvert seulement ; jamais sous A.MAX_OPEN).
  local g_iag = f.team.iag
  local hands = Ca.idle_of(g_iag and g_iag.idle_ema or 0)
  local base = Dm.slots(A.MAX_OPEN, f.team.ia3 and f.team.ia3.puits ~= nil, hands, cs.blocked_slots)
  -- Lot COUVERTURE : les emplacements grandissent avec les chantiers finis (un de plus par Pe.MODULES_PER_SITE), au plus Dm.SLOTS_HARD.
  base = math.min(math.max(base, Dm.SLOTS_HARD), base + Cv.slot_growth(cs.batis_done or Cv.seed(cs.done), Pe.MODULES_PER_SITE))
  -- lot DEPENSES2 (essai 4) : produits qui dorment -> siège du complément (Em.slots, règle 7)
  -- lot CORR-CHAMP-MANQUE (règle 8) : la plaque qui manque LE PLUS aux ordres ouverts (coût brut des manques, recettes ouvertes du
  -- livre de la force, moins le stock libre : Ca.seat_plate, relecture du lead 18 h 10, point 2 ; pas Ca.blocked_items, qui penche
  -- vers le fer) : le champ de son minerai a le siège du complément, même quand rien ne dort (partie du DC 717152950 en 0.6.51,
  -- 11 à 31 min). Sans livre (appelant de banc) : aucun siège de la règle 8.
  local free = {}
  for i, p in ipairs(PLATE_PRODUCTS) do free[p] = plates[i] end
  -- (banc témoin seulement : remote.call("fo-capi", "manque", <clé>, false) éteint la règle 8, cs.no_short)
  local short = {}
  if not cs.no_short then
    -- (seconde relecture, point 2 : hystérésis sur la plaque du relevé précédent, cs.seat_prev)
    local plate = Ca.seat_plate({ open = cs.open, book = book, names = PLATE_PRODUCTS, free = free, prev = cs.seat_prev })
    cs.seat_prev = plate
    if plate then short = Em.short(PLATE_PRODUCTS, ORE_OF_PRODUCT, { [plate] = true }, free) end
  else
    cs.seat_prev = nil
  end
  -- Relecture du lead (18 h 10, point 1, BLOQUANT) : un ordre CHAMP ouvert sur le siège du complément (decide, Em.champ_seat) le tient.
  -- (seconde relecture, point 1 : seulement s'il avance VRAIMENT, posées en hausse depuis moins de Em.STALL : Em.champ_holds)
  local held = 0
  for _, o in ipairs(cs.open or {}) do if Em.champ_holds(o, tick) then held = held + 1 end end
  local sl = Em.slots({ base = base, plates = plates, mods = mods, tick = tick, names = PLATE_PRODUCTS, sleeping = Dep.sleeping(f, tick),
    short = short, held_comp = held })
  if (cs.dm_base or A.MAX_OPEN) ~= base then
    log(string.format("[FO-DEMANDE] %s : EMPLACEMENTS de chantier %s -> %d (base %d + %d : %d bras libres, %d ordre(s) retenu(s) faute de place ; plafond de surete %d) a %.1f min",
      f.key or "?", cs.dm_base and tostring(cs.dm_base) or "-", base, A.MAX_OPEN, base - A.MAX_OPEN, math.floor(hands), cs.blocked_slots or 0, Dm.SLOTS_HARD, minutes(f, tick)))
    cs.dm_base = base
  end
  local comp_list = {} -- lot CORR-CHAMP-MANQUE : le journal suit aussi les produits du siège (stock qui dort, matière qui manque)
  for _, p in ipairs(PLATE_PRODUCTS) do if sl.comp and sl.comp[p] then comp_list[#comp_list + 1] = p end end
  local sig = string.format("%d|%d|%d|%s|%s|%d|%s", sl.cap, sl.counted, sl.open, table.concat(sl.keys_stalled, ","), table.concat(sl.keys_piled, ","),
    sl.comp and sl.room_comp or -1, table.concat(comp_list, ","))
  if cs.slots_sig ~= sig then
    cs.slots_sig = sig
    local pl = {}
    for i, p in ipairs(PLATE_PRODUCTS) do pl[#pl + 1] = p .. "=" .. math.floor(plates[i]) end
    log(string.format("[FO-CAPI-EMPLACEMENTS] %s : %s ; libres %d ; stock {%s} ; figes [%s] ; pile [%s] a %.1f min", f.key or "?", sl.why, sl.room,
      table.concat(pl, " "), table.concat(sl.keys_stalled, ", "), table.concat(sl.keys_piled, ", "), minutes(f, tick)))
  end
  -- Lot VIDEO-L6 (porte des bras, G12) : modules de la capitalisation POSÉS (tous leurs projets « fini ») et chantiers OUVERTS (un projet
  -- ni fini, ni en réserve, ni refusé, ni perdu) ; lus par Capi.portes. Approximation déclarée : seuls les modules de la capitalisation
  -- comptent (ni les autres projets du plan directeur, ni le QG).
  -- (relu module par module : la liste `states` ci-dessus s'arrête au premier projet non fini)
  -- Lot COUVERTURE : les modules déjà finis sont comptés AUSSI quand leur ordre a quitté cs.open (cs.batis_done, Capi.think_tail) ; avant,
  -- seuls ceux d'un ordre encore ouvert comptaient : la limite ⌊batis/25⌋+1 restait à 1 chantier toute la partie (mesuré : minute 257).
  local fini_open, open_sites = 0, 0
  for _, o in ipairs(cs.open or {}) do
    if o.exec == "module" then
      for _, id in ipairs(o.mod_ids or { o.module }) do
        local m = Auto.module(f, id)
        local s = m and m.state
        if s == "fini" then fini_open = fini_open + 1
        elseif s ~= nil and s ~= "reserve" and s ~= "refuse" then open_sites = open_sites + 1 end
      end
    end
  end
  local batis = Cv.batis(cs.batis_done or Cv.seed(cs.done), fini_open)
  sl.batis, sl.open_sites = batis, open_sites
  sl.hands = hands -- lot COUVERTURE : bras libres de cette décision (Cv.sat_modules)
  return sl
end

---------------------------------------------------------------------------------------------------
-- Lot VIDEO-L6 (étape 6 de VIDEO-INTEG) : PORTES AVANT D'ÉTENDRE (règle pure shared/ai3/portes_extension.lua, Pe). Réglage de carte
-- fo-war-portes, ÉTEINT par défaut ; lu avec repli à « éteint » tant qu'il n'est pas déclaré (settings.lua : intégrateur).
---------------------------------------------------------------------------------------------------
Capi.PORTES_SETTING = "fo-war-portes"
-- Ordres qui AJOUTENT des tournées de PNJ : les chantiers du plan directeur (et du champ) et les laboratoires servis à la main.
local PORTES_TOURS = { couvrir = true, ouvrir = true, chaine = true, packs = true, labos = true }

-- Lot TV-FLUX (G51, TODO_VIDEO l.228) : le fluide se juge sur ses barils. Réglage de carte ALLUMÉ par défaut (settings/flux.lua) ; le
-- lecteur garde un repli à « éteint » quand le réglage MANQUE (moteur simulé des tests, qui ne le déclare pas).
Capi.BARILS_SETTING = "fo-war-barils"
function Capi.barils_on()
  local ok, v = pcall(function() return settings.global[Capi.BARILS_SETTING].value end)
  return ok and v == true
end

--- Journal [FO-BARILS] : une ligne quand les unités de fluide comptées en barils CHANGENT (res.barils, shared/ai3/capitalisation.lua, Ca.barrel_stock).
--- État : cs.barils_sig (chaîne). Rend la ligne écrite ou nil.
function Capi.say_barils(f, cs, res, tick)
  local list = {}
  for _, fl in ipairs(sorted_keys(res and res.barils or {})) do list[#list + 1] = fl .. "=" .. string.format("%d", math.floor(res.barils[fl])) end
  local sig = table.concat(list, ",")
  if sig == (cs.barils_sig or "") then return nil end
  cs.barils_sig = sig
  local line = string.format("[FO-BARILS] %s minute %d : fluides comptes en barils au coffre {%s}", f.key or "?", math.floor(minutes(f, tick)), sig)
  log(line)
  return line
end

--- Lot COUVERTURE : une ligne [FO-COUVERTURE] par ordre d'extraction (couvrir, ouvrir) de la décision dont le verdict CHANGE (passe L6 en boucle,
--- passe par un manque mesuré, retenu par la porte avec sa cause). État : cs.couv_sig (clé -> signature, reconstruit à chaque décision :
--- borné par le nombre d'ordres). `r` = résultat de Pe.filter, `verdict` = { clé -> { ok, raison } } de la règle de boucle.
function Capi.say_couverture(f, cs, res, r, verdict, tick)
  local prev, now = cs.couv_sig or {}, {}
  for _, o in ipairs(res.orders or {}) do
    if o.kind == "couvrir" or o.kind == "ouvrir" then
      local held = r.why and r.why[o.key] or nil
      local v = verdict[o.key]
      local what
      if held then
        what = string.format("RETENU par la porte (%s) ; boucle refusee : %s", tostring(held), v and tostring(v[2]) or "manque mesure ou autre racine")
      elseif v and v[1] then
        what = "PASSE la porte du transport EN BOUCLE (" .. tostring(v[2]) .. ")"
      else
        what = "PASSE la porte" .. (v and (" (boucle non retenue : " .. tostring(v[2]) .. ")") or " (manque mesure, ou porte ouverte)")
      end
      local sig = what:sub(1, 90)
      now[o.key] = sig
      if prev[o.key] ~= sig then
        log(string.format("[FO-COUVERTURE] %s minute %d : %s x%d : %s", f.key or "?", math.floor(minutes(f, tick)), tostring(o.key), o.n or 1, what))
      end
    end
  end
  cs.couv_sig = now
end

--- Lot COUVERTURE : saturation totale des gisements revendiqués. Réglage de carte fo-war-saturation (repli à « allumé » tant qu'il n'est pas
--- déclaré : seul un réglage déclaré À FAUX l'éteint).
Capi.SATURATION_SETTING = "fo-war-saturation"
function Capi.saturation_on()
  local ok, v = pcall(function() return settings.global[Capi.SATURATION_SETTING].value end)
  if ok and v == false then return false end
  return true
end

--- Journal [FO-SATURATION] : une ligne par gisement REVENDIQUÉ dont l'état change (ordre ouvert ou fermé, avec la cause) ou dont la couverture passe une
--- tranche de 10 %. « Revendiqué » = ouvert au plan de la décision et au moins une tuile à couvrir. État : cs.sat_sig (id -> signature, reconstruit à chaque
--- décision). Aucune décision n'en dépend.
function Capi.say_saturation(f, cs, res, tick)
  if not res or not res.sat or not res.coverage then return end
  local have = {}
  for _, o in ipairs(res.orders or {}) do
    if (o.kind == "couvrir" or o.kind == "ouvrir") and o.deposit ~= nil then have[tostring(o.deposit)] = "decide" end
  end
  for _, rec in ipairs(cs.open or {}) do
    if (rec.kind == "couvrir" or rec.kind == "ouvrir") and rec.deposit ~= nil and not have[tostring(rec.deposit)] then have[tostring(rec.deposit)] = "ouvert" end
  end
  local refus = {}
  for _, r in ipairs(res.refus or {}) do refus[r.key] = r.why end
  local prev, now = cs.sat_sig or {}, {}
  for _, c in ipairs(res.coverage) do
    if c.open and not c.dead and (c.tiles or 0) > 0 then
      local id = tostring(c.id)
      local state, cause
      if have[id] then
        state, cause = "ouvert", have[id] == "decide" and "ordre de cette decision" or "ordre en cours"
      else
        state = "ferme"
        local v = res.sat[id]
        if v and v.ok then cause = refus["couvrir:" .. id] or "ordre voulu mais non retenu ce cycle (budget, bras, porte ou ordre d'ouverture en cours)"
        elseif v then cause = v.why
        elseif c.kappa >= 1000 then cause = "gisement sature"
        elseif (c.free or 0) <= 0 then cause = "aucune place libre"
        elseif refus["couvrir:" .. id] then cause = refus["couvrir:" .. id]
        else cause = "ordre pris dans ce cycle ou demande en cours" end
      end
      local sig = state .. "|" .. tostring(cause):sub(1, 60) .. "|" .. math.floor(c.kappa / 100)
      now[id] = sig
      if prev[id] ~= sig then
        log(string.format("[FO-SATURATION] %s minute %d : gisement %s %s : %d/%d tuiles couvertes (%d pour mille), ordre %s (%s)", f.key or "?",
          math.floor(minutes(f, tick)), id, tostring(c.resource), c.covered or 0, c.tiles or 0, c.kappa or 0, state, tostring(cause)))
      end
    end
  end
  cs.sat_sig = now
end

function Capi.portes_on()
  local ok, v = pcall(function() return settings.global[Capi.PORTES_SETTING].value end)
  return ok and v == true
end

--- Porte de la décision : { [clé d'ordre] = raison } des ordres retenus, ou nil (réglage éteint : la décision d'avant, inchangée).
--- Entrées : PNJ et PNJ sans tâche de la vue (view.workers, view.workers_waiting), tâches libres qui attendent (view.backlog, écrit par
--- Team.view), modules posés et chantiers ouverts (cs.slots, Capi.slots). État : cs.portes (nombres, booléens, une chaîne).
function Capi.portes(f, cs, res, view, tick)
  if not Capi.portes_on() then return nil end
  cs.portes = cs.portes or Pe.new()
  local sl = cs.slots or {}
  local a = { workers = view.workers, idle = view.workers_waiting, free_tasks = view.backlog, batis = sl.batis, open_sites = sl.open_sites,
    site_floor = sl.cap }
  local was = cs.portes.closed
  -- Lot L3 versé (étape 4) : manque net MESURÉ (view.mq.build) : un ordre sur un objet en manque mesuré est une petite marche (comptée)
  -- et ne vise pas le même objet que l'ordre mesuré de la décision précédente, sauf s'il est seul en manque (Pe.check, anti-répétition).
  local build = view.mq and view.mq.build or nil
  local n_build = 0
  for _, k in ipairs(sorted_keys(build)) do if (build[k] or 0) > 0 then n_build = n_build + 1 end end
  -- Lot tv-fer : RACINE. Un ordre couvrir/ouvrir dont le produit (METHOD_OF_ORE) est en manque (mesuré L3 : view.mq.build, ou manque du
  -- plan : f.team.missing) crée la source de ce manque : il passe la porte du transport (les PNJ occupés à le remplacer à la main la
  -- fermeraient pour toujours). Les rangs, la porte des chantiers et l'anti-répétition restent inchangés.
  local short = {}
  for _, k in ipairs(sorted_keys(build)) do if (build[k] or 0) > 0 then short[k] = build[k] end end
  for _, m in ipairs(f.team and f.team.missing or {}) do
    if type(m) == "table" and m[1] ~= nil and (m[2] or 0) > 0 then short[m[1]] = math.max(short[m[1]] or 0, m[2]) end
  end
  local product_of = {}
  -- Lot COUVERTURE (8/11, DC : « ils construisent pas en boucle ») : seconde sorte de racine, la COUVERTURE EN BOUCLE. Un couvrir/ouvrir dont le
  -- produit n'est pas saturé (f.team.ia3.saturated : stock au-delà de B.SAT_FACTOR × le besoin) et dont le gisement a des places libres passe
  -- la porte du transport même sans manque mesuré (shared/ai3/couverture.lua) : les PNJ d'une force sont occupés en permanence, la porte restait
  -- fermée de la minute 2 à la 60 et retenait tous les couvrir (mesuré 0.6.64). La porte des chantiers (Pe.site_room) borne le travail ouvert.
  local ia3 = f.team and f.team.ia3 or nil
  local saturated = ia3 and ia3.saturated or {}
  local free_of = {}
  for _, c in ipairs(res.coverage or {}) do free_of[tostring(c.id)] = c.free end
  local crisis = (view.survie or view.hq_threat) and true or false
  local verdict = {} -- clé d'ordre -> { vrai/faux, raison } de la règle de couverture en boucle
  local function root_of(o)
    if o.kind ~= "couvrir" and o.kind ~= "ouvrir" then return nil end
    local meth = METHOD_OF_ORE[o.resource]
    local n = meth and short[meth.product] or nil
    if n then product_of[o.key] = meth.product return n end
    local ok, why = Cv.loop({ kind = o.kind, product = meth and meth.product or nil, saturated = saturated,
      free = free_of[tostring(o.deposit)], crisis = crisis, saturation = o.saturation })
    verdict[o.key] = { ok, why }
    if ok then return 1 end -- racine « de boucle » : un nombre > 0 suffit à la porte (le manque n'est pas écrit au journal des racines)
    return nil
  end
  local r = Pe.filter(cs.portes, a, res.orders, { family_of = Pi.order_family, family_rank = Pi.FAMILY_RANK,
    site_kinds = Capi.MODULE_KINDS, tours_kinds = PORTES_TOURS, measured = build, measured_n = n_build, root_of = root_of })
  for _, rt in ipairs(r.roots or {}) do
    if not (verdict[rt.key] and verdict[rt.key][1]) then
      log(string.format("[FO-PORTES] racine : %s passe L6 (manque %s %s)", tostring(rt.key), tostring(product_of[rt.key] or rt.item), tostring(rt.need)))
    end
  end
  Capi.say_couverture(f, cs, res, r, verdict, tick)
  if r.refused > 0 or r.closed ~= was then
    log(string.format("[FO-PORTES] %s minute %d : transport %s (%d fermeture(s)) ; %d ordre(s) gardes, %d retenu(s), %d qu'une petite marche aurait reduit(s) ; places de chantier %d sur %d (%d pose(s), %d ouvert(s)) ; %s",
      f.key or "?", math.floor(minutes(f, tick) + 0.5), r.closed and "SATURE" or "libre", cs.portes.closes or 0, r.kept, r.refused, r.reduced,
      r.room, r.limit, sl.batis or 0, sl.open_sites or 0, tostring(r.cause)))
  end
  return r.why
end

---------------------------------------------------------------------------------------------------
-- Lot VIDEO-L10 (étape 7 de VIDEO-INTEG) : MARCHES DE STABILITÉ, VARIANTE B de C2 (règle pure shared/ai3/palier.lua, Pl). Réglage de carte
-- fo-war-paliers, ÉTEINT par défaut (repli à « éteint » tant qu'il n'est pas déclaré : settings.lua, intégrateur). Éteint : C2 (variante A)
-- inchangé. Allumé : le puits élastique de C2 (input.demande) ne s'ouvre qu'à la décision où une marche tombe (5 min de stabilité
-- continue sans pose) ; sa taille reste celle de C2 (Dm.step, Dm.extra_cap selon les bras : écart déclaré au « un laboratoire » de la
-- source). Le critère A/B est Pl.verdict (3 graines, accord du DC : bancs longs).
---------------------------------------------------------------------------------------------------
Capi.PALIERS_SETTING = "fo-war-paliers"

function Capi.paliers_on()
  local ok, v = pcall(function() return settings.global[Capi.PALIERS_SETTING].value end)
  return ok and v == true
end

--- Entrées de Pl.step lues dans l'état du jeu (aucun temps mesuré) : manques = objets en manque net MESURÉ (L3, view.mq.build ; nil si
--- L3 est éteint : jamais stable) ; crise = mode survie ou QG menacé (L12) ; bras libres (comme Capi.slots) ; pose = un module de la
--- capitalisation de plus est « fini » depuis la décision précédente (cs.slots.batis, Capi.slots) ; arbre fini = plus aucune technologie
--- à la file (input.research.queue).
function Capi.palier_inputs(f, cs, view, input)
  local st = cs.palier
  local batis = (cs.slots and cs.slots.batis) or 0
  local pose = st.batis_prev ~= nil and batis > st.batis_prev
  local build = view.mq and view.mq.build or nil
  -- lot BLOCAGE-SORTIE-2 : un manque qu'aucune décision ne peut lever (cs.impayable, lu par Ca.obtainable à la décision précédente) ne retient plus le palier
  local manques, ecartes = Pal.fixable(build, cs.impayable)
  local g_iag = f.team.iag
  local arbre_fini = true
  for _, q in ipairs((input.research or {}).queue or {}) do if (q.left or 0) > 0 then arbre_fini = false break end end
  -- Lot BLOCAGE-SORTIE-2 (soupape de dormance, shared/ai3/palier.lua) : le stock libre dort-il ? (Dm.sleeping : mêmes MU que la décision ;
  -- le besoin évalué est absent sous menace du QG ou besoin non évalué : alors nil, jamais de soupape)
  local dort, stock_mu, free_mu = nil, 0, 0
  if input.reserve and type(input.reserve.free) == "table" and input.data then
    dort, stock_mu, free_mu = Dm.sleeping(input.data, input.stock or {}, input.reserve.free)
  end
  return { manques = manques, crise = (view.survie or view.hq_threat) and true or false,
    bras_libres = math.floor(Ca.idle_of(g_iag and g_iag.idle_ema or 0)), pose = pose, arbre_fini = arbre_fini, dort = dort,
    stock_mu = stock_mu, free_mu = free_mu, ecartes = ecartes }, batis
end

--- Une décision (decide_start, après build_input, AVANT l'instantané) : rend la marche ou nil. Réglage allumé : input.demande n'est vrai
--- qu'à la décision de la marche. État : cs.palier (Pl : nombres et booléens ; batis_prev).
function Capi.palier(f, cs, view, input, tick)
  if not Capi.paliers_on() then cs.palier = nil return nil end
  cs.palier = cs.palier or Pal.new()
  local st = cs.palier
  local a, batis = Capi.palier_inputs(f, cs, view, input)
  st.batis_prev = batis
  local had = st.until_tick
  local since = st.manque_depuis
  local mk, ev = Pal.step(st, a, tick)
  -- lot BLOCAGE-SORTIE-2 : si c'est le palier qui ferme le puits (le reste l'autorisait), sa raison part avec l'entrée (décision, journal [FO-DEMANDE])
  if input.demande and mk == nil then input.palier_why = Pal.explain(a, ev, st, tick) end
  input.demande = (input.demande and mk ~= nil) and true or false
  local sig = table.concat(a.ecartes or {}, ",")
  if sig ~= (st.ecartes_sig or "") then
    st.ecartes_sig = sig
    if sig ~= "" then
      log(string.format("[FO-SORTIE] %s minute %d : manque(s) INSOLUBLE(S) ecarte(s) de la stabilite du palier : %s (ni au stock, ni ressource extractible, ni recette ouverte a ingredients obtenables) ; %s manque(s) restant(s)",
        f.key or "?", math.floor(minutes(f, tick) + 0.5), sig, tostring(a.manques)))
    end
  end
  -- Lot BLOCAGE-SORTIE-2 : [FO-SORTIE], une ligne à l'ouverture de la soupape et une à sa fermeture, avec la cause
  if ev == "soupape" then
    log(string.format("[FO-SORTIE] %s minute %d : soupape de dormance OUVERTE (%d manque(s) seuls depuis %.1f min, stock libre %d MU sur %d MU qui dort, %d bras libres) : puits de C2 ouvert a chaque decision, sans minuteur ; ouvertures %d",
      f.key or "?", math.floor(minutes(f, tick) + 0.5), a.manques or 0, (tick - (since or tick)) / 3600, math.floor(a.free_mu or 0),
      math.floor(a.stock_mu or 0), a.bras_libres, st.soupapes or 0))
  elseif ev == "soupape_ferme" then
    local why = (not a.dort and "le stock ne dort plus ou le besoin n'est plus evalue") or (a.crise and "crise (survie ou QG menace)")
      or (a.bras_libres < Pal.HANDS_MIN and "aucun bras libre") or ((a.manques or 0) == 0 and "plus aucun manque : la video reprend") or "autre"
    log(string.format("[FO-SORTIE] %s minute %d : soupape de dormance FERMEE : %s ; ouvertures %d",
      f.key or "?", math.floor(minutes(f, tick) + 0.5), why, st.soupapes or 0))
  end
  if ev == "marche" or ev == "arme" or ev == "annule" or (had and not st.until_tick) then
    log(string.format("[FO-PALIER] %s minute %d : %s (minuteur %s, marches %d, annulations %d) ; manques %s, crise %s, bras libres %d, pose %s, arbre fini %s%s",
      f.key or "?", math.floor(minutes(f, tick) + 0.5), tostring(ev), tostring(st.until_tick), st.marches or 0, st.annules or 0,
      tostring(a.manques), tostring(a.crise), a.bras_libres, tostring(a.pose), tostring(a.arbre_fini),
      mk and (" ; marche " .. mk.kind .. " : puits de C2 ouvert pour cette decision") or ""))
  end
  return mk
end

--- Lot CAPI-DECIDE : l'exécutant des chaînes sait-il les poser aujourd'hui ? (input.can_exec de la règle, mémo de la décision.)
--- Faite depuis ses DONNÉES `d` (stock, objets voulus, repli, tick, emplacements, centrale, portée, débit des tapis) et le livre :
--- une décision découpée la refait à l'identique depuis l'instantané, jamais depuis l'état vivant du jeu. Écrit dans d.wanted.
local function make_can_exec(d, book)
  local ce_memo = {}
  local stock, wanted, repli, tick = d.stock, d.wanted, d.repli, d.tick
  return function(kind, item)
    -- fours du QG : nourris à la main par les PNJ (tâches de fonte du cerveau) ; leur nombre reste au décideur d'avant
    -- (Br.smelters, SCALE). Moteur réel, banc p2 du lot : 25 fours du QG commandés « d'avance » pour les briques, 25
    -- affamés sur 26 (aucune tâche de fonte ne les nourrit sans manque). La fonte au débit des foreuses passe par les
    -- fonderies à foreuses (ordre « couvrir » : leurs fours sont dimensionnés par le gabarit sur le minerai des foreuses).
    if kind == "fours" then return "fours du QG nourris par les PNJ : decideur SCALE (Br.smelters)" end
    -- Lot LEVIERS : un module s'insère s'il est au coffre, ou si l'équipe sait le fabriquer à la main aujourd'hui (la
    -- recherche qui le débloque est sinon DEMANDÉE : wanted, donnée à la recherche par Auto.want).
    if kind == "equiper" then
      local m2 = ce_memo[item]
      if m2 ~= nil then return m2 or nil end
      local res2 = nil
      if (stock[item] or 0) <= 0 and not book:handcraftable(item) then
        res2 = "recherche : " .. item
        wanted[item] = true
      end
      ce_memo[item] = res2 or false
      return res2
    end
    local m = ce_memo[item]
    if m ~= nil then return m or nil end
    local meth, why = A.method_for(item, book, function(n) return book:handcraftable(n) or (stock[n] or 0) > 0 end)
    local res = nil
    local hw = Rp.held(repli, Rp.key(item, nil), tick, nil) -- lot CAPI-REPLI : chaînes et packs, clé = l'objet seul
    if not meth then res = tostring(why)
    elseif hw then res = hw
    elseif d.busy then res = d.busy_text
    elseif d.wait_plant and ((A.template(meth.gen, meth.args) or {}).power_kw or 0) > 0 then
      res = "centrale demandee, pas finie (" .. tostring(d.plant_state) .. ")"
    elseif d.plant_state == "refuse" and ((A.template(meth.gen, meth.args) or {}).power_kw or 0) > 0 then
      res = "centrale refusee (" .. tostring(d.plant_why) .. ")"
    else
      local ok, miss = module_ok(meth, book, stock, d.plant_state ~= nil, nil, d.reachable, d.belt_flow)
      if not ok then
        res = "recherche : " .. table.concat(miss, ",")
        for _, x in ipairs(miss) do wanted[x] = true end
      end
    end
    ce_memo[item] = res or false
    return res
  end
end

--- Lot VIDEO-L3 : résultat du manque mesuré de l'équipe (script/team/manque_vue.lua, f.team.mq.res) s'il a moins de 2 min, sinon nil.
--- Ses manques de MODULES (consommation d'un module fini qu'aucun autre puits ne voit) deviennent des puits (Mq.sinks).
local function mq_fresh(f, tick)
  local m = f.team and f.team.mq
  if m and m.res and m.tick and tick - m.tick <= 2 * 3600 then return m.res end
  return nil
end

local function build_input(f, cs, view, book, tick, D, w)
  local st = f.team.ia3
  local force = game.forces[f.force]
  D.bonus.mining = (force and force.mining_drill_productivity_bonus) or 0
  D.bonus.lab = (force and force.laboratory_speed_modifier) or 0
  local stock = view.stock or {}
  local threat, production_first = Sv.capi(Survie.on(f) and not (view.qg_peril and view.qg_peril.peril), view.threatened or false, (f.team and f.team.priorite_pf) or false)
  if threat and R.PILE_BUDGET and Pi.threat_open(st.pile) then threat = false end -- lot PILE-BUDGET (relecture) : défense payée, l'évolution continue
  -- Lot L12 (partie 3) : la menace TENUE (view.threat_held, script/team/menace_equipe.lua : jusqu'à 2 pensées calmes avec une tourelle armée
  -- au QG, ou 5 min après la dernière perte) ferme aussi les gisements. Avant, la décision ne voyait la menace que par fenêtres de 15 s
  -- (f.threatened_until). Ni le budget couvert (Pi.threat_open) ni l'échéance ne la lèvent : seule la règle tenue ; le mode survie, si (Sv.capi).
  local def_share = BdRt.share(f, tick) -- lot S42-DEFENSE (nil : regle coupee ou votre equipe)
  cs.def_dyn = def_share ~= nil or nil
  local threat_why = threat and "menace recente du QG (view.threatened)" or nil -- lot BLOCAGE-SORTIE-2 : origine écrite au journal du puits fermé
  if not threat and view.threat_held then
    threat = (Sv.capi(Survie.on(f) and not (view.qg_peril and view.qg_peril.peril), true, production_first))
    if threat then threat_why = "menace tenue (view.threat_held)" end
  end
  -- foreuse imposée par ressource : électrique (fonderie du plan directeur) si le gabarit se pose aujourd'hui ; sinon
  -- AUCUNE (« » : la règle refuse « aucune foreuse disponible »). Les avant-postes à combustion restent au décideur
  -- d'avant (croissance des buts et vagues de SCALE) : leur combustible est porté par les PNJ, un travail récurrent que
  -- la règle ne compte pas (moteur réel, bancs p1 et p2 du lot : avant-postes « pleins », puis 75 à 102 foreuses à
  -- combustion sans charbon, fer extrait divisé par 4, 50 à 75 % de PNJ sans tâche).
  local drill_for, elec = {}, {}
  local plant_state, plant_why = Auto.plant_state(f)
  -- Centrale demandée mais pas finie : un seul module électrique ouvert à la fois (celui qui l'a fait demander) ; les
  -- suivants attendent le réseau (banc p3 du lot : « pas de rue vers le reseau », « pas de centrale » à la chaîne).
  -- Lot CAPI-DEBIT : emplacements (A.MAX_OPEN de base) : un module figé en chantier depuis Em.STALL n'en tient plus, un stock
  -- riche en ouvre de plus ; un module qui attend sa matière tient toujours le sien (la matière réservée par le plan directeur
  -- ne doit pas vider le coffre, banc p4). cs.slots sert aussi au décompte des ordres d'une même décision (decide).
  local slots = Capi.slots(f, cs, stock, tick, book)
  cs.slots = slots
  local elec_open = slots.open
  local wait_plant = plant_state ~= nil and plant_state ~= "fini" and elec_open > 0
  local busy = slots.busy
  local busy_text = Em.busy_text(slots)
  local wanted = {}
  -- Lot CAPI-MESURE : la RAISON de chaque `drill_for = ""` (audit 29/10 : jamais journalisée), relue par [FO-CAPI-COUV].
  -- Lot CAPI-REPLI : le repli ne ferme plus la ressource (il était porté par le produit : tous les gisements à la fois) ; il
  -- ferme le GISEMENT en cause (boucle des gisements ci-dessous, Rp.held).
  local drill_why = {}
  for _, res in ipairs(D.res_list) do
    local meth = METHOD_OF_ORE[res]
    local ok, miss = false, {}
    local why = nil
    if not meth then why = "aucune fonderie a foreuses pour ce minerai"
    elseif not elec_drill then why = "aucune foreuse electrique de l'executant"
    elseif plant_state == "refuse" then why = "centrale refusee (" .. tostring(plant_why) .. ")"
    elseif wait_plant then why = "centrale demandee, pas finie (" .. tostring(plant_state) .. ")"
    elseif Em.drill_refused(slots, meth.product) then why = busy_text -- (lot DEPENSES2 : siège du complément ; règle pure, testée)
    else
      ok, miss = module_ok(meth, book, stock, plant_state ~= nil, nil, Harvest.reachable(f), Auto.belt_flow(f))
      if not ok then why = "objets impossibles : " .. table.concat(miss, ",") end
    end
    if ok then drill_for[res], elec[res] = elec_drill, true
    else
      drill_for[res] = ""
      drill_why[res] = why or "?"
    end
    for _, m in ipairs(miss) do wanted[m] = true end
  end
  cs.drill_why = drill_why
  cs.wanted_set = wanted
  local repli = repli_book(cs)
  -- gisements : recensés, ouverts s'ils portent une foreuse de la force ou un avant-poste ; portée du plan directeur
  -- (lot GISEMENTS : une enceinte fige le treillis sous RADIUS_MAX, journal du DC « rayon 4 » : au-delà, ordres refusés sans fin)
  local enc = f.build and f.build.enc
  -- Intégration 0.6.32 (C3) : une enceinte complète ne fige plus le treillis (Build.beyond_wall) : sans cela, un gisement au-delà de son rayon
  -- restait « hors du plan directeur » alors que le treillis y va.
  if enc and Build.beyond_wall(f.build) then enc = nil end
  local reach = (Tr.reach_radius(enc and enc.r, Build.RADIUS_ORE) + 0.5) * Pl.PITCH -- lot INDUSTRIE I3 : jusqu'à RADIUS_ORE (12), plus RADIUS_MAX (5)
  if not Rsv.on() then reach = ((enc and enc.r and math.min(enc.r, Build.RADIUS_MAX) or Build.RADIUS_MAX) + 0.5) * Pl.PITCH end -- réglage maître éteint
  local open_dep = {}
  for _, dr in ipairs(cs.scan and cs.scan.drills or {}) do if dr.deposit ~= "?" then open_dep[dr.deposit] = true end end
  local deposits = {}
  for _, id in ipairs(sorted_keys(cs.deps)) do
    local d = cs.deps[id]
    local blocked = nil
    if cs.block_all then blocked = "interdit (banc)" end -- lot LEVIERS : banc « tous les sites interdits » (remote block_sites)
    local smelt, smelter = nil, nil
    if elec[d.resource] then
      local far = math.max(math.abs(d.cx - f.hq_pos.x), math.abs(d.cy - f.hq_pos.y))
      if far > reach then blocked = "hors du plan directeur" end
      local meth = METHOD_OF_ORE[d.resource]
      smelter = meth.args[1]
      -- Lot CAPI-REPLI : repli par (produit, gisement) ; plafonné à 5 min si la couverture est sous 50 % et le besoin non servi
      if not blocked then
        blocked = Rp.held(repli, Rp.key(meth.product, id), tick, repli_opts(f, d, meth.product))
      end
      for _, rn in ipairs(D.producers[meth.product] or {}) do
        local r = D.recipes[rn]
        for _, i in ipairs(r.ingredients) do if i.name == d.resource and not smelt then smelt = rn end end
      end
    end
    deposits[#deposits + 1] = { id = id, resource = d.resource, tiles = d.tiles, amount = d.amount, covered = d.covered,
      dist = math.floor(dist({ x = d.cx, y = d.cy }, f.hq_pos)), open = open_dep[id] or false, smelt = smelt,
      smelter = smelter, danger = d.danger, blocked = blocked, x = d.cx, y = d.cy } -- (x, y : lot GISEMENTS, site voisin)
  end
  -- ordres ouverts : reste à poser
  local open = {}
  for _, o in ipairs(cs.open) do
    open[#open + 1] = { key = o.key, kind = o.kind, item = o.item, resource = o.resource, deposit = o.deposit,
      entity = o.entity, n = o.n, n_left = o.n_left or o.n, rate = o.rate, where = o.where, smelt_n = o.smelt_n,
      smelt_left = o.smelt_left, smelt_recipe = o.smelt_recipe, smelt_entity = o.smelt_entity, missing = o.missing or {},
      work_left = o.work_left, value = o.value,
      -- lot LEVIERS : ce que l'ordre ajoute au plan tant qu'il n'est pas fini
      tech = o.tech, d_item = o.d_item, d_out = o.d_out, d_in = o.d_in, d_kw = o.d_kw, d_fuel = o.d_fuel }
  end
  local research, nlabs = research_of(f, cs)
  cs.nlabs = nlabs
  local labs = {}
  for _, l in ipairs(cs.scan and cs.scan.labs or {}) do labs[#labs + 1] = { entity = l.entity, n = l.n } end
  -- besoin des buts SANS les buts capi ni la recherche : le besoin de matière de la dernière pensée (manque + usage)
  local need = {}
  for _, k in ipairs(sorted_keys(st.need)) do need[k] = st.need[k] end
  -- L'exécutant des chaînes (rangées du plan directeur) sait-il les poser aujourd'hui ? Lot CAPI-DECIDE : la fonction est refaite
  -- depuis ses DONNÉES (make_can_exec), gardées dans l'instantané d'une décision découpée.
  local cex = { stock = stock, wanted = wanted, repli = repli, tick = tick, busy = busy, busy_text = busy_text, wait_plant = wait_plant,
    plant_state = plant_state, plant_why = plant_why, reachable = Harvest.reachable(f), belt_flow = Auto.belt_flow(f) }
  local can_exec = make_can_exec(cex, book)
  local g = f.team.iag
  -- Lot LEVIERS : clés d'ordres de leviers refusées par l'exécutant, en repli (Ca.decide : input.skip).
  local skip = {}
  for _, k in ipairs(sorted_keys(cs.stale or {})) do
    if cs.scan and cs.scan.tick == cs.stale[k] then skip[k] = true else cs.stale[k] = nil end
  end
  for _, k in ipairs(sorted_keys(cs.backoff or {})) do
    if (k:sub(1, 8) == "equiper:" or k:sub(1, 7) == "techno:") and held(cs, k, tick) then skip[k] = true end
  end
  return {
    can_exec = can_exec, skip = skip, successors = successors_for(cs),
    data = D, state = { techs = st.techs or {}, known = st.known }, stock = stock, flows = cs.flows or {},
    barils = Capi.barils_on() or nil, -- lot TV-FLUX (G51) : un fluide se juge sur ses barils pleins au coffre (nil : le stock d'avant)
    -- lot VIDEO-L13 : plus de `or {}` (une liste absente ferme la décision, decide_start ; cs.scan existe : Capi.think)
    machines = cs.scan and cs.scan.machines, drills = cs.scan and cs.scan.drills, labs = labs,
    hold = cs.scan and cs.scan.hold, -- lot VIDEO-L5 : objets suspendus (nil : sans confirmation, la capacité compte à la pose)
    -- lot VIDEO-L3 : les manques mesurés des modules finis s'ajoutent aux puits (Mq.sinks ; Ca.requirements n'est pas touché)
    deposits = deposits, open = open, sinks = cs.bench_sinks or Mq.sinks(mq_fresh(f, tick), Ml.sinks(st.mall)), need = need, research = research, drill_for = drill_for,
    saturation = Capi.saturation_on() or nil, -- lot COUVERTURE : saturation totale des gisements revendiqués (réglage fo-war-saturation, allumé par défaut)
    excl = Excl.read(), -- lot VIDEO-PLAFONDS (V99) : objets exclus de la demande (nil : réglage vide, entrée inchangée)
    hard_off = (not Pil.plafonds_on()) or nil, -- lot TV-PILOTE (G02) : plafonds de sûreté des fours, chaînes et packs (réglage fo-war-plafonds, allumé par défaut)
    limits = Rsv.on() and {} or { max_ingredients = 2 }, workers = view.workers or 0, idle = Ca.idle_of(g and g.idle_ema or 0),
    can_grow = (view.workers or 0) < (view.workers_wanted or 0), traits = f.traits or {},
    weights = w or {}, threat = threat, threat_why = threat_why, dt = 1, lag = cs.lag, starved = Pi.threat_exempt(st.pile, st.starved_open), -- (intégration 0.6.28)
    reserve = (not threat) and Dep.capi_reserve(f, Rsv.input(f, tick), tick) or nil, -- lot INDUSTRIE I1 : stock hors besoin (nil : réglage éteint, besoin périmé ou QG menacé) ; lot DEPENSES2 (revue D2) : débité de ce que la règle du stock qui dort a accordé ou engagé
    demande = (not threat) and Rsv.on() and not cs.demande_off or false, -- (cs.demande_off : BANC SEULEMENT, témoin) lot C2 : puits ouvert (le stock hors besoin qui dort devient une demande)
    demande_sleep = Dm.SLEEP_CYCLES, -- intégration 0.6.32 : un stock ne dort qu'après 3 décisions de suite au-dessus du seuil
    -- Lot PRIORITE-RESSOURCES : la pensée précédente du cerveau a décidé « production d'abord » (shared/team/priorite.lua)
    -- Lot SURVIE-PENURIE : en mode survie (pénurie durable d'une matière clé), aucune part pour la défense ni l'armée et la menace
    -- ne ferme plus les leviers hors du QG (Sv.capi) ; les gisements dangereux restent exclus (`danger` de chaque gisement).
    production_first = production_first,
    def_share = def_share, -- lot S42-DEFENSE : part de la defense (pour mille) mesuree sur les pertes recentes (nil : part du caractere)
    defense = defense_input(f, D), -- lot PREVISION (C12) : « oui, compter la défense » dans le coût de chaque investissement
    power = Capi.power_input(f, plant_state, plant_why, wait_plant), -- étape 5a de VIDEO-INTEG : courant des centrales finies ; lot TV-ENERGIE (W02) : amorce ou relevé fermé sans centrale finie
    solid_mesure = true, -- lot CONSOLIDATION-TIERS : `flows` est mesuré (statistiques de production de la force) ; la porte de rang juge la maturité des tiers
    mq_build = view.mq and view.mq.build or nil, -- lot VIDEO-ORDRE : manque net MESURÉ par objet (L3) ; un objet posé n'est re-ordonné qu'une fois ce signal bougé (nil : règle d'avant)
  }, cex
end

---------------------------------------------------------------------------------------------------
-- Exécution des ordres
---------------------------------------------------------------------------------------------------
local function note(f, cs, tick, text)
  log(string.format("[FO-CAPI] %s : %s a %.1f min", f.key or "?", text, minutes(f, tick)))
end

--- Débit d'un ordre découpé en modules d'au plus A.FIRST_RATE_MAX objets/min (au plus Capi.MODULES_PER_ORDER).
--- Lot CAPI-REPLI : `factor` (1, 1/2, 1/4 ; Rp.factor) réduit la taille du module après un échec de matériaux.
function Capi.split(rate, factor, max_k)
  local cap = A.FIRST_RATE_MAX * (factor or 1)
  -- Lot COUVERTURE : un ordre de SATURATION peut avoir plusieurs modules (max_k, Cv.sat_modules) ; les autres, Capi.MODULES_PER_ORDER.
  local k = math.max(1, math.min(max_k or Capi.MODULES_PER_ORDER, math.ceil((rate or 0) / cap - 1e-9)))
  local each = math.min(cap, (rate or 0) / k)
  local out = {}
  for i = 1, k do out[i] = each end
  return out
end

--- Lot CHAMP (demande du lead, 2/11) : un ordre « couvrir » ou « ouvrir » à foreuses électriques d'un minerai que le CHAMP sait poser (minerai
--- à fondre, script/team/migration_champ.lua Mig.takes) va au champ (bandes en rangées hors du treillis), plus à une fonderie à foreuses du
--- treillis : la ligne électrique de cette fonderie occupait le gisement et le champ n'y posait plus de bande (mesuré, partie de 150 min,
--- graine 20261020 : emerald, « gisement occupe (hors paires) : electric-mining-drill 18, reserve 127 », aucune bande sur ce gisement).
local function to_champ(f, cs, o)
  if o.kind ~= "couvrir" and o.kind ~= "ouvrir" then return false end
  local dm = Capi.data().drill_by[o.entity]
  return dm ~= nil and dm.energy == "electric" and MigChamp.takes(f, o.resource) ~= nil
end

--- Envoie un ordre de la règle à son exécutant. Rend l'enregistrement de l'ordre ouvert, ou nil et la raison.
local function execute(f, cs, o, view, book, tick, research)
  local rec = { key = o.key, kind = o.kind, item = o.item, resource = o.resource, deposit = o.deposit, entity = o.entity,
    n = o.n, n_left = o.n, rate = o.rate, where = o.where, smelt_n = o.smelt_n, smelt_left = o.smelt_n,
    smelt_recipe = o.smelt_recipe, smelt_entity = o.smelt_entity, value = o.value, T = o.T, opened = tick,
    progress_tick = tick, missing = {}, why = o.why }
  local D = Capi.data()
  if to_champ(f, cs, o) then
    -- le champ du gisement : une bande de plus (la suivante de son cadre), demandée au plan directeur par la migration ; l'ordre est fini
    -- quand une bande de ce champ produit (Mig.follow), ses manques sont les buts de la bande (script/ai3/automatisation.lua)
    local dep = cs.deps[o.deposit]
    if not dep then return nil, "champ : gisement non recense" end
    -- plan directeur et centrale d'abord, comme avant le premier module électrique (Auto.submit) : le champ attend un réseau qui produit
    Auto.ensure_power(f, tick, A.choose_pole(book, view.stock or {}, Harvest.reachable(f)))
    local fid, produced = MigChamp.want(f, dep, tick)
    if not fid then return nil, "champ : " .. tostring(produced) end
    rec.exec, rec.field, rec.produced0, rec.missing = "champ", fid, produced or 0, {}
    return rec
  end
  if o.kind == "couvrir" or o.kind == "ouvrir" then
    local dm = D.drill_by[o.entity]
    if dm and dm.energy == "electric" then
      local meth = METHOD_OF_ORE[o.resource]
      if not meth then return nil, "aucune fonderie a foreuses pour ce minerai" end
      local dep = cs.deps[o.deposit]
      local per_ore = 1
      local rn = o.smelt_recipe or (dep and nil)
      local r = rn and D.recipes[rn]
      if r then
        local pin, pout = 0, 0
        for _, i in ipairs(r.ingredients) do if i.name == o.resource then pin = i.amount end end
        for _, p in ipairs(r.products) do if p.name == meth.product then pout = p.amount end end
        if pin > 0 then per_ore = pout / pin end
      end
      local rate = (o.rate or 0) * per_ore
      -- Pas de « near » : le plan directeur pose la fonderie au plus près de SON gisement de lots (comme AUTO, fonderies
      -- validées en 0.6.3) ; banc p2 du lot : avec la fonderie posée au centre du gisement, 174 refus « tapis des
      -- foreuses (minerai) » et 124 « (trop loin) ».
      local near = nil
      local ids, why = {}, nil
      local rkey = Rp.key(meth.product, o.deposit)
      local repli = repli_book(cs)
      local shrunk = Rp.factor(repli, rkey, tick) < 1 -- lot INTEG-ECONOMIE (D2) : module réduit après un échec de matériaux
      -- Lot COUVERTURE : modules d'un ordre de saturation = ce que le débit demande, borné par les bras libres et le plafond de sûreté (Cv.sat_modules)
      local sat_k, sat_want, sat_gap = nil, nil, nil
      if o.saturation then
        sat_want = math.max(1, math.ceil(rate / (A.FIRST_RATE_MAX * Rp.factor(repli, rkey, tick)) - 1e-9))
        sat_k, sat_gap = Cv.sat_modules(sat_want, cs.slots and cs.slots.hands or 0, Dm.HANDS_PER_SITE, Dm.SLOTS_HARD)
      end
      for _, part in ipairs(Capi.split(rate, Rp.factor(repli, rkey, tick), sat_k)) do
        local g, args = fit_module(meth, part, book, view.stock or {}, Auto.plant_state(f) ~= nil, Harvest.reachable(f), Auto.belt_flow(f))
        if not g then why = "objets impossibles : " .. table.concat(args or {}, ",") break end
        local id, w2 = Auto.submit(f, { product = meth.product, gen = meth.gen, args = args, feed = meth.feed, rate = part,
          shrunk = shrunk or nil,
          rate_nom = (g.nominal[meth.product] or 0) * 60, electric = (g.power_kw or 0) > 0, gain = 1, near = near, pole = g.pole, arms = g.arms,
          capi = o.key, why = string.format("CAPI %s %s x%d T=%.2f", o.kind, tostring(o.deposit), o.n or 0, o.T or 0) },
          tick, research)
        if not id then
          why = "plan directeur : " .. tostring(w2)
          Rp.fail(repli, rkey, w2, tick, nil) -- lot CAPI-REPLI : repli de CE gisement seulement
          break
        end
        ids[#ids + 1] = id
        -- portée du plan directeur : le treillis grandit jusqu'au gisement (au plus Build.RADIUS_ORE, lot INDUSTRIE I3)
        if f.build and dep then
          local far = math.max(math.abs(dep.cx - f.hq_pos.x), math.abs(dep.cy - f.hq_pos.y))
          Build.grow(f, Tr.grow_target(far, Pl.PITCH, Build.RADIUS_ORE), Build.RADIUS_ORE)
        end
      end
      if #ids == 0 then return nil, why end
      rec.exec, rec.mod_ids, rec.product = "module", ids, meth.product
      if sat_want then
        local gap = sat_gap or (#ids < sat_want and (why or "plan directeur") or nil)
        log(string.format("[FO-SATURATION] %s minute %d : ordre %s : %d module(s) voulu(s), %d obtenu(s)%s", f.key or "?", math.floor(minutes(f, tick)),
          tostring(o.key), sat_want, #ids, gap and (" (cause de l'ecart : " .. tostring(gap) .. ")") or ""))
      end
      if Rp.factor(repli, rkey, tick) < 1 then
        note(f, cs, tick, string.format("ordre %s : module reduit a %d %% apres un echec de materiaux (%s)", o.key,
          math.floor(100 * Rp.factor(repli, rkey, tick) + 0.5), rkey))
      end
      return rec
    end
    return nil, "foreuses a combustion : decideur d'avant (SCALE)"
  elseif o.kind == "fours" then
    return nil, "fours du QG : decideur SCALE (Br.smelters)"
  elseif o.kind == "equiper" then
    -- Lot LEVIERS : machines DÉJÀ posées (relevé de cette minute) du groupe décidé : même machine, même recette ou
    -- ressource, même endroit, mêmes modules déjà posés ; au plus o.n machines, les premières par numéro d'unité.
    local list = o.resource and (cs.scan and cs.scan.drills or {}) or (cs.scan and cs.scan.machines or {})
    local targets = {}
    for _, g in ipairs(list) do
      local same = g.entity == o.entity and g.sig == o.sig
      if same and o.resource then same = g.resource == o.resource and tostring(g.deposit) == tostring(o.deposit) end
      if same and not o.resource then same = g.recipe == o.recipe and tostring(g.where) == tostring(o.where) end
      if same then
        for _, u in ipairs(g.units or {}) do
          if #targets < (o.n or 0) then targets[#targets + 1] = { x = u.x, y = u.y, u = u.u, entity = g.entity } end
        end
      end
    end
    if #targets == 0 then return nil, "aucune machine du groupe au releve (releve perime)" end
    table.sort(targets, function(a, b) return a.u < b.u end)
    rec.exec, rec.module, rec.per, rec.targets, rec.done, rec.inserted = "equiper", o.module, o.per, targets, {}, 0
    rec.n, rec.n_left = #targets, #targets
    rec.missing = { { o.module, #targets * o.per } }
    rec.d_item, rec.d_out, rec.d_in, rec.d_kw, rec.d_fuel, rec.sig = o.d_item, o.d_out, o.d_in, o.d_kw, o.d_fuel, o.sig
    -- sortie annoncée pour les machines réellement ciblées (le plan applique n_left ÷ n de l'ordre décidé)
    if (o.n or 0) > #targets and o.n > 0 then
      local k = #targets / o.n
      rec.d_out, rec.d_kw, rec.d_fuel = (o.d_out or 0) * k, (o.d_kw or 0) * k, (o.d_fuel or 0) * k
      rec.d_in = {}
      for _, e in ipairs(o.d_in or {}) do rec.d_in[#rec.d_in + 1] = { e[1], e[2] * k } end
    end
    rec.announced = { d_out = rec.d_out, item = o.d_item, factor = o.factor }
    return rec
  elseif o.kind == "techno" then
    rec.exec, rec.tech, rec.n, rec.n_left = "techno", o.tech, 1, 1
    return rec
  elseif o.kind == "labos" then
    rec.exec = "labos"
    rec.target = (cs.nlabs or 0) + (o.n or 0)
    return rec
  elseif o.kind == "chaine" or o.kind == "packs" then
    local vstock = view.stock or {}
    local meth, why = A.method_for(o.item, book, function(n) return book:handcraftable(n) or (vstock[n] or 0) > 0 end)
    if not meth then return nil, tostring(why) end
    local ids, why2 = {}, nil
    local rkey = Rp.key(o.item, nil)
    local repli = repli_book(cs)
    -- Lot RANGEES-ASM : une chaîne agrandit la rangée en attente de la même recette, ou pose une rangée dimensionnée sur la
    -- demande (5 machines au moins quand elle le justifie), près des autres (script/ai3/rangees_asm.lua) ; false : ancien chemin
    if o.kind == "chaine" then
      -- lot MALL (tranche 2, docs/MALL.md §3) : l'état S vrai, l'objet va dans une rangée du mall (une section de plus) au lieu d'un module isolé ; refus : le chemin d'avant, cause écrite
      local mid = Capi.MallRt.chaine(f, o, book, vstock, tick, A.choose_pole(book, vstock, Harvest.reachable(f)))
      if mid then
        rec.exec, rec.product = "mall", o.item
        if mid ~= true then rec.mall_id = mid end
        return rec
      end
      local rids, rwhy = Capi.RaRt.execute(f, o, meth,
        function(m2, rate) return fit_module(m2, rate, book, view.stock or {}, Auto.plant_state(f) ~= nil, Harvest.reachable(f), Auto.belt_flow(f)) end,
        function(m2, g, args, near, dyn)
          local id, w2 = Auto.submit(f, { product = o.item, gen = m2.gen, args = args, feed = m2.feed, rate = o.rate or 0,
            rate_nom = (g.nominal[o.item] or 0) * 60, electric = (g.power_kw or 0) > 0, gain = 1, capi = o.key, pole = g.pole, arms = g.arms,
            near = near, rangee = dyn or nil, why = string.format("CAPI %s x%d T=%.2f (rangee)", o.kind, o.n or 0, o.T or 0) }, tick, research)
          if not id then Rp.fail(repli, rkey, w2, tick, nil) return nil, "plan directeur : " .. tostring(w2) end
          return { id }
        end, Rp.factor(repli, rkey, tick), tick)
      if rids ~= false then
        if not rids then return nil, rwhy end
        rec.exec, rec.mod_ids, rec.product = "module", rids, o.item
        return rec
      end
    end
    for _, part in ipairs(Capi.split(o.rate or 0, Rp.factor(repli, rkey, tick))) do
      local g, args = fit_module(meth, part, book, view.stock or {}, Auto.plant_state(f) ~= nil, Harvest.reachable(f), Auto.belt_flow(f))
      if not g then why2 = "objets impossibles : " .. table.concat(args or {}, ",") break end
      local id, w2 = Auto.submit(f, { product = o.item, gen = meth.gen, args = args, feed = meth.feed, rate = part,
        rate_nom = (g.nominal[o.item] or 0) * 60, electric = (g.power_kw or 0) > 0, gain = 1, capi = o.key, pole = g.pole, arms = g.arms,
        why = string.format("CAPI %s x%d T=%.2f", o.kind, o.n or 0, o.T or 0) }, tick, research)
      if not id then
        why2 = "plan directeur : " .. tostring(w2)
        Rp.fail(repli, rkey, w2, tick, nil)
        break
      end
      ids[#ids + 1] = id
    end
    if #ids == 0 then return nil, why2 end
    rec.exec, rec.mod_ids, rec.product = "module", ids, o.item
    return rec
  end
  return nil, "levier sans executant (" .. tostring(o.kind) .. ")"
end

--- Suivi d'un ordre ouvert : manques, reste à poser, fin. Rend "ouvert", "fini" ou "echec", raison.
local function follow(f, cs, rec, tick)
  if rec.exec == "module" then
    -- plusieurs modules par ordre : fini quand tous sont finis ou refusés (au moins un fini) ; échec si tous refusés
    local missing, n_fini, n_ref, built, total, why = {}, 0, 0, 0, 0, nil
    local blocked = nil
    local lost = {} -- lot CAPI-REPLI : objets qui manquaient au module refusé (derniers manques connus de l'exécutant)
    local states = {} -- lot CAPI-DEBIT (relecture) : entrée en chantier (Em.work_tick), lue par Capi.slots
    for _, id in ipairs(rec.mod_ids or { rec.module }) do
      local m = Auto.module(f, id)
      states[#states + 1] = m and tostring(m.state) or "perdu"
      if not m or m.state == "refuse" then
        n_ref = n_ref + 1
        why = m and tostring(m.reason) or "module perdu"
        for _, it in ipairs(m and m.missing or {}) do lost[#lost + 1] = it end
      elseif m.state == "fini" then n_fini = n_fini + 1
      else
        if m.state == "reserve" then for _, it in ipairs(m.missing or {}) do missing[#missing + 1] = it end end
        if m.state == "bloque" then blocked = tostring(m.reason) end
        -- lot FUITES-PILE : réserve suspendue par la pile : ce n'est pas un ordre sans progrès (Capi.ORDER_TTL)
        if m.reason == "pile" then rec.progress_tick = tick end
      end
      if m then built, total = built + (m.built or 0), total + (m.total or 0) end
    end
    local n_mod = #(rec.mod_ids or { rec.module })
    rec.missing, rec.blocked = missing, blocked
    rec.work_tick = Em.work_tick(rec.work_tick, states, tick)
    if n_fini + n_ref >= n_mod then
      if n_fini > 0 then return "fini" end
      rec.lost = lost
      return "echec", "plan directeur : " .. tostring(why)
    end
    if built ~= rec.built then rec.built, rec.progress_tick = built, tick end
    if total > 0 then rec.n_left = math.max(0, math.ceil((rec.n or 0) * (total - built) / total)) end
    return "ouvert"
  elseif rec.exec == "equiper" then
    -- Lot LEVIERS : fini quand chaque machine ciblée a été traitée par un PNJ (module posé, ou refus du moteur écrit).
    local done = {}
    for _, u in ipairs(rec.done or {}) do done[u] = true end
    local left, first = 0, nil
    for _, t in ipairs(rec.targets or {}) do
      if not done[t.u] then
        left = left + 1
        first = first or t
      end
    end
    if #(rec.done or {}) ~= rec.ndone then rec.ndone, rec.progress_tick = #(rec.done or {}), tick end
    rec.n_left = left
    local have = Stock.count(f, rec.module)
    rec.missing = {}
    if left > 0 and have < left * rec.per then rec.missing = { { rec.module, left * rec.per - have } } end
    if left == 0 then
      if (rec.inserted or 0) > 0 then return "fini" end
      return "echec", "aucun module pose (" .. tostring(rec.why_refused) .. ")"
    end
    return "ouvert"
  elseif rec.exec == "champ" then
    -- Lot CHAMP : fini quand une bande de plus du champ produit ; échec si le champ est perdu, posé en entier ou abandonné ; progrès à
    -- chaque changement d'étape, d'état du projet ou d'entité posée
    local s = MigChamp.follow(f, rec.field, tick)
    if not s then return "echec", "champ : cible perdue" end
    if s.produced > (rec.produced0 or 0) then
      rec.n_left = 0
      return "fini"
    end
    if s.migr == "fini" then return "echec", "champ : pose en entier" end
    if s.abandoned then return "echec", "champ : abandonne" end
    local tag = table.concat({ tostring(s.stage), tostring(s.pid), tostring(s.pstate), tostring(s.reason), tostring(s.built) }, ":")
    if tag ~= rec.tag then rec.tag, rec.progress_tick = tag, tick end
    -- seconde relecture (point 1) : le progrès RÉEL (posées en hausse), seul lu par le siège du complément (Em.champ_holds)
    rec.adv_tick, rec.built_hi = Em.champ_advance(rec.adv_tick, rec.built_hi, s.built, tick)
    rec.missing = {}
    -- lot COURANT-LIBRE : reste à poser en foreuses (Ca.champ_left) et projet de la bande (Capi.power_input ne le compte pas en plus)
    rec.n_left = Capi.MUT.champ_plein and rec.n or Ca.champ_left(rec.n, s.drills, s.drills_built) -- (mutant : l'ancien reste, tout l'ordre)
    rec.pid = s.pid
    return "ouvert"
  elseif rec.exec == "techno" then
    -- Lot LEVIERS : fini quand la technologie est faite ; progrès tant que le laboratoire la cherche ou qu'elle attend sa file.
    local st = f.team.ia3
    if (st.techs or {})[rec.tech] then return "fini" end
    if st.lab and st.lab.tech == rec.tech then rec.progress_tick = tick end
    return "ouvert"
  elseif rec.exec == "outpost" then
    if rec.outpost then
      local o = f.outposts[rec.outpost]
      if not o then return "echec", "avant-poste perdu" end
      rec.n_left = math.max(0, (rec.target or 0) - o.drills)
      if o.drills ~= rec.built then rec.built, rec.progress_tick = o.drills, tick end
      if o.drills >= (rec.target or 0) then return "fini" end
      if o.full_place then return "echec", "avant-poste plein (place)" end
      return "ouvert"
    end
    local n = 0
    for _, oid in ipairs(sorted_keys(f.outposts)) do if f.outposts[oid].kind == rec.outpost_kind then n = n + 1 end end
    if n >= (rec.target_count or 0) then return "fini" end
    return "ouvert"
  elseif rec.exec == "smelters" then
    local n = #(f.smelters or {})
    if n ~= rec.built then rec.built, rec.progress_tick = n, tick end
    rec.n_left = math.max(0, (rec.target or 0) - n)
    if n >= (rec.target or 0) then return "fini" end
    return "ouvert"
  elseif rec.exec == "labos" then
    local n = cs.nlabs or 0
    if n ~= rec.built then rec.built, rec.progress_tick = n, tick end
    rec.n_left = math.max(0, (rec.target or 0) - n)
    if n >= (rec.target or 0) then return "fini" end
    return "ouvert"
  end
  if rec.exec == "mall" then -- lot MALL : la section de rangée demandée (aucune : l'objet était déjà servi)
    local p = rec.mall_id and f.build and f.build.projects[rec.mall_id]
    if not rec.mall_id or (p and p.state == "fini") then return "fini" end
    if not p or p.state == "refuse" then return "echec", p and tostring(p.reason) or "section du mall perdue" end
    return "ouvert"
  end
  return "echec", "executant inconnu"
end
Capi.follow_one = follow -- tests seulement (tests/courant_libre_test.lua)

---------------------------------------------------------------------------------------------------
-- Lot CAPI-MESURE : couverture par gisement et capacité posée contre capacité MESURÉE
---------------------------------------------------------------------------------------------------
Capi.ZERO_ALERT = 2 -- relevés de suite (5 min chacun) à 0/min avant l'alerte d'une capacité posée
Capi.ZERO_REMIND = 6 -- puis un rappel tous les 6 relevés (30 min)

--- Alerte « capacité posée, 0/min mesuré » : écrite au deuxième relevé nul de suite, puis en rappel ; la reprise est écrite.
local function zero_watch(f, cs, label, placed, rate, tick, detail)
  cs.zero = cs.zero or {}
  if placed > 0 and rate ~= nil and rate <= 0 then
    local n = (cs.zero[label] or 0) + 1
    cs.zero[label] = n
    if n == Capi.ZERO_ALERT or (n > Capi.ZERO_ALERT and (n - Capi.ZERO_ALERT) % Capi.ZERO_REMIND == 0) then
      log(string.format("[FO-CAPI-ALERTE] %s : capacite posee qui produit 0/min depuis %d min : %s (%s) a %.1f min", f.key or "?",
        n * Capi.COUV_EVERY / 3600, label, detail, minutes(f, tick)))
    end
  elseif rate ~= nil then
    if (cs.zero[label] or 0) >= Capi.ZERO_ALERT then
      log(string.format("[FO-CAPI-ALERTE] %s : %s produit de nouveau (%.1f/min mesures) a %.1f min", f.key or "?", label, rate, minutes(f, tick)))
    end
    cs.zero[label] = nil
  end
end

--- Une ligne [FO-CAPI-COUV] par gisement suivi toutes les Capi.COUV_EVERY : couverture, places libres, raison de
--- `drill_for = ""`, repli en cours, refus de la règle, ordre ouvert ; une ligne par minerai : foreuses posées, débit théorique
--- et débit MESURÉ (compteurs de production de la force sur la fenêtre). Aucune décision modifiée.
local function couv_report(f, cs, res, input, D, tick)
  if cs.couv_next and tick < cs.couv_next then return end
  cs.couv_next = tick + Capi.COUV_EVERY
  local who, mn = f.key or "?", math.floor(minutes(f, tick) + 0.5)
  local repli = repli_book(cs)
  local cov = {}
  for _, c in ipairs(res.coverage or {}) do cov[tostring(c.id)] = c end
  local refus = {}
  for _, r in ipairs(res.refus or {}) do refus[tostring(r.key)] = tostring(r.why) end
  -- foreuses posées par gisement et par minerai (relevé de la minute), débit théorique
  local per_dep, per_res = {}, {}
  for _, g in ipairs(cs.scan and cs.scan.drills or {}) do
    per_dep[g.deposit] = (per_dep[g.deposit] or 0) + (g.n or 0)
    local r = per_res[g.resource] or { n = 0, rate = 0 }
    r.n = r.n + (g.n or 0)
    local dm = D.drill_by[g.entity]
    if dm and D.res[g.resource] then r.rate = r.rate + (g.n or 0) * Ca.drill_per_min(D, dm, g.resource) end
    per_res[g.resource] = r
  end
  local by_recipe = {}
  for _, m in ipairs(cs.scan and cs.scan.machines or {}) do
    local r = m.recipe and D.recipes[m.recipe]
    local out = r and r.products and r.products[1]
    if out and out.name then
      local e = by_recipe[m.recipe] or { n = 0, product = out.name }
      e.n = e.n + (m.n or 1)
      by_recipe[m.recipe] = e
    end
  end
  -- fenêtre de mesure : compteurs absolus de la force (cs.prod, relevé par flows_of à chaque décision)
  local cur, snap = cs.prod or {}, cs.couv_snap
  local dt = snap and (tick - snap.tick) / 3600 or nil
  local function measured(item)
    if not (snap and dt and dt > 0.5) or snap.v[item] == nil then return nil end
    return math.max(0, ((cur[item] or 0) - snap.v[item]) / dt)
  end
  local wanted_items = {}
  for _, rn in ipairs(sorted_keys(per_res)) do wanted_items[rn] = true end
  for _, rn in ipairs(sorted_keys(by_recipe)) do wanted_items[by_recipe[rn].product] = true end
  for _, id in ipairs(sorted_keys(cs.deps)) do
    local d = cs.deps[id]
    local c = cov[tostring(id)]
    local n_open = {}
    for _, rec in ipairs(cs.open) do
      if tostring(rec.deposit) == tostring(id) then n_open[#n_open + 1] = rec.key .. "(" .. tostring(rec.exec) .. ")" end
    end
    local meth = METHOD_OF_ORE[d.resource]
    local rk = meth and Rp.key(meth.product, id) or nil
    local df = input.drill_for[d.resource]
    local why_dep = refus["couvrir:" .. id] or refus["ouvrir:" .. id]
    log(string.format("[FO-CAPI-COUV] %s minute %d | gisement %s %s | couverture %d/%d (%d pour mille) | places libres %s | foreuses posees %d | %s%s | foreuse %s | repli %s | refus %s | ordres %s",
      who, mn, tostring(id), tostring(d.resource), d.covered or 0, d.tiles or 0,
      (d.tiles or 0) > 0 and math.floor(1000 * (d.covered or 0) / d.tiles) or 0, c and tostring(c.free) or "?", per_dep[id] or 0,
      (c and c.open or (per_dep[id] or 0) > 0) and "ouvert" or "connu", d.danger and ", danger" or "",
      (df == nil or df == "") and ("\"\" (" .. tostring(cs.drill_why and cs.drill_why[d.resource] or "?") .. ")") or tostring(df),
      rk and Rp.describe(repli, rk, tick, repli_opts(f, d, meth.product)) or "-", why_dep or "-",
      #n_open > 0 and table.concat(n_open, ",") or "-"))
  end
  for _, rn in ipairs(sorted_keys(per_res)) do
    local r = per_res[rn]
    local got = measured(rn)
    log(string.format("[FO-CAPI-COUV] %s minute %d | minerai %s | foreuses posees %d, %.1f/min theoriques | extrait mesure %s/min",
      who, mn, rn, r.n, r.rate, got and string.format("%.1f", got) or "?"))
    zero_watch(f, cs, "foreuses " .. rn, r.n, got, tick, string.format("%d foreuse(s), %.1f/min theoriques", r.n, r.rate))
  end
  for _, rc in ipairs(sorted_keys(by_recipe)) do
    local e = by_recipe[rc]
    local got = measured(e.product)
    zero_watch(f, cs, "machines " .. rc, e.n, got, tick, string.format("%d machine(s) de la recette, produit %s", e.n, e.product))
  end
  local v = {}
  for _, it in ipairs(sorted_keys(wanted_items)) do v[it] = cur[it] or 0 end
  cs.couv_snap = { tick = tick, v = v }
end

---------------------------------------------------------------------------------------------------
-- Étape 10 : décision
---------------------------------------------------------------------------------------------------
--- Lot FUITES-PILE (fuite a) : un ordre NEUF de la capitalisation est une amélioration (R3) ; pendant qu'un cadre réparer, protéger ou
--- survivre retient (shared/ai3/pile.lua), il n'est envoyé à aucun exécutant, sauf s'il produit une matière d'un cadre ouvert ou qui
--- manque (investissement de production, comme g.invest de la pensée). Objets produits : l'objet de l'ordre, son minerai et les
--- produits de sa recette de fonte. Rend (permis, raison).
local function pile_ok(f, o)
  local items = {}
  if o.item then items[#items + 1] = o.item end
  if o.resource and o.resource ~= o.item then items[#items + 1] = o.resource end
  local r = o.smelt_recipe and Capi.data().recipes[o.smelt_recipe]
  for _, pr in ipairs(r and r.products or {}) do items[#items + 1] = pr.name end
  return PileRt.porte_any(f, Pi.order_family(o.kind), items)
end

--- Suite de la décision (dernière tranche) : puits, journaux, ordres envoyés aux exécutants. `input` : l'entrée de la règle (refaite depuis
--- l'instantané d'une décision découpée).
--- Lot VIDEO-SIEGES (C5, règle 10 de shared/ai3/emplacements.lua) : l'ordre dans lequel les ordres « module » de la décision prennent leur
--- siège, et ceux qui n'ouvrent pas. Les ordres qui DÉBLOQUENT un manque des ordres ouverts (Ca.blocked_items, Ca.unblocks) d'abord, puis le
--- moins couvert (θ = (débit mesuré + stock ÷ H_STOCK) ÷ besoin) ; une chaîne dont le manque d'ouverture (ce que ses machines ont en trop
--- peu au coffre) recoupe à plus de Em.OVERLAP_MAX % celui d'une chaîne ouverte, ou d'une chaîne qui a déjà son siège, n'ouvre pas.
--- Rend la liste des ordres (seules les places des ordres « module » changent) et { [clé] = raison } ; nil, nil : réglage éteint.
Capi.ARBITRE = true

function Capi.arbitre(f, cs, res, input, view, tick)
  if not Capi.ARBITRE then return res.orders, nil end
  local stock = view.stock or {}
  local flows, R = input.flows or {}, res.R or {}
  local blocked = Ca.blocked_items({ open = cs.open, D = input.data })
  local cands, by_key = {}, {}
  for _, o in ipairs(res.orders) do
    if Capi.MODULE_KINDS[o.kind] then
      local miss = {}
      for _, it in ipairs(o.items or {}) do
        if (stock[it[1]] or 0) < (it[2] or 0) then miss[it[1]] = true end
      end
      local item = o.item or o.resource
      local theta = nil
      if item ~= nil and (R[item] or 0) > 0 then
        theta = (((flows[item] or {}).made or 0) + (stock[item] or 0) / Ca.H_STOCK) / R[item]
      end
      cands[#cands + 1] = { key = o.key, kind = o.kind, miss = miss, unblocks = Ca.unblocks(o, blocked), theta = theta }
      by_key[o.key] = o
    end
  end
  if #cands == 0 then return res.orders, nil end
  local open = {}
  for _, rec in ipairs(cs.open or {}) do
    if rec.exec == "module" and rec.kind == "chaine" then
      local miss = {}
      for _, m in ipairs(rec.missing or {}) do if m[1] ~= nil and (m[2] or 0) > 0 then miss[m[1]] = true end end
      open[#open + 1] = { key = rec.key, miss = miss }
    end
  end
  local _, refused, sorted = Em.arbitrate(cands, open)
  local out, j, moved = {}, 0, false
  for i, o in ipairs(res.orders) do
    if Capi.MODULE_KINDS[o.kind] then
      j = j + 1
      out[i] = by_key[sorted[j].key]
      if out[i] ~= o then moved = true end
    else
      out[i] = o
    end
  end
  if moved or next(refused) ~= nil then
    local seq, rf = {}, {}
    for _, o in ipairs(out) do if Capi.MODULE_KINDS[o.kind] then seq[#seq + 1] = o.key end end
    for _, k in ipairs(sorted_keys(refused)) do rf[#rf + 1] = k .. " (" .. refused[k] .. ")" end
    log(string.format("[FO-CAPI-SIEGES] %s minute %d : sieges dans l'ordre [%s] ; sans siege [%s]", f.key or "?",
      math.floor(minutes(f, tick) + 0.5), table.concat(seq, ", "), table.concat(rf, ", ")))
  end
  return out, refused
end

local function decide_finish(f, cs, res, input, view, book, tick, research)
  local D = Capi.data()
  -- Lot C2 : le PUITS OUVERT. f.team.ia3.puits (débit de chaque matière, puits compris) est lu par la saturation du cerveau, la décision de
  -- l'automatisation et les capacités ; cs.blocked_slots (ordres retenus faute de place) règle les emplacements de chantier.
  do
    local dm = res.demande
    cs.blocked_slots = Dm.blocked_next(cs.blocked_slots, Dm.count_blocked(res.refus))
    if dm and dm.p > 0 then
      local flow = {}
      for _, k in ipairs(sorted_keys(res.R or {})) do
        if (res.R[k] or 0) > 0 then flow[k] = res.R[k] end
      end
      f.team.ia3.puits = { flow = flow, p = dm.p }
    else
      f.team.ia3.puits = nil
    end
    local last = cs.dm_last or { dormant = false, p = 0 }
    local p = dm and dm.p or 0
    -- lot BLOCAGE-SORTIE-2 : puits fermé = une cause DISTINCTE (Dm.closed_cause), journalisée aussi quand elle change
    local ckey, ctext
    if not dm then
      ckey, ctext = Dm.closed_cause({ on = Rsv.on(), off = cs.demande_off, threat = input.threat, threat_why = input.threat_why,
        reserve = input.reserve ~= nil, palier_why = input.palier_why })
      if ckey == "palier" then ckey = ckey .. ":" .. tostring(input.palier_why or ""):sub(1, 40) end
    end
    if (dm and dm.dormant or false) ~= last.dormant or math.abs(p - last.p) > 0.25 * math.max(last.p, 1) or ckey ~= cs.dm_ckey then
      cs.dm_last = { dormant = dm and dm.dormant or false, p = p }
      cs.dm_ckey = ckey
      log(string.format("[FO-DEMANDE] %s : %s ; retour accepte au moins %.0f min (le stock dormirait autant, cout d'opportunite nul ; plafond %d) ; %d ordre(s) a %.1f min",
        f.key or "?", dm and dm.cause or ctext,
        math.min(dm and dm.tmax_sleep or 0, Dm.TMAX_CAP), Dm.TMAX_CAP, #res.orders, minutes(f, tick)))
    end
  end
  -- Lot LEVIERS : les modules rentables mais pas encore fabricables sont DEMANDÉS à la recherche (comme une chaîne refusée).
  cs.wanted_set = cs.wanted_set or {}
  for _, nm in ipairs(res.want or {}) do cs.wanted_set[nm] = true end
  cs.wanted = sorted_keys(cs.wanted_set or {})
  cs.wanted_set = nil
  -- Lot LEVIERS : « repli : pourquoi » (ressources bloquées, leviers retenus ou raison de n'en avoir aucun). Écrit quand la
  -- SITUATION change (ressources bloquées, leviers), jamais à l'horloge.
  if res.repli then
    local rs, ls = {}, {}
    for _, b in ipairs(res.repli.blocked) do rs[#rs + 1] = b.resource end
    for _, l in ipairs(res.repli.levers) do ls[#ls + 1] = l.key end
    local sig = table.concat(rs, ",") .. "|" .. table.concat(ls, ",") .. "|" .. tostring(res.repli.none)
    if cs.repli_sig ~= sig then
      cs.repli_sig = sig
      log(string.format("[FO-CERVEAU] %s : %s a %.1f min", f.key or "?", res.repli.text, minutes(f, tick)))
      for _, l in ipairs(res.repli.levers) do
        log(string.format("[FO-CERVEAU] %s : repli : levier %s : %s", f.key or "?", l.key, tostring(l.why)))
      end
      cs.repli_refus = cs.repli_refus or {}
      for _, r in ipairs(res.repli.refus) do
        -- chaque refus n'est écrit qu'une fois par raison (le même refus se répète à chaque changement de situation)
        local sig2 = r.key .. "|" .. tostring(r.why)
        if not cs.repli_refus[sig2] then
          cs.repli_refus[sig2] = true
          log(string.format("[FO-CERVEAU] %s : repli : levier refuse %s : %s", f.key or "?", r.key, tostring(r.why)))
        end
      end
    end
    cs.repli_text = res.repli.text
  else
    cs.repli_sig, cs.repli_text = nil, nil
  end
  -- Lot LEVIERS : recherches retenues parce qu'elles débloquent une meilleure machine (écrit quand l'ensemble change).
  do
    local names = {}
    for _, u in ipairs(res.unlocks or {}) do names[#names + 1] = u.tech end
    local sig3 = table.concat(names, ",")
    if sig3 ~= (cs.unlock_sig or "") then
      cs.unlock_sig = sig3
      for _, u in ipairs(res.unlocks or {}) do
        log(string.format("[FO-CERVEAU] %s : %s a %.1f min", f.key or "?", u.why, minutes(f, tick)))
      end
    end
    cs.unlocks = names
    -- technologies de la chaîne (la technologie et ses prérequis non faits) : valeur d'un objet voulu SANS le quart des
    -- machines « pour plus tard » (Gen.LATER_DIV) : la machine supérieure est posée sur place par le lot AMELIORER
    cs.unlock_techs = {}
    for _, u in ipairs(res.unlocks or {}) do
      for _, t in ipairs(u.chain or {}) do cs.unlock_techs[t] = u.tech end
    end
  end
  -- Les objets que ses exécutants attendent sont DONNÉS à la recherche (étape 1 du 27/10 au soir : sans cela, scarlet cherchait
  -- grenades et armure pendant 30 min pendant que les chaînes de la capitalisation étaient refusées « recherche :
  -- fast-inserter, medium-electric-pole » ; le critère « automation à 2 min comme au témoin » interdisait toute électrification).
  -- La garde K1 ne retient plus que les recherches voulues LOINTAINES (Gen.k1, near).
  Auto.want(f, cs.wanted)
  cs.decisions = cs.decisions + 1
  cs.res = { delta = res.delta, alpha = res.alpha, s = res.s, K = res.K, Y = res.Y, budget = res.budget, spent = res.spent,
    labs_target = res.labs_target, u_star = res.u_star, free = input.reserve and input.reserve.free or nil,
    zero = input.reserve and input.reserve.zero or nil,
    puits = res.demande and { p = res.demande.p, dormant = res.demande.dormant, left0 = res.demande.left0, cap = res.demande.cap } or nil,
    -- lot BLOCAGE-SORTIE-2 (lecture seule, bancs) : pourquoi le puits est fermé (menace, puits éteint, besoin évalué ou non)
    threat = input.threat and true or false, demande_in = input.demande and true or false, reserve_in = input.reserve ~= nil }
  -- Lots VIDEO-L5 et VIDEO-L13 : refus de la règle par la suspension (« confirmation : ») ou par le plafond d'un objet, au journal.
  for _, r in ipairs(res.refus or {}) do
    local why = tostring(r.why)
    if why:sub(1, 15) == "confirmation : " or why:sub(1, 8) == "plafond " then
      log(string.format("[FO-CAPI-CONF] %s : refus %s : %s a %.1f min", f.key or "?", tostring(r.key), why, minutes(f, tick)))
    end
  end
  Excl.journal(f, input, res, tick, minutes(f, tick)) -- lot VIDEO-PLAFONDS (V99) : refus d'exclusion et puits retirés, [FO-EXCLU]
  -- Lot TV-ENERGIE (W02) : refus du courant EN AMONT (relevé fermé, amorce prise, capacité non lue) : une ligne par CAUSE, quand l'ensemble
  -- des causes change (jamais à l'horloge), sous le plafond Capi.COURANT_LOGS par équipe.
  do
    local seen, causes = {}, {}
    for _, r in ipairs(res.refus or {}) do
      local why = tostring(r.why)
      if why:sub(1, 7) == "courant" then
        local cause = why:gsub("%d+", "#") -- (la cause, pas les kW qui bougent à chaque minute : une ligne par changement de cause)
        if not seen[cause] then seen[cause] = true causes[#causes + 1] = why end
      end
    end
    table.sort(causes)
    local sig = table.concat(causes, " | ")
    if sig ~= (cs.courant_said or "") then
      cs.courant_said = sig
      cs.courant_logs = (cs.courant_logs or 0) + 1
      if sig ~= "" and cs.courant_logs <= Capi.COURANT_LOGS then
        log(string.format("[FO-CAPI-COURANT] %s : option(s) electrique(s) refusee(s) en amont de la decision a %.1f min : %s",
          f.key or "?", minutes(f, tick), sig))
      end
    end
  end
  -- Étape 5a de VIDEO-INTEG : le courant de la décision (capacité des centrales finies, somme nominale du relevé, puissance MESURÉE pour
  -- comparer, sans décider, et kW retenus faute de courant).
  if res.kw and not (input.power and (input.power.amorce or input.power.fermee)) then
    local g = f.build and f.build.grow
    log(string.format("[FO-CAPI-KW] %s : capacite %.0f kW, vue de la porte %.0f kW (mesure %.0f kW + chantiers), nominal %.0f kW, retenu %.0f kW a %.1f min",
      f.key or "?", res.kw.have, res.kw.used, (g and g.power or 0) * JTICK_KW, res.kw.nominal or 0, res.kw.blocked, minutes(f, tick)))
  end
  -- kW retenus, datés de cette décision : la centrale les compte pour grandir AVANT d'être saturée (script/team/sante_centrale.lua,
  -- Sante.growth, S.capi_kw ; valables S.CAPI_TTL). Aucun courant donné à la règle : rien de retenu.
  cs.kw_blocked = (res.kw and res.kw.blocked > 0) and { kw = res.kw.blocked, tick = tick, bank = res.bank } or nil -- (bank : épargne restante en MU, lot TV-ENERGIE : déficit de kW, S.deficit)
  if input.reserve then
    -- Lot INDUSTRIE I1 : journal du besoin évalué et de ce qui s'investit (une ligne par décision, au plus une par minute et par équipe).
    local stk = 0
    for _, k in ipairs(sorted_keys(view.stock or {})) do stk = stk + (view.stock[k] or 0) end
    log(string.format("[FO-RESERVE] %s minute %d | %s | stock libre %s MU investissable (part du stock au budget %s, depense %s, %d ordre(s)) | objets au coffre %d",
      f.key or "?", math.floor(minutes(f, tick) + 0.5), Rs.describe(input.reserve), string.format("%.0f", res.free_mu or 0), string.format("%.0f", res.stock_part or 0),
      string.format("%.0f", res.spent or 0), #res.orders, stk))
  end
  local sent, refused, rlog = {}, {}, {}
  -- Lot CAPI-DEBIT : le plafond des emplacements vaut pour la décision entière (avant : de 0 module ouvert, jusqu'à
  -- Capi.MAX_ORDERS modules partaient d'un coup) ; un ordre qui ouvrirait un module de trop est refusé, son épargne rendue.
  local room = cs.slots and cs.slots.room
  local room_comp = cs.slots and cs.slots.room_comp -- lot DEPENSES2 (essai 4) : siège du complément du stock qui dort (Em.slots, règle 7)
  -- Relecture du lead (18 h 10, point 1) : emplacements PLEINS au début de la décision : une foreuse n'a pu être accordée que par le
  -- siège du complément, le champ y passe lui aussi (Em.champ_seat).
  local full = room ~= nil and room <= 0
  -- Lot VIDEO-L6 : portes avant d'étendre (transport saturé, bras à seuil croissant), AVANT la boucle d'envoi ; nil : réglage éteint.
  -- Un ordre retenu suit le chemin des refus ci-dessous (« porte L6 : », épargne rendue, cs.refused).
  Capi.say_barils(f, cs, res, tick) -- lot TV-FLUX (G51)
  res.orders = AmRt.after_decision(f, cs, res, tick, minutes(f, tick)) -- lot VIDEO-COUVERTURE 5 : cycles publiés, MÊME plan re-émis après l'exécutant occupé
  local gate_why = Capi.portes(f, cs, res, view, tick)
  cs.couv_wants = Cv.reserve_wants(res.orders, gate_why) -- lot COUVERTURE : la pose prévue est une demande du mall (lue par Ind.think)
  Capi.say_saturation(f, cs, res, tick) -- lot COUVERTURE : [FO-SATURATION]
  local seat_why
  res.orders, seat_why = Capi.arbitre(f, cs, res, input, view, tick) -- lot VIDEO-SIEGES (C4/C5) : qui prend le siège d'abord, qui n'ouvre pas
  for _, o in ipairs(res.orders) do
    local rec, why
    -- (Intégration 0.6.25 : la porte de la pile de FUITES-PILE d'abord, puis le plafond des emplacements de CAPI-DEBIT.)
    local allowed, pwhy = pile_ok(f, o)
    local meth_o = (o.kind == "couvrir" or o.kind == "ouvrir") and METHOD_OF_ORE[o.resource] or nil
    local seat = Em.order_seat(room, room_comp, cs.slots and cs.slots.comp, meth_o and meth_o.product) -- (règle pure, testée)
    local champ = to_champ(f, cs, o) -- (lot CHAMP : le champ n'est pas un module)
    local cseat = champ and Em.champ_seat(full, room, room_comp, cs.slots and cs.slots.comp, meth_o and meth_o.product) or nil
    local gw = gate_why and gate_why[o.key]
    if gw then
      rec, why = nil, "porte L6 : " .. gw
    elseif seat_why and seat_why[o.key] then
      rec, why = nil, seat_why[o.key]
    elseif allowed and Capi.MODULE_KINDS[o.kind] and ((not champ and seat == nil) or (champ and cseat == nil)) then
      rec, why = nil, Em.busy_text(cs.slots) .. " ; emplacements libres pris par cette decision"
      -- (intégration 0.6.32 : retenu faute de place lui aussi ; remarque 6 de la relecture de CORR-CHAMP-MANQUE : pas quand seul le
      -- siège unique du complément était pris, Em.blocked_counts)
      if Em.blocked_counts(cs.slots and cs.slots.comp, meth_o and meth_o.product) then cs.blocked_slots = (cs.blocked_slots or 0) + 1 end
    elseif allowed then
      rec, why = execute(f, cs, o, view, book, tick, research)
      if rec and rec.exec == "champ" and cseat == "complement" then rec.seat = "complement" end -- (tenu : Capi.slots, held_comp)
    else
      why = "pile : " .. tostring(pwhy)
      PileRt.refuse(f, "capi:" .. tostring(o.key), "ordre " .. tostring(o.kind) .. " " .. tostring(o.item or o.resource or o.tech)
        .. " non envoye (" .. tostring(pwhy) .. ")", tick)
    end
    if rec and rec.exec == "module" then room, room_comp = Em.take(room, room_comp, #(rec.mod_ids or { rec.module }))
    elseif rec and rec.seat == "complement" then room, room_comp = Em.take(room, room_comp, 1) end -- (le champ sur le siège)
    if rec then
      cs.open[#cs.open + 1] = rec
      cs.orders = cs.orders + 1
      TC.note(f, TC.event(o, rec), tick) -- lot VIDEO L11 : ordre ENVOYÉ (après les portes de la boucle et le filtre de L6) : [FO-TRACE]
      sent[#sent + 1] = string.format("%s:%s(%s x%d)", o.kind, tostring(o.item or o.resource), tostring(rec.exec), o.n or 0)
      cs.stats[o.kind] = (cs.stats[o.kind] or 0) + 1
    else
      refused[#refused + 1] = o.key .. " (" .. tostring(why) .. ")"
      rlog[#rlog + 1] = { o.key, tostring(why) } -- lot DEBUG-CERVEAU
      cs.refused[o.key] = tick
      AmRt.defer(cs, o, why, tick) -- lot VIDEO-COUVERTURE 5 : refusé par l'exécutant occupé = mis de côté, re-émis à l'identique
      if cs.st.posed and o.item ~= nil then cs.st.posed[o.item] = nil end -- lot VIDEO-ORDRE : un ordre refusé n'a rien posé, l'objet reste ordonnable
      -- lot LEVIERS : pas redemandé tout de suite (lot FUITES-PILE : sauf un refus de la pile, redemandé dès qu'elle se vide)
      if allowed and (o.kind == "equiper" or o.kind == "techno") then hold(cs, o.key, why, tick) end
      -- l'ordre n'a rien coûté : l'épargne débitée par la règle lui est rendue
      cs.st.bank = (cs.st.bank or 0) + (o.cost_m or 0)
    end
  end
  for _, r in ipairs(res.refus or {}) do rlog[#rlog + 1] = { tostring(r.key), tostring(r.why) } end -- lot DEBUG-CERVEAU : refus de la règle, avec leur raison (lecture seule de res.refus)
  Capi.Anneau.note(f, tick, sent, rlog) -- lot DEBUG-CERVEAU : un seul appel, écrit dans l'anneau de la vue, jamais relu par la décision
  -- Lot PAVAGE-GEANT (règle R3 du DC, 11/11) : verdict de la règle par gisement recensé, « plein » sans place libre ou couvert à Ca.KAPPA pour mille
  -- (le verdict de la porte de l'ouverture, all_covered) ; lu par script/faction/sites.lua (admission d'un site) et la méga-fonderie (V.unfull_distance)
  for _, c in ipairs(res.coverage or {}) do
    local d = cs.deps[c.id]
    if d then d.full = (c.free or 0) <= 0 or (c.kappa or 0) >= Ca.KAPPA end
  end
  couv_report(f, cs, res, input, D, tick) -- lot CAPI-MESURE
  Ind.think(f, cs, res, view, book, tick) -- lot INDUSTRIE I6 : demande non servie -> patron (rangée ou bloc de mall) -> module
  -- couverture relue et dépôts suivis (journal : critères (1) et (3))
  local deps = {}
  for _, id in ipairs(sorted_keys(cs.deps)) do
    local d = cs.deps[id]
    deps[#deps + 1] = string.format("%s:%d/%d%s", id, d.covered or 0, d.tiles, d.danger and "!" or "")
  end
  log(Rf.line(f.key or "?", math.floor(minutes(f, tick) + 0.5), res.refus or {})) -- lot VIDEO-REFUS (C6) : refus par sorte, somme = nombre de refus
  log(string.format("[FO-CAPI] %s minute %d | tick %d | %s | envoyes [%s] | executant refuse [%s] | depots {%s} | foreuse_par_ressource {%s} | recherche_voulue [%s]",
    f.key or "?", math.floor(minutes(f, tick) + 0.5), tick, Ca.text(res), table.concat(sent, ", "), table.concat(refused, ", "),
    table.concat(deps, " "), (function()
      local o = {}
      for _, k in ipairs(sorted_keys(input.drill_for)) do if input.drill_for[k] ~= "" then o[#o + 1] = k .. "=" .. input.drill_for[k] end end
      return table.concat(o, " ")
    end)(), table.concat(cs.wanted or {}, " ")))
end

---------------------------------------------------------------------------------------------------
-- Lot CAPI-DECIDE (7/11) : la décision en TRANCHES (critères : fo-logs/2026-11-07_CAPI-DECIDE/CRITERES.md)
---------------------------------------------------------------------------------------------------
-- Première tranche (tick t0) : entrée relevée (build_input, comme avant) et INSTANTANÉ dans global (cs.dj : copie de l'entrée sans les
-- données ni la fonction, données de can_exec, bonus de la force) ; l'état de TRAVAIL (contexte, plan, besoins de la règle, copie de
-- cs.st) vit en MÉMOIRE seulement (DJ_MEM), refait depuis l'instantané quand il manque (chargement) ou que sa clé (seq, t0, sig) ne
-- correspond pas. Chaque tranche joue les unités dues à son tick (Capi.DECIDE_UNITS par tick depuis t0 ; toutes si `run` est nil ou
-- run.rush) ; rien n'est écrit dans global ni au journal avant la dernière, qui réécrit cs.st, pose cs.wanted_set et joue la suite.
-- Une recherche de la force finie, annulée ou remise à zéro pendant la décision (le livre de recettes change) l'abandonne, chez tous.
Capi.DECIDE_UNITS = 1 -- unités par tranche (une unité : le début, un tour de la boucle des ordres, ou le compte rendu)
Capi.DJ_SIG = "capi-decide:1"
Capi.PENDING = {} -- marque rendue par Capi.think quand la décision attend sa tranche suivante (jamais gardée)
Capi.MUT = {} -- tests seulement (mutants) : cle, vivant, st_tot, journal_tot, bonus
local DJ_MEM = {} -- [clé d'équipe] = { seq, t0, sig, J, input, cex, st } : MÉMOIRE seulement, jamais dans global

local function dj_key(f) return f.is_player and "player" or tostring(f.key or f.id) end

local function is_object(v) return rawget(v, "__self") ~= nil or rawget(v, "_lua_object") ~= nil end
local function dcopy(v, memo)
  if type(v) ~= "table" or is_object(v) then return v end
  memo = memo or {}
  if memo[v] then return memo[v] end
  local c = {}
  memo[v] = c
  for k, x in pairs(v) do c[dcopy(k, memo)] = dcopy(x, memo) end
  return c
end

--- Remplace le contenu de `dst` par celui de `src` (même table : les lecteurs de cs.st gardent leur référence).
local function replace_contents(dst, src)
  for _, k in ipairs(sorted_keys(dst)) do dst[k] = nil end
  for _, k in ipairs(sorted_keys(src)) do dst[k] = src[k] end
end

--- État de travail refait depuis l'instantané (mémoire).
local function dj_build(dj, cs, book)
  local D = Capi.data()
  D.bonus.mining, D.bonus.lab = dj.bonus.mining, dj.bonus.lab
  local input = dcopy(dj.input)
  local cex = dcopy(dj.cex)
  input.data = D
  input.can_exec = make_can_exec(cex, book)
  local st = dcopy(cs.st)
  local J = Ca.decide_begin(input, st)
  return { seq = dj.seq, t0 = dj.t0, sig = dj.sig, J = J, input = input, cex = cex, st = st }
end

--- Première tranche : relevé, instantané, état de travail. Rend faux (aucune décision, aucun instantané) quand une liste d'entrée
--- manque (lot VIDEO-L13, garde fermée par défaut : Ca.absent_input).
local function decide_start(f, cs, view, book, tick, w, run)
  local D = Capi.data()
  cs.flows = flows_of(f, cs)
  Dep.think(f, cs, tick, DEP_PRODUCTS, minutes(f, tick)) -- lot DEPENSES2 : budget du stock qui dort (Dep.defense, Dep.labs)
  if f.team.ia3.mall then Ml.set_running(f.team.ia3.mall, cs.flows) end -- lot PILE-MALL (relecture)
  local mrates = Mg.ON and marge_sample(f, cs, tick) or nil
  local input, cex = build_input(f, cs, view, book, tick, D, w)
  if mrates and next(mrates) ~= nil then input.marge = mrates end -- lot MARGE-TIERS : débits /min de la fenêtre (nil : pas encore de relevé)
  local absent = Ca.absent_input(input)
  if absent then
    log(string.format("[FO-CAPI] %s : decision refusee : entree absente : %s a %.1f min", f.key or "?", absent, minutes(f, tick)))
    return false
  end
  Capi.palier(f, cs, view, input, tick) -- lot VIDEO-L10 (variante B, réglage fo-war-paliers ALLUMÉ par défaut) : AVANT l'instantané
  local snap = {}
  for _, k in ipairs(sorted_keys(input)) do
    if k ~= "data" and k ~= "can_exec" then snap[k] = input[k] end
  end
  -- numéro de la décision : celui qu'elle aura une fois finie (cs.decisions compte les décisions finies ; aucun champ de plus dans
  -- global hors de l'instantané, qui disparaît à la fin : le mode bloc garde le global d'avant octet à octet)
  cs.dj = { seq = (cs.decisions or 0) + 1, t0 = tick, t_think = run and run.t or tick, sig = Capi.DJ_SIG, input = dcopy(snap), cex = dcopy(cex),
    bonus = { mining = D.bonus.mining or 0, lab = D.bonus.lab or 0 } }
  if Capi.MUT.vivant then -- mutant : l'état de travail lit l'entrée VIVANTE (pas l'instantané)
    local st = Capi.MUT.st_tot and cs.st or dcopy(cs.st)
    DJ_MEM[dj_key(f)] = { seq = cs.dj.seq, t0 = tick, sig = Capi.DJ_SIG, J = Ca.decide_begin(input, st), input = input, cex = cex, st = st }
  elseif Capi.MUT.st_tot then -- mutant : cs.st avancé dès la première tranche (prepare l'écrit)
    local m = dj_build(cs.dj, cs, book)
    m.st = cs.st
    m.J = Ca.decide_begin(m.input, cs.st)
    DJ_MEM[dj_key(f)] = m
  else
    DJ_MEM[dj_key(f)] = dj_build(cs.dj, cs, book)
  end
  return true
end

--- Tranche de la décision en cours (cs.dj) : rend vrai quand elle est finie (appliquée, ou abandonnée), faux sinon.
local function decide_slice(f, cs, view, book, tick, research, run)
  local dj = cs.dj
  local key = dj_key(f)
  local why = dj.abort or (dj.sig ~= Capi.DJ_SIG and "signature d'une autre version") or nil
  if why then
    cs.dj, DJ_MEM[key] = nil, nil
    log(string.format("[FO-CAPI] %s : decision du tick %d abandonnee (%s) a %.1f min", f.key or "?", dj.t0, why, minutes(f, tick)))
    return true
  end
  local mem = DJ_MEM[key]
  if not (mem and ((mem.seq == dj.seq and mem.t0 == dj.t0 and mem.sig == dj.sig) or Capi.MUT.cle)) then
    mem = dj_build(dj, cs, book)
    DJ_MEM[key] = mem
  end
  local D = Capi.data()
  if not Capi.MUT.bonus then D.bonus.mining, D.bonus.lab = dj.bonus.mining, dj.bonus.lab end
  local due = (run == nil or run.rush) and math.huge or Capi.DECIDE_UNITS * (tick - dj.t0 + 1)
  local J = mem.J
  local done = J.res ~= nil
  Profiler.fstart("capi:decide")
  while not done and J.units < due do done = Ca.decide_step(J) end
  Profiler.fstop("capi:decide")
  if not done then
    if Capi.MUT.journal_tot then log(string.format("[FO-CAPI] %s : MUTANT, tranche intermediaire au tick %d", f.key or "?", tick)) end
    return false
  end
  replace_contents(cs.st, mem.st)
  cs.wanted_set = mem.cex.wanted
  do -- lot BLOCAGE-SORTIE-2 : manques mesurés que cette décision ne peut pas lever (Ca.obtainable) ; lus par Capi.palier_inputs à la décision suivante
    local imp, build = {}, view.mq and view.mq.build or nil
    for _, k in ipairs(sorted_keys(build or {})) do
      if (build[k] or 0) > 0 and not Ca.obtainable(J.ctx, k) then imp[k] = true end
    end
    cs.impayable = next(imp) ~= nil and imp or nil
  end
  cs.dj, DJ_MEM[key] = nil, nil
  RangTrace.note(f, J.ctx.rang, tick) -- lot VIDEO-TRACES (G34) : journal [FO-RANG], une ligne par signature changée (rang de la décision, sans toucher au résultat)
  do -- lot MARGE-TIERS : [FO-MARGE] toutes les 5 minutes, et à chaque gel posé ou levé
    local mg = J.ctx.mg
    if mg then
      local changed = (cs.marge_gel == true) ~= (mg.gel == true)
      if changed or cs.marge_log == nil or tick - cs.marge_log >= 5 * 3600 then
        cs.marge_log = tick
        local _, win_min = Mg.rates(cs.marge_win)
        log(Mg.format(f.key or "player", math.floor(minutes(f, tick)), mg, J.ctx.mg_n, win_min))
      end
      cs.marge_gel = mg.gel == true
    end
  end
  RangTrace.attentes(f, J.ctx.cons_log, tick) -- lot CONSOLIDATION-TIERS : [FO-RANG] une ligne par attente, consolidation ou levée (sans toucher au résultat)
  decide_finish(f, cs, J.res, mem.input, view, book, tick, research)
  return true
end

--- Équipes de la force `force` (factions de la guerre, puis votre équipe), dans un ordre fixe.
local function teams_of_force(force)
  local out = {}
  local name = force and force.valid and force.name
  local war = State.war()
  if war and war.factions then
    for _, id in ipairs(sorted_keys(war.factions)) do
      local f = war.factions[id]
      if f and (name == nil or f.force == name) then out[#out + 1] = f end
    end
  end
  local p = State.faction("player")
  if p and (name == nil or p.force == name) then out[#out + 1] = p end
  return out
end

local function abort_research(force, why)
  for _, f in ipairs(teams_of_force(force)) do
    local cs = f.team and f.team.capi
    if cs and cs.dj and not cs.dj.abort then cs.dj.abort = why end
  end
end
Events.on(defines.events.on_research_finished, function(e) abort_research(e.research and e.research.force, "recherche finie") end)
Events.on(defines.events.on_research_reversed, function(e) abort_research(e.research and e.research.force, "recherche annulee") end)
Events.on(defines.events.on_technology_effects_reset, function(e) abort_research(e.force, "recherches remises a zero") end)
Events.on(defines.events.on_force_reset, function(e) abort_research(e.force, "force remise a zero") end)
-- Configuration changée : la mémoire est jetée (la tranche suivante la refait depuis l'instantané, ou abandonne une autre signature).
Events.on_configuration_changed(function() DJ_MEM = {} end)

--- Tests (moteur simulé) : un chargement simulé vide la mémoire, comme un vrai chargement.
function Capi.forget_memory() DJ_MEM = {} end

---------------------------------------------------------------------------------------------------
-- Pensée
---------------------------------------------------------------------------------------------------
--- Appelé par le cerveau (Ia3.plan) avant la pensée pure. Rend ctx.capi = { res, open } (buts de fond), ou nil ; Capi.PENDING quand la
--- décision découpée attend sa tranche suivante (lot CAPI-DECIDE). `run` : nil (tout tout de suite) ou { t = tick de la pensée, rush }.
function Capi.think(f, view, book, tick, research, w, run)
  if not Capi.on(f) then return nil end
  local cs = state_of(f)
  if cs.dj and run and cs.dj.t_think ~= run.t then
    -- décision d'une pensée perdue (effacée au changement de version du mod) : jetée, cette pensée repart comme d'habitude
    log(string.format("[FO-CAPI] %s : decision du tick %d abandonnee (pensee du tick %d perdue) a %.1f min", f.key or "?", cs.dj.t0,
      cs.dj.t_think, minutes(f, tick)))
    cs.dj, DJ_MEM[dj_key(f)] = nil, nil
  end
  Profiler.start("capi:think")
  if cs.dj then
    if not decide_slice(f, cs, view, book, tick, research, run) then
      Profiler.stop("capi:think")
      return Capi.PENDING
    end
    return Capi.think_tail(f, cs, tick)
  end
  Ind.sweep(f, tick) -- lot INDUSTRIE I6 : sorties des patrons à la collecte, barre posée (à chaque pensée, pas seulement à la décision)
  TC.capi(f, cs, tick) -- lot VIDEO L11 : étiquette des modules des ordres ouverts dès qu'ils ont un lieu (« pose » quand ils sont finis)
  TC.flush(f, tick) -- lot VIDEO L11 : chunk cartographié depuis (F131), copies chez le joueur retirées quand le réglage est coupé
  local phase = cs.n % Capi.CYCLE
  cs.n = cs.n + 1
  if phase == 0 then
    Profiler.fstart("capi:scan")
    scan(f, cs, tick)
    Profiler.fstop("capi:scan")
  elseif phase == 1 then
    Profiler.fstart("capi:coverage")
    coverage(f, cs, tick)
    Profiler.fstop("capi:coverage")
  elseif phase >= 2 and phase <= 9 then
    -- lot COUT-600 : un gisement de la couverture par pensée (les cinq ou six gisements d'avant ne tenaient pas dans la seule pensée 1)
    Profiler.fstart("capi:coverage")
    coverage(f, cs, tick)
    Profiler.fstop("capi:coverage")
    census_one(f, cs, tick)
  elseif phase == 10 and cs.scan then
    if decide_start(f, cs, view, book, tick, w, run) and not decide_slice(f, cs, view, book, tick, research, run) then
      Profiler.stop("capi:think")
      return Capi.PENDING
    end
  elseif phase == 11 and Capi.Mega.on() then
    -- Lot MEGA-FONDERIE : méga-fonderie des gisements recensés (étape libre jusqu'ici : une seule étape coûteuse par pensée)
    Profiler.fstart("mega:think")
    Capi.Mega.think(f, cs, tick, { power = Auto.plant_state(f) == "fini", crisis = (view and (view.survie or view.hq_threat)) and true or false })
    Profiler.fstop("mega:think")
  end
  return Capi.think_tail(f, cs, tick)
end

--- Suite de Capi.think après la décision (suivi des ordres, laboratoires, buts de fond) : chaque pensée.
function Capi.think_tail(f, cs, tick)
  -- Suivi des ordres ouverts (chaque pensée : lectures sans appel coûteux du moteur).
  local keep = {}
  for _, rec in ipairs(cs.open) do
    local state, why = follow(f, cs, rec, tick)
    if state == "ouvert" and tick - (rec.progress_tick or rec.opened) > Capi.ORDER_TTL then
      state, why = "echec", "aucun progres en " .. math.floor(Capi.ORDER_TTL / 3600) .. " min"
      if rec.exec == "module" then
        for _, id in ipairs(rec.mod_ids or { rec.module }) do Build.cancel(f, id, "CAPI : " .. why) end
      end
    end
    if state == "ouvert" then keep[#keep + 1] = rec
    else
      if state == "fini" and rec.exec == "module" and rec.product then
        -- Lot CAPI-REPLI : un module terminé remet à zéro le repli et la réduction de sa clé (produit, gisement)
        Rp.done(repli_book(cs), Rp.key(rec.product, rec.deposit))
      end
      if state == "fini" then
        cs.lag_hist = cs.lag_hist or {}
        cs.lag_hist[#cs.lag_hist + 1] = (tick - rec.opened) / 3600
        while #cs.lag_hist > 5 do table.remove(cs.lag_hist, 1) end
        local s = 0
        for _, x in ipairs(cs.lag_hist) do s = s + x end
        cs.lag = s / #cs.lag_hist
      end
      if state == "echec" and rec.exec == "module" and rec.product then
        -- Lot CAPI-REPLI : repli de (produit, gisement) ; un échec de matériaux ne ferme PAS le gisement (module réduit,
        -- objets manquants gardés en préparation)
        local rkey = Rp.key(rec.product, rec.deposit)
        local kind = Rp.fail(repli_book(cs), rkey, why, tick, rec.lost)
        log(string.format("[FO-CAPI-REPLI] %s : %s : echec %s (%s) -> %s a %.1f min", f.key or "?", rkey, kind, tostring(why),
          kind == "materiaux" and "gisement ouvert, module suivant a 1/" .. (2 ^ Rp.eff(repli_book(cs)[rkey], tick, "shrink")) .. " et materiaux en preparation"
            or Rp.describe(repli_book(cs), rkey, tick, nil), minutes(f, tick)))
      end
      if state == "echec" and (rec.exec == "equiper" or rec.exec == "techno") then hold(cs, rec.key, why, tick) end
      -- Lot LEVIERS : le relevé des machines (une fois par minute) ne montre pas encore les modules qu'un PNJ vient de poser :
      -- cette clé n'est pas redécidée avant le relevé suivant (banc leviers-modules : le même ordre, réémis sur l'ancien relevé).
      if rec.exec == "equiper" and cs.scan then
        cs.stale = cs.stale or {}
        cs.stale[rec.key] = cs.scan.tick
      end
      if state == "fini" and Cv.SITE_EXECS[rec.exec] then
        -- Lot COUVERTURE : compteur cumulé des chantiers finis, modules et bandes du champ (nombre, jamais d'entité) ; amorcé sur l'historique
        -- pour une partie d'avant.
        cs.batis_done = (cs.batis_done or Cv.seed(cs.done)) + math.max(1, #(rec.mod_ids or { rec.module }))
      end
      cs.done[#cs.done + 1] = { key = rec.key, kind = rec.kind, exec = rec.exec, n = rec.n, state = state, why = why,
        opened = rec.opened, closed = tick }
      while #cs.done > Capi.LOG_ORDERS do table.remove(cs.done, 1) end
      note(f, cs, tick, string.format("ordre %s %s (%s%s) apres %.1f min", rec.key, state == "fini" and "FINI" or "ECHOUE",
        tostring(rec.exec), why and (", " .. why) or "", (tick - rec.opened) / 3600))
    end
  end
  cs.open = keep
  -- Lot MODULES-POSES : les modules au coffre, au-delà d'une petite réserve, sont posés par les PNJ (ordres « equiper » de stock ajoutés
  -- à cs.open ; la tâche est postée plus bas comme pour tout ordre « equiper »).
  Capi.MS.think(f, cs, tick, { Ca = Ca, D = Capi.data(), minutes = minutes, held = held,
    count = function(item) return Stock.count(f, item) end,
    power = function() return Capi.power_input(f, Auto.plant_state(f)) end,
    threat = (f.threatened_until or 0) > tick })
  -- Laboratoires visés : ceux du QG plus le reste des ordres ouverts.
  local labs_want = cs.nlabs or 0
  for _, rec in ipairs(cs.open) do
    if rec.exec == "labos" then labs_want = math.max(labs_want, rec.target or 0) end
  end
  cs.labs_want = labs_want
  -- Buts de fond du cerveau : un par ordre ouvert (Ca.goals), avec ce qui manque à l'exécutant.
  -- Lot ELEC2 : un ordre qui ÉTEND la capacité d'une matière dont les projets manquent (couvrir, ouvrir : foreuses
  -- électriques et fours sur place) est servi DEVANT les consommateurs permanents de cette matière (voir Ca.goals).
  -- Seulement quand la centrale tourne : sans courant le module attend « pas de centrale » et ses matériaux pris d'avance
  -- ne rapportent rien (moteur réel, etape1-guide 123456789 : l'armée de scarlet à 0 soldat pendant que le module de fer
  -- était refusé 30 min).
  local short_now = (f.team.ia3 and f.team.ia3.short) or {}
  local D0 = Capi.data()
  local power_up = Auto.plant_state(f) == "fini"
  -- Amorçage seulement : une matière qui a déjà des foreuses électriques posées reprend le rang ordinaire des buts de fond
  -- (la défense ne paie pas chaque agrandissement ; moteur réel, 1618033988 : azure perd son armée en 3 fonderies de fer).
  local elec_on = {}
  for _, dr in ipairs(cs.scan and cs.scan.drills or {}) do
    if dr.entity == elec_drill then elec_on[dr.resource] = (elec_on[dr.resource] or 0) + (dr.n or 1) end
  end
  local function makes_short(rec)
    if not power_up or (rec.kind ~= "couvrir" and rec.kind ~= "ouvrir") then return false end
    if (elec_on[rec.item] or 0) > 0 then return false end
    if (short_now[rec.item] or 0) > 0 then return true end
    local r = rec.smelt_recipe and D0.recipes[rec.smelt_recipe]
    for _, pr in ipairs(r and r.products or {}) do
      if (short_now[pr.name] or 0) > 0 then return true end
    end
    return false
  end
  local open = {}
  for _, rec in ipairs(cs.open) do
    open[#open + 1] = { key = rec.key, kind = rec.kind, item = rec.item, value = rec.value, exec = rec.exec,
      outpost_kind = rec.outpost_kind, n_left = rec.n_left, missing = rec.missing, blocked = rec.blocked, tech = rec.tech,
      short = makes_short(rec), mod_ids = rec.mod_ids } -- (mod_ids, lot KITS-VOLES : les kits de l'ordre vont à ses modules)
  end
  -- Lot CAPI-REPLI : objets qui manquaient à un module refusé pour « materiaux introuvables » : but de FABRICATION gardé
  -- Rp.PREP_TTL après l'échec (le module suivant, réduit, les trouvera au coffre). Un ordre ouvert de la même clé reprend
  -- ses manques lui-même (pas de doublon). `short` : la matière du produit manque et la centrale tourne, comme makes_short
  -- (« si on manque cruellement de ressources, l'objectif est ces ressources », DC 29/10).
  do
    local book_r = repli_book(cs)
    local live = {}
    for _, rec in ipairs(cs.open) do
      if rec.exec == "module" and rec.product then live[Rp.key(rec.product, rec.deposit)] = true end
    end
    for _, pr in ipairs(Rp.prep(book_r, tick)) do
      if not live[pr.key] then
        local product = pr.key:match("^([^@]*)")
        open[#open + 1] = { key = "prep:" .. pr.key, kind = "prep", item = product, value = Ca.V_MIN, exec = "prep",
          missing = pr.missing, short = (power_up and (short_now[product] or 0) > 0) or nil }
      end
    end
    Rp.prune(book_r, tick)
  end
  -- Lot LEVIERS : tâches « equiper » (une par ordre : le premier lot de machines non traitées, dès que les modules sont
  -- au coffre) ; renouvelées à chaque pensée, comme le plan.
  local tasks = {}
  for _, rec in ipairs(cs.open) do
    -- Lot FUITES-PILE : poser des modules dans les machines est une amélioration (R3) : suspendu pendant une retenue de la pile (sauf
    -- pour une machine d'une matière d'un cadre ouvert ou qui manque) ; l'ordre ne vieillit pas pendant la suspension
    local eq_ok, eq_why = true, nil
    if rec.exec == "equiper" and (rec.n_left or 0) > 0 then
      -- Lot MODULES-POSES : un module DÉJÀ au coffre n'a aucun coût d'opportunité en matière ; seule la pile « survivre » suspend sa pose
      if rec.stock then eq_ok, eq_why = Capi.MS.gate(f)
      else eq_ok, eq_why = PileRt.porte_any(f, "capi", { rec.d_item }) end
      if not eq_ok then
        rec.progress_tick = tick
        PileRt.refuse(f, "equiper:" .. tostring(rec.key), "pose de modules " .. tostring(rec.module) .. " suspendue (" .. tostring(eq_why) .. ")", tick)
      end
    end
    if eq_ok and rec.exec == "equiper" and (rec.n_left or 0) > 0 then
      local done = {}
      for _, u in ipairs(rec.done or {}) do done[u] = true end
      local nb = math.ceil(#rec.targets / Equip.BATCH)
      for b = 1, nb do
        local batch = {}
        for i = (b - 1) * Equip.BATCH + 1, math.min(#rec.targets, b * Equip.BATCH) do
          if not done[rec.targets[i].u] then batch[#batch + 1] = rec.targets[i] end
        end
        if #batch > 0 then
          if Stock.count(f, rec.module) >= #batch * rec.per then
            tasks[#tasks + 1] = { key = "eq:" .. rec.key .. ":" .. b, kind = Equip.KIND, prio = rec.stock and Equip.PRIO_STOCK or Equip.PRIO, domain = "production",
              work = 20 + 10 * #batch, items = { { rec.module, #batch * rec.per } }, targets = batch, module = rec.module,
              per = rec.per, rec_key = rec.key }
          end
          break -- un lot à la fois par ordre : les modules du suivant attendent le coffre
        end
      end
    end
  end
  Profiler.stop("capi:think")
  return { res = cs.res, open = open, tasks = tasks }
end

--- Lot LEVIERS : recherches à effet que la capitalisation a CHOISIES et qui restent ouvertes : { [technologie] = valeur }.
--- Lue par le choix de la technologie (script/ai3/general.lua, ctx.levers de Gen.choose). Nil : aucune.
function Capi.techs_wanted(f)
  if not (f and f.team and f.team.capi) or not Capi.on(f) then return nil end
  local out = nil
  for _, rec in ipairs(f.team.capi.open) do
    if rec.exec == "techno" and rec.tech then
      out = out or {}
      out[rec.tech] = rec.value or Ca.V_MIN
    end
  end
  for _, t in ipairs(sorted_keys(f.team.capi.unlock_techs or {})) do
    out = out or {}
    if out[t] == nil then out[t] = Ca.V_MIN end
  end
  return out
end

--- Laboratoires visés par la capitalisation (nil : capitalisation éteinte pour cette faction).
function Capi.labs_want(f)
  if not Capi.on(f) then return nil end
  local cs = f.team.capi
  return cs and cs.labs_want or nil
end

---------------------------------------------------------------------------------------------------
-- Interface distante de LECTURE (bancs)
---------------------------------------------------------------------------------------------------
local function team_of(key)
  if key == "player" then return State.faction("player") end -- lot LEVIERS : votre équipe aussi (bancs)
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and (f.key == key or id == key) then return f end
  end
  return nil
end

remote.add_interface("fo-capi", {
  --- Lot LEVIERS (BANC SEULEMENT) : déclare interdits tous les gisements de la faction (même champ que « hors du plan
  --- directeur ») ; la détection du danger elle-même n'est pas touchée. Rend vrai si la faction existe.
  --- Lot LEVIERS (BANC SEULEMENT) : un client externe de la faction consomme `rate` objets/min de `item` (puits mesuré de la
  --- règle, élastique en dehors du banc) ; rate 0 le retire.
  bench_sink = function(key, item, rate)
    local f = team_of(key)
    if not (f and f.team) then return false end
    local cs = state_of(f)
    cs.bench_sinks = (rate and rate > 0) and { { item = item, rate = rate, want = rate } } or nil
    return true
  end,
  --- Lot C2 (BANC SEULEMENT, témoin) : éteint le puits ouvert, la décision sur le débit voulu et le seuil du tapis de cette faction.
  demande_off = function(key, off)
    local f = team_of(key)
    if not (f and f.team) then return false end
    state_of(f).demande_off = off and true or nil
    return true
  end,
  block_sites = function(key, on)
    local f = team_of(key)
    if not (f and f.team) then return false end
    state_of(f).block_all = on and true or nil
    return true
  end,
  --- Lot CORR-CHAMP-MANQUE (BANC SEULEMENT, témoin) : on = false éteint la règle 8 des emplacements (siège du minerai dont la plaque
  --- manque aux ordres ouverts) pour cette équipe ; on = true (ou nil) la rallume. Rend vrai si l'équipe existe.
  manque = function(key, on)
    local f = team_of(key)
    if not (f and f.team) then return false end
    state_of(f).no_short = (on == false) or nil
    return true
  end,
  --- Lot CORR-CHAMP-MANQUE (BANC SEULEMENT) : ouvre un ordre de la capitalisation de genre `kind` (« chaine » ou « packs ») pour
  --- `item` à `rate` objets/min, par l'exécutant des ordres de la décision (execute : A.method_for, Auto.submit) SANS passer par
  --- elle ; l'ordre entre dans cs.open (emplacements, suivi, manques) comme un ordre décidé. Rend les numéros de modules, ou nil et
  --- la raison. (Comme « fo-ind row » : un banc court ne peut pas attendre que la décision veuille ces ordres.)
  bench_order = function(key, kind, item, rate)
    local f = team_of(key)
    local cs = f and f.team and f.team.capi
    if not (cs and f.hq and f.hq.valid) then return nil, "equipe ou capitalisation absente" end
    if kind ~= "chaine" and kind ~= "packs" then return nil, "genre refuse : " .. tostring(kind) end
    local force = game.forces[f.force]
    local book = Book.from_game(game.recipe_prototypes, { allowed = function(name)
      local r = force and force.recipes[name]
      return r ~= nil and r.enabled
    end })
    local inv = f.hq.get_inventory(defines.inventory.chest)
    local view = { stock = inv and inv.get_contents() or {} }
    local o = { key = "banc:" .. kind .. ":" .. tostring(item), kind = kind, item = item, rate = rate, n = 1, T = 0, why = "banc" }
    local rec, why = execute(f, cs, o, view, book, game.tick, nil)
    if not rec then return nil, tostring(why) end
    cs.open[#cs.open + 1] = rec
    return rec.mod_ids, o.key
  end,
  --- Lot MEGA-FONDERIE (BANC SEULEMENT) : l'étape 11 tout de suite (sans attendre le cycle de 12 pensées), courant comme l'étape 11 (centrale
  --- finie), sans crise. box = { x0, y0, x1, y1, resource, tiles } : un gisement relevé AU MOTEUR dans cette boîte (tiles impose le compte :
  --- mesure de coût d'un gisement géant) ; sans box : les gisements recensés (cs.deps). Durée au profileur : ligne [FO-MEGA-COUT]. Rend
  --- { power, n, deps = copie de f.mega.deps }.
  bench_mega = function(key, box)
    local f = team_of(key)
    local cs = f and f.team and f.team.capi
    if not (cs and f.hq and f.hq.valid) then return nil end
    local target = cs
    if box then
      local n = box.tiles or f.hq.surface.count_entities_filtered({ area = { { box.x0, box.y0 }, { box.x1, box.y1 } }, name = box.resource })
      local id = "banc:" .. tostring(box.resource) .. "@" .. box.x0 .. "," .. box.y0
      target = { deps = { [id] = { id = id, resource = box.resource, tiles = n, x0 = box.x0, y0 = box.y0, x1 = box.x1, y1 = box.y1,
        cx = (box.x0 + box.x1) / 2, cy = (box.y0 + box.y1) / 2 } } }
    end
    local power = Auto.plant_state(f) == "fini"
    local prof = game.create_profiler()
    local n = Capi.Mega.think(f, target, game.tick, { power = power, crisis = false })
    prof.stop()
    log({ "", "[FO-MEGA-COUT] ", f.key or "player", " : ", n, " gisement(s) relu(s), ", (box and box.tiles) and "tuiles imposees par le banc, " or "", prof })
    return { power = power, n = n, deps = f.mega and f.mega.deps or {} }
  end,
  --- Lot TV-ENERGIE (W02, lecture seule) : le relevé du courant que la capitalisation donnerait aujourd'hui à la règle, selon l'état de la
  --- centrale de l'équipe (Auto.plant_state) : { amorce } ou { fermee } sans centrale finie, { have_kw, used_kw } avec.
  --- Lot TV-ENERGIE (BANC SEULEMENT) : kW retenus faute de courant et épargne, datés d'aujourd'hui (comme la fin d'une décision, cs.kw_blocked).
  bench_kw = function(key, kw, bank)
    local f = team_of(key)
    if not (f and f.team) then return false end
    state_of(f).kw_blocked = kw and kw > 0 and { kw = kw, tick = game.tick, bank = bank } or nil
    return true
  end,
  --- Lot TV-ENERGIE (lecture seule) : le texte du refus de courant et la répartition des kW par la règle réelle (moteur, données du jeu).
  kw_probe = function(have, used, kw)
    local plan = { kw_have = have, kw_used = used }
    local allot, order = Ca.kw_alloc({ { key = "A", item = "obj-a", kw = 90, n = 18, short = 30 }, { key = "B", item = "obj-b", kw = 90, n = 1, short = 10 } }, have - used)
    return { why = Ca.kw_refusal(plan, kw), allot = allot, order = order }
  end,
  power_probe = function(key, state, why, wait)
    local f = team_of(key)
    if not f then return nil end
    local ps, pw = Auto.plant_state(f)
    if state ~= nil then ps, pw = state, why end
    return Capi.power_input(f, ps, pw, wait), ps
  end,
  --- Lot MODULES-POSES (BANC SEULEMENT) : relève les machines tout de suite (au lieu d'attendre la phase 0 de la minute) ; la disposition
  --- du stock de modules (Capi.MS.think) tourne à la pensée suivante par son chemin ordinaire. Rend vrai si l'équipe existe.
  bench_scan = function(key)
    local f = team_of(key)
    local cs = f and f.team and f.team.capi
    if not (cs and f.hq and f.hq.valid) then return false end
    scan(f, cs, game.tick)
    return true
  end,
  status = function(key)
    local f = team_of(key)
    local cs = f and f.team and f.team.capi
    if not cs then return nil end
    local out = { on = Capi.on(f), decisions = cs.decisions, orders = cs.orders, open = {}, done = {}, deps = {},
      res = cs.res, labs_want = cs.labs_want, stats = {}, lag = cs.lag, wanted = cs.wanted, repli = cs.repli_text, unlocks = cs.unlocks }
    for _, rec in ipairs(cs.open) do
      out.open[#out.open + 1] = { key = rec.key, kind = rec.kind, exec = rec.exec, n = rec.n, n_left = rec.n_left,
        mod_ids = rec.mod_ids, opened = rec.opened, module = rec.module, per = rec.per, inserted = rec.inserted,
        refused = rec.refused, why_refused = rec.why_refused, tech = rec.tech, announced = rec.announced,
        resource = rec.resource, product = rec.product, missing = rec.missing, stock = rec.stock } -- (lot CORR-CHAMP-MANQUE : ressource, produit, manques ; lot MODULES-POSES : ordre de stock)
    end
    -- lot CORR-CHAMP-MANQUE : emplacements du dernier relevé (Capi.slots), produits du siège du complément dans l'ordre des fonderies
    local sl = cs.slots
    if sl then
      local comp = {}
      for _, p in ipairs(PLATE_PRODUCTS) do if sl.comp and sl.comp[p] then comp[#comp + 1] = p end end
      out.slots = { cap = sl.cap, counted = sl.counted, open = sl.open, room = sl.room, room_comp = sl.room_comp, busy = sl.busy,
        materials = sl.materials, comp = comp, why = sl.why }
    end
    for _, d in ipairs(cs.done) do out.done[#out.done + 1] = d end
    -- lot CAPI-REPLI / CAPI-MESURE : repli par (produit, gisement) et raison de chaque foreuse refusée (bancs)
    out.repli, out.drill_why = {}, cs.drill_why
    for _, k in ipairs(sorted_keys(cs.repli or {})) do out.repli[k] = Rp.describe(cs.repli, k, game.tick, nil) end
    -- lot LEVIERS : machines relevées (groupes) pour les bancs
    out.machines = {}
    for _, m in ipairs(cs.scan and cs.scan.machines or {}) do
      out.machines[#out.machines + 1] = { entity = m.entity, recipe = m.recipe, where = m.where, n = m.n, sig = m.sig }
    end
    for _, id in ipairs(sorted_keys(cs.deps)) do
      local d = cs.deps[id]
      out.deps[#out.deps + 1] = { id = id, resource = d.resource, tiles = d.tiles, amount = d.amount, covered = d.covered,
        x0 = d.x0, y0 = d.y0, x1 = d.x1, y1 = d.y1, cx = d.cx, cy = d.cy, danger = d.danger, cut = d.cut }
    end
    for _, k in ipairs(sorted_keys(cs.stats)) do out.stats[k] = cs.stats[k] end
    return out
  end,
})

return Capi
