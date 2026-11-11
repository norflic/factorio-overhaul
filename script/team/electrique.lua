--[[
  Lot ELECTRIQUE (retour du DC du 8/11, 14 h 30, 0.6.66) : glue de la règle pure shared/team/electrique.lua. Journal [FO-ELECTRIQUE].

  (a) Elec.think (pensée d'équipe, script/team/team.lua E5, avant la retenue de la pile) relit les entrées du verdict : foreuse électrique
      obtenable (stock ou fabricable), centrale finie (capacité des machines bâties, f.build.grow), poteau obtenable, centrale saine.
      Elec.filter (script/team/board.lua : Board.sync et Board.add, le passage commun de TOUS les producteurs de tâches : fond, cerveau,
      projets, survie) refuse les tâches LIBRES qui posent ou fabriquent des foreuses thermiques quand l'électrique est possible. Une tâche
      déjà prise finit ce qu'elle porte. Verdict périmé (plus de Elec.TTL ticks) : rien n'est filtré (comportement d'avant).
  (b) Elec.swap_plan (script/team/foreuse_swap.lua, tranche « plan ») : quota de remplacements lu à la marge de kW, candidats ramenés aux
      champs entiers (E.block) ; Elec.swap_done : bilan de la passe, champ basculé N/M.
  (c) Même tranche : kW des électriques prévues non couverts par la marge (E.planned_kw) écrits dans f.team.elec_kw = { kw, tick } ; lus par
      Sante.growth (script/team/sante_centrale.lua) comme un déficit : la centrale est demandée AVANT la pose, à la taille du besoin.
  Réglage fo-war-electrique (settings/electrique.lua ; absent : allumé). Éteint : rien n'est filtré, quota et kW comme avant.
  Déterminisme : listes triées, aucun temps mesuré ; état dans f.elec (tables simples).
]]

local T = require("shared.team.config")
local E = require("shared.team.electrique")
local Dt = require("shared.team.decision_tree") -- arbre de décision Early / Mid / Late (DC, 9/11) : phase et électriques qui dorment au coffre
local Stock = require("script.team.stock")
local Outposts = require("script.faction.outposts") -- lot CHARBON-EXTENSION (F486) : brûleurs à sec par avant-poste (Outposts.status)
local Fx = require("shared.team.flux")
local VITAL = Fx.vital(T.outposts, T.fuel, T.smelter_inputs) -- types vitaux (même lecture que le journal [FO-FLUX])

--- Brûleurs à sec des avant-postes VITAUX de l'équipe (ids triés, lecture seule).
local function vital_dry(f, tick)
  local ids = {}
  for id in pairs(f.outposts or {}) do ids[#ids + 1] = id end
  table.sort(ids, function(x, y) return tostring(x) < tostring(y) end)
  local dry = 0
  for _, id in ipairs(ids) do
    local o = f.outposts[id]
    if o and VITAL[o.kind] then dry = dry + ((Outposts.status(o, tick) or {}).dry or 0) end
  end
  return dry
end

local Elec = {}

local function State_sorted(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

Elec.SETTING = "fo-war-electrique"
Elec.TTL = 2 * 3600      -- ticks : verdict encore valable (une pensée d'équipe le refait bien avant)
Elec.LOGS = 120          -- lignes [FO-ELECTRIQUE] au plus par équipe (hors bilans de 5 min)
Elec.SAY_KEY = 5 * 3600  -- ticks : un refus de la même tâche n'est réécrit qu'après ce délai
Elec.REPORT = 5 * 3600   -- ticks : bilan des refus par tranche de 5 min
Elec.KW_STEP = 0.15      -- part de changement des kW demandés qui justifie une ligne de plus
Elec.SKIP = 18000        -- ticks (5 min, comme Swap.RETRY) : un champ où la passe n'a rien planifié est sauté

function Elec.on()
  local ok, v = pcall(function() return settings.global[Elec.SETTING].value end)
  if ok and v ~= nil then return v == true end
  return true
end

local function state_of(f)
  local st = f.elec
  if not st then
    st = { logs = 0, said = {}, refused = {}, counts = {} }
    f.elec = st
  end
  return st
end

local function minutes(f, tick) return (tick - (f.started or 0)) / 3600 end

local function say(f, st, tick, text)
  st.logs = (st.logs or 0) + 1
  if st.logs <= Elec.LOGS then
    log(string.format("[FO-ELECTRIQUE] %s : %s a %.1f min", f.key or "player", text, minutes(f, tick)))
  end
end

local function obtainable(f, book, item)
  if not item then return false end
  local ip = game and game.item_prototypes
  if ip and not ip[item] then return false end
  if Stock.count(f, item) > 0 then return true end
  return book ~= nil and book:handcraftable(item) == true
end

--- Correctif d'interblocage : foreuses électriques de la FORCE qui tournent (en marche ou sortie pleine), au total et par ressource minée,
--- relues au plus toutes les Elec.LIVE_EVERY ticks (une recherche du moteur par équipe). { total, by = { [ressource] = n } }.
Elec.LIVE_EVERY = 600
local LIVE_STATUS = nil
local function live_drills(f, st, tick)
  if st.live and tick - (st.live.tick or -math.huge) < Elec.LIVE_EVERY then return st.live end
  local out = { tick = tick, total = 0, by = {} }
  local surface = f.hq and f.hq.valid and f.hq.surface
  if surface and defines and defines.entity_status then
    LIVE_STATUS = LIVE_STATUS or { [defines.entity_status.working] = true, [defines.entity_status.waiting_for_space_in_destination] = true }
    local ok, list = pcall(function() return surface.find_entities_filtered({ name = T.DRILL_ELECTRIC, force = f.force }) end)
    for _, d in ipairs(ok and list or {}) do
      if d.valid and LIVE_STATUS[d.status] then
        out.total = out.total + 1
        local r = d.mining_target
        local rn = r and r.valid and r.name
        if rn then out.by[rn] = (out.by[rn] or 0) + 1 end
      end
    end
  end
  st.live = out
  return out
end

--- Entrées de E.thermal pour un type d'avant-poste (`kind`, nil : règle globale) ; `craft` : fabrication de thermiques (la ressource la moins
--- servie en électrique décide).
local function inputs(v, kind, craft)
  local spec = kind and T.outposts[kind]
  local res_live = nil
  if spec then res_live = (v.by or {})[spec.resource] or 0 end
  if craft then res_live = v.min_live end
  local rr = (kind and not craft and v.res) and v.res[kind] or nil
  return { on = v.on, obtainable = v.obtainable, plants = v.plants, poles = v.poles, healthy = v.healthy,
    fuel = craft or (spec ~= nil and spec.product == T.fuel), el_live = v.el_live, poles_stock = v.poles_stock, since = v.since,
    res_live = res_live, phase = v.phase, elec_drill_stock = v.elec_drill_stock, -- arbre de décision (Dt.thermal_allowed)
    burners_dry = v.burners_dry, -- lot CHARBON-EXTENSION (F486) : brûleurs des avant-postes vitaux à sec
    res_active = rr and rr.active, res_peak = rr and rr.peak, res_stalled = rr and rr.stalled, res_was = rr and rr.was }
end
Elec.inputs = inputs

--- Arbre de décision (DC, 9/11) : compteurs GÉNÉRIQUES du mall au stock, classés au PROTOTYPE de l'entité que pose chaque objet (un tapis a
--- une vitesse de tapis, un bras une vitesse de rotation, une machine une vitesse de fabrication hors four) : aucun nom d'objet. Classe
--- mémorisée par nom dans une table de module (jamais dans `global`). Rend { machines, belts, inserters } ; sans moteur : zéros.
local CLASS = {}
local function proto_get(obj, k)
  local ok, v = pcall(function() return obj[k] end)
  if ok then return v end
  return nil
end
local function class_of(item)
  local c = CLASS[item]
  if c ~= nil then return c end
  local ip = game and game.item_prototypes
  local pe = ip and ip[item] and proto_get(ip[item], "place_result")
  c = false
  if pe then
    if proto_get(pe, "belt_speed") then c = "belts"
    elseif proto_get(pe, "inserter_rotation_speed") then c = "inserters"
    elseif proto_get(pe, "crafting_speed") and proto_get(pe, "type") ~= "furnace" then c = "machines" end
  end
  CLASS[item] = c
  return c
end
local function mall_stock(f)
  local out = { machines = 0, belts = 0, inserters = 0 }
  local ok, contents = pcall(Stock.contents, f)
  for item, n in pairs(ok and contents or {}) do -- (sommes seules : l'ordre ne compte pas)
    local c = class_of(item)
    if c then out[c] = out[c] + n end
  end
  return out
end

--- Phase de l'arbre de décision et foreuses électriques qui dorment au coffre, écrites dans `v` (lues par inputs -> E.thermal). Une ligne
--- [FO-ELECTRIQUE] quand la phase change.
local function phase_of(f, st, tick, v)
  v.elec_drill_stock = Stock.count(f, T.DRILL_ELECTRIC)
  local stock = mall_stock(f)
  local phase, why = Dt.phase({ plant_ok = (v.plants or 0) >= 1 and v.healthy == true, elec_drill = v.obtainable == true, stock = stock })
  v.phase = phase
  if st.phase ~= phase then
    say(f, st, tick, string.format("phase %s -> %s : %s ; %d foreuse(s) electrique(s) au coffre, mall %d machines, %d tapis, %d bras",
      tostring(st.phase or "-"), phase, why, v.elec_drill_stock, stock.machines, stock.belts, stock.inserters))
    st.phase = phase
  end
end

--- (a) Entrées du verdict, relues à chaque pensée d'équipe (stock, livre de recettes, centrale). Une ligne quand le verdict change.
function Elec.think(f, book, tick)
  if not f then return end
  local st = state_of(f)
  local g = f.build and f.build.grow
  local cap_kw = (g and (g.capacity or 0) or 0) * 60 / 1000
  local poles, poles_stock = false, 0
  for _, p in ipairs(T.swap.poles or {}) do
    if obtainable(f, book, p) then poles = true end
    poles_stock = poles_stock + Stock.count(f, p)
  end
  local lv = live_drills(f, st, tick)
  local min_live
  for _, k in ipairs(T.OUTPOST_ORDER or {}) do
    local sp = T.outposts[k]
    local n = sp and (lv.by[sp.resource] or 0) or 0
    if min_live == nil or n < min_live then min_live = n end
  end
  -- Lot DEFENSE-AP : extraction EFFONDRÉE par ressource (foreuses qui travaillent : thermiques des avant-postes + électriques de la force sur
  -- cette ressource), pic récent, durée sans foreuse de plus, hystérésis ; lu par E.thermal (inputs : res_active, res_peak, res_stalled, res_was).
  st.res = st.res or {}
  local res = {}
  for _, k in ipairs(T.OUTPOST_ORDER or {}) do
    local sp = T.outposts[k]
    if sp then
      local thermal = 0
      for _, oid in ipairs(State_sorted(f.outposts)) do
        local o = f.outposts[oid]
        if o.kind == k then
          for _, d in ipairs(o.drill_list or {}) do
            if d.valid and d.name == T.DRILL then thermal = thermal + 1 end
          end
        end
      end
      local active = thermal + (lv.by[sp.resource] or 0)
      local r = st.res[k] or { peak = active, peak_t = tick, last = active, rise_t = tick, was = false }
      -- (un pic ne vieillit PAS tant que l'extraction est effondrée : sinon, à 0 foreuse, le pic retombait à 0 au bout de 30 min et la règle se rendait
      -- toute seule alors que rien n'avait repris ; mesuré, coll-on-20261020)
      if active >= r.peak or (tick - r.peak_t > E.CFG.peak_keep and not r.was) then r.peak, r.peak_t = active, tick end
      if active > r.last then r.rise_t = tick end
      r.last = active
      local stalled = tick - r.rise_t
      local down = E.collapsed({ active = active, peak = r.peak, stalled = stalled, was = r.was }) -- effondrée ET (à l'arrêt, ou déjà entrée)
      if down ~= r.was then
        say(f, st, tick, string.format("extraction de %s %s : %d foreuse(s) actives pour un pic recent de %d, %.1f min sans foreuse de plus",
          k, down and "EFFONDREE (thermique permise)" or "retablie (thermique refusee de nouveau)", active, r.peak, stalled / 3600))
      end
      r.was = down
      st.res[k] = r
      res[k] = { active = active, peak = r.peak, stalled = stalled, was = down }
    end
  end
  local v = { tick = tick, on = Elec.on(), res = res, obtainable = obtainable(f, book, T.DRILL_ELECTRIC), plants = cap_kw > 0 and 1 or 0,
    poles = poles, healthy = not (f.build and f.build.sante and f.build.sante.healthy == false), cap = cap_kw,
    el_live = lv.total, by = lv.by, min_live = min_live or 0, poles_stock = poles_stock,
    since = st.switch_tick and (tick - st.switch_tick) or nil }
  phase_of(f, st, tick, v) -- arbre de décision : v.phase, v.elec_drill_stock
  v.burners_dry = vital_dry(f, tick) -- lot CHARBON-EXTENSION (F486)
  st.v = v
  -- bascule datée (retour au thermique après E.CFG.revert sans électrique) : posée au premier refus, effacée quand une cause MATÉRIELLE
  -- rend la thermique (centrale, objet, poteaux) ; gardée pendant le retour pour cause de 0 électrique (la règle se réarme quand une tourne)
  local base_ok = E.thermal({ on = v.on, obtainable = v.obtainable, plants = v.plants, poles = v.poles, healthy = v.healthy,
    el_live = v.el_live, poles_stock = v.poles_stock })
  if base_ok then st.switch_tick = nil elseif not st.switch_tick then st.switch_tick = tick end
  v.since = st.switch_tick and (tick - st.switch_tick) or nil
  local allowed, why = E.thermal(inputs(v, nil, false))
  if st.allowed ~= allowed then
    st.allowed = allowed
    say(f, st, tick, string.format("%s : %s (capacite %.0f kW)", allowed and "thermique permise" or "BASCULE ELECTRIQUE", why, cap_kw))
  end
  Elec.count(f, st, tick, allowed, why)
end

--- Compte d'une minute (journal seulement, aucune décision ne le lit) : thermiques debout par type d'avant-poste, celles de la force hors des
--- avant-postes de l'équipe (joueur compris pour votre équipe : comptées, jamais touchées), remplacées depuis la ligne précédente, cause du reste.
Elec.COUNT_EVERY = 3600
function Elec.count(f, st, tick, allowed, why)
  if tick < (st.count_next or 0) then return end
  st.count_next = tick + Elec.COUNT_EVERY
  local by, n = {}, 0
  for _, oid in ipairs(State_sorted(f.outposts)) do
    local o = f.outposts[oid]
    for _, d in ipairs(o.drill_list or {}) do
      if d.valid and d.name == T.DRILL then
        by[o.kind] = (by[o.kind] or 0) + 1
        n = n + 1
      end
    end
  end
  local out = 0
  local surface = f.hq and f.hq.valid and f.hq.surface
  if surface then
    local ok, all = pcall(function() return surface.count_entities_filtered({ name = T.DRILL, force = f.force }) end)
    if ok and type(all) == "number" then out = math.max(0, all - n) end
  end
  local kinds = {}
  for _, k in ipairs(T.OUTPOST_ORDER or {}) do kinds[#kinds + 1] = string.format("%s %d", k, by[k] or 0) end
  local made = st.made_acc or 0
  st.made_acc = 0
  local cause
  local l = st.last or {}
  if allowed then cause = "thermique encore permise : " .. tostring(why)
  elseif n == 0 then cause = "aucune"
  elseif (l.quota or 0) <= 0 then cause = string.format("marge de kW nulle (%.0f kW) : centrale demandee pour %.0f kW", l.margin or 0, st.kw_said or 0)
  elseif (l.ready or 0) + (l.chain or 0) <= 0 then cause = "aucun poteau alimente a portee des champs du bloc (champs sautes 5 min)"
  elseif (l.have or 0) <= 0 then cause = "foreuses electriques a fabriquer (stock libre 0)"
  else cause = string.format("remplacement en cours (quota %d, marge %.0f kW)", l.quota or 0, l.margin or 0) end
  local v = st.v or {}
  log(string.format("[FO-ELECTRIQUE] %s : thermiques debout %d (%s), hors avant-postes de l'equipe %d, electriques qui tournent %d (force), poteaux au stock %d, remplacees cette minute %d, cause du reste : %s a %.1f min",
    f.key or "player", n, table.concat(kinds, ", "), out, v.el_live or 0, v.poles_stock or 0, made, cause, minutes(f, tick)))
end

local function verdict_for(v)
  return function(t)
    local spec = t.outpost_kind and T.outposts[t.outpost_kind]
    -- une fabrication de thermique ne sert qu'à l'exception du combustible : permise quand la centrale est à l'arrêt
    local fuel = (t.kind == "craft") or (spec ~= nil and spec.product == T.fuel)
    return E.thermal(inputs(v, t.outpost_kind, t.kind == "craft"))
  end
end

--- (a) Vue du cerveau (Team.view) : { [type d'avant-poste] = raison } des types refusés en thermique, ou nil (verdict périmé, règle éteinte,
--- rien de refusé). Lu par shared/ai3/projets.lua (EMIT.outpost : projet « bloque electrique:<type> » au lieu d'émettre une tâche filtrée).
function Elec.view_off(f, tick)
  local st = f and f.elec
  local v = st and st.v
  if not (v and v.on and tick - (v.tick or -math.huge) <= Elec.TTL) then return nil end
  local out, any = {}, false
  for _, kind in ipairs(T.OUTPOST_ORDER or {}) do
    local spec = T.outposts[kind]
    local ok, why = E.thermal(inputs(v, kind, false))
    if not ok then out[kind], any = why, true end
  end
  return any and out or nil
end

--- La thermique est-elle encore permise pour ce type d'avant-poste (nil : type inconnu, jamais du combustible) ? Verdict périmé ou règle
--- éteinte : vrai (comportement d'avant). Lu par la reconstruction (script/team/reconstruction.lua).
function Elec.allowed(f, tick, kind)
  local st = f and f.elec
  local v = st and st.v
  if not (v and v.on and tick - (v.tick or -math.huge) <= Elec.TTL) then return true end
  local spec = kind and T.outposts[kind]
  return (E.thermal(inputs(v, kind, false)))
end

--- Lot CC-MAIN : l'objet `item` sort-il d'une ressource que la foreuse électrique sait extraire (catégorie de la ressource parmi celles de la
--- foreuse, lues aux prototypes) ? Le bois des arbres, un fluide d'une autre catégorie : non. Mémorisé par objet dans une table de module
--- (jamais dans `global` ; une somme booléenne : l'ordre de `pairs` ne compte pas).
local DRILLABLE = {}
local function drillable(item)
  local c = DRILLABLE[item]
  if c ~= nil then return c end
  c = false
  local ok, drill = pcall(function() return game.entity_prototypes[T.DRILL_ELECTRIC] end)
  local cats = ok and drill and proto_get(drill, "resource_categories") or nil
  local ok2, list = pcall(function() return game.get_filtered_entity_prototypes({ { filter = "type", type = "resource" } }) end)
  if cats and ok2 and list then
    for _, r in pairs(list) do
      if cats[proto_get(r, "resource_category") or ""] then
        local mp = proto_get(r, "mineable_properties")
        for _, p in ipairs(mp and mp.products or {}) do
          if p.name == item and p.type ~= "fluid" then c = true end
        end
      end
    end
  end
  DRILLABLE[item] = c
  return c
end

--- Lot CC-MAIN (mandat du DC, 10/11 22 h 20 : plus de minage au sol dès que les foreuses électriques sont là) : cause (chaîne) qui interdit
--- la pioche sur `item`, ou nil. MÊME exclusion mutuelle que la thermique (Dt.thermal_allowed : hors phase early, des foreuses électriques
--- dorment au coffre), appliquée aux seules ressources que la foreuse électrique extrait (jamais le bois des arbres). Verdict périmé ou
--- règle éteinte : nil (comportement d'avant). Lu par la garde unique du minage à la main (Mi.hand_verdict : worker, fond).
function Elec.hand_blocked(f, tick, item)
  local st = f and f.elec
  local v = st and st.v
  if not (v and v.on and tick - (v.tick or -math.huge) <= Elec.TTL) then return nil end
  local dt_ok, dt_why = Dt.thermal_allowed({ phase = v.phase, elec_drill_stock = v.elec_drill_stock })
  if dt_ok then return nil end
  if not drillable(item) then return nil end
  return dt_why
end

--- Journal : foreuses thermiques perdues non refaites (n) et secours thermiques annulés (back) par la reconstruction.
function Elec.note_rebuild(f, tick, n, back)
  local st = state_of(f)
  say(f, st, tick, string.format("reconstruction : %d foreuse(s) thermique(s) perdue(s) non refaite(s), %d secours thermique(s) annule(s) (l'electrique les remplace)", n, back))
end

local function report(f, st, tick)
  local slot = math.floor(tick / Elec.REPORT)
  if st.slot == slot then return end
  local first = st.slot == nil
  st.slot = slot
  local c = st.counts
  st.counts = {}
  if first or not next(c) then return end
  log(string.format("[FO-ELECTRIQUE] %s : bilan 5 min a %.1f min | thermique refusee : agrandissements %d, avant-postes neufs %d, fabrications %d (%d foreuse(s) thermique(s) en tout)",
    f.key or "player", minutes(f, tick), c.extend or 0, c.build or 0, c.craft or 0, c.drills or 0))
end

--- (a) Filtre du tableau : rend la liste des tâches gardées (la même table si rien n'est refusé). Paires refusées retenues pour (c).
function Elec.filter(f, tasks, tick)
  local st = f and f.elec
  local v = st and st.v
  if not (v and v.on and tick - (v.tick or -math.huge) <= Elec.TTL) then return tasks end
  local kept, refused = E.filter(tasks, T.DRILL, verdict_for(v))
  if #refused == 0 then return tasks end
  for _, r in ipairs(refused) do
    local t = r.task
    st.counts[t.kind] = (st.counts[t.kind] or 0) + 1
    st.counts.drills = (st.counts.drills or 0) + r.n
    if t.kind ~= "craft" then st.refused[#st.refused + 1] = { tick = tick, n = r.n } end
    local key = tostring(t.key)
    if not (st.said[key] and tick - st.said[key] < Elec.SAY_KEY) then
      st.said[key] = tick
      say(f, st, tick, string.format("thermique refusee : tache %s (%s%s, %d foreuse(s) thermique(s)) : %s", key, t.kind,
        t.outpost and (" avant-poste " .. tostring(t.outpost)) or (t.outpost_kind and (" " .. t.outpost_kind) or ""), r.n, tostring(r.why)))
    end
  end
  st.refused = (E.refused_window(st.refused, tick))
  -- mémoire des clés bornée : celles écrites il y a plus de Elec.SAY_KEY sont oubliées
  local said = {}
  local keys = {}
  for k in pairs(st.said) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do if tick - st.said[k] < Elec.SAY_KEY then said[k] = st.said[k] end end
  st.said = said
  report(f, st, tick)
  return kept
end

local function speed_of(name)
  local p = name and game.entity_prototypes[name]
  return p and p.mining_speed or nil
end

--- (b) et (c) : candidats et bornes de la passe de remplacement. pass : passe de foreuse_swap (entries, t0) ; pc : { capacity, used, committed }
--- en kW (nil sans centrale lue) ; kw : kW d'une électrique ; base = { limit, tries, fit_tries, craft_cap } (valeurs d'avant). Rend
--- { entries, limit, tries, fit_tries, craft_cap, quota, margin, fields }. Écrit f.team.elec_kw (déficit pour la centrale).
function Elec.swap_plan(f, pass, pc, kw, base)
  local out = { entries = pass.entries, limit = base.limit, tries = base.tries, fit_tries = base.fit_tries, craft_cap = base.craft_cap }
  local st = state_of(f)
  local v = st.v
  if not (Elec.on() and v and v.on) then
    if f.team then f.team.elec_kw = nil end
    return out
  end
  local t0 = pass.t0
  local quota, margin = E.swap_quota({ capacity = pc and pc.capacity, used = pc and pc.used, committed = pc and pc.committed, kw = kw,
    fallback = base.limit })
  out.quota, out.margin = quota, margin
  st.last = { quota = quota, margin = margin, have = pass.have } -- (compte d'une minute : cause du reste)
  if quota > 0 then
    -- champs où la passe précédente n'a rien planifié, sautés Elec.SKIP ticks (sinon un champ sans poteau à portée retiendrait le quota)
    local skip, keep_skip = {}, {}
    for _, o in ipairs(st.skip_list or {}) do
      if type(o) == "table" and o.until_tick and o.until_tick > t0 then skip[o.o] = true keep_skip[#keep_skip + 1] = o end
    end
    st.skip_list = keep_skip
    local list, fields = E.block(pass.entries, quota, skip)
    out.entries, out.fields = list, fields
    out.limit = quota
    out.tries = math.min(E.CFG.tries_max, math.max(base.tries, quota))
    out.fit_tries = math.min(E.CFG.block_max, math.max(base.fit_tries, quota))
    out.craft_cap = math.max(base.craft_cap, quota)
  else
    out.limit = 0 -- plus de kW : aucun remplacement, mais les candidats restent classés (st.ready, lu par script/team/gisement.lua)
  end
  -- (c) kW des électriques prévues : thermiques à convertir (relevé) + paires refusées des 2 dernières minutes, moins la marge
  local keep, refused = E.refused_window(st.refused, t0)
  st.refused = keep
  local short, planned, n_el = E.planned_kw({ thermals = #pass.entries, refused = refused, th_speed = speed_of(T.DRILL),
    el_speed = speed_of(T.DRILL_ELECTRIC), kw = kw, margin = margin })
  local allowed = E.thermal(inputs(v, nil, false))
  if f.team then f.team.elec_kw = (not allowed and short > 0) and { kw = short, tick = t0 } or nil end
  local last = st.kw_said or 0
  local want = (not allowed) and short or 0
  if math.abs(want - last) > Elec.KW_STEP * math.max(last, kw or 1) then
    st.kw_said = want
    say(f, st, t0, string.format("kW demandes a la centrale : %.0f kW (%d electrique(s) prevue(s) pour %d thermique(s) et %d paire(s) refusee(s), %.0f kW prevus, marge %.0f kW)",
      want, n_el, #pass.entries, refused, planned, margin or 0))
  end
  return out
end

--- (b) Après le plan (S.plan) : les champs de la passe où aucun candidat n'a été retenu sont sautés Elec.SKIP ticks (E.idle_fields).
--- Aucun candidat alimenté ni à chaîne (n_ready + n_chain = 0) : tous les champs du bloc sont sautés, stock ou non (sinon rien n'est
--- fabriqué d'avance et le bloc reste pour toujours sur un champ sans poteau à portée). Rien au stock mais des candidats : on attend la
--- fabrication d'avance, rien n'est sauté.
function Elec.swap_planned(f, pass, out, n_ready, n_chain)
  local st0 = f and f.elec
  if st0 and st0.last then st0.last.ready, st0.last.chain = n_ready or 0, n_chain or 0 end
  if not (pass and pass.fields and #pass.fields > 0) then return end
  local idle
  if (n_ready or 0) + (n_chain or 0) <= 0 then
    idle = {}
    for _, fl in ipairs(pass.fields) do idle[#idle + 1] = fl.o end
  elseif (pass.have or 0) <= 0 then
    return
  else
    local owner = {}
    for _, e in ipairs(pass.entries or {}) do owner[e.id] = e.o end
    idle = E.idle_fields(pass.fields, out, owner)
  end
  if #idle == 0 then return end
  local st = state_of(f)
  st.skip_list = st.skip_list or {}
  for _, o in ipairs(idle) do st.skip_list[#st.skip_list + 1] = { o = o, until_tick = pass.t0 + Elec.SKIP } end
end

--- (b) Bilan d'une passe finie : électriques posées par champ, N/M (thermiques restantes du champ comptées après la passe).
function Elec.swap_done(f, pass)
  if not (pass and (pass.made or 0) > 0) then return end
  local st = state_of(f)
  st.made_acc = (st.made_acc or 0) + pass.made
  if not pass.fields then return end
  local parts = {}
  for _, fl in ipairs(pass.fields) do
    local o = f.outposts and f.outposts[fl.o]
    local left = 0
    for _, d in ipairs(o and o.drill_list or {}) do if d.valid and d.name == T.DRILL then left = left + 1 end end
    local made = (pass.made_by and pass.made_by[fl.o]) or 0
    parts[#parts + 1] = string.format("avant-poste %s (%s) : %d/%d basculee(s)%s", tostring(fl.o), o and o.kind or "?", made, made + left,
      left == 0 and " (champ entier electrique)" or "")
  end
  say(f, st, pass.t0, string.format("passe de remplacement : %d electrique(s) posee(s), quota %d (marge %.0f kW) | %s", pass.made,
    pass.quota or 0, pass.margin or 0, table.concat(parts, " ; ")))
end

return Elec
