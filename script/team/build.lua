--[[
  CONSTRUCTION PAR LES PNJ (lot IA1-d, docs/EQUIPES_PNJ.md §6.5 à §6.8) : le plan directeur (shared/team/plan.lua, pur)
  appliqué au monde réel.

  Pour une équipe (faction ou votre équipe), `f.build` porte :
    - le treillis (lots de 24, rues de 4, ancré au QG) et l'ÉVALUATION des lots et des tronçons de rue (3 appels du
      moteur chacun, sur les jetons de travail du mod ; aucune entité posée) ;
    - les PROJETS : « construire tel module à tel débit, ici » (Build.request, l'interface du cerveau IA3-c) :
        attente (lots pas encore évalués) → plan (lot, rotation, têtes d'alimentation, tapis, poteaux) → reserve
        (objets RETIRÉS du coffre vers le stock du chantier : personne ne les arrache) → defrichage (arbres, rochers)
        → fantomes (posés d'avance ; votre équipe : « juste à temps », F176) → chantier (les PNJ ravivent les fantômes
        à 16 tuiles au plus de leur point d'appui) → raccordement (fils, recettes) → fini ; ou refuse / bloque (raison) ;
    - le RÉSEAU électrique : grands poteaux aux carrefours (moyens à défaut), centrale à vapeur sur une rive ;
    - les mesures : refus de lots et fermetures de rues par raison, marches par les rues, PNJ bloqués et replis vers le
      PathService (par minute), fantômes posés, ravivés, refusés.
  Les PNJ prennent les tâches au tableau de l'équipe (Board.add après chaque pensée) : `ghost` (construire un lot de
  fantômes autour d'un point d'appui), `clear` (défricher), `carry` (remplir un quai, vider un quai de sortie). Leurs
  programmes d'étapes sont dans script/team/worker.lua (étape « ia1d »).

  Rien ne change pour une équipe sans `f.build` (Build.enable n'est appelé que par le cerveau ou un banc).
  Déterminisme : listes triées, clés triées ; aucun temps mesuré ; rien de fonctionnel dans global.
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local Stock = require("script.team.stock") -- lot COFFRE : stock = coffre du QG + annexes
local Board = require("script.team.board")
local ChantierLent = require("script.team.chantier_lent") -- lot AZURE : trace [FO-CHANTIER-LENT] (lecture seule)
local Tokens = require("script.team.tokens")
local Profiler = require("script.core.profiler")
local P = require("shared.team.plan")
local M = require("shared.team.modules")
local Saut = require("shared.team.champ_saut") -- lot FONDERIE : foreuse de bande sautée quand une tourelle de l'équipe a pris son emprise
local Fonte = require("shared.team.fonte") -- lot FONDERIES : équilibre entre l'entrée des foreuses et les fours (règle pure)
local Li = require("shared.team.ligne")       -- lot AGENCEMENT : fonderie en longue ligne extensible (règles pures)
local Gisements = require("shared.team.gisement") -- lot GISEMENTS : un lot qui porte un minerai sert de gisement
local Tr = require("shared.team.treillis") -- lot INDUSTRIE I3 : jusqu'où le treillis grandit vers un gisement, cause du refus (règles pures)
local Fal = require("script.team.falaise") -- lot OBSTACLES : emprise RÉELLE des falaises (orientation), pas la boîte générique de bounding_box
local FalPure = require("shared.team.falaise") -- lot OBSTACLES : mémoire bornée des tuiles refusées à cause d'une falaise
local Rsv = require("script.ai3.reserve") -- lot INDUSTRIE : le réglage maître (fo-war-industrie)
local Rg = require("shared.team.rangees")     -- lot AGENCEMENT : foreuses en rangées qui couvrent le gisement (règles pures)
local Db = require("shared.team.debit")       -- lot RANGEES-DEBIT : ligne de foreuses dimensionnée par le débit du tapis (règles pures)
local CvRegle = require("shared.team.convoyeurs")  -- lot RANGEES-DEBIT (relecture) : choix du tapis sans le journal du premier vrai tracé
local Conv = require("script.team.convoyeurs") -- lot CONVOYEURS : tapis selon la technologie
local T = require("shared.team.config")      -- lot ESPACE : nom du mur de l'enceinte (T.wall)
local Cr = require("shared.team.coupure_reseau") -- lot ENERGIE (2/11) : zone des ennemis d'un second chemin de poteaux
local Pt = require("shared.team.poteaux")   -- lot POTEAUX-COURT : longueur de fil, choix direct ou escalier (règles pures)
local Mq = require("shared.team.masques")   -- lot POTEAUX-MASQUES : relevé paresseux des masques par chunk (règles pures)
local Or = require("shared.team.orient")      -- lot PD-FONDERIEQG (D82) : sens du gisement (règle pure)
local Blocage = require("shared.team.blocage") -- lot FACTIONS-BLOQUEES : tourelle sur un chantier, projet sans progrès (règles pures)
local Axe = require("shared.team.axe") -- lot TOURELLES-HORS-AXE : couloir d'extension des lignes (règles pures)
local Enc = require("shared.team.enceinte")  -- lot ESPACE : croissance et enceinte (règles pures)
local PlantArms = require("script.team.plant_arms") -- lot PLANDIR : moniteur de la centrale (journal)
local Sante = require("script.team.sante_centrale") -- lot ENERGIE (2/11) : amorce à la main des chaudières à sec, porte des consommateurs
local Jeton = require("script.team.pouls_jeton") -- lot POULS : un seul relevé lourd du pouls par tick (réseau ou raccord)
local BoiteChunks = require("script.team.boite_chunks") -- lot POULS : boîte des chunks générés (relevé du réseau par bandes)
local Liaison = require("script.team.liaison") -- lot INDUSTRIE I7 : un tapis du coffre de sortie d'un module au quai d'entrée d'un autre (le PNJ ne porte plus)
local Sweep = require("shared.team.rebuild_sweep") -- lot INTEG-RECONSTRUCTION : règles pures du relevé (refus répété d'un projet rouvert)
local Outposts = require("script.faction.outposts") -- lot AUTO : crochets des poseurs de tourelles (Outposts.corridors)
local PlacesQG = require("script.ai3.places_qg") -- lot FOUR-PLEIN : crochet des tuiles réservées (PlacesQG.reserved) ; lot TOURELLES-MINERAI : PlacesQG.on_resource (tourelle déplacée)
local Ilots = require("script.team.ilots") -- lot ILOTS-MURS : murs et tourelles des îlots isolés hors de l'enceinte
local Sq = require("shared.team.survie_qg") -- lot QGSURVIE : réserve de fer du QG avant un module neuf (règle pure)
local Ic = require("shared.team.ilots_croissance") -- lot C3 EXTENSION : le treillis grandit au-delà du mur, en îlots défendus (règles pures)
local Cv = require("shared.team.champ_vapeur") -- lot ENERGIE : champ de machines à vapeur (tapis par relais, refus de l'alimentation)
local Cc = require("shared.team.charbon_centrale") -- lot CHARBON-CENTRALE : coffre de la centrale en urgence, foreuses de la centrale (règles pures)
local Cl = require("shared.team.centrale_loin") -- lot PD-CENTRALE : règles pures de la centrale lointaine (D-24)
local Far = require("script.team.centrale_loin") -- lot PD-CENTRALE : eau hors du treillis, ligne de poteaux

local Build = {}
-- lot DECOUPLAGE : le type de prototype d'une entité de gabarit (BOX_MINAGE / BOX_FONDERIE de P.fit), lu dans les données du jeu
Build.Sm = require("shared.team.sol_minerai")
Build.Sm.type_of = function(name) local pr = game.entity_prototypes[name]; return pr and pr.type end
-- lot DEFAUTS-REVELES : bloc principal à 200 locales (limite de Lua) ; modules lus en un seul endroit = champs de Build, pas des locales
Build.Tournee = require("shared.team.tournee_pose") -- lot CHANTIERS-FANTOMES : tournées de pose (règle pure)
Build.RevueObst = require("shared.team.revue_obstacles") -- lot AGEBLOCAGE : curseur de la revue des obstacles
Build.Rv = require("script.team.reseau_vivant") -- lot CORR-RESEAU : santé de la centrale et du réseau après « fini »
Build.Raccord = require("script.team.raccord") -- lot PD-ELEC (D05) : machines sans courant hors poteau perdu, raccordement

Build.RADIUS = 3              -- carré de lots évalué au départ (7 × 7)
Build.RADIUS_MAX = 5
Build.RADIUS_ORE = Tr.CAP    -- lot INDUSTRIE I3 : rayon au plus de la croissance VERS UN GISEMENT (12 : 25 × 25 lots) ; la croissance ordinaire reste à RADIUS_MAX
Build.TREILLIS_LOGS = 40     -- lot INDUSTRIE I3 : lignes [FO-TREILLIS] au plus, par équipe
P.declare_size(T.wall, 1, 1)  -- lot ESPACE : emprise du mur, connue dès le chargement (les PNJ la lisent avant tout plan)
Build.PULSE = 5               -- ticks entre deux passes de travail
Build.NET_WAIT_TICKS = 1800   -- lot PLANDIR : attente (30 s) entre deux essais d'un projet dont le réseau passe par un projet pas bâti
Build.NET_WAIT_MAX = 40       -- au plus 40 essais (20 min) avant le refus
Build.EVAL_PER_PULSE = 4
Build.GHOSTS_PER_PULSE = 6
Build.REVIVE_PER_THINK = 6    -- ravivages par pensée d'un PNJ (pensée toutes les 60 ticks)
Build.CLEAR_PER_THINK = 3
Build.COST_EVAL = 30          -- unités de jetons (estimées ; E122 : un poteau ravivé 200 à 420 µs)
Build.COST_GHOST = 50
Build.COST_REVIVE = 50
Build.COST_REVIVE_POLE = 300
Build.COST_PLAN = 200
Build.QUAI_LOW = 60
Build.QUAI_FILL = 400
Build.COLLECT_AT = 200
Build.PRIO = 55
-- Étape 1 / électrification (27/10 au soir, banc etape1-guide, Azure : matière du module de fonderie réunie à 38 min, puis
-- 72 obstacles défrichés par 4 PNJ au plus à la priorité 59, sous les packs (85), les kits et les chargeurs (70 à 85) : le
-- module n'a fini qu'à 46 min) : une tâche de chantier n'existe qu'une fois la matière du projet RÉUNIE (état défrichage,
-- fantômes ou chantier) ; elle termine un investissement déjà payé et passe devant la fabrication d'avance.
Build.FINISH_BONUS = 30
Build.FINISH_CAP = 89         -- … sans jamais atteindre l'urgence (90 : O.URGENT_PRIO, M.URGENT)
local function finish_prio(base) return math.min(base + Build.FINISH_BONUS, Build.FINISH_CAP) end
Build.FAIL_LIMIT = 3          -- §6.6 (4) : un fantôme refusé 3 fois bloque son module (raison écrite)
Build.REFUSAL_LOGS = 40       -- refus de fantôme écrits au journal (emprise et occupants), au plus, par équipe
Build.NPC_BLOCKS_PER_FAIL = 5  -- un PNJ debout sur l'emprise est passager : 5 refus de ce genre comptent pour 1 échec
Build.RETRY_TICKS = 7200       -- un projet bloqué rend ses PNJ et reprend 2 min plus tard (au plus Build.RETRIES fois)
Build.RETRIES = 3
Build.ANCHOR_SEARCH = 6        -- rayon (tuiles) de la recherche d'une tuile libre pour un point d'appui
Build.OBST_CHECKS = 8          -- obstacles revus par passe (défrichage et chantier), à tour de rôle
Build.CUT_WIDTH = 1.5          -- demi-largeur (tuiles) du couloir qu'un défricheur arrêté s'ouvre vers son point d'appui
Build.CUT_TRIES = 6            -- marches refaites après une coupe, par tâche
Build.SITES = {}               -- lot PETROLE : planificateurs de sites { [nom] = fn(f, surface, p, aides) } (script/ai3/petrole.lua)

local REACH = P.BUILD_DISTANCE
local PileRt = require("script.team.pile") -- lot FUITES-PILE : la porte de la pile (réserve des modules neufs, agrandissement, tapis)
Build.Ene = require("shared.team.energie_dabord") -- lot TV-ENERGIE (G41) : « la première expansion est l'énergie », règle pure ; champ de Build, pas une locale (bloc principal à 198 locales)
Build.Qd = require("shared.team.quai_debit") -- lot RESEAU-GRAPHE : bras du quai d'entrée choisi par le débit, n borné à ce que le quai porte (règle pure) ; champ de Build, pas une locale
Build.QUAI_CHEST = "iron-chest" -- coffre des quais et des sorties (pièce du plan, P.feeder) : un seul nom pour les relevés au moteur
Build.QUAI_PAR_DEBIT = true -- vrai : NOUVEAUX gabarits seulement (les projets déjà planifiés gardent leurs pièces) ; faux : le quai d'avant (un bras de base par voie)
Build.Colr = require("shared.team.collecte") -- lot COLLECTE : règle pure (états servis, voyage à vide) ; champ de Build, pas une locale (essai-0660 : bloc principal à 200 locales)
local Collecte = require("script.team.collecte") -- lot COLLECTE : coffres de sortie du champ collectés en urgence quand le fer manque
local Rr = require("shared.team.rebuild_rapide") -- lot REBUILD-RAPIDE : projet rouvert sans attendre toute sa matière, ordre, foreuse de secours
-- Lot EXPANSION-LOINTAINE : une bande de champ NEUVE part en chantier dès que chaque objet de son kit est réservé aux deux tiers (règle pure) ;
-- champ de Build, pas une locale (limite des 200 locales du bloc principal).
Build.Cp = require("shared.team.chantier_progressif")
-- Lot TOURELLE-JOURNAL : [FO-TOURELLE-RETIREE] (tourelles de l'équipe déplacées ou reprises). Champ de Build, pas une locale
-- (limite de 200 locales du bloc principal, relecture de la 0.6.59).
Build.Tj = require("script.team.tourelle_journal")
-- Lot ÉTAGE 5 : couloir d'accès réservé des avant-postes (règle pure). Champ de Build, pas une locale : le bloc principal de ce fichier est
-- à la limite de 200 locales de Lua 5.2 (fusion avec le lot PERIMETRE2).
Build.Co = require("shared.team.couloir")
-- Lot VIDEO L4 : quotas du gabarit (colle de shared/team/quotas.lua) ; champ de Build, même raison (199 locales sur 200).
Build.Quotas = require("script.team.quotas_glue")
Build.Agents = require("script.companion.registry") -- lot MESURE-MODULE : l'agent qui porte une tâche de coffre (indice réécrit)
Build.Sites = require("shared.team.sites_dedup") -- lot MESURE-MODULE : copies de coffres de p.quais / p.outs (champ de Build, pas une locale)
-- Lot REMPLISSAGE : cible des coffres d'entrée quand le stock est abondant (colle de shared/team/remplissage.lua) ; champ de Build, même raison.
Build.Rempl = require("script.team.remplissage_glue")
Build.Elec = require("script.team.electrique") -- lot RETROFIT : ère électrique datée (Elec.era), reliques thermiques démontées par le chantier d'une bande
-- Lot TV-VAPEUR : tampon de vapeur de la centrale (V36, colle de shared/team/vapeur_tampon.lua) et dégradation sous charge (V89, script/core/
-- charge.lua) ; champs de Build, pas des locales (199 locales sur 200).
Build.Vg = require("script.team.vapeur_glue")
Build.Cd = require("shared.team.champ_dedupe") -- lot COMBUSTIBLE-MIGRATION : tuiles retenues par le cadre d'un champ pour son réseau du charbon (champ de Build, pas une locale)
Build.Ct = require("script.team.charbon_tampon") -- lot COMBUSTIBLE-CENTRALE : tampon de charbon des avant-postes (levier a)
Build.FonderieBloc = require("script.team.fonderie_bloc") -- lot FONDERIE-BLOC : le coffre de charbon d'une fonderie de champ relié par un tapis au charbon ; champ de Build, pas une locale
Build.Piquage = require("script.team.piquage") -- lot PIQUAGE : entrée d'un bloc alimentée par le surplus d'un tapis existant ; champ de Build, pas une locale (build.lua est à 199 locales)
Build.Charge = require("script.core.charge")
Build.Rangee = require("script.team.rangee_dyn") -- lot RANGEES-ASM : rangée d'assembleurs dynamique (place entière, grandit sur place) ; champ de Build, pas une locale
-- Lot VIDEO L9 : lots de minerai réservés au minerai (colle de shared/team/lot_minerai.lua, interrupteur éteint par défaut) ; champ
-- de Build, même raison (199 locales sur 200).
Build.LotsMinerai = require("script.team.lots_minerai_glue")
-- Lot TV-REPLI (TODO_VIDEO C07) : repli de placement simple d'un module sans lot (colle de shared/team/repli_place.lua, réglage
-- fo-war-repli-place allumé par défaut) ; champ de Build, même raison (199 locales sur 200).
Build.Repli = require("script.team.repli_place")
-- Lot TV-ARCHI (V23) : quartiers et enveloppe d'avance (script/team/quartiers.lua) ; champ de Build, même raison (199 locales sur 200).
Build.Quartiers = require("script.team.quartiers")
Build.TrancheForeuses = require("script.team.foreuses_tranches") -- lot TRANCHES-FOREUSES : tracé pondéré du tapis des foreuses par tranches (champ de Build, même raison : 199 locales)
Build.Trav = require("script.team.traversee") -- lot TRAVERSEE : tapis qui enjambent les obstacles par des souterrains, gisements évités (champ de Build : bloc principal à 199 locales)
Build.Pur = require("script.team.purete") -- lot PURETE-TAPIS : garde-fou de pureté des tapis (aucun mélange d'objets), champ de Build pour la même raison
-- Lot RAPATRIEMENT (8/11) : lignes sortie lointaine -> tapis -> tampon (script/team/rapatriement.lua) ; champ de Build, même raison (199 locales sur 200).
Build.Rapatriement = require("script.team.rapatriement")
Build.RpPart = require("shared.team.rapatriement") -- lot CC-PRIO-LIGNES (F532) : part du coffre d'une ligne de rapatriement (champ de Build : 199 locales)
Build.Mall = require("script.team.mall") -- lot MALL (tranche 1) : secteur du mall choisi par le terrain et réservé, état S (docs/MALL.md) ; champ de Build, pas une locale
Build.Place = require("script.team.place_glue") -- lot TV-PLACE : sonde 30 x 30 (G37), défrichage préventif 50 x 50 (G38), repli de placement simple (C07)
Build.Hygiene = require("script.team.hygiene") -- lot SCAN-TRANCHES (DC 9/11) : audit électrique en lecture seule par impulsions (s'abonne lui-même à on_tick) ; champ de Build, pas une locale (199 locales)
local TREE_TYPES = { "tree", "simple-entity" }


---------------------------------------------------------------------------------------------------
-- Outils
---------------------------------------------------------------------------------------------------
local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b)
    if type(a) == type(b) then return a < b end
    return type(a) == "number"
  end)
  return ks
end

local function bump(t, k, n) t[k] = (t[k] or 0) + (n or 1) end

local function dist2(a, b) local dx, dy = a.x - b.x, a.y - b.y; return dx * dx + dy * dy end

--- Objet qui pose une entité (prototype du jeu ; mémoire locale, jamais dans global).
local item_of
do
local ITEM_OF = {}
function item_of(name)
  local it = ITEM_OF[name]
  if it == nil then
    local p = game.entity_prototypes[name]
    local list = p and p.items_to_place_this
    it = (list and list[1] and list[1].name) or false
    ITEM_OF[name] = it
  end
  return it or nil
end
end -- do

local function team_of_key(key)
  if key == "player" then return State.faction("player") end
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and (f.key == key or id == key) then return f end
  end
  return nil
end

local function surface_of(f)
  return f.hq and f.hq.valid and f.hq.surface or nil
end

local strict
do
local Foot = require("shared.levels.footprint") -- DEFAUTS-REVELES : locale du seul strict
function strict(b, x0, y0, x1, y1)
  return Foot.overlap({ x0 = x0, y0 = y0, x1 = x1, y1 = y1 },
    { x0 = b.left_top.x, y0 = b.left_top.y, x1 = b.right_bottom.x, y1 = b.right_bottom.y })
end
end -- do

---------------------------------------------------------------------------------------------------
-- État
---------------------------------------------------------------------------------------------------
local function new_stats()
  return {
    lots = {}, lots_refused = {}, segs = {}, segs_closed = {}, plan_refused = {}, evals = 0,
    ghosts = 0, ghost_refused = 0, revived = 0, revive_fail = 0, cleared = 0, filled = 0, collected = 0,
    street_walks = 0, street_ok = 0, street_stuck = 0, minutes = {}, minute_cur = nil,
    modules_started = 0, modules_done = 0, projects_done = 0, projects_refused = 0, projects_blocked = 0,
  }
end

--- Active le plan directeur d'une équipe (idempotent). opts : seul (le banc retire les tâches libres de l'ancien
--- planificateur), ghosts_ahead (fantômes posés d'avance ; votre équipe : non par défaut, F176), radius.
function Build.enable(f, opts)
  if not (f and f.hq and f.hq.valid) then return nil end
  opts = opts or {}
  local b = f.build
  if not b then
    b = {
      lat = P.lattice(f.hq_pos), radius = 0, lots = {}, segs = {}, queue = {}, qhead = 1,
      projects = {}, order = {}, next_id = 1, occ = {}, net = {}, plant = nil,
      opts = { seul = false, ghosts_ahead = not f.is_player }, stats = new_stats(),
    }
    f.build = b
  end
  for _, k in ipairs({ "seul", "ghosts_ahead" }) do if opts[k] ~= nil then b.opts[k] = opts[k] and true or false end end
  Build.grow(f, opts.radius or Build.RADIUS)
  return b
end

--- Élargit le carré évalué au rayon r (nouveaux lots et tronçons mis en file, du centre vers l'extérieur). `cap` : plafond du rayon
--- (Build.RADIUS_MAX par défaut, la croissance ordinaire ; Build.RADIUS_ORE pour une croissance vers un gisement, lot INDUSTRIE I3).
function Build.grow(f, r, cap)
  local b = f.build
  if not Rsv.on() then cap = nil end -- réglage maître éteint : la croissance ordinaire seulement
  r = math.min(r, cap or Build.RADIUS_MAX) -- lot INDUSTRIE I3 : `cap` = Build.RADIUS_ORE pour une croissance vers un gisement connu
  -- lot ESPACE : le rayon est figé par l'enceinte (un lot posé après l'anneau serait dehors, ou l'anneau couperait un lot)
  -- Lot C3 EXTENSION : sauf enceinte COMPLÈTE à contour serré (Build.beyond_wall) : les lots au-delà sont des îlots
  if b.enc and not Build.beyond_wall(b) then r = math.min(r, b.enc.r) end
  if r <= b.radius then return end
  for _, l in ipairs(P.lots_within(r)) do
    local k = P.lot_key(l.i, l.j)
    if not b.lots[k] then
      b.lots[k] = { i = l.i, j = l.j, state = "inconnu" }
      b.queue[#b.queue + 1] = { "lot", k }
    end
  end
  for _, key in ipairs(P.segs_within(r)) do
    if not b.segs[key] then
      b.segs[key] = { state = "inconnu" }
      b.seg_ver = (b.seg_ver or 0) + 1
      b.queue[#b.queue + 1] = { "seg", key }
    end
  end
  b.radius = r
end

--- Lot C3 EXTENSION (audit n°11, PLAN I8/D4) : le treillis peut-il grandir au-delà du mur ? Oui quand l'enceinte est COMPLÈTE et a son
--- contour serré (shared/team/ilots_croissance.lua, Ic.open) et que le réglage maître est allumé ; éteint, le rayon reste figé comme avant.
function Build.beyond_wall(b)
  return b.enc ~= nil and Ic.open(b.enc) and Rsv.on()
end

--- Lot ESPACE : le treillis peut-il encore grandir ? (rayon maximal ou enceinte : non). Les replans qui attendent une
--- croissance s'y réfèrent, sinon ils attendraient pour toujours un rayon figé.
function Build.can_grow(b) return b.radius < Build.RADIUS_MAX and (not b.enc or Build.beyond_wall(b)) end

local function seg_ok(b) return function(key) local s = b.segs[key]; return s ~= nil and s.state == "ouvert" end end
local function seg_passable(b) return function(key) local s = b.segs[key]; return s ~= nil and s.state ~= "ferme" and s.state ~= "inconnu" end end
--- Tronçon que des fils peuvent suivre : connu, et fermé au plus par une falaise ou nos bâtiments (pas l'eau : le
--- carrefour peut y tomber ; ni nid, ni force rivale).
local function seg_wire(b) return function(key)
  local s = b.segs[key]
  if s == nil or s.state == "inconnu" then return false end
  return s.state ~= "ferme" or s.reason == "falaise" or s.reason == "batiments"
end end

---------------------------------------------------------------------------------------------------
-- Évaluation d'un lot ou d'un tronçon : 3 appels du moteur, aucune entité posée
---------------------------------------------------------------------------------------------------
Build.WALKABLE_OWN = { ["transport-belt"] = true, ["underground-belt"] = true, ["splitter"] = true, ["electric-pole"] = true }

local function survey(surface, force, x0, y0, x1, y1, seg)
  local area = { { x0, y0 }, { x1, y1 } }
  local s = { tiles = (x1 - x0) * (y1 - y0), water = 0, cliffs = 0, trees = 0, rocks = 0, foreign = 0, own = 0, nests = 0, res = {} }
  s.water = surface.count_tiles_filtered({ area = area, collision_mask = "water-tile" })
  for _, e in ipairs(surface.find_entities_filtered({ area = area, collision_mask = "object-layer" })) do
    if strict(e.bounding_box, x0, y0, x1, y1) then
      local t = e.type
      local fn = e.force.name
      if t == "tree" then s.trees = s.trees + 1
      elseif t == "cliff" then s.cliffs = s.cliffs + 1
      elseif t == "simple-entity" then s.rocks = s.rocks + 1
      elseif t == "unit-spawner" or (t == "turret" and fn == "enemy") then s.nests = s.nests + 1
      elseif fn == force then
        -- un tronçon de rue reste praticable sous nos tapis et nos poteaux (correction du 27/10 : 9 rues « fermées
        -- par nos bâtiments » après défrichage au banc ia1-build-foret)
        if not (seg and Build.WALKABLE_OWN[t]) then s.own = s.own + 1 end
      elseif fn == "neutral" then s.rocks = s.rocks + 1
      elseif fn ~= "enemy" then s.foreign = s.foreign + 1 end
    end
  end
  for _, e in ipairs(surface.find_entities_filtered({ area = { { x0 + 0.01, y0 + 0.01 }, { x1 - 0.01, y1 - 0.01 } }, type = "resource" })) do
    bump(s.res, e.name)
    Build.LotsMinerai.amount(s, e, seg) -- lot VIDEO MINERAI-SONDE : la quantité de minerai du lot (seuils par ressource et somme, G42, G43)
  end
  return s
end

--- Rectangle (x0, y0, x1, y1) d'une entrée de la file d'évaluation : lot ou tronçon.
local function item_rect(b, item)
  if item[1] == "lot" then
    local l = b.lots[item[2]]
    if not l then return nil end
    return P.lot_rect(b.lat, l.i, l.j)
  end
  return P.seg_rect(b.lat, item[2])
end

--- Lot INDUSTRIE I3 : un lot ou un tronçon AU-DELÀ du rayon ordinaire (RADIUS_MAX) n'est relevé que si tous ses chunks sont
--- générés : sur un chunk vide le relevé ne voit ni eau ni falaise et rend « libre » (un plan y poserait ses fantômes). Il est
--- remis à plus tard (b.ungen, repris par ungen_retry) ; en deçà du rayon ordinaire, rien ne change.
local function ungenerated(b, surface, item, x0, y0, x1, y1)
  if Tr.ring_of_point(b.lat.ox, b.lat.oy, (x0 + x1) / 2, (y0 + y1) / 2, P.PITCH) <= Build.RADIUS_MAX then return false end
  for _, c in ipairs(Tr.chunks(x0, y0, x1, y1)) do
    if not surface.is_chunk_generated(c) then
      b.ungen = b.ungen or {}
      b.ungen[#b.ungen + 1] = item
      b.stats.ungen_deferred = (b.stats.ungen_deferred or 0) + 1
      return true
    end
  end
  return false
end

--- Rend à la file les entrées dont tous les chunks sont maintenant générés (sans jetons : un appel par chunk). Intégration 0.6.30 : le premier
--- chunk manquant de chaque entrée est DEMANDÉ au moteur, Tr.GEN_PER_RETRY au plus par essai : sinon rien ne garantit que le couloir d'un
--- gisement lointain se génère un jour (le banc ind-treillis-gen le forçait), et ses rues restent inconnues, donc fermées au plan.
local function ungen_retry(f, surface, tick)
  local b = f.build
  if not (b.ungen and #b.ungen > 0) or tick < (b.ungen_next or 0) then return end
  b.ungen_next = tick + Tr.RETRY_UNGEN
  local keep, back = {}, 0
  local asked, asked_n = {}, 0
  for _, item in ipairs(b.ungen) do
    local x0, y0, x1, y1 = item_rect(b, item)
    local ready = x0 ~= nil
    if ready then
      for _, c in ipairs(Tr.chunks(x0, y0, x1, y1)) do
        if not surface.is_chunk_generated(c) then
          ready = false
          local ck = c.x .. ":" .. c.y
          if not asked[ck] and asked_n < Tr.GEN_PER_RETRY then
            asked[ck], asked_n = true, asked_n + 1
            surface.request_to_generate_chunks({ c.x * Tr.CHUNK + 16, c.y * Tr.CHUNK + 16 }, 0)
          end
          break
        end
      end
    end
    if ready then
      b.queue[#b.queue + 1] = item
      back = back + 1
    elseif x0 ~= nil then
      keep[#keep + 1] = item
    end
  end
  b.ungen = keep
  if back > 0 then
    b.stats.ungen_back = (b.stats.ungen_back or 0) + back
    b.ungen_logs = (b.ungen_logs or 0) + 1
    if b.ungen_logs <= Build.TREILLIS_LOGS then
      log(string.format("[FO-TREILLIS] %s : %d lot(s)/troncon(s) lointain(s) dont les chunks sont generes rendus a l'evaluation, %d attendent encore (%.1f min)",
        f.key or "player", back, #keep, tick / 3600))
    end
  end
end

local function eval_one(f, surface, item, tick)
  local b = f.build
  local st = b.stats
  do
    local x0, y0, x1, y1 = item_rect(b, item)
    if x0 and ungenerated(b, surface, item, x0, y0, x1, y1) then return end
  end
  st.evals = st.evals + 1
  if item[1] == "lot" then
    local l = b.lots[item[2]]
    if not l or l.used then return end
    local x0, y0, x1, y1 = P.lot_rect(b.lat, l.i, l.j)
    local s = survey(surface, f.force, x0, y0, x1, y1)
    -- le lot du QG est toujours « occupé »
    if l.i == 0 and l.j == 0 then s.own = math.max(1, s.own) end
    local old = l.state
    l.state, l.reason = P.classify_lot(s, Build.LotsMinerai.seuils()) -- lot VIDEO MINERAI-SONDE : seuils par ressource lus en données (règle éteinte : nil, le seuil unique d'avant)
    -- Lot AUTO : un lot de GISEMENT qui porte déjà nos bâtiments (avant-poste à combustion posé sur le minerai par le
    -- cerveau) restait « occupe » : ses tuiles libres de minerai n'étaient plus proposées aux foreuses électriques
    -- (« tapis des foreuses (pas de lot) »). Il reste un gisement PARTAGÉ : P.fit n'y pose rien sur une tuile bâtie
    -- (masque `free`), la couverture de minerai (P.DRILL_COVER) se compte sur ce qui reste. Le lot du QG reste occupé.
    local ore, n_ore = P.main_resource(s)
    l.ore, l.ore_n = ore, n_ore
    if l.state == "occupe" and not (l.i == 0 and l.j == 0) and ore and n_ore >= P.MIN_RES_TILES then
      l.state, l.reason, l.shared = "gisement", ore, true
    end
    l.res = (l.state == "gisement") and l.reason or nil
    l.water, l.trees, l.rocks, l.tick = s.water, s.trees + s.rocks, s.rocks, tick
    Build.Place.evaluated(f, surface, tick, item[2], l, s, x0, y0, x1, y1, old, Build.LotsMinerai.amount, Build.LotsMinerai.seuils()) -- lot TV-PLACE (G37) : sonde de 30 x 30, lot en bord de gisement ; résultat du défrichage préventif
    Build.LotsMinerai.evaluated(f, tick, item[2], l, s, old) -- lot VIDEO MINERAI-SONDE : le lot de minerai neuf est RESERVE tout de suite (même en crise) ; un nid neuf est un ennemi vu
    if old == "inconnu" then
      bump(st.lots, l.state)
      if l.state == "refuse" then bump(st.lots_refused, l.reason) end
    end
  else
    local g = b.segs[item[2]]
    local x0, y0, x1, y1 = P.seg_rect(b.lat, item[2])
    local s = survey(surface, f.force, x0, y0, x1, y1, true)
    local old = g.state
    g.state, g.reason = P.classify_segment(s)
    Build.LotsMinerai.seg_changed(f, tick, old, g.state) -- lot VIDEO MINERAI-SONDE : une rue qui se ferme (porte) fait refaire le relevé des lots
    g.trees, g.tick = s.trees + s.rocks, tick
    if g.state ~= old then b.seg_ver = (b.seg_ver or 0) + 1 end
    if old == "inconnu" then
      bump(st.segs, g.state)
      if g.state == "ferme" then bump(st.segs_closed, g.reason) end
    elseif old == "encombre" and g.state == "ouvert" then
      bump(st.segs, "defriche")
    end
  end
end

--- Masques d'un rectangle lus au moteur (une fois par plan) : eau, bloqué (bâtiments, falaises, nids : non
--- défrichable), obstacles défrichables (arbres, rochers) ; plus les tuiles réservées par nos projets.
-- Lot MIGRATION-CHAMP : tuiles d'une partie de champ que le plan compte comme LIBRES le temps de planifier le projet qui la remplace
-- (liste plate { tx, ty, ... } de spec.degel.tiles ; mémoire LOCALE posée autour de plan_project, jamais dans global).
local THAW = nil

--- Lot ÉTAGE 5 : tuiles des couloirs d'accès des avant-postes de l'équipe `f` (shared/team/couloir.lua), ensemble { [P.tkey] = id d'avant-poste }.
--- Lecteurs : read_masks (free : foreuses et poteaux du plan ; les tapis traversent, un tapis ne bloque pas un personnage), la vue des poteaux
--- (masques_view), Build.reserved_entity (agrandissements et tourelles, crochet PlacesQG.reserved ; remplacements de foreuse) et le masque de la
--- migration du champ électrique (script/team/champ.lua). Cache LOCAL (jamais dans global, vide à chaque chargement), refait quand un accès ou
--- le QG change : il ne dépend que de l'état. Règle coupée (f.team.couloir_off, bancs témoins) : ensemble vide.
--- Revue (performance) : un seul relevé par tick et par équipe (c.tick == game.tick) ; Build.couloirs_reset(f) l'efface quand un accès est
--- écrit (worker.lua ACTS.build, banc bench_outpost) : un agrandissement dans le même tick voit déjà le couloir. Build.couloir_stats.sig : relevés
--- de signature faits (tests).
Build._couloirs = {}  -- cache LOCAL au module (champ : limite des 200 locales)
Build.NO_COULOIR = {} -- ensemble vide partagé : ne jamais écrire dedans
Build.couloir_stats = { sig = 0 }
function Build.couloirs(f)
  if not (f and f.hq_pos and f.outposts) or (f.team and f.team.couloir_off) then return Build.NO_COULOIR end
  local k = tostring(f.key or f.id)
  local c = Build._couloirs[k]
  local now = game and game.tick or 0
  if c and c.tick == now then return c.set end
  Build.couloir_stats.sig = Build.couloir_stats.sig + 1
  local sig = { math.floor(f.hq_pos.x), math.floor(f.hq_pos.y) }
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local a = f.outposts[oid].access
    if a then sig[#sig + 1] = tostring(oid) .. ":" .. math.floor(a.x) .. ":" .. math.floor(a.y) end
  end
  local s = table.concat(sig, ";")
  if c and c.sig == s then
    c.tick = now
    return c.set
  end
  local set, n = {}, 0
  for _, t in ipairs(Build.Co.team_tiles(f.outposts, f.hq_pos)) do
    set[P.tkey(t.x, t.y)] = t.id
    n = n + 1
  end
  Build._couloirs[k] = { sig = s, set = set, tick = now, n = n }
  return set
end

function Build.couloirs_reset(f)
  if f then Build._couloirs[tostring(f.key or f.id)] = nil end
end

--- Revue (B3) : place prise par les couloirs, au journal [FO-COULOIR] une fois par tranche de 10 min et par équipe (appelé par Team.think, pour
--- toutes les équipes) : refus par un couloir comptés en APPELS (une même place peut être lue plusieurs fois : free() par tuile et par essai,
--- place_pairs jusqu'à 8 appels par place) : lectures d'emprise refusées (agrandissements, tourelles, remplacements de foreuse), lectures de
--- tuile refusées au plan (modules, poteaux), tuiles de couloir marquées dans le masque de la migration du champ.
Build.COULOIR_REPORT = 10 * 3600
function Build.couloir_report(f, tick)
  local st = f.stats
  if not st then return end
  local slot = math.floor(tick / Build.COULOIR_REPORT)
  if st.couloir_slot == slot then return end
  local first = st.couloir_slot == nil
  st.couloir_slot = slot
  if first then return end
  Build.couloirs(f) -- relevé à jour (une équipe sans lecteur dans la tranche n'en a pas)
  local c = Build._couloirs[tostring(f.key or f.id)]
  log(string.format("[FO-COULOIR] %s : bilan a %.0f min : %d tuile(s) de couloir ; refus par un couloir, en APPELS (une place peut etre lue "
    .. "plusieurs fois) : %d appel(s) d'emprise (agrandissements, tourelles, foreuses), %d appel(s) de tuile du plan (modules, poteaux), "
    .. "%d marque(s) au masque du champ", f.key or "player", tick / 3600, c and c.n or 0,
    st.couloir_emprises or 0, st.couloir_tuiles or 0, st.couloir_champ or 0))
end

local function read_masks(f, surface, x0, y0, x1, y1)
  local b = f.build
  local water, blocked, clear, res = {}, {}, {}, {}
  for _, t in ipairs(surface.find_tiles_filtered({ area = { { x0, y0 }, { x1, y1 } }, collision_mask = "water-tile" })) do
    water[P.tkey(math.floor(t.position.x), math.floor(t.position.y))] = true
  end
  -- lot DECOUPLAGE : tuiles de toutes les ressources (P.fit : une BOX_FONDERIE n'en couvre aucune, shared/team/sol_minerai.lua)
  for _, e in ipairs(surface.find_entities_filtered({ area = { { x0, y0 }, { x1, y1 } }, type = "resource" })) do
    res[P.tkey(math.floor(e.position.x), math.floor(e.position.y))] = true
  end
  for _, e in ipairs(surface.find_entities_filtered({ area = { { x0, y0 }, { x1, y1 } }, collision_mask = "object-layer" })) do
    local bb = e.bounding_box
    local tx0, ty0 = math.floor(bb.left_top.x + 0.01), math.floor(bb.left_top.y + 0.01)
    local tx1, ty1 = math.ceil(bb.right_bottom.x - 0.01) - 1, math.ceil(bb.right_bottom.y - 0.01) - 1
    local soft = e.type == "tree" or e.type == "simple-entity" or (e.force.name == "neutral" and e.type ~= "cliff")
    for ty = ty0, ty1 do
      for tx = tx0, tx1 do
        local k = P.tkey(tx, ty)
        if soft then clear[k] = true else blocked[k] = true end
      end
    end
  end
  -- lot OBSTACLES : `bounding_box` d'une falaise TOURNÉE (coin, entrée) est la petite boîte alignée du rectangle tourné, alors que sa collision réelle suit
  -- son orientation (jusqu'à 4 × 3 tuiles, coins tournés). Mesuré sur 4 parties sur 4 : un tapis planifié à 1,5 tuile du centre d'une
  -- falaise était refusé « occupe », projet bloqué puis abandonné après 3 reprises au même plan (F294, shared/team/falaise.lua). Les
  -- tuiles réelles sont bloquées, avec celles que le moteur a déjà refusées (mémoire b.hard, apprise par learn_cliff).
  Fal.mark(surface, x0, y0, x1, y1, function(tx, ty) blocked[P.tkey(tx, ty)] = true end)
  if b.hard and b.hard.t then
    for k in pairs(b.hard.t) do blocked[k] = true end -- union d'un ensemble : l'ordre n'a aucun effet
  end
  if THAW then
    for i = 1, #THAW - 1, 2 do blocked[P.tkey(THAW[i], THAW[i + 1])] = nil end
  end
  local cor = Build.couloirs(f) -- lot ÉTAGE 5 : ni module ni poteau sur un couloir d'accès (les tapis, par `blocked`, le traversent)
  f.stats = f.stats or {}
  local st = f.stats
  return {
    water = water, blocked = blocked, clear = clear, res = res,
    rect = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }, -- lot POTEAUX-MASQUES : où ce relevé fait foi (Mq.view)
    free = function(tx, ty)
      local k = P.tkey(tx, ty)
      if water[k] or blocked[k] or b.occ[k] then return false end
      if cor[k] then
        st.couloir_tuiles = (st.couloir_tuiles or 0) + 1 -- revue (B3) : place perdue par le plan
        return false
      end
      return true
    end,
  }
end

--- Lot POTEAUX-MASQUES : cache LOCAL (jamais dans global, vide à chaque chargement) des relevés par chunk, par surface.
--- Écrit par masques_view, invalidé par finish_project (Mq.invalidate) et par la péremption (Mq.TTL) ; lu par masques_view seul.
local MASQ = {}
local function masq_cache(surface)
  local c = MASQ[surface.index]
  if not c then c = Mq.new(); MASQ[surface.index] = c end
  return c
end

--- Relevé d'un chunk entier au moteur (même lecture que read_masks, donc mêmes règles : eau, bloqué, défrichable).
local function chunk_reader(f, surface)
  return function(cx, cy)
    local x0, y0 = cx * Mq.CHUNK, cy * Mq.CHUNK
    local m = read_masks(f, surface, x0, y0, x0 + Mq.CHUNK, y0 + Mq.CHUNK)
    return { water = m.water, blocked = m.blocked, clear = m.clear }
  end
end

--- Lot POTEAUX-MASQUES : vue des masques sur le couloir des `legs` ({ a, b } à relier par P.pole_chain). Rend la vue, ou nil si
--- l'accord de cet essai (p.masq_n + 1 fois Mq.BUDGET chunks) ne couvre pas tout le couloir : plan_power rend alors le projet
--- en attente (« masques ») et l'essai suivant accorde Mq.BUDGET chunks de plus. L'accord ne dépend que de p (sauvegardé) :
--- jamais du contenu du cache.
local function masques_view(f, surface, p, masks, legs, reach)
  local b = f.build
  local list, total = Mq.corridor(legs, Mq.margin(reach))
  local attempt = (p.masq_n or 0) + 1
  local granted = Mq.grant(attempt, #list)
  local ready, reads, hits = Mq.ensure(masq_cache(surface), list, granted, game.tick, chunk_reader(f, surface))
  local complete = granted >= #list
  if not complete or attempt > 1 then
    p.masq_logged = (p.masq_logged or 0) + 1
    if p.masq_logged <= 6 then
      log(string.format("[FO-MASQUES] %s : projet %d, couloir de %d chunk(s)%s, essai %d : %d accorde(s) (budget %d), %d lu(s) au moteur, %d en cache%s",
        f.key or "player", p.id, #list, total > #list and (" sur " .. total .. " (plafond " .. Mq.MAX_CHUNKS .. ")") or "", attempt, math.min(granted, #list),
        Mq.BUDGET, reads, hits, complete and " : couloir complet" or " : le projet attend la suite"))
    end
  end
  if not complete then return nil end
  local cor = Build.couloirs(f) -- lot ÉTAGE 5 : les poteaux lus dans le cache des chunks évitent aussi les couloirs d'accès
  return Mq.view(masks, masks.rect, ready, P.tkey, function(tx, ty)
    local k = P.tkey(tx, ty)
    return not b.occ[k] and not cor[k]
  end)
end

---------------------------------------------------------------------------------------------------
-- Projets : demande (interface du cerveau)
---------------------------------------------------------------------------------------------------
--[[
  Build.request(f, spec) -> id, ou nil et raison. spec :
    gen, args     générateur de shared/team/modules.lua et ses paramètres (ou key = gabarit du catalogue) ;
    rate          débit visé en objets/min du produit principal (dimensionne l'extension du gabarit) ;
    resource      ressource exploitée (foreuses) ;
    feed          true : têtes d'alimentation (tapis depuis des foreuses quand une voie dépasse 60/min et qu'un
                  gisement est à portée, sinon quai), quais de sortie ;
    near          {x, y} : la zone préférée (sinon le QG ou le gisement de l'entrée principale) ;
    prio          priorité des tâches (défaut 55) ; domain : domaine des tâches (défaut production).
  Le module électrique demande la centrale (une par équipe, créée au besoin sur la rive la plus proche).
]]
function Build.request(f, spec)
  local b = f.build or Build.enable(f, {})
  if not b then return nil, "equipe" end
  if type(spec) ~= "table" then return nil, "spec" end
  -- lot TV-ENERGIE (G41) : la première expansion d'une équipe sans centrale fait demander la centrale D'ABORD (règle pure Build.Ene.decide) ;
  -- Build.plant la place en tête de file, la demande est enregistrée derrière elle
  local must = Build.Ene.decide(spec, { plant = b.plant, off = b.opts and b.opts.no_energie_dabord == true })
  if must then
    local pid = Build.plant(f, spec.pole)
    b.energie_dabord = (b.energie_dabord or 0) + 1
    if pid and b.energie_dabord == 1 then log(Build.Ene.line(f.key or "player", game.tick, spec, pid)) end
  end
  local id = b.next_id
  b.next_id = id + 1
  local p = {
    id = id, spec = spec, state = "attente", created = game.tick, reason = nil,
    parts = {}, ents = {}, wires = {}, stock = {}, quais = {}, outs = {}, obstacles = {}, fails = 0,
    prio = spec.prio or Build.PRIO, domain = spec.domain or "production",
  }
  b.projects[id] = p
  b.order[#b.order + 1] = id
  if spec.gen == "steam" and not b.plant then b.plant = id end
  return id
end

--- Lot AGENCEMENT : le gabarit `g` refait avec `n` pour paramètre d'extension (au poteau du gabarit, sinon au poteau par
--- défaut quand le poteau court ne couvre plus ni ne relie l'extension, lot PLANDIR) ; `g` tel quel si l'extension est refusée.
local function extend_to(g, n)
  local g2 = M.extend(g, n)
  -- lot PLANDIR : l'extension qui ne passe pas avec un poteau court (ni couverture, ni fils) est refaite au poteau par défaut
  if g2 and g.pole_name ~= M.DEFAULT_POLE and #M.check(g2) > 0 then g2 = M.regenerate(g, { [g.extensions[1].arg] = n }, M.DEFAULT_POLE) end
  return g2 or g
end

--- Gabarit d'une demande, dimensionné au débit : (gabarit) ou (nil, raison). `opts` (lot AGENCEMENT) : sortie = "exterieur"
--- (la fonderie à tapis finit côté tête, ses coffres vers l'extérieur) ; grow(g, n) -> n' : taille de la ligne décidée APRÈS
--- celle du débit (la fonderie suit le gisement et le minerai livré, line_rows).
local function template_of(spec, opts)
  local g, why
  if spec.gen then
    local fn = M.GEN[spec.gen]
    if not fn then return nil, "generateur inconnu" end
    local args = spec.args or {}
    if opts and opts.sortie == "exterieur" and spec.gen == "smelter" then
      args = { args[1], args[2], args[3], "exterieur" }
    end
    -- lot RECHERCHE-BRAS : spec.arms = les bras OBTENABLES de la demande (nil : tous) ; le gabarit tourne alors à la cadence qu'ils tiennent
    g, why = M.with_arms(spec.arms, M.with_pole, spec.pole, fn, table.unpack(args))
    -- lot PLANDIR : un poteau plus court qui ne couvre pas le gabarit cède au poteau par défaut
    if spec.pole and spec.pole ~= M.DEFAULT_POLE and (not g or #M.check(g) > 0) then g, why = M.with_arms(spec.arms, fn, table.unpack(args)) end
    if not g and spec.arms then g, why = M.with_pole(spec.pole, fn, table.unpack(args)) end -- bras trop lents : tous les bras, comme avant
  elseif spec.key then
    g = M.get_any(spec.key)
    if not g then why = "gabarit inconnu" end
  end
  if not g then return nil, why end
  if spec.rate and g.extensions and g.extensions[1] and g.nominal then
    local want = spec.rate / 60
    local main
    for _, k in ipairs(sorted_keys(g.nominal)) do if k ~= "electricity-kw" then main = main or k end end
    if main and g.nominal[main] and g.nominal[main] > 0 then
      local ex = g.extensions[1]
      local cur = g.args[ex.arg]
      local n = math.max(1, math.min(ex.max, math.ceil(cur * want / g.nominal[main] - 1e-9)))
      if n ~= cur then g = extend_to(g, n) end
    end
  end
  if opts and opts.grow and g.extensions and g.extensions[1] then
    local ex = g.extensions[1]
    local cur = g.args[ex.arg]
    local n = opts.grow(g, cur)
    if type(n) == "number" and n ~= cur and n >= 1 and n <= ex.max then g = extend_to(g, n) end
  end
  return g
end

local function lot_center(b, l)
  local x0, y0, x1, y1 = P.lot_rect(b.lat, l.i, l.j)
  return { x = (x0 + x1) / 2, y = (y0 + y1) / 2 }
end

--- Lots candidats d'une sorte, triés par distance à `toward` (puis i, j).
Build.AVOID_MARGIN = 8 -- tuiles ajoutées au rayon d'un site écarté (le lot fait 32 tuiles de côté)
local REUSE_STATES = { defrichage = true, fantomes = true, chantier = true, raccordement = true, fini = true } -- projets dont les poteaux existent ou vont exister

--- Lot ENERGIE-CROISSANCE : numéro du projet `pid` si c'est une centrale à vapeur FINIE (sa rive peut en recevoir une autre), sinon nil.
--- (relecture : une centrale ABANDONNÉE par la santé du réseau, site jugé dangereux, ne prête pas sa rive : b.avoid ne garde que
--- 6 sites, le sien peut en être sorti)
local function plant_owner(b, pid)
  local p = b.projects[pid]
  if p and p.state == "fini" and not p.abandoned and p.parts and p.parts[1] and p.parts[1].kind == "centrale" then return pid end
  return nil
end

--- Lot MALL-PAVAGE (directive du DC du 9/11 : « éradiquer l'espacement mort », un bloc par lot de 24 à pas 28 = 17 à 20 tuiles de vide) :
--- numéro du projet `pid` si c'est un bloc ou une cellule de mall (gen « bloc » ou « patron ») vivant, posé dans un lot du treillis :
--- son lot en reçoit un autre, collé à lui (Build.Pave.pin, Mp.pave_origin), sinon nil.
--- (Sous Build.Pave, sans locale nouvelle : le chunk principal de ce fichier est à la limite des 200 locales de Lua 5.2.)
Build.Pave = { Mp = require("shared.team.mall_paving"), Sd = require("shared.team.serie_dirs"), GEN = { bloc = true, patron = true, ruban = true } } -- (ruban : lot MALL-RUE ; Sd : lot MALL-DIRECTIONS)
function Build.Pave.owner(b, pid)
  local p = b.projects[pid]
  if p and not p.abandoned and p.spec and Build.Pave.GEN[p.spec.gen] and p.parts and p.parts[1] and p.parts[1].kind == "module" then return pid end
  return nil
end

--- Emprise, dans le lot `k` (rect), de tout ce que les projets vivants y ont planifié (modules, têtes, quais) : { x0, y0, x1, y1 }
--- (x1, y1 exclus) ou nil, et rotation du premier module du lot. Projets parcourus par numéro croissant (une union : l'ordre est sans effet).
function Build.Pave.box(b, k, rect)
  local box, kk
  for _, pid in ipairs(sorted_keys(b.projects)) do
    local p = b.projects[pid]
    if not p.abandoned and p.parts and p.parts[1] and p.parts[1].lot == k then
      kk = kk or p.parts[1].k or 0
      for _, e in ipairs(p.ents or {}) do
        for _, t in ipairs(P.tiles_of(e)) do
          if t[1] >= rect.x0 and t[1] < rect.x1 and t[2] >= rect.y0 and t[2] < rect.y1 then
            if not box then box = { x0 = t[1], y0 = t[2], x1 = t[1] + 1, y1 = t[2] + 1 }
            else
              box.x0, box.y0 = math.min(box.x0, t[1]), math.min(box.y0, t[2])
              box.x1, box.y1 = math.max(box.x1, t[1] + 1), math.max(box.y1, t[2] + 1)
            end
          end
        end
      end
    end
  end
  return box, kk or 0
end

--- Lot MALL-PAVAGE : épingle `fopts.within` à la place collée au bloc précédent du lot (Mp.pave_origin : à l'est, sinon au sud, à
--- Mp.GAP tuile), dans l'orientation du premier bloc ; les têtes du gabarit (P.port_room) ne mordent pas sur lui. Rend le gabarit
--- (P.fit n'a plus qu'une place à essayer), ou nil, raison (lot plein : le lot suivant prend).
function Build.Pave.pin(b, c, g, rect, fopts)
  local Mp = Build.Pave.Mp
  local prev, k = Build.Pave.box(b, c.k, rect)
  if not prev then return g end -- (rien de planifié dans le lot : P.fit cherche comme d'habitude)
  local r = (k == 0) and g or M.rotate(g, k)
  if not r then return nil, "pavage : gabarit non orientable" end
  local lead = { x0 = 0, y0 = 0, x1 = r.w, y1 = r.h }
  for _, t in ipairs(P.port_room(M.instantiate(r, 0, 0, 0), fopts.fan)) do
    lead.x0, lead.y0 = math.min(lead.x0, t[1]), math.min(lead.y0, t[2])
    lead.x1, lead.y1 = math.max(lead.x1, t[1] + 1), math.max(lead.y1, t[2] + 1)
  end
  -- lot MALL-DIRECTIONS : la section d'un ruban se colle DU CÔTÉ où sa série avance (orientation du premier bloc du lot) ; les blocs comme avant
  local o, why = Mp.pave_origin_dir(prev, { w = r.w, h = r.h, lead = lead }, rect, Mp.GAP, fopts.margin, g.gen == "ruban" and Build.Pave.Sd.dir_of(k) or nil)
  if not o then return nil, "pavage : " .. why end
  fopts.within = { x0 = o.x, y0 = o.y, x1 = o.x + r.w, y1 = o.y + r.h }
  fopts.rot = { k } -- (lot MALL-DIRECTIONS : la même orientation que le premier bloc du lot, pas sa retournée de même emprise)
  return g
end

--- Lot MALL-RUE (décision du DC, carte blanche : « si une extension de mall dépasse le lot et rencontre une rue de la grille de ville,
--- n'interromps pas la chaîne : enjambe la rue par des convoyeurs souterrains ») : le lot courant ne tient pas la section suivante du
--- RUBAN (gabarit « ruban », shared/team/patrons.lua §6 bis) : Mp.serie la pose de l'autre côté de la rue et le corridor la rejoint par
--- un souterrain par voie (type souterrain du palier débloqué et sa portée lus aux données : Build.Trav.underground). Champs sous
--- Build.Pave (le chunk principal est à la limite des 200 locales).
Build.Pave.LOGS = 40 -- lignes [FO-MALL] de série au plus par équipe (hors pose)

--- Journal borné de la série.
function Build.Pave.say(f, b, text)
  b.serie_logs = (b.serie_logs or 0) + 1
  if b.serie_logs <= Build.Pave.LOGS then log(string.format("[FO-MALL] %s : %s", f.key or "player", text)) end
end

--- Nom du tapis d'un gabarit (sa première entité de sorte « belt », M.spec), ou nil.
function Build.Pave.belt_of(g)
  for _, e in ipairs(g.entities or {}) do
    local sp = M.spec(e.name)
    if sp and sp.kind == "belt" then return e.name end
  end
  return nil
end

--- Dernière section de ruban de la famille `fam` (« ruban-<machine> ») dans le lot `k` : son corps p.parts[1] ({ ox, oy, w, h, k, key }), la plus
--- AVANCÉE dans le sens de sa série (lot MALL-DIRECTIONS : Sd.along selon l'orientation pt.k ; vers l'est, la plus à l'est), parmi les projets
--- vivants ; nil sans section. Projets parcourus par numéro croissant (la plus avancée gagne : l'ordre est sans effet).
function Build.Pave.last(b, k, fam)
  local Sd = Build.Pave.Sd
  local best, ba
  for _, pid in ipairs(sorted_keys(b.projects)) do
    local p = b.projects[pid]
    local pt = p and not p.abandoned and p.spec and p.spec.gen == "ruban" and p.parts and p.parts[1] or nil
    if pt and pt.lot == k and pt.kind == "module" and type(pt.key) == "string" and pt.key:sub(1, #fam + 1) == fam .. "-" then
      local a = Sd.along(pt.ox, pt.oy, Sd.dir_of(pt.k or 0))
      if not best or a > ba then best, ba = pt, a end
    end
  end
  return best
end

--- Numéro de la section d'un ruban (projets vivants « ruban » dont le lot est au nom de `owner`, celui-ci compris).
function Build.Pave.rank(b, owner)
  local n = 0
  for _, pid in ipairs(sorted_keys(b.projects)) do
    local p = b.projects[pid]
    local pt = p and not p.abandoned and p.spec and p.spec.gen == "ruban" and p.parts and p.parts[1] or nil
    if pt and b.lots[pt.lot] and b.lots[pt.lot].used == owner then n = n + 1 end
  end
  return n
end

--- La section suivante de l'autre côté de la rue : { k2, l2, rect2, within, trav = { res (Mp.serie), ug = { name, maxd }, belt }, owner } ou nil, raison.
--- « serie arretee : lot occupe » (gisement, centrale, autre module, hors du treillis) : la série s'arrête proprement, rien n'est démoli.
function Build.Pave.serie(f, b, c, g, states)
  local Mp, Sd = Build.Pave.Mp, Build.Pave.Sd
  if g.gen ~= "ruban" or type(g.ruban) ~= "table" then return nil, "serie : gabarit sans corridor" end
  local prev = Build.Pave.last(b, c.k, g.ruban.fam)
  if not prev then return nil, "serie : aucune section de ruban dans le lot " .. tostring(c.k) end
  -- lot MALL-DIRECTIONS : la série suit l'orientation de la section précédente (prev.k : est, sud, ouest ou nord) ; les lignes du corridor
  -- (décalages canoniques en y) suivent la rotation (Sd.cross) ; Mp.serie_dir pose la section suivante dans ce sens
  local k = prev.k or 0
  local gr = (k == 0) and g or M.rotate(g, k)
  if not gr or prev.w ~= gr.w or prev.h ~= gr.h then return nil, "serie : section precedente d'une autre forme" end
  local dir = Sd.dir_of(k)
  local belt = Build.Pave.belt_of(g)
  local ug = belt and Build.Trav.underground(f, belt) or nil
  if not ug then return nil, "serie : aucun souterrain debloque pour le tapis " .. tostring(belt) end
  local lots = { pitch = P.PITCH, lot = P.LOT, ox = b.lat.ox - P.HALF, oy = b.lat.oy - P.HALF }
  local belts = {}
  for i, off in ipairs(g.ruban.belts) do belts[i] = Sd.cross(off, k, g.h) end
  local res, why = Mp.serie_dir({ x = prev.ox, y = prev.oy, w = prev.w, h = prev.h, belts = belts },
    { { w = prev.w, h = prev.h }, { w = gr.w, h = gr.h } }, dir, lots, Mp.GAP, { w = P.STREET, underground_reach = ug.maxd })
  if not res then return nil, "serie : " .. why end
  local s2 = res.sections[2]
  local k2 = P.lot_key(s2.lot.i, s2.lot.j)
  if k2 == c.k then return nil, "serie : la section tient encore dans le lot (refus du placement)" end
  local l2 = b.lots[k2]
  if not l2 then return nil, "serie arretee : lot occupe (" .. k2 .. " hors du treillis)" end
  if (l2.used and l2.used ~= c.l.used) or not states[l2.state] or l2.out or (l2.bad or 0) >= 2 then
    return nil, string.format("serie arretee : lot occupe (%s : %s%s)", k2, tostring(l2.state), l2.used and (", projet " .. tostring(l2.used)) or "")
  end
  local x0, y0, x1, y1 = P.lot_rect(b.lat, l2.i, l2.j)
  local rect2 = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  if Build.Pave.box(b, k2, rect2) then return nil, "serie : lot suivant deja pave (" .. k2 .. ")" end
  return { k2 = k2, l2 = l2, rect2 = rect2, within = { x0 = s2.x, y0 = s2.y, x1 = s2.x + gr.w, y1 = s2.y + gr.h }, trav = { res = res, ug = ug, belt = belt },
    owner = c.l.used, k = k, dir = dir }
end

--- Essai de la section de l'autre côté de la rue : relevé du lot suivant (`scan(c2, rect2)` -> masks), passage du corridor libre (rallonge, entrée,
--- sortie : ni réservé, ni bâti), P.fit épinglé (within) sans tête sur le port servi par le souterrain (fed). Rend le placement (la forme de
--- place_module : lot = le lot suivant, pave = le ruban propriétaire, fed, serie) ou nil, raison.
function Build.Pave.try_serie(f, surface, g, c, fopts, states, scan)
  local b = f.build
  local sr, why = Build.Pave.serie(f, b, c, g, states)
  if not sr then return nil, why end
  local masks = scan({ k = sr.k2, l = sr.l2 }, sr.rect2)
  for _, t in ipairs(sr.trav.res.traversees) do
    local tiles = { t.entree, t.sortie }
    for _, r in ipairs(t.rallonge) do tiles[#tiles + 1] = r end
    for _, q in ipairs(tiles) do
      if b.occ[P.tkey(q.x, q.y)] or not (fopts.free(q.x, q.y) or masks.free(q.x, q.y)) then
        return nil, string.format("serie : passage du corridor occupe en (%d, %d)", q.x, q.y)
      end
    end
  end
  local fo = {}
  for kk, v in pairs(fopts) do fo[kk] = v end -- (copie des options : l'ordre est sans effet)
  fo.free, fo.within, fo.fed, fo.rot = masks.free, sr.within, { [g.ruban.port] = true }, { sr.k } -- (rot : l'orientation de la série, lot MALL-DIRECTIONS)
  fo.res = masks.res -- (lot DECOUPLAGE : ressources du lot de la section, P.fit)
  local fit, fwhy = P.fit(g, sr.rect2, fo)
  if not fit then return nil, "serie : " .. tostring(fwhy) .. " dans le lot " .. sr.k2 end
  local r = fit.k == 0 and g or M.rotate(g, fit.k)
  return { g = r, k = fit.k, ox = fit.ox, oy = fit.oy, lot = sr.k2, inst = M.instantiate(g, fit.k, fit.ox, fit.oy), cover = fit.cover, masks = masks, fan = fo.fan,
    pen = fit.pen, d = fit.d, pave = sr.owner, fed = fo.fed, serie = sr.trav, lot_from = c.k }
end

--- Pièces du franchissement, dans le projet de la section posée de l'autre côté de la rue : rallonge de tapis jusqu'au bord du lot, entrée
--- (type « input ») sur la dernière tuile du lot, sortie (type « output ») sur la première du suivant, dans le sens du corridor ; même tapis
--- que le gabarit, souterrain du palier débloqué. `reserve` = reserve_tiles. Rend true ou false, raison ; journal [FO-MALL].
function Build.Pave.cross(f, p, main, reserve)
  local b = f.build
  local tr = main.serie
  local list = {}
  for _, t in ipairs(tr.res.traversees) do
    for _, r in ipairs(t.rallonge) do list[#list + 1] = { name = tr.belt, x = r.x + 0.5, y = r.y + 0.5, dir = t.dir, role = "serie-tapis", part = 1 } end
    list[#list + 1] = { name = tr.ug.name, x = t.entree.x + 0.5, y = t.entree.y + 0.5, dir = t.dir, type = "input", role = "serie-souterrain", part = 1 }
    list[#list + 1] = { name = tr.ug.name, x = t.sortie.x + 0.5, y = t.sortie.y + 0.5, dir = t.dir, type = "output", role = "serie-souterrain", part = 1 }
  end
  if not reserve(b, p, list) then return false, "serie : place du souterrain" end
  p.parts[1].serie = { lot_from = main.lot_from, voies = #tr.res.traversees, ug = tr.ug.name }
  local t1 = tr.res.traversees[1]
  log(string.format("[FO-MALL] %s : serie : section %d posee de l'autre cote de la rue (lot %s), corridor en souterrain (%d voies), direction %s : projet %d, %s de (%d, %d) a (%d, %d), %d tapis de rallonge",
    f.key or "player", Build.Pave.rank(b, main.pave), main.lot, #tr.res.traversees, Build.Pave.Sd.NOM[tr.res.dir or 2] or "?", p.id, tr.ug.name, t1.entree.x, t1.entree.y, t1.sortie.x, t1.sortie.y, #t1.rallonge))
  return true
end

--- Lot MALL-DIRECTIONS : rotations à essayer pour la première section d'un ruban dans le lot `c` : vers le premier voisin libre du treillis
--- (même état permis, ni pris par un autre projet, ni pavé, ni sorti, ni mauvais), le plus proche de `toward`, puis est, sud, ouest, nord.
--- Rend la liste des k (les quatre, les voisins libres d'abord), les candidats et les refus (Sd.candidats).
function Build.Pave.rotations(b, c, states, toward)
  local Sd = Build.Pave.Sd
  local function rect_of(i, j) return P.lot_rect(b.lat, i, j) end
  local function occupation(i, j)
    local l = b.lots[P.lot_key(i, j)]
    if not l then return false, "hors du treillis" end
    if l.used and l.used ~= c.l.used then return false, "projet " .. tostring(l.used) end
    if not states[l.state] then return false, tostring(l.state) end
    if l.out or (l.bad or 0) >= 2 then return false, "lot ecarte" end
    local x0, y0, x1, y1 = rect_of(i, j)
    if Build.Pave.box(b, P.lot_key(i, j), { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }) then return false, "lot pave" end
    return true
  end
  local cands, refus = Sd.candidats({ i = c.l.i, j = c.l.j }, rect_of, occupation, { bus = toward })
  return Sd.rotations(cands), cands, refus
end

local function candidates(b, states, toward, res)
  local out = {}
  -- lot MALL-PAVAGE : `Build.Pave.want` (posé par place_module juste avant l'appel, consommé ici : aucun autre appelant ne le voit) : le
  -- gabarit à poser est un bloc ou une cellule de mall, un lot déjà pris par l'un d'eux reste candidat
  local pave = Build.Pave.want
  Build.Pave.want = nil
  if b.opts and b.opts.no_lots then return out end -- banc seulement (lot TV-REPLI, remote fo-ia1d set_option) : aucun lot candidat, le repli de placement simple doit prendre
  for _, k in ipairs(sorted_keys(b.lots)) do
    local l = b.lots[k]
    -- un lot de gisement sert plusieurs lignes de foreuses tant qu'il reste de la place (relevé des tuiles libres)
    -- lot IA3-e : la centrale peut aussi aller dans un lot refusé pour l'EAU (plus de la moitié d'eau) : sa rive y est
    -- souvent la seule ; le gabarit ne pose rien sur l'eau (P.fit)
    local ok_state = states[l.state] or (states.eau and l.state == "refuse" and l.reason == "eau")
    if l.out and (l.state == "libre" or l.state == "defricher") then ok_state = false end -- lot ENCEINTE3 : dehors du contour
    if states.no_edge and l.edge then ok_state = false end -- lot TV-PLACE (G37) : lot en bord de gisement, réservé à la fonte et aux foreuses (une fabrique n'y va pas)
    if b.mall and b.mall.sect and Build.Mall.lot_inside(b, l) then ok_state = false end -- lot MALL : lot entièrement dans le secteur réservé du mall
    -- lot ENERGIE-CROISSANCE : une rive déjà prise par une centrale FINIE reçoit une centrale de plus sur un autre bord de la même
    -- eau (P.fit ne pose rien sur ses tuiles, b.occ) ; sans cela, l'étang garanti étant la seule eau, toute centrale de plus était
    -- refusée « pas de lot » (retour du DC du 29/10 sur la 0.6.18 : « ils ont un déficit en électricité »)
    local shared = l.used and l.state ~= "gisement" and states.rive and plant_owner(b, l.used) or nil
    -- lot MALL-PAVAGE : un lot pris par un bloc ou une cellule de mall en reçoit un autre, collé au précédent (place_module, Build.Pave.pin) ;
    -- le lot reste au nom de son premier bloc (comme la rive partagée)
    local paved = pave and not shared and l.used and l.state ~= "gisement" and Build.Pave.owner(b, l.used) or nil
    -- lot GISEMENTS : gisement voisin du QG refusé sans fin « hors du treillis » (journal du DC, cuivre d'ambre à 33 tuiles) : l'état d'un lot
    -- ne retient qu'UNE ressource et son premier relevé ; le lot qui porte ce minerai sert (P.fit raisonne à la tuile)
    local ore_lot = states.gisement and res and Gisements.lot_for_ore(l, res, P.MIN_RES_TILES)
    if ore_lot then ok_state = true end
    if ((not l.used or l.state == "gisement" or shared) or paved) and ok_state and (not res or l.res == res or ore_lot) and not (l.bad and l.bad >= 2) then
      local c = lot_center(b, l)
      -- lot CORR-RESEAU : la centrale ne retourne pas sur un site jugé dangereux (b.avoid, posé par script/team/reseau_vivant.lua)
      local avoided = false
      if states.rive and b.avoid then
        for _, a in ipairs(b.avoid) do
          local m = a.r + Build.AVOID_MARGIN
          if (c.x - a.x) * (c.x - a.x) + (c.y - a.y) * (c.y - a.y) <= m * m then avoided = true break end
        end
      end
      if not avoided then
        out[#out + 1] = { l = l, d = math.abs(c.x - toward.x) + math.abs(c.y - toward.y), pave = paved, k = k, shared = shared }
      end
    end
  end
  table.sort(out, function(a, c) if a.d ~= c.d then return a.d < c.d end return a.k < c.k end)
  return out
end

--- Tuiles de minerai `res` d'un lot (un appel). Lot PD-FONDERIEQG (D82) : `set.axis` = sens du gisement dans le lot ("x", "y"
--- ou nil : rond ou trop petit ; shared/team/orient.lua), lu par place_module pour orienter une ligne de foreuses.
local mel_category
do
local MEL_CAT = {} -- lot MELANGE : catégorie d'une ressource (mémoire LOCALE, prototypes seulement)
function mel_category(name)
  local c = MEL_CAT[name]
  if c == nil then
    local pp = game.entity_prototypes[name]
    c = pp and pp.resource_category or false
    MEL_CAT[name] = c
  end
  return c
end
end -- do

local function ore_set(surface, rect, res)
  local set, n = {}, 0
  local m = Or.moments()
  for _, e in ipairs(surface.find_entities_filtered({ area = { { rect.x0 + 0.01, rect.y0 + 0.01 }, { rect.x1 - 0.01, rect.y1 - 0.01 } }, name = res })) do
    local tx, ty = math.floor(e.position.x), math.floor(e.position.y)
    set[P.tkey(tx, ty)] = true
    Or.add(m, tx - rect.x0, ty - rect.y0)
    n = n + 1
  end
  set.axis = Or.axis(m)
  -- lot MELANGE : tuiles d'une AUTRE ressource que la foreuse électrique sait miner (P.fit, opts.foreign)
  local dp = game.entity_prototypes[T.DRILL_ELECTRIC]
  local cats = dp and dp.resource_categories or {}
  local frn = {}
  for _, e in ipairs(surface.find_entities_filtered({ area = { { rect.x0 - 3.99, rect.y0 - 3.99 }, { rect.x1 + 3.99, rect.y1 + 3.99 } }, type = "resource" })) do
    if e.name ~= res then
      local c = mel_category(e.name)
      if c and cats[c] then frn[P.tkey(math.floor(e.position.x), math.floor(e.position.y))] = true end
    end
  end
  set.foreign = frn
  return set, n
end

--- Étape 1 / robustesse (28/10, graine 123456789 : Écarlate, QG à (339, −340), AUCUNE eau dans les 121 lots du treillis ni à
--- moins de 256 tuiles ; graine 271828182, Azure : de l'eau, mais aucune rive où le gabarit de la pompe tient) : sans rive
--- utilisable dans le treillis, l'électrification d'une faction ne démarrait JAMAIS. L'étang garanti (make_pond, posé dans le
--- lot libre le plus proche du QG) est SUPPRIMÉ par la décision du DC D-24 (1) : la centrale va à l'eau la plus proche hors du
--- treillis, reliée par une ligne de poteaux (lot PD-CENTRALE, script/team/centrale_loin.lua). Les étangs déjà posés dans une
--- sauvegarde restent de l'eau ; le champ b.pond n'est plus lu.
--- Intégration 0.6.21 (PD-CENTRALE x ENERGIE-CROISSANCE) : les étangs DE PLUS d'ENERGIE-CROISSANCE (l'ancien étang garanti avec
--- `extra` ; sa règle pure Cen.pond_allowed et C.MAX_PONDS, restées sans lecteur, sont retirées au lot FUITES-PILE) partent avec l'étang garanti, comme le demande le rapport de PD-CENTRALE : une centrale de plus va elle aussi
--- au loin par Far.place (une autre fenêtre de la même rive, masques b.occ). Le reste d'ENERGIE-CROISSANCE (rive partagée
--- main.shared, demandes, pause, 5 refus) est gardé.

--- Lot AGENCEMENT : relevés d'un lot (masques de place, tuiles de minerai `res`) gardés pour la passe de plan en cours. Mémoire
--- LOCALE (jamais dans global), valable pour un tick et une équipe : plan_project lit les lots pour dimensionner la ligne
--- (line_rows) puis pour poser les foreuses (plan_drills, place_module) sans relire le terrain ; vide après un chargement.
local SCAN = { tick = -1, key = nil, data = {} }
local function scan_cache(f)
  local key = tostring(f.key or "player")
  if SCAN.tick ~= game.tick or SCAN.key ~= key then SCAN.tick, SCAN.key, SCAN.data = game.tick, key, {} end
  return SCAN.data
end

--- Relevés du lot `c` (élément de candidates) : masks, et les tuiles de `res` si demandées. `cache` : scan_cache(f) ou nil.
local function lot_scan(f, surface, c, rect, res, cache)
  local masks = cache and cache["m" .. c.k]
  if not masks then
    masks = read_masks(f, surface, rect.x0 - 8, rect.y0 - 8, rect.x1 + 8, rect.y1 + 8)
    if cache then cache["m" .. c.k] = masks end
  end
  local ores
  if res then
    ores = cache and cache["o" .. c.k .. res]
    if not ores then
      ores = ore_set(surface, rect, res)
      if cache then cache["o" .. c.k .. res] = ores end
    end
  end
  return masks, ores
end

--- Pose un gabarit dans le meilleur lot : { g (tourné), k, ox, oy, lot, inst } ou nil, raison.
local function place_module(f, surface, g, kind_states, toward, res, opts)
  local b = f.build
  local last = "pas de lot"
  local tries = 0
  -- lot TV-PLACE (C07) : le repli simple fournit ses propres lots (spirale) ; sinon le classement par distance d'avant
  Build.Pave.want = Build.Pave.GEN[g.gen] -- lot MALL-PAVAGE : lu et consommé par candidates (un bloc de mall pave un lot déjà pris par un autre)
  for _, c in ipairs((opts and opts.simple_lots) or candidates(b, kind_states, toward, res)) do
    tries = tries + 1
    if tries > 8 then break end
    local x0, y0, x1, y1 = P.lot_rect(b.lat, c.l.i, c.l.j)
    local rect = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
    -- lot AGENCEMENT : `opts.cache` (scan_cache) garde les relevés d'un lot entre deux tailles essayées
    local masks, ores = lot_scan(f, surface, c, rect, res, opts and opts.cache)
    local fopts = { free = masks.free, res = masks.res, toward = toward, margin = (opts and opts.margin) or 1 }
    -- lot FONDERIES : la tête d'alimentation regarde le gisement (shared/team/plan.lua, P.fit)
    if opts and opts.head_toward then fopts.head_toward = opts.head_toward end
    -- lot AGENCEMENT : couverture visée des foreuses (80 % d'abord) et bras de sortie par quai (P.fit : place du second bras)
    if opts and opts.cover_min then fopts.cover_min = opts.cover_min end
    if opts and opts.within then fopts.within = opts.within end -- lot MIGRATION-CHAMP : la ligne tient dans la place libérée
    if opts and opts.fan then fopts.fan = opts.fan end
    if res then fopts.ore = ores; fopts.foreign = ores and ores.foreign or nil end -- (lot MELANGE)
    -- lot PD-FONDERIEQG (D82) : ligne de foreuses (gabarit « drills ») dans le sens du gisement, sortie du collecteur vers l'arrivée
    if res and g.gen == "drills" then fopts.axis = ores and ores.axis or nil; fopts.out_toward = true end
    if opts and opts.water then fopts.water = masks.water end
    fopts.front_ok = Build.Pur.front_ok(f, surface) -- lot PURETE-TAPIS : la queue d'un tapis du gabarit ne verse sur aucun tapis existant (nil : éteint)
    -- lot MALL-PAVAGE : dans un lot déjà pris par un bloc de mall, P.fit n'essaie que la place collée au précédent (Build.Pave.pin)
    local gp, pwhy = g, nil
    if c.pave then gp, pwhy = Build.Pave.pin(b, c, g, rect, fopts) end
    local fit, why
    if gp and g.gen == "ruban" and not c.pave then
      -- lot MALL-DIRECTIONS : la PREMIÈRE section d'un ruban prend l'orientation de sa série : vers le premier lot voisin libre (shared/team/serie_dirs.lua :
      -- le plus proche du point de collecte, puis est, sud, ouest, nord) ; une rotation à la fois, la première qui tient gagne
      for _, rk in ipairs(Build.Pave.rotations(b, c, kind_states, toward)) do
        fopts.rot = { rk }
        fit, why = P.fit(gp, rect, fopts)
        if fit then break end
      end
      fopts.rot = nil
    elseif gp then fit, why = P.fit(gp, rect, fopts) else why = pwhy end
    if fit then
      local r = fit.k == 0 and g or M.rotate(g, fit.k)
      local inst = M.instantiate(r, 0, fit.ox, fit.oy)
      return { g = r, k = fit.k, ox = fit.ox, oy = fit.oy, lot = c.k, inst = inst, cover = fit.cover, masks = masks, fan = fopts.fan,
        axis = fopts.axis, pen = fit.pen, d = fit.d, pave = c.pave, shared = c.shared }
    end
    -- lot MALL-RUE : le lot ne tient pas la section suivante d'un ruban : de l'autre côté de la rue, le corridor en souterrain (Build.Pave.try_serie)
    if c.pave and g.gen == "ruban" then
      local sp, swhy = Build.Pave.try_serie(f, surface, g, c, fopts, kind_states, function(c2, r2) return (lot_scan(f, surface, c2, r2, nil, opts and opts.cache)) end)
      if sp then return sp end
      if swhy:find("arretee", 1, true) or swhy:find("passage", 1, true) or swhy:find("souterrain", 1, true) or swhy:find("portee", 1, true) then Build.Pave.say(f, b, swhy) end
      why = tostring(why) .. " ; " .. swhy
    end
    last = why or last
    if not (opts and opts.simple_lots) then bump(b.stats.plan_refused, last) end -- (le repli simple ne fausse pas le décompte des refus du plan)
    -- Lot AUTO : `nobad` (foreuses de ravitaillement) : un refus ne compte pas contre le lot. Build.plan_drills essaie
    -- n, n-1, … 1 foreuses dans les MÊMES lots : chaque taille refusée y comptait un échec, et le lot était exclu après la
    -- deuxième (« tapis des foreuses (pas de lot) » alors qu'une ligne plus courte y tenait).
    if opts and opts.diag then opts.diag[#opts.diag + 1] = c.k .. ":" .. tostring(why) end
    -- (lot ENERGIE-CROISSANCE : la rive d'une centrale qui n'a plus de bord libre n'est pas un mauvais lot : sa centrale y reste et
    -- la remplacer doit pouvoir y revenir)
    -- (lot MALL-PAVAGE : un lot plein pour un bloc de plus n'est pas un mauvais lot : son premier bloc y reste, + 0)
    if not (opts and opts.nobad) and not c.shared then c.l.bad = (c.l.bad or 0) + (c.pave and 0 or 1) end
  end
  return nil, last
end

--- Ajoute des entités planifiées au projet (contrôle de la place réservée) ; faux si une tuile est déjà prise.
local function reserve_tiles(b, p, list)
  for _, e in ipairs(list) do
    for _, t in ipairs(P.tiles_of(e)) do
      local k = P.tkey(t[1], t[2])
      -- (lot COMBUSTIBLE-MIGRATION : les tuiles que le cadre du champ de ce projet a retenues pour son réseau du charbon reporté lui reviennent)
      local ow = b.occ[k]
      if ow and ow ~= p.id and not (p.spec and p.spec.champ and Build.Cd.own(ow, p.spec.champ.oid)) then return false end
    end
  end
  for _, e in ipairs(list) do
    for _, t in ipairs(P.tiles_of(e)) do b.occ[P.tkey(t[1], t[2])] = p.id end
    p.ents[#p.ents + 1] = e
  end
  return true
end

local function inst_entities(inst, part, belt)
  local out = {}
  for _, e in ipairs(inst.entities) do
    -- Lot CONVOYEURS : `belt` remplace le tapis du gabarit (le collecteur des foreuses suit le tracé qui l'achemine)
    local name = e.name
    if belt and (M.BASE[name] or {}).kind == "belt" then name = belt end
    out[#out + 1] = { name = name, x = e.position.x, y = e.position.y, dir = e.direction or 0, recipe = e.recipe, part = part, type = e.type } -- (type : entrée ou sortie d'un souterrain)
  end
  return out
end

--- Lot PLANDIR : poteau du réseau. Le grand (5 d'acier la pièce) seulement quand le coffre en contient déjà ; sinon le
--- poteau du module lui-même (`own`, le moins cher débloqué à la demande, A.choose_pole), de la portée de fil de ses données
--- (P.wire). Un seul type de poteau par module et pour sa rue : une île sans courant vient d'un maillon trop long.
local function pole_kind(f, own)
  if Stock.count(f, "big-electric-pole") > 0 then return "big-electric-pole", 30 end
  local name = own or M.DEFAULT_POLE
  return name, P.wire(name) or 9
end

--- Carrefour le plus proche d'une position (i, j).
local function nearest_node(b, x, y)
  local i = math.floor((x - b.lat.ox - P.HALF - 2) / P.PITCH + 0.5)
  local j = math.floor((y - b.lat.oy - P.HALF - 2) / P.PITCH + 0.5)
  return i, j
end

--- Poteaux du réseau à ajouter pour relier le module (premier poteau `mp`) au réseau : carrefours de la route jusqu'au
--- premier carrefour déjà au réseau (ou planifié), chaîne de liaison. Rend la liste d'entités ou nil, raison.
local function plan_power(f, p, mp, masks)
  local b = f.build
  local pole, reach = pole_kind(f, mp.name)
  local big = pole == "big-electric-pole"
  local mi, mj = nearest_node(b, mp.x, mp.y)
  -- lot PD-CENTRALE : un module HORS du treillis évalué (la centrale lointaine) s'accroche au carrefour de bord le plus proche ;
  -- une ligne de poteaux tracée au moteur l'y relie (fin de la fonction, Far.line), les rues du treillis font le reste
  -- (vérification rapide, 30/10 : seule la centrale lointaine, p.far, prend ce chemin ; un module ordinaire ne passe jamais
  -- par Far.line, dont l'échec rend « loin » sans fin pour un projet sans rive à écarter)
  local far = p.far ~= nil and Cl.is_far(b.radius, mi, mj)
  if far then mi, mj = Cl.clamp_node(b.radius, mi, mj) end
  local out = {}
  -- poteau d'un carrefour : celui du réseau s'il existe, sinon un quart LIBRE du carrefour (contrôlé au moteur :
  -- falaise, eau, bâti ; arbres et rochers seront défrichés). Correction du 27/10 : le poteau tombait sur le bout d'une
  -- falaise (banc ia1-build-reseau).
  local surface = surface_of(f)
  local spots = {}
  local function spot_of(i, j)
    local k = P.lot_key(i, j)
    if spots[k] ~= nil then return spots[k] or nil end
    local net = b.net[k]
    if net and net.x then spots[k] = { x = net.x, y = net.y } return spots[k] end
    local base = P.node_pole(b.lat, i, j, big)
    local w = big and 2 or 1
    for _, d in ipairs({ { 0, 0 }, { 2, 0 }, { 0, 2 }, { 2, 2 } }) do
      -- quarts du carrefour (4 × 4) : grand poteau 2 × 2 décalé de 2, poteau moyen aux coins (décalé de 3)
      local x, y = base.x + d[1], base.y + d[2]
      if not big then x, y = base.x + d[1] * 1.5, base.y + d[2] * 1.5 end
      local area = { { x - w / 2 + 0.05, y - w / 2 + 0.05 }, { x + w / 2 - 0.05, y + w / 2 - 0.05 } }
      local ok = true
      for ty = math.floor(area[1][2]), math.floor(area[2][2]) do
        for tx = math.floor(area[1][1]), math.floor(area[2][1]) do if b.occ[P.tkey(tx, ty)] then ok = false end end
      end
      if ok and surface then
        if surface.count_tiles_filtered({ area = area, collision_mask = "water-tile", limit = 1 }) > 0 then ok = false end
        if ok then
          for _, e in ipairs(surface.find_entities_filtered({ area = area, collision_mask = "object-layer" })) do
            if e.type ~= "tree" and e.type ~= "simple-entity" and e.type ~= "character" then ok = false break end
          end
        end
      end
      if ok then spots[k] = { x = x, y = y } return spots[k] end
    end
    spots[k] = false
    return nil
  end
  -- Lot IA3-e : le carrefour le plus proche du module peut n'avoir aucun quart libre (rive, eau : la centrale) ; on prend
  -- le plus proche des carrefours voisins qui en a un (moteur réel, e3-usine, azure : centrale refusée « pas de rue vers
  -- le reseau » alors qu'elle amorçait le réseau, son carrefour étant dans l'eau).
  -- Lot IA3-e : le PREMIER réseau (la centrale) part d'un carrefour relié au QG par les rues : la centrale au bord de
  -- l'eau, son carrefour isolé par des rues fermées (eau), aucun module ne pouvait ensuite la rejoindre (moteur réel,
  -- e4-usine graine 271828182, emerald : 15 refus « pas de rue vers le reseau »).
  local first_net = next(b.net) == nil
  local function reach_hq(i, j)
    if not first_net then return true end
    return P.route_nodes({ i = i, j = j }, { i = 0, j = 0 }, seg_passable(b), b.radius) ~= nil
      or P.route_nodes({ i = i, j = j }, { i = 0, j = 0 }, seg_wire(b), b.radius) ~= nil
  end
  if not (spot_of(mi, mj) and reach_hq(mi, mj)) then
    local cands = {}
    for dj = -2, 2 do
      for di = -2, 2 do
        if di ~= 0 or dj ~= 0 then
          local n = P.node_pos(b.lat, mi + di, mj + dj)
          cands[#cands + 1] = { i = mi + di, j = mj + dj, d = (n.x - mp.x) ^ 2 + (n.y - mp.y) ^ 2 }
        end
      end
    end
    table.sort(cands, function(a, c) if a.d ~= c.d then return a.d < c.d end if a.j ~= c.j then return a.j < c.j end return a.i < c.i end)
    for _, c in ipairs(cands) do
      if spot_of(c.i, c.j) and reach_hq(c.i, c.j) then mi, mj = c.i, c.j break end
    end
  end
  -- route de carrefours jusqu'au réseau (tronçons non fermés)
  local target
  local keys = sorted_keys(b.net)
  local gen_net = nil -- réseau des machines à vapeur (lu aussi par la chaîne directe, lot POTEAUX-COURT)
  if #keys == 0 then
    target = { i = mi, j = mj }
  else
    -- Lot IA3-e : un carrefour BÂTI d'abord (réseau qui existe) ; un carrefour d'un projet encore en réserve disparaît
    -- si ce projet est annulé, et le module qui s'y reliait reste une île sans courant (moteur réel, e7-usine, amber :
    -- rangée de grenades reliée au réseau prévu d'un module annulé, réseau à elle seule, « no_power »).
    -- Le réseau RÉEL : un carrefour bâti dont le poteau est sur le réseau des machines à vapeur (moteur réel, e7-usine
    -- graine 20261020, scarlet : la rangée de pierre reliée à la route d'un module annulé, puis la fonderie et les
    -- chargeurs reliés à elle : trois modules sur une île, centrale à 0 kW). À défaut, les carrefours de la centrale, puis
    -- n'importe lequel.
    if surface then
      local g = surface.find_entities_filtered({ force = f.force, type = "generator", limit = 1 })[1]
      gen_net = g and g.electric_network_id or nil
    end
    local function live(n)
      if not (n.built and gen_net and surface and n.x) then return false end
      local e = surface.find_entities_filtered({ position = { n.x, n.y }, radius = 0.75, force = f.force, type = "electric-pole", limit = 1 })[1]
      return e ~= nil and e.electric_network_id == gen_net
    end
    local best, bestd, lbest, lbestd, pbest, pbestd
    for _, k in ipairs(keys) do
      local n = b.net[k]
      local d = math.abs(n.i - mi) + math.abs(n.j - mj)
      if not bestd or d < bestd then best, bestd = n, d end
      if b.plant and n.pid == b.plant and (not pbestd or d < pbestd) then pbest, pbestd = n, d end
      if (not lbestd or d < lbestd) and live(n) then lbest, lbestd = n, d end
    end
    target = lbest or pbest or best
  end
  -- route : rues praticables, à défaut par-dessus une rue fermée par une falaise (les fils passent ; correction du
  -- 27/10, banc ia1-build-reseau) ; un carrefour sans place pour son poteau est évité (3 essais)
  local bad = {}
  -- Lot IA3-e : la route ne traverse pas un carrefour PRÉVU par un autre projet et pas encore bâti (il n'y pose pas de
  -- poteau, le croyant là ; ce projet annulé, la route a un trou : moteur réel, e8-usine graine 20261020, scarlet,
  -- rangée de pierre à 95 tuiles de la centrale, réseau à elle seule). Le départ et le but restent permis.
  local skey, tkey = P.lot_key(mi, mj), P.lot_key(target.i, target.j)
  local function foreign(k)
    local n = b.net[k]
    return n ~= nil and not n.built and n.pid ~= p.id and k ~= skey and k ~= tkey
  end
  local function avoid(okf) return function(key)
    if not okf(key) then return false end
    local kind, i, j = P.parse_seg(key)
    if not kind then return true end
    local i2, j2 = i + (kind == "h" and 1 or 0), j + (kind == "v" and 1 or 0)
    local k1, k2 = P.lot_key(i, j), P.lot_key(i2, j2)
    return not bad[k1] and not bad[k2] and not foreign(k1) and not foreign(k2)
  end end
  local nodes
  -- lot PLANDIR : cause exacte d'un refus « pas de rue vers le reseau » (journal [FO-PLANDIR], 3 lignes au plus par projet)
  local cause, blocked_at
  local no_route -- lot POTEAUX-COURT : aucune route de carrefours ({ wait = attente du refus }) : la chaîne directe ou le refus
  for attempt = 1, 4 do
    nodes = P.route_nodes({ i = mi, j = mj }, target, avoid(seg_passable(b)), b.radius)
    if not nodes then nodes = P.route_nodes({ i = mi, j = mj }, target, avoid(seg_wire(b)), b.radius) end
    if not nodes then cause = "aucune route filtree (essai " .. attempt .. ")" break end
    local blocked
    for _, n in ipairs(nodes) do
      if not spot_of(n.i, n.j) then blocked = n break end
    end
    if not blocked then cause = nil break end
    blocked_at = string.format("(%d,%d)", blocked.i, blocked.j)
    bad[P.lot_key(blocked.i, blocked.j)] = true
    cause = "carrefour " .. blocked_at .. " sans quart libre (essai " .. attempt .. ")"
    nodes = nil
  end
  if not nodes then
    local nbad, nforeign_total = 0, 0
    for _ in pairs(bad) do nbad = nbad + 1 end
    for _, k in ipairs(keys) do if foreign(k) then nforeign_total = nforeign_total + 1 end end
    p.noroute_logged = (p.noroute_logged or 0) + 1
    if p.noroute_logged <= 3 then
      local free_streets = P.route_nodes({ i = mi, j = mj }, target, seg_passable(b), b.radius) ~= nil
      local free_wires = P.route_nodes({ i = mi, j = mj }, target, seg_wire(b), b.radius) ~= nil
      log(string.format("[FO-PLANDIR] %s : pas de rue vers le reseau (projet %d) : cause %s ; depart (%d,%d) cible (%d,%d) rayon %d ; "
        .. "carrefours ecartes %d, etrangers non bati %d, reseau %d carrefour(s) ; route sans filtre : rues %s, fils %s",
        f.key or "player", p.id, tostring(cause), mi, mj, target.i, target.j, b.radius or 0, nbad, nforeign_total, #keys,
        free_streets and "oui" or "non", free_wires and "oui" or "non"))
    end
    -- lot PLANDIR : les carrefours d'un AUTRE projet pas encore bâti ferment seuls la route (elle existe sans le filtre, 27/10,
    -- scarlet : 19 carrefours étrangers sur 20, projet refusé à 13 min) : le projet ATTEND (« net ») que ce réseau soit bâti ou
    -- annulé, au lieu d'être refusé
    local wait = nil
    if (nforeign_total or 0) > 0 and nbad == 0 and cause and cause:find("^aucune route") then
      local ok_s = P.route_nodes({ i = mi, j = mj }, target, seg_passable(b), b.radius) ~= nil
      local ok_w = P.route_nodes({ i = mi, j = mj }, target, seg_wire(b), b.radius) ~= nil
      if ok_s or ok_w then wait = "net" end
    end
    -- lot POTEAUX-COURT (relecture) : b.net ne grandit plus quand le direct gagne, le carrefour cible s'éloigne : sans route, la
    -- chaîne directe au poteau vivant le plus proche relie encore le module (plus bas) ; le refus ne tombe que si elle échoue
    if far or big or not surface or #keys == 0 then return nil, "pas de rue vers le reseau", wait end
    no_route = { wait = wait }
    nodes = {}
  end
  -- lot POTEAUX-COURT (relecture, maillon manquant) : le but de la chaîne directe est le poteau VIVANT le plus proche du module (tout
  -- poteau sur le réseau des machines à vapeur, celui d'un module voisin ou d'une chaîne directe d'avant compris), pas le carrefour
  -- cible : sinon chaque module tirait sa ligne parallèle jusqu'au même carrefour lointain. Seuls des poteaux qui existent sont
  -- traversés gratuitement (un poteau prévu par un projet annulé laisserait un trou, moteur réel e8-usine). Sans centrale qui
  -- tourne : le carrefour cible.
  local dgoal, dlive
  local dlink = math.min(reach, P.wire(mp.name) or 9)
  if not far and not big and surface and (no_route or #nodes >= 2) then
    dgoal = spot_of(target.i, target.j)
    if dgoal and gen_net then
      local d = math.sqrt((mp.x - dgoal.x) ^ 2 + (mp.y - dgoal.y) ^ 2) + 1
      local live = {}
      for _, e in ipairs(surface.find_entities_filtered({ area = { { mp.x - d, mp.y - d }, { mp.x + d, mp.y + d } }, force = f.force, type = "electric-pole" })) do
        if e.electric_network_id == gen_net and (P.wire(e.name) or 0) >= dlink - 1e-9 then live[#live + 1] = { x = e.position.x, y = e.position.y } end
      end
      table.sort(live, function(u, v) if u.y ~= v.y then return u.y < v.y end return u.x < v.x end)
      local near = Pt.nearest(mp, live)
      if near then dgoal, dlive = near, live end
    end
  end
  -- tuiles des poteaux déjà prévus ici (un poteau de liaison ne se pose pas sur un poteau de carrefour)
  local taken = {}
  local function take(e) for _, t in ipairs(P.tiles_of(e)) do taken[P.tkey(t[1], t[2])] = true end end
  -- lot POTEAUX-MASQUES : les obstacles du couloir de CHAQUE liaison (le module au carrefour, puis carrefour à carrefour), pas
  -- seulement ceux du rectangle relevé autour du module ; hors couloir relevé, une tuile reste « libre » comme avant
  local view = { free = masks.free, clear = function(tx, ty) return masks.clear[P.tkey(tx, ty)] end }
  if surface then
    local legs = {}
    local npos0 = spot_of(mi, mj) or P.node_pole(b.lat, mi, mj, big)
    -- (lot PD-CENTRALE : la ligne lointaine lit son propre couloir, chunk par chunk, dans Far.line)
    if not far then legs[1] = { a = { x = mp.x, y = mp.y }, b = npos0 } end
    local pv
    -- lot POTEAUX-COURT : couloir de la chaîne directe (relevé avant ceux de l'escalier, qu'un long détour peut faire plafonner) ;
    -- au-delà du plafond de chunks, ses tuiles seraient « inconnues » (libres) : pas de direct
    if dgoal then
      local leg = { a = { x = mp.x, y = mp.y }, b = dgoal }
      local _, total = Mq.corridor({ leg }, Mq.margin(reach))
      if total <= Mq.MAX_CHUNKS then legs[#legs + 1] = leg else dgoal = nil end
    end
    for _, n in ipairs(nodes) do
      local pos = spot_of(n.i, n.j)
      if pv and (not big or (pv.x - pos.x) ^ 2 + (pv.y - pos.y) ^ 2 > reach * reach - 1e-6) then legs[#legs + 1] = { a = pv, b = pos } end
      pv = pos
    end
    local v = masques_view(f, surface, p, masks, legs, reach)
    if not v then return nil, "masques (couloir des poteaux en cours de releve)", "masques" end
    view = v
  end
  local function free(x, y)
    local tx, ty = math.floor(x), math.floor(y)
    return view.free(tx, ty) and not taken[P.tkey(tx, ty)] and not view.clear(tx, ty)
  end
  -- lot CORR-RESEAU : poteaux déjà prévus ou posés (ce projet, puis les projets en chantier ou finis) que les chaînes traversent au
  -- lieu d'en doubler un (seuls comptent ceux dont la portée de fil atteint celle de la chaîne ; shift_pole n'est pas touché)
  local known = {}
  local function add_known(e)
    if e.name:find("electric%-pole") and (P.wire(e.name) or 0) >= reach - 1e-9 then known[#known + 1] = { x = e.x, y = e.y } end
  end
  for _, e in ipairs(p.ents) do add_known(e) end
  if dlive then for _, k in ipairs(known) do dlive[#dlive + 1] = k end end -- (les poteaux de ce projet sont posés avec lui)
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    -- centrale abandonnée exclue : reseau_vivant ne rouvre plus ses poteaux, on ne s'appuie pas sur eux
    if q and q ~= p and not q.abandoned and REUSE_STATES[q.state] then for _, e in ipairs(q.ents) do add_known(e) end end
  end
  -- lot POTEAUX-COURT : chaîne DIRECTE du module à dgoal (A* sans passer par les carrefours), calculée avant l'escalier et comparée à
  -- lui plus bas. Relecture : elle suit d'abord les rues et les lots déjà pris, un poteau au milieu d'un lot libre y refuserait
  -- les modules (P.fit dans 24 x 24, l.bad à 2 : lot exclu) ; elle ne coupe un lot libre que si les rues font un vrai détour.
  local n0 = #out
  local direct
  if dgoal then
    local a = { x = mp.x, y = mp.y }
    local k = dlive or known
    local opts = Cl.path_opts(math.sqrt((a.x - dgoal.x) ^ 2 + (a.y - dgoal.y) ^ 2), dlink)
    local oi, oj = P.lot_at(b.lat, math.floor(mp.x), math.floor(mp.y))
    local function free_street(x, y)
      if not free(x, y) then return false end
      local i, j = P.lot_at(b.lat, math.floor(x), math.floor(y))
      return not i or (i == oi and j == oj) or not Pt.lot_protected(b.lots[P.lot_key(i, j)])
    end
    direct = Build.Trav.pole_chain(f, surface, a, dgoal, dlink, false, free_street, k, opts)
    if not Pt.keep_street(a, direct, dgoal) then
      local c2 = Build.Trav.pole_chain(f, surface, a, dgoal, dlink, false, free, k, opts)
      if c2 and (not direct or Pt.length(a, c2, dgoal) < Pt.length(a, direct, dgoal) - 0.01) then direct = c2 end
    end
  end
  local function direct_out()
    local r = {}
    for _, c in ipairs(direct) do r[#r + 1] = { name = mp.name, x = c.x, y = c.y, dir = 0, role = "liaison" } end
    return r, nil, {} -- (aucun carrefour : pas de poteau dessus, b.net n'est pas touché)
  end
  if no_route then
    if not direct then return nil, "pas de rue vers le reseau", no_route.wait end
    return direct_out()
  end
  local via_len = 0
  local prev
  for _, n in ipairs(nodes) do
    local k = P.lot_key(n.i, n.j)
    local pos = spot_of(n.i, n.j)
    n.x, n.y = pos.x, pos.y
    if not b.net[k] then
      local e = { name = pole, x = pos.x, y = pos.y, dir = 0, role = "reseau", node = k }
      out[#out + 1] = e
    end
    take({ name = pole, x = pos.x, y = pos.y, dir = 0 })
    -- poteaux de rue : moyens, ou grands quand deux carrefours décalés passent la portée
    local d2 = prev and ((prev.x - pos.x) ^ 2 + (prev.y - pos.y) ^ 2) or 0
    if prev and (not big or d2 > reach * reach - 1e-6) then
      local chain = Build.Trav.pole_chain(f, surface, prev, pos, reach, big, free, known)
      if not chain then
        if direct then return direct_out() end -- (l'escalier échoue, le direct passe)
        return nil, "poteaux de rue"
      end
      via_len = via_len + Pt.length(prev, chain, pos)
      for _, c in ipairs(chain) do
        local e = { name = pole, x = c.x, y = c.y, dir = 0, role = "rue" }
        out[#out + 1] = e
        take(e)
      end
    end
    prev = pos
  end
  -- liaison du module au carrefour le plus proche (poteaux du gabarit : moyens)
  local npos = spot_of(mi, mj) or P.node_pole(b.lat, mi, mj, big)
  local link_reach = math.min(reach, P.wire(mp.name) or 9)
  local chain
  if far and surface then
    local w4, wait4
    chain, w4, wait4 = Far.line(f, surface, p, { x = mp.x, y = mp.y }, npos, link_reach, taken, known, read_masks)
    if not chain then return nil, w4, wait4 end
  else
    chain = Build.Trav.pole_chain(f, surface, { x = mp.x, y = mp.y }, npos, link_reach, false, free, known)
  end
  if not chain then
    if direct then return direct_out() end
    return nil, "liaison electrique"
  end
  via_len = via_len + Pt.length({ x = mp.x, y = mp.y }, chain, npos)
  for _, c in ipairs(chain) do
    -- (lot PD-CENTRALE : un poteau de la ligne lointaine arrive avec son point d'appui, lu sur le terrain de la ligne)
    local e = { name = mp.name, x = c.x, y = c.y, dir = 0, role = "liaison", ligne = far or nil,
      ax = c.ax, ay = c.ay, anchor = c.anchor }
    out[#out + 1] = e
    take(e)
  end
  -- lot POTEAUX-COURT : l'escalier de carrefours contre la chaîne directe (règle : Pt.prefer_direct) ; journal [FO-POTEAUX]
  if dgoal then
    local via = { n = #out - n0, len = via_len }
    local dir = direct and { n = #direct, len = Pt.length({ x = mp.x, y = mp.y }, direct, dgoal) } or nil
    local d0 = math.sqrt((mp.x - dgoal.x) ^ 2 + (mp.y - dgoal.y) ^ 2)
    local use = Pt.prefer_direct(dir, via)
    p.pot_logged = (p.pot_logged or 0) + 1
    if p.pot_logged <= 3 then
      log(string.format("[FO-POTEAUX] %s : projet %d, module vers le poteau %s a %.0f tuiles : escalier %d poteau(x) %.0f tuiles (ratio %.2f), direct %s : %s",
        f.key or "player", p.id, dlive and "vivant" or "du carrefour", d0, via.n, via.len, d0 > 0 and via.len / d0 or 1,
        dir and string.format("%d poteau(x) %.0f tuiles (ratio %.2f)", dir.n, dir.len, d0 > 0 and dir.len / d0 or 1) or "introuvable",
        use and "DIRECT retenu" or "escalier garde"))
    end
    if use then return direct_out() end
  end
  if view.stats and (p.masq_logged or 0) < 6 then
    p.masq_logged = (p.masq_logged or 0) + 1
    log(string.format("[FO-MASQUES] %s : projet %d, %d poteau(x) de liaison et de rue planifie(s) : %d interrogation(s) du rectangle du module, %d d'un chunk releve, %d de tuile inconnue (libre)",
      f.key or "player", p.id, #out, view.stats.base, view.stats.chunk, view.stats.unknown))
  end
  return out, nil, nodes
end

local function needs_power(g) return (g.power_kw or 0) > 0 end

--- Lot GISEMENTS : aucun lot ne porte ce minerai au dernier relevé : recompte le minerai des lots libres (toutes les G.ORE_SCAN ticks par
--- minerai), l.ores[minerai] lu par Gisements.lot_for_ore. Un lot ne garde sinon que sa ressource principale, relevée une fois.
local function scan_ore_lots(f, surface, res)
  local b = f.build
  b.ore_scan = b.ore_scan or {}
  local tick = game.tick
  if b.ore_scan[res] and tick < b.ore_scan[res] then return end
  b.ore_scan[res] = tick + Gisements.ORE_SCAN
  for _, k in ipairs(sorted_keys(b.lots)) do
    local l = b.lots[k]
    if not l.used and l.state ~= "inconnu" and not (l.i == 0 and l.j == 0) then
      local x0, y0, x1, y1 = P.lot_rect(b.lat, l.i, l.j)
      local n = surface.count_entities_filtered({ area = { { x0 + 0.01, y0 + 0.01 }, { x1 - 0.01, y1 - 0.01 } }, type = "resource", name = res })
      if n > 0 or l.ores then
        l.ores = l.ores or {}
        l.ores[res] = n
      end
    end
  end
end

local function deposit_toward(b, res)
  local c = candidates(b, { gisement = true }, { x = b.lat.ox, y = b.lat.oy }, res)[1]
  return c and lot_center(b, c.l) or nil
end

--- Lot INDUSTRIE I3 : aucun lot du treillis ne porte ce minerai. Y en a-t-il un au-delà ? Compte le minerai des anneaux de lots
--- radius + 1 … RADIUS_ORE, du plus proche au plus loin (4 bandes par anneau, `limit` = la tuile minimale d'un lot de gisement) et
--- rend le premier anneau qui en porte assez, ou false. Mémorisé PROBE_EVERY ticks par minerai (b.probe, des nombres seulement).
local function probe_ore(f, surface, res)
  local b = f.build
  b.probe = b.probe or {}
  local tick = game.tick
  local pr = b.probe[res]
  if pr and tick < pr.next then return pr.hit end
  local hit = false
  for _, k in ipairs(Tr.rings_to_probe(b.radius, Build.RADIUS_ORE)) do
    for _, band in ipairs(Tr.ring_bands(k)) do
      local ax, ay = P.lot_rect(b.lat, band.i0, band.j0)
      local _, _, bx, by = P.lot_rect(b.lat, band.i1, band.j1)
      local n = surface.count_entities_filtered({ area = { { ax + 0.01, ay + 0.01 }, { bx - 0.01, by - 0.01 } }, type = "resource", name = res,
        limit = P.MIN_RES_TILES })
      if n >= P.MIN_RES_TILES then hit = k break end
    end
    if hit then break end
  end
  b.probe[res] = { next = tick + Tr.PROBE_EVERY, hit = hit }
  return hit
end

--- Lot INDUSTRIE I3 : la chaîne déclencheur -> décision -> action -> effet d'un gisement que le plan d'une fonderie n'atteint pas.
--- Déclencheur : plan_feed (la voie d'un minerai sans lot à portée du tapis). Décision : Tr.decide (règle pure) sur ce que le treillis
--- porte (`dt`, centre du lot de minerai, ou rien) et ce que la sonde voit au-delà. Action : Build.grow jusqu'au gisement, d'un coup,
--- au plus RADIUS_ORE. Effet : le prochain plan trouve les lots (ou la raison du refus est écrite). Compte par cause (b.stats.treillis),
--- une ligne [FO-TREILLIS] à chaque changement de cause d'un minerai. Rend la décision.
local function treillis_step(f, surface, res, dt, dist, reach_tiles)
  local b = f.build
  if not Rsv.on() then -- réglage maître éteint : la règle d'avant, un anneau par refus sans gisement connu
    if not dt and Build.can_grow(b) then Build.grow(f, b.radius + 1) end
    return nil
  end
  -- (intégration 0.6.32 : enceinte complète, Build.beyond_wall : le rayon n'est plus figé ; Tr.decide refusait « enceinte » ce que Build.grow permet)
  local s = { radius = b.radius, cap = Build.RADIUS_ORE, enc_r = b.enc and not Build.beyond_wall(b) and b.enc.r or nil,
    pending = math.max(0, #b.queue - b.qhead + 1), reach = reach_tiles }
  if dt then
    s.found, s.dist = true, dist
    s.deposit_ring = Tr.ring_of_point(b.lat.ox, b.lat.oy, dt.x, dt.y, P.PITCH)
  end
  local dec = Tr.decide(s)
  if dec.action == "sonder" then
    s.probe = probe_ore(f, surface, res)
    dec = Tr.decide(s)
  end
  local from = b.radius
  if dec.action == "grandir" then Build.grow(f, dec.radius, Build.RADIUS_ORE) end
  b.stats.treillis = b.stats.treillis or {}
  bump(b.stats.treillis, dec.cause .. ":" .. dec.action)
  b.tr_last = b.tr_last or {}
  if b.tr_last[res] ~= dec.cause then
    b.tr_last[res] = dec.cause
    b.tr_logs = (b.tr_logs or 0) + 1
    if b.tr_logs <= Build.TREILLIS_LOGS then
      log(Tr.line({ team = f.key or "player", tick = game.tick, res = res, cause = dec.cause, action = dec.action, from = from, to = dec.radius,
        probe = s.probe, cap = s.cap, dist = s.found and dist or nil, reach = reach_tiles }))
    end
  end
  return dec
end

--- Lot IA3-e : un bras ÉLECTRIQUE de quai (tête d'alimentation, quai de sortie) hors de l'aire des poteaux du module ne
--- reçoit pas de courant (moteur réel, e5-usine, diagnostic : « inserter:no_power » aux quais, fours « no_fuel » faute du
--- bras du charbon) : un poteau moyen est ajouté sur une tuile libre voisine (le moteur le relie seul aux poteaux à portée).
local quai_poles
do
local QUAI_ROLES = { ["quai-bras"] = true, ["sortie-bras"] = true }
local function covered_by(poles, e)
  for _, q in ipairs(poles) do
    -- aire d'alimentation du poteau (demi-côté) contre la boîte du bras (±0,15) : un bras à 4 tuiles d'un poteau moyen
    -- n'est PAS alimenté (moteur réel, e6-usine : bras de quai « no_power » sous des poteaux du réseau de la centrale)
    local sup = (q.name == "big-electric-pole") and 2 or ((M.spec(q.name) or {}).supply or 3.5)
    if math.abs(q.x - e.x) <= sup + 0.15 and math.abs(q.y - e.y) <= sup + 0.15 then return true end
  end
  return false
end
function quai_poles(b, p, list, masks, pole_name)
  local poles = {}
  for _, e in ipairs(p.ents) do if e.name:find("electric%-pole") then poles[#poles + 1] = e end end
  for _, e in ipairs(list) do if e.name:find("electric%-pole") then poles[#poles + 1] = e end end
  local planned = {}
  for _, e in ipairs(p.ents) do for _, t in ipairs(P.tiles_of(e)) do planned[P.tkey(t[1], t[2])] = true end end
  for _, e in ipairs(list) do for _, t in ipairs(P.tiles_of(e)) do planned[P.tkey(t[1], t[2])] = true end end
  local extra = {}
  for _, e in ipairs(list) do
    if QUAI_ROLES[e.role] and not covered_by(poles, e) then
      local tx0, ty0 = math.floor(e.x), math.floor(e.y)
      for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 }, { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 } }) do
        local tx, ty = tx0 + d[1], ty0 + d[2]
        local k = P.tkey(tx, ty)
        if not planned[k] and not b.occ[k] and (not masks or masks.free(tx, ty)) then
          local pole = { name = pole_name or M.DEFAULT_POLE, x = tx + 0.5, y = ty + 0.5, dir = 0, role = "quai-poteau", part = e.part }
          extra[#extra + 1] = pole
          poles[#poles + 1] = pole
          planned[k] = true
          break
        end
      end
    end
  end
  return extra
end
end -- do

--- Lot AGENCEMENT : bras de sortie par tapis de sortie d'un gabarit : (nom du bras, nombre) pour au plus `fan_max` bras (1 : le
--- quai d'avant seul, comme avant le lot ; 2 : un second bras et son coffre sur le côté extérieur du bout du tapis, dont la place
--- est réservée par P.fit via `fan`). Un bras seul ne suit pas une longue ligne (le plafond de la ligne était son débit).
local function out_arms(g, fan_max)
  local outn = 0
  for _, k in ipairs(sorted_keys(g.nominal or {})) do if k ~= "electricity-kw" then outn = outn + g.nominal[k] end end
  local nports = 0
  for _, q in ipairs(g.ports or {}) do if q.kind == "tapis" and q.io == "out" then nports = nports + 1 end end
  local per = outn / math.max(1, nports)
  local cmax = math.max(1, math.min(fan_max or 1, Li.MAX_ARMS))
  -- lot RECHERCHE-BRAS : g.arms = les bras obtenables du gabarit (nil : tous, comme avant) ; au pire le plus rapide d'entre eux
  local ins, cnt = M.choose_inserters(per, true, cmax, g.arms)
  if not ins then ins, cnt = (g.arms or M.ARMS)[#(g.arms or M.ARMS)], cmax end
  return ins, cnt
end

--- Lot AGENCEMENT : un AUTRE projet du plan consomme-t-il `plate` ? (`p.consumes`, posé au plan de chaque projet : les entrées de
--- son gabarit.) Plaques qui nourrissent un module de l'usine : la ligne finit côté tête, coffres vers l'extérieur.
local function plate_used_elsewhere(b, p, plate)
  for _, id in ipairs(b.order) do
    local q = b.projects[id]
    if q and q ~= p and q.consumes and q.consumes[plate] then return true end
  end
  return false
end

Build.LINE_LOGS = 24 -- lignes [FO-LIGNE] au plus, par équipe
Build.DEBIT_LOGS = 24 -- lignes [FO-DEBIT] au plus, par équipe

--- Lot RANGEES-DEBIT (retour du DC du 29/10 en jouant la 0.6.18 : « il faut faire des packs de N [...] en fonction du débit », « huit
--- d'un côté, huit de l'autre au lieu d'en avoir six ») : paires de foreuses qu'UN collecteur porte, lues sur le tapis que la ligne
--- entière demanderait (Conv.choose : vitesse lue dans les prototypes, technologie de l'équipe ; débit d'une foreuse : M.spec), bornées
--- par l'emprise du gabarit `emprise` (M.GEN.drills, longueur d'un lot). Règle pure : shared/team/debit.lua. Lecteur : line_rows, qui
--- borne ensuite par le gisement (80 % de couverture) puis donne aux fours les rangées que ces foreuses nourrissent ; la ligne de
--- foreuses posée suit ces fours (plan_drills, demande). Journal [FO-DEBIT] : une ligne par minerai et par borne retenue.
--- Relecture : le tapis est lu par la règle pure (CvRegle.pick, même choix que Conv.choose) et NON par Conv.choose, qui écrit une fois par
--- équipe la ligne [FO-CONVOYEURS] « premier choix de tapis » : appelée ici, au plan, avec un débit HYPOTHÉTIQUE, elle prenait la place
--- de celle du premier vrai tracé (plan_feed). Avec les données de base, la borne retenue est l'emprise (7 paires, M.MAX_SIDE), jamais le
--- tapis (15 foreuses par côté sur une voie jaune) : le gabarit (M.GEN.drills) bornait déjà par M.LANE_RATE, le plus lent des tapis.
function Build.debit_pairs(f, ore, emprise, drill_rate, lateral)
  local dc = T.debit or {}
  if not dc.belt or type(drill_rate) ~= "number" or drill_rate <= 0 then return emprise end
  -- une voie = un côté de la ligne entière
  local belt, speed = CvRegle.pick(Conv.belts(), Conv.usable(f), (emprise or 0) * drill_rate, { need_only = Conv.MODE == "besoin" })
  local lane = Db.lane_capacity(speed)
  local by_belt = Db.belt_pairs(lane, drill_rate, nil)
  if by_belt <= 0 then return emprise end -- aucun tapis lisible : la borne du gabarit (comportement d'avant)
  by_belt = Db.head_pairs(by_belt, lateral) -- lot FIX-P4 : arrivée latérale sur la tête = deux voies versées dans une seule
  local np, why = math.min(by_belt, emprise or by_belt), (by_belt < (emprise or by_belt)) and "tapis" or "emprise"
  local b = f.build
  b.debit_seen = b.debit_seen or {}
  local key = tostring(ore) .. ":" .. tostring(belt) .. ":" .. np
  if not b.debit_seen[key] then
    b.debit_seen[key] = true
    b.debit_logs = (b.debit_logs or 0) + 1
    if b.debit_logs <= Build.DEBIT_LOGS then
      log(string.format("[FO-DEBIT] %s : foreuses %s : tapis %s, %.2f/s par voie / %.2f/s par foreuse = %d foreuse(s) par cote ; emprise d'un lot %d paire(s) -> ligne de %d paire(s) au plus (%d foreuses, borne %s), puis le gisement et les fours",
        f.key or "player", tostring(ore), tostring(belt), lane, drill_rate, by_belt, emprise or 0, np, 2 * np, why))
    end
  end
  return np
end

--- Lot AGENCEMENT (retour du DC du 29/10 : « ils peuvent pas vraiment étendre plus loin », « 4 foreuses ») : taille de la fonderie
--- à tapis, décidée APRÈS celle de la demande. La ligne suit les foreuses que le gisement le plus proche porte à 80 % de
--- couverture (Rg.pairs_for_tiles : tuiles de minerai du lot, relevé du plan, sans appel moteur), bornée par l'emprise d'un lot,
--- le débit des bras de sortie et une part du stock de plaques. Règle pure : shared/team/ligne.lua. Rend le nombre de rangées.
local function line_rows(f, surface, spec, g, cur, rev)
  local cfg = T.ligne
  local prm = g.params or {}
  if not (cfg and cfg.grow and g.gen == "smelter" and spec.feed == "tapis" and prm.ore and prm.n and prm.n > 0) then return cur end
  if spec.fixe then return cur end -- lot MIGRATION-CHAMP : la ligne d'une partie de champ a la taille de la partie, pas celle du gisement
  local b = f.build
  local plate = M.PLATE_OF[prm.ore]
  local main = g.nominal and plate and g.nominal[plate]
  local fsp, dsp = M.spec(prm.furnace or ""), M.spec(T.DRILL_ELECTRIC)
  if not (main and main > 0 and fsp and dsp) then return cur end
  local cap = main / (2 * prm.n) -- plaques/s d'UN four
  local gd = M.GEN.drills(prm.ore, 1)
  local pairs_line = gd and gd.extensions and gd.extensions[1] and gd.extensions[1].max or 0
  pairs_line = Build.debit_pairs(f, prm.ore, pairs_line, dsp.speed, P.FEEDER_SIDE_LOAD) -- lot RANGEES-DEBIT : le collecteur réel borne la ligne
  local reach = Rg.reach(dsp.radius, dsp.w)
  -- ce que les lots de gisement les plus proches portent : le comptage des tuiles du relevé de lot donne une BORNE HAUTE
  -- (Rg.pairs_for_tiles), puis P.fit lui-même (pur) dit quelle ligne de foreuses y TIENT à la couverture visée
  local tiles, pairs_dep, bound = 0, 0, 0
  local cache = scan_cache(f)
  for i, c in ipairs(candidates(b, { gisement = true }, { x = b.lat.ox, y = b.lat.oy }, prm.ore)) do
    if i > cfg.top_lots then break end
    local nt = c.l.ore_n or 0
    if nt > tiles then tiles = nt end
    local ub = math.min(Rg.pairs_for_tiles(nt, dsp.w, reach, cfg.cover, pairs_line), pairs_line)
    bound = math.max(bound, ub)
    if ub > pairs_dep then
      local x0, y0, x1, y1 = P.lot_rect(b.lat, c.l.i, c.l.j)
      local rect = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
      local masks, ores = lot_scan(f, surface, c, rect, prm.ore, cache)
      for n = ub, pairs_dep + 1, -1 do
        local gd2 = M.GEN.drills(prm.ore, n)
        if gd2 and P.fit(gd2, rect, { free = masks.free, res = masks.res, ore = ores, foreign = ores and ores.foreign or nil, cover_min = cfg.cover }) then pairs_dep = n break end
      end
    end
  end
  local rows, why = Li.rows_wanted({
    rows_rate = cur, pairs_dep = pairs_dep, drill_rate = dsp.speed, cap = cap,
    pairs_line = pairs_line, rows_max = g.extensions[1].max, grow = true,
    rows_fit = Li.rows_fit(P.LOT, 1, P.FEED_DEPTH, rev and 0 or 2, (g.cell and g.cell.h) or fsp.w), -- (lot RETROFIT-GABARITS : pas = cellule réservée du gabarit)
    out_ok = function(r) return M.choose_inserters(r * cap, true, Li.MAX_ARMS) ~= nil end,
    -- lot FONDERIE-DYNAMIQUE : plus de plancher de 4 rangées ; ligne dynamique : la PLACE de la ligne entière est réservée (sans
    -- budget), les rangées sont posées par étapes (ligne_split au plan, Build.ligne_step ensuite) ; sinon le stock borne la ligne
    budget_rows = (not cfg.dyn) and Li.budget_rows(Stock.count(f, T.outposts.iron.product), cfg.row_cost, cfg.stock_share, 0) or nil,
  })
  if rows ~= cur then
    b.line_logs = (b.line_logs or 0) + 1
    if b.line_logs <= Build.LINE_LOGS then
      log(string.format("[FO-LIGNE] %s : fonderie %s, %d rangee(s) demandee(s) -> %d (%s) ; gisement %d tuiles (borne %d paire(s)) = %d paire(s) de foreuses a %d%% verifiees, sortie %s",
        f.key or "player", tostring(prm.ore), cur, rows, why, tiles, bound, pairs_dep, math.floor(cfg.cover * 100 + 0.5),
        rev and "exterieur" or "centre"))
    end
  end
  return rows
end

--- Têtes d'alimentation et quais d'un module posé ; foreuses de ravitaillement et tapis. Rend true ou false, raison.
local function plan_feed(f, surface, p, place, part)
  local b = f.build
  local g = place.g
  -- Lot AUTO : les quais de SORTIE d'abord, puis les entrées (têtes, foreuses et leur tapis). Le tapis des foreuses évite
  -- les tuiles déjà réservées (b.occ) ; réservé AVANT le quai de sortie, il pouvait passer sur sa tuile (reserve_tiles admet
  -- un recouvrement dans le même projet) : moteur réel, a2 et a3-usine graine 271828182, emerald, fantôme du tapis refusé
  -- « occupe » par le coffre du quai de sortie bâti avant lui, fonderie bloquée à 138 entités sur 139 jusqu'à 90 min.
  local ports = {}
  for _, port in ipairs(P.belt_ports(place.inst)) do if port.io ~= "in" then ports[#ports + 1] = port end end
  for _, port in ipairs(P.belt_ports(place.inst)) do if port.io == "in" then ports[#ports + 1] = port end end
  for _, port in ipairs(ports) do
    if place.fed and place.fed[port.ent] then
      -- lot MALL-RUE : port servi par le souterrain de la série (le corridor de la section précédente) : aucune tête d'alimentation
    elseif port.io == "in" then
      local sources = { nil, nil }
      local drills = {}
      -- une même ressource sur les deux voies : une seule source (la voie 1), sauf si son débit dépasse une voie (lot FIX-P4 :
      -- Db.lane_split, voie lue sur le tapis que ce débit demanderait) : alors les deux voies, chacune pour la moitié
      local split
      if port.lanes and port.lanes[1] and port.lanes[1] == port.lanes[2] then
        local all = g.inputs and g.inputs[port.lanes[1]] or 0
        local _, sp = CvRegle.pick(Conv.belts(), Conv.usable(f), all, { need_only = Conv.MODE == "besoin" })
        split = Db.lane_split(all, Db.lane_capacity(sp))
      end
      for lane = 1, 2 do
        local item = port.lanes and port.lanes[lane]
        if item and not (split and not split[lane]) then
          sources[lane] = "quai"
          local flow = split and split[lane] or (g.inputs and g.inputs[item] or 0)
          -- Lot IA3-e, étendu par le lot DECOUPLAGE (directive du DC du 11/11 : « le minerai brut quitte la box de minage par un
          -- convoyeur collecteur continu jusqu'à l'entrée de la box de fonderie », relais par coffre interdit) : la voie de minerai
          -- d'une fonderie est servie par foreuses et tapis, JAMAIS par un quai, quel que soit le mode d'alimentation demandé et sous
          -- le seuil du tapis compris ; sinon le plan est refusé, raison « gisement : … ». Le charbon (combustible) garde son quai.
          local need_belt = Build.Sm.belt_only(item, M.ORES, T.fuel)
          -- Lot C2 : seuil du tapis par le coût réel de la voie (f.team.ia3e.belt_flow, shared/ai3/demande.lua) ; à défaut, la constante P.AUTO_FLOW
          local belt_thr = (f.team and f.team.ia3e and f.team.ia3e.belt_flow) or P.AUTO_FLOW
          if need_belt or (M.ORES[item] and flow >= belt_thr and p.spec.feed ~= "quai") then
            local dt = deposit_toward(b, item)
            if not dt and need_belt then -- lot GISEMENTS
              scan_ore_lots(f, surface, item)
              dt = deposit_toward(b, item)
            end
            local reach = (p.spec.feed == "tapis") and 5 or 3
            local d = dt and (math.abs(dt.x - place.ox) + math.abs(dt.y - place.oy)) or nil
            if d and d <= reach * P.PITCH then
              sources[lane] = "tapis"
              drills[lane] = { item = item, flow = flow, dist = d, need = need_belt }
            elseif need_belt then
              -- gisement hors du treillis : le treillis grandit (nouvel essai quand le rayon change). Lot INDUSTRIE I3 : d'un coup
              -- jusqu'au gisement que la sonde a vu, au plus RADIUS_ORE, et jamais pour rien (l'ancien +1 par refus, borné à RADIUS_MAX,
              -- grandissait sans savoir s'il y avait quelque chose à atteindre, et ne grandissait pas du tout pour un lot trop loin du module)
              treillis_step(f, surface, item, dt, d, reach * P.PITCH)
              -- lot GISEMENTS : quels lots portent ce minerai, dans quel état (journal [FO-AUTO], borné par DRILL_DIAG_LOGS)
              if not dt then Build.drill_diag(f, item, 0, { x = place.ox, y = place.oy }, "hors du treillis", nil) end
              return false, dt and string.format("gisement : %s a %d tuiles du lot", item, d) or ("gisement : " .. item .. " hors du treillis")
            end
          end
        end
      end
      -- centrale : bras À COMBUSTION au quai (correction du 27/10 : avec un bras électrique, pas de charbon sans courant
      -- ni de courant sans charbon, 0 kW au banc ia1-build-plaine) ; il se ravitaille avec le charbon qu'il porte. Lot
      -- PLANDIR (28/10) : ils le RESTENT, mesuré : passés à l'électrique, les bras de la centrale la tuaient en 1,5 à 3,5 min
      -- (6 cas sur 6)
      local quai_ins = (g.gen == "steam") and M.BURNER_ARM or "inserter"
      local quai_n = 1
      if Build.QUAI_PAR_DEBIT and g.gen ~= "steam" then
        -- lot RESEAU-GRAPHE : le bras du quai suit le débit de la recette, comme out_arms pour les sorties (1 à 2 bras par voie)
        local qd = Build.Qd.plan(M, g, Build.Qd.skip(M, g, p.spec.feed == "quai"))
        quai_ins, quai_n = qd.arm, qd.count
      end
      -- Lot CONVOYEURS : la tête et le tracé des foreuses ont le même tapis (le meilleur débloqué, ou celui que le débit exige)
      local head_belt
      do
        local top, len = 0, 0
        for lane = 1, 2 do
          if drills[lane] and drills[lane].flow > top then top = drills[lane].flow end
          if drills[lane] and (drills[lane].dist or 0) > len then len = drills[lane].dist end -- lot FIX-P4 : longueur du tracé (distance du gisement)
        end
        if top > 0 then head_belt = Conv.choose(f, top, len) end
      end
      local fd = P.feeder(port, sources, quai_ins, head_belt, quai_n)
      -- lot s42 charbon-centrale (a) : centrale = DEUX entrées de combustible (deux coffres, deux bras ; le premier reste à combustion, le
      -- second est électrique s'il y en a un au coffre), retenues seulement si chaque pièce de plus tient sur un terrain libre ; sinon la
      -- tête d'avant, à une entrée (jamais un refus de plus : reserve_tiles est tout ou rien)
      -- s43 cc-garde : la seconde entrée attend une centrale finie, un réseau sain et du charbon au stock (Cc.second_ok)
      local done_n = 0
      for _, pid in ipairs(State.sorted_keys(b.projects or {})) do
        local q = b.projects[pid]
        if q and q.state == "fini" and q.parts and q.parts[1] and q.parts[1].kind == "centrale" then done_n = done_n + 1 end
      end
      local second = Cc.second_ok({ plants_done = done_n, healthy = (b.sante ~= nil and b.sante.healthy == true), coal = Stock.count(f, T.fuel) })
      if g.gen == "steam" and #fd.chests > 0 and second then
        local n2, arm2 = Cc.entries(M.BURNER_ARM, M.ELECTRIC_ARM, M.ELECTRIC_ARM and Stock.count(f, M.ELECTRIC_ARM) or 0)
        local fd2 = P.feeder(port, sources, quai_ins, head_belt, n2, arm2)
        local fits = true
        for _, e in ipairs(Cc.extras(fd.entities, fd2.entities)) do
          for _, t in ipairs(P.tiles_of(e)) do
            if b.occ[P.tkey(t[1], t[2])] or (place.masks and not place.masks.free(t[1], t[2])) then fits = false end
          end
        end
        for _, e in ipairs(fd2.entities) do e.part = part end
        if fits and reserve_tiles(b, p, fd2.entities) then
          fd = fd2
          b.stats.cc_double = (b.stats.cc_double or 0) + 1
          if b.stats.cc_double <= Cc.LOGS then
            log(string.format("[FO-CHARBON-CENTRALE] %s : projet %d (centrale) : %d entrees de combustible (2e bras : %s)", f.key or "player", p.id, #fd.chests, tostring(arm2)))
          end
        else
          for _, e in ipairs(fd.entities) do e.part = part end
          if not reserve_tiles(b, p, fd.entities) then return false, "tete d'alimentation" end
          b.stats.cc_simple = (b.stats.cc_simple or 0) + 1
          if b.stats.cc_simple <= Cc.LOGS then
            log(string.format("[FO-CHARBON-CENTRALE] %s : projet %d (centrale) : une seule entree de combustible (pas de place libre pour la seconde)", f.key or "player", p.id))
          end
        end
      else
        for _, e in ipairs(fd.entities) do e.part = part end
        if not reserve_tiles(b, p, fd.entities) then return false, "tete d'alimentation" end
      end
      for _, c in ipairs(fd.chests) do p.quais[#p.quais + 1] = { x = c.x, y = c.y, item = c.item } end
      -- Lot IA3-e : les poteaux des bras de quai APRÈS le tapis des foreuses (posés avant, ils prenaient les tuiles de son
      -- arrivée : tapis impossible, repli sur un quai de minerai vide ; moteur réel, e7-usine, emerald, même lot qu'en
      -- e6, 74 entités sans foreuses contre 138 avec).
      local quay_ents = {}
      for _, e in ipairs(fd.entities) do quay_ents[#quay_ents + 1] = e end
      for _, a in ipairs(fd.arrivals) do
        local d = drills[a.lane]
        if d then
          local ok, why, wait = Build.plan_drills(f, surface, p, d.item, d.flow, a, head_belt)
          if wait then return false, why, wait end -- lot TRANCHES-FOREUSES : le tracé du tapis continue à la pensée suivante (ni refus ni repli sur un quai)
          if not ok and d.need then
            bump(b.stats.plan_refused, "tapis:" .. tostring(why))
            return false, "gisement : tapis des foreuses (" .. tostring(why) .. ")"
          end
          if ok then Build.fonte_equilibre(f, p, g, d, #p.parts) end
          if not ok then
            -- repli : quai sur cette voie (le tapis n'a pas pu être tracé ou le gisement manque)
            bump(b.stats.plan_refused, "tapis:" .. tostring(why))
            local alt = P.feeder(port, { a.lane == 1 and "quai" or nil, a.lane == 2 and "quai" or nil }, quai_ins, head_belt, quai_n)
            local extra = {}
            for _, e in ipairs(alt.entities) do if e.role ~= "tete" then e.part = part; extra[#extra + 1] = e end end
            -- lot FIX-P4 : quai de repli refusé (tuiles prises) = voie jamais alimentée : l'échec remonte
            if not reserve_tiles(b, p, extra) then return false, "quai de repli : tuiles prises" end
            for _, c in ipairs(alt.chests) do p.quais[#p.quais + 1] = { x = c.x, y = c.y, item = c.item } end
            for _, e in ipairs(extra) do quay_ents[#quay_ents + 1] = e end
          end
        end
      end
      do
        local qp = quai_poles(b, p, quay_ents, place.masks, g.pole_name)
        if #qp > 0 and not reserve_tiles(b, p, qp) then return false, "poteau de quai" end
      end
    else
      -- lot AGENCEMENT : jusqu'à `place.fan` bras par tapis de sortie (2 pour une longue ligne), le second du côté extérieur
      local ins, arms = out_arms(g, place.fan)
      local q = P.out_quai(port, ins, arms, arms > 1 and P.out_side(place.inst, port) or nil)
      for _, e in ipairs(q) do e.part = part end
      if not reserve_tiles(b, p, q) then return false, "quai de sortie" end
      local qp = quai_poles(b, p, q, place.masks, g.pole_name)
      if #qp > 0 and not reserve_tiles(b, p, qp) then return false, "poteau de quai" end
      for _, e in ipairs(q) do
        if e.role == "sortie" then p.outs[#p.outs + 1] = { x = e.x, y = e.y } end
      end
    end
  end
  return true
end

--- Lot AUTO : l'emprise d'une entité `name` posée en `pos` (direction `dir`) touche-t-elle une tuile RÉSERVÉE par un projet
--- du plan directeur de l'équipe (b.occ) ? Lecture seulement ; faux sans plan directeur. Les autres poseurs (avant-postes
--- d'IA3-c) la consultent : moteur réel, a2-usine graine 271828182, emerald, un coffre d'avant-poste posé à 50 min sur le
--- tracé du tapis de la fonderie planifiée à 31 min : fantôme du tapis refusé « occupe » 18 fois, fonderie bloquée à
--- 138 entités sur 139 jusqu'à 90 min.
--- opts (lot ÉTAGE 5, revue) : opts.couloir == false : le couloir ne compte pas (adoption d'une machine posée à la main : B2, décision du lead) ;
--- opts.keep = { x0, y0, x1, y1 } (tuiles) : l'ANCIENNE emprise d'un remplacement sur place ; il n'est refusé que s'il COUPE un couloir que
--- l'ancienne laissait ouvert (B1, 2e relecture : la 3×3 électrique déborde toujours d'une colonne ET d'une rangée de la 2×2, donc sur un
--- couloir de 2 de large toute foreuse à combustion posée dessus était refusée à jamais) ; opts.blocked(x, y) : tuiles des bâtiments voisins.
--- Lot HYGIENE-PLANS-FINIS (DC 10/11) : l'UNIQUE écrivain de la cession d'une pièce POSÉE d'un plan fini à l'hygiène électrique
--- (script/team/hygiene.lua). Sans `new` : la pièce est cédée (e.dropped, p.dropped + 1 : all_built, le relevé de reconstruction, le réseau
--- vivant et la reconstruction rapide ne la reposent plus) et ses tuiles sont rendues à b.occ (le minerai dessous redevient planifiable).
--- Avec `new` = { x, y } : la pièce SUIT son remplaçant hors gisement (le plan garde son poteau : perdu, il serait reposé là) ; ses anciennes
--- tuiles sont rendues, les nouvelles prises si elles sont libres. Rend faux (rien d'écrit) si la pièce est déjà cédée ou n'est pas bâtie.
function Build.cede_piece(f, p, e, cause, new)
  local b = f and f.build
  if not (b and b.occ and p and e and e.built and not e.dropped) then return false end
  for _, t in ipairs(P.tiles_of(e)) do
    local tk = P.tkey(t[1], t[2])
    if b.occ[tk] == p.id then b.occ[tk] = nil end
  end
  if new then
    e.x, e.y = new.x, new.y
    e.ghosted, e.fails, e.npc_blocks = nil, 0, 0
    for _, t in ipairs(P.tiles_of(e)) do
      local tk = P.tkey(t[1], t[2])
      if b.occ[tk] == nil then b.occ[tk] = p.id end
    end
    e.cede = cause
  else
    e.dropped, e.cede = true, cause
    p.dropped = (p.dropped or 0) + 1
  end
  return true
end

function Build.reserved_entity(f, name, pos, dir, opts)
  local b = f and f.build
  if not (f and pos) then return false end
  local occ = b and b.occ
  -- lot ÉTAGE 5 : une emprise sur le couloir d'accès d'un avant-poste est réservée (agrandissements, tourelles, remplacements)
  local cor = (opts and opts.couloir == false) and Build.NO_COULOIR or Build.couloirs(f)
  if not occ and next(cor) == nil then return false end
  local p = game.entity_prototypes[name]
  if not p then return false end
  local w, h = p.tile_width or 1, p.tile_height or 1
  if dir == 2 or dir == 6 then w, h = h, w end
  local x0, y0 = math.floor(pos.x - w / 2 + 0.01), math.floor(pos.y - h / 2 + 0.01)
  local keep = opts and opts.keep
  local by_cor = false
  for ty = y0, y0 + h - 1 do
    for tx = x0, x0 + w - 1 do
      local k = P.tkey(tx, ty)
      if occ and occ[k] then return true end
      if cor[k] then by_cor = true end
    end
  end
  -- B1 (2e relecture, lead 5/11 17 h 38) : remplacement sur place : refusé seulement s'il sépare deux tuiles libres du couloir (Co.cuts)
  if by_cor and keep then by_cor = Build.Co.cuts(function(x, y) return cor[P.tkey(x, y)] ~= nil end, keep, { x0, y0, x0 + w - 1, y0 + h - 1 }, opts.blocked) end
  if by_cor then
    f.stats = f.stats or {}
    f.stats.couloir_emprises = (f.stats.couloir_emprises or 0) + 1 -- revue (B3)
  end
  return by_cor
end

-- Lot TUILES-RESERVEES : crochet UNIQUE des tuiles réservées (script/ai3/places_qg.lua, PlacesQG.is_reserved), lu par tous les poseurs
-- hors du plan (avant-postes, tourelles, annexes, fours et labos du QG, centre, reconstruction, remplacements de foreuse, hygiène).
PlacesQG.reserved = function(f, name, pos, dir, opts) return Build.reserved_entity(f, name, pos, dir, opts) end

--- Lot TOURELLES-HORS-AXE (retour du DC du 29/10 sur 0.6.18, défaut 4 : « le canon est en plein milieu [...] si on voulait étendre
--- sur la gauche [...] on pourrait pas »). Couloirs d'extension des lignes extensibles de l'équipe : la ligne de fours à tapis
--- (partie 1 d'un projet smelter à feed « tapis ») et chaque rangée de foreuses (partie « foreuses »). Couloir = toute la longueur
--- du lot le long de l'axe de la ligne (sa longueur maximale prévue, Li.rows_fit et P.fit : le lot), bout du tapis et quai compris,
--- sur la largeur du module plus Axe.SIDE tuile(s) de chaque côté (shared/team/axe.lua). Calculé à la demande depuis p.parts et
--- p.ents, sans état écrit : les projets des sauvegardes 0.6.18 ont leurs couloirs comme les nouveaux. Ligne fixe (MIGRATION-CHAMP,
--- spec.fixe), projet abandonné ou refusé : aucun couloir. Lecteurs : Outposts.fortify_at (crochet Outposts.corridors) et
--- move_turrets_off (une tourelle déplacée ne retombe pas dans un couloir). Liste dans l'ordre b.order, puis des parties.
function Build.corridors(f)
  local b = f and f.build
  if not (b and b.order and b.projects and b.lat) then return {} end
  local out = {}
  -- relecture : un tapis se reconnaît aussi par la liste des tapis des données (Conv.belts), pas au seul gabarit (M.spec ne connaît
  -- que le tapis de base) ; le tapis d'une rangée de foreuses est choisi au débit et amélioré en place (script/team/convoyeurs.lua
  -- réécrit e.name) : sans cela le couloir d'une rangée à tapis rapide disparaissait sans un mot. Aucun nom en dur.
  local belt_of = {}
  for _, bt in ipairs(Conv.belts()) do belt_of[bt.name] = true end
  local function is_belt(name) return belt_of[name] or (M.spec(name) or {}).kind == "belt" end
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    local spec = p and p.spec or {}
    if p and p.parts and not p.abandoned and p.state ~= "refuse" and not spec.fixe then
      for i = 1, #p.parts do
        local pt = p.parts[i]
        local ext = pt and ((i == 1 and spec.gen == "smelter" and spec.feed == "tapis") or pt.kind == "foreuses")
        if ext and pt.ox and pt.w then
          local dirs = {}
          for _, e in ipairs(p.ents) do
            if e.part == i and e.x > pt.ox and e.x < pt.ox + pt.w and e.y > pt.oy and e.y < pt.oy + pt.h
                and is_belt(e.name) then dirs[#dirs + 1] = e.dir or 0 end
          end
          local li, lj = P.lot_of(b.lat, pt.ox + pt.w / 2, pt.oy + pt.h / 2)
          if li then
            local x0, y0, x1, y1 = P.lot_rect(b.lat, li, lj)
            local c = Axe.corridor({ x0 = pt.ox, y0 = pt.oy, x1 = pt.ox + pt.w, y1 = pt.oy + pt.h },
              { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }, Axe.axis_of(dirs))
            if c then c.pid, c.part = pid, i; out[#out + 1] = c end
          end
        end
      end
    end
  end
  return out
end

--- Lot TOURELLES-HORS-AXE : couloir que recouvre l'emprise d'une entité `name` en `pos` (ou nil). `cors` : Build.corridors(f).
function Build.axis_entity(cors, name, pos)
  if not (cors and #cors > 0 and pos) then return nil end
  local pr = game.entity_prototypes[name]
  if not pr then return nil end
  return (Axe.hit(cors, Axe.tile_rect(pos.x, pos.y, pr.tile_width or 1, pr.tile_height or 1)))
end

--- Lot TOURELLES-HORS-AXE : une ligne [FO-AXE] (au plus Build.AXE_LOGS par équipe, compteur b.stats.axe_logs).
Build.AXE_LOGS = 40
function Build.axe_log(f, text)
  local st = f and f.build and f.build.stats
  if st then
    st.axe_logs = (st.axe_logs or 0) + 1
    if st.axe_logs > Build.AXE_LOGS then return end
  end
  log("[FO-AXE] " .. tostring(f and f.key or "player") .. " : " .. text)
end

-- Crochets des poseurs de tourelles (script/faction/outposts.lua, Outposts.fortify_at)
Outposts.corridors = function(f) return Build.corridors(f) end
Outposts.axe_log = function(f, text) return Build.axe_log(f, text) end

Build.ROUTE_WEIGHT = 2        -- lot AUTO : poids de l'heuristique du second tracé du tapis des foreuses (A* pondéré)
Build.DRILL_DIAG_LOGS = 24    -- lot AUTO : lignes de diagnostic des foreuses refusées, au plus, par équipe

--- Lot AUTO : diagnostic d'un refus des foreuses d'une voie (une ligne [FO-AUTO], au plus Build.DRILL_DIAG_LOGS par
--- équipe) : les lots qui portent ce minerai (état, partagé, réservé, échecs, tuiles, distance à l'arrivée) et les raisons
--- de P.fit lot par lot (essai à 1 foreuse). Lecture seulement.
function Build.drill_diag(f, item, n, a, why, diag, s)
  local b = f.build
  b.drill_logs = (b.drill_logs or 0) + 1
  if b.drill_logs > Build.DRILL_DIAG_LOGS then return end
  local lots = {}
  for _, k in ipairs(sorted_keys(b.lots)) do
    local l = b.lots[k]
    if l.ore == item or l.res == item or (l.ores and (l.ores[item] or 0) > 0) then
      local c = lot_center(b, l)
      lots[#lots + 1] = string.format("%s(%s%s%s,bad%d,%d tuiles,%d)", k, l.state .. (l.state == "refuse" and (":" .. tostring(l.reason)) or ""),
        l.shared and ",partage" or "", l.used and (",pris" .. tostring(l.used)) or "", l.bad or 0,
        (l.ores and l.ores[item]) or l.ore_n or 0, math.floor(math.abs(c.x - a.x) + math.abs(c.y - a.y)))
    end
  end
  log(string.format("[FO-AUTO] %s : foreuses %s refusees (%s) : %d foreuse(s) visees, arrivee (%d, %d)%s ; lots de %s : %s ; essais (1 foreuse) : %s",
    f.key or "player", item, tostring(why), n, a.x, a.y, s and string.format(", queue (%d, %d)", s.x, s.y) or "", item,
    #lots > 0 and table.concat(lots, " ") or "aucun", (diag and #diag > 0) and table.concat(diag, " ") or "-"))
end

--- Lot FONDERIES : le plan d'une fonderie à tapis tient-il l'équilibre entre les foreuses RÉELLEMENT planifiées (la ligne
--- peut avoir été raccourcie : plan_drills essaie n, n-1, … 1) et ses fours ? Règle pure shared/team/fonte.lua ; ici,
--- DIAGNOSTIC seulement (une ligne [FO-FONTE] et p.equilibre), rien n'est retiré ni ajouté au plan.
function Build.fonte_equilibre(f, p, g, d, part)
  local dp = p.parts[part]
  local prm = g.params or {}
  local plate = M.PLATE_OF[d.item]
  local main = g.nominal and plate and g.nominal[plate]
  if not (dp and dp.drills and dp.drills > 0 and prm.n and prm.n > 0 and main and main > 0) then return end
  local drill_rate = dp.drill_rate or 0
  local dec = Fonte.balance({ input = dp.drills * drill_rate, capacity = main / (2 * prm.n), furnaces = 2 * prm.n,
    max_furnaces = 2 * prm.n, drills = dp.drills, drill_rate = drill_rate, max_drills = dp.drills })
  p.equilibre = { action = dec.action, wanted = dec.wanted, furnaces = 2 * prm.n, drills = dp.drills }
  if dec.action ~= "equilibre" then
    log(string.format("[FO-FONTE] %s : projet %d, fonderie de %d fours pour %d foreuses (%s) : equilibre %s, %d four(s) voulu(s)",
      f.key or "player", p.id, 2 * prm.n, dp.drills, d.item, dec.action, dec.wanted))
  end
end

---------------------------------------------------------------------------------------------------
-- Lot FONDERIE-DYNAMIQUE : la ligne de fours suit les foreuses qui l'alimentent (arbitrage du DC du 29/10 au soir : « la fonderie
-- grandit en fonction du nombre de foreuses qu'elle a en input, donc dynamiquement, ni 2, ni 4, ni 8, mais dynamique »).
-- Chaîne : plan_project (place de la ligne ENTIÈRE réservée, line_rows sans budget ni plancher) -> Build.ligne_split (pièces des rangées et
-- paires au-delà de Fonte.initial gardées dans p.ligne.held, tuiles toujours à ce projet dans b.occ) -> Build.think -> Build.ligne_step
-- (toutes les T.ligne.every ticks, projet « fini ») -> read_line (foreuses qui PRODUISENT, fours posés, au moteur) -> Fonte.step ->
-- ligne_open (pièces rendues à p.ents, projet rouvert en « reserve ») -> chantier ordinaire (réserve au coffre, fantômes, PNJ) ->
-- fours ou foreuses posés au bout de la ligne. Journal : [FO-FONTE] (une ligne par action, par changement d'état, au plus
-- Build.FONTE_LOGS par équipe). État écrit : p.ligne (lecteurs : Build.ligne_step, ligne_open, Build.status ; p.ligne.missing : Build.brief.grow -> script/ai3/automatisation.lua,
-- but « alim », le cerveau fabrique les pièces du pas suivant), p.ents (chantier).
-- Projets d'avant ce lot (sans p.ligne) : inchangés, jamais relus.
---------------------------------------------------------------------------------------------------
Build.FONTE_LOGS = 40 -- lignes [FO-FONTE] de la ligne dynamique, au plus, par équipe

do
local ROW_KINDS = { drill = { drill = true }, four = { furnace = true, inserter = true } }
local SIDE_KIND = { drill = "drill", four = "furnace" }

--- Marque `field` (row : rangée de fours ; pair : paire de foreuses) sur les entités `ents` (même ordre que g.entities, g NON tourné).
function Build.tag_rows(ents, g, offset, which, field)
  if not (g and g.entities and ROW_KINDS[which]) then return end
  local kinds, side = ROW_KINDS[which], nil
  for _, e in ipairs(g.entities) do
    local sp = M.spec(e.name)
    if sp and sp.kind == SIDE_KIND[which] then side = (g.cell and g.cell.h) or sp.w break end -- (lot RETROFIT-GABARITS : pas = cellule réservée du gabarit)
  end
  if not side then return end
  local rows = Li.rows_of(g.entities, side, offset, function(e)
    local sp = M.spec(e.name)
    return sp ~= nil and kinds[sp.kind] == true
  end)
  for i, e in ipairs(ents) do if rows[i] then e[field] = rows[i] end end
end
end -- do

local function fonte_log(f, text)
  local b = f.build
  b.fonte_logs = (b.fonte_logs or 0) + 1
  if b.fonte_logs <= Build.FONTE_LOGS then log("[FO-FONTE] " .. tostring(f.key or "player") .. " : " .. text) end
end

--- Au plan (fin de plan_project) : taille de départ de la ligne (Fonte.initial : les fours que les foreuses planifiées nourrissent, borné
--- par le stock, sans plancher) ; le reste attend dans p.ligne.held. Rien pour une ligne fixe (MIGRATION-CHAMP) ou sans foreuses.
function Build.ligne_split(f, p, g)
  local cfg = T.ligne or {}
  if not cfg.dyn or p.spec.fixe then return end
  local prm = g.params or {}
  if not (g.gen == "smelter" and p.spec.feed == "tapis" and prm.ore and prm.n and prm.n > 0) then return end
  local dpi, dp
  for i = 2, #p.parts do
    local pt = p.parts[i]
    if pt and pt.kind == "foreuses" and pt.ore == prm.ore then dpi, dp = i, pt break end
  end
  if not (dp and (dp.pairs or 0) > 0) then return end
  local plate = M.PLATE_OF[prm.ore]
  local main = g.nominal and plate and g.nominal[plate]
  if not (main and main > 0) then return end
  local cap = main / (2 * prm.n)
  local budget = Li.budget_rows(Stock.count(f, T.outposts.iron.product), cfg.row_cost, cfg.stock_share, 0)
  local rows, prs, why = Fonte.initial({ rows_max = prm.n, pairs_max = dp.pairs, drill_rate = dp.drill_rate or 0, cap = cap, budget = budget })
  local keep, held = {}, {}
  for _, e in ipairs(p.ents) do
    if (e.part == 1 and e.row and e.row > rows) or (e.part == dpi and e.pair and e.pair > prs) then held[#held + 1] = e
    else keep[#keep + 1] = e end
  end
  p.ents = keep
  p.ligne = { ore = prm.ore, rows = rows, rows_max = prm.n, pairs = prs, pairs_max = dp.pairs, part = dpi, cap = cap,
    drill_rate = dp.drill_rate or 0, furnace = prm.furnace, drill = dp.drill, held = held, steps = 0 }
  fonte_log(f, string.format("projet %d, ligne dynamique %s : %d/%d rangee(s) posee(s) (%d fours), %d/%d paire(s) de foreuses (%s, budget %d unite(s)) ; place de la ligne entiere reservee, %d piece(s) en attente",
    p.id, tostring(prm.ore), rows, prm.n, 2 * rows, prs, dp.pairs, why, budget, #held))
end

local read_line
do
local PRODUCING, DEPLETED -- mémoire LOCALE (constantes du moteur), jamais dans global
local function in_part(pt, pos) return pos.x > pt.ox and pos.x < pt.ox + pt.w and pos.y > pt.oy and pos.y < pt.oy + pt.h end

--- Relevé au moteur d'une ligne bâtie : foreuses de sa partie (qui produisent, épuisées, autres), entrée réelle (vitesse du prototype
--- posé, niveaux compris, et productivité minière de la force), fours de son module et leur capacité. Lecture seulement.
function read_line(f, surface, p, ln)
  if not PRODUCING then
    local s = defines.entity_status
    PRODUCING = { [s.working] = true, [s.low_power] = true, [s.waiting_for_space_in_destination] = true }
    DEPLETED = s.no_minable_resources
  end
  local fo = game.forces[f.force]
  local dpt, mpt = p.parts[ln.part], p.parts[1]
  if not (fo and dpt and mpt) then return nil, "parties absentes" end
  local bonus = 1 + (fo.mining_drill_productivity_bonus or 0)
  local dbase = ln.drill and game.entity_prototypes[ln.drill]
  local fbase = ln.furnace and game.entity_prototypes[ln.furnace]
  local r = { drills = 0, live = 0, dead = 0, other = 0, input = 0, furnaces = 0, capsum = 0 }
  local found = surface.find_entities_filtered({ area = { { dpt.ox, dpt.oy }, { dpt.ox + dpt.w, dpt.oy + dpt.h } }, type = "mining-drill", force = fo })
  for _, d in ipairs(found) do
    if in_part(dpt, d.position) then -- F96 : une foreuse voisine qui touche seulement le bord ne compte pas
      r.drills = r.drills + 1
      local st = d.status
      if PRODUCING[st] then
        r.live = r.live + 1
        local k = (dbase and dbase.mining_speed > 0) and (d.prototype.mining_speed / dbase.mining_speed) or 1
        r.input = r.input + ln.drill_rate * k * bonus
      elseif st == DEPLETED then r.dead = r.dead + 1
      else r.other = r.other + 1 end
    end
  end
  found = surface.find_entities_filtered({ area = { { mpt.ox, mpt.oy }, { mpt.ox + mpt.w, mpt.oy + mpt.h } }, type = "furnace", force = fo })
  for _, m in ipairs(found) do
    if in_part(mpt, m.position) then
      r.furnaces = r.furnaces + 1
      local k = (fbase and fbase.crafting_speed > 0) and (m.prototype.crafting_speed / fbase.crafting_speed) or 1
      r.capsum = r.capsum + ln.cap * k
    end
  end
  return r
end
end -- do

--- Rend à p.ents les pièces des rangées 1..rows+add_r et des paires 1..pairs+add_p ; le projet fini est rouvert (« reserve ») et suit
--- le chantier ordinaire. p.reopened : non annulable tant que ses pièces ne sont pas posées (Build.cancel) ; reopened_tick n'est PAS
--- écrit (un agrandissement ne retient pas les améliorations, Sw.project_holds). Rend le nombre de pièces rendues.
local function ligne_takes(ln, e, nr, np)
  return (e.part == 1 and e.row and e.row <= nr) or (e.part == ln.part and e.pair and e.pair <= np)
end

--- Objets d'une pièce à poser, comme needs_of les compte pour la réserve (charbon d'amorce d'un bras à combustible compris, noms lus
--- dans les données : M.BURNER_ARM, T.outposts.coal) ; sinon le pas rouvert attendait en « reserve » un charbon jamais compté
--- (relecture FONDERIE-DYNAMIQUE).
local function piece_needs(need, e)
  bump(need, e.item)
  if M.BURNER_ARM and e.name == M.BURNER_ARM then bump(need, T.outposts.coal.product, 2) end
end

--- « Ressources d'abord » : objets qui MANQUENT au stock libre (coffre moins les réserves des tâches, Board.view_stock) pour les pièces
--- d'un pas. Un pas n'est lancé que tout réuni : un projet rouvert qui attend ses matériaux en « reserve » ne sert plus ses quais (charbon
--- des fours, quai_tasks ne tourne qu'en « fini » et « chantier ») et la partie déjà bâtie s'arrêterait. Rend une liste { objet, n } triée ;
--- ligne_one la garde dans ln.missing, que le cerveau fabrique (Build.brief.grow).
local function ligne_missing(f, ln, nr, np)
  local need = {}
  for _, e in ipairs(ln.held) do
    if ligne_takes(ln, e, nr, np) and e.item then piece_needs(need, e) end
  end
  local free = Board.view_stock(f, Stock.contents(f), game.tick)
  local out = {}
  for _, it in ipairs(sorted_keys(need)) do
    local have = math.min(Stock.count(f, it), free[it] or 0)
    if have < need[it] then out[#out + 1] = { it, need[it] - have } end
  end
  return out
end

local function ligne_open(p, ln, add_r, add_p, tick)
  local nr, np = ln.rows + add_r, ln.pairs + add_p
  local keep, moved = {}, 0
  for _, e in ipairs(ln.held) do
    if ligne_takes(ln, e, nr, np) then
      e.built, e.ghosted, e.fails, e.npc_blocks = false, nil, 0, 0
      p.ents[#p.ents + 1] = e
      moved = moved + 1
    else
      keep[#keep + 1] = e
    end
  end
  ln.held, ln.rows, ln.pairs = keep, nr, np
  if moved > 0 then
    ln.steps = (ln.steps or 0) + 1
    ln.grown = tick
    p.counted = true -- déjà compté aux statistiques
    p.state, p.reason, p.reserve_next = "reserve", "fonderie : agrandissement", nil
    p.retries, p.retry_at = 0, nil
    p.reopened = (p.reopened or 0) + 1
  end
  return moved
end

--- Pièces POSÉES attendues d'une ligne (foreuses de ses paires, fours de ses rangées), lues dans p.ents : une pièce abandonnée (e.dropped :
--- refus répétés ; e.gave_up : le relevé de reconstruction y a renoncé) n'est plus au monde et n'est plus attendue. Sans cela (2 × paires,
--- 2 × rangées) une seule pièce abandonnée laissait la ligne en « pieces » pour toute la partie, sans croissance (relecture du lot).
local function ligne_expected(p, ln)
  local nd, nf = 0, 0
  for _, e in ipairs(p.ents) do
    if not (e.dropped or e.gave_up) then
      if e.part == ln.part and e.pair then nd = nd + 1
      elseif e.part == 1 and e.row and (M.spec(e.name) or {}).kind == "furnace" then nf = nf + 1 end
    end
  end
  return nd, nf
end

--- Une ligne bâtie : relevé, décision (Fonte.step), action. Rend vrai si la ligne a été agrandie. Écrit ln.missing (lecteur : Build.brief,
--- champ `grow`, puis script/ai3/automatisation.lua qui en fait un but « alim:<produit> » : le cerveau FABRIQUE les fours et foreuses du
--- pas suivant ; sans lecteur, un pas « materiaux » n'avançait que si le coffre avait par hasard des pièces de rechange).
local function ligne_one(f, surface, p, ln, cfg, tick)
  local r, why = read_line(f, surface, p, ln)
  local action, dec, cause = "attente", nil, "parties"
  ln.missing = nil
  local want_d, want_f = ligne_expected(p, ln)
  if r and (r.drills < want_d or r.furnaces < want_f or r.furnaces < 1) then
    cause = "pieces"
    why = string.format("pieces manquantes (%d/%d foreuses, %d/%d fours) : releve de reconstruction", r.drills, want_d, r.furnaces, want_f)
  elseif r and r.other > 0 then
    cause = "arret"
    why = string.format("%d foreuse(s) a l'arret (courant, commande) : rien a mesurer", r.other)
  elseif r then
    local budget = Li.budget_rows(Stock.count(f, T.outposts.iron.product), cfg.row_cost, cfg.stock_share, 0)
    dec = Fonte.step({ input = r.input, cap = r.capsum / r.furnaces, rows = ln.rows, rows_max = ln.rows_max, drills = r.live,
      drill_rate = r.live > 0 and (r.input / r.live) or ln.drill_rate, pairs = ln.pairs, pairs_max = ln.pairs_max, budget = budget,
      step_rows = cfg.step_rows, step_pairs = cfg.step_pairs })
    action, cause = dec.action, dec.action
    why = string.format("entree %.2f/s de %d foreuse(s) qui produisent (%d epuisee(s)), %d four(s) a %.3f/s (%d voulu(s)), budget %d unite(s)",
      r.input, r.live, r.dead, r.furnaces, r.capsum / r.furnaces, dec.furnaces, budget)
  end
  local moved = 0
  if dec and (dec.rows > 0 or dec.pairs > 0) then
    local miss = ligne_missing(f, ln, ln.rows + dec.rows, ln.pairs + dec.pairs)
    if #miss > 0 then
      local parts = {}
      for _, m in ipairs(miss) do parts[#parts + 1] = m[1] .. " x" .. m[2] end
      action, cause = "materiaux", "materiaux:" .. dec.action
      ln.missing = miss -- à fabriquer par le cerveau (Build.brief.grow -> automatisation, but « alim »)
      why = why .. " ; manque au coffre {" .. table.concat(parts, ", ") .. "} (" .. dec.action .. " remis, demande au cerveau)"
    else
      moved = ligne_open(p, ln, dec.rows, dec.pairs, tick)
    end
  end
  if moved > 0 or cause ~= ln.cause then -- une ligne par action, et par changement d'état ou de cause d'attente
    ln.last, ln.cause = action, cause
    fonte_log(f, string.format("projet %d, ligne %s : action %s (+%d rangee(s), +%d paire(s), %d piece(s) a poser) -> %d/%d rangee(s), %d/%d paire(s) ; %s a %.1f min",
      p.id, tostring(ln.ore), action, dec and dec.rows or 0, dec and dec.pairs or 0, moved, ln.rows, ln.rows_max, ln.pairs, ln.pairs_max,
      tostring(why), tick / 3600))
  end
  return moved > 0
end

--- Relevé des lignes dynamiques d'une équipe (appelé par Build.think) : au plus un agrandissement par équipe et par relevé.
function Build.ligne_step(f, surface, tick)
  local b = f.build
  local cfg = T.ligne or {}
  if not (b and surface and cfg.dyn) then return end
  if tick < (b.ligne_next or 0) then return end
  b.ligne_next = tick + (cfg.every or 3600)
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    local ln = p and p.ligne
    if ln and p.state == "fini" and not p.abandoned and tick - (p.finished or 0) >= (cfg.settle or 0) then
      -- Lot FUITES-PILE : un agrandissement est un investissement de production ; pendant une retenue, seulement pour une matière d'un
      -- cadre ouvert ou qui manque (la ligne déjà bâtie continue de produire) ; ses pièces ne sont plus demandées (ln.missing)
      if not Build.grow_suspended(f, p, ln, tick) and ligne_one(f, surface, p, ln, cfg, tick) then return end
    end
  end
end

--- Foreuses de ravitaillement d'une voie et leur tapis jusqu'à l'arrivée `a`. Rend true, ou false et raison.
function Build.plan_drills(f, surface, p, item, flow, a, belt)
  local b = f.build
  belt = belt or Conv.choose(f, flow) or "transport-belt" -- lot CONVOYEURS
  local n = math.max(1, math.ceil(flow / (2 * M.spec("electric-mining-drill").speed) - 1e-9))
  local place, why
  local diag = {}
  -- lot AGENCEMENT (retour du DC du 29/10 : « on veut des rangées de foreuses ») : la ligne ne dépasse pas ce qu'un collecteur porte
  -- (le gabarit le dit), s'essaie d'abord à 80 % de tuiles minées portant du minerai SANS réduire la ligne (relecture : une ligne
  -- plus courte à 80 % n'a pas le droit de battre la ligne voulue à la couverture d'avant), puis redescend comme avant (n, n−1, … 1) ;
  -- les relevés d'un lot servent à toutes les tailles essayées (`cache`)
  local g1 = M.GEN.drills(item, 1)
  local pmax = g1 and g1.extensions and g1.extensions[1] and g1.extensions[1].max or n
  local top = math.max(1, math.min(n, pmax))
  if p.spec and p.spec.paires then top = math.max(1, math.min(top, p.spec.paires)) end -- lot MIGRATION-CHAMP : la ligne tient dans la place libérée
  local cfg = T.ligne or {}
  local cache, picked, pg = scan_cache(f), nil, nil -- pg : le gabarit NON tourné posé (lot FONDERIE-DYNAMIQUE : paires de foreuses)
  for _, at in ipairs(Rg.attempts(top, top, { high = cfg.cover })) do
    local nn = at.n
    local g = M.with_pole(p.spec and p.spec.pole, M.GEN.drills, item, nn)
    if not g and p.spec and p.spec.pole then g = M.GEN.drills(item, nn) end
    if g then
      place, why = place_module(f, surface, g, { gisement = true }, { x = a.x, y = a.y }, item,
        { nobad = true, diag = (nn == 1 and not at.cover) and diag or nil, cover_min = at.cover, cache = cache,
          within = p.spec and p.spec.degel and p.spec.degel.zone or nil })
      if place then picked, pg = at, g break end
    end
  end
  if not place then
    -- Lot GISEMENTS (« tapis des foreuses (minerai) », 1 144 refus au journal du DC) : dernier essai, une paire en bord de gisement ; le
    -- débit d'une foreuse ne dépend pas du nombre de tuiles minées, seule sa durée de vie en dépend. « Exploitent toujours à 100 % ».
    local g = M.with_pole(p.spec and p.spec.pole, M.GEN.drills, item, 1)
    if not g and p.spec and p.spec.pole then g = M.GEN.drills(item, 1) end
    if g then
      place = place_module(f, surface, g, { gisement = true }, { x = a.x, y = a.y }, item,
        { nobad = true, cover_min = Gisements.COVER_LOW, cache = cache, within = p.spec and p.spec.degel and p.spec.degel.zone or nil })
      if place then picked, pg = { n = 1, cover = Gisements.COVER_LOW }, g end
      -- lot TV-REPLI (TODO_VIDEO C07) : plus aucun lot du treillis, et il ne grandit plus : la paire de foreuses va au bord du gisement,
      -- dans une fenêtre libre et sûre autour de lui (mêmes tuiles libres, même couverture minimale que le dernier essai)
      if not place and not Build.can_grow(b) then
        place = Build.Repli.try(f, surface, g, { p = p, why = why, res = item, center = deposit_toward(b, item) or { x = a.x, y = a.y },
          fopts = { toward = { x = a.x, y = a.y }, cover_min = Gisements.COVER_LOW },
          read_masks = read_masks, ore_set = ore_set, avoid_margin = Build.AVOID_MARGIN })
        if place then picked, pg = { n = 1, cover = Gisements.COVER_LOW }, g end
      end
    end
  end
  if not place then
    Build.drill_diag(f, item, n, a, why, diag)
    return false, why
  end
  local part = #p.parts + 1
  p.parts[part] = { kind = "foreuses", key = place.g.key, lot = place.lot or (place.repli and "repli") or nil, ox = place.ox, oy = place.oy, k = place.k,
    w = place.g.w, h = place.g.h, power = needs_power(place.g), belt = belt, flow = flow,
    drills = 2 * ((place.g.params or {}).n or 0),
    drill_rate = (M.spec((place.g.params or {}).drill or "") or {}).speed or 0,
    pairs = (place.g.params or {}).n, cover = place.cover, ore = item, drill = (place.g.params or {}).drill }
  local resumed = p.rs_drills ~= nil or p.rs_done ~= nil -- lot TRANCHES-FOREUSES : reprise du tracé pondéré (le journal et les compteurs de cette ligne ne se répètent pas)
  if not resumed then b.stats.rangees = (b.stats.rangees or 0) + 1 end
  if not resumed and b.stats.rangees <= Build.LINE_LOGS then
    log(string.format("[FO-RANGEES] %s : projet %d, foreuses %s : %d paire(s) (%d foreuses) visees %d, couverture %d%% (visee %d%%), %.2f minerai/s demandes",
      f.key or "player", p.id, item, (place.g.params or {}).n or 0, 2 * ((place.g.params or {}).n or 0), n,
      math.floor((place.cover or 0) * 100 + 0.5), picked and picked.cover and math.floor(picked.cover * 100 + 0.5) or math.floor(P.DRILL_COVER * 100 + 0.5), flow))
  end
  -- lot PD-FONDERIEQG (D82) : sens du gisement dans le lot, sens du collecteur choisi, distance de sa sortie à l'arrivée
  do
    local la
    for _, port in ipairs(P.belt_ports(place.inst)) do if port.io == "out" then la = Or.line_axis(port.dir) end end
    if not resumed then b.stats.orient = (b.stats.orient or 0) + 1 end
    if not resumed and b.stats.orient <= Build.LINE_LOGS then
      log(string.format("[FO-ORIENT] %s : projet %d, foreuses %s : gisement %s dans le lot %s, collecteur %s%s, sortie a %d tuile(s) de l'arrivee",
        f.key or "player", p.id, item, place.axis == "y" and "vertical" or (place.axis == "x" and "horizontal" or "sans sens (rond ou petit)"),
        place.lot or "repli", la == "y" and "vertical" or "horizontal", (place.pen or 0) > 0 and " (en travers : meilleure couverture ou place)" or "",
        math.floor((place.d or 0) + 0.5)))
    end
  end
  local ents = inst_entities(place.inst, part, belt)
  Build.tag_rows(ents, pg, 1, "drill", "pair") -- lot FONDERIE-DYNAMIQUE : paire de chaque foreuse (pose par étapes, ligne_split)
  -- tapis : queue des foreuses → arrivée
  local tail
  for _, port in ipairs(P.belt_ports(place.inst)) do if port.io == "out" then tail = port end end
  local v = P.DV[tail.dir]
  local s = { x = tail.x + v[1], y = tail.y + v[2] }
  local bx0 = math.min(s.x, a.x) - 12
  local by0 = math.min(s.y, a.y) - 12
  local bx1 = math.max(s.x, a.x) + 12
  local by1 = math.max(s.y, a.y) + 12
  -- lot ENERGIE : le tapis d'alimentation d'une centrale (spec.alim) dépasse la boîte de 120 tuiles (Cv.reach) ; mesuré au 31/10 : 17 refus
  -- « trop loin » sur 31 demandes, aucune centrale nourrie par des foreuses. Lot VAPEUR-RELAIS (11/11) : le tapis long est le MÊME tracé que le
  -- tapis ordinaire (Tdr.trace dans la boîte entière : souterrains, tranches, preuve de pureté), plus de tronçons par points de passage fixes
  -- (partie du DC en 0.7.3 : refus « point de passage » du relais dès que le milieu de la droite était bâti, centrales 13, 50 et 68 nourries à la main)
  if bx1 - bx0 > 120 or by1 - by0 > 120 then
    local mode = nil
    if p.spec and (p.spec.alim or p.spec.alimquai) then mode = Cv.reach(s.x, s.y, a.x, a.y) end -- lot FONDERIE-BLOC : l'alimentation d'un coffre de champ aussi
    if mode ~= "long" then return false, "trop loin" end
  end
  -- lot TRANCHES-FOREUSES : les trois essais du tapis (exact, exact avec marge, pondéré) se calculent par TRANCHES de Tdr.SLICE états, une par pensée
  -- du plan (script/team/foreuses_tranches.lua). Les masques sont posés par l'essai.
  local Tdr = Build.TrancheForeuses
  local tsig = Tdr.sig(s, a, belt, tail.dir, place)
  local rsd = Tdr.resume(p, tsig, game.tick)
  if Tdr.unstable(p) then p.rs_drills, p.parts[part] = nil, nil; return false, "tapis : trace instable" end
  local masks = { water = {}, blocked = {}, clear = {} } -- remplis par l'essai en cours (Tdr.trace)
  -- anneau d'une tuile autour des modules (aucun tapis ne longe un module : bras, têtes, queues)
  local ring = {}
  local function ring_of(ox, oy, w, h)
    for x = ox - 1, ox + w do ring[P.tkey(x, oy - 1)] = true; ring[P.tkey(x, oy + h)] = true end
    for y = oy - 1, oy + h do ring[P.tkey(ox - 1, y)] = true; ring[P.tkey(ox + w, y)] = true end
  end
  for _, pt in ipairs(p.parts) do ring_of(pt.ox, pt.oy, pt.w, pt.h) end
  local planned = {}
  for _, e in ipairs(ents) do for _, t in ipairs(P.tiles_of(e)) do planned[P.tkey(t[1], t[2])] = true end end
  local sk, ak = P.tkey(s.x, s.y), P.tkey(a.x, a.y)
  -- lot PURETE-TAPIS (journal du DC du 8/11 : « une ligne d'output ne doit jamais fusionner avec une ligne d'input qui attend un objet différent ») : ce
  -- tracé n'avait AUCUN garde de la tuile devant un tapis existant ; la tuile où un tapis étranger (plan ou monde) verse reste libre
  local pure_front = Build.Pur.fronts(f, surface, item, p)
  local function cost(x, y)
    local k = P.tkey(x, y)
    if k ~= sk and k ~= ak and ring[k] then return nil end
    if masks.water[k] or masks.blocked[k] or b.occ[k] or planned[k] then return nil end
    if pure_front(x, y) then return nil end
    local c = 1
    if P.in_street(b.lat, x, y) then c = P.STREET_COST end
    if masks.clear[k] then c = c + 1 end
    return c
  end
  local tiles, n2
  local tnames -- lot TRAVERSEE : nom du souterrain d'un tracé qui en pose
  local topts = { belt = belt, sd = tail.dir, kind = "foreuses" }
  do
    -- (essai 1 : exact dans la boîte des extrémités + 12 ; essai 2 : marge d'un pas de treillis, contourner une falaise par la brèche voisine, correction du
    -- 27/10 ; essai 3, lot AUTO (« tapis des foreuses (trop long) » chez scarlet, e15-usine graine 271828182) : l'A* exact s'arrêtait à P.ASTAR_MAX nœuds
    -- dans une boîte qui en compte jusqu'à 14 400 ; nouvel essai PONDÉRÉ (heuristique × Build.ROUTE_WEIGHT) sur toute la boîte : un tapis un peu plus long,
    -- ou « aucun chemin ». 0.6.72 : budget PROPRE à l'essai 3 (la boîte entière), hors du budget partagé Tv.PLAN_BUDGET (4000) qui le refusait toujours en
    -- « trop long » depuis 0.6.68 : 0 champ électrique en partie neuve)
    local first
    tiles, n2, tnames, first = Tdr.trace({ p = p, sig = tsig, tick = game.tick, rsd = rsd, s = s, a = a, pitch = P.PITCH,
      box1 = { x0 = bx0, y0 = by0, x1 = bx1, y1 = by1 }, topts = topts, weight = Build.ROUTE_WEIGHT,
      max_of = function(bx) return (bx.x1 - bx.x0 + 1) * (bx.y1 - bx.y0 + 1) end,
      read = function(x0, y0, x1, y1) return read_masks(f, surface, x0, y0, x1, y1) end,
      set_masks = function(m) masks.water, masks.blocked, masks.clear = m.water, m.blocked, m.clear end,
      route = function(bx, o) return Build.Trav.route(f, surface, p, s, { x = a.x, y = a.y }, a.dir, bx, cost, o) end })
    if tiles == "pending" then
      p.parts[part] = nil -- rien n'est réservé par ce plan-ci ; l'appelant rend ce qu'il a réservé (attente « foreuses ») et rappelle à la pensée suivante
      return false, "foreuses : trace du tapis en cours (essai " .. tostring(p.rs_drills and p.rs_drills.stage or "?") .. ")", "foreuses"
    end
    if first then
      bump(b.stats.plan_refused, "tapis-pondere:" .. (tiles and "ok" or tostring(n2)))
      if not tiles then n2 = first .. ", pondere : " .. tostring(n2) end
    end
  end
  if not tiles then
    p.parts[part] = nil
    Build.drill_diag(f, item, n, a, "tapis " .. tostring(n2), nil, s)
    return false, n2
  end
  do
    -- lot PURETE-TAPIS : la preuve du tracé (causes a, b, c, d) contre une lecture fraîche du monde ; la tuile devant l'arrivée est la cible
    local own = {}
    for k in next, planned do own[k] = true end -- (copie d'un ensemble : l'ordre n'a aucun effet)
    local av = P.DV[a.dir or 0]
    local targets = {}
    if av then targets[P.tkey(a.x + av[1], a.y + av[2])] = true end
    local pok, pwhy = Build.Pur.check_route(f, surface, p, "foreuses", tiles, item, targets, { own = own })
    if not pok then
      p.parts[part] = nil
      Build.drill_diag(f, item, n, a, "tapis " .. tostring(pwhy), nil, s)
      return false, pwhy
    end
  end
  for _, e2 in ipairs(Build.Trav.entities(tiles, { belt = belt, ug = tnames and tnames.ug }, "liaison-tapis")) do
    e2.part = part
    ents[#ents + 1] = e2
  end
  if not reserve_tiles(b, p, ents) then p.parts[part] = nil; return false, "place" end
  if place.lot then b.lots[place.lot].used = p.id end -- (lot TV-REPLI : un repli n'a pas de lot du treillis)
  return true
end

--- Tuile libre pour un point d'appui, au plus près de (x, y) : ni réservée par un projet (emprise d'une entité
--- planifiée, de cette équipe), ni eau, ni bâtie (relevé `masks`, quand il couvre la tuile), ni arbre (`trees`) ; de
--- préférence avec ses 8 voisines libres (le PNJ s'arrête à une tuile près du point). Anneaux de Chebyshev de rayon 0 à
--- Build.ANCHOR_SEARCH, ordre fixe (distance, puis y, puis x). Rend le centre de la tuile ; à défaut une tuile libre
--- sous un arbre ; sans tuile libre, le point tel quel.
local function free_spot(b, masks, x, y, trees)
  local function free(tx, ty, wood)
    local k = P.tkey(tx, ty)
    if b.occ[k] then return false end
    if masks and (masks.water[k] or masks.blocked[k]) then return false end
    if not wood and ((trees and trees[k]) or (masks and masks.clear and masks.clear[k])) then return false end
    return true
  end
  local function clear3(tx, ty)
    for dy = -1, 1 do for dx = -1, 1 do if not free(tx + dx, ty + dy) then return false end end end
    return true
  end
  local x0, y0 = math.floor(x), math.floor(y)
  local fallback, fallback2
  for r = 0, Build.ANCHOR_SEARCH do
    local ring = {}
    for dy = -r, r do
      for dx = -r, r do
        if math.max(math.abs(dx), math.abs(dy)) == r then ring[#ring + 1] = { dx, dy } end
      end
    end
    table.sort(ring, function(u, v)
      local du, dv = u[1] * u[1] + u[2] * u[2], v[1] * v[1] + v[2] * v[2]
      if du ~= dv then return du < dv end
      if u[2] ~= v[2] then return u[2] < v[2] end
      return u[1] < v[1]
    end)
    for _, d in ipairs(ring) do
      local tx, ty = x0 + d[1], y0 + d[2]
      if clear3(tx, ty) then return tx + 0.5, ty + 0.5 end
      if not fallback and free(tx, ty) then fallback = { tx + 0.5, ty + 0.5 } end
      if not fallback2 and free(tx, ty, true) then fallback2 = { tx + 0.5, ty + 0.5 } end
    end
  end
  if fallback then return fallback[1], fallback[2] end
  if fallback2 then return fallback2[1], fallback2[2] end
  return x, y
end

--- Arbres et rochers sur l'emprise de TOUTES les entités d'un projet (un appel sur leur boîte englobante, au plan) :
--- { [tuile] = true }. Correction du 27/10 : seul le relevé du module principal était lu, et les arbres sous les
--- foreuses et leur tapis n'étaient découverts qu'à la pose (banc ia1-build-foret).
local wood_of
do
local STRETCHED = { reseau = true, rue = true, liaison = true, ["liaison-tapis"] = true }

function wood_of(surface, ents)
  -- une boîte par pièce compacte (module, foreuses, têtes) ; entité par entité pour ce qui s'étire (poteaux de rue et de
  -- liaison, tapis de liaison) : un seul appel sur la boîte de tout le projet coûtait jusqu'à 68 ms en forêt (27/10)
  local boxes, order = {}, {}
  local out = {}
  local function mark(area)
    for _, t in ipairs(surface.find_entities_filtered({ area = area, type = TREE_TYPES })) do
      local bb = t.bounding_box
      for ty = math.floor(bb.left_top.y + 0.01), math.ceil(bb.right_bottom.y - 0.01) - 1 do
        for tx = math.floor(bb.left_top.x + 0.01), math.ceil(bb.right_bottom.x - 0.01) - 1 do out[P.tkey(tx, ty)] = true end
      end
    end
  end
  for _, e in ipairs(ents) do
    local w, h = P.size(e.name, e.dir)
    if STRETCHED[e.role or ""] then
      mark({ { e.x - w / 2 - 1, e.y - h / 2 - 1 }, { e.x + w / 2 + 1, e.y + h / 2 + 1 } })
    else
      local k = e.part or 0
      local bx = boxes[k]
      if not bx then bx = { math.huge, math.huge, -math.huge, -math.huge }; boxes[k] = bx; order[#order + 1] = k end
      bx[1], bx[2] = math.min(bx[1], e.x - w / 2), math.min(bx[2], e.y - h / 2)
      bx[3], bx[4] = math.max(bx[3], e.x + w / 2), math.max(bx[4], e.y + h / 2)
    end
  end
  table.sort(order)
  for _, k in ipairs(order) do
    local bx = boxes[k]
    mark({ { bx[1] - 1, bx[2] - 1 }, { bx[3] + 1, bx[4] + 1 } })
  end
  return out
end
end -- do

--- Ajoute un obstacle au projet (une fois par tuile).
local function add_obstacle(p, o)
  local k = P.tkey(math.floor(o.x), math.floor(o.y))
  p.obst_keys = p.obst_keys or {}
  p.obst_faits = nil -- lot UPS : un obstacle rouvert ou ajouté : la revue relit la liste (review_obstacles)
  if p.obst_keys[k] then
    for _, q in ipairs(p.obstacles) do if q.k == k then q.done = nil end end
    return
  end
  p.obst_keys[k] = true
  o.k = k
  p.obstacles[#p.obstacles + 1] = o
end

--- Revue de Build.OBST_CHECKS obstacles ouverts (à tour de rôle) : faits quand plus aucun arbre ni rocher n'y est.
--- Rend le nombre d'obstacles encore ouverts.
local function review_obstacles(surface, p)
  -- Lot UPS : la revue parcourait TOUTE la liste à chaque passe (toutes les 5 ticks, pour chaque projet en chantier), même quand tous
  -- les obstacles étaient déjà faits. p.obst_faits garde la LISTE (la table elle-même) dont la dernière revue n'a laissé aucun obstacle
  -- ouvert : tant que c'est encore elle (une liste neuve du plan est une autre table) et que rien n'y a été ajouté ni rouvert
  -- (add_obstacle efface la marque ; un obstacle fait ne se rouvre que là), la revue rendrait 0 sans rien écrire : elle est sautée.
  if p.obst_faits ~= nil and p.obst_faits == p.obstacles then return 0 end
  -- Lot AGEBLOCAGE : le curseur repart juste après le dernier obstacle revu (règle pure shared/team/revue_obstacles.lua). L'ancienne
  -- boucle faisait n pas : son curseur revenait à son départ, les mêmes obstacles étaient revus à chaque appel et les autres restaient
  -- ouverts, même vides (banc ageblocage-dc 717152950 : 68 obstacles vides d'Azur jamais revus de 37 à 57 min, curseur bloqué à n + 1,
  -- 30 à 44 défrichages par 5 min sur des rectangles vides, fabrications à l'arrêt).
  local left, cur = Build.RevueObst.review(p.obstacles, p.obst_cur, Build.OBST_CHECKS, function(o)
    return surface.count_entities_filtered({ area = { { o.x - 0.45, o.y - 0.45 }, { o.x + 0.45, o.y + 0.45 } }, type = TREE_TYPES, limit = 1 }) > 0
  end)
  p.obst_cur = cur
  p.obst_faits = (left == 0) and p.obstacles or nil
  return left
end

---------------------------------------------------------------------------------------------------
-- Lot ESPACE : enceinte (anneau de murs au-delà du treillis ; règle pure : shared/team/enceinte.lua)
---------------------------------------------------------------------------------------------------
--- Relevé des zones d'un projet d'enceinte (rectangles { x0, y0, x1, y1 }) : eau, bloqué, défrichable (read_masks) et
--- tuiles de RESSOURCE (jamais murées).
local function enc_masks(f, surface, areas)
  local m = { water = {}, blocked = {}, clear = {}, ore = {} }
  for _, bd in ipairs(areas) do
    local r = read_masks(f, surface, bd[1], bd[2], bd[3], bd[4])
    for k in pairs(r.water) do m.water[k] = true end
    for k in pairs(r.blocked) do m.blocked[k] = true end
    for k in pairs(r.clear) do m.clear[k] = true end
    for _, e in ipairs(surface.find_entities_filtered({ area = { { bd[1], bd[2] }, { bd[3], bd[4] } }, type = "resource" })) do
      m.ore[P.tkey(math.floor(e.position.x), math.floor(e.position.y))] = true
    end
  end
  return m
end

--- Zones à relever pour l'anneau ENTIER (projet d'une sauvegarde d'avant ENCEINTE2) : quatre bandes de 11 tuiles d'épaisseur
--- vers l'intérieur (de quoi y placer les points d'appui, sur la dernière rue).
local function ring_areas(x0, y0, x1, y1)
  return {
    { x0 - 1, y0 - 1, x1 + 2, y0 + 10 }, { x0 - 1, y1 - 9, x1 + 2, y1 + 2 },
    { x0 - 1, y0 - 1, x0 + 10, y1 + 2 }, { x1 - 9, y0 - 1, x1 + 2, y1 + 2 },
  }
end

--- Lot ENCEINTE3 (retour du DC, Azur : « ils ont vraiment placé super loin ») : contour SERRÉ sur l'empreinte réelle de la base.
--- Empreinte = lots pris par un projet vivant (planifié ou fini), lot du QG, tourelles de l'équipe ; + E.MARGIN tuiles ; les lots
--- et tourelles ISOLÉS (plus de E.ISOLATED_GAP tuiles) restent dehors ; les E.ROOM_LOTS lots libres les plus proches restent dedans.
--- Rend ({ x0, y0, x1, y1 } = tuiles du mur, incluses, info) ou nil (ouvertures hors bornes : repli sur le rayon d'avant).
local function enc_tight_bounds(f)
  local b = f.build
  local rects, room = {}, {}
  for _, k in ipairs(sorted_keys(b.lots)) do
    local l = b.lots[k]
    local x0, y0, x1, y1 = P.lot_rect(b.lat, l.i, l.j)
    local box = { x0 = x0, y0 = y0, x1 = x1, y1 = y1, k = k }
    if l.used then
      local p = b.projects[l.used]
      if p and p.state ~= "refuse" and not (p.spec and p.spec.enceinte) then rects[#rects + 1] = box end
    elseif (l.state == "libre" or l.state == "defricher") and not (l.i == 0 and l.j == 0) and not (l.bad and l.bad >= 2) and not l.out then
      room[#room + 1] = box
    end
  end
  for _, id in ipairs(sorted_keys(f.turrets or {})) do
    local t = f.turrets[id]
    if t and t.valid then
      local x, y = t.position.x, t.position.y
      rects[#rects + 1] = { x0 = math.floor(x - 1), y0 = math.floor(y - 1), x1 = math.ceil(x + 1), y1 = math.ceil(y + 1) }
    end
  end
  local cx0, cy0, cx1, cy1 = Enc.bounds(b.lat, b.radius) -- relecture ENCEINTE3 : jamais plus large que l'anneau du rayon
  local bounds, info = Enc.tight_bounds(b.lat, rects, room, { clamp = { cx0, cy0, cx1, cy1 } })
  if not Enc.gates_inside(b.lat, bounds) then return nil end
  return bounds, info
end

--- Lot ENCEINTE3 : les lots libres que le mur coupe ou laisse dehors ne reçoivent plus de module (drapeau `out`, lu par
--- `candidates` et Enc.free_count) ; un lot de GISEMENT reste utilisable dehors (les mines d'avant-poste).
local function enc_mark_out(b, bounds)
  local n = 0
  for _, k in ipairs(sorted_keys(b.lots)) do
    local l = b.lots[k]
    local x0, y0, x1, y1 = P.lot_rect(b.lat, l.i, l.j)
    if not (l.i == 0 and l.j == 0) and not Enc.inside(bounds, { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }) then
      l.out = true
      n = n + 1
    end
  end
  return n
end

--- Lot ENCEINTE3 : rayon libéré (aucun segment posé) : les lots écartés par le contour redeviennent utilisables.
local function enc_release(b)
  for _, k in ipairs(sorted_keys(b.lots)) do b.lots[k].out = nil end
end

--- Plan du projet « enceinte » : (true) ou (false, raison). Mêmes champs qu'un projet de module (entités, points d'appui,
--- obstacles) : la machine d'états d'`advance` ne change pas.
local function plan_enceinte(f, surface, p)
  local b = f.build
  local enc = b.enc
  local isl = p.spec.ilot and p.spec.walls -- lot ILOTS-MURS : segment du mur d'un îlot (script/team/ilots.lua), sans l'anneau de l'enceinte
  if not enc and not isl then return false, "enceinte annulee" end
  local item = item_of(T.wall)
  if not item then return false, "mur sans objet" end
  local x0, y0, x1, y1 = 0, 0, 0, 0
  if enc then x0, y0, x1, y1 = Enc.bounds(b.lat, enc.r, nil, enc.bounds) end -- lot ENCEINTE3 : contour serré s'il y en a un
  -- lot ENCEINTE2 : un projet = un SEGMENT (spec.walls : tuiles { {tx, ty} ... }) ; sans liste (projet d'une sauvegarde d'avant),
  -- l'anneau entier
  local seg = p.spec.walls
  local areas, tiles
  if seg then
    local ax0, ay0, ax1, ay1 = math.huge, math.huge, -math.huge, -math.huge
    tiles = {}
    for _, w in ipairs(seg) do
      tiles[#tiles + 1] = { tx = w[1], ty = w[2], x = w[1] + 0.5, y = w[2] + 0.5 }
      ax0, ay0, ax1, ay1 = math.min(ax0, w[1]), math.min(ay0, w[2]), math.max(ax1, w[1]), math.max(ay1, w[2])
    end
    areas = { { ax0 - 11, ay0 - 11, ax1 + 12, ay1 + 12 } } -- 11 tuiles tout autour : de quoi poser les points d'appui
    if isl then x0, y0, x1, y1 = ax0, ay0, ax1, ay1 end -- lot ILOTS-MURS : bornes du segment (pas d'anneau d'enceinte)
  else
    areas = ring_areas(x0, y0, x1, y1)
  end
  local m = enc_masks(f, surface, areas)
  local function skip(tx, ty)
    local k = P.tkey(tx, ty)
    if m.water[k] then return "eau" end
    if m.ore[k] then return "ressource" end
    if m.blocked[k] then return "bloque" end
    if b.occ[k] then return "reserve" end
    if Build.couloirs(f)[k] then return "couloir" end -- lot ÉTAGE 5 (décision du lead) : un mur d'enceinte ne coupe pas un couloir d'accès
    return nil
  end
  local ring
  if tiles then
    ring = { walls = {}, gates = 0, skipped = {} }
    for _, w in ipairs(tiles) do
      local why = skip(w.tx, w.ty)
      if why then ring.skipped[why] = (ring.skipped[why] or 0) + 1 else ring.walls[#ring.walls + 1] = w end
    end
  else
    ring = Enc.ring(b.lat, enc.r, { skip = skip, bounds = enc.bounds })
  end
  if #ring.walls == 0 then return false, "aucun mur posable" end
  local ents = {}
  for _, w in ipairs(ring.walls) do
    ents[#ents + 1] = { name = T.wall, x = w.x, y = w.y, dir = 0, part = 1, role = "enceinte", wall = true, item = item }
  end
  if not reserve_tiles(b, p, ents) then return false, "place" end
  local passable = seg_passable(b)
  local spots = {}
  for _, e in ipairs(p.ents) do
    local a = P.anchor_for(b.lat, e.x, e.y, passable)
    local ax, ay
    if a then ax, ay = a.x, a.y else ax, ay = math.floor(e.x / 8) * 8 + 4, math.floor(e.y / 8) * 8 + 4 end
    local ck = ax .. ":" .. ay
    local sp = spots[ck]
    if not sp then sp = { free_spot(b, m, ax, ay, nil) }; spots[ck] = sp end
    local fx, fy = sp[1], sp[2]
    if (fx - e.x) * (fx - e.x) + (fy - e.y) * (fy - e.y) > REACH * REACH then fx, fy = free_spot(b, m, e.x, e.y, nil) end
    e.ax, e.ay = fx, fy
    e.anchor = string.format("%s%g:%g", a and "" or "c", fx, fy)
  end
  P.sort_build(p.ents)
  p.obstacles, p.obst_keys = {}, {}
  for _, e in ipairs(p.ents) do
    local tx, ty = math.floor(e.x), math.floor(e.y)
    if m.clear[P.tkey(tx, ty)] then add_obstacle(p, { x = e.x, y = e.y, anchor = e.anchor, ax = e.ax, ay = e.ay }) end
  end
  -- ox, oy : le milieu du segment (la rue qui y mène est défrichée la première) ; ancien projet entier : l'ouverture nord
  local ox, oy = b.lat.ox + 14, y0
  if tiles then
    local mid = ring.walls[math.ceil(#ring.walls / 2)]
    ox, oy = mid.x, mid.y
  end
  p.parts[1] = { kind = "enceinte", key = "enceinte", ox = ox, oy = oy, w = 1, h = 1, power = false,
    ring = { x0, y0, x1, y1 } }
  b.stats.modules_started = b.stats.modules_started + 1
  p.walls_planned = #ring.walls
  if isl then -- lot ILOTS-MURS : journal propre (pas de rayon d'enceinte)
    local sk = {}
    for _, k in ipairs(sorted_keys(ring.skipped)) do sk[#sk + 1] = k .. "=" .. ring.skipped[k] end
    log(string.format("[FO-ILOT] %s : segment de l'ilot %s planifie (projet %d, cote %s, %d,%d a %d,%d) : %d murs, tuiles laissees ouvertes %s, %d obstacles a defricher",
      f.key or "player", tostring(p.spec.ilot), p.id, tostring(p.spec.side), x0, y0, x1, y1, #ring.walls,
      #sk > 0 and table.concat(sk, " ") or "aucune", #p.obstacles))
    return true
  end
  log(string.format("[FO-ESPACE] %s : enceinte %s planifiee (rayon %d, anneau %d,%d a %d,%d) : %d murs, tuiles non murees %s, %d obstacles a defricher",
    f.key or "player", tiles and ("segment " .. tostring(p.spec.side)) or "entiere", enc.r, x0, y0, x1, y1, #ring.walls,
    (function()
      local out = {}
      for _, k in ipairs(sorted_keys(ring.skipped)) do out[#out + 1] = k .. "=" .. ring.skipped[k] end
      return #out > 0 and table.concat(out, " ") or "aucune"
    end)(), #p.obstacles))
  return true
end

local plan_finish -- lot CHARBON-CENTRALE : fin commune des plans (définie après plan_project)

--- Lot CHARBON-CENTRALE : boilers (nombre) et puissance de combustion (kW, données) des chaudières planifiées d'une centrale `p`
--- (chaudière : une entité des données qui boit de l'eau et brûle du combustible ; aucun nom écrit ici).
local function plant_burn_kw(p)
  local n, kw = 0, 0
  for _, e in ipairs(p.ents or {}) do
    local sp = M.spec(e.name)
    if sp and sp.water and sp.burner_kw then n, kw = n + 1, kw + sp.burner_kw end
  end
  return n, kw
end

--- Lot CHARBON-CENTRALE : le projet `p` est-il une centrale planifiée (sa première partie, posée par plan_project) ?
local function is_plant_project(p)
  return p ~= nil and p.parts ~= nil and p.parts[1] ~= nil and p.parts[1].kind == "centrale"
end

--- Lot CHARBON-CENTRALE : la centrale `p` est-elle nourrie par des foreuses (règle pure Cc.automated) ? Rend aussi son projet
--- d'alimentation (ou nil).
local function plant_automated(b, p)
  local kinds = {}
  for _, pt in ipairs(p.parts or {}) do kinds[#kinds + 1] = pt and pt.kind or "?" end
  local st = b.charbon and b.charbon[p.id]
  local alim = st and st.alim and b.projects[st.alim] or nil
  return Cc.automated(kinds, alim and alim.state or nil), alim
end

--- Lot CHARBON-CENTRALE : plan du projet « alimentation de la centrale » (spec.alim = numéro du projet de centrale) : foreuses sur le
--- gisement du combustible de son coffre le plus proche de sa tête d'alimentation, et leur tapis jusqu'à cette tête (Build.plan_drills,
--- le plan des foreuses d'une fonderie), puis poteaux, points d'appui et obstacles (plan_finish). Le coffre de la centrale reste en
--- secours. Rend true, ou (false, raison[, attendre]).
local function plan_alim(f, surface, p)
  local b = f.build
  local plant = b.projects[p.spec.alim]
  if not (plant and plant.state == "fini") then return false, "centrale absente ou en chantier" end
  local fuel = plant.quais and plant.quais[1] and plant.quais[1].item
  if not fuel then return false, "centrale sans coffre de combustible" end
  local head
  for _, e in ipairs(plant.ents) do if e.role == "tete" then head = e end end -- la dernière tuile de la tête (la plus loin du module)
  if not head then return false, "centrale sans tete d'alimentation" end
  local _, kw = plant_burn_kw(plant)
  local rate = Cc.alim_rate(kw, M.COAL_J) -- lot s42 charbon-centrale (b) : consommation nominale des chaudières × Cc.ALIM_MARGIN
  local d = head.dir or 0
  local lx, ly = P.left_of(d)
  local last = "arrivee prise"
  local transient = false
  for _, a in ipairs(Cc.arrivals(math.floor(head.x), math.floor(head.y), P.DV[d], { lx, ly }, d, P.dir_of)) do
    if a.dir and not b.occ[P.tkey(a.x, a.y)] then
      p.parts, p.ents = {}, {}
      local ok, why, wait = Build.plan_drills(f, surface, p, fuel, rate, a, nil)
      if wait then p.parts, p.ents = {}, {}; return false, why, wait end -- lot TRANCHES-FOREUSES : le tracé du tapis continue à la pensée suivante
      if ok then
        p.parts[1].alim = plant.id
        local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
        for _, e in ipairs(p.ents) do
          x0, y0, x1, y1 = math.min(x0, e.x), math.min(y0, e.y), math.max(x1, e.x), math.max(y1, e.y)
        end
        local masks = read_masks(f, surface, math.floor(x0) - 32, math.floor(y0) - 32, math.ceil(x1) + 32, math.ceil(y1) + 32)
        local route = 0
        for _, e in ipairs(p.ents) do if e.role == "liaison-tapis" then route = route + 1 end end
        log(string.format("[FO-CHARBON-CENTRALE] %s : projet %d (alimentation de la centrale %d) plan : %d foreuse(s) de %s pour %.2f/s, tapis de %d tuile(s) jusqu'a la tete (%d, %d)",
          f.key or "player", p.id, plant.id, p.parts[1].drills or 0, tostring(fuel), rate, route, a.x, a.y))
        return plan_finish(f, surface, p, masks, false)
      end
      last = tostring(why) -- (plan_drills ne réserve rien quand il échoue : reserve_tiles est tout ou rien)
      transient = transient or Cc.transient(last)
    end
  end
  p.parts, p.ents = {}, {}
  -- lot s50 centrale-tapis : un échec passager du tracé (Cc.transient) garde le projet ouvert (attente, nouvel essai), sans refus
  if transient then
    p.transient_n = (p.transient_n or 0) + 1
    p.plan_after = game.tick + Cc.transient_wait(p.transient_n - 1) -- 0.7.110 : 2 min, 5 min, puis 15 min
    return false, "foreuses : " .. last .. " (trace en pause, nouvel essai)", true
  end
  -- lot ENERGIE : gisement de charbon hors du treillis (12 refus « minerai » sur 31 demandes au 31/10) : le treillis GRANDIT, le prochain
  -- essai (pause du lot CHARBON-CENTRALE) trouve le gisement ; avant, rien ne le faisait grandir pour l'alimentation
  if Cv.after_refusal(last, Build.can_grow(b)) == "grandir" then
    Build.grow(f, b.radius + 1)
    p.cv_grew = true -- (relecture : ce refus-là ne compte pas vers la pause longue, Cc.refused)
    b.stats.cv_grow = (b.stats.cv_grow or 0) + 1
    if b.stats.cv_grow <= Build.LINE_LOGS then
      log(Cv.line({ kind = "grandir", team = f.key or "player", tick = game.tick, project = p.id, why = last, radius = b.radius }))
    end
  end
  return false, "foreuses : " .. last
end

--- Lot PD-ELEC (D05) : plan d'un projet de RACCORDEMENT (spec.raccord, demandé par script/team/raccord.lua) : une chaîne de poteaux
--- du poteau d'une île (ou d'un poteau neuf contre une machine sous aucun poteau) au poteau alimenté choisi, par P.pole_chain (recherche
--- de chemin de 0.6.17) sur les masques du couloir (lot POTEAUX-MASQUES, mêmes attentes « masques »). Mêmes champs qu'un projet de
--- module (entités, points d'appui, obstacles) : la machine d'états d'`advance` ne change pas ; les fils sont tirés au raccordement
--- (wire_project relie les poteaux du projet à leurs voisins, île et réseau alimenté compris).
local function plan_raccord(f, surface, p)
  local b = f.build
  local rc = p.spec.raccord
  local function pole_at(x, y)
    return surface.find_entities_filtered({ position = { x, y }, radius = 0.6, force = f.force, type = "electric-pole", limit = 1 })[1]
  end
  local tgt = pole_at(rc.target.x, rc.target.y)
  if not tgt then return false, "raccord: poteau alimente disparu" end
  local s0 = rc.start.new and rc.cands[1] or rc.start
  if not s0 then return false, "raccord: aucun depart" end
  local masks = read_masks(f, surface, math.floor(s0.x) - 12, math.floor(s0.y) - 12, math.floor(s0.x) + 13, math.floor(s0.y) + 13)
  local start
  if rc.start.new then
    for _, c in ipairs(rc.cands) do
      local tx, ty = math.floor(c.x), math.floor(c.y)
      if masks.free(tx, ty) and not masks.clear[P.tkey(tx, ty)] then start = { x = c.x, y = c.y } break end
    end
    if not start then return false, "raccord: aucune place libre pour un poteau contre la machine" end
  else
    local sp = pole_at(rc.start.x, rc.start.y)
    if not sp then return false, "raccord: poteau de l'ile disparu" end
    if sp.electric_network_id == tgt.electric_network_id then return false, "raccord: deja relie" end
    start = { x = rc.start.x, y = rc.start.y }
  end
  -- lot ENERGIE (2/11) : un second chemin contourne une zone de 28 tuiles : couloir de masques plus large (margin(2 x reach) plafonne à 32)
  local view = masques_view(f, surface, p, masks, { { a = start, b = { x = rc.target.x, y = rc.target.y } } }, rc.avoid and rc.reach * 2 or rc.reach)
  if not view then return false, "masques (couloir du raccordement en cours de releve)", "masques" end
  local taken = {}
  if rc.start.new then taken[P.tkey(math.floor(start.x), math.floor(start.y))] = true end
  -- lot ENERGIE (2/11) : second chemin, la chaîne neuve reste hors de la zone des ennemis (sauf autour de ses deux bouts)
  local avoid = rc.avoid
  local ends = { { x = start.x, y = start.y }, { x = rc.target.x, y = rc.target.y } }
  local function free(x, y)
    local tx, ty = math.floor(x), math.floor(y)
    if avoid and Cr.in_zone(tx + 0.5, ty + 0.5, avoid, ends, Cr.EXEMPT_R) then return false end
    return view.free(tx, ty) and not taken[P.tkey(tx, ty)] and not view.clear(tx, ty)
  end
  -- poteaux déjà prévus ou posés (projets en chantier ou finis, comme plan_power) : la chaîne les traverse au lieu d'en doubler un
  local known = {}
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and q ~= p and not q.abandoned and REUSE_STATES[q.state] then
      for _, e in ipairs(q.ents) do
        if e.name:find("electric%-pole") and (P.wire(e.name) or 0) >= rc.reach - 1e-9 then
          -- second chemin : seuls les poteaux qui EXISTENT et hors de la zone des ennemis sont traversés sans en poser (un poteau perdu,
          -- ou tenu par un ennemi, ne relie rien)
          local usable = P.relay_pole(q.state, e.built) -- lot COURANT3 : un poteau seulement prevu d'un chantier voisin ne relie rien
          if usable and avoid then
            usable = e.built and not Cr.in_zone(e.x, e.y, avoid, ends, Cr.EXEMPT_R) and pole_at(e.x, e.y) ~= nil
          end
          if usable then known[#known + 1] = { x = e.x, y = e.y } end
        end
      end
    end
  end
  -- second chemin : le détour de la zone des ennemis demande plus de cellules que le plafond ordinaire (600 : couloir trop grand)
  local chain = Build.Trav.pole_chain(f, surface, start, { x = rc.target.x, y = rc.target.y }, rc.reach, rc.big, free, known,
    avoid and { max_cells = 2500, max_expand = 10000 } or nil)
  if not chain then return false, "raccord: aucune chaine de poteaux (relief, eau, place)" end
  local ents = {}
  if rc.start.new then ents[1] = { name = rc.pole, x = start.x, y = start.y, dir = 0, part = 1, role = "liaison" } end
  for _, c in ipairs(chain) do ents[#ents + 1] = { name = rc.pole, x = c.x, y = c.y, dir = 0, part = 1, role = "liaison" } end
  if #ents == 0 then return false, "raccord: aucun poteau a poser (bouts a portee)" end
  if not reserve_tiles(b, p, ents) then return false, "poteaux" end
  local passable = seg_passable(b)
  local wood = wood_of(surface, p.ents)
  for _, e in ipairs(p.ents) do
    local a = P.anchor_for(b.lat, e.x, e.y, passable)
    local ax, ay
    if a then ax, ay = a.x, a.y else ax, ay = math.floor(e.x / 8) * 8 + 4, math.floor(e.y / 8) * 8 + 4 end
    local fx, fy = free_spot(b, masks, ax, ay, wood)
    if (fx - e.x) * (fx - e.x) + (fy - e.y) * (fy - e.y) > REACH * REACH then fx, fy = free_spot(b, masks, e.x, e.y, wood) end
    e.ax, e.ay = fx, fy
    e.anchor = string.format("%s%g:%g", a and "" or "c", fx, fy)
    e.item = item_of(e.name)
  end
  P.sort_build(p.ents)
  p.obstacles, p.obst_keys = {}, {}
  for _, e in ipairs(p.ents) do
    for _, t in ipairs(P.tiles_of(e)) do
      local k = P.tkey(t[1], t[2])
      if masks.clear[k] or wood[k] then add_obstacle(p, { x = t[1] + 0.5, y = t[2] + 0.5, anchor = e.anchor, ax = e.ax, ay = e.ay }) end
    end
  end
  p.parts[1] = { kind = "raccord", key = "raccord", ox = start.x, oy = start.y, w = 1, h = 1, power = false }
  p.counted = true -- un raccordement n'est pas un module : finish_project ne le compte pas aux modules finis
  log(string.format("[FO-RACCORD] %s : projet %d planifie (groupe %s) : %d poteau(x) %s de (%.1f, %.1f) a (%.1f, %.1f), portee %g, %d obstacle(s)%s",
    f.key or "player", p.id, tostring(rc.key), #p.ents, rc.pole, start.x, start.y, rc.target.x, rc.target.y, rc.reach, #p.obstacles,
    avoid and string.format(" ; SECOND CHEMIN, %d ennemi(s) evite(s) a %d tuiles, %d poteau(x) existant(s) reutilise(s)", #avoid, avoid[1] and avoid[1].r or 0, #known) or ""))
  return true
end

--- Plan d'un projet : (true) ou (false, raison, attendre). Une seule pensée de plan par passe.
--- Fin du plan d'un projet (points d'appui, ordre de pose, obstacles) ; commune aux modules et aux SITES (lot PETROLE).
local function anchors_and_obstacles(f, surface, p, masks)
  local b = f.build
  Profiler.start("build:plan:anchors")
  -- points d'appui : sur une rue praticable à 16 tuiles au plus, sinon au centre de la case de 8 × 8 ; dans les deux
  -- cas déplacés sur une tuile LIBRE (correction du 27/10 : le repli tombait sur l'emprise de la chaudière, et le PNJ
  -- bâtisseur, debout dessus, en empêchait la pose : banc ia1-build-plaine, 25/10)
  local passable = seg_passable(b)
  local wood = wood_of(surface, p.ents)
  for _, e in ipairs(p.ents) do
    -- (relecture de la reprise 0.6.20 : garde de main 0.6.21, lot PD-CENTRALE, reprise ici pour que la fusion garde ce côté ;
    -- sur 0.6.20 aucune entité ne porte `ligne` : sans effet. Un poteau de la ligne lointaine garde son point d'appui, Far.line)
    if not (e.ligne and e.anchor) then
      local a = P.anchor_for(b.lat, e.x, e.y, passable)
      local ax, ay
      if a then ax, ay = a.x, a.y
      else ax, ay = math.floor(e.x / 8) * 8 + 4, math.floor(e.y / 8) * 8 + 4 end
      local fx, fy = free_spot(b, masks, ax, ay, wood)
      if (fx - e.x) * (fx - e.x) + (fy - e.y) * (fy - e.y) > REACH * REACH then fx, fy = free_spot(b, masks, e.x, e.y, wood) end
      e.ax, e.ay = fx, fy
      e.anchor = string.format("%s%g:%g", a and "" or "c", fx, fy)
    end
    e.item = item_of(e.name)
  end
  P.sort_build(p.ents)
  -- obstacles à défricher sous les entités planifiées (toutes les pièces du projet)
  p.obstacles, p.obst_keys = {}, {}
  for _, e in ipairs(p.ents) do
    for _, t in ipairs(P.tiles_of(e)) do
      local k = P.tkey(t[1], t[2])
      if masks.clear[k] or wood[k] then add_obstacle(p, { x = t[1] + 0.5, y = t[2] + 0.5, anchor = e.anchor, ax = e.ax, ay = e.ay }) end
    end
  end
  for _, pt in ipairs(p.parts) do if pt then b.stats.modules_started = b.stats.modules_started + 1 end end
  Profiler.stop("build:plan:anchors")
  return true
end

local function plan_project(f, surface, p)
  local b = f.build
  local spec = p.spec
  if spec.enceinte then return plan_enceinte(f, surface, p) end
  if spec.alim then return plan_alim(f, surface, p) end -- lot CHARBON-CENTRALE
  if spec.alimquai then -- lot FONDERIE-BLOC : ligne de foreuses de charbon et tapis jusqu'au coffre de tête d'un champ (script/team/fonderie_bloc.lua)
    return Build.FonderieBloc.plan({ read_masks = function(x0, y0, x1, y1) return read_masks(f, surface, x0, y0, x1, y1) end, reserve_tiles = reserve_tiles,
      finish = plan_finish, plan_drills = Build.plan_drills }, f, surface, p)
  end
  if spec.raccord then return plan_raccord(f, surface, p) end -- lot PD-ELEC (D05)
  if spec.quartier then -- lot TV-ARCHI (V23) : pôle d'un quartier (poteau, dépôts, lot défriché), script/team/quartiers.lua
    return Build.Quartiers.plan(f, surface, p, { read_masks = function(x0, y0, x1, y1) return read_masks(f, surface, x0, y0, x1, y1) end,
      reserve_tiles = reserve_tiles, finish = plan_finish, add_obstacle = add_obstacle, free_spot = free_spot,
      count = function(it) return Stock.count(f, it) end }) -- (tranche 3 : tourelle du pôle si le coffre l'a)
  end
  if spec.liaison and spec.liaison.piquage then return Build.Piquage.plan({ read_masks = function(x0, y0, x1, y1) return read_masks(f, surface, x0, y0, x1, y1) end, reserve_tiles = reserve_tiles, wood_of = wood_of, free_spot = free_spot, add_obstacle = add_obstacle, item_of = item_of, seg_passable = seg_passable, REACH = REACH, trav = Build.Trav }, f, surface, p) end -- lot PIQUAGE
  if spec.rapatriement then -- lot RAPATRIEMENT : ligne longue d'une sortie lointaine à un coffre tampon (script/team/rapatriement.lua)
    return Build.Rapatriement.plan({ read_masks = function(x0, y0, x1, y1) return read_masks(f, surface, x0, y0, x1, y1) end, reserve_tiles = reserve_tiles, wood_of = wood_of,
      free_spot = free_spot, add_obstacle = add_obstacle, item_of = item_of, seg_passable = seg_passable, REACH = REACH }, f, surface, p)
  end
  if spec.liaison then return Liaison.plan({ read_masks = function(x0, y0, x1, y1) return read_masks(f, surface, x0, y0, x1, y1) end, reserve_tiles = reserve_tiles, wood_of = wood_of, free_spot = free_spot, add_obstacle = add_obstacle, item_of = item_of, seg_passable = seg_passable, REACH = REACH }, f, surface, p) end -- lot INDUSTRIE I7
  Profiler.start("build:plan:place") -- lot IA3-e : parts du coût d'un plan (pics de K10), mesure seulement
  -- Lot PETROLE : un SITE (spec.site) est implanté par son planificateur (Build.SITES[nom], hors du treillis : au gisement
  -- d'un fluide) ; le chantier qui suit est le même (réserve, défrichage, fantômes, ravivage, fils, quais).
  if spec.site then
    local fn = Build.SITES[spec.site]
    if not fn then return false, "site inconnu" end
    local lay, swhy, wait = fn(f, surface, p, {
      read_masks = function(x0, y0, x1, y1) return read_masks(f, surface, x0, y0, x1, y1) end,
      plant = function() return Build.plant(f) end })
    if not lay then return false, swhy, wait end
    p.parts[1] = { kind = "module", key = lay.key, lot = "site", ox = lay.box[1], oy = lay.box[2], k = 0,
      w = lay.box[3] - lay.box[1] + 1, h = lay.box[4] - lay.box[2] + 1, power = true }
    local ents = {}
    for _, e in ipairs(lay.ents) do
      ents[#ents + 1] = { name = e.name, x = e.x, y = e.y, dir = e.dir or 0, recipe = e.recipe, part = 1, role = e.role, charge = e.charge, rank = e.rank,
        type = e.type, carries = e.carries } -- (lot CHAMP : charge du coffre de combustible, rang de pose ; lot FONDERIE : entrée ou sortie d'un souterrain ; lot MALL : objet porté par un tapis, déclaré)
    end
    if not reserve_tiles(b, p, ents) then return false, "place" end
    for _, t in ipairs(lay.sous or {}) do local k = P.tkey(t[1], t[2]); if b.occ[k] == nil then b.occ[k] = p.id end end -- lot s42 TUYAUX : sol au-dessus d'une paire souterraine, retenu au plan (aucun souterrain aligné d'un autre chantier)
    for _, q in ipairs(lay.quais or {}) do p.quais[#p.quais + 1] = { x = q.x, y = q.y, item = q.item, flow = q.flow } end -- (lot FONDERIE-BLOC : flow = débit d'un coffre de tête de champ)
    for _, o in ipairs(lay.outs or {}) do p.outs[#p.outs + 1] = { x = o.x, y = o.y, at = lay.out_at } end
    if lay.directes and #lay.directes > 0 then p.sorties_directes = lay.directes end -- s42 bus-direct : bouts des lignes de plaques (script/team/rapatriement.lua, ligne directe)
    if lay.piquable and #lay.piquable > 0 then p.tapis_piquable = lay.piquable end -- s41 sortie-bus : trop-plein d'une ligne de plaques (script/team/piquage.lua, plan_sources)
    Profiler.stop("build:plan:place")
    return anchors_and_obstacles(f, surface, p, lay.masks)
  end
  -- lot AGENCEMENT : la fonderie à tapis est une LIGNE qui suit le gisement (line_rows) ; ses coffres vont vers le centre (la
  -- source de ressources de la base, défaut) ou vers l'extérieur (les plaques nourrissent un autre module du plan)
  local topts
  if spec.gen == "smelter" and spec.feed == "tapis" then
    local plate = M.PLATE_OF[(spec.args or {})[2]]
    local use = spec.use or ((plate and plate_used_elsewhere(b, p, plate)) and "usine" or nil)
    local sortie = Li.sortie_for(use)
    -- lot INTEG-ECONOMIE (D2) : un module réduit après un échec de matériaux (CAPI-REPLI, spec.shrunk) garde la taille demandée ;
    -- sans cela line_rows le remontait au plancher de 4 rangées (retiré au lot FONDERIE-DYNAMIQUE) et annulait la réduction
    topts = { sortie = sortie, grow = function(g1, cur)
      if spec.shrunk then return cur end
      return line_rows(f, surface, spec, g1, cur, sortie == "exterieur")
    end }
    p.sortie = sortie
  end
  local g, why = template_of(spec, topts)
  if not g then return false, why end
  g = Build.Rangee.full(p, g, f) -- lot RANGEES-ASM : rangée dynamique planifiée à la borne de son gabarit (place entière réservée)
  p.consumes = {}
  p.inflow = {} -- lot INDUSTRIE I7 : débit nominal de chaque entrée (objets/s), lu par script/team/liaison.lua pour le prix d'une liaison de quai
  for _, k in ipairs(sorted_keys(g.inputs or {})) do p.consumes[k] = true; p.inflow[k] = g.inputs[k] end
  if Build.QUAI_PAR_DEBIT and g.gen ~= "steam" then
    -- lot RESEAU-GRAPHE : le débit d'une entrée servie par quai est celui que le quai porte (Li.worth le lit : min(nominal, capacité))
    local qcaps = Build.Qd.plan(M, g, Build.Qd.skip(M, g, spec.feed == "quai")).caps
    for _, k in ipairs(sorted_keys(qcaps)) do
      if p.inflow[k] and qcaps[k] < p.inflow[k] then p.inflow[k] = qcaps[k] end
    end
  end
  p.outflow = {} -- lot VIDEO L4 : débit nominal de chaque sortie (objets/s, M.analyze), lu par les quotas (Build.Quotas)
  for _, k in ipairs(sorted_keys(g.nominal or {})) do p.outflow[k] = g.nominal[k] end
  local main
  local is_plant = g.gen == "steam"
  local toward
  local rp_last -- lot TV-REPLI : gabarit et options du dernier essai de try_place (le repli de placement simple reprend les mêmes)
  if spec.near then toward = spec.near end
  if is_plant then
    main, why = place_module(f, surface, g, { rive = true, eau = true }, toward or { x = b.lat.ox, y = b.lat.oy }, nil, { water = true, margin = 0 })
  elseif g.resource then
    main, why = place_module(f, surface, g, { gisement = true }, toward or { x = b.lat.ox, y = b.lat.oy }, spec.resource or g.resource)
  else
    local best, bf
    for _, k in ipairs(sorted_keys(g.inputs or {})) do
      if M.ORES[k] and k ~= "coal" and (not bf or g.inputs[k] > bf) then best, bf = k, g.inputs[k] end
    end
    local dep = (best and (not toward or spec.feed == "tapis")) and deposit_toward(b, best) or nil
    if not toward then
      -- « les fonderies vont vers le minerai » : vers le gisement de l'entrée principale
      toward = dep or { x = b.lat.ox, y = b.lat.oy }
    end
    -- lot FONDERIES (retour du DC du 29/10 : tapis en crochet, fours posés « à l'envers ») : une fonderie servie par un
    -- tapis de foreuses est tournée tête vers le gisement ; la colonne de fours s'étend à l'opposé, sans retour.
    local function try_place(gx)
      local fopts = (spec.feed == "tapis" and dep) and { head_toward = dep } or nil
      -- lot AGENCEMENT : deux bras par tapis de sortie quand un seul étranglerait la ligne (place du second réservée par P.fit)
      if topts then
        local _, arms = out_arms(gx, Li.MAX_ARMS)
        if arms > 1 then fopts = fopts or {}; fopts.fan = arms end
      end
      -- lot VIDEO L9 : états de lots essayés par la règle (Build.LotsMinerai.states : le repli d'avant, libres puis gisement, quand elle est
      -- éteinte (repli d'avant) ; Lm.states_for allumée (défaut depuis 0.6.60) : une fabrique ne se replie plus sur un gisement) ; replis et refus comptés ([FO-LOTS-MINERAI])
      rp_last = { g = gx, fopts = fopts }
      local m, w, mi, ms
      for i, states in ipairs(Build.LotsMinerai.states(f, gx.gen)) do
        m, w = place_module(f, surface, gx, states, toward, nil, fopts)
        if m then mi, ms = i, states break end
      end
      Build.LotsMinerai.after(f, gx.gen, m, mi, ms)
      return m, w
    end
    main, why = try_place(g)
    -- lot AGENCEMENT (relecture) : la ligne agrandie ne tient dans aucun lot (relief, eau, bâtiments) : repli sur la taille de la
    -- demande, qui se posait avant le lot. Sans cela le projet restait refusé (et le treillis grandissait pour rien).
    if not main and topts then
      local g0 = template_of(spec, { sortie = topts.sortie })
      if g0 and (g0.params or {}).n ~= (g.params or {}).n then
        local m0, w0 = try_place(g0)
        if m0 then
          b.line_logs = (b.line_logs or 0) + 1
          if b.line_logs <= Build.LINE_LOGS then
            log(string.format("[FO-LIGNE] %s : projet %d, fonderie de %d rangee(s) sans place (%s) : repli sur %d rangee(s) de la demande",
              f.key or "player", p.id, (g.params or {}).n or 0, tostring(why), (g0.params or {}).n or 0))
          end
          main, why, g = m0, w0, g0
        end
      end
    end
    -- lot TV-PLACE (C07 : « placement … as dumb as possible ») : avant de faire grandir le treillis, la règle la plus petite (shared/team/place_simple.lua) :
    -- lots dans l'ordre de la spirale, mêmes états permis, marge 0, sans autre option
    if not main and Build.Place.simple_on() then
      local cache = scan_cache(f)
      local qg = { x = b.lat.ox, y = b.lat.oy }
      main, why = Build.Place.simple(f, p, g, why, Build.LotsMinerai.states(f, g.gen), function(states, fo)
        fo.cache = cache
        return place_module(f, surface, g, states, qg, nil, fo)
      end, game.tick)
    end
  end
  Profiler.stop("build:plan:place")
  if not main then
    if Build.can_grow(b) then
      Build.grow(f, b.radius + 1)
      return false, why, true
    end
    -- lot TV-REPLI (TODO_VIDEO C07, « placement as dumb as possible ») : le treillis ne grandit plus et aucun lot ne tient le module :
    -- placement de repli simple (fenêtres libres et sûres autour du QG ou du gisement) au lieu de l'abandon du projet
    if not is_plant then
      local res = g.resource and (spec.resource or g.resource) or nil
      local rg = (rp_last and rp_last.g) or g
      local center = (res and deposit_toward(b, res)) or toward or { x = b.lat.ox, y = b.lat.oy }
      local rp = Build.Repli.try(f, surface, rg, { p = p, why = why, res = res, center = center, fopts = rp_last and rp_last.fopts or nil,
        read_masks = read_masks, ore_set = ore_set, avoid_margin = Build.AVOID_MARGIN })
      if rp then main, g = rp, rg end
    end
    -- lot PD-CENTRALE (décision du DC D-24 (1) : « si l'eau n'est pas utilisable, il faut aller plus loin […] centrale plus
    -- loin ») : plus d'étang garanti ; la centrale va à l'eau la plus proche HORS du treillis, reliée par une ligne de poteaux
    -- (plan_power, Far.line). Toutes les équipes (votre équipe était refusée sans recours).
    if not main then
      if not is_plant then return false, why end
      Profiler.start("build:plan:loin")
      local lwhy, lwait
      main, lwhy, lwait = Far.place(f, surface, g, { read_masks = read_masks, tick = game.tick, why = why, avoid_margin = Build.AVOID_MARGIN, p = p })
      Profiler.stop("build:plan:loin")
      if not main then return false, lwhy, lwait end
    end
  end
  p.far = main.far -- lot PD-CENTRALE : rive de la centrale lointaine (nil dans le treillis)
  p.parts[1] = { kind = is_plant and "centrale" or "module", key = main.g.key, lot = main.lot or (main.repli and "repli") or "lointain", ox = main.ox, oy = main.oy,
    k = main.k, w = main.g.w, h = main.g.h, power = needs_power(main.g) }
  local ents = inst_entities(main.inst, 1)
  Build.Rangee.tag(p, ents, main.g) -- lot RANGEES-ASM : colonne de chaque machine et de ses bras (pose par étapes, Build.Rangee.split)
  if topts then Build.tag_rows(ents, g, 0, "four", "row") end -- lot FONDERIE-DYNAMIQUE : rangée de chaque four et de ses bras (ligne_split)
  if not reserve_tiles(b, p, ents) then return false, "place" end
  if main.lot then b.lots[main.lot].used = p.id end
  -- lot ENERGIE-CROISSANCE : la rive partagée reste au nom de sa première centrale (un refus ou un abandon de la centrale de plus
  -- libère les lots à son nom : il ne doit pas libérer celui d'une centrale bâtie, que l'enceinte et l'évaluation lisent pris).
  -- (Une centrale lointaine de PD-CENTRALE n'a ni lot ni main.shared.)
  if main.shared then
    b.lots[main.lot].used = main.shared
    log(string.format("[FO-ENERGIE] %s : projet %d, centrale posee sur la rive de la centrale %d (lot %s, autre bord de la meme eau)",
      f.key or "player", p.id, main.shared, main.lot))
  end
  -- lot MALL-PAVAGE : le lot pavé reste au nom de son premier bloc (un abandon du bloc de plus ne libère pas le lot)
  if main.pave then
    b.lots[main.lot].used = main.pave
    log(string.format("[FO-MALL] %s : projet %d, bloc de mall colle au bloc %d dans le lot %s (pavage, gap %d) en (%d, %d)",
      f.key or "player", p.id, main.pave, main.lot, Build.Pave.Mp.GAP, main.ox, main.oy))
  end
  -- lot MALL-RUE : section posée de l'autre côté de la rue : rallonge, entrée et sortie du souterrain sur chaque voie du corridor (le lot suivant
  -- est au nom du même ruban : main.pave ; le port d'entrée servi n'a pas de tête : main.fed, plan_feed)
  if main.serie then
    local okc, cwhy = Build.Pave.cross(f, p, main, reserve_tiles)
    if not okc then return false, cwhy end
  end
  if spec.feed or is_plant then
    Profiler.start("build:plan:feed")
    local ok, w2, w3 = plan_feed(f, surface, p, main, 1)
    Profiler.stop("build:plan:feed")
    if not ok then return false, w2, w3 end
    -- Lot AUTO : diagnostic seulement (aucun refus) : deux entités du projet sur une même tuile ne se bâtiront jamais
    -- toutes les deux (la seconde : fantôme refusé « occupe »).
    local ov = P.overlaps(p.ents)
    if #ov > 0 then
      local e1, e2 = p.ents[ov[1][1]], p.ents[ov[1][2]]
      log(string.format("[FO-AUTO] %s : projet %d, %d chevauchement(s) au plan, dont %s (%s) et %s (%s) en (%.1f, %.1f)",
        f.key or "player", p.id, #ov, e1.name, tostring(e1.role), e2.name, tostring(e2.role), e2.x, e2.y))
    end
  end
  return Build.Rangee.after(f, p, plan_finish(f, surface, p, main.masks, is_plant, topts, g)) -- RANGEES-ASM (machines au-delà de n en attente) + FONTE-DYN (topts et g pour ligne_split)
end

--- Fin commune d'un plan (lot CHARBON-CENTRALE : partagée avec le projet d'alimentation de la centrale, plan_alim) : poteaux du
--- réseau, points d'appui, obstacles. `masks` : relevé de la zone de la première partie. Rend true, ou (false, raison, attendre).
--- `topts` et `g` (facultatifs, de plan_project) : l'option et le gabarit d'une ligne de fonderie, pour Build.ligne_split ; nil pour les
--- autres plans (alimentation de la centrale, quartiers).
plan_finish = function(f, surface, p, masks, is_plant, topts, g)
  local b = f.build
  Profiler.start("build:plan:power")
  -- électricité : le réseau de l'équipe ; la centrale l'amorce
  local need = false
  for _, pt in ipairs(p.parts) do if pt.power or pt.kind == "centrale" then need = true end end
  if need then
    if not is_plant and not b.plant then
      Build.plant(f)
    end
    local seen = {}
    for idx, pt in ipairs(p.parts) do
      if pt and (pt.power or pt.kind == "centrale") then
        local mp
        for _, e in ipairs(p.ents) do if e.part == idx and e.name:find("electric%-pole") then mp = mp or e end end
        if mp and not seen[idx] then
          seen[idx] = true
          -- relevé autour de CE module (eau, bâtiments, arbres) jusqu'aux carrefours voisins
          local pm = idx == 1 and masks or read_masks(f, surface, pt.ox - 32, pt.oy - 32, pt.ox + pt.w + 32, pt.oy + pt.h + 32)
          local extra, w3, nodes = plan_power(f, p, mp, pm)
          if not extra then
            -- lot PD-CENTRALE : la centrale lointaine que le réseau ne peut pas rejoindre (pas de rue depuis son carrefour de bord,
            -- liaison) écarte sa rive au lieu d'être refusée (sinon la même rive revenait à chaque demande)
            if p.far and nodes ~= "net" and nodes ~= "masques" and nodes ~= "loin" and Far.reject(f, p, w3) then return false, w3, "loin" end
            return false, w3, (nodes == "net" or nodes == "masques" or nodes == "loin") and nodes or nil
          end
          if not reserve_tiles(b, p, extra) then return false, "poteaux" end
          for _, n in ipairs(nodes or {}) do
            local k = P.lot_key(n.i, n.j)
            if not b.net[k] then b.net[k] = { i = n.i, j = n.j, pid = p.id, x = n.x, y = n.y } end
          end
        end
      end
    end
  end
  Profiler.stop("build:plan:power")
  if is_plant and not b.plant then b.plant = p.id end -- (lot CORR-ENERGIE : une centrale de plus ne devient pas LA centrale)
  anchors_and_obstacles(f, surface, p, masks) -- lot PETROLE : fin de plan commune aux modules et aux sites (même code qu'avant)
  if topts then Build.ligne_split(f, p, g) end -- lot FONDERIE-DYNAMIQUE : rangées et paires posées par étapes, la place reste réservée
  return true
end

--- Centrale de l'équipe (une demande, si aucune n'existe).
function Build.plant(f, pole)
  local b = f.build
  if b.plant then return b.plant end
  local id = Build.request(f, { gen = "steam", args = { 1 }, feed = true, prio = Build.PRIO + 5, domain = "infrastructures",
    pole = pole, plant = true }) -- (lot TV-ENERGIE : plant = la demande EST la centrale, Build.Ene)
  b.plant = id
  -- la centrale passe avant les autres projets en attente
  local order = { id }
  for _, x in ipairs(b.order) do if x ~= id then order[#order + 1] = x end end
  b.order = order
  return id
end

--- Lot CORR-ENERGIE : une centrale de plus (nb chaudières), demandée comme la première ; son chantier est un projet du plan
--- directeur (réserve de matériaux au coffre d'équipe, plan sur une autre rive libre). Suivi dans b.extra_plants.
function Build.grow_plant(f, nb, tick, secours)
  local b = f.build
  local first = b.plant and b.projects[b.plant]
  if not (first and first.spec and first.spec.gen) then return nil end -- (la centrale de plus est du même type que la première)
  -- lot CENTRALE-PRES : taille et poteau OBTENABLES (le gabarit de 4 chaudières ne tient pas avec le petit poteau et cédait au moyen,
  -- recette fermée : 34 poteaux réservés 30 min, projet 2 de la partie neuve 0.6.70) ; aucun poteau obtenable : refus tout de suite
  local pole
  nb, pole = PlantArms.size(f, first.spec.gen, nb, first.spec.pole, tick, secours)
  if not nb then return nil end
  local id = Build.request(f, { gen = first.spec.gen, args = { nb }, feed = true, prio = Build.PRIO + 5, domain = "infrastructures",
    pole = pole, plant = true }) -- (intégration 0.6.28 : même poteau que la première, voir l'alimentation)
  if not id then return nil end
  b.projects[id].secours = secours or nil -- lot TV-ENERGIE (G65) : unité de secours, projet DISTINCT (journal, bancs)
  b.extra_plants = b.extra_plants or {}
  b.extra_plants[#b.extra_plants + 1] = id
  -- lot ENERGIE-CROISSANCE : le courant qui manque arrête la production principale : la centrale de plus est un besoin de PRODUCTION
  -- servi en premier (réserve au coffre, plan), APRÈS ce qui répare et protège (projets rouverts, enceinte, îlots) et les autres
  -- centrales ; Build.request la mettait en queue, derrière tous les projets ouverts.
  local front, rest = {}, {}
  for _, x in ipairs(b.order) do
    local q = b.projects[x]
    if x ~= id then
      -- (lot FUITES-PILE : « ce qui répare » = reconstruction ou murs rouverts, pas un pas d'agrandissement d'une ligne)
      if q and ((q.reopened and (Sweep.rebuilding(q) or not q.ligne)) or (q.spec and (q.spec.enceinte or q.spec.ilot or q.spec.gen == first.spec.gen))) then front[#front + 1] = x
      else rest[#rest + 1] = x end
    end
  end
  front[#front + 1] = id
  for _, x in ipairs(rest) do front[#front + 1] = x end
  b.order = front
  local g = b.grow or {}
  log(string.format("[FO-ENERGIE] %s : decision : centrale de %d chaudiere(s) demandee a %.1f min (projet %d, rang %d sur %d ; production %.0f kW sur %.0f kW de capacite, %d centrale(s) finie(s))",
    f.key or "player", nb, tick / 3600, id, #front - #rest, #front, (g.power or 0) * 60 / 1000, (g.capacity or 0) * 60 / 1000, g.done or 0))
  return id
end

---------------------------------------------------------------------------------------------------
-- Réservation au coffre
---------------------------------------------------------------------------------------------------
local function needs_of(p)
  local need = {}
  for _, e in ipairs(p.ents) do
    if not e.built and e.item then
      bump(need, e.item)
      if e.name == "burner-inserter" then bump(need, "coal", 2) end
      if e.subst then bump(need, T.fuel, Rr.SUBST_FUEL) end -- lot REBUILD-RAPIDE (d) : combustible de la foreuse à combustion de secours
      if e.charge then bump(need, e.charge.item, e.charge.count) end -- lot CHAMP : coffre de combustible posé garni
    end
  end
  local lq = p.spec and p.spec.liaison
  if lq and lq.extra and not p.piq_placed then bump(need, lq.extra.item) end -- lot PIQUAGE : le répartiteur, posé par le script à la fin du projet
  return need
end

--- Stock LIBRE du coffre (lot IA3-e) : le coffre moins ce que les tâches prises y ont réservé (registre d'IA3-b,
--- Board.view_stock ; registre éteint : le coffre tel quel). Le chantier ne prend plus la matière promise à une tâche
--- (critère K4 : 0 échec « stock »).
local function free_stock(f)
  return Board.view_stock(f, Stock.contents(f), game.tick)
end

--- Lot ESPACE : recette du mur lue au moteur (ingrédients-objets seuls) : { item, ings, per } ou nil (pas de mur, recette
--- inconnue ou fermée à l'équipe, fluide en ingrédient). Les ingrédients ne sont écrits nulle part : ni nom ni quantité.
local function wall_recipe(f)
  local item = item_of(T.wall)
  local rec = game.recipe_prototypes[T.wall]
  local fo = game.forces[f.force]
  local fr = fo and fo.recipes[T.wall]
  if not (item and rec and fr and fr.enabled) then return nil end
  local ings = {}
  for _, ing in ipairs(rec.ingredients) do
    if ing.type ~= "item" then return nil end
    ings[#ings + 1] = { name = ing.name, amount = ing.amount }
  end
  local per = 1
  for _, pr in ipairs(rec.products) do if pr.name == item then per = pr.amount or 1 end end
  return { item = item, ings = ings, per = per }
end

--- Lot ESPACE : murs que les ingrédients du coffre permettent de fabriquer d'un coup (fabrication « au coffre », instantanée,
--- payée en ingrédients : personne ne fabrique de mur sinon).
local function craftable_walls(f, wr)
  return Enc.crafts_possible(wr.ings, function(n) return Stock.count(f, n) end) * wr.per
end

--- Lot ESPACE : transforme au coffre les ingrédients en murs pour couvrir ce qui manque au projet (une réserve d'enceinte).
local function craft_walls(f, p)
  local wr = wall_recipe(f)
  if not wr then return end
  local need = needs_of(p)[wr.item] or 0
  local missing = need - (p.stock[wr.item] or 0) - Stock.count(f, wr.item)
  local runs = Enc.crafts_to_run(missing, wr.per, Enc.crafts_possible(wr.ings, function(n) return Stock.count(f, n) end))
  if runs <= 0 then return end
  for i, ing in ipairs(wr.ings) do
    local want = ing.amount * runs
    local got = Stock.remove(f, ing.name, want)
    if got < want then -- ne devrait pas arriver (compté dans le même tick) : tout est rendu, rien n'est fabriqué
      Stock.insert(f, ing.name, got)
      for j = 1, i - 1 do Stock.insert(f, wr.ings[j].name, wr.ings[j].amount * runs) end
      return
    end
  end
  local made = wr.per * runs
  local put = Stock.insert(f, wr.item, made)
  if put < made then -- coffre plein : les fabrications entières qui n'ont pas tenu rendent leurs ingrédients
    local back = math.floor((made - put) / wr.per)
    if back > 0 then for _, ing in ipairs(wr.ings) do Stock.insert(f, ing.name, ing.amount * back) end end
  end
  p.crafted = (p.crafted or 0) + put
end

--- Lot FUITES-PILE (fuite b) : famille de la pile dont dépend la RÉSERVE au coffre du projet `p`, ou nil (jamais suspendue). Seuls les
--- projets marqués par leur demandeur (p.spec.pile : modules de l'automatisation et de la capitalisation, ligne d'une migration du champ)
--- passent par la porte ; une reconstruction (Sweep.rebuilding : pièces détruites à refaire) jamais ; un pas d'agrandissement d'une ligne
--- (ligne_open) non plus ici : il n'est ouvert que matière réunie et la ligne ne sert plus ses quais en « reserve » (la porte est à
--- Build.ligne_step) ; une migration déjà EN CHANTIER (paires retirées) non plus (PileRt.migration_building, comme script/team/team.lua).
local function pile_family(f, p)
  local fam = p.spec and p.spec.pile
  if not fam or Sweep.rebuilding(p) or (p.reopened and p.reopened ~= 0) then return nil end
  if fam == "migration" and PileRt.migration_building(f) then return nil end
  return fam
end

local function reserve(f, p)
  local need = needs_of(p)
  local missing = {}
  -- lot CC-PRIO-LIGNES (F532) : une ligne de rapatriement ne prend pas ce qui manque aux bandes de champ actives (les bandes d'abord)
  local free = Build.RpPart.libre_pour(p.spec, free_stock(f), f.build.projects, f.build.order)
  for _, it in ipairs(sorted_keys(need)) do
    local want = need[it] - (p.stock[it] or 0)
    if want > 0 then
      local have = math.min(Stock.count(f, it), free[it] or 0)
      local n = math.min(want, have)
      if n > 0 then
        local got = Stock.remove(f, it, n)
        bump(p.stock, it, got)
        want = want - got
      end
      if want > 0 then missing[#missing + 1] = { it, want } end
    end
  end
  p.missing = missing
  return #missing == 0, need -- (need : lu par le chantier progressif, lot EXPANSION-LOINTAINE)
end

--- Lot CC-PETROLE : objets de TÊTE d'une extension de champ de puits (rôle « extracteur » de son plan, pas encore bâtis), lus par
--- Build.Cp.go : l'extension part dès qu'un chevalet est réservé, les suivants se posent à leur arrivée. nil hors extension.
local function lead_items(p)
  if not (p.spec and p.spec.ext) then return nil end
  local out
  for _, e in ipairs(p.ents) do
    if e.role == "extracteur" and e.item and not e.built then
      out = out or {}
      out[e.item] = true
    end
  end
  return out
end

--- Lot INTEG-RECONSTRUCTION (D6) : les objets qui MANQUENT au coffre pour les pièces à refaire d'un projet ROUVERT qui n'est plus en
--- « reserve » (fantômes, chantier : le relevé en rouvre par passes de 40, Rv et une nouvelle destruction aussi). `reserve` n'est lu qu'en état
--- « reserve » : sans cela p.missing restait périmé, le cerveau ne fabriquait rien (A.emit) et le PNJ abandonnait « stock » en boucle. Ne retire
--- RIEN au coffre (le PNJ complète sur le stock libre à sa prise, Build.take_reserved) ; écrit seulement p.missing. Un objet que le PNJ porte déjà
--- vers sa pièce compte encore comme besoin (écart transitoire de quelques objets, borné par le nombre de PNJ).
local function refresh_missing(f, p)
  local need = needs_of(p)
  local free = free_stock(f)
  local missing = {}
  for _, it in ipairs(sorted_keys(need)) do
    local want = need[it] - (p.stock[it] or 0)
    if want > 0 then
      local have = math.min(Stock.count(f, it), free[it] or 0)
      if want > have then missing[#missing + 1] = { it, want - have } end
    end
  end
  p.missing = missing
end

--- Lot QGSURVIE (règle 1, shared/team/survie_qg.lua, Sq.module_held) : votre équipe ; le fer au coffre est-il sous la réserve du QG
--- (f.team.qg_reserve, écrite par Team.view) ? Un module rouvert pour reconstruction n'arrive pas ici (pile_family, appelant). Une ligne
--- [FO-QGSURVIE] à l'entrée et à la sortie de la retenue de chaque projet (`what` : « reserve » ou « ligne »). Rend vrai si retenu.
local function qg_held(f, p, what, tick)
  if not (T.qg_reserve_on and f.is_player and f.team and f.team.qg_reserve) then return false end
  local iron = Stock.count(f, T.outposts.iron.product)
  local held = Sq.module_held({ iron = iron, reserve = f.team.qg_reserve, rebuild = false })
  local key = what == "ligne" and "qg_hold_ln" or "qg_hold"
  if held ~= (p[key] == true) then
    log(string.format("[FO-QGSURVIE] %s : projet %d (%s, %s) %s a %.1f min : fer au coffre %d, reserve du QG %d", f.key or "player", p.id,
      tostring(p.spec and p.spec.pile), what, held and "RETENU (module neuf sous la reserve du QG)" or "libere", tick / 3600, iron,
      f.team.qg_reserve))
    f.team.qg_holds = (f.team.qg_holds or 0) + (held and 1 or 0)
  end
  p[key] = held or nil
  return held
end

local function release(f, p)
  for _, it in ipairs(sorted_keys(p.stock)) do
    local n = p.stock[it]
    if n > 0 and f.hq and f.hq.valid then
      local put = Stock.insert(f, it, n)
      p.stock[it] = n - put
    end
  end
end

--- Lot AZURE : rend au coffre de l'équipe la matière réservée par le projet `p` (bande mise en réserve définitive par script/team/migration_champ.lua :
--- ses entités bâties restent, aucune matière ne reste retenue pour elle). Seul le retour à l'état d'avant la réserve ; rien d'autre.
function Build.give_back(f, p)
  release(f, p)
end

--- Lot FUITES-PILE (fuite b) : la réserve au coffre du projet `p` (état « reserve ») est-elle suspendue par la pile ? Un module NEUF est une
--- amélioration (R3) : pendant qu'un cadre réparer, protéger ou survivre retient, il ne prend rien au coffre et REND ce qu'il avait pris
--- (p.stock), ses manques sont effacés (aucun but ne les fabrique), raison « pile », relu dans une seconde ; sauf s'il produit une matière
--- d'un cadre ouvert ou qui manque (PileRt.porte). Un module rouvert pour reconstruction n'est jamais suspendu (pile_family). Avant, le
--- module neuf réservait le fer des tourelles exactement comme un module rouvert pour reconstruction. Rend vrai si suspendue.
function Build.reserve_suspended(f, p, tick)
  local fam = pile_family(f, p)
  if not fam then return false end
  -- Lot QGSURVIE (règle 1) : sous la réserve de fer du QG, un module neuf ne prend rien, même s'il produit une matière qui manque.
  if qg_held(f, p, "reserve", tick) then
    release(f, p)
    p.missing = {}
    p.reason, p.reserve_next = "qg", tick + 60
    return true
  end
  local ok, why = PileRt.porte(f, fam, p.spec.product)
  if ok then return false end
  release(f, p)
  p.missing = {}
  p.reason, p.reserve_next = "pile", tick + 60
  PileRt.refuse(f, "projet:" .. p.id, string.format("projet %d (%s, %s) : reserve au coffre suspendue, objets rendus (%s)", p.id, fam,
    tostring(p.spec.product), tostring(why)), tick)
  return true
end

--- Lot FUITES-PILE : l'agrandissement de la ligne finie du projet `p` (Build.ligne_step) est-il suspendu par la pile ? C'est un
--- investissement de production : pendant une retenue, seulement pour une matière d'un cadre ouvert ou qui manque ; la ligne déjà bâtie
--- continue de produire, ses pièces du pas suivant ne sont plus demandées (ln.missing effacé). Rend vrai si suspendu.
function Build.grow_suspended(f, p, ln, tick)
  -- (relecture : le produit, et le minerai de la ligne, au cadre ouvert ; une ligne FINIE d'une sauvegarde 0.6.21 n'a pas de
  -- spec.product, Build.tag ne marquant que les modules encore ouverts : sans le minerai, la ligne du fer des tourelles restait
  -- suspendue pendant tout un siège ; le minerai d'une plaque d'un cadre est dans focus, Pi.update produce)
  -- Lot QGSURVIE (règle 1) : l'agrandissement est un investissement : retenu sous la réserve de fer du QG
  if qg_held(f, p, "ligne", tick) then
    ln.missing = nil
    return true
  end
  local items = {}
  if p.spec and p.spec.product ~= nil then items[#items + 1] = p.spec.product end
  if ln.ore ~= nil then items[#items + 1] = ln.ore end
  local ok, why = PileRt.porte_any(f, "invest", items)
  if ok then return false end
  ln.missing = nil
  PileRt.refuse(f, "ligne:" .. p.id, string.format("projet %d, ligne %s : agrandissement suspendu (%s)", p.id, tostring(ln.ore),
    tostring(why)), tick)
  return true
end

--- Lot IA3-e : annule une demande pas encore en chantier (attente, plan, réserve) : objets réservés rendus au coffre,
--- tuiles et lots libérés ; état « refuse » (raison donnée). Rend vrai si la demande a été annulée.
--- Lot RANGEES-ASM : agrandit sur place le gabarit d'un module ENCORE EN ATTENTE (rien de posé ni de réservé) : ses
--- arguments deviennent `args` (rangée plus longue, mêmes tapis prolongés). Rend vrai si le projet a été changé.
function Build.resize_waiting(f, id, args)
  local p = f and f.build and f.build.projects[id]
  if not (p and p.state == "attente" and p.spec and type(args) == "table") then return false end
  local a = {}
  for i = 1, #args do a[i] = args[i] end
  p.spec.args = a
  return true
end

function Build.cancel(f, id, why)
  local b = f and f.build
  local p = b and b.projects[id]
  if not (p and (p.state == "attente" or p.state == "plan" or p.state == "reserve")) then return false end
  if p.reopened then return false end -- lot CORR-RESEAU : un projet déjà bâti dont des pièces sont à refaire n'est pas annulable
  -- lot CORR-RESEAU : la centrale de remplacement (p.keep) n'est annulée que par la santé du réseau (raison « reseau: ... »)
  if p.keep and not tostring(why):find("^reseau") then return false end
  release(f, p)
  for k, v in pairs(b.occ) do if v == p.id then b.occ[k] = nil end end
  for _, l in pairs(b.lots) do if l.used == p.id then l.used = nil end end
  for _, n in ipairs(sorted_keys(b.net)) do if b.net[n].pid == p.id then b.net[n] = nil end end
  p.ents, p.parts = {}, {}
  p.state, p.reason = "refuse", why or "annule"
  b.stats.projects_refused = b.stats.projects_refused + 1
  if b.plant == p.id then b.plant = nil end
  log(string.format("[FO-IA1D] %s : projet %d annule (%s)", f.key or "player", p.id, tostring(p.reason)))
  return true
end

--- Prise au stock du chantier (étape « take_res » d'un PNJ) : rend vrai si tout a été pris.
function Build.take_reserved(f, pid, items, inv)
  local p = f.build and f.build.projects[pid]
  if not p then return false end
  local all = true
  local free = nil
  for _, it in ipairs(items) do
    local want = it[2]
    local have = p.stock[it[1]] or 0
    if have < want then
      -- complément au coffre (un PNJ a pu rapporter des objets) : sur le stock LIBRE seulement (lot IA3-e, K4)
      free = free or free_stock(f)
      local add = math.min(want - have, Stock.count(f, it[1]), free[it[1]] or 0)
      if add > 0 then have = have + Stock.remove(f, it[1], add) end
    end
    local n = math.min(want, have)
    local put = n > 0 and inv.insert({ name = it[1], count = n }) or 0
    p.stock[it[1]] = have - put
    if put < want then all = false end
  end
  return all
end

--- Lot BANDE-FIN-TAPIS (F475) : inverse de Build.take_reserved. Une tâche de chantier ABANDONNÉE (Worker.abort : PNJ rappelé, en fuite,
--- chemin, bail) rend à la réserve de SON projet ce que le PNJ porte encore de ses objets, au plus le compte de la tâche. Avant, le retour au QG
--- (deposit_inventory) remettait ces objets d'abord aux modules en réserve (AmRt.deliver), puis au coffre libre : graine 123456789, à 29,5 min,
--- les 24 tapis de la bande -30 du joueur (projet 4, 341/365) sont partis à la bande suivante encore à 0/366 ; la bande est restée à 341/365
--- jusqu'à 90 min (p.stock 0, coffre 0, échecs « stock » en boucle). Projet fini, refusé ou inconnu : rien n'est rendu (sa réserve est déjà
--- rendue au coffre, release). Rend le nombre d'objets rendus.
function Build.restore_reserved(f, pid, items, inv)
  local p = f.build and f.build.projects[pid]
  if not (p and p.stock and inv) or p.state == "fini" or p.state == "refuse" then return 0 end
  local n = 0
  for _, it in ipairs(items or {}) do
    local k = math.min(it[2], inv.get_item_count(it[1]))
    if k > 0 then
      local got = inv.remove({ name = it[1], count = k })
      if got > 0 then
        p.stock[it[1]] = (p.stock[it[1]] or 0) + got
        n = n + got
      end
    end
  end
  return n
end

---------------------------------------------------------------------------------------------------
-- Fantômes
---------------------------------------------------------------------------------------------------
local function find_real(surface, e, force)
  local found = surface.find_entity(e.name, { e.x, e.y })
  if found and found.force.name == force then return found end
  return nil
end

local function find_ghost(surface, e, force)
  for _, gh in ipairs(surface.find_entities_filtered({ position = { e.x, e.y }, radius = 0.3, name = "entity-ghost", force = force })) do
    if gh.ghost_name == e.name then return gh end
  end
  return nil
end

--- Ce qui occupe l'emprise d'une entité planifiée (journal d'un refus) : entités triées, tuiles d'eau.
local function blockers(surface, e)
  local w, h = P.size(e.name, e.dir)
  local area = { { e.x - w / 2 + 0.05, e.y - h / 2 + 0.05 }, { e.x + w / 2 - 0.05, e.y + h / 2 - 0.05 } }
  local out = {}
  for _, x in ipairs(surface.find_entities_filtered({ area = area })) do
    out[#out + 1] = string.format("%s%s %s (%.2f, %.2f) dir %d", x.name, x.name == "entity-ghost" and ("/" .. x.ghost_name) or "",
      x.force.name, x.position.x, x.position.y, x.direction or 0)
  end
  table.sort(out)
  local wet = surface.count_tiles_filtered({ area = area, collision_mask = "water-tile" })
  return (#out > 0 and table.concat(out, ", ") or "rien") .. " ; eau " .. wet .. " tuile(s)"
end

local function log_refusal(f, p, e, why, surface)
  e.why = tostring(why) -- lot AZURE : dernier motif de refus de la pièce (chaîne), lu par la trace [FO-CHANTIER-LENT] ; posé avant le plafond du journal
  local st = f.build.stats
  st.refusal_logs = (st.refusal_logs or 0) + 1
  if st.refusal_logs > Build.REFUSAL_LOGS then return end
  log(string.format("[FO-IA1D] %s : projet %d, fantome refuse (%s) : %s en (%g, %g) dir %d ; emprise : %s", f.key or "player",
    p and p.id or 0, why, e.name, e.x, e.y, e.dir or 0, blockers(surface, e)))
end

--- Emprise d'une entité planifiée, rognée de 0,05 (les voisins qui la touchent ne comptent pas, F96).
local function footprint(e)
  local w, h = P.size(e.name, e.dir)
  return { { e.x - w / 2 + 0.05, e.y - h / 2 + 0.05 }, { e.x + w / 2 - 0.05, e.y + h / 2 - 0.05 } }
end

--- Un personnage (PNJ, joueur) debout sur l'emprise : refus passager.
local function npc_on(surface, e)
  -- Lot IA3-e : un SOLDAT (unité) debout sur l'emprise est aussi un passager (moteur réel, e2-usine : fantômes d'emerald
  -- refusés « occupe » par fo-emerald-rifleman et fo-emerald-rocketeer, chantier bloqué près du QG).
  return surface.count_entities_filtered({ area = footprint(e), type = { "character", "unit" }, limit = 1 }) > 0
end

Build.OBST_LOGS = 12 -- lot OBSTACLES : lignes [FO-OBSTACLES] écrites au plus, par équipe

--- Lot OBSTACLES : un fantôme refusé « occupe » alors qu'une FALAISE touche son emprise (le moteur la voit, les masques ne la voyaient
--- pas : emprise réelle selon l'orientation). Les tuiles de la falaise (modèle de shared/team/falaise.lua) et celles de l'entité
--- refusée (ce que le moteur a vraiment refusé) sont apprises dans b.hard, que read_masks bloque désormais ; le relevé en cache de
--- la zone est jeté. Rend vrai si une falaise est en cause : l'entité est marquée (e.cliff_hit), et le projet ne retentera pas le
--- même plan 3 fois de suite (voir le blocage du chantier), la reprise se fait par un NOUVEAU plan.
local function learn_cliff(f, surface, p, e, r)
  if r ~= "occupe" then return false end
  local cliffs = surface.find_entities_filtered({ area = footprint(e), type = "cliff" })
  if #cliffs == 0 then return false end
  local b = f.build
  b.hard = b.hard or { n = 0, t = {} }
  local added = 0
  for _, c in ipairs(cliffs) do
    if c.valid then added = added + FalPure.learn(b.hard, Fal.tiles(c), P.tkey) end
  end
  local a = footprint(e)
  added = added + FalPure.learn(b.hard, FalPure.box_tiles(a[1][1], a[1][2], a[2][1], a[2][2]), P.tkey)
  if not e.cliff_hit then
    b.stats.cliff_hits = (b.stats.cliff_hits or 0) + 1
    b.hard_logs = (b.hard_logs or 0) + 1
    if b.hard_logs <= Build.OBST_LOGS then
      log(string.format("[FO-OBSTACLES] %s : projet %d, %s en (%g, %g) refuse par %d falaise(s) (%s) : %d tuile(s) apprise(s) (%d en memoire), nouveau plan a la reprise",
        f.key or "player", p and p.id or 0, tostring(e.name), e.x, e.y, #cliffs, tostring(cliffs[1].valid and cliffs[1].cliff_orientation), added, b.hard.n))
    end
  end
  e.cliff_hit = true
  if MASQ[surface.index] then
    Mq.invalidate(MASQ[surface.index], math.floor(a[1][1]) - 6, math.floor(a[1][2]) - 6, math.ceil(a[2][1]) + 6, math.ceil(a[2][2]) + 6)
  end
  return true
end

--- Pose le fantôme d'une entité planifiée : "ok", "deja" (bâtie), "obstacle" (arbre, rocher), "pnj" (un personnage
--- debout dessus, passager), "occupe" (autre).
--- Lot CORR-RESEAU : retire les RESTES neutres (cadavres de machine, objets au sol) de l'emprise d'une pièce à poser, marge de 0,6.
--- Mesuré le 29/10 (essai court 20261020, journal [FO-IA1D]) : la chaudière détruite d'une centrale n'était jamais reposée, son
--- fantôme refusé « occupe » 11 min de suite, l'emprise ne portant plus que deux item-on-ground neutres au bord (les bras à combustion
--- de la centrale y lâchent leur charbon, la cible ayant disparu) ; un cadavre seul ne bloque pas (expérience reseau-restes).
--- Lot CC-DORMANT (F496) : les DÉBRIS SOLIDES neutres de l'épave de départ (types de prototype ci-dessous, force neutre, minables) posés
--- DANS l'emprise sont retirés aussi. Mesuré (partie du DC, 0.6.88, graine 1732508881) : un débris de l'épave sur la tuile d'un poteau
--- faisait refuser son fantôme « occupe » 14 fois (ni arbre ni rocher, donc jamais défriché) ; la bande -33 du gisement 100002 restait
--- bloquée de 21 à 60 min, gardait le créneau du fer, et la bande de l'avant-poste 1 payée par 27 foreuses électriques dormantes ne
--- partait pas (55 foreuses au coffre, 105 à 189 PNJ sans tâche). Les bancs ne posent pas l'épave : jamais vu avant le DC (cf. F490).
Build.DEBRIS_TYPES = { "simple-entity-with-owner", "container" }
local function clear_floor(surface, e)
  local a = footprint(e)
  local n = 0
  for _, d in ipairs(surface.find_entities_filtered({ area = { { a[1][1] - 0.6, a[1][2] - 0.6 }, { a[2][1] + 0.6, a[2][2] + 0.6 } },
    type = { "corpse", "item-entity" }, force = "neutral" })) do
    if d.valid then d.destroy() n = n + 1 end
  end
  for _, d in ipairs(surface.find_entities_filtered({ area = a, type = Build.DEBRIS_TYPES, force = "neutral" })) do
    if d.valid and d.minable then d.destroy() n = n + 1 end
  end
  return n
end

local function place_ghost(surface, f, e)
  if find_real(surface, e, f.force) then return "deja" end
  if find_ghost(surface, e, f.force) then return "ok" end
  local function can_place()
    return surface.can_place_entity({ name = e.name, position = { e.x, e.y }, direction = e.dir, force = f.force,
      build_check_type = defines.build_check_type.ghost_revive })
  end
  if not can_place() and not (clear_floor(surface, e) > 0 and can_place()) then
    local area = footprint(e)
    if surface.count_entities_filtered({ area = area, type = TREE_TYPES, limit = 1 }) > 0 then return "obstacle" end
    if npc_on(surface, e) then return "pnj" end
    return "occupe"
  end
  -- lot FONDERIE : `type` (« input » | « output ») d'un tapis souterrain, passé au fantôme comme à l'entité (H-FONDERIE-1, à prouver au banc)
  local gh = surface.create_entity({ name = "entity-ghost", inner_name = e.name, position = { e.x, e.y }, direction = e.dir,
    force = f.force, expires = false, type = e.type })
  if not gh then return "occupe" end
  return "ok"
end

--- Lot TOURELLES-HORS-AXE : une tourelle ENREGISTRÉE de l'équipe (f.turrets, posée par les avant-postes ; jamais celle d'un joueur) qui
--- occupe seule l'emprise d'une pièce à poser du projet n'est plus enlevée : elle est DÉPLACÉE à côté (teleport : munitions, santé et
--- registre gardés), d'abord sur le côté de la ligne dont elle bloque le couloir (Axe.side_spots), sinon sur l'anneau voisin
--- (Blocage.spots), jamais sur une tuile réservée (Build.reserved_entity : b.occ) ni dans un couloir (Build.axis_entity), ni sur une tuile de
--- ressource (lot TOURELLES-MINERAI : PlacesQG.on_resource, la règle de shared/team/sol_minerai.lua ; scarlet, graine 2507543475, 26,5 min :
--- tourelle déplacée de (374, -344) en (374, -347), sur son fer, puis montée en fo-lvl-gun-2 à la même place). Appelé au
--- refus « occupe » d'un fantôme (revive_one, phase « fantomes ») : la ligne qui s'étend la pousse tout de suite, sans attendre le
--- blocage du projet. Rend vrai si TOUTES les tourelles de l'emprise ont été déplacées. Journal [FO-AXE], une ligne par tourelle.
local function move_turrets_off(f, surface, p, e)
  if not (f.turrets and f.build) then return false end
  -- lot TOURELLE-BANDE : seules les entités SOLIDES de l'emprise comptent (couche « object-layer », comme le relevé des obstacles) : le
  -- minerai du gisement sous une bande n'est pas un obstacle, et il ne doit être ni téléporté ni repris au coffre
  local found = surface.find_entities_filtered({ area = footprint(e), collision_mask = "object-layer" })
  local list = {}
  for _, x in ipairs(found) do
    local mine = x.unit_number ~= nil and f.turrets[x.unit_number] ~= nil
    list[#list + 1] = { name = x.name, force = mine and x.force.name or "non-enregistree", solid = true }
  end
  if not Blocage.own_blockers(list, f.force, T.turret) then return false end
  local cors = Build.corridors(f)
  for _, x in ipairs(found) do
    if x.valid then
      local from = x.position
      local pr = game.entity_prototypes[x.name] or {}
      local spots = Axe.side_spots(from.x, from.y, cors, pr.tile_width or 1, pr.tile_height or 1)
      for _, s in ipairs(Blocage.spots(from.x, from.y)) do spots[#spots + 1] = s end
      local pos = Blocage.first_free(spots,
        function(c) return surface.find_non_colliding_position(x.name, { x = c.x, y = c.y }, 4, 1) end,
        function(q) return Build.reserved_entity(f, x.name, q) or Build.axis_entity(cors, x.name, q) ~= nil or PlacesQG.on_resource(surface, x.name, q) end)
      local d = Build.Tj.describe(x) -- lot TOURELLE-JOURNAL (avant le téléport)
      if not (pos and x.teleport(pos)) then
        Build.axe_log(f, string.format("projet %d : tourelle en (%g, %g) sur l'emprise de %s en (%g, %g), aucune place libre hors des couloirs : non deplacee",
          p.id, from.x, from.y, tostring(e.name), e.x, e.y))
        return false
      end
      f.build.stats.turrets_moved = (f.build.stats.turrets_moved or 0) + 1
      Build.Tj.removed(d, "chantier de l'equipe " .. tostring(f.key), "emprise de " .. tostring(e.name) .. " (projet " .. tostring(p.id) .. ")",
        string.format("deplacee en (%.1f, %.1f)", x.position.x, x.position.y))
      Build.axe_log(f, string.format("projet %d : tourelle deplacee de (%g, %g) a (%g, %g) : elle occupait l'emprise de %s en (%g, %g) ; %d couloir(s) d'extension",
        p.id, from.x, from.y, x.position.x, x.position.y, tostring(e.name), e.x, e.y, #cors))
    end
  end
  return true
end

--- Lot RETROFIT (F556) : les entités de l'ÉQUIPE à brûleur (foreuses thermiques, fours en pierre du début) qui occupent l'emprise d'une pièce
--- d'une BANDE de champ, une fois l'ère électrique datée (Elec.era), sont DÉMONTÉES par le chantier lui-même : contenus de tous leurs
--- inventaires et objet de minage rendus au stock (rien si le stock ne tient pas tout), registre de l'avant-poste lâché (State.disown) avant
--- la destruction. Règle pure : Saut.relics (shared/team/champ_saut.lua). Partie du DC (0.7.3, projet 70, bande 40) : 4 paires thermiques sous
--- la bande, la foreuse sautée et le reste refusé « occupe », la bande restait en chantier. Rend le nombre d'entités démontées.
Build.relics_off = function(f, surface, p, e)
  local era = Build.Elec.era(f)
  if not (era and p.spec) then return 0 end
  local found = surface.find_entities_filtered({ area = footprint(e), collision_mask = "object-layer" })
  local bl = {}
  for i, x in ipairs(found) do
    local pr = x.valid and x.prototype or nil
    bl[i] = { own = pr ~= nil and x.force.name == f.force, burner = pr ~= nil and pr.burner_prototype ~= nil,
      power = pr ~= nil and ((x.fluidbox ~= nil and #x.fluidbox > 0) or pr.electric_energy_source_prototype ~= nil) }
    -- lot RELIQUES-SOUS-BANDE : `outpost` = foreuse ou réception inscrite à un avant-poste de l'équipe (le registre que lit le plan, mine_of) ;
    -- `piece` = pièce non cédée d'un projet du plan (détenteur b.occ de sa tuile centrale, même nom, même position) : jamais démontée
    local ow = pr ~= nil and x.unit_number and State.owner(x.unit_number) or nil
    bl[i].outpost = ow ~= nil and ow.f == f.id and (ow.kind == "drill" or ow.kind == "sink")
    local q = pr ~= nil and f.build.occ and f.build.projects[f.build.occ[P.tkey(math.floor(x.position.x), math.floor(x.position.y))] or false] or nil
    for _, pe in ipairs(q and q.ents or {}) do
      if not pe.dropped and pe.name == x.name and pe.x == x.position.x and pe.y == x.position.y then bl[i].piece = true break end
    end
  end
  local n = 0
  for _, i in ipairs(Saut.relics(p.spec.site, era, bl)) do
    local x = found[i]
    if x.valid then
      local want, invs = {}, {}
      for k = 1, (x.get_max_inventory_index() or 0) do
        local inv = x.get_inventory(k)
        if inv and not inv.is_empty() then
          invs[#invs + 1] = inv
          local c = inv.get_contents()
          local names = {}
          for name in pairs(c) do names[#names + 1] = name end
          table.sort(names)
          for _, name in ipairs(names) do want[#want + 1] = { name, c[name] } end
        end
      end
      for _, pd in ipairs(x.prototype.mineable_properties.products or {}) do
        if pd.type ~= "fluid" then want[#want + 1] = { pd.name, pd.amount or pd.amount_max or 1 } end
      end
      if Stock.can_take and not Stock.can_take(f, want) then break end -- STOCKAGE-VITAL : rien au sol, la pièce attend
      for _, w in ipairs(want) do
        local put = Stock.insert(f, w[1], w[2])
        if put < w[2] then surface.spill_item_stack(f.hq_pos, { name = w[1], count = w[2] - put }, true, f.force, false) end
      end
      local d = string.format("%s en (%.1f, %.1f)", x.name, x.position.x, x.position.y)
      if x.unit_number then State.disown(x.unit_number) end
      x.destroy()
      n = n + 1
      local st = f.build.stats
      st.relics = (st.relics or 0) + 1
      if st.relics <= Build.REFUSAL_LOGS then
        log(string.format("[FO-RETROFIT] %s : projet %d : relique %s demontee (emprise de %s en (%g, %g), ere electrique depuis %.1f min), contenu et objet au stock",
          f.key or "player", p.id, d, tostring(e.name), e.x, e.y, era / 3600))
      end
    end
  end
  return n
end

--- Refus passager (un personnage sur l'emprise) : compté à part ; Build.NPC_BLOCKS_PER_FAIL refus valent un échec.
local function npc_block(f, p, e, surface)
  local st = f.build.stats
  st.npc_blocks = (st.npc_blocks or 0) + 1
  e.npc_blocks = (e.npc_blocks or 0) + 1
  -- Lot IA3-e : un SOLDAT de l'équipe en garnison ne quitte jamais l'emprise (moteur réel, e9-usine graine 20261020 après
  -- la fusion de main 0.5.0 : fonderie d'emerald bloquée 50 min à 68 entités sur 69, un bras sous fo-emerald-rifleman) :
  -- il s'écarte (téléporté sur la case libre la plus proche HORS de l'emprise). Les personnages (PNJ) bougent seuls.
  local a = footprint(e)
  -- Lot AUTO : un PNJ (personnage SANS joueur) de l'équipe arrêté sur l'emprise s'écarte aussi (moteur réel, a4-usine
  -- graine 271828182, emerald : fonderie à 133 entités sur 135 de 58 à 75 min, four refusé « pnj » ; « les PNJ bougent
  -- seuls » ne vaut pas pour un PNJ sans tâche). Un personnage d'un joueur n'est jamais déplacé.
  local movers = surface.find_entities_filtered({ area = a, type = "unit", force = f.force })
  for _, c in ipairs(surface.find_entities_filtered({ area = a, type = "character", force = f.force })) do
    if not c.player then movers[#movers + 1] = c end
  end
  for _, u in ipairs(movers) do
    local target = { x = a[2][1] + 2, y = (a[1][2] + a[2][2]) / 2 }
    local pos = surface.find_non_colliding_position(u.name, target, 8, 0.5)
    if pos and not (pos.x > a[1][1] - 0.5 and pos.x < a[2][1] + 0.5 and pos.y > a[1][2] - 0.5 and pos.y < a[2][2] + 0.5) then
      u.teleport(pos)
      st.npc_moved = (st.npc_moved or 0) + 1
    end
  end
  if e.npc_blocks % Build.NPC_BLOCKS_PER_FAIL == 0 then e.fails = (e.fails or 0) + 1; p.fails_lus = nil end -- lot UPS : un refus de plus, le chantier relit ses pièces (advance)
  log_refusal(f, p, e, "pnj", surface)
end

--- Le bâtisseur `self` est-il debout sur l'emprise de `e` (marge 0,3) ?
local function stands_on(self, e)
  if not (self and self.valid) then return false end
  local a, q = footprint(e), self.position
  return q.x > a[1][1] - 0.3 and q.x < a[2][1] + 0.3 and q.y > a[1][2] - 0.3 and q.y < a[2][2] + 0.3
end

--- Écarte le bâtisseur de l'emprise de `e` : case libre la plus proche à l'est de l'emprise, HORS de toute emprise
--- visée (comme npc_block pour les autres PNJ). Rend vrai s'il ne gêne plus. Sans cela, un bâtisseur arrêté sur le
--- dernier poteau et la dernière machine d'une centrale les « laissait » à chaque pensée en payant ses jetons, et la
--- tâche ne finissait jamais (moteur réel, etape1-guide, VOTRE équipe : centrale à 15 entités sur 17 de 27 à 60 min,
--- module des packs rouges sans courant, aucune foreuse électrique).
local function step_aside(surface, self, e)
  if not stands_on(self, e) then return true end
  local a = footprint(e)
  for _, d in ipairs({ 2, 4, 6 }) do
    local spot = surface.find_non_colliding_position(self.name, { x = a[2][1] + d, y = (a[1][2] + a[2][2]) / 2 }, 6, 0.5)
    if spot then
      self.teleport(spot)
      if not stands_on(self, e) then return true end
    end
  end
  return false
end

--- Lot ELEC2 : un poteau 1 × 1 refusé « occupe » (une falaise que les masques ne voient pas, F294, ou une foreuse à
--- combustion d'un avant-poste posée depuis le plan ; banc etape1-guide : fonderie électrique abandonnée à 181 entités
--- sur 197 sur un seul poteau, 0 foreuse électrique à 60 min) est reposé sur une tuile libre voisine (2 tuiles au plus) qui
--- laisse le réseau local aussi relié qu'avant : mêmes composantes connexes (fil de 7,5 tuiles, poteaux du projet et du
--- réseau alentour). Rend vrai si le fantôme a été posé ailleurs (e.x, e.y changent).
local function shift_pole(f, surface, p, e)
  local reach = P.wire(e.name)
  local w, h = P.size(e.name, e.dir)
  if not reach or w ~= 1 or h ~= 1 then return false end
  local b = f.build
  local win = 2 * reach + 2
  local near = {}
  for _, o in ipairs(p.ents) do
    if o ~= e and P.wire(o.name) and math.abs(o.x - e.x) <= win and math.abs(o.y - e.y) <= win then
      near[#near + 1] = { x = o.x, y = o.y }
    end
  end
  for _, o in ipairs(surface.find_entities_filtered({ position = { e.x, e.y }, radius = win, type = "electric-pole",
    force = f.force })) do
    near[#near + 1] = { x = o.position.x, y = o.position.y }
  end
  -- composantes connexes de `near` plus un poteau en (x, y)
  local function components(x, y)
    local pts = { { x = x, y = y } }
    for _, n in ipairs(near) do pts[#pts + 1] = n end
    local comp, count = {}, 0
    for i = 1, #pts do
      if not comp[i] then
        count = count + 1
        comp[i] = count
        local stack = { i }
        while #stack > 0 do
          local u = table.remove(stack)
          for v = 1, #pts do
            if not comp[v] and (pts[u].x - pts[v].x) ^ 2 + (pts[u].y - pts[v].y) ^ 2 <= reach * reach + 1e-9 then
              comp[v] = count
              stack[#stack + 1] = v
            end
          end
        end
      end
    end
    return count
  end
  local before = components(e.x, e.y)
  local cands = {}
  for dy = -2, 2 do
    for dx = -2, 2 do
      if dx ~= 0 or dy ~= 0 then cands[#cands + 1] = { x = e.x + dx, y = e.y + dy, d = dx * dx + dy * dy } end
    end
  end
  table.sort(cands, function(a, c)
    if a.d ~= c.d then return a.d < c.d end
    if a.y ~= c.y then return a.y < c.y end
    return a.x < c.x
  end)
  local n_occ, n_link, n_ghost = 0, 0, 0
  for _, c in ipairs(cands) do
    local k = P.tkey(math.floor(c.x), math.floor(c.y))
    if b.occ[k] then
      n_occ = n_occ + 1
    elseif components(c.x, c.y) > before then
      n_link = n_link + 1
    elseif place_ghost(surface, f, { name = e.name, x = c.x, y = c.y, dir = e.dir }) == "ok" then
      log(string.format("[FO-IA1D] %s : projet %d, %s deplace de (%g, %g) a (%g, %g) (tuile occupee)", f.key or "player", p.id,
        e.name, e.x, e.y, c.x, c.y))
      b.occ[k] = p.id
      e.x, e.y = c.x, c.y
      b.stats.poles_moved = (b.stats.poles_moved or 0) + 1
      return true
    else
      n_ghost = n_ghost + 1
    end
  end
  if not e.shift_logged then
    e.shift_logged = true
    log(string.format("[FO-IA1D] %s : projet %d, %s en (%g, %g) ne peut pas bouger : %d tuile(s) reservee(s), %d coupant le reseau, %d refusee(s)",
      f.key or "player", p.id, e.name, e.x, e.y, n_occ, n_link, n_ghost))
  end
  return false
end

--- Ravive (ou pose puis ravive) une entité planifiée avec l'objet porté par le PNJ `self` : true si bâtie. Une
--- entité sous les pieds du bâtisseur lui-même est laissée (ni essai, ni échec) : un autre passage la fera.
local function revive_one(surface, f, p, e, inv, tick, self)
  local st = f.build.stats
  if find_real(surface, e, f.force) then e.built = true return true end
  if not e.item or inv.get_item_count(e.item) < 1 then return false end
  if self and self.valid then
    local a, q = footprint(e), self.position
    if q.x > a[1][1] - 0.3 and q.x < a[2][1] + 0.3 and q.y > a[1][2] - 0.3 and q.y < a[2][2] + 0.3 then
      st.self_skips = (st.self_skips or 0) + 1
      return false
    end
  end
  local gh = find_ghost(surface, e, f.force)
  if not gh then
    local r = place_ghost(surface, f, e)
    if r == "deja" then e.built = true return true end
    if r == "pnj" then npc_block(f, p, e, surface) return false end
    if r == "occupe" and move_turrets_off(f, surface, p, e) then r = place_ghost(surface, f, e) end -- lot TOURELLES-HORS-AXE
    if r == "deja" then e.built = true return true end
    if r == "occupe" and shift_pole(f, surface, p, e) then r = "ok" end
    if r == "occupe" and Build.relics_off(f, surface, p, e) > 0 then r = place_ghost(surface, f, e) end -- lot RETROFIT : relique démontée, place libre
    if r == "deja" then e.built = true return true end
    -- lot FONDERIE : une foreuse de BANDE refusée « occupe » pour la 3e fois, quand tout ce qui occupe son emprise est une tourelle de l'équipe
    -- posée après le plan (que move_turrets_off n'a pas pu déplacer), est SAUTÉE : la bande finit et produit sans elle, la tourelle reste
    -- (lot6-20261020 : emerald, bande 329, 551 entités bâties sur 552 jusqu'à la fin)
    if (r == "occupe" or r == "obstacle") and e.role == "champ-foreuse" and Build.TAPIS and Build.TAPIS() then -- CHAMP-OBSTACLES : arbre résiduel compris
      local turret = {}
      for _, t in ipairs(T.TURRET_TYPES or {}) do turret[t] = true end
      local bl = {}
      for _, x in ipairs(surface.find_entities_filtered({ area = footprint(e), collision_mask = "object-layer" })) do
        if x.valid then bl[#bl + 1] = { own_turret = turret[x.type] == true and x.force.name == f.force } end
      end
      if Saut.skip(e.role, r, e.fails or 0, bl, Build.FAIL_LIMIT) then
        -- `dropped` : la revue de reconstruction (rebuild_sweep) ne la rouvre pas comme une pièce détruite (court-g-20261020 : rouverte et
        -- resautée toutes les 5 à 6 min, la bande restait en chantier)
        e.built, e.skipped, e.dropped = true, r, true
        st.skipped = (st.skipped or 0) + 1
        log(string.format("[FO-FONDERIE] %s : projet %d, foreuse de bande (%.1f, %.1f) sautee : emprise refusee « %s » %d fois (tuile sautee, la bande continue)",
          f.key or "player", p.id, e.x, e.y, r, (e.fails or 0) + 1))
        return true
      end
    end
    if r ~= "ok" then
      -- lot PETROLE : sur un site défriché pendant le chantier (spec.lazy_clear), un arbre sous l'emprise n'est pas un
      -- échec (il est coupé par la tâche de défrichage ; moteur réel, petrole-site : raffinerie « bloquée » par un arbre)
      if not (r == "obstacle" and p.spec and p.spec.lazy_clear) then e.fails = (e.fails or 0) + 1; p.fails_lus = nil end -- lot UPS : un refus de plus, le chantier relit ses pièces (advance)
      st.revive_fail = st.revive_fail + 1
      learn_cliff(f, surface, p, e, r) -- lot OBSTACLES : falaise cachée aux masques, apprise
      log_refusal(f, p, e, r, surface)
      if r == "obstacle" then add_obstacle(p, { x = e.x, y = e.y, anchor = e.anchor, ax = e.ax, ay = e.ay }) end
      return false
    end
    st.ghosts = st.ghosts + 1
    gh = find_ghost(surface, e, f.force)
    if not gh then
      e.fails = (e.fails or 0) + 1; p.fails_lus = nil -- lot UPS : un refus de plus, le chantier relit ses pièces (advance)
      st.revive_fail = st.revive_fail + 1
      log_refusal(f, p, e, "fantome pose mais introuvable", surface)
      return false
    end
  end
  clear_floor(surface, e) -- les bras de la centrale relâchent du charbon sur l'emprise d'une chaudière détruite, même sous le fantôme
  inv.remove({ name = e.item, count = 1 })
  local _, ent = gh.revive({ raise_revive = true })
  if not (ent and ent.valid) then
    inv.insert({ name = e.item, count = 1 })
    if npc_on(surface, e) then npc_block(f, p, e, surface) return false end
    e.fails = (e.fails or 0) + 1; p.fails_lus = nil -- lot UPS : un refus de plus, le chantier relit ses pièces (advance)
    st.revive_fail = st.revive_fail + 1
    log_refusal(f, p, e, "ravivage refuse", surface)
    return false
  end
  if e.recipe and ent.type == "assembling-machine" then pcall(ent.set_recipe, e.recipe) end
  -- lot FONDERIE : un souterrain ravivé dans l'autre sens que prévu (si le fantôme n'a pas gardé `type`, H-FONDERIE-1) est retourné ;
  -- journal [FO-FONDERIE] à chaque retournement (le banc dit si la branche sert)
  if e.type then
    local got, bt = pcall(function() return ent.belt_to_ground_type end) -- lisible sur un souterrain seulement
    if got and bt and bt ~= e.type then
      local ok = pcall(ent.rotate)
      log(string.format("[FO-FONDERIE] %s : souterrain (%.1f, %.1f) ravive en %s au lieu de %s, retourne %s", f.key or "player", e.x, e.y,
        tostring(bt), e.type, ok and "oui" or "non"))
    end
  end
  if e.name == "burner-inserter" and inv.get_item_count("coal") >= 2 then
    local fuel = ent.get_fuel_inventory()
    if fuel then fuel.insert({ name = "coal", count = inv.remove({ name = "coal", count = 2 }) }) end
  end
  if e.subst and inv.get_item_count(T.fuel) >= 1 then -- lot REBUILD-RAPIDE (d) : la foreuse de secours démarre avec son combustible
    local fuel = ent.get_fuel_inventory()
    if fuel then fuel.insert({ name = T.fuel, count = inv.remove({ name = T.fuel, count = math.min(Rr.SUBST_FUEL, inv.get_item_count(T.fuel)) }) }) end
  end
  -- lot CHAMP : un coffre de combustible d'une fonderie de champ est posé garni (la charge portée par le PNJ avec lui) : ses fours
  -- démarrent sans attendre le premier remplissage du quai (mesuré : jusqu'à 32 fours « sans combustible » par équipe à 58 min)
  if e.charge and inv.get_item_count(e.charge.item) >= 1 then
    local n = inv.remove({ name = e.charge.item, count = math.min(e.charge.count, inv.get_item_count(e.charge.item)) })
    if n > 0 then
      local put = ent.insert({ name = e.charge.item, count = n })
      if put < n then inv.insert({ name = e.charge.item, count = n - put }) end
    end
  end
  e.built = true
  st.revived = st.revived + 1
  return true
end

---------------------------------------------------------------------------------------------------
-- Travail d'un PNJ sur place (état « ia1d » de script/team/worker.lua) : "more", "done", "fail", ou "again" (refaire la
-- marche vers le point d'appui depuis la position atteinte)
---------------------------------------------------------------------------------------------------
--- PNJ arrêté en route (forêt dense) : il coupe les arbres et rochers du couloir (demi-largeur Build.CUT_WIDTH) qui
--- mène à son point d'appui, à sa portée. Rend le nombre coupé, ou nil (jetons épuisés ou limite de la pensée : à
--- reprendre). Correction du 27/10, banc ia1-build-foret.
local function cut_toward(f, agent, job, pos, inv, tick, reach2)
  local e = agent.entity
  local surface = e.surface
  local b = f.build
  local dx, dy = job.ax - pos.x, job.ay - pos.y
  local l2 = dx * dx + dy * dy
  local near = surface.find_entities_filtered({ area = { { pos.x - REACH, pos.y - REACH }, { pos.x + REACH, pos.y + REACH } }, type = TREE_TYPES })
  table.sort(near, function(a, c)
    local da, dc = dist2(a.position, pos), dist2(c.position, pos)
    if da ~= dc then return da < dc end
    if a.position.x ~= c.position.x then return a.position.x < c.position.x end
    return a.position.y < c.position.y
  end)
  local cut = 0
  for _, t in ipairs(near) do
    local tx, ty = t.position.x - pos.x, t.position.y - pos.y
    local u = (tx * dx + ty * dy) / l2
    local px, py = tx - u * dx, ty - u * dy
    if u > 0 and u <= 1 and px * px + py * py <= Build.CUT_WIDTH * Build.CUT_WIDTH and dist2(t.position, pos) <= reach2 then
      if cut >= Build.CLEAR_PER_THINK then return nil end
      if not Tokens.take(f, tick, Build.COST_EVAL) then return nil end
      if not t.mine({ inventory = inv, force = e.force, raise_destroyed = true }) and t.valid then t.destroy({ raise_destroy = true }) end
      cut = cut + 1
      job.cut = (job.cut or 0) + 1 -- lot ETAGE4 (relecture) : travail sur place du bâtisseur, lu par le bail (script/team/bail.lua)
      b.stats.cleared = b.stats.cleared + 1
      b.stats.cut = (b.stats.cut or 0) + 1
    end
  end
  return cut
end

--- Point d'appui pas atteint : couper le couloir, puis refaire la marche (Build.CUT_TRIES fois par tâche au plus).
local function not_there(f, agent, job, pos, inv, tick, reach2, give_up)
  local cut = cut_toward(f, agent, job, pos, inv, tick, reach2)
  if cut == nil or cut > 0 then return "more" end
  local t = agent.task
  if t and (t.cut_tries or 0) < Build.CUT_TRIES then
    t.cut_tries = (t.cut_tries or 0) + 1
    return "again"
  end
  -- Lot ELEC2 : point d'appui inaccessible à pied (ni arbre à couper ni chemin : emprise cernée par les foreuses d'un
  -- avant-poste, falaises). Moteur réel, etape1-guide 271828182 : le dernier lot de la fonderie électrique (poteau et 4
  -- foreuses) abandonné 30 fois en 15 min à 28 tuiles de son point d'appui, 182 entités sur 197, 0 foreuse électrique à
  -- 60 min. Le bâtisseur est posé sur la case libre la plus proche du point d'appui (une fois par tâche) ; il rentre
  -- ensuite comme les autres (« home »).
  if t and not t.teleported and job.ax and agent.entity and agent.entity.valid then
    local e = agent.entity
    local spot = e.surface.find_non_colliding_position(e.name, { x = job.ax, y = job.ay }, 8, 0.5)
    if spot then
      t.teleported = true
      e.teleport(spot)
      f.build.stats.build_teleports = (f.build.stats.build_teleports or 0) + 1
      log(string.format("[FO-IA1D] %s : batisseur pose pres du point d'appui (%g, %g), inaccessible a pied", f.key or "player", job.ax, job.ay))
      return "more"
    end
  end
  return give_up
end

function Build.work(agent, f, tick)
  local job = agent.ia1d
  local b = f and f.build
  local p = b and job and b.projects[job.pid]
  if not p and not (b and job and job.seg) then return "fail" end
  local e = agent.entity
  local surface = e.surface
  local inv = e.get_main_inventory()
  local pos = e.position
  -- 16 tuiles du point d'appui ; le PNJ s'arrête à 2 tuiles au plus de ce point (étape goto, rayon 1, but déplacé
  -- s'il est occupé) : 18 tuiles au plus du PNJ, distance la plus grande mesurée et publiée (max_reach).
  local reach2 = (REACH + 2) * (REACH + 2)
  if job.mode == "build" then
    local did, left = 0, 0
    for _, x in ipairs(p.ents) do
      if not x.built and x.anchor == job.anchor then
        if dist2(x, pos) <= reach2 and x.item and inv.get_item_count(x.item) > 0 and (x.fails or 0) < Build.FAIL_LIMIT * 2 then
          if did < Build.REVIVE_PER_THINK then
            -- Debout sur l'emprise : s'écarter AVANT de payer les jetons (step_aside) ; impossible : laissée sans jetons.
            local blocked = stands_on(e, x) and not find_real(surface, x, f.force) and not step_aside(surface, e, x)
            pos = e.position
            local cost = x.name:find("electric%-pole") and Build.COST_REVIVE_POLE or Build.COST_REVIVE
            if blocked then
              left = left + 1
            elseif not Tokens.take_pose(f, tick, cost, Build.REVIVE_PER_THINK * Build.COST_REVIVE) then -- lot JETONS : part de pose propre, par équipe (tokens.lua)
              local g = agent.task and agent.task.gt -- lot CHANTIERS-FANTOMES : pensée arrêtée faute de jetons
              if g then g.tok = (g.tok or 0) + 1; g.built = (g.built or 0) + did end
              return "more"
            elseif revive_one(surface, f, p, x, inv, tick, e) then
              did = did + 1
              local d = math.sqrt(dist2(x, pos))
              if d > (b.stats.max_reach or 0) then b.stats.max_reach = d end
            else
              left = left + 1
            end
          else
            left = left + 1
          end
        end
      end
    end
    job.done = (job.done or 0) + did
    local g = agent.task and agent.task.gt -- lot CHANTIERS-FANTOMES : pièces posées par la tâche
    if g then g.built = (g.built or 0) + did end
    if did > 0 and left > 0 then return "more" end
    if did > 0 then return "done" end -- lot CHANTIERS-FANTOMES : rien de plus à portée avec le sac (left == 0) : fini sans une pensée de plus
    if (job.done or 0) == 0 and job.ax and dist2({ x = job.ax, y = job.ay }, pos) > 16 then
      return not_there(f, agent, job, pos, inv, tick, reach2, "fail")
    end
    return (job.done or 0) > 0 and "done" or "fail"
  elseif job.mode == "clear" then
    local gate = Build.Place.defprev_gate(f, job, tick) -- lot TV-PLACE (G38) : une tâche de défrichage préventif passe sous le jeton des travaux lourds
    if gate then return gate end
    local did = 0
    local rect = job.rect
    local area = rect and { { rect[1], rect[2] }, { rect[3], rect[4] } } or { { pos.x - REACH, pos.y - REACH }, { pos.x + REACH, pos.y + REACH } }
    local list = surface.find_entities_filtered({ area = area, type = TREE_TYPES })
    table.sort(list, function(a, c)
      local da, dc = dist2(a.position, pos), dist2(c.position, pos)
      if da ~= dc then return da < dc end
      if a.position.x ~= c.position.x then return a.position.x < c.position.x end
      return a.position.y < c.position.y
    end)
    local remain = 0
    for _, t in ipairs(list) do
      if dist2(t.position, pos) <= reach2 then
        if did < Build.CLEAR_PER_THINK then
          if not Tokens.take(f, tick, Build.COST_EVAL) then return "more" end
          if t.mine({ inventory = inv, force = e.force, raise_destroyed = true }) then
            did = did + 1
            b.stats.cleared = b.stats.cleared + 1
          else
            if t.valid then t.destroy({ raise_destroy = true }) end
            did = did + 1
            b.stats.cleared = b.stats.cleared + 1
          end
        else
          remain = remain + 1
        end
      end
    end
    -- rien à portée dans la zone (PNJ arrêté en route, forêt dense) : il s'ouvre le couloir vers son point d'appui,
    -- puis refait la marche (correction du 27/10, banc ia1-build-foret)
    if did == 0 and remain == 0 and job.ax and dist2({ x = job.ax, y = job.ay }, pos) > 16 then
      return not_there(f, agent, job, pos, inv, tick, reach2, "done")
    end
    job.done = (job.done or 0) + did
    Build.Place.cut(f, job.seg, did) -- lot TV-PLACE (G38) : obstacles coupés par le défrichage préventif (journal)
    if did > 0 or remain > 0 then return "more" end
    if job.seg then Build.street_cleared(f, job.seg) end
    return "done"
  elseif job.mode == "fill" then
    local q = p.quais[job.idx]
    local chest = q and surface.find_entity(Build.QUAI_CHEST, { q.x, q.y })
    if not chest then return "fail" end
    local n = inv.get_item_count(q.item)
    if n > 0 then
      local put = chest.insert({ name = q.item, count = n })
      if put > 0 then inv.remove({ name = q.item, count = put }) end
      b.stats.filled = b.stats.filled + put
      q.tours, q.filled = (q.tours or 0) + 1, (q.filled or 0) + put -- lot PIQUAGE : tournées « fill » par quai (journal [FO-PIQUAGE] bilan)
      b.stats.trips_fill = (b.stats.trips_fill or 0) + 1 -- lot RAPATRIEMENT : voyages de remplissage terminés (critère C2)
    end
    return "done"
  elseif job.mode == "amorce" then
    return Sante.work(f, p, surface, inv, tick) -- lot ENERGIE (2/11) : charbon porté versé dans les chaudières à sec
  elseif job.mode == "collect" then
    local o = p.outs[job.idx]
    local function out_chest(q) return surface.find_entity(Build.QUAI_CHEST, { q.x, q.y }) end
    local chest = o and out_chest(o)
    if not chest then return "fail" end
    local got = 0
    -- Lot COLLECTE : ce que le stock refuse (Stock.skip_fn, lot STOCKAGE-VITAL, absent avant lui) reste au coffre ; fer et charbon d'abord.
    local skip = Stock.skip_fn and Stock.skip_fn(f) or nil
    local function take(c)
      for _, it in ipairs(Build.Colr.take_list(sorted_keys(c.get_inventory(defines.inventory.chest).get_contents()), skip)) do
        local n = c.get_item_count(it)
        local put = inv.insert({ name = it, count = n })
        if put > 0 then c.remove_item({ name = it, count = put }); got = got + put end
      end
    end
    local before = 0
    for _, it in ipairs(Build.Colr.take_list(sorted_keys(chest.get_inventory(defines.inventory.chest).get_contents()), skip)) do before = before + chest.get_item_count(it) end
    take(chest)
    -- Lot COLLECTE : un voyage qui ne rapporte RIEN d'un coffre qui tient quelque chose (sac plein) n'est pas « done » : il échoue et la
    -- tâche reprend après la pause d'échec (carte de l'IA, boucle B2 : voyages à vide sans pause).
    if Build.Colr.outcome(before, got) == "fail" then
      f.stats.collecte_vide = (f.stats.collecte_vide or 0) + 1
      if f.stats.collecte_vide <= 12 then
        log(string.format("[FO-COLLECTE] %s a %.1f min : voyage a vide, le coffre (%.0f, %.0f) tient %d objet(s) et le sac n'en prend aucun : echec, pause",
          f.key or "player", tick / 3600, o.x, o.y, before))
      end
      return "fail"
    end
    -- Lot PETROLE 2 : les autres sorties du MÊME projet, à portée de la première, se vident dans le même voyage (moteur réel,
    -- etape1-guide 1618033988 : la sortie du soufre, de clé plus petite, était toujours vidée la première, celle du plastique
    -- gardait 732 plaques et le pack chimique ne se fabriquait jamais).
    -- s41 lots-massifs (constat du DC : micro-lots, une sortie par voyage) : la règle des sites vaut pour tout projet SANS borne keep_stock
    -- (champ de fonderie : fer, cuivre) : les sorties voisines du même projet, même sous leur seuil, partent dans le même voyage (le sac
    -- borne : inv.insert). Un bloc de mall (keep_stock : la barre doit arrêter la machine) garde une sortie par voyage. Règle pure C.sweep.
    local site = (p.spec and p.spec.site) and true or false
    local own = got
    for _, i in ipairs(Build.Colr.sweep(p.outs, job.idx, site, p.keep_stock ~= nil)) do
      local o2 = p.outs[i]
      local c2 = out_chest(o2)
      if c2 and c2.force.name == f.force then
        local g0 = got
        take(c2)
        if not site then o2.collected = (o2.collected or 0) + (got - g0) end -- arrivées au tampon (rapatriement) : chaque coffre son compte
      end
    end
    b.stats.collected = b.stats.collected + got
    -- lot RAPATRIEMENT : voyages de collecte terminés (critère C2), par sortie (o.trips) et objets pris à ce coffre (o.collected, arrivées au tampon)
    b.stats.trips_collect = (b.stats.trips_collect or 0) + 1
    o.trips, o.collected = (o.trips or 0) + 1, (o.collected or 0) + (site and got or own)
    return "done"
  end
  return "fail"
end

---------------------------------------------------------------------------------------------------
-- Marche par les rues (étape goto de script/team/worker.lua)
---------------------------------------------------------------------------------------------------
--- Waypoints par les rues de p à q quand les deux sont dans le plan (tronçons OUVERTS seulement), sinon nil.
--- Mémoire des arbres de parcours des rues, par équipe, valable pour une version des tronçons (b.seg_ver) et un rayon.
--- HORS de global : c'est une simple mémoire d'un calcul pur (P.route_tree), vide au chargement et recalculée au
--- besoin, au même résultat (27/10 : 1,7 ms par marche sans elle, hors jeu).
-- Lot IA3-e : le compte des mémoires refaites reste LOCAL (une mesure) : écrit dans global, il différait entre une partie
-- continue et la même partie rechargée (la mémoire, locale, est refaite après le chargement) ; moteur simulé, pvp_test
-- « partie continue = partie rechargée », 2 ECHEC dès que les factions ont un plan directeur.
local ROUTE_RESETS = {}
local route_cache
do
local ROUTES = {} -- mémoire des arbres de parcours (ci-dessus)
function route_cache(f)
  local b = f.build
  local key = f.key or "player"
  local ver = tostring(b.seg_ver or 0) .. ":" .. tostring(b.radius)
  local c = ROUTES[key]
  if not c or c.ver ~= ver then
    c = { ver = ver, trees = {} }
    ROUTES[key] = c
    ROUTE_RESETS[key] = (ROUTE_RESETS[key] or 0) + 1
  end
  return c.trees
end
end -- do

function Build.street_route(f, p, q)
  local b = f.build
  if not b or b.radius == 0 then return nil end
  local lim = (b.radius + 0.5) * P.PITCH
  if math.abs(p.x - b.lat.ox) > lim or math.abs(p.y - b.lat.oy) > lim then return nil end
  if math.abs(q.x - b.lat.ox) > lim or math.abs(q.y - b.lat.oy) > lim then return nil end
  b.stats.route_calls = (b.stats.route_calls or 0) + 1
  local wp = P.street_path(b.lat, p, q, seg_ok(b), b.radius, route_cache(f))
  if not wp then b.stats.route_nil = (b.stats.route_nil or 0) + 1 return nil end
  return wp
end

--- Mesures de la marche par les rues : "start", "ok", "stuck" (repli PathService).
function Build.note_walk(f, what)
  local st = f.build and f.build.stats
  if not st then return end
  if what == "start" then st.street_walks = st.street_walks + 1
  elseif what == "ok" then st.street_ok = st.street_ok + 1
  elseif what == "stuck" then st.street_stuck = st.street_stuck + 1 end
end

---------------------------------------------------------------------------------------------------
-- Tâches au tableau
---------------------------------------------------------------------------------------------------
local function batch_tasks(f, p, out, free_of)
  local b = f.build
  local by = {}
  local order = {}
  local started = {} -- lot FANTOMES : points d'appui entamés (une pièce déjà posée) : servis les premiers (Build.Tournee.allot)
  for _, e in ipairs(p.ents) do
    if e.built then
      if e.anchor ~= nil then started[e.anchor] = true end
    elseif e.item and (e.fails or 0) < Build.FAIL_LIMIT * 2 then
      local k = e.anchor
      if not by[k] then by[k] = { k = k, ax = e.ax, ay = e.ay, pieces = {} }; order[#order + 1] = k end
      local bt = by[k]
      local extra = {} -- objets portés avec la pièce
      if e.name == "burner-inserter" then extra[#extra + 1] = { "coal", 2 } end
      if e.subst then extra[#extra + 1] = { T.fuel, Rr.SUBST_FUEL } end -- lot REBUILD-RAPIDE (d) : combustible porté avec la foreuse de secours
      if e.charge then extra[#extra + 1] = { e.charge.item, e.charge.count } end -- lot CHAMP : charge portée avec le coffre de combustible
      bt.pieces[#bt.pieces + 1] = { item = e.item, extra = extra }
    end
  end
  if #order == 0 then return end
  table.sort(order)
  -- Lot CHANTIERS-FANTOMES : points d'appui déjà servis par une tâche de pose du tableau (libre ou prise) : pas repris dans une autre tournée
  -- (deux PNJ sur la même pièce). Ils reviennent quand la tâche finit ou échoue.
  -- Lot FANTOMES : objets PROMIS à ces tâches tant que leur PNJ n'a pas pris (t.took, script/team/worker.lua take_res) : ils sont encore dans
  -- la réserve du projet mais ne sont plus à donner.
  local held, promised = {}, {}
  for _, t in pairs(Board.get(f).tasks) do -- (ensemble et sommes seulement : l'ordre de pairs n'entre dans aucune décision)
    local j = t.ia1d
    if j and j.mode == "build" and j.pid == p.id then
      if j.tour then for _, a in ipairs(j.tour) do held[a.anchor] = true end
      elseif j.anchor then held[j.anchor] = true end
      if not t.took then
        for _, it in ipairs(t.items or {}) do promised[it[1]] = (promised[it[1]] or 0) + it[2] end
      end
    end
  end
  -- Lot FANTOMES : matière comptée d'un point d'appui au suivant (shared/team/tournee_pose.lua, Tp.allot). Avant, chaque point d'appui voyait
  -- TOUTE la réserve du projet (Rr.batch_ready) et demandait son besoin entier : la même matière promise à toutes les tâches, PNJ au coffre
  -- pour rien (échec « stock », 188 tâches sans pose sur 1 430, [FO-GHOST-BILAN]). Disponible = réserve du projet + stock libre (complément
  -- de Build.take_reserved, lu une fois par pensée et décompté d'un projet au suivant) - objets promis.
  local free = free_of and free_of() or {}
  local function left_of(it) return (p.stock[it] or 0) + (free[it] or 0) - (promised[it] or 0) end
  local list = {}
  for _, k in ipairs(order) do
    if not held[k] then
      local bt = by[k]
      list[#list + 1] = { k = k, started = started[k] or false, pieces = bt.pieces, ax = bt.ax, ay = bt.ay }
    end
  end
  local allot, taken = Build.Tournee.allot(list, left_of)
  for _, it in ipairs(sorted_keys(taken)) do -- part prise au stock libre : plus à donner au projet suivant de cette pensée
    local over = taken[it] - math.max(0, (p.stock[it] or 0) - (promised[it] or 0))
    if over > 0 and free[it] then free[it] = math.max(0, free[it] - over) end
  end
  local cand = {}
  for _, c in ipairs(allot) do
    local a = list[c.i]
    local its = {}
    for _, it in ipairs(c.items) do its[#its + 1] = it[1] end
    cand[#cand + 1] = { k = c.k, x = a.ax, y = a.ay, n = c.n, items = c.items, its = its }
  end
  if #cand == 0 then return end
  -- Lot CHANTIERS-FANTOMES : une tâche = une TOURNÉE de points d'appui voisins (shared/team/tournee_pose.lua) ; avant, un point d'appui par
  -- voyage (1,3 à 7 pièces, 76 % du temps à marcher, journal [FO-GHOST-BILAN]).
  local protos = game and game.item_prototypes
  local function stack(nm)
    local pr = protos and protos[nm]
    return pr and pr.stack_size or 1
  end
  for _, tour in ipairs(Build.Tournee.group(cand, f.hq_pos or { x = b.lat.ox, y = b.lat.oy }, stack)) do
    local first = cand[tour[1]]
    local sum, names, n, list = {}, {}, 0, {}
    for _, i in ipairs(tour) do
      local c = cand[i]
      n = n + c.n
      list[#list + 1] = { anchor = c.k, ax = c.x, ay = c.y, its = c.its }
      for _, it in ipairs(c.items) do
        if not sum[it[1]] then sum[it[1]] = 0; names[#names + 1] = it[1] end
        sum[it[1]] = sum[it[1]] + it[2]
      end
    end
    table.sort(names)
    local items = {}
    for _, nm in ipairs(names) do items[#items + 1] = { nm, sum[nm] } end
    out[#out + 1] = {
      -- lot REBUILD-RAPIDE (b) : un projet ROUVERT passe à son rang (alimentation 88, production principale 87 ; le reste inchangé)
      key = "ia1d:" .. p.id .. ":b:" .. first.k, kind = "ghost", prio = Rr.project_prio(p, finish_prio(p.prio)), domain = p.domain, work = 15 + 2 * n,
      items = items, ia1d = { pid = p.id, mode = "build", anchor = first.k, ax = first.x, ay = first.y, n = n, tour = list },
    }
  end
end

local function clear_tasks(f, p, out)
  local by, order = {}, {}
  for _, o in ipairs(p.obstacles) do
    if not o.done then
      local k = o.anchor or "?"
      if not by[k] then
        by[k] = { ax = o.ax or o.x, ay = o.ay or o.y, x0 = o.x, y0 = o.y, x1 = o.x, y1 = o.y }
        order[#order + 1] = k
      end
      local c = by[k]
      c.x0, c.y0 = math.min(c.x0, o.x), math.min(c.y0, o.y)
      c.x1, c.y1 = math.max(c.x1, o.x), math.max(c.y1, o.y)
    end
  end
  table.sort(order)
  for _, k in ipairs(order) do
    local c = by[k]
    out[#out + 1] = {
      key = "ia1d:" .. p.id .. ":c:" .. k, kind = "clear", prio = finish_prio(p.prio + 1), domain = "logistique", work = 30,
      ia1d = { pid = p.id, mode = "clear", anchor = k, ax = c.ax, ay = c.ay, rect = { c.x0 - 1, c.y0 - 1, c.x1 + 1, c.y1 + 1 } },
    }
  end
end

--- Défrichage des rues (R13) : tronçons encombrés sur les routes du QG vers les chantiers.
local function street_clear_tasks(f, out)
  local b = f.build
  local want = {}
  local passable = seg_passable(b)
  local hi, hj = 0, 0
  -- Lot UPS : UN arbre de parcours depuis le QG pour tous les chantiers de la pensée (P.route_tree : mêmes règles et même ordre que
  -- P.route_nodes, le chemin lu dans l'arbre est celui que rend P.route_nodes ; tests/plan_test.lua). Avant : un parcours en largeur
  -- ENTIER par chantier ouvert (mesuré à 60-90 min, graine 123456789 : 14 ms par pensée d'équipe, pics de 77 ms). L'arbre n'est
  -- calculé qu'au premier chantier ouvert, et jeté à la fin de l'appel (les tronçons ne changent pas pendant l'appel).
  local tree
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and (p.state == "defrichage" or p.state == "fantomes" or p.state == "chantier") and p.parts[1] then
      local pt = p.parts[1]
      local ti, tj = nearest_node(b, pt.ox, pt.oy)
      tree = tree or P.route_tree({ i = hi, j = hj }, passable, b.radius)
      local nodes = P.tree_path(tree, { i = ti, j = tj })
      for k = 2, #(nodes or {}) do
        local a, c = nodes[k - 1], nodes[k]
        local key = a.i ~= c.i and P.seg_key("h", math.min(a.i, c.i), a.j) or P.seg_key("v", a.i, math.min(a.j, c.j))
        if b.segs[key] and b.segs[key].state == "encombre" then want[key] = true end
      end
    end
  end
  for _, key in ipairs(sorted_keys(want)) do
    local x0, y0, x1, y1 = P.seg_rect(b.lat, key)
    -- deux moitiés de 16 tuiles : tout arbre du tronçon est à portée d'un point d'appui
    local halves
    if key:sub(1, 1) == "h" then
      local mx = (x0 + x1) / 2
      halves = { { x0, y0, mx, y1 }, { mx, y0, x1, y1 } }
    else
      local my = (y0 + y1) / 2
      halves = { { x0, y0, x1, my }, { x0, my, x1, y1 } }
    end
    for h, r in ipairs(halves) do
      out[#out + 1] = {
        key = "ia1d:rue:" .. key .. ":" .. h, kind = "clear", prio = Build.PRIO + 2, domain = "logistique", work = 40,
        ia1d = { pid = 0, mode = "clear", seg = key, ax = (r[1] + r[3]) / 2, ay = (r[2] + r[4]) / 2, rect = r },
      }
    end
  end
end

--- Lot CHARBON-CENTRALE : journal du coffre de la centrale, une ligne par épisode (passage sous le seuil, coffre du QG vide), au plus
--- Cc.LOGS par équipe. Mémoire : b.charbon[pid].said (chaîne), effacée quand le coffre repasse au-dessus du seuil.
local function cc_say(f, p, i, n, have, rate, r)
  local b = f.build
  b.charbon = b.charbon or {}
  local st = b.charbon[p.id] or {}
  b.charbon[p.id] = st
  local cause = r.due and (r.steam and "vapeur" or "urgence") or (r.short and "sans charbon" or nil)
  if not cause then st.said = nil return end
  if st.said == cause then return end
  st.said = cause
  b.charbon_logs = (b.charbon_logs or 0) + 1
  if b.charbon_logs > Cc.LOGS then return end
  if r.due and r.steam then
    log(string.format("[FO-CHARBON-CENTRALE] %s : centrale %d, coffre %d a %d charbon(s), AU-DESSUS du seuil %d mais tampon de vapeur BAS a %.1f min : tache URGENTE (prio %d), %d a porter (cible %d), coffre du QG %d",
      f.key or "player", p.id, i, n, r.low, game.tick / 3600, r.prio, r.count, r.target, have))
  elseif r.due then
    log(string.format("[FO-CHARBON-CENTRALE] %s : centrale %d, coffre %d a %d charbon(s), sous le seuil %d (%.2f/s x %d s) a %.1f min : tache URGENTE (prio %d), %d a porter (cible %d), coffre du QG %d",
      f.key or "player", p.id, i, n, r.low, rate, Cc.LEAD_S, game.tick / 3600, r.prio, r.count, r.target, have))
  else
    log(string.format("[FO-CHARBON-CENTRALE] %s : centrale %d, coffre %d a %d charbon(s), sous le seuil %d a %.1f min : coffre du QG SANS charbon libre (hors la reserve des bruleurs), aucune tache possible (le bilan du charbon compte les chaudieres nourries a la main)",
      f.key or "player", p.id, i, n, r.low, game.tick / 3600))
  end
end

--- Lot INDUSTRIE I6 (relecture 0.6.31) : la sortie d'un bloc de mall se vide-t-elle vers le QG ? p.keep_stock = { [objet] = stock du QG visé } : au-delà,
--- le PNJ la laisse, le coffre monte à sa barre et la machine s'arrête seule. Sans cette borne, la collecte (seuil 5) vidait le coffre à chaque
--- voyage : la barre n'était jamais atteinte et le mall changeait tout le stock en pièces, en occupant les PNJ. Un objet hors de la table : collecté.
local function out_wanted(f, p, chest)
  -- Lot COLLECTE : un coffre dont tout est écarté par le stock (Stock.skip_fn) n'envoie personne (voyage à vide)
  local skip = Stock.skip_fn and Stock.skip_fn(f) or nil
  if skip and #Build.Colr.take_list(sorted_keys(chest.get_inventory(defines.inventory.chest).get_contents()), skip) == 0 then return false end
  local keep = p.keep_stock
  if not keep then return true end
  for _, it in ipairs(sorted_keys(chest.get_inventory(defines.inventory.chest).get_contents())) do
    if keep[it] == nil or Stock.count(f, it) < keep[it] then return true end
  end
  return false
end

--- Lot LOGISTIQUE : point d'appui d'une tâche de PORTAGE (collecte d'une sortie, remplissage d'un quai, amorce) : le point de la rue passé par
--- free_spot, comme les points d'appui de chantier (plan_project). Avant le lot le point de la rue était pris tel quel : une rue du treillis sous
--- le quai d'une colonne du champ donnait un but ENTRE deux bras du quai, que le moteur refuse (« no_path ») : banc partie-reelle-120, graine
--- 123456789, emerald, les 11 coffres du projet 4 visaient (-282, 521), 110 refus de chemin, 18 900 plaques au quai et QG à sec à 120 min.
function Build.carry_anchor(b, x, y)
  local a = P.anchor_for(b.lat, x, y, seg_passable(b))
  local fx, fy
  if a then fx, fy = free_spot(b, nil, a.x, a.y) else fx, fy = free_spot(b, nil, x, y) end
  return { x = fx, y = fy }
end

--- Tâches de COLLECTE des coffres de sortie d'un projet (une par coffre au seuil). Lot COLLECTE : appelée aussi pour un projet qui n'est ni
--- « fini » ni « chantier » (bande du champ « reserve:pile », « refuse:migration »... dont les coffres posés se remplissent encore : journal du
--- DC du 7/11, 8 coffres au seuil de 159 à 174 min) ; un coffre absent (rien de bâti) est ignoré.
--- Lot VIDEO L4 : relève d'abord les coffres de sortie (quota du projet, Build.Quotas.of ; compte de chaque coffre), puis émet la collecte
--- au seuil borné par le quota (jamais retenue : une sortie arrêtée par le quota reste vidée). Rend (quota ou nil, comptes par coffre).
local function out_tasks(f, p, surface, out)
  local chests, counts, slots, in_slots = {}, {}, nil, nil
  for i, o in ipairs(p.outs) do
    local chest = surface.find_entity(Build.QUAI_CHEST, { o.x, o.y })
    if chest and chest.force.name == f.force then
      local inv = chest.get_inventory(defines.inventory.chest)
      chests[i], counts[i] = chest, inv.get_item_count()
      if not slots then in_slots = #inv; slots = math.min(in_slots, inv.get_bar() - 1) end -- F95 : sans barre, get_bar() = cases + 1
    end
  end
  Build.Quotas.measure(f, p, surface) -- lot TV-QUOTAS (C11) : modules réellement posés (ou retirés) -> rapports p.qm_out, p.qm_in, lus par Quotas.of
  local q = Build.Quotas.of(p, slots, in_slots, Build.COLLECT_AT)
  for i, o in ipairs(p.outs) do
    local chest = chests[i]
    -- lot PETROLE : seuil propre d'une sortie de site (o.at) ; lot VIDEO L4 : borné par le quota
    if chest and counts[i] >= Build.Quotas.collect_at(q, i, o.at or Build.COLLECT_AT) and out_wanted(f, p, chest) then
      local a = Build.carry_anchor(f.build, o.x, o.y)
      out[#out + 1] = {
        key = "ia1d:" .. p.id .. ":o:" .. i, kind = "carry", prio = p.prio, domain = "logistique", work = 40,
        ia1d = { pid = p.id, mode = "collect", idx = i, ax = a.x, ay = a.y },
      }
    end
  end
  return q, counts
end

local function quai_tasks(f, p, surface, out)
  --- Lot BRULEURS-A-SEC (B4, banc V0676-D graine 123456789) : combustible du coffre du QG RÉSERVÉ aux tournées des brûleurs : la grandeur
  --- que shared/team/planner.lua retire du stock virtuel (« le charbon nécessaire aux tournées est réservé avant toute fabrication ») :
  --- fours de l'équipe, puis brûleurs des avant-postes dont le produit n'est pas le combustible (un avant-poste de combustible se sert sur
  --- ses sorties, Sm.carry_fuel). Avant le lot, quai_tasks lisait le stock BRUT : à 36,3 min, 400 charbons au coffre et 46 brûleurs de fer
  --- à sec sur 60 (besoin 588), la centrale (prio 91, cible 1080) prenait les 400 ; les brûleurs sont restés à sec 45 min.
  --- (somme d'entiers : l'ordre de `pairs` n'y change rien ; locale de quai_tasks : le bloc principal de build.lua est à sa limite de locales)
  --- Lot CHAUDIERES : seulement les tournées DUES (un brûleur du groupe sous T.fuel_low), Cc.tour_reserve ; le complément des brûleurs qui
  --- n'attendent aucune tournée n'est plus retenu à la centrale (banc CHAUDIERES : libre 0 avec 23 à 70 charbons au coffre, 11 min).
  local function burner_fuel_reserve()
    local fill = f.team and f.team.flux_fill or T.fuel_refill_to
    local groups = { { fill = T.fuel_refill_to, levels = Outposts.fuel_levels(Outposts.smelters(f)) } }
    for _, o in pairs(f.outposts) do
      local spec = T.outposts[o.kind]
      if not (spec and spec.product == T.fuel) then groups[#groups + 1] = { fill = fill, levels = Outposts.fuel_levels(Outposts.burners(o)) } end
    end
    return Cc.tour_reserve(groups, T.fuel_low)
  end
  -- lot CHARBON-CENTRALE : le coffre d'une centrale se remplit en URGENCE dès qu'il passe sous un seuil d'avance (consommation à pleine
  -- charge des chaudières × Cc.LEAD_S), jamais seulement au-dessous de Build.QUAI_LOW à la priorité du projet (63 : coffre oublié, centrale
  -- de scarlet à sec 8 fois dans la partie du DC en 0.6.18)
  local rate
  if is_plant_project(p) then
    local _, kw = plant_burn_kw(p)
    rate = Cc.chest_rate(Cc.rate(kw, M.COAL_J), #p.quais) -- (lot s42 charbon-centrale : deux coffres se partagent la consommation)
    -- lot ENERGIE (2/11) : chaudières à sec = amorce à la main (charbon du stock versé dans la chaudière), en tête de pile
    Sante.tasks(f, p, out, function(x, y)
      local a = Build.carry_anchor(f.build, x, y)
      return a
    end)
  end
  -- lot VIDEO L4 : sorties relevées AVANT les entrées (verdict « sortie pleine ») ; la collecte, jamais retenue, garde sa place en fin de liste
  local collect = {}
  local qta, counts = out_tasks(f, p, surface, collect)
  local feed = Build.Quotas.feed_ok(qta, counts)
  for i, q in ipairs(p.quais) do
    local chest = surface.find_entity(Build.QUAI_CHEST, { q.x, q.y })
    if chest and chest.force.name == f.force then
      local n = chest.get_item_count(q.item)
      local have = Stock.count(f, q.item)
      -- lot BRULEURS-A-SEC (B4) : le combustible des tournées des brûleurs n'est pas à la centrale ni au quai de combustible d'un champ
      if q.item == T.fuel then have = Cc.free_fuel(have, burner_fuel_reserve()) end
      if rate then
        local inv = chest.get_inventory(defines.inventory.chest)
        -- lot TV-VAPEUR (V36) : le tampon de vapeur bas déclenche aussi le remplissage (Build.Vg nul dans les doublures des bancs hors jeu)
        local steam_low = Build.Vg and Build.Vg.low(f, p, surface) or false
        local r = Cc.refill(n, rate, have, inv and (n + inv.get_insertable_count(q.item)) or nil, steam_low, #p.quais) -- (s43 cc-garde : planchers par centrale)
        -- lot COMBUSTIBLE-CENTRALE (levier a) : coffre du QG sans charbon -> le tampon d'un avant-poste de charbon porte le complément
        local relay
        if r.short and Build.Ct then
          local a = Build.carry_anchor(f.build, q.x, q.y)
          relay = Build.Ct.relay(f, p, surface, i, q, n, r, a.x, a.y, Build.Quartiers.DEPOT, game.tick)
          if relay then r.short = nil end
        end
        cc_say(f, p, i, n, have, rate, r)
        if relay then out[#out + 1] = relay end
        if r.due then
          local a = Build.carry_anchor(f.build, q.x, q.y)
          out[#out + 1] = {
            key = "ia1d:" .. p.id .. ":q:" .. i, kind = "carry", prio = r.prio, no_rush = true, domain = "logistique", work = 40,
            items = { { q.item, r.count } },
            ia1d = { pid = p.id, mode = "fill", idx = i, ax = a.x, ay = a.y },
          }
        end
      elseif (q.flow or 0) > 0 then -- lot COMBUSTIBLE-MIGRATION : quai de COMBUSTIBLE d'une colonne de champ (q.flow = objets/s brûlés par ses fours) : seuil et cible à la consommation
        -- (Cc.refill : 4 min d'avance, 20 min de cible), tâche URGENTE comme le coffre d'une centrale ; coffre du QG sans combustible : le tampon d'un avant-poste (Build.Ct)
        local inv = chest.get_inventory(defines.inventory.chest)
        local r = Cc.refill(n, q.flow, have, inv and (n + inv.get_insertable_count(q.item)) or nil, false)
        local a = Build.carry_anchor(f.build, q.x, q.y)
        local relay
        if r.short and Build.Ct then
          relay = Build.Ct.relay(f, p, surface, i, q, n, r, a.x, a.y, Build.Quartiers.DEPOT, game.tick)
          if relay then r.short = nil end
        end
        if relay then out[#out + 1] = relay end
        if r.due then
          out[#out + 1] = {
            key = "ia1d:" .. p.id .. ":q:" .. i, kind = "carry", prio = r.prio, no_rush = true, domain = "logistique", work = 40,
            items = { { q.item, r.count } },
            ia1d = { pid = p.id, mode = "fill", idx = i, ax = a.x, ay = a.y },
          }
        end
      elseif feed then -- lot VIDEO L4 : module à sortie pleine, plus d'alimentation (V27) ; une minute d'ingrédients (V25), sinon l'ancienne règle
        local r = Build.Quotas.refill(qta, i, n, have, Build.QUAI_LOW, Build.QUAI_FILL)
        r = Build.Rempl.adjust(f, p, i, q, chest, n, have, qta, r, Build.QUAI_LOW, Build.QUAI_FILL) -- lot REMPLISSAGE : stock abondant, coffre plein
        if r.due then
          local a = Build.carry_anchor(f.build, q.x, q.y)
          out[#out + 1] = {
            key = "ia1d:" .. p.id .. ":q:" .. i, kind = "carry", prio = p.prio + 3, domain = "logistique", work = 40,
            items = { { q.item, r.count } },
            ia1d = { pid = p.id, mode = "fill", idx = i, ax = a.x, ay = a.y },
          }
        end
      end
    end
  end
  for _, t in ipairs(collect) do out[#out + 1] = t end
end

---------------------------------------------------------------------------------------------------
-- Raccordement : fils (arbre couvrant au plus court), recettes
---------------------------------------------------------------------------------------------------
--- Lot UPS : même calcul qu'avant, ligne pour ligne (mêmes poteaux, même tri, mêmes candidats dans le même ordre, mêmes unions, mêmes
--- fils posés dans le même ordre), mais chaque poteau n'est LU au moteur qu'une fois (position, portée de fil du prototype, numéro) au
--- lieu de l'être à chaque comparaison du tri et à chaque paire, et le voisin déjà relié est retrouvé par son numéro au lieu d'une
--- comparaison d'entités avec TOUS les poteaux. Mesuré (graine 123456789, 72,3 min, centrale de 149 entités) : 959 ms dans un seul tick.
--- La règle est Build.wire_poles (champ de Build : essayée hors jeu par tests/registre_types_test.lua contre l'ancienne).
--- poles : liste d'entités (poteaux) ; rend le nombre de fils posés, le nombre de liaisons de cuivre entre ces poteaux.
function Build.wire_poles(poles)
  local recs = {}
  for i, ent in ipairs(poles) do
    local pos = ent.position
    recs[i] = { ent = ent, x = pos.x, y = pos.y, reach = ent.prototype.max_wire_distance, u = ent.unit_number }
  end
  table.sort(recs, function(a, c) if a.y ~= c.y then return a.y < c.y end return a.x < c.x end)
  local cand = {}
  for a = 1, #recs do
    for c = a + 1, #recs do
      local pa, pc = recs[a], recs[c]
      local reach = math.min(pa.reach, pc.reach)
      local d2 = dist2(pa, pc)
      if d2 <= reach * reach + 1e-6 then cand[#cand + 1] = { d2, a, c } end
    end
  end
  table.sort(cand, function(u, v) if u[1] ~= v[1] then return u[1] < v[1] end if u[2] ~= v[2] then return u[2] < v[2] end return u[3] < v[3] end)
  local parent, idx = {}, {}
  for i = 1, #recs do
    parent[i] = i
    idx[recs[i].u] = i
  end
  local function find(x) while parent[x] ~= x do x = parent[x] end return x end
  -- poteaux déjà reliés entre eux : même composante
  for a = 1, #recs do
    for _, nb in ipairs((recs[a].ent.neighbours or {}).copper or {}) do
      local c = nb.valid and idx[nb.unit_number] or nil
      if c then local ra, rc = find(a), find(c); if ra ~= rc then parent[rc] = ra end end
    end
  end
  local n = 0
  for _, c in ipairs(cand) do
    local ra, rc = find(c[2]), find(c[3])
    if ra ~= rc then
      -- lot CHAMP : la liaison n'unit les deux réseaux que si le fil est POSÉ ; un poteau qui a déjà ses 5 fils (reliés par le moteur au
      -- ravivage) refuse, et l'arête suivante doit être essayée. Avant, le refus comptait comme une liaison : des fonderies de champ restaient
      -- sur un réseau sans centrale (mesuré : 12 à 26 bras « sans courant » par bande, graine 271828182, [FO-CHAMP-ETAT])
      if recs[c[2]].ent.connect_neighbour(recs[c[3]].ent) then
        n = n + 1
        parent[rc] = ra
      end
    end
  end
  -- liaisons de cuivre des poteaux du projet (le moteur relie lui-même un poteau ravivé à ses voisins : les fils
  -- AJOUTÉS ci-dessus ne comptent que les trous)
  local links = 0
  for a = 1, #recs do
    for _, nb in ipairs((recs[a].ent.neighbours or {}).copper or {}) do
      if nb.valid and idx[nb.unit_number] and idx[nb.unit_number] > a then links = links + 1 end
    end
  end
  return n, links
end

local function wire_project(f, surface, p)
  local poles = {}
  local seen = {}
  local function add(ent) if ent and ent.valid and not seen[ent.unit_number] then seen[ent.unit_number] = true; poles[#poles + 1] = ent end end
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, e in ipairs(p.ents) do
    if e.name:find("electric%-pole") then
      add(find_real(surface, e, f.force))
      x0, y0, x1, y1 = math.min(x0, e.x), math.min(y0, e.y), math.max(x1, e.x), math.max(y1, e.y)
    end
  end
  if #poles == 0 then return 0 end
  -- poteaux du réseau voisins
  for _, ent in ipairs(surface.find_entities_filtered({ area = { { x0 - 30, y0 - 30 }, { x1 + 30, y1 + 30 } }, type = "electric-pole", force = f.force })) do add(ent) end
  local n, links = Build.wire_poles(poles)
  p.links = links
  return n
end

local function all_built(p)
  for _, e in ipairs(p.ents) do if not e.built then return false end end
  return true
end

local function count_built(p)
  local n = 0
  for _, e in ipairs(p.ents) do if e.built then n = n + 1 end end
  return n
end

--- Fin d'un projet : fils, objets restants rendus, modules comptés.
local function finish_project(f, surface, p, tick)
  local b = f.build
  p.wired = wire_project(f, surface, p)
  release(f, p)
  p.missing = {} -- lot INTEG-RECONSTRUCTION (D6) : plus rien à réunir (refresh_missing ne tourne plus)
  p.state = "fini"
  p.finished = tick
  if not p.counted then -- lot CORR-RESEAU : un projet rouvert puis refini ne compte qu'une fois
    p.counted = true
    for _, pt in pairs(p.parts) do
      if pt then b.stats.modules_done = b.stats.modules_done + 1 end
    end
    b.stats.projects_done = b.stats.projects_done + 1
  end
  if p.spec.ilot then -- lot ILOTS-MURS
    log(string.format("[FO-ILOT] %s : segment de l'ilot %s fini (projet %d) a %.1f min : %d murs, %d abandonne(s) (tuile refusee 3 fois)", f.key or "player",
      tostring(p.spec.ilot), p.id, tick / 3600, #p.ents - (p.dropped or 0), p.dropped or 0))
  elseif p.spec.enceinte then
    log(string.format("[FO-ESPACE] %s : segment d'enceinte fini a %.1f min : %d murs, %d abandonne(s) (tuile refusee 3 fois)", f.key or "player",
      tick / 3600, #p.ents - (p.dropped or 0), p.dropped or 0))
  end
  for _, n in ipairs(sorted_keys(b.net)) do if b.net[n].pid == p.id then b.net[n].built = true end end
  -- lot POTEAUX-MASQUES : le terrain a changé là où ce projet a bâti : les relevés de chunk de cette zone tombent
  if #p.ents > 0 and surface and MASQ[surface.index] then
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for _, e in ipairs(p.ents) do
      x0, y0, x1, y1 = math.min(x0, e.x), math.min(y0, e.y), math.max(x1, e.x), math.max(y1, e.y)
    end
    Mq.invalidate(MASQ[surface.index], math.floor(x0) - 4, math.floor(y0) - 4, math.ceil(x1) + 4, math.ceil(y1) + 4)
  end
  log(string.format("[FO-IA1D] %s : projet %d fini (%s, %d entites, %d fils) a %.1f min", f.key or "player", p.id,
    p.parts[1] and p.parts[1].key or "?", #p.ents, p.wired or 0, tick / 3600))
end

---------------------------------------------------------------------------------------------------
-- Avancement : passe de travail (toutes les Build.PULSE ticks) et pensée d'équipe
---------------------------------------------------------------------------------------------------
local function advance(f, surface, p, tick)
  local b = f.build
  if p.state == "attente" then
    if b.qhead > #b.queue and tick >= (p.plan_after or 0) then
      -- lot ENERGIE (2/11) : un module électrique ne s'ouvre pas au-delà de ce que la centrale produit (Sante.gate : 12 min d'attente au plus)
      local ok = Sante.gate(f, p, tick, function(spec) local g = template_of(spec); return g and g.power_kw or 0 end)
      if ok then p.state = "plan" end
    end
    return
  end
  if p.state == "plan" then
    if not Tokens.take(f, tick, Build.COST_PLAN) then return end
    -- un projet ne se planifie qu'après la centrale (qui amorce le réseau)
    if b.plant and b.plant ~= p.id then
      local pl = b.projects[b.plant]
      if pl and (pl.state == "attente" or pl.state == "plan") then return end
    end
    Profiler.start("build:plan")
    -- lot MIGRATION-CHAMP : les tuiles de la partie de champ à remplacer comptent comme libres pour CE plan seulement (relevés de
    -- tuiles du tick jetés avant et après : un autre plan du même tick ne les verrait pas libres)
    THAW = p.spec.degel and p.spec.degel.tiles or nil
    if THAW then SCAN.tick = nil end
    local ok, why, wait = plan_project(f, surface, p)
    if wait ~= "foreuses" then Build.TrancheForeuses.clear(p) end -- lot TRANCHES-FOREUSES : fin du plan (accepté, refusé ou autre attente)
    if THAW then THAW = nil; SCAN.tick = nil end
    Profiler.stop("build:plan")
    -- lot IA3-e : minuteurs des parties arrêtés aussi après un retour anticipé du plan (refus, attente)
    Profiler.stop("build:plan:place"); Profiler.stop("build:plan:feed"); Profiler.stop("build:plan:power"); Profiler.stop("build:plan:anchors")
    if ok then
      p.sites_v = 1 -- lot MESURE-MODULE : coffres planifiés une seule fois (Build.dedupe_sites n'a rien à relire)
      p.masq_n = nil -- lot POTEAUX-MASQUES : l'accord de chunks repart de zéro au prochain plan de ce projet
      p.state = "reserve"
      p.started = tick
      -- lot COURANT2 : un site (bande de champ…) n'a pas de gabarit, donc pas de puissance à la porte : la noter ici (Sante.committed)
      if (p.power_kw or 0) <= 0 and p.spec.site then p.power_kw = Sante.site_kw(p) end
      log(string.format("[FO-IA1D] %s : projet %d plan (%s, lot %s, %d entites, %d obstacles) a %.1f min", f.key or "player", p.id,
        p.parts[1].key, p.parts[1].lot, #p.ents, #p.obstacles, tick / 3600))
    elseif wait == "masques" then
      -- lot POTEAUX-MASQUES : le couloir des poteaux n'est pas encore relevé en entier (budget de chunks par essai) ; tout ce qui a
      -- été réservé est rendu, nouvel essai sous peu avec Mq.BUDGET chunks accordés de plus (p.masq_n, lu par masques_view)
      for k, v in pairs(b.occ) do if v == p.id then b.occ[k] = nil end end
      for _, l in pairs(b.lots) do if l.used == p.id then l.used = nil end end
      for _, n in ipairs(sorted_keys(b.net)) do if b.net[n].pid == p.id then b.net[n] = nil end end
      p.ents, p.parts = {}, {}
      p.quais, p.outs = {}, {} -- lot MESURE-MODULE : plan_feed les AJOUTE à chaque plan (un module à 3 attentes avait 4 copies de sa sortie)
      p.masq_n = (p.masq_n or 0) + 1
      p.plan_after = tick + Mq.WAIT_TICKS
      p.state, p.reason = "attente", why
    elseif wait == "net" and (p.wait_net or 0) < Build.NET_WAIT_MAX then
      -- lot PLANDIR : le réseau d'un autre projet n'est pas bâti ; tout ce qui a été réservé est rendu, nouvel essai plus tard
      for k, v in pairs(b.occ) do if v == p.id then b.occ[k] = nil end end
      for _, l in pairs(b.lots) do if l.used == p.id then l.used = nil end end
      for _, n in ipairs(sorted_keys(b.net)) do if b.net[n].pid == p.id then b.net[n] = nil end end
      p.ents, p.parts = {}, {}
      p.quais, p.outs = {}, {} -- lot MESURE-MODULE (voir plus haut)
      p.wait_net = (p.wait_net or 0) + 1
      -- lot POTEAUX-MASQUES (relecture) : après 30 s le cache (Mq.TTL) est tombé ; garder l'ancien accord ferait relire jusqu'à 20
      -- chunks en une seule passe (pic) : l'accord repart de zéro, comme pour tout nouveau plan
      p.masq_n = nil
      p.plan_after = tick + Build.NET_WAIT_TICKS
      p.state, p.reason = "attente", why
    elseif wait == "tranche" then
      -- lot RAPATRIEMENT : la recherche du tracé continue à la pensée suivante (Rap.plan la garde en mémoire locale) ; rien n'est réservé avant la fin
      p.plan_after = tick + Build.Rapatriement.SLICE_WAIT
      p.state, p.reason = "attente", why
      -- lot CC-PLEIN (F503) : une tranche n'est pas un plan fini : le projet CÈDE SON RANG (fin de b.order) aux projets demandés après lui.
      -- Il gardait sa place : la tranche prend le plan de la passe (« un plan au plus par passe ») et le jeton du tick, la recherche dure des
      -- milliers d'appels, et aucun projet derrière lui n'atteignait plus son plan (partie 0.6.89 du DC : 7 lignes en recherche dès 17 min,
      -- 19 projets en « plan » sans un seul essai jusqu'à 82 min, dont la bande 51 de la migration du fer : avant-poste « plein par
      -- migration », 243 PNJ sans tâche). Rien n'est réservé pendant la recherche : son rang ne sert qu'à l'ordre des essais de plan.
      local order = {}
      for _, x in ipairs(b.order) do if x ~= p.id then order[#order + 1] = x end end
      order[#order + 1] = p.id
      b.order = order
    elseif wait == "loin" then
      -- lot PD-CENTRALE : centrale lointaine, recherche de l'eau en cours (budget de la passe épuisé), rive écartée (ligne
      -- impossible) ou terrain de la ligne en génération : tout ce qui a été réservé est rendu, nouvel essai plus tard
      for k, v in pairs(b.occ) do if v == p.id then b.occ[k] = nil end end
      for _, l in pairs(b.lots) do if l.used == p.id then l.used = nil end end
      for _, n in ipairs(sorted_keys(b.net)) do if b.net[n].pid == p.id then b.net[n] = nil end end
      p.ents, p.parts, p.far = {}, {}, nil
      p.quais, p.outs = {}, {} -- lot MESURE-MODULE (voir plus haut)
      p.masq_n = nil
      p.plan_after = tick + (p.far_poll or Cl.RETRY)
      p.far_poll = nil
      p.state, p.reason = "attente", why
    elseif wait == "foreuses" then
      -- lot TRANCHES-FOREUSES : le tracé pondéré du tapis des foreuses se calcule par tranches (p.rs_drills) ; tout ce qui a été réservé est rendu,
      -- le projet reste en « plan » et le replan, à la pensée suivante, reprend la recherche là où elle s'était arrêtée
      for k, v in pairs(b.occ) do if v == p.id then b.occ[k] = nil end end
      for _, l in pairs(b.lots) do if l.used == p.id then l.used = nil end end
      for _, n in ipairs(sorted_keys(b.net)) do if b.net[n].pid == p.id then b.net[n] = nil end end
      p.ents, p.parts = {}, {}
      p.quais, p.outs = {}, {}
      p.reason = why
    elseif wait == "calcul" then
      -- lot PETROLE 2 : le plan d'un site se calcule par tranches (Fl.layout_step) ; le projet reste en « plan » et reprend à la
      -- prochaine passe (rien n'a été réservé)
      p.reason = why
    elseif wait == true then
      p.state = "attente"
      p.reason = why
    else
      -- tout ce qui a été réservé est rendu
      for k, v in pairs(b.occ) do if v == p.id then b.occ[k] = nil end end
      for _, l in pairs(b.lots) do if l.used == p.id then l.used = nil end end
      for _, n in ipairs(sorted_keys(b.net)) do if b.net[n].pid == p.id then b.net[n] = nil end end
      p.ents, p.parts = {}, {}
      p.quais, p.outs = {}, {} -- lot MESURE-MODULE (voir plus haut)
      p.state, p.reason = "refuse", why
      b.stats.projects_refused = b.stats.projects_refused + 1
      if b.plant == p.id then b.plant = nil end
      log(string.format("[FO-IA1D] %s : projet %d refuse (%s)", f.key or "player", p.id, tostring(why)))
    end
    return
  end
  if p.state == "reserve" then
    -- lot IA3-e : une réserve incomplète n'est relue qu'une fois par seconde (elle relisait le coffre et le registre
    -- toutes les 5 ticks : chantiers des factions en attente de matériaux pendant des dizaines de minutes, K10)
    if p.reserve_next and tick < p.reserve_next then return end
    -- Lot FUITES-PILE (fuite b) : un module NEUF est une amélioration (R3) ; pendant qu'un cadre réparer, protéger ou survivre retient,
    -- il ne prend rien au coffre (et rend ce qu'il avait déjà pris), sauf s'il produit une matière d'un cadre ouvert ou qui manque
    -- (PileRt.porte). Avant, il réservait le fer des tourelles comme un module rouvert pour reconstruction.
    Profiler.fstart("rs:pile") -- lot UPS : portées fines de la réserve (mesure seulement)
    local susp = Build.reserve_suspended(f, p, tick)
    Profiler.fstop("rs:pile")
    if susp then return end
    if p.spec.enceinte then craft_walls(f, p) end
    -- lot IA3-e : la raison « materiaux » est effacée quand la réserve est complète (elle restait affichée au chantier)
    Profiler.fstart("rs:reserve")
    local full, need = reserve(f, p)
    Profiler.fstop("rs:reserve")
    -- Lot EXPANSION-LOINTAINE : une bande de champ NEUVE n'attend plus TOUTE sa matière (azure, bande 393 : 40 min en « reserve:materiaux »
    -- avec 283 pièces sur 311 au coffre) : elle part dès que chaque objet est réservé au plancher de Build.Cp (règle pure) ; le reste est pris
    -- au coffre à la prise du PNJ (Build.take_reserved), suivi par refresh_missing (p.progressif), fabriqué par le cerveau comme en réserve.
    local prog, pd = false, nil
    if not full then
      prog, pd = Build.Cp.go({ state = p.state, reopened = p.reopened, degele = p.degele, spec = p.spec, need = need, stock = p.stock, lead = lead_items(p) })
    end
    if full or prog then
      -- lot MIGRATION-CHAMP : matières réunies, la partie de champ à remplacer est retirée par script/team/migration_champ.lua (qui pose
      -- p.degele) : le chantier ne commence qu'ensuite, et le champ produit jusque-là
      if p.spec.degel and not p.degele then
        p.reason, p.reserve_next = "degel", tick + 60
        return
      end
      if prog and not p.progressif then
        p.progressif = true
        log(string.format("[FO-CHANTIER-PROGRESSIF] %s : projet %d (%s) part en chantier sans toute sa matiere a %.1f min : %s", f.key or "player",
          p.id, p.spec.ext and "extension de champ de puits" or ("bande " .. tostring(p.spec.champ and p.spec.champ.pr)), tick / 3600,
          Build.Cp.describe(pd))) -- (lot CC-PETROLE : une extension de champ de puits part aussi ainsi)
      end
      -- lot PETROLE : un site étendu (spec.lazy_clear) ne défriche pas tout d'abord : ses fantômes se posent, et les
      -- arbres sont coupés pendant le chantier, entité par entité (moteur réel, petrole-site : 58 arbres sur un site
      -- de 92 entités, chantier jamais commencé en 8 min)
      p.state, p.reason, p.reserve_next = (#p.obstacles > 0 and not p.spec.lazy_clear) and "defrichage" or "fantomes", nil, nil
    elseif Rr.partial_go(p) and not (p.spec.degel and not p.degele) then
      -- lot REBUILD-RAPIDE (a) : un projet ROUVERT reprend son chantier avec ce qui est au coffre (réservé par `reserve` ci-dessus) au lieu
      -- d'attendre toute sa matière (Scarlet, partie du DC du 29/10 : fonderie 7 en « reserve[materiaux] » 40 min pour 2 bras sans cuivre,
      -- 27 tapis à refaire) ; le reste est pris au coffre par le PNJ à sa prise (Build.take_reserved) et suivi par refresh_missing.
      p.state, p.reason, p.reserve_next = (#p.obstacles > 0 and not p.spec.lazy_clear) and "defrichage" or "fantomes", nil, nil
    else
      -- lot CENTRALE-PRES : une réserve de centrale qu'aucun coffre ni aucune fabrication ne peut couvrir (recette fermée, rien au
      -- coffre) ne se lèvera jamais : refus tout de suite avec sa cause, la pause de la croissance prend le relais (plant_arms), au
      -- lieu des 30 min de C.STALE pendant lesquelles aucune autre centrale n'est demandée
      local dead = (p.spec.plant and f.build.plant ~= p.id and not p.reopened) and PlantArms.dead(f, p.missing) or {} -- (la première centrale attend sa recherche)
      if #dead > 0 then
        local cause = "insoluble:" .. table.concat(dead, ",")
        if Build.cancel(f, p.id, cause) then
          log(string.format("[FO-ENERGIE] %s : projet %d (centrale) refuse a %.1f min : %s (ni au coffre, ni recette ouverte) ; %d objet(s) manquent en tout",
            f.key or "player", p.id, tick / 3600, table.concat(dead, ", "), #p.missing))
          return
        end
      end
      p.reason, p.reserve_next = "materiaux", tick + 60
    end
    return
  end
  -- lot RACCORD-BANDE 2 : une LIGNE de bande (p.spec.lg) relit aussi ses manques en chantier : partie neuve 0.6.72 (diag2), 29 poteaux sur 32 posés puis plus rien
  -- pendant 6 min, 0 tâche au tableau : les poteaux perdus en route (PNJ tué, réserve de 31 pour 32) n'étaient demandés à personne (p.missing resté vide
  -- depuis la fin de la réserve), le PNJ échouait « stock » en boucle
  if (p.reopened or p.progressif or (p.spec and p.spec.lg)) and tick >= (p.miss_next or 0) and (p.state == "defrichage" or p.state == "fantomes" or p.state == "chantier") then
    p.miss_next = tick + 60 -- lot INTEG-RECONSTRUCTION (D6) : une fois par seconde
    Profiler.fstart("ch:missing")
    refresh_missing(f, p)
    Profiler.fstop("ch:missing")
  end
  if p.state == "defrichage" then
    if review_obstacles(surface, p) == 0 then p.state = "fantomes" end
    return
  end
  if p.state == "fantomes" then
    if not b.opts.ghosts_ahead then p.state = "chantier" return end
    local placed = 0
    local pending = 0
    for _, e in ipairs(p.ents) do
      if not e.built and not e.ghosted then
        if placed >= Build.GHOSTS_PER_PULSE then pending = pending + 1 break end
        if not Tokens.take(f, tick, Build.COST_GHOST) then return end
        local r = place_ghost(surface, f, e)
        if r == "occupe" and move_turrets_off(f, surface, p, e) then r = place_ghost(surface, f, e) end -- lot TOURELLES-HORS-AXE
        if r == "ok" then e.ghosted = true; placed = placed + 1; b.stats.ghosts = b.stats.ghosts + 1
        elseif r == "deja" then e.built = true
        elseif r == "obstacle" then
          add_obstacle(p, { x = e.x, y = e.y, anchor = e.anchor, ax = e.ax, ay = e.ay })
          e.ghosted = true
        elseif r == "pnj" then
          e.ghosted = true -- posé au ravivage (revive_one)
          npc_block(f, p, e, surface)
        else
          e.ghosted = true
          e.fails = (e.fails or 0) + 1; p.fails_lus = nil -- lot UPS : un refus de plus, le chantier relit ses pièces (advance)
          b.stats.ghost_refused = b.stats.ghost_refused + 1
          learn_cliff(f, surface, p, e, r) -- lot OBSTACLES
          log_refusal(f, p, e, r, surface)
        end
      end
    end
    if pending == 0 then p.state = "chantier" end
    return
  end
  if p.state == "chantier" then
    Profiler.fstart("ch:obst") -- lot UPS : portées fines du chantier (mesure seulement)
    review_obstacles(surface, p)
    Profiler.fstop("ch:obst")
    if all_built(p) then
      p.state = "raccordement"
    elseif p.fails_lus ~= true then
      -- Lot UPS : cette boucle relisait TOUTES les pièces du projet à chaque passe (toutes les 5 ticks). Elle n'agit que sur une pièce
      -- pas bâtie dont les refus ont atteint la limite ; chaque pièce de ce genre y est abandonnée (bâtie) ou bloque le projet (retour).
      -- Une lecture allée au bout n'en laisse donc aucune : p.fails_lus le dit, et les cinq lignes de ce fichier qui comptent un refus
      -- (les seules du mod à faire monter e.fails) l'effacent. Les réouvertures remettent e.fails à 0 avec e.built. Absent (sauvegarde
      -- d'avant ce lot) : la boucle se joue, comme avant.
      -- 3 refus d'un même fantôme : le module est bloqué (raison écrite), §6.6 (4)
      for _, e in ipairs(p.ents) do
        local ept = not e.built and e.cliff_hit and game.entity_prototypes[e.name] -- s50 falaises : type lu au prototype
        if not e.built and FalPure.skip_refused(e.wall, ept and ept.type, e.cliff_hit, e.fails, Build.FAIL_LIMIT * 2) then
          -- lot ESPACE : un mur refusé 3 fois (tuile prise, falaise cachée) est abandonné : il ne bloque pas toute l'enceinte
          e.built, e.dropped = true, true
          p.dropped = (p.dropped or 0) + 1
        elseif not e.built and (e.fails or 0) >= Build.FAIL_LIMIT * 2 and Sweep.refusal_verdict(p.reopened, p.retries, Build.RETRIES) == "abandon" then
          -- lot INTEG-RECONSTRUCTION (D2) : un projet ROUVERT dont les reprises sont épuisées abandonne la pièce refusée (emprise reprise par un
          -- arbre, un ouvrage du joueur, un nid) au lieu de mourir « bloque » sans reprise : le reste du module se refait, la fin (raccordement,
          -- fini) rend l'objet réservé et libère l'emplacement d'automatisation (A.MAX_OPEN). Lecteurs : all_built, Sw.todo, le relevé (e.dropped).
          e.built, e.dropped = true, true
          p.dropped = (p.dropped or 0) + 1
          log(string.format("[FO-IA1D] %s : projet %d rouvert, piece abandonnee apres %d reprises : %s en %s,%s (refus repetes)", f.key or "player",
            p.id, p.retries or 0, tostring(e.name), tostring(e.x), tostring(e.y)))
        elseif not e.built and (e.fails or 0) >= Build.FAIL_LIMIT * 2 then
          p.state, p.reason = "bloque", "fantome refuse (" .. e.name .. " en " .. e.x .. "," .. e.y .. ")"
          b.stats.projects_blocked = b.stats.projects_blocked + 1
          -- lot OBSTACLES : refus par une falaise = le MÊME plan échouera aux 3 reprises (mesuré : 4 parties sur 4, abandon à 267 min
          -- pour la fonderie de Scarlet) ; abandon tout de suite, le demandeur replanifie avec les tuiles apprises (b.hard)
          if e.cliff_hit then p.retries = Build.RETRIES end
          p.retries = (p.retries or 0) + 1
          p.retry_at = p.retries <= Build.RETRIES and (tick + Build.RETRY_TICKS) or nil
          -- lot PD-CENTRALE : la pompe d'une centrale lointaine refusée au moteur ne passera pas à la reprise : rive écartée, abandon
          -- tout de suite, et la place de LA centrale est rendue (le prochain module électrique en redemande une, à une autre rive)
          if p.far and (M.BASE[e.name] or {}).kind == "offshore" and Far.reject(f, p, "pompe refusee") then
            p.retry_at = nil
            if b.plant == p.id then b.plant = nil end
          end
          log(string.format("[FO-IA1D] %s : projet %d bloque : %s%s", f.key or "player", p.id, p.reason,
            p.retry_at and string.format(" ; reprise %d/%d a %.1f min", p.retries, Build.RETRIES, p.retry_at / 3600) or " ; abandon"))
          return
        end
      end
      p.fails_lus = true
    end
    return
  end
  if p.state == "raccordement" then
    finish_project(f, surface, p, tick)
  end
end

--- Lot FACTIONS-BLOQUEES : enlève les tourelles de l'équipe qui recouvrent seules l'emprise d'une entité encore à poser du projet
--- (moteur réel, 20261020 : fantôme d'un tapis refusé « occupe » par gun-turret de la même équipe, 30 refus, fonderie bloquée à 111
--- entités sur 113 de 36 min à la fin ; la pose des tourelles évite désormais les tuiles réservées, ceci reprend les chantiers
--- déjà pris). Rend le nombre d'entités enlevées. Une autre entité sur l'emprise (arbre, falaise, bâtiment) : rien n'est touché.
local function free_own_turrets(f, surface, p)
  local n, n_back, n_moved = 0, 0, 0
  for _, e in ipairs(p.ents) do
    if not e.built then
      -- lot TOURELLE-BANDE : entités SOLIDES seulement (couche « object-layer ») : le minerai sous une bande n'est pas un obstacle
      local found, list = surface.find_entities_filtered({ area = footprint(e), collision_mask = "object-layer" }), {}
      -- seules les tourelles ENREGISTRÉES de l'équipe (posées par les avant-postes) comptent : jamais celle qu'un joueur a posée
      for _, x in ipairs(found) do
        local mine = x.unit_number ~= nil and f.turrets ~= nil and f.turrets[x.unit_number] ~= nil
        list[#list + 1] = { name = x.name, force = mine and x.force.name or "non-enregistree", solid = true }
      end
      -- lot TOURELLES-HORS-AXE : d'abord déplacée à côté (move_turrets_off) ; récupérée au coffre seulement si aucune place
      if Blocage.own_blockers(list, f.force, T.turret) and move_turrets_off(f, surface, p, e) then
        n, n_moved = n + #list, n_moved + #list
      elseif Blocage.own_blockers(list, f.force, T.turret) then
        found = surface.find_entities_filtered({ area = footprint(e), collision_mask = "object-layer" }) -- relu : une tourelle déjà déplacée n'est plus sur l'emprise
        for _, x in ipairs(found) do
          if x.valid then
            -- Lot INTEG-DEFENSE 4.1 : la tourelle (et ses chargeurs) RETOURNE au coffre de l'équipe (la détruire perdait ~40 de fer, 10 de
            -- cuivre et 80 de fer de munitions, sans remboursement) ; coffre plein ou aucun coffre : détruite comme avant, pour que le
            -- chantier reprenne. Même effet sur le registre qu'avant (aucun événement levé).
            local taken = false
            local d = Build.Tj.describe(x) -- lot TOURELLE-JOURNAL (avant la reprise)
            if f.hq and f.hq.valid then
              for _, inv in ipairs(Stock.inventories(f)) do
                if inv and inv.valid and x.mine({ inventory = inv, force = false, raise_destroyed = false }) then taken = true break end
              end
            end
            if taken then n_back = n_back + 1 elseif x.valid then x.destroy() end
            Build.Tj.removed(d, "chantier de l'equipe " .. tostring(f.key), "emprise de " .. tostring(e.name) .. " (projet " .. tostring(p.id) .. "), aucune place a cote",
              taken and "reprise au coffre de l'equipe" or "DETRUITE (coffre plein ou absent)")
            n = n + 1
          end
        end
      end
    end
  end
  return n, n_back, n_moved
end

--- Lot FACTIONS-BLOQUEES : un projet qui n'avance plus depuis 10 min (aucune entité bâtie de plus) est écrit UNE fois par équipe et
--- par cause, journal [FO-BLOQUE] (retour du DC du 29/10 : « elles avancent pas »). Horloge propre (tous les 600 ticks), rien à
--- l'état du jeu hors f.build.noprog (nombres et chaînes).
local watch_stall
do
local STALL_STATES = { plan = true, reserve = true, chantier = true, raccordement = true, bloque = true }
function watch_stall(f, tick)
  local b = f.build
  if tick < (b.noprog_next or 0) then return end
  b.noprog_next = tick + 600
  b.noprog = b.noprog or {}
  b.noprog_dits = b.noprog_dits or {}
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and STALL_STATES[p.state] then
      local built = count_built(p)
      if p.state == "bloque" then p.bloc_cause, p.bloc_built = Blocage.cause(p.state, p.reason), built end
      -- la cause d'un blocage reste celle du blocage tant qu'aucune entité de plus n'est bâtie (reprise en « chantier » comprise)
      local cause = (p.bloc_cause and p.bloc_built == built) and p.bloc_cause or Blocage.cause(p.state, p.reason)
      local rec, say = Blocage.stall(b.noprog[pid], count_built(p), cause, tick)
      b.noprog[pid] = rec
      if say and not b.noprog_dits[pid .. ":" .. say] then -- lot REBUILD-SUIVI : une fois par (projet, cause), non par cause
        b.noprog_dits[pid .. ":" .. say] = true
        log(string.format("[FO-BLOQUE] %s : projet %d (%s) sans progres depuis %d min : %s ; %d entite(s) baties sur %d, etat %s a %.1f min%s",
          f.key or "player", p.id, tostring(p.spec.key or p.spec.gen or "?"), math.floor((tick - rec.since) / 3600), say, count_built(p), #p.ents,
          p.state, tick / 3600, ChantierLent.missing(p))) -- (RECHERCHE-BRAS suite : entités manquantes nommées, shared/team/manquantes.lua)
        ChantierLent.report(f, p, tick, say, rec) -- lot AZURE : détail du chantier lent d'une bande (une fois par projet)
      end
    elseif b.noprog[pid] then
      b.noprog[pid] = nil
    end
  end
end
end -- do

--- Lot CHARBON-CENTRALE : relevé des centrales finies (toutes les Cc.EVERY ticks). Une centrale encore nourrie par son coffre demande
--- le projet « alimentation de la centrale » (règle pure Cc.want_alim : un seul ouvert par équipe, pause et plafond après des refus) ;
--- il passe devant les projets en attente, après ce qui répare et les centrales. Journal [FO-CHARBON-CENTRALE] : demande, refus, fin.
--- Mémoire : b.charbon[pid de la centrale] = { alim, tries, retry_at, said, done_said } (nombres et chaînes), créée ici (événement).
local function charbon_step(f, tick)
  local b = f.build
  if tick < (b.cc_next or 0) then return end
  b.cc_next = tick + (Build.Charge and Build.Charge.stretch(Cc.EVERY) or Cc.EVERY) -- (lot TV-VAPEUR, V89 : relevé non urgent, espacé sous charge)
  b.charbon = b.charbon or {}
  local plants, other_open = {}, false
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and p.state == "fini" and is_plant_project(p) then plants[#plants + 1] = p end
    if p and p.spec and p.spec.alim and p.state ~= "fini" and p.state ~= "refuse" and not (p.state == "bloque" and not p.retry_at) then
      other_open = true
    end
  end
  for _, p in ipairs(plants) do
    local st = b.charbon[p.id] or {}
    b.charbon[p.id] = st
    local auto, alim = plant_automated(b, p)
    if alim and (alim.state == "refuse" or (alim.state == "bloque" and not alim.retry_at)) then
      -- refus du plan (pas de gisement à portée, pas de tracé) ou chantier abandonné : pause, puis nouvel essai
      local why = tostring(alim.reason)
      Cc.refused(st, tick, alim.cv_grew)
      b.charbon_logs = (b.charbon_logs or 0) + 1
      if b.charbon_logs <= Cc.LOGS then
        log(string.format("[FO-CHARBON-CENTRALE] %s : centrale %d, projet d'alimentation %d %s (%s) a %.1f min : refus %d (pause %s apres %d), nouvel essai a %.1f min ; le coffre reste rempli en urgence",
          f.key or "player", p.id, alim.id, alim.state, why, tick / 3600, st.tries, st.tries < Cc.MAX_TRIES and "courte" or "longue",
          Cc.MAX_TRIES, st.retry_at / 3600))
      end
      alim = nil
    end
    if auto and not st.done_said then
      st.done_said = true
      log(string.format("[FO-CHARBON-CENTRALE] %s : centrale %d nourrie par des foreuses a %.1f min (projet %s) ; son coffre reste en secours",
        f.key or "player", p.id, tick / 3600, tostring(alim and alim.id or "de la centrale")))
    elseif not auto then
      st.done_said = nil
    end
    local open = alim ~= nil and not auto
    local ok = Cc.want_alim(st, { automated = auto, quai = #(p.quais or {}) > 0, alim_open = open, other_open = other_open and not open,
      tick = tick, off = b.opts and b.opts.no_alim == true })
    if ok then
      local n, kw = plant_burn_kw(p)
      -- Intégration 0.6.28 (ENERGIE × poteaux) : même poteau que la centrale ; sans `pole`, le gabarit prenait M.DEFAULT_POLE (poteau moyen, recette
      -- pas encore ouverte : journal du DC, ambre, projet 4 « reserve:materiaux » à 28 min, electric-energy-distribution-1 non recherchée à 38 min)
      local id = Build.request(f, { alim = p.id, prio = Cc.PROJECT_PRIO, domain = "infrastructures", pole = p.spec and p.spec.pole })
      if id then
        st.alim = id
        other_open = true
        -- prioritaire : devant les projets en attente, après ce qui répare (rouvert) et les centrales pas encore finies
        local front, rest = {}, {}
        for _, x in ipairs(b.order) do
          local q = b.projects[x]
          if x ~= id then
            if q and ((q.reopened and (Sweep.rebuilding(q) or not q.ligne)) or (q.spec and q.spec.gen == p.spec.gen and q.state ~= "fini")) then front[#front + 1] = x
            else rest[#rest + 1] = x end
          end
        end
        front[#front + 1] = id
        for _, x in ipairs(rest) do front[#front + 1] = x end
        b.order = front
        b.charbon_logs = (b.charbon_logs or 0) + 1
        if b.charbon_logs <= Cc.LOGS then
          log(string.format("[FO-CHARBON-CENTRALE] %s : centrale %d nourrie a la main (%d chaudiere(s), %.2f charbon/s a pleine charge) : projet d'alimentation %d demande a %.1f min (essai %d, rang %d sur %d)",
            f.key or "player", p.id, n, Cc.rate(kw, M.COAL_J), id, tick / 3600, (st.tries or 0) + 1, #front - #rest, #front))
        end
      end
    end
  end
end

-- Lot X10-S0 : noms des portées fines de la passe par état du projet (constantes : aucune chaîne fabriquée par passe). Champ du
-- module, pas une locale : la fonction principale de ce fichier est à 199 locales sur 200 (relecture de revue-s, 8/11).
Build.BP_STATE_SCOPE = { attente = "bp:p-attente", plan = "bp:p-plan", reserve = "bp:p-reserve", defrichage = "bp:p-defrichage",
  fantomes = "bp:p-fantomes", chantier = "bp:p-chantier", raccordement = "bp:p-raccordement" }

local function pulse_team(f, tick)
  local b = f.build
  local surface = surface_of(f)
  if not (b and surface) then return end
  -- 1. évaluations
  Profiler.fstart("bp:eval") -- lot PERF3 : portées fines de la passe (mesure seulement)
  ungen_retry(f, surface, tick) -- lot INDUSTRIE I3 : lots lointains dont les chunks viennent d'être générés
  local n = 0
  while b.qhead <= #b.queue and n < Build.EVAL_PER_PULSE do
    if not Tokens.take(f, tick, Build.COST_EVAL) then break end
    eval_one(f, surface, b.queue[b.qhead], tick)
    b.queue[b.qhead] = false
    b.qhead = b.qhead + 1
    n = n + 1
  end
  if b.qhead > #b.queue and #b.queue > 0 then b.queue, b.qhead = {}, 1 end
  Profiler.fstop("bp:eval")
  -- 2. projets, dans l'ordre des demandes (un plan au plus par passe)
  Profiler.fstart("bp:projets")
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    -- projet bloqué : il a rendu ses PNJ ; il reprend son chantier à l'heure dite (échecs remis à zéro)
    if p and p.state == "bloque" and p.retry_at and tick >= p.retry_at then
      Profiler.fstart("bp:reprise") -- lot X10-S0 : portée fine (mesure seulement)
      p.retry_at = nil
      local freed, back, moved = free_own_turrets(f, surface, p) -- lot FACTIONS-BLOQUEES (TOURELLES-HORS-AXE : déplacées d'abord)
      if freed > 0 then
        b.stats.turrets_freed = (b.stats.turrets_freed or 0) + freed
        log(string.format("[FO-IA1D] %s : projet %d, %d tourelle(s) de l'equipe enlevee(s) de l'emprise du chantier (%d deplacee(s) a cote, %d rendue(s) au coffre avec leurs chargeurs)", f.key or "player", p.id, freed, moved or 0, back or 0))
      end
      for _, e in ipairs(p.ents) do if not e.built then e.fails, e.npc_blocks = 0, 0 end end
      p.state, p.reason = "chantier", nil
      log(string.format("[FO-IA1D] %s : projet %d reprend son chantier a %.1f min", f.key or "player", p.id, tick / 3600))
      Profiler.fstop("bp:reprise")
    end
    if p and p.state ~= "fini" and p.state ~= "refuse" and p.state ~= "bloque" then
      local was = p.state
      local scope = Build.BP_STATE_SCOPE[was] or "bp:p-autre" -- lot X10-S0 : temps de la passe par état du projet (mesure seulement)
      Profiler.fstart(scope)
      advance(f, surface, p, tick)
      Profiler.fstop(scope)
      if was == "plan" and p.state ~= "plan" then break end
    end
  end
  Profiler.fstop("bp:projets")
  Profiler.fstart("bp:suivi")
  watch_stall(f, tick) -- lot FACTIONS-BLOQUEES
  -- 3. lot PLANDIR : moniteur de la centrale finie (premier courant, pannes)
  local pp = b.plant and b.projects[b.plant]
  if pp and pp.state == "fini" then PlantArms.step(f, surface, pp, tick) end
  -- 4. lot CORR-RESEAU : santé de la centrale et du réseau (horloge propre, rien si pas l'heure)
  Profiler.fstop("bp:suivi")
  Profiler.fstart("bp:reseau")
  Build.Rv.step({ plant = Build.plant, cancel = Build.cancel, box = BoiteChunks.get, jeton = Jeton, pulse = Build.PULSE, prof = Profiler }, f,
    surface, tick)
  Profiler.fstop("bp:reseau")
  Profiler.fstart("bp:raccord")
  -- 4 bis. lot PD-ELEC (D05) : machines des modules finis sans courant HORS poteau perdu (île, sous aucun poteau) : raccordement
  -- (lot FONDERIE, 0.6.43) champ_live : les bandes de champ en cours sont relevées aussi (fonderie à tapis allumée)
  -- (lot LOURD) box : le relevé des générateurs du début de cycle se fait par bandes de la boîte des chunks
  Build.Raccord.step({ request = Build.request, prio = Build.PRIO + 4, champ_live = (Build.TAPIS and Build.TAPIS()) or false, jeton = Jeton,
    pulse = Build.PULSE,
    prof = Profiler, box = BoiteChunks.get }, f, surface, tick)
  -- 4 ter. lot INDUSTRIE I7 : un quai d'entrée porté à la main par un PNJ, relié par un tapis à la sortie d'un module du même objet
  Profiler.fstop("bp:raccord")
  Profiler.fstart("bp:liaison")
  Liaison.step({ request = Build.request, prio = Build.PRIO + 1, fill = Build.QUAI_FILL, low = Build.QUAI_LOW }, f, surface, tick)
  Build.Piquage.step({ request = Build.request, prio = Build.PRIO + 1, fill = Build.QUAI_FILL, low = Build.QUAI_LOW }, f, surface, tick) -- lot PIQUAGE
  Build.FonderieBloc.step({ request = Build.request, prio = Build.PRIO + 1 }, f, surface, tick) -- lot FONDERIE-BLOC : coffre de tête d'un champ sans source
  Profiler.fstop("bp:liaison")
  Build.Rapatriement.step({ request = Build.request, prio = Build.PRIO + 1 }, f, surface, tick) -- lot RAPATRIEMENT : sorties lointaines reliées au tampon près des quais
  Build.Mall.step({ couloirs = Build.couloirs, jeton = Jeton, pulse = Build.PULSE }, f, surface, tick) -- lot MALL : secteur (relevé par chunks sous le jeton), état S
  Profiler.fstart("bp:centrale")
  -- 5. lot CORR-ENERGIE : centrale saturée, une centrale de plus (même mécanisme que la première)
  local nb, stale, secours = PlantArms.watch(f, surface, tick)
  for _, id in ipairs(stale or {}) do Build.cancel(f, id, PlantArms.STALE_REASON) end
  if nb then Build.grow_plant(f, nb, tick, secours) end
  -- 6. lot CHARBON-CENTRALE : une centrale nourrie à la main demande ses foreuses (horloge propre)
  charbon_step(f, tick)
  Profiler.fstop("bp:centrale")
end

local function teams()
  local out = {}
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and f.build then out[#out + 1] = f end
  end
  local pf = State.faction("player")
  if pf and pf.build then out[#out + 1] = pf end
  return out
end

Events.on_nth_tick(Build.PULSE, function(e)
  -- lot CC-PLAN-FIGE (F512) : l'équipe servie la première tourne à chaque passe (le gros jeton du tick, celui d'un plan, va au premier
  -- demandeur ; dans l'ordre fixe, les plans par tranches des factions le prenaient à chaque passe et ceux de votre équipe ne passaient plus)
  local list = teams()
  for _, i in ipairs(Tokens.serve_order(#list, e.tick, Build.PULSE)) do
    local f = list[i]
    if f.hq and f.hq.valid then
      Profiler.start("build:pulse")
      pulse_team(f, e.tick)
      Profiler.stop("build:pulse")
    end
  end
end)

---------------------------------------------------------------------------------------------------
-- Lot ESPACE : croissance du treillis et enceinte (décisions toutes les Enc.CHECK_TICKS ; règles pures : shared/team/enceinte.lua)
---------------------------------------------------------------------------------------------------
local ACTIVE = { attente = true, plan = true, reserve = true, defrichage = true, fantomes = true, chantier = true, raccordement = true }

local function space_info(b)
  local busy = 0
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and ACTIVE[p.state] then busy = busy + 1 end
  end
  return { radius = b.radius, rmax = Build.RADIUS_MAX, pending = math.max(0, #b.queue - b.qhead + 1), free = Enc.free_count(b.lots),
    busy = busy, done = b.stats.projects_done, enc = b.enc ~= nil }
end

local function space_log(b, text)
  b.space_logs = (b.space_logs or 0) + 1
  if b.space_logs <= 40 then log(text) end
end

--- Lot C3 EXTENSION, BANCS SEULEMENT (interface « fo-ext », script/ai3/extension.lua) : pose une enceinte COMPLÈTE à contour serré sans en
--- construire les murs (les murs et leur fabrication ne sont pas l'objet du banc d'îlots) ; rend { bounds, out } ou nil (déjà une enceinte,
--- ouvertures hors bornes). Les lots hors du contour sont écartés (`out`) comme à la première demande de segment (space_step).
function Build.stage_enclosure(f, tick)
  local b = f.build
  if not b or b.enc then return nil end
  local tight = enc_tight_bounds(f)
  if not tight then return nil end
  b.enc = { r = b.radius, claimed = {}, segs = {}, tick = tick, gates = Enc.gate_count(), bounds = tight, complete = true }
  -- (une enceinte n'est demandée qu'après Enc.MIN_PROJECTS projets finis : la base du banc est réputée les avoir finis)
  b.stats.projects_done = math.max(b.stats.projects_done or 0, Enc.MIN_PROJECTS)
  return { bounds = tight, out = enc_mark_out(b, tight) }
end

--- Lot C3 EXTENSION (audit n°11 et 12, PLAN D4) : au-delà du mur, en îlots défendus (règles pures : shared/team/ilots_croissance.lua).
--- Enceinte COMPLÈTE : la porte des îlots (murs et tourelles des îlots déjà retenus, aucun chantier du mur) rend ou reprend les lots
--- dehors du contour (drapeau `out`), puis le treillis grandit d'un anneau quand il manque de lots libres. Journal [FO-EXTENSION].
local function ext_log(b, text)
  b.ext_logs = (b.ext_logs or 0) + 1
  if b.ext_logs <= 40 then log(text) end
end

function Build.beyond_step(f, b, enc, tick, main_busy)
  if not Build.beyond_wall(b) then return end
  local il = Ilots.state(f)
  local bounds = enc.bounds
  local rows = {}
  for _, k in ipairs(sorted_keys(b.lots)) do
    local l = b.lots[k]
    local x0, y0, x1, y1 = P.lot_rect(b.lat, l.i, l.j)
    local p = l.used and b.projects[l.used]
    rows[#rows + 1] = { k = k, out = l.out == true, used = l.used ~= nil, x0 = x0, y0 = y0, x1 = x1, y1 = y1,
      free = (l.state == "libre" or l.state == "defricher") and not (l.i == 0 and l.j == 0) and not (l.bad and l.bad >= 2),
      busy = p ~= nil and ACTIVE[p.state] == true and not (p.spec and p.spec.enceinte) }
  end
  local info = { islands = il.n, max = Ic.max_islands(f.engineers_count or 0), unwalled = il.unwalled, unguarded = il.unguarded,
    threatened = tick < (f.threatened_until or 0), main_busy = main_busy == true, outside_busy = Ic.count_busy(rows, bounds) }
  local ok, why = Ic.gate(info)
  local freed, parked = Ic.release(rows, bounds, ok)
  for _, k in ipairs(freed) do b.lots[k].out = nil end
  for _, k in ipairs(parked) do b.lots[k].out = true end
  local state = ok and "ouverte" or ("fermee : " .. tostring(why))
  if state ~= b.ext_gate then
    b.ext_gate = state
    ext_log(b, string.format("[FO-EXTENSION] %s : porte des ilots %s a %.1f min (ilots %d/%d, sans mur %d, sans tourelles %d, chantiers dehors %d ; %d lot(s) rendu(s), %d reprise(s))",
      f.key or "player", state, tick / 3600, info.islands, info.max, info.unwalled, info.unguarded, info.outside_busy, #freed, #parked))
  end
  local sinfo = space_info(b)
  sinfo.rmax = Build.RADIUS_ORE -- au-delà du mur le rayon va jusqu'au plafond des gisements (12), non plus à Build.RADIUS_MAX (5)
  sinfo.islands, sinfo.max, sinfo.unwalled, sinfo.unguarded = info.islands, info.max, info.unwalled, info.unguarded
  sinfo.threatened, sinfo.main_busy, sinfo.outside_busy = info.threatened, info.main_busy, info.outside_busy
  local due, dwhy = Ic.grow_due(sinfo)
  if due then
    b.ext_wait = nil
    ext_log(b, string.format("[FO-EXTENSION] %s : le treillis grandit au rayon %d AU-DELA du mur (rayon de l'enceinte %d ; lots libres %d < %d, ilots %d/%d) a %.1f min",
      f.key or "player", b.radius + 1, enc.r, sinfo.free, Ic.GROW_FREE_MIN, info.islands, info.max, tick / 3600))
    Build.grow(f, b.radius + 1, Build.RADIUS_ORE)
  elseif sinfo.free < Ic.GROW_FREE_MIN and dwhy ~= b.ext_wait then
    -- croissance voulue (manque de lots libres) mais refusée : la cause est écrite une fois par changement
    b.ext_wait = dwhy
    ext_log(b, string.format("[FO-EXTENSION] %s : croissance au-dela du mur voulue (lots libres %d < %d) mais attendue : %s, a %.1f min",
      f.key or "player", sinfo.free, Ic.GROW_FREE_MIN, tostring(dwhy), tick / 3600))
  end
end

--- Segment d'enceinte en cours (demandé, pas fini ni refusé) : numéro dans enc.segs, ou nil.
local function active_segment(b, enc)
  for i, sg in ipairs(enc.segs) do
    local p = b.projects[sg.pid]
    if p and p.state ~= "fini" and p.state ~= "refuse" then return i end
  end
  return nil
end

--- Contrôle des murs des segments finis, par paquets de Enc.REPAIR_BATCH murs : un segment qui a perdu un mur est rouvert SEUL
--- (réserve, fantômes, chantier) ; les autres ne bougent pas (lot ENCEINTE2). Les statistiques de projets ne sont pas touchées
--- (un projet rouvert ne se recompte pas : le « fini » suivant l'ignore).
--- Lot ILOTS-MURS : `hold` (facultatif) = l'état des îlots (f.build.ilots : mêmes champs segs, repair_at, cur_s, cur_e), `tag` son journal.
local function repair_enclosure(f, surface, tick, hold, tag)
  local b, enc = f.build, hold or f.build.enc
  if not enc.repair_at then
    for _, sg in ipairs(enc.segs) do
      local p = b.projects[sg.pid]
      if p and p.state == "fini" then enc.repair_at = (p.finished or tick) + Enc.REPAIR_TICKS break end
    end
    if not enc.repair_at then return end
  end
  if tick < enc.repair_at then return end
  local si, ei = enc.cur_s or 1, enc.cur_e or 1
  local budget = Enc.REPAIR_BATCH
  while si <= #enc.segs and budget > 0 do
    local sg = enc.segs[si]
    local p = b.projects[sg.pid]
    if p and p.state == "fini" then
      local last = math.min(#p.ents, ei + budget - 1)
      for i = ei, last do
        local e = p.ents[i]
        if e.built and not e.dropped
          and surface.count_entities_filtered({ position = { e.x, e.y }, radius = 0.4, type = { "wall", "gate" }, limit = 1 }) == 0 then
          e.built, e.ghosted, e.fails, e.npc_blocks = false, false, 0, 0
          sg.lost = (sg.lost or 0) + 1
        end
      end
      budget = budget - math.max(1, last - ei + 1)
      if last >= #p.ents then
        if (sg.lost or 0) > 0 then
          p.state, p.reason, p.reserve_next = "reserve", nil, nil
          p.reopened = (p.reopened or 0) + 1 -- non annulable (Build.cancel) tant que ses murs ne sont pas refaits
          space_log(b, string.format("%s %s : %d mur(s) detruit(s) au segment %d (%s) : il reprend son chantier a %.1f min",
            tag or "[FO-ESPACE]", f.key or "player", sg.lost, si, tostring(sg.side), tick / 3600))
        end
        sg.lost = nil
        si, ei = si + 1, 1
      else
        ei = last + 1
      end
    else
      si, ei = si + 1, 1
    end
  end
  if si > #enc.segs then
    enc.cur_s, enc.cur_e, enc.repair_at = nil, nil, tick + Enc.REPAIR_TICKS
  else
    enc.cur_s, enc.cur_e = si, ei
  end
end

--- Demande le segment suivant de l'enceinte `enc` (table de b.enc, ou candidate au premier segment) : (true) ou (false, raison).
--- Le segment est payé sur le stock : au plus un quart de ce que le coffre contient en murs ou permet d'en fabriquer.
local function request_segment(f, enc, tick)
  local b = f.build
  local wr = wall_recipe(f)
  if not wr then return false, "recette" end
  local runs = Enc.runs(b.lat, enc.r, { bounds = enc.bounds })
  local equiv = Stock.count(f, wr.item) + craftable_walls(f, wr)
  -- menaces connues de l'équipe (nids et vers de sa carte de connaissance, lot IA3-f) : liste { x, y, w } (shared/team/enceinte.lua)
  local m = f.ai3f and f.ai3f.m
  local threats = Enc.known_threats(m and m.s, f.build.lat, Enc.THREAT_RANGE)
  -- lot ENCEINTE3 (lot A) : le segment démarre au bout du tronçon le plus proche de la menace connue de son côté, à défaut du QG
  local seg, why = Enc.next_segment(runs, Enc.run_order(runs, b.lat, threats), enc.claimed, Enc.segment_cap(equiv),
    Enc.run_refs(runs, b.lat, threats))
  if not seg then
    if why == "complet" then enc.complete = true end
    return false, why, equiv
  end
  local tiles = {}
  for _, w in ipairs(seg.walls) do tiles[#tiles + 1] = { w.tx, w.ty } end
  local id, rwhy = Build.request(f, { enceinte = true, walls = tiles, side = seg.side, prio = Build.PRIO - 15, domain = "infrastructures" })
  if not id then return false, rwhy end
  Enc.claim(enc.claimed, seg.walls, true)
  enc.segs[#enc.segs + 1] = { pid = id, n = #seg.walls, side = seg.side }
  space_log(b, string.format("[FO-ESPACE] %s : segment d'enceinte %d demande (projet %d, cote %s, %d murs, stock equivalent %d murs, reste %d a reserver) a %.1f min",
    f.key or "player", #enc.segs, id, seg.side, #seg.walls, equiv, Enc.unclaimed(runs, enc.claimed), tick / 3600))
  return true
end

--- Sauvegarde d'avant ENCEINTE2 : un seul projet pour l'anneau entier. Il devient l'unique segment, et l'enceinte est complète.
local function upgrade_legacy_enclosure(enc)
  enc.claimed = enc.claimed or {}
  enc.segs = { { pid = enc.pid, n = enc.walls or 0, side = "tous" } }
  enc.complete = true
end

--- Un segment refusé ou annulé : ses tuiles sont rendues si c'est la place ou la matière qui a manqué (autrement, les tuiles ne
--- sont pas murables et restent réservées : pas de boucle) ; si rien n'est encore posé, le rayon est libéré comme avant.
local function segment_failed(f, tick, i, p)
  local b, enc = f.build, f.build.enc
  local why = p and p.reason or "projet perdu"
  local transient = why == "materiaux" or why == "place" or p == nil
  space_log(b, string.format("[FO-ESPACE] %s : segment d'enceinte %d refuse (%s)%s", f.key or "player", i, tostring(why),
    transient and " : tuiles rendues, nouvel essai plus tard" or " : tuiles non murables, gardees"))
  table.remove(enc.segs, i)
  enc.cur_s, enc.cur_e = nil, nil
  if transient then
    if p and p.spec and p.spec.walls then
      local list = {}
      for _, w in ipairs(p.spec.walls) do list[#list + 1] = { tx = w[1], ty = w[2] } end
      Enc.claim(enc.claimed, list, nil)
    end
    enc.complete = nil
    enc.retry = tick + Enc.SEG_RETRY_TICKS
  end
  -- plus aucun segment : rayon libere (refus durable de l'enceinte d'une sauvegarde d'avant, dont l'etat « complete » ne
  -- demanderait plus jamais de segment, ou anneau entierement refuse)
  if #enc.segs == 0 and (transient or enc.complete) then
    b.enc, b.enc_retry = nil, tick + Enc.RETRY_TICKS
    enc_release(b) -- lot ENCEINTE3
    space_log(b, string.format("[FO-ESPACE] %s : aucun segment pose, rayon libere, nouvel essai a %.1f min", f.key or "player", (tick + Enc.RETRY_TICKS) / 3600))
  end
end

--- Rapport de l'enceinte (Build.report) : rayon, segments (finis / demandés), murs planifiés, ouvertures.
function Build.enclosure_report(b)
  local enc = b.enc
  local fin, walls = 0, 0
  for _, sg in ipairs(enc.segs or {}) do
    local p = b.projects[sg.pid]
    if p then
      if p.state == "fini" then fin = fin + 1 end
      walls = walls + (p.walls_planned or sg.n or 0)
    end
  end
  return { r = enc.r, segments = #(enc.segs or {}), finished = fin, walls = walls, gates = enc.gates or Enc.gate_count(),
    complete = enc.complete == true, bounds = enc.bounds, tight = enc.bounds ~= nil }
end

--- Une décision de croissance ou d'enceinte (appelée à chaque pensée d'équipe, utile seulement toutes les Enc.CHECK_TICKS).
function Build.space_step(f, surface, tick)
  local b = f.build
  if b.opts.espace == false or tick < (b.space_next or 0) then return end
  b.space_next = tick + Enc.CHECK_TICKS
  local enc = b.enc
  if enc then
    if not enc.segs then upgrade_legacy_enclosure(enc) end
    local ai = active_segment(b, enc)
    if ai then
      -- matière absente depuis 5 min (briques dépensées ailleurs) : segment annulé, sinon il bloquerait le suivant
      local p = b.projects[enc.segs[ai].pid]
      if p and Enc.reserve_stalled(p.state, p.started, p.finished, tick) then Build.cancel(f, p.id, "materiaux") end
    end
    -- segments refusés (plan refusé, annulé) : le dernier d'abord, les numéros restent valables
    for i = #enc.segs, 1, -1 do
      local p = b.projects[enc.segs[i].pid]
      if not p or p.state == "refuse" then
        segment_failed(f, tick, i, p)
        if not b.enc then return end
      end
    end
    repair_enclosure(f, surface, tick)
    -- lot ILOTS-MURS : les îlots isolés hors du contour (shared/team/ilots.lua), APRÈS l'enceinte principale (complète, sans chantier)
    Ilots.step(f, surface, tick, { prio = Build.PRIO - 15, main_busy = active_segment(b, enc) ~= nil,
      equiv = function() local wr = wall_recipe(f) return wr and (Stock.count(f, wr.item) + craftable_walls(f, wr)) or 0 end,
      request = function(spec) return Build.request(f, spec) end, cancel = function(pid, why) return Build.cancel(f, pid, why) end,
      repair = function(hold) repair_enclosure(f, surface, tick, hold, "[FO-ILOT]") end })
    if Build.beyond_step then Build.beyond_step(f, b, enc, tick, active_segment(b, enc) ~= nil) end -- lot C3 EXTENSION
    if enc.complete or active_segment(b, enc) or tick < (enc.retry or 0) then return end
    local ok, why, equiv = request_segment(f, enc, tick)
    if ok then
      enc.poor = nil
    elseif why == "complet" and #enc.segs == 0 then
      -- toutes les tuiles de l'anneau sont non murables et aucun segment n'existe : le rayon n'a pas de raison d'etre fige
      b.enc, b.enc_retry = nil, tick + Enc.RETRY_TICKS
      enc_release(b) -- lot ENCEINTE3
      space_log(b, string.format("[FO-ESPACE] %s : aucune tuile murable, rayon libere, nouvel essai a %.1f min", f.key or "player", (tick + Enc.RETRY_TICKS) / 3600))
    elseif why == "stock" and not enc.poor then
      enc.poor = true
      space_log(b, string.format("[FO-ESPACE] %s : segment suivant attendu : stock equivalent %d murs, un quart = %d (minimum %d)", f.key or "player",
        equiv or 0, Enc.segment_cap(equiv or 0), Enc.SEG_MIN))
    end
    return
  end
  local info = space_info(b)
  if Enc.grow_due(info) then
    space_log(b, string.format("[FO-ESPACE] %s : le treillis grandit au rayon %d (lots libres %d < %d, chantiers %d, projets finis %d)",
      f.key or "player", b.radius + 1, info.free, Enc.GROW_FREE_MIN, info.busy, info.done))
    Build.grow(f, b.radius + 1)
    return
  end
  local on = b.opts.enceinte
  if on == nil then on = not f.is_player end  -- le joueur garde la main sur ses propres murs
  if not on or tick < (b.enc_retry or 0) or not Enc.enclosure_due(info) then return end
  -- premier segment : le rayon n'est figé (b.enc) que si un segment est vraiment demandé
  -- lot ENCEINTE3 : contour serré sur l'empreinte (bornes figées avec le rayon) ; nil : le rayon, comme avant
  local tight, tinfo = enc_tight_bounds(f)
  local cand = { r = b.radius, claimed = {}, segs = {}, tick = tick, gates = Enc.gate_count(), bounds = tight }
  local ok, why, equiv = request_segment(f, cand, tick)
  if not ok then
    if why == "stock" and not b.space_poor then
      b.space_poor = true
      space_log(b, string.format("[FO-ESPACE] %s : enceinte voulue (rayon %d, %d murs au plus), stock equivalent %d murs : un quart = %d, minimum %d : attente",
        f.key or "player", b.radius, Enc.max_walls(b.radius, { bounds = tight }), equiv or 0, Enc.segment_cap(equiv or 0), Enc.SEG_MIN))
    end
    return
  end
  b.enc = cand
  local out_n = tight and enc_mark_out(b, tight) or 0
  space_log(b, string.format("[FO-ESPACE] %s : enceinte progressive commencee (rayon %d fige, %d murs au plus en tout) a %.1f min", f.key or "player",
    b.radius, Enc.max_walls(b.radius, { bounds = tight }), tick / 3600))
  if tight then
    space_log(b, string.format("[FO-ESPACE] %s : contour serre %d,%d a %d,%d (QG %d,%d ; empreinte %d lots/tourelles gardes, %d isoles dehors, %d lots libres gardes dedans, %d lots ecartes du contour)",
      f.key or "player", tight[1], tight[2], tight[3], tight[4], b.lat.ox, b.lat.oy, tinfo.core, #tinfo.excluded, tinfo.room, out_n))
  end
end

--- Pensée d'équipe (script/team/team.lua, après l'organisation) : tâches au tableau, réévaluation des rues
--- défrichées, mesures par minute. Sans plan directeur : rien.
function Build.think(f, surface, tick)
  local b = f.build
  if not b then return end
  if Build.line_trace then Build.line_trace(f, tick) end -- lot RACCORD-BANDE 2 : trace [FO-LIGNE-BANDE-ETAT] (lecture seule)
  Build.LotsMinerai.minute(f, tick) -- lot VIDEO L9 : [FO-LOTS-MINERAI], une ligne par équipe et par minute de jeu (la mesure avant la règle)
  Build.LotsMinerai.think(f, tick) -- lot VIDEO MINERAI-SONDE : pièce détruite, ennemi vu ou porte fermée : le relevé des lots est refait (Lm.needs_survey)
  local tasks = {}
  local free_cache -- relecture REBUILD-RAPIDE : stock libre lu une fois par pensée, au premier projet rouvert (batch_tasks)
  local function free_of()
    if not free_cache then free_cache = free_stock(f) end
    return free_cache
  end
  -- Lot X10-S0 : portées fines de la pensée E2 (mesure seulement ; mêmes appels, même ordre)
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p then
      if p.state == "defrichage" then
        Profiler.fstart("e2:batch")
        clear_tasks(f, p, tasks)
        Profiler.fstop("e2:batch")
      elseif p.state == "chantier" or (p.state == "fantomes" and b.opts.ghosts_ahead) then
        Profiler.fstart("e2:batch")
        if #p.obstacles > 0 then
          local open = false
          for _, o in ipairs(p.obstacles) do if not o.done then open = true break end end
          if open then clear_tasks(f, p, tasks) end
        end
        batch_tasks(f, p, tasks, free_of)
        Profiler.fstop("e2:batch")
      end
      -- lot CHARBON-CENTRALE (relecture) : une centrale ROUVERTE (pièce détruite : reserve, defrichage, fantomes, raccordement, bloque)
      -- garde ses chaudières debout qui brûlent : son coffre se remplit aussi (avant : seulement fini ou chantier, coffre oublié pendant
      -- toute la reconstruction) ; quai_tasks ne fait rien sans le coffre réel de l'équipe
      -- lot X10-S0 : portée e2:quai autour du choix entier (quais, et sorties de COLLECTE) ; l'appel de quai_tasks reste la ligne qui suit
      -- la condition (relue telle quelle par tests/charbon_centrale_test.lua) ; e2:coffres compté à l'unique appel, et non dans quai_tasks,
      -- que tests/quotas_glue_test.lua charge à part, sans profileur (mesure seulement, détail)
      Profiler.fstart("e2:quai")
      if p.sites_v ~= 1 then Build.dedupe_sites(f, p) end -- lot MESURE-MODULE : projets planifiés avant le correctif
      if p.state == "fini" or p.state == "chantier" or (p.reopened and p.state ~= "refuse" and is_plant_project(p)) then
        quai_tasks(f, p, surface, tasks)
        Profiler.fcount("e2:coffres", #p.quais + #p.outs)
      elseif Build.Colr.collects_outs(p.state, #p.outs) then
        out_tasks(f, p, surface, tasks) -- lot COLLECTE : les coffres de sortie d'une bande en réserve ou refusée sont vidés aussi
      end
      Profiler.fstop("e2:quai")
    end
  end
  Profiler.fstart("e2:rues")
  Profiler.fwrap("e2:rues-routes", street_clear_tasks, f, tasks)
  Build.Place.defprev_tasks(f, tasks, tick) -- lot TV-PLACE (G38) : défrichage préventif de 50 x 50, un lot à la fois, priorité la plus basse
  Profiler.fstop("e2:rues")
  Profiler.fstart("e2:board")
  if b.opts.seul then
    Board.drop_free(f, function(t) return t.ia1d ~= nil end)
  end
  Build.Quartiers.route(f, surface, tasks) -- lot TV-ARCHI (V91) : quais d'un quartier ouvert servis par son depot (rien si fo-war-quartiers est eteint)
  Collecte.apply(f, surface, b, tasks, tick) -- lot COLLECTE : fer libre sous le besoin et équipe sous son effectif
  if #tasks > 0 then Board.add(f, tasks, tick) end
  Profiler.fstop("e2:board")
  Profiler.fstart("e2:conv")
  -- Lot FUITES-PILE : amélioration des tapis (R3, ses tapis pris au stock) suspendue pendant une retenue de la pile
  local conv_ok, conv_why = PileRt.porte(f, "upgrade", nil)
  if conv_ok then
    Conv.step(f, surface, tick) -- lot CONVOYEURS : amélioration des tapis saturés, tâche de fond bornée
  else
    PileRt.refuse(f, "convoyeurs", "amelioration des tapis suspendue (" .. tostring(conv_why) .. ")", tick)
  end
  Profiler.fstop("e2:conv")
  Profiler.fstart("e2:ligne")
  Build.ligne_step(f, surface, tick) -- lot FONDERIE-DYNAMIQUE : la ligne de fours suit ses foreuses (relevé borné)
  Profiler.fstop("e2:ligne")
  Profiler.fstart("e2:espace")
  -- tronçons encombrés : réévalués (défrichés par les PNJ)
  for _, key in ipairs(sorted_keys(b.segs)) do
    local s = b.segs[key]
    if s.state == "encombre" and s.cleared_tick and tick - s.cleared_tick < 600 then
      b.queue[#b.queue + 1] = { "seg", key }
      s.cleared_tick = nil
    end
  end
  Build.space_step(f, surface, tick)
  Build.Quartiers.step(f, tick, { request = Build.request }) -- lot TV-ARCHI (V23) : enveloppe d'avance (rien si fo-war-enveloppe est éteint)
  -- mesures par minute
  local st = b.stats
  local m = math.floor(tick / 3600)
  if st.minute_cur ~= m then
    st.minute_cur = m
    st.minutes[#st.minutes + 1] = { m = m, walks = st.street_walks, ok = st.street_ok, stuck = st.street_stuck,
      revived = st.revived, cleared = st.cleared, ghosts = st.ghosts }
    if #st.minutes > 240 then table.remove(st.minutes, 1) end
  end
  Profiler.fstop("e2:espace")
end

--- Un tronçon de rue défriché par un PNJ : réévalué à la pensée suivante.
function Build.street_cleared(f, key)
  if type(key) == "string" and key:sub(1, 4) == "pre:" then return Build.Place.defprev_cleared(f, key, game.tick) end -- lot TV-PLACE (G38) : un quart du défrichage préventif
  local s = f.build and f.build.segs[key]
  if s then s.cleared_tick = game.tick end
end

---------------------------------------------------------------------------------------------------
-- Lecture (interface du cerveau et des bancs)
---------------------------------------------------------------------------------------------------
function Build.status(f, id)
  local p = f and f.build and f.build.projects[id]
  if not p then return nil end
  local parts = {}
  for i = 1, #p.parts do
    local pt = p.parts[i]
    if pt then parts[#parts + 1] = { kind = pt.kind, key = pt.key, lot = pt.lot, x = pt.ox, y = pt.oy, w = pt.w, h = pt.h, rotation = pt.k } end
  end
  local missing = {}
  for _, m in ipairs(p.missing or {}) do missing[#missing + 1] = { m[1], m[2] } end
  -- quais d'entrée : contenu lu au moteur (le cerveau sait ce qui manque ; le banc sait quand renvoyer l'équipe)
  local quais = {}
  local surface = surface_of(f)
  for _, q in ipairs(p.quais) do
    local chest = surface and surface.find_entity(Build.QUAI_CHEST, { q.x, q.y })
    quais[#quais + 1] = { x = q.x, y = q.y, item = q.item, count = chest and chest.get_item_count(q.item) or -1 }
  end
  -- entités pas encore bâties (5 au plus, dans l'ordre de pose) : ce qui retient un chantier
  local unbuilt = {}
  for _, e in ipairs(p.ents) do
    if not e.built and #unbuilt < 5 then
      unbuilt[#unbuilt + 1] = { name = e.name, x = e.x, y = e.y, fails = e.fails or 0, npc = e.npc_blocks or 0, anchor = e.anchor }
    end
  end
  local open_obst = 0
  for _, o in ipairs(p.obstacles or {}) do if not o.done then open_obst = open_obst + 1 end end
  return { id = p.id, state = p.state, reason = p.reason, built = count_built(p), total = #p.ents, parts = parts,
    gen = p.spec and p.spec.gen or nil, secours = p.secours or nil, -- (lot TV-ENERGIE : générateur du projet, unité de secours)
    unbuilt = unbuilt, open_obstacles = open_obst,
    obstacles = #p.obstacles, quais = quais, outs = #p.outs, missing = missing, created = p.created, started = p.started,
    finished = p.finished, wires = p.wired, links = p.links, retry_at = p.retry_at, retries = p.retries, progressif = p.progressif or nil,
    -- lot FONDERIE-DYNAMIQUE : taille posée et réservée d'une ligne dynamique (nil pour les autres projets)
    ligne = p.ligne and { rows = p.ligne.rows, rows_max = p.ligne.rows_max, pairs = p.ligne.pairs, pairs_max = p.ligne.pairs_max,
      held = #p.ligne.held, last = p.ligne.last, steps = p.ligne.steps } or nil }
end

--- Lot MESURE-MODULE : retire les copies d'un même coffre de p.quais et p.outs (projets planifiés avant le correctif de plan_feed :
--- un plan qui attendait puis recommençait ajoutait ses coffres une fois de plus). Les indices de p.quais et p.outs servent de clé aux
--- tâches du tableau (ia1d:<projet>:q|o:<indice>) et sont copiés dans l'agent qui porte la tâche : ils sont RÉÉCRITS ensemble.
--- Une seule tâche reste par coffre (la prise de préférence), les copies libres sont jetées, la tâche prise passe à son nouvel
--- indice, celui de l'agent aussi. Appelée par la passe des tâches (premier passage après un chargement, jamais en on_load) tant que
--- p.sites_v ~= 1. Rend le nombre de copies retirées de p.quais et p.outs.
function Build.dedupe_sites(f, p)
  local D = Build.Sites
  local dq, do_ = D.count_dups(p.quais, D.quai_key), D.count_dups(p.outs, D.out_key)
  if dq == 0 and do_ == 0 then p.sites_v = 1; return 0 end
  local quais, map_q = D.remap(p.quais, D.quai_key)
  local outs, map_o = D.remap(p.outs, D.out_key)
  p.quais, p.outs = quais, outs
  p.quota, p.quota_key = nil, nil -- le quota se refait pour le vrai nombre de coffres (Quotas.of)
  -- tâches du tableau de ce projet
  local tasks = f.team and f.team.board and f.team.board.tasks or {}
  local entries, by_key = {}, {}
  for _, key in ipairs(sorted_keys(tasks)) do
    local t = tasks[key]
    local j = t.ia1d
    if j and j.pid == p.id and (j.mode == "collect" or j.mode == "fill") and type(j.idx) == "number" then
      entries[#entries + 1] = { key = key, mode = j.mode, idx = j.idx, taken = t.worker ~= nil }
      by_key[key] = t
    end
  end
  local plan = D.plan_tasks(entries, map_o, map_q, p.id)
  local dropped = {}
  for _, a in ipairs(plan) do if a.action == "drop" then dropped[by_key[a.key]] = true end end
  if next(dropped) ~= nil then Board.drop_free(f, function(t) return not dropped[t] end) end
  for _, a in ipairs(plan) do
    local t = by_key[a.key]
    if a.action == "keep" and t then
      local old = t.ia1d.idx
      t.ia1d.idx = a.idx
      if t.worker ~= nil then -- l'agent porte une copie de l'indice (étape « ia1d », worker.lua)
        local ag = Build.Agents.get(t.worker)
        local aj = ag and ag.ia1d
        if aj and aj.pid == p.id and aj.mode == t.ia1d.mode and aj.idx == old then aj.idx = a.idx end
      end
      if a.newkey ~= a.key and tasks[a.newkey] == nil then
        tasks[a.key] = nil
        tasks[a.newkey] = t
        t.key = a.newkey
      end
    end
  end
  p.sites_v = 1
  log(string.format("[FO-SITES] %s : projet %d, %d copie(s) de coffre d'entree et %d de coffre de sortie retiree(s), %d tache(s) du tableau jetee(s) (plans repris avant le correctif) a %.1f min",
    f.key or "player", p.id, dq, do_, (function() local n = 0; for _ in pairs(dropped) do n = n + 1 end; return n end)(), game.tick / 3600))
  return dq + do_
end

--- Lot IA3-e : état court d'une demande, SANS appel du moteur (lu à chaque pensée par le cerveau ; Build.status relit les
--- quais au moteur) : { state, reason, missing, built, total, retry_at, retries, parts }.
function Build.brief(f, id)
  local p = f and f.build and f.build.projects[id]
  if not p then return nil end
  local missing = {}
  for _, m in ipairs(p.missing or {}) do missing[#missing + 1] = { m[1], m[2] } end
  local parts = {}
  for i = 1, #p.parts do
    local pt = p.parts[i]
    if pt then parts[#parts + 1] = { kind = pt.kind, key = pt.key, x = pt.ox, y = pt.oy, w = pt.w, h = pt.h } end
  end
  -- objets des quais d'entrée (lot IA3-e : un module fini se nourrit DEPUIS LE COFFRE du QG, quai_tasks)
  local quais, seen = {}, {}
  for _, q in ipairs(p.quais or {}) do
    if q.item and not seen[q.item] then seen[q.item] = true; quais[#quais + 1] = q.item end
  end
  -- lot FONDERIE-DYNAMIQUE (relecture) : pièces du prochain pas d'une ligne dynamique FINIE qui manquent au coffre (ligne_one, ln.missing)
  local grow
  if p.state == "fini" and not p.abandoned and p.ligne and p.ligne.missing then
    grow = {}
    for _, m in ipairs(p.ligne.missing) do grow[#grow + 1] = { m[1], m[2] } end
  end
  -- lot FUITES-PILE (fuite b) : reconstruction (pièces détruites à refaire) contre pas d'agrandissement d'une ligne (ligne_open)
  local rebuilding = Sweep.rebuilding(p)
  return { state = p.state, reason = p.reason, missing = missing, built = count_built(p), total = #p.ents,
    retry_at = p.retry_at, retries = p.retries, parts = parts, quais = quais, grow = grow,
    rebuilding = rebuilding, progressif = p.progressif or nil, growth = (p.ligne ~= nil and p.reopened ~= nil and p.reopened ~= 0 and not rebuilding and p.state ~= "fini") or false,
    rangee = Build.Rangee.brief(p) } -- lot RANGEES-ASM : { n, n_max, held } d'une rangée dynamique
end

--- Lot ENERGIE (relecture) : projet d'alimentation de centrale ouvert de l'équipe (un seul à la fois, Cc.want_alim), ou nil. Lecteur :
--- script/ai3/automatisation.lua, qui en fait un but « fabriquer ses manques ». Lecture seule.
function Build.alim_project(f)
  local b = f and f.build
  if not b then return nil end
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and p.spec and p.spec.alim and p.state ~= "fini" and p.state ~= "refuse" and not (p.state == "bloque" and not p.retry_at) then return pid end
  end
  return nil
end

--- Lot FUITES-PILE : pose la famille de la pile et le produit d'un projet demandé AVANT ce lot (sauvegarde 0.6.21) ; ne change rien à un
--- projet déjà marqué. Appelé par script/ai3/automatisation.lua à chaque relevé d'un module suivi.
function Build.tag(f, id, family, product)
  local p = f and f.build and f.build.projects[id]
  if not (p and p.spec) or p.spec.pile then return false end
  p.spec.pile = family
  if product ~= nil and p.spec.product == nil then p.spec.product = product end
  return true
end

function Build.report(f)
  local b = f and f.build
  if not b then return nil end
  local st = b.stats
  local projects = {}
  for _, pid in ipairs(b.order) do projects[#projects + 1] = Build.status(f, pid) end
  local lots, segs = {}, {}
  for _, k in ipairs(sorted_keys(b.lots)) do local l = b.lots[k]; bump(lots, l.state .. (l.reason and (":" .. l.reason) or "")) end
  for _, k in ipairs(sorted_keys(b.segs)) do local s = b.segs[k]; bump(segs, s.state .. (s.reason and (":" .. s.reason) or "")) end
  local out = {
    radius = b.radius, lots = lots, segs = segs, queue = #b.queue - b.qhead + 1, projects = projects,
    lots_refused = st.lots_refused, segs_closed = st.segs_closed, plan_refused = st.plan_refused,
    ghosts = st.ghosts, ghost_refused = st.ghost_refused, revived = st.revived, revive_fail = st.revive_fail,
    cleared = st.cleared, filled = st.filled, collected = st.collected, npc_blocks = st.npc_blocks or 0,
    trips_collect = st.trips_collect or 0, trips_fill = st.trips_fill or 0, rapatrie = st.rapatrie or 0, -- lot RAPATRIEMENT : voyages de PNJ terminés, objets arrivés par tapis aux tampons
    route_calls = st.route_calls or 0, route_nil = st.route_nil or 0, route_resets = ROUTE_RESETS[f.key or "player"] or 0,
    self_skips = st.self_skips or 0,
    street_walks = st.street_walks, street_ok = st.street_ok, street_stuck = st.street_stuck,
    modules_started = st.modules_started, modules_done = st.modules_done, projects_done = st.projects_done,
    projects_refused = st.projects_refused, projects_blocked = st.projects_blocked, minutes = st.minutes,
    net = #sorted_keys(b.net), opts = { seul = b.opts.seul, ghosts_ahead = b.opts.ghosts_ahead },
    enceinte = b.enc and Build.enclosure_report(b) or nil,
    ilots = Ilots.report(b), -- lot ILOTS-MURS
    treillis = st.treillis, ungen = b.ungen and #b.ungen or 0, ungen_deferred = st.ungen_deferred or 0, ungen_back = st.ungen_back or 0, -- lot INDUSTRIE I3 : causes de la croissance vers un gisement
  }
  return out
end

--- Lots et tronçons (pour les captures et les bancs) : listes { i, j, state, reason } et { key, state, reason }.
function Build.layout(f)
  local b = f and f.build
  if not b then return nil end
  local lots, segs = {}, {}
  for _, k in ipairs(sorted_keys(b.lots)) do
    local l = b.lots[k]
    local x0, y0, x1, y1 = P.lot_rect(b.lat, l.i, l.j)
    lots[#lots + 1] = { i = l.i, j = l.j, state = l.state, reason = l.reason, used = l.used, x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  end
  for _, k in ipairs(sorted_keys(b.segs)) do
    local s = b.segs[k]
    local x0, y0, x1, y1 = P.seg_rect(b.lat, k)
    segs[#segs + 1] = { key = k, state = s.state, reason = s.reason, x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  end
  local ents = {}
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    for _, e in ipairs(p and p.ents or {}) do ents[#ents + 1] = { name = e.name, x = e.x, y = e.y, dir = e.dir, pid = pid, built = e.built or false } end
  end
  return { lots = lots, segs = segs, ents = ents, ox = b.lat.ox, oy = b.lat.oy }
end

remote.add_interface("fo-ia1d", {
  enable = function(key, opts)
    local f = team_of_key(key)
    local b = f and Build.enable(f, type(opts) == "table" and opts or {})
    return b ~= nil
  end,
  request = function(key, spec, expansion)
    local f = team_of_key(key)
    if not (f and f.build) then return nil, "plan directeur inactif" end
    -- (lot TV-ENERGIE : une demande de banc ne déclenche pas « l'énergie d'abord » ; `expansion` vrai = une vraie expansion, la règle s'applique : banc tv-energie)
    if type(spec) == "table" and spec.bench == nil and not expansion then spec.bench = "remote" end
    return Build.request(f, spec)
  end,
  --- Lot TV-ENERGIE (BANC SEULEMENT, micro-banc tv-energie-kw) : pose comme centrale FINIE de l'équipe un projet dont les pièces sont des entités
  --- RÉELLES déjà créées par le banc (ents = { { name, x, y } }) : le relevé de la centrale (PA.watch, Sante.observe) les lit au moteur.
  bench_plant = function(key, ents, gen, quais) -- quais (facultatif, lot COMBUSTIBLE-CENTRALE) : { { x, y, item } } coffres de quai de la centrale du banc
    local f = team_of_key(key)
    local b = f and f.build
    if not (b and type(ents) == "table") then return nil end
    local id = b.next_id
    b.next_id = id + 1
    local p = { id = id, spec = { gen = gen, args = { 1 }, feed = true, plant = true, bench = "remote" }, state = "fini", created = game.tick,
      finished = game.tick, reason = nil, parts = { { kind = "centrale", ox = ents[1] and ents[1].x or 0, oy = ents[1] and ents[1].y or 0, w = 3, h = 3, k = 0 } }, ents = {}, wires = {}, stock = {}, quais = type(quais) == "table" and quais or {}, outs = {},
      obstacles = {}, fails = 0, prio = Build.PRIO, domain = "infrastructures" }
    for _, e in ipairs(ents) do p.ents[#p.ents + 1] = { name = e.name, x = e.x, y = e.y, built = true } end
    b.projects[id] = p
    b.order[#b.order + 1] = id
    b.plant = id
    return id
  end,
  status = function(key, id) return Build.status(team_of_key(key), id) end,
  report = function(key) return Build.report(team_of_key(key)) end,
  place = function(key, cmd, arg) return Build.Place.remote(team_of_key(key), cmd, arg) end, -- lot TV-PLACE : compteurs de la sonde 30 x 30, du défrichage préventif et du repli simple (bancs)
  lots_minerai = function(key, cmd, arg) return Build.LotsMinerai.remote(team_of_key(key), cmd, arg) end, -- lot VIDEO MINERAI-SONDE : lots reserves, événements, relevés refaits (bancs)
  layout = function(key) return Build.layout(team_of_key(key)) end,
  quartiers = function(key, cmd, arg) return Build.Quartiers.remote(team_of_key(key), cmd, arg) end, -- lot TV-ARCHI : bancs (report, now, bench_build)
  -- banc seulement (migration des bras de la centrale, lot PLANDIR) : reproduit la conversion électrique des versions 0.6.5 à 0.6.7
  legacy_electric_arms = function(key)
    local f = team_of_key(key)
    local surface = f and surface_of(f)
    return (f and f.build and surface) and PlantArms.legacy_electric(f, surface) or 0
  end,
  set_option = function(key, name, value)
    local f = team_of_key(key)
    if not (f and f.build and (name == "seul" or name == "ghosts_ahead" or name == "sante" or name == "no_grow" or name == "no_lots" or name == "no_alim" or name == "no_sante" or name == "no_coupure" or name == "no_energie_dabord" or name == "no_combustible" or name == "no_tampon")) then return nil end -- no_coupure : coupe le chemin le plus court et le second chemin des poteaux perdus (lot ENERGIE 2/11, témoin des bancs) ; no_grow : coupe la croissance de la centrale (bancs) ; no_alim : coupe les foreuses de la centrale (lot CHARBON-CENTRALE, bancs) ; no_sante : coupe l'amorce à la main, la porte des consommateurs et l'avance de la centrale de plus (lot ENERGIE 2/11, témoin des bancs)
    f.build.opts[name] = value and true or false
    return f.build.opts[name]
  end,
})

return Build
