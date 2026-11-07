--[[
  Sortie de spirale (shared/team/spirale.lua), règle PURE non branchée. États de la partie du DC sur 0.6.58
  (fo-logs/2026-11-07_PARTIE-DC-0658/factorio-current-1415.log, votre équipe) :
    - 157,7 à 177 min : 2 PNJ, effectif de départ 12, fer libre 0 ([FO-DEFENSE]), pierre saturée ([FO-IA3C] « sature [copper-plate
      stone] ») ;
    - 153,5 min : fer libre 28 ([FO-DEFENSE]).
  Fer d'une recrue : kit (pistolet 5 fer + 10 chargeurs ; 194 chargeurs au coffre, [FO-REARMEMENT]) + (10 + effectif) fer
  (shared/team/org.lua:1083) : 5 + 12 = 17 à 2 PNJ (HYPOTHÈSE : pistolet absent du coffre, chargeurs présents).
  Lancement : lua5.2 tests/spirale_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local Sp = require("shared.team.spirale")

local quiet = false
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC : " .. msg) end
  end
end

local NEED = 17
local function suite()
  local d = Sp.decide({ workers = 2, floor = 12, iron = 0, recruit_iron = NEED, stone_saturated = true })
  check(d.hold == 0 and d.mine and d.stop_stone and not d.unarmed,
    "partie du DC, 157-177 min (2 PNJ, fer 0, pierre saturee) : minage d'urgence du fer, plus de pierre ; pas de recrue sans arme a 2")
  local d28 = Sp.decide({ workers = 2, floor = 12, iron = 28, recruit_iron = NEED, stone_saturated = true })
  check(d28.hold == NEED and Sp.iron_for_others(28, d28) == 28 - NEED and not d28.mine and not d28.stop_stone,
    "153,5 min (fer 28) : 17 gardes pour la recrue, 11 pour les autres ; assez pour une recrue : ni minage, ni arret de la pierre")
  local d10 = Sp.decide({ workers = 2, floor = 12, iron = 10, recruit_iron = NEED })
  check(d10.hold == 10 and Sp.iron_for_others(10, d10) == 0 and d10.mine,
    "fer 10 < 17 : tout le fer garde pour la recrue (les autres ne voient rien), minage d'urgence")
  local d1 = Sp.decide({ workers = 1, floor = 12, iron = 0, recruit_iron = NEED })
  check(d1.unarmed and d1.mine, "1 PNJ, fer 0 : recrue sans arme (parite avec les factions, planner.lua:943-947)")
  local up = Sp.decide({ workers = 12, floor = 12, iron = 0, recruit_iron = NEED, stone_saturated = true })
  check(up.hold == 0 and not up.mine and not up.unarmed and not up.stop_stone, "a l'effectif de depart : la regle ne fait rien")
  local nf = Sp.decide({ workers = 2, floor = 0, iron = 0, recruit_iron = NEED })
  check(nf.hold == 0 and not nf.mine, "sans effectif de depart connu (factions) : rien")
  check(Sp.decide(nil).hold == 0 and Sp.iron_for_others(5, nil) == 5, "entrees absentes : rien, le fer reste a tous")
  local ns = Sp.decide({ workers = 2, floor = 12, iron = 0, recruit_iron = NEED, stone_saturated = false })
  check(not ns.stop_stone and ns.mine, "pierre non saturee : la pierre continue")
end

-- §2 branchement au planificateur (shared/team/planner.lua) : vues de votre équipe (recover_floor), livre des tests
local Planner = require("shared.team.planner")
local Book = require("shared.team.book")
local S = require("shared.team.scale")
local book = Book.new(dofile("tests/fixtures/recipes.lua"))
local function pview(over)
  local v = {
    tech = 0, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {},
    outposts = {}, pending = {}, sites = {}, smelters = 2, smelters_pending = 0, smelter_task = false,
    smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0, turret_groups = {},
    soldiers = 0, soldiers_max = 0, workers = 2, workers_max = 30, workers_idle = 0, threatened = false, open = {},
    workers_wanted = 30, no_research = true, recover_floor = 12,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function has_task(plan, key)
  for _, t in ipairs(plan.tasks) do if t.key == key then return t end end
  return nil
end
local DC = { ["firearm-magazine"] = 194, ["copper-plate"] = 5385, stone = 28888, coal = 300 }
local function suite_planner()
  check(Sp.recruit_iron(S.recruit_cost(2), DC, book) == 17,
    "fer d'une recrue a 2 PNJ, 194 chargeurs au coffre : pistolet 5 + (10 + 2) = 17 (" .. tostring(Sp.recruit_iron(S.recruit_cost(2), DC, book)) .. ")")
  local p2 = Planner.plan(pview({ workers = 2, stock = DC }), book)
  local mt = has_task(p2, "mine:iron-ore")
  check(mt ~= nil and mt.prio == 90 and not p2.recruit_unarmed,
    "partie du DC (2 PNJ, fer 0) : minage d'urgence du fer (priorite 90), pas de recrue sans arme a 2")
  local p1 = Planner.plan(pview({ workers = 1, stock = DC }), book)
  check(p1.recruit_workers == 1 and p1.recruit_unarmed and p1.emergency_unarmed and has_task(p1, "mine:iron-ore") ~= nil,
    "1 PNJ, fer 0 : recrue sans arme (emergency_unarmed, comme les factions) et minage d'urgence")
  local p12 = Planner.plan(pview({ workers = 12, stock = DC }), book)
  local m12 = has_task(p12, "mine:iron-ore")
  check((m12 == nil or m12.prio < 90) and (p12.spirale_hold or 0) == 0 and not p12.recruit_unarmed,
    "a l'effectif de depart : ni minage d'URGENCE (le minage ordinaire, priorite 45, reste), ni fer garde, ni recrue sans arme")
  local fac = Planner.plan(pview({ workers = 1, stock = DC, recover_floor = false, emergency = { floor = 12, rebuild = false } }), book)
  check((fac.spirale_hold or 0) == 0, "une faction (view.emergency, pas de recover_floor) : la regle ne s'applique pas")
  -- le fer GARDE : une tourelle sans chargeurs demande des munitions (priorite 90, entretien, AVANT la recrue) ; 60 fer, aucun chargeur
  local st60 = { ["iron-plate"] = 120, ["copper-plate"] = 100 } -- (120 fer : les 20 chargeurs de l'entretien, 80 fer, se font sans la regle)
  local tg = { { key = "o1", low = 1, has_task = false } }
  local need = Sp.recruit_iron(S.recruit_cost(2), st60, book)
  local ph = Planner.plan(pview({ workers = 2, stock = st60, turret_groups = tg }), book)
  check(ph.spirale_hold == math.min(120, need) and ph.recruit_workers == 1 and not ph.recruit_unarmed,
    string.format("120 fer, 20 chargeurs demandes par l'entretien (80 fer) : %d fer gardes, la recrue est payee (recrue %s)", ph.spirale_hold or -1,
      tostring(ph.recruit_workers)))
  local st57 = { ["iron-plate"] = need, ["copper-plate"] = 100 }
  local pe = Planner.plan(pview({ workers = 2, stock = st57, turret_groups = tg }), book)
  check(pe.spirale_hold == need and pe.recruit_workers == 1,
    string.format("fer juste egal au besoin (%d) : tout garde pendant l'entretien, puis RENDU a la recrue, qui est payee", need))
end
suite_planner()

suite()
local base_fail = failures

local real = Sp.decide
local killed, total = 0, 0
local function mutant(name, f)
  total = total + 1
  Sp.decide = f
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(function() suite() suite_planner() end)
  quiet = false
  Sp.decide = real
  local caught = (failures > f0) or not ok
  passes, failures = p0, f0
  if caught then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. name) end
end
mutant("aucune part gardee (avant)", function(s) local d = real(s) d.hold = 0 return d end)
mutant("tout le fer garde (plus que le besoin d'une recrue)", function(s) local d = real(s) if s and (s.workers or 0) < (s.floor or 0) then d.hold = s.iron or 0 end return d end)
mutant("regle aussi au-dessus de l'effectif de depart", function(s)
  local t = {} for k, v in pairs(s or {}) do t[k] = v end
  if t.floor then t.floor = math.max(t.floor, (t.workers or 0) + 1) end
  return real(t)
end)
mutant("recrue sans arme a 2 PNJ", function(s) local d = real(s) if s and (s.workers or 0) <= 2 and (s.iron or 0) < (s.recruit_iron or 0) then d.unarmed = true end return d end)
mutant("pas de minage d'urgence", function(s) local d = real(s) d.mine = false return d end)
mutant("pierre jamais arretee", function(s) local d = real(s) d.stop_stone = false return d end)
mutant("pierre arretee meme non saturee", function(s) local d = real(s) d.stop_stone = d.mine return d end)

-- mutants du branchement (copies mutees de shared/team/planner.lua, chargees a part)
local function src_of(path) local fh = assert(io.open(path, "rb")) local t = fh:read("*a") fh:close() return t end
local PSRC = src_of("shared/team/planner.lua")
local function planner_mutant(name, from, to, from2, to2)
  total = total + 1
  local a, b = PSRC:find(from, 1, true)
  if not a then print("  MUTANT INTROUVABLE : " .. name) return end
  local mutated = PSRC:sub(1, a - 1) .. to .. PSRC:sub(b + 1)
  if from2 then
    local a2, b2 = mutated:find(from2, 1, true)
    if not a2 then print("  MUTANT INTROUVABLE : " .. name) return end
    mutated = mutated:sub(1, a2 - 1) .. to2 .. mutated:sub(b2 + 1)
  end
  local real_planner = package.loaded["shared.team.planner"]
  local M = assert(load(mutated, "=planner-mutant"))()
  Planner = M
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(suite_planner)
  quiet = false
  Planner = real_planner
  local caught = (failures > f0) or not ok
  passes, failures = p0, f0
  if caught then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. name) end
end
planner_mutant("branchement : fer garde jamais retire (avant : ni retire ni rendu)",
  'if spir.hold > 0 then avail["iron-plate"] = avail["iron-plate"] - spir.hold end', "",
  'if spir.hold > 0 then avail["iron-plate"] = (avail["iron-plate"] or 0) + spir.hold end', "")
planner_mutant("branchement : fer garde jamais rendu a la recrue",
  'if spir.hold > 0 then avail["iron-plate"] = (avail["iron-plate"] or 0) + spir.hold end', "")
planner_mutant("branchement : pas de minage d'urgence (avant)", "if spir.mine then emergency_mine(p.raw) end", "")
planner_mutant("branchement : pas de recrue sans arme (avant)", "if spir.unarmed then", "if false then")

-- câblage hors du planificateur (structure) : le cerveau rend spirale_hold, Team.think le garde, les modules neufs le lisent
local function count(src, pat)
  local n, i = 0, 1
  while true do
    local x, y = src:find(pat, i, true)
    if not x then return n end
    n, i = n + 1, y + 1
  end
end
local WIRES = {
  { "shared/ai3/cerveau.lua", "spirale_hold = base.spirale_hold," },
  { "script/team/team.lua", "f.team.spirale_hold = h > 0 and h or nil" },
  { "script/team/build.lua", "((f.team and f.team.spirale_hold) or 0)" },
  { "script/team/build.lua", "local held = Sq.module_held({ iron = iron, reserve = reserve, rebuild = false })" },
}
local wired = true
for _, w in ipairs(WIRES) do if count(src_of(w[1]), w[2]) ~= 1 then wired = false print("  CABLAGE ABSENT : " .. w[1] .. " : " .. w[2]) end end
check(wired, "cablage : cerveau (spirale_hold), Team.think (f.team.spirale_hold), modules neufs (qg_held : reserve + fer garde)")
local tm_mut = 0
for _, w in ipairs(WIRES) do
  local src = src_of(w[1])
  local x, y = src:find(w[2], 1, true)
  local mutated = x and (src:sub(1, x - 1) .. "--" .. src:sub(y + 1)) or src
  if count(mutated, w[2]) ~= 1 then tm_mut = tm_mut + 1 end
end
check(tm_mut == #WIRES, string.format("mutants de texte du cablage : %d / %d vus", tm_mut, #WIRES))

print(string.format("[SPIRALE] MUTANTS : %d / %d refuses", killed, total))
print(string.format("[SPIRALE] BILAN : %d OK, %d ECHEC(S)%s", passes, failures + (total - killed), base_fail > 0 and " (suite de base en echec)" or ""))
os.exit((failures == 0 and killed == total) and 0 or 1)
