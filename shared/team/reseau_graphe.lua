--[[
  Lot RESEAU-GRAPHE : BUS DE PRODUITS entre les blocs producteurs et les quais des consommateurs. Règle PURE : aucune API du jeu, aucun nom
  d'objet (un objet est une chaîne opaque) ; lue hors jeu (tests/reseau_graphe_test.lua). Conception : docs/conception/RESEAU_GRAPHE.md.

  Demande du DC (8/11, en jouant la 0.6.65) : les PNJ usent les coffres posés aux fonderies, mais « il faut faire pas mal de trajets pour aller
  les chercher » ; « un problème de théorie des graphes, relier un maximum les ressources aux assembleurs », « blocs et graphes connexes »,
  « un problème de maximisation avec les K-max ... le nombre de bus ». Aujourd'hui (shared/team/liaison.lua) un quai n'est relié qu'à UN coffre
  de sortie à 40 tuiles au plus : sur la sauvegarde du DC (255 min), 1 quai servi par tapis sur 33 à 59 par équipe.

  Modèle. Producteurs = coffres de sortie (objet, tuile, débit disponible en objets/min), consommateurs = quais d'entrée (objet, tuile, débit
  demandé). Le QG est le moyeu : sans tapis, un objet fait DEUX trajets de PNJ (collecte sortie -> QG, remplissage QG -> quai). Un BUS est un
  tapis droit (tronc) qui suit un axe de rue, avec des branches perpendiculaires vers chaque coffre (arbre « en peigne ») ; une file de tapis a 2
  voies, une voie porte un objet. Le tapis va dans un seul sens : un consommateur ne reçoit que de ce qui est en amont.

  1. LEGS (Rg.leg) : coût d'un trajet par objet porté = (2 d / marche + prise) / lot, lots de la collecte (200) et du remplissage (340).
  2. COMPOSANTES (components) : par objet, graphe des terminaux relié si Manhattan <= Rg.LINK_R (ou dist(a, b) rend un nombre, nil = interdit) ;
     composantes connexes par union-find ; au-delà de Rg.N_MAX terminaux, coupe à la médiane de l'axe le plus étendu (récursif).
  3. BUS D'UNE COMPOSANTE (Rg.bus_of) : axe et sens = déplacement du centre des producteurs vers celui des consommateurs ; balayage (evaluate)
     le long du tronc : le débit dans la voie monte aux producteurs (borné par Rg.LANE_CAP), descend aux consommateurs ; le gain est la somme
     des trajets évités (PNJ-secondes par minute). Tronc à la médiane des coordonnées perpendiculaires (minimise la somme des branches).
     Élagage glouton à rebours (peel) : on retire le terminal dont le départ améliore le plus la valeur nette tmax x gain - coût, tant que
     cela améliore et jusqu'à tenir dans Rg.MAX_TRUNK.
  4. CHOIX (select_run) : au plus k files de tapis (2 voies chacune) ; deux objets de même axe, sens et rue (Rg.SHARE_PERP) dont les troncs se
     recouvrent partagent une file et ne payent qu'une fois le recouvrement ; deux ordres (valeur nette, valeur nette / coût),
     on garde le meilleur total. Sortie : bus ordonnés (ordre de pose), prises ordonnées par contribution.

  Entrées (inp) : producers = { { key, item, x, y, rate } }, consumers = { { key, item, x, y, rate } } (rate en objets/min), hub = { x, y }, k
  (files, défaut Rg.BELTS), budget (plaques, nil = sans borne), hub_share (part des sorties laissée au QG, défaut Rg.HUB_SHARE), labor, price,
  tmax. Le crochet dist(a, b) est passé à Rg.step / Rg.plan (jamais rangé dans le travail : le travail est sérialisable).

  Découpage : Rg.begin / Rg.step(job, unités, dist) / Rg.result ; une unité = un objet (composantes) ou un bus ; le travail ne contient que
  des nombres, chaînes et tables. Rg.plan = begin + step jusqu'au bout.

  Déterminisme : listes triées avec départage par clé, aucune trigonométrie, aucune horloge, aucun hasard. Valeurs NON MESURÉES : Rg.HUB_SHARE,
  Rg.LANE_CAP (tapis de base : 15 objets/s sur 2 voies), Rg.ARM_RATE (bras électrique de base, coffre à tapis).
]]

local Li = require("shared.team.liaison")

local Rg = {}
Rg._u = { Li = Li } -- aides communes aux deux fichiers

Rg.BELTS = 2            -- files de tapis (« k bus ») par défaut ; une file = 2 voies
Rg.LANES_PER_BELT = 2
Rg.LANE_CAP = 450       -- objets/min par voie (7,5/s : tapis de base 15/s sur 2 voies)
Rg.ARM_RATE = 50        -- objets/min par bras électrique (0,83/s)
Rg.MAX_ARMS = 4         -- bras au plus par coffre (débit d'un terminal borné à MAX_ARMS x ARM_RATE)
Rg.COLLECT_BATCH = 200  -- objets par trajet de collecte (Build.COLLECT_AT, script/team/build.lua)
Rg.FILL_BATCH = 340     -- objets par trajet de remplissage (Build.QUAI_FILL - Build.QUAI_LOW)
Rg.LINK_R = 160         -- tuiles (Manhattan) : deux terminaux d'un même objet plus proches sont de la même composante
Rg.MAX_TRUNK = 220      -- tuiles de tapis (tronc et branches) au plus par bus
Rg.N_MAX = 32           -- terminaux au plus par composante (au-delà : coupe)
Rg.PEEL_MAX = 40        -- retraits (ou ajouts) au plus de l'élagage et de la croissance
Rg.DEPTH_MAX = 3        -- bus au plus par composante (le premier, puis les restes)
Rg.HUB_SHARE = 0.3      -- part du débit des sorties laissée à la collecte vers le QG (construction et fabrication à la main)
Rg.DETOUR = Li.EST_FACTOR
Rg.SHARE_PERP = 4       -- tuiles : deux troncs à cet écart au plus sont dans la même rue
Rg.OVERLAP_MIN = 0.5    -- part du plus court tronc qui doit être recouverte pour partager une file
Rg.MIN_RATE = 1         -- objets/min : en dessous, un terminal ou un bus ne compte pas
Rg.EPOCH_STEP = 3       -- une file de plus toutes les EPOCH_STEP époques (proposition, à valider par le DC)
Rg.BELT_TILES = 150     -- tuiles de tapis tenues en réserve par file ouverte (un bus type de l'exemple : 130 à 190 tuiles)
Rg.CROSS_PLAQUES = 20   -- plaques-équivalent d'un croisement de deux bus (une paire de tapis souterrains) ; NON MESURÉ
Rg.EPS = 1e-6

local function manhattan(ax, ay, bx, by) return math.abs(ax - bx) + math.abs(ay - by) end

local function copy(list)
  local o = {}
  for i = 1, #list do o[i] = list[i] end
  return o
end

local function without(list, skip)
  local o = {}
  for i = 1, #list do if i ~= skip then o[#o + 1] = list[i] end end
  return o
end

local function term_lt(a, b)
  if a.key ~= b.key then return a.key < b.key end
  return a.kind < b.kind
end

--- Coût, en PNJ-secondes par objet, d'un trajet aller-retour à la distance d (tuiles) pour un lot de `batch` objets.
function Rg.leg(d, batch)
  return (2 * d / Li.WALK + Li.HANDLE_S) / math.max(1, batch)
end


Rg._u.manhattan, Rg._u.copy, Rg._u.without, Rg._u.term_lt = manhattan, copy, without, term_lt
require("shared.team.reseau_bus")(Rg)
local U = Rg._u
Rg._u = nil

---------------------------------------------------------------------------------------------------
-- 3. Choix des bus sous k files
---------------------------------------------------------------------------------------------------
local function first_key(c) return c.taps[1].key end

local function cand_lt(a, b)
  if a.item ~= b.item then return a.item < b.item end
  local ka, kb = first_key(a), first_key(b)
  if ka ~= kb then return ka < kb end
  return a.line < b.line
end

--- Un passage glouton dans l'ordre `order` (liste de candidats). Rend { picks = { { c, belt, ov, mnet, mplaq } }, belts, net, plaques }.
local function select_run(order, k, budget, o)
  local belts, picks = {}, {}
  local spent, net_total = 0, 0
  for _, c in ipairs(order) do
    local bb, bov = nil, 0
    for bi, b in ipairs(belts) do
      if b.axis == c.axis and b.sign == c.sign and #b.lanes < Rg.LANES_PER_BELT and not b.items[c.item]
        and math.abs(b.line - c.line) <= Rg.SHARE_PERP then
        local ov = math.min(b.hi, c.hi) - math.max(b.lo, c.lo)
        local short = math.min(b.hi - b.lo, c.hi - c.lo)
        if ov >= Rg.OVERLAP_MIN * math.max(1, short) and ov > bov then bb, bov = bi, ov end
      end
    end
    local mplaq, mnet = c.plaques, c.net
    if bb then
      local shared = math.ceil(bov * Rg.DETOUR)
      mplaq = math.max(0, c.plaques - shared * o.price.belt)
      mnet = c.net + shared * (o.price.belt / o.labor + Li.POSE_S)
    end
    -- croisements avec les bus déjà posés sur d'AUTRES files : une paire de souterrains chacun, payée par le bus qui arrive
    local nx = 0
    for _, q in ipairs(picks) do
      if q.belt ~= bb then nx = nx + U.crossings(q.c.segs, c.segs) end
    end
    mplaq = mplaq + nx * Rg.CROSS_PLAQUES
    mnet = mnet - nx * (Rg.CROSS_PLAQUES / o.labor + 2 * Li.POSE_S)
    if (bb or #belts < k) and (not budget or spent + mplaq <= budget) and mnet > 0 then
      if not bb then
        belts[#belts + 1] = { axis = c.axis, sign = c.sign, line = c.line, lo = c.lo, hi = c.hi, lanes = {}, items = {} }
        bb = #belts
      end
      local b = belts[bb]
      b.lanes[#b.lanes + 1] = c
      b.items[c.item] = true
      b.lo, b.hi = math.min(b.lo, c.lo), math.max(b.hi, c.hi)
      picks[#picks + 1] = { c = c, belt = bb, lane = #b.lanes, ov = bov, mnet = mnet, mplaq = mplaq, nx = nx }
      spent = spent + mplaq
      net_total = net_total + mnet
    end
  end
  return { picks = picks, belts = belts, net = net_total, plaques = spent }
end

local function choose(cands, k, budget, o)
  local A = copy(cands)
  table.sort(A, function(a, b)
    if a.net ~= b.net then return a.net > b.net end
    return cand_lt(a, b)
  end)
  local B = copy(cands)
  table.sort(B, function(a, b)
    local ra, rb = a.net / math.max(1, a.pay_s), b.net / math.max(1, b.pay_s)
    if ra ~= rb then return ra > rb end
    return cand_lt(a, b)
  end)
  -- A contient déjà le meilleur bus seul (premier de sa liste, s'il tient) : le meilleur des deux ordres vaut au moins max(meilleur seul,
  -- glouton par valeur / coût), donc la moitié de l'optimum du sac à dos quand les bus sont indépendants.
  local ra, rb = select_run(A, k, budget, o), select_run(B, k, budget, o)
  local best, which = ra, "net"
  if rb.net > best.net + Rg.EPS then best, which = rb, "net/cout" end
  return best, which
end

---------------------------------------------------------------------------------------------------
-- 4. Travail découpé
---------------------------------------------------------------------------------------------------
--- Prépare le travail. Rend le job (nombres, chaînes, tables ; aucune fonction).
function Rg.begin(inp)
  local opts = {
    hub = inp.hub or { x = 0, y = 0 },
    labor = inp.labor or Li.LABOR_VALUE,
    price = inp.price or Li.PRICE,
    tmax = inp.tmax or Li.TMAX,
    k = inp.k or Rg.BELTS,
    budget = inp.budget,
    hub_share = inp.hub_share or Rg.HUB_SHARE,
  }
  local seen, items, by = {}, {}, {}
  local demand, supply = 0, 0
  local function add(t, kind)
    local m = U.make_terminal(t, kind, opts.hub, kind == "p" and opts.hub_share or 0)
    if not m then return end
    if kind == "c" then demand = demand + m.rate else supply = supply + m.rate end
    if not seen[m.item] then seen[m.item] = true; items[#items + 1] = m.item; by[m.item] = {} end
    table.insert(by[m.item], m)
  end
  for _, t in ipairs(inp.producers or {}) do add(t, "p") end
  for _, t in ipairs(inp.consumers or {}) do add(t, "c") end
  table.sort(items)
  local queue, ceiling = {}, 0
  for _, it in ipairs(items) do
    table.sort(by[it], term_lt)
    queue[#queue + 1] = { t = "item", item = it, list = by[it] }
    local sp, sc = 0, 0
    for _, m in ipairs(by[it]) do if m.kind == "p" then sp = sp + m.rate else sc = sc + m.rate end end
    ceiling = ceiling + math.min(sp, sc)
  end
  return { opts = opts, queue = queue, qi = 1, cands = {}, n_comp = 0, rejects = {}, phase = "queue", demand = demand, supply = supply,
    ceiling = ceiling, n_items = #items }
end

local function reject(job, why)
  job.rejects[#job.rejects + 1] = why
end

--- Avance de `units` unités (nil = tout). dist : crochet facultatif (voir Rg.components). Rend vrai quand le travail est fini.
function Rg.step(job, units, dist)
  local left = units or math.huge
  while left > 0 and job.phase ~= "done" do
    if job.phase == "queue" then
      local task = job.queue[job.qi]
      if not task then
        job.phase = "select"
      else
        left = left - 1
        if task.t == "item" then
          job.qi = job.qi + 1
          for _, comp in ipairs(Rg.components(task.list, dist)) do
            local parts = {}
            U.split(comp, parts)
            for _, part in ipairs(parts) do
              job.n_comp = job.n_comp + 1
              job.queue[#job.queue + 1] = { t = "bus", item = task.item, comp = part }
            end
          end
          task.list = nil
        else
          -- tâche « bus » : une passe par unité (l'état est gardé dans la tâche)
          task.st = task.st or Rg.bus_start(task.comp, job.opts)
          if Rg.bus_step(task.st, job.opts) then
            job.qi = job.qi + 1
            local bus, why = task.st.bus, task.st.why
            if bus then
              job.cands[#job.cands + 1] = bus
              -- les terminaux laissés par ce bus forment, s'ils portent producteur et consommateur, une composante résiduelle (un autre bus)
              local taken = {}
              for _, t in ipairs(bus.taps) do taken[t.kind .. t.key] = true end
              local rest = {}
              for _, t in ipairs(task.comp) do if not taken[t.kind .. t.key] then rest[#rest + 1] = t end end
              local np, nc = U.count_kinds(rest)
              if np > 0 and nc > 0 and (task.depth or 1) < Rg.DEPTH_MAX then
                job.queue[#job.queue + 1] = { t = "bus", item = task.item, comp = rest, depth = (task.depth or 1) + 1 }
              end
            else
              reject(job, task.item .. " : " .. tostring(why))
            end
            task.comp, task.st = nil, nil
          end
        end
      end
    else -- select
      left = left - 1
      job.result = Rg.finish(job)
      job.phase = "done"
    end
  end
  return job.phase == "done"
end

--- Choix final et statistiques.
function Rg.finish(job)
  local o = job.opts
  local run, which = choose(job.cands, o.k, o.budget, o)
  -- ordre de pose : fichier par fichier (la valeur nette par coût de la voie de base d'abord ; la voie qui PARTAGE le tronc après celle qui le
  -- pose), puis voie par voie
  local picks = copy(run.picks)
  local dens = {}
  for _, p in ipairs(picks) do
    if p.lane == 1 then dens[p.belt] = p.mnet / math.max(1, p.c.pay_s) end
  end
  table.sort(picks, function(a, b)
    if a.belt ~= b.belt then
      if dens[a.belt] ~= dens[b.belt] then return dens[a.belt] > dens[b.belt] end
      return a.belt < b.belt
    end
    return a.lane < b.lane
  end)
  local buses, links, belt_id, belt_list = {}, {}, {}, {}
  local served, gain, tiles, plaques, crossed = 0, 0, 0, 0, 0
  for i, p in ipairs(picks) do
    local c = p.c
    if not belt_id[p.belt] then belt_list[#belt_list + 1] = p.belt; belt_id[p.belt] = #belt_list end
    local b = { id = i, item = c.item, belt = belt_id[p.belt], lane = p.lane, axis = c.axis, sign = c.sign, line = c.line, lo = c.lo, hi = c.hi,
      tiles = c.tiles, shared_tiles = math.ceil(p.ov * Rg.DETOUR), plaques = p.mplaq, served = c.served, gain = c.gain,
      payback_min = c.payback_min, net = p.mnet, n_prod = c.n_prod, n_cons = c.n_cons, taps = c.taps, crossings = p.nx }
    buses[i] = b
    served, gain, plaques = served + c.served, gain + c.gain, plaques + p.mplaq
    crossed = crossed + p.nx
    tiles = tiles + c.tiles - b.shared_tiles
    for j, t in ipairs(c.taps) do
      links[#links + 1] = { bus = i, belt = b.belt, item = c.item, key = t.key, kind = t.kind, x = t.x, y = t.y, order = j, contrib = t.contrib }
    end
  end
  local belts = {}
  for bi, raw in ipairs(belt_list) do
    local b = run.belts[raw]
    local lanes = {}
    for _, bus in ipairs(buses) do if bus.belt == bi then lanes[#lanes + 1] = bus.id end end
    belts[bi] ={ id = bi, axis = b.axis, sign = b.sign, line = b.line, lo = b.lo, hi = b.hi, lanes = lanes }
  end
  return { buses = buses, belts = belts, links = links, which = which,
    stats = { demand = job.demand, supply = job.supply, served = served, share = job.demand > 0 and served / job.demand or 0,
      ceiling = job.ceiling, ceiling_share = job.ceiling > 0 and served / job.ceiling or 0, gain_s_min = gain, pnj_equiv = gain / 60,
      trips_avoided_min = served / Rg.FILL_BATCH + served / Rg.COLLECT_BATCH, plaques = plaques, tiles = tiles, belts = #belts, buses = #buses,
      components = job.n_comp, candidates = #job.cands, crossings = crossed, rejects = job.rejects } }
end

function Rg.result(job) return job.result end

--- Nombre de files (« k bus ») permises : une de plus toutes les Rg.EPOCH_STEP époques (au moins 1 dès qu'il y a du tapis), bornée par le stock
--- de tapis du QG (Rg.BELT_TILES tuiles par file). epoch : 0 à 14 (X0) ; belt_stock : tapis au coffre. Proposition NON MESURÉE.
function Rg.k_for(epoch, belt_stock)
  local cap = 1 + math.floor(math.max(0, epoch or 0) / Rg.EPOCH_STEP)
  local by_stock = math.floor(math.max(0, belt_stock or 0) / Rg.BELT_TILES)
  return math.max(0, math.min(cap, by_stock))
end

--- Adaptateur du registre des coffres du lot MINAGE-MAIN (`require("script.team.sources").list(f)`, lecture seule) : liste d'entrées
--- { uid, x, y, surface, kind = "sortie" | "entree" | "neutre", rate = { [objet] = objets/min } } (rate absent : pas de débit mesuré, l'entrée
--- est écartée). Rend producers, consommateurs, nombre d'entrées écartées. Une sortie donne un producteur par objet, une entrée un consommateur.
function Rg.terminals_from_sources(list, surface)
  local P, C, skipped = {}, {}, 0
  for _, e in ipairs(list or {}) do
    local rate = e.rate
    if (surface and e.surface ~= surface) or type(rate) ~= "table" or (e.kind ~= "sortie" and e.kind ~= "entree") then
      skipped = skipped + 1
    else
      local items = {}
      for item in next, rate do items[#items + 1] = item end
      table.sort(items)
      for _, item in ipairs(items) do
        local t = { key = tostring(e.uid) .. ":" .. item, item = item, x = e.x, y = e.y, rate = rate[item] }
        if e.kind == "sortie" then P[#P + 1] = t else C[#C + 1] = t end
      end
    end
  end
  return P, C, skipped
end

--- Tout d'un coup (bancs hors jeu, petites instances).
function Rg.plan(inp, dist)
  local job = Rg.begin(inp)
  Rg.step(job, nil, dist)
  return job.result
end

-- Pour le banc hors jeu seulement (comparaison à l'optimum, mutants) : jamais appelé par le mod.
Rg._internals.choose, Rg._internals.select_run = choose, select_run

return Rg
