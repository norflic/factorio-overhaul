--[[
  Lot CAPI « la capitalisation des factions » (demandes du DC du 27/10, 12 h 05 : « le scaling des IA est aussi et surtout
  dans la maximisation des gisements, de la fonte et des crafts […] c'est le concept de capitalisation qu'il faut
  implémenter », « Et concernant la recherche IA ? » ; 12 h 15 : « A ne pas oublier toute la partie plus de gisements.
  Plus de fours (dans la limite de ce qu'on peut faire fondre évidemment), si assembleurs disponibles alors on ajoute des
  chaînes de production etc etc. »). Conception : docs/IA_CAPITALISATION.md. PUR (aucune API Factorio), testé hors jeu
  (tests/ai3_capitalisation_test.lua). (Texte d'origine : « rien n'est branché en jeu » ; périmé : branchée par le lot CAPIB,
  script/ai3/capitalisation.lua, allumée par défaut, tournante dans la partie du DC du 29/10. Le repli des ordres refusés est
  dans shared/ai3/repli.lua, lot CAPI-REPLI.)

  Ce qu'un joueur fait : il RÉINVESTIT sa production dans plus de capacité de production, là où elle rapporte le plus vite
  et seulement là où ce qu'elle produit a un débouché. Il couvre ses gisements de foreuses puis en ouvre d'autres, met
  autant de fours que son minerai en nourrit (jamais plus), monte des rangées d'assembleurs dès qu'il en a, fait grandir
  ses laboratoires et sa production de packs avec la recherche. Sa capacité croît comme un capital qui rapporte.

  En calcul, à chaque cycle (Ca.decide) :
    1. DÉBITS UNITAIRES lus dans les DONNÉES (Ca.data, relevé des prototypes au format de shared/ai3/catalogue.lua plus
       vitesses, aires de minage, puissances, temps de minage ; Ca.entity_of convertit un prototype lu en jeu) : foreuse
       60 × vitesse × (1 + bonus) ÷ temps de minage ; machine 60 × vitesse ÷ durée × quantités ; laboratoire 60 × vitesse
       × (1 + bonus) secondes de recherche par minute ; combustible kW × 60 ÷ pouvoir calorifique. Valeur des objets (MU) :
       point fixe min-plus jusqu'à stabilité (ressource = Ca.RAW_MU × temps de minage ; recette = ingrédients + Ca.TIME_MU
       par seconde de fabrication). Combustible : celui du catalogue (opts.cat.fuel) ou le filtre de l'exécutant
       (opts.fuel_ok) ; F332 : sans filtre, une ressource minable à la main plus riche que le charbon serait prise.
    2. DEMANDE (objets/min) aux PUITS : besoin des buts (÷ Ca.H_GOALS), puits mesurés (agrégés par objet), matières des
       ordres ouverts (le capital fabrique le capital, ÷ Ca.H_B), packs de la recherche visée, combustible des machines à
       combustion. Les puits ÉLASTIQUES (recherche tant qu'il reste des technologies, puits marqués `elastic`) visent
       (1 + g) × leur débit, g = s ÷ (T̄ + délai de pose) (‰ par cycle, au plus Ca.G_MAX), jamais plus de Ca.LEAD fois ce
       qui tourne. Sans puits élastique : g = 0 (saturation GLOBALE).
    3. BESOIN par objet : demande propagée dans le graphe des recettes (recette choisie dans les données ; un objet ne
       transmet à son amont que son besoin NET de son stock) : R_i, et la part de R_i de chaque utilisateur (used_by).
       Capacité planifiée N_i : machines posées, reste des ordres ouverts (n_left), ordres de ce cycle ; la MAIN n'est pas
       du capital (Ca.HAND_CAPITAL = 0) ; un gisement épuisé (amount ≤ 0) ne compte plus. Manque d_i = R_i − N_i − stock_i
       ÷ Ca.H_STOCK.
    4. OPTIONS par levier (aucun nom, aucune table par bâtiment) :
         couvrir  : foreuses sur un gisement OUVERT qui a des places (peigne lu sur la foreuse : Ca.comb) ; pour le manque,
                    puis D'AVANCE avec le budget qui reste (jusqu'à Ca.KAPPA ‰ et Ca.LEAD × le besoin, gain à
                    Ca.AHEAD_PCT %) ; fonte sur place dimensionnée par GISEMENT (débit total de ses foreuses moins ce que
                    ses fours mangent déjà) ;
         ouvrir   : un gisement CONNU de plus quand les ouverts sont couverts ou interdits (danger, courant), et qu'il
                    manque, ou d'avance (épuisement en moins de Ca.H_LIFE, réserve de places basse, site moins cher) ;
                    sans site connu : exploration ;
         fours    : fabriques qui ne sont pas des assembleurs, nourries par le minerai LIVRÉ PAR LES FOREUSES (mesuré, sans
                    la main ni le stock) : jamais plus que ce qu'il nourrit (Ca.fed_max) ; d'avance (« fondre tout le
                    minerai ») seulement sur la part que les autres usages du minerai ne réclament pas, et au plus
                    Ca.LEAD × le débouché ;
         chaine   : rangée d'assembleurs (fabrique d'une catégorie de la main : la sorte vient de la MACHINE) DÈS qu'une
                    machine est disponible (exécutable, recherchée, fabricable) ; packs : la même chose pour une entrée de
                    laboratoire ; l'aval d'un ingrédient en manque ATTEND (goulot amont d'abord) ;
         labos    : laboratoires pour la recherche visée (en DÉBIT), jamais plus que les packs ne nourrissent ;
         energie  : centrale quand des machines électriques rentables manquent de courant.
       Les améliorations de niveau restent au lot CAPITAL (un seul décideur par levier).
    5. COÛT C = matières (MU) + λ × travail (λ = 0 quand des bras sont libres) ; GAIN G (MU/min) = part UTILE de l'ajout
       (au plus le manque ; Ca.AHEAD_PCT % pour un débit d'avance) × valeur de l'objet × PART DE L'ÉTAGE dans le capital
       de toute sa chaîne (Ca.share : capital de l'étage ÷ capital de la chaîne, Ca.chain_capital) × poids de la famille,
       plus les bras libérés de la main, moins le combustible. RETOUR T = C ÷ G : pour un étage plein, T = capital de la
       chaîne ÷ valeur, le retour du PROJET de chaîne (la valeur au puits n'est plus comptée à chaque étage) ; accepté si
       T ≤ T_max.
    6. CHOIX GLOUTON : la meilleure option (T arrondi au millionième, profondeur, clé), réduite par dichotomie si elle
       dépasse budget ou bras, appliquée au plan, puis TOUT est recalculé (gain marginal), tant que le BUDGET matières et
       le BUDGET de bras le permettent, au plus Ca.OPEN_MAX ordres ouverts.
  BUDGET : part libre des parts défense et armée (1 − δ − α) appliquée au flux ET au stock ; le flux réinvesti s × Y est
  ÉPARGNÉ d'un cycle à l'autre (st.bank, au plus Ca.BANK_H minutes) : une option plus chère qu'un cycle finit par passer ;
  le stock libre ne compte que les objets CONVERTIBLES (fermeture des recettes des foreuses, fabriques, laboratoires et
  pièces de l'exécutant ; ni militaire, ni objet d'un puits).
  Caractère (traits d'IA2-0, poids d'IA2-a) : s (part réinvestie), δ (défense), α (armée), T_max ; menace : T_max ÷ 4,
  δ double, seuls les leviers du QG restent ouverts (Ca.HQ_LEVERS).
  Cerveau : Ca.goals rend des buts de FOND (g.fond du lot CAPITAL : aucune des K places, servis après les autres projets),
  valeur 35 à 50 (sous la recherche et l'extraction), un par ordre NOUVEAU OU OUVERT jusqu'à sa fin.

  Aucun nom du jeu ici (test anti-échelle, tests/iag_test.lua §8) : objets, recettes, machines et ressources viennent du
  relevé. Déterminisme : listes triées (égalités départagées par l'index d'origine ou la clé), flottants calculés dans un
  ordre fixe, aucun hasard, aucun pairs décisionnel ; l'état persistant `st` ne garde que des nombres et des tables.
]]

local R = require("shared.ai3.reglages") -- types du moteur -> rôle (seules données nommées admises)
local Lv = require("shared.ai3.leviers") -- lot LEVIERS : modules dans les machines posées, recherches à effet
local Gi = require("shared.team.gisement") -- lot GISEMENTS : matière la plus en manque d'abord, pas d'avant-poste de trop
local Dm = require("shared.ai3.demande") -- lot C2 : puits ouvert (le stock qui dort devient une demande)
local Pf = require("shared.ai3.plafonds") -- lot VIDEO-L13 : gardes fermées par défaut (places des ordres ouverts)
local Rg = require("shared.ai3.rang") -- lot VIDEO-L1b : rang de la décision (Rg.chain), ordre de propagation des besoins
local Cf = require("shared.ai3.confirmation") -- lot VIDEO-COUVERTURE 5 : module suivant retenu en amont (Cf.upstream)
local Pr = require("shared.ai3.porte_rang") -- lot VIDEO-L2 : porte de rang ciblée
local Cv = require("shared.ai3.couverture") -- lot COUVERTURE : saturation totale des gisements revendiqués (Cv.saturation)

local Ca = {}

-- Valeurs (MU, unité de la règle X0 : une unité de ressource d'une seconde de minage vaut 1).
Ca.RAW_MU = 1           -- MU d'une ressource par seconde de minage (temps de minage du prototype)
Ca.TIME_MU = 0.1        -- MU d'une seconde de fabrication à vitesse 1 (valeur ajoutée d'une recette, d'un laboratoire)
-- Horizons (minutes).
Ca.H_GOALS = 10         -- besoin des buts servi en 10 min
Ca.H_STOCK = 10         -- un stock couvre son débit pendant 10 min
Ca.H_BUF = 5            -- tampon gardé au stock ; au-delà, le stock convertible est LIBRE et s'investit
Ca.H_B = 10             -- matières des ordres ouverts fabriquées en 10 min (programme d'équipement)
Ca.H_R = 20             -- file de recherche visée en 20 min au plus
Ca.H_FUEL = 30          -- combustible compté sur 30 min dans le choix d'une machine
Ca.H_LIFE = 60          -- gisements ouverts épuisés en moins de 60 min : ouvrir le suivant d'avance
-- Gisements.
Ca.SCARCE_FIRST = true  -- lot GISEMENTS : ordre des options de matière par bande de pénurie (mutant : false)
Ca.KAPPA = 1000         -- ‰ des tuiles sous une foreuse : gisement couvert EN ENTIER (DC 31/10 : « il ne faut pas s'arrêter à 80 % » ; 800 avant le lot GISEMENTS)
Ca.RESERVE_PCT = 25     -- places libres de débit inférieur à 25 % de la demande : ouvrir le suivant d'avance
Ca.OPEN_RATIO = 120     -- % : un site neuf 20 % moins cher par débit que couvrir l'ancien : l'ouvrir
Ca.OPEN_MIN = 2         -- foreuses au moins sur un gisement ouvert d'avance
-- Lot GEANT-D-ABORD : parmi les sites d'un minerai, les 3 PLUS PROCHES étaient seuls évalués (Ca.SITES_EVAL) : un géant à 150 tuiles n'était jamais regardé
-- tant que trois petits cercles étaient plus près. Le rang d'un site est sa distance moins un crédit de taille PLAFONNÉ (Ca.GIANT_CREDIT tuiles au plus,
-- de 0 à Ca.GIANT_SMALL tuiles du gisement à plein crédit à Ca.GIANT_FULL) ; le crédit ne change que l'ORDRE : un site dangereux ou bloqué reste refusé
-- plus loin (f.danger, f.blocked), aucun site n'est ajouté.
Ca.GIANT_SMALL = 300
Ca.GIANT_FULL = 2500
Ca.GIANT_CREDIT = 90
function Ca.size_credit(tiles)
  if type(tiles) ~= "number" or tiles <= Ca.GIANT_SMALL then return 0 end
  if tiles >= Ca.GIANT_FULL then return Ca.GIANT_CREDIT end
  return math.floor(Ca.GIANT_CREDIT * (tiles - Ca.GIANT_SMALL) / (Ca.GIANT_FULL - Ca.GIANT_SMALL))
end
--- Rang d'un site `f` ({ dist, tiles }) : plus petit d'abord.
function Ca.site_rank(f)
  return (f.dist or Ca.DIST) - Ca.size_credit(f.tiles)
end
Ca.SITES_EVAL = 3       -- sites connus évalués par ressource et par passe, les plus proches (coût de calcul)
-- Machines.
Ca.U_MIN = 50           -- % : une machine de plus pour au moins une demi-machine de manque (goulot : dès le premier objet)
Ca.FRAC_UP = 0.1        -- machines nourries : ⌊x⌋ + [frac(x) ≥ 0,9] (famine ≤ 10 %, entassement < une machine)
Ca.THETA_MIN = 900      -- ‰ : une chaîne attend tant que son ingrédient est couvert à moins de 90 % (goulot amont)
Ca.AHEAD_PCT = 25       -- % du gain compté pour un débit d'avance (il servira peut-être)
Ca.HAND_CAPITAL = 0     -- part de la fabrication à la main comptée comme capacité : 0 (« ils craftent beaucoup à la main »)
-- Caractère (traits pour mille d'IA2-0, poids pour mille d'IA2-a).
Ca.S0, Ca.S_MIN, Ca.S_MAX = 500, 200, 800   -- part réinvestie (‰)
Ca.D0, Ca.A0 = 100, 150                     -- parts de la défense et de l'armée (‰), prises AVANT le budget
Ca.SHARE_MAX = 800                          -- défense + armée au plus (‰)
Ca.T0, Ca.T_MIN, Ca.T_MAX = 20, 10, 40      -- retour accepté (min) : T0 × ambition ÷ prudence, borné
Ca.THREAT_DIV = 4                           -- menace : retour accepté ÷ 4 (comme les 5 min d'IA3-e)
-- Leviers du QG : les seuls ouverts sous menace (les foreuses et les sites sont hors du QG).
Ca.HQ_LEVERS = { fours = true, chaine = true, packs = true, labos = true, energie = true, equiper = true, techno = true }
-- Budget, croissance, bras.
Ca.STOCK_PCT = 50       -- part du stock libre convertible investissable par cycle
Ca.RESERVE_PCT = 100    -- lot INDUSTRIE I1 : part du stock HORS BESOIN investissable par cycle (le besoin est évalué, shared/ai3/reserve.lua)
Ca.BANK_H = 30          -- épargne du flux réinvesti : au plus 30 min de ce flux
Ca.CYCLE_MIN = 1        -- un cycle = 1 min (le runtime donne `dt` en minutes)
Ca.G_MAX = 150          -- ‰ de croissance de la demande élastique par cycle, au plus
Ca.T_GROWTH0 = 5        -- min : retour supposé avant le premier ordre
Ca.T_LAG = 5            -- min : délai de pose supposé (décision -> bâtiment qui tourne) quand le runtime ne le mesure pas
Ca.T_HIST = 3           -- cycles gardés pour le retour moyen T̄ (médiane)
Ca.CHAIN_MAX = 4        -- … et au plus 4 machines d'avance par ordre
Ca.CHAIN_LEAD = 2       -- lot PILE-MALL : une chaîne se dimensionne sur 2 fois le débit voulu au plus (nil : le manque présent seulement)
Ca.LEAD = 2             -- la demande élastique, et la capacité d'avance, ne dépassent jamais 2 fois le débit voulu
-- Couverture d'avance d'un gisement OUVERT : plafond en multiple du besoin. nil = aucun plafond (décision de l'intégrateur
-- sur Q-CAPI-1, OBJECTIFS §4, 27/10 vers 14 h 20, tirée de la phrase du DC de 12 h 30 « il aurait mis des foreuses partout,
-- récupérer un maximum » : couvrir jusqu'à Ca.KAPPA ‰ des tuiles dès que le budget le permet, SANS « 2 × le besoin » ; les
-- FOURS restent bornés par le minerai livré, Ca.fed_max). Lot CAPIB (branchement, 27/10 soir).
Ca.COVER_LEAD = nil
-- Couverture d'avance avec une foreuse À COMBUSTIBLE : interdite (false). Son combustible est porté par les PNJ, à vie : un
-- travail récurrent que le coût de pose ne compte pas. Moteur réel, banc p2 du lot CAPIB (graine 1618033988) : 75 à 102
-- foreuses à combustion à 40 min, 43 fours sur 48 des avant-postes sans minerai (foreuses sans charbon), fer extrait
-- divisé par 4. La couverture d'avance se fait avec des foreuses sans combustible (électriques) ; le MANQUE reste couvert
-- par toute foreuse.
Ca.AHEAD_BURNER = false
Ca.LABOR_H = 10         -- min de travail des bras disponibles engagés au plus
Ca.SPARE = 2            -- PNJ : travail qui attend au-delà des bras libres (fait venir une recrue, IA3-d)
Ca.HANDS_MIN = 1        -- PNJ : un bras au moins peut toujours passer au capital
-- Travail (mêmes ordres de grandeur qu'IA3-e, shared/ai3/automatiser.lua).
Ca.POSE_S, Ca.BATCH, Ca.WALK, Ca.HANDLE_S, Ca.DIST = 1.5, 12, 8, 10, 56
Ca.NEAR_SITE = Gi.NEAR -- tuiles : un gisement ouvert plus près que cela d'un site, avec des places, rend l'ouverture du site inutile (lot GISEMENTS)
-- Valeur d'un but au cerveau (échelle des projets) : 35 (seuil du travail qui fait recruter, IA3-d) à 50, sous la
-- recherche (B.RESEARCH 62) et l'extraction ; but de FOND (lot CAPITAL : bancs c1 et c1-témoin, un but de capital servi
-- comme un projet ordinaire retardait la recherche).
Ca.V_MIN, Ca.V_SPAN, Ca.V_MAX, Ca.V_SHAPE = 35, 15, 50, 7
-- Lots VIDEO-L1b et VIDEO-L2 (docs/TODO_VIDEO.md §H ; fo-logs/2026-11-07_VIDEO-AUTOMATISATION/PLAN_L1_L2.md) : ALLUMÉS à l'étape 8
-- d'INTEGRATION_VIDEO, Ca.RANG d'abord, puis Ca.PORTE_RANG. Éteints (false), la décision est celle d'avant ligne pour ligne
-- (tests/rang_cablage_test.lua §1) : c'est le repli si l'un des deux doit être coupé.
Ca.RANG = true          -- L1b : le besoin se propage dans l'ordre du RANG de la décision (Rg.chain), calculé une fois par jeu de graines
Ca.PORTE_RANG = true    -- L2 : un ordre de production qui dépend d'un manque d'un rang plus bas attend (Pr.decide) ; demande Ca.RANG
Ca.MAX_ORDERS = 24      -- ordres nouveaux au plus par cycle (coût de calcul)
Ca.OPEN_MAX = 16        -- ordres ouverts au plus (plafond de sûreté du dépliage ; le travail disponible borne avant)
Ca.HQ = "qg"
Ca.EPS = 1e-9
-- Lot VIDEO-L5 (confirmation observée, shared/ai3/confirmation.lua) : sortes d'ordres SUSPENDUES tant qu'une unité posée de leur
-- objet attend sa première production (input.hold = { [objet] = raison }, relevé du runtime ; absent : rien de suspendu).
Ca.HOLD_KINDS = { couvrir = true, ouvrir = true, fours = true, chaine = true, packs = true }
-- Lot VIDEO-L13 (plafond par objet, shared/ai3/plafonds.lua) : sortes PLAFONNÉES (posé nominal + ouvert + ajouté ≤ Pf.K × la demande ;
-- Pf.HARD unités au plus). couvrir et ouvrir n'y sont pas : décision du DC sur Q-CAPI-1, « foreuses partout » (Ca.COVER_LEAD = nil).
Ca.CAPPED = { fours = true, chaine = true, packs = true }
-- Plafond ABSOLU par objet, en unités posées + ouvertes (Pf.fits, s.hard). Lot TV-PILOTE (G02) : il est posé PAR SORTE (Pf.HARD_OBJ : fours
-- 192, chaînes 96, packs 96, valeurs mesurées dans shared/ai3/plafonds.lua) par Ca.cap_hard. Ca.CAP_HARD n'est plus que le repli d'un
-- objet SANS recette (extraction : couvrir et ouvrir ne sont pas plafonnés, Q-CAPI-1) : hors d'atteinte comme avant. Avant TV-PILOTE : un plafond
-- unique de 64 (Pf.HARD) changeait 116 rendus sur 502 au témoin A/B de VIDEO-INTEG (K6), d'où 192 pour les fours (§3, 1 800/min : 96 fours).
Ca.CAP_HARD = 1e6

---------------------------------------------------------------------------------------------------
-- Outils
---------------------------------------------------------------------------------------------------
local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end
Ca.sorted_keys = sorted_keys

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

local function set_of(list)
  local s = {}
  for _, v in ipairs(list or {}) do s[v] = true end
  return s
end

local function sorted_copy(list)
  local out = {}
  for i, v in ipairs(list or {}) do out[i] = v end
  table.sort(out)
  return out
end

--- Copie triée d'une liste de tables par une clé texte ; égalités départagées par l'index d'origine (tri STABLE : la
--- clé doit donc porter tout ce qui distingue deux éléments, sans quoi l'ordre d'entrée compte).
local function sort_by(list, keyf)
  local tmp = {}
  for i, v in ipairs(list or {}) do tmp[i] = { k = keyf(v), i = i, v = v } end
  table.sort(tmp, function(a, b)
    if a.k ~= b.k then return a.k < b.k end
    return a.i < b.i
  end)
  local out = {}
  for i, e in ipairs(tmp) do out[i] = e.v end
  return out
end

local function amount_of(list, name)
  local a = 0
  for _, x in ipairs(list or {}) do if x.name == name then a = a + x.amount end end
  return a
end

local function norm_amount(x)
  local a = x.amount
  if a == nil then a = ((x.amount_min or 0) + (x.amount_max or x.amount_min or 0)) / 2 end
  return a * (x.probability or 1)
end

local function median(list)
  if #list == 0 then return nil end
  local c = sorted_copy(list)
  return c[math.floor((#c + 1) / 2)]
end

local function fmt(x)
  if x == nil then return "-" end
  if x == math.huge then return "inf" end
  if x ~= x then return "nan" end
  return string.format("%.1f", x)
end

--- Somme de nombres dans un ordre fixe (croissant) : la même entrée permutée donne le même flottant.
local function fsum(list)
  local c = sorted_copy(list)
  local s = 0
  for _, x in ipairs(c) do s = s + x end
  return s
end

---------------------------------------------------------------------------------------------------
-- 1. Données : relevé des prototypes -> débits unitaires et valeurs
---------------------------------------------------------------------------------------------------
--- Prototype d'entité lu en jeu (champs de LuaEntityPrototype, API 1.1.91) -> entité du relevé de Ca.data. Unités :
--- vitesse = crafting_speed, mining_speed ou researching_speed ; aire de minage (CÔTÉ) = arrondi de 2 ×
--- resource_searching_radius (un RAYON : 2,49 -> 5) ; emprise = tile_width ; kW = energy_usage (J par tick) × 60 ÷ 1000.
function Ca.entity_of(p)
  local e = {}
  for _, k in ipairs({ "name", "type", "item", "energy", "crafting_categories", "resource_categories", "lab_inputs" }) do
    e[k] = p[k]
  end
  e.speed = p.crafting_speed or p.mining_speed or p.researching_speed or 1
  if p.resource_searching_radius then e.mining_area = math.floor(2 * p.resource_searching_radius + 0.5) end
  e.size = p.tile_width
  if p.energy_usage then e.energy_kw = p.energy_usage * 60 / 1000 end
  -- Lot PREVISION (C12) : pollution/min à pleine marche (emissions_per_second × 60) : la défense induite d'un agrandissement.
  if p.emissions_per_second then e.emit = p.emissions_per_second * 60 end
  return e
end

--- Bras libres : Br.smooth (lot SCALE) est en DIXIÈMES de PNJ ; la règle attend des PNJ.
function Ca.idle_of(smooth10) return (smooth10 or 0) / 10 end

--- Fermeture des recettes : les objets `seeds` et tout ce qui entre (récursivement) dans une de leurs recettes, sauf
--- les objets militaires et les fluides. Rend un ensemble (indépendant de l'ordre des graines).
function Ca.closure(D, seeds, out)
  out = out or {}
  local stack = {}
  for i = #(seeds or {}), 1, -1 do stack[#stack + 1] = seeds[i] end
  while #stack > 0 do
    local x = stack[#stack]
    stack[#stack] = nil
    if x and not out[x] and not D.mil[x] then
      out[x] = true
      for _, rn in ipairs(D.producers[x] or {}) do
        for _, i in ipairs(D.recipes[rn].ingredients) do
          if not i.fluid and not out[i.name] then stack[#stack + 1] = i.name end
        end
      end
    end
  end
  return out
end

--- Relevé (format de shared/ai3/catalogue.lua, K.build) complété de : entities[].speed, mining_area (côté de l'aire de
--- minage, en tuiles), size (côté de l'emprise), energy_kw ; resources[].mining_time ; items[].fuel_value (J), type.
--- opts = { exec = { [entité] = vrai } (absente : toutes), exec_roles = { [rôle] = vrai }, mining_bonus, lab_bonus,
--- cat (catalogue K.build : son combustible), fuel (combustible imposé), fuel_ok (fonction ou ensemble : combustibles
--- qu'un exécutant sait apporter) }.
function Ca.data(dump, opts)
  opts = opts or {}
  local D = { recipes = {}, recipe_list = {}, producers = {}, hand = {}, hand_mine = {}, makers = {}, drills = {},
    labs = {}, res = {}, res_list = {}, packs = {}, item_of = {}, maker_by = {}, drill_by = {}, lab_by = {},
    unlocked_by = {}, fuel = opts.fuel, fuel_kj = 0, items = dump.items or {}, mil = {}, pumped = {},
    bonus = { mining = opts.mining_bonus or 0, lab = opts.lab_bonus or 0 } }
  local ents = {}
  for _, e in ipairs(dump.entities or {}) do ents[#ents + 1] = e end
  table.sort(ents, function(a, b) return a.name < b.name end)
  local function executable(e, role)
    if (opts.exec_roles or {})[role] then return true end
    if opts.exec == nil then return true end
    return opts.exec[e.name] == true
  end
  local hand_done = false
  for _, e in ipairs(ents) do
    local role = R.ENTITY_ROLE[e.type or ""]
    if role == "main" then
      if not hand_done then
        hand_done = true
        for _, c in ipairs(e.crafting_categories or {}) do D.hand[c] = true end
        for _, c in ipairs(e.resource_categories or {}) do D.hand_mine[c] = true end
      end
    elseif role == "pompe" then
      -- Lot RB-FLUIDE : le fluide qu'une pompe exécutable tire (eau d'une rive) : la force le sait produire, sans recette
      if e.fluid and e.item and executable(e, role) then D.pumped[e.fluid] = true end
    elseif e.item and (role == "fabrique" or role == "foreuse" or role == "labo") then
      D.item_of[e.name] = e.item
      local m = { name = e.name, item = e.item, speed = e.speed or 1, energy = e.energy or "none", kw = e.energy_kw or 0,
        size = e.size or 1, exec = executable(e, role), emit = e.emit or 0 }
      if role == "fabrique" then
        m.cat_list = sorted_copy(e.crafting_categories)
        m.cats = set_of(m.cat_list)
        D.makers[#D.makers + 1] = m
        D.maker_by[m.name] = m
      elseif role == "foreuse" then
        m.cat_list = sorted_copy(e.resource_categories)
        m.cats = set_of(m.cat_list)
        m.area = e.mining_area or m.size
        D.drills[#D.drills + 1] = m
        D.drill_by[m.name] = m
      else
        m.input_list = sorted_copy(e.lab_inputs)
        m.inputs = set_of(m.input_list)
        for _, p in ipairs(m.input_list) do D.packs[p] = true end
        D.labs[#D.labs + 1] = m
        D.lab_by[m.name] = m
      end
    end
  end
  -- Machine d'assemblage : une fabrique dont une catégorie est aussi celle de la main (elle remplace la main).
  for _, m in ipairs(D.makers) do
    m.assembler = false
    for _, c in ipairs(m.cat_list) do if D.hand[c] then m.assembler = true end end
  end
  -- Objets militaires (type du moteur) : jamais du stock investissable.
  for _, n in ipairs(sorted_keys(D.items)) do
    if R.ITEM_ROLE[D.items[n].type or ""] == "militaire" then D.mil[n] = true end
  end
  -- Ressources : chaque produit d'une ressource (entités dans l'ordre des noms ; le premier gagne).
  local rl = {}
  for _, r in ipairs(dump.resources or {}) do rl[#rl + 1] = r end
  table.sort(rl, function(a, b) return a.entity < b.entity end)
  for _, r in ipairs(rl) do
    for _, p in ipairs(r.products or {}) do
      if not D.res[p.name] then
        D.res[p.name] = { category = r.category, mining_time = r.mining_time or 1, fluid = p.type == "fluid",
          entity = r.entity }
      end
    end
  end
  D.res_list = sorted_keys(D.res)
  -- Technologies visibles et actives : ce qu'elles débloquent (la première dans l'ordre des noms).
  for _, t in ipairs(sorted_keys(dump.techs)) do
    local tt = dump.techs[t]
    if tt.enabled ~= false and not tt.hidden then
      for _, r in ipairs(tt.unlocks or {}) do if D.unlocked_by[r] == nil then D.unlocked_by[r] = t end end
    end
  end
  -- Recettes visibles, actives au départ ou débloquables.
  for _, name in ipairs(sorted_keys(dump.recipes)) do
    local r = dump.recipes[name]
    if not r.hidden and (r.enabled ~= false or D.unlocked_by[name]) then
      local ing, prod, fluid = {}, {}, false
      for _, i in ipairs(r.ingredients or {}) do
        ing[#ing + 1] = { name = i.name, amount = norm_amount(i), fluid = i.type == "fluid" }
        if i.type == "fluid" then fluid = true end
      end
      for _, p in ipairs(r.products or {}) do
        prod[#prod + 1] = { name = p.name, amount = norm_amount(p), fluid = p.type == "fluid" }
        if p.type == "fluid" then fluid = true end
      end
      table.sort(ing, function(a, b) return a.name < b.name end)
      table.sort(prod, function(a, b) return a.name < b.name end)
      D.recipes[name] = { name = name, category = r.category or "", energy = math.max(Ca.EPS, r.energy or 0.5),
        ingredients = ing, products = prod, fluid = fluid, enabled = r.enabled ~= false }
      D.recipe_list[#D.recipe_list + 1] = name
      for _, p in ipairs(prod) do
        if p.amount > 0 then
          D.producers[p.name] = D.producers[p.name] or {}
          local l = D.producers[p.name]
          l[#l + 1] = name
        end
      end
    end
  end
  -- Combustible : celui du catalogue (K.build, filtré par l'exécutant : F332, banc g1), sinon le produit d'une ressource
  -- extractible par un exécutant, au plus grand pouvoir calorifique, que opts.fuel_ok admet (égalité : le nom).
  if opts.fuel == nil and opts.cat ~= nil then D.fuel = opts.cat.fuel end
  if D.fuel == nil and opts.cat == nil then
    local fok = opts.fuel_ok
    local function fuel_ok(name)
      if fok == nil then return true end
      if type(fok) == "table" then return fok[name] == true end
      return fok(name) and true or false
    end
    local best, bv = nil, 0
    for _, name in ipairs(D.res_list) do
      local it = D.items[name]
      local v = it and it.fuel_value or 0
      local rs = D.res[name]
      local ok = D.hand_mine[rs.category] or false
      for _, d in ipairs(D.drills) do if d.exec and d.cats[rs.category] then ok = true end end
      if v > bv and ok and not rs.fluid and fuel_ok(name) then best, bv = name, v end
    end
    D.fuel = best
  end
  local fi = D.fuel and D.items[D.fuel]
  D.fuel_kj = fi and (fi.fuel_value or 0) / 1000 or 0
  D.mu, D.mu_recipe = Ca.values(D)
  -- Objets CONVERTIBLES en capital : les biens d'équipement (foreuses, fabriques, laboratoires) et la fermeture de leurs
  -- recettes. Le stock libre n'en compte pas d'autres (un coffre, une tourelle, une munition ne deviennent pas foreuse).
  local seeds = {}
  for _, m in ipairs(D.makers) do seeds[#seeds + 1] = m.item end
  for _, m in ipairs(D.drills) do seeds[#seeds + 1] = m.item end
  for _, m in ipairs(D.labs) do seeds[#seeds + 1] = m.item end
  D.convertible = Ca.closure(D, sorted_copy(seeds))
  -- Lot LEVIERS : modules, emplacements des machines, recherches à effet (relevé `dump.lv`, absent : aucun levier).
  D.lv = Lv.build(dump.lv, dump, D)
  return D
end

--- Lot VALEURS (5/11) : recettes qui DÉFONT exactement ce qu'une autre assemble : mêmes objets aux mêmes quantités, ingrédients
--- et produits échangés, et plus de sortes de produits que d'ingrédients (le vidage d'un contenant). Elles ne fixent aucun prix
--- (Ca.values) : le couple formerait un cycle où le coût partagé à parts égales entre les produits tire le prix d'un contenu
--- vers celui du contenu le moins cher passé par le même contenant (mesuré : gaz 0,05 MU par un fluide de 0,003 MU, au lieu de
--- 2,23 par sa recette). Un couple qui a autant de sortes des deux côtés garde ses deux recettes. Rend { [recette] = true }.
function Ca.unpackers(D)
  local function sig(list)
    local t = {}
    for _, x in ipairs(list) do t[#t + 1] = x.name .. "=" .. x.amount end
    table.sort(t)
    return table.concat(t, ",")
  end
  local fwd, out = {}, {}
  for _, rn in ipairs(D.recipe_list) do
    local r = D.recipes[rn]
    fwd[sig(r.ingredients) .. ">" .. sig(r.products)] = true
  end
  for _, rn in ipairs(D.recipe_list) do
    local r = D.recipes[rn]
    if #r.products > #r.ingredients and fwd[sig(r.products) .. ">" .. sig(r.ingredients)] then out[rn] = true end
  end
  return out
end

--- Lot TV-FLUX (G51 « le fluide se juge sur ses barils », docs/TODO_VIDEO.md l.228) : les CONTENANTS de fluide du jeu, lus dans les
--- recettes (aucun nom : anti-échelle). Un contenant est un objet B tel qu'une recette le VIDE (B -> fluide F en a unités + un objet E rendu)
--- ET qu'une recette le REMPLIT à l'identique (F en a unités + E -> B), à un seul fluide et un seul objet des deux côtés. Rend
--- { [fluide] = { { item = B, amount = a }, ... } } (contenants triés par nom ; un fluide peut en avoir plusieurs).
function Ca.barrels(D)
  if D.barrels_memo then return D.barrels_memo end
  local fill = {}
  for _, rn in ipairs(D.recipe_list) do
    local r = D.recipes[rn]
    if #r.ingredients == 2 and #r.products == 1 and not r.products[1].fluid then
      local fl, it
      for _, i in ipairs(r.ingredients) do if i.fluid then fl = i else it = i end end
      if fl and it then fill[fl.name .. "=" .. fl.amount .. "|" .. it.name .. "=" .. it.amount .. ">" .. r.products[1].name .. "=" .. r.products[1].amount] = true end
    end
  end
  local out, seen = {}, {}
  for _, rn in ipairs(D.recipe_list) do
    local r = D.recipes[rn]
    if #r.ingredients == 1 and #r.products == 2 and not r.ingredients[1].fluid then
      local b = r.ingredients[1]
      local fl, it
      for _, p in ipairs(r.products) do if p.fluid then fl = p else it = p end end
      if fl and it and fl.amount > 0 and fill[fl.name .. "=" .. fl.amount .. "|" .. it.name .. "=" .. it.amount .. ">" .. b.name .. "=" .. b.amount]
        and not seen[b.name] then
        seen[b.name] = true
        out[fl.name] = out[fl.name] or {}
        -- unités de fluide d'un contenant (b.amount contenants vidés rendent fl.amount unités)
        table.insert(out[fl.name], { item = b.name, amount = fl.amount / math.max(Ca.EPS, b.amount) })
      end
    end
  end
  for _, l in pairs(out) do table.sort(l, function(a, b) return a.item < b.item end) end
  D.barrels_memo = out
  return out
end

--- Stock de FLUIDE compté en contenants pleins (G51) : copie de `stock` où chaque fluide reçoit, en unités, ce que ses contenants au stock
--- tiennent. Un fluide qui a déjà une entrée la garde (l'ajout s'y ajoute). Rend (copie, { [fluide] = unités ajoutées }) ; sans contenant
--- au stock, rend `stock` lui-même (même table : la décision d'avant, à l'identique).
function Ca.barrel_stock(D, stock)
  local bar = Ca.barrels(D)
  local added, any = {}, false
  for _, fl in ipairs(sorted_keys(bar)) do
    local u = 0
    for _, c in ipairs(bar[fl]) do u = u + math.max(0, (stock or {})[c.item] or 0) * c.amount end
    if u > 0 then added[fl], any = u, true end
  end
  if not any then return stock or {}, added end
  local cp = {}
  for k, v in pairs(stock) do cp[k] = v end
  for fl, u in pairs(added) do cp[fl] = (cp[fl] or 0) + u end
  return cp, added
end

--- Valeur de chaque objet (MU) : point fixe min-plus sur les recettes (ordre des noms), jusqu'à stabilité (au plus une
--- passe par recette, plus une). Rend aussi la recette la moins chère de chaque objet. Les recettes de Ca.unpackers n'y
--- entrent pas.
function Ca.values(D)
  local mu, best = {}, {}
  local skip = Ca.unpackers(D)
  for _, name in ipairs(D.res_list) do mu[name] = Ca.RAW_MU * D.res[name].mining_time end
  for _ = 1, #D.recipe_list + 1 do
    local changed = false
    for _, rn in ipairs(D.recipe_list) do
      local r = D.recipes[rn]
      local input, ok = r.energy * Ca.TIME_MU, not skip[rn]
      for _, i in ipairs(r.ingredients) do
        local m = mu[i.name]
        if m == nil then ok = false break end
        input = input + m * i.amount
      end
      if ok then
        local tot = 0
        for _, p in ipairs(r.products) do tot = tot + p.amount end
        if tot > 0 then
          local unit = input / tot
          for _, p in ipairs(r.products) do
            if not D.res[p.name] and (mu[p.name] == nil or unit < mu[p.name] - 1e-12) then
              mu[p.name] = unit
              best[p.name] = rn
              changed = true
            end
          end
        end
      end
    end
    if not changed then break end
  end
  return mu, best
end

--- Valeur ajoutée d'un objet (MU par unité) par sa recette `rn` (ou sa recette la moins chère) ; ressource : sa MU.
function Ca.va(D, item, rn)
  if D.res[item] then return D.mu[item] or 0 end
  rn = rn or (D.mu_recipe or {})[item] or (D.producers[item] or {})[1]
  local r = rn and D.recipes[rn]
  if not r or not D.mu[item] then return 0 end
  local amt = amount_of(r.products, item)
  if amt <= 0 then return 0 end
  local input = 0
  for _, i in ipairs(r.ingredients) do
    local m = D.mu[i.name]
    if m == nil then return 0 end
    input = input + m * i.amount
  end
  return math.max(0, D.mu[item] - input / amt)
end

--- Débits unitaires (par minute).
function Ca.crafts_per_min(m, r) return 60 * (m.speed or 1) / math.max(Ca.EPS, r.energy) end
function Ca.out_per_min(m, r, item) return Ca.crafts_per_min(m, r) * amount_of(r.products, item) end
function Ca.in_per_min(m, r, item) return Ca.crafts_per_min(m, r) * amount_of(r.ingredients, item) end
function Ca.drill_per_min(D, d, item)
  local rs = D.res[item]
  return 60 * (d.speed or 1) * (1 + (D.bonus.mining or 0)) / math.max(Ca.EPS, rs and rs.mining_time or 1)
end
function Ca.lab_per_min(D, l) return 60 * (l.speed or 1) * (1 + (D.bonus.lab or 0)) end -- secondes de recherche / min
function Ca.fuel_per_min(D, m)
  if m.energy ~= "burner" or (D.fuel_kj or 0) <= 0 then return 0 end
  return (m.kw or 0) * 60 / D.fuel_kj
end

--- Peigne de foreuses (paires face à un tapis), géométrie lue sur la foreuse : emprise w, aire de minage a (côté).
--- Rend les tuiles de terrain par foreuse ((w + a + 1) × w ÷ 2) et les tuiles de minerai couvertes par foreuse
--- (min(terrain, a × w)). Foreuse électrique vanilla (3, 5) : 13,5 et 13,5 ; à combustion (2, 2) : 5 et 4.
function Ca.comb(d)
  local w = d.size or 1
  local a = math.max(d.area or w, w)
  local per = (w + a + 1) * w / 2
  return per, math.min(per, a * w)
end

--- Machines qu'une arrivée nourrit : x = (arrivée − consommation) ÷ consommation d'une machine ; ⌊x⌋ + [frac ≥ 0,9].
--- Contrôle DUR de la consigne « plus de fours dans la limite de ce qu'on peut faire fondre ».
function Ca.fed_max(supply, cons, kappa)
  if (kappa or 0) <= 0 then return 0 end
  local x = ((supply or 0) - (cons or 0)) / kappa
  if x <= 0 then return 0 end
  return math.floor(x + Ca.FRAC_UP)
end

--- Nombre de machines pour un manque : arrondi au-dessus dès une demi-machine (Ca.U_MIN %).
function Ca.count(def, unit)
  if (unit or 0) <= 0 or (def or 0) <= 0 then return 0 end
  return math.floor(def / unit + 1 - Ca.U_MIN / 100 + Ca.EPS)
end

--- Le même pour un GOULOT (couverture θ sous Ca.THETA_MIN ‰) : une machine dès le premier objet qui manque.
function Ca.count_for(def, unit, theta)
  local n = Ca.count(def, unit)
  if n == 0 and (def or 0) > Ca.EPS and (unit or 0) > 0 and theta ~= nil and theta * 1000 < Ca.THETA_MIN then n = 1 end
  return n
end

---------------------------------------------------------------------------------------------------
-- 2. Caractère, budget, prix du travail, croissance
---------------------------------------------------------------------------------------------------
--- s (‰ réinvesti), delta (‰ défense), alpha (‰ armée), tmax (min). Traits d'IA2-0 et poids d'IA2-a, pour mille.
--- Lot PRIORITE-RESSOURCES : `production_first` (le fer ne paie pas la défense ET la production, shared/team/priorite.lua) :
--- aucune part n'est prise pour la défense ni l'armée, tout le budget va à la production (« si on peut pas se l'acheter, on
--- investit les ressources dans la production de plus de ressources ») ; elles reviennent dès que le fer paie les deux.
function Ca.character(traits, weights, threat, production_first)
  local tr, w = traits or {}, weights or {}
  local amb = clamp(tr.ambition or 1000, 0, 2000)
  local agr = clamp(tr.agressivite or 1000, 0, 2000)
  local pru = clamp(tr.prudence or 1000, 1, 2000)
  local s = math.floor(Ca.S0 * amb / 1000 * (2000 - agr) / 1000 * (w.capital or 1000) / 1000)
  s = clamp(s, Ca.S_MIN, Ca.S_MAX)
  local delta = math.floor(Ca.D0 * pru / 1000 * (threat and 2 or 1) * (w.defense or 1000) / 1000)
  local alpha = math.floor(Ca.A0 * agr / 1000 * (w.armee or 1000) / 1000)
  if delta + alpha > Ca.SHARE_MAX then
    local k = Ca.SHARE_MAX / (delta + alpha)
    delta, alpha = math.floor(delta * k), math.floor(alpha * k)
  end
  if production_first then delta, alpha = 0, 0 end
  local tmax = clamp(Ca.T0 * amb / pru, Ca.T_MIN, Ca.T_MAX)
  if threat then tmax = tmax / Ca.THREAT_DIV end
  return { s = s, delta = delta, alpha = alpha, tmax = tmax }
end

--- Budget matières du cycle (MU). keep = (1000 − δ − α) ‰, appliqué au flux ET au stock (les parts de la défense et de
--- l'armée sont prises avant). Flux : s × Y × keep par minute, ÉPARGNÉ (bank) et plafonné à Ca.BANK_H minutes ; stock :
--- s × stock libre convertible × keep × Ca.STOCK_PCT %. Rend budget, épargne disponible ce cycle, part du stock.
function Ca.budget(ch, Y, free_mu, dt, bank, reserve)
  local keep = (1000 - ch.delta - ch.alpha) / 1000
  local per_min = ch.s / 1000 * (Y or 0) * keep
  local b = math.min(Ca.BANK_H * per_min, (bank or 0) + per_min * (dt or Ca.CYCLE_MIN))
  if b < 0 then b = 0 end
  local stock_part = ch.s / 1000 * (free_mu or 0) * keep * Ca.STOCK_PCT / 100
  -- Lot INDUSTRIE I1 : le besoin (défense, reconstruction, recrues, consommation prévue) est évalué et déjà retiré du stock libre ;
  -- ce qui reste s'investit sans pourcentage ni part de caractère (le flux garde s, δ et α).
  if reserve then stock_part = (free_mu or 0) * Ca.RESERVE_PCT / 100 end
  return b + stock_part, b, stock_part
end

--- Prix du travail (MU par PNJ-minute) : nul quand au moins un bras est libre, sinon la production par PNJ.
function Ca.labor_price(Y, workers, idle)
  if (idle or 0) >= 1 then return 0 end
  return (Y or 0) / math.max(1, workers or 1)
end

--- Croissance de la demande élastique (‰ par cycle) : s × dt ÷ (T̄ + délai de pose), T̄ = médiane des retours (de
--- CHAÎNE) acceptés, délai mesuré par le runtime (input.lag) ou Ca.T_LAG ; au plus Ca.G_MAX. dK/dt = K ÷ (T + délai) × s.
function Ca.growth(ch, st, elastic, dt, lag)
  if not elastic then return 0 end
  local tbar = median(st.T_hist or {}) or Ca.T_GROWTH0
  local den = math.max(Ca.EPS, tbar + (lag or Ca.T_LAG))
  return math.min(Ca.G_MAX, math.floor(ch.s * (dt or Ca.CYCLE_MIN) / den))
end

--- Valeur d'un but au cerveau : Ca.V_MAX à T = 0, Ca.V_MIN à T = T_max, décroissance rationnelle (aucun logarithme)
--- qui étale les retours courts : f = (T_max − T) ÷ (T_max + Ca.V_SHAPE × T).
function Ca.value(T, tmax)
  if not T or not tmax or tmax <= 0 then return Ca.V_MIN end
  local f = clamp((tmax - T) / (tmax + Ca.V_SHAPE * math.max(0, T)), 0, 1)
  return Ca.V_MIN + math.floor(Ca.V_SPAN * f + Ca.EPS)
end

---------------------------------------------------------------------------------------------------
-- 3. Disponibilité : recherché, exécutable, fabricable
---------------------------------------------------------------------------------------------------
function Ca.recipe_open(ctx, rn)
  local r = ctx.D.recipes[rn]
  if not r then return false end
  if r.enabled then return true end
  local t = ctx.D.unlocked_by[rn]
  return t ~= nil and ctx.techs[t] == true
end

--- Ressource connue de la faction (state.known ; absente : toutes).
function Ca.is_known(ctx, item) return ctx.known == nil or ctx.known[item] == true end

--- Objet obtenable : au stock, ressource connue et extractible, ou recette ouverte d'une catégorie faisable (main,
--- machine posée ou au stock) dont tous les ingrédients sont obtenables. Lot RB-FLUIDE : un FLUIDE entre dans la même règle. Une recette qui
--- demande ou rend un fluide reste obtenable quand la force sait produire chaque fluide qu'elle demande : un fluide est obtenable comme un
--- objet (ressource fluide connue et extractible par un exécutant ; fluide d'une pompe exécutable et connu ; ou recette ouverte d'une
--- catégorie présente dont les entrées sont obtenables). Avant le lot, TOUTE recette à fluide était écartée : le pack chimique (soufre et
--- plastique viennent du gaz de pétrole) était « non obtenable » même avec le site de pétrole fini. input.obtainable remplace ce calcul : une
--- FONCTION (objet -> booléen) ou une TABLE { [objet] = vrai } (en jeu : ev.feas d'IA-G, qui est une table).
function Ca.obtainable(ctx, item)
  local io = ctx.input.obtainable
  if type(io) == "table" then return io[item] == true end
  if io then return io(item) and true or false end
  local memo = ctx.obt
  if memo[item] ~= nil then return memo[item] end
  memo[item] = false -- garde contre un cycle de recettes
  local D = ctx.D
  local ok = (ctx.stock[item] or 0) > 0
  if not ok and D.res[item] then
    local rs = D.res[item]
    local ext = D.hand_mine[rs.category] or false
    for _, d in ipairs(D.drills) do if d.exec and d.cats[rs.category] then ext = true end end
    ok = Ca.is_known(ctx, item) and ext
  end
  if not ok and D.pumped[item] then ok = Ca.is_known(ctx, item) end
  if not ok then
    for _, rn in ipairs(D.producers[item] or {}) do
      local r = D.recipes[rn]
      if Ca.recipe_open(ctx, rn) and ctx.cats_present[r.category] then
        local all = true
        for _, i in ipairs(r.ingredients) do
          if not Ca.obtainable(ctx, i.name) then all = false break end
        end
        if all then ok = true break end
      end
    end
  end
  memo[item] = ok
  return ok
end

--- Machine disponible pour une construction neuve : un exécutant sait la poser, et l'objet qui la pose est au stock ou
--- recherché et fabricable (consigne du DC : « si assembleurs disponibles »).
function Ca.available(ctx, m)
  if not m.exec then return false end
  if (ctx.stock[m.item] or 0) > 0 then return true end
  local open = false
  for _, rn in ipairs(ctx.D.producers[m.item] or {}) do
    if Ca.recipe_open(ctx, rn) then open = true break end
  end
  return open and Ca.obtainable(ctx, m.item)
end

--- Meilleure fabrique disponible d'une catégorie : (MU + combustible sur Ca.H_FUEL) ÷ vitesse, égalité : le nom.
local function best_maker(ctx, cat)
  local c = ctx.best_m[cat]
  if c ~= nil then return c or nil end
  local D = ctx.D
  local best, bs = nil, nil
  for _, m in ipairs(D.makers) do
    if m.cats[cat] and D.mu[m.item] and Ca.available(ctx, m) then
      local s = (D.mu[m.item] + Ca.H_FUEL * Ca.fuel_per_min(D, m) * ctx.fuel_mu) / math.max(Ca.EPS, m.speed)
      if bs == nil or s < bs - 1e-12 then best, bs = m, s end
    end
  end
  ctx.best_m[cat] = best or false
  return best
end

--- Meilleure foreuse disponible d'une ressource : (MU + combustible) ÷ débit.
local function best_drill(ctx, item)
  local c = ctx.best_d[item]
  if c ~= nil then return c or nil end
  local D = ctx.D
  local rs = D.res[item]
  local best, bs = nil, nil
  -- Lot CAPIB : foreuse imposée par ressource (input.drill_for = { [ressource] = entité }) : celle que l'EXÉCUTANT de cette
  -- ressource sait poser (le runtime le déduit de ses exécutants ; ex. foreuses électriques là où une fonderie à foreuses
  -- existe, foreuses des avant-postes ailleurs). Absente : toutes les foreuses disponibles.
  local only = (ctx.input.drill_for or {})[item]
  for _, d in ipairs(D.drills) do
    if (only == nil or d.name == only) and d.cats[rs.category] and D.mu[d.item] and Ca.available(ctx, d) then
      local s = (D.mu[d.item] + Ca.H_FUEL * Ca.fuel_per_min(D, d) * ctx.fuel_mu) / math.max(Ca.EPS, Ca.drill_per_min(D, d, item))
      if bs == nil or s < bs - 1e-12 then best, bs = d, s end
    end
  end
  ctx.best_d[item] = best or false
  return best
end

--- Meilleur laboratoire disponible qui accepte tous les packs de la technologie `q` : MU ÷ vitesse.
local function best_lab(ctx, q)
  local D = ctx.D
  local best, bs = nil, nil
  for _, l in ipairs(D.labs) do
    local fits = true
    for _, p in ipairs((q and q.packs) or {}) do if not l.inputs[p[1]] then fits = false end end
    if fits and D.mu[l.item] and Ca.available(ctx, l) then
      local s = D.mu[l.item] / math.max(Ca.EPS, l.speed)
      if bs == nil or s < bs - 1e-12 then best, bs = l, s end
    end
  end
  return best
end

---------------------------------------------------------------------------------------------------
-- 4. Demande et besoin par objet
---------------------------------------------------------------------------------------------------
--- Recette choisie pour un objet : ouverte d'abord, faisable, sans fluide, de même nom que l'objet, à un seul produit,
--- puis le nom. Rend la recette ou nil et la raison (mémoïsée par décision).
local function choose_recipe(ctx, item)
  if Pf.excluded(ctx.input.excl, item) then return nil, Pf.excluded_why(item) end -- lot VIDEO-PLAFONDS (V99) : objet exclu, aucune recette
  local memo = ctx.rec_memo[item]
  if memo then return memo.r, memo.why end
  local D = ctx.D
  local best, bk = nil, nil
  for _, rn in ipairs(D.producers[item] or {}) do
    if Ca.recipe_open(ctx, rn) then
      local r = D.recipes[rn]
      local doable = D.hand[r.category] or ctx.cats_present[r.category] or best_maker(ctx, r.category) ~= nil
      local k = string.format("%d%d%d%d|%s", doable and 0 or 1, r.fluid and 1 or 0, rn == item and 0 or 1,
        #r.products > 1 and 1 or 0, rn)
      if bk == nil or k < bk then best, bk = r, k end
    end
  end
  local why = nil
  if not best then why = (D.producers[item] or {})[1] and "recette a rechercher" or "aucune recette" end
  ctx.rec_memo[item] = { r = best, why = why }
  return best, why
end

--- Lot VIDEO-L1b (Ca.RANG) : le même besoin que Ca.requirements, propagé dans l'ordre du RANG de la décision (shared/ai3/rang.lua,
--- Rg.chain sur la recette CHOISIE par choose_recipe), au lieu du parcours `visit` refait à chaque appel. Le rang est calculé une fois
--- par JEU DE GRAINES (ctx.rang ; refait quand une graine change, le combustible d'une machine décidée par exemple). Sans cycle :
--- même fermeture, même ordre, même liste, mêmes besoins au bit près (tests/rang_test.lua §9, tests/rang_cablage_test.lua). Un arc
--- INTERNE à un cycle (recette qui consomme son produit, Kovarex) n'est pas propagé : c'est l'amorce (ctx.rang.seed).
local function requirements_by_rank(ctx, fin)
  local seeds = sorted_keys(fin)
  local key = table.concat(seeds, "\n")
  local Rk = ctx.rang
  if Rk == nil or ctx.rang_key ~= key then
    Rk = Rg.chain(ctx.D, function(i) return choose_recipe(ctx, i) end, seeds)
    ctx.rang, ctx.rang_key, ctx.rang_deps = Rk, key, nil
  end
  local Rq, used_by = {}, {}
  for _, k in ipairs(seeds) do Rq[k] = fin[k] end
  for _, i in ipairs(Rk.order) do
    local r = Rk.rec[i]
    local net = (Rq[i] or 0) - (ctx.stock[i] or 0) / Ca.H_STOCK
    if r and net > 0 then
      local crafts = net / amount_of(r.products, i)
      local ci = Rk.cyc[i]
      for _, ing in ipairs(r.ingredients) do
        if ci == nil or Rk.cyc[ing.name] ~= ci then
          local x = crafts * ing.amount
          Rq[ing.name] = (Rq[ing.name] or 0) + x
          used_by[ing.name] = used_by[ing.name] or {}
          used_by[ing.name][i] = (used_by[ing.name][i] or 0) + x
        end
      end
    end
  end
  return { R = Rq, list = Rk.list, depth = Rk.rank, rec = Rk.rec, why = Rk.why, fin = fin, used_by = used_by }
end

--- Besoin par objet (objets/min) : la demande finale propagée dans le graphe des recettes. Rend { R, list (profondeur
--- croissante, puis le nom), depth, rec, why, fin, used_by = { [ingrédient] = { [objet] = /min } } }.
function Ca.requirements(ctx, plan)
  local D = ctx.D
  local fin = {}
  local function add(i, x) if i and x and x > 0 then fin[i] = (fin[i] or 0) + x end end
  for _, s in ipairs(ctx.sinks) do add(s.item, s.rate) end
  local need = ctx.input.need or {}
  for _, k in ipairs(sorted_keys(need)) do add(k, need[k] / Ca.H_GOALS) end
  for _, o in ipairs(ctx.open) do
    for _, it in ipairs(o.missing or {}) do add(it[1], it[2] / Ca.H_B) end
  end
  for _, it in ipairs(ctx.pack_rates) do add(it[1], it[2]) end
  if ctx.D.fuel and plan.burn > 0 then add(ctx.D.fuel, plan.burn) end
  if Ca.RANG then return requirements_by_rank(ctx, fin) end -- lot VIDEO-L1b (allumé à l'étape 8)
  local depth, rec, why, seen = {}, {}, {}, {}
  local items = {}
  local function visit(i)
    if seen[i] then return depth[i] or 0 end
    seen[i] = true
    depth[i] = 0
    items[#items + 1] = i
    if D.res[i] then return 0 end
    local r, w = choose_recipe(ctx, i)
    if not r then why[i] = w return 0 end
    if r.fluid then why[i] = "limite : fluide (" .. r.name .. ")" return 0 end
    rec[i] = r
    local best = 0
    for _, ing in ipairs(r.ingredients) do
      local di = visit(ing.name) + 1
      if di > best then best = di end
    end
    depth[i] = best
    return best
  end
  for _, k in ipairs(sorted_keys(fin)) do visit(k) end
  table.sort(items, function(a, b)
    if depth[a] ~= depth[b] then return depth[a] > depth[b] end
    return a < b
  end)
  local Rq, used_by = {}, {}
  for _, k in ipairs(sorted_keys(fin)) do Rq[k] = fin[k] end
  for _, i in ipairs(items) do
    local r = rec[i]
    -- Besoin NET propagé à l'amont : un stock qui dort couvre son débit pendant Ca.H_STOCK minutes (50 000 plaques au
    -- coffre ne demandent aucun minerai).
    local net = (Rq[i] or 0) - (ctx.stock[i] or 0) / Ca.H_STOCK
    if r and net > 0 then
      local crafts = net / amount_of(r.products, i)
      for _, ing in ipairs(r.ingredients) do
        local x = crafts * ing.amount
        Rq[ing.name] = (Rq[ing.name] or 0) + x
        used_by[ing.name] = used_by[ing.name] or {}
        used_by[ing.name][i] = (used_by[ing.name][i] or 0) + x
      end
    end
  end
  local list = {}
  for i = #items, 1, -1 do list[#list + 1] = items[i] end
  table.sort(list, function(a, b)
    if depth[a] ~= depth[b] then return depth[a] < depth[b] end
    return a < b
  end)
  return { R = Rq, list = list, depth = depth, rec = rec, why = why, fin = fin, used_by = used_by }
end

---------------------------------------------------------------------------------------------------
-- 5. Capital d'une chaîne : le retour d'un PROJET de chaîne, réparti sur ses étages
---------------------------------------------------------------------------------------------------
local function extras_mu(ctx, list)
  local c = 0
  for _, it in ipairs(list or {}) do c = c + (ctx.D.mu[it[1]] or 0) * it[2] end
  return c
end

--- Capital (MU par objet/min) de TOUTE la chaîne qui livre un objet de plus par minute : la machine (ou la foreuse)
--- choisie et ses pièces, plus le capital des ingrédients au prorata. Mémoïsé ; ctx.cs garde le capital du DERNIER
--- étage seul. Un étage sans machine (fait à la main) ne compte pour rien.
function Ca.chain_capital(ctx, item)
  local memo = ctx.cc
  if memo[item] ~= nil then return memo[item] end
  memo[item] = 0 -- garde contre un cycle de recettes
  local D = ctx.D
  local s, c = 0, 0
  if D.res[item] then
    local d = best_drill(ctx, item)
    if d then s = (D.mu[d.item] + extras_mu(ctx, ctx.input.drill_extra)) / math.max(Ca.EPS, Ca.drill_per_min(D, d, item)) end
    c = s
  else
    local r = choose_recipe(ctx, item)
    if r and not r.fluid then
      local amt = amount_of(r.products, item)
      local m = best_maker(ctx, r.category)
      if m and amt > 0 then
        s = (D.mu[m.item] + extras_mu(ctx, ctx.input.machine_extra)) / math.max(Ca.EPS, Ca.out_per_min(m, r, item))
      end
      c = s
      if amt > 0 then
        for _, ing in ipairs(r.ingredients) do
          if not ing.fluid then c = c + ing.amount / amt * Ca.chain_capital(ctx, ing.name) end
        end
      end
    end
  end
  memo[item] = c
  ctx.cs[item] = s
  return c
end

--- Part du dernier étage dans le capital de la chaîne (0 à 1) : la valeur d'un objet au puits se répartit sur les étages
--- au prorata de leur capital ; chaque étage plein a alors le retour du projet entier (capital de la chaîne ÷ valeur).
function Ca.share(ctx, item)
  local c = Ca.chain_capital(ctx, item)
  if c <= Ca.EPS then return 1 end
  return clamp((ctx.cs[item] or 0) / c, 0, 1)
end

---------------------------------------------------------------------------------------------------
-- 6. Plan : capacités posées, ouvertes et décidées
---------------------------------------------------------------------------------------------------
local function add_machines(ctx, plan, m, r, n, where, fs, fp)
  if not (m and r) or (n or 0) <= 0 then return end
  local cpm = Ca.crafts_per_min(m, r) * n * (fs or 1) -- fs : facteur de vitesse des modules posés (lot LEVIERS)
  for _, p in ipairs(r.products) do plan.N[p.name] = (plan.N[p.name] or 0) + cpm * p.amount * (fp or 1) end
  if where == nil or where == Ca.HQ then
    for _, i in ipairs(r.ingredients) do
      plan.cons[i.name] = (plan.cons[i.name] or 0) + cpm * i.amount
      plan.cons_by[i.name] = plan.cons_by[i.name] or {}
      for _, p in ipairs(r.products) do
        plan.cons_by[i.name][p.name] = (plan.cons_by[i.name][p.name] or 0) + cpm * i.amount
      end
    end
  end
  plan.burn = plan.burn + n * Ca.fuel_per_min(ctx.D, m)
  if m.energy == "electric" then plan.kw_used = plan.kw_used + n * (m.kw or 0) end
end

local function add_drills(ctx, plan, d, item, n, dep, count_cover, mult)
  if not d or (n or 0) <= 0 or not ctx.D.res[item] then return end
  local key = dep ~= nil and tostring(dep) or nil
  if key and plan.dead[key] then return end -- gisement épuisé : ses foreuses ne livrent plus rien
  local rate = n * Ca.drill_per_min(ctx.D, d, item) * (mult or 1) -- mult : modules posés (lot LEVIERS)
  plan.N[item] = (plan.N[item] or 0) + rate
  if key then
    plan.drills_on[key] = (plan.drills_on[key] or 0) + n
    if count_cover then
      local _, cov = Ca.comb(d)
      plan.cover[key] = (plan.cover[key] or 0) + n * cov
    end
  end
  plan.burn = plan.burn + n * Ca.fuel_per_min(ctx.D, d)
  if d.energy == "electric" then plan.kw_used = plan.kw_used + n * (d.kw or 0) end
end

local function add_labs(ctx, plan, l, n)
  if not l or (n or 0) <= 0 then return end
  local rate = Ca.lab_per_min(ctx.D, l) * n
  plan.labs = plan.labs + n
  plan.lab_cap = plan.lab_cap + rate
  for _, p in ipairs(sorted_keys(ctx.mix)) do plan.cons[p] = (plan.cons[p] or 0) + rate * ctx.mix[p] end
  if l.energy == "electric" then plan.kw_used = plan.kw_used + n * (l.kw or 0) end
end

--- Applique un ordre (ouvert ou décidé) au plan : capacité, consommation, couverture, combustible, courant. Un ordre
--- OUVERT s'applique pour son reste à poser (n_left, smelt_left ; absents : n, smelt_n) : ce qui est posé est déjà dans
--- machines, drills, labs.
--- Lot TV-ENERGIE (W02) : l'amorçage (relevé { amorce = true }) ne laisse passer qu'UN ordre électrique par décision : celui qui fait demander
--- la centrale. Un ordre électrique (foreuse, four sur place ou machine de fabrication à énergie électrique) consomme l'amorce ; ensuite
--- plan.amorce_left vaut 0 et toute l'électrique est refusée comme sous un relevé fermé. Appelée par Ca.apply (ordres ouverts compris).
function Ca.spend_amorce(ctx, plan, o)
  if (plan.amorce_left or 0) <= 0 then return end
  local D = ctx.D
  local k = o.kind
  local electric = false
  if k == "couvrir" or k == "ouvrir" then
    local d = D.drill_by[o.entity]
    local m = D.maker_by[o.smelt_entity]
    electric = (d ~= nil and d.energy == "electric") or (m ~= nil and (o.smelt_left or o.smelt_n or 0) > 0 and m.energy == "electric")
  elseif k == "fours" or k == "chaine" or k == "packs" then
    local m = D.maker_by[o.entity]
    electric = m ~= nil and m.energy == "electric"
  end
  if electric then plan.amorce_left = 0 end
end

--- Lot COURANT-LIBRE (partie neuve 0.6.70, journal INTEG-0670 : « 1800 kW pris sur 1800 kW » pendant 30 min, production 0 kW) : reste à poser,
--- EN FOREUSES, d'un ordre de CHAMP. Le champ pose UNE bande (n foreuses voulues) et l'ordre ne finit qu'à la première production de la bande ;
--- n_left restait n tout ce temps. Or les foreuses déjà posées sont comptées ailleurs (relevé des machines : capacité et couverture ; mesure
--- du courant : kw_used), donc l'ordre les comptait DEUX fois, et les kW qu'il réservait ne se libéraient jamais quand la centrale ne tournait pas.
--- total : foreuses du projet de la bande (nil : projet pas encore au plan, tout reste à poser) ; built : foreuses posées.
function Ca.champ_left(n, total, built)
  n = math.max(0, n or 0)
  if type(total) ~= "number" or total <= 0 then return n end
  return math.max(0, math.min(n, total - math.max(0, built or 0)))
end

--- Raison écrite du refus d'une option électrique, ou nil : relevé fermé / sans capacité (Pf.power_why), ou amorce déjà prise par un ordre
--- de cette décision (lot TV-ENERGIE, W02).
function Ca.power_refusal(ctx, plan)
  local pw = ctx.input.power
  local why = Pf.power_why(pw)
  if why then return why end
  if pw and pw.amorce and (plan.amorce_left or 0) <= 0 then
    return "courant : amorcage : le premier ordre electrique de la decision fait demander la centrale, les autres attendent qu'elle soit finie"
  end
  return nil
end

--- Lot TV-ENERGIE (diagnostic azure, 8/11) : le refus de courant d'une centrale FINIE dit la vérité. Avant, « courant insuffisant (aucune centrale
--- possible) » alors qu'une centrale de 1 800 kW tournait : les kW étaient pris (ordres de la même décision, chantiers), pas la centrale absente.
--- Rend « courant insuffisant : <pris> kW pris sur <capacité> kW (reste <reste>, il en faut <kw>) ».
function Ca.kw_refusal(plan, kw)
  local have, used = plan.kw_have or 0, plan.kw_used or 0
  -- aucune capacité du tout (centrale absente, sans machine vivante) : c'est bien « aucune centrale possible »
  if have <= 0 then return "courant insuffisant (aucune centrale possible : 0 kW de capacite)" end
  return string.format("courant insuffisant : %d kW pris sur %d kW (reste %d, il en faut %d)", math.floor(used + 0.5), math.floor(have + 0.5),
    math.max(0, math.floor(have - used + 0.5)), math.floor((kw or 0) + 0.5))
end

function Ca.apply(ctx, plan, o)
  local D = ctx.D
  local k = o.kind
  local n = o.n_left or o.n
  Ca.spend_amorce(ctx, plan, o)
  if k == "couvrir" or k == "ouvrir" then
    add_drills(ctx, plan, D.drill_by[o.entity], o.resource, n, o.deposit, true)
    local sn = o.smelt_left or o.smelt_n
    if (sn or 0) > 0 then
      add_machines(ctx, plan, D.maker_by[o.smelt_entity], D.recipes[o.smelt_recipe], sn, o.deposit)
    end
    if k == "ouvrir" and o.deposit ~= nil then plan.opened[tostring(o.deposit)] = true end
  elseif k == "fours" or k == "chaine" or k == "packs" then
    add_machines(ctx, plan, D.maker_by[o.entity], D.recipes[o.recipe], n, o.where or Ca.HQ)
  elseif k == "labos" then
    add_labs(ctx, plan, D.lab_by[o.entity], n)
  elseif k == "energie" then
    plan.kw_have = plan.kw_have + (o.kw_left or o.kw or 0)
  elseif k == "equiper" or k == "techno" then
    Lv.apply(ctx, plan, o) -- lot LEVIERS
  end
  if o.key then plan.taken[o.key] = true end
end

--- Clé déjà prise (ordre ouvert ou décidé dans ce cycle) : un seul ordre ouvert par clé.
function Ca.taken(plan, key) return plan.taken[key] == true end

--- Lot VIDEO-L5 : part CONFIRMÉE d'un groupe posé (n_cap ÷ n, relevé du runtime) ; 1 sans relevé de confirmation (input.hold
--- absent, ou groupe sans n_cap : la capacité reste comptée à la pose, comme avant). Ne pèse que sur la CAPACITÉ (plan.N, plan.K) :
--- consommation, combustible et courant restent comptés sur n (une machine sans courant tire encore dans le plan).
function Ca.cap_factor(ctx, g)
  if ctx.input.hold == nil or g.n_cap == nil or (g.n or 0) <= 0 then return 1 end
  return clamp(g.n_cap / g.n, 0, 1)
end

--- Lot VIDEO-L13 : débit d'un ordre ouvert d'une sorte plafonnée, pour son reste à poser (n_left ; le posé est déjà relevé).
local function open_cap(plan, o)
  if not (Ca.CAPPED[o.kind] and o.item) then return end
  local n, left = o.n or 0, o.n_left or o.n or 0
  local rate = (type(o.rate) == "number" and n > 0) and o.rate * left / n or 0
  plan.O[o.item] = (plan.O[o.item] or 0) + rate
  plan.NO[o.item] = (plan.NO[o.item] or 0) + left
end

local function new_plan(ctx)
  local D = ctx.D
  local plan = { N = {}, cons = {}, cons_by = {}, burn = 0, cover = {}, opened = {}, dead = {},
    drills_on = {}, labs = 0, lab_cap = 0, kw_used = 0, kw_have = 0, amorce_left = 0, taken = {}, K = 0, hand = {},
    -- lot VIDEO-L13 : posé NOMINAL de tous les états (P débit, NP nombre) et ordres ouverts (O, NO), par objet
    P = {}, NP = {}, O = {}, NO = {} }
  -- La MAIN n'est pas du capital (consigne du DC : « ils craftent beaucoup à la main ») : elle nourrit les machines
  -- aujourd'hui (couverture d'un ingrédient), mais le manque d'un objet se compte sans elle.
  for _, k in ipairs(sorted_keys(ctx.flows)) do
    local h = ctx.flows[k].hand or 0
    if h > 0 then
      plan.hand[k] = h
      if Ca.HAND_CAPITAL > 0 then plan.N[k] = (plan.N[k] or 0) + h * Ca.HAND_CAPITAL end
    end
  end
  -- Couverture mesurée par le runtime (tuiles sous une foreuse) quand elle est donnée ; sinon calculée. Un gisement dont
  -- la quantité est CONNUE et nulle est épuisé (amount absent : inconnu, jamais épuisé).
  local measured = {}
  for _, f in ipairs(ctx.deposits) do
    local key = tostring(f.id)
    if f.amount ~= nil and f.amount <= 0 then plan.dead[key] = true end
    if f.covered ~= nil then
      plan.cover[key] = f.covered
      measured[key] = true
    end
    if f.open then plan.opened[key] = true end
  end
  for _, m in ipairs(ctx.machines) do
    local mm, r = D.maker_by[m.entity], D.recipes[m.recipe]
    local fs, fp = Lv.factors(D, m)
    local fc = Ca.cap_factor(ctx, m) -- lot VIDEO-L5 (1 exactement sans relevé : mêmes flottants qu'avant)
    add_machines(ctx, plan, mm, r, m.n, m.where, fs, fp * fc)
    if mm and r then
      for _, p in ipairs(r.products) do
        plan.K = plan.K + Ca.crafts_per_min(mm, r) * m.n * fs * fp * fc * p.amount * Ca.va(D, p.name, r.name)
        plan.P[p.name] = (plan.P[p.name] or 0) + Ca.crafts_per_min(mm, r) * m.n * fs * p.amount * fp
        plan.NP[p.name] = (plan.NP[p.name] or 0) + m.n
      end
    end
  end
  for _, d in ipairs(ctx.drills_in) do
    local dd = D.drill_by[d.entity]
    local key = d.deposit ~= nil and tostring(d.deposit) or nil
    local fs, fp = Lv.factors(D, d)
    local fc = Ca.cap_factor(ctx, d)
    add_drills(ctx, plan, dd, d.resource, d.n, d.deposit, not (key and measured[key]), fs * fp * fc)
    if key then plan.opened[key] = true end
    if dd and D.res[d.resource] and not (key and plan.dead[key]) then
      plan.K = plan.K + d.n * fs * fp * fc * Ca.drill_per_min(D, dd, d.resource) * (D.mu[d.resource] or 0)
      plan.P[d.resource] = (plan.P[d.resource] or 0) + d.n * Ca.drill_per_min(D, dd, d.resource) * fs * fp
      plan.NP[d.resource] = (plan.NP[d.resource] or 0) + d.n
    end
  end
  for _, l in ipairs(ctx.labs_in) do
    local ll = D.lab_by[l.entity]
    add_labs(ctx, plan, ll, l.n)
    if ll then plan.K = plan.K + l.n * Ca.lab_per_min(D, ll) * Ca.TIME_MU end
  end
  local pw = ctx.input.power
  if pw then
    plan.kw_have = pw.have_kw or 0
    plan.amorce_left = pw.amorce and 1 or 0 -- lot TV-ENERGIE (W02) : sans centrale finie, UN ordre électrique par décision (Ca.spend_amorce)
    plan.kw_nominal = plan.kw_used -- étape 5a de VIDEO-INTEG : somme nominale des machines relevées (journal, comparée à used_kw)
    if pw.used_kw then plan.kw_used = pw.used_kw end
  end
  plan.lab_cap0 = plan.lab_cap
  for _, o in ipairs(ctx.open) do
    Ca.apply(ctx, plan, o)
    open_cap(plan, o)
  end
  -- Lot LEVIERS : clés que l'exécutant a refusées (input.skip = { [clé] = vrai }) : jamais réémises tant qu'elles y sont.
  for k, v in pairs(ctx.input.skip or {}) do if v then plan.taken[k] = true end end
  return plan
end

---------------------------------------------------------------------------------------------------
-- 7. Préparation d'un cycle
---------------------------------------------------------------------------------------------------
--- Objet convertible en capital (stock libre investissable).
function Ca.convertible(ctx, item)
  return (ctx.D.convertible[item] or ctx.conv_extra[item]) and not ctx.D.mil[item] and not ctx.sink_set[item]
end

--- Arrivée de minerai qui DIMENSIONNE des fours : ce que livrent les foreuses (mesuré, `made` moins `hand`) ; ni la
--- main (elle cessera), ni le stock (une tâche ponctuelle le fond, pas un capital permanent).
function Ca.supply_of(ctx, item)
  local f = ctx.flows[item] or {}
  return math.max(0, (f.made or 0) - (f.hand or 0))
end

local function prepare(input, st)
  local D = input.data
  local state = input.state or {}
  -- Lot TV-FLUX (G51) : un fluide se juge sur ses contenants pleins au stock (input.barils : réglage allumé ; absent : le stock d'avant)
  local jstock, barils_added = input.stock or {}, nil
  if input.barils then jstock, barils_added = Ca.barrel_stock(D, jstock) end
  if barils_added and next(barils_added) == nil then barils_added = nil end
  local ctx = { D = D, st = st, input = input, stock = jstock, barils_added = barils_added, flows = input.flows or {},
    techs = state.techs or {}, known = state.known, obt = {}, best_m = {}, best_d = {}, refus = {}, explore = {},
    dt = input.dt or Ca.CYCLE_MIN, threat = input.threat and true or false, power_block = {}, rec_memo = {}, cc = {},
    cs = {}, ds = {},
    -- Lot PREVISION (C12, arbitrage du DC « oui, compter la défense ») : prix de la défense induite, en MU par pollution/min de
    -- plus (shared/ai3/prevision.lua, Pv.defense_price ; nil : aucun nid connu ne reçoit notre pollution, ou prévision coupée).
    def_price = input.defense and input.defense.price or nil,
    -- Lot INDUSTRIE I1 : stock hors besoin ({ free = { [objet] = n } }, shared/ai3/reserve.lua) ; jamais sous menace du QG (la règle
    -- d'avant s'applique en entier).
    reserve = (not input.threat) and input.reserve or nil }
  Lv.prepare(ctx)
  ctx.ch = Ca.character(input.traits, input.weights, ctx.threat, input.production_first)
  local w = input.weights or {}
  ctx.w_cap = (w.capital or 1000) / 1000
  ctx.w_rech = (w.recherche or 1000) / 1000
  ctx.machines = sort_by(input.machines, function(m)
    return tostring(m.entity) .. "|" .. tostring(m.recipe) .. "|" .. tostring(m.where) .. "|" .. tostring(m.n) .. "|"
      .. tostring(m.sig) end)
  ctx.drills_in = sort_by(input.drills, function(d)
    return tostring(d.entity) .. "|" .. tostring(d.resource) .. "|" .. tostring(d.deposit) .. "|" .. tostring(d.n) .. "|"
      .. tostring(d.sig) end)
  ctx.labs_in = sort_by(input.labs, function(l) return tostring(l.entity) .. "|" .. tostring(l.n) end)
  ctx.deposits = sort_by(input.deposits, function(f) return tostring(f.id) end)
  ctx.open = sort_by(input.open, function(o)
    return tostring(o.key) .. "|" .. tostring(o.n) .. "|" .. tostring(o.n_left) .. "|" .. tostring(o.work_left) end)
  -- Gisements indexés par ressource (une fois par décision).
  ctx.dep_by_res = {}
  for _, f in ipairs(ctx.deposits) do
    local l = ctx.dep_by_res[f.resource or ""] or {}
    l[#l + 1] = f
    ctx.dep_by_res[f.resource or ""] = l
  end
  ctx.fuel_mu = (D.fuel and D.mu[D.fuel]) or 0
  -- Catégories faisables aujourd'hui : la main, les machines posées ou au stock.
  ctx.cats_present = {}
  for _, c in ipairs(sorted_keys(D.hand)) do ctx.cats_present[c] = true end
  local placed = {}
  for _, m in ipairs(ctx.machines) do placed[m.entity] = true end
  for _, m in ipairs(D.makers) do
    if placed[m.name] or (ctx.stock[m.item] or 0) > 0 then
      for _, c in ipairs(m.cat_list) do ctx.cats_present[c] = true end
    end
  end
  -- Pièces de l'exécutant (convertibles elles aussi).
  local seeds = {}
  for _, l in ipairs({ input.site_items, input.drill_extra, input.machine_extra, (input.power and input.power.plant or {}).items }) do
    for _, it in ipairs(l or {}) do seeds[#seeds + 1] = it[1] end
  end
  ctx.conv_extra = Ca.closure(D, sorted_copy(seeds))
  -- Production mesurée (MU/min) : valeur ajoutée de ce qui a été fait.
  local rs = input.research or {}
  local Y = 0
  for _, k in ipairs(sorted_keys(ctx.flows)) do Y = Y + (ctx.flows[k].made or 0) * Ca.va(D, k) end
  Y = Y + (rs.rate or 0) * Ca.TIME_MU
  ctx.Y = Y
  ctx.lambda = Ca.labor_price(Y, input.workers, input.idle)
  -- Lot C2 : le PUITS OUVERT (shared/ai3/demande.lua). Le stock hors besoin d'I1 qui dort (au-delà de 2 fois le besoin évalué) devient une
  -- demande : un débit visé en plus de la consommation, qui croît tant que le stock dort. Allumé par input.demande (jamais sous menace ni
  -- sans le besoin évalué : sinon la règle d'avant, ligne pour ligne).
  local sinks_in = input.sinks or {}
  ctx.dm = nil
  if input.demande and ctx.reserve then
    local stock_mu, free_mu = 0, 0
    for _, k in ipairs(sorted_keys(ctx.stock)) do
      local m = D.mu[k]
      if m and (D.convertible[k] or ctx.conv_extra[k]) and not D.mil[k] then
        local have = ctx.stock[k] or 0
        stock_mu = stock_mu + have * m
        free_mu = free_mu + math.min(have, (ctx.reserve.free or {})[k] or 0) * m
      end
    end
    local research = false
    for _, q in ipairs(rs.queue or {}) do if (q.left or 0) > 0 then research = true break end end
    st.dm = st.dm or Dm.new()
    ctx.dm = Dm.step(st.dm, { stock_mu = stock_mu, free_mu = free_mu, Y = Y, sleep = input.demande_sleep,
      cands = Dm.candidates(D, function(i) return Ca.obtainable(ctx, i) end), research = research })
    if #ctx.dm.sinks > 0 then
      local merged = {}
      for _, s in ipairs(sinks_in) do merged[#merged + 1] = s end
      for _, s in ipairs(ctx.dm.sinks) do merged[#merged + 1] = s end
      sinks_in = merged
    end
  end
  -- Puits AGRÉGÉS par objet (débits sommés dans un ordre fixe, élastique si l'un l'est) : deux puits du même objet ne
  -- dépendent plus de l'ordre d'entrée.
  local agg = {}
  for _, s in ipairs(sinks_in) do
    if s.item ~= nil and not Pf.excluded(input.excl, s.item) then -- lot VIDEO-PLAFONDS (V99) : un objet exclu n'est aucun puits
      local a = agg[s.item] or { rates = {}, elastic = false }
      a.rates[#a.rates + 1] = math.max(s.rate or 0, s.want or 0)
      if s.elastic then a.elastic = true end
      agg[s.item] = a
    end
  end
  ctx.sink_set = {}
  for _, k in ipairs(sorted_keys(agg)) do ctx.sink_set[k] = true end
  -- Croissance : puits élastiques (recherche restante, puits marqués).
  local queue = rs.queue or {}
  local Ls = 0
  for _, q in ipairs(queue) do Ls = Ls + (q.left or 0) * (q.time or 1) end
  local elastic = Ls > 0
  for _, k in ipairs(sorted_keys(agg)) do if agg[k].elastic then elastic = true end end
  ctx.g = Ca.growth(ctx.ch, st, elastic, ctx.dt, input.lag)
  local gf = (1000 + ctx.g) / 1000
  st.sink_t = st.sink_t or {}
  ctx.sinks = {}
  for _, k in ipairs(sorted_keys(agg)) do
    local rate = fsum(agg[k].rates)
    if agg[k].elastic and rate > 0 then
      local prev = st.sink_t[k] or rate
      local t = math.min(prev * gf, Ca.LEAD * rate)
      if t < rate then t = rate end
      st.sink_t[k] = t
      rate = t
    end
    ctx.sinks[#ctx.sinks + 1] = { item = k, rate = rate, elastic = agg[k].elastic }
  end
  -- Recherche visée (secondes de laboratoire par minute) : elle grandit de g par cycle, jamais plus de Ca.LEAD fois
  -- ce qui tourne, jamais plus que la file en Ca.H_R.
  ctx.lab = best_lab(ctx, queue[1])
  ctx.lab_rate = ctx.lab and Ca.lab_per_min(D, ctx.lab) or 0
  local cap0 = 0
  for _, l in ipairs(ctx.labs_in) do
    local ll = D.lab_by[l.entity]
    if ll then cap0 = cap0 + l.n * Ca.lab_per_min(D, ll) end
  end
  local u_meas = rs.rate or 0
  local u_star = 0
  if Ls > 0 and ctx.lab_rate > 0 then
    local want_q = Ls / Ca.H_R
    local grown = math.max(ctx.lab_rate, (st.u_target or 0) * gf)
    local lead = Ca.LEAD * math.max(ctx.lab_rate, u_meas, cap0)
    u_star = math.min(want_q, grown, lead)
    if u_star < math.min(want_q, u_meas) then u_star = math.min(want_q, u_meas) end
  end
  st.u_target = u_star
  ctx.u_star, ctx.u_meas, ctx.Ls, ctx.cap0 = u_star, u_meas, Ls, cap0
  -- Mélange des packs (par seconde de laboratoire) : la recherche visée répartie sur la file, dans son ordre.
  ctx.mix, ctx.pack_rates = {}, {}
  if u_star > 0 then
    local left = u_star * Ca.H_R
    local tot = {}
    for _, q in ipairs(queue) do
      if left <= 0 then break end
      local qt = q.time or 1
      local x = math.min(left, (q.left or 0) * qt)
      for _, p in ipairs(q.packs or {}) do tot[p[1]] = (tot[p[1]] or 0) + x * p[2] / qt end
      left = left - x
    end
    for _, p in ipairs(sorted_keys(tot)) do
      ctx.mix[p] = tot[p] / (u_star * Ca.H_R)
      ctx.pack_rates[#ctx.pack_rates + 1] = { p, tot[p] / Ca.H_R }
    end
  end
  -- Valeur d'une seconde de recherche : ses packs et son temps de laboratoire.
  ctx.lab_mu = Ca.TIME_MU
  for _, p in ipairs(sorted_keys(ctx.mix)) do ctx.lab_mu = ctx.lab_mu + ctx.mix[p] * (D.mu[p] or 0) end
  -- Bras.
  ctx.labor_limited = input.workers ~= nil
  if ctx.labor_limited then
    local hands = math.max(Ca.HANDS_MIN, math.floor(input.idle or 0) + (input.can_grow and Ca.SPARE or 0))
    local open_w = 0
    for _, o in ipairs(ctx.open) do open_w = open_w + (o.work_left or 0) end
    ctx.labor = math.max(0, hands * 60 * Ca.LABOR_H - open_w)
  else
    ctx.labor = math.huge
  end
  return ctx
end

--- Part du dernier étage de la RECHERCHE (le laboratoire) dans le capital de toute sa chaîne (packs compris).
local function lab_share(ctx)
  if ctx.lab_sh ~= nil then return ctx.lab_sh end
  local D = ctx.D
  local c_lab = (D.mu[ctx.lab.item] or 0) / math.max(Ca.EPS, ctx.lab_rate)
  local c = c_lab
  for _, p in ipairs(sorted_keys(ctx.mix)) do c = c + ctx.mix[p] * Ca.chain_capital(ctx, p) end
  ctx.lab_sh = c > Ca.EPS and clamp(c_lab / c, 0, 1) or 1
  return ctx.lab_sh
end

---------------------------------------------------------------------------------------------------
-- 8. Options
---------------------------------------------------------------------------------------------------
local function refuse(ctx, key, kind, item, why)
  ctx.refus[key] = { key = key, kind = kind, item = item, why = why } -- la dernière raison (état final du plan)
end

--- Matières (MU) d'une liste { {objet, n} } ; nil si un objet n'a pas de valeur (impayable).
local function items_mu(ctx, items)
  local c = 0
  for _, it in ipairs(items) do
    local m = ctx.D.mu[it[1]]
    if m == nil then return nil, it[1] end
    c = c + m * it[2]
  end
  return c
end

--- Travail (PNJ-s) : pose, allers-retours de chantier, fabrication à la main de ce qui manque au stock (un niveau).
local function work_of(ctx, items, dist)
  local D = ctx.D
  local n_ent = 0
  local craft = 0
  for _, it in ipairs(items) do
    n_ent = n_ent + it[2]
    local miss = math.max(0, it[2] - (ctx.stock[it[1]] or 0))
    if miss > 0 then
      local rn = (D.producers[it[1]] or {})[1]
      local r = rn and D.recipes[rn]
      if r and D.hand[r.category] then craft = craft + miss * r.energy / math.max(Ca.EPS, amount_of(r.products, it[1])) end
    end
  end
  return n_ent * Ca.POSE_S + math.ceil(n_ent / Ca.BATCH) * (2 * (dist or Ca.DIST) / Ca.WALK + Ca.HANDLE_S) + craft
end

--- Lot PREVISION (C12) : pollution/min qu'un ordre AJOUTE (machines du relevé, à pleine marche), selon son genre (même lecture
--- que Ca.apply) ; 0 pour un levier sans machine (courant, modules, recherche).
function Ca.option_emit(ctx, o)
  local D = ctx.D
  local k = o.kind
  local n = o.n_left or o.n or 0
  local e = 0
  if k == "couvrir" or k == "ouvrir" then
    local d = D.drill_by[o.entity]
    e = e + n * ((d and d.emit) or 0)
    local sn = o.smelt_left or o.smelt_n or 0
    local m = o.smelt_entity and D.maker_by[o.smelt_entity]
    e = e + sn * ((m and m.emit) or 0)
  elseif k == "fours" or k == "chaine" or k == "packs" then
    local m = D.maker_by[o.entity]
    e = e + n * ((m and m.emit) or 0)
  elseif k == "labos" then
    local l = D.lab_by[o.entity]
    e = e + n * ((l and l.emit) or 0)
  end
  return e
end

--- Intégration 0.6.28 (GISEMENTS × PILE-BUDGET) : input.starved = matières en manque par rapport au besoin ou d'un cadre ouvert de la
--- pile. La pile les laisse passer (Pi.porte) : la menace ne les ferme pas non plus (le `danger` de chaque gisement reste exclu).
local function starved_in(ctx, item)
  local sv = ctx.input and ctx.input.starved
  return sv ~= nil and item ~= nil and sv[item] == true
end

--- Termine une option : coût, retour, valeur ; rend l'option ou nil (refus écrit). `tmax` : retour accepté (le caractère
--- par défaut ; lot LEVIERS : plus long quand l'extraction n'a plus aucune option, Lv.REPLI_TMAX).
local function finish(ctx, o, tmax)
  tmax = tmax or ctx.ch.tmax
  -- Lot C2 : un stock qui dort n'a aucun coût d'opportunité : le retour accepté couvre la durée de son sommeil (shared/ai3/demande.lua).
  if ctx.dm then tmax = Dm.tmax(tmax, ctx.dm.tmax_sleep) end
  if ctx.threat and starved_in(ctx, o.item) then tmax = tmax * Ca.THREAT_DIV end -- (sans cela, ouverte mais refusée « retour > Tmax ÷ 4 »)
  if o.cost_m == nil then
    refuse(ctx, o.key, o.kind, o.item, "impayable : " .. tostring(o.unpaid))
    return nil
  end
  o.cost = o.cost_m + ctx.lambda * (o.work or 0) / 60
  -- Lot C2 : la part des matières payée par le stock qui DORT (au-delà de 2 fois le besoin évalué) n'a aucun coût d'opportunité : personne
  -- d'autre ne la veut. Elle sort du coût du retour (pas du budget) ; chaque ordre retenu entame ce stock (ctx.dm.left).
  if ctx.dm and (ctx.dm.left or 0) > 0 then
    local disc = math.min(o.cost_m, ctx.dm.left)
    o.cost = o.cost - disc
    o.dormant_mu = disc
  end
  -- Lot PREVISION (C12) : la pollution que l'ordre ajoute entraîne les tourelles qu'elle rendra nécessaires ; leur prix entre dans
  -- le RETOUR (le choix), pas dans le budget de la capitalisation (les tourelles sont payées par la défense, part δ).
  if ctx.def_price and ctx.def_price > 0 then
    local em = Ca.option_emit(ctx, o)
    if em > 0 then
      o.emit = em
      o.def_mu = em * ctx.def_price
      o.cost = o.cost + o.def_mu
    end
  end
  if (o.gain or 0) <= Ca.EPS then
    refuse(ctx, o.key, o.kind, o.item, "gain nul")
    return nil
  end
  o.T = o.cost / o.gain
  o.Tq = math.floor(o.T * 1e6 + 0.5) -- comparaison exacte et transitive (aucun bruit de flottant dans le tri)
  if o.T > tmax then
    refuse(ctx, o.key, o.kind, o.item, string.format("retour %s min > %s", fmt(o.T), fmt(tmax)))
    return nil
  end
  o.value = Ca.value(o.T, tmax)
  return o
end

local function cand(list, o, mk) if o then list[#list + 1] = { o = o, mk = mk } end end

--- Couverture d'un gisement dans le plan : couvertes (tuiles), places libres, κ (‰). Mémoïsée par passe.
local function deposit_state(ctx, plan, f, d)
  local mk = tostring(f.id) .. "|" .. d.name
  local m = ctx.ds[mk]
  if m then return m[1], m[2], m[3] end
  local key = tostring(f.id)
  local per, cov = Ca.comb(d)
  local covered = math.min(f.tiles or 0, plan.cover[key] or 0)
  local used_land = covered * per / math.max(Ca.EPS, cov)
  local free = math.max(0, math.floor(((f.tiles or 0) - used_land) / per + Ca.EPS))
  local kappa = (f.tiles or 0) > 0 and math.floor(1000 * covered / f.tiles) or 1000
  ctx.ds[mk] = { covered, free, kappa }
  return covered, free, kappa
end
Ca.deposit_state = deposit_state

--- Raison qui interdit de poser sur un gisement CE cycle (nil : permis) : menace (hors QG), danger.
function Ca.usable(ctx, f, kind)
  if ctx.threat and not Ca.HQ_LEVERS[kind] and not starved_in(ctx, f.resource) then return "menace : leviers du QG seulement" end
  if f.danger then return "danger" end
  if f.blocked then return tostring(f.blocked) end -- lot CAPIB : interdit par l'exécutant (hors de portée, refus)
  return nil
end

--- Fonte sur place d'un gisement (avant-poste) : sa recette et son four, s'ils fondent cette ressource.
function Ca.smelt_of(ctx, f, item)
  local D = ctx.D
  local r = f.smelt and D.recipes[f.smelt]
  local m = f.smelter and D.maker_by[f.smelter]
  if r and m and amount_of(r.ingredients, item) > 0 then return r, m end
  return nil
end

--- Options d'extraction d'une ressource : couvrir les gisements ouverts (manque, puis d'avance), ouvrir un gisement
--- connu, explorer.
local function extraction_options(ctx, plan, req, item, def, out, sat_only)
  local D = ctx.D
  local rs = D.res[item]
  -- Lot COUVERTURE (sat_only) : ressource SANS demande nette (Ri = 0) : seule la saturation des gisements revendiqués est étudiée, sans
  -- refus de ressource (fluide, aucune foreuse) ni ouverture de site.
  if rs.fluid then if not sat_only then refuse(ctx, "extraire:" .. item, "couvrir", item, "limite : fluide") end return end
  local d = best_drill(ctx, item)
  if not d then if not sat_only then refuse(ctx, "extraire:" .. item, "couvrir", item, "aucune foreuse disponible") end return end
  local rho = Ca.drill_per_min(D, d, item)
  local fuel = Ca.fuel_per_min(D, d)
  local Ri = req.R[item] or 0
  local Ni = plan.N[item] or 0
  local stock_i = (ctx.stock[item] or 0) / Ca.H_STOCK
  local theta = Ri > 0 and (Ni + (plan.hand[item] or 0) + stock_i) / Ri or 1
  local n_need = Ca.count_for(def, rho, theta)
  if def > Ca.EPS and n_need == 0 and not sat_only then
    refuse(ctx, "extraire:" .. item, "couvrir", item, "manque sous une demi-machine (" .. fmt(def) .. "/min)")
  end
  local opened, sites = {}, {}
  for _, f in ipairs(ctx.dep_by_res[item] or {}) do
    local key = tostring(f.id)
    if not plan.dead[key] then
      if plan.opened[key] then opened[#opened + 1] = f else sites[#sites + 1] = f end
    end
  end
  local function by_dist(a, b)
    local da, db = a.dist or Ca.DIST, b.dist or Ca.DIST
    if da ~= db then return da < db end
    return tostring(a.id) < tostring(b.id)
  end
  table.sort(opened, by_dist)
  -- lot GEANT-D-ABORD : distance moins crédit de taille (Ca.site_rank, calculé UNE fois par site), puis la distance, puis l'identifiant
  local rank = {}
  for _, f in ipairs(sites) do rank[f] = Ca.site_rank(f) end
  table.sort(sites, function(a, b)
    local ra, rb = rank[a], rank[b]
    if ra ~= rb then return ra < rb end
    return by_dist(a, b)
  end)
  local per, cov = Ca.comb(d)
  local sh_cache = {}
  local function mk_drills(kind, f, n, fixed)
    local key = tostring(f.id)
    local o = { kind = kind, key = kind .. ":" .. key, item = item, resource = item, deposit = f.id,
      entity = d.name, n = n, rate = n * rho, depth = 0, where = f.id,
      kw_unit = (d.energy == "electric" and (d.kw or 0) > 0) and d.kw or nil, short = def } -- (lot TV-ENERGIE (c) : kW d'une foreuse et manque, Ca.share_kw)
    local items = { { d.item, n } }
    for _, it in ipairs(ctx.input.drill_extra or {}) do items[#items + 1] = { it[1], it[2] * n } end
    for _, it in ipairs(fixed or {}) do items[#items + 1] = { it[1], it[2] } end
    local useful = math.min(n * rho, math.max(0, def))
    local ahead = n * rho - useful
    local unit_va = D.mu[item] or 0
    local op = n * fuel * ctx.fuel_mu
    local sr, sm = Ca.smelt_of(ctx, f, item)
    if sr then
      -- Fours de l'ordre : ceux de SON débit, comme les modules que l'exécutant pose (lot CAPI-RETOUR : dimensionnés sur tout le gisement
      -- moins les fours posés SUR lui, ils recomptaient à chaque ordre la fonte des foreuses déjà posées, faite par la fonderie déportée).
      local nf = Ca.fed_max(n * rho, 0, Ca.in_per_min(sm, sr, item))
      if nf > 0 then
        o.smelt_n, o.smelt_recipe, o.smelt_entity = nf, sr.name, sm.name
        items[#items + 1] = { sm.item, nf }
        local p = sr.products[1]
        local per_ore = p.amount / amount_of(sr.ingredients, item)
        local sh = sh_cache[p.name]
        if sh == nil then
          -- Part des deux étages (foreuse et four) dans le capital de la chaîne de la plaque.
          local cd = (D.mu[d.item] + extras_mu(ctx, ctx.input.drill_extra)) / math.max(Ca.EPS, rho) / per_ore
          local cf = (D.mu[sm.item] + extras_mu(ctx, ctx.input.machine_extra)) / math.max(Ca.EPS, Ca.out_per_min(sm, sr, p.name))
          local cc = Ca.chain_capital(ctx, p.name)
          sh = cc > Ca.EPS and clamp((cd + cf) / cc, 0, 1) or 1
          sh_cache[p.name] = sh
        end
        unit_va = math.max(unit_va, (D.mu[p.name] or 0) * per_ore * sh)
        op = op + nf * Ca.fuel_per_min(D, sm) * ctx.fuel_mu
      end
    end
    o.items = items
    o.cost_m, o.unpaid = items_mu(ctx, items)
    o.work = work_of(ctx, items, f.dist)
    o.gain = (useful + ahead * Ca.AHEAD_PCT / 100) * unit_va * ctx.w_cap - op
    o.useful = useful
    return o
  end
  -- Courant : une foreuse électrique ne se pose que si la centrale la porte ; le débit bloqué donne sa valeur à la
  -- centrale (levier « energie »).
  local pw = ctx.input.power
  local pw_why = Ca.power_refusal(ctx, plan) -- lots VIDEO-COUVERTURE 5 et TV-ENERGIE (W02) : relevé du courant fermé, sans capacité lue ou amorce prise : refus qui nomme la cause
  local function power_cap(n, key)
    if d.energy ~= "electric" or not pw or (d.kw or 0) <= 0 or (plan.amorce_left or 0) > 0 then return n end
    local np = math.max(0, math.floor((plan.kw_have - plan.kw_used) / d.kw + Ca.EPS))
    if np < n then
      ctx.power_block[#ctx.power_block + 1] = { key = key, kw = (n - np) * d.kw, n = n - np, item = item, p = rho,
        va = D.mu[item] or 0, share = 1 }
      return np
    end
    return n
  end
  -- Sans centrale possible, une foreuse électrique sans courant ne se pose nulle part : le gisement est « interdit ».
  local no_power = d.energy == "electric" and pw ~= nil and (d.kw or 0) > 0 and not pw.plant
    and (plan.amorce_left or 0) <= 0 and (plan.kw_have - plan.kw_used) < d.kw - Ca.EPS
  -- Couvrir les gisements ouverts. Un gisement où l'on ne peut pas poser ce cycle (danger, courant sans centrale)
  -- compte comme couvert : il ne bloque ni l'ouverture d'un autre, ni la réserve de places.
  local all_covered, free_total, ext_unit, n_usable, kmin = true, 0, nil, 0, 1000
  local near_free = {} -- lot GISEMENTS : gisements ouverts de CE minerai qui ont encore des places (pas d'avant-poste de trop)
  for _, f in ipairs(opened) do
    local key = "couvrir:" .. tostring(f.id)
    local covered, free, kappa = deposit_state(ctx, plan, f, d)
    local blocked = f.danger or f.blocked or no_power
    if not blocked then
      n_usable = n_usable + 1
      free_total = free_total + free
      if free > 0 then near_free[#near_free + 1] = { x = f.x, y = f.y, free = free, blocked = f.blocked, danger = f.danger, id = f.id } end
      if free > 0 and kappa < Ca.KAPPA then all_covered = false end
      if kappa < kmin then kmin = kappa end
    end
    if free > 0 and not Ca.taken(plan, key) then
      local n, ahead = 0, false
      if def > Ca.EPS then
        n = math.min(free, n_need)
      elseif Ri > 0 and kappa < Ca.KAPPA and not Ca.taken(plan, "ouvrir:" .. tostring(f.id))
        and (Ca.AHEAD_BURNER or d.energy ~= "burner") then
        -- Couverture D'AVANCE (critère (1) : « à mesure que le capital le permet ») : jusqu'à Ca.KAPPA ‰ des tuiles et
        -- Ca.LEAD × le besoin, gain à Ca.AHEAD_PCT % ; seulement pour une ressource qui a un débouché, et pas sur un site
        -- ouvert dans ce cycle (un ordre par gisement et par cycle).
        local room = Ca.COVER_LEAD and (Ca.COVER_LEAD * Ri - Ni - stock_i) or math.huge
        local to_k = math.ceil((Ca.KAPPA * (f.tiles or 0) / 1000 - covered) / math.max(Ca.EPS, cov) - Ca.EPS)
        n = math.max(0, math.min(free, math.floor(room / rho + Ca.EPS), to_k))
        ahead = true
      end
      -- Lot COUVERTURE, SATURATION TOTALE (directive du DC du 8/11) : un gisement REVENDIQUÉ (ouvert) qui a encore des tuiles libres garde un
      -- ordre de couverture, sans condition sur la demande nette (Ri) ni sur le manque. Le budget, les bras, les emplacements et la porte du
      -- transport le bornent ; la cause d'une absence d'ordre est toujours écrite (ctx.sat, journal [FO-SATURATION]).
      local sat_order = false
      if n == 0 and ctx.input.saturation then
        local ok, why = Cv.saturation({ free = free, kappa = kappa, kappa_max = Ca.KAPPA, electric = d.energy ~= "burner",
          crisis = ctx.threat and not starved_in(ctx, item) })
        ctx.sat[tostring(f.id)] = { ok = ok, why = why }
        if ok then
          n = math.max(0, math.min(free, math.ceil((Ca.KAPPA * (f.tiles or 0) / 1000 - covered) / math.max(Ca.EPS, cov) - Ca.EPS)))
          ahead, sat_order = true, true
        end
      end
      if n > 0 then
        local why_not = Ca.usable(ctx, f, "couvrir")
        if why_not then refuse(ctx, key, "couvrir", item, why_not)
        elseif no_power then
          refuse(ctx, key, "couvrir", item, pw_why or Ca.kw_refusal(plan, d.kw))
          -- étape 5a de VIDEO-INTEG : kW retenus, comme power_cap (la centrale les compte pour grandir : Ca.blocked_kw ; power_options
          -- ne lit power_block qu'avec une centrale à proposer, pw.plant : aucune décision ne change)
          ctx.power_block[#ctx.power_block + 1] = { key = key, kw = n * d.kw, n = n, item = item, p = rho, va = D.mu[item] or 0, share = 1 }
        else
          local o = mk_drills("couvrir", f, n)
          if not ahead and ext_unit == nil and o.cost_m and o.gain > 0 then
            ext_unit = (o.cost_m + ctx.lambda * o.work / 60) / (n * rho)
          end
          local np = power_cap(n, key)
          if np <= 0 then refuse(ctx, key, "couvrir", item, pw_why or Ca.kw_refusal(plan, d.kw))
          else
            if np ~= n then o = mk_drills("couvrir", f, np) end
            local why = ahead and (sat_order and "saturation du gisement" or "couverture d'avance") or nil
            o.why = why
            o.saturation = sat_order or nil
            cand(out, finish(ctx, o), function(k)
              local x = mk_drills("couvrir", f, k)
              x.why = why
              x.saturation = sat_order or nil
              return finish(ctx, x)
            end)
          end
        end
      end
    end
  end
  if sat_only then return end
  -- Ouvrir : autorisé quand les ouverts sont couverts ou interdits (et qu'il manque), ou d'avance.
  local amount_open, unknown = 0, false
  for _, f in ipairs(opened) do
    if f.amount == nil then unknown = true else amount_open = amount_open + f.amount end
  end
  local life = (not unknown and Ni > 0) and amount_open / Ni or math.huge
  -- Réserve de places basse : ouvrir d'avance, tant que la capacité reste sous Ca.LEAD × le besoin (une foreuse de marge).
  local reserve_low = Ri > 0 and free_total * rho < Ca.RESERVE_PCT / 100 * Ri and Ca.LEAD * Ri - Ni - stock_i >= rho
  local why_open = nil
  if def > Ca.EPS and all_covered then
    if n_usable > 0 then why_open = "gisements ouverts couverts"
    elseif #opened > 0 then why_open = "gisements ouverts interdits (danger, courant)"
    else why_open = "aucun gisement ouvert" end
  elseif #opened > 0 and Ri > 0 and life < Ca.H_LIFE then why_open = "epuisement en " .. fmt(life) .. " min"
  elseif #opened > 0 and reserve_low then why_open = "reserve de places basse" end
  local any_site = false
  for _, f in ipairs(sites) do if not (f.danger or f.blocked) then any_site = true end end
  local evaluated, cheap_done = 0, false
  for _, f in ipairs(sites) do
    local key = "ouvrir:" .. tostring(f.id)
    local redundant, near_dep = false, nil
    if not Ca.taken(plan, key) and not f.danger and not f.blocked then
      -- Lot GISEMENTS (DC 31/10 : « ils voulaient même faire un avant-poste de cuivre alors que le gisement est à côté ») : un
      -- gisement ouvert voisin du même minerai a des places : pas de site de plus, sauf s'il s'épuise (epuisement en N min).
      redundant, near_dep = Gi.site_redundant(f, near_free, Ca.NEAR_SITE)
    end
    if redundant and not (why_open and why_open:sub(1, 10) == "epuisement") then
      refuse(ctx, key, "ouvrir", item, "gisement voisin a des places (" .. tostring(near_dep and near_dep.id) .. ")")
      evaluated = evaluated + 1
      if evaluated >= Ca.SITES_EVAL then break end
    elseif not Ca.taken(plan, key) and not f.danger and not f.blocked then
      local why = why_open
      local _, slots = deposit_state(ctx, plan, f, d)
      local n = math.min(slots, math.max(Ca.OPEN_MIN, Ca.count_for(math.max(0, def), rho, theta)))
      if not why and def > Ca.EPS and n > 0 and ext_unit and not cheap_done then
        cheap_done = true -- seul le site le plus proche est comparé à la couverture (coût de calcul)
        local o = mk_drills("ouvrir", f, n, ctx.input.site_items)
        if o.cost_m and o.gain > 0 then
          local unit = (o.cost_m + ctx.lambda * o.work / 60) / (n * rho)
          if unit * Ca.OPEN_RATIO / 100 < ext_unit then why = "site moins cher par debit" end
        end
      end
      if not why then
        refuse(ctx, key, "ouvrir", item, string.format("gisements ouverts pas couverts (kappa %d pour mille < %d)", kmin, Ca.KAPPA))
        break -- les sites suivants ont la même raison
      elseif n <= 0 then refuse(ctx, key, "ouvrir", item, "aucune place")
      else
        local why_not = Ca.usable(ctx, f, "ouvrir")
        if why_not then refuse(ctx, key, "ouvrir", item, why_not)
        else
          local np = power_cap(n, key)
          if np <= 0 then refuse(ctx, key, "ouvrir", item, pw_why or Ca.kw_refusal(plan, d.kw))
          else
            local mk = function(k)
              local o = mk_drills("ouvrir", f, k, ctx.input.site_items)
              o.why = why
              return finish(ctx, o)
            end
            cand(out, mk(np), mk)
          end
        end
      end
      evaluated = evaluated + 1
      if evaluated >= Ca.SITES_EVAL then break end
    elseif (f.danger or f.blocked) and not Ca.taken(plan, key) and why_open then
      refuse(ctx, key, "ouvrir", item, f.danger and "danger" or tostring(f.blocked))
    end
  end
  if why_open and not any_site and not ctx.threat then ctx.explore[item] = why_open end
end

--- Options d'une fabrique (fours, chaîne, packs) pour l'objet `item` de recette `r`. La SORTE vient de la machine
--- choisie : un assembleur (catégorie de la main) donne une chaîne (packs pour une entrée de laboratoire), une autre
--- fabrique des fours.
local function fabric_options(ctx, plan, req, item, r, def, out)
  local D = ctx.D
  local hand_cat = D.hand[r.category] or false
  local m = best_maker(ctx, r.category)
  if not m then
    if def > Ca.EPS then
      local kind = hand_cat and (D.packs[item] and "packs" or "chaine") or "fours"
      refuse(ctx, kind .. ":" .. item, kind, item, "aucune machine disponible (" .. r.category .. ")")
    end
    return
  end
  local is_chain = m.assembler
  local kind = is_chain and (D.packs[item] and "packs" or "chaine") or "fours"
  local key = kind .. ":" .. item
  if Ca.taken(plan, key) then return end
  -- Lot CAPIB : l'EXÉCUTANT sait-il poser cette chaîne aujourd'hui (gabarit, objets du gabarit fabricables, centrale) ?
  -- input.can_exec(kind, item) rend nil (oui) ou la raison ; le refus est écrit et l'option n'existe pas (aucun budget
  -- dépensé pour un ordre que personne ne peut poser).
  local ce = ctx.input.can_exec
  if ce then
    local why_not = ce(kind, item)
    if why_not then
      if def > Ca.EPS then refuse(ctx, key, kind, item, "executant : " .. tostring(why_not)) end
      return
    end
  end
  if ctx.threat and not Ca.HQ_LEVERS[kind] then
    if def > Ca.EPS then refuse(ctx, key, kind, item, "menace : leviers du QG seulement") end
    return
  end
  local lim = ctx.input.limits or {}
  if lim.max_ingredients and #r.ingredients > lim.max_ingredients then
    if def > Ca.EPS then refuse(ctx, key, kind, item, "limite : " .. #r.ingredients .. " ingredients") end
    return
  end
  local p = Ca.out_per_min(m, r, item)
  local Ri = req.R[item] or 0
  local stock_i = (ctx.stock[item] or 0) / Ca.H_STOCK
  -- Entrées : une ressource se lit sur l'ARRIVÉE des foreuses (contrôle dur des fours) ; un objet fabriqué sur sa
  -- couverture dans le plan (un ingrédient en manque passe d'abord : goulot amont).
  local ncap, limit, raw_in, nfree = math.huge, nil, false, math.huge
  for _, ing in ipairs(r.ingredients) do
    local k_in = Ca.in_per_min(m, r, ing.name)
    if D.res[ing.name] then
      raw_in = true
      local supply = Ca.supply_of(ctx, ing.name)
      local cons = plan.cons[ing.name] or 0
      local c = Ca.fed_max(supply, cons, k_in)
      if c < ncap then ncap, limit = c, ing.name end
      -- Part d'AVANCE : le minerai que les AUTRES usages ne réclament pas (leur besoin brut, moins ce que leurs machines
      -- consomment déjà et que `cons` compte).
      local Rj = req.R[ing.name] or 0
      local mine = ((req.used_by[ing.name] or {})[item]) or 0
      local cons_self = ((plan.cons_by[ing.name] or {})[item]) or 0
      local other = math.max(0, Rj - mine - math.max(0, cons - cons_self))
      local ca = Ca.fed_max(supply - other, cons, k_in)
      if ca < nfree then nfree = ca end
    else
      local Rj = req.R[ing.name] or 0
      local cover = (plan.N[ing.name] or 0) + (plan.hand[ing.name] or 0) + (ctx.stock[ing.name] or 0) / Ca.H_STOCK
      if Rj > 0 and cover * 1000 < Ca.THETA_MIN * Rj then
        if def > Ca.EPS then
          refuse(ctx, key, kind, item, string.format("entree %s d'abord (couverte a %d pour mille)", ing.name,
            math.floor(1000 * cover / Rj)))
        end
        return
      end
    end
  end
  local theta = Ri > 0 and ((plan.N[item] or 0) + (plan.hand[item] or 0) + stock_i) / Ri or 1
  local nwant = Ca.count_for(def, p, theta)
  local ahead = false
  if not is_chain and raw_in and Ri > 0 and ncap ~= math.huge then
    -- Fondre d'avance (« tout le minerai ») : sur la part libre du minerai, au plus Ca.LEAD × le débouché.
    local n_lead = math.max(0, math.floor((Ca.LEAD * Ri - (plan.N[item] or 0) - stock_i) / p + Ca.FRAC_UP))
    local na = math.min(ncap, nfree, n_lead)
    if na > nwant then nwant, ahead = na, true end
  end
  -- Lot PILE-MALL (retour du DC du 31/10, point 8 : « une seule usine par objet ») : une CHAÎNE se dimensionne aussi sur la demande
  -- (au plus Ca.CHAIN_LEAD fois le débit voulu, comme la fonte d'avance), pas seulement sur le manque présent ; la demande déjà
  -- couverte par les machines, la main et le stock n'ouvre rien de plus. Les ingrédients (nfree) et la capacité (ncap) bornent.
  local n_short = nil -- relecture : le nombre pour le seul manque présent (repli si l'ordre agrandi dépasse le retour accepté)
  if is_chain and Ca.CHAIN_LEAD and Ri > 0 then
    local n_lead = math.max(0, math.floor((Ca.CHAIN_LEAD * Ri - (plan.N[item] or 0) - (plan.hand[item] or 0) - stock_i) / p + Ca.FRAC_UP))
    local na = math.min(ncap, nfree, n_lead, Ca.CHAIN_MAX)
    n_short = nwant
    if na > nwant then nwant = na end -- sans crédit d'avance : §9, un crédit fait passer les chaînes devant l'extraction (K et foreuses s'effondrent)
  end
  if nwant <= 0 then
    if def > Ca.EPS then refuse(ctx, key, kind, item, "manque sous une demi-machine (" .. fmt(def) .. "/min)") end
    return
  end
  if ncap <= 0 then
    refuse(ctx, key, kind, item, "entree " .. tostring(limit) .. " insuffisante (arrivee des foreuses)")
    return
  end
  local n = math.min(nwant, ncap)
  local va = D.mu[item] or 0
  local sh = Ca.share(ctx, item)
  if m.energy == "electric" and ctx.input.power and (plan.amorce_left or 0) <= 0 then
    local np = math.max(0, math.floor((plan.kw_have - plan.kw_used) / math.max(Ca.EPS, m.kw) + Ca.EPS))
    if np < n then
      ctx.power_block[#ctx.power_block + 1] = { key = key, kw = (n - np) * m.kw, n = n - np, item = item, p = p, va = va,
        share = sh }
      n = np
      if n <= 0 then refuse(ctx, key, kind, item, Ca.power_refusal(ctx, plan) or Ca.kw_refusal(plan, m.kw)) return end
    end
  end
  -- Valeur de l'objet × part de cet étage dans le capital de sa chaîne (Ca.share) : un étage plein a le retour du
  -- PROJET de chaîne, la valeur au puits n'est pas comptée une fois par étage.
  local wf = D.packs[item] and ctx.w_rech or ctx.w_cap
  local hand = (ctx.flows[item] or {}).hand or 0
  local unit_s = r.energy / math.max(Ca.EPS, amount_of(r.products, item))
  local fuel = Ca.fuel_per_min(D, m)
  local function mk(k)
    local o = { kind = kind, key = key, item = item, recipe = r.name, entity = m.name, n = k, rate = k * p,
      where = Ca.HQ, depth = req.depth[item] or 0, fed_by = limit, fed_max = ncap ~= math.huge and ncap or nil,
      share = sh, kw_unit = (m.energy == "electric" and (m.kw or 0) > 0) and m.kw or nil, short = def } -- (lot TV-ENERGIE (c))
    local items = { { m.item, k } }
    for _, it in ipairs(ctx.input.machine_extra or {}) do items[#items + 1] = { it[1], it[2] * k } end
    o.items = items
    o.cost_m, o.unpaid = items_mu(ctx, items)
    o.work = work_of(ctx, items, Ca.DIST)
    local useful = math.min(k * p, math.max(0, def))
    local extra = ahead and (k * p - useful) * Ca.AHEAD_PCT / 100 or 0
    local freed = hand_cat and math.min(hand, k * p) * unit_s / 60 or 0 -- PNJ libérés de la main
    o.useful = useful
    o.gain = (useful + extra) * va * sh * wf + ctx.lambda * freed - k * fuel * ctx.fuel_mu
    o.why = string.format("manque %s/min, %d x %s (%s/min chacune)%s", fmt(def), k, m.name, fmt(p),
      limit and (", nourrie par " .. limit .. " (" .. ncap .. " au plus)") or "")
    return finish(ctx, o)
  end
  local first = mk(n)
  if not first and n_short and n_short > 0 and n_short < n then first = mk(n_short) end
  cand(out, first, mk)
end

--- Recherche que les packs nourrissent AU-DELÀ des laboratoires planifiés (secondes de laboratoire par minute) : pour
--- chaque pack, (couverture − consommation planifiée) ÷ part du pack ; le plus petit.
function Ca.lab_cap(ctx, plan)
  local cap = math.huge
  for _, p in ipairs(sorted_keys(ctx.mix)) do
    local mx = ctx.mix[p]
    if mx > 0 then
      local cover = (plan.N[p] or 0) + (plan.hand[p] or 0) + (ctx.stock[p] or 0) / Ca.H_STOCK
      local extra = (cover - (plan.cons[p] or 0)) / mx
      if extra < cap then cap = extra end
    end
  end
  return cap
end

--- Options des laboratoires : la recherche visée (en DÉBIT), jamais plus que les packs ne nourrissent.
local function lab_options(ctx, plan, out)
  if ctx.u_star <= 0 or not ctx.lab then return end
  local key = "labos:" .. ctx.lab.name
  if Ca.taken(plan, key) then return end
  local want_rate = ctx.u_star - plan.lab_cap
  if want_rate <= Ca.EPS then return end
  if ctx.threat and not Ca.HQ_LEVERS.labos then refuse(ctx, key, "labos", nil, "menace : leviers du QG seulement") return end
  local want = math.ceil(want_rate / ctx.lab_rate - Ca.EPS)
  local starved = (ctx.input.research or {}).starved or 0
  if starved > 100 then refuse(ctx, key, "labos", nil, "laboratoires affames (" .. starved .. " pour mille) : les packs d'abord") return end
  local feed = Ca.lab_cap(ctx, plan)
  local n = math.min(want, math.floor(feed / ctx.lab_rate + Ca.FRAC_UP))
  if n <= 0 then refuse(ctx, key, "labos", nil, "packs insuffisants pour un laboratoire de plus") return end
  local l = ctx.lab
  local sh = lab_share(ctx)
  local function mk(k)
    local o = { kind = "labos", key = key, entity = l.name, item = l.item, n = k, rate = k * ctx.lab_rate, depth = 99,
      where = Ca.HQ, share = sh }
    o.items = { { l.item, k } }
    o.cost_m, o.unpaid = items_mu(ctx, o.items)
    o.work = work_of(ctx, o.items, Ca.DIST)
    local useful = math.min(k * ctx.lab_rate, math.max(0, want_rate))
    o.useful = useful
    o.gain = useful * ctx.lab_mu * sh * ctx.w_rech
    o.why = string.format("recherche visee %s s/min, %s posee ou ouverte, %d laboratoire(s) de plus", fmt(ctx.u_star),
      fmt(plan.lab_cap), k)
    return finish(ctx, o)
  end
  cand(out, mk(n), mk)
end

--- Centrale : machines électriques rentables qui manquent de courant (la puissance d'une centrale vient du runtime).
local function power_options(ctx, plan, out)
  local pw = ctx.input.power
  if not pw or not pw.plant or #ctx.power_block == 0 then return end
  local key = "energie"
  if Ca.taken(plan, key) then return end
  local kw_need, gain = 0, 0
  for _, b in ipairs(ctx.power_block) do
    kw_need = kw_need + b.kw
    gain = gain + b.n * b.p * b.va * (b.share or 1) * ctx.w_cap
  end
  local pk = math.max(Ca.EPS, pw.plant.kw or 0)
  local n = math.ceil(kw_need / pk - Ca.EPS)
  local function mk(k)
    local o = { kind = "energie", key = key, n = k, kw = k * pk, depth = 98, where = Ca.HQ }
    local items = {}
    for _, it in ipairs(pw.plant.items or {}) do items[#items + 1] = { it[1], it[2] * k } end
    o.items = items
    o.cost_m, o.unpaid = items_mu(ctx, items)
    o.work = work_of(ctx, items, Ca.DIST)
    local burn = (pw.plant.burner_kw or 0) * 60 / math.max(Ca.EPS, ctx.D.fuel_kj) * k * ctx.fuel_mu
    o.gain = gain * math.min(1, k * pk / math.max(Ca.EPS, kw_need)) - burn
    o.why = string.format("%s kW manquent a des machines rentables", fmt(kw_need))
    return finish(ctx, o)
  end
  cand(out, mk(n), mk)
end

--- Lot CONSOLIDATION-TIERS (8/11 ; critères : fo-logs/2026-11-08_CONSOLIDATION-TIERS/CRITERES.md) : ALLUMÉ par défaut ; demande Ca.PORTE_RANG,
--- Ca.RANG, l'état persistant (ctx.st) et input.solid_mesure (le runtime donne des débits MESURÉS : input.flows). Éteint ou sans mesure, rank_gate
--- est celui de 7fc96ada. Une chaîne de rang >= 1 n'est CONSOLIDÉE que si son débit mesuré (hors main) plus son stock couvre Pr.SOLID_PCT % de sa
--- demande depuis Pr.SOLID_MIN minutes ; un ordre de rang r attend tant qu'une chaîne de rang < r qui l'alimente ne l'est pas ET a une issue.
Ca.CONSOLIDE_RANG = true

--- Fluide ? (l'objet est un produit de fluide de sa recette : les statistiques d'objets ne le voient pas.)
local function fluid_product(r, item)
  for _, p in ipairs((r and r.products) or {}) do
    if p.name == item and p.fluid then return true end
  end
  return false
end

--- Lignes de consolidation de la décision : un relevé par chaîne demandée de rang >= 1 (hors ressources), débit = production mesurée de
--- la force moins la main (ctx.flows), stock ÷ H_STOCK ; « arrêtée » = machines posées dont aucune unité ne compte (confirmation).
local function solid_rows(ctx, req)
  local D, Rk = ctx.D, ctx.rang
  local posed, cap = {}, {}
  for _, m in ipairs(ctx.machines) do
    local r = D.recipes[m.recipe]
    if r and (m.n or 0) > 0 then
      for _, p in ipairs(r.products) do
        posed[p.name] = (posed[p.name] or 0) + m.n
        cap[p.name] = (cap[p.name] or 0) + (m.n_cap or m.n)
      end
    end
  end
  local rows = {}
  for _, i in ipairs(req.list) do
    local Ri, rk = req.R[i] or 0, Rk.rank[i]
    if Ri > Ca.EPS and rk ~= nil and rk >= 1 and not D.res[i] then
      local rate = nil
      if req.rec[i] ~= nil and not fluid_product(req.rec[i], i) then
        local fl = ctx.flows[i] or {}
        rate = math.max(0, (fl.made or 0) - (fl.hand or 0))
      end
      rows[#rows + 1] = { item = i, rank = rk, demand = Ri, stock_cover = (ctx.stock[i] or 0) / Ca.H_STOCK, rate = rate,
        stopped = (posed[i] or 0) > 0 and (cap[i] or 0) <= 0 }
    end
  end
  return rows
end

--- Chaînes non consolidées qui ont une issue (option ce tour, machines posées, ordre ouvert ou décidé) : l'entrée `solid` de Pr.decide.
--- Le relevé (et la mémoire st.solid) avance UNE fois par décision ; l'issue se relit à chaque tour de la boucle des ordres.
local function consolidation(ctx, plan, req, served)
  if ctx.cons == nil then
    ctx.st.solid = ctx.st.solid or Pr.solid_new()
    local verdicts, lines = Pr.solid_step(ctx.st.solid, ctx.dt, solid_rows(ctx, req))
    ctx.cons, ctx.cons_log = { v = verdicts }, lines
  end
  return Pr.solid_list(ctx.cons.v, function(x)
    return served[x] == true, ((plan.N[x] or 0) + (plan.NP[x] or 0) + (plan.NO[x] or 0)) > Ca.EPS
  end)
end

--- Lot VIDEO-ORDRE (lot 1 de la couverture vidéo, 7/11) : ALLUMÉ par défaut ; éteint, rank_gate ne fait que ce qu'il faisait en 0.6.61
--- (l'ordre ne change pas, aucune mémoire des objets posés, aucune règle de grosse unité). Demande Ca.PORTE_RANG et Ca.RANG.
Ca.ORDRE_RANG = true

--- Ordre des options : retour (arrondi au millionième), profondeur (l'amont d'abord), clé. Lot VIDEO-ORDRE : rank_gate donne aux options
--- du rang retenu la PLACE (oTq, odepth, okey) d'une autre option du même rang (Pr.order) : le reste de la liste ne bouge pas.
function Ca.before(a, b)
  local at, bt = a.oTq or a.Tq, b.oTq or b.Tq
  if at ~= bt then return at < bt end
  local ad, bd = a.odepth or a.depth, b.odepth or b.depth
  if ad ~= bd then return ad < bd end
  return (a.okey or a.key) < (b.okey or b.key)
end

--- Lot VIDEO-L2 (Ca.PORTE_RANG, demande Ca.RANG) : PORTE DE RANG CIBLÉE (shared/ai3/porte_rang.lua). Une option de fabrication
--- (chaîne, packs, fours) dont la chaîne DÉPEND, par les recettes choisies, d'un objet EN MANQUE d'un rang plus bas est refusée
--- « rang : <objet> (rang k) d'abord » : elle ne prend ni budget ni emplacement tant que ce manque n'est pas couvert par le plan.
--- Manque = R − N − stock ÷ H_STOCK (la formule de Ca.options) ; un manque qu'aucune option de ce tour ne sert ne bloque rien.
--- L'extraction (rang 0) n'est jamais retenue ; anti-répétition : l'objet du dernier ordre (ctx.last_item) cède sa place à un
--- autre objet de son rang. Cas visé : l'interblocage du fer (EFFONDREMENT, Ca.blocked_items) ; la foreuse passe devant.
--- Lot VIDEO-ORDRE (Ca.ORDRE_RANG) : (1) dans le rang retenu r*, les options changent de place entre elles, le plus gros manque net
--- d'abord (Pr.order ; le reste de la liste ne bouge pas) ; (2) un objet de fabrication posé n'est pas re-ordonné tant que le manque
--- MESURÉ (input.mq_build, L3) n'a pas bougé, ni avant Pr.RETRY_MIN décisions (Pr.recent ; st.posed, st.clock) ; (3) après une grosse
--- unité (coût > Pr.BIG_K fois la médiane des options), les grosses cèdent à une autre option (Pr.big_hold ; st.last_big). Le pas de
--- l'ordre posé est lu au tour suivant dans plan.taken : le dernier ordre d'une décision qui atteint Ca.MAX_ORDERS n'est pas noté.
local function rank_gate(ctx, plan, req, out)
  local Rk = ctx.rang
  if ctx.rang_deps == nil then ctx.rang_deps = Pr.deps(Rk) end
  local solid = Ca.CONSOLIDE_RANG and ctx.st ~= nil and ctx.input.solid_mesure and true or nil
  local served = {}
  for _, c in ipairs(out) do
    if c.o.item ~= nil then served[c.o.item] = true end
    if c.o.resource ~= nil then served[c.o.resource] = true end
  end
  local short, net = {}, {}
  for _, i in ipairs(req.list) do
    local Ri = req.R[i] or 0
    if Ri > 0 and Rk.rank[i] ~= nil then
      local def = Ri - (plan.N[i] or 0) - (ctx.stock[i] or 0) / Ca.H_STOCK
      if def > Ca.EPS then short[#short + 1] = { item = i, rank = Rk.rank[i], option = served[i] == true } net[i] = def end
    end
  end
  local orders = {}
  for _, c in ipairs(out) do
    local o = c.o
    if (o.kind == "chaine" or o.kind == "packs" or o.kind == "fours") and o.item ~= nil then
      orders[#orders + 1] = { key = o.key, item = o.item, rank = Rk.rank[o.item], pile = 2 }
    end
  end
  local solid_list = nil
  if solid then solid_list = consolidation(ctx, plan, req, served) end
  local g = Pr.decide({ orders = orders, short = short, deps = ctx.rang_deps, last = ctx.last_item, solid = solid_list })
  if solid then
    for _, x in ipairs(sorted_keys(g.waiting)) do
      local v = ctx.cons.v[x]
      local line = Pr.solid_mark(ctx.st.solid, x, v and v.text)
      if line then ctx.cons_log[#ctx.cons_log + 1] = line end
    end
  end
  -- r* de la décision (compte rendu) : le rang le plus bas d'un manque à option sur TOUS les tours (le dernier tour, manque couvert,
  -- n'en a souvent plus).
  if g.rstar ~= nil and (ctx.rstar == nil or g.rstar < ctx.rstar) then ctx.rstar = g.rstar end
  local cause, nheld = {}, #g.held
  for _, h in ipairs(g.held) do cause[h.order.key] = h.cause end
  -- Lot VIDEO-ORDRE : l'ordre dans le rang retenu, la mémoire des objets posés, les grosses unités (shared/ai3/porte_rang.lua).
  local st = ctx.st
  local on = Ca.ORDRE_RANG and st ~= nil
  local sig = ctx.input and ctx.input.mq_build -- manque net MESURÉ par objet (L3, view.mq.build) ; nil : rien n'est mesuré (objet absent : 0)
  if on then
    -- Une décision = une minute de plus pour la mémoire ; l'ordre posé au tour précédent (une clé de plus dans plan.taken parmi les
    -- options du tour précédent) y entre : la mémoire des objets posés et la grosse unité.
    local prev = ctx.rg_list
    if prev == nil then
      Pr.tick(st, ctx.dt)
    else
      for _, e in ipairs(prev) do
        if plan.taken[e.key] and not e.was then
          st.last_big = e.big
          if e.item ~= nil and sig ~= nil then Pr.note(st, e.item, sig[e.item] or 0) end
        end
      end
    end
    -- Un objet posé dont le signal mesuré n'a pas bougé n'est pas re-ordonné (avant Pr.RETRY_MIN minutes).
    if sig ~= nil and st.posed ~= nil then
      for _, o in ipairs(g.allowed) do
        if cause[o.key] == nil and Pr.recent(st, o.item, sig[o.item] or 0) then
          cause[o.key] = string.format("anti-repetition : %s pose, manque mesure inchange (%s)", o.item, fmt(sig[o.item] or 0))
          nheld = nheld + 1
        end
      end
    end
    -- Pas deux grosses unités de suite : la médiane des coûts des options de ce tour juge « grosse ».
    local items = {}
    for _, c in ipairs(out) do
      if cause[c.o.key] == nil then items[#items + 1] = { key = c.o.key, cost = c.o.cost_m } end
    end
    local big_hold, med = Pr.big_hold(st.last_big == true, items)
    ctx.rg_list = {}
    for _, c in ipairs(out) do
      local o = c.o
      local fab = o.kind == "chaine" or o.kind == "packs" or o.kind == "fours"
      ctx.rg_list[#ctx.rg_list + 1] = { key = o.key, was = plan.taken[o.key] == true, item = fab and o.item or nil, big = Pr.big(o.cost_m, med) }
      if big_hold[o.key] and cause[o.key] == nil then
        cause[o.key] = string.format("grosse unite : %s MU, plus de %s fois la mediane (%s), une autre option d'abord",
          fmt(o.cost_m), tostring(Pr.BIG_K), fmt(med))
        nheld = nheld + 1
      end
    end
  end
  if nheld == 0 and not on then return out end
  if nheld > 0 then ctx.rang_held = (ctx.rang_held or 0) + nheld end
  local kept = {}
  for _, c in ipairs(out) do
    local why = cause[c.o.key]
    if why then refuse(ctx, c.o.key, c.o.kind, c.o.item, why) else kept[#kept + 1] = c end
  end
  if on and g.rstar ~= nil then
    -- Dans le rang retenu, le plus gros manque net d'abord : chaque option du rang prend la place d'une autre du rang.
    local recs, in_rank = {}, 0
    for _, c in ipairs(kept) do
      local it = c.o.item or c.o.resource
      local rk = it ~= nil and Rk.rank[it] or nil
      if rk == g.rstar then in_rank = in_rank + 1 end
      recs[#recs + 1] = { c = c, key = c.o.key, item = it, rank = rk, Tq = c.o.Tq, depth = c.o.depth }
    end
    if in_rank >= 2 then
      local new, old = Pr.order(recs, g.rstar, net)
      for j, r in ipairs(new) do
        if r ~= old[j] then r.c.o.oTq, r.c.o.odepth, r.c.o.okey = old[j].Tq, old[j].depth, old[j].key end
      end
    end
  end
  -- Lot CONSOLIDATION-TIERS : les options des chaînes qui retiennent un ordre passent devant (priorité à leur consolidation) : chaque option
  -- prend la PLACE (oTq, odepth, okey) de celle qui était à son rang dans l'ordre actuel, comme Pr.order.
  if solid and next(g.waiting) ~= nil and #kept >= 2 then
    local cur = {}
    for _, c in ipairs(kept) do cur[#cur + 1] = c end
    table.sort(cur, function(a, b) return Ca.before(a.o, b.o) end)
    local new = Pr.front(cur, function(c)
      local it = c.o.item or c.o.resource
      return it ~= nil and g.waiting[it] == true
    end)
    local place = {}
    for j, c in ipairs(cur) do place[j] = { c.o.oTq or c.o.Tq, c.o.odepth or c.o.depth, c.o.okey or c.o.key } end
    for j, c in ipairs(new) do
      if c ~= cur[j] then c.o.oTq, c.o.odepth, c.o.okey = place[j][1], place[j][2], place[j][3] end
    end
  end
  return kept
end

--- Toutes les options du plan courant.
function Ca.options(ctx, plan, req)
  local D = ctx.D
  local out = {}
  ctx.power_block = {}
  ctx.ds = {}
  ctx.sat = {} -- lot COUVERTURE : verdict de saturation par gisement (id -> { ok, why }), dernier passage
  for _, i in ipairs(req.list) do
    local Ri = req.R[i] or 0
    if Ri > 0 then
      local def = Ri - (plan.N[i] or 0) - (ctx.stock[i] or 0) / Ca.H_STOCK
      if D.res[i] then
        extraction_options(ctx, plan, req, i, def, out)
      else
        local r = req.rec[i]
        if not r then
          if def > Ca.EPS then refuse(ctx, "objet:" .. i, "chaine", i, req.why[i] or "aucune recette") end
        else
          fabric_options(ctx, plan, req, i, r, def, out)
        end
      end
    end
  end
  -- Lot COUVERTURE : les ressources dont le besoin net est nul (stock de plaques, puits fermé) gardent leurs gisements revendiqués saturés.
  if ctx.input.saturation then
    for _, i in ipairs(sorted_keys(ctx.dep_by_res)) do
      if D.res[i] and (req.R[i] or 0) <= 0 then extraction_options(ctx, plan, req, i, 0, out, true) end
    end
  end
  lab_options(ctx, plan, out)
  power_options(ctx, plan, out)
  Lv.options(Ca, ctx, plan, req, out) -- lot LEVIERS : modules dans les machines posées, recherches à effet
  if Ca.PORTE_RANG and Ca.RANG and ctx.rang then out = rank_gate(ctx, plan, req, out) end -- lot VIDEO-L2 (allumé à l'étape 8)
  out = Pf.gate(out, ctx.input.excl, { labos = plan.labs }, function(k, kd, it, w) refuse(ctx, k, kd, it, w) end) -- lot VIDEO-PLAFONDS : exclusion (V99), plafond de sûreté des laboratoires (G02, G03, G64)
  table.sort(out, function(a, b) return Ca.before(a.o, b.o) end)
  -- Lot GISEMENTS (DC 31/10 : « la gestion des ressources […] on doit l'appliquer à toutes les ressources ») : la matière la plus en manque
  -- par rapport au besoin passe devant (cuivre, pierre, charbon comme le fer) ; laboratoires, courant et leviers gardent leur place.
  if Ca.SCARCE_FIRST then
    local theta = {}
    for _, i in ipairs(req.list) do
      local Ri = req.R[i] or 0
      if Ri > 0 then theta[i] = ((plan.N[i] or 0) + (plan.hand[i] or 0) + (ctx.stock[i] or 0) / Ca.H_STOCK) / Ri end
    end
    out = Gi.reorder(out, function(c)
      local it = c.o.item
      if it == nil or theta[it] == nil or not (c.o.kind == "couvrir" or c.o.kind == "ouvrir" or c.o.kind == "chaine" or c.o.kind == "fours") then return nil end
      return Gi.band(theta[it])
    end)
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- 9. Décision
---------------------------------------------------------------------------------------------------
--- Stock libre (MU) : ce qui dépasse le tampon de Ca.H_BUF minutes de besoin, pour les seuls objets CONVERTIBLES.
local function free_stock_mu(ctx, req)
  local v = 0
  local res = ctx.reserve
  for _, k in ipairs(sorted_keys(ctx.stock)) do
    local m = ctx.D.mu[k]
    if m and Ca.convertible(ctx, k) then
      local have = ctx.stock[k] or 0
      -- Lot INDUSTRIE I1 : le stock libre est ce qui reste une fois le besoin payé (au plus le stock d'aujourd'hui) ; le tampon des
      -- chaînes en marche (H_BUF minutes de leur consommation) reste un besoin.
      if res then have = math.min(have, (res.free or {})[k] or 0) end
      v = v + math.max(0, have - (req.R[k] or 0) * Ca.H_BUF) * m
    end
  end
  return v
end

--- PRÉDICAT PARTAGÉ « ce qui débloque un manque » (lots AGEBLOCAGE, étage chantiers, et EFFONDREMENT, CORR-CHAMP-MANQUE ; accord du
--- lead du 5/11 : un seul prédicat pour les deux verrous de la capitalisation). Matières qui MANQUENT aux ordres ouverts (o.missing,
--- n > 0) et leurs ingrédients DIRECTS dans les recettes du jeu (D.producers, D.recipes ; sans fluide) : { [objet] = vrai }.
--- ctx = { open = { { missing = { {objet, n} } } }, D = { producers, recipes } }. Mesurés :
---   - AGEBLOCAGE (journal lot-guide-271828182 de DEPENSES2, 4 ouvriers) : 4 ordres ouverts bloqués en « matériaux » retenaient tout le
---     budget de bras de la minute 20 à 59 ; la chaîne des circuits qui les aurait débloqués ne sortait qu'à la minute 60 ;
---   - EFFONDREMENT (partie du DC 717152950 en 0.6.51, fo-logs/2026-11-05_EFFONDREMENT/RAPPORT.md §2 bis) : 2 modules qui attendaient
---     du fer tenaient les 2 emplacements du plan directeur de 11 à 31 min ; la foreuse de fer était refusée « plan directeur occupe »
---     (12 foreuses de fer contre 18 à 28 dans la partie 0.6.50).
function Ca.blocked_items(ctx)
  local out = {}
  local D = ctx and ctx.D
  for _, o in ipairs((ctx and ctx.open) or {}) do
    for _, m in ipairs(o.missing or {}) do
      local it = m[1]
      if it and (m[2] or 0) > 0 then
        out[it] = true
        for _, rn in ipairs((D and D.producers and D.producers[it]) or {}) do
          local r = D.recipes and D.recipes[rn]
          for _, i in ipairs((r and r.ingredients) or {}) do
            if not i.fluid then out[i.name] = true end
          end
        end
      end
    end
  end
  return out
end

--- Une option (ou un module, un champ) DÉBLOQUE-t-elle un manque ? Vrai si ce qu'elle fait (o.item, o.product) ou la ressource qu'elle
--- extrait (o.resource) est dans `blocked` (Ca.blocked_items). Aucune condition de genre : chaque règle choisit où elle l'applique
--- (AGEBLOCAGE : les chaînes, hors du budget de bras ; EFFONDREMENT : les champs, au siège +1 des emplacements).
function Ca.unblocks(o, blocked)
  if o == nil or blocked == nil then return false end
  return (o.item ~= nil and blocked[o.item] == true) or (o.product ~= nil and blocked[o.product] == true)
    or (o.resource ~= nil and blocked[o.resource] == true)
end

--- Lot CORR-CHAMP-MANQUE (relecture du lead, 18 h 10, point 2) : SECOND prédicat, celui du SIÈGE du complément (règle 8 de
--- shared/ai3/emplacements.lua). Ca.blocked_items reste celui d'AGEBLOCAGE, tel quel : ses chaînes ont besoin de tout l'ensemble,
--- circuits et câbles compris. Pour le siège, les ingrédients DIRECTS penchent vers le fer : un module qui attend des circuits manque
--- en fait de CUIVRE, par le câble. Ici :
---   - on prend le coût BRUT des manques des ordres ouverts (book:plan : recettes de la main du LIVRE donné ; le livre d'une force
---     n'a que ses recettes ouvertes, D.producers les a toutes) ;
---   - on retire le stock libre des plaques ;
---   - on garde les seules plaques `names`.
--- Rend UNE plaque, celle du plus grand déficit (égalité : l'ordre de `names`), ou nil ; second retour : { [plaque] = déficit }.
--- ctx = {
---   open : ordres ouverts, chacun avec missing = { { objet, n } } ;
---   book : livre (shared/team/book.lua) ;
---   names : plaques, dans l'ordre ;
---   free : { [plaque] = n } ;
---   prev : la plaque rendue la fois d'avant (hystérésis, Ca.SEAT_MARGIN), ou nil }.
--- Pur : aucune API Factorio, le livre est donné par l'appelant.
Ca.SEAT_MARGIN = 25 -- % : seconde relecture, point 2 : la plaque qui tient le siège le garde tant que l'autre ne la dépasse pas de plus

function Ca.seat_plate(ctx)
  local def = {}
  local book = ctx and ctx.book
  if not book then return nil, def end
  local wants = {}
  for _, o in ipairs(ctx.open or {}) do
    for _, m in ipairs(o.missing or {}) do
      if m[1] ~= nil and (m[2] or 0) > 0 then wants[#wants + 1] = { m[1], m[2] } end
    end
  end
  if #wants == 0 then return nil, def end
  local stock = {}
  for _, n in ipairs(ctx.names or {}) do stock[n] = math.max(0, (ctx.free or {})[n] or 0) end
  local raw = book:plan(wants, stock).raw
  local best, bv = nil, 0
  for _, n in ipairs(ctx.names or {}) do
    local v = raw[n] or 0
    def[n] = v
    if v > bv then best, bv = n, v end
  end
  -- Seconde relecture (revue-depenses2, point 2) : HYSTÉRÉSIS. La plaque qui tenait le siège (ctx.prev) le garde tant qu'elle manque
  -- encore et que la meilleure ne la dépasse pas de plus de Ca.SEAT_MARGIN % ; sinon la porte des foreuses basculerait fer, cuivre,
  -- fer d'une minute à l'autre sur deux déficits proches. (Entiers : best × 100 <= prev × (100 + marge).)
  local prev = ctx.prev
  local pv = prev ~= nil and def[prev] or nil
  if best ~= nil and pv ~= nil and pv > 0 and best ~= prev and bv * 100 <= pv * (100 + Ca.SEAT_MARGIN) then best = prev end
  return best, def
end

--- La décision d'un cycle. input = {
---   data (Ca.data), state = { techs = { [techno] = vrai }, known = { [ressource] = vrai } (absente : toutes) },
---   stock = { [objet] = n }, flows = { [objet] = { made = /min arrivés au QG (toutes sources), hand = /min faits ou minés à
---   la main } }, machines = { { entity, recipe, n, where = "qg" ou id de gisement } }, drills = { { entity, resource, n,
---   deposit } }, labs = { { entity, n } }, deposits = { { id, resource, tiles, amount (nil : inconnue), covered (tuiles
---   sous une foreuse, facultatif), dist, open, smelt, smelter (fonte sur place), danger } } (ouverts et connus),
---   open = { ordres en cours, tels que rendus par Ca.decide, + n_left, smelt_left (reste à poser), missing = { {objet,
---   n} }, work_left (PNJ-s) }, sinks = { { item, rate, want, elastic } }, need = { [objet] = n } (buts, SANS les buts
---   capi ni le but de recherche), research = { queue = { { tech, left, time, packs = { {pack, n} } } }, rate (s de
---   laboratoire / min mesurées), starved (‰ de laboratoires affamés) }, power = { have_kw, used_kw, plant = { kw,
---   items, burner_kw } } (facultatif), site_items, drill_extra, machine_extra = { {objet, n} } (pièces de
---   l'exécutant), limits = { max_ingredients }, workers, idle (PNJ sans tâche : Ca.idle_of(Br.smooth)), can_grow,
---   traits, weights, threat, dt (min), lag (délai de pose mesuré, min), obtainable (fonction ou table),
---   solid_mesure (vrai : `flows` est un débit MESURÉ ; lot CONSOLIDATION-TIERS, la porte de rang attend la consolidation des tiers) }.
--- st : état persistant de la règle (nombres et tables : bank, T_hist, sink_t, u_target). Rend { orders, refus,
--- explore, s, delta, alpha, tmax, g, lambda, Y, K, budget, bank, flow_part, stock_part, spent, labor, labor_used,
--- u_star, labs_target, coverage, bottleneck, R, open_n }.
--- Lot CAPI-DECIDE (7/11 ; critères : fo-logs/2026-11-07_CAPI-DECIDE/CRITERES.md) : la décision en UNITÉS de travail, reprenable.
--- J = travail en cours, table EN MÉMOIRE seulement (contexte, plan, besoins, ordres : des références au livre de données D, jamais
--- dans global). Unité 1 : Ca.decide_begin (contexte, plan, besoins, budget) ; puis Ca.decide_step : un tour de la boucle des ordres
--- par appel, puis le compte rendu (J.res). Ca.decide enchaîne toutes les unités d'un appel : même calcul, même ordre qu'avant.
--- `st` est écrit par prepare (dm, sink_t, u_target) et par le compte rendu (bank, T_hist) : l'appelant qui découpe passe une COPIE.
function Ca.decide_begin(input, st)
  st = st or {}
  local ctx = prepare(input, st)
  local J = { st = st, ctx = ctx, units = 1, turn = 0, orders = {} }
  if Ca.PORTE_RANG then ctx.last_item = st.last_item end -- lot VIDEO-L2 : anti-répétition d'une décision à l'autre
  J.plan = new_plan(ctx)
  J.req = Ca.requirements(ctx, J.plan)
  J.free_mu = free_stock_mu(ctx, J.req)
  J.budget, J.bank, J.stock_part = Ca.budget(ctx.ch, ctx.Y, J.free_mu, ctx.dt, st.bank, ctx.reserve)
  J.b_left, J.l_left, J.work_used = J.budget, ctx.labor, 0
  -- Lot AGEBLOCAGE, étage chantiers (prédicat partagé ci-dessus) : une option de CHAÎNE (rangée d'assembleurs) qui débloque un ordre
  -- ouvert ne passe pas par le budget de BRAS : les bras sont retenus par ces ordres mêmes, qui attendent sa matière. Elle reste
  -- bornée par le budget de matières et par la règle du goulot amont (Ca.options).
  J.blocked = Ca.blocked_items(ctx)
  -- Lot VIDEO-L13 (garde fermée par défaut) : la LISTE d'entrée, pas ctx.open (sort_by en fait {} quand elle manque : la garde
  -- s'ouvrirait sur une entrée absente). Liste présente : même nombre de places et même texte qu'avant.
  local room, why_open = Pf.open_room(input.open, Ca.OPEN_MAX)
  if room <= 0 then refuse(ctx, "capi", "capi", nil, why_open) end
  J.turns = math.min(Ca.MAX_ORDERS, math.max(0, room))
  -- Lot VIDEO-L13 : registre des plafonds de la décision (mémoire seulement, jamais dans st ni dans global).
  J.caps = Pf.ledger(Ca.cap_states(ctx, J.plan, J.req))
  return J
end

--- Lot VIDEO-L13 : relevé du plafond de chaque objet demandé (R > 0) : demande, posé nominal de tous les états (P, NP), ordres
--- ouverts (O, NO). Rend { [objet] = { demand, posed, open, n_posed, n_open } }.
function Ca.cap_states(ctx, plan, req)
  local out = {}
  for _, i in ipairs(req.list) do
    local Ri = req.R[i] or 0
    if Ri > 0 then
      out[i] = { demand = Ri, posed = plan.P[i] or 0, open = plan.O[i] or 0, n_posed = plan.NP[i] or 0, n_open = plan.NO[i] or 0,
        hard = Ca.cap_hard(ctx, req, i) }
    end
  end
  return out
end

--- Lot TV-PILOTE (G02) : plafond de sûreté d'un objet, selon la SORTE d'ordre qui le fabrique (la même règle que fabric_options : la
--- machine choisie donne la sorte ; sans machine disponible, la catégorie de la recette). Un objet sans recette (extraction) garde
--- Ca.CAP_HARD. Données : Pf.HARD_OBJ.
function Ca.cap_hard(ctx, req, item)
  local r = req and req.rec and req.rec[item]
  if not r or (ctx.input and ctx.input.hard_off) then return Ca.CAP_HARD end -- (input.hard_off : réglage fo-war-plafonds éteint, script/ai3/pilotage.lua)
  local D = ctx.D
  local m = best_maker(ctx, r.category)
  local kind
  if m then kind = m.assembler and (D.packs[item] and "packs" or "chaine") or "fours"
  else kind = (D.hand[r.category] and (D.packs[item] and "packs" or "chaine")) or "fours" end
  return math.min(Ca.CAP_HARD, Pf.hard_obj(kind))
end

--- Lot VIDEO-L13 : la demande suit les besoins recalculés après chaque ordre (le combustible des machines décidées) ; un objet
--- devenu demandé entre au registre avec son posé et ses ordres ouverts (aucun ordre de la décision ne l'a encore touché).
local function caps_refresh(J)
  local R, plan = J.req.R, J.plan
  for _, i in ipairs(sorted_keys(J.caps)) do J.caps[i].demand = R[i] or 0 end
  for _, i in ipairs(J.req.list) do
    if J.caps[i] == nil and (R[i] or 0) > 0 then
      J.caps[i] = { demand = R[i], posed = plan.P[i] or 0, open = plan.O[i] or 0, n_posed = plan.NP[i] or 0,
        n_open = plan.NO[i] or 0, hard = Ca.cap_hard(J.ctx, J.req, i) }
    end
  end
end

--- Étape 5a de VIDEO-INTEG : kW nominaux des machines et foreuses électriques que le courant a retenues (ctx.power_block du dernier
--- tour : état final du plan). La centrale en tient compte pour grandir AVANT d'être saturée (shared/team/sante_centrale.lua,
--- S.capi_kw) : sans cela, la décision attend du courant et la centrale attend une saturation qui ne vient pas.
function Ca.blocked_kw(ctx)
  local kw = 0
  for _, b in ipairs(ctx.power_block or {}) do kw = kw + (b.kw or 0) end
  return kw
end

--- Lot VIDEO-L5 : raison de suspendre l'option `o` (une unité de son objet attend sa première production), ou nil.
function Ca.held(ctx, o)
  local h = ctx.input.hold
  if h == nil or not Ca.HOLD_KINDS[o.kind] or o.item == nil then return nil end
  return h[o.item] or Cf.upstream(h, o.recipe and ctx.D.recipes[o.recipe] or nil, o.recipe and o.item or nil) -- C5.2 : le module N+1 attend la 1re production de N
end

--- Lot VIDEO-L13 (garde fermée par défaut) : listes sans lesquelles la règle ne décide pas. Une liste absente ne vaut jamais
--- « rien de posé » (les « silos sans fin » de la vidéo : une entrée à 0 laissait le manque vrai pour toujours).
Ca.INPUT_LISTS = { "machines", "drills", "stock", "open" }

--- Première liste d'entrée absente (pas une table), dans l'ordre de Ca.INPUT_LISTS ; nil quand toutes sont là. Le runtime refuse
--- alors la décision (script/ai3/capitalisation.lua, decide_start).
function Ca.absent_input(input)
  if type(input) ~= "table" then return "entree" end
  for _, k in ipairs(Ca.INPUT_LISTS) do
    if type(input[k]) ~= "table" then return k end
  end
  return nil
end

--- Lot VIDEO-L13 : l'option passe-t-elle le plafond de son objet ? (sortes non plafonnées : oui ; entrée absente : non)
local function cap_ok(J, o)
  if not Ca.CAPPED[o.kind] then return true end
  return Pf.fits_item(J.caps, o.item, { rate = o.rate, n = o.n })
end

local function fits(J, o)
  return o.cost_m <= J.b_left + Ca.EPS
    and ((o.work or 0) <= J.l_left + Ca.EPS or (o.kind == "chaine" and Ca.unblocks(o, J.blocked)))
    and cap_ok(J, o)
end

--- Lot TV-ENERGIE (c, accord du lead, 8/11 : « les kW libres ne suffisent pas à tous les ordres électriques d'une décision : répartis par ordre de
--- manque, chaque objet en manque reçoit son premier lot avant qu'un autre en reçoive un second, départage écrit, aucun nom d'objet »).
--- entries = { { key, item, kw (par machine), n (voulues), short (manque, /min) } } ; free = kW libres. Rend allot[key] = machines accordées et
--- l'ordre de service { items }. Ordre : manque décroissant, puis nom de l'objet croissant (départage), puis clé. Un TOUR donne UNE machine à
--- chaque objet (à sa première option non servie qui tient dans les kW restants) ; on tourne tant qu'un tour accorde quelque chose.
-- Décision du lead (8/11, 13 h 20) : « aucun minerai ne prend plus de 60 % des kW libres tant qu'un autre minerai demandé attend du courant ».
-- Appliquée en deux temps : TANT QU'un autre objet attend (en phase 1), un objet ne dépasse pas Ca.KW_SHARE_MAX des kW libres ; ce qui reste
-- ensuite (phase 2) va à qui en veut encore, plafond levé (personne d'autre n'attend plus).
Ca.KW_SHARE_MAX = 0.6

function Ca.kw_alloc(entries, free)
  local by_item, items = {}, {}
  for _, e in ipairs(entries) do
    local g = by_item[e.item]
    if not g then
      g = { item = e.item, short = e.short or 0, list = {} }
      by_item[e.item] = g
      items[#items + 1] = g
    end
    if (e.short or 0) > g.short then g.short = e.short end
    g.list[#g.list + 1] = e
  end
  table.sort(items, function(a, b)
    if a.short ~= b.short then return a.short > b.short end
    return tostring(a.item) < tostring(b.item)
  end)
  for _, g in ipairs(items) do
    table.sort(g.list, function(a, b) return tostring(a.key) < tostring(b.key) end)
  end
  local allot, used = {}, {}
  for _, e in ipairs(entries) do allot[e.key] = 0 end
  for _, g in ipairs(items) do used[g.item] = 0 end
  local left = free
  local cap = (#items >= 2) and (Ca.KW_SHARE_MAX * free) or math.huge -- un seul objet : aucun autre n'attend, pas de plafond
  for phase = 1, 2 do
    repeat
      local given = false
      for _, g in ipairs(items) do
        for _, e in ipairs(g.list) do
          if allot[e.key] < e.n and e.kw <= left + Ca.EPS and (phase == 2 or used[g.item] + e.kw <= cap + Ca.EPS) then
            allot[e.key] = allot[e.key] + 1
            used[g.item] = used[g.item] + e.kw
            left = left - e.kw
            given = true
            break
          end
        end
      end
    until not given
  end
  local order = {}
  for _, g in ipairs(items) do order[#order + 1] = g.item end
  return allot, order
end

--- Applique la répartition aux options d'un tour (avant le choix) : si les kW libres couvrent tous les ordres électriques, rien ne change
--- (identité). Sinon chaque option est ramenée à sa part (Ca.kw_alloc) par sa fonction de taille ; une option sans part est retirée avec le refus
--- écrit. Rend la liste (même ordre).
function Ca.share_kw(ctx, plan, opts)
  local pw = ctx.input.power
  if not pw or pw.fermee or (plan.amorce_left or 0) > 0 or ctx.kw_share_off then return opts end
  local free = (plan.kw_have or 0) - (plan.kw_used or 0)
  local entries, total = {}, 0
  for _, c in ipairs(opts) do
    local o = c.o
    if o.kw_unit and o.kw_unit > 0 and (o.n or 0) > 0 then
      entries[#entries + 1] = { key = o.key, item = o.item or o.resource or "?", kw = o.kw_unit, n = o.n, short = o.short or 0 }
      total = total + o.kw_unit * o.n
    end
  end
  if #entries < 2 or total <= free + Ca.EPS then return opts end
  local allot, order = Ca.kw_alloc(entries, free)
  local out = {}
  for _, c in ipairs(opts) do
    local o = c.o
    local a = o.kw_unit and allot[o.key]
    if a == nil or a >= o.n then
      out[#out + 1] = c
    elseif a >= 1 and c.mk then
      local o2 = c.mk(a)
      if o2 then
        o2.why = tostring(o2.why or "") .. string.format(" ; kW partages : %d machine(s) sur %d voulues", a, o.n)
        out[#out + 1] = { o = o2, mk = c.mk }
      end
    else
      refuse(ctx, o.key, o.kind, o.item, string.format(
        "courant insuffisant : repartition des kW par ordre de manque (manque egal : ordre alphabetique des objets) : %d kW libres, ordre de service %s, il en faut %d",
        math.floor(free + 0.5), table.concat(order, " > "), math.floor(o.kw_unit + 0.5)))
    end
  end
  return out
end

--- Un tour de la boucle des ordres : rend faux si aucun ordre ne passe (la boucle s'arrête).
local function decide_turn(J)
  local ctx, plan = J.ctx, J.plan
  local opts = Ca.share_kw(ctx, plan, Ca.options(ctx, plan, J.req)) -- lot TV-ENERGIE (c) : kW libres répartis par ordre de manque
  local pick = nil
  for _, c in ipairs(opts) do
    local o = c.o
    local hold = Ca.held(ctx, o) -- lot VIDEO-L5 : une unité de cet objet attend sa première production
    if hold then
      refuse(ctx, o.key, o.kind, o.item, "confirmation : " .. hold)
    else
      if fits(J, o) then pick = o break end
      -- Trop grand pour le budget, les bras ou le plafond : la plus grande taille qui passe (dichotomie ; le coût et le débit
      -- croissent avec la taille). Les bras règlent le rythme, pas la taille du capital.
      if c.mk and o.n > 1 then
        local lo, hi, best = 1, o.n - 1, nil
        while lo <= hi do
          local mid = math.floor((lo + hi) / 2)
          local o2 = c.mk(mid)
          if o2 and fits(J, o2) then best, lo = o2, mid + 1 else hi = mid - 1 end
        end
        if best then pick = best break end
      end
      local why
      if o.cost_m > J.b_left + Ca.EPS then why = string.format("budget : %s MU > %s", fmt(o.cost_m), fmt(J.b_left))
      elseif (o.work or 0) > J.l_left + Ca.EPS and not (o.kind == "chaine" and Ca.unblocks(o, J.blocked)) then
        why = string.format("bras : %s PNJ-s > %s", fmt(o.work), fmt(J.l_left))
      else
        local _, wc = cap_ok(J, o)
        why = wc or "plafond"
      end
      refuse(ctx, o.key, o.kind, o.item, why)
    end
  end
  if not pick then return false end
  Ca.apply(ctx, plan, pick)
  if Ca.CAPPED[pick.kind] then Pf.take(J.caps, pick.item, { rate = pick.rate, n = pick.n }) end -- lot VIDEO-L13 : décision entière
  ctx.refus[pick.key] = nil
  if Ca.PORTE_RANG then ctx.last_item = pick.item end -- lot VIDEO-L2 : objet du dernier ordre (anti-répétition)
  J.b_left = J.b_left - pick.cost_m
  J.l_left = J.l_left - (pick.work or 0)
  J.work_used = J.work_used + (pick.work or 0)
  J.orders[#J.orders + 1] = pick
  if ctx.dm and pick.dormant_mu then ctx.dm.left = math.max(0, (ctx.dm.left or 0) - pick.dormant_mu) end
  J.req = Ca.requirements(ctx, plan) -- le combustible des machines décidées entre dans la demande
  caps_refresh(J)
  return true
end

--- Compte rendu de la décision (dernière unité).
local function decide_report(J)
  local ctx, plan, req, orders, st = J.ctx, J.plan, J.req, J.orders, J.st
  local budget, bank, stock_part = J.budget, J.bank, J.stock_part
  -- Épargne : le stock libre paie d'abord (il est là), le reste vient de l'épargne du flux.
  local spent = budget - J.b_left
  st.bank = math.max(0, bank - math.max(0, spent - stock_part))
  if Ca.PORTE_RANG then st.last_item = ctx.last_item end -- lot VIDEO-L2 : un nom (rien d'interdit dans global)
  -- Retour moyen (médiane) des ordres de ce cycle : il règle la croissance des cycles suivants.
  if #orders > 0 then
    local ts = {}
    for _, o in ipairs(orders) do ts[#ts + 1] = o.T end
    st.T_hist = st.T_hist or {}
    st.T_hist[#st.T_hist + 1] = median(ts)
    while #st.T_hist > Ca.T_HIST do table.remove(st.T_hist, 1) end
  end
  -- Compte rendu.
  local refus = {}
  for _, k in ipairs(sorted_keys(ctx.refus)) do refus[#refus + 1] = ctx.refus[k] end
  local explore = {}
  for _, k in ipairs(sorted_keys(ctx.explore)) do explore[#explore + 1] = { resource = k, why = ctx.explore[k] } end
  ctx.ds = {}
  local coverage = {}
  for _, f in ipairs(ctx.deposits) do
    local d = ctx.D.res[f.resource] and (best_drill(ctx, f.resource) or ctx.D.drill_by[(ctx.drills_in[1] or {}).entity or ""])
    if d then
      local covered_t, free, kappa = deposit_state(ctx, plan, f, d)
      local key = tostring(f.id)
      coverage[#coverage + 1] = { id = f.id, resource = f.resource, kappa = kappa, free = free,
        open = plan.opened[key] or false, dead = plan.dead[key] or false }
      -- Lot COUVERTURE : tuiles couvertes / tuiles du gisement (journal [FO-SATURATION]) ; seulement quand la saturation est allumée
      -- (le rendu d'avant reste identique sinon).
      if ctx.input.saturation then
        local c = coverage[#coverage]
        c.tiles, c.covered = f.tiles or 0, covered_t
      end
    end
  end
  local bottleneck, theta = nil, nil
  for _, i in ipairs(req.list) do
    local Ri = req.R[i] or 0
    if Ri > 0 then
      local th = ((plan.N[i] or 0) + (plan.hand[i] or 0) + (ctx.stock[i] or 0) / Ca.H_STOCK) / Ri
      if theta == nil or th < theta - 1e-12 then bottleneck, theta = i, th end
    end
  end
  local repli = Lv.repli(Ca, ctx, plan, req, orders) -- lot LEVIERS : pourquoi ces leviers, ou pourquoi aucun
  return { repli = repli, want = Lv.wanted(ctx), unlocks = ctx.lv_unlock or {}, orders = orders, refus = refus, explore = explore, s = ctx.ch.s, delta = ctx.ch.delta, alpha = ctx.ch.alpha,
    tmax = ctx.ch.tmax, g = ctx.g, lambda = ctx.lambda, Y = ctx.Y, K = plan.K, budget = budget, bank = st.bank,
    flow_part = bank, stock_part = stock_part, spent = spent, labor = ctx.labor, labor_used = J.work_used,
    reserve = ctx.reserve and true or nil, free_mu = J.free_mu, demande = ctx.dm,
    barils = ctx.barils_added, -- lot TV-FLUX (G51) : unités de fluide comptées en contenants pleins ce tour (nil : réglage éteint ou aucun contenant)
    u_star = ctx.u_star, labs_target = ctx.lab_rate > 0 and math.ceil(ctx.u_star / ctx.lab_rate - Ca.EPS) or 0,
    coverage = coverage, bottleneck = bottleneck and { item = bottleneck, theta = theta } or nil, R = req.R,
    open_n = #ctx.open, rstar = ctx.rstar, rang_held = ctx.rang_held,
    sat = ctx.input.saturation and ctx.sat or nil, -- lot COUVERTURE : verdict de saturation par gisement (nil : saturation éteinte) -- lot VIDEO-L2 : porte de rang (nil quand elle est éteinte)
    -- lot VIDEO-COUVERTURE 5 (C5.1) : cycles de la décision, graine de l'amorce. Seulement s'il y a un cycle ou une graine (intégrateur,
    -- 7/11 23 h 55) : sinon le champ casserait l'identité de la décision rang allumé / éteint (rang_cablage_test §2) sans rien semer.
    rang_cycles = ctx.rang and (next(ctx.rang.cyc or {}) ~= nil or next(ctx.rang.seed or {}) ~= nil)
      and { seed = ctx.rang.seed, cyc = ctx.rang.cyc } or nil,
    -- Étape 5a de VIDEO-INTEG (RD_LOG F391) : courant du plan quand le runtime donne input.power (sinon nil : rendu d'avant)
    kw = ctx.input.power and { have = plan.kw_have, used = plan.kw_used, nominal = plan.kw_nominal, blocked = Ca.blocked_kw(ctx) } or nil }
end

--- Une unité de plus (un tour de la boucle, ou le compte rendu) ; rend vrai quand la décision est finie (J.res).
function Ca.decide_step(J)
  if J.res then return true end
  J.units = J.units + 1
  if not J.loop_done then
    if J.turn < J.turns then
      J.turn = J.turn + 1
      if not decide_turn(J) then J.loop_done = true end
      return false
    end
    J.loop_done = true
  end
  J.res = decide_report(J)
  return true
end

function Ca.decide(input, st)
  local J = Ca.decide_begin(input, st)
  while not Ca.decide_step(J) do end
  return J.res
end

---------------------------------------------------------------------------------------------------
-- 10. Cerveau et journal
---------------------------------------------------------------------------------------------------
--- Buts du cerveau (shared/ai3/buts.lua, shared/ai3/projets.lua) : un but de FOND par ordre NOUVEAU (res.orders) ou
--- OUVERT (`open`, la liste que le runtime garde jusqu'à la fin de chaque ordre), même clé « capi:<clé> » d'une pensée à
--- l'autre (P.update ferme un projet dont le but disparaît). Famille capital (recherche pour les laboratoires et les
--- packs) ; valeur de l'ordre, gardée (35 à 50). Les ordres sont copiés (aucune fonction : l'état peut aller dans
--- global).
function Ca.goals(goals, res, open)
  local list, seen = {}, {}
  for _, o in ipairs((res and res.orders) or {}) do
    if o.key and not seen[o.key] then seen[o.key] = true list[#list + 1] = o end
  end
  for _, o in ipairs(sort_by(open, function(x) return tostring(x.key) end)) do
    if o.key and not seen[o.key] then seen[o.key] = true list[#list + 1] = o end
  end
  for _, o in ipairs(list) do
    local copy = {}
    for _, k in ipairs(sorted_keys(o)) do
      local v = o[k]
      if type(v) ~= "function" then copy[k] = v end
    end
    local fam = (o.kind == "labos" or o.kind == "packs") and "recherche" or "capital"
    -- Une recherche à effet n'a pas de matière à fabriquer : l'exécutant est le choix de technologie (Ca.techs_wanted).
    -- Lot ELEC2 : `short` (posé par le runtime : ordre qui étend la capacité d'une matière en manque) place le but juste
    -- après les familles permanentes (shared/ai3/projets.lua, P.update, g.invest), devant les autres projets : une
    -- extraction qui se rembourse en quelques minutes passe avant ce qui consomme la matière qu'elle produit. L'armée et les
    -- munitions gardent leur rang, leurs parts restent réservées (Ca.capi_view).
    if o.kind ~= "techno" then goals[#goals + 1] = { key = "capi:" .. o.key, family = fam, kind = "capi", value = o.value or Ca.V_MIN, fond = true,
      invest = (o.short and true) or nil, order = copy } end
  end
  table.sort(goals, function(a, b)
    if a.value ~= b.value then return a.value > b.value end
    return a.key < b.key
  end)
  return goals
end

--- Part du stock virtuel que les projets capi peuvent réserver (P.take) : (1000 − δ − α) ‰ de chaque objet, arrondie en
--- dessous. Les parts de la défense et de l'armée restent réservées même quand elles n'ont rien demandé ce cycle.
function Ca.capi_view(avail, res)
  local keep = 1000 - ((res and res.delta) or 0) - ((res and res.alpha) or 0)
  local free = res and res.free
  local out = {}
  for _, k in ipairs(sorted_keys(avail)) do
    out[k] = math.floor((avail[k] or 0) * keep / 1000)
    -- Lot INDUSTRIE I1 : le besoin est évalué (shared/ai3/reserve.lua) : les projets de la capitalisation voient le stock HORS BESOIN
    -- en entier, plus la part (1000 - δ - α) ‰ qui dormait. Un objet absent de l'évaluation garde la part d'avant.
    if free and free[k] ~= nil then out[k] = math.min(math.floor(avail[k] or 0), math.floor(free[k])) end
    if res and res.zero and res.zero[k] then out[k] = 0 end -- intégration 0.6.30 : le besoin la prend en entier
  end
  return out
end

--- Lot CAPIB (branchement) : émission d'un projet « capi » (shared/ai3/projets.lua, P.EMIT.capi). L'EXÉCUTANT a reçu
--- l'ordre du runtime au moment de la décision (plan directeur, rangées de fours, laboratoires du QG) ; il prend lui-même
--- au coffre ce qui y est. Le projet ne fait que ce qui MANQUE à l'exécutant (g.order.missing = { {objet, n} }, relu à
--- chaque pensée par le runtime) : fabriquer à la main, fondre, miner, depuis la PART CAPI du stock virtuel
--- (Ca.capi_view : les parts de la défense et de l'armée restent à leurs familles, même si elles n'ont rien demandé).
--- Statut : « bloque » (raison de l'exécutant), « matiere » (il manque des objets), sinon « en_cours ».
--- ctx.capi = { res } (la décision du cycle : δ et α) ; sans elle, la part entière.
function Ca.emit(P)
  return function(E, proj, g, ctx)
    local o = (g and g.order) or {}
    if o.blocked then return "bloque", "capi:" .. tostring(o.blocked) end
    local miss = o.missing or {}
    if #miss == 0 then return "en_cours" end
    local res = ctx and ctx.capi and ctx.capi.res or nil
    local full = E.avail
    local view = Ca.capi_view(full, res)
    local held = {}
    for _, k in ipairs(sorted_keys(full)) do held[k] = (full[k] or 0) - (view[k] or 0) end
    E.avail = view
    P.want_kit(E, proj, miss, proj.prio, "capi") -- lot POSE-PAR-LOTS : le manque fabricable de l'exécutant en KITS
    local after = E.avail
    local merged = {}
    for _, k in ipairs(sorted_keys(after)) do merged[k] = (after[k] or 0) + (held[k] or 0) end
    for _, k in ipairs(sorted_keys(held)) do
      if merged[k] == nil then merged[k] = held[k] end
    end
    E.avail = merged
    return "matiere"
  end
end

--- Ligne de journal (ASCII) : « [FO-CAPI] <faction> minute M » + ce texte, côté runtime.
function Ca.text(res)
  local parts = {}
  local rp = res.repli and (" repli=[" .. res.repli.text .. "]") or ""
  if res.reserve then rp = rp .. string.format(" reserve=[besoin evalue ; stock libre %s MU, investi sans pourcentage]", fmt(res.free_mu or 0)) end
  for _, o in ipairs(res.orders) do
    parts[#parts + 1] = string.format("%s %s x%d T=%s v=%d%s", o.kind, tostring(o.item or o.key), o.n or 1, fmt(o.T), o.value or 0,
      (o.def_mu or 0) > 0 and (" defense " .. fmt(o.def_mu) .. " MU") or "") -- lot PREVISION : défense induite comptée
  end
  local rf = {}
  for i = 1, math.min(6, #res.refus) do rf[#rf + 1] = res.refus[i].key .. " (" .. res.refus[i].why .. ")" end
  local cov = {}
  for _, c in ipairs(res.coverage) do
    if c.open then cov[#cov + 1] = string.format("%s %s %d/1000 libres %d", tostring(c.id), c.resource, c.kappa, c.free) end
  end
  return string.format("s=%d d=%d a=%d Tmax=%s g=%d Y=%s K=%s budget=%s/%s (epargne %s stock %s) bras=%s/%s lambda=%s "
    .. "recherche=%s labos=%d ouverts=%d goulot=%s ordres=[%s] gisements=[%s] refus=[%s]",
    res.s, res.delta, res.alpha, fmt(res.tmax), res.g, fmt(res.Y), fmt(res.K), fmt(res.spent), fmt(res.budget),
    fmt(res.bank), fmt(res.stock_part), fmt(res.labor_used), fmt(res.labor), fmt(res.lambda), fmt(res.u_star),
    res.labs_target, res.open_n or 0, res.bottleneck and (res.bottleneck.item .. " " .. fmt(res.bottleneck.theta)) or "-",
    table.concat(parts, ", "), table.concat(cov, ", "), table.concat(rf, ", ")) .. rp
    -- Lot VIDEO-L2 : la porte de rang (interrupteur éteint : rien d'écrit, la ligne est celle d'avant).
    .. ((res.rstar ~= nil or (res.rang_held or 0) > 0) and string.format(" porte=[r*=%s retenus=%d]", tostring(res.rstar), res.rang_held or 0) or "")
end

--- Recherches à effet retenues (res.orders de la sorte « techno ») ou ouvertes : { [technologie] = valeur (35 à 50) }.
function Ca.techs_wanted(res, open)
  local out = {}
  for _, o in ipairs((res and res.orders) or {}) do
    if o.kind == "techno" and o.tech then out[o.tech] = o.value or Ca.V_MIN end
  end
  for _, o in ipairs(open or {}) do
    if o.kind == "techno" and o.tech and out[o.tech] == nil then out[o.tech] = o.value or Ca.V_MIN end
  end
  return out
end

-- Aides de la règle pour shared/ai3/leviers.lua (même état de décision, pas de second chemin de calcul).
Ca.H = { refuse = refuse, items_mu = items_mu, work_of = work_of, finish = finish, cand = cand, best_drill = best_drill,
  lab_share = lab_share }

return Ca
