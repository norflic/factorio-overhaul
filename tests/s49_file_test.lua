--[[
  s49 tranches : file des plans de cadre reportés (Ax.push, Ax.pop, shared/team/champ_axe.lua) et son câblage (script/team/migration_champ.lua) :
  un plan reporté (Ax.WAIT) fait son pas suivant dès le tick suivant (Events.on_nth_tick(1), UNE entrée par tick), pas à la pensée suivante
  de Mig.think (600 ticks). Pur, aucune API Factorio.
  Usage, depuis la racine du mod :   lua5.2 tests/s49_file_test.lua
]]
package.path = "./?.lua;" .. package.path
local Ax = require("shared.team.champ_axe")

local n, bad = 0, 0
local function check(c, m) if c then n = n + 1 else bad = bad + 1; print("  ECHEC : " .. m) end end

print("== s49 file : règle pure")
local q = {}
check(Ax.pop(q) == nil, "file vide : rien")
check(Ax.push(q, { key = "a:1" }) and Ax.push(q, { key = "b:2" }), "deux avant-postes en attente")
check(not Ax.push(q, { key = "a:1" }) and #q == 2, "une clé n'est qu'une fois dans la file (pensée et tick au même pas : pas de doublon)")
check(Ax.pop(q).key == "a:1" and Ax.pop(q).key == "b:2" and Ax.pop(q) == nil, "ordre d'arrivée, une entrée par appel")
-- rotation : une entrée reprise au tick T et encore en attente revient en fin de file (équipes servies chacune leur tour)
q = {}
Ax.push(q, { key = "a" }); Ax.push(q, { key = "b" })
local e = Ax.pop(q); Ax.push(q, e)
check(q[1].key == "b" and q[2].key == "a", "une entrée reportée de nouveau passe après les autres")

-- délai d'un plan à 4 variantes sur 2 axes : pas par tick (file) contre pas par pensée (600 ticks). Simulation : PLAN_TICK, Ax.step, la file.
do
  local function run(per_tick)
    local plan_tick, try, seq_n, steps = nil, nil, 0, 0
    local axis_done = 0
    local wait = {}
    local start, finish = 1000, nil
    local function frame(tick)
      local s = Ax.step(try, tick, plan_tick)
      if s == "wait" then return "wait" end
      plan_tick = tick
      seq_n, steps = seq_n + 1, steps + 1
      if seq_n < 4 then return "wait" end -- 4 variantes par axe
      seq_n = 0
      axis_done = axis_done + 1
      if s == "first" then try = { axe = "y", tick = tick }; return "wait" end
      return "done"
    end
    for tick = start, start + 20000 do
      local think = (tick - start) % 600 == 0
      local r
      if think then
        r = frame(tick)
        if r == "wait" then Ax.push(wait, { key = "o" }) end
      end
      if per_tick and not r and wait[1] then
        Ax.pop(wait)
        r = frame(tick)
        if r == "wait" then Ax.push(wait, { key = "o" }) end
      end
      if r == "done" then finish = tick; break end
    end
    return finish and (finish - start), steps
  end
  local d0, s0 = run(false)
  local d1, s1 = run(true)
  check(s0 == 8 and s1 == 8, string.format("8 pas (4 variantes x 2 axes) dans les deux cas (%s, %s)", tostring(s0), tostring(s1)))
  check(d0 == 7 * 600, string.format("à la pensée seule : %s ticks", tostring(d0)))
  check(d1 == 7, string.format("par la file : %s ticks (un pas par tick)", tostring(d1)))
  print(string.format("  plan à 4 variantes sur 2 axes : %d ticks à la pensée seule, %d ticks par la file", d0 or -1, d1 or -1))
end

print("== s49 file : câblage (script/team/migration_champ.lua)")
do
  local h = assert(io.open("script/team/migration_champ.lua", "r"))
  local src = h:read("*a")
  h:close()
  check(src:find("local FRAME_WAIT = {}", 1, true) ~= nil, "file locale au module (jamais dans global)")
  check(src:find("Events.on_nth_tick(1, function(e) if FRAME_WAIT[1] then Mig.frame_tick(e.tick) end end)", 1, true) ~= nil,
    "abonnement statique au tick : rien si la file est vide")
  local fi = src:find("function Mig.frame_tick(tick)", 1, true)
  local fe = fi and src:find("\nend\n", fi, true)
  local blk = (fi and fe) and src:sub(fi, fe) or ""
  local npop = 0
  for _ in blk:gmatch("Ax%.pop%(") do npop = npop + 1 end
  check(npop == 1 and blk:find("frame_take(f, w.surface, ms, o, st, tick)", 1, true) ~= nil, "Mig.frame_tick : UNE entrée par tick, le même pas que la pensée")
  check(blk:find("st.frame or st.abandoned or ms.verify_due", 1, true) ~= nil, "entrée laissée si le cadre est déjà pris, abandonné ou un autre en vérification")
  local ti = src:find("local function frame_take(", 1, true)
  local te = ti and src:find("\nend\n", ti, true)
  local tb = (ti and te) and src:sub(ti, te) or ""
  check(tb:find("order == Ax.WAIT", 1, true) ~= nil and tb:find("Ax.push(FRAME_WAIT", 1, true) ~= nil, "un plan reporté entre dans la file")
  check(src:find("if not st.frame then frame_take(f, surface, ms, o, st, tick); return false end", 1, true) ~= nil,
    "la pensée de Mig.think passe par le même pas (verrou d'un plan par tick dans Champ.frame : pas de pas en double)")
end

print(string.format("s49 file : %d OK, %d ECHEC(S)", n, bad))
os.exit(bad == 0 and 0 or 1)
