--[[
  Lot IA3-k « comportements visibles » : CARTE DU DANGER d'une équipe (docs/IA3K_COMPORTEMENTS.md §2, §4). PUR : aucune
  API Factorio, testable hors jeu (tests/ia3k_danger_test.lua).

  Ce que l'équipe a VU (menaces fixes : vers, nids, tourelles adverses ; menaces mobiles : unités, personnages adverses),
  ce qu'elle a SUBI (attaques) et ses MORTS, par cases de D.CELL tuiles. Aucune vérité du moteur : seulement les regards
  de ses PNJ. Nombres et tables seulement (rangé dans `global` par script/ai3/comportement.lua).

  map = {
    cells   = { [clé] = { m = score mobile, t = tick de m } },   -- unités vues, attaques subies (10 % par minute)
    threats = { { x, y, k = genre, r = portée, t = dernier regard }, ... }   -- fixes, D.MAX_THREATS au plus
    deaths  = { { x, y, t }, ... }                                           -- D.MAX_DEATHS au plus, 60 min
  }
  Décroissances par tables ENTIÈRES (aucune puissance flottante, aucune trigonométrie) ; aucun ordre de `pairs`.
]]

local D = {}

D.CELL = 16
D.OFF = 32768
D.MARGIN = 10           -- marge ajoutée à la portée d'une menace (8 laissait passer à 29 tuiles d'un ver de 30)
D.ATTACK_W = 300        -- attaque subie (perte de vie sans ennemi vu ou en plus de lui)
D.ATTACK_R = 16
D.DEATH_W = 600         -- une mort
D.DEATH_R = 24
D.DEATH_FULL = 30 * 3600 -- pleine pendant 30 min, puis 10 % par minute
D.HOUR = 60 * 3600       -- fenêtre de la règle « au plus 2 morts au même endroit par heure »
D.HOUR_R = 32            -- « au même endroit »
D.MOBILE_CAP = 900
D.MAX_THREATS = 48
D.MAX_DEATHS = 32
D.MAX_CELLS = 256

-- Genres (tirés du TYPE de l'entité vue, jamais de son nom) : poids et portée par défaut (la portée réelle du
-- prototype, quand elle est lue, la remplace).
D.KINDS = {
  worm = { w = 1000, r = 30, fixed = true },      -- « turret » de la force des déchiqueteurs
  turret = { w = 1000, r = 24, fixed = true },    -- tourelle d'une force adverse
  spawner = { w = 800, r = 30, fixed = true },    -- nid (les déchiqueteurs qui le gardent voient à 30 tuiles)
  -- MEUTE : zone d'un groupe d'unités devant lequel un PNJ a réagi (portée = vue + étendue du groupe) ; bloquante, mais
  -- elle s'éteint vite (10 % par minute) et un regard qui la voit vide l'efface.
  pack = { w = 800, r = 30, fixed = true, fast = true, same = 12 },
  unit = { w = 150, r = 16, fixed = false },
  character = { w = 150, r = 16, fixed = false },
}

-- Tables de décroissance (pour mille) par minute écoulée : 10 % et 2 % par minute.
local DEC10, DEC2 = { [0] = 1000 }, { [0] = 1000 }
for k = 1, 120 do DEC10[k] = math.floor(DEC10[k - 1] * 9 / 10) end
for k = 1, 480 do DEC2[k] = math.floor(DEC2[k - 1] * 98 / 100) end
D.DEC10, D.DEC2 = DEC10, DEC2

local function dec(tab, n, dt)
  local k = math.floor(dt / 3600)
  if k <= 0 then return 1000 end
  if k > n then return 0 end
  return tab[k]
end
function D.dec10(dt) return dec(DEC10, 120, dt) end
function D.dec2(dt) return dec(DEC2, 480, dt) end

function D.new() return { cells = {}, threats = {}, deaths = {}, n_cells = 0 } end

function D.cell(v) return math.floor(v / D.CELL) end
function D.key(cx, cy) return (cx + D.OFF) * 65536 + (cy + D.OFF) end
function D.unkey(k)
  local a = math.floor(k / 65536)
  return a - D.OFF, k - a * 65536 - D.OFF
end
function D.center(cx, cy) return cx * D.CELL + D.CELL / 2, cy * D.CELL + D.CELL / 2 end

--- Distance au carré d'un point au rectangle de la case (cx, cy).
function D.d2_cell(x, y, cx, cy)
  local x0, y0 = cx * D.CELL, cy * D.CELL
  local x1, y1 = x0 + D.CELL, y0 + D.CELL
  local dx = (x < x0) and (x0 - x) or ((x > x1) and (x - x1) or 0)
  local dy = (y < y0) and (y0 - y) or ((y > y1) and (y - y1) or 0)
  return dx * dx + dy * dy
end

--- Cases dont le rectangle est à moins de r tuiles de (x, y), dans l'ordre (cy, cx) croissant : appel de fn(cx, cy).
local function cells_within(x, y, r, fn)
  local c0x, c1x = D.cell(x - r), D.cell(x + r)
  local c0y, c1y = D.cell(y - r), D.cell(y + r)
  local r2 = r * r
  for cy = c0y, c1y do
    for cx = c0x, c1x do
      if D.d2_cell(x, y, cx, cy) <= r2 then fn(cx, cy) end
    end
  end
end
D.cells_within = cells_within

local function mobile_now(c, tick)
  return math.floor(c.m * D.dec10(tick - c.t) / 1000)
end

local function add_mobile(map, x, y, r, w, tick)
  cells_within(x, y, r, function(cx, cy)
    local k = D.key(cx, cy)
    local c = map.cells[k]
    if not c then
      c = { m = 0, t = tick }
      map.cells[k] = c
      map.n_cells = (map.n_cells or 0) + 1
    end
    local m = mobile_now(c, tick) + w
    if m > D.MOBILE_CAP then m = D.MOBILE_CAP end
    c.m, c.t = m, tick
  end)
end

--- Une menace VUE en (x, y) : genre (D.KINDS), portée (nil : celle du genre). Renvoie true si c'est du nouveau
--- (menace fixe inconnue ou case mobile qui n'était pas marquée).
function D.mark_seen(map, x, y, kind, range, tick)
  local K = D.KINDS[kind] or D.KINDS.unit
  local r = range or K.r
  if K.fixed then
    local same = (K.same or 3) * (K.same or 3)
    for _, t in ipairs(map.threats) do
      local dx, dy = t.x - x, t.y - y
      if t.k == kind and dx * dx + dy * dy <= same then
        t.t = tick
        if K.fast then t.x, t.y, t.r = x, y, r elseif r > t.r then t.r = r end
        return false
      end
    end
    map.threats[#map.threats + 1] = { x = x, y = y, k = kind, r = r, t = tick }
    if #map.threats > D.MAX_THREATS then
      local oldest = 1
      for i, t in ipairs(map.threats) do if t.t < map.threats[oldest].t then oldest = i end end
      table.remove(map.threats, oldest)
    end
    return true
  end
  local k = D.key(D.cell(x), D.cell(y))
  local fresh = map.cells[k] == nil or mobile_now(map.cells[k], tick) < K.w
  add_mobile(map, x, y, r + D.MARGIN, K.w, tick)
  return fresh
end

--- Attaque subie en (x, y) (perte de vie d'un PNJ).
function D.mark_attack(map, x, y, tick)
  add_mobile(map, x, y, D.ATTACK_R, D.ATTACK_W, tick)
end

--- Mort d'un PNJ de l'équipe en (x, y).
function D.mark_death(map, x, y, tick)
  local keep = {}
  for _, d in ipairs(map.deaths) do
    if tick - d.t < D.HOUR then keep[#keep + 1] = d end
  end
  keep[#keep + 1] = { x = x, y = y, t = tick }
  while #keep > D.MAX_DEATHS do table.remove(keep, 1) end
  map.deaths = keep
end

--- Un regard centré en (x, y), de rayon r, a vu son ennemi le plus proche à la distance `nearest` (nil : aucun). Les
--- menaces fixes connues plus près que lui (moins 2 tuiles) ne sont plus là : oubliées (nid nettoyé, ver détruit).
--- Renvoie le nombre de menaces oubliées.
function D.forget_unseen(map, x, y, r, nearest)
  local lim = (nearest and math.min(nearest, r) or r) - 2
  if lim <= 0 then return 0 end
  local l2 = lim * lim
  local keep, n = {}, 0
  for _, t in ipairs(map.threats) do
    local dx, dy = t.x - x, t.y - y
    if dx * dx + dy * dy < l2 then n = n + 1 else keep[#keep + 1] = t end
  end
  if n > 0 then map.threats = keep end
  return n
end

local function death_w(d, tick)
  local age = tick - d.t
  if age < D.DEATH_FULL then return D.DEATH_W end
  return math.floor(D.DEATH_W * D.dec10(age - D.DEATH_FULL) / 1000)
end

--- CHAMP du danger dans une boîte de cases { cx0, cy0, cx1, cy1 } (nil : partout) : table { [clé] = danger } des seules
--- cases non nulles, et leur nombre. Coût : menaces × cases de leur disque + morts + cases mobiles.
function D.field(map, tick, box)
  local out, n = {}, 0
  local function add(cx, cy, w)
    if w <= 0 then return end
    if box and (cx < box[1] or cy < box[2] or cx > box[3] or cy > box[4]) then return end
    local k = D.key(cx, cy)
    if not out[k] then n = n + 1 end
    out[k] = (out[k] or 0) + w
  end
  for _, t in ipairs(map.threats) do
    local K = D.KINDS[t.k] or D.KINDS.unit
    local w = math.floor(K.w * (K.fast and D.dec10(tick - t.t) or D.dec2(tick - t.t)) / 1000)
    if w > 0 then cells_within(t.x, t.y, t.r + D.MARGIN, function(cx, cy) add(cx, cy, w) end) end
  end
  for _, d in ipairs(map.deaths) do
    local w = death_w(d, tick)
    if w > 0 then cells_within(d.x, d.y, D.DEATH_R, function(cx, cy) add(cx, cy, w) end) end
  end
  -- Cases mobiles : clés triées (aucun ordre de pairs).
  local keys = {}
  for k in pairs(map.cells) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local cx, cy = D.unkey(k)
    add(cx, cy, mobile_now(map.cells[k], tick))
  end
  return out, n
end

--- Danger d'une case (sans champ précalculé : pour un contrôle ponctuel).
function D.danger_at(map, x, y, tick)
  local cx, cy = D.cell(x), D.cell(y)
  local f = D.field(map, tick, { cx, cy, cx, cy })
  return f[D.key(cx, cy)] or 0
end

--- Morts de l'heure à moins de r tuiles d'une liste de points (polyligne échantillonnée), comptées une fois chacune.
function D.deaths_near(map, pts, r, tick)
  local r2, n = r * r, 0
  for _, d in ipairs(map.deaths) do
    if tick - d.t < D.HOUR then
      for _, p in ipairs(pts) do
        local dx, dy = p.x - d.x, p.y - d.y
        if dx * dx + dy * dy <= r2 then n = n + 1 break end
      end
    end
  end
  return n
end

--- Seuil de blocage d'une case selon la prudence (pour mille ; 1 000 neutre) : 400 à 750.
function D.block(prudence)
  local b = math.floor(600000 / math.max(1, prudence or 1000))
  if b < 400 then return 400 end
  if b > 750 then return 750 end
  return b
end

--- PORTE d'une tâche (C5, C6). info = { blocked, max_d, goal_d, deaths, far } (itinéraire du PNJ vers sa destination) ;
--- ctx = { B, prudence, escort_ok }. Renvoie "go" | "escort" | "wait", puis la raison.
function D.gate(info, ctx)
  local B = ctx.B or D.block(ctx.prudence)
  local esc = ctx.escort_ok and true or false
  if (info.deaths or 0) >= 2 then return "wait", "morts" end
  if info.blocked or (info.goal_d or 0) >= B or (info.deaths or 0) == 1 then
    if esc then return "escort", info.blocked and "bloque" or ((info.deaths or 0) == 1 and "mort" or "but") end
    return "wait", info.blocked and "bloque" or ((info.deaths or 0) == 1 and "mort" or "but")
  end
  if (info.max_d or 0) * 2 >= B then
    if esc then return "escort", "marque" end
    if (ctx.prudence or 1000) >= 1000 then return "wait", "marque" end
    return "go", "marque"
  end
  if info.far and esc then return "escort", "loin" end
  return "go", "sur"
end

--- Ménage : cases mobiles éteintes, menaces fixes oubliées par le temps, morts hors de l'heure ; au plus MAX_CELLS cases
--- (les plus faibles partent d'abord). Renvoie le nombre de cases retirées.
function D.prune(map, tick)
  local keys = {}
  for k in pairs(map.cells) do keys[#keys + 1] = k end
  table.sort(keys)
  local removed = 0
  local live = {}
  for _, k in ipairs(keys) do
    local m = mobile_now(map.cells[k], tick)
    if m < 10 then
      map.cells[k] = nil
      removed = removed + 1
    else
      live[#live + 1] = { k = k, m = m }
    end
  end
  if #live > D.MAX_CELLS then
    table.sort(live, function(a, b) if a.m ~= b.m then return a.m < b.m end return a.k < b.k end)
    for i = 1, #live - D.MAX_CELLS do
      map.cells[live[i].k] = nil
      removed = removed + 1
    end
  end
  map.n_cells = 0
  for _ in pairs(map.cells) do map.n_cells = map.n_cells + 1 end
  local th = {}
  for _, t in ipairs(map.threats) do
    local K = D.KINDS[t.k] or D.KINDS.unit
    if (K.fast and D.dec10(tick - t.t) or D.dec2(tick - t.t)) * K.w >= 50 * 1000 then th[#th + 1] = t end
  end
  map.threats = th
  local de = {}
  for _, d in ipairs(map.deaths) do if tick - d.t < D.HOUR then de[#de + 1] = d end end
  map.deaths = de
  return removed
end

--- Résumé (journal, interface des bancs).
function D.summary(map, tick)
  local nests, worms, turrets, packs = 0, 0, 0, 0
  for _, t in ipairs(map.threats) do
    if t.k == "spawner" then nests = nests + 1 elseif t.k == "worm" then worms = worms + 1
    elseif t.k == "pack" then packs = packs + 1 else turrets = turrets + 1 end
  end
  local deaths = 0
  for _, d in ipairs(map.deaths) do if tick - d.t < D.HOUR then deaths = deaths + 1 end end
  local cells = 0
  for _ in pairs(map.cells) do cells = cells + 1 end
  return { nests = nests, worms = worms, turrets = turrets, packs = packs, deaths = deaths, cells = cells, threats = #map.threats }
end

return D
