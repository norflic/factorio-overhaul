--[[
  Lot VIDEO-L10, étape 7 de VIDEO-INTEG : branchement de la variante B des marches de stabilité dans le runtime de la capitalisation
  (script/ai3/capitalisation.lua : Capi.palier, Capi.palier_inputs, decide_start). Moteur simulé (tests/mock_engine.lua). Lancer depuis la
  racine du mod :
    lua5.2 tests/palier_runtime_test.lua   -> [L10-RT] BILAN : N OK, 0 ECHEC(S)
  §1 réglage absent ou éteint : C2 inchangé (input.demande intact) ; §2 réglage allumé, 6 décisions (6 min) stables : une marche à la 6e,
  puits de C2 ouvert à cette décision seulement ; puis plus de marche sans pose ; une pose relance le minuteur ; §3 instabilité (manque
  mesuré, crise, aucun bras libre, L3 éteint) ; §4 traduction des entrées ; §5 câblage (lecture du source) ; §6 mutants du runtime.
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[L10-RT] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end

M.new_world({ p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful" })
M.load_mod()
local W = M.world()
M.dispatch(W.on_init)
local Capi = package.loaded["script.ai3.capitalisation"]
local Ca = require("shared.ai3.capitalisation")
check(Capi ~= nil and type(Capi.palier) == "function", "Capi.palier charge")

local MIN = 3600
local function stable_view() return { mq = { build = {} } } end
local function input_research(left) return { demande = true, research = { queue = { { left = left } } } } end
local function team(hands) return { key = "f1", team = { iag = { idle_ema = hands } } } end
-- bras libres comptés comme Capi.slots (Ca.idle_of : idle_ema en dixièmes) : idle_ema choisi pour en avoir au moins 1
local EMA = 30
check(math.floor(Ca.idle_of(EMA)) >= 1, "idle_ema " .. EMA .. " donne au moins 1 bras libre (" .. tostring(Ca.idle_of(EMA)) .. ")")

-- §1 réglage absent puis éteint
local f = team(EMA)
local cs = { slots = { batis = 5 } }
W.settings["fo-war-paliers"] = nil
local in1 = input_research(10)
check(Capi.paliers_on() == false and Capi.palier(f, cs, stable_view(), in1, 0) == nil and in1.demande == true and cs.palier == nil,
  "§1 reglage absent : aucune marche, input.demande intact (C2), aucun etat")
W.settings["fo-war-paliers"] = false
local in2 = input_research(10)
check(Capi.palier(f, cs, stable_view(), in2, 0) == nil and in2.demande == true, "§1 reglage eteint : C2 inchange")

-- §2 réglage allumé : 6 décisions stables (une par minute) -> une marche à la 6e (18 000 ticks après l'armement)
W.settings["fo-war-paliers"] = true
local marches, opened = {}, {}
for i = 0, 5 do
  local inp = input_research(10)
  local mk = Capi.palier(f, cs, stable_view(), inp, i * MIN) -- (une décision par minute)
  marches[#marches + 1] = mk and mk.kind or "-"
  opened[#opened + 1] = inp.demande and "o" or "f"
end
-- ticks 0, 3600, … 18000 : armé à 0, échu à 18 000 (6e décision)
check(table.concat(marches, ",") == "-,-,-,-,-,recherche", "§2 6 decisions stables : une marche « recherche » a la 6e (" .. table.concat(marches, ",") .. ")")
check(table.concat(opened) == "fffffo", "§2 puits de C2 ouvert a la decision de la marche seulement (" .. table.concat(opened) .. ")")
-- pas de deuxième marche sans pose
local more = 0
for i = 6, 12 do
  local inp = input_research(10)
  if Capi.palier(f, cs, stable_view(), inp, i * MIN) then more = more + 1 end
  if inp.demande then more = more + 100 end
end
check(more == 0, "§2 aucune marche ni puits sans pose apres la marche (" .. more .. ")")
-- une pose (un module de plus « fini ») relance le minuteur depuis zéro : marche 18 000 ticks après
cs.slots.batis = 6
local t_pose = 13 * MIN
Capi.palier(f, cs, stable_view(), input_research(10), t_pose)
check(cs.palier.until_tick == t_pose + 18000, "§2 pose : minuteur relance a la pose (" .. tostring(cs.palier.until_tick) .. ")")
local mk2 = Capi.palier(f, cs, stable_view(), input_research(10), t_pose + 18000)
check(mk2 ~= nil, "§2 deuxieme marche 5 min apres la pose")
-- arbre fini : la marche va à l'équipement
cs.slots.batis = 7
Capi.palier(f, cs, stable_view(), input_research(0), t_pose + 18000 + MIN)
local mk3 = Capi.palier(f, cs, stable_view(), input_research(0), t_pose + 18000 + MIN + 18000)
check(mk3 and mk3.kind == "equipement", "§2 arbre fini : marche « equipement »")
local n_log = 0
for _, l in ipairs(W.logs or {}) do if l:find("[FO-PALIER]", 1, true) then n_log = n_log + 1 end end
check(n_log >= 5, "§2 journal [FO-PALIER] (armements, annulations, marches) : " .. n_log .. " ligne(s)")

-- §3 instabilité : chaque cause jette le minuteur
local function unstable_case(view, ff, label)
  local c = { slots = { batis = 1 } }
  Capi.palier(ff or f, c, stable_view(), input_research(10), 0)
  Capi.palier(ff or f, c, view, input_research(10), 9000)
  local late = Capi.palier(ff or f, c, stable_view(), input_research(10), 18000)
  check(late == nil and (c.palier.until_tick or 0) > 18000 - 1, "§3 " .. label .. " : minuteur jete puis rearme (pas de marche a 18 000)")
end
unstable_case({ mq = { build = { x = 4 } } }, nil, "manque mesure")
unstable_case({ mq = { build = {} }, survie = true }, nil, "mode survie")
unstable_case({ mq = { build = {} }, hq_threat = true }, nil, "QG menace")
do
  local c = { slots = { batis = 1 } }
  for i = 0, 6 do Capi.palier(team(0), c, stable_view(), input_research(10), i * MIN) end
  check((c.palier.marches or 0) == 0, "§3 aucun bras libre : jamais de marche")
  local c2 = { slots = { batis = 1 } }
  for i = 0, 6 do Capi.palier(f, c2, {}, input_research(10), i * MIN) end
  check((c2.palier.marches or 0) == 0, "§3 L3 eteint (pas de view.mq) : jamais stable (garde fermee)")
end

-- §4 traduction des entrées
do
  local c = { slots = { batis = 3 }, palier = { batis_prev = 2 } }
  local a = Capi.palier_inputs(f, c, { mq = { build = { a = 2, b = 0, c = 1 } }, survie = nil, hq_threat = true }, input_research(0))
  check(a.manques == 2 and a.crise == true and a.pose == true and a.arbre_fini == true and a.bras_libres >= 1,
    "§4 entrees : 2 objets en manque, crise (QG menace), pose (2 -> 3), arbre fini, bras libres")
  local c0 = { slots = { batis = 3 }, palier = {} }
  local a0 = Capi.palier_inputs(f, c0, { mq = { build = {} } }, input_research(5))
  check(a0.pose == false and a0.manques == 0 and a0.crise == false and a0.arbre_fini == false,
    "§4 premiere decision : pas de pose (aucun releve d'avant), arbre non fini")
end

-- §5 câblage (lecture du source)
do
  local src = read("script/ai3/capitalisation.lua"):gsub("%-%-[^\n]*", "")
  local a = src:find("\n  Capi.palier(f, cs, view, input, tick)", 1, true) -- l'appel (pas la définition « function Capi.palier(… »)
  local b = src:find("local snap = {}", a or 1, true)
  local c = src:find("local input, cex = build_input(", 1, true)
  check(a and b and c and c < a and a < b, "§5 decide_start : Capi.palier apres build_input et AVANT l'instantane")
end

-- §6 mutants du runtime (fonction rechargée sur la table chargée, upvalues par l'environnement)
do
  local src = read("script/ai3/capitalisation.lua")
  local function body(name)
    local i = src:find("function Capi." .. name .. "(", 1, true)
    local j = src:find("\nend\n", i, true)
    return src:sub(i, j + 4)
  end
  local function mutant(name, old, new, probe)
    local b2, n = body(name):gsub(old:gsub("%p", "%%%0"), (new:gsub("%%", "%%%%")))
    if n ~= 1 then return false end
    local env = setmetatable({}, { __index = _G })
    local chunk = assert(load("local Capi, Pal, Ca, sorted_keys, minutes = ...\n" .. b2, "=mut", "t", env))
    local saved = Capi[name]
    chunk(Capi, require("shared.ai3.palier"), Ca, function(t) local k = {} for x in next, t or {} do k[#k + 1] = x end table.sort(k) return k end,
      function() return 0 end)
    local ok, killed = pcall(probe)
    Capi[name] = saved
    return (not ok) or killed
  end
  local function probe_pose() -- une pose doit relancer après une marche
    local c = { slots = { batis = 1 } }
    for i = 0, 5 do Capi.palier(f, c, stable_view(), input_research(10), i * MIN) end
    c.slots.batis = 2
    Capi.palier(f, c, stable_view(), input_research(10), 7 * MIN)
    local mk = Capi.palier(f, c, stable_view(), input_research(10), 7 * MIN + 18000)
    return mk == nil
  end
  local function probe_demande() -- hors marche, le puits doit rester fermé
    local c = { slots = { batis = 1 } }
    local inp = input_research(10)
    Capi.palier(f, c, stable_view(), inp, 0)
    return inp.demande == true
  end
  local function probe_crise()
    local c = { slots = { batis = 1 } }
    Capi.palier(f, c, stable_view(), input_research(10), 0)
    Capi.palier(f, c, { mq = { build = {} }, survie = true }, input_research(10), 9000)
    return Capi.palier(f, c, stable_view(), input_research(10), 18000) ~= nil
  end
  local function probe_l3() -- L3 éteint : jamais stable
    local c = { slots = { batis = 1 } }
    local any = false
    for i = 0, 6 do if Capi.palier(f, c, {}, input_research(10), i * MIN) then any = true end end
    return any
  end
  local MUT = {
    { "palier_inputs", "local pose = st.batis_prev ~= nil and batis > st.batis_prev", "local pose = false", probe_pose, "pose toujours fausse" },
    { "palier", "input.demande = (input.demande and mk ~= nil) and true or false", "input.demande = input.demande", probe_demande, "puits de C2 ouvert hors marche" },
    { "palier_inputs", "crise = (view.survie or view.hq_threat) and true or false", "crise = false", probe_crise, "crise ignoree" },
    { "palier_inputs", "local manques = nil", "local manques = 0", probe_l3, "L3 eteint compte comme « aucun manque »" },
    { "palier", "st.batis_prev = batis", "", probe_pose, "releve des poses non garde" },
  }
  W.settings["fo-war-paliers"] = true
  local refused = 0
  for _, m in ipairs(MUT) do
    local killed = mutant(m[1], m[2], m[3], m[4])
    if killed then refused = refused + 1 else print("[L10-RT] mutant NON refuse : " .. m[5]) end
    check(killed, "§6 mutant refuse : " .. m[5])
  end
  print(string.format("[L10-RT] §6 mutants du runtime refuses : %d sur %d", refused, #MUT))
end
W.settings["fo-war-paliers"] = nil

print(string.format("[L10-RT] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
