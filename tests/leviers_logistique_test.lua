--[[
  Lot VIDEO-COUVERTURE 3 (C05, critère C3.5) : valeur LOGISTIQUE d'un module de productivité, test hors jeu de Lv.logistic_term et de son
  branchement dans les options « equiper » de shared/ai3/leviers.lua. Lancement, depuis la racine du mod :
    lua5.2 tests/leviers_logistique_test.lua   -> [LEVIERS-LOGI] BILAN : N OK, 0 ECHEC(S)
  Critère C3.5 : le gain d'un module de productivité avec et sans terme logistique ; l'ordre des options ne change que si le terme dépasse 5 %.
    §1 le terme (voyages évités × coût d'un voyage) et son seuil de 5 % ;
    §2 l'ordre de deux options : inchangé sous 5 %, retourné au-dessus ;
    §3 branché dans Ca.decide : prix du travail faible = gain d'avant au chiffre près ; prix du travail fort = gain d'avant + terme ;
    §4 mutants (substitution dans la source de leviers.lua).
  Ce fichier est du TEST : il nomme les prototypes (comme le moteur) ; la règle n'en voit rien.
]]
package.path = "./?.lua;" .. package.path
local C = require("tests.leviers_common")
local Lv = require("shared.ai3.leviers")
local Ca = require("shared.ai3.capitalisation")

local pass, fail = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1 if not quiet then print("[LEVIERS-LOGI] ECHEC : " .. msg) end end
  return cond
end
local function say(s) if not quiet then print("[LEVIERS-LOGI] " .. s) end end
local function near(a, b, e) return a ~= nil and b ~= nil and math.abs(a - b) <= (e or 1e-6) end

---------------------------------------------------------------------------------------------------
-- §1 Le terme
---------------------------------------------------------------------------------------------------
local TRIP_S = 2 * 56 / 8 + 10                                   -- 24 s : Ca.DIST, Ca.WALK, Ca.HANDLE_S
check(near(TRIP_S, 2 * Ca.DIST / Ca.WALK + Ca.HANDLE_S), "§1 un voyage = 2 x distance / marche + manutention (24 s) comme Ca.work_of")
check(Lv.LOGI_MIN_PCT == 5, "§1 seuil de 5 %")
-- 100 objets non portés par minute, charge 100 : 1 voyage par minute ; à lambda = 25 MU par PNJ-minute : 24 s = 0,4 min = 10 MU.
local kept, raw = Lv.logistic_term(100, 100, 100, TRIP_S, 25)
check(near(raw, 10) and near(kept, 10), "§1 1 voyage/min a 25 MU/PNJ-min : 10 MU/min (" .. tostring(raw) .. ")")
-- sous 5 % du gain de base : brut calculé, retenu nul
kept, raw = Lv.logistic_term(100, 100, 100, TRIP_S, 10)
check(near(raw, 4) and kept == 0, "§1 4 % du gain : brut 4, retenu 0")
-- au seuil exact : non retenu (strictement au-dessus de 5 %)
kept = Lv.logistic_term(100, 100, 100, TRIP_S, 12.5)
check(kept == 0, "§1 exactement 5 % : non retenu")
kept, raw = Lv.logistic_term(100, 100, 100, TRIP_S, 12.6)
check(kept > 0 and near(kept, raw), "§1 5,04 % : retenu en entier")
-- le terme suit les voyages : charge double = voyages divisés par deux
local _, r2 = Lv.logistic_term(100, 100, 200, TRIP_S, 25)
check(near(r2, 5), "§1 charge de 200 par voyage : 5 MU/min")
-- gardes : pas de gain de base, rien d'évité, données invalides = 0
check(Lv.logistic_term(0, 100, 100, TRIP_S, 25) == 0 and Lv.logistic_term(-5, 100, 100, TRIP_S, 25) == 0, "§1 sans gain de base : aucune option purement logistique")
check(Lv.logistic_term(100, 0, 100, TRIP_S, 25) == 0, "§1 rien d'evite : 0")
check(Lv.logistic_term(100, 100, 0, TRIP_S, 25) == 0 and Lv.logistic_term(100, 100, 100, 0, 25) == 0 and Lv.logistic_term(100, 100, 100, TRIP_S, 0) == 0,
  "§1 charge, duree ou prix du travail nuls : 0")
check(Lv.logistic_term(100, 0 / 0, 100, TRIP_S, 25) == 0 and Lv.logistic_term(100, nil, 100, TRIP_S, 25) == 0 and Lv.logistic_term(nil, 100, 100, TRIP_S, 25) == 0,
  "§1 NaN ou valeur absente : 0")

---------------------------------------------------------------------------------------------------
-- §2 L'ordre des options (retour T = coût ÷ gain : plus le gain est grand, plus l'option passe tôt)
---------------------------------------------------------------------------------------------------
local function order_of(opts, with_term)
  local list = {}
  for _, o in ipairs(opts) do
    local kept2 = Lv.logistic_term(o.gain, o.saved, 100, TRIP_S, 25)
    list[#list + 1] = { key = o.key, g = o.gain + (with_term and kept2 or 0) }
  end
  table.sort(list, function(a, b) if a.g ~= b.g then return a.g > b.g end return a.key < b.key end)
  local out = {}
  for _, x in ipairs(list) do out[#out + 1] = x.key end
  return table.concat(out, ",")
end
-- A : gain 100 et 30 objets/min évités (brut 3 MU = 3 %) ; B : gain 102 sans voyage évité.
local close = { { key = "A", gain = 100, saved = 30 }, { key = "B", gain = 102, saved = 0 } }
check(order_of(close, false) == "B,A" and order_of(close, true) == "B,A", "§2 terme de 3 % : l'ordre ne change pas (B,A)")
-- A' : 80 objets/min évités (brut 8 MU = 8 %) : A passe devant B.
local far = { { key = "A", gain = 100, saved = 80 }, { key = "B", gain = 102, saved = 0 } }
check(order_of(far, false) == "B,A" and order_of(far, true) == "A,B", "§2 terme de 8 % : l'ordre change (A devant B)")

---------------------------------------------------------------------------------------------------
-- §3 Branchement dans Ca.decide
---------------------------------------------------------------------------------------------------
local D0 = C.data()
local function fours_reserves(kind)
  if kind == "fours" then return "fours du QG nourris par les PNJ : decideur SCALE" end
  return nil
end
local function stock()
  return { ["electronic-circuit"] = 1000, ["speed-module"] = 0, ["productivity-module"] = 40, ["speed-module-2"] = 0,
    ["productivity-module-2"] = 40, ["effectivity-module"] = 0, ["iron-plate"] = 400 }
end
local SINK_CABLE, CAP_CABLE = 1440, 6 * 180
-- La scène « tous les sites interdits » de tests/leviers_test.lua (assembleurs de câbles).
local function scene()
  return C.input(D0, {
    stock = stock(),
    deposits = { { id = "d1", resource = "copper-ore", tiles = 270, amount = 1e6, open = true, dist = 60, danger = true } },
    drills = { { entity = "electric-mining-drill", resource = "copper-ore", n = 6, deposit = "d1" } },
    machines = { { entity = "assembling-machine-2", recipe = "copper-cable", n = 6, where = "qg" } },
    flows = { ["copper-ore"] = { made = 180 }, ["copper-plate"] = { made = 180 }, ["copper-cable"] = { made = 360 } },
    sinks = { { item = "copper-cable", rate = SINK_CABLE } }, can_exec = fours_reserves })
end
local function find(res, pat)
  for _, o in ipairs(res.orders) do if o.key:find(pat, 1, true) then return o end end
  return nil
end
local KEY = "equiper:assembling-machine-2:copper-cable"

local function decide(CaX, lambda)
  local saved_price = CaX.labor_price
  if lambda then CaX.labor_price = function() return lambda end end
  local ok, res = pcall(CaX.decide, scene(), {})
  CaX.labor_price = saved_price
  assert(ok, res)
  return res
end

-- Gain de base recalculé comme tests/leviers_test.lua §3 : sortie utile x valeur - énergie.
local function base_gain_of(o)
  return math.min(o.d_out, SINK_CABLE - CAP_CABLE) * D0.mu["copper-cable"] - (o.d_kw * 60 / D0.fuel_kj) * D0.mu[D0.fuel]
end
-- Ingrédients non portés : n machines x 90 plaques/min (60 x 0,75 / 0,5 s) x vitesse 0,96 x (121 - 100) / 100 (barème D-17, 2 modules).
local function saved_of(o) return o.n * 90 * 0.96 * (121 - 100) / 100 end

local function s3(CaX, label)
  local lo = decide(CaX, nil)
  local olo = find(lo, KEY)
  if not olo then check(false, label .. " §3 ordre absent") return end
  say(string.format("%s : prix du travail par defaut lambda=%.4f : gain %.4f, terme logistique %s (brut %.4f)", label, lo.lambda, olo.gain,
    tostring(olo.logi), saved_of(olo) / 100 * lo.lambda * TRIP_S / 60))
  check(olo.module == "productivity-module" and olo.n >= 1, label .. " §3 module de productivite choisi")
  local g0 = base_gain_of(olo)
  local brut = saved_of(olo) / 100 * lo.lambda * TRIP_S / 60
  if brut * 100 <= g0 * 5 then
    check(olo.logi == nil and near(olo.gain, g0), label .. " §3 prix du travail du jeu : terme sous 5 %, gain d'avant au chiffre pres (" .. olo.gain .. " contre " .. g0 .. ")")
  else
    check(near(olo.gain, g0 + brut, 1e-6), label .. " §3 prix du travail du jeu : terme retenu")
  end
  -- prix du travail tres bas : jamais de terme
  local lo2 = decide(CaX, 0.001)
  local o2 = find(lo2, KEY)
  check(o2 and o2.logi == nil and near(o2.gain, base_gain_of(o2)), label .. " §3 prix du travail bas : gain d'avant au chiffre pres")
  -- prix du travail fort : terme retenu, gain = base + terme
  local hi = decide(CaX, 60)
  local oh = find(hi, KEY)
  check(oh ~= nil, label .. " §3 prix du travail fort : l'ordre existe")
  if oh then
    local want = saved_of(oh) / 100 * 60 * TRIP_S / 60
    check(oh.logi ~= nil and near(oh.logi, want, 1e-6), string.format("%s §3 prix du travail fort : terme %.4f = voyages evites x cout d'un voyage (%.4f)", label, oh.logi or -1, want))
    check(near(oh.gain, base_gain_of(oh) + want, 1e-6), label .. " §3 gain = gain d'avant + terme")
    check(oh.logi and oh.logi * 100 > base_gain_of(oh) * 5, label .. " §3 le terme retenu depasse 5 % du gain d'avant")
    check(oh.why:find("voyages evites", 1, true) ~= nil, label .. " §3 le compte rendu cite les voyages evites")
    check(near(oh.T, (oh.cost_m + hi.lambda * oh.work / 60) / oh.gain, 1e-9), label .. " §3 retour = cout / gain (terme compris)")
  end
end
s3(Ca, "regle")

---------------------------------------------------------------------------------------------------
-- §4 Mutants
---------------------------------------------------------------------------------------------------
local function read_all(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end
local LV_SRC = read_all("shared/ai3/leviers.lua")
local function mutate(old, new)
  local i, j = LV_SRC:find(old, 1, true)
  assert(i, "mutant : motif introuvable : " .. old)
  assert(not LV_SRC:find(old, j + 1, true), "mutant : motif ambigu : " .. old)
  return LV_SRC:sub(1, i - 1) .. new .. LV_SRC:sub(j + 1)
end
--- Exécute les contrôles §1 à §3 contre la source mutée ; rend vrai si au moins un contrôle échoue ou plante.
local function killed_by(src)
  local chunk = assert(load(src, "@leviers_mutant"))
  local saved = { package.loaded["shared.ai3.leviers"], package.loaded["shared.ai3.capitalisation"] }
  package.loaded["shared.ai3.leviers"] = chunk()
  package.loaded["shared.ai3.capitalisation"] = nil
  local CaM = require("shared.ai3.capitalisation")
  local LvM = package.loaded["shared.ai3.leviers"]
  local f0, p0, q0 = fail, pass, quiet
  quiet = true
  local ok = pcall(function()
    local kept, raw = LvM.logistic_term(100, 100, 100, TRIP_S, 10)
    check(near(raw, 4) and kept == 0, "m1")
    check(LvM.logistic_term(100, 100, 100, TRIP_S, 12.5) == 0, "m2")
    check(near(select(2, LvM.logistic_term(100, 100, 200, TRIP_S, 25)), 5), "m3")
    check(LvM.logistic_term(0, 100, 100, TRIP_S, 25) == 0, "m4")
    s3(CaM, "mutant")
  end)
  local dead = (not ok) or fail > f0
  fail, pass, quiet = f0, p0, q0
  package.loaded["shared.ai3.leviers"], package.loaded["shared.ai3.capitalisation"] = saved[1], saved[2]
  return dead
end
local MUT = {
  { "seuil de 5 % retire (tout terme retenu)", "raw * 100 <= base_gain * Lv.LOGI_MIN_PCT", "false" },
  { "seuil de 5 % inverse (retenu seulement sous 5 %)", "raw * 100 <= base_gain * Lv.LOGI_MIN_PCT", "raw * 100 > base_gain * Lv.LOGI_MIN_PCT" },
  { "charge d'un voyage ignoree", "local raw = saved_per_min / trip_load * lambda * trip_s / 60", "local raw = saved_per_min * lambda * trip_s / 60" },
  { "duree d'un voyage ignoree", "local raw = saved_per_min / trip_load * lambda * trip_s / 60", "local raw = saved_per_min / trip_load * lambda / 60" },
  { "prix du travail ignore", "local raw = saved_per_min / trip_load * lambda * trip_s / 60", "local raw = saved_per_min / trip_load * trip_s / 60" },
  { "terme jamais ajoute au gain", "if logi > 0 then o.gain, o.logi = o.gain + logi, logi end", "if logi > 0 then o.logi = logi end" },
  { "terme ajoute sans etre note", "if logi > 0 then o.gain, o.logi = o.gain + logi, logi end", "if logi > 0 then o.gain = o.gain + logi end" },
  { "ingredients evites sans la productivite (toute l'entree)", "k * e.per * s_eff / 100 * (p_n - p_o) / p_o", "k * e.per * s_eff / 100" },
  { "ingredients evites sans la vitesse", "k * e.per * s_eff / 100 * (p_n - p_o) / p_o", "k * e.per * (p_n - p_o) / p_o" },
  { "gain sans gain de base compte (option purement logistique)", "or base_gain <= 0 or", "or" },
}
local n_dead = 0
for _, m in ipairs(MUT) do
  local dead = killed_by(mutate(m[2], m[3]))
  if dead then n_dead = n_dead + 1 else say("mutant NON refuse : " .. m[1]) end
  check(dead, "mutant refuse : " .. m[1])
end
print(string.format("[LEVIERS-LOGI] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refuses sur %d)", pass, fail, n_dead, #MUT))
os.exit(fail == 0 and 0 or 1)
