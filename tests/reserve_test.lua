--[[
  Lot INDUSTRIE I1 (RESERVE) : banc HORS JEU du besoin évalué (shared/ai3/reserve.lua), de son branchement dans la capitalisation
  (Ca.budget, Ca.decide, Ca.capi_view), dans le cerveau (C.think : f.team.ia3.noyau) et dans la réserve de fer de votre équipe
  (FE.reserve). Lancement, depuis la racine du mod : lua5.2 tests/reserve_test.lua
    1. recrues voulues (plancher, travail qui attend, frein, marge) ;
    2. le noyau : consommation prévue, défense (postes de croissance et facultatifs exceptés), reconstruction, recrues, « production
       d'abord » ;
    3. l'évaluation PAR MATIÈRE (le cuivre ne paie pas le fer), marge, noyau non couvert, stock non modifié, déterminisme ;
    4. le budget : le stock hors besoin s'investit en entier, sans s, sans pourcentage ; le flux garde sa règle ; sous menace la règle
       d'avant ; jamais plus que le stock d'aujourd'hui ; ordres plus gros qu'avec le pourcentage ;
    5. le cerveau écrit le besoin à chaque pensée (réglage allumé), rien sinon ; état sans fonction ;
    6. la réserve de fer de croissance de votre équipe tombe quand le besoin est couvert ;
    7. anti-échelle : reserve.lua ne nomme aucun objet du jeu ;
    8. mutants : chaque règle retirée fait échouer au moins un contrôle.
  Ce fichier est du TEST : il nomme les prototypes vanilla (comme le moteur) ; la règle n'en voit rien.
]]
package.path = "./?.lua;" .. package.path
local F = require("tests.iag_fixture")
local Book = require("shared.team.book")
local S = require("shared.team.scale")
local B = require("shared.ai3.buts")
local T = require("shared.team.config")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end

local IRON, COPPER, TURRET = "iron-plate", "copper-plate", "gun-turret"
local book = Book.new(dofile("tests/fixtures/recipes.lua"))

local function sorted_keys(t) local ks = {} for k in pairs(t or {}) do ks[#ks + 1] = k end table.sort(ks) return ks end
local function deep(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = deep(v) end
  return c
end

-- Les modules sous test : rechargés à neuf pour chaque batterie (les mutants remplacent un fichier).
local Rs, Ca, C, FE
local PATHS = { Rs = "shared/ai3/reserve.lua", Ca = "shared/ai3/capitalisation.lua", C = "shared/ai3/cerveau.lua",
  FE = "shared/team/fer_equipe.lua" }
local LOADED = { Rs = "shared.ai3.reserve", Ca = "shared.ai3.capitalisation" }
local function slurp(p) local f = assert(io.open(p, "rb")) local x = f:read("*a") f:close() return x end
local function load_source(path, mutate)
  local src = slurp(path)
  if mutate then
    local i, j = src:find(mutate[1], 1, true)
    if not i then return nil, "texte introuvable : " .. mutate[1] end
    src = src:sub(1, i - 1) .. mutate[2] .. src:sub(j + 1)
  end
  local fn, err = load(src, "@" .. path)
  if not fn then return nil, err end
  return fn()
end
--- Charge les 4 modules (le mutant remplace `which`) ; les dépendants voient le mutant par package.loaded.
local function build(which, mutate)
  local saved = { package.loaded[LOADED.Rs], package.loaded[LOADED.Ca] }
  local mods = {}
  local err
  for _, k in ipairs({ "Rs", "Ca", "C", "FE" }) do
    local m, e = load_source(PATHS[k], (k == which) and mutate or nil)
    if not m then err = e break end
    mods[k] = m
    if LOADED[k] then package.loaded[LOADED[k]] = m end
  end
  package.loaded[LOADED.Rs], package.loaded[LOADED.Ca] = saved[1], saved[2]
  return mods, err
end

-- Relevé vanilla réaliste (copié de tests/ai3_capitalisation_test.lua : vitesses, aires, puissances de data/base 1.1.91).
local V_SPEED = { ["stone-furnace"] = 1, ["steel-furnace"] = 2, ["electric-furnace"] = 2, ["assembling-machine-1"] = 0.5,
  ["assembling-machine-2"] = 0.75, ["assembling-machine-3"] = 1.25, ["burner-mining-drill"] = 0.25,
  ["electric-mining-drill"] = 0.5, ["pumpjack"] = 1, ["lab"] = 1, ["chemical-plant"] = 1, ["oil-refinery"] = 1,
  ["centrifuge"] = 1 }
local V_AREA = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 5, ["pumpjack"] = 1 }
local V_SIZE = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 3, ["stone-furnace"] = 2, ["steel-furnace"] = 2 }
local V_KW = { ["stone-furnace"] = 90, ["steel-furnace"] = 90, ["electric-furnace"] = 180, ["burner-mining-drill"] = 150,
  ["electric-mining-drill"] = 90, ["assembling-machine-1"] = 75, ["assembling-machine-2"] = 150,
  ["assembling-machine-3"] = 375, ["lab"] = 60, ["boiler"] = 1800 }
local V_MINE = { ["uranium-ore"] = 2 }

local function vanilla_dump(mut, fopts)
  local d = F.dump(fopts)
  for _, e in ipairs(d.entities) do
    if V_SPEED[e.name] then e.speed = V_SPEED[e.name] end
    e.mining_area = V_AREA[e.name]
    e.size = V_SIZE[e.name] or 3
    e.energy_kw = V_KW[e.name]
  end
  -- Recettes débloquées par une technologie : inactives au départ (comme dans le jeu).
  for _, t in ipairs(sorted_keys(d.techs)) do
    for _, r in ipairs(d.techs[t].unlocks) do if d.recipes[r] then d.recipes[r].enabled = false end end
  end
  for _, r in ipairs(d.resources) do r.mining_time = V_MINE[r.entity] or 1 end
  if mut then mut(d) end
  return d
end

-- Exécutants : ceux d'AUTO (foreuses électriques, assembleurs) et ceux de main aujourd'hui (four en pierre, foreuse à
-- combustion), plus la main et le laboratoire du QG.
local EXEC_AUTO = { ["stone-furnace"] = true, ["steel-furnace"] = true, ["burner-mining-drill"] = true,
  ["electric-mining-drill"] = true, ["assembling-machine-1"] = true, ["assembling-machine-2"] = true }
local EXEC_MAIN = { ["stone-furnace"] = true, ["burner-mining-drill"] = true }
local ROLES = { main = true, labo = true }
local function vdata(mut, exec, fopts)
  return Ca.data(vanilla_dump(mut, fopts), { exec = exec or EXEC_AUTO, exec_roles = ROLES })
end

-- Financement RÉALISTE des scènes : des pièces d'équipement au coffre (1 000 circuits, 3 425 MU), qui entrent dans les
-- recettes des foreuses, des assembleurs et des laboratoires. Plus de coffres en fer (ils ne deviennent jamais une
-- foreuse : un stock non convertible ne compte plus, §6). Les contrôles du budget lui-même partent d'un stock VIDE.
local PIECES = { ["electronic-circuit"] = 1000 }
local function pieces(extra)
  local s = deep(PIECES)
  for k, v in pairs(extra or {}) do s[k] = v end
  return s
end

--- Entrée de base (vanilla) : de l'assemblage recherché, RIEN au stock, des bras libres.
local function vin(D, over)
  local inp = { data = D, state = { techs = { automation = true } }, stock = {}, flows = {},
    machines = {}, drills = {}, labs = {}, deposits = {}, open = {}, sinks = {}, workers = 30, idle = 10,
    can_grow = true, traits = {}, weights = {} }
  for k, v in pairs(over or {}) do inp[k] = v end
  return inp
end

local function find(res, key)
  for i, o in ipairs(res.orders) do if o.key == key then return o, i end end
  return nil, nil
end
local function refus_of(res, key)
  for _, r in ipairs(res.refus) do if r.key == key then return r end end
  return nil
end
local function count_kind(res, kind)
  local n = 0
  for _, o in ipairs(res.orders) do if o.kind == kind then n = n + 1 end end
  return n
end
local function no_dup(res)
  local seen = {}
  for _, o in ipairs(res.orders) do
    if seen[o.key] then return false end
    seen[o.key] = true
  end
  return true
end
local function sum_cost(res)
  local c = 0
  for _, o in ipairs(res.orders) do c = c + o.cost_m end
  return c
end
local function explores(res, item)
  for _, e in ipairs(res.explore) do if e.resource == item then return e end end
  return nil
end

-- Gisement de fer (minerai livré au QG, fours du QG) et un site connu plus loin.
local function iron_scene(D, sink, over)
  local inp = vin(D, {
    stock = pieces(),
    deposits = { { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true, dist = 60 },
      { id = "s2", resource = "iron-ore", tiles = 270, amount = 1e6, dist = 150 } },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 2, deposit = "d1" } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 4, where = "qg" } },
    flows = { ["iron-ore"] = { made = 60 }, ["iron-plate"] = { made = 60 } },
    sinks = { { item = "iron-plate", rate = sink } } })
  for k, v in pairs(over or {}) do inp[k] = v end
  return inp
end


-- Vue du cerveau (copiée de tests/ai3_cerveau_test.lua) : votre équipe de 10 PNJ, pierre et charbon, un avant-poste de pierre.
local function view(over)
  local v = {
    tech = 0, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {}, outposts = {},
    pending = {}, sites = {}, smelters = 0, smelters_pending = 0, smelter_task = false, smelter_output = 0,
    smelter_fuel_low = false, smelter_coal = 0, turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 10,
    workers_max = 30, workers_idle = 10, threatened = false, open = {}, workers_wanted = 10, no_research = true,
    ladder = T.player_ladder, hq_turrets = T.defend_hq, defend_first = true, is_player = true,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function no_fn(t, seen)
  seen = seen or {}
  if seen[t] then return true end
  seen[t] = true
  for k, v in pairs(t) do
    if type(v) == "function" or type(k) == "function" then return false end
    if type(v) == "table" and not no_fn(v, seen) then return false end
  end
  return true
end
local function ctx_of(over)
  local c = { tick = 600, is_player = true, weights = B.weights({}, nil), reach = { ["iron-ore"] = 150, stone = 40, coal = 80 } }
  for k, x in pairs(over or {}) do c[k] = x end
  return c
end

--- La batterie de contrôles, jouée sur les modules `m` (les vrais ou un mutant). Rend le nombre d'échecs.
local function battery(m, verbose)
  local fails = 0
  local function ck(cond, msg)
    if not cond then
      fails = fails + 1
      if verbose then print("  ECHEC : " .. msg) end
    elseif verbose then
      passes = passes + 1
    end
  end
  Rs, Ca, C, FE = m.Rs, m.Ca, m.C, m.FE
  local D = Ca.data(vanilla_dump(), { exec = EXEC_AUTO, exec_roles = ROLES })

  -- 1. Recrues voulues ---------------------------------------------------------------------------------------------------------
  local cost = { { IRON, 30 }, { COPPER, 5 } }
  local n, list = Rs.recruits({ workers = 3, wanted = 30, floor = 8, cost = cost })
  ck(n == 5 and list[1][1] == COPPER and list[1][2] == 25 and list[2][1] == IRON and list[2][2] == 150,
    "1a. sous l'effectif de départ : toutes les recrues qui manquent (" .. n .. ")")
  n = Rs.recruits({ workers = 3, wanted = 30, floor = 8, blocked = true, cost = cost })
  ck(n == 0, "1b. plafond d'agents atteint : aucune recrue voulue")
  n, list = Rs.recruits({ workers = 10, wanted = 30, floor = 8, reason = "cout", cost = cost })
  ck(n == 1 and list[2][2] == 30, "1c. du travail attend, la recrue n'est pas payée (cout) : une recrue au besoin")
  n = Rs.recruits({ workers = 10, wanted = 30, floor = 8, reason = "inactifs", cost = cost })
  ck(n == 0, "1d. des bras libres (inactifs) : aucune recrue voulue")
  n = Rs.recruits({ workers = 30, wanted = 30, floor = 8, reason = "cout", cost = cost })
  ck(n == 0, "1e. effectif visé atteint : aucune recrue voulue")
  n = Rs.recruits({ workers = 10, wanted = 30, floor = 8, held = true, cost = cost })
  ck(n == 0, "1f. votre équipe, recrues retenues par le frein : aucune")
  n = Rs.recruits({ workers = 10, wanted = 30, floor = 8, held = false, cost = cost })
  ck(n == 1, "1g. votre équipe, rien ne retient : une recrue")
  n, list = Rs.recruits({ workers = 10, wanted = 30, floor = 8, reason = "rythme", cost = cost, margin = { IRON, 50 } })
  ck(n == 1 and list[2][2] == 80, "1h. la marge de la règle d'effectif entre au besoin (30 + 50 fer)")

  -- 2. Le noyau ----------------------------------------------------------------------------------------------------------------
  local posts = { { id = "hq", have = 0, want = 2, claim = { { TURRET, 2 } } }, { id = "front", have = 0, want = 3, claim = { { TURRET, 3 } } },
    { id = "ilot", have = 0, want = 1, claim = { { TURRET, 1 } } }, { id = "out1", have = 2, want = 2, claim = { { TURRET, 9 } } } }
  local core, parts = Rs.core({ posts = posts })
  ck(#core == 1 and core[1][1] == TURRET and core[1][2] == 2 and parts.defense == 2,
    "2a. défense : seul le poste sous son minimum (ni croissance front, ni facultatif ilot, ni poste plein)")
  core = Rs.core({ posts = posts, production_first = true })
  ck(#core == 0, "2b. production d'abord : la défense sort du noyau")
  core, parts = Rs.core({ repair = { { item = TURRET }, { item = TURRET }, { item = "pipe", claimed = true }, { item = "pipe", enemy = true } },
    plan_wants = { { "inserter", 3 } } })
  ck(#core == 2 and core[1][1] == TURRET and core[1][2] == 2 and core[2][1] == "inserter" and core[2][2] == 3 and parts.rebuild == 5,
    "2c. reconstruction : pièces sans tâche (ni prise, ni tenue par l'ennemi) + projet rouvert, liste triée")
  core = Rs.core({ planned = { [IRON] = 40, [COPPER] = 10 }, recruit = { { IRON, 30 } }, posts = posts })
  local sums = {}
  for _, it in ipairs(core) do sums[it[1]] = it[2] end
  ck(#core == 3 and sums[IRON] == 70 and sums[COPPER] == 10 and sums[TURRET] == 2, "2d. consommation prévue + recrues + défense : sommées par objet")

  -- 3. Évaluation par matière --------------------------------------------------------------------------------------------------
  local def = { { TURRET, 2 } } -- 80 fer + 20 cuivre ; avec la marge de 10 % : 3 tourelles (arrondi au-dessus), 120 fer + 30 cuivre
  local stock = { [IRON] = 500, [COPPER] = 100 }
  local ev = Rs.evaluate(book, stock, def)
  ck(ev.covered and ev.free[IRON] == 380 and ev.free[COPPER] == 70,
    "3a. 500 fer et 100 cuivre : libre 380 fer et 70 cuivre (" .. tostring(ev.free[IRON]) .. ", " .. tostring(ev.free[COPPER]) .. ")")
  ev = Rs.evaluate(book, { [IRON] = 30, [COPPER] = 49000 }, def)
  ck(not ev.covered and (ev.missing[IRON] or 0) > 0 and ev.free[COPPER] == 49000 - 30 and ev.free[IRON] == nil,
    "3b. 49 000 cuivre ne paient pas le fer : noyau non couvert, fer libre nul, cuivre libre")
  ev = Rs.evaluate(book, { [IRON] = 80, [COPPER] = 20 }, def)
  ck(not ev.covered, "3c. le stock exact ne couvre pas le noyau majoré de " .. Rs.MARGIN_PCT .. " %")
  ev = Rs.evaluate(book, stock, {})
  ck(ev.covered and ev.free[IRON] == 500 and ev.free[COPPER] == 100, "3d. aucun besoin : tout le stock est libre")
  local before = deep(stock)
  local e1, e2 = Rs.evaluate(book, stock, def), Rs.evaluate(book, stock, def)
  ck(stock[IRON] == before[IRON] and stock[COPPER] == before[COPPER], "3e. le stock donné n'est pas modifié")
  ck(e1.covered == e2.covered and e1.free[IRON] == e2.free[IRON] and e1.core[1][2] == e2.core[1][2], "3f. déterministe")
  ck(Rs.evaluate(nil, stock, def).covered == false, "3g. sans livre : jamais couvert (la règle d'avant s'applique)")
  local st = Rs.state(book, stock, { posts = { { id = "hq", have = 0, want = 2, claim = def } } }, 700)
  ck(st.tick == 700 and st.covered and st.parts.defense == 2 and no_fn(st), "3h. état : tick, parts, sans fonction")
  ck(Rs.covered(st, 700 + Rs.FRESH_TICKS) and not Rs.covered(st, 701 + Rs.FRESH_TICKS) and not Rs.covered(nil, 0),
    "3i. un besoin périmé n'est plus lu")
  ck(Rs.input(st, 900) and Rs.input(st, 900).free[IRON] == 380 and Rs.input(st, 700 + Rs.FRESH_TICKS + 1) == nil and Rs.input(nil, 0) == nil,
    "3j. entrée de la capitalisation : libre, ou nil si absent ou périmé")
  ck(Rs.describe(st):find("COUVERT", 1, true) and Rs.describe(nil):find("non evalue", 1, true), "3k. ligne de journal")
  local st_raw = Rs.state(book, stock, { raw_need = { [IRON] = { n = 25, prio = 40 } } }, 700)
  ck(not st_raw.covered and st_raw.missing[IRON] == 25 and st_raw.free[IRON] == 500 and not Rs.covered(st_raw, 700),
    "3k bis. le planificateur manque de fer : besoin NON couvert (la réserve de croissance reste), le stock libre ne change pas")

  -- Le recrutement n'est pas affamé : une recrue voulue (le coût n'est pas payé, « cout ») garde sa matière hors du stock libre.
  local n_r, rec_list = Rs.recruits({ workers = 10, wanted = 30, floor = 8, reason = "cout", cost = { { IRON, 150 } }, margin = { IRON, 30 } })
  local ev_r = Rs.state(book, { [IRON] = 200 }, { recruit = rec_list }, 0)
  ck(n_r == 1 and ev_r.covered and (ev_r.free[IRON] or 0) <= 2, "3l. 200 fer, recrue à 150 + marge 30 : la capitalisation ne voit que " .. tostring(ev_r.free[IRON] or 0) .. " fer libre")
  local ev_r2 = Rs.state(book, { [IRON] = 200 }, {}, 0)
  ck(ev_r2.free[IRON] == 200, "3m. sans recrue voulue : les 200 fer sont libres")

  -- 4. Le budget ---------------------------------------------------------------------------------------------------------------
  local lo = Ca.character({ ambition = 600, agressivite = 1400 }, nil, false)
  local hi = Ca.character({ ambition = 1600, agressivite = 400 }, nil, false)
  local b0 = Ca.budget(hi, 100, 1000, 1, 0)
  local b1, flux1, part1 = Ca.budget(hi, 100, 1000, 1, 0, true)
  local _, flux0 = Ca.budget(hi, 100, 1000, 1, 0)
  ck(math.abs(part1 - 1000) < 1e-9 and b1 > b0 and math.abs(flux1 - flux0) < 1e-9,
    "4a. avec le besoin évalué : tout le stock libre (1000 MU), le flux garde sa règle")
  local _, _, plo = Ca.budget(lo, 100, 1000, 1, 0, true)
  local _, _, phi = Ca.budget(hi, 100, 1000, 1, 0, true)
  local _, _, olo = Ca.budget(lo, 100, 1000, 1, 0)
  local _, _, ohi = Ca.budget(hi, 100, 1000, 1, 0)
  ck(plo == phi and olo ~= ohi, "4b. le caractère (s, δ, α) ne règle plus la part du stock (il règle encore l'ancienne)")

  local function scene(circ, over)
    local inp = iron_scene(D, 150, { stock = { ["electronic-circuit"] = circ } })
    inp.deposits[1].tiles = 1350
    for k, v in pairs(over or {}) do inp[k] = v end
    return inp
  end
  local r_old = Ca.decide(scene(100), {})
  local r_new = Ca.decide(scene(100, { reserve = { free = { ["electronic-circuit"] = 100 } } }), {})
  local o_old, o_new = find(r_old, "couvrir:d1"), find(r_new, "couvrir:d1")
  ck(o_old and o_new and o_new.n > o_old.n and r_new.reserve == true and r_old.reserve == nil,
    "4c. 100 circuits : le pourcentage paie " .. tostring(o_old and o_old.n) .. " foreuses, le stock hors besoin " .. tostring(o_new and o_new.n))
  ck(r_new.stock_part > 0 and math.abs(r_new.stock_part - r_new.free_mu) < 1e-9 and sum_cost(r_new) <= r_new.budget + 1e-6,
    "4d. part du stock = stock libre, dépense dans le budget")
  local r_zero = Ca.decide(scene(100, { reserve = { free = {} } }), {})
  local o_zero = find(r_zero, "couvrir:d1")
  ck(r_zero.stock_part == 0 and (o_zero == nil or o_zero.n < o_old.n), "4e. besoin qui prend tout le stock (libre nul) : le stock ne paie plus rien")
  local r_cap = Ca.decide(scene(100, { reserve = { free = { ["electronic-circuit"] = 1e9 } } }), {})
  ck(math.abs(r_cap.stock_part - r_new.stock_part) < 1e-9, "4f. jamais plus que le stock d'aujourd'hui")
  local r_thr = Ca.decide(scene(100, { threat = true, reserve = { free = { ["electronic-circuit"] = 100 } } }), {})
  local r_thr0 = Ca.decide(scene(100, { threat = true }), {})
  ck(r_thr.reserve == nil and math.abs(r_thr.stock_part - r_thr0.stock_part) < 1e-9, "4g. sous menace du QG : la règle d'avant, en entier")
  ck(Ca.text(r_new):find("reserve=[", 1, true) and not Ca.text(r_old):find("reserve=[", 1, true),
    "4h. journal : la ligne [FO-CAPI] dit quand le besoin est évalué")
  local avail = { [IRON] = 1000, [COPPER] = 400, coal = 50 }
  local v0 = Ca.capi_view(avail, { delta = 100, alpha = 150 })
  local v1 = Ca.capi_view(avail, { delta = 100, alpha = 150, free = { [IRON] = 700, [COPPER] = 9000 } })
  ck(v0[IRON] == 750 and v1[IRON] == 700 and v1[COPPER] == 400 and v1.coal == 37,
    "4i. projets de la capitalisation : stock hors besoin (jamais plus que le stock), sinon la part d'avant")
  local v2 = Ca.capi_view({ [IRON] = 1000 }, { delta = 100, alpha = 150, free = { [IRON] = 990 } })
  ck(v2[IRON] == 990, "4j. … même au-delà de la part (1000 - δ - α) d'avant")
  local v3 = Ca.capi_view(avail, { delta = 100, alpha = 150, free = { [COPPER] = 9000 }, zero = { [IRON] = true } })
  ck(v3[IRON] == 0 and v3[COPPER] == 400 and v3.coal == 37, "4k. matière que le besoin prend en entier : plus rien pour les projets (" .. tostring(v3[IRON]) .. ")")
  local ev_z = Rs.evaluate(book, { [IRON] = 30, [COPPER] = 49000 }, { { TURRET, 2 } })
  ck(ev_z.zero[IRON] == true and not ev_z.zero[COPPER] and Rs.input({ tick = 0, zero = ev_z.zero }, 0).zero[IRON] == true,
    "4l. le besoin non couvert marque le fer, pas le cuivre, et la capitalisation le lit")
  local ev_z2 = Rs.evaluate(book, { [IRON] = 120, [COPPER] = 100 }, { { TURRET, 2 } })
  ck(ev_z2.covered and ev_z2.zero[IRON] == true and ev_z2.free[IRON] == nil and not ev_z2.zero[COPPER], "4m. besoin couvert au plus juste : le fer est pris en entier, marqué aussi")

  -- 5. Le cerveau --------------------------------------------------------------------------------------------------------------
  local dc_stock = { stone = 600, coal = 800, ["firearm-magazine"] = 60, [IRON] = 1000, [COPPER] = 300 }
  local function dc_view(over)
    local v = view({ stock = dc_stock, outposts = { { id = 1, kind = "stone", drills = 2, full = false, turrets = 1, coal_needed = 0,
      fuel_low = false, output = 50, idle_ticks = 0, has_task = false, has_fortify = false } },
      sites = { coal = 1, iron = 1, copper = 0, stone = 1 }, done = { stone = true } })
    for k, x in pairs(over or {}) do v[k] = x end
    return v
  end
  local sA = C.new_state(0)
  C.think(dc_view(), book, sA, ctx_of({ industrie = true }))
  ck(sA.noyau ~= nil and sA.noyau.tick == 600 and sA.noyau.covered ~= nil and no_fn(sA.noyau),
    "5a. réglage allumé : le besoin est écrit à chaque pensée (sans fonction)")
  local sB = C.new_state(0)
  C.think(dc_view(), book, sB, ctx_of({}))
  ck(sB.noyau == nil, "5b. réglage éteint : rien n'est écrit (le jeu d'avant)")
  sB.noyau = { tick = 1 }
  C.think(dc_view(), book, sB, ctx_of({}))
  ck(sB.noyau == nil, "5c. réglage éteint en cours de partie : l'ancien besoin est effacé")
  local sC = C.new_state(0)
  C.think(dc_view({ workers_wanted = 30 }), book, sC, ctx_of({ industrie = true }))
  ck(sC.noyau.parts.recruit > 0 and sC.noyau.recruits == 1, "5d. votre équipe sous son effectif voulu : une recrue entre au besoin")
  local sD = C.new_state(0)
  C.think(dc_view({ workers_wanted = 30, is_player = false, effectif = { reason = "cout", margin = 50, margin_item = IRON }, recruit_held = true }),
    book, sD, ctx_of({ industrie = true }))
  ck(sD.noyau.recruits == 1, "5e. faction dont la règle d'effectif attend le coût (cout) : la recrue entre au besoin même retenue")
  local sE = C.new_state(0)
  C.think(dc_view({ workers_wanted = 30, is_player = false, effectif = { reason = "inactifs" } }), book, sE, ctx_of({ industrie = true }))
  ck(sE.noyau.recruits == 0, "5f. faction aux bras libres : aucune recrue au besoin")
  ck((sA.noyau.free[IRON] or 0) <= 1000 and (sA.noyau.free[COPPER] or 0) <= 300, "5g. le stock libre ne dépasse jamais le stock")
  local sb = C.new_state(0)
  C.think(dc_view(), book, sb, ctx_of({ industrie = true }))
  local sP0, sP1 = C.new_state(0), C.new_state(0)
  C.think(dc_view({ hq_turrets = 0 }), book, sP0, ctx_of({ industrie = true }))
  C.think(dc_view({ hq_turrets = 0, survie = true }), book, sP1, ctx_of({ industrie = true }))
  ck(sP0.noyau.parts.defense > 0 and sP1.noyau.parts.defense == 0,
    "5i. poste du QG sans tourelle : sa défense entre au besoin, sauf en production d'abord (mode survie)")
  local sR = C.new_state(0)
  C.think(dc_view({ hq_turrets = 0, survie = true, stock = { stone = 600, coal = 800, ["firearm-magazine"] = 60 } }), book, sR, ctx_of({ industrie = true }))
  ck(sR.noyau.parts.defense == 0 and (sR.noyau.missing[IRON] or 0) > 0 and not sR.noyau.covered,
    "5i bis. production d'abord sans fer : la défense sort du besoin, mais le manque brut du planificateur le laisse NON couvert")
  ck(sC.noyau.parts.planned > 0, "5j. ce que le planificateur consomme déjà (tâches, recrue décidée) entre au besoin")
  local function sigs(nn)
    local out = {}
    for _, k in ipairs(sorted_keys(nn.free)) do out[#out + 1] = k .. "=" .. nn.free[k] end
    return table.concat(out, ",") .. "|" .. tostring(nn.covered)
  end
  ck(sigs(sA.noyau) == sigs(sb.noyau), "5h. déterministe")

  -- 6. La réserve de fer de votre équipe ---------------------------------------------------------------------------------------
  ck(FE.reserve(400, true) == 400 and FE.reserve(400, true, false) == 400, "6a. besoin non évalué : la réserve de croissance d'avant")
  ck(FE.reserve(400, true, true) == nil, "6b. besoin évalué et couvert : plus de réserve de croissance")
  ck(FE.reserve(nil, true, true) == nil and FE.reserve(nil, true) == nil, "6c. sans réserve de base : aucune réserve")

  Rs, Ca, C, FE = nil, nil, nil, nil
  return fails
end

section("1 à 6. Règle pure, budget, cerveau, réserve de fer")
local real, err = build()
assert(real, err)
local f0 = battery(real, true)
check(f0 == 0, "batterie complète sur les vrais modules")

section("7. Anti-échelle : aucun objet du jeu dans reserve.lua")
local function code_only(src)
  src = src:gsub("%-%-%[%[.-%]%]", "")
  src = src:gsub("%-%-[^\n]*", "")
  return src
end
do
  local src = code_only(slurp("shared/ai3/reserve.lua"))
  local bad = nil
  for _, w in ipairs({ "iron", "copper", "coal", "stone", "turret", "inserter", "assembling", "transport", "belt", "pole", "firearm", "gear",
    "electric", "steel", "wood", "pipe", "magazine", "chest", "furnace", "drill" }) do
    if src:find(w, 1, true) then bad = w end
  end
  check(bad == nil, "shared/ai3/reserve.lua ne nomme aucun objet du jeu (" .. tostring(bad) .. ")")
  local bare = src:gsub("ipairs%(", "")
  check(not bare:find("pairs%("), "aucun `pairs` : toute itération passe par des listes triées")
end

section("8. Mutants")
local killed, total = 0, 0
local function mut(which, from, to, name)
  total = total + 1
  local mods, e = build(which, { from, to })
  if not mods then check(false, "mutant '" .. name .. "' : " .. tostring(e)) return end
  local ok, n = pcall(battery, mods, false)
  Rs, Ca, C, FE = nil, nil, nil, nil
  if check(not ok or n > 0, "mutant refusé : " .. name) then killed = killed + 1 end
end
mut("Rs", "Rs.MARGIN_PCT = 110", "Rs.MARGIN_PCT = 100", "marge de 10 % retirée")
mut("Rs", "if workers < floor then n = floor - workers", "if workers < floor then n = 1", "plancher : une seule recrue au besoin")
mut("Rs", "if Rs.RECRUIT_REASONS[v.reason] then n = 1 end", "n = 1", "toute raison d'effectif veut une recrue")
mut("Rs", "if v.blocked then return 0, {} end", "", "plafond d'agents ignoré")
mut("Rs", "if not inp.production_first then", "if true then", "production d'abord ignorée")
mut("Rs", "and not Pi.GROWTH_POSTS[p.id] and not Pi.OPTIONAL_POSTS[p.id] then", "then", "postes de croissance et facultatifs comptés")
mut("Rs", "if r.item and not r.claimed and not r.enemy then", "if r.item then", "pièces déjà prises ou tenues par l'ennemi comptées")
mut("Rs", "add(acc, inp.plan_wants)", "", "projet rouvert ignoré")
mut("Rs", "add(acc, planned)", "", "consommation prévue ignorée")
mut("Rs", "add(acc, inp.recruit)", "", "recrues ignorées")
mut("Rs", "out.covered = next(pl.raw) == nil", "out.covered = true", "noyau toujours réputé couvert")
mut("Rs", "if (pl.avail[k] or 0) > 0 then out.free[k] = pl.avail[k] end", "out.free[k] = (stock or {})[k]", "libre = tout le stock (besoin ignoré)")
mut("Rs", "tick - st.tick > Rs.FRESH_TICKS then return nil end", "false then return nil end", "besoin périmé encore lu")
mut("Rs", "and st.tick ~= nil and tick - st.tick <= Rs.FRESH_TICKS", "", "couverture périmée encore lue")
mut("Ca", "if reserve then stock_part = (free_mu or 0) * Ca.RESERVE_PCT / 100 end", "", "budget : pourcentage d'avant")
mut("Ca", "if reserve then stock_part = (free_mu or 0) * Ca.RESERVE_PCT / 100 end",
  "if reserve then stock_part = (free_mu or 0) * Ca.RESERVE_PCT / 200 end", "budget : la moitié du stock libre")
mut("Ca", "if res then have = math.min(have, (res.free or {})[k] or 0) end", "", "stock libre = tout le stock")
mut("Ca", "have = math.min(have, (res.free or {})[k] or 0)", "have = (res.free or {})[k] or 0", "libre pris sans borne du stock")
mut("Ca", "reserve = (not input.threat) and input.reserve or nil }", "reserve = input.reserve }", "réserve appliquée sous menace")
mut("Ca", "if free and free[k] ~= nil then out[k] = math.min(math.floor(avail[k] or 0), math.floor(free[k])) end", "",
  "projets : part d'avant")
mut("Ca", "math.min(math.floor(avail[k] or 0), math.floor(free[k]))", "math.floor(free[k])", "projets : libre sans borne")
mut("Ca", "if res.reserve then rp = rp", "if false then rp = rp", "journal muet")
mut("Ca", "if res and res.zero and res.zero[k] then out[k] = 0 end", "", "projets : part d'avant sur la matière que le besoin prend")
mut("Rs", "if (pl.avail[k] or 0) <= 0 then out.zero[k] = true end", "", "matière prise en entier non marquée")
mut("Rs", "      ev.covered = false\n", "", "manque brut du planificateur ignoré")
mut("C", "production_first = sig.production_first, raw_need = sig.raw_need }, tick)", "production_first = sig.production_first }, tick)", "manque brut non transmis")
mut("C", "if ctx.industrie then", "if false then", "besoin jamais évalué")
mut("C", "planned = used, recruit = rec,", "planned = {}, recruit = rec,", "consommation prévue non transmise")
mut("C", "production_first = sig.production_first, raw_need", "production_first = false, raw_need", "production d'abord non transmise")
mut("C", "st.noyau = nil\n  end", "end", "ancien besoin gardé réglage éteint")
mut("FE", "if evaluated then return nil end", "", "réserve de croissance gardée malgré le besoin couvert")
print(string.format("   mutants refusés : %d / %d", killed, total))
check(killed == total, "tous les mutants refusés")

print(string.format("[RESERVE] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, killed, total))
os.exit(failures == 0 and 0 or 1)
