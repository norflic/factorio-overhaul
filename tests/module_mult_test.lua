--[[
  Banc hors jeu du lot MOD-1 : modules MULTIPLICATIFS (décision D-15 du Directeur Créatif, 24/10).
  Usage, depuis la racine du mod :   lua5.2 tests/module_mult_test.lua

  1. Règle pure (shared/content/module_mult.lua) : facteur voulu (produit exact, arrondi, bornes du moteur),
     complément, décomposition en modules cachés, productivité MULTIPLIÉE (D-17), énergie qui garde l'écart au
     plafond (Q-M5 B, D-17 ; logarithme en virgule fixe), déterminisme et indépendance de l'ordre, comparaison à un
     calcul flottant indépendant sur 3 000 listes et 3 000 machines complètes tirées au hasard (RNG maison).
  2. Données (lot MOD-3, D-17) : vitesse +20 % puis +10 points, productivité +10 % puis +5 points, énergie = 60 % du
     bonus, malus et pollution de la productivité et efficacité gardés, valeurs relues comme le moteur (centièmes),
     modules cachés (90, valeurs exactes), emplacements 5 + (niveau − 1), exemples à 5 et 34 modules.
  3. MUTANTS : 26 altérations du fichier de règle, chacune doit faire échouer au moins un contrôle de la partie 1.
  Le moteur réel est prouvé à part : scénario greffé « mod1-modules » (tools/autotest/fo-autotest/scenarios).
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local MM = require("shared.content.module_mult")
local M = require("shared.content.modules")
local L = require("shared.levels.config")

-- RNG maison (LCG 31 bits), déterministe.
local function rng(seed)
  local s = seed
  return function(n)
    s = (s * 1103515245 + 12345) % 2147483648
    return s % n + 1
  end
end

---------------------------------------------------------------------------------------------------
-- Partie 1 : la règle, paramétrée par la table de règle (mutants : même suite, autre table)
---------------------------------------------------------------------------------------------------
--- Facteur voulu d'après un calcul FLOTTANT indépendant : round(Π (1 + e/100) × 100), facteurs ≥ 0,2, bornes.
local function float_target(list)
  local p = 1
  for _, e in ipairs(list) do p = p * math.max(0.2, 1 + e / 100) end
  local t = math.floor(p * 100 + 0.5)
  if t < 20 then t = 20 end
  if t > 32867 then t = 32867 end
  return t, p * 100
end

local function rule_suite(R, chk)
  -- Valeurs connues (centièmes).
  local function T(list) return R.target(list) end
  chk(T({}) == 100, "aucun module : × 1,00")
  chk(T({ 50 }) == 150, "1 module +50 % : × 1,50")
  chk(T({ 50, 50 }) == 225, "2 × +50 % : × 2,25 (et non 2,00)")
  chk(T({ 50, 80, 110 }) == 567, "paliers +50, +80, +110 : × 5,67 (1,5 × 1,8 × 2,1)")
  local l14 = {}
  for _ = 1, 14 do l14[#l14 + 1] = 50 end
  chk(T(l14) == 29193, "14 × +50 % : × 291,93 (1,5^14 = 291,929…) ; obtenu " .. tostring(T(l14)))
  local l15 = {}
  for _ = 1, 15 do l15[#l15 + 1] = 50 end
  chk(T(l15) == 32867, "15 × +50 % : plafond × 328,67 (1,5^15 = 437,9)")
  chk(T({ 320, 320, 320, 320 }) == 31117, "4 × palier 10 (+320 %) : × 311,17 (4,2^4 = 311,1696)")
  chk(T({ 3, 3 }) == 106, "arrondi : 1,03 × 1,03 = 1,0609 → × 1,06")
  chk(T({ 5, 5, 5 }) == 116, "arrondi : 1,05^3 = 1,157625 → × 1,16 (moitié vers le haut)")
  chk(T({ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }) == 110, "arrondi : 1,01^10 = 1,1046 → × 1,10")
  chk(T({ -15, 50 }) == 128, "−15 % et +50 % : 0,85 × 1,5 = 1,275 → × 1,28")
  chk(T({ -80, -80 }) == 20, "plancher : 0,2 × 0,2 = 0,04 → × 0,20 (moteur : −80 %)")
  chk(T({ -95 }) == 20, "un module à −95 % compte × 0,2 (facteur plancher)")
  chk(T({ -80, 400 }) == 100, "facteur plancher 0,2 puis × 5 : × 1,00")
  chk(T({ -95, 400 }) == 100, "un module à −95 % compte × 0,2 même suivi d'un × 5 : × 1,00 (et non × 0,25)")
  chk(T({ 30, -30 }) == 91, "1,3 × 0,7 = 0,91")
  chk(T({ 32767 }) == 32867, "un module +327,67 : × 328,67")
  chk(T({ 32767, 32767 }) == 32867, "deux modules +327,67 : plafond")
  -- Compléments.
  local c, t, s = R.effect_complement({ 50, 50 })
  chk(c == 25 and t == 225 and s == 100, "complément 2 × +50 % : +25 centièmes (S 100, T 225)")
  c, t, s = R.effect_complement({ -80, -80 })
  chk(c == 80 and t == 20 and s == -160, "complément plancher : S −160, voulu −80 → +80")
  local l34 = {}
  for _ = 1, 34 do l34[#l34 + 1] = 320 end
  c, t, s = R.effect_complement(l34)
  chk(c == 32767 - 10880 and t == 32867, "34 × palier 10 : plafond, complément 32 767 − 10 880 = 21 887")
  local big = {}
  for _ = 1, 34 do big[#big + 1] = 2000 end
  c = R.effect_complement(big)
  chk(c == -32767, "complément borné à −32 767 (34 × +20 : S 68 000) ; obtenu " .. tostring(c))
  c = R.effect_complement({ -32768, -32768, -32768, 32767, 32767, 32767 })
  chk(c == 32767, "complément borné à +32 767 (S −3, plafond : 32 770 voulus) ; obtenu " .. tostring(c))
  c = R.effect_complement({ 50 })
  chk(c == 0, "un seul module : complément nul (produit = somme)")
  -- Jeu complet d'une machine (vitesse, énergie, productivité).
  local mods = { { speed = 50, consumption = 30 }, { speed = 80, consumption = 48 }, { productivity = 10, speed = -15, consumption = 80 },
    { productivity = 10, speed = -15, consumption = 80 } }
  local comp = R.complements(mods)
  -- vitesse : 1,5 × 1,8 × 0,85 × 0,85 = 1,95075 → 195 ; S = 50 + 80 − 30 = 100 ; C = −5
  chk(comp.speed.t == 195 and comp.speed.s == 100 and comp.speed.c == -5, "machine mixte : vitesse T 195, S 100, C −5 ; obtenu "
    .. tostring(comp.speed.t) .. " " .. tostring(comp.speed.s) .. " " .. tostring(comp.speed.c))
  -- énergie : 1,3 × 1,48 × 1,8 × 1,8 = 6,23376 → 623 ; S = 238 ; C = 623 − 100 − 238 = 285
  chk(comp.consumption.t == 623 and comp.consumption.c == 285, "machine mixte : énergie T 623, C 285 ; obtenu "
    .. tostring(comp.consumption.t) .. " " .. tostring(comp.consumption.c))
  chk(comp.productivity.t == 121 and comp.productivity.c == 1 and comp.productivity.s == 20,
    "productivité MULTIPLIÉE par défaut (D-17) : 1,1² = 1,21 → C +1 ; obtenu " .. tostring(comp.productivity.t))
  local compa = R.complements(mods, { productivity_multiplies = false })
  chk(compa.productivity.c == 0 and compa.productivity.t == 120, "productivité additive (réglage false) : +20 %, complément nul")
  chk(R.PRODUCTIVITY_MULTIPLIES == true, "réglage unique de la productivité : multipliée (true, D-17)")
  -- Logarithme en virgule fixe (énergie au plafond, D-17).
  local L = R.log2_fp
  chk(L(1) == 0 and L(2) == 65536 and L(1024) == 10 * 65536 and L(32768) == 15 * 65536, "log2_fp exact aux puissances de deux")
  local maxerr, mono = 0, true
  local prev = -1
  for x = 1, 40000 do
    local v = L(x)
    local err = math.abs(v / 65536 - math.log(x) / math.log(2))
    if err > maxerr then maxerr = err end
    if v < prev then mono = false end
    prev = v
  end
  chk(maxerr < 3e-5 and mono, string.format("log2_fp de 1 à 40 000 : écart au log flottant %.2e (< 3e-5), croissant", maxerr))
  -- Énergie au plafond : l'écart est gardé (Q-M5 B).
  local function rep(m, n)
    local t = {}
    for i = 1, n do t[i] = m end
    return t
  end
  local S10 = { speed = 110, consumption = 66 }
  local P10 = { productivity = 55, speed = -15, consumption = 33 }
  local E10 = { consumption = -80 }
  local c34 = R.complements(rep(S10, 34))
  local want34 = math.floor(100 * 328.67 ^ (math.log(1.66) / math.log(2.1)) + 0.5)
  chk(c34.speed.t == 32867 and math.abs(c34.consumption.t - want34) <= 1 and c34.consumption.gap,
    "34 × vitesse 10 : vitesse × 328,67, énergie × " .. want34 / 100 .. " = 328,67^(ln 1,66 / ln 2,1) ; obtenu " .. c34.consumption.t)
  chk(c34.consumption.c == c34.consumption.t - 100 - 34 * 66, "complément d'énergie au plafond = T − 100 − S")
  local same = true
  for n = 8, 40 do
    local cn = R.complements(rep(S10, n))
    if cn.consumption.t ~= c34.consumption.t or cn.speed.t ~= 32867 then same = false end
  end
  chk(same, "8 à 40 × vitesse 10 : au plafond, l'énergie ne bouge plus (un module de plus ne sert à rien et ne coûte rien)")
  local c7 = R.complements(rep(S10, 7))
  chk(c7.speed.t == 18011 and c7.consumption.t == 3473 and not c7.consumption.gap,
    "7 × vitesse 10 (sous le plafond) : vitesse × 180,11, énergie × 34,73 (produit exact, aucune correction)")
  local c34f = R.complements(rep(S10, 34), { energy_keeps_gap = false })
  chk(c34f.consumption.t == 32867, "sans la règle de l'écart (D-15) : énergie × 328,67 = vitesse (le défaut Q-M5)")
  local p34 = R.complements(rep(P10, 34))
  local wantp = math.floor(100 * math.exp(math.log(1.33) * math.log(328.67) / math.log(1.55)) + 0.5)
  chk(p34.productivity.t == 32867 and math.abs(p34.consumption.t - wantp) <= 1 and p34.speed.t == 20,
    "34 × productivité 10 : productivité × 328,67, vitesse × 0,20, énergie × " .. wantp / 100 .. " ; obtenu " .. p34.consumption.t)
  chk(p34.consumption.t < p34.productivity.t * p34.speed.t / 100,
    "34 × productivité 10 : énergie plus basse que le gain (productivité × vitesse = × 65,73)")
  local mixe = rep(S10, 30)
  for _ = 1, 4 do mixe[#mixe + 1] = E10 end
  chk(R.complements(mixe).consumption.t == 20, "30 × vitesse 10 + 4 × efficacité 10 : la part de l'efficacité n'est PAS réduite (× 0,20)")
  local m1 = rep(S10, 30)
  for _ = 1, 4 do m1[#m1 + 1] = P10 end
  local m2 = {}
  for i = #m1, 1, -1 do m2[#m2 + 1] = m1[i] end
  chk(R.complements(m1).consumption.t == R.complements(m2).consumption.t, "énergie au plafond indépendante de l'ordre des modules")
  -- Décomposition exhaustive.
  local bad, maxn = 0, 0
  for v = -32767, 32767 do
    local parts = R.decompose(v)
    local sum, seen, okp = 0, {}, true
    for _, p in ipairs(parts) do
      if seen[p.bit] or p.bit < 0 or p.bit > 14 or p.sign ~= (v > 0 and 1 or -1) then okp = false end
      seen[p.bit] = true
      sum = sum + p.sign * 2 ^ p.bit
    end
    if #parts > maxn then maxn = #parts end
    if sum ~= v or not okp then bad = bad + 1 end
  end
  chk(bad == 0, "décomposition exacte de −32 767 à +32 767 (" .. bad .. " erreur(s))")
  chk(maxn <= 15, "au plus 15 modules cachés par effet (" .. maxn .. ")")
  local names = R.beacon_modules({ speed = { c = 32767 }, consumption = { c = -32767 }, productivity = { c = 32767 } })
  chk(#names == 45 and #names <= R.BEACON_SLOTS, "pire cas : 45 modules cachés, balise de " .. tostring(R.BEACON_SLOTS) .. " emplacements")
  local d = R.decoded(names)
  chk(d.speed == 32767 and d.consumption == -32767 and d.productivity == 32767, "noms décodés = compléments")
  chk(#R.beacon_modules({ speed = { c = 0 }, consumption = { c = 0 }, productivity = { c = 0 } }) == 0
    and not R.needs_beacon({ speed = { c = 0 }, consumption = { c = 0 }, productivity = { c = 0 } }),
    "complément nul : aucune balise")
  -- Ordre indifférent, déterminisme, calcul flottant indépendant.
  local rand = rng(20261024)
  local diff_order, diff_float, near_half, out_of_bounds, recomputed = 0, 0, 0, 0, 0
  local POOL = { 50, 80, 110, 140, 170, 200, 230, 260, 290, 320, 30, 48, 66, 84, 102, 120, 138, 156, 174, 192,
    -5, -10, -15, 40, 60, 80, 90, 100, -30, -40, -50, -55, -60, -80, 4, 6, 10 }
  for _ = 1, 3000 do
    local n = rand(35) - 1
    local list = {}
    for i = 1, n do list[i] = POOL[rand(#POOL)] end
    local t1 = R.target(list)
    local perm = {}
    for i = 1, n do perm[i] = list[i] end
    for i = n, 2, -1 do
      local j = rand(i)
      perm[i], perm[j] = perm[j], perm[i]
    end
    if R.target(perm) ~= t1 then diff_order = diff_order + 1 end
    if R.target(list) ~= t1 then recomputed = recomputed + 1 end
    local tf, raw = float_target(list)
    local frac = raw - math.floor(raw)
    if math.abs(frac - 0.5) < 1e-6 and raw < 32867 then
      near_half = near_half + 1
      if math.abs(tf - t1) > 1 then diff_float = diff_float + 1 end
    elseif tf ~= t1 then
      diff_float = diff_float + 1
    end
    if t1 < 20 or t1 > 32867 then out_of_bounds = out_of_bounds + 1 end
  end
  chk(diff_order == 0, "3 000 machines : même facteur quel que soit l'ordre des modules (" .. diff_order .. " écart(s))")
  chk(recomputed == 0, "3 000 machines : même facteur au second calcul")
  chk(diff_float == 0, "3 000 machines : facteur = calcul flottant indépendant (" .. diff_float .. " écart(s) ; "
    .. near_half .. " cas à une demi-unité près)")
  chk(out_of_bounds == 0, "3 000 machines : facteur dans [× 0,20 ; × 328,67]")
  -- Machines complètes (les 30 modules du jeu, 0 à 40 par machine) : vitesse, productivité et énergie contre un calcul
  -- FLOTTANT indépendant (logarithmes naturels), règle de l'écart comprise.
  local REAL = {}
  for _, fam in ipairs(M.ORDER) do
    for k = 1, M.TIERS do
      local c = M.cents(fam, k)
      REAL[#REAL + 1] = { speed = c.speed, consumption = c.consumption, productivity = c.productivity }
    end
  end
  local function fl(e) return math.log(math.max(0.2, 1 + e / 100)) end
  local function float_machine(mods)
    local ls, lp, lc = 0, 0, 0
    local s_list, p_list = 0, 0
    for _, m in ipairs(mods) do
      if m.speed then ls = ls + fl(m.speed); s_list = s_list + 1 end
      if m.productivity then lp = lp + fl(m.productivity); p_list = p_list + 1 end
      if m.consumption then lc = lc + fl(m.consumption) end
    end
    local half = false
    local function T(l, n)
      if n == 0 then return 100 end
      local raw = math.exp(l) * 100
      if math.abs(raw - math.floor(raw) - 0.5) < 1e-6 and raw < 32867 then half = true end
      return math.max(20, math.min(32867, math.floor(raw + 0.5)))
    end
    local over_s = s_list > 0 and math.floor(math.exp(ls) * 100 + 0.5) > 32867
    local over_p = p_list > 0 and math.floor(math.exp(lp) * 100 + 0.5) > 32867
    local tc = T(lc, 1)
    if over_s or over_p then
      local rs = over_s and math.log(328.67) / ls or 1
      local rp = over_p and math.log(328.67) / lp or 1
      local y = 0
      for _, m in ipairs(mods) do
        local c = m.consumption
        if c then
          if c > 0 and (m.speed or 0) > 0 then y = y + rs * fl(c)
          elseif c > 0 and (m.productivity or 0) > 0 then y = y + rp * fl(c)
          else y = y + fl(c) end
        end
      end
      tc = math.min(tc, T(y, 1))
    end
    local ts, tp = T(ls, s_list), T(lp, p_list)
    return ts, tp, tc, over_s or over_p, half
  end
  -- RNG maison sur les bits HAUTS du LCG (les bits bas d'un LCG modulo 2^31 ont une période courte : la parité
  -- alterne à chaque tirage, ce qui corrélait les choix dans un premier jet de ce test).
  local rand2
  do
    local s = 20261025
    rand2 = function(n)
      s = (s * 1103515245 + 12345) % 2147483648
      return math.floor(s / 65536) % n + 1
    end
  end
  local bad_s, bad_p, bad_c, worst, capped, gap_bad, order_bad = 0, 0, 0, 0, 0, 0, 0
  for _ = 1, 3000 do
    local n = rand2(41) - 1
    local mods = {}
    -- tirage pondéré : une machine sur deux surtout en vitesse 8 à 10, 10 modules au moins (plafond fréquent)
    local heavy = rand2(2) == 1
    if heavy then n = 9 + rand2(31) end
    for i = 1, n do
      if heavy and rand2(4) > 1 then mods[i] = REAL[rand2(3) + 7] else mods[i] = REAL[rand2(#REAL)] end
    end
    local comp = R.complements(mods)
    local ts, tp, tc, over, half = float_machine(mods)
    if over then capped = capped + 1 end
    local tol = half and 1 or 0
    if math.abs(comp.speed.t - ts) > tol then bad_s = bad_s + 1 end
    if math.abs(comp.productivity.t - tp) > tol then bad_p = bad_p + 1 end
    local d = math.abs(comp.consumption.t - tc)
    if d > worst then worst = d end
    if d > 1 + 1e-4 * tc then bad_c = bad_c + 1 end
    -- écart gardé : machine de vitesse seule au plafond → énergie < vitesse
    local only_speed = n > 0
    for _, m in ipairs(mods) do if not (m.speed and m.speed > 0) then only_speed = false end end
    if only_speed and comp.speed.t == 32867 and comp.consumption.t >= comp.speed.t then gap_bad = gap_bad + 1 end
    local rev = {}
    for i = n, 1, -1 do rev[#rev + 1] = mods[i] end
    if R.complements(rev).consumption.t ~= comp.consumption.t then order_bad = order_bad + 1 end
  end
  chk(bad_s == 0 and bad_p == 0, "3 000 machines complètes : vitesse et productivité = calcul flottant (" .. bad_s .. ", " .. bad_p .. " écart(s))")
  chk(bad_c == 0 and capped >= 1000, string.format("3 000 machines complètes : énergie = calcul flottant de la règle de l'écart "
    .. "à 1 centième près (%d écart(s), pire %d ; %d machine(s) au plafond)", bad_c, worst, capped))
  chk(gap_bad == 0, "machines de vitesse seule au plafond : énergie plus basse que la vitesse (" .. gap_bad .. " faute(s))")
  chk(order_bad == 0, "3 000 machines complètes : énergie indépendante de l'ordre (" .. order_bad .. " écart(s))")
  -- Modules cachés.
  local all = R.all_modules()
  local uniq, exact = {}, 0
  for _, m in ipairs(all) do
    uniq[m.name] = true
    if R.engine_cents(m.value) == m.sign * 2 ^ m.bit then exact = exact + 1 end
  end
  local nu = 0
  for _ in pairs(uniq) do nu = nu + 1 end
  chk(#all == 90 and nu == 90, "90 modules cachés (3 effets × 2 signes × 15), noms uniques")
  chk(exact == 90, "valeur de chaque module caché relue comme le moteur = ±2^bit centièmes (" .. exact .. "/90)")
  chk(R.engine_cents(1.15) == 114 and R.engine_cents(0.5 + 1e-6) == 50 and R.engine_cents(-0.15) == -15
    and R.engine_cents(-0.55) == -55 and R.engine_cents(nil) == 0,
    "lecture comme le moteur : 1,15 → 114 (F190), 0,5 + ε → 50, −0,15 → −15, −0,55 → −55 (troncature vers zéro)")
  -- Valeurs RENDUES par le moteur à l'exécution (module_effects, mod1-modules passe 1, 24/10) : centièmes / 100 en
  -- flottant 32 bits ; la troncature y perdait un centième (0,48 → 47).
  chk(R.runtime_cents(0.47999998927116394) == 48 and R.runtime_cents(1.3999999761581421) == 140
    and R.runtime_cents(0.8399999737739563) == 84 and R.runtime_cents(1.0199999809265137) == 102
    and R.runtime_cents(-0.15000000596046448) == -15 and R.runtime_cents(0.039999999105930328) == 4
    and R.runtime_cents(-0.30000001192092896) == -30 and R.runtime_cents(nil) == 0,
    "lecture des valeurs rendues par le moteur (flottants 32 bits) : 0,4799999893 → 48, 1,3999999762 → 140, −0,1500000060 → −15")
  chk(R.factor_text(29193) == "291,93" and R.factor_text(105) == "1,05" and R.bonus_text(29193) == "+29093 %"
    and R.bonus_text(91) == "-9 %", "textes affichés (entiers seulement)")
end

section("Règle (shared/content/module_mult.lua)")
rule_suite(MM, check)

---------------------------------------------------------------------------------------------------
section("Données : paliers, énergie, valeurs relues comme le moteur, emplacements")
---------------------------------------------------------------------------------------------------
local want_speed = { 20, 30, 40, 50, 60, 70, 80, 90, 100, 110 }
local want_energy = { 12, 18, 24, 30, 36, 42, 48, 54, 60, 66 }
local okv = true
for k = 1, M.TIERS do
  local c = M.cents("speed", k)
  if c.speed ~= want_speed[k] or c.consumption ~= want_energy[k] or c.productivity then okv = false end
end
check(okv, "vitesse (D-17) : +20 % puis +10 points (10 paliers, vanilla compris, +110 % au palier 10) ; énergie = 60 % du bonus")
local want_prod = { 10, 15, 20, 25, 30, 35, 40, 45, 50, 55 }
local want_pen = { -5, -10, -15, -15, -15, -15, -15, -15, -15, -15 }
local want_pe = { 6, 9, 12, 15, 18, 21, 24, 27, 30, 33 }
local want_pol = { 5, 7, 10, 12, 14, 16, 18, 20, 22, 25 }
local okp = true
for k = 1, M.TIERS do
  local c = M.cents("productivity", k)
  if c.productivity ~= want_prod[k] or c.speed ~= want_pen[k] or c.consumption ~= want_pe[k] or c.pollution ~= want_pol[k] then
    okp = false
  end
end
check(okp, "productivité (D-17) : +10 % puis +5 points (+55 % au palier 10) ; énergie = 60 % du bonus ; malus de vitesse "
  .. "(−5, −10, −15 %) et pollution (+5 … +25 %) gardés")
check(M.families.speed.vanilla_overridden == true and M.families.productivity.vanilla_overridden == true
  and not M.families.effectivity.vanilla_overridden, "paliers vanilla 1 à 3 réécrits : vitesse et productivité (D-17) ; efficacité vanilla")
local bad_read = {}
for _, fam in ipairs(M.ORDER) do
  for k = 1, M.TIERS do
    local e = M.effect(fam, k)
    local c = M.cents(fam, k)
    local keys = {}
    for key in pairs(e) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
      if MM.engine_cents(e[key].bonus) ~= c[key] then
        bad_read[#bad_read + 1] = M.name(fam, k) .. "." .. key .. " " .. MM.engine_cents(e[key].bonus) .. "≠" .. tostring(c[key])
      end
    end
  end
end
check(#bad_read == 0, "les 30 modules : valeur du prototype relue comme le moteur = valeur voulue ("
  .. table.concat(bad_read, ", ") .. ")")
-- Efficacité : valeurs gardées (D-17 : « paliers inchangés »).
local want_ec = { -30, -40, -50, -55, -60, -65, -70, -75, -80, -80 }
local oke = true
for k = 1, M.TIERS do
  if M.cents("effectivity", k).consumption ~= want_ec[k] or M.cents("effectivity", k).speed then oke = false end
end
check(oke, "efficacité : −30 … −80 % gardés (plancher du moteur aux paliers 9 et 10)")
-- Indicateurs : machines de 5 modules identiques (exemples du rapport), règle complète.
local mt = M.metrics("speed", 1, 5)
check(math.abs(mt.speed - 2.49) < 1e-9 and math.abs(mt.energy - 1.76) < 1e-9,
  "5 × vitesse 1 → vitesse × 2,49 (1,2^5), énergie × 1,76 (1,12^5) ; obtenu " .. mt.speed .. ", " .. mt.energy)
mt = M.metrics("speed", 10, 5)
check(math.abs(mt.speed - 40.84) < 1e-9 and math.abs(mt.energy - 12.60) < 1e-9,
  "5 × vitesse 10 → vitesse × 40,84 (2,1^5), énergie × 12,60 (1,66^5) ; obtenu " .. mt.speed .. ", " .. mt.energy)
mt = M.metrics("speed", 10, 34)
check(math.abs(mt.speed - 328.67) < 1e-9 and mt.energy < 53 and mt.energy > 52,
  "34 × vitesse 10 → vitesse × 328,67, énergie × 52,4 (écart gardé) ; obtenu " .. mt.speed .. ", " .. mt.energy)
mt = M.metrics("productivity", 10, 5)
check(math.abs(mt.output - 0.44 * 8.95) < 1e-9 and math.abs(mt.energy - 4.16) < 1e-9,
  "5 × productivité 10 → productivité × 8,95 (1,55^5), vitesse × 0,44, énergie × 4,16 ; obtenu " .. mt.output .. ", " .. mt.energy)
-- Emplacements.
check(L.module_slots(L.by_key.assembler, 1) == 5 and L.module_slots(L.by_key.assembler, 30) == 34
  and L.module_slots(L.by_key.drill, 1) == 5 and L.module_slots(L.by_key.drill, 12) == 16,
  "emplacements : 5 au niveau 1, +1 par niveau (34 au niveau 30) ; foreuse et assembleur")
check(L.module_slots(L.by_key.furnace, 5) == nil and L.module_slots(L.by_key.gun, 5) == nil
  and L.module_slots(L.by_key.command, 3) == nil, "four en acier, tourelles, centre : aucun emplacement")

---------------------------------------------------------------------------------------------------
section("Mutants de la règle (chacun doit être refusé)")
---------------------------------------------------------------------------------------------------
local f = assert(io.open("shared/content/module_mult.lua", "rb"))
local SRC = f:read("*a")
f:close()
local MUTANTS = {
  { "facteur plancher retiré", "if f < MM.MIN_FACTOR then f = MM.MIN_FACTOR end", "" },
  { "arrondi retiré (troncature)", "if k >= 1 and (n[k] or 0) >= BASE / 2 then v = v + 1 end", "" },
  { "plafond + 1", "MM.MAX_T = 100 + 32767", "MM.MAX_T = 100 + 32768" },
  { "plancher à 0", "MM.MIN_T = 100 + MM.FLOOR", "MM.MIN_T = 0" },
  { "complément de signe faux", "local c = (t - 100) - s", "local c = (t - 100) + s" },
  { "complément non borné", "if c > MM.MAX_C then c = MM.MAX_C end", "" },
  { "complément négatif non borné", "if c < -MM.MAX_C then c = -MM.MAX_C end", "" },
  { "bit inversé", "if math.floor(v / p) % 2 == 1 then", "if math.floor(v / p) % 2 == 0 then" },
  { "bit 0 oublié", "for bit = 0, MM.BITS - 1 do\n    local p", "for bit = 1, MM.BITS - 1 do\n    local p" },
  { "productivité toujours multipliée", "if effect == \"productivity\" and not prod_mult then", "if false then" },
  { "échelle fausse", "return big_scaled_round(big, used - 1, MM.MIN_T, MM.MAX_T)", "return big_scaled_round(big, used, MM.MIN_T, MM.MAX_T)" },
  { "retenue fausse", "    local q = math.floor(v / BASE)\n    n[i]", "    local q = math.ceil(v / BASE)\n    n[i]" },
  { "seuil du plafond rapide trop bas", "if high > 3 then return hi end", "if high > 2 then return hi end" },
  { "lecture du moteur par plancher", "return -math.floor(-x)", "return math.floor(x)" },
  { "facteur décalé", "big_mul(big, f)", "big_mul(big, f + 1)" },
  { "signe perdu", "local sign = c > 0 and 1 or -1", "local sign = 1" },
  { "valeur rendue tronquée (défaut de la passe 1)", "if x >= 0 then return math.floor(x + 0.5) end", "if x >= 0 then return math.floor(x) end" },
  -- Lot MOD-3 (D-17) : productivité multipliée et énergie qui garde l'écart au plafond.
  { "productivité jamais multipliée", "\nMM.PRODUCTIVITY_MULTIPLIES = true", "\nMM.PRODUCTIVITY_MULTIPLIES = false" },
  { "écart au plafond retiré (D-15)", "MM.ENERGY_KEEPS_GAP = true", "MM.ENERGY_KEEPS_GAP = false" },
  { "part de vitesse non réduite au plafond", "if over_s then y = y + math.floor(part_s * l_cap / sum_logs(lists.speed)) else y = y + part_s end", "y = y + part_s" },
  { "part de productivité non réduite au plafond", "if over_p then y = y + math.floor(part_p * l_cap / sum_logs(lists.productivity)) else y = y + part_p end", "y = y + part_p" },
  { "part de l'efficacité réduite elle aussi", "else free = free + l end", "else part_s = part_s + l end" },
  { "plafond jugé sur le produit déjà borné", "return big_scaled_round(big, used - 1, MM.MIN_T, MM.MAX_T + 1) > MM.MAX_T", "return big_scaled_round(big, used - 1, MM.MIN_T, MM.MAX_T) > MM.MAX_T" },
  { "chiffre du logarithme compté double", "      res = res + bit\n", "      res = res + 2 * bit\n" },
  { "mantisse non élevée au carré", "m = math.floor(m * m / MANT_ONE)", "m = math.floor(m * 2)" },
  { "dichotomie bornée trop bas", "local lo, hi = MM.MIN_T, MM.MAX_T", "local lo, hi = MM.MIN_T, 10000" },
}
local killed = 0
for _, mu in ipairs(MUTANTS) do
  local a, b = SRC:find(mu[2], 1, true)
  if not a then
    check(false, "mutant « " .. mu[1] .. " » : motif introuvable dans module_mult.lua")
  else
    local src = SRC:sub(1, a - 1) .. mu[3] .. SRC:sub(b + 1)
    local chunk, err = load(src, "=mutant", "t", _ENV)
    local R = chunk and chunk()
    if not R then
      check(false, "mutant « " .. mu[1] .. " » : ne se charge pas (" .. tostring(err) .. ")")
    else
      local fails = 0
      local okc = pcall(rule_suite, R, function(cond) if not cond then fails = fails + 1 end end)
      if not okc then fails = fails + 1 end
      if fails > 0 then killed = killed + 1 end
      check(fails > 0, "mutant « " .. mu[1] .. " » refusé (" .. fails .. " contrôle(s) en échec)")
    end
  end
end
print(string.format("  mutants refusés : %d / %d", killed, #MUTANTS))

print(string.format("BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
