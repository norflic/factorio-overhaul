--[[
  Lot X10-GEL : la COMPTABILITÉ d'un îlot figé (fo-logs/2026-11-07_X10/L1_CRITERES.md §3.3). RÈGLE PURE (aucune API Factorio ;
  tests/gel_compta_test.lua, avec mutants et compte d'instructions).

  Un îlot est un graphe sans cycle de MACHINES (foreuses, fours, assembleurs) reliées par des BUS virtuels (un tapis, ou le dépôt direct
  d'une foreuse dans un four), qui n'échange avec le monde que par des RÉSERVES réelles (coffres, inventaires propres d'une machine
  qu'aucun lien ne sert : source et sortie d'un four rempli et vidé à la main, combustible rechargé par un PNJ), des GISEMENTS et le
  courant. Un pas de `dt` ticks applique aux réserves et aux gisements le flux que l'îlot aurait eu en marche, borné par ce qui est
  disponible : jamais un produit sans ses ingrédients, jamais un dépôt sans place. L'état interne des machines (progression, tapis,
  mains des bras) n'est pas dans le modèle : le runtime n'y touche jamais (F83, F84).

  Description (préparée par le runtime, gardée dans `global` ; machines triées par id ; Gc.prepare y ajoute des tables dérivées) :
    il = { machines = { m, ... }, fv = { [combustible] = J } }
    m  = { id, kind = "drill" | "craft", rate = cycles par tick à pleine vitesse (vitesse et modules compris),
           ing = { {objet, quantité}, ... } (craft), out = { {objet, quantité}, ... } (produits d'un cycle ; foreuse : produits d'une
           unité minée), prod = bonus de productivité, energy = "burner" | "electric", power = énergie UTILE à pleine vitesse (J/tick),
           drain = J/tick (électrique), eff = rendement du brûleur, emis = pollution par joule utile, fuel = id de sa réserve de
           combustible, res = { id de réserves de gisement } (foreuse), src = { ref }, dst = { ref } }   ref = { k = "pool"|"bus", id }
  Frontière (relue par le runtime à chaque pas) :
    fr = { pools = { [id] = { items = { [objet] = n }, space = { [objet] = n }, amount = n (gisement) } },
           fuel = { [id] = { items = { [combustible] = n }, rem = J } }, sat = satisfaction électrique (0 à 1) }
  État gardé par îlot : st = { frac = { [id] = x }, pfrac = { [id] = { [objet] = x } }, carry = { [bus] = { [objet] = n } } }.

  Algorithme :
    - ordre topologique des machines (Kahn, file triée) ;
    - passe ARRIÈRE (contre-pression) : D = cycles au plus de chaque machine (temps, courant, gisement, combustible propre, ingrédients
      de réserves, place en aval) ; un preneur de bus n'y expose que des cycles ENTIERS, partagés entre les producteurs du bus dans
      l'ordre inverse ;
    - passe AVANT : chaque machine prend ses ingrédients en amont (bus, puis réserves), brûle son combustible, dépose ses produits
      (bus au besoin, réserves à la place, puis reste au bus) ;
    - un RESTE dans un bus (un preneur a fait moins que prévu : deux ingrédients de bus, combustible absent) : ses preneurs sont
      plafonnés à ce qu'ils ont fait et les deux passes sont refaites (au plus Gc.PASSES fois) ; un reste final est REPORTÉ au pas
      suivant, au-delà de Gc.CARRY_MAX par objet il est compté « excès » (jamais perdu en silence) ;
    - fractions de cycle gardées quand le TEMPS borne la machine ; fraction de produit (productivité, place) gardée toujours.
  Déterminisme : listes dans l'ordre donné ; noms triés ; une copie de table par `next` n'a pas d'effet d'ordre (copie seulement) ;
  aucun hasard (espérance des produits).
]]

local Gc = {}

Gc.EPS = 1e-9
Gc.PASSES = 3
Gc.CARRY_MAX = 50

local floor, min, max, huge = math.floor, math.min, math.max, math.huge

local function sorted_names(t)
  local out = {}
  for k in pairs(t or {}) do out[#out + 1] = k end
  table.sort(out)
  return out
end
Gc.sorted_names = sorted_names

-- Copie d'une table de comptes (l'ordre de parcours n'a aucun effet sur le résultat).
local function copy(t)
  local o = {}
  if t then for k, v in next, t do o[k] = v end end
  return o
end

local function amount_of(list, name)
  for i = 1, #list do if list[i][1] == name then return list[i][2] end end
  return 0
end

--- Ordre topologique (Kahn, file triée par rang dans il.machines) ; nil et la raison si un cycle existe.
function Gc.order(il)
  local ms = il.machines
  local prod_of, deg = {}, {}
  for i, m in ipairs(ms) do
    deg[i] = 0
    for _, r in ipairs(m.dst or {}) do
      if r.k == "bus" then
        prod_of[r.id] = prod_of[r.id] or {}
        prod_of[r.id][#prod_of[r.id] + 1] = i
      end
    end
  end
  local succ = {}
  for j, m in ipairs(ms) do
    for _, r in ipairs(m.src or {}) do
      if r.k == "bus" then
        for _, i in ipairs(prod_of[r.id] or {}) do
          succ[i] = succ[i] or {}
          succ[i][#succ[i] + 1] = j
          deg[j] = deg[j] + 1
        end
      end
    end
  end
  local ready, out = {}, {}
  for i = 1, #ms do if deg[i] == 0 then ready[#ready + 1] = i end end
  while #ready > 0 do
    table.sort(ready)
    local i = table.remove(ready, 1)
    out[#out + 1] = i
    for _, j in ipairs(succ[i] or {}) do
      deg[j] = deg[j] - 1
      if deg[j] == 0 then ready[#ready + 1] = j end
    end
  end
  if #out ~= #ms then return nil, "cycle" end
  return out
end

--- Contrôle de forme : rend (vrai) ou (faux, raison).
function Gc.check(il)
  if type(il) ~= "table" or type(il.machines) ~= "table" or #il.machines == 0 then return false, "vide" end
  local prod_bus, cons_bus = {}, {}
  for _, m in ipairs(il.machines) do
    if m.kind ~= "drill" and m.kind ~= "craft" then return false, "machine inconnue" end
    if type(m.rate) ~= "number" or m.rate <= 0 then return false, "vitesse" end
    if m.energy ~= "burner" and m.energy ~= "electric" then return false, "energie" end
    if m.energy == "burner" and (m.fuel == nil or type(m.eff) ~= "number" or m.eff <= 0) then return false, "combustible" end
    if m.kind == "drill" and (type(m.res) ~= "table" or #m.res == 0) then return false, "gisement" end
    if m.kind == "craft" and (type(m.ing) ~= "table" or #m.ing == 0) then return false, "recette" end
    if type(m.out) ~= "table" or #m.out == 0 then return false, "produits" end
    for _, r in ipairs(m.dst or {}) do if r.k == "bus" then prod_bus[r.id] = true end end
    for _, r in ipairs(m.src or {}) do if r.k == "bus" then cons_bus[r.id] = true end end
  end
  for _, b in ipairs(sorted_names(prod_bus)) do if not cons_bus[b] then return false, "bus sans preneur" end end
  for _, b in ipairs(sorted_names(cons_bus)) do if not prod_bus[b] then return false, "bus sans source" end end
  local order, why = Gc.order(il)
  if not order then return false, why end
  return true
end

--- Tables dérivées, calculées une fois (gardées dans il) : ordre, preneurs de chaque bus, bus d'entrée, noms des combustibles,
--- bus et réserves cités. Rend il, ou nil et la raison.
function Gc.prepare(il)
  local order, why = Gc.order(il)
  if not order then return nil, why end
  local cons, buses, pools, seenp = {}, {}, {}, {}
  for i, m in ipairs(il.machines) do
    m.busin = false
    for _, r in ipairs(m.src or {}) do
      if r.k == "bus" then
        m.busin = true
        cons[r.id] = cons[r.id] or {}
        cons[r.id][#cons[r.id] + 1] = i
      elseif not seenp[r.id] then seenp[r.id] = true; pools[#pools + 1] = r.id end
    end
    for _, r in ipairs(m.dst or {}) do
      if r.k == "bus" then buses[r.id] = true
      elseif not seenp[r.id] then seenp[r.id] = true; pools[#pools + 1] = r.id end
    end
    for _, id in ipairs(m.res or {}) do if not seenp[id] then seenp[id] = true; pools[#pools + 1] = id end end
    m.jpc = (m.power or 0) / m.rate                      -- J utiles par cycle
    m.fpc = (m.energy == "burner") and (m.jpc / m.eff) or 0 -- J de combustible par cycle
  end
  -- un brûleur ne tire son combustible d'un bus que si un producteur de ce bus fait un combustible qui n'est pas son ingrédient
  local fv = il.fv or {}
  local made = {}
  for _, m in ipairs(il.machines) do
    for _, r in ipairs(m.dst or {}) do
      if r.k == "bus" then
        made[r.id] = made[r.id] or {}
        for _, it in ipairs(m.out) do made[r.id][#made[r.id] + 1] = it[1] end
      end
    end
  end
  for _, m in ipairs(il.machines) do
    m.busfuel = false
    if m.energy == "burner" then
      for _, r in ipairs(m.src or {}) do
        for _, n in ipairs((r.k == "bus" and made[r.id]) or {}) do
          if (fv[n] or 0) > 0 and amount_of(m.ing or {}, n) == 0 then m.busfuel = true end
        end
      end
    end
  end
  table.sort(pools, function(a, b) return tostring(a) < tostring(b) end)
  il.order, il.cons, il.bus_ids, il.pool_ids = order, cons, sorted_names(buses), pools
  il.fnames = sorted_names(il.fv)
  il.prepared = true
  return il
end

-- Énergie de combustible encore disponible dans une réserve (J), net de ce que ce pas a déjà brûlé (used).
local function fuel_energy(il, fp, used)
  if not fp then return 0 end
  local e = used and used.rem or fp.rem or 0
  local fv, fn = il.fv or {}, il.fnames
  for i = 1, #fn do
    local n = fn[i]
    e = e + ((fp.items[n] or 0) - ((used and used.items[n]) or 0)) * (fv[n] or 0)
  end
  return e
end

-- Besoin d'un preneur c pour l'objet n, pour d cycles ENTIERS : ingrédient, et combustible de bus pour un brûleur.
local function need_of(il, c, n, d)
  local a = amount_of(c.ing or {}, n)
  local k = floor(d + Gc.EPS)
  if a > 0 then return k * a end
  if c.energy == "burner" and c.busfuel then
    local fv = (il.fv or {})[n] or 0
    if fv > 0 then return math.ceil(k * c.fpc / fv - Gc.EPS) end
  end
  return 0
end

-- Capacité en cycles sur dt (temps, courant, fraction gardée).
local function capacity(m, sat, st, dt)
  local s = (m.energy == "electric") and sat or 1
  if s <= 0 then return 0 end
  return m.rate * dt * s + ((st.frac and st.frac[m.id]) or 0)
end

-- Limites FIXES (avant la passe avant) : gisement, combustible propre (sans bus d'entrée), ingrédients venus de réserves seules.
local function static_limit(il, m, fr)
  local lim = huge
  if m.kind == "drill" then
    local a = 0
    for _, id in ipairs(m.res) do a = a + max(0, ((fr.pools[id] or {}).amount or 0)) end
    lim = a
  end
  if m.energy == "burner" and m.fpc > 0 and not m.busfuel then lim = min(lim, fuel_energy(il, fr.fuel[m.fuel], nil) / m.fpc) end
  if not m.busin then
    if m.kind == "craft" then
      for _, it in ipairs(m.ing) do
        local avail = 0
        for _, r in ipairs(m.src or {}) do
          local p = fr.pools[r.id]
          avail = avail + ((p and p.items[it[1]]) or 0)
        end
        lim = min(lim, avail / it[2])
      end
    end
  end
  return lim
end

-- Passe ARRIÈRE : D[i] = cycles au plus. caps : plafonds imposés (passe suivante).
local function backward(il, fr, st, dt, caps, sat)
  local ms, cons, order = il.machines, il.cons, il.order
  local D, left, space = {}, {}, {}
  local carry = st.carry or {}
  for idx = #order, 1, -1 do
    local i = order[idx]
    local m = ms[i]
    local d = min(capacity(m, sat, st, dt), static_limit(il, m, fr))
    if caps and caps[i] then d = min(d, caps[i]) end
    local pf = (st.pfrac and st.pfrac[m.id]) or {}
    local dst, outs = m.dst or {}, m.out
    for o = 1, #outs do
      local n, a = outs[o][1], outs[o][2] * (1 + (m.prod or 0))
      local absorb = 0
      for _, r in ipairs(dst) do
        if r.k == "pool" then
          space[r.id] = space[r.id] or {}
          local sp = space[r.id][n]
          if sp == nil then sp = (fr.pools[r.id] and fr.pools[r.id].space[n]) or 0; space[r.id][n] = sp end
          absorb = absorb + sp
        else
          left[r.id] = left[r.id] or {}
          local l = left[r.id][n]
          if l == nil then
            l = 0
            for _, j in ipairs(cons[r.id] or {}) do l = l + need_of(il, ms[j], n, D[j] or 0) end
            l = max(0, l - ((carry[r.id] and carry[r.id][n]) or 0))
            left[r.id][n] = l
          end
          absorb = absorb + l
        end
      end
      if a > 0 then d = min(d, max(0, absorb - (pf[n] or 0)) / a) end
    end
    d = max(0, d)
    D[i] = d
    -- part réservée par ce producteur, en objets entiers (bus d'abord, puis réserves : même ordre que le dépôt)
    for o = 1, #outs do
      local n = outs[o][1]
      local q = floor(d * outs[o][2] * (1 + (m.prod or 0)) + (pf[n] or 0) + Gc.EPS)
      for pass = 1, 2 do
        for _, r in ipairs(dst) do
          if q > 0 and ((pass == 1 and r.k == "bus") or (pass == 2 and r.k == "pool")) then
            local box = (r.k == "pool") and space[r.id] or left[r.id]
            local u = min(q, box[n] or 0)
            box[n] = (box[n] or 0) - u
            q = q - u
          end
        end
      end
    end
  end
  return D
end

-- Prend `want` objets n aux sources (bus d'abord, puis réserves) ; rend la quantité prise.
local function take(srcs, n, want, pools, buses, res)
  local got = 0
  for pass = 1, 2 do
    for _, r in ipairs(srcs) do
      if got >= want then return got end
      local isbus = r.k == "bus"
      if (pass == 1) == isbus then
        local box = isbus and buses[r.id] or (pools[r.id] and pools[r.id].items)
        local have = box and box[n] or 0
        local q = min(have, want - got)
        if q > 0 then
          box[n] = have - q
          got = got + q
          if not isbus then
            local t = res.take[r.id] or {}
            res.take[r.id] = t
            t[n] = (t[n] or 0) + q
          end
        end
      end
    end
  end
  return got
end

-- Combustible : J brûlés pris aux bus (combustibles qui ne sont pas des ingrédients), puis à la réserve propre (braise, puis objets).
local function burn(il, m, need_j, fr, buses, res)
  if need_j <= Gc.EPS then return end
  local fv, fn = il.fv or {}, il.fnames
  if m.busin then
    for _, r in ipairs(m.src) do
      local box = (r.k == "bus") and buses[r.id] or nil
      if box then
        for i = 1, #fn do
          local n = fn[i]
          local have = box[n] or 0
          if have > 0 and need_j > Gc.EPS and amount_of(m.ing or {}, n) == 0 and (fv[n] or 0) > 0 then
            local c = min(have, math.ceil(need_j / fv[n] - Gc.EPS))
            box[n] = have - c
            need_j = need_j - c * fv[n]
            res.consumed[n] = (res.consumed[n] or 0) + c
          end
        end
      end
    end
  end
  if need_j <= Gc.EPS then return end
  local fp = fr.fuel[m.fuel]
  local out = res.fuel[m.fuel]
  if not out then out = { items = {}, rem = fp.rem or 0 }; res.fuel[m.fuel] = out end
  if out.rem >= need_j then out.rem = out.rem - need_j return end
  need_j = need_j - out.rem
  out.rem = 0
  for i = 1, #fn do
    local n = fn[i]
    local f = fv[n] or 0
    local left = (fp.items[n] or 0) - (out.items[n] or 0)
    if f > 0 and left > 0 and need_j > Gc.EPS then
      local c = min(left, math.ceil(need_j / f - Gc.EPS))
      out.items[n] = (out.items[n] or 0) + c
      res.consumed[n] = (res.consumed[n] or 0) + c
      out.rem = max(0, c * f - need_j)
      need_j = need_j - c * f
      out.burning = n
    end
  end
end

-- Limites (cycles) à l'entrée de la passe avant : ingrédients (bus et réserves), gisement, combustible.
local function supply_limits(il, m, pools, buses, fr, res)
  local ing, gis, fuel = huge, huge, huge
  local src = m.src or {}
  if m.kind == "craft" then
    for _, it in ipairs(m.ing) do
      local avail = 0
      for _, r in ipairs(src) do
        local box = (r.k == "bus") and buses[r.id] or (pools[r.id] and pools[r.id].items)
        avail = avail + ((box and box[it[1]]) or 0)
      end
      ing = min(ing, avail / it[2])
    end
  else
    local a = 0
    for _, id in ipairs(m.res) do a = a + max(0, (pools[id] and pools[id].amount) or 0) end
    gis = a
  end
  if m.energy == "burner" and m.fpc > 0 then
    local e = fuel_energy(il, fr.fuel[m.fuel], res.fuel[m.fuel])
    if m.busin then
      local fv, fn = il.fv or {}, il.fnames
      for _, r in ipairs(src) do
        local box = (r.k == "bus") and buses[r.id] or nil
        if box then
          for i = 1, #fn do
            local n = fn[i]
            if amount_of(m.ing or {}, n) == 0 then e = e + (box[n] or 0) * (fv[n] or 0) end
          end
        end
      end
    end
    fuel = e / m.fpc
  end
  return ing, gis, fuel
end

-- Place restante en aval (cycles) pour chaque produit : réserves (place) et bus (besoin entier de leurs preneurs).
local function out_limit(il, m, pools, buses, D, st)
  local lim = huge
  local pf = (st.pfrac and st.pfrac[m.id]) or {}
  for _, it in ipairs(m.out) do
    local n, a = it[1], it[2] * (1 + (m.prod or 0))
    local absorb = 0
    for _, r in ipairs(m.dst or {}) do
      if r.k == "pool" then
        absorb = absorb + ((pools[r.id] and pools[r.id].space[n]) or 0)
      else
        local need = 0
        for _, j in ipairs(il.cons[r.id] or {}) do need = need + need_of(il, il.machines[j], n, D[j] or 0) end
        absorb = absorb + max(0, need - ((buses[r.id] and buses[r.id][n]) or 0))
      end
    end
    if a > 0 then lim = min(lim, max(0, absorb - (pf[n] or 0)) / a) end
  end
  return lim
end

-- Dépose q objets n en aval : bus (au besoin entier restant), réserves (à la place), puis reste au premier bus. Rend ce qui reste.
local function deliver(il, m, n, q, pools, buses, D, res)
  local dst = m.dst or {}
  for pass = 1, 3 do
    for _, r in ipairs(dst) do
      if q <= 0 then return 0 end
      if r.k == "bus" and pass ~= 2 then
        local box = buses[r.id]
        local put = q
        if pass == 1 then
          local need = 0
          for _, j in ipairs(il.cons[r.id] or {}) do need = need + need_of(il, il.machines[j], n, D[j] or 0) end
          put = min(q, max(0, need - (box[n] or 0)))
        end
        if put > 0 then box[n] = (box[n] or 0) + put; q = q - put end
      elseif r.k == "pool" and pass == 2 then
        local p = pools[r.id]
        local room = p and p.space[n] or 0
        local put = min(q, room)
        if put > 0 then
          p.space[n] = room - put
          local t = res.put[r.id] or {}
          res.put[r.id] = t
          t[n] = (t[n] or 0) + put
          q = q - put
        end
      end
    end
  end
  return q
end

-- Statut comptable (nom d'un defines.entity_status) : le runtime le rend à la place de `disabled_by_script` (Gel.status).
local function status_of(m, k, l, sat)
  if k > 0 then
    if m.energy == "electric" and sat < 1 then return "low_power" end
    return "working"
  end
  if m.energy == "electric" and sat <= 0 then return "no_power" end
  if m.kind == "drill" then
    if l.res < 1 - Gc.EPS then return "no_minable_resources" end
    if m.energy == "burner" and l.fuel < 1 - Gc.EPS then return "no_fuel" end
    if l.out < 1 - Gc.EPS then return "waiting_for_space_in_destination" end
  else
    if l.out < 1 - Gc.EPS then return "full_output" end
    if m.energy == "burner" and l.fuel < 1 - Gc.EPS then return "no_fuel" end
    if l.ing < 1 - Gc.EPS then return "no_ingredients" end
  end
  return "working" -- moins d'un cycle sur ce pas (fraction gardée) : la machine travaille
end

-- Passe AVANT avec les plafonds D.
local function forward(il, fr, st, dt, D, sat)
  local ms, order = il.machines, il.order
  local pools = {}
  for _, id in ipairs(il.pool_ids) do
    local p = fr.pools[id]
    if p then pools[id] = { items = copy(p.items), space = copy(p.space), amount = p.amount } end
  end
  local buses = {}
  local carry = st.carry or {}
  for _, b in ipairs(il.bus_ids) do buses[b] = copy(carry[b]) end
  local res = { take = {}, put = {}, mined = {}, fuel = {}, crafts = {}, status = {}, frac = {}, pfrac = {}, produced = {}, consumed = {},
    energy = 0, useful = 0, pollution = 0, excess = 0, carry = {} }
  for oi = 1, #order do
    local i = order[oi]
    local m = ms[i]
    local cap = capacity(m, sat, st, dt)
    local l = { out = out_limit(il, m, pools, buses, D, st) }
    l.ing, l.res, l.fuel = supply_limits(il, m, pools, buses, fr, res)
    local x = max(0, min(cap, l.ing, l.res, l.fuel, l.out, D[i] or 0))
    local k = floor(x + Gc.EPS)
    res.frac[m.id] = (x >= cap - Gc.EPS) and max(0, min(0.999999, cap - k)) or 0
    res.crafts[m.id] = k
    if m.kind == "craft" then
      for _, it in ipairs(m.ing) do
        local got = take(m.src or {}, it[1], k * it[2], pools, buses, res)
        res.consumed[it[1]] = (res.consumed[it[1]] or 0) + got
      end
    else
      local need = k
      for _, id in ipairs(m.res) do
        local p = pools[id] -- un gisement non relu (le runtime ne lit que ce qu'il faut pour le pas) compte pour 0
        local q = p and min(need, max(0, p.amount or 0)) or 0
        if q > 0 then
          p.amount = p.amount - q
          res.mined[id] = (res.mined[id] or 0) + q
          need = need - q
        end
      end
    end
    local useful = m.jpc * k
    if m.energy == "burner" then burn(il, m, m.fpc * k, fr, buses, res)
    else res.energy = res.energy + useful + (m.drain or 0) * dt end
    res.useful = res.useful + useful
    res.pollution = res.pollution + useful * (m.emis or 0)
    local pf_old = (st.pfrac and st.pfrac[m.id]) or {}
    local pf = {}
    for _, it in ipairs(m.out) do
      local n = it[1]
      local total = k * it[2] * (1 + (m.prod or 0)) + (pf_old[n] or 0)
      local q = floor(total + Gc.EPS)
      local back = deliver(il, m, n, q, pools, buses, D, res)
      pf[n] = total - q + back -- ce qui n'a pas trouvé place reste « à faire » (jamais perdu, jamais créé)
      res.produced[n] = (res.produced[n] or 0) + (q - back)
    end
    res.pfrac[m.id] = pf
    res.status[m.id] = status_of(m, k, l, sat)
  end
  for _, b in ipairs(il.bus_ids) do
    local box, keep = buses[b], {}
    for _, n in ipairs(sorted_names(box)) do
      if box[n] > 0 then
        keep[n] = box[n]
        if box[n] > Gc.CARRY_MAX then res.excess = res.excess + (box[n] - Gc.CARRY_MAX) end
      end
    end
    res.carry[b] = keep
  end
  return res
end

-- Preneurs à plafonner quand un bus garde un reste plus grand qu'au début du pas.
local function caps_from_leftover(il, st, res)
  local caps, any = {}, false
  for _, b in ipairs(il.bus_ids) do
    local box, old = res.carry[b] or {}, (st.carry and st.carry[b]) or {}
    for _, n in ipairs(sorted_names(box)) do
      if (box[n] or 0) > (old[n] or 0) then
        for _, j in ipairs(il.cons[b] or {}) do caps[j] = res.crafts[il.machines[j].id]; any = true end
      end
    end
  end
  return any and caps or nil
end

--- Un pas de `dt` ticks. Rend res = { take, put, mined, fuel, crafts, status, frac, pfrac, carry, produced, consumed, energy (J
--- électriques), useful (J utiles), pollution, excess } ; le runtime applique take/put/mined/fuel au monde et garde frac/pfrac/carry.
function Gc.step(il, fr, st, dt)
  if not il.prepared then
    local okp, why = Gc.prepare(il)
    if not okp then return nil, why end
  end
  fr.pools, fr.fuel = fr.pools or {}, fr.fuel or {}
  st = st or {}
  local sat = max(0, min(1, fr.sat or 1))
  local D = backward(il, fr, st, dt, nil, sat)
  local res = forward(il, fr, st, dt, D, sat)
  local passes = 1
  for _ = 2, Gc.PASSES do
    local caps = caps_from_leftover(il, st, res)
    if not caps then break end
    D = backward(il, fr, st, dt, caps, sat)
    res = forward(il, fr, st, dt, D, sat)
    passes = passes + 1
  end
  res.passes = passes
  return res
end

--- Garde le nouvel état d'un îlot après un pas appliqué.
function Gc.commit(st, res)
  st.frac, st.pfrac, st.carry = res.frac, res.pfrac, res.carry
  return st
end

--- Remise à zéro au gel et au réveil (fractions et reports perdus : jamais un gain). Rend les reports perdus { [objet] = n }.
function Gc.reset(st)
  local lost = {}
  for _, b in ipairs(sorted_names(st.carry)) do
    for _, n in ipairs(sorted_names(st.carry[b])) do lost[n] = (lost[n] or 0) + st.carry[b][n] end
  end
  st.frac, st.pfrac, st.carry = {}, {}, {}
  return lost
end

return Gc
