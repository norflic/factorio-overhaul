--[[
  Journal des mesures des factions (lot IA2-0) : lignes publiées pour l'outil hors jeu
  tools/autotest/ia2_mesures.py (métriques M1 forme des bases, M2 diversité, M3 capitalisation ; conception :
  fo-logs/2026-10-24_ANALYSE/IA_ADAPTATIVE.md §B10).

  Lignes (toutes en clair dans factorio-current.log, toujours publiées, partie normale comprise) :
    [FO-STRAT] fondation : une par faction au lancement de la guerre (ou à la migration d'une partie existante) :
               personnalité, origine du caractère, traits (pour mille), graine du flux de la faction ;
    [FO-STRAT] attaque   : une par groupe lancé : cible, effectif, rassemblement, point visé, distance, OCTANT
               d'arrivée vu du QG de la cible (0 = est, puis sens horaire à l'écran : 2 = sud, 4 = ouest, 6 = nord),
               multiplicateur du seuil (pour mille, « - » sans caractère tiré) ;
    [FO-STRAT] site      : un par site puisé dans la réserve de prospection : rang du site choisi par distance au QG
               parmi les sites valides de la même ressource en réserve (1 = le plus proche) ;
    [FO-SHAPE]           : à la 1re seconde puis toutes les 10 min (SHAPE_PERIOD), par faction vivante, étalées
               (une faction par seconde) : bâtiments de la faction (QG, tourelles, foreuses et réceptacles des
               avant-postes, fonderie : ses propres listes, Journal.buildings), chunks occupés, centre et covariance
               des positions RELATIVES au QG, rayon maximal, avant-postes (numéro d'ordre de construction, type,
               position relative) et nombre de bâtiments par nom.

  Rien ici ne décide : lectures seules (aucun tirage, aucune écriture dans `global`), le comportement des factions
  ne change pas. Coût mesuré sur la voie « faction:shape ». La 1re version (recherche de zone de 1 408 tuiles de
  côté, gardée en option : Journal.shape(..., true)) coûtait environ 7 ms par appel en moteur réel (E143).
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
--- Lot IA2-a : l'octant est celui du point d'ARRIVÉE, vu du QG de la cible : le rassemblement avancé choisi par le
--- chef quand il y en a un, sinon le départ (chemin direct, comme avant IA2-a). Champs ajoutés en fin de ligne
--- (la regex de tools/autotest/ia2_mesures.py lit le début inchangé) : rassemblement, règle, raid.
function Journal.attack(f, target_faction, n, rp, tick)
  local hq = target_faction.hq_pos or rp.target
  local tx, ty = rp.target.x, rp.target.y
  local from = rp.approach or rp.gather
  local ox = from.x - hq.x
  local oy = from.y - hq.y
  local dx, dy = tx - rp.gather.x, ty - rp.gather.y
  log(string.format("[FO-STRAT] attaque tick %d %s -> %s : %d soldats, depart (%d, %d), vise (%d, %d), %d tuiles, octant %d, seuil %s, rassemblement %s, regle %s%s",
    tick, f.key, target_faction.key, n, math.floor(rp.gather.x), math.floor(rp.gather.y), math.floor(tx), math.floor(ty),
    math.floor(math.sqrt(dx * dx + dy * dy)), Journal.octant(ox, oy), f.attack_jitter and tostring(f.attack_jitter) or "-",
    rp.approach and string.format("(%d, %d)", math.floor(rp.approach.x), math.floor(rp.approach.y)) or "-",
    rp.rule or (target_faction.id == "player" and "joueur" or "-"), rp.raid and ", raid" or ""))
end

--- Ligne d'un site puisé dans la réserve : `site` choisi, `list` = réserve AVANT le retrait (sites valides de la
--- même ressource : `valid(site)` vrai). Lot IA2-b : `extra` = { value, rank, n } (valeur du site choisi, son rang par
--- valeur parmi les n candidats valides) en fin de ligne ; plus `front` (clé du front qui l'a trouvé, ou « qg »).
function Journal.site(f, site, list, valid, tick, extra)
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
  local tail = ""
  if extra then
    tail = string.format(", valeur %d, rang valeur %d sur %d, richesse %d, front %s", extra.value or 0, extra.rank or 1,
      extra.n or 1, site.rich or -1, site.front or "qg")
  end
  log(string.format("[FO-STRAT] site tick %d %s %s : (%d, %d), %d tuiles du QG, rang %d sur %d en reserve, plus proche %d tuiles%s",
    tick, f.key, tostring(site.resource), math.floor(site.x), math.floor(site.y), math.floor(math.sqrt(mine)), rank,
    math.max(n, 1), math.floor(math.sqrt(nearest)), tail))
end

--- Bâtiments d'une faction, lus dans ses propres listes (QG, tourelles, foreuses et réceptacles des avant-postes,
--- fonderie) : aucune recherche moteur. Mesuré (E143) : la recherche de zone de 1 408 × 1 408 tuiles coûtait environ
--- 7 ms par faction et par appel, en un seul tick.
function Journal.buildings(f)
  local list = {}
  if f.hq and f.hq.valid then list[#list + 1] = f.hq end
  for _, id in ipairs(State.sorted_keys(f.turrets or {})) do list[#list + 1] = f.turrets[id] end
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local o = f.outposts[oid]
    for _, e in ipairs(o.drill_list or {}) do list[#list + 1] = e end
    for _, e in ipairs(o.sinks or {}) do list[#list + 1] = e end
  end
  for _, e in ipairs(f.smelters or {}) do list[#list + 1] = e end
  -- Lot IA-V2 : laboratoires du QG posés par le cerveau par besoins (lot IA3-c, f.team.ia3.labs).
  local ia3 = f.team and f.team.ia3
  for _, e in ipairs(ia3 and ia3.labs or {}) do list[#list + 1] = e end
  -- Lot IA2-b (F209) : réceptacles orphelins des avant-postes perdus (coffres et fours restés sur la carte).
  for _, o in ipairs(f.orphans or {}) do
    if o.e and o.e.valid then list[#list + 1] = o.e end
  end
  return list
end

--- Ligne de forme d'une faction (lectures seules). `area` vrai : recherche de zone (contrôle de l'énumération).
function Journal.shape(f, surface, tick, area)
  local hq = f.hq_pos
  local r = Journal.SHAPE_RADIUS
  local list
  if area then
    list = surface.find_entities_filtered({ area = { { hq.x - r, hq.y - r }, { hq.x + r, hq.y + r } }, force = f.force })
  else
    list = Journal.buildings(f)
  end
  local n, sx, sy, sxx, syy, sxy, rmax = 0, 0, 0, 0, 0, 0, 0
  local chunks, nchunks, names = {}, 0, {}
  local hcx, hcy = math.floor(hq.x / 32), math.floor(hq.y / 32)
  local cells = {} -- lot IA2-b : chunks occupés, relatifs au chunk du QG (« dx:dy »), triés
  for _, e in ipairs(list) do
    if e.valid and not NOT_BUILDING[e.type] then
      local p = e.position
      local dx, dy = p.x - hq.x, p.y - hq.y
      n = n + 1
      sx, sy = sx + dx, sy + dy
      sxx, syy, sxy = sxx + dx * dx, syy + dy * dy, sxy + dx * dy
      local d = dx * dx + dy * dy
      if d > rmax then rmax = d end
      local pcx, pcy = math.floor(p.x / 32), math.floor(p.y / 32)
      local k = State.chunk_key(pcx, pcy)
      if not chunks[k] then
        chunks[k] = true
        nchunks = nchunks + 1
        cells[#cells + 1] = { pcx - hcx, pcy - hcy }
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
  local orphans = 0
  for _, o in ipairs(f.orphans or {}) do if o.e and o.e.valid then orphans = orphans + 1 end end
  table.sort(cells, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
  for i, c in ipairs(cells) do cells[i] = c[1] .. ":" .. c[2] end
  log(string.format("[FO-SHAPE] tick %d %s : hq (%d, %d) | batiments %d | chunks %d | centre (%.1f, %.1f) | cov %.1f %.1f %.1f | rayon %d | avant-postes %s | noms %s | cases %s | orphelins %d",
    tick, f.key, math.floor(hq.x), math.floor(hq.y), n, nchunks, mx, my, cxx, cyy, cxy, math.floor(math.sqrt(rmax)),
    #ops > 0 and table.concat(ops, ",") or "-", #ns > 0 and table.concat(ns, ",") or "-",
    #cells > 0 and table.concat(cells, ",") or "-", orphans))
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
