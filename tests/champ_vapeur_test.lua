--[[
  Tests hors jeu du lot ENERGIE (champ de machines a vapeur, retour du DC du 31/10 sur la 0.6.27) : shared/team/champ_vapeur.lua,
  son branchement dans shared/team/centrale.lua, chaine statique vers script/team/build.lua et script/team/plant_arms.lua, mutants.
  Usage :   lua5.2 tests/champ_vapeur_test.lua
]]
package.path = "./?.lua;" .. package.path
local P = require("shared.team.plan")

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
end
local function section(name) if not quiet then print("== " .. name) end end
local function read_file(path) local fh = assert(io.open(path, "rb")); local s = fh:read("*a"); fh:close(); return s end

--- Tapis par relais sur une carte libre (ou avec obstacles), via le VRAI A* du plan directeur : la route rendue est-elle continue ?
local function relay_run(Cv, sx, sy, ax, ay, blocked)
  local a = { x = ax, y = ay, dir = 0 }
  local mode, legs = Cv.reach(sx, sy, ax, ay)
  if mode ~= "relais" then return nil, mode, legs end
  local planned, reads = {}, 0
  local function cost(x, y)
    if blocked and blocked(x, y) then return nil end
    if planned[P.tkey(x, y)] then return nil end
    return 1
  end
  local maxbox = 0
  local tiles, why = Cv.route({ x = sx, y = sy }, a, legs, {
    dir_of = P.dir_of, DV = P.DV, cost = cost,
    read = function() reads = reads + 1 end,
    route = function(from, to, dir, bd)
      maxbox = math.max(maxbox, bd.x1 - bd.x0 + 1, bd.y1 - bd.y0 + 1)
      return P.belt_route(from, to, dir, bd, cost)
    end,
    mark = function(t) planned[P.tkey(t.x, t.y)] = true end,
  })
  return tiles, why, legs, maxbox
end

local function battery(Cv, C)
  section("1. Taille du champ")
  check(Cv.boilers_for(1) == Cv.MIN_FIELD, "une chaudiere vivante : champ minimal")
  check(Cv.boilers_for(0) == Cv.MIN_FIELD, "aucune chaudiere vivante : champ minimal (centrale perdue)")
  check(Cv.boilers_for(6) == 3, "six chaudieres vivantes : un champ de trois (la moitie)")
  check(Cv.boilers_for(30) == Cv.MAX_FIELD, "champ borne par Cv.MAX_FIELD")
  check(Cv.boilers_for(30, 2) == Cv.MAX_FIELD - 2, "une chaudiere de moins par refus du plan")
  check(Cv.boilers_for(30, 99) == 1, "jamais moins d'une chaudiere")
  check(Cv.boilers_for(30, 0, 4) == 4, "borne par la voie de tapis")
  check(Cv.boilers_for(30, nil, 0) == Cv.MAX_FIELD, "voie inconnue (0) : sans borne")
  check(Cv.lane_cap(15, 1800, 4000) == 33, "une voie de 15/s nourrit 33 chaudieres de 1,8 MW au charbon de 4 MJ")
  check(Cv.lane_cap(15, nil, 4000) == 0 and Cv.lane_cap(nil, 1800, 4000) == 0, "donnee manquante : 0")

  section("2. Branchement dans la croissance (shared/team/centrale.lua)")
  local free = { done = 1, pending = 0, refused = 0, hold = false, off = false }
  local function with(over) local n = {}; for k, v in pairs(free) do n[k] = v end; for k, v in pairs(over) do n[k] = v end; return n end
  check(C.growth({ saturated = true }, with({})) == C.BOILERS, "sans mesure des chaudieres : comme avant (C.BOILERS)")
  check(C.growth({ saturated = true }, with({ built = 1 })) == Cv.MIN_FIELD, "saturee, une chaudiere : un CHAMP de plus, pas une chaudiere")
  check(C.growth({ saturated = true }, with({ built = 8, refused = 1 })) == 3, "saturee, huit chaudieres, un refus : 4 - 1")
  check(C.growth({ saturated = true }, with({ built = 8, lane_cap = 2 })) == 2, "voie de tapis a 2 chaudieres : champ de 2")
  local nb, why = C.growth({ saturated = false }, with({ built = 3 }))
  check(nb == nil and why == "pas saturee", "non saturee, rien perdu : rien")
  check(C.growth({ saturated = false }, with({ built = 0, lost = true })) == C.SECOURS_BOILERS, "centrale perdue : unite de SECOURS (lot TV-ENERGIE, G65), jamais le champ, meme non saturee")
  nb, why = C.growth({ saturated = false }, with({ lost = true, pending = 1 }))
  check(nb == nil and why == "un chantier de centrale est ouvert", "perdue mais un chantier est ouvert : on attend")
  check(C.growth({ saturated = false }, with({ built = 0, lost = true, pending = 1, rebuilding = 1, done = 0 })) == C.SECOURS_BOILERS,
    "relecture : seule centrale rouverte depuis 10 min, l'unite de secours est demandee quand meme")
  nb, why = C.growth({ saturated = false }, with({ built = 0, lost = true, pending = 2, rebuilding = 1 }))
  check(nb == nil and why == "un chantier de centrale est ouvert", "relecture : un champ de remplacement est deja en chantier : pas un second")
  nb, why = C.growth({ saturated = true }, with({ built = 1, pending = 1, rebuilding = 1 }))
  check(nb == nil and why == "un chantier de centrale est ouvert", "relecture : centrale rouverte, pas encore perdue : on attend la reconstruction")
  nb, why = C.growth({ saturated = true }, with({ built = 1, done = 0 }))
  check(nb == nil and why == "aucune centrale finie", "relecture : rien de fini, rien de perdu : rien")
  check(C.growth({ saturated = false }, with({ built = 0, lost = true, hold = true })) == C.SECOURS_BOILERS, "relecture : le repli ne retient pas le secours")
  nb = C.growth({ saturated = false }, with({ lost = true, off = true }))
  check(nb == nil, "reglage de banc no_grow : rien, meme perdue")
  nb = C.growth({ saturated = false }, with({ lost = true, cool = true }))
  check(nb == nil, "pause apres un refus : rien, meme perdue")

  section("3. Perte de la centrale")
  local st = {}
  local fired = false
  for _ = 1, 119 do fired = fired or Cv.lost(st, 100, 10) end
  check(not fired, "pas de remplacement avant 120 releves (10 min : la reconstruction sur place a sa chance)")
  check(Cv.lost(st, 100, 10) == true and st.lost == 0, "au 120e releve : remplacement, compteur remis a zero")
  -- lot ENERGIE (2/11) : perte TOTALE (aucune machine vivante) = 36 releves (3 min), pas 120
  st, fired = {}, false
  for _ = 1, 35 do fired = fired or Cv.lost(st, 100, 0) end
  check(not fired, "perte totale : pas de remplacement avant 36 releves (3 min)")
  check(Cv.lost(st, 100, 0) == true and st.lost == 0 and Cv.LOSS_CHECKS_TOTAL == 36, "perte totale : remplacement au 36e releve")
  st = {}
  for _ = 1, 35 do Cv.lost(st, 100, 0) end
  check(Cv.lost(st, 100, 5) == false, "une machine revenue (5 %) : perte partielle, il faut de nouveau 120 releves")
  st = {}
  for _ = 1, 119 do Cv.lost(st, 100, 10) end
  check(Cv.lost(st, 100, 60) == false and st.lost == 0, "la moitie revenue : plus perdue, compteur a zero")
  st = {}
  for _ = 1, 2 * Cv.LOSS_CHECKS do check(Cv.lost(st, 0, 0) == false, "rien de prevu : jamais perdue") end
  st = {}
  for _ = 1, 2 * Cv.LOSS_CHECKS do check(Cv.lost(st, 100, 50) == false, "exactement la moitie vivante : pas perdue") end

  section("4. Portee du tapis et relais")
  check(Cv.reach(0, 0, 90, 60) == "direct", "boite de 114 x 85 : tapis ordinaire")
  local mode, legs = Cv.reach(0, 0, 142, 0)
  check(mode == "relais" and legs == 2, "ambre : 142 tuiles -> relais en 2 troncons (mode " .. tostring(mode) .. ", " .. tostring(legs) .. ")")
  mode, legs = Cv.reach(0, 0, 360, 0)
  check(mode == "relais" and legs == 4, "360 tuiles : 4 troncons, le maximum")
  mode, legs = Cv.reach(0, 0, 361, 0)
  check(mode == nil and legs == "trop loin", "au-dela : trop loin")
  local wps = Cv.waypoints(0, 0, 200, 40, 3, P.dir_of)
  check(#wps == 2 and wps[1].x == 67 and wps[1].y == 13 and wps[2].x == 133 and wps[2].y == 27, "points de passage sur la droite")
  check(wps[1].dir == P.dir_of(1, 0), "sens d'arrivee : axe dominant (x)")
  wps = Cv.waypoints(0, 0, -10, -200, 3, P.dir_of)
  check(wps[1].dir == P.dir_of(0, -1), "axe dominant y, vers le nord")
  check(#Cv.waypoints(0, 0, 50, 0, 1, P.dir_of) == 0, "un seul troncon : aucun point de passage")
  local cands = Cv.waypoint_candidates(10, 10)
  check(#cands == (2 * Cv.WAYPOINT_R + 1) ^ 2 and cands[1][1] == 10 and cands[1][2] == 10, "candidats : le point lui-meme d'abord")
  local ok_order = true
  for i = 2, #cands do if cands[i][3] < cands[i - 1][3] then ok_order = false end end
  check(ok_order, "candidats par distance de Chebyshev croissante")

  section("5. Route par relais (vrai A* du plan directeur)")
  local cases = { { 0, 0, 142, 0 }, { 0, 0, -140, 37 }, { 0, 0, 20, 200 }, { 5, 5, 250, -180 }, { 0, 0, 340, 0 } }
  for _, c in ipairs(cases) do
    local tiles, why, lg, maxbox = relay_run(Cv, c[1], c[2], c[3], c[4])
    local label = string.format("(%d,%d)->(%d,%d)", c[1], c[2], c[3], c[4])
    check(tiles ~= nil, "route trouvee " .. label .. " : " .. tostring(why))
    if tiles then
      local cont = tiles[1].x == c[1] and tiles[1].y == c[2] and tiles[#tiles].x == c[3] and tiles[#tiles].y == c[4]
      local seen = {}
      for i, t in ipairs(tiles) do
        if seen[P.tkey(t.x, t.y)] then cont = false end
        seen[P.tkey(t.x, t.y)] = true
        local nx = tiles[i + 1]
        if nx then
          local v = P.DV[t.dir]
          if not (v and t.x + v[1] == nx.x and t.y + v[2] == nx.y) then cont = false end
        end
      end
      check(cont, "route continue, sans doublon, chaque tuile tournee vers la suivante " .. label)
      check(maxbox <= Cv.BOX_DIRECT, "chaque boite de troncon tient dans 120 tuiles " .. label .. " (" .. tostring(maxbox) .. ")")
    end
  end
  -- un mur au milieu avec une breche : le relais contourne ; un mur sans breche sur toute la boite : refus nomme
  local wall = function(x, y) return x == 71 and (y < -30 or y > 30) end
  local tiles = relay_run(Cv, 0, 0, 142, 0, wall)
  check(tiles ~= nil, "mur avec breche au milieu : le relais passe")
  local closed = function(x, y) return x >= 70 and x <= 72 end
  local t2, why2 = relay_run(Cv, 0, 0, 142, 0, closed)
  check(t2 == nil and tostring(why2):find("troncon", 1, true) ~= nil, "mur sans breche : refus qui nomme le troncon (" .. tostring(why2) .. ")")
  local noway = function(x, y) return x > 40 and x < 100 end -- les points de passage (47, 94) sont dans la zone interdite
  local t3, why3 = relay_run(Cv, 0, 0, 142, 0, noway)
  check(t3 == nil, "zone interdite sur toute la droite : refus (" .. tostring(why3) .. ")")

  section("6. Refus de l'alimentation")
  check(Cv.after_refusal("foreuses : minerai", true) == "grandir", "gisement hors des lots : le treillis grandit")
  check(Cv.after_refusal("foreuses : gisement : coal hors du treillis", true) == "grandir", "hors du treillis : il grandit")
  check(Cv.after_refusal("foreuses : minerai", false) == "attendre", "treillis au maximum : on attend")
  check(Cv.after_refusal("foreuses : trop loin", true) == "attendre", "trop loin : on attend (le relais a deja tranche)")
  check(Cv.after_refusal(nil, true) == "attendre", "raison inconnue : on attend")

  section("7. Journal")
  local l = Cv.line({ kind = "champ", team = "scarlet", tick = 3600 * 90, nb = 3, built = 4, refused = 1 })
  check(l:find("%[FO%-CHAMP%-VAPEUR%] scarlet : champ de 3 chaudiere%(s%) demande a 90%.0 min") ~= nil, "ligne champ : " .. l)
  l = Cv.line({ kind = "perte", team = "azure", tick = 7200, alive = 0, planned = 60000, nb = 2 })
  check(l:find("centrale perdue", 1, true) ~= nil and l:find("autre rive", 1, true) ~= nil, "ligne perte")
  l = Cv.line({ kind = "relais", team = "amber", tick = 0, project = 4, legs = 2, sx = 1, sy = 2, ax = 3, ay = 4 })
  check(l:find("2 troncon", 1, true) ~= nil, "ligne relais")
  l = Cv.line({ kind = "grandir", team = "amber", tick = 0, project = 4, why = "minerai", radius = 4 })
  check(l:find("le treillis grandit", 1, true) ~= nil, "ligne grandir")
end

local Cv0 = dofile("shared/team/champ_vapeur.lua")
local C0 = dofile("shared/team/centrale.lua")
battery(Cv0, C0)

---------------------------------------------------------------------------------------------------
-- Chaine statique : declencheur -> decision -> action
---------------------------------------------------------------------------------------------------
section("8. Chaine statique")
local build = read_file("script/team/build.lua")
local arms = read_file("script/team/plant_arms.lua")
local central = read_file("shared/team/centrale.lua")
check(central:find("require(\"shared.team.champ_vapeur\")", 1, true) ~= nil, "centrale.lua lit la regle du champ")
check(central:find("Cv.boilers_for(n.built, n.refused, n.lane_cap)", 1, true) ~= nil, "C.growth dimensionne le champ")
check(arms:find("local lost = Cv.lost(g, planned, capacity + reopened_alive)", 1, true) ~= nil, "plant_arms : releve de la perte")
check(arms:find("built = boilers_alive", 1, true) ~= nil and arms:find("lane_cap = Cv.lane_cap(M.BELT_RATE, boiler_kw, M.COAL_J)", 1, true) ~= nil,
  "plant_arms : chaudieres vivantes et voie de tapis a la decision")
check(arms:find("Cv.line({ kind = \"champ\"", 1, true) ~= nil and arms:find("kind = \"perte\"", 1, true) ~= nil, "plant_arms : journal du champ et de la perte")
check(build:find("mode, legs = Cv.reach(s.x, s.y, a.x, a.y)", 1, true) ~= nil and build:find("if p.spec and p.spec.alim then", 1, true) ~= nil,
  "plan_drills : le relais ne sert qu'a l'alimentation d'une centrale (et, lot FONDERIE-BLOC, a celle d'un coffre de champ)")
check(build:find("if p.spec and p.spec.alimquai then mode, legs = Cv.reach(s.x, s.y, a.x, a.y) end", 1, true) ~= nil,
  "plan_drills : le relais sert aussi a l'alimentation d'un coffre de champ (spec.alimquai)")
check(build:find("tiles, why_leg, leg_no = Cv.route(s, a, relay_legs", 1, true) ~= nil, "plan_drills : trace par troncons")
-- (lot TRANCHES-FOREUSES : les trois essais de boite unique sont dans Tdr.trace, appele dans la branche « sinon » du relais)
do
  local i_relais = build:find('n2 = "relais : " .. tostring(why_leg)', 1, true)
  local i_trace = build:find("Tdr.trace({", 1, true)
  check(i_relais ~= nil and i_trace ~= nil and i_trace > i_relais and build:sub(i_relais, i_trace):find("\n  else\n", 1, true) ~= nil
    and build:sub(i_relais, i_trace):find("if not tiles and not relay_legs", 1, true) == nil,
    "plan_drills : les essais de boite unique (Tdr.trace) ne servent pas au relais")
end
check(build:find("Cv.after_refusal(last, Build.can_grow(b)) == \"grandir\"", 1, true) ~= nil, "plan_alim : le treillis grandit sur un refus « minerai »")
check(build:find("if mode ~= \"relais\" then return false, \"trop loin\" end", 1, true) ~= nil, "plan_drills : au-dela du relais, « trop loin » reste")

---------------------------------------------------------------------------------------------------
-- Mutants
---------------------------------------------------------------------------------------------------
section("9. Mutants")
local function mutant(label, edit)
  local Cm = dofile("shared/team/champ_vapeur.lua")
  local Cc = dofile("shared/team/centrale.lua")
  edit(Cm, Cc)
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(battery, Cm, Cc)
  quiet = false
  local caught = failures > f0 or not ok
  passes, failures = p0, f0
  check(caught, "mutant refuse : " .. label)
end
mutant("champ minimal d'une chaudiere", function(Cm) Cm.MIN_FIELD = 1 end)
mutant("champ non borne", function(Cm) Cm.MAX_FIELD = 100 end)
mutant("refus du plan ignores", function(Cm) local old = Cm.boilers_for; Cm.boilers_for = function(b, _, l) return old(b, 0, l) end end)
mutant("voie de tapis ignoree", function(Cm) local old = Cm.boilers_for; Cm.boilers_for = function(b, s) return old(b, s, nil) end end)
mutant("perte totale comme une perte partielle (10 min)", function(Cm) Cm.LOSS_CHECKS_TOTAL = Cm.LOSS_CHECKS end)
mutant("perte totale immediate", function(Cm) Cm.LOSS_CHECKS_TOTAL = 1 end)
mutant("perte immediate", function(Cm) Cm.LOSS_CHECKS = 1 end)
mutant("perte jamais", function(Cm) Cm.lost = function() return false end end)
mutant("seuil de perte a 100 %", function(Cm) Cm.LOSS_FRAC = 1.0 end)
mutant("relais jamais", function(Cm) Cm.MAX_LEGS = 0 end)
mutant("relais sans borne", function(Cm) Cm.MAX_LEGS = 100 end)
mutant("troncons trop longs", function(Cm) Cm.LEG = 200 end)
mutant("pas de point de passage", function(Cm) local old = Cm.waypoints; Cm.waypoints = function(a, b, c, d, e, f) local w = old(a, b, c, d, e, f); return {} end end)
mutant("tronçon suivant sur le point de passage", function(Cm)
  local old = Cm.route
  Cm.route = function(s, a, legs, env)
    local DV = {}
    for k, v in pairs(env.DV) do DV[k] = { 0, 0 } end
    env.DV = DV
    return old(s, a, legs, env)
  end
end)
mutant("le treillis ne grandit jamais", function(Cm) Cm.after_refusal = function() return "attendre" end end)
mutant("le treillis grandit meme au maximum", function(Cm) Cm.after_refusal = function() return "grandir" end end)
mutant("centrale perdue ignoree par la croissance", function(_, Cc)
  local old = Cc.growth
  Cc.growth = function(st, n) local n2 = {}; for k, v in pairs(n) do n2[k] = v end; n2.lost = nil; return old(st, n2) end
end)
mutant("croissance sans champ", function(_, Cc)
  local old = Cc.growth
  Cc.growth = function(st, n) local n2 = {}; for k, v in pairs(n) do n2[k] = v end; n2.built = nil; return old(st, n2) end
end)
mutant("candidats dans le desordre", function(Cm)
  local old = Cm.waypoint_candidates
  Cm.waypoint_candidates = function(x, y) local l = old(x, y); local r = {}; for i = #l, 1, -1 do r[#r + 1] = l[i] end; return r end
end)

---------------------------------------------------------------------------------------------------
-- Relecture : les maillons qui manquaient (PA.watch reel, moteur simule ; but du cerveau ; refus qui fait grandir)
---------------------------------------------------------------------------------------------------
section("10. Perte d'une centrale ROUVERTE (PA.watch reel)")
do
  log = log or function() end
  package.preload["script.team.stock"] = package.preload["script.team.stock"] or function() return { count = function() return 0 end } end
  package.preload["script.team.centrale_mort"] = package.preload["script.team.centrale_mort"] or function() return {} end
  local PA = require("script.team.plant_arms")
  local Cvr = require("shared.team.champ_vapeur")
  local alive = {} -- nom .. position -> vivant
  local surface = { find_entity = function(name, pos)
    if alive[name .. ":" .. pos[1]] then
      return { valid = true, force = { name = "f" }, energy_generated_last_tick = 0,
        get_fuel_inventory = function() return { is_empty = function() return false end } end } -- (lot ENERGIE 2/11 : la sante lit les chaudieres)
    end
    return nil
  end }
  local plant = { id = 1, state = "fini", finished = 10, spec = { gen = "steam" },
    ents = { { name = "boiler", x = 1, y = 0 }, { name = "steam-engine", x = 2, y = 0 }, { name = "steam-engine", x = 3, y = 0 } } }
  local f = { key = "t", force = "f", build = { plant = 1, projects = { [1] = plant }, order = { 1 }, opts = {} } }
  local tick, asked = 0, nil
  local function run(n) for _ = 1, n do tick = tick + PA.WATCH_EVERY; asked = PA.watch(f, surface, tick); if asked then return true end end return false end
  for _, e in ipairs(plant.ents) do alive[e.name .. ":" .. e.x] = true end
  check(run(Cvr.LOSS_CHECKS + 5) == false, "centrale vivante, non saturee : rien")
  -- destruction ; la reconstruction rouvre le projet (Sweep.reopen_pieces) et n'aboutit pas
  alive = {}
  plant.state, plant.reopened, plant.reopened_tick = "reserve", 1, tick
  check(run(Cvr.LOSS_CHECKS_TOTAL - 1) == false, "avant 3 min : on laisse la reconstruction faire")
  check(run(1) == true and asked == require("shared.team.centrale").SECOURS_BOILERS, "3 min sans aucune machine, projet rouvert : unite de secours (" .. tostring(asked) .. ")")
  -- le remplacement est en chantier : pas un second
  f.build.extra_plants = { 2 }
  f.build.projects[2] = { id = 2, state = "chantier", spec = {}, ents = {} }
  check(run(2 * Cvr.LOSS_CHECKS) == false, "remplacement en chantier : pas de second champ")
  -- les machines revenues : plus perdue
  f.build.extra_plants, f.build.projects[2] = nil, nil
  for _, e in ipairs(plant.ents) do alive[e.name .. ":" .. e.x] = true end
  check(run(2 * Cvr.LOSS_CHECKS) == false, "machines revenues (projet encore rouvert) : rien")
end

section("11. Le cerveau fabrique les manques du projet d'alimentation")
do
  local A = require("shared.ai3.automatiser")
  local g = A.goals({}, { mods = {
    { product = "centrale", state = "reserve", missing = { { "x", 1 } }, gain = 0 },
    { product = "centrale-alim", state = "reserve", missing = { { "tapis", 142 } }, gain = 0 } } }, {})
  local keys = {}
  for _, x in ipairs(g) do keys[x.key] = x end
  check(keys["auto:centrale"] ~= nil and keys["auto:centrale-alim"] ~= nil, "centrale et alimentation ouvertes : deux buts, A.goals ne les fond pas")
  check(keys["auto:centrale-alim"] and keys["auto:centrale-alim"].missing[1][2] == 142 and keys["auto:centrale-alim"].pile == nil,
    "le but porte les manques et n'est jamais suspendu par la pile")
  local autos = read_file("script/ai3/automatisation.lua")
  check(autos:find("local alim_id = Build.alim_project(f)", 1, true) ~= nil and autos:find("product = \"centrale-alim\"", 1, true) ~= nil,
    "automatisation.lua : le projet d'alimentation entre au contexte du cerveau")
  check(build:find("function Build.alim_project(f)", 1, true) ~= nil, "build.lua : Build.alim_project")
end

section("12. Un refus qui fait grandir le treillis ne mene pas a la pause longue")
do
  local Ch = require("shared.team.charbon_centrale")
  local st = {}
  for _ = 1, 10 do Ch.refused(st, 100, true) end
  check(st.tries == 0 and st.retry_at == 100 + Ch.RETRY_TICKS, "10 refus avec croissance : pause courte, 0 essai compte")
  Ch.refused(st, 100)
  check(st.tries == 1, "refus ordinaire : compte")
  check(build:find("Cc.refused(st, tick, alim.cv_grew)", 1, true) ~= nil and build:find("p.cv_grew = true", 1, true) ~= nil, "build.lua : le refus dit qu'il a fait grandir")
  -- Intégration 0.6.28 : alimentation et champ suivant héritent du poteau de la centrale (pas le poteau moyen par défaut, recette fermée)
  check(build:find('domain = "infrastructures", pole = p.spec and p.spec.pole }', 1, true) ~= nil, "build.lua : l'alimentation prend le poteau de la centrale")
  -- lot CENTRALE-PRES : le poteau de la première centrale est le poteau PRÉFÉRÉ (PlantArms.size) ; la demande porte celui qui est obtenable
  check(build:find("PlantArms.size(f, first.spec.gen, nb, first.spec.pole, tick, secours)", 1, true) ~= nil and build:find("pole = pole, plant = true", 1, true) ~= nil,
    "build.lua : le champ suivant prend le poteau de la première centrale (ou un poteau obtenable, lot CENTRALE-PRES)")
end

print(string.format("[CHAMP-VAPEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
