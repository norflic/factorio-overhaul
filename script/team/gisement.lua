--[[
  Lot GISEMENTS (retour du DC du 31/10, 0.6.27) : « les foreuses thermiques occupent encore une partie des gisements et elles ne
  fonctionnent pas », « les fours sur le gisement prennent de l'espace ». Règle pure : shared/team/gisement.lua (G.verdict).

  Tâche de FOND bornée (au plus Gis.PER_PASS actions toutes les Gis.EVERY ticks par équipe) sur les foreuses à combustion des
  avant-postes (f.outposts[*].drill_list) :
    - une foreuse À L'ARRÊT depuis G.IDLE (statut autre que « travaille ») est jugée : « rebrancher » (son four a disparu : un
      réceptacle du stock est reposé à son dépôt), « remplacer » (Swap.think s'en charge, remplacement électrique prêt : on attend
      G.HARD), « retirer » (arrêt de G.RETIRE sans remplacement, ou minerai épuisé sous elle) ;
    - retirer = objets REPRIS au stock (foreuse, combustible, four et son contenu), jamais détruits ; l'avant-poste n'est plus plein
      (la place libérée sert aux foreuses électriques de la capitalisation) et plus aucune paire à four n'est reposée sur le minerai
      (G.forbid_pairs, lu par Outposts.extend, script/faction/outposts.lua).
  Journal [FO-GISEMENT]. Déterminisme : listes triées, aucun temps mesuré (ticks du jeu). État : f.gisement (tables simples).
]]

local T = require("shared.team.config")
local G = require("shared.team.gisement")
local S = require("shared.team.foreuse_swap")
local State = require("script.faction.state")
local Stock = require("script.team.stock")

local Gis = {}

Gis.EVERY = 1800     -- 30 s entre deux passes
Gis.PER_PASS = 4     -- actions au plus par passe
Gis.LOGS = 40        -- lignes de journal au plus par équipe

local function sorted_keys(t) return State.sorted_keys(t or {}) end

local function box_of(e)
  local p = e.prototype
  return { x = e.position.x, y = e.position.y, w = p.tile_width or 1, h = p.tile_height or 1 }
end

local function say(f, st, text, tick)
  st.logs = (st.logs or 0) + 1
  if st.logs <= Gis.LOGS then
    log(string.format("[FO-GISEMENT] %s : %s a %.1f min", f.key or "player", text, (tick - (f.started or 0)) / 3600))
  end
end

local function state_of(f)
  local st = f.gisement
  if not st then
    st = { next = 0, retired = 0, rewired = 0, idle = {}, logs = 0 }
    f.gisement = st
  end
  return st
end

--- Reprend un objet entier au stock de l'équipe : l'entité, son combustible et son contenu.
local function take_back(f, e, item)
  if not (e and e.valid) then return end
  for _, inv_id in ipairs({ defines.inventory.fuel, defines.inventory.furnace_source, defines.inventory.furnace_result,
      defines.inventory.furnace_modules }) do
    local inv = e.get_inventory(inv_id)
    if inv then
      local c = inv.get_contents()
      for _, name in ipairs(sorted_keys(c)) do Stock.insert(f, name, c[name]) end
      inv.clear()
    end
  end
  State.disown(e.unit_number)
  e.destroy()
  if item then Stock.insert(f, item, 1) end
end

--- Une passe : rend le nombre d'actions faites.
function Gis.think(f, surface, tick)
  if not (f and f.outposts and next(f.outposts)) then return 0 end
  local st = state_of(f)
  if tick < st.next then return 0 end
  st.next = tick + Gis.EVERY
  local seen, actions = {}, 0
  local ready = (f.swap and f.swap.ready or 0) > 0
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    local spec = T.outposts[o.kind]
    -- un champ en migration est géré par la migration ; sans réceptacle de four, l'arrêt d'une foreuse (coffre plein) n'est pas jugé ici
    local sink_proto = spec and game.entity_prototypes[spec.sink]
    local on_furnace = sink_proto and sink_proto.type == "furnace"
    if o.migr ~= "en cours" and o.drill_list then
      local keep, removed = {}, 0
      for index, d in ipairs(o.drill_list) do
        local kept = true
        if d.valid and d.name == T.DRILL and d.unit_number then
          local u = d.unit_number
          local s = d.status
          local working = (s == defines.entity_status.working) or (s == defines.entity_status.normal)
          local first = st.idle[u] or tick
          if not working then seen[u] = first end
          local idle = working and 0 or (tick - first)
          if actions < Gis.PER_PASS and idle >= G.IDLE and (on_furnace or s == defines.entity_status.no_minable_resources) then
            local pos = d.position
            local rx, ry = S.rotate(d.direction, T.drill_drop[1], T.drill_drop[2])
            local sink
            for _, sk in ipairs(o.sinks or {}) do
              if sk.valid and S.inside(box_of(sk), pos.x + rx, pos.y + ry) then sink = sk break end
            end
            local verdict, why = G.verdict({ idle = idle, dead = (s == defines.entity_status.no_minable_resources),
              sink = sink and "ok" or "manque", can_sink = spec ~= nil and Stock.count(f, spec.sink) > 0, ready = ready })
            if verdict == "rebrancher" then
              local fits = function(name, p) return surface.can_place_entity({ name = name, position = p, force = f.force }) end
              local c = { x = pos.x + rx, y = pos.y + ry }
              local at = surface.find_non_colliding_position(spec.sink, c, 2, 1)
              -- le réceptacle posé doit RECEVOIR le dépôt de la foreuse (sa boîte contient le point de dépôt)
              local catches = at and S.inside({ x = at.x, y = at.y, w = sink_proto.tile_width or 1, h = sink_proto.tile_height or 1 }, c.x, c.y)
              if at and catches and fits(spec.sink, at) and Stock.remove(f, spec.sink, 1) >= 1 then
                local n = surface.create_entity({ name = spec.sink, position = at, force = f.force })
                if n then
                  State.own(n, f.id, "sink", o.id)
                  o.sinks[#o.sinks + 1] = n
                  st.rewired = st.rewired + 1
                  st.idle[u] = nil
                  seen[u] = nil
                  actions = actions + 1
                  say(f, st, string.format("foreuse a combustion en (%.1f, %.1f) rebranchee a un four neuf (%s)", pos.x, pos.y, why), tick)
                else
                  Stock.insert(f, spec.sink, 1)
                end
              end
            elseif verdict == "retirer" then
              take_back(f, d, T.DRILL)
              if sink and sink.valid then take_back(f, sink, spec.sink) end
              st.retired = st.retired + 1
              actions = actions + 1
              removed = removed + 1
              kept = false
              seen[u] = nil
              o.full, o.full_by, o.full_why = nil, nil, nil -- la place libérée sert aux foreuses électriques de la capitalisation
              say(f, st, string.format("foreuse a combustion retiree en (%.1f, %.1f) : %s (arret %.1f min, avant-poste %d, %d retiree(s))",
                pos.x, pos.y, why, idle / 3600, o.id, st.retired), tick)
            end
          end
        end
        if kept then keep[#keep + 1] = d end
      end
      if removed > 0 then
        o.drill_list = keep
        o.drills = math.max(0, (o.drills or #keep + removed) - removed)
      end
    end
  end
  st.idle = seen
  return actions
end

return Gis
