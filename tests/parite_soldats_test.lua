--[[
  Lot PARITE (reprise du 2/11 soir, écart 2) : votre équipe a des soldats comme une faction. Banc HORS JEU.
  Lancement : lua5.2 tests/parite_soldats_test.lua (racine du mod). Critères : fo-logs/2026-11-02_PARITE/CRITERES2.md.
    1. le cerveau (shared/ai3/buts.lua) donne à votre équipe le même but « armée » qu'à une faction de mêmes chiffres ;
    2. sans plafond de soldats (réglage à 0), aucun but d'armée (comme avant) ;
    3. mutant : la règle de l'exception d'avant (is_player) revient -> le test le voit.
]]
package.path = "./?.lua;" .. package.path
local B = require("shared.ai3.buts")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end

local function s_of(is_player, soldiers_max, soldiers)
  return { is_player = is_player, workers = 8, soldiers = soldiers or 0, soldiers_max = soldiers_max, stock = { ["firearm-magazine"] = 60, stone = 50 },
    cap = { coal = 1, iron = 2, copper = 1, stone = 1 }, pending = {}, sites = {}, smelters = 4, smelters_pending = 0,
    weights = B.weights({}, nil), research = { tech = "t-pack", palier = true }, army_target = 18, economy_done = true }
end
local st = function() return { targets = { coal = 2, iron = 2, copper = 1, stone = 1 }, iron2_set = true } end
local function army(goals) for _, g in ipairs(goals) do if g.key == "armee" then return g end end return nil end

local gp = army(B.generate(s_of(true, 30, 0), st()))
local gf = army(B.generate(s_of(false, 30, 0), st()))
check(gp ~= nil and gf ~= nil, "votre équipe ET la faction ont un but d'armée avec un plafond de 30 soldats")
check(gp and gf and gp.value == gf.value and gp.target == gf.target, "même valeur et même cible que la faction de mêmes chiffres")
check(army(B.generate(s_of(true, 0, 0), st())) == nil, "plafond 0 : aucun but d'armée pour votre équipe (comme avant)")
local g12 = army(B.generate(s_of(true, 30, 12), st()))
check(g12 ~= nil and g12.target == 18, "au-delà des premiers soldats : la cible ordinaire (18)")
local g20 = army(B.generate(s_of(true, 30, 20), st()))
check(g20 == nil, "cible atteinte : plus de but d'armée")

-- Mutant : l'exception d'avant revient.
local f = assert(io.open("shared/ai3/buts.lua", "rb")); local src = f:read("*a"); f:close()
local from = "if boot and (s.soldiers_max or 0) > 0 then"
local i, j = src:find(from, 1, true)
check(i ~= nil and not src:find(from, j + 1, true), "mutant : le texte à muter existe une seule fois")
local mutated = src:sub(1, i - 1) .. "if boot and not s.is_player and (s.soldiers_max or 0) > 0 then" .. src:sub(j + 1)
package.loaded["shared.ai3.buts"] = nil
local Bm = assert(load(mutated, "@buts_mutant"))()
local gm = army(Bm.generate(s_of(true, 30, 0), st()))
check(gm == nil, "mutant (l'exception d'avant) refusé : votre équipe perd son but d'armée")
package.loaded["shared.ai3.buts"] = B

print(string.format("[PARITE-SOLDATS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
