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
Col.LOGS = 12       -- lignes [FO-COLLECTE] au plus par partie
local PLATE = T.outposts.iron.product

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
      local chest = o and surface.find_entity("iron-chest", { o.x, o.y })
      if chest and chest.valid then
        local n = chest.get_item_count(PLATE)
        local at = o.at or 200
        if n >= at then
          local oid = p.spec and p.spec.champ and p.spec.champ.oid
          local ob = oid and f.outposts and f.outposts[oid]
          local enemy = surface.count_entities_filtered({ position = { x = o.x, y = o.y }, radius = Co.DANGER_RADIUS, force = "enemy",
            type = { "unit-spawner", "turret" }, limit = 1 }) > 0
          out[#out + 1] = { key = t.key, d2 = (o.x - hq.x) ^ 2 + (o.y - hq.y) ^ 2, n = n, at = at, enemy = enemy,
            loss = loss_near(f, o.x, o.y, tick), lethal_tick = ob and ob.lethal_tick or nil }
          by_key[t.key] = out[#out]
        end
      end
    end
  end
  return out, by_key
end

--- Passe en urgence les collectes choisies parmi `tasks` (liste de la pensée, avant Board.add). Rend le nombre de tâches passées.
function Col.apply(f, surface, b, tasks, tick)
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

return Col
