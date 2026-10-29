--[[
  Lot ILOTS-MURS, côté RUNTIME (règle pure : shared/team/ilots.lua). Arbitrage du DC (QCU du 29/10) : les lots lointains isolés restent
  « hors du mur mais potentiellement l'entourer d'un mur et d'une ou 2 tourelle » ; la dépense suit par extension « Oui, ressources
  d'abord » (arbitrage de la faction ruinée sans tourelle, même QCU ; voir shared/team/ilots.lua).

  Trois services :
    - Il.step(f, surface, tick, ctx) : appelé par Build.space_step (script/team/build.lua) toutes les Enc.CHECK_TICKS. Il retient les îlots
      importants (lots bâtis hors du contour figé de l'enceinte), puis demande leurs murs SEGMENT par SEGMENT, avec la machinerie de
      l'enceinte (projets « enceinte » du plan directeur, ctx.request), seulement quand l'enceinte principale est COMPLÈTE et sans chantier
      (ctx.main_busy), un segment à la fois, payé au plus un quart du stock (Enc.segment_cap). Murs détruits : segment rouvert (ctx.repair,
      la réparation de l'enceinte appliquée à b.ilots).
    - Il.view(f, fortify_open, iron) : vue des tourelles des îlots pour le planificateur permanent (shared/team/planner.lua, poste « ilot »,
      FACULTATIF : hors du coût de la défense, jamais en « production d'abord », planchers doublés).
    - Il.place(f, surface, task, carrier) : pose, depuis l'inventaire du PNJ, les tourelles de la tâche « fortify » du poste « ilot » dans
      l'emprise de l'îlot (Outposts.fortify_at ; groupe de ravitaillement « oilot<clé> » : un îlot, un groupe).

  État (f.build.ilots, créé dans un événement, jamais à on_load ; nombres, chaînes et tables simples) :
    list = { { key, box = { x0, y0, x1, y1 }, value, plant, claimed = { [Enc.key] = true }, complete, retry, created, attack0 } }
      écrit par discover / next_wall / seg_failed ; lu par next_wall (murs), Il.view (tourelles), Il.report (Build.report) ;
    segs = { { pid, n, side, ilot } } : écrit par next_wall / seg_failed / la réparation ; lu par active, seg_failed, ctx.repair (repair_enclosure) ;
    repair_at, cur_s, cur_e : curseur de la réparation (écrits et lus par repair_enclosure de script/team/build.lua) ;
    rest = { [clé] = tick }, zero = { [clé] = n } : écrits par Il.place (pose à zéro), rest lu par Il.view, zero par Il.place (repos
      allongé) ; pause_until : écrit par Il.on_lost, lu par Il.view ;
    scan_next : écrit et lu par discover ; poor, why : écrits et lus par next_wall / discover (une ligne de journal par changement) ;
    logs, poses, status : compteurs du journal, lus par ilog et Il.view.
  Journal : [FO-ILOT] (une ligne par cause : îlot retenu, rien à retenir, segment demandé, segment refusé, mur complet, stock insuffisant,
  pose de tourelles, porteur tué, état périodique).
  Déterminisme : listes triées, aucun `pairs` dans les décisions, aucun temps mesuré.
]]
local T = require("shared.team.config")
local D = require("shared.team.automatisation_donnees")
local Enc = require("shared.team.enceinte")
local I = require("shared.team.ilots")
local Fr = require("shared.team.front")
local P = require("shared.team.plan")
local State = require("script.faction.state")
local Outposts = require("script.faction.outposts")

local Il = {}

Il.LOGS = 80                 -- lignes [FO-ILOT] au plus par équipe (les poses et les états périodiques en plus, bornés eux aussi)
Il.SCAN_TICKS = 18000        -- ticks (5 min) : relevé des îlots candidats
Il.REST_TICKS = 10 * 3600    -- repos d'un îlot dont la dernière pose n'a rien posé (lot plein : pas de place dans l'emprise), multiplié
Il.REST_MAX = 6              -- ... par le nombre de poses à zéro de suite, au plus 6 (une heure) : pas d'aller-retour inutile des PNJ
Il.STATUS_EVERY = 5 * 3600   -- ticks : une ligne d'état des tourelles au plus
Il.OID = "ilot"              -- préfixe du poste des tourelles posées (State.own : « ilot<clé> »)

local function sorted_keys(t)
  local out = {}
  for k in next, t do out[#out + 1] = k end
  table.sort(out)
  return out
end

local function ilog(h, text)
  h.logs = (h.logs or 0) + 1
  if h.logs <= Il.LOGS then log(text) end
end

local function hq_of(b) return { x = b.lat.ox + 0.5, y = b.lat.oy + 0.5 } end

--- Cellules attaquées de la mémoire du front (script/team/front.lua, f.front_mem) : { { x, y, score } }. Lecture seule (la décroissance
--- est faite par Front.view à chaque pensée).
local function front_cells(f)
  local st = f.front_mem
  local mem = st and st.mem
  if not (mem and mem.cells) then return {} end
  return Fr.top(mem, 64, 1)
end

--- Segment d'îlot en cours (demandé, ni fini ni refusé) : numéro dans h.segs, ou nil.
local function active(b, h)
  for i, sg in ipairs(h.segs) do
    local p = b.projects[sg.pid]
    if p and p.state ~= "fini" and p.state ~= "refuse" then return i end
  end
  return nil
end

local function find(h, key)
  for _, il in ipairs(h.list) do if il.key == key then return il end end
  return nil
end

--- Valeur d'un projet fini : pièces bâties (murs exclus) + bonus de centrale (D.PLANT : la donnée, jamais un nom).
local function project_value(p)
  local n = 0
  for _, e in ipairs(p.ents or {}) do
    if e.built and not e.dropped and not e.wall then n = n + 1 end
  end
  local plant = p.spec ~= nil and p.spec.gen == D.PLANT.gen
  return I.value(n, plant), plant
end

--- Un segment refusé ou annulé : tuiles rendues si c'est la matière ou la place (nouvel essai plus tard), gardées sinon (pas de boucle).
local function seg_failed(f, h, i, p, tick)
  local sg = h.segs[i]
  local why = p and p.reason or "projet perdu"
  local transient = p == nil or why == "materiaux" or why == "place" or why == "enceinte annulee"
  table.remove(h.segs, i)
  h.cur_s, h.cur_e = nil, nil
  local il = find(h, sg.ilot)
  if il and transient then
    if p and p.spec and p.spec.walls then
      local list = {}
      for _, w in ipairs(p.spec.walls) do list[#list + 1] = { tx = w[1], ty = w[2] } end
      Enc.claim(il.claimed, list, nil)
    end
    il.complete = nil
    il.retry = tick + Enc.SEG_RETRY_TICKS
  end
  ilog(h, string.format("[FO-ILOT] %s : segment de l'ilot %s refuse (%s)%s a %.1f min", f.key or "player", tostring(sg.ilot), tostring(why),
    transient and " : tuiles rendues, nouvel essai dans 5 min" or " : tuiles non murables, gardees", tick / 3600))
end

--- Relevé des îlots : lots pris par un projet FINI, hors du contour de l'enceinte (I.outside) et hors des îlots déjà retenus ; regroupés
--- (I.clusters) ; le plus prioritaire des importants est retenu (I.pick_new). Un îlot par relevé.
local function discover(f, h, tick)
  local b = f.build
  if #h.list >= I.MAX or tick < (h.scan_next or 0) then return end
  h.scan_next = tick + Il.SCAN_TICKS
  local bounds = b.enc and b.enc.bounds
  if not bounds then
    if h.why ~= "rayon" then
      h.why = "rayon"
      ilog(h, string.format("[FO-ILOT] %s : enceinte sans contour serre (anneau du rayon, sauvegarde d'avant ENCEINTE3) : aucun lot dehors, aucun ilot", f.key or "player"))
    end
    return
  end
  local cands, values = {}, {}
  for _, k in ipairs(sorted_keys(b.lots)) do
    local l = b.lots[k]
    local p = l.used and b.projects[l.used]
    if p and p.state == "fini" and not (p.spec and p.spec.enceinte) then
      local x0, y0, x1, y1 = P.lot_rect(b.lat, l.i, l.j)
      local r = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
      local covered = false -- lot déjà dans l'emprise figée d'un îlot retenu
      for _, il in ipairs(h.list) do
        if x0 >= il.box.x0 and y0 >= il.box.y0 and x1 <= il.box.x1 and y1 <= il.box.y1 then covered = true break end
      end
      if not covered and I.outside(bounds, r) then
        local v = values[p.id]
        if not v then
          local val, plant = project_value(p)
          v = { val, plant }
          values[p.id] = v
        end
        cands[#cands + 1] = { k = k, x0 = x0, y0 = y0, x1 = x1, y1 = y1, pid = p.id, value = v[1], plant = v[2] }
      end
    end
  end
  local clusters = I.clusters(cands)
  local pick, why, rows = I.pick_new(clusters, h.list, front_cells(f), hq_of(b), I.MAX, bounds) -- (relecture : emprise entièrement dehors)
  if not pick then
    if why ~= h.why then
      h.why = why
      ilog(h, string.format("[FO-ILOT] %s : aucun ilot retenu (%s) : %d lot(s) bati(s) hors de l'enceinte en %d groupe(s), %d ilot(s) deja retenu(s) a %.1f min",
        f.key or "player", tostring(why), #cands, #clusters, #h.list, tick / 3600))
    end
    return
  end
  h.why = nil
  h.list[#h.list + 1] = { key = pick.key, box = { x0 = pick.box.x0, y0 = pick.box.y0, x1 = pick.box.x1, y1 = pick.box.y1 },
    value = pick.value, plant = pick.plant or nil, claimed = {}, created = tick, attack0 = pick.attack }
  local cx, cy = I.center(pick.box)
  ilog(h, string.format("[FO-ILOT] %s : ilot %s retenu (%d lot(s), emprise %d,%d a %d,%d, a %.0f tuiles du QG ; valeur %d%s ; attaque %d) a %.1f min ; %d admissible(s), %d ilot(s) retenu(s) sur %d",
    f.key or "player", pick.key, #(pick.lots or {}), pick.box.x0, pick.box.y0, pick.box.x1, pick.box.y1,
    math.max(math.abs(cx - b.lat.ox), math.abs(cy - b.lat.oy)), pick.value or 0, pick.plant and " (centrale)" or "",
    pick.attack or 0, tick / 3600, #rows, #h.list, I.MAX))
end

--- Segment suivant : l'îlot à murer le plus prioritaire (attaqué d'abord, I.sort), son tronçon tourné vers l'attaque ou vers l'extérieur.
local function next_wall(f, h, tick, ctx)
  local b = f.build
  local cells = front_cells(f)
  local hq = hq_of(b)
  local rows = {}
  for _, il in ipairs(h.list) do
    if not il.complete and tick >= (il.retry or 0) then
      local a, at = I.attack(il.box, cells)
      rows[#rows + 1] = { key = il.key, box = il.box, value = il.value, attack = a, at = at, il = il }
    end
  end
  if #rows == 0 then return end
  I.sort(rows, hq)
  local equiv = ctx.equiv()
  local cap = Enc.segment_cap(equiv)
  for _, r in ipairs(rows) do
    local il = r.il
    local runs = Enc.split_runs(I.ring(il.box, b.lat))
    local order, refs = I.run_order(runs, I.ref_point(il.box, hq, r.at))
    local seg, why = Enc.next_segment(runs, order, il.claimed, cap, refs)
    if seg then
      local tiles = {}
      for _, w in ipairs(seg.walls) do tiles[#tiles + 1] = { w.tx, w.ty } end
      local id, rwhy = ctx.request({ enceinte = true, ilot = il.key, walls = tiles, side = seg.side, prio = ctx.prio, domain = "infrastructures" })
      if not id then
        ilog(h, string.format("[FO-ILOT] %s : segment de l'ilot %s non demande (%s)", f.key or "player", il.key, tostring(rwhy)))
        return
      end
      Enc.claim(il.claimed, seg.walls, true)
      h.segs[#h.segs + 1] = { pid = id, n = #seg.walls, side = "ilot " .. il.key .. " " .. seg.side, ilot = il.key }
      h.poor = nil
      ilog(h, string.format("[FO-ILOT] %s : segment de l'ilot %s demande (projet %d, cote %s, %d murs, stock equivalent %d murs, attaque %d%s) a %.1f min",
        f.key or "player", il.key, id, seg.side, #seg.walls, equiv, r.attack or 0, r.at and " : cote de l'attaque d'abord" or "", tick / 3600))
      return
    elseif why == "complet" then
      il.complete = true
      ilog(h, string.format("[FO-ILOT] %s : mur de l'ilot %s complet (%d segment(s) demande(s)) a %.1f min", f.key or "player", il.key,
        (function() local n = 0 for _, sg in ipairs(h.segs) do if sg.ilot == il.key then n = n + 1 end end return n end)(), tick / 3600))
    else
      if not h.poor then
        h.poor = true
        ilog(h, string.format("[FO-ILOT] %s : mur de l'ilot %s attendu : stock equivalent %d murs, un quart = %d (minimum %d) : les ressources d'abord",
          f.key or "player", il.key, equiv, cap, Enc.SEG_MIN))
      end
      return
    end
  end
end

--- Pas des îlots (Build.space_step, après l'enceinte principale). ctx = { equiv = function() -> murs en stock + fabricables,
--- request = function(spec) -> id ou nil, raison ; cancel = function(pid, raison) ; repair = function(hold) ; main_busy = vrai si un
--- segment de l'enceinte principale est en cours ; prio = priorité des projets de murs }.
function Il.step(f, surface, tick, ctx)
  local b = f.build
  local enc = b.enc
  local h = b.ilots
  if not h then
    if not (enc and enc.complete) then return end
    h = { list = {}, segs = {}, logs = 0, poses = 0 }
    b.ilots = h
  end
  -- segments refusés (plan refusé, annulé) : le dernier d'abord, les numéros restent valables
  for i = #h.segs, 1, -1 do
    local p = b.projects[h.segs[i].pid]
    if not p or p.state == "refuse" then seg_failed(f, h, i, p, tick) end
  end
  -- matière absente depuis 5 min : segment annulé (il bloquerait les autres)
  local ai = active(b, h)
  if ai then
    local p = b.projects[h.segs[ai].pid]
    if p and Enc.reserve_stalled(p.state, p.started, p.finished, tick) then ctx.cancel(p.id, "materiaux") end
  end
  ctx.repair(h)
  -- l'enceinte principale d'abord (complète, sans chantier ni réparation en cours), puis un segment d'îlot à la fois
  if not (enc and enc.complete) or ctx.main_busy then return end
  if active(b, h) then return end
  discover(f, h, tick)
  next_wall(f, h, tick, ctx)
end

--- Rapport (Build.report) : nombre d'îlots retenus, murs complets, segments, tourelles posées.
function Il.report(b)
  local h = b and b.ilots
  if not h then return nil end
  local complete, rows = 0, {}
  for _, il in ipairs(h.list) do
    if il.complete then complete = complete + 1 end
    rows[#rows + 1] = { key = il.key, box = { il.box.x0, il.box.y0, il.box.x1, il.box.y1 }, value = il.value, complete = il.complete == true }
  end
  return { islands = #h.list, complete = complete, segments = #h.segs, poses = h.poses or 0, list = rows }
end

---------------------------------------------------------------------------------------------------
-- Tourelles
---------------------------------------------------------------------------------------------------
local function turrets_of(f)
  local list, placed = {}, 0
  for _, id in ipairs(State.sorted_keys(f.turrets or {})) do
    local t = f.turrets[id]
    if t.valid then
      list[#list + 1] = { x = t.position.x, y = t.position.y }
      local o = State.owner(id)
      if o and type(o.oid) == "string" and o.oid:sub(1, #Il.OID) == Il.OID then placed = placed + 1 end
    end
  end
  return list, placed
end

function Il.view(f, fortify_open, iron)
  local b = f.build
  local h = b and b.ilots
  if not (h and #h.list > 0) then return nil end
  local tick = game.tick
  local turrets, placed = turrets_of(f)
  local cells = front_cells(f)
  local list = {}
  for _, il in ipairs(h.list) do
    local a, at = I.attack(il.box, cells)
    list[#list + 1] = { key = il.key, box = il.box, value = il.value, attack = a, at = at, rest = ((h.rest or {})[il.key] or 0) > tick }
  end
  local plan = I.plan_turrets(list, turrets, placed, hq_of(b))
  local fi, fc = I.floors(T.defend_iron_floor, T.defend_copper_floor)
  local pause = (h.pause_until or 0) > tick
  if tick - (h.status or -Il.STATUS_EVERY) >= Il.STATUS_EVERY then
    h.status = tick
    local parts = {}
    for _, r in ipairs(plan.rows) do parts[#parts + 1] = string.format("%s %d/%d%s (%s)", r.key, r.have, r.want, r.attack >= I.ATTACK_MIN and " attaque" or "", r.skip or "?") end
    log(string.format("[FO-ILOT] %s : tourelles des ilots a %.1f min : %s ; posees %d sur %d au plus, tache ouverte %s, pause %s, fer au stock %s (plancher %d)",
      f.key or "player", tick / 3600, table.concat(parts, " ; "), placed, I.TEAM_MAX, tostring(fortify_open and fortify_open["ilot"] or false),
      tostring(pause), tostring(iron or "?"), fi))
  end
  return { pick = (not pause) and plan.pick or nil, busy = fortify_open and fortify_open["ilot"] or false, floor_i = fi, floor_cu = fc }
end

function Il.place(f, surface, task, carrier)
  local box = task.box
  if not (box and task.ilot) then return 0 end
  local n = Outposts.fortify_at(f, surface, Il.OID .. tostring(task.ilot), task.sites or {}, task.items[1][2], carrier,
    function(pos) return I.accepts(box, pos.x, pos.y) end)
  local h = f.build and f.build.ilots
  if h then
    local tick = game.tick
    h.poses = (h.poses or 0) + n
    h.rest, h.zero = h.rest or {}, h.zero or {}
    h.zero[task.ilot] = n == 0 and math.min(Il.REST_MAX, (h.zero[task.ilot] or 0) + 1) or nil
    h.rest[task.ilot] = n == 0 and tick + Il.REST_TICKS * h.zero[task.ilot] or nil
    ilog(h, string.format("[FO-ILOT] %s : pose de %d tourelle(s) sur %d demandee(s) a l'ilot %s a %.1f min (cumul %d)%s",
      f.key or "player", n, task.items[1][2], tostring(task.ilot), tick / 3600, h.poses,
      n == 0 and string.format(" : aucune place dans l'emprise, ilot au repos %d min", Il.REST_TICKS * h.zero[task.ilot] / 3600) or ""))
  end
  return n
end

--- Porteur tué en allant poser les tourelles d'un îlot : pause du poste (comme un avant-poste meurtrier, T.lethal_ticks).
function Il.on_lost(f, agent_id, cause)
  local h = f.build and f.build.ilots
  if not h then return end
  local tick = game.tick
  h.pause_until = tick + T.lethal_ticks
  ilog(h, string.format("[FO-ILOT] %s : PNJ %s tue en allant poser les tourelles d'un ilot (%s) a %.1f min ; pause jusqu'a %.1f min",
    f.key or "player", tostring(agent_id), tostring(cause), tick / 3600, h.pause_until / 3600))
end

return Il
