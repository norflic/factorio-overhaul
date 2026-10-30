--[[
  Tests hors jeu du lot PD-FONDERIEQG (inventaire de la vague 9, D77 et D82). Pur, aucune API Factorio.
  Usage, depuis la racine du mod :   lua5.2 tests/fonderie_qg_test.lua

  1. FQ (shared/ai3/fonderie_qg.lua) : plaques automatisées, manques ouverts, borne ;
  2. Br.smelters : la fonderie du QG grandit comme avant SANS ligne à tapis ; avec une plaque fondue par une ligne, son manque
     et son minerai au coffre ne font plus grandir la fonderie à la main, qui est bornée (base + une vague par plaque NON
     couverte en manque durable) ; rien n'est retiré ; la borne se relâche quand la ligne tombe ;
  3. B.smelt_situation transmet st.covered ;
  4. Or (shared/team/orient.lua) : sens d'un gisement (vertical, horizontal, rond, trop petit) ;
  5. P.fit : collecteur dans le sens du gisement, sortie du collecteur vers l'arrivée ; sans les options, score d'avant ;
  6. mutants : chaque règle faussée est refusée par les contrôles ci-dessus.
]]
package.path = "./?.lua;" .. package.path

local FQ = require("shared.ai3.fonderie_qg")
local Br = require("shared.ai3.bras")
local B = require("shared.ai3.buts")
local Or = require("shared.team.orient")
local P = require("shared.team.plan")
local M = require("shared.team.modules")
local T = require("shared.team.config")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

-- Données : entrées de la fonderie du QG (shared/team/config.lua), triées comme B.smelt_situation.
local INPUTS = {}
do
  local ps = {}
  for p in pairs(T.smelter_inputs) do ps[#ps + 1] = p end
  table.sort(ps)
  for _, p in ipairs(ps) do INPUTS[#INPUTS + 1] = { p, T.smelter_inputs[p][1], T.smelter_inputs[p][2] } end
end
local IRON, IRON_ORE = "iron-plate", T.smelter_inputs["iron-plate"][1]
local COPPER, COPPER_ORE = "copper-plate", T.smelter_inputs["copper-plate"][1]

--- Contrôles de la partie « fonderie du QG » (D77) ; rend le nombre d'échecs.
local function suite_fq(verbose)
  local bad, total = 0, 0
  local function ck(cond, msg) total = total + 1; if not cond then bad = bad + 1; if verbose then print("  ECHEC : " .. msg) end end end
  -- 1. FQ seul
  ck(#FQ.automated(INPUTS, nil) == 0, "1 sans couverture : aucune plaque automatisée")
  ck(#FQ.automated(INPUTS, { [IRON] = true, ["autre-chose"] = true }) == 1, "1 seule une plaque de la fonderie compte")
  ck(FQ.open_short(INPUTS, { [IRON] = true }, { short = { [IRON] = 50, [COPPER] = 50 }, short_n = { [IRON] = 9, [COPPER] = 9 } }, 6) == 1,
    "1 manque ouvert : le cuivre (non couvert) compte, le fer (couvert) non")
  ck(FQ.open_short(INPUTS, {}, { short = { [COPPER] = 50 }, short_n = { [COPPER] = 2 } }, 6) == 0, "1 manque passager : rien")
  local lim, why = FQ.limit(16, 4, 0, 0, 2)
  ck(lim == 16 and why == nil, "1 sans automatisation : borne d'avant")
  lim, why = FQ.limit(16, 4, 1, 0, 2)
  ck(lim == 4 and why == "automatisee", "1 une plaque automatisée : bornée à 4 (" .. tostring(lim) .. ")")
  lim = FQ.limit(16, 4, 1, 2, 2)
  ck(lim == 8, "1 deux plaques non couvertes en manque : 4 + 2 × 2 = 8 (" .. tostring(lim) .. ")")
  lim, why = FQ.limit(3, 4, 1, 0, 2)
  ck(lim == 3 and why == nil, "1 jamais au-delà de la borne d'avant")

  -- 2. Br.smelters : 30 PNJ, beaucoup de minerai de fer au coffre, fer en manque durable
  local function fs(stock, smelters, tick, covered)
    return { workers = 30, stock = stock, smelters = smelters, smelters_pending = 0, tick = tick or 0,
      smelter_inputs = INPUTS, covered = covered }
  end
  local ore = { [IRON_ORE] = 1000 }
  -- sans ligne : la borne monte avec le minerai (1000 / 40 = 25, plafond Br.SMELT_HARD) et les vagues grandissent
  local st = { short = { [IRON] = 200 }, short_n = { [IRON] = 9 } }
  local n = Br.smelters(fs(ore, 4, 0), st, 4, 6)
  ck(n == 6, "2 sans ligne : une vague (4 -> 6) (" .. n .. ")")
  ck(st.fq == nil, "2 sans ligne : aucune borne d'automatisation")
  local cur = 6
  for i = 1, 12 do cur = Br.smelters(fs(ore, cur, 3600 * i), st, 4, 6) end
  ck(cur == Br.SMELT_HARD, "2 sans ligne : la fonderie à la main monte jusqu'à Br.SMELT_HARD (" .. cur .. ")")
  -- avec une ligne à tapis qui fond le fer : plus de vague, borne 4, rien de retiré (le cerveau ne demande plus rien)
  local st2 = { short = { [IRON] = 200 }, short_n = { [IRON] = 9 } }
  n = Br.smelters(fs(ore, 4, 0, { [IRON] = true }), st2, 4, 6)
  ck(n == 4, "2 fer fondu par une ligne : pas de vague (" .. n .. ")")
  ck(st2.fq ~= nil and st2.fq.cap == 4 and st2.fq.auto == 1 and st2.fq.why == "automatisee", "2 st.fq : borne 4, 1 plaque")
  local st3 = { short = { [IRON] = 200 }, short_n = { [IRON] = 9 }, smelt_target = 16 }
  n = Br.smelters(fs(ore, 16, 3600, { [IRON] = true }), st3, 4, 6)
  ck(n == 4, "2 16 fours déjà posés puis ligne : la cible tombe à la borne (" .. n .. "), aucun four de plus")
  -- un manque NON couvert (cuivre, minerai au coffre) garde de quoi grandir un peu
  local st4 = { short = { [IRON] = 200, [COPPER] = 200 }, short_n = { [IRON] = 9, [COPPER] = 9 } }
  local both = { [IRON_ORE] = 1000, [COPPER_ORE] = 1000 }
  n = Br.smelters(fs(both, 4, 0, { [IRON] = true }), st4, 4, 6)
  ck(n == 6, "2 cuivre non couvert en manque : une vague (4 -> 6) (" .. n .. ")")
  n = Br.smelters(fs(both, 6, 3600, { [IRON] = true }), st4, 4, 6)
  ck(n == 6, "2 cuivre non couvert : borne 4 + 2 = 6, pas au-delà (" .. n .. ")")
  -- la ligne tombe (plus couverte) : borne d'avant rendue, la vague repart
  n = Br.smelters(fs(ore, 4, 7200, {}), st2, 4, 6)
  ck(n == 6 and st2.fq == nil, "2 ligne tombée : la main reprend (4 -> 6) (" .. n .. ")")

  -- 3. B.smelt_situation transmet st.covered
  local ss = B.smelt_situation({ workers = 8, stock = {}, smelters = 4, smelters_pending = 0, tick = 0 }, { covered = { [IRON] = true } })
  ck(ss.covered and ss.covered[IRON] == true, "3 situation de la fonderie : covered transmis")
  ck(B.smelt_situation({ workers = 8 }).covered == nil, "3 sans état : comme avant")
  return bad, total
end

--- Gisement : rectangle de tuiles [x0, x1] × [y0, y1] (inclus) -> set { [tkey] = true } et moments.
local function deposit(x0, y0, x1, y1)
  local set, m = {}, Or.moments()
  for x = x0, x1 do for y = y0, y1 do
    set[(x + 1048576) * 2097152 + (y + 1048576)] = true
    Or.add(m, x, y)
  end end
  return set, m
end

local function out_dir(g, fit)
  local r = fit.k == 0 and g or M.rotate(g, fit.k)
  local inst = M.instantiate(r, 0, fit.ox, fit.oy)
  for _, bp in ipairs(P.belt_ports(inst)) do if bp.io == "out" then return bp.dir, bp end end
end

--- Contrôles de la partie « sens des lignes de foreuses » (D82) ; rend le nombre d'échecs.
local function suite_or(verbose)
  local bad, total = 0, 0
  local function ck(cond, msg) total = total + 1; if not cond then bad = bad + 1; if verbose then print("  ECHEC : " .. msg) end end end
  -- 4. Or
  local _, mv = deposit(8, 0, 16, 23)
  ck(Or.axis(mv) == "y", "4 gisement 9 × 24 : vertical")
  local _, mh = deposit(0, 8, 23, 16)
  ck(Or.axis(mh) == "x", "4 gisement 24 × 9 : horizontal")
  local _, mr = deposit(2, 2, 21, 21)
  ck(Or.axis(mr) == nil, "4 gisement carré : sans sens")
  local _, ms = deposit(0, 0, 9, 0)
  ck(Or.axis(ms) == nil, "4 trop petit (10 tuiles) : sans sens")
  ck(Or.line_axis(0) == "y" and Or.line_axis(4) == "y" and Or.line_axis(2) == "x" and Or.line_axis(6) == "x", "4 sens d'un collecteur")

  -- 5. P.fit sur un lot de 24 × 24, ligne de 2 paires (les deux sens couvrent 100 % : seul le sens et la sortie départagent)
  local rect = { x0 = 0, y0 = 0, x1 = 24, y1 = 24 }
  local free = function() return true end
  local g = M.GEN.drills("iron-ore", 2)
  -- 5a. gisement vertical, arrivée au nord : collecteur vertical, sortie vers le nord
  local ov = deposit(8, 0, 16, 23)
  local toward = { x = 12, y = -10 }
  local fit = P.fit(g, rect, { free = free, ore = ov, toward = toward, axis = Or.axis(mv), out_toward = true })
  local d = fit and out_dir(g, fit)
  ck(fit ~= nil and d == 0, "5a gisement vertical, arrivée au nord : collecteur vers le nord (dir " .. tostring(d) .. ")")
  ck(fit ~= nil and (fit.pen or 0) == 0 and fit.cover >= 1 - 1e-9, "5a dans le sens, couverture pleine")
  -- 5b. même gisement, arrivée à l'est : le sens du gisement l'emporte sur la ligne en travers qui sortirait droit à l'est
  local fit_b = P.fit(g, rect, { free = free, ore = ov, toward = { x = 40, y = 12 }, axis = "y", out_toward = true })
  local db = fit_b and out_dir(g, fit_b)
  ck(fit_b ~= nil and (db == 0 or db == 4), "5b arrivée à l'est : collecteur toujours vertical (dir " .. tostring(db) .. ")")
  -- 5c. gisement horizontal, arrivée à l'ouest : collecteur horizontal, sortie vers l'ouest
  local oh = deposit(0, 8, 23, 16)
  local fit_c = P.fit(g, rect, { free = free, ore = oh, toward = { x = -10, y = 12 }, axis = Or.axis(mh), out_toward = true })
  local dc = fit_c and out_dir(g, fit_c)
  ck(fit_c ~= nil and dc == 6, "5c gisement horizontal, arrivée à l'ouest : sortie vers l'ouest (dir " .. tostring(dc) .. ")")
  -- 5d. gisement rond, arrivée au sud : pas de sens, la sortie regarde l'arrivée
  local orr = deposit(2, 2, 21, 21)
  local fit_d = P.fit(g, rect, { free = free, ore = orr, toward = { x = 12, y = 40 }, axis = Or.axis(mr), out_toward = true })
  local dd = fit_d and out_dir(g, fit_d)
  ck(fit_d ~= nil and dd == 4, "5d gisement rond, arrivée au sud : sortie vers le sud (dir " .. tostring(dd) .. ")")
  -- 5e. une ligne qui ne tient QUE en travers (6 paires dans un gisement de 9 × 24 couché) n'est pas refusée par le sens
  local g6 = M.GEN.drills("iron-ore", 6)
  local fit_e = P.fit(g6, rect, { free = free, ore = oh, toward = { x = 12, y = -10 }, axis = "y", out_toward = true, cover_min = 0.8 })
  ck(fit_e ~= nil, "5e le sens est une préférence, jamais un refus")
  -- 5f. sans les options : score d'avant (aucune pénalité, distance au centre)
  local f0 = P.fit(g, rect, { free = free, ore = ov, toward = toward })
  ck(f0 ~= nil and (f0.pen or 0) == 0, "5f sans options : aucune pénalité")
  if f0 then
    local cx, cy = f0.ox + f0.w / 2, f0.oy + f0.h / 2
    ck(math.abs(f0.d - (math.abs(cx - toward.x) + math.abs(cy - toward.y))) < 1e-9, "5f sans options : distance au centre (score d'avant)")
  end
  return bad, total
end

section("1 à 3. Fonderie du QG bornée par l'automatisation (D77)")
local b1, n1 = suite_fq(true)
passes, failures = passes + n1 - b1, failures + b1
section("4 et 5. Sens des lignes de foreuses (D82)")
local b2, n2 = suite_or(true)
passes, failures = passes + n2 - b2, failures + b2

section("6. Mutants")
local function mutant(name, apply, restore, suite)
  apply()
  local ok, bad = pcall(suite, false)
  restore()
  check(not ok or bad > 0, "mutant refusé : " .. name)
end
do
  local lim0 = FQ.limit
  mutant("FQ.limit rend toujours la borne d'avant", function() FQ.limit = function(max) return max, nil end end,
    function() FQ.limit = lim0 end, suite_fq)
  local auto0 = FQ.automated
  mutant("FQ.automated ignore la couverture", function() FQ.automated = function() return {} end end,
    function() FQ.automated = auto0 end, suite_fq)
  local os0 = FQ.open_short
  mutant("FQ.open_short compte aussi les plaques couvertes", function()
    FQ.open_short = function(inputs, covered, st, n) return os0(inputs, {}, st, n) end end, function() FQ.open_short = os0 end, suite_fq)
  local keep0 = FQ.KEEP
  mutant("FQ.limit sans le pas des plaques ouvertes", function()
    FQ.limit = function(max, keep, a, o) return lim0(max, keep, a, 0, 0) end end, function() FQ.limit = lim0 end, suite_fq)
  FQ.KEEP = keep0
  local pen0 = P.AXIS_PENALTY
  mutant("P.AXIS_PENALTY = 0 (le sens du gisement ignoré)", function() P.AXIS_PENALTY = 0 end, function() P.AXIS_PENALTY = pen0 end, suite_or)
  local ax0 = Or.axis
  mutant("Or.axis inverse les axes", function()
    Or.axis = function(m, r, n) local a, x, y = ax0(m, r, n); if a == "x" then a = "y" elseif a == "y" then a = "x" end return a, x, y end end,
    function() Or.axis = ax0 end, suite_or)
  local la0 = Or.line_axis
  mutant("Or.line_axis inversé", function() Or.line_axis = function(d) return la0(d) == "x" and "y" or "x" end end,
    function() Or.line_axis = la0 end, suite_or)
end

print(string.format("[FONDERIE-QG] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
