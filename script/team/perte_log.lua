--[[
  Lot PERIMETRE2 (diagnostic, 4/11) : journal [FO-PERTE] en LECTURE SEULE (règle pure : shared/team/perte.lua ; critères :
  fo-logs/2026-11-04_PERIMETRE2/CRITERES.md). Aucune décision du mod ne lit ce module ni l'état f.perte.
    - on_entity_died : un bâtiment d'une équipe (votre équipe ou une faction) détruit par une force ennemie : une ligne (au plus PL.LINES
      par équipe) : catégorie, site, côté vu du QG, tueur, tourelles de l'équipe à portée (armées ou non), unités ennemies à 30 tuiles,
      mur à 12 tuiles, fer au stock, ce qui manquait ; cumul dans f.perte.agg.
    - PL.measure(f, tick) (appelé par Team.view) : toutes les PL.EVERY ticks (bornes de 5 min), couverture ARMÉE des points sensibles,
      tourelles isolées, murs, et le cumul des pertes.
  État f.perte = { agg, lines, next } (nombres, chaînes, tables simples ; créé dans un événement, jamais à on_load).
]]
local Events = require("script.core.events")
local State = require("script.faction.state")
local R = require("shared.ai3.reglages")
local T = require("shared.team.config")
local Pa = require("shared.team.perte")
local Stock = require("script.team.stock")
local Garde = require("script.team.garde_site") -- lot PERIMETRE2 : entités de la force « player » qui sont à votre équipe (Gd.team_owned)

local PL = {}

PL.LINES = 300     -- lignes de perte au plus par équipe
PL.MLINES = 200    -- lignes de relevé au plus par équipe
PL.EVERY = 18000   -- ticks : relevé (bornes de 5 min)

local RANGE = {} -- portée par nom de prototype (les prototypes ne changent pas en cours de partie)
local function range_of(name)
  local r = RANGE[name]
  if r == nil then
    local p = game.entity_prototypes[name]
    r = (p and p.turret_range) or 0
    RANGE[name] = r
  end
  return r
end

local SENS_TYPES
local function sens_types()
  if SENS_TYPES then return SENS_TYPES end
  SENS_TYPES = {}
  for _, ty in ipairs(R.ENTITY_TYPES) do
    if (Pa.ROLE_W[R.ENTITY_ROLE[ty]] or 0) > 0 then SENS_TYPES[#SENS_TYPES + 1] = ty end
  end
  return SENS_TYPES
end

local function team_of(force_name)
  if force_name == "player" then return State.faction("player") end
  return State.by_force(force_name)
end

local function state(f)
  local st = f.perte
  if not st then
    st = { lines = 0, mlines = 0, next = 0 }
    f.perte = st
  end
  return st
end

local function armed(t)
  if t.type ~= "ammo-turret" then return true end
  local inv = t.get_inventory(defines.inventory.turret_ammo)
  return inv ~= nil and inv.get_item_count() > 0
end

local function killer_of(e)
  local c = e.cause
  if not (c and c.valid) then return "?" end
  if c.force and c.force.name ~= "enemy" then return "faction" end
  if c.type == "turret" then return "ver" end
  if c.type == "unit" then
    local ok, ap = pcall(function() return c.prototype.attack_parameters end)
    local range = ok and ap and ap.range or 0
    return range >= 6 and "cracheur" or "mordeur"
  end
  return c.type
end

local function nearest_outpost(f, pos)
  local best, bid
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local o = f.outposts[oid]
    if o and o.pos then
      local d = (o.pos.x - pos.x) ^ 2 + (o.pos.y - pos.y) ^ 2
      if best == nil or d < best then best, bid = d, oid end
    end
  end
  return best and math.sqrt(best) or nil, bid
end

local function on_died(e)
  local ent, killer = e.entity, e.force
  if not (ent and ent.valid and ent.force and killer) then return end
  local force = ent.force
  if killer.name == force.name or force.get_cease_fire(killer) then return end
  local f = team_of(force.name)
  if not (f and f.hq_pos) or f.eliminated then return end
  local role = R.ENTITY_ROLE[ent.type]
  if role == "main" or ent.type == "character" or ent.type == "unit" or ent.type == "car" or ent.type == "spider-vehicle" then return end
  -- relecture du lead (point 7) : la force « player » est partagée avec le joueur : seules les pièces de votre équipe sont comptées
  if f.is_player and not Garde.team_owned(f, ent) then return end
  local is_hq = f.hq ~= nil and f.hq.valid and ent.unit_number ~= nil and f.hq.unit_number == ent.unit_number
  local cat = Pa.category(ent.type, role, is_hq)
  local pos, s = ent.position, ent.surface
  local dx, dy = pos.x - f.hq_pos.x, pos.y - f.hq_pos.y
  local dhq = math.sqrt(dx * dx + dy * dy)
  local dap, ap = nearest_outpost(f, pos)
  local nr, na = 0, 0
  for _, t in ipairs(s.find_entities_filtered({ position = pos, radius = 40, force = force, type = R.TURRET_TYPES })) do
    if t.valid and t ~= ent then
      local r = range_of(t.name)
      if (t.position.x - pos.x) ^ 2 + (t.position.y - pos.y) ^ 2 <= r * r then
        nr = nr + 1
        if armed(t) then na = na + 1 end
      end
    end
  end
  local units = 0
  for _, u in ipairs(s.find_entities_filtered({ position = pos, radius = Pa.WAVE_R, type = "unit" })) do
    if u.valid and u.force.name ~= force.name and not force.get_cease_fire(u.force) then units = units + 1 end
  end
  local wall = s.count_entities_filtered({ position = pos, radius = Pa.WALL_R, force = force, type = { "wall", "gate" }, limit = 1 }) > 0
  local okf, iron = pcall(Stock.count, f, T.outposts.iron.product)
  local rec = { cat = cat, site = Pa.site(dhq, dap, ap), side = Pa.side(dx, dy), killer = killer_of(e),
    lack = Pa.sensible(cat) and Pa.lack(nr, na, units) or nil, wall = wall }
  local st = state(f)
  st.agg = Pa.add(st.agg, rec)
  st.lines = st.lines + 1
  if st.lines <= PL.LINES then
    log(string.format("[FO-PERTE] %s minute %.1f | %s (%s) site %s cote %s a %.0f tuiles du QG | tueur %s | tourelles a portee %d dont armees %d | ennemis a %d tuiles %d | mur %s | fer %s | manque %s",
      f.key or "player", e.tick / 3600, ent.name, cat, rec.site, rec.side, dhq, rec.killer, nr, na, Pa.WAVE_R, units, wall and "oui" or "non",
      okf and tostring(iron) or "?", rec.lack or "-"))
  end
end
Events.on(defines.events.on_entity_died, on_died)

--- Relevé périodique (lecture seule), appelé à chaque pensée de l'équipe.
function PL.measure(f, tick)
  if f.eliminated or not (f.hq and f.hq.valid and f.hq_pos) then return end
  local st = state(f)
  if tick < st.next then return end
  st.next = (math.floor(tick / PL.EVERY) + 1) * PL.EVERY
  local h, d = f.hq_pos, Pa.MAX_DIST
  local area = { { h.x - d, h.y - d }, { h.x + d, h.y + d } }
  local s = f.hq.surface
  local pts = { { x = h.x, y = h.y, role = "qg" } }
  for _, e in ipairs(s.find_entities_filtered({ area = area, force = f.force, type = sens_types() })) do
    if e.valid then pts[#pts + 1] = { x = e.position.x, y = e.position.y, role = R.ENTITY_ROLE[e.type] } end
  end
  local tur, n_armed = {}, 0
  for _, t in ipairs(s.find_entities_filtered({ area = area, force = f.force, type = R.TURRET_TYPES })) do
    if t.valid then
      local a = armed(t)
      if a then n_armed = n_armed + 1 end
      tur[#tur + 1] = { x = t.position.x, y = t.position.y, range = range_of(t.name), armed = a }
    end
  end
  local walls = s.count_entities_filtered({ area = area, force = f.force, type = { "wall", "gate" } })
  local cov = Pa.coverage(pts, tur)
  st.mlines = st.mlines + 1
  if st.mlines <= PL.MLINES then
    log(string.format("[FO-PERTE] %s releve a %.1f min | couverture armee %d %% du poids (%d/%d), points %d dont couverts %d | tourelles %d dont armees %d, isolees %d | murs %d | pertes cumulees : %s",
      f.key or "player", tick / 3600, cov.w > 0 and math.floor(100 * cov.wc / cov.w + 0.5) or 100, cov.wc, cov.w, cov.n, cov.nc, #tur, n_armed,
      Pa.isolated(tur), walls, Pa.summary(st.agg)))
    if f.is_player and f.build then PL.plan_line(f, tick) end
  end
end

--- Lot PERIMETRE2 (G3, 5/11) : croissance du plan directeur de votre équipe, en LECTURE SEULE : rayon du treillis, lots (pris, libres,
--- écartés par le contour), projets finis et en cours, enceinte (segments finis, murs planifiés, complète), pierre, briques et murs au stock.
function PL.plan_line(f, tick)
  local b = f.build
  local used, free, out, total = 0, 0, 0, 0
  for _, k in ipairs(State.sorted_keys(b.lots or {})) do
    local l = b.lots[k]
    total = total + 1
    if l.used then used = used + 1 end
    if l.out then out = out + 1 end
    if not l.used and not l.out and (l.state == "libre" or l.state == "defricher") then free = free + 1 end
  end
  local active, ring = 0, "aucune"
  for _, pid in ipairs(b.order or {}) do
    local p = b.projects[pid]
    if p and p.state ~= "fini" and p.state ~= "refuse" then active = active + 1 end
  end
  if b.enc then
    local fin, w = 0, 0
    for _, sg in ipairs(b.enc.segs or {}) do
      local p = b.projects[sg.pid]
      if p and p.state == "fini" then fin = fin + 1 end
      w = w + (sg.n or 0)
    end
    ring = string.format("rayon %s, segments %d dont finis %d, murs demandes %d, complete %s", tostring(b.enc.r), #(b.enc.segs or {}), fin, w,
      tostring(b.enc.complete == true))
  end
  local stone = T.outposts.stone and T.outposts.stone.product
  local wall_item = T.wall
  local rec = game.recipe_prototypes[T.wall]
  local brick = rec and rec.ingredients[1] and rec.ingredients[1].name -- (briques : premier ingrédient du mur, lu dans les données)
  log(string.format("[FO-PERTE] %s plan a %.1f min | treillis rayon %s | lots %d : pris %d, libres %d, ecartes %d | projets finis %d, en cours %d | enceinte : %s | stock pierre %d, briques %d, murs %d",
    f.key or "player", tick / 3600, tostring(b.radius), total, used, free, out, b.stats and b.stats.projects_done or 0, active, ring,
    stone and Stock.count(f, stone) or 0, brick and Stock.count(f, brick) or 0, wall_item and Stock.count(f, wall_item) or 0))
end

return PL
