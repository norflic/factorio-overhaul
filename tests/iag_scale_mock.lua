--[[
  Lot IA-G : MESURE au moteur simulé (indicative, pas une preuve) de la part de PNJ sans tâche des factions à 30 PNJ,
  avec et sans les règles « bras libres » (shared/ai3/general.lua, Gen.ahead_depth), et avec l'ancien choix d'IA-V2.
  Même partie que tests/ia1_scale_test.lua (4 factions, 30 PNJ, financées). Usage :
    lua5.2 tests/iag_scale_mock.lua <variante> [minutes=30]   variante = apres | sans-bras | avant
  Imprime, par faction : PNJ, part sans tâche (pensées de la minute 12 à la fin), technologies recherchées.
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")
local variant = arg[1] or "apres"
local minutes = tonumber(arg[2]) or 30

local function patches()
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  return out
end

M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0 })
M.world().settings["fo-recruit-idle-max"] = 60
M.world().settings["fo-war-workers"] = 30
local Gen = require("shared.ai3.general")
local General = require("script.ai3.general")
if variant == "sans-bras" then Gen.IDLE_MIN = 1e9 end
if variant == "avant" then General.ENABLED = false; Gen.IDLE_MIN = 1e9 end
assert(remote.call("factorio-overhaul", "war_start", 4, 100, nil, 320) == true)
remote.call("factorio-overhaul", "war_fund", 3000)
M.run_ticks(12 * 3600)
local w = global.fo.war
local base = {}
for _, f in ipairs(w.factions) do
  local s = f.team.scale or {}
  base[f.key] = { idle = s.idle_sum or 0, n = s.n_sum or 0 }
end
M.run_ticks((minutes - 12) * 3600)
local tot_i, tot_n = 0, 0
for _, f in ipairs(w.factions) do
  local s = f.team.scale or {}
  local di, dn = (s.idle_sum or 0) - base[f.key].idle, (s.n_sum or 0) - base[f.key].n
  tot_i, tot_n = tot_i + di, tot_n + dn
  local techs = 0
  for _, t in pairs(game.forces[f.force].technologies) do if t.researched then techs = techs + 1 end end
  local g = f.team.iag or {}
  print(string.format("[IAG-ECHELLE] %s %s : %d PNJ, sans tache %.1f %% (min 12-%d), technologies %d, avance %d pensees, extraction d'avance %d",
    variant, f.key, f.engineers_count or 0, dn > 0 and 100 * di / dn or 0, minutes, techs, g.ahead_thinks or 0,
    (f.team.ia3 and f.team.ia3.idle_grown) or 0))
end
print(string.format("[IAG-ECHELLE] %s : sans tache %.1f %% (4 factions, min 12-%d)", variant, tot_n > 0 and 100 * tot_i / tot_n or 0, minutes))
