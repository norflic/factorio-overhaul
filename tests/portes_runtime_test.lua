--[[
  Lot VIDEO-L6, étape 6 de VIDEO-INTEG : branchement des portes avant d'étendre dans le runtime de la capitalisation
  (script/ai3/capitalisation.lua : Capi.portes, decide_finish, Capi.slots) et dans la vue (script/team/team.lua : view.backlog).
  Moteur simulé (tests/mock_engine.lua). Lancer depuis la racine du mod :
    lua5.2 tests/portes_runtime_test.lua   -> [L6-RT] BILAN : N OK, 0 ECHEC(S)
  §1 réglage absent ou éteint : aucune porte (la décision d'avant) ; §2 réglage allumé, 2 PNJ et 16 tâches libres : fermée à la 2e
  décision, chantiers retenus, levier gardé, journal [FO-PORTES] ; §3 Capi.slots compte modules posés et chantiers ouverts ; §4 câblage
  (lecture du source) ; §5 mutants du runtime.
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[L6-RT] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end

M.new_world({ p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful" })
M.load_mod()
local W = M.world()
M.dispatch(W.on_init)
local Capi = package.loaded["script.ai3.capitalisation"]
check(Capi ~= nil and type(Capi.portes) == "function", "Capi.portes charge")

local function orders()
  return { { key = "chaine:a", kind = "chaine", item = "a", n = 2 }, { key = "couvrir:b", kind = "couvrir", resource = "b", n = 3 },
    { key = "equiper:c", kind = "equiper", item = "c", n = 4 }, { key = "labos", kind = "labos", n = 1 } }
end
local D1 = { workers = 2, workers_waiting = 0, backlog = 16 }
local function n_portes_logs()
  local n = 0
  for _, l in ipairs(W.logs or {}) do if l:find("[FO-PORTES]", 1, true) then n = n + 1 end end
  return n
end

-- §1 Réglage absent (non déclaré dans settings.lua : repli à « éteint ») puis éteint.
local f = { key = "player", is_player = true, team = {} }
local cs = { slots = { batis = 10, open_sites = 0 } }
W.settings["fo-war-portes"] = nil
check(Capi.portes_on() == false, "§1 reglage absent : eteint (repli)")
check(Capi.portes(f, cs, { orders = orders() }, D1, 300) == nil and cs.portes == nil, "§1 reglage absent : aucune porte, aucun etat")
W.settings["fo-war-portes"] = false
check(Capi.portes(f, cs, { orders = orders() }, D1, 600) == nil, "§1 reglage eteint : aucune porte")

-- §2 Réglage allumé : 2 PNJ, 0 libre, 16 tâches libres.
W.settings["fo-war-portes"] = true
local l0 = n_portes_logs()
local w1 = Capi.portes(f, cs, { orders = orders() }, D1, 900)
check(w1 ~= nil and not w1["chaine:a"] and w1["couvrir:b"] and tostring(w1["couvrir:b"]):find("bras", 1, true) ~= nil and not w1["labos"],
  "§2 1re decision tendue : transport pas encore ferme ; seule la porte des bras retient le 2e chantier (10 poses : 1 chantier)")
local w2 = Capi.portes(f, cs, { orders = orders() }, D1, 1200)
check(w2 and w2["chaine:a"] and w2["couvrir:b"] and w2["labos"] and not w2["equiper:c"],
  "§2 2e decision : chantiers et laboratoires retenus, levier garde")
check(w2 and tostring(w2["chaine:a"]):find("transport sature", 1, true) ~= nil, "§2 raison : transport sature")
check(cs.portes and cs.portes.closed == true and cs.portes.closes == 1, "§2 etat cs.portes : fermee, 1 fermeture")
check(n_portes_logs() - l0 == 2, "§2 une ligne [FO-PORTES] par decision qui retient (" .. (n_portes_logs() - l0) .. ")")
-- transport détendu (5 PNJ libres sur 10, 0 tâche) deux fois : rouverte ; porte des bras : 10 posés -> 1 chantier ouvert au plus
local calm = { workers = 10, workers_waiting = 5, backlog = 0 }
Capi.portes(f, cs, { orders = orders() }, calm, 1500)
local w3 = Capi.portes(f, cs, { orders = orders() }, calm, 1800)
check(w3 and not w3["chaine:a"] and w3["couvrir:b"] and tostring(w3["couvrir:b"]):find("bras", 1, true) ~= nil,
  "§2 rouverte : 1er chantier garde, 2e retenu par la porte des bras (1 chantier pour 10 poses)")
cs.slots = { batis = 60, open_sites = 1 }
local w4 = Capi.portes(f, cs, { orders = orders() }, calm, 2100)
check(w4 and next(w4) == nil, "§2 60 poses, 1 ouvert : 2 places, les 2 chantiers passent")
-- vue absente du backlog (ancienne vue) : mesure absente -> fermée (garde fermée par défaut)
local w5 = Capi.portes(f, cs, { orders = orders() }, { workers = 10, workers_waiting = 5 }, 2400)
check(w5 and w5["chaine:a"] ~= nil, "§2 backlog absent de la vue : porte fermee (garde fermee)")
check(M.serialize(cs.portes) ~= nil, "§2 etat serialisable")
-- manque mesuré de L3 (view.mq.build) : le même objet en manque deux décisions de suite est retenu (anti-répétition), sauf seul en manque
do
  local fm, cm = { key = "m2" }, { slots = { batis = 100, open_sites = 0 } }
  local vm = { workers = 10, workers_waiting = 5, backlog = 0, mq = { build = { a = 7, z = 3 } } }
  local om = function() return { { key = "chaine:a", kind = "chaine", item = "a", n = 1 }, { key = "chaine:q", kind = "chaine", item = "q", n = 1 } } end
  Capi.portes(fm, cm, { orders = om() }, vm, 2700)
  local wm = Capi.portes(fm, cm, { orders = om() }, vm, 3000)
  check(wm and wm["chaine:a"] and tostring(wm["chaine:a"]):find("repetition", 1, true) ~= nil and not wm["chaine:q"],
    "§2 manque mesure (L3) : meme objet deux decisions de suite retenu, objet non mesure garde")
  Capi.portes(fm, cm, { orders = om() }, vm, 3300) -- (a repasse : la décision d'avant n'avait gardé aucun objet mesuré)
  vm.mq.build = { a = 7 }
  local wm2 = Capi.portes(fm, cm, { orders = om() }, vm, 3600)
  check(wm2 and not wm2["chaine:a"], "§2 manque mesure : seul objet en manque, la repetition est permise")
end
W.settings["fo-war-portes"] = nil

-- §3 Capi.slots : modules posés et chantiers ouverts (Auto.module remplacé : états imposés).
do
  local Auto = package.loaded["script.ai3.automatisation"]
  local STATES = { [1] = "fini", [2] = "fini", [3] = "chantier", [4] = "reserve", [5] = "attente", [6] = "refuse" }
  local orig = Auto.module
  Auto.module = function(_, id) local s = STATES[id] return s and { state = s, reason = "x" } or nil end
  local fs = { key = "f1", team = { ia3 = {} }, hq_pos = { x = 0, y = 0 } }
  local css = { open = { { key = "m1", exec = "module", mod_ids = { 1, 2 } }, { key = "m2", exec = "module", mod_ids = { 3, 4, 5, 6, 7 } },
    { key = "lev", exec = "equiper" } } }
  local ok, sl = pcall(Capi.slots, fs, css, {}, 3000, nil)
  Auto.module = orig
  check(ok and sl and sl.batis == 2 and sl.open_sites == 2,
    "§3 Capi.slots : 2 poses (fini), 2 ouverts (chantier, attente), reserve, refuse et perdu exclus (" ..
    tostring(ok and sl and sl.batis) .. ", " .. tostring(ok and sl and sl.open_sites) .. (ok and "" or (" ; " .. tostring(sl))) .. ")")
end

-- §4 Câblage (lecture du source).
do
  local src = read("script/ai3/capitalisation.lua"):gsub("%-%-[^\n]*", "")
  local a = src:find("local gate_why = Capi.portes(f, cs, res, view, tick)", 1, true)
  local b = src:find("for _, o in ipairs(res.orders) do", a or 1, true)
  check(a ~= nil and b ~= nil and b > a, "§4 decide_finish : Capi.portes AVANT la boucle d'envoi")
  check(src:find('rec, why = nil, "porte L6 : " .. gw', 1, true) ~= nil, "§4 refus par le chemin existant, raison « porte L6 : »")
  check(src:find("sl.batis, sl.open_sites = batis, open_sites", 1, true) ~= nil, "§4 Capi.slots rend batis et open_sites")
  local tsrc = read("script/team/team.lua"):gsub("%-%-[^\n]*", "")
  check(tsrc:find("backlog = backlog,", 1, true) ~= nil, "§4 Team.view rend backlog")
end

-- §5 Mutants du runtime (substitution unique dans script/ai3/capitalisation.lua, fonctions rejouées sur la table chargée).
do
  local src = read("script/ai3/capitalisation.lua")
  local function body(name)
    local i = src:find("function Capi." .. name .. "(", 1, true)
    local j = src:find("\nend\n", i, true)
    return src:sub(i, j + 4)
  end
  local function mutant(name, old, new, probe)
    local b = body(name)
    local b2, n = b:gsub(old:gsub("%p", "%%%0"), (new:gsub("%%", "%%%%")))
    if n ~= 1 then return false, "introuvable" end
    -- la fonction mutée est rechargée avec les mêmes upvalues lues par le nom (Capi, Pe, Pi, settings…) via un environnement
    local env = setmetatable({ Capi = Capi, Pe = require("shared.ai3.portes_extension"), Pi = require("shared.ai3.pile"),
      PORTES_TOURS = { couvrir = true, ouvrir = true, chaine = true, packs = true, labos = true },
      minutes = function() return 0 end }, { __index = _G })
    local chunk = assert(load("local Capi, Pe, Pi, PORTES_TOURS, minutes = Capi, Pe, Pi, PORTES_TOURS, minutes\n" .. b2, "=mut", "t", env))
    local saved = Capi[name]
    chunk()
    local killed = probe()
    env.Capi[name] = saved
    Capi[name] = saved
    return killed
  end
  local function probe_with(v)
    return function()
      W.settings["fo-war-portes"] = true
      local fx, cx = { key = "m" }, { slots = { batis = 10, open_sites = 0 } }
      Capi.portes(fx, cx, { orders = orders() }, v, 300)
      local w = Capi.portes(fx, cx, { orders = orders() }, v, 600)
      W.settings["fo-war-portes"] = nil
      return not (w and w["chaine:a"] and not w["equiper:c"])
    end
  end
  local probe_d1 = probe_with(D1)
  -- Lot IA-CAPI : les PNJ libres ne ferment plus la porte ; ils restent dans la raison écrite (« 0 PNJ libre(s) sur 2 »).
  local function probe_idle()
    W.settings["fo-war-portes"] = true
    local fx, cx = { key = "m" }, { slots = { batis = 10, open_sites = 0 } }
    Capi.portes(fx, cx, { orders = orders() }, D1, 300)
    local w = Capi.portes(fx, cx, { orders = orders() }, D1, 600)
    W.settings["fo-war-portes"] = nil
    return not (w and tostring(w["chaine:a"]):find("0 PNJ libre(s) sur 2", 1, true))
  end
  local probe_backlog = probe_with({ workers = 10, workers_waiting = 3, backlog = 40 }) -- tendu par les tâches libres seulement
  local function probe_off()
    W.settings["fo-war-portes"] = nil
    local w = Capi.portes({ key = "m" }, { slots = {} }, { orders = orders() }, D1, 300)
    return w ~= nil
  end
  local MUT = {
    { "portes", "free_tasks = view.backlog", "free_tasks = 0", probe_backlog, "backlog non lu" },
    { "portes", "idle = view.workers_waiting", "idle = view.workers", probe_idle, "PNJ libres pris pour l'effectif" },
    { "portes_on", "return ok and v == true", "return true", probe_off, "reglage toujours allume" },
    { "portes", "site_kinds = Capi.MODULE_KINDS, tours_kinds = PORTES_TOURS", "site_kinds = {}, tours_kinds = {}", probe_d1, "chantiers non reconnus" },
  }
  local refused = 0
  for _, m in ipairs(MUT) do
    local ok, killed = pcall(mutant, m[1], m[2], m[3], m[4])
    killed = (not ok) or killed == true
    if killed then refused = refused + 1 else print("[L6-RT] mutant NON refuse : " .. m[5]) end
    check(killed, "§5 mutant refuse : " .. m[5])
  end
  print(string.format("[L6-RT] §5 mutants du runtime refuses : %d sur %d", refused, #MUT))
end

print(string.format("[L6-RT] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
