--[[
  Lot COLLECTE (7/11) : les coffres de SORTIE du champ (tâches « carry/collect » de script/team/build.lua, quai_tasks) passent en urgence
  quand le fer libre du QG est sous le besoin et que votre équipe est sous son effectif. Règle pure : shared/team/collecte.lua.
  Appelé par Build.think juste avant Board.add ; ne modifie QUE les tâches de la liste de la pensée (priorité, critique, sans ruée) ;
  état : f.team.collecte = { t = tick du dernier choix, picked = { [clé de tâche] = vrai }, key = texte du dernier choix }.
  Ne requiert ni script/team/poles.lua ni script/team/intermediaires.lua (cycle avec build.lua) : la sûreté relit les mêmes données
  (nid ou ver proche, pertes récentes f.team.org.loss_pos, avant-poste meurtrier o.lethal_tick).
]]
local T = require("shared.team.config")
local Co = require("shared.team.collecte")
local Stock = require("script.team.stock")

local Col = {}

Col.EVERY = 300     -- ticks entre deux choix (le choix tient entre-temps)
Col.LOGS = 12       -- lignes [FO-COLLECTE] au plus par partie, pour les choix, et 12 de plus pour les refus (une par coffre et par cause)
local PLATE = T.outposts.iron.product
local CHEST = T.outposts.coal.sink -- coffre des avant-postes bruts (shared/team/config.lua) : le coffre de sortie des projets du plan directeur

local function loss_near(f, x, y, tick)
  local org = f.team and f.team.org
  if not (org and org.loss_pos) then return false end
  local r2 = Co.LOSS_RADIUS * Co.LOSS_RADIUS
  for _, p in ipairs(org.loss_pos) do
    if tick - p.tick < Co.LOSS_TICKS then
      local dx, dy = p.x - x, p.y - y
      if dx * dx + dy * dy <= r2 then return true end
    end
  end
  return false
end

local function missing_of(f)
  local n = 0
  for _, m in ipairs(f.team.missing or {}) do
    if m[1] == PLATE then n = n + (m[2] or 0) end
  end
  return n
end

local function is_collect(t)
  return t.kind == "carry" and t.ia1d ~= nil and t.ia1d.mode == "collect"
end

--- Manque en plaques de fer de votre équipe à cet instant (0 : la règle dort).
function Col.shortfall(f)
  return Co.shortfall({ free = Stock.count(f, PLATE), reserve = T.grow_iron_reserve, missing = missing_of(f),
    n = f.engineers_count or 0, floor = (f.team and f.team.floor) or 0 })
end

--- Candidats : un par tâche de collecte de la pensée dont le coffre tient au moins le seuil en plaques de fer.
local function candidates(f, surface, b, tasks, tick)
  local out, by_key = {}, {}
  local hq = f.hq.position
  for _, t in ipairs(tasks) do
    if is_collect(t) then
      local p = b.projects[t.ia1d.pid]
      local o = p and p.outs and p.outs[t.ia1d.idx]
      local chest = o and surface.find_entity(CHEST, { o.x, o.y })
      if chest and chest.valid then
        local n = chest.get_item_count(PLATE)
        local at = o.at or 200
        if n >= at then
          local oid = p.spec and p.spec.champ and p.spec.champ.oid
          local ob = oid and f.outposts and f.outposts[oid]
          -- Un ennemi QUELCONQUE (nid, ver, meute) à moins de Co.DANGER_RADIUS tuiles du coffre : le danger lu est celui du coffre, jamais
          -- l'état « danger » du projet ailleurs (rebuild_sweep : 5 cases de danger sur le projet 12 de 146 à 176 min).
          local foe = surface.find_nearest_enemy({ position = { x = o.x, y = o.y }, max_distance = Co.DANGER_RADIUS, force = f.force })
          local enemy = foe ~= nil and foe.valid
          out[#out + 1] = { key = t.key, d2 = (o.x - hq.x) ^ 2 + (o.y - hq.y) ^ 2, n = n, at = at, enemy = enemy,
            loss = loss_near(f, o.x, o.y, tick), lethal_tick = ob and ob.lethal_tick or nil }
          by_key[t.key] = out[#out]
        end
      end
    end
  end
  return out, by_key
end

--- Lot VIDEO-L3 : la collecte suit le MANQUE MESURÉ (shared/ai3/manque_local.lua, résultat gardé par script/team/manque_vue.lua dans
--- f.team.mq.res) : chaque action de collecte relève SA tâche à la priorité héritée des manques qu'elle couvre (jamais ne l'abaisse) ; au
--- niveau de la survie (Co.PRIO et plus), critique et pour Co.MAX_TASKS tâches au plus (les suivantes juste dessous). Un seul décideur :
--- avec un résultat frais, l'ancien choix (Col.shortfall, Co.pick) n'est pas joué. Les deux équipes (l'ancien choix : votre équipe seule).
Col.MQ = true            -- faux : la règle d'avant (banc témoin)
Col.MQ_AGE = 2 * 3600    -- ticks : un résultat plus vieux n'est pas suivi (la vue le refait toutes les minutes)

local function apply_mq(f, tasks, res, tick)
  local by_key = {}
  for _, t in ipairs(tasks) do if is_collect(t) then by_key[t.key] = t end end
  local n, crit, seen, parts = 0, 0, {}, {}
  for _, a in ipairs(res.collect or {}) do -- triées par Mq.step : priorité décroissante, puis distance
    local t = a.task and by_key[a.task]
    if t and not seen[a.task] then
      seen[a.task] = true
      local p = a.prio or 0
      if p > (t.prio or 0) then
        if p >= Co.PRIO then
          if crit < Co.MAX_TASKS then
            crit = crit + 1
            t.critical, t.urgent_collect = Co.CRITICAL or nil, true
          else
            p = Co.PRIO - 1
          end
        end
        t.prio, t.no_rush = p, true
        n = n + 1
        parts[#parts + 1] = string.format("%s %s x%d prio %d%s", a.task, tostring(a.item), math.floor((a.n or 0) + 0.5), p, a.expired and " (echue)" or "")
      end
    end
  end
  local st = f.team.collecte
  if not st then
    st = { t = -Col.EVERY, picked = {} }
    f.team.collecte = st
  end
  local desc = #parts > 0 and table.concat(parts, " | ") or nil
  if (desc or "") ~= (st.mq_key or "") then
    st.mq_key = desc
    f.stats = f.stats or {}
    f.stats.collecte_logs = (f.stats.collecte_logs or 0) + 1
    if desc and f.stats.collecte_logs <= Col.LOGS then
      log(string.format("[FO-COLLECTE] %s a %.1f min : manque mesure (L3) : %s", f.key or "player", tick / 3600, desc))
    end
  end
  return n
end

--- Lot COLLECTE-CHAMP : un coffre de sortie du champ SOUS son seuil de collecte reçoit sa tâche quand il tient de quoi combler un manque mesuré
--- (Co.low_due sur f.team.mq.res.net, résultat frais). Appelé par out_tasks (build.lua) ; au plus Co.LOW_MAX coffres par pensée. Lecture seule
--- des coffres ; la sûreté du trajet est celle de toute tâche de collecte (porte du danger à la prise). Journal [FO-COLLECTE].
Col.LOW_ON = true        -- faux : la règle d'avant (banc témoin)
Col.LOW_LOGS = 12
function Col.low_due(f, p, chest, tick)
  if not Col.LOW_ON or not (p.spec and p.spec.champ) then return false end
  local mq = f.team and f.team.mq
  local res = mq and mq.res
  if not (res and res.net and mq.tick and tick - mq.tick <= Col.MQ_AGE) then return false end
  local st = f.team.collecte
  if not st then
    st = { t = -Col.EVERY, picked = {} }
    f.team.collecte = st
  end
  if st.low_tick ~= tick then st.low_tick, st.low_n = tick, 0 end
  if (st.low_n or 0) >= Co.LOW_MAX then return false end
  local contents = chest.get_inventory(defines.inventory.chest).get_contents()
  if not Co.low_due(contents, res.net) then return false end
  st.low_n = st.low_n + 1
  f.stats = f.stats or {}
  f.stats.collecte_basse = (f.stats.collecte_basse or 0) + 1
  if f.stats.collecte_basse <= Col.LOW_LOGS then
    log(string.format("[FO-COLLECTE] %s a %.1f min : coffre du champ (projet %d) SOUS son seuil mais %d objets d'un manque mesure : collecte emise",
      f.key or "player", tick / 3600, p.id or -1, Co.useful(contents, res.net)))
  end
  return true
end

--- Passe en urgence les collectes choisies parmi `tasks` (liste de la pensée, avant Board.add). Rend le nombre de tâches passées.
function Col.apply(f, surface, b, tasks, tick)
  local mq = Col.MQ and f.team and f.team.mq
  if mq and mq.res and mq.tick and tick - mq.tick <= Col.MQ_AGE then return apply_mq(f, tasks, mq.res, tick) end
  if not (f.is_player and f.team and f.hq and f.hq.valid and surface) then return 0 end
  local st = f.team.collecte
  if not st then
    st = { t = -Col.EVERY, picked = {} }
    f.team.collecte = st
  end
  if tick - st.t >= Col.EVERY then
    st.t = tick
    local short = Col.shortfall(f)
    local picked, desc = {}, nil
    if short > 0 then
      local cands, by_key = candidates(f, surface, b, tasks, tick)
      local keys = Co.pick(cands, short, tick)
      st.refused = st.refused or {}
      for _, c in ipairs(cands) do
        local why = Co.refusal(c, tick)
        if why and not st.refused[c.key .. ":" .. why] then
          st.refused[c.key .. ":" .. why] = true
          f.stats.collecte_refus = (f.stats.collecte_refus or 0) + 1
          if f.stats.collecte_refus <= Col.LOGS then
            log(string.format("[FO-COLLECTE] %s a %.1f min : %s REFUSEE (%s) : %d plaques, a %d tuiles du QG, ennemi a moins de %d tuiles du coffre : %s",
              f.key or "player", tick / 3600, c.key, why, c.n, math.floor(math.sqrt(c.d2)), Co.DANGER_RADIUS, c.enemy and "oui" or "non"))
          end
        end
      end
      local parts = {}
      for _, k in ipairs(keys) do
        picked[k] = true
        parts[#parts + 1] = string.format("%s d=%d plaques=%d", k, math.floor(math.sqrt(by_key[k].d2)), by_key[k].n)
      end
      if #keys > 0 then
        desc = string.format("fer libre %d, besoin %d, equipe %d sur %d : collecte en urgence de %s",
          Stock.count(f, PLATE), (T.grow_iron_reserve or 0) + missing_of(f), f.engineers_count or 0, f.team.floor or 0, table.concat(parts, " | "))
      end
    end
    st.picked = picked
    if (desc or "") ~= (st.key or "") then
      st.key = desc
      f.stats.collecte_logs = (f.stats.collecte_logs or 0) + 1
      if desc and f.stats.collecte_logs <= Col.LOGS then
        log(string.format("[FO-COLLECTE] %s a %.1f min : %s", f.key or "player", tick / 3600, desc))
      end
    end
  end
  local n = 0
  for _, t in ipairs(tasks) do
    if st.picked[t.key] and is_collect(t) then
      t.prio, t.critical, t.no_rush, t.urgent_collect = Co.PRIO, Co.CRITICAL or nil, true, true
      n = n + 1
    end
  end
  return n
end

--- PROPOSITION, NON BRANCHÉE en jeu (Col.waiting n'a pour appelant que tests/collecte_glue_test.lua ; la vue lit les sorties par
--- Col.waiting_all, manque_vue.lua:163) : plaques de fer qui attendent dans les coffres de sortie des projets de `b`, { total, chests }. À lire par Team.view
--- (champ séparé `view.champ_out`, pour le journal et le manque), PAS à ajouter au stock « attendu » du planificateur : le lot FLUX l'a mesuré
--- (compter des plaques dormantes comme disponibles sans tournée qui les ramène a fait tomber Écarlate de 30 686 à 14 074 plaques).
function Col.waiting(f, surface, b)
  local total, chests = 0, 0
  for _, pid in ipairs(b.order or {}) do
    local p = b.projects[pid]
    for _, o in ipairs((p and p.outs) or {}) do
      local c = surface.find_entity(CHEST, { o.x, o.y })
      if c and c.valid and c.force.name == f.force then
        local n = c.get_item_count(PLATE)
        if n > 0 then total, chests = total + n, chests + 1 end
      end
    end
  end
  return total, chests
end

--- Lot VIDEO-L3 : les SORTIES du plan directeur pour le manque mesuré (Mq.step, input.sources), TOUS objets. Une par coffre p.outs[i] des
--- projets de b.order, quel que soit leur état (Co.collects_outs) :
---   { id = "<projet>:<i>", items = contenu, read_tick, d (distance au QG, au carré), ok, collect, task }.
--- `ok` : la tâche de collecte « ia1d:<projet>:o:<i> » est au tableau (le seuil o.at et la borne keep_stock de out_tasks, build.lua, sont
--- donc passés) ET le coffre est sûr (Co.refusal : ennemi, perte, avant-poste meurtrier, comme `candidates`) ; sans tâche, la sortie dort
--- (vue, ni disponible ni retenue). `collect` : « taken » si un PNJ a pris la tâche, « open » si elle attend. Lecture seule ; la sûreté
--- (find_nearest_enemy) n'est lue que pour un coffre qui a sa tâche.
function Col.waiting_all(f, surface, b, tick)
  local out = {}
  if not (b and b.order and b.projects and surface) then return out end
  local hq = f.hq and f.hq.valid and f.hq.position or nil
  local tasks = (f.team and f.team.board and f.team.board.tasks) or {}
  local seen = {} -- lot MESURE-MODULE : un coffre n'est lu qu'UNE fois, quel que soit le nombre d'entrées de p.outs qui le désignent
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and Co.collects_outs(p.state, p.outs and #p.outs or 0) then
      for i, o in ipairs(p.outs) do
        local c = surface.find_entity(CHEST, { o.x, o.y })
        if c and c.valid and c.force.name == f.force then
          local ck = c.unit_number or (tostring(o.x) .. "," .. tostring(o.y))
          local prev = seen[ck]
          local inv = (not prev) and c.get_inventory(defines.inventory.chest) or nil -- (la copie n'est pas relue)
          local key = "ia1d:" .. pid .. ":o:" .. i
          local t = tasks[key]
          local ok = false
          if t then
            local foe = surface.find_nearest_enemy({ position = { x = o.x, y = o.y }, max_distance = Co.DANGER_RADIUS, force = f.force })
            local oid = p.spec and p.spec.champ and p.spec.champ.oid
            local ob = oid and f.outposts and f.outposts[oid]
            ok = Co.refusal({ enemy = foe ~= nil and foe.valid, loss = loss_near(f, o.x, o.y, tick),
              lethal_tick = ob and ob.lethal_tick or nil }, tick) == nil
          end
          local entry = { id = pid .. ":" .. i, items = inv and inv.get_contents() or {}, read_tick = tick,
            d = hq and ((o.x - hq.x) ^ 2 + (o.y - hq.y) ^ 2) or nil, ok = ok,
            collect = t and (t.worker and "taken" or "open") or nil, task = t and key or nil }
          if prev then
            -- copie du même coffre : pas de seconde lecture ; la tâche de collecte prise l'emporte sur celle qui attend
            if entry.collect and (prev.collect == nil or (entry.collect == "taken" and prev.collect ~= "taken")) then
              prev.collect, prev.task, prev.ok = entry.collect, entry.task, entry.ok
            end
          else
            out[#out + 1] = entry
            seen[ck] = entry
          end
        end
      end
    end
  end
  return out
end

return Col
