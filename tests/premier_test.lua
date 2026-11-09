--[[
  Lot PORTE-PILE : banc HORS JEU du premier module de fabrication (shared/ai3/premier.lua, son branchement dans shared/ai3/pile.lua
  Pi.update / Pi.porte / Pi.signals). Lancement, depuis la racine du mod : lua5.2 tests/premier_test.lua
    1. règle pure Pm.eval : places (3 - modules finis), noyau payé d'abord (la défense n'est jamais entamée), matière par matière,
       candidat trop cher sauté (le suivant passe), hystérésis (la réserve déjà tenue n'est pas rendue pour quelques fers), mall ouvert
       tant qu'une place est libre, stock non modifié, déterminisme ;
    2. Pi.update / Pi.porte : le premier module passe la retenue (même sommet « adapter »), ni les autres familles, ni un autre objet,
       ni QG menacé, ni module fini en nombre ; la porte du mall ; l'état reste sérialisable ; Pi.signals relaie les candidats ;
    3. anti-échelle : premier.lua ne nomme aucun objet du jeu ;
    4. mutants : chaque règle retirée fait échouer au moins un contrôle.
]]
package.path = "./?.lua;" .. package.path
local Book = require("shared.team.book")
local book = Book.new(dofile("tests/fixtures/recipes.lua"))

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end

local TURRET, IRON, COPPER, INSERTER = "gun-turret", "iron-plate", "copper-plate", "inserter" -- données du banc (la règle n'en nomme aucun)
local CIRCUIT = "electronic-circuit"

local function sorted_keys(t) local ks = {} for k in pairs(t) do ks[#ks + 1] = k end table.sort(ks) return ks end

-- 2 tourelles de défense = 80 fer + 20 cuivre ; la marge de 10 % arrondit au-dessus : 3 tourelles = 120 fer + 30 cuivre.
local def = { { TURRET, 2 } }

--- La batterie de contrôles de la règle pure, jouée sur le module donné (le vrai ou un mutant). Rend le nombre d'échecs.
local function battery(Pm, verbose)
  local fails = 0
  local function ck(cond, msg)
    if not cond then fails = fails + 1 if verbose then print("  ECHEC : " .. msg) end end
    if verbose then check(cond, msg) end
  end
  local claims = { defense = def, rebuild = {} }
  local function ev(done, cands, avail, cl) return Pm.eval({ done = done, cands = cands }, book, avail, cl or claims) end
  local cand = function(key, item, cost, prev) return { key = key, item = item, cost = cost, prev = prev } end
  -- a. Le stock couvre le noyau et le module : admis, mall ouvert (2 places libres).
  local r = ev(0, { cand(7, CIRCUIT, { { IRON, 40 }, { COPPER, 20 } }) }, { [IRON] = 500, [COPPER] = 200 })
  ck(r.items[CIRCUIT] and r.admitted[1] == 7 and r.mall and r.slots == 3, "a. stock qui couvre noyau + module : admis, mall ouvert (" .. tostring(r.why) .. ")")
  -- b. Le fer ne couvre que le noyau : le module de fer n'est pas admis, la défense garde son fer.
  r = ev(0, { cand(7, CIRCUIT, { { IRON, 40 } }) }, { [IRON] = 150, [COPPER] = 200 })
  ck(not r.items[CIRCUIT] and r.skipped[1] == 7, "b. 150 fer = noyau (120 avec la marge) + 30 : un module de 40 fer n'est pas admis")
  r = ev(0, { cand(7, CIRCUIT, { { IRON, 15 } }) }, { [IRON] = 100, [COPPER] = 200 })
  ck(not r.items[CIRCUIT], "b2. 100 fer : 80 de défense + 15 passeraient sans la marge de 10 %, pas avec (noyau 120)")
  -- c. Par matière : le noyau en manque de fer n'empêche pas un module de cuivre que la défense ne prend pas.
  r = ev(0, { cand(7, CIRCUIT, { { COPPER, 30 } }) }, { [IRON] = 20, [COPPER] = 200 })
  ck(r.items[CIRCUIT], "c. noyau en manque de fer, module payé en cuivre seulement : admis")
  r = ev(0, { cand(7, CIRCUIT, { { IRON, 5 } }) }, { [IRON] = 20, [COPPER] = 200 })
  ck(not r.items[CIRCUIT], "c2. noyau en manque de fer : un module qui veut du fer n'est pas admis (la défense d'abord)")
  -- d. Places : 1 module fini, 3 candidats -> deux considérés, le troisième hors des premiers ; mall fermé.
  r = ev(1, { cand(1, "a", {}), cand(2, "b", {}), cand(3, "c", {}) }, { [IRON] = 500, [COPPER] = 200 })
  ck(r.slots == 2 and r.items.a and r.items.b and not r.items.c and not r.mall, "d. 1 fini : deux places, le troisième candidat attend, mall fermé")
  r = ev(3, { cand(1, "a", {}) }, { [IRON] = 500, [COPPER] = 200 })
  ck(next(r.items) == nil and not r.mall and r.slots == 0 and r.why:find("finis", 1, true) ~= nil, "d2. trois modules de fabrication finis : plus d'exception")
  r = ev(2, {}, { [IRON] = 0 })
  ck(r.mall and r.slots == 1, "d3. 2 finis, aucun candidat : le mall peut encore ouvrir")
  -- e. Trop cher sauté, le suivant admis ; les deux consomment une place.
  r = ev(0, { cand(1, "gros", { { IRON, 10000 } }), cand(2, "petit", { { IRON, 30 } }) }, { [IRON] = 500, [COPPER] = 200 })
  ck(not r.items.gros and r.items.petit and r.skipped[1] == 1 and r.admitted[1] == 2 and r.mall, "e. 'gros' sauté, 'petit' admis, une place reste au mall")
  -- f. Pas de double dépense : deux modules de 250 fer sur 500 fer (noyau 88) : un seul.
  r = ev(0, { cand(1, "a", { { IRON, 250 } }), cand(2, "b", { { IRON, 250 } }) }, { [IRON] = 500, [COPPER] = 200 })
  ck(r.items.a and not r.items.b, "f. 500 fer : noyau 88 + 250 passent, un second de 250 non (pas de double dépense)")
  -- g. Hystérésis : admis avant (prev), le stock descend sous noyau + coût mais couvre encore le coût seul.
  r = ev(0, { cand(7, CIRCUIT, { { IRON, 40 } }, true) }, { [IRON] = 100, [COPPER] = 200 })
  ck(r.items[CIRCUIT], "g. déjà admis, le stock libre seul (100) couvre le coût restant (40) : maintenu")
  r = ev(0, { cand(7, CIRCUIT, { { IRON, 40 } }, true) }, { [IRON] = 30, [COPPER] = 200 })
  ck(not r.items[CIRCUIT], "g2. déjà admis mais le stock ne couvre plus le coût restant : plus admis")
  -- h. Coût vide (rien à prendre au coffre) : admis.
  r = ev(0, { cand(7, CIRCUIT, {}) }, { [IRON] = 0 })
  ck(r.items[CIRCUIT], "h. aucun objet à prendre : admis")
  -- i. Reconstruction comptée au noyau.
  r = ev(0, { cand(7, CIRCUIT, { { IRON, 40 } }) }, { [IRON] = 200, [COPPER] = 200 })
  ck(r.items[CIRCUIT], "i0. défense seule (120 fer avec la marge) : 200 fer laissent 80, le module de 40 passe")
  r = ev(0, { cand(7, CIRCUIT, { { IRON, 40 } }) }, { [IRON] = 200, [COPPER] = 200 }, { defense = def, rebuild = { { TURRET, 1 } } })
  ck(not r.items[CIRCUIT], "i. défense (2) + reconstruction (1) = 200 fer avec les marges : 200 fer ne laissent rien")
  -- j. Sans livre ; le stock n'est pas modifié ; déterminisme.
  r = Pm.eval({ done = 0, cands = { cand(7, CIRCUIT, {}) } }, nil, {}, claims)
  ck(next(r.items) == nil, "j. sans livre : aucune exception")
  local stock = { [IRON] = 500, [COPPER] = 200 }
  local c1 = { cand(7, CIRCUIT, { { IRON, 40 } }) }
  local r1 = ev(0, c1, stock)
  local r2 = ev(0, c1, stock)
  ck(stock[IRON] == 500 and stock[COPPER] == 200, "j2. le stock donné n'est pas modifié")
  ck(r1.why == r2.why and #r1.admitted == #r2.admitted and r1.mall == r2.mall, "j3. déterministe")
  ck(Pm.describe(r1):find("admis 7", 1, true) ~= nil and Pm.describe(nil):find("non evalue", 1, true) ~= nil, "j4. ligne de journal")
  -- k. Générateurs : la fabrication n'est pas la fonderie, les foreuses, la vapeur, les laboratoires.
  local NF = require("shared.team.automatisation_donnees").NOT_FAB
  ck(Pm.is_fab("simple", NF) and Pm.is_fab("patron", NF) and Pm.is_fab("bloc", NF), "k. assembleurs : de la fabrication")
  ck(not Pm.is_fab("smelter", NF) and not Pm.is_fab("drills", NF) and not Pm.is_fab("steam", NF) and not Pm.is_fab("labs", NF)
    and not Pm.is_fab(nil, NF), "k2. fonderie, foreuses, vapeur, laboratoires, sans générateur : pas de la fabrication")
  ck(Pm.is_fab("smelter", {}) and Pm.is_fab("x", nil), "k3. la liste des générateurs qui n'en sont pas vient de l'appelant")
  return fails
end

print("== 1. Règle pure (Pm.eval)")
local Pm = require("shared.ai3.premier")
battery(Pm, true)

print("== 2. Pi.update / Pi.porte : le premier module passe la retenue")
local Pi = require("shared.ai3.pile")
-- Un poste sous son minimum (2 tourelles = 120 fer avec la marge), 130 fer en tout : le noyau est couvert une fois seulement, la retenue demeure
-- quand l'amélioration (200 fer) ne se paie pas.
local function sig(over)
  local s = { posts = { { id = "hq", have = 0, want = 2, why = "fabrication", raw = {}, claim = { { TURRET, 2 } } } },
    sources = { [IRON] = true, [COPPER] = true }, inputs = {}, book = book, avail = { [IRON] = 130, [COPPER] = 200 },
    upgrades = { { key = "capital:x", cost = { { IRON, 200 } } } },
    premiers = { done = 0, cands = { { key = 7, item = CIRCUIT, cost = { { COPPER, 30 } } } } } }
  for k, v in pairs(over or {}) do s[k] = v end
  return s
end
local st = Pi.new()
Pi.update(st, sig(), 100)
check(st.hold and not st.parallel, "départ : la retenue demeure (130 fer, l'amélioration de 200 ne se paie pas)")
check(st.premier and st.premier.items[CIRCUIT] and st.premier.mall, "… le premier module est admis, le mall ouvert")
check(select(1, Pi.porte(st, "capital", CIRCUIT, false)), "Pi.porte : le premier module (capital) passe")
check(select(1, Pi.porte(st, "capi", CIRCUIT, false)), "Pi.porte : le premier module (capi) passe")
check(not select(1, Pi.porte(st, "capital", "autre", false)), "Pi.porte : un autre objet reste suspendu")
check(not select(1, Pi.porte(st, "recherche", CIRCUIT, false)), "Pi.porte : la recherche reste suspendue")
check(not select(1, Pi.porte(st, "upgrade", CIRCUIT, false)), "Pi.porte : l'amélioration des tapis reste suspendue")
check(not select(1, Pi.porte(st, "capital", nil, false)), "Pi.porte : sans objet ni mall, suspendu")
check(select(1, Pi.porte(st, "capital", "bloc-x", false, true)), "Pi.porte : un bloc du mall passe tant qu'une place est libre")
check(not select(1, Pi.porte(st, "recherche", "bloc-x", false, true)), "Pi.porte : le mall n'ouvre pas la recherche")
check(Pi.describe(st):find("premier module", 1, true) ~= nil, "journal : la ligne de la pile dit le premier module")
-- Défense: la porte ne retire rien au rang adapter ni au-dessus (déjà permis), ni au budget
check(select(1, Pi.porte(st, "reparer", "x", false)) and select(1, Pi.porte(st, "proteger", "x", false)), "réparer et protéger passent comme avant")
-- Hystérésis de la pile : le module admis reste admis quand le stock descend un peu
local st2 = Pi.new()
Pi.update(st2, sig({ premiers = { done = 0, cands = { { key = 7, item = CIRCUIT, cost = { { IRON, 40 } } } } }, avail = { [IRON] = 170, [COPPER] = 200 } }), 100)
check(st2.premier.items[CIRCUIT], "stock 170 : noyau 120 + 40 : admis")
Pi.update(st2, sig({ premiers = { done = 0, cands = { { key = 7, item = CIRCUIT, cost = { { IRON, 40 } } } } }, avail = { [IRON] = 125, [COPPER] = 200 } }), 101)
check(st2.premier.items[CIRCUIT], "stock 125 (noyau 120 + 5) : l'oscillation mesurée ne rend plus la réserve (hystérésis d'état)")
local st3 = Pi.new()
Pi.update(st3, sig({ premiers = { done = 0, cands = { { key = 7, item = CIRCUIT, cost = { { IRON, 40 } } } } }, avail = { [IRON] = 125, [COPPER] = 200 } }), 100)
check(not st3.premier.items[CIRCUIT], "… sans admission précédente, le même stock n'admet pas")
-- QG menacé : le coffre reste gardé
local stq = Pi.new()
Pi.update(stq, sig({ survive = "qg" }), 100)
check(stq.hold and stq.premier == nil and not select(1, Pi.porte(stq, "capital", CIRCUIT, false)), "QG menacé : aucune exception")
-- Sans candidats / sans livre : comme avant
local stn = Pi.new()
Pi.update(stn, sig({ premiers = false }), 100)
check(stn.hold and stn.premier == nil and not select(1, Pi.porte(stn, "capital", CIRCUIT, false, true)), "sans candidats : la retenue d'avant")
local stb = Pi.new()
Pi.update(stb, sig({ book = false }), 100)
check(stb.hold and stb.premier == nil, "sans livre : la retenue d'avant")
-- Trois modules finis : plus d'exception
local std = Pi.new()
Pi.update(std, sig({ premiers = { done = 3, cands = { { key = 7, item = CIRCUIT, cost = {} } } } }), 100)
check(std.hold and not select(1, Pi.porte(std, "capital", CIRCUIT, false)) and not select(1, Pi.porte(std, "capital", "x", false, true)),
  "3 modules finis : plus de passe-droit ni pour le module ni pour le mall")
-- Budget couvert : la retenue tombe, pas d'exception à écrire
local stc = Pi.new()
Pi.update(stc, sig({ avail = { [IRON] = 900, [COPPER] = 200 } }), 100)
check(not stc.hold and stc.premier == nil and select(1, Pi.porte(stc, "capital", "x", false)), "budget couvert : la retenue tombe, rien à exempter")
-- La pile qui oublie la retenue oublie l'exception
Pi.update(st, sig({ avail = { [IRON] = 900, [COPPER] = 200 } }), 101)
check(not st.hold and st.premier == nil, "la retenue tombée efface l'exception")
-- Pi.signals relaie les candidats du contexte
local sgn = Pi.signals({ workers = 5 }, {}, {}, {}, { auto = { premiers = { done = 1, cands = {} } } }, nil)
check(sgn.premiers and sgn.premiers.done == 1, "Pi.signals : les candidats du plan directeur arrivent à la pile")
check(Pi.signals({ workers = 5 }, {}, {}, {}, nil, nil).premiers == nil, "Pi.signals : sans contexte, pas de candidats")
-- L'état reste sérialisable (aucune fonction)
local function no_fn(t, seen)
  seen = seen or {}
  if seen[t] then return true end
  seen[t] = true
  for _, k in ipairs(sorted_keys(t)) do
    local v = t[k]
    if type(v) == "function" then return false end
    if type(v) == "table" and not no_fn(v, seen) then return false end
  end
  return true
end
check(no_fn(st2), "état de la pile sans fonction (sauvegarde)")

print("== 3. Anti-échelle : aucun objet du jeu dans premier.lua")
local function slurp(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local function code_only(src)
  src = src:gsub("%-%-%[%[.-%]%]", "")
  src = src:gsub("%-%-[^\n]*", "")
  return src
end
do
  local src = code_only(slurp("shared/ai3/premier.lua"))
  local bad = nil
  for _, w in ipairs({ "iron", "copper", "coal", "stone", "turret", "inserter", "assembling", "transport", "belt", "pole", "firearm", "gear",
    "electric", "steel", "wood", "pipe", "magazine", "chest", "furnace", "drill%-" }) do
    if src:find(w) then bad = w end
  end
  check(bad == nil, "premier.lua ne nomme aucun objet du jeu (" .. tostring(bad) .. ")")
end

print("== 4. Mutants")
local function mutant(path, from, to, name, runner)
  local src = slurp(path)
  local i, j = src:find(from, 1, true)
  if not i then check(false, "mutant '" .. name .. "' : texte introuvable") return end
  local m = src:sub(1, i - 1) .. to .. src:sub(j + 1)
  local tmp = require("tests.depot").tmpname()
  local f = assert(io.open(tmp, "wb")) f:write(m) f:close()
  local ok, mod = pcall(dofile, tmp)
  os.remove(tmp)
  if not ok then check(false, "mutant '" .. name .. "' : ne charge pas (" .. tostring(mod) .. ")") return end
  local ok2, n = pcall(runner, mod)
  check(not ok2 or n > 0, "mutant refusé : " .. name)
  return (not ok2 or n > 0)
end
local killed, total = 0, 0
local function mut(...) total = total + 1 if mutant(...) then killed = killed + 1 end end
local M = "shared/ai3/premier.lua"
mut(M, "Pm.MAX = 3", "Pm.MAX = 99", "plus de limite de places", battery)
mut(M, "if out.slots <= 0 then", "if false then", "places épuisées ignorées", battery)
mut(M, "local free = book:plan(core, avail or {}).avail", "local free = avail or {}", "noyau non payé d'abord (défense entamée)", battery)
mut(M, "Bg.MARGIN_PCT)", "100)", "marge du noyau retirée", battery)
mut(M, "if next(pc.raw) == nil then\n        free = pc.avail", "if true then\n        free = pc.avail", "tout candidat admis sans contrôle du coût", battery)
mut(M, "free = pc.avail\n", "\n", "stock non entamé par le candidat admis (double dépense)", battery)
mut(M, "if c.prev then", "if false then", "hystérésis retirée", battery)
mut(M, "ok = next(book:plan(cost, avail or {}).raw) == nil", "ok = true", "hystérésis sans contrôle du stock", battery)
mut(M, "out.mall = (out.slots - used) > 0", "out.mall = true", "mall toujours ouvert", battery)
mut(M, "if used >= out.slots then break end", "", "candidats au-delà des places admis", battery)
mut(M, "concat(claims.defense, claims.rebuild)", "claims.defense", "reconstruction ignorée du noyau", battery)
mut(M, "(not_fab or {})[gen] ~= true", "true", "la fonderie compte comme fabrication", battery)
mut(M, "gen ~= nil and", "", "un module sans générateur compte comme fabrication", battery)
-- branchement dans Pi
local function pi_runner(PiM)
  local fails = 0
  local function ck(c) if not c then fails = fails + 1 end end
  local s1 = PiM.new()
  PiM.update(s1, sig(), 100)
  ck(s1.hold and s1.premier and s1.premier.items[CIRCUIT])
  ck(select(1, PiM.porte(s1, "capital", CIRCUIT, false)))
  ck(not select(1, PiM.porte(s1, "capital", "autre", false)))
  ck(not select(1, PiM.porte(s1, "recherche", CIRCUIT, false)))
  ck(select(1, PiM.porte(s1, "capital", "bloc-x", false, true)))
  ck(not select(1, PiM.porte(s1, "capital", "bloc-x", false, false)))
  local s2 = PiM.new()
  PiM.update(s2, sig({ survive = "qg" }), 100)
  ck(s2.premier == nil and not select(1, PiM.porte(s2, "capital", CIRCUIT, false)))
  local s3 = PiM.new()
  PiM.update(s3, sig({ premiers = { done = 3, cands = { { key = 7, item = CIRCUIT, cost = {} } } } }), 100)
  ck(not select(1, PiM.porte(s3, "capital", CIRCUIT, false)))
  local s4 = PiM.new()
  PiM.update(s4, sig({ avail = { [IRON] = 900, [COPPER] = 200 } }), 100)
  ck(s4.premier == nil)
  local s5 = PiM.new()
  PiM.update(s5, sig({ premiers = { done = 0, cands = { { key = 7, item = CIRCUIT, cost = { { IRON, 40 } } } } }, avail = { [IRON] = 170, [COPPER] = 200 } }), 100)
  PiM.update(s5, sig({ premiers = { done = 0, cands = { { key = 7, item = CIRCUIT, cost = { { IRON, 40 } } } } }, avail = { [IRON] = 125, [COPPER] = 200 } }), 101)
  ck(s5.premier and s5.premier.items[CIRCUIT])
  ck(PiM.signals({ workers = 5 }, {}, {}, {}, { auto = { premiers = { done = 1, cands = {} } } }, nil).premiers ~= nil)
  return fails
end
local P = "shared/ai3/pile.lua"
mut(P, "if hold and claims and sig.premiers and sig.book then", "if false then", "l'exception n'est jamais évaluée", pi_runner)
mut(P, "if pm and Pi.PREMIER_FAMILIES[family] then", "if pm then", "toute famille passe (recherche, tapis)", pi_runner)
mut(P, "if item ~= nil and pm.items and pm.items[item] then return true, nil end", "if pm.items then return true, nil end", "tout objet passe", pi_runner)
mut(P, "if mall and pm.mall then return true, nil end", "if pm.mall then return true, nil end", "mall sans demande du mall", pi_runner)
mut(P, 'if hold and claims and sig.premiers and sig.book then', 'if hold and sig.premiers and sig.book then claims = claims or { defense = {}, rebuild = {} }', "noyau ignoré (QG menacé exception)", pi_runner)
mut(P, "prev = prev[tostring(c.key)] == true", "prev = false", "mémoire des admis retirée", pi_runner)
mut(P, "st.premier = premier ", "st.premier = nil ", "exception jamais écrite à l'état", pi_runner)
mut(P, "premiers = ctx and ctx.auto and ctx.auto.premiers or nil", "premiers = nil", "candidats jamais relayés à la pile", pi_runner)
print(string.format("   mutants refusés : %d / %d", killed, total))
check(killed == total, "tous les mutants refusés")

print(string.format("[PORTE-PILE] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, killed, total))
os.exit(failures == 0 and 0 or 1)
