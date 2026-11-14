--[[
  Lot INDUSTRIE I7 (LIAISONS) : la LIAISON DE QUAI. Règle PURE : aucune API du jeu, aucun nom d'objet ; lue hors jeu
  (tests/liaison_test.lua) et en jeu (script/team/liaison.lua).

  Règle du DC (11/11, ablation des navettes) : toute sortie de production reliée est un tapis continu, sans coffre de tamponnage en
  bout de chaîne, et tout raccordement plus court que la portée de la liaison (Li.MAX_SPAN) est posé en tapis direct, sans calcul de
  rentabilité. Le COFFRE DE SORTIE du module de départ disparaît : sa tuile devient la première tuile du tapis (le bras de sortie du
  module y dépose), puis tapis -> bras -> coffre du quai d'entrée.

  1. SITE (Li.sites, Li.pick_ends) : la tuile du coffre de sortie et une voisine libre ; contre le quai, un bras et un tapis dans le
     prolongement ; les paires de bouts les plus courtes d'abord.
  2. TRACÉ (Li.route_ok) : jamais plus de Li.MAX_LEN tuiles ni de détour au-delà de Li.DETOUR fois la distance ; un tracé coupé passe par
     une paire de souterrains (script/team/traversee.lua).
  3. ENTITÉS (Li.entities) et leur preuve géométrique (Li.verify : chaîne de tapis du coffre de sortie remplacé au bras du quai).
  4. APPARIEMENT (Li.pairs) : un quai (objet X) avec la sortie la plus proche qui porte X, à Li.MAX_SPAN tuiles au plus ; une sortie sert
     un seul quai. Toute paire est reliée (Li.decide : seulement la menace, l'ennemi et les PNJ libres font attendre).

  Déterminisme : listes triées, aucun `pairs` dans une décision, aucune trigonométrie, aucune horloge mesurée.
]]

local Li = {}

-- Relevé et décision (script/team/liaison.lua)
Li.PERIOD = 1800            -- ticks entre deux débuts de relevé (30 s)
Li.UNITS_PER_PULSE = 2      -- projets relevés par passe de Build (Build.PULSE = 5 ticks)
Li.MIN_OPEN = 1             -- liaison en construction toujours permise (les PNJ occupés finissent par se libérer) ; au-delà : Li.max_open
Li.CONFIRM = 2              -- relevés de suite où la paire est vue avant d'agir (lu par script/team/piquage.lua)
Li.MAX_TRIES = 2            -- essais au plus pour un même quai (lu par le piquage)
Li.RETRY_AFTER = 20 * 3600  -- ticks : essais épuisés, un essai de plus après 20 min (lu par le piquage)
Li.ENEMY_R = 28             -- tuiles : jamais de pose avec un ennemi à cette portée de l'un des deux coffres
Li.LOG_EVERY = 5 * 3600     -- une synthèse au plus par équipe et par 5 min (hors changement)

-- Géométrie
Li.MAX_SPAN = 40            -- tuiles : distance (Manhattan) maximale entre les deux coffres (un lot voisin : 28)
Li.MAX_LEN = 48             -- tuiles de tapis au plus
Li.DETOUR = 1.5             -- un tracé ne dépasse pas DETOUR x (Manhattan + 1) + DETOUR_SLACK tuiles
Li.DETOUR_SLACK = 6
Li.ROUTE_TRIES = 4          -- paires de bouts essayées au plus par plan
Li.EST_FACTOR = 1.3         -- longueur de tapis ESTIMÉE avant tracé : EST_FACTOR x distance + 2

-- Économie partagée (lue par le piquage, le rapatriement, le réseau de bus et le placement ; la liaison de quai n'en calcule plus)
Li.TMAX = 90                -- minutes : retour accepté (la menace divise par Li.THREAT_DIV)
Li.THREAT_DIV = 4
Li.WALK = 8                 -- tuiles par seconde
Li.HANDLE_S = 10            -- s de prise et de dépôt par aller-retour
Li.POSE_S = 1.5             -- s de pose par entité
Li.BATCH = 12               -- entités par aller-retour de chantier
Li.LABOR_VALUE = 1.0        -- plaques par PNJ-seconde (NON MESURÉ)
Li.PRICE = { belt = 1.5, arm = 5.5, pole = 2.0 }   -- plaques-équivalent par pièce (tapis, bras électrique, poteau 1 x 1)
Li.MIN_FLOW = 0.02          -- objets/s : sous ce débit un quai ne vaut aucune ligne

local DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }
Li.DV = DV
local DIRS = { 0, 2, 4, 6 }

local function dir_of(dx, dy)
  if dx == 0 and dy == -1 then return 0 end
  if dx == 1 and dy == 0 then return 2 end
  if dx == 0 and dy == 1 then return 4 end
  if dx == -1 and dy == 0 then return 6 end
  return nil
end
Li.dir_of = dir_of

local function opposite(d) return (d + 4) % 8 end

local function manhattan(ax, ay, bx, by) return math.abs(ax - bx) + math.abs(ay - by) end
Li.manhattan = manhattan

---------------------------------------------------------------------------------------------------
-- 1. Sites et bouts
---------------------------------------------------------------------------------------------------
--- Sites d'un coffre (tuile tx, ty) : pour chaque direction d, le bras sur la tuile voisine et la tuile de tapis derrière lui, toutes deux
--- libres (free(tx, ty) -> bool). Rend une liste { dir, ax, ay, bx, by } dans l'ordre N, E, S, O.
function Li.sites(tx, ty, free)
  local out = {}
  for _, d in ipairs(DIRS) do
    local v = DV[d]
    local ax, ay = tx + v[1], ty + v[2]
    local bx, by = ax + v[1], ay + v[2]
    if free(ax, ay) and free(bx, by) then out[#out + 1] = { dir = d, ax = ax, ay = ay, bx = bx, by = by } end
  end
  return out
end

--- s45 liaison-directe : pourquoi un coffre n'a aucun site. why(x, y) -> nom de la garde qui refuse la tuile (nil : libre).
--- Rend une chaîne « N:occ,E:libre/guard,... » (bras/tapis par côté, ordre N, E, S, O), pour le journal [FO-LIAISON].
function Li.block_report(tx, ty, why)
  local names, parts = { [0] = "N", [2] = "E", [4] = "S", [6] = "O" }, {}
  for _, d in ipairs(DIRS) do
    local v = DV[d]
    local ax, ay = tx + v[1], ty + v[2]
    parts[#parts + 1] = names[d] .. ":" .. (why(ax, ay) or "libre") .. "/" .. (why(ax + v[1], ay + v[2]) or "libre")
  end
  return table.concat(parts, ",")
end

--- Paires de bouts (site du coffre de départ S, site du coffre d'arrivée D), les plus courtes d'abord (Manhattan des deux tuiles de
--- tapis), départage par directions ; au plus `max`. Une paire où un bras tombe sur l'autre bras ou sur le tapis de l'autre est écartée.
--- src_sites : sites du départ (Li.sites par défaut).
function Li.pick_ends(S, D, free, max, src_sites)
  local ss, ds = (src_sites or Li.sites)(S.x, S.y, free), Li.sites(D.x, D.y, free)
  local out = {}
  for _, s in ipairs(ss) do
    for _, d in ipairs(ds) do
      local clash = (s.ax == d.ax and s.ay == d.ay) or (s.ax == d.bx and s.ay == d.by) or (d.ax == s.bx and d.ay == s.by)
      if not clash then
        out[#out + 1] = { src = s, dst = d, span = manhattan(s.bx, s.by, d.bx, d.by) }
      end
    end
  end
  table.sort(out, function(a, b)
    if a.span ~= b.span then return a.span < b.span end
    if a.src.dir ~= b.src.dir then return a.src.dir < b.src.dir end
    return a.dst.dir < b.dst.dir
  end)
  if max then while #out > max do out[#out] = nil end end
  return out
end

--- Direction de la dernière tuile de tapis : vers le bras d'arrivée.
function Li.end_dir(site) return opposite(site.dir) end

--- Tuile d'un poteau 1 x 1 contre le bras (tuile ax, ay, axe dir) : d'abord les deux côtés, puis les quatre diagonales ; libre (free) et
--- non prise (taken[clé]). Rend tx, ty ou nil. Un poteau de portée 2,5 couvre toutes ces tuiles.
Li.POLE_RING = 2 -- distance (tuiles) au bras de l'anneau de repli d'un poteau : le plus grand d entier avec d - 0,5 < supply_area_distance du petit poteau (2,5 : relu des donnees du jeu par tests/liaison_test.lua)
function Li.pole_tile(site, free, taken)
  local v = DV[site.dir]
  local px, py = v[2], -v[1]
  local cands = {
    { site.ax + px, site.ay + py }, { site.ax - px, site.ay - py },
    { site.ax + px + v[1], site.ay + py + v[2] }, { site.ax - px + v[1], site.ay - py + v[2] },
    { site.ax + px - v[1], site.ay + py - v[2] }, { site.ax - px - v[1], site.ay - py - v[2] },
  }
  for _, c in ipairs(cands) do
    if free(c[1], c[2]) and not (taken and taken[c[1] .. ":" .. c[2]]) then return c[1], c[2] end
  end
  -- lot RESEAU-GRAPHE : rangee dense, les six tuiles collees au bras sont prises ; un petit poteau couvre 5 x 5 (portee 2,5) : l'anneau de
  -- distance 2 alimente encore le bras, du plus proche au plus loin (ordre fixe : distance de Manhattan, puis x, puis y)
  local ring = {}
  local R = Li.POLE_RING
  for dx = -R, R do
    for dy = -R, R do
      if math.max(math.abs(dx), math.abs(dy)) == R then ring[#ring + 1] = { site.ax + dx, site.ay + dy, math.abs(dx) + math.abs(dy) } end
    end
  end
  table.sort(ring, function(a, z)
    if a[3] ~= z[3] then return a[3] < z[3] end
    if a[1] ~= z[1] then return a[1] < z[1] end
    return a[2] < z[2]
  end)
  for _, c in ipairs(ring) do
    if free(c[1], c[2]) and not (taken and taken[c[1] .. ":" .. c[2]]) then return c[1], c[2] end
  end
  return nil
end

--- Le tracé est-il acceptable ? len = nombre de tuiles, m = Manhattan des deux tuiles de tapis. Rend ok, raison.
function Li.route_ok(len, m)
  if len > Li.MAX_LEN then return false, string.format("tapis de %d tuiles > %d", len, Li.MAX_LEN) end
  local lim = Li.DETOUR * (m + 1) + Li.DETOUR_SLACK
  if len > lim then return false, string.format("detour de %d tuiles pour %d a vol d'oiseau (limite %.0f)", len, m + 1, lim) end
  return true, ""
end

---------------------------------------------------------------------------------------------------
-- 2. Entités et preuve
---------------------------------------------------------------------------------------------------
--- Entités d'une liaison. inp = { src = site de départ, dst = site d'arrivée, route = { {x, y, dir} } (tuiles entières, de la tuile de
--- départ à celle d'arrivée), names = { arm, belt, pole }, poles = { {tx, ty}, {tx, ty} } }. Centres de tuile (+ 0,5). Direction d'un bras :
--- vers sa prise (convention du plan directeur : P.feeder, P.out_quai). Rend une liste { name, x, y, dir, role }.
function Li.entities(inp)
  local out = {}
  local s, d = inp.src, inp.dst
  out[#out + 1] = { name = inp.names.arm, x = s.ax + 0.5, y = s.ay + 0.5, dir = opposite(s.dir), role = "liaison-bras" }
  for _, t in ipairs(inp.route) do
    if t.ug and inp.names.ug then
      -- lot TRAVERSEE : pièce d'une paire souterraine (type = "input" | "output", convention de build.lua)
      out[#out + 1] = { name = inp.names.ug, x = t.x + 0.5, y = t.y + 0.5, dir = t.dir, type = t.ug, role = "liaison-tapis" }
    else
      out[#out + 1] = { name = inp.names.belt, x = t.x + 0.5, y = t.y + 0.5, dir = t.dir, role = "liaison-tapis" }
    end
  end
  out[#out + 1] = { name = inp.names.arm, x = d.ax + 0.5, y = d.ay + 0.5, dir = d.dir, role = "liaison-bras" }
  for _, p in ipairs(inp.poles or {}) do
    out[#out + 1] = { name = inp.names.pole, x = p[1] + 0.5, y = p[2] + 0.5, dir = 0, role = "liaison" }
  end
  return out
end

--- Preuve géométrique d'une liste d'entités : la chaîne part du tapis posé sur S (liaison de quai : le coffre de sortie remplacé), sinon du
--- bras de départ qui prend au coffre S et dépose sur la première tuile ; chaque tuile mène à
--- la suivante ; la dernière mène au bras d'arrivée, qui prend à cette tuile et dépose dans le coffre D. S, D = { x, y } (tuiles entières).
--- isbelt(e), isarm(e) : prédicats sur une entité (le script les lit aux prototypes, le test aux rôles). Rend la liste des écarts (vide : juste).
function Li.verify(ents, S, D, isbelt, isarm)
  local bad = {}
  local belts, arms, count = {}, {}, 0
  local function key(x, y) return x .. ":" .. y end
  for _, e in ipairs(ents) do
    local tx, ty = math.floor(e.x), math.floor(e.y)
    if isbelt(e) then
      if belts[key(tx, ty)] then bad[#bad + 1] = "deux tapis sur " .. key(tx, ty) end
      belts[key(tx, ty)] = e
      count = count + 1
    elseif isarm(e) then
      arms[#arms + 1] = { tx = tx, ty = ty, dir = e.dir }
    end
  end
  local on_s = belts[key(S.x, S.y)] ~= nil
  local want = on_s and 1 or 2
  if #arms ~= want then bad[#bad + 1] = string.format("%d bras au lieu de %d", #arms, want) return bad end
  local function pick(a) local v = DV[a.dir]; return a.tx + v[1], a.ty + v[2] end
  local function drop(a) local v = DV[a.dir]; return a.tx - v[1], a.ty - v[2] end
  local first, last
  for _, a in ipairs(arms) do
    local px, py = pick(a)
    local dx, dy = drop(a)
    if px == S.x and py == S.y then first = a elseif dx == D.x and dy == D.y then last = a end
  end
  if not (first or on_s) then bad[#bad + 1] = "aucun bras ne prend au coffre de depart" return bad end
  if not last then bad[#bad + 1] = "aucun bras ne depose dans le coffre d'arrivee" return bad end
  local cx, cy = S.x, S.y
  if first then cx, cy = drop(first) end
  local n = 0
  while true do
    local e = belts[key(cx, cy)]
    if not e then bad[#bad + 1] = string.format("le tapis s'arrete en %s sans atteindre le bras d'arrivee", key(cx, cy)) return bad end
    n = n + 1
    if n > count then bad[#bad + 1] = "boucle de tapis" return bad end
    local v = DV[e.dir]
    local nx, ny = cx + v[1], cy + v[2]
    if belts[key(nx, ny)] then
      cx, cy = nx, ny
    else
      -- dernière tuile : elle doit mener au bras d'arrivée, qui y prend
      local px, py = pick(last)
      if nx ~= last.tx or ny ~= last.ty then bad[#bad + 1] = string.format("la derniere tuile %s ne mene pas au bras d'arrivee", key(cx, cy)) end
      if px ~= cx or py ~= cy then bad[#bad + 1] = "le bras d'arrivee ne prend pas sur la derniere tuile" end
      break
    end
  end
  if n ~= count then bad[#bad + 1] = string.format("%d tuile(s) de tapis hors de la chaine sur %d", count - n, count) end
  return bad
end

---------------------------------------------------------------------------------------------------
-- 3. Appariement
---------------------------------------------------------------------------------------------------
--- Quais d'entrée et coffres de sortie -> paires. docks = { { key, pid, x, y, item, flow, linked } }, srcs = { { key, pid, x, y, item,
--- linked } } (x, y : tuile du coffre). Un quai déjà relié ou un coffre déjà pris ne sert plus ; le coffre est d'un AUTRE projet que le
--- quai et porte le même objet, à Li.MAX_SPAN tuiles au plus (Manhattan) ; le plus proche (puis la clé la plus petite) l'emporte, les
--- quais de plus grand débit choisissent d'abord. Rend { { dock, src, span } } dans l'ordre de choix.
--- Coût : chaque quai ne parcourt que les coffres de SON objet (à 200 modules, un produit quais × coffres en un tick toutes les 30 s).
function Li.pairs(docks, srcs)
  local ds, ss = {}, {}
  for _, d in ipairs(docks) do if not d.linked and d.item then ds[#ds + 1] = d end end
  for _, s in ipairs(srcs) do if not s.linked and s.item then ss[#ss + 1] = s end end
  table.sort(ds, function(a, b)
    if (a.flow or 0) ~= (b.flow or 0) then return (a.flow or 0) > (b.flow or 0) end
    return a.key < b.key
  end)
  table.sort(ss, function(a, b) return a.key < b.key end)
  local by_item = {}
  for _, s in ipairs(ss) do
    by_item[s.item] = by_item[s.item] or {}
    table.insert(by_item[s.item], s)
  end
  local used, out = {}, {}
  for _, d in ipairs(ds) do
    local best, bspan
    for _, s in ipairs(by_item[d.item] or {}) do
      if not used[s.key] and s.pid ~= d.pid then
        local span = manhattan(s.x, s.y, d.x, d.y)
        if span <= Li.MAX_SPAN and (not bspan or span < bspan) then best, bspan = s, span end
      end
    end
    if best then
      used[best.key] = true
      out[#out + 1] = { dock = d, src = best, span = bspan }
    end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- 4. Décision d'une paire
---------------------------------------------------------------------------------------------------
--- Liaisons en construction permises à la fois : autant que de PNJ libres (`free` : sans tâche, ou sur la file sûre que tout préempte), au moins Li.MIN_OPEN.
--- Une borne écrite (1 à la fois) faisait passer 100 quais en série (AUDIT_PLAFONDS n° 22), quels que soient les bras disponibles.
function Li.max_open(free)
  return math.max(Li.MIN_OPEN, math.floor(free or 0))
end

--- inp = { open (la liaison de CE quai est en cours), open_total, free (PNJ libres, Li.max_open), enemies (nombre), threat (QG menacé) }.
--- Rend action ("relier" | "attendre"), raison. Aucune rentabilité, aucune confirmation, aucun essai compté : la paire est reliée.
function Li.decide(inp)
  if inp.open then return "attendre", "liaison deja en cours" end
  if inp.threat then return "attendre", "QG menace : le PNJ reste au QG, la liaison attend" end
  if (inp.enemies or 0) > 0 then return "attendre", string.format("ennemi a moins de %d tuiles", Li.ENEMY_R) end
  if (inp.open_total or 0) >= Li.max_open(inp.free) then
    return "attendre", string.format("%d liaison(s) deja ouverte(s), %d PNJ libre(s)", inp.open_total, inp.free or 0)
  end
  return "relier", "sortie a portee de tapis"
end

--- Barre du coffre d'entrée d'une liaison finie : la charge d'un aller-retour (fill objets) en cases, plus une ; le tapis ne le remplit pas en entier.
function Li.bar(fill, stack)
  local slots = math.max(1, math.ceil((fill or 400) / math.max(1, stack or 1)))
  return slots + 1
end

-- Prix d'un tapis en tournées économisées : la liaison de quai ne l'appelle plus ; lu par le piquage (shared/team/piquage.lua) et le réseau de bus.
--- Prix d'une liaison, en PNJ-secondes, contre le travail qu'elle économise.
--- inp = { flow (objets/s que consomme le quai), dist (tuiles du QG au quai), span (Manhattan des deux coffres), tiles (tapis ; nil :
---   estimé sur span), fill, low (Build.QUAI_FILL, Build.QUAI_LOW), tmax (minutes ; nil : Li.TMAX), threat (bool), labor (nil : Li.LABOR_VALUE),
---   price (nil : Li.PRICE) }.
--- Rend ok, raison, détail { trips_min, trip_s, labor_s_min, cost, build_s, pay_s, payback_min, tiles, tmax }.
function Li.worth(inp)
  local flow = inp.flow or 0
  if flow < Li.MIN_FLOW then return false, string.format("debit du quai %.3f/s : rien a economiser", flow), { payback_min = math.huge } end
  local span = inp.span or 0
  local tiles = inp.tiles or math.ceil(span * Li.EST_FACTOR + 2)
  local price = inp.price or Li.PRICE
  local labor = inp.labor or Li.LABOR_VALUE
  local per_trip = math.max(1, (inp.fill or 400) - (inp.low or 60))
  local trips_min = flow * 60 / per_trip
  local trip_s = 2 * (inp.dist or 56) / Li.WALK + Li.HANDLE_S
  local labor_s_min = trips_min * trip_s
  local cost = tiles * price.belt + 2 * price.arm + 2 * price.pole
  local n_ent = tiles + 4
  local build_s = n_ent * Li.POSE_S + math.ceil(n_ent / Li.BATCH) * trip_s
  local pay_s = cost / labor + build_s
  local payback = pay_s / labor_s_min
  local tmax = inp.tmax or Li.TMAX
  if inp.threat then tmax = tmax / Li.THREAT_DIV end
  local det = { trips_min = trips_min, trip_s = trip_s, labor_s_min = labor_s_min, cost = cost, build_s = build_s, pay_s = pay_s,
    payback_min = payback, tiles = tiles, tmax = tmax }
  if payback > tmax then
    return false, string.format("retour %.0f min > %.0f min (%.2f PNJ-s/min economisees, %d tuiles, cout %.0f)", payback, tmax, labor_s_min, tiles, cost), det
  end
  return true, string.format("retour %.0f min <= %.0f min (%.2f PNJ-s/min economisees, %d tuiles, cout %.0f)", payback, tmax, labor_s_min, tiles, cost), det
end

return Li
