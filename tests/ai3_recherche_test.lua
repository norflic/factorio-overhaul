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
    5. généricité (aucun nom de pack dans le module) et déterminisme.

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
  for _, it in ipairs(T.start_kit_generous) do s[it[1]] = it[2] end
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

-- 4 bis (lot KIT). Le kit RÉEL d'une faction (coffre vide, comme votre équipe) : la recherche est demandée, payable, et les 30
-- packs rouges de départ le sont aussi (la matière se récolte ; le plafond reste celui du niveau, pas du coffre).
do
  check(next((function() local s = {} for _, it in ipairs(T.start_kit) do s[it[1]] = it[2] end return s end)()) == nil,
    "kit réel : coffre de départ vide (T.start_kit)")
  local d = A.plan({ tech = 0, levels = T.research, stock = {}, book = book_at(0), obtainable = obtainable, avail = {},
    economy_done = false, lean = 0 })
  check(d.payable and #d.wants == 1 and d.wants[1][1] == "automation-science-pack" and d.wants[1][2] == 30,
    "niveau 0 depuis le kit réel : 30 packs rouges demandés (payable, coffre vide)")
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

print(string.format("[AI3-RECHERCHE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
