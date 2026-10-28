--[[
  Tests hors jeu du lot KIT : le kit de départ d'une faction est celui de votre équipe (réponse du DC du 28/10 : « idéalement
  il faudrait vraiment pas leur donner de ressources : ils ne doivent pas avoir plus que le joueur principal, ils doivent
  eux-mêmes récolter les ressources nécessaires au début ; pour les tests c'est plus simple qu'ils en aient »).
  Usage, depuis la racine du mod :   lua5.2 tests/kit_test.lua

  Vérifie : F.grant (shared/team/fondation.lua) rend le MÊME résultat pour votre équipe et une faction (coffre, fours, kit
  ouvrier) ; le kit généreux (bancs) est un sur-ensemble strict, sans bois ; aucun kit ne contient de bois ; listes triées et
  déterministes ; Harvest (shared/team/harvest.lua) donne les arbres du bois sans nom écrit, et les minerais restent l'entité
  du même nom ; le poteau (A.choose_pole) ne dépend plus d'un stock de bois de départ ; MUTANTS refusés.
]]

package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local F = require("shared.team.fondation")
local H = require("shared.team.harvest")
local A = require("shared.ai3.automatiser")
local Book = require("shared.team.book")
local recipes = dofile("tests/fixtures/recipes.lua")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end

local function same(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  if #a ~= #b then return false end
  for i = 1, #a do if not same(a[i], b[i]) then return false end end
  local n, m = 0, 0
  for _ in pairs(a) do n = n + 1 end
  for _ in pairs(b) do m = m + 1 end
  if n ~= m then return false end
  for k, v in pairs(a) do if type(k) ~= "number" and not same(v, b[k]) then return false end end
  return true
end
local function as_map(list) local m = {} for _, it in ipairs(list) do m[it[1]] = it[2] end return m end

---------------------------------------------------------------------------------------------------
section("1. Kit égal : faction == votre équipe")
local player, faction, generous = F.grant(true, false), F.grant(false, false), F.grant(false, true)
check(same(player, faction), "F.grant(joueur) == F.grant(faction) champ par champ (coffre, fours, kit ouvrier)")
check(#faction.chest == 0 and faction.smelters == 0, "kit égal : coffre vide, aucun four posé")
check(same(F.grant(true, true), player), "le réglage généreux n'agit jamais sur votre équipe")
check(same(T.start_kit, {}) and T.start_smelters == 0, "T.start_kit vide et T.start_smelters 0 (kit égal)")
check(same(faction.worker_kit, player.worker_kit) and #faction.worker_kit > 0, "kit de l'ouvrier commun aux deux équipes")
check(same(F.grant(false, false), F.grant(false, false)), "déterminisme : deux appels, même résultat")
check(F.SETTING == "fo-war-kit-genereux", "nom du réglage")
check(F.grant(false, nil).smelters == 0 and #F.grant(false, nil).chest == 0, "réglage absent (nil) : kit égal")
check(F.grant(false, "oui").smelters == 0, "seul `true` allume le kit généreux")

---------------------------------------------------------------------------------------------------
section("2. Kit généreux (bancs) : sur-ensemble strict, sans bois")
local gm, pm = as_map(generous.chest), as_map(player.chest)
local strict = true
for k, n in pairs(pm) do if (gm[k] or 0) < n then strict = false end end
check(strict and #generous.chest > #player.chest, "le kit généreux contient celui du joueur et davantage")
check(generous.smelters == T.start_smelters_generous and generous.smelters > 0, "kit généreux : fours posés au départ")
check(gm["burner-mining-drill"] == 12 and gm["stone-furnace"] == 8 and gm["iron-plate"] == 200, "contenu d'avant (12 foreuses, 8 fours, 200 fer)")
local names_sorted = true
for i = 2, #generous.chest do if generous.chest[i - 1][1] >= generous.chest[i][1] then names_sorted = false end end
check(names_sorted, "coffre rendu trié par nom (déterminisme)")
local before = #T.start_kit_generous
F.grant(false, true).chest[1][2] = 0
check(#T.start_kit_generous == before and T.start_kit_generous[1][2] ~= 0, "le résultat est une copie : la configuration n'est pas modifiée")
for _, kit in ipairs({ T.start_kit, T.start_kit_generous, T.kits.worker }) do
  for _, it in ipairs(kit) do check(it[1] ~= "wood", "aucun bois dans un kit de départ (" .. it[1] .. ")") end
end
check(T.hq_smelters >= 1, "la fonderie de secours (planificateur) a sa propre taille, indépendante du kit")

---------------------------------------------------------------------------------------------------
section("3. Harvest : entités qui donnent un objet (aucun nom écrit)")
local protos = {
  { name = "iron-ore", type = "resource", products = { "iron-ore" } },
  { name = "coal", type = "resource", products = { "coal" } },
  { name = "tree-z", type = "tree", products = { "wood" } },
  { name = "tree-a", type = "tree", products = { "wood" } },
  { name = "tree-nothing", type = "tree", products = {} },
  { name = "rock-big", type = "simple-entity", products = { "stone", "coal" } },
}
check(same(H.names("iron-ore", protos), { "iron-ore" }), "un minerai reste l'entité du même nom (comportement d'avant)")
check(same(H.names("wood", protos), { "tree-a", "tree-z" }), "le bois : les arbres qui le donnent, triés")
check(same(H.names("sand", protos), {}), "objet inconnu : rien à récolter")
check(same(H.names("wood", {}), {}) and same(H.names("wood", nil), {}), "aucun prototype : rien")
local other = {
  { name = "grumble", type = "tree", products = { "fo-fibre", "fo-resin" } },
  { name = "ferrous-lump", type = "resource", products = { "ferrous-lump" } },
}
check(same(H.names("fo-resin", other), { "grumble" }) and same(H.names("ferrous-lump", other), { "ferrous-lump" }),
  "d'autres données : résine par l'arbre, minerai par son nom")
check(same(H.names("wood", protos), H.names("wood", protos)), "déterminisme")
check(same(H.free_types(), { "resource", "tree" }), "types qui comptent comme libres au test de tuile")

---------------------------------------------------------------------------------------------------
section("4. Le poteau ne dépend plus d'un stock de bois de départ")
local SMALL, MEDIUM = "small-electric-pole", "medium-electric-pole"
local function book_of(rec)
  return Book.new(rec, { allowed = function(n) return not (n == MEDIUM or n == "big-electric-pole") end })
end
local early = book_of(recipes)
local late = Book.new(recipes, { allowed = function(n) return n ~= "big-electric-pole" end })
check(A.choose_pole(early, {}) == nil, "début, sans bois ni arbre : aucun (comme avant)")
check(A.choose_pole(early, {}, {}) == nil, "début, arbres hors de portée : aucun")
check(A.choose_pole(early, {}, { wood = 48 }) == SMALL, "début, des arbres à portée, coffre vide : petit poteau (le bois se coupe)")
check(A.choose_pole(late, {}, { wood = 160 }) == SMALL, "moyen ouvert, des arbres à portée : le petit (le moins cher)")
check(A.choose_pole(late, {}, {}) == MEDIUM, "moyen ouvert, aucun arbre : le moyen")
check(A.choose_pole(early, { wood = 10 }, {}) == SMALL, "10 bois au coffre : le petit, sans arbres")
check(A.choose_pole(early, {}, { ["iron-ore"] = 48 }) == nil, "une autre matière à portée ne remplace pas le bois")
local needs = A.natural_needs(early)
local has_wood = false
for _, k in ipairs(needs) do if k == "wood" then has_wood = true end end
check(has_wood, "A.natural_needs trouve le bois sur le livre et la table des poteaux")
local sorted = true
for i = 2, #needs do if needs[i - 1] >= needs[i] then sorted = false end end
check(sorted, "A.natural_needs : liste triée")
for _, k in ipairs(needs) do check(early:natural(k), "A.natural_needs ne rend que des matières naturelles (" .. k .. ")") end
-- Généralisation : un livre où la matière du petit poteau s'appelle autrement
local renamed = {}
for name, r in pairs(recipes) do
  local c = {}
  for k, v in pairs(r) do c[k] = v end
  c.ingredients = {}
  for i, it in ipairs(r.ingredients or {}) do
    local d = {}
    for k, v in pairs(it) do d[k] = v end
    if d.name == "wood" then d.name = "fo-resin" end
    c.ingredients[i] = d
  end
  renamed[name] = c
end
local book2 = book_of(renamed)
local resin = false
for _, k in ipairs(A.natural_needs(book2)) do if k == "fo-resin" then resin = true end end
check(resin, "autre jeu de données (résine à la place du bois) : A.natural_needs la trouve, aucun nom écrit")
check(A.choose_pole(book2, {}, { ["fo-resin"] = 48 }) == SMALL and A.choose_pole(book2, {}, { wood = 48 }) == nil,
  "autre jeu de données : le poteau suit la matière de CE livre")

---------------------------------------------------------------------------------------------------
section("5. MUTANTS (chacun doit être refusé par un contrôle)")
local refused, total = 0, 0
local function mutant(label, fn)
  total = total + 1
  local ok = pcall(fn)
  if not ok then refused = refused + 1 else print("  MUTANT SURVIVANT : " .. label) failures = failures + 1 end
end
local function expect(cond) if not cond then error("refusé") end end
local grant0, kit0 = F.grant, T.start_kit
mutant("un objet remis dans le kit égal", function()
  T.start_kit = { { "iron-plate", 1 } }
  local ok = #F.grant(false, false).chest == 0
  T.start_kit = kit0
  expect(ok)
end)
mutant("un four de départ dans le kit égal", function()
  T.start_smelters = 1
  local ok = F.grant(false, false).smelters == 0
  T.start_smelters = 0
  expect(ok)
end)
mutant("du bois dans le kit généreux", function()
  T.start_kit_generous[#T.start_kit_generous + 1] = { "wood", 50 }
  local clean = true
  for _, it in ipairs(T.start_kit_generous) do if it[1] == "wood" then clean = false end end
  table.remove(T.start_kit_generous)
  expect(clean)
end)
mutant("réglage généreux inversé", function()
  F.grant = function(is_player, g) return grant0(is_player, not g) end
  local ok = #F.grant(false, false).chest == 0
  F.grant = grant0
  expect(ok)
end)
mutant("le réglage généreux agit sur votre équipe", function()
  F.grant = function(_, g) return grant0(false, g) end
  local ok = same(F.grant(true, true), grant0(true, true))
  F.grant = grant0
  expect(ok)
end)
mutant("le kit de la faction diffère de celui du joueur", function()
  F.grant = function(is_player, g)
    local r = grant0(is_player, g)
    if not is_player then r.smelters = r.smelters + 1 end
    return r
  end
  local ok = same(F.grant(true, false), F.grant(false, false))
  F.grant = grant0
  expect(ok)
end)
mutant("choose_pole ignore harvest", function()
  local orig = A.choose_pole
  A.choose_pole = function(book, stock) return orig(book, stock) end
  local ok = A.choose_pole(early, {}, { wood = 48 }) == SMALL
  A.choose_pole = orig
  expect(ok)
end)
mutant("Harvest : un arbre qui ne donne pas l'objet", function()
  expect(same(H.names("wood", { { name = "t", type = "tree", products = { "stone" } } }), { "t" }))
end)
print(string.format("   mutants refusés : %d sur %d", refused, total))

print(string.format("\n[KIT] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
