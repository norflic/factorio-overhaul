--[[
  Journal des mesures des factions (lot IA2-0) : lignes publiées pour l'outil hors jeu
  tools/autotest/ia2_mesures.py (métriques M1 forme des bases, M2 diversité, M3 capitalisation ; conception :
  fo-logs/2026-10-24_ANALYSE/IA_ADAPTATIVE.md §B10).

  Lignes (toutes en clair dans factorio-current.log, toujours publiées, partie normale comprise) :
    [FO-STRAT] fondation : une par faction au lancement de la guerre (ou à la migration d'une partie existante) :
               personnalité, origine du caractère, traits (pour mille), graine du flux de la faction ;
    [FO-STRAT] attaque   : une par groupe lancé : cible, effectif, rassemblement, point visé, distance, OCTANT
               d'arrivée vu du QG de la cible (0 = est, puis sens horaire à l'écran : 2 = sud, 4 = ouest, 6 = nord) ;
    [FO-STRAT] site      : un par site puisé dans la réserve de prospection : rang du site choisi par distance au QG
               parmi les sites valides de la même ressource en réserve (1 = le plus proche) ;
    [FO-SHAPE]           : toutes les 10 min (SHAPE_PERIOD) et par faction vivante, étalées (une faction par
               seconde) : bâtiments de la faction à moins de SHAPE_RADIUS tuiles du QG (types d'unités et de
               personnages exclus), chunks occupés, centre et covariance des positions RELATIVES au QG, rayon
               maximal, avant-postes (numéro d'ordre de construction, type, position relative) et nombre de
               bâtiments par nom.

  Rien ici ne décide : lectures seules (aucun tirage, aucune écriture dans `global`), le comportement des factions
  ne change pas. Coût : une recherche de zone par faction toutes les 10 min (voie mesurée « faction:shape »).
]]

local Events = require("script.core.events")
local Profiler = require("script.core.profiler")
local State = require("script.faction.state")

local Journal = {}

Journal.SHAPE_PERIOD = 36000 -- 10 min
Journal.SHAPE_RADIUS = 704   -- 22 chunks : la prospection élargie va jusqu'à 18 chunks du QG

-- Types qui ne sont pas des bâtiments (unités, personnages, véhicules, fantômes, effets).
local NOT_BUILDING = {
  ["unit"] = true, ["character"] = true, ["character-corpse"] = true, ["corpse"] = true, ["car"] = true,
  ["spider-vehicle"] = true, ["combat-robot"] = true, ["construction-robot"] = true, ["logistic-robot"] = true,
  ["projectile"] = true, ["stream"] = true, ["entity-ghost"] = true, ["tile-ghost"] = true,
  ["item-request-proxy"] = true, ["fire"] = true, ["sticker"] = true, ["flying-text"] = true,
  ["highlight-box"] = true, ["smoke-with-trigger"] = true, ["speech-bubble"] = true, ["item-entity"] = true,
}

-- tan(22,5°) = √2 − 1 : bornes des octants SANS trigonométrie (comparaisons de |dx| et |dy| seulement).
local TAN = 0.41421356

--- Octant d'un vecteur (0 à 7) : 0 = est, 1 = sud-est, 2 = sud, 3 = sud-ouest, 4 = ouest, 5 = nord-ouest,
--- 6 = nord, 7 = nord-est (y vers le bas, comme à l'écran). Vecteur nul : -1.
function Journal.octant(dx, dy)
  if dx == 0 and dy == 0 then return -1 end
  local ax, ay = math.abs(dx), math.abs(dy)
  if ay <= TAN * ax then return dx > 0 and 0 or 4 end
  if ax <= TAN * ay then return dy > 0 and 2 or 6 end
  if dx > 0 then return dy > 0 and 1 or 7 end
  return dy > 0 and 3 or 5
end

local function fmt_traits(traits, order)
  if not traits then return "-" end
  local parts = {}
  for _, k in ipairs(order) do parts[#parts + 1] = k .. "=" .. tostring(traits[k] or "?") end
  return table.concat(parts, " ")
end

--- Ligne de fondation d'une faction. `order` : liste des noms de traits (nil : aucun trait).
function Journal.foundation(f, tick, origin, order)
  log(string.format("[FO-STRAT] fondation tick %d %s : personnalite %s, origine %s, flux %s, traits %s",
    tick, f.key, tostring(f.personality), origin or "couleur", f.rng and tostring(f.rng.seed) or "-",
    fmt_traits(f.traits, order or {})))
end

--- Ligne d'un groupe lancé (appelée par script/faction/military.lua au départ du groupe).
function Journal.attack(f, target_faction, n, rp, tick)
  local hq = target_faction.hq_pos or rp.target
  local tx, ty = rp.target.x, rp.target.y
  local ox = rp.gather.x - hq.x
  local oy = rp.gather.y - hq.y
  local dx, dy = tx - rp.gather.x, ty - rp.gather.y
  log(string.format("[FO-STRAT] attaque tick %d %s -> %s : %d soldats, depart (%d, %d), vise (%d, %d), %d tuiles, octant %d, seuil %s",
    tick, f.key, target_faction.key, n, math.floor(rp.gather.x), math.floor(rp.gather.y), math.floor(tx), math.floor(ty),
    math.floor(math.sqrt(dx * dx + dy * dy)), Journal.octant(ox, oy), rp.threshold and tostring(rp.threshold) or "-"))
end

--- Ligne d'un site puisé dans la réserve : `site` choisi, `list` = réserve AVANT le retrait (sites valides de la
--- même ressource : `valid(site)` vrai).
function Journal.site(f, site, list, valid, tick)
  local hx, hy = f.hq_pos and f.hq_pos.x or 0, f.hq_pos and f.hq_pos.y or 0
  local function d2(p) return (p.x - hx) * (p.x - hx) + (p.y - hy) * (p.y - hy) end
  local mine = d2(site)
  local rank, n, nearest = 1, 0, mine
  for _, s in ipairs(list) do
    if s.resource == site.resource and valid(s) then
      n = n + 1
      local d = d2(s)
      if s ~= site and d < mine then rank = rank + 1 end
      if d < nearest then nearest = d end
    end
  end
  log(string.format("[FO-STRAT] site tick %d %s %s : (%d, %d), %d tuiles du QG, rang %d sur %d en reserve, plus proche %d tuiles",
    tick, f.key, tostring(site.resource), math.floor(site.x), math.floor(site.y), math.floor(math.sqrt(mine)), rank,
    math.max(n, 1), math.floor(math.sqrt(nearest))))
end

--- Ligne de forme d'une faction (lectures seules).
function Journal.shape(f, surface, tick)
  local hq = f.hq_pos
  local r = Journal.SHAPE_RADIUS
  local list = surface.find_entities_filtered({ area = { { hq.x - r, hq.y - r }, { hq.x + r, hq.y + r } }, force = f.force })
  local n, sx, sy, sxx, syy, sxy, rmax = 0, 0, 0, 0, 0, 0, 0
  local chunks, nchunks, names = {}, 0, {}
  for _, e in ipairs(list) do
    if e.valid and not NOT_BUILDING[e.type] then
      local p = e.position
      local dx, dy = p.x - hq.x, p.y - hq.y
      n = n + 1
      sx, sy = sx + dx, sy + dy
      sxx, syy, sxy = sxx + dx * dx, syy + dy * dy, sxy + dx * dy
      local d = dx * dx + dy * dy
      if d > rmax then rmax = d end
      local k = State.chunk_key(math.floor(p.x / 32), math.floor(p.y / 32))
      if not chunks[k] then
        chunks[k] = true
        nchunks = nchunks + 1
      end
      names[e.name] = (names[e.name] or 0) + 1
    end
  end
  local mx, my, cxx, cyy, cxy = 0, 0, 0, 0, 0
  if n > 0 then
    mx, my = sx / n, sy / n
    cxx, cyy, cxy = sxx / n - mx * mx, syy / n - my * my, sxy / n - mx * my
  end
  local ops = {}
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local o = f.outposts[oid]
    ops[#ops + 1] = string.format("%d:%s:%d:%d", oid, tostring(o.kind), math.floor(o.pos.x - hq.x), math.floor(o.pos.y - hq.y))
  end
  local ns = {}
  for _, k in ipairs(State.sorted_keys(names)) do ns[#ns + 1] = k .. "=" .. names[k] end
  log(string.format("[FO-SHAPE] tick %d %s : hq (%d, %d) | batiments %d | chunks %d | centre (%.1f, %.1f) | cov %.1f %.1f %.1f | rayon %d | avant-postes %s | noms %s",
    tick, f.key, math.floor(hq.x), math.floor(hq.y), n, nchunks, mx, my, cxx, cyy, cxy, math.floor(math.sqrt(rmax)),
    #ops > 0 and table.concat(ops, ",") or "-", #ns > 0 and table.concat(ns, ",") or "-"))
end

-- Une faction par seconde : la faction d'identifiant i au tick k × SHAPE_PERIOD + 60 × i (pics étalés).
Events.on_nth_tick(60, function(e)
  local phase = e.tick % Journal.SHAPE_PERIOD
  if phase == 0 or phase > 60 * 8 then return end
  local war = State.war()
  if not war.active then return end
  local f = war.factions[phase / 60]
  if not f or f.eliminated or not (f.hq_pos and f.hq and f.hq.valid) then return end
  local surface = game.surfaces[war.surface]
  if not surface then return end
  Profiler.start("faction:shape")
  Journal.shape(f, surface, e.tick)
  Profiler.stop("faction:shape")
end)

return Journal
