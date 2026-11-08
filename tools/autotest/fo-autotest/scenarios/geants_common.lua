--[[
  Lot GISEMENTS-GEANTS (demande du DC, 8/11 17 h 50) : « Vos agents considèrent qu'ils ont couvert "100%" d'un gisement parce
  que vos environnements de test utilisent les petits gisements de départ (des petits cercles parfaits) [...] Sur de vrais
  gisements massifs, l'IA ne couvre rien du tout [...] Vous devez impérativement augmenter la taille des gisements dans vos
  tests. Forcez l'IA à réagir face à des champs de minerais immenses. »

  Ce module ne sert qu'aux bancs : il n'est lu que par scenarios/etape1-geants.lua et scenarios/etape1-geants-court.lua.
  Il apporte trois choses, sans toucher au mod :
    1. POSE (place_all) : par équipe (votre équipe et chaque faction), 2 gisements par minerai (fer, cuivre, charbon, pierre), de
       2 500 à 5 000 tuiles chacun, IRRÉGULIERS (chaîne de 4 lobes elliptiques tournés + bruit de valeur, jamais un disque), à 60-200
       tuiles du QG, le second collé au premier (écart de 3 tuiles), richesse 1 000 à 5 000 par tuile (plus riche au coeur). Posés
       par create_entity de ressources sur des tuiles terrestres, à 2 tuiles au moins de l'eau, hors falaises et nids, hors des
       gisements naturels (2 tuiles de marge : jamais de minerai mêlé). Les gisements de départ sont GARDÉS. Posés dès que tous
       les QG existent (lancement automatique de la guerre, tick 600 à 1200) : avant que les équipes ne posent quoi que ce soit.
    2. RELEVÉ (releve) : ligne [FO-GEANTS] par minute, par équipe et par gisement géant : tuiles couvertes par des foreuses (zone de
       minage du prototype), électriques et thermiques (= sans source électrique) séparées, pour-mille couvert, foreuses dessus,
       lignes de tapis qui en sortent (composantes connexes de tapis alimentées par une foreuse du gisement ; sorties directes
       dans une machine ou un coffre comptées à part).
    3. CONTRÔLES (checks) : gisements posés, tailles, distances, formes, minerai bien présent ; et un TÉMOIN du relevé
       (control) : un gisement synthétique, 2 foreuses électriques sur un tapis, 1 thermique sur un autre tapis, 1 thermique
       dans un coffre, dont le relevé doit rendre exactement les nombres attendus.
  Tout est déterministe : graines fixes, aucun ordre de pairs, pas de temps mesuré.
]]

local M = {}

M.MINERAIS = { -- ordre fixe ; n1 = tuiles du gisement principal, n2 = du gisement voisin (avant variation de ± 8 % par équipe)
  { ore = "iron-ore", n1 = 5000, n2 = 3500 },
  { ore = "copper-ore", n1 = 4200, n2 = 3000 },
  { ore = "coal", n1 = 3500, n2 = 2600 },
  { ore = "stone", n1 = 3000, n2 = 2700 },
}
M.DMIN, M.DMAX = 60, 200
M.MIN_TUILES = 2500
M.IRR_MAX = 0.75 -- tuiles / (pi * rmax^2) : un disque parfait vaut 1
local HALO = 3   -- écart entre deux gisements posés
local NAT = 2    -- marge autour d'un gisement naturel

local floor, ceil, sqrt, exp, cos, sin = math.floor, math.ceil, math.sqrt, math.exp, math.cos, math.sin
local PI = 3.14159265358979

local function key(x, y) return x * 65536 + y end

---------------------------------------------------------------------------------------------------
-- Hasard déterministe
---------------------------------------------------------------------------------------------------
local function make_rng(seed)
  local s = seed % 2147483646 + 1
  return function()
    s = (s * 48271) % 2147483647
    return s / 2147483647
  end
end

local function hash01(ix, iy, seed)
  local h = (ix * 73856093 + iy * 19349663 + seed * 83492791) % 2147483647
  h = (h * 48271) % 2147483647
  h = (h * 48271) % 2147483647
  return h / 2147483647
end

local function vnoise(x, y, seed)
  local ix, iy = floor(x), floor(y)
  local fx, fy = x - ix, y - iy
  fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
  local a, b = hash01(ix, iy, seed), hash01(ix + 1, iy, seed)
  local c, d = hash01(ix, iy + 1, seed), hash01(ix + 1, iy + 1, seed)
  return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy
end

---------------------------------------------------------------------------------------------------
-- Forme d'un gisement : meilleures tuiles d'un champ de scores (chaîne de lobes elliptiques tournés + bruit)
---------------------------------------------------------------------------------------------------
--- Tuiles candidates triées par score décroissant : { { k, x, y, sc }, ... } (x, y = coin de la tuile).
local function shape(seed, n, cx, cy)
  local rng = make_rng(seed)
  local a0 = sqrt(n / 7.9)
  local lobes, x, y = {}, 0, 0
  local dir = rng() * 2 * PI
  for i = 1, 4 do
    local a = a0 * (0.75 + 0.5 * rng())
    local th = dir + (rng() - 0.5) * 0.8
    lobes[i] = { x = x, y = y, a = a, b = a * (0.55 + 0.4 * rng()), c = cos(th), s = sin(th) }
    dir = dir + (rng() - 0.5) * 1.8
    x, y = x + cos(dir) * a * 0.95, y + sin(dir) * a * 0.95
  end
  local mx, my = 0, 0
  for _, l in ipairs(lobes) do mx, my = mx + l.x / 4, my + l.y / 4 end
  for _, l in ipairs(lobes) do l.x, l.y = l.x - mx + cx, l.y - my + cy end
  local by_key = {}
  for _, l in ipairs(lobes) do
    local r = 2.3 * l.a
    for tx = floor(l.x - r), ceil(l.x + r) do
      for ty = floor(l.y - r), ceil(l.y + r) do
        local dx, dy = tx + 0.5 - l.x, ty + 0.5 - l.y
        local u, v = (dx * l.c + dy * l.s) / l.a, (-dx * l.s + dy * l.c) / l.b
        local q = u * u + v * v
        if q < 5.3 then
          local k = key(tx, ty)
          local sc = exp(-q)
          local cur = by_key[k]
          if not cur or sc > cur.sc then by_key[k] = { k = k, x = tx, y = ty, sc = sc } end
        end
      end
    end
  end
  local list = {}
  for _, c in pairs(by_key) do -- l'ordre de pairs est effacé par le tri total qui suit (score, puis clé)
    local nz = 0.65 * vnoise(c.x / 7, c.y / 7, seed) + 0.35 * vnoise(c.x / 3, c.y / 3, seed + 7)
    c.sc = c.sc + 0.40 * (nz - 0.5)
    list[#list + 1] = c
  end
  table.sort(list, function(p, q) if p.sc ~= q.sc then return p.sc > q.sc end return p.k < q.k end)
  return list
end
M._shape = shape

---------------------------------------------------------------------------------------------------
-- Terrain
---------------------------------------------------------------------------------------------------
local WCACHE = {} -- [clé de tuile] = vrai si l'eau (ou le vide) occupe la tuile

local function is_water(s, x, y)
  local k = key(x, y)
  local w = WCACHE[k]
  if w == nil then
    local t = s.get_tile(x, y)
    w = (t.name == "out-of-map") or t.collides_with("resource-layer")
    WCACHE[k] = w
  end
  return w
end

local function tile_ok(s, x, y)
  return not (is_water(s, x, y) or is_water(s, x + 2, y) or is_water(s, x - 2, y) or is_water(s, x, y + 2) or is_water(s, x, y - 2))
end

--- Tuiles à éviter dans une zone : falaises (3 tuiles autour) et nids ennemis (10 tuiles autour).
local function blocked(s, x0, y0, x1, y1)
  local bad = {}
  local function mark(px, py, r)
    local bx, by = floor(px), floor(py)
    for dx = -r, r do for dy = -r, r do bad[key(bx + dx, by + dy)] = true end end
  end
  for _, c in ipairs(s.find_entities_filtered({ area = { { x0, y0 }, { x1, y1 } }, type = "cliff" })) do
    mark(c.position.x, c.position.y, 3)
  end
  for _, c in ipairs(s.find_entities_filtered({ area = { { x0, y0 }, { x1, y1 } }, force = "enemy", type = { "unit-spawner", "turret" } })) do
    mark(c.position.x, c.position.y, 10)
  end
  return bad
end

--- Tuiles portant déjà du minerai (naturel ou posé plus tôt) dans une zone.
local function resource_tiles(s, x0, y0, x1, y1)
  local res = {}
  for _, r in ipairs(s.find_entities_filtered({ area = { { x0, y0 }, { x1, y1 } }, type = "resource" })) do
    res[key(floor(r.position.x), floor(r.position.y))] = true
  end
  return res
end

---------------------------------------------------------------------------------------------------
-- Pose d'un gisement
---------------------------------------------------------------------------------------------------
local TILES = {}  -- [numero de gisement] = liste de tuiles { k, x, y } (module)
local OWNER = {}  -- [clé de tuile] = numéro de gisement (module : reconstruit à chaque processus, jamais lu après un rechargement)
local HALOS = {}  -- [clé de tuile] = vrai : tuiles des gisements posés et 3 tuiles autour
M._OWNER = OWNER
M._TILES = TILES

--- Sélection (sans effet de bord) : les n meilleures tuiles valides autour de (cx, cy) pour un QG en `hq`. dmin/dmax : distance au QG.
local function select_tiles(s, hq, n, seed, cx, cy, dmin, dmax)
  local cand = shape(seed, n, cx, cy)
  if #cand == 0 then return {} end
  local x0, y0, x1, y1 = 1e9, 1e9, -1e9, -1e9
  for _, c in ipairs(cand) do
    if c.x < x0 then x0 = c.x end
    if c.y < y0 then y0 = c.y end
    if c.x > x1 then x1 = c.x end
    if c.y > y1 then y1 = c.y end
  end
  x0, y0, x1, y1 = x0 - 6, y0 - 6, x1 + 7, y1 + 7
  local bad = blocked(s, x0, y0, x1, y1)
  local nat = resource_tiles(s, x0, y0, x1, y1)
  local function near_nat(x, y)
    for dx = -NAT, NAT do for dy = -NAT, NAT do if nat[key(x + dx, y + dy)] then return true end end end
    return false
  end
  local out = {}
  for _, c in ipairs(cand) do
    local dx, dy = c.x + 0.5 - hq.x, c.y + 0.5 - hq.y
    local d2 = dx * dx + dy * dy
    if d2 >= dmin * dmin and d2 <= dmax * dmax and not HALOS[c.k] and not bad[c.k] and not near_nat(c.x, c.y) and tile_ok(s, c.x, c.y) then
      out[#out + 1] = c
      if #out >= n then break end
    end
  end
  return out
end

--- Plus grande composante 8-connexe d'un ensemble de tuiles { [clé] = { x, y } } : nombre de tuiles.
local function largest_component(tiles, list)
  local seen, best = {}, 0
  for _, t in ipairs(list) do
    if not seen[t.k] then
      local q, h = { t }, 1
      seen[t.k] = true
      while h <= #q do
        local c = q[h]; h = h + 1
        for dx = -1, 1 do
          for dy = -1, 1 do
            local k2 = key(c.x + dx, c.y + dy)
            if tiles[k2] and not seen[k2] then seen[k2] = true; q[#q + 1] = tiles[k2] end
          end
        end
      end
      if #q > best then best = #q end
    end
  end
  return best
end

--- Crée les ressources de `sel` (tuiles choisies) ; rend la fiche du gisement. `num` : numéro de gisement (état).
local function commit(s, sel, ore, num, team, hq, rng)
  local n = #sel
  local tiles, made, fail = {}, 0, 0
  local amin, amax, asum = 1e9, 0, 0
  local sx, sy = 0, 0
  local x0, y0, x1, y1 = 1e9, 1e9, -1e9, -1e9
  for i, c in ipairs(sel) do
    tiles[c.k] = c
    local frac = 1 - (i - 1) / n
    local amount = floor((1000 + 4000 * frac ^ 1.4) * (0.9 + 0.2 * rng()))
    if amount < 1000 then amount = 1000 elseif amount > 5000 then amount = 5000 end
    local ok, e = pcall(s.create_entity, { name = ore, position = { c.x + 0.5, c.y + 0.5 }, amount = amount })
    if ok and e then made = made + 1 else fail = fail + 1 end
    if amount < amin then amin = amount end
    if amount > amax then amax = amount end
    asum = asum + amount
    sx, sy = sx + c.x + 0.5, sy + c.y + 0.5
    if c.x < x0 then x0 = c.x end
    if c.y < y0 then y0 = c.y end
    if c.x > x1 then x1 = c.x end
    if c.y > y1 then y1 = c.y end
    OWNER[c.k] = num
    for dx = -HALO, HALO do for dy = -HALO, HALO do HALOS[key(c.x + dx, c.y + dy)] = true end end
  end
  TILES[num] = sel
  local cx, cy = sx / n, sy / n
  local rmax2, dmin, dmax = 0, 1e9, 0
  for _, c in ipairs(sel) do
    local dx, dy = c.x + 0.5 - cx, c.y + 0.5 - cy
    local r2 = dx * dx + dy * dy
    if r2 > rmax2 then rmax2 = r2 end
    local hx, hy = c.x + 0.5 - hq.x, c.y + 0.5 - hq.y
    local d = sqrt(hx * hx + hy * hy)
    if d < dmin then dmin = d end
    if d > dmax then dmax = d end
  end
  return {
    num = num, team = team.key, force = team.force, ore = ore, n = n, made = made, fail = fail, cx = cx, cy = cy,
    x0 = x0, y0 = y0, x1 = x1 + 1, y1 = y1 + 1, dmin = dmin, dmax = dmax, irr = n / (PI * rmax2),
    comp = largest_component(tiles, sel), amin = amin, amax = amax, aavg = floor(asum / n),
  }
end

--- Pose un gisement de `n` tuiles : essais successifs (centres tournés) jusqu'à 97 % de `n`, sinon le meilleur essai.
--- `centers(a)` rend le centre de l'essai a (0 à 11).
local function place_deposit(s, team, hq, ore, n, seed, centers, num, dmin, dmax, rng)
  local best
  for a = 0, 11 do
    local cx, cy = centers(a)
    local sel = select_tiles(s, hq, n, seed + 17 * a, cx, cy, dmin, dmax)
    if not best or #sel > #best then best = sel end
    if #sel >= n * 0.97 then break end
  end
  if not best or #best == 0 then return nil end
  return commit(s, best, ore, num, team, hq, rng)
end

---------------------------------------------------------------------------------------------------
-- Équipes
---------------------------------------------------------------------------------------------------
--- Votre équipe (coffre d'équipe) puis les factions (QG) triées par clé : { { key, force, x, y }, ... }.
function M.teams(s)
  local out = {}
  local chest = s.find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
  if chest then out[#out + 1] = { key = "player", force = "player", x = chest.position.x, y = chest.position.y } end
  local rows = {}
  for _, r in ipairs(remote.call("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then rows[#rows + 1] = r end
  end
  table.sort(rows, function(a, b) return tostring(a.key) < tostring(b.key) end)
  for _, r in ipairs(rows) do
    local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = r.force, limit = 1 })[1]
    if hq then out[#out + 1] = { key = r.key, force = r.force, x = hq.position.x, y = hq.position.y } end
  end
  return out
end

--- Nombre d'équipes attendues : votre équipe + factions du réglage de carte.
function M.expected()
  return 1 + settings.global["fo-war-factions"].value
end

---------------------------------------------------------------------------------------------------
-- POSE pour toutes les équipes
---------------------------------------------------------------------------------------------------
function M.place_all(ctx, teams)
  local s = ctx.surface()
  local st = ctx.state()
  local g = {}
  st.geants = g
  g.deps, g.teams, g.tick = {}, {}, game.tick
  -- chunks : rayon 8 chunks (256 tuiles) autour de chaque QG, générés d'un coup
  for _, t in ipairs(teams) do s.request_to_generate_chunks({ t.x, t.y }, 8) end
  s.force_generate_chunk_requests()
  for ti, t in ipairs(teams) do
    local rec = { key = t.key, force = t.force, x = t.x, y = t.y, deps = {} }
    g.teams[#g.teams + 1] = rec
    local rng = make_rng(9100 + 101 * ti)
    for j, spec in ipairs(M.MINERAIS) do
      local seed = 10000 * ti + 1000 * j
      local n1 = floor(spec.n1 * (0.92 + 0.16 * rng()))
      local n2 = floor(spec.n2 * (0.92 + 0.16 * rng()))
      if n1 < M.MIN_TUILES + 60 then n1 = M.MIN_TUILES + 60 end
      if n2 < M.MIN_TUILES + 60 then n2 = M.MIN_TUILES + 60 end
      -- principal : direction propre à l'équipe et au minerai (quatre quarts), distance 105 à 125
      local ang = ((ti * 53 + (j - 1) * 90 + 17) % 360) * PI / 180
      local dist = 105 + ((j % 2) * 10) + 5 * ti
      local function c1(a) -- essai a : 0, +30, -30, +60, -60... degres autour de la direction de depart
        local step = ceil(a / 2) * (PI / 6)
        if a % 2 == 0 then step = -step end
        local an = ang + step
        local d = dist + ((a % 3) - 1) * 8
        return t.x + cos(an) * d, t.y + sin(an) * d
      end
      local p1 = place_deposit(s, t, t, spec.ore, n1, seed, c1, #g.deps + 1, M.DMIN, M.DMAX, rng)
      if p1 then
        g.deps[#g.deps + 1] = p1
        p1.rang = 1
        rec.deps[#rec.deps + 1] = p1.num
        -- voisin : de côté (perpendiculaire à la direction du QG), à (r1 + r2) du principal, écart de 3 tuiles
        local r1, r2 = sqrt(p1.n / PI), sqrt(n2 / PI)
        local rx, ry = p1.cx - t.x, p1.cy - t.y
        local rl = sqrt(rx * rx + ry * ry)
        local px, py = -ry / rl, rx / rl
        local function c2(a)
          local sgn = (a % 2 == 0) and 1 or -1
          local off = (r1 + r2) * (0.95 + 0.1 * (a % 3))
          local back = ((a % 4) - 1) * 6
          return p1.cx + sgn * px * off - rx / rl * back, p1.cy + sgn * py * off - ry / rl * back
        end
        local p2 = place_deposit(s, t, t, spec.ore, n2, seed + 500, c2, #g.deps + 1, M.DMIN, M.DMAX, rng)
        if p2 then
          g.deps[#g.deps + 1] = p2
          p2.rang = 2
          rec.deps[#rec.deps + 1] = p2.num
        end
      end
    end
  end
  for _, d in ipairs(g.deps) do
    log(string.format("[FO-GEANTS] pose | %s | %s#%d | centre=(%d,%d) tuiles=%d creees=%d echecs=%d d_qg=%d..%d irregularite=%.2f d_un_tenant=%d%% richesse=%d..%d (moy %d)",
      d.team, d.ore, d.rang, floor(d.cx), floor(d.cy), d.n, d.made, d.fail, floor(d.dmin), floor(d.dmax), d.irr,
      floor(100 * d.comp / d.n), d.amin, d.amax, d.aavg))
  end
  g.placed = true
  g.total = 0
  for _, d in ipairs(g.deps) do g.total = g.total + d.made end
  log(string.format("[FO-GEANTS] pose terminee au tick %d : %d equipe(s), %d gisement(s), %d tuiles creees", game.tick, #g.teams, #g.deps, g.total))
end

---------------------------------------------------------------------------------------------------
-- RELEVÉ
---------------------------------------------------------------------------------------------------
local BELT = { ["transport-belt"] = true, ["underground-belt"] = true, ["splitter"] = true, ["loader"] = true,
  ["loader-1x1"] = true, ["linked-belt"] = true }

--- Composante connexe de tapis de `e` (mémoïsée dans `memo`, identifiant dans `counter`).
local function belt_component(e, memo, counter)
  local u = e.unit_number
  if memo[u] then return memo[u] end
  counter.n = counter.n + 1
  local id = counter.n
  memo[u] = id
  local q, h = { e }, 1
  while h <= #q and h <= 60000 do
    local b = q[h]; h = h + 1
    local ok, nb = pcall(function() return b.belt_neighbours end)
    if ok and nb then
      for _, list in ipairs({ nb.inputs or {}, nb.outputs or {} }) do
        for _, o in ipairs(list) do
          if o.valid and o.unit_number and not memo[o.unit_number] then memo[o.unit_number] = id; q[#q + 1] = o end
        end
      end
    end
    if b.type == "underground-belt" then
      local o = b.neighbours
      if o and o.valid and o.unit_number and not memo[o.unit_number] then memo[o.unit_number] = id; q[#q + 1] = o end
    end
  end
  return id
end

local SKIP = { resource = true, tree = true, ["simple-entity"] = true, ["mining-drill"] = true, ["item-entity"] = true,
  corpse = true, ["character-corpse"] = true, cliff = true, fish = true, ["entity-ghost"] = true, ["item-request-proxy"] = true }

--- Entité qui reçoit la production de la foreuse `d` : drop_target du moteur s'il est renseigné, sinon (observé en banc le 8/11 : nil
--- pour une foreuse neuve qui n'a pas encore travaillé) l'entité posée sur le point de dépôt (tapis d'abord).
local function drop_entity(s, d)
  local tg = d.drop_target
  if tg and tg.valid then return tg end
  local p = d.drop_position
  if not p then return nil end
  local best
  for _, o in ipairs(s.find_entities_filtered({ area = { { p.x - 0.05, p.y - 0.05 }, { p.x + 0.05, p.y + 0.05 } } })) do
    if o.valid and not SKIP[o.type] and o.unit_number then
      if BELT[o.type] then return o end
      best = best or o
    end
  end
  return best
end

local function mined_tiles(d)
  local r = d.prototype.mining_drill_radius or 1
  local p = d.position
  local out = {}
  for x = floor(p.x - r + 0.01), ceil(p.x + r - 0.01) - 1 do
    for y = floor(p.y - r + 0.01), ceil(p.y + r - 0.01) - 1 do out[#out + 1] = key(x, y) end
  end
  return out
end

--- Relevé d'une équipe. Rend { deps = { [num] = { cov_e, cov_t, cov, e, t, lines, directs, none } }, hors = foreuses hors géants,
--- total_e, total_t }. Ne lit que le moteur.
function M.measure_team(s, force, dep_nums)
  local mine = {}
  for _, num in ipairs(dep_nums) do mine[num] = true end
  local rows = {}
  for _, num in ipairs(dep_nums) do
    rows[num] = { ce = {}, ct = {}, e = 0, t = 0, comps = {}, directs = 0, none = 0, seen = {} }
  end
  local memo, counter = {}, { n = 0 }
  local hors, tot_e, tot_t = 0, 0, 0
  local drills = s.find_entities_filtered({ type = "mining-drill", force = force })
  for _, d in ipairs(drills) do
    local elec = d.prototype.electric_energy_source_prototype ~= nil
    if elec then tot_e = tot_e + 1 else tot_t = tot_t + 1 end
    local hit = {}
    for _, k in ipairs(mined_tiles(d)) do
      local num = OWNER[k]
      if num and mine[num] then
        local r = rows[num]
        if elec then r.ce[k] = true else r.ct[k] = true end
        hit[num] = true
      end
    end
    local any = false
    for _, num in ipairs(dep_nums) do
      if hit[num] then
        any = true
        local r = rows[num]
        if elec then r.e = r.e + 1 else r.t = r.t + 1 end
        local tg = drop_entity(s, d)
        if tg and tg.valid and BELT[tg.type] and tg.unit_number then
          r.comps[belt_component(tg, memo, counter)] = true
        elseif tg and tg.valid then
          r.directs = r.directs + 1
        else
          r.none = r.none + 1
        end
      end
    end
    if not any then hors = hors + 1 end
  end
  local out = { deps = {}, hors = hors, total_e = tot_e, total_t = tot_t }
  for _, num in ipairs(dep_nums) do
    local r = rows[num]
    local ne, nt, nu = 0, 0, 0
    for k in pairs(r.ce) do ne = ne + 1; nu = nu + 1 end
    for k in pairs(r.ct) do nt = nt + 1; if not r.ce[k] then nu = nu + 1 end end
    local lines = 0
    for _ in pairs(r.comps) do lines = lines + 1 end
    out.deps[num] = { cov_e = ne, cov_t = nt, cov = nu, e = r.e, t = r.t, lines = lines, directs = r.directs, none = r.none }
  end
  return out
end

local function pm(a, b) return b > 0 and floor(1000 * a / b + 0.5) or 0 end

--- Écrit les lignes [FO-GEANTS] d'un relevé pour toutes les équipes. Rend la table { [clé d'équipe] = résultat }.
function M.releve(ctx, label, teams_rec, deps)
  local s = ctx.surface()
  local res = {}
  for _, t in ipairs(teams_rec) do
    local m = M.measure_team(s, t.force, t.deps)
    res[t.key] = m
    local sn, sc, se, st_, sl = 0, 0, 0, 0, 0
    local cee, ctt = 0, 0
    for _, num in ipairs(t.deps) do
      local d, r = deps[num], m.deps[num]
      log(string.format("[FO-GEANTS] %s | %s | %s#%d | tuiles=%d | couvert elec=%d (%d pm) therm=%d (%d pm) total=%d (%d pm) | foreuses elec=%d therm=%d | lignes=%d directes=%d sans_sortie=%d",
        label, t.key, d.ore, d.rang or 1, d.n, r.cov_e, pm(r.cov_e, d.n), r.cov_t, pm(r.cov_t, d.n), r.cov, pm(r.cov, d.n),
        r.e, r.t, r.lines, r.directs, r.none))
      sn, sc, se, st_, sl = sn + d.n, sc + r.cov, se + r.e, st_ + r.t, sl + r.lines
      cee, ctt = cee + r.cov_e, ctt + r.cov_t
    end
    log(string.format("[FO-GEANTS] %s | %s | TOTAL %d gisement(s) %d tuiles | couvert elec=%d therm=%d total=%d (%d pm) | foreuses dessus elec=%d therm=%d, hors geants %d (toutes: elec=%d therm=%d) | lignes=%d",
      label, t.key, #t.deps, sn, cee, ctt, sc, pm(sc, sn), se, st_, m.hors, m.total_e, m.total_t, sl))
  end
  return res
end

---------------------------------------------------------------------------------------------------
-- TÉMOIN du relevé : gisement synthétique + foreuses connues
---------------------------------------------------------------------------------------------------
local CTL = { x = 3300, y = 3300 }

function M.control(ctx)
  local s = ctx.surface()
  local st = ctx.state()
  local g = st.geants
  local c = {}
  g.control = c
  if not game.forces["fo-geants-ctl"] then game.create_force("fo-geants-ctl") end
  s.request_to_generate_chunks({ CTL.x, CTL.y }, 4)
  s.force_generate_chunk_requests()
  local team = { key = "TEMOIN", force = "fo-geants-ctl" }
  local rng = make_rng(77)
  local dep = place_deposit(s, team, CTL, "iron-ore", 1400, 4242, function(a) return CTL.x + (a % 4) * 30, CTL.y + floor(a / 4) * 30 end,
    #g.deps + 1, 0, 120, rng)
  if not dep then c.err = "gisement du temoin non pose"; return end
  dep.rang = 1
  g.deps[#g.deps + 1] = dep
  c.dep = dep.num
  local sel = {}
  for _, c in ipairs(TILES[dep.num]) do sel[#sel + 1] = c end
  table.sort(sel, function(p, q) if p.x ~= q.x then return p.x < q.x end return p.y < q.y end)
  local has = {}
  for _, c in ipairs(sel) do has[c.k] = true end
  local function area_in(x, y, w) -- carré de w x w tuiles de coin (x, y) entièrement dans le gisement
    for dx = 0, w - 1 do for dy = 0, w - 1 do if not has[key(x + dx, y + dy)] then return false end end end
    return true
  end
  -- Cherche : une rangée de deux foreuses électriques à 6 tuiles (zones 5x5 disjointes), puis deux thermiques (2x2) disjointes
  local used = {}
  local function take(x, y, w) for dx = 0, w - 1 do for dy = 0, w - 1 do used[key(x + dx, y + dy)] = true end end end
  local function free(x, y, w) for dx = -1, w do for dy = -1, w do if used[key(x + dx, y + dy)] then return false end end end return true end
  local ex, ey
  for _, c in ipairs(sel) do
    local x, y = c.x, c.y
    if area_in(x, y, 5) and area_in(x + 6, y, 5) then ex, ey = x, y; break end
  end
  if not ex then c.err = "pas de place pour les foreuses electriques"; return end
  take(ex, ey, 5); take(ex + 6, ey, 5)
  local bs = {}
  for _, c in ipairs(sel) do
    local x, y = c.x, c.y
    if area_in(x, y, 2) and free(x, y, 2) and not (x >= ex - 8 and x <= ex + 14 and y >= ey - 4 and y <= ey + 12) then
      bs[#bs + 1] = { x, y }
      take(x, y, 2)
      if #bs == 2 then break end
      -- la seconde est cherchée à 8 tuiles au moins de la première (tapis et coffre sans gêne)
      for dx = -8, 8 do for dy = -8, 8 do used[key(x + dx, y + dy)] = true end end
    end
  end
  if #bs < 2 then c.err = "pas de place pour les foreuses thermiques"; return end
  -- terrain du témoin : arbres et rochers retirés sur la zone des machines et des tapis
  local zx0, zy0 = ex - 3, ey - 3
  for _, e in ipairs(s.find_entities_filtered({ area = { { zx0, zy0 }, { ex + 16, ey + 12 } }, type = { "tree", "simple-entity" } })) do e.destroy() end
  for _, b in ipairs(bs) do
    for _, e in ipairs(s.find_entities_filtered({ area = { { b[1] - 4, b[2] - 4 }, { b[1] + 6, b[2] + 6 } }, type = { "tree", "simple-entity" } })) do e.destroy() end
  end
  local function belt_run(from_x, to_x, y)
    local n = 0
    for x = from_x, to_x do
      if s.create_entity({ name = "transport-belt", position = { x + 0.5, y + 0.5 }, direction = defines.direction.east, force = "fo-geants-ctl" }) then n = n + 1 end
    end
    return n
  end
  local force = "fo-geants-ctl"
  c.elec, c.therm, c.belts = 0, 0, 0
  local e1 = s.create_entity({ name = "electric-mining-drill", position = { ex + 2.5, ey + 2.5 }, direction = defines.direction.south, force = force })
  local e2 = s.create_entity({ name = "electric-mining-drill", position = { ex + 8.5, ey + 2.5 }, direction = defines.direction.south, force = force })
  if e1 and e2 then
    c.elec = 2
    local d1, d2 = e1.drop_position, e2.drop_position
    c.belts = c.belts + belt_run(floor(d1.x), floor(d2.x) + 3, floor(d1.y))
  end
  local b1 = s.create_entity({ name = "burner-mining-drill", position = { bs[1][1] + 1, bs[1][2] + 1 }, direction = defines.direction.south, force = force })
  if b1 then
    c.therm = c.therm + 1
    local d = b1.drop_position
    c.belts = c.belts + belt_run(floor(d.x), floor(d.x) + 4, floor(d.y))
  end
  local b2 = s.create_entity({ name = "burner-mining-drill", position = { bs[2][1] + 1, bs[2][2] + 1 }, direction = defines.direction.south, force = force })
  if b2 then
    c.therm = c.therm + 1
    local d = b2.drop_position
    c.chest = s.create_entity({ name = "wooden-chest", position = { floor(d.x) + 0.5, floor(d.y) + 0.5 }, force = force })
  end
  c.tick = game.tick
  -- ce que le relevé doit rendre : 2 électriques (2 x 25 tuiles), 2 thermiques (2 x 4 tuiles), 2 lignes de tapis, 1 sortie directe
  c.expect = { cov_e = 50, cov_t = 8, cov = 58, e = 2, t = 2, lines = 2, directs = 1 }
  g.teams[#g.teams + 1] = { key = "TEMOIN", force = force, x = CTL.x, y = CTL.y, deps = { dep.num }, control = true }
end

---------------------------------------------------------------------------------------------------
-- CONTRÔLES (au tick de vérification)
---------------------------------------------------------------------------------------------------
function M.checks(ctx, opts)
  opts = opts or {}
  local st = ctx.state()
  local g = st.geants
  ctx.check(g ~= nil and g.placed == true, "GEANTS : gisements immenses poses", g and tostring(g.tick) or "jamais")
  if not (g and g.placed) then return end
  local s = ctx.surface()
  local expected = M.expected()
  local real = 0
  for _, t in ipairs(g.teams) do if not t.control then real = real + 1 end end
  ctx.check(real == expected, string.format("GEANTS : %d equipe(s) servie(s) (votre equipe + factions)", expected), tostring(real))
  for _, t in ipairs(g.teams) do
    if not t.control then
      local by = {}
      for _, num in ipairs(t.deps) do
        local d = g.deps[num]
        by[d.ore] = (by[d.ore] or 0) + 1
      end
      local ok = true
      for _, spec in ipairs(M.MINERAIS) do if by[spec.ore] ~= 2 then ok = false end end
      ctx.check(ok and #t.deps == 8, "GEANTS : " .. t.key .. " : 2 gisements par minerai (fer, cuivre, charbon, pierre)", tostring(#t.deps))
      for _, num in ipairs(t.deps) do
        local d = g.deps[num]
        local name = t.key .. " " .. d.ore .. "#" .. (d.rang or 1)
        ctx.check(d.n >= M.MIN_TUILES and d.fail == 0 and d.made == d.n, "GEANTS : " .. name .. " : au moins " .. M.MIN_TUILES .. " tuiles, toutes creees",
          string.format("%d posees, %d creees, %d echecs", d.n, d.made, d.fail))
        ctx.check(d.dmin >= M.DMIN - 0.5 and d.dmax <= M.DMAX + 0.5, "GEANTS : " .. name .. " : a 60-200 tuiles du QG",
          string.format("%.0f..%.0f", d.dmin, d.dmax))
        ctx.check(d.irr < M.IRR_MAX, "GEANTS : " .. name .. " : forme irreguliere (pas un disque)", string.format("%.2f (disque = 1)", d.irr))
        ctx.check(d.amin >= 1000 and d.amax <= 5000, "GEANTS : " .. name .. " : richesse 1000-5000 par tuile", string.format("%d..%d", d.amin, d.amax))
        local present = s.count_entities_filtered({ area = { { d.x0, d.y0 }, { d.x1, d.y1 } }, name = d.ore, type = "resource" })
        ctx.check(present >= d.n * 0.98, "GEANTS : " .. name .. " : minerai present en jeu", string.format("%d dans la boite pour %d tuiles", present, d.n))
      end
    end
  end
  if opts.control then
    local c = g.control
    ctx.check(c ~= nil and c.err == nil, "GEANTS : temoin du releve pose", c and tostring(c.err) or "absent")
    if c and not c.err then
      local rec
      for _, t in ipairs(g.teams) do if t.control then rec = t end end
      local m = M.measure_team(s, "fo-geants-ctl", rec.deps)
      local r = m.deps[c.dep]
      local x = c.expect
      ctx.check(c.elec == 2 and c.therm == 2, "GEANTS : temoin : 2 foreuses electriques et 2 thermiques posees", string.format("%d, %d", c.elec, c.therm))
      ctx.check(r.cov_e == x.cov_e, "GEANTS : releve : tuiles couvertes par les electriques (2 x 25)", tostring(r.cov_e))
      ctx.check(r.cov_t == x.cov_t, "GEANTS : releve : tuiles couvertes par les thermiques (2 x 4)", tostring(r.cov_t))
      ctx.check(r.cov == x.cov, "GEANTS : releve : tuiles couvertes en tout", tostring(r.cov))
      ctx.check(r.e == x.e and r.t == x.t, "GEANTS : releve : foreuses dessus, electriques et thermiques", string.format("%d, %d", r.e, r.t))
      ctx.check(r.lines == x.lines, "GEANTS : releve : lignes de tapis (2 electriques sur un tapis + 1 thermique sur un autre)", tostring(r.lines))
      ctx.check(r.directs == x.directs, "GEANTS : releve : sortie directe (coffre) comptee a part", tostring(r.directs))
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Crochet de tick commun aux deux scénarios
---------------------------------------------------------------------------------------------------
--- opts.every : ticks entre deux relevés ; opts.control : joue le témoin du relevé ; opts.deadline : tick au-delà duquel on pose
--- pour les équipes déjà nées (défaut 2400). Toute erreur Lua est écrite au journal sans couper le crochet du scénario de base.
function M.on_tick(ctx, e, opts)
  local ok, err = pcall(function()
    local st = ctx.state()
    local s = ctx.surface()
    local g = st.geants
    if not g then
      if e.tick < 1 then return end
      local teams = M.teams(s)
      if #teams >= M.expected() then
        M.place_all(ctx, teams)
      elseif e.tick >= (opts.deadline or 2400) and #teams > 0 then
        log(string.format("[FO-GEANTS] ATTENTION : seulement %d equipe(s) sur %d au tick %d, pose pour celles-la", #teams, M.expected(), e.tick))
        M.place_all(ctx, teams)
      end
      return
    end
    if opts.control and not g.control and e.tick >= g.tick + 30 then M.control(ctx) end
    if e.tick >= g.tick + 60 and (not g.first or (e.tick % opts.every == 0)) then
      g.first = true
      M.releve(ctx, string.format("minute %.1f", e.tick / 3600), g.teams, g.deps)
    end
  end)
  if not ok then log("[FO-GEANTS] ERREUR du crochet de tick au tick " .. tostring(e.tick) .. " : " .. tostring(err)) end
end

return M
