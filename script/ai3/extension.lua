--[[
  Lot C3 EXTENSION, côté RUNTIME (règle pure : shared/ai3/extension.lua ; but émis par shared/ai3/buts.lua, B.releve).
  Appelé par Ia3.plan (script/ai3/cerveau.lua) après la pensée. Ne décide rien : il LIT la vue d'équipe, RANGE les grandeurs que lisent les
  autres modules et ÉCRIT le journal [FO-EXTENSION] (une ligne par changement de cause, jamais par pensée).

  État (f.team.ia3.ext, créé par B.releve dans une pensée, jamais à on_load ; nombres, chaînes et tables simples) :
    last, n_out, grown, why, log, seq : voir shared/ai3/extension.lua (Ex.new) ; écrits par Ex.releve, journal lu ici ;
    push      : une relève attend un site (écrit par B.releve) ; lu par script/ai3/exploration.lua (veille poussée) ;
    extent, radius, reach, def, per, total : étendue de la base (tuiles), rayon de base, portée de valeur (pour mille), capacité de
                défense, sites gardés par ressource et en tout ; écrits ici ; lus par script/faction/sites.lua et script/ai3/capitalisation.lua ;
    lost0, lost_seen, bilan_at, logs : mesure des morts de PNJ (f.stats.engineers_lost), journal borné.
  Journal : [FO-EXTENSION] <équipe> : <type> : but <cause> | attend : <raison> (<cause>) ; avant-postes, capacité, place, sites, délai d'allure.
  Bilan toutes les 10 min : avant-postes, extensions, emprise, rayon de base, sites, PNJ morts depuis le dernier bilan (critère SURVIE).
]]
local T = require("shared.team.config")
local Ex = require("shared.ai3.extension")
local State = require("script.faction.state")
local Rsv = require("script.ai3.reserve") -- réglage maître (fo-war-industrie) : éteint, les grandeurs rangées ne sont plus lues

local Ext = {}

Ext.LOGS = 120              -- lignes [FO-EXTENSION] au plus par équipe (bilans compris)
Ext.BILAN_EVERY = 10 * 3600 -- ticks entre deux bilans

local function minutes(f, tick)
  return tick / 3600
end

--- Grandeurs de la pensée rangées pour les autres modules (étendue, rayon de base, portée, capacité de défense, sites gardés).
local function measure(f, view, es)
  local d2, defended = {}, 0
  for _, o in ipairs(view.outposts or {}) do
    d2[#d2 + 1] = o.d2 or 0
    if (o.turrets or 0) >= T.defend_turrets(o.drills) then defended = defended + 1 end
  end
  es.extent = Ex.extent(d2)
  es.radius = Ex.base_radius(es.extent)
  es.reach = Ex.reach_bonus(es.extent)
  es.def = Ex.defense_capacity(defended, view.soldiers)
  es.per, es.total = Ex.site_limits(es.def)
end

--- Pensée finie : mesures, journal. `st` = f.team.ia3.
function Ext.after(f, view, st, tick)
  local es = st.ext
  if not es then return end
  measure(f, view, es)
  es.logs = es.logs or 0
  for _, e in ipairs(es.log or {}) do
    if e.seq > (es.log_seen or 0) then
      es.log_seen = e.seq
      es.logs = es.logs + 1
      if es.logs <= Ext.LOGS then
        log(string.format("[FO-EXTENSION] %s : %s a %.1f min", f.key or "?", e.text, minutes(f, e.tick)))
      end
    end
  end
  if tick - (es.bilan_at or 0) >= Ext.BILAN_EVERY then
    es.bilan_at = tick
    local lost = (f.stats and f.stats.engineers_lost) or 0
    local d = lost - (es.lost_seen or 0)
    es.lost_seen = lost
    es.logs = es.logs + 1
    if es.logs <= Ext.LOGS then
      log(string.format("[FO-EXTENSION] bilan %s a %.1f min : %d avant-poste(s), %d gagne(s) depuis le debut, emprise %d tuiles (rayon de base %d, portee x%.2f), "
        .. "sites gardes %d par ressource et %d en tout (defense %d), PNJ morts depuis le dernier bilan %d (total %d), relevee %s",
        f.key or "?", minutes(f, tick), es.n_out or 0, es.grown or 0, es.extent or 0, es.radius or 0, (es.reach or 1000) / 1000,
        es.per or 0, es.total or 0, es.def or 0, d, lost, es.push and "attend un site" or "non"))
    end
  end
end

--- Le lot est-il allumé ? (réglage maître fo-war-industrie)
function Ext.on() return Rsv.on() end

--- Une relève attend-elle un site ? (écrit par B.releve à chaque pensée ; lu par la veille de script/ai3/exploration.lua)
function Ext.push(f)
  local es = Ext.info(f)
  return es ~= nil and es.push == true
end

--- Grandeurs rangées par la pensée, ou nil (équipe sans cerveau, réglage maître éteint) : lu par les sites, la capitalisation, la veille.
function Ext.info(f)
  if f.is_player or not Rsv.on() then return nil end
  local ia3 = f.team and f.team.ia3
  return ia3 and ia3.ext or nil
end

---------------------------------------------------------------------------------------------------
-- Interface distante « fo-ext » : LECTURE de l'état (bancs), et quatre écritures de BANC seulement (cadre du scénario, jamais une décision)
---------------------------------------------------------------------------------------------------
local function team_of(key)
  if key == "player" then return State.faction("player") end
  local war = State.war()
  for _, id in ipairs(State.sorted_keys(war and war.factions or {})) do
    local f = war.factions[id]
    if f.key == key then return f end
  end
  return nil
end

local function copy_list(t)
  local out = {}
  for i, v in ipairs(t or {}) do out[i] = v end
  return out
end

remote.add_interface("fo-ext", {
  --- État de la relève d'une équipe : { hq, outposts = { { id, kind, drills, full, x, y, turrets } }, ext = { … }, sites = { [type] = n }, lost, build }.
  status = function(key)
    local f = team_of(key)
    if not (f and f.hq_pos) then return nil end
    local out = { hq = { x = f.hq_pos.x, y = f.hq_pos.y }, outposts = {}, sites = {}, lost = (f.stats and f.stats.engineers_lost) or 0,
      workers = f.engineers_count or 0, soldiers = f.soldiers_count or 0 }
    for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
      local o = f.outposts[oid]
      out.outposts[#out.outposts + 1] = { id = oid, kind = o.kind, drills = o.drills, full = o.full == true, x = o.pos.x, y = o.pos.y,
        turrets = #(o.turret_list or {}) }
    end
    local es = f.team and f.team.ia3 and f.team.ia3.ext
    if es then
      out.ext = { n_out = es.n_out, grown = es.grown, last = es.last, push = es.push, extent = es.extent, radius = es.radius,
        reach = es.reach, def = es.def, per = es.per, total = es.total, log = copy_list(es.log), why = {} }
      for _, kind in ipairs(T.OUTPOST_ORDER) do out.ext.why[kind] = es.why[kind] end
    end
    for _, kind in ipairs(T.OUTPOST_ORDER) do out.sites[kind] = #(f.prospects or {}) > 0 and (function()
      local n = 0
      for _, p in ipairs(f.prospects) do if p.resource == T.outposts[kind].resource then n = n + 1 end end
      return n
    end)() or 0 end
    local b = f.build
    if b then
      out.build = { radius = b.radius, enc = b.enc ~= nil, complete = b.enc and b.enc.complete == true or false, gate = b.ext_gate,
        islands = b.ilots and #b.ilots.list or 0 }
      local walled, lots_out, free = 0, 0, 0
      for _, il in ipairs(b.ilots and b.ilots.list or {}) do if il.complete then walled = walled + 1 end end
      local keys = State.sorted_keys(b.lots)
      for _, k in ipairs(keys) do
        local l = b.lots[k]
        if l.out then lots_out = lots_out + 1 end
        if (l.state == "libre" or l.state == "defricher") and not l.used and not l.out and not (l.i == 0 and l.j == 0) then free = free + 1 end
      end
      out.build.walled, out.build.lots_out, out.build.lots, out.build.free = walled, lots_out, #keys, free
      out.build.projects = {}
      for _, pid in ipairs(b.order) do
        local p = b.projects[pid]
        if p then out.build.projects[#out.build.projects + 1] = pid .. ":" .. tostring(p.state) .. (p.reason and ("/" .. tostring(p.reason)) or "") end
      end
    end
    return out
  end,
  --- BANC : marque pleins tous les avant-postes d'un type (le gisement est « couvert » : la relève se déclenche sans attendre la pose).
  set_full = function(key, kind)
    local f = team_of(key)
    if not f then return nil end
    local n = 0
    for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
      local o = f.outposts[oid]
      if o.kind == kind then
        o.full, o.full_by, o.full_why = true, "banc", "gisement"
        n = n + 1
      end
    end
    return n
  end,
  --- BANC : date du dernier gain d'avant-poste (l'allure d'extension est échue quand tick - last >= Ex.interval).
  set_last = function(key, tick)
    local f = team_of(key)
    local es = f and f.team and f.team.ia3 and f.team.ia3.ext
    if not es then return nil end
    es.last = tick
    return es.last
  end,
  --- BANC : enceinte complète à contour serré, sans murs (Build.stage_enclosure).
  stage_enclosure = function(key)
    local f = team_of(key)
    local Build = package.loaded["script.team.build"]
    if not (f and f.build and Build and Build.stage_enclosure) then return nil end
    local r = Build.stage_enclosure(f, game.tick)
    return r and { bounds = r.bounds, out = r.out } or nil
  end,
  --- BANC : relevé des îlots tout de suite (au lieu de toutes les Il.SCAN_TICKS).
  ilots_scan_now = function(key)
    local f = team_of(key)
    local h = f and f.build and f.build.ilots
    if not h then return nil end
    h.scan_next = 0
    return true
  end,
})

return Ext
