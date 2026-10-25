--[[
  IA3 « le cerveau des PNJ » : PROTOTYPE PUR (conception, NON BRANCHÉ) de la PLACE DE MARCHÉ des tâches.
  docs/IA3_CERVEAU.md §2.3. N'importe quel PNJ libre prend la tâche la plus utile qu'il SAIT faire ; le rôle
  (pôle, généraliste) ORIENTE par un bonus, il n'interdit jamais.

    score(n, t) = valeur(t) × aptitude(n, t) × (1 + bonus_rôle) − trajet(n, t) + continuité(n, t)
      valeur      = priorité × 1,5 sur le chemin critique × 0,7^k (k-ième tâche URGENTE du même genre déjà prise)
      aptitude    = 0 s'il ne sait pas (n.cannot[genre]) ; sinon 1 + bonus de rang (n.skill[genre], en pour cent)
      bonus_rôle  = +20 % dans son pôle ; +20 % de plus pour un généraliste sur une tâche de conception
      trajet      = distance de Manhattan (tuiles) ÷ 10
      continuité  = +10 si la tâche est du même projet que la précédente du PNJ

  M.assign(npcs, tasks, ctx) -> { {npc = id, task = clé, score}, ... }, prix_fictif, notes calculées
    attribution GLOUTONNE déterministe : à chaque tour, le meilleur couple (score, puis clé de tâche, puis id du PNJ) ;
    le facteur anti-ruée est recalculé après chaque attribution d'une urgence. Lot IA3-0 (revue M1) : version
    PARESSEUSE (couples notés une fois, triés, re-notés seulement quand la ruée a changé) ; M.assign_naive garde la
    version de conception, référence des tests (mêmes attributions sur des tableaux tirés).
  M.pole_rule(npcs, tasks) : règle d'aujourd'hui simplifiée (son pôle ou une urgence ≥ 90), pour comparaison.
  Aucun pairs décisionnel, aucun hasard ; nombres seulement (sérialisable).
]]

local M = {}

M.ROLE_BONUS = 20      -- pour cent
M.DESIGN_BONUS = 20    -- pour cent
M.CRITICAL = 1.5
M.RUSH = 0.7
M.URGENT = 90
M.TRAVEL_DIV = 10
M.CONTINUITY = 10

local function dist(a, b)
  if not a or not b then return 0 end
  local dx, dy = a.x - b.x, a.y - b.y
  return (dx < 0 and -dx or dx) + (dy < 0 and -dy or dy)
end

--- Score d'un couple, ou nil si le PNJ ne sait pas faire la tâche. rush = nombre d'urgences de ce genre déjà prises.
function M.score(npc, task, rush)
  if npc.cannot and npc.cannot[task.kind] then return nil end
  local value = task.prio
  if task.critical then value = value * M.CRITICAL end
  if task.prio >= M.URGENT and rush and rush > 0 then value = value * M.RUSH ^ rush end
  local apt = 1 + ((npc.skill and npc.skill[task.kind]) or 0) / 100
  local bonus = 0
  if task.pole and task.pole == npc.pole then bonus = bonus + M.ROLE_BONUS end
  if task.design and npc.role == "generalist" then bonus = bonus + M.DESIGN_BONUS end
  local s = value * apt * (1 + bonus / 100) - dist(npc.pos, task.pos) / M.TRAVEL_DIV
  if task.project and npc.last_project == task.project then s = s + M.CONTINUITY end
  return s
end

--- Ordre des couples (comme la version naïve) : note décroissante à 1e-9 près, puis clé de tâche, puis identifiant du
--- PNJ. Vrai si (s, tâche j, PNJ i) passe avant (bs, bj, bi).
local function first(npcs, tasks, s, j, i, bs, bj, bi)
  if not bs then return true end
  if s > bs + 1e-9 then return true end
  if s < bs - 1e-9 then return false end
  local k, bk = tasks[j].key, tasks[bj].key
  if k ~= bk then return k < bk end
  return npcs[i].id < npcs[bi].id
end

--- Attribution gloutonne au MEILLEUR COUPLE DE CHAQUE PNJ (revue M1 : la version naïve note tous les couples à chaque
--- attribution, O(PNJ² × tâches), 8,25 ms à 30 × 64 ; un tri de tous les couples coûtait encore 6 ms).
--- Chaque PNJ libre garde sa meilleure tâche libre (note, clé). À chaque tour, le meilleur des meilleurs est attribué
--- (même ordre que la version naïve). Ensuite seuls deux cas changent un « meilleur » : sa tâche vient d'être prise,
--- ou c'est une urgence du genre dont la ruée vient d'augmenter (sa note baisse). Les autres PNJ gardent le leur :
--- les notes des autres tâches n'ont pas bougé ou ont BAISSÉ. Même résultat que la version naïve (contrôlé sur des
--- tableaux tirés par tests/ai3_groupe_test.lua). Renvoie aussi le nombre de notes calculées.
function M.assign(npcs, tasks, ctx)
  ctx = ctx or {}
  local rush = {}
  for _, k in ipairs(ctx.rush_kinds or {}) do rush[k[1]] = k[2] end
  local scored = 0
  local free_n, free_t = {}, {}
  for i = 1, #npcs do free_n[i] = true end
  for j = 1, #tasks do free_t[j] = true end
  local bs, bj = {}, {}
  -- Mémoire des notes : une note ne change que pour une urgence dont la ruée a changé (cache[i][j] = note ou false,
  -- stamp[i][j] = ruée au moment de la note).
  local cache, stamp = {}, {}
  local function best_of(i)
    local s0, j0
    local ci, si = cache[i], stamp[i]
    if not ci then ci, si = {}, {}; cache[i], stamp[i] = ci, si end
    for j = 1, #tasks do
      if free_t[j] then
        local t = tasks[j]
        local r = t.prio >= M.URGENT and (rush[t.kind] or 0) or 0
        local s = ci[j]
        if s == nil or si[j] ~= r then
          s = M.score(npcs[i], t, r) or false
          scored = scored + 1
          ci[j], si[j] = s, r
        end
        if s and first(npcs, tasks, s, j, i, s0, j0, i) then s0, j0 = s, j end
      end
    end
    bs[i], bj[i] = s0, j0
  end
  for i = 1, #npcs do best_of(i) end
  local out = {}
  while true do
    local wi
    for i = 1, #npcs do
      if free_n[i] and bj[i] and (not wi or first(npcs, tasks, bs[i], bj[i], i, bs[wi], bj[wi], wi)) then wi = i end
    end
    if not wi then break end
    local j = bj[wi]
    local t = tasks[j]
    free_n[wi], free_t[j] = false, false
    out[#out + 1] = { npc = npcs[wi].id, task = t.key, score = bs[wi] }
    local urgent = t.prio >= M.URGENT
    if urgent then rush[t.kind] = (rush[t.kind] or 0) + 1 end
    for i = 1, #npcs do
      local b = bj[i]
      if free_n[i] and b and (b == j or (urgent and tasks[b].prio >= M.URGENT and tasks[b].kind == t.kind)) then
        best_of(i)
      end
    end
  end
  local shadow = 0
  for j = 1, #tasks do
    if free_t[j] then
      local v = tasks[j].prio * (tasks[j].critical and M.CRITICAL or 1)
      if v > shadow then shadow = v end
    end
  end
  return out, shadow, scored
end

--- Version NAÏVE du prototype de conception (tous les couples à chaque attribution) : gardée comme RÉFÉRENCE des tests.
function M.assign_naive(npcs, tasks, ctx)
  ctx = ctx or {}
  local rush = {}
  for _, k in ipairs(ctx.rush_kinds or {}) do rush[k[1]] = k[2] end
  local free_n, free_t = {}, {}
  for i = 1, #npcs do free_n[i] = true end
  for j = 1, #tasks do free_t[j] = true end
  local out = {}
  while true do
    local bi, bj, bs
    for i = 1, #npcs do
      if free_n[i] then
        for j = 1, #tasks do
          if free_t[j] then
            local t = tasks[j]
            local s = M.score(npcs[i], t, t.prio >= M.URGENT and (rush[t.kind] or 0) or 0)
            if s then
              local better = not bs or s > bs + 1e-9
                or (s > bs - 1e-9 and (t.key < tasks[bj].key or (t.key == tasks[bj].key and npcs[i].id < npcs[bi].id)))
              if better then bi, bj, bs = i, j, s end
            end
          end
        end
      end
    end
    if not bi then break end
    free_n[bi], free_t[bj] = false, false
    out[#out + 1] = { npc = npcs[bi].id, task = tasks[bj].key, score = bs }
    if tasks[bj].prio >= M.URGENT then rush[tasks[bj].kind] = (rush[tasks[bj].kind] or 0) + 1 end
  end
  -- Prix fictif d'une PNJ-seconde : valeur de la meilleure tâche restée sans preneur (0 si tout est pris).
  local shadow = 0
  for j = 1, #tasks do
    if free_t[j] then
      local v = tasks[j].prio * (tasks[j].critical and M.CRITICAL or 1)
      if v > shadow then shadow = v end
    end
  end
  return out, shadow
end

--- Règle d'aujourd'hui, simplifiée (org.lua, rangs 2, 3, 5) : un PNJ prend la tâche la plus prioritaire de SON pôle,
--- ou une urgence (≥ 90) d'un autre pôle ; jamais une tâche ordinaire d'un autre pôle. Ordre des PNJ : identifiant.
function M.pole_rule(npcs, tasks)
  local taken, out = {}, {}
  local order = {}
  for i = 1, #npcs do order[i] = i end
  table.sort(order, function(a, b) return npcs[a].id < npcs[b].id end)
  for _, i in ipairs(order) do
    local npc, bj = npcs[i], nil
    for j = 1, #tasks do
      local t = tasks[j]
      if not taken[j] and not (npc.cannot and npc.cannot[t.kind]) and (t.pole == npc.pole or t.prio >= M.URGENT) then
        if not bj or t.prio > tasks[bj].prio or (t.prio == tasks[bj].prio and t.key < tasks[bj].key) then bj = j end
      end
    end
    if bj then
      taken[bj] = true
      out[#out + 1] = { npc = npc.id, task = tasks[bj].key }
    end
  end
  return out
end

return M
