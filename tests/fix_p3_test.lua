--[[
  FIX-P3 (audit statique) : test pur des quatre failles de la recherche.
    1. B.weights : famille « armee » × 1,5 quand l'équipe est menacée ;
    2. Gen.keep_current : tourelle fermée et recherche en cours autre que la sienne : Gen.choose décide ;
    3. Gen.V_OTHER = 0 : une technologie sans usage n'a plus de note positive ; Gen.fallback garde son prérequis ;
    4. Gen.V_LOG = 30, comme Gen.V_MACHINE.
  Catalogue synthétique (noms abstraits, aucun nom du jeu). Usage : lua5.2 tests/fix_p3_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local B = require("shared.ai3.buts")
local Gen = require("shared.ai3.general")

local fails = 0
local function check(cond, msg)
  if cond then print("OK   " .. msg) else fails = fails + 1; print("ECHEC " .. msg) end
end

-- 1. Menace
local calm = B.weights({}, {}, false)
local hot = B.weights({}, {}, true)
check(hot.armee == math.floor(calm.armee * 3 / 2), "1. armee x1,5 sous menace (" .. calm.armee .. " -> " .. hot.armee .. ")")
check(hot.recherche == calm.recherche and hot.extraction == calm.extraction and hot.defense == calm.defense and hot.capital == calm.capital,
  "1. les autres familles ne bougent pas")
check(B.weights({}, {}).armee == calm.armee, "1. sans l'argument : comportement d'avant")
check(hot.armee <= B.W_MAX, "1. plafond B.W_MAX tenu")

-- 2. Garde de la recherche en cours
check(Gen.keep_current("ta", "tdef", true) == false, "2. tourelle fermee, autre recherche : Gen.choose decide")
check(Gen.keep_current("tdef", "tdef", true) == true, "2. la recherche de la tourelle est gardee")
check(Gen.keep_current("ta", "tdef", false) == true, "2. tourelle ouverte : recherche en cours gardee")
check(Gen.keep_current("ta", nil, true) == true, "2. pas de technologie de defense connue : gardee")

-- 3 et 4. Valeurs
local function cat_of(role)
  return {
    techs = { t = { unlocks = { "r" }, prerequisites = {}, bonus = {} } },
    products = { r = { "x" } }, role = { x = role },
    g = { unlocked_by = { r = "t" }, recipes = { r = {} }, machine = { x = true } },
  }
end
local ev = { feas = { x = true } }
local state = { techs = {} }
local v_other = Gen.value(cat_of(nil), ev, state, "t", { weights = {} })
check(v_other == 0, "3. technologie sans usage : valeur 0 (" .. tostring(v_other) .. ")")
check(Gen.V_OTHER == 0, "3. Gen.V_OTHER = 0")
local v_log = Gen.value(cat_of("logistique"), ev, state, "t", { weights = {} })
local v_mac = Gen.value(cat_of("machine"), ev, state, "t", { weights = {} })
check(v_log == 30 and v_log == v_mac, "4. logistique = machine = 30 (" .. tostring(v_log) .. ", " .. tostring(v_mac) .. ")")

-- 3. Gen.fallback : la technologie de valeur nulle qui ouvre une branche est prise.
local cat = { tech_list = { "a", "b", "c" }, techs = {
  a = { prerequisites = {} }, b = { prerequisites = {} }, c = { prerequisites = { "b" } } } }
local saved = Gen.cost
Gen.cost = function() return 10 end
local fb = Gen.fallback(cat, {}, { techs = {} }, { "a", "b" }, 1)
Gen.cost = saved
check(fb.tech == "b" and fb.opens == 1, "3. Gen.fallback garde le prerequis (" .. tostring(fb.tech) .. ")")

if fails > 0 then print(fails .. " echec(s)"); os.exit(1) end
print("fix_p3_test : tout vert")
