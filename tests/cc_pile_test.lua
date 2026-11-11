--[[
  Lot CC-PILE (F522) : banc HORS JEU de l'hystérésis de la pile avec la matière retenue par les améliorations en cours.
  Lancement, depuis la racine du mod : lua5.2 tests/cc_pile_test.lua
  Symptôme (banc de sonde de CC-MATIERES, graine 1618033988, 45 min) : de 30 à 44 min, la pile du joueur bascule à chaque relevé entre
  « ameliorer PERMIS (budget couvert, en parallele) » et « ameliorer SUSPENDU : noyau non couvert (manque iron-plate 45 à 410) »
  (39 bascules en 49 relevés) ; les modules 5, 6 et 21 (capital) restent « reserve(0/N)[pile] » : chaque permis leur fait retirer du
  fer du coffre, le noyau passe alors « non couvert », la retenue leur fait tout rendre (Build.reserve_suspended), et ainsi de suite.
  Contrôles :
    1. règle pure Bg.assess : en parallèle, le noyau que la réserve des modules a découvert reste couvert avec `held` ; on n'ENTRE
       pas en parallèle sur `held` ; held vide = comme avant ; manque réel (même avec held) = retenue ; held ne paie aucune amélioration ;
       Bg.with_held additionne sans toucher ses entrées ; rejeu de l'état du symptôme (plus de bascule) ; déterminisme ;
    2. câblage (texte) : Build.pile_held (producteur), Team.view.pile_held, le cerveau qui le transmet, Pi.signals et Pi.update ;
    3. mutants : chaque pièce retirée fait échouer au moins un contrôle.
]]
package.path = "./?.lua;" .. package.path
local Book = require("shared.team.book")
local book = Book.new(dofile("tests/fixtures/recipes.lua"))

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end

local TURRET, IRON, COPPER = "gun-turret", "iron-plate", "copper-plate" -- données du banc (la règle n'en nomme aucun)
local def = { { TURRET, 2 } } -- 2 tourelles = 80 fer + 20 cuivre (x 1,1 = 88 + 22)

local function battery(Bg, verbose)
  local fails = 0
  local function ck(cond, msg)
    if not cond then fails = fails + 1 if verbose then print("  ECHEC : " .. msg) end end
    if verbose then check(cond, msg) end
  end
  -- a. Déjà en parallèle, le coffre n'a plus que 50 fer (les modules en ont retiré 200) : maintenu grâce à held.
  local r = Bg.assess(book, { [IRON] = 50, [COPPER] = 100 }, { defense = def, upgrades = {} }, true, { [IRON] = 200 })
  ck(r.covered and r.why and r.why:find("retenue par les ameliorations") ~= nil, "a. en parallèle, held couvre le noyau : maintenu (" .. tostring(r.why) .. ")")
  -- b. Pas encore en parallèle : held ne fait pas entrer.
  r = Bg.assess(book, { [IRON] = 50, [COPPER] = 100 }, { defense = def, upgrades = { { key = "u", cost = { { IRON, 10 } } } } }, false, { [IRON] = 200 })
  ck(not r.covered and not r.core_ok, "b. hors parallèle, held ne fait pas entrer : retenue")
  -- c. held vide : comportement d'avant (noyau non couvert).
  r = Bg.assess(book, { [IRON] = 50, [COPPER] = 100 }, { defense = def, upgrades = {} }, true, {})
  ck(not r.covered and (r.missing[IRON] or 0) > 0, "c. held vide : noyau non couvert, comme avant")
  -- d. Manque réel même avec held : retenue.
  r = Bg.assess(book, { [IRON] = 20, [COPPER] = 100 }, { defense = def, upgrades = {} }, true, { [IRON] = 30 })
  ck(not r.covered and not r.core_ok, "d. 20 + 30 fer ne couvrent pas 88 : la retenue demeure")
  -- e. held d'une autre matière ne couvre pas le fer.
  r = Bg.assess(book, { [IRON] = 50, [COPPER] = 100 }, { defense = def, upgrades = {} }, true, { [COPPER] = 5000 })
  ck(not r.covered, "e. du cuivre retenu ne couvre pas un manque de fer")
  -- f. held ne paie aucune amélioration (aucune admise sur la matière retenue).
  r = Bg.assess(book, { [IRON] = 50, [COPPER] = 100 }, { defense = def, upgrades = { { key = "u", cost = { { IRON, 100 } } } } }, true, { [IRON] = 500 })
  ck(r.covered and #r.admitted == 0, "f. maintenu sans admettre d'amélioration payée par la matière retenue (" .. #r.admitted .. ")")
  -- g. Noyau couvert par le stock libre : held ignoré (même résultat qu'avant).
  local r1 = Bg.assess(book, { [IRON] = 500, [COPPER] = 100 }, { defense = def, upgrades = { { key = "u", cost = { { IRON, 100 } } } } }, true, { [IRON] = 300 })
  local r2 = Bg.assess(book, { [IRON] = 500, [COPPER] = 100 }, { defense = def, upgrades = { { key = "u", cost = { { IRON, 100 } } } } }, true, nil)
  ck(r1.covered == r2.covered and r1.admitted[1] == r2.admitted[1] and r1.why == r2.why, "g. stock libre suffisant : held ne change rien")
  -- h. Bg.with_held additionne, ignore les entrées nulles, ne touche pas ses entrées.
  local st, hd = { [IRON] = 10 }, { [IRON] = 5, [COPPER] = 0 }
  local w = Bg.with_held and Bg.with_held(st, hd) or {}
  ck(w[IRON] == 15 and w[COPPER] == nil and st[IRON] == 10 and hd[IRON] == 5, "h. with_held : 10 + 5 fer, cuivre nul ignoré, entrées intactes")
  -- i. Rejeu du symptôme : des modules qui retirent jusqu'à 200 fer à chaque permis ; plus de bascule sur 10 pensées.
  local coffre, held, prev, flips, last = 260, 0, false, 0, nil
  for _ = 1, 10 do
    local res = Bg.assess(book, { [IRON] = coffre, [COPPER] = 100 }, { defense = def, upgrades = { { key = "m", cost = { { IRON, 150 } } } } }, prev, { [IRON] = held })
    if last ~= nil and res.covered ~= last then flips = flips + 1 end
    last, prev = res.covered, res.covered
    if res.covered then -- permis : les modules réservent jusqu'à 200 fer
      local take = math.min(200 - held, coffre) coffre, held = coffre - take, held + take
    else -- retenue : ils rendent tout (Build.reserve_suspended)
      coffre, held = coffre + held, 0
    end
  end
  ck(flips == 0 and last == true, "i. rejeu : 0 bascule sur 10 pensées (" .. flips .. "), les modules gardent leur réserve (" .. held .. " fer)")
  -- k. Hystérésis d'état d'avant (gardée) : noyau couvert par le stock libre, amélioration trop chère, déjà en parallèle : maintenu ;
  --    hors parallèle, le noyau doit être couvert 2 fois.
  local k1 = Bg.assess(book, { [IRON] = 120, [COPPER] = 100 }, { defense = def, upgrades = { { key = "u", cost = { { IRON, 9999 } } } } }, true, nil)
  local k2 = Bg.assess(book, { [IRON] = 120, [COPPER] = 100 }, { defense = def, upgrades = { { key = "u", cost = { { IRON, 9999 } } } } }, false, nil)
  ck(k1.covered and not k2.covered, "k. hystérésis d'état d'avant gardée (en parallèle : maintenu ; hors parallèle : retenue)")
  -- j. Déterminisme.
  local x = Bg.assess(book, { [IRON] = 50, [COPPER] = 100 }, { defense = def, upgrades = {} }, true, { [IRON] = 200 })
  local y = Bg.assess(book, { [IRON] = 50, [COPPER] = 100 }, { defense = def, upgrades = {} }, true, { [IRON] = 200 })
  ck(x.covered == y.covered and x.why == y.why, "j. deux évaluations identiques")
  return fails
end

print("== CC-PILE : 1. règle pure")
local Bg = require("shared.ai3.budget")
local ok_pure, err_pure = pcall(battery, Bg, true)
if not ok_pure then check(false, "1. la règle pure plante : " .. tostring(err_pure)) end

print("== 2. câblage")
local build, team, cerveau, pile = read("script/team/build.lua"), read("script/team/team.lua"), read("shared/ai3/cerveau.lua"), read("shared/ai3/pile.lua")
check(build:find("function Build.pile_held(f)", 1, true) and build:find("p.state == \"reserve\" and p.stock and pile_family(f, p)", 1, true), "2a. Build.pile_held : chantiers en réserve que la pile suspendrait")
check(team:find("pile_held = Build.pile_held(f)", 1, true), "2b. Team.view porte pile_held")
check(cerveau:find("held = view.pile_held", 1, true), "2c. le cerveau transmet view.pile_held au budget de la pile")
check(pile:find("held = bud and bud.held or nil", 1, true), "2d. Pi.signals garde held")
check(pile:find("Bg.assess(sig.book, sig.avail or {}, claims, st.parallel, sig.held)", 1, true), "2e. Pi.update passe sig.held à Bg.assess")

print("== 3. mutants")
local src = read("shared/ai3/budget.lua")
local function mutant(name, from, to)
  local a, b = src:find(from, 1, true)
  if not a then check(false, "mutant " .. name .. " : motif introuvable") return end
  local s = src:sub(1, a - 1) .. to .. src:sub(b + 1)
  local M = assert(load(s, "=budget_mutant"))()
  local ok, f = pcall(battery, M, false)
  if not ok then f = 1 end -- un mutant qui plante est refusé
  check(f > 0, "mutant '" .. name .. "' refusé (" .. f .. " échec(s))")
end
mutant("held ignoré", "if prev and next(held or {}) ~= nil then", "if false then")
mutant("held sans prev", "if prev and next(held or {}) ~= nil then", "if next(held or {}) ~= nil then")
mutant("held dans le stock libre", "local base = book:plan(core, stock or {})", "local base = book:plan(core, Bg.with_held(stock, held))")
mutant("with_held ne compte pas held", "if (held[k] or 0) > 0 then out[k] = (out[k] or 0) + held[k] end", "")
mutant("with_held modifie l'entrée", "for _, k in ipairs(sorted_keys(stock)) do out[k] = stock[k] end", "out = stock")
mutant("held couvre sans vérifier", "if next(kept.raw) == nil then", "if true then")
mutant("hystérésis d'état retirée", "elseif prev then", "elseif false then")

print(string.format("[CC-PILE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
