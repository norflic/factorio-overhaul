--[[
  Lot RESEAU : test hors jeu du RUNTIME (script/team/reseau_runtime.lua) sur un moteur simulé minimal, avec un jeu de
  données aux NOMS CHANGÉS (poteau « zz-pole », générateur « zz-engine », foreuse « zz-drill », types « zz-… ») :
    §1 les types de prototypes qui consomment ou produisent sont DÉCOUVERTS (aucun nom dans le code) ;
    §2 le relevé étalé sur plusieurs ticks publie les bonnes composantes, zones non couvertes, îlots, production ;
    §3 un poteau d'un projet MORT (événement) est relevé : petit projet de réparation (réserve, objets, ancre), 3 essais,
       jamais pour un poteau retiré sans mort ;
    §4 à 80 % de charge confirmés deux fois : une centrale de plus (extra, args, près de la première) ; une seule à la fois ;
       jamais avant 80 % ; la puissance d'une unité vient des prototypes ;
    §5 les bras de la centrale de plus passent par plant_arms avec leur propre état ;
    §6 déterminisme (deux jeux identiques, mêmes publications) et jetons refusés : rien ne se passe.
  Usage : lua5.2 tests/reseau_runtime_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local oks, fails = 0, 0
local function check(cond, msg)
  if cond then oks = oks + 1 else fails = fails + 1; print("  ECHEC : " .. msg) end
end

---------------------------------------------------------------------------------------------------
-- Moteur simulé
---------------------------------------------------------------------------------------------------
local handlers = { nth = nil, died = nil }
local remote_if = {}
local logs = {}
local arms_calls = {}
local requests = {}
local tokens_ok = true

defines = { events = { on_entity_died = 17 }, entity_status = { low_power = 1, no_power = 2, working = 3 } }
log = function(s) logs[#logs + 1] = s end
remote = { add_interface = function(name, t) remote_if[name] = t end }

package.loaded["script.core.events"] = {
  on_nth_tick = function(n, fn) handlers.nth = fn end,
  on = function(id, fn) handlers.died = fn end,
}
package.loaded["script.core.profiler"] = { start = function() end, stop = function() end }
local TEAM
package.loaded["script.faction.state"] = {
  alive = function() return { 1 } end,
  faction = function(id) if id == 1 then return TEAM end return nil end,
}
package.loaded["script.team.stock"] = { count = function() return 100 end }
package.loaded["script.team.tokens"] = { take = function() return tokens_ok end }
package.loaded["script.team.plant_arms"] = {
  step = function(f, surface, p, tick) arms_calls[#arms_calls + 1] = { pid = p.id, state = f.build.plant_arms } end,
}
package.loaded["script.team.build"] = {
  PRIO = 55, COST_PLAN = 200,
  request = function(f, spec)
    local b = f.build
    local id = #b.order + 1
    local p = { id = id, spec = spec, state = "attente", parts = {}, ents = {}, obstacles = {}, stock = {}, prio = spec.prio }
    b.projects[id] = p
    b.order[#b.order + 1] = id
    requests[#requests + 1] = p
    return id
  end,
}

-- le gabarit de centrale du test : une unité = 2 machines (renommées), extensible jusqu'à 4
local M = require("shared.team.modules")
M.GEN.zzgen = function(n)
  local ents = {}
  for i = 1, 2 * n do ents[i] = { name = "zz-engine" } end
  return { entities = ents, electric_out_kw = 1800 * n, power_kw = 0, extensions = { { arg = 1, max = 4 } } }
end
M.GEN.zzload = function(n) return { entities = {}, power_kw = 700 * n, extensions = {} } end

local PROTOS = {
  ["zz-pole"] = { type = "electric-pole", max_wire_distance = 7.5, supply_area_distance = 2.5 },
  ["zz-big"] = { type = "electric-pole", max_wire_distance = 30, supply_area_distance = 2 },
  ["zz-engine"] = { type = "zz-gen-type", max_energy_production = 15000, max_energy_usage = 0,
    electric_energy_source_prototype = { usage_priority = "primary-output" } },
  ["zz-drill"] = { type = "zz-drill-type", max_energy_usage = 1500, max_energy_production = 0,
    electric_energy_source_prototype = { usage_priority = "secondary-input" } },
  ["zz-battery"] = { type = "zz-battery-type", max_energy_usage = 0, max_energy_production = 5000,
    electric_energy_source_prototype = { usage_priority = "tertiary" } },
  ["zz-wall"] = { type = "zz-wall-type", max_energy_usage = 0, max_energy_production = 0 },
}
for name, p in pairs(PROTOS) do p.name = name end

local WORLD
local function new_world()
  WORLD = { ents = {}, next_unit = 1, tick = 0 }
  local S = {}
  function S.find_entities_filtered(t)
    local types = t.type
    if type(types) == "string" then types = { types } end
    local set
    if types then set = {}; for _, ty in ipairs(types) do set[ty] = true end end
    local out = {}
    for _, e in ipairs(WORLD.ents) do
      if e.valid and (not t.force or e.force == t.force) and (not set or set[e.type]) then
        local inside = true
        if t.area then
          local a = t.area
          inside = e.position.x >= a[1][1] and e.position.x < a[2][1] and e.position.y >= a[1][2] and e.position.y < a[2][2]
        end
        if inside then out[#out + 1] = e end
      end
    end
    return out
  end
  WORLD.surface = S
  return WORLD
end

local function add(name, x, y, extra)
  local p = PROTOS[name]
  local e = { valid = true, name = name, type = p.type, force = "fx", position = { x = x, y = y }, unit_number = WORLD.next_unit,
    energy_generated_last_tick = 0, status = defines.entity_status.working }
  WORLD.next_unit = WORLD.next_unit + 1
  local w = extra and extra.w or 1
  local h = extra and extra.h or 1
  e.bounding_box = { left_top = { x = x - w / 2, y = y - h / 2 }, right_bottom = { x = x + w / 2, y = y + h / 2 } }
  for k, v in pairs(extra or {}) do e[k] = v end
  WORLD.ents[#WORLD.ents + 1] = e
  return e
end

game = { tick = 0, entity_prototypes = PROTOS }

---------------------------------------------------------------------------------------------------
-- Équipe
---------------------------------------------------------------------------------------------------
local function new_team()
  local f = {
    id = 1, key = 1, force = "fx", is_player = false, outposts = {},
    hq = { valid = true, position = { x = 0, y = 0 }, surface = WORLD.surface },
    build = { projects = {}, order = {}, plant = 1, plant_arms = nil },
  }
  -- projet 1 : centrale de base finie ; projet 2 : réseau (poteaux bâtis)
  f.build.projects[1] = { id = 1, state = "fini", spec = { gen = "zzgen", args = { 1 }, feed = true, domain = "infrastructures" },
    parts = { { ox = 40, oy = 0, w = 6, h = 12 } }, ents = {}, obstacles = {} }
  f.build.projects[2] = { id = 2, state = "fini", spec = { gen = "smelter", args = {} }, parts = {}, obstacles = {}, ents = {} }
  f.build.order = { 1, 2 }
  return f
end

--- Chaîne de poteaux sur y = 0.5 de x = 0.5 à 36.5 (pas 7), engines à gauche, foreuses le long.
local function build_base()
  if package.loaded["script.team.reseau_runtime"] then package.loaded["script.team.reseau_runtime"].reset() end
  new_world()
  TEAM = new_team()
  local p2 = TEAM.build.projects[2]
  for i = 0, 5 do
    local x = 0.5 + 7 * i
    local pole = add("zz-pole", x, 0.5, { electric_network_id = 1 })
    pole.electric_network_id = 1
    p2.ents[#p2.ents + 1] = { name = "zz-pole", x = x, y = 0.5, dir = 0, built = true, anchor = "a" .. i, ax = x, ay = 4.5, item = "zz-pole-item" }
  end
  for i = 1, 2 do add("zz-engine", -2.5, 0.5 + 1.5 * (i - 1), { w = 3, h = 3, electric_network_id = 1 }) end
  for i = 0, 3 do add("zz-drill", 6 + 7 * i, 3.5, { w = 3, h = 3, electric_network_id = 1 }) end
  add("zz-drill", 70.5, 20.5, { w = 3, h = 3 })           -- hors de toute aire : zone non couvertes
  add("zz-drill", 72.5, 22.5, { w = 3, h = 3 })
  add("zz-drill", -60.5, 50.5, { w = 3, h = 3 })
  add("zz-battery", 10.5, 10.5, { w = 2, h = 2 })           -- ni producteur ni consommateur
  add("zz-wall", 10.5, 12.5)
  return TEAM
end

local function run(ticks, step)
  for _ = 1, ticks / 20 do
    game.tick = game.tick + 20
    handlers.nth({ tick = game.tick })
  end
end

---------------------------------------------------------------------------------------------------
-- Chargement du runtime
---------------------------------------------------------------------------------------------------
build_base()
local Rt
do
  local alt = arg and arg[1] == "--src" and arg[2] or nil -- mutant à jouer (pilote des mutants plus bas)
  if alt then
    local fn = assert(loadfile(alt))
    Rt = fn()
    package.loaded["script.team.reseau_runtime"] = Rt
  else
    Rt = require("script.team.reseau_runtime")
  end
end
check(handlers.nth ~= nil and handlers.died ~= nil, "abonnements statiques posés (tick et mort)")
check(remote_if["fo-reseau"] ~= nil, "interface fo-reseau")

-- §1/§2 : découverte des types et relevé
run(2400)
local rep = TEAM.reseau and TEAM.reseau.report
check(rep ~= nil, "un relevé publié après 2 400 ticks")
if rep then
  check(rep.poles == 6 and rep.comps == 1, "6 poteaux, 1 composante (" .. rep.poles .. ", " .. rep.comps .. ")")
  check(rep.producers == 2, "2 producteurs découverts par leur type (« primary-output »), la batterie exclue (" .. rep.producers .. ")")
  check(rep.consumers == 7, "7 consommateurs découverts par leur type (" .. rep.consumers .. ")")
  check(rep.uncovered == 3 and rep.n_zones == 2, "3 bâtiments hors de portée en 2 zones (" .. rep.uncovered .. ", " .. tostring(rep.n_zones) .. ")")
  check(rep.check.comp_split == 0 and rep.check.comp_merge == 0, "composantes du modèle = réseaux simulés")
  check(rep.check.cover_disagree == 0, "couverture du modèle = réseau simulé (" .. rep.check.cover_disagree .. ")")
  check(rep.prod_kw == 1800 and rep.unit_kw == 1800, "production 1 800 kW, unité 1 800 kW lue aux prototypes (" .. tostring(rep.prod_kw) .. ", " .. tostring(rep.unit_kw) .. ")")
  check(rep.level == "ok" and #requests == 0, "charge nulle : ok, aucune demande")
  check(rep.pivots ~= nil, "poteaux pivots publiés")
end
local r1 = remote_if["fo-reseau"].report(1)
check(r1 and r1.tick == rep.tick, "interface distante : même relevé")
check(#Rt.uncovered_zones(TEAM) == 2, "zones non couvertes lisibles par le cerveau")
check(tostring(logs[#logs]):find("FO%-RESEAU") ~= nil or #logs > 0, "ligne de journal écrite")

-- le contrôle contre le moteur voit un désaccord : un bâtiment « hors de portée » pour le modèle mais relié pour le moteur
do
  for _, e in ipairs(WORLD.ents) do if e.name == "zz-drill" and e.position.x == 70.5 then e.electric_network_id = 7 end end
  game.tick = game.tick + 100000
  Rt.reset()
  TEAM.reseau = nil
  run(2400)
  check(TEAM.reseau.report.check.cover_disagree == 1, "un désaccord de couverture avec le moteur est compté (" .. tostring(TEAM.reseau.report.check.cover_disagree) .. ")")
end

-- §3 : un poteau meurt
build_base()
game.tick = game.tick + 100000
run(2400)
local victim
for _, e in ipairs(WORLD.ents) do if e.name == "zz-pole" and math.abs(e.position.x - 14.5) < 0.01 then victim = e end end
check(victim ~= nil, "poteau témoin trouvé")
victim.valid = false -- il disparaît du monde …
handlers.died({ entity = { valid = true, type = "electric-pole", name = "zz-pole", force = { name = "fx" }, position = { x = 14.5, y = 0.5 } } })
local died_tick = game.tick
run(Rt.REPAIR_DELAY - 100) -- trop tôt pour l'ordre
local before = #requests
run(4000)
local rep2 = TEAM.reseau.report
check(rep2 ~= nil and rep2.comps == 2, "le relevé voit 2 composantes après la mort (" .. tostring(rep2 and rep2.comps) .. ")")
local rp
for _, p in ipairs(requests) do if p.spec.repair then rp = p end end
check(rp ~= nil, "un projet de réparation est demandé")
if rp then
  check(#rp.ents == 1 and rp.ents[1].x == 14.5 and rp.ents[1].name == "zz-pole" and rp.ents[1].built == false, "il relève exactement le poteau mort")
  check(rp.state == "reserve" and rp.ents[1].anchor == "a2" and rp.ents[1].item == "zz-pole-item", "état réserve, ancre et objet copiés")
  check(rp.prio == 80, "priorité du chantier élevée (" .. tostring(rp.prio) .. ")")
end
local n_rep = 0
for _, p in ipairs(requests) do if p.spec.repair then n_rep = n_rep + 1 end end
check(n_rep == 1, "un seul projet de réparation tant qu'il est ouvert (" .. n_rep .. ")")
-- le projet échoue (bloqué) : nouvel essai, puis abandon au 3e
for try = 2, 4 do
  for _, p in ipairs(requests) do if p.spec.repair and p.state ~= "bloque" then p.state = "bloque" end end
  run(3700)
end
n_rep = 0
for _, p in ipairs(requests) do if p.spec.repair then n_rep = n_rep + 1 end end
check(n_rep == 3, "3 essais au plus pour un même poteau (" .. n_rep .. ")")
local st = remote_if["fo-reseau"].state(1)
check(st.stats.repairs_made == 3 and st.stats.repairs_abandoned == 1, "statistiques : 3 réparations, 1 abandon (" .. st.stats.repairs_made .. ", " .. st.stats.repairs_abandoned .. ")")

-- un poteau retiré sans mort n'est jamais relevé
TEAM = build_base()
TEAM.reseau = nil
requests = {}
handlers.died = handlers.died
for _, e in ipairs(WORLD.ents) do if e.name == "zz-pole" and math.abs(e.position.x - 21.5) < 0.01 then e.valid = false end end
run(6000)
check(#requests == 0, "poteau repris par un joueur (aucune mort) : jamais relevé")

-- poteau mort qui ne rallume rien : pas de projet
TEAM = build_base()
requests = {}
for _, e in ipairs(WORLD.ents) do if e.name == "zz-pole" and math.abs(e.position.x - 35.5) < 0.01 then e.valid = false end end
handlers.died({ entity = { valid = true, type = "electric-pole", name = "zz-pole", force = { name = "fx" }, position = { x = 35.5, y = 0.5 } } })
run(8000)
local any = false
for _, p in ipairs(requests) do if p.spec.repair then any = true end end
check(not any, "poteau de bout de ligne sans bâtiment derrière : aucune réparation inutile")

-- §4 : charge
TEAM = build_base()
requests = {}
-- machines productrices à 85 % de la production (1 800 kW)
for _, e in ipairs(WORLD.ents) do if e.name == "zz-engine" then e.energy_generated_last_tick = 15000 * 0.85 end end
game.tick = game.tick + 100000
run(2400)
check(TEAM.reseau.report and TEAM.reseau.report.level == "alerte", "85 % : alerte (" .. tostring(TEAM.reseau.report and TEAM.reseau.report.level) .. ")")
check(#requests == 0, "une seule alerte ne suffit pas (confirmation sur 2 relevés)")
run(4000)
local extra
for _, p in ipairs(requests) do if p.spec.extra then extra = p end end
check(extra ~= nil, "alerte confirmée : une centrale de plus demandée")
if extra then
  check(extra.spec.gen == "zzgen" and extra.spec.feed == true, "même générateur et mêmes options que la centrale de base")
  check(extra.spec.args[1] == math.max(1, math.min(4, math.ceil((1800 * 0.85 / 0.6 - 1800) / 1800 - 1e-9))), "unités = (besoin / 60 % - production) / unité (" .. tostring(extra.spec.args[1]) .. ")")
  check(extra.spec.near and extra.spec.near.x == 43 and extra.spec.near.y == 6, "demandée près de la première (43, 6)")
end
run(6000)
local nextra = 0
for _, p in ipairs(requests) do if p.spec.extra then nextra = nextra + 1 end end
check(nextra == 1, "une seule à la fois tant qu'elle est ouverte (" .. nextra .. ")")
-- sous 80 % : jamais
TEAM = build_base()
requests = {}
for _, e in ipairs(WORLD.ents) do if e.name == "zz-engine" then e.energy_generated_last_tick = 15000 * 0.79 end end
game.tick = game.tick + 100000
run(12000)
check(#requests == 0 and TEAM.reseau.report.level == "ok", "79 % : rien (" .. tostring(TEAM.reseau.report.level) .. ")")
-- un module électrique demandé mais pas bâti compte AVANT la saturation
TEAM = build_base()
requests = {}
TEAM.build.projects[3] = { id = 3, state = "reserve", spec = { gen = "zzload", args = { 1 } }, parts = {}, ents = {}, obstacles = {} }
TEAM.build.order[3] = 3
for _, e in ipairs(WORLD.ents) do if e.name == "zz-engine" then e.energy_generated_last_tick = 15000 * 0.5 end end
game.tick = game.tick + 100000
run(6000)
check(TEAM.reseau.report.level == "alerte" and TEAM.reseau.report.plan_kw == 700, "50 % + un module de 700 kW demandé : alerte (" .. tostring(TEAM.reseau.report.level) .. ", plan " .. tostring(TEAM.reseau.report.plan_kw) .. ")")

-- §5 : les bras d'une centrale de plus
do
  local f = TEAM
  local ex = { id = 9, state = "fini", spec = { gen = "zzgen", extra = true }, parts = {}, ents = {}, obstacles = {} }
  f.build.projects[9] = ex
  f.reseau.plants[#f.reseau.plants + 1] = { pid = 9, asked = 1, n = 1 }
  f.build.plant_arms = { mode = "base" }
  arms_calls = {}
  run(60)
  check(#arms_calls > 0 and arms_calls[1].pid == 9, "plant_arms appelé pour la centrale de plus")
  check(arms_calls[1].state == nil and f.build.plant_arms.mode == "base", "état des bras propre à la centrale de plus ; celui de la base est rendu intact")
end

-- §6 : déterminisme et jetons
do
  local function digest()
    TEAM = build_base()
    TEAM.reseau = nil
    game.tick = 500000
    run(3000)
    local r = TEAM.reseau.report
    return string.format("%d|%d|%d|%d|%d|%d|%s", r.poles, r.comps, r.consumers, r.uncovered, r.n_zones, r.powered, tostring(r.prod_kw))
  end
  local a, b = digest(), digest()
  check(a == b, "deux jeux identiques, mêmes publications (" .. a .. ")")
  tokens_ok = false
  TEAM = build_base()
  TEAM.reseau = nil
  game.tick = game.tick + 100000
  run(3000)
  check(TEAM.reseau == nil or TEAM.reseau.report == nil, "jetons refusés : aucun relevé")
  tokens_ok = true
end

-- §7 mutants : chaque règle retirée du runtime est vue (le test est rejoué sur une copie modifiée du fichier)
if not (arg and arg[1] == "--src") then
  local f = assert(io.open("script/team/reseau_runtime.lua", "rb"))
  local SRC = f:read("*a")
  f:close()
  local MUT = {
    { "3 essais au plus", "Rt.REPAIR_TRIES = 3", "Rt.REPAIR_TRIES = 99" },
    { "seuls les morts sont relevés", "if d and not present[k] and not seen[k]", "if not present[k] and not seen[k]" },
    { "alerte confirmée deux fois", "Rt.CONFIRM = 2 ", "Rt.CONFIRM = 1 " },
    { "centrale de plus marquée extra", "spec.extra = true", "spec.extra = nil" },
    { "modules demandés comptés", "plan = plan + rs.plan_kw[pid]", "plan = plan" },
    { "accumulateur exclu des producteurs", '["solar"] = true }', '["solar"] = true, ["tertiary"] = true }' },
    { "réparation prioritaire", "prio = Build.PRIO + 25", "prio = Build.PRIO" },
    { "une centrale de plus à la fois", "and not open_ext and tick", "and tick" },
    { "pas de réparation inutile", "if #plan.chosen == 0 then return end", "" },
    { "bras de la centrale de plus : état propre", "b.plant_arms = e.arms", "b.plant_arms = saved" },
    { "seuil d'alerte de la règle pure", "alert = rs.alert", "alert = 0.99" },
    { "couverture contre le moteur", "if model_covered ~= engine_covered then", "if false then" },
  }
  local caught, total = 0, 0
  local dir = (os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"):gsub("\\", "/")
  local function play(src, name)
    local tmp = dir .. "/reseau_mut_" .. name .. ".lua"
    local out = assert(io.open(tmp, "wb"))
    out:write(src)
    out:close()
    local ok = os.execute('lua5.2 tests/reseau_runtime_test.lua --src "' .. tmp .. '" > NUL 2>&1')
    os.remove(tmp)
    return ok == true
  end
  -- témoin : la copie intacte passe (sinon « mutant vu » ne voudrait rien dire)
  if not play(SRC, "temoin") then
    print("  ECHEC : la copie intacte du runtime ne passe pas le test rejoué")
    fails = fails + 1
  end
  for k, m in ipairs(MUT) do
    local i, j = SRC:find(m[2], 1, true)
    total = total + 1
    if not i then
      print("  ECHEC : mutant du runtime sans motif : " .. m[1])
      fails = fails + 1
    elseif play(SRC:sub(1, i - 1) .. m[3] .. SRC:sub(j + 1), tostring(k)) then
      print("  ECHEC : mutant du runtime NON vu : " .. m[1])
      fails = fails + 1
    else
      caught = caught + 1
    end
  end
  print(string.format("[RESEAU-RUNTIME] mutants refuses : %d sur %d", caught, total))
end

print(string.format("[RESEAU-RUNTIME] BILAN : %d OK, %d ECHEC(S)", oks, fails))
os.exit(fails == 0 and 0 or 1)
