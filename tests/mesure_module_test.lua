--[[
  Lot MESURE-MODULE (8/11/2026) : banc HORS JEU de la mesure du débit d'un module fini.
  Lancement : lua5.2 tests/mesure_module_test.lua (depuis la racine du mod).

  Sections :
    1. règle pure (shared/ai3/mesure_module.lua) : première lecture sans mesure, débit stable, objets par fabrication, remplacement
       de machines par une montée de niveau (3 sur 4 au milieu d'une minute : débit INCHANGÉ), machine neuve bornée, machine
       absente, écart de minutes, compteur négatif, déterminisme, état sérialisable, recoupement avec les coffres ;
    2. runtime (script/ai3/automatisation.lua, measure_module et roll) sur un monde simulé minimal (surface à entités,
       Build.brief simulé) : mêmes cas par le vrai chemin du mod, plus le voisin qui TOUCHE la zone (F96), le four d'une autre
       recette, l'amorce (nil, jamais 0), la remise à nil de made_prev par le suivi de reconstruction, le journal d'écart ;
    3. mutants : chaque règle retirée fait échouer au moins un contrôle.
  Ce n'est pas une preuve en jeu.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
  return cond
end
local function section(name) if not quiet then print("== " .. name) end end
local function near(a, b, eps) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 0.011) end

local function read_file(p)
  local fh = assert(io.open(p, "rb")); local s = fh:read("*a"); fh:close(); return s
end
local function plain_replace(src, old, new)
  local i, j = src:find(old, 1, true)
  assert(i, "mutant : motif introuvable : " .. old)
  return src:sub(1, i - 1) .. new .. src:sub(j + 1)
end
local function load_chunk(src, name)
  local fn, err = load(src, "=" .. name, "t", _G)
  assert(fn, err)
  return fn()
end

---------------------------------------------------------------------------------------------------
-- 1. Règle pure
---------------------------------------------------------------------------------------------------
local SRC_MM = read_file("shared/ai3/mesure_module.lua")
local function new_mm(mut) return mut and load_chunk(mut(SRC_MM), "mesure_module_mutant") or load_chunk(SRC_MM, "mesure_module") end

--- n machines (numéros first_id.. ) de `per_min` fabrications par minute, `pf0` fabrications au départ : lectures après `min` minutes.
local function reads(ids, pf, amount, cap)
  local out = {}
  for _, id in ipairs(ids) do out[#out + 1] = { id = id, pf = pf[id], amount = amount or 1, cap = cap } end
  return out
end

--- Les cas de la règle pure, rendus sous forme de table de résultats (pour jouer aussi les mutants).
local function pure_cases(Mm)
  local r = {}
  -- a. première lecture : pas de mesure (nil), jamais 0
  local st, rate, info = Mm.step(nil, reads({ 1, 2, 3, 4 }, { 0, 0, 0, 0 }), 10)
  r.first_nil = (rate == nil) and info.why == "premiere lecture"
  -- b. débit stable : 4 machines à 3 fabrications par minute = 12
  local pf = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
  local rates = {}
  for k = 1, 3 do
    for id = 1, 4 do pf[id] = pf[id] + 3 end
    st, rate = Mm.step(st, reads({ 1, 2, 3, 4 }, pf), 10 + k)
    rates[k] = rate
  end
  r.stable = near(rates[1], 12) and near(rates[2], 12) and near(rates[3], 12)
  -- c. remplacement de 3 machines sur 4 au milieu de la minute (montée de niveau : nouveaux numéros, compteur à la moitié d'une
  -- minute de fabrication) : 4 machines à 6 fabrications par minute = 24, débit INCHANGÉ
  local base = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
  local s6 = select(1, Mm.step(nil, reads({ 1, 2, 3, 4 }, base), 0))
  local before
  for k = 1, 3 do
    for id = 1, 4 do base[id] = base[id] + 6 end
    s6, before = Mm.step(s6, reads({ 1, 2, 3, 4 }, base), k)
  end
  local after_pf = { [4] = base[4] + 6, [11] = 3, [12] = 3, [13] = 3 }
  local _, after, info2 = Mm.step(s6, reads({ 11, 12, 13, 4 }, after_pf), 4)
  r.replace_same = near(before, 24) and near(after, 24) and info2.new == 3 and info2.gone == 3
  -- d. machine NEUVE née depuis la dernière lecture : pf compte en entier ; machine ADOPTÉE déjà vieille : bornée par cap
  local sA = select(1, Mm.step(nil, reads({ 1 }, { [1] = 0 }), 0))
  local _, rN = Mm.step(sA, { { id = 1, pf = 6, amount = 1 }, { id = 2, pf = 4, amount = 1, cap = 10 } }, 1)
  r.new_counted = near(rN, 10)
  local _, rC, infoC = Mm.step(sA, { { id = 1, pf = 6, amount = 1 }, { id = 2, pf = 5000, amount = 1, cap = 12 } }, 1)
  r.new_capped = near(rC, 18) and infoC.capped == 1
  -- e. objets par fabrication (copper-cable : 2)
  local sB = select(1, Mm.step(nil, { { id = 1, pf = 100, amount = 2 } }, 0))
  local _, rB = Mm.step(sB, { { id = 1, pf = 105, amount = 2 } }, 1)
  r.amount = near(rB, 10)
  r.amount_of = Mm.amount_of({ { name = "copper-cable", amount = 2 } }, "copper-cable") == 2
    and Mm.amount_of({ { name = "x", amount_min = 1, amount_max = 3, probability = 0.5 } }, "x") == 1
    and Mm.amount_of({ { name = "x", amount = 1 } }, "y") == 0
  -- f. écart de minutes : une lecture sautée, le débit reste par minute
  local sG = select(1, Mm.step(nil, { { id = 1, pf = 0, amount = 1 } }, 0))
  local _, rG, infoG = Mm.step(sG, { { id = 1, pf = 30, amount = 1 } }, 3)
  r.gap = near(rG, 10) and infoG.gap == 3
  -- g. même minute : rien ne bouge
  local _, rS, infoS = Mm.step(sG, { { id = 1, pf = 99, amount = 1 } }, 0)
  r.same_min = rS == nil and infoS.why == "meme minute"
  -- h. aucune machine lue : mesure inconnue (nil) et l'état est gardé tel quel
  local sH, rH = Mm.step(sG, {}, 5)
  r.none_nil = rH == nil and sH == sG
  -- i. compteur qui baisse pour un même numéro : 0 pour cette machine, signalé, pas de négatif
  local sI = select(1, Mm.step(nil, { { id = 1, pf = 50, amount = 1 }, { id = 2, pf = 0, amount = 1 } }, 0))
  local _, rI, infoI = Mm.step(sI, { { id = 1, pf = 10, amount = 1 }, { id = 2, pf = 3, amount = 1 } }, 1)
  r.negative = near(rI, 3) and infoI.anomaly == 1
  -- j. machine disparue sans débit connu : 0 ; avec débit connu : la moitié
  local sJ = select(1, Mm.step(nil, { { id = 1, pf = 0, amount = 1 }, { id = 2, pf = 0, amount = 1 } }, 0))
  local sJ1, rJ1 = Mm.step(sJ, { { id = 1, pf = 4, amount = 1 }, { id = 2, pf = 4, amount = 1 } }, 1)
  local _, rJ2 = Mm.step(sJ1, { { id = 1, pf = 8, amount = 1 } }, 2)
  local sK = select(1, Mm.step(nil, { { id = 1, pf = 0, amount = 1 }, { id = 2, pf = 0, amount = 1 } }, 0))
  local _, rK = Mm.step(sK, { { id = 1, pf = 4, amount = 1 } }, 1)
  r.gone_half = near(rJ1, 8) and near(rJ2, 4 + 2) and near(rK, 4)
  -- k. déterminisme et état sérialisable
  local sD1 = select(1, Mm.step(nil, reads({ 3, 1, 2 }, { [1] = 0, [2] = 0, [3] = 0 }), 0))
  local sD2 = select(1, Mm.step(nil, reads({ 1, 2, 3 }, { [1] = 0, [2] = 0, [3] = 0 }), 0))
  local _, rD1 = Mm.step(sD1, reads({ 2, 3, 1 }, { [1] = 3, [2] = 5, [3] = 7 }), 1)
  local _, rD2 = Mm.step(sD2, reads({ 1, 2, 3 }, { [1] = 3, [2] = 5, [3] = 7 }), 1)
  r.determinism = rD1 == rD2 and near(rD1, 15)
  local function plain(v, depth)
    if depth > 6 then return false end
    local t = type(v)
    if t == "number" or t == "string" or t == "boolean" then return true end
    if t ~= "table" then return false end
    for k, x in pairs(v) do
      if not (type(k) == "number" or type(k) == "string") or not plain(x, depth + 1) then return false end
    end
    return true
  end
  r.plain = plain(sD1, 0) and plain(st, 0)
  -- l. données invalides ignorées (nombre non fini, produit nul)
  local sV = select(1, Mm.step(nil, { { id = 1, pf = 0, amount = 1 } }, 0))
  local _, rV = Mm.step(sV, { { id = 1, pf = 5, amount = 1 }, { id = 2, pf = 0 / 0, amount = 1 }, { id = 3, pf = 4, amount = 0 }, { id = "x", pf = 1, amount = 1 } }, 1)
  r.invalid = near(rV, 5)
  -- m. recoupement
  r.cross = Mm.crosscheck(12, 48) == "ecart" and Mm.crosscheck(12, 14) == nil and Mm.crosscheck(nil, 48) == nil
    and Mm.crosscheck(12, nil) == nil and Mm.crosscheck(12, 0) == nil and Mm.crosscheck(0, 1) == nil and Mm.crosscheck(0, 3) == "ecart"
  -- n. sentinelle de compatibilité
  r.sentinel = Mm.sentinel({ { id = 1, pf = 3, amount = 2 }, { id = 2, pf = 4, amount = 1 } }) == 10
  return r
end

local PURE_KEYS = { "first_nil", "stable", "replace_same", "new_counted", "new_capped", "amount", "amount_of", "gap", "same_min",
  "none_nil", "negative", "gone_half", "determinism", "plain", "invalid", "cross", "sentinel" }

section("1. regle pure")
local pure = pure_cases(new_mm())
for _, k in ipairs(PURE_KEYS) do check(pure[k] == true, "regle pure : " .. k) end

---------------------------------------------------------------------------------------------------
-- 2. Runtime : monde simulé minimal
---------------------------------------------------------------------------------------------------
local logs = {}
function log(s) logs[#logs + 1] = s end -- journal du moteur (global dans le jeu)
settings = { global = {} }
remote = { add_interface = function() end }

local function stub_modules(brief_of)
  local Pkg = package.loaded
  Pkg["script.faction.state"] = { sorted_keys = function(t)
      local ks = {}
      for k in pairs(t or {}) do ks[#ks + 1] = k end
      table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
      return ks
    end, war = function() return { started = 0 } end }
  Pkg["script.team.board"] = {}
  Pkg["script.team.build"] = { brief = brief_of }
  Pkg["script.team.harvest"] = {}
  Pkg["script.core.profiler"] = {}
  Pkg["script.team.migration_champ"] = {}
  Pkg["script.team.pile"] = {}
  Pkg["script.ai3.reserve"] = {}
  Pkg["script.team.intermediaires"] = {}
  Pkg["shared.ai3.mesure_module"] = nil
end

local SRC_AUTO = read_file("script/ai3/automatisation.lua")
local PROJECTS = {}
local function brief_of(f, id)
  local p = f and f.build and f.build.projects[id]
  if not p then return nil end
  return { state = "fini", parts = p.parts }
end
local function new_auto(mut_auto, mut_mm)
  stub_modules(brief_of)
  package.loaded["shared.ai3.mesure_module"] = new_mm(mut_mm)
  local src = mut_auto and mut_auto(SRC_AUTO) or SRC_AUTO
  return load_chunk(src, "automatisation")
end

local COPPER, GEAR = "copper-cable", "iron-gear-wheel"
local RECIPES = {
  ["automation-science-pack"] = { name = "automation-science-pack", energy = 5, products = { { name = "automation-science-pack", amount = 1 } } },
  [COPPER] = { name = COPPER, energy = 0.5, products = { { name = COPPER, amount = 2 } } },
  [GEAR] = { name = GEAR, energy = 0.5, products = { { name = GEAR, amount = 1 } } },
  ["iron-plate"] = { name = "iron-plate", energy = 3.2, products = { { name = "iron-plate", amount = 1 } } },
}

local function new_world()
  local W = { ents = {}, next_id = 100 }
  W.surface = {
    find_entities_filtered = function(args)
      local a = args.area
      local types = {}
      for _, t in ipairs(args.type or {}) do types[t] = true end
      local out = {}
      for _, e in ipairs(W.ents) do
        -- F96 : une entité qui TOUCHE la zone par un bord est rendue (intervalles fermés, boîte de l'entité)
        local h = e.half
        if e.valid and types[e.type] and e.force == args.force
          and e.position.x + h >= a[1][1] and e.position.x - h <= a[2][1]
          and e.position.y + h >= a[1][2] and e.position.y - h <= a[2][2] then
          out[#out + 1] = e
        end
      end
      return out
    end,
  }
  function W.add(kind, x, y, recipe, pf, extra)
    W.next_id = W.next_id + 1
    local e = { valid = true, unit_number = W.next_id, type = kind, position = { x = x, y = y }, half = 1.5, force = "player",
      products_finished = pf or 0, crafting_speed = 0.5, productivity_bonus = 0 }
    local r = recipe and RECIPES[recipe] or nil
    if kind == "assembling-machine" then e.get_recipe = function() return r end
    else
      e.get_recipe = function() return nil end
      e.previous_recipe = r
    end
    for k, v in pairs(extra or {}) do e[k] = v end
    W.ents[#W.ents + 1] = e
    return e
  end
  function W.remove(e) e.valid = false end
  return W
end

local function new_team(W, product)
  local f = { key = "player", force = "player", is_player = true, started = 0,
    hq = { valid = true, surface = W.surface, position = { x = 0, y = 0 } },
    build = { projects = { [7] = { parts = { { kind = "module", x = 0, y = 0, w = 12, h = 6 } } } } },
    team = {} }
  local m = { id = 7, product = product or "automation-science-pack", state = "fini" }
  return f, m
end

local function minute(k) return k * 3600 + 5 end

--- Joue `fn` avec le runtime normal ; rend les résultats du scénario du runtime sous forme de table.
local function runtime_cases(Auto)
  local r = {}
  -- a. 4 assembleurs de packs à 3/min (3 fabrications), premier relevé : pas de mesure
  local W = new_world()
  local f, m = new_team(W)
  local es = {}
  for i = 1, 4 do es[i] = W.add("assembling-machine", 1.5 + 3 * (i - 1), 1.5, "automation-science-pack", 0) end
  local first = Auto.measure_module(f, m, minute(10))
  r.first_nil = first == nil and m.made_prev == 0
  local rates = {}
  for k = 1, 3 do
    for _, e in ipairs(es) do e.products_finished = e.products_finished + 3 end
    rates[k] = Auto.measure_module(f, m, minute(10 + k))
  end
  r.stable = near(rates[1], 12) and near(rates[2], 12) and near(rates[3], 12)
  -- b. montée de niveau de 3 machines sur 4 au milieu de la minute : nouvelle entité (autre numéro), compteur à 3 (la moitié d'une
  -- minute à 6/min) ; l'agrandissement décale le centre d'une demi-tuile ; débit inchangé à 6/min par machine. Deux minutes à
  -- 6/min d'abord pour que le débit connu soit 6.
  local W2 = new_world()
  local f2, m2 = new_team(W2)
  local e2 = {}
  for i = 1, 4 do e2[i] = W2.add("assembling-machine", 1.5 + 3 * (i - 1), 1.5, "automation-science-pack", 0) end
  Auto.measure_module(f2, m2, minute(20))
  local last
  for k = 1, 2 do
    for _, e in ipairs(e2) do e.products_finished = e.products_finished + 6 end
    last = Auto.measure_module(f2, m2, minute(20 + k))
  end
  r.six = near(last, 24)
  for i = 1, 3 do
    W2.remove(e2[i])
    W2.add("assembling-machine", e2[i].position.x + 0.5, 2, "automation-science-pack", 3)
  end
  e2[4].products_finished = e2[4].products_finished + 6
  local after = Auto.measure_module(f2, m2, minute(23))
  r.replace_same = near(after, 24) and m2.meas_partial == true
  -- c. le rate_meas posé par la minute (roll) : un module fini dont rien n'est lu reste INCONNU (nil), pas 0
  local f3, m3 = new_team(new_world())
  f3.build.projects[7] = nil
  r.no_project_nil = Auto.measure_module(f3, m3, minute(30)) == nil
  local f3b, m3b = new_team(new_world())
  f3b.hq = { valid = false }
  r.no_surface_nil = Auto.measure_module(f3b, m3b, minute(30)) == nil
  -- d. aucune machine du produit dans la zone : nil (inconnu), pas 0
  local W4 = new_world()
  local f4, m4 = new_team(W4)
  r.empty_nil = Auto.measure_module(f4, m4, minute(31)) == nil
  -- e. le voisin qui TOUCHE la zone sans y avoir son centre n'est pas compté (F96) ; deux pièces qui se recouvrent : une seule fois
  local W5 = new_world()
  local f5, m5 = new_team(W5)
  f5.build.projects[7].parts = { { kind = "module", x = 0, y = 0, w = 12, h = 6 }, { kind = "module", x = 6, y = 0, w = 12, h = 6 } }
  local a5 = W5.add("assembling-machine", 8.5, 1.5, "automation-science-pack", 0)
  local nb = W5.add("assembling-machine", 19.5, 1.5, "automation-science-pack", 0) -- centre à 19,5 : zone 6..18, box 18..21 touche
  Auto.measure_module(f5, m5, minute(40))
  a5.products_finished, nb.products_finished = 6, 600
  r.neighbour = near(Auto.measure_module(f5, m5, minute(41)), 6)
  -- f. objets par fabrication : copper-cable (2) ; un four d'une autre recette n'est pas compté ; un four sans recette courante
  --    mais dont la recette précédente donne le produit l'est
  local W6 = new_world()
  local f6, m6 = new_team(W6, COPPER)
  local c6 = W6.add("assembling-machine", 1.5, 1.5, COPPER, 0)
  local fo6 = W6.add("furnace", 4.5, 1.5, "iron-plate", 0)
  local g6 = W6.add("assembling-machine", 7.5, 1.5, GEAR, 0)
  Auto.measure_module(f6, m6, minute(50))
  c6.products_finished, fo6.products_finished, g6.products_finished = 5, 40, 40
  r.amount_and_recipe = near(Auto.measure_module(f6, m6, minute(51)), 10)
  local W7 = new_world()
  local f7, m7 = new_team(W7, "iron-plate")
  local fu7 = W7.add("furnace", 1.5, 1.5, "iron-plate", 0)
  Auto.measure_module(f7, m7, minute(60))
  fu7.products_finished = 9
  r.furnace_prev = near(Auto.measure_module(f7, m7, minute(61)), 9)
  -- g. suivi de reconstruction : made_prev remis à nil -> nouvelle référence, pas de pic de toute la réparation
  local W8 = new_world()
  local f8, m8 = new_team(W8)
  local e8 = W8.add("assembling-machine", 1.5, 1.5, "automation-science-pack", 0)
  Auto.measure_module(f8, m8, minute(70))
  e8.products_finished = 6
  local ok1 = near(Auto.measure_module(f8, m8, minute(71)), 6)
  m8.made_prev = nil; m8.rate_meas = 0 -- ce que fait Sw.follow
  e8.products_finished = 600
  local nil_after = Auto.measure_module(f8, m8, minute(72))
  e8.products_finished = 603
  local back = Auto.measure_module(f8, m8, minute(73))
  r.follow_reset = ok1 and nil_after == nil and near(back, 3)
  -- h. machine adoptée vieille (numéro jamais vu, compteur énorme) : pas de pic (cap)
  local W9 = new_world()
  local f9, m9 = new_team(W9)
  local e9 = W9.add("assembling-machine", 1.5, 1.5, "automation-science-pack", 0)
  Auto.measure_module(f9, m9, minute(80))
  e9.products_finished = 6
  W9.add("assembling-machine", 4.5, 1.5, "automation-science-pack", 90000)
  local spike = Auto.measure_module(f9, m9, minute(81))
  r.adopted_capped = spike ~= nil and spike < 20
  -- i. état sérialisable : m.mm, m.made_prev, m.meas_n que des nombres, booléens et tables
  local function plain(v, d)
    if d > 6 then return false end
    local t = type(v)
    if t == "number" or t == "string" or t == "boolean" then return true end
    if t ~= "table" then return false end
    for k, x in pairs(v) do if not (type(k) == "number" or type(k) == "string") or not plain(x, d + 1) then return false end end
    return true
  end
  r.plain = plain(m2.mm, 0) and plain(m2.made_prev, 0) and type(m2.meas_n) == "number"
  return r
end

local RUNTIME_KEYS = { "first_nil", "stable", "six", "replace_same", "no_project_nil", "no_surface_nil", "empty_nil", "neighbour",
  "amount_and_recipe", "furnace_prev", "follow_reset", "adopted_capped", "plain" }

section("2. runtime (measure_module)")
local rt = runtime_cases(new_auto())
for _, k in ipairs(RUNTIME_KEYS) do check(rt[k] == true, "runtime : " .. k) end

-- La minute (roll) pose rate_meas, nil quand inconnu ; le journal de la minute dit « ? » ; recoupement avec les coffres.
local function roll_cases(Auto)
  local r = {}
  game = { tick = 0, forces = {}, recipe_prototypes = {} }
  local W = new_world()
  local f, m = new_team(W)
  f.team.delivered = {}
  local e = W.add("assembling-machine", 1.5, 1.5, "automation-science-pack", 0)
  local st = { mods = { m }, window = {}, last_delivered = {}, verdicts = {}, wanted = {}, hand = {}, logs = {} }
  Auto.roll(f, st, minute(100))
  r.roll_first_nil = m.rate_meas == nil and st.last_min == 100
  e.products_finished = 12
  -- coffres de sortie : 4 fois la production (cas du DC) -> une ligne d'écart
  f.team.mq = { tick = 100 * 3600, res = { out_all = { ["automation-science-pack"] = 324 } } }
  Auto.roll(f, st, minute(101))
  r.roll_rate = near(m.rate_meas, 12)
  f.team.mq = { tick = 101 * 3600, res = { out_all = { ["automation-science-pack"] = 324 } } }
  e.products_finished = 24
  Auto.roll(f, st, minute(102))
  f.team.mq = { tick = 102 * 3600, res = { out_all = { ["automation-science-pack"] = 372 } } }
  e.products_finished = 36
  logs = {}
  Auto.roll(f, st, minute(103))
  local n = 0
  for _, l in ipairs(logs) do if l:find("%[FO%-IA3E%-MESURE%]") and l:find("automation%-science%-pack") then n = n + 1 end end
  r.cross_log = n == 1
  -- l'écart dure à la minute suivante : pas de seconde ligne avant Auto.CHECK_EVERY (10 min)
  f.team.mq = { tick = 103 * 3600, res = { out_all = { ["automation-science-pack"] = 420 } } }
  e.products_finished = 48
  logs = {}
  Auto.roll(f, st, minute(104))
  n = 0
  for _, l in ipairs(logs) do if l:find("%[FO%-IA3E%-MESURE%]") then n = n + 1 end end
  r.cross_once = n == 0
  -- accord : pas de ligne
  f.team.mq = { tick = 104 * 3600, res = { out_all = { ["automation-science-pack"] = 432 } } }
  e.products_finished = 60
  logs = {}
  Auto.roll(f, st, minute(105))
  n = 0
  for _, l in ipairs(logs) do if l:find("%[FO%-IA3E%-MESURE%]") then n = n + 1 end end
  r.cross_quiet = n == 0
  -- la ligne de la minute écrit « ? » pour une mesure inconnue
  local m2 = { id = 8, product = "x", state = "fini", built = 1, total = 1 }
  local st2 = { mods = { m2 }, verdicts = {}, window = {}, wanted = {}, hand = {} }
  logs = {}
  Auto.minute_line(f, st2, minute(104))
  r.line_unknown = (logs[1] or ""):find("x#8:fini(1/1)=?/min", 1, true) ~= nil
  m2.rate_meas = 12.4
  logs = {}
  Auto.minute_line(f, st2, minute(104))
  r.line_known = (logs[1] or ""):find("x#8:fini(1/1)=12/min", 1, true) ~= nil
  return r
end
local ROLL_KEYS = { "roll_first_nil", "roll_rate", "cross_log", "cross_once", "cross_quiet", "line_unknown", "line_known" }

section("2b. runtime (roll, recoupement, ligne de la minute)")
local rl = roll_cases(new_auto())
for _, k in ipairs(ROLL_KEYS) do check(rl[k] == true, "roll : " .. k) end

---------------------------------------------------------------------------------------------------
-- 3. Mutants
---------------------------------------------------------------------------------------------------
section("3. mutants")
local mutants = {
  -- règle pure
  { "regle : premiere lecture rend 0", "mm", function(s) return plain_replace(s, 'info.why = "premiere lecture"\n    return { v = Mm.VERSION, min = now_min, per = per }, nil, info', 'info.why = "premiere lecture"\n    return { v = Mm.VERSION, min = now_min, per = per }, 0, info') end, { "first_nil" } },
  { "regle : disparue sans moitie", "mm", function(s) return plain_replace(s, "if rt and rt > 0 then total = total + 0.5 * rt end", "if rt and rt > 0 then total = total + 0 end") end, { "replace_same", "gone_half" } },
  { "regle : disparue comptee en entier", "mm", function(s) return plain_replace(s, "total = total + 0.5 * rt", "total = total + 1.0 * rt") end, { "replace_same", "gone_half" } },
  { "regle : machine neuve ignoree", "mm", function(s) return plain_replace(s, "total = total + made / gap\n      info.new", "total = total + 0\n      info.new") end, { "replace_same", "new_counted", "new_capped" } },
  { "regle : borne cap retiree", "mm", function(s) return plain_replace(s, "if r.cap and made > r.cap * gap then", "if false then") end, { "new_capped" } },
  { "regle : objets par fabrication ignores", "mm", function(s) return plain_replace(s, "local made = d * r.amount / gap", "local made = d / gap") end, { "amount" } },
  { "regle : ecart de minutes ignore", "mm", function(s) return plain_replace(s, "local made = d * r.amount / gap", "local made = d * r.amount") end, { "gap" } },
  { "regle : compteur negatif non borne", "mm", function(s) return plain_replace(s, "if d < 0 then d = 0; info.anomaly = (info.anomaly or 0) + 1 end", "") end, { "negative" } },
  { "regle : aucune machine lue rend 0", "mm", function(s) return plain_replace(s, 'info.why = "aucune machine lue"\n    return state, nil, info', 'info.why = "aucune machine lue"\n    return state, 0, info') end, { "none_nil" } },
  { "regle : meme minute recalculee", "mm", function(s) return plain_replace(s, "if gap < 1 then", "if gap < 0 then") end, { "same_min" } },
  { "regle : donnees invalides acceptees", "mm", function(s) return plain_replace(s, "if id and pf and pf >= 0 and am and am > 0 then", "if id then") end, { "invalid" } },
  { "regle : recoupement sans tolerance", "mm", function(s) return plain_replace(s, "if g > m * Mm.CHECK_RATIO + Mm.CHECK_SLACK then", "if g > m then") end, { "cross" } },
}
for _, mu in ipairs(mutants) do
  local ok, res = pcall(function() return pure_cases(new_mm(mu[3])) end)
  local caught = not ok -- un plantage compte comme détecté
  if ok then for _, k in ipairs(mu[4]) do if res[k] ~= true then caught = true end end end
  check(caught, "mutant non detecte : " .. mu[1])
end

local rt_mutants = {
  { "runtime : voisin qui touche compte (F96)", function(s) return plain_replace(s, "p.x >= pt.x and p.x <= pt.x + pt.w and p.y >= pt.y and p.y <= pt.y + pt.h", "true") end, { "neighbour" } },
  { "runtime : doublon de pieces compte deux fois", function(s) return plain_replace(s, "if p and not seen[id] and", "if p and") end, { "neighbour" } },
  { "runtime : tout four est compte", function(s) return plain_replace(s, "local amount = r and Mm.amount_of(r.products, m.product) or 0", "local amount = (r and Mm.amount_of(r.products, m.product) or 0); if e.type == 'furnace' then amount = 1 end") end, { "amount_and_recipe" } },
  { "runtime : recette precedente du four ignoree", function(s) return plain_replace(s, 'if not r and e.type == "furnace" then r = e.previous_recipe end', "") end, { "furnace_prev" } },
  { "runtime : amount ignore", function(s) return plain_replace(s, "local amount = r and Mm.amount_of(r.products, m.product) or 0", "local amount = r and 1 or 0") end, { "amount_and_recipe" } },
  { "runtime : made_prev nil ignore", function(s) return plain_replace(s, "if m.made_prev == nil then m.mm = nil end", "") end, { "follow_reset" } },
  { "runtime : projet absent rend 0", function(s) return plain_replace(s, "if not s then return nil end", "if not s then return 0 end") end, { "no_project_nil" } },
  { "runtime : cap des machines neuves retire", function(s) return plain_replace(s, "if not known[id] then", "if false then") end, { "adopted_capped" } },
  { "runtime : sentinelle jamais posee", function(s) return plain_replace(s, "if #readings > 0 then m.made_prev = Mm.sentinel(readings) end", "") end, { "first_nil" } },
}
for _, mu in ipairs(rt_mutants) do
  local ok, res = pcall(function() return runtime_cases(new_auto(mu[2])) end)
  local caught = not ok
  if ok then for _, k in ipairs(mu[3]) do if res[k] ~= true then caught = true end end end
  check(caught, "mutant non detecte : " .. mu[1])
end
local roll_mutants = {
  { "roll : mesure inconnue ecrite 0 dans la ligne", function(s) return plain_replace(s, '(m.rate_meas and string.format("=%.0f/min", m.rate_meas) or "=?/min")', 'string.format("=%.0f/min", m.rate_meas or 0)') end, { "line_unknown" } },
  { "roll : recoupement jamais appele", function(s) return plain_replace(s, "  crosscheck(f, st, tick)\n", "") end, { "cross_log" } },
  { "roll : ecart journalise a chaque minute", function(s) return plain_replace(s, "(cur.said[item] == nil or tick - cur.said[item] >= Auto.CHECK_EVERY)", "true") end, { "cross_once" } },
}
for _, mu in ipairs(roll_mutants) do
  local ok, res = pcall(function() return roll_cases(new_auto(mu[2])) end)
  local caught = not ok
  if ok then for _, k in ipairs(mu[3]) do if res[k] ~= true then caught = true end end end
  check(caught, "mutant non detecte : " .. mu[1])
end

print(string.format("[MESURE-MODULE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
