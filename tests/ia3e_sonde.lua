-- Lot IA3-e : SONDE au moteur simulé (pas un banc : aucun contrôle) : une guerre à 2 factions (Normal, 8 PNJ) jouée
-- N minutes, puis les lignes [FO-IA3E] et [FO-IA1D] du journal. Lancement : lua5.2 tests/ia3e_sonde.lua [minutes].
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")
local MIN = 3600
local minutes = tonumber(arg and arg[1]) or 45
local function patches()
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    local names = { "coal", "iron-ore", "copper-ore", "stone" }
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  return out
end
M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "normal", groups_hit_player = true, turrets_kill = true, ia3e = true })
M.command("fo-war", "start 2 60 8 320")
local seen = 0
local t0 = os.clock()
for m = 1, minutes do
  M.run_ticks(MIN)
  local logs = M.world().logs
  for i = seen + 1, #logs do
    local l = logs[i]
    if l:find("FO%-IA3E") or l:find("FO%-IA1D") or l:find("palier") or l:find("terminee") then print(l) end
  end
  seen = #logs
end
print(string.format("sonde : %d min de jeu en %.1f s", minutes, os.clock() - t0))
-- Diagnostic du plan directeur (SONDE_PLAN=1).
if os.getenv("SONDE_PLAN") then
  local Build = require("script.team.build")
  for _, id in ipairs({ 1, 2 }) do
    local f = global.fo.war.factions[id]
    local r = f and f.build and Build.report(f)
    if r then
      local function kv(t) local o = {} for k, v in pairs(t or {}) do o[#o + 1] = tostring(k) .. "=" .. tostring(v) end table.sort(o) return table.concat(o, " ") end
      print(f.key, "rayon", r.radius, "lots {" .. kv(r.lots) .. "}", "refus au plan {" .. kv(r.plan_refused) .. "}")
      for _, p in ipairs(r.projects) do print("  projet", p.id, p.state, p.reason, p.total) end
      print("  hq", f.hq_pos.x, f.hq_pos.y)
    end
  end
end
