--[[
  Lot CAPI « la capitalisation des factions » (demandes du DC du 27/10, 12 h 05 : « le scaling des IA est aussi et surtout
  dans la maximisation des gisements, de la fonte et des crafts […] c'est le concept de capitalisation qu'il faut
  implémenter », « Et concernant la recherche IA ? » ; 12 h 15 : « A ne pas oublier toute la partie plus de gisements.
  Plus de fours (dans la limite de ce qu'on peut faire fondre évidemment), si assembleurs disponibles alors on ajoute des
  chaînes de production etc etc. »). Conception : docs/IA_CAPITALISATION.md. PUR (aucune API Factorio), testé hors jeu
  (tests/ai3_capitalisation_test.lua). RIEN N'EST BRANCHÉ EN JEU dans ce lot.

  Ce qu'un joueur fait : il RÉINVESTIT sa production dans plus de capacité de production, là où elle rapporte le plus vite
  et seulement là où ce qu'elle produit a un débouché. Il couvre ses gisements de foreuses puis en ouvre d'autres, met
  autant de fours que son minerai en nourrit (jamais plus), monte des rangées d'assembleurs dès qu'il en a, fait grandir
  ses laboratoires et sa production de packs avec la recherche. Sa capacité croît comme un capital qui rapporte.

  En calcul, à chaque cycle (Ca.decide) :
    1. DÉBITS UNITAIRES lus dans les DONNÉES (Ca.data, relevé des prototypes au format de shared/ai3/catalogue.lua plus
       vitesses, aires de minage, puissances, temps de minage) : foreuse 60 × vitesse × (1 + bonus) ÷ temps de minage ;
       machine 60 × vitesse ÷ durée de la recette × quantités ; laboratoire 60 × vitesse × (1 + bonus) secondes de
       recherche par minute ; combustible kW × 60 ÷ pouvoir calorifique. Valeur des objets (MU) : point fixe min-plus
       (ressource = Ca.RAW_MU × temps de minage ; recette = ingrédients + Ca.TIME_MU par seconde de fabrication).
    2. DEMANDE (objets/min) aux PUITS : besoin des buts (÷ Ca.H_GOALS), puits mesurés (armée, munitions…), matières des
       ordres ouverts (le capital fabrique le capital, ÷ Ca.H_B), packs de la recherche visée, combustible des machines à
       combustion. Les puits ÉLASTIQUES (recherche tant qu'il reste des technologies, puits marqués `elastic`) visent
       (1 + g) × leur débit, g = s ÷ T̄ (‰ par cycle, au plus Ca.G_MAX), jamais plus de Ca.LEAD fois ce qui tourne.
       Sans puits élastique : g = 0 (saturation GLOBALE, la seule qui arrête tout).
    3. BESOIN par objet : demande propagée dans le graphe des recettes (recette choisie dans les données, ordre de
       profondeur décroissant ; un objet ne transmet à son amont que son besoin NET de son stock) : R_i. Capacité
       planifiée N_i : machines posées, ordres ouverts, ordres de ce cycle ; la MAIN n'est pas du capital (elle nourrit
       les machines aujourd'hui, elle ne compte pas dans N_i). Manque d_i = R_i − N_i − stock_i ÷ Ca.H_STOCK (un stock
       qui dort couvre son débit ; sans débouché R_i = 0).
    4. OPTIONS par levier (aucun nom, aucune table par bâtiment) :
         couvrir  : foreuses sur un gisement OUVERT qui a des places (peigne de paires face à un tapis, géométrie lue
                    sur la foreuse : Ca.comb) ;
         ouvrir   : un gisement CONNU de plus quand les ouverts sont couverts (Ca.KAPPA ‰ des tuiles, ou plus aucune
                    place) et qu'il manque, ou d'avance (épuisement en moins de Ca.H_LIFE, réserve de places sous
                    Ca.RESERVE_PCT % de la demande, site moins cher par débit) ; sans site connu : exploration ;
         fours    : fabriques d'une catégorie que la main ne fait pas, nourries par le minerai ARRIVÉ (mesuré) : jamais
                    plus que ce qu'il nourrit (Ca.fed_max : ⌊x⌋ + [frac ≥ 0,9], x = (arrivée + stock ÷ H − consommation)
                    ÷ consommation d'un four) ;
         chaine   : rangée d'assembleurs (fabrique d'une catégorie de la main) DÈS qu'une machine est disponible
                    (exécutable, recherchée, fabricable) ; packs : la même chose pour une entrée de laboratoire ;
                    l'aval d'un ingrédient en manque ATTEND (goulot amont d'abord) ;
         labos    : laboratoires pour la recherche visée, jamais plus que les packs ne nourrissent ;
         energie  : centrale quand des machines électriques rentables manquent de courant ;
         ameliorer: les candidats du lot CAPITAL (coût et gain donnés), rangés avec les autres.
    5. COÛT C = matières (MU) + λ × travail (PNJ-min ; λ = 0 quand des bras sont libres) ; GAIN G (MU/min) = part UTILE
       de l'ajout (au plus le manque ; Ca.AHEAD_PCT % pour un débit d'avance) × valeur PLEINE de l'objet (un ingrédient
       en manque arrête toute la chaîne en aval ; une seconde de recherche vaut ses packs et son temps) × poids de la
       famille, plus les bras libérés de la main, moins le combustible ; RETOUR T = C ÷ G ; accepté si T ≤ T_max.
    6. CHOIX GLOUTON : la meilleure option (T, profondeur, clé), appliquée au plan, puis TOUT est recalculé (gain
       marginal : chaque levier plafonne de lui-même), tant que le BUDGET matières (s × production libre de la part
       armée et défense + stock libre) et le BUDGET de bras le permettent.
  Caractère (traits d'IA2-0, poids d'IA2-a) : s (part réinvestie), δ (défense), α (armée), T_max ; menace : T_max ÷ 4,
  δ double, seuls les leviers du QG restent ouverts.

  Aucun nom du jeu ici (test anti-échelle, tests/iag_test.lua §8) : objets, recettes, machines et ressources viennent du
  relevé. Déterminisme : listes triées, flottants calculés dans un ordre fixe, égalités départagées par la clé, aucun
  hasard, aucun pairs décisionnel ; l'état persistant `st` ne garde que des nombres et des tables.
]]

local R = require("shared.ai3.reglages") -- types du moteur -> rôle (seules données nommées admises)

local Ca = {}

-- Valeurs (MU, unité de la règle X0 : une unité de ressource d'une seconde de minage vaut 1).
Ca.RAW_MU = 1           -- MU d'une ressource par seconde de minage (temps de minage du prototype)
Ca.TIME_MU = 0.1        -- MU d'une seconde de fabrication à vitesse 1 (valeur ajoutée d'une recette, d'un laboratoire)
-- Horizons (minutes).
Ca.H_GOALS = 10         -- besoin des buts servi en 10 min
Ca.H_STOCK = 10         -- un stock couvre son débit pendant 10 min (stock fondu en 10 min, pas plus vite)
Ca.H_BUF = 5            -- tampon gardé au stock ; au-delà, le stock est LIBRE et s'investit
Ca.H_B = 10             -- matières des ordres ouverts fabriquées en 10 min (programme d'équipement)
Ca.H_R = 20             -- file de recherche visée en 20 min au plus
Ca.H_FUEL = 30          -- combustible compté sur 30 min dans le choix d'une machine
Ca.H_LIFE = 60          -- gisements ouverts épuisés en moins de 60 min : ouvrir le suivant d'avance
-- Gisements.
Ca.KAPPA = 800          -- ‰ des tuiles sous une foreuse : gisement couvert (critère (1) du DC, 27/10, 12 h 30)
Ca.RESERVE_PCT = 25     -- places libres de débit inférieur à 25 % de la demande : ouvrir le suivant d'avance
Ca.OPEN_RATIO = 120     -- % : un site neuf 20 % moins cher par débit que couvrir l'ancien : l'ouvrir
Ca.OPEN_MIN = 2         -- foreuses au moins sur un gisement ouvert d'avance
-- Machines.
Ca.U_MIN = 50           -- % : une machine de plus pour au moins une demi-machine de manque
Ca.FRAC_UP = 0.1        -- machines nourries : ⌊x⌋ + [frac(x) ≥ 0,9] (famine ≤ 10 %, entassement < une machine)
Ca.THETA_MIN = 900      -- ‰ : une chaîne attend tant que son ingrédient est couvert à moins de 90 % (goulot amont)
Ca.AHEAD_PCT = 25       -- % du gain compté pour un débit d'avance (il servira peut-être)
-- Caractère (traits pour mille d'IA2-0, poids pour mille d'IA2-a).
Ca.S0, Ca.S_MIN, Ca.S_MAX = 500, 200, 800   -- part réinvestie (‰)
Ca.D0, Ca.A0 = 100, 150                     -- parts de la défense et de l'armée (‰), prises AVANT le budget
Ca.SHARE_MAX = 800                          -- défense + armée au plus (‰)
Ca.T0, Ca.T_MIN, Ca.T_MAX = 20, 10, 40      -- retour accepté (min) : T0 × ambition ÷ prudence, borné
Ca.THREAT_DIV = 4                           -- menace : retour accepté ÷ 4 (comme les 5 min d'IA3-e)
-- Budget, croissance, bras.
Ca.STOCK_PCT = 50       -- part du stock libre investissable par cycle
Ca.CYCLE_MIN = 1        -- un cycle = 1 min (le runtime donne `dt` en minutes)
Ca.G_MAX = 150          -- ‰ de croissance de la demande élastique par cycle, au plus
Ca.T_GROWTH0 = 10       -- min : retour supposé avant le premier ordre
Ca.T_FLOOR = 5          -- min : plancher du retour moyen dans g
Ca.T_HIST = 3           -- cycles gardés pour le retour moyen T̄ (médiane)
Ca.LEAD = 2             -- la demande élastique ne précède jamais de plus de 2 fois ce qui tourne
Ca.LABOR_H = 10         -- min de travail des bras disponibles engagés au plus
Ca.SPARE = 2            -- PNJ : travail qui attend au-delà des bras libres (fait venir une recrue, IA3-d)
Ca.HANDS_MIN = 1        -- PNJ : un bras au moins peut toujours passer au capital
-- Travail (mêmes ordres de grandeur qu'IA3-e, shared/ai3/automatiser.lua).
Ca.POSE_S, Ca.BATCH, Ca.WALK, Ca.HANDLE_S, Ca.DIST = 1.5, 12, 8, 10, 56
-- Valeur d'un ordre au cerveau (échelle des projets) : 35 (seuil du travail qui fait recruter, IA3-d) à 90.
Ca.V_MIN, Ca.V_SPAN, Ca.V_MAX = 35, 55, 90
Ca.MAX_ORDERS = 24      -- ordres au plus par cycle (coût de calcul)
Ca.HQ = "qg"
Ca.EPS = 1e-9

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

--- Copie triée d'une liste de tables par une clé texte (égalités : ordre stable par l'index d'origine).
local function sort_by(list, keyf)
  local tmp = {}
  for i, v in ipairs(list or {}) do tmp[i] = { k = keyf(v), v = v } end
  table.sort(tmp, function(a, b) return a.k < b.k end)
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
  return string.format("%.1f", x)
end

---------------------------------------------------------------------------------------------------
-- 1. Données : relevé des prototypes -> débits unitaires et valeurs
---------------------------------------------------------------------------------------------------
--- Relevé (format de shared/ai3/catalogue.lua, K.build) complété de : entities[].speed (vitesse de fabrication, de
--- minage ou de recherche), mining_area (côté de l'aire de minage, en tuiles), size (côté de l'emprise), energy_kw
--- (puissance consommée) ; resources[].mining_time ; items[].fuel_value (J). opts = { exec = { [entité] = vrai } (absente :
--- toutes), exec_roles = { [rôle] = vrai }, mining_bonus, lab_bonus (bonus de la force), fuel (combustible imposé) }.
function Ca.data(dump, opts)
  opts = opts or {}
  local D = { recipes = {}, recipe_list = {}, producers = {}, hand = {}, hand_mine = {}, makers = {}, drills = {},
    labs = {}, res = {}, res_list = {}, packs = {}, item_of = {}, maker_by = {}, drill_by = {}, lab_by = {},
    unlocked_by = {}, fuel = opts.fuel, fuel_kj = 0, items = dump.items or {},
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
    elseif e.item and (role == "fabrique" or role == "foreuse" or role == "labo") then
      D.item_of[e.name] = e.item
      local m = { name = e.name, item = e.item, speed = e.speed or 1, energy = e.energy or "none", kw = e.energy_kw or 0,
        size = e.size or 1, exec = executable(e, role) }
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
  -- Combustible : le produit d'une ressource extractible au plus grand pouvoir calorifique (égalité : le nom).
  if not D.fuel then
    local best, bv = nil, 0
    for _, name in ipairs(D.res_list) do
      local it = D.items[name]
      local v = it and it.fuel_value or 0
      local rs = D.res[name]
      local ok = D.hand_mine[rs.category] or false
      for _, d in ipairs(D.drills) do if d.exec and d.cats[rs.category] then ok = true end end
      if v > bv and ok and not rs.fluid then best, bv = name, v end
    end
    D.fuel = best
  end
  local fi = D.fuel and D.items[D.fuel]
  D.fuel_kj = fi and (fi.fuel_value or 0) / 1000 or 0
  D.mu, D.mu_recipe = Ca.values(D)
  return D
end

--- Valeur de chaque objet (MU) : point fixe min-plus sur les recettes (ordre des noms, au plus 60 passes). Rend aussi
--- la recette la moins chère de chaque objet.
function Ca.values(D)
  local mu, best = {}, {}
  for _, name in ipairs(D.res_list) do mu[name] = Ca.RAW_MU * D.res[name].mining_time end
  for _ = 1, 60 do
    local changed = false
    for _, rn in ipairs(D.recipe_list) do
      local r = D.recipes[rn]
      local input, ok = r.energy * Ca.TIME_MU, true
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

---------------------------------------------------------------------------------------------------
-- 2. Caractère, budget, prix du travail, croissance
---------------------------------------------------------------------------------------------------
--- s (‰ réinvesti), delta (‰ défense), alpha (‰ armée), tmax (min). Traits d'IA2-0 et poids d'IA2-a, pour mille.
function Ca.character(traits, weights, threat)
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
  local tmax = clamp(Ca.T0 * amb / pru, Ca.T_MIN, Ca.T_MAX)
  if threat then tmax = tmax / Ca.THREAT_DIV end
  return { s = s, delta = delta, alpha = alpha, tmax = tmax }
end

--- Budget matières du cycle (MU) : s × (production libre des parts défense et armée × dt + stock libre × Ca.STOCK_PCT %).
function Ca.budget(ch, Y, free_mu, dt)
  local y_free = (Y or 0) * (1000 - ch.delta - ch.alpha) / 1000
  return ch.s / 1000 * (y_free * (dt or Ca.CYCLE_MIN) + (free_mu or 0) * Ca.STOCK_PCT / 100)
end

--- Prix du travail (MU par PNJ-minute) : nul quand au moins un bras est libre, sinon la production par PNJ.
function Ca.labor_price(Y, workers, idle)
  if (idle or 0) >= 1 then return 0 end
  return (Y or 0) / math.max(1, workers or 1)
end

--- Croissance de la demande élastique (‰ par cycle) : s × dt ÷ T̄ (médiane des retours acceptés), au plus Ca.G_MAX.
function Ca.growth(ch, st, elastic, dt)
  if not elastic then return 0 end
  local tbar = median(st.T_hist or {}) or Ca.T_GROWTH0
  return math.min(Ca.G_MAX, math.floor(ch.s * (dt or Ca.CYCLE_MIN) / math.max(Ca.T_FLOOR, tbar)))
end

--- Valeur d'un ordre au cerveau : 35 à T = T_max, 90 à T = 0.
function Ca.value(T, tmax)
  if not T or tmax <= 0 then return Ca.V_MIN end
  return clamp(Ca.V_MIN + math.floor(Ca.V_SPAN * (tmax - T) / tmax), Ca.V_MIN, Ca.V_MAX)
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

--- Objet obtenable : au stock, ressource connue et extractible, ou recette ouverte d'une catégorie faisable (main,
--- machine posée ou au stock) dont tous les ingrédients sont obtenables. input.obtainable(objet) remplace ce calcul
--- (en jeu : le point fixe du graphe d'IA-G, ev.feas).
function Ca.obtainable(ctx, item)
  local io = ctx.input.obtainable
  if io then return io(item) and true or false end
  local memo = ctx.obt
  if memo[item] ~= nil then return memo[item] end
  memo[item] = false -- garde contre un cycle de recettes
  local D = ctx.D
  local ok = (ctx.stock[item] or 0) > 0
  if not ok and D.res[item] then
    local rs = D.res[item]
    local known = ctx.known == nil or ctx.known[item] == true
    local ext = D.hand_mine[rs.category] or false
    for _, d in ipairs(D.drills) do if d.exec and d.cats[rs.category] then ext = true end end
    ok = known and ext and not rs.fluid
  end
  if not ok then
    for _, rn in ipairs(D.producers[item] or {}) do
      local r = D.recipes[rn]
      if Ca.recipe_open(ctx, rn) and not r.fluid and ctx.cats_present[r.category] then
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
  for _, d in ipairs(D.drills) do
    if d.cats[rs.category] and D.mu[d.item] and Ca.available(ctx, d) then
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
--- puis le nom. Rend la recette ou nil et la raison.
local function choose_recipe(ctx, item)
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
  if not best then
    if (D.producers[item] or {})[1] then return nil, "recette a rechercher" end
    return nil, "aucune recette"
  end
  return best
end

--- Besoin par objet (objets/min) : la demande finale propagée dans le graphe des recettes. Rend { R, list (profondeur
--- croissante, puis le nom), depth, rec, why, fin }.
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
  if D.fuel and plan.burn > 0 then add(D.fuel, plan.burn) end
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
  local Rq = {}
  for _, k in ipairs(sorted_keys(fin)) do Rq[k] = fin[k] end
  for _, i in ipairs(items) do
    local r = rec[i]
    -- Besoin NET propagé à l'amont : un stock qui dort couvre son débit pendant Ca.H_STOCK minutes (50 000 plaques au
    -- coffre ne demandent aucun minerai).
    local net = (Rq[i] or 0) - (ctx.stock[i] or 0) / Ca.H_STOCK
    if r and net > 0 then
      local crafts = net / amount_of(r.products, i)
      for _, ing in ipairs(r.ingredients) do Rq[ing.name] = (Rq[ing.name] or 0) + crafts * ing.amount end
    end
  end
  local list = {}
  for i = #items, 1, -1 do list[#list + 1] = items[i] end
  table.sort(list, function(a, b)
    if depth[a] ~= depth[b] then return depth[a] < depth[b] end
    return a < b
  end)
  return { R = Rq, list = list, depth = depth, rec = rec, why = why, fin = fin }
end

---------------------------------------------------------------------------------------------------
-- 5. Plan : capacités posées, ouvertes et décidées
---------------------------------------------------------------------------------------------------
local function add_machines(ctx, plan, m, r, n, where)
  if not (m and r) or (n or 0) <= 0 then return end
  local cpm = Ca.crafts_per_min(m, r) * n
  for _, p in ipairs(r.products) do plan.N[p.name] = (plan.N[p.name] or 0) + cpm * p.amount end
  if where == nil or where == Ca.HQ then
    for _, i in ipairs(r.ingredients) do plan.cons[i.name] = (plan.cons[i.name] or 0) + cpm * i.amount end
  end
  plan.burn = plan.burn + n * Ca.fuel_per_min(ctx.D, m)
  if m.energy == "electric" then plan.kw_used = plan.kw_used + n * (m.kw or 0) end
end

local function add_drills(ctx, plan, d, item, n, dep, count_cover)
  if not d or (n or 0) <= 0 or not ctx.D.res[item] then return end
  plan.N[item] = (plan.N[item] or 0) + n * Ca.drill_per_min(ctx.D, d, item)
  if dep ~= nil then
    local key = tostring(dep)
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

--- Applique un ordre (ouvert ou décidé) au plan : capacité, consommation, couverture, combustible, courant.
function Ca.apply(ctx, plan, o)
  local D = ctx.D
  local k = o.kind
  if k == "couvrir" or k == "ouvrir" then
    add_drills(ctx, plan, D.drill_by[o.entity], o.resource, o.n, o.deposit, true)
    if (o.smelt_n or 0) > 0 then
      add_machines(ctx, plan, D.maker_by[o.smelt_entity], D.recipes[o.smelt_recipe], o.smelt_n, o.deposit)
    end
    if k == "ouvrir" and o.deposit ~= nil then plan.opened[tostring(o.deposit)] = true end
  elseif k == "fours" or k == "chaine" or k == "packs" then
    add_machines(ctx, plan, D.maker_by[o.entity], D.recipes[o.recipe], o.n, o.where or Ca.HQ)
  elseif k == "labos" then
    add_labs(ctx, plan, D.lab_by[o.entity], o.n)
  elseif k == "energie" then
    plan.kw_have = plan.kw_have + (o.kw or 0)
  end
  if o.key then plan.taken[o.key] = true end
end

local function new_plan(ctx)
  local D = ctx.D
  local plan = { N = {}, cons = {}, burn = 0, cover = {}, opened = {}, drills_on = {}, labs = 0, lab_cap = 0,
    kw_used = 0, kw_have = 0, taken = {}, K = 0, hand = {} }
  -- La MAIN n'est pas du capital (consigne du DC : « ils craftent beaucoup à la main ») : elle nourrit les machines
  -- aujourd'hui (couverture d'un ingrédient), mais le manque d'un objet se compte sans elle.
  for _, k in ipairs(sorted_keys(ctx.flows)) do
    local h = ctx.flows[k].hand or 0
    if h > 0 then plan.hand[k] = h end
  end
  -- Couverture mesurée par le runtime (tuiles sous une foreuse) quand elle est donnée ; sinon calculée.
  local measured = {}
  for _, f in ipairs(ctx.deposits) do
    local key = tostring(f.id)
    if f.covered ~= nil then
      plan.cover[key] = f.covered
      measured[key] = true
    end
    if f.open then plan.opened[key] = true end
  end
  for _, m in ipairs(ctx.machines) do
    local mm, r = D.maker_by[m.entity], D.recipes[m.recipe]
    add_machines(ctx, plan, mm, r, m.n, m.where)
    if mm and r then
      for _, p in ipairs(r.products) do plan.K = plan.K + Ca.crafts_per_min(mm, r) * m.n * p.amount * Ca.va(D, p.name, r.name) end
    end
  end
  for _, d in ipairs(ctx.drills_in) do
    local dd = D.drill_by[d.entity]
    local key = d.deposit ~= nil and tostring(d.deposit) or nil
    add_drills(ctx, plan, dd, d.resource, d.n, d.deposit, not (key and measured[key]))
    if key then plan.opened[key] = true end
    if dd and D.res[d.resource] then plan.K = plan.K + d.n * Ca.drill_per_min(D, dd, d.resource) * (D.mu[d.resource] or 0) end
  end
  for _, l in ipairs(ctx.labs_in) do
    local ll = D.lab_by[l.entity]
    add_labs(ctx, plan, ll, l.n)
    if ll then plan.K = plan.K + l.n * Ca.lab_per_min(D, ll) * Ca.TIME_MU end
  end
  local pw = ctx.input.power
  if pw then
    plan.kw_have = pw.have_kw or 0
    if pw.used_kw then plan.kw_used = pw.used_kw end
  end
  plan.lab_cap0 = plan.lab_cap
  for _, o in ipairs(ctx.open) do Ca.apply(ctx, plan, o) end
  return plan
end

---------------------------------------------------------------------------------------------------
-- 6. Préparation d'un cycle
---------------------------------------------------------------------------------------------------
local function prepare(input, st)
  local D = input.data
  local state = input.state or {}
  local ctx = { D = D, st = st, input = input, stock = input.stock or {}, flows = input.flows or {},
    techs = state.techs or {}, known = state.known, obt = {}, best_m = {}, best_d = {}, refus = {}, explore = {},
    dt = input.dt or Ca.CYCLE_MIN, threat = input.threat and true or false, power_block = {} }
  ctx.ch = Ca.character(input.traits, input.weights, ctx.threat)
  local w = input.weights or {}
  ctx.w_cap = (w.capital or 1000) / 1000
  ctx.w_rech = (w.recherche or 1000) / 1000
  ctx.machines = sort_by(input.machines, function(m)
    return tostring(m.entity) .. "|" .. tostring(m.recipe) .. "|" .. tostring(m.where) .. "|" .. tostring(m.n) end)
  ctx.drills_in = sort_by(input.drills, function(d)
    return tostring(d.entity) .. "|" .. tostring(d.resource) .. "|" .. tostring(d.deposit) .. "|" .. tostring(d.n) end)
  ctx.labs_in = sort_by(input.labs, function(l) return tostring(l.entity) .. "|" .. tostring(l.n) end)
  ctx.deposits = sort_by(input.deposits, function(f) return tostring(f.id) end)
  ctx.open = sort_by(input.open, function(o) return tostring(o.key) end)
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
  -- Production mesurée (MU/min) : valeur ajoutée de ce qui a été fait.
  local rs = input.research or {}
  local Y = 0
  for _, k in ipairs(sorted_keys(ctx.flows)) do Y = Y + (ctx.flows[k].made or 0) * Ca.va(D, k) end
  Y = Y + (rs.rate or 0) * Ca.TIME_MU
  ctx.Y = Y
  ctx.lambda = Ca.labor_price(Y, input.workers, input.idle)
  -- Croissance : puits élastiques (recherche restante, puits marqués).
  local queue = rs.queue or {}
  local Ls = 0
  for _, q in ipairs(queue) do Ls = Ls + (q.left or 0) * (q.time or 1) end
  local elastic = Ls > 0
  for _, s in ipairs(input.sinks or {}) do if s.elastic then elastic = true end end
  ctx.g = Ca.growth(ctx.ch, st, elastic, ctx.dt)
  local gf = (1000 + ctx.g) / 1000
  st.sink_t = st.sink_t or {}
  ctx.sinks = {}
  for _, s in ipairs(sort_by(input.sinks, function(x) return tostring(x.item) end)) do
    local rate = math.max(s.rate or 0, s.want or 0)
    if s.elastic and rate > 0 then
      local prev = st.sink_t[s.item] or rate
      local t = math.min(prev * gf, Ca.LEAD * rate)
      if t < rate then t = rate end
      st.sink_t[s.item] = t
      rate = t
    end
    ctx.sinks[#ctx.sinks + 1] = { item = s.item, rate = rate, elastic = s.elastic }
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
  ctx.u_star, ctx.u_meas, ctx.Ls = u_star, u_meas, Ls
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
  -- Valeur d'une seconde de recherche : ses packs et son temps de laboratoire (le laboratoire est le PUITS de toute la
  -- chaîne des packs : sans lui, elle ne vaut rien).
  ctx.lab_mu = Ca.TIME_MU
  for _, p in ipairs(sorted_keys(ctx.mix)) do ctx.lab_mu = ctx.lab_mu + ctx.mix[p] * (D.mu[p] or 0) end
  -- Bras.
  if input.workers then
    local hands = math.max(Ca.HANDS_MIN, math.floor(input.idle or 0) + (input.can_grow and Ca.SPARE or 0))
    local open_w = 0
    for _, o in ipairs(ctx.open) do open_w = open_w + (o.work_left or 0) end
    ctx.labor = math.max(0, hands * 60 * Ca.LABOR_H - open_w)
  else
    ctx.labor = math.huge
  end
  return ctx
end

---------------------------------------------------------------------------------------------------
-- 7. Options
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

--- Termine une option : coût, retour, valeur ; rend l'option ou nil (refus écrit).
local function finish(ctx, o)
  if o.cost_m == nil then
    refuse(ctx, o.key, o.kind, o.item, "impayable : " .. tostring(o.unpaid))
    return nil
  end
  o.cost = o.cost_m + ctx.lambda * (o.work or 0) / 60
  if (o.gain or 0) <= Ca.EPS then
    refuse(ctx, o.key, o.kind, o.item, "gain nul")
    return nil
  end
  o.T = o.cost / o.gain
  if o.T > ctx.ch.tmax then
    refuse(ctx, o.key, o.kind, o.item, string.format("retour %s min > %s", fmt(o.T), fmt(ctx.ch.tmax)))
    return nil
  end
  o.value = Ca.value(o.T, ctx.ch.tmax)
  return o
end

local function cand(list, o, mk) if o then list[#list + 1] = { o = o, mk = mk } end end

--- Couverture d'un gisement dans le plan : couvertes (tuiles), places libres, κ (‰).
local function deposit_state(ctx, plan, f, d)
  local key = tostring(f.id)
  local per, cov = Ca.comb(d)
  local covered = math.min(f.tiles or 0, plan.cover[key] or 0)
  local used_land = covered * per / math.max(Ca.EPS, cov)
  local free = math.max(0, math.floor(((f.tiles or 0) - used_land) / per + Ca.EPS))
  local kappa = (f.tiles or 0) > 0 and math.floor(1000 * covered / f.tiles) or 1000
  return covered, free, kappa
end
Ca.deposit_state = deposit_state

--- Options d'extraction d'une ressource : couvrir les gisements ouverts, ouvrir un gisement connu, explorer.
local function extraction_options(ctx, plan, req, item, def, out)
  local D = ctx.D
  local rs = D.res[item]
  if rs.fluid then refuse(ctx, "extraire:" .. item, "couvrir", item, "limite : fluide") return end
  local d = best_drill(ctx, item)
  if not d then refuse(ctx, "extraire:" .. item, "couvrir", item, "aucune foreuse disponible") return end
  local rho = Ca.drill_per_min(D, d, item)
  local fuel = Ca.fuel_per_min(D, d)
  local Ri = req.R[item] or 0
  local opened, sites = {}, {}
  for _, f in ipairs(ctx.deposits) do
    if f.resource == item then
      if plan.opened[tostring(f.id)] then opened[#opened + 1] = f else sites[#sites + 1] = f end
    end
  end
  local function by_dist(a, b)
    local da, db = a.dist or Ca.DIST, b.dist or Ca.DIST
    if da ~= db then return da < db end
    return tostring(a.id) < tostring(b.id)
  end
  table.sort(opened, by_dist)
  table.sort(sites, by_dist)
  -- Fonte sur place (avant-postes) : le gisement porte sa recette et son four ; ils grandissent avec les foreuses.
  local function smelt_of(f)
    local r = f.smelt and D.recipes[f.smelt]
    local m = f.smelter and D.maker_by[f.smelter]
    if r and m and amount_of(r.ingredients, item) > 0 then return r, m end
    return nil
  end
  local function mk_drills(kind, f, n, fixed)
    local o = { kind = kind, key = kind .. ":" .. tostring(f.id), item = item, resource = item, deposit = f.id,
      entity = d.name, n = n, rate = n * rho, depth = 0, where = f.id }
    local items = { { d.item, n } }
    for _, it in ipairs(ctx.input.drill_extra or {}) do items[#items + 1] = { it[1], it[2] * n } end
    for _, it in ipairs(fixed or {}) do items[#items + 1] = { it[1], it[2] } end
    local useful = math.min(n * rho, math.max(0, def))
    local ahead = n * rho - useful
    local unit_va = D.mu[item] or 0
    local op = n * fuel * ctx.fuel_mu
    local sr, sm = smelt_of(f)
    if sr then
      local k_in = Ca.in_per_min(sm, sr, item)
      local nf = Ca.fed_max(n * rho, 0, k_in)
      if nf > 0 then
        o.smelt_n, o.smelt_recipe, o.smelt_entity = nf, sr.name, sm.name
        items[#items + 1] = { sm.item, nf }
        local p = sr.products[1]
        unit_va = math.max(unit_va, (D.mu[p.name] or 0) * p.amount / amount_of(sr.ingredients, item))
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
  local function power_cap(n, key)
    if d.energy ~= "electric" or not ctx.input.power or (d.kw or 0) <= 0 then return n end
    local np = math.max(0, math.floor((plan.kw_have - plan.kw_used) / d.kw + Ca.EPS))
    if np < n then
      ctx.power_block[#ctx.power_block + 1] = { key = key, kw = (n - np) * d.kw, n = n - np, item = item, p = rho,
        va = D.mu[item] or 0 }
      return np
    end
    return n
  end
  -- Couvrir les gisements ouverts.
  local all_covered, free_total = true, 0
  local ext_unit = nil
  for _, f in ipairs(opened) do
    local _, free, kappa = deposit_state(ctx, plan, f, d)
    free_total = free_total + free
    if free > 0 and kappa < Ca.KAPPA then all_covered = false end
    local key = "couvrir:" .. tostring(f.id)
    if free > 0 and def > 0 and not plan.taken[key] then
      if ctx.threat then refuse(ctx, key, "couvrir", item, "menace : leviers du QG seulement")
      elseif f.danger then refuse(ctx, key, "couvrir", item, "danger")
      else
        local n = math.min(free, Ca.count(def, rho))
        if n > 0 then
          local o = mk_drills("couvrir", f, n)
          if o.cost_m and o.gain > 0 and ext_unit == nil then ext_unit = (o.cost_m + ctx.lambda * o.work / 60) / (n * rho) end
          n = power_cap(n, key)
          if n <= 0 then refuse(ctx, key, "couvrir", item, "courant insuffisant")
          else cand(out, finish(ctx, mk_drills("couvrir", f, n)), function(k) return finish(ctx, mk_drills("couvrir", f, k)) end) end
        end
      end
    end
  end
  -- Ouvrir : autorisé quand les ouverts sont couverts (et qu'il manque), ou d'avance.
  local amount_open = 0
  for _, f in ipairs(opened) do amount_open = amount_open + (f.amount or 0) end
  local life = (plan.N[item] or 0) > 0 and amount_open / plan.N[item] or math.huge
  local reserve_low = Ri > 0 and free_total * rho < Ca.RESERVE_PCT / 100 * Ri
  local why_open = nil
  if def > 0 and all_covered then why_open = #opened > 0 and "gisements ouverts couverts" or "aucun gisement ouvert"
  elseif #opened > 0 and Ri > 0 and life < Ca.H_LIFE then why_open = "epuisement en " .. fmt(life) .. " min"
  elseif #opened > 0 and reserve_low then why_open = "reserve de places basse" end
  local any_site = false
  for _, f in ipairs(sites) do
    local key = "ouvrir:" .. tostring(f.id)
    any_site = true
    if not plan.taken[key] then
      local _, slots = deposit_state(ctx, plan, f, d)
      local n = math.min(slots, math.max(Ca.OPEN_MIN, Ca.count(math.max(0, def), rho)))
      local why = why_open
      if not why and def > 0 and n > 0 and ext_unit then
        local o = mk_drills("ouvrir", f, n, ctx.input.site_items)
        if o.cost_m and o.gain > 0 then
          local unit = (o.cost_m + ctx.lambda * o.work / 60) / (n * rho)
          if unit * Ca.OPEN_RATIO / 100 < ext_unit then why = "site moins cher par debit" end
        end
      end
      if not why then
        local k = 1000
        for _, g in ipairs(opened) do
          local _, _, kg = deposit_state(ctx, plan, g, d)
          if kg < k then k = kg end
        end
        refuse(ctx, key, "ouvrir", item, string.format("gisements ouverts pas couverts (kappa %d pour mille < %d)", k, Ca.KAPPA))
      elseif n <= 0 then refuse(ctx, key, "ouvrir", item, "aucune place")
      elseif ctx.threat then refuse(ctx, key, "ouvrir", item, "menace : leviers du QG seulement")
      elseif f.danger then refuse(ctx, key, "ouvrir", item, "danger")
      else
        n = power_cap(n, key)
        if n <= 0 then refuse(ctx, key, "ouvrir", item, "courant insuffisant")
        else
          local mk = function(k)
            local o = mk_drills("ouvrir", f, k, ctx.input.site_items)
            o.why = why
            return finish(ctx, o)
          end
          cand(out, mk(n), mk)
        end
      end
    end
  end
  if why_open and not any_site and not ctx.threat then ctx.explore[item] = why_open end
end

--- Options d'une fabrique (fours, chaîne, packs) pour l'objet `item` de recette `r`.
local function fabric_options(ctx, plan, req, item, r, def, out)
  local D = ctx.D
  local is_chain = D.hand[r.category] or false
  local kind = is_chain and (D.packs[item] and "packs" or "chaine") or "fours"
  local key = kind .. ":" .. item
  if plan.taken[key] then return end
  local m = best_maker(ctx, r.category)
  if not m then
    if def > 0 then refuse(ctx, key, kind, item, "aucune machine disponible (" .. r.category .. ")") end
    return
  end
  local lim = ctx.input.limits or {}
  if lim.max_ingredients and #r.ingredients > lim.max_ingredients then
    if def > 0 then refuse(ctx, key, kind, item, "limite : " .. #r.ingredients .. " ingredients") end
    return
  end
  local p = Ca.out_per_min(m, r, item)
  -- Entrées : une ressource se lit sur l'ARRIVÉE mesurée (contrôle dur des fours) ; un objet fabriqué sur sa couverture
  -- dans le plan (un ingrédient en manque passe d'abord : goulot amont).
  local ncap, limit, raw_in = math.huge, nil, false
  for _, ing in ipairs(r.ingredients) do
    local k_in = Ca.in_per_min(m, r, ing.name)
    if D.res[ing.name] then
      raw_in = true
      local f = ctx.flows[ing.name] or {}
      local supply = (f.made or 0) + (ctx.stock[ing.name] or 0) / Ca.H_STOCK
      local c = Ca.fed_max(supply, plan.cons[ing.name] or 0, k_in)
      if c < ncap then ncap, limit = c, ing.name end
    else
      local Rj = req.R[ing.name] or 0
      local cover = (plan.N[ing.name] or 0) + (plan.hand[ing.name] or 0) + (ctx.stock[ing.name] or 0) / Ca.H_STOCK
      if Rj > 0 and cover * 1000 < Ca.THETA_MIN * Rj then
        if def > 0 then
          refuse(ctx, key, kind, item, string.format("entree %s d'abord (couverte a %d pour mille)", ing.name,
            math.floor(1000 * cover / Rj)))
        end
        return
      end
    end
  end
  local nwant = Ca.count(def, p)
  local ahead = false
  if not is_chain and raw_in and (req.R[item] or 0) > 0 and ncap ~= math.huge and ncap > nwant then
    nwant = ncap -- fondre tout le minerai qui arrive, pour un produit qui a un débouché
    ahead = true
  end
  if nwant <= 0 then return end
  if ncap <= 0 then
    refuse(ctx, key, kind, item, "entree " .. tostring(limit) .. " insuffisante (arrivee mesuree)")
    return
  end
  local n = math.min(nwant, ncap)
  if m.energy == "electric" and ctx.input.power then
    local np = math.max(0, math.floor((plan.kw_have - plan.kw_used) / math.max(Ca.EPS, m.kw) + Ca.EPS))
    if np < n then
      ctx.power_block[#ctx.power_block + 1] = { key = key, kw = (n - np) * m.kw, n = n - np, item = item, p = p, va = D.mu[item] or 0 }
      n = np
      if n <= 0 then refuse(ctx, key, kind, item, "courant insuffisant") return end
    end
  end
  -- Valeur PLEINE de l'objet : le manque vient de la demande des puits, et un ingrédient en manque arrête toute la
  -- chaîne en aval (un engrenage ne vaut que 0,05 MU de valeur ajoutée, mais sans lui aucun pack ne se fait).
  local va = D.mu[item] or 0
  local wf = D.packs[item] and ctx.w_rech or ctx.w_cap
  local hand = (ctx.flows[item] or {}).hand or 0
  local unit_s = r.energy / math.max(Ca.EPS, amount_of(r.products, item))
  local fuel = Ca.fuel_per_min(D, m)
  local function mk(k)
    local o = { kind = kind, key = key, item = item, recipe = r.name, entity = m.name, n = k, rate = k * p,
      where = Ca.HQ, depth = req.depth[item] or 0, fed_by = limit, fed_max = ncap ~= math.huge and ncap or nil }
    local items = { { m.item, k } }
    for _, it in ipairs(ctx.input.machine_extra or {}) do items[#items + 1] = { it[1], it[2] * k } end
    o.items = items
    o.cost_m, o.unpaid = items_mu(ctx, items)
    o.work = work_of(ctx, items, Ca.DIST)
    local useful = math.min(k * p, math.max(0, def))
    local extra = ahead and (k * p - useful) * Ca.AHEAD_PCT / 100 or 0
    local freed = is_chain and math.min(hand, k * p) * unit_s / 60 or 0 -- PNJ libérés de la main
    o.useful = useful
    o.gain = (useful + extra) * va * wf + ctx.lambda * freed - k * fuel * ctx.fuel_mu
    o.why = string.format("manque %s/min, %d x %s (%s/min chacune)%s", fmt(def), k, m.name, fmt(p),
      limit and (", nourrie par " .. limit .. " (" .. ncap .. " au plus)") or "")
    return finish(ctx, o)
  end
  cand(out, mk(n), mk)
end

--- Options des laboratoires : la recherche visée, jamais plus que les packs ne nourrissent.
function Ca.lab_cap(ctx, plan)
  local cap = math.huge
  for _, p in ipairs(sorted_keys(ctx.mix)) do
    local per_lab = ctx.lab_rate * ctx.mix[p]
    if per_lab > 0 then
      local cover = (plan.N[p] or 0) + (plan.hand[p] or 0) + (ctx.stock[p] or 0) / Ca.H_STOCK
      local c = math.floor(cover / per_lab + Ca.FRAC_UP)
      if c < cap then cap = c end
    end
  end
  return cap
end

local function lab_options(ctx, plan, out)
  if ctx.u_star <= 0 or not ctx.lab then return end
  local key = "labos:" .. ctx.lab.name
  if plan.taken[key] then return end
  local target = math.ceil(ctx.u_star / ctx.lab_rate - Ca.EPS)
  local want = target - plan.labs
  if want <= 0 then return end
  local starved = (ctx.input.research or {}).starved or 0
  if starved > 100 then refuse(ctx, key, "labos", nil, "laboratoires affames (" .. starved .. " pour mille) : les packs d'abord") return end
  local n = math.min(want, Ca.lab_cap(ctx, plan) - plan.labs)
  if n <= 0 then refuse(ctx, key, "labos", nil, "packs insuffisants pour un laboratoire de plus") return end
  local l = ctx.lab
  local function mk(k)
    local o = { kind = "labos", key = key, entity = l.name, item = l.item, n = k, rate = k * ctx.lab_rate, depth = 99,
      where = Ca.HQ }
    o.items = { { l.item, k } }
    o.cost_m, o.unpaid = items_mu(ctx, o.items)
    o.work = work_of(ctx, o.items, Ca.DIST)
    local useful = math.min(k * ctx.lab_rate, math.max(0, ctx.u_star - plan.lab_cap))
    o.useful = useful
    o.gain = useful * ctx.lab_mu * ctx.w_rech
    o.why = string.format("recherche visee %s s/min, %d laboratoire(s) vises, %d poses ou ouverts", fmt(ctx.u_star), target, plan.labs)
    return finish(ctx, o)
  end
  cand(out, mk(n), mk)
end

--- Centrale : machines électriques rentables qui manquent de courant (la puissance d'une centrale vient du runtime).
local function power_options(ctx, plan, out)
  local pw = ctx.input.power
  if not pw or not pw.plant or #ctx.power_block == 0 then return end
  local key = "energie"
  if plan.taken[key] then return end
  local kw_need, gain = 0, 0
  for _, b in ipairs(ctx.power_block) do
    kw_need = kw_need + b.kw
    gain = gain + b.n * b.p * b.va * ctx.w_cap
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

--- Améliorations (lot CAPITAL) : coût et gain donnés par l'appelant, rangés avec les autres.
local function upgrade_options(ctx, plan, out)
  for _, u in ipairs(sort_by(ctx.input.upgrades, function(x) return tostring(x.key) end)) do
    local key = "ameliorer:" .. tostring(u.key)
    if not plan.taken[key] then
      local o = { kind = "ameliorer", key = key, item = u.key, n = 1, depth = 97, cost_m = u.cost, work = u.work or 0,
        gain = u.gain, items = u.items or {}, why = u.why, where = Ca.HQ }
      cand(out, finish(ctx, o), nil)
    end
  end
end

--- Toutes les options du plan courant.
function Ca.options(ctx, plan, req)
  local D = ctx.D
  local out = {}
  ctx.power_block = {}
  for _, i in ipairs(req.list) do
    local Ri = req.R[i] or 0
    if Ri > 0 then
      local def = Ri - (plan.N[i] or 0) - (ctx.stock[i] or 0) / Ca.H_STOCK
      if D.res[i] then
        extraction_options(ctx, plan, req, i, def, out)
      else
        local r = req.rec[i]
        if not r then
          if def > 0 then refuse(ctx, "objet:" .. i, "chaine", i, req.why[i] or "aucune recette") end
        else
          fabric_options(ctx, plan, req, i, r, def, out)
        end
      end
    end
  end
  lab_options(ctx, plan, out)
  power_options(ctx, plan, out)
  upgrade_options(ctx, plan, out)
  table.sort(out, function(a, b)
    if a.o.T ~= b.o.T then return a.o.T < b.o.T end
    if a.o.depth ~= b.o.depth then return a.o.depth < b.o.depth end
    return a.o.key < b.o.key
  end)
  return out
end

---------------------------------------------------------------------------------------------------
-- 8. Décision
---------------------------------------------------------------------------------------------------
--- Stock libre (MU) : ce qui dépasse le tampon de Ca.H_BUF minutes de besoin.
local function free_stock_mu(ctx, req)
  local v = 0
  for _, k in ipairs(sorted_keys(ctx.stock)) do
    local m = ctx.D.mu[k]
    if m then v = v + math.max(0, (ctx.stock[k] or 0) - (req.R[k] or 0) * Ca.H_BUF) * m end
  end
  return v
end

--- La décision d'un cycle. input = {
---   data (Ca.data), state = { techs = { [techno] = vrai }, known = { [ressource] = vrai } (absente : toutes) },
---   stock = { [objet] = n }, flows = { [objet] = { made = /min arrivés au QG (toutes sources), hand = /min faits à la main } },
---   machines = { { entity, recipe, n, where = "qg" ou id de gisement } }, drills = { { entity, resource, n, deposit } },
---   labs = { { entity, n } }, deposits = { { id, resource, tiles, amount, covered (tuiles sous une foreuse, facultatif),
---   dist, open, smelt, smelter (fonte sur place, facultatif), danger } } (ouverts et connus),
---   open = { ordres en cours, tels que rendus par Ca.decide, + missing = { {objet, n} }, work_left (PNJ-s) },
---   sinks = { { item, rate, want, elastic } }, need = { [objet] = n } (buts), research = { queue = { { tech, left, time,
---   packs = { {pack, n} } } }, rate (s de laboratoire / min mesurées), starved (‰ de laboratoires affamés) },
---   power = { have_kw, used_kw, plant = { kw, items, burner_kw } } (facultatif), upgrades = { { key, cost, gain, items,
---   work, why } } (lot CAPITAL), site_items, drill_extra, machine_extra = { {objet, n} } (pièces de l'exécutant),
---   limits = { max_ingredients }, workers, idle (PNJ sans tâche, lissés), can_grow, traits, weights, threat, dt (min),
---   obtainable (fonction, facultative) }.
--- st : état persistant de la règle (nombres et tables). Rend { orders, refus, explore, s, delta, alpha, tmax, g, lambda,
--- Y, K, budget, spent, labor, labor_used, u_star, labs_target, coverage, bottleneck }.
function Ca.decide(input, st)
  st = st or {}
  local ctx = prepare(input, st)
  local plan = new_plan(ctx)
  local req = Ca.requirements(ctx, plan)
  local budget = Ca.budget(ctx.ch, ctx.Y, free_stock_mu(ctx, req), ctx.dt)
  local b_left, l_left = budget, ctx.labor
  local orders = {}
  for _ = 1, Ca.MAX_ORDERS do
    local opts = Ca.options(ctx, plan, req)
    local pick = nil
    for _, c in ipairs(opts) do
      local o = c.o
      if o.cost_m <= b_left + Ca.EPS and (o.work or 0) <= l_left + Ca.EPS then pick = o break end
      -- Trop grand pour le budget ou les bras : la plus grande taille qui passe (les bras règlent le rythme).
      if c.mk and o.n > 1 then
        for k = o.n - 1, 1, -1 do
          local o2 = c.mk(k)
          if o2 and o2.cost_m <= b_left + Ca.EPS and (o2.work or 0) <= l_left + Ca.EPS then pick = o2 break end
        end
        if pick then break end
      end
      refuse(ctx, o.key, o.kind, o.item, (o.cost_m > b_left + Ca.EPS) and
        string.format("budget : %s MU > %s", fmt(o.cost_m), fmt(b_left)) or
        string.format("bras : %s PNJ-s > %s", fmt(o.work), fmt(l_left)))
    end
    if not pick then break end
    Ca.apply(ctx, plan, pick)
    ctx.refus[pick.key] = nil
    b_left = b_left - pick.cost_m
    l_left = l_left - (pick.work or 0)
    orders[#orders + 1] = pick
    req = Ca.requirements(ctx, plan) -- le combustible des machines décidées entre dans la demande
  end
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
  local coverage = {}
  for _, f in ipairs(ctx.deposits) do
    local d = ctx.D.res[f.resource] and (best_drill(ctx, f.resource) or ctx.D.drill_by[(ctx.drills_in[1] or {}).entity or ""])
    if d then
      local _, free, kappa = deposit_state(ctx, plan, f, d)
      coverage[#coverage + 1] = { id = f.id, resource = f.resource, kappa = kappa, free = free,
        open = plan.opened[tostring(f.id)] or false }
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
  return { orders = orders, refus = refus, explore = explore, s = ctx.ch.s, delta = ctx.ch.delta, alpha = ctx.ch.alpha,
    tmax = ctx.ch.tmax, g = ctx.g, lambda = ctx.lambda, Y = ctx.Y, K = plan.K, budget = budget, spent = budget - b_left,
    labor = ctx.labor, labor_used = ctx.labor - l_left, u_star = ctx.u_star,
    labs_target = ctx.lab_rate > 0 and math.ceil(ctx.u_star / ctx.lab_rate - Ca.EPS) or 0, coverage = coverage,
    bottleneck = bottleneck and { item = bottleneck, theta = theta } or nil, R = req.R }
end

---------------------------------------------------------------------------------------------------
-- 9. Cerveau et journal
---------------------------------------------------------------------------------------------------
--- Buts du cerveau (shared/ai3/buts.lua) : un but par ordre, famille capital (recherche pour les laboratoires et les
--- packs), valeur de l'ordre (35 à 90 : au-dessus du seuil du travail qui fait recruter, IA3-d). Les ordres sont copiés
--- (aucune fonction : l'état peut aller dans global).
function Ca.goals(goals, res)
  for _, o in ipairs((res and res.orders) or {}) do
    local copy = {}
    for _, k in ipairs(sorted_keys(o)) do
      local v = o[k]
      if type(v) ~= "function" then copy[k] = v end
    end
    local fam = (o.kind == "labos" or o.kind == "packs") and "recherche" or "capital"
    goals[#goals + 1] = { key = "capi:" .. o.key, family = fam, kind = "capi", value = o.value, order = copy }
  end
  table.sort(goals, function(a, b)
    if a.value ~= b.value then return a.value > b.value end
    return a.key < b.key
  end)
  return goals
end

--- Ligne de journal (ASCII) : « [FO-CAPI] <faction> minute M » + ce texte, côté runtime.
function Ca.text(res)
  local parts = {}
  for _, o in ipairs(res.orders) do
    parts[#parts + 1] = string.format("%s %s x%d T=%s v=%d", o.kind, tostring(o.item or o.key), o.n or 1, fmt(o.T), o.value or 0)
  end
  local rf = {}
  for i = 1, math.min(6, #res.refus) do rf[#rf + 1] = res.refus[i].key .. " (" .. res.refus[i].why .. ")" end
  local cov = {}
  for _, c in ipairs(res.coverage) do
    if c.open then cov[#cov + 1] = string.format("%s %s %d/1000 libres %d", tostring(c.id), c.resource, c.kappa, c.free) end
  end
  return string.format("s=%d d=%d a=%d Tmax=%s g=%d Y=%s K=%s budget=%s/%s bras=%s/%s lambda=%s recherche=%s labos=%d "
    .. "goulot=%s ordres=[%s] gisements=[%s] refus=[%s]",
    res.s, res.delta, res.alpha, fmt(res.tmax), res.g, fmt(res.Y), fmt(res.K), fmt(res.spent), fmt(res.budget),
    fmt(res.labor_used), fmt(res.labor), fmt(res.lambda), fmt(res.u_star), res.labs_target,
    res.bottleneck and (res.bottleneck.item .. " " .. fmt(res.bottleneck.theta)) or "-",
    table.concat(parts, ", "), table.concat(cov, ", "), table.concat(rf, ", "))
end

return Ca
