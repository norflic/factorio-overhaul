--[[
  IA3-a (préparation, lot IA3-0) : test hors jeu de la règle « recherche d'abord, rien d'impayable »
  (shared/ai3/recherche.lua ; docs/IA3_CERVEAU.md §6.2 ; revue B3).

  Données RÉELLES : recettes vanilla + mod (tests/fixtures/recipes_ia1e.lua), livre de la main (shared/team/book.lua)
  filtré comme en jeu par les recettes ACTIVES de la force (une faction au niveau L a les technologies de
  T.unlocks[0..L], tests/fixtures/tech_ai3.lua), niveaux T.research, caractères d'IA2-0 (Tr.ARCHETYPES), affinités du
  chef d'IA2-a (C.AFFINITY).

  Ce qu'il prouve :
    1. niveaux 1 à 3 payables à la main au niveau précédent ; niveau 4 IMPAYABLE (pack chimique) : AUCUN pack demandé
       (K6, défaut C1) ;
    2. le caractère décide « recherche ou armée d'abord » (D-18) : technocrate au-dessus de l'armée ordinaire (45),
       conquérant en dessous, neutre juste au-dessus ;
    3. garde de l'économie (revue B3) : avant le fer II, jamais au-dessus de la fabrication d'objectif (50) ; le plancher
       de l'avant-poste suivant n'est jamais entamé ; quand la recherche est l'objectif, au moins 50 ;
    4. demandes dès le départ (niveau 0 → 1, sans verrou « tech1 »), au plus 30 par sorte ;
    5. généricité (aucun nom de pack dans le module) et déterminisme ;
    6. lot IA3-a : BRANCHEMENT dans le planificateur (view.ia3_research) : packs dès l'objectif « défense », réglage
       éteint = règle d'avant, niveau 4 sans aucun pack (témoin éteint : défaut C1), paiement, objectif « tech1 » à 50
       au moins, plancher (packs réduits, manque de fer compté), ordre du stock virtuel selon le caractère (neutre :
       packs avant l'armée ; conquérant : l'armée d'abord), déterminisme.

  Usage : lua5.2 tests/ai3_recherche_test.lua   (depuis la racine du mod)
]]

package.path = "./?.lua;" .. package.path
local A = require("shared.ai3.recherche")
local Book = require("shared.team.book")
local T = require("shared.team.config")
local Tr = require("shared.faction.traits")
local C = require("shared.faction.chef")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[AI3-RECHERCHE] ECHEC : " .. msg) end
end

local recipes = dofile("tests/fixtures/recipes_ia1e.lua")
local techs = dofile("tests/fixtures/tech_ai3.lua")

-- Recettes actives d'une faction au niveau L : celles qu'aucune technologie ne débloque, plus celles des technologies
-- de T.unlocks[0..L] (comme unlock() de script/team/team.lua).
local unlocked_by = {}
for tname, t in pairs(techs) do for _, r in ipairs(t.unlocks or {}) do unlocked_by[r] = unlocked_by[r] or {} ; unlocked_by[r][tname] = true end end
local function book_at(level)
  local have = {}
  for l = 0, level do for _, tn in ipairs(T.unlocks[l] or {}) do have[tn] = true end end
  return Book.new(recipes, { allowed = function(name)
    local by = unlocked_by[name]
    if not by then return true end
    for tn in pairs(by) do if have[tn] then return true end end
    return false
  end })
end

-- Sources de matières premières de l'ancien cerveau (SOURCE de shared/team/planner.lua).
local SOURCE = { ["coal"] = true, ["stone"] = true, ["iron-ore"] = true, ["copper-ore"] = true, ["iron-plate"] = true,
  ["copper-plate"] = true, ["steel-plate"] = true, ["stone-brick"] = true }
local function obtainable(item) return SOURCE[item] == true end

local function kit_stock()
  local s = {}
  for _, it in ipairs(T.start_kit) do s[it[1]] = it[2] end
  return s
end

-- 1. Payabilité des niveaux.
for level = 0, 3 do
  local book = book_at(level)
  local ok, causes = A.level_status(book, T.research[level + 1], obtainable)
  if level < 3 then
    check(ok, string.format("niveau %d payable à la main au niveau %d (causes : %s)", level + 1, level, table.concat(causes, ", ")))
  else
    local chem = false
    for _, c in ipairs(causes) do if c == "chemical-science-pack" then chem = true end end
    check(not ok and chem, "niveau 4 impayable sans pétrole, cause « chemical-science-pack » (" .. table.concat(causes, ", ") .. ")")
    local d = A.plan({ tech = 3, levels = T.research, stock = { ["automation-science-pack"] = 5 }, book = book,
      obtainable = obtainable, avail = { ["iron-plate"] = 5000, ["copper-plate"] = 5000 }, economy_done = true, lean = 1000 })
    check(#d.wants == 0 and d.held == "impayable",
      "niveau 4 impayable : AUCUN pack demandé, même les rouges (K6 ; défaut C1 : 120 rouges, 52 à 105 verts, 60 militaires)")
  end
end

-- 2. Le caractère (D-18).
local function prio_of(arch, mix, economy_done)
  return A.priority(A.lean(Tr.ARCHETYPES[arch], mix, C.AFFINITY), { economy_done = economy_done })
end
local pt, pc, pb = prio_of("technocrat", nil, true), prio_of("conqueror", nil, true), prio_of("balanced", nil, true)
print(string.format("[AI3-RECHERCHE] priorité des packs (armée ordinaire 45, objectif 50) : technocrate %d, conquérant %d, neutre %d, bâtisseur %d",
  pt, pc, pb, prio_of("builder", nil, true)))
check(pt > 45 and pc < 45 and pb > 45, "le caractère décide : technocrate au-dessus de l'armée (45), conquérant en dessous, neutre au-dessus")
local tech_mix = { { key = "technologie", w = 700 }, { key = "expansion", w = 300 } }
local army_mix = { { key = "armee", w = 700 }, { key = "assaut", w = 300 } }
check(prio_of("balanced", tech_mix, true) > prio_of("balanced", nil, true)
  and prio_of("balanced", army_mix, true) < prio_of("balanced", nil, true),
  "la posture du chef (technologie, armée) déplace la priorité dans le bon sens")
local lo, hi = 1000, 0
for _, a in ipairs({ "conqueror", "technocrat", "builder", "balanced" }) do
  for _, m in ipairs({ tech_mix, army_mix, {} }) do
    local p = prio_of(a, m, true)
    if p < lo then lo = p end
    if p > hi then hi = p end
  end
end
check(lo >= 36 and hi <= 56, string.format("priorités bornées entre 36 et 56 (%d à %d) : jamais au-dessus du recrutement (55) sauf technocrate en posture technologie", lo, hi))

-- 3. Garde de l'économie (revue B3).
check(prio_of("technocrat", tech_mix, false) <= 49, "avant le fer II : jamais au-dessus de la fabrication d'objectif (50)")
check(A.priority(-1000, { economy_done = true, is_goal = true }) >= 50, "quand la recherche est l'objectif de l'échelle : au moins 50")
do
  local book = book_at(0)
  local stock = kit_stock()
  -- 200 fer au coffre, plancher 160 (avant-poste de fer suivant) : 40 fer de libres, un pack rouge en coûte 3.
  local d = A.plan({ tech = 0, levels = T.research, stock = stock, book = book, obtainable = obtainable,
    avail = { ["iron-plate"] = 200, ["copper-plate"] = 60 }, floor = { ["iron-plate"] = 160 }, economy_done = false, lean = 0 })
  local n = d.wants[1] and d.wants[1][2] or 0
  local per = book:raw_cost({ { "automation-science-pack", 1 } })
  local used = n * (per["iron-plate"] or 0)
  check(d.capped and used <= 40 and n > 0, string.format("plancher : %d packs rouges demandés (%d fer sur 40 libres ; %s fer par pack)", n, used, tostring(per["iron-plate"])))
  local d2 = A.plan({ tech = 0, levels = T.research, stock = stock, book = book, obtainable = obtainable,
    avail = { ["iron-plate"] = 150, ["copper-plate"] = 60 }, floor = { ["iron-plate"] = 160 }, economy_done = false, lean = 0 })
  check(#d2.wants == 0 and d2.held == "plancher de l'economie", "sous le plancher : aucun pack (l'avant-poste de fer passe d'abord)")
end

-- 4. Dès le départ, au plus 30 par sorte.
do
  local d = A.plan({ tech = 0, levels = T.research, stock = kit_stock(), book = book_at(0), obtainable = obtainable,
    avail = kit_stock(), economy_done = false, lean = 0 })
  check(d.payable and #d.wants == 1 and d.wants[1][1] == "automation-science-pack" and d.wants[1][2] == 30,
    "niveau 0 : 30 packs rouges demandés dès le départ (sans verrou « tech1 ») avec le coffre de départ")
  local d2 = A.plan({ tech = 1, levels = T.research, stock = { ["automation-science-pack"] = 12 }, book = book_at(1),
    obtainable = obtainable, avail = { ["iron-plate"] = 9999, ["copper-plate"] = 9999 }, economy_done = true, lean = 0 })
  check(#d2.wants == 2 and d2.wants[1][2] == 30 and d2.wants[2][2] == 30, "niveau 2 : 30 rouges et 30 verts à la fois (10 avant IA3-a)")
  local st = { ["automation-science-pack"] = 30 }
  local d3 = A.plan({ tech = 0, levels = T.research, stock = st, book = book_at(0), obtainable = obtainable, avail = st,
    economy_done = true, lean = 0 })
  check(d3.have_all and #d3.wants == 0, "tous les packs au stock : le niveau se paie, rien de plus n'est fabriqué")
end

-- 5. Généricité et déterminisme.
do
  local f = assert(io.open("shared/ai3/recherche.lua", "rb"))
  local src = f:read("*a")
  f:close()
  local hits = {}
  for _, lvl in ipairs(T.research) do
    for _, it in ipairs(lvl) do if src:find('"' .. it[1] .. '"', 1, true) then hits[#hits + 1] = it[1] end end
  end
  check(#hits == 0, "généricité : aucun nom de pack dans le module (" .. table.concat(hits, ", ") .. ")")
  local args = { tech = 1, levels = T.research, stock = { ["automation-science-pack"] = 3 }, book = book_at(1),
    obtainable = obtainable, avail = { ["iron-plate"] = 300, ["copper-plate"] = 100 }, floor = { ["iron-plate"] = 100 },
    economy_done = false, lean = 300 }
  local function ser(d)
    local p = { tostring(d.prio), tostring(d.held), tostring(d.capped) }
    for _, w in ipairs(d.wants) do p[#p + 1] = w[1] .. "=" .. w[2] end
    return table.concat(p, ",")
  end
  check(ser(A.plan(args)) == ser(A.plan(args)), "déterminisme : même décision deux fois")
end

-- 6. Lot IA3-a : BRANCHEMENT dans le planificateur (shared/team/planner.lua, view.ia3_research). Vue de faction minimale
-- (coffre de départ ou coffre riche), livre de la faction à son niveau.
local P = require("shared.team.planner")
local S = require("shared.team.scale")
local function upto(key, extra)
  local d = {}
  for _, g in ipairs(T.ladder) do
    d[g.key] = true
    if g.key == key then break end
  end
  for _, k in ipairs(extra or {}) do d[k] = true end
  return d
end
local function fview(over)
  local v = {
    tech = 0, personality = "balanced", done = upto("stone"), deferred = {}, stock = kit_stock(), incoming = {},
    outposts = {}, pending = {}, sites = {}, smelters = 2, smelters_pending = 0, smelter_task = true, smelter_output = 0,
    smelter_fuel_low = false, smelter_coal = 0, turret_groups = {}, soldiers = 10, soldiers_max = 30, workers = 4,
    workers_max = 4, workers_idle = 0, workers_wanted = 4, threatened = false, open = {}, ladder = T.ladder,
    no_research = false, ia3_research = true, research_lean = 0,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function tagged(plan, tag)
  local n, prio = 0, nil
  for _, t in ipairs(plan.tasks) do
    if t.kind == "craft" and t.tag == tag then n = n + 1; prio = prio or t.prio end
  end
  return n, prio
end
local rich = { ["iron-plate"] = 5000, ["copper-plate"] = 5000, coal = 2000, stone = 2000, ["stone-brick"] = 500,
  ["steel-plate"] = 500, ["firearm-magazine"] = 200 }
do
  -- a) Dès le départ (objectif « défense », niveau 0) : packs rouges commandés, priorité du caractère (neutre 46).
  local v = fview()
  local p = P.plan(v, book_at(0))
  local n, prio = tagged(p, "recherche")
  check(n > 0 and prio == A.priority(0, { economy_done = false }),
    string.format("branché : packs commandés dès l'objectif « défense » (%d tâches, priorité %s)", n, tostring(prio)))
  v.ia3_research = nil
  check(tagged(P.plan(v, book_at(0)), "recherche") == 0, "réglage éteint : règle d'avant (aucun pack avant « tech1 »)")
  -- b) Niveau 4 impayable (pack chimique) : AUCUN pack, même riche ; la règle d'avant en fabriquait (défaut C1).
  local v4 = fview({ tech = 3, done = upto("tech3"), stock = rich, soldiers = 30 })
  local p4 = P.plan(v4, book_at(3))
  check(tagged(p4, "recherche") == 0 and p4.research_rule and p4.research_rule.held == "impayable",
    "niveau 4 impayable : aucun pack commandé, décision « impayable » rendue")
  v4.ia3_research = nil
  check(tagged(P.plan(v4, book_at(3)), "recherche") > 0, "témoin : réglage éteint, les packs du niveau 4 sont commandés (défaut C1)")
  -- c) Packs au stock : le niveau se paie.
  local pr = P.plan(fview({ stock = { ["automation-science-pack"] = 30, ["iron-plate"] = 200 } }), book_at(0))
  check(pr.research == 1, "packs du niveau 1 au stock : recherche payée (out.research = 1)")
  -- d) La recherche est l'objectif (« tech1 ») : priorité 50 au moins.
  local pg = P.plan(fview({ done = upto("iron2", { "coal", "iron", "copper", "stone" }), stock = rich,
    outposts = { { id = 1, kind = "iron", drills = 16, full = false, turrets = 1, coal_needed = 0, fuel_low = false,
      output = 0, idle_ticks = 0, has_task = true, has_fortify = false } } }), book_at(0))
  local _, gprio = tagged(pg, "recherche")
  check(pg.goal == "tech1" and (gprio or 0) >= 50, string.format("objectif « tech1 » : priorité %s (au moins 50)", tostring(gprio)))
  -- e) Plancher de l'économie : 100 fer, plancher d'un avant-poste de fer ; packs réduits, manque compté (fonte).
  local pf = P.plan(fview({ done = upto("army"), stock = { ["iron-plate"] = 100, ["copper-plate"] = 100 } }), book_at(0))
  local rr = pf.research_rule or {}
  local nf = 0
  for _, t in ipairs(pf.tasks) do if t.tag == "recherche" then nf = nf + (t.count or 0) end end
  check(rr.capped and (rr.floor_iron or 0) > 0 and nf * 2 <= 100 - rr.floor_iron and (pf.smelt["iron-plate"] or 0) > 0,
    string.format("plancher : %d packs rouges sur 30 (plancher %s fer), manque de fer compté (fonte %s)", nf,
      tostring(rr.floor_iron), tostring(pf.smelt["iron-plate"])))
  -- e2) Défaut du 1er essai en moteur réel (manque compté sans le stock : acier redemandé à chaque pensée, briques
  -- jamais fondues) : niveau 3 retenu par le plancher, acier et briques AU COFFRE : ni acier ni briques demandés à la
  -- fonderie ; le fer au-dessus du plancher, lui, l'est.
  local pm = P.plan(fview({ tech = 2, done = upto("army"), stock = { ["automation-science-pack"] = 80,
    ["logistic-science-pack"] = 60, ["steel-plate"] = 50, ["stone-brick"] = 200, ["iron-plate"] = 100,
    ["copper-plate"] = 500, coal = 500, stone = 500 } }), book_at(2))
  local rm = pm.research_rule or {}
  check(rm.capped and pm.smelt["steel-plate"] == nil and pm.smelt["stone-brick"] == nil and (pm.smelt["iron-plate"] or 0) > 0,
    string.format("plancher au niveau 3 : acier %s, briques %s, fer %s demandés à la fonderie (acier et briques au coffre)",
      tostring(pm.smelt["steel-plate"]), tostring(pm.smelt["stone-brick"]), tostring(pm.smelt["iron-plate"])))
  -- f) Ordre du stock virtuel = ordre des priorités : 260 fer, un lot de 5 fusiliers en coûte 250 (mitraillette 30,
  -- 5 chargeurs 20), 30 packs rouges 60 : fer pour UN seul des deux. Neutre (46) :
  -- les packs d'abord ; conquérant (42) : l'armée d'abord. Objectif « fonderie » (pas la recherche), avant-postes de
  -- fer de l'échelle faits (pas de plancher) ; soldats sous la cible.
  local all = upto("tech1", { "iron3", "iron4", "expand" })
  local function ordered(lean)
    local p = P.plan(fview({ tech = 0, done = all, soldiers = 0, research_lean = lean,
      stock = { ["iron-plate"] = 260, ["copper-plate"] = 100, ["firearm-magazine"] = 0 } }), book_at(0))
    local packs = 0
    for _, t in ipairs(p.tasks) do if t.tag == "recherche" then packs = packs + (t.count or 0) end end
    return packs, tagged(p, "armee"), p.research_rule or {}
  end
  local rn, an, rrn = ordered(0)
  local rc, ac, rrc = ordered(-1000)
  check(rrn.first and rn == 30, string.format("neutre (%s) : packs servis avant l'armée (%d packs sur 30, %d tâches d'armée)", tostring(rrn.prio), rn, an))
  check(not rrc.first and ac > 0 and rc < 30, string.format("conquérant (%s) : armée servie d'abord (%d tâches d'armée, %d packs sur 30)", tostring(rrc.prio), ac, rc))
  -- g) Déterminisme du plan branché.
  local s1, s2 = {}, {}
  for _, t in ipairs(P.plan(fview(), book_at(0)).tasks) do s1[#s1 + 1] = t.key .. "@" .. t.prio .. "x" .. tostring(t.count) end
  for _, t in ipairs(P.plan(fview(), book_at(0)).tasks) do s2[#s2 + 1] = t.key .. "@" .. t.prio .. "x" .. tostring(t.count) end
  check(table.concat(s1, ";") == table.concat(s2, ";"), "déterminisme : même plan branché deux fois")
end

print(string.format("[AI3-RECHERCHE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
