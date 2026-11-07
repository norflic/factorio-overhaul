--[[
  Lot TRANCHES des foreuses (lead, 7/11 : tt:foswap jusqu'à 125 ms d'un bloc dans la pensée E4 de 0.6.58). Swap.think joue sa passe par
  tranches bornées (script/team/foreuse_swap.lua, Swap.SLICE) ; l'état de la passe est dans f.swap.pass (global), la suite au tick suivant
  (minuterie). PREUVE : sur un monde factice INCHANGÉ entre deux tranches, la passe en tranches décide EXACTEMENT comme la passe d'un bloc
  (Swap.SLICED = false) : même global (f.swap hors de la passe, avant-postes, registre des propriétaires, stock, tableau des tâches), même
  monde (entités posées et retirées, fils), même journal, sur plusieurs passes. Plus : la passe en tranches en compte vraiment plusieurs,
  chaque tranche est bornée, la passe gardée dans global ne contient aucune fonction, et une passe sans fin est abandonnée. Mutants.

  Monde factice : deux avant-postes de fer (16 paires serrées, et 3 paires loin de tout poteau), un petit poteau source de l'équipe
  alimenté, stock de 4 électriques et 30 petits poteaux.
  Usage, depuis la racine du mod :   lua5.2 tests/foreuse_tranches_test.lua
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local SRC_PATH = "script/team/foreuse_swap.lua"
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end
local SRC = read(SRC_PATH)

local ok_n, bad = 0, 0
local function check(name, cond, detail)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[FOREUSE-TRANCHES] ECHEC : " .. name .. (detail and (" (" .. tostring(detail) .. ")") or "")) end
end

local Monde = require("tests.foreuse_monde") -- monde factice (extrait de ce fichier pour tests/foreuse_reserve_test.lua)
local sorted_keys = Monde.sorted_keys

--- Monde de départ : avant-poste 1 (16 paires serrées sur du fer, 2 rangées), avant-poste 2 (3 paires loin de tout poteau), source alimentée.
local function build(W)
  for x = 0, 44 do for y = 4, 20 do W.add("iron-ore", x + 0.5, y + 0.5, 0) end end
  for x = 100, 140 do for y = 4, 16 do W.add("iron-ore", x + 0.5, y + 0.5, 0) end end
  local hq = W.add("fo-team-chest", 20.5, 60.5, 0, { force = "player" })
  hq.surface = W.surface
  local function outpost(id, pos, pairs_at)
    local o = { id = id, kind = "iron", pos = pos, drill_list = {}, sinks = {}, drills = 0 }
    for _, q in ipairs(pairs_at) do
      local d = W.add("burner-mining-drill", q[1], q[2], 0, { force = "player" })
      d.inv.fuel.coal = 5
      local s = W.add("stone-furnace", q[1] - 1, q[2] - 2, 0, { force = "player" })
      s.inv[2]["iron-ore"] = 7
      s.inv[3]["iron-plate"] = 11
      o.drill_list[#o.drill_list + 1] = d
      o.sinks[#o.sinks + 1] = s
      o.drills = o.drills + 1
    end
    return o
  end
  local row = {}
  for i = 0, 7 do row[#row + 1] = { 10 + 2 * i, 10 } end
  for i = 0, 7 do row[#row + 1] = { 10 + 2 * i, 14 } end
  local o1 = outpost(1, { x = 17, y = 12 }, row)
  local o2 = outpost(2, { x = 120, y = 10 }, { { 110, 10 }, { 114, 10 }, { 118, 10 } })
  local src = W.add("small-electric-pole", 20.5, 30.5, 0, { force = "player", source = true })
  return hq, { [1] = o1, [2] = o2 }, src
end

local function fresh(text, sliced, slice) return Monde.fresh(text, sliced, slice, build) end
local use, play = Monde.use, Monde.play

--- Image de l'état : global (f.swap sans la passe, avant-postes), propriétaires, stock, tâches, monde, fils, journal.
local function snapshot(R)
  local out = {}
  local function put(s) out[#out + 1] = s end
  local function ser(v, depth)
    depth = depth or 0
    if type(v) ~= "table" then return tostring(v) end
    if v.unit_number and v.position then return string.format("E%d", v.unit_number) end
    local parts = {}
    for _, k in ipairs(sorted_keys(v)) do if not (depth == 0 and k == "pass") then parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k], depth + 1) end end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  put("swap " .. ser(R.f.swap or {}))
  for _, oid in ipairs(sorted_keys(R.f.outposts)) do
    local o = R.f.outposts[oid]
    local dl, sl, pl = {}, {}, {}
    for _, d in ipairs(o.drill_list) do dl[#dl + 1] = (d.valid and "" or "x") .. d.unit_number end
    for _, s in ipairs(o.sinks) do sl[#sl + 1] = (s.valid and "" or "x") .. s.unit_number end
    for _, p in ipairs(o.swap_poles or {}) do pl[#pl + 1] = p.unit_number end
    put(string.format("o%d drills=%d [%s] sinks [%s] poles [%s]", oid, o.drills, table.concat(dl, " "), table.concat(sl, " "), table.concat(pl, " ")))
  end
  put("own " .. ser(R.env.own))
  put("stock " .. ser(R.env.stock))
  put("board " .. table.concat(R.env.board, " | "))
  for _, e in ipairs(R.W.ents) do
    if e.name ~= "iron-ore" then
      local w = {}
      for _, n in ipairs(e.wires) do if n.valid then w[#w + 1] = n.unit_number end end
      table.sort(w)
      put(string.format("e%d %s %.2f %.2f %d %s [%s]", e.unit_number, e.name, e.position.x, e.position.y, e.direction, tostring(e.valid), table.concat(w, " ")))
    end
  end
  for _, l in ipairs(R.W.logs) do put("log " .. l) end
  return out
end

local function compare(a, b)
  local n = math.max(#a, #b)
  for i = 1, n do if a[i] ~= b[i] then return false, string.format("ligne %d :\n  bloc    %s\n  tranches %s", i, tostring(a[i]), tostring(b[i])) end end
  return true
end

local PASSES = 4
local function suite(text)
  local res = {}
  local function c(name, cond, detail) res[#res + 1] = { name, cond and true or false, detail } end
  local okA, A = pcall(fresh, text, false)
  local okB, B = pcall(fresh, text, true, 40)
  if not (okA and okB) then c("module charge", false, tostring(A) .. " / " .. tostring(B)) return res end
  local okp1, sA = pcall(play, A, PASSES)
  local okp2, sB = pcall(play, B, PASSES)
  if not (okp1 and okp2) then c("passes jouees", false, tostring(sA) .. " / " .. tostring(sB)) return res end
  local imA, imB = snapshot(A), snapshot(B)
  local same, where = compare(imA, imB)
  c("tranches = bloc : global, monde, fils et journal identiques sur " .. PASSES .. " passes", same, where)
  c("bloc : aucune minuterie (passe d'un appel)", sA == 0, tostring(sA))
  c("tranches : la passe en compte vraiment plusieurs (au moins 3 par passe)", sB >= 3 * PASSES, tostring(sB))
  c("tranches : aucune passe laissee en cours", not B.stuck)
  c("tranches : passe gardee dans global sans fonction", not B.fn_in_global)
  -- le cas n'est pas vide : des electriques posees, des chaines, des echanges, des refus
  local st = A.f.swap or {}
  local why = st.why or {}
  c("le cas n'est pas vide : electriques posees, chaines, echanges, refus", (st.done or 0) >= 3 and (st.chained or 0) >= 1 and (st.exchanged or 0) >= 1 and next(why) ~= nil,
    string.format("faites %s, chaines %s, echanges %s, refus %s", tostring(st.done), tostring(st.chained), tostring(st.exchanged), tostring(next(why))))
  -- une tranche plus fine ne change rien non plus
  local okC, C = pcall(fresh, text, true, 5)
  if okC and pcall(play, C, PASSES) then
    local sameC, whereC = compare(imA, snapshot(C))
    c("tranches de 5 unites = bloc", sameC, whereC)
  else
    c("tranches de 5 unites jouees", false)
  end
  return res
end

local function run(text)
  local okr, res = pcall(suite, text)
  if not okr then return { { "suite : " .. tostring(res), false } } end
  return res
end
for _, r in ipairs(run(SRC)) do check(r[1], r[2], r[3]) end

-- Passe sans fin (minuterie perdue) : abandonnee après Swap.PASS_MAX, la suivante repart du relevé.
do
  local R = fresh(SRC, true, 40)
  use(R)
  game.tick = 0
  R.Swap.think(R.f, R.W.surface, R.env.book, { ["electric-mining-drill"] = 4, ["small-electric-pole"] = 30 }, 0)
  R.env.queue = {} -- minuterie perdue
  local stuck = R.f.swap.pass ~= nil
  game.tick = R.Swap.PASS_MAX + T.swap.every
  R.Swap.think(R.f, R.W.surface, R.env.book, { ["electric-mining-drill"] = 4, ["small-electric-pole"] = 30 }, game.tick)
  local restarted = R.f.swap.pass ~= nil and R.f.swap.pass.t0 == game.tick
  local logged = false
  for _, l in ipairs(R.W.logs) do if l:find("sans fin", 1, true) then logged = true end end
  check("passe sans fin abandonnee apres Swap.PASS_MAX, la suivante repart (une ligne au journal)", stuck and restarted and logged)
end

local CR = SRC:find("\r\n", 1, true) and "\r\n" or "\n"
local MUT = {
  { "tranche qui perd la foreuse ou elle s'arrete", "        if used >= budget then return used, false end", "        if used >= budget then pass.di = pass.di + 1 return used, false end" },
  { "refus du plan dates au tick courant", "    if ref then st.retry[ref.key] = t0 + Swap.RETRY end", "    if ref then st.retry[ref.key] = game.tick + Swap.RETRY end" },
  { "releve qui lit le tick courant", "          if not (retry[key] and pass.t0 < retry[key]) then", "          if not (retry[key] and game.tick < retry[key]) then" },
  { "suite de la passe jamais programmee", "    if used >= budget then" .. CR .. "      Scheduler.after(1, Swap.TIMER, { fid = f.id })", "    if used >= budget then" .. CR .. "      do end" },
  { "minuterie qui abandonne la passe", "  run_pass(f, f.hq.surface, book, pass)" .. CR .. "end)", "  f.swap.pass = nil" .. CR .. "end)" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUT) do
  local a, z = SRC:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif introuvable)"
  else
    local res = run(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(z + 1))
    local seen = false
    for _, r in ipairs(res) do
      if not r[2] then
        seen = true
        print(string.format("[FOREUSE-TRANCHES] mutant « %s » refuse par : %s", m[1], r[1]))
        break
      end
    end
    if seen then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(string.format("mutants refuses %d/%d%s", refused, #MUT, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""), refused == #MUT)
print(string.format("[FOREUSE-TRANCHES] mutants refuses %d/%d", refused, #MUT))
print(string.format("[FOREUSE-TRANCHES] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
