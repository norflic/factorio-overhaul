--[[
  CENTRALE LOINTAINE, partie moteur (lot PD-CENTRALE, décision du DC D-24 (1) : l'étang garanti est SUPPRIMÉ ; « si l'eau
  n'est pas utilisable, il faut aller plus loin […] centrale plus loin »). Règles pures : shared/team/centrale_loin.lua.

  Appelé par script/team/build.lua (plan_project) quand aucun lot du treillis ne tient la centrale à vapeur et que le treillis
  ne peut plus grandir :
    Far.place(f, surface, g, ctx)  cherche l'eau la plus proche hors du treillis et y essaie le gabarit (Cl.WINDOW autour de
                                   chaque rive) ; rend le placement (mêmes champs que place_module, sans lot, plus `far`), ou
                                   nil, raison, "loin" (recherche en cours : passe suivante sous Cl.RETRY ticks), ou nil,
                                   raison (aucune eau atteignable : la centrale est refusée comme avant, et redemandée par le
                                   prochain module électrique).
    Far.line(...)                  ligne de poteaux de la centrale au carrefour de bord du treillis (recherche de chemin,
                                   shared/team/poteaux.lua), terrain lu chunk par chunk au moteur ; points d'appui posés.
    Far.reject(f, p, why)          rive écartée (pompe refusée au moteur).

  Où est l'eau : les secteurs où l'équipe en a VU (carte de connaissance d'une faction, f.ai3f.m, s.w ; aucun regard
  omniscient), sans nid connu au secteur ni sur le chemin ; sans carte (votre équipe, brouillard coupé), les secteurs générés
  autour du QG, sondés au plus Cl.PROBES_PER_PASS par passe (réponse gardée dans b.far.w).

  Sans eau VUE qui tienne la centrale (carte de connaissance), l'équipe demande une exploration de l'eau (Cl.EXPLORE_TAG, par
  le crochet Far.hooks.request) et relit sa carte toutes les Cl.EXPLORE_POLL ticks, au plus Cl.EXPLORE_WAIT par recherche.

  État (dans f.build, donc dans global, créé à la première recherche, en événement) : b.far = { bad = { [rive] = true },
  done = { [secteur] = true }, w = { [secteur] = bool }, logs, searching, explore }. Une sauvegarde d'avant le lot n'en a pas : il
  est créé au premier besoin. Le champ b.pond des sauvegardes 0.6.18 n'est plus lu (l'étang déjà posé reste de l'eau).
]]

local P = require("shared.team.plan")
local M = require("shared.team.modules")
local Q = require("shared.team.poteaux")
local Cl = require("shared.team.centrale_loin")
local K = require("shared.ai3.carte")

local Far = {}

-- Crochets posés au chargement par script/ai3/exploration.lua (qui charge déjà ce module par worker → build : un require dans
-- l'autre sens ferait une boucle) : request(f, tag, tick, why), cancel(f, tag, tick). Absents : pas d'exploration demandée.
Far.hooks = {}

local floor, sqrt = math.floor, math.sqrt

local function sorted_keys(t)
  local out = {}
  for k in pairs(t or {}) do out[#out + 1] = k end
  table.sort(out, function(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta < tb end
    return a < b
  end)
  return out
end

local function state(b)
  local s = b.far
  if not s then
    s = { bad = {}, done = {}, w = {}, logs = 0 }
    b.far = s
  end
  return s
end

local function say(f, text)
  local s = state(f.build)
  s.logs = (s.logs or 0) + 1
  if s.logs <= Cl.LOGS then log(Cl.line(f.key or "player", text)) end
end

local function sector_generated(surface, sx, sy)
  for dy = 0, 1 do
    for dx = 0, 1 do
      if not surface.is_chunk_generated({ x = sx * 2 + dx, y = sy * 2 + dy }) then return false end
    end
  end
  return true
end

--- Secteurs d'eau candidats : liste { key, x, y }, source, sondages faits, sondage inachevé.
local function sector_list(f, surface, hq, tick)
  local s = state(f.build)
  local k = f.ai3f
  local out = {}
  if k and k.m and k.m.s then
    for _, key in ipairs(sorted_keys(k.m.s)) do
      local sec = k.m.s[key]
      if sec.w and not s.done[key] then
        local cx, cy = K.center(K.xy(key))
        if K.sector_risk(k.m, key, tick, nil) < K.DANGER.skip and K.path_clear(k.m, hq, { x = cx, y = cy }) then
          out[#out + 1] = { key = key, x = cx, y = cy }
        end
      end
    end
    return out, "carte", 0, false
  end
  local R = math.ceil(Cl.MAX_DIST / Cl.SECTOR)
  local hsx, hsy = floor(hq.x / Cl.SECTOR), floor(hq.y / Cl.SECTOR)
  local all = {}
  for sy = hsy - R, hsy + R do
    for sx = hsx - R, hsx + R do
      local cx, cy = K.center(sx, sy)
      all[#all + 1] = { key = K.key(sx, sy), x = cx, y = cy }
    end
  end
  local probes, pending = 0, false
  for _, c in ipairs(Cl.order_sectors(all, hq, s.done)) do
    local w = s.w[c.key]
    if w == nil then
      local sx, sy = K.xy(c.key)
      if sector_generated(surface, sx, sy) then
        if probes >= Cl.PROBES_PER_PASS then pending = true break end
        probes = probes + 1
        local x0, y0 = sx * Cl.SECTOR, sy * Cl.SECTOR
        w = surface.count_tiles_filtered({ area = { { x0, y0 }, { x0 + Cl.SECTOR, y0 + Cl.SECTOR } }, collision_mask = "water-tile",
          limit = 1 }) > 0
        s.w[c.key] = w
      end
    end
    if w then out[#out + 1] = c end
  end
  return out, "sondage", probes, pending
end

--- Placement de la centrale hors du treillis. ctx = { read_masks = fonction de build.lua, tick, why = raison du refus dans le
--- treillis, avoid_margin, p = projet (son délai d'attente far_poll est posé pendant l'exploration) }.
function Far.place(f, surface, g, ctx)
  local b = f.build
  local s = state(b)
  local hq = { x = b.lat.ox, y = b.lat.oy }
  local x0, y0 = P.lot_rect(b.lat, -b.radius, -b.radius)
  local _, _, x1, y1 = P.lot_rect(b.lat, b.radius, b.radius)
  local ext = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  local list, source, probes, pending = sector_list(f, surface, hq, ctx.tick)
  local cands = Cl.order_sectors(list, hq, s.done)
  if not s.searching then
    s.searching = ctx.tick
    say(f, string.format("aucun lot du treillis (rayon %d) ne tient la centrale (%s) : recherche de l'eau hors du treillis a %.1f min (source %s, %d secteur(s) d'eau candidat(s)%s)",
      b.radius, tostring(ctx.why), ctx.tick / 3600, source, #cands, pending and ", sondage en cours" or ""))
  end
  local fits, reads = 0, 0
  for _, c in ipairs(cands) do
    if reads >= Cl.SECTORS_PER_PASS or fits >= Cl.FITS_PER_PASS then pending = true break end
    reads = reads + 1
    local sx, sy = K.xy(c.key)
    local mg = Cl.SECTOR_MARGIN
    local area = { x0 = sx * Cl.SECTOR - mg, y0 = sy * Cl.SECTOR - mg, x1 = (sx + 1) * Cl.SECTOR + mg, y1 = (sy + 1) * Cl.SECTOR + mg }
    local water = {}
    for _, t in ipairs(surface.find_tiles_filtered({ area = { { area.x0, area.y0 }, { area.x1, area.y1 } }, collision_mask = "water-tile" })) do
      water[P.tkey(floor(t.position.x), floor(t.position.y))] = true
    end
    local shores = Cl.shores(function(tx, ty) return water[P.tkey(tx, ty)] == true end, area, hq, {
      -- (b.avoid : sites de centrale jugés dangereux par script/team/reseau_vivant.lua, comme pour les lots, Build.AVOID_MARGIN)
      keep = function(tx, ty)
        return Cl.outside(ext, tx, ty) and not s.bad[Cl.shore_key(tx, ty)] and not Cl.avoided(b.avoid, tx, ty, ctx.avoid_margin)
      end })
    local all_failed = true
    for _, sh in ipairs(shores) do
      if fits >= Cl.FITS_PER_PASS then all_failed = false pending = true break end
      fits = fits + 1
      local rect = Cl.window(sh.x, sh.y)
      local masks = ctx.read_masks(f, surface, rect.x0, rect.y0, rect.x1, rect.y1)
      local fit = P.fit(g, rect, { free = masks.free, toward = hq, margin = 0, water = masks.water })
      if fit then
        local r = fit.k == 0 and g or M.rotate(g, fit.k)
        local inst = M.instantiate(r, 0, fit.ox, fit.oy)
        local d = sqrt((sh.x + 0.5 - hq.x) ^ 2 + (sh.y + 0.5 - hq.y) ^ 2)
        say(f, string.format("centrale posee a la rive (%d, %d) du secteur (%d, %d), a %.0f tuiles du QG, gabarit en (%d, %d) rotation %d (%d rive(s) ecartee(s) avant)",
          sh.x, sh.y, sx, sy, d, fit.ox, fit.oy, fit.k, #sorted_keys(s.bad)))
        s.searching = nil
        Far.stop_explore(f, ctx.tick)
        return { g = r, k = fit.k, ox = fit.ox, oy = fit.oy, inst = inst, cover = fit.cover, masks = masks,
          far = { x = sh.x, y = sh.y, key = Cl.shore_key(sh.x, sh.y), sector = c.key, d = d } }
      end
      s.bad[Cl.shore_key(sh.x, sh.y)] = true
    end
    -- secteur épuisé : aucune rive hors du treillis, ou toutes essayées sans succès (liste plus courte que le plafond)
    if all_failed and #shores < Cl.SHORES_MAX then s.done[c.key] = true end
    if all_failed and #shores >= Cl.SHORES_MAX then pending = true end
  end
  if pending then return nil, "centrale lointaine : recherche de l'eau en cours", "loin" end
  -- « il faut aller plus loin » : aucune eau VUE ne tient la centrale ; avec une carte de connaissance, l'équipe demande une
  -- exploration (crochet posé par script/ai3/exploration.lua) et relit sa carte toutes les Cl.EXPLORE_POLL ticks, au plus
  -- Cl.EXPLORE_WAIT par recherche
  local waited = ctx.tick - (s.searching or ctx.tick)
  if Cl.when_dry(source, waited, Far.hooks.request ~= nil) == "explorer" then
    local r = Far.hooks.request(f, Cl.EXPLORE_TAG, ctx.tick, "centrale")
    if not s.explore then
      s.explore = ctx.tick
      say(f, string.format("aucune eau vue ne tient la centrale (%d secteur(s) epuise(s), %d rive(s) ecartee(s)) : exploration demandee (%s) a %.1f min, attente au plus %d min",
        #sorted_keys(s.done), #sorted_keys(s.bad), tostring(r), ctx.tick / 3600, Cl.EXPLORE_WAIT / 3600))
    end
    if ctx.p then ctx.p.far_poll = Cl.EXPLORE_POLL end
    return nil, "centrale lointaine : exploration de l'eau", "loin"
  end
  say(f, string.format("aucune eau atteignable hors du treillis (source %s, %d secteur(s) epuise(s), %d rive(s) ecartee(s), %d sondage(s) dans cette passe, %.1f min de recherche) : centrale refusee, nouvel essai a la prochaine demande",
    source, #sorted_keys(s.done), #sorted_keys(s.bad), probes, waited / 3600))
  Far.stop_explore(f, ctx.tick)
  s.searching = nil
  return nil, "pas d'eau atteignable"
end

--- Fin de l'exploration demandée pour l'eau (centrale posée ou refusée).
function Far.stop_explore(f, tick)
  local s = state(f.build)
  if s.explore and Far.hooks.cancel then Far.hooks.cancel(f, Cl.EXPLORE_TAG, tick) end
  s.explore = nil
end

--- Rive écartée (la ligne ou la pompe n'y passe pas) : la recherche suivante prend la rive suivante.
function Far.reject(f, p, why)
  if not (p and p.far) then return false end
  local s = state(f.build)
  s.bad[p.far.key] = true
  say(f, string.format("projet %d : rive (%d, %d) ecartee (%s) : rive suivante", p.id, p.far.x, p.far.y, tostring(why)))
  return true
end

--- Ligne de poteaux de la centrale lointaine (premier poteau `a`) au carrefour `goal` du treillis. taken = { [tkey] = true }
--- (poteaux déjà prévus par ce plan) ; known = poteaux connus (traversés) ; read_masks : relevé de build.lua. Rend la chaîne
--- (poteaux neufs, de `a` vers `goal`, chacun avec son point d'appui ax, ay, anchor), ou nil, raison, "loin".
function Far.line(f, surface, p, a, goal, reach, taken, known, read_masks)
  local b = f.build
  local chunks, missing, mset = {}, {}, {}
  local function chunk(cx, cy)
    local ck = cx .. ":" .. cy
    local c = chunks[ck]
    if c == nil then
      if surface.is_chunk_generated({ x = cx, y = cy }) then
        local m = read_masks(f, surface, cx * 32, cy * 32, cx * 32 + 32, cy * 32 + 32)
        c = { water = m.water, blocked = m.blocked, clear = m.clear }
      else
        c = false
        if not mset[ck] then mset[ck] = true missing[#missing + 1] = { cx, cy } end
      end
      chunks[ck] = c
    end
    return c
  end
  local trees_ok = false
  local function ground(tx, ty)
    local c = chunk(floor(tx / 32), floor(ty / 32))
    if not c then return nil end
    local k = P.tkey(tx, ty)
    if c.water[k] or c.blocked[k] or b.occ[k] then return nil end
    return c, k
  end
  local function free(x, y)
    local tx, ty = floor(x), floor(y)
    local c, k = ground(tx, ty)
    if not c or taken[k] then return false end
    if not trees_ok and c.clear[k] then return false end
    return true
  end
  local dist = sqrt((a.x - goal.x) ^ 2 + (a.y - goal.y) ^ 2)
  local opts = Cl.path_opts(dist, reach)
  -- P.pole_chain : la chaîne gloutonne d'abord (au plus près du minimum de poteaux en terrain libre), la recherche de chemin
  -- (shared/team/poteaux.lua, budget du lot) quand elle échoue ou s'allonge ; why : raison de la recherche de chemin
  local chain = P.pole_chain(a, goal, reach, false, free, known, opts)
  local why
  if not chain then
    trees_ok = true -- second essai : à travers bois (les arbres sous les poteaux seront défrichés)
    chain = P.pole_chain(a, goal, reach, false, free, known, opts)
    if not chain then _, why = Q.path(a, goal, reach, false, free, known, opts) end
  end
  if not chain then
    if #missing > 0 then
      for i = 1, math.min(#missing, 16) do
        surface.request_to_generate_chunks({ missing[i][1] * 32 + 16, missing[i][2] * 32 + 16 }, 0)
      end
      say(f, string.format("projet %d : ligne de (%.0f, %.0f) a (%.0f, %.0f) : terrain en generation (%d chunk(s) demande(s)), nouvel essai dans %d s",
        p.id, a.x, a.y, goal.x, goal.y, #missing, Cl.POLL / 60))
      p.far_poll = Cl.POLL -- lu par advance (build.lua) : délai avant le nouvel essai
      return nil, "ligne : terrain en generation", "loin"
    end
    Far.reject(f, p, string.format("ligne impossible sur %.0f tuiles : %s", dist, tostring(why)))
    return nil, "ligne impossible", "loin"
  end
  if #chain > Cl.MAX_POLES then
    Far.reject(f, p, string.format("ligne de %d poteaux au-dela de %d", #chain, Cl.MAX_POLES))
    return nil, "ligne trop longue", "loin"
  end
  -- points d'appui : une tuile praticable (ni eau, ni bâti, ni arbre, ni réservée, ni poteau de la ligne) près de chaque poteau
  local poles = {}
  for _, c in ipairs(chain) do poles[P.tkey(floor(c.x), floor(c.y))] = true end
  local function stand(tx, ty)
    local c, k = ground(tx, ty)
    return c ~= nil and not c.clear[k] and not taken[k] and not poles[k]
  end
  local anchored = 0
  for _, c in ipairs(chain) do
    local ax, ay = Cl.anchor_spot(stand, c.x, c.y, 6)
    if ax then
      c.ax, c.ay, c.anchor = ax, ay, string.format("l%g:%g", ax, ay)
      anchored = anchored + 1
    end
  end
  say(f, string.format("projet %d : ligne de %d poteau(x) (portee %.1f) de la centrale (%.0f, %.0f) au carrefour du treillis (%.0f, %.0f), %.0f tuiles%s, %d point(s) d'appui poses",
    p.id, #chain, reach, a.x, a.y, goal.x, goal.y, dist, trees_ok and ", a travers bois" or "", anchored))
  return chain
end

return Far
