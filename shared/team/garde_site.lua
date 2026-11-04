--[[
  Lot PERIMETRE2 « garde des sites » (accord du lead et QCM du DC, 4/11 : « Oui, enceinte et avant-postes ») ; diagnostic mesuré :
  fo-logs/2026-11-04_PERIMETRE2/RAPPORT.md (chaque avant-poste gardé par UNE tourelle, tuée la première ; équipe riche qui ne renforce pas ;
  aucun mur de votre équipe). Lua PUR : aucune API du jeu, aucun nom d'objet (les clés de matière viennent de l'appelant), aucun `pairs` dans
  une décision, aucune trigonométrie (racine carrée seulement), aucun hasard. Testé hors jeu : tests/garde_site_test.lua.

  G1 GROUPE PAR SITE : un avant-poste est gardé par UN groupe de tourelles qui se couvrent, du côté des attaques ; taille voulue
     Gs.want(plus grosse vague vue au site) = ⌈vague / Gs.PER_UNITS⌉ borné à [Gs.GROUP_MIN, Gs.GROUP_MAX] ; « déjà là » = tourelles à moins de
     Gs.ACCEPT du CENTRE DU GROUPE (toutes règles confondues ; les tourelles éparses du site ne font pas un groupe). Ordre de service : sites
     attaqués (vague décroissante), puis poids, puis clé.
  G2 BUDGET : avec le module DEPENSES (table { [matière] = accordé }), le fer accordé seul paie ; sans lui, repli : les tourelles de la garde
     n'immobilisent pas plus de Gs.FREE_PCT % du fer LIBRE hors besoin ; rien sous Gs.RICH_IRON de fer au stock dans les deux cas.
  G3 MURS : anneau de murs autour d'un avant-poste ATTAQUÉ (boîte de ses bâtiments + Gs.WALL_MARGIN), une porte de Gs.GATE tuiles tournée vers
     le QG ; segments d'au plus `cap` tuiles ; les tuiles près des bâtiments du JOUEUR (usine du joueur, Gs.PLAYER_GAP) et les tuiles rendues
     par le joueur (mur qu'il a retiré) ne sont jamais murées.
]]

local Gs = {}

Gs.GROUP_MIN = 3        -- tourelles d'un groupe
Gs.GROUP_MAX = 6
Gs.PER_UNITS = 5        -- une tourelle de plus par 5 ennemis de la plus grosse vague vue (diagnostic : 5 ennemis par tourelle = submergée)
Gs.SITE_R = 24          -- tuiles : tourelles « du site » autour de son centre
Gs.GROUP_DIST = 6       -- tuiles : le groupe est posé à cette distance du centre, du côté des attaques
Gs.SPOT_R = 9           -- tuiles : emplacements du groupe autour de son centre
Gs.ACCEPT = 10          -- tuiles : une pose plus loin du centre du groupe est refusée
Gs.SPOT_STEP = 3.5      -- tuiles : pas de la trame des emplacements (écart 7 entre voisins de rang 2, >= Pose.gap 6)
Gs.RICH_IRON = 2000     -- fer au stock sous lequel la garde n'achète rien (leçon du lot PERIMETRE : la partie pauvre reste identique)
Gs.FREE_PCT = 30        -- repli sans le module DEPENSES : % du fer libre hors besoin que la garde peut immobiliser
Gs.WAVE_TICKS = 30 * 3600 -- une vague vue est oubliée après 30 min
Gs.WALL_MARGIN = 3      -- tuiles entre les bâtiments d'un avant-poste et son anneau de murs
Gs.GATE = 3             -- tuiles de la porte (PNJ), sur le côté tourné vers le QG
Gs.PLAYER_GAP = 6       -- tuiles : jamais de mur à moins de cela d'un bâtiment du joueur (son usine)
Gs.SEG_MIN = 8          -- tuiles au moins par segment (sauf le reste d'un côté)
Gs.WALL_ITEMS = 10      -- matière brute (pierre) par mur : 5 briques de 2 pierres
Gs.UNIT_IRON = 120      -- fer d'une tourelle armée (40 + 20 chargeurs de 4) : demande écrite pour DEPENSES seulement (le budget lit le livre)

local function d2(ax, ay, bx, by) local dx, dy = ax - bx, ay - by return dx * dx + dy * dy end

--- Taille voulue du groupe d'un site pour la plus grosse vague vue (nil : aucune).
function Gs.want(wave)
  local n = Gs.GROUP_MIN
  if wave and wave > 0 then
    local k = math.ceil(wave / Gs.PER_UNITS)
    if k > n then n = k end
  end
  if n > Gs.GROUP_MAX then n = Gs.GROUP_MAX end
  return n
end

--- Vague encore en mémoire ? (tick de la vague, tick courant)
function Gs.wave_live(wave_tick, tick) return wave_tick ~= nil and tick - wave_tick <= Gs.WAVE_TICKS end

--- Direction (unitaire) du groupe : vers les menaces { {x, y, w} } à moins de 64 tuiles du site (somme pondérée), sinon vers l'extérieur
--- (du QG vers le site), sinon le nord.
function Gs.dir(site, threats, hq)
  local sx, sy = 0, 0
  for _, t in ipairs(threats or {}) do
    local dx, dy = t.x - site.x, t.y - site.y
    local l2 = dx * dx + dy * dy
    if l2 > 1 and l2 <= 64 * 64 then
      local l = math.sqrt(l2)
      sx, sy = sx + (t.w or 1) * dx / l, sy + (t.w or 1) * dy / l
    end
  end
  if sx * sx + sy * sy < 1e-9 and hq then sx, sy = site.x - hq.x, site.y - hq.y end
  local l = math.sqrt(sx * sx + sy * sy)
  if l < 1e-9 then return 0, -1 end
  return sx / l, sy / l
end

--- Emplacements du groupe : centre g = site + Gs.GROUP_DIST × dir ; trame de pas Gs.SPOT_STEP dans le repère (tangente, normale), à moins de
--- Gs.SPOT_R de g, triés par distance à g (puis par rang : ordre fixe). Rend g et la liste { {x, y} }.
function Gs.spots(site, nx, ny)
  local gx, gy = site.x + Gs.GROUP_DIST * nx, site.y + Gs.GROUP_DIST * ny
  local tx, ty = -ny, nx
  local list = {}
  local k = math.floor(Gs.SPOT_R / Gs.SPOT_STEP)
  local rank = 0
  for j = -k, k do
    for i = -k, k do
      local a, c = i * Gs.SPOT_STEP, j * Gs.SPOT_STEP * 2 -- rangées espacées de 7 : écart >= 6 en travers aussi
      local r2 = a * a + c * c
      if (i + j) % 2 == 0 and r2 <= Gs.SPOT_R * Gs.SPOT_R then
        rank = rank + 1
        list[#list + 1] = { x = gx + a * tx + c * nx, y = gy + a * ty + c * ny, r2 = r2, rank = rank }
      end
    end
  end
  table.sort(list, function(p, q) if p.r2 ~= q.r2 then return p.r2 < q.r2 end return p.rank < q.rank end)
  local out = {}
  for _, p in ipairs(list) do out[#out + 1] = { x = p.x, y = p.y } end
  return { x = gx, y = gy }, out
end

function Gs.accepts(g, x, y) return d2(g.x, g.y, x, y) <= Gs.ACCEPT * Gs.ACCEPT end

--- Sites { {key, x, y, have, want, wave, w} } -> le premier à servir (have < want, pas au repos `rest[key]`), dans l'ordre : vague décroissante,
--- poids décroissant, clé ; et le nombre de sites servis.
function Gs.pick(sites, rest)
  local rows = {}
  for _, s in ipairs(sites or {}) do rows[#rows + 1] = s end
  table.sort(rows, function(a, b)
    if (a.wave or 0) ~= (b.wave or 0) then return (a.wave or 0) > (b.wave or 0) end
    if (a.w or 0) ~= (b.w or 0) then return (a.w or 0) > (b.w or 0) end
    return tostring(a.key) < tostring(b.key)
  end)
  local pick, served = nil, 0
  for _, s in ipairs(rows) do
    if s.have >= s.want then served = served + 1
    elseif not pick and not (rest and rest[s.key]) then pick = s end
  end
  return pick, served, #rows
end

--- Budget en tourelles commandables maintenant. s = { granted (fer accordé par DEPENSES, nil sans le module), iron (stock), free (fer libre
--- hors besoin, repli), unit (fer d'une tourelle armée), held (tourelles de la garde vivantes, repli), want, rich, pct } -> (n, source).
function Gs.budget(s)
  local unit, want = s.unit or 0, math.max(0, s.want or 0)
  if unit <= 0 or (s.iron or 0) < (s.rich or Gs.RICH_IRON) then return 0, "pauvre" end
  if s.granted ~= nil then
    return math.min(want, math.floor(math.max(0, s.granted) / unit)), "depenses"
  end
  local a = math.floor((s.pct or Gs.FREE_PCT) * math.max(0, s.free or 0) / (100 * unit)) - (s.held or 0)
  if a < 0 then a = 0 end
  return math.min(want, a), "repli"
end

--- Demande écrite pour DEPENSES : { [clé du fer] = tourelles × unit, [clé de la pierre] = murs × Gs.WALL_ITEMS } (clés données par l'appelant).
function Gs.want_table(iron_key, turrets, unit, stone_key, walls)
  local t = {}
  if iron_key and (turrets or 0) > 0 and (unit or 0) > 0 then t[iron_key] = turrets * unit end
  if stone_key and (walls or 0) > 0 then t[stone_key] = walls * Gs.WALL_ITEMS end
  return t
end

--- Anneau de murs d'une boîte { x0, y0, x1, y1 } (tuiles, incluses) élargie de Gs.WALL_MARGIN : 4 côtés (n, e, s, o) en tuiles { tx, ty },
--- coins une fois ; la porte (Gs.GATE tuiles) au milieu du côté tourné vers `gate` (un point, le QG) n'est pas murée.
function Gs.ring(box, gate)
  local m = Gs.WALL_MARGIN
  local x0, y0, x1, y1 = box.x0 - m - 1, box.y0 - m - 1, box.x1 + m + 1, box.y1 + m + 1
  local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
  local gside
  if gate then
    local dx, dy = gate.x - cx, gate.y - cy
    if math.abs(dx) * (y1 - y0) >= math.abs(dy) * (x1 - x0) then gside = dx >= 0 and "e" or "o" else gside = dy >= 0 and "s" or "n" end
  end
  local runs = { n = {}, e = {}, s = {}, o = {} }
  local half = math.floor(Gs.GATE / 2)
  local function add(side, tx, ty, mid, pos)
    if side == gside and math.abs(pos - mid) <= half then return end
    runs[side][#runs[side] + 1] = { tx = tx, ty = ty }
  end
  local mx, my = math.floor((x0 + x1) / 2), math.floor((y0 + y1) / 2)
  for tx = x0, x1 do add("n", tx, y0, mx, tx) end
  for ty = y0 + 1, y1 do add("e", x1, ty, my, ty) end
  for tx = x1 - 1, x0, -1 do add("s", tx, y1, mx, tx) end
  for ty = y1 - 1, y0 + 1, -1 do add("o", x0, ty, my, ty) end
  return { runs = runs, order = { "n", "e", "s", "o" }, gate = gside, box = { x0, y0, x1, y1 } }
end

local function tkey(tx, ty) return (tx + 32768) * 65536 + (ty + 32768) end
Gs.tkey = tkey

--- Segment suivant d'un anneau : les tuiles non réclamées (`claimed[tkey]`) ni refusées (`skip(tx, ty)` vrai) du premier côté qui en a, au plus
--- `cap` (et au moins Gs.SEG_MIN, sinon nil, « stock » ; sauf le reste d'un côté) ; rend (segment { side, walls }, raison).
function Gs.next_segment(ring, claimed, cap, skip)
  for _, side in ipairs(ring.order) do
    local free = {}
    for _, t in ipairs(ring.runs[side]) do
      if not claimed[tkey(t.tx, t.ty)] and not (skip and skip(t.tx, t.ty)) then free[#free + 1] = t end
    end
    if #free > 0 then
      local n = math.min(#free, cap or 0)
      if n < math.min(#free, Gs.SEG_MIN) then return nil, "stock" end
      local walls = {}
      for i = 1, n do walls[i] = free[i] end
      return { side = side, walls = walls }, nil
    end
  end
  return nil, "complet"
end

--- Une tuile est-elle dans l'usine du joueur ? (à moins de Gs.PLAYER_GAP tuiles, Chebyshev, d'une boîte { x0, y0, x1, y1 } de ses bâtiments)
function Gs.in_player_zone(tx, ty, boxes)
  local g = Gs.PLAYER_GAP
  for _, b in ipairs(boxes or {}) do
    if tx + 0.5 >= b.x0 - g and tx + 0.5 <= b.x1 + g and ty + 0.5 >= b.y0 - g and ty + 0.5 <= b.y1 + g then return true end
  end
  return false
end

return Gs
