--[[
  Tests hors jeu du lot TV-ENERGIE (couverture de la TODO vidéo, 8/11) : points G41, G65 et W02 (chaîne statique ; la règle est dans tests/ai3_capitalisation_test.lua §21).
  Usage :   lua5.2 tests/tv_energie_test.lua
  Chaque règle pure a ses mutants (un mutant doit faire échouer au moins un contrôle).
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
end
local function section(name) if not quiet then print("== " .. name) end end
local function read_file(path) local fh = assert(io.open(path, "rb")); local s = fh:read("*a"); fh:close(); return s end
local function between(src, a_mark, b_mark)
  local a = assert(src:find(a_mark, 1, true), "repere absent : " .. a_mark)
  local b = assert(src:find(b_mark, a, true), "repere absent : " .. b_mark)
  return src:sub(a, b - 1)
end

local build_src = read_file("script/team/build.lua")
local arms_src = read_file("script/team/plant_arms.lua")

---------------------------------------------------------------------------------------------------
-- G65 : unité de secours en crise d'énergie (shared/team/centrale.lua)
---------------------------------------------------------------------------------------------------
local function g65(C, Cv)
  section("G65-1. crise et unité de secours (règle pure)")
  local free = { done = 1, pending = 0, refused = 0, hold = false, off = false }
  local function with(over) local n = {}; for k, v in pairs(free) do n[k] = v end; for k, v in pairs(over) do n[k] = v end; return n end
  local crisis, why = C.crisis({ sat = 0 }, with({ lost = true }))
  check(crisis == true and why == "perte", "crise : la centrale est perdue")
  crisis, why = C.crisis({ sat = C.HOLD_PASS }, with({ hold = true }))
  check(crisis == true and why == "repli", "crise : saturation depuis HOLD_PASS relevés pendant le repli de l'équipe")
  check(C.crisis({ sat = C.HOLD_PASS - 1 }, with({ hold = true })) == false, "pas de crise : saturation plus courte que HOLD_PASS pendant le repli")
  check(C.crisis({ sat = 500 }, with({ hold = false })) == false, "pas de crise : saturée longtemps mais sans repli (croissance ordinaire)")
  check(C.crisis({ sat = 0 }, with({})) == false, "pas de crise : rien de perdu")

  -- en crise : la plus petite unité, jamais le champ
  check(C.growth({ saturated = false, sat = 0 }, with({ lost = true, built = 6 })) == 1,
    "centrale perdue, six chaudières vivantes mesurées : l'unité de secours (" .. C.SECOURS_BOILERS .. "), pas un champ de 3")
  check(C.growth({ saturated = true, sat = C.HOLD_PASS }, with({ hold = true, built = 8 })) == 1,
    "saturée pendant le repli (crise de matière), huit chaudières : l'unité de secours, pas le champ de 4")
  -- hors crise : le champ comme avant
  check(C.growth({ saturated = true, sat = 10 }, with({ built = 8 })) == 4, "saturée sans crise, huit chaudières : champ de 4 (inchangé)")
  local nb, w = C.growth({ saturated = true, sat = 10 }, with({ hold = true, built = 8 }))
  check(nb == nil and w == "repli de l'equipe (manque de matiere)", "repli court (sat < HOLD_PASS) : on attend toujours (inchangé)")
  -- plafond par crise
  nb, w = C.growth({ saturated = false, sat = 0 }, with({ lost = true, secours_n = 3 }))
  check(nb == nil and w == "unites de secours epuisees pour cette crise", "plafond de secours par crise : " .. tostring(w))
  check(C.growth({ saturated = false, sat = 0 }, with({ lost = true, secours_n = 2 })) == 1, "un secours de moins que le plafond : permis")
  -- les garde-fous valent aussi pour le secours
  nb, w = C.growth({ saturated = false, sat = 0 }, with({ lost = true, pending = 1 }))
  check(nb == nil and w == "un chantier de centrale est ouvert", "un chantier est ouvert : pas un second secours")
  check(C.growth({ saturated = false, sat = 0 }, with({ lost = true, off = true })) == nil, "réglage de banc no_grow : pas de secours")
  check(C.growth({ saturated = false, sat = 0 }, with({ lost = true, cool = true })) == nil, "pause après un refus : pas de secours")
  check(C.growth({ saturated = false, sat = 0 }, with({ lost = true, refused = C.MAX_REFUSED })) == nil, "plan refusé MAX_REFUSED fois : pas de secours")
  -- fin de crise
  check(Cv.down(100, 10) == true and Cv.down(100, 60) == false and Cv.down(0, 0) == false and Cv.down(nil, 0) == false,
    "Cv.down : capacité vivante sous la moitié du prévu = en panne ; rien de prévu = jamais")
end

local C0 = dofile("shared/team/centrale.lua")
local Cv0 = dofile("shared/team/champ_vapeur.lua")
g65(C0, Cv0)

section("G65-2. chaîne : PA.watch réel (moteur simulé), Build.grow_plant")
do
  log = log or function() end
  package.preload["script.team.stock"] = package.preload["script.team.stock"] or function() return { count = function() return 0 end } end
  package.preload["script.team.centrale_mort"] = package.preload["script.team.centrale_mort"] or function() return {} end
  local PA = require("script.team.plant_arms")
  local logs = {}
  local old_log = log
  log = function(s) logs[#logs + 1] = s end
  local alive = {}
  local power = 0
  local surface = { find_entity = function(name, pos)
    if alive[name .. ":" .. pos[1]] then
      return { valid = true, force = { name = "f" }, energy_generated_last_tick = (name == "steam-engine") and power or 0,
        get_fuel_inventory = function() return { is_empty = function() return false end } end }
    end
    return nil
  end }
  local plant = { id = 1, state = "fini", finished = 10, spec = { gen = "steam" },
    ents = { { name = "boiler", x = 1, y = 0 }, { name = "steam-engine", x = 2, y = 0 }, { name = "steam-engine", x = 3, y = 0 } } }
  local f = { key = "t", force = "f", build = { plant = 1, projects = { [1] = plant }, order = { 1 }, opts = {} } }
  local tick, asked, secours = 0, nil, nil
  local function run(n) for _ = 1, n do tick = tick + PA.WATCH_EVERY; asked, _, secours = PA.watch(f, surface, tick); if asked then return true end end return false end
  for _, e in ipairs(plant.ents) do alive[e.name .. ":" .. e.x] = true end
  -- saturation ordinaire (les deux machines produisent leur capacité) : le champ, pas le secours
  power = 900 * 1000 / 60
  check(run(C0.SAT_CHECKS + 2) == true and asked >= 2 and secours == false, "saturée sans crise : un champ (" .. tostring(asked) .. "), pas de secours (" .. tostring(secours) .. ")")
  check(f.build.grow.secours_n == nil or f.build.grow.secours_n == 0, "aucun secours compté hors crise")
  -- la centrale est détruite : après 3 min sans machine, l'unité de secours
  alive = {}; power = 0
  plant.state, plant.reopened, plant.reopened_tick = "reserve", 1, tick
  check(run(Cv0.LOSS_CHECKS_TOTAL - 1) == false, "avant 3 min sans machine : rien")
  check(run(1) == true and asked == 1 and secours == true, "3 min sans machine : l'unité de secours (" .. tostring(asked) .. ", secours " .. tostring(secours) .. ")")
  check(f.build.grow.secours_n == 1, "le secours est compté pour cette crise")
  local line
  for _, l in ipairs(logs) do if l:find("UNITE DE SECOURS", 1, true) then line = l end end
  check(line ~= nil and line:find("centrale perdue", 1, true) and line:find("secours 1 sur " .. C0.SECOURS_MAX, 1, true), "journal [FO-ENERGIE] : unité de secours demandée, cause et compte")
  log = old_log
  -- côté Build : le projet demandé est marqué secours
  check(build_src:find("local nb, stale, secours = PlantArms.watch(f, surface, tick)", 1, true) ~= nil
    and build_src:find("if nb then Build.grow_plant(f, nb, tick, secours) end", 1, true) ~= nil, "build.lua : le relevé de la centrale dit si la demande est un secours")
  check(build_src:find("b.projects[id].secours = secours or nil", 1, true) ~= nil, "Build.grow_plant : le projet est marqué secours (projet distinct)")
  check(arms_src:find("local crisis, crisis_why = C.crisis(g, { lost = lost, hold = hold })", 1, true) ~= nil and arms_src:find("secours_n = g.secours_n", 1, true) ~= nil,
    "plant_arms : la crise et le compte des secours entrent dans la décision")
end

---------------------------------------------------------------------------------------------------
-- G41 : la première expansion est l'énergie (shared/team/energie_dabord.lua, Build.request)
---------------------------------------------------------------------------------------------------
local function g41(E)
  section("G41-1. règle pure")
  check(E.expansion({ gen = "smelter" }) and E.expansion({ site = "petrole" }) and E.expansion({ key = "gabarit" }), "module, site, gabarit : des expansions")
  for _, k in ipairs({ "bench", "enceinte", "ilot", "alim", "liaison", "raccord", "walls", "plant", "quartier" }) do
    local spec = { gen = "smelter" }
    spec[k] = true
    check(not E.expansion(spec), "« " .. k .. " » n'est pas une expansion")
  end
  check(E.decide({ gen = "steam", args = { 1 }, plant = true }, { plant = nil }) == false, "la centrale elle-même (spec.plant) n'est pas une expansion")
  check(not E.expansion(nil) and not E.expansion("x") and not E.expansion({}), "demande absente, illisible ou vide : pas une expansion")
  local must, why = E.decide({ gen = "smelter" }, { plant = nil })
  check(must == true and why:find("energie d'abord", 1, true), "première expansion sans centrale : la centrale d'abord")
  check(E.decide({ gen = "smelter" }, { plant = 3 }) == false, "centrale déjà demandée : rien")
  check(E.decide({ gen = "smelter" }, { plant = nil, off = true }) == false, "réglage de banc no_energie_dabord : rien")
  check(E.decide({ gen = "smelter" }, nil) == false, "état absent : rien (fermé)")
  check(E.decide({ enceinte = true }, { plant = nil }) == false, "enceinte sans centrale : rien (on protège d'abord)")
  local was = E.ON
  E.ON = false
  check(E.decide({ gen = "smelter" }, { plant = nil }) == false, "règle coupée (E.ON = false) : comportement d'avant")
  E.ON = was
  check(E.line("t", 3600, { gen = "smelter" }, 1):find("[FO-ENERGIE-DABORD] t : premiere expansion", 1, true) ~= nil, "ligne de journal")
end

local E0 = dofile("shared/team/energie_dabord.lua")
g41(E0)

section("G41-2. Build.request réel (code extrait de build.lua)")
local function request_world(E)
  local src = between(build_src, "function Build.request(f, spec)", "--- Lot AGENCEMENT : le gabarit")
  local logs = {}
  local Build = { Ene = E, PRIO = 55 }
  Build.enable = function(f) f.build = { next_id = 1, projects = {}, order = {}, opts = {} } return f.build end
  Build.plant = function(f, pole)
    local b = f.build
    if b.plant then return b.plant end
    local id = Build.request(f, { gen = "steam", args = { 1 }, pole = pole, plant = true })
    b.plant = id
    local order = { id }
    for _, x in ipairs(b.order) do if x ~= id then order[#order + 1] = x end end
    b.order = order
    return id
  end
  local env = { Build = Build, game = { tick = 7200 }, log = function(s) logs[#logs + 1] = s end }
  local chunk = assert(load(src, "request", "t", setmetatable(env, { __index = _G })))
  chunk()
  return Build, logs
end
local function g41_request(E)
  local Build, logs = request_world(E)
  local f = { key = "t", build = { next_id = 1, projects = {}, order = {}, opts = {} } }
  local id = Build.request(f, { gen = "smelter", args = { 1 } })
  local b = f.build
  check(b.plant ~= nil and b.plant ~= id and b.order[1] == b.plant and b.projects[b.plant].spec.gen == "steam",
    "première expansion : la centrale est demandée AVANT et placée en tête (plant " .. tostring(b.plant) .. ", expansion " .. tostring(id) .. ")")
  check(b.order[2] == id and #logs == 1 and logs[1]:find("[FO-ENERGIE-DABORD]", 1, true), "l'expansion suit la centrale ; une ligne de journal")
  Build.request(f, { gen = "smelter", args = { 2 } })
  check(#logs == 1 and (b.energie_dabord or 0) == 1, "deuxième expansion : la centrale existe, rien de plus")
  local f2 = { key = "u", build = { next_id = 1, projects = {}, order = {}, opts = { no_energie_dabord = true } } }
  Build.request(f2, { gen = "smelter" })
  check(f2.build.plant == nil, "réglage de banc : aucune centrale d'office")
  local f3 = { key = "v", build = { next_id = 1, projects = {}, order = {}, opts = {} } }
  Build.request(f3, { enceinte = true, walls = {} })
  Build.request(f3, { alim = 1 })
  Build.request(f3, { gen = "labs", bench = "manque-labo" })
  check(f3.build.plant == nil, "enceinte, alimentation, demande de banc : aucune centrale d'office")
  local f4 = { key = "w", build = { next_id = 1, projects = {}, order = {}, opts = {} } }
  Build.request(f4, { gen = "steam", args = { 1 }, plant = true })
  check(f4.build.plant == 1 and f4.build.energie_dabord == nil, "la demande de la centrale elle-même : pas de récursion")
end
g41_request(E0)
check(build_src:find('Build.Ene = require("shared.team.energie_dabord")', 1, true) ~= nil, "build.lua : Build.Ene (champ de Build, pas une locale)")
check(build_src:find("spec.bench = \"remote\"", 1, true) ~= nil, "remote fo-ia1d request : une demande de banc ne déclenche pas la règle")

---------------------------------------------------------------------------------------------------
-- W02 : chaîne statique (la règle pure : tests/ai3_capitalisation_test.lua §21, tests/plafonds_test.lua §16)
---------------------------------------------------------------------------------------------------
section("W02. chaîne statique")
do
  local capi_src = read_file("script/ai3/capitalisation.lua")
  local pure = read_file("shared/ai3/capitalisation.lua")
  check(capi_src:find("power = Capi.power_input(f, plant_state, plant_why, wait_plant)", 1, true) ~= nil, "build_input : l'état de la centrale entre dans le relevé du courant")
  check(capi_src:find("return { amorce = true", 1, true) ~= nil and capi_src:find("return { fermee = ", 1, true) ~= nil, "Capi.power_input : plus de nil sans centrale finie")
  check(pure:find("function Ca.spend_amorce(ctx, plan, o)", 1, true) ~= nil and pure:find("Ca.spend_amorce(ctx, plan, o)\n", 1, true) ~= nil, "Ca.apply consomme l'amorce")
  check(capi_src:find("[FO-CAPI-COURANT]", 1, true) ~= nil, "journal [FO-CAPI-COURANT] (une ligne par cause)")
end

---------------------------------------------------------------------------------------------------
-- Déficit de kW (diagnostic azure, 8/11) : centrale de plus tout de suite quand des kW sont retenus avec de l'épargne qui dort
---------------------------------------------------------------------------------------------------
local function gdef(C, Cv, S)
  section("DEFICIT-1. règle pure")
  check(S.deficit({ kw = 1170, tick = 1000, bank = 10912 }, 1000) == 1170, "kW retenus + épargne de 10 912 MU : déficit de 1170 kW")
  check(S.deficit({ kw = 1170, tick = 1000, bank = 299 }, 1000) == 0, "épargne sous 300 MU : pas de déficit (pas d'argent pour la centrale)")
  check(S.deficit({ kw = 1170, tick = 1000 }, 1000) == 0 and S.deficit({ kw = 1170, tick = 1000, bank = "9999" }, 1000) == 0
    and S.deficit({ kw = 1170, tick = 1000, bank = 0 / 0 }, 1000) == 0, "épargne absente, texte ou NaN : pas de déficit (garde fermée)")
  check(S.deficit({ kw = 1170, tick = 1000, bank = 5000 }, 1000 + 2 * 3600 + 1) == 0, "kW retenus périmés (plus de 2 min) : pas de déficit")
  check(S.deficit(nil, 1000) == 0 and S.deficit({ kw = 0, tick = 1000, bank = 5000 }, 1000) == 0, "rien de retenu : pas de déficit")
  local st = {}
  check(not C.deficit_track(st, true) and not C.deficit_track(st, true) and C.deficit_track(st, true), "déficit installé au 3e relevé de suite")
  check(not C.deficit_track(st, false) and st.def_n == 0, "un relevé sans déficit remet le compte à zéro")
  check(C.deficit_size(1170, 1800) == 1 and C.deficit_size(3540, 1800) == 2 and C.deficit_size(99999, 1800) == Cv.MAX_FIELD, "taille : 1170 kW -> 1, 3540 kW -> 2, borné par le champ")
  check(C.deficit_size(3540, 1800, 1) == 1 and C.deficit_size(3540, 1800, 0, 1) == 1 and C.deficit_size(3540, nil) == C.BOILERS, "un refus de moins ; voie de tapis ; chaudière inconnue : C.BOILERS")
  local free = { done = 1, pending = 0, refused = 0, hold = false, off = false }
  local function with(over) local n = {}; for k, v in pairs(free) do n[k] = v end; for k, v in pairs(over) do n[k] = v end; return n end
  local nb, why = C.growth({ saturated = false, sat = 0, def_n = 2 }, with({ deficit_kw = 1170, boiler_kw = 1800, built = 1 }))
  check(nb == nil and why == "pas saturee", "déficit depuis 2 relevés seulement : rien")
  nb = C.growth({ saturated = false, sat = 0, def_n = 3 }, with({ deficit_kw = 1170, boiler_kw = 1800, built = 1 }))
  check(nb == 1, "déficit installé (3 relevés), centrale d'une chaudière, 1170 kW : UNE chaudière (pas le champ de 2) : " .. tostring(nb))
  nb = C.growth({ saturated = false, sat = 0, def_n = 3 }, with({ deficit_kw = 3540, boiler_kw = 1800, built = 1 }))
  check(nb == 2, "déficit de 3540 kW : deux chaudières")
  nb, why = C.growth({ saturated = false, sat = 0, def_n = 3 }, with({ deficit_kw = 1170, boiler_kw = 1800, pending = 1 }))
  check(nb == nil and why == "un chantier de centrale est ouvert", "un chantier de centrale est ouvert : une seule à la fois")
  nb, why = C.growth({ saturated = false, sat = 0, def_n = 3 }, with({ deficit_kw = 1170, boiler_kw = 1800, hold = true }))
  check(nb == nil and why == "repli de l'equipe (manque de matiere)", "repli de l'équipe (matière affamée) : le déficit attend aussi")
  check(C.growth({ saturated = false, sat = 0, def_n = 3 }, with({ deficit_kw = 1170, boiler_kw = 1800, off = true })) == nil, "réglage de banc no_grow : rien")
  check(C.growth({ saturated = false, sat = 0, def_n = 3 }, with({ deficit_kw = 1170, boiler_kw = 1800, cool = true })) == nil, "pause après un refus : rien")
  check(C.growth({ saturated = false, sat = 0, def_n = 3 }, with({ deficit_kw = 1170, boiler_kw = 1800, lost = true })) == 1, "centrale perdue ET déficit : le secours (1), la crise passe devant")
  check(C.growth({ saturated = true, sat = 10, def_n = 3 }, with({ deficit_kw = 1170, boiler_kw = 1800, built = 8 })) == 4, "saturée : le champ ordinaire (le déficit ne change pas la saturation)")
  local s2 = { def_n = 3 }
  C.requested(s2)
  check(s2.def_n == 0, "la demande partie remet le compte du déficit à zéro")
end

local Sx0 = dofile("shared/team/sante_centrale.lua")
gdef(C0, Cv0, Sx0)

section("DEFICIT-2. PA.watch réel (moteur simulé)")
do
  log = log or function() end
  package.preload["script.team.stock"] = package.preload["script.team.stock"] or function() return { count = function() return 0 end } end
  package.preload["script.team.centrale_mort"] = package.preload["script.team.centrale_mort"] or function() return {} end
  local PA = require("script.team.plant_arms")
  local logs = {}
  local old_log = log
  log = function(s) logs[#logs + 1] = s end
  local alive = {}
  local PROD = 3000 -- J/tick produits par chaque machine a vapeur vivante (lot CC-ENERGIE, F491 : la demande mesurée change au fil du test)
  local surface = { find_entity = function(name, pos)
    if alive[name .. ":" .. pos[1]] then
      return { valid = true, force = { name = "f" }, energy_generated_last_tick = (name == "steam-engine") and PROD or 0,
        get_fuel_inventory = function() return { is_empty = function() return false end } end }
    end
    return nil
  end }
  local plant = { id = 1, state = "fini", finished = 10, spec = { gen = "steam" },
    ents = { { name = "boiler", x = 1, y = 0 }, { name = "steam-engine", x = 2, y = 0 }, { name = "steam-engine", x = 3, y = 0 } } }
  local f = { key = "t", force = "f", team = { capi = {} }, build = { plant = 1, projects = { [1] = plant }, order = { 1 }, opts = {} } }
  for _, e in ipairs(plant.ents) do alive[e.name .. ":" .. e.x] = true end
  local tick, asked = 0, nil
  local function run(n, bank)
    for _ = 1, n do
      tick = tick + PA.WATCH_EVERY
      f.team.capi.kw_blocked = { kw = 500, tick = tick, bank = bank }
      asked = PA.watch(f, surface, tick)
      if asked then return true end
    end
    return false
  end
  -- 6000 J/tick produits sur 30000 de capacité (20 %) : ni saturée ni avance (0,6 x 500 kW de retenu < 70 %)
  check(run(Cv0.LOSS_CHECKS, 50) == false, "kW retenus mais épargne de 50 MU : pas de centrale de plus")
  check(run(2, 5000) == false, "déficit avec épargne, 2 relevés : pas encore")
  -- lot CC-ENERGIE (F491, règle du DC) : le déficit installé ne fait plus grandir une centrale dont la demande MESURÉE reste sous 75 %
  check(run(1, 5000) == false, "F491 : 3e relevé, déficit installé, demande mesurée 360 kW sur 1 800 (20 %) : AUCUNE centrale")
  local held
  for _, l in ipairs(logs) do if l:find("croissance RETENUE", 1, true) then held = l end end
  check(held ~= nil and held:find("(20 %", 1, true) and held:find("seuil 75 %", 1, true) and held:find("deficit 500 kW", 1, true),
    "F491 : journal [FO-ENERGIE] croissance RETENUE : charge, seuil et déclencheur écarté (" .. tostring(held) .. ")")
  check(run(20, 5000) == false, "F491 : le déficit dure 20 relevés à 20 % : toujours aucune centrale")
  local n_held = 0
  for _, l in ipairs(logs) do if l:find("croissance RETENUE", 1, true) then n_held = n_held + 1 end end
  check(n_held == 1, "F491 : une seule ligne RETENUE par épisode (" .. n_held .. ")")
  PROD = 11400 -- 22 800 J/tick sur 30 000 : 76 %, au-dessus du seuil
  check(run(1, 5000) == true and asked == 1, "demande mesurée 76 %, déficit installé : une centrale d'UNE chaudière est demandée (" .. tostring(asked) .. ")")
  local line
  for _, l in ipairs(logs) do if l:find("DEFICIT de kW", 1, true) then line = l end end
  check(line ~= nil and line:find("500 kW retenus", 1, true) and line:find("1 chaudiere(s)", 1, true), "journal [FO-ENERGIE] : DEFICIT de kW, kW retenus et taille")
  check(f.build.grow.def_n == 0, "le compte du déficit repart à zéro après la demande")
  -- une seule centrale par déficit : le projet demandé est en chantier, le déficit dure, aucune seconde demande
  f.build.extra_plants = { 2 }
  f.build.projects[2] = { id = 2, state = "chantier", spec = { gen = "steam" }, ents = {} }
  check(run(30, 5000) == false, "déficit qui dure pendant que la centrale demandée est en chantier : AUCUNE seconde demande (30 relevés)")
  -- lot ELECTRIQUE (e, demande de tv-energie) : chantier aux machines CONNUES (1 800 kW) et déficit durable de 5 000 kW : une seconde demande
  -- (en parallèle) ; deux chantiers ouverts : JAMAIS une troisième, même sur un déficit énorme (borne contre un pending_kw trop petit)
  do
    local function kw_run(n, kw)
      for _ = 1, n do
        tick = tick + PA.WATCH_EVERY
        f.team.capi.kw_blocked = { kw = kw, tick = tick, bank = 5000 }
        asked = PA.watch(f, surface, tick)
        if asked then return true end
      end
      return false
    end
    local engines = { { name = "boiler", x = 11, y = 0 }, { name = "steam-engine", x = 12, y = 0 }, { name = "steam-engine", x = 13, y = 0 } }
    f.build.projects[2].ents = engines
    -- F491 : le chantier ouvert compte dans la capacité : 22 800 J/tick sur 30 000 bâtis + 30 000 en chantier = 38 % : rien en parallèle
    check(kw_run(10, 5000) == false, "F491 E1 : demande 1 368 kW sur 1 800 bâtis + 1 800 en chantier (38 %) : AUCUN chantier en parallèle")
    -- centrale finie de 16 machines (14 400 kW) à 97 % : 232 000 J/tick sur 240 000 + 30 000 en chantier = 86 %, déficit de 5 000 kW
    for i = 4, 17 do plant.ents[#plant.ents + 1] = { name = "steam-engine", x = i, y = 0 }; alive["steam-engine:" .. i] = true end
    PROD = 14500
    f.build.grow.cool_until = 0
    check(kw_run(10, 5000) == true and asked ~= nil and asked >= 2,
      "E1 : déficit de 5 000 kW, demande 86 % avec le chantier ouvert de 1 800 kW : chantier EN PARALLELE de " .. tostring(asked) .. " chaudière(s)")
    local par
    for _, l in ipairs(logs) do if l:find("EN PARALLELE", 1, true) then par = l end end
    check(par ~= nil, "E1 : journal [FO-ENERGIE] centrale EN PARALLELE")
    f.build.extra_plants = { 2, 3 }
    f.build.projects[3] = { id = 3, state = "chantier", spec = { gen = "steam" }, ents = engines }
    f.build.grow.cool_until = 0
    PROD = 15000 -- 240 000 J/tick sur 240 000 + 60 000 en chantier = 80 % : la garde du DC passe, la borne des chantiers seule retient
    check(kw_run(40, 50000) == false, "E2 : deux chantiers ouverts, déficit de 50 000 kW durable (40 relevés) : AUCUNE troisième demande")
    f.build.projects[3] = nil
    for _ = 4, 17 do plant.ents[#plant.ents] = nil end
    PROD = 11400
    f.build.extra_plants = { 2 }
    f.build.projects[2].ents = {}
  end
  -- lot FIX-P1 : plus de borne C.MAX_REQUESTS sur la partie (C.COOL et C.MAX_REFUSED bornent)
  f.build.extra_plants, f.build.projects[2] = nil, nil
  f.build.grow.requests = C0.MAX_REQUESTS
  f.build.grow.cool_until = 0
  check(run(10, 5000) == true, "C.MAX_REQUESTS atteint : la demande passe encore (lot FIX-P1), déficit, demande mesurée 76 %")
  f.build.extra_plants, f.build.projects[2] = nil, nil
  PROD = 3000
  tick = tick + PA.WATCH_EVERY -- (F491 : un relevé à 20 % sans retenu remet à zéro l'avance comptée pendant les phases à 76-100 %)
  f.team.capi.kw_blocked = nil
  PA.watch(f, surface, tick)
  -- l'avance interrompue s'écrit (hypothèse du compteur d'anticipation, diagnostic azure)
  f.build.grow.requests = 0
  logs[#logs + 1] = "-- avance --"
  for _ = 1, 3 do
    tick = tick + PA.WATCH_EVERY
    f.team.capi.kw_blocked = { kw = 2000, tick = tick, bank = 0 }
    PA.watch(f, surface, tick)
  end
  tick = tick + PA.WATCH_EVERY
  f.team.capi.kw_blocked = nil
  PA.watch(f, surface, tick)
  local broken
  for _, l in ipairs(logs) do if l:find("avance de la centrale de plus INTERROMPUE", 1, true) then broken = l end end
  check(broken ~= nil and broken:find("apres 3 releve(s)", 1, true), "avance de 3 relevés puis chute : la ligne [FO-SANTE-CENTRALE] « avance INTERROMPUE » écrit les chiffres (" .. tostring(broken) .. ")")
  log = old_log
end

local function bilan()
  print(string.format("[TV-ENERGIE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
end

---------------------------------------------------------------------------------------------------
-- Mutants (règles pures G65 et G41)
---------------------------------------------------------------------------------------------------
section("Mutants")
local function mutant(label, edit)
  local Cc = dofile("shared/team/centrale.lua")
  local Cm = dofile("shared/team/champ_vapeur.lua")
  local Em = dofile("shared/team/energie_dabord.lua")
  edit(Cc, Cm, Em)
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(function() g65(Cc, Cm) g41(Em) end)
  quiet = false
  local caught = failures > f0 or not ok
  passes, failures = p0, f0
  check(caught, "mutant refusé : " .. label)
end
mutant("secours = champ (C.SECOURS_BOILERS = 4)", function(Cc) Cc.SECOURS_BOILERS = 4 end)
mutant("crise ignorée", function(Cc) Cc.crisis = function() return false, nil end end)
mutant("crise = perte seule", function(Cc) local old = Cc.crisis; Cc.crisis = function(st, n) return old(st, { lost = n.lost }) end end)
mutant("crise de repli dès le premier relevé", function(Cc) Cc.HOLD_PASS = 0 end)
mutant("plafond de secours ignoré", function(Cc) Cc.SECOURS_MAX = 1000 end)
mutant("plafond de secours à 1", function(Cc) Cc.SECOURS_MAX = 1 end)
mutant("capacité vivante jamais en panne", function(_, Cm) Cm.down = function() return false end end)
mutant("énergie d'abord coupée", function(_, _, Em) Em.ON = false end)
mutant("la centrale est une expansion", function(_, _, Em) local old = Em.decide; Em.decide = function(s, st) return old(s, { plant = st and st.plant, off = st and st.off }) end end)
mutant("l'enceinte est une expansion", function(_, _, Em) Em.NOT_EXPANSION = { "bench" } end)
mutant("réglage de banc ignoré", function(_, _, Em) local old = Em.decide; Em.decide = function(s, st) return old(s, { plant = st and st.plant }) end end)
mutant("centrale déjà demandée ignorée", function(_, _, Em) local old = Em.decide; Em.decide = function(s, st) return old(s, { plant = nil, off = st and st.off }) end end)

local function mutant_def(label, edit)
  local Cc = dofile("shared/team/centrale.lua")
  local Cm = dofile("shared/team/champ_vapeur.lua")
  local Sm = dofile("shared/team/sante_centrale.lua")
  edit(Cc, Cm, Sm)
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(gdef, Cc, Cm, Sm)
  quiet = false
  local caught = failures > f0 or not ok
  passes, failures = p0, f0
  check(caught, "mutant refusé : " .. label)
end
mutant_def("épargne ignorée (DEFICIT_BANK = 0)", function(_, _, Sm) Sm.DEFICIT_BANK = 0 end)
mutant_def("déficit dès le premier relevé", function(Cc) Cc.DEFICIT_CHECKS = 1 end)
mutant_def("déficit jamais", function(_, _, Sm) Sm.deficit = function() return 0 end end)
mutant_def("déficit pris pour le champ (taille ordinaire)", function(Cc, Cm) Cc.deficit_size = function() return Cm.MIN_FIELD end end)
mutant_def("compte du déficit jamais remis à zéro", function(Cc) Cc.deficit_track = function(st, flag) st.def_n = (st.def_n or 0) + 1 return st.def_n >= Cc.DEFICIT_CHECKS end end)
mutant_def("taille bornée à 1", function(Cc) Cc.deficit_size = function() return 1 end end)

bilan()
os.exit(failures == 0 and 0 or 1)
