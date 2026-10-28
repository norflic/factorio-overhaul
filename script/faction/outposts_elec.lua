--[[
  Lot ELEC2 « les avant-postes passent à l'électrique » (retour du DC, 0.6.5 : « ils utilisent toujours massivement des
  foreuses thermiques, malgré qu'ils ont des foreuses électriques niveau 4 »).

  Quand l'équipe a un réseau électrique (une centrale qui tourne, au moins Elec.MIN_POLES poteaux) et de la marge de
  puissance, ses avant-postes posent la foreuse ÉLECTRIQUE (prototypes : type mining-drill, source d'énergie électrique,
  posable, dans les gabarits de shared/team/modules.lua) à la place de celle à combustible :
    - CONTEXTE (Elec.context, posé dans T.elec par script/team/team.lua avant les planificateurs) : les objets du kit
      (shared/team/config.lua, T.pair_kit) ; rien n'est écrit en dur ici, ni noms de foreuse (lus aux prototypes), ni
      puissances, ni portées de fil, ni vitesses (prototypes) ;
    - POSE (Elec.place, appelée par Outposts.build/extend quand l'ouvrier porte des foreuses électriques) : la foreuse sur
      le minerai, son réceptacle sur le point de dépôt (vecteur du prototype), un poteau qui l'alimente, puis la ligne de
      poteaux depuis le réseau (P.pole_chain) ; la première paire est annulée si la ligne ne se fait pas ;
    - REMPLACEMENT (Elec.retire) : les foreuses à combustible d'un avant-poste couvert sont retirées (rendues à l'ouvrier)
      quand les électriques valent le plafond de l'avant-poste, sans interrompre la production (les électriques d'abord).
  Déterminisme : listes triées, aucun hasard, aucun temps mesuré.
]]

local T = require("shared.team.config")
local M = require("shared.team.modules")
local P = require("shared.team.plan")
local State = require("script.faction.state")
local function sorted_keys(t) return State.sorted_keys(t or {}) end
local R = require("shared.ai3.reglages") -- types du moteur -> rôle (consommateurs d'électricité)

-- Types consommateurs : machines de fabrication, foreuses, laboratoires, et ceux de la logistique qui ont une source
-- d'énergie électrique (pinces : charge moyenne). Relevé au premier appel (prototypes).
local USERS, LIGHT = nil, {}
local function users()
  if USERS then return USERS end
  USERS = {}
  for _, ty in ipairs(R.ENTITY_TYPES) do
    local role = R.ENTITY_ROLE[ty]
    if role == "fabrique" or role == "foreuse" or role == "labo" then
      USERS[#USERS + 1] = ty
    elseif role == "logistique" then
      local list = game.get_filtered_entity_prototypes({ { filter = "type", type = ty } })
      for _, n in ipairs(sorted_keys(list)) do
        if list[n].electric_energy_source_prototype ~= nil then
          USERS[#USERS + 1] = ty
          LIGHT[ty] = true
          break
        end
      end
    end
  end
  return USERS
end

local Elec = {}

Elec.ENABLED = true
Elec.MIN_POLES = 20        -- poteaux du réseau de la centrale à partir desquels un avant-poste peut être électrifié
Elec.POLES_IN_KIT = 12     -- poteaux portés avec le kit (ligne depuis le réseau + poteaux des foreuses)
Elec.LOAD_PCT = 85         -- % de la puissance des machines à vapeur qu'on accepte de charger
Elec.INSERTER_KW = 5       -- charge moyenne d'une pince (aucune lecture fiable : prototypes, puissance max 13 kW)
Elec.GRID_EVERY = 1800     -- ticks entre deux relevés du réseau
Elec.BACKOFF = 10 * 3600   -- un type d'avant-poste dont la ligne a échoué repasse à combustible pendant ce temps
Elec.MAX_ATTEMPTS = 120    -- emplacements essayés au plus (une foreuse 3 × 3 en consomme plus qu'une 2 × 2)


---------------------------------------------------------------------------------------------------
-- Prototypes (cache LOCAL : prototypes seulement)
---------------------------------------------------------------------------------------------------
local cache = nil

local function protos()
  if cache then return cache end
  local c = { drills = {}, poles = {}, info = {} }
  local list = game.get_filtered_entity_prototypes({ { filter = "type", type = "mining-drill" } })
  for _, name in ipairs(sorted_keys(list)) do
    local p = list[name]
    local spec = M.BASE[name]
    if spec and spec.kind == "drill" and spec.usage_kw and spec.drop and p.electric_energy_source_prototype ~= nil
      and p.items_to_place_this and #p.items_to_place_this > 0 then
      -- point de dépôt : le prototype ne l'expose pas à l'exécution, c'est la donnée du gabarit (modules.lua, `drop`)
      c.drills[#c.drills + 1] = name
      c.info[name] = { speed = p.mining_speed or 1, kw = (p.max_energy_usage or 0) * 60 / 1000, drop = spec.drop }
    end
  end
  local pl = game.get_filtered_entity_prototypes({ { filter = "type", type = "electric-pole" } })
  for _, name in ipairs(sorted_keys(pl)) do
    local p = pl[name]
    local box = p.collision_box
    local w = box and (box.right_bottom.x - box.left_top.x) or 1
    if p.items_to_place_this and #p.items_to_place_this > 0 and w <= 0.9 and (p.max_wire_distance or 0) > 0 then
      c.poles[#c.poles + 1] = name
      c.info[name] = { wire = p.max_wire_distance, supply = p.supply_area_distance or 2.5 }
    end
  end
  -- la plus rapide des foreuses électriques d'abord (égalité : le nom) ; le poteau au fil le plus long d'abord
  table.sort(c.drills, function(a, b)
    if c.info[a].speed ~= c.info[b].speed then return c.info[a].speed > c.info[b].speed end
    return a < b
  end)
  table.sort(c.poles, function(a, b)
    if c.info[a].wire ~= c.info[b].wire then return c.info[a].wire > c.info[b].wire end
    return a < b
  end)
  local burner = game.entity_prototypes[T.DRILL]
  c.burner_speed = burner and burner.mining_speed or 0.25
  cache = c
  return c
end

function Elec.drill_names() return protos().drills end

--- Foreuses à combustible qu'une foreuse électrique vaut (vitesses de minage des prototypes).
function Elec.per()
  local c = protos()
  local d = c.drills[1]
  if not d then return 1 end
  return math.max(1, math.floor(c.info[d].speed / math.max(0.01, c.burner_speed) + 0.5))
end

function Elec.is_electric(e)
  return e and e.valid and protos().info[e.name] ~= nil and protos().info[e.name].drop ~= nil
end

---------------------------------------------------------------------------------------------------
-- Réseau de la centrale
---------------------------------------------------------------------------------------------------
--- Relevé du réseau de la force (une fois par Elec.GRID_EVERY ticks) : identifiants des réseaux qui ont un générateur,
--- poteaux dessus, puissance installée et chargée (kW). Rangé dans f.team.elec (nombres seulement).
local function grid(f, tick)
  local t = f.team
  t.elec = t.elec or {}
  local g = t.elec
  if g.at and tick - g.at < Elec.GRID_EVERY then return g end
  g.at = tick
  g.poles, g.cap_kw, g.used_kw, g.nets = 0, 0, 0, {}
  local surface = f.hq and f.hq.valid and f.hq.surface
  if not surface then return g end
  local c = f.hq_pos
  local R = 160
  local area = { { c.x - R, c.y - R }, { c.x + R, c.y + R } }
  local nets = {}
  for _, e in ipairs(surface.find_entities_filtered({ area = area, force = f.force, type = "generator" })) do
    local id = e.electric_network_id
    if id then
      nets[id] = true
      local pr = e.prototype
      g.cap_kw = g.cap_kw + (pr.max_power_output or 0) * 60 / 1000
    end
  end
  g.nets = sorted_keys(nets)
  local n = 0
  for _, e in ipairs(surface.find_entities_filtered({ area = area, force = f.force, type = "electric-pole" })) do
    if nets[e.electric_network_id] then n = n + 1 end
  end
  g.poles = n
  local used = 0
  local usage = {}
  for _, e in ipairs(surface.find_entities_filtered({ area = area, force = f.force, type = users() })) do
    local pr = e.prototype
    if pr.electric_energy_source_prototype ~= nil then
      if LIGHT[e.type] then used = used + Elec.INSERTER_KW
      else
        local u = usage[e.name]
        if not u then u = (pr.max_energy_usage or 0) * 60 / 1000 usage[e.name] = u end
        used = used + u
      end
    end
  end
  g.used_kw = used
  return g
end

--- Puissance disponible pour de nouvelles foreuses (kW).
function Elec.headroom(f, tick)
  local g = grid(f, tick)
  return g.cap_kw * Elec.LOAD_PCT / 100 - g.used_kw
end

--- Contexte électrique de la pensée (T.elec) ou nil. `choose_pole(book, stock)` : le poteau le moins cher fabricable.
function Elec.context(f, tick, book, stock, choose_pole)
  if not Elec.ENABLED or not f.team or not (f.hq and f.hq.valid) then return nil end
  local c = protos()
  local g = grid(f, tick)
  if g.poles < Elec.MIN_POLES or #g.nets == 0 then return nil end
  local drill
  for _, n in ipairs(c.drills) do
    -- au stock, ou fabricable À LA MAIN avec la matière du coffre (sinon le projet attendrait le cuivre de ses circuits
    -- alors que la foreuse à combustible partirait tout de suite)
    if (stock[n] or 0) >= 2 or (book and book:handcraftable(n) and next(book:plan({ { n, 2 } }, stock).raw) == nil) then
      drill = n
      break
    end
  end
  if not drill then return nil end
  local pole = choose_pole and choose_pole(book, stock) or nil
  if not (pole and c.info[pole]) then
    for _, n in ipairs(c.poles) do
      if (stock[n] or 0) >= Elec.POLES_IN_KIT or (book and book:handcraftable(n)) then pole = n break end
    end
  end
  if not (pole and c.info[pole]) then return nil end
  local per = Elec.per()
  -- marge de puissance : au moins deux foreuses (le kit en porte plus ; la pose s'arrête quand la marge est épuisée)
  if Elec.headroom(f, tick) < 2 * c.info[drill].kw then return nil end
  local off = f.team.elec.off or {}
  local out, any = {}, false
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    if (off[kind] or 0) <= tick then
      out[kind] = { drill = drill, pole = pole, poles = Elec.POLES_IN_KIT, per = per }
      any = true
    end
  end
  return any and out or nil
end

--- Une ligne n'a pas pu se faire pour ce type d'avant-poste : retour aux foreuses à combustible pendant Elec.BACKOFF.
function Elec.fail(f, kind, tick)
  local g = f.team.elec or {}
  f.team.elec = g
  g.off = g.off or {}
  g.off[kind] = tick + Elec.BACKOFF
end

---------------------------------------------------------------------------------------------------
-- Pose
---------------------------------------------------------------------------------------------------
local function rotate(v, dir)
  local x, y = v[1], v[2]
  if dir == defines.direction.east then return { -y, x } end
  if dir == defines.direction.south then return { -x, -y } end
  if dir == defines.direction.west then return { y, -x } end
  return { x, y }
end

--- Premier objet de `names` que l'ouvrier porte (ou nil).
local function carried(carrier, names)
  for _, n in ipairs(names) do if carrier.get_item_count(n) > 0 then return n end end
  return nil
end

function Elec.carries(carrier)
  return carried(carrier, protos().drills) ~= nil
end

--- Pose le poteau `name` en `pos`, relie au réseau `net` : rend le poteau ou nil.
local function put_pole(surface, f, name, pos, carrier, net)
  if carrier.get_item_count(name) < 1 then return nil end
  if not surface.can_place_entity({ name = name, position = pos, force = f.force }) then return nil end
  local e = surface.create_entity({ name = name, position = pos, force = f.force })
  if not (e and e.valid) then return nil end
  carrier.remove({ name = name, count = 1 })
  if net and e.electric_network_id ~= net then
    -- relie au poteau du réseau le plus proche dans la portée du fil
    local wire = protos().info[name].wire
    local best, bd
    for _, o in ipairs(surface.find_entities_filtered({ position = pos, radius = wire, type = "electric-pole", force = f.force })) do
      if o ~= e and o.electric_network_id == net then
        local d = (o.position.x - pos.x) ^ 2 + (o.position.y - pos.y) ^ 2
        if not bd or d < bd then best, bd = o, d end
      end
    end
    if best then pcall(function() e.connect_neighbour(best) end) end
  end
  return e
end

--- Poteau le plus proche de `pos` sur un réseau qui a un générateur : (poteau, id du réseau) ou nil.
local function source_pole(f, surface, pos)
  local nets = {}
  for _, id in ipairs((f.team.elec and f.team.elec.nets) or {}) do nets[id] = true end
  local best, bd
  for _, r in ipairs({ 80, 160, 320 }) do
    for _, o in ipairs(surface.find_entities_filtered({ position = pos, radius = r, type = "electric-pole", force = f.force })) do
      if nets[o.electric_network_id] then
        local d = (o.position.x - pos.x) ^ 2 + (o.position.y - pos.y) ^ 2
        if not bd or d < bd or (d == bd and o.unit_number < best.unit_number) then best, bd = o, d end
      end
    end
    if best then return best, best.electric_network_id end
  end
  return nil
end

--- Un poteau alimente-t-il déjà cette foreuse (zone d'alimentation qui touche sa boîte) ?
local function supplied(surface, f, c, half, nets_ok)
  local info = protos().info
  local reach = 0
  for _, n in ipairs(protos().poles) do reach = math.max(reach, info[n].supply) end
  for _, o in ipairs(surface.find_entities_filtered({ area = { { c.x - half - reach, c.y - half - reach }, { c.x + half + reach, c.y + half + reach } },
    type = "electric-pole", force = f.force })) do
    local s = info[o.name] and info[o.name].supply or 0
    if math.abs(o.position.x - c.x) < half + s and math.abs(o.position.y - c.y) < half + s and nets_ok(o.electric_network_id) then
      return true
    end
  end
  return false
end

local RING = { { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 }, { -2, -1 }, { 2, -1 }, { -1, -2 }, { -1, 2 }, { -2, 1 }, { 2, 1 }, { 1, -2 }, { 1, 2 },
  { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } }

--- Pose jusqu'à `max_n` paires foreuse électrique + réceptacle sur le gisement `kind` autour de `center`, leur poteau, et la
--- ligne depuis le réseau. `h` = { sink_position, DIRS } de outposts.lua. Rend drills, sinks (vides : rien posé).
function Elec.place(f, surface, kind, center, carrier, max_n, radius, h)
  local spec = T.outposts[kind]
  local c = protos()
  local dname = carried(carrier, c.drills)
  local pname = carried(carrier, c.poles)
  local drills, sinks = {}, {}
  if not (dname and pname) then return drills, sinks end
  local src, net = source_pole(f, surface, center)
  if not src then return drills, sinks end
  local info = c.info[dname]
  local half = 1.5
  local nets_ok = function(id) return id == net end
  -- minerai, du plus proche du centre au plus loin
  local resources = surface.find_entities_filtered({ position = center, radius = radius, name = spec.resource })
  table.sort(resources, function(a, b)
    local pa, pb = a.position, b.position
    local da = (pa.x - center.x) ^ 2 + (pa.y - center.y) ^ 2
    local db = (pb.x - center.x) ^ 2 + (pb.y - center.y) ^ 2
    if da ~= db then return da < db end
    if pa.x ~= pb.x then return pa.x < pb.x end
    return pa.y < pb.y
  end)
  local made = {} -- entités posées par cet appel (annulation de la première paire)
  local tried, attempts = {}, 0
  local linked = false
  local max_kw = math.max(0, Elec.headroom(f, game.tick))
  for _, res in ipairs(resources) do
    if #drills >= max_n or attempts >= Elec.MAX_ATTEMPTS then break end
    if carrier.get_item_count(dname) < 1 or carrier.get_item_count(spec.sink) < 1 then break end
    if (#drills + 1) * info.kw > max_kw then break end -- marge de puissance épuisée
    local rp = res.position
    local pos = { x = math.floor(rp.x) + 0.5, y = math.floor(rp.y) + 0.5 }
    local key = math.floor(pos.x) * 65536 + math.floor(pos.y)
    local fresh = not tried[key]
    tried[key] = true
    if fresh then
      attempts = attempts + 1
      local placed = false
      for _, dir in ipairs(h.DIRS) do
        local v = rotate(info.drop, dir)
        local drop = { x = pos.x + v[1], y = pos.y + v[2] }
        local spos = h.sink_position(surface, spec.sink, drop, f.force, pos)
        if spos and h.free(f, dname, pos, dir, spec.sink, spos)
          and surface.can_place_entity({ name = dname, position = pos, direction = dir, force = f.force }) then
          local d = surface.create_entity({ name = dname, position = pos, direction = dir, force = f.force })
          if d and d.valid then
            local s = surface.can_place_entity({ name = spec.sink, position = spos, force = f.force })
              and surface.create_entity({ name = spec.sink, position = spos, force = f.force })
            local pole = nil
            if s and s.valid then
              if supplied(surface, f, pos, half, nets_ok) then
                pole = true
              else
                for _, r in ipairs(RING) do
                  pole = put_pole(surface, f, pname, { x = pos.x + r[1], y = pos.y + r[2] }, carrier, linked and net or nil)
                  if pole then break end
                end
              end
            end
            if s and s.valid and pole then
              carrier.remove({ name = dname, count = 1 })
              carrier.remove({ name = spec.sink, count = 1 })
              if spec.sink == T.SMELTER then
                local n = math.min(T.fuel_per_burner, carrier.get_item_count(T.fuel))
                if n > 0 then s.get_fuel_inventory().insert({ name = T.fuel, count = carrier.remove({ name = T.fuel, count = n }) }) end
              end
              drills[#drills + 1] = d
              sinks[#sinks + 1] = s
              made[#made + 1] = d
              made[#made + 1] = s
              if type(pole) ~= "boolean" then made[#made + 1] = pole end
              if not linked then
                -- première paire : la ligne depuis le réseau ; sinon tout est annulé
                local first = type(pole) ~= "boolean" and pole or surface.find_entities_filtered({ position = pos, radius = 5, type = "electric-pole", force = f.force })[1]
                local ok = first ~= nil and Elec.connect(f, surface, src, net, first, pname, carrier)
                if ok then
                  linked = true
                else
                  for _, e in ipairs(made) do
                    if e.valid then
                      carrier.insert({ name = e.name, count = 1 })
                      e.destroy()
                    end
                  end
                  drills, sinks = {}, {}
                  return drills, sinks, "ligne"
                end
              end
              placed = true
            else
              if s and s.valid then s.destroy() end
              d.destroy()
            end
          end
        end
        if placed then break end
      end
    end
  end
  return drills, sinks
end

--- Ligne de poteaux du poteau `src` (réseau `net`) jusqu'au poteau `target` ; les poteaux posés sont pris à l'ouvrier.
--- Vrai si `target` est sur le réseau à la fin.
function Elec.connect(f, surface, src, net, target, pname, carrier)
  local wire = protos().info[pname].wire
  if target.electric_network_id == net then return true end
  local a, b = src.position, target.position
  local chain = P.pole_chain(a, b, math.min(wire, protos().info[target.name] and protos().info[target.name].wire or wire), false,
    function(x, y) return surface.can_place_entity({ name = pname, position = { x = x, y = y }, force = f.force }) end)
  if not chain then return false end
  if #chain > carrier.get_item_count(pname) then return false end
  local made = {}
  for _, pos in ipairs(chain) do
    local e = put_pole(surface, f, pname, pos, carrier, net)
    if not e then
      for _, x in ipairs(made) do if x.valid then x.destroy() carrier.insert({ name = pname, count = 1 }) end end
      return false
    end
    made[#made + 1] = e
  end
  -- le dernier poteau de la ligne rejoint la cible
  local last = made[#made]
  if target.electric_network_id ~= net then
    local ref = last or src
    pcall(function() ref.connect_neighbour(target) end)
  end
  return target.electric_network_id == net
end

---------------------------------------------------------------------------------------------------
-- Remplacement
---------------------------------------------------------------------------------------------------
--- Retire les foreuses à combustible de l'avant-poste `o` en trop : l'avant-poste vaut `weight` foreuses à combustible
--- équivalentes (électrique = Elec.per) pour un plafond `cap` ; les brûleurs en trop sont rendus à l'ouvrier avec leur
--- réceptacle (contenu compris). Rend le nombre retiré.
function Elec.retire(o, carrier, cap, per)
  local burners, nelec = {}, 0
  for _, d in ipairs(o.drill_list or {}) do
    if d.valid then
      if Elec.is_electric(d) then nelec = nelec + 1 else burners[#burners + 1] = d end
    end
  end
  local over = nelec * per + #burners - cap
  if nelec == 0 or over <= 0 then return 0 end
  local n = 0
  for i = #burners, 1, -1 do
    if n >= over then break end
    local d = burners[i]
    carrier.insert({ name = d.name, count = 1 })
    d.destroy() -- l'événement de destruction décompte la foreuse de l'avant-poste (Outposts.on_drill_lost)
    n = n + 1
  end
  return n
end

return Elec
