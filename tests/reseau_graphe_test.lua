--[[
  Lot RESEAU-GRAPHE : test hors jeu de la règle pure shared/team/reseau_graphe.lua (bus de produits entre blocs producteurs et quais).
    §1 constantes contre le plan directeur et la liaison de quai ; §2 trajets (Rg.leg) et prix contre Li.worth ; §3 balayage du tronc (sens,
    voie, part du QG) ; §4 composantes connexes (union-find, interdits, coupe) ; §5 choix sous k files (partage de tronc, budget, meilleur des
    trois ordres) ; §6 contre l'OPTIMUM par énumération (sous-ensembles de terminaux, sous-ensembles de bus) ; §7 déterminisme (ordre des
    listes) ; §8 travail découpé = travail d'un bloc, sans fonction ; §9 instance chiffrée de la sauvegarde du DC ; §10 aucun nom d'objet,
    aucun pairs, aucune API ; §11 coût en instructions (debug.sethook) ; §12 mutants : chaque règle cassée est vue.
  Usage : lua5.2 tests/reseau_graphe_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/reseau_graphe.lua")
local BUILD = read("script/team/build.lua")
local Li = require("shared.team.liaison")

local BUSSRC = read("shared/team/reseau_bus.lua") -- le bus d'une composante (suite du fichier principal, installé par require)
local function load_rg(src, bus)
  local saved = package.loaded["shared.team.reseau_bus"]
  local bfn, berr = load(bus or BUSSRC, "=reseau_bus", "t")
  assert(bfn, berr)
  package.loaded["shared.team.reseau_bus"] = bfn()
  local fn, err = load(src, "=reseau_graphe", "t")
  assert(fn, err)
  local ok, R = pcall(fn)
  package.loaded["shared.team.reseau_bus"] = saved
  assert(ok, R)
  return R
end

local function prod(key, item, x, y, rate) return { key = key, item = item, x = x, y = y, rate = rate } end
local cons = prod

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

-- sérialisation canonique d'un résultat (comparaison exacte)
local function ser(v)
  local t = type(v)
  if t == "table" then
    local out = {}
    for _, k in ipairs(sorted_keys(v)) do out[#out + 1] = tostring(k) .. "=" .. ser(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
  elseif t == "number" then
    return string.format("%.9g", v)
  end
  return tostring(v)
end

local function near(a, b, tol) return math.abs(a - b) <= (tol or 1e-6) end

---------------------------------------------------------------------------------------------------
-- LA SUITE (rejouée sur chaque mutant : `quick` saute les énumérations lourdes)
---------------------------------------------------------------------------------------------------
local function suite(Rg, quick, out)
  local ok_n, fail_n = 0, 0
  local failed = {}
  local function check(c, msg)
    if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 failed[#failed + 1] = msg if out then print("  ECHEC : " .. msg) end end
  end
  local HUB = { x = 0, y = 0 }
  local O0 = { hub = HUB, labor = Li.LABOR_VALUE, price = Li.PRICE, tmax = Li.TMAX }
  local function plan(P, C, extra)
    local inp = { producers = P, consumers = C, hub = HUB, hub_share = 0 }
    for k, v in pairs(extra or {}) do inp[k] = v end
    return Rg.plan(inp, extra and extra.dist_fn)
  end

  -- §1 constantes
  check(Rg.COLLECT_BATCH == tonumber(BUILD:match("Build%.COLLECT_AT = (%d+)")), "1.1 lot de collecte = Build.COLLECT_AT")
  check(Rg.FILL_BATCH == tonumber(BUILD:match("Build%.QUAI_FILL = (%d+)")) - tonumber(BUILD:match("Build%.QUAI_LOW = (%d+)")),
    "1.2 lot de remplissage = Build.QUAI_FILL - Build.QUAI_LOW (Li.worth : per_trip)")
  check(Rg.LANES_PER_BELT == 2 and Rg.BELTS >= 1, "1.3 une file de tapis a deux voies")
  check(Rg.LANE_CAP == 450 and Rg.ARM_RATE == 50, "1.4 voie 7,5/s, bras 0,83/s (objets/min)")
  check(Rg.LINK_R * Rg.DETOUR <= Rg.MAX_TRUNK, "1.5 deux terminaux liés tiennent toujours dans un tronc (LINK_R x détour <= MAX_TRUNK)")

  check(Rg.k_for(0, 1000) == 1 and Rg.k_for(5, 1000) == 2 and Rg.k_for(14, 10000) == 5 and Rg.k_for(14, 300) == 2 and Rg.k_for(9, 149) == 0 and Rg.k_for(nil, nil) == 0,
    "1.6 k selon l'époque (une file de plus toutes les 3 époques) et le stock de tapis (150 tuiles par file)")
  check(Rg.k_for(2, 1e9) == 1 and Rg.k_for(3, 1e9) == 2, "1.7 le palier d'époque change à l'époque 3")

  -- §2 trajets et prix
  check(near(Rg.leg(60, 200), (2 * 60 / Li.WALK + Li.HANDLE_S) / 200), "2.1 leg = (2 d / marche + prise) / lot")
  check(Rg.leg(100, 340) > Rg.leg(10, 340) and Rg.leg(60, 200) > Rg.leg(60, 400), "2.2 plus loin coûte plus, un lot plus gros coûte moins par objet")
  -- une paire : producteur AU QG, consommateur à 56 tuiles : le gain « quai » est celui de Li.worth (mêmes trajets de remplissage)
  do
    local r = plan({ prod("p", "X", 0, 0, 100) }, { cons("c", "X", 56, 0, 60) })
    check(#r.buses == 1 and r.buses[1].served == 60, "2.3 une paire : un bus, 60 objets/min servis")
    local dock_gain = r.buses[1].gain - r.buses[1].served * Rg.leg(0, Rg.COLLECT_BATCH)
    local _, _, det = Li.worth({ flow = 60 / 60, dist = 56, span = 56, fill = 400, low = 60, tiles = r.buses[1].tiles })
    check(near(dock_gain, det.labor_s_min, 1e-6), "2.4 gain du quai = PNJ-s/min économisées de Li.worth (" .. string.format("%.4f", dock_gain) .. " contre " .. string.format("%.4f", det.labor_s_min) .. ")")
  end

  -- §3 balayage du tronc
  do
    local r = plan({ prod("p", "X", 0, 0, 100) }, { cons("c", "X", 50, 0, 80) })
    local b = r.buses[1]
    check(b and b.axis == "x" and b.sign == 1 and b.served == 80, "3.1 producteur à l'ouest, consommateur à l'est : axe x, sens +, 80 servis")
    local expect_tiles = math.ceil(50 * Li.EST_FACTOR) + 4
    check(b and b.tiles == expect_tiles and b.lo == 0 and b.hi == 50, "3.2 tuiles = ceil(portée x détour) + 2 par terminal (" .. tostring(b and b.tiles) .. " contre " .. expect_tiles .. ")")
    local expect_gain = 80 * (Rg.leg(50, Rg.FILL_BATCH) + Rg.leg(0, Rg.COLLECT_BATCH))
    check(b and near(b.gain, expect_gain), "3.3 gain = servi x (trajet de remplissage évité + trajet de collecte évité)")
  end
  do
    local r = plan({ prod("p", "X", 100, 0, 100) }, { cons("c", "X", 40, 0, 80) })
    check(r.buses[1] and r.buses[1].sign == -1 and r.buses[1].served == 80, "3.4 producteur à l'est : le bus roule vers l'ouest (sens -)")
  end
  do -- un consommateur EN AMONT du seul producteur ne reçoit rien et est écarté
    local r = plan({ prod("p", "X", 0, 0, 100) }, { cons("up", "X", -60, 0, 50), cons("down", "X", 60, 0, 50) })
    local b = r.buses[1]
    local has_up = false
    for _, t in ipairs(b and b.taps or {}) do if t.key == "up" then has_up = true end end
    check(b and b.served == 50 and not has_up, "3.5 consommateur en amont : rien reçu, absent du bus")
  end
  do -- le débit dans une voie est borné
    local P, C = {}, {}
    for i = 1, 4 do P[#P + 1] = prod("p" .. i, "X", i, 0, 200) end
    for i = 1, 4 do C[#C + 1] = cons("c" .. i, "X", 100 + i, 0, 200) end
    local r = plan(P, C, { k = 4 })
    local top, over = 0, false
    for _, b in ipairs(r.buses) do
      if b.served > top then top = b.served end
      if b.served > Rg.LANE_CAP + 1e-9 then over = true end
    end
    check(near(top, Rg.LANE_CAP) and not over, "3.6 quatre producteurs de 200 : une voie porte " .. Rg.LANE_CAP .. " objets/min au plus (" .. top .. ")")
  end
  do -- le terminal est borné à MAX_ARMS bras
    local r = plan({ prod("p", "X", 0, 0, 1000) }, { cons("c", "X", 30, 0, 1000) })
    check(r.buses[1] and r.buses[1].served == Rg.MAX_ARMS * Rg.ARM_RATE, "3.7 un coffre porte " .. Rg.MAX_ARMS * Rg.ARM_RATE .. " objets/min au plus (bras)")
  end
  do -- part du QG
    local r = Rg.plan({ producers = { prod("p", "X", 0, 0, 100) }, consumers = { cons("c", "X", 50, 0, 100) }, hub = HUB, hub_share = 0.4 })
    check(r.buses[1] and near(r.buses[1].served, 60), "3.8 40 % du débit de la sortie restent au QG : 60 servis")
    local r0 = Rg.plan({ producers = { prod("p", "X", 0, 0, 100) }, consumers = { cons("c", "X", 50, 0, 100) }, hub = HUB })
    check(r0.buses[1] and near(r0.buses[1].served, 100 * (1 - Rg.HUB_SHARE)), "3.9 part du QG par défaut = Rg.HUB_SHARE")
  end
  do -- tronc à la médiane : branches de 0, 0 et 30 -> tronc sur la médiane
    local r = plan({ prod("p", "X", 0, 40, 100) }, { cons("a", "X", 50, 40, 30), cons("b", "X", 60, 40, 30), cons("c", "X", 70, 34, 60) })
    local b = r.buses[1]
    check(b and b.line == 40 and #b.taps == 4, "3.10 tronc sur la médiane des coordonnées perpendiculaires (" .. tostring(b and b.line) .. ")")
  end
  do -- des égalités de position : producteur d'abord
    local r = plan({ prod("p", "X", 20, 0, 50) }, { cons("c", "X", 20, 0, 50), cons("d", "X", 80, 0, 50) })
    local served = 0
    for _, t in ipairs(r.buses[1] and r.buses[1].taps or {}) do if t.key == "c" then served = t.served end end
    check(served == 50, "3.11 à la même tuile, le producteur est en amont du consommateur")
  end
  do -- un bus qui ne se paie pas est refusé (débit minuscule, peu de trajets)
    local r = plan({ prod("p", "X", 0, 0, 3) }, { cons("c", "X", 90, 0, 3) })
    check(#r.buses == 0 and #r.stats.rejects == 1, "3.12 débit minuscule : le bus ne se paie pas")
    local near_q = plan({ prod("p", "X", 0, 0, 100) }, { cons("c", "X", 8, 0, 100) })
    local far_q = plan({ prod("p", "X", 0, 0, 100) }, { cons("c", "X", 80, 0, 100) })
    check(near_q.buses[1] and far_q.buses[1] and near_q.buses[1].gain < far_q.buses[1].gain, "3.13 un quai collé au QG économise moins de trajets qu'un quai loin")
  end
  do -- retour = coût / gain, sur l'horizon tmax
    local r = plan({ prod("p", "X", 60, 0, 100) }, { cons("c", "X", 160, 0, 100) })
    local b = r.buses[1]
    check(b and near(b.net, 90 * b.gain - b.payback_min * b.gain, 1e-6), "3.14 valeur nette = tmax x gain - coût (retour x gain)")
    check(b and b.payback_min <= Li.TMAX, "3.15 un bus gardé se paie en moins de Li.TMAX")
  end
  do -- ordre des prises : par contribution décroissante, puis par clé
    local r = plan({ prod("p", "X", 0, 0, 200) }, { cons("c1", "X", 50, 0, 150), cons("c2", "X", 80, 0, 30) })
    local t = r.buses[1] and r.buses[1].taps or {}
    check(#t == 3 and t[1].key == "p" and t[2].key == "c1" and t[3].key == "c2", "3.16 prises : le producteur, puis le gros consommateur, puis le petit")
    local r2 = plan({ prod("pa", "X", 0, 0, 100), prod("pb", "X", 0, 0, 100) }, { cons("c", "X", 60, 0, 150) })
    local t2 = r2.buses[1] and r2.buses[1].taps or {}
    check(#t2 >= 2 and t2[1].key == "c" and t2[2].key == "pa", "3.17 contributions égales : la plus petite clé d'abord (" .. tostring(t2[2] and t2[2].key) .. ")")
  end
  do -- composante résiduelle : deux grappes d'un même objet que le tronc ne peut pas joindre en un seul bus
    local r = plan({ prod("p1", "X", 0, 0, 100), prod("p2", "X", 150, 0, 100) }, { cons("c1", "X", 60, 0, 100), cons("c2", "X", 210, 0, 100) }, { k = 2 })
    local short = true
    for _, b in ipairs(r.buses) do if b.tiles - 2 * #b.taps > Rg.MAX_TRUNK then short = false end end
    check(#r.buses == 2 and r.buses[1].item == "X" and r.buses[2].item == "X" and r.stats.served >= 2 * 99.9 and short,
      "3.18 chaîne de 210 tuiles (> MAX_TRUNK avec détour) : deux bus du même objet, chacun dans la limite (" .. #r.buses .. ")")
  end

  do -- la croissance gloutonne rattrape un élagage coincé (fixture trouvée par recherche : élagage seul 59 % de l'optimum)
    local raw = { { "t01", "p", 116, 52, 46 }, { "t02", "c", 2, 12, 146 }, { "t03", "p", 16, 40, 68 }, { "t04", "p", 118, 52, 168 }, { "t05", "p", 82, 16, 112 },
      { "t06", "p", 88, 52, 38 }, { "t07", "p", 144, 4, 80 }, { "t08", "p", 2, 32, 110 }, { "t09", "p", 24, 12, 118 }, { "t10", "p", 6, 40, 74 } }
    local comp = {}
    for _, r in ipairs(raw) do
      comp[#comp + 1] = { key = r[1], kind = r[2], item = "X", x = r[3], y = r[4], rate = r[5], arms = math.ceil(r[5] / Rg.ARM_RATE),
        leg = Rg.leg(r[3] + r[4], r[2] == "p" and Rg.COLLECT_BATCH or Rg.FILL_BATCH) }
    end
    local O1 = { hub = HUB, labor = Li.LABOR_VALUE, price = Li.PRICE, tmax = Li.TMAX }
    local bus = Rg.bus_of(comp, O1)
    local I = Rg._internals
    local ax = I.axis_of(comp)
    local best = 0
    for mask = 1, 1023 do
      local S = {}
      for i = 1, 10 do if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then S[#S + 1] = comp[i] end end
      table.sort(S, I.along(ax))
      local e = I.evaluate(S, ax, O1)
      if e.trunk <= Rg.MAX_TRUNK and e.net > best then best = e.net end
    end
    check(bus and best > 0 and bus.net >= 0.98 * best, "3.19 dix terminaux : le bus égale l'optimum énuméré à 2 % près (" .. string.format("%.0f / %.0f", bus and bus.net or 0, best) .. ")")
  end

  do -- un consommateur de plus aurait payé, mais le tronc dépasserait MAX_TRUNK : refusé
    local r = plan({ prod("p", "X", 0, 0, 200) }, { cons("c1", "X", 100, 0, 100), cons("c2", "X", 250, 0, 100) }, { k = 1 })
    local b = r.buses[1]
    check(b and b.tiles - 2 * #b.taps <= Rg.MAX_TRUNK, "3.20 le tronc d'un bus ne dépasse jamais MAX_TRUNK, même si un terminal de plus rapporterait (" .. tostring(b and b.tiles) .. " tuiles)")
  end

  -- §4 composantes
  do
    local ts = {}
    local function t(k, x, y) ts[#ts + 1] = { key = k, kind = "p", x = x, y = y } end
    t("a", 0, 0) t("b", 100, 0) t("c", 200, 0) t("d", 600, 0) t("e", 650, 0)
    local comps = Rg.components(ts)
    check(#comps == 2 and #comps[1] == 3 and #comps[2] == 2, "4.1 chaîne a-b-c (pas de 100 <= LINK_R) puis d-e : deux composantes")
    local forbid = Rg.components(ts, function(a, b) if (a.key == "b" and b.key == "c") then return nil end return math.abs(a.x - b.x) + math.abs(a.y - b.y) end)
    check(#forbid == 3, "4.2 liaison interdite par le crochet (nil) : la chaîne se coupe (" .. #forbid .. " composantes)")
    local long = Rg.components(ts, function(a, b) return 1e9 end)
    check(#long == 5, "4.3 crochet trop long : cinq composantes isolées")
  end
  do -- coupe des grosses composantes
    local P, C = {}, {}
    for i = 1, 30 do P[#P + 1] = prod("p" .. string.format("%02d", i), "X", (i - 1) * 3, 0, 20) end
    for i = 1, 30 do C[#C + 1] = cons("c" .. string.format("%02d", i), "X", 90 + (i - 1) * 3, 0, 20) end
    local job = Rg.begin({ producers = P, consumers = C, hub = HUB, hub_share = 0 })
    Rg.step(job, nil)
    check(job.n_comp >= 2, "4.4 60 terminaux > N_MAX : coupés en au moins 2 composantes (" .. job.n_comp .. ")")
  end

  -- §5 choix sous k files
  local function two_items(k, extra)
    local P = { prod("pa", "A", 0, 0, 100), prod("pb", "B", 0, 4, 100) }
    local C = { cons("ca", "A", 90, 0, 100), cons("cb", "B", 90, 4, 100) }
    local inp = { producers = P, consumers = C, hub = HUB, hub_share = 0, k = k }
    for kk, v in pairs(extra or {}) do inp[kk] = v end
    return Rg.plan(inp)
  end
  do
    local r1 = two_items(1)
    check(#r1.buses == 2 and #r1.belts == 1 and #r1.belts[1].lanes == 2, "5.1 deux objets sur la même rue et le même sens partagent UNE file (deux voies)")
    local solo = Rg.plan({ producers = { prod("pa", "A", 0, 0, 100) }, consumers = { cons("ca", "A", 90, 0, 100) }, hub = HUB, hub_share = 0 })
    local shared_bus = r1.buses[2]
    check(shared_bus.shared_tiles > 0 and shared_bus.plaques < solo.buses[1].plaques, "5.2 le tronc recouvert n'est payé qu'une fois (" .. shared_bus.shared_tiles .. " tuiles)")
    check(r1.stats.tiles == r1.buses[1].tiles + r1.buses[2].tiles - shared_bus.shared_tiles, "5.3 tuiles du total = somme - recouvrement")
  end
  do
    local r = Rg.plan({ producers = { prod("pa", "A", 0, 0, 100), prod("pb", "B", 0, 4, 100) }, consumers = { cons("ca", "A", 90, 0, 100), cons("cb", "B", 90, 4, 100) },
      hub = HUB, hub_share = 0, k = 1 })
    check(#r.belts == 1, "5.4 (contrôle) deux objets distincts : une file")
    -- deux composantes du MÊME objet ne se partagent pas une file
    local R2 = Rg.plan({ producers = { prod("pa", "A", 0, 0, 100), prod("pb", "A", 0, 400, 100) }, consumers = { cons("ca", "A", 90, 0, 100), cons("cb", "A", 90, 400, 100) },
      hub = HUB, hub_share = 0, k = 1 })
    check(#R2.buses == 1, "5.5 k = 1 et deux composantes d'un même objet éloignées : un seul bus")
  end
  do
    -- sens opposé : pas de partage
    local r = Rg.plan({ producers = { prod("pa", "A", 0, 0, 100), prod("pb", "B", 90, 4, 100) }, consumers = { cons("ca", "A", 90, 0, 100), cons("cb", "B", 0, 4, 100) },
      hub = HUB, hub_share = 0, k = 1 })
    check(#r.buses == 1, "5.6 sens opposés : une seule file, un seul bus gardé (k = 1)")
    local r2 = Rg.plan({ producers = { prod("pa", "A", 0, 0, 100), prod("pb", "B", 90, 4, 100) }, consumers = { cons("ca", "A", 90, 0, 100), cons("cb", "B", 0, 4, 100) },
      hub = HUB, hub_share = 0, k = 2 })
    check(#r2.buses == 2 and #r2.belts == 2, "5.7 sens opposés, k = 2 : deux files")
  end
  do
    local P, C = {}, {}
    for i = 1, 6 do
      local item = "I" .. i
      P[#P + 1] = prod("p" .. i, item, 0, i * 40, 100)
      C[#C + 1] = cons("c" .. i, item, 90, i * 40, 100)
    end
    local rk = {}
    for k = 1, 4 do rk[k] = Rg.plan({ producers = P, consumers = C, hub = HUB, hub_share = 0, k = k }) end
    check(rk[1].stats.belts <= 1 and rk[2].stats.belts <= 2 and rk[4].stats.belts <= 4, "5.8 jamais plus de k files")
    check(rk[1].stats.served < rk[2].stats.served and rk[2].stats.served < rk[4].stats.served, "5.9 plus de files, plus de débit servi (" ..
      rk[1].stats.served .. " < " .. rk[2].stats.served .. " < " .. rk[4].stats.served .. ")")
    local rb = Rg.plan({ producers = P, consumers = C, hub = HUB, hub_share = 0, k = 6, budget = 1 })
    check(#rb.buses == 0, "5.10 budget d'une plaque : aucun bus")
    local free = Rg.plan({ producers = P, consumers = C, hub = HUB, hub_share = 0, k = 6 })
    local half = Rg.plan({ producers = P, consumers = C, hub = HUB, hub_share = 0, k = 6, budget = free.stats.plaques / 2 })
    check(half.stats.plaques <= free.stats.plaques / 2 + 1e-9 and #half.buses >= 1 and #half.buses < #free.buses, "5.11 budget de la moitié : moins de bus, dépense bornée")
    -- ordre de pose : valeur par coût décroissante
    local ratios, ordered = {}, true
    for i, b in ipairs(free.buses) do ratios[i] = b.net / b.plaques end
    for i = 2, #free.buses do if free.buses[i].id ~= i then ordered = false end end
    check(ordered and #free.links > 0 and free.links[1].bus == 1, "5.12 identifiants dans l'ordre de pose, prises de la liste dans l'ordre des bus")
    for i = 1, #free.buses do
      local c = free.buses[i].taps
      for j = 2, #c do if c[j - 1].contrib < c[j].contrib - 1e-9 then ordered = false end end
    end
    check(ordered, "5.13 prises d'un bus par contribution décroissante")
  end
  do -- ordre de pose : la file la plus rentable d'abord ; une file de plus seulement si elle recouvre
    local r = Rg.plan({ producers = { prod("pa", "A", 0, 0, 200), prod("pb", "B", 0, 300, 40) }, consumers = { cons("ca", "A", 90, 0, 200), cons("cb", "B", 90, 300, 40) },
      hub = HUB, hub_share = 0, k = 2 })
    check(#r.buses == 2 and r.buses[1].item == "A" and r.buses[2].item == "B" and r.buses[1].net > r.buses[2].net, "5.20 le bus le plus rentable est posé en premier")
    -- deux troncs sur la même rue mais sans recouvrement : jamais la même file
    local far = Rg.plan({ producers = { prod("pa", "A", 0, 0, 100), prod("pb", "B", 400, 0, 100) }, consumers = { cons("ca", "A", 60, 0, 100), cons("cb", "B", 460, 0, 100) },
      hub = HUB, hub_share = 0, k = 1 })
    check(#far.buses == 1 and #far.belts == 1, "5.21 deux troncs sur la même rue sans recouvrement : pas de file partagée (k = 1 : un seul bus)")
  end
  do -- recouvrement de troncs : trop faible (10 sur 100) pas de file partagée ; assez fort (60 sur 100) partagée
    local weak = Rg.plan({ producers = { prod("pa", "A", 0, 0, 100), prod("pb", "B", 90, 0, 100) }, consumers = { cons("ca", "A", 100, 0, 100), cons("cb", "B", 190, 0, 100) },
      hub = HUB, hub_share = 0, k = 1 })
    check(#weak.buses == 1, "5.22 recouvrement de 10 tuiles sur 100 : pas de partage (k = 1 : un seul bus)")
    local strong = Rg.plan({ producers = { prod("pa", "A", 0, 0, 100), prod("pb", "B", 40, 0, 100) }, consumers = { cons("ca", "A", 100, 0, 100), cons("cb", "B", 140, 0, 100) },
      hub = HUB, hub_share = 0, k = 1 })
    check(#strong.buses == 2 and #strong.belts == 1, "5.23 recouvrement de 60 tuiles sur 100 : une file, deux voies")
  end
  do -- croisements : un bus vertical coupe le tronc horizontal d'un autre objet, sur une autre file
    local I = Rg._internals
    local h = I.segments("x", 0, 0, 100, {})
    local v = I.segments("y", 50, -50, 50, {})
    check(I.crossings(h, v) == 1 and I.crossings(h, h) == 0, "5.24 un tronc horizontal et un tronc vertical qui se coupent : un croisement ; deux parallèles : aucun")
    check(I.crossings(I.segments("x", 0, 0, 100, {}), I.segments("y", 100, -50, 50, {})) == 0, "5.25 se toucher par le bout n'est pas se croiser")
    local P = { prod("pa", "A", 0, 0, 100), prod("pb", "B", 50, 80, 100) }
    local C = { cons("ca", "A", 100, 0, 100), cons("cb", "B", 50, -80, 100) }
    local x2 = Rg.plan({ producers = P, consumers = C, hub = HUB, hub_share = 0, k = 2 })
    check(#x2.buses == 2 and x2.stats.crossings == 1, "5.26 deux bus en croix sur deux files : un croisement compté (" .. tostring(x2.stats.crossings) .. ")")
    local solo_a = Rg.plan({ producers = { P[1] }, consumers = { C[1] }, hub = HUB, hub_share = 0, k = 1 })
    local solo_b = Rg.plan({ producers = { P[2] }, consumers = { C[2] }, hub = HUB, hub_share = 0, k = 1 })
    local sum = solo_a.stats.plaques + solo_b.stats.plaques
    check(near(x2.stats.plaques, sum + Rg.CROSS_PLAQUES, 1e-6), "5.27 le croisement coûte Rg.CROSS_PLAQUES de plus que les deux bus séparés")
    local par = Rg.plan({ producers = { P[1], prod("pb", "B", 0, 40, 100) }, consumers = { C[1], cons("cb", "B", 100, 40, 100) }, hub = HUB, hub_share = 0, k = 2 })
    check(par.stats.crossings == 0, "5.28 deux bus parallèles : aucun croisement")
  end
  do -- coût fixe d'un terminal (piquage : répartiteur, souterrains)
    local base = plan({ prod("p", "X", 0, 0, 100) }, { cons("c", "X", 80, 0, 100) })
    local ex = plan({ { key = "p", item = "X", x = 0, y = 0, rate = 100, extra = 40 } }, { cons("c", "X", 80, 0, 100) })
    check(base.buses[1] and ex.buses[1] and near(ex.buses[1].plaques, base.buses[1].plaques + 40), "5.29 le coût fixe `extra` d'un terminal s'ajoute aux plaques du bus")
    local big = plan({ { key = "p", item = "X", x = 0, y = 0, rate = 100, extra = 1e6 } }, { cons("c", "X", 80, 0, 100) })
    check(#big.buses == 0, "5.30 un coût fixe énorme : le bus ne se paie pas")
  end
  do -- adaptateur du registre des coffres
    local list = { { uid = 7, x = 10, y = 0, surface = "s", kind = "sortie", rate = { b = 30, a = 100 } }, { uid = 9, x = 90, y = 0, surface = "s", kind = "entree", rate = { a = 60 } },
      { uid = 3, x = 0, y = 0, surface = "s", kind = "neutre", rate = { a = 1 } }, { uid = 4, x = 0, y = 0, surface = "s", kind = "sortie" },
      { uid = 5, x = 0, y = 0, surface = "autre", kind = "sortie", rate = { a = 5 } } }
    local P, C, skipped = Rg.terminals_from_sources(list, "s")
    check(#P == 2 and P[1].key == "7:a" and P[2].key == "7:b" and #C == 1 and C[1].key == "9:a" and skipped == 3, "5.31 registre des coffres : une sortie donne un producteur par objet, les neutres, sans débit et d'une autre surface sont écartés")
    local r = Rg.plan({ producers = P, consumers = C, hub = HUB, hub_share = 0, k = 1 })
    check(#r.buses == 1 and near(r.buses[1].served, 60), "5.32 le bus lit les terminaux de l'adaptateur (60 objets/min servis)")
  end
  do -- le sac à dos : l'ordre par valeur / coût bat l'ordre par valeur (budget 100 : un gros bus contre deux petits)
    local function cd(item, line, net, plaques)
      return { item = item, axis = "x", sign = 1, line = line, lo = 0, hi = 50, plaques = plaques, net = net, pay_s = plaques, taps = { { key = item } } }
    end
    local got, which = Rg._internals.choose({ cd("big", 100, 100, 100), cd("s1", 200, 60, 50), cd("s2", 300, 60, 50) }, 3, 100, O0)
    check(got.net == 120 and which == "net/cout", "5.14 deux petits (120) valent mieux qu'un gros (100) sous budget : ordre par valeur / coût (" .. tostring(which) .. ")")
    local got2, which2 = Rg._internals.choose({ cd("big", 100, 100, 100), cd("s1", 200, 11, 10) }, 3, 100, O0)
    check(got2.net == 100 and which2 == "net", "5.15 le gros seul (100) bat le petit (11) quand il tient : ordre par valeur (" .. tostring(which2) .. ")")
    -- une même rue, un même sens, un même objet : jamais deux voies d'une file pour le même objet
    local two = Rg._internals.choose({ cd("same", 100, 100, 100), cd("same", 102, 90, 100) }, 1, nil, O0)
    check(#two.picks == 1, "5.16 deux bus du même objet ne partagent pas une file")
    local diff = Rg._internals.choose({ cd("a", 100, 100, 100), cd("b", 102, 90, 100) }, 1, nil, O0)
    check(#diff.picks == 2 and #diff.belts == 1, "5.17 deux objets différents, même rue : une file, deux voies")
    local far = Rg._internals.choose({ cd("a", 100, 100, 100), cd("b", 140, 90, 100) }, 1, nil, O0)
    check(#far.picks == 1, "5.19 deux rues différentes (écart > SHARE_PERP) : pas de file partagée")
  end
  do -- (contrôle conservé) : un gros bus cher contre deux petits : on garde le meilleur total sous budget
    local P = { prod("pa", "A", 0, 0, 200), prod("pb", "B", 0, 300, 50), prod("pc", "C", 0, 600, 50) }
    local C = { cons("ca", "A", 160, 0, 200), cons("cb", "B", 40, 300, 50), cons("cc", "C", 40, 600, 50) }
    local r = Rg.plan({ producers = P, consumers = C, hub = HUB, hub_share = 0, k = 3 })
    check(r.which ~= nil and #r.buses >= 1, "5.18 l'ordre retenu est nommé (" .. tostring(r.which) .. ")")
  end

  -- §6 contre l'optimum par énumération
  -- (a) sous-ensemble de terminaux d'une composante : le bus trouvé contre le meilleur des 2^n sous-ensembles
  local lcg = 12345
  local function rnd(n)
    lcg = (lcg * 1103515245 + 12345) % 2147483648
    return lcg % n
  end
  local O = { hub = HUB, labor = Li.LABOR_VALUE, price = Li.PRICE, tmax = Li.TMAX }
  local ratios_a, worst_a = {}, 1
  local trials = quick and 6 or 40
  for _ = 1, trials do
    local n = 5 + rnd(4)
    local comp = {}
    local np = 0
    for i = 1, n do
      local kind = (i <= 2 or rnd(2) == 0) and "p" or "c"
      if i == 3 then kind = "c" end
      local x, y = rnd(150), rnd(60)
      local rate = 20 + rnd(150)
      comp[#comp + 1] = { key = string.format("t%02d", i), kind = kind, item = "X", x = x, y = y, rate = math.min(rate, 200), arms = math.ceil(math.min(rate, 200) / Rg.ARM_RATE),
        leg = Rg.leg(x + y, kind == "p" and Rg.COLLECT_BATCH or Rg.FILL_BATCH) }
      if kind == "p" then np = np + 1 end
    end
    local ax_ok = false
    for _, t in ipairs(comp) do if t.kind == "c" then ax_ok = true end end
    if ax_ok and np > 0 then
      local bus = Rg.bus_of(comp, O)
      -- optimum : tous les sous-ensembles, sur le MÊME axe que la règle (axe de la composante entière)
      local I = Rg._internals
      local ax = I.axis_of(comp)
      local best = 0
      for mask = 1, (2 ^ n) - 1 do
        local S = {}
        for i = 1, n do if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then S[#S + 1] = comp[i] end end
        table.sort(S, I.along(ax))
        local e = I.evaluate(S, ax, O)
        if e.trunk <= Rg.MAX_TRUNK and e.net > best then best = e.net end
      end
      local got = bus and bus.net or 0
      if best > 0 then
        local ratio = got / best
        ratios_a[#ratios_a + 1] = ratio
        if ratio < worst_a then worst_a = ratio end
      end
      check(got <= best + 1e-6, "6.1 le bus de la règle n'est jamais meilleur que l'optimum énuméré (" .. string.format("%.3f / %.3f", got, best) .. ")")
    end
  end
  local mean_a = 0
  for _, r in ipairs(ratios_a) do mean_a = mean_a + r end
  mean_a = #ratios_a > 0 and mean_a / #ratios_a or 1
  if out then print(string.format("[RESEAU-GRAPHE] §6a bus contre optimum (%d instances) : pire %.3f, moyenne %.3f", #ratios_a, worst_a, mean_a)) end
  check(#ratios_a >= (quick and 2 or 12) and worst_a >= 0.8 and mean_a >= 0.95, "6.2 bus >= 80 % de l'optimum au pire, 95 % en moyenne (pire " ..
    string.format("%.3f, moyenne %.3f", worst_a, mean_a) .. ")")

  -- (b) choix sous k files : candidats indépendants (rues différentes), énumération des sous-ensembles de taille <= k et du budget
  local ratios_b, worst_b = {}, 1
  for _ = 1, (quick and 6 or 60) do
    local m = 5 + rnd(5)
    local cands = {}
    for i = 1, m do
      local plaques = 10 + rnd(300)
      local net = (10 + rnd(900))
      cands[i] = { item = "I" .. string.format("%02d", i), axis = "x", sign = 1, line = i * 100, lo = 0, hi = 50, plaques = plaques, net = net,
        pay_s = plaques + rnd(100), taps = { { key = "t" .. string.format("%02d", i) } } }
    end
    local k = 1 + rnd(3)
    local budget = 150 + rnd(500)
    local got = Rg._internals.choose(cands, k, budget, O)
    local best = 0
    for mask = 1, (2 ^ m) - 1 do
      local cnt, pl, nt = 0, 0, 0
      for i = 1, m do
        if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then cnt, pl, nt = cnt + 1, pl + cands[i].plaques, nt + cands[i].net end
      end
      if cnt <= k and pl <= budget and nt > best then best = nt end
    end
    if best > 0 then
      local ratio = got.net / best
      ratios_b[#ratios_b + 1] = ratio
      if ratio < worst_b then worst_b = ratio end
    end
    check(got.net <= best + 1e-6 and got.plaques <= budget + 1e-9 and #got.belts <= k, "6.3 choix : jamais au-dessus de l'optimum, budget et k tenus")
  end
  local mean_b = 0
  for _, r in ipairs(ratios_b) do mean_b = mean_b + r end
  mean_b = #ratios_b > 0 and mean_b / #ratios_b or 1
  if out then print(string.format("[RESEAU-GRAPHE] §6b choix contre optimum (%d instances) : pire %.3f, moyenne %.3f", #ratios_b, worst_b, mean_b)) end
  check(#ratios_b >= (quick and 2 or 30) and worst_b >= 0.5 and mean_b >= 0.9, "6.4 choix >= 50 % de l'optimum au pire (garantie du sac à dos), 90 % en moyenne (pire " ..
    string.format("%.3f, moyenne %.3f", worst_b, mean_b) .. ")")

  -- §7 déterminisme : l'ordre des listes ne change rien
  do
    local P, C = {}, {}
    for i = 1, 12 do
      P[#P + 1] = prod("p" .. string.format("%02d", i), (i % 3 == 0) and "A" or "B", (i * 37) % 200, (i * 11) % 90, 40 + i * 7)
      C[#C + 1] = cons("c" .. string.format("%02d", i), (i % 3 == 0) and "A" or "B", 60 + (i * 53) % 220, (i * 17) % 90, 30 + i * 5)
    end
    local function rev(l) local o = {} for i = #l, 1, -1 do o[#o + 1] = l[i] end return o end
    local function rot(l) local o = {} for i = 1, #l do o[i] = l[(i + 4 - 1) % #l + 1] end return o end
    local r1 = Rg.plan({ producers = P, consumers = C, hub = HUB, k = 2 })
    local r2 = Rg.plan({ producers = rev(P), consumers = rot(C), hub = HUB, k = 2 })
    check(ser(r1) == ser(r2) and #r1.buses > 0, "7.1 listes renversées ou tournées : résultat identique (" .. #r1.buses .. " bus)")
    local r3 = Rg.plan({ producers = P, consumers = C, hub = HUB, k = 2 })
    check(ser(r1) == ser(r3), "7.2 deux appels : résultat identique")
    -- égalité exacte entre deux candidats : départage écrit (par objet puis clé)
    local PP = { prod("pa", "A", 0, 200, 100), prod("pb", "B", 0, -200, 100) }
    local CC = { cons("ca", "A", 90, 200, 100), cons("cb", "B", 90, -200, 100) }
    local t1 = Rg.plan({ producers = PP, consumers = CC, hub = HUB, hub_share = 0, k = 1 })
    local t2 = Rg.plan({ producers = { PP[2], PP[1] }, consumers = { CC[2], CC[1] }, hub = HUB, hub_share = 0, k = 1 })
    check(t1.buses[1] and t1.buses[1].item == "A" and t2.buses[1].item == "A", "7.3 égalité parfaite de deux bus et une seule file : le plus petit objet l'emporte")
  end

  -- §8 travail découpé
  do
    local P, C = {}, {}
    for i = 1, 10 do
      P[#P + 1] = prod("p" .. string.format("%02d", i), "I" .. (i % 4), (i * 29) % 180, (i * 13) % 70, 100)
      C[#C + 1] = cons("c" .. string.format("%02d", i), "I" .. (i % 4), 40 + (i * 41) % 200, (i * 7) % 70, 80)
    end
    local inp = { producers = P, consumers = C, hub = HUB, k = 2 }
    local whole = Rg.plan(inp)
    local job = Rg.begin(inp)
    local steps = 0
    while not Rg.step(job, 1) do steps = steps + 1 if steps > 1000 then break end end
    check(ser(Rg.result(job)) == ser(whole), "8.1 une unité à la fois = tout d'un coup")
    check(steps >= 4, "8.2 le travail se découpe (" .. steps .. " pas)")
    local function has_fn(t, seen)
      for _, k in ipairs(sorted_keys(t)) do
        local v = t[k]
        if type(v) == "function" then return true end
        if type(v) == "table" and not seen[v] then seen[v] = true if has_fn(v, seen) then return true end end
      end
      return false
    end
    local j2 = Rg.begin(inp)
    Rg.step(j2, 2)
    check(not has_fn(j2, {}), "8.3 le travail en cours ne contient aucune fonction (sérialisable)")
    check(Rg.step(Rg.begin({ producers = {}, consumers = {}, hub = HUB })) == true, "8.4 instance vide : fini d'emblée")
  end

  return ok_n, fail_n, failed
end

---------------------------------------------------------------------------------------------------
-- §9 à §11 : sur le module réel seulement
---------------------------------------------------------------------------------------------------
local Rg = load_rg(SRC)
Rg._internals = Rg._internals
local ok_n, fail_n, failed = suite(Rg, false, true)
local total_ok, total_fail = ok_n, fail_n
local function check(c, msg)
  if c then total_ok = total_ok + 1 else total_fail = total_fail + 1 print("  ECHEC : " .. msg) end
end

-- §9 instance chiffrée : la sauvegarde du DC à 255 min (voir docs/conception/RESEAU_GRAPHE.md §5)
local Ex = require("tests.reseau_graphe_exemple")
do
  local inp = Ex.instance()
  local r = Rg.plan(inp)
  local s = r.stats
  check(s.demand > 0 and s.served > 0 and s.served <= s.ceiling + 1e-6 and s.served <= s.demand + 1e-6, "9.1 servi <= plafond sans géométrie <= demande")
  check(s.belts <= inp.k, "9.2 files <= k")
  local r1 = Rg.plan(Ex.instance({ k = 1 }))
  local r4 = Rg.plan(Ex.instance({ k = 4 }))
  check(r1.stats.served <= s.served and s.served <= r4.stats.served, "9.3 le débit servi croît avec k (" .. string.format("%.0f <= %.0f <= %.0f", r1.stats.served, s.served, r4.stats.served) .. ")")
  local cur = Ex.current_rule(inp)
  check(s.gain_s_min > cur.gain_s_min, "9.4 le bus économise plus de PNJ-secondes que la liaison actuelle de quai (" ..
    string.format("%.1f contre %.1f PNJ-s/min", s.gain_s_min, cur.gain_s_min) .. ")")
  print(string.format("[RESEAU-GRAPHE] §9 exemple : demande %.0f/min, plafond %.0f, k=1 servi %.0f, k=2 servi %.0f (%.0f %%), k=4 servi %.0f ; %.2f PNJ-équivalents économisés (k=2) contre %.2f (règle actuelle : %d paire(s))",
    s.demand, s.ceiling, r1.stats.served, s.served, 100 * s.share, r4.stats.served, s.pnj_equiv, cur.gain_s_min / 60, cur.pairs))
end

-- §10 hygiène du source
do
  local code = (SRC .. "\n" .. BUSSRC):gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  check(not code:find("iron%-") and not code:find("copper%-") and not code:find("transport%-belt") and not code:find("[a-z]%-inserter")
    and not code:find("electric%-pole") and not code:find("assembling") and not code:find("wooden") and not code:find("%-plate") and not code:find("gear"),
    "10.1 aucun nom d'objet dans shared/team/reseau_graphe.lua")
  check(not code:find("[^i%.]pairs%("), "10.2 aucun pairs dans la règle")
  check(not code:find("math%.random") and not code:find("os%.time") and not code:find("os%.clock") and not code:find("math%.sin") and not code:find("math%.cos")
    and not code:find("math%.atan"), "10.3 ni hasard, ni horloge, ni trigonométrie")
  check(not code:find("game%.") and not code:find("global") and not code:find("script%.") and not code:find("settings%."), "10.4 aucune API du jeu")
  check(not code:find("require%(\"script"), "10.5 aucun require de script/")
end

-- §11 coût en instructions
local function instr(fn)
  local c = 0
  debug.sethook(function() c = c + 1 end, "", 1)
  fn()
  debug.sethook()
  return c
end
do
  local inp = Ex.big(10, 150)
  local job = Rg.begin(inp)
  local worst, total, units = 0, 0, 0
  local done = false
  while not done do
    local c = instr(function() done = Rg.step(job, 1) end)
    units = units + 1
    total = total + c
    if c > worst then worst = c end
  end
  -- le pire cas d'une unité : une composante pleine de N_MAX terminaux
  local comp = {}
  for i = 1, Rg.N_MAX do
    comp[#comp + 1] = { key = string.format("t%02d", i), kind = (i % 2 == 0) and "p" or "c", item = "X", x = (i * 37) % 150, y = (i * 23) % 70, rate = 60 + i,
      arms = 2, leg = 1 }
  end
  local O = { hub = { x = 0, y = 0 }, labor = Li.LABOR_VALUE, price = Li.PRICE, tmax = Li.TMAX }
  local full = instr(function() Rg.bus_of(comp, O) end)
  print(string.format("[RESEAU-GRAPHE] §11 coût (sethook, compte de 1) : %d terminaux en %d unités, total %d instructions, pire unité %d ; composante pleine (%d terminaux) %d instructions",
    #inp.producers + #inp.consumers, units, total, worst, Rg.N_MAX, full))
  check(worst <= 150000, "11.1 pire unité (une passe) sous 150 000 instructions")
  check(total <= 12000000, "11.2 150 producteurs + 150 consommateurs : moins de 12 millions d'instructions en tout")
  COST = { worst = worst, total = total, full = full, units = units }
end

-- §12 mutants
local MUTANTS = {
  { "le consommateur reçoit sans producteur en amont", "local take = math.min(pool, t.rate)", "local take = t.rate" },
  { "voie sans plafond", "Rg.LANE_CAP - pool", "Rg.LANE_CAP * 100 - pool" },
  { "part du QG ignorée", "rate = rate * (1 - hub_share)", "rate = rate * 1" },
  { "trajet sans aller-retour", "(2 * d / Li.WALK + Li.HANDLE_S)", "(d / Li.WALK + Li.HANDLE_S)" },
  { "consommateur avant producteur à égalité", "if a.kind ~= b.kind then return a.kind == \"p\" end\n    return a.key < b.key", "if a.kind ~= b.kind then return a.kind == \"c\" end\n    return a.key < b.key" },
  { "composantes à portée infinie", "d <= Rg.LINK_R then\n        local ri", "d <= 1e9 then\n        local ri" },
  { "interdit du crochet ignoré", "if d ~= nil and d <= Rg.LINK_R then", "if (d == nil or d <= Rg.LINK_R) then" },
  { "partage de file entre sens opposés", "b.sign == c.sign and #b.lanes", "#b.lanes" },
  { "même objet sur les deux voies", "and not b.items[c.item]", "and true" },
  { "budget ignoré", "(not budget or spent + mplaq <= budget)", "true" },
  { "nombre de files ignoré", "(bb or #belts < k)", "true" },
  { "bus qui ne se paie pas accepté", "if ev.net <= 0 then st.why", "if false then st.why" },
  { "pas de composante résiduelle", "(task.depth or 1) < Rg.DEPTH_MAX", "false" },
  { "un seul ordre glouton", "if rb.net > best.net + Rg.EPS then", "if false then" },
  { "départage des clés inversé le long du tronc", "if a.kind ~= b.kind then return a.kind == \"p\" end\n    return a.key < b.key", "if a.kind ~= b.kind then return a.kind == \"p\" end\n    return a.key > b.key" },
  { "tronc au premier coin et non à la médiane", "math.ceil(#perps / 2)", "1" },
  { "prises dans l'ordre inverse", "if a.contrib ~= b.contrib then return a.contrib > b.contrib end", "if a.contrib ~= b.contrib then return a.contrib < b.contrib end" },
  { "composantes jamais coupées", "if #comp <= Rg.N_MAX then", "if true then" },
  { "recouvrement non compté", "mplaq = math.max(0, c.plaques - shared * o.price.belt)", "mplaq = c.plaques" },
  { "croissance supprimée", "if not S2 or st.gev.net > ev.net + Rg.EPS then", "if false then" },
  { "élagage supprimé", "if st.pass <= Rg.PEEL_MAX then S2, e2 = peel_pass(st.S, st.ev, st.ax, o) end", "" },
  { "croissance sans bornes de tronc", "if e.trunk <= Rg.MAX_TRUNK and e.net > (be and be.net or bev.net) + Rg.EPS then", "if e.net > (be and be.net or bev.net) + Rg.EPS then" },
  { "ordre de pose inversé", "if dens[a.belt] ~= dens[b.belt] then return dens[a.belt] > dens[b.belt] end", "if dens[a.belt] ~= dens[b.belt] then return dens[a.belt] < dens[b.belt] end" },
  { "voie de partage posée avant la voie de base", "return a.lane < b.lane", "return a.lane > b.lane" },
  { "k indifférent au stock de tapis", "local by_stock = math.floor(math.max(0, belt_stock or 0) / Rg.BELT_TILES)", "local by_stock = 99" },
  { "coût fixe ignoré", "local plaques = tiles * price.belt + arms * price.arm + #S * price.pole + extra", "local plaques = tiles * price.belt + arms * price.arm + #S * price.pole" },
  { "croisement gratuit", "mplaq = mplaq + nx * Rg.CROSS_PLAQUES", "mplaq = mplaq" },
  { "croisement à l'intérieur compté aux bornes", "if h.a < v.k and v.k < h.b and v.a < h.k and h.k < v.b then", "if h.a <= v.k and v.k <= h.b and v.a <= h.k and h.k <= v.b then" },
  { "partage pour un recouvrement faible", "if ov >= Rg.OVERLAP_MIN * math.max(1, short) and ov > bov", "if ov > bov" },
  { "rue ignorée au partage", "and math.abs(b.line - c.line) <= Rg.SHARE_PERP then", "then" },
  { "gain de collecte oublié", "gain = gain + take * (t.leg + pleg)", "gain = gain + take * t.leg" },
}
local refused = 0
for _, m in ipairs(MUTANTS) do
  local msrc, mbus = SRC, BUSSRC
  local a, b = SRC:find(m[2], 1, true)
  if a then
    msrc = SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1)
  else
    a, b = BUSSRC:find(m[2], 1, true)
    if a then mbus = BUSSRC:sub(1, a - 1) .. m[3] .. BUSSRC:sub(b + 1) end
  end
  if not a then
    check(false, "12 motif de mutant introuvable : " .. m[1])
  else
    local okl, M = pcall(load_rg, msrc, mbus)
    if not okl then
      refused = refused + 1
    else
      local oks, okn, failn = pcall(suite, M, true, false)
      if not oks or failn > 0 then
        refused = refused + 1
      else
        check(false, "12 mutant SURVIVANT : " .. m[1])
      end
    end
  end
end
print(string.format("[RESEAU-GRAPHE] §12 mutants refusés : %d sur %d", refused, #MUTANTS))
check(refused == #MUTANTS, "12.1 tous les mutants sont refusés")

print(string.format("[RESEAU-GRAPHE] BILAN : %d OK, %d ECHEC(S)", total_ok, total_fail))
os.exit(total_fail == 0 and 0 or 1)
