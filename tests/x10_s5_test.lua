--[[
  Lot S5 du ×10 (FOSWAP et DICHOTOMIE) : preuves hors jeu (fo-logs/2026-11-07_X10/S5_CRITERES.md §3).
    P1 monotonie de la faisabilité de Book:plan en n (vrai livre recipes_ia1e et livres synthétiques), 0 violation sous la garde ;
    P2 même (m, q) que les boucles linéaires des trois appelants (copies exactes de l'ancien code) ; Bm.feasible = plan sans brut ;
    P3 mutants de shared/team/book_max.lua ;
    P4 coût en instructions (debug.sethook, compte 1) et mémoire allouée par appel, avant et après ;
    P5, P6 (relevé de FoSwap, S.plan) : partie foswap, reportée après la fusion de corr-foreuses-th (consigne du lead, 7/11) ;
    P7 Recon.craft_spares avec le mémo (Recon.S5) = sans (témoin) : tâches, registre, journaux ;
    P8 mutants de P7 ;
    P9 Rc.demand avec les clés triées une fois (sans le tri de Rc.due) = Rc.demand d'avant ; mutants ; coût à 635 pièces.
  Graine fixe, déterministe. Usage : lua5.2 tests/x10_s5_test.lua [--court]   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local COURT = arg and arg[1] == "--court"
local ok_n, ko_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 else ko_n = ko_n + 1 print("  ECHEC : " .. msg) end
end
local function read(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end

-- RNG maison (Park-Miller, produits < 2^53) --------------------------------------------------------------------------------------
local function Rng(seed)
  local s = seed % 2147483647
  if s <= 0 then s = s + 2147483646 end
  local r = {}
  function r.next() s = (s * 16807) % 2147483647 return s end
  function r.int(a, b) return a + (r.next() % (b - a + 1)) end
  function r.float() return r.next() / 2147483647 end
  function r.pick(t) return t[r.int(1, #t)] end
  return r
end

local function sorted_keys(t)
  local k = {}
  for key in next, t do k[#k + 1] = key end
  table.sort(k, function(a, b) return tostring(a) < tostring(b) end)
  return k
end

local function deep_eq(a, b, seen)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then
    if type(a) == "number" and type(b) == "number" and a ~= a and b ~= b then return true end
    return false
  end
  for k, v in next, a do if not deep_eq(v, b[k]) then return false end end
  for k in next, b do if a[k] == nil then return false end end
  return true
end

local function copy(t)
  local o = {}
  for k, v in next, t do o[k] = v end
  return o
end

local function count_instr(fn)
  local c = 0
  debug.sethook(function() c = c + 1 end, "", 1)
  local r1, r2 = fn()
  debug.sethook()
  return c, r1, r2
end

local function alloc_kb(fn)
  collectgarbage("collect")
  collectgarbage("stop")
  local a = collectgarbage("count")
  fn()
  local b = collectgarbage("count")
  collectgarbage("restart")
  return b - a
end

local Book = require("shared.team.book")
local Bm = require("shared.team.book_max")
local T = require("shared.team.config")

-- 0. MAX_DEPTH : exporté par book.lua (Book.MAX_DEPTH = la locale de `need`), lu par book_max sans copie ----------------------------
do
  local d = read("shared/team/book.lua"):match("local MAX_DEPTH = (%d+)")
  check(type(Book.MAX_DEPTH) == "number" and tonumber(d) == Book.MAX_DEPTH,
    "Book.MAX_DEPTH (" .. tostring(Book.MAX_DEPTH) .. ") = la locale MAX_DEPTH de shared/team/book.lua (" .. tostring(d) .. ")")
  local src = read("shared/team/book_max.lua")
  check(not src:find("MAX_DEPTH%s*=%s*%d") and select(2, src:gsub("Book%.MAX_DEPTH", "")) >= 2,
    "book_max.lua lit Book.MAX_DEPTH et n'en garde aucune copie")
end

-- 1. Cas : livres, objets, stocks ---------------------------------------------------------------------------------------------------
local RECIPES = dofile("tests/fixtures/recipes_ia1e.lua")
local function name_hash(s, seed)
  local h = seed
  for i = 1, #s do h = (h * 31 + s:byte(i)) % 1000003 end
  return h
end
local real_books = { Book.new(RECIPES) }
for _, sd in ipairs({ 11, 23, 37 }) do
  real_books[#real_books + 1] = Book.new(RECIPES, { allowed = function(name) return name_hash(name, sd) % 10 < 8 end })
end
local CALLER_ITEMS = { "electric-mining-drill", "burner-mining-drill", "small-electric-pole", "medium-electric-pole", "big-electric-pole",
  "substation", "boiler", "steam-engine", "offshore-pump", "pump", "solar-panel", "accumulator", "gun-turret", "stone-furnace" }
local ALL_NAMES = {}
for _, k in ipairs(sorted_keys(RECIPES)) do
  for _, p in ipairs(RECIPES[k].products) do ALL_NAMES[#ALL_NAMES + 1] = p.name end
  for _, i in ipairs(RECIPES[k].ingredients) do ALL_NAMES[#ALL_NAMES + 1] = i.name end
end

local function recipe(name, ings, amount)
  local list = {}
  for _, ig in ipairs(ings) do list[#list + 1] = { type = "item", name = ig[1], amount = ig[2] } end
  return { category = "crafting", energy = 1, hidden = false, ingredients = list, products = { { type = "item", name = name, amount = amount or 1 } } }
end

--- Livre synthétique : DAG (ingrédients d'indice plus petit), produits par 1 à 3, quelques cycles, chaînes longues, quantités non entières.
local function synth_book(r)
  local n = r.int(8, 40)
  local leaves = r.int(2, 6)
  local rec = {}
  for i = leaves + 1, n do
    local ings = {}
    local k = r.int(1, 4)
    for _ = 1, k do
      local j = r.int(1, i - 1)
      if r.int(1, 100) <= 6 then j = r.int(1, n) end -- cycle possible
      local a = r.int(1, 5)
      local u = r.int(1, 100)
      if u <= 2 then a = 0 elseif u <= 4 then a = 0.5 end
      ings[#ings + 1] = { "s" .. j, a }
    end
    local u = r.int(1, 100)
    local per = (u <= 60 and 1) or (u <= 85 and 2) or (u <= 95 and 3) or 1.5
    rec["r" .. i] = recipe("s" .. i, ings, per)
  end
  if r.int(1, 100) <= 25 then -- chaîne de 11 à 15 niveaux au-dessus du sommet
    local top = "s" .. n
    local len = r.int(11, 15)
    local prev = top
    for c = 1, len do
      local nm = "c" .. c
      rec["rc" .. c] = recipe(nm, { { prev, r.int(1, 2) } }, r.int(1, 2))
      prev = nm
    end
    rec["rtop"] = recipe("top", { { prev, 1 }, { "s" .. r.int(leaves + 1, n), r.int(1, 3) } }, 1)
  end
  return Book.new(rec), (rec["rtop"] and "top" or ("s" .. n))
end

--- Contre-exemple construit (coupure de profondeur) : R = P + C1 ; P = X ; X par 2 depuis Z ; C1 (par 100) → … → C11 = X.
--- X est demandé à la profondeur 2 (par P) puis à la profondeur 12 (par C11, coupé) : faisable seulement quand n est impair.
local function depth_book()
  local rec = {}
  rec.R = recipe("R", { { "P", 1 }, { "C1", 1 } }, 1)
  rec.P = recipe("P", { { "X", 1 } }, 1)
  rec.X = recipe("X", { { "Z", 1 } }, 2)
  for c = 1, 10 do rec["C" .. c] = recipe("C" .. c, { { "C" .. (c + 1), 1 } }, 100) end
  rec.C11 = recipe("C11", { { "X", 1 } }, 100)
  return Book.new(rec)
end

local function stock_for(r, book, item, noise)
  local st = {}
  local sh = Bm.shape(book, item)
  local base = book:plan({ { item, 1 } }, {}).raw
  for _, it in ipairs(sh.items) do
    local u = r.int(1, 100)
    if u <= 35 then st[it] = 0
    elseif u <= 60 then st[it] = r.int(1, 12)
    elseif u <= 72 then st[it] = r.int(40, 400)
    elseif u <= 74 then st[it] = r.int(1, 20) + 0.5      -- non entier : hors de la garde
    elseif u <= 75 then st[it] = r.int(1, 60) / 10       -- au dixième : arrondis flottants
    elseif u <= 77 then st[it] = -r.int(1, 5)            -- négatif
    end
  end
  for _, k in ipairs(sorted_keys(base)) do
    if r.int(1, 100) <= 80 then st[k] = math.floor(base[k] * r.float() * 9) end -- autour du seuil, de 0 à 9 objets
  end
  for _ = 1, noise do st[r.pick(ALL_NAMES)] = r.int(0, 300) end
  return st
end

local function handcraftables(book)
  local out = {}
  for _, k in ipairs(sorted_keys(book.by_product)) do out[#out + 1] = k end
  return out
end
local HC = {}
for i, b in ipairs(real_books) do HC[i] = handcraftables(b) end

local N_CASES = COURT and 2000 or 10000
local cases = {}
do
  local r = Rng(20261107)
  local depth = depth_book()
  for c = 1, N_CASES do
    local book, item
    local u = r.int(1, 100)
    if u <= 60 then
      local bi = r.int(1, #real_books)
      book = real_books[bi]
      item = (r.int(1, 100) <= 60) and r.pick(CALLER_ITEMS) or r.pick(HC[bi])
    elseif u <= 97 then
      book, item = synth_book(r)
    else
      book, item = depth, "R"
    end
    local st = stock_for(r, book, item, r.int(0, 20))
    if book == depth then -- la chaîne C1 … C11 doit être fabriquée (rien au stock) pour atteindre la coupure de profondeur
      for k in next, st do st[k] = nil end
      st.Z = r.int(0, 10)
    end
    cases[c] = { book = book, item = item, stock = st }
  end
end

local function truth(book, item, n, stock)
  return next(book:plan({ { item, n } }, stock).raw) == nil
end

-- P1 : monotonie -----------------------------------------------------------------------------------------------------------------
local NMAX = 8
do
  local guarded, viol_g, viol_free, counter = 0, 0, 0, {}
  local feas_bad = 0
  for c, cs in ipairs(cases) do
    local book, item = cs.book, cs.item
    local st = copy(cs.stock)
    st[item] = 0
    local f = {}
    for n = 1, NMAX + 1 do
      f[n] = truth(book, item, n, st)
      if Bm.feasible(book, item, n, st) ~= f[n] then feas_bad = feas_bad + 1 end
      -- variante « objet lu comme 0 » sur le stock non modifié (rebuild_rapide.obtainable, Recon.available_or_craftable)
      if Bm.feasible(book, item, n, cs.stock, item) ~= f[n] then feas_bad = feas_bad + 1 end
    end
    local bad = false
    for n = 1, NMAX do if f[n + 1] and not f[n] then bad = true end end
    local g = Bm.monotone(book, item, st)
    if g then guarded = guarded + 1 end
    if bad then
      if g then viol_g = viol_g + 1 else viol_free = viol_free + 1 end
      if #counter < 6 then
        local s = {}
        for n = 1, NMAX + 1 do s[#s + 1] = f[n] and "1" or "0" end
        local sh = Bm.shape(book, item)
        counter[#counter + 1] = string.format("cas %d, objet %s, faisable(1..%d) = %s, garde : %s (hauteur %d, forme %s)", c, item, NMAX + 1,
          table.concat(s), tostring(g), sh.height, tostring(sh.ok))
      end
    end
  end
  print(string.format("[X10-S5] P1 : %d cas, %d sous la garde (théorème), violations de monotonie : %d sous la garde, %d hors de la garde",
    #cases, guarded, viol_g, viol_free))
  for _, l in ipairs(counter) do print("[X10-S5] P1 contre-exemple hors garde : " .. l) end
  check(viol_g == 0, "P1 : aucune violation de monotonie sous la garde (" .. viol_g .. ")")
  check(guarded >= #cases / 2, "P1 : la garde couvre au moins la moitié des cas (" .. guarded .. ")")
  check(viol_free > 0, "P1 : les livres synthétiques produisent des contre-exemples hors de la garde (sinon la garde ne serait pas éprouvée)")
  check(feas_bad == 0, "P1 : Bm.feasible = (plan sans matière brute) sur tous les cas et tous les n (" .. feas_bad .. " écarts)")
end

-- P2 : même (m, q) que les boucles linéaires des trois appelants ------------------------------------------------------------------
-- Copies EXACTES de l'ancien code (d96f61ed), rendues en (m, q).
local function old_foswap(book, item, want, avail)            -- script/team/foreuse_swap.lua:215-224
  local q = book:plan({ { item, want } }, avail)
  if next(q.raw) ~= nil then
    local found = false
    for m = want - 1, 1, -1 do
      local q2 = book:plan({ { item, m } }, avail)
      if next(q2.raw) == nil then q, want, found = q2, m, true break end
    end
    if not found then return 0, q end
  end
  return want, q
end
local function old_rr(book, item, n, avail)                   -- script/team/rebuild_rapide.lua:125-130
  local qp = book:plan({ { item, n } }, avail)
  for m = n - 1, 1, -1 do
    if next(qp.raw) == nil then break end
    qp, n = book:plan({ { item, m } }, avail), m
  end
  if next(qp.raw) ~= nil then return 0, qp end
  return n, qp
end
local function old_recon(book, item, n, avail)                -- script/team/reconstruction.lua:572-580
  local q = book:plan({ { item, n } }, avail)
  if next(q.raw) ~= nil then
    for m = n - 1, 1, -1 do
      local q2 = book:plan({ { item, m } }, avail)
      if next(q2.raw) == nil then q, n = q2, m break end
    end
  end
  if next(q.raw) == nil then return n, q end
  return 0, q
end

local function p2_run(B, label, quiet)
  local bad, runs, first = 0, 0, nil
  local plans_old, plans_new = 0, 0
  for c, cs in ipairs(cases) do
    local book, item = cs.book, cs.item
    local avail = copy(cs.stock)
    avail[item] = 0
    local before = copy(avail)
    -- (le plan rendu avec m = 0 n'est lu que par reconstruction, pour le journal « matiere manquante » : foreuse_swap et rebuild_rapide
    -- rendent 0 sans le lire ; l'ancien rebuild_rapide gardait alors le plan de 1, le nouveau le plan de n)
    for _, pair in ipairs({ { old_foswap, 4, false }, { old_rr, 6, false }, { old_recon, 6, true }, { old_recon, 9, true } }) do
      local old, cap, q_read = pair[1], pair[2], pair[3]
      local n = 1 + (c % cap)
      runs = runs + 1
      local m0, q0 = old(book, item, n, avail)
      local m1, q1 = B.best(book, item, n, avail)
      local same = m0 == m1 and deep_eq(avail, before)
      if same and (m0 > 0 or q_read) then
        same = deep_eq(q0.crafts, q1.crafts) and deep_eq(q0.uses, q1.uses) and deep_eq(q0.raw, q1.raw) and deep_eq(q0.avail, q1.avail)
      end
      if not same then
        bad = bad + 1
        if not first then first = string.format("cas %d (%s, n = %d) : ancien m = %d, nouveau m = %s", c, item, n, m0, tostring(m1)) end
      end
    end
  end
  if not quiet then print(string.format("[X10-S5] P2 %s : %d recherches, %d écarts%s", label, runs, bad, first and (" ; premier : " .. first) or "")) end
  return bad, runs
end

do
  local bad = p2_run(Bm, "dichotomie gardée")
  check(bad == 0, "P2 : même m et même plan que les trois boucles linéaires (" .. bad .. " écarts)")
  Bm.DICHO = false
  local bad2 = p2_run(Bm, "témoin linéaire (Bm.DICHO = false)")
  Bm.DICHO = true
  check(bad2 == 0, "P2 : témoin linéaire (test léger seul) : même m et même plan (" .. bad2 .. " écarts)")
  -- Suite d'objets de Recon.craft_spares : l'avail est entamé d'objet en objet (copie exacte de la boucle, sans le journal).
  local r = Rng(77)
  local seq_bad = 0
  local NSEQ = COURT and 300 or 1500
  for s = 1, NSEQ do
    local bi = r.int(1, #real_books)
    local book = real_books[bi]
    local wanted = {}
    for _ = 1, r.int(1, 4) do wanted[#wanted + 1] = { r.pick(CALLER_ITEMS), r.int(1, 6) } end
    local free = stock_for(r, book, wanted[1][1], 30)
    local function run(newcode)
      local avail = {}
      for _, k in ipairs(sorted_keys(free)) do avail[k] = free[k] end
      local added = {}
      for _, w in ipairs(wanted) do
        local item, n = w[1], w[2]
        if book:handcraftable(item) then
          local saved = avail[item]
          avail[item] = 0
          local q
          if newcode then
            local m
            m, q = Bm.best(book, item, n, avail)
            if m > 0 then n = m end
          else
            q = book:plan({ { item, n } }, avail)
            if next(q.raw) ~= nil then
              for m = n - 1, 1, -1 do
                local q2 = book:plan({ { item, m } }, avail)
                if next(q2.raw) == nil then q, n = q2, m break end
              end
            end
          end
          avail[item] = saved
          if next(q.raw) == nil then
            local uses = sorted_keys(q.uses)
            local list = {}
            for _, k in ipairs(uses) do list[#list + 1] = { k, q.uses[k] } end
            added[#added + 1] = { item = item, count = n, steps = q.crafts, uses = list }
            for _, u in ipairs(list) do if u[1] ~= item then avail[u[1]] = (avail[u[1]] or 0) - u[2] end end
          else
            added[#added + 1] = { item = item, miss = sorted_keys(q.raw) }
          end
        end
      end
      return added, avail
    end
    local a0, v0 = run(false)
    local a1, v1 = run(true)
    if not (deep_eq(a0, a1) and deep_eq(v0, v1)) then seq_bad = seq_bad + 1 end
  end
  print(string.format("[X10-S5] P2 suites d'objets de craft_spares : %d suites, %d écarts", NSEQ, seq_bad))
  check(seq_bad == 0, "P2 : suites d'objets de craft_spares (avail entamé) identiques (" .. seq_bad .. ")")
end

-- P3 : mutants de book_max --------------------------------------------------------------------------------------------------------
local BM_SRC = read("shared/team/book_max.lua")
local function load_bm(src)
  local fn = assert(load(src, "=book_max_mutant", "t"))
  return fn()
end
do
  local mutants = {
    { "dichotomie décalée de 1 (lo = mid + 1 sur un succès)", "then lo = mid else", "then lo = mid + 1 else" },
    { "bornes inversées", "local lo, hi = 0, n - 1", "local lo, hi = n - 1, 0" },
    { "garde toujours vraie", "if Bm.DICHO and Bm.monotone(book, item, stock) then", "if Bm.DICHO then" },
    { "hauteur non contrôlée (coupure de profondeur)", "if h >= Book.MAX_DEPTH then ok = false end", "" },
    { "quantités non entières admises", "if type(per) ~= \"number\" or per <= 0 or per ~= floor(per) then ok = false end", "", prudence = true },
    { "test léger sans surcouche (écrit dans le stock)", "ov[it] = have - take", "stock[it] = have - take" },
    { "surplus partagé entre deux tests", "local ov, made = {}, {}", "local ov = {}" , "local Bm = {}", "local Bm = {}\nlocal made = {}" },
    { "premier plan complet sauté", "if next(q.raw) == nil then return n, q end", "" },
    { "stock non entier admis par la garde", "if v ~= nil and (type(v) ~= \"number\" or v ~= floor(v)) then return false end", "", prudence = true },
  }
  -- « prudence » : condition de la garde plus stricte que nécessaire (aucun contre-exemple en 200 000 livres et stocks non entiers
  -- tirés au hasard, scratchpad x10-s5/flottants.lua ; les moitiés et les entiers sont exacts en binaire). Leur survie est attendue et
  -- dite ; ils ne comptent pas dans le critère.
  local seen, need, prud = 0, 0, 0
  for _, mu in ipairs(mutants) do
    local src = BM_SRC
    local a, b = src:find(mu[2], 1, true)
    assert(a, "mutant introuvable : " .. mu[1])
    src = src:sub(1, a - 1) .. mu[3] .. src:sub(b + 1)
    if mu[4] then
      local c, d = src:find(mu[4], 1, true)
      src = src:sub(1, c - 1) .. mu[5] .. src:sub(d + 1)
    end
    local M = load_bm(src)
    for _, cs in ipairs(cases) do cs.book._s5 = nil end -- la forme gardée par le livre viendrait du vrai module
    local ok, bad = pcall(p2_run, M, "mutant", true)
    for _, cs in ipairs(cases) do cs.book._s5 = nil end
    local caught = (not ok) or bad > 0
    if mu.prudence then
      if not caught then prud = prud + 1 end
    else
      need = need + 1
      if caught then seen = seen + 1 end
    end
    print(string.format("[X10-S5] P3 mutant « %s »%s : %s", mu[1], mu.prudence and " (prudence)" or "",
      caught and ("vu (" .. (ok and (bad .. " écarts") or "erreur") .. ")") or "NON VU"))
  end
  print(string.format("[X10-S5] P3 : mutants vus %d sur %d ; mutants de prudence sans effet observable : %d", seen, need, prud))
  check(seen == need, "P3 : tous les mutants qui changent le résultat sont vus (" .. seen .. " sur " .. need .. ")")
end

-- P4 : coût (instructions, mémoire) des trois appelants ---------------------------------------------------------------------------
do
  local r = Rng(4242)
  local book = real_books[1]
  local function free_stock(item, mode)
    local st = {}
    for _ = 1, 200 do st[r.pick(ALL_NAMES)] = r.int(0, 300) end
    local raw = book:plan({ { item, 1 } }, {}).raw
    for _, it in ipairs(Bm.shape(book, item).items) do st[it] = 0 end
    for _, k in ipairs(sorted_keys(raw)) do
      if mode == "tout" then st[k] = raw[k] * 10 elseif mode == "moitie" then st[k] = raw[k] * 2 + 1 else st[k] = 0 end
    end
    return st
  end
  print("[X10-S5] P4 instructions Lua par appel (debug.sethook, compte 1 ; tri en C non compté, donc l'ancien est sous-estimé)")
  local worst_ratio = math.huge
  for _, sc in ipairs({ { "foswap", old_foswap, "electric-mining-drill", 4 }, { "rebuild_rapide", old_rr, "electric-mining-drill", 6 },
    { "reconstruction", old_recon, "small-electric-pole", 6 }, { "reconstruction", old_recon, "medium-electric-pole", 6 } }) do
    for _, mode in ipairs({ "tout", "moitie", "rien" }) do
      local free = free_stock(sc[3], mode)
      local avail = {}
      for _, k in ipairs(sorted_keys(free)) do avail[k] = free[k] end
      avail[sc[3]] = 0
      Bm.shape(book, sc[3]) -- forme gardée (une fois par livre et par objet en jeu)
      local i0, m0 = count_instr(function() return sc[2](book, sc[3], sc[4], avail) end)
      local i1, m1 = count_instr(function() return Bm.best(book, sc[3], sc[4], avail) end)
      local k0 = alloc_kb(function() sc[2](book, sc[3], sc[4], avail) end)
      local k1 = alloc_kb(function() Bm.best(book, sc[3], sc[4], avail) end)
      print(string.format("[X10-S5] P4 %-15s %-22s n=%d %-6s : m %d = %d ; instructions %6d -> %6d (x%.2f) ; mémoire %.1f -> %.1f Ko",
        sc[1], sc[3], sc[4], mode, m0, m1, i0, i1, i0 / math.max(1, i1), k0, k1))
      check(m0 == m1, "P4 " .. sc[1] .. " " .. mode .. " : même m")
      if mode == "rien" then worst_ratio = math.min(worst_ratio, i0 / math.max(1, i1)) end
    end
  end
  check(worst_ratio >= 2, string.format("P4 : rien de faisable à n = borne : instructions divisées par au moins 2 (x%.2f)", worst_ratio))
  -- « fabricable ? » (Recon.available_or_craftable, rebuild_rapide.obtainable) : copie triée + plan, contre le test léger.
  local free = free_stock("small-electric-pole", "rien")
  local function old_aoc(item)
    if (free[item] or 0) >= 1 then return true end
    if not book:handcraftable(item) then return false end
    local avail = {}
    for _, k in ipairs(sorted_keys(free)) do avail[k] = free[k] end
    avail[item] = 0
    return next(book:plan({ { item, 1 } }, avail).raw) == nil
  end
  local i0, a0 = count_instr(function() return old_aoc("small-electric-pole") end)
  local i1, a1 = count_instr(function() return Bm.feasible(book, "small-electric-pole", 1, free, "small-electric-pole") end)
  local k0 = alloc_kb(function() old_aoc("small-electric-pole") end)
  local k1 = alloc_kb(function() Bm.feasible(book, "small-electric-pole", 1, free, "small-electric-pole") end)
  print(string.format("[X10-S5] P4 fabricable ? (poteau, rien) : %s = %s ; instructions %d -> %d (x%.1f) ; mémoire %.1f -> %.1f Ko", tostring(a0),
    tostring(a1), i0, i1, i0 / math.max(1, i1), k0, k1))
  check(a0 == a1 and i0 >= 3 * i1, "P4 : « fabricable ? » même réponse, instructions divisées par au moins 3")
end

-- 5. Doublures du moteur (pour P7) -----------------------------------------------------------------------------------------------
-- (P5, relevé de FoSwap, et P6, S.plan sans allocation : partie foswap du lot, reportée après la fusion de corr-foreuses-th dans
-- essai-0659, qui réécrit script/team/foreuse_swap.lua et shared/team/foreuse_swap.lua ; consigne du lead du 7/11)
defines = defines or {}
game = { tick = 0, entity_prototypes = {} }
function log() end
package.loaded["script.faction.state"] = {
  sorted_keys = function(t) local k = {} for key in next, t do k[#k + 1] = key end table.sort(k) return k end,
  own = function() end, disown = function() end,
}

-- 7. Recon.craft_spares : mémo et test léger (P7) ---------------------------------------------------------------------------------
local RECON_SRC = read("script/team/reconstruction.lua")
local recon_env = {}
do
  local handlers = {}
  package.loaded["script.core.events"] = { on = function(id, fn) handlers[id] = fn end, on_died = function(fn) handlers.died = fn end }
  setmetatable(package.loaded["script.core.events"], { __index = function() return function() end end }) -- lot UPS (registre)
  defines.events = defines.events or { on_entity_died = 1, on_player_mined_entity = 2, on_robot_mined_entity = 3 }
  defines.entity_status = defines.entity_status or { no_power = 7, working = 1 }
  defines.direction = defines.direction or { north = 0, east = 2, south = 4, west = 6 }
  package.loaded["script.core.storage"] = { ns = function() return {} end, declare = function() end } -- lot UPS : registre_types.lua
  local st = package.loaded["script.faction.state"]
  st.owner = function() return nil end
  st.faction = function() return nil end
  st.by_force = function() return nil end
  st.alive = function() return {} end
  st.war = function() return { claims = {} } end
  st.site_key = function(pos) return math.floor(pos.x / 32) .. ":" .. math.floor(pos.y / 32) end
  package.loaded["script.faction.sites"] = { claim = function() end, release = function() end }
  package.loaded["script.team.harvest"] = { names = function(item) if item == "wood" then return { "tree-01" } end return { item } end }
  remote = remote or { add_interface = function() end }
  local R = require("shared.ai3.reglages")
  R.REBUILD_SWEEP = false -- RrRt.drill_swap rend tout de suite (relevé testé par tests/rebuild_rapide_test.lua)
  local PROTOS = {
    ["small-electric-pole"] = { items_to_place_this = { { name = "small-electric-pole" } }, supply_area_distance = 2.5, max_wire_distance = 7.5 },
    ["medium-electric-pole"] = { items_to_place_this = { { name = "medium-electric-pole" } }, supply_area_distance = 3.5, max_wire_distance = 9 },
    ["big-electric-pole"] = { items_to_place_this = { { name = "big-electric-pole" } }, supply_area_distance = 2, max_wire_distance = 30 },
  }
  game.entity_prototypes = PROTOS
  function game.get_filtered_entity_prototypes()
    return setmetatable({}, { __pairs = function()
      local ks = { "big-electric-pole", "medium-electric-pole", "small-electric-pole" }
      local i = 0
      return function() i = i + 1 if ks[i] then return ks[i], PROTOS[ks[i]] end end
    end })
  end
  recon_env.logs = {}
  function log(s) recon_env.logs[#recon_env.logs + 1] = s end
  recon_env.added = {}
  package.loaded["script.team.board"] = {
    get = function(f) return f.team.board end,
    add = function(f, tasks)
      local n = 0
      for _, t in ipairs(tasks) do
        if not f.team.board.tasks[t.key] then f.team.board.tasks[t.key] = t recon_env.added[#recon_env.added + 1] = t n = n + 1 end
      end
      return n
    end,
  }
  package.loaded["script.team.stock"] = { count = function(f, item) return f.stock[item] or 0 end }
end

local function load_recon(src)
  package.loaded["script.team.reconstruction"] = nil
  local fn = assert(load(src, "=reconstruction", "t"))
  return fn()
end

--- Équipe avec des poteaux perdus (infrastructure), le stock libre `free`, et des pièces dues.
local function recon_team(r, n_lost)
  local lost = {}
  local items = { "small-electric-pole", "medium-electric-pole", "big-electric-pole" }
  for k = 1, n_lost do
    local key = "k" .. string.format("%04d", k)
    lost[key] = { key = key, infra = true, etype = "electric-pole", name = r.pick(items), x = r.int(-300, 300), y = r.int(-300, 300),
      tick = r.int(0, 200), losses = r.int(1, 3), reach = r.pick({ 0, 5, 7.5, 9, 25 }), value = r.int(2, 14), claimed = r.int(1, 10) == 1 or nil }
    lost[key].item = lost[key].name
  end
  return { key = "emerald", force = "emerald", is_player = false, recon = { lost = lost, hist = {}, stats = { logs = 0 } },
    team = { board = { tasks = {} } }, stock = {} }
end

local function free_of(r, mode)
  local fr = { ["iron-plate"] = r.int(0, 200), ["iron-stick"] = r.int(0, 6), ["steel-plate"] = (mode >= 2) and r.int(0, 30) or 0,
    ["copper-plate"] = (mode >= 3) and r.int(0, 12) or 0, ["copper-cable"] = (mode >= 3) and r.int(0, 10) or 0,
    ["wood"] = (mode >= 1) and r.int(0, 4) or 0, ["stone"] = r.int(0, 50) }
  for _ = 1, 150 do fr[r.pick(ALL_NAMES)] = r.int(0, 300) end
  fr["small-electric-pole"], fr["medium-electric-pole"], fr["big-electric-pole"] = 0, 0, 0
  return fr
end

local function p7_run(RC, seed, n_teams, quiet)
  local r = Rng(seed)
  local bad, first = 0, nil
  local plans = { [true] = 0, [false] = 0 }
  local ins = { [true] = 0, [false] = 0 }
  local book = real_books[1]
  -- Échauffement : la liste des poteaux remplaçants (mémoire locale du module) est lue et journalisée une fois pour toutes.
  RC.craft_spares(recon_team(Rng(1), 1), book, { ["iron-plate"] = 1 }, 100000)
  for t = 1, n_teams do
    local mode = r.int(0, 3)
    local base = recon_team(r, r.int(1, 120))
    local frees = { free_of(r, mode), free_of(r, r.int(0, 3)) } -- deux pensées, deux stocks différents (mémo jamais gardé d'une à l'autre)
    local res = {}
    for _, s5 in ipairs({ false, true }) do
      RC.S5 = s5
      local f = { key = base.key, force = base.force, is_player = false, team = { board = { tasks = {} } }, stock = {},
        recon = { lost = {}, hist = {}, stats = { logs = 0 } } }
      for k, v in next, base.recon.lost do f.recon.lost[k] = copy(v) end
      recon_env.logs, recon_env.added = {}, {}
      local np = 0
      local bk = setmetatable({ plan = function(self, ...) np = np + 1 return Book.plan(self, ...) end }, { __index = book })
      local n_ins = 0
      for th = 1, 2 do
        n_ins = n_ins + count_instr(function() RC.craft_spares(f, bk, frees[th], 5000 + 300 * th) end)
      end
      plans[s5] = plans[s5] + np
      ins[s5] = ins[s5] + n_ins
      res[s5] = { lost = f.recon.lost, stats = f.recon.stats, tasks = f.team.board.tasks, logs = recon_env.logs, added = recon_env.added }
    end
    RC.S5 = true
    local a, b = res[false], res[true]
    local same = deep_eq(a.lost, b.lost) and deep_eq(a.stats, b.stats) and deep_eq(a.tasks, b.tasks) and deep_eq(a.logs, b.logs)
      and deep_eq(a.added, b.added)
    if not same then
      bad = bad + 1
      first = first or ("équipe " .. t)
    end
  end
  if not quiet then
    print(string.format("[X10-S5] P7 craft_spares : %d équipes (2 pensées chacune), %d écarts%s ; plans complets %d -> %d ; instructions %d -> %d (/%.1f)",
      n_teams, bad, first and (" ; premier : " .. first) or "", plans[false], plans[true], ins[false], ins[true], ins[false] / math.max(1, ins[true])))
  end
  return bad, plans
end

do
  local Recon = load_recon(RECON_SRC)
  check(Recon.S5 == true, "P7 : Recon.S5 allumé par défaut")
  local bad, plans = p7_run(Recon, 31, COURT and 40 or 200)
  check(bad == 0, "P7 : craft_spares avec mémo et test léger = sans (tâches, registre, statistiques, journaux) (" .. bad .. " écarts)")
  check(plans[true] * 3 <= plans[false], "P7 : plans complets divisés par au moins 3 (" .. plans[false] .. " -> " .. plans[true] .. ")")
end

-- 8. Mutants de P7 (P8) ------------------------------------------------------------------------------------------------------------
do
  local function mutate(src, a, b)
    local i, j = src:find(a, 1, true)
    assert(i, "mutant introuvable : " .. a)
    return src:sub(1, i - 1) .. b .. src:sub(j + 1)
  end
  local seen, total = 0, 0
  local function report(name, caught)
    total = total + 1
    if caught then seen = seen + 1 end
    print(string.format("[X10-S5] P8 mutant « %s » : %s", name, caught and "vu" or "NON VU"))
  end
  for _, mu in ipairs({
    { "mémo gardé d'un appel à l'autre", "Recon.S5 and { ok = {}, raw = {} } or nil", "Recon.S5 and S5_MEMO or nil",
      "local Recon = {}", "local Recon = {}\nlocal S5_MEMO = { ok = {}, raw = {} }" },
    { "mémo : réponse fausse gardée", "if memo then memo.ok[item] = v end", "if memo then memo.ok[item] = true end" },
    { "mémo : matière manquante gardée sous la mauvaise table", "if memo then memo.raw[item] = v or false end", "if memo then memo.ok[item] = v or false end" },
  }) do
    local src = mutate(RECON_SRC, mu[2], mu[3])
    if mu[4] then src = mutate(src, mu[4], mu[5]) end
    local ok, RC = pcall(load_recon, src)
    local caught = not ok
    if ok then
      local ok2, bad = pcall(p7_run, RC, 31, COURT and 40 or 200, true)
      caught = (not ok2) or bad > 0
    end
    report(mu[1], caught)
  end
  load_recon(RECON_SRC)
  print(string.format("[X10-S5] P8 : mutants vus %d sur %d", seen, total))
  check(seen == total, "P8 : tous les mutants du mémo sont vus (" .. seen .. " sur " .. total .. ")")
end

-- 9. Rc.demand : clés triées une fois, sans le tri de Rc.due (P9) ----------------------------------------------------------------
do
  local RC_SRC = read("shared/team/reconstruction.lua")
  local function load_rc(src)
    local fn = assert(load(src, "=reconstruction_regles", "t"))
    return fn()
  end
  local Rc0 = load_rc(RC_SRC)
  local function registry(r, n)
    local lost = {}
    local items = { "small-electric-pole", "medium-electric-pole", "boiler", "steam-engine", "offshore-pump", "lab", "assembler" }
    for k = 1, n do
      local key = "k" .. r.int(1, 99999) .. "-" .. k
      local e = { key = key, item = (r.int(1, 30) > 1) and r.pick(items) or nil, infra = r.int(1, 3) > 1, value = r.int(0, 6) * 2,
        tick = r.int(0, 20000), losses = r.int(1, 4) }
      if r.int(1, 8) == 1 then e.claimed = true end
      if r.int(1, 10) == 1 then e.abandoned = true end
      if r.int(1, 5) == 1 then e.retry = r.int(0, 30000) end
      lost[key] = e
    end
    return { lost = lost }
  end
  local function have_of(r)
    local h = {}
    for _, it in ipairs({ "small-electric-pole", "medium-electric-pole", "boiler", "steam-engine", "offshore-pump", "lab", "assembler" }) do
      h[it] = r.int(0, 3) == 0 and r.int(1, 7) or 0
    end
    return function(item) return h[item] or 0 end
  end
  local function p9_run(RcN, n_cases, quiet)
    local r = Rng(909)
    local bad = 0
    for _ = 1, n_cases do
      local st = registry(r, r.int(0, 80))
      local tick = r.int(0, 32000)
      local have = have_of(r)
      local a = Rc0.demand(st, tick, have)
      local keys = sorted_keys(st.lost)
      local b = RcN.demand(st, tick, have, keys)
      for i = #keys, 2, -1 do local j = r.int(1, i) keys[i], keys[j] = keys[j], keys[i] end -- ordre quelconque : même résultat
      local c = RcN.demand(st, tick, have, keys)
      if not (deep_eq(a, b) and deep_eq(a, c)) then bad = bad + 1 end
    end
    if not quiet then print(string.format("[X10-S5] P9 Rc.demand : %d registres, %d écarts (clés triées puis mêlées)", n_cases, bad)) end
    return bad
  end
  local bad = p9_run(Rc0, COURT and 1000 or 5000)
  check(bad == 0, "P9 : Rc.demand avec les clés = Rc.demand d'avant (" .. bad .. " écarts)")
  local seen, total = 0, 0
  for _, mu in ipairs({
    { "infrastructure non filtrée", "if r and is_due(r, tick) and r.infra then", "if r and is_due(r, tick) then" },
    { "délai de reprise oublié", "and (not r.retry or tick >= r.retry) and tick - r.tick >= Rc.calm_for(r)", "and tick - r.tick >= Rc.calm_for(r)" },
    { "patience oubliée", "and (not r.retry or tick >= r.retry) and tick - r.tick >= Rc.calm_for(r)", "and (not r.retry or tick >= r.retry)" },
    { "dernière valeur au lieu de la plus haute", "        if r.value > (top[r.item] or -1) then top[r.item] = r.value end\n      end\n    end\n  else",
      "        top[r.item] = r.value\n      end\n    end\n  else" },
  }) do
    local i, j = RC_SRC:find(mu[2], 1, true)
    assert(i, "mutant introuvable : " .. mu[1])
    local ok, M = pcall(load_rc, RC_SRC:sub(1, i - 1) .. mu[3] .. RC_SRC:sub(j + 1))
    local caught = not ok
    if ok then
      local ok2, b2 = pcall(p9_run, M, COURT and 1000 or 3000, true)
      caught = (not ok2) or b2 > 0
    end
    total = total + 1
    if caught then seen = seen + 1 end
    print(string.format("[X10-S5] P9 mutant « %s » : %s", mu[1], caught and "vu" or "NON VU"))
  end
  check(seen == total, "P9 : mutants vus (" .. seen .. " sur " .. total .. ")")
  -- Coût à 635 pièces (emerald, sauvegarde du DC) : tri des clés une fois de moins, plus de tri de Rc.due.
  local r = Rng(635)
  local st = registry(r, 635)
  local have = have_of(r)
  local i0 = count_instr(function() local _ = sorted_keys(st.lost) return Rc0.demand(st, 25000, have) end)
  local keys = sorted_keys(st.lost)
  local i1 = count_instr(function() return Rc0.demand(st, 25000, have, keys) end)
  print(string.format("[X10-S5] P9 635 pièces : Rc.demand %d -> %d instructions (/%.1f ; le tri des clés en C n'est pas compté)", i0, i1,
    i0 / math.max(1, i1)))
  check(i0 >= 2 * i1, "P9 : Rc.demand à 635 pièces, instructions divisées par au moins 2")
end

print(string.format("[X10-S5] BILAN : %d OK, %d ECHEC(S)", ok_n, ko_n))
os.exit(ko_n == 0 and 0 or 1)
