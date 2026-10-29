--[[
  ESPACE ET ENCEINTE des équipes de PNJ (lot ESPACE, 29/10, remarque 5 du DC : « gestion de l'espace (construire vers
  l'extérieur) » et enceinte de murailles). Lua PUR : aucune API du jeu, aucun nom d'objet ; lu hors jeu
  (tests/enceinte_test.lua) et en jeu (script/team/build.lua, Build.space_step, qui fait les relevés du moteur).

  1. CROISSANCE : le carré de lots grandit d'un cran quand la place LIBRE dans le rayon actuel passe sous un seuil, que
     tout le rayon est évalué, que l'équipe n'est pas surchargée de chantiers et qu'elle a déjà fini un projet.
  2. ENCEINTE : quand la base a fini E.MIN_PROJECTS projets et que la croissance n'est plus voulue (assez de place libre,
     ou rayon maximal), un anneau de murs d'une tuile est posé à E.GAP tuiles AU-DELÀ du treillis (jamais dedans : les
     lots, rues, tapis et poteaux du plan ne croisent jamais l'anneau). Des OUVERTURES de la largeur d'une rue (4)
     sont laissées dans l'anneau en prolongement des rues principales (celles qui bordent le lot du QG) : les PNJ, les
     tapis et les poteaux passent, et l'anneau ne referme jamais l'équipe sur elle-même. Le rayon est ensuite FIGÉ
     (voir Build.grow) : un lot posé après l'anneau serait dehors, ou l'anneau couperait un lot.

  Géométrie (tuiles entières, repère du treillis de shared/team/plan.lua) : le treillis de rayon r couvre en x et en y les
  tuiles [ox - (28 r + 16), ox + 28 r + 15] (lots de 24, rues de 4, pas de 28). Le mur est sur la tuile
  ox - (28 r + 16) - GAP - 1 à l'ouest et ox + 28 r + 16 + GAP à l'est (idem en y).

  3. SEGMENTS (lot ENCEINTE2, 29/10) : l'anneau entier coûtait ~800 murs (4 000 briques) d'un coup, donc il ne se posait
     jamais. L'enceinte est maintenant PARTIELLE et PROGRESSIVE : l'anneau est découpé en TRONÇONS continus (entre les
     ouvertures, par côté), classés par menace connue (côté tourné vers les nids et vers vus, puis le plus proche du
     nid), et posé SEGMENT par SEGMENT (un seul en cours), chaque segment payé sur le stock disponible : jamais plus de
     un quart du stock de murs (ou de ce que ses ingrédients permettent de fabriquer) par segment, entre E.SEG_MIN et
     E.SEG_MAX murs. L'anneau est à E.GAP = 3 tuiles du treillis. Un segment dont les murs sont détruits est rouvert
     tout seul (script/team/build.lua). Le rayon est figé dès le premier segment demandé.

  Déterminisme : listes triées, aucun `pairs`, aucune trigonométrie.
]]

local E = {}

E.PITCH = 28
E.HALF = 12
E.STREET = 4

E.GAP = 3                 -- (lot ENCEINTE2 : 4 -> 3, le minimum utile) tuiles libres entre le bord du treillis et le mur
E.MAIN_STREETS = { -1, 0 } -- rues principales : rangées/colonnes -1 et 0 (celles qui bordent le lot (0, 0) du QG)
E.GROW_FREE_MIN = 3       -- croissance quand moins de 3 lots libres (et utilisables) dans le rayon
E.BUSY_MAX = 2            -- … et au plus 2 chantiers en cours
E.MIN_PROJECTS = 5        -- projets finis avant de murer
E.CHECK_TICKS = 1800      -- période (ticks) des décisions de croissance et d'enceinte (30 s)
E.REPAIR_TICKS = 18000    -- période (ticks) du contrôle des murs détruits (5 min)
E.REPAIR_BATCH = 200      -- murs contrôlés par passe
E.RETRY_TICKS = 108000    -- après un refus du plan de l'enceinte : nouvel essai 30 min plus tard
E.SEG_MAX = 40            -- murs au plus par segment
E.SEG_MIN = 8             -- murs au moins par segment (sauf le reste d'un tronçon, plus court)
E.STOCK_DIV = 4           -- un segment coûte au plus 1/4 du stock de murs (en équivalent : murs + fabricables)
E.SEG_RETRY_TICKS = 18000 -- segment refusé pour la place ou annulé faute de matière : nouvel essai 5 min plus tard
E.THREAT_RANGE = 300      -- nids et vers connus pris en compte : à moins de 300 tuiles (Chebyshev) du QG
E.W_NEST = 3              -- poids d'un nid dans la menace d'un côté
E.W_WORM = 1              -- poids d'un ver
E.SIDES = { "n", "e", "s", "o" } -- ordre des côtés à menace égale
E.RESERVE_TICKS = 18000   -- enceinte restée 5 min « en réserve » sans ses murs (briques prises ailleurs) : annulée, rayon libéré

local function sorted_keys(t)
  local out = {}
  for k in next, t do out[#out + 1] = k end
  table.sort(out)
  return out
end

--- Lots utilisables par un module (libres ou à défricher, ni pris ni écartés par des échecs), le lot du QG excepté.
function E.free_count(lots)
  local n = 0
  for _, k in ipairs(sorted_keys(lots or {})) do
    local l = lots[k]
    if not (l.i == 0 and l.j == 0) and not l.used and (l.state == "libre" or l.state == "defricher")
      and not (l.bad and l.bad >= 2) then
      n = n + 1
    end
  end
  return n
end

--- La croissance est-elle voulue ? info = { radius, rmax, pending (évaluations en file), free, busy, done, enc }.
--- Rend (vrai) ou (faux, raison).
function E.grow_due(info)
  if info.enc then return false, "enceinte" end
  if info.radius >= info.rmax then return false, "rayon maximal" end
  if (info.pending or 0) > 0 then return false, "evaluation en cours" end
  if (info.free or 0) >= E.GROW_FREE_MIN then return false, "place libre" end
  if (info.busy or 0) > E.BUSY_MAX then return false, "chantiers en cours" end
  if (info.done or 0) < 1 then return false, "rien de fini" end
  return true
end

--- L'enceinte est-elle voulue ? Même info. Elle attend que la croissance ne soit plus voulue pour de la PLACE
--- (le seul motif qui ne dépend pas de l'économie : place libre suffisante ou rayon maximal).
function E.enclosure_due(info)
  if info.enc then return false, "deja" end
  if (info.pending or 0) > 0 then return false, "evaluation en cours" end
  if (info.done or 0) < E.MIN_PROJECTS then return false, "base trop jeune" end
  if info.radius < info.rmax and (info.free or 0) < E.GROW_FREE_MIN then return false, "croissance voulue" end
  return true
end

--- Une enceinte pas encore finie reste-t-elle bloquée en réserve (matière absente) depuis assez longtemps pour être
--- annulée ? Le rayon est figé dès la demande : sans cette sortie, des briques dépensées ailleurs le figeraient pour toujours.
--- Jamais pour une enceinte déjà finie (finished non nil) : annuler sa réparation libérerait le rayon et provoquerait une
--- seconde enceinte dont l'anneau couperait les lots du nouveau rayon.
function E.reserve_stalled(state, started, finished, tick)
  return finished == nil and state == "reserve" and started ~= nil and tick - started >= E.RESERVE_TICKS
end

--- Bornes de l'anneau (tuiles du mur, incluses) pour un treillis ancré en lat = { ox, oy } et de rayon r.
function E.bounds(lat, r, gap)
  gap = gap or E.GAP
  local h = E.PITCH * r + E.HALF + E.STREET + gap
  return lat.ox - h - 1, lat.oy - h - 1, lat.ox + h, lat.oy + h
end

--- Tuile de l'axe (x ou y relatif au QG) dans l'ouverture d'une rue principale ? `o` : origine du treillis sur l'axe.
local function in_gate(v, o, mains)
  for _, m in ipairs(mains) do
    local a = o + E.PITCH * m + E.HALF
    if v >= a and v < a + E.STREET then return true end
  end
  return false
end

--- Anneau de murs : { walls = { { tx, ty, x, y, side } ... }, gates = nombre de tuiles laissées ouvertes,
--- skipped = { [raison] = nombre } }. `skip(tx, ty)` (facultatif) rend une raison (chaîne) pour une tuile à ne pas murer
--- (eau, ressource, bâtiment, tuile réservée), sinon nil. Ordre : côté nord, côté sud, ouest, est (puis x, y croissants).
function E.ring(lat, r, opts)
  opts = opts or {}
  local x0, y0, x1, y1 = E.bounds(lat, r, opts.gap)
  local mains = opts.mains or E.MAIN_STREETS
  local out = { walls = {}, gates = 0, skipped = {}, bounds = { x0, y0, x1, y1 } }
  local function add(tx, ty, side, gate)
    if gate then out.gates = out.gates + 1 return end
    local why = opts.skip and opts.skip(tx, ty) or nil
    if why then out.skipped[why] = (out.skipped[why] or 0) + 1 return end
    out.walls[#out.walls + 1] = { tx = tx, ty = ty, x = tx + 0.5, y = ty + 0.5, side = side }
  end
  for tx = x0, x1 do add(tx, y0, "n", in_gate(tx, lat.ox, mains)) end
  for tx = x0, x1 do add(tx, y1, "s", in_gate(tx, lat.ox, mains)) end
  for ty = y0 + 1, y1 - 1 do add(x0, ty, "o", in_gate(ty, lat.oy, mains)) end
  for ty = y0 + 1, y1 - 1 do add(x1, ty, "e", in_gate(ty, lat.oy, mains)) end
  return out
end

--- Murs d'un anneau sans obstacle (borne haute du coût) : périmètre moins les tuiles d'ouverture.
function E.max_walls(r, opts)
  opts = opts or {}
  local h = E.PITCH * r + E.HALF + E.STREET + (opts.gap or E.GAP)
  local side = 2 * h + 2
  return 4 * (side - 1) - 4 * #(opts.mains or E.MAIN_STREETS) * E.STREET
end

---------------------------------------------------------------------------------------------------
-- Lot ENCEINTE2 : tronçons, menace, segments
---------------------------------------------------------------------------------------------------

--- Clé d'une tuile de mur (chaîne ; propre à l'enceinte, pas celle de b.occ).
function E.key(tx, ty) return tx .. ":" .. ty end

--- Tuiles d'ouverture de l'anneau (4 côtés x rues principales x largeur de rue).
function E.gate_count(opts)
  opts = opts or {}
  return 4 * #(opts.mains or E.MAIN_STREETS) * E.STREET
end

--- Tronçons continus de l'anneau (coupés aux ouvertures et aux coins) : { { id, side, walls = {...}, mx, my } ... }, dans
--- l'ordre de E.ring (nord, sud, ouest, est). `mx, my` : le mur du milieu (centre de la tuile). Rend aussi l'anneau.
function E.runs(lat, r, opts)
  local ring = E.ring(lat, r, opts)
  local runs, cur = {}, nil
  for _, w in ipairs(ring.walls) do
    local prev = cur and cur.walls[#cur.walls]
    if not (prev and prev.side == w.side and math.abs(w.tx - prev.tx) + math.abs(w.ty - prev.ty) == 1) then
      cur = { id = #runs + 1, side = w.side, walls = {} }
      runs[#runs + 1] = cur
    end
    cur.walls[#cur.walls + 1] = w
  end
  for _, run in ipairs(runs) do
    local m = run.walls[math.ceil(#run.walls / 2)]
    run.mx, run.my = m.x, m.y
  end
  return runs, ring
end

--- Côté de l'anneau tourné vers le point (x, y), vu du centre du treillis : axe dominant (égalité : nord/sud).
function E.side_of(lat, x, y)
  local dx, dy = x - lat.ox, y - lat.oy
  if math.abs(dy) >= math.abs(dx) then return dy < 0 and "n" or "s" end
  return dx < 0 and "o" or "e"
end

--- Menaces connues d'une carte de connaissance (secteurs `s[clé] = { sp = { {x,y} }, wm = { {x,y} } }`, shared/ai3/carte.lua) :
--- liste { { x, y, w } ... } des nids (E.W_NEST) et vers (E.W_WORM) à moins de `range` tuiles (Chebyshev) du centre du treillis.
function E.known_threats(sectors, lat, range)
  local out = {}
  if not sectors then return out end
  range = range or E.THREAT_RANGE
  for _, k in ipairs(sorted_keys(sectors)) do
    local s = sectors[k]
    for _, kind in ipairs({ "sp", "wm" }) do
      for _, p in ipairs(s[kind] or {}) do
        if math.max(math.abs(p.x - lat.ox), math.abs(p.y - lat.oy)) <= range then
          out[#out + 1] = { x = p.x, y = p.y, w = kind == "sp" and E.W_NEST or E.W_WORM }
        end
      end
    end
  end
  return out
end

--- Ordre de pose des tronçons : liste d'identifiants. Clés, dans l'ordre : menace du côté (décroissante), distance du milieu
--- du tronçon à la menace la plus proche de CE côté (croissante), ordre fixe des côtés, identifiant. Sans menace connue :
--- l'ordre fixe seul (nord, est, sud, ouest).
function E.run_order(runs, lat, threats)
  local weight, side_idx = {}, {}
  for i, sd in ipairs(E.SIDES) do weight[sd] = 0; side_idx[sd] = i end
  local by_side = { n = {}, e = {}, s = {}, o = {} }
  for _, t in ipairs(threats or {}) do
    local sd = E.side_of(lat, t.x, t.y)
    weight[sd] = weight[sd] + (t.w or 1)
    by_side[sd][#by_side[sd] + 1] = t
  end
  local near, side_of_run, ids = {}, {}, {}
  for _, run in ipairs(runs) do
    local best = math.huge
    for _, t in ipairs(by_side[run.side]) do
      local d = (t.x - run.mx) ^ 2 + (t.y - run.my) ^ 2
      if d < best then best = d end
    end
    near[run.id], side_of_run[run.id] = best, run.side
    ids[#ids + 1] = run.id
  end
  table.sort(ids, function(a, b)
    local sa, sb = side_of_run[a], side_of_run[b]
    if weight[sa] ~= weight[sb] then return weight[sa] > weight[sb] end
    if near[a] ~= near[b] then return near[a] < near[b] end
    if sa ~= sb then return side_idx[sa] < side_idx[sb] end
    return a < b
  end)
  return ids
end

--- Taille permise d'un segment pour un stock de `equiv` murs (murs en stock + fabricables) : au plus un quart du stock.
function E.segment_cap(equiv)
  return math.min(E.SEG_MAX, math.floor(math.max(0, equiv) / E.STOCK_DIV))
end

--- Prochain segment : le premier bloc de murs NON réservés d'un tronçon, par ordre de priorité, de `cap` murs au plus.
--- Rend { run, side, walls = { {tx, ty, x, y, side} ... } } ou (nil, "complet") quand tout est réservé, (nil, "stock") quand
--- le plafond `cap` ne permet aucun segment d'au moins min(E.SEG_MIN, bloc) murs. `claimed` : { [E.key] = true }.
function E.next_segment(runs, order, claimed, cap)
  local why = "complet"
  for _, ri in ipairs(order) do
    local run = runs[ri]
    local n = #run.walls
    local i = 1
    while i <= n do
      local w = run.walls[i]
      if claimed[E.key(w.tx, w.ty)] then
        i = i + 1
      else
        local j = i
        while j < n and not claimed[E.key(run.walls[j + 1].tx, run.walls[j + 1].ty)] do j = j + 1 end
        local len = j - i + 1
        local take = math.min(cap, len, E.SEG_MAX)
        if take >= 1 and take >= math.min(E.SEG_MIN, len) then
          local out = {}
          for k = i, i + take - 1 do out[#out + 1] = run.walls[k] end
          return { run = ri, side = run.side, walls = out }
        end
        why = "stock"
        i = j + 1
      end
    end
  end
  return nil, why
end

--- Réserve (ou libère, si `value` est nil) les tuiles d'une liste de murs { {tx, ty} ... } dans `claimed`.
function E.claim(claimed, walls, value)
  for _, w in ipairs(walls) do claimed[E.key(w.tx, w.ty)] = value end
end

--- Murs de l'anneau pas encore réservés.
function E.unclaimed(runs, claimed)
  local n = 0
  for _, run in ipairs(runs) do
    for _, w in ipairs(run.walls) do if not claimed[E.key(w.tx, w.ty)] then n = n + 1 end end
  end
  return n
end

--- Nombre de fabrications d'une recette que le stock permet. ings = { { name, amount } ... }, count(name) = stock.
function E.crafts_possible(ings, count)
  if #ings == 0 then return 0 end
  local best
  for _, ing in ipairs(ings) do
    local n = math.floor(count(ing.name) / math.max(1, ing.amount))
    if not best or n < best then best = n end
  end
  return best or 0
end

--- Murs en stock, plus ceux que les ingrédients du stock permettent de fabriquer : de quoi payer `need` murs ?
function E.affordable(need, walls_in_stock, craftable)
  return walls_in_stock + craftable >= need
end

--- Fabrications à lancer pour `missing` murs d'une recette qui en rend `per_craft` : au plus `possible`.
function E.crafts_to_run(missing, per_craft, possible)
  if missing <= 0 or possible <= 0 then return 0 end
  return math.min(possible, math.ceil(missing / math.max(1, per_craft)))
end

return E
