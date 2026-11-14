--[[
  Lot charbon-dim (14/11, P0) : DIMENSIONNEMENT NOMINAL du combustible. Lancement : lua5.2 tests/charbon_dim_test.lua
    1. règle pure (shared/team/bilan_charbon.lua) : Bc.dim (besoin à pleine puissance + Bc.MARGE, offre nominale), Bc.drill_nominal ;
    2. relevé en jeu (script/team/plafond_charbon.lua, Cap.read) sur un moteur simulé : un four VIDE et une foreuse SANS combustible comptent
       au besoin ; une foreuse du combustible arrêtée faute de combustible compte à l'offre ; une foreuse épuisée ne compte pas ; les
       puissances et le combustible sont lus aux PROTOTYPES (données changées : le besoin suit) ;
    3. décision (shared/team/planner.lua) : offre sous le besoin nominal -> agrandir l'avant-poste du combustible ; décision rendue dans
       plan.coal_dim ; offre suffisante -> rien ;
    4. branchement : la vue lit Cap.read, la pensée note la décision (Cap.note -> [FO-CHARBON-DIM]), le cerveau IA3 rend coal_dim.
]]
package.path = "./?.lua;" .. package.path
local ok, n = 0, 0
local function check(c, msg) n = n + 1; if c then ok = ok + 1 else print("ECHEC : " .. msg) end end
local function near(a, b) return math.abs(a - b) < 1e-9 end
local function read_src(p) local fh = assert(io.open(p, "rb")); local s = fh:read("*a"); fh:close(); return s end

local Bc = require("shared.team.bilan_charbon")
local S = { working = 1, no_fuel = 2, no_minable_resources = 3, disabled_by_script = 4, disabled_by_control_behavior = 5,
  waiting_for_space_in_destination = 6, no_power = 7, waiting_for_source_items = 8 }

-- 1. règle pure
check(Bc.MARGE == 1.3, "marge de 30 %")
local d = Bc.dim({ 90e3, 90e3, 150e3 }, { 0.25 }, 4e6)
check(near(d.raw, 330e3 / 4e6) and near(d.need, 330e3 / 4e6 * 1.3), "besoin = somme des puissances / valeur du combustible, + 30 %")
check(near(d.capacity, 0.25) and d.short == false, "0,25/s pour 0,107/s : offre suffisante")
local d2 = Bc.dim({ 90e3, 90e3, 90e3, 90e3, 90e3, 90e3, 90e3, 90e3, 90e3, 90e3 }, { 0.25 }, 4e6)
check(d2.short == true and Bc.room(d2), "10 fours (0,29/s avec marge) pour une foreuse (0,25/s) : agrandir")
check(Bc.dim({ 90e3 * 8 }, { 0.25 }, 4e6).short == false and Bc.dim({ 90e3 * 9 }, { 0.25 }, 4e6).short == true, "9 fours : 0,203/s au brut couvert, 0,263/s avec la marge : agrandir AVANT la pénurie")
check(Bc.dim({}, {}, 4e6).short == false, "rien de posé : rien à agrandir")
check(Bc.dim({ 1e6 }, {}, 0).need == 0, "combustible illisible : besoin 0 (pas de division par zéro)")
check(Bc.drill_nominal(S.working, S) and Bc.drill_nominal(S.no_fuel, S)
  and Bc.drill_nominal(S.waiting_for_space_in_destination, S), "foreuse posée (en marche, sans combustible, sortie pleine) : offre")
check(not Bc.drill_nominal(S.no_minable_resources, S) and not Bc.drill_nominal(S.disabled_by_script, S)
  and not Bc.drill_nominal(S.disabled_by_control_behavior, S) and not Bc.drill_nominal(nil, S), "épuisée, arrêtée, illisible : pas d'offre")
check(not Bc.drill_nominal(S.no_power, S), "foreuse électrique sans courant : pas d'offre (banc 1, emerald 26 min : 6,75/s posés, 0,75/s en marche)")
local line = Bc.line("amber", { need = 0.3, raw = 0.23, capacity = 0.25, n_consumers = 8, n_drills = 1, short = true }, 12, "agrandir avant-poste 3")
check(line:find("amber minute 12", 1, true) and line:find("besoin 0.300/s", 1, true) and line:find("offre 0.250/s (foreuses 1)", 1, true)
  and line:find("offre < besoin", 1, true) and line:find("decision agrandir avant-poste 3", 1, true), "ligne de journal : équipe, besoin, offre, décision")

-- 2. Cap.read sur un moteur simulé (noms de prototypes INVENTÉS : la règle ne lit que les prototypes)
local function run_cap(fuel_value, furnace_w)
  local logs = {}
  _G.log = function(s) logs[#logs + 1] = s end
  _G.defines = { entity_status = S }
  _G.game = { tick = 1000, item_prototypes = { ["coal"] = { fuel_category = "chem", fuel_value = fuel_value } } }
  local burner = { effectivity = 1, fuel_categories = { chem = true } }
  local fuel_res = { valid = true, prototype = { mineable_properties = { mining_time = 1, products = { { name = "coal" } } } } }
  local ore_res = { valid = true, prototype = { mineable_properties = { mining_time = 1, products = { { name = "x-ore" } } } } }
  local furnace_p = { max_energy_usage = furnace_w / 60, burner_prototype = burner }
  local drill_p = { max_energy_usage = 150e3 / 60, burner_prototype = burner, mining_speed = 0.25 }
  local ents = {
    { type = "furnace", status = S.waiting_for_source_items, prototype = furnace_p }, -- four VIDE
    { type = "furnace", status = S.no_fuel, prototype = furnace_p },                  -- four sans combustible
    { type = "mining-drill", status = S.no_fuel, prototype = drill_p, mining_target = fuel_res }, -- foreuse du combustible à sec de combustible
    { type = "mining-drill", status = S.working, prototype = drill_p, mining_target = fuel_res },
    { type = "mining-drill", status = S.no_minable_resources, prototype = drill_p, mining_target = fuel_res }, -- épuisée
    { type = "mining-drill", status = S.waiting_for_source_items, prototype = drill_p, mining_target = ore_res }, -- minerai, arrêtée
  }
  package.loaded["script.core.profiler"] = { fstart = function() end, fstop = function() end }
  package.loaded["script.team.registre_types"] = { list = function(_, _, types)
    local want, out = {}, {}
    for _, t in ipairs(types) do want[t] = true end
    for _, e in ipairs(ents) do if want[e.type] then out[#out + 1] = e end end
    return out
  end }
  package.loaded["shared.team.config"] = { fuel = "coal" }
  package.loaded["script.team.plafond_charbon"] = nil
  local Cap = require("script.team.plafond_charbon")
  package.loaded["shared.team.config"] = nil
  local f = { key = "amber", force = "amber" }
  local m = Cap.read(f, {})
  return m, Cap, f, logs
end
local m, Cap, f, logs = run_cap(4e6, 90e3)
-- besoin : 2 fours (90 kW) + 4 foreuses à brûleur (150 kW), toutes posées, à pleine puissance = 780 kW / 4 MJ * 1,3
check(m.n_consumers == 6 and near(m.raw, 780e3 / 4e6) and near(m.need, 780e3 / 4e6 * 1.3), "besoin nominal : 6 machines posées comptées, quel que soit leur état")
-- offre : 2 foreuses du combustible posées (la marche et celle à sec de combustible) ; l'épuisée exclue ; celle sur minerai exclue
check(m.n_drills == 2 and near(m.capacity, 0.5), "offre nominale : 2 foreuses du combustible (0,5/s)")
check(near(m.live_capacity, 0.25), "relevé d'avant : seule la foreuse en marche (0,25/s), gardé pour le journal")
check(near(m.live_need, (90e3 * 2 + 150e3 * 2) / 4e6), "relevé d'avant : fours (nominal s45) + foreuses en marche ou sans combustible seulement (0,12/s)")
check(f.coal_cap == m and m.tick == 1000, "mémo du relevé")
Cap.note(f, "offre suffisante", 1000)
check(#logs == 1 and logs[1]:find("[FO-CHARBON-DIM] amber", 1, true) and logs[1]:find("decision offre suffisante", 1, true), "Cap.note écrit [FO-CHARBON-DIM]")
Cap.note(f, "offre suffisante", 1600)
check(#logs == 1, "même décision avant Cap.LOG_EVERY : pas de ligne")
Cap.note(f, "agrandir avant-poste 3", 1700)
check(#logs == 2 and logs[2]:find("agrandir avant-poste 3", 1, true), "décision changée : une ligne")
local m2 = run_cap(8e6, 180e3)
check(near(m2.raw, (180e3 * 2 + 150e3 * 4) / 8e6), "données changées (four 180 kW, combustible 8 MJ) : le besoin suit les prototypes")

-- 3. décision du planificateur
package.loaded["shared.team.config"] = nil
local T = require("shared.team.config")
local Book = require("shared.team.book")
local Planner = require("shared.team.planner")
local Sc = require("shared.team.scale")
local book = Book.new(dofile("tests/fixtures/recipes.lua"))
local IRON = T.outposts.iron.product
local function view(cc)
  local v = {
    tech = 0, personality = "balanced", done = { coal = true, iron = true, copper = true, stone = true },
    deferred = {}, stock = { [IRON] = 600, coal = 500, stone = 500, ["copper-plate"] = 300, ["burner-mining-drill"] = 10, ["stone-furnace"] = 10, ["iron-chest"] = 6 },
    incoming = {}, pending = {}, sites = { coal = 1 }, smelters = 2, smelters_pending = 0, smelter_task = false, smelter_output = 0,
    smelter_fuel_low = false, smelter_coal = 0, turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 8, workers_max = 30,
    workers_idle = 0, threatened = false, open = {}, workers_wanted = 30, no_research = true, ladder = T.player_ladder,
    hq_turrets = T.defend_hq, defend_first = false, coal_cap = cc,
    outposts = { { id = 1, kind = "coal", drills = 4, full = false, turrets = 1, coal_needed = 0, fuel_low = false, output = 0, idle_ticks = 0,
      has_task = true, has_fortify = false } },
  }
  v.recruit_cost = Sc.recruit_cost(v.workers)
  return v
end
local function has_extend(plan)
  for _, t in ipairs(plan.tasks) do if t.key == "extend:1" or t.key == "build:coal" then return true end end
  return false
end
-- l'usine est À L'ARRÊT faute de combustible : la mesure d'avant voyait 0,08/s pour 0,25/s extraits (rien à faire) ; le nominal voit 0,25
-- foreuses posées pour 0,25 * 1,3 : agrandir
local short = Bc.dim({ 90e3, 90e3, 90e3, 90e3, 90e3, 90e3, 90e3, 90e3, 90e3, 90e3 }, { 0.25 }, 4e6)
local p1 = Planner.plan(view(short), book)
check(has_extend(p1) and p1.coal_dim == "agrandir avant-poste 1", "offre nominale sous le besoin : agrandir (" .. tostring(p1.coal_dim) .. ")")
local p0 = Planner.plan(view(Bc.dim({ 90e3 }, { 0.25 }, 4e6)), book)
check(not has_extend(p0) and p0.coal_dim == "offre suffisante", "offre suffisante : rien (" .. tostring(p0.coal_dim) .. ")")
local p2 = Planner.plan(view(nil), book)
check(p2.coal_dim == "sans releve", "sans relevé : décision nommée")

-- 4. branchement
local team_src = read_src("script/team/team.lua")
check(team_src:find("coal_cap = fsurface and Profiler.fwrap(\"view:5-cap\", Cap.read, f, fsurface) or nil", 1, true), "la vue lit Cap.read")
check(team_src:find("if plan.coal_dim then Cap.note(f, plan.coal_dim, tick) end", 1, true), "la pensée note la décision (Cap.note)")
check(read_src("shared/ai3/cerveau.lua"):find("coal_dim = base.coal_dim", 1, true), "le cerveau IA3 rend la décision du planificateur permanent")
check(read_src("script/team/migration_champ.lua"):find("if not Bc.room(cap) then", 1, true), "les bandes du combustible lisent le même plafond (liaisons)")

print(string.format("charbon-dim : %d/%d OK", ok, n))
if ok ~= n then os.exit(1) end
