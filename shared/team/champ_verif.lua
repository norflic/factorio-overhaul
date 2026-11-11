--[[
  CHAMP, contrôle d'un plan (lot CHAMP) : ce que le DC verrait sur le terrain, relu sur le plan seul. PUR : aucune API Factorio,
  aucun nom d'objet. Lu par tests/champ_test.lua (champs synthétiques et mutants) et par script/team/champ.lua (journal du plan).

  Cv.verify(plan, spec) -> rapport :
    tiles, covered, elec    tuiles de minerai, tuiles dans la zone d'une foreuse du plan, part (0..1)
    overlaps, blocked       tuiles prises deux fois, entités sur un obstacle
    unpowered               foreuses et bras hors de la zone d'un poteau (fours à combustible exceptés)
    components              réseaux de poteaux (fils à portée) : 1 attendu
    traverse                tuiles de tapis hors de la rangée de tapis de leur bande, ou sens contraire à la sortie du groupe
    inside                  groupes dont le tapis finit DANS le champ (fonderie sur le gisement)
    drops                   foreuses dont la sortie ne tombe pas sur un tapis de leur groupe
    arms                    bras qui ne prennent pas ou ne posent pas où il faut (tapis -> four, four -> coffre, coffre -> four)
    starved                 groupes dont la fonderie (ou les coffres) absorbe moins que les foreuses, ou dont une voie déborde
    melange                 foreuses dont la zone touche une tuile d'une AUTRE ressource minable (lot MELANGE ; foreuses du champ :
                            spec.foreign ; foreuses de la ligne de charbon : spec.coal.foreign)
    ok                      aucun des défauts ci-dessus
]]

local Ch = require("shared.team.champ")

local Cv = {}

local DIRS = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }

-- (lot FONDERIE) une entité peut être un rectangle w × h (répartiteur) ; sinon un carré `size`
local function wh(e) return e.w or e.size, e.h or e.size end

local function origin(e)
  local w, h = wh(e)
  return math.floor(e.x - w / 2 + 0.5), math.floor(e.y - h / 2 + 0.5)
end

local function tiles(e)
  local x0, y0 = origin(e)
  local w, h = wh(e)
  local out = {}
  for x = x0, x0 + w - 1 do for y = y0, y0 + h - 1 do out[#out + 1] = { x, y } end end
  return out
end

---------------------------------------------------------------------------------------------------
-- (lot FONDERIE) Voies des tapis : ce qui circule réellement, objet par objet et voie par voie (règles du moteur 1.1 : un tapis qui
-- arrive par le côté d'un tapis qui a un tapis DERRIÈRE lui, ou un autre arrivant de l'autre côté, charge sa voie proche ; sinon c'est
-- un virage qui garde les voies ; un bras pose sur la voie lointaine ; une foreuse dépose sur la voie lointaine ; un souterrain
-- d'entrée rejoint la première sortie de même sens à `ug` tuiles au plus ; un répartiteur envoie ses deux entrées vers ses deux
-- sorties). Rend le nombre de fours sans minerai, sans charbon (fours à combustible), de coffres de quai sans plaque, de voies mêlées
-- (minerai et charbon sur la même voie) et de raccords impossibles.
---------------------------------------------------------------------------------------------------
local function left(d) local v = DIRS[d]; return v[2], -v[1] end

function Cv.flow(plan, spec)
  local at = {}
  for _, e in ipairs(plan.ents) do for _, t in ipairs(tiles(e)) do at[Ch.key(t[1], t[2])] = e end end
  local function ent_at(x, y) return at[Ch.key(x, y)] end
  local fuel = spec.furnace and spec.furnace.fuel
  local maxd = (spec.logistics and spec.logistics.underground) or 10
  local isbelt = { tapis = true, souterrain = true, repartiteur = true }
  local items = {}   -- clé de tuile -> { [1] = {objet = vrai}, [2] = {...} }
  local held = {}    -- entité -> {objet = vrai} (fours, coffres)
  local rep = { no_ore = 0, no_coal = 0, no_plate = 0, mixed = 0, junction = 0 }
  local bad = {}
  local function flag(e) if not bad[e] then bad[e] = true; rep.junction = rep.junction + 1 end end
  local queue = {}
  local function add(x, y, lane, it)
    local k = Ch.key(x, y)
    items[k] = items[k] or { {}, {} }
    if not items[k][lane][it] then items[k][lane][it] = true; queue[#queue + 1] = { x, y }; return true end
    return false
  end
  local function lane_of(bx, by, bdir, fx, fy) -- voie du tapis (bdir) du côté du vecteur (fx, fy)
    local lx, ly = left(bdir)
    return (fx * lx + fy * ly > 0) and 1 or 2
  end
  local function outputs_into(e, x, y, nx, ny) -- l'entité de tapis `e` (tuile x, y) sort-elle vers (nx, ny) ?
    if not (e and isbelt[e.kind]) then return false end
    if e.kind == "souterrain" and e.ug == "input" then return false end
    local v = DIRS[e.dir]
    return x + v[1] == nx and y + v[2] == ny
  end
  local function feed(x, y, d, lanes) -- ce qui sort de la tuile (x, y) dans le sens d entre en (x, y) + d
    local v = DIRS[d]
    local nx, ny = x + v[1], y + v[2]
    local n = ent_at(nx, ny)
    if not (n and isbelt[n.kind]) then return end
    local dn = n.dir
    local changed = false
    if n.kind == "souterrain" then
      if n.ug ~= "input" or dn ~= d then flag(n) return end
      for l = 1, 2 do for it in pairs(lanes[l]) do changed = add(nx, ny, l, it) or changed end end
      return
    end
    if n.kind == "repartiteur" then
      if dn ~= d then flag(n) return end
      for l = 1, 2 do for it in pairs(lanes[l]) do changed = add(nx, ny, l, it) or changed end end
      return
    end
    if dn == d then
      for l = 1, 2 do for it in pairs(lanes[l]) do add(nx, ny, l, it) end end
    elseif dn == (d + 4) % 8 then
      flag(n)
    else
      local bv = DIRS[dn]
      local behind = outputs_into(ent_at(nx - bv[1], ny - bv[2]), nx - bv[1], ny - bv[2], nx, ny)
      local lx, ly = left(dn)
      local s1 = outputs_into(ent_at(nx + lx, ny + ly), nx + lx, ny + ly, nx, ny)
      local s2 = outputs_into(ent_at(nx - lx, ny - ly), nx - lx, ny - ly, nx, ny)
      if behind or (s1 and s2) then
        local l = lane_of(nx, ny, dn, -v[1], -v[2])
        for ll = 1, 2 do for it in pairs(lanes[ll]) do add(nx, ny, l, it) end end
      else
        for l = 1, 2 do for it in pairs(lanes[l]) do add(nx, ny, l, it) end end
      end
    end
  end
  local function step_belt(x, y)
    local e = ent_at(x, y)
    local lanes = items[Ch.key(x, y)]
    if not (e and lanes) then return end
    if e.kind == "tapis" or (e.kind == "souterrain" and e.ug == "output") or e.kind == "repartiteur" then
      if e.kind == "repartiteur" then
        -- les deux tuiles : chacune reçoit ce que l'une ou l'autre a reçu, puis sort tout droit
        for _, t in ipairs(tiles(e)) do
          for l = 1, 2 do for it in pairs(lanes[l]) do add(t[1], t[2], l, it) end end
        end
      end
      feed(x, y, e.dir, lanes)
    elseif e.kind == "souterrain" then
      local v = DIRS[e.dir]
      local pair
      for k = 1, maxd do
        local q = ent_at(x + k * v[1], y + k * v[2])
        if q and q.kind == "souterrain" and q.dir == e.dir then
          if q.ug == "output" then pair = { x + k * v[1], y + k * v[2] } end
          break
        end
      end
      if not pair then flag(e) return end
      for l = 1, 2 do for it in pairs(lanes[l]) do add(pair[1], pair[2], l, it) end end
    end
  end
  local function drain()
    local i = 1
    while i <= #queue do
      local q = queue[i]
      i = i + 1
      step_belt(q[1], q[2])
      if i > 400000 then break end
    end
    queue = {}
  end
  -- sources : foreuses (voie lointaine), coffres de combustible (garnis à la pose)
  for _, e in ipairs(plan.ents) do
    if e.kind == "foreuse" then
      local x0, y0 = origin(e)
      local v = DIRS[e.dir]
      local hh = math.floor(e.size / 2)
      local tx, ty = x0 + hh + v[1] * (hh + 1), y0 + hh + v[2] * (hh + 1)
      local b = ent_at(tx, ty)
      if b and b.kind == "tapis" then add(tx, ty, lane_of(tx, ty, b.dir, v[1], v[2]), e.role == "charbon" and "charbon" or "minerai") end
    elseif e.kind == "coffre" and e.role == "combustible" then
      held[e] = { charbon = true }
    end
  end
  for _ = 1, 64 do
    drain()
    local changed = false
    for _, e in ipairs(plan.ents) do
      if e.kind == "bras" then
        local x0, y0 = origin(e)
        local v = DIRS[e.dir]
        local px, py, dx, dy = x0 + v[1], y0 + v[2], x0 - v[1], y0 - v[2]
        local src, dst = ent_at(px, py), ent_at(dx, dy)
        local got = {}
        if src and isbelt[src.kind] then
          local lanes = items[Ch.key(px, py)]
          if lanes then for l = 1, 2 do for it in pairs(lanes[l]) do got[it] = true end end end
        elseif src and src.kind == "four" then
          if held[src] and held[src].plaque then got.plaque = true end
        elseif src and src.kind == "coffre" and held[src] then
          for it in pairs(held[src]) do got[it] = true end
        end
        if dst and isbelt[dst.kind] then
          local l = lane_of(dx, dy, dst.dir, -v[1], -v[2])
          for it in pairs(got) do if add(dx, dy, l, it) then changed = true end end
        elseif dst and (dst.kind == "four" or dst.kind == "coffre") then
          held[dst] = held[dst] or {}
          for it in pairs(got) do
            local ok = dst.kind == "coffre" or it == "minerai" or (it == "charbon" and fuel)
            if ok and not held[dst][it] then held[dst][it] = true; changed = true end
          end
        end
      end
    end
    for _, e in ipairs(plan.ents) do
      if e.kind == "four" and held[e] and held[e].minerai and (held[e].charbon or not fuel) and not held[e].plaque then
        held[e].plaque = true
        changed = true
      end
    end
    if not changed and #queue == 0 then break end
  end
  for _, e in ipairs(plan.ents) do
    if e.kind == "four" then
      local h = held[e] or {}
      if not h.minerai then rep.no_ore = rep.no_ore + 1 end
      if fuel and not h.charbon then rep.no_coal = rep.no_coal + 1 end
    elseif e.kind == "coffre" and e.role == "sortie" and plan.design == "colonne" then
      if not (held[e] and held[e].plaque) then rep.no_plate = rep.no_plate + 1 end
    end
  end
  for k, lanes in pairs(items) do
    for l = 1, 2 do
      local n = 0
      for _, it in ipairs({ "minerai", "charbon", "plaque" }) do if lanes[l][it] then n = n + 1 end end
      if n > 1 then rep.mixed = rep.mixed + 1 end
    end
  end
  return rep
end

-- Lot PERF3 : compression de chemin par moitiés (mêmes racines : un nœud ne quitte jamais l'arbre de sa racine ; sans elle, les chaînes
-- des poteaux d'un grand champ rendaient chaque recherche linéaire)
local function find(parent)
  return function(i)
    while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end
    return i
  end
end

function Cv.verify(plan, spec)
  local rep = { overlaps = 0, blocked = 0, unpowered = 0, components = 0, traverse = 0, inside = 0, drops = 0, arms = 0, starved = 0, melange = 0 }
  local at = {}        -- clé de tuile -> entité
  local R, wire = spec.pole.reach, spec.pole.wire
  local d = spec.drill
  for _, e in ipairs(plan.ents) do
    for _, t in ipairs(tiles(e)) do
      local k = Ch.key(t[1], t[2])
      if at[k] then rep.overlaps = rep.overlaps + 1 end
      at[k] = e
      if spec.blocked and spec.blocked[k] and not (spec.mine and spec.mine[k]) then rep.blocked = rep.blocked + 1 end
    end
  end
  -- couverture
  local ore, n = {}, 0
  for i = 1, #spec.ore - 1, 2 do
    local k = Ch.key(spec.ore[i], spec.ore[i + 1])
    if not ore[k] then ore[k] = true; n = n + 1 end
  end
  local cov, cn = {}, 0
  local foreign = spec.foreign or {}
  -- (lot MELANGE) ligne de charbon du lot FONDERIE : son minerai est le charbon, ses tuiles étrangères sont spec.coal.foreign
  local cfor, cset = spec.coal and spec.coal.foreign or {}, {}
  if spec.coal and spec.coal.tiles then
    for i = 1, #spec.coal.tiles - 1, 2 do cset[Ch.key(spec.coal.tiles[i], spec.coal.tiles[i + 1])] = true end
  end
  for _, e in ipairs(plan.ents) do
    if e.kind == "foreuse" then
      local x0, y0 = origin(e)
      local coal_drill = e.role == "charbon"
      local mixed = false
      for x = x0 - d.reach, x0 + e.size - 1 + d.reach do
        for y = y0 - d.reach, y0 + e.size - 1 + d.reach do
          local k = Ch.key(x, y)
          if coal_drill then
            if cfor[k] and not cset[k] then mixed = true end
          else
            if ore[k] and not cov[k] then cov[k] = true; cn = cn + 1 end
            if foreign[k] and not ore[k] then mixed = true end
          end
        end
      end
      if mixed then rep.melange = rep.melange + 1 end
    end
  end
  rep.tiles, rep.covered, rep.elec = n, cn, n > 0 and cn / n or 0
  -- poteaux : couverture et réseau
  local poles = {}
  local grid = {}
  for _, e in ipairs(plan.ents) do
    if e.kind == "poteau" then
      local x0, y0 = origin(e)
      poles[#poles + 1] = { x = x0, y = y0 }
      local gk = Ch.key(math.floor(x0 / 8), math.floor(y0 / 8))
      grid[gk] = grid[gk] or {}
      grid[gk][#grid[gk] + 1] = #poles
    end
  end
  local function near_pole(tx, ty, r)
    for gx = math.floor((tx - r) / 8), math.floor((tx + r) / 8) do
      for gy = math.floor((ty - r) / 8), math.floor((ty + r) / 8) do
        for _, i in ipairs(grid[Ch.key(gx, gy)] or {}) do
          local p = poles[i]
          if math.abs(p.x - tx) <= r and math.abs(p.y - ty) <= r then return true end
        end
      end
    end
    return false
  end
  for _, e in ipairs(plan.ents) do
    local needs = e.kind == "foreuse" or e.kind == "bras" or (e.kind == "four" and spec.furnace and not spec.furnace.fuel)
    if needs then
      local ok = false
      for _, t in ipairs(tiles(e)) do if near_pole(t[1], t[2], R) then ok = true break end end
      if not ok then rep.unpowered = rep.unpowered + 1 end
    end
  end
  local parent = {}
  for i = 1, #poles do parent[i] = i end
  local root = find(parent)
  local reach = math.ceil(wire)
  for i, p in ipairs(poles) do
    for gx = math.floor((p.x - reach) / 8), math.floor((p.x + reach) / 8) do
      for gy = math.floor((p.y - reach) / 8), math.floor((p.y + reach) / 8) do
        for _, j in ipairs(grid[Ch.key(gx, gy)] or {}) do
          local q = poles[j]
          if j > i and (p.x - q.x) ^ 2 + (p.y - q.y) ^ 2 <= wire * wire + 1e-9 then
            local a, b = root(i), root(j)
            if a ~= b then parent[a] = b end
          end
        end
      end
    end
  end
  local roots = {}
  for i = 1, #poles do local r = root(i); if not roots[r] then roots[r] = true; rep.components = rep.components + 1 end end
  -- tapis : rangée de leur bande, sens du groupe ; fin hors du champ (lot FONDERIE : tapis de la bande et de la colonne seulement ;
  -- tête, voie de charbon, plaques et réseau du charbon sont jugés par les voies, Cv.flow)
  local axis = plan.axis
  local function uv(x, y) if axis == "x" then return x, y end return y, x end
  local last = {}
  for _, e in ipairs(plan.ents) do
    if e.kind == "tapis" and (e.role == nil or e.role == "bande" or e.role == "colonne") then
      local bd = plan.bands[e.band]
      local g = bd and bd.groups[e.group]
      local x0, y0 = origin(e)
      local u, v = uv(x0, y0)
      local du, dv = uv(DIRS[e.dir][1], DIRS[e.dir][2])
      if not (bd and g and v == bd.b and dv == 0 and du == g.side) then rep.traverse = rep.traverse + 1 end
      local key = e.band .. ":" .. e.group
      if not last[key] or (g and ((g.side > 0 and u > last[key].u) or (g.side < 0 and u < last[key].u))) then last[key] = { u = u, g = g } end
    end
  end
  local lkeys = {}
  for k in pairs(last) do lkeys[#lkeys + 1] = k end
  table.sort(lkeys)
  for _, k in ipairs(lkeys) do
    local l = last[k]
    if l.g and l.u >= plan.stats.umin and l.u <= plan.stats.umax then rep.inside = rep.inside + 1 end
  end
  -- sorties des foreuses et bras
  local function ent_at(x, y) return at[Ch.key(x, y)] end
  for _, e in ipairs(plan.ents) do
    if e.kind == "foreuse" then
      local x0, y0 = origin(e)
      local v = DIRS[e.dir]
      local h = math.floor(e.size / 2)
      local tx = x0 + h + v[1] * (h + 1)
      local ty = y0 + h + v[2] * (h + 1)
      local t = ent_at(tx, ty)
      local good
      if e.role == "charbon" then good = t and t.kind == "tapis" and t.role == "charbon"
      else good = t and t.kind == "tapis" and t.band == e.band and t.group == e.group end
      if not good then rep.drops = rep.drops + 1 end
    elseif e.kind == "bras" then
      local x0, y0 = origin(e)
      local v = DIRS[e.dir]
      local pick, drop = ent_at(x0 + v[1], y0 + v[2]), ent_at(x0 - v[1], y0 - v[2])
      local belt = { tapis = true, souterrain = true, repartiteur = true }
      local good = pick and drop and (
        (pick.kind == "tapis" and (drop.kind == "four" or drop.kind == "coffre")) or
        (pick.kind == "four" and drop.kind == "coffre" and drop.role == "sortie") or
        (pick.kind == "coffre" and pick.role == "combustible" and drop.kind == "four") or
        -- lot FONDERIE : four -> tapis de plaques, coffre de tête -> voie de charbon, tronc -> voie de charbon
        (pick.kind == "four" and drop.kind == "tapis" and drop.role == "sortie") or
        (pick.kind == "coffre" and pick.role == "combustible" and drop.kind == "tapis" and drop.role == "charbon") or
        (belt[pick.kind] and pick.role == "charbon" and drop.kind == "tapis" and drop.role == "charbon"))
      if not good then rep.arms = rep.arms + 1 end
    end
  end
  -- débits : capacité RECOMPTÉE sur les entités (fours du groupe, ou bras qui posent dans un coffre), voie du tapis par côté
  local count, per = {}, {}
  for _, e in ipairs(plan.ents) do
    local k = (e.band or 0) .. ":" .. (e.group or 0)
    if e.kind == "four" then count[k] = (count[k] or 0) + 1
    elseif e.kind == "bras" and not spec.furnace then
      local x0, y0 = origin(e)
      local v = DIRS[e.dir]
      local pick = ent_at(x0 + v[1], y0 + v[2])
      if pick and pick.kind == "tapis" then count[k] = (count[k] or 0) + 1 end
    elseif e.kind == "foreuse" then
      per[k] = per[k] or { [0] = 0, [2] = 0, [4] = 0, [6] = 0 }
      per[k][e.dir] = per[k][e.dir] + 1
    end
  end
  for bi, bd in ipairs(plan.bands) do
    for gi, g in ipairs(bd.groups) do
      local k = bi .. ":" .. gi
      local p = per[k] or { [0] = 0, [2] = 0, [4] = 0, [6] = 0 }
      local rate = spec.furnace and spec.furnace.rate or ((spec.inserter and spec.inserter.rate) or 1)
      local bt = spec.belts[g.belt]
      -- F555 : les fours absorbent ce que le tapis LIVRE (voie relue ici, pas par Ch.delivered : le contrôle ne partage pas la règle qu'il
      -- juge) ; des foreuses au-delà du débit du tapis le plus rapide ne sont pas un défaut de la fonderie. Lot FONDERIE : colonne à
      -- combustible, tout le minerai du groupe sur UNE voie après la tête ; sinon une voie par sens de sortie des foreuses
      local flow = 0
      if bt then
        if plan.design == "colonne" and spec.furnace and spec.furnace.fuel then
          flow = math.min((p[0] + p[2] + p[4] + p[6]) * d.rate, bt.lane)
        else
          for _, dd in ipairs({ 0, 2, 4, 6 }) do flow = flow + math.min(p[dd] * d.rate, bt.lane) end
        end
      end
      -- un tapis plus lent que le plus rapide doit porter tout le groupe
      if not bt or (g.belt ~= #spec.belts and flow + 1e-9 < (p[0] + p[2] + p[4] + p[6]) * d.rate) then rep.starved = rep.starved + 1 end
      if (count[k] or 0) * rate + 1e-9 < flow then rep.starved = rep.starved + 1 end
    end
  end
  local fl = Cv.flow(plan, spec)
  rep.no_ore, rep.no_coal, rep.no_plate, rep.mixed, rep.junction = fl.no_ore, fl.no_coal, fl.no_plate, fl.mixed, fl.junction
  rep.ok = rep.overlaps == 0 and rep.blocked == 0 and rep.unpowered == 0 and rep.components <= 1 and rep.traverse == 0
    and rep.inside == 0 and rep.drops == 0 and rep.arms == 0 and rep.starved == 0
    and fl.no_ore == 0 and fl.no_coal == 0 and fl.no_plate == 0 and fl.mixed == 0 and fl.junction == 0 and rep.melange == 0
  return rep
end

function Cv.line(rep)
  return string.format("couverture %d/%d (%d%%), chevauchements %d, obstacles %d, sans courant %d, reseaux %d, tapis hors bande %d, tapis finis dans le champ %d, sorties ratees %d, bras faux %d, debits courts %d, fours sans minerai %d, sans charbon %d, quais sans plaque %d, voies melees %d, raccords faux %d, zones melangees %d",
    rep.covered, rep.tiles, math.floor(100 * rep.elec + 0.5), rep.overlaps, rep.blocked, rep.unpowered, rep.components, rep.traverse,
    rep.inside, rep.drops, rep.arms, rep.starved, rep.no_ore or 0, rep.no_coal or 0, rep.no_plate or 0, rep.mixed or 0, rep.junction or 0,
    rep.melange or 0)
end

return Cv
