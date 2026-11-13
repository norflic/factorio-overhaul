--[[
  Lot MINAGE-MAIN, côté RUNTIME (règles pures : shared/team/sources.lua ; critères : fo-logs/2026-11-08_MINAGE-MAIN/CRITERES.md).

  Le DC (8/11, 0.6.65) : des PNJ minent du fer et du cuivre à la main, les fondent dans des fours près de la base, pendant que des milliers de
  plaques dorment dans des coffres de SORTIE (fonderie de l'équipe ou posée par lui). Cause (RD_LOG, lot MINAGE-MAIN) : la vue de stock est le
  coffre d'équipe seul ; les sorties du plan directeur et d'une fonderie posée à la main ne sont dans aucun registre.

  Ce module :
    1. tient le REGISTRE des coffres (sortie : un bras ou une foreuse y dépose, aucun bras n'en retire) par ÉVÉNEMENTS : pose, retrait, rotation
       (chaque événement étudie les bras à 4 tuiles du coffre, jamais la carte) ; les sorties DÉCLARÉES du plan directeur (p.outs) y sont ajoutées
       à chaque pensée (les équipes bâtissent par script : pas d'événement) ; une sauvegarde d'avant le lot est étudiée par TRANCHES de
       S.SCAN_PER_THINK coffres (jamais à on_load) ;
    2. relit le contenu des sorties par tranches de S.READ_PER_THINK ;
    3. à chaque pensée d'équipe (étape E4, avant le marché) : pour chaque ressource suivie, décide « prendre à la sortie X » (tâche « fetch »,
       priorité S.PRIO), « attendre une sortie en marche » ou « extraire à la main : aucune source (cause) » ; retire les minages LIBRES des
       ressources que les sorties fournissent ; journal [FO-SOURCES] ;
    4. ajoute ce que les tournées ramèneront à `view.incoming` du cerveau (Src.incoming), jamais au stock libre ;
    5. barre le programme d'un minage à la main déjà pris quand une source existe (Src.hand_ok, appelé par script/team/worker.lua).
  Hors de son périmètre : les sorties des avant-postes (o.sinks : lots FLUX et CHARBON-MAIN), le coffre d'équipe et ses annexes.
  Interrupteur par équipe (bancs) : f.team.sources_regle == false coupe tout. État : f.team.sources (créé ici, en événement, jamais à on_load).
  Déterminisme : listes triées, aucune mesure de temps, aucune décision selon l'ordre de pairs.
]]
local Events = require("script.core.events")
local T = require("shared.team.config")
local S = require("shared.team.sources")
local State = require("script.faction.state")
local Storage = require("script.core.storage")
local Board = require("script.team.board")
local Stock = require("script.team.stock")
local Profiler = require("script.core.profiler") -- lot UPS : portées fines « ws: » (recherches sur toute la surface ; mesure seulement)
local Poles = require("script.team.poles")

local Src = {}

Src.RADIUS = 4       -- tuiles autour d'un coffre où l'on cherche les bras et les foreuses qui s'y rattachent (bras long : 2 tuiles)
Src.LOGS = 60        -- lignes [FO-SOURCES] au plus par équipe
Src.LOG_EVERY = 3600 -- une ligne par ressource et par minute au plus
Src.REACH = 15       -- tuiles : le PNJ doit être à cette distance du coffre pour le vider
Src.CHEST = T.outposts.coal.sink -- coffre des sorties du plan directeur (shared/team/config.lua)

local TARGETS = S.targets(T.outposts, T.smelter_inputs, T.OUTPOST_ORDER)
local TRACKED = S.tracked(TARGETS)
local BY_RES = {}
for _, x in ipairs(TARGETS) do BY_RES[x.res] = x end

local FEED_TYPES = { "inserter", "mining-drill" }

---------------------------------------------------------------------------------------------------
-- État
---------------------------------------------------------------------------------------------------
function Src.on(f) return f ~= nil and f.team ~= nil and f.team.sources_regle ~= false end

--- Registre de l'équipe (créé au besoin : jamais depuis on_load).
local function reg_of(f)
  local st = f.team.sources
  if not st then
    st = S.new()
    st.dec = {}      -- dernière décision par ressource : { act, item, uid, n, why, tick }
    st.said = {}     -- signature de la dernière ligne de journal, par ressource
    st.said_t = {}   -- tick de cette ligne
    st.logs = 0
    st.fetched = 0   -- objets rapportés en tout
    st.trips = 0
    st.empty = 0     -- tournées revenues sans rien
    f.team.sources = st
  end
  return st
end

--- Lecture seule pour les autres lots (graphe de flux, rapatriement, vue du cerveau) : coffres du registre, triés par identifiant. `kind` : "sortie",
--- "entree" ou nil (tous). Rend des rangées { uid, x, y, surface, kind, feeders, takers, n = { [objet] = n }, rate = { [objet] = objets/min } | nil,
--- grew, read, decl }. `rate` : pour une sortie, ce qui y entre ; pour une entrée, ce qui en sort (consommation) ; nil tant qu'un seul relevé existe.
function Src.list(f, kind)
  local st = f and f.team and f.team.sources
  if not st then return {} end
  local ids = {}
  for uid in pairs(st.chests) do ids[#ids + 1] = uid end
  table.sort(ids)
  local out = {}
  for _, uid in ipairs(ids) do
    local k = S.kind(st, uid)
    if kind == nil or k == kind then
      local c = st.chests[uid]
      local rate = k == "sortie" and c.rin or (k == "entree" and c.rout) or nil
      local surf = c.ent and c.ent.valid and c.ent.surface and c.ent.surface.name or nil
      out[#out + 1] = { uid = uid, x = c.x, y = c.y, surface = surf, kind = k, feeders = c.nf, takers = c.nt, n = c.n, rate = rate,
        grew = c.grew, read = c.read, decl = c.decl or false }
    end
  end
  return out
end

local function team_of(force)
  local name = force and force.name
  if not name then return nil end
  local pt = Storage.ns("pteam").team
  if pt and pt.force == name then return pt end
  return State.by_force(name)
end

---------------------------------------------------------------------------------------------------
-- Registre : événements
---------------------------------------------------------------------------------------------------
--- Le coffre sous un point (la cible d'un bras ou d'une foreuse). Banc 14 h : `drop_target` d'un bras posé par script rend nil (cible non encore
--- résolue : bras sans courant ou posé dans le tick), alors que `drop_position` est connu : on cherche le coffre à ce point.
local function chest_at(surface, pos)
  if not pos then return nil end
  local found = surface.find_entities_filtered({ area = { { pos.x - 0.2, pos.y - 0.2 }, { pos.x + 0.2, pos.y + 0.2 } }, type = "container" })
  table.sort(found, function(a, b) return (a.unit_number or 0) < (b.unit_number or 0) end)
  for _, c in ipairs(found) do
    if c.valid and c.unit_number then return c end
  end
  return nil
end

local function target_of(ent, entity_target, position)
  if entity_target and entity_target.valid then
    return (entity_target.type == "container" and entity_target.unit_number) and entity_target or nil
  end
  return chest_at(ent.surface, position)
end

--- Étudie un bras ou une foreuse : le coffre où il dépose (drop_target, sinon le coffre au point de dépôt) et celui où il prend (pickup_target,
--- sinon au point de prise ; bras seulement).
local function study_feeder(st, ent)
  local iuid = ent.unit_number
  if not iuid then return end
  S.unlink(st, iuid)
  local dt = target_of(ent, ent.drop_target, ent.drop_position)
  if dt then S.link(st, iuid, "feed", dt.unit_number) end
  if ent.type == "inserter" then
    local pt = target_of(ent, ent.pickup_target, ent.pickup_position)
    if pt then S.link(st, iuid, "take", pt.unit_number) end
  end
end

--- Étudie les bras et foreuses autour d'un coffre (une zone de 9 × 9 tuiles).
local function rescan_chest(st, ent)
  local p = ent.position
  local near = ent.surface.find_entities_filtered({
    area = { { p.x - Src.RADIUS, p.y - Src.RADIUS }, { p.x + Src.RADIUS, p.y + Src.RADIUS } }, type = FEED_TYPES, force = ent.force })
  table.sort(near, function(a, b) return (a.unit_number or 0) < (b.unit_number or 0) end)
  for _, e in ipairs(near) do
    if e.valid then study_feeder(st, e) end
  end
end

local function add_chest(st, ent)
  local uid = ent.unit_number
  if not uid then return nil end
  local known = st.chests[uid] ~= nil
  local p = ent.position
  local c = S.add_chest(st, uid, ent, p.x, p.y)
  if not known then rescan_chest(st, ent) end
  return c
end

local function on_built(e)
  local ent = e.created_entity or e.entity
  if not (ent and ent.valid) then return end
  local ty = ent.type
  if ty ~= "container" and ty ~= "inserter" and ty ~= "mining-drill" then return end
  local f = team_of(ent.force)
  if not (f and f.team and f.hq and f.hq.valid and Src.on(f)) then return end
  local st = reg_of(f)
  if ty == "container" then add_chest(st, ent) else study_feeder(st, ent) end
end

local function on_removed(e)
  local ent = e.entity
  if not (ent and ent.valid) then return end
  local ty = ent.type
  if ty ~= "container" and ty ~= "inserter" and ty ~= "mining-drill" then return end
  local f = team_of(ent.force)
  local st = f and f.team and f.team.sources
  if not (st and ent.unit_number) then return end
  if ty == "container" then S.remove_chest(st, ent.unit_number) else S.unlink(st, ent.unit_number) end
end

local function on_rotated(e)
  local ent = e.entity
  if not (ent and ent.valid and ent.type == "inserter") then return end
  local f = team_of(ent.force)
  local st = f and f.team and f.team.sources
  if st then study_feeder(st, ent) end
end

Events.on(defines.events.on_built_entity, on_built)
Events.on(defines.events.on_robot_built_entity, on_built)
Events.on(defines.events.script_raised_built, on_built)
Events.on(defines.events.script_raised_revive, on_built)
Events.on(defines.events.on_player_mined_entity, on_removed)
Events.on(defines.events.on_robot_mined_entity, on_removed)
Events.on(defines.events.script_raised_destroy, on_removed)
Events.on(defines.events.on_player_rotated_entity, on_rotated)
Events.on_died(on_removed, { types = { "container", "inserter", "mining-drill" }, ennemi = false })

---------------------------------------------------------------------------------------------------
-- Registre : reprise d'une sauvegarde, sorties déclarées, relecture du contenu
---------------------------------------------------------------------------------------------------
--- Reprise par tranches : une liste de coffres de la force (une seule recherche), étudiés S.SCAN_PER_THINK par pensée.
local function scan_step(f, st, surface)
  if st.scanned then return end
  if not st.todo then
    Profiler.fstart("ws:sources")
    st.todo = surface.find_entities_filtered({ force = f.force, type = "container" })
    Profiler.fstop("ws:sources")
    st.todo_i = 1
  end
  local n = 0
  while st.todo_i <= #st.todo and n < S.SCAN_PER_THINK do
    local ent = st.todo[st.todo_i]
    st.todo_i = st.todo_i + 1
    if ent.valid and ent ~= f.hq and ent.name ~= "fo-team-chest" then
      add_chest(st, ent)
      n = n + 1
    end
  end
  if st.todo_i > #st.todo then
    st.todo, st.todo_i, st.scanned = nil, nil, true
    log(string.format("[FO-SOURCES] %s : reprise de la sauvegarde finie : %d coffre(s) etudie(s), %d sortie(s) a %.1f min",
      f.key or "player", st.nchests, #S.sorties(st), (game.tick - (f.started or 0)) / 3600))
  end
end

--- Sorties DÉCLARÉES du plan directeur : le plan y dépose par construction (script/team/build.lua, p.outs).
local function declare_step(f, st, surface)
  local b = f.build
  if not (b and b.order and b.projects) then return end
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    for _, o in ipairs(p and p.outs or {}) do
      local ent = surface.find_entity(Src.CHEST, { o.x, o.y })
      if ent and ent.valid and ent.unit_number and ent.force.name == f.force then
        local c = st.chests[ent.unit_number] or add_chest(st, ent)
        if c then c.decl = true end
      end
    end
  end
end

--- Coffres à ne jamais compter : le coffre d'équipe et ses annexes (le stock), les réceptacles des avant-postes (lots FLUX et CHARBON-MAIN).
local function excluded_set(f)
  local ex = {}
  if f.hq and f.hq.valid and f.hq.unit_number then ex[f.hq.unit_number] = true end
  for _, e in ipairs(Stock.annexes(f)) do if e.unit_number then ex[e.unit_number] = true end end
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    for _, s in ipairs(f.outposts[oid].sinks or {}) do
      if s.valid and s.unit_number then ex[s.unit_number] = true end
    end
  end
  return ex
end

local function read_step(f, st, tick)
  for _, uid in ipairs(S.read_batch(st, S.READ_PER_THINK)) do
    local c = st.chests[uid]
    local ent = c and c.ent
    if not (ent and ent.valid) then
      S.remove_chest(st, uid)
    else
      S.set_content(st, uid, ent.get_inventory(defines.inventory.chest).get_contents(), TRACKED, tick)
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Décision
---------------------------------------------------------------------------------------------------
local function safe_fn(f, st, surface, tick)
  local cache = {}
  return function(uid)
    local v = cache[uid]
    if v == nil then
      local c = st.chests[uid]
      local pos = c and { x = c.x, y = c.y }
      v = true
      if pos then
        if surface.count_entities_filtered({ position = pos, radius = Poles.DANGER_RADIUS, force = "enemy", type = { "unit-spawner", "turret" }, limit = 1 }) > 0
          or (f.is_player and Poles.near_loss(f, pos, tick)) then
          v = false
        end
      end
      cache[uid] = v
    end
    return v
  end
end

local function key_of(item, uid) return "src:fetch:" .. item .. ":" .. tostring(uid) end

local function pause_fn(f, item, tick)
  local cd = Board.get(f).cooldown
  return function(uid)
    local until_t = cd[key_of(item, uid)]
    return until_t ~= nil and tick < until_t
  end
end

--- Décision pour la cible `x` : d'abord son produit (la plaque), puis la ressource elle-même (du minerai qui dort dans une sortie se fond au QG).
--- Rend la décision de S.decide, plus `item` (ce qu'on va chercher).
local WHY_RANK = { ["sortie dangereuse"] = 4, ["tournee en pause apres un echec"] = 3, ["sorties vides"] = 2, ["aucune sortie"] = 1 }

local function decide_for(f, st, x, ex, safe, tick, crisis)
  local at = f.hq_pos
  local skip = function(uid) return ex[uid] == true end
  local best
  local items = { x.item }
  if x.item ~= x.res then items[2] = x.res end
  for _, item in ipairs(items) do
    local d = S.decide({ rows = S.rows(st, item, at, skip), pause = pause_fn(f, item, tick), safe = safe, now = tick, crisis = crisis })
    d.item = item
    if d.act ~= "hand" then return d end
    if not best or (WHY_RANK[d.why] or 0) > (WHY_RANK[best.why] or 0) then best = d end
  end
  return best
end

--- Décision à jour pour la ressource minée `res` (nil : pas une ressource suivie). Lecture seule hors registre.
--- Le stock d'équipe (coffre + annexes, BRUT : sans réservation ni plafond) couvre-t-il ce minage ? Rend vrai, nature ("minerai" | "plaques"),
--- minerai et plaques au stock. (DC, 8/11 : du cuivre miné à la main avec des milliers de plaques au coffre ; Mi.hand_verdict ne lit que le minerai
--- et laisse passer toute tâche qui porte un manque `short`.)
local function stock_cover(f, x, count)
  local ore = Stock.count(f, x.res)
  local plate = x.plate and Stock.count(f, x.item) or nil
  local ok, what = S.stock_covers({ ore = ore, plate = plate, count = count })
  return ok, what, ore, plate
end

function Src.with_stock(f, x, d, count)
  local ok, what, ore, plate = stock_cover(f, x, count or 50)
  if ok then return { act = "stock", item = x.item, why = what, code = "stock_suffit", ore = ore, plate = plate } end
  return d
end

function Src.decision(f, res, tick, crisis, count, survie)
  local x = BY_RES[res]
  if not (x and Src.on(f) and f.team and f.team.sources and f.hq and f.hq.valid) then return nil end
  -- Les machines extraient déjà assez (D09, script/team/intermediaires.lua : f.team.inter.skip, état lu sans require) : une tâche déjà prise est barrée
  -- aussi (banc verif-guide, 8/11 : 2 minages de fer finis à 9,5 et 29,3 min après la coupure du fer à 1,9 min). Survie et crise exemptées.
  local inter = f.team.inter
  if not crisis and not survie and inter and inter.skip and inter.skip[res] then
    return { act = "machines", item = x.item, why = "machines", code = "machines_suffisent" }, x
  end
  local surface = f.hq.surface
  if not surface then return nil end
  local st = f.team.sources
  local d = decide_for(f, st, x, excluded_set(f), safe_fn(f, st, surface, tick), tick, crisis)
  if d.act == "hand" and not crisis then d = Src.with_stock(f, x, d, count) end
  return d, x
end

--- Minage à la main de `res` permis ? Rend ok, raison, texte pour le journal. Appelé par le programme d'un minage (script/team/worker.lua).
function Src.hand_ok(f, res, tick, crisis, count, survie)
  local d = Src.decision(f, res, tick, crisis, count, survie)
  if not d then return true, "rien", "" end
  -- Compteurs de la garde (lus par les bancs : combien de programmes de minage laissés / barrés, par ressource).
  local st = f.team.sources
  st.hand = st.hand or {}
  local h = st.hand[res] or { ok = 0, no = 0 }
  st.hand[res] = h
  if S.hand_ok(d) then
    h.ok = h.ok + 1
    return true, d.why or "rien", ""
  end
  h.no = h.no + 1
  local text = d.act == "machines"
    and "les machines de l'equipe extraient deja assez (D09)"
    or d.act == "stock"
    and string.format("le stock suffit (%s) : %d minerai, %s plaque(s)", tostring(d.why), d.ore or 0, tostring(d.plate))
    or d.act == "fetch"
    and string.format("prendre a la sortie %s@(%d,%d) : %d %s", tostring(d.row.uid), math.floor(d.row.x), math.floor(d.row.y), d.row.n, d.item)
    or string.format("sortie %s en marche (%s)", tostring(d.row.uid), d.item)
  return false, d.act, text
end

---------------------------------------------------------------------------------------------------
-- Journal
---------------------------------------------------------------------------------------------------
local function say(f, st, x, d, tick, stock_n)
  local sig
  if d.act == "fetch" then sig = "fetch:" .. d.item .. ":" .. tostring(d.row.uid)
  elseif d.act == "wait" then sig = "wait:" .. d.item .. ":" .. tostring(d.row.uid)
  elseif d.act == "stock" then sig = "stock:" .. tostring(d.why)
  else sig = "hand:" .. tostring(d.why) end
  if st.said[x.res] == sig then return end
  if st.said_t[x.res] and tick - st.said_t[x.res] < Src.LOG_EVERY then return end
  st.said[x.res], st.said_t[x.res] = sig, tick
  if st.logs >= Src.LOGS then return end
  st.logs = st.logs + 1
  local min = (tick - (f.started or 0)) / 3600
  if d.act == "fetch" then
    log(string.format("[FO-SOURCES] %s : prendre a la sortie %s@(%d,%d) : %d %s pour %s (stock %d, d=%d tuiles) a %.1f min",
      f.key or "player", tostring(d.row.uid), math.floor(d.row.x), math.floor(d.row.y), d.n, d.item, x.res, stock_n or 0,
      math.floor(math.sqrt(d.row.d2)), min))
  elseif d.act == "stock" then
    log(string.format("[FO-SOURCES] %s : pas de minage a la main de %s : le stock suffit (%s : %d minerai, %s plaque(s)) a %.1f min",
      f.key or "player", x.res, tostring(d.why), d.ore or 0, tostring(d.plate), min))
  elseif d.act == "wait" then
    log(string.format("[FO-SOURCES] %s : attendre la sortie %s@(%d,%d), en marche (son contenu monte) : pas de minage a la main de %s a %.1f min",
      f.key or "player", tostring(d.row.uid), math.floor(d.row.x), math.floor(d.row.y), x.res, min))
  else
    log(string.format("[FO-SOURCES] %s : extraire a la main %s : aucune source (%s) a %.1f min", f.key or "player", x.res, tostring(d.why), min))
  end
end

---------------------------------------------------------------------------------------------------
-- Pensée d'équipe (E4, avant le marché)
---------------------------------------------------------------------------------------------------
--- Rend le nombre de tâches libres retirées.
--- Libres sans rien à faire : la cause, une ligne [FO-RIEN-A-FAIRE] par minute au plus (lecture seule du tableau et du plan directeur).
local function idle_report(f, st, tick, idle)
  if (idle or 0) <= 0 or (st.idle_t and tick - st.idle_t < Src.LOG_EVERY) then return end
  local free, waiting = {}, {}
  local tasks = Board.get(f).tasks
  for _, key in ipairs(State.sorted_keys(tasks)) do
    local t = tasks[key]
    if not t.worker then free[t.kind] = (free[t.kind] or 0) + 1 end
  end
  local b = f.build
  for _, pid in ipairs(b and b.order or {}) do
    local p = b.projects[pid]
    if p and (p.state == "reserve" or p.progressif) and not p.abandoned and p.missing and #p.missing > 0 then -- (p.progressif : lot EXPANSION-LOINTAINE)
      waiting[#waiting + 1] = { pid = pid, ents = #(p.ents or {}), missing = p.missing }
    end
  end
  local c = S.idle_cause({ idle = idle, free = free, waiting = waiting })
  if not c then return end
  st.idle_t = tick
  st.idle = { code = c.code, tick = tick, n = idle } -- lu par la vue du cerveau : mot fixe
  if (st.idle_logs or 0) < Src.LOGS then
    st.idle_logs = (st.idle_logs or 0) + 1
    log(string.format("[FO-RIEN-A-FAIRE] %s : %d PNJ libre(s) : %s a %.1f min", f.key or "player", idle, c.text, (tick - (f.started or 0)) / 3600))
  end
end

function Src.think(f, tick, idle)
  if not (Src.on(f) and f.team and f.hq and f.hq.valid) then return 0 end
  idle_report(f, reg_of(f), tick, idle)
  local surface = f.hq.surface
  local st = reg_of(f)
  scan_step(f, st, surface)
  declare_step(f, st, surface)
  read_step(f, st, tick)
  local has_sorties = #S.sorties(st) > 0
  local ex = has_sorties and excluded_set(f) or {}
  local safe = safe_fn(f, st, surface, tick)
  local skip_item = Stock.skip_fn and Stock.skip_fn(f) or nil
  local covered, keep_fetch, add = {}, {}, {}
  for _, x in ipairs(TARGETS) do
    local d
    if has_sorties then d = decide_for(f, st, x, ex, safe, tick, false)
    else d = { act = "hand", why = "aucune sortie", code = "aucune_sortie", item = x.item } end
    local refused = d.act == "fetch" and skip_item and skip_item(d.item)
    if refused then
      -- Le stock refuse cet objet (saturé au plafond, coffre plein) : rien à rapporter, et aucune raison de le miner non plus.
      d = { act = "wait", row = d.row, item = d.item, n = 0, code = "stock_refuse" }
    end
    if d.act == "hand" then d = Src.with_stock(f, x, d, 50) end
    local stock_n = Stock.count(f, x.item)
    st.dec[x.res] = { act = d.act, item = d.item, uid = d.row and d.row.uid, n = d.n or (d.row and d.row.n) or 0, why = d.why,
      choix = (d.act == "fetch" or d.act == "wait") and "sortie" or (d.act == "stock" and "stock" or "main"),
      raison = d.act == "fetch" and "sortie" or (d.act == "wait" and (d.code or "en_marche")) or d.code or "aucune_sortie",
      d = d.row and math.floor(math.sqrt(d.row.d2)) or 0, tick = tick }
    if d.act ~= "hand" then covered[x.res] = true end
    if d.act == "fetch" then
      local room = Stock.room(f, d.item)
      local n = d.n
      if room ~= nil and room < n then n = room end
      if n >= S.MIN then
        local key = key_of(d.item, d.row.uid)
        keep_fetch[d.item] = key
        add[#add + 1] = { key = key, kind = "fetch", prio = S.PRIO, item = d.item, uid = d.row.uid, count = n, pos = { x = d.row.x, y = d.row.y },
          domain = "logistique", no_rush = true, res = x.res }
      end
    end
    if not refused then say(f, st, x, d, tick, stock_n) elseif st.said[x.res] ~= "stock-refuse" then
      st.said[x.res] = "stock-refuse"
      if st.logs < Src.LOGS then
        st.logs = st.logs + 1
        log(string.format("[FO-SOURCES] %s : pas de tournee pour %s : le stock refuse %s (sature ou plein), pas de minage a la main non plus a %.1f min",
          f.key or "player", x.res, d.item, (tick - (f.started or 0)) / 3600))
      end
    end
  end
  -- Retire les minages LIBRES des ressources couvertes (une crise injectée par un banc reste exemptée), ceux que le stock couvre pour LEUR fournée
  -- (quelle que soit la source qui les pose : ia3:, manque:, fond, survie, planificateur) et les tournées libres vers une autre sortie.
  local by_res = {}
  for _, x in ipairs(TARGETS) do by_res[x.res] = x end
  local stock_dropped = 0
  local dropped = Board.drop_free(f, function(t)
    if t.kind == "mine" and t.resource and not (type(t.key) == "string" and t.key:sub(1, 6) == "crise:") then
      if covered[t.resource] then return false end
      local x = by_res[t.resource]
      if x and select(1, stock_cover(f, x, t.count)) then
        stock_dropped = stock_dropped + 1
        return false
      end
    end
    if t.kind == "fetch" and t.item and keep_fetch[t.item] ~= t.key then return false end
    return true
  end)
  if #add > 0 then Board.add(f, add, tick) end
  st.dropped = (st.dropped or 0) + dropped
  st.dropped_stock = (st.dropped_stock or 0) + stock_dropped
  return dropped
end

---------------------------------------------------------------------------------------------------
-- Objets attendus du cerveau
---------------------------------------------------------------------------------------------------
--- Ajoute à `incoming` (view.incoming) ce que les tournées « fetch » rapporteront : plaques (ou ressource brute) des sorties sûres, bornées par la
--- place du coffre d'équipe. Lecture seule du registre ; le stock libre de la vue ne change pas.
function Src.incoming(f, incoming, tick)
  if not (Src.on(f) and f.team and f.team.sources and f.hq and f.hq.valid) then return incoming end
  local st = f.team.sources
  if st.nchests == 0 then return incoming end
  local surface = f.hq.surface
  local ex = excluded_set(f)
  local skip = function(uid) return ex[uid] == true end
  local safe = safe_fn(f, st, surface, tick)
  local skip_item = Stock.skip_fn and Stock.skip_fn(f) or nil
  for _, x in ipairs(TARGETS) do
    local items = { x.item }
    if x.item ~= x.res then items[2] = x.res end
    for _, item in ipairs(items) do
      if not (skip_item and skip_item(item)) then
        local rows = S.rows(st, item, f.hq_pos, skip)
        local n = S.fetchable(rows, safe, pause_fn(f, item, tick), Stock.room(f, item))
        if n > 0 then incoming[item] = (incoming[item] or 0) + n end
      end
    end
  end
  -- Plaques déjà prises à une sortie et en route vers le coffre : ni dans la sortie ni encore au stock (une seule fois comptées).
  local tasks = Board.get(f).tasks
  for _, key in ipairs(State.sorted_keys(tasks)) do
    local t = tasks[key]
    if t.kind == "fetch" and t.worker and t.got and t.got > 0 and t.item then incoming[t.item] = (incoming[t.item] or 0) + t.got end
  end
  return incoming
end

---------------------------------------------------------------------------------------------------
-- Tournée « fetch » : programme et acte (script/team/worker.lua)
---------------------------------------------------------------------------------------------------
--- Pas du programme : home, aller au coffre, le vider (dans la limite du sac et du stock), home (dépôt).
function Src.program(f, task)
  if not (task.pos and task.uid) then return nil end
  return { { "home" }, { "goto", task.pos, 3 }, { "act", "fetch" }, { "home" } }
end

function Src.act(agent, f, task, surface, tick)
  local st = f.team and f.team.sources
  local c = st and st.chests[task.uid]
  local ent = c and c.ent
  if not (ent and ent.valid) then
    if st and c then S.remove_chest(st, task.uid) end
    return false
  end
  if ent.force.name ~= f.force then -- propriété : jamais le coffre d'une autre force (une faction ne prend pas chez le joueur)
    S.remove_chest(st, task.uid)
    return false
  end
  local e = agent.entity
  local p, q = e.position, ent.position
  if (p.x - q.x) ^ 2 + (p.y - q.y) ^ 2 > Src.REACH * Src.REACH then return false end -- pas arrivé (chemin refusé) : la tournée échoue
  local inv = e.get_main_inventory()
  local cinv = ent.get_inventory(defines.inventory.chest)
  local want = math.min(task.count or S.TRIP_MAX, cinv.get_item_count(task.item), S.TRIP_MAX)
  local got = 0
  if want > 0 then
    local put = inv.insert({ name = task.item, count = want })
    if put > 0 then
      got = cinv.remove({ name = task.item, count = put })
      if got < put then inv.remove({ name = task.item, count = put - got }) end
    end
  end
  c.n[task.item] = cinv.get_item_count(task.item)
  c.read = tick
  if got <= 0 then
    st.empty = (st.empty or 0) + 1
    if st.empty <= 12 then
      log(string.format("[FO-SOURCES] %s : tournee a vide a la sortie %s@(%d,%d) : %d %s demande(s), %d en coffre, sac %s a %.1f min",
        f.key or "player", tostring(task.uid), math.floor(q.x), math.floor(q.y), task.count or 0, task.item, c.n[task.item],
        inv.can_insert({ name = task.item, count = 1 }) and "libre" or "plein", (tick - (f.started or 0)) / 3600))
    end
    return false
  end
  S.note_removed(st, task.uid, task.item, got) -- hors du débit mesuré
  task.got = got -- en route vers le coffre d'équipe : Src.incoming le compte jusqu'au dépôt (sinon un trou dans les objets attendus)
  st.trips = (st.trips or 0) + 1
  st.fetched = (st.fetched or 0) + got
  f.team.collected = (f.team.collected or 0) + got
  if st.trips <= 20 then
    log(string.format("[FO-SOURCES] %s : tournee faite : %d %s pris a la sortie %s@(%d,%d), %d restent, %d rapportes en tout (%d tournees) a %.1f min",
      f.key or "player", got, task.item, tostring(task.uid), math.floor(q.x), math.floor(q.y), c.n[task.item], st.fetched, st.trips,
      (tick - (f.started or 0)) / 3600))
  end
  return true
end

return Src
