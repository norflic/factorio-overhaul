--[[
  Gabarits de modules des équipes de PNJ (lot IA1-c, docs/EQUIPES_PNJ.md §6.4, §6.6, §6.8). Lua PUR : aucune API
  du jeu ; lu hors jeu (tests/ia1_modules_test.lua) et en moteur réel (scénario greffé `ia1-modules`).

  Un GABARIT est une petite usine éprouvée, posée d'un bloc par les PNJ (Q-IA1-4, défaut retenu par le DC le 24/10) :
    - entités relatives (nom, centre x/y en tuiles depuis le coin nord-ouest de l'emprise, direction, recette,
      cadence prévue en fabrications par seconde) ;
    - emprise w × h (24 × 24 au plus) ;
    - PORTS au bord : tapis (entrée ou sortie, contenu de chaque voie), tuyau (fluide), quai (coffre), four ou
      foreuse « à collecter » et « à ravitailler » (avant-postes à combustible, servis par les porteurs) ;
    - POINTS D'APPUI dans la rue (d'où un PNJ construit à 16 tuiles au plus, O.SCRIPT_BUILD_DISTANCE) ;
    - débit nominal (calculé ici, jamais écrit à la main), puissance, époque (calculée sur X0) et recettes à
      débloquer, extensions (paramètre que le générateur sait augmenter).
  Les gabarits sont PRODUITS par un générateur paramétrique (colonnes de fours, lignes de foreuses, rangées
  d'assembleurs, centrale à vapeur, chevalets, raffinerie, chimie) ; les blocs composés (circuits, packs, moteurs,
  pétrole sur place) assemblent ces pièces. Rotations par matrices entières (quarts de tour).

  CONTRÔLE (M.check) : emprise, alignement sur la grille, chevauchements (emprises ACTUELLES des bâtiments à niveaux,
  shared/levels/config.lua L.footprints), ports au bord et ouverts vers l'extérieur, tapis (sens, virages,
  chargement latéral, contenu de chaque voie, voies mêlées refusées), bras (cible de prise et de dépôt, objets
  utiles), débits par flot maximal objet par objet (capacité des bras sans bonus de recherche, des tapis, des
  liaisons), réseaux de fluides (raccords réciproques, tuyaux souterrains, un seul fluide par réseau, offre ≥
  demande, longueur des conduites : R8), alimentation (aire des poteaux, portée des fils), points d'appui, débit
  nominal et puissance recalculés.

  Conventions : directions 1.1 (nord 0, est 2, sud 4, ouest 6) ; un bras « dirigé vers le nord » PREND au nord et
  DÉPOSE au sud (prototype : pickup (0, −1), insert (0, 1,2)) ; un tapis va dans sa direction ; voie 1 = gauche,
  voie 2 = droite (sens de la marche, comme defines.transport_line). Les chiffres des bras (objets par seconde,
  pile de 1, coffre à coffre) sont ceux du wiki 1.1 ; un bras qui prend sur un tapis compte 85 % ; toute liaison
  garde 10 % de marge. Ce sont des ESTIMATIONS : le banc `ia1-modules` mesure le débit réel de chaque gabarit.

  Déterminisme : listes et tris seulement ; les tables de recherche indexées ne sont jamais parcourues par
  `pairs` sans tri ; aucune trigonométrie ; aucune fonction dans un gabarit (sérialisable dans global).
]]

local function need(dotted, slashed)
  local ok, res = pcall(require, dotted)
  if ok and type(res) == "table" then return res end
  return require("__factorio-overhaul__/" .. slashed)
end

local L = need("shared.levels.config", "shared/levels/config")
local Points = need("shared.levels.points", "shared/levels/points")
local X = need("shared.content.epochs", "shared/content/epochs")

local M = {}

M.MAX_SIDE = 24                -- emprise maximale (EQUIPES_PNJ §6.4 ; lot de 24 × 24, §6.5)
M.STREET = 4                   -- largeur de la rue autour d'un lot (§6.5)
M.BUILD_DISTANCE = 16          -- O.SCRIPT_BUILD_DISTANCE (shared/team/org.lua), recopié : modules ne lit pas org
M.MARGIN = 0.9                 -- toute liaison garde 10 % de marge
M.BELT_PICKUP = 0.85           -- un bras qui prend sur un tapis
M.LANE_RATE = 7.5              -- tapis jaune : 7,5 objets/s par voie
M.BELT_RATE = 15
M.COAL_J = 4000                -- kJ d'un charbon (4 MJ)
M.EPS = 1e-9

M.N, M.E, M.S, M.W = 0, 2, 4, 6
local N, E, S, W = 0, 2, 4, 6
local DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }

--- Rotation d'un vecteur du nord vers la direction d (matrices entières).
function M.rot(d, x, y)
  if d == 0 then return x, y end
  if d == 2 then return -y, x end
  if d == 4 then return -x, -y end
  if d == 6 then return y, -x end
  error("direction invalide : " .. tostring(d))
end
local rot = M.rot

local function opposite(d) return (d + 4) % 8 end
local function left_of(d) local v = DV[d]; return v[2], -v[1] end

---------------------------------------------------------------------------------------------------
-- 1. Entités connues (prototypes vanilla 1.1.91, relus dans data/base ; puissance en kW, ponction comprise)
---------------------------------------------------------------------------------------------------
local BASE = {
  ["transport-belt"] = { kind = "belt", w = 1, h = 1 },
  ["burner-inserter"] = { kind = "inserter", w = 1, h = 1, rate = 0.59, reach = 1, burner = true },
  ["inserter"] = { kind = "inserter", w = 1, h = 1, rate = 0.83, reach = 1, power = 13.6 },
  ["fast-inserter"] = { kind = "inserter", w = 1, h = 1, rate = 2.31, reach = 1, power = 47.2 },
  ["long-handed-inserter"] = { kind = "inserter", w = 1, h = 1, rate = 1.15, reach = 2, power = 20.4 },
  ["small-electric-pole"] = { kind = "pole", w = 1, h = 1, supply = 2.5, wire = 7.5 },
  ["medium-electric-pole"] = { kind = "pole", w = 1, h = 1, supply = 3.5, wire = 9 },
  ["wooden-chest"] = { kind = "chest", w = 1, h = 1, slots = 16 },
  ["iron-chest"] = { kind = "chest", w = 1, h = 1, slots = 32 },
  ["steel-chest"] = { kind = "chest", w = 1, h = 1, slots = 48 },
  ["pipe"] = { kind = "pipe", w = 1, h = 1 },
  ["pipe-to-ground"] = { kind = "ptg", w = 1, h = 1, max = 10 },
  ["stone-furnace"] = { kind = "furnace", w = 2, h = 2, speed = 1, burner_kw = 90 },
  ["steel-furnace"] = { kind = "furnace", w = 2, h = 2, speed = 2, burner_kw = 90 },
  ["assembling-machine-1"] = { kind = "assembler", w = 3, h = 3, speed = 0.5, usage_kw = 75, drain = true,
    categories = { "crafting", "basic-crafting", "advanced-crafting" } },
  ["assembling-machine-2"] = { kind = "assembler", w = 3, h = 3, speed = 0.75, usage_kw = 150, drain = true,
    categories = { "crafting", "basic-crafting", "advanced-crafting", "crafting-with-fluid" } },
  ["oil-refinery"] = { kind = "assembler", w = 5, h = 5, speed = 1, usage_kw = 420, drain = true, categories = { "oil-processing" },
    boxes = { { io = "in", pts = { { -1, 3 } } }, { io = "in", pts = { { 1, 3 } } },
      { io = "out", pts = { { -2, -3 } } }, { io = "out", pts = { { 0, -3 } } }, { io = "out", pts = { { 2, -3 } } } } },
  ["chemical-plant"] = { kind = "assembler", w = 3, h = 3, speed = 1, usage_kw = 210, drain = true, categories = { "chemistry" },
    boxes = { { io = "in", pts = { { -1, -2 } } }, { io = "in", pts = { { 1, -2 } } },
      { io = "out", pts = { { -1, 2 } } }, { io = "out", pts = { { 1, 2 } } } } },
  ["lab"] = { kind = "lab", w = 3, h = 3, speed = 1, usage_kw = 60, drain = true },
  ["electric-mining-drill"] = { kind = "drill", w = 3, h = 3, speed = 0.5, usage_kw = 90, radius = 2.49, drop = { 0, -1.85 } },
  ["burner-mining-drill"] = { kind = "drill", w = 2, h = 2, speed = 0.25, burner_kw = 150, radius = 0.99, drop = { -0.5, -1.3 } },
  -- Chevalet : sortie EXPLICITE par direction (prototype : positions = N, E, S, O), pas une rotation de la sortie
  -- nord : un gabarit qui en contient ne se tourne pas (no_rotate).
  ["pumpjack"] = { kind = "pumpjack", w = 3, h = 3, usage_kw = 90, rate = 10,
    outs = { [0] = { 1, -2 }, [2] = { 2, -1 }, [4] = { -1, 2 }, [6] = { -2, 1 } } },
  ["boiler"] = { kind = "boiler", w = 3, h = 2, burner_kw = 1800, water = 60,
    boxes = { { io = "io", fluid = "water", pts = { { -2, 0.5 }, { 2, 0.5 } } }, { io = "out", fluid = "steam", pts = { { 0, -1.5 } } } } },
  ["steam-engine"] = { kind = "generator", w = 3, h = 5, power_out = 900, steam = 30,
    boxes = { { io = "io", fluid = "steam", pts = { { 0, 3 }, { 0, -3 } } } } },
  -- Pompe de rive : le modèle ne compte que sa tuile sur la terre ; elle déborde d'une tuile sur l'eau, HORS de
  -- l'emprise (port « rive »). Les tuiles voisines sont réservées (boîte de collision de 1,2 de large).
  ["offshore-pump"] = { kind = "offshore", w = 1, h = 1, rate = 1200,
    boxes = { { io = "out", fluid = "water", pts = { { 0, 1 } } } } },
}
M.BASE = BASE

-- Familles de bâtiments à niveaux (shared/levels/config.lua) dont le niveau 1 est dans BASE.
local LEVEL_CACHE = {}

local function copy(t)
  if type(t) ~= "table" then return t end
  local o = {}
  for k, v in pairs(t) do o[k] = copy(v) end
  return o
end

--- Caractéristiques d'une entité (nom vanilla ou niveau fo-lvl-<famille>-<n>), ou nil. Pour un niveau : emprise
--- L.footprint, vitesse et puissance par L.apply_stat, points de jeu déplacés comme à l'étape data (Points).
function M.spec(name)
  local s = BASE[name]
  if s then return s end
  if LEVEL_CACHE[name] then return LEVEL_CACHE[name] end
  local fam, n = L.parse(name)
  if not fam then return nil end
  local b = BASE[fam.base]
  if not b then return nil end
  local side = L.footprint(fam, n)
  local o = copy(b)
  o.level, o.family, o.base = n, fam.key, fam.base
  o.w, o.h = side, side
  for _, st in ipairs(fam.stats) do
    local key = st.path[#st.path]
    if (key == "crafting_speed" or key == "mining_speed") and o.speed then o.speed = L.apply_stat(st, b.speed, n) end
    if key == "energy_usage" then
      if o.usage_kw then o.usage_kw = L.apply_stat(st, b.usage_kw, n) end
      if o.burner_kw then o.burner_kw = L.apply_stat(st, b.burner_kw, n) end
    end
  end
  if b.drop then
    local p = Points.move_point({ b.drop[1], b.drop[2] }, b.w, side)
    o.drop = { p[1], p[2] }
  end
  if b.radius then o.radius = b.radius + (side - b.w) / 2 end
  if b.boxes then
    for _, box in ipairs(o.boxes) do
      for i, p in ipairs(box.pts) do
        local q = Points.move_point({ p[1], p[2] }, b.w, side)
        box.pts[i] = { q[1], q[2] }
      end
    end
  end
  LEVEL_CACHE[name] = o
  return o
end

--- Puissance électrique maximale (kW) d'une entité, ponction comprise (1/30 de la consommation pour les machines).
function M.power_kw(name)
  local s = M.spec(name)
  if not s then return 0 end
  if s.power then return s.power end
  if s.usage_kw then return s.drain and s.usage_kw * 31 / 30 or s.usage_kw end
  return 0
end

---------------------------------------------------------------------------------------------------
-- 2. Recettes utilisées (data/base 1.1.91 ; recoupées par tests/ia1_modules_test.lua avec tests/fixtures/recipes.lua).
--    `box` : fluidbox_index de la recette (sinon dans l'ordre des fluides).
---------------------------------------------------------------------------------------------------
local R = {}
local function recipe(name, cat, time, ins, outs) R[name] = { name = name, category = cat, time = time, ingredients = ins, products = outs } end
local function I(n, a) return { name = n, amount = a } end
local function F(n, a, box) return { name = n, amount = a, fluid = true, box = box } end
recipe("iron-plate", "smelting", 3.2, { I("iron-ore", 1) }, { I("iron-plate", 1) })
recipe("copper-plate", "smelting", 3.2, { I("copper-ore", 1) }, { I("copper-plate", 1) })
recipe("iron-gear-wheel", "crafting", 0.5, { I("iron-plate", 2) }, { I("iron-gear-wheel", 1) })
recipe("copper-cable", "crafting", 0.5, { I("copper-plate", 1) }, { I("copper-cable", 2) })
recipe("electronic-circuit", "crafting", 0.5, { I("iron-plate", 1), I("copper-cable", 3) }, { I("electronic-circuit", 1) })
recipe("automation-science-pack", "crafting", 5, { I("copper-plate", 1), I("iron-gear-wheel", 1) }, { I("automation-science-pack", 1) })
recipe("inserter", "crafting", 0.5, { I("electronic-circuit", 1), I("iron-gear-wheel", 1), I("iron-plate", 1) }, { I("inserter", 1) })
recipe("transport-belt", "crafting", 0.5, { I("iron-plate", 1), I("iron-gear-wheel", 1) }, { I("transport-belt", 2) })
recipe("logistic-science-pack", "crafting", 6, { I("inserter", 1), I("transport-belt", 1) }, { I("logistic-science-pack", 1) })
recipe("pipe", "crafting", 0.5, { I("iron-plate", 1) }, { I("pipe", 1) })
recipe("engine-unit", "advanced-crafting", 10, { I("steel-plate", 1), I("iron-gear-wheel", 1), I("pipe", 2) }, { I("engine-unit", 1) })
recipe("basic-oil-processing", "oil-processing", 5, { F("crude-oil", 100, 2) }, { F("petroleum-gas", 45, 3) })
recipe("plastic-bar", "chemistry", 1, { F("petroleum-gas", 20), I("coal", 1) }, { I("plastic-bar", 2) })
recipe("sulfur", "chemistry", 1, { F("water", 30), F("petroleum-gas", 30) }, { I("sulfur", 2) })
recipe("advanced-circuit", "crafting", 6, { I("electronic-circuit", 2), I("plastic-bar", 2), I("copper-cable", 4) }, { I("advanced-circuit", 1) })
M.RECIPES = R

--- Minerais extraits par les foreuses (temps d'extraction vanilla : 1 s).
M.ORES = { ["iron-ore"] = 1, ["copper-ore"] = 1, ["coal"] = 1, ["stone"] = 1 }
M.PLATE_OF = { ["iron-ore"] = "iron-plate", ["copper-ore"] = "copper-plate" }

local function recipe_names_sorted()
  local t = {}
  for k in pairs(R) do t[#t + 1] = k end
  table.sort(t)
  return t
end
M.recipe_names = recipe_names_sorted

---------------------------------------------------------------------------------------------------
-- 3. Géométrie
---------------------------------------------------------------------------------------------------
--- Côtés (tuiles) d'une entité tournée.
function M.size(name, dir)
  local s = M.spec(name)
  if dir == E or dir == W then return s.h, s.w end
  return s.w, s.h
end

--- Rectangle (bords en tuiles) d'une entité du gabarit.
local function rect(e)
  local w, h = M.size(e.name, e.dir or N)
  return e.x - w / 2, e.y - h / 2, e.x + w / 2, e.y + h / 2
end
M.rect = rect

local function tkey(tx, ty) return (tx + 4096) * 16384 + (ty + 4096) end
local function tile_of(x, y) return math.floor(x), math.floor(y) end

local function fmt(v)
  if v == math.floor(v) then return string.format("%d", v) end
  return string.format("%.2f", v)
end

---------------------------------------------------------------------------------------------------
-- 4. Constructeur de gabarit
---------------------------------------------------------------------------------------------------
local Builder = {}
Builder.__index = Builder

local function new_builder(key, fr, en)
  return setmetatable({ g = { key = key, name_fr = fr, name_en = en, entities = {}, ports = {}, anchors = {},
    params = {}, extensions = {}, fuel_ports = {}, water = {}, resource = nil, notes = {} } }, Builder)
end

--- Pose `name` dont la tuile nord-ouest est (tx, ty) ; renvoie l'indice. opt : recipe, rate (fabrications/s).
function Builder:put(name, tx, ty, dir, opt)
  dir = dir or N
  assert(M.spec(name), "entité inconnue : " .. tostring(name))
  local w, h = M.size(name, dir)
  local e = { name = name, x = tx + w / 2, y = ty + h / 2, dir = dir }
  if opt then
    e.recipe, e.rate, e.role = opt.recipe, opt.rate, opt.role
    if opt.type then e.type = opt.type end
  end
  local list = self.g.entities
  list[#list + 1] = e
  return #list
end

function Builder:port(p) self.g.ports[#self.g.ports + 1] = p; return #self.g.ports end

function Builder:belt_line(x0, y0, x1, y1, dir)
  local out = {}
  local dx = x1 > x0 and 1 or (x1 < x0 and -1 or 0)
  local dy = y1 > y0 and 1 or (y1 < y0 and -1 or 0)
  local x, y = x0, y0
  while true do
    out[#out + 1] = self:put("transport-belt", x, y, dir)
    if x == x1 and y == y1 then break end
    x, y = x + dx, y + dy
  end
  return out
end

function Builder:pipe_line(x0, y0, x1, y1)
  local out = {}
  local dx = x1 > x0 and 1 or (x1 < x0 and -1 or 0)
  local dy = y1 > y0 and 1 or (y1 < y0 and -1 or 0)
  local x, y = x0, y0
  while true do
    out[#out + 1] = self:put("pipe", x, y, N)
    if x == x1 and y == y1 then break end
    x, y = x + dx, y + dy
  end
  return out
end

--- Tuiles occupées (table de recherche) par les entités posées.
local function occupancy(g)
  local occ = {}
  for i, e in ipairs(g.entities) do
    local x0, y0, x1, y1 = rect(e)
    for tx = math.floor(x0 + 0.01), math.ceil(x1 - 0.01) - 1 do
      for ty = math.floor(y0 + 0.01), math.ceil(y1 - 0.01) - 1 do occ[tkey(tx, ty)] = i end
    end
  end
  return occ
end

--- Choix des bras d'une liaison : le moins d'entités, du plus lent au plus rapide (débit demandé `need`, depuis un
--- tapis ou non). Renvoie nom et nombre.
function M.choose_inserters(need, from_belt, max_count, allow)
  local kinds = allow or { "inserter", "fast-inserter" }
  max_count = max_count or 3
  for count = 1, max_count do
    for _, k in ipairs(kinds) do
      local cap = BASE[k].rate * (from_belt and M.BELT_PICKUP or 1) * M.MARGIN * count
      if cap + M.EPS >= need then return k, count end
    end
  end
  return nil, 0
end

--- Pose automatique des poteaux moyens : couverture gloutonne (candidats dans l'ordre (y, x), le plus de bâtiments
--- électriques non couverts d'abord), puis liaisons pour un seul réseau. `cands` : liste {x, y} de tuiles libres.
function Builder:auto_poles(cands, pole)
  pole = pole or "medium-electric-pole"
  local g = self.g
  local sp = BASE[pole]
  local occ = occupancy(g)
  local free = {}
  for _, c in ipairs(cands) do
    if not occ[tkey(c[1], c[2])] then free[#free + 1] = { c[1], c[2] } end
  end
  table.sort(free, function(a, b) if a[2] ~= b[2] then return a[2] < b[2] end return a[1] < b[1] end)
  local need = {}
  for i, e in ipairs(g.entities) do
    local s = M.spec(e.name)
    if M.power_kw(e.name) > 0 or s.kind == "generator" then need[#need + 1] = i end
  end
  local function covers(px, py, i)
    local x0, y0, x1, y1 = rect(g.entities[i])
    local cx, cy = px + 0.5, py + 0.5
    return math.min(x1, cx + sp.supply) - math.max(x0, cx - sp.supply) > M.EPS
      and math.min(y1, cy + sp.supply) - math.max(y0, cy - sp.supply) > M.EPS
  end
  local covered, chosen, used = {}, {}, {}
  while true do
    local best, best_n = nil, 0
    for ci, c in ipairs(free) do
      if not used[ci] then
        local n = 0
        for _, i in ipairs(need) do if not covered[i] and covers(c[1], c[2], i) then n = n + 1 end end
        if n > best_n then best, best_n = ci, n end
      end
    end
    if not best then break end
    used[best] = true
    chosen[#chosen + 1] = free[best]
    for _, i in ipairs(need) do if covers(free[best][1], free[best][2], i) then covered[i] = true end end
  end
  -- Liaisons : tant qu'il y a plusieurs réseaux, ajouter le candidat qui en relie le plus (puis le premier).
  local function dist(a, b) local dx, dy = a[1] - b[1], a[2] - b[2]; return math.sqrt(dx * dx + dy * dy) end
  local function components(list)
    local comp, n = {}, 0
    for i = 1, #list do
      if not comp[i] then
        n = n + 1
        local stack = { i }
        comp[i] = n
        while #stack > 0 do
          local a = table.remove(stack)
          for j = 1, #list do
            if not comp[j] and dist(list[a], list[j]) <= sp.wire + M.EPS then comp[j] = n; stack[#stack + 1] = j end
          end
        end
      end
    end
    return comp, n
  end
  for _ = 1, 64 do
    local comp, n = components(chosen)
    if n <= 1 then break end
    local best, best_k = nil, 1
    for ci, c in ipairs(free) do
      if not used[ci] then
        local seen, k = {}, 0
        for j, p in ipairs(chosen) do
          if dist(c, p) <= sp.wire + M.EPS and not seen[comp[j]] then seen[comp[j]] = true; k = k + 1 end
        end
        if k > best_k then best, best_k = ci, k end
      end
    end
    if not best then
      -- aucun candidat ne relie deux réseaux : le plus proche du premier réseau vers un autre (pas à pas)
      local bestd
      for ci, c in ipairs(free) do
        if not used[ci] then
          local touch1, d2 = false, math.huge
          for j, p in ipairs(chosen) do
            local d = dist(c, p)
            if comp[j] == 1 and d <= sp.wire + M.EPS then touch1 = true end
            if comp[j] ~= 1 then d2 = math.min(d2, d) end
          end
          if touch1 and (not bestd or d2 < bestd - M.EPS) then best, bestd = ci, d2 end
        end
      end
    end
    if not best then break end
    used[best] = true
    chosen[#chosen + 1] = free[best]
  end
  table.sort(chosen, function(a, b) if a[2] ~= b[2] then return a[2] < b[2] end return a[1] < b[1] end)
  local first
  for _, c in ipairs(chosen) do
    local i = self:put(pole, c[1], c[2], N, { role = "pole" })
    first = first or i
  end
  return first
end

--- Tuiles libres d'un rectangle (bornes incluses), dans l'ordre (y, x).
function Builder:free_tiles(x0, y0, x1, y1)
  local occ = occupancy(self.g)
  local out = {}
  for y = y0, y1 do for x = x0, x1 do if not occ[tkey(x, y)] then out[#out + 1] = { x, y } end end end
  return out
end

--- Points d'appui : milieu de chaque côté et coins, à 2 tuiles de l'emprise (dans la rue de 4).
local function standard_anchors(w, h)
  local a = {}
  local mx, my = w / 2, h / 2
  for _, p in ipairs({ { mx, -2 }, { w + 2, my }, { mx, h + 2 }, { -2, my }, { -2, -2 }, { w + 2, -2 }, { w + 2, h + 2 }, { -2, h + 2 } }) do
    a[#a + 1] = { x = p[1], y = p[2] }
  end
  return a
end

--- Termine le gabarit : emprise (boîte englobante depuis (0, 0)), points d'appui, nominal recalculé.
function Builder:finish(w, h)
  local g = self.g
  local mw, mh = 0, 0
  for _, e in ipairs(g.entities) do
    local _, _, x1, y1 = rect(e)
    mw, mh = math.max(mw, x1), math.max(mh, y1)
  end
  g.w, g.h = w or math.ceil(mw - M.EPS), h or math.ceil(mh - M.EPS)
  if #g.anchors == 0 then g.anchors = standard_anchors(g.w, g.h) end
  local rep = M.analyze(g)
  g.nominal = rep.outputs
  g.inputs = rep.inputs
  g.power_kw = rep.power_kw
  g.epoch = rep.epoch
  g.unlocks = rep.unlocks
  g.electric_out_kw = rep.electric_out_kw
  return g
end

---------------------------------------------------------------------------------------------------
-- 5. Générateurs paramétriques
---------------------------------------------------------------------------------------------------
local G = {}
M.GEN = G

local function ore_label(ore) return (ore == "iron-ore" and "fer") or (ore == "copper-ore" and "cuivre") or (ore == "coal" and "charbon") or "pierre" end
local function ore_label_en(ore) return (ore == "iron-ore" and "iron") or (ore == "copper-ore" and "copper") or (ore == "coal" and "coal") or "stone" end

--- Avant-poste à combustion (époque 1) : n paires foreuse à combustion → four en pierre (la foreuse dépose dans le
--- four). Pas de bras, pas d'électricité : les porteurs ravitaillent en charbon et collectent les plaques.
function G.outpost_burner(ore, n)
  local b = new_builder("avant-poste-" .. ore_label(ore), "Avant-poste à combustion (" .. ore_label(ore) .. ")",
    "Burner outpost (" .. ore_label_en(ore) .. ")")
  local plate = M.PLATE_OF[ore]
  local drill = BASE["burner-mining-drill"]
  for i = 0, n - 1 do
    local f = b:put("stone-furnace", 2 * i, 0, N, { recipe = plate, rate = drill.speed, role = "four" })
    local d = b:put("burner-mining-drill", 2 * i, 2, N, { role = "foreuse" })
    b:port({ kind = "four", io = "out", ent = f, item = plate })
    b.g.fuel_ports[#b.g.fuel_ports + 1] = f
    b.g.fuel_ports[#b.g.fuel_ports + 1] = d
  end
  b.g.resource = ore
  b.g.params = { ore = ore, n = n }
  b.g.extensions = { { param = "n", step = 1, max = 12 } }
  return b:finish()
end

--- Colonne de fours électrique (époque ≥ 3) : tapis central d'entrée (voie gauche : minerai, voie droite : charbon),
--- deux rangées de fours, deux tapis de sortie vers le sud. `furnace` : stone-furnace, steel-furnace ou un niveau.
function G.smelter(furnace, ore, n)
  local plate = M.PLATE_OF[ore]
  local sp = M.spec(furnace)
  local s = sp.w
  local lvl = sp.level and ("-n" .. sp.level) or ""
  local tag = (sp.base or furnace) == "stone-furnace" and "pierre" or "acier"
  local b = new_builder("fonderie-" .. ore_label(ore) .. "-" .. tag .. lvl,
    "Fonderie électrique (" .. ore_label(ore) .. ", " .. furnace .. ", " .. 2 * n .. " fours)",
    "Electric smelter (" .. ore_label_en(ore) .. ", " .. furnace .. ", " .. 2 * n .. " furnaces)")
  local rate = sp.speed / R[plate].time
  local fuel = (sp.burner_kw or 0) / M.COAL_J
  local in_k, in_n = M.choose_inserters(rate + fuel, true, 1)
  local out_k, out_n = M.choose_inserters(rate, false, 1)
  assert(in_k and out_k, "fonderie : bras introuvables")
  local x_out_w, x_ins_w, x_f_w = 0, 1, 2
  local x_in_w, x_belt, x_in_e = 2 + s, 3 + s, 4 + s
  local x_f_e, x_ins_e, x_out_e = 5 + s, 5 + 2 * s, 6 + 2 * s
  local H = n * s
  local main = b:belt_line(x_belt, 0, x_belt, H - 1, S)
  local ow = b:belt_line(x_out_w, 0, x_out_w, H - 1, S)
  local oe = b:belt_line(x_out_e, 0, x_out_e, H - 1, S)
  for i = 0, n - 1 do
    local y = i * s
    b:put(furnace, x_f_w, y, N, { recipe = plate, rate = rate, role = "four" })
    b:put(furnace, x_f_e, y, N, { recipe = plate, rate = rate, role = "four" })
    b:put(in_k, x_in_w, y, E)    -- prend à l'est (tapis), dépose à l'ouest (four)
    b:put(in_k, x_in_e, y, W)    -- prend à l'ouest (tapis), dépose à l'est
    b:put(out_k, x_ins_w, y, E)  -- prend à l'est (four), dépose à l'ouest (tapis de sortie)
    b:put(out_k, x_ins_e, y, W)
  end
  b:port({ kind = "tapis", io = "in", ent = main[1], lanes = { ore, "coal" } })
  b:port({ kind = "tapis", io = "out", ent = ow[#ow] })
  b:port({ kind = "tapis", io = "out", ent = oe[#oe] })
  local cands = {}
  for _, x in ipairs({ x_ins_w, x_in_w, x_in_e, x_ins_e }) do
    for y = 0, H - 1 do cands[#cands + 1] = { x, y } end
  end
  b.g.power_pole = b:auto_poles(cands)
  b.g.params = { furnace = furnace, ore = ore, n = n }
  b.g.extensions = { { param = "n", step = 1, max = math.floor(M.MAX_SIDE / s) } }
  return b:finish()
end

--- Ligne de foreuses électriques de part et d'autre d'un tapis qui sort au sud ; poteaux sur les deux bords.
function G.drills(ore, n, drill)
  drill = drill or "electric-mining-drill"
  local sp = M.spec(drill)
  local s = sp.w
  local lvl = sp.level and ("-n" .. sp.level) or ""
  local b = new_builder("foreuses-" .. ore_label(ore) .. lvl, "Ligne de " .. 2 * n .. " foreuses (" .. ore_label(ore) .. ", " .. drill .. ")",
    "Line of " .. 2 * n .. " drills (" .. ore_label_en(ore) .. ", " .. drill .. ")")
  -- rangée 0 : tête du tapis et poteaux de liaison (les deux bords sont à 2s + 2 tuiles l'un de l'autre)
  local H = n * s + 1
  local xb = s + 1
  local belt = b:belt_line(xb, 0, xb, H - 1, S)
  for i = 0, n - 1 do
    b:put(drill, 1, 1 + i * s, E, { role = "foreuse" })
    b:put(drill, xb + 1, 1 + i * s, W, { role = "foreuse" })
  end
  b:port({ kind = "tapis", io = "out", ent = belt[#belt] })
  local cands = {}
  for y = 0, H - 1 do cands[#cands + 1] = { 0, y }; cands[#cands + 1] = { 2 * s + 2, y } end
  for x = 1, 2 * s + 1 do cands[#cands + 1] = { x, 0 } end
  b.g.power_pole = b:auto_poles(cands)
  b.g.resource = ore
  b.g.params = { ore = ore, n = n, drill = drill }
  b.g.extensions = { { param = "n", step = 1, max = math.floor(M.MAX_SIDE / s) } }
  return b:finish()
end

--- Centrale à vapeur (époque 3) : pompe de rive à l'ouest, nb chaudières en rangée (l'eau traverse les chaudières),
--- 2 machines à vapeur au-dessus de chacune, deux bras à combustion par chaudière sur un tapis de charbon qui entre
--- à l'est. Poteaux sur les bords ouest et est (machines) et dans la rangée des bras.
function G.steam(nb)
  local b = new_builder("centrale-vapeur-" .. nb, "Centrale à vapeur (" .. nb .. " chaudières, " .. 2 * nb .. " machines)",
    "Steam power plant (" .. nb .. " boilers, " .. 2 * nb .. " engines)")
  local yb = 11
  local W_ = 3 * nb + 2
  b:put("offshore-pump", 0, yb, W, { role = "pompe" })
  for k = 0, nb - 1 do
    local x = 1 + 3 * k
    b:put("boiler", x, yb - 1, N, { role = "chaudiere" })
    b:put("steam-engine", x, yb - 6, N, { role = "machine" })
    b:put("steam-engine", x, yb - 11, N, { role = "machine" })
    b:put("burner-inserter", x, yb + 1, S)
    b:put("burner-inserter", x + 2, yb + 1, S)
  end
  local belt = b:belt_line(W_ - 1, yb + 2, 1, yb + 2, W)
  b:port({ kind = "tapis", io = "in", ent = belt[1], lanes = { "coal", "coal" } })
  b:port({ kind = "rive", io = "in", ent = 1, fluid = "water" })
  for dx = -6, -1 do for dy = -2, 2 do b.g.water[#b.g.water + 1] = { dx, yb + dy } end end
  local cands = {}
  for y = 0, yb - 2 do cands[#cands + 1] = { 0, y }; cands[#cands + 1] = { W_ - 1, y } end
  for x = 1, W_ - 1 do cands[#cands + 1] = { x, yb + 1 } end
  b.g.power_pole = b:auto_poles(cands)
  b.g.params = { nb = nb }
  b.g.extensions = { { param = "nb", step = 1, max = 7 } }
  return b:finish(W_, yb + 3)
end

--- Rangée d'assembleurs (ou de labos) : tapis d'entrée au nord (voies), bras, machines espacées d'une colonne de
--- liaison, bras de sortie, tapis de sortie au sud vers l'est. spec :
---   machines = { { name, recipe, rate, top = { objets pris au tapis du haut }, top2 = { objets pris au 2e tapis par
---     un bras long }, out = true (sortie au tapis du bas) } } ;
---   links = { { from = i, to = j (voisins), item, flow } } ;
---   lanes = voies du tapis du haut ; lanes2 = voies du 2e tapis (bras longs) ; out_x0 : début du tapis de sortie.
function G.row(key, fr, en, spec, ox, oy, b)
  b = b or new_builder(key, fr, en)
  ox, oy = ox or 0, oy or 0
  local s = M.spec(spec.machines[1].name).w
  local nm = #spec.machines
  local Wd = nm * s + (nm - 1)
  local has2 = spec.lanes2 ~= nil
  local y_top2 = oy
  local y_top = oy + (has2 and 1 or 0)
  local y_ins = y_top + 1
  local y_m = y_ins + 1
  local y_out = y_m + s
  local y_ob = y_out + 1
  local top = b:belt_line(ox, y_top, ox + Wd - 1, y_top, E)
  b:port({ kind = "tapis", io = "in", ent = top[1], lanes = spec.lanes })
  local top2
  if has2 then
    top2 = b:belt_line(ox, y_top2, ox + Wd - 1, y_top2, E)
    b:port({ kind = "tapis", io = "in", ent = top2[1], lanes = spec.lanes2 })
  end
  local any_out = false
  local xs = {}
  for i, m in ipairs(spec.machines) do
    local x = ox + (i - 1) * (s + 1)
    xs[i] = x
    b:put(m.name, x, y_m, N, { recipe = m.recipe, rate = m.rate, role = m.role or "machine" })
    local r = R[m.recipe]
    local rate = m.rate
    -- bras du haut
    local col = 0
    local function need_of(items)
      local t = 0
      for _, it in ipairs(items or {}) do
        if m.kind == "lab" then t = t + rate
        else
          for _, ing in ipairs(r.ingredients) do if ing.name == it then t = t + ing.amount * rate end end
        end
      end
      return t
    end
    if m.top and #m.top > 0 then
      local k, n = M.choose_inserters(need_of(m.top), true, s - (m.top2 and 1 or 0))
      assert(k, key .. " : bras du haut introuvables pour la machine " .. i)
      for _ = 1, n do b:put(k, x + col, y_ins, N); col = col + 1 end
    end
    if m.top2 and #m.top2 > 0 then
      local k, n = M.choose_inserters(need_of(m.top2), true, s - col, { "long-handed-inserter" })
      assert(k, key .. " : bras longs introuvables pour la machine " .. i)
      for _ = 1, n do b:put(k, x + col, y_ins, N); col = col + 1 end
    end
    if m.out then
      any_out = true
      local outn = 0
      for _, p in ipairs(r.products) do outn = outn + p.amount * rate end
      local k, n = M.choose_inserters(outn, false, s)
      assert(k, key .. " : bras de sortie introuvables pour la machine " .. i)
      for c = 0, n - 1 do b:put(k, x + c, y_out, N) end
    end
  end
  -- liaisons par la colonne entre deux voisins
  local used = {}
  for _, l in ipairs(spec.links or {}) do
    assert(math.abs(l.from - l.to) == 1, key .. " : liaison entre machines non voisines")
    local gap = math.min(l.from, l.to)
    local gx = xs[gap] + s
    local dir = l.from < l.to and W or E     -- prend du côté de la source
    local k, n = M.choose_inserters(l.flow, false, s)
    assert(k, key .. " : liaison " .. l.from .. " → " .. l.to .. " impossible")
    used[gap] = used[gap] or 0
    for _ = 1, n do
      assert(used[gap] < s, key .. " : colonne de liaison pleine")
      b:put(k, gx, y_m + used[gap], dir)
      used[gap] = used[gap] + 1
    end
  end
  local ob
  if any_out then
    local x0 = spec.out_x0 or ox
    ob = b:belt_line(x0, y_ob, ox + Wd - 1, y_ob, E)
    if not spec.no_out_port then b:port({ kind = "tapis", io = "out", ent = ob[#ob] }) end
  end
  return b, { y_ins = y_ins, y_out = y_out, y_ob = y_ob, w = Wd, xs = xs, s = s, top = top, out = ob, y_m = y_m }
end

local function row_poles(b, info, ox, oy, extra)
  local cands = {}
  for x = ox, ox + info.w - 1 do
    cands[#cands + 1] = { x, info.y_ins }
    cands[#cands + 1] = { x, info.y_out }
  end
  for i = 1, #info.xs - 1 do
    local gx = info.xs[i] + info.s
    for y = info.y_m, info.y_m + info.s - 1 do cands[#cands + 1] = { gx, y } end
  end
  for _, c in ipairs(extra or {}) do cands[#cands + 1] = c end
  return b:auto_poles(cands)
end

function G.gears(n, machine)
  machine = machine or "assembling-machine-2"
  local sp = M.spec(machine)
  local rate = sp.speed / R["iron-gear-wheel"].time
  local ms = {}
  for i = 1, n do ms[i] = { name = machine, recipe = "iron-gear-wheel", rate = rate, top = { "iron-plate" }, out = true } end
  local lvl = sp.level and ("-n" .. sp.level) or ""
  local b, info = G.row("engrenages" .. lvl, "Engrenages (" .. n .. " " .. machine .. ")", "Gears (" .. n .. " " .. machine .. ")",
    { machines = ms, lanes = { "iron-plate", "iron-plate" } })
  b.g.power_pole = row_poles(b, info, 0, 0)
  b.g.params = { n = n, machine = machine }
  b.g.extensions = { { param = "n", step = 1, max = 6 } }
  return b:finish()
end

--- Îlot de circuits verts « C K C K C » : 3 assembleurs de câbles (cuivre) et 2 de circuits ; chaque circuit reçoit
--- ses câbles de ses deux voisins (rapport 3:2, EQUIPES_PNJ §6.4), le fer au tapis du haut.
function G.circuits(machine)
  machine = machine or "assembling-machine-2"
  local sp = M.spec(machine)
  local kc = sp.speed / R["copper-cable"].time            -- fabrications de câbles par seconde (2 câbles chacune)
  local kk = sp.speed / R["electronic-circuit"].time      -- circuits par seconde
  local cab = 2 * kc
  local ms = {
    { name = machine, recipe = "copper-cable", rate = kc, top = { "copper-plate" } },
    { name = machine, recipe = "electronic-circuit", rate = kk, top = { "iron-plate" }, out = true },
    { name = machine, recipe = "copper-cable", rate = kc, top = { "copper-plate" } },
    { name = machine, recipe = "electronic-circuit", rate = kk, top = { "iron-plate" }, out = true },
    { name = machine, recipe = "copper-cable", rate = kc, top = { "copper-plate" } },
  }
  local need = 3 * kk
  local links = {
    { from = 1, to = 2, item = "copper-cable", flow = cab },
    { from = 3, to = 2, item = "copper-cable", flow = need - cab },
    { from = 3, to = 4, item = "copper-cable", flow = cab - (need - cab) },
    { from = 5, to = 4, item = "copper-cable", flow = cab },
  }
  local lvl = sp.level and ("-n" .. sp.level) or ""
  local b, info = G.row("circuits-verts" .. lvl, "Îlot de circuits verts (C K C K C, " .. machine .. ")",
    "Green circuit island (C K C K C, " .. machine .. ")", { machines = ms, links = links, lanes = { "iron-plate", "copper-plate" } })
  b.g.power_pole = row_poles(b, info, 0, 0)
  b.g.params = { machine = machine }
  return b:finish()
end

--- Moteurs « P M G M P » : assembleurs de tuyaux et d'engrenages au contact des assembleurs de moteurs ; acier et fer
--- au tapis du haut.
function G.engines(machine)
  machine = machine or "assembling-machine-2"
  local sp = M.spec(machine)
  local ke = sp.speed / R["engine-unit"].time
  local ms = {
    { name = machine, recipe = "pipe", rate = 2 * ke, top = { "iron-plate" } },
    { name = machine, recipe = "engine-unit", rate = ke, top = { "steel-plate" }, out = true },
    { name = machine, recipe = "iron-gear-wheel", rate = 2 * ke, top = { "iron-plate" } },
    { name = machine, recipe = "engine-unit", rate = ke, top = { "steel-plate" }, out = true },
    { name = machine, recipe = "pipe", rate = 2 * ke, top = { "iron-plate" } },
  }
  local links = {
    { from = 1, to = 2, item = "pipe", flow = 2 * ke },
    { from = 3, to = 2, item = "iron-gear-wheel", flow = ke },
    { from = 3, to = 4, item = "iron-gear-wheel", flow = ke },
    { from = 5, to = 4, item = "pipe", flow = 2 * ke },
  }
  local b, info = G.row("moteurs", "Moteurs (P M G M P, " .. machine .. ")", "Engines (P E G E P, " .. machine .. ")",
    { machines = ms, links = links, lanes = { "iron-plate", "steel-plate" } })
  b.g.power_pole = row_poles(b, info, 0, 0)
  b.g.params = { machine = machine }
  return b:finish()
end

--- Labos (n) nourris par un tapis de packs (voies : packs rouges et verts). `unit_time` : durée d'une unité de
--- recherche (s) ; nominal = packs consommés par seconde de chaque sorte.
function G.labs(n, unit_time)
  local rate = BASE.lab.speed / unit_time
  local ms = {}
  for i = 1, n do ms[i] = { name = "lab", kind = "lab", recipe = nil, rate = rate, top = { "automation-science-pack", "logistic-science-pack" } } end
  local b, info = G.row("labos-" .. n, "Labos (" .. n .. ", packs rouges et verts)", "Labs (" .. n .. ", red and green packs)",
    { machines = ms, lanes = { "automation-science-pack", "logistic-science-pack" } })
  b.g.power_pole = row_poles(b, info, 0, 0)
  b.g.params = { n = n, unit_time = unit_time }
  b.g.labs = { packs = { "automation-science-pack", "logistic-science-pack" }, unit_time = unit_time }
  b.g.extensions = { { param = "n", step = 1, max = 6 } }
  return b:finish()
end

--- Circuits rouges « A C A A C A » : deux tapis au nord (cuivre par bras longs pour les câbles ; circuits verts et
--- plastique pour les assembleurs de circuits rouges), câbles par contact.
function G.advanced_circuits(machine)
  machine = machine or "assembling-machine-2"
  local sp = M.spec(machine)
  local ka = sp.speed / R["advanced-circuit"].time
  local kc = 4 * ka * 2 / 2                          -- 2 voisins × 4 câbles × ka, 2 câbles par fabrication
  local A = function() return { name = machine, recipe = "advanced-circuit", rate = ka, top = { "electronic-circuit", "plastic-bar" }, out = true } end
  local C = function() return { name = machine, recipe = "copper-cable", rate = kc, top2 = { "copper-plate" } } end
  local ms = { A(), C(), A(), A(), C(), A() }
  local links = {
    { from = 2, to = 1, item = "copper-cable", flow = 4 * ka }, { from = 2, to = 3, item = "copper-cable", flow = 4 * ka },
    { from = 5, to = 4, item = "copper-cable", flow = 4 * ka }, { from = 5, to = 6, item = "copper-cable", flow = 4 * ka },
  }
  local b, info = G.row("circuits-rouges", "Circuits rouges (A C A A C A, " .. machine .. ")", "Red circuits (A C A A C A, " .. machine .. ")",
    { machines = ms, links = links, lanes = { "electronic-circuit", "plastic-bar" }, lanes2 = { "copper-plate", "copper-plate" } })
  b.g.power_pole = row_poles(b, info, 0, 0)
  b.g.params = { machine = machine }
  return b:finish()
end

--- Bloc à deux étages : l'étage A (rangée) dépose sur un tapis de jonction (deux tronçons qui se rejoignent par les
--- côtés sur une tuile qui descend : une voie chacun), qui devient le tapis d'entrée de l'étage B.
---   specA : rangée A (sorties au tapis du bas ; `merge_x` = colonne de jonction ; `west_out`/`east_out` : machines
---           dont la sortie va à l'ouest ou à l'est de la jonction) ; side_port : objet amené par un port latéral
---           à l'est (au lieu de l'est de l'étage A).
local function two_stage(key, fr, en, specA, specB, merge_x, side_port)
  local b = new_builder(key, fr, en)
  specA.no_out_port = true
  local _, ia = G.row(key, fr, en, specA, 0, 0, b)
  -- remplacer le tapis du bas de A par deux tronçons orientés vers la jonction
  local yj = ia.y_ob
  local keep = {}
  local ob = {}
  for _, i in ipairs(ia.out or {}) do ob[i] = true end
  for i, e in ipairs(b.g.entities) do if not ob[i] then keep[#keep + 1] = e end end
  b.g.entities = keep
  b.g.ports = { b.g.ports[1] }                          -- seul le port d'entrée de A
  local wa = ia.w
  local east_end = side_port and nil or (wa - 1)
  if merge_x > 0 then b:belt_line(0, yj, merge_x - 1, yj, E) end
  local jn = b:put("transport-belt", merge_x, yj, S)
  b:put("transport-belt", merge_x, yj + 1, S)
  local ib
  -- étage B : tapis d'entrée à partir de la jonction, vers l'est
  local yB = yj + 2
  specB.no_in_port = true
  local bB = new_builder(key .. "-B", fr, en)
  local _, iB = G.row(key .. "-B", fr, en, specB, merge_x, yB, bB)
  -- recopier B (sans son port d'entrée : alimenté par la jonction)
  local offset = #b.g.entities
  for _, e in ipairs(bB.g.entities) do b.g.entities[#b.g.entities + 1] = e end
  for _, p in ipairs(bB.g.ports) do
    if p.io == "out" then
      local q = copy(p); q.ent = p.ent + offset; b:port(q)
    end
  end
  local wtot = merge_x + iB.w
  if side_port then
    local sb = b:belt_line(wtot - 1, yj, merge_x + 1, yj, W)
    b:port({ kind = "tapis", io = "in", ent = sb[1], lanes = { side_port, side_port } })
  elseif east_end and east_end > merge_x then
    b:belt_line(east_end, yj, merge_x + 1, yj, W)
  end
  return b, ia, iB, jn, offset
end

--- Packs rouges complets : un assembleur d'engrenages (fer) dépose à l'ouest de la jonction, le cuivre arrive par
--- un port à l'est ; 5 assembleurs de packs rouges.
function G.red_packs(machine)
  machine = machine or "assembling-machine-2"
  local sp = M.spec(machine)
  local kr = sp.speed / R["automation-science-pack"].time
  local nB = 5
  local kg = nB * kr
  local specA = { machines = { { name = machine, recipe = "iron-gear-wheel", rate = kg, top = { "iron-plate" }, out = true } },
    lanes = { "iron-plate", "iron-plate" } }
  local ms = {}
  for i = 1, nB do ms[i] = { name = machine, recipe = "automation-science-pack", rate = kr, top = { "copper-plate", "iron-gear-wheel" }, out = true } end
  local specB = { machines = ms, lanes = nil }
  local b, ia, iB = two_stage("packs-rouges", "Packs rouges (engrenages, puis " .. nB .. " assembleurs)",
    "Red science (gears, then " .. nB .. " assemblers)", specA, specB, 3, "copper-plate")
  local cands = {}
  for x = 0, 2 do cands[#cands + 1] = { x, ia.y_ins }; cands[#cands + 1] = { x, ia.y_out } end
  for y = ia.y_m, ia.y_m + ia.s - 1 do cands[#cands + 1] = { 3, y }; cands[#cands + 1] = { 4, y } end
  b.g.power_pole = row_poles(b, iB, 3, 0, cands)
  b.g.params = { machine = machine, n = nB }
  return b:finish()
end

--- Packs verts complets : étage A « bras, engrenages, convoyeurs » (I G B, engrenages par contact) ; les bras sortent
--- à l'ouest de la jonction, les convoyeurs à l'est (une voie chacun) ; étage B : 5 assembleurs de packs verts.
function G.green_packs(machine)
  machine = machine or "assembling-machine-2"
  local sp = M.spec(machine)
  local kp = sp.speed / R["logistic-science-pack"].time
  local nB = 5
  local ki = nB * kp                       -- bras par seconde
  local kb = nB * kp / 2                   -- fabrications de convoyeurs (2 par fabrication)
  local kg = ki + kb                       -- engrenages
  local specA = { machines = {
      { name = machine, recipe = "inserter", rate = ki, top = { "iron-plate", "electronic-circuit" }, out = true },
      { name = machine, recipe = "iron-gear-wheel", rate = kg, top = { "iron-plate" } },
      { name = machine, recipe = "transport-belt", rate = kb, top = { "iron-plate" }, out = true },
    },
    links = { { from = 2, to = 1, item = "iron-gear-wheel", flow = ki }, { from = 2, to = 3, item = "iron-gear-wheel", flow = kb } },
    lanes = { "iron-plate", "electronic-circuit" } }
  local ms = {}
  for i = 1, nB do ms[i] = { name = machine, recipe = "logistic-science-pack", rate = kp, top = { "inserter", "transport-belt" }, out = true } end
  local b, ia, iB = two_stage("packs-verts", "Packs verts (bras, engrenages, convoyeurs, puis " .. nB .. " assembleurs)",
    "Green science (inserters, gears, belts, then " .. nB .. " assemblers)", specA, { machines = ms }, 5, nil)
  local cands = {}
  for x = 0, ia.w - 1 do cands[#cands + 1] = { x, ia.y_ins }; cands[#cands + 1] = { x, ia.y_out } end
  for i = 1, 2 do for y = ia.y_m, ia.y_m + ia.s - 1 do cands[#cands + 1] = { ia.xs[i] + ia.s, y } end end
  b.g.power_pole = row_poles(b, iB, 5, 0, cands)
  b.g.params = { machine = machine, n = nB }
  return b:finish()
end

--- Chevalets (époque 4) : n chevalets côte à côte, sortie au nord sur un collecteur qui sort à l'est. Ne se tourne
--- pas (sorties explicites du prototype, voir BASE.pumpjack).
function G.pumpjacks(n)
  local b = new_builder("chevalets-" .. n, "Chevalets (" .. n .. ")", "Pumpjacks (" .. n .. ")")
  for i = 0, n - 1 do b:put("pumpjack", 3 * i, 1, N, { role = "chevalet" }) end
  local pipes = b:pipe_line(0, 0, 3 * n - 1, 0)
  b:port({ kind = "tuyau", io = "out", ent = pipes[#pipes], fluid = "crude-oil" })
  local cands = {}
  for x = 0, 3 * n - 1 do cands[#cands + 1] = { x, 4 } end
  b.g.power_pole = b:auto_poles(cands)
  b.g.resource = "crude-oil"
  b.g.no_rotate = true
  b.g.params = { n = n }
  b.g.extensions = { { param = "n", step = 1, max = 8 } }
  return b:finish()
end

--- Raffinerie (traitement de base) : n raffineries ; brut au sud par un collecteur (entrée à l'ouest), gaz au nord
--- par un collecteur (sortie à l'est). Les raccords inutilisés des raffineries restent libres.
function G.refinery(n)
  local b = new_builder("raffinerie-" .. n, "Raffinerie (" .. n .. ", traitement de base)", "Oil refinery (" .. n .. ", basic processing)")
  local k = 1 / R["basic-oil-processing"].time
  for i = 0, n - 1 do
    b:put("oil-refinery", 5 * i, 2, N, { recipe = "basic-oil-processing", rate = k })
    b:put("pipe", 5 * i + 3, 7, N)
    b:put("pipe", 5 * i + 4, 1, N)
  end
  local crude = b:pipe_line(0, 8, 5 * n - 1, 8)
  local gas = b:pipe_line(0, 0, 5 * n - 1, 0)
  b:port({ kind = "tuyau", io = "in", ent = crude[1], fluid = "crude-oil" })
  b:port({ kind = "tuyau", io = "out", ent = gas[#gas], fluid = "petroleum-gas" })
  local cands = {}
  for x = 0, 5 * n - 1 do cands[#cands + 1] = { x, 1 }; cands[#cands + 1] = { x, 7 } end
  -- un poteau ne touche pas un raccord inutilisé : il n'est pas une entité à fluide (aucun risque de mélange)
  b.g.power_pole = b:auto_poles(cands)
  b.g.params = { n = n }
  b.g.extensions = { { param = "n", step = 1, max = 4 } }
  return b:finish()
end

--- Plastique : n usines chimiques ; gaz au nord (collecteur, entrée à l'ouest), charbon au sud par un tapis (entrée
--- à l'ouest), plastique par des bras longs sur un second tapis (sortie à l'est).
function G.plastic(n)
  local b = new_builder("plastique-" .. n, "Plastique (" .. n .. " usines chimiques)", "Plastic (" .. n .. " chemical plants)")
  local k = 1 / R["plastic-bar"].time
  local ck, cn = M.choose_inserters(k, true, 1)
  local ok_, on = M.choose_inserters(2 * k, false, 2, { "long-handed-inserter" })
  for i = 0, n - 1 do
    local x = 3 * i
    b:put("chemical-plant", x, 2, N, { recipe = "plastic-bar", rate = k })
    b:put("pipe", x, 1, N)
    b:put(ck, x, 5, S)
    for c = 1, on do b:put(ok_, x + c, 5, N) end
  end
  local gas = b:pipe_line(0, 0, 3 * n - 1, 0)
  local coal = b:belt_line(0, 6, 3 * n - 1, 6, E)
  local out = b:belt_line(0, 7, 3 * n - 1, 7, E)
  b:port({ kind = "tuyau", io = "in", ent = gas[1], fluid = "petroleum-gas" })
  b:port({ kind = "tapis", io = "in", ent = coal[1], lanes = { "coal", "coal" } })
  b:port({ kind = "tapis", io = "out", ent = out[#out] })
  local cands = {}
  for x = 0, 3 * n - 1 do cands[#cands + 1] = { x, 1 }; cands[#cands + 1] = { x, 8 } end
  b.g.power_pole = b:auto_poles(cands)
  b.g.params = { n = n }
  b.g.extensions = { { param = "n", step = 1, max = 8 } }
  return b:finish()
end

--- Soufre : n usines chimiques au pas de 4 ; l'eau (rangée 0) et le gaz (rangée 1) arrivent au nord sans se
--- toucher : chaque collecteur passe SOUS les piquages de l'autre par des paires de tuyaux souterrains.
function G.sulfur(n)
  local b = new_builder("soufre-" .. n, "Soufre (" .. n .. " usines chimiques)", "Sulfur (" .. n .. " chemical plants)")
  local k = 1 / R["sulfur"].time
  local ok_, on = M.choose_inserters(2 * k, false, 3)
  for i = 0, n - 1 do
    local x = 4 * i
    b:put("chemical-plant", x, 2, N, { recipe = "sulfur", rate = k })
    b:put("pipe", x, 0, N)          -- collecteur d'eau
    b:put("pipe", x, 1, N)          -- piquage d'eau (raccord 1)
    b:put("pipe", x + 2, 1, N)      -- piquage de gaz (raccord 2)
    if i < n - 1 then
      b:put("pipe-to-ground", x + 1, 0, W)   -- eau : sort au nord-ouest du suivant par en dessous
      b:put("pipe-to-ground", x + 3, 0, E)
      b:put("pipe-to-ground", x + 3, 1, W)   -- gaz : passe sous le piquage d'eau suivant
      b:put("pipe-to-ground", x + 5, 1, E)
    end
    for c = 0, on - 1 do b:put(ok_, x + c, 5, N) end
  end
  local gas_port = b:put("pipe", 4 * n - 1, 1, N)
  local out = b:belt_line(0, 6, 4 * n - 1, 6, E)
  b:port({ kind = "tuyau", io = "in", ent = 2, fluid = "water" })
  b:port({ kind = "tuyau", io = "in", ent = gas_port, fluid = "petroleum-gas" })
  b:port({ kind = "tapis", io = "out", ent = out[#out] })
  local cands = {}
  for x = 0, 4 * n - 1 do cands[#cands + 1] = { x, 5 } end
  for i = 0, n - 1 do for y = 2, 4 do cands[#cands + 1] = { 4 * i + 3, y } end end
  b.g.power_pole = b:auto_poles(cands)
  b.g.params = { n = n }
  b.g.extensions = { { param = "n", step = 1, max = 6 } }
  return b:finish()
end

--- Pétrole sur place (EQUIPES_PNJ §6.8, greffe P1 : on raffine près du champ et on transporte du solide) : une
--- raffinerie et une usine chimique de plastique ; brut à l'ouest, charbon à l'est, plastique à l'est.
function G.oil_plastic()
  local b = new_builder("petrole-plastique", "Pétrole sur place : raffinerie et plastique", "On-site oil: refinery and plastic")
  local kr = 1 / R["basic-oil-processing"].time
  local gas = 45 * kr
  local kp = gas / 20
  b:put("oil-refinery", 0, 2, N, { recipe = "basic-oil-processing", rate = kr })
  b:put("pipe", 3, 7, N)
  local crude = b:pipe_line(0, 8, 3, 8)
  b:put("pipe", 4, 1, N)
  b:pipe_line(4, 0, 6, 0)
  b:put("pipe", 6, 1, N)
  b:put("chemical-plant", 6, 2, N, { recipe = "plastic-bar", rate = kp })
  local ck = M.choose_inserters(kp, true, 1)
  local lk, ln = M.choose_inserters(2 * kp, false, 2, { "long-handed-inserter" })
  b:put(ck, 6, 5, S)
  for c = 1, ln do b:put(lk, 6 + c, 5, N) end
  local coal = b:belt_line(8, 6, 6, 6, W)
  local out = b:belt_line(6, 7, 8, 7, E)
  b:port({ kind = "tuyau", io = "in", ent = crude[1], fluid = "crude-oil" })
  b:port({ kind = "tapis", io = "in", ent = coal[1], lanes = { "coal", "coal" } })
  b:port({ kind = "tapis", io = "out", ent = out[#out] })
  local cands = {}
  for x = 0, 8 do cands[#cands + 1] = { x, 1 }; cands[#cands + 1] = { x, 7 }; cands[#cands + 1] = { x, 8 } end
  for y = 2, 6 do cands[#cands + 1] = { 5, y } end
  b.g.power_pole = b:auto_poles(cands)
  return b:finish()
end

---------------------------------------------------------------------------------------------------
-- 6. Catalogue (ordre fixe)
---------------------------------------------------------------------------------------------------
local function lv(fam, n) return L.name(L.by_key[fam], n) end
M.LAB_UNIT_TIME = 30

local CATALOGUE
function M.catalogue()
  if CATALOGUE then return CATALOGUE end
  local list = {
    G.outpost_burner("iron-ore", 6),
    G.outpost_burner("copper-ore", 6),
    G.smelter("stone-furnace", "iron-ore", 8),
    G.smelter("stone-furnace", "copper-ore", 8),
    G.smelter("steel-furnace", "iron-ore", 5),
    G.smelter(lv("furnace", 7), "iron-ore", 3),
    G.drills("iron-ore", 6),
    G.drills("copper-ore", 6),
    G.drills("coal", 6),
    G.drills("iron-ore", 5, lv("drill", 7)),
    G.steam(2),
    G.gears(4),
    G.circuits(),
    G.circuits(lv("assembler", 7)),
    G.red_packs(),
    G.green_packs(),
    G.labs(4, M.LAB_UNIT_TIME),
    G.engines(),
    G.pumpjacks(4),
    G.refinery(2),
    G.plastic(2),
    G.sulfur(2),
    G.oil_plastic(),
    G.advanced_circuits(),
  }
  CATALOGUE = list
  return list
end

function M.get(key)
  for _, g in ipairs(M.catalogue()) do if g.key == key then return g end end
  return nil
end

---------------------------------------------------------------------------------------------------
-- 7. Rotation et pose dans le monde
---------------------------------------------------------------------------------------------------
--- Gabarit tourné de k quarts de tour (sens horaire), en coordonnées locales. Refusé (nil, raison) si no_rotate.
function M.rotate(g, k)
  k = k % 4
  if k == 0 then return g end
  if g.no_rotate then return nil, "gabarit non orientable (sorties de chevalet explicites par direction)" end
  local o = copy(g)
  local w, h = g.w, g.h
  local function pt(x, y)
    local xx, yy, ww, hh = x, y, w, h
    for _ = 1, k do xx, yy = hh - yy, xx; ww, hh = hh, ww end
    return xx, yy
  end
  for _, e in ipairs(o.entities) do
    e.x, e.y = pt(e.x, e.y)
    e.dir = ((e.dir or 0) + 2 * k) % 8
  end
  for _, a in ipairs(o.anchors) do a.x, a.y = pt(a.x, a.y) end
  for i, t in ipairs(o.water or {}) do
    local x, y = pt(t[1] + 0.5, t[2] + 0.5)
    o.water[i] = { math.floor(x), math.floor(y) }
  end
  if k % 2 == 1 then o.w, o.h = h, w end
  o.rotation = ((g.rotation or 0) + k) % 4
  return o
end

--- Entités du gabarit dans le monde (coin nord-ouest de l'emprise en (ox, oy), entiers), après k quarts de tour.
function M.instantiate(g, k, ox, oy)
  local r, why = M.rotate(g, k or 0)
  if not r then return nil, why end
  local out = { entities = {}, ports = {}, anchors = {}, water = {}, w = r.w, h = r.h, gabarit = r }
  for i, e in ipairs(r.entities) do
    out.entities[i] = { name = e.name, position = { x = ox + e.x, y = oy + e.y }, direction = e.dir, recipe = e.recipe, type = e.type }
  end
  for i, p in ipairs(r.ports) do local q = copy(p); out.ports[i] = q end
  for i, a in ipairs(r.anchors) do out.anchors[i] = { x = ox + a.x, y = oy + a.y } end
  for i, t in ipairs(r.water or {}) do out.water[i] = { ox + t[1], oy + t[2] } end
  return out
end

---------------------------------------------------------------------------------------------------
-- 8. Analyse et contrôle
---------------------------------------------------------------------------------------------------
--- Tuiles de minerai que les foreuses exploitent (coordonnées locales), triées ; positions des puits des chevalets.
function M.resource_tiles(g)
  local seen, out = {}, {}
  for _, e in ipairs(g.entities) do
    local s = M.spec(e.name)
    if s.kind == "drill" then
      local r = s.radius
      for tx = math.floor(e.x - r), math.ceil(e.x + r) - 1 do
        for ty = math.floor(e.y - r), math.ceil(e.y + r) - 1 do
          local k = tkey(tx, ty)
          if not seen[k] then seen[k] = true; out[#out + 1] = { tx, ty } end
        end
      end
    elseif s.kind == "pumpjack" then
      out[#out + 1] = { e.x, e.y, well = true }
    end
  end
  table.sort(out, function(a, b) if a[2] ~= b[2] then return a[2] < b[2] end return a[1] < b[1] end)
  return out
end

-- Cadence maximale (fabrications/s) d'une entité de production.
local function max_rate(e)
  local s = M.spec(e.name)
  if s.kind == "assembler" or s.kind == "furnace" then
    local r = R[e.recipe]
    return r and s.speed / r.time or 0
  elseif s.kind == "drill" then return s.speed
  elseif s.kind == "pumpjack" then return s.rate
  elseif s.kind == "lab" then return e.rate or 0
  end
  return 0
end

local function epoch_of_name(name, idx)
  local fam, n = L.parse(name)
  if fam and n > 1 then return L.epoch_of(fam, n) end
  return idx[name]
end

local EPOCH_IDX
local function epoch_index()
  if EPOCH_IDX then return EPOCH_IDX end
  EPOCH_IDX = {}
  for _, row in ipairs(X.base_recipe_epochs) do
    for _, n in ipairs(row[2]) do if not EPOCH_IDX[n] then EPOCH_IDX[n] = row[1] end end
  end
  return EPOCH_IDX
end
M.epoch_index = epoch_index

--- Flot maximal (Edmonds-Karp) sur un petit graphe : n nœuds, arêtes { a, b, cap } ; renvoie le flot.
local function maxflow(n, edges, s, t)
  local head, nxt, to, cap = {}, {}, {}, {}
  local m = 0
  local function add(a, b, c)
    m = m + 1; to[m] = b; cap[m] = c; nxt[m] = head[a] or 0; head[a] = m
    m = m + 1; to[m] = a; cap[m] = 0; nxt[m] = head[b] or 0; head[b] = m
  end
  for _, e in ipairs(edges) do add(e[1], e[2], e[3]) end
  local flow = 0
  for _ = 1, 10000 do
    local prev = {}
    prev[s] = 0
    local q, qi = { s }, 1
    while qi <= #q and prev[t] == nil do
      local a = q[qi]; qi = qi + 1
      local ei = head[a] or 0
      while ei > 0 do
        local b = to[ei]
        if prev[b] == nil and cap[ei] > 1e-12 then prev[b] = ei; q[#q + 1] = b end
        ei = nxt[ei]
      end
    end
    if prev[t] == nil then break end
    local f, v = math.huge, t
    while v ~= s do local ei = prev[v]; f = math.min(f, cap[ei]); v = to[ei % 2 == 0 and ei - 1 or ei + 1] end
    v = t
    while v ~= s do
      local ei = prev[v]
      cap[ei] = cap[ei] - f
      local rev = ei % 2 == 0 and ei - 1 or ei + 1
      cap[rev] = cap[rev] + f
      v = to[rev]
    end
    flow = flow + f
  end
  return flow
end
M.maxflow = maxflow

--- Débit maximal (unités/s) d'une conduite droite de `len` tuyaux (fluides 1.1). Table MESURÉE en moteur réel par le
--- banc ia1-modules (R8, 24/10 : eau, tuyau source remis plein et tuyau puits vidé à chaque tick, `len` tuyaux entre
--- les deux, 5 min), arrondie vers le bas. Entre deux longueurs : la valeur de la plus longue (prudent) ; au-delà de
--- 400 : extrapolation en 1/len (prudente : la mesure tombe plus vite que 1/len entre 200 et 400).
M.PIPE_FLOW = { { 1, 2250 }, { 2, 1909 }, { 5, 1500 }, { 10, 1285 }, { 12, 1243 }, { 17, 1178 }, { 20, 1153 },
  { 30, 1105 }, { 50, 1064 }, { 100, 1031 }, { 200, 995 }, { 400, 543 } }
M.PIPE_FLOW_SOURCE = "mesure ia1-modules 24/10"
function M.pipe_capacity(len)
  local t = M.PIPE_FLOW
  if len <= t[1][1] then return t[1][2] end
  for i = 2, #t do
    if len <= t[i][1] then return t[i][2] end
  end
  return t[#t][2] * t[#t][1] / len
end

--- Analyse complète d'un gabarit : { errors = {…}, outputs = {objet = /s}, inputs, power_kw, epoch, unlocks,
--- lanes (voies des ports), fluid_nets, … }. Ne lève jamais d'erreur sur un gabarit faux : tout va dans errors.
function M.analyze(g)
  local errors = {}
  local function err(msg) errors[#errors + 1] = msg end
  local ents = g.entities
  local n = #ents
  local specs = {}
  for i, e in ipairs(ents) do
    local s = M.spec(e.name)
    if not s then err("entité inconnue n°" .. i .. " : " .. tostring(e.name)) else specs[i] = s end
  end
  if #errors > 0 then return { errors = errors, outputs = {}, inputs = {} } end
  local function label(i) local e = ents[i]; return e.name .. " n°" .. i .. " (" .. fmt(e.x) .. ", " .. fmt(e.y) .. ")" end

  -- 8.1 grille, emprise, chevauchements
  local W_, H_ = g.w or 0, g.h or 0
  if W_ > M.MAX_SIDE or H_ > M.MAX_SIDE then err(string.format("emprise %d×%d au-delà de %d×%d", W_, H_, M.MAX_SIDE, M.MAX_SIDE)) end
  local occ = {}
  local tiles = {}
  for i, e in ipairs(ents) do
    local x0, y0, x1, y1 = rect(e)
    if math.abs(x0 - math.floor(x0 + 0.5)) > M.EPS or math.abs(y0 - math.floor(y0 + 0.5)) > M.EPS then
      err(label(i) .. " hors de la grille")
    end
    if x0 < -M.EPS or y0 < -M.EPS or x1 > W_ + M.EPS or y1 > H_ + M.EPS then err(label(i) .. " hors de l'emprise") end
    tiles[i] = {}
    for tx = math.floor(x0 + 0.01), math.ceil(x1 - 0.01) - 1 do
      for ty = math.floor(y0 + 0.01), math.ceil(y1 - 0.01) - 1 do
        local k = tkey(tx, ty)
        if occ[k] then err("chevauchement : " .. label(occ[k]) .. " et " .. label(i) .. " sur la tuile (" .. tx .. ", " .. ty .. ")") end
        occ[k] = i
        tiles[i][#tiles[i] + 1] = { tx, ty }
      end
    end
    if specs[i].kind == "offshore" then
      -- boîte de collision de 1,2 de large : les deux voisines dans l'axe de la rive restent libres
      local vx, vy = rot(e.dir, 1, 0)
      for _, sg in ipairs({ -1, 1 }) do
        local k = tkey(math.floor(e.x + sg * vx), math.floor(e.y + sg * vy))
        if occ[k] and occ[k] ~= i then err("pompe de rive " .. label(i) .. " : voisine occupée par " .. label(occ[k])) end
        occ[k] = occ[k] or -i
      end
    end
  end
  local function at(x, y)
    local v = occ[tkey(math.floor(x), math.floor(y))]
    if v and v > 0 then return v end
    return nil
  end
  local function inside(x, y) return x >= -M.EPS and y >= -M.EPS and x <= W_ + M.EPS and y <= H_ + M.EPS end

  -- 8.2 cadences prévues
  local rate = {}
  for i, e in ipairs(ents) do
    local mr = max_rate(e)
    local s = specs[i]
    if s.kind == "assembler" or s.kind == "furnace" then
      if not e.recipe or not R[e.recipe] then err(label(i) .. " : recette absente ou inconnue (" .. tostring(e.recipe) .. ")")
      else
        local cat = R[e.recipe].category
        if s.kind == "furnace" and cat ~= "smelting" then err(label(i) .. " : un four ne fait pas « " .. e.recipe .. " »") end
        if s.kind == "assembler" then
          local ok = false
          for _, c in ipairs(s.categories or {}) do if c == cat then ok = true end end
          if not ok then err(label(i) .. " : catégorie « " .. cat .. " » impossible") end
        end
      end
    end
    rate[i] = e.rate or mr
    if rate[i] > mr + 1e-9 and s.kind ~= "lab" then err(label(i) .. string.format(" : cadence prévue %.4f > maximale %.4f", rate[i], mr)) end
  end

  -- 8.3 tapis : liaisons, virages, chargements latéraux, voies
  local belts, is_belt = {}, {}
  for i, e in ipairs(ents) do if specs[i].kind == "belt" then belts[#belts + 1] = i; is_belt[i] = true end end
  local feeders = {}
  for _, i in ipairs(belts) do feeders[i] = {} end
  local downstream = {}
  for _, i in ipairs(belts) do
    local e = ents[i]
    local v = DV[e.dir]
    local j = at(e.x + v[1], e.y + v[2])
    if j and is_belt[j] then
      local f = ents[j]
      if f.dir == opposite(e.dir) then err("tapis face à face : " .. label(i) .. " et " .. label(j))
      elseif f.dir == e.dir then feeders[j][#feeders[j] + 1] = { from = i, kind = "behind" }; downstream[i] = j
      else
        local lx, ly = left_of(f.dir)
        local side = (-v[1]) * lx + (-v[2]) * ly > 0 and 1 or 2
        feeders[j][#feeders[j] + 1] = { from = i, kind = "side", side = side }
        downstream[i] = j
      end
    end
  end
  for _, j in ipairs(belts) do
    local behind = false
    local sides = {}
    for _, f in ipairs(feeders[j]) do if f.kind == "behind" then behind = true else sides[#sides + 1] = f end end
    if not behind and #sides == 1 then sides[1].kind = "turn" end
  end
  local lanes = {}
  for _, i in ipairs(belts) do lanes[i] = { {}, {} } end
  local port_of_ent = {}
  for pi, p in ipairs(g.ports) do port_of_ent[p.ent] = pi end
  local function add_lane(i, l, item)
    if not lanes[i][l][item] then lanes[i][l][item] = true; return true end
    return false
  end
  -- semis : ports d'entrée, dépôts des bras et des foreuses (calculés plus bas : on les mémorise)
  local seeds = {}
  for _, p in ipairs(g.ports) do
    if p.kind == "tapis" and p.io == "in" and is_belt[p.ent] then
      for l = 1, 2 do if p.lanes and p.lanes[l] then seeds[#seeds + 1] = { p.ent, l, p.lanes[l] } end end
    end
  end

  -- 8.4 bras et foreuses : cibles
  local links = {}          -- { from, to, cap (objets/s), via = indice du bras }
  local ins_side = {}
  local products, accepts = {}, {}
  local function prod_items(i)
    local e, s = ents[i], specs[i]
    if s.kind == "assembler" or s.kind == "furnace" then
      local r = R[e.recipe]
      local t = {}
      if r then for _, p in ipairs(r.products) do if not p.fluid then t[#t + 1] = p.name end end end
      return t
    end
    return {}
  end
  local fuel_burner = function(s) return s.burner_kw and s.burner_kw > 0 end
  local function accept_items(i)
    local e, s = ents[i], specs[i]
    local t = {}
    if s.kind == "assembler" or s.kind == "furnace" then
      local r = R[e.recipe]
      if r then for _, p in ipairs(r.ingredients) do if not p.fluid then t[#t + 1] = p.name end end end
    elseif s.kind == "lab" then
      for _, p in ipairs((g.labs or {}).packs or {}) do t[#t + 1] = p end
    end
    if fuel_burner(s) then t[#t + 1] = "coal" end
    return t
  end
  for i = 1, n do products[i] = prod_items(i); accepts[i] = accept_items(i) end
  local function has(list, x) for _, v in ipairs(list) do if v == x then return true end end return false end

  local drops = {}          -- { from = i, to = j, item = nil (objets du producteur) }
  for i, e in ipairs(ents) do
    local s = specs[i]
    if s.kind == "inserter" then
      local r = s.reach
      local px, py = rot(e.dir, 0, -r)
      local dx, dy = rot(e.dir, 0, r + 0.2)
      local a = at(e.x + px, e.y + py)
      local b = at(e.x + dx, e.y + dy)
      if not a then err(label(i) .. " : rien à prendre en (" .. fmt(e.x + px) .. ", " .. fmt(e.y + py) .. ")") end
      if not b then err(label(i) .. " : rien où déposer en (" .. fmt(e.x + dx) .. ", " .. fmt(e.y + dy) .. ")") end
      if a and b then
        local ka, kb = specs[a].kind, specs[b].kind
        local okA = ka == "belt" or ka == "chest" or ka == "assembler" or ka == "furnace"
        local okB = kb == "belt" or kb == "chest" or kb == "assembler" or kb == "furnace" or kb == "lab" or kb == "boiler"
        if not okA then err(label(i) .. " : ne peut pas prendre dans " .. label(a)) end
        if not okB then err(label(i) .. " : ne peut pas déposer dans " .. label(b)) end
        if s.burner and not (kb == "boiler" or kb == "furnace") then err(label(i) .. " : bras à combustion sans charbon à porter (seulement vers une chaudière ou un four)") end
        local cap = s.rate * M.MARGIN * (ka == "belt" and M.BELT_PICKUP or 1)
        links[#links + 1] = { from = a, to = b, cap = cap, via = i }
        if kb == "belt" then
          -- voie : celle du côté du point de dépôt ; un dépôt dans l'axe du tapis est refusé
          local f = ents[b]
          local vx, vy = DV[f.dir][1], DV[f.dir][2]
          local ox_, oy_ = e.x + dx - f.x, e.y + dy - f.y
          local lx, ly = left_of(f.dir)
          local side = ox_ * lx + oy_ * ly
          if math.abs(side) < 0.05 then err(label(i) .. " : dépôt dans l'axe du tapis " .. label(b) .. " (voie indéterminée)")
          else drops[#drops + 1] = { from = a, belt = b, lane = side > 0 and 1 or 2 } end
          if math.abs(ox_ * vx + oy_ * vy) > 0.5 then err(label(i) .. " : dépôt hors du tapis") end
        end
      end
    elseif s.kind == "drill" then
      local dx, dy = rot(e.dir, s.drop[1], s.drop[2])
      local b = at(e.x + dx, e.y + dy)
      if not b then err(label(i) .. " : la foreuse dépose dans le vide en (" .. fmt(e.x + dx) .. ", " .. fmt(e.y + dy) .. ")")
      else
        local kb = specs[b].kind
        if not (kb == "belt" or kb == "chest" or kb == "furnace") then err(label(i) .. " : la foreuse dépose dans " .. label(b)) end
        links[#links + 1] = { from = i, to = b, cap = math.huge, via = i }
        if kb == "belt" then
          local f = ents[b]
          local lx, ly = left_of(f.dir)
          local side = (e.x + dx - f.x) * lx + (e.y + dy - f.y) * ly
          if math.abs(side) < 0.05 then err(label(i) .. " : dépôt dans l'axe du tapis") else drops[#drops + 1] = { from = i, belt = b, lane = side > 0 and 1 or 2, ore = g.resource } end
        end
      end
    end
  end

  -- objets d'un producteur (foreuse : le minerai)
  local function items_of(i)
    if specs[i].kind == "drill" then return { g.resource } end
    return products[i]
  end
  -- propagation des voies
  for _, sd in ipairs(seeds) do add_lane(sd[1], sd[2], sd[3]) end
  local changed = true
  local guard = 0
  while changed and guard < 200 do
    changed, guard = false, guard + 1
    for _, d in ipairs(drops) do
      local src = d.from
      local list
      if is_belt[src] then
        list = {}
        for l = 1, 2 do for _, it in ipairs((function() local t = {} for k in pairs(lanes[src][l]) do t[#t + 1] = k end table.sort(t) return t end)()) do list[#list + 1] = it end end
      elseif specs[src].kind == "chest" then
        list = {}
        local pi = port_of_ent[src]
        if pi and g.ports[pi].item then list = { g.ports[pi].item } end
      else
        list = items_of(src)
      end
      for _, it in ipairs(list) do if add_lane(d.belt, d.lane, it) then changed = true end end
    end
    for _, j in ipairs(belts) do
      for _, f in ipairs(feeders[j]) do
        local a = f.from
        for l = 1, 2 do
          local tl = (f.kind == "side") and f.side or l
          local items = {}
          for k in pairs(lanes[a][l]) do items[#items + 1] = k end
          table.sort(items)
          for _, it in ipairs(items) do if add_lane(j, tl, it) then changed = true end end
        end
      end
    end
  end
  local function lane_list(i, l)
    local t = {}
    for k in pairs(lanes[i][l]) do t[#t + 1] = k end
    table.sort(t)
    return t
  end
  for _, i in ipairs(belts) do
    for l = 1, 2 do
      local t = lane_list(i, l)
      if #t > 1 then err("voie " .. l .. " mêlée sur " .. label(i) .. " : " .. table.concat(t, ", ")) end
    end
  end
  -- les bras qui prennent sur un tapis ne trient rien : un objet utile doit y passer
  local function belt_items(i)
    local seen, t = {}, {}
    for l = 1, 2 do for _, it in ipairs(lane_list(i, l)) do if not seen[it] then seen[it] = true; t[#t + 1] = it end end end
    table.sort(t)
    return t
  end
  local function chest_items(i)
    local pi = port_of_ent[i]
    if pi and g.ports[pi].item then return { g.ports[pi].item } end
    return {}
  end
  local function supply_items(i)
    local k = specs[i].kind
    if k == "belt" then return belt_items(i) end
    if k == "chest" then return chest_items(i) end
    return items_of(i)
  end
  for _, l in ipairs(links) do
    if specs[l.via].kind == "inserter" then
      local useful = false
      local kb = specs[l.to].kind
      for _, it in ipairs(supply_items(l.from)) do
        if kb == "belt" or kb == "chest" or has(accepts[l.to], it) then useful = true end
      end
      if not useful then err(label(l.via) .. " : rien d'utile de " .. label(l.from) .. " vers " .. label(l.to)) end
    end
  end

  -- 8.5 fluides
  local boxes = {}          -- { ent, io, fluid (imposé), pts (absolus), id }
  local box_of_ent = {}
  local function add_box(i, io, fluid, pts, idx)
    local b = { ent = i, io = io, fluid = fluid, pts = pts, idx = idx }
    boxes[#boxes + 1] = b
    box_of_ent[i] = box_of_ent[i] or {}
    box_of_ent[i][#box_of_ent[i] + 1] = #boxes
    return #boxes
  end
  for i, e in ipairs(ents) do
    local s = specs[i]
    if s.kind == "pipe" then
      local pts = {}
      for _, d in ipairs({ N, E, S, W }) do pts[#pts + 1] = { e.x + DV[d][1], e.y + DV[d][2] } end
      add_box(i, "io", nil, pts)
    elseif s.kind == "ptg" then
      add_box(i, "io", nil, { { e.x + DV[e.dir][1], e.y + DV[e.dir][2] } })
    elseif s.kind == "pumpjack" then
      local o = s.outs[e.dir]
      add_box(i, "out", "crude-oil", { { e.x + o[1], e.y + o[2] } })
    elseif s.boxes then
      for bi, bx in ipairs(s.boxes) do
        local pts = {}
        for _, p in ipairs(bx.pts) do local x, y = rot(e.dir, p[1], p[2]); pts[#pts + 1] = { e.x + x, e.y + y } end
        add_box(i, bx.io, bx.fluid, pts, bi)
      end
    end
  end
  local parent = {}
  for b = 1, #boxes do parent[b] = b end
  local function find(x) while parent[x] ~= x do parent[x] = parent[parent[x]]; x = parent[x] end return x end
  local function union(a, b) a, b = find(a), find(b); if a ~= b then if a < b then parent[b] = a else parent[a] = b end end end
  local function in_ent(j, x, y) local k = occ[tkey(math.floor(x), math.floor(y))]; return k == j end
  local connected_pts = {}
  for bi, b in ipairs(boxes) do
    for pi_, p in ipairs(b.pts) do
      local j = at(p[1], p[2])
      if j and j ~= b.ent and box_of_ent[j] then
        for _, bj in ipairs(box_of_ent[j]) do
          for _, q in ipairs(boxes[bj].pts) do
            if in_ent(b.ent, q[1], q[2]) and math.abs(q[1] - p[1]) + math.abs(q[2] - p[2]) <= 1 + M.EPS then
              union(bi, bj)
              connected_pts[bi .. ":" .. pi_] = true
            end
          end
        end
      end
    end
  end
  -- tuyaux souterrains : paire dans l'axe, direction opposée, à 10 tuiles au plus
  for i, e in ipairs(ents) do
    if specs[i].kind == "ptg" then
      local v = DV[e.dir]
      for k = 1, specs[i].max + 1 do
        local j = at(e.x - v[1] * k, e.y - v[2] * k)
        if j and specs[j].kind == "ptg" then
          if ents[j].dir == opposite(e.dir) then union(box_of_ent[i][1], box_of_ent[j][1]) end
          break
        end
      end
    end
  end
  -- affectation des fluides des recettes
  local cons, prods = {}, {}            -- boîte → { fluid, rate }
  for i, e in ipairs(ents) do
    local s = specs[i]
    if s.kind == "assembler" and e.recipe and R[e.recipe] and box_of_ent[i] then
      local r = R[e.recipe]
      local ins, outs = {}, {}
      for _, bi in ipairs(box_of_ent[i]) do
        if boxes[bi].io == "in" then ins[#ins + 1] = bi elseif boxes[bi].io == "out" then outs[#outs + 1] = bi end
      end
      local ni, no = 0, 0
      for _, ing in ipairs(r.ingredients) do
        if ing.fluid then
          ni = ni + 1
          local bi = ins[ing.box or ni]
          if not bi then err(label(i) .. " : pas de raccord d'entrée pour " .. ing.name)
          else cons[bi] = { fluid = ing.name, rate = ing.amount * rate[i] } end
        end
      end
      for _, p in ipairs(r.products) do
        if p.fluid then
          no = no + 1
          local bi = outs[p.box or no]
          if not bi then err(label(i) .. " : pas de raccord de sortie pour " .. p.name)
          else prods[bi] = { fluid = p.name, rate = p.amount * rate[i] } end
        end
      end
    elseif s.kind == "pumpjack" then
      prods[box_of_ent[i][1]] = { fluid = "crude-oil", rate = rate[i] }
    elseif s.kind == "offshore" then
      prods[box_of_ent[i][1]] = { fluid = "water", rate = s.rate, cap = true }
    end
  end
  -- centrale : vapeur demandée par les machines, eau demandée par les chaudières (au prorata)
  local engines, boilers = {}, {}
  for i = 1, n do
    if specs[i].kind == "generator" then engines[#engines + 1] = i elseif specs[i].kind == "boiler" then boilers[#boilers + 1] = i end
  end
  local steam_need = #engines * BASE["steam-engine"].steam
  local boiler_rate = #boilers > 0 and math.min(1, steam_need / (#boilers * BASE.boiler.water)) or 0
  for _, i in ipairs(boilers) do
    rate[i] = boiler_rate
    cons[box_of_ent[i][1]] = { fluid = "water", rate = BASE.boiler.water * boiler_rate }
    prods[box_of_ent[i][2]] = { fluid = "steam", rate = BASE.boiler.water * boiler_rate }
  end
  for _, i in ipairs(engines) do cons[box_of_ent[i][1]] = { fluid = "steam", rate = BASE["steam-engine"].steam } end
  -- ports à fluide
  local port_fluid = {}
  for _, p in ipairs(g.ports) do
    if p.kind == "tuyau" and box_of_ent[p.ent] then
      local bi = box_of_ent[p.ent][1]
      if p.io == "in" then prods[bi] = { fluid = p.fluid, rate = math.huge, port = true } else port_fluid[bi] = p.fluid end
    end
  end
  -- réseaux
  local nets, net_order = {}, {}
  for bi = 1, #boxes do
    local r = find(bi)
    if not nets[r] then nets[r] = { boxes = {}, fluids = {}, supply = 0, demand = 0, port_out = nil }; net_order[#net_order + 1] = r end
    local nt = nets[r]
    nt.boxes[#nt.boxes + 1] = bi
    if prods[bi] then nt.fluids[prods[bi].fluid] = true; nt.supply = nt.supply + prods[bi].rate end
    if port_fluid[bi] then nt.port_out = port_fluid[bi] end
  end
  table.sort(net_order)
  local fluid_nets = {}
  for _, r in ipairs(net_order) do
    local nt = nets[r]
    local fl = {}
    for k in pairs(nt.fluids) do fl[#fl + 1] = k end
    table.sort(fl)
    local need_in = {}
    for _, bi in ipairs(nt.boxes) do
      if cons[bi] then
        need_in[cons[bi].fluid] = (need_in[cons[bi].fluid] or 0) + cons[bi].rate
        nt.demand = nt.demand + cons[bi].rate
      end
    end
    if #fl > 1 then err("fluides mêlés dans un réseau : " .. table.concat(fl, ", ")) end
    local nk = {}
    for k in pairs(need_in) do nk[#nk + 1] = k end
    table.sort(nk)
    for _, f in ipairs(nk) do
      if not nt.fluids[f] then err("réseau sans " .. f .. " pour " .. string.format("%.1f/s", need_in[f]) .. " (aucun producteur raccordé)") end
    end
    if nt.port_out and #fl == 1 and fl[1] ~= nt.port_out then err("port de sortie " .. nt.port_out .. " sur un réseau de " .. fl[1]) end
    if nt.port_out and #fl == 0 then err("port de sortie " .. nt.port_out .. " sans producteur raccordé") end
    if nt.supply + 1e-6 < nt.demand then err(string.format("réseau de %s : offre %.2f/s < demande %.2f/s", fl[1] or "?", nt.supply, nt.demand)) end
    -- R8 : plus long trajet en tuyaux entre deux boîtes non tuyaux du réseau
    local pipes_in = 0
    for _, bi in ipairs(nt.boxes) do local k = specs[boxes[bi].ent].kind; if k == "pipe" or k == "ptg" then pipes_in = pipes_in + 1 end end
    local flow = math.max(nt.demand, 0)
    if nt.port_out then flow = math.max(flow, nt.supply < math.huge and nt.supply or 0) end
    if flow > 0 and flow < math.huge and flow > M.pipe_capacity(math.max(1, pipes_in)) then
      err(string.format("réseau de %s : %.0f/s au-delà de la capacité de %d tuyaux (%.0f/s)", fl[1] or "?", flow, pipes_in, M.pipe_capacity(pipes_in)))
    end
    fluid_nets[#fluid_nets + 1] = { fluid = fl[1], supply = nt.supply, demand = nt.demand, pipes = pipes_in, boxes = #nt.boxes }
    -- entrées et sorties de fluide du module (ports)
    local own = 0
    local has_in = false
    for _, bi in ipairs(nt.boxes) do
      if prods[bi] then if prods[bi].port then has_in = true else own = own + prods[bi].rate end end
    end
    if #fl == 1 then
      if has_in and nt.demand > own + 1e-9 then nt.fluid_in = nt.demand - own end
      if nt.port_out and own > nt.demand + 1e-9 then nt.fluid_out = own - nt.demand end
      nt.fluid = fl[1]
    end
  end
  -- toute boîte de recette doit être raccordée (une machine ne reçoit rien sinon)
  for bi = 1, #boxes do
    local c, p = cons[bi], prods[bi]
    if c and #nets[find(bi)].boxes == 1 then err(label(boxes[bi].ent) .. " : entrée de " .. c.fluid .. " non raccordée") end
    if p and not p.port and #nets[find(bi)].boxes == 1 then err(label(boxes[bi].ent) .. " : sortie de " .. p.fluid .. " non raccordée") end
  end

  -- 8.6 électricité
  local poles, consumers = {}, {}
  for i = 1, n do
    local s = specs[i]
    if s.kind == "pole" then poles[#poles + 1] = i
    elseif M.power_kw(ents[i].name) > 0 or s.kind == "generator" then consumers[#consumers + 1] = i end
  end
  local power = 0
  for _, i in ipairs(consumers) do power = power + M.power_kw(ents[i].name) end
  for _, i in ipairs(consumers) do
    local x0, y0, x1, y1 = rect(ents[i])
    local ok = false
    for _, p in ipairs(poles) do
      local s = specs[p].supply
      local e = ents[p]
      if math.min(x1, e.x + s) - math.max(x0, e.x - s) > M.EPS and math.min(y1, e.y + s) - math.max(y0, e.y - s) > M.EPS then ok = true; break end
    end
    if not ok then err(label(i) .. " : hors de l'aire des poteaux") end
  end
  if #poles > 0 then
    local comp = {}
    local stack = { poles[1] }
    comp[poles[1]] = true
    while #stack > 0 do
      local a = table.remove(stack)
      for _, b in ipairs(poles) do
        if not comp[b] then
          local dx, dy = ents[a].x - ents[b].x, ents[a].y - ents[b].y
          if math.sqrt(dx * dx + dy * dy) <= math.min(specs[a].wire, specs[b].wire) + M.EPS then comp[b] = true; stack[#stack + 1] = b end
        end
      end
    end
    for _, p in ipairs(poles) do if not comp[p] then err(label(p) .. " : poteau isolé (hors de portée des fils)") end end
    if not g.power_pole or not specs[g.power_pole] or specs[g.power_pole].kind ~= "pole" then err("poteau de raccordement (power_pole) absent") end
  elseif #consumers > 0 then
    err("bâtiments électriques sans aucun poteau")
  end

  -- 8.7 ports
  local function edge_tile(i)
    local x0, y0, x1, y1 = rect(ents[i])
    return x0 < M.EPS or y0 < M.EPS or x1 > W_ - M.EPS or y1 > H_ - M.EPS
  end
  for pi, p in ipairs(g.ports) do
    local i = p.ent
    if not ents[i] then err("port " .. pi .. " : entité absente")
    else
      local e, s = ents[i], specs[i]
      if p.kind == "tapis" then
        if s.kind ~= "belt" then err("port " .. pi .. " : pas un tapis")
        else
          local v = DV[e.dir]
          local function outside_pt(x, y) return x < 0 or y < 0 or x > W_ or y > H_ end
          if p.io == "in" then
            if not outside_pt(e.x - v[1], e.y - v[2]) then err("port " .. pi .. " (tapis d'entrée) : l'amont n'est pas hors de l'emprise") end
          elseif not outside_pt(e.x + v[1], e.y + v[2]) then
            err("port " .. pi .. " (tapis de sortie) : l'aval n'est pas hors de l'emprise")
          end
        end
      elseif p.kind == "tuyau" then
        local out = false
        for _, bi in ipairs(box_of_ent[i] or {}) do
          for _, q in ipairs(boxes[bi].pts) do if q[1] < 0 or q[2] < 0 or q[1] > W_ or q[2] > H_ then out = true end end
        end
        if not out then err("port " .. pi .. " (tuyau) : aucun raccord vers l'extérieur") end
      elseif p.kind == "four" or p.kind == "quai" then
        if not edge_tile(i) then err("port " .. pi .. " (" .. p.kind .. ") : pas au bord") end
      elseif p.kind == "rive" then
        if s.kind ~= "offshore" then err("port " .. pi .. " (rive) : pas une pompe de rive") end
        local vx, vy = rot(e.dir, 0, -1)
        local wx, wy = e.x + vx, e.y + vy
        if inside(wx, wy) and wx > 0 and wy > 0 and wx < W_ and wy < H_ then err("port " .. pi .. " (rive) : l'eau serait dans l'emprise") end
        local seen = false
        for _, t in ipairs(g.water or {}) do if t[1] == math.floor(wx) and t[2] == math.floor(wy) then seen = true end end
        if not seen then err("port " .. pi .. " (rive) : tuile d'eau devant la pompe non déclarée") end
      end
    end
  end

  -- 8.8 flots d'objets (flot maximal par objet)
  local items_set, items = {}, {}
  local function addi(x) if x and not items_set[x] then items_set[x] = true; items[#items + 1] = x end end
  for i = 1, n do for _, x in ipairs(products[i]) do addi(x) end; for _, x in ipairs(accepts[i]) do addi(x) end end
  if g.resource and M.ORES[g.resource] then addi(g.resource) end
  for _, p in ipairs(g.ports) do if p.lanes then addi(p.lanes[1]); addi(p.lanes[2]) end; addi(p.item) end
  table.sort(items)
  -- besoins et productions par entité
  local function need_of(i, it)
    local e, s = ents[i], specs[i]
    local t = 0
    if (s.kind == "assembler" or s.kind == "furnace") and e.recipe and R[e.recipe] then
      for _, ing in ipairs(R[e.recipe].ingredients) do if not ing.fluid and ing.name == it then t = t + ing.amount * rate[i] end end
    elseif s.kind == "lab" and g.labs and has(g.labs.packs, it) then t = t + rate[i]
    end
    if it == "coal" and fuel_burner(s) then
      local util = 1
      local mr = max_rate(ents[i])
      if s.kind == "boiler" then util = rate[i] elseif mr > 0 then util = rate[i] / mr end
      t = t + s.burner_kw / M.COAL_J * util
    end
    return t
  end
  local function prod_of(i, it)
    local e, s = ents[i], specs[i]
    if s.kind == "drill" then return it == g.resource and rate[i] or 0 end
    if (s.kind == "assembler" or s.kind == "furnace") and e.recipe and R[e.recipe] then
      local t = 0
      for _, p in ipairs(R[e.recipe].products) do if not p.fluid and p.name == it then t = t + p.amount * rate[i] end end
      return t
    end
    return 0
  end
  local outputs, inputs = {}, {}
  local fuel_by_port = {}
  for _, f in ipairs(g.fuel_ports or {}) do fuel_by_port[f] = true end
  local lane_report = {}
  for _, it in ipairs(items) do
    local produced, consumed = 0, 0
    for i = 1, n do produced = produced + prod_of(i, it); consumed = consumed + need_of(i, it) end
    local net = produced - consumed
    if net > 1e-9 then outputs[it] = net elseif net < -1e-9 then inputs[it] = -net end
  end
  -- répartition des sorties sur les ports de sortie (objets des voies ou du four)
  local out_ports = {}
  for pi, p in ipairs(g.ports) do
    if p.io == "out" and (p.kind == "tapis" or p.kind == "four" or p.kind == "quai") then
      local list = {}
      if p.kind == "tapis" and is_belt[p.ent] then
        for l = 1, 2 do lane_report[pi] = lane_report[pi] or {}; lane_report[pi][l] = lane_list(p.ent, l) end
        list = belt_items(p.ent)
      elseif p.item then list = { p.item } end
      out_ports[#out_ports + 1] = { pi = pi, ent = p.ent, items = list }
    end
  end
  for pi, p in ipairs(g.ports) do
    if p.io == "in" and p.kind == "tapis" and is_belt[p.ent] then
      lane_report[pi] = { lane_list(p.ent, 1), lane_list(p.ent, 2) }
    end
  end
  local okeys = {}
  for k in pairs(outputs) do okeys[#okeys + 1] = k end
  table.sort(okeys)
  for _, it in ipairs(okeys) do
    local any = false
    for _, op in ipairs(out_ports) do if has(op.items, it) then any = true end end
    if not any then err("produit sans port de sortie : " .. it .. string.format(" (%.3f/s)", outputs[it])) end
  end
  for _, op in ipairs(out_ports) do
    for _, it in ipairs(op.items) do
      if not outputs[it] then err("port " .. op.pi .. " : « " .. it .. " » sortirait du module sans être un produit net") end
    end
  end
  local ikeys = {}
  for k in pairs(inputs) do ikeys[#ikeys + 1] = k end
  table.sort(ikeys)
  for _, it in ipairs(ikeys) do
    local any = false
    for _, p in ipairs(g.ports) do
      if p.io == "in" and ((p.lanes and has(p.lanes, it)) or p.item == it) then any = true end
    end
    if it == "coal" and #(g.fuel_ports or {}) > 0 then any = true end
    if g.resource == it then any = true end
    if not any then err("besoin sans port d'entrée : " .. it .. string.format(" (%.3f/s)", inputs[it])) end
  end
  -- flot maximal objet par objet
  local flow_report = {}
  for _, it in ipairs(items) do
    local S_, T_ = n + 1, n + 2
    local edges, demand = {}, 0
    for i = 1, n do
      local p = prod_of(i, it)
      if p > 0 then edges[#edges + 1] = { S_, i, p } end
      local c = need_of(i, it)
      if c > 0 then
        if it == "coal" and fuel_by_port[i] then
          -- ravitaillé par les porteurs (port « combustible »)
        else
          edges[#edges + 1] = { i, T_, c }; demand = demand + c
        end
      end
    end
    for _, p in ipairs(g.ports) do
      if p.io == "in" and p.kind == "tapis" and is_belt[p.ent] and p.lanes then
        local c = 0
        for l = 1, 2 do if p.lanes[l] == it then c = c + M.LANE_RATE end end
        if c > 0 then edges[#edges + 1] = { S_, p.ent, c } end
      elseif p.io == "in" and p.kind == "quai" and p.item == it then
        edges[#edges + 1] = { S_, p.ent, 1e9 }
      end
    end
    -- sorties : la part nette de l'objet doit atteindre un port de sortie
    if outputs[it] then
      local cand = {}
      for _, op in ipairs(out_ports) do if has(op.items, it) then cand[#cand + 1] = op end end
      for _, op in ipairs(cand) do edges[#edges + 1] = { op.ent, T_, 1e9 } end
      demand = demand + outputs[it]
    end
    for _, l in ipairs(links) do
      local kb = specs[l.to].kind
      local can_take = false
      for _, x in ipairs(supply_items(l.from)) do if x == it then can_take = true end end
      if can_take and (kb == "belt" or kb == "chest" or has(accepts[l.to], it)) then
        edges[#edges + 1] = { l.from, l.to, l.cap }
      end
    end
    for _, j in ipairs(belts) do
      for _, f in ipairs(feeders[j]) do
        local carries = false
        for l = 1, 2 do if lanes[f.from][l][it] then carries = true end end
        if carries then edges[#edges + 1] = { f.from, j, f.kind == "side" and M.LANE_RATE or M.BELT_RATE } end
      end
    end
    if demand > 1e-9 then
      local f = maxflow(n + 2, edges, S_, T_)
      flow_report[#flow_report + 1] = { item = it, demand = demand, flow = f }
      if f + 1e-6 < demand then err(string.format("débit de %s : %.3f/s acheminés sur %.3f/s demandés (bras, tapis ou liaisons trop faibles)", it, f, demand)) end
    end
  end

  -- fluides entrant et sortant par les ports (après les contrôles propres aux objets)
  for _, r in ipairs(net_order) do
    local nt = nets[r]
    if nt.fluid_in then inputs[nt.fluid] = (inputs[nt.fluid] or 0) + nt.fluid_in end
    if nt.fluid_out then outputs[nt.fluid] = (outputs[nt.fluid] or 0) + nt.fluid_out end
  end

  -- 8.9 points d'appui
  for i, e in ipairs(ents) do
    local best = math.huge
    for _, a in ipairs(g.anchors) do
      local dx, dy = e.x - a.x, e.y - a.y
      best = math.min(best, math.sqrt(dx * dx + dy * dy))
    end
    if best > M.BUILD_DISTANCE + M.EPS then err(label(i) .. string.format(" : à %.1f tuiles du point d'appui le plus proche (> %d)", best, M.BUILD_DISTANCE)) end
  end
  for ai, a in ipairs(g.anchors) do
    local inside_lot = a.x > 0 and a.x < W_ and a.y > 0 and a.y < H_
    local far = a.x < -M.STREET or a.y < -M.STREET or a.x > W_ + M.STREET or a.y > H_ + M.STREET
    if inside_lot or far then err("point d'appui " .. ai .. " hors de la rue") end
  end

  -- 8.10 époque, recettes à débloquer, électricité produite
  local idx = epoch_index()
  local epoch, why = 1, "départ"
  local unlocks, useen = {}, {}
  local function bump(e, w) if e and e > epoch then epoch, why = e, w end end
  local electric = false
  for i, e in ipairs(ents) do
    local base = specs[i].base or e.name
    local ep = epoch_of_name(e.name, idx)
    if ep == nil then err("époque inconnue (X0) pour " .. e.name) end
    bump(ep, e.name)
    if not useen[base] then useen[base] = true; unlocks[#unlocks + 1] = base end
    if e.recipe and not useen[e.recipe] then
      useen[e.recipe] = true
      unlocks[#unlocks + 1] = e.recipe
      if idx[e.recipe] then bump(idx[e.recipe], e.recipe) end
    end
    if M.power_kw(e.name) > 0 then electric = true end
  end
  if electric then bump(idx["steam-engine"], "électricité (vapeur)") end
  table.sort(unlocks)
  local elec_out = 0
  for _ in ipairs(engines) do elec_out = elec_out + BASE["steam-engine"].power_out end
  if #engines > 0 then outputs["electricity-kw"] = elec_out end

  -- boîtes à fluide raccordées (pour le recoupement en moteur réel : un même réseau ⇔ un même système de fluide)
  local box_report = {}
  for bi, b in ipairs(boxes) do
    local r = find(bi)
    if #nets[r].boxes >= 2 then box_report[#box_report + 1] = { ent = b.ent, idx = b.idx or 1, net = r, pts = b.pts } end
  end

  return {
    errors = errors, outputs = outputs, inputs = inputs, power_kw = power, epoch = epoch, epoch_why = why,
    unlocks = unlocks, lanes = lane_report, fluid_nets = fluid_nets, flows = flow_report, electric_out_kw = elec_out,
    rates = rate, boxes = box_report,
  }
end

--- Contrôle d'un gabarit : liste d'erreurs (vide si le gabarit est bon), plus l'écart entre ce qui est déclaré
--- (nominal, puissance, époque, entrées) et ce que l'analyse recalcule.
function M.check(g)
  local rep = M.analyze(g)
  local errs = rep.errors
  local function cmp(a, b, what)
    local ka = {}
    for k in pairs(a or {}) do ka[#ka + 1] = k end
    for k in pairs(b or {}) do if not (a or {})[k] then ka[#ka + 1] = k end end
    table.sort(ka)
    local last
    for _, k in ipairs(ka) do
      if k ~= last then
        local x, y = (a or {})[k] or 0, (b or {})[k] or 0
        if math.abs(x - y) > 1e-6 * math.max(1, math.abs(y)) then errs[#errs + 1] = string.format("%s de %s déclaré %.4f, recalculé %.4f", what, k, x, y) end
      end
      last = k
    end
  end
  -- un gabarit écrit à la main ou converti (bp2lua) sans nominal déclaré : seule l'analyse compte
  if g.nominal then cmp(g.nominal, rep.outputs, "débit nominal") end
  if g.inputs then cmp(g.inputs, rep.inputs, "entrée") end
  if g.power_kw and math.abs(g.power_kw - rep.power_kw) > 1e-6 then errs[#errs + 1] = string.format("puissance déclarée %.1f kW, recalculée %.1f", g.power_kw, rep.power_kw) end
  if g.epoch and g.epoch ~= rep.epoch then errs[#errs + 1] = "époque déclarée " .. g.epoch .. ", recalculée " .. rep.epoch end
  return errs, rep
end

--- Fils à poser entre les poteaux (arbre couvrant, plus courts d'abord, puis indices) : { {i, j} }.
function M.wires(g)
  local poles = {}
  for i, e in ipairs(g.entities) do if M.spec(e.name).kind == "pole" then poles[#poles + 1] = i end end
  local cand = {}
  for a = 1, #poles do
    for b = a + 1, #poles do
      local ea, eb = g.entities[poles[a]], g.entities[poles[b]]
      local dx, dy = ea.x - eb.x, ea.y - eb.y
      local d = math.sqrt(dx * dx + dy * dy)
      if d <= math.min(M.spec(ea.name).wire, M.spec(eb.name).wire) + M.EPS then cand[#cand + 1] = { d, poles[a], poles[b] } end
    end
  end
  table.sort(cand, function(x, y)
    if math.abs(x[1] - y[1]) > M.EPS then return x[1] < y[1] end
    if x[2] ~= y[2] then return x[2] < y[2] end
    return x[3] < y[3]
  end)
  local parent = {}
  for _, p in ipairs(poles) do parent[p] = p end
  local function find(x) while parent[x] ~= x do x = parent[x] end return x end
  local out = {}
  for _, c in ipairs(cand) do
    local ra, rb = find(c[2]), find(c[3])
    if ra ~= rb then parent[rb] = ra; out[#out + 1] = { c[2], c[3] } end
  end
  return out
end

--- Sérialisation canonique d'un gabarit (clés triées) : déterminisme et empreinte.
function M.serialize(v)
  local t = type(v)
  if t == "table" then
    local ks = {}
    for k in pairs(v) do ks[#ks + 1] = k end
    table.sort(ks, function(a, b)
      local ta, tb = type(a), type(b)
      if ta ~= tb then return ta < tb end
      return a < b
    end)
    local parts = {}
    for _, k in ipairs(ks) do parts[#parts + 1] = tostring(k) .. "=" .. M.serialize(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif t == "number" then
    return string.format("%.10g", v)
  end
  return tostring(v)
end

return M
