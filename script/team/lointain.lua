--[[
  Lot CENTRALE (28/10) : la centrale à vapeur À DISTANCE d'une équipe (règles pures : shared/team/lointain.lua ; carte de
  connaissance : shared/ai3/carte.lua). Remplace l'étang garanti de 6 × 6 (97ced75, f92b150) : quand aucune rive du treillis
  ne tient le gabarit de la pompe, l'équipe cherche l'EAU qu'elle a VUE (secteurs `w` de sa carte, jamais un balayage
  omniscient), explore si elle n'en connaît pas, pose sa centrale sur la meilleure rive et la relie au treillis par une ligne
  de poteaux (le poteau du gabarit, le moins cher débloqué, portée lue aux données).

  Ce module lit le moteur (tuiles d'eau d'un secteur, relevé d'une rive, terrain d'une ligne) et décide ; Build (script/team/
  build.lua) l'appelle depuis plan_project et plan_power et pose les entités par ses états de projet habituels. Il ne
  requiert ni Build ni l'exploration (cycle) : Build lui passe ses fonctions locales (ctx) ; l'exploration lit
  `f.build.remote.want_water` (données du jeu).

  État (nombres, chaînes, tables à clés triées ; jamais de fonction) : f.build.remote = { want_water, since, bad = { [secteur] =
  raison }, cur = { [secteur] = rives déjà consommées }, gen = { [secteur] = passes d'attente du terrain }, logged }.

  Déterminisme : secteurs et rives triés ; relevés du moteur rangés dans des ensembles puis triés avant tout choix.
]]

local P = require("shared.team.plan")
local M = require("shared.team.modules")
local K = require("shared.ai3.carte")
local L = require("shared.team.lointain")

local Lointain = {}

Lointain.POLL_SEARCH = 300     -- ticks (5 s) entre deux passes tant que des secteurs d'eau restent à essayer
Lointain.LOGS = 40             -- lignes [FO-LOINTAIN] au plus, par équipe

local floor = math.floor

local function state_of(b)
  if not b.remote then b.remote = { want_water = false, bad = {}, cur = {}, gen = {}, logged = 0 } end
  local r = b.remote
  r.bad, r.cur, r.gen = r.bad or {}, r.cur or {}, r.gen or {}
  return r
end

local function say(f, r, fmt, ...)
  r.logged = (r.logged or 0) + 1
  if r.logged > Lointain.LOGS then return end
  log("[FO-LOINTAIN] " .. (f.key or "player") .. " : " .. string.format(fmt, ...))
end

--- Danger écarté : les NIDS, les vers et les incidents VUS (carte de connaissance) ; PAS les QG rivaux. Le terme « QG rival à
--- 256 tuiles » de K.sector_risk (+ 600) vaut pour un éclaireur qui évite un adversaire ; ici, l'eau d'une faction voisine du
--- point de départ du joueur (moteur réel, 28/10, graine 271828182 : tous les secteurs d'eau d'Azure écartés « danger : risque
--- 1000, 0 nid ») serait interdite à jamais. Les rivaux ne sont donc pas passés à K.line_risk ni à K.site_inputs.
local NO_RIVALS = {}

local function mark_bad(f, r, key, why)
  if r.bad[key] then return end
  r.bad[key] = why
  local sx, sy = K.xy(key)
  say(f, r, "secteur d'eau (%d, %d) ecarte (%s)", sx, sy, why)
end

--- Les chunks d'un rectangle sont-ils générés ? Sinon rend la liste (triée) de ceux qui manquent.
local function missing_chunks(surface, x0, y0, x1, y1)
  local miss = {}
  for cy = floor(y0 / 32), floor((y1 - 1) / 32) do
    for cx = floor(x0 / 32), floor((x1 - 1) / 32) do
      if not surface.is_chunk_generated({ x = cx, y = cy }) then miss[#miss + 1] = { x = cx, y = cy } end
    end
  end
  return miss
end

local function request(surface, miss)
  for i, c in ipairs(miss) do
    if i > 6 then break end
    surface.request_to_generate_chunks({ x = c.x * 32 + 16, y = c.y * 32 + 16 }, 1)
  end
end

--- Cherche l'eau et une rive pour la centrale. ctx = { read_masks, fit, make_main(g, fit, masks), p (projet), tick }. Rend
---   main  (même forme que place_module de Build, lot = nil, remote = { key, idx, x, y })
--- ou nil, raison, "lointain" (plan remis à plus tard : p.plan_after posé).
function Lointain.place(f, surface, g, ctx)
  local b = f.build
  local r = state_of(b)
  local p, tick = ctx.p, ctx.tick
  -- `explore` : aucune eau connue à essayer, l'exploration doit en trouver (demande d'exploration de l'eau, porte de la
  -- centrale relâchée pour les projets sans réseau) ; sinon des secteurs d'eau restent à essayer et la recherche continue
  local function later(why, poll, explore)
    if explore and not r.want_water then
      r.want_water, r.since = true, tick
      say(f, r, "pas de rive au treillis, aucune eau connue a essayer : exploration de l'eau demandee a %.1f min (%s)", tick / 3600, why)
    elseif not explore then
      r.want_water = false
    end
    r.since = r.since or tick
    p.plan_after = tick + (poll or L.POLL)
    return nil, why, "lointain"
  end
  local m = f.ai3f and f.ai3f.m
  if not m then return later("eau : carte de connaissance absente", L.POLL, true) end
  local hq = f.hq_pos
  local rv = NO_RIVALS
  local reach = P.wire(g.pole_name or M.DEFAULT_POLE) or 9
  local list = K.waters(m, hq, r.bad)
  if #list == 0 then return later("eau : aucun secteur d'eau connu (exploration)", L.POLL, true) end
  local examined = 0
  for _, w in ipairs(list) do
    if examined >= L.SECTORS_PER_PASS then break end
    examined = examined + 1
    local base = (b.radius + 0.5) * P.PITCH -- le territoire du treillis n'entre pas dans le danger du couloir
    local info = K.line_risk(m, hq, { x = w.x, y = w.y }, tick, rv, base)
    local ok, why = L.corridor_ok(info, { skip = K.DANGER.skip })
    local line_len = math.max(0, info.length - (b.radius + 0.5) * P.PITCH)
    if ok and L.poles_needed(line_len, reach) > L.MAX_POLES then ok, why = false, "trop loin" end
    if not ok then
      local wx, wy = 0, 0
      local nn, nw, nm = 0, 0, 0
      if info.worst then
        local ux, uy = K.xy(info.worst)
        wx, wy = ux, uy
        local cx, cy = K.center(ux, uy)
        nn, nw = K.enemies_near(m, cx, cy, K.SECTOR * 2)
        nm = K.marks_near(m, cx, cy, 2 * K.SECTOR, tick)
      end
      mark_bad(f, r, w.key, string.format("%s : risque %d au secteur (%d, %d) [%d nid(s), %d ver(s), %d incident(s) a 128 tuiles], %d nid(s) sur le couloir, %d/%d secteurs inconnus, %d tuiles",
        why, info.risk, wx, wy, nn, nw, nm, info.nests, info.unseen, info.samples, floor(info.length)))
    else
      local sx, sy = K.xy(w.key)
      local x0, y0 = sx * K.SECTOR, sy * K.SECTOR
      -- l'eau d'un secteur et ses abords (L.SECTOR_MARGIN tuiles) : la rive d'un lac qui commence au bord du secteur est de
      -- l'autre côté de la limite
      local mg = L.SECTOR_MARGIN
      local ws = {}
      for _, t in ipairs(surface.find_tiles_filtered({ area = { { x0 - mg - 2, y0 - mg - 2 }, { x0 + K.SECTOR + mg + 2, y0 + K.SECTOR + mg + 2 } },
        collision_mask = "water-tile" })) do
        ws[P.tkey(floor(t.position.x), floor(t.position.y))] = true
      end
      local shores = L.shores(function(tx, ty) return ws[P.tkey(tx, ty)] == true end,
        { x0 = x0 - mg, y0 = y0 - mg, x1 = x0 + K.SECTOR + mg, y1 = y0 + K.SECTOR + mg }, hq)
      local done = r.cur[w.key] or 0
      local tried = 0
      local i = done
      while i < #shores and tried < L.SHORES_PER_PASS do
        i = i + 1
        local sh = shores[i]
        local rect = L.window(sh.x, sh.y)
        local miss = missing_chunks(surface, rect.x0 - 8, rect.y0 - 8, rect.x1 + 8, rect.y1 + 8)
        if #miss > 0 and (r.gen[w.key] or 0) < L.GEN_WAIT_MAX then
          request(surface, miss)
          r.gen[w.key] = (r.gen[w.key] or 0) + 1
          r.cur[w.key] = i - 1
          return later("eau : terrain de la rive en generation", Lointain.POLL_SEARCH)
        end
        r.cur[w.key] = i
        if #miss == 0 then
          tried = tried + 1
          local masks = ctx.read_masks(f, surface, rect.x0 - 8, rect.y0 - 8, rect.x1 + 8, rect.y1 + 8)
          local fit, fwhy = ctx.fit(g, rect, { free = masks.free, water = masks.water, toward = hq, margin = 0 })
          if fit then
            local site = { x = sh.x, y = sh.y }
            local sok, swhy = L.site_ok(K.site_inputs(m, site, hq, tick, false))
            local cinfo = K.line_risk(m, hq, site, tick, rv, base)
            local cok, cwhy = L.corridor_ok(cinfo, { skip = K.DANGER.skip })
            if sok and cok then
              say(f, r, "rive choisie en (%d, %d) du secteur (%d, %d) a %d tuiles du QG, environ %d poteaux, couloir : risque %d, %d/%d secteurs inconnus",
                sh.x, sh.y, sx, sy, floor(cinfo.length), L.poles_needed(line_len, reach), cinfo.risk, cinfo.unseen, cinfo.samples)
              local out = ctx.make_main(g, fit, masks)
              out.remote = { key = w.key, idx = i, x = sh.x, y = sh.y, dir = sh.dir }
              return out
            end
            say(f, r, "rive (%d, %d) ecartee : %s", sh.x, sh.y, tostring(swhy or cwhy))
          else
            r.fit_refused = (r.fit_refused or 0) + 1
            if (r.fit_refused <= 6) then say(f, r, "rive (%d, %d) : gabarit refuse (%s)", sh.x, sh.y, tostring(fwhy)) end
          end
        end
      end
      if (r.cur[w.key] or 0) >= #shores then mark_bad(f, r, w.key, "aucune rive ne tient le gabarit") end
    end
  end
  return later("eau : recherche d'une rive", Lointain.POLL_SEARCH)
end

--- Le plan a abouti : l'eau n'est plus à chercher.
function Lointain.found(f, tick)
  local r = f.build and f.build.remote
  if r then
    r.want_water = false
    log(string.format("[FO-LOINTAIN] %s : centrale planifiee a %.1f min (eau cherchee depuis %.1f min)", f.key or "player",
      tick / 3600, (r.since or tick) / 3600))
    r.since = nil
  end
end

--- Le plan a échoué APRÈS le choix d'une rive (ligne impossible, terrain en génération) ou le projet est annulé :
--- `retry` rend la rive au secteur (elle n'est pas en faute).
function Lointain.release(f, p, retry)
  local site = p.remote_site
  local r = f.build and f.build.remote
  if site and r and retry then r.cur[site.key] = math.min(r.cur[site.key] or 0, site.idx - 1) end
  p.remote_site = nil
end

--- Le fantôme de la pompe est refusé au moteur malgré le gabarit accepté par P.fit (rive irrégulière, tuile de bord que la
--- règle de la pompe n'accepte pas) : la rive est écartée pour de bon, la centrale sera replanifiée à la suivante (la
--- signature de l'automatisation change : `rejected`). Rend vrai si le projet est une centrale lointaine.
function Lointain.reject(f, p)
  local site = p.remote_site
  local r = f.build and f.build.remote
  if not (site and r) then return false end
  L.skip_shore(r.cur, site)
  r.rejected = (r.rejected or 0) + 1
  say(f, r, "pompe refusee a la rive (%d, %d) du secteur %s : rive ecartee, centrale replanifiee", site.x, site.y, tostring(site.key))
  return true
end

--- Terrain d'une ligne de poteaux lu au moteur : free(x, y) -> bool (centre de tuile), mémoïsé ; `missing()` rend les chunks
--- non générés rencontrés (liste triée). Une tuile est libre si son chunk est généré, sans eau, sans entité de la couche
--- des objets (arbres, rochers, falaises, bâtiments), non réservée par un projet (b.occ) ni dans `taken`.
function Lointain.line_free(f, surface, taken)
  local b = f.build
  local memo, miss, missn = {}, {}, {}
  local function free(x, y)
    local tx, ty = floor(x), floor(y)
    local k = P.tkey(tx, ty)
    local v = memo[k]
    if v ~= nil then return v end
    v = false
    if not (b.occ[k] or (taken and taken[k])) then
      local cx, cy = floor(tx / 32), floor(ty / 32)
      if surface.is_chunk_generated({ x = cx, y = cy }) then
        v = surface.count_tiles_filtered({ area = { { tx, ty }, { tx + 1, ty + 1 } }, collision_mask = "water-tile", limit = 1 }) == 0
          and surface.count_entities_filtered({ area = { { tx + 0.05, ty + 0.05 }, { tx + 0.95, ty + 0.95 } },
            collision_mask = "object-layer", limit = 1 }) == 0
      else
        local ck = P.tkey(cx, cy)
        if not missn[ck] then missn[ck] = true; miss[#miss + 1] = { x = cx, y = cy } end
      end
    end
    memo[k] = v
    return v
  end
  local function missing()
    table.sort(miss, function(a, c) if a.y ~= c.y then return a.y < c.y end return a.x < c.x end)
    return miss
  end
  return free, missing
end

--- Demande la génération du terrain le long du segment a → b (un point tous les 24 tuiles, chunk et voisins) ; rend vrai si
--- tout est déjà généré.
function Lointain.corridor_ready(surface, a, bpos)
  local dx, dy = bpos.x - a.x, bpos.y - a.y
  local n = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy) / 24))
  local miss, seen = {}, {}
  for i = 0, n do
    local x, y = a.x + dx * i / n, a.y + dy * i / n
    local cx, cy = floor(x / 32), floor(y / 32)
    for oy = -1, 1 do
      for ox = -1, 1 do
        local k = P.tkey(cx + ox, cy + oy)
        if not seen[k] then
          seen[k] = true
          if not surface.is_chunk_generated({ x = cx + ox, y = cy + oy }) then miss[#miss + 1] = { x = cx + ox, y = cy + oy } end
        end
      end
    end
  end
  if #miss == 0 then return true end
  table.sort(miss, function(u, v) if u.y ~= v.y then return u.y < v.y end return u.x < v.x end)
  request(surface, miss)
  return false
end

--- Chunks manquants (liste) à demander puis à attendre.
function Lointain.request(surface, miss) request(surface, miss) end

return Lointain
