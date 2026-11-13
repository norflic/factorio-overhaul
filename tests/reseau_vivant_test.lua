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
-- Lot TESTS-VERTS : script/team/zone_equipe.lua (UPS-HYGIENE, a9010348) requiert script/team/boite_chunks.lua, abonné à
-- defines.events.on_chunk_generated au chargement (POULS, c03b7f67).
defines = defines or {}
defines.events = defines.events or { on_chunk_generated = 34 }
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
  check(f.build.sante.healthy == true, "saine : sante.healthy vrai (produit 900 kW)")

  -- lot CHAMP-COURANT : aucune demande, production 0 kW : saine (sinon le champ électrique, power_ok, ne part jamais) ; chaudière à sec : non
  logs = {}
  w = new_world()
  local f0, ent0 = team(w)
  ent0.engine.energy_generated_last_tick = 0
  run(f0, w, 1200, 1200 * 3)
  check(f0.build.sante.healthy == true, "production 0 kW sans consommateur : centrale saine (champ-courant)")
  w = new_world()
  local f1, ent1 = team(w)
  ent1.engine.energy_generated_last_tick = 0
  ent1.boiler.burner.remaining_burning_fuel = 0
  ent1.boiler.get_fuel_inventory = function() return { is_empty = function() return true end } end
  run(f1, w, 1200, 1200 * 3)
  check(f1.build.sante.healthy == false, "production 0 kW, chaudière à sec : pas saine")

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
  check(q.counted == true, "site sur : le projet rouvert est marqué compté (pas de double compte aux statistiques au « fini » suivant)")
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

-- §5 ter lot ENERGIE (2/11) : ligne de 4 poteaux perdus entre la centrale et un ilot, plus une branche perdue qui ne mene nulle part :
-- le chemin le plus court est rouvert d'abord (la branche attend) ; un ennemi sur la ligne : rien n'est rouvert, second chemin annonce ;
-- interrupteur no_coupure : la regle d'avant (tout ce qu'aucun ennemi ne tient)
local function ligne_world(enemy)
  local w = new_world()
  local f = team(w)
  local ents = {}
  for _, x in ipairs({ 11, 18, 25, 32 }) do ents[#ents + 1] = { name = "small-electric-pole", x = x, y = 0, built = true, role = "rue" } end
  ents[#ents + 1] = { name = "small-electric-pole", x = 6, y = -6, built = true, role = "rue" } -- branche perdue hors chemin
  ents[#ents + 1] = { name = "small-electric-pole", x = 39, y = 0, built = true, role = "rue" }
  f.build.projects[2] = { id = 2, state = "fini", ents = ents, parts = {} }
  for _, e in ipairs(w.ents) do
    if e.type == "electric-pole" and (e.position.x == 10 or e.position.x == 13) then e.valid = false end
  end
  w:add(entity("small-electric-pole", "electric-pole", 39, 0, { net = 2 }))
  w:add(entity("assembling-machine-1", "assembling-machine", 40, 1.5, { net = 2, consumer = true }))
  if enemy then w.enemies[1] = { valid = true, position = { x = 24, y = 8 } } end
  return w, f
end

do
  logs = {}
  local w, f = ligne_world(false)
  run(f, w, 1200, 7200 + 1200 * 6)
  local q2 = f.build.projects[2]
  local rouverts = ""
  for i = 1, 4 do rouverts = rouverts .. (q2.ents[i].built and "." or "X") end
  check(rouverts == "XXXX", "ligne : les 4 poteaux du chemin le plus court sont rouverts (" .. rouverts .. ")")
  check(q2.ents[5].built == true, "ligne : la branche perdue hors chemin attend")
  check(count("coupure: ") >= 1 and count("chemin le plus court") >= 1, "ligne : la decision est au journal")

  logs = {}
  w, f = ligne_world(true)
  run(f, w, 1200, 7200 + 1200 * 6)
  q2 = f.build.projects[2]
  check(q2.ents[1].built and q2.ents[2].built and q2.ents[3].built and q2.ents[4].built, "ligne + ennemi : aucun poteau du chemin tenu n'est rouvert")
  check(count("sans chemin sur") >= 1, "ligne + ennemi : le second chemin est annonce")
  check(f.build.sante.second_tick ~= nil, "ligne + ennemi : l'annonce du second chemin est posee pour le raccordement")

  -- un poteau perdu LOIN de l'ennemi mais qui ne relie rien : avec un ilot sans chemin sur, il n'est pas rouvert (il retiendrait la centrale en chantier)
  logs = {}
  w, f = ligne_world(true)
  table.insert(f.build.projects[2].ents, { name = "small-electric-pole", x = -30, y = 0, built = true, role = "rue" })
  run(f, w, 1200, 7200 + 1200 * 6)
  check(f.build.projects[2].ents[7].built == true and f.build.projects[2].state == "fini", "ligne + ennemi : le poteau perdu loin de l'ennemi n'est pas rouvert pour rien")

  logs = {}
  w, f = ligne_world(false)
  f.build.opts.no_coupure = true
  run(f, w, 1200, 7200 + 1200 * 6)
  q2 = f.build.projects[2]
  check(not q2.ents[5].built and not q2.ents[1].built, "no_coupure : la regle d'avant rouvre tout, branche comprise")
  check(f.build.sante.second_tick == nil, "no_coupure : aucune annonce de second chemin")
  check(count("coupure: ") == 0, "no_coupure : rien de la coupure au journal")

  -- un poteau deja rouvert (en reconstruction) garde le chemin continu : le releve suivant ne rouvre pas la branche
  logs = {}
  w, f = ligne_world(false)
  run(f, w, 1200, 7200 + 1200 * 2)
  local before = 0
  for _, e in ipairs(f.build.projects[2].ents) do if e.built then before = before + 1 end end
  f.build.sante.idle_until = nil
  run(f, w, 7200 + 1200 * 3, 7200 + 1200 * 12)
  check(f.build.projects[2].ents[5].built == true, "reconstruction en cours : la branche hors chemin n'est toujours pas rouverte")
end

-- §5 bis plafond de réouvertures des poteaux : propre aux poteaux (la centrale rouverte n'en use pas), et jamais pour une centrale abandonnée
do
  logs = {}
  local w, f = island_world(false)
  f.build.projects[2].reopened = 5 -- reposes de la centrale / autres réouvertures : ne comptent pas pour les poteaux
  run(f, w, 1200, 7200 + 1200 * 6)
  check(not f.build.projects[2].ents[1].built, "plafond : 5 réouvertures d'un autre genre n'empêchent pas la réouverture d'un poteau perdu")

  logs = {}
  w, f = island_world(false)
  f.build.projects[2].poles_reopened = Rv.POLE_REOPEN_MAX
  run(f, w, 1200, 7200 + 1200 * 6)
  check(f.build.projects[2].ents[1].built == true and f.build.projects[2].state == "fini", "plafond : poteaux déjà rouverts au plafond : plus de réouverture")

  logs = {}
  w, f = island_world(false)
  f.build.projects[2].abandoned = true -- projet d'une centrale quittée : on n'y dépense plus de matières
  run(f, w, 1200, 7200 + 1200 * 6)
  check(f.build.projects[2].ents[1].built == true, "projet abandonné : ses poteaux perdus ne sont pas rouverts")
end

-- §3 bis un danger vu une fois puis parti ne reste pas dans les sites écartés d'une décision prise sur des pertes seules
do
  logs, requested = {}, nil
  local w = new_world()
  local f, parts = team(w)
  run(f, w, 1200, 1200 * 3)
  w.enemies[1] = { valid = true, position = { x = 40, y = 12 } }
  run(f, w, 1200 * 4, 1200 * 5) -- vu 2 fois, puis parti
  w.enemies[1].valid = false
  f.build.sante.st.site_losses = 2 -- pertes répétées sur le site
  w:remove(parts.boiler)
  w:remove(parts.engine)
  run(f, w, 1200 * 6, 1200 * 8)
  local only_lot = f.build.avoid ~= nil
  for _, a in ipairs(f.build.avoid or {}) do if a.r ~= Rv.LOT_AVOID_R then only_lot = false end end
  check(requested == 3 and only_lot, "pertes seules : seul le lot perdu est écarté (pas de position d'ennemi périmée)")
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

-- lot COURANT2 : chaine statique, le releve des ilots n'exempte que les projets dont le chantier avance (S.exempts)
do
  local fh = io.open("script/team/reseau_vivant.lua", "r"); local src = fh:read("*a"); fh:close()
  check(src:find("S.exempts(q.state, q.retry_at)", 1, true) ~= nil, "COURANT2 : in_construction passe par S.exempts")
  check(src:find('if q and q.state ~= "fini" and q.state ~= "refuse" then', 1, true) == nil, "COURANT2 : plus d'exemption de tout projet non fini")
end

-- s40 : le plafond des réouvertures de poteaux borne un incident : un réseau relu sain remet le compte à zéro
do
  logs = {}
  local w = new_world()
  local f = team(w)
  for _, pid in ipairs(f.build.order) do f.build.projects[pid].poles_reopened = Rv.POLE_REOPEN_MAX end
  run(f, w, 1200, 7200 + 1200 * 6)
  local left = 0
  for _, pid in ipairs(f.build.order) do if f.build.projects[pid].poles_reopened then left = left + 1 end end
  check(f.build.sante.islands + f.build.sante.uncovered == 0 and left == 0, "s40 : réseau sain : le compte des réouvertures de poteaux repart de zéro")
  local w2, f2 = island_world(true) -- îlot tenu par l'ennemi : le réseau n'est pas rétabli, le plafond tient
  f2.build.projects[2].poles_reopened = Rv.POLE_REOPEN_MAX
  run(f2, w2, 1200, 7200 + 1200 * 6)
  check(f2.build.projects[2].poles_reopened == Rv.POLE_REOPEN_MAX, "s40 : réseau coupé : le plafond des poteaux n'est pas remis à zéro")
end

print(string.format("[RESEAU-VIVANT] BILAN : %d OK, %d ECHEC(S)", oks, fails))
os.exit(fails == 0 and 0 or 1)
