--[[
  Lot INDUSTRIE I5 « patrons » (PLAN INDUSTRIE §2) : la FAMILLE de gabarits qui fabrique n'importe quel objet à partir du
  nombre de ses entrées, sans qu'aucun nom d'objet, de machine ou de recette soit écrit ici. Lua PUR : aucune API du jeu ;
  les noms viennent des arguments (recette lue par le lot I4, machine et kit lus par le lot I4), jamais du code.

  Une règle, deux assemblages (décision 1 du plan) :
    - la CELLULE (P.cellule, générateur `patron` de shared/team/modules.lua) : n machines d'UNE recette en rangée ;
        solides s : 1-2 → 1 tapis au nord, bras normal ; 3-4 → 2 tapis au nord (bras normal sur le tapis proche, bras long
        sur l'autre) ; 5-6 → 2 au nord + 1 au sud ; 7-8 → 2 au nord + 2 au sud. Une voie ne porte qu'UN objet (le contrôle
        du lot IA1-c refuse les voies mêlées) : 2 objets par tapis, d'où 8 entrées au plus. Un bras ne prend que ce que la
        machine demande : les voies sont partagées sans filtre.
        Entrées : les tapis impairs entrent par l'EST, les pairs par l'OUEST (P.cote_tapis) : la tête d'alimentation d'un port
        (P.feeder du plan directeur : 3 tuiles derrière, 2 de chaque côté) ne tient pas à côté de celle d'un tapis voisin. Les
        têtes mangent la largeur du lot (24 − 3 par côté ouvert) : le nombre de machines d'une rangée et du bloc en dépend.
        Sortie : s ≤ 4 → au sud (tapis ou coffre) ; s ≥ 5 → à l'est (bras + coffre), une machine seule, jamais en tapis (il
        croiserait ceux du sud) ; `unite` : aucun bras ni coffre, la machine elle-même est le quai (le balayage de script la vide :
        lot ROBOTS). Plusieurs produits solides : coffre seul, jamais de tapis (voies mêlées).
        Cadence : ce que les bras du kit tiennent (la machine tourne moins vite que son maximum quand ils ne suffisent pas) ;
        le débit nominal du gabarit le dit.
        Fluides en entrée : tuyaux posés sur les raccords lus aux boîtes de la machine, tournée (F91 : direction et recette
        se donnent à la pose) pour que ses entrées regardent l'ouest, ou l'est ; une machine seule ; sortie en fluide refusée.
    - le BLOC de mall (P.bloc) : des recettes DIFFÉRENTES, une machine par objet, de part et d'autre de 2 tapis communs
        (4 voies, donc 4 objets d'entrée au plus pour tout le bloc), sortie en coffre avec barre (le bras s'arrête seul
        quand la barre est atteinte : F95). P.groups range des objets en blocs (glouton déterministe).
    - le RUBAN de mall (P.ruban, lot MALL-RUE) : le bloc sur la géométrie de Mp.pattern quand la demande dépasse un lot : son
        corridor continue de section en section, la rue franchie par un souterrain (§6 bis).
  Rendu : un gabarit M ordinaire (`gen`, `args`, ports, `nominal`, `inputs`) : M.analyze, M.check, M.regenerate, M.extend
  et P.fit s'y appliquent sans changement. Dupliquer = mêmes `gen` et `args` sur un autre lot.

  Dans shared/team/modules.lua : `M.new_builder` (le constructeur prêté à cette règle) et les générateurs `patron` et `bloc`
  (4 lignes, voir le rapport I5). P.declare, P.def_machine et P.declare_kit sont la pièce du « résolveur injecté » du plan §1 :
  elles apprennent à M une machine ou une pièce du kit que M.BASE ne connaît pas (un mod) d'après le relevé de lecture du lot I4.

  Refus : (nil, raison) dont la raison commence par « limite : » (même convention que shared/ai3/lecture.lua), jamais
  silencieux. Déterminisme : listes triées, aucun pairs décisionnel, aucune trigonométrie, aucune fonction dans un gabarit.
]]

local P = {}

P.MAX_SOLIDES = 8   -- 4 tapis × 2 voies (L.MAX_SOLIDES du lot I4)
P.LOT = 24          -- lot du treillis (shared/team/plan.lua, P.LOT : le test les compare)
P.MARGE = 1         -- tuiles libres entre l'emprise et les rues (P.fit)
P.TETE = 3          -- profondeur d'une tête d'alimentation derrière un port d'entrée (plan.lua, P.FEED_DEPTH)
P.TETE_LARGEUR = 2  -- tuiles de chaque côté de l'axe d'un port d'entrée que la tête réserve (bras et coffre du quai)
P.SORTIE = 2        -- tuiles réservées devant un port de sortie en tapis (le quai de sortie)
P.MAX_N = 64        -- nombre de machines d'une rangée au plus (même plafond que shared/team/modules.lua)
P.SORTIES = { "tapis", "coffre", "unite" }
P.BLOC_VOIES = 4    -- 2 tapis communs × 2 voies

local N, E, S, W = 0, 2, 4, 6

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local EPS = 1e-9

local function fail(fmt, ...) return nil, "limite : " .. string.format(fmt, ...) end
local function floor_eps(x) return floor(x + EPS) end

---------------------------------------------------------------------------------------------------
-- 1. Topologie : (s, fluides, sortie) → forme, sans rien nommer
---------------------------------------------------------------------------------------------------
--- Forme d'une cellule pour `s` entrées solides. Rend { s, belts, nord, sud, cote }:
---   belts = nombre de tapis (2 voies chacun) ; nord / sud = tapis de chaque côté ; cote = côté de la sortie
---   ("sud" pour s ≤ 4, "est" au-delà : les tapis du sud occupent la rangée du dessous) ; ou (nil, raison).
function P.topologie(s, sortie)
  if type(s) ~= "number" or s < 0 or s ~= floor(s) then return fail("nombre d'entrées invalide (%s)", tostring(s)) end
  if s > P.MAX_SOLIDES then return fail("%d entrées solides (%d au plus)", s, P.MAX_SOLIDES) end
  local nb = ceil(s / 2)
  local nord = min(nb, 2)
  local sud = nb - nord
  local cote = "sud"
  if sud > 0 then cote = "est" end
  if sortie == "unite" then cote = "aucun" end
  return { s = s, belts = nb, nord = nord, sud = sud, cote = cote }
end

--- Les `s` entrées dans les tapis : liste de tapis, chacun { objets… } (2 au plus), rangés par demande décroissante puis
--- par nom (les égalités se départagent par le nom : l'isomorphisme n'est exact qu'aux égalités près, PLAN §8.8).
function P.voies(solides)
  local list = {}
  for i, it in ipairs(solides) do list[i] = it end
  table.sort(list, function(a, b)
    if a.demande ~= b.demande then return a.demande > b.demande end
    return a.name < b.name
  end)
  local belts = {}
  for i, it in ipairs(list) do
    local k = ceil(i / 2)
    belts[k] = belts[k] or {}
    belts[k][#belts[k] + 1] = it
  end
  return belts
end

--- Côté du module par où entre le tapis `k` (1 = le plus proche des bras) : les tapis impairs par l'est, les pairs par l'ouest
--- (l'inverse quand un fluide entre par l'est). Deux tapis voisins entrent ainsi de côtés OPPOSÉS : la tête d'alimentation d'un
--- port (P.feeder du plan directeur : 3 tuiles derrière, 2 de chaque côté, bras et coffre de quai) ne tiendrait pas à côté de la
--- tête du tapis voisin. Mesuré à la main sur P.feeder : 4 conflits dès que 2 ports voisins ouvrent du même côté.
function P.cote_tapis(k, cote_fluide)
  local est = (k % 2 == 1)
  if cote_fluide == "est" then est = not est end
  return est and "est" or "ouest"
end

---------------------------------------------------------------------------------------------------
-- 2. Résolveur injecté : machines et pièces du kit que M.BASE ne connaît pas (un mod)
---------------------------------------------------------------------------------------------------
--- Cadence d'un bras (objets/s, coffre à coffre, pile de 1) d'après sa vitesse de rotation (tours par tick) : 58 × rot,
--- ESTIMATION prudente (0,81 pour 0,014 : le wiki donne 0,83 ; 1,16 pour 0,02 : 1,15 ; 2,32 pour 0,04 : 2,31).
function P.arm_rate(rot)
  if type(rot) ~= "number" or rot <= 0 then return nil end
  return floor(58 * rot * 100 + 1e-6) / 100
end

--- Déclare à `M` (shared/team/modules.lua) une machine ou une pièce du kit inconnue. `def` : table du type M.BASE
--- (`kind` = une des sortes de M.BASE : machine d'assemblage, four, bras, tapis, coffre, poteau, tuyau ; machine : w, h, speed,
--- categories, usage_kw, boxes ; bras : rate, reach, power ; poteau : supply, wire). Idempotent : un nom déjà connu n'est pas
--- écrasé ; une machine DÉCLARÉE ici gagne en revanche les catégories nouvelles d'un second appel (la lecture donne une machine
--- par recette, donc une catégorie à la fois). L'époque (X0) d'un nom inconnu est 1 : la place du mod dans les ères n'est pas
--- l'affaire de ce lot.
function P.declare(M, name, def)
  if type(name) ~= "string" or type(def) ~= "table" or not def.kind then return nil, "limite : déclaration invalide" end
  if M.BASE[name] == nil then
    local o = {}
    for k, v in pairs(def) do o[k] = v end
    o.w, o.h = o.w or 1, o.h or 1
    if (o.kind == "assembler" or o.kind == "furnace") then
      o.usage_kw = o.usage_kw or 100
      o.drain = (o.drain == nil) and true or o.drain
    end
    if o.categories then
      local cats = {}
      for i, c in ipairs(o.categories) do cats[i] = c end
      table.sort(cats)
      o.categories = cats
    end
    o.declared = true
    M.BASE[name] = o
  elseif M.BASE[name].declared and def.categories then
    local have = {}
    for _, c in ipairs(M.BASE[name].categories or {}) do have[c] = true end
    local cats = M.BASE[name].categories or {}
    for _, c in ipairs(def.categories) do
      if not have[c] then have[c] = true; cats[#cats + 1] = c end
    end
    table.sort(cats)
    M.BASE[name].categories = cats
  end
  local idx = M.epoch_index()
  if idx[name] == nil then idx[name] = 1 end
  return true
end

--- Définition (pour P.declare) d'une machine du relevé de lecture (lot I4 : cat.fab[recette].machines[i] = { entity, type, speed,
--- w, h, energy, boxes = { { type = "input" | "output" | "input-output", conns = { [0] = { { x, y } } } } } }) ; `categories` :
--- celles que la lecture lui donne (la catégorie de la recette). Toute machine est une machine d'assemblage pour le modèle
--- (le contrôle des catégories est celui de la lecture, pas une règle du four) ; une machine à combustible se reconnaît à son
--- énergie (le patron la refuse : le combustible n'est pas une entrée). Les boîtes à fluide sont lues pour la machine tournée au
--- nord (conns[0]) ; une boîte entrée-sortie est gardée en « io » (jamais prise pour une entrée de recette).
function P.def_machine(m, categories)
  local boxes = {}
  for _, bx in ipairs(m.boxes or {}) do
    local c = bx.conns and bx.conns[0] and bx.conns[0][1]
    if c then
      local io = (bx.type == "input" and "in") or (bx.type == "output" and "out") or "io"
      boxes[#boxes + 1] = { io = io, pts = { { c[1] or c.x, c[2] or c.y } } }
    end
  end
  local def = { kind = "assembler", w = m.w, h = m.h, speed = m.speed, categories = categories, boxes = (#boxes > 0) and boxes or nil }
  if m.energy == "burner" then def.burner_kw = 1 end
  return def
end

--- Définitions des pièces du kit lues (lot I4 : cat.kit() = { bras, bras_long, tapis, coffre, poteau } ; chaque pièce
--- { entity, reach, rot, energy, slots, supply, wire }) : P.declare à chacune ; rend la table { bras, bras_long, tapis, coffre,
--- poteau } des NOMS D'ENTITÉS que P.cellule et P.bloc attendent, ou (nil, raison). Le tuyau n'est pas dans le kit lu : l'appelant
--- ajoute `tuyau` (une pièce de type tuyau déclarée) quand il demande des fluides.
function P.declare_kit(M, kit)
  -- la sorte d'un bras dans le modèle : celle de la première pièce de M.BASE (noms triés) qui a une portée et une cadence
  local arm_kind
  local names = {}
  for k in pairs(M.BASE) do names[#names + 1] = k end
  table.sort(names)
  for _, k in ipairs(names) do
    local sp = M.BASE[k]
    if not arm_kind and type(sp.reach) == "number" and type(sp.rate) == "number" then arm_kind = sp.kind end
  end
  local out = {}
  for _, k in ipairs({ "bras", "bras_long", "tapis", "coffre", "poteau" }) do
    local c = kit and kit[k]
    if not c or not c.entity then return fail("kit lu sans « %s »", k) end
    local def
    if k == "bras" or k == "bras_long" then
      local rate = P.arm_rate(c.rot)
      if not rate then return fail("bras « %s » sans vitesse de rotation", tostring(c.entity)) end
      def = { kind = arm_kind, rate = rate, reach = c.reach, power = 13.6 }
      if c.energy == "burner" then def.burner = true end
    elseif k == "tapis" then
      def = { kind = "belt" }
    elseif k == "coffre" then
      def = { kind = "chest", slots = c.slots }
    else
      def = { kind = "pole", supply = c.supply, wire = c.wire }
    end
    local ok, why = P.declare(M, c.entity, def)
    if not ok then return nil, why end
    out[k] = c.entity
  end
  return out
end

--- Déclaration portée par les arguments d'un patron : `decl` = { kit = pièces lues, machines = { { machine = machine lue, categories } } }.
--- Idempotente ; `decl` absent : rien. M.BASE est reconstruit à chaque chargement : elle ne peut pas venir d'un état en mémoire.
function P.redeclare(M, decl)
  if type(decl) ~= "table" then return end
  if decl.kit then P.declare_kit(M, decl.kit) end
  for _, d in ipairs(decl.machines or {}) do
    P.declare(M, d.machine.entity, P.def_machine(d.machine, d.categories))
  end
end

---------------------------------------------------------------------------------------------------
-- 3. Recette : modèle de calcul et enregistrement dans M.RECIPES
---------------------------------------------------------------------------------------------------
--- Recette lue (table du relevé : name, category, energy | time, ingredients, products) → modèle de la cellule.
function P.modele(M, rec)
  if type(rec) ~= "table" or type(rec.name) ~= "string" then return nil, "limite : recette sans nom" end
  local time = rec.time or rec.energy or 0.5
  if type(time) ~= "number" or time <= 0 then return fail("%s sans durée", rec.name) end
  local solids, fin, prods, fout = {}, {}, {}, 0
  local ings, outs = {}, {}
  for _, i in ipairs(rec.ingredients or {}) do
    local name, amount = i.name or i[1], i.amount or i[2] or 1
    local fluid = (i.type == "fluid") or (i.fluid == true)
    ings[#ings + 1] = { name = name, amount = amount, fluid = fluid or nil }
    if fluid then fin[#fin + 1] = { name = name, amount = amount } else solids[#solids + 1] = { name = name, amount = amount } end
  end
  for _, q in ipairs(rec.products or {}) do
    local name, amount = q.name or q[1], q.amount or q[2] or 1
    local fluid = (q.type == "fluid") or (q.fluid == true)
    outs[#outs + 1] = { name = name, amount = amount, fluid = fluid or nil }
    if fluid then fout = fout + 1 else prods[#prods + 1] = { name = name, amount = amount } end
  end
  if #solids + #fin == 0 then return fail("%s n'a aucune entrée", rec.name) end
  if fout > 0 then return fail("%s : sortie en fluide (hors patron)", rec.name) end
  if #prods == 0 then return fail("%s ne produit aucun objet", rec.name) end
  -- produits NETS (une recette qui rend un de ses ingrédients, comme l'enrichissement cyclique, n'en sort que le surplus)
  local nets = {}
  for _, p in ipairs(prods) do
    local used = 0
    for _, i in ipairs(solids) do if i.name == p.name then used = used + i.amount end end
    if p.amount - used > EPS then nets[#nets + 1] = p.name end
  end
  if #nets == 0 then return fail("%s ne produit aucun objet net", rec.name) end
  if not M.RECIPES[rec.name] then
    M.RECIPES[rec.name] = { name = rec.name, category = rec.category or "crafting", time = time, ingredients = ings, products = outs }
  end
  return { name = rec.name, category = rec.category or "crafting", time = time, solids = solids, fin = fin, prods = prods, nets = nets }
end

---------------------------------------------------------------------------------------------------
-- 4. Contrôles d'arguments
---------------------------------------------------------------------------------------------------
local function check_kit(M, kit, need_pipe)
  if type(kit) ~= "table" then return nil, "limite : kit absent" end
  -- Les pièces se reconnaissent à leur forme dans le modèle (une portée et une cadence pour un bras, une sorte « belt » ou
  -- « chest », une seule tuile pour un tuyau), jamais à un nom du jeu.
  local function piece(key, kind, reach)
    local sp = kit[key] and M.spec(kit[key])
    if not sp then return fail("kit : « %s » (%s) inconnu du gabarit (P.declare)", tostring(kit[key]), key) end
    if kind and sp.kind ~= kind then return fail("kit : « %s » n'est pas de la sorte « %s »", tostring(kit[key]), kind) end
    if reach then
      if type(sp.rate) ~= "number" then return fail("kit : « %s » (%s) n'est pas un bras (aucune cadence)", tostring(kit[key]), key) end
      if sp.reach ~= reach then return fail("kit : « %s » a une portée de %s, il faut %d", tostring(kit[key]), tostring(sp.reach), reach) end
    end
    if key == "tuyau" and not (sp.w == 1 and sp.h == 1) then return fail("kit : « %s » (tuyau) n'a pas une tuile", tostring(kit[key])) end
    return true
  end
  for _, c in ipairs({ { "bras", nil, 1 }, { "bras_long", nil, 2 }, { "tapis", "belt" }, { "coffre", "chest" } }) do
    local ok, why = piece(c[1], c[2], c[3])
    if not ok then return nil, why end
  end
  if need_pipe then
    local ok, why = piece("tuyau")
    if not ok then return nil, why end
  end
  return true
end

--- Période des tuiles libres d'une rangée de bras : la couverture du poteau (distance de son aire, en tuiles) arrondie en
--- bas, plus un. Poteau moyen (3,5) : 4, donc tout bras est à 3 tuiles au plus d'une tuile libre.
function P.periode(supply)
  if type(supply) ~= "number" or supply < 1 then return 4 end
  return max(2, floor(supply + EPS) + 1)
end

--- Colonnes d'une rangée de `width` tuiles où un bras peut aller : une tuile sur `period` (la dernière du motif) reste
--- libre pour un poteau ; une rangée de 3 ou moins en garde une, la dernière. Un module dont la rangée serait pleine
--- n'aurait aucun poteau possible (G.row, IA1-c).
function P.colonnes_bras(width, period)
  period = period or 4
  local t = {}
  for c = 0, width - 1 do
    if c % period ~= period - 1 and not (width <= period - 1 and c == width - 1) then t[#t + 1] = c end
  end
  return t
end

local function slots_of(width, total, period)
  local all = P.colonnes_bras(width, period)
  local t = {}
  for i = 1, total do t[i] = all[i] end
  return t
end

local function n_slots(width, period) return #P.colonnes_bras(width, period) end

-- Poteau d'un module : celui du kit, sinon celui de M (M.with_pole), sinon le poteau par défaut.
local function pole_period(M, kit)
  local name = kit.poteau or M.current_pole or M.DEFAULT_POLE
  local sp = name and M.spec(name)
  return P.periode(sp and sp.supply)
end

local function lane_pair(belt)
  return { belt[1].name, (belt[2] or belt[1]).name }
end

-- Cadence des bras : ceux du kit seulement (le moins cher de chaque sorte). Quand ils ne suffisent pas à la machine au
-- maximum, la machine tourne moins vite (cadence prévue < maximale) : le gabarit dit ce qu'il débite vraiment (nominal).
local function arm_cap1(M, arm, from_belt)
  return M.BASE[arm].rate * (from_belt and M.BELT_PICKUP or 1) * M.MARGIN
end

--- Plus grande part f (≤ 1) de la cadence maximale `rate_max` que `slots` bras tiennent pour des groupes
--- { d = objets par fabrication, arm, belt }, un seul groupe ou deux (un bras normal et un long se partagent la rangée).
local function best_f(M, groups, slots, rate_max)
  local ng = #groups
  if ng == 0 then return 1 end
  if ng > slots then return 0 end
  local function f_of(g, c) return c * arm_cap1(M, g.arm, g.belt) / (g.d * rate_max) end
  if ng == 1 then return min(1, f_of(groups[1], slots)) end
  local best = 0
  for x = 1, slots - 1 do best = max(best, min(f_of(groups[1], x), f_of(groups[2], slots - x))) end
  return min(1, best)
end

--- Plus petit nombre de bras de chaque groupe pour la cadence `rate`.
local function arm_counts(M, groups, rate)
  local c = {}
  for i, g in ipairs(groups) do c[i] = max(1, ceil(g.d * rate / arm_cap1(M, g.arm, g.belt) - EPS)) end
  return c
end

---------------------------------------------------------------------------------------------------
-- 5. La cellule
---------------------------------------------------------------------------------------------------
--- Machine tournée pour que ses entrées de fluide regardent l'ouest, sinon l'est : { dir, cote, boites = { { tx, ty } } }
--- (tuiles des raccords, relatives au coin nord-ouest de la machine) ou (nil, raison).
local function orient(M, machine, msp, nfluids)
  if nfluids == 0 then return { dir = N } end
  local ins = {}
  for _, bx in ipairs(msp.boxes or {}) do if bx.io == "in" then ins[#ins + 1] = bx end end
  if #ins < nfluids then return fail("%s a %d boîte(s) d'entrée, la recette demande %d fluide(s)", machine, #ins, nfluids) end
  -- côté voulu : l'ouest d'abord, puis l'est ; pour chacun, la direction qui y met tous les raccords d'entrée (ouest, est,
  -- nord, sud dans cet ordre : la plus proche d'une machine tournée vers l'ouest l'emporte)
  for _, side in ipairs({ "ouest", "est" }) do
    for _, d in ipairs({ W, E, N, S }) do
      local mw, mh = M.size(machine, d)
      local ok, pts = true, {}
      for k = 1, nfluids do
        local p = ins[k].pts[1]
        local px, py = M.rot(d, p[1], p[2])
        local edge = (side == "ouest") and -(mw / 2 + 0.5) or (mw / 2 + 0.5)
        if math.abs(px - edge) > EPS or math.abs(py) >= mh / 2 then ok = false; break end
        pts[#pts + 1] = { ty = floor(mh / 2 + py) }
      end
      if ok then
        local rows = {}
        for i, q in ipairs(pts) do rows[i] = q.ty end
        table.sort(rows)
        for i = 2, #rows do
          if rows[i] - rows[i - 1] < 2 then ok = false end       -- deux tuyaux voisins se raccorderaient
        end
      end
      if ok then return { dir = d, cote = side, boites = pts } end
    end
  end
  return fail("les raccords d'entrée de %s ne regardent pas un même côté (ouest ou est) à une tuile de la machine, non voisins", machine)
end

--- Cellule : n machines de `machine` qui fabriquent `recette` (table du relevé) ; entrées par tapis, sortie `sortie`
--- ("tapis", "coffre" ou "unite") ; kit = { bras, bras_long, tapis, coffre, poteau (facultatif), tuyau (fluides) } ;
--- barre = cases du coffre de sortie ouvertes (0 : aucune barre). Rend le gabarit ou (nil, raison).
function P.cellule(M, machine, recette, sortie, n, kit, barre)
  sortie = sortie or "tapis"
  n = n or 1
  barre = barre or 0
  local okS = false
  for _, s in ipairs(P.SORTIES) do if s == sortie then okS = true end end
  if not okS then return fail("sortie « %s » inconnue (tapis, coffre ou unite)", tostring(sortie)) end
  if type(n) ~= "number" or n < 1 or n ~= floor(n) or n > P.MAX_N then return fail("nombre de machines invalide (%s)", tostring(n)) end
  if type(barre) ~= "number" or barre < 0 or barre ~= floor(barre) then return fail("barre invalide (%s)", tostring(barre)) end
  local msp = M.spec(machine)
  if not msp or (msp.kind ~= "assembler" and msp.kind ~= "furnace") then
    return fail("machine « %s » inconnue du gabarit (P.declare)", tostring(machine))
  end
  if (msp.burner_kw or 0) > 0 then return fail("« %s » brûle un combustible : hors patron (le combustible n'est pas une entrée)", machine) end
  local r, why = P.modele(M, recette)
  if not r then return nil, why end
  local okk, whyk = check_kit(M, kit, #r.fin > 0)
  if not okk then return nil, whyk end
  if msp.kind == "assembler" then
    local cat_ok = false
    for _, c in ipairs(msp.categories or {}) do if c == r.category then cat_ok = true end end
    if not cat_ok then return fail("« %s » ne fabrique pas la catégorie « %s »", machine, r.category) end
  end
  if #r.prods > 1 and sortie == "tapis" then
    return fail("%s a %d produits : sortie en coffre seulement (voies mêlées)", r.name, #r.prods)
  end
  local topo, whyt = P.topologie(#r.solids, sortie)
  if not topo then return nil, whyt end
  if topo.sud > 0 and sortie == "tapis" then
    return fail("%d entrées solides : sortie en coffre ou en unité (un tapis de sortie croiserait les tapis du sud)", #r.solids)
  end
  if #r.fin > 0 and n ~= 1 then return fail("fluides en entrée : une machine seule (%d demandées)", n) end
  if topo.sud > 0 and n ~= 1 then return fail("%d entrées solides : une machine seule (%d demandées)", #r.solids, n) end
  local ori, whyo = orient(M, machine, msp, #r.fin)
  if not ori then return nil, whyo end
  if ori.cote == "est" and topo.sud > 0 and sortie ~= "unite" then
    return fail("fluides à l'est avec %d entrées solides : colonne de sortie prise", #r.solids)
  end

  local mdir = ori.dir
  local per = pole_period(M, kit)
  local mw, mh = M.size(machine, mdir)
  local rate_max = msp.speed / r.time     -- exactement la formule du contrôle (max_rate)
  local ox = (ori.cote == "ouest") and 1 or 0
  local belts = P.voies((function()
    local t = {}
    for i, it in ipairs(r.solids) do t[i] = { name = it.name, amount = it.amount, demande = it.amount } end
    return t
  end)())

  -- lignes (relatives au coin nord-ouest du module)
  local nN, nS = topo.nord, topo.sud
  local y_belt = {}
  if nN >= 1 then y_belt[1] = nN - 1 end
  if nN == 2 then y_belt[2] = 0 end
  local y_ins = (nN > 0) and nN or nil
  local y_m = nN + ((nN > 0) and 1 or 0)
  local y_after = y_m + mh
  local y_sa, y_out, y_ob, H
  if nS > 0 then
    y_sa = y_after
    y_belt[3] = y_sa + 1
    if nS == 2 then y_belt[4] = y_sa + 2 end
    H = y_sa + 1 + nS
  elseif sortie ~= "unite" then
    y_out, y_ob = y_after, y_after + 1
    H = y_after + 2
  else
    H = y_after
  end
  local east_out = (nS > 0 and sortie ~= "unite")
  -- colonnes à l'est : sortie latérale (bras + coffre ou tapis) ; sinon une colonne de poteau pour une machine seule
  -- (comme G.row), sauf sous les tapis du sud où la machine d'unité garde un bord libre ; fluides à l'est : le tuyau
  local ec
  if east_out then ec = 2
  elseif nS > 0 then ec = (ox == 0) and 1 or 0
  elseif n == 1 then ec = 1
  else ec = 0 end
  if ori.cote == "est" and ec < 1 then ec = 1 end
  local span = n * mw + (n - 1)                 -- largeur des machines et de leurs colonnes de liaison
  local Wd = ox + span + ec
  -- places des têtes d'alimentation : côté de chaque tapis, profondeur, rangées au-dessus et au-dessous
  local sides = {}
  local w_need, e_need = P.MARGE, P.MARGE
  for k = 1, #belts do
    sides[k] = P.cote_tapis(k, ori.cote)
    if sides[k] == "ouest" then w_need = P.TETE else e_need = P.TETE end
  end
  if sortie == "tapis" then e_need = max(e_need, P.SORTIE) end
  local top_need = (#belts > 0) and P.TETE_LARGEUR or P.MARGE
  local bot_need = (nS > 0) and P.TETE_LARGEUR or P.MARGE
  if Wd + w_need + e_need > P.LOT or H + top_need + bot_need > P.LOT then
    return fail("emprise %d × %d, avec les têtes d'alimentation %d × %d, au-delà du lot de %d × %d", Wd, H,
      Wd + w_need + e_need, H + top_need + bot_need, P.LOT, P.LOT)
  end

  local b = M.new_builder("patron-" .. r.name .. "-" .. machine .. "-" .. sortie .. "-" .. n,
    "Patron (" .. n .. " " .. machine .. ", " .. r.name .. ", " .. #r.solids .. " entrées, sortie " .. sortie .. ")",
    "Pattern (" .. n .. " " .. machine .. ", " .. r.name .. ", " .. #r.solids .. " inputs, output " .. sortie .. ")")

  -- tapis d'entrée : de x = 0 à la dernière colonne des machines, une rangée chacun ; une voie = un objet
  local x_end = ox + span - 1
  local belt_first = {}
  for k, belt in ipairs(belts) do
    local line
    if sides[k] == "ouest" then line = b:belt_line(0, y_belt[k], x_end, y_belt[k], E)
    else line = b:belt_line(Wd - 1, y_belt[k], ox, y_belt[k], W) end
    belt_first[k] = line[1]
  end

  -- cadence : la part de la cadence maximale que les rangées de bras tiennent (nord, sud, sortie)
  local kin, groups_n, groups_s = {}, {}, {}
  for k, belt in ipairs(belts) do
    local d = 0
    for _, it in ipairs(belt) do d = d + it.amount end
    local long = (k % 2 == 0)
    kin[k] = long and kit.bras_long or kit.bras
    local g = { d = d, arm = kin[k], belt = true }
    if k <= 2 then groups_n[#groups_n + 1] = g else groups_s[#groups_s + 1] = g end
  end
  local d_out = 0
  for _, p in ipairs(r.prods) do d_out = d_out + p.amount end
  local out_slots = east_out and mh or mw
  local groups_o = (sortie ~= "unite") and { { d = d_out, arm = kit.bras, belt = false } } or {}
  local f = min(best_f(M, groups_n, n_slots(mw, per), rate_max), best_f(M, groups_s, n_slots(mw, per), rate_max), best_f(M, groups_o, n_slots(out_slots, per), rate_max))
  if f <= 0 then return fail("aucun bras ne tient la machine « %s » pour %s", machine, r.name) end
  local rate = rate_max * f
  local cn, cs, co = arm_counts(M, groups_n, rate), arm_counts(M, groups_s, rate), arm_counts(M, groups_o, rate)
  local nin = { cn[1], cn[2], cs[1], cs[2] }     -- bras par tapis
  local kout, nout = kit.bras, co[1] or 0

  local ent_machine = {}

  local out_ents = {}             -- indices des coffres (un par bras de sortie) ou des machines (unité)
  for i = 1, n do
    local x = ox + (i - 1) * (mw + 1)
    ent_machine[i] = b:put(machine, x, y_m, mdir, { recipe = r.name, rate = rate, role = "machine" })
    local north = slots_of(mw, (nin[1] or 0) + (nin[2] or 0), per)
    local col = 0
    for _ = 1, nin[1] or 0 do col = col + 1; b:put(kin[1], x + north[col], y_ins, N) end
    for _ = 1, nin[2] or 0 do col = col + 1; b:put(kin[2], x + north[col], y_ins, N) end
    if nS > 0 then
      local south = slots_of(mw, (nin[3] or 0) + (nin[4] or 0), per)
      col = 0
      for _ = 1, nin[3] or 0 do col = col + 1; b:put(kin[3], x + south[col], y_sa, S) end
      for _ = 1, nin[4] or 0 do col = col + 1; b:put(kin[4], x + south[col], y_sa, S) end
    end
    if sortie ~= "unite" and not east_out then
      local oslots = slots_of(mw, nout, per)
      for c = 1, nout do
        b:put(kout, x + oslots[c], y_out, N)
        if sortie == "coffre" then out_ents[#out_ents + 1] = b:put(kit.coffre, x + oslots[c], y_ob, N, { role = "coffre" }) end
      end
    end
  end
  if sortie == "tapis" and not east_out then
    local ob = b:belt_line(ox, y_ob, Wd - 1, y_ob, E)
    b:port({ kind = "tapis", io = "out", ent = ob[#ob] })
  end
  if east_out then
    local xe = ox + mw
    local oslots = slots_of(mh, nout, per)
    for _, c in ipairs(oslots) do b:put(kout, xe, y_m + c, W) end
    if sortie == "coffre" then
      for _, c in ipairs(oslots) do out_ents[#out_ents + 1] = b:put(kit.coffre, xe + 1, y_m + c, N, { role = "coffre" }) end
    else
      local col = b:belt_line(xe + 1, y_m, xe + 1, H - 1, S)
      b:port({ kind = "tapis", io = "out", ent = col[#col] })
    end
  end

  -- fluides : un tuyau sur chaque raccord, au bord du module
  if #r.fin > 0 then
    for k, p in ipairs(ori.boites) do
      local tx = (ori.cote == "ouest") and 0 or (Wd - 1)
      local pi = b:put(kit.tuyau, tx, y_m + p.ty, N, { role = "tuyau" })
      b:port({ kind = "tuyau", io = "in", ent = pi, fluid = r.fin[k].name })
    end
  end

  -- ports d'entrée (tapis) et de sortie (quai)
  for k, belt in ipairs(belts) do
    b:port({ kind = "tapis", io = "in", ent = belt_first[k], lanes = lane_pair(belt) })
  end
  if sortie == "coffre" then
    for _, ci in ipairs(out_ents) do
      for _, nm in ipairs(r.nets) do b:port({ kind = "quai", io = "out", ent = ci, item = nm, bar = (barre > 0) and barre or nil }) end
    end
  elseif sortie == "unite" then
    for i = 1, n do
      for _, nm in ipairs(r.nets) do b:port({ kind = "quai", io = "out", ent = ent_machine[i], item = nm, unite = true }) end
    end
  end

  -- poteaux : toute tuile libre du module, couverture gloutonne (M.Builder:auto_poles)
  local cands = {}
  for y = 0, H - 1 do for x = 0, Wd - 1 do cands[#cands + 1] = { x, y } end end
  local pole = kit.poteau
  b.g.power_pole = M.with_pole(pole, function() return b:auto_poles(cands) end)

  b.g.params = { machine = machine, recipe = r.name, sortie = sortie, n = n }
  b.g.gen, b.g.level_arg = "patron", 1
  b.g.args = { machine, recette, sortie, n, kit, barre }

  -- extension : le plus grand n tel que tout n de 1 à max passe le contrôle (largeur du lot, voies d'entrée, voie de sortie)
  local top = 1
  if topo.sud == 0 and #r.fin == 0 then
    local bounds = { floor_eps((P.LOT - w_need - e_need - ox + 1) / (mw + 1)) }
    for _, belt in ipairs(belts) do
      local cap = (#belt == 1) and 2 * M.LANE_RATE or M.LANE_RATE
      for _, it in ipairs(belt) do bounds[#bounds + 1] = floor_eps(cap / (it.amount * rate)) end
    end
    if sortie == "tapis" then bounds[#bounds + 1] = floor_eps(M.LANE_RATE / (d_out * rate)) end
    top = bounds[1]
    for _, v in ipairs(bounds) do top = min(top, v) end
    top = min(top, P.MAX_N)
  end
  b.g.extensions = { { param = "n", arg = 4, step = 1, max = max(0, top) } }
  return b:finish(Wd, H)
end

---------------------------------------------------------------------------------------------------
-- 6. Le bloc de mall : des recettes différentes sur 4 voies communes
---------------------------------------------------------------------------------------------------
--- Colonnes de machines par côté pour des machines de côté `mw` dans le lot : k·mw + (k − 1) ≤ MAX_LOT.
function P.colonnes(mw) return floor_eps((P.LOT - 2 * P.TETE + 1) / (mw + 1)) end

--- Nombre de machines d'un bloc au plus (deux côtés).
function P.bloc_max(M, machine)
  local msp = M.spec(machine)
  if not msp then return 0 end
  return 2 * P.colonnes(msp.w)
end

--- Bloc : une machine par recette de `recettes` (liste de tables du relevé, rangées par entrées décroissantes puis nom),
--- moitié au nord, moitié au sud de deux tapis. Sortie : un coffre par bras de sortie, barre `barre`.
function P.bloc(M, machine, recettes, kit, barre)
  barre = barre or 0
  if type(recettes) ~= "table" or #recettes == 0 then return fail("bloc sans recette") end
  if type(barre) ~= "number" or barre < 0 or barre ~= floor(barre) then return fail("barre invalide (%s)", tostring(barre)) end
  local msp = M.spec(machine)
  if not msp or msp.kind ~= "assembler" then return fail("machine « %s » inconnue du gabarit (P.declare)", tostring(machine)) end
  if (msp.burner_kw or 0) > 0 then return fail("« %s » brûle un combustible : hors patron", machine) end
  local okk, whyk = check_kit(M, kit, false)
  if not okk then return nil, whyk end
  local mw, mh = msp.w, msp.h
  local per = pole_period(M, kit)
  local models = {}
  for i, rec in ipairs(recettes) do
    local r, why = P.modele(M, rec)
    if not r then return nil, why end
    if #r.fin > 0 then return fail("%s : fluide en entrée (le bloc ne porte que des solides)", r.name) end
    local cat_ok = false
    for _, c in ipairs(msp.categories or {}) do if c == r.category then cat_ok = true end end
    if not cat_ok then return fail("« %s » ne fabrique pas la catégorie « %s » (%s)", machine, r.category, r.name) end
    models[i] = r
  end
  table.sort(models, function(a, b)
    if #a.solids ~= #b.solids then return #a.solids > #b.solids end
    return a.name < b.name
  end)
  for i = 2, #models do
    if models[i].name == models[i - 1].name then return fail("%s deux fois dans le même bloc", models[i].name) end
  end
  -- un objet fait dans le bloc ne peut pas être aussi une entrée d'un autre : l'analyse le compterait en moins
  local inputs_of = {}
  for _, r in ipairs(models) do for _, it in ipairs(r.solids) do inputs_of[it.name] = true end end
  for _, r in ipairs(models) do
    for _, nm in ipairs(r.nets) do
      if inputs_of[nm] then return fail("%s est fait ET consommé dans le même bloc (%s)", nm, r.name) end
    end
  end
  local m = #models
  local cols = P.colonnes(mw)
  if m > 2 * cols then return fail("%d recettes, %d machines au plus par bloc de côté %d", m, 2 * cols, mw) end

  -- voies communes : l'union des entrées, 4 au plus, rangée par nombre d'usages décroissant puis nom
  local use, names = {}, {}
  for _, r in ipairs(models) do
    for _, it in ipairs(r.solids) do
      if not use[it.name] then use[it.name] = { name = it.name, usages = 0 }; names[#names + 1] = it.name end
      use[it.name].usages = use[it.name].usages + 1
    end
  end
  if #names > P.BLOC_VOIES then return fail("%d entrées distinctes pour le bloc (%d voies)", #names, P.BLOC_VOIES) end
  local list = {}
  for _, nm in ipairs(names) do list[#list + 1] = use[nm] end
  table.sort(list, function(a, b)
    if a.usages ~= b.usages then return a.usages > b.usages end
    return a.name < b.name
  end)
  local lane_of, lane_name = {}, {}
  for i, it in ipairs(list) do lane_of[it.name] = i; lane_name[i] = it.name end
  local nbelts = ceil(#list / 2)

  -- côtés : le nord prend le premier, le sud le deuxième, etc.
  local north, south = {}, {}
  for i, r in ipairs(models) do
    if i % 2 == 1 then north[#north + 1] = r else south[#south + 1] = r end
  end
  local kmax = max(#north, #south)
  local Wd = kmax * mw + (kmax - 1)
  local has_south = #south > 0
  -- rangées
  local y_chest_n, y_out_n = 0, 1
  local y_m_n = 2
  local y_ia = y_m_n + mh
  local yA = y_ia + 1
  local yB = (nbelts == 2) and (y_ia + 2) or nil
  local y_ib = y_ia + 1 + nbelts
  local y_m_s = y_ib + 1
  local y_out_s = y_m_s + mh
  local y_chest_s = y_out_s + 1
  local H = has_south and (y_chest_s + 1) or (y_ia + 1 + nbelts)
  -- deux tapis voisins entrent de côtés opposés (P.cote_tapis) : une tête de P.TETE tuiles de chaque côté
  local w_need, e_need = P.MARGE, P.MARGE
  for k = 1, nbelts do
    if P.cote_tapis(k) == "ouest" then w_need = P.TETE else e_need = P.TETE end
  end
  if Wd + w_need + e_need > P.LOT or H + 2 * P.MARGE > P.LOT then
    return fail("emprise %d × %d, avec les têtes d'alimentation %d × %d, au-delà du lot de %d × %d", Wd, H,
      Wd + w_need + e_need, H + 2 * P.MARGE, P.LOT, P.LOT)
  end

  local b = M.new_builder("bloc-" .. machine .. "-" .. m, "Bloc de mall (" .. m .. " " .. machine .. ", " .. #list .. " voies)",
    "Mall block (" .. m .. " " .. machine .. ", " .. #list .. " lanes)")
  local belt_rows = { yA, yB }
  local belt_first = {}
  for k = 1, nbelts do
    if P.cote_tapis(k) == "ouest" then belt_first[k] = b:belt_line(0, belt_rows[k], Wd - 1, belt_rows[k], E)[1]
    else belt_first[k] = b:belt_line(Wd - 1, belt_rows[k], 0, belt_rows[k], W)[1] end
  end

  -- cadence de chaque machine : la part de son maximum que ses bras tiennent (proche : bras normal, loin : bras long)
  local rates, plan = {}, {}
  local function side_plan(recs, near, far)
    for _, r in ipairs(recs) do
      local d = { 0, 0 }
      for _, it in ipairs(r.solids) do
        local belt = ceil(lane_of[it.name] / 2)
        d[belt] = d[belt] + it.amount
      end
      local groups = {}
      if d[near] > 0 then groups[#groups + 1] = { d = d[near], arm = kit.bras, belt = true } end
      if far and d[far] > 0 then groups[#groups + 1] = { d = d[far], arm = kit.bras_long, belt = true } end
      local d_out = 0
      for _, p in ipairs(r.prods) do d_out = d_out + p.amount end
      local gout = { { d = d_out, arm = kit.bras, belt = false } }
      local rate_max = msp.speed / r.time
      local f = min(best_f(M, groups, n_slots(mw, per), rate_max), best_f(M, gout, n_slots(mw, per), rate_max))
      if f <= 0 then return fail("aucun bras ne tient la machine pour %s", r.name) end
      rates[r.name] = rate_max * f
      plan[r.name] = { counts = arm_counts(M, groups, rates[r.name]), out = arm_counts(M, gout, rates[r.name])[1],
        near = d[near] > 0, far = far and d[far] > 0 }
    end
    return true
  end
  local near_n, far_n = 1, (nbelts == 2) and 2 or nil
  local near_s, far_s = nbelts, (nbelts == 2) and 1 or nil
  local okp, whyp = side_plan(north, near_n, far_n)
  if not okp then return nil, whyp end
  okp, whyp = side_plan(south, near_s, far_s)
  if not okp then return nil, whyp end

  -- demande de chaque voie sur le bloc entier (les bras d'une même rangée ne dépassent pas une voie)
  local demand = {}
  for _, r in ipairs(models) do
    for _, it in ipairs(r.solids) do
      demand[it.name] = (demand[it.name] or 0) + it.amount * rates[r.name]
    end
  end
  for i, nm in ipairs(lane_name) do
    local cap = (#list % 2 == 1 and i == #list) and 2 * M.LANE_RATE or M.LANE_RATE
    if demand[nm] > cap + EPS then return fail("voie %d : %.2f/s demandés sur %.2f/s", i, demand[nm], cap) end
  end

  local function side(recs, y_m, y_arm, y_oarm, y_ch, arm_dir, out_dir)
    for j, r in ipairs(recs) do
      local x = (j - 1) * (mw + 1)
      local pl = plan[r.name]
      b:put(machine, x, y_m, N, { recipe = r.name, rate = rates[r.name], role = "machine" })
      local ci_near, ci_far = 0, 0
      local k = 1
      if pl.near then ci_near = pl.counts[k]; k = k + 1 end
      if pl.far then ci_far = pl.counts[k] end
      local sl = slots_of(mw, ci_near + ci_far, per)
      local col = 0
      for _ = 1, ci_near do col = col + 1; b:put(kit.bras, x + sl[col], y_arm, arm_dir) end
      for _ = 1, ci_far do col = col + 1; b:put(kit.bras_long, x + sl[col], y_arm, arm_dir) end
      -- sortie : un coffre au bout de chaque bras
      local osl = slots_of(mw, pl.out, per)
      for c = 1, pl.out do
        b:put(kit.bras, x + osl[c], y_oarm, out_dir)
        local ci = b:put(kit.coffre, x + osl[c], y_ch, N, { role = "coffre" })
        for _, nm in ipairs(r.nets) do
          b:port({ kind = "quai", io = "out", ent = ci, item = nm, bar = (barre > 0) and barre or nil })
        end
      end
    end
  end
  -- nord : bras dirigés vers le sud (prennent au sud, déposent au nord), sortie vers le nord
  side(north, y_m_n, y_ia, y_out_n, y_chest_n, S, S)
  -- sud : bras dirigés vers le nord ; le tapis proche est le dernier
  if has_south then side(south, y_m_s, y_ib, y_out_s, y_chest_s, N, N) end
  for k = 1, nbelts do
    local pair = { list[2 * k - 1].name, (list[2 * k] or list[2 * k - 1]).name }
    b:port({ kind = "tapis", io = "in", ent = belt_first[k], lanes = pair })
  end

  local cands = {}
  for y = 0, H - 1 do for x = 0, Wd - 1 do cands[#cands + 1] = { x, y } end end
  b.g.power_pole = M.with_pole(kit.poteau, function() return b:auto_poles(cands) end)
  local byname, recs = {}, {}
  for _, orig in ipairs(recettes) do byname[orig.name] = orig end
  for i, r in ipairs(models) do recs[i] = byname[r.name] end
  b.g.params = { machine = machine, n = m }
  b.g.gen, b.g.level_arg = "bloc", 1
  b.g.args = { machine, recs, kit, barre }
  b.g.extensions = {}
  return b:finish(Wd, H)
end

---------------------------------------------------------------------------------------------------
-- 6 bis. Le RUBAN de mall (lot MALL-RUE) : le gabarit des blocs quand la demande dépasse ce qu'un lot tient
---------------------------------------------------------------------------------------------------
-- Géométrie : Mp.pattern (shared/team/mall_paving.lua : deux rangées de machines face à face, corridor central de 2 convoyeurs,
-- coffres extérieurs) ; bras et coffres suivent la cadence, par les règles du bloc. Corridor : le convoyeur A (seconde ligne du
-- corridor) va vers l'EST, entré à l'ouest, 2 voies (les deux entrées les plus demandées) : c'est lui que la série prolonge de
-- section en section, sous la rue, par un souterrain (Mp.serie ; script/team/build.lua, Build.Pave) ; le convoyeur B (première
-- ligne) va vers l'OUEST, entré à l'est, UNE entrée sur ses deux voies : sa tête d'alimentation (P.feeder : bras et coffre au
-- nord de la tête) laisse libre la ligne de A à l'est du corps, où passent la rallonge et l'entrée du souterrain. Donc
-- P.RUBAN_VOIES = 3 entrées distinctes au plus (le bloc en porte 4 : au-delà, le bloc reste le gabarit ; script/ai3/industrie.lua).
-- Le ruban est ORIENTABLE depuis le lot MALL-DIRECTIONS (la série suit l'orientation de sa première section, choisie vers un lot voisin
-- libre : shared/team/serie_dirs.lua ; Build.Pave tourne les lignes du corridor par Sd.cross) ; g.ruban = { belts = { ligne de A }, port = entité du port d'entrée de A
-- (la section suivante est servie par le souterrain : aucune tête sur ce port), fam = « ruban-<machine> » }.
local Mp = require("shared.team.mall_paving")

P.RUBAN_VOIES = 3

--- Modèles des recettes d'un ruban (les contrôles du bloc : solides seuls, catégorie de la machine, pas deux fois, rien de fait ET
--- consommé), rangés par entrées décroissantes puis nom. Rend la liste ou (nil, raison).
local function ruban_models(M, machine, msp, recettes)
  local models = {}
  for i, rec in ipairs(recettes) do
    local r, why = P.modele(M, rec)
    if not r then return nil, why end
    if #r.fin > 0 then return fail("%s : fluide en entrée (le ruban ne porte que des solides)", r.name) end
    local cat_ok = false
    for _, c in ipairs(msp.categories or {}) do if c == r.category then cat_ok = true end end
    if not cat_ok then return fail("« %s » ne fabrique pas la catégorie « %s » (%s)", machine, r.category, r.name) end
    models[i] = r
  end
  table.sort(models, function(a, b)
    if #a.solids ~= #b.solids then return #a.solids > #b.solids end
    return a.name < b.name
  end)
  for i = 2, #models do
    if models[i].name == models[i - 1].name then return fail("%s deux fois dans le même ruban", models[i].name) end
  end
  local inputs_of = {}
  for _, r in ipairs(models) do for _, it in ipairs(r.solids) do inputs_of[it.name] = true end end
  for _, r in ipairs(models) do
    for _, nm in ipairs(r.nets) do
      if inputs_of[nm] == true then return fail("%s est fait ET consommé dans le même ruban (%s)", nm, r.name) end
    end
  end
  return models
end

--- Voies du ruban : entrées rangées par usages décroissants puis nom ; A porte les deux premières, B la troisième (sur ses deux
--- voies). Rend { belt_of = { [objet] = 1 (A) | 2 (B) }, A = { a, b }, B = { c, c }, names } ou (nil, raison).
local function ruban_lanes(models)
  local use, names = {}, {}
  for _, r in ipairs(models) do
    for _, it in ipairs(r.solids) do
      if not use[it.name] then use[it.name] = { name = it.name, usages = 0 }; names[#names + 1] = it.name end
      use[it.name].usages = use[it.name].usages + 1
    end
  end
  if #names > P.RUBAN_VOIES then return fail("%d entrées distinctes pour le ruban (%d voies : 2 sur le corridor continu, 1 sur le retour)", #names, P.RUBAN_VOIES) end
  local list = {}
  for _, nm in ipairs(names) do list[#list + 1] = use[nm] end
  table.sort(list, function(a, b)
    if a.usages ~= b.usages then return a.usages > b.usages end
    return a.name < b.name
  end)
  -- 3 entrées : A = { 1, 2 }, B = { 3, 3 } ; 2 entrées : A = { 1, 1 }, B = { 2, 2 } ; 1 entrée : A = { 1, 1 }, pas de B
  local belt_of, A, B = {}, nil, nil
  if #list == 3 then
    belt_of[list[1].name], belt_of[list[2].name], belt_of[list[3].name] = 1, 1, 2
    A, B = { list[1].name, list[2].name }, { list[3].name, list[3].name }
  elseif #list == 2 then
    belt_of[list[1].name], belt_of[list[2].name] = 1, 2
    A, B = { list[1].name, list[1].name }, { list[2].name, list[2].name }
  else
    belt_of[list[1].name] = 1
    A = { list[1].name, list[1].name }
  end
  return { belt_of = belt_of, A = A, B = B, names = list }
end

--- Cadence d'une machine du ruban et ses bras : `near` = convoyeur à portée 1 (bras normal), `far` = à portée 2 (bras long).
--- Rend { rate, counts = { près, loin } (0 : aucun bras), out = bras de sortie } ou (nil, raison).
local function ruban_plan(M, r, lanes, near, far, kit, msp, slots)
  local d = { 0, 0 }
  for _, it in ipairs(r.solids) do d[lanes.belt_of[it.name]] = d[lanes.belt_of[it.name]] + it.amount end
  local groups = {}
  if d[near] > 0 then groups[#groups + 1] = { d = d[near], arm = kit.bras, belt = true } end
  if d[far] > 0 then groups[#groups + 1] = { d = d[far], arm = kit.bras_long, belt = true } end
  local d_out = 0
  for _, p in ipairs(r.prods) do d_out = d_out + p.amount end
  local gout = { { d = d_out, arm = kit.bras, belt = false } }
  local rate_max = msp.speed / r.time
  local f = min(best_f(M, groups, slots, rate_max), best_f(M, gout, slots, rate_max))
  if f <= 0 then return fail("aucun bras ne tient la machine pour %s", r.name) end
  local rate = rate_max * f
  local c = arm_counts(M, groups, rate)
  local counts = { 0, 0 }
  local k = 1
  if d[near] > 0 then counts[1] = c[k]; k = k + 1 end
  if d[far] > 0 then counts[2] = c[k] end
  return { rate = rate, counts = counts, out = arm_counts(M, gout, rate)[1] }
end

--- Pose une rangée de machines du ruban (nord ou sud) : machine, bras d'entrée (près puis loin), bras et coffres de sortie.
local function ruban_side(b, M, machine, recs, plans, rows, mw, per, kit, barre)
  for j, r in ipairs(recs) do
    local x = (j - 1) * (mw + 1)
    local pl = plans[r.name]
    b:put(machine, x, rows.m, N, { recipe = r.name, rate = pl.rate, role = "machine" })
    local sl = slots_of(mw, pl.counts[1] + pl.counts[2], per)
    local col = 0
    for _ = 1, pl.counts[1] do col = col + 1; b:put(kit.bras, x + sl[col], rows.arm, rows.arm_dir) end
    for _ = 1, pl.counts[2] do col = col + 1; b:put(kit.bras_long, x + sl[col], rows.arm, rows.arm_dir) end
    local osl = slots_of(mw, pl.out, per)
    local bar = (barre > 0) and barre or nil
    for c = 1, pl.out do
      b:put(kit.bras, x + osl[c], rows.oarm, rows.arm_dir)
      local ci = b:put(kit.coffre, x + osl[c], rows.chest, N, { role = "coffre" })
      for _, nm in ipairs(r.nets) do b:port({ kind = "quai", io = "out", ent = ci, item = nm, bar = bar }) end
    end
  end
end

--- Ruban : une machine par recette de `recettes`, moitié au nord, moitié au sud du corridor de Mp.pattern. Sortie : un coffre par
--- bras de sortie, barre `barre`. Mêmes arguments que P.bloc ; rend le gabarit (gen « ruban ») ou (nil, raison).
function P.ruban(M, machine, recettes, kit, barre)
  barre = barre or 0
  if type(recettes) ~= "table" or #recettes == 0 then return fail("ruban sans recette") end
  if type(barre) ~= "number" or barre < 0 or barre ~= floor(barre) then return fail("barre invalide (%s)", tostring(barre)) end
  local msp = M.spec(machine)
  if not msp or msp.kind ~= "assembler" then return fail("machine « %s » inconnue du gabarit (P.declare)", tostring(machine)) end
  if (msp.burner_kw or 0) > 0 then return fail("« %s » brûle un combustible : hors patron", machine) end
  local okk, whyk = check_kit(M, kit, false)
  if not okk then return nil, whyk end
  local models, whym = ruban_models(M, machine, msp, recettes)
  if not models then return nil, whym end
  local lanes, whyl = ruban_lanes(models)
  if not lanes then return nil, whyl end
  local m, mw, mh = #models, msp.w, msp.h
  local cols = P.colonnes(mw)
  if m > 2 * cols then return fail("%d recettes, %d machines au plus par section de ruban de côté %d", m, 2 * cols, mw) end
  local kmax = ceil(m / 2)
  local pat, whyp = Mp.pattern({ asm = { w = mw, h = mh }, belts = 2, n = kmax, gap = Mp.GAP })
  if not pat then return nil, whyp end
  local Wd, H = pat.w, pat.h
  if Wd + 2 * P.TETE > P.LOT or H + 2 * P.MARGE > P.LOT then
    return fail("emprise %d × %d, avec les têtes d'alimentation %d × %d, au-delà du lot de %d × %d", Wd, H, Wd + 2 * P.TETE, H + 2 * P.MARGE, P.LOT, P.LOT)
  end
  -- lignes du ruban lues dans le gabarit pur : machines du nord et du sud, les deux convoyeurs (B puis A)
  local y_m_n, y_m_s, yA, yB = math.huge, -math.huge, math.huge, -math.huge
  for _, c in ipairs(pat.cells) do
    if c.kind == "asm" then y_m_n, y_m_s = min(y_m_n, c.dy), max(y_m_s, c.dy) end
    if c.kind == "belt" then yA, yB = min(yA, c.dy), max(yB, c.dy) end
  end
  local per = pole_period(M, kit)
  local north, south = {}, {}
  for i, r in ipairs(models) do if i % 2 == 1 then north[#north + 1] = r else south[#south + 1] = r end end
  local plans, demand = {}, {}
  for _, side in ipairs({ { north, 2, 1 }, { south, 1, 2 } }) do -- nord : près B (2), loin A (1) ; sud : près A, loin B
    for _, r in ipairs(side[1]) do
      local pl, why = ruban_plan(M, r, lanes, side[2], side[3], kit, msp, n_slots(mw, per))
      if not pl then return nil, why end
      plans[r.name] = pl
      for _, it in ipairs(r.solids) do demand[it.name] = (demand[it.name] or 0) + it.amount * pl.rate end
    end
  end
  local lanes_n = {} -- voies que chaque entrée occupe (A et B)
  for _, nm in ipairs(lanes.A) do lanes_n[nm] = (lanes_n[nm] or 0) + 1 end
  for _, nm in ipairs(lanes.B or {}) do lanes_n[nm] = (lanes_n[nm] or 0) + 1 end
  for i, it in ipairs(lanes.names) do
    local cap = lanes_n[it.name] * M.LANE_RATE
    if demand[it.name] > cap + EPS then return fail("voie %d : %.2f/s demandés sur %.2f/s", i, demand[it.name], cap) end
  end
  local b = M.new_builder("ruban-" .. machine .. "-" .. m, "Ruban de mall (" .. m .. " " .. machine .. ", " .. #lanes.names .. " voies)",
    "Mall ribbon (" .. m .. " " .. machine .. ", " .. #lanes.names .. " lanes)")
  local firstB = lanes.B and b:belt_line(Wd - 1, yA, 0, yA, W)[1] or nil -- (sans troisième ni deuxième entrée : pas de convoyeur de retour)
  local firstA = b:belt_line(0, yB, Wd - 1, yB, E)[1]
  ruban_side(b, M, machine, north, plans, { m = y_m_n, arm = y_m_n + mh, oarm = 1, chest = 0, arm_dir = S }, mw, per, kit, barre)
  if #south > 0 then ruban_side(b, M, machine, south, plans, { m = y_m_s, arm = yB + 1, oarm = y_m_s + mh, chest = H - 1, arm_dir = N }, mw, per, kit, barre) end
  b:port({ kind = "tapis", io = "in", ent = firstA, lanes = { lanes.A[1], lanes.A[2] } })
  if firstB then b:port({ kind = "tapis", io = "in", ent = firstB, lanes = { lanes.B[1], lanes.B[2] } }) end
  local cands = {}
  for y = 0, H - 1 do for x = 0, Wd - 1 do cands[#cands + 1] = { x, y } end end
  b.g.power_pole = M.with_pole(kit.poteau, function() return b:auto_poles(cands) end)
  local byname, recs = {}, {}
  for _, orig in ipairs(recettes) do byname[orig.name] = orig end
  for i, r in ipairs(models) do recs[i] = byname[r.name] end
  b.g.params = { machine = machine, n = m }
  b.g.gen, b.g.level_arg = "ruban", 1
  b.g.args = { machine, recs, kit, barre }
  b.g.extensions = {}
  b.g.ruban = { belts = { yB }, port = firstA, fam = "ruban-" .. machine } -- (orientable : lot MALL-DIRECTIONS)
  return b:finish(Wd, H)
end

---------------------------------------------------------------------------------------------------
-- 7. Regroupement, copies, assemblage
---------------------------------------------------------------------------------------------------
--- Range des objets en blocs. objets : liste de { name, solides = { noms }, machine = classe de machine (texte) }. Glouton
--- déterministe : objets rangés par nombre d'entrées décroissant puis nom ; chacun va dans le premier bloc de sa classe
--- dont l'union des entrées reste ≤ P.BLOC_VOIES et dont le nombre de machines reste ≤ `opts.max` (défaut : P.bloc_max
--- n'est pas connu ici, 10). Un objet de plus de P.BLOC_VOIES entrées ne rentre dans aucun bloc : il reste « seul »
--- (rangée dédiée). Rend { blocs = { { classe, objets = { noms }, voies = { noms } } }, seuls = { noms } }.
function P.groups(objets, opts)
  opts = opts or {}
  local cap = opts.max or 10
  local list = {}
  for i, o in ipairs(objets) do list[i] = o end
  table.sort(list, function(a, b)
    if #a.solides ~= #b.solides then return #a.solides > #b.solides end
    return a.name < b.name
  end)
  local blocs, seuls = {}, {}
  for _, o in ipairs(list) do
    if #o.solides > P.BLOC_VOIES or #o.solides == 0 then
      seuls[#seuls + 1] = o.name
    else
      local placed = false
      for _, bl in ipairs(blocs) do
        -- un objet n'est pas fait dans un bloc qui le consomme, ni ne consomme ce que le bloc fait
        local clash = false
        for _, v in ipairs(bl.voies) do if v == o.name then clash = true end end
        for _, nm in ipairs(bl.objets) do for _, v in ipairs(o.solides) do if v == nm then clash = true end end end
        if not clash and bl.classe == o.machine and #bl.objets < cap then
          local union, n = {}, 0
          for _, v in ipairs(bl.voies) do union[v] = true; n = n + 1 end
          for _, v in ipairs(o.solides) do if not union[v] then union[v] = true; n = n + 1 end end
          if n <= P.BLOC_VOIES then
            bl.objets[#bl.objets + 1] = o.name
            bl.voies = {}
            for v in pairs(union) do bl.voies[#bl.voies + 1] = v end
            table.sort(bl.voies)
            placed = true
            break
          end
        end
      end
      if not placed then
        local voies = {}
        for _, v in ipairs(o.solides) do voies[#voies + 1] = v end
        table.sort(voies)
        blocs[#blocs + 1] = { classe = o.machine, objets = { o.name }, voies = voies }
      end
    end
  end
  return { blocs = blocs, seuls = seuls }
end

--- Machines nécessaires pour un débit (objets/min) : au moins 1, arrondi au-dessus.
function P.copies(demande, par_min)
  if type(demande) ~= "number" or type(par_min) ~= "number" or par_min <= 0 then return nil end
  return max(1, ceil(demande / par_min - EPS))
end

--- Assemblage : « rangee » dès qu'il faut au moins une machine entière, sinon « bloc » (PLAN §2).
function P.assemblage(demande, par_min)
  if type(demande) ~= "number" or type(par_min) ~= "number" or par_min <= 0 then return nil end
  if demande >= par_min - EPS then return "rangee" end
  return "bloc"
end

return P
