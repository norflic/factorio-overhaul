--[[
  Lot EXPANSION « le besoin croissant » : test hors jeu de shared/ai3/besoin.lua (règles pures) et de son branchement
  (shared/ai3/expansion.lua, crochets de shared/ai3/buts.lua et shared/ai3/cerveau.lua).
    §1 besoin d'une matière : croissant en demande et en facteur, décroissant en production et en stock, nul quand la
       production couvre la demande projetée, facteur de croissance (entiers, plafonné) ;
    §2 graphe de recettes : consommateurs directs d'une matière et leurs débits, comparés à un dépliage récursif écrit
       à part (données du jeu et données RENOMMÉES), cycle de recettes sans boucle ;
    §3 ÉQUILIBRE : la même fraction pour tous les consommateurs, personne d'affamé, personne au-delà de son besoin,
       jamais plus que l'offre ; comparé à une FORCE BRUTE sur de petits cas (aucune répartition entière ne fait mieux sur
       le plus petit taux de satisfaction) ; propriété sur 400 tirages ; Be.limit ;
    §4 déclencheur : les cinq issues, la machine d'état (explorations vaines, repli sur les modules, nouvelle tentative) ;
    §5 prévoyance bornée et un seul chantier à la fois ;
    §6 branchement : le but « expansion » de la situation du cerveau (gardes, inertie, un chantier, données renommées),
       l'émission (site absent : bloqué et sites demandés ; site présent : kit puis construction) ;
    §7 aucun nom du jeu dans les fichiers de décision (règle anti-échelle de tests/iag_test.lua §8) ;
    §8 mutants : chaque règle retirée ou altérée est vue.
  Usage : lua5.2 tests/besoin_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/ai3/besoin.lua")

-- Tirage déterministe (congruentiel).
local function lcg(seed)
  local x = seed
  return function(n)
    x = (x * 1103515245 + 12345) % 2147483648
    return x % n
  end
end

local function load_be(src)
  local fn, err = load(src, "=besoin", "t")
  if not fn then return nil, err end
  local ok, mod = pcall(fn)
  if not ok then return nil, mod end
  return mod
end

---------------------------------------------------------------------------------------------------
-- Suite des règles pures (rejouée sur chaque mutant).
---------------------------------------------------------------------------------------------------
local function suite(Be)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m)
    if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
  end
  local function near(a, b) return math.abs(a - b) < 1e-9 end

  -- §1 Besoin.
  check(Be.factor(0, 10) == 1000 and Be.factor(nil, 10) == 1000, "§1 sans croissance, le facteur reste 1000")
  check(Be.factor(50, 10) == 1623 and Be.factor(50, 1) == 1050, "§1 facteur composé : 50 ‰ pendant 10 cycles = 1623 (" .. Be.factor(50, 10) .. ")")
  check(Be.factor(150, 10) == Be.FACTOR_MAX and Be.factor(9999, 10) == Be.FACTOR_MAX, "§1 facteur plafonné à " .. Be.FACTOR_MAX)
  check(Be.factor(-30, 10) == 1000, "§1 une croissance négative est ignorée")
  do
    local prev = 0
    local mono = true
    for g = 0, 150, 5 do
      local f = Be.factor(g, 10)
      if f < prev then mono = false end
      prev = f
    end
    check(mono, "§1 le facteur croît avec la croissance")
  end
  check(near(Be.rate_of_kept(500), 50) and Be.rate_of_kept(nil) == 0 and Be.rate_of_kept(-5) == 0,
    "§1 le besoin gardé se lit comme servi en " .. Be.H_GOALS .. " min")
  do
    local n, p = Be.need({ demand = 100, production = 40, stock = 0, factor = 1000 })
    check(near(n, 60) and near(p, 100), "§1 besoin = demande − production (" .. n .. ")")
    n, p = Be.need({ demand = 100, production = 40, stock = 0, factor = 1500 })
    check(near(n, 110) and near(p, 150), "§1 la croissance du capital augmente le besoin (" .. n .. ")")
    n = Be.need({ demand = 100, production = 150, stock = 0, factor = 1500 })
    check(n == 0, "§1 la production couvre la demande projetée : besoin nul")
    n = Be.need({ demand = 100, production = 0, stock = 5000, factor = 1500 })
    check(n == 0, "§1 des milliers en stock : besoin nul (« ils ont des milliers de cuivre »)")
    n = Be.need({ demand = 100, production = 0, stock = 100, factor = 1000 })
    check(near(n, 90), "§1 un stock couvre son débit pendant " .. Be.H_STOCK .. " min (" .. n .. ")")
    n = Be.need({})
    check(n == 0, "§1 entrée vide : besoin nul")
  end
  do
    -- Propriétés sur une grille : monotonie dans chaque variable.
    local ok_d, ok_f, ok_p, ok_s, ok_pos = true, true, true, true, true
    for _, base in ipairs({ { 80, 10, 50, 1000 }, { 10, 0, 0, 1400 }, { 300, 120, 900, 1100 } }) do
      local function nd(d, p, s, f) return (Be.need({ demand = d, production = p, stock = s, factor = f })) end
      for step = 1, 6 do
        if nd(base[1] + step * 7, base[2], base[3], base[4]) < nd(base[1], base[2], base[3], base[4]) then ok_d = false end
        if nd(base[1], base[2], base[3], base[4] + step * 90) < nd(base[1], base[2], base[3], base[4]) then ok_f = false end
        if nd(base[1], base[2] + step * 9, base[3], base[4]) > nd(base[1], base[2], base[3], base[4]) then ok_p = false end
        if nd(base[1], base[2], base[3] + step * 40, base[4]) > nd(base[1], base[2], base[3], base[4]) then ok_s = false end
        if nd(base[1], base[2] + step * 500, base[3], base[4]) < 0 then ok_pos = false end
      end
    end
    check(ok_d, "§1 le besoin ne baisse pas quand la demande monte")
    check(ok_f, "§1 le besoin ne baisse pas quand la croissance monte")
    check(ok_p, "§1 le besoin ne monte pas quand la production monte (« le besoin décroît quand la production le couvre »)")
    check(ok_s, "§1 le besoin ne monte pas quand le stock monte")
    check(ok_pos, "§1 le besoin n'est jamais négatif")
  end

  -- §2 Graphe de recettes. Format de shared/ai3/graphe.lua.
  local function rec(ings, prods) return { ingredients = ings, products = prods } end
  local function I(name, n) return { name = name, amount = n } end
  local R1 = {
    ["make-c"] = rec({ I("m", 2) }, { I("c", 1) }),         -- c : 2 m
    ["make-d"] = rec({ I("m", 5) }, { I("d", 1) }),         -- d : 5 m
    ["make-e"] = rec({ I("c", 3), I("m", 1) }, { I("e", 2) }), -- 2 e : 3 c + 1 m
    ["make-f"] = rec({ I("n", 1) }, { I("f", 1) }),
  }
  local fl = Be.flows(R1, { c = 10, d = 4, e = 6 })
  -- e : 6 → 3 fabrications → 9 c + 3 m ; c total 10 + 9 = 19 → 38 m ; d : 4 → 20 m ; e → 3 m. Total m = 38 + 20 + 3 = 61.
  local by = {}
  for _, e in ipairs(fl.cons.m or {}) do by[e.key] = e.rate end
  check(near(by.c or -1, 38) and near(by.d or -1, 20) and near(by.e or -1, 3), "§2 consommateurs directs de m : c 38, d 20, e 3 (" ..
    tostring(by.c) .. ", " .. tostring(by.d) .. ", " .. tostring(by.e) .. ")")
  check(near(fl.total.c, 19) and near(fl.total.m, 61), "§2 demande totale propagée : c 19, m 61 (" .. tostring(fl.total.m) .. ")")
  local cc = {}
  for _, e in ipairs(fl.cons.c or {}) do cc[e.key] = e.rate end
  check(near(cc.e or -1, 9), "§2 e consomme 9 c")
  check(fl.cons.n == nil, "§2 une matière que personne ne consomme n'a pas de consommateurs")
  do
    local keys, sorted = {}, true
    for _, e in ipairs(fl.cons.m) do keys[#keys + 1] = e.key end
    for i = 2, #keys do if keys[i - 1] > keys[i] then sorted = false end end
    check(sorted, "§2 consommateurs triés par clé")
    local f2 = Be.flows(R1, { c = 10, d = 4, e = 6 }, { materials = { m = true } })
    check(f2.cons.c == nil and f2.cons.m ~= nil, "§2 filtre des matières")
    local f3 = Be.flows(R1, { c = 10, d = 4, e = 6 })
    local same = #f3.cons.m == #fl.cons.m
    for i, e in ipairs(f3.cons.m) do if e.rate ~= fl.cons.m[i].rate or e.key ~= fl.cons.m[i].key then same = false end end
    check(same, "§2 déterministe")
  end
  -- Cycle de recettes : ni boucle ni plantage ; la part hors cycle est comptée.
  local RC = {
    ["a-from-b"] = rec({ I("b", 1), I("m", 1) }, { I("a", 1) }),
    ["b-from-a"] = rec({ I("a", 1) }, { I("b", 1) }),
  }
  do
    local ok, f = pcall(Be.flows, RC, { a = 5 })
    check(ok and f and f.cons.m ~= nil, "§2 cycle de recettes : le dépliage termine")
    check(ok and f and near(f.total.a, 5) and near(f.total.b, 5), "§2 cycle : l'arête qui boucle n'est pas propagée (a " .. tostring(ok and f and f.total.a) .. ")")
    local mm = 0
    if ok and f and f.cons.m then for _, e in ipairs(f.cons.m) do mm = mm + e.rate end end
    check(mm >= 5 - 1e-9, "§2 cycle : la matière directe est comptée (" .. mm .. ")")
  end
  -- Recette cachée ignorée ; choix de la recette par `pick`.
  do
    local RH = {
      ["x-hidden"] = { hidden = true, ingredients = { I("m", 100) }, products = { I("x", 1) } },
      ["x-open"] = rec({ I("m", 2) }, { I("x", 1) }),
    }
    local f = Be.flows(RH, { x = 3 })
    check(f.cons.m and near(f.cons.m[1].rate, 6), "§2 recette cachée ignorée")
    local RP = {
      ["x-a"] = rec({ I("m", 2) }, { I("x", 1) }),
      ["x-b"] = rec({ I("m", 7) }, { I("x", 1) }),
    }
    local f1 = Be.flows(RP, { x = 1 })
    local f2 = Be.flows(RP, { x = 1 }, { pick = function(_, l) return l[#l] end })
    check(near(f1.cons.m[1].rate, 2) and near(f2.cons.m[1].rate, 7), "§2 recette par nom, ou choisie par l'appelant")
  end

  -- §3 Équilibre.
  do
    local a = Be.allocate(100, { { key = "g", want = 60 }, { key = "s", want = 30 }, { key = "a", want = 90 } })
    check(near(a.lambda, 100 / 180), "§3 même fraction pour tous : 100 / 180")
    check(near(a.give.g, 60 * 100 / 180) and near(a.give.s, 30 * 100 / 180) and near(a.give.a, 90 * 100 / 180),
      "§3 parts proportionnelles aux besoins")
    local b = Be.allocate(500, { { key = "g", want = 60 }, { key = "s", want = 30 } })
    check(b.lambda == 1 and near(b.give.g, 60) and near(b.give.s, 30), "§3 offre suffisante : chacun reçoit son besoin")
    local z = Be.allocate(0, { { key = "g", want = 60 } })
    check(z.lambda == 0 and z.give.g == 0, "§3 offre nulle : rien")
    local e = Be.allocate(50, {})
    check(e.lambda == 1 and e.total == 0, "§3 aucun besoin")
  end
  do
    -- Propriété sur 400 tirages.
    local rnd = lcg(20261028)
    local ok_sum, ok_cap, ok_starve, ok_frac = true, true, true, true
    for _ = 1, 400 do
      local n = 1 + rnd(6)
      local wants, tot = {}, 0
      for i = 1, n do
        local w = rnd(5) == 0 and 0 or 1 + rnd(200)
        wants[i] = { key = "k" .. i, want = w }
        tot = tot + w
      end
      local supply = rnd(400)
      local r = Be.allocate(supply, wants)
      local sum = 0
      for _, w in ipairs(wants) do
        local g = r.give[w.key]
        sum = sum + g
        if g > w.want + 1e-9 then ok_cap = false end
        if supply > 0 and w.want > 0 and g <= 0 then ok_starve = false end
        if w.want > 0 and math.abs(g / w.want - r.lambda) > 1e-9 then ok_frac = false end
      end
      if sum > supply + 1e-6 then ok_sum = false end
    end
    check(ok_sum, "§3 la somme des parts ne dépasse jamais l'offre (400 tirages)")
    check(ok_cap, "§3 aucune part au-delà du besoin (400 tirages)")
    check(ok_starve, "§3 personne n'est affamé tant qu'il reste de l'offre (400 tirages)")
    check(ok_frac, "§3 tous reçoivent la même fraction de leur besoin (400 tirages)")
  end
  do
    -- Force brute : toutes les répartitions entières de petits cas ; aucune ne dépasse le plus petit taux de λ.
    local rnd = lcg(7)
    local ok_best, ok_reach, cases = true, true, 0
    for _ = 1, 60 do
      local n = 2 + rnd(2)
      local needs = {}
      for i = 1, n do needs[i] = 1 + rnd(7) end
      local supply = 1 + rnd(14)
      local wants = {}
      for i = 1, n do wants[i] = { key = "k" .. i, want = needs[i] } end
      local lam = Be.allocate(supply, wants).lambda
      local best = 0
      local alloc = {}
      local function rec_enum(i, left)
        if i > n then
          local mn = math.huge
          for j = 1, n do mn = math.min(mn, alloc[j] / needs[j]) end
          if mn > best then best = mn end
          return
        end
        for g = 0, math.min(needs[i], left) do
          alloc[i] = g
          rec_enum(i + 1, left - g)
        end
      end
      rec_enum(1, supply)
      cases = cases + 1
      if best > lam + 1e-9 then ok_best = false end
      -- λ est atteignable en réels : le meilleur entier n'est pas plus de 1 / min(besoin) en dessous.
      local mn = math.huge
      for j = 1, n do mn = math.min(mn, needs[j]) end
      if best < lam - 1 / mn - 1e-9 then ok_reach = false end
    end
    check(ok_best, "§3 force brute : aucune répartition entière ne fait mieux que λ sur le plus petit taux (" .. cases .. " cas)")
    check(ok_reach, "§3 force brute : λ est presque atteint par une répartition entière (écart ≤ 1 / plus petit besoin)")
  end
  check(Be.limit(100, 30, 20) == 30, "§3 limite : assez pour tous, la part entière")
  check(Be.limit(50, 30, 30) == 25 and Be.limit(50, 0, 30) == 0, "§3 limite : proportionnelle (25 sur 50)")
  check(Be.limit(0, 30, 30) == 0 and Be.limit(10, 30, nil) == 10 and Be.limit(40, 30, nil) == 30, "§3 limite : sans concurrent")
  do
    local ok = true
    for avail = 0, 120, 7 do
      for mine = 1, 50, 7 do
        for others = 0, 80, 11 do
          local l = Be.limit(avail, mine, others)
          if l > mine or l < 0 or l > avail then ok = false end
        end
      end
    end
    check(ok, "§3 limite : jamais plus que demandé ni que disponible, jamais négative")
  end

  -- §4 Déclencheur.
  do
    local ex = Be.new_ex()
    local function dec(m, tick) return Be.expansion(m, ex, tick) end
    local sat = { need = 20, sat_pct = 90, free_sites = 0 }
    local act, why = dec({ need = 0, sat_pct = 100 }, 0)
    check(act == "none" and why == "couvert", "§4 besoin nul : rien (" .. act .. ")")
    act = dec({ need = 20, sat_pct = 50, free_sites = 0 }, 0)
    check(act == "none", "§4 marge sur les gisements connus : rien")
    act = dec({ need = 20, sat_pct = nil }, 0)
    check(act == "none", "§4 exploitation inconnue : rien")
    act = dec({ need = 20, sat_pct = 79, free_sites = 0 }, 0)
    check(act == "none", "§4 79 % : pas encore")
    act = dec({ need = 20, sat_pct = 80, free_sites = 0 }, 0)
    check(act == "explore", "§4 80 % et un besoin, aucun site : explorer (" .. act .. ")")
    act = dec({ need = 20, sat_pct = 80, free_sites = 1 }, 5)
    check(act == "open", "§4 un site retenu : le bâtir (" .. act .. ")")
    act = dec({ need = 20, sat_pct = 60, free_sites = 0, yield_pct = 65 }, 6)
    check(act == "explore", "§4 rendement sous 70 % : même déclencheur (" .. act .. ")")
    act = dec({ need = 20, sat_pct = 60, free_sites = 0, yield_pct = 75 }, 6)
    check(act == "none", "§4 rendement correct, marge : rien")
    act = dec({ need = 20, sat_pct = 95, free_sites = 3, allowed = false }, 6)
    check(act == "none", "§4 garde du runtime : rien")
    -- Machine d'état : trois tentatives vaines puis les modules.
    ex = Be.new_ex()
    local t0 = 1000
    act = dec(sat, t0)
    check(act == "explore", "§4 tentative 1 commence")
    act = dec(sat, t0 + Be.TRY_TICKS - 1)
    check(act == "explore" and ex.tries == 0, "§4 tentative 1 en cours")
    act = dec(sat, t0 + Be.TRY_TICKS)
    check(act == "explore" and ex.tries == 1, "§4 tentative 1 vaine : on recommence (" .. ex.tries .. ")")
    act = dec(sat, t0 + 2 * Be.TRY_TICKS)
    check(act == "explore" and ex.tries == 2, "§4 tentative 2 vaine : on recommence")
    act = dec(sat, t0 + 3 * Be.TRY_TICKS)
    check(act == "productivite" and ex.tries == 3, "§4 trois tentatives vaines : les modules (" .. act .. ")")
    act = dec(sat, t0 + 3 * Be.TRY_TICKS + Be.RETRY_TICKS - 1)
    check(act == "productivite", "§4 les modules tiennent jusqu'à la nouvelle tentative")
    act = dec(sat, t0 + 3 * Be.TRY_TICKS + Be.RETRY_TICKS)
    check(act == "explore", "§4 nouvelle tentative après " .. math.floor(Be.RETRY_TICKS / 3600) .. " min (" .. act .. ")")
    act = dec(sat, t0 + 4 * Be.TRY_TICKS + Be.RETRY_TICKS + Be.TRY_TICKS)
    check(act == "productivite", "§4 une tentative de plus, vaine : les modules de nouveau")
    act = dec({ need = 20, sat_pct = 90, free_sites = 1 }, t0 + 99 * Be.TRY_TICKS)
    check(act == "open" and ex.tries == 0, "§4 un site apparaît : « open », compteur remis à zéro")
    -- Un besoin qui disparaît remet la tentative en cours à zéro mais garde les échecs.
    ex = Be.new_ex()
    dec(sat, 0)
    dec({ need = 0 }, 100)
    check(ex.since == nil, "§4 besoin disparu : tentative abandonnée")
  end

  -- §5 Prévoyance et un chantier à la fois.
  check(Be.ahead(0, 1) == 1 and Be.ahead(1, 1) == 0 and Be.ahead(0, 0) == 0 and Be.ahead(5, 3) == 0,
    "§5 prévoyance : un kit pour un site prêt, jamais en plus de ce qui dort")
  check(Be.ahead(0, 4) == Be.AHEAD_MAX, "§5 prévoyance bornée à " .. Be.AHEAD_MAX .. " kit(s) d'avance")
  do
    local c = { { key = "a", need = 10, projected = 100 }, { key = "b", need = 30, projected = 100 },
      { key = "c", need = 30, projected = 100 } }
    check(Be.pick(c) == "b", "§5 le plus pressé : plus grand déficit relatif, puis clé (" .. tostring(Be.pick(c)) .. ")")
    check(Be.pick({}) == nil, "§5 aucun candidat")
    c[1] = { key = "a", need = 50, projected = 60 }
    check(Be.pick(c) == "a", "§5 déficit relatif 83 % passe devant 30 %")
    local d = { { key = "x", need = 20, projected = 100 }, { key = "y", need = 40, projected = 200 } }
    check(Be.pick(d) == "y", "§5 à déficit relatif égal, le plus grand besoin")
  end
  return pass, fail, msgs
end

---------------------------------------------------------------------------------------------------
-- Règles réelles.
---------------------------------------------------------------------------------------------------
local Be = assert(load_be(SRC))
local failures = 0
local total_pass = 0
local function report(tag, pass, fail, msgs)
  total_pass = total_pass + pass
  failures = failures + fail
  for _, m in ipairs(msgs) do print("[BESOIN] ECHEC " .. tag .. " : " .. m) end
end
do
  local p, f, m = suite(Be)
  report("règles pures", p, f, m)
end

-- §2 bis : données du jeu (fixture des recettes) et dépliage récursif écrit à part.
do
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m) if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end end
  local recipes = dofile("tests/fixtures/recipes_ia1e.lua")
  local PL = T.outposts.iron.product
  -- Dépliage récursif de référence : coût en matière d'une unité d'objet (première recette par nom, sans cycle).
  local function reference(recipes_, item, mat, stack)
    if item == mat then return 1 end
    stack = stack or {}
    if stack[item] then return 0 end
    local names = {}
    for n, r in pairs(recipes_) do
      if not r.hidden then
        for _, p in ipairs(r.products) do if p.name == item then names[#names + 1] = n break end end
      end
    end
    table.sort(names)
    if #names == 0 then return 0 end
    local r = recipes_[names[1]]
    local per = 0
    for _, p in ipairs(r.products) do if p.name == item then per = p.amount end end
    stack[item] = true
    local sum = 0
    for _, ing in ipairs(r.ingredients) do sum = sum + ing.amount * reference(recipes_, ing.name, mat, stack) end
    stack[item] = nil
    return sum / per
  end
  local demand = { ["steel-plate"] = 2, ["iron-gear-wheel"] = 10, ["firearm-magazine"] = 30, ["automation-science-pack"] = 12 }
  local fl = Be.flows(recipes, demand, { materials = { [PL] = true } })
  local total, want = 0, 0
  for _, e in ipairs(fl.cons[PL] or {}) do total = total + e.rate end
  -- Débit direct + indirect : la somme des consommateurs directs = le coût total en plaque de la demande.
  for _, k in ipairs({ "steel-plate", "iron-gear-wheel", "firearm-magazine", "automation-science-pack" }) do
    want = want + demand[k] * reference(recipes, k, PL)
  end
  check(math.abs(total - want) < 1e-6 and total > 0, string.format("§2 données du jeu : somme des consommateurs directs %.2f = coût dépliée à part %.2f", total, want))
  local direct = {}
  for _, e in ipairs(fl.cons[PL] or {}) do direct[e.key] = e.rate end
  check(math.abs((direct["steel-plate"] or 0) - 10) < 1e-9, "§2 données du jeu : l'acier consomme 5 plaques par pièce (10 pour 2)")
  check(math.abs((direct["iron-gear-wheel"] or 0) - 20 - 0) < 1e-6 or (direct["iron-gear-wheel"] or 0) >= 20,
    "§2 données du jeu : les engrenages consomment 2 plaques par pièce, plus ceux des paquets")
  -- Renommage : toutes les clés changées, mêmes débits.
  local function rename(name) return "zz_" .. name:reverse() end
  local rr = {}
  for n, r in pairs(recipes) do
    local c = { hidden = r.hidden, ingredients = {}, products = {} }
    for _, i in ipairs(r.ingredients) do c.ingredients[#c.ingredients + 1] = { name = rename(i.name), amount = i.amount } end
    for _, p in ipairs(r.products) do c.products[#c.products + 1] = { name = rename(p.name), amount = p.amount } end
    rr[rename(n)] = c
  end
  local dem2 = {}
  for k, v in pairs(demand) do dem2[rename(k)] = v end
  local f2 = Be.flows(rr, dem2, { materials = { [rename(PL)] = true } })
  local same = #(f2.cons[rename(PL)] or {}) == #(fl.cons[PL] or {})
  local m2 = {}
  for _, e in ipairs(f2.cons[rename(PL)] or {}) do m2[e.key] = e.rate end
  for _, e in ipairs(fl.cons[PL] or {}) do
    if math.abs((m2[rename(e.key)] or -1) - e.rate) > 1e-6 then same = false end
  end
  check(same, "§2 données renommées : mêmes consommateurs et mêmes débits")
  -- Équilibre sur les données du jeu : la plaque ne suffit pas, chacun reçoit la même fraction.
  local wants = {}
  for _, e in ipairs(fl.cons[PL] or {}) do wants[#wants + 1] = { key = e.key, want = e.rate } end
  local sup = total / 3
  local al = Be.allocate(sup, wants)
  local starved = false
  for _, w in ipairs(wants) do if al.give[w.key] <= 0 then starved = true end end
  check(not starved and math.abs(al.lambda - 1 / 3) < 1e-9, "§3 données du jeu : plaque au tiers, chacun reçoit un tiers de son besoin, personne n'est affamé")
  report("données du jeu", pass, fail, msgs)
end

---------------------------------------------------------------------------------------------------
-- §6 Branchement : le but « expansion ».
---------------------------------------------------------------------------------------------------
local Ex = require("shared.ai3.expansion")
local P = require("shared.ai3.projets")
do
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m) if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end end
  local KIND = "iron"
  local PROD = T.outposts[KIND].product
  local MAXD = T.max_drills(KIND)
  local function sit(over)
    local s = {
      tick = 100000, is_player = false, economy_done = true, at_war = false,
      outposts = { { id = 1, kind = KIND, drills = MAXD, full = true } },
      sites = {}, pending = {}, stock = { [PROD] = 0 }, need = { [PROD] = 2000 },
      drill_rate = { coal = 15, iron = 15, copper = 15, stone = 15 }, growth = 50, weights = {},
    }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
  end
  local function fresh() return { army_done = 1 } end
  -- Cas nominal : le fer est plein (20 foreuses), la demande 200/min × 1,628 = 325 contre 300 produits : besoin 25.
  local s, st = sit(), fresh()
  local goals = Ex.goals({}, s, st, {})
  check(#goals == 1 and goals[1].key == "expansion:" .. KIND and goals[1].act == "explore" and goals[1].kind == "expansion",
    "§6 gisements pleins et besoin croissant, aucun site : but d'exploration (" .. #goals .. ")")
  check(st.exp[KIND].act == "explore" and st.exp[KIND].sat == 100, "§6 le journal garde la décision et l'exploitation")
  s = sit({ sites = { [KIND] = 1 } })
  goals = Ex.goals({}, s, fresh(), {})
  check(#goals == 1 and goals[1].act == "open", "§6 un site retenu : but d'ouverture")
  s = sit({ sites = { [KIND] = 1 }, outposts = { { id = 1, kind = KIND, drills = 4, full = false } } })
  goals = Ex.goals({}, s, fresh(), {})
  check(#goals == 0, "§6 un avant-poste à 4 foreuses sur 20 et un site libre : 4 sur 40, aucune expansion")
  s = sit({ need = { [PROD] = 100 } })
  check(#Ex.goals({}, s, fresh(), {}) == 0, "§6 besoin couvert par la production : aucun but")
  s = sit({ stock = { [PROD] = 6000 } })
  check(#Ex.goals({}, s, fresh(), {}) == 0, "§6 des milliers au stock : aucun but")
  s = sit()
  s.drill_rate = nil
  check(#Ex.goals({}, s, fresh(), {}) == 0, "§6 sans débit de foreuse lu : aucun but (comportement d'avant le lot)")
  s = sit({ economy_done = false })
  check(#Ex.goals({}, s, fresh(), {}) == 0, "§6 économie pas faite : aucun but")
  s = sit({ at_war = true })
  check(#Ex.goals({}, s, fresh(), {}) == 0, "§6 en guerre : aucun but")
  check(#Ex.goals({}, sit(), {}, {}) == 0, "§6 armée de départ pas faite (faction) : aucun but")
  check(#Ex.goals({}, sit({ is_player = true }), {}, {}) == 1, "§6 votre équipe n'a pas d'armée de départ à attendre")
  s = sit({ pending = { [KIND] = 1 } })
  check(#Ex.goals({}, s, fresh(), {}) == 0, "§6 chantier déjà en cours : aucun but")
  s = sit({ outposts = {} })
  check(#Ex.goals({}, s, fresh(), {}) == 0, "§6 aucun avant-poste de ce type (amorçage, pas expansion) : aucun but")
  s = sit({ growth = 0 })
  local n0 = (Ex.read(s, KIND)).need
  local n1 = (Ex.read(sit({ growth = 50 }), KIND)).need
  check(n0 < n1, "§6 la croissance du capital augmente le besoin (" .. n0 .. " < " .. n1 .. ")")
  -- Un seul chantier à la fois, le plus pressé ; inertie.
  local two = sit({ outposts = { { id = 1, kind = KIND, drills = MAXD, full = true },
    { id = 2, kind = "copper", drills = 12, full = true } },
    need = { [PROD] = 2000, [T.outposts.copper.product] = 2600 } })
  st = fresh()
  goals = Ex.goals({}, two, st, {})
  check(#goals == 1, "§6 deux types saturés : un seul but d'expansion (" .. #goals .. ")")
  local first = goals[1] and goals[1].outpost
  -- Le premier choisi reste choisi même si l'autre devient un peu plus pressé.
  two.need[PROD] = 2400
  goals = Ex.goals({}, two, st, {})
  check(goals[1] and goals[1].outpost == first, "§6 inertie : le chantier courant reste (" .. tostring(first) .. ")")
  -- Les modules : plus de but après trois explorations vaines.
  st = fresh()
  s = sit()
  for i = 0, 3 do
    s.tick = 100000 + i * Be.TRY_TICKS
    Ex.goals({}, s, st, {})
  end
  s.tick = 100000 + 3 * Be.TRY_TICKS
  goals = Ex.goals({}, s, st, {})
  check(#goals == 0 and st.exp[KIND].act == "productivite", "§6 exploration vaine trois fois : plus de but, décision « productivite » au journal")
  -- Valeur : poids de la famille.
  s = sit()
  local g1 = Ex.goals({}, s, fresh(), { extraction = 1000 })[1]
  local g2 = Ex.goals({}, s, fresh(), { extraction = 1500 })[1]
  check(g1.value == Ex.BASE and g2.value == math.floor(Ex.BASE * 1.5) and g1.value < 55, "§6 valeur " .. Ex.BASE .. " × poids de l'extraction, sous la croissance par manque (55)")
  -- Données RENOMMÉES : types, produits et places changés dans T, mêmes décisions.
  do
    local saved = T.outposts
    local savedmax = T.outpost_max
    local savedorder = T.OUTPOST_ORDER
    T.outposts = {
      qq = { resource = "q-ore", sink = "kiln", product = "q-bar", drills = 5 },
      rr = { resource = "r-ore", sink = "kiln", product = "r-bar", drills = 3 },
    }
    T.OUTPOST_ORDER = { "qq", "rr" }
    T.outpost_max = { qq = 10 }
    local s3 = {
      tick = 5000, economy_done = true, at_war = false, sites = {}, pending = {},
      outposts = { { id = 1, kind = "qq", drills = 10, full = false }, { id = 2, kind = "rr", drills = 2, full = false } },
      stock = {}, need = { ["q-bar"] = 1500, ["r-bar"] = 1500 }, drill_rate = { qq = 12, rr = 12 }, growth = 50,
    }
    local st3 = { army_done = 1 }
    local g = Ex.goals({}, s3, st3, {})
    check(#g == 1 and g[1].outpost == "qq" and g[1].why == "q-bar", "§6 données renommées : le type saturé (10 sur 10) déclenche, l'autre (2 sur 12) non")
    s3.sites = { qq = 1 }
    g = Ex.goals({}, s3, { army_done = 1 }, {})
    check(#g == 1 and g[1].act == "open", "§6 données renommées : site retenu, ouverture")
    T.outposts, T.outpost_max, T.OUTPOST_ORDER = saved, savedmax, savedorder
  end
  -- Émission.
  do
    local function book(handcraft) return { handcraftable = function() return handcraft end,
      plan = function(_, _, avail) return { raw = {}, crafts = {}, avail = avail, uses = {} } end } end
    local function ctx(view, avail, hand)
      return P.context(avail or {}, book(hand or false), view, { projects = {} })
    end
    local emit = Ex.emit(P)
    local function view(over)
      local v = { pending = {}, sites = {}, outposts = {}, open = {}, defend_first = false }
      for k, x in pairs(over or {}) do v[k] = x end
      return v
    end
    local proj = { id = 7, key = "expansion:" .. KIND, prio = 70 }
    local g = { outpost = KIND }
    local E = ctx(view())
    local r, why = emit(E, proj, g)
    check(r == "bloque" and why == "site:" .. KIND and E.site_needs[KIND] == 1,
      "§6 émission sans site : bloqué « site:" .. KIND .. " » et sites demandés (" .. tostring(r) .. ")")
    check(#E.tasks == 0 and next(E.raw) == nil, "§6 émission sans site : aucun kit fabriqué d'avance (prévoyance)")
    E = ctx(view({ sites = { [KIND] = 1 } }), {})
    r = emit(E, proj, g)
    check(r == "matiere" and E.site_needs[KIND] == 1, "§6 émission avec site, kit absent : « matière » (" .. tostring(r) .. ")")
    local function kit()
      local a = {}
      for _, it in ipairs(require("shared.team.planner").outpost_items(KIND)) do a[it[1]] = it[2] end
      return a
    end
    E = ctx(view({ sites = { [KIND] = 1 } }), kit())
    r = emit(E, proj, g)
    check(r == "ok" and #E.tasks == 1 and E.tasks[1].kind == "build" and E.tasks[1].outpost_kind == KIND and E.tasks[1].key == "build:" .. KIND,
      "§6 émission avec site et kit : tâche de construction d'un NOUVEL avant-poste (" .. tostring(r) .. ")")
    E = ctx(view({ sites = { [KIND] = 1 }, open = { ["build:" .. KIND] = true } }), kit())
    check(emit(E, proj, g) == "en_cours", "§6 construction déjà ouverte : en cours")
    E = ctx(view({ sites = { [KIND] = 1 }, pending = { [KIND] = 1 } }), kit())
    check(emit(E, proj, g) == "en_cours", "§6 avant-poste en chantier : en cours")
    check(select(1, emit(ctx(view()), proj, { outpost = "inconnu" })) == "bloque", "§6 type inconnu : bloqué")
    -- Défendre d'abord : tourelles du kit du 2e avant-poste de ce type.
    local v = view({ sites = { [KIND] = 1 }, defend_first = true, outposts = { { id = 1, kind = KIND, drills = 20, full = true } } })
    local av2 = kit()
    av2[P.TURRET] = 9
    av2[T.turret_ammo] = 999
    E = ctx(v, av2, true)
    r = emit(E, proj, g)
    local has_turret = false
    for _, it in ipairs((E.tasks[1] or {}).items or {}) do if it[1] == P.TURRET then has_turret = true end end
    check(r == "ok" and has_turret, "§6 le kit du nouvel avant-poste porte ses tourelles (couverture)")
  end
  -- Déterminisme.
  do
    local a, b = fresh(), fresh()
    local ga = Ex.goals({}, sit(), a, {})
    local gb = Ex.goals({}, sit(), b, {})
    check(ga[1].key == gb[1].key and ga[1].value == gb[1].value and a.exp[KIND].need == b.exp[KIND].need, "§6 déterminisme")
  end
  report("branchement", pass, fail, msgs)
end

---------------------------------------------------------------------------------------------------
-- §7 Aucun nom du jeu dans les fichiers de décision de ce lot (la règle générale est tests/iag_test.lua §8).
---------------------------------------------------------------------------------------------------
do
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m) if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end end
  local recipes = dofile("tests/fixtures/recipes_ia1e.lua")
  local names = {}
  for name, r in pairs(recipes) do
    names[name] = true
    for _, p in ipairs(r.products) do names[p.name] = true end
    for _, i in ipairs(r.ingredients) do names[i.name] = true end
  end
  for _, kind in ipairs(T.OUTPOST_ORDER) do names[T.outposts[kind].product] = true names[T.outposts[kind].resource] = true end
  for _, file in ipairs({ "shared/ai3/besoin.lua", "shared/ai3/expansion.lua", "script/ai3/besoin.lua" }) do
    local code = read(file):gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
    local hits = {}
    local keys = {}
    for k in pairs(names) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, name in ipairs(keys) do
      if name:match("^[%a_][%w_]*$") then
        if code:find("%f[%w_]" .. name .. "%f[^%w_]") then hits[#hits + 1] = name end
      elseif code:find('"' .. name .. '"', 1, true) then hits[#hits + 1] = '"' .. name .. '"' end
    end
    check(#hits == 0, "§7 " .. file .. " nomme " .. table.concat(hits, " "))
  end
  check(not read("shared/ai3/besoin.lua"):find("require", 1, true), "§7 shared/ai3/besoin.lua ne requiert rien (règles pures autonomes)")
  report("anti-échelle", pass, fail, msgs)
end

---------------------------------------------------------------------------------------------------
-- §8 Mutants : chaque règle altérée est vue (la suite des règles pures, §1 à §5, les voit).
---------------------------------------------------------------------------------------------------
local MUTANTS = {
  { "le facteur ne plafonne plus", "if f >= Be.FACTOR_MAX then return Be.FACTOR_MAX end", "" },
  { "la production n'est plus soustraite", "- math.max(0, m.production or 0) -", "- 0 -" },
  { "le stock n'est plus compté", "- math.max(0, m.stock or 0) / Be.H_STOCK", "" },
  { "le facteur n'est plus appliqué", "local projected = math.max(0, m.demand or 0) * f / 1000", "local projected = math.max(0, m.demand or 0)" },
  { "besoin négatif possible", "if need < 0 then need = 0 end", "" },
  { "croissance négative acceptée", "local gg = clamp(math.floor(g or 0), 0, Be.G_MAX)", "local gg = math.floor(g or 0)" },
  { "allocation gloutonne (le premier prend tout)", "lambda = supply > 0 and supply / total or 0", "lambda = supply > 0 and supply / total * 1.5 or 0" },
  { "l'offre n'est plus plafonnée", "if total > supply then lambda", "if total > supply * 2 then lambda" },
  { "part au-delà du besoin", "give[w.key] = math.max(0, w.want or 0) * lambda", "give[w.key] = math.max(0, w.want or 0) * lambda + 1" },
  { "limite sans proportion", "return math.floor(math.max(0, avail) * mine / tot)", "return math.floor(math.max(0, avail))" },
  { "seuil de saturation 90", "Be.SAT_PCT = 80", "Be.SAT_PCT = 90" },
  { "seuil de saturation 50", "Be.SAT_PCT = 80", "Be.SAT_PCT = 50" },
  { "le rendement ne déclenche plus", "or (m.yield_pct ~= nil and m.yield_pct < Be.YIELD_PCT)", "" },
  { "garde ignorée", "if m.allowed == false then ex.since = nil return \"none\", \"garde\" end", "" },
  { "besoin nul n'éteint plus", "if (m.need or 0) < Be.NEED_MIN then ex.since = nil return \"none\", \"couvert\" end", "" },
  { "un site retenu n'ouvre plus", "return \"open\", \"site\"", "return \"explore\", \"site\"" },
  { "les modules n'arrivent jamais", "return \"productivite\", \"exploration vaine\" end\n  end\n  if not ex.since", "return \"explore\", \"x\" end\n  end\n  if not ex.since" },
  { "pas de nouvelle tentative", "if tick - (ex.last_fail or 0) >= Be.RETRY_TICKS then", "if false then" },
  { "prévoyance sans borne", "local n = math.min(soon or 0, Be.AHEAD_MAX) - math.max(0, stock or 0)", "local n = (soon or 0) - math.max(0, stock or 0)" },
  { "prévoyance qui ignore le stock", "- math.max(0, stock or 0)\n  return n > 0", "\n  return n > 0" },
  { "chantier le moins pressé", "elseif rel ~= bk.rel then better = rel > bk.rel", "elseif rel ~= bk.rel then better = rel < bk.rel" },
  { "cycle de recettes non coupé", "if (pos[ing.name] or 0) < i then", "if true then" },
  { "recettes cachées utilisées", "if not r.hidden then\n      for _, p in ipairs(r.products or {}) do", "if true then\n      for _, p in ipairs(r.products or {}) do" },
}
do
  local refused, kept = 0, {}
  for _, m in ipairs(MUTANTS) do
    local i, j = SRC:find(m[2], 1, true)
    if not i then
      kept[#kept + 1] = m[1] .. " (motif introuvable)"
    else
      local src = SRC:sub(1, i - 1) .. m[3] .. SRC:sub(j + 1)
      local mod, err = load_be(src)
      local seen = false
      if not mod then seen = true
      else
        local ok, p, f = pcall(suite, mod)
        if not ok or f > 0 then seen = true end
      end
      if seen then refused = refused + 1 else kept[#kept + 1] = m[1] end
    end
  end
  if #kept > 0 then
    failures = failures + #kept
    print("[BESOIN] ECHEC : mutants NON refusés : " .. table.concat(kept, " ; "))
  end
  total_pass = total_pass + refused
  print(string.format("[BESOIN] mutants refusés : %d sur %d", refused, #MUTANTS))
end

print(string.format("[BESOIN] BILAN : %d OK, %d ECHEC(S)", total_pass, failures))
if failures > 0 then os.exit(1) end
