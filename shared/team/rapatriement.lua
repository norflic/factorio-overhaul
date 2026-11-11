--[[
  Lot RAPATRIEMENT (demande du DC, 8/11 vers 12 h 20, en jouant la 0.6.65) : règle PURE (aucune API du jeu, aucun nom d'objet : un objet est une
  chaîne opaque) des LIGNES DE RAPATRIEMENT. Lue hors jeu (tests/rapatriement_test.lua) et en jeu (script/team/rapatriement.lua).

  Le DC : « il y a une fonderie qui est vachement loin du centre de la base et ça le met dans des coffres et ça le met pas sur des convoyeurs
  pour le ramener au plus proche de la base, enfin là où en tout cas le fer est utilisé typiquement [...] transformer les coffres qui sont de
  stockage, qui seraient du coup des buffers, c'est-à-dire qu'on met un bras mécanique qui récupère des convoyeurs et qui le met dans les
  coffres, et ensuite un autre bras qui récupère du coffre et qui le met sur un autre convoyeur, et ensuite qu'il fait en sorte que l'output de
  ces convoyeurs-là aille se diriger vers des endroits où il y en a besoin du fer, typiquement, au plus proche de la base. »

  Mesuré (journal de la partie du DC, 255 min, fo-logs/2026-11-08_MESURE-DC/petrole) : 40 coffres de sortie de champ pour votre équipe, 57 652
  plaques dormant, 1 quai sur 33 servi par tapis, 0 paire possible : la liaison de quai (shared/team/liaison.lua) s'arrête à Li.MAX_SPAN = 40
  tuiles et Li.MAX_LEN = 48. Tout objet fait DEUX trajets de PNJ (collecte sortie -> QG, remplissage QG -> quai) ; le premier, le plus long,
  n'était jamais remplacé.

  Ligne : coffre de SORTIE lointain -> bras -> tapis (60 à 320 tuiles) -> bras -> coffre TAMPON près des consommateurs.
    1. SOURCES ET CONSOMMATEURS (Rp.candidates) : une sortie à Rp.MIN_DIST tuiles ou plus du QG (Manhattan), d'un objet connu, d'un débit d'au moins
       Rp.MIN_RATE ; les consommateurs sont les quais du même objet qu'aucune liaison ne sert encore. Un débit de STOCK (coffre qui dort plein, rien ne
       monte) ne compte que pour Rp.STOCK_FACTOR : vider un reste une fois ne paie pas une ligne.
    2. TAMPON (Rp.tampon_point) : le point qui MINIMISE Σ débit x distance de Manhattan aux consommateurs. La distance de Manhattan se sépare par axe :
       la médiane pondérée (la plus petite valeur dont le poids cumulé atteint la moitié) de x, celle de y. Prouvé contre la force brute. Ramené à
       Rp.NEAR_HUB tuiles du QG (un tampon trop loin du QG ne soulage pas la main).
    3. PRIX (Rp.worth) : travail de PNJ économisé par minute, en PNJ-secondes, contre ce que la ligne coûte (tapis, bras, poteaux, pose), comme
       Li.worth. Économie = jambe de collecte lointaine (distance source -> QG) moins ce qui reste à porter du tampon au QG (part non servie par
       tapis), plus une part Rp.STAGE2 de la jambe de remplissage pour ce que le tampon sert aux quais à Li.MAX_SPAN (liaison ordinaire du tampon,
       ou bus du lot reseau-graphe).
    4. DÉCISION (Rp.decide) : prix, confirmation sur Rp.CONFIRM relevés, essais, menace, ennemis, lignes ouvertes, lignes au plus Rp.MAX_LINES.
    5. SITE ET TRACÉ (Rp.pick_spots, Rp.street_edge, Rp.route_ok) : un point libre du tampon près du point voulu (anneaux de Manhattan croissants), un bras et un tapis
       contre le coffre ; le tracé accepté s'il tient dans Rp.MAX_LEN et Rp.DETOUR.
    6. ENTITÉS ET PREUVE (Rp.entities, Rp.verify) : chaque pièce mène à la suivante, le tampon est le coffre où dépose le dernier bras.
    7. BARRE (Rp.bar) : le tampon est borné à Rp.BUFFER_MIN minutes de débit (au moins Rp.BUFFER_MIN_OBJ objets, au plus Rp.BUFFER_MAX_OBJ),
       sans quoi le bras vide la sortie sans fin : plein, le tapis reflue, le coffre de sortie remonte et la collecte à la main reprend (le repli).
    8. TRAJETS (Rp.trips) : trajets de PNJ par heure évités / restants, pour le journal [FO-RAPATRIEMENT].

  Déterminisme : listes triées avec départage par clé, aucun `pairs` dans une décision, aucune trigonométrie, aucune horloge mesurée.
  Valeurs NON MESURÉES : Rp.STAGE2, Rp.BUFFER_MIN, Rp.DRAIN_MIN, Rp.KEEP_STOCK.
]]

local Li = require("shared.team.liaison")

local Rp = {}

-- Relevé et décision (script/team/rapatriement.lua)
Rp.PERIOD = 1800            -- ticks entre deux débuts de relevé (30 s)
Rp.UNITS_PER_PULSE = 2      -- projets relevés par passe de Build (Build.PULSE = 5 ticks)
Rp.CONFIRM = 2              -- relevés de suite où la ligne est vue avant d'agir
Rp.MAX_TRIES = 2            -- lignes tentées au plus pour une même sortie
Rp.RETRY_AFTER = 20 * 3600  -- ticks : essais épuisés, un essai de plus après 20 min
Rp.MAX_LINES = 8            -- lignes (ouvertes ou finies) au plus par équipe : chaque ligne prend des centaines de tuiles
Rp.ENEMY_R = 28             -- tuiles : jamais de pose avec un ennemi à cette portée de la sortie ou du tampon
Rp.LOG_EVERY = 5 * 3600     -- une synthèse au plus par équipe et par 5 min (hors changement)
Rp.HIST = 6                 -- relevés gardés par sortie pour le débit

-- Géométrie
Rp.MIN_DIST = 56            -- tuiles (Manhattan) QG -> sortie : en deçà, la main et la liaison ordinaire suffisent
Rp.NEAR_HUB = 72            -- tuiles : le tampon est au plus à cette distance du QG
Rp.MAX_LEN = 640            -- tuiles de tapis au plus (lot BUS-LONG : 320 refusait des sources à 300 tuiles du QG à l'échelle 600 %, détour compris)
Rp.DETOUR = 1.4             -- un tracé ne dépasse pas DETOUR x (Manhattan + 1) + DETOUR_SLACK tuiles
Rp.DETOUR_SLACK = 16
Rp.ROUTE_TRIES = 4          -- paires de bouts essayées au plus par plan
Rp.SPOT_RADIUS = 12         -- tuiles (Manhattan) : recherche d'un point libre pour le tampon autour du point voulu
Rp.SPOT_TRIES = 6           -- points libres essayés au plus
Rp.FALLBACK_STEP = 12        -- tuiles : pas du repli forcé du tampon vers le QG quand aucun poteau du réseau n'est à portée du point voulu (lot BUS-FER)
Rp.REUSE_R = 10             -- tuiles : un tampon du même objet plus proche du point voulu est réutilisé (un coffre, plusieurs lignes)
Rp.REUSE_MAX = 3            -- lignes au plus vers un même tampon (un coffre a quatre côtés, un est pris par son bras de sortie)
Rp.EST_FACTOR = Li.EST_FACTOR

-- Prix. Les durées sont celles de shared/team/liaison.lua (donc de shared/ai3/automatiser.lua).
Rp.TMAX = 120                 -- minutes : retour accepté d'une ligne (un tapis dure toute la partie ; Li.TMAX = 90 pour une liaison de quai) (NON MESURÉ)
Rp.BELT_BATCH = 100         -- pièces par aller-retour de chantier : la pile d'un tapis est de 100 (Li.BATCH = 12 vaut pour des pièces mêlées)
Rp.THREAT_DIV = Li.THREAT_DIV
Rp.COLLECT_BATCH = 200      -- objets par trajet de collecte (Build.COLLECT_AT)
Rp.FILL_BATCH = 340         -- objets par trajet de remplissage (Build.QUAI_FILL - Build.QUAI_LOW)
Rp.MIN_RATE = 0.05          -- objets/s : sous ce débit une sortie ne vaut aucune ligne
Rp.STAGE2 = 0.5             -- part de la jambe de remplissage comptée pour ce que le tampon sert aux quais voisins (NON MESURÉ)
Rp.DRAIN_MIN = 30           -- minutes : une sortie qui dort pleine se vide en ce temps (débit de stock, borné par le bras)
Rp.WHY_SATURATED = "objet sature au QG (le stock le refuse) et aucun quai ne le consomme"
Rp.STOCK_FACTOR = 0.3       -- un débit de STOCK (coffre qui dort plein) n'est pas une production : il ne compte que pour cette part dans le prix (NON MESURÉ)
Rp.BUFFER_MIN = 10          -- minutes de débit gardées au tampon (NON MESURÉ)
Rp.BUFFER_MIN_OBJ = 200
Rp.BUFFER_MAX_OBJ = 1600
Rp.TAMPON_AT = 150          -- objets : seuil de collecte du tampon par un PNJ (court trajet vers le QG quand le QG manque)
Rp.KEEP_STOCK = 2000        -- objets : le PNJ ne vide le tampon que si le stock du QG est sous cette valeur (p.keep_stock)
Rp.PRICE = { belt = Li.PRICE.belt, arm = Li.PRICE.arm, pole = Li.PRICE.pole, chest = 8 } -- plaques-équivalent par pièce (coffre de fer : 8 plaques)

local function manhattan(ax, ay, bx, by) return math.abs(ax - bx) + math.abs(ay - by) end
Rp.manhattan = manhattan

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

---------------------------------------------------------------------------------------------------
-- 1. Débit d'une sortie
---------------------------------------------------------------------------------------------------
--- Débit d'une sortie (objets/s) lu à l'historique { {tick, n}, ... } : la médiane des hausses du coffre entre deux relevés (une baisse est une
--- collecte, pas une production : la paire est écartée). Un coffre qui dort plein (n >= `at`) et ne monte plus se vide, au plus à `arm` objets/s,
--- en Rp.DRAIN_MIN minutes. Rend le débit et sa nature ("mesure" | "stock" | nil).
function Rp.rate_of(hist, at, arm)
  local rises = {}
  local last
  for _, h in ipairs(hist or {}) do
    if last and h[1] > last[1] then
      local r = (h[2] - last[2]) / ((h[1] - last[1]) / 60)
      if r > 0 then rises[#rises + 1] = r end
    end
    last = h
  end
  table.sort(rises)
  local best = 0
  if #rises > 0 then best = rises[floor((#rises + 1) / 2)] end -- médiane basse des hausses positives : un pic isolé ne fait pas le débit
  if arm and best > arm then best = arm end
  if best >= Rp.MIN_RATE then return best, "mesure" end
  local n = last and last[2] or 0
  if n >= (at or Rp.COLLECT_BATCH) then
    local r = n / (Rp.DRAIN_MIN * 60)
    if arm and r > arm then r = arm end
    if r >= Rp.MIN_RATE then return r, "stock" end
  end
  return 0, nil
end

---------------------------------------------------------------------------------------------------
-- 2. Point du tampon
---------------------------------------------------------------------------------------------------
--- Médiane pondérée : vals = { {v, w}, ... } (w > 0) ; la plus petite valeur dont le poids cumulé atteint la moitié du poids total. nil si vide.
function Rp.wmedian(vals)
  local list, total = {}, 0
  for _, e in ipairs(vals) do
    if e[2] > 0 then list[#list + 1] = e; total = total + e[2] end
  end
  if #list == 0 then return nil end
  table.sort(list, function(a, b)
    if a[1] ~= b[1] then return a[1] < b[1] end
    return a[2] < b[2]
  end)
  local cum = 0
  for _, e in ipairs(list) do
    cum = cum + e[2]
    if cum * 2 >= total then return e[1] end
  end
  return list[#list][1]
end

--- Coût d'un point : Σ débit x distance de Manhattan aux consommateurs { {x, y, flow} }.
function Rp.cost_at(consumers, x, y)
  local c = 0
  for _, k in ipairs(consumers) do c = c + (k.flow or 0) * manhattan(k.x, k.y, x, y) end
  return c
end

--- Point qui minimise Σ débit x distance de Manhattan : médiane pondérée de x, médiane pondérée de y (la distance de Manhattan se sépare par axe).
--- Rend x, y, coût ; nil quand aucun consommateur n'a de débit.
function Rp.tampon_point(consumers)
  local xs, ys = {}, {}
  for _, k in ipairs(consumers) do
    if (k.flow or 0) > 0 then
      xs[#xs + 1] = { k.x, k.flow }
      ys[#ys + 1] = { k.y, k.flow }
    end
  end
  local x, y = Rp.wmedian(xs), Rp.wmedian(ys)
  if not x then return nil end
  return x, y, Rp.cost_at(consumers, x, y)
end

--- Ramène (x, y) à `r` tuiles (Manhattan) du QG au plus, en gardant la direction (réduction homothétique, tronquée vers le QG).
function Rp.clamp_near(x, y, hub, r)
  local dx, dy = x - hub.x, y - hub.y
  local d = math.abs(dx) + math.abs(dy)
  if d <= r then return x, y end
  local k = r / d
  local function cut(v) if v >= 0 then return floor(v * k) end return -floor(-v * k) end
  return hub.x + cut(dx), hub.y + cut(dy)
end

---------------------------------------------------------------------------------------------------
-- 3. Prix
---------------------------------------------------------------------------------------------------
--- Coût en PNJ-secondes par objet d'un trajet aller-retour à la distance d (tuiles) pour un lot de `batch` objets (comme Rg.leg du lot reseau-graphe).
function Rp.leg(d, batch)
  return (2 * d / Li.WALK + Li.HANDLE_S) / max(1, batch)
end

--- Prix d'une ligne. inp = { flow (objets/s qui passent par la ligne), d_src (Manhattan source -> QG), d_tam (tampon -> QG), d_fill (QG -> quais
--- servis, moyenne), covered (objets/s des quais à Li.MAX_SPAN du tampon), tiles (tapis ; nil : estimé), tmax, threat, labor, price }.
--- Rend ok, raison, détail { save_s_min, labor_s_min, cost, build_s, pay_s, payback_min, tiles, tmax, phi, trips }.
function Rp.worth(inp)
  local flow = inp.flow or 0
  if flow < Rp.MIN_RATE then return false, string.format("debit de la sortie %.3f/s : rien a economiser", flow), { payback_min = math.huge, tiles = 0, save_s_min = 0 } end
  local tiles = inp.tiles or ceil((inp.span or inp.d_src or 0) * Rp.EST_FACTOR + 2)
  local price = inp.price or Rp.PRICE
  local labor = inp.labor or Li.LABOR_VALUE
  local phi = 0
  if flow > 0 then phi = min(1, max(0, (inp.covered or 0) / flow)) end
  local far = Rp.leg(inp.d_src or 0, Rp.COLLECT_BATCH)                  -- jambe lointaine évitée, par objet
  local rest = (1 - phi) * Rp.leg(inp.d_tam or 0, Rp.COLLECT_BATCH)      -- court trajet du tampon au QG pour la part non servie par tapis
  local fill = phi * Rp.STAGE2 * Rp.leg(inp.d_fill or 0, Rp.FILL_BATCH)  -- remplissage des quais voisins évité
  local save_s = flow * (far - rest + fill)
  local save_s_min = 60 * save_s
  local cost = tiles * price.belt + 2 * price.arm + 2 * price.pole + (price.chest or 0)
  local n_ent = tiles + 5
  local trip_s = 2 * (inp.d_src or 56) / Li.WALK + Li.HANDLE_S
  local build_s = n_ent * Li.POSE_S + ceil(n_ent / Rp.BELT_BATCH) * trip_s
  local pay_s = cost / labor + build_s
  local tmax = inp.tmax or Rp.TMAX
  if inp.threat then tmax = tmax / Rp.THREAT_DIV end
  local det = { save_s_min = save_s_min, labor_s_min = save_s_min, cost = cost, build_s = build_s, pay_s = pay_s, tiles = tiles, tmax = tmax, phi = phi,
    far_s = flow * far * 60, rest_s = flow * rest * 60, fill_s = flow * fill * 60 }
  if save_s_min <= 0 then
    return false, string.format("aucun travail economise (jambe lointaine %.2f, reste %.2f PNJ-s/min)", det.far_s, det.rest_s), det
  end
  det.payback_min = pay_s / save_s_min
  if det.payback_min > tmax then
    return false, string.format("retour %.0f min > %.0f min (%.2f PNJ-s/min economisees, %d tuiles, cout %.0f)", det.payback_min, tmax, save_s_min, tiles, cost), det
  end
  return true, string.format("retour %.0f min <= %.0f min (%.2f PNJ-s/min economisees, %d tuiles, cout %.0f)", det.payback_min, tmax, save_s_min, tiles, cost), det
end

--- Trajets de PNJ par heure (objets/s `flow`) : lointains évités (collecte source -> QG), courts restants (tampon -> QG pour la part non servie),
--- de remplissage évités (part servie, Rp.STAGE2).
function Rp.trips(flow, phi)
  local h = 3600 * flow
  return { far_avoided_h = h / Rp.COLLECT_BATCH, short_left_h = (1 - phi) * h / Rp.COLLECT_BATCH, fill_avoided_h = phi * Rp.STAGE2 * h / Rp.FILL_BATCH }
end

---------------------------------------------------------------------------------------------------
-- 4. Candidats
---------------------------------------------------------------------------------------------------
--- srcs = { { key, pid, idx, x, y, item, rate (objets/s), linked } }, docks = { { key, x, y, item, flow, served } } (TUILES), hub = { x, y } : la POSITION du QG
--- (centre d'entité : x,5 pour un coffre 1 x 1), ramenée une fois à sa tuile.
--- o = { price, labor, tmax, threat, tampons = { { x, y, item, lines } } } (facultatifs). Rend la liste des candidats triée par valeur nette décroissante
--- (puis clé) : { src, item, flow, d_src, point = { x, y }, reuse (tampon réutilisé ou nil), d_tam, covered, d_fill, consumers (n), ok, why, det, net }.
function Rp.candidates(srcs, docks, hub, o)
  o = o or {}
  -- lot CC-ROUTE (F518) : toute la règle travaille en tuiles (sorties, quais, tampon, bouts du tapis) ; le centre du QG gardé tel quel donnait un tampon
  -- et un bout d'arrivée en demi-tuiles, une cible que le tracé (tuiles entières) n'atteint jamais : la ligne cherchait jusqu'à épuiser ses réparations
  hub = { x = floor(hub.x), y = floor(hub.y) }
  local by_item = {}
  for _, d in ipairs(docks) do
    if d.item and not d.served and (d.flow or 0) >= Li.MIN_FLOW then
      by_item[d.item] = by_item[d.item] or {}
      table.insert(by_item[d.item], d)
    end
  end
  local out = {}
  for _, s in ipairs(srcs) do
    local d_src = manhattan(s.x, s.y, hub.x, hub.y)
    if s.item and not s.linked and (s.rate or 0) >= Rp.MIN_RATE and d_src >= Rp.MIN_DIST then
      local cons = by_item[s.item] or {}
      local px, py
      if #cons > 0 then px, py = Rp.tampon_point(cons) end
      if not px then px, py = hub.x, hub.y end
      px, py = Rp.clamp_near(px, py, hub, Rp.NEAR_HUB)
      -- lot BUS-SORTIE (partie du DC 0.7.3) : le quai consommateur le plus proche du point voulu EST l'arrivée (le dernier bras y dépose, aucun coffre posé) ;
      -- un tampon posé à côté du quai empilait un second relais coffre -> bras -> tapis -> bras -> quai (3:o6 -> (-63, 13) -> liaison -> 8:q1 (-58, 13))
      local reuse
      for _, d in ipairs(cons) do
        if manhattan(d.x, d.y, px, py) <= Rp.REUSE_R and (not reuse or manhattan(d.x, d.y, px, py) < manhattan(reuse.x, reuse.y, px, py)) then reuse = d end
      end
      if not reuse then for _, t in ipairs(o.tampons or {}) do
        if t.item == s.item and (t.lines or 1) < Rp.REUSE_MAX and manhattan(t.x, t.y, px, py) <= Rp.REUSE_R then
          if not reuse or manhattan(t.x, t.y, px, py) < manhattan(reuse.x, reuse.y, px, py) then reuse = t end
        end
      end end
      local tx, ty = px, py
      if reuse then tx, ty = reuse.x, reuse.y end
      local covered, fill_w, fill_sum = 0, 0, 0
      for _, d in ipairs(cons) do
        if manhattan(d.x, d.y, tx, ty) <= Li.MAX_SPAN and d.flow > covered then covered = d.flow end -- une source = un quai (liaison ordinaire) : le plus gros seulement
        fill_w = fill_w + d.flow
        fill_sum = fill_sum + d.flow * manhattan(d.x, d.y, hub.x, hub.y)
      end
      local flow = s.rate
      if s.nature == "stock" then flow = flow * Rp.STOCK_FACTOR end
      local d_tam = manhattan(tx, ty, hub.x, hub.y)
      local d_fill = fill_w > 0 and fill_sum / fill_w or 0
      local span = manhattan(s.x, s.y, tx, ty)
      local ok, why, det = Rp.worth({ flow = flow, d_src = d_src, d_tam = d_tam, d_fill = d_fill, covered = covered,
        tiles = ceil(span * Rp.EST_FACTOR + 2), price = o.price, labor = o.labor, tmax = o.tmax, threat = o.threat })
      -- Un objet que le stock du QG refuse (saturé : s.saturated) et qu'aucun quai ne consomme n'a pas de preneur : la ligne le déposerait dans un tampon que
      -- rien ne vide (journal du DC du 8/11 : 14 demandes de PIERRE alors que le QG en tient 28 888)
      if s.saturated and #cons == 0 then ok, why = false, Rp.WHY_SATURATED end
      out[#out + 1] = { src = s, item = s.item, flow = s.rate, worth_flow = flow, d_src = d_src, point = { x = tx, y = ty }, reuse = reuse, d_tam = d_tam, covered = covered,
        d_fill = d_fill, consumers = #cons, span = span, ok = ok, why = why, det = det, net = (det.save_s_min or 0) }
    end
  end
  table.sort(out, function(a, b)
    if a.net ~= b.net then return a.net > b.net end
    return a.src.key < b.src.key
  end)
  return out
end

---------------------------------------------------------------------------------------------------
-- 5. Décision
---------------------------------------------------------------------------------------------------
--- Lignes ouvertes à la fois : autant que de PNJ libres, au moins 1 (comme Li.max_open).
function Rp.max_open(free) return max(1, floor(free or 0)) end

--- inp = { worth, worth_why, open_total, free, seen, tries, since_try, enemies, threat, lines (ouvertes ou finies) }. Rend action, raison.
function Rp.decide(inp)
  if not inp.worth then return "laisser", "ne se paie pas : " .. tostring(inp.worth_why) end
  if (inp.lines or 0) >= Rp.MAX_LINES then return "laisser", string.format("%d ligne(s) deja posee(s) (au plus %d)", inp.lines, Rp.MAX_LINES) end
  if (inp.seen or 0) < Rp.CONFIRM then return "attendre", string.format("a confirmer (%d releve(s) sur %d)", inp.seen or 0, Rp.CONFIRM) end
  if (inp.tries or 0) >= Rp.MAX_TRIES and (inp.since_try or 0) < Rp.RETRY_AFTER then
    return "laisser", string.format("%d ligne(s) tentee(s) sans effet (nouvel essai %d min apres le dernier)", inp.tries, Rp.RETRY_AFTER / 3600)
  end
  if inp.threat then return "attendre", "QG menace : le PNJ reste au QG, la ligne attend" end
  if (inp.enemies or 0) > 0 then return "attendre", string.format("ennemi a moins de %d tuiles", Rp.ENEMY_R) end
  if (inp.open_total or 0) >= Rp.max_open(inp.free) then
    return "attendre", string.format("%d ligne(s) deja ouverte(s), %d PNJ libre(s)", inp.open_total, inp.free or 0)
  end
  return "relier", "sortie lointaine servie a la main, ligne rentable"
end

---------------------------------------------------------------------------------------------------
-- 6. Site du tampon et tracé
---------------------------------------------------------------------------------------------------
--- Tuiles à `r` de Manhattan de (px, py), dans l'ordre : y croissant puis x croissant.
function Rp.ring(px, py, r)
  local out = {}
  if r == 0 then out[1] = { px, py } return out end
  for dy = -r, r do
    local rem = r - math.abs(dy)
    if rem == 0 then out[#out + 1] = { px, py + dy }
    else
      out[#out + 1] = { px - rem, py + dy }
      out[#out + 1] = { px + rem, py + dy }
    end
  end
  return out
end

--- Premiers points libres pour un coffre tampon (chaque coffre a au moins un site de bras : Li.sites) autour de (px, py), jusqu'à Rp.SPOT_RADIUS ;
--- au plus `max` points (défaut Rp.SPOT_TRIES), les plus proches d'abord. free(x, y) -> bool. Rend { { x, y, sites } }.
function Rp.pick_spots(px, py, free, max_n, radius)
  local out = {}
  max_n = max_n or Rp.SPOT_TRIES
  for r = 0, radius or Rp.SPOT_RADIUS do
    for _, t in ipairs(Rp.ring(px, py, r)) do
      if free(t[1], t[2]) then
        local sites = Li.sites(t[1], t[2], free)
        if #sites > 0 then
          out[#out + 1] = { x = t[1], y = t[2], sites = sites }
          if #out >= max_n then return out end
        end
      end
    end
  end
  return out
end

--- La tuile (tx, ty) est-elle au BORD d'une rue du treillis (première ou dernière tuile de la rue, hors croisement) ? Un coffre au milieu d'un lot
--- le rendrait inutilisable par un module (le module veut son rectangle entier libre) ; au milieu de la rue il gênerait la marche des PNJ ; au bord de
--- la rue il ne fait ni l'un ni l'autre. lat = { ox, oy }, geom = { pitch, lot, half } (shared/team/plan.lua : P.PITCH, P.LOT, P.HALF).
function Rp.street_edge(lat, geom, tx, ty)
  local rx = (tx - lat.ox + geom.half) % geom.pitch
  local ry = (ty - lat.oy + geom.half) % geom.pitch
  local xs, ys = rx >= geom.lot, ry >= geom.lot
  if xs and ys then return false end -- croisement
  if xs then return rx == geom.lot or rx == geom.pitch - 1 end
  if ys then return ry == geom.lot or ry == geom.pitch - 1 end
  return false
end

--- Le tracé est-il acceptable ? len = nombre de tuiles, m = Manhattan des deux tuiles de tapis. Rend ok, raison.
function Rp.route_ok(len, m)
  if len > Rp.MAX_LEN then return false, string.format("tapis de %d tuiles > %d", len, Rp.MAX_LEN) end
  local lim = Rp.DETOUR * (m + 1) + Rp.DETOUR_SLACK
  if len > lim then return false, string.format("detour de %d tuiles pour %d a vol d'oiseau (limite %.0f)", len, m + 1, lim) end
  return true, ""
end

---------------------------------------------------------------------------------------------------
-- 6 bis. Recherche de chemin REPRENABLE (A* en tranches)
---------------------------------------------------------------------------------------------------
-- Mesure du 8/11 (debug.sethook, Rap.plan sur la sauvegarde-type) : un tracé de 180 tuiles coûte 0,49 M d'instructions, une destination
-- inatteignable 81,6 M (0,65 à 3,6 s d'un seul tenant) : le tracé se fait donc en tranches de nœuds développés (Rp.SLICE_NODES), sur plusieurs
-- pensées. MÊME algorithme et MÊME départage que P.belt_route (shared/team/plan.lua) : le test compare les deux tuile pour tuile.
Rp.SLICE_NODES = 135        -- noeuds développés au plus par tranche (environ 110 k instructions mesurées : 800 par noeud développé ; 5 ms à 44 ns, demande de team-lead 8/11)
Rp.TOTAL_NODES = 60000      -- noeuds développés au plus par projet, toutes recherches comprises (60 000 = 120 tranches ; au pire environ 24 M d'instructions étalées)
Rp.POCKET_NODES = 300       -- une recherche sans issue qui a développé moins de noeuds est une POCHE (départ ou arrivée enfermés) : les autres bouts restent essayés ; au-delà, une barrière : le passage s'arrête
local function tkey(x, y) return (x + 1048576) * 2097152 + (y + 1048576) end
local function heap_push(h, n)
  h[#h + 1] = n
  local i = #h
  while i > 1 do
    local p = floor(i / 2)
    local a, b = h[p], h[i]
    if a.f < b.f or (a.f == b.f and (a.h < b.h or (a.h == b.h and a.k <= b.k))) then break end
    h[p], h[i] = b, a
    i = p
  end
end
local function heap_pop(h)
  local top = h[1]
  local last = h[#h]
  h[#h] = nil
  local n = #h
  if n > 0 then
    h[1] = last
    local i = 1
    while true do
      local l, r, m = 2 * i, 2 * i + 1, i
      if l <= n then
        local a, b = h[l], h[m]
        if a.f < b.f or (a.f == b.f and (a.h < b.h or (a.h == b.h and a.k < b.k))) then m = l end
      end
      if r <= n then
        local a, b = h[r], h[m]
        if a.f < b.f or (a.f == b.f and (a.h < b.h or (a.h == b.h and a.k < b.k))) then m = r end
      end
      if m == i then break end
      h[m], h[i] = h[i], h[m]
      i = m
    end
  end
  return top
end
local ORDER = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }

--- Début d'une recherche de la tuile `s` à la tuile `t` (incluses) dans `bounds` { x0, y0, x1, y1 } (inclus), 4 voisins. weight : poids de l'heuristique.
--- L'état rendu ne contient que des nombres et des tables (aucune fonction) ; cost(x, y) est passé à chaque tranche.
function Rp.route_begin(s, t, t_dir, bounds, weight)
  local hw = weight or 1
  local h0 = (math.abs(s.x - t.x) + math.abs(s.y - t.y)) * hw
  local job = { s = { x = s.x, y = s.y }, t = { x = t.x, y = t.y }, t_dir = t_dir, bounds = bounds, hw = hw, open = {}, g = { [tkey(s.x, s.y)] = 0 }, prev = {},
    closed = {}, expanded = 0, status = "run", started = false }
  heap_push(job.open, { x = s.x, y = s.y, f = h0, h = h0, k = tkey(s.x, s.y) })
  return job
end

--- Avance de `nodes` nœuds développés au plus ; `cap` : plafond de nœuds développés de la recherche entière (« trop long » au-delà). Rend l'état :
--- "more" (reprendre), "found" (job.tiles = liste { x, y, dir }), "none" (job.why = « depart », « arrivee » ou « aucun chemin »), "cap" (job.why = « trop long »).
function Rp.route_step(job, cost, nodes, cap)
  if job.status ~= "run" then return job.status end
  if not job.started then
    job.started = true
    if not cost(job.s.x, job.s.y) then job.status, job.why = "none", "depart" return job.status end
    if not cost(job.t.x, job.t.y) then job.status, job.why = "none", "arrivee" return job.status end
  end
  local open, g, prev, closed, b, t, hw = job.open, job.g, job.prev, job.closed, job.bounds, job.t, job.hw
  local left = nodes or math.huge
  while #open > 0 do
    if left <= 0 then return "more" end
    local cur = heap_pop(open)
    local ck = cur.k
    if not closed[ck] then
      closed[ck] = true
      left = left - 1
      job.expanded = job.expanded + 1
      if job.expanded > (cap or math.huge) then job.status, job.why = "cap", "trop long" return job.status end
      if cur.x == t.x and cur.y == t.y then
        local tiles = {}
        local k = ck
        local x, y = cur.x, cur.y
        while true do
          table.insert(tiles, 1, { x = x, y = y })
          local p = prev[k]
          if not p then break end
          x, y, k = p[1], p[2], tkey(p[1], p[2])
        end
        for i = 1, #tiles - 1 do tiles[i].dir = Li.dir_of(tiles[i + 1].x - tiles[i].x, tiles[i + 1].y - tiles[i].y) end
        tiles[#tiles].dir = job.t_dir
        job.tiles, job.status = tiles, "found"
        job.open, job.g, job.prev, job.closed = nil, nil, nil, nil -- la mémoire de la recherche est rendue
        return job.status
      end
      for _, o in ipairs(ORDER) do
        local nx, ny = cur.x + o[1], cur.y + o[2]
        if nx >= b.x0 and nx <= b.x1 and ny >= b.y0 and ny <= b.y1 then
          local nk = tkey(nx, ny)
          if not closed[nk] then
            local c = cost(nx, ny)
            if c then
              local ng = g[ck] + c
              if g[nk] == nil or ng < g[nk] then
                g[nk] = ng
                prev[nk] = { cur.x, cur.y }
                local h = (math.abs(nx - t.x) + math.abs(ny - t.y)) * hw
                heap_push(open, { x = nx, y = ny, f = ng + h, h = h, k = nk })
              end
            end
          end
        end
      end
    end
  end
  job.status, job.why = "none", "aucun chemin"
  job.open, job.g, job.prev, job.closed = nil, nil, nil, nil
  return job.status
end

---------------------------------------------------------------------------------------------------
-- 7. Entités et preuve
---------------------------------------------------------------------------------------------------
--- Entités d'une ligne. inp = { src, dst (sites de Li.sites), route, names = { arm, belt, pole, chest }, poles, reuse (vrai : le tampon existe déjà) }.
--- Les rôles de la liaison ordinaire (« liaison-bras », « liaison-tapis », « liaison »), plus « tampon » pour le coffre neuf.
function Rp.entities(inp)
  local ents = Li.entities({ src = inp.src, dst = inp.dst, route = inp.route, names = inp.names, poles = inp.poles })
  if not inp.reuse then
    -- le coffre tampon est la tuile où dépose le bras d'arrivée : à l'opposé de la tuile du bras (dir = vers la prise)
    local v = Li.DV[inp.dst.dir]
    ents[#ents + 1] = { name = inp.names.chest, x = inp.dst.ax - v[1] + 0.5, y = inp.dst.ay - v[2] + 0.5, dir = 0, role = "tampon" }
  end
  return ents
end

--- Preuve géométrique : Li.verify (le bras de départ prend au coffre S, la chaîne de tapis, le bras d'arrivée dépose en D) et le coffre tampon sur D.
--- Rend la liste des écarts (vide : juste).
function Rp.verify(ents, S, D, isbelt, isarm, ischest, reuse)
  local bad = Li.verify(ents, S, D, isbelt, isarm)
  local chests = 0
  for _, e in ipairs(ents) do
    if ischest(e) then
      chests = chests + 1
      if floor(e.x) ~= D.x or floor(e.y) ~= D.y then bad[#bad + 1] = "le coffre tampon n'est pas sur la tuile d'arrivee" end
    end
  end
  if reuse then
    if chests ~= 0 then bad[#bad + 1] = "un tampon reutilise ne pose pas de coffre" end
  elseif chests ~= 1 then
    bad[#bad + 1] = string.format("%d coffre(s) tampon au lieu de 1", chests)
  end
  return bad
end

---------------------------------------------------------------------------------------------------
-- 8. Barre du tampon
---------------------------------------------------------------------------------------------------
--- Barre (première case bloquée, F95 : barre n + 1 = n cases) d'un tampon d'objets de pile `stack` pour un débit de `flow` objets/s.
function Rp.bar(flow, stack)
  local objs = min(Rp.BUFFER_MAX_OBJ, max(Rp.BUFFER_MIN_OBJ, ceil((flow or 0) * 60 * Rp.BUFFER_MIN)))
  local slots = max(1, ceil(objs / max(1, stack or 1)))
  return slots + 1
end

--- Barre du tampon quand plusieurs lignes l'alimentent : somme des débits.
function Rp.bar_total(flows, stack)
  local t = 0
  for _, f in ipairs(flows) do t = t + f end
  return Rp.bar(t, stack)
end

---------------------------------------------------------------------------------------------------
-- 9. Journal
---------------------------------------------------------------------------------------------------
--- Texte d'une ligne [FO-RAPATRIEMENT]. kind : "demandee" | "finie" | "coupee" | "refusee" | "laissee" | "releve". d : champs de la ligne.
function Rp.text(kind, d)
  local who = tostring(d.team or "player")
  local at = string.format("a %.1f min", (d.tick or 0) / 3600)
  if kind == "demandee" then
    local t = Rp.trips(d.flow or 0, d.phi or 0)
    return string.format("[FO-RAPATRIEMENT] %s : ligne demandee (projet %s) : sortie %s (%s, %.2f/s %s, a %d tuiles du QG) -> tampon (%d, %d) a %d tuiles du QG%s ; %d tuile(s) de tapis ; %s ; "
      .. "trajets de PNJ economises par heure : %.1f lointain(s), %.1f court(s) restant(s), %.1f de remplissage %s",
      who, tostring(d.pid), tostring(d.key), tostring(d.item), d.flow or 0, tostring(d.nature or "mesure"), d.d_src or 0, d.x or 0, d.y or 0, d.d_tam or 0,
      d.reuse and " (tampon reutilise)" or "", d.tiles or 0, tostring(d.why), t.far_avoided_h, t.short_left_h, t.fill_avoided_h, at)
  elseif kind == "finie" then
    return string.format("[FO-RAPATRIEMENT] %s : ligne finie (projet %s, %d piece(s), %d fil(s) tire(s)) : %s de %s vers le tampon (%d, %d), le PNJ n'a plus a porter la jambe lointaine %s",
      who, tostring(d.pid), d.pieces or 0, d.wires or 0, tostring(d.item), tostring(d.key), d.x or 0, d.y or 0, at)
  elseif kind == "coupee" then
    return string.format("[FO-RAPATRIEMENT] %s : ligne coupee (projet %s rouvert, etat %s) : le coffre de sortie %s remonte, la collecte a la main reprend %s",
      who, tostring(d.pid), tostring(d.state), tostring(d.key), at)
  elseif kind == "refusee" then
    return string.format("[FO-RAPATRIEMENT] %s : ligne refusee (projet %s : %s), sortie %s : le PNJ continue a la main %s", who, tostring(d.pid), tostring(d.cause), tostring(d.key), at)
  elseif kind == "laissee" then
    return string.format("[FO-RAPATRIEMENT] %s : sortie %s (%s, %.2f/s, a %d tuiles du QG) -> tampon (%d, %d) : %s : %s %s",
      who, tostring(d.key), tostring(d.item), d.flow or 0, d.d_src or 0, d.x or 0, d.y or 0, tostring(d.action), tostring(d.cause), at)
  end
  return string.format("[FO-RAPATRIEMENT] %s : releve : %d sortie(s) lointaine(s) vue(s), %d candidate(s) rentable(s) ; lignes finies %d, en construction %d ; "
    .. "demandes %d, finies %d, refusees %d, coupees %d %s", who, d.far or 0, d.worth or 0, d.done or 0, d.open or 0, d.demandes or 0, d.finis or 0, d.refuses or 0,
    d.coupees or 0, at)
end

--- Lot CC-MATIERES (F520) : les lignes de rapatriement encore OUVERTES (demandées, ni finies ni refusées ni abandonnées), triées par clé :
--- { { key, pid, pile } }. lines : b.rapatriement.lines ({ [clé] = { pid, done } }) ; projects : b.projects ({ [pid] = { state, abandoned,
--- spec = { pile } } }). Lu par script/ai3/automatisation.lua : les objets qui manquent à leur réserve deviennent des buts du cerveau, comme
--- la ligne d'une migration de champ et la ligne d'une bande (avant : personne ne les fabriquait, réserve « materiaux » sans fin).
function Rp.open_lines(lines, projects)
  local keys = {}
  for k in next, lines or {} do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local out = {}
  for _, k in ipairs(keys) do
    local l = lines[k]
    local q = l and projects and projects[l.pid]
    if q and not l.done and q.state ~= "fini" and q.state ~= "refuse" and not q.abandoned then
      out[#out + 1] = { key = k, pid = l.pid, pile = q.spec and q.spec.pile or nil }
    end
  end
  return out
end

--- Lot CC-PRIO-LIGNES (F532, règle du DC « le pavage des gisements passe d'abord ») : stock LIBRE pour la réserve d'une LIGNE DE RAPATRIEMENT.
--- Le coffre est servi au premier lecteur (Build.reserve relit chaque projet en réserve une fois par seconde, chacun à sa phase) : une ligne,
--- objectif d'investissement, prenait les tapis et les bras qui manquaient à une bande de champ (banc C4, graine 271828182 : 10 lignes dont
--- 2 demandées avant les bandes 21, 26, 28 ; à 31 min la bande manque 145 tapis contre 29 sans les lignes, 1 348 plaques livrées de 31 à
--- 40 min contre 6 803). La famille « bande de champ » (spec.champ) passe avant la famille « rapatriement » (spec.rapatriement) : pour une
--- ligne, chaque objet libre est diminué de ce qui MANQUE aux bandes de champ actives (réserve ou chantier, p.missing frais). Pour tout autre
--- projet, `free` est rendu tel quel. Ne modifie pas `free` (vue qui le lit, objets gardés seuls réécrits). Ni nom d'objet ni quantité :
--- tout vient des manques (ipairs seulement : objets dans l'ordre des listes de manques).
Rp.BANDE_ACTIVE = { reserve = true, defrichage = true, fantomes = true, chantier = true }

function Rp.libre_pour(spec, free, projects, order)
  if not (type(spec) == "table" and spec.rapatriement ~= nil) then return free end
  local owed, keys = {}, {}
  for _, pid in ipairs(order or {}) do
    local q = projects and projects[pid]
    if q and q.spec and q.spec.champ and Rp.BANDE_ACTIVE[q.state] and q.missing then
      for _, m in ipairs(q.missing) do
        if owed[m[1]] == nil then keys[#keys + 1] = m[1] end
        owed[m[1]] = (owed[m[1]] or 0) + (m[2] or 0)
      end
    end
  end
  if #keys == 0 then return free end
  local out = setmetatable({}, { __index = free })
  for _, it in ipairs(keys) do out[it] = math.max(0, (free[it] or 0) - owed[it]) end
  return out
end

return Rp
