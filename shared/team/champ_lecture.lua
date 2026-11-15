--[[
  C5-PERF (chantier 5 du DC : pics > 15 ms par tick, partie 0.9.4 : étapes « ore » et « charbon » de la lecture de la spec d'un cadre
  jusqu'à 24 et 33 ms d'un bloc sur la carte à 600 %) : les deux traitements qui suivent la lecture du moteur, faits d'un bloc sur des
  dizaines de milliers de tuiles, deviennent REPRENABLES au budget (un compte d'éléments traités, jamais un temps) :
    - Lu.component_*  = Paires.nearest_component (composante du gisement du centre, triée : distance, x, y) ;
    - Lu.coal_*       = coal_from de script/team/champ.lua (fenêtres de charbon autour des tuiles les plus proches, liste triée et boîte).
  Mêmes calculs, dans le même ordre, mêmes résultats (tests/c5_perf_test.lua compare aux versions d'un bloc). Les tris passent par un tri
  fusion reprenable (Lu.msort_*) : les comparateurs sont des ordres TOTAUX stricts (une ressource par tuile), le résultat d'un tri est donc
  unique, quel que soit l'algorithme. Lua pur, aucune fonction gardée dans l'état entre deux pas que l'appelant ne puisse refaire.
]]
local Lu = {}

---------------------------------------------------------------------------------------------------
-- Tri fusion reprenable (en place sur `a`, ordre strict `less`) : passes de largeur 1, 2, 4... ; S = { a, less, n, w, i, k, l, r, src, dst }
---------------------------------------------------------------------------------------------------
function Lu.msort_begin(a, less)
  return { a = a, less = less, n = #a, w = 1, src = a, dst = {}, i = 1 }
end
--- Fait au plus `W` déplacements d'éléments ; rend vrai quand `S.a` est trié (copié dans `a` à la fin si besoin).
function Lu.msort_step(S, W)
  local n, less = S.n, S.less
  local done = 0
  while S.w < n do
    local w, src, dst = S.w, S.src, S.dst
    while S.i <= n do
      local i = S.i
      local mid, hi = math.min(i + w, n + 1), math.min(i + 2 * w, n + 1)
      local k, l, r = S.k or i, S.l or i, S.r or mid
      while k < hi do
        if done >= W then S.k, S.l, S.r = k, l, r return false end
        if l < mid and (r >= hi or not less(src[r], src[l])) then dst[k] = src[l]; l = l + 1 else dst[k] = src[r]; r = r + 1 end
        k = k + 1
        done = done + 1
      end
      S.k, S.l, S.r = nil, nil, nil
      S.i = hi
    end
    S.src, S.dst = dst, src
    S.w, S.i = 2 * w, 1
  end
  if S.src ~= S.a then
    local a, src = S.a, S.src
    for j = S.cj or 1, n do
      if done >= W then S.cj = j return false end
      a[j] = src[j]
      done = done + 1
    end
    S.src = a
  end
  return true
end

---------------------------------------------------------------------------------------------------
-- Composante du gisement du centre (= Paires.nearest_component, voir shared/team/pose_paires.lua)
---------------------------------------------------------------------------------------------------
function Lu.component_begin(resources, gap, center, seed_max)
  return { res = resources, n = #resources, reach = gap + 1, cx = center.x, cy = center.y, seed_max = seed_max, ph = "seed", i = 1 }
end
local function find(a)
  while a.parent ~= a do
    a.parent = a.parent.parent
    a = a.parent
  end
  return a
end
--- Au plus ~W éléments traités ; rend (fini, composante { {x, y} } triée).
function Lu.component_step(J, W)
  local res, n, reach, cx, cy = J.res, J.n, J.reach, J.cx, J.cy
  local floor = math.floor
  local done = 0
  if n == 0 then return true, {} end
  if J.ph == "seed" then
    local seed, sd = J.seed, J.sd
    local i = J.i
    while i <= n and done < W do
      local r = res[i]
      local d = (r.x - cx) ^ 2 + (r.y - cy) ^ 2
      if not seed or d < sd or (d == sd and (r.x < seed.x or (r.x == seed.x and r.y < seed.y))) then seed, sd = r, d end
      i = i + 1
      done = done + 1
    end
    J.seed, J.sd, J.i = seed, sd, i
    if i <= n then return false end
    if (seed.x - cx) ^ 2 + (seed.y - cy) ^ 2 > J.seed_max * J.seed_max then return true, {} end
    J.ph, J.i, J.rows, J.ys = "rows", 1, {}, {}
  end
  if J.ph == "rows" then
    local rows, ys = J.rows, J.ys
    local i = J.i
    while i <= n and done < W do
      local r = res[i]
      local y = floor(r.y)
      local row = rows[y]
      if not row then row = {}; rows[y] = row; ys[#ys + 1] = y end
      row[#row + 1] = floor(r.x)
      i = i + 1
      done = done + 1
    end
    J.i = i
    if i <= n then return false end
    table.sort(ys) -- (une clé par rangée : quelques centaines au plus)
    J.ph, J.yi, J.runs_of, J.all = "runs", 1, {}, {}
  end
  if J.ph == "runs" then
    local rows, ys, runs_of, all = J.rows, J.ys, J.runs_of, J.all
    while J.yi <= #ys do
      if done >= W then return false end
      local y = ys[J.yi]
      local row = rows[y]
      table.sort(row)
      local list = {}
      local lo, prev = row[1], row[1]
      for j = 2, #row do
        local x = row[j]
        if x - prev > reach then
          local run = { lo = lo, hi = prev }
          run.parent = run
          list[#list + 1] = run
          all[#all + 1] = run
          lo = x
        end
        prev = x
      end
      local run = { lo = lo, hi = prev }
      run.parent = run
      list[#list + 1] = run
      all[#all + 1] = run
      runs_of[y] = list
      done = done + 2 * #row
      J.yi = J.yi + 1
    end
    J.ph, J.yi = "union", 1
  end
  if J.ph == "union" then
    local ys, runs_of = J.ys, J.runs_of
    while J.yi <= #ys do
      if done >= W then return false end
      local y = ys[J.yi]
      local a = runs_of[y]
      for dy = 1, reach do
        local b = runs_of[y + dy]
        if b then
          local i, j = 1, 1
          while i <= #a and j <= #b do
            local ra, rb = a[i], b[j]
            if ra.lo - reach <= rb.hi and rb.lo - reach <= ra.hi then
              local pa, pb = find(ra), find(rb)
              if pa ~= pb then pb.parent = pa end
            end
            if ra.hi <= rb.hi then i = i + 1 else j = j + 1 end
            done = done + 1
          end
        end
      end
      done = done + 1
      J.yi = J.yi + 1
    end
    local sx, sy = floor(J.seed.x), floor(J.seed.y)
    for _, run in ipairs(runs_of[sy]) do
      if sx >= run.lo and sx <= run.hi then J.root = find(run) break end
    end
    J.ph, J.i, J.m, J.xs, J.ysr, J.ds, J.order = "collect", 1, 0, {}, {}, {}, {}
  end
  if J.ph == "collect" then
    local runs_of, root, xs_, ys_, ds, order = J.runs_of, J.root, J.xs, J.ysr, J.ds, J.order
    local m, i = J.m, J.i
    while i <= n and done < W do
      local r = res[i]
      local list = runs_of[floor(r.y)]
      local x = floor(r.x)
      for j = 1, #list do
        local run = list[j]
        if x >= run.lo and x <= run.hi then
          if find(run) == root then
            m = m + 1
            xs_[m], ys_[m] = r.x, r.y
            ds[m] = (r.x - cx) ^ 2 + (r.y - cy) ^ 2
            order[m] = m
          end
          break
        end
      end
      i = i + 1
      done = done + 2
    end
    J.m, J.i = m, i
    if i <= n then return false end
    J.rows, J.runs_of, J.all = nil, nil, nil
    J.ph = "sort"
    J.S = Lu.msort_begin(order, function(a, b)
      local da, db = ds[a], ds[b]
      if da ~= db then return da < db end
      local xa, xb = xs_[a], xs_[b]
      if xa ~= xb then return xa < xb end
      return ys_[a] < ys_[b]
    end)
  end
  if J.ph == "sort" then
    if not Lu.msort_step(J.S, math.max(1, W - done)) then return false end
    done = W
    J.S = nil
    J.ph, J.k, J.out = "out", 1, {}
    return false
  end
  local xs_, ys_, order, out = J.xs, J.ysr, J.order, J.out
  local k = J.k
  while k <= J.m and done < W do
    out[k] = { x = xs_[order[k]], y = ys_[order[k]] }
    k = k + 1
    done = done + 1
  end
  J.k = k
  if k <= J.m then return false end
  return true, out
end

---------------------------------------------------------------------------------------------------
-- Fenêtres de charbon (= coal_from de script/team/champ.lua, d'un bloc : Lu.coal_from, gardé comme référence des tests)
---------------------------------------------------------------------------------------------------
--- pts = { {x, y} } (lecture du moteur), pos = centre, W = demi-côté de fenêtre ; rend (liste plate triée, boîte) ou nil.
function Lu.coal_from(pts, pos, W)
  if #pts == 0 then return nil end
  local function dd(c) return (c.x - pos.x) ^ 2 + (c.y - pos.y) ^ 2 end
  local function less(a, b)
    local da, db = dd(a), dd(b)
    if da ~= db then return da < db end
    if a.x ~= b.x then return a.x < b.x end
    return a.y < b.y
  end
  local centers = {}
  for _ = 1, 3 do
    local best
    for _, c in ipairs(pts) do
      local inside = false
      for _, k in ipairs(centers) do if math.abs(c.x - k.x) <= W and math.abs(c.y - k.y) <= W then inside = true break end end
      if not inside and (not best or less(c, best)) then best = c end
    end
    if not best then break end
    centers[#centers + 1] = best
  end
  local list = {}
  for _, c in ipairs(pts) do
    local keep = false
    for _, k in ipairs(centers) do if math.abs(c.x - k.x) <= W and math.abs(c.y - k.y) <= W then keep = true break end end
    if keep then list[#list + 1] = { math.floor(c.x), math.floor(c.y) } end
  end
  table.sort(list, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
  local flat = {}
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, t in ipairs(list) do
    flat[#flat + 1] = t[1]; flat[#flat + 1] = t[2]
    x0, y0, x1, y1 = math.min(x0, t[1]), math.min(y0, t[2]), math.max(x1, t[1]), math.max(y1, t[2])
  end
  return flat, { x0, y0, x1, y1 }
end

function Lu.coal_begin(pts, pos, W)
  return { pts = pts, px = pos.x, py = pos.y, W = W, ph = "centers", centers = {}, i = 1 }
end
local function xy_less(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end
--- Au plus ~W éléments traités ; rend (fini, liste plate, boîte) ; (true, nil) sans charbon.
function Lu.coal_step(J, Wk)
  local pts, px, py, W = J.pts, J.px, J.py, J.W
  local n = #pts
  if n == 0 then return true, nil end
  local abs = math.abs
  local done = 0
  local centers = J.centers
  if J.ph == "centers" then
    -- passe k (#centers + 1) : la plus petite tuile selon (distance, x, y) hors des fenêtres déjà prises
    while true do
      local best, bd = J.best, J.bd
      local i = J.i
      local nc = #centers
      while i <= n and done < Wk do
        local c = pts[i]
        local inside = false
        for q = 1, nc do local k = centers[q]; if abs(c.x - k.x) <= W and abs(c.y - k.y) <= W then inside = true break end end
        if not inside then
          local d = (c.x - px) ^ 2 + (c.y - py) ^ 2
          if not best or d < bd or (d == bd and (c.x < best.x or (c.x == best.x and c.y < best.y))) then best, bd = c, d end
        end
        i = i + 1
        done = done + 1 + nc
      end
      if i <= n then J.best, J.bd, J.i = best, bd, i return false end
      J.best, J.bd, J.i = nil, nil, 1
      if best then centers[#centers + 1] = best end
      if not best or #centers >= 3 then J.ph, J.list = "keep", {} break end
      if done >= Wk then return false end
    end
  end
  if J.ph == "keep" then
    local list, i, nc = J.list, J.i, #centers
    local floor = math.floor
    while i <= n and done < Wk do
      local c = pts[i]
      for q = 1, nc do
        local k = centers[q]
        if abs(c.x - k.x) <= W and abs(c.y - k.y) <= W then list[#list + 1] = { floor(c.x), floor(c.y) } break end
      end
      i = i + 1
      done = done + 1 + nc
    end
    J.i = i
    if i <= n then return false end
    J.ph, J.S = "sort", Lu.msort_begin(list, xy_less)
  end
  if J.ph == "sort" then
    if not Lu.msort_step(J.S, math.max(1, Wk - done)) then return false end
    J.S = nil
    J.ph, J.i, J.flat, J.box = "flat", 1, {}, { math.huge, math.huge, -math.huge, -math.huge }
    return false
  end
  local list, flat, b = J.list, J.flat, J.box
  local i = J.i
  while i <= #list and done < Wk do
    local t = list[i]
    flat[#flat + 1] = t[1]; flat[#flat + 1] = t[2]
    b[1], b[2], b[3], b[4] = math.min(b[1], t[1]), math.min(b[2], t[2]), math.max(b[3], t[1]), math.max(b[4], t[2])
    i = i + 1
    done = done + 1
  end
  J.i = i
  if i <= #list then return false end
  return true, flat, b
end

return Lu
