--[[
  Étape 2b d'INTEGRATION_VIDEO.md, lot L1b : le RANG de la décision (Ca.RANG, shared/ai3/rang.lua) BRANCHÉ dans
  shared/ai3/capitalisation.lua, ÉTEINT par défaut. Plan : fo-logs/2026-11-07_VIDEO-AUTOMATISATION/PLAN_L1_L2.md §2. Test hors jeu de
  la décision entière (Ca.decide).
    §0 interrupteur éteint par défaut ;
    §1 éteint : la règle du rang n'est JAMAIS appelée ;
    §2 A/B : rang allumé contre éteint, décision ENTIÈRE identique (ordres, refus, besoins, `st`) sur 3 décisions de suite de chaque
       scène sans cycle ; Kovarex (cycle) : l'arc interne n'est pas propagé ;
    §9 coût en instructions (debug.sethook) ; §10 mutants appliqués au SOURCE de shared/ai3/capitalisation.lua.
  Usage : lua5.2 tests/rang_cablage_test.lua   (depuis la racine du mod). Fichier de TEST : il nomme des objets vanilla.
]]

package.path = "./?.lua;" .. package.path
local F = require("tests.iag_fixture")
local Ca0 = require("shared.ai3.capitalisation")
local Rg = require("shared.ai3.rang")

local pass, fail, quiet = 0, 0, false
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if not quiet then print("[RANG-CABLAGE] ECHEC : " .. msg) end
  end
end
local function say(s) if not quiet then print("[RANG-CABLAGE] " .. s) end end

local function sk(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end
local function ser(v)
  if type(v) == "table" then
    local parts = {}
    for _, k in ipairs(sk(v)) do
      if type(v[k]) ~= "function" then parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
    end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif type(v) == "number" then return string.format("%.17g", v) end
  return tostring(v)
end
local function copy(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = copy(v) end
  return c
end

---------------------------------------------------------------------------------------------------
-- Relevé (vitesses et aires vanilla) et scènes
---------------------------------------------------------------------------------------------------
local SP = { ["stone-furnace"] = 1, ["steel-furnace"] = 2, ["assembling-machine-1"] = 0.5, ["assembling-machine-2"] = 0.75,
  ["burner-mining-drill"] = 0.25, ["electric-mining-drill"] = 0.5, ["lab"] = 1 }
local AR = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 5 }
local KW = { ["stone-furnace"] = 90, ["steel-furnace"] = 90, ["burner-mining-drill"] = 150, ["electric-mining-drill"] = 90,
  ["assembling-machine-1"] = 75, ["assembling-machine-2"] = 150, ["lab"] = 60, ["boiler"] = 1800 }
local function dump()
  local d = F.dump()
  for _, t in ipairs(sk(d.techs)) do
    for _, r in ipairs(d.techs[t].unlocks or {}) do if d.recipes[r] then d.recipes[r].enabled = false end end
  end
  for _, e in ipairs(d.entities) do
    if SP[e.name] then e.speed = SP[e.name] end
    e.mining_area = AR[e.name]
    e.size = e.name == "burner-mining-drill" and 2 or 3
    e.energy_kw = KW[e.name] -- (combustible des fours : sans puissance, plan.burn reste nul et le charbon n'entre jamais aux graines)
  end
  for _, r in ipairs(d.resources) do r.mining_time = 1 end
  return d
end
local EXEC = { ["stone-furnace"] = true, ["steel-furnace"] = true, ["burner-mining-drill"] = true,
  ["electric-mining-drill"] = true, ["assembling-machine-1"] = true, ["assembling-machine-2"] = true }
local ALL = {}
for t in pairs(dump().techs) do ALL[t] = true end
local function data(C) return C.data(dump(), { exec = EXEC, exec_roles = { main = true, labo = true } }) end

-- Corpus de l'A/B (le témoin de l'étape 2b) : cinq scènes de l'early game au lancement de fusée, plus une base neuve où le premier
-- four (à combustion) ajoute le charbon aux graines en cours de décision (le rang doit être refait).
local function corpus_scene(C, techs, sinks, stock, open)
  return { data = data(C), state = { techs = techs }, stock = stock or { ["electronic-circuit"] = 3000 }, workers = 30, idle = 10,
    can_grow = true, traits = {}, weights = {}, open = open or {},
    deposits = { { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true, dist = 60 },
      { id = "s2", resource = "iron-ore", tiles = 270, amount = 1e6, dist = 150 },
      { id = "dc", resource = "copper-ore", tiles = 200, amount = 5e5, open = true, dist = 80 },
      { id = "dk", resource = "coal", tiles = 200, amount = 5e5, open = true, dist = 50 } },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 4, deposit = "d1" },
      { entity = "burner-mining-drill", resource = "copper-ore", n = 4, deposit = "dc" } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 6, where = "qg" },
      { entity = "stone-furnace", recipe = "copper-plate", n = 4, where = "dc" } },
    labs = { { entity = "lab", n = 8 } },
    research = { queue = { { tech = "electronics", left = 27, time = 15, packs = { { "automation-science-pack", 1 } } } }, rate = 450 },
    flows = { ["iron-ore"] = { made = 120 }, ["iron-plate"] = { made = 110 }, ["copper-plate"] = { made = 60 },
      ["iron-gear-wheel"] = { made = 20, hand = 20 } }, sinks = sinks }
end
local function new_base(C)
  return { data = data(C), state = { techs = { automation = true } }, stock = { ["electronic-circuit"] = 1000 }, workers = 30,
    idle = 10, can_grow = true, traits = {}, weights = {}, open = {}, labs = {}, machines = {},
    deposits = { { id = "fer", resource = "iron-ore", tiles = 600, amount = 1e6, open = true, dist = 60 },
      { id = "ch", resource = "coal", tiles = 300, amount = 5e5, open = true, dist = 50 } },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 4, deposit = "fer" } },
    flows = { ["iron-ore"] = { made = 120 } }, sinks = { { item = "iron-plate", rate = 100 } } }
end
local CORPUS = {
  { "munitions", function(C) return corpus_scene(C, { automation = true }, { { item = "firearm-magazine", rate = 20, elastic = true } }) end },
  { "engrenages et circuits", function(C) return corpus_scene(C, { automation = true }, { { item = "iron-gear-wheel", rate = 60 },
    { item = "electronic-circuit", rate = 40 } }) end },
  { "packs bleus et violets", function(C) return corpus_scene(C, ALL, { { item = "utility-science-pack", rate = 5 },
    { item = "production-science-pack", rate = 5 } }) end },
  { "packs verts, ordre ouvert", function(C) return corpus_scene(C, ALL, { { item = "logistic-science-pack", rate = 30 },
    { item = "inserter", rate = 20 } }, {}, { { key = "chaine:x", kind = "chaine", item = "inserter", n = 1, n_left = 1,
    missing = { { "iron-plate", 50 } }, work_left = 30 } }) end },
  { "fer sans stock", function(C) return corpus_scene(C, { automation = true }, { { item = "iron-plate", rate = 400 } }, {}) end },
  { "base neuve (charbon ajoute)", new_base },
}
-- Scène à cycle (Kovarex, recette choisie de l'uranium 235 et 238) : hors de l'A/B, contrôlée à part (§2).
local function kovarex(C)
  return corpus_scene(C, ALL, { { item = "uranium-fuel-cell", rate = 2 }, { item = "rocket-control-unit", rate = 2 } })
end

-- EFFONDREMENT : 12 fours de fer pour une seule foreuse (le minerai manque ; les plaques, comptées sur les fours, non), une chaîne
-- d'engrenages voulue. C'est le cas de la partie du DC 717152950 en 0.6.51 (fo-logs/2026-11-05_EFFONDREMENT), ramené à la décision.
local function eff(C, over)
  local inp = { data = data(C), state = { techs = { automation = true } }, stock = { ["electronic-circuit"] = 1000 }, workers = 30,
    idle = 10, can_grow = true, traits = {}, weights = {}, open = {}, labs = {},
    deposits = { { id = "fer", resource = "iron-ore", tiles = 600, amount = 1e6, open = true, dist = 60 } },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 1, deposit = "fer" } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 12, where = "qg" } },
    flows = { ["iron-ore"] = { made = 30 }, ["iron-plate"] = { made = 30 } }, sinks = { { item = "iron-gear-wheel", rate = 60 } } }
  for k, v in pairs(over or {}) do inp[k] = v end
  return inp
end

--- Une décision entière, interrupteurs posés le temps de l'appel. Rend res, les refus « rang » et « anti-répétition » du TOUR 1, J.
local function decide(C, inp, st, rang, porte)
  C.RANG, C.PORTE_RANG = rang, porte
  local ok, res, t1, J = pcall(function()
    local J0 = C.decide_begin(inp, st or {})
    C.decide_step(J0)
    local r1 = {}
    for _, k in ipairs(sk(J0.ctx.refus)) do
      local w = J0.ctx.refus[k].why
      if w:find("^rang :") or w:find("^anti%-repetition") then r1[k] = w end
    end
    while not C.decide_step(J0) do end
    return J0.res, r1, J0
  end)
  C.RANG, C.PORTE_RANG = false, false
  if not ok then error(res, 0) end
  return res, t1, J
end
---------------------------------------------------------------------------------------------------
-- Batterie (rejouée sur chaque mutant)
---------------------------------------------------------------------------------------------------
local function battery(C)
  local p0, f0 = pass, fail

  -- §0
  check(C.RANG == false, "§0 Ca.RANG eteint par defaut")

  -- §1 Éteint : aucun appel.
  local calls = 0
  local c0 = Rg.chain
  Rg.chain = function(...) calls = calls + 1 return c0(...) end
  local okspy, err = pcall(function()
    for _, s in ipairs(CORPUS) do C.decide(s[2](C), {}) end
    check(calls == 0, "§1 eteint : Rg.chain jamais appele (" .. calls .. ")")
    decide(C, eff(C), {}, true, false)
    check(calls >= 1, "§1 allume : la regle du rang est appelee")
  end)
  Rg.chain = c0
  check(okspy, "§1 sans erreur (" .. tostring(err) .. ")")

  -- §2 A/B de L1b sur le corpus, 3 décisions de suite (st porté).
  local same, acyclic, total = 0, 0, 0
  for _, s in ipairs(CORPUS) do
    local stA, stB = {}, {}
    for rep = 1, 3 do
      total = total + 1
      local a = C.decide(s[2](C), stA)
      local b, _, J = decide(C, s[2](C), stB, true, false)
      if #J.ctx.rang.cycles == 0 then
        acyclic = acyclic + 1
        if ser(a) == ser(b) and ser(stA) == ser(stB) then same = same + 1
        elseif not quiet then say("§2 difference : " .. s[1] .. ", decision " .. rep) end
      end
    end
  end
  check(acyclic == total and same == acyclic, string.format("§2 rang allume : decision entiere identique sur %d decisions sans cycle "
    .. "sur %d (%d identiques)", acyclic, total, same))
  local ko = C.decide(kovarex(C), {})
  local kn, _, Jk = decide(C, kovarex(C), {}, true, false)
  check(#Jk.ctx.rang.cycles >= 1, "§2 Kovarex : le cycle de l'uranium est vu")
  -- 2 piles/min : 0,2 fabrication de 10 piles, donc 0,2 uranium 235 et 3,8 uranium 238. Le 235 se fait par Kovarex (boucle sur
  -- lui-même : l'arc 235 -> 235 est l'amorce, non propagé) ; le 238 par le retraitement (hors du cycle) : l'arc Kovarex -> 238 est
  -- EXTERNE et se propage, 0,2 ÷ 41 fabrications × 5 = 1/41.
  local u5, u8 = kn.R["uranium-235"] or 0, kn.R["uranium-238"] or 0
  check(math.abs(u5 - 0.2) < 1e-12 and math.abs(u8 - (3.8 + 1 / 41)) < 1e-12, string.format(
    "§2 Kovarex allume : l'arc interne du cycle n'est pas propage, l'arc externe l'est (235 : %.6g, 238 : %.6g ; attendus 0,2 et "
    .. "3,8 + 1/41)", u5, u8))
  check((ko.R["uranium-235"] or 0) > 0.2 + 1e-9, "§2 Kovarex eteint : l'ancienne propagation ajoute l'arc interne (difference connue)")

  return pass - p0, fail - f0
end

local _, BASE = battery(Ca0)

---------------------------------------------------------------------------------------------------
-- §9 Coût en instructions (debug.sethook, compte d'instructions : déterministe)
---------------------------------------------------------------------------------------------------
local function cost(fn)
  local n = 0
  debug.sethook(function() n = n + 1 end, "", 1)
  fn()
  debug.sethook()
  return n
end
do
  local scenes = {}
  for _, s in ipairs(CORPUS) do scenes[#scenes + 1] = s end
  scenes[#scenes + 1] = { "effondrement", function(C) return eff(C) end }
  local rows, worst = {}, 0
  for _, s in ipairs(scenes) do
    local i1, i2 = s[2](Ca0), s[2](Ca0)
    local a = cost(function() Ca0.decide(i1, {}) end)
    local b = cost(function() decide(Ca0, i2, {}, true, false) end)
    rows[#rows + 1] = string.format("%s : eteint %d, rang %d (%+.1f %%)", s[1], a, b, 100 * (b - a) / a)
    if b / a > worst then worst = b / a end
  end
  for _, r in ipairs(rows) do say("§9 " .. r) end
  -- Borne écrite APRÈS la mesure (7/11 : le rang de -9,2 % à +5,2 %, pire cas la base neuve, où le rang est refait quand le charbon
  -- entre aux graines) : la décision au rang coûte au plus 1,10 fois l'éteinte. Les comptes varient de 0,1 % d'un lancement à l'autre
  -- (graine de hachage de Lua 5.2 : l'ordre d'entrée des tris de sorted_keys) ; les DÉCISIONS, non.
  check(worst <= 1.10, string.format("§9 decision au rang au plus 1,10 fois l'eteinte (pire : %.3f)", worst))
end

---------------------------------------------------------------------------------------------------
-- §10 Mutants (source de shared/ai3/capitalisation.lua)
---------------------------------------------------------------------------------------------------
local fh = assert(io.open("shared/ai3/capitalisation.lua", "rb"))
local SRC = fh:read("*a")
fh:close()
local function plain_count(s, sub)
  local n, i = 0, 1
  while true do
    local a, b = s:find(sub, i, true)
    if not a then return n end
    n, i = n + 1, b + 1
  end
end
local MUTANTS = {
  { "arc interne du cycle propage", "        if ci == nil or Rk.cyc[ing.name] ~= ci then", "        if true then" },
  { "rang jamais refait quand les graines changent", "  if Rk == nil or ctx.rang_key ~= key then", "  if Rk == nil then" },
  { "rang allume par defaut", "Ca.RANG = false ", "Ca.RANG = true " },
  { "propagation sans le stock", "    local net = (Rq[i] or 0) - (ctx.stock[i] or 0) / Ca.H_STOCK\n    if r and net > 0 then\n      local crafts = net / amount_of(r.products, i)\n      local ci",
    "    local net = (Rq[i] or 0)\n    if r and net > 0 then\n      local crafts = net / amount_of(r.products, i)\n      local ci" },
}
if BASE > 0 then
  print("[RANG-CABLAGE] mutants non juges : la batterie echoue sur le source livre")
else
  local killed = 0
  for _, m in ipairs(MUTANTS) do
    local n = plain_count(SRC, m[2])
    if n ~= 1 then
      check(false, "§10 mutant « " .. m[1] .. " » : extrait trouve " .. n .. " fois (attendu 1)")
    else
      local a = SRC:find(m[2], 1, true)
      local src = SRC:sub(1, a - 1) .. m[3] .. SRC:sub(a + #m[2])
      local chunk = assert(load(src, "=capitalisation(mutant)"))
      local Cm = chunk()
      local p1, f1 = pass, fail
      quiet = true
      local ok, err = pcall(battery, Cm)
      quiet = false
      local caught = (not ok) or fail > f1
      pass, fail = p1, f1
      check(caught, "§10 mutant « " .. m[1] .. " » detecte" .. (ok and "" or " (plantage : " .. tostring(err) .. ")"))
      if caught then killed = killed + 1 end
    end
  end
  say(string.format("§10 mutants : %d detectes sur %d", killed, #MUTANTS))
end

print(string.format("[RANG-CABLAGE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
