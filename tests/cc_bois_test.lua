--[[
  Lot CC-BOIS (F504, 11/11/2026) : le poteau choisi « parce que le bois se récolte » ne rend plus le bloc du mall inachetable.
  Usage, depuis la racine du mod :   lua5.2 tests/cc_bois_test.lua

  Partie 0.6.89 du DC (graine 4271945338, fo-logs/2026-11-10_PLAYTEST-0689) : Ambre garde 5 007 fer, tous ses blocs du mall attendent de
  30 à 82 min sur « stock hors besoin insuffisant (manque wood 1 à 7) » (script/ai3/industrie.lua, afford_list), jamais faute de fer.
  A.choose_pole (shared/ai3/automatiser.lua) retient le petit poteau quand le bois se RÉCOLTE (lot KIT, harvest lu au cerveau) ; l'achat du
  bloc exigeait ce même bois au stock hors besoin. Deux gardes, deux lectures de la même matière (B5). Coupe : une lecture unique,
  A.short_of / A.harvested, partagée par le choix du poteau et l'achat du bloc.

  Vérifie : (1) l'état du DC : petit poteau retenu par la récolte, bloc payé en fer, bois au stock nul : l'achat ne manque de rien ;
  (2) une matière fabriquée manque toujours (fer) ; une naturelle hors de portée aussi ; (3) cohérence : pour toute récolte, le poteau que
  A.choose_pole retient ne fait jamais manquer ses matières naturelles à l'achat ; (4) choix du poteau inchangé ; (5) l'achat du bloc lit
  A.short_of avec la récolte de l'équipe (texte de script/ai3/industrie.lua) ; (6) déterminisme ; MUTANTS refusés.
]]

package.path = "./?.lua;" .. package.path
local A = require("shared.ai3.automatiser")
local Book = require("shared.team.book")
local recipes = dofile("tests/fixtures/recipes.lua")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end

local SMALL, MEDIUM = "small-electric-pole", "medium-electric-pole"
local early = Book.new(recipes, { allowed = function(n) return not (n == MEDIUM or n == "big-electric-pole") end })
local late = Book.new(recipes, { allowed = function(n) return n ~= "big-electric-pole" end })
local has_rule = type(A.short_of) == "function" and type(A.harvested) == "function"

local function names(list) local o = {} for _, it in ipairs(list or {}) do o[#o + 1] = it[1] end return table.concat(o, ",") end
local function short(book, list, free, harvest)
  if not has_rule then return "regle absente" end
  return names(A.short_of(book, book:plan(list, free).raw, harvest))
end

---------------------------------------------------------------------------------------------------
section("1. L'état d'Ambre : petit poteau par la récolte, fer au coffre, aucun bois")
check(has_rule, "A.short_of et A.harvested existent (lecture unique du poteau et de l'achat)")
local HARV = { wood = 48, stone = 48, coal = 96, ["iron-ore"] = 48 } -- comme f.team.ia3.reach : arbres ET gisements à portée
local FREE = { ["iron-plate"] = 5007, ["copper-plate"] = 1000 }      -- 5 007 fer hors besoin, aucun bois
local pole = A.choose_pole(early, {}, HARV)
check(pole == SMALL, "le petit poteau est retenu parce que le bois se récolte")
local bloc = { { SMALL, 12 }, { "iron-gear-wheel", 20 }, { "transport-belt", 30 } }
check(short(early, bloc, FREE, HARV) == "", "bloc avec 12 petits poteaux : rien ne manque (le bois se coupe)")
check(short(early, { { SMALL, 2 } }, FREE, HARV) == "", "le bloc d'un seul petit poteau ([small-electric-pole] du DC) : rien ne manque")

section("2. Ce qui manque toujours")
check(short(early, bloc, {}, HARV) == "copper-plate,iron-plate", "coffre vide : cuivre et fer (matières fabriquées) manquent, pas le bois")
check(short(early, bloc, FREE, {}) == "wood", "aucun arbre à portée : le bois manque")
check(short(early, bloc, FREE, nil) == "wood", "récolte inconnue (nil) : le bois manque")
check(short(early, bloc, FREE, { wood = false }) == "wood", "récolte à faux : le bois manque")
check(short(early, { { SMALL, 2 } }, FREE, { ["iron-plate"] = 48 }) == "wood", "une plaque « à portée » ne remplace pas le bois")
check(short(early, { { "iron-gear-wheel", 10 } }, {}, { ["iron-plate"] = 48 }) == "iron-plate",
  "une matière FABRIQUÉE n'est jamais exemptée, même nommée dans la récolte")
check(short(early, { { "stone-furnace", 4 }, { "grenade", 1 } }, { ["iron-plate"] = 50 }, HARV) == "",
  "pierre et charbon à portée : ni le four ni la grenade ne manquent")
check(short(early, { { "stone-furnace", 4 }, { "grenade", 1 } }, { ["iron-plate"] = 50 }, { wood = 48 }) == "coal,stone",
  "pierre et charbon hors de portée : ils manquent, triés")

section("3. Cohérence : le poteau retenu ne fait jamais manquer ses matières naturelles")
local harvests = { {}, { wood = 48 }, { wood = 160, stone = 48 }, { stone = 48 }, HARV }
for i, h in ipairs(harvests) do
  for _, b in ipairs({ early, late }) do
    local p = A.choose_pole(b, {}, h)
    if p and has_rule then
      local miss = A.short_of(b, b:plan({ { p, 12 } }, FREE).raw, h)
      local nat = {}
      for _, it in ipairs(miss) do if b:natural(it[1]) then nat[#nat + 1] = it[1] end end
      check(#nat == 0, "récolte " .. i .. " : poteau " .. p .. " sans manque naturel à l'achat (" .. table.concat(nat, ",") .. ")")
    end
  end
end

section("4. Le choix du poteau ne change pas")
check(A.choose_pole(early, {}) == nil, "début, sans bois ni arbre : aucun")
check(A.choose_pole(early, {}, {}) == nil, "début, arbres hors de portée : aucun")
check(A.choose_pole(early, {}, { wood = 48 }) == SMALL, "début, arbres à portée : petit")
check(A.choose_pole(late, {}, {}) == MEDIUM, "moyen ouvert, aucun arbre : moyen")
check(A.choose_pole(late, {}, { wood = 160 }) == SMALL, "moyen ouvert, arbres à portée : petit")
check(A.choose_pole(early, { wood = 10 }, {}) == SMALL, "10 bois au coffre : petit, sans arbres")
check(A.choose_pole(early, {}, { ["iron-ore"] = 48 }) == nil, "une autre matière à portée ne remplace pas le bois")

section("5. L'achat du bloc lit la même règle, avec la récolte de l'équipe")
local function afford_text()
  local fh = io.open("script/ai3/industrie.lua", "rb")
  local s = fh:read("*a")
  fh:close()
  local a = s:find("local function afford_list", 1, true)
  local b = a and s:find("\nend", a, true)
  return a and s:sub(a, b) or ""
end
local NEW = "A.short_of(book, plan.raw, Harvest.reachable(f))"
local OLD = "for _, k in ipairs(sorted_keys(plan.raw)) do"
local function wired(t) return t:find(NEW, 1, true) ~= nil and t:find(OLD, 1, true) == nil end
local AFFORD = afford_text()
check(AFFORD ~= "", "afford_list trouvé dans script/ai3/industrie.lua")
check(wired(AFFORD), "afford_list lit A.short_of(book, plan.raw, Harvest.reachable(f)), plus la boucle brute sur plan.raw")

section("6. Déterminisme")
if has_rule then
  local r1 = names(A.short_of(early, { ["steel-plate"] = 2, ["iron-plate"] = 3, wood = 4, coal = 0 }, {}))
  local r2 = names(A.short_of(early, { wood = 4, coal = 0, ["iron-plate"] = 3, ["steel-plate"] = 2 }, {}))
  check(r1 == "iron-plate,steel-plate,wood" and r1 == r2, "liste triée, quantités nulles écartées, même résultat (" .. r1 .. ")")
else
  check(false, "déterminisme : règle absente")
end

---------------------------------------------------------------------------------------------------
section("7. Mutants (chacun doit être refusé)")
local refused, total = 0, 0
local function mutant(name, fn)
  total = total + 1
  local ok, broken = pcall(fn)
  if ok and broken then refused = refused + 1 else print("  MUTANT NON REFUSÉ : " .. name) failures = failures + 1 end
end
local function with(field, fake, probe)
  local orig = A[field]
  A[field] = fake
  local ok, res = pcall(probe)
  A[field] = orig
  return ok and res
end
local function plain_find(s, pat) return s:find(pat, 1, true) end
if has_rule then
  local H0, S0 = A.harvested, A.short_of
  mutant("la récolte est ignorée (le bois manque à l'achat)", function()
    return with("harvested", function() return false end, function() return short(early, bloc, FREE, HARV) ~= "" end)
  end)
  mutant("toute matière nommée dans la récolte est exemptée, même fabriquée", function()
    return with("harvested", function(_, k, h) return h ~= nil and h[k] ~= nil and h[k] ~= false end,
      function() return short(early, { { "iron-gear-wheel", 10 } }, {}, { ["iron-plate"] = 48 }) ~= "iron-plate" end)
  end)
  mutant("une récolte à faux compte comme récoltée", function()
    return with("harvested", function(book, k, h) return book:natural(k) and h ~= nil and h[k] ~= nil end,
      function() return short(early, bloc, FREE, { wood = false }) ~= "wood" end)
  end)
  mutant("les quantités nulles restent dans les manques", function()
    return with("short_of", function(book, raw, h)
      local keys = {}
      for x in pairs(raw) do keys[#keys + 1] = x end
      table.sort(keys)
      local o = {}
      for _, k in ipairs(keys) do if not H0(book, k, h) then o[#o + 1] = { k, raw[k] } end end
      return o
    end, function() return names(A.short_of(early, { coal = 0 }, {})) ~= "" end)
  end)
  mutant("manques non triés", function()
    return with("short_of", function(book, raw, h)
      local o = S0(book, raw, h)
      table.sort(o, function(x, y) return x[1] > y[1] end)
      return o
    end, function() return names(A.short_of(early, { ["steel-plate"] = 2, ["iron-plate"] = 3 }, {})) ~= "iron-plate,steel-plate" end)
  end)
  mutant("le choix du poteau accepte une naturelle hors de portée", function()
    return with("only_made", function() return true end, function() return A.choose_pole(early, {}, {}) ~= nil end)
  end)
  mutant("l'achat du bloc garde l'ancienne boucle sur plan.raw", function()
    local a = plain_find(AFFORD, NEW)
    if not a then return false end
    local old = AFFORD:sub(1, a - 1) .. "sorted_keys(plan.raw)" .. AFFORD:sub(a + #NEW) .. "\n" .. OLD
    return not wired(old)
  end)
  mutant("l'achat du bloc lit la règle sans la récolte de l'équipe", function()
    local a = plain_find(AFFORD, NEW)
    if not a then return false end
    local old = AFFORD:sub(1, a - 1) .. "A.short_of(book, plan.raw, nil)" .. AFFORD:sub(a + #NEW)
    return not wired(old)
  end)
end
print(string.format("   mutants refusés : %d sur %d", refused, total))

print(string.format("\n[CC-BOIS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
