--[[
  FANTÔMES (lot FANTOMES, exigence du DC du 27/10 : « visualiser où ils vont les poser »). Quand un PNJ de VOTRE équipe prend une
  tâche de construction d'avant-poste (build) ou d'agrandissement (extend), les paires foreuse + réceptacle qu'il va poser sont
  montrées en FANTÔMES (entity-ghost de votre force) sur le gisement, le temps de son trajet. Les emplacements viennent de
  Outposts.preview_pairs : le même parcours que la pose (tuiles de minerai, orientations, points de dépôt), sans objet ni
  destruction.

  Un aperçu, pas un chantier : à son arrivée, le PNJ pose ses vrais bâtiments comme avant (Outposts.build/extend), et les
  fantômes de la tâche sont retirés d'abord (crochet Outposts.on_arrive) : aucun ravivage, donc ni le coût d'un ravivage (F295)
  ni un PNJ debout sur l'emprise qui l'empêche (F293). Les fantômes sont purgés :
    - à l'arrivée du PNJ (crochet ci-dessus) ;
    - à la fin de la tâche, réussie ou non (Board.finish) ;
    - par le balayage (Fantomes.sweep, à chaque pensée) quand la tâche n'est plus au tableau, n'a plus d'ouvrier (PNJ mort) ou
      dure depuis plus de Fantomes.MAX_AGE ticks.
  État : f.fantomes = { [clé de tâche] = { task, ents = { fantômes }, site | outpost, tick } } ; compteurs f.stats.fantomes_*.
  Réglage de carte fo-war-fantomes (vrai par défaut) pour couper. Votre équipe seulement.
]]

local Storage = require("script.core.storage")
local T = require("shared.team.config")
local State = require("script.faction.state")
local Outposts = require("script.faction.outposts")

local Fantomes = {}

Fantomes.SETTING = "fo-war-fantomes"
Fantomes.MAX_AGE = 20 * 3600 -- ticks : un aperçu plus vieux est purgé (tâche bloquée)
Fantomes.KINDS = { build = true, extend = true }
Fantomes.RADIUS = Outposts.RADIUS -- ceux de Outposts.build et Outposts.extend (place_pairs ; lot EXTENSION-FER : 14 et 32)

function Fantomes.on()
  local ok, v = pcall(function() return settings.global[Fantomes.SETTING].value end)
  return not (ok and v == false)
end

local function stat(f, k, n)
  f.stats = f.stats or {}
  f.stats[k] = (f.stats[k] or 0) + (n or 1)
end

--- Détruit les fantômes d'une entrée et la retire. `why` : compteur ("arrivee", "fin", "balayage").
local function drop(f, key, why)
  local e = f.fantomes and f.fantomes[key]
  if not e then return 0 end
  local n = 0
  for _, g in ipairs(e.ents) do
    if g.valid then
      g.destroy()
      n = n + 1
    end
  end
  f.fantomes[key] = nil
  stat(f, "fantomes_" .. why, n)
  return n
end

--- Montre les paires de la tâche `task` (claimed par un PNJ). Rend le nombre de fantômes posés.
function Fantomes.show(f, task, tick)
  if not (f.is_player and Fantomes.KINDS[task.kind] and f.hq and f.hq.valid and Fantomes.on()) then return 0 end
  f.fantomes = f.fantomes or {}
  if f.fantomes[task.key] then return 0 end
  local surface = f.hq.surface
  local kind, center, max_pairs, site, oid, ext
  if task.kind == "build" then
    kind, site = task.outpost_kind, task.site
    center = site and { x = site.x, y = site.y }
    max_pairs = kind and T.outposts[kind] and T.outposts[kind].drills
  else
    local o = f.outposts and f.outposts[task.outpost]
    if o then
      kind, oid, center, ext = o.kind, o.id, o.pos, o
      max_pairs = math.min(T.outposts[kind].drills, T.max_drills(kind) - o.drills)
    end
  end
  if not (kind and center and center.x and max_pairs and max_pairs > 0 and T.outposts[kind]) then return 0 end
  local pairs_ = Outposts.preview_pairs(f, surface, kind, center, max_pairs, Fantomes.RADIUS[task.kind], ext)
  local ents = {}
  for _, p in ipairs(pairs_) do
    for _, part in ipairs({ p.drill, p.sink }) do
      local g = surface.create_entity({ name = "entity-ghost", inner_name = part.name, position = part.position,
        direction = part.direction, force = f.force })
      if g and g.valid then ents[#ents + 1] = g end
    end
  end
  if #ents == 0 then return 0 end
  f.fantomes[task.key] = { task = task, ents = ents, site = site, outpost = oid, tick = tick }
  stat(f, "fantomes_montres", #ents)
  log(string.format("[FO-FANTOMES] player : tache %s : %d fantome(s) (%d paire(s) %s) en (%.0f, %.0f) a %.1f min", task.key, #ents, #pairs_,
    kind, center.x, center.y, (tick - (f.started or 0)) / 3600))
  return #ents
end

--- La tâche `key` est finie (réussie ou non) : ses fantômes partent.
function Fantomes.finish(f, key)
  return drop(f, key, "fin")
end

--- Balayage : les aperçus dont la tâche n'est plus au tableau, n'a plus d'ouvrier ou est trop vieille. Rend le nombre purgé.
function Fantomes.sweep(f, tick)
  if not f.fantomes then return 0 end
  local tasks = f.team and f.team.board and f.team.board.tasks or {}
  local n = 0
  for _, key in ipairs(State.sorted_keys(f.fantomes)) do
    local e = f.fantomes[key]
    local live = tasks[key] == e.task and e.task.worker ~= nil
    if not live or tick - e.tick > Fantomes.MAX_AGE then n = n + drop(f, key, "balayage") end
  end
  return n
end

--- Fantômes d'aperçu vivants (registre) et fantômes de pose de ce module repérés sur la carte (balayage de contrôle).
function Fantomes.status(f)
  local live, entries, drills = 0, 0, 0
  for _, key in ipairs(State.sorted_keys(f.fantomes or {})) do
    entries = entries + 1
    for _, g in ipairs(f.fantomes[key].ents) do
      if g.valid then
        live = live + 1
        if g.ghost_name == T.DRILL then drills = drills + 1 end
      end
    end
  end
  return { entries = entries, live = live, drills = drills, shown = (f.stats or {}).fantomes_montres or 0, arrive = (f.stats or {}).fantomes_arrivee or 0,
    fin = (f.stats or {}).fantomes_fin or 0, balayage = (f.stats or {}).fantomes_balayage or 0 }
end

-- Crochet des avant-postes : le PNJ arrive et va poser (Outposts.build : site ; Outposts.extend : avant-poste).
Outposts.on_arrive = function(f, site, outpost)
  if not (f.fantomes and f.is_player) then return end
  for _, key in ipairs(State.sorted_keys(f.fantomes)) do
    local e = f.fantomes[key]
    if (site and e.site == site) or (outpost and e.outpost == outpost) then drop(f, key, "arrivee") end
  end
end

remote.add_interface("fo-fantomes", {
  status = function()
    local f = Storage.ns("pteam").team
    return f and Fantomes.status(f) or { entries = 0, live = 0, shown = 0, arrive = 0, fin = 0, balayage = 0 }
  end,
})

return Fantomes
