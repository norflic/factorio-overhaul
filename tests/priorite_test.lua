--[[
  Lot PRIORITE-RESSOURCES (remarque du DC, 29/10 vers 15 h : « si on manque cruellement de ressources, l'objectif est justement
  ces ressources, pas la défense, la défense viendra tout juste après du coup, mais si on peut pas se l'acheter, on investit les
  ressources dans la production de plus de ressources ») : banc HORS JEU. Lancement : lua5.2 tests/priorite_test.lua (racine du mod).

    1. la règle pure (shared/team/priorite.lua) : cas, bornes, invariants sur une grille (force brute) ;
    2. objectifs militaires de l'échelle ;
    3. le planificateur (shared/team/planner.lua) : fer pauvre -> la production passe d'abord (agrandir, bâtir, objectif de
       production devant l'armée) ; fer riche -> la défense d'abord comme avant ; la survie et l'avant-poste meurtrier gardent
       la main ; la défense s'achète dès que le fer dépasse le coût du pas de production ;
    4. le cerveau par besoins (shared/ai3/projets.lua, EMIT.outpost) ;
    5. la capitalisation : pas de part défense / armée en « production d'abord » ;
    6. déterminisme ;
    7. mutants : chaque règle retirée fait changer au moins un fait observé.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Book = require("shared.team.book")
local S = require("shared.team.scale")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end

local function read_src(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local recipes = dofile("tests/fixtures/recipes.lua")
local book = Book.new(recipes)
local norec = {}
do
  local ks = {}
  for k in pairs(recipes) do ks[#ks + 1] = k end
  table.sort(ks)
  for _, k in ipairs(ks) do if k ~= "gun-turret" then norec[k] = recipes[k] end end
end
local book_no = Book.new(norec)

local IRON = T.outposts.iron.product

--- Toute la mécanique à tester, chargée à partir de modules donnés (les mutants passent un module modifié).
local function load_world(over)
  over = over or {}
  local saved = {}
  local names = { "shared.team.priorite", "shared.team.planner", "shared.ai3.projets", "shared.ai3.capitalisation" }
  for _, n in ipairs(names) do saved[n] = package.loaded[n]; package.loaded[n] = nil end
  local function mod(name, path)
    if over[name] then
      local chunk = assert(load(over[name], "@" .. path))
      package.loaded[name] = chunk()
    else
      package.loaded[name] = nil
      package.loaded[name] = require(name)
    end
    return package.loaded[name]
  end
  local W = {}
  W.Pr = mod("shared.team.priorite", "priorite")
  W.Planner = mod("shared.team.planner", "planner")
  W.P = mod("shared.ai3.projets", "projets")
  W.Ca = mod("shared.ai3.capitalisation", "capitalisation")
  for _, n in ipairs(names) do package.loaded[n] = saved[n] end
  return W
end

local function view(over)
  local v = {
    tech = 0, personality = "balanced", done = { coal = true, iron = true, copper = true, stone = true },
    deferred = {}, stock = {}, incoming = {}, outposts = {}, pending = {}, sites = {}, smelters = 2,
    smelters_pending = 0, smelter_task = false, smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0,
    turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 8, workers_max = 30, workers_idle = 0,
    threatened = false, open = {}, workers_wanted = 30, no_research = true, ladder = T.player_ladder,
    hq_turrets = T.defend_hq, defend_first = true,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function op(id, kind, drills, turrets, over)
  local o = { id = id, kind = kind, drills = drills, full = false, turrets = turrets or 0, coal_needed = 0,
    fuel_low = false, output = 0, idle_ticks = 0, has_task = true, has_fortify = false }
  for k, x in pairs(over or {}) do o[k] = x end
  return o
end
local function find(plan, pred)
  for _, t in ipairs(plan.tasks) do if pred(t) then return t end end
  return nil
end
local function key_is(k) return function(t) return t.key == k end end
local function items_of(t, name)
  for _, it in ipairs(t and t.items or {}) do if it[1] == name then return it[2] end end
  return 0
end
local function sig(plan)
  local out = {}
  for _, t in ipairs(plan.tasks) do
    local its = {}
    for _, it in ipairs(t.items or {}) do its[#its + 1] = it[1] .. "x" .. it[2] end
    out[#out + 1] = t.key .. "@" .. tostring(t.prio) .. "[" .. table.concat(its, ",") .. "]"
  end
  local m = {}
  for _, x in ipairs(plan.missing) do m[#m + 1] = x[1] .. "x" .. x[2] end
  return table.concat(out, ";") .. "|" .. table.concat(m, ",") .. "|" .. tostring(plan.goal) .. "|"
    .. tostring(plan.priorite and plan.priorite.mode)
end
local function with(base, extra)
  local s = {}
  for k, x in pairs(base) do s[k] = x end
  for k, x in pairs(extra or {}) do s[k] = x end
  return s
end

local W0 = load_world()
local Pr, Planner = W0.Pr, W0.Planner

---------------------------------------------------------------------------------------------------
section("1. La règle pure : cas et bornes")
---------------------------------------------------------------------------------------------------
local function dec(f, cd, cp, surv) return Pr.decide({ funds = f, defense_cost = cd, production_cost = cp, survival = surv }) end
check(dec(500, 100, 50).mode == Pr.MODE_DEFENSE_D_ABORD and not dec(500, 100, 50).production_first,
  "le fer paie les deux : la défense d'abord, comme avant")
check(dec(150, 100, 50).mode == Pr.MODE_DEFENSE_D_ABORD, "borne : fer = défense + production -> les deux sont payés")
check(dec(149, 100, 50).mode == Pr.MODE_PRODUCTION_D_ABORD and dec(149, 100, 50).production_first,
  "borne : un de moins -> la production d'abord")
local d = dec(120, 100, 50)
check(d.hold == 50 and d.defense_budget == 70, "production d'abord, 120 de fer : 50 réservés au pas, 70 pour la défense")
d = dec(30, 100, 50)
check(d.hold == 30 and d.defense_budget == 0, "manque cruel (30 de fer, pas à 50) : tout va à la production, rien à la défense")
d = dec(0, 100, 50)
check(d.production_first and d.hold == 0 and d.defense_budget == 0, "aucun fer : la production d'abord, rien réservé")
check(dec(10, 100, 0).production_first, "un pas qui ne coûte pas de fer (objets au stock) : la production d'abord quand la défense est impayable")
check(dec(500, 100, 0).mode == Pr.MODE_DEFENSE_D_ABORD, "un pas gratuit et une défense payable : défense d'abord (les deux sont payés)")
check(dec(10, 100, nil).mode == Pr.MODE_DEFENSE and not dec(10, 100, nil).production_first,
  "aucun pas de production à faire : la défense comme avant, même impayable")
check(dec(10, 0, 50).mode == Pr.MODE_PRODUCTION and not dec(10, 0, 50).production_first, "rien à défendre : la production comme avant")
check(dec(10, 0, nil).mode == Pr.MODE_RIEN, "rien à faire")
check(dec(10, 100, 50, true).mode == Pr.MODE_SURVIE and not dec(10, 100, 50, true).production_first,
  "survie (sous l'effectif de départ) : règle d'avant")
check(Pr.decide({}).mode == Pr.MODE_RIEN and Pr.decide().mode == Pr.MODE_RIEN, "entrées vides : rien")
check(dec(-5, 100, 50).funds == 0 and dec(10, -3, 50).defense_cost == 0 and dec(10, 100, -4).production_cost == 0,
  "entrées négatives ramenées à 0")
check(dec(0 / 0, 100, 50).funds == 0, "NaN ramené à 0")
-- Invariants sur une grille (force brute).
local bad, n_cases = {}, 0
for _, f in ipairs({ 0, 1, 17, 49, 50, 51, 99, 100, 149, 150, 151, 400, 5000 }) do
  for _, cd in ipairs({ 0, 1, 50, 100, 400 }) do
    for _, cp in ipairs({ -1, 0, 18, 50, 120 }) do
      for _, sv in ipairs({ false, true }) do
        n_cases = n_cases + 1
        local r = Pr.decide({ funds = f, defense_cost = cd, production_cost = cp >= 0 and cp or nil, survival = sv })
        local has_step = cp >= 0
        local pays_both = has_step and f >= cd + cp
        local expect_pf = (not sv) and has_step and cd > 0 and not pays_both
        if r.production_first ~= expect_pf then bad[#bad + 1] = string.format("pf f=%d cd=%d cp=%d sv=%s", f, cd, cp, tostring(sv)) end
        if r.hold < 0 or r.hold > f or (has_step and r.hold > cp) then bad[#bad + 1] = string.format("hold f=%d cd=%d cp=%d", f, cd, cp) end
        if r.defense_budget < 0 or r.defense_budget > f then bad[#bad + 1] = string.format("budget f=%d cd=%d cp=%d", f, cd, cp) end
        if r.hold + r.defense_budget ~= f then bad[#bad + 1] = string.format("somme f=%d cd=%d cp=%d", f, cd, cp) end
        if not r.production_first and r.hold ~= 0 then bad[#bad + 1] = string.format("hold sans pf f=%d cd=%d cp=%d", f, cd, cp) end
        -- Monotonie : plus de fer ne fait JAMAIS passer de « les deux payés » à « production d'abord ».
        local r2 = Pr.decide({ funds = f + 10, defense_cost = cd, production_cost = cp >= 0 and cp or nil, survival = sv })
        if r.production_first == false and r2.production_first == true then bad[#bad + 1] = string.format("monotonie f=%d cd=%d cp=%d", f, cd, cp) end
        -- Tout le fer au-delà du pas va à la défense : jamais de défense retenue quand le fer paie les deux.
        if pays_both and r.defense_budget < cd then bad[#bad + 1] = string.format("défense retenue f=%d cd=%d cp=%d", f, cd, cp) end
      end
    end
  end
end
check(#bad == 0, string.format("%d cas de la grille, invariants tenus%s", n_cases, #bad > 0 and (" : " .. table.concat(bad, "; ")) or ""))
check(Pr.cheapest({ 40, 18, 72 }) == 18 and Pr.cheapest({}) == nil and Pr.cheapest(nil) == nil and Pr.cheapest({ 0, 5 }) == 0,
  "le pas le moins cher (0 compte)")

---------------------------------------------------------------------------------------------------
section("2. Objectifs militaires de l'échelle")
---------------------------------------------------------------------------------------------------
local AMMO = T.turret_ammo
check(Pr.military_need({ soldiers = 10 }, AMMO) and Pr.military_need({ outpost_turrets = 1 }, AMMO)
  and Pr.military_need({ stock = { [AMMO] = 60 } }, AMMO), "armée, fortifier et réserve de la munition : militaires")
check(not Pr.military_need({ outposts = { iron = 2 } }, AMMO) and not Pr.military_need({ smelters = 4 }, AMMO)
  and not Pr.military_need({ tech = 2 }, AMMO) and not Pr.military_need({ stock = { [T.fuel] = 10 } }, AMMO)
  and not Pr.military_need({ stock = { [AMMO] = 60, [T.fuel] = 10 } }, AMMO) and not Pr.military_need(nil, AMMO)
  and not Pr.military_need({ stock = {} }, AMMO),
  "avant-postes, fours, recherche, autre stock, mélange, vide : pas militaires")
local pf = Pr.decide({ funds = 0, defense_cost = 100, production_cost = 10 })
local nf = Pr.decide({ funds = 900, defense_cost = 100, production_cost = 10 })
check(Pr.skip_goal(pf, { soldiers = 10 }, AMMO) and not Pr.skip_goal(nf, { soldiers = 10 }, AMMO)
  and not Pr.skip_goal(pf, { outposts = { iron = 2 } }, AMMO) and not Pr.skip_goal(nil, { soldiers = 10 }, AMMO),
  "sauté seulement si la production d'abord ET militaire")

---------------------------------------------------------------------------------------------------
section("3. Le planificateur : fer pauvre -> la production d'abord")
---------------------------------------------------------------------------------------------------
local poor0 = { ["copper-plate"] = 100, coal = 500, stone = 500 }
-- Des biens d'équipement au stock : l'agrandissement se paie sans fer (le test ne regarde que l'ordre).
local kit = { ["burner-mining-drill"] = 20, ["stone-furnace"] = 20, ["iron-chest"] = 8 }
local rich = with(kit, { [IRON] = 3000, ["copper-plate"] = 1000, coal = 500, stone = 500, [AMMO] = 60 })
local done2 = { coal = true, iron = true, copper = true, stone = true, defense = true }
-- Le fer est sous-défendu (1 tourelle sur 2) ; l'objectif « fer II » demande un agrandissement.
local outs2 = { op(1, "coal", 4, 1), op(2, "iron", 8, 1), op(3, "copper", 3, 1), op(4, "stone", 2, 1) }
local function plan2(stock, o, over)
  return Planner.plan(view(with({ stock = stock, outposts = o or outs2, done = done2, sites = { iron = 1 } }, over)), book)
end

-- Témoin (riche) : la défense d'abord, comme avant le lot.
local pr = plan2(with(rich, { ["gun-turret"] = 4 }))
check(not pr.priorite.production_first, "riche : défense et production payées (" .. pr.priorite.mode .. ")")
check(find(pr, key_is("fortify:2")) ~= nil and find(pr, key_is("extend:2")) == nil,
  "riche : la tourelle du fer d'abord, pas d'agrandissement avant elle (règle d'avant conservée)")

-- Pauvre : 100 de fer, aucune tourelle ni chargeur au stock, la défense (120) est impayable.
local pp = plan2(with(kit, with(poor0, { [IRON] = 100 })))
check(pp.priorite.mode == Pr.MODE_PRODUCTION_D_ABORD and pp.priorite.production_first, "pauvre : la production d'abord")
check(find(pp, key_is("extend:2")) ~= nil, "pauvre : l'avant-poste de fer sans sa 2e tourelle S'AGRANDIT quand même")
check(find(pp, function(t) return t.kind == "fortify" end) == nil, "pauvre : aucune fortification, le fer va à la production")
check(find(pp, function(t) return t.kind == "craft" and t.item == "gun-turret" end) == nil,
  "pauvre : aucune tourelle fabriquée (le fer est à la production)")
check(pp.priorite.defense_cost > pp.priorite.funds, "pauvre : la défense coûte plus que le fer disponible au-dessus du plancher")

-- Tourelle à l'avant-poste mais avant-poste de fer plein à côté : un NOUVEL avant-poste du même type se bâtit sans ses tourelles.
local outs3 = { op(1, "coal", 12, 2, { full = true }), op(2, "iron", 8, 2, { full = true }), op(3, "copper", 3, 1), op(4, "stone", 2, 1) }
local b_rich = find(plan2(with(rich, { ["gun-turret"] = 4 }), outs3), key_is("build:iron"))
check(b_rich ~= nil and items_of(b_rich, "gun-turret") == T.defend_turrets(8), "riche : le 2e avant-poste de fer se bâtit AVEC ses tourelles")
local b_poor = find(plan2(with(kit, with(poor0, { [IRON] = 100 })), outs3), key_is("build:iron"))
check(b_poor ~= nil and items_of(b_poor, "gun-turret") == 0 and items_of(b_poor, "burner-mining-drill") == 8,
  "pauvre : le 2e avant-poste de fer se bâtit SANS attendre ses tourelles")

-- Reconstruction d'un avant-poste détruit : jamais retenue par les tourelles.
local lost = { op(1, "coal", 4, 1), op(3, "copper", 3, 1), op(4, "stone", 2, 1) }
local pl = plan2(with(kit, with(poor0, { [IRON] = 100 })), lost)
check(find(pl, key_is("build:iron")) ~= nil, "pauvre : le fer détruit est reconstruit")

-- Le plancher du lot IA1-b2 : le fer à 140 (plancher 150) n'achète rien ; avant le lot, l'agrandissement attendait quand même.
local p140 = plan2(with(kit, with(poor0, { [IRON] = 140 })))
check(p140.priorite.production_first and find(p140, key_is("extend:2")) ~= nil,
  "fer 140 (sous le plancher de la défense) : la production d'abord, l'agrandissement part")

-- Entre les deux : le pas de production est réservé, la défense ne dépense que le fer au-delà.
local no_kit = with(poor0, {})
local function craft_turret(p) return find(p, function(t) return t.kind == "craft" and t.item == "gun-turret" end) end
local f_cd = T.defend_iron_floor
local probe = plan2(with(no_kit, { [IRON] = 3000 }))
local cd, cp = probe.priorite.defense_cost, probe.priorite.production_cost
check(cd > 0 and cp and cp > 0, string.format("mesure : la défense coûte %d, le pas de production %d", cd, cp or -1))
local p_mid = plan2(with(no_kit, { [IRON] = f_cd + cd + cp - 1 }))
check(p_mid.priorite.production_first and p_mid.priorite.hold == cp and p_mid.priorite.defense_budget == cd - 1,
  "un fer de moins que défense + production : la production d'abord, le pas est réservé (" .. tostring(p_mid.priorite.hold)
  .. "), la défense a le reste (" .. tostring(p_mid.priorite.defense_budget) .. ")")
-- Le pas réservé n'est pas dépensé par la défense : on cherche le fer le plus bas où la première tourelle se fabrique (la
-- production d'abord, le pas réservé) ; un fer de moins, elle ne se fabrique pas (la défense n'a que le fer au-delà du pas).
local edge
for fe = f_cd, f_cd + cd + cp do
  if craft_turret(plan2(with(no_kit, { [IRON] = fe }))) then edge = fe break end
end
check(edge ~= nil and edge > f_cd + cp and plan2(with(no_kit, { [IRON] = edge })).priorite.production_first,
  "la première tourelle se fabrique dès " .. tostring(edge) .. " de fer, encore en production d'abord")
local p_ok = plan2(with(no_kit, { [IRON] = f_cd + cd + cp }))
check(not p_ok.priorite.production_first and craft_turret(p_ok) ~= nil,
  "fer = défense + production (+ plancher) : les deux sont payés, la tourelle se fabrique (« tout juste après »)")
local p_hi = plan2(with(no_kit, { [IRON] = f_cd + cd + cp + 400 }))
check(craft_turret(p_hi) ~= nil, "bien plus de fer : la tourelle aussi")
-- La défense n'est JAMAIS retenue quand le fer paie les deux, à toute hauteur de fer.
local never_held = true
for fe = f_cd + cd + cp, f_cd + cd + cp + 300, 7 do
  local p = plan2(with(no_kit, { [IRON] = fe }))
  if craft_turret(p) == nil then never_held = false end
end
check(never_held, "jamais de tourelle retenue quand le fer paie la défense et le pas de production")

-- Pas de plancher de réserve : la production d'abord ne retient rien au-delà du pas (le fer inutile revient au stock).
local p_free = plan2(with(kit, with(poor0, { [IRON] = 100 })))
check(p_free.priorite.hold <= (p_free.priorite.production_cost or 0), "réservation bornée au prix d'UN pas de production")

-- Objectifs militaires : l'armée passe après le fer II quand le fer ne paie pas tout.
local ladder_mil = {
  { key = "army", need = { soldiers = 10 } },
  { key = "iron2", need = { outposts = { iron = 2, coal = 2 } } },
}
local function plan_army(stock)
  return Planner.plan(view(with({ stock = stock, outposts = outs2, done = { coal = true, iron = true, copper = true, stone = true },
    sites = { iron = 1 }, ladder = ladder_mil, soldiers = 0, soldiers_max = 30, tech = 0, defend_first = true, hq_turrets = T.defend_hq,
    workers = 8 }, {})), book)
end
local pa_poor = plan_army(with(kit, with(poor0, { [IRON] = 100 })))
check(pa_poor.priorite.production_first and pa_poor.goal == "iron2" and (pa_poor.skipped_goals or 0) == 1,
  "pauvre : l'objectif « armée » est sauté, on poursuit « fer II » (" .. tostring(pa_poor.goal) .. ")")
check(find(pa_poor, key_is("extend:2")) ~= nil or find(pa_poor, key_is("extend:1")) ~= nil, "pauvre : l'agrandissement de l'objectif de production part")
local pa_rich = plan_army(with(rich, { ["gun-turret"] = 4 }))
check(not pa_rich.priorite.production_first and pa_rich.goal == "army" and (pa_rich.skipped_goals or 0) == 0,
  "riche : « armée » d'abord, comme avant (" .. tostring(pa_rich.goal) .. ")")
-- Les deux ensemble : 'army' puis 'iron2' ; sans objectif de production derrière, l'armée reste (rien à sauter vers).
local ladder_only_mil = { { key = "army", need = { soldiers = 10 } } }
local pa_only = Planner.plan(view({ stock = with(kit, with(poor0, { [IRON] = 100 })), outposts = outs2, ladder = ladder_only_mil,
  soldiers = 0, soldiers_max = 30, done = { coal = true, iron = true, copper = true, stone = true } }), book)
check(pa_only.goal == nil, "pauvre, l'armée est le seul objectif : sautée, aucun objectif poursuivi (l'armée revient quand le fer paie)")
-- Un objectif atteint reste enregistré même quand un objectif militaire est sauté.
local ladder_r = { { key = "coal", need = { outposts = { coal = 1 } } }, { key = "army", need = { soldiers = 10 } },
  { key = "iron2", need = { outposts = { iron = 2, coal = 2 } } } }
local pr_r = Planner.plan(view({ stock = with(kit, with(poor0, { [IRON] = 100 })), outposts = outs2, ladder = ladder_r, soldiers = 0,
  soldiers_max = 30, done = {}, sites = { iron = 1 } }), book)
check(#pr_r.reached == 1 and pr_r.reached[1] == "coal", "l'objectif atteint avant l'armée sautée est bien enregistré")

-- Menace : l'entraînement de réponse à une attaque garde la main (la remarque du DC vise l'ordre de l'ÉCHELLE).
local pa_thr = Planner.plan(view({ stock = with(kit, with(poor0, { [IRON] = 100 })), outposts = outs2, ladder = ladder_mil, soldiers = 0,
  soldiers_max = 30, threatened = true, done = { coal = true, iron = true, copper = true, stone = true, army = true }, sites = { iron = 1 } }), book)
check(pa_thr.priorite.production_first and (pa_thr.train ~= nil or find(pa_thr, function(t) return t.kind == "craft" end) ~= nil),
  "sous attaque : l'entraînement des soldats continue (hors de l'échelle)")

-- Survie : sous l'effectif de départ la règle d'avant s'applique.
local ps = Planner.plan(view({ stock = with(kit, with(poor0, { [IRON] = 100 })), outposts = outs2, done = done2, sites = { iron = 1 },
  workers = 3, recover_floor = 8 }), book)
check(ps.priorite.mode == Pr.MODE_SURVIE and not ps.priorite.production_first and find(ps, key_is("extend:2")) == nil,
  "sous l'effectif de départ : survie, règle d'avant (pas d'agrandissement avant la tourelle)")

-- Avant-poste MEURTRIER : il reste exclu, même en production d'abord.
local outs_l = { op(1, "coal", 4, 1), op(2, "iron", 8, 1, { lethal = true, has_task = false }), op(3, "copper", 3, 1), op(4, "stone", 2, 1) }
local pm = plan2(with(kit, with(poor0, { [IRON] = 100 })), outs_l)
check(pm.priorite.production_first and find(pm, key_is("extend:2")) == nil, "meurtrier, production d'abord : pas d'agrandissement du fer meurtrier")
-- Sans « défendre d'abord » : plan d'avant, aucune décision de priorité.
local pn = Planner.plan(view({ defend_first = false, stock = with(kit, with(poor0, { [IRON] = 100 })), outposts = outs2, done = done2,
  sites = { iron = 1 } }), book)
check(pn.priorite.mode == Pr.MODE_RIEN and not pn.priorite.production_first, "sans « défendre d'abord » : aucun effet")
-- Sans recette de tourelle : règle de repli (extension comme avant), aucun effet du lot.
local pb = Planner.plan(view({ stock = with(kit, with(poor0, { [IRON] = 100 })), outposts = outs2, done = done2, sites = { iron = 1 } }), book_no)
check(find(pb, key_is("extend:2")) ~= nil, "sans recette de tourelle : l'agrandissement part comme avant")
-- Un pas déjà au tableau (extension ouverte, ou en attente) n'est pas recompté ; plus de pas : la défense comme avant.
local pe = Planner.plan(view({ stock = with(kit, with(poor0, { [IRON] = 100 })), done = done2, sites = {},
  outposts = { op(1, "coal", 12, 2, { full = true }), op(2, "iron", 8, 1, { full = true }), op(3, "copper", 3, 1, { full = true }), op(4, "stone", 2, 1, { full = true }) } }), book)
check(pe.priorite.mode == Pr.MODE_DEFENSE and not pe.priorite.production_first,
  "tous les avant-postes pleins, aucun site : rien à produire, la défense comme avant (" .. pe.priorite.mode .. ")")
local po = plan2(with(kit, with(poor0, { [IRON] = 100 })), outs2, { open = { ["extend:1"] = true, ["extend:2"] = true, ["extend:3"] = true,
  ["extend:4"] = true } })
check(po.priorite.mode == Pr.MODE_DEFENSE, "tous les agrandissements déjà ouverts : plus de pas à faire (" .. po.priorite.mode .. ")")
-- Faisabilité : sans pierre (le four ne se fabrique pas), le pas n'est pas faisable et ne retient pas la défense.
local pnf = plan2(with(poor0, { [IRON] = 100, stone = 0, coal = 0 }), { op(2, "iron", 8, 1) })
check(pnf.priorite.production_cost == nil or pnf.priorite.mode == Pr.MODE_DEFENSE,
  "un pas infaisable (matière autre que le fer absente) n'est pas compté")

---------------------------------------------------------------------------------------------------
section("4. Le cerveau par besoins (EMIT.outpost)")
---------------------------------------------------------------------------------------------------
local function emit_outpost(W, stock, o, priorite, kind)
  local E = W.P.context(with(stock, {}), book, view({ stock = stock, outposts = o, done = done2, sites = { iron = 1 } }), {})
  E.priorite = priorite
  local proj = { id = 1, key = "outpost:" .. kind, prio = 50 }
  local status, cause = W.P.EMIT.outpost(E, proj, { outpost = kind }, { tick = 0 })
  return status, cause, E
end
local st_poor = with(kit, with(poor0, { [IRON] = 100 }))
local s1, c1, E1 = emit_outpost(W0, st_poor, outs2, nil, "iron")
check(s1 == "bloque" and c1 == "tourelles" or s1 == "matiere", "sans décision de priorité : le fer sous-défendu attend ses tourelles (" .. tostring(s1) .. ")")
check(E1.tasks[1] == nil or E1.tasks[1].key ~= "extend:2", "…et ne s'agrandit pas")
local s2, _, E2 = emit_outpost(W0, st_poor, outs2, { production_first = true, mode = Pr.MODE_PRODUCTION_D_ABORD }, "iron")
check(s2 == "ok" and E2.tasks[1] and E2.tasks[1].key == "extend:2", "production d'abord : l'avant-poste de fer s'agrandit sans attendre sa tourelle")
local s3, _, E3 = emit_outpost(W0, st_poor, outs2, { production_first = false, mode = Pr.MODE_DEFENSE_D_ABORD }, "iron")
check(E3.tasks[1] == nil or E3.tasks[1].key ~= "extend:2", "les deux payés : règle d'avant")
-- Nouvel avant-poste d'un type déjà exploité : sans ses tourelles en production d'abord.
local s4, _, E4 = emit_outpost(W0, st_poor, outs3, { production_first = true }, "iron")
local bt = E4.tasks[1]
check(s4 == "ok" and bt and bt.key == "build:iron" and items_of(bt, "gun-turret") == 0, "production d'abord : le nouvel avant-poste se bâtit sans ses tourelles")
local s5, _, E5 = emit_outpost(W0, with(st_poor, { ["gun-turret"] = 4, [AMMO] = 100 }), outs3, { production_first = false }, "iron")
local bt5 = E5.tasks[1]
check(s5 == "ok" and bt5 and items_of(bt5, "gun-turret") == T.defend_turrets(8), "les deux payés : il se bâtit avec ses tourelles (règle d'avant)")
-- Le cerveau complet porte la décision du planificateur permanent.
local C = require("shared.ai3.cerveau")
local B = require("shared.ai3.buts")
local cst = C.new_state(0)
local cplan = C.think(view({ is_player = true, stock = with(kit, with(poor0, { [IRON] = 100 })), outposts = outs2, done = done2,
  sites = { iron = 1 }, workers_idle = 4 }), book, cst, { tick = 0, is_player = true, weights = B.weights({}, nil), reach = {} })
check(cplan.priorite ~= nil and cplan.priorite.production_first == true, "C.think publie plan.priorite (production d'abord, fer pauvre)")
local cplan2 = C.think(view({ is_player = true, stock = with(rich, { ["gun-turret"] = 4 }), outposts = outs2, done = done2,
  sites = { iron = 1 }, workers_idle = 4 }), book, C.new_state(0), { tick = 0, is_player = true, weights = B.weights({}, nil), reach = {} })
check(cplan2.priorite ~= nil and cplan2.priorite.production_first == false, "C.think : fer riche, les deux payés")

---------------------------------------------------------------------------------------------------
section("5. La capitalisation : pas de part défense / armée en production d'abord")
---------------------------------------------------------------------------------------------------
local Ca = W0.Ca
local ch0 = Ca.character({}, {}, false)
local ch1 = Ca.character({}, {}, false, true)
check(ch0.delta > 0 and ch0.alpha > 0, "règle d'avant : parts défense " .. ch0.delta .. " ‰ et armée " .. ch0.alpha .. " ‰")
check(ch1.delta == 0 and ch1.alpha == 0 and ch1.s == ch0.s and ch1.tmax == ch0.tmax, "production d'abord : aucune part défense ni armée, le reste inchangé")
local b0 = Ca.budget(ch0, 100, 1000, 1, 0)
local b1 = Ca.budget(ch1, 100, 1000, 1, 0)
check(b1 > b0, "le budget d'investissement grandit des parts rendues (" .. string.format("%.1f -> %.1f", b0, b1) .. ")")
local cv = Ca.capi_view({ x = 1000 }, ch1)
check(cv.x == 1000, "la part capi du stock virtuel est entière")
check(Ca.character({}, {}, true, true).delta == 0, "menace + production d'abord : la production d'abord l'emporte sur la part de menace")

---------------------------------------------------------------------------------------------------
section("6. Déterminisme")
---------------------------------------------------------------------------------------------------
local da = plan2(with(kit, with(poor0, { [IRON] = 100 })))
local db = plan2(with(kit, with(poor0, { [IRON] = 100 })))
check(sig(da) == sig(db), "deux pensées identiques : même plan et même décision")
local dc = Planner.plan(view({ stock = with(kit, with(poor0, { [IRON] = 100 })), outposts = outs2, done = done2, sites = { iron = 1 } }), book)
check(sig(dc) == sig(da), "ordre des champs de la vue sans effet")

---------------------------------------------------------------------------------------------------
section("7. Mutants : chaque règle retirée change au moins un fait")
---------------------------------------------------------------------------------------------------
--- Faits observés : tout ce que le lot doit garantir, dans une chaîne comparable.
local function facts(W)
  local out = {}
  local function put(k, v) out[#out + 1] = k .. "=" .. tostring(v) end
  local Pn = W.Planner
  local function pl2(stock, o, over)
    return Pn.plan(view(with({ stock = stock, outposts = o or outs2, done = done2, sites = { iron = 1 } }, over)), book)
  end
  local function has(p, k) return find(p, key_is(k)) ~= nil end
  local poor = with(kit, with(poor0, { [IRON] = 100 }))
  local a = pl2(poor)
  put("pauvre.extend", has(a, "extend:2"))
  put("pauvre.mode", a.priorite.mode)
  put("pauvre.fortify", find(a, function(t) return t.kind == "fortify" end) ~= nil)
  local b = pl2(with(rich, { ["gun-turret"] = 4 }))
  put("riche.extend", has(b, "extend:2"))
  put("riche.fortify", has(b, "fortify:2"))
  put("riche.mode", b.priorite.mode)
  local c = pl2(poor, outs3)
  local bi = find(c, key_is("build:iron"))
  put("pauvre.build.tourelles", bi and items_of(bi, "gun-turret") or "aucun")
  local d_ = pl2(with(no_kit, { [IRON] = edge - 1 }))
  put("milieu.tourelle", find(d_, function(t) return t.kind == "craft" and t.item == "gun-turret" end) ~= nil)
  put("milieu.hold", d_.priorite.hold)
  put("milieu.budget", d_.priorite.defense_budget)
  local e = pl2(with(no_kit, { [IRON] = f_cd + cd + cp }))
  put("juste.tourelle", find(e, function(t) return t.kind == "craft" and t.item == "gun-turret" end) ~= nil)
  local s = pl2(poor, outs2, { workers = 3, recover_floor = 8 })
  put("survie.mode", s.priorite.mode)
  put("survie.extend", has(s, "extend:2"))
  local m = pl2(poor, outs_l)
  put("meurtrier.extend", has(m, "extend:2"))
  local ml = Pn.plan(view({ stock = poor, outposts = { op(2, "iron", 8, 1, { lethal = true, has_task = false }) }, done = done2, sites = {} }), book)
  put("meurtrier.seul", ml.priorite.mode)
  local ar = Pn.plan(view({ stock = poor, outposts = outs2, ladder = ladder_mil, soldiers = 0, soldiers_max = 30,
    done = { coal = true, iron = true, copper = true, stone = true }, sites = { iron = 1 } }), book)
  put("armee.goal", ar.goal)
  local ar2 = Pn.plan(view({ stock = with(rich, { ["gun-turret"] = 4 }), outposts = outs2, ladder = ladder_mil, soldiers = 0,
    soldiers_max = 30, done = { coal = true, iron = true, copper = true, stone = true }, sites = { iron = 1 } }), book)
  put("armee.riche.goal", ar2.goal)
  local lt = Pn.plan(view({ stock = poor, outposts = lost, done = done2, sites = { iron = 1 } }), book)
  put("reconstruction", has(lt, "build:iron"))
  -- cerveau par besoins
  local E = W.P.context(with(poor, {}), book, view({ stock = poor, outposts = outs2, done = done2, sites = { iron = 1 } }), {})
  E.priorite = a.priorite
  local st = W.P.EMIT.outpost(E, { id = 1, key = "outpost:iron", prio = 50 }, { outpost = "iron" }, { tick = 0 })
  put("emit.statut", st)
  -- capitalisation
  local chx = W.Ca.character({}, {}, false, true)
  put("capi.parts", chx.delta .. "/" .. chx.alpha)
  -- règle pure
  local r = W.Pr.decide({ funds = 120, defense_cost = 100, production_cost = 50 })
  put("pur", r.mode .. "/" .. r.hold .. "/" .. r.defense_budget)
  local r2 = W.Pr.decide({ funds = 150, defense_cost = 100, production_cost = 50 })
  put("pur.borne", r2.mode)
  put("pur.sauter", tostring(W.Pr.skip_goal(r, { soldiers = 10 }, AMMO)) .. tostring(W.Pr.skip_goal(r, { outposts = { iron = 2 } }, AMMO))
    .. tostring(W.Pr.military_need({ outpost_turrets = 1 }, AMMO)) .. tostring(W.Pr.military_need({ stock = { [AMMO] = 1 } }, AMMO)))
  put("pur.survie", W.Pr.decide({ funds = 1, defense_cost = 100, production_cost = 50, survival = true }).mode)
  put("pur.sanspas", W.Pr.decide({ funds = 1, defense_cost = 100 }).mode)
  put("pur.neg", W.Pr.decide({ funds = -5, defense_cost = 100, production_cost = 50 }).funds)
  return table.concat(out, "\n")
end
local base_facts = facts(W0)
check(base_facts:find("pauvre.extend=true", 1, true) and base_facts:find("riche.fortify=true", 1, true),
  "témoin : les faits de base disent « pauvre : agrandit », « riche : fortifie »")

local src = {
  Pr = read_src("shared/team/priorite.lua"),
  Pl = read_src("shared/team/planner.lua"),
  Pj = read_src("shared/ai3/projets.lua"),
  Ca = read_src("shared/ai3/capitalisation.lua"),
}
local function mutate(text, from, to)
  local a, b = text:find(from, 1, true)
  if not a then return nil end
  return text:sub(1, a - 1) .. to .. text:sub(b + 1)
end
local mutants = {
  { "règle pure : la production n'est jamais d'abord", "Pr", "    out.production_first = true\n", "    out.production_first = false\n" },
  { "règle pure : la borne « les deux payés » devient stricte", "Pr", "elseif funds >= cd + cp then", "elseif funds > cd + cp then" },
  { "règle pure : rien n'est réservé à la production", "Pr", "out.hold = math.min(funds, cp)", "out.hold = 0" },
  { "règle pure : la défense ne dépense pas le fer au-delà du pas", "Pr", "out.defense_budget = funds - out.hold", "out.defense_budget = 0" },
  { "règle pure : la survie est ignorée", "Pr", "if a.survival then", "if false then" },
  { "règle pure : les soldats ne sont plus militaires", "Pr", "if need.soldiers or need.outpost_turrets then return true end", "if need.outpost_turrets then return true end" },
  { "règle pure : la fortification n'est plus militaire", "Pr", "if need.soldiers or need.outpost_turrets then return true end", "if need.soldiers then return true end" },
  { "règle pure : tout objectif est sauté", "Pr", "return pri ~= nil and pri.production_first == true and Pr.military_need(need, ammo)", "return pri ~= nil and pri.production_first == true" },
  { "règle pure : un pas inexistant compte comme zéro", "Pr", "local has_step = a.production_cost ~= nil", "local has_step = true" },
  { "planificateur : l'avant-poste sous-défendu attend toujours sa tourelle", "Pl", "local block = turret_ok and not pri.production_first", "local block = turret_ok" },
  { "planificateur : le pas de production n'est pas réservé", "Pl", "local held = math.min(pri.hold or 0, avail[iron_key] or 0)", "local held = 0" },
  { "planificateur : le fer sous le plancher compte pour la défense", "Pl", "funds = (avail[iron_key] or 0) - T.defend_iron_floor,", "funds = (avail[iron_key] or 0)," },
  { "planificateur : l'objectif militaire n'est plus sauté", "Pl", "elseif Pr.skip_goal(pri, g.need, T.turret_ammo) then", "elseif false then" },
  { "planificateur : la survie ne protège plus", "Pl", "survival = decimated })", "survival = false })" },
  { "planificateur : un avant-poste meurtrier devient agrandissable", "Pl", "o.drills < T.max_drills(o.kind) and not lethal_only[o.id] then\n        growable", "o.drills < T.max_drills(o.kind) then\n        growable" },
  { "planificateur : le coût de la défense est nul", "Pl", "local cd = n_miss > 0 and iron_cost(turret_items(n_miss)) or 0", "local cd = 0" },
  { "cerveau par besoins : l'avant-poste attend ses tourelles", "Pj", "  if pf then turret_ok = false end\n", "" },
  { "capitalisation : les parts défense et armée restent", "Ca", "  if production_first then delta, alpha = 0, 0 end\n", "" },
}
local killed = 0
for _, m in ipairs(mutants) do
  local name, which, from, to = m[1], m[2], m[3], m[4]
  local over = {}
  local text = src[which]
  local mutated = mutate(text, from, to)
  if not check(mutated ~= nil, "mutant « " .. name .. " » : le texte à muter existe encore") then goto continue end
  over[({ Pr = "shared.team.priorite", Pl = "shared.team.planner", Pj = "shared.ai3.projets", Ca = "shared.ai3.capitalisation" })[which]] = mutated
  do
    local ok, got = pcall(function() return facts(load_world(over)) end)
    local differs = (not ok) or got ~= base_facts
    if check(differs, "mutant « " .. name .. " » refusé (un fait change)") then killed = killed + 1 end
  end
  ::continue::
end
print(string.format("[PRIORITE] mutants refusés : %d sur %d", killed, #mutants))

print(string.format("[PRIORITE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
