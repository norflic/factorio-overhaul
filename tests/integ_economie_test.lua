--[[
  Lot INTEG-ECONOMIE (relecture d'intégration de la 0.6.17, thème économie) : banc HORS JEU. Lancement : lua5.2 tests/integ_economie_test.lua
    D1  la priorité « production d'abord » est lue par l'armée et la réserve de munitions du cerveau (shared/ai3/projets.lua),
        la défense MINIMALE (premiers soldats, réserve jusqu'à B.AMMO_MIN) reste payée ;
    D2  un module réduit après un échec de matériaux (CAPI-REPLI) n'est pas remonté par AGENCEMENT (câblage, source) ;
    D4  le charbon des fours du plan directeur entre dans le bilan du charbon du planificateur ;
    D5  le site proche bloqué devient un lieu à couvrir par le front (shared/team/site_securise.lua + Fr.plan) ;
    mutants : chaque règle retirée fait changer un fait observé.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Book = require("shared.team.book")
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end
local function read_src(path)
  local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s
end

local recipes = dofile("tests/fixtures/recipes.lua")
local book = Book.new(recipes)
local IRON = T.outposts.iron.product
local AMMO = T.turret_ammo

--- Projets du cerveau chargés depuis une source donnée (les mutants passent un texte modifié).
local function load_projets(src)
  local saved = package.loaded["shared.ai3.projets"]
  package.loaded["shared.ai3.projets"] = nil
  local P
  if src then P = assert(load(src, "@projets"))() else P = require("shared.ai3.projets") end
  package.loaded["shared.ai3.projets"] = saved
  return P
end

local function emit(P, iron, pri, goal)
  local view = { soldiers = 0, tech = 0, outposts = {}, pending = {}, sites = {}, smelters = 2, stock = {}, incoming = {}, open = {} }
  local E = P.context({ [IRON] = iron, coal = 500, stone = 500, ["copper-plate"] = 500, wood = 100 }, book, view, {})
  E.priorite = pri
  local st = P.EMIT[goal.kind](E, { id = 1, key = "x", prio = 50 }, goal, { tick = 0 })
  return st, E
end
local function iron_tasks(E)
  local n = 0
  for _, t in ipairs(E.tasks) do for _, u in ipairs(t.uses or {}) do if u[1] == IRON then n = n + u[2] end end end
  return n
end

---------------------------------------------------------------------------------------------------
section("1. D1 : l'armée et les munitions lisent la priorité")
---------------------------------------------------------------------------------------------------
local P0 = load_projets()
local PF = { production_first = true, hold = 200, mode = "production_d_abord" }
local ARMY = { kind = "army", target = 10 }
local _, E0 = emit(P0, 300, nil, ARMY)
local _, E1 = emit(P0, 300, PF, ARMY)
check(iron_tasks(E0) > iron_tasks(E1), "armée à 300 de fer, 200 réservés : moins de fer pris que sans décision (" .. iron_tasks(E0) .. " > " .. iron_tasks(E1) .. ")")
check(E1.avail[IRON] >= 200, "le fer réservé est rendu au stock virtuel (reste " .. E1.avail[IRON] .. ")")
local _, En = emit(P0, 300, { production_first = false, hold = 0 }, ARMY)
check(iron_tasks(En) == iron_tasks(E0), "défense payée (pas de production d'abord) : règle d'avant")
-- Le fer réservé n'est jamais consommé : 120 de fer, 200 réservés -> aucune fabrication de l'armée.
local _, Ep = emit(P0, 120, PF, ARMY)
check(#Ep.tasks == 0 and Ep.avail[IRON] == 120, "fer entièrement réservé à la production : l'armée ne fabrique rien et le stock est intact")
-- Défense minimale : les premiers soldats ne sont pas retenus.
local _, Em = emit(P0, 120, PF, { kind = "army", target = 10, minimal = true })
check(#Em.tasks > 0, "premiers soldats (défense minimale) : fabriqués malgré la production d'abord")
-- Munitions : la part minimale passe, le reste est retenu.
local _, Ea = emit(P0, 300, PF, { kind = "stock", item = AMMO, n = 40, minimal_n = 20 })
local sb, Eb = emit(P0, 300, PF, { kind = "stock", item = AMMO, n = 40, minimal_n = 0 })
local sc, Ec = emit(P0, 300, nil, { kind = "stock", item = AMMO, n = 40, minimal_n = 20 })
check(iron_tasks(Eb) <= iron_tasks(Ea) and iron_tasks(Ea) <= iron_tasks(Ec), "munitions : retenues sans minimum <= minimum seul <= sans décision ("
  .. iron_tasks(Eb) .. " <= " .. iron_tasks(Ea) .. " <= " .. iron_tasks(Ec) .. ")")
check(sb == "matiere" and sc == "ok", "munitions : réserve entière retenue (matiere) contre servie sans décision (ok)")
local _, Ez = emit(P0, 120, PF, { kind = "stock", item = AMMO, n = 40, minimal_n = 0 })
check(#Ez.tasks == 0, "munitions sans minimum, fer réservé : rien fabriqué")
local _, Ez2 = emit(P0, 120, PF, { kind = "stock", item = AMMO, n = 40, minimal_n = 20 })
check(#Ez2.tasks > 0, "munitions sous leur minimum : fabriquées malgré le fer réservé")
-- Les buts publient bien les drapeaux.
local B = require("shared.ai3.buts")
check(B.AMMO_MIN ~= nil and B.AMMO_MIN < B.AMMO_STOCK, "B.AMMO_MIN < B.AMMO_STOCK")
local function goals_of(over)
  local s = { cap = { iron = 1, coal = 1 }, pending = {}, stock = {}, weights = {}, soldiers = 0, soldiers_max = 30, army_target = 20,
    smelters = 4, smelters_pending = 0, at_war = false, is_player = false }
  for k, v in pairs(over or {}) do s[k] = v end
  return B.generate(s, {})
end
local function find_goal(gs, key) for _, g in ipairs(gs) do if g.key == key then return g end end end
local ga = find_goal(goals_of({ soldiers = 2 }), "armee")
check(ga and ga.minimal == true, "armée sous ses 10 premiers soldats : but minimal")
local gb = find_goal(goals_of({ soldiers = 12 }), "armee")
check(gb and not gb.minimal, "armée au-delà des 10 premiers : but non minimal (retenu en production d'abord)")
local gm = find_goal(goals_of({ stock = { [AMMO] = 5 } }), "defense:munitions")
check(gm and gm.minimal_n == B.AMMO_MIN - 5, "munitions à 5 : minimum à servir " .. (B.AMMO_MIN - 5))
local gm2 = find_goal(goals_of({ stock = { [AMMO] = B.AMMO_MIN + 5 } }), "defense:munitions")
check(gm2 and gm2.minimal_n == 0, "munitions au-dessus du minimum : rien de minimal")

---------------------------------------------------------------------------------------------------
section("2. D2 : le module réduit n'est pas remonté par AGENCEMENT")
---------------------------------------------------------------------------------------------------
local Li = require("shared.team.ligne")
local grown = Li.rows_wanted({ rows_rate = 1, pairs_dep = 8, drill_rate = 0.5, cap = 0.3, pairs_line = 8, rows_max = 12, grow = true,
  rows_fit = 12, budget_rows = Li.budget_rows(0, T.ligne.row_cost, T.ligne.stock_share, T.ligne.rows_floor) })
check(grown >= T.ligne.rows_floor, "fait de départ : sans garde, une demande de 1 rangée remonte à " .. grown .. " (plancher " .. T.ligne.rows_floor .. ")")
local cap_src, auto_src, build_src = read_src("script/ai3/capitalisation.lua"), read_src("script/ai3/automatisation.lua"), read_src("script/team/build.lua")
check(cap_src:find("shrunk = shrunk or nil", 1, true) and cap_src:find("Rp.factor(repli, rkey, tick) < 1", 1, true), "CAPI : le module réduit porte shrunk")
check(auto_src:find("shrunk = rq.shrunk or nil", 1, true), "automatisation : spec.shrunk repris de la demande")
check(build_src:find("if spec.shrunk then return cur end", 1, true), "build : une ligne réduite garde la taille demandée")

---------------------------------------------------------------------------------------------------
section("3. D4 : le charbon des fours du plan directeur dans le bilan")
---------------------------------------------------------------------------------------------------
local Planner = require("shared.team.planner")
local S = require("shared.team.scale")
local function view2(over)
  local v = {
    tech = 0, personality = "balanced", done = { coal = true, iron = true, copper = true, stone = true },
    deferred = {}, stock = { [IRON] = 600, coal = 500, stone = 500, ["copper-plate"] = 300, ["burner-mining-drill"] = 10, ["stone-furnace"] = 10, ["iron-chest"] = 6 },
    incoming = {}, pending = {}, sites = { coal = 1 }, smelters = 2, smelters_pending = 0, smelter_task = false, smelter_output = 0,
    smelter_fuel_low = false, smelter_coal = 0, turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 8, workers_max = 30,
    workers_idle = 0, threatened = false, open = {}, workers_wanted = 30, no_research = true, ladder = T.player_ladder,
    hq_turrets = T.defend_hq, defend_first = false,
    outposts = { { id = 1, kind = "coal", drills = 4, full = false, turrets = 1, coal_needed = 0, fuel_low = false, output = 0, idle_ticks = 0,
      has_task = true, has_fortify = false } },
  }
  for k, x in pairs(over or {}) do v[k] = x end
  v.recruit_cost = S.recruit_cost(v.workers)
  return v
end
local p_base = Planner.plan(view2({}), book)
local p_burn = Planner.plan(view2({ build_burn = 3.0 }), book)
check(p_base.burn_rate ~= nil and p_burn.burn_rate ~= nil and math.abs(p_burn.burn_rate - p_base.burn_rate - 3.0) < 1e-9,
  "burn_rate du planificateur augmente du charbon des fours du plan (" .. tostring(p_base.burn_rate) .. " -> " .. tostring(p_burn.burn_rate) .. ")")
local function has_coal_step(plan)
  for _, t in ipairs(plan.tasks) do if t.key == "extend:1" or t.key == "build:coal" then return true end end
  return false
end
check(not has_coal_step(p_base) and has_coal_step(p_burn), "un charbon qui ne couvre plus les fours du plan fait agrandir l'avant-poste de charbon")
local team_src = read_src("script/team/team.lua")
check(team_src:find("build_burn = Build.burn_rate(f, game.tick)", 1, true), "la vue publie build_burn")
check(build_src:find("function Build.burn_rate", 1, true) and build_src:find("sp.kind == \"furnace\" and sp.burner_kw", 1, true), "Build.burn_rate lit la puissance aux données (M.spec)")

---------------------------------------------------------------------------------------------------
section("4. D5 : le site proche bloqué est couvert par le front")
---------------------------------------------------------------------------------------------------
local Sec = require("shared.team.site_securise")
local Fr = require("shared.team.front")
local tick = 1000
local sig = { coal = { x = 100, y = 40, why = "perte", until_tick = tick + 500, d_blocked = 60, n = 2 },
  iron = { x = -30, y = 20, why = "hostile", until_tick = tick + 500, d_blocked = 40, n = 1 },
  stone = { x = 5, y = 5, why = "ecarte", until_tick = tick - 1, d_blocked = 10, n = 3 },
  copper = { x = 0, y = 0, why = "perte", until_tick = tick + 500, d_blocked = 20, n = 0 } }
local cv = Sec.covers(sig, tick)
check(#cv == 2 and cv[1].resource == "iron" and cv[2].resource == "coal", "site proche bloqué : les 2 plus proches du QG, échu et sans site suspendu écartés")
check(cv[1].key == "bloque:iron" and cv[1].x == -30 and cv[1].y == 20 and cv[1].n == 1, "lieu : clé, position, poids")
check(#Sec.covers(nil, tick) == 0 and #Sec.covers({}, tick) == 0, "aucun signal : aucun lieu")
local plan = Fr.plan({ cells = {}, cover = cv, turrets = {}, placed = 0, allow = function() return true end })
check(plan.pick ~= nil and plan.pick.key == "bloque:iron" and plan.pick.kind == "couverture" and plan.pick.count >= 1,
  "le front choisit de couvrir le site bloqué (" .. tostring(plan.pick and plan.pick.key) .. ")")
local plan2 = Fr.plan({ cells = {}, cover = cv, turrets = { { x = -30, y = 20 }, { x = -31, y = 20 } }, placed = 2,
  allow = function() return true end })
check(plan2.pick ~= nil and plan2.pick.key == "bloque:coal", "site déjà couvert par ses tourelles : le suivant")
local plan3 = Fr.plan({ cells = {}, cover = cv, turrets = {}, placed = 0, allow = function(row) return row.key ~= "bloque:iron" end })
check(plan3.pick ~= nil and plan3.pick.key == "bloque:coal", "ennemi sur place (le moteur refuse) : le suivant, jamais de pose sous les nids")
check(Sec.covers(sig, tick)[1].key == Sec.covers(sig, tick)[1].key and Sec.covers(sig, tick)[2].key == cv[2].key, "déterministe")
local fsrc = read_src("script/team/front.lua")
check(fsrc:find("Sec.covers(f.site_blocked, tick)", 1, true) and fsrc:find("cover = cover, turrets", 1, true), "Front.view lit f.site_blocked")

---------------------------------------------------------------------------------------------------
section("5. Mutants")
---------------------------------------------------------------------------------------------------
local src = read_src("shared/ai3/projets.lua")
local function mutate(old, new)
  local i, j = src:find(old, 1, true)
  assert(i, "motif absent : " .. old)
  return src:sub(1, i - 1) .. new .. src:sub(j + 1)
end
local function signature(P)
  local out = {}
  local _, a = emit(P, 300, PF, ARMY); out[#out + 1] = iron_tasks(a)
  local _, b = emit(P, 120, PF, ARMY); out[#out + 1] = #b.tasks
  local _, c = emit(P, 120, PF, { kind = "army", target = 10, minimal = true }); out[#out + 1] = #c.tasks
  local _, d = emit(P, 120, PF, { kind = "stock", item = AMMO, n = 40, minimal_n = 0 }); out[#out + 1] = #d.tasks
  local _, e = emit(P, 120, PF, { kind = "stock", item = AMMO, n = 40, minimal_n = 20 }); out[#out + 1] = #e.tasks
  local _, f = emit(P, 300, PF, ARMY); out[#out + 1] = f.avail[IRON]
  return table.concat(out, ",")
end
local ref = signature(P0)
local muts = {
  { "la réserve n'est pas retirée", mutate("E.avail[P.IRON] = (E.avail[P.IRON] or 0) - keep\n  local a, b = fn()", "local a, b = fn()\n  E.avail[P.IRON] = (E.avail[P.IRON] or 0) - keep") },
  { "le fer n'est pas rendu", mutate("E.avail[P.IRON] = (E.avail[P.IRON] or 0) + keep\n  return a, b", "return a, b") },
  { "le minimal n'est pas exempté", mutate("if minimal or not (pri and pri.production_first) then return fn() end", "if not (pri and pri.production_first) then return fn() end") },
  { "l'armée ignore la priorité", mutate("return with_hold(E, g.minimal, function() return P.EMIT_army(E, proj, g, ctx) end)", "return P.EMIT_army(E, proj, g, ctx)") },
  { "le minimum des munitions est ignoré", mutate("local mini = pf and math.min(g.n or 0, g.minimal_n or 0) or 0", "local mini = 0") },
  { "les munitions ignorent la priorité", mutate("    return with_hold(E, false, function()\n      return P.want(E, proj, { { g.item, g.n } }, proj.prio, true, \"stock\") and \"ok\" or \"matiere\"\n    end)", "    return P.want(E, proj, { { g.item, g.n } }, proj.prio, true, \"stock\") and \"ok\" or \"matiere\"") },
}
for _, m in ipairs(muts) do
  local Pm = load_projets(m[2])
  check(signature(Pm) ~= ref, "mutant refusé : " .. m[1])
end

print(string.format("[INTEG-ECONOMIE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
