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
    ok                      aucun des défauts ci-dessus
]]

local Ch = require("shared.team.champ")

local Cv = {}

local DIRS = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }

local function origin(e)
  return math.floor(e.x - e.size / 2 + 0.5), math.floor(e.y - e.size / 2 + 0.5)
end

local function tiles(e)
  local x0, y0 = origin(e)
  local out = {}
  for x = x0, x0 + e.size - 1 do for y = y0, y0 + e.size - 1 do out[#out + 1] = { x, y } end end
  return out
end

local function find(parent) return function(i) while parent[i] ~= i do i = parent[i] end; return i end end

function Cv.verify(plan, spec)
  local rep = { overlaps = 0, blocked = 0, unpowered = 0, components = 0, traverse = 0, inside = 0, drops = 0, arms = 0, starved = 0 }
  local at = {}        -- clé de tuile -> entité
  local R, wire = spec.pole.reach, spec.pole.wire
  local d = spec.drill
  for _, e in ipairs(plan.ents) do
    for _, t in ipairs(tiles(e)) do
      local k = Ch.key(t[1], t[2])
      if at[k] then rep.overlaps = rep.overlaps + 1 end
      at[k] = e
      if spec.blocked and spec.blocked[k] then rep.blocked = rep.blocked + 1 end
    end
  end
  -- couverture
  local ore, n = {}, 0
  for i = 1, #spec.ore - 1, 2 do
    local k = Ch.key(spec.ore[i], spec.ore[i + 1])
    if not ore[k] then ore[k] = true; n = n + 1 end
  end
  local cov, cn = {}, 0
  for _, e in ipairs(plan.ents) do
    if e.kind == "foreuse" then
      local x0, y0 = origin(e)
      for x = x0 - d.reach, x0 + e.size - 1 + d.reach do
        for y = y0 - d.reach, y0 + e.size - 1 + d.reach do
          local k = Ch.key(x, y)
          if ore[k] and not cov[k] then cov[k] = true; cn = cn + 1 end
        end
      end
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
  -- tapis : rangée de leur bande, sens du groupe ; fin hors du champ
  local axis = plan.axis
  local function uv(x, y) if axis == "x" then return x, y end return y, x end
  local last = {}
  for _, e in ipairs(plan.ents) do
    if e.kind == "tapis" then
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
      if not (t and t.kind == "tapis" and t.band == e.band and t.group == e.group) then rep.drops = rep.drops + 1 end
    elseif e.kind == "bras" then
      local x0, y0 = origin(e)
      local v = DIRS[e.dir]
      local pick, drop = ent_at(x0 + v[1], y0 + v[2]), ent_at(x0 - v[1], y0 - v[2])
      local good = pick and drop and (
        (pick.kind == "tapis" and (drop.kind == "four" or drop.kind == "coffre")) or
        (pick.kind == "four" and drop.kind == "coffre" and drop.role == "sortie") or
        (pick.kind == "coffre" and pick.role == "combustible" and drop.kind == "four"))
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
      local side_max = math.max(p[0], p[2], p[4], p[6])
      local flow = (p[0] + p[2] + p[4] + p[6]) * d.rate
      local rate = spec.furnace and spec.furnace.rate or ((spec.inserter and spec.inserter.rate) or 1)
      local bt = spec.belts[g.belt]
      if (count[k] or 0) * rate + 1e-9 < flow then rep.starved = rep.starved + 1 end
      -- (voie relue ici, pas par Ch.lane_drills : le contrôle ne partage pas la règle qu'il juge)
      if not bt or math.floor(bt.lane / d.rate + 1e-9) < side_max then rep.starved = rep.starved + 1 end
    end
  end
  rep.ok = rep.overlaps == 0 and rep.blocked == 0 and rep.unpowered == 0 and rep.components <= 1 and rep.traverse == 0
    and rep.inside == 0 and rep.drops == 0 and rep.arms == 0 and rep.starved == 0
  return rep
end

function Cv.line(rep)
  return string.format("couverture %d/%d (%d%%), chevauchements %d, obstacles %d, sans courant %d, reseaux %d, tapis hors bande %d, tapis finis dans le champ %d, sorties ratees %d, bras faux %d, debits courts %d",
    rep.covered, rep.tiles, math.floor(100 * rep.elec + 0.5), rep.overlaps, rep.blocked, rep.unpowered, rep.components, rep.traverse,
    rep.inside, rep.drops, rep.arms, rep.starved)
end

return Cv
