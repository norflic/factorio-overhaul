--[[
  Lot PILE-BUDGET : banc HORS JEU du budget de la pile (shared/ai3/budget.lua, son branchement dans shared/ai3/pile.lua Pi.update et dans
  le cerveau par besoins). Lancement, depuis la racine du mod : lua5.2 tests/pile_budget_test.lua
    1. règle pure Bg.assess : couverture par matière (le cuivre ne paie pas le fer), marge, noyau non couvert, amélioration admise,
       améliorations en parallèle sans double dépense, trop chère sautée / suivante admise (PNJ libre), hystérésis, cas sans coût connu,
       stock non modifié, déterminisme ;
    2. Pi.update : retenue qui tombe quand le stock couvre défense + reconstruction + amélioration (parallèle), qui demeure sinon, tâche
       déjà prise = rien à payer, reconstruction comptée, projet rouvert compté, réglage éteint (sans livre), journal ;
    3. anti-échelle : budget.lua et mall.lua ne nomment aucun objet du jeu ;
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

local TURRET, IRON, COPPER = "gun-turret", "iron-plate", "copper-plate" -- données du banc (la règle n'en nomme aucun)

local function sorted_keys(t) local ks = {} for k in pairs(t) do ks[#ks + 1] = k end table.sort(ks) return ks end

--- La batterie de contrôles de la règle pure, jouée sur le module donné (le vrai ou un mutant). Rend le nombre d'échecs.
local function battery(Bg, verbose)
  local fails = 0
  local function ck(cond, msg)
    if not cond then fails = fails + 1 if verbose then print("  ECHEC : " .. msg) end end
    if verbose then check(cond, msg) end
  end
  -- 2 tourelles = 80 fer + 20 cuivre (x 1,1 de marge = 88 + 22).
  local def = { { TURRET, 2 } }
  -- a. Noyau couvert + une amélioration payée : parallèle.
  local r = Bg.assess(book, { [IRON] = 500, [COPPER] = 100 }, { defense = def, upgrades = { { key = "u1", cost = { { IRON, 100 } } } } }, false)
  ck(r.covered and r.core_ok and r.admitted[1] == "u1", "a. le stock couvre 2 tourelles et une amélioration : parallèle (" .. tostring(r.why) .. ")")
  -- b. Noyau non couvert : fer insuffisant.
  r = Bg.assess(book, { [IRON] = 60, [COPPER] = 100 }, { defense = def, upgrades = { { key = "u1", cost = { { IRON, 10 } } } } }, false)
  ck(not r.covered and not r.core_ok and (r.missing[IRON] or 0) > 0, "b. 60 fer ne paient pas 2 tourelles : la retenue demeure (manque " .. tostring(r.missing[IRON]) .. ")")
  -- c. Par matière : 49 000 cuivre ne paient pas le fer.
  r = Bg.assess(book, { [IRON] = 30, [COPPER] = 49000 }, { defense = def, upgrades = { { key = "u1", cost = { { COPPER, 100 } } } } }, false)
  ck(not r.covered and not r.core_ok, "c. beaucoup de cuivre et peu de fer : le noyau (fer) n'est pas couvert")
  r = Bg.assess(book, { [IRON] = 5000, [COPPER] = 0 }, { defense = def, upgrades = { { key = "u1", cost = { { IRON, 100 } } } } }, false)
  ck(not r.covered and (r.missing[COPPER] or 0) > 0, "c2. beaucoup de fer et pas de cuivre : la tourelle ne se paie pas")
  -- d. Marge : 80 fer + 20 cuivre exacts ne couvrent pas le noyau majoré de 10 %.
  r = Bg.assess(book, { [IRON] = 80, [COPPER] = 20 }, { defense = def, upgrades = {} }, false)
  ck(not r.core_ok, "d. le stock exact sans marge ne couvre pas le noyau majoré de " .. Bg.MARGIN_PCT .. " %")
  -- e. Amélioration trop chère sautée, la suivante admise (un PNJ libre prend la prochaine qui se paie).
  r = Bg.assess(book, { [IRON] = 600, [COPPER] = 100 }, { defense = def, upgrades = { { key = "gros", cost = { { IRON, 10000 } } },
    { key = "petit", cost = { { IRON, 100 } } } } }, false)
  ck(r.covered and r.admitted[1] == "petit" and r.skipped[1] == "gros", "e. 'gros' sauté, 'petit' admis")
  -- f. Parallèle sans double dépense : 500 fer, noyau 88, deux améliorations de 200 passent, une troisième non.
  r = Bg.assess(book, { [IRON] = 600, [COPPER] = 100 }, { defense = def, upgrades = { { key = "a", cost = { { IRON, 200 } } },
    { key = "b", cost = { { IRON, 200 } } }, { key = "c", cost = { { IRON, 200 } } } } }, false)
  ck(#r.admitted == 2 and r.skipped[1] == "c", "f. deux améliorations en parallèle, la troisième dépasserait le stock (" .. #r.admitted .. " admises)")
  -- g. Reconstruction comptée avec la défense.
  r = Bg.assess(book, { [IRON] = 150, [COPPER] = 100 }, { defense = def, rebuild = { { TURRET, 2 } }, upgrades = { { key = "a", cost = { { IRON, 5 } } } } }, false)
  ck(not r.covered, "g. défense (2) + reconstruction (2) = 4 tourelles : 150 fer ne suffisent pas")
  -- h. Hystérésis : aucune amélioration payable, mais déjà en parallèle et noyau couvert : maintenu.
  local ups_big = { { key = "gros", cost = { { IRON, 10000 } } } }
  r = Bg.assess(book, { [IRON] = 120, [COPPER] = 30 }, { defense = def, upgrades = ups_big }, true)
  ck(r.covered, "h. déjà en parallèle, noyau couvert une fois : maintenu")
  r = Bg.assess(book, { [IRON] = 300, [COPPER] = 100 }, { defense = def, upgrades = ups_big }, false)
  ck(r.covered, "h2. relecture : noyau couvert 2 fois, l'amélioration trop chère ne retient plus les autres")
  r = Bg.assess(book, { [IRON] = 120, [COPPER] = 30 }, { defense = def, upgrades = ups_big }, false)
  ck(r.core_ok and not r.covered, "h2b. noyau couvert une fois seulement et amélioration trop chère : la retenue demeure")
  r = Bg.assess(book, { [IRON] = 50, [COPPER] = 100 }, { defense = def, upgrades = ups_big }, true)
  ck(not r.covered, "h3. en parallèle mais noyau non couvert : la retenue revient")
  -- i. Sans coût connu : le noyau doit être couvert deux fois.
  r = Bg.assess(book, { [IRON] = 120, [COPPER] = 30 }, { defense = def, upgrades = {} }, false)
  ck(r.core_ok and not r.covered, "i. noyau couvert une fois seulement, aucun coût connu : pas de parallèle")
  r = Bg.assess(book, { [IRON] = 400, [COPPER] = 100 }, { defense = def, upgrades = {} }, false)
  ck(r.covered, "i2. noyau couvert deux fois, aucun coût connu : parallèle")
  -- j. Rien à protéger : couvert.
  r = Bg.assess(book, {}, { defense = {}, rebuild = {}, upgrades = {} }, false)
  ck(r.covered, "j. aucune demande de défense ni de reconstruction : couvert")
  -- k. Le stock n'est pas modifié ; le résultat est déterministe.
  local stock = { [IRON] = 500, [COPPER] = 100 }
  local claims = { defense = def, upgrades = { { key = "u1", cost = { { IRON, 100 } } } } }
  local r1 = Bg.assess(book, stock, claims, false)
  local r2 = Bg.assess(book, stock, claims, false)
  ck(stock[IRON] == 500 and stock[COPPER] == 100, "k. le stock donné n'est pas modifié")
  ck(r1.why == r2.why and r1.covered == r2.covered and #r1.admitted == #r2.admitted, "k2. déterministe")
  ck(Bg.describe(r1):find("COUVERT", 1, true) ~= nil and Bg.describe(nil):find("non evalue", 1, true) ~= nil, "k3. ligne de journal")
  return fails
end

print("== 1. Règle pure (Bg.assess)")
local Bg = require("shared.ai3.budget")
local f0 = battery(Bg, true)

print("== 2. Pi.update : la retenue ne vaut que si le budget manque")
local Pi = require("shared.ai3.pile")
local function sig(over)
  local s = { posts = { { id = "hq", have = 0, want = 2, why = "fabrication", raw = {}, claim = { { TURRET, 2 } } } },
    sources = { [IRON] = true, [COPPER] = true }, inputs = {}, book = book, avail = { [IRON] = 500, [COPPER] = 100 },
    upgrades = { { key = "capital:x", cost = { { IRON, 100 } } } } }
  for k, v in pairs(over or {}) do s[k] = v end
  return s
end
local st = Pi.new()
Pi.update(st, sig(), 100)
check(st.top == Pi.ADAPTER and not st.hold and st.parallel and st.budget and st.budget.covered, "poste sous son minimum, stock qui couvre tout : sommet s'adapter, retenue tombée, parallèle")
check(st.changed, "le passage en parallèle est un changement (journal)")
check(Pi.allows(st, "capital", "autre") and select(1, Pi.porte(st, "capital", "autre", false)), "capital et capitalisation passent la porte en parallèle")
check(Pi.describe(st):find("en parallele", 1, true) and Pi.describe(st):find("budget COUVERT", 1, true), "journal : « PERMIS (budget couvert, en parallele) » et le budget")
Pi.update(st, sig(), 101)
check(not st.changed, "second passage identique : aucun changement")
-- stock insuffisant : la retenue demeure
st = Pi.new()
Pi.update(st, sig({ avail = { [IRON] = 60, [COPPER] = 100 } }), 100)
check(st.hold and not st.parallel and st.budget and not st.budget.covered, "stock insuffisant pour la défense : la retenue demeure")
check(not select(1, Pi.porte(st, "capital", "autre", false)), "… et la porte refuse le capital")
-- tâche déjà prise par le poste : rien à payer pour lui
st = Pi.new()
Pi.update(st, sig({ posts = { { id = "hq", have = 1, want = 2, why = "tache_creee", raw = {} } }, avail = { [IRON] = 150, [COPPER] = 0 },
  upgrades = { { key = "capital:x", cost = { { IRON, 100 } } } } }), 100)
check(not st.hold and st.parallel, "poste dont les objets sont déjà pris (aucune demande) : l'amélioration payée passe")
-- relecture : QG menacé, la retenue reste ; sous l'effectif, les recrues manquantes entrent au noyau
st = Pi.new()
Pi.update(st, sig({ survive = "qg" }), 100)
check(st.hold and not st.parallel and st.budget == nil, "QG menacé : la retenue reste, quel que soit le stock")
st = Pi.new()
Pi.update(st, sig({ survive = "effectif", avail = { [IRON] = 500, [COPPER] = 100 } }), 100)
check(not st.hold and st.parallel, "sous l'effectif, stock qui couvre aussi les recrues absentes : parallèle")
st = Pi.new()
Pi.update(st, sig({ survive = "effectif", recruit_claim = { { IRON, 2000 } }, avail = { [IRON] = 500, [COPPER] = 100 } }), 100)
check(st.hold and not st.parallel, "sous l'effectif, recrues trop chères pour le stock : la retenue demeure")
local sg = Pi.signals({ workers = 2, recover_floor = 5, recruit_cost = { { IRON, 30 } } }, {}, {}, {}, nil, nil)
check(sg.survive == "effectif" and sg.recruit_claim[1][2] == 90, "signaux : 3 recrues manquantes à 30 fer = 90 fer au noyau")
-- relecture : la menace ne ferme la capitalisation que si la pile retient encore
check(Pi.threat_open({ parallel = true, top = Pi.ADAPTER }) and Pi.threat_open({ top = Pi.AMELIORER }), "menace : parallèle ou sommet améliorer, l'évolution reste ouverte")
check(not Pi.threat_open({ parallel = false, top = Pi.ADAPTER }) and not Pi.threat_open(nil), "menace : pile retenue ou absente, la menace ferme comme avant")
check(Pi.threat_open({ top = Pi.ADAPTER, blocked = true }), "intégration : pile bloquée (amélioration permise), la menace ne ferme plus")
do
  local ex = Pi.threat_exempt({ top = Pi.PRODUIRE, hold = true, focus = { ["fer"] = true } }, { ["cuivre"] = true })
  check(ex["cuivre"] and ex["fer"] and not ex["pierre"], "intégration : matière en manque et cadre ouvert exemptés de la menace")
  check(Pi.threat_exempt({ top = Pi.SURVIVRE, hold = true }, { ["cuivre"] = true }) == nil, "intégration : sous « survivre », aucune exemption")
  check(Pi.threat_exempt(nil, { ["cuivre"] = true }) == nil, "intégration : sauvegarde sans pile, aucune exemption, aucune exception")
end
-- reconstruction comptée
st = Pi.new()
Pi.update(st, sig({ posts = {}, repair = { { key = "k1", item = TURRET, value = 5, prio = 75, have = 0, craftable = true },
  { key = "k2", item = TURRET, value = 5, prio = 75, have = 0, craftable = true } }, avail = { [IRON] = 100, [COPPER] = 100 } }), 100)
check(st.hold and not st.parallel, "2 tourelles à refaire sans objet, 100 fer : la retenue demeure")
st = Pi.new()
Pi.update(st, sig({ posts = {}, repair = { { key = "k1", item = TURRET, value = 5, prio = 75, have = 0, craftable = true } },
  avail = { [IRON] = 500, [COPPER] = 100 } }), 100)
check(not st.hold and st.parallel, "1 tourelle à refaire, 500 fer : parallèle")
-- pièce déjà prise par une tâche (claimed) : rien à payer
st = Pi.new()
Pi.update(st, sig({ posts = {}, repair = { { key = "k1", item = TURRET, value = 5, prio = 75, have = 0, craftable = true, claimed = true } },
  avail = { [IRON] = 0, [COPPER] = 0 }, upgrades = {} }), 100)
check(not st.hold and st.parallel, "pièce déjà prise par une tâche, noyau vide : rien ne retient")
-- projet du plan directeur rouvert
st = Pi.new()
Pi.update(st, sig({ posts = {}, plan_reopened = true, plan_path = true, plan_wants = { { TURRET, 3 } }, avail = { [IRON] = 100, [COPPER] = 100 } }), 100)
check(st.hold and not st.parallel, "projet rouvert à 3 tourelles, 100 fer : la retenue demeure")
-- sans livre : la retenue d'avant
st = Pi.new()
Pi.update(st, sig({ book = false }), 100)
check(st.hold and not st.parallel and st.budget == nil, "sans livre (réglage éteint) : la retenue d'avant")
-- hystérésis de la pile : parallèle, puis le stock descend mais le noyau reste couvert
st = Pi.new()
Pi.update(st, sig(), 100)
Pi.update(st, sig({ avail = { [IRON] = 120, [COPPER] = 30 } }), 101)
check(st.parallel and not st.hold, "stock descendu sous le prix de l'amélioration, noyau couvert : parallèle maintenu")
Pi.update(st, sig({ avail = { [IRON] = 20, [COPPER] = 30 } }), 102)
check(st.hold and not st.parallel and st.changed, "noyau non couvert : la retenue revient (changement)")
-- l'état reste sérialisable (aucune fonction)
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
check(no_fn(st), "état de la pile sans fonction (sauvegarde)")

print("== 3. Anti-échelle : aucun objet du jeu dans budget.lua et mall.lua")
local function slurp(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local function code_only(src)
  src = src:gsub("%-%-%[%[.-%]%]", "")
  src = src:gsub("%-%-[^\n]*", "")
  return src
end
for _, p in ipairs({ "shared/ai3/budget.lua", "shared/ai3/mall.lua" }) do
  local src = code_only(slurp(p))
  local bad = nil
  for _, w in ipairs({ "iron", "copper", "coal", "stone", "turret", "inserter", "assembling", "transport", "belt", "pole", "firearm", "gear",
    "electric", "steel", "wood", "pipe", "magazine", "chest", "furnace", "drill" }) do
    if src:find(w, 1, true) then bad = w end
  end
  check(bad == nil, p .. " ne nomme aucun objet du jeu (" .. tostring(bad) .. ")")
end

print("== 4. Mutants")
local function mutant(path, from, to, name, runner)
  local src = slurp(path)
  local i, j = src:find(from, 1, true)
  if not i then check(false, "mutant '" .. name .. "' : texte introuvable") return end
  local m = src:sub(1, i - 1) .. to .. src:sub(j + 1)
  local tmp = os.tmpname()
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
local B = "shared/ai3/budget.lua"
mut(B, "Bg.MARGIN_PCT = 110", "Bg.MARGIN_PCT = 100", "marge de 10 % retirée", battery)
mut(B, "if next(base.raw) ~= nil then", "if false then", "noyau toujours réputé couvert", battery)
mut(B, "if next(pc.raw) == nil then", "if true then", "toute amélioration admise sans contrôle", battery)
mut(B, "avail = pc.avail\n", "\n", "stock non entamé par l'amélioration admise (double dépense)", battery)
mut(B, "elseif prev then", "elseif false then", "hystérésis retirée", battery)
mut(B, "out.skipped[#out.skipped + 1] = u.key", "break", "amélioration trop chère : arrêt au lieu de sauter", battery)
mut(B, "Bg.MARGIN_PCT + Bg.NEUTRAL_PCT", "Bg.MARGIN_PCT", "marge élargie sans coût connu retirée", battery)
mut(B, "concat(claims.defense, claims.rebuild), Bg.MARGIN_PCT)", "claims.defense, Bg.MARGIN_PCT)", "reconstruction ignorée du noyau", battery)
-- branchement dans Pi.update : le module mutant remplace le vrai (même chemin de chargement)
local function pi_runner(PiM)
  local fails = 0
  local function ck(c) if not c then fails = fails + 1 end end
  local s1 = PiM.new()
  PiM.update(s1, sig(), 100)
  ck(not s1.hold and s1.parallel)
  local s2 = PiM.new()
  PiM.update(s2, sig({ avail = { [IRON] = 60, [COPPER] = 100 } }), 100)
  ck(s2.hold and not s2.parallel)
  local s3 = PiM.new()
  PiM.update(s3, sig({ posts = { { id = "hq", have = 1, want = 2, why = "tache_creee", raw = {} } }, avail = { [IRON] = 150, [COPPER] = 0 } }), 100)
  ck(not s3.hold)
  local s4 = PiM.new()
  PiM.update(s4, sig({ posts = {}, plan_reopened = true, plan_path = true, plan_wants = { { TURRET, 3 } }, avail = { [IRON] = 100, [COPPER] = 100 } }), 100)
  ck(s4.hold)
  local s5 = PiM.new()
  PiM.update(s5, sig({ posts = {}, repair = { { key = "k1", item = TURRET, value = 5, prio = 75, have = 0, craftable = true },
    { key = "k2", item = TURRET, value = 5, prio = 75, have = 0, craftable = true } }, avail = { [IRON] = 100, [COPPER] = 100 } }), 100)
  ck(s5.hold)
  local s6 = PiM.new()
  PiM.update(s6, sig({ avail = { [IRON] = 130, [COPPER] = 100 } }), 100) -- défense (3 tourelles avec la marge : 120 fer) + 100 fer d'amélioration > 130
  ck(s6.hold and not s6.parallel)
  local s7 = PiM.new()
  PiM.update(s7, sig({ survive = "qg" }), 100)
  ck(s7.hold)
  local s8 = PiM.new()
  PiM.update(s8, sig({ survive = "effectif", recruit_claim = { { IRON, 2000 } }, avail = { [IRON] = 500, [COPPER] = 100 } }), 100)
  ck(s8.hold)
  ck(not PiM.threat_open({ parallel = false, top = PiM.ADAPTER }))
  return fails
end
local P = "shared/ai3/pile.lua"
mut(P, "if budget.covered then hold, parallel = false, true end", "", "la retenue ne tombe jamais", pi_runner)
mut(P, 'if hold and sig.book and sig.survive ~= "qg" then', "if hold and false then", "budget jamais évalué", pi_runner)
mut(P, ' and sig.survive ~= "qg" then', " then", "QG menacé levé par le budget", pi_runner)
mut(P, "for _, it in ipairs(sig.recruit_claim or {}) do claims.defense[#claims.defense + 1] = it end", "", "recrues ignorées du noyau", pi_runner)
mut(P, "return st ~= nil and (st.parallel == true or st.top == Pi.AMELIORER or st.blocked == true)", "return false", "menace jamais ouverte (parallèle sans effet)", function(PiM)
  return PiM.threat_open({ parallel = true, top = PiM.ADAPTER }) and 0 or 1
end)
mut(P, "for _, it in ipairs(p.claim or {}) do claims.defense[#claims.defense + 1] = it end", "", "défense ignorée du noyau", pi_runner)
mut(P, "for _, it in ipairs(sig.plan_wants or {}) do claims.rebuild[#claims.rebuild + 1] = it end", "", "projet rouvert ignoré du noyau", pi_runner)
mut(P, "if a.n - a.claimed > 0 then claims.rebuild", "if false then claims.rebuild", "pièces à refaire ignorées du noyau", pi_runner)
print(string.format("   mutants refusés : %d / %d", killed, total))
check(killed == total, "tous les mutants refusés")

print(string.format("[PILE-BUDGET] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, killed, total))
os.exit(failures == 0 and 0 or 1)
