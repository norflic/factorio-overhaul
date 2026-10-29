--[[
  Tests hors jeu du lot SITE-PROCHE (29/10) : R1 (agrandir l'avant-poste le plus PROCHE, jamais un lointain quand un site
  proche est libre), porte au build, R4 (le fond ne bâtit pas d'avant-poste d'un produit saturé).
  Usage, depuis la racine du mod :   lua5.2 tests/site_proche_test.lua

  Constat du DC (29/10, partie réelle, Emeraude : « ils vont vachement loin pour le charbon ») : extendable() rendait le
  PREMIER avant-poste du type, par identifiant, quelle que soit sa distance : le charbon s'agrandissait à 201 tuiles pendant
  qu'un gisement de 192 000 était libre à 45 (audit fo-logs/2026-10-29_VAGUE4/AUDIT4/site-charbon.md, mécanisme M1).

  Vérifie (purs, sans moteur) :
    1. R1 : plus proche d'abord ; sans distance dans la vue, l'ordre d'avant ; avant-poste lointain sauté si un site
       admissible est à moins de 0,6 × sa distance et 60 tuiles plus près (le projet BÂTIT alors) ;
    2. porte au build : tant qu'un avant-poste a des places libres, le projet agrandit ; plein ou au plafond : il bâtit ;
       aucun site admissible : « bloqué : site » ;
    3. R4 : le fond ne bâtit pas d'avant-poste d'un produit saturé (agrandir reste permis), ni ne compte ce build dans son
       potentiel ;
    4. mutants refusés.
]]

package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local P = require("shared.ai3.projets")
local Planner = require("shared.team.planner")
local V = require("shared.faction.valeur")
local Fond = require("shared.team.fond")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local KIND = T.OUTPOST_ORDER[1]
for _, k in ipairs(T.OUTPOST_ORDER) do if T.outposts[k].resource == "coal" then KIND = k end end
local SPEC = T.outposts[KIND]

local function d2(d) return d * d end

local function avail_for(kind)
  local a = {}
  for _, it in ipairs(Planner.outpost_items(kind)) do a[it[1]] = it[2] * 4 end
  return a
end

--- Une émission d'avant-poste sur une vue : rend (état, cause), la liste des tâches émises.
local function emit(view, kind)
  view.pending = view.pending or {}
  view.open = view.open or {}
  local E = P.context(avail_for(kind or KIND), nil, view)
  local proj = { id = 1, key = "extraction:" .. (kind or KIND), prio = 60 }
  local state, cause = P.EMIT.outpost(E, proj, { outpost = kind or KIND }, { tick = 1000 })
  return state, cause, E.tasks, E
end

local function op(id, d, o)
  o = o or {}
  local sq = d2(d)
  if o.nod2 then sq = nil end -- vue sans distance
  return { id = id, kind = KIND, drills = o.drills or 4, full = o.full or false, turrets = 0, d2 = sq }
end

local function task_of(tasks, kind_) for _, t in ipairs(tasks) do if t.kind == kind_ then return t end end end

---------------------------------------------------------------------------------------------------
section("R1 : l'agrandissement choisit le plus proche, et cède à un site proche libre")
local function scenario()
  local r = {}
  -- 1. Le plus ancien (id 1) est à 201 tuiles, le plus récent (id 2) à 45 : on agrandit le proche.
  do
    local st, _, tasks = emit({ outposts = { op(1, 201), op(2, 45) }, sites = {} })
    local t = task_of(tasks, "extend")
    r[1] = st == "ok" and t ~= nil and t.outpost == 2
  end
  -- 2. Un seul avant-poste, à 201 tuiles, et un site admissible libre à 45 : on BÂTIT au proche.
  do
    local st, _, tasks = emit({ outposts = { op(1, 201) }, sites = { [KIND] = 1 }, sites_near = { [KIND] = 45 } })
    r[2] = st == "ok" and task_of(tasks, "build") ~= nil and task_of(tasks, "extend") == nil
  end
  -- 3. Site connu à 130 tuiles seulement (> 0,6 × 201) : l'agrandissement lointain reste permis.
  do
    local st, _, tasks = emit({ outposts = { op(1, 201) }, sites = { [KIND] = 1 }, sites_near = { [KIND] = 130 } })
    local t = task_of(tasks, "extend")
    r[3] = st == "ok" and t ~= nil and t.outpost == 1
  end
  -- 4. Aucun site connu : on agrandit le lointain (rien d'autre à faire).
  do
    local st, _, tasks = emit({ outposts = { op(1, 201) }, sites = {}, sites_near = {} })
    local t = task_of(tasks, "extend")
    r[4] = st == "ok" and t ~= nil and t.outpost == 1
  end
  -- 5. Vue sans distance (équipe du joueur, bancs) : l'ordre d'avant (le premier de la vue).
  do
    local st, _, tasks = emit({ outposts = { op(7, 0, { nod2 = true }), op(3, 0, { nod2 = true }) }, sites = {} })
    local t = task_of(tasks, "extend")
    r[5] = st == "ok" and t ~= nil and t.outpost == 7
  end
  -- 6. Deux avant-postes, le proche déjà plein (son gisement : plus de plafond de foreuses depuis le lot PLAFOND-FOREUSES) : on
  -- agrandit le lointain (site proche absent).
  do
    local st, _, tasks = emit({ outposts = { op(1, 201), op(2, 45, { drills = 60, full = true }) }, sites = {} })
    local t = task_of(tasks, "extend")
    r[6] = st == "ok" and t ~= nil and t.outpost == 1
  end
  -- 7. Le proche est plein (full) et un site proche existe : on bâtit (ni agrandir le plein, ni le lointain refusé).
  do
    local st, _, tasks = emit({ outposts = { op(1, 201), op(2, 45, { full = true }) }, sites = { [KIND] = 1 },
      sites_near = { [KIND] = 30 } })
    r[7] = st == "ok" and task_of(tasks, "build") ~= nil
  end
  -- 8. Porte au build : un avant-poste avec des places libres ET aucun site : on agrandit, on ne bloque pas.
  do
    local st, cause = emit({ outposts = { op(1, 60) }, sites = {} })
    r[8] = st == "ok"
  end
  -- 9. Rien à agrandir, aucun site admissible : « bloqué : site ».
  do
    local st, cause = emit({ outposts = { op(1, 60, { full = true }) }, sites = { [KIND] = 0 }, sites_near = {} })
    r[9] = st == "bloque" and cause == "site:" .. KIND
  end
  -- 10. Plusieurs avant-postes à égalité de distance : le premier de la vue (déterminisme).
  do
    local st, _, tasks = emit({ outposts = { op(4, 80), op(9, 80) }, sites = {} })
    local t = task_of(tasks, "extend")
    r[10] = st == "ok" and t ~= nil and t.outpost == 4
  end
  -- 11. Le plus proche des trois (au milieu de la liste) est choisi.
  do
    local st, _, tasks = emit({ outposts = { op(1, 150), op(2, 90), op(3, 200) }, sites = {} })
    local t = task_of(tasks, "extend")
    r[11] = st == "ok" and t ~= nil and t.outpost == 2
  end
  -- 12. R1 saute SEULEMENT l'avant-poste concerné : le proche (60) n'est pas refusé par un site à 45 (écart < 60).
  do
    local st, _, tasks = emit({ outposts = { op(1, 201), op(2, 60) }, sites = { [KIND] = 1 }, sites_near = { [KIND] = 45 } })
    local t = task_of(tasks, "extend")
    r[12] = st == "ok" and t ~= nil and t.outpost == 2
  end
  return r
end
local res = scenario()
for i = 1, 12 do check(res[i] == true, "R1 / porte au build : cas " .. i) end

-- Mutants : chacun doit casser au moins un cas.
local function mutant(name, patch, restore)
  patch()
  local r = scenario()
  restore()
  local broken = false
  for i = 1, 12 do if r[i] ~= true then broken = true end end
  check(broken, "mutant refusé : " .. name)
end
local real_refused = V.extension_refused
mutant("R1 jamais refusé", function() V.extension_refused = function() return false end end,
  function() V.extension_refused = real_refused end)
mutant("R1 toujours refusé", function() V.extension_refused = function(_, s) return s ~= nil end end,
  function() V.extension_refused = real_refused end)
-- Le plus ancien d'abord (comportement d'avant) : rejoué en remplaçant le tri par distance par l'ordre de la vue.
do
  local real_emit = P.EMIT.outpost
  local function old_order(E, proj, g, ctx)
    local v = E.view
    local saved = {}
    for i, o in ipairs(v.outposts or {}) do saved[i] = o.d2; o.d2 = 0 end
    local a, b = real_emit(E, proj, g, ctx)
    for i, o in ipairs(v.outposts or {}) do o.d2 = saved[i] end
    return a, b
  end
  mutant("le plus ancien d'abord", function() P.EMIT.outpost = old_order end, function() P.EMIT.outpost = real_emit end)
end

---------------------------------------------------------------------------------------------------
section("R4 : le fond ne bâtit pas d'avant-poste d'un produit saturé")
local function free_all()
  local f = {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    for _, it in ipairs(Fond.pair_items(kind, Fond.PAIRS)) do f[it[1]] = (f[it[1]] or 0) + it[2] * 4 end
  end
  return f
end
local function build_keys(cands)
  local keys = {}
  for _, t in ipairs(cands.extraction or {}) do
    if t.kind == "build" then keys[#keys + 1] = t.key end
  end
  return keys
end
local function fond_scenario()
  local r = {}
  local view = { outposts = {}, sites = { [KIND] = 1 }, stock = {} }
  -- 1. Sans saturation : le fond bâtit.
  local c0 = Fond.candidates(view, free_all(), { keys = {} })
  r[1] = #build_keys(c0) >= 1
  -- 2. Produit saturé : plus de build de ce type.
  local c1 = Fond.candidates(view, free_all(), { keys = {}, saturated = { [SPEC.product] = true } })
  r[2] = #build_keys(c1) == 0
  -- 3. Un AUTRE produit saturé : le build reste.
  local c2 = Fond.candidates(view, free_all(), { keys = {}, saturated = { ["__autre__"] = true } })
  r[3] = #build_keys(c2) >= 1
  -- 4. Agrandir reste permis sur un produit saturé.
  local view4 = { outposts = { op(1, 60) }, sites = {}, stock = {} }
  local c3 = Fond.candidates(view4, free_all(), { keys = {}, saturated = { [SPEC.product] = true } })
  local ext = false
  for _, t in ipairs(c3.extraction or {}) do if t.kind == "extend" then ext = true end end
  r[4] = ext
  -- 5. Le potentiel (paires d'avance) ne compte pas ce build non plus.
  local p0 = Fond.potential(view, { keys = {} }, free_all())
  local p1 = Fond.potential(view, { keys = {}, saturated = { [SPEC.product] = true } }, free_all())
  r[5] = p0 > 0 and p1 == 0
  -- 6. Interface : F.saturated_build.
  r[6] = Fond.saturated_build({ saturated = { [SPEC.product] = true } }, KIND) == true
    and Fond.saturated_build({}, KIND) == false and Fond.saturated_build(nil, KIND) == false
  -- 7. R1 au fond : avant-poste à 201 tuiles, site admissible libre à 45 : pas d'agrandissement lointain, on bâtit.
  local view7 = { outposts = { op(1, 201) }, sites = { [KIND] = 1 }, sites_near = { [KIND] = 45 }, stock = {} }
  local c7 = Fond.candidates(view7, free_all(), { keys = {} })
  local ext7 = false
  for _, t in ipairs(c7.extraction or {}) do if t.kind == "extend" then ext7 = true end end
  r[7] = not ext7 and #build_keys(c7) >= 1
  -- 8. Même vue sans site proche connu : on agrandit le lointain, on ne bâtit pas.
  local view8 = { outposts = { op(1, 201) }, sites = { [KIND] = 1 }, sites_near = { [KIND] = 130 }, stock = {} }
  local c8 = Fond.candidates(view8, free_all(), { keys = {} })
  local ext8 = false
  for _, t in ipairs(c8.extraction or {}) do if t.kind == "extend" then ext8 = true end end
  r[8] = ext8 and #build_keys(c8) == 0
  -- 9. Prédicat F.far_from_site : vrai avec un site proche libre, faux à 130 tuiles ou sans site connu.
  r[9] = Fond.far_from_site(view7, view7.outposts[1]) == true and Fond.far_from_site(view8, view8.outposts[1]) == false
    and Fond.far_from_site({ outposts = {} }, view7.outposts[1]) == false
  return r
end
local fr = fond_scenario()
for i = 1, 9 do check(fr[i] == true, "R4 : cas " .. i) end
do
  local real = Fond.saturated_build
  Fond.saturated_build = function() return false end
  local m = fond_scenario()
  Fond.saturated_build = real
  local broken = false
  for i = 1, 6 do if m[i] ~= true then broken = true end end
  check(broken, "mutant refusé : R4 sans effet")
  local real_far = Fond.far_from_site
  Fond.far_from_site = function() return false end
  m = fond_scenario()
  Fond.far_from_site = real_far
  broken = false
  for i = 1, 9 do if m[i] ~= true then broken = true end end
  check(broken, "mutant refusé : R1 du fond sans effet")
  Fond.saturated_build = function() return true end
  m = fond_scenario()
  Fond.saturated_build = real
  broken = false
  for i = 1, 6 do if m[i] ~= true then broken = true end end
  check(broken, "mutant refusé : R4 qui bloque tout")
end

---------------------------------------------------------------------------------------------------
section("R1 dans le planificateur permanent (relecture) : l'agrandissement du charbon sous 1,4 x la consommation")
do
  local Book = require("shared.team.book")
  local S = require("shared.team.scale")
  local book = Book.new(dofile("tests/fixtures/recipes.lua"))
  local rich = { ["iron-plate"] = 3000, ["copper-plate"] = 1000, coal = 500, stone = 500, ["firearm-magazine"] = 60,
    ["burner-mining-drill"] = 20, ["stone-furnace"] = 20, ["iron-chest"] = 8 }
  local function pop(id, kind, drills, d)
    return { id = id, kind = kind, drills = drills, full = false, turrets = 0, coal_needed = 0, fuel_low = false, output = 0,
      idle_ticks = 0, has_task = true, has_fortify = false, d2 = d2(d) }
  end
  local function plan_of(outposts, over)
    local v = { tech = 0, personality = "balanced", done = { coal = true, iron = true, copper = true, stone = true },
      deferred = {}, stock = rich, incoming = {}, outposts = outposts, pending = {}, sites = {}, smelters = 2,
      smelters_pending = 0, smelter_task = false, smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0,
      turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 8, workers_max = 30, workers_idle = 0,
      threatened = false, open = {}, workers_wanted = 30, no_research = true, ladder = {}, hq_turrets = T.defend_hq }
    for k, x in pairs(over or {}) do v[k] = x end
    v.recruit_cost = S.recruit_cost(v.workers)
    return Planner.plan(v, book)
  end
  local function has(plan, key) for _, t in ipairs(plan.tasks) do if t.key == key then return true end end return false end
  -- Charbon : un seul avant-poste a 201 tuiles (4 foreuses), du fer a 20 foreuses brule plus que 1,4 fois le charbon rendu.
  local outs = { pop(1, "coal", 4, 201), pop(2, "iron", 20, 40) }
  outs[2].full = true
  local far = plan_of(outs, { sites = {}, sites_near = {} })
  check(has(far, "extend:1"), "planificateur : sans site proche connu, on agrandit le charbon lointain")
  local near = plan_of(outs, { sites = { coal = 1 }, sites_near = { coal = 45 } })
  check(not has(near, "extend:1") and has(near, "build:coal"),
    "planificateur : site de charbon admissible a 45 tuiles, on batit au proche au lieu d'agrandir a 201")
  local mid = plan_of(outs, { sites = { coal = 1 }, sites_near = { coal = 130 } })
  check(has(mid, "extend:1"), "planificateur : site a 130 tuiles (> 0,6 x 201), on agrandit comme avant")
  -- Le plus proche d'abord, aussi dans le planificateur.
  local two = { pop(1, "coal", 4, 201), pop(2, "coal", 4, 45), pop(3, "iron", 20, 40) }
  two[3].full = true
  check(has(plan_of(two, { sites = {} }), "extend:2"), "planificateur : deux avant-postes de charbon, le proche s'agrandit")
end

print(string.format("\n[SITE-PROCHE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
