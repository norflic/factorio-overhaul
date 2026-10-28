--[[
  Lot RESEAU-VIVANT : test hors jeu du branchement (script/team/reseau_vivant.lua) sur un moteur simulé minimal :
    §1 centrale saine : aucune décision ; §2 chaudière détruite, site sûr : projet rouvert, pièce à bâtir ; §3 ennemis à portée
    du site : on attend, puis centrale demandée AILLEURS (site écarté, ancien projet abandonné) ; §4 remplacement refusé : retour
    sur place ; §5 consommateurs sur îlot + poteau perdu : le poteau du plan minimal est rouvert, pas ceux qui ne servent à rien ;
    §6 déterminisme (deux passes identiques, mêmes journaux).
  Usage : lua5.2 tests/reseau_vivant_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end

local LOG = {}
function log(s) LOG[#LOG + 1] = s end

local function box(x, y, w, h) return { left_top = { x = x - w / 2, y = y - h / 2 }, right_bottom = { x = x + w / 2, y = y + h / 2 } } end

game = { entity_prototypes = {
  ["medium-electric-pole"] = { max_wire_distance = 9, supply_area_distance = 3.5 },
  ["small-electric-pole"] = { max_wire_distance = 7.5, supply_area_distance = 2.5 },
} }

local Rv = require("script.team.reseau_vivant")

-- Moteur simulé ---------------------------------------------------------------------------------
local function new_world()
  local W = { ents = {}, enemy = nil }
  local un = 0
  function W.add(t)
    un = un + 1
    t.unit_number = un
    t.valid = true
    t.force = t.force or "f1"
    t.position = { x = t.x, y = t.y }
    t.bounding_box = t.bounding_box or box(t.x, t.y, t.w or 1, t.h or 1)
    t.prototype = t.prototype or {}
    W.ents[#W.ents + 1] = t
    return t
  end
  function W.kill(e) e.valid = false end
  local S = {}
  function S.find_entities_filtered(a)
    local types = a.type and (type(a.type) == "table" and a.type or { a.type })
    local out = {}
    for _, e in ipairs(W.ents) do
      if e.valid and (not a.force or e.force == a.force) then
        local okt = true
        if types then
          okt = false
          for _, t in ipairs(types) do if e.type == t then okt = true end end
        end
        if okt and a.position then
          local r = a.radius or 1
          okt = (e.x - a.position[1]) ^ 2 + (e.y - a.position[2]) ^ 2 <= r * r
        end
        if okt then out[#out + 1] = e end
      end
    end
    return out
  end
  function S.find_nearest_enemy(a)
    if W.enemy and (W.enemy.x - a.position.x) ^ 2 + (W.enemy.y - a.position.y) ^ 2 <= a.max_distance ^ 2 then return W.enemy end
    return nil
  end
  W.surface = S
  return W
end

local function plant_project(W, id)
  local ents = {}
  local function plan(name, x, y, role)
    local e = { name = name, x = x, y = y, built = true, role = role }
    ents[#ents + 1] = e
    return e
  end
  local p = { id = id, state = "fini", parts = { { ox = 100, oy = 100, w = 10, h = 8 } }, ents = ents, order = nil }
  p.boiler = plan("boiler", 100, 100)
  p.engine = plan("steam-engine", 104, 100)
  p.pump = plan("offshore-pump", 98, 100)
  p.pole = plan("medium-electric-pole", 102, 98)
  W.add({ type = "boiler", name = "boiler", x = 100, y = 100, get_fuel_inventory = function() return { is_empty = function() return false end } end,
    burner = { remaining_burning_fuel = 5 } })
  W.add({ type = "generator", name = "steam-engine", x = 104, y = 100, energy_generated_last_tick = 15000, electric_network_id = 1 })
  W.add({ type = "offshore-pump", name = "offshore-pump", x = 98, y = 100 })
  W.add({ type = "electric-pole", name = "medium-electric-pole", x = 102, y = 98, electric_network_id = 1 })
  return p
end

local function team(W)
  local p = plant_project(W, 1)
  local b = { projects = { [1] = p }, order = { 1 }, plant = 1, next_id = 2 }
  local f = { key = "azure", force = "f1", build = b }
  return f, b, p
end

local function tmpl_api(b)
  local calls = { plant = 0 }
  return { plant = function(f)
    calls.plant = calls.plant + 1
    local id = b.next_id
    b.next_id = id + 1
    b.projects[id] = { id = id, state = "attente", parts = {}, ents = {} }
    b.order[#b.order + 1] = id
    b.plant = id
    return id
  end }, calls
end

-- §1 saine
do
  LOG = {}
  local W = new_world()
  local f, b = team(W)
  local api, calls = tmpl_api(b)
  -- un consommateur alimenté pour avoir une demande
  b.projects[1].ents[#b.projects[1].ents + 1] = { name = "assembling-machine-1", x = 110, y = 100, built = true }
  for t = 1200, 1200 * 6, 1200 do Rv.step(api, f, W.surface, t) end
  check(calls.plant == 0, "saine : aucune centrale demandee")
  check(b.projects[1].state == "fini" and b.projects[1].reopened == nil, "saine : projet intact")
  check(b.sante and b.sante.healthy, "saine : etat sain lu")
end

-- §2 chaudière détruite, site sûr
do
  LOG = {}
  local W = new_world()
  local f, b, p = team(W)
  local api, calls = tmpl_api(b)
  for t = 1200, 1200 * 2, 1200 do Rv.step(api, f, W.surface, t) end
  W.kill(W.ents[1]) -- la chaudière
  Rv.step(api, f, W.surface, 1200 * 3)
  check(p.state == "reserve", "chaudiere detruite : projet rouvert (" .. tostring(p.state) .. ")")
  check(p.boiler.built == false, "chaudiere detruite : la piece est a rebatir")
  check(p.engine.built == true and p.pump.built == true, "chaudiere detruite : les pieces intactes ne sont pas touchees")
  check(p.reopened == 1, "chaudiere detruite : une reouverture")
  check(calls.plant == 0, "chaudiere detruite, site sur : pas d'autre centrale")
  local said = false
  for _, l in ipairs(LOG) do if l:find("[FO-RESEAU]", 1, true) and l:find("rouverte", 1, true) then said = true end end
  check(said, "chaudiere detruite : decision journalisee")
end

-- §3 ennemis à portée : on attend, puis ailleurs
do
  LOG = {}
  local W = new_world()
  local f, b, p = team(W)
  local api, calls = tmpl_api(b)
  for t = 1200, 1200 * 2, 1200 do Rv.step(api, f, W.surface, t) end
  W.kill(W.ents[1])
  W.enemy = { x = 110, y = 110 }
  local t = 1200 * 3
  Rv.step(api, f, W.surface, t)
  check(p.state == "fini" and calls.plant == 0, "ennemis a portee, premier releve : on attend, aucune pose")
  for _ = 1, 5 do t = t + 1200 Rv.step(api, f, W.surface, t) end
  check(calls.plant == 1, "ennemis a portee durablement : une centrale demandee ailleurs (" .. calls.plant .. ")")
  check(b.avoid and #b.avoid == 1 and b.avoid[1].r == 40, "le site dangereux est ecarte")
  check(p.abandoned == true and b.plant == 2, "l'ancien projet est abandonne, la nouvelle centrale est la centrale de l'equipe")
  check(b.sante.reloc and b.sante.reloc.new == 2, "le remplacement est suivi")
  check(p.state == "fini", "ancien projet non rouvert sous le feu")
  -- §4 le remplacement est refusé : retour sur place
  b.projects[2].state, b.projects[2].reason = "refuse", "pas de lot"
  W.enemy = nil
  t = t + 1200
  Rv.step(api, f, W.surface, t)
  check(b.plant == 1 and b.avoid == nil, "remplacement refuse : retour a l'ancienne centrale, site de nouveau permis")
  check(p.state == "fini" and p.boiler.built == true, "remplacement refuse, ennemis partis a l'instant : pas de reouverture dans la meme passe")
  check(b.sante.reloc == nil, "remplacement refuse : suivi termine")
  t = t + 1200
  Rv.step(api, f, W.surface, t)
  check(p.state == "reserve" and p.boiler.built == false, "ennemis partis : pieces perdues rouvertes sur place a la passe suivante")
  -- ennemis revenus : pas de nouvelle demande d'autre site avant la fin du blocage
  local calls_before = calls.plant
  W.enemy = { x = 110, y = 110 }
  p.state, p.boiler.built = "fini", true
  W.kill(W.ents[1])
  b.sante.st.seen, b.sante.st.relocations = 9, 1
  t = t + 1200
  Rv.step(api, f, W.surface, t)
  check(calls.plant == calls_before, "apres un refus du plan : pas de nouvelle demande pendant le blocage")
end

-- §5 îlot : le poteau du plan minimal est rouvert
do
  LOG = {}
  local W = new_world()
  local f, b, p = team(W)
  local api = tmpl_api(b)
  -- deux consommateurs hors du réseau de la centrale (réseau 2) ; poteau perdu 'utile' (entre) et poteau perdu 'inutile' (loin)
  W.add({ type = "assembling-machine", name = "assembling-machine-1", x = 120, y = 98, w = 3, h = 3, electric_network_id = 2,
    prototype = { electric_energy_source_prototype = {} } })
  W.add({ type = "electric-pole", name = "medium-electric-pole", x = 119, y = 96, electric_network_id = 2 })
  p.ents[#p.ents + 1] = { name = "medium-electric-pole", x = 110.5, y = 98.5, built = true, role = "rue" } -- perdu, utile
  p.ents[#p.ents + 1] = { name = "medium-electric-pole", x = 60.5, y = 98.5, built = true, role = "rue" }  -- perdu, inutile
  local t = 1200
  for _ = 1, 8 do Rv.step(api, f, W.surface, t) t = t + 1200 end
  local useful, useless = p.ents[#p.ents - 1], p.ents[#p.ents]
  check(useful.built == false, "ilot : le poteau perdu qui relie est rouvert")
  check(useless.built == true, "ilot : le poteau perdu qui ne sert a rien n'est PAS rouvert (pas de redondance)")
  check(p.reopened == 1 and p.state == "reserve", "ilot : projet rouvert une fois")
end

-- §6 déterminisme
do
  local function run()
    LOG = {}
    local W = new_world()
    local f, b = team(W)
    local api = tmpl_api(b)
    W.kill(W.ents[1])
    W.enemy = { x = 110, y = 110 }
    local t = 1200
    for _ = 1, 10 do Rv.step(api, f, W.surface, t) t = t + 1200 end
    return table.concat(LOG, "\n")
  end
  local a, c = run(), run()
  check(a == c and #a > 0, "determinisme : memes journaux")
end

print(string.format("[RESEAU-VIVANT] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
