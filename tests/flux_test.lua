--[[
  Lot FLUX : ce qui dort dans les sorties des avant-postes, le minage à la main alors que le stock couvre, le ravitaillement de ce
  qui produit (shared/team/flux.lua et ses lecteurs : planificateur, fond, tableau). Usage : lua5.2 tests/flux_test.lua
    §1 données : types vitaux et carte minerai -> plaque DÉDUITS de shared/team/config.lua (aucun nom dans la règle) ;
    §2 sorties comptées (meurtrier, tournée libre trop longtemps, tournées ratées) ; somme et ordre ;
    §3 minerai équivalent ; §4 priorité d'une tournée ; §5 vieillissement ; §6 produit saturé et sorties pleines ;
    §7 planificateur : tournée vitale à 96, sorties pleines à 88 quand le coffre manque ; plus de minage de plaque couverte par
       les sorties (objets attendus de la vue) ;
    §8 fond : le minage à la main de remplissage compte les plaques (coffre et sorties) ;
    §9 mutants : chaque règle cassée est vue par au moins un contrôle.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Fx = require("shared.team.flux")
local Planner = require("shared.team.planner")
local Book = require("shared.team.book")
local Fond = require("shared.team.fond")
local S = require("shared.team.scale")

local passes, failures = 0, 0
local current_mutant
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    print("  ECHEC" .. (current_mutant and (" [mutant " .. current_mutant .. "]") or "") .. " : " .. msg)
  end
end

local IRON, COPPER, COAL, STONE = T.outposts.iron, T.outposts.copper, T.outposts.coal, T.outposts.stone

--- Tous les contrôles qui voient les mutants (rejoués une fois par mutant, `mutants` ci-dessous).
local function suite()
  -- §1 données
  local vital = Fx.vital(T.outposts, T.fuel, T.smelter_inputs)
  check(vital.iron == "plate" and vital.copper == "plate" and vital.coal == "fuel" and not vital.stone,
    "vitaux : le fer et le cuivre (plaque), le charbon (combustible) ; pas la pierre")
  local map = Fx.plate_map(T.OUTPOST_ORDER, T.outposts, T.smelter_inputs)
  check(map[IRON.resource] and map[IRON.resource].plate == IRON.product and map[IRON.resource].ratio == T.smelter_inputs[IRON.product][2],
    "carte : le minerai de fer donne sa plaque")
  check(map[COPPER.resource] and not map[COAL.resource] and not map[STONE.resource], "carte : pas de plaque pour le charbon ni la pierre")

  -- §2 sorties comptées
  local rows = {
    { outputs = { [IRON.product] = 100, [COPPER.product] = 30 } },
    { outputs = { [IRON.product] = 50 }, free_age = Fx.STALE_TICKS - 1 },
    { outputs = { [IRON.product] = 400 }, lethal = true },
    { outputs = { [IRON.product] = 700 }, free_age = Fx.STALE_TICKS },
    { outputs = { [IRON.product] = 900 }, fails = Fx.FAILS_MAX },
    { outputs = { [IRON.product] = 20 }, fails = Fx.FAILS_MAX - 1 },
  }
  local repat, total = Fx.repatriable(rows)
  check(repat[IRON.product] == 170 and repat[COPPER.product] == 30 and total == 200,
    "comptées : 100 + 50 + 20 de fer, 30 de cuivre ; ni meurtrier, ni tournée libre depuis 5 min, ni 3 échecs de suite")
  check(select(2, Fx.repatriable({ { outputs = { [IRON.product] = 50 }, unsafe = true } })) == 0, "avant-poste dangereux : ses sorties ne sont pas comptées")
  local only = Fx.plates_of(map)
  check(only[IRON.product] and only[COPPER.product] and not only[COAL.product] and not only[STONE.product], "objets comptés : les plaques")
  local ro, to = Fx.repatriable({ { outputs = { [IRON.product] = 100, [COAL.product] = 900, [STONE.product] = 50 } } }, only)
  check(ro[IRON.product] == 100 and ro[COAL.product] == nil and ro[STONE.product] == nil and to == 100,
    "sorties : le charbon et la pierre d'un coffre d'avant-poste ne comptent pas comme objets attendus")
  local rn = Fx.repatriable({ { outputs = { [COAL.product] = 900 } } })
  check(rn[COAL.product] == 900, "sans filtre : tout compte (anciens appelants)")
  local r2 = Fx.repatriable({ { outputs = { x = 0, y = -3, z = "a" } } })
  check(next(r2) == nil, "zéro, négatif ou non numérique : rien")
  check(next((Fx.repatriable(nil))) == nil and select(2, Fx.repatriable({})) == 0, "aucune rangée : rien")

  -- §3 minerai équivalent
  local ore, plate = IRON.resource, IRON.product
  local ratio = map[ore].ratio
  check(Fx.equiv(ore, map, { [ore] = 40 }, {}) == 40, "minerai seul")
  check(Fx.equiv(ore, map, { [ore] = 40, [plate] = 300 }, {}) == 40 + 300 * ratio, "plus les plaques du coffre, en minerai")
  check(Fx.equiv(ore, map, { [ore] = 40 }, { [plate] = 100 }) == 40 + 100 * ratio, "plus les plaques des sorties")
  check(Fx.equiv(COAL.resource, map, { [COAL.resource] = 500, [plate] = 99 }, { [plate] = 99 }) == 500, "le charbon : son stock seul")
  check(Fx.equiv(ore, nil, { [ore] = 40, [plate] = 300 }, {}) == 40, "sans carte : le minerai seul (anciens appelants)")
  check(Fx.equiv(ore, map, { [ore] = -5, [plate] = -9 }, { [plate] = -1 }) == 0, "jamais négatif")

  -- §4 priorité d'une tournée
  check(Fx.service_prio(95, { fuel_low = true }, "fuel", 0) == Fx.VITAL_PRIO, "avant-poste de combustible à sec : 96")
  check(Fx.service_prio(95, { fuel_low = true }, "plate", 0) == 95, "avant-poste de plaque à sec : 95 (il vieillit)")
  check(Fx.service_prio(95, { fuel_low = true }, nil, 0) == 95, "avant-poste non vital à sec : 95 (inchangé)")
  check(Fx.service_prio(70, {}, "fuel", 0) == 70, "combustible sans manque de brûleur : 70")
  check(Fx.service_prio(70, { stuck = 2 }, "plate", Fx.COVER - 1) == Fx.AGE_CAP_STUCK, "sorties pleines, coffre qui manque du produit : 88")
  check(Fx.service_prio(70, { stuck = 2 }, "plate", Fx.COVER) == 70, "sorties pleines, coffre qui couvre : 70 (il vieillira)")
  check(Fx.service_prio(70, { stuck = 0 }, "plate", 0) == 70, "aucune sortie pleine : 70")
  check(Fx.service_prio(97, { fuel_low = true, stuck = 1 }, "fuel", 0) == 97, "jamais en dessous de la base")
  check(Fx.service_prio(95, { fuel_low = true, unsafe = true }, "fuel", 0) == 95 and Fx.service_prio(70, { stuck = 3, unsafe = true }, "plate", 0) == 70
    and Fx.service_prio(95, { fuel_low = true, lethal = true }, "fuel", 0) == 95, "avant-poste dangereux ou meurtrier : jamais d'urgence")

  -- §5 vieillissement
  check(Fx.aged(70, 0, nil) == 70 and Fx.aged(70, -5, nil) == 70 and Fx.aged(70, nil, nil) == 70, "pas d'attente : inchangée")
  check(Fx.aged(70, Fx.AGE_STEP * 3 + 1, nil) == 73, "+1 par pas")
  check(Fx.aged(70, Fx.AGE_STEP * 500, nil) == Fx.AGE_CAP, "plafonnée")
  check(Fx.aged(70, Fx.AGE_STEP * 500, { stuck = true }) >= Fx.AGE_CAP_STUCK, "sorties pleines : plafond plus haut")
  check(Fx.aged(85, 3, nil) == 85 and Fx.aged(Fx.AGE_CAP + 5, Fx.AGE_STEP * 9, nil) == Fx.AGE_CAP + 5, "jamais abaissée")
  check(Fx.aged(70, Fx.URGENT_AFTER - 1, { stuck = true }) < Fx.URGENT and Fx.aged(70, Fx.URGENT_AFTER, { stuck = true }) == Fx.URGENT,
    "sorties pleines : urgence après 3 min d'attente")
  check(Fx.aged(95, Fx.URGENT_AFTER, { dry = true }) >= Fx.URGENT and Fx.aged(95, 1, { dry = true }) == 95, "vital à sec : jamais sous 95")
  check(Fx.aged(70, Fx.URGENT_AFTER * 4, nil) < Fx.URGENT, "une tournée ordinaire ne devient jamais une urgence")
  check(Fx.aged(70, Fx.AGE_STEP * 99, { unsafe = true, stuck = true, dry = true }) == 70, "avant-poste dangereux : la tournée ne vieillit pas")
  check(Fx.aged(95, Fx.AGE_STEP * 99, { dry = true }) == Fx.AGE_CAP_DRY, "vital à sec : plafond 97")

  -- §6 produit saturé
  check(Fx.drop_service({ stuck = 0 }, true) == true and Fx.drop_service({}, true) == true, "saturé, sorties vides : tournée retirée")
  check(Fx.drop_service({ stuck = 1 }, true) == false, "saturé, une sortie pleine : tournée gardée")
  check(Fx.drop_service({ stuck = 1 }, false) == false and Fx.drop_service({}, false) == false, "pas retirée par la règle d'avant : gardée")
  check(Fx.stuck_count({ Fx.STUCK_AT, Fx.STUCK_AT - 1, 100, 0 }) == 2 and Fx.stuck_count(nil) == 0, "réceptacles pleins")

  -- §6 bis remplissage des brûleurs
  check(Fx.refill_to(0, 100, 10, 50) == 10 and Fx.refill_to(1500, 100, 10, 50) == 10, "coffre pauvre : le niveau de base")
  check(Fx.refill_to(5700, 111, 10, 50) == 25, "5700 charbons, 111 brûleurs : 25 (la moitié du coffre)")
  check(Fx.refill_to(1000000, 111, 10, 50) == 50, "coffre immense : la pile, 50")
  check(Fx.refill_to(5000, 0, 10, 50) == 10 and Fx.refill_to(5000, nil, 10, 50) == 10, "aucun brûleur : le niveau de base")
  check(Fx.refill_to(-5, 10, 10, 50) == 10 and Fx.refill_to(nil, 10, 10, 50) == 10, "coffre négatif ou inconnu : le niveau de base")
  check(Fx.refill_to(5000, 10, 10, nil) == 10 and Fx.refill_to(5000, 10, nil, nil) == 10, "sans maximum : jamais au-dessus de la base")
  check(Fx.refill_to(900, 10, 10, 50) == 45, "rond vers le bas : 900 / 20 = 45")

  -- §7 planificateur
  local book = Book.new(dofile("tests/fixtures/recipes.lua"))
  local cost = S.recruit_cost(8)
  local function view(over)
    local v = {
      tech = 0, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {},
      outposts = {}, pending = {}, sites = {}, smelters = 0, smelters_pending = 0, smelter_task = false,
      smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0, turret_groups = {},
      soldiers = 0, soldiers_max = 100, workers = 10, workers_max = 30, workers_idle = 0, threatened = false, open = {},
      workers_wanted = 30, recruit_cost = cost, recover_floor = 8, no_research = true,
    }
    for k, x in pairs(over or {}) do v[k] = x end
    return v
  end
  local function op(id, kind, over)
    local o = { id = id, kind = kind, drills = 2, full = false, turrets = 0, coal_needed = 0, fuel_low = false, output = 0,
      idle_ticks = 0, has_task = false, has_fortify = false, d2 = 100 }
    for k, x in pairs(over or {}) do o[k] = x end
    return o
  end
  local function service(plan, id)
    for _, t in ipairs(plan.tasks) do if t.kind == "service" and t.outpost == id then return t end end
    return nil
  end
  local p1 = Planner.plan(view({ outposts = { op(1, "iron", { fuel_low = true }), op(2, "stone", { fuel_low = true }),
    op(3, "iron", { output = 90, stuck = 1 }), op(4, "copper", { output = 90 }) } }), book)
  check(service(p1, 1) and service(p1, 1).prio == 95, "planificateur : le fer à sec reste à 95 (il vieillit au tableau)")
  check(service(p1, 2) and service(p1, 2).prio == 95, "planificateur : la pierre à sec reste à 95")
  local p1c = Planner.plan(view({ outposts = { op(7, "coal", { fuel_low = true }) } }), book)
  check(service(p1c, 7) and service(p1c, 7).prio == Fx.VITAL_PRIO, "planificateur : le charbon à sec passe à 96")
  check(service(p1, 3) and service(p1, 3).prio == Fx.AGE_CAP_STUCK, "planificateur : sorties pleines, coffre vide : 88")
  check(service(p1, 4) and service(p1, 4).prio == 70, "planificateur : sorties sans four plein : 70")
  local p2 = Planner.plan(view({ stock = { [IRON.product] = 5000 }, outposts = { op(3, "iron", { output = 90, stuck = 1 }) } }), book)
  check(service(p2, 3) and service(p2, 3).prio == 70, "planificateur : coffre qui couvre le produit : 70")

  -- le minage d'un minerai dont la plaque dort dans les sorties : le manque de plaques ne le demande plus (objets attendus)
  local goal_view = function(incoming)
    return view({ smelters = 2, stock = { ["iron-ore"] = 0 }, incoming = incoming, no_research = false,
      workers_idle = 4, done = {}, outposts = {} })
  end
  local function mine_tasks(plan)
    local n = 0
    for _, t in ipairs(plan.tasks) do if t.kind == "mine" and t.resource == IRON.resource then n = n + 1 end end
    return n
  end
  local m0 = Planner.plan(goal_view({}), book)
  local m1 = Planner.plan(goal_view({ [IRON.product] = 100000 }), book)
  check(mine_tasks(m1) == 0, "planificateur : des plaques attendues en quantité : aucun minage de leur minerai")
  check(mine_tasks(m0) >= 0, "planificateur : (témoin) la même vue sans objets attendus se calcule")

  -- §8 fond
  local function fview() return { outposts = {}, sites = {}, smelters = 2, stock = {}, incoming = {} } end
  local function fmines(c, res)
    local n = 0
    for _, t in ipairs(c.extraction) do if t.kind == "mine" and t.resource == res then n = n + 1 end end
    return n
  end
  local fctx = function(extra)
    local c = { keys = {}, mine_left = 4, plate_map = map }
    for k, x in pairs(extra or {}) do c[k] = x end
    return c
  end
  local target
  for _, m in ipairs(Fond.MINE_TARGETS) do if m[1] == ore then target = m[2] end end
  check(target ~= nil, "le fond a une cible de minerai de fer")
  check(fmines(Fond.candidates(fview(), {}, fctx()), ore) > 0, "fond : rien au coffre, rien dans les sorties : il mine")
  check(fmines(Fond.candidates(fview(), { [plate] = target * 5 }, fctx()), ore) == 0, "fond : le coffre a des plaques : il ne mine pas")
  check(fmines(Fond.candidates(fview(), {}, fctx({ repat = { [plate] = target * 5 } })), ore) == 0, "fond : les sorties ont des plaques : il ne mine pas")
  check(fmines(Fond.candidates(fview(), {}, fctx({ repat = { [plate] = 1 } })), ore) > 0, "fond : une plaque dans les sorties ne suffit pas")
  check(fmines(Fond.candidates(fview(), { [plate] = target * 5 }, { keys = {}, mine_left = 4 }), ore) > 0,
    "fond : sans carte, la règle d'avant (le minerai seul)")
end

suite()

-- §9 mutants : la règle est cassée à la main, au moins un contrôle doit échouer.
local MUTANTS = {
  { "stale-ignore", function() Fx.counted = function(o) return not o.lethal and (o.fails or 0) < Fx.FAILS_MAX end end },
  { "lethal-ignore", function() Fx.counted = function(o) return (o.free_age or 0) < Fx.STALE_TICKS and (o.fails or 0) < Fx.FAILS_MAX end end },
  { "fails-ignore", function() Fx.counted = function(o) return not o.lethal and (o.free_age or 0) < Fx.STALE_TICKS end end },
  { "repat-all-items", function()
      local o = Fx.repatriable
      Fx.repatriable = function(rows) return o(rows, nil) end
    end },
  { "equiv-plates-off", function() Fx.equiv = function(res, _, stock) return math.max(0, (stock and stock[res]) or 0) end end },
  { "equiv-repat-off", function()
      local orig = Fx.equiv
      Fx.equiv = function(res, map, stock, _) return orig(res, map, stock, nil) end
    end },
  { "vital-prio-off", function() local o = Fx.service_prio; Fx.service_prio = function(b, r, v, h) return o(b, r, nil, h) end end },
  { "vital-prio-all", function() local o = Fx.service_prio; Fx.service_prio = function(b, r, v, h) return o(b, r, v and "fuel", h) end end },
  { "stuck-prio-off", function() local o = Fx.service_prio; Fx.service_prio = function(b, r, v, h) return o(b, { fuel_low = r.fuel_low }, v, h) end end },
  { "stuck-cover-ignored", function()
      Fx.service_prio = function(b, o, v, _) local p = b; if v and o.fuel_low then p = math.max(p, Fx.VITAL_PRIO) end
        if (o.stuck or 0) > 0 then p = math.max(p, Fx.AGE_CAP_STUCK) end return p end
    end },
  { "unsafe-ignored", function()
      local oa, os_, oc = Fx.aged, Fx.service_prio, Fx.counted
      Fx.aged = function(p, w, k) k = k or {}; return oa(p, w, { stuck = k.stuck, dry = k.dry }) end
      Fx.service_prio = function(b, o, v, h) return os_(b, { fuel_low = o.fuel_low, stuck = o.stuck }, v, h) end
      Fx.counted = function(o) return oc({ lethal = o.lethal, free_age = o.free_age, fails = o.fails }) end
    end },
  { "aged-never", function() Fx.aged = function(p) return p end end },
  { "aged-uncapped", function() Fx.aged = function(p, w) return p + math.floor((w or 0) / Fx.AGE_STEP) end end },
  { "aged-no-urgent", function()
      Fx.aged = function(p, w, k) local cap = (k and k.stuck) and Fx.AGE_CAP_STUCK or Fx.AGE_CAP
        return math.min(cap, p + math.floor((w or 0) / Fx.AGE_STEP)) end
    end },
  { "drop-always", function() Fx.drop_service = function(_, dropped) return dropped end end },
  { "refill-ignores-coal", function() Fx.refill_to = function(_, _, base) return base or 10 end end },
  { "refill-uncapped", function() Fx.refill_to = function(c, b, base) return math.max(base or 10, math.floor((c or 0) / (2 * math.max(1, b or 1)))) end end },
  { "refill-all-coal", function() Fx.refill_to = function(c, b, base, max) return math.max(base or 10, math.min(max or 10, math.floor((c or 0) / math.max(1, b or 1)))) end end },
  { "vital-all", function()
      Fx.vital = function(spec) local out = {} for k in pairs(spec) do out[k] = "fuel" end return out end
    end },
}
-- Chaque mutant est rejoué sur le module rechargé (les lecteurs ont gardé leurs références : on recharge tout).
local function fresh_modules()
  for _, name in ipairs({ "shared.team.flux", "shared.team.planner", "shared.team.fond" }) do package.loaded[name] = nil end
  Fx = require("shared.team.flux")
  Planner = require("shared.team.planner")
  Fond = require("shared.team.fond")
end
local killed = 0
local base_failures = failures
for _, m in ipairs(MUTANTS) do
  fresh_modules()
  m[2]()
  -- les lecteurs (planificateur, fond) ont été rechargés AVANT le mutant : on les recharge APRÈS pour qu'ils lisent le module cassé
  for _, name in ipairs({ "shared.team.planner", "shared.team.fond" }) do package.loaded[name] = nil end
  local broken = Fx
  package.loaded["shared.team.flux"] = broken
  Planner = require("shared.team.planner")
  Fond = require("shared.team.fond")
  local before, pbefore = failures, passes
  current_mutant = m[1]
  local saved_print = print
  print = function() end
  local ok, err = pcall(suite)
  print = saved_print
  current_mutant = nil
  local detected = (failures > before) or not ok
  if detected then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. m[1]) end
  failures, passes = before, pbefore -- les contrôles d'un mutant ne comptent pas dans le bilan du banc
  if not detected then failures = failures + 1 end
end
fresh_modules()
print(string.format("[FLUX] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
