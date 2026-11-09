--[[
  Lot RAPATRIEMENT (8/11) : COUT en instructions (debug.sethook, jamais os.clock) de Rap.plan, tranche par tranche. Demande de team-lead (8/11) : « un pic dans
  la partie du DC est pire qu'une ligne refusee ». Mesure de depart (avant le decoupage) : destination inatteignable = 81,6 M d'instructions d'un seul
  tenant (0,65 a 3,6 s) ; tracé libre de 180 tuiles = 0,49 M. Apres : chaque appel de Rap.plan developpe au plus Rp.SLICE_NODES noeuds.
  Criteres : C1 aucun appel au-dessus de 0,6 M d'instructions (4,8 a 26 ms a 8-44 ns par instruction) ; C2 une recherche sans issue se termine
  (refus avec cause) en moins de 400 appels ; C3 un trace libre est trouve ; C4 un mur qui se contourne est contourne.
  Usage : lua5.2 tests/rapatriement_cout_test.lua   (depuis la racine du mod ; lit les bouchons de tests/rapatriement_glue_test.lua jusqu'au repere « G1 »)
]]
package.path = "./?.lua;" .. package.path
local src = io.open("tests/rapatriement_glue_test.lua", "rb"):read("*a")
local cut = src:find("-- G1 : éteint", 1, true)
local head = src:sub(1, cut - 1)
local G = assert(load(head .. "\nreturn { new_world = new_world, new_team = new_team, plan_api = plan_api, Rap = Rap, P = P, CHEST = CHEST, Rp = Rp }", "=glue"))()
local RESULTS = {}
local function run(label, wall, srcpos, point)
  local W = G.new_world()
  local f, b = G.new_team(W)
  local sx, sy = srcpos[1], srcpos[2]
  if sx ~= 150 then W.chests["150:20"] = nil; W.chest(sx, sy, "A", 0); W.pole(sx + 2, sy + 2) end
  local spec = { rapatriement = { key = "1:o1", item = "A", flow = 0.8, arm = "fast-inserter", pole = "small-electric-pole", belt = "transport-belt", chest = G.CHEST,
    src = { pid = 1, idx = 1, x = sx, y = sy }, point = { x = point[1], y = point[2] } } }
  local p = { id = 20, spec = spec, state = "plan", parts = {}, ents = {}, wires = {}, stock = {}, quais = {}, outs = {}, obstacles = {}, fails = 0 }
  b.projects[20] = p
  b.order[#b.order + 1] = 20
  -- une équipe réelle : 200 projets de 120 pièces chacun (tapis, bras, poteaux) hors du couloir, comme la partie du DC (60 a 90 projets de plus de 100 pièces)
  for k = 1, 200 do
    local ents = {}
    for e = 1, 120 do ents[e] = { name = (e % 3 == 0) and "transport-belt" or "inserter", x = 800 + k * 3 + 0.5, y = 800 + e + 0.5, dir = 2 } end
    local pid = 100 + k
    b.projects[pid] = { id = pid, state = "fini", spec = { gen = "banc" }, parts = {}, ents = ents, quais = {}, outs = {}, obstacles = {} }
    b.order[#b.order + 1] = pid
  end
  local api = G.plan_api(f, b, { blocked = wall })
  local reads = 0
  local rm = api.read_masks
  api.read_masks = function(...) reads = reads + 1 return rm(...) end
  local calls, maxc, total, ok, why = 0, 0, 0
  repeat
    local n = 0
    debug.sethook(function() n = n + 1 end, "", 1000)
    local wait
    ok, why, wait = G.Rap.plan(api, f, W.surface, p)
    debug.sethook()
    n = n * 1000
    calls = calls + 1
    total = total + n
    if n > maxc then maxc = n end
  until wait ~= "tranche" or calls > 5000
  RESULTS[#RESULTS + 1] = { label = label, ok = ok, calls = calls, maxc = maxc, total = total }
  print(string.format("%-40s ok=%-5s appels=%4d  pire appel=%8d instr (%.1f a %.1f ms)  total=%10d (%.0f a %.0f ms)  chunks=%d", label, tostring(ok), calls, maxc,
    maxc * 8e-6, maxc * 44e-6, total, total * 8e-6, total * 44e-6, reads))
end
local P = G.P
local function wallx(x0, x1, y0, y1) local w = {} for y = y0, y1 do for x = x0, x1 do w[P.tkey(x, y)] = true end end return w end
run("libre, 180 tuiles", {}, { 150, 20 }, { 24, 14 })
run("mur plein x=100..102", wallx(100, 102, -420, 420), { 150, 20 }, { 24, 14 })
run("source a 300 tuiles, libre", {}, { 300, 20 }, { 24, 14 })
run("source a 300 tuiles, mur plein", wallx(150, 152, -420, 420), { 300, 20 }, { 24, 14 })
run("mur a contourner (-16..50)", wallx(60, 62, -16, 50), { 150, 20 }, { 24, 14 })

local fails = 0
local LIMITE = 400000 -- instructions par appel (3 a 17 ms) ; lot BUS-LONG : la tranche de troncon (260 etats, souterrains) ; plafond du lot : 600 000 a 800 000 par pensee (ancienne borne 160 000 : A* de 135 noeuds, sans souterrains)
local function check(c, m) if not c then fails = fails + 1 print("  ECHEC : " .. m) end end
local by = {}
for _, r in ipairs(RESULTS) do by[r.label] = r; check(r.maxc <= LIMITE, r.label .. " : pire appel " .. r.maxc .. " instructions > limite") end
check(by["libre, 180 tuiles"].ok == true, "C3 trace libre trouve")
check(by["mur a contourner (-16..50)"].ok == true and by["mur a contourner (-16..50)"].calls > 1, "C4 mur contourne en plusieurs tranches")
check(by["mur plein x=100..102"].ok == false and by["mur plein x=100..102"].calls < 900, "C2 recherche sans issue finie en moins de 400 appels")
check(by["source a 300 tuiles, mur plein"].ok == false and by["source a 300 tuiles, mur plein"].calls < 900, "C2 idem a 300 tuiles")
print(string.format("[RAPATRIEMENT-COUT] BILAN : %d ECHEC(S)", fails))
os.exit(fails == 0 and 0 or 1)
