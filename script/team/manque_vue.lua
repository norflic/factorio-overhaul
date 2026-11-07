--[[
  Lot VIDEO-L3 (étape 4 de fo-logs/2026-11-07_VIDEO-AUTOMATISATION/INTEGRATION_VIDEO.md) : le MANQUE MESURÉ, côté moteur. La règle est
  PURE : shared/ai3/manque_local.lua (tests/manque_local_test.lua) ; ici seulement les relevés et l'état. Appelé par Team.view
  (script/team/team.lua) une fois par pensée ; ne calcule qu'une fois par Mv.PERIOD et rend sinon le dernier résultat.

  Relevés (lecture seule, aucune entité écrite) :
    modules  : les projets « fini » du plan directeur qui ont des quais et un débit nominal d'entrée (p.inflow, objets/s : g.inputs de
               M.analyze, build.lua, la même source que les quotas de L4) ; au plus Mv.MODS_MAX par relevé (tourniquet Mq.slice) ;
               `have` = contenu des quais, `power` = faux si toutes les machines de la première partie sont sans courant ;
    sorties  : Col.waiting_all (script/team/collecte.lua), tous objets, sûreté et collecte prise ou non ;
    transit  : les tâches « fill » PRISES des quais (réservées au registre, donc déjà hors du stock libre), et l'inventaire du PNJ qui
               les porte, sous la même clé de tâche (Mq les dédoublonne) ;
    demandes : le manque de l'objectif (f.team.missing, NET du stock : `net = true`), la réserve de fer sous l'effectif de départ
               (T.grow_iron_reserve, à Co.PRIO comme l'ancienne collecte d'urgence) et l'équipement d'une recrue décidée (factions :
               la règle d'effectif ; coût NET du stock) ;
    stock    : le stock LIBRE de la vue (Board.view_stock), jamais modifié.
  Ce que la vue en reçoit (Team.view) : view.mq (le résultat), view.avail_out (sorties dont la collecte est prise), view.dort (sorties
  qui dorment). JAMAIS ajouté à view.stock : piège du lot FLUX (Écarlate de 30 686 à 14 074 plaques).
  Lecteurs : Col.apply (collecte, f.team.mq.res.collect), Survie.think (script/team/survie.lua : view.mq.need, view.mq.build), la
  capitalisation (script/ai3/capitalisation.lua, build_input : Mq.sinks).

  État : f.team.mq = { mq = Mq.new() (curseur, horloges), reads = { [projet] = relevé }, tick, res, said, logs } : nombres, chaînes et
  tables (global, pour que tous les pairs suivent la même collecte) ; créé à la première vue, jamais dans on_load.
  Déterminisme : projets dans l'ordre de b.order, tâches par clé triée, aucun hasard, aucune horloge mesurée.
]]
local T = require("shared.team.config")
local Mq = require("shared.ai3.manque_local")
local Co = require("shared.team.collecte")
local Col = require("script.team.collecte")
local Registry = require("script.companion.registry")

local Mv = {}

Mv.ENABLED = true     -- faux : aucune lecture, view.mq absent (la règle d'avant partout)
Mv.PERIOD = 3600      -- ticks entre deux calculs (1 min : Mq.H_NEED)
Mv.MODS_MAX = 64      -- modules relus par calcul (tourniquet au-delà)
Mv.PRIO_GOAL = 55     -- priorité du manque de l'objectif hors survie (Build.PRIO : celle d'une collecte ordinaire)
Mv.LOGS = 24          -- lignes [FO-MQ] au plus par équipe

local PLATE = T.outposts.iron.product
local CHEST = T.outposts.coal.sink -- coffre des quais et des sorties du plan directeur (comme script/team/collecte.lua)
local MACHINES = { "assembling-machine", "furnace" } -- TYPES de prototypes (pas des noms d'objets) des machines d'un module
local NO_POWER -- constante du moteur, lue au premier relevé (jamais dans global)

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

local function is_module(p)
  return p ~= nil and p.state == "fini" and type(p.inflow) == "table" and next(p.inflow) ~= nil and type(p.quais) == "table" and #p.quais > 0
end

local function in_part(pt, pos) return pos.x > pt.ox and pos.x < pt.ox + pt.w and pos.y > pt.oy and pos.y < pt.oy + pt.h end

--- Relevé d'un module : { id, power, have, inputs, read_tick, prio } (Mq.step, input.mods).
function Mv.read_module(f, surface, p, tick)
  if not NO_POWER then NO_POWER = defines.entity_status.no_power end
  local have = {}
  for _, q in ipairs(p.quais) do
    if type(q.item) == "string" then
      local c = surface.find_entity(CHEST, { q.x, q.y })
      have[q.item] = (have[q.item] or 0) + ((c and c.valid) and c.get_item_count(q.item) or 0)
    end
  end
  local inputs = {}
  for _, k in ipairs(sorted_keys(p.inflow)) do
    local r = p.inflow[k]
    inputs[#inputs + 1] = { item = k, rate = type(r) == "number" and r * 60 or nil } -- objets/s -> objets/min ; absent : refusé par Mq
  end
  -- Courant : vrai dès qu'une machine du module n'est pas « sans courant » ; faux si toutes le sont ; inconnu (nil, refusé par Mq) sans machine.
  local power
  local pt = p.parts and p.parts[1]
  if pt and pt.ox then
    local found = surface.find_entities_filtered({ area = { { pt.ox, pt.oy }, { pt.ox + pt.w, pt.oy + pt.h } }, type = MACHINES, force = f.force })
    for _, m in ipairs(found) do
      if m.valid and in_part(pt, m.position) then -- F96 : une machine voisine qui touche seulement le bord ne compte pas
        if m.status ~= NO_POWER then power = true break end
        power = false
      end
    end
  end
  return { id = p.id, power = power, have = have, inputs = inputs, read_tick = tick, prio = p.prio }
end

--- Transit vers les quais : tâches « fill » prises, et l'inventaire de leur PNJ (même clé).
function Mv.transit(f)
  local out = {}
  local tasks = (f.team and f.team.board and f.team.board.tasks) or {}
  for _, key in ipairs(sorted_keys(tasks)) do
    local t = tasks[key]
    local it = t.items and t.items[1]
    if t.worker and t.ia1d and t.ia1d.mode == "fill" and it and type(it[1]) == "string" then
      out[#out + 1] = { task = key, module = t.ia1d.pid, item = it[1], n = it[2] }
      local a = Registry.get(t.worker)
      local e = a and a.entity
      if e and e.valid then
        local inv = e.get_main_inventory()
        if inv then out[#out + 1] = { task = key, module = t.ia1d.pid, item = it[1], n = inv.get_item_count(it[1]) } end
      end
    end
  end
  return out
end

--- Demandes hors module. args = { effectif, recruit_prio } (Team.view).
function Mv.wants(f, args)
  local out = {}
  local under = (f.engineers_count or 0) < ((f.team and f.team.floor) or 0)
  local prio_goal = under and Co.PRIO or Mv.PRIO_GOAL
  for _, m in ipairs((f.team and f.team.missing) or {}) do
    if type(m[1]) == "string" and type(m[2]) == "number" and m[2] > 0 then
      out[#out + 1] = { key = "but:" .. m[1], item = m[1], n = m[2], prio = prio_goal, net = true }
    end
  end
  if under and (T.grow_iron_reserve or 0) > 0 then out[#out + 1] = { key = "reserve", item = PLATE, n = T.grow_iron_reserve, prio = Co.PRIO } end
  local ef = args and args.effectif
  if ef and ef.reason == "recrue" and type(ef.margin_item) == "string" and (ef.cost_iron or 0) > 0 then
    out[#out + 1] = { key = "recrue", item = ef.margin_item, n = ef.cost_iron, prio = (args and args.recruit_prio) or Mv.PRIO_GOAL, net = true }
  end
  return out
end

local function say(f, st, tick, res)
  local parts = {}
  for _, it in ipairs(res.items or {}) do
    if res.build[it] or res.dort[it] or res.dispo_sorties[it] then
      parts[#parts + 1] = string.format("%s besoin %d sorties-prises %d dort %d a-construire %d", it, math.floor((res.need[it] or 0) + 0.5),
        math.floor((res.dispo_sorties[it] or 0) + 0.5), math.floor((res.dort[it] or 0) + 0.5), math.floor((res.build[it] or 0) + 0.5))
    end
  end
  local sig = table.concat(parts, " ; ") .. " | collectes " .. #res.collect
  if sig == st.said then return end
  st.said = sig
  st.logs = (st.logs or 0) + 1
  if st.logs > Mv.LOGS then return end
  log(string.format("[FO-MQ] %s a %.1f min : %s ; refus %d, perimes %d, sans courant %d", f.key or "player", tick / 3600, sig,
    #res.refused, #res.stale, #res.no_power))
end

--- Manque mesuré de l'équipe `f` (résultat de Mq.step, ou nil : éteint ou sans relevé). stock = stock libre de la vue ; args : Mv.wants.
function Mv.think(f, tick, stock, args)
  if not f.team then return nil end
  if not Mv.ENABLED then f.team.mq = nil return nil end -- éteint : plus aucun lecteur ne suit un résultat ancien
  local st = f.team.mq
  if not st then
    st = { mq = Mq.new(), reads = {} }
    f.team.mq = st
  end
  if st.tick ~= nil and tick - st.tick < Mv.PERIOD then return st.res end
  local b = f.build
  local surface = f.hq and f.hq.valid and f.hq.surface or nil
  local ids, keep = {}, {}
  for _, pid in ipairs((b and surface and b.order) or {}) do
    if is_module(b.projects[pid]) then ids[#ids + 1] = pid keep[pid] = true end
  end
  for _, id in ipairs(sorted_keys(st.reads)) do if not keep[id] then st.reads[id] = nil end end
  for _, id in ipairs(Mq.slice(st.mq, ids, Mv.MODS_MAX)) do st.reads[id] = Mv.read_module(f, surface, b.projects[id], tick) end
  local mods = {}
  for _, id in ipairs(ids) do if st.reads[id] then mods[#mods + 1] = st.reads[id] end end
  local res = Mq.step(st.mq, { mods = mods, transit = Mv.transit(f), sources = surface and Col.waiting_all(f, surface, b, tick) or {},
    wants = Mv.wants(f, args), stock = stock or {} }, tick)
  st.tick, st.res = tick, res
  if res then say(f, st, tick, res) end
  return res
end

return Mv
