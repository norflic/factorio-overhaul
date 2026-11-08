--[[
  Tests hors jeu du lot TV-ENERGIE (couverture de la TODO vidéo, 8/11) : points G41, G65, V36 (règle du tampon de vapeur : aussi dans
  tests/charbon_centrale_test.lua), W02 (chaîne statique ; la règle est dans tests/ai3_capitalisation_test.lua §21) et V89.
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
  for _, k in ipairs({ "bench", "enceinte", "ilot", "alim", "liaison", "raccord", "walls" }) do
    local spec = { gen = "smelter" }
    spec[k] = true
    check(not E.expansion(spec), "« " .. k .. " » n'est pas une expansion")
  end
  check(not E.expansion({ gen = "steam", args = { 1 } }), "la centrale elle-même n'est pas une expansion")
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
    local id = Build.request(f, { gen = "steam", args = { 1 }, pole = pole })
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
  Build.request(f4, { gen = "steam", args = { 1 } })
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
-- V89 : dégradation graduée (shared/faction/degrade.lua, Cd.skip, Commander, Lourd.depth)
---------------------------------------------------------------------------------------------------
local function v89(Dg, Cd)
  section("V89-1. niveaux et hystérésis (règle pure, aucun temps mesuré)")
  check(Dg.target(0) == 0 and Dg.target(3) == 0 and Dg.target(4) == 1 and Dg.target(8) == 2 and Dg.target(13) == 2 and Dg.target(14) == 3 and Dg.target(99) == 3,
    "profondeur 0, 3, 4, 8, 13, 14, 99 : niveaux 0, 0, 1, 2, 2, 3, 3")
  check(Dg.target(nil) == 0 and Dg.target("12") == 0 and Dg.target(0 / 0) == 0, "profondeur absente, texte ou NaN : niveau 0 (garde fermée)")
  local st = {}
  local lvl, ch = Dg.update(st, 5)
  check(lvl == 0 and not ch, "une lecture haute ne suffit pas")
  Dg.update(st, 5)
  lvl, ch = Dg.update(st, 5)
  check(lvl == 1 and ch, "3 lectures de suite au seuil : niveau 1")
  Dg.update(st, 20) Dg.update(st, 20)
  lvl = Dg.update(st, 20)
  check(lvl == 2, "puis 3 lectures à 20 : niveau 2 (un niveau à la fois, pas de saut à 3)")
  Dg.update(st, 20) Dg.update(st, 20)
  lvl = Dg.update(st, 20)
  check(lvl == 3, "puis niveau 3")
  Dg.update(st, 20) Dg.update(st, 20) lvl = Dg.update(st, 20)
  check(lvl == 3, "plafond : niveau 3")
  Dg.update(st, 6) Dg.update(st, 6)
  check(st.level == 3, "deux lectures sous la moitié du seuil (14 / 2 = 7) : pas encore de sortie")
  Dg.update(st, 6)
  check(st.level == 2, "trois lectures de suite sous 7 : niveau 2 (hystérésis de sortie)")
  Dg.update(st, 3) Dg.update(st, 3)
  Dg.update(st, 5) -- 5 >= 8 / 2 : le compte de sortie repart
  Dg.update(st, 3) Dg.update(st, 3)
  check(st.level == 2, "une lecture au-dessus de la moitié du seuil remet le compte de sortie à zéro")
  Dg.update(st, 3)
  check(st.level == 1, "trois lectures de suite sous 4 : niveau 1")
  Dg.update(st, 1) Dg.update(st, 1) Dg.update(st, 1)
  check(st.level == 0, "retour au niveau 0")
  -- une lecture creuse au milieu de la montée remet le compte à zéro
  local s2 = {}
  Dg.update(s2, 9) Dg.update(s2, 9) Dg.update(s2, 0) Dg.update(s2, 9) Dg.update(s2, 9)
  check(s2.level == 0, "montée interrompue par une lecture basse : le compte repart")
  -- déterminisme : mêmes lectures, même suite de niveaux
  local seq = { 0, 5, 5, 5, 9, 9, 9, 15, 15, 15, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0 }
  local function play() local a, out = {}, {} for _, d in ipairs(seq) do out[#out + 1] = Dg.update(a, d) end return table.concat(out, ",") end
  check(play() == play(), "mêmes lectures, mêmes niveaux (déterminisme)")
  local was = Dg.ON
  Dg.ON = false
  local s3 = {}
  for _ = 1, 10 do Dg.update(s3, 99) end
  check(s3.level == 0, "règle coupée (Dg.ON = false) : jamais de dégradation")
  Dg.ON = was
  check(Dg.slow(600, 0) == 600 and Dg.slow(600, 1) == 900 and Dg.slow(600, 2) == 1200 and Dg.slow(600, 3) == 1800 and Dg.slow(600, nil) == 600 and Dg.slow(600, 9) == 600,
    "période de repos : 600, 900, 1200, 1800 selon le niveau ; niveau inconnu : la base")

  section("V89-2. effet sur la cadence des factions (Cd.skip)")
  local calm = { is_player = false, box = { x0 = 0, y0 = 0, x1 = 10, y1 = 10 }, players = {}, army_out = false }
  local fst = { last = 0 }
  check(Cd.skip(fst, calm, 599) == true, "loin et calme, 599 ticks après la dernière pensée : sautée (niveau 0)")
  check(Cd.skip(fst, calm, 600) == false, "loin et calme, 600 ticks : pense (niveau 0)")
  check(Cd.skip(fst, calm, 600, Dg.slow(Cd.SLOW, 1)) == true and Cd.skip(fst, calm, 900, Dg.slow(Cd.SLOW, 1)) == false, "niveau 1 : repos de 900 ticks")
  check(Cd.skip(fst, calm, 1799, Dg.slow(Cd.SLOW, 3)) == true and Cd.skip(fst, calm, 1800, Dg.slow(Cd.SLOW, 3)) == false, "niveau 3 : repos de 1800 ticks")
  -- jamais ralenti : éveillée pour une cause
  local slow3 = Dg.slow(Cd.SLOW, 3)
  check(Cd.skip({ last = 0 }, { is_player = true, box = calm.box, players = {}, army_out = false }, 100, slow3) == false, "votre équipe : jamais ralentie")
  check(Cd.skip({ last = 0 }, { is_player = false, box = calm.box, players = { { x = 5, y = 5 } }, army_out = false }, 100, slow3) == false, "joueur proche : jamais ralentie")
  check(Cd.skip({ last = 0 }, { is_player = false, box = calm.box, players = {}, army_out = false, threatened_until = 500 }, 100, slow3) == false, "menace : jamais ralentie")
  check(Cd.skip({ last = 0 }, { is_player = false, box = calm.box, players = {}, army_out = true }, 100, slow3) == false, "armée dehors : jamais ralentie")
  check(Cd.skip({ last = 0 }, { is_player = false, box = calm.box, players = {}, army_out = false, lost_t = 50 }, 100, slow3) == false, "perte récente : jamais ralentie")
end

local Dg0 = dofile("shared/faction/degrade.lua")
local Cd0 = dofile("shared/faction/cadence.lua")
v89(Dg0, Cd0)

section("V89-3. chaîne : Lourd.depth réel, Commander (code réel), journal")
do
  local store = {}
  local saved_events, saved_storage = package.loaded["script.core.events"], package.loaded["script.core.storage"]
  package.loaded["script.core.lourd"] = nil
  package.loaded["script.core.events"] = { on = function() end, on_init = function() end, on_configuration_changed = function() end }
  package.loaded["script.core.storage"] = {
    declare = function(name, init) store[name] = store[name] or init() end,
    ns = function(name) return store[name] end,
  }
  local J = require("script.core.lourd")
  J.reset()
  check(J.depth() == 0, "file vide : profondeur 0")
  -- 5 demandeurs qui veulent tous le budget entier : un seul passe par tick, les autres font la file
  local served = 0
  for i = 1, 5 do if J.take(100, "q" .. i) then served = served + 1 end end
  check(served == 1 and J.depth() == 4, "5 demandeurs au même tick : 1 servi, file de 4 (" .. J.depth() .. ")")
  J.reset()
  check(J.depth() == 0, "reset : file vide")
  package.loaded["script.core.lourd"] = nil
  package.loaded["script.core.events"], package.loaded["script.core.storage"] = saved_events, saved_storage
  local cmd = read_file("script/faction/commander.lua")
  check(cmd:find("local skip, why = Cd.skip(cs, inp, tick, Commander.slow())", 1, true) ~= nil, "Commander.think : la période de repos suit le niveau")
  check(cmd:find("if tick % Commander.DEGRADE_EVERY == 0 then Commander.degrade(tick) end", 1, true) ~= nil, "Commander.guard : une lecture de la file par seconde de jeu")
  check(cmd:find("local depth = Lourd.depth()", 1, true) ~= nil and cmd:find('Storage.declare("degrade"', 1, true) ~= nil, "Commander.degrade : lit la file, état dans global (ns degrade)")
  check(cmd:find("log(Dg.line(", 1, true) ~= nil, "journal [FO-DEGRADE] à chaque changement de niveau")
  check(Dg0.line({ from = 0, to = 1, tick = 3600, depth = 5, slow = 900, base = 600 }):find("[FO-DEGRADE] niveau 0 -> 1 a 1.0 min", 1, true) ~= nil, "ligne de journal")
  check(read_file("script/core/lourd.lua"):find("function J.depth()", 1, true) ~= nil, "lourd.lua : J.depth")
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
  local Dm = dofile("shared/faction/degrade.lua")
  local Cdm = dofile("shared/faction/cadence.lua")
  edit(Cc, Cm, Em, Dm, Cdm)
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(function() g65(Cc, Cm) g41(Em) v89(Dm, Cdm) end)
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
mutant("la centrale est une expansion", function(_, _, Em) local old = Em.expansion; Em.expansion = function(s) return old(s) or (type(s) == "table" and s.gen == "steam") end end)
mutant("l'enceinte est une expansion", function(_, _, Em) Em.NOT_EXPANSION = { "bench" } end)
mutant("réglage de banc ignoré", function(_, _, Em) local old = Em.decide; Em.decide = function(s, st) return old(s, { plant = st and st.plant }) end end)
mutant("centrale déjà demandée ignorée", function(_, _, Em) local old = Em.decide; Em.decide = function(s, st) return old(s, { plant = nil, off = st and st.off }) end end)

mutant("dégradation coupée", function(_, _, _, Dm) Dm.ON = false end)
mutant("niveau en un coup (3 lectures ignorées)", function(_, _, _, Dm) Dm.CHECKS = 1 end)
mutant("seuils à 1", function(_, _, _, Dm) Dm.ENTER = { 1, 1, 1 } end)
mutant("seuils jamais atteints", function(_, _, _, Dm) Dm.ENTER = { 1000, 2000, 3000 } end)
mutant("multiplicateurs nuls", function(_, _, _, Dm) Dm.MULT = { 1, 1, 1, 1 } end)
mutant("pas d'hystérésis de sortie (sortie dès le seuil)", function(_, _, _, Dm)
  local old = Dm.update
  Dm.update = function(st, depth) local l, c = old(st, depth); if Dm.target(depth) < l then st.level = Dm.target(depth) end return st.level, c end
end)
mutant("profondeur illisible comptée comme charge", function(_, _, _, Dm) Dm.target = function() return 3 end end)
mutant("repos ignoré par Cd.skip", function(_, _, _, _, Cdm)
  local old = Cdm.skip
  Cdm.skip = function(st, s, tick) return old(st, s, tick, nil) end
end)
mutant("votre équipe ralentie", function(_, _, _, _, Cdm)
  local old = Cdm.awake
  Cdm.awake = function(s, tick) s.is_player = false return old(s, tick) end
end)

bilan()
os.exit(failures == 0 and 0 or 1)
