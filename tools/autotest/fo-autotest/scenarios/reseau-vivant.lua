--[[
  Lot RESEAU-VIVANT (29/10) : ÉVÉNEMENTS PROVOQUÉS sur la partie du guide (etape1-guide, 4 factions et votre équipe), jugés
  par tools/autotest/reseau_evenements.py (critères C2, C3, C4 de fo-logs/2026-10-29_NUIT/RESEAU/CRITERES.md).
  À la minute EV_MIN, parmi les équipes qui ont une centrale en marche (triées par clé, « player » compris), dans l'ordre :
    1re  « sur »     : chaudières ET machines à vapeur détruites (die), site sûr ;
    2e   « danger »  : idem, plus deux déchiqueteurs et un nid posés à 18 à 24 tuiles du site ;
    3e   « pivot »   : le poteau PIVOT du réseau (celui dont la perte éteint le plus de consommateurs, hors poteaux voisins de la
                       centrale) détruit ;
    4e   témoin      : rien.
  Relevés toutes les 20 s dès l'événement ([FO-RESEAU-BANC] « releve ») : pour chaque équipe, production, chaudières et machines
  présentes, consommateurs posés et sur le réseau d'une centrale, ennemis militaires à 28 tuiles du site, pièces de la
  centrale posées pendant qu'un ennemi est à 28 tuiles (« pose sous le feu »).
  Tout est lu au moteur ; rien n'est écrit dans le mod.
]]

local base = require("scenarios/etape1-guide")
local Z = require("scenarios/fonction_reseau")

local MIN = 3600
local EV_MIN = 30
local EV_TICK = EV_MIN * MIN
local STEP = 1200
local DANGER_R = 28
local TAG = "[FO-RESEAU-BANC] "
local ELEC = { "mining-drill", "assembling-machine", "lab", "inserter", "furnace" }

base.description = "RESEAU-VIVANT : partie du guide, centrales et poteau pivot detruits a " .. EV_MIN .. " min, releves toutes les 20 s"

local tick0 = base.tick
local state = { plan = nil }

local function teams()
  local out = {}
  for _, r in ipairs(remote.call("fo-ia1", "teams") or {}) do out[#out + 1] = { key = r.key, force = r.force } end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

local function plant_of(s, force)
  local boilers = s.find_entities_filtered({ force = force, type = "boiler" })
  local gens = s.find_entities_filtered({ force = force, type = "generator" })
  return boilers, gens
end

local function center(list)
  local x, y, n = 0, 0, 0
  for _, e in ipairs(list) do x, y, n = x + e.position.x, y + e.position.y, n + 1 end
  if n == 0 then return nil end
  return { x = x / n, y = y / n }
end

local function consumers(s, force)
  local out = {}
  for _, e in ipairs(s.find_entities_filtered({ force = force, type = ELEC })) do
    if e.prototype.electric_energy_source_prototype then out[#out + 1] = e end
  end
  return out
end

local function enemy_near(s, force, pos, r)
  return s.find_nearest_enemy({ position = pos, max_distance = r, force = force }) ~= nil
end

local function kill_plant(s, force)
  local n = 0
  local boilers, gens = plant_of(s, force)
  for _, e in ipairs(boilers) do if e.valid then e.die(); n = n + 1 end end
  for _, e in ipairs(gens) do if e.valid then e.die(); n = n + 1 end end
  return n
end

local function spawn_danger(s, pos)
  local made = {}
  local specs = { { "medium-worm-turret", 18, 0 }, { "medium-worm-turret", -18, 6 }, { "biter-spawner", 0, 22 } }
  for _, sp in ipairs(specs) do
    local want = { x = pos.x + sp[2], y = pos.y + sp[3] }
    local p = s.find_non_colliding_position(sp[1], want, 12, 1)
    if p then
      local e = s.create_entity({ name = sp[1], position = p, force = "enemy" })
      if e then made[#made + 1] = string.format("%s@%.0f,%.0f", sp[1], p.x, p.y) end
    end
  end
  return made
end

local function kill_pivot(s, force)
  local ents = s.find_entities_filtered({ force = force, type = "electric-pole" })
  table.sort(ents, function(a, b) return a.unit_number < b.unit_number end)
  local idx = {}
  for i, e in ipairs(ents) do idx[e.unit_number] = i end
  local poles = {}
  for i, e in ipairs(ents) do
    local nb = {}
    for _, o in ipairs((e.neighbours and e.neighbours.copper) or {}) do
      local j = o.valid and idx[o.unit_number]
      if j then nb[#nb + 1] = j end
    end
    table.sort(nb)
    poles[i] = { x = e.position.x, y = e.position.y, name = e.name, supply = e.prototype.supply_area_distance or 2.5, nb = nb }
  end
  local cons, prods = {}, {}
  for _, e in ipairs(consumers(s, force)) do
    local bb = e.bounding_box
    cons[#cons + 1] = { x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y }
  end
  local gens = s.find_entities_filtered({ force = force, type = "generator" })
  for _, e in ipairs(gens) do
    local bb = e.bounding_box
    prods[#prods + 1] = { x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y }
  end
  local R = Z.measure(poles, cons, prods)
  local c = center(gens)
  local best, bd = nil, 0
  for i, e in ipairs(ents) do
    local d = R.drop and R.drop[i] or 0
    local far = not c or (e.position.x - c.x) ^ 2 + (e.position.y - c.y) ^ 2 > 12 * 12
    if far and d > bd then best, bd = i, d end
  end
  if not best then return nil end
  local e = ents[best]
  local info = { x = e.position.x, y = e.position.y, drop = bd, comps = R.comps_gen, comp_id = e.electric_network_id }
  e.die()
  return info
end

local function release(s, force, row)
  -- relevé d'une équipe
  local boilers, gens = plant_of(s, force)
  local kw, gnets = 0, {}
  for _, g in ipairs(gens) do
    kw = kw + (g.energy_generated_last_tick or 0) * 60 / 1000
    if g.electric_network_id then gnets[g.electric_network_id] = true end
  end
  local pose, on, arms, arms_on = 0, 0, 0, 0
  for _, e in ipairs(consumers(s, force)) do
    pose = pose + 1
    local is_on = e.electric_network_id ~= nil and gnets[e.electric_network_id] == true
    if is_on then on = on + 1 end
    if e.type == "inserter" then
      arms = arms + 1
      if is_on then arms_on = arms_on + 1 end
    end
  end
  local site = center(boilers) or center(gens)
  local enemy = site and enemy_near(s, force, site, DANGER_R) or false
  local ghosts = 0
  if site then
    ghosts = s.count_entities_filtered({ position = site, radius = 40, force = force, type = "entity-ghost" })
  end
  local mid = state.plan and state.plan[row.key]
  log(TAG .. string.format("releve t=%d | %s | genre=%s kw=%.0f chaudieres=%d machines=%d conso_pose=%d conso_reseau=%d bras_pose=%d bras_reseau=%d"
    .. " ennemi28=%d fantomes40=%d site=%s", game.tick, row.key, mid or "-", kw, #boilers, #gens, pose, on, arms, arms_on, enemy and 1 or 0, ghosts,
    site and string.format("%.0f,%.0f", site.x, site.y) or "-"))
  return enemy
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  local s = ctx.surface()
  if e.tick == EV_TICK then
    local all = teams()
    local live = {}
    for _, t in ipairs(all) do
      local boilers, gens = plant_of(s, t.force)
      local kw = 0
      for _, g in ipairs(gens) do kw = kw + (g.energy_generated_last_tick or 0) end
      if #boilers > 0 and #gens > 0 then live[#live + 1] = t end
    end
    state.plan = {}
    local genres = { "sur", "danger", "pivot", "temoin" }
    for i, t in ipairs(live) do
      local genre = genres[i] or "temoin"
      state.plan[t.key] = genre
      local boilers, gens = plant_of(s, t.force)
      local site = center(boilers) or center(gens)
      if genre == "sur" then
        local n = kill_plant(s, t.force)
        log(TAG .. string.format("evenement t=%d | %s | genre=sur pieces_detruites=%d site=%.0f,%.0f", e.tick, t.key, n, site.x, site.y))
      elseif genre == "danger" then
        local n = kill_plant(s, t.force)
        local made = spawn_danger(s, site)
        log(TAG .. string.format("evenement t=%d | %s | genre=danger pieces_detruites=%d site=%.0f,%.0f ennemis=%s", e.tick, t.key, n, site.x,
          site.y, table.concat(made, ";")))
      elseif genre == "pivot" then
        local info = kill_pivot(s, t.force)
        if info then
          log(TAG .. string.format("evenement t=%d | %s | genre=pivot poteau=%.1f,%.1f eteint=%d reseau_avant=%s", e.tick, t.key, info.x, info.y,
            info.drop, tostring(info.comp_id)))
        else
          log(TAG .. string.format("evenement t=%d | %s | genre=pivot AUCUN poteau pivot trouve", e.tick, t.key))
          state.plan[t.key] = "pivot-vide"
        end
      else
        log(TAG .. string.format("evenement t=%d | %s | genre=temoin rien detruit", e.tick, t.key))
      end
    end
    log(TAG .. string.format("evenement t=%d | equipes avec centrale %d sur %d", e.tick, #live, #all))
  end
  if state.plan and e.tick >= EV_TICK and (e.tick - EV_TICK) % STEP == 0 then
    for _, t in ipairs(teams()) do
      if state.plan[t.key] then release(s, t.force, t) end
    end
  end
end

return base
