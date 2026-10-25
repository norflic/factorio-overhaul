-- Lot IA3-DIAG : ce que le solveur d'IA1-e1 (shared/team/production.lua) demande pour payer les recherches des
-- factions (T.research) en un temps donné, avec des assembleurs au lieu de la fabrication à la main.
-- Usage (racine du mod) : lua5.2 tools/autotest/ia3d_solveur.lua
package.path = "./?.lua;" .. package.path
local P = require("shared.team.production")
local T = require("shared.team.config")
local FIX = require("tests.fixtures.recipes_ia1e")

local book = P.book(FIX)

local function show(title, targets)
  local plan, why = P.solve(book, targets)
  print("== " .. title)
  if not plan then print("   refuse : " .. tostring(why)) return end
  for _, n in ipairs(plan.nodes) do
    print(string.format("   %-28s %7.2f /min  %-22s machines %5.2f (%d)", n.item, n.per_min or 0, tostring(n.machine or n.category),
      n.machines or 0, n.machines_ceil or 0))
  end
  for _, r in ipairs(plan.raw or {}) do
    print(string.format("   brut %-22s %7.2f /min", tostring(r.item or r[1]), r.per_min or 0))
  end
  if plan.coal then print(string.format("   charbon total %.1f /min", plan.coal.total or 0)) end
end

-- Recherches 1 à 3 en 10 min chacune (débit moyen sur la fenêtre).
for lvl = 1, 3 do
  local t = {}
  for _, it in ipairs(T.research[lvl]) do t[#t + 1] = { it[1], it[2] / 10 } end
  show("recherche " .. lvl .. " en 10 min", t)
end
-- Recherche 4 (pack chimique : pétrole) en 20 min.
local t4 = {}
for _, it in ipairs(T.research[4]) do t4[#t4 + 1] = { it[1], it[2] / 20 } end
show("recherche 4 en 20 min (petrole)", t4)
