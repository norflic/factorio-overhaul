--[[
  Lot INDUSTRIE I7 (LIAISONS) : la LIAISON DE QUAI. Règle PURE : aucune API du jeu, aucun nom d'objet ; lue hors jeu
  (tests/liaison_test.lua) et en jeu (script/team/liaison.lua).

  Demande du DC (31/10) : « l'automatisation du remplissage, et pas à devoir faire toujours tout par des IA "compagnon" qui n'auront
  pas forcément le temps ». Aujourd'hui un module fini se nourrit par `carry` : un PNJ porte les plaques du coffre du QG au coffre de
  son quai d'entrée (script/team/build.lua, quai_tasks), et rapporte les produits du coffre de sortie. Cela coûte du travail PNJ qui
  croît avec le nombre de modules.

  Idée (PLAN.md §4) : ne rien retirer. Tracer un tapis du coffre de SORTIE d'un module A au coffre d'ENTRÉE d'un module B du même objet :
  coffre -> bras -> tapis -> bras -> coffre. Le coffre d'entrée reste plein, donc quai_tasks n'émet plus rien ; le tapis coupé, le coffre
  baisse sous Build.QUAI_LOW et le PNJ reprend tout seul : le repli est celui qui existe déjà, sans une ligne de plus.

  1. DÉCISION DE PRIX (Li.worth) : le travail PNJ que la liaison économise par minute (allers-retours du quai : débit / charge portée x
     durée d'un aller-retour) contre ce qu'elle coûte (tapis, bras, poteaux, pose), le tout compté en PNJ-secondes avec un prix du travail
     TOUJOURS positif (Ca.labor_price vaut 0 dès qu'un bras est libre et bloquerait tout). On trace si le retour tient dans Tmax.
  2. SITE (Li.sites, Li.pick_ends) : un bras contre chaque coffre, un tapis qui part (ou arrive) dans le prolongement ; les paires de bouts
     les plus courtes d'abord.
  3. TRACÉ (Li.route_ok) : jamais plus de Li.MAX_LEN tuiles ni de détour au-delà de Li.DETOUR fois la distance (remarque du DC : « poteaux
     et tapis longs, détours de 4 à 5 fois » ; F251 : un PNJ loin du QG meurt, un long tapis se fait couper).
  4. ENTITÉS (Li.entities) et leur preuve géométrique (Li.verify : chaque bras prend et dépose où le modèle le dit).
  5. APPARIEMENT (Li.pairs) : un quai (objet X) avec le coffre de sortie le plus proche qui porte X ; un coffre de sortie sert un seul quai.
  6. BARRE (Li.bar) : le coffre d'entrée est bridé à la charge d'un aller-retour du PNJ (Build.QUAI_FILL), sinon le bras le remplirait en
     entier et viderait la sortie du module pour rien.

  Déterminisme : listes triées, aucun `pairs` dans une décision, aucune trigonométrie, aucune horloge mesurée.
]]

local Li = {}

-- Relevé et décision (script/team/liaison.lua)
Li.PERIOD = 1800            -- ticks entre deux débuts de relevé (30 s)
Li.UNITS_PER_PULSE = 2      -- projets relevés par passe de Build (Build.PULSE = 5 ticks)
Li.CONFIRM = 2              -- relevés de suite où la paire est vue avant d'agir
Li.MIN_OPEN = 1             -- liaison en construction toujours permise (les PNJ occupés finissent par se libérer) ; au-delà : Li.max_open
Li.MAX_TRIES = 2            -- liaisons tentées au plus pour un même quai
Li.RETRY_AFTER = 20 * 3600  -- ticks : essais épuisés, un essai de plus après 20 min
Li.DECIDE_MAX = 4           -- paires décidées au plus par relevé qui lisent le moteur (ennemis) ; les autres décisions sont pures
Li.ENEMY_R = 28             -- tuiles : jamais de pose avec un ennemi à cette portée de l'un des deux coffres
Li.LOG_EVERY = 5 * 3600     -- une synthèse au plus par équipe et par 5 min (hors changement)

-- Géométrie
Li.MAX_SPAN = 40            -- tuiles : distance (Manhattan) maximale entre les deux coffres (un lot voisin : 28)
Li.MAX_LEN = 48             -- tuiles de tapis au plus
Li.DETOUR = 1.5             -- un tracé ne dépasse pas DETOUR x (Manhattan + 1) + DETOUR_SLACK tuiles
Li.DETOUR_SLACK = 6
Li.EST_FACTOR = 1.3         -- longueur de tapis ESTIMÉE avant tracé : EST_FACTOR x distance + 2 (le tracé réel remplace l'estimation)
Li.ROUTE_TRIES = 4          -- paires de bouts essayées au plus par plan

-- Prix. Les durées sont celles de shared/ai3/automatiser.lua (A.WALK, A.HANDLE_S, A.POSE_S, A.BATCH : le test les compare).
Li.TMAX = 90                -- minutes : retour accepté d'une liaison (un tapis dure toute la partie, quelques heures ; la menace divise par Li.THREAT_DIV)
Li.THREAT_DIV = 4
Li.WALK = 8                 -- tuiles par seconde
Li.HANDLE_S = 10            -- s de prise et de dépôt par aller-retour
Li.POSE_S = 1.5             -- s de pose par entité
Li.BATCH = 12               -- entités par aller-retour de chantier
Li.LABOR_VALUE = 1.0        -- plaques par PNJ-seconde (NON MESURÉ, à calibrer à la partie de mesure I9 : un PNJ produit de l'ordre de 30 à 60 plaques par minute)
Li.PRICE = { belt = 1.5, arm = 5.5, pole = 2.0 }   -- plaques-équivalent par pièce (tapis, bras électrique, poteau 1 x 1)
Li.MIN_FLOW = 0.02          -- objets/s : sous ce débit un quai ne vaut aucune liaison

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
-- 1. Prix
---------------------------------------------------------------------------------------------------
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

---------------------------------------------------------------------------------------------------
-- 2. Sites et bouts
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

--- Paires de bouts (site du coffre de départ S, site du coffre d'arrivée D), les plus courtes d'abord (Manhattan des deux tuiles de
--- tapis), départage par directions ; au plus `max`. Une paire où un bras tombe sur l'autre bras ou sur le tapis de l'autre est écartée.
function Li.pick_ends(S, D, free, max)
  local ss, ds = Li.sites(S.x, S.y, free), Li.sites(D.x, D.y, free)
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
-- 3. Entités et preuve
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

--- Preuve géométrique d'une liste d'entités : le bras de départ prend au coffre S et dépose sur la première tuile ; chaque tuile mène à
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
  if #arms ~= 2 then bad[#bad + 1] = string.format("%d bras au lieu de 2", #arms) return bad end
  local function pick(a) local v = DV[a.dir]; return a.tx + v[1], a.ty + v[2] end
  local function drop(a) local v = DV[a.dir]; return a.tx - v[1], a.ty - v[2] end
  local first, last
  for _, a in ipairs(arms) do
    local px, py = pick(a)
    local dx, dy = drop(a)
    if px == S.x and py == S.y then first = a elseif dx == D.x and dy == D.y then last = a end
  end
  if not first then bad[#bad + 1] = "aucun bras ne prend au coffre de depart" return bad end
  if not last then bad[#bad + 1] = "aucun bras ne depose dans le coffre d'arrivee" return bad end
  local cx, cy = drop(first)
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
-- 4. Appariement
---------------------------------------------------------------------------------------------------
--- Quais d'entrée et coffres de sortie -> paires. docks = { { key, pid, x, y, item, flow, linked } }, srcs = { { key, pid, x, y, item,
--- linked } } (x, y : tuile du coffre). Un quai déjà relié ou un coffre déjà pris ne sert plus ; le coffre est d'un AUTRE projet que le
--- quai et porte le même objet, à Li.MAX_SPAN tuiles au plus (Manhattan) ; le plus proche (puis la clé la plus petite) l'emporte, les
--- quais de plus grand débit choisissent d'abord. Rend { { dock, src, span } } dans l'ordre de choix.
--- Coût : chaque quai ne parcourt que les coffres de SON objet (à 200 modules, un produit quais × coffres en un tick toutes les 30 s).
function Li.pairs(docks, srcs)
  local ds, ss = {}, {}
  for _, d in ipairs(docks) do if not d.linked and d.item and (d.flow or 0) >= Li.MIN_FLOW then ds[#ds + 1] = d end end
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
-- 5. Décision d'une paire
---------------------------------------------------------------------------------------------------
--- Liaisons en construction permises à la fois : autant que de PNJ libres (`free` : sans tâche, ou sur la file sûre que tout préempte), au moins Li.MIN_OPEN.
--- Une borne écrite (1 à la fois) faisait passer 100 quais en série (AUDIT_PLAFONDS n° 22), quels que soient les bras disponibles.
function Li.max_open(free)
  return math.max(Li.MIN_OPEN, math.floor(free or 0))
end

--- inp = { worth (bool : Li.worth), worth_why, open (la liaison de CE quai est en cours), open_total, free (PNJ libres, Li.max_open), seen (relevés de suite),
---   tries, since_try (ticks depuis le dernier essai ; nil : essais épuisés laissés), enemies (nombre), threat (QG menacé) }.
--- Rend action ("relier" | "attendre" | "laisser"), raison.
function Li.decide(inp)
  if inp.open then return "attendre", "liaison deja en cours" end
  if not inp.worth then return "laisser", "ne se paie pas : " .. tostring(inp.worth_why) end
  if (inp.seen or 0) < Li.CONFIRM then return "attendre", string.format("a confirmer (%d releve(s) sur %d)", inp.seen or 0, Li.CONFIRM) end
  if (inp.tries or 0) >= Li.MAX_TRIES and (inp.since_try or 0) < Li.RETRY_AFTER then
    return "laisser", string.format("%d liaison(s) tentee(s) sans effet (nouvel essai %d min apres le dernier)", inp.tries, Li.RETRY_AFTER / 3600)
  end
  if inp.threat then return "attendre", "QG menace : le PNJ reste au QG, la liaison attend" end
  if (inp.enemies or 0) > 0 then return "attendre", string.format("ennemi a moins de %d tuiles", Li.ENEMY_R) end
  if (inp.open_total or 0) >= Li.max_open(inp.free) then
    return "attendre", string.format("%d liaison(s) deja ouverte(s), %d PNJ libre(s)", inp.open_total, inp.free or 0)
  end
  return "relier", "quai servi a la main, liaison rentable"
end

---------------------------------------------------------------------------------------------------
-- 6. Barre du coffre d'entrée
---------------------------------------------------------------------------------------------------
--- Barre (index de la première case bloquée) d'un coffre d'entrée : assez de cases pour `fill` objets de pile `stack`. Le moteur compte la
--- barre à partir de 1 : une barre de n + 1 laisse n cases (F95).
function Li.bar(fill, stack)
  local slots = math.max(1, math.ceil((fill or 400) / math.max(1, stack or 1)))
  return slots + 1
end

return Li
