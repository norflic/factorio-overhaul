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
local Stock = require("script.team.stock")

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

--- (a) Entrées du verdict, relues à chaque pensée d'équipe (stock, livre de recettes, centrale). Une ligne quand le verdict change.
function Elec.think(f, book, tick)
  if not f then return end
  local st = state_of(f)
  local g = f.build and f.build.grow
  local cap_kw = (g and (g.capacity or 0) or 0) * 60 / 1000
  local poles = false
  for _, p in ipairs(T.swap.poles or {}) do
    if obtainable(f, book, p) then poles = true break end
  end
  local v = { tick = tick, on = Elec.on(), obtainable = obtainable(f, book, T.DRILL_ELECTRIC), plants = cap_kw > 0 and 1 or 0,
    poles = poles, healthy = not (f.build and f.build.sante and f.build.sante.healthy == false), cap = cap_kw }
  st.v = v
  local allowed, why = E.thermal(v)
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
  log(string.format("[FO-ELECTRIQUE] %s : thermiques debout %d (%s), hors avant-postes de l'equipe %d, remplacees cette minute %d, cause du reste : %s a %.1f min",
    f.key or "player", n, table.concat(kinds, ", "), out, made, cause, minutes(f, tick)))
end

local function verdict_for(v)
  return function(t)
    local spec = t.outpost_kind and T.outposts[t.outpost_kind]
    -- une fabrication de thermique ne sert qu'à l'exception du combustible : permise quand la centrale est à l'arrêt
    local fuel = (t.kind == "craft") or (spec ~= nil and spec.product == T.fuel)
    return E.thermal({ on = v.on, obtainable = v.obtainable, plants = v.plants, poles = v.poles, fuel = fuel, healthy = v.healthy })
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
    local ok, why = E.thermal({ on = v.on, obtainable = v.obtainable, plants = v.plants, poles = v.poles,
      fuel = spec ~= nil and spec.product == T.fuel, healthy = v.healthy })
    if not ok then out[kind], any = why, true end
  end
  return any and out or nil
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
  local allowed = E.thermal(v)
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
