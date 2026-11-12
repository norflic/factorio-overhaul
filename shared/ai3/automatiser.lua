--[[
  IA3-e « automatiser ce qui revient » : la règle MAIN → MACHINE (docs/IA3_CERVEAU.md §1.2 H3 et H4, §3.4 ;
  fo-logs/2026-10-25_IA1-d/INTEGRATION.md §6). PUR (aucune API Factorio) : testé hors jeu
  (tests/ai3_automatiser_test.lua) ; le runtime (script/ai3/automatisation.lua) lui donne les mesures et applique ses
  demandes au plan directeur d'IA1-d (Build.request).

  Ce qu'un joueur fait : il fabrique ses 10 premiers engrenages à la main, puis pose un assembleur quand ça devient
  pénible ; il porte ses premières plaques, puis pose des foreuses électriques et un tapis vers ses fours. En calcul :

  1. CHARGE à la main d'un objet P, en PNJ : L = (PNJ-secondes passées sur les tâches qui produisent P : tournées des
     avant-postes de P, fonte au QG, minage à la main de son minerai, fabrication à la main de P) ÷ (60 × minutes de la
     fenêtre). La fenêtre glisse sur A.WINDOW minutes COMPLÈTES (relevées par le runtime à la fin de chaque tâche).
  2. DÉBIT D = objets P livrés au QG par minute (toutes sources : c'est le besoin que l'équipe réalise aujourd'hui).
  3. Module visé (méthode « machine » de P, A.METHODS) dimensionné au débit R = D × (1 + marge) (25 % en sécurité,
     0 % menacé : H4), au plus l'extension maximale du gabarit ; débit nominal R_nom (gabarit de shared/team/modules.lua).
  4. COÛT C (PNJ-secondes) = pose (entités × A.POSE_S) + allers-retours de chantier + fabrication à la main des
     matériaux (livre de recettes, au stock près) + plaques brutes au prix de leur fabrication (L × 60 ÷ D, mesuré ;
     A.PLATE_S sans mesure).
  5. GAIN G (PNJ) = L × min(1, R_nom ÷ D) − logistique qui reste (porteurs des quais d'entrée et de sortie du module).
  6. RETOUR T = C ÷ (60 × G) minutes. On automatise si L > A.LOAD_MIN (0,25 PNJ) en moyenne sur la fenêtre pleine
     (10 min) ET T ≤ H (A.H_SAFE = 20 min en sécurité, A.H_THREAT = 5 min menacé).
  7. Un objet du gabarit que l'équipe ne sait ni fabriquer ni n'a en stock (poteau moyen sans sa technologie) : verdict
     « recherche » ; l'objet est rendu dans `wanted` (le runtime donne de la valeur à la technologie qui le débloque :
     « la recherche vaut ce qu'elle débloque », H9). Aucune demande tant qu'il manque.
  8. Ordre DÉDUIT DU GRAPHE DES RECETTES (consigne du DC, 27/10, 7 h 10 : « un objet attend que ses ingrédients soient
     automatisés. Pas d'une liste de noms ») : profondeur d'un objet = 1 + la plus grande profondeur de ses entrées
     (entrées du gabarit, sinon ingrédients de sa recette ; objet brut : 0) ; les objets sont pesés par profondeur
     croissante, puis charge décroissante, puis nom ; un objet ATTEND (« ordre ») tant qu'une de ses entrées est en route
     vers l'automatisation (demandée, en recherche, en cours, en attente de place, ou elle-même en attente). Au plus
     A.MAX_OPEN modules ouverts à la fois (hors centrale) ; au plus A.MAX_PER_PRODUCT modules finis par objet.
  10. N'IMPORTE QUEL objet (même consigne) : sont pesés les produits de A.METHODS (gabarits écrits à la main, plus
     efficaces : fonderie avec foreuses, îlots de circuits) ET tout objet qui a coûté de la charge à la main dans la
     fenêtre (ou demandé par l'appelant, input.items). Sans gabarit, le module est GÉNÉRÉ depuis les données : rangée
     d'assembleurs (G.simple) de la première machine de A.MACHINES qui fait la catégorie de sa recette, entrées de la
     recette par quais, débit visé. Limites (verdict « limite », raison écrite) : objet brut (extraction seule), recette
     hors de la main (fours, fluides), plus de 2 ingrédients, plusieurs produits (INTEGRATION.md §0).
     Un objet impossible se voit dès A.RESEARCH_WINDOW minutes de fenêtre (la recherche prend du temps) ; la demande
     du module attend la fenêtre pleine.
  9. Refus du plan directeur : coût infini tant que la raison ne change pas (signature `sig` : raison + contexte
     fourni par le runtime, rayon du treillis et poteau disponible).

  Ce module ne connaît le jeu que par ses DONNÉES (A.METHODS : générateurs et paramètres de shared/team/modules.lua) ;
  la décision est la même pour chaque objet. Déterminisme : listes triées, entiers et flottants calculés dans un ordre
  fixe, aucun hasard, aucun pairs décisionnel ; le cache des gabarits est LOCAL (fonction pure de ses paramètres),
  jamais dans global.
]]

local M = require("shared.team.modules")
local T = require("shared.team.config")
local Dm = require("shared.ai3.demande") -- lot C2 : décision sur le débit voulu, seuil du tapis par le coût réel
local D = require("shared.team.automatisation_donnees") -- lot IA3-e : ce que l'exécutant sait poser (données nommées)
local Book = require("shared.team.book") -- lot AUTO : livre de la main, pour A.exec_recipes (même règle que A.method_for)
local Pt = require("shared.team.patrons") -- lot INDUSTRIE I6 : patrons (cellule, bloc) des recettes que la rangée simple refuse
local L = require("shared.ai3.lecture") -- lot INDUSTRIE I6 : recettes et machines lues (cat.fab), lot I4
local Pl = require("shared.team.plan") -- lot INDUSTRIE I6 : le coffre de sortie que le plan directeur pose (P.out_quai)

local A = {}

A.WINDOW = 10            -- minutes de la fenêtre glissante (H3 : « pendant 10 min »)
A.LOAD_MIN = 0.25        -- PNJ (H3)
A.H_SAFE = 20            -- minutes (horizon du chef en sécurité)
A.H_THREAT = 5           -- minutes (menacé)
A.MARGIN_SAFE = 25       -- % de débit en plus en sécurité (H4)
A.MARGIN_THREAT = 0
A.POSE_S = 1.5           -- s de pose par entité (plan directeur : ravivage + marche locale)
A.BATCH = 12             -- entités par aller-retour de chantier (le PNJ prend un lot au point d'appui)
A.WALK = 8               -- tuiles par seconde (personnage : 0,15 tuile par tick, marge pour les détours)
A.HANDLE_S = 10          -- s de prise et de dépôt par aller-retour
A.DIST = 56              -- tuiles du QG au module (2 lots) quand le runtime ne la donne pas
A.PLATE_S = 1.0          -- PNJ-s par plaque brute sans mesure (minage à la main 1 s + fonte, à la louche)
A.QUAI_FILL = 400        -- objets portés au quai d'entrée par aller-retour (Build.QUAI_FILL)
A.COLLECT_AT = 200       -- objets rapportés du quai de sortie par aller-retour (Build.COLLECT_AT)
A.BELT_FLOW = 1.0        -- objets/s : au-delà, une voie de minerai est servie par tapis depuis des foreuses (P.AUTO_FLOW)
A.QUAI_RATE = 0.635      -- objets/s d'un bras simple au quai de sortie (0,83 × 0,85 × 0,9 : M.choose_inserters) ; au-delà,
                         -- le plan directeur pose un bras RAPIDE (technologie) : la taille du module se règle sur ce qui se
                         -- fabrique (moteur réel, e4-usine : fonderie de 7 rangées, 2 bras rapides impossibles, réserve 15 min)
A.FIRST_RATE_MAX = 150   -- objets/min au plus pour le PREMIER module d'un objet (on commence petit, on agrandit ensuite :
                         -- e4-usine, fonderie de 7 rangées à 93 entités jamais payée)
A.DRILL_RATE = 0.5       -- minerai/s d'une foreuse électrique (vitesse 0,5, temps 1 s)
A.BELT_LEN = 28          -- tuiles de tapis estimées des foreuses à la tête d'alimentation (un pas de treillis)
A.NET_POLES = 3          -- poteaux de réseau estimés jusqu'au carrefour le plus proche
A.MAX_OPEN = 2           -- modules ouverts à la fois (chantier, plan, réserve), hors centrale : fer et cuivre ensemble
A.RESEARCH_WINDOW = 5    -- minutes : un objet impossible (recherche) se voit dès la demi-fenêtre (la recherche prend du temps)
A.MAX_PER_PRODUCT = 2    -- modules finis au plus par objet
A.VALUE = 64             -- valeur de base du projet d'un module (famille capital, pondérée par le chef)…
A.VALUE_PER_PNJ = 8      -- … plus 8 par PNJ libéré (gain G), au plus A.VALUE_MAX : un module qui libère 2 PNJ passe
A.VALUE_MAX = 90         -- devant l'armée et la recherche au service du fer (piège de pauvreté, e3-usine : réserve
                         -- « materiaux » 64 min, le fer mangé par l'armée et les munitions servies avant lui)
A.BURNER_RATE = 0.25     -- minerai/s d'une foreuse à combustion (avant-postes : capacité d'un module en unités d'avant-poste)

-- Méthodes « machine », centrale, machines des rangées générées et pièces du plan directeur : données NOMMÉES de
-- l'exécutant (shared/team/automatisation_donnees.lua, hors des fichiers de décision : règle anti-échelle d'IA-G).
A.METHODS = D.METHODS
A.PLANT = D.PLANT

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

---------------------------------------------------------------------------------------------------
-- Gabarits (cache LOCAL : fonction pure des paramètres)
---------------------------------------------------------------------------------------------------
local cache = {}
local kit_cache = {} -- lot INDUSTRIE I6 : mémo LOCAL (fonction pure de la lecture) : signature des pièces -> kit
local pm_cache = {}  -- lot INDUSTRIE I6 : mémo LOCAL des méthodes « patron » : objet|kit|machines utilisables -> méthode

local function args_key(gen, args)
  local parts = { gen }
  for i = 1, #args do
    local a = args[i]
    -- recette tirée des données (G.simple) : son NOM (une adresse de table changerait d'une pensée à l'autre)
    if type(a) ~= "table" then
      parts[#parts + 1] = tostring(a)
    elseif a.name ~= nil then
      parts[#parts + 1] = "{" .. tostring(a.name) .. "}"
    elseif a.bras ~= nil then
      -- lot INDUSTRIE I6 : kit d'un patron = les noms de ses pièces, triés (jamais sa déclaration `decl`)
      local ks = {}
      for _, k in ipairs(sorted_keys(a)) do if type(a[k]) == "string" then ks[#ks + 1] = k .. "=" .. a[k] end end
      parts[#parts + 1] = "kit{" .. table.concat(ks, ",") .. "}"
    else
      -- lot INDUSTRIE I6 : liste de recettes d'un bloc = leurs noms
      local ns = {}
      for _, r in ipairs(a) do ns[#ns + 1] = tostring(type(r) == "table" and r.name or r) end
      parts[#parts + 1] = "[" .. table.concat(ns, ",") .. "]"
    end
  end
  return table.concat(parts, "|")
end

--- Résumé d'un gabarit : { key, n_ent, items = { [objet] = n }, nominal = { [objet] = n/s }, inputs = { [objet] = n/s },
--- power_kw, ext = { arg, max }, args } ou nil, raison. Les entités vanilla se posent par l'objet de même nom.
function A.template(gen, args, pole, arms)
  -- lot RECHERCHE-BRAS : `arms` = bras OBTENABLES (A.choose_arms, nil : tous) ; le gabarit est fait avec eux, à la cadence qu'ils tiennent
  local k = args_key(gen, args) .. (pole and ("#" .. pole) or "") .. (arms and ("@" .. table.concat(arms, ",")) or "")
  local c = cache[k]
  if c ~= nil then
    if c == false then return nil, "gabarit refuse" end
    return c
  end
  local fn = M.GEN[gen]
  if not fn then cache[k] = false return nil, "generateur inconnu" end
  local g, why = M.with_arms(arms, M.with_pole, pole, fn, table.unpack(args))
  -- un poteau plus court couvre parfois moins bien (bras ou machine hors de l'aire des poteaux, fils trop longs) : le
  -- gabarit est contrôlé (M.check) et cède au poteau par défaut s'il est refusé
  if g and pole and pole ~= M.DEFAULT_POLE and #M.check(g) > 0 then g = nil end
  if not g and pole then
    -- Lot PLANDIR : le poteau choisi ne couvre pas ce gabarit (portée plus courte) : le poteau par défaut le pose
    local c2 = A.template(gen, args, nil, arms)
    cache[k] = c2 or false
    return c2, c2 == nil and why or nil
  end
  if not g and arms then
    -- lot RECHERCHE-BRAS : les bras obtenables ne tiennent pas ce gabarit (cadence sous M.ARM_F_MIN) : le gabarit à tous les bras, comme
    -- avant le lot (le bras rapide est alors un objet à rechercher)
    local c3 = A.template(gen, args, pole)
    cache[k] = c3 or false
    return c3, c3 == nil and why or nil
  end
  if not g then cache[k] = false return nil, why end
  local items, recipes = {}, {}
  for _, e in ipairs(g.entities) do
    items[e.name] = (items[e.name] or 0) + 1
    -- lot AUTO : recettes que le gabarit donne à ses machines ({ [entité] = { [recette] = vrai } }, A.exec_recipes)
    if type(e.recipe) == "string" then
      recipes[e.name] = recipes[e.name] or {}
      recipes[e.name][e.recipe] = true
    end
  end
  local ex = g.extensions and g.extensions[1]
  c = { key = g.key, n_ent = #g.entities, items = items, recipes = recipes, nominal = g.nominal or {}, inputs = g.inputs or {},
    power_kw = g.power_kw or 0, ext = ex and { arg = ex.arg, max = ex.max } or nil, args = args, gen = gen,
    pole = g.pole_name, arms = g.arms }
  cache[k] = c
  return c
end

--- Lot PLANDIR : poteau des gabarits d'une équipe = le moins cher DONT LA RECETTE EST DÉBLOQUÉE (livre de la main, qui ne
--- compte que les recettes ouvertes) ou déjà au coffre, et dont les matières NATURELLES (aucune recette ne les produit : le
--- bois) sont au coffre pour A.POLE_BATCH poteaux. Rend le nom (table triée de shared/team/modules.lua) ou nil : le poteau
--- par défaut. Les plaques, câbles et bâtons ne bloquent pas : fonderie et main les fournissent.
A.POLE_BATCH = 12 -- lot ELECTRIQUE (d, lead 8/11) : la taille du gabarit de fonderie au petit poteau (12), et non 20
--- Lot KIT : `harvest` = { [matière] = vrai } des matières naturelles que l'équipe peut RÉCOLTER (des arbres à portée pour le
--- bois, lus à f.team.ia3.reach) : une matière naturelle récoltable n'interdit plus le poteau qui l'utilise, l'ouvrier la
--- coupe (les factions n'ont plus de bois au coffre de départ). Sans arbre à portée : comportement d'avant (le moyen).
function A.choose_pole(book, stock, harvest)
  stock = stock or {}
  return M.cheapest_pole(function(name)
    if (stock[name] or 0) >= A.POLE_BATCH then return true end
    if not book:handcraftable(name) then return false end
    local plan = book:plan({ { name, A.POLE_BATCH } }, stock)
    return A.only_made(book, plan.raw, harvest) -- lot CC-BOIS : même lecture que l'achat du bloc (A.short_of), décision inchangée
  end)
end

--- Lot CC-BOIS (F504) : une matière NATURELLE (aucune recette ne la produit : le bois, la pierre) que l'équipe peut RÉCOLTER (`harvest`,
--- lot KIT : { [matière] = rayon } lu au cerveau) n'est pas un manque : l'ouvrier la coupe ou la mine. Lecture UNIQUE du poteau
--- (A.choose_pole) et de l'achat d'un bloc du mall (script/ai3/industrie.lua, afford_list) : avant, le petit poteau était choisi
--- « parce que le bois se récolte », puis le bloc qui le porte était refusé « faute de bois au stock hors besoin » (partie 0.6.89 du DC,
--- Ambre : tous ses blocs du mall en attente de 30 à 82 min, 5 007 fer au coffre). Rend la liste TRIÉE { { objet, n } } des manques
--- bruts (`raw` = plan.raw de Book:plan) qui bloquent vraiment : les matières fabriquées, et les naturelles hors de portée.
function A.harvested(book, k, harvest)
  return book:natural(k) and harvest ~= nil and harvest[k] ~= nil and harvest[k] ~= false
end
function A.short_of(book, raw, harvest)
  local out = {}
  for _, k in ipairs(sorted_keys(raw)) do
    if (raw[k] or 0) > 0 and not A.harvested(book, k, harvest) then out[#out + 1] = { k, raw[k] } end
  end
  return out
end

--- Le manque du poteau ne compte que ses matières NATURELLES (A.choose_pole d'avant : plaques, câbles et bâtons ne bloquent pas, la
--- fonderie et la main les fournissent) : vrai quand tout ce qui reste de `A.short_of` est une matière fabriquée.
function A.only_made(book, raw, harvest)
  for _, it in ipairs(A.short_of(book, raw, harvest)) do
    if book:natural(it[1]) then return false end
  end
  return true
end

--- Lot RECHERCHE-BRAS : les bras des gabarits d'une équipe = ceux qu'elle sait avoir : au coffre en nombre suffisant (A.ARM_STOCK), ou
--- fabricables à la main (livre de la main : recettes OUVERTES). Rend la liste (du plus lent au plus rapide, M.ARMS : lue aux données, aucun
--- nom écrit) des bras obtenables, ou nil quand TOUS le sont (rien à limiter : comportement d'avant) ou qu'AUCUN ne l'est (rien à
--- bâtir de toute façon : même comportement). Un gabarit fait avec cette liste tourne moins vite plutôt que d'exiger un bras à rechercher.
A.ARM_STOCK = 8 -- bras d'un type au coffre au-delà desquels il compte comme obtenable (la taille d'une rangée de bras d'un module)
function A.choose_arms(book, stock)
  stock = stock or {}
  local ok = {}
  for _, name in ipairs(M.ARMS) do
    if (stock[name] or 0) >= A.ARM_STOCK or book:handcraftable(name) then ok[#ok + 1] = name end
  end
  if #ok == 0 or #ok == #M.ARMS then return nil end
  return ok
end

--- Lot KIT : matières NATURELLES (aucune recette ne les produit : le bois) qu'il faut pour A.POLE_BATCH poteaux de chaque
--- type de poteau, DÉDUITES du livre et de la table des poteaux (shared/team/modules.lua) : aucun nom écrit. Liste triée.
function A.natural_needs(book)
  local set = {}
  for _, name in ipairs(M.POLES) do
    if book:handcraftable(name) then
      local plan = book:plan({ { name, A.POLE_BATCH } }, {})
      for _, k in ipairs(sorted_keys(plan.raw)) do
        if book:natural(k) then set[k] = true end
      end
    end
  end
  return sorted_keys(set)
end

--- Vide le cache (tests).
function A.reset_cache() cache, kit_cache, pm_cache = {}, {}, {} end

--- Lot AUTO : entités que l'EXÉCUTANT de l'automatisation sait poser et faire tourner, DÉDUITES de ses gabarits (aucun
--- nom écrit ici) : celles des méthodes écrites (A.METHODS), des foreuses qui servent leur minerai, de la centrale
--- (A.PLANT) et les machines des rangées générées (A.MACHINES). Le cerveau général (script/ai3/general.lua,
--- General.exec_opts) les ajoute à ses exécutants quand l'automatisation est allumée : l'électricité (générateur,
--- chaudière, pompe) et les recettes des assembleurs deviennent payables au sens du graphe (H8). Liste triée.
function A.exec_entities()
  local set = {}
  local function add(gen, args)
    local t = A.template(gen, args)
    if t then for _, k in ipairs(sorted_keys(t.items)) do set[k] = true end end
  end
  for _, m in ipairs(A.METHODS) do
    add(m.gen, m.args)
    if m.ore then add("drills", { m.ore, 1 }) end
  end
  add(A.PLANT.gen, A.PLANT.args)
  for _, name in ipairs(A.MACHINES) do set[name] = true end
  -- lot INDUSTRIE I6 : les machines des patrons (lues dans les prototypes) et les pièces du kit sont posées par l'exécutant
  local lec = A.lecture()
  if lec then
    for _, rn in ipairs(sorted_keys(lec.fab)) do
      local e = lec.fab[rn]
      if e.patronnable and #e.fluides_in == 0 then
        -- les machines d'assemblage seulement : les fours restent au décideur des fours (SCALE), un patron n'en pose pas
        for _, m in ipairs(e.machines) do if m.type == "assembling-machine" then set[m.entity] = true end end
      end
    end
    local kit = lec.kit(nil)
    for _, k in ipairs({ "bras", "bras_long", "tapis", "coffre", "poteau" }) do
      if kit[k] then set[kit[k].entity] = true end
    end
  end
  return sorted_keys(set)
end

--- Lot AUTO (correction après revue, règle H8) : ce que chaque MACHINE DE FABRICATION de l'exécutant sait LANCER,
--- recette par recette, et non tout ce que ses catégories permettent en jeu. Rend { [entité] = { [recette] = vrai } }
--- pour :
---   - les machines des gabarits écrits (A.METHODS) : les recettes que le gabarit leur donne ;
---   - les machines des rangées générées (A.MACHINES) : les recettes pour lesquelles A.method_for génère une rangée sur
---     elles, sur le livre de la main bâti depuis `recipes` (la règle de la rangée G.simple : ingrédients solides, 1 ou
---     2 ingrédients, un produit ; première machine de A.MACHINES qui fait sa catégorie). Une machine qu'aucune recette
---     ne choisit rend un ensemble VIDE : elle ne fait rien pour le graphe.
--- Une recette à fluide en entrée ou en sortie (rangée : « demande un fluide »), à plus de 2 ingrédients hors d'un
--- gabarit écrit, ou hors du livre de la main n'y est donc jamais : en jeu, une machine saurait la faire, mais aucun
--- exécutant ne sait la lancer (revue du lot AUTO : le béton et les barils d'eau devenaient faisables, réglage allumé).
--- `recipes` : le relevé du catalogue ({ [nom] = { category, energy, hidden, ingredients, products } }). Fonction pure.
function A.exec_recipes(recipes)
  local out = {}
  local function add(entity, rname)
    out[entity] = out[entity] or {}
    if rname then out[entity][rname] = true end
  end
  for _, name in ipairs(A.MACHINES) do add(name) end
  for _, m in ipairs(A.METHODS) do
    local t = A.template(m.gen, m.args)
    if t then
      for _, e in ipairs(sorted_keys(t.recipes)) do
        for _, rn in ipairs(sorted_keys(t.recipes[e])) do add(e, rn) end
      end
    end
  end
  local book = Book.new(recipes or {})
  -- Lot INDUSTRIE I6 (relecture 0.6.31) : une machine lue n'a que ses recettes de patron, ou un ensemble VIDE : à « vrai » (A.add_executors), elle
  -- faisait TOUTE sa catégorie pour le graphe et pour Fl.executors (done_by) : recettes à fluide « payables » et jamais de cellule de pétrole.
  local lec = A.lecture()
  local fab = lec and lec.fab or {}
  for _, rn in ipairs(sorted_keys(fab)) do
    for _, m in ipairs(fab[rn].machines or {}) do if m.type == "assembling-machine" then add(m.entity) end end
  end
  for _, item in ipairs(sorted_keys(book.by_product)) do
    local m = A.method_for(item, book)
    if m and m.generic then
      if m.patron then
        -- toutes les machines de la recette : A.method_for prend la plus rapide UTILISABLE, le graphe ne doit pas exiger la plus rapide du jeu
        add(m.args[1], m.args[2].name)
        for _, em in ipairs((fab[m.args[2].name] or {}).machines or {}) do
          if em.type == "assembling-machine" then add(em.entity, m.args[2].name) end
        end
      else
        add(m.args[3], m.args[1].name)
      end
    end
  end
  return out
end

--- Lot AUTO (correction après revue) : ajoute à `exec` (exécutants du catalogue, shared/ai3/catalogue.lua :
--- { [entité] = vrai | { [recette] = vrai } }) ceux de l'automatisation : chaque entité de ses gabarits
--- (A.exec_entities) ; une machine de fabrication n'y lance que ses recettes (A.exec_recipes) ; une entité déjà
--- exécutante de TOUTES ses recettes (fours du QG) le reste. Rend exec (modifié sur place).
function A.add_executors(exec, recipes)
  local runs = A.exec_recipes(recipes)
  for _, name in ipairs(A.exec_entities()) do
    if exec[name] ~= true then exec[name] = runs[name] or true end
  end
  return exec
end

--- Gabarit d'une méthode dimensionné au débit `rate` (objets/min du produit) : (résumé, args) ou nil, raison.
function A.sized(method, rate, pole, arms)
  local base, why = A.template(method.gen, method.args, pole, arms)
  if not base then return nil, why end
  local nom = (base.nominal[method.product] or 0) * 60
  if nom <= 0 then return nil, "debit nominal nul" end
  local args = {}
  for i = 1, #method.args do args[i] = method.args[i] end
  if base.ext and base.ext.max >= 1 then
    local cur = args[base.ext.arg]
    local n = math.ceil(cur * rate / nom - 1e-9)
    if n < 1 then n = 1 end
    if n > base.ext.max then n = base.ext.max end
    args[base.ext.arg] = n
  end
  local g, why2 = A.template(method.gen, args, pole, arms)
  if not g then return nil, why2 end
  return g, args
end

---------------------------------------------------------------------------------------------------
-- Mesures de la fenêtre
---------------------------------------------------------------------------------------------------
--- Charge (PNJ), débit (objets/min) et logistique (PNJ) moyens d'un objet sur la fenêtre. window = liste de minutes
--- COMPLÈTES { m, load = { [objet] = ticks }, made = { [objet] = n }, logi = { [objet] = ticks } } (ordre croissant).
--- after (facultatif) : seules les minutes m > after comptent (après la fin d'un module du même objet).
--- Rend L, D, Lres, n (minutes comptées).
function A.measure(window, item, after)
  local n = 0
  local load, made, logi = 0, 0, 0
  local first = math.max(1, #window - A.WINDOW + 1)
  for i = first, #window do
    local b = window[i]
    if after and (b.m or 0) <= after then goto skip end
    n = n + 1
    load = load + ((b.load or {})[item] or 0)
    made = made + ((b.made or {})[item] or 0)
    logi = logi + ((b.logi or {})[item] or 0)
    ::skip::
  end
  if n == 0 then return 0, 0, 0, 0 end
  return load / (n * 3600), made / n, logi / (n * 3600), n
end

---------------------------------------------------------------------------------------------------
-- Coût et gain
---------------------------------------------------------------------------------------------------
--- Entités supplémentaires estimées du plan directeur autour d'un gabarit : foreuses et leur tapis (voie de minerai
--- au-delà de A.BELT_FLOW), quais d'entrée (autres voies), quais de sortie, poteaux de réseau. Rend items, n, quais
--- d'entrée { { objet, flux/s } }, quais de sortie (nombre).
local function feed_extra(method, g, belt_flow)
  belt_flow = belt_flow or A.BELT_FLOW
  local items, n = {}, 0
  local function add(name, k) items[name] = (items[name] or 0) + k; n = n + k end
  local quais_in = {}
  for _, it in ipairs(sorted_keys(g.inputs)) do
    local flow = g.inputs[it]
    if method.ore == it and flow >= belt_flow then
      local nd = math.max(1, math.ceil(flow / (2 * A.DRILL_RATE) - 1e-9))
      local d = A.template("drills", { it, nd }, g.pole)
      if d then
        for _, name in ipairs(sorted_keys(d.items)) do add(name, d.items[name]) end
      end
      add(D.PARTS.belt, A.BELT_LEN)
    else
      quais_in[#quais_in + 1] = { it, flow }
      add(D.PARTS.chest, 1)
      add(D.PARTS.arm, 1)
    end
  end
  local outn = 0
  for _, it in ipairs(sorted_keys(g.nominal)) do if it ~= "electricity-kw" then outn = outn + g.nominal[it] end end
  -- un quai de sortie par port de sortie : les fonderies en ont deux (une rangée de fours chacune) ; bras rapide quand un
  -- bras simple ne suffit pas (choix du plan directeur, P.out_quai)
  local ports = method.gen == "smelter" and 2 or 1
  add(D.PARTS.chest, ports)
  -- lot RECHERCHE-BRAS : le bras rapide du quai ne se compte que s'il est obtenable (g.arms : bras du gabarit ; nil : tous)
  local fast_ok = true
  if g.arms then
    fast_ok = false
    for _, a in ipairs(g.arms) do if a == D.PARTS.fast_arm then fast_ok = true end end
  end
  add(outn / ports > A.QUAI_RATE and fast_ok and D.PARTS.fast_arm or D.PARTS.arm, ports)
  if (g.power_kw or 0) > 0 then add(g.pole or D.PARTS.pole, A.NET_POLES) end
  return items, n, quais_in, ports
end

--- Coût (PNJ-secondes) et matériaux d'un module : C, items (objet -> n), n_ent, détail.
--- ctx = { book, stock, dist, price = { [plaque] = PNJ-s }, has_plant }.
function A.cost(method, g, ctx)
  local items = {}
  for _, name in ipairs(sorted_keys(g.items)) do items[name] = g.items[name] end
  local extra, n_extra, quais_in, outs = feed_extra(method, g, ctx.belt_flow)
  for _, name in ipairs(sorted_keys(extra)) do items[name] = (items[name] or 0) + extra[name] end
  local n_ent = g.n_ent + n_extra
  if (g.power_kw or 0) > 0 and not ctx.has_plant then
    local pl = A.template(A.PLANT.gen, A.PLANT.args, g.pole)
    if pl then
      for _, name in ipairs(sorted_keys(pl.items)) do items[name] = (items[name] or 0) + pl.items[name] end
      items[D.PARTS.chest] = (items[D.PARTS.chest] or 0) + 1
      -- lot PLANDIR (T2) : le bras du quai de la centrale est à combustion au démarrage (build.lua, plan_feed)
      items[M.BURNER_ARM] = (items[M.BURNER_ARM] or 0) + 1
      n_ent = n_ent + pl.n_ent + 2
    end
  end
  local dist = ctx.dist or A.DIST
  local pose = n_ent * A.POSE_S + math.ceil(n_ent / A.BATCH) * (2 * dist / A.WALK + A.HANDLE_S)
  local list = {}
  for _, name in ipairs(sorted_keys(items)) do list[#list + 1] = { name, items[name] } end
  local craft_s, raw_s = 0, 0
  local raw = {}
  if ctx.book then
    local p = ctx.book:plan(list, ctx.stock or {})
    for _, c in ipairs(p.crafts) do craft_s = craft_s + c.energy end
    for _, k in ipairs(sorted_keys(p.raw)) do
      raw[k] = p.raw[k]
      local price = (ctx.price or {})[k] or A.PLATE_S
      raw_s = raw_s + p.raw[k] * price
    end
  end
  return pose + craft_s + raw_s, items, n_ent, { pose = pose, craft = craft_s, raw = raw_s, quais_in = quais_in, outs = outs }
end

--- Lot C2 : coût RÉEL (PNJ-secondes) d'une voie de minerai servie par foreuses et tapis : une paire de foreuses, le tapis jusqu'à la tête
--- d'alimentation (A.BELT_LEN), leur pose et leurs matières lues au livre. ctx = { book, stock, dist, price }. Rend le coût ou nil.
function A.belt_cost(ctx)
  local ore = nil
  for _, m in ipairs(A.METHODS) do if m.ore then ore = m.ore break end end
  local d = ore and A.template("drills", { ore, 1 })
  if not d then return nil end
  local items = {}
  for _, name in ipairs(sorted_keys(d.items)) do items[name] = d.items[name] end
  items[D.PARTS.belt] = (items[D.PARTS.belt] or 0) + A.BELT_LEN
  local c = A.cost({ gen = "drills" }, { items = items, n_ent = d.n_ent + A.BELT_LEN, inputs = {}, nominal = {}, power_kw = 0 }, ctx)
  return c
end

--- Lot C2 (AUDIT n°3 : 152 refus « copper-ore 0.63/s, sous le seuil du tapis ») : seuil du tapis (objets/s) par le coût réel de la voie
--- contre le gain des porteurs, retour accepté `tmax` minutes (shared/ai3/demande.lua, Dm.belt_flow) ; jamais plus strict que A.BELT_FLOW.
function A.belt_flow(ctx, tmax)
  if not (ctx and ctx.book) then return A.BELT_FLOW end -- sans livre, les matières sont inconnues : le coût serait sous-estimé
  return Dm.belt_flow(A.belt_cost(ctx), A.PLATE_S, tmax, A.BELT_FLOW)
end

--- Logistique qui RESTE avec le module (PNJ) : porteurs des quais d'entrée et de sortie.
function A.residual(det, rate_nom_min, dist)
  local trip = 2 * (dist or A.DIST) / A.WALK + A.HANDLE_S
  local trips = 0
  for _, q in ipairs(det.quais_in or {}) do trips = trips + q[2] * 60 / A.QUAI_FILL end
  trips = trips + rate_nom_min / A.COLLECT_AT
  return trips * trip / 60
end

---------------------------------------------------------------------------------------------------
-- Graphe des recettes et méthodes générées (consigne du DC du 27/10, 7 h 10)
---------------------------------------------------------------------------------------------------
--- Machines essayées, dans l'ordre, pour un module généré : la première dont les catégories contiennent celle de la
--- recette (M.spec). Un objet de la machine que l'équipe ne sait pas fabriquer fait « recherche » (point 7).
A.MACHINES = D.MACHINES

-- Index produit -> recette de TOUT le livre (fours et fluides compris : le graphe, pas la main). Cache LOCAL par livre
-- (table faible), construit dans l'ordre des noms : fonction pure des recettes.
local INDEX = setmetatable({}, { __mode = "k" })
local function recipe_index(book)
  if not (type(book) == "table" and type(book.recipes) == "table") then return {} end
  local idx = INDEX[book]
  if idx then return idx end
  idx = {}
  for _, name in ipairs(sorted_keys(book.recipes)) do
    local r = book.recipes[name]
    local pr = r.products or {}
    if not r.hidden and #pr == 1 and pr[1].name then
      local p = pr[1].name
      local cur = idx[p]
      if not cur or (name == p and cur ~= p) then idx[p] = name end
    end
  end
  INDEX[book] = idx
  return idx
end

--- Lot PLANDIR (T1) : la MEILLEURE machine de fabrication dont `usable(nom)` est vrai (recette ouverte ou au coffre) parmi
--- A.MACHINES, qui fait toutes les catégories de `cats` : la plus rapide (données de shared/team/modules.lua), à égalité
--- la première de la liste. Sans machine utilisable (ou `usable` nil), la première de la liste qui fait les catégories
--- (comportement d'avant : l'objet impossible fait rechercher). Rend le nom ou nil.
function A.pick_machine(cats, usable)
  local first, best, best_speed
  for _, name in ipairs(A.MACHINES) do
    local sp = M.spec(name)
    local ok = sp ~= nil
    for _, c in ipairs(cats or {}) do
      local has = false
      for _, c2 in ipairs(sp and sp.categories or {}) do if c2 == c then has = true end end
      ok = ok and has
    end
    if ok then
      first = first or name
      if usable and usable(name) and (not best or (sp.speed or 0) > best_speed) then best, best_speed = name, sp.speed or 0 end
    end
  end
  return best or first
end

local MACHINE_SET = {}
for _, name in ipairs(A.MACHINES) do MACHINE_SET[name] = true end

---------------------------------------------------------------------------------------------------
-- Lot INDUSTRIE I6 : les patrons (shared/team/patrons.lua) pour ce que la rangée simple refuse
---------------------------------------------------------------------------------------------------
--- Fournisseur de la lecture (cat.fab, cat.kit) posé par le runtime (script/ai3/industrie.lua) : fonction -> { fab, kit = function(usable) }
--- ou nil (réglage maître éteint, ou rien de lu). Local au module, jamais dans global, reconstruit à la demande.
local lecture_provider = nil
function A.set_lecture_provider(fn) lecture_provider = fn end
function A.lecture()
  if not lecture_provider then return nil end
  local lec = lecture_provider()
  if type(lec) == "table" and type(lec.fab) == "table" and type(lec.kit) == "function" then return lec end
  return nil
end

-- Le coffre que le plan directeur pose lui-même à la sortie d'un module (P.out_quai) : c'est celui que les PNJ savent vider
-- (script/team/build.lua, mode collect), donc celui des sorties en coffre d'un patron. Lu au plan, jamais écrit ici.
local exec_chest_name
local function exec_chest()
  if exec_chest_name == nil then
    exec_chest_name = false
    for _, e in ipairs(Pl.out_quai({ x = 0, y = 0, dir = 0 }, nil, 1)) do
      if e.role == "sortie" then exec_chest_name = e.name end
    end
  end
  return exec_chest_name or nil
end
A.exec_chest = exec_chest

--- Déclaration à M (modules.lua) des machines et des pièces du kit qu'il ne connaît pas (P.redeclare) : aussi faite par les générateurs
--- « patron » et « bloc » de M.GEN à partir de leurs arguments.
local function declare(decl) Pt.redeclare(M, decl) end
A.declare = declare

--- Kit de logistique d'un patron : noms des pièces (dont le coffre du plan directeur), plus `decl` pour les redéclarer. Rend (kit, lu)
--- ou (nil, raison). Les pièces non débloquées (usable) sont tout de même prises (le moins cher par type, parmi toutes) : la
--- recherche qui les débloque est demandée par module_ok, comme pour toute pièce d'un gabarit.
function A.patron_kit(lec, usable)
  local lu = lec.kit(usable)
  if #(lu.manque or {}) > 0 then lu = lec.kit(nil) end
  if #(lu.manque or {}) > 0 then return nil, "limite : kit de logistique incomplet (" .. table.concat(lu.manque, ",") .. ")" end
  local sig = {}
  for _, k in ipairs({ "bras", "bras_long", "tapis", "coffre", "poteau" }) do sig[#sig + 1] = lu[k].entity end
  local sg = table.concat(sig, "|")
  if kit_cache[sg] then return kit_cache[sg] end
  local pieces = {}
  for _, k in ipairs({ "bras", "bras_long", "tapis", "coffre", "poteau" }) do pieces[k] = lu[k] end
  local names, why = Pt.declare_kit(M, pieces)
  if not names then return nil, why end
  local chest = exec_chest()
  if chest and M.BASE[chest] and M.BASE[chest].kind == "chest" then names.coffre = chest end
  names.decl = { kit = pieces, machines = {} }
  kit_cache[sg] = names
  return names, pieces
end


--- Méthode « patron » d'un objet (recette `r` du livre, entrée lue `e`) ou (nil, raison). Machine : la plus rapide utilisable que
--- le gabarit accepte ; sortie : tapis quand le plan directeur sait le servir (4 entrées au plus, un produit solide), sinon
--- coffre. n = 1 : A.sized dimensionne ensuite sur le débit.
local function patron_method(item, rname, r, usable, why_simple)
  local lec = A.lecture()
  if not lec then return nil, why_simple end
  local e = lec.fab[rname]
  if not e then return nil, why_simple end
  if not e.patronnable then return nil, (e.refus and e.refus.texte) or why_simple end
  if #(e.fluides_in or {}) > 0 then return nil, why_simple end
  local kit, why_kit = A.patron_kit(lec, usable)
  if not kit then return nil, why_kit end
  local ms = L.machines_for(e, usable)
  if #ms == 0 then ms = e.machines end
  local mk = {}
  for _, m in ipairs(ms) do mk[#mk + 1] = m.entity end
  local ck = item .. "#" .. rname .. "#" .. tostring(kit.bras) .. "#" .. table.concat(mk, ",")
  if pm_cache[ck] ~= nil then
    if pm_cache[ck] == false then return nil, "limite : aucun patron ne tient " .. rname end
    for _, d in ipairs(pm_cache[ck].args[5].decl.machines) do declare({ machines = { d } }) end
    return pm_cache[ck]
  end
  local def = { name = rname, category = r.category, energy = r.energy, ingredients = r.ingredients, products = r.products }
  local last_why = "limite : aucune machine ne tient le patron"
  for i = #ms, 1, -1 do
    local m = ms[i]
    local k2 = {}
    for kk, v in pairs(kit) do k2[kk] = v end
    k2.decl = { kit = kit.decl.kit, machines = { { machine = m, categories = { e.category } } } }
    declare(k2.decl)
    local sortie = (e.s <= 4 and e.sorties_solides == 1) and "tapis" or "coffre"
    for _, so in ipairs({ sortie, "coffre" }) do
      local meth = { product = item, gen = "patron", args = { m.entity, def, so, 1, k2, 0 }, feed = true, generic = true, patron = true }
      local g, why = A.template(meth.gen, meth.args)
      if g then
        pm_cache[ck] = meth
        return meth
      end
      last_why = tostring(why)
      if sortie == "coffre" then break end
    end
  end
  pm_cache[ck] = false
  return nil, last_why
end

--- Méthode « machine » d'un objet : celle de A.METHODS s'il en a une, sinon un module GÉNÉRÉ depuis la recette de la main
--- (rangée G.simple), sinon (lot INDUSTRIE I6) un PATRON depuis la lecture des prototypes (3 à 8 entrées, plusieurs produits,
--- catégorie hors de A.MACHINES). Rend la méthode, ou nil et la raison de la limite. `usable` (facultatif, lot PLANDIR T1) : les
--- machines du module sont les meilleures utilisables (A.pick_machine), jamais plus lentes que celles écrites.
function A.method_for(item, book, usable)
  local meth, why = A.simple_method(item, book, usable)
  -- une rangée générée dont le gabarit est refusé (bras trop lents pour 8 plaques par fabrication : le coffre de fer, 16 plaques/s)
  -- cède au patron, qui baisse la cadence à ce que les bras du kit tiennent ; sans patron, la rangée refusée reste (comme avant)
  if meth and not (meth.generic and not A.template(meth.gen, meth.args)) then return meth end
  local rname = type(book) == "table" and book.recipe_for and book:recipe_for(item) or nil
  rname = rname or recipe_index(book)[item]
  local r = rname and book.recipes[rname]
  if not r then return meth, why end
  local pm, pwhy = patron_method(item, rname, r, usable, why)
  if pm then return pm end
  if meth then return meth end
  return nil, pwhy or why
end

function A.simple_method(item, book, usable)
  for _, m in ipairs(A.METHODS) do
    if m.product == item then
      if not usable then return m end
      local args, changed = {}, false
      for i = 1, #m.args do
        local a = m.args[i]
        if type(a) == "string" and MACHINE_SET[a] then
          local sp = M.spec(a)
          local best = A.pick_machine(sp and sp.categories, usable)
          if best and best ~= a and (M.spec(best).speed or 0) > (sp.speed or 0) then a, changed = best, true end
        end
        args[i] = a
      end
      if not changed then return m end
      local m2 = {}
      for k, v in pairs(m) do m2[k] = v end
      m2.args = args
      -- une machine plus rapide qui ne passe pas le contrôle du gabarit (bras introuvables…) cède à la machine écrite
      if not A.template(m2.gen, m2.args) then return m end
      return m2
    end
  end
  local rname = type(book) == "table" and book.recipe_for and book:recipe_for(item) or nil
  if not rname then
    local other = recipe_index(book)[item]
    if other then
      local r = book.recipes[other]
      return nil, "limite : recette " .. other .. " hors de la main (" .. tostring(r and r.category) .. ")"
    end
    return nil, "limite : objet brut (extraction seule)"
  end
  local r = book.recipes[rname]
  local solid, n_in = true, 0
  for _, i in ipairs(r.ingredients or {}) do
    n_in = n_in + 1
    if i.type == "fluid" then solid = false end
  end
  if not solid then return nil, "limite : " .. rname .. " demande un fluide" end
  if n_in < 1 or n_in > 2 then return nil, "limite : " .. rname .. " a " .. n_in .. " ingredients (rangee : 1 ou 2)" end
  if #(r.products or {}) ~= 1 then return nil, "limite : " .. rname .. " a plusieurs produits" end
  local machine = A.pick_machine({ r.category }, usable)
  if not machine then return nil, "limite : aucune machine pour la categorie " .. tostring(r.category) end
  local def = { name = rname, category = r.category, energy = r.energy, ingredients = r.ingredients, products = r.products }
  local meth = { product = item, gen = "simple", args = { def, 1, machine }, feed = true, generic = true }
  -- lot PLANDIR (T1) : la meilleure machine refusée par le gabarit cède à la première de la liste
  local first = A.pick_machine({ r.category }, nil)
  if machine ~= first and not A.template(meth.gen, meth.args) then meth.args = { def, 1, first } end
  return meth
end

--- Entrées d'un objet dans le graphe : celles du gabarit de sa méthode (ce que le module reçoit du dehors : les
--- engrenages des packs rouges se font DANS le module), sinon les ingrédients de sa recette (toutes catégories). Triées.
local function inputs_of(item, book, meth)
  local t = {}
  if meth then
    local base = A.template(meth.gen, meth.args)
    if base then
      for _, k in ipairs(sorted_keys(base.inputs)) do if k ~= "electricity-kw" then t[#t + 1] = k end end
      return t
    end
  end
  local rname = recipe_index(book)[item]
  local r = rname and book.recipes[rname]
  if not r then return t end
  local seen = {}
  for _, i in ipairs(r.ingredients or {}) do
    if i.name and not seen[i.name] then seen[i.name] = true; t[#t + 1] = i.name end
  end
  table.sort(t)
  return t
end
A.inputs_of = inputs_of

--- Profondeur d'un objet dans le graphe des recettes : 0 pour un objet brut, 1 + la plus grande profondeur de ses entrées
--- sinon (fer : 1 ; engrenages, circuits, chargeurs, packs rouges : 2 ; packs verts : 3). memo et meth_of facultatifs.
function A.depth(item, book, memo, meth_of)
  memo = memo or {}
  meth_of = meth_of or function(i) return (A.method_for(i, book)) end
  local d = memo[item]
  if d ~= nil then return d end
  memo[item] = 0 -- garde contre un cycle de recettes
  local best = 0
  for _, i in ipairs(A.inputs_of(item, book, meth_of(item))) do
    local di = A.depth(i, book, memo, meth_of) + 1
    if di > best then best = di end
  end
  memo[item] = best
  return best
end

---------------------------------------------------------------------------------------------------
-- Décision
---------------------------------------------------------------------------------------------------
local OPEN = { attente = true, plan = true, reserve = true, defrichage = true, fantomes = true, chantier = true,
  raccordement = true, bloque = true, demande = true }
A.OPEN_STATES = OPEN

--- La décision d'une pensée. input = {
---   window, threatened, mods = { { product, state, reason, sig, finished_m } } (demandes de l'équipe, dans l'ordre),
---   obtainable(item) -> bool (fabricable à la main OU au stock), book, stock, dist, has_plant, sig (contexte),
---   no_power (raison du refus de la centrale, ou nil), hold (raison d'un repli : aucune demande, ou nil), items (facultatif : objets à peser en plus, par exemple les
---   étapes « produce » du dépliage d'IA-G) }.
--- Rend { requests = { { product, gen, args, rate, rate_nom, feed, why, items, electric, gain } }, verdicts = { { product,
--- verdict, why, L, D, T, C, G, depth, generic } } (ordre de la pesée : profondeur, charge, nom), wanted = { [objet] = true } }.
--- Verdicts : demande, en_cours, ordre (une entrée d'abord), recherche (objet impossible), attente (fenêtre ou place),
--- non (charge, retour, gain, centrale, gabarit), refuse (plan directeur, même signature), fini, limite (pas de méthode).
function A.decide(input)
  local window = input.window or {}
  local H = input.threatened and A.H_THREAT or A.H_SAFE
  local margin = input.threatened and A.MARGIN_THREAT or A.MARGIN_SAFE
  local mods = {}
  local open = 0
  for _, m in ipairs(input.mods or {}) do
    mods[m.product] = mods[m.product] or { open = 0, fini = 0, refused = nil }
    local r = mods[m.product]
    if OPEN[m.state] then
      r.open = r.open + 1
      open = open + 1
    elseif m.state == "fini" then
      r.fini = r.fini + 1
      if m.finished_m and (not r.last_m or m.finished_m > r.last_m) then r.last_m = m.finished_m end
    elseif m.state == "refuse" then
      r.refused = m
    end
  end
  -- Prix des plaques (PNJ-s par plaque) mesurés sur la fenêtre.
  local price = {}
  for _, meth in ipairs(A.METHODS) do
    if meth.ore then
      local L, D = A.measure(window, meth.product)
      if D > 0 and L > 0 then price[meth.product] = L * 60 / D end
    end
  end
  -- Produits de la fonderie du QG (acier) : au prix de leurs plaques d'entrée (données de shared/team/config.lua).
  for _, p in ipairs(sorted_keys(T.smelter_inputs)) do
    local input = T.smelter_inputs[p]
    if not price[p] and price[input[1]] then price[p] = input[2] * price[input[1]] end
  end
  local out = { requests = {}, verdicts = {}, wanted = {} }
  -- Lot C2 : seuil du tapis par le coût réel (réglage maître allumé seulement), et demande de la capitalisation (débit voulu par objet).
  local belt = A.BELT_FLOW
  if input.demande then
    belt = A.belt_flow({ book = input.book, stock = input.stock, dist = input.dist, price = price }, H) or A.BELT_FLOW
    out.belt_flow = belt
  end
  out.demande = {}
  -- Objets pesés : produits des gabarits écrits, objets demandés par l'appelant, objets qui ont coûté de la charge à la
  -- main dans la fenêtre (n'importe lequel : consigne du DC du 27/10).
  local book = input.book
  local cands, seen = {}, {}
  local function cand(item) if item and not seen[item] then seen[item] = true; cands[#cands + 1] = item end end
  for _, m in ipairs(A.METHODS) do cand(m.product) end
  for _, it in ipairs(input.items or {}) do cand(it) end
  local loaded = {}
  for i = math.max(1, #window - A.WINDOW + 1), #window do
    for k, x in pairs(window[i].load or {}) do if x > 0 then loaded[k] = true end end
  end
  for _, k in ipairs(sorted_keys(loaded)) do cand(k) end
  local meths, whys = {}, {}
  local function meth_of(item)
    if meths[item] == nil then
      local m, why = A.method_for(item, book, input.obtainable)
      meths[item] = m or false
      whys[item] = why
    end
    return meths[item] or nil
  end
  local memo = {}
  local order = {}
  for _, item in ipairs(cands) do
    local st = mods[item] or { open = 0, fini = 0 }
    local L, D, _, n = A.measure(window, item, st.last_m)
    -- Lot C2 : la décision porte sur le débit VOULU (la charge à la main au débit que la capitalisation vise), non sur la charge d'aujourd'hui.
    local L0, D0 = L, D
    local scaled
    L, D, scaled = Dm.load(L, D, input.wanted and input.wanted[item])
    if scaled then out.demande[#out.demande + 1] = { item = item, L0 = L0, L = L, D0 = D0, D = D } end
    order[#order + 1] = { item = item, depth = A.depth(item, book, memo, meth_of), L = L, D = D, n = n, scaled = scaled and true or nil,
      inputs = A.inputs_of(item, book, meth_of(item)) }
  end
  table.sort(order, function(a, b)
    if a.depth ~= b.depth then return a.depth < b.depth end
    if a.L ~= b.L then return a.L > b.L end
    return a.item < b.item
  end)
  local busy = {} -- objets en route vers l'automatisation : leurs consommateurs attendent (point 8)
  for _, c in ipairs(order) do
    local meth = meth_of(c.item)
    local st = mods[c.item] or { open = 0, fini = 0 }
    local L, D, n = c.L, c.D, c.n
    local v = { product = c.item, L = L, D = D, depth = c.depth, generic = meth and meth.generic or nil }
    local first_busy = nil
    for _, i in ipairs(c.inputs) do if busy[i] and not first_busy then first_busy = i end end
    if first_busy then
      v.verdict, v.why = "ordre", "entree " .. first_busy .. " d'abord"
      busy[c.item] = true
    elseif st.open > 0 then
      v.verdict, v.why = "en_cours", "module ouvert"
      busy[c.item] = true
    elseif st.refused and st.refused.sig == input.sig then
      -- refus « gisement » (fonderie sans lot assez près de son minerai) : limite écrite, pas de module posé
      local why = tostring(st.refused.reason)
      v.verdict, v.why = why:find("^gisement") and "limite" or "refuse", why
    elseif st.fini >= A.MAX_PER_PRODUCT then
      v.verdict, v.why = "fini", st.fini .. " module(s)"
    elseif n < A.RESEARCH_WINDOW then
      v.verdict, v.why = "attente", "fenetre " .. n .. "/" .. A.WINDOW .. " min"
    elseif L <= A.LOAD_MIN then
      v.verdict, v.why = "non", string.format("charge %.2f PNJ <= %.2f", L, A.LOAD_MIN) .. (c.scaled and (" (au debit voulu " .. string.format("%.1f", D) .. "/min)") or "")
    elseif not meth then
      v.verdict, v.why = "limite", tostring(whys[c.item])
    else
      local rate = math.max(1, D) * (100 + margin) / 100
      if st.fini == 0 and rate > A.FIRST_RATE_MAX then rate = A.FIRST_RATE_MAX end
      local g, args = A.sized(meth, rate, input.pole, input.arms)
      -- Fonderie : la voie de minerai n'est servie par foreuses et tapis qu'au-delà de A.BELT_FLOW (P.AUTO_FLOW) ; en
      -- dessous, c'est un quai que les porteurs remplissent DEPUIS LE COFFRE, où il n'y a pas de minerai (les avant-postes
      -- livrent des plaques) : moteur réel, e6-usine, emerald, seconde fonderie de fer à quai de minerai vide 30 min. La
      -- plus petite taille servie par tapis, donc.
      local function belt_ok(gg) return not meth.ore or (gg.inputs[meth.ore] or 0) >= belt - 1e-9 end
      if g and g.ext and not belt_ok(g) then
        for n = args[g.ext.arg] + 1, g.ext.max do
          local a2 = {}
          for i = 1, #args do a2[i] = args[i] end
          a2[g.ext.arg] = n
          local g2 = A.template(meth.gen, a2, input.pole, input.arms)
          if g2 and belt_ok(g2) then g, args = g2, a2 break end
        end
      end
      local function missing_of(gg)
        local _, its = A.cost(meth, gg, { has_plant = true, belt_flow = belt })
        local miss = {}
        for _, name in ipairs(sorted_keys(its)) do
          if not (input.obtainable and input.obtainable(name)) then miss[#miss + 1] = name end
        end
        return miss
      end
      -- La plus grande taille que l'équipe sait FABRIQUER (une taille plus petite peut se passer d'un objet impossible, le
      -- bras rapide d'un quai de sortie) ; l'objet impossible ne fait rechercher que si même la plus petite le demande.
      if g and g.ext and #missing_of(g) > 0 then
        local cur = args[g.ext.arg]
        for n = cur - 1, 1, -1 do
          local a2 = {}
          for i = 1, #args do a2[i] = args[i] end
          a2[g.ext.arg] = n
          local g2 = A.template(meth.gen, a2, input.pole, input.arms)
          if g2 and belt_ok(g2) and #missing_of(g2) == 0 then g, args = g2, a2 break end
        end
      end
      if not g then
        v.verdict, v.why = "non", "gabarit : " .. tostring(args)
      else
        local rate_nom = (g.nominal[c.item] or 0) * 60
        local C, items, n_ent, det = A.cost(meth, g, { book = input.book, stock = input.stock, dist = input.dist,
          price = price, has_plant = input.has_plant, belt_flow = belt })
        local electric = (g.power_kw or 0) > 0
        local missing = {}
        for _, name in ipairs(sorted_keys(items)) do
          if not (input.obtainable and input.obtainable(name)) then missing[#missing + 1] = name end
        end
        local share = D > 0 and math.min(1, rate_nom / D) or 1
        local G = L * share - A.residual(det, rate_nom, input.dist)
        v.C, v.G, v.n_ent, v.rate_nom = C, G, n_ent, rate_nom
        if electric and input.no_power then
          -- La centrale du plan directeur est refusée (pas de rive, pas de rue vers le réseau) : un module électrique ne
          -- produirait rien (moteur réel, e2-usine : 5 modules bâtis sans courant chez emerald). Coût infini tant que la
          -- raison ne change pas (signature du refus de la centrale).
          v.verdict, v.why = "non", "pas de centrale : " .. tostring(input.no_power)
        elseif G <= 0 then
          v.verdict, v.why = "non", string.format("gain %.2f PNJ <= 0 (logistique du module %.2f)", G, L * share - G)
        else
          local T = C / (60 * G)
          v.T = T
          if T > H then
            v.verdict, v.why = "non", string.format("retour %.1f min > %d", T, H)
          elseif #missing > 0 then
            v.verdict, v.why = "recherche", "objets impossibles : " .. table.concat(missing, ",")
            for _, name in ipairs(missing) do out.wanted[name] = true end
            busy[c.item] = true
          elseif n < A.WINDOW then
            -- Demi-fenêtre : assez pour lancer la recherche d'un objet impossible, pas pour demander le module (H3 :
            -- « pendant 10 min »).
            v.verdict, v.why = "attente", "fenetre " .. n .. "/" .. A.WINDOW .. " min"
          elseif open >= A.MAX_OPEN then
            v.verdict, v.why = "attente", "un module deja ouvert"
            busy[c.item] = true
          elseif input.hold then
            -- repli de l'équipe après des réserves affamées (le runtime en donne la raison)
            v.verdict, v.why = "attente", tostring(input.hold)
            busy[c.item] = true
          else
            v.verdict, v.why = "demande", string.format("charge %.2f PNJ, retour %.1f min <= %d", L, T, H)
            out.requests[#out.requests + 1] = { product = c.item, gen = meth.gen, args = args, rate = rate,
              rate_nom = rate_nom, feed = meth.feed, why = v.why, items = items, electric = electric, gain = G,
              pole = g.pole, arms = g.arms }
            open = open + 1
            busy[c.item] = true
          end
        end
      end
    end
    out.verdicts[#out.verdicts + 1] = v
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Projet du cerveau (IA3-c) : un module demandé est un PROJET compté dans les K projets ouverts
---------------------------------------------------------------------------------------------------
local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

--- Objets qu'une recherche ouverte consomme (ses packs restants) : un module qui en produit SERT la recherche.
--- research = s.research du cerveau ({ tech, packs = { { objet, n } }, for_auto }) ou nil.
function A.serves_research(research, product)
  if not research then return false end
  for _, it in ipairs(research.packs or {}) do
    if (it[1] or it.name) == product then return true end
  end
  return false
end

--- Buts « module » des demandes ouvertes (auto = { mods = { { product, state, missing, reason } } }), ajoutés à la
--- liste des buts de la pensée (shared/ai3/cerveau.lua). Valeur : A.VALUE × poids « capital » du chef.
--- research (facultatif) : la recherche ouverte ; un module qui ne la sert pas passe APRÈS elle (valeur plafonnée sous
--- celle du but « recherche ») : il ne prend ni les matières ni les bras dont elle a besoin (moteur réel, e6 à e10-usine,
--- critère K1 : palier 3 de 18,7 à 43,8 min ou jamais atteint, réserves de chantier servies avant les packs). Une
--- recherche voulue par l'automatisation elle-même (for_auto : poteau moyen) ne plafonne rien.
function A.goals(goals, auto, weights, research)
  if not auto then return goals end
  local rvalue = nil
  for _, g in ipairs(goals) do
    if g.key == "recherche" and not (research and research.for_auto) then rvalue = g.value end
  end
  local function capped(v, product)
    if rvalue and v >= rvalue and not A.serves_research(research, product) then return math.max(1, rvalue - 1) end
    return v
  end
  -- Le caractère peut AVANCER l'automatisation (capitalisation), pas la retarder sous le neutre : un conquérant construit
  -- aussi son usine (moteur réel, e4-usine : scarlet, conquérant, poids « capital » sous 1 000, fonderie servie après la
  -- recherche, l'armée et les munitions, réserve « materiaux » de 26 à 90 min).
  local w = math.max(1000, (weights or {}).capital or 1000)
  local seen = {}
  -- Lot FUITES-PILE (fuite b) : un module EN RECONSTRUCTION (m.pile == "reparer", posé par script/ai3/automatisation.lua) passe avant un
  -- module neuf du même produit (un seul but par produit : ses manques sont ceux des pièces à refaire) ; g.pile porte la famille de la
  -- pile (reparer, capital, capi, invest, migration ; nil : centrale et autres projets d'infrastructure, jamais suspendus) que la
  -- pensée lit pour suspendre les modules NEUFS pendant une retenue (shared/ai3/cerveau.lua).
  local ordered = {}
  for _, m in ipairs(auto.mods or {}) do if m.pile == "reparer" then ordered[#ordered + 1] = m end end
  for _, m in ipairs(auto.mods or {}) do if m.pile ~= "reparer" then ordered[#ordered + 1] = m end end
  for _, m in ipairs(ordered) do
    if OPEN[m.state] and not seen[m.product] then
      seen[m.product] = true
      local base = math.min(A.VALUE_MAX, A.VALUE + math.floor(A.VALUE_PER_PNJ * math.max(0, m.gain or 0)))
      goals[#goals + 1] = { key = "auto:" .. m.product, family = "capital", kind = "module", product = m.product,
        status = m.state, missing = m.missing, reason = m.reason, pile = m.pile, item = m.item, -- (lot CHAMP : plaque d'une bande du champ)
        pids = m.id and { m.id } or nil, -- lot KITS-VOLES : le projet du plan directeur du module (les kits du but lui sont remis, P.want_kit)
        -- lot RACCORD-BANDE 2 : la LIGNE de poteaux d'une bande (famille « couverture ») est un investissement de fond : elle ne prend pas de place parmi les K
        -- projets (partie neuve 0.6.72 : « auto:ligne-bande:attente » 12 min sur 20, 104 poteaux manquants de 8 à 38 min avec 470 de bois et 330 de cuivre au coffre)
        fond = m.line or nil, invest = m.line or nil, -- (m.line : posé par script/ai3/automatisation.lua pour une ligne de bande)
        value = capped(clamp(math.floor(base * w / 1000), 1, 100), m.product) }
    end
  end
  -- Un module FINI se nourrit depuis le coffre du QG (quais d'entrée remplis par les porteurs, plan directeur) : ce qui
  -- manque au coffre pour ses quais (circuits des packs verts, plaques) est un but « alimenter », de la valeur du module
  -- (moteur réel, e7-usine : packs verts finis, quai de circuits vide, 0 pack ; personne ne fabriquait de circuits pour
  -- lui). Ses manques deviennent des sous-buts (fabriquer, fondre) comme ceux d'un chantier ; la charge à la main des
  -- objets qu'il mange se mesure alors, et leur propre module vient en son temps (ordre du graphe).
  local fed = {}
  for _, fd in ipairs(auto.feeds or {}) do
    if not fed[fd.product] and fd.items and #fd.items > 0 then
      fed[fd.product] = true
      local base = math.min(A.VALUE_MAX, A.VALUE + math.floor(A.VALUE_PER_PNJ * math.max(0, fd.gain or 0)))
      -- (relecture FUITES-PILE : g.grow, pièces d'un agrandissement, lu par Pi.improving ; jamais suspendu ici, g.pile reste nil)
      goals[#goals + 1] = { key = "alim:" .. fd.product, family = "capital", kind = "module", product = fd.product,
        status = "reserve", missing = fd.items, grow = fd.grow, pids = fd.id and { fd.id } or nil, value = capped(clamp(math.floor(base * w / 1000), 1, 100), fd.product) }
    end
  end
  table.sort(goals, function(a, b)
    if a.value ~= b.value then return a.value > b.value end
    return a.key < b.key
  end)
  return goals
end

--- Émission d'un projet « module » (shared/ai3/projets.lua, EMIT.module) : les objets qui MANQUENT au chantier
--- (Build.status.missing) deviennent des sous-buts (fabriquer à la main, fondre, miner) ; un chantier bloqué est un
--- projet bloqué (il ne prend pas de place) ; sinon le projet est en cours (ses tâches de chantier sont posées au
--- tableau par le plan directeur lui-même).
function A.emit(P)
  return function(E, proj, g)
    local state = g.status
    if state == "bloque" then return "bloque", "module:" .. tostring(g.reason or "?") end
    -- Lot INTEG-RECONSTRUCTION (D6) : un projet ROUVERT garde ses manques aussi en fantômes / chantier (refresh_missing de build.lua les relit)
    if (state == "reserve" or state == "defrichage" or state == "fantomes" or state == "chantier") and g.missing and #g.missing > 0 then
      P.want_kit(E, proj, g.missing, proj.prio, "module") -- lot POSE-PAR-LOTS : le manque fabricable du chantier en KITS
      return "matiere"
    end
    return "en_cours"
  end
end

return A
