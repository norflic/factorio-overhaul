--[[
  Lot COUVERTURE, volet RECONSTRUCTION : une pièce de l'équipe détruite est REFAITE, avant que l'équipe n'améliore quoi que
  ce soit (constat du DC, 28/10 : « un endroit détruit n'a pas été remplacé alors que ça prend deux secondes et qu'ils ont
  toutes les ressources », « le labo de recherche attaqué n'est pas réparé »). Règles pures : shared/team/reconstruction.lua.

  Pourquoi un registre et pas les fantômes du moteur : le fantôme laissé par une pièce détruite dépend du temps de vie des
  fantômes de la force (LuaForce.ghost_time_to_live, 0 par défaut = jamais effacé, mais le moteur n'en laisse que si le
  prototype le prévoit et ne les rend pas aux PNJ), et le ravivage par un PNJ est celui du plan directeur (script/team/build.lua),
  dont les projets finis ne reprennent plus leurs pièces. Le registre garde l'essentiel d'une pièce (nom, place, direction,
  recette, objet qui la pose), lu au moment de sa mort : refaire ne dépend de rien d'autre.

  Quelles pièces : celles que l'ÉQUIPE a posées, et seulement elles :
    - les pièces d'un projet du plan directeur (f.build.projects[].ents : laboratoire, assembleur, four, tapis, poteau…),
      reconnues à leur place ;
    - les foreuses et réceptacles d'un avant-poste encore vivant (registre des propriétaires, State.owner : « drill », « sink »).
  Les tourelles se refont par « défendre d'abord » (Outposts.fortify, positions par couverture) ; ce que le joueur a posé à la
  main n'est jamais refait par ses PNJ.

  Un lot par voyage : la pièce la plus précieuse et ses voisines à Rc.BATCH_RADIUS tuiles (tâche « rebuild », priorité de 70 à 86,
  sous l'urgence). Le PNJ prend les objets au stock (liste stricte du tableau), va sur place, pose. Pas de pose tant que des
  ennemis sont près de la place (la pièce est différée, puis abandonnée après trop de reports).
  « Améliorer attend » : Reconstruction.hold_upgrades(f) est vrai tant qu'une pièce refaisable attend (Ia3.capital_pay).
  Les destructions servent aussi de MENACE à la couverture des tourelles (f.recon.hits).
  Déterminisme : listes triées, aucun temps mesuré. État : f.recon (tables simples, dans la sauvegarde).
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local Board = require("script.team.board")
local Stock = require("script.team.stock")
local R = require("shared.ai3.reglages")
local Cov = require("shared.team.couverture")
local Rc = require("shared.team.reconstruction")

local Recon = {}

Recon.MAX_OPEN = 3          -- tâches « rebuild » au tableau en même temps
Recon.SAFE_RADIUS = 28      -- tuiles : pas de pose si des unités ennemies sont plus près de la place
Recon.RETRY = 600           -- 10 s : report quand des ennemis sont près de la place
Recon.SEEDS_PER_THINK = 3   -- places essayées (épreuve « ennemis près ») par pensée
Recon.HITS_MAX = 24
Recon.MATCH = 0.3           -- tolérance de position (tuiles) pour reconnaître une pièce d'un projet
Recon.LOGS = 60

local ITEM_OF = {}          -- mémoire LOCALE (prototypes seulement)
local function item_of(name)
  local it = ITEM_OF[name]
  if it == nil then
    local p = game.entity_prototypes[name]
    local list = p and p.items_to_place_this
    it = (list and list[1] and list[1].name) or false
    ITEM_OF[name] = it
  end
  return it or nil
end

function Recon.state(f)
  if not f.recon then f.recon = Rc.new() end
  local s = f.recon
  s.hits = s.hits or {}
  s.stats = s.stats or { recorded = 0, rebuilt = 0, blocked = 0, deferred = 0, tasks = 0, discarded = 0, logs = 0 }
  return s
end

local function stat(s, k, n) s.stats[k] = (s.stats[k] or 0) + (n or 1) end

local function team_of(force_name)
  if force_name == "player" then return State.faction("player") end
  return State.by_force(force_name)
end

--- La pièce morte appartient-elle à un projet du plan directeur de l'équipe ?
local function in_project(f, pos)
  local b = f.build
  if not b then return false end
  for _, pid in ipairs(b.order or {}) do
    local p = b.projects[pid]
    if p then
      for _, e in ipairs(p.ents) do
        if math.abs(e.x - pos.x) <= Recon.MATCH and math.abs(e.y - pos.y) <= Recon.MATCH then return true end
      end
    end
  end
  return false
end

--- Pièce détruite (événement on_entity_died) : menace pour la couverture ; inscrite au registre si l'équipe l'avait posée.
local function on_died(e)
  local ent = e.entity
  if not (ent and ent.valid) then return end
  local role = R.ENTITY_ROLE[ent.type]
  if not role or role == "main" then return end
  local f = team_of(ent.force.name)
  if not (f and not f.eliminated and f.hq and f.hq.valid) then return end
  local s = Recon.state(f)
  local pos = ent.position
  s.hits[#s.hits + 1] = { x = pos.x, y = pos.y, t = e.tick }
  while #s.hits > Recon.HITS_MAX do table.remove(s.hits, 1) end
  local value = Cov.role_value(role)
  if value <= 0 then return end
  local kind, oid
  local owner = ent.unit_number and State.owner(ent.unit_number)
  if owner then
    if owner.f ~= f.id or (owner.kind ~= "drill" and owner.kind ~= "sink") then return end
    kind, oid = owner.kind, owner.oid
  elseif not in_project(f, pos) then
    return
  end
  local recipe
  if ent.type == "assembling-machine" then
    local ok, r = pcall(function() local x = ent.get_recipe() return x and x.name end)
    recipe = ok and r or nil
  end
  Rc.record(s, { name = ent.name, x = pos.x, y = pos.y, dir = ent.direction, item = item_of(ent.name), recipe = recipe,
    value = value, kind = kind, oid = oid }, e.tick)
  stat(s, "recorded")
  if s.stats.logs < Recon.LOGS then
    s.stats.logs = s.stats.logs + 1
    log(string.format("[FO-RECON] %s : %s detruit en (%.1f, %.1f) a %.1f min, a refaire (valeur %d, %d en attente)", f.key or "player",
      ent.name, pos.x, pos.y, (e.tick - (f.started or 0)) / 3600, value, Rc.pending(s)))
  end
end
Events.on(defines.events.on_entity_died, on_died)

--- Y a-t-il des pièces refaisables en attente ? (« améliorer attend » : Ia3.capital_pay)
function Recon.hold_upgrades(f)
  local s = f.recon
  if not s then return false end
  return Rc.hold_upgrades(s, function(item) return Stock.count(f, item) end)
end

function Recon.pending(f) return f.recon and Rc.pending(f.recon) or 0 end

--- Une pensée de l'équipe : tâches de reconstruction au tableau (après Board.sync, comme le plan directeur).
function Recon.think(f, surface, tick)
  local s = f.recon
  if not s or next(s.lost) == nil then return 0 end
  local b = Board.get(f)
  -- Libère les pièces dont la tâche n'existe plus ou n'a plus d'ouvrier (PNJ mort en route).
  local open = 0
  for _, k in ipairs(State.sorted_keys(s.lost)) do
    local r = s.lost[k]
    if r.claimed then
      local t = b.tasks[r.claimed]
      if not (t and t.worker) then r.claimed = nil end
    end
    -- Avant-poste disparu : une foreuse ou un réceptacle seul ne se refait pas.
    if r.kind and not (f.outposts and f.outposts[r.oid]) then
      Rc.done(s, k)
      stat(s, "discarded")
    end
  end
  for _, key in ipairs(State.sorted_keys(b.tasks)) do
    if b.tasks[key].kind == "rebuild" then open = open + 1 end
  end
  if open >= Recon.MAX_OPEN then return 0 end
  Rc.prune(s, tick)
  local due = Rc.due(s, tick)
  if #due == 0 then return 0 end
  local added, tried = {}, 0
  local have, taken = {}, {}
  for _, seed in ipairs(due) do
    if open + #added >= Recon.MAX_OPEN or tried >= Recon.SEEDS_PER_THINK then break end
    if not taken[seed.key] then
    tried = tried + 1
    local near = surface.find_enemy_units({ x = seed.x, y = seed.y }, Recon.SAFE_RADIUS, f.force)
    if #near > 0 then
      Rc.defer(s, seed.key, tick + Recon.RETRY, tick)
      stat(s, "deferred")
    else
      -- Le lot : les pièces voisines dont l'objet est au stock (compté pièce par pièce).
      local batch = {}
      local pool = {}
      for _, r in ipairs(due) do if not taken[r.key] then pool[#pool + 1] = r end end
      for _, r in ipairs(Rc.batch(s, pool, seed, Rc.BATCH_MAX, Rc.BATCH_RADIUS)) do
        local left = have[r.item]
        if left == nil then left = Stock.count(f, r.item) end
        if left >= 1 then
          have[r.item] = left - 1
          batch[#batch + 1] = r
        else
          have[r.item] = left
        end
      end
      if #batch > 0 then
        local keys = {}
        for _, r in ipairs(batch) do keys[#keys + 1] = r.key taken[r.key] = true end
        added[#added + 1] = { key = "rebuild:" .. batch[1].key, kind = "rebuild", prio = Rc.task_prio(batch[1].value),
          domain = "defense", work = 20 + 3 * #batch, items = Rc.items(batch), recs = keys,
          pos = { x = batch[1].x, y = batch[1].y } }
      end
    end
    end
  end
  if #added > 0 then
    local n = Board.add(f, added, tick)
    stat(s, "tasks", n)
    return n
  end
  return 0
end

--- Programme de l'ouvrier qui prend la tâche (script/team/worker.lua, Worker.program). Les pièces sont marquées prises.
function Recon.program(f, task)
  local s = f.recon
  if not (s and task.pos and task.items) then return nil end
  Rc.claim(s, task.recs, task.key)
  return { { "home" }, { "take", task.items, strict = true }, { "goto", task.pos, 4 }, { "act", "rebuild" }, { "home" } }
end

--- Emprise de la pièce (boîte de collision du prototype, tournée selon la direction) élargie de 0,3 : { x0, y0, x1, y1 }.
local function footprint(r)
  local p = game.entity_prototypes[r.name]
  local cb = p and p.collision_box
  local hx, hy = 0.5, 0.5
  if cb and cb.left_top and cb.right_bottom then
    hx, hy = (cb.right_bottom.x - cb.left_top.x) / 2, (cb.right_bottom.y - cb.left_top.y) / 2
  end
  if r.dir == defines.direction.east or r.dir == defines.direction.west then hx, hy = hy, hx end
  return { r.x - hx - 0.3, r.y - hy - 0.3, r.x + hx + 0.3, r.y + hy + 0.3 }
end

--- Le PNJ debout sur l'emprise de la pièce l'empêcherait de se poser (moteur réel, plan directeur : un bâtisseur arrêté sur
--- la dernière machine) : il est écarté, à l'est de l'emprise, sur une case libre.
local function step_aside(surface, self, r)
  if not (self and self.valid) then return end
  local fp, q = footprint(r), self.position
  if q.x > fp[1] and q.x < fp[3] and q.y > fp[2] and q.y < fp[4] then
    local spot = surface.find_non_colliding_position(self.name, { x = fp[3] + 2, y = r.y }, 6, 0.5)
    if spot then self.teleport(spot) end
  end
end

--- Pose les pièces du lot (script/team/worker.lua, ACTS.rebuild). Vrai si au moins une pièce est refaite.
function Recon.act(agent, f, task, surface)
  local s = f.recon
  if not s then return false end
  local inv = agent.entity.get_main_inventory()
  local placed = 0
  for _, k in ipairs(task.recs or {}) do
    local r = s.lost[k]
    if r and not r.abandoned then
      local there = surface.find_entity(r.name, { r.x, r.y })
      if there and there.valid and there.force.name == f.force then
        Rc.done(s, k) -- déjà refaite (par un autre moyen)
      elseif r.item and inv.get_item_count(r.item) >= 1 then
        step_aside(surface, agent.entity, r)
        if surface.can_place_entity({ name = r.name, position = { x = r.x, y = r.y }, direction = r.dir, force = f.force }) then
          local ent = surface.create_entity({ name = r.name, position = { x = r.x, y = r.y }, direction = r.dir, force = f.force,
            raise_built = true })
          if ent and ent.valid then
            inv.remove({ name = r.item, count = 1 })
            if r.recipe and ent.type == "assembling-machine" then pcall(ent.set_recipe, r.recipe) end
            if r.kind and ent.unit_number then
              State.own(ent, f.id, r.kind, r.oid)
              local o = f.outposts and f.outposts[r.oid]
              if o then
                if r.kind == "drill" then
                  o.drill_list = o.drill_list or {}
                  o.drill_list[#o.drill_list + 1] = ent
                  o.drills = o.drills + 1
                else
                  o.sinks = o.sinks or {}
                  o.sinks[#o.sinks + 1] = ent
                end
              end
            end
            Rc.done(s, k)
            placed = placed + 1
            stat(s, "rebuilt")
          end
        else
          stat(s, "blocked")
        end
      end
    end
  end
  Rc.release(s, task.key)
  if placed > 0 and s.stats.logs < Recon.LOGS then
    s.stats.logs = s.stats.logs + 1
    log(string.format("[FO-RECON] %s : %d piece(s) refaite(s) en (%.1f, %.1f) a %.1f min, %d en attente", f.key or "player", placed,
      task.pos.x, task.pos.y, (game.tick - (f.started or 0)) / 3600, Rc.pending(s)))
  end
  return placed > 0
end

remote.add_interface("fo-recon", {
  status = function(key)
    local f = (key == nil or key == "player") and State.faction("player") or nil
    if not f and key ~= nil then
      for _, id in ipairs(State.alive()) do
        local x = State.faction(id)
        if x and (x.key == key or id == key) then f = x break end
      end
    end
    local s = f and f.recon
    if not s then return { pending = 0, recorded = 0, rebuilt = 0, blocked = 0, deferred = 0, tasks = 0, hits = 0, abandoned = 0, hold = false } end
    local ab = 0
    for _, k in ipairs(State.sorted_keys(s.lost)) do if s.lost[k].abandoned then ab = ab + 1 end end
    local st = s.stats
    return { pending = Rc.pending(s), recorded = st.recorded, rebuilt = st.rebuilt, blocked = st.blocked, deferred = st.deferred,
      tasks = st.tasks, discarded = st.discarded, hits = #s.hits, abandoned = ab, hold = Recon.hold_upgrades(f) }
  end,
})

return Recon
