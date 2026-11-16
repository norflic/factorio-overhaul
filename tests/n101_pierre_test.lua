-- n101-pierre (A2) : une ressource consommée telle quelle a une voie d'extraction électrique dérivée des données (shared/ai3/voie_brute.lua).
-- Avant : seule la fonderie à foreuses (A.METHODS) donnait une méthode ; la pierre n'en avait aucune (0 foreuse électrique à 89 min).
-- Usage : lua5.2 tests/n101_pierre_test.lua (depuis la racine du mod)
package.path = "./?.lua;" .. package.path
local Vb = require("shared.ai3.voie_brute")
local A = require("shared.ai3.automatiser")
local fails = 0
local function check(c, m) if not c then fails = fails + 1; print("ECHEC : " .. m) end end

-- les méthodes de fonderie de l'exécutant, comme script/ai3/capitalisation.lua (METHOD_OF_ORE), lues aux données
local by_ore, raw_res = {}, nil
for _, m in ipairs(A.METHODS) do if m.ore and not by_ore[m.ore] then by_ore[m.ore] = m end end
local smelted = nil
for _, k in ipairs((function() local t = {} for k in pairs(by_ore) do t[#t + 1] = k end table.sort(t) return t end)()) do smelted = smelted or k end
check(smelted ~= nil, "au moins une fonderie a foreuses dans A.METHODS")
raw_res = "ressource-brute-de-test" -- (nom synthétique : aucune fonderie ne la sert)
check(by_ore[raw_res] == nil, "la ressource de test n'a pas de fonderie")

local solid = { fluid = false, fuel = 0, mines = true, champ = true }
-- 1. fonderie : sa méthode est gardée telle quelle
check(Vb.of(by_ore, smelted, solid) == by_ore[smelted], "un minerai fondu garde sa fonderie")
-- 2. ressource brute solide, minée par la foreuse électrique, posée par le champ : méthode brute (le maillon manquant)
local m = Vb.of(by_ore, raw_res, solid)
check(m ~= nil and m.raw == true and m.product == raw_res and m.ore == raw_res, "ressource brute : methode electrique derivee")
-- 3. combustible : garde la voie de la migration (pas de second écrivain)
local m3, w3 = Vb.of(by_ore, raw_res, { fluid = false, fuel = 4e6, mines = true, champ = true })
check(m3 == nil and tostring(w3):find("combustible") ~= nil, "combustible : pas de methode brute")
-- 4. fluide, 5. aucune foreuse électrique qui la mine, 6. aucun champ : pas de méthode, raison nommée
check(Vb.of(by_ore, raw_res, { fluid = true, mines = true, champ = true }) == nil, "fluide refuse")
check(Vb.of(by_ore, raw_res, { fluid = false, mines = false, champ = true }) == nil, "sans foreuse electrique refuse")
check(Vb.of(by_ore, raw_res, { fluid = false, mines = true, champ = false }) == nil, "sans champ refuse")
-- 7. déterminisme : même entrée, même sortie
local a, b = Vb.of(by_ore, raw_res, solid), Vb.of(by_ore, raw_res, solid)
check(a.product == b.product and a.raw == b.raw, "deterministe")

if fails > 0 then error(fails .. " echec(s)") end
print("n101_pierre_test OK (7 cas)")
