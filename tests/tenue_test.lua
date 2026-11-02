--[[
  Tests hors jeu du lot TENUE : shared/ai3/armure.lua (dégâts réels contre les résistances des unités ennemies) et son branchement dans la
  prévision (shared/ai3/prevision.lua Pv.mix, script/ai3/prevision.lua). La formule des résistances est comparée aux MESURES du moteur réel
  (tests/fixtures/tenue_armure.lua, scénario tools/autotest/fo-autotest/scenarios/tenue-armure.lua : LuaEntity.damage rend les dégâts
  appliqués).
  Usage : lua5.2 tests/tenue_test.lua
]]
package.path = "./?.lua;" .. package.path
local Ar = require("shared.ai3.armure")
local Pv = require("shared.ai3.prevision")

local passes, failures = 0, 0
local SILENCE = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 if not SILENCE then io.write("ECHEC : ", msg, "\n") end end
end
local function section(s) print("-- " .. s) end
local function near(a, b, e) return math.abs(a - b) <= (e or 1e-9) end

local function read(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

-- Mélanges synthétiques (aucun nom d'objet) : une unité sans résistance, une à (-4, 10 %), une à (-8, 10 %).
local NONE = { w = 0.5, hp = 15 }
local MID = { w = 0.3, hp = 75, res = { physical = { 4, 0.10 } } }
local BIG = { w = 0.2, hp = 375, res = { physical = { 8, 0.10 } } }

---------------------------------------------------------------------------------------------------
section("1. Ar.hit : formule des résistances")
local function hit_cases()
  local ok = true
  local function c(cond, msg) if not cond then ok = false end check(cond, msg) end
  c(near(Ar.hit(5, 0, 0), 5), "aucune résistance : le coup entier")
  c(near(Ar.hit(5, 4, 0.10), 0.9), "5 contre -4 plats et 10 % : (5 - 4) × 0,9")
  c(near(Ar.hit(20, 4, 0.10), 14.4), "20 contre -4 et 10 % : 16 × 0,9")
  c(near(Ar.hit(5, 8, 0.10), 0.18), "5 contre -8 et 10 % : 1 / (8 - 5 + 2) × 0,9")
  c(near(Ar.hit(8, 8, 0), 0.5), "un coup égal à la réduction plate : 1 / 2")
  c(near(Ar.hit(9, 8, 0), 1), "un coup d'un point au-dessus de la réduction plate : 1")
  c(Ar.hit(0, 4, 0.1) == 0 and Ar.hit(-3, 0, 0) == 0, "coup nul ou négatif : rien")
  c(near(Ar.hit(5, 0, 2), 0), "pourcentage borné à 100 %")
  c(near(Ar.hit(5, -3, -1), 5), "résistance négative : ignorée")
  c(Ar.hit(nil, nil, nil) == 0 and Ar.hit(0 / 0, 1, 1) == 0, "entrées absentes ou NaN : 0")
  return ok
end
hit_cases()

---------------------------------------------------------------------------------------------------
section("2. Ar.hit contre le moteur réel (fixture tenue_armure)")
local fx_ok, fixture = pcall(function() return dofile("tests/fixtures/tenue_armure.lua") end)
local function fixture_cases()
  local ok = true
  local function c(cond, msg) if not cond then ok = false end check(cond, msg) end
  if not (fx_ok and type(fixture) == "table" and #fixture > 0) then
    c(false, "fixture tests/fixtures/tenue_armure.lua absente ou vide : " .. tostring(fixture))
    return ok
  end
  c(#fixture >= 200, "au moins 200 coups mesurés (" .. #fixture .. ")")
  local n_phys, n_res = 0, 0
  for _, m in ipairs(fixture) do
    local calc = Ar.hit(m.d, m.flat, m.pct)
    -- le moteur renvoie un flottant : 0,5 % d'écart relatif ou 0,001 absolu
    c(math.abs(calc - m.rendu) <= math.max(0.001, 0.005 * m.rendu),
      string.format("%s %s coup %s (plat %s, pct %s) : moteur %s, règle %s", m.unit, m.type, m.d, m.flat, m.pct, m.rendu, calc))
    if m.type == "physical" then n_phys = n_phys + 1 end
    if m.flat > 0 or m.pct > 0 then n_res = n_res + 1 end
  end
  c(n_phys >= 100 and n_res >= 100, "la fixture couvre le physique et des unités à résistances (" .. n_phys .. ", " .. n_res .. ")")
  return ok
end
fixture_cases()

---------------------------------------------------------------------------------------------------
section("3. Ar.factor : efficacité contre un mélange")
local function factor_cases()
  local ok = true
  local function c(cond, msg) if not cond then ok = false end check(cond, msg) end
  c(Ar.factor(nil, 5, "physical") == 1000 and Ar.factor({}, 5, "physical") == 1000, "sans mélange : 1000")
  c(Ar.factor({ NONE }, 5, "physical") == 1000, "mélange sans résistance : 1000")
  c(Ar.factor({ NONE, MID, BIG }, 0, "physical") == 1000, "coup nul : 1000 (rien à corriger)")
  c(Ar.factor({ NONE, MID, BIG }, 5, "fire") == 1000, "autre type de dégâts : pas de résistance")
  c(Ar.factor({ NONE, MID, BIG }, 5, nil) == 1000, "type inconnu : 1000")
  -- un seul moyen : 0,9 / 5 = 18 %
  c(Ar.factor({ { w = 1, hp = 75, res = { physical = { 4, 0.10 } } } }, 5, "physical") == 180, "biter moyen seul, coup de 5 : 180 ‰")
  -- un seul gros : 0,18 / 5 = 3,6 %
  c(Ar.factor({ { w = 1, hp = 375, res = { physical = { 8, 0.10 } } } }, 5, "physical") == 36, "gros biter seul, coup de 5 : 36 ‰")
  -- harmonique pondérée par les PV : Σ w hp / Σ (w hp / r)
  local nominal = 0.5 * 15 + 0.3 * 75 + 0.2 * 375
  local reel = 0.5 * 15 / 1 + 0.3 * 75 / 0.18 + 0.2 * 375 / 0.036
  local attendu = math.floor(1000 * nominal / reel)
  c(Ar.factor({ NONE, MID, BIG }, 5, "physical") == attendu, "mélange : harmonique pondérée par les PV (" .. attendu .. ")")
  -- un coup plus fort passe mieux, jamais au-dessus de 1000
  local a, b, d = Ar.factor({ NONE, MID, BIG }, 5, "physical"), Ar.factor({ NONE, MID, BIG }, 10, "physical"), Ar.factor({ NONE, MID, BIG }, 40, "physical")
  c(a < b and b < d and d <= 1000, "plus le coup est fort, meilleur le facteur : " .. a .. " < " .. b .. " < " .. d)
  -- ordre des unités sans effet
  c(Ar.factor({ BIG, NONE, MID }, 5, "physical") == a, "l'ordre des unités ne change rien")
  -- plancher : une unité intouchable ne rend pas le facteur nul
  local inv = { { w = 1, hp = 100, res = { physical = { 1000, 0.99 } } } }
  c(Ar.factor(inv, 5, "physical") == 10, "plancher de 10 ‰ par unité")
  -- entrées inchangées
  local before = BIG.res.physical[1]
  Ar.factor({ BIG }, 5, "physical")
  c(BIG.res.physical[1] == before, "les entrées ne sont pas modifiées")
  c(Ar.scale(100, 500) == 50 and Ar.scale(100, 2000) == 100 and Ar.scale(100, -5) == 0 and Ar.scale(nil, 500) == 0, "Ar.scale borne le facteur")
  return ok
end
factor_cases()

---------------------------------------------------------------------------------------------------
section("4. Pv.mix expose les unités (poids normalisés, résistances transmises)")
local KINDS = {
  { units = { { hp = 15, cost = 4, speed = 0.2, pts = { { 0, 0.3 }, { 600, 0 } } },
      { hp = 75, cost = 20, speed = 0.24, pts = { { 200, 0 }, { 600, 0.3 } }, res = { physical = { 4, 0.10 } } } }, rate_max = 10, rate_max1 = 24 },
}
local function mix_cases()
  local ok = true
  local function c(cond, msg) if not cond then ok = false end check(cond, msg) end
  local m0, m5 = Pv.mix(KINDS, 0), Pv.mix(KINDS, 500)
  c(m0 and #m0.units == 1 and near(m0.units[1].w, 1) and m0.units[1].res == nil, "évolution 0 : un seul petit, poids 1, sans résistance")
  c(m5 and #m5.units == 2, "évolution 0,5 : deux unités")
  local s = 0
  for _, u in ipairs(m5.units) do s = s + u.w end
  c(near(s, 1, 1e-9), "poids normalisés : somme 1 (" .. s .. ")")
  c(m5.units[2].res and m5.units[2].res.physical[1] == 4, "résistance du moyen transmise")
  c(Ar.factor(m0.units, 5, "physical") == 1000 and Ar.factor(m5.units, 5, "physical") < 1000, "le mélange résistant baisse le facteur, pas le petit")
  c(Pv.mix({}, 0) == nil, "sans type de nid : nil")
  -- l'ancien contrat de Pv.mix est intact
  c(m0.pbar == 4 and m0.hbar == 15 and m0.cap == 10, "pbar, hbar et cap inchangés")
  return ok
end
mix_cases()

---------------------------------------------------------------------------------------------------
section("5. Branchement (textes des sources)")
local function wiring_cases()
  local ok = true
  local function c(cond, msg) if not cond then ok = false end check(cond, msg) end
  local rt = read("script/ai3/prevision.lua") or ""
  c(rt:find('require("shared.ai3.armure")', 1, true) ~= nil, "la prévision charge shared/ai3/armure.lua")
  c(rt:find('get(up, "resistances")', 1, true) ~= nil, "résistances lues au prototype de l'unité")
  c(rt:find("armor(tp.hit * hit_mult(force, e.name, tp.cat), tp.dtype)", 1, true) ~= nil, "chaque tourelle du site compte son coup réel")
  c(rt:find('sdps_armor = armor(sp.damage * boost, "physical")', 1, true) ~= nil, "le soldat compte son coup réel")
  c(rt:find("local fac = armor(tp.hit * hit_mult(force, T.turret, tp.cat), tp.dtype)", 1, true) ~= nil, "la tourelle de plus compte son coup réel")
  local sh = read("shared/ai3/armure.lua") or ""
  c(sh ~= "" and not sh:find("game%.") and not sh:find("[^i]pairs%("), "armure.lua est pur : ni API du jeu ni pairs")
  return ok
end
wiring_cases()

---------------------------------------------------------------------------------------------------
-- MUTANTS : chacun casse une partie de la règle et doit être refusé par au moins un contrôle.
local mix_orig = Pv.mix
local function mutant(name, patch, run)
  local saved = {}
  for k, v in pairs(Ar) do saved[k] = v end
  patch()
  local p0, f0 = passes, failures
  SILENCE = true
  local okp, res = pcall(run)
  SILENCE = false
  local killed = (not okp) or res == false
  passes, failures = p0, f0
  for k in pairs(Ar) do Ar[k] = nil end
  for k, v in pairs(saved) do Ar[k] = v end
  Pv.mix = mix_orig
  check(killed, "mutant détecté : " .. name)
end
local quiet = print
print = function() end
mutant("réduction plate ignorée", function() local f = Ar.hit Ar.hit = function(d, fl, p) return f(d, 0, p) end end, hit_cases)
mutant("pourcentage ignoré", function() local f = Ar.hit Ar.hit = function(d, fl, p) return f(d, fl, 0) end end, hit_cases)
mutant("coup sous la réduction plate : zéro", function() local f = Ar.hit Ar.hit = function(d, fl, p) if d <= fl then return 0 end return f(d, fl, p) end end, hit_cases)
mutant("coup sous la réduction plate : 1", function() local f = Ar.hit Ar.hit = function(d, fl, p) if d <= fl then return 1 * (1 - p) end return f(d, fl, p) end end, hit_cases)
mutant("pourcentage non borné", function() Ar.hit = function(d, fl, p) local a = d > fl and d - fl or 1 / (fl - d + 2) return a * (1 - p) end end, hit_cases)
mutant("moyenne arithmétique au lieu de l'harmonique", function()
  Ar.factor = function(units, hit, dtype)
    local s, w = 0, 0
    for _, u in ipairs(units or {}) do
      local r = u.res and dtype and u.res[dtype]
      local ratio = r and Ar.hit(hit, r[1], r[2]) / hit or 1
      s, w = s + u.w * u.hp * ratio, w + u.w * u.hp
    end
    return w > 0 and math.floor(1000 * s / w) or 1000
  end
end, factor_cases)
mutant("poids par les PV oublié", function()
  Ar.factor = function(units, hit, dtype)
    local nominal, real = 0, 0
    for _, u in ipairs(units or {}) do
      local r = u.res and dtype and u.res[dtype]
      local ratio = r and Ar.hit(hit, r[1], r[2]) / hit or 1
      nominal, real = nominal + u.w, real + u.w / math.max(ratio, 0.01)
    end
    return real > 0 and math.floor(1000 * nominal / real) or 1000
  end
end, factor_cases)
mutant("plancher retiré", function() Ar.FLOOR = 0 end, factor_cases)
mutant("type de dégâts ignoré", function()
  local f = Ar.factor
  Ar.factor = function(units, hit, dtype) return f(units, hit, "physical") end
end, factor_cases)
mutant("facteur non borné à 1000", function()
  local f = Ar.factor
  Ar.factor = function(units, hit, dtype) local v = f(units, hit, dtype) if v >= 1000 then return 1500 end return v end
end, factor_cases)
mutant("Pv.mix sans unités", function()
  Pv.mix = function(k, e) local m = mix_orig(k, e) if m then m.units = {} end return m end
end, mix_cases)
mutant("poids non normalisés", function()
  Pv.mix = function(k, e) local m = mix_orig(k, e) if m then for _, u in ipairs(m.units) do u.w = u.w * 3 end end return m end
end, mix_cases)
print = quiet

print(string.format("[TENUE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
