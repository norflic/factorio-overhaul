--[[
  Lot EXPANSION « le besoin croissant » (constat du DC, 28/10, en observant des factions à 3 h 30 de jeu : « il y a pas de
  capitalisation, donc ça sert à rien d'aller explorer ou sécuriser d'autres gisements », « en théorie on devrait pouvoir
  s'étendre à l'infini », mais « il faut pas tomber dans le piège de l'ultra maximisation » : maximiser une matière
  intermédiaire prend toute la matière première des autres ; « il faut définir le BESOIN, et le besoin augmente »).
  RÈGLES PURES (aucune API Factorio), aucun nom du jeu (tests/iag_test.lua §8) : les matières, recettes et vitesses
  arrivent par les arguments. Testées hors jeu par tests/besoin_test.lua (propriétés, force brute, mutants, données
  renommées).

  Cinq règles, toutes de petite taille (un glouton prouvé suffit, rien d'exotique) :

  1. BESOIN d'une matière, en objets par minute :
        besoin = max(0, demande × facteur ÷ 1000 − production − stock ÷ Be.H_STOCK)
     demande : ce que les buts actifs déplient en cette matière (le besoin gardé du cerveau, ÷ Be.H_GOALS comme Ca.H_GOALS
     de la capitalisation) ; facteur : croissance du capital sur Be.CYCLES minutes (Be.factor, formule de
     Ca.growth de shared/ai3/capitalisation.lua, lue sans la modifier) ; production : mesurée ou déduite des machines ;
     un stock couvre son débit pendant Be.H_STOCK minutes. Croissant en demande et en facteur, décroissant en production et en
     stock, nul dès que la production couvre la demande projetée : « des milliers de cuivre » = aucun besoin de cuivre.

  2. ÉQUILIBRE entre matières SŒURS (Be.flows, Be.allocate) : la demande des buts est dépliée dans le graphe des recettes
     (une seule recette par objet, la première par nom, ou celle que donne `opts.pick`) ; chaque objet qui consomme DIRECTEMENT
     une matière (un produit dont la recette l'a pour ingrédient) en est un CONSOMMATEUR, avec son débit. Quand la matière
     ne suffit pas à tous, chacun reçoit la même FRACTION de son besoin (λ = min(1, offre ÷ somme des besoins)) : jamais
     gloutonne, personne n'est affamé tant qu'il reste de l'offre, personne ne reçoit plus que son besoin. C'est l'optimum
     du plus petit taux de satisfaction (contrôlé par force brute sur de petits cas).

  3. DÉCLENCHEUR d'expansion (Be.expansion) : quand le besoin d'une matière est positif ET que ses gisements connus sont
     exploités à Be.SAT_PCT % ou plus (ou que leur rendement mesuré tombe sous Be.YIELD_PCT %), il faut un nouveau site
     AVANT l'épuisement : « open » (un site retenu attend : le bâtir, avec ses tourelles), « explore » (aucun site : la
     prospection et l'exploration cherchent), « productivite » (l'exploration est restée vaine Be.TRIES_MAX fois de suite : tous les
     sites sont pris ou dangereux, la suite appartient aux modules de productivité du lot LEVIERS ; une nouvelle tentative
     après Be.RETRY_TICKS), « none » (besoin couvert, ou marge sur les gisements connus).

  4. PRÉVOYANCE bornée (Be.ahead) : on fabrique d'avance ce qui sera POSÉ à brève échéance (sites prêts), jamais au-delà
     de ce qui dort déjà au stock.

  5. UN SEUL chantier d'expansion à la fois, le plus pressé d'abord (Be.pick : plus grand déficit relatif, égalité par
     clé) : jamais trois kits d'avant-poste fabriqués en parallèle sur la même fonderie.

  Déterminisme : listes triées par clé, aucun pairs décisionnel, flottants calculés dans un ordre fixe, aucun hasard,
  l'état persistant (`ex`) ne garde que des nombres.
]]

local Be = {}

-- Horizons (minutes).
Be.H_GOALS = 10      -- le besoin gardé des buts se lit comme un débit servi en 10 min (Ca.H_GOALS)
Be.H_STOCK = 10      -- un stock couvre son débit pendant 10 min (Ca.H_STOCK)
Be.CYCLES = 10       -- croissance du capital composée sur 10 cycles d'une minute
-- Croissance (‰ par cycle, comme Ca.G_MAX) et facteur composé (‰) ; le facteur ne dépasse pas 4 fois la demande actuelle.
Be.G_MAX = 150
Be.FACTOR_BASE, Be.FACTOR_MAX = 1000, 4000
-- Déclencheur.
Be.NEED_MIN = 1      -- objets par minute : en dessous, le besoin est du bruit
Be.SAT_PCT = 80      -- gisements connus exploités à 80 % ou plus
Be.YIELD_PCT = 70    -- rendement mesuré (% du nominal) sous lequel un site compte comme saturé
Be.TRIES_MAX = 3     -- explorations vaines de suite avant de passer aux modules
Be.TRY_TICKS = 10 * 3600    -- une tentative d'exploration dure 10 min (la mission d'un éclaireur)
Be.RETRY_TICKS = 20 * 3600  -- … et recommence 20 min après la dernière vaine
-- Prévoyance.
Be.AHEAD_MAX = 1     -- kits fabriqués d'avance au plus (un chantier à la fois)

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

local function amount_of(list, name)
  for _, e in ipairs(list or {}) do
    if e.name == name then return e.amount or 1 end
  end
  return 0
end

---------------------------------------------------------------------------------------------------
-- 1. Besoin
---------------------------------------------------------------------------------------------------
--- Facteur de croissance (‰) : (1000 + g) ‰ par cycle pendant `cycles` cycles, g borné à [0, Be.G_MAX], arrondi à l'entier
--- inférieur à chaque cycle (entiers : même résultat partout), plafonné à Be.FACTOR_MAX. g = 0 : 1000 (aucune croissance).
function Be.factor(g, cycles)
  local gg = clamp(math.floor(g or 0), 0, Be.G_MAX)
  local f = Be.FACTOR_BASE
  for _ = 1, cycles or Be.CYCLES do
    f = math.floor(f * (1000 + gg) / 1000)
    if f >= Be.FACTOR_MAX then return Be.FACTOR_MAX end
  end
  return f
end

--- Débit demandé (objets/min) d'après le besoin gardé du cerveau (objets) : il se lit comme servi en Be.H_GOALS minutes.
function Be.rate_of_kept(kept)
  return math.max(0, kept or 0) / Be.H_GOALS
end

--- Besoin d'une matière (objets/min) et demande projetée. m = { demand, production, stock, factor } (débits en objets/min,
--- stock en objets, facteur en ‰). Rend besoin, projetée.
function Be.need(m)
  local f = m.factor or Be.FACTOR_BASE
  local projected = math.max(0, m.demand or 0) * f / 1000
  local need = projected - math.max(0, m.production or 0) - math.max(0, m.stock or 0) / Be.H_STOCK
  if need < 0 then need = 0 end
  return need, projected
end

---------------------------------------------------------------------------------------------------
-- 2. Équilibre entre matières sœurs
---------------------------------------------------------------------------------------------------
--- Débits qui consomment chaque matière, dans le graphe des recettes.
--- recipes = { [recette] = { ingredients = { {name, amount} }, products = { {name, amount} }, hidden } } (format de
--- shared/ai3/graphe.lua) ; demand = { [objet] = débit/min } (ce que les buts veulent, objets finis comme intermédiaires) ;
--- opts = { pick = function(objet, liste triée de recettes) -> recette, materials = { [objet] = true } (filtre) }.
--- Rend { cons = { [matière] = { { key = objet consommateur, rate = débit de la matière } } (triés par clé) },
--- total = { [objet] = demande totale propagée } }. Une arête de cycle (recettes circulaires) est ignorée.
function Be.flows(recipes, demand, opts)
  opts = opts or {}
  local prod = {}
  for _, name in ipairs(sorted_keys(recipes)) do
    local r = recipes[name]
    if not r.hidden then
      for _, p in ipairs(r.products or {}) do
        local l = prod[p.name] or {}
        l[#l + 1] = name
        prod[p.name] = l
      end
    end
  end
  local chosen = {}
  local function recipe_of(item)
    if chosen[item] ~= nil then return chosen[item] or nil end
    local l = prod[item]
    local pick = nil
    if l and #l > 0 then pick = opts.pick and opts.pick(item, l) or l[1] end
    chosen[item] = pick or false
    return pick
  end
  -- Ordre topologique (consommateurs avant ingrédients) : parcours en profondeur depuis les objets demandés.
  local order, state = {}, {}
  local function visit(item)
    if state[item] then return end
    state[item] = 1
    local rn = recipe_of(item)
    if rn then
      local ings = {}
      for _, ing in ipairs(recipes[rn].ingredients or {}) do ings[#ings + 1] = ing.name end
      table.sort(ings)
      for _, ing in ipairs(ings) do
        if state[ing] == 1 then -- sur la pile : arête de cycle, ignorée
        else visit(ing) end
      end
    end
    state[item] = 2
    order[#order + 1] = item
  end
  for _, item in ipairs(sorted_keys(demand)) do visit(item) end
  local total = {}
  for _, item in ipairs(sorted_keys(demand)) do total[item] = demand[item] end
  local cons = {}
  local acc = {}
  local pos = {}
  for i, item in ipairs(order) do pos[item] = i end
  for i = #order, 1, -1 do
    local item = order[i]
    local d = total[item] or 0
    local rn = d > 0 and recipe_of(item) or nil
    if rn then
      local r = recipes[rn]
      local per = amount_of(r.products, item)
      if per > 0 then
        local crafts = d / per
        local ings = {}
        for _, ing in ipairs(r.ingredients or {}) do ings[#ings + 1] = ing end
        table.sort(ings, function(a, b) return a.name < b.name end)
        for _, ing in ipairs(ings) do
          -- Un ingrédient déjà traité (rang plus haut dans l'ordre) ferme un cycle : arête ignorée.
          if (pos[ing.name] or 0) < i then
            local use = crafts * (ing.amount or 1)
            total[ing.name] = (total[ing.name] or 0) + use
            if not opts.materials or opts.materials[ing.name] then
              local a = acc[ing.name] or {}
              a[item] = (a[item] or 0) + use
              acc[ing.name] = a
            end
          end
        end
      end
    end
  end
  for _, m in ipairs(sorted_keys(acc)) do
    local l = {}
    for _, k in ipairs(sorted_keys(acc[m])) do l[#l + 1] = { key = k, rate = acc[m][k] } end
    cons[m] = l
  end
  return { cons = cons, total = total }
end

--- Partage d'une OFFRE entre des besoins : la même fraction λ = min(1, offre ÷ somme) pour tous. wants = liste
--- { key, want } (want ≥ 0). Rend { give = { [key] = part }, lambda, total } ; la somme des parts ne dépasse pas l'offre,
--- aucune part ne dépasse son besoin, aucune part n'est nulle tant que l'offre et le besoin sont positifs.
function Be.allocate(supply, wants)
  local total = 0
  for _, w in ipairs(wants) do total = total + math.max(0, w.want or 0) end
  local lambda = 1
  if total > supply then lambda = supply > 0 and supply / total or 0 end
  local give = {}
  for _, w in ipairs(wants) do give[w.key] = math.max(0, w.want or 0) * lambda end
  return { give = give, lambda = lambda, total = total }
end

--- Part maximale que `mine` peut prendre d'une quantité `avail` quand `others` la réclament aussi : proportionnelle au
--- besoin, jamais plus que `mine`, arrondie en dessous.
function Be.limit(avail, mine, others)
  if mine <= 0 then return 0 end
  local tot = mine + math.max(0, others or 0)
  if avail >= tot then return mine end
  return math.floor(math.max(0, avail) * mine / tot)
end

---------------------------------------------------------------------------------------------------
-- 3. Déclencheur d'expansion
---------------------------------------------------------------------------------------------------
--- Taux d'exploitation (%) de gisements connus : foreuses posées ÷ places des gisements connus (bâtis ou retenus).
function Be.saturation(used, capacity)
  if not capacity or capacity <= 0 then return nil end
  return math.min(100, math.floor((used or 0) * 100 / capacity))
end

--- État neuf d'un type (nombres seulement) : explorations vaines de suite, début de la tentative, dernière vaine.
function Be.new_ex() return { tries = 0 } end

--- Décision pour une matière. m = { need (objets/min), sat_pct (nil : inconnu), yield_pct (nil : inconnu),
--- free_sites (sites retenus non bâtis, sûrs), allowed (faux : garde du runtime) } ; ex = Be.new_ex() persistant ; tick.
--- Rend act ("none" | "open" | "explore" | "productivite") et la raison (texte court, ASCII).
function Be.expansion(m, ex, tick)
  ex.tries = ex.tries or 0
  if m.allowed == false then ex.since = nil return "none", "garde" end
  if (m.need or 0) < Be.NEED_MIN then ex.since = nil return "none", "couvert" end
  local trig = (m.sat_pct ~= nil and m.sat_pct >= Be.SAT_PCT)
    or (m.yield_pct ~= nil and m.yield_pct < Be.YIELD_PCT)
  if not trig then ex.since = nil return "none", "marge" end
  if (m.free_sites or 0) > 0 then
    ex.tries, ex.since = 0, nil
    return "open", "site"
  end
  if ex.tries >= Be.TRIES_MAX then
    if tick - (ex.last_fail or 0) >= Be.RETRY_TICKS then ex.tries, ex.since = Be.TRIES_MAX - 1, tick -- une nouvelle tentative
    else return "productivite", "exploration vaine" end
  end
  if not ex.since then
    ex.since = tick
  elseif tick - ex.since >= Be.TRY_TICKS then
    ex.tries, ex.last_fail, ex.since = ex.tries + 1, tick, tick
    if ex.tries >= Be.TRIES_MAX then return "productivite", "exploration vaine" end
  end
  return "explore", "aucun site"
end

---------------------------------------------------------------------------------------------------
-- 4. Prévoyance bornée
---------------------------------------------------------------------------------------------------
--- Combien fabriquer d'avance : ce qui sera posé à brève échéance (`soon`, par exemple les sites retenus), moins ce qui dort
--- déjà au stock, au plus Be.AHEAD_MAX.
function Be.ahead(stock, soon)
  local n = math.min(soon or 0, Be.AHEAD_MAX) - math.max(0, stock or 0)
  return n > 0 and n or 0
end

---------------------------------------------------------------------------------------------------
-- 5. Un chantier à la fois
---------------------------------------------------------------------------------------------------
--- Le plus pressé parmi des candidats { key, need, projected } : plus grand déficit relatif (besoin ÷ projetée, en ‰ entier),
--- puis plus grand besoin, puis clé. Rend la clé, ou nil.
function Be.pick(cands)
  local best, bk = nil, nil
  for _, c in ipairs(cands) do
    local rel = c.projected and c.projected > 0 and math.floor(c.need * 1000 / c.projected) or 0
    local better = false
    if not best then better = true
    elseif rel ~= bk.rel then better = rel > bk.rel
    elseif c.need ~= bk.need then better = c.need > bk.need
    else better = c.key < best.key end
    if better then best, bk = c, { rel = rel, need = c.need } end
  end
  return best and best.key or nil
end

return Be
