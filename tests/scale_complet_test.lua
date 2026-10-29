--[[
  Tests hors jeu du lot SCALE-COMPLET (29/10, retour du DC en jouant la 0.6.18, fo-logs/2026-10-29_RETOUR/RETOUR_DC_6_0.6.18.md) :
  « Le cuivre, ils l'ont pas ils ont pas pris tout le gisement alors qu'ils auraient pu. Le fer pareil » ; « Ils ont fait un
  avant-poste alors qu'il y en a pas besoin en vérité puisque bah c'est il y en a à côté ».
  Usage, depuis la racine du mod :   lua5.2 tests/scale_complet_test.lua

  Situation reconstruite d'après le journal de la partie (Écarlate, 46 min) : cuivre et charbon « saturés » (plus aucun but
  d'extraction), cuivre à 6 foreuses sur 197 tuiles, charbon de départ à 42 tuiles couvert à 243 pour mille, un avant-poste de
  charbon n° 5 bâti par le fond à 157 tuiles vers 27 min.

  Vérifie (purs, sans moteur) :
    1. V.room_distance et V.build_refused (R1 retournée) ;
    2. le fond ne bâtit pas d'avant-poste lointain tant qu'un avant-poste proche du type a des places (même dangereux), le
       note dans ctx.far_builds, et ne compte pas ce build dans son potentiel ; il bâtit quand le proche est plein ou quand le
       site est proche ;
    3. le projet d'extraction (EMIT.outpost) ne bâtissait déjà jamais au loin tant qu'un avant-poste a des places (vérifié) ;
    4. B.generate : but de COUVERTURE d'un type saturé dont un avant-poste a des places (fond, extend_only) ; jamais pour
       votre équipe, un type optionnel, un type sans place, un type qui a déjà un but d'extraction ; attend tant que le
       combustible manque (sauf le combustible lui-même) ; take_only quand le produit est saturé et qu'une autre matière manque ;
    5. EMIT.outpost d'un but de couverture : agrandit le plus proche, ne bâtit jamais, take_only ne fait rien fabriquer ;
    6. la pensée entière (C.think) sur la situation d'Écarlate : le cuivre saturé est agrandi, aucun build lointain ;
    7. mutants refusés.
]]

package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local V = require("shared.faction.valeur")
local Fond = require("shared.team.fond")
local P = require("shared.ai3.projets")
local B = require("shared.ai3.buts")
local C = require("shared.ai3.cerveau")
local Planner = require("shared.team.planner")
local Book = require("shared.team.book")
local S = require("shared.team.scale")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end

-- Types lus dans la configuration (aucun nom en dur dans les décisions ; ici, seulement pour retrouver les types).
local KIND_OF = {}
for _, k in ipairs(T.OUTPOST_ORDER) do KIND_OF[T.outposts[k].resource] = k end
local COAL, IRON, COPPER, STONE = KIND_OF["coal"], KIND_OF["iron-ore"], KIND_OF["copper-ore"], KIND_OF["stone"]
local function d2(d) return d * d end
local function op(id, kind, d, over)
  local o = { id = id, kind = kind, drills = 4, full = false, turrets = 1, coal_needed = 0, fuel_low = false, output = 0,
    idle_ticks = 0, has_task = false, has_fortify = false, d2 = d and d2(d) or nil }
  for k, x in pairs(over or {}) do o[k] = x end
  return o
end
local function free_all()
  local f = {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    for _, it in ipairs(Fond.pair_items(kind, Fond.PAIRS)) do f[it[1]] = (f[it[1]] or 0) + it[2] * 4 end
  end
  return f
end
local function tasks_of(list, kind_, okind)
  local out = {}
  for _, t in ipairs(list or {}) do if t.kind == kind_ and (okind == nil or t.outpost_kind == okind) then out[#out + 1] = t end end
  return out
end

---------------------------------------------------------------------------------------------------
section("1. V.room_distance et V.build_refused")
do
  local outs = { op(1, COAL, 157), op(2, COAL, 42), op(3, IRON, 20), op(4, COAL, 30, { full = true }),
    op(5, COAL, 10, { drills = T.max_drills(COAL) }) }
  check(math.abs(V.room_distance(outs, COAL, T.max_drills(COAL)) - 42) < 1e-9, "le plus proche avec des places (42), ni plein ni au plafond")
  check(V.room_distance(outs, STONE, T.max_drills(STONE)) == nil, "aucun avant-poste du type : nil")
  check(V.room_distance({ op(1, COAL, nil) }, COAL, 12) == nil, "sans distance dans la vue : ne compte pas")
  check(V.build_refused(42, 157) == true, "Écarlate : avant-poste à 42, site à 157 : build refusé")
  check(V.build_refused(42, 90) == false, "site à 90 (> 0,6 × 90 = 54 > 42 mais écart 48 < 60) : permis")
  check(V.build_refused(100, 150) == false, "site à 150, avant-poste à 100 (> 0,6 × 150) : permis")
  check(V.build_refused(nil, 157) == false and V.build_refused(42, nil) == false, "sans l'une des distances : permis")
  -- Cohérence avec R1 : jamais les deux refus à la fois.
  local contra = false
  for a = 0, 400, 7 do for b = 0, 400, 11 do
    if V.build_refused(a, b) and V.extension_refused(a, b) then contra = true end
  end end
  check(not contra, "R1 (agrandissement lointain) et R1 retournée (build lointain) ne refusent jamais ensemble")
end

---------------------------------------------------------------------------------------------------
section("2. Le fond : pas de build lointain tant qu'un avant-poste proche a des places")
do
  -- 2.1 Situation d'Écarlate après le lot PLAFOND-FOREUSES : charbon proche à 42 tuiles, pas plein, mais DANGEREUX (nids à
  -- moins de 40 tuiles : le fond ne l'agrandit pas) ; site admissible le plus proche à 157 tuiles.
  local view = { outposts = { op(2, COAL, 42, { drills = 8 }) }, sites = { [COAL] = 1 }, sites_near = { [COAL] = 157 }, stock = {} }
  local ctx = { keys = {}, danger = { [2] = true } }
  local c = Fond.candidates(view, free_all(), ctx)
  check(#tasks_of(c.extraction, "build", COAL) == 0, "2.1 avant-poste proche dangereux, site à 157 : aucun build lointain")
  check(#tasks_of(c.extraction, "extend") == 0, "2.1 … et le fond n'agrandit pas l'avant-poste dangereux (inchangé)")
  check(ctx.far_builds ~= nil and #ctx.far_builds == 1 and ctx.far_builds[1].kind == COAL
    and math.floor(ctx.far_builds[1].d_room) == 42 and ctx.far_builds[1].d_site == 157, "2.1 refus noté dans ctx.far_builds (journal [FO-LOIN])")
  check(Fond.potential(view, { keys = {}, danger = { [2] = true } }, free_all()) == 0, "2.1 potentiel : ce build ne compte pas")
  -- 2.2 Avant-poste proche plein (couverture atteinte) : le fond bâtit au site suivant, même lointain.
  local view2 = { outposts = { op(2, COAL, 42, { full = true }) }, sites = { [COAL] = 1 }, sites_near = { [COAL] = 157 }, stock = {} }
  local c2 = Fond.candidates(view2, free_all(), { keys = {} })
  check(#tasks_of(c2.extraction, "build", COAL) == 1, "2.2 proche plein : le fond bâtit")
  -- 2.3 Site proche (60 tuiles) : le build reste permis.
  local view3 = { outposts = { op(2, COAL, 42, { drills = 8 }) }, sites = { [COAL] = 1 }, sites_near = { [COAL] = 60 }, stock = {} }
  local ctx3 = { keys = {}, danger = { [2] = true } }
  local c3 = Fond.candidates(view3, free_all(), ctx3)
  check(#tasks_of(c3.extraction, "build", COAL) == 1 and ctx3.far_builds == nil, "2.3 site proche : build permis, rien noté")
  -- 2.4 Avant-poste proche sûr avec des places : on l'agrandit (inchangé), pas de build.
  local c4 = Fond.candidates(view, free_all(), { keys = {} })
  check(#tasks_of(c4.extraction, "extend") == 1 and #tasks_of(c4.extraction, "build", COAL) == 0, "2.4 proche sûr : agrandi, pas de build")
  -- 2.5 Votre équipe (aucun sites_near) : rien ne change.
  local view5 = { outposts = { op(2, COAL, 42, { drills = 8 }) }, sites = { [COAL] = 1 }, stock = {} }
  local c5 = Fond.candidates(view5, free_all(), { keys = {}, danger = { [2] = true } })
  check(#tasks_of(c5.extraction, "build", COAL) == 1, "2.5 sans sites_near (votre équipe) : comportement d'avant")
end

---------------------------------------------------------------------------------------------------
section("3. Le projet d'extraction : jamais de build lointain quand le proche a des places (déjà vrai)")
local function emit(view, goal, avail)
  view.pending = view.pending or {}
  view.open = view.open or {}
  local a = avail
  if not a then
    a = {}
    for _, it in ipairs(Planner.outpost_items(goal.outpost)) do a[it[1]] = it[2] * 4 end
  end
  local book = Book.new(dofile("tests/fixtures/recipes.lua"))
  local E = P.context(a, book, view)
  local proj = { id = 1, key = goal.key or ("extraction:" .. goal.outpost), prio = 60 }
  local st, cause = P.EMIT.outpost(E, proj, goal, { tick = 1000 })
  return st, cause, E
end
do
  -- Le projet ne bâtit qu'une fois l'agrandissement impossible : il agrandit le proche (le danger du fond n'est pas lu ici) ou
  -- attend ses tourelles ; un build n'arrive que si le proche est plein ou écarté par R1 (site proche). La règle retournée n'y
  -- a donc rien à refuser (vérifié ici, pour qu'un changement futur ne la rende pas nécessaire en silence).
  -- 3.1 Proche dangereux (le fond ne l'agrandit pas) : le projet l'agrandit.
  local view = { outposts = { op(2, COAL, 42, { drills = 8 }) }, sites = { [COAL] = 1 }, sites_near = { [COAL] = 157 } }
  local st, _, E = emit(view, { outpost = COAL })
  check(st == "ok" and #tasks_of(E.tasks, "extend") == 1 and #tasks_of(E.tasks, "build") == 0, "3.1 projet : le proche est agrandi, aucun build")
  -- 3.2 Proche non défendu et meurtrier, aucune tourelle possible (défendre d'abord) : le projet attend, aucun build.
  local view2 = { outposts = { op(2, COAL, 42, { drills = 8, turrets = 0, lethal = true }) }, sites = { [COAL] = 1 },
    sites_near = { [COAL] = 157 }, defend_first = true }
  local st2, cause2, E2 = emit(view2, { outpost = COAL })
  check(#tasks_of(E2.tasks, "build") == 0 and #tasks_of(E2.tasks, "extend") == 0, "3.2 projet : proche meurtrier, il attend (" .. tostring(st2) .. ", " .. tostring(cause2) .. ")")
  -- 3.3 Proche plein : on bâtit au loin (la couverture est faite).
  local view3 = { outposts = { op(2, COAL, 42, { full = true }) }, sites = { [COAL] = 1 }, sites_near = { [COAL] = 157 } }
  local st3, _, E3 = emit(view3, { outpost = COAL })
  check(st3 == "ok" and #tasks_of(E3.tasks, "build") == 1, "3.3 proche plein : build lointain permis")
end

---------------------------------------------------------------------------------------------------
section("4. B.generate : buts de couverture")
local function sit(over)
  local s = { is_player = false, workers = 8, soldiers = 10, soldiers_max = 30, stock = {}, cap = {}, pending = {}, sites = {},
    room = {}, smelters = 4, smelters_pending = 0, weights = {}, need = {}, at_war = false, key = nil, tick = 0 }
  for k, x in pairs(over or {}) do s[k] = x end
  return s
end
local function goal(goals, key) for _, g in ipairs(goals) do if g.key == key then return g end end end
local SAT = { ["copper-plate"] = 100000, coal = 100000, ["iron-plate"] = 100000, stone = 100000 }
local function cap_all(n) local c = {} for _, k in ipairs(T.OUTPOST_ORDER) do c[k] = n end return c end
local function stD() return { targets = { [COAL] = 2, [IRON] = 2, [COPPER] = 1, [STONE] = 1 }, iron2_set = true, short = {}, short_n = {} } end
do
  -- 4.1 Écarlate : tout saturé, cuivre et charbon avec des places : couverture du cuivre et du charbon, rien d'autre.
  local s = sit({ stock = SAT, cap = cap_all(2), room = { [COPPER] = true, [COAL] = true } })
  local g = B.generate(s, stD())
  local gc, gk = goal(g, "couverture:" .. COPPER), goal(g, "couverture:" .. COAL)
  check(gc ~= nil and gc.fond and gc.extend_only and gc.kind == "outpost" and gc.outpost == COPPER and gc.family == "extraction",
    "4.1 cuivre saturé avec des places : but de couverture de fond, agrandir seulement")
  check(gk ~= nil, "4.1 charbon saturé avec des places : but de couverture")
  check(goal(g, "extraction:" .. COPPER) == nil, "4.1 aucun but d'extraction (saturé, inchangé)")
  check(goal(g, "couverture:" .. IRON) == nil, "4.1 fer sans place : aucun but de couverture")
  check(gc.value >= 35 and gc.value <= 50, "4.1 valeur dans la bande de la capitalisation (35 à 50) : " .. tostring(gc.value))
  check(not gc.take_only, "4.1 aucune autre matière ne manque : la couverture fait fabriquer ce qui lui manque")
  -- 4.2 Une autre matière manque (st.other_short) : produit saturé -> take_only.
  local st2 = stD()
  st2.other_short = true
  local g2 = B.generate(s, st2)
  check(goal(g2, "couverture:" .. COPPER) and goal(g2, "couverture:" .. COPPER).take_only == true,
    "4.2 cuivre saturé pendant qu'une autre matière manque : take_only")
  -- 4.3 Le combustible MANQUE : le cuivre attend, le charbon est couvert.
  local st3 = stD()
  st3.short = { [T.outposts[COAL].product] = 40 }
  local g3 = B.generate(s, st3)
  check(goal(g3, "couverture:" .. COPPER) == nil and goal(g3, "couverture:" .. COAL) ~= nil,
    "4.3 combustible en manque : le cuivre (brûleurs) attend, le charbon se couvre")
  -- 4.4 Votre équipe : jamais.
  local g4 = B.generate(sit({ is_player = true, stock = SAT, cap = cap_all(2), room = { [COPPER] = true } }), stD())
  check(goal(g4, "couverture:" .. COPPER) == nil, "4.4 votre équipe : aucun but de couverture")
  -- 4.5 Type optionnel (sans besoin au dépliage) : jamais.
  local key = { top = IRON, fuel = COAL, order = { IRON, COPPER, STONE }, optional = { [STONE] = true } }
  local g5 = B.generate(sit({ stock = SAT, cap = cap_all(2), room = { [STONE] = true }, key = key }), stD())
  check(goal(g5, "couverture:" .. STONE) == nil, "4.5 type optionnel : aucun but de couverture")
  local key6 = { top = IRON, fuel = COAL, order = { IRON, COPPER, STONE }, optional = {} }
  local g6 = B.generate(sit({ stock = SAT, cap = cap_all(2), room = { [STONE] = true }, key = key6 }), stD())
  check(goal(g6, "couverture:" .. STONE) ~= nil, "4.5 le même type utile : but de couverture")
  -- 4.6 Un but d'extraction existe pour le type (non saturé, capacité sous la cible) : pas de doublon.
  local s7 = sit({ stock = {}, cap = { [COAL] = 2, [IRON] = 0.5, [COPPER] = 1, [STONE] = 1 }, room = { [IRON] = true } })
  local g7 = B.generate(s7, stD())
  check(goal(g7, "extraction:" .. IRON) ~= nil and goal(g7, "couverture:" .. IRON) == nil, "4.6 extraction présente : pas de couverture en double")
  -- 4.7 Déterminisme : deux appels identiques, mêmes buts dans le même ordre.
  local a, b = B.generate(s, stD()), B.generate(s, stD())
  local same = #a == #b
  for i = 1, math.min(#a, #b) do if a[i].key ~= b[i].key or a[i].value ~= b[i].value then same = false end end
  check(same, "4.7 déterminisme")
end

---------------------------------------------------------------------------------------------------
section("5. EMIT.outpost d'un but de couverture")
do
  local gC = { key = "couverture:" .. COPPER, outpost = COPPER, extend_only = true, fond = true }
  -- 5.1 Deux avant-postes de cuivre avec des places : le plus proche est agrandi.
  local view = { outposts = { op(7, COPPER, 120, { drills = 3 }), op(1, COPPER, 47, { drills = 6 }) }, sites = { [COPPER] = 1 },
    sites_near = { [COPPER] = 160 }, defend_first = false }
  local st, _, E = emit(view, gC)
  local ext = tasks_of(E.tasks, "extend")
  check(st == "ok" and #ext == 1 and ext[1].outpost == 1, "5.1 agrandit le plus proche (47 tuiles)")
  -- 5.2 Aucun avant-poste agrandissable (plein) mais un site : jamais de build, bloqué « couverture ».
  local view2 = { outposts = { op(1, COPPER, 47, { full = true }) }, sites = { [COPPER] = 1 }, sites_near = { [COPPER] = 50 } }
  local st2, cause2, E2 = emit(view2, gC)
  check(st2 == "bloque" and cause2 == "couverture:" .. COPPER and #E2.tasks == 0, "5.2 jamais de build ni d'exploration")
  -- 5.3 take_only sans les objets : rien n'est fabriqué ni demandé.
  local gT = { key = "couverture:" .. COPPER, outpost = COPPER, extend_only = true, fond = true, take_only = true }
  local st3, _, E3 = emit(view, gT, { ["iron-plate"] = 500, stone = 500 })
  check(st3 == "matiere" and #E3.tasks == 0 and next(E3.raw) == nil, "5.3 take_only : aucune fabrication, aucun manque")
  -- 5.4 Sans take_only, mêmes objets absents : les foreuses se fabriquent.
  local st4, _, E4 = emit(view, gC, { ["iron-plate"] = 500, stone = 500, coal = 500 })
  check(st4 == "matiere" and #tasks_of(E4.tasks, "craft") > 0, "5.4 sans take_only : fabrication des foreuses et des fours")
end

---------------------------------------------------------------------------------------------------
section("6. La pensée entière (C.think) : situation d'Écarlate à 46 min")
local recipes = dofile("tests/fixtures/recipes.lua")
local book = Book.new(recipes)
local function fview(over)
  local v = {
    tech = 0, personality = "balanced", done = {}, deferred = {}, incoming = {}, pending = {}, smelter_task = false,
    smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0, turret_groups = {}, soldiers = 13, soldiers_max = 30,
    workers = 8, workers_max = 30, workers_idle = 2, threatened = false, open = {}, workers_wanted = 8, no_research = true,
    ladder = T.ladder, hq_turrets = 0, hq_defend = 0, defend_first = false, is_player = false, smelters = 4, smelters_pending = 0,
    stock = { ["iron-plate"] = 600, ["copper-plate"] = 2000, coal = 1500, stone = 1500, ["firearm-magazine"] = 80,
      ["burner-mining-drill"] = 12, ["stone-furnace"] = 12, ["iron-chest"] = 6 },
    outposts = { op(1, COPPER, 47, { drills = 6 }), op(2, COAL, 42, { drills = 8 }), op(3, IRON, 38, { drills = T.max_drills(IRON) , full = true }),
      op(4, STONE, 86, { drills = 4, full = true }) },
    sites = { [COAL] = 1, [IRON] = 1, [COPPER] = 1, [STONE] = 1 },
    sites_near = { [COAL] = 157, [IRON] = 120, [COPPER] = 164, [STONE] = 173 },
  }
  for k, x in pairs(over or {}) do v[k] = x end
  v.recruit_cost = S.recruit_cost(v.workers)
  return v
end
local function think(view, st)
  st = st or C.new_state(0)
  return C.think(view, book, st, { tick = 46 * 3600, weights = B.weights({}, nil), reach = {}, iron_floor = 0 }), st
end
do
  local plan, st = think(fview())
  local projs = {}
  for _, p in ipairs(st.projects or {}) do projs[p.key] = p end
  check(projs["couverture:" .. COPPER] ~= nil, "6.1 projet de couverture du cuivre ouvert")
  check(projs["couverture:" .. COAL] ~= nil, "6.1 projet de couverture du charbon ouvert")
  local ext_cu, build_far = nil, 0
  for _, t in ipairs(plan.tasks) do
    if t.kind == "extend" and t.outpost == 1 then ext_cu = t end
    if t.kind == "build" then build_far = build_far + 1 end
  end
  check(ext_cu ~= nil, "6.2 tâche d'agrandissement du cuivre (avant-poste 1) émise")
  check(build_far == 0, "6.3 aucun build (le charbon proche a des places, aucun avant-poste plein n'appelle un site lointain)")
  -- 6.4 Rejouée : même plan (déterminisme).
  local plan2 = think(fview())
  local function sig(p) local o = {} for _, t in ipairs(p.tasks) do o[#o + 1] = t.key .. "@" .. tostring(t.prio) end return table.concat(o, ";") end
  check(sig(plan) == sig(plan2), "6.4 déterminisme de la pensée")
  -- 6.5 Plus aucune place (tous pleins) : plus de projet de couverture (il est « fini »).
  local v5 = fview({ outposts = { op(1, COPPER, 47, { drills = 6, full = true }), op(2, COAL, 42, { drills = 8, full = true }),
    op(3, IRON, 38, { full = true }), op(4, STONE, 86, { full = true }) } })
  local _, st5 = think(v5, st)
  local any = false
  for _, p in ipairs(st5.projects or {}) do if p.key:match("^couverture:") then any = true end end
  check(not any, "6.5 tous les avant-postes pleins : projets de couverture finis")
end

---------------------------------------------------------------------------------------------------
section("7. Mutants (chacun doit faire échouer une scène de référence)")
local function scene_far()
  local view = { outposts = { op(2, COAL, 42, { drills = 8 }) }, sites = { [COAL] = 1 }, sites_near = { [COAL] = 157 }, stock = {} }
  return #tasks_of(Fond.candidates(view, free_all(), { keys = {}, danger = { [2] = true } }).extraction, "build", COAL) == 0
end
local function scene_cover()
  local plan = think(fview())
  for _, t in ipairs(plan.tasks) do if t.kind == "extend" and t.outpost == 1 then return true end end
  return false
end
local function scene_never_build()
  local view2 = { outposts = { op(1, COPPER, 47, { full = true }) }, sites = { [COPPER] = 1 }, sites_near = { [COPPER] = 50 } }
  local st2 = emit(view2, { key = "couverture:" .. COPPER, outpost = COPPER, extend_only = true, fond = true })
  return st2 == "bloque"
end
local function scene_fuel()
  local s = sit({ stock = SAT, cap = cap_all(2), room = { [COPPER] = true, [COAL] = true } })
  local st3 = stD()
  st3.short = { [T.outposts[COAL].product] = 40 }
  return goal(B.generate(s, st3), "couverture:" .. COPPER) == nil
end
local function scene_take()
  local view = { outposts = { op(1, COPPER, 47, { drills = 6 }) }, sites = {}, defend_first = false }
  local _, _, E3 = emit(view, { key = "couverture:" .. COPPER, outpost = COPPER, extend_only = true, take_only = true },
    { ["iron-plate"] = 500, stone = 500 })
  return #E3.tasks == 0
end
check(scene_far() and scene_cover() and scene_never_build() and scene_fuel() and scene_take(), "7.0 scènes de référence vertes")
local function mutant(name, scene, apply, restore)
  apply()
  local ok, res = pcall(scene)
  restore()
  check(not ok or res == false, "mutant refusé : " .. name)
end
do
  local saved = V.build_refused
  mutant("R1 retournée sans effet", scene_far, function() V.build_refused = function() return false end end,
    function() V.build_refused = saved end)
  local saved_sit = C.situation
  mutant("aucune place vue (s.room vide)", scene_cover, function()
    C.situation = function(...) local s = saved_sit(...) s.room = {} return s end end, function() C.situation = saved_sit end)
  local saved_emit = P.EMIT.outpost
  mutant("extend_only ignoré", scene_never_build, function()
    P.EMIT.outpost = function(E, proj, g, ctx)
      local g2 = {}
      for k, x in pairs(g) do g2[k] = x end
      g2.extend_only = nil
      return saved_emit(E, proj, g2, ctx)
    end end, function() P.EMIT.outpost = saved_emit end)
  mutant("take_only ignoré", scene_take, function()
    P.EMIT.outpost = function(E, proj, g, ctx)
      local g2 = {}
      for k, x in pairs(g) do g2[k] = x end
      g2.take_only = nil
      return saved_emit(E, proj, g2, ctx)
    end end, function() P.EMIT.outpost = saved_emit end)
  local saved_key = B.key
  mutant("garde du combustible sans effet", scene_fuel, function()
    B.key = function(s) local k = saved_key(s) return { top = k.top, fuel = nil, order = k.order, optional = k.optional } end
  end, function() B.key = saved_key end)
end

print(string.format("[SCALE-COMPLET] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
