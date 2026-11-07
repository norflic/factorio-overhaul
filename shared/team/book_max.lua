--[[
  Lot S5 du ×10 (FOSWAP et DICHOTOMIE, fo-logs/2026-11-07_X10/S5_CRITERES.md). PUR (aucune API Factorio).

  « Combien d'objets `item` la matière du stock permet-elle de fabriquer, au plus n ? » Avant S5, trois appelants
  (script/team/foreuse_swap.lua `craft`, script/team/rebuild_rapide.lua `craft`, script/team/reconstruction.lua `craft_spares`)
  le demandaient par une boucle linéaire de plans COMPLETS :
      q = book:plan({ { item, n } }, stock)
      si q.raw n'est pas vide : pour m = n - 1, ..., 1 : q2 = book:plan({ { item, m } }, stock) ; le premier sans matière brute gagne.
  Chaque plan complet recopie tout le stock (Book:plan, `pairs(stock)`) et bâtit crafts / uses / raw.

  Bm.best rend EXACTEMENT le même (m, q) :
    1. un plan complet de n, comme avant (il sert tel quel s'il est faisable, ou pour q.raw quand rien ne l'est) ;
    2. la recherche de m dans [1, n - 1] par un TEST léger (Bm.feasible : même règle que `need` de Book:plan, sur une surcouche du
       stock, sans copie, arrêté à la première matière brute) ;
    3. un seul plan complet de m.
  La recherche est une DICHOTOMIE seulement quand la faisabilité est prouvée monotone en n (Bm.monotone : sous-arbre de recettes
  sans cycle, plus long chemin < MAX_DEPTH, quantités entières, stock entier sur ces objets ; preuve dans S5_CRITERES.md §5) ;
  sinon elle est LINÉAIRE, dans l'ordre n - 1 → 1 de l'ancien code (exacte sans hypothèse).
  Mémoire : la forme du sous-arbre est gardée dans le livre (book._s5), qui est un objet LOCAL (team.lua `books`), hors du global,
  comme book.made (Book:natural).

  INVARIANT DU CACHE book._s5 (revue de 717c1d3f) : la forme gardée n'est juste que si le Book n'est JAMAIS modifié après Book.new
  (book.recipes, book.by_product, leurs recettes, ingrédients et quantités). Aujourd'hui, aucun code ne le fait : team.lua construit
  un livre neuf par clé force:tech (`books`), et Book:natural n'ajoute que book.made. Qui voudrait modifier un livre en place doit
  vider book._s5 (book._s5 = nil) au même moment. Sinon la garde peut dire « théorème » pour un livre qui ne l'est plus, et la
  dichotomie rendre un autre m que la boucle linéaire : décision changée, et désynchronisation possible en multijoueur entre un
  client qui a gardé l'ancienne forme et un client qui vient de charger la partie (livre et cache rebâtis à neuf).
]]

local Book = require("shared.team.book")

local Bm = {}

Bm.DICHO = true    -- témoin : false = recherche linéaire seulement (toujours avec le test léger)

local floor, ceil = math.floor, math.ceil

--- Le plan de `n` objets `item` sur `stock` serait-il sans matière brute ? Même règle que Book:plan (shared/team/book.lua, `need`),
--- pour une seule demande { item, n } : le stock est lu à travers une surcouche (rien n'est copié ni écrit dans `stock`).
--- `zero` (facultatif) : objet lu comme 0 au stock (l'appelant qui faisait `avail[item] = 0` sur sa copie).
function Bm.feasible(book, item, n, stock, zero)
  local recipes, by_product = book.recipes, book.by_product
  if not (recipes and by_product) then
    -- Livre qui n'est pas un Book (doublure des tests : seulement handcraftable et plan) : l'ancien calcul, plan complet sur une copie.
    local keys, avail = {}, {}
    for k in next, stock do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do avail[k] = stock[k] end
    if zero ~= nil then avail[zero] = 0 end
    return next(book:plan({ { item, n } }, avail).raw) == nil
  end
  local MAXD = Book.MAX_DEPTH
  local ov, made = {}, {}
  local short = false
  local function need(it, k, depth)
    local m = made[it] or 0
    if m > 0 then
      local t = m < k and m or k
      made[it] = m - t
      k = k - t
      if k <= 0 then return end
    end
    local have = ov[it]
    if have == nil then
      if it == zero then have = 0 else have = stock[it] or 0 end
    end
    local take = have < k and have or k
    if take > 0 then
      ov[it] = have - take
      k = k - take
      if k <= 0 then return end
    end
    local rname = depth < MAXD and by_product[it] or nil
    if not rname then
      short = true -- Book:plan écrirait raw[it] : le plan n'est plus faisable, quoi qu'il arrive ensuite
      return
    end
    local r = recipes[rname]
    local per = r.products[1].amount
    local runs = ceil(k / per)
    local ings = r.ingredients
    for i = 1, #ings do
      local ing = ings[i]
      need(ing.name, ing.amount * runs, depth + 1)
      if short then return end
    end
    local surplus = runs * per - k
    if surplus > 0 then made[it] = (made[it] or 0) + surplus end
  end
  need(item, n, 0)
  return not short
end

--- Forme du sous-arbre de recettes de `item` dans le livre (gardée dans book._s5) : { ok = bool, items = { objets du sous-arbre } }.
--- ok : sans cycle, plus long chemin < MAX_DEPTH, quantités entières et strictement positives (produit et ingrédients).
function Bm.shape(book, item)
  local memo = book._s5
  if not memo then
    memo = {}
    book._s5 = memo
  end
  local s = memo[item]
  if s then return s end
  local recipes, by_product = book.recipes, book.by_product
  local state, height, items = {}, {}, {}
  local ok = true
  local function visit(it)
    local st = state[it]
    if st == 1 then ok = false return 0 end -- cycle
    if st == 2 then return height[it] end
    state[it] = 1
    items[#items + 1] = it
    local h = 0
    local rname = by_product[it]
    if rname then
      local r = recipes[rname]
      local per = r.products[1].amount
      if type(per) ~= "number" or per <= 0 or per ~= floor(per) then ok = false end
      for _, ing in ipairs(r.ingredients) do
        local a = ing.amount
        -- (quantité nulle exclue : `need(Y, 0)` écrit raw[Y] = 0 sauf si un surplus de Y attend, ce qui dépend de l'histoire du plan)
        if type(a) ~= "number" or a <= 0 or a ~= floor(a) then ok = false end
        local hh = visit(ing.name) + 1
        if hh > h then h = hh end
      end
    end
    state[it] = 2
    height[it] = h
    return h
  end
  local h = visit(item)
  -- Profondeur d'un appel de `need` = longueur du chemin depuis la racine, au plus h : avec h < MAX_DEPTH, aucune coupure.
  if h >= Book.MAX_DEPTH then ok = false end
  s = { ok = ok, items = items, height = h }
  memo[item] = s
  return s
end

--- La faisabilité de `item` sur `stock` est-elle prouvée monotone en n (preuve : S5_CRITERES.md §5) ?
function Bm.monotone(book, item, stock, zero)
  if not (book.recipes and book.by_product) then return false end -- doublure : rien n'est prouvé, recherche linéaire
  local s = Bm.shape(book, item)
  if not s.ok then return false end
  local items = s.items
  for i = 1, #items do
    local it = items[i]
    if it ~= zero then
      local v = stock[it]
      if v ~= nil and (type(v) ~= "number" or v ~= floor(v)) then return false end
    end
  end
  return true
end

--- Le plus grand m de [1, n] dont le plan est sans matière brute : rend m, book:plan({ { item, m } }, stock) ; ou 0 et le plan de n
--- quand aucun ne l'est (même résultat que l'ancienne boucle linéaire, voir l'en-tête). `stock` n'est pas modifié.
function Bm.best(book, item, n, stock)
  local q = book:plan({ { item, n } }, stock)
  if next(q.raw) == nil then return n, q end
  if n <= 1 then return 0, q end
  local m = 0
  if Bm.DICHO and Bm.monotone(book, item, stock) then
    -- faisable(n) est faux ; faisable est vrai sur [1, M] et faux au-delà (monotonie) : M cherché dans [0, n - 1].
    local lo, hi = 0, n - 1
    while lo < hi do
      local mid = floor((lo + hi + 1) / 2)
      if Bm.feasible(book, item, mid, stock) then lo = mid else hi = mid - 1 end
    end
    m = lo
  else
    for k = n - 1, 1, -1 do
      if Bm.feasible(book, item, k, stock) then m = k break end
    end
  end
  if m == 0 then return 0, q end
  return m, book:plan({ { item, m } }, stock)
end

return Bm
