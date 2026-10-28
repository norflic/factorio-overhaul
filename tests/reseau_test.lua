--[[
  Lot RESEAU : test hors jeu de la règle pure shared/team/reseau.lua (réseau électrique des équipes de PNJ).
    §1 fils, couverture, composantes, état : l'analyse (grille, union-find, tranches de travail) contre une version NAÏVE
       (toutes les paires, parcours récursif) sur des réseaux tirés au hasard, et cas limites exacts (distance = portée) ;
    §2 poteaux pivots : perte exacte de CHAQUE poteau contre « retirer et tout recalculer », liste de la tâche reprenable ;
    §3 réparation : plan de poteaux relevés contre une FORCE BRUTE sur tous les sous-ensembles (même ensemble rallumé,
       coût comparé à l'optimum : exact avec une cible, rapport mesuré au-delà) ;
    §4 zones non couvertes contre le regroupement naïf par paires ;
    §5 capacité : tableau de verdicts (80 %, saturation, plan en attente, production nulle), unités à ajouter ;
    §6 déterminisme, tranches de travail (budget 1 = budget infini) et aucun nom d'objet du jeu ;
    §7 mutants : chaque règle retirée est vue.
  Usage : lua5.2 tests/reseau_test.lua   (depuis la racine du mod)
]]
io.stdout:setvbuf("no")
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/reseau.lua")

local function load_r(src)
  local fn, err = load(src, "=reseau", "t")
  if not fn then return nil, err end
  local ok, mod = pcall(fn)
  if not ok then return nil, mod end
  return mod
end

---------------------------------------------------------------------------------------------------
-- Générateur (Lehmer : entiers exacts en double)
---------------------------------------------------------------------------------------------------
local function rng(seed)
  local s = seed
  return function(n)
    s = (s * 16807) % 2147483647
    return (s % n) + 1
  end
end

local function rand_net(rnd, opts)
  opts = opts or {}
  local npole = opts.poles or (rnd(12) + 1)
  local ncons = opts.cons or (rnd(10))
  local nprod = opts.prod or (rnd(3) - 1)
  local net = { poles = {}, consumers = {}, producers = {} }
  local W = opts.size or 18
  for i = 1, npole do
    net.poles[i] = { id = i, x = rnd(W) - 0.5, y = rnd(W) - 0.5, wire = ({ 3, 4, 7.5, 9 })[rnd(4)], supply = ({ 1, 2, 2.5, 3.5 })[rnd(4)] }
  end
  for k = 1, ncons do
    local x, y = rnd(W) - 0.5, rnd(W) - 0.5
    local w, h = rnd(3), rnd(3)
    net.consumers[k] = { id = k, x0 = x - w / 2, y0 = y - h / 2, x1 = x + w / 2, y1 = y + h / 2, kw = 10 * rnd(9), starved = rnd(5) == 1 }
  end
  for k = 1, nprod do
    local x, y = rnd(W) - 0.5, rnd(W) - 0.5
    net.producers[k] = { id = k, x0 = x - 1.5, y0 = y - 1.5, x1 = x + 1.5, y1 = y + 1.5, kw = 900, out_kw = 100 * rnd(8) }
  end
  return net
end

---------------------------------------------------------------------------------------------------
-- Références naïves
---------------------------------------------------------------------------------------------------
local function ref_links(poles, R)
  local e = {}
  for i = 1, #poles do
    for j = i + 1, #poles do
      local reach = math.min(poles[i].wire, poles[j].wire)
      local dx, dy = poles[i].x - poles[j].x, poles[i].y - poles[j].y
      if reach > 0 and math.sqrt(dx * dx + dy * dy) <= reach + 1e-9 then e[#e + 1] = { i, j } end
    end
  end
  return e
end

local function ref_cover(p, b)
  local ox = math.min(b.x1, p.x + p.supply) - math.max(b.x0, p.x - p.supply)
  local oy = math.min(b.y1, p.y + p.supply) - math.max(b.y0, p.y - p.supply)
  return ox > 1e-9 and oy > 1e-9
end

-- Renvoie : comp (parcours récursif), powered par consommateur (ids)
local function ref_analyse(net, R)
  local poles = net.poles
  local n = #poles
  local edges = ref_links(poles, R)
  local adj = {}
  for i = 1, n do adj[i] = {} end
  for _, e in ipairs(edges) do adj[e[1]][#adj[e[1]] + 1] = e[2]; adj[e[2]][#adj[e[2]] + 1] = e[1] end
  local comp, nc = {}, 0
  local function dfs(v, c)
    comp[v] = c
    for _, w in ipairs(adj[v]) do if not comp[w] then dfs(w, c) end end
  end
  for i = 1, n do if not comp[i] then nc = nc + 1; dfs(i, nc) end end
  local touch = {}
  for _, pr in ipairs(net.producers) do
    for i = 1, n do if ref_cover(poles[i], pr) then touch[comp[i]] = true end end
  end
  local powered, uncovered, orphans = {}, {}, {}
  for k, c in ipairs(net.consumers) do
    local any, live = false, false
    for i = 1, n do
      if ref_cover(poles[i], c) then
        any = true
        if touch[comp[i]] then live = true end
      end
    end
    powered[k] = live
    if not any then uncovered[#uncovered + 1] = k elseif not live then orphans[#orphans + 1] = k end
  end
  return { edges = edges, comp = comp, nc = nc, powered = powered, uncovered = uncovered, orphans = orphans }
end

local function without_pole(net, p)
  local poles = {}
  for i, q in ipairs(net.poles) do if i ~= p then poles[#poles + 1] = q end end
  return { poles = poles, consumers = net.consumers, producers = net.producers }
end

local function same_list(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i] ~= b[i] then return false end end
  return true
end

local function same_edges(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i][1] ~= b[i][1] or a[i][2] ~= b[i][2] then return false end end
  return true
end

---------------------------------------------------------------------------------------------------
-- La suite (rendue pour un module R donné : l'original, puis chaque mutant)
---------------------------------------------------------------------------------------------------
local function suite(R, verbose, strict)
  local fails, oks = 0, 0
  local first
  local function check(cond, msg)
    if cond then oks = oks + 1 else
      fails = fails + 1
      first = first or msg
      if strict then error("mutant vu : " .. msg, 0) end
      if verbose then print("  ECHEC : " .. msg) end
    end
  end

  -- §1 cas limites exacts
  do
    local a = { x = 0, y = 0, wire = 7.5, supply = 2.5 }
    local b = { x = 7.5, y = 0, wire = 9, supply = 2 }
    local c = { x = 7.5001, y = 0, wire = 9, supply = 2 }
    local d = { x = 9, y = 0, wire = 9, supply = 2 }
    check(R.linked(a, b), "fil : distance exactement égale à la plus petite portée (7,5) relie")
    check(not R.linked(a, c), "fil : un cheveu au-delà ne relie pas")
    check(not R.linked(a, d), "fil : la portée est le MINIMUM des deux (9 > 7,5)")
    check(R.linked(b, d), "fil : 1,5 < 9")
    check(not R.linked({ x = 0, y = 0, wire = 0, supply = 1 }, { x = 1, y = 0, wire = 9, supply = 1 }), "fil : portée nulle ne relie jamais")
    local e = R.links({ a, b, c, d })
    check(same_edges(e, ref_links({ a, b, c, d }, R)), "fils : grille = toutes les paires (cas limites)")
    -- aire d'alimentation : strictement positive
    local p = { x = 0, y = 0, wire = 7.5, supply = 2.5 }
    check(R.covers(p, { x0 = 2.4, y0 = 0, x1 = 4, y1 = 1 }), "aire : recouvrement de 0,1 compte")
    check(not R.covers(p, { x0 = 2.5, y0 = 0, x1 = 4, y1 = 1 }), "aire : simple contact ne compte pas")
    check(not R.covers(p, { x0 = -1, y0 = 2.5, x1 = 1, y1 = 4 }), "aire : contact par le haut ne compte pas")
    check(R.covers(p, { x0 = -4, y0 = -4, x1 = 4, y1 = 4 }), "aire : bâtiment qui contient l'aire")
  end

  -- §1 analyse contre la version naïve
  do
    local rnd = rng(20281028)
    local bad = 0
    for case = 1, 400 do
      local net = rand_net(rnd, { size = ({ 10, 18, 30 })[(case % 3) + 1] })
      local ref = ref_analyse(net, R)
      local A = R.analyse(net)
      local ok = same_edges(A.edges, ref.edges) and A.ncomp == ref.nc
      for i = 1, #net.poles do if A.comp[i] ~= ref.comp[i] then ok = false end end
      for k = 1, #net.consumers do if (A.powered[k] or false) ~= ref.powered[k] then ok = false end end
      ok = ok and same_list(A.uncovered, ref.uncovered) and same_list(A.orphans, ref.orphans)
      if not ok then bad = bad + 1 end
      -- totaux : la somme des kW des composantes = somme des producteurs couverts
      local s, expect = 0, 0
      for c = 1, A.ncomp do s = s + A.comps[c].prod_kw end
      for k, pr in ipairs(net.producers) do if #A.cover_p[k] > 0 then expect = expect + pr.kw end end
      if math.abs(s - expect) > 1e-6 then bad = bad + 1 end
    end
    check(bad == 0, "analyse : 400 réseaux au hasard identiques à la version naïve (" .. bad .. " écarts)")
    -- tranches de travail : un budget de 3 donne le même résultat que le budget infini
    local net = rand_net(rng(5), { poles = 14, cons = 12, prod = 2 })
    local A1 = R.analyse(net)
    local job = R.job(net)
    local steps = 0
    while not R.job_step(job, 3) do steps = steps + 1 end
    local A2 = job.A
    local same = A1.ncomp == A2.ncomp and same_list(A1.uncovered, A2.uncovered) and same_list(A1.orphans, A2.orphans)
    for k = 1, #net.consumers do if (A1.powered[k] or false) ~= (A2.powered[k] or false) then same = false end end
    check(same and steps > 3, "tranches de travail : budget 3 = budget infini (" .. steps .. " tranches)")
  end

  -- §1 exemple parlant : chaîne de poteaux, une centrale, un îlot, un bâtiment hors de portée
  do
    local net = {
      poles = {
        { id = 1, x = 0.5, y = 0.5, wire = 7.5, supply = 2.5 }, { id = 2, x = 7.5, y = 0.5, wire = 7.5, supply = 2.5 },
        { id = 3, x = 14.5, y = 0.5, wire = 7.5, supply = 2.5 },   -- chaîne 1-2-3
        { id = 4, x = 40.5, y = 0.5, wire = 7.5, supply = 2.5 },   -- îlot sans producteur
      },
      producers = { { id = 1, x0 = -3, y0 = -1, x1 = 0, y1 = 2, kw = 900, out_kw = 450 } },
      consumers = {
        { id = 1, x0 = 6, y0 = 2, x1 = 9, y1 = 5, kw = 90 },            -- couvert par 2
        { id = 2, x0 = 13, y0 = 2, x1 = 16, y1 = 5, kw = 150 },         -- couvert par 3
        { id = 3, x0 = 39, y0 = 2, x1 = 42, y1 = 5, kw = 90 },          -- couvert par 4 : orphelin
        { id = 4, x0 = 60, y0 = 0, x1 = 62, y1 = 2, kw = 30 },          -- hors de toute aire
      },
    }
    local A = R.analyse(net)
    check(A.ncomp == 2 and A.comp[1] == 1 and A.comp[3] == 1 and A.comp[4] == 2, "exemple : deux composantes")
    check(A.powered[1] and A.powered[2] and not A.powered[3] and not A.powered[4], "exemple : alimentés 1 et 2 seulement")
    check(same_list(A.uncovered, { 4 }) and same_list(A.orphans, { 3 }), "exemple : hors de portée 4, orphelin 3")
    check(#A.islands == 1 and A.islands[1] == 2, "exemple : un îlot sans producteur")
    local cap = R.capacity(A)
    check(cap.prod_kw == 900 and cap.dem_kw == 240 and cap.out_kw == 450 and cap.uncovered == 1 and cap.islands == 1,
      "exemple : capacité (production 900, demande 240)")
    -- pivots : 1 couvre seul le producteur, 2 coupe la chaîne vers 3, 3 couvre seul le consommateur 2
    local job = R.pivot_job(net, A)
    check(R.pivot_step(job, math.huge), "pivots : tâche finie")
    local by = {}
    for _, o in ipairs(job.out) do by[o.pole] = o end
    check(by[1] and by[1].n == 2 and by[1].kw == 240 and by[2] and by[2].n == 2 and by[2].kw == 240 and by[3] and by[3].n == 1
      and by[3].kw == 150 and not by[4], "pivots : perte de 1 = 240 kW (producteur), de 2 = 240 kW (coupe la chaîne), de 3 = 150 kW, 4 sans effet")
    check(job.out[1].pole == 1, "pivots : le plus lourd d'abord")
  end

  -- §2 pivots : perte exacte de chaque poteau
  do
    local rnd = rng(777)
    local bad, tot, nonc = 0, 0, 0
    for case = 1, 250 do
      local net = rand_net(rnd, { poles = rnd(12) + 2, cons = rnd(10), prod = rnd(2), size = ({ 12, 20 })[(case % 2) + 1] })
      local A = R.analyse(net)
      local ref0 = ref_analyse(net, R)
      local cand = R.pivot_candidates(net, A)
      local iscand = {}
      for _, p in ipairs(cand) do iscand[p] = true end
      local exp = {}
      for p = 1, #net.poles do
        local ref = ref_analyse(without_pole(net, p), R)
        local n, kw = 0, 0
        for k, c in ipairs(net.consumers) do
          if ref0.powered[k] and not ref.powered[k] then n = n + 1; kw = kw + c.kw end
        end
        tot = tot + 1
        local l = R.loss(net, A, p)
        if l.n ~= n or math.abs(l.kw - kw) > 1e-9 then bad = bad + 1 end
        if n > 0 and not iscand[p] then nonc = nonc + 1 end -- un poteau qui éteint quelque chose doit être candidat
        if n > 0 then exp[#exp + 1] = { pole = p, n = n, kw = kw } end
      end
      table.sort(exp, function(a, b)
        if a.kw ~= b.kw then return a.kw > b.kw end
        if a.n ~= b.n then return a.n > b.n end
        return a.pole < b.pole
      end)
      local job = R.pivot_job(net, A)
      local steps = 0
      while not R.pivot_step(job, 2) do steps = steps + 1 end
      local same = #job.out == #exp
      if same then for i = 1, #exp do if job.out[i].pole ~= exp[i].pole or job.out[i].n ~= exp[i].n then same = false end end end
      if not same then bad = bad + 1 end
    end
    check(bad == 0, "pivots : " .. tot .. " poteaux, perte exacte et liste de la tâche reprenable (" .. bad .. " écarts)")
    check(nonc == 0, "pivots : tout poteau dont la perte éteint quelque chose est candidat (" .. nonc .. " oubliés)")
    -- points d'articulation contre « retirer et compter les composantes »
    local bad2 = 0
    for case = 1, 300 do
      local net = rand_net(rnd, { poles = rnd(14) + 1, cons = 0, prod = 0, size = 16 })
      local A = R.analyse(net)
      local art = R.articulation(A.n, A.adj)
      for p = 1, A.n do
        local _, nc = R.components(A.n, A.adj, p)
        -- retirer p retire sa composante si elle était seule (nc diminue) ; il y a articulation si nc augmente
        local expect = nc > A.ncomp or (nc == A.ncomp and false)
        if (art[p] or false) ~= expect then bad2 = bad2 + 1 end
      end
    end
    check(bad2 == 0, "articulation : Tarjan = comptage des composantes après retrait (" .. bad2 .. " écarts)")
  end

  -- §3 réparation contre la force brute
  do
    local rnd = rng(31415)
    local bad, multi_sub, multi_n, single_n, single_bad, worst = 0, 0, 0, 0, 0, 1
    local with_targets = 0
    for case = 1, 220 do
      local net = rand_net(rnd, { poles = rnd(8) + 3, cons = rnd(6) + 2, prod = 1, size = 16 })
      local g = rnd(7)
      local cands = {}
      for j = 1, g do
        cands[j] = { id = 100 + j, x = rnd(16) - 0.5, y = rnd(16) - 0.5, wire = ({ 4, 7.5, 9 })[rnd(3)], supply = ({ 2, 2.5 })[rnd(2)], cost = rnd(3) == 1 and 2 or 1 }
      end
      local res = R.repair(net, cands)
      -- référence : ensemble des consommateurs rallumés par tous les candidats
      local function powered_with(set)
        local poles = {}
        for i, q in ipairs(net.poles) do poles[i] = q end
        for j = 1, g do if set[j] then poles[#poles + 1] = cands[j] end end
        return ref_analyse({ poles = poles, consumers = net.consumers, producers = net.producers }, R).powered
      end
      local all = {}
      for j = 1, g do all[j] = true end
      local p_all, p_none = powered_with(all), powered_with({})
      local must = {}
      for k = 1, #net.consumers do if p_all[k] and not p_none[k] then must[#must + 1] = k end end
      if res.targets ~= #must then bad = bad + 1 end
      -- le plan rallume tout ce qui est rallumable
      local chosen_set = {}
      for _, j in ipairs(res.chosen) do chosen_set[j] = true end
      local p_plan = powered_with(chosen_set)
      for _, k in ipairs(must) do if not p_plan[k] then bad = bad + 1 end end
      if #must > 0 then
        with_targets = with_targets + 1
        -- optimum par énumération
        local opt = math.huge
        for mask = 0, 2 ^ g - 1 do
          local set, cost = {}, 0
          for j = 1, g do
            if math.floor(mask / 2 ^ (j - 1)) % 2 == 1 then set[j] = true; cost = cost + cands[j].cost end
          end
          if cost < opt then
            local pw = powered_with(set)
            local okset = true
            for _, k in ipairs(must) do if not pw[k] then okset = false break end end
            if okset then opt = cost end
          end
        end
        if res.cost < opt - 1e-9 then bad = bad + 1 end              -- jamais mieux que l'optimum
        -- une seule cible : le plus court chemin est OPTIMAL
        if #must == 1 then
          single_n = single_n + 1
          if res.cost > opt + 1e-9 then single_bad = single_bad + 1 end
        else
          multi_n = multi_n + 1
          if opt > 0 then
            local ratio = res.cost / opt
            if ratio > worst then worst = ratio end
            if ratio > 1 + 1e-9 then multi_sub = multi_sub + 1 end
          end
        end
      else
        if #res.chosen ~= 0 then bad = bad + 1 end
      end
    end
    check(bad == 0, "réparation : même ensemble rallumé que tous les candidats, jamais sous l'optimum (" .. bad .. " écarts)")
    check(single_bad == 0 and single_n >= 15, "réparation : une seule cible, coût = optimum (" .. single_n .. " cas, " .. single_bad .. " au-dessus)")
    check(worst <= 2 + 1e-9 and multi_n >= 5, string.format("réparation : plusieurs cibles, pire rapport au coût optimal %.2f (%d cas, %d au-dessus de l'optimum)", worst, multi_n, multi_sub))
    check(with_targets >= 40, "réparation : assez de cas non triviaux (" .. with_targets .. ")")
    if verbose then
      print(string.format("  [info] réparation : %d cas avec cibles, %d à une cible, %d à plusieurs (pire rapport %.2f, %d non optimaux)",
        with_targets, single_n, multi_n, worst, multi_sub))
    end
  end

  -- §3 réparation : cas parlant (le DC : « trois poteaux posés à côté »)
  do
    -- chaîne 1 - X - Y - Z - 5 ; X, Y, Z détruits ; trois autres candidats posés « à côté » ne relient rien seuls
    local net = {
      poles = { { id = 1, x = 0.5, y = 0.5, wire = 7.5, supply = 2.5 }, { id = 5, x = 30.5, y = 0.5, wire = 7.5, supply = 2.5 } },
      producers = { { id = 1, x0 = -3, y0 = -1, x1 = 0, y1 = 2, kw = 900, out_kw = 100 } },
      consumers = { { id = 1, x0 = 29, y0 = 2, x1 = 32, y1 = 5, kw = 90 } },
    }
    local cands = {
      { x = 7.5, y = 0.5, wire = 7.5, supply = 2.5 }, { x = 14.5, y = 0.5, wire = 7.5, supply = 2.5 },
      { x = 21.5, y = 0.5, wire = 7.5, supply = 2.5 },
      { x = 21.5, y = 8, wire = 7.5, supply = 2.5 }, { x = 8, y = 8, wire = 7.5, supply = 2.5 }, { x = 15, y = 9, wire = 7.5, supply = 2.5 },
      { x = 26.5, y = 0.5, wire = 7.5, supply = 2.5 },
    }
    local res = R.repair(net, cands)
    check(res.targets == 1 and res.restored == 1, "chaîne coupée : une cible rallumée")
    -- 0,5 -> 7,5 -> 14,5 -> 21,5 -> 26,5 -> 30,5 : exactement 4 poteaux (21,5 à 30,5 = 9 > 7,5), pas les 7 candidats
    check(res.cost == 4 and #res.chosen == 4, "chaîne coupée : " .. res.cost .. " poteaux relevés (4, pas les 7 candidats)")
    local one = R.repair({ poles = net.poles, producers = net.producers, consumers = net.consumers }, {})
    check(#one.chosen == 0 and one.targets == 0, "aucun candidat : rien à relever")
  end

  -- §4 zones
  do
    local rnd = rng(99)
    local bad = 0
    for case = 1, 200 do
      local items = {}
      for i = 1, rnd(12) do
        local x, y = rnd(40), rnd(40)
        local w, h = rnd(3), rnd(3)
        items[i] = { x0 = x, y0 = y, x1 = x + w, y1 = y + h, kw = 5 }
      end
      local gap = ({ 0, 3, 6, 10 })[rnd(4)]
      local zones = R.zones(items, gap)
      -- naïf : fermeture transitive des paires proches
      local lab = {}
      for i = 1, #items do lab[i] = i end
      local changed = true
      while changed do
        changed = false
        for i = 1, #items do
          for j = i + 1, #items do
            local a, b = items[i], items[j]
            local dx = math.max(a.x0 - b.x1, b.x0 - a.x1, 0)
            local dy = math.max(a.y0 - b.y1, b.y0 - a.y1, 0)
            if math.max(dx, dy) <= gap and lab[i] ~= lab[j] then
              local m = math.min(lab[i], lab[j])
              lab[i], lab[j] = m, m
              changed = true
            end
          end
        end
      end
      local classes = {}
      for i = 1, #items do classes[lab[i]] = true end
      local nclass = 0
      for _ in pairs(classes) do nclass = nclass + 1 end
      if #zones ~= nclass then bad = bad + 1 end
      for _, z in ipairs(zones) do
        for _, i in ipairs(z.items) do if lab[i] ~= lab[z.items[1]] then bad = bad + 1 end end
      end
      local tot = 0
      for _, z in ipairs(zones) do tot = tot + z.n end
      if tot ~= #items then bad = bad + 1 end
    end
    check(bad == 0, "zones : regroupement identique au naïf (" .. bad .. " écarts)")
    local z = R.zones({ { x0 = 0, y0 = 0, x1 = 2, y1 = 2, kw = 1 }, { x0 = 6, y0 = 0, x1 = 8, y1 = 2, kw = 1 }, { x0 = 20, y0 = 0, x1 = 22, y1 = 2, kw = 1 } }, 4)
    check(#z == 2 and z[1].n == 2 and z[1].x1 == 8 and z[2].n == 1, "zones : écart exactement égal au seuil regroupe (4), au-delà non")
    local z2 = R.zones({ { x0 = 0, y0 = 0, x1 = 2, y1 = 2, kw = 1 }, { x0 = 6.5, y0 = 0, x1 = 8, y1 = 2, kw = 1 } }, 4)
    check(#z2 == 2, "zones : écart 4,5 > 4 sépare")
  end

  -- §5 capacité
  do
    local function cap(prod, out, starved_kw) return { prod_kw = prod, out_kw = out, dem_kw = out, starved = 0, starved_kw = starved_kw or 0, n_prod = 1, n_cons = 1, islands = 0, uncovered = 0 } end
    local v = R.verdict(cap(1800, 900), { unit_kw = 1800 })
    check(v.level == "ok" and v.add == 0, "capacité : 50 % -> ok")
    v = R.verdict(cap(1800, 1440), { unit_kw = 1800 })
    check(v.level == "alerte" and v.add == 1, "capacité : 80 % exactement -> alerte, une unité (" .. v.level .. " " .. v.add .. ")")
    v = R.verdict(cap(1800, 1439), { unit_kw = 1800 })
    check(v.level == "ok", "capacité : 79,9 % -> ok")
    v = R.verdict(cap(1800, 1790, 400), { unit_kw = 1800 })
    check(v.level == "sature" and v.add == math.ceil((1790 + 400) / 0.6 / 1800 - 1800 / 1800 - 1e-9), "capacité : saturée, les affamés comptent (" .. v.add .. " unités)")
    v = R.verdict(cap(1800, 900, 400), { unit_kw = 1800 })
    check(v.level == "ok", "capacité : affamés à 50 % de charge = problème de fil, pas de capacité")
    v = R.verdict(cap(1800, 900), { unit_kw = 1800, plan_kw = 700 })
    check(v.level == "alerte", "capacité : un module électrique demandé fait passer l'alerte AVANT la saturation (" .. v.level .. ")")
    v = R.verdict(cap(0, 0), { unit_kw = 1800 })
    check(v.level == "sans_centrale" and v.add == 0, "capacité : sans producteur, rien à agrandir ici")
    v = R.verdict(cap(3600, 3300), { unit_kw = 900 })
    check(v.add == math.ceil(3300 / 0.6 / 900 - 3600 / 900 - 1e-9), "capacité : unités = (besoin / cible - production) / unité, arrondi au-dessus (" .. v.add .. ")")
    v = R.verdict(cap(3600, 3300), { unit_kw = 0 })
    check(v.level == "alerte" and v.add == 0, "capacité : unité inconnue, alerte sans ajout")
    local hist = {}
    local m1 = R.push(hist, 10, 3)
    local m2 = R.push(hist, 20, 3)
    R.push(hist, 30, 3)
    local m4 = R.push(hist, 40, 3)
    check(m1 == 10 and m2 == 15 and m4 == 30 and #hist == 3, "moyenne glissante sur 3 valeurs")
    check(R.is_starved(5, 100, 0.1) and not R.is_starved(10, 100, 0.1) and not R.is_starved(0, 0, 0.1), "affamé : sous 10 % du tampon")
  end

  -- §6 déterminisme
  do
    local a = R.analyse(rand_net(rng(42), { poles = 12, cons = 9, prod = 2 }))
    local b = R.analyse(rand_net(rng(42), { poles = 12, cons = 9, prod = 2 }))
    local same = a.ncomp == b.ncomp and same_list(a.uncovered, b.uncovered) and same_list(a.orphans, b.orphans) and same_edges(a.edges, b.edges)
    check(same, "déterminisme : même entrée, même sortie")
  end
  return fails, oks, first
end

---------------------------------------------------------------------------------------------------
-- Exécution
---------------------------------------------------------------------------------------------------
local R = assert(load_r(SRC))
local fails, oks = suite(R, true)
print(string.format("[RESEAU] original : %d OK, %d ECHEC(S)", oks, fails))

-- §6 aucun nom d'objet du jeu dans la règle (hors commentaires)
do
  local code = SRC:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
  local bad = {}
  for q in code:gmatch('"([^"\n]*)"') do
    -- seules chaînes admises : niveaux du verdict, formats d'affichage
    local okq = ({ sans_centrale = true, ok = true, alerte = true, sature = true, index = true, links = true, comps = true,
      cover_c = true, cover_p = true, stats = true, ["aucun producteur alimente"] = true })[q] or q:find("%%")
    if not okq and q ~= "" then bad[#bad + 1] = q end
  end
  if #bad > 0 then fails = fails + 1; print("[RESEAU] ECHEC : chaînes inattendues dans la règle : " .. table.concat(bad, ", ")) end
  oks = oks + 1
end

-- §7 mutants
if arg and arg[1] == "original" then print("[RESEAU] (mutants sautes)") os.exit(fails == 0 and 0 or 1) end
local MUTANTS = {
  { "fil trop court (strict)", "dx * dx + dy * dy <= reach * reach + EPS", "dx * dx + dy * dy < reach * reach - EPS" },
  { "fil : portée max au lieu de min", "local reach = min(p.wire, q.wire)", "local reach = max(p.wire, q.wire)" },
  { "aire : contact compte", "b.x0 < p.x + s - EPS and b.x1 > p.x - s + EPS", "b.x0 <= p.x + s and b.x1 >= p.x - s" },
  { "aire : demi-côté doublé", "local s = p.supply\n  return", "local s = p.supply * 2\n  return" },
  { "articulation : seuil > au lieu de >=", "low[v] >= disc[p]", "low[v] > disc[p]" },
  { "articulation : racine à un enfant", "if root_children > 1 then", "if root_children > 0 then" },
  { "perte : la coupure ne compte pas", "if has[sub[i]] then touches = true break end", "if true then touches = true break end" },
  { "perte : producteur du retiré compte encore", "if i ~= p and A.comp[i] == c0 then has[sub[i]] = true end", "if A.comp[i] == c0 then has[sub[i] or 0] = true end" },
  { "candidats : couvreur unique oublié", "if e[2] == 1 then sole[e[1]] = true end", "if e[2] == 99 then sole[e[1]] = true end" },
  { "tranches : index recalculé à chaque tranche", "if not job.gs then", "if true then" },
  { "analyse : toucher un producteur inutile", "if touch[c] and (not live or c < live) then live = c end", "if (not live or c < live) then live = c end" },
  { "analyse : producteur compté deux fois", "if best then\n      local s = A.comps[best]\n      s.n_prod = s.n_prod + 1\n      s.prod_kw = s.prod_kw + (prods[k].kw or 0)", "if best then\n      local s = A.comps[best]\n      s.n_prod = s.n_prod + 1\n      s.prod_kw = s.prod_kw + 2 * (prods[k].kw or 0)" },
  { "plus court chemin : relâchement inversé", "if nd < dist[w] - EPS then", "if nd > dist[w] + EPS then" },
  { "réparation : sans élagage", "if not restores(chosen) then chosen[j] = true end", "chosen[j] = true" },
  { "réparation : coût ignoré", "cost[v] = v <= nlive and 0 or (all[v].cost or 1)", "cost[v] = v <= nlive and 0 or 1" },
  { "réparation : chemin non relevé", "if q > nlive and cost[q] > 0 then chosen[q - nlive] = true; cost[q] = 0 end", "if q > nlive and cost[q] > 0 then cost[q] = 0 end" },
  { "zones : seuil strict", "if dist(items[i], items[j]) <= gap + EPS then", "if dist(items[i], items[j]) < gap - EPS then" },
  { "zones : écart en x seulement", "return max(dx, dy)\n  end", "return dx\n  end" },
  { "verdict : seuil à 90 %", "projected >= alert - EPS", "projected >= 0.9" },
  { "verdict : affamés toujours imputés", "if load >= R.FULL then need = need + cap.starved_kw end", "need = need + cap.starved_kw" },
  { "verdict : plan en attente ignoré", "local need = cap.out_kw + plan", "local need = cap.out_kw" },
  { "verdict : arrondi en dessous", "math.ceil((need / target - cap.prod_kw) / unit - 1e-9)", "math.floor((need / target - cap.prod_kw) / unit - 1e-9)" },
  { "capacité : composantes sans producteur comptées", "if s.prod then\n      cap.prod_kw", "if true then\n      cap.prod_kw" },
  { "moyenne glissante : fenêtre ignorée", "while #hist > n do table.remove(hist, 1) end", "" },
  { "tâche pivots : tri inversé", "if a.kw ~= b.kw then return a.kw > b.kw end\n      if a.n ~= b.n", "if a.kw ~= b.kw then return a.kw < b.kw end\n      if a.n ~= b.n" },
}
local refused = 0
local kept = {}
for _, m in ipairs(MUTANTS) do
  local t0 = os.clock()
  local i, j = SRC:find(m[2], 1, true)
  if not i then
    kept[#kept + 1] = m[1] .. " (motif introuvable)"
  else
    local src = SRC:sub(1, i - 1) .. m[3] .. SRC:sub(j + 1)
    local mod, err = load_r(src)
    local caught = false
    if not mod then caught = true else
      -- garde-fou : un mutant qui boucle est un mutant vu (limite d'instructions)
      debug.sethook(function() error("trop long", 0) end, "", 20000000)
      local ok, f = pcall(suite, mod, false, true)
      debug.sethook()
      caught = (not ok) or f > 0
    end
    if os.getenv("FO_VERBOSE_MUT") then print(string.format("  mutant %-50s %s %.1fs", m[1], caught and "vu" or "NON VU", os.clock() - t0)) end
    if caught then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
print(string.format("[RESEAU] mutants refusés : %d sur %d", refused, #MUTANTS))
if #kept > 0 then
  fails = fails + 1
  print("[RESEAU] ECHEC : mutants NON refusés : " .. table.concat(kept, " ; "))
end
print(string.format("[RESEAU] BILAN : %d OK, %d ECHEC(S)", oks + refused, fails))
os.exit(fails == 0 and 0 or 1)
