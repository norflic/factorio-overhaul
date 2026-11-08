--[[
  Lot DEFENSE-STOCK : banc HORS JEU du RUNTIME (script/team/defense_stock.lua, branchement de team.lua, worker.lua, planner.lua) sur le
  moteur simulé, guerre de 4 factions. Prouve la PLOMBERIE (le moteur simulé n'a pas de vrais biters ni de vraie pose en terrain
  encombré) :
    1. coffre d'une faction garni de tourelles et de chargeurs, cellules attaquées dans la mémoire du front : le poste « reserve »
       crée une tâche, un PNJ la prend, des tourelles sont POSÉES en groupe, inscrites dans f.turrets avec l'oid « reserve<clé> »,
       payées sur le coffre (la réserve reste), journal [FO-DEFENSE] reserve ;
    2. sous la réserve : aucune tâche, aucune ligne de pose ;
    3. global sérialisable ; deux passages identiques (journal compris).
  Lancement : lua5.2 tests/defense_stock_moteur_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local function W() return M.world() end

local function patches()
  local out = {}
  local d = 0.7071
  for _, c in ipairs({ { d, -d }, { d, d }, { -d, d }, { -d, -d } }) do
    local hx, hy = c[1] * 320, c[2] * 320
    local names = { "coal", "iron-ore", "copper-ore", "stone" }
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di = 1, 12 do
        local a = di * 0.5236
        out[#out + 1] = { x = hx + math.cos(a) * r, y = hy + math.sin(a) * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  return out
end

local function lines(pat, from)
  local out = {}
  for i = from or 1, #W().logs do
    local l = W().logs[i]
    if l:find(pat, 1, true) then out[#out + 1] = l end
  end
  return out
end

local function run(stock_turrets)
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0 })
  M.command("fo-war", "start 4 100 10 320")
  M.run_ticks(600)
  local St = require("script.faction.state")
  local Fr = require("shared.team.front")
  local Ds = require("shared.team.defense_stock")
  local f = St.war().factions[1]
  local out = { key = f.key }
  -- Le coffre dort : tourelles et chargeurs.
  f.hq.insert({ name = "gun-turret", count = stock_turrets })
  f.hq.insert({ name = "firearm-magazine", count = 2000 })
  f.hq.insert({ name = "iron-plate", count = 3000 })
  -- Mémoire du front : deux cellules attaquées à 12 et 30 tuiles du QG (des bâtiments de l'équipe sont à moins de 24 tuiles).
  local tick = game.tick
  local mem = Fr.new(tick)
  for _ = 1, 20 do Fr.record(mem, f.hq_pos.x + 12, f.hq_pos.y + 4, Fr.HIT) end
  for _ = 1, 8 do Fr.record(mem, f.hq_pos.x - 30, f.hq_pos.y - 4, Fr.HIT) end
  f.front_mem = { mem = mem, rest = {}, chk = {}, chk_tick = tick, cover = {}, cover_tick = tick, poses = 0, logs = 0 }
  out.stock0 = f.hq.get_item_count("gun-turret")
  local n0 = #W().logs
  local t0 = 0
  for _ in pairs(f.turrets or {}) do t0 = t0 + 1 end
  out.t0 = t0
  M.run_ticks(6000)
  local oids, n_res = {}, 0
  for _, id in ipairs(St.sorted_keys(f.turrets or {})) do
    local o = St.owner(id)
    if o and type(o.oid) == "string" and o.oid:sub(1, 7) == "reserve" then
      n_res = n_res + 1
      oids[o.oid] = (oids[o.oid] or 0) + 1
    end
  end
  out.n_res = n_res
  out.oids = oids
  out.stock1 = f.hq.get_item_count("gun-turret")
  out.poses = lines("[FO-DEFENSE] reserve", n0)
  out.logs = {}
  for _, l in ipairs(out.poses) do out.logs[#out.logs + 1] = l end
  out.ser = pcall(M.serialize, global)
  out.tasks_seen = f.stats and f.stats.reserve_fortified or 0
  return out
end

section("Branchement (moteur simulé, guerre de 4 factions)")
local Ds = require("shared.team.defense_stock")
local r = run(60)
if arg[1] == "-v" then
  print(string.format("  [info] coffre %d -> %d, posees %d, oids:", r.stock0, r.stock1, r.n_res))
  for _, oid in ipairs((function() local k = {} for o in pairs(r.oids) do k[#k + 1] = o end table.sort(k) return k end)()) do print("   ", oid, r.oids[oid]) end
  for _, l in ipairs(r.logs) do print("  " .. l:sub(1, 400)) end
end
check(r.stock0 >= 60, "coffre garni de tourelles (" .. tostring(r.stock0) .. ")")
check(r.n_res >= Ds.MIN_GROUP, "des tourelles de réserve sont posées, en groupe (" .. tostring(r.n_res) .. ")")
check(r.stock1 >= Ds.RESERVE, "la réserve de " .. Ds.RESERVE .. " tourelles reste au coffre (" .. tostring(r.stock1) .. ")")
check(r.stock1 < r.stock0, "le coffre a payé les tourelles (" .. r.stock0 .. " -> " .. r.stock1 .. ")")
local ok_oid = next(r.oids) ~= nil
for oid in pairs(r.oids) do if oid:sub(1, 7) ~= "reserve" then ok_oid = false end end
check(ok_oid, "inscrites dans f.turrets avec l'oid « reserve<clé> »")
local has_pose = false
for _, l in ipairs(r.poses) do if l:find(" pose a ", 1, true) and l:find("cause stock au-dela de la reserve", 1, true) then has_pose = true end end
check(has_pose, "journal [FO-DEFENSE] reserve : une ligne de pose avec sa cause")
check(r.ser, "global sérialisable")

section("Sous la réserve : rien")
local r0 = run(Ds.RESERVE - 1)
check(r0.n_res == 0 and #r0.poses == 0, "stock sous la réserve : aucune tourelle posée, aucune ligne")

section("Déterminisme")
local r2 = run(60)
local same = #r2.logs == #r.logs and r2.n_res == r.n_res and r2.stock1 == r.stock1
for i = 1, math.min(#r.logs, #r2.logs) do if r.logs[i] ~= r2.logs[i] then same = false end end
check(same, "deux passages identiques (journal compris)")

print(string.format("[DEFENSE-STOCK-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
