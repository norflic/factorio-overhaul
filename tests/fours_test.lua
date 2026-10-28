--[[
  Lot FOURS « banque de fours dimensionnée au flux, répartiteurs » : banc HORS JEU de la règle pure
  shared/team/banque_fours.lua et de son branchement dans le dimensionnement des fonderies (shared/ai3/automatiser.lua,
  A.sized). Lancement : lua5.2 tests/fours_test.lua (depuis la racine du mod).

    §1 débits d'un four lus dans des nombres de prototype (pierre, acier, un four électrique inventé, bras limitants) ;
    §2 nombre de fours : plus petit n qui absorbe B.COVER du flux ; aucun four affamé (balayage de 400 flux × 5 fours) ;
    §3 FORCE BRUTE des banques : programmation dynamique sur TOUTES les compositions de n en banques admissibles
       (contraintes réécrites ici, indépendamment du module) ;
    §4 FORCE BRUTE des répartiteurs : énumération de toutes les allocations entières, maximum lexicographique par
       priorité, flux conservé, réserve et part maximale respectées (« pas d'ultra-maximisation ») ;
    §5 SIMULATION : fours qui puisent dans un tapis tick par tick ; la charge simulée de chaque four suit B.loads, et la
       charge du four le moins servi d'un plan reste ≥ B.LOAD_MIN ;
    §6 disposition : aucune pièce ne se recouvre, hauteur de lot ;
    §7 GÉNÉRALISATION : mêmes règles sur d'autres nombres (four électrique de vitesse 4, tapis rapide, recette de 6,4 s) ;
       le module ne nomme aucun objet (relu comme texte) ;
    §8 branchement : A.sized d'une fonderie suit la banque (données du jeu : M.spec, M.RECIPES), jamais plus de fours
       que le flux n'en nourrit ; déterminisme ;
    §9 MUTANTS : 19 altérations du code source, chacune vue par au moins un contrôle.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC : " .. msg) end
  end
  return cond
end
local function section(name) if not quiet then print("== " .. name) end end
local function near(a, b, tol) return math.abs(a - b) <= (tol or 1e-6) end

local SRC_PATH = "shared/team/banque_fours.lua"

--- Toute la suite, contre un module `B` (le vrai, ou un mutant). Rend rien : compte dans passes/failures.
local function suite(B, full)
  ---------------------------------------------------------------------------------------------------
  section("1. Débit d'un four")
  ---------------------------------------------------------------------------------------------------
  local stone = { speed = 1, time = 3.2, fuel_kw = 90, fuel_kj = 4000, size = 2 }
  local steel = { speed = 2, time = 3.2, fuel_kw = 90, fuel_kj = 4000, size = 2 }
  local elec = { speed = 2, time = 3.2, fuel_kw = 0, size = 3 }
  local f1 = B.furnace(stone)
  check(near(f1.rate, 0.3125) and near(f1.fuel, 0.0225), "four de pierre : 0,3125 minerai/s et 0,0225 combustible/s")
  local f2 = B.furnace(steel)
  check(near(f2.rate, 0.625) and near(f2.fuel, 0.0225), "four d'acier : 0,625 minerai/s")
  local f3 = B.furnace(elec)
  check(near(f3.rate, 0.625) and f3.fuel == 0, "four électrique : aucun combustible")
  local f4 = B.furnace({ speed = 2, time = 3.2, fuel_kw = 90, fuel_kj = 4000, arm_out = 0.5 })
  check(near(f4.rate, 0.5) and f4.fuel < 0.0225 and near(f4.fuel, 0.0225 * 0.5 / 0.625), "bras de sortie limitant : débit réduit, combustible au prorata")
  local f5 = B.furnace({ speed = 2, time = 3.2, fuel_kw = 90, fuel_kj = 4000, arm_in = 0.4 })
  check(f5.rate < 0.4 and f5.rate > 0.3, "bras d'entrée limitant : il porte minerai ET combustible")

  ---------------------------------------------------------------------------------------------------
  section("2. Nombre de fours")
  ---------------------------------------------------------------------------------------------------
  check(B.count(0, 0.3) == 0, "flux nul : aucun four")
  check(B.count(0.01, 0.3125) == 1, "un filet de minerai : un four")
  check(B.count(2.5, 0.3125) == 7, "2,5/s sur des fours de pierre : 7 (⌈0,85 × 8⌉), pas 8")
  check(B.count(0.3125, 0.3125) == 1 and B.count(0.625, 0.3125) == 2, "exactement 1 et 2 fours de flux")
  check(B.count(1, nil) == nil, "four sans débit : refusé")
  check(B.count(2.5, 0.3125, 1.0) == 8 and B.count(2.5, 0.3125, 0.5) == 4, "couverture demandée : 100 % donne 8 fours, 50 % donne 4")
  -- balayage : couverture atteinte, un four de moins ne la donne pas, charge du dernier four
  local sweep_bad, sweep_n = 0, 0
  local kinds = { stone, steel, elec, { speed = 1.5, time = 6.4, fuel_kw = 0 }, { speed = 4, time = 3.2, fuel_kw = 180, fuel_kj = 4000 } }
  for _, fk in ipairs(kinds) do
    local fr = B.furnace(fk)
    for i = 1, 400 do
      local flow = i * fr.rate / 12 -- 1/12 de four à 33 fours
      local n = B.count(flow, fr.rate, 0.85)
      sweep_n = sweep_n + 1
      local minimal = n * fr.rate >= 0.85 * flow - 1e-9 and (n == 1 or (n - 1) * fr.rate < 0.85 * flow - 1e-9)
      if not minimal then sweep_bad = sweep_bad + 1 end
      -- aucun four affamé : le plan complet, voies larges
      local plan = B.plan({ flow = flow, furnace = fk, lane = 1000, max_rows = 100 })
      local viol = plan and B.check(plan, { lane = 1000, max_rows = 100 }) or { "plan nil" }
      if #viol > 0 then
        sweep_bad = sweep_bad + 1
        if sweep_bad < 4 and not quiet then print("    flux " .. flow .. " : " .. table.concat(viol, ", ")) end
      end
    end
  end
  check(sweep_bad == 0, string.format("balayage %d cas : n minimal pour la couverture ET aucun four affamé (%d en défaut)", sweep_n, sweep_bad))

  ---------------------------------------------------------------------------------------------------
  section("3. Force brute des banques")
  ---------------------------------------------------------------------------------------------------
  local bank_bad, bank_n = 0, 0
  local function feasible(k, rate, fuel, lane, max_rows)
    local rows = math.floor((k + 1) / 2)
    local lanes_ore = fuel > 1e-9 and 1 or 2
    local cap = lane * 0.9
    return rows <= max_rows and k * rate <= lanes_ore * cap + 1e-9 and k * fuel <= cap + 1e-9 and rows * rate <= cap + 1e-9
  end
  for _, fk in ipairs(kinds) do
    for _, lane in ipairs({ 7.5, 3, 15 }) do
      for _, max_rows in ipairs({ 2, 3, 5, 12 }) do
        local fr = B.furnace(fk)
        local cap = B.bank_cap(fr, { lane = lane, max_rows = max_rows })
        -- plus grande banque admissible, par énumération
        local want_cap = 0
        for k = 1, 60 do if feasible(k, fr.rate, fr.fuel, lane, max_rows) then want_cap = k end end
        bank_n = bank_n + 1
        if cap ~= want_cap then bank_bad = bank_bad + 1 end
        -- compositions : DP (banques, plus grande banque) lexicographique minimal
        for n = 1, 26 do
          local best = { [0] = { 0, 0 } }
          for m = 1, n do
            local b
            for k = 1, m do
              if feasible(k, fr.rate, fr.fuel, lane, max_rows) and best[m - k] then
                local c = { best[m - k][1] + 1, math.max(k, best[m - k][2]) }
                if not b or c[1] < b[1] or (c[1] == b[1] and c[2] < b[2]) then b = c end
              end
            end
            best[m] = b
          end
          local sizes = B.banks(n, cap)
          bank_n = bank_n + 1
          if best[n] == nil then
            if sizes ~= nil then bank_bad = bank_bad + 1 end
          else
            local sum, mx, okp = 0, 0, sizes ~= nil
            for _, k in ipairs(sizes or {}) do
              sum = sum + k; mx = math.max(mx, k)
              if not feasible(k, fr.rate, fr.fuel, lane, max_rows) then okp = false end
            end
            if not (okp and sum == n and #sizes == best[n][1] and mx == best[n][2]) then
              bank_bad = bank_bad + 1
              if bank_bad < 4 and not quiet then print(string.format("    n=%d cap=%d : %s contre %d banques de %d au plus", n, cap, table.concat(sizes or {}, "+"), best[n][1], best[n][2])) end
            end
          end
        end
      end
    end
  end
  check(bank_bad == 0, string.format("banques : %d cas contre la force brute (moins de banques, puis plus petite banque, toutes admissibles), %d écart(s)", bank_n, bank_bad))
  check(B.bank_cap(B.furnace({ speed = 1, time = 3.2, fuel_kw = 90, fuel_kj = 4000 }), { lane = 0.1, max_rows = 12 }) == 0,
    "voie trop étroite pour un seul four : aucune banque")
  local plan_none = B.plan({ flow = 5, furnace = stone, lane = 0.1 })
  check(plan_none == nil, "plan refusé (nil) quand aucune banque n'est possible")
  -- Cas du gabarit actuel : fours de pierre, voie de 7,5, hauteur 12 rangées : 1 banque de 24 fours (3,75 à 7,5 minerai/s)
  local p24 = B.plan({ flow = 6.9, furnace = stone })
  check(p24 and p24.n == 19 and #p24.banks == 1 and p24.banks[1].rows == 10, "6,9 minerai/s sur des fours de pierre : 19 fours (⌈0,85 × 22,08⌉), 1 banque de 10 rangées")
  local p48 = B.plan({ flow = 12, furnace = stone })
  check(p48 and #p48.banks >= 2 and B.check(p48, {}) and #B.check(p48, {}) == 0, "12 minerai/s : plusieurs banques, contraintes tenues")

  ---------------------------------------------------------------------------------------------------
  section("4. Force brute des répartiteurs")
  ---------------------------------------------------------------------------------------------------
  local al_bad, al_n = 0, 0
  -- jeux de cas déterministes : lignes entières, total multiple de 4
  local line_sets = { { 4 }, { 2, 2 }, { 3, 1 }, { 4, 4 }, { 5, 3 }, { 2, 3, 3 }, { 8 } }
  local cons_sets = {
    { { id = "a", demand = 1, priority = 1 } },
    { { id = "a", demand = 3, priority = 2 }, { id = "b", demand = 2, priority = 1 } },
    { { id = "a", demand = 9, priority = 1, share_max = 0.5 }, { id = "b", demand = 2, priority = 1 } },
    { { id = "z", demand = 2, priority = 1 }, { id = "y", demand = 2, priority = 1 }, { id = "x", demand = 2, priority = 2 } },
    { { id = "a", demand = 0, priority = 1 }, { id = "b", demand = 4, priority = 3, share_max = 0.25 } },
  }
  for _, lines in ipairs(line_sets) do
    local total = 0
    for _, f in ipairs(lines) do total = total + f end
    if total % 4 == 0 then
      for _, cons in ipairs(cons_sets) do
        for _, reserve in ipairs({ 0, 0.25, 0.5, 1 }) do
          local res = B.allocate(lines, cons, reserve, true)
          al_n = al_n + 1
          -- force brute : toutes les prises entières, maximum lexicographique par (priorité, id)
          local order = {}
          for i, c in ipairs(cons) do order[i] = c end
          table.sort(order, function(a, b) if a.priority ~= b.priority then return a.priority < b.priority end return a.id < b.id end)
          local wants = {}
          for i, c in ipairs(order) do
            local w = c.demand
            if c.share_max then w = math.min(w, c.share_max * total) end
            wants[i] = math.floor(w + 1e-9)
          end
          local allowance = math.floor(total * (1 - reserve) + 1e-9)
          local bestv
          local cur = {}
          local function rec(i, used)
            if i > #order then
              local better = false
              if not bestv then better = true else
                for j = 1, #order do
                  if cur[j] ~= bestv[j] then better = cur[j] > bestv[j]; break end
                end
              end
              if better then bestv = { table.unpack(cur) } end
              return
            end
            for t = 0, wants[i] do
              if used + t <= allowance then cur[i] = t; rec(i + 1, used + t) end
            end
          end
          rec(1, 0)
          local ok = true
          local got_sum = 0
          for i, c in ipairs(order) do
            local t = res.takes[i]
            if t.id ~= c.id or not near(t.take, bestv[i]) then ok = false end
            got_sum = got_sum + t.take
            local ps = 0
            for _, p in ipairs(t.parts) do ps = ps + p.flow; if p.flow > lines[p.line] + 1e-9 then ok = false end end
            if not near(ps, t.take) then ok = false end
          end
          if not near(got_sum + res.main_total, total) then ok = false end
          if res.main_total + 1e-9 < total * reserve and #cons > 0 and got_sum > 0 then ok = false end
          if not ok then
            al_bad = al_bad + 1
            if al_bad < 4 and not quiet then print("    allocation différente de la force brute : lignes " .. table.concat(lines, ",") .. " réserve " .. reserve) end
          end
        end
      end
    end
  end
  check(al_bad == 0, string.format("répartiteurs : %d cas contre la force brute (maximum lexicographique, flux conservé, réserve), %d écart(s)", al_n, al_bad))
  -- Pas d'ultra-maximisation : un consommateur gourmand ne prend jamais plus que sa part maximale ni la réserve
  local greedy = B.allocate({ 5, 5 }, { { id = "gears", demand = 100, priority = 1, share_max = 0.4 } }, 0.3, true)
  check(near(greedy.takes[1].take, 4) and near(greedy.main_total, 6), "consommateur gourmand : borné à 40 % du total (4 sur 10), 6 restent")
  local greedy2 = B.allocate({ 5, 5 }, { { id = "gears", demand = 100, priority = 1 } }, 0.3, true)
  check(near(greedy2.takes[1].take, 7) and near(greedy2.main_total, 3), "sans part maximale, la réserve de 30 % protège quand même la ligne principale")
  local none = B.allocate({ 5, 5 }, { { id = "gears", demand = 3, priority = 1 } }, 0, false)
  check(none.takes[1].take == 0 and none.splitters == 0 and near(none.main_total, 10) and near(none.takes[1].short, 3),
    "répartiteur non débloqué : aucune prise, tout reste sur la ligne principale, manque signalé")
  local pr = B.allocate({ 4 }, { { id = "b", demand = 3, priority = 2 }, { id = "a", demand = 3, priority = 1 } }, 0, true)
  check(near(pr.takes[1].take, 3) and pr.takes[1].id == "a" and near(pr.takes[2].take, 1), "priorité : le premier servi prend sa demande, le suivant le reste")
  local two = B.allocate({ 2, 2 }, { { id = "a", demand = 3, priority = 1 } }, 0, true)
  check(two.splitters == 2 and #two.takes[1].parts == 2, "une prise de 3 sur deux lignes de 2 : deux répartiteurs")

  ---------------------------------------------------------------------------------------------------
  section("5. Simulation tick par tick")
  ---------------------------------------------------------------------------------------------------
  --- Banque de k fours (durée D ticks par minerai), x fours-équivalents de minerai qui arrivent : charge de chaque four.
  local function simulate(k, x, D, ticks)
    local busy = {}
    local left = {}
    for j = 1, k do busy[j] = 0; left[j] = 0 end
    local pool = 0
    local inflow = x / D
    local rows = math.floor((k + 1) / 2)
    for t = 1, ticks do
      pool = pool + inflow
      for r = 1, rows do
        local m = (r == rows and k % 2 == 1) and 1 or 2
        for q = 0, m - 1 do
          local j = 2 * r - 2 + 1 + ((q + t) % m) -- les deux fours d'une rangée se relaient pour piocher
          if left[j] == 0 and pool >= 1 then pool = pool - 1; left[j] = D end
        end
      end
      for j = 1, k do
        if left[j] > 0 then left[j] = left[j] - 1; busy[j] = busy[j] + 1 end
      end
    end
    local out = {}
    for j = 1, k do out[j] = busy[j] / ticks end
    return out
  end
  -- B.loads est une BORNE PESSIMISTE (amont saturé d'abord) : un tapis clairsemé répartit plus également (file commune).
  -- Contrôles : (a) le débit total simulé vaut min(x, k) ; (b) la rangée la moins servie de la simulation n'est jamais
  -- moins chargée que celle du modèle (à 0,05 près) ; (c) à l'excès de minerai, tous saturent.
  local sim_bad, sim_n = 0, 0
  local ticks = full and 9600 or 4800
  for _, k in ipairs({ 1, 2, 3, 4, 5, 6, 7 }) do
    for _, x in ipairs({ 0.6, 1.2, 1.9, 2.4, 3.3, 4.5, 5.9, 6.8, 9 }) do
      local sim = simulate(k, x, 192, ticks)
      local model = B.loads(x, k)
      -- charge d'une RANGÉE (moyenne de ses un ou deux fours) : le partage entre les deux fours d'une rangée dépend de
      -- l'ordre de mise à jour du moteur (non mesuré), il n'est pas garanti ; la rangée l'est.
      local s_sum, s_min, m_min, m_sum = 0, 1, 1, 0
      for r = 1, math.floor((k + 1) / 2) do
        local m = (r == math.floor((k + 1) / 2) and k % 2 == 1) and 1 or 2
        local ss, mm = 0, 0
        for q = 1, m do ss = ss + sim[2 * r - 2 + q]; mm = mm + model[2 * r - 2 + q] end
        s_sum = s_sum + ss; m_sum = m_sum + mm
        s_min = math.min(s_min, ss / m); m_min = math.min(m_min, mm / m)
      end
      sim_n = sim_n + 1
      local ok = math.abs(s_sum - math.min(x, k)) <= 0.04 * k + 0.02 and math.abs(m_sum - math.min(x, k)) <= 1e-9 and s_min >= m_min - 0.05
      if x >= k + 0.5 then ok = ok and s_min >= 0.95 end
      if not ok then
        sim_bad = sim_bad + 1
        if sim_bad < 4 and not quiet then print(string.format("    k=%d x=%.1f : simulé somme %.3f min %.3f ; modèle somme %.3f min %.3f", k, x, s_sum, s_min, m_sum, m_min)) end
      end
    end
  end
  check(sim_bad == 0, string.format("%d banques simulées (k de 1 à 7, flux de 0,6 à 9 fours) : débit total conservé, rangée la moins servie jamais sous la borne du modèle, %d écart(s)", sim_n, sim_bad))
  -- le four le moins servi d'un plan : simulé ≥ B.LOAD_MIN - tolérance, pour 60 flux
  local worst, wb = 1, 0
  for i = 1, 60 do
    local flow = i * 0.0937
    local plan = B.plan({ flow = flow, furnace = stone, lane = 1000, max_rows = 100 })
    local bk = plan.banks[1]
    local sim = simulate(bk.k, flow / 0.3125, 192, ticks)
    local mn = 1
    for r = 1, math.floor((bk.k + 1) / 2) do
      local m = (r == math.floor((bk.k + 1) / 2) and bk.k % 2 == 1) and 1 or 2
      local ss = 0
      for q = 1, m do ss = ss + sim[2 * r - 2 + q] end
      mn = math.min(mn, ss / m)
    end
    if plan.n >= 2 then
      worst = math.min(worst, mn)
      if mn < B.LOAD_MIN - 0.05 then wb = wb + 1 end
    end
  end
  check(wb == 0, string.format("60 plans simulés : la rangée la moins servie charge à %.2f au pire (seuil %.2f), %d en défaut", worst, B.LOAD_MIN, wb))

  ---------------------------------------------------------------------------------------------------
  section("6. Disposition")
  ---------------------------------------------------------------------------------------------------
  local lay_bad = 0
  for _, nrows in ipairs({ 1, 2, 4, 6 }) do
    for _, east in ipairs({ 0, 1 }) do
      local bk = { rows = nrows, west = nrows, east = nrows - east, k = 2 * nrows - east }
      for _, sp in ipairs({ { 0, 0 }, { 1, 0 }, { 2, 2 }, { 3, 1 } }) do
        for _, sz in ipairs({ 2, 3 }) do
          local lay = B.layout(bk, sz, sp)
          if #B.layout_overlaps(lay) > 0 then lay_bad = lay_bad + 1 end
          local maxy = 0
          for _, r in ipairs(lay.rects) do maxy = math.max(maxy, r.y + r.h) end
          if maxy ~= lay.h then lay_bad = lay_bad + 1 end
          if lay.h ~= nrows * sz + 2 * math.max(sp[1], sp[2]) then lay_bad = lay_bad + 1 end
        end
      end
    end
  end
  check(lay_bad == 0, "disposition : aucune pièce ne se recouvre, hauteur = rangées × côté + 2 par répartiteur (96 cas)")
  local lay2 = B.layout({ rows = 3, west = 3, east = 3, k = 6 }, 2, { 1, 1 })
  local nspl = 0
  for _, r in ipairs(lay2.rects) do if r.kind == "repartiteur" then nspl = nspl + 1; check(r.w == 2 and r.h == 1, "répartiteur 2 × 1") end end
  check(nspl == 2 and lay2.x0 == -1 and lay2.x1 == 7 + 4 + 1, "deux répartiteurs, un de chaque côté, hors de la colonne des fours")
  -- la disposition fautive est vue
  local bad_lay = { w = 5, h = 5, rects = { { kind = "a", x = 0, y = 0, w = 2, h = 2 }, { kind = "b", x = 1, y = 1, w = 2, h = 2 } } }
  check(#B.layout_overlaps(bad_lay) == 1, "témoin : deux pièces qui se recouvrent sont comptées")
  local tall = B.plan({ flow = 3.0, furnace = stone, consumers = { { id = "a", demand = 0.1, priority = 1 }, { id = "b", demand = 0.1, priority = 2 }, { id = "c", demand = 0.1, priority = 3 }, { id = "d", demand = 0.1, priority = 4 } }, splitter = true, max_rows = 6, side = 14 })
  check(tall and tall.height and tall.height > 0, "hauteur calculée pour le plan")
  local h_ok = B.plan({ flow = 3.0, furnace = stone, splitter = true, max_rows = 6 })
  check(h_ok and h_ok.height == h_ok.banks[1].rows * 2, "sans prise, la hauteur est celle des rangées de fours")
  local warned = false
  for _, w in ipairs(tall.warnings) do if w == "hauteur de lot depassee" then warned = true end end
  check((tall.height > 14) == warned, "dépassement de la hauteur de lot signalé exactement quand il a lieu")

  ---------------------------------------------------------------------------------------------------
  section("7. Généralisation")
  ---------------------------------------------------------------------------------------------------
  -- un four électrique de vitesse 4 sur une recette de 6,4 s (0,625/s), tapis rapide (voie de 15)
  local future = { speed = 4, time = 6.4, fuel_kw = 0, size = 4 }
  local pf = B.plan({ flow = 10, furnace = future, lane = 15, max_rows = 6, consumers = { { id = "q", demand = 3, priority = 1, share_max = 0.5 } }, reserve = 0.2, splitter = true, side = 24 })
  check(pf and pf.n == 14 and #B.check(pf, { lane = 15, max_rows = 6, reserve = 0.2 }) == 0,
    "four électrique inventé : 10/s sur des fours de 0,625/s → 14 fours (⌈0,85 × 16⌉), contraintes tenues")
  check(pf and pf.banks[1].k * 0.625 <= 2 * 15 * 0.9 + 1e-9, "four électrique : les deux voies portent du minerai (pas de combustible)")
  local pf_fuel = B.plan({ flow = 10, furnace = { speed = 4, time = 6.4, fuel_kw = 300, fuel_kj = 4000, size = 4 }, lane = 15, max_rows = 6 })
  check(pf_fuel and pf_fuel.banks[1].k * 0.625 <= 15 * 0.9 + 1e-9, "le même four à combustible : une seule voie de minerai")
  -- le module ne nomme aucun objet du jeu
  local fh = io.open(SRC_PATH, "rb")
  local text = fh and fh:read("*a") or ""
  if fh then fh:close() end
  local code = text:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  local named = {}
  for str in code:gmatch('"([^"\n]*)"') do
    for _, w in ipairs({ "furnace", "iron", "copper", "plate", "gear", "stone", "coal", "belt", "splitter", "inserter", "ore" }) do
      if str:find(w, 1, true) then named[#named + 1] = w .. " dans \"" .. str .. "\"" end
    end
  end
  check(#named == 0 and #text > 1000, "aucune chaîne de shared/team/banque_fours.lua ne nomme un objet du jeu (" .. table.concat(named, ", ") .. ")")
end

---------------------------------------------------------------------------------------------------
-- Charge du module réel et suite complète
---------------------------------------------------------------------------------------------------
local Real = require("shared.team.banque_fours")
suite(Real, true)

---------------------------------------------------------------------------------------------------
section("8. Branchement : dimensionnement des fonderies (A.sized) et déterminisme")
---------------------------------------------------------------------------------------------------
do
  local A = require("shared.ai3.automatiser")
  local M = require("shared.team.modules")
  A.reset_cache()
  local meth = A.METHODS[1]
  check(meth.product ~= nil and meth.bank ~= nil, "la méthode de fonderie déclare sa banque (indices de ses paramètres, données nommées)")
  -- jamais plus de fours que le flux n'en nourrit : pour chaque débit demandé, la fonderie dimensionnée a une couverture
  -- ≥ B.COVER et ne dépasse pas ⌈couverture/2⌉ + 1 paires (arrondi de la symétrie)
  local bad, nn = 0, 0
  local sp = M.spec(meth.args[1])
  local r = sp.speed / M.RECIPES[meth.product].time
  for rate = 15, 240, 15 do -- plaques/min
    local g, args = A.sized(meth, rate)
    if g then
      nn = nn + 1
      local furn = 2 * args[g.ext.arg]
      local flow = rate / 60
      local want = Real.count(flow, r, Real.COVER)
      if furn ~= 2 * Real.pairs(want) then bad = bad + 1; if not quiet then print("    débit " .. rate .. "/min : " .. furn .. " fours au lieu de " .. 2 * Real.pairs(want)) end end
      -- jamais un four affamé de plus que la symétrie n'impose
      if furn - want > 1 then bad = bad + 1 end
    end
  end
  check(nn >= 10 and bad == 0, string.format("A.sized suit la banque : %d débits de 15 à 240 plaques/min, %d écart(s)", nn, bad))
  -- déterminisme
  local g1, a1 = A.sized(meth, 90)
  A.reset_cache()
  local g2, a2 = A.sized(meth, 90)
  check(g1 and g2 and a1[3] == a2[3] and g1.n_ent == g2.n_ent, "deux dimensionnements identiques donnent le même gabarit")
  -- généralisation : une méthode « banque » dont le four et la recette sont autres (données nommées changées)
  local fake = { product = meth.product, gen = meth.gen, args = { "fo-lvl-furnace-12", meth.args[2], 1 }, ore = meth.ore, feed = meth.feed, bank = meth.bank }
  A.reset_cache()
  local gf, af = A.sized(fake, 150)
  local spf = M.spec("fo-lvl-furnace-12")
  if gf and spf then
    local rf = spf.speed / M.RECIPES[meth.product].time
    local wantf = Real.pairs(Real.count(150 / 60, rf, Real.COVER))
    check(af[3] == math.min(wantf, gf.ext.max), "un autre niveau de four (vitesse " .. string.format("%.1f", spf.speed) .. ") : la banque est redimensionnée à " .. af[3] .. " paire(s)")
  else
    check(false, "niveau de four 12 introuvable pour la généralisation")
  end
end

---------------------------------------------------------------------------------------------------
section("9. Mutants")
---------------------------------------------------------------------------------------------------
do
  local fh = assert(io.open(SRC_PATH, "rb"))
  local text = fh:read("*a")
  fh:close()
  local MUT = {
    { "B.COVER = 0.85", "B.COVER = 0.5", "couverture trop basse" },
    { "local function ceil_eps(x) return math.ceil(x - B.EPS) end", "local function ceil_eps(x) return math.floor(x) end", "arrondi au-dessous" },
    { "B.MARGIN = 0.9", "B.MARGIN = 1.3", "marge de voie perdue" },
    { "local lanes_ore = (fr.fuel > B.EPS) and 1 or 2", "local lanes_ore = (fr.fuel > B.EPS) and 2 or 1", "voies de minerai inversées" },
    { "for k = 1, 2 * max_rows do", "for k = 1, max_rows do", "banque : recherche trop courte" },
    { "(i <= extra and 1 or 0)", "(i <= extra and 0 or 0)", "banques déséquilibrées" },
    { "if pa ~= pb then return pa < pb end", "if pa ~= pb then return pa > pb end", "priorité inversée" },
    { "if c.share_max then want", "if false then want", "part maximale ignorée" },
    { "local allowance = total * (1 - math.min(1, math.max(0, reserve or 0)))", "local allowance = total", "réserve ignorée" },
    { "left[i] = left[i] - part", "left[i] = left[i]", "flux non retiré de la ligne" },
    { "local take = math.min(m, math.max(0, left))", "local take = m", "rangées jamais en manque" },
    { "local room = f.arm_in - fuel * (rate / raw)", "local room = f.arm_in", "bras d'entrée sans combustible" },
    { "if available ~= false then take", "if true then take", "répartiteur non débloqué utilisé" },
    { "add(\"repartiteur\", math.min(inner, outer), H + 2 * j, 2, 1)", "add(\"repartiteur\", math.min(inner, outer), H + j, 2, 1)", "répartiteurs trop serrés" },
    { "local n = ceil_eps((cover or B.COVER) * flow / rate)", "local n = ceil_eps(B.COVER * flow / rate)", "couverture demandée ignorée" },
    { "and rows * fr.rate <= lane + B.EPS", "and true", "voie de sortie ignorée" },
    { "plan.lines[#plan.lines + 1] = w_sum * fr.rate", "plan.lines[#plan.lines + 1] = tot * fr.rate", "ligne de sortie fausse" },
    { "B.LOAD_MIN = 0.3", "B.LOAD_MIN = 0.9", "seuil de charge trop haut" },
    { "rec.short = math.max(0, math.max(0, c.demand or 0) - rec.take)", "rec.short = 0", "manque jamais signalé" },
  }
  local caught = 0
  for _, m in ipairs(MUT) do
    local a, b = text:find(m[1], 1, true)
    if not a then
      check(false, "mutant introuvable dans le source : " .. m[3])
    else
      local src = text:sub(1, a - 1) .. m[2] .. text:sub(b + 1)
      local fn, err = load(src, "=mutant", "t")
      if not fn then
        check(false, "mutant mal formé : " .. m[3] .. " (" .. tostring(err) .. ")")
      else
        local ok, Mut = pcall(fn)
        local p0, f0 = passes, failures
        local q0 = quiet
        quiet = true
        local ok2 = pcall(suite, Mut, false)
        quiet = q0
        local detected = (not ok2) or failures > f0
        passes, failures = p0, f0 -- les contrôles des mutants ne comptent pas dans le bilan
        check(ok and detected, "mutant « " .. m[3] .. " » vu par la suite")
        if detected then caught = caught + 1 end
      end
    end
  end
  check(caught == #MUT, string.format("%d mutants sur %d détectés", caught, #MUT))
end

print(string.format("[FOURS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
