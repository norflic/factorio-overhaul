--[[
  Lot AMELIORATION-CONTINUE (directive du DC, 8/11, 18 h 40 : « Amélioration Continue (Upgrade Continu) : Les PNJ ne doivent jamais
  s'arrêter. Disposant d'une automatisation totale de la production, ils doivent enchaîner la pose de structures en boucle et remplacer
  en continu les vieux convoyeurs/bras par leurs versions supérieures. ») : test hors jeu des règles pures
  (shared/ai3/amelioration.lua : Am.fab, Am.run_order, Am.parc ; shared/ai3/capital.lua : Cap.replace_candidates, Cap.goal, Cap.emit).

    §1 orientation (Am.run_order) : une ligne se suit, l'aval d'abord, les lignes l'une après l'autre ; sans position, par numéro ;
       invariant par permutation ; l'entrée n'est pas modifiée ;
    §2 le BLOC entier est demandé : stock vide, le lot payable est 1 mais le lot demandé est le bloc (au plus 12) ; éteint (ctx.continu
       absent), la décision est celle d'avant (aucun champ nouveau) ;
    §3 émission : stock virtuel vide -> 12 fabrications demandées (1 avant) ; stock partiel -> payé tout de suite ET le reste du bloc demandé ;
    §4 finir le bloc : le groupe payé à la décision précédente garde la tête à score égal ;
    §5 obtenable : un rang (tapis, bras) à monter en nombre réclame la recherche de sa cible non débloquée ; une machine seule, un petit
       nombre, ou la règle éteinte : non ;
    §6 parc : pièces par rang, part montée ;
    §7 BOUCLE simulée (décision, émission, paiement, fabrication limitée) : la boucle continue monte plus de pièces que l'ancienne, sans
       jamais s'arrêter tant qu'une pièce de rang inférieur existe et que la fabrication tourne ;
    §8 coût : une décision sur 5 000 pièces remplaçables sous 300 000 instructions (5 ms, debug.sethook) ;
    §9 MUTANTS : chaque règle réécrite fausse est vue par au moins un contrôle.
  Usage : lua5.2 tests/amelioration_continue_test.lua   (depuis la racine du mod)
]]

package.path = "./?.lua;" .. package.path
local L = require("shared.levels.config")
local Book = require("shared.team.book")
local P = require("shared.ai3.projets")

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local QUIET = false
local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if not QUIET then print("[AMELIORATION-CONTINUE] ECHEC : " .. msg) end
  end
  return cond
end
local function say(s) if not QUIET then print("[AMELIORATION-CONTINUE] " .. s) end end

local CC = L.by_key.command
local recipes = dofile("tests/fixtures/recipes_ia1e.lua")
local book = Book.new(recipes)

-- Monde de tapis et de bras (vitesses des prototypes vanilla 1.1.91, groupes de remplacement rapide) : aucun nom dans la règle, seulement ici.
local MP = {
  ["transport-belt"] = { type = "transport-belt", group = "belt", w = 1, h = 1, energy = "none", cats = {}, speed = 0.03125, item = "transport-belt", rang = true },
  ["fast-transport-belt"] = { type = "transport-belt", group = "belt", w = 1, h = 1, energy = "none", cats = {}, speed = 0.0625, item = "fast-transport-belt", rang = true },
  ["express-transport-belt"] = { type = "transport-belt", group = "belt", w = 1, h = 1, energy = "none", cats = {}, speed = 0.09375, item = "express-transport-belt", rang = true },
  ["inserter"] = { type = "inserter", group = "ins", w = 1, h = 1, energy = "electric", cats = {}, speed = 0.014, item = "inserter", reach = "r", rang = true },
  ["fast-inserter"] = { type = "inserter", group = "ins", w = 1, h = 1, energy = "electric", cats = {}, speed = 0.04, item = "fast-inserter", reach = "r", rang = true },
  ["stone-furnace"] = { type = "furnace", group = "furn", w = 2, h = 2, energy = "burner", cats = { smelting = true }, speed = 1, item = "stone-furnace" },
  ["steel-furnace"] = { type = "furnace", group = "furn", w = 2, h = 2, energy = "burner", cats = { smelting = true }, speed = 2, item = "steel-furnace" },
}
local NAMES = {}
for n in pairs(MP) do NAMES[#NAMES + 1] = n end
table.sort(NAMES)
local UNIT = { ["fast-transport-belt"] = 12, ["express-transport-belt"] = 40, ["fast-inserter"] = 14, ["steel-furnace"] = 30,
  ["transport-belt"] = 3, ["inserter"] = 6, ["stone-furnace"] = 5 }
local RICH = { ["iron-plate"] = 20000, ["copper-plate"] = 20000, ["iron-gear-wheel"] = 2000, ["electronic-circuit"] = 2000, ["stone-brick"] = 2000, ["steel-plate"] = 2000 }

local function base_ctx(over)
  local c = { proto = function() return nil end, unit_cost = function(item) return UNIT[item] end, stock = {}, weights = {}, cc_level = 3,
    mproto = function(n) return MP[n] end, machines = NAMES, continu = true }
  for k, v in pairs(over or {}) do c[k] = v end
  return c
end

--- Ligne de n tapis sur l'axe horizontal y = `y`, du x0 en avant, direction `dir`, numéros croissants dans l'ordre du tracé.
local function line(list, id0, name, block, n, x0, y, dir, vertical)
  for i = 1, n do
    local x, yy = x0 + i - 1, y
    if vertical then x, yy = y, x0 + i - 1 end
    list[#list + 1] = { id = id0 + i, name = name, working = true, block = block, x = x, y = yy, dir = dir }
  end
  return list
end

local function census_of(machines) return { list = {}, center = { id = 1, name = L.name(CC, 2) }, machines = machines } end

local function run(Cap, Am, quiet)
  QUIET = quiet or false
  pass, fail = 0, 0

  ---------------------------------------------------------------------------------------------------
  -- §1 Orientation
  ---------------------------------------------------------------------------------------------------
  do
    local function ids_of(list) local o = {} for i, m in ipairs(list) do o[i] = m.id end return o end
    local function same(a, b)
      if #a ~= #b then return false end
      for i = 1, #a do if a[i] ~= b[i] then return false end end
      return true
    end
    local east = line({}, 100, "transport-belt", "p1", 6, 0, 0, 2)          -- flux vers l'est : l'aval est à l'est (x grand)
    local west = line({}, 200, "transport-belt", "p1", 6, 0, 0, 6)          -- flux vers l'ouest : l'aval est à l'ouest (x petit)
    local south = line({}, 300, "transport-belt", "p1", 6, 0, 3, 4, true)   -- flux vers le sud : l'aval est au sud (y grand)
    local north = line({}, 400, "transport-belt", "p1", 6, 0, 3, 0, true)   -- flux vers le nord : l'aval est au nord (y petit)
    local function xs(list, key) local o = {} for i, m in ipairs(list) do o[i] = m[key] end return o end
    check(same(xs(Am.run_order(east), "x"), { 5, 4, 3, 2, 1, 0 }), "§1 flux vers l'est : l'aval (x grand) d'abord")
    check(same(xs(Am.run_order(west), "x"), { 0, 1, 2, 3, 4, 5 }), "§1 flux vers l'ouest : l'aval (x petit) d'abord")
    check(same(xs(Am.run_order(south), "y"), { 5, 4, 3, 2, 1, 0 }), "§1 flux vers le sud : l'aval (y grand) d'abord")
    check(same(xs(Am.run_order(north), "y"), { 0, 1, 2, 3, 4, 5 }), "§1 flux vers le nord : l'aval (y petit) d'abord")
    -- Deux lignes parallèles mêlées dans le relevé : une ligne entière, puis l'autre.
    local two = {}
    line(two, 500, "transport-belt", "p1", 5, 0, 7, 2)
    line(two, 600, "transport-belt", "p1", 5, 0, 2, 2)
    local mixed = {}
    for i = 1, 5 do mixed[#mixed + 1] = two[i]; mixed[#mixed + 1] = two[5 + i] end
    local ord = Am.run_order(mixed)
    local ys = xs(ord, "y")
    check(same(ys, { 2, 2, 2, 2, 2, 7, 7, 7, 7, 7 }), "§1 deux lignes : la ligne y = 2 entière, puis la ligne y = 7")
    -- Une pièce sans position ou sans direction va à la fin, par numéro.
    local odd = { { id = 9 }, { id = 3, x = 0, y = 0 }, { id = 5, x = 4, y = 1, dir = 2 }, { id = 1, x = 1, y = 1, dir = 2 } }
    check(same(ids_of(Am.run_order(odd)), { 5, 1, 3, 9 }), "§1 sans position ou sans direction : à la fin, par numéro (" .. table.concat(ids_of(Am.run_order(odd)), ",") .. ")")
    -- Invariance par permutation de l'entrée, entrée intacte.
    local all = {}
    for _, l in ipairs({ east, west, south, north }) do for _, m in ipairs(l) do all[#all + 1] = m end end
    local ref = ids_of(Am.run_order(all))
    local okperm = true
    local seed = 7
    for _ = 1, 25 do
      local cp = {}
      for i, m in ipairs(all) do cp[i] = m end
      for i = #cp, 2, -1 do
        seed = (seed * 1103515245 + 12345) % 2147483648
        local j = seed % i + 1
        cp[i], cp[j] = cp[j], cp[i]
      end
      if not same(ids_of(Am.run_order(cp)), ref) then okperm = false end
    end
    check(okperm, "§1 l'ordre ne dépend pas de l'ordre du relevé")
    local before = ids_of(all)
    Am.run_order(all)
    check(same(ids_of(all), before), "§1 l'entrée n'est pas modifiée")
    -- Am.first_n : les n premières de run_order, sans tout trier (douze sur plusieurs tailles, sur la liste mêlée).
    local okfirst = true
    for _, n in ipairs({ 1, 5, 12, 30, 200 }) do
      local want = ids_of(Am.run_order(all))
      local got = ids_of(Am.first_n(all, n))
      for i = 1, math.min(n, #want) do if got[i] ~= want[i] then okfirst = false end end
      if #got ~= math.min(n, #want) then okfirst = false end
    end
    check(okfirst, "§1 Am.first_n(liste, n) = les n premières de Am.run_order(liste)")
  end

  ---------------------------------------------------------------------------------------------------
  -- §2 Le bloc entier est demandé
  ---------------------------------------------------------------------------------------------------
  local D2
  do
    local ms = {}
    line(ms, 1000, "transport-belt", "p1", 20, 0, 0, 2)
    line(ms, 2000, "transport-belt", "p2", 8, 0, 5, 2)
    local rc = Cap.replace_candidates(L, census_of(ms), base_ctx({ stock = {} }))
    table.sort(rc, function(a, b) return a.key < b.key end)
    check(#rc == 2, "§2 un lot par bloc (" .. #rc .. ")")
    local c1, c2 = rc[1], rc[2]
    check(c1.replace.n == 1 and c1.n == 1 and #c1.ids == 1, "§2 stock vide : le lot PAYABLE est 1")
    check(c1.fab == 12, "§2 stock vide : le lot DEMANDÉ est 12, le bloc de 20 borné à 12 (" .. tostring(c1.fab) .. ")")
    check(c2.fab == 8, "§2 un bloc de 8 pièces : 8 demandées (" .. tostring(c2.fab) .. ")")
    check(c1.unit and c1.unit[1][1] == "fast-transport-belt" and c1.unit[1][2] == 1, "§2 l'unité du paiement partiel est la cible, une pièce")
    check(c1.ids[1] == 1020, "§2 la première pièce est l'AVAL de la ligne (flux est : x = 19, numéro 1020) : " .. tostring(c1.ids[1]))
    local rc5 = Cap.replace_candidates(L, census_of(ms), base_ctx({ stock = { ["fast-transport-belt"] = 5 } }))
    table.sort(rc5, function(a, b) return a.key < b.key end)
    check(rc5[1].n == 5 and #rc5[1].ids == 5 and rc5[1].fab == 12, "§2 cinq pièces au stock : cinq payables, douze demandées")
    check(rc5[1].ids[1] == 1020 and rc5[1].ids[5] == 1016, "§2 les cinq payées se SUIVENT le long de la ligne, en aval (1020 à 1016)")
    local off = Cap.replace_candidates(L, census_of(ms), base_ctx({ stock = {}, continu = false }))
    table.sort(off, function(a, b) return a.key < b.key end)
    check(off[1].fab == nil and off[1].unit == nil and off[1].group == nil and off[1].ids[1] == 1001,
      "§2 règle éteinte : la décision d'avant (ni lot demandé, ni unité, ordre par numéro)")
    D2 = Cap.choose(L, census_of(ms), base_ctx({ stock = {} }))
    check(D2.replace and D2.fab == 12 and D2.n == 1, "§2 Cap.choose garde le lot demandé (" .. tostring(D2.fab) .. ")")
    local g = Cap.goal(D2, {})
    check(g.fab == 12 and g.unit and g.n == 1 and g.replace == true, "§2 le but porte le lot demandé, l'unité et le nombre payable")
    local goff = Cap.goal(Cap.choose(L, census_of(ms), base_ctx({ stock = {}, continu = false })), {})
    check(goff.fab == nil and goff.unit == nil and goff.n == nil, "§2 règle éteinte : le but d'avant")
  end

  ---------------------------------------------------------------------------------------------------
  -- §3 Émission
  ---------------------------------------------------------------------------------------------------
  do
    local ms = {}
    line(ms, 1000, "transport-belt", "p1", 20, 0, 0, 2)
    local function goal_for(stock)
      return Cap.goal(Cap.choose(L, census_of(ms), base_ctx({ stock = stock })), {})
    end
    local function emit(avail, goal, idle)
      local E = P.context(avail, book, { open = {}, workers_idle = idle or 0 }, {})
      E.view = { workers_idle = idle or 0 }
      local st = Cap.emit(P)(E, { id = 3, key = goal.key, prio = 50 }, goal)
      local crafted = 0
      for _, t in ipairs(E.tasks) do if t.kind == "craft" and t.item == "fast-transport-belt" then crafted = crafted + t.count end end
      return st, E, crafted
    end
    local av = {}
    for k, v in pairs(RICH) do av[k] = v end
    local st0, E0, c0 = emit(av, goal_for({}), 0)
    check(st0 == "matiere" and c0 == 12 and not E0.pay, "§3 stock vide, aucun PNJ libre : 12 tapis rapides demandés à la fabrication, rien à payer (" .. c0 .. ")")
    local off = Cap.goal(Cap.choose(L, census_of(ms), base_ctx({ stock = {}, continu = false })), {})
    local _, _, coff = emit(av, off, 0)
    check(coff == 1, "§3 règle éteinte : UN tapis rapide à la fois (" .. coff .. ")")
    -- Stock complet pour 3 : payé (3) ET les 9 autres demandés.
    local av3 = {}
    for k, v in pairs(RICH) do av3[k] = v end
    av3["fast-transport-belt"] = 3
    local st3, E3, c3 = emit(av3, goal_for({ ["fast-transport-belt"] = 3 }), 0)
    check(st3 == "ok" and E3.pay and E3.pay[1].n == 3 and c3 == 9, "§3 trois au stock : trois payés, neuf demandés (" .. tostring(E3.pay and E3.pay[1].n) .. ", " .. c3 .. ")")
    -- Stock libre de 5 mais stock VIRTUEL de 2 (le reste est promis ailleurs) : deux payés, dix demandés.
    local av2 = {}
    for k, v in pairs(RICH) do av2[k] = v end
    av2["fast-transport-belt"] = 2
    local st2, E2, c2 = emit(av2, goal_for({ ["fast-transport-belt"] = 5 }), 0)
    check(st2 == "ok" and E2.pay and E2.pay[1].n == 2 and #E2.pay[1].cost == 1 and E2.pay[1].cost[1][2] == 2 and c2 == 10,
      "§3 cinq au stock libre, deux au virtuel : deux payés, dix demandés (" .. tostring(E2.pay and E2.pay[1].n) .. ", " .. c2 .. ")")
    -- Bloc de 20 entièrement au stock : douze payés, rien à demander.
    local av20 = {}
    for k, v in pairs(RICH) do av20[k] = v end
    av20["fast-transport-belt"] = 40
    local st20, E20, c20 = emit(av20, goal_for({ ["fast-transport-belt"] = 40 }), 0)
    check(st20 == "ok" and E20.pay[1].n == 12 and c20 == 0, "§3 douze payables sur douze demandés : rien de plus à fabriquer (" .. c20 .. ")")
    -- Un bloc de BÂTIMENTS À NIVEAUX (foreuses, fours, assembleurs) : avec des PNJ libres, le bloc entier est demandé ; SANS PNJ libre, seulement
    -- ce que le stock virtuel permet de fabriquer, sans jamais réclamer de matière brute à l'extraction (règle des bras libres d'IA-G gardée).
    local gb = { key = "capital:bloc", cost = { { "iron-gear-wheel", 3 } }, target = "bloc", bloc = "p1", n = 1,
      unit = { { "iron-gear-wheel", 3 } }, fab = 6 }
    local function gears_for(avail, idle)
      local Eb = P.context(avail, book, { open = {}, workers_idle = idle }, {})
      Eb.view = { workers_idle = idle }
      local sb = Cap.emit(P)(Eb, { id = 4, key = gb.key, prio = 50 }, gb)
      local gears, raws = 0, 0
      for _, t in ipairs(Eb.tasks) do if t.kind == "craft" and t.item == "iron-gear-wheel" then gears = gears + t.count end end
      for _ in pairs(Eb.raw or {}) do raws = raws + 1 end
      return sb, gears, raws
    end
    local sb, g_idle0, r_idle0 = gears_for({ ["iron-plate"] = 500 }, 0)
    check(sb == "matiere" and g_idle0 == 18 and r_idle0 == 0, "§3 bloc de bâtiments sans PNJ libre, fer au stock : les 6 mises à niveau sont fabriquées par le premier PNJ libre (" .. g_idle0 .. " engrenages)")
    local _, g_poor, r_poor = gears_for({ ["iron-plate"] = 20 }, 0)
    check(g_poor == 9 and r_poor == 0, "§3 sans PNJ libre et fer (20 plaques) pour 3 mises à niveau seulement : 3 demandées (9 engrenages), aucune matière brute réclamée (" .. g_poor .. ", " .. r_poor .. ")")
    local _, g_none, r_none = gears_for({}, 0)
    check(g_none == 0 and r_none == 0, "§3 sans PNJ libre ni fer : rien n'est demandé, aucune matière brute réclamée à l'extraction (" .. g_none .. ", " .. r_none .. ")")
    local _, g_idle2 = gears_for({ ["iron-plate"] = 500 }, 2)
    check(g_idle2 == 18, "§3 avec des PNJ libres, le bloc de bâtiments demande les 6 mises à niveau (18 engrenages) : " .. g_idle2)
  end

  ---------------------------------------------------------------------------------------------------
  -- §4 Finir le bloc entamé
  ---------------------------------------------------------------------------------------------------
  do
    local ms = {}
    line(ms, 1000, "transport-belt", "p1", 12, 0, 0, 2)
    line(ms, 2000, "transport-belt", "p2", 12, 0, 5, 2)
    local d0 = Cap.choose(L, census_of(ms), base_ctx({ stock = {} }))
    check(d0.replace and d0.replace.group:sub(1, 2) == "p1", "§4 à score égal, le groupe de plus petite clé : p1 (" .. tostring(d0.replace and d0.replace.group) .. ")")
    local d1 = Cap.choose(L, census_of(ms), base_ctx({ stock = {}, last_group = d0.replace.group:gsub("^p1", "p2") }))
    check(d1.replace and d1.replace.group:sub(1, 2) == "p2", "§4 le groupe payé à la décision précédente garde la tête : p2 (" .. tostring(d1.replace and d1.replace.group) .. ")")
    local d2 = Cap.choose(L, census_of(ms), base_ctx({ stock = {}, last_group = "inconnu" }))
    check(d2.replace and d2.replace.group:sub(1, 2) == "p1", "§4 un groupe disparu ne change rien")
  end

  ---------------------------------------------------------------------------------------------------
  -- §5 Obtenable : le rang à monter en nombre réclame sa recherche
  ---------------------------------------------------------------------------------------------------
  do
    local function LOCKED(item) return item ~= "fast-transport-belt" and item ~= "express-transport-belt" and item ~= "fast-inserter" and item ~= "steel-furnace" end
    local function wanted_for(count, name, over)
      local ms = {}
      line(ms, 1000, name, "p1", count, 0, 0, 2)
      local d = Cap.choose(L, census_of(ms), base_ctx(over or { available = LOCKED }))
      local b
      for _, x in ipairs(d.blocked) do if x.family == "remplacer" then b = x end end
      return d, b
    end
    -- Le rang réclamé passe par d.rang_wanted (le runtime le déclare par Voulues.set) ; Capital.wanted (d.wanted) n'est pas touchée.
    local d30, b30 = wanted_for(30, "transport-belt")
    check(d30.replace == nil and b30 and b30.rang_want == true and d30.rang_wanted["fast-transport-belt"] == true and d30.wanted["fast-transport-belt"] == nil,
      "§5 30 tapis, cible non débloquée : l'OBJET du tapis rapide est voulu (rang_wanted), d.wanted inchangé")
    local d23, b23 = wanted_for(23, "transport-belt")
    check(b23 and not b23.rang_want and next(d23.rang_wanted) == nil, "§5 23 tapis (< 24) : rien de voulu")
    local di, bi = wanted_for(40, "inserter")
    check(bi and bi.rang_want == true and di.rang_wanted["fast-inserter"] == true, "§5 40 bras : l'objet du bras rapide est voulu")
    local df, bf = wanted_for(40, "stone-furnace")
    check(bf and not bf.rang_want and next(df.rang_wanted) == nil, "§5 40 fours de pierre : ce n'est pas un rang, rien de voulu par le remplacement")
    local do_, bo = wanted_for(30, "transport-belt", { available = LOCKED, continu = false })
    check(bo and not bo.rang_want and next(do_.rang_wanted) == nil, "§5 règle éteinte : rien de voulu (comportement d'avant)")
    -- Modules posés avec des bras simples (RECHERCHE-BRAS B) : dès que le bras rapide est obtenable, le bloc de bras simples du module est un
    -- candidat de 12 demandés, orienté.
    do
      local mm = {}
      line(mm, 5000, "inserter", "p3", 14, 0, 4, 2)
      local dm = Cap.choose(L, census_of(mm), base_ctx({ available = function() return true end }))
      check(dm.replace and dm.replace.from == "inserter" and dm.replace.to == "fast-inserter" and dm.fab == 12 and dm.replace.group:sub(1, 2) == "p3",
        "§5 module à bras simples : candidat de 12 dès que le bras rapide est obtenable (" .. tostring(dm.replace and dm.replace.to) .. ", lot " .. tostring(dm.fab) .. ")")
    end
    -- Dès que la cible est débloquée, le remplacement commence (plus aucune cause de blocage).
    local ms = {}
    line(ms, 1000, "transport-belt", "p1", 30, 0, 0, 2)
    local dd = Cap.choose(L, census_of(ms), base_ctx({ available = function() return true end }))
    check(dd.replace and dd.replace.to == "fast-transport-belt", "§5 cible débloquée : le remplacement est décidé")
  end

  ---------------------------------------------------------------------------------------------------
  -- §6 Parc
  ---------------------------------------------------------------------------------------------------
  do
    local ms = {}
    for i = 1, 6 do ms[#ms + 1] = { name = "transport-belt" } end
    for i = 1, 3 do ms[#ms + 1] = { name = "fast-transport-belt" } end
    for i = 1, 1 do ms[#ms + 1] = { name = "express-transport-belt" } end
    for i = 1, 2 do ms[#ms + 1] = { name = "inserter" } end
    local rows = Am.parc(ms, function(n) return MP[n] end, NAMES)
    check(#rows == 2 and rows[1].key == "inserter/ins" and rows[2].key == "transport-belt/belt", "§6 un groupe par type et groupe de remplacement, triés")
    local belt = rows[2]
    check(belt.total == 10 and belt.up == 4 and #belt.tiers == 3 and belt.tiers[1].name == "transport-belt" and belt.tiers[3].name == "express-transport-belt",
      "§6 tapis : 10 pièces, 4 montées, trois rangs par vitesse croissante")
    check(rows[1].total == 2 and rows[1].up == 0, "§6 bras : aucun monté")
    check(Am.parc_line(belt) == "transport-belt/belt : transport-belt 6, fast-transport-belt 3, express-transport-belt 1 ; montees 4/10 (40%)",
      "§6 la ligne du journal : " .. Am.parc_line(belt))
    -- Un parc sans plus aucune pièce du plus bas rang : le plus bas rang du CATALOGUE sert de référence (tout est monté).
    local only = {}
    for _ = 1, 4 do only[#only + 1] = { name = "fast-transport-belt" } end
    local r2 = Am.parc(only, function(n) return MP[n] end, NAMES)
    check(r2[1].up == 4 and r2[1].total == 4, "§6 tout au-dessus du plus bas rang du catalogue : 4/4 montées")
    local r3 = Am.parc(only, function(n) return MP[n] end)
    check(r3[1].up == 0, "§6 sans catalogue, le plus bas rang VU sert de référence")
  end

  ---------------------------------------------------------------------------------------------------
  -- §7 Boucle simulée : décision, émission, paiement, fabrication limitée
  ---------------------------------------------------------------------------------------------------
  local function simulate(continu, pensees, fab_rate)
    local ms = {}
    line(ms, 1000, "transport-belt", "p1", 40, 0, 0, 2)
    line(ms, 2000, "transport-belt", "p2", 40, 0, 5, 2)
    line(ms, 3000, "inserter", "p1", 24, 0, 9, 2)
    local stock = {}
    local last_group
    local upgraded, gaps, gap, best_gap = 0, 0, 0, 0
    local per_pensee = {}
    for t = 1, pensees do
      local lower = 0
      for _, m in ipairs(ms) do if m.name == "transport-belt" or m.name == "inserter" then lower = lower + 1 end end
      local ctx = base_ctx({ stock = stock, continu = continu and true or false, last_group = continu and last_group or nil })
      local d = Cap.choose(L, census_of(ms), ctx)
      local paid = 0
      local crafts = {}
      if d.replace then
        local g = Cap.goal(d, {})
        local av = {}
        for k, v in pairs(RICH) do av[k] = v end
        for k, v in pairs(stock) do av[k] = v end
        local E = P.context(av, book, { open = {}, workers_idle = 0 }, {})
        E.view = { workers_idle = 0 }
        Cap.emit(P)(E, { id = 5, key = g.key, prio = 50 }, g)
        for _, tk in ipairs(E.tasks) do if tk.kind == "craft" then crafts[tk.item] = (crafts[tk.item] or 0) + tk.count end end
        for _, pay in ipairs(E.pay or {}) do
          local n = pay.n or #d.ids
          local item = d.replace.to
          local k = 0
          for i = 1, math.min(n, #d.ids) do
            if (stock[item] or 0) < 1 then break end
            local id = d.ids[i]
            for _, m in ipairs(ms) do
              if m.id == id then m.name = d.replace.to; k = k + 1; stock[item] = stock[item] - 1 end
            end
          end
          paid = paid + k
          last_group = d.replace.group
        end
      end
      upgraded = upgraded + paid
      per_pensee[#per_pensee + 1] = paid
      -- Fabrication à la main : au plus fab_rate objets par pensée, dans l'ordre des demandes (tapis rapides d'abord par clé).
      local left = fab_rate
      for _, item in ipairs({ "fast-inserter", "fast-transport-belt" }) do
        local k = math.min(crafts[item] or 0, left)
        if k > 0 then stock[item] = (stock[item] or 0) + k; left = left - k end
      end
      if lower > 0 and paid == 0 then gap = gap + 1; if gap > best_gap then best_gap = gap end else gap = 0 end
    end
    return upgraded, best_gap, per_pensee
  end
  do
    local on, gap_on = simulate(true, 80, 2)
    local off, gap_off = simulate(false, 80, 2)
    say(string.format("§7 80 pensées, fabrication 2 pièces par pensée : boucle continue %d pièces montées (plus longue pause %d), ancienne %d (pause %d)", on, gap_on, off, gap_off))
    check(on >= 2.5 * off and off >= 1, "§7 la boucle continue monte au moins 2,5 fois plus de pièces que l'ancienne (" .. on .. " contre " .. off .. ")")
    check(gap_on <= 1, "§7 la boucle continue ne s'arrête jamais plus d'une pensée tant qu'une pièce de rang inférieur existe (" .. gap_on .. ")")
    check(on == 104 and off <= 45, "§7 la boucle continue finit les 104 pièces en 80 pensées, l'ancienne n'en monte que " .. off .. " (" .. on .. ")")
    -- Fabrication lente : 1 pièce par pensée -> la boucle suit exactement le débit de la fabrication.
    local on1 = simulate(true, 60, 1)
    check(on1 >= 55, "§7 fabrication à 1 pièce par pensée : la boucle monte presque une pièce par pensée (" .. on1 .. ")")
    -- Tout est fini : le bloc de 104 pièces (40 + 40 + 24) est monté en entier, puis plus rien (pas de boucle folle).
    local all = simulate(true, 120, 4)
    check(all == 104, "§7 les 104 pièces sont montées, ni plus ni moins (" .. all .. ")")
  end

  ---------------------------------------------------------------------------------------------------
  -- §8 Coût d'une décision sur un grand parc
  ---------------------------------------------------------------------------------------------------
  do
    local function parc(blocs)
      local ms = {}
      local id = 10000
      for b = 1, blocs do
        for l = 1, 10 do
          line(ms, id, "transport-belt", "p" .. b, 20, 0, l * 2, (l % 2 == 0) and 2 or 6)
          id = id + 100
        end
      end
      for b = 1, blocs do line(ms, id, "inserter", "p" .. b, 40, 0, 40, 2); id = id + 100 end
      for b = 1, math.floor(blocs / 2) do line(ms, id, "stone-furnace", "p" .. b, 12, 0, 50, 2); id = id + 100 end
      return ms
    end
    local function cost(ms)
      local ctx = base_ctx({ stock = { ["fast-transport-belt"] = 3 } })
      local worst = 0
      for _ = 1, 3 do
        local n = 0
        debug.sethook(function() n = n + 1 end, "", 1000)
        local d = Cap.choose(L, census_of(ms), ctx)
        debug.sethook()
        if n > worst then worst = n end
        assert(d.replace)
      end
      return worst
    end
    local ms3 = parc(12)
    local w3 = cost(ms3)
    local w5 = cost(parc(20))
    say(string.format("§8 une décision sur %d pièces remplaçables : %d milliers d'instructions (budget 300) ; sur 4 920 pièces : %d milliers", #ms3, w3, w5))
    check(w3 <= 300, "§8 une décision sur " .. #ms3 .. " pièces sous 300 000 instructions (5 ms) : " .. w3 .. " milliers")
    check(w5 <= 450, "§8 une décision sur 4 920 pièces sous 450 000 instructions : " .. w5 .. " milliers")
  end

  return pass, fail
end

---------------------------------------------------------------------------------------------------
-- Règle réelle, puis MUTANTS
---------------------------------------------------------------------------------------------------
local CapReal = require("shared.ai3.capital")
local AmReal = require("shared.ai3.amelioration")
local p0, f0 = run(CapReal, AmReal, false)
say(string.format("règle réelle : %d OK, %d ECHEC(S)", p0, f0))

local SRC_CAP = read("shared/ai3/capital.lua")
local SRC_AM = read("shared/ai3/amelioration.lua")

--- Charge une copie MUTANTE : `which` = "cap" ou "am". Rend Cap, Am (le module non muté est le vrai).
local function mutant(which, old, new)
  local src = which == "cap" and SRC_CAP or SRC_AM
  local i, j = src:find(old, 1, true)
  assert(i, "mutant : motif introuvable : " .. old)
  assert(not src:find(old, j + 1, true), "mutant : motif multiple : " .. old)
  local text = src:sub(1, i - 1) .. new .. src:sub(j + 1)
  local saved = package.loaded["shared.ai3.amelioration"]
  local am
  if which == "am" then
    am = assert(load(text, "=mutantAm", "t"))()
    package.loaded["shared.ai3.amelioration"] = am
    local cap = assert(load(SRC_CAP, "=capSousMutantAm", "t"))()
    package.loaded["shared.ai3.amelioration"] = saved
    return cap, am
  end
  local cap = assert(load(text, "=mutantCap", "t"))()
  return cap, AmReal
end

local n_mut, n_caught = 0, 0
local function M(name, which, old, new)
  n_mut = n_mut + 1
  local cap, am = mutant(which, old, new)
  local ok, p, f = pcall(run, cap, am, true)
  local caught = (not ok) or (f > 0)
  if caught then n_caught = n_caught + 1 else print("[AMELIORATION-CONTINUE] mutant survivant : " .. name) end
  QUIET = false
  say("§9 mutant « " .. name .. " » : " .. (caught and "refusé" or "SURVIVANT"))
end
M("lot demandé réduit à une pièce", "cap", "Am.fab(total, Cap.REPLACE_BATCH)", "1")
M("reste du bloc non demandé après un paiement", "cap", "      rest(g.n or 1)", "")
M("reste du bloc non demandé après un paiement partiel", "cap", "      res = \"ok\"\n      rest(part)", "      res = \"ok\"")
M("l'unité du paiement partiel n'est pas passée au but", "cap", "unit = (d.bloc or d.fab) and d.unit or nil,", "unit = d.bloc and d.unit or nil,")
M("orientation ignorée (ordre par numéro)", "cap", "local mem = ctx.continu and Am.first_n(grp.members, n) or grp.members", "local mem = grp.members")
M("inertie du groupe retirée", "cap", "if ctx.last_group and c.group and c.group == ctx.last_group then", "if false and ctx.last_group and c.group and c.group == ctx.last_group then")
M("recherche du rang jamais réclamée", "cap", "local want = ctx.continu and p0 and p0.rang and (count[pd.name] or 0) >= Am.RESEARCH_MIN", "local want = false")
M("recherche réclamée pour toute machine", "cap", "local want = ctx.continu and p0 and p0.rang and (count[pd.name] or 0) >= Am.RESEARCH_MIN", "local want = ctx.continu")
M("seuil de recherche ignoré", "cap", "(count[pd.name] or 0) >= Am.RESEARCH_MIN", "(count[pd.name] or 0) >= 1")
M("amont d'abord", "am", "if axis == \"h\" then return 1, m.y, -sign * m.x end", "if axis == \"h\" then return 1, m.y, sign * m.x end")
M("lignes mêlées (la ligne n'est pas la clé)", "am", "if axis == \"h\" then return 1, m.y, -sign * m.x end\n  return 2, m.x, -sign * m.y", "if axis == \"h\" then return 1, 0, -sign * m.x end\n  return 2, 0, -sign * m.y")
M("axe ignoré", "am", "if a[1] ~= b[1] then return a[1] < b[1] end", "")
M("amont d'abord dans first_n", "am", "-signs[d] * x else", "signs[d] * x else")
M("les n premières prises dans l'ordre du relevé", "am", "if nk < n or ax < wax or (ax == wax and (ln < worst[2] or (ln == worst[2] and (al < worst[3] or (al == worst[3] and m.id < worst[4]))))) then", "if nk < n then")
M("part montée comptée au rang bas aussi", "am", "if t.speed > floor_speed then up = up + t.n end", "if t.speed >= floor_speed then up = up + t.n end")
M("lot demandé jamais borné", "am", "return math.max(1, math.min(cap or Am.FAB_MAX, total or 1))", "return math.max(1, total or 1)")
M("lot demandé borné à une pièce", "am", "return math.max(1, math.min(cap or Am.FAB_MAX, total or 1))", "return 1")
M("bloc de bâtiments sans PNJ libre : tout demandé, matière brute comprise", "cap", "local f = feasible(k)\n        if f > 0 then", "local f = k\n        if f > 0 then")
M("bloc de bâtiments sans PNJ libre : plus rien demandé", "cap", "local f = feasible(k)\n        if f > 0 then", "local f = 0\n        if f > 0 then")
M("évaluation non mémorisée coûte trop (mesure de coût)", "cap", "local e = memo[name]\n    if e then return e end", "local e = nil")

QUIET = false
say(string.format("BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", p0, f0, n_caught, n_mut))
if f0 > 0 or n_caught < n_mut then os.exit(1) end
