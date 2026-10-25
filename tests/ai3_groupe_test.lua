--[[
  IA3 (conception) : test hors jeu des PROTOTYPES du groupe organisé (NON BRANCHÉS) : registre des réservations
  (shared/ai3/registre.lua) et place de marché des tâches (shared/ai3/marche.lua). docs/IA3_CERVEAU.md §2.2, §2.3, §7.

  Ce qu'il prouve :
    1. l'exemple de la machine à vapeur (§2.2) : réservation, prise stricte, préemption réglée ;
    2. 20 000 opérations tirées au hasard (générateur déterministe) : jamais de réservation au-delà du stock, jamais
       de prise au-delà d'une réservation, jamais de préemption hors des règles ; même suite, même état ;
    3. place de marché : jamais un PNJ libre sans tâche s'il existe une tâche libre qu'il sait faire (1 000 tableaux) ;
       le rôle oriente, l'urgence passe avant le rôle, l'anti-ruée, le déterminisme ;
    4. simulation jouet (8 PNJ, travail concentré à la base comme dans IA3-DIAG) : règle des pôles d'aujourd'hui contre
       place de marché, mêmes arrivées : PNJ inactifs PENDANT que du travail attend.

  Usage : lua5.2 tests/ai3_groupe_test.lua   (depuis la racine du mod)
]]

package.path = "./?.lua;" .. package.path
local R = require("shared.ai3.registre")
local M = require("shared.ai3.marche")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[AI3-GROUPE] ECHEC : " .. msg) end
end

-- Générateur congruentiel déterministe (Park-Miller : produits < 2^53, exacts en double ; aucun math.random).
local function lcg(seed)
  local s = seed % 2147483647
  if s == 0 then s = 1 end
  return function(n)
    s = (s * 16807) % 2147483647
    return s % n
  end
end

-- 1. La machine à vapeur.
do
  local reg = R.new()
  R.set_stock(reg, { ["iron-plate"] = 60 }, 0)
  R.open(reg, 1, 60, 0) -- centrale à vapeur
  R.open(reg, 2, 50, 0) -- munitions de réserve
  local g1 = R.request(reg, 1, { { "iron-plate", 31 } }, 0)
  check(g1[1] and g1[1][2] == 31, "vapeur : 31 plaques réservées à la centrale")
  local g2, s2 = R.request(reg, 2, { { "iron-plate", 40 } }, 0)
  check(g2[1] and g2[1][2] == 29 and s2[1] and s2[1][2] == 11, "vapeur : les munitions n'ont que les 29 libres")
  check(R.free(reg, "iron-plate") == 0, "vapeur : plus rien de libre")
  check(R.take(reg, 1, "iron-plate", 40) == 31 - 0 and reg.stock["iron-plate"] == 29,
    "vapeur : prise stricte bornée à la réservation (31 sur 40 demandées)")
  -- On rejoue : la centrale n'a pris que 16 plaques (engrenages), 15 restent réservées au coffre.
  reg = R.new()
  R.set_stock(reg, { ["iron-plate"] = 60 }, 0)
  R.open(reg, 1, 60, 0)
  R.open(reg, 2, 50, 0)
  R.request(reg, 1, { { "iron-plate", 31 } }, 0)
  R.request(reg, 2, { { "iron-plate", 40 } }, 0)
  check(R.take(reg, 1, "iron-plate", 16) == 16, "vapeur : un PNJ de la centrale prend 16 plaques (engrenages)")
  -- Attaque : munitions (80, non engagées) contre la centrale engagée (60 + 20 % d'inertie = 72) : écart 8, refusé.
  reg.projects[2].prio = 80
  local got = R.preempt(reg, 2, "iron-plate", 15, 0)
  check(got == 0, "vapeur : écart 8 contre un projet engagé : refusé")
  reg.projects[2].prio = 102
  got = R.preempt(reg, 2, "iron-plate", 15, 0)
  check(got == 15, "vapeur : écart 30 : les 15 plaques encore au coffre partent aux munitions, pas celles en main")
  check(reg.projects[1].waiting_since == 0, "vapeur : la centrale attend (vieillissement lancé)")
  check(R.effective(reg, 1, 20 * 3600) == 60 + 12 + 20, "vieillissement : + 20 au plus après 20 min")
  local ok, msg = R.check(reg)
  check(ok, "vapeur : invariants (" .. tostring(msg) .. ")")
  -- Projet non engagé : écart 10 suffit.
  local reg2 = R.new()
  R.set_stock(reg2, { gear = 10 }, 0)
  R.open(reg2, 1, 40, 0)
  R.open(reg2, 2, 50, 0)
  R.request(reg2, 1, { { "gear", 10 } }, 0)
  check(R.preempt(reg2, 2, "gear", 5, 0) == 5, "préemption : écart 10 contre un projet non engagé")
  reg2.projects[2].prio = 45
  check(R.preempt(reg2, 2, "gear", 5, 0) == 0, "préemption : écart 5 refusé")
end

-- 2. Propriétés sur 20 000 opérations.
local function run_ops(seed, nops)
  local rnd = lcg(seed)
  local reg = R.new()
  local items = { "a", "b", "c" }
  local stock = { a = 50, b = 50, c = 50 }
  R.set_stock(reg, stock, 0)
  local next_id, viol = 1, 0
  for step = 1, nops do
    local tick = step * 60
    local op = rnd(6)
    local item = items[rnd(3) + 1]
    if op == 0 or #reg.ids == 0 then
      R.open(reg, next_id, 10 * (rnd(10) + 1), tick)
      next_id = next_id + 1
    elseif op == 1 then
      local id = reg.ids[rnd(#reg.ids) + 1]
      local before = R.free(reg, item)
      local g = R.request(reg, id, { { item, rnd(30) + 1 } }, tick)
      local gn = g[1] and g[1][2] or 0
      if gn > before then viol = viol + 1 end
    elseif op == 2 then
      local id = reg.ids[rnd(#reg.ids) + 1]
      local have = reg.projects[id].resa[item] or 0
      local t = R.take(reg, id, item, rnd(30) + 1)
      if t > have then viol = viol + 1 end
      stock[item] = reg.stock[item]
    elseif op == 3 then
      local id = reg.ids[rnd(#reg.ids) + 1]
      local mine = R.effective(reg, id, tick)
      local snapshot = {}
      for _, v in ipairs(reg.ids) do snapshot[v] = { e = R.effective(reg, v, tick), engaged = reg.projects[v].engaged } end
      local _, from = R.preempt(reg, id, item, rnd(30) + 1, tick)
      for _, f in ipairs(from) do
        local gap = mine - snapshot[f[1]].e
        if not (gap >= R.PREEMPT_URGENT or (gap >= R.PREEMPT_IDLE and not snapshot[f[1]].engaged)) then viol = viol + 1 end
      end
    elseif op == 4 then
      stock[item] = rnd(80)
      R.set_stock(reg, stock, tick)
    else
      R.release(reg, reg.ids[rnd(#reg.ids) + 1])
    end
    local ok = R.check(reg)
    if not ok then viol = viol + 1 end
    for _, it in ipairs(items) do if R.free(reg, it) < 0 then viol = viol + 1 end end
  end
  return viol, R.fingerprint(reg)
end
do
  local viol, fp1 = run_ops(20261025, 20000)
  check(viol == 0, "20 000 opérations : " .. viol .. " violation(s) des règles")
  local _, fp2 = run_ops(20261025, 20000)
  check(fp1 == fp2, "déterminisme du registre : même suite, même état")
  print(string.format("[AI3-GROUPE] registre : 20 000 opérations, %d violation(s)", viol))
end

-- 3. Place de marché.
local POLES = { "extraction", "base", "territoire" }
local KINDS = { "craft", "service", "build", "refill", "mine" }
do
  local rnd = lcg(777)
  local idle_with_work = 0
  for case = 1, 1000 do
    local npcs, tasks = {}, {}
    for i = 1, rnd(10) + 1 do
      local cannot = nil
      if rnd(5) == 0 then cannot = { [KINDS[rnd(#KINDS) + 1]] = true } end
      npcs[#npcs + 1] = { id = i, pole = POLES[rnd(3) + 1], role = rnd(6) == 0 and "generalist" or "executant",
        pos = { x = rnd(200), y = rnd(200) }, cannot = cannot }
    end
    for j = 1, rnd(12) do
      tasks[#tasks + 1] = { key = string.format("t%03d", j), kind = KINDS[rnd(#KINDS) + 1], prio = 20 + rnd(80),
        pole = POLES[rnd(3) + 1], pos = { x = rnd(200), y = rnd(200) }, critical = rnd(4) == 0, design = rnd(8) == 0 }
    end
    local out = M.assign(npcs, tasks)
    local busy, used = {}, {}
    for _, a in ipairs(out) do busy[a.npc] = true; used[a.task] = true end
    for _, n in ipairs(npcs) do
      if not busy[n.id] then
        for _, t in ipairs(tasks) do
          if not used[t.key] and not (n.cannot and n.cannot[t.kind]) then idle_with_work = idle_with_work + 1 break end
        end
      end
    end
  end
  check(idle_with_work == 0, "marché : " .. idle_with_work .. " PNJ libre(s) laissé(s) sans tâche alors qu'une tâche faisable restait")

  -- Le rôle oriente.
  local npcs = { { id = 1, pole = "base", role = "executant", pos = { x = 0, y = 0 } } }
  local tasks = { { key = "a", kind = "craft", prio = 50, pole = "extraction", pos = { x = 0, y = 0 } },
                  { key = "b", kind = "craft", prio = 50, pole = "base", pos = { x = 0, y = 0 } } }
  check(M.assign(npcs, tasks)[1].task == "b", "marché : à valeur égale, le PNJ prend la tâche de son pôle")
  -- Mais n'interdit pas.
  tasks = { { key = "a", kind = "craft", prio = 50, pole = "extraction", pos = { x = 0, y = 0 } } }
  check(M.assign(npcs, tasks)[1] ~= nil, "marché : seul du travail d'un autre pôle : le PNJ le prend")
  -- L'urgence passe avant le rôle.
  tasks = { { key = "a", kind = "refill", prio = 95, pole = "territoire", pos = { x = 0, y = 0 } },
            { key = "b", kind = "craft", prio = 50, pole = "base", pos = { x = 0, y = 0 } } }
  check(M.assign(npcs, tasks)[1].task == "a", "marché : l'urgence d'un autre pôle passe avant sa tâche ordinaire")
  -- Anti-ruée : 10 PNJ, 8 recharges urgentes et 8 fabrications.
  npcs, tasks = {}, {}
  for i = 1, 10 do npcs[i] = { id = i, pole = "base", role = "executant", pos = { x = 0, y = 0 } } end
  for j = 1, 8 do
    tasks[#tasks + 1] = { key = string.format("r%d", j), kind = "refill", prio = 90, pole = "territoire", pos = { x = 0, y = 0 } }
    tasks[#tasks + 1] = { key = string.format("c%d", j), kind = "craft", prio = 60, pole = "base", pos = { x = 0, y = 0 } }
  end
  local out = M.assign(npcs, tasks)
  local refills = 0
  for _, a in ipairs(out) do if a.task:sub(1, 1) == "r" then refills = refills + 1 end end
  check(refills >= 2 and refills <= 4, "anti-ruée : " .. refills .. " recharges urgentes sur 10 PNJ (2 à 4 attendues)")
  -- Sans autre travail, toutes les urgences sont prises.
  local only = {}
  for _, t in ipairs(tasks) do if t.kind == "refill" then only[#only + 1] = t end end
  check(#M.assign(npcs, only) == 8, "anti-ruée : sans autre travail, les 8 urgences sont prises")
  -- Déterminisme : ordre d'entrée inversé.
  local rev_n, rev_t = {}, {}
  for i = #npcs, 1, -1 do rev_n[#rev_n + 1] = npcs[i] end
  for j = #tasks, 1, -1 do rev_t[#rev_t + 1] = tasks[j] end
  local function ser(o)
    local p = {}
    for _, a in ipairs(o) do p[#p + 1] = a.npc .. ">" .. a.task end
    table.sort(p)
    return table.concat(p, ",")
  end
  check(ser(M.assign(rev_n, rev_t)) == ser(out), "marché : même attribution quel que soit l'ordre d'entrée")
end

-- 4. Simulation jouet : règle des pôles contre place de marché (mêmes arrivées).
local function simulate(rule, steps)
  local rnd = lcg(31415)
  local npcs = {}
  local layout = { "extraction", "extraction", "extraction", "base", "base", "base", "territoire", "territoire" }
  for i, p in ipairs(layout) do npcs[i] = { id = i, pole = p, role = "executant", pos = { x = 0, y = 0 }, left = 0 } end
  local queue, next_key = {}, 1
  local idle, idle_with_work, done, wait_sum = 0, 0, 0, 0
  for step = 1, steps do
    local arrivals = rnd(10) < 4 and 1 or 2
    for _ = 1, arrivals do
      local r = rnd(100)
      local pole = r < 70 and "base" or (r < 90 and "extraction" or "territoire")
      queue[#queue + 1] = { key = string.format("k%06d", next_key), kind = "craft", prio = rnd(20) == 0 and 95 or 50,
        pole = pole, pos = { x = 0, y = 0 }, born = step }
      next_key = next_key + 1
    end
    local free = {}
    for _, n in ipairs(npcs) do if n.left <= 0 then free[#free + 1] = n end end
    local out = rule(free, queue)
    local taken = {}
    for _, a in ipairs(out) do taken[a.task] = a.npc end
    local rest = {}
    for _, t in ipairs(queue) do
      if taken[t.key] then
        npcs[taken[t.key]].left = 4
        done = done + 1
        wait_sum = wait_sum + (step - t.born)
      else
        rest[#rest + 1] = t
      end
    end
    queue = rest
    for _, n in ipairs(npcs) do
      if n.left <= 0 then
        idle = idle + 1
        if #queue > 0 then idle_with_work = idle_with_work + 1 end
      end
      n.left = n.left - 1
    end
  end
  return { idle = idle / (steps * #npcs), idle_with_work = idle_with_work / (steps * #npcs), done = done,
    backlog = #queue, wait = done > 0 and wait_sum / done or 0 }
end
do
  local steps = 600
  local a = simulate(M.pole_rule, steps)
  local b = simulate(function(n, t) return (M.assign(n, t)) end, steps)
  print(string.format("[AI3-GROUPE] jouet, règle des pôles : inactifs %.0f %%, inactifs PENDANT que du travail attend %.0f %%, tâches faites %d, en retard %d, attente moyenne %.0f pas",
    100 * a.idle, 100 * a.idle_with_work, a.done, a.backlog, a.wait))
  print(string.format("[AI3-GROUPE] jouet, place de marché : inactifs %.0f %%, inactifs PENDANT que du travail attend %.0f %%, tâches faites %d, en retard %d, attente moyenne %.0f pas",
    100 * b.idle, 100 * b.idle_with_work, b.done, b.backlog, b.wait))
  check(b.idle_with_work == 0, "jouet : la place de marché ne laisse jamais un PNJ inactif quand du travail attend")
  check(a.idle_with_work > 0.2, "jouet : la règle des pôles laisse des PNJ inactifs avec du travail (> 20 %)")
  check(b.done > a.done, "jouet : la place de marché finit plus de tâches")
end

print(string.format("[AI3-GROUPE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
