--[[
  Tests hors jeu du lot PLANDIR : croissance de la centrale (shared/team/centrale.lua). Usage :   lua5.2 tests/centrale_test.lua
]]
package.path = "./?.lua;" .. package.path
local C = require("shared.team.centrale")
local M = require("shared.team.modules")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local CAP = 2 * M.BASE["steam-engine"].power_out * 1000 / 60  -- une chaudière, deux machines : 30 000 J/tick
section("1. Saturation")
check(CAP == 30000, "capacité d'une centrale de base : 30 000 J/tick (" .. CAP .. ")")
local st = {}
for i = 1, C.SAT_CHECKS - 1 do C.observe(st, 0.85 * CAP, CAP) end
check(not st.saturated, "pas saturée avant " .. C.SAT_CHECKS .. " relevés")
C.observe(st, 0.85 * CAP, CAP)
check(st.saturated, "saturée au relevé " .. C.SAT_CHECKS)
C.observe(st, 0.5 * CAP, CAP)
check(not st.saturated and st.sat == 0, "un relevé sous 80 % remet le compte à zéro")
for i = 1, 10 do C.observe(st, 0, CAP) end
check(not st.saturated, "centrale éteinte (puissance 0) : jamais saturée (une panne n'est pas une demande)")
for i = 1, 10 do C.observe(st, 100, 0) end
check(not st.saturated, "capacité nulle : jamais saturée")
check(M.BASE["steam-engine"].power_out == 900, "machine à vapeur : 900 kW lus aux données")

section("2. Croissance")
local s = { saturated = true }
check(C.growth(s, 1, 0, 1, 7) == 1, "une centrale d'une chaudière saturée : une de plus de 1 chaudière")
check(C.growth(s, 2, 0, 3, 7) == 3, "la capacité double : autant de chaudières que l'existant")
check(C.growth(s, 2, 0, 12, 7) == 7, "bornée par l'extension du gabarit")
check(C.growth(s, 1, 1, 1, 7) == nil, "un chantier de centrale ouvert : on attend")
check(C.growth(s, C.MAX_PLANTS, 0, 9, 7) == nil, "plafond de " .. C.MAX_PLANTS .. " centrales")
check(C.growth(s, 0, 0, 0, 7) == nil, "aucune centrale finie : rien à faire grandir")
check(C.growth({ saturated = false }, 1, 0, 1, 7) == nil, "non saturée : rien")
C.requested(s)
check(C.growth(s, 1, 0, 1, 7) == nil and s.sat == 0, "après la demande : à remesurer")

section("3. Le gabarit agrandi passe le contrôle")
for nb = 1, 7 do
  local g = M.GEN.steam(nb)
  check(g ~= nil and #M.check(g) == 0, "centrale de " .. nb .. " chaudière(s) : gabarit valide")
  if g then check(g.power_kw < 0 or (g.electric_out_kw or 0) == nb * 2 * 900, "centrale " .. nb .. " : " .. tostring(g.electric_out_kw) .. " kW produits") end
end
local ext = M.GEN.steam(1).extensions[1]
check(ext.max >= 3, "extension du gabarit : au moins 3 chaudières (" .. ext.max .. ")")

print(string.format("[CENTRALE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
