--[[
  Tests hors jeu du lot LAYOUT, partie gabarit : un plan de shared/team/layout_mine.lua devient un gabarit de
  shared/team/modules.lua (M.mine_template) qui passe le contrôle M.check, pour la foreuse de base et les 30 niveaux de la
  famille « foreuse », en mode "single" (une ligne, une sortie) et en mode "all" (champ entier).
  Usage, depuis la racine du mod :   lua5.2 tests/layout_modules_test.lua
]]

package.path = "./?.lua;" .. package.path
local M = require("shared.team.modules")
local L = require("shared.levels.config")
local LM = require("shared.team.layout_mine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local function rect(x0, y0, x1, y1, res, amount)
  local t = {}
  for x = x0, x1 do for y = y0, y1 do t[#t + 1] = { x = x, y = y, res = res, amount = amount or 100 } end end
  return t
end

local names = { "electric-mining-drill" }
local fam = L.by_key.drill
for n = 1, fam.max do names[#names + 1] = L.name(fam, n) end

section("Gabarit d'un champ : foreuse de base et 30 niveaux")
local built, total_checked = 0, 0
for _, name in ipairs(names) do
  local sp = M.spec(name)
  if not sp then
    check(false, "entité inconnue " .. name)
  else
    local drill = { w = sp.w, reach = sp.radius, speed = sp.speed, drop = sp.drop }
    local f = { tiles = rect(0, 0, 21, 21, "iron-ore"), bounds = { x0 = 1, y0 = 1, x1 = 23, y1 = 23 } }
    for _, mode in ipairs({ "single", "all" }) do
      local opts = { gap = 1, mode = mode, max_drills = 6, belt_rate = M.BELT_RATE, toward = { x = 40, y = 12 } }
      local plan = LM.plan(f, drill, opts)
      if not plan then
        -- une foreuse trop large ou trop rapide pour une voie : aucun plan, ce n'est pas un défaut du gabarit
        check(sp.speed * 1 > M.LANE_RATE or sp.w >= 5, name .. " " .. mode .. " : pas de plan alors que la foreuse tient (w=" .. sp.w .. ")")
      else
        local g, why = M.mine_template(plan, "iron-ore", name)
        check(g ~= nil, name .. " " .. mode .. " : gabarit refusé : " .. tostring(why))
        if g then
          built = built + 1
          local errs = M.check(g)
          total_checked = total_checked + 1
          check(#errs == 0, name .. " " .. mode .. " : " .. tostring(errs[1]))
          check(g.w <= M.MAX_SIDE and g.h <= M.MAX_SIDE, name .. " " .. mode .. " : emprise " .. g.w .. " x " .. g.h)
          local out = g.nominal and g.nominal["iron-ore"] or 0
          check(math.abs(out - plan.rate) < 1e-6, string.format("%s %s : débit nominal %.3f, plan %.3f", name, mode, out, plan.rate))
          local outs = 0
          for _, p in ipairs(g.ports) do if p.io == "out" then outs = outs + 1 end end
          check(outs == #plan.exits, name .. " " .. mode .. " : une sortie par couloir sorti")
          if mode == "single" then check(outs == 1, name .. " : une seule sortie en mode single") end
        end
      end
    end
  end
end
print(string.format("  %d gabarits construits et contrôlés sur %d entités", built, #names))
check(built >= 2 * #names - 12, "au moins la plupart des entités ont leur gabarit")

section("Mutant : une foreuse tournée à l'envers est refusée par le contrôle")
do
  local sp = M.spec("electric-mining-drill")
  local f = { tiles = rect(0, 0, 21, 21, "iron-ore"), bounds = { x0 = 0, y0 = 0, x1 = 24, y1 = 24 } }
  local plan = LM.plan(f, { w = sp.w, reach = sp.radius, speed = sp.speed, drop = sp.drop }, { gap = 1, mode = "single", max_drills = 4 })
  for _, d in ipairs(plan.drills) do d.dir = (d.dir + 4) % 8 end
  local g = M.mine_template(plan, "iron-ore", "electric-mining-drill")
  check(g ~= nil and #M.check(g) > 0, "foreuses retournées : refusées")
end

print(string.format("[LAYOUT-MODULES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
