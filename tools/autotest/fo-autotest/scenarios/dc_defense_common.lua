-- Lot DEFENSE (retour du DC du 2/11, points 10 et 16 : « une quantite absolument faramineuse de tourelles autour du centre de commandement et pas du
-- tout autour de la ou ils se font attaquer » ; « ils defendent les gisements mais pas du tout la base, les assembleurs »).
-- MESURE seulement (aucune decision du mod n'en depend) : la partie de dc-croissance (3 factions, 30 ouvriers) jouee sans images, avec
--   * toutes les minutes, par equipe : tourelles au total, a moins de 15 tuiles du QG, a moins de 40 tuiles du QG, tourelles armees ;
--   * a chaque mort d'une piece de l'equipe tuee par l'ennemi : etait-elle a portee d'une tourelle vivante de l'equipe (portee lue au
--     prototype) ? Par nature de piece (batiment de production ou tourelle), et par VAGUE (une mort apres 30 s de calme en ouvre une).
-- Lancement : banc.py --qui DEFENSE -- 216000 dc-defense <source> ; lecture : tools/autotest/defense_mesures.py <archive>.
-- Journal : [FO-DEF-MESURE] (minute) et [FO-DEF-PERTE] (bilan final par equipe).
local NEAR_QG = 15
local FAR_QG = 40
local WAVE_GAP = 1800 -- ticks de calme qui separent deux vagues
local TURRET_TYPES = { "ammo-turret", "electric-turret", "fluid-turret" }
local PROD_TYPES = { ["assembling-machine"] = true, ["furnace"] = true, ["mining-drill"] = true, ["lab"] = true, ["boiler"] = true,
  ["generator"] = true, ["container"] = true, ["logistic-container"] = true }
local TURRET_SET = { ["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true }

return function(CHECK)
local base = require("scenarios/dc_evolution_common")(CHECK)

local function mes()
  global.defmes = global.defmes or { forces = {} }
  return global.defmes
end

local function row_of(force_name)
  local m = mes()
  local r = m.forces[force_name]
  if not r then
    r = { prod_dead = 0, prod_far = 0, tur_dead = 0, tur_far = 0, waves = 0, last = -1000000, wave_prod = 0, wave_tur = 0,
      worst_prod = 0, worst_tur = 0 }
    m.forces[force_name] = r
  end
  return r
end

--- Une tourelle vivante de la force couvre-t-elle (x, y) ? (portee lue au prototype de chaque tourelle ; la piece morte est exclue)
--- Rend aussi la distance a la tourelle vivante la plus proche (dans 80 tuiles ; nil au-dela), pour le journal de chaque perte.
local function covered(s, ent, force)
  local p = ent.position
  local ok, nearest = false, nil
  for _, t in ipairs(s.find_entities_filtered({ position = p, radius = 80, force = force, type = TURRET_TYPES })) do
    if t.valid and t ~= ent then
      local proto = game.entity_prototypes[t.name]
      local range = proto and proto.turret_range or 18
      local dx, dy = t.position.x - p.x, t.position.y - p.y
      local d2 = dx * dx + dy * dy
      if d2 <= range * range then ok = true end
      if not nearest or d2 < nearest then nearest = d2 end
    end
  end
  return ok, nearest and math.sqrt(nearest) or nil
end

local function hq_dist(s, ent)
  local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = ent.force, limit = 1 })[1]
  local q = hq and hq.valid and hq.position or game.forces.player.get_spawn_position(s)
  return math.sqrt((ent.position.x - q.x) ^ 2 + (ent.position.y - q.y) ^ 2)
end

script.on_event(defines.events.on_entity_died, function(e)
  local en = e.entity
  if not (en and en.valid and en.force) then return end
  local killer = e.force
  if not (killer and killer.name == "enemy") then return end
  local fname = en.force.name
  if fname ~= "player" and fname:sub(1, 3) ~= "fo-" then return end
  local is_tur = TURRET_SET[en.type] or false
  if not (is_tur or PROD_TYPES[en.type]) then return end
  local r = row_of(fname)
  if e.tick - r.last > WAVE_GAP then
    r.waves = r.waves + 1
    r.wave_prod, r.wave_tur = 0, 0
  end
  r.last = e.tick
  local cov, near = covered(en.surface, en, en.force)
  local out = not cov
  r.logs = (r.logs or 0) + 1
  if r.logs <= 120 then
    log(string.format("[FO-DEF-PIECE] minute %.1f | %s | %s (%s) en (%.0f, %.0f) a %.0f tuiles du QG | tourelle vivante la plus proche : %s | %s",
      e.tick / 3600, fname, en.name, en.type, en.position.x, en.position.y, hq_dist(en.surface, en),
      near and string.format("%.0f tuiles", near) or "aucune a 80 tuiles", out and "HORS PORTEE" or "a portee"))
  end
  if is_tur then
    r.tur_dead = r.tur_dead + 1
    r.wave_tur = r.wave_tur + 1
    if r.wave_tur > r.worst_tur then r.worst_tur = r.wave_tur end
  else
    r.prod_dead = r.prod_dead + 1
    r.wave_prod = r.wave_prod + 1
    if r.wave_prod > r.worst_prod then r.worst_prod = r.wave_prod end
    if out then r.prod_far = r.prod_far + 1 end
  end
end)

local function teams()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  return ok and rows or {}
end

local function hq_of(s, row)
  local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = row.force, limit = 1 })[1]
  if hq and hq.valid then return hq.position end
  return game.forces.player.get_spawn_position(s)
end

local function census(ctx, minute)
  local s = ctx.surface()
  for _, row in ipairs(teams()) do
    local q = hq_of(s, row)
    local total, near, far = 0, 0, 0
    local turrets = {}
    for _, t in ipairs(s.find_entities_filtered({ force = row.force, type = TURRET_TYPES })) do
      total = total + 1
      local dx, dy = t.position.x - q.x, t.position.y - q.y
      local d2 = dx * dx + dy * dy
      if d2 <= NEAR_QG * NEAR_QG then near = near + 1 end
      if d2 <= FAR_QG * FAR_QG then far = far + 1 end
      local proto = game.entity_prototypes[t.name]
      local range = proto and proto.turret_range or 18
      turrets[#turrets + 1] = { x = t.position.x, y = t.position.y, r2 = range * range }
    end
    -- Couverture STATIQUE : pieces de production (par type) a portee d'au moins une tourelle vivante de l'equipe.
    local prod, cov = 0, 0
    local by = {}
    for _, t in ipairs(s.find_entities_filtered({ force = row.force, type = { "assembling-machine", "furnace", "mining-drill", "lab" } })) do
      if t.valid then
        prod = prod + 1
        local ok = false
        for _, u in ipairs(turrets) do
          local dx, dy = u.x - t.position.x, u.y - t.position.y
          if dx * dx + dy * dy <= u.r2 then ok = true break end
        end
        if ok then cov = cov + 1 end
        local b = by[t.type] or { 0, 0 }
        by[t.type] = b
        b[1], b[2] = b[1] + 1, b[2] + (ok and 1 or 0)
      end
    end
    local a = by["assembling-machine"] or { 0, 0 }
    ctx.log(string.format("[FO-DEF-MESURE] minute %d | %s | tourelles=%d pres_qg15=%d pres_qg40=%d pieces_prod=%d couvertes=%d assembleurs=%d assembleurs_couverts=%d",
      minute, row.key, total, near, far, prod, cov, a[1], a[2]))
  end
end

local tick0, finish0 = base.tick, base.finish
base.description = "DEFENSE : partie de dc-croissance (3 factions, 30 ouvriers), mesure des tourelles et des pertes a portee de tourelle"
base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick > 0 and e.tick % 3600 == 0 and e.tick <= CHECK then census(ctx, math.floor(e.tick / 3600)) end
end
base.finish = function(ctx)
  finish0(ctx)
  local m = mes()
  local names = {}
  for k in pairs(m.forces) do names[#names + 1] = k end
  table.sort(names)
  local tp, tf, td, tw = 0, 0, 0, 0
  for _, k in ipairs(names) do
    local r = m.forces[k]
    tp, tf, td, tw = tp + r.prod_dead, tf + r.prod_far, td + r.tur_dead, tw + r.waves
    ctx.log(string.format("[FO-DEF-PERTE] %s | vagues=%d | pieces_prod_perdues=%d dont_hors_portee_de_tourelle=%d | tourelles_perdues=%d | pire_vague_prod=%d pire_vague_tourelles=%d",
      k, r.waves, r.prod_dead, r.prod_far, r.tur_dead, r.worst_prod, r.worst_tur))
  end
  local poi = ctx.call("points_of_interest")
  ctx.log(string.format("[FO-DEF-PERTE] TOTAL | vagues=%d | pieces_prod_perdues=%d dont_hors_portee=%d (%d%%) | tourelles_perdues=%d | pertes_prod_par_vague=%.1f | factions_vivantes=%d",
    tw, tp, tf, tp > 0 and math.floor(100 * tf / tp + 0.5) or 0, td, tw > 0 and tp / tw or 0, poi and #poi.factions or -1))
end
return base
end
