--[[
  Lot COLLECTE : règle pure shared/team/rappel_urgent.lua (rappel d'un PNJ occupé pour une tâche urgente que personne ne prend).
  Cas : la collecte de fer (2 PNJ : exploration, minage de pierre) et le coffre en bois urgent de STOCKAGE-VITAL (4 PNJ : éclaireur, minage à 111 tuiles).
  Mutants : chaque règle cassée est vue. Coût : instructions Lua comptées par debug.sethook (déterministe), jamais le temps.
  Usage : lua5.2 tests/rappel_urgent_test.lua
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local current, quiet = nil, false
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC" .. (current and (" [mutant " .. current .. "]") or "") .. " : " .. msg) end
  end
end

local function checks(R)
  local T0 = 100000
  -- Cas 1 : la collecte du banc collecte-fer. Deux PNJ occupés : 1 explore (priorité absente), 2 mine de la pierre (70).
  local collecte = {
    tick = T0, last_at = nil,
    tasks = { { key = "ia1d:1:o:1", prio = 94, created = T0 - 600, ok = true, x = 75, y = 0 } },
    npcs = { { id = 1, busy = true, prio = 0, explore = true, x = -50, y = -50 }, { id = 2, busy = true, prio = 70, x = -50, y = 40 } },
  }
  local r = R.pick(collecte)
  check(r and r.npc == 2 and r.urgent == "ia1d:1:o:1" and r.dropped_prio == 70, "collecte : le minage de pierre est rappelé AVANT l'exploration")

  -- Cas 2 : le coffre en bois urgent (90) de STOCKAGE-VITAL, 4 PNJ : 2 éclaireurs, 2 minages de fer à 111 tuiles (prio 45 et 55).
  local bois = {
    tick = T0, last_at = T0 - 5000,
    tasks = { { key = "fond:craft:wooden-chest:annexe-urgente", prio = 90, created = T0 - 400, ok = true, x = 0, y = 0 } },
    npcs = { { id = 3, busy = true, prio = 0, explore = true, x = 200, y = 0 }, { id = 4, busy = true, prio = 0, explore = true, x = 10, y = 0 },
      { id = 5, busy = true, prio = 55, x = 111, y = 0 }, { id = 6, busy = true, prio = 45, x = 111, y = 5 } },
  }
  r = R.pick(bois)
  check(r and r.npc == 6 and r.dropped_prio == 45, "bois : le minage de fer le moins prioritaire (45) est rappelé, pas un éclaireur")

  -- Abstentions
  local c = {}
  for k, v in pairs(collecte) do c[k] = v end
  c.last_at = T0 - 1799
  local x, why = R.pick(c)
  check(x == nil and why == "pause", "un seul rappel par 30 s : 1 799 ticks après le dernier, rien")
  c.last_at = T0 - 1800
  check(R.pick(c) ~= nil, "1 800 ticks après le dernier, le rappel est permis")
  c = { tick = T0, tasks = collecte.tasks, npcs = { { id = 1, busy = false }, { id = 2, busy = true, prio = 70, x = 0, y = 0 } } }
  x, why = R.pick(c)
  check(x == nil and why == "libre", "un PNJ libre prendra la tâche tout seul : aucun rappel")
  c = { tick = T0, tasks = { { key = "u", prio = 89, created = T0 - 600, ok = true } }, npcs = collecte.npcs }
  x, why = R.pick(c)
  check(x == nil and why == "aucune urgence", "89 n'est pas une urgence")
  c = { tick = T0, tasks = { { key = "u", prio = 94, created = T0 - 299, ok = true } }, npcs = collecte.npcs }
  x, why = R.pick(c)
  check(x == nil and why == "aucune urgence", "tâche au tableau depuis moins d'une pensée : on attend")
  c = { tick = T0, tasks = { { key = "u", prio = 94, created = T0 - 600, ok = false } }, npcs = collecte.npcs }
  check(R.pick(c) == nil, "tâche que personne ne peut prendre (matière non libre) : aucun rappel inutile")

  -- Défense et priorité stricte
  c = { tick = T0, tasks = collecte.tasks, npcs = { { id = 1, busy = true, prio = 10, defending = true, x = 0, y = 0 }, { id = 2, busy = true, prio = 94, x = 0, y = 0 } } }
  x, why = R.pick(c)
  check(x == nil and why == "aucun candidat", "le PNJ en défense n'est jamais rappelé, un PNJ à priorité égale non plus")
  c = { tick = T0, tasks = collecte.tasks, npcs = { { id = 1, busy = true, prio = 93, x = 0, y = 0 } } }
  check(R.pick(c) ~= nil, "priorité 93 < 94 : rappelé")

  -- Ordre : priorité croissante, puis distance, puis numéro
  local function one(npcs)
    return R.pick({ tick = T0, tasks = { { key = "u", prio = 94, created = T0 - 600, ok = true, x = 0, y = 0 } }, npcs = npcs })
  end
  r = one({ { id = 1, busy = true, prio = 60, x = 5, y = 0 }, { id = 2, busy = true, prio = 40, x = 500, y = 0 } })
  check(r.npc == 2, "priorité la plus basse d'abord, même plus loin")
  r = one({ { id = 1, busy = true, prio = 40, x = 50, y = 0 }, { id = 2, busy = true, prio = 40, x = 5, y = 0 } })
  check(r.npc == 2, "à priorité égale, le plus proche de la tâche urgente")
  r = one({ { id = 7, busy = true, prio = 40, x = 5, y = 0 }, { id = 3, busy = true, prio = 40, x = 0, y = 5 } })
  check(r.npc == 3, "à priorité et distance égales, le plus petit numéro")
  r = one({ { id = 1, busy = true, prio = 0, explore = true, x = 1, y = 0 }, { id = 2, busy = true, prio = 80, x = 400, y = 0 } })
  check(r.npc == 2, "le minage (80) avant l'exploration, malgré sa priorité plus haute et sa distance")
  r = one({ { id = 1, busy = true, prio = 0, explore = true, x = 1, y = 0 } })
  check(r and r.npc == 1, "seule l'exploration est rappelable : elle l'est")

  -- Plusieurs urgences : la plus prioritaire, puis la plus ancienne
  c = { tick = T0, tasks = { { key = "b", prio = 90, created = T0 - 900, ok = true, x = 0, y = 0 }, { key = "a", prio = 94, created = T0 - 400, ok = true, x = 0, y = 0 } },
    npcs = { { id = 1, busy = true, prio = 50, x = 0, y = 0 } } }
  check(R.pick(c).urgent == "a", "plusieurs urgences : la plus prioritaire d'abord")
  c.tasks[2].prio = 90
  check(R.pick(c).urgent == "b", "à priorité égale, la plus ancienne")
  c = { tick = T0, tasks = { { key = "hi", prio = 96, created = T0 - 600, ok = true, x = 0, y = 0 }, { key = "lo", prio = 90, created = T0 - 600, ok = true, x = 0, y = 0 } },
    npcs = { { id = 1, busy = true, prio = 93, x = 0, y = 0 } } }
  check(R.pick(c).urgent == "hi", "l'urgence la plus haute a un candidat (93 < 96)")
  c.npcs[1].prio = 95
  check(R.pick(c) ~= nil and R.pick(c).urgent == "hi", "95 < 96 : rappelé pour 96")
  c.npcs[1].prio = 96
  check(R.pick(c) == nil, "96 n'est ni inférieur à 96 ni à 90 : personne")
end

local function fresh()
  package.loaded["shared.team.rappel_urgent"] = nil
  return require("shared.team.rappel_urgent")
end

checks(fresh())

-- Coût en instructions (debug.sethook, compteur déterministe) : 30 PNJ occupés, 200 tâches libres dont 10 urgentes.
do
  local R = fresh()
  local npcs, tasks = {}, {}
  for i = 1, 30 do npcs[i] = { id = i, busy = true, prio = 30 + i, x = i * 7, y = -i * 3, explore = (i % 9 == 0) } end
  for i = 1, 200 do tasks[i] = { key = "t" .. i, prio = (i % 20 == 0) and 94 or 55, created = 99000, ok = true, x = i, y = i } end
  local n = 0
  debug.sethook(function() n = n + 1 end, "", 1000)
  for _ = 1, 10 do R.pick({ tick = 100000, tasks = tasks, npcs = npcs }) end
  debug.sethook()
  local per_call = n * 1000 / 10
  print(string.format("[RAPPEL] coût : %.0f instructions Lua par choix (30 PNJ, 200 tâches libres, 10 urgentes)", per_call))
  check(per_call < 60000, "coût borné : moins de 60 000 instructions par choix")
end

local function wrap_ctx(R, f)
  local o = R.pick
  R.pick = function(ctx) return o(f(ctx)) end
end

local function clone(ctx, over)
  local out = { tick = ctx.tick, last_at = ctx.last_at, tasks = {}, npcs = {} }
  for i, t in ipairs(ctx.tasks) do out.tasks[i] = { key = t.key, prio = t.prio, created = t.created, ok = t.ok, x = t.x, y = t.y } end
  for i, n in ipairs(ctx.npcs) do
    out.npcs[i] = { id = n.id, busy = n.busy, prio = n.prio, defending = n.defending, explore = n.explore, x = n.x, y = n.y }
  end
  if over then over(out) end
  return out
end

local MUTANTS = {
  { "defense-rappelee", function(R) wrap_ctx(R, function(c) return clone(c, function(o) for _, n in ipairs(o.npcs) do n.defending = false end end) end) end },
  { "libre-ignore", function(R) wrap_ctx(R, function(c) return clone(c, function(o) for _, n in ipairs(o.npcs) do n.busy = true end end) end) end },
  { "pas-de-pause", function(R) wrap_ctx(R, function(c) return clone(c, function(o) o.last_at = nil end) end) end },
  { "age-ignore", function(R) wrap_ctx(R, function(c) return clone(c, function(o) for _, t in ipairs(o.tasks) do t.created = -1e9 end end) end) end },
  { "ok-ignore", function(R) wrap_ctx(R, function(c) return clone(c, function(o) for _, t in ipairs(o.tasks) do t.ok = true end end) end) end },
  { "explore-d-abord", function(R) wrap_ctx(R, function(c) return clone(c, function(o) for _, n in ipairs(o.npcs) do n.explore = false end end) end) end },
  { "seuil-89", function(R) R.URGENT = 89 end },
  { "seuil-91", function(R) R.URGENT = 91 end },
  { "pause-15s", function(R) R.EVERY = 15 * 60 end },
  { "pause-60s", function(R) R.EVERY = 60 * 60 end },
  { "age-0", function(R) R.AGE = 0 end },
  { "age-900", function(R) R.AGE = 900 end },
  { "prio-egale-rappelee", function(R)
      local o = R.pick
      R.pick = function(ctx) return o(clone(ctx, function(c) for _, t in ipairs(c.tasks) do t.prio = t.prio + 1 end end)) end
    end },
  { "plus-haute-prio-d-abord", function(R)
      local o = R.pick
      R.pick = function(ctx)
        return o(clone(ctx, function(c) for _, n in ipairs(c.npcs) do if not n.explore then n.prio = -(n.prio or 0) end end end))
      end
    end },
  { "plus-loin-d-abord", function(R)
      local o = R.pick
      R.pick = function(ctx) return o(clone(ctx, function(c) for _, n in ipairs(c.npcs) do n.x = 1000 - (n.x or 0); n.y = (n.y or 0) end end)) end
    end },
  { "plus-grand-numero-d-abord", function(R)
      local o = R.pick
      R.pick = function(ctx) return o(clone(ctx, function(c) for _, n in ipairs(c.npcs) do n.id = -n.id end end)) end
    end },
  { "plus-ancienne-d-abord-inverse", function(R)
      local o = R.pick
      R.pick = function(ctx) return o(clone(ctx, function(c) for _, t in ipairs(c.tasks) do t.created = -(t.created or 0) end end)) end
    end },
}

local killed = 0
for _, m in ipairs(MUTANTS) do
  local before, pbefore = failures, passes
  local R = fresh()
  m[2](R)
  current, quiet = m[1], true
  local okc, err = pcall(checks, R)
  current, quiet = nil, false
  local dead = (not okc) or failures > before
  if dead then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. m[1]) end
  failures, passes = before, pbefore
end
if killed < #MUTANTS then failures = failures + (#MUTANTS - killed) end
print(string.format("[RAPPEL] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
