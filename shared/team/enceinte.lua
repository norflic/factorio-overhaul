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

  4. CONTOUR SERRÉ (lot ENCEINTE3, 29/10, retour du DC sur Azur : « ils ont vraiment placé super loin ») : l'anneau n'est plus au-delà
  du treillis ENTIER (rayon figé) mais sur l'EMPREINTE réelle de la base : lots pris ou planifiés, lot du QG, tourelles, plus
  E.MARGIN tuiles (E.tight_bounds). Les bornes { x0, y0, x1, y1 } sont figées avec le rayon au premier segment (b.enc.bounds) ;
  une enceinte d'une sauvegarde d'avant n'en a pas et garde l'anneau du rayon (E.bounds). Les lots ou tourelles ISOLÉS (plus de
  E.ISOLATED_GAP tuiles de l'empreinte) restent dehors ; E.ROOM_LOTS lots libres restent dedans ; les lots libres que le mur coupe
  ou laisse dehors ne reçoivent plus de module (drapeau `out`, script/team/build.lua). Chaque segment démarre au bout de son tronçon
  le plus proche de la menace connue de son côté, à défaut du QG (E.run_refs, E.next_segment), jamais dans un coin.

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
E.LOT = 24                -- côté d'un lot (shared/team/plan.lua : P.LOT)
E.MARGIN = 9              -- (lot ENCEINTE3) tuiles libres entre l'EMPREINTE de la base et le mur du contour serré (8 à 10 demandées)
E.ISOLATED_GAP = 36       -- (lot ENCEINTE3) un lot ou une tourelle à plus de 36 tuiles (Chebyshev) de l'empreinte est ISOLÉ : dehors du contour
E.ROOM_LOTS = 4           -- (lot ENCEINTE3) lots libres les plus proches gardés DANS le contour (de quoi bâtir encore ; le rayon est figé)

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
      and not (l.bad and l.bad >= 2) and not l.out then
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
--- `tight` (lot ENCEINTE3) : bornes { x0, y0, x1, y1 } d'un contour serré (E.tight_bounds), figées à la première demande ;
--- elles remplacent le rayon (une enceinte d'une sauvegarde d'avant n'en a pas : le rayon, comme avant).
function E.bounds(lat, r, gap, tight)
  if tight then return tight[1], tight[2], tight[3], tight[4] end
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
  local x0, y0, x1, y1 = E.bounds(lat, r, opts.gap, opts.bounds)
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
  if opts.bounds then
    -- contour serré (rectangle, pas forcément carré) : 2 (largeur + hauteur) - 4 tuiles, moins les ouvertures
    local x0, y0, x1, y1 = E.bounds(nil, r, nil, opts.bounds)
    return 2 * ((x1 - x0 + 1) + (y1 - y0 + 1)) - 4 - 4 * #(opts.mains or E.MAIN_STREETS) * E.STREET
  end
  local h = E.PITCH * r + E.HALF + E.STREET + (opts.gap or E.GAP)
  local side = 2 * h + 2
  return 4 * (side - 1) - 4 * #(opts.mains or E.MAIN_STREETS) * E.STREET
end

---------------------------------------------------------------------------------------------------
-- Lot ENCEINTE3 : contour SERRÉ sur l'empreinte réelle de la base
---------------------------------------------------------------------------------------------------
-- Retour du DC (29/10, Azur) : « ils ont investi dedans, par contre ils ont vraiment placé super loin […] si on devait placer
-- des murs pour protéger notre base, on s'attendrait pas à les mettre aussi loin ». L'anneau était posé au-delà du treillis
-- ENTIER (rayon figé, ici 235..442 autour du QG (339, 339) : 103 tuiles du QG) alors que la base n'occupait que quelques lots.
-- Le contour serré est le rectangle de l'empreinte (lots pris ou planifiés, lot du QG, tourelles) plus E.MARGIN tuiles.
-- Un lot ou une tourelle ISOLÉ (à plus de E.ISOLATED_GAP tuiles de l'empreinte, qui grandit de proche en proche) reste DEHORS
-- du contour (avant-poste lointain, mine) : il ne tire pas le mur vers lui. Les ouvertures des rues principales restent
-- dans le contour par construction (le lot du QG est dans l'empreinte et E.MARGIN > E.STREET).

--- Écart de Chebyshev entre un rectangle { x0, y0, x1, y1 } (fin exclue) et une boîte { bx0, by0, bx1, by1 } (fin exclue) : 0 si
--- elles se touchent ou se recouvrent.
local function box_gap(r, bx0, by0, bx1, by1)
  local dx = math.max(r.x0 - bx1, bx0 - r.x1, 0)
  local dy = math.max(r.y0 - by1, by0 - r.y1, 0)
  return math.max(dx, dy)
end

--- Lot (i, j) du treillis : rectangle { x0, y0, x1, y1 } (fin exclue), même repère que P.lot_rect.
function E.lot_box(lat, i, j)
  local x0, y0 = lat.ox + E.PITCH * i - E.HALF, lat.oy + E.PITCH * j - E.HALF
  return { x0 = x0, y0 = y0, x1 = x0 + E.LOT, y1 = y0 + E.LOT }
end

--- Contour serré. `rects` : empreinte candidate { { x0, y0, x1, y1 (fin exclue), ... } ... } (lots pris ou planifiés, tourelles) ;
--- `room` : lots LIBRES candidats { { x0, y0, x1, y1, k } ... } dont les E.ROOM_LOTS plus proches de l'empreinte sont gardés.
--- Le lot du QG est toujours dans l'empreinte. Rend ({ x0, y0, x1, y1 } = tuiles du mur, incluses, ou nil si la graine manque), info
--- = { core = nombre de rectangles gardés, excluded = { rectangles isolés }, room = nombre de lots libres gardés, box = { bx0, by0,
--- bx1, by1 } l'empreinte (fin exclue) }. Déterministe : le point fixe de la croissance ne dépend pas de l'ordre des rectangles ;
--- les lots libres sont départagés par écart puis par clé.
function E.tight_bounds(lat, rects, room, opts)
  opts = opts or {}
  local gap = opts.isolated_gap or E.ISOLATED_GAP
  local margin = opts.margin or E.MARGIN
  local seed = E.lot_box(lat, 0, 0)
  local bx0, by0, bx1, by1 = seed.x0, seed.y0, seed.x1, seed.y1
  local kept = {}
  -- croissance de proche en proche jusqu'au point fixe : un rectangle à moins de `gap` de la boîte courante la rejoint
  local function grow()
    local changed = true
    while changed do
      changed = false
      for i, r in ipairs(rects or {}) do
        if not kept[i] and box_gap(r, bx0, by0, bx1, by1) <= gap then
          kept[i] = true
          changed = true
          bx0, by0 = math.min(bx0, r.x0), math.min(by0, r.y0)
          bx1, by1 = math.max(bx1, r.x1), math.max(by1, r.y1)
        end
      end
    end
  end
  grow()
  -- de la place pour bâtir encore : les lots libres les plus proches de l'empreinte (à portée d'elle seulement)
  local cand = {}
  for _, r in ipairs(room or {}) do
    local g = box_gap(r, bx0, by0, bx1, by1)
    if g <= gap then cand[#cand + 1] = { r = r, g = g, k = tostring(r.k or "") } end
  end
  table.sort(cand, function(a, b) if a.g ~= b.g then return a.g < b.g end return a.k < b.k end)
  local kept_room = 0
  for i = 1, math.min(opts.room_lots or E.ROOM_LOTS, #cand) do
    local r = cand[i].r
    bx0, by0 = math.min(bx0, r.x0), math.min(by0, r.y0)
    bx1, by1 = math.max(bx1, r.x1), math.max(by1, r.y1)
    kept_room = kept_room + 1
  end
  -- les lots libres ont pu rapprocher la boîte d'un rectangle isolé : il la rejoint alors (jamais coupé par le mur)
  grow()
  local excluded, core = {}, 0
  for i, r in ipairs(rects or {}) do
    if kept[i] then core = core + 1 else excluded[#excluded + 1] = r end
  end
  return { bx0 - margin - 1, by0 - margin - 1, bx1 + margin, by1 + margin },
    { core = core, excluded = excluded, room = kept_room, box = { bx0, by0, bx1, by1 } }
end

--- Le rectangle { x0, y0, x1, y1 } (fin exclue) est-il entièrement à l'INTÉRIEUR du contour (les tuiles du mur exclues) ?
function E.inside(bounds, r)
  return r.x0 >= bounds[1] + 1 and r.y0 >= bounds[2] + 1 and r.x1 <= bounds[3] and r.y1 <= bounds[4]
end

--- Les ouvertures des rues principales tiennent-elles dans les bornes ? (invariant du contour serré ; jamais faux avec le lot du QG
--- dans l'empreinte.)
function E.gates_inside(lat, bounds, mains)
  mains = mains or E.MAIN_STREETS
  for _, m in ipairs(mains) do
    local ax, ay = lat.ox + E.PITCH * m + E.HALF, lat.oy + E.PITCH * m + E.HALF
    if ax < bounds[1] or ax + E.STREET - 1 > bounds[3] or ay < bounds[2] or ay + E.STREET - 1 > bounds[4] then return false end
  end
  return true
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

--- Point de référence de chaque tronçon (lot ENCEINTE3, lot A) : la menace connue la plus proche du milieu du tronçon, parmi celles
--- de SON côté ; à défaut, le QG (centre du treillis). Le segment d'un tronçon démarre au bout le plus proche de ce point, jamais
--- dans un coin au hasard de l'ordre de pose. Rend { [id du tronçon] = { x, y } }.
function E.run_refs(runs, lat, threats)
  local by_side = { n = {}, e = {}, s = {}, o = {} }
  for _, t in ipairs(threats or {}) do
    local sd = E.side_of(lat, t.x, t.y)
    by_side[sd][#by_side[sd] + 1] = t
  end
  local refs = {}
  for _, run in ipairs(runs) do
    local best, bd = nil, math.huge
    for _, t in ipairs(by_side[run.side]) do
      local d = (t.x - run.mx) ^ 2 + (t.y - run.my) ^ 2
      if d < bd then best, bd = t, d end
    end
    refs[run.id] = best and { x = best.x, y = best.y } or { x = lat.ox + 0.5, y = lat.oy + 0.5 }
  end
  return refs
end

--- Prochain segment : un bloc de murs NON réservés d'un tronçon, par ordre de priorité, de `cap` murs au plus.
--- Rend { run, side, walls = { {tx, ty, x, y, side} ... } } ou (nil, "complet") quand tout est réservé, (nil, "stock") quand
--- le plafond `cap` ne permet aucun segment d'au moins min(E.SEG_MIN, bloc) murs. `claimed` : { [E.key] = true }.
--- `refs` (facultatif, E.run_refs) : dans un tronçon, les blocs libres sont pris du plus proche du point de référence au plus loin,
--- et un segment plus court que son bloc démarre par le bout le PLUS PROCHE de ce point (les murs sont rendus de ce bout vers
--- l'autre). Sans `refs` : le premier bloc du tronçon, par son début (comportement d'avant ENCEINTE3).
function E.next_segment(runs, order, claimed, cap, refs)
  local why = "complet"
  for _, ri in ipairs(order) do
    local run = runs[ri]
    local n = #run.walls
    local ref = refs and refs[ri] or nil
    local blocks = {}
    local i = 1
    while i <= n do
      local w = run.walls[i]
      if claimed[E.key(w.tx, w.ty)] then
        i = i + 1
      else
        local j = i
        while j < n and not claimed[E.key(run.walls[j + 1].tx, run.walls[j + 1].ty)] do j = j + 1 end
        local b = { i = i, j = j }
        if ref then
          local a, z = run.walls[i], run.walls[j]
          b.da = (a.x - ref.x) ^ 2 + (a.y - ref.y) ^ 2
          b.dz = (z.x - ref.x) ^ 2 + (z.y - ref.y) ^ 2
          b.d = math.min(b.da, b.dz)
        end
        blocks[#blocks + 1] = b
        i = j + 1
      end
    end
    if ref then
      table.sort(blocks, function(p, q) if p.d ~= q.d then return p.d < q.d end return p.i < q.i end)
    end
    for _, b in ipairs(blocks) do
      local len = b.j - b.i + 1
      local take = math.min(cap, len, E.SEG_MAX)
      if take >= 1 and take >= math.min(E.SEG_MIN, len) then
        local out = {}
        if ref and b.dz < b.da then
          for k = b.j, b.j - take + 1, -1 do out[#out + 1] = run.walls[k] end
        else
          for k = b.i, b.i + take - 1 do out[#out + 1] = run.walls[k] end
        end
        return { run = ri, side = run.side, walls = out }
      end
      why = "stock"
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
