-- Lot RANGEES-DEBIT : ligne de foreuses bornée par le débit du tapis collecteur (shared/team/debit.lua), chaîne pure jusqu'aux fours
-- (shared/team/ligne.lua), et branchements (script/team/build.lua line_rows, script/ai3/automatisation.lua submit). lua5.2 tests/debit_test.lua
package.path = "./?.lua;" .. package.path
local Db = require("shared.team.debit")
local M = require("shared.team.modules")
local P = require("shared.team.plan")
local Li = require("shared.team.ligne")
local T = require("shared.team.config")

local ok, ko = 0, 0
local function check(c, msg)
  if c then ok = ok + 1 else ko = ko + 1; print("ECHEC : " .. msg) end
end
local function read(path)
  local fh = assert(io.open(path, "rb")); local s = fh:read("*a"); fh:close(); return s
end

-- 1. Règle pure
check(Db.lane_capacity(0.03125) == 7.5, "voie d'un tapis de vitesse 0,03125 : 7,5/s")
check(Db.lane_capacity(0.0625) == 15, "voie d'un tapis deux fois plus rapide : 15/s")
check(Db.lane_capacity(nil) == 0 and Db.lane_capacity(-1) == 0, "vitesse absente : 0")
check(Db.belt_pairs(7.5, 0.5, nil) == 15, "7,5/s par voie / 0,5/s : 15 foreuses par cote")
check(Db.belt_pairs(7.5, 0.5, 7) == 7, "emprise 7 paires : 7")
check(Db.belt_pairs(7.5, 0.75, nil) == 10, "foreuse plus rapide : 10 par cote")
check(Db.belt_pairs(7.4, 0.5, nil) == 14, "arrondi par defaut : la voie n'est jamais saturee")
check(Db.belt_pairs(0, 0.5, 7) == 0 and Db.belt_pairs(7.5, 0, 7) == 0 and Db.belt_pairs(nil, 0.5, 7) == 0, "donnee manquante : 0")
for _, sp in ipairs({ 0.03125, 0.0625, 0.09375 }) do
  for _, dr in ipairs({ 0.25, 0.5, 0.75, 1.1 }) do
    local n = Db.belt_pairs(Db.lane_capacity(sp), dr, nil)
    check(n * dr <= Db.lane_capacity(sp) + 1e-9 and (n + 1) * dr > Db.lane_capacity(sp) - 1e-9,
      string.format("tapis %.5f, foreuse %.2f : %d par cote, la plus longue ligne qui tient", sp, dr, n))
  end
end

-- 2. Chaîne pure avec les données du jeu de base (le cas du DC : tapis jaune, foreuse électrique, four en pierre)
do
  local dsp = M.spec(T.DRILL_ELECTRIC)
  local gd = M.GEN.drills("iron-ore", 1)
  local emprise = gd.extensions[1].max
  local by_belt = Db.belt_pairs(Db.lane_capacity(0.03125), dsp.speed, nil)
  check(by_belt == 15, "le tapis porte 15 foreuses par cote (DC : « 15 objets par seconde [...] 0,5 par seconde »)")
  check(emprise == 7, "emprise d'un lot : 7 paires (longueur 24 tuiles) ; c'est elle qui borne, pas le tapis")
  local pairs_line = math.min(by_belt, emprise)
  for _, furnace in ipairs({ "stone-furnace", "steel-furnace" }) do
    local g1 = M.GEN.smelter(furnace, "iron-ore", 1)
    if g1 then
      local cap = g1.nominal["iron-plate"] / 2
      local rows = Li.rows_wanted({ rows_rate = 2, pairs_dep = pairs_line, drill_rate = dsp.speed, cap = cap, pairs_line = pairs_line,
        rows_max = g1.extensions[1].max, grow = true, rows_fit = Li.rows_fit(P.LOT, 1, P.FEED_DEPTH, 2, M.spec(furnace).w) })
      local demand_pairs = math.ceil(2 * rows * cap / (2 * dsp.speed) - 1e-9)
      check(2 * rows * cap > 2.5 + 1e-9, string.format("%s : %d rangees (%d fours, %.2f/s) pour un gisement de %d paires, plus que les 8 fours en pierre de 0.6.18 (2,5/s)", furnace, rows, 2 * rows, 2 * rows * cap, pairs_line))
      check(demand_pairs <= pairs_line and demand_pairs > 3, string.format("%s : %d paires posees (%d foreuses), plus que le paquet de 6, jamais plus que le collecteur", furnace, demand_pairs, 2 * demand_pairs))
      check(demand_pairs * dsp.speed <= 2 * rows * cap + 2 * dsp.speed, string.format("%s : les fours absorbent les foreuses a une paire pres", furnace))
    end
  end
end

-- 2 bis. Relecture : ce que le DC a vu en 0.6.18 (8 fours, 6 foreuses) vient du BUDGET de main (Li.budget_rows, plancher 4 rangées),
-- pas du tapis : 600 plaques -> 4 rangées -> 3 paires. La borne du tapis ne mord jamais avec les données de base (le gabarit bornait
-- déjà par M.LANE_RATE) ; seule la ligne dynamique (lot FONDERIE-DYNAMIQUE, T.ligne.dyn) fait grandir la ligne au-delà.
do
  local dsp = M.spec(T.DRILL_ELECTRIC)
  local emprise = M.GEN.drills("iron-ore", 1).extensions[1].max
  for _, sp in ipairs({ 0.03125, 0.0625, 0.09375 }) do
    check(math.min(Db.belt_pairs(Db.lane_capacity(sp), dsp.speed, nil), emprise) == emprise,
      string.format("tapis %.5f : la borne retenue est l'emprise (%d paires), le tapis ne retire rien", sp, emprise))
  end
  local g1 = M.GEN.smelter("stone-furnace", "iron-ore", 1)
  if g1 and not (T.ligne and T.ligne.dyn) then
    local cap = g1.nominal["iron-plate"] / 2
    local budget = Li.budget_rows(600, T.ligne.row_cost, T.ligne.stock_share, T.ligne.rows_floor)
    local demand_pairs = math.ceil(2 * budget * cap / (2 * dsp.speed) - 1e-9)
    check(budget == 4 and demand_pairs == 3, string.format("main sans ligne dynamique : 600 plaques -> %d rangees, %d paires (le paquet de 6 du DC)", budget, demand_pairs))
  end
end

-- 3. Réglages et branchements (lecture des sources : un lecteur par état écrit)
check(type(T.debit) == "table" and T.debit.belt == true and T.debit.shrunk_grows == true, "reglages T.debit presents")
local build = read("script/team/build.lua")
check(build:find("pairs_line = Build.debit_pairs(f, prm.ore, pairs_line, dsp.speed)", 1, true) ~= nil, "line_rows lit la borne du tapis")
check(build:find("[FO-DEBIT]", 1, true) ~= nil, "journal [FO-DEBIT] dans build.lua")
check(build:find('require("shared.team.debit")', 1, true) ~= nil, "build.lua charge la regle au chargement du fichier")
do -- relecture : Build.debit_pairs ne passe pas par Conv.choose (journal [FO-CONVOYEURS] « premier choix » réservé au vrai tracé)
  local s = build:find("function Build.debit_pairs", 1, true)
  local e = s and build:find("\nend", s, true)
  local body = s and e and build:sub(s, e) or ""
  check(body ~= "" and not body:find("Conv.choose", 1, true) and body:find("Cv.pick", 1, true) ~= nil,
    "Build.debit_pairs lit le tapis par la regle pure, sans ecrire le journal du premier trace")
end
local auto = read("script/ai3/automatisation.lua")
check(auto:find("spec.shrunk and T.debit and T.debit.shrunk_grows and T.ligne and T.ligne.dyn", 1, true) ~= nil,
  "un module reduit n'est plus fige quand la ligne est dynamique (seulement elle)")
-- sans ligne dynamique (main 0.6.18 sans FONDERIE-DYNAMIQUE), la réduction est gardée
check(not (T.ligne and T.ligne.dyn) or T.ligne.rows_floor == nil, "ligne dynamique : plus de plancher de 4 rangees")
local src = read("shared/team/debit.lua")
check(not src:find("game%.") and not src:find("defines%.") and not src:find("\"[%w%-]+%-belt\""), "regle pure, aucun nom de tapis en dur")

print(string.format("[DEBIT] BILAN : %d OK, %d ECHEC(S)", ok, ko))
os.exit(ko == 0 and 0 or 1)
