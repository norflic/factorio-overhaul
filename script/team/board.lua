--[[
  Tableau des tâches d'une équipe : ce que le cerveau a décidé, qui s'en occupe.

  f.team.board = { tasks = { [clé] = tâche }, list = { tâche, ... } }   tâche.worker = id d'ouvrier si prise
  - sync : remplace les tâches LIBRES par le nouveau plan ; les tâches prises continuent. Lot IA1-a : le
    tableau est TRIÉ UNE FOIS par pensée (O.sort_tasks : priorité décroissante, puis clé) dans `list`.
  - claim : l'ouvrier prend la tâche libre la plus prioritaire (ordre déterministe : priorité, clé), en UN
    passage sur `list` (O.pick_task). Avant IA1-a, chaque prise triait toutes les clés : O(T log T) par
    ouvrier inoccupé et par pensée, soit 30 tris par pensée pour 30 PNJ.
  - finish : tâche terminée (réussie ou non) ; un échec la met en pause un moment (pas de boucle d'échecs).

  Lot IA3-b « personne n'attend, personne n'arrache » (docs/IA3_CERVEAU.md §2.2, §2.3 ; derrière le réglage
  fo-war-ia3-marche, FIGÉ par équipe à sa première lecture : f.team.marche) :
  - PLACE DE MARCHÉ : Board.claim note chaque tâche libre (M.order : priorité × (1 + 20 % dans son pôle, + 20 % de
    conception pour un généraliste) × besoin des tâches d'extraction − trajet/10 + continuité 10, anti-ruée 0,7^k sur
    les urgences d'un même genre) ; le cerveau d'abord, le fond ensuite ; le pôle oriente, il n'interdit plus. À la
    pensée, Board.assign attribue les meilleures paires (M.assign, glouton paresseux) aux PNJ inactifs : indices
    gardés jusqu'à la pensée suivante (b.hint, b.hinted).
  - REGISTRE (R, shared/ai3/registre.lua ; f.team.reg) : chaque tâche PRISE ouvre un projet (priorité de la tâche)
    qui réserve sa liste au LIBRE du coffre (coffre − réservé). Une tâche stricte dont la liste n'est pas libre n'est
    pas prise (le PNJ prend la suivante), sauf préemption réglée (R.preempt : écart ≥ 30, ou ≥ 10 si l'autre n'a rien
    pris ; jamais ce qu'un PNJ a en main), tout ou rien, journalisée « [FO-IA3B] ». Les prises larges (recharge,
    charbon des tournées, fonderie) sont bornées au libre par l'ouvrier (Board.reserve_soft, projet « Entretien »).
    La vue du cerveau voit coffre − réservé (Board.view_stock) : deux pensées ne promettent plus les mêmes plaques.
  - MANQUE DE PLAQUES (X, shared/ai3/manque.lua) : fours du QG et minage par plusieurs PNJ (Board.sync).
]]

local O = require("shared.team.org")
local T = require("shared.team.config")
local M = require("shared.ai3.marche")
local R = require("shared.ai3.registre")
local X = require("shared.ai3.manque")
local Registry = require("script.companion.registry")

local Board = {}

local RETRY_TICKS = 1800

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Liste triée des tâches du tableau (priorité décroissante, puis clé), une fois par pensée.
local function rebuild_list(b)
  local list = {}
  for _, key in ipairs(sorted_keys(b.tasks)) do
    local t = b.tasks[key]
    list[#list + 1] = t
    -- Lot IA3-b (place de marché) : tâche de conception ; garde du QG MENACÉ sans anti-ruée (toute l'équipe y va,
    -- règle d'IA1-b2).
    if O.DESIGN_KINDS[t.kind] then t.design = true end
    if t.kind == "garrison" and t.post == "hq" and (t.prio or 0) >= T.guard_threat_prio then t.no_rush = true end
  end
  b.list = O.sort_tasks(list)
end

---------------------------------------------------------------------------------------------------
-- Lot IA3-b : réglage, registre des réservations
---------------------------------------------------------------------------------------------------
--- La place de marché et le registre sont-ils allumés pour cette équipe ? Réglage lu UNE fois (première pensée ou
--- première prise) et figé dans f.team.marche ; réglage absent (moteur simulé) : M.DEFAULT_ON.
function Board.market(f)
  local t = f.team
  if not t then return false end
  if t.marche == nil then
    local ok, v = pcall(function() return settings.global[M.SETTING].value end)
    if ok and type(v) == "boolean" then t.marche = v else t.marche = M.DEFAULT_ON end
    log(string.format("[FO-IA3B] %s : place de marche et registre %s (fige pour l'equipe)", f.key or "player",
      t.marche and "ALLUMES" or "eteints"))
  end
  return t.marche
end

local function reg_of(f)
  local t = f.team
  t.reg = t.reg or R.new()
  t.reg_next = t.reg_next or 0
  return t.reg
end

local function stats_of(f)
  local org = f.team.org
  return org and org.stats or nil
end

local function bump(f, k, n)
  local st = stats_of(f)
  if st then st[k] = (st[k] or 0) + (n or 1) end
end

-- Liste prise STRICTEMENT par le programme de l'ouvrier (script/team/worker.lua, étape « take » avec strict = true).
local STRICT = { craft = "uses", build = "items", extend = "items", fortify = "items", smelters = "items" }
function Board.strict_list(t)
  local fld = STRICT[t.kind]
  return fld and t[fld] or nil
end

local function journal_cuts(f, reg, cuts, why)
  for _, c in ipairs(cuts) do
    local p = reg.projects[c[1]]
    log(string.format("[FO-IA3B] %s : %d %s reserve(s) pour '%s' %s", f.key or "player", c[3], c[2],
      p and p.key or "?", why))
    bump(f, "resa_lost", c[3])
  end
end

--- Vérité d'un objet au coffre (une fois par prise et par objet : `seen`).
local function sync_item(f, reg, item, tick, seen)
  if seen and seen[item] then return end
  if seen then seen[item] = true end
  local cuts = R.set_count(reg, item, f.hq.get_item_count(item), tick)
  if #cuts > 0 then journal_cuts(f, reg, cuts, "disparu(s) du coffre") end
end

local function new_project(f, reg, t, agent, tick)
  f.team.reg_next = (f.team.reg_next or 0) + 1
  local id = f.team.reg_next
  local p = R.open(reg, id, t.prio or 0, tick)
  p.key, p.agent = t.key, agent.id
  return id, p
end

--- Projet de l'ouvrier rendu au libre (tâche finie, échouée, abandonnée, PNJ disparu).
function Board.release(f, agent)
  local id = agent.resa_id
  if not id then return end
  agent.resa_id = nil
  local reg = f.team and f.team.reg
  if reg then R.release(reg, id) end
end

--- Réserve la liste STRICTE de la tâche `t` pour l'ouvrier (tout ou rien, préemption réglée). Vrai si réservée.
local function reserve_strict(f, reg, t, agent, tick, seen)
  local list = Board.strict_list(t)
  if not list or #list == 0 then return true end
  local id, p = new_project(f, reg, t, agent, tick)
  local short = false
  for _, it in ipairs(list) do
    sync_item(f, reg, it[1], tick, seen)
    if R.free(reg, it[1]) < it[2] then short = true end
  end
  if short then
    for _, it in ipairs(list) do
      local s = it[2] - R.free(reg, it[1])
      if s > 0 and R.preemptable(reg, id, it[1], tick) < s then
        R.release(reg, id)
        bump(f, "resa_refused")
        return false
      end
    end
    local b = Board.get(f)
    for _, it in ipairs(list) do
      local s = it[2] - R.free(reg, it[1])
      if s > 0 then
        local got, from = R.preempt(reg, id, it[1], s, tick)
        for _, v in ipairs(from) do
          local vp = reg.projects[v[1]]
          local vt = vp and vp.key and b.tasks[vp.key]
          if vt then vt.preempted = true end
          log(string.format("[FO-IA3B] %s : preemption, %d %s de '%s' (priorite %d) pour '%s' (priorite %d) a %.1f min",
            f.key or "player", v[2], it[1], vp and vp.key or "?", vp and vp.prio or 0, t.key, t.prio or 0, tick / 3600))
        end
        bump(f, "resa_preempt", got)
      end
    end
  end
  for _, it in ipairs(list) do
    local rest = it[2] - (p.resa[it[1]] or 0)
    if rest > 0 then R.request(reg, id, { { it[1], rest } }, tick) end
  end
  agent.resa_id = id
  return true
end

--- Prises LARGES (étape « take » non stricte : recharge, charbon d'une tournée, fonderie) bornées au libre et réservées
--- (projet « Entretien » de la tâche) ; la liste de l'étape est remplacée par ce qui est réservé. Après Worker.program.
function Board.reserve_soft(f, agent, task, steps, tick)
  if not Board.market(f) then return end
  local reg = reg_of(f)
  for _, st in ipairs(steps) do
    if st[1] == "take" and not st.strict then
      local id = agent.resa_id
      if not id then id = new_project(f, reg, task, agent, tick) end
      reg.projects[id].entretien = true
      local seen, out, at = {}, {}, {}
      for _, it in ipairs(st[2]) do
        sync_item(f, reg, it[1], tick, seen)
        local g = math.min(it[2], R.free(reg, it[1]))
        if g > 0 then
          R.request(reg, id, { { it[1], g } }, tick)
          if at[it[1]] then out[at[it[1]]][2] = out[at[it[1]]][2] + g
          else
            out[#out + 1] = { it[1], g }
            at[it[1]] = #out
          end
        end
      end
      st[2] = out
      agent.resa_id = id
    end
  end
end

--- Prise au coffre d'un ouvrier dont la tâche a une réservation : jamais plus que réservé (prise STRICTE), objets mis
--- dans `inv`. Rend vrai si toute la liste est prise. Le projet est ensuite rendu (ce qui manque retourne au libre).
function Board.take_reserved(f, agent, inv, list)
  local reg = f.team.reg
  local p = reg and reg.projects[agent.resa_id]
  local left = {}
  if p then for _, it in ipairs(list) do left[it[1]] = p.resa[it[1]] or 0 end end
  local all = true
  for _, it in ipairs(list) do
    local name, want = it[1], it[2]
    local n = math.min(want, left[name] or 0, f.hq.get_item_count(name))
    local put = 0
    if n > 0 then
      local got = f.hq.remove_item({ name = name, count = n })
      put = got > 0 and inv.insert({ name = name, count = got }) or 0
      if put < got then f.hq.insert({ name = name, count = got - put }) end
      left[name] = (left[name] or 0) - put
    end
    if put < want then all = false end
  end
  Board.release(f, agent)
  return all
end

--- Stock vu par le cerveau : coffre − réservé (réglage allumé) ; sinon le coffre tel quel. À la vue d'une pensée
--- (`full`), le registre est aussi remis à la vérité du coffre et les projets orphelins sont rendus.
function Board.view_stock(f, stock, tick, full)
  if not Board.market(f) then return stock end
  local reg = reg_of(f)
  if full then
    local ids = {}
    for i, id in ipairs(reg.ids) do ids[i] = id end
    for _, id in ipairs(ids) do
      local p = reg.projects[id]
      local a = p and Registry.get(p.agent)
      if not (a and a.resa_id == id) then R.release(reg, id) end
    end
    local cuts = R.set_stock(reg, stock, tick)
    if #cuts > 0 then journal_cuts(f, reg, cuts, "disparu(s) du coffre") end
  end
  local out = {}
  for k, v in pairs(stock) do out[k] = v end
  for _, id in ipairs(reg.ids) do
    local p = reg.projects[id]
    for _, k in ipairs(sorted_keys(p.resa)) do out[k] = (out[k] or 0) - p.resa[k] end
  end
  for _, k in ipairs(sorted_keys(out)) do if out[k] <= 0 then out[k] = nil end end
  return out
end

function Board.get(f)
  f.team.board = f.team.board or { tasks = {}, cooldown = {} }
  local b = f.team.board
  -- Sauvegarde d'avant IA1-a : la liste triée se reconstruit à la première lecture (jamais dans on_load).
  if not b.list then rebuild_list(b) end
  return b
end

--- Clés des tâches prises (pour que le cerveau ne les replanifie pas).
function Board.open(f)
  local b = Board.get(f)
  local open = {}
  for key, t in pairs(b.tasks) do if t.worker then open[key] = true end end
  return open
end

--- Lot IA3-b : plaques qui manquent au cerveau ({ [plaque] = n }) : « il manque » de l'objectif (plan.missing) et
--- production demandée à la fonderie (plan.smelt), le plus grand des deux.
local function plate_shortage(plan)
  local out = {}
  for _, m in ipairs(plan.missing or {}) do
    if type(m[1]) == "string" and type(m[2]) == "number" then out[m[1]] = math.max(out[m[1]] or 0, m[2]) end
  end
  for _, p in ipairs(X.PLATES) do
    local n = plan.smelt and plan.smelt[p[1]]
    if n and n > (out[p[1]] or 0) then out[p[1]] = n end
  end
  return out
end

--- plan, view, book (facultatifs, lot IA3-b) : avec le réglage allumé, tâches du MANQUE DE PLAQUES (X.tasks) ajoutées
--- au plan, et facteurs de besoin des tâches d'extraction (b.need_mult) pour la place de marché.
function Board.sync(f, planned, tick, plan, view, book)
  local b = Board.get(f)
  local keep = {}
  -- Lot IA1-b : une tâche libre replanifiée garde sa date de naissance (`created`) : l'attente d'une tâche se compte
  -- d'une pensée à l'autre (règle « tâche en souffrance » de Board.claim). Dates des tâches libres retirées gardées
  -- pour Board.add (le fond est rouvert après la pensée d'organisation).
  local born = {}
  for key, t in pairs(b.tasks) do
    if t.worker then keep[key] = t else born[key] = t.created end
  end
  for _, t in ipairs(planned) do
    local cd = b.cooldown[t.key]
    if not keep[t.key] and not (cd and tick < cd) then
      t.created = born[t.key] or tick
      keep[t.key] = t
    end
  end
  b.hint, b.hinted = nil, nil
  if plan and view and Board.market(f) then
    local missing = plate_shortage(plan)
    local keys, mines, taken = {}, {}, {}
    for _, key in ipairs(sorted_keys(keep)) do
      keys[key] = true
      local t = keep[key]
      if t.kind == "mine" and t.resource then
        mines[t.resource] = (mines[t.resource] or 0) + 1
        if t.worker then taken[t.resource] = (taken[t.resource] or 0) + 1 end
      end
    end
    for _, key in ipairs(sorted_keys(b.cooldown)) do if tick < b.cooldown[key] then keys[key] = true end end
    -- Lot IA-V2 : sous le cerveau par besoins, ses fours d'abord (no_smelters, shared/ai3/manque.lua).
    local added = X.tasks(view, missing, { keys = keys, mines = mines, mines_taken = taken, book = book,
      no_smelters = f.team.ia3c == true })
    for _, t in ipairs(added) do
      t.created = born[t.key] or tick
      keep[t.key] = t
    end
    if #added > 0 then bump(f, "manque_tasks", #added) end
    b.need_mult = X.need(view, missing)
  else
    b.need_mult = nil
  end
  b.tasks = keep
  b.born = born
  rebuild_list(b)
end

--- Lot IA1-b : ajoute des tâches au tableau après la synchronisation (travail de fond, crise injectée par un banc).
--- Une clé déjà présente (prise ou libre) ou en pause après un échec est ignorée. Liste retriée une fois.
function Board.add(f, tasks, tick)
  local b = Board.get(f)
  local born = b.born or {}
  local n = 0
  for _, t in ipairs(tasks) do
    local cd = b.cooldown[t.key]
    if not b.tasks[t.key] and not (cd and tick < cd) then
      t.created = born[t.key] or tick
      b.tasks[t.key] = t
      n = n + 1
    end
  end
  if n > 0 then rebuild_list(b) end
  return n
end

-- PNJ « neutre » du lot IA1-a : ni pôle, ni projet, ni zone (les pôles arrivent au lot IA1-b). Avec le rôle
-- généraliste et sans pôle, O.pick_task rend la PREMIÈRE tâche libre de la liste triée (urgence au rang 3,
-- le reste au rang 6, à rang égal l'ordre de la liste) : exactement la règle de l'ancien Board.claim (priorité
-- la plus haute, à égalité la plus petite clé). Contrôlé hors jeu sur des tableaux tirés au hasard
-- (tests/ia1_scale_test.lua). Aucun plafond hors pôle ni plafond manuel : rien n'est encore réparti par pôle.
local NEUTRAL = { role = "generalist" }

-- Lot IA1-b : un PNJ placé dans un pôle (agent.org, script/team/poles.lua) prend sa tâche par O.pick_task avec son
-- rôle, son pôle EFFECTIF (destination différée comprise), sa partie, et la limite des urgences hors pôle.
-- Règle « tâche en souffrance » (garde-fou des petites équipes, où un pôle peut n'avoir aucun exécutant) : une tâche
-- du CERVEAU (pas du fond) libre depuis STARVE_TICKS passe devant le travail de FOND de n'importe quel PNJ ; elle ne
-- passe jamais devant une tâche du cerveau de son pôle. Sans pôle (avant la première pensée d'organisation), règle
-- d'IA1-a (NEUTRAL).
Board.STARVE_TICKS = 1800

local function starving(list, gen, tick)
  for i = 1, #list do
    local t = list[i]
    if not t.worker and not t.fond and t.created and tick - t.created >= Board.STARVE_TICKS
      and (gen or not O.DESIGN_KINDS[t.kind]) then
      return i
    end
  end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Lot IA3-b : place de marché
---------------------------------------------------------------------------------------------------
local CANNOT_EXEC, CANNOT_EXEC_UNARMED = {}, { garrison = true }
for _, k in ipairs(sorted_keys(O.DESIGN_KINDS)) do
  CANNOT_EXEC[k] = true
  CANNOT_EXEC_UNARMED[k] = true
end
local CANNOT_UNARMED = { garrison = true }

--- PNJ vu par la place de marché : rôle (sans organisation : neutre, comme NEUTRAL), pôle EFFECTIF, position, projet
--- précédent (ou celui qu'il mène), ce qu'il ne sait pas faire (conception : exécutant ; garde : sans munitions).
local function market_npc(agent)
  local org = agent.org
  local role = org and (org.role or "executant") or "generalist"
  local e = agent.entity
  local armed = e.get_item_count(T.worker_ammo) + e.get_item_count("piercing-rounds-magazine") > 0
  local cannot
  if role ~= "generalist" then cannot = armed and CANNOT_EXEC or CANNOT_EXEC_UNARMED
  elseif not armed then cannot = CANNOT_UNARMED end
  local p = e.position
  return { id = agent.id, role = role, pole = org and O.effective_pole(org) or nil, pos = { x = p.x, y = p.y },
    last_project = (org and org.project) or agent.last_project, cannot = cannot }
end

--- Point de départ d'une tâche (trajet de la note) : la case du QG pour toute tâche qui commence au coffre ; le poste
--- pour une garde. Facteur de besoin d'une tâche d'extraction (minage, tournée ordinaire d'un avant-poste).
local function market_ctx(f, b)
  local home = f.home_spot or f.hq_pos
  local need = b.need_mult or {}
  local ctx = {}
  ctx.pos_of = function(t)
    if t.kind == "garrison" and t.post ~= "hq" then
      local o = f.outposts and f.outposts[t.post]
      if o then return o.access or o.pos end
    end
    return home
  end
  ctx.mult_of = function(t)
    if t.kind == "mine" then return need[t.resource] or 1 end
    -- Fonte du QG : le besoin de la plaque la plus en manque (une plaque qui manque : la fonte passe devant le minage).
    if t.kind == "smelt" then return math.max(need["iron-plate"] or 1, need["copper-plate"] or 1) end
    if t.kind == "service" and (t.prio or 0) < M.URGENT then
      local o = f.outposts and f.outposts[t.outpost]
      local spec = o and T.outposts[o.kind]
      return spec and need[spec.product] or 1
    end
    return 1
  end
  return ctx
end

local function rush_of(list)
  local rush = {}
  for k = 1, #list do
    local t = list[k]
    if t.worker and (t.prio or 0) >= M.URGENT and not t.no_rush then rush[t.kind] = (rush[t.kind] or 0) + 1 end
  end
  return rush
end

Board.MARKET_TRIES = 8 -- tâches strictes refusées (matière non libre) essayées au plus par prise
-- Lot IA-V2 : un indice de la pensée (Board.assign) ne réserve sa tâche qu'une seconde, et seulement pour un PNJ encore en
-- attente (sans tâche, état « idle »). Diagnostic du 27/10 (moteur réel, ia3c-default graine 20261020, Écarlate : 4 à
-- 5 PNJ sans tâche à CHAQUE pensée pendant 2 h avec une vingtaine de tâches libres prenables ; moteur simulé, 4 factions :
-- 52 prises vides sur 52 avaient toutes leurs tâches libres indiquées à d'AUTRES PNJ).
Board.HINT_TICKS = 60

local function claim_market(f, agent, tick, b)
  local list = b.list
  local reg = reg_of(f)
  local npc = market_npc(agent)
  local hinted = b.hinted or {}
  local mine = b.hint and b.hint[agent.id]
  local ctx = market_ctx(f, b)
  ctx.rush = rush_of(list)
  local fresh = b.hint_tick ~= nil and tick - b.hint_tick <= Board.HINT_TICKS
  ctx.skip = function(t)
    local h = hinted[t.key]
    if h == nil or h == agent.id or not fresh then return false end
    local ha = Registry.get(h)
    return ha ~= nil and ha.task == nil and ha.state == "idle"
  end
  local idx = M.order(npc, list, ctx)
  -- L'indice de la pensée (meilleure paire de M.assign) d'abord, s'il est encore là.
  if mine then
    for i, j in ipairs(idx) do
      if list[j].key == mine then
        table.remove(idx, i)
        table.insert(idx, 1, j)
        break
      end
    end
  end
  local seen, tries = {}, 0
  for _, j in ipairs(idx) do
    local t = list[j]
    -- Lot IA-V2 : tri préalable sans lecture du coffre : une tâche dont la matière stricte n'est pas libre au registre
    -- n'use pas un des Board.MARKET_TRIES essais (sauf une urgence, qui peut préempter). Moteur simulé, 4 factions :
    -- 125 prises vides sur 130 avec des tâches libres : les 8 essais partaient sur des fabrications sans matière, le PNJ
    -- n'arrivait jamais au minage, à la tournée ou à la fonte plus bas dans l'ordre (K5, « personne au coffre pendant
    -- que du travail attend »).
    local quick = true
    if (t.prio or 0) < M.URGENT then
      for _, it in ipairs(Board.strict_list(t) or {}) do
        if R.free(reg, it[1]) < it[2] then quick = false break end
      end
    end
    if quick and b.tasks[t.key] == t then
      if reserve_strict(f, reg, t, agent, tick, seen) then
        bump(f, "market_claims")
        if t.pole and npc.pole and t.pole ~= npc.pole then bump(f, "market_away") end
        if t.fond then bump(f, "market_fond") end
        return t
      end
      tries = tries + 1
      if tries >= Board.MARKET_TRIES then break end
    end
  end
  return nil
end

--- Lot IA3-b : à la pensée d'équipe (après l'organisation et le fond), meilleures paires PNJ inactif × tâche libre
--- (M.assign, glouton paresseux ; cerveau d'abord, puis fond pour les PNJ restants). Seulement si au moins 2 PNJ sont
--- inactifs ; au-delà de Board.ASSIGN_MAX couples, chaque PNJ prend seulement sa meilleure note à sa prise.
Board.ASSIGN_MAX = 1200
function Board.assign(f, tick)
  local b = Board.get(f)
  b.hint, b.hinted = nil, nil
  if not Board.market(f) then return 0 end
  local npcs = {}
  for _, id in ipairs(sorted_keys(f.engineers or {})) do
    local a = Registry.get(id)
    -- Lot IA-V2 : seulement les PNJ qui vont PRENDRE une tâche (état « idle ») : un PNJ sans tâche qui rentre au QG
    -- ou attend ne reçoit pas d'indice (il bloquerait la tâche pour les autres).
    if a and not a.task and a.state == "idle" and a.entity and a.entity.valid then npcs[#npcs + 1] = market_npc(a) end
  end
  local reg = reg_of(f)
  -- Lot IA-V2 : diagnostic de K5 (PNJ sans tâche pendant que des tâches libres attendent), à chaque pensée : tâches
  -- libres et, parmi elles, celles dont la matière stricte n'est pas libre au registre (non prenables). Écrit chaque
  -- minute par script/ai3/cerveau.lua (Ia3.measure), puis remis à zéro.
  if #npcs > 0 then
    local free, blocked = 0, 0
    for _, t in ipairs(b.list) do
      if not t.worker then
        free = free + 1
        for _, it in ipairs(Board.strict_list(t) or {}) do
          if R.free(reg, it[1]) < it[2] then blocked = blocked + 1 break end
        end
      end
    end
    if free > 0 then
      local d = b.diag or { n = 0, idle = 0, free = 0, blocked = 0 }
      d.n, d.idle, d.free, d.blocked = d.n + 1, d.idle + #npcs, d.free + free, d.blocked + blocked
      b.diag = d
    end
  end
  if #npcs < 2 then return 0 end
  local brain, fond = {}, {}
  for _, t in ipairs(b.list) do
    if not t.worker then
      local ok = true
      for _, it in ipairs(Board.strict_list(t) or {}) do
        if R.free(reg, it[1]) < it[2] then ok = false break end
      end
      if ok then
        if t.fond then fond[#fond + 1] = t else brain[#brain + 1] = t end
      end
    end
  end
  if #npcs * (#brain + #fond) > Board.ASSIGN_MAX or #brain + #fond == 0 then return 0 end
  local ctx = market_ctx(f, b)
  local rush = rush_of(b.list)
  ctx.rush_kinds = {}
  for _, k in ipairs(sorted_keys(rush)) do ctx.rush_kinds[#ctx.rush_kinds + 1] = { k, rush[k] } end
  local hint, hinted = {}, {}
  local n = 0
  local pairs1 = #brain > 0 and M.assign(npcs, brain, ctx) or {}
  for _, a in ipairs(pairs1) do
    hint[a.npc], hinted[a.task] = a.task, a.npc
    n = n + 1
  end
  if #fond > 0 then
    local rest = {}
    for _, p in ipairs(npcs) do if not hint[p.id] then rest[#rest + 1] = p end end
    if #rest > 0 then
      for _, a in ipairs(M.assign(rest, fond, ctx)) do
        hint[a.npc], hinted[a.task] = a.task, a.npc
        n = n + 1
      end
    end
  end
  b.hint, b.hinted = hint, hinted
  b.hint_tick = tick
  return n
end

function Board.claim(f, agent, tick)
  local b = Board.get(f)
  if Board.market(f) then
    local best = claim_market(f, agent, tick, b)
    if best then
      best.worker = agent.id
      best.claimed = tick
      best.away = nil
      -- Son indice (pris ou non) et celui de la tâche prise sont rendus : la tâche indiquée redevient libre pour tous.
      local h = b.hint and b.hint[agent.id]
      if h then
        b.hint[agent.id] = nil
        if b.hinted and b.hinted[h] == agent.id then b.hinted[h] = nil end
      end
      if b.hinted then b.hinted[best.key] = nil end
    end
    return best
  end
  local list = b.list
  local org = agent.org
  local i, away
  if org and org.pole then
    local npc = { id = agent.id, role = org.role or "executant", pole = org.pole, dest = org.dest, project = org.project,
      zone = org.zone }
    local n_away = 0
    for k = 1, #list do
      local t = list[k]
      if t.worker and t.away then n_away = n_away + 1 end
    end
    local n_exec = (f.team.org and f.team.org.n_exec) or 0
    i, away = O.pick_task(npc, list, { urgent_away = n_away, urgent_away_cap = O.urgent_away_cap(n_exec) })
    if i == nil or list[i].fond then
      local s = starving(list, npc.role == "generalist", tick)
      if s then
        i, away = s, false
        if f.team.org then f.team.org.stats.starve_taken = f.team.org.stats.starve_taken + 1 end
      end
    end
    -- Rang 7 (écart déclaré à la table du §4.5) : un exécutant dont le pôle n'a plus rien à lui donner prend le
    -- travail de FOND d'un autre pôle (le plus prioritaire), plutôt que rester inactif. Le travail du cerveau reste
    -- réparti par pôle ; seul le fond est partagé.
    if i == nil then
      for k = 1, #list do
        local t = list[k]
        if not t.worker and t.fond then
          i, away = k, true
          if f.team.org then f.team.org.stats.fond_cross = (f.team.org.stats.fond_cross or 0) + 1 end
          break
        end
      end
    end
    -- Lot IA1-b2 (complément du DC, 25/10 : « sur les 8 PNJ y en avait pas mal qui faisaient rien ») : rang 8, un PNJ
    -- qui n'a RIEN à prendre (ni son pôle, ni le fond) prend la tâche du cerveau qui attend le plus haut dans la liste,
    -- quel que soit son pôle (essai 6 : 44 à 74 % des attentes avec des tâches libres d'un autre pôle). Votre équipe
    -- seulement (l'économie des factions règle l'ordre des difficultés de pvp_test).
    if i == nil and f.is_player then
      for k = 1, #list do
        local t = list[k]
        if not t.worker and (npc.role == "generalist" or not O.DESIGN_KINDS[t.kind]) then
          i, away = k, true
          if f.team.org then f.team.org.stats.brain_cross = (f.team.org.stats.brain_cross or 0) + 1 end
          break
        end
      end
    end
  else
    -- Une tâche de la liste retirée du tableau depuis la pensée (finie) a un ouvrier : pick_task l'ignore.
    i = O.pick_task(NEUTRAL, list)
  end
  local best = i and list[i]
  if best and b.tasks[best.key] ~= best then best = nil end
  if best then
    best.worker = agent.id
    best.claimed = tick
    best.away = (away and (best.prio or 0) >= O.URGENT_PRIO) or nil
  end
  return best
end

-- Lot IA-V2 : crochet facultatif (posé par script/ai3/exploration.lua) appelé à l'échec d'une tâche : mémoire des
-- gisements lointains injoignables (chemin raté).
Board.on_fail = nil

function Board.finish(f, task, ok, tick)
  if not ok and Board.on_fail then Board.on_fail(f, task, tick) end
  local b = Board.get(f)
  if b.tasks[task.key] == task then b.tasks[task.key] = nil end
  local st = f.team.task_stats
  st[task.kind] = st[task.kind] or { ok = 0, fail = 0 }
  if ok then
    st[task.kind].ok = st[task.kind].ok + 1
  else
    st[task.kind].fail = st[task.kind].fail + 1
    -- Lot IA3-b : une tâche PRÉEMPTÉE (sa matière est partie à une urgence, règle du registre) n'est pas en faute : elle
    -- peut être replanifiée dès la pensée suivante.
    if task.fail ~= "preempte" then
      b.cooldown[task.key] = tick + (task.fond and RETRY_TICKS * 2 or RETRY_TICKS)
    end
    if task.fail then
      f.team.fail_reasons[task.fail] = (f.team.fail_reasons[task.fail] or 0) + 1
    end
  end
end

--- Objets attendus des fabrications en cours (le cerveau ne les recommande pas).
function Board.incoming(f)
  local b = Board.get(f)
  local inc = {}
  for _, key in ipairs(sorted_keys(b.tasks)) do
    local t = b.tasks[key]
    if t.worker and t.kind == "craft" then inc[t.item] = (inc[t.item] or 0) + t.count end
  end
  return inc
end

function Board.count(f)
  local b = Board.get(f)
  local open, taken = 0, 0
  for _, t in pairs(b.tasks) do
    if t.worker then taken = taken + 1 else open = open + 1 end
  end
  return open, taken
end

--- Tâches de construction en cours, par type d'avant-poste (le cerveau les compte comme « en chantier »).
function Board.pending(f)
  local b = Board.get(f)
  local pend, smelters = {}, 0
  local fortify = {}
  for _, t in pairs(b.tasks) do
    if t.worker then
      if t.kind == "build" or t.kind == "extend" then pend[t.outpost_kind] = (pend[t.outpost_kind] or 0) + 1 end
      if t.kind == "smelters" then smelters = smelters + t.count end
      if t.kind == "fortify" then fortify[t.outpost] = true end
    end
  end
  return pend, smelters, fortify
end

function Board.has(f, key)
  local t = Board.get(f).tasks[key]
  return t ~= nil and t.worker ~= nil
end

--- Lot IA1-d (option « seul » d'un banc du plan directeur) : retire les tâches LIBRES que `keep(t)` refuse ; les
--- tâches prises continuent. Liste retriée une fois.
function Board.drop_free(f, keep)
  local b = Board.get(f)
  local n = 0
  for _, key in ipairs(sorted_keys(b.tasks)) do
    local t = b.tasks[key]
    if not t.worker and not keep(t) then b.tasks[key] = nil; n = n + 1 end
  end
  if n > 0 then rebuild_list(b) end
  return n
end

return Board
