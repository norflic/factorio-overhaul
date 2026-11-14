--[[
  TRAVERSEE, côté RUNTIME (règle pure : shared/team/traversee.lua ; lot TRAVERSEE, demande du DC du 8/11). Rien de décisionnel ici : ce
  fichier LIT le moteur (portée et nom des souterrains débloqués, tuiles de gisement, souterrains déjà posés ou planifiés, nature d'un
  obstacle franchi), appelle la règle et écrit le journal [FO-TRAVERSEE].

  Deux services, appelés à la place de P.belt_route et de P.pole_chain (même signature, plus l'équipe et la surface) :
    - Trav.route(f, surface, p, s, t, t_dir, bounds, cost, opts) -> tiles, info, names  |  nil, raison
        tiles : { x, y, dir, ug = nil | "input" | "output" } ; Trav.entities(tiles, names, role) en fait des entités de projet
        (une pièce souterraine porte type = "input" | "output" : convention de build.lua pour le fantôme et le ravivage).
        opts : belt (nom du tapis du tracé), sd (sens d'arrivée en s, code du jeu), weight, max, kind (texte du journal), no_ore (vrai : le
        gisement est ignoré), budget ({ left } : états restants, partagé ; défaut : Tv.PLAN_BUDGET par projet et par tick).
        phase_slice / phase_state (lot TRANCHES-FOREUSES) : tracé par passes de phase_slice états ; une passe inachevée rend nil, "pending", état.
    - Trav.pole_chain(f, surface, a, b, reach, big, free, known, opts) -> chaîne | nil
  Réglage : Trav.ENABLED (banc : Trav.set_enabled(false) rend les anciens tracés, le compteur de gisement continue de tourner).
  Rien dans global ici, sauf les compteurs de f.build.stats (traversee_*), créés à la demande, jamais à on_load.
]]

local T = require("shared.team.config")
local P = require("shared.team.plan")
local Tv = require("shared.team.traversee")
local RG = require("shared.team.route_garde") -- s45 astar-budget : plafond par tick, mémo d'échec, boucle

local Trav = {}

Trav.ENABLED = true
Trav.LOGS = 60                 -- lignes [FO-TRAVERSEE] au plus par équipe (hors bilan)
Trav.BILAN_TICKS = 18000       -- un bilan par équipe et par tranche de 5 minutes
Trav.TTL = 600                 -- ticks : vie d'un chunk de gisement en cache
Trav.CACHE_MAX = 400           -- chunks gardés au plus par surface

function Trav.set_enabled(on) Trav.ENABLED = on and true or false end

---------------------------------------------------------------------------------------------------
-- Lectures
---------------------------------------------------------------------------------------------------
local function enabled_item(f, item)
  local force = game.forces[f.force]
  local r = force and force.recipes[item]
  return r ~= nil and r.enabled == true
end

--- Souterrain à poser avec un tapis `belt` : le moins cher (vitesse, puis nom) débloqué dont la vitesse atteint celle du tapis, sinon le
--- plus rapide débloqué. Rend { name, maxd } ou nil (aucun débloqué : le tracé se contourne). Aucun nom écrit ici.
local UG_CACHE = {}
function Trav.underground(f, belt)
  -- cache LOCAL (jamais dans global) par force et tapis, Trav.TTL ticks : la liste des prototypes était relue et triée à chaque tracé
  local ck = tostring(f.force) .. "|" .. tostring(belt)
  local hit = UG_CACHE[ck]
  if hit and game.tick - hit.tick < Trav.TTL then return hit.ug or nil end
  local ug = Trav.underground_read(f, belt)
  UG_CACHE[ck] = { tick = game.tick, ug = ug or false }
  return ug
end

function Trav.underground_read(f, belt)
  local protos = game.get_filtered_entity_prototypes({ { filter = "type", type = T.LOGISTIC_TYPES.underground } })
  local bp = belt and game.entity_prototypes[belt]
  local want = bp and bp.belt_speed or 0
  local list = {}
  for name, pr in pairs(protos) do -- (liste triée juste après : l'ordre de pairs n'a aucun effet)
    local items = pr.items_to_place_this
    if items and items[1] and not pr.has_flag("hidden") and pr.max_underground_distance and pr.max_underground_distance >= 2 then
      list[#list + 1] = { name = name, speed = pr.belt_speed or 0, item = items[1].name, maxd = pr.max_underground_distance }
    end
  end
  table.sort(list, function(a, b) if a.speed ~= b.speed then return a.speed < b.speed end return a.name < b.name end)
  local fastest
  for _, x in ipairs(list) do
    if enabled_item(f, x.item) then
      if x.speed + 1e-9 >= want then
        P.declare_size(x.name, 1, 1)
        return x
      end
      fastest = x
    end
  end
  if fastest then P.declare_size(fastest.name, 1, 1) end
  return fastest
end

-- Cache LOCAL (jamais dans global, vide à chaque chargement) des tuiles de gisement par chunk de 32 x 32 : un chunk est lu au moteur à la première
-- question, relu après Trav.TTL ticks (comme le cache des masques de build.lua, shared/team/masques.lua). Plafonné : au-delà de Trav.CACHE_MAX
-- chunks, le cache de la surface est vidé.
local CACHE = {}
local function ore_chunk(surface, cx, cy)
  local sc = CACHE[surface.index]
  if not sc then sc = { n = 0, by = {} }; CACHE[surface.index] = sc end
  local k = P.tkey(cx, cy)
  local e = sc.by[k]
  if e and game.tick - e.tick < Trav.TTL then return e.set end
  if not e then
    sc.n = sc.n + 1
    if sc.n > Trav.CACHE_MAX then sc.n, sc.by = 1, {} end
  end
  local set = {}
  local x0, y0 = cx * 32, cy * 32
  local area = { { x0, y0 }, { x0 + 32, y0 + 32 } }
  -- (aucune ressource dans le chunk : un simple comptage, sans créer un objet par entité)
  if surface.count_entities_filtered({ area = area, type = "resource", limit = 1 }) > 0 then
    for _, r in ipairs(surface.find_entities_filtered({ area = area, type = "resource" })) do
      set[P.tkey(math.floor(r.position.x), math.floor(r.position.y))] = true
    end
  end
  sc.by[k] = { tick = game.tick, set = set }
  return set
end

--- Question « cette tuile porte-t-elle du gisement ? » (lecture paresseuse par chunk).
local function ore_lookup(surface)
  return function(x, y) return ore_chunk(surface, math.floor(x / 32), math.floor(y / 32))[P.tkey(math.floor(x), math.floor(y))] == true end
end
Trav.ore_lookup = ore_lookup

--- Axe (1 vertical, 2 horizontal) des pièces souterraines de la boîte : posées, fantômes, et pièces planifiées par les projets de l'équipe.
local function read_ug_axes(f, surface, x0, y0, x1, y1, ug_name)
  local map = {}
  local function axis_of(d) return (d == 0 or d == 4) and 1 or 2 end
  local area = { { x0, y0 }, { x1 + 1, y1 + 1 } }
  for _, e in ipairs(surface.find_entities_filtered({ area = area, type = T.LOGISTIC_TYPES.underground })) do
    map[P.tkey(math.floor(e.position.x), math.floor(e.position.y))] = axis_of(e.direction or 0)
  end
  local b = f.build
  if b and ug_name then
    for _, pid in ipairs(b.order or {}) do
      local q = b.projects[pid]
      if q and q.ents then
        for _, e in ipairs(q.ents) do
          if e.name == ug_name then map[P.tkey(math.floor(e.x), math.floor(e.y))] = axis_of(e.dir or 0) end
        end
      end
    end
  end
  return map
end

local NATURE = { ["electric-pole"] = "poteau", ["transport-belt"] = "tapis", ["underground-belt"] = "tapis", ["splitter"] = "tapis",
  ["tree"] = "arbre", ["cliff"] = "falaise", ["simple-entity"] = "rocher", ["container"] = "coffre", ["logistic-container"] = "coffre",
  ["inserter"] = "bras", ["wall"] = "mur", ["gate"] = "mur", ["pipe"] = "tuyau", ["pipe-to-ground"] = "tuyau", ["entity-ghost"] = "fantome" }

--- Nature de ce qui occupe une tuile (journal seulement, appelé pour les tuiles franchies d'un tracé retenu).
local function nature_at(surface, x, y)
  local on_ore = false
  for _, e in ipairs(surface.find_entities_filtered({ area = { { x + 0.1, y + 0.1 }, { x + 0.9, y + 0.9 } } })) do
    if e.type ~= "resource" then
      local ty = e.type == "entity-ghost" and e.ghost_type or e.type
      return NATURE[ty] or (e.type == "entity-ghost" and "fantome") or "machine"
    end
    on_ore = true
  end
  if surface.count_tiles_filtered({ area = { { x + 0.1, y + 0.1 }, { x + 0.9, y + 0.9 } }, collision_mask = "water-tile" }) > 0 then return "eau" end
  return on_ore and "gisement" or "reserve"
end

---------------------------------------------------------------------------------------------------
-- Journal et compteurs
---------------------------------------------------------------------------------------------------
local function say(f, text)
  local st = f.build and f.build.stats
  if not st then return end
  st.traversee_logs = (st.traversee_logs or 0) + 1
  if st.traversee_logs > Trav.LOGS then return end
  log(text)
end

local function count(f, info, ok, why)
  local st = f.build and f.build.stats
  if not st then return end
  st.traversee = st.traversee or { routes = 0, refused = 0, jumps = 0, pairs_routes = 0, ore = 0, ore_base = 0, avoided = 0, detours = 0, why = {}, slot = 0 }
  local c = st.traversee
  c.why = c.why or {}
  if not ok then
    c.refused = c.refused + 1
    local key = tostring(why or "?")
    c.why[key] = (c.why[key] or 0) + 1
  else
    c.routes = c.routes + 1
    c.jumps = c.jumps + info.jumps
    if info.jumps > 0 then c.pairs_routes = (c.pairs_routes or 0) + 1 end
    c.ore = c.ore + info.ore
    c.ore_base = c.ore_base + info.base_ore
    if info.ore < info.base_ore then c.avoided = (c.avoided or 0) + 1 end
    if (info.phys or 0) > (info.base_phys or 0) then c.detours = (c.detours or 0) + 1 end
  end
  -- une ligne de bilan par tranche de 5 minutes (jamais bornée par Trav.LOGS : rien ne se perd après la borne)
  local slot = math.floor(game.tick / Trav.BILAN_TICKS)
  if slot ~= c.slot then
    c.slot = slot
    local causes = {}
    local keys = {}
    for k in pairs(c.why) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do causes[#causes + 1] = string.format("%s %d", k, c.why[k]) end
    log(string.format("[FO-TRAVERSEE] %s : bilan a %.1f min : %d trace(s) dont %d avec paire(s) souterraine(s) (%d paire(s)), %d avec detour pour eviter un gisement, %d avec moins de gisement ; gisement couvert %d tuile(s) (trace de base : %d) ; %d refus [%s]",
      f.key or "player", game.tick / 3600, c.routes, c.pairs_routes or 0, c.jumps, c.detours or 0, c.avoided or 0, c.ore, c.ore_base, c.refused, table.concat(causes, ", ")))
  end
end

---------------------------------------------------------------------------------------------------
-- Tapis
---------------------------------------------------------------------------------------------------
local BUDGET = { key = nil, box = nil }
local TICK_BOX = { tick = nil, spent = 0 } -- s45 : états dépensés au tick, tous tracés (table LOCALE)
--- Budget d'états PARTAGÉ par tous les tracés d'un même projet au même tick (les 3 essais de plan_drills, les 4 paires de bouts d'une liaison).
--- opts.budget (table { left }) l'emporte. Table LOCALE : jamais dans global, rien à sauvegarder.
function Trav.budget(f, p, opts)
  if opts and opts.budget then return opts.budget end
  local key = tostring(f.key or f.force) .. ":" .. tostring(p and p.id or "?") .. ":" .. tostring(game.tick)
  if BUDGET.key ~= key then BUDGET.key, BUDGET.box = key, { left = Tv.PLAN_BUDGET } end
  return BUDGET.box
end

--- Trace d'un tapis de s à t (voir le haut du fichier). `p` : le projet (numéro et nature au journal), facultatif.
function Trav.route(f, surface, p, s, t, t_dir, bounds, cost, opts)
  opts = opts or {}
  -- s45 astar-budget : une paire en échec attend (1, 2, 4 … BASE, borné à 30 min) ; plafond global d'états par tick
  local memo = f.build and (function() f.build.route_memo = f.build.route_memo or {} return f.build.route_memo end)() or nil
  -- clé : la paire triée, plus ce qui change le tracé (boîte, poids, plafond, nature) : un 2e essai différent n'est pas bloqué
  local pkey = RG.pair_key(s, t) .. "|" .. tostring(opts.kind) .. "|" .. tostring(opts.weight) .. "|" .. tostring(opts.max) .. "|" ..
    tostring(bounds.x0) .. "," .. tostring(bounds.y0) .. "," .. tostring(bounds.x1) .. "," .. tostring(bounds.y1)
  if memo and not opts.resume and RG.blocked(memo, pkey, game.tick) then return nil, "attente" end
  if RG.tick_left(TICK_BOX, game.tick) <= 0 then return nil, "budget tick" end
  local tiles, info, extra = Trav.route_inner(f, surface, p, s, t, t_dir, bounds, cost, opts)
  if tiles and RG.has_loop(tiles) then tiles, info, extra = nil, "boucle", nil end
  if memo and info ~= "pending" and info ~= "budget tick" then
    if tiles then RG.success(memo, pkey) else RG.fail(memo, pkey, game.tick) end
  end
  return tiles, info, extra
end

function Trav.route_inner(f, surface, p, s, t, t_dir, bounds, cost, opts)
  local ug = Trav.ENABLED and Trav.underground(f, opts.belt) or nil
  -- opts.no_ore : aucun détour de gisement (appelants courts : branches de piquage) ; le gisement n'est alors pas lu du tout
  local ore = (not opts.no_ore) and ore_lookup(surface) or nil
  local ctx = {
    maxd = ug and ug.maxd or nil, sd = opts.sd, weight = opts.weight or Tv.GAME_WEIGHT, max = opts.max, ore = ore, budget = (not opts.slice) and Trav.budget(f, p, opts) or nil,
    slice = opts.slice, resume = opts.resume, no_detour = opts.no_detour, -- lot RESEAU-GRAPHE : recherche par tranches (tronc de bus)
    phase_slice = opts.phase_slice, phase_state = opts.phase_state, -- lot TRANCHES-FOREUSES : le MÊME tracé, cherché par passes (état rendu : nil, "pending", état)
    -- les souterrains existants ne sont lus qu'à la première paire envisagée (phase B de la règle) : un tracé sans obstacle ne lit rien
    ug_axis = ug and (function()
      local axes
      return function(x, y)
        if not axes then axes = read_ug_axes(f, surface, bounds.x0, bounds.y0, bounds.x1, bounds.y1, ug.name) end
        return axes[P.tkey(x, y)]
      end
    end)() or nil,
    nature = function(x, y) return nature_at(surface, x, y) end,
  }
  local tiles, info, resume_state
  if Trav.ENABLED then
    local left0 = ctx.budget and ctx.budget.left
    local cap = left0 and math.min(left0, RG.tick_left(TICK_BOX, game.tick)) or nil
    if cap then ctx.budget.left = cap end
    tiles, info, resume_state = Tv.route(s, t, t_dir, bounds, cost, ctx)
    if cap then
      local used = math.max(0, cap - ctx.budget.left)
      RG.spend(TICK_BOX, game.tick, used)
      ctx.budget.left = left0 - used
      -- coupé par le plafond du tick (pas par le sien) : ni verdict ni mémo, on réessaie à une passe suivante
      if not tiles and info == "trop long" and cap < left0 then return nil, "budget tick" end
    elseif type(info) == "table" and info.expand then
      RG.spend(TICK_BOX, game.tick, info.expand)
    end
    if not tiles and info == "pending" then return nil, "pending", resume_state end -- tranche finie : ni verdict, ni journal
  else
    -- réglage éteint : l'ancien tracé (P.belt_route), compteur de gisement seulement
    local old, n = P.belt_route(s, t, t_dir, bounds, cost, opts.weight and { weight = opts.weight, max = opts.max } or nil)
    if not old then return nil, n end
    tiles = old
    local on = 0
    for _, e in ipairs(old) do if ore and ore(e.x, e.y) then on = on + 1 end end
    info = { len = #old, ore = on, jumps = 0, base_len = #old, base_ore = on, pen = 0, jump_list = {} }
  end
  if not tiles then
    count(f, nil, false, info)
    if Trav.ENABLED then
      -- la CAUSE du refus : quel obstacle arrête le tracé, où (le journal ne la disait pas)
      local st = f.build and f.build.stats
      if st and (st.traversee_logs or 0) < Trav.LOGS and (info == "aucun chemin" or info == "trop long") and not opts.no_diag then
        local diag = Tv.diagnose(s, t, bounds, cost, ug and ug.maxd or nil)
        local nat = diag.block and not diag.outside and nature_at(surface, diag.block.x, diag.block.y) or nil
        say(f, Tv.refusal_line({ team = f.key or "player", project = p and p.id or "?", kind = opts.kind or "tapis" }, info, diag, nat))
      else
        say(f, Tv.refusal_line({ team = f.key or "player", project = p and p.id or "?", kind = opts.kind or "tapis" }, info, nil, nil))
      end
    end
    return nil, info
  end
  count(f, info, true)
  if Trav.ENABLED then
    local who = { team = f.key or "player", project = p and p.id or "?", kind = opts.kind or "tapis" }
    for _, line in ipairs(Tv.lines(who, info)) do say(f, line) end
  end
  return tiles, info, ug and { ug = ug.name, maxd = ug.maxd } or {}
end

--- Entités d'un tracé de Trav.route : names = { belt, ug } (ug : le nom rendu par Trav.route), role = rôle des pièces.
function Trav.entities(tiles, names, role) return Tv.entities(tiles, names, role) end

---------------------------------------------------------------------------------------------------
-- Poteaux
---------------------------------------------------------------------------------------------------
--- Chaîne de poteaux qui évite les gisements : comme P.pole_chain (mêmes arguments, plus l'équipe et la surface), rend la chaîne.
function Trav.pole_chain(f, surface, a, b, reach, big, free, known, opts)
  local function chain(aa, bb, fr) return P.pole_chain(aa, bb, reach, big, fr, known, opts) end
  if not Trav.ENABLED then return chain(a, b, free) end
  local got, how, n0 = Tv.pole_chain(chain, a, b, free, ore_lookup(surface))
  if how == "evitee" then
    say(f, string.format("[FO-TRAVERSEE] %s : poteaux de (%.1f, %.1f) a (%.1f, %.1f) : chaine sans gisement (%d poteau(x), %d sur le gisement sur la chaine d'avant)",
      f.key or "player", a.x, a.y, b.x, b.y, #got, n0))
  elseif how == "traverse" then
    say(f, string.format("[FO-TRAVERSEE] %s : poteaux de (%.1f, %.1f) a (%.1f, %.1f) : %d poteau(x) sur le gisement (aucune chaine sans gisement a moins de %d poteau(x) de plus)",
      f.key or "player", a.x, a.y, b.x, b.y, n0, Tv.POLE_EXTRA))
  end
  return got
end

return Trav
