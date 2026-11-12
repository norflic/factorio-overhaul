--[[
  Lot DEFENSE-AP : banc HORS JEU de la garde d'un avant-poste dimensionnée sur la menace (shared/team/garde_ap.lua).
  Lancement, depuis la racine du mod : lua5.2 tests/garde_ap_test.lua

  Sections :
    1. la règle d'avant reste le plancher (menace nulle, inconnue ou plus petite) ;
    2. la menace RELÈVE la garde : vague prévue à 5 min, à 15 min, vague reçue ; le plus grand des trois compte ;
    3. cas mesurés (diag1, 9/11) : ap1 de fer, 16 foreuses, tourelle 574 PV : 294 PV -> base ; 1750 PV -> 4 ; 2457 PV -> 5 ;
    4. plafond Ga.CAP, jamais en dessous de la règle d'avant ;
    5. entrées dégradées (nil, négatif, NaN) ; constante de marge alignée sur la prévision ; déterminisme ; anti-échelle (aucun nom d'objet) ;
    6. mutants (règle modifiée par substitution du texte) : chacun fait échouer au moins un contrôle.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    print("  ECHEC : " .. msg)
  end
  return cond
end

local function load_module(src)
  local chunk, err = load(src, "=garde_ap", "t", _ENV)
  if not chunk then error(err) end
  return chunk()
end

local function read_all(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end

local SRC_REAL = read_all("shared/team/garde_ap.lua")
-- Le module livré a la garde d'avant-poste COUPÉE (Ga.CAP = 0). Les contrôles de la règle (sections 1 à 4, mutants) se jouent sur la même
-- source avec Ga.CAP = 6, la valeur essayée ; la section 0 dit explicitement que la garde livrée est coupée.
local SRC = SRC_REAL:gsub("Ga%.CAP = 0 ", "Ga.CAP = 6 ", 1)

-- Les contrôles, rejouables sur un module modifié (mutant) : rendent le nombre d'échecs.
local function run_checks(Ga, label, loud)
  local fails = 0
  local function ck(cond, msg)
    if not cond then
      fails = fails + 1
      if loud then check(false, label .. " : " .. msg) end
    elseif loud then
      check(true, msg)
    end
  end
  local TV = 574
  -- 1. plancher = règle d'avant
  ck(Ga.want({ base = 3, tv = TV }) == 3, "sans menace : la règle d'avant")
  ck(Ga.want({ base = 3, w5 = 0, w15 = 0, mem = 0, tv = TV }) == 3, "vague nulle : la règle d'avant")
  ck(Ga.want({ base = 3, w5 = 294, tv = TV }) == 3, "vague 294 PV (0,6 tourelle) : la règle d'avant")
  ck(Ga.want({ base = 3, w5 = 5000, tv = 0 }) == 3, "valeur de tourelle inconnue : la règle d'avant")
  ck(select(3, Ga.want({ base = 3, w5 = 294, tv = TV })) == "base", "raison base")
  -- 2. la menace relève
  ck(Ga.want({ base = 1, w5 = 1750, tv = TV }) == 4, "w5 seule relève (1750 -> 4)")
  ck(Ga.want({ base = 1, w15 = 1750, tv = TV }) == 4, "w15 seule relève")
  ck(Ga.want({ base = 1, mem = 1750, tv = TV }) == 4, "la vague reçue seule relève")
  ck(Ga.want({ base = 1, w5 = 600, w15 = 1750, mem = 900, tv = TV }) == 4, "le plus grand des trois compte (w15)")
  ck(Ga.want({ base = 1, w5 = 1750, w15 = 600, mem = 900, tv = TV }) == 4, "le plus grand des trois compte (w5)")
  ck(Ga.want({ base = 1, w5 = 600, w15 = 900, mem = 1750, tv = TV }) == 4, "le plus grand des trois compte (mem)")
  ck(select(3, Ga.want({ base = 1, w5 = 1750, tv = TV })) == "menace", "raison menace")
  ck(select(2, Ga.want({ base = 1, w5 = 600, w15 = 900, mem = 1750, tv = TV })) == 1750, "vague retenue rendue")
  -- 3. cas mesurés (diag1)
  ck(Ga.want({ base = 3, w5 = 294, w15 = 294, tv = TV }) == 3, "diag1 5 min : base")
  ck(Ga.want({ base = 3, w5 = 1750, w15 = 1750, tv = TV }) == 4, "diag1 10 min : 4 tourelles")
  ck(Ga.want({ base = 3, w5 = 2457, w15 = 2457, tv = TV }) == 5, "diag1 15 min : 5 tourelles")
  -- bord exact : 1,1 x vague = n tourelles pile -> n, pas n + 1
  ck(Ga.want({ base = 1, w5 = 1000 * 574 * 3 / 1100, tv = 574 }) == 3, "bord exact : 3 tourelles")
  ck(Ga.want({ base = 1, w5 = 1000 * 574 * 3 / 1100 + 1, tv = 574 }) == 4, "un PV de plus : 4 tourelles")
  -- 4. plafond
  ck(Ga.want({ base = 1, w5 = 100000, tv = TV }) == 6, "plafond de 6 tourelles")
  ck(select(3, Ga.want({ base = 1, w5 = 100000, tv = TV })) == "plafond", "raison plafond")
  ck(Ga.want({ base = Ga.CAP + 2, w5 = 100000, tv = TV }) == Ga.CAP + 2, "jamais sous la règle d'avant")
  ck(select(3, Ga.want({ base = Ga.CAP + 2, w5 = 100000, tv = TV })) == "base", "base au-dessus du plafond : raison base")
  ck(Ga.want({ base = Ga.CAP, w5 = 100000, tv = TV }) == Ga.CAP, "base = plafond")
  -- monotonie en la vague
  local last = 0
  local mono = true
  for w = 0, 6000, 50 do
    local n = Ga.want({ base = 2, w5 = w, tv = TV })
    if n < last then mono = false end
    last = n
  end
  ck(mono, "monotone en la vague")
  -- 5. entrées dégradées
  ck(Ga.want() == 0, "sans entrée : 0")
  ck(Ga.want({}) == 0, "table vide : 0")
  ck(Ga.want({ base = -4, w5 = -5, tv = TV }) == 0, "négatifs ignorés")
  ck(Ga.want({ base = 3, w5 = 0 / 0, tv = TV }) == 3, "NaN ignoré")
  ck(Ga.want({ base = "x", w5 = "y", tv = TV }) == 0, "chaînes ignorées")
  ck(Ga.want({ base = 2.9, tv = TV }) == 2, "base fractionnaire arrondie vers le bas")
  return fails
end

-- 0. Module livré : garde d'avant-poste COUPÉE
do
  local Real = load_module(SRC_REAL)
  print("[GARDE-AP] garde d'avant-poste : COUPEE dans le module livre (Ga.CAP = " .. tostring(Real.CAP) .. ")")
  check(Real.CAP == 0, "la garde d'avant-poste est COUPÉE dans le module livré (Ga.CAP = 0)")
  local n, w, why = Real.want({ base = 3, w5 = 100000, w15 = 100000, mem = 100000, tv = 574 })
  check(n == 3 and why == "base", "garde coupée : aucune menace ne relève la garde voulue d'un avant-poste (règle d'avant : 3)")
  check(Real.hq_want({ base = 4, have = 3, cap = 8, threat = 4575, min = 300, tv = 574, funds = 1365, cost = 120, reserve = 300 }) == 8,
    "la règle du QG, elle, reste allumée (4 575 PV, fer 1 365 : 8 tourelles)")
end

-- Module réel
local Ga = load_module(SRC)
local f0 = run_checks(Ga, "reel", true)
check(f0 == 0, "module réel : tous les contrôles")

-- Alignement sur la prévision (même marge)
do
  local Pc = require("shared.ai3.prevision_choix")
  check(Ga.MARGE == Pc.MARGE, "marge alignée sur Pc.MARGE")
  check(Ga.CAP >= Pc.PREP_TURRETS, "plafond au moins égal aux tourelles d'avance de la prévision")
end

-- Déterminisme
do
  local a = { Ga.want({ base = 2, w5 = 1234, w15 = 2345, mem = 345, tv = 574 }) }
  local b = { Ga.want({ base = 2, w5 = 1234, w15 = 2345, mem = 345, tv = 574 }) }
  check(a[1] == b[1] and a[2] == b[2] and a[3] == b[3], "mêmes entrées, mêmes sorties")
end

-- Anti-échelle : aucun nom d'objet ni de bâtiment du jeu, aucun pairs
do
  local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  for _, bad in ipairs({ "gun%-turret", "iron%-plate", "firearm", "copper", "stone", "pairs%(", "game%.", "math%.random" }) do
    check(not code:find(bad), "anti-échelle : pas de « " .. bad .. " »")
  end
end

-- Coût (palier 2 : instructions Lua comptées par debug.sethook, jamais l'horloge) : la règle d'un avant-poste, au pire cas
do
  local worst = 0
  for _, a in ipairs({ { base = 3, w5 = 0, w15 = 0, mem = 0, tv = 574 }, { base = 1, w5 = 100000, w15 = 100000, mem = 100000, tv = 574 },
    { base = 3, w5 = 2457, w15 = 2457, mem = 1500, tv = 574 }, {} }) do
    local n = 0
    debug.sethook(function() n = n + 1 end, "", 1)
    Ga.want(a)
    debug.sethook()
    if n > worst then worst = n end
  end
  print(string.format("[GARDE-AP] cout : Ga.want pire %d instructions par avant-poste (sethook, compte de 1)", worst))
  check(worst < 400, "coût d'un avant-poste sous 400 instructions (50 avant-postes : sous 20 000, très loin de 5 ms)")
end

-- 5 bis. Planificateur : l'avant-poste « défendu » à l'ancienne règle mais sous la garde de sa menace reçoit ses tourelles
do
  local T = require("shared.team.config")
  local Book = require("shared.team.book")
  local S = require("shared.team.scale")
  local Planner = require("shared.team.planner")
  local IRON, COPPER = T.outposts.iron.product, T.outposts.copper.product
  local book = Book.new(dofile("tests/fixtures/recipes.lua"))
  local function view(outposts, stock)
    local v = {
      tech = 0, personality = "balanced", done = { coal = true, iron = true, copper = true, stone = true, defense = true },
      deferred = {}, stock = stock, incoming = {}, outposts = outposts, pending = {}, sites = { iron = 1 }, smelters = 2,
      smelters_pending = 0, smelter_task = false, smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0,
      turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 8, workers_max = 30, workers_idle = 0,
      threatened = false, open = {}, workers_wanted = 30, no_research = true, ladder = T.player_ladder,
      hq_turrets = T.defend_hq, defend_first = true,
    }
    v.recruit_cost = S.recruit_cost(v.workers)
    return v
  end
  local function op(id, kind, drills, turrets, want_t, protect)
    return { id = id, kind = kind, drills = drills, full = false, turrets = turrets, coal_needed = 0, fuel_low = false, output = 0,
      idle_ticks = 0, has_task = true, has_fortify = false, want_t = want_t, protect = protect or nil }
  end
  local function stock_of(iron)
    return { [IRON] = iron, [COPPER] = 1000, coal = 500, stone = 500, [T.turret_ammo] = 200, ["gun-turret"] = 6,
      ["burner-mining-drill"] = 20, ["stone-furnace"] = 20, ["iron-chest"] = 8 }
  end
  local function fortify_of(plan, id)
    for _, t in ipairs(plan.tasks) do if t.key == "fortify:" .. id then return t end end
  end
  local function count_turrets(t)
    for _, it in ipairs(t.items or {}) do if it[1] == "gun-turret" then return it[2] end end
    return 0
  end
  local function post_of(plan, id)
    for _, d in ipairs(plan.defend and plan.defend.posts or {}) do if d.id == id then return d end end
  end
  local function facts(PlannerX)
    local f = {}
    -- fer 16 foreuses : la règle d'avant veut 3 tourelles ; la menace en veut 5
    local base3 = { op(1, "coal", 4, 1, 1), op(2, "iron", 16, 3, 3), op(3, "copper", 3, 1, 1), op(4, "stone", 2, 1, 1) }
    local menace5 = { op(1, "coal", 4, 1, 1), op(2, "iron", 16, 3, 5), op(3, "copper", 3, 1, 1), op(4, "stone", 2, 1, 1) }
    local p0 = PlannerX.plan(view(base3, stock_of(3000)), book)
    local p1 = PlannerX.plan(view(menace5, stock_of(3000)), book)
    f.no_post_before = post_of(p0, 2) == nil and 1 or 0
    f.no_task_before = fortify_of(p0, 2) == nil and 1 or 0
    local d = post_of(p1, 2)
    f.post_want = d and d.want or -1
    f.post_have = d and d.have or -1
    local t = fortify_of(p1, 2)
    f.task_turrets = t and count_turrets(t) or -1
    -- une menace plus petite que la règle d'avant ne change rien
    local small = { op(1, "coal", 4, 1, 1), op(2, "iron", 16, 3, 3), op(3, "copper", 3, 1, 1), op(4, "stone", 2, 1, 1) }
    f.small_no_task = fortify_of(PlannerX.plan(view(small, stock_of(3000)), book), 2) == nil and 1 or 0
    -- avant-poste sans want_t (vue d'avant le lot) : la règle d'avant
    local legacy = { op(1, "coal", 4, 1, nil), op(2, "iron", 16, 3, nil), op(3, "copper", 3, 1, nil), op(4, "stone", 2, 1, nil) }
    f.legacy_no_task = fortify_of(PlannerX.plan(view(legacy, stock_of(3000)), book), 2) == nil and 1 or 0
    -- protection avant le premier coup : fer 200 (150 de plancher laissent 50, 60 de plancher laissent 140 : une tourelle et ses chargeurs, 120), aucune tourelle au stock
    local poor = stock_of(200)
    poor["gun-turret"], poor[T.turret_ammo] = 0, 0
    local prot = { op(1, "coal", 4, 1, 1), op(2, "iron", 16, 3, 5, true), op(3, "copper", 3, 1, 1), op(4, "stone", 2, 1, 1) }
    local noprot = { op(1, "coal", 4, 1, 1), op(2, "iron", 16, 3, 5, false), op(3, "copper", 3, 1, 1), op(4, "stone", 2, 1, 1) }
    local kp = PlannerX.plan(view(prot, poor), book)
    local kn = PlannerX.plan(view(noprot, poor), book)
    local function crafts(plan)
      for _, t in ipairs(plan.tasks) do if t.key == "craft:gun-turret:defense:1" then return 1 end end
      return 0
    end
    f.prot_craft, f.noprot_craft = crafts(kp), crafts(kn)
    return f
  end
  local F1 = facts(Planner)
  check(F1.no_post_before == 1 and F1.no_task_before == 1, "témoin : avant-poste à 3 tourelles sur 3 voulues (règle d'avant) : aucun poste")
  check(F1.post_want == 5 and F1.post_have == 3, "la garde voulue par la menace (5) ouvre un poste 3/5 même si la règle d'avant est servie")
  check(F1.task_turrets == 2, "la tâche de pose apporte l'écart (2 tourelles)")
  check(F1.small_no_task == 1 and F1.legacy_no_task == 1, "menace plus petite ou vue sans want_t : rien ne change")
  check(F1.prot_craft == 1 and F1.noprot_craft == 0, "protection avant le premier coup : plancher réduit, la tourelle se fabrique à 200 de fer ; sans elle, non")
  -- mutants du planificateur
  local psrc = read_all("shared/team/planner.lua")
  local pmut = {
    -- (CC-TOURELLES F489, 60b8e863 : la garde voulue est plafonnée par T.defend_outpost_max : repère suivi)
    { "poste sans la garde voulue", "local wt = math.min(T.defend_outpost_max, math.max(o.want_t or 0, T.defend_turrets(o.drills)))",
      "local wt = math.min(T.defend_outpost_max, T.defend_turrets(o.drills))" },
    { "poste jamais pour un avant-poste défendu", "if lacking[o.id] or (o.turrets or 0) < wt then", "if lacking[o.id] then" },
    { "protection sans la garde voulue", "(o.turrets or 0) < (o.want_t or T.defend_turrets(o.drills)) then protect_any = true end", "(o.turrets or 0) < T.defend_turrets(o.drills) then protect_any = true end" },
  }
  for _, m in ipairs(pmut) do
    local a, b = psrc:find(m[2], 1, true)
    if not a then check(false, "mutant planificateur « " .. m[1] .. " » : texte introuvable") else
      local src2 = psrc:sub(1, a - 1) .. m[3] .. psrc:sub(b + 1)
      local saved = package.loaded["shared.team.planner"]
      package.loaded["shared.team.planner"] = nil
      local chunk = assert(load(src2, "@shared.team.planner"))
      local okm, PlM = pcall(chunk)
      package.loaded["shared.team.planner"] = saved
      local dead = false
      if not okm then dead = true else
        local okf, FM = pcall(facts, PlM)
        if not okf then dead = true else
          dead = not (FM.no_post_before == F1.no_post_before and FM.post_want == F1.post_want and FM.task_turrets == F1.task_turrets
            and FM.small_no_task == F1.small_no_task and FM.legacy_no_task == F1.legacy_no_task and FM.prot_craft == F1.prot_craft
            and FM.noprot_craft == F1.noprot_craft)
        end
      end
      check(dead, "mutant planificateur « " .. m[1] .. " » refusé")
    end
  end
end

-- 5 ter. QG : assurance quand le fer le paie (Ga.hq_want), cas mesurés de long432-b2f727e4 (50 min : vague 4 575 PV, fer 1 365)
do
  local function hq_facts(Gx)
    local f = {}
    local function w(over)
      local a = { base = 4, have = 3, cap = 8, threat = 4575, min = 300, tv = 574, funds = 1365, cost = 120, reserve = 300 }
      for k, x in pairs(over or {}) do a[k] = x end
      return Gx.hq_want(a)
    end
    f.rich, f.rich_why = w()
    f.mid, f.mid_why = w({ funds = 568 })
    f.poor, f.poor_why = w({ funds = 100 })
    f.small, f.small_why = w({ threat = 200 })
    f.five, f.five_why = w({ threat = 1500 })
    f.below_min = w({ threat = 3000, min = 3500 })
    f.notv = w({ tv = 0 })
    f.nocap = w({ cap = 4 })
    f.nocost = w({ cost = 0 })
    f.nothreat = w({ threat = 0 })
    f.have_hi = w({ have = 6, funds = 400 })
    f.edge = w({ funds = 300 + 120 * 1, have = 4 })
    f.empty = Gx.hq_want()
    return f
  end
  local H0 = hq_facts(Ga)
  check(H0.rich == 8 and H0.rich_why == "plafond", "50 min (vague 4 575 PV, fer 1 365, 3 tourelles) : le QG en veut 8 (plafond), pas 5")
  check(H0.mid == 6 and H0.mid_why == "fer", "fer 568 : borné par le fer au-dessus de la réserve (2 tourelles de plus : 6)")
  check(H0.poor == 4 and H0.poor_why == "base" and H0.small == 4 and H0.small_why == "base", "fer insuffisant ou vague sous le seuil : la règle d'avant (4)")
  check(H0.below_min == 4, "vague sous le seuil de menace du lot : la règle d'avant")
  check(H0.five == 6 and H0.five_why == "menace", "menace 1 500 PV : 6 tourelles (vise 2 x la vague)")
  check(H0.notv == 4 and H0.nocap == 4 and H0.nocost == 4 and H0.nothreat == 4 and H0.empty == 4 - 4, "entrées inconnues : la règle d'avant (tv 0, plafond atteint, coût inconnu, aucune vague)")
  check(H0.have_hi == 6 and H0.edge == 5, "déjà 6 posées avec 400 de fer : 6 ; 420 de fer et 4 posées : 5 (une de plus payée)")
  local gsrc = read_all("shared/team/garde_ap.lua")
  local hm = {
    { "menace complète non bornée par le fer", "if want > payable then want, why = payable, \"fer\" end", "" },
    { "plafond ignoré", "if want > cap then want, why = cap, \"plafond\" end", "" },
    { "réserve oubliée", "math.max(0, num(a.funds) - num(a.reserve))", "num(a.funds)" },
    { "vague sous le seuil prise en compte", "or threat < num(a.min) or", "or" },
    { "arrondi bas", "local need = math.ceil(threat * Ga.HQ_MARGE / 1000 / tv - 1e-9)", "local need = math.floor(threat * Ga.HQ_MARGE / 1000 / tv)" },
    { "tourelles déjà posées ignorées", "local payable = math.max(have, base) + pay", "local payable = base + pay" },
    { "coût nul = gratuit", "local pay = cost > 0 and math.floor(math.max(0, num(a.funds) - num(a.reserve)) / cost) or 0", "local pay = cost > 0 and math.floor(math.max(0, num(a.funds) - num(a.reserve)) / cost) or 99" },
  }
  for _, m in ipairs(hm) do
    local a, b = gsrc:find(m[2], 1, true)
    if not a then check(false, "mutant QG « " .. m[1] .. " » : texte introuvable") else
      local ok, GM = pcall(load_module, gsrc:sub(1, a - 1) .. m[3] .. gsrc:sub(b + 1))
      local dead = not ok
      if ok then
        local okf, FM = pcall(hq_facts, GM)
        if not okf then dead = true else
          for k, v in pairs(H0) do if FM[k] ~= v then dead = true end end
        end
      end
      check(dead, "mutant QG « " .. m[1] .. " » refusé")
    end
  end
end

-- 5 quater. Fonds de défense : le fer d'une tourelle d'avant-poste de fer sans défense est mis de côté (Ga.fund, planificateur, C.consumed)
do
  local T = require("shared.team.config")
  local Book = require("shared.team.book")
  local S = require("shared.team.scale")
  local Planner = require("shared.team.planner")
  local IRON, COPPER = T.outposts.iron.product, T.outposts.copper.product
  local book = Book.new(dofile("tests/fixtures/recipes.lua"))
  local function view(outposts, stock, over)
    local v = {
      tech = 0, personality = "balanced", done = { coal = true, iron = true, copper = true, stone = true, defense = true },
      deferred = {}, stock = stock, incoming = {}, outposts = outposts, pending = {}, sites = { iron = 1 }, smelters = 2,
      smelters_pending = 0, smelter_task = false, smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0,
      turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 8, workers_max = 30, workers_idle = 0,
      threatened = false, open = {}, workers_wanted = 30, no_research = true, ladder = T.player_ladder,
      hq_turrets = T.defend_hq, defend_first = true,
    }
    v.recruit_cost = S.recruit_cost(v.workers)
    for k, x in pairs(over or {}) do v[k] = x end
    return v
  end
  local function op(id, kind, drills, turrets)
    return { id = id, kind = kind, drills = drills, full = false, turrets = turrets, coal_needed = 0, fuel_low = false, output = 0,
      idle_ticks = 0, has_task = true, has_fortify = false }
  end
  local function stock_of(iron)
    return { [IRON] = iron, [COPPER] = 1000, coal = 500, stone = 500, [T.turret_ammo] = 200,
      ["burner-mining-drill"] = 20, ["stone-furnace"] = 20, ["iron-chest"] = 8 }
  end
  local function has_craft(plan)
    for _, t in ipairs(plan.tasks) do if t.key == "craft:gun-turret:defense:1" then return 1 end end
    return 0
  end
  local function fund_facts(Pl, GaX)
    local f = {}
    local zero = { op(1, "coal", 4, 1), op(2, "iron", 16, 0), op(3, "copper", 3, 1), op(4, "stone", 2, 1) }
    local one = { op(1, "coal", 4, 1), op(2, "iron", 16, 1), op(3, "copper", 3, 1), op(4, "stone", 2, 1) }
    local p20 = Pl.plan(view(zero, stock_of(20)), book)
    f.hold20 = p20.defense_hold and p20.defense_hold[IRON] or 0
    local p80 = Pl.plan(view(zero, stock_of(80)), book)
    f.hold80 = p80.defense_hold and p80.defense_hold[IRON] or 0
    local p1000 = Pl.plan(view(zero, stock_of(1000)), book)
    f.hold_rich = p1000.defense_hold and p1000.defense_hold[IRON] or 0
    f.craft_zero_200 = has_craft(Pl.plan(view(zero, stock_of(200)), book))
    f.craft_one_200 = has_craft(Pl.plan(view(one, stock_of(200)), book))
    local p1 = Pl.plan(view(one, stock_of(20)), book)
    f.hold_one = p1.defense_hold and p1.defense_hold[IRON] or 0
    local pf = Pl.plan(view(zero, stock_of(20), { survie = true }), book)
    f.hold_survie = pf.defense_hold and pf.defense_hold[IRON] or 0
    f.pure_on = GaX.fund({ critical = GaX.critical(true, 0, 3), avail = 50, cost = 120 })
    f.pure_cap = GaX.fund({ critical = GaX.critical(true, 0, 3), avail = 500, cost = 120 })
    f.pure_have = GaX.fund({ critical = GaX.critical(true, 1, 3), avail = 50, cost = 120 })
    f.pure_notiron = GaX.fund({ critical = GaX.critical(false, 0, 3), avail = 50, cost = 120 })
    f.pure_pf = GaX.fund({ critical = true, production_first = true, avail = 50, cost = 120 })
    f.pure_nowant = GaX.fund({ critical = GaX.critical(true, 0, 0), avail = 50, cost = 120 })
    return f
  end
  local U0 = fund_facts(Planner, Ga)
  check(U0.hold20 == 20 and U0.hold80 == 80, "avant-poste de fer à 0 tourelle, fer 20 ou 80 : tout le fer libre est mis de côté (20, 80)")
  check(U0.hold_rich == 0 and U0.craft_zero_200 == 1, "fer 1 000 : rien à mettre de côté ; fer 200 (plancher 150 baissé à 60) : la tourelle se fabrique")
  check(U0.hold_one == 0 and U0.craft_one_200 == 0, "avant-poste de fer à 1 tourelle (3 voulues) : ni fonds ni plancher baissé (règle d'avant)")
  check(U0.pure_on == 50 and U0.pure_cap == 120 and U0.pure_have == 0 and U0.pure_notiron == 0 and U0.pure_pf == 0 and U0.pure_nowant == 0,
    "règle pure : min(fer libre, coût) pour un poste de fer sans tourelle ; rien s'il en a, hors fer, en production d'abord, sans tourelle voulue")
  -- C.consumed lit le fonds
  local C = require("shared.ai3.cerveau")
  local used = C.consumed({ tasks = {}, defense_hold = { [IRON] = 30 } }, view({}, stock_of(100)))
  check(used[IRON] == 30, "le cerveau compte le fonds comme consommé (fer 30 retiré aux projets)")
  local pmut = {
    { "fonds oublié", "if fund_hold > 0 then out.defense_hold", "if false then out.defense_hold" },
    { "plancher non baissé", "if crit then fi_p, fc_p = math.min(fl_i, Sq.FLOOR_IRON), math.min(fl_c, Sq.FLOOR_COPPER) end", "" },
    { "fonds pour tout avant-poste", "local crit = Ga.critical(p.iron, p.have, p.want)", "local crit = true" },
  }
  local psrc = read_all("shared/team/planner.lua")
  for _, m in ipairs(pmut) do
    local a, b = psrc:find(m[2], 1, true)
    if not a then check(false, "mutant fonds « " .. m[1] .. " » : texte introuvable") else
      local saved = package.loaded["shared.team.planner"]
      package.loaded["shared.team.planner"] = nil
      local okm, PlM = pcall(function() return assert(load(psrc:sub(1, a - 1) .. m[3] .. psrc:sub(b + 1), "@shared.team.planner"))() end)
      package.loaded["shared.team.planner"] = saved
      local dead = not okm
      if okm then
        local okf, FM = pcall(fund_facts, PlM, Ga)
        dead = (not okf)
        if okf then for k, v in pairs(U0) do if FM[k] ~= v then dead = true end end end
      end
      check(dead, "mutant fonds « " .. m[1] .. " » refusé")
    end
  end
  local gm = {
    { "fonds au-delà du coût", "return math.floor(math.min(num(a.avail), num(a.cost)))", "return math.floor(num(a.avail))" },
    { "fonds en production d'abord", "if not a.critical or a.production_first then return 0 end", "if not a.critical then return 0 end" },
    { "poste avec tourelle critique", "return Ga.FUND_ON and iron == true and num(have) <= 0 and num(want) > 0", "return Ga.FUND_ON and iron == true and num(want) > 0" },
    { "poste hors fer critique", "return Ga.FUND_ON and iron == true and num(have) <= 0 and num(want) > 0", "return Ga.FUND_ON and num(have) <= 0 and num(want) > 0" },
  }
  local gsrc2 = read_all("shared/team/garde_ap.lua")
  for _, m in ipairs(gm) do
    local a, b = gsrc2:find(m[2], 1, true)
    if not a then check(false, "mutant fonds pur « " .. m[1] .. " » : texte introuvable") else
      local ok, GM = pcall(load_module, gsrc2:sub(1, a - 1) .. m[3] .. gsrc2:sub(b + 1))
      local dead = not ok
      if ok then
        local okf, FM = pcall(fund_facts, Planner, GM)
        dead = not okf
        if okf then for k, v in pairs(U0) do if FM[k] ~= v then dead = true end end end
      end
      check(dead, "mutant fonds pur « " .. m[1] .. " » refusé")
    end
  end
end

-- 6. Mutants
local mutants = {
  { "marge à 1000", "Ga.MARGE = 1100", "Ga.MARGE = 1000" },
  { "marge à 1200", "Ga.MARGE = 1100", "Ga.MARGE = 1200" },
  { "plafond à 2", "Ga.CAP = 6", "Ga.CAP = 2" },
  { "plafond à 9", "Ga.CAP = 6", "Ga.CAP = 9" },
  { "w5 seul (w15 et mem ignorées)", "math.max(num(a.w5), num(a.w15), num(a.mem))", "num(a.w5)" },
  { "mem ignorée", "math.max(num(a.w5), num(a.w15), num(a.mem))", "math.max(num(a.w5), num(a.w15))" },
  { "w15 ignorée", "math.max(num(a.w5), num(a.w15), num(a.mem))", "math.max(num(a.w5), num(a.mem))" },
  { "plus petit au lieu du plus grand", "math.max(num(a.w5), num(a.w15), num(a.mem))", "math.min(num(a.w5), num(a.w15), num(a.mem))" },
  { "arrondi bas au lieu de haut", "math.ceil(w * Ga.MARGE / 1000 / tv - 1e-9)", "math.floor(w * Ga.MARGE / 1000 / tv)" },
  { "arrondi haut sans tolérance", "math.ceil(w * Ga.MARGE / 1000 / tv - 1e-9)", "math.ceil(w * Ga.MARGE / 1000 / tv + 1e-9)" },
  { "sous la règle d'avant", "if need <= base then return base, w, \"base\" end", "if need <= 0 then return base, w, \"base\" end" },
  { "plafond ignoré", "if need > Ga.CAP then", "if false then" },
  { "plafond sous la base", "if Ga.CAP <= base then return base, w, \"base\" end", "" },
  { "raison menace -> base", "return need, w, \"menace\"", "return need, w, \"base\"" },
  { "valeur de tourelle nulle acceptée", "if tv <= 0 or w <= 0 then", "if w <= 0 then" },
  { "base non arrondie", "local base = math.floor(num(a.base))", "local base = num(a.base)" },
  { "négatifs acceptés", "if type(x) ~= \"number\" or x ~= x or x < 0 then return 0 end", "if type(x) ~= \"number\" then return 0 end" },
  { "NaN accepté", "if type(x) ~= \"number\" or x ~= x or x < 0 then return 0 end", "if type(x) ~= \"number\" or x < 0 then return 0 end" },
}
local killed = 0
for _, m in ipairs(mutants) do
  local s, e = SRC:find(m[2], 1, true)
  if not s then
    check(false, "mutant « " .. m[1] .. " » : texte à remplacer introuvable")
  else
    local mutated = SRC:sub(1, s - 1) .. m[3] .. SRC:sub(e + 1)
    local ok, M = pcall(load_module, mutated)
    local dead = false
    if not ok then dead = true else
      local ok2, fails = pcall(run_checks, M, m[1], false)
      dead = (not ok2) or fails > 0
    end
    if dead then killed = killed + 1 end
    check(dead, "mutant « " .. m[1] .. " » refusé")
  end
end
print(string.format("[GARDE-AP] mutants refusés : %d / %d", killed, #mutants))
print(string.format("[GARDE-AP] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
