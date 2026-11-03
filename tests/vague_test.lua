--[[
  Lot CHARBON3 (Q4, 3/11) : test hors jeu de shared/team/vague.lua (tournée proche rejugée sans les marques d'une vague passée).
    §1 V.split : mêmes poids que D.exact_parts (kept + stale = fixed + mobile) sur une carte tirée au hasard (graine fixe) ;
    §2 classement : ver et nid toujours comptés, meute et case mobile comptées fraîches, écartées passées V.QUIET ;
    §3 V.applies : tournée seulement, refus pour le danger seulement (jamais pour des morts), but à moins de V.NEAR_R du QG ;
    §4 cas du journal (0.6.43N 1618033988) : QG (7, 7), but de la tournée de charbon (9, -18), case mobile au plafond et meute :
       refus pendant la vague, départ 1 min après la dernière vue, refus si un ver garde le but ou si la meute est revue ;
    §5 suite simulée de 20 min (vagues revues toutes les 3 min) : part du temps où la tournée peut partir, avec et sans la règle ;
    §6 câblage (script/ai3/comportement.lua) ; §7 mutants ; §8 aucun nom d'objet.
  Usage : lua5.2 tests/vague_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local D = require("shared.ai3.danger")

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/vague.lua")
local function load_v(src)
  local fn = load(src, "=vague", "t")
  if not fn then return nil end
  local ok, m = pcall(fn)
  return ok and m or nil
end

local ok_n, bad = 0, 0
local function check(name, cond)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[VAGUE] ECHEC : " .. name) end
end

local MIN = 3600
local HQ = { x = 7, y = 7 }
local GOAL = { x = 9, y = -18 }

--- Carte du journal : case mobile du but au plafond (vue à t_mob), meute à 12 tuiles du but (vue à t_pack), ver facultatif.
local function journal_map(t_mob, t_pack, worm)
  local map = D.new()
  map.cells[D.key(D.cell(GOAL.x), D.cell(GOAL.y))] = { m = D.MOBILE_CAP, t = t_mob }
  map.n_cells = 1
  if t_pack then map.threats[#map.threats + 1] = { x = 15, y = -28, k = "pack", r = 30, t = t_pack } end
  if worm then map.threats[#map.threats + 1] = { x = 20, y = -40, k = "worm", r = 30, t = 30 * MIN } end -- vu 11 min avant le controle : environ 800, au-dessus du seuil
  return map
end

-- route droite du QG au but : échantillons de la porte (R.samples, pas R.SAMPLE, départ et but compris)
local Rt = require("shared.ai3.route")
local function samples(p, g) return Rt.samples(p, {}, g, Rt.SAMPLE) end

local function suite(V)
  local res = {}
  local function c(name, cond) res[#res + 1] = { name, cond and true or false } end
  -- §1 mêmes poids que D.exact_parts
  local seed = 12345
  local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648 return seed % n end
  local kinds = { "worm", "turret", "spawner", "pack" }
  local same_all, n_pts = true, 0
  for trial = 1, 40 do
    local map = D.new()
    local tick = 30 * MIN + rnd(30 * MIN)
    for _ = 1, 6 do
      map.threats[#map.threats + 1] = { x = rnd(200) - 100, y = rnd(200) - 100, k = kinds[1 + rnd(4)], r = 20 + rnd(20), t = tick - rnd(20 * MIN) }
    end
    for _ = 1, 10 do
      local x, y = rnd(200) - 100, rnd(200) - 100
      map.cells[D.key(D.cell(x), D.cell(y))] = { m = 100 + rnd(800), t = tick - rnd(10 * MIN) }
    end
    for _ = 1, 10 do
      local x, y = rnd(200) - 100, rnd(200) - 100
      local P = D.exact_parts(map, x, y, tick)
      local k, s = V.split(map, x, y, tick)
      n_pts = n_pts + 1
      if k + s ~= P.fixed + P.mobile then same_all = false end
    end
  end
  c(string.format("§1 kept + stale = fixed + mobile de D.exact_parts (%d points)", n_pts), same_all)
  -- §2 classement
  local T0 = 40 * MIN
  local m1 = D.new()
  m1.threats[1] = { x = 0, y = 0, k = "worm", r = 30, t = T0 - 10 * MIN }
  local k, s = V.split(m1, 0, 0, T0)
  c("§2 ver vu il y a 10 min : compte (menace permanente)", k > 0 and s == 0)
  m1.threats[1] = { x = 0, y = 0, k = "spawner", r = 30, t = T0 - 10 * MIN }
  k, s = V.split(m1, 0, 0, T0)
  c("§2 nid vu il y a 10 min : compte", k > 0 and s == 0)
  m1.threats[1] = { x = 0, y = 0, k = "pack", r = 30, t = T0 - 30 * 60 }
  k, s = V.split(m1, 0, 0, T0)
  c("§2 meute vue il y a 30 s : fraiche, comptee", k == 800 and s == 0)
  m1.threats[1] = { x = 0, y = 0, k = "pack", r = 30, t = T0 - V.QUIET }
  k, s = V.split(m1, 0, 0, T0)
  c("§2 meute vue il y a V.QUIET : passee, ecartee", k == 0 and s == 720)
  local m2 = D.new()
  m2.cells[D.key(D.cell(0), D.cell(0))] = { m = 900, t = T0 - 30 * 60 }
  k, s = V.split(m2, 0, 0, T0)
  c("§2 case mobile vue il y a 30 s : comptee", k == 900 and s == 0)
  m2.cells[D.key(D.cell(0), D.cell(0))] = { m = 900, t = T0 - 2 * MIN }
  k, s = V.split(m2, 0, 0, T0)
  c("§2 case mobile vue il y a 2 min : ecartee (729)", k == 0 and s == 729)
  -- §3 V.applies
  c("§3 tournee proche refusee pour le but : oui", V.applies("service", "but", HQ, GOAL))
  c("§3 bloque et marque : oui", V.applies("service", "bloque", HQ, GOAL) and V.applies("service", "marque", HQ, GOAL))
  c("§3 refus pour des morts : non", not V.applies("service", "mort", HQ, GOAL) and not V.applies("service", "morts", HQ, GOAL))
  c("§3 boucle de detours : non", not V.applies("service", "boucle", HQ, GOAL))
  c("§3 autre tache (minage, fortification, recharge) : non", not V.applies("mine", "but", HQ, GOAL)
    and not V.applies("fortify", "but", HQ, GOAL) and not V.applies("refill", "but", HQ, GOAL))
  c("§3 but a 63 tuiles : oui ; a 65 : non", V.applies("service", "but", HQ, { x = HQ.x + 63, y = HQ.y })
    and not V.applies("service", "but", HQ, { x = HQ.x + 65, y = HQ.y }))
  c("§3 sans QG : non", not V.applies("service", "but", nil, GOAL))
  -- §4 cas du journal
  local ctx = { B = 600, prudence = 1000, escort_ok = false }
  local P = { x = 4, y = 9 }
  local pts = samples(P, GOAL)
  local function orig(map, tick)
    local mx = 0
    for _, q in ipairs(pts) do
      local dx, dy = q.x - P.x, q.y - P.y
      if dx * dx + dy * dy > 36 then local v = D.danger_exact(map, q.x, q.y, tick) if v > mx then mx = v end end
    end
    local g = D.danger_exact(map, GOAL.x, GOAL.y, tick)
    return { blocked = mx >= ctx.B, max_d = mx, goal_d = g, deaths = 0, far = false }
  end
  local mapA = journal_map(T0, T0)
  local iA = orig(mapA, T0 + 30 * 60)
  local d0 = D.gate(iA, ctx)
  local dA = V.gate(iA, mapA, P, pts, GOAL, T0 + 30 * 60, ctx)
  c(string.format("§4 vague vue il y a 30 s (but %d) : refus d'origine et refus rejuge", iA.goal_d), d0 == "wait" and dA == "wait")
  local tB = T0 + 90 * 60
  local iB = orig(mapA, tB)
  local d1 = D.gate(iB, ctx)
  local dB, wB, nB, i2 = V.gate(iB, mapA, P, pts, GOAL, tB, ctx)
  c(string.format("§4 vue il y a 90 s (but %d) : refus d'origine, depart rejuge (%s, %s, %d point(s), but sans marques %d)",
    iB.goal_d, tostring(dB), tostring(wB), nB, i2.goal_d), d1 == "wait" and dB == "go" and nB > 0 and i2.goal_d == 0)
  local mapW = journal_map(T0, T0, true)
  local iW = orig(mapW, tB)
  local dW = V.gate(iW, mapW, P, pts, GOAL, tB, ctx)
  c("§4 un ver garde le but : refus garde", dW == "wait")
  local ctxA = { B = 600, prudence = 500, escort_ok = false }
  local iW2 = { blocked = false, max_d = iW.max_d, goal_d = iW.goal_d, deaths = 0, far = false }
  local dW2, wW2 = V.gate(iW2, mapW, P, pts, GOAL, tB, ctxA)
  c("§4 un ver garde le but, PNJ audacieux, route non bloquee : refus garde (but)", dW2 == "wait" and wW2 == "but")
  local mapR = journal_map(T0, tB - 20 * 60)
  local iR = orig(mapR, tB)
  local dR = V.gate(iR, mapR, P, pts, GOAL, tB, ctx)
  c("§4 meute revue il y a 20 s : refus garde (vague en cours)", dR == "wait")
  local dZ, _, nZ = V.gate(iB, D.new(), P, pts, GOAL, tB, ctx)
  c("§4 aucune marque passee : rien a rejuger", dZ == "wait" and nZ == 0)
  -- route bloquée par une meute fraîche hors du but, PNJ audacieux (marque admise) : bloqué reste bloqué
  local mapF = D.new()
  mapF.cells[D.key(D.cell(GOAL.x), D.cell(GOAL.y))] = { m = 900, t = T0 }
  mapF.threats[1] = { x = 6, y = -2, k = "pack", r = 6, t = tB - 10 * 60 }
  local iF = orig(mapF, tB)
  local dF = V.gate(iF, mapF, P, pts, GOAL, tB, ctxA)
  c("§4 route bloquee par une meute fraiche (PNJ audacieux) : refus garde", iF.blocked and dF == "wait")
  -- §5 suite simulée : vagues revues toutes les 3 min (case mobile au plafond, meute), 20 min, contrôle toutes les 10 s
  local open_rule, open_orig, n = 0, 0, 0
  local map5 = journal_map(0, 0)
  for tk = 0, 20 * MIN, 600 do
    if tk % (3 * MIN) == 0 then
      map5.cells[D.key(D.cell(GOAL.x), D.cell(GOAL.y))] = { m = D.MOBILE_CAP, t = tk }
      map5.threats[1].t = tk
    end
    local i5 = orig(map5, tk)
    local d5 = D.gate(i5, ctx)
    local r5 = d5
    if d5 == "wait" and V.applies("service", "but", HQ, GOAL) then r5 = V.gate(i5, map5, P, pts, GOAL, tk, ctx) end
    n = n + 1
    if d5 ~= "wait" then open_orig = open_orig + 1 end
    if r5 ~= "wait" then open_rule = open_rule + 1 end
  end
  res.open_rule, res.open_orig, res.n = open_rule, open_orig, n
  c(string.format("§5 vagues toutes les 3 min : depart possible %d/%d avec la regle (>= 50 %%), %d/%d sans (0)", open_rule, n, open_orig, n),
    open_orig == 0 and open_rule * 2 >= n)
  return res
end

local V0 = assert(load_v(SRC), "module illisible")
local base = suite(V0)
for _, r in ipairs(base) do check(r[1], r[2]) end
print(string.format("[VAGUE] suite de 20 min, vagues revues toutes les 3 min : tournee possible %d/%d controles avec la regle, %d/%d sans",
  base.open_rule, base.n, base.open_orig, base.n))

-- §6 câblage
local C = read("script/ai3/comportement.lua")
check("§6 comportement charge la regle", C:find('local Vg = require("shared.team.vague")', 1, true) ~= nil)
check("§6 porte : regle appliquee a un refus (interrupteur f.team.sorties_vague, lot CHARBON4)", C:find('if decision == "wait" and Vg.on(f.team and f.team.sorties_vague) and Vg.applies(task.kind, why, f.hq_pos, dest) then', 1, true) ~= nil)
check("§6 interrupteur : nil = allumee, false = coupee", V0.on(nil) == true and V0.on(false) == false and V0.on(true) == true)
check("§6 porte rejugee sur la route du moindre danger", C:find("local qs = R.samples(p, (alt or res).pts, dest, R.SAMPLE)", 1, true) ~= nil
  and C:find("Vg.gate(ginfo, t.map, p, qs, dest, tick, { B = res.B, prudence = prud, escort_ok = free >= 2 })", 1, true) ~= nil)
check("§6 depart avec le risque accepte", C:find('if vague and decision == "go" then a.risk = true end', 1, true) ~= nil)
local i_rule = C:find("Vg.applies(task.kind", 1, true)
local i_loop = C:find('decision, why = "wait", "boucle"', 1, true)
local i_reset = C:find("a.escort, a.risk, a.calm = nil, nil, nil", 1, true)
local i_risk = C:find('if vague and decision == "go" then a.risk = true end', 1, true)
check("§6 ordre : regle, puis garde des boucles, puis remise a zero, puis risque", i_rule and i_loop and i_reset and i_risk
  and i_rule < i_loop and i_loop < i_reset and i_reset < i_risk)
check("§6 journal [FO-VAGUE] (une ligne au plus toutes les Ac.LOG_GAP par equipe)", C:find("[FO-VAGUE]", 1, true) ~= nil
  and C:find("tick - t.vague_log_t >= Ac.LOG_GAP", 1, true) ~= nil)

-- §7 mutants
local MUTANTS = {
  { "jamais passee (delai ignore)", "if K.fast and tick - t.t >= quiet then", "if false then" },
  { "ver ecarte comme une meute", "if K.fast and tick - t.t >= quiet then", "if tick - t.t >= quiet then" },
  { "case mobile toujours ecartee", "if tick - c.t >= quiet then stale", "if true then stale" },
  { "case mobile jamais ecartee", "if tick - c.t >= quiet then stale", "if false then stale" },
  { "delai inverse", "if K.fast and tick - t.t >= quiet then", "if K.fast and tick - t.t < quiet then" },
  { "toute tache", "if not (V.KINDS[kind] and V.WHY[why] and hq and goal) then return false end", "if not (V.WHY[why] and hq and goal) then return false end" },
  { "tout motif (morts compris)", "if not (V.KINDS[kind] and V.WHY[why] and hq and goal) then return false end", "if not (V.KINDS[kind] and hq and goal) then return false end" },
  { "sans rayon du QG", "return dx * dx + dy * dy <= V.NEAR_R * V.NEAR_R", "return true" },
  { "route jamais bloquee", "blocked = (info.blocked and mx >= B) or false", "blocked = false" },
  { "but non rejuge", "goal_d = kg,", "goal_d = 0," },
  { "route non rejugee", "if k > mx then mx = k end", "" },
  { "rejuge sans marque passee", "if ns == 0 then return \"wait\", nil, 0, i2 end", "" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif absent)"
  else
    local mod = load_v(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))
    local seen = mod == nil
    if not seen then
      local ok, res = pcall(suite, mod)
      if not ok then seen = true else for _, r in ipairs(res) do if not r[2] then seen = true break end end end
    end
    if seen then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(string.format("§7 mutants refuses %d/%d%s", refused, #MUTANTS, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""), refused == #MUTANTS)

-- §8 aucun nom d'objet du jeu
local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
local names = { "coal", "stone", "iron", "chest", "furnace", "drill", "character", "companion", "water", "player", "biter" }
local found = {}
for _, nm in ipairs(names) do if code:find(nm, 1, true) then found[#found + 1] = nm end end
check("§8 aucun nom d'objet dans le module" .. (#found > 0 and (" : " .. table.concat(found, ",")) or ""), #found == 0)

print(string.format("[VAGUE] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
