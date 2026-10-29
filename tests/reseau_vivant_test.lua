--[[
  Lot CORR-RESEAU : test hors jeu du RUNTIME (script/team/reseau_vivant.lua) sur un moteur simulé minimal (surface, entités,
  ennemi le plus proche) et un état de plan directeur écrit à la main (projets, pièces, drapeaux « bâti »).
    §1 centrale saine : rien ne bouge ; interrupteur d'essai coupé : rien ne bouge non plus ;
    §2 chaudière et machine perdues, site sûr : les DEUX pièces (et elles seules) redeviennent « à bâtir », le projet repasse en réserve ;
    §3 mêmes pertes, ennemi persistant à portée : « autre site » (nouvelle centrale demandée), sites écartés = le lot perdu ET le danger
       (rayon DANGER + 16), l'ancien projet abandonné ; pas de pose sous le feu avant ;
    §4 centrale de remplacement refusée : retour au site d'origine, pièces rouvertes ;
    §5 poteau perdu entre la centrale et un consommateur : rouvert (îlot + poteau perdu), jamais avec un ennemi à 28 tuiles ;
    §6 déterminisme : deux jeux identiques, mêmes journaux.
  Usage : lua5.2 tests/reseau_vivant_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local oks, fails = 0, 0
local function check(cond, msg)
  if cond then oks = oks + 1 else fails = fails + 1; print("  ECHEC : " .. msg) end
end

---------------------------------------------------------------------------------------------------
-- Moteur simulé
---------------------------------------------------------------------------------------------------
local logs
log = function(s) logs[#logs + 1] = s end
defines = defines or {}
local PROTO = {
  ["small-electric-pole"] = { max_wire_distance = 7.5, supply_area_distance = 2.5 },
}
game = { entity_prototypes = PROTO, tick = 0 }

local World = {}
World.__index = World

local function new_world()
  local w = setmetatable({ ents = {}, enemies = {} }, World)
  return w
end

function World:add(e)
  e.valid = true
  e.destroy = e.destroy or function() e.valid = false end
  e.force = e.force or "fo-test"
  e.bounding_box = e.bounding_box or { left_top = { x = e.position.x - 0.5, y = e.position.y - 0.5 },
    right_bottom = { x = e.position.x + 0.5, y = e.position.y + 0.5 } }
  e.prototype = e.prototype or { electric_energy_source_prototype = e.consumer and {} or nil,
    max_wire_distance = PROTO[e.name] and PROTO[e.name].max_wire_distance,
    supply_area_distance = PROTO[e.name] and PROTO[e.name].supply_area_distance }
  self.ents[#self.ents + 1] = e
  return e
end

function World:remove(e) e.valid = false end

local function has_type(t, ty)
  if t == nil then return true end
  if type(t) == "string" then return t == ty end
  for _, x in ipairs(t) do if x == ty then return true end end
  return false
end

function World:surface()
  local w = self
  return {
    find_entities_filtered = function(q)
      local out = {}
      for _, e in ipairs(w.ents) do
        if e.valid and (q.force == nil or e.force == q.force) and has_type(q.type, e.type) then
          local ok = true
          if q.position then
            local dx, dy = e.position.x - (q.position[1] or q.position.x), e.position.y - (q.position[2] or q.position.y)
            ok = dx * dx + dy * dy <= (q.radius or 0) ^ 2 + 1e-9
          end
          if q.area then
            ok = ok and e.position.x >= q.area[1][1] and e.position.x <= q.area[2][1] and e.position.y >= q.area[1][2] and e.position.y <= q.area[2][2]
          end
          if ok then out[#out + 1] = e end
        end
      end
      return out
    end,
    can_place_entity = function(q)
      for _, e in ipairs(w.ents) do
        if e.valid and math.abs(e.position.x - q.position[1]) < 0.5 and math.abs(e.position.y - q.position[2]) < 0.5 then return false end
      end
      return true
    end,
    find_nearest_enemy = function(q)
      local px, py = q.position.x or q.position[1], q.position.y or q.position[2]
      for _, en in ipairs(w.enemies) do
        if en.valid and (px - en.position.x) ^ 2 + (py - en.position.y) ^ 2 <= q.max_distance ^ 2 then return en end
      end
      return nil
    end,
  }
end

local function entity(name, type_, x, y, o)
  o = o or {}
  local e = { name = name, type = type_, position = { x = x, y = y }, consumer = o.consumer, electric_network_id = o.net,
    energy_generated_last_tick = o.kw and (o.kw * 1000 / 60) or 0 }
  if type_ == "boiler" then
    e.burner = { remaining_burning_fuel = o.fuel or 1 }
    e.get_fuel_inventory = function() return { is_empty = function() return (o.fuel or 1) <= 0 end } end
  end
  return e
end

---------------------------------------------------------------------------------------------------
-- Plan directeur écrit à la main
---------------------------------------------------------------------------------------------------
local Rv = require("script.team.reseau_vivant")

--- Une équipe : centrale (projet 1, fini : chaudière, machine, pompe, poteau), un module (projet 2, fini : 2 poteaux).
local function team(world)
  local ents1 = {
    { name = "boiler", x = 10, y = 10, built = true }, { name = "steam-engine", x = 10, y = 2, built = true },
    { name = "offshore-pump", x = 10, y = 6, built = true }, { name = "small-electric-pole", x = 4, y = 0, built = true, role = "liaison" },
  }
  local ents2 = {
    { name = "small-electric-pole", x = 10, y = 0, built = true, role = "rue" },
    { name = "small-electric-pole", x = 13, y = 0, built = true, role = "rue" },
  }
  local f = { key = "test", force = "fo-test", build = { order = { 1, 2 }, plant = 1, opts = {}, occ = {}, projects = {
    [1] = { id = 1, state = "fini", ents = ents1, parts = { { ox = 8, oy = 4, w = 5, h = 14 } } },
    [2] = { id = 2, state = "fini", ents = ents2, parts = {} },
  } } }
  local boiler = world:add(entity("boiler", "boiler", 10, 10, { fuel = 1 }))
  local engine = world:add(entity("steam-engine", "generator", 10, 2, { net = 1, kw = 900 }))
  world:add(entity("offshore-pump", "offshore-pump", 10, 6))
  world:add(entity("small-electric-pole", "electric-pole", 4, 0, { net = 1 }))
  world:add(entity("small-electric-pole", "electric-pole", 10, 0, { net = 1 }))
  world:add(entity("small-electric-pole", "electric-pole", 13, 0, { net = 1 }))
  return f, { boiler = boiler, engine = engine }
end

local requested, cancelled

local api = {
  cancel = function(f, id, why) cancelled = { id = id, why = why }; f.build.projects[id].state = "refuse"; return true end,
  plant = function(f)
  local b = f.build
  local id = 3
  b.projects[id] = { id = id, state = "attente", ents = {}, parts = {} }
  b.order[#b.order + 1] = id
  b.plant = id
  requested = id
  return id
end }

--- Joue Rv.step toutes les 1 200 ticks de t0 à t1 inclus.
local function run(f, world, t0, t1)
  local s = world:surface()
  for t = t0, t1, 1200 do Rv.step(api, f, s, t) end
end

local function count(prefix)
  local n = 0
  for _, l in ipairs(logs) do if l:find(prefix, 1, true) then n = n + 1 end end
  return n
end

local function unbuilt(q)
  local n = 0
  for _, e in ipairs(q.ents) do if not e.built then n = n + 1 end end
  return n
end

---------------------------------------------------------------------------------------------------
-- §1 centrale saine ; interrupteur d'essai
---------------------------------------------------------------------------------------------------
do
  logs, requested = {}, nil
  local w = new_world()
  local f = team(w)
  run(f, w, 1200, 1200 * 12)
  check(f.build.projects[1].state == "fini" and unbuilt(f.build.projects[1]) == 0, "saine : projet de la centrale inchangé")
  check(count("rouvert") == 0 and requested == nil, "saine : aucune réouverture, aucune centrale demandée")

  logs = {}
  w = new_world()
  f = team(w)
  f.build.opts.sante = false
  w.ents[1].valid = false
  w.ents[2].valid = false
  run(f, w, 1200, 1200 * 12)
  check(unbuilt(f.build.projects[1]) == 0 and f.build.sante == nil, "interrupteur d'essai coupé : rien n'est lu ni rouvert")
end

---------------------------------------------------------------------------------------------------
-- §2 pièces perdues, site sûr
---------------------------------------------------------------------------------------------------
do
  logs, requested = {}, nil
  local w = new_world()
  local f, parts = team(w)
  run(f, w, 1200, 1200 * 3)
  w:remove(parts.boiler)
  w:remove(parts.engine)
  run(f, w, 1200 * 4, 1200 * 6)
  local q = f.build.projects[1]
  check(unbuilt(q) == 2, "site sur : exactement 2 pièces rouvertes (la chaudière et la machine) : " .. unbuilt(q))
  check(not q.ents[1].built and not q.ents[2].built and q.ents[3].built and q.ents[4].built, "site sur : la pompe et le poteau restent bâtis")
  check(q.state == "reserve", "site sur : le projet repasse en réserve (machinerie de pose habituelle) : " .. tostring(q.state))
  check(q.reopened == 1, "site sur : un seul comptage de réouverture")
  check(requested == nil, "site sur : pas de nouvelle centrale")
  -- tant que le projet est rouvert, la santé attend (centrale pas finie) et ne rouvre pas une seconde fois
  run(f, w, 1200 * 7, 1200 * 14)
  check(q.reopened == 1, "projet rouvert : pas de seconde réouverture pendant la reconstruction")
end

---------------------------------------------------------------------------------------------------
-- §3 pièces perdues, ennemi persistant : autre site
---------------------------------------------------------------------------------------------------
do
  logs, requested = {}, nil
  local w = new_world()
  local f, parts = team(w)
  run(f, w, 1200, 1200 * 3)
  w:remove(parts.boiler)
  w:remove(parts.engine)
  w.enemies[1] = { valid = true, position = { x = 40, y = 12 } } -- à 30 tuiles du site
  -- premier relevé avec l'ennemi : pas de pose sous le feu
  run(f, w, 1200 * 4, 1200 * 4)
  check(unbuilt(f.build.projects[1]) == 0 and requested == nil, "ennemi vu une fois : ni pose ni déménagement (pas encore jugé dangereux)")
  run(f, w, 1200 * 5, 1200 * 9)
  check(requested == 3 and f.build.plant == 3, "ennemi persistant : une centrale est demandée ailleurs (projet 3)")
  local av = f.build.avoid or {}
  local lot, danger
  for _, a in ipairs(av) do
    if a.r == Rv.LOT_AVOID_R then lot = a end
    if a.x == 40 and a.y == 12 then danger = a end
  end
  check(lot ~= nil and math.abs(lot.x - 10.5) < 1.1, "site écarté : le lot de la centrale perdue")
  check(danger ~= nil and danger.r == 40 + 16, "site écarté : le DANGER lui-même, rayon DANGER + 16")
  check(f.build.projects[1].abandoned == true, "l'ancien projet est abandonné")
  check(count("AILLEURS") == 1, "une seule décision « ailleurs » au journal")
  check(unbuilt(f.build.projects[1]) == 0, "l'ancien projet n'est pas rouvert")
  -- §4 la centrale de remplacement est refusée : retour au site d'origine
  f.build.projects[3].state = "refuse"
  f.build.projects[3].reason = "place"
  w.enemies[1].valid = false
  run(f, w, 1200 * 10, 1200 * 11)
  check(f.build.plant == 1 and f.build.avoid == nil, "remplacement refusé : retour à la centrale d'origine, sites écartés effacés")
  check(unbuilt(f.build.projects[1]) == 2 and f.build.projects[1].state == "reserve", "remplacement refusé : les 2 pièces perdues rouvertes sur place")
end

-- §4 bis centrale de remplacement en attente de matieres : gardee tant que le danger tient, abandonnee quand le site d'origine est calme
do
  logs, requested, cancelled = {}, nil, nil
  local w = new_world()
  local f, parts = team(w)
  run(f, w, 1200, 1200 * 3)
  w:remove(parts.boiler)
  w:remove(parts.engine)
  w.enemies[1] = { valid = true, position = { x = 40, y = 12 } }
  run(f, w, 1200 * 4, 1200 * 9)
  check(requested == 3 and f.build.projects[3].keep == true, "remplacement demande, marque a garder (l'automatisation ne l'annule pas)")
  run(f, w, 1200 * 10, 1200 * 30)
  check(f.build.plant == 3 and cancelled == nil, "ennemi toujours la : le remplacement est garde longtemps (pas de retour)")
  w.enemies[1].valid = false
  run(f, w, 1200 * 31, 1200 * 33)
  check(f.build.plant == 1 and cancelled ~= nil and cancelled.id == 3, "site d'origine calme, remplacement pas commence : annule, retour a la centrale d'origine")
  check(f.build.projects[3].abandoned == true and f.build.projects[1].abandoned == nil, "l'automatisation suit : remplacement abandonne, origine reprise")
  check(unbuilt(f.build.projects[1]) == 2 and f.build.projects[1].state == "reserve", "les pieces perdues de l'origine sont rouvertes")
end

---------------------------------------------------------------------------------------------------
-- §5 poteau perdu : relier
---------------------------------------------------------------------------------------------------
local function island_world(enemy)
  local w = new_world()
  local f = team(w)
  -- le poteau (10,0) est perdu : le consommateur en (12,0) est sur un autre réseau (id 2)
  for _, e in ipairs(w.ents) do
    if e.type == "electric-pole" and e.position.x == 10 then e.valid = false end
    if e.type == "electric-pole" and e.position.x == 13 then e.electric_network_id = 2 end
  end
  w:add(entity("assembling-machine-1", "assembling-machine", 12, 1.5, { net = 2, consumer = true }))
  if enemy then w.enemies[1] = { valid = true, position = { x = 20, y = 0 } } end
  return w, f
end

do
  logs = {}
  local w, f = island_world(false)
  run(f, w, 1200, 7200 + 1200 * 6)
  local q2 = f.build.projects[2]
  check(not q2.ents[1].built, "îlot : le poteau perdu (10,0) est rouvert")
  check(q2.ents[2].built, "îlot : le poteau intact (13,0) n'est pas touché")
  check(q2.state == "reserve" and q2.reopened == 1, "îlot : le projet du poteau repasse en réserve, une seule réouverture")
  check(count("[FO-RESEAU]") >= 1, "îlot : la décision est au journal")

  logs = {}
  w, f = island_world(true) -- ennemi à 10 tuiles du poteau perdu : pas de pose sous le feu
  run(f, w, 1200, 7200 + 1200 * 6)
  check(f.build.projects[2].ents[1].built == true and f.build.projects[2].state == "fini" and (f.build.projects[2].reopened or 0) == 0,
    "îlot + ennemi à 28 tuiles : poteau pas rouvert (pas de pose sous le feu)")
end

---------------------------------------------------------------------------------------------------
-- §6 déterminisme
---------------------------------------------------------------------------------------------------
do
  local function play()
    logs = {}
    local w, f = island_world(false)
    run(f, w, 1200, 7200 + 1200 * 12)
    return table.concat(logs, "\n")
  end
  local a, b = play(), play()
  check(a == b and #a > 0, "deux jeux identiques : mêmes journaux")
end

print(string.format("[RESEAU-VIVANT] BILAN : %d OK, %d ECHEC(S)", oks, fails))
os.exit(fails == 0 and 0 or 1)
