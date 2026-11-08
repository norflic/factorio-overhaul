--[[
  Lot RESEAU-GRAPHE (ajout du DC, placement pondéré) : test hors jeu de shared/team/placement_poids.lua.
    §1 point de Weber (médiane pondérée par axe) contre l'optimum énuméré sur la grille ; §2 coût, sources multiples, puissance ; §3 classement
    des lots (départages, ordre des listes) ; §4 demandes d'un module ; §5 Pp.order sur les candidats de place_module ; §6 comparaison au
    placement actuel (un seul point `toward`) ; §7 hygiène du source ; §8 coût en instructions ; §9 mutants.
  Usage : lua5.2 tests/placement_poids_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/placement_poids.lua")
local Li = require("shared.team.liaison")

local function load_pp(src)
  local fn, err = load(src, "=placement_poids", "t")
  assert(fn, err)
  return fn()
end

local function near(a, b, tol) return math.abs(a - b) <= (tol or 1e-6) end

local function grid(n, pitch)
  local lots = {}
  for i = -n, n do
    for j = -n, n do lots[#lots + 1] = { key = string.format("%+03d:%+03d", i, j), x = i * pitch, y = j * pitch } end
  end
  return lots
end

local function suite(Pp, quick, out)
  local ok_n, fail_n, failed = 0, 0, {}
  local function check(c, msg)
    if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 failed[#failed + 1] = msg if out then print("  ECHEC : " .. msg) end end
  end
  local HUB = { x = 0, y = 0 }

  -- §1 point de Weber
  check(Pp.point({}) == nil and Pp.point({ { w = 0, x = 1, y = 1 } }) == nil, "1.1 sans demande de poids positif : rien")
  local one = Pp.point({ { w = 5, x = 12, y = -7 } })
  check(one.x == 12 and one.y == -7 and one.cost == 0, "1.2 une seule demande : le point est la demande")
  local heavy = Pp.point({ { w = 300, x = -100, y = 0 }, { w = 50, x = 100, y = 40 } })
  check(heavy.x == -100 and heavy.y == 0 and heavy.x_hi == -100, "1.3 une demande qui pèse plus de la moitié attire le point sur elle")
  local eq = Pp.point({ { w = 10, x = 0, y = 0 }, { w = 10, x = 100, y = 40 } })
  check(eq.x == 0 and eq.x_hi == 100 and eq.y == 0 and eq.y_hi == 40, "1.4 deux poids égaux : intervalle optimal (0 à 100, 0 à 40), borne basse rendue")
  local three = Pp.point({ { w = 4, x = 0, y = 0 }, { w = 3, x = 50, y = 90 }, { w = 3, x = 100, y = 10 } })
  check(three.x == 50 and three.y == 10, "1.5 trois demandes : médiane pondérée par axe (" .. three.x .. ", " .. three.y .. ")")
  -- optimalité contre la grille entière
  local lcg = 99
  local function rnd(n) lcg = (lcg * 1103515245 + 12345) % 2147483648 return lcg % n end
  local worst = 0
  for _ = 1, quick and 8 or 60 do
    local d = {}
    for i = 1, 2 + rnd(5) do d[i] = { w = 1 + rnd(20), x = rnd(24), y = rnd(24) } end
    local pt = Pp.point(d)
    local best = math.huge
    for x = 0, 23 do for y = 0, 23 do local c = Pp.cost(x, y, d, 1) if c < best then best = c end end end
    if pt.cost > best + 1e-9 then worst = worst + 1 end
    check(pt.cost <= best + 1e-9, "1.6 le point de Weber égale le minimum énuméré sur la grille (" .. pt.cost .. " contre " .. best .. ")")
  end

  -- §2 coût
  check(Pp.cost(0, 0, { { w = 2, x = 3, y = 4 } }, 1) == 14 and Pp.cost(0, 0, { { w = 2, x = 3, y = 4 } }, 2) == 98, "2.1 coût = poids x Manhattan^p")
  check(Pp.cost(0, 0, { { w = 1, x = 0, y = 0, alts = { { x = 50, y = 0 }, { x = 3, y = 0 }, { x = -20, y = 0 } } } }, 1) == 3, "2.2 plusieurs sources : la plus proche compte")
  check(Pp.cost(5, 5, { { w = 0, x = 90, y = 90 } }, 1) == 0, "2.3 un poids nul ne coûte rien")
  -- p = 2 : le point intérieur
  do
    local d = { { w = 3, x = 0, y = 0 }, { w = 1, x = 100, y = 0 } }
    local lots = {}
    for i = 0, 4 do lots[#lots + 1] = { key = "L" .. i, x = i * 28, y = 0 } end
    check(Pp.rank(lots, d, { hub = HUB, power = 1 })[1].key == "L0", "2.4 p = 1 : le lot sur la source lourde")
    check(Pp.rank(lots, d, { hub = HUB, power = 2 })[1].key == "L1", "2.5 p = 2 : un lot intérieur, à 28 tuiles de la source lourde")
  end

  -- §3 classement
  do
    local d = { { w = 10, x = 0, y = 0 }, { w = 10, x = 112, y = 0 } }
    local lots = {}
    for i = 0, 4 do lots[#lots + 1] = { key = "L" .. i, x = i * 28, y = 0 } end
    local r = Pp.rank(lots, d, { hub = { x = -500, y = 0 } })
    check(r[1].key == "L0" and r[2].key == "L1" and near(r[1].cost, r[5].cost), "3.1 coût à plat entre deux sources égales : départage par la distance au QG")
    local r2 = Pp.rank(lots, d, { hub = { x = 900, y = 0 } })
    check(r2[1].key == "L4", "3.2 le QG de l'autre côté : le départage change")
    local same = Pp.rank({ { key = "b", x = 0, y = 0 }, { key = "a", x = 0, y = 0 } }, d, { hub = HUB })
    check(same[1].key == "a", "3.3 égalité totale : la plus petite clé")
    local rev = {}
    for i = #lots, 1, -1 do rev[#rev + 1] = lots[i] end
    local ra, rb = Pp.rank(lots, d, { hub = HUB }), Pp.rank(rev, d, { hub = HUB })
    local same_order = #ra == #rb
    for i = 1, #ra do if ra[i].key ~= rb[i].key then same_order = false end end
    check(same_order, "3.4 l'ordre des lots en entrée ne change rien")
    local lim = Pp.rank({ { key = "z", x = 9, y = 9 } }, d, nil)
    check(#lim == 1 and lim[1].hub_d == 0, "3.5 sans QG donné : distance au QG nulle")
  end

  -- §4 demandes d'un module
  do
    local dem = Pp.demands({ b = 2, a = 3, c = 0 }, { z = 1 }, function(it)
      if it == "a" then return { { x = 100, y = 0 } } end
      if it == "b" then return { { x = 0, y = 50 }, { x = 7, y = 7 } } end
      return nil
    end, nil, { x = 1, y = 2 }, { unit = 60, out_factor = 0.5 })
    check(#dem == 3 and dem[1].item == "a" and dem[2].item == "b" and dem[3].item == "z", "4.1 entrées par ordre d'objet, puis les sorties (poids nul écarté)")
    check(dem[1].w == 180 and dem[2].w == 120 and dem[3].w == 30, "4.2 poids = débit x unité (x facteur pour les sorties)")
    check(dem[1].x == 100 and dem[2].alts and #dem[2].alts == 2 and dem[3].x == 1 and dem[3].y == 2, "4.3 source connue, sources multiples, sinon le QG")
  end

  -- §5 Pp.order
  do
    local cands = {}
    for i = 0, 3 do cands[#cands + 1] = { k = "k" .. i, l = { i = i }, d = 999, shared = nil } end
    local d = { { w = 5, x = 84, y = 0 } }
    local sorted = Pp.order(cands, d, function(c) return c.l.i * 28, 0 end, { hub = HUB })
    check(sorted[1].k == "k3" and sorted[1].d == 5 * 0 and sorted[4].k == "k0" and sorted[4].d == 5 * 84, "5.1 candidats rangés par coût, d remplacé par le coût")
    check(sorted[1] == cands[4], "5.2 ce sont les mêmes tables (place_module lit .l, .k, .shared)")
  end

  -- §6 comparaison au placement actuel : un module de circuits entre cuivre et fer
  do
    local lots = grid(6, 28)
    local dem = Pp.demands({ copper = 4.5, iron = 3 }, { circ = 3 }, function(it)
      if it == "copper" then return { { x = 140, y = -28 } } end
      return { { x = -140, y = 28 } }
    end, nil, HUB, { unit = 60, out_factor = 0 })
    local cmp = Pp.compare(lots, dem, HUB, { hub = HUB })
    check(cmp.old.key == "+00:+00" and cmp.new.key == "+05:-01", "6.1 sans le débit de sortie : le module va au cuivre (poids 270 sur 450), pas au QG (" .. cmp.new.key .. ")")
    check(near(cmp.old.cost, 75600) and near(cmp.new.cost, 60480), "6.2 coût au QG 75 600, au lot du cuivre 60 480 (objets/min x tuiles)")
    check(near(cmp.saving, cmp.old.cost - cmp.new.cost) and cmp.saving_pct > 15 and cmp.saving_pnj_s_min > 0, "6.3 économie chiffrée (" .. string.format("%.0f %%, %.1f PNJ-s/min", cmp.saving_pct, cmp.saving_pnj_s_min) .. ")")
    local with_out = Pp.demands({ copper = 4.5, iron = 3 }, { circ = 3 }, function(it)
      if it == "copper" then return { { x = 140, y = -28 } } end
      return { { x = -140, y = 28 } }
    end, nil, HUB, { unit = 60, out_factor = 1 })
    local c2 = Pp.compare(lots, with_out, HUB, { hub = HUB })
    check(c2.new.key == "+00:+00" and near(c2.saving, 0), "6.4 avec la sortie (180/min) portée au QG, le QG redevient le meilleur lot")
    check(near(Pp.pnj_s_min(340), 2 / Li.WALK), "6.5 340 objets x tuile = un aller-retour d'une tuile de marche")
  end

  return ok_n, fail_n, failed
end

local Pp = load_pp(SRC)
local ok_n, fail_n = suite(Pp, false, true)
local function check(c, msg)
  if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end
end

-- §7 hygiène
do
  local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  check(not code:find("iron%-") and not code:find("copper%-") and not code:find("transport%-belt") and not code:find("assembling") and not code:find("%-plate"),
    "7.1 aucun nom d'objet")
  check(not code:find("[^i%.]pairs%("), "7.2 aucun pairs")
  check(not code:find("math%.random") and not code:find("os%.time") and not code:find("os%.clock") and not code:find("math%.sin") and not code:find("math%.cos"),
    "7.3 ni hasard, ni horloge, ni trigonométrie")
  check(not code:find("game%.") and not code:find("global") and not code:find("script%."), "7.4 aucune API du jeu")
end

-- §8 coût
do
  local lots = grid(6, 28)
  local d = {}
  for i = 1, 8 do d[i] = { w = 10 + i, x = (i * 53) % 300 - 150, y = (i * 37) % 300 - 150 } end
  local c = 0
  debug.sethook(function() c = c + 1 end, "", 1)
  Pp.rank(lots, d, { hub = { x = 0, y = 0 } })
  debug.sethook()
  print(string.format("[PLACEMENT] cout (sethook, compte de 1) : classement de %d lots contre %d demandes : %d instructions", #lots, #d, c))
  check(c <= 400000, "8.1 classer 169 lots contre 8 demandes : moins de 400 000 instructions")
end

-- §9 mutants
local MUTANTS = {
  { "médiane : seuil du poids dépassé trop tard", "if cum >= half - Pp.EPS then", "if cum > total - Pp.EPS then" },
  { "médiane : intervalle plat ignoré", "if math.abs(cum - half) <= Pp.EPS and list[i + 1] then return e.c, list[i + 1].c end", "" },
  { "distance de Chebyshev au lieu de Manhattan", "return math.abs(ax - bx) + math.abs(ay - by)", "return math.max(math.abs(ax - bx), math.abs(ay - by))" },
  { "source la plus lointaine", "if not best or m < best then best = m end", "if not best or m > best then best = m end" },
  { "poids ignoré", "total = total + d.w * dist_to(d, x, y) ^ p", "total = total + dist_to(d, x, y) ^ p" },
  { "puissance ignorée", "local p = power or Pp.POWER", "local p = 1" },
  { "départage par le QG inversé", "if a.hub_d ~= b.hub_d then return a.hub_d < b.hub_d end", "if a.hub_d ~= b.hub_d then return a.hub_d > b.hub_d end" },
  { "départage par la clé inversé", "return a.key < b.key\n  end)\n  return out", "return a.key > b.key\n  end)\n  return out" },
  { "coût le plus haut d'abord", "if math.abs(a.cost - b.cost) > Pp.EPS * math.max(1, math.abs(a.cost)) then return a.cost < b.cost end", "if math.abs(a.cost - b.cost) > Pp.EPS * math.max(1, math.abs(a.cost)) then return a.cost > b.cost end" },
  { "sortie comptée au poids plein", "add(outputs, where_out, \"out\", ofac)", "add(outputs, where_out, \"out\", 1)" },
  { "source inconnue : ni QG ni rien", "d.x, d.y = hub.x, hub.y", "d.x, d.y = 0, 0" },
  { "unité ignorée", "local w = map[name] * unit * factor", "local w = map[name] * factor" },
  { "d non remplacé par le coût", "r.ref.c.d = r.cost", "" },
  { "départ de l'ancien placement : le plus lointain", "if not old or d < old.d or (d == old.d and l.key < old.key) then", "if not old or d > old.d or (d == old.d and l.key < old.key) then" },
  { "conversion en PNJ-s sans aller-retour", "return cost * 2 / Li.WALK / Pp.FILL_BATCH", "return cost / Li.WALK / Pp.FILL_BATCH" },
}
local refused = 0
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then
    check(false, "9 motif de mutant introuvable : " .. m[1])
  else
    local okl, M = pcall(load_pp, SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))
    if not okl then
      refused = refused + 1
    else
      local oks, okn, failn = pcall(suite, M, true, false)
      if not oks or failn > 0 then refused = refused + 1 else check(false, "9 mutant SURVIVANT : " .. m[1]) end
    end
  end
end
print(string.format("[PLACEMENT] mutants refusés : %d sur %d", refused, #MUTANTS))
check(refused == #MUTANTS, "9.1 tous les mutants sont refusés")

print(string.format("[PLACEMENT] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
