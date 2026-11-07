--[[
  Relais entre réseaux de poteaux TELS QU'AU COMMIT 067a1bd3 (shared/team/champ.lua, bridge_0641 et bridge), recopiés à l'identique : la
  référence du contrôle « machine reprenable = passes d'avant » de tests/champ_tranches_test.lua (les réseaux y sont refaits de zéro à
  chaque passe). Ne pas modifier : c'est une référence figée.
  Usage : local R = dofile("tests/fixtures/champ_bridge_ref.lua")(Ch) ; R.bridge_0641(c, spec, poles), R.bridge(c, spec, poles).
]]
return function(Ch)
local function bridge_0641(c, spec, poles)
  local wire = spec.pole.wire
  local w2 = wire * wire + Ch.CFG.eps
  local added = {}
  for _ = 1, 60 do
    local parent = {}
    for i = 1, #poles do parent[i] = i end
    local function root(i) while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end return i end
    local grid = {}
    local cell = math.max(1, math.ceil(wire))
    for i, p in ipairs(poles) do
      local k = Ch.key(math.floor(p[1] / cell), math.floor(p[2] / cell))
      grid[k] = grid[k] or {}
      grid[k][#grid[k] + 1] = i
    end
    for i, p in ipairs(poles) do
      local gx, gy = math.floor(p[1] / cell), math.floor(p[2] / cell)
      for dx = -1, 1 do
        for dy = -1, 1 do
          for _, j in ipairs(grid[Ch.key(gx + dx, gy + dy)] or {}) do
            local q = poles[j]
            if j > i and (p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 <= w2 then
              local a, b = root(i), root(j)
              if a ~= b then parent[a] = b end
            end
          end
        end
      end
    end
    -- Lot PERF3 : racine de chaque poteau calculée UNE fois (avant : root() dans la double boucle, N² appels), puis les mêmes paires
    -- dans le même ordre (i puis j croissants) : même paire retenue, à égalité comprise.
    local main = root(1)
    local ins, outs = {}, {}
    for i = 1, #poles do if root(i) == main then ins[#ins + 1] = i else outs[#outs + 1] = i end end
    local best, ba, bb
    for _, i in ipairs(ins) do
      local p = poles[i]
      local p1, p2 = p[1], p[2]
      for _, j in ipairs(outs) do
        local q = poles[j]
        local d2 = (p1 - q[1]) ^ 2 + (p2 - q[2]) ^ 2
        if not best or d2 < best then best, ba, bb = d2, i, j end
      end
    end
    if not best then return added end
    local a, b = poles[ba], poles[bb]
    local dist = math.sqrt(best)
    local n = math.ceil(dist / (wire - 0.5)) - 1
    local prev = a
    local ok = n >= 1
    for k = 1, n do
      local iu = math.floor(a[1] + (b[1] - a[1]) * k / (n + 1) + 0.5)
      local iv = math.floor(a[2] + (b[2] - a[2]) * k / (n + 1) + 0.5)
      local put
      for r = 0, 3 do
        for du = -r, r do
          for dv = -r, r do
            local u, v = iu + du, iv + dv
            if not put and math.max(math.abs(du), math.abs(dv)) == r and c.free(u, v)
              and (u - prev[1]) ^ 2 + (v - prev[2]) ^ 2 <= w2 then put = { u, v } end
          end
        end
      end
      if not put then ok = false break end
      c.take(put[1], put[2])
      poles[#poles + 1] = put
      added[#added + 1] = put
      prev = put
    end
    if not ok then return added end
  end
  return added
end

-- (lot FONDERIE) relais à plusieurs paires (Ch.BRIDGE_TRIES) pour la colonne à tapis ; le motif à coffres garde bridge_0641, à l'identique
local function bridge(c, spec, poles)
  local wire = spec.pole.wire
  local w2 = wire * wire + Ch.CFG.eps
  local added = {}
  for _ = 1, 60 do
    local parent = {}
    for i = 1, #poles do parent[i] = i end
    local function root(i) while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end return i end
    local grid = {}
    local cell = math.max(1, math.ceil(wire))
    for i, p in ipairs(poles) do
      local k = Ch.key(math.floor(p[1] / cell), math.floor(p[2] / cell))
      grid[k] = grid[k] or {}
      grid[k][#grid[k] + 1] = i
    end
    for i, p in ipairs(poles) do
      local gx, gy = math.floor(p[1] / cell), math.floor(p[2] / cell)
      for dx = -1, 1 do
        for dy = -1, 1 do
          for _, j in ipairs(grid[Ch.key(gx + dx, gy + dy)] or {}) do
            local q = poles[j]
            if j > i and (p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 <= w2 then
              local a, b = root(i), root(j)
              if a ~= b then parent[a] = b end
            end
          end
        end
      end
    end
    local main = root(1)
    -- (lot FONDERIE) les Ch.BRIDGE_TRIES paires (réseau principal, autre réseau) les plus proches, essayées dans l'ordre : avant, seule la plus
    -- proche l'était, et un échec arrêtait tout (deux rangées de poteaux d'une ligne de charbon à 8 tuiles : leur milieu est sur le tapis et
    -- les foreuses, aucun relais possible là, mais au bout de la ligne oui)
    -- Lot PERF3 : racines calculées une fois, mêmes paires dans le même ordre (voir bridge_0641)
    local ins, outs = {}, {}
    for i = 1, #poles do if root(i) == main then ins[#ins + 1] = i else outs[#outs + 1] = i end end
    local cand = {}
    local tries = Ch.BRIDGE_TRIES
    for _, i in ipairs(ins) do
      local p = poles[i]
      local p1, p2 = p[1], p[2]
      for _, j in ipairs(outs) do
        local q = poles[j]
        local d2 = (p1 - q[1]) ^ 2 + (p2 - q[2]) ^ 2
        if #cand < tries or d2 < cand[#cand][1] then
          local pos = #cand + 1
          while pos > 1 and cand[pos - 1][1] > d2 do pos = pos - 1 end
          table.insert(cand, pos, { d2, i, j })
          if #cand > tries then cand[#cand] = nil end
        end
      end
    end
    if #cand == 0 then return added end
    local done = false
    for _, cd in ipairs(cand) do
      if not done then
        local a, b = poles[cd[2]], poles[cd[3]]
        local n = math.ceil(math.sqrt(cd[1]) / (wire - 0.5)) - 1
        local prev, ok, chain, tmp = a, n >= 1, {}, {}
        for k = 1, n do
          if ok then
            local iu = math.floor(a[1] + (b[1] - a[1]) * k / (n + 1) + 0.5)
            local iv = math.floor(a[2] + (b[2] - a[2]) * k / (n + 1) + 0.5)
            local put
            for r = 0, 3 do
              for du = -r, r do
                for dv = -r, r do
                  local u, v = iu + du, iv + dv
                  if not put and math.max(math.abs(du), math.abs(dv)) == r and c.free(u, v) and not tmp[Ch.key(u, v)]
                    and (u - prev[1]) ^ 2 + (v - prev[2]) ^ 2 <= w2 then put = { u, v } end
                end
              end
            end
            if not put then ok = false else chain[#chain + 1] = put; tmp[Ch.key(put[1], put[2])] = true; prev = put end
          end
        end
        if ok and (prev[1] - b[1]) ^ 2 + (prev[2] - b[2]) ^ 2 <= w2 then
          for _, put in ipairs(chain) do
            c.take(put[1], put[2])
            poles[#poles + 1] = put
            added[#added + 1] = put
          end
          done = true
        end
      end
    end
    if not done then return added end
  end
  return added
end

return { bridge_0641 = bridge_0641, bridge = bridge }
end
