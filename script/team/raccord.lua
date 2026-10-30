--[[
  Lot PD-ELEC (demande D05 du DC : « incapables de détecter des zones non couvertes par l'électricité ») : relevé périodique,
  borné par tick, des machines des modules FINIS d'une équipe (factions et votre équipe) qui n'ont pas de courant parce qu'elles
  sont sur une île (réseau sans machine génératrice) ou sous aucun poteau, HORS du cas « poteau perdu » (déjà traité par
  script/team/reseau_vivant.lua, [FO-RESEAU]) ; puis un projet de RACCORDEMENT : une chaîne de poteaux planifiée par la recherche
  de chemin de 0.6.17/0.6.18 (P.pole_chain, masques du couloir) et bâtie par la machinerie ordinaire du plan directeur (réserve
  au coffre, fantômes, PNJ, fils au raccordement). Règle pure : shared/team/raccord.lua. Journal [FO-RACCORD].

  Appelé par script/team/build.lua à chaque passe d'équipe (Ra.step) ; rien à abonner. État : b.raccord (nombres, chaînes,
  tables ; jamais de fonction, jamais d'entité), créé à la première passe : les sauvegardes d'avant le lot le créent d'elles-mêmes.
  Coût : un début de relevé par minute (une lecture des machines génératrices), puis UNE partie de module par passe (une recherche
  d'entités sur sa boîte) ; la décision (au plus un raccordement par relevé) lit les poteaux autour du groupe choisi.
]]

local R = require("shared.team.raccord")
local M = require("shared.team.modules")
local P = require("shared.team.plan")
local Rv = require("script.team.reseau_vivant")

local Ra = {}

local ELEC_TYPES = { "mining-drill", "assembling-machine", "lab", "inserter", "furnace" }
local GEN_TYPES = { "generator", "burner-generator", "solar-panel" }
local LIVE_STATES = { fini = true, chantier = true, raccordement = true } -- projets dont un poteau perdu est rouvert par [FO-RESEAU]
local PENDING_STATES = { reserve = true, defrichage = true, fantomes = true, chantier = true, raccordement = true }
local DECIDE_MAX = 6 -- groupes examinés au plus par relevé (lectures du moteur bornées)

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function say(f, tick, text)
  log(string.format("[FO-RACCORD] %s : %s a %.1f min", f.key or "player", text, tick / 3600))
end

local function is_pole(name) return name:find("electric%-pole") ~= nil end

--- Pièce « machine » d'un plan (rang de pose machine ou bras) : seules celles-là sont relevées.
local function is_machine(e)
  local r = P.kind_rank(e.name)
  return r == 2 or r == 3
end

---------------------------------------------------------------------------------------------------
-- Relevé
---------------------------------------------------------------------------------------------------
--- Réseaux alimentés (au moins une machine génératrice de l'équipe) : { [numéro] = true }, nombre.
local function live_networks(f, surface)
  local live, n = {}, 0
  for _, g in ipairs(surface.find_entities_filtered({ force = f.force, type = GEN_TYPES })) do
    local id = g.electric_network_id
    if id and not live[id] then live[id] = true; n = n + 1 end
  end
  return live, n
end

local function start_cycle(f, surface, b)
  local live, n = live_networks(f, surface)
  local units = {}
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and q.state == "fini" and not q.abandoned and not (q.spec and (q.spec.raccord or q.spec.enceinte)) then
      local parts, seen = {}, {}
      for _, e in ipairs(q.ents) do
        if e.built and not e.dropped and is_machine(e) then
          local k = e.part or 0
          if not seen[k] then seen[k] = true; parts[#parts + 1] = k end
        end
      end
      table.sort(parts)
      for _, k in ipairs(parts) do units[#units + 1] = { pid, k } end
    end
  end
  return { live = live, n_live = n, units = units, i = 1, obs = {}, found = {}, machines = 0 }
end

local function tkey(x, y) return math.floor(x) .. ":" .. math.floor(y) end

local function scan_unit(f, surface, b, c, u)
  local q = b.projects[u[1]]
  if not (q and q.state == "fini") then return end
  local keys, x0, y0, x1, y1 = {}, math.huge, math.huge, -math.huge, -math.huge
  for _, e in ipairs(q.ents) do
    if (e.part or 0) == u[2] and e.built and not e.dropped and is_machine(e) then
      keys[tkey(e.x, e.y)] = true
      x0, y0, x1, y1 = math.min(x0, e.x), math.min(y0, e.y), math.max(x1, e.x), math.max(y1, e.y)
    end
  end
  if x0 == math.huge then return end
  for _, ent in ipairs(surface.find_entities_filtered({ area = { { x0 - 1, y0 - 1 }, { x1 + 1, y1 + 1 } }, force = f.force, type = ELEC_TYPES })) do
    local pos = ent.position
    -- une machine du PLAN (un niveau plus grand peut avoir décalé son centre d'une demi-tuile) ; jamais celle qu'un joueur a posée
    local mine = keys[tkey(pos.x, pos.y)] or keys[tkey(pos.x - 0.5, pos.y - 0.5)] or keys[tkey(pos.x + 0.5, pos.y - 0.5)]
      or keys[tkey(pos.x - 0.5, pos.y + 0.5)] or keys[tkey(pos.x + 0.5, pos.y + 0.5)]
    local un = ent.unit_number
    if mine and un and not c.found[un] then
      c.found[un] = true
      c.machines = c.machines + 1
      local net = ent.electric_network_id
      if not (net and c.live[net]) then -- le cas courant (réseau alimenté) ne lit pas le prototype
        local kind = R.classify(net, function(id) return c.live[id] == true end, ent.prototype.electric_energy_source_prototype ~= nil)
        if kind ~= "ok" then
          local bb = ent.bounding_box
          c.obs[#c.obs + 1] = { pid = q.id, part = u[2], net = net, x = pos.x, y = pos.y, kind = kind,
            box = { bb.left_top.x, bb.left_top.y, bb.right_bottom.x, bb.right_bottom.y } }
        end
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Entrées de la décision
---------------------------------------------------------------------------------------------------
local function near_box(box, x, y, r)
  local dx = math.max(box[1] - x, 0, x - box[3])
  local dy = math.max(box[2] - y, 0, y - box[4])
  return dx * dx + dy * dy <= r * r
end

local function member(list, v)
  for _, x in ipairs(list) do if x == v then return true end end
  return false
end

--- Poteaux perdus que [FO-RESEAU] peut rouvrir (même filtre que reseau_vivant.lost_poles) : ceux des projets du groupe, ou à
--- R.LOST_NEAR de sa boîte. Au plus 40 lectures du moteur.
local function lost_near(f, surface, b, g)
  local n, reads = 0, 0
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and not q.abandoned and LIVE_STATES[q.state] and (q.poles_reopened or 0) < Rv.POLE_REOPEN_MAX then
      local own = member(g.pids, q.id)
      for _, e in ipairs(q.ents) do
        if e.built and not e.dropped and is_pole(e.name) and (own or near_box(g.box, e.x, e.y, R.LOST_NEAR)) then
          reads = reads + 1
          if reads > 40 then return n end
          local found = surface.find_entities_filtered({ position = { e.x, e.y }, radius = 0.6, force = f.force, type = "electric-pole", limit = 1 })
          if not found[1] then n = n + 1 end
        end
      end
    end
  end
  return n
end

--- Poteaux pas encore bâtis d'un chantier (autre qu'un raccordement de ce groupe) à R.LOST_NEAR : l'île est peut-être attendue.
local function pending_near(b, g)
  local n = 0
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and PENDING_STATES[q.state] and not q.abandoned and not (q.spec and q.spec.raccord and q.spec.raccord.key == g.key) then
      for _, e in ipairs(q.ents) do
        if not e.built and is_pole(e.name) and near_box(g.box, e.x, e.y, R.LOST_NEAR) then n = n + 1 end
      end
    end
  end
  return n
end

local function wire_of(name)
  local w = P.wire(name)
  if w then return w end
  local proto = game.entity_prototypes[name]
  return proto and proto.max_wire_distance or nil
end

--- Bouts du raccordement d'un groupe : spec.raccord, ou nil et raison. Un fil seul suffit (bouts à portée) : il est tiré ici
--- (rend nil, "fil").
local function ends_of(f, surface, g, live)
  local m = R.MAX_DIST
  local targets = {}
  for _, p in ipairs(surface.find_entities_filtered({ area = { { g.box[1] - m, g.box[2] - m }, { g.box[3] + m, g.box[4] + m } },
    type = "electric-pole", force = f.force })) do
    local id = p.electric_network_id
    if id and live[id] then
      targets[#targets + 1] = { x = p.position.x, y = p.position.y, name = p.name, reach = p.prototype.max_wire_distance, ent = p }
    end
  end
  if #targets == 0 then return nil, string.format("aucun poteau alimente a moins de %d tuiles", m) end
  local starts, new = {}, false
  if g.kind == "ile" then
    for _, p in ipairs(surface.find_entities_filtered({ area = { { g.box[1] - 12, g.box[2] - 12 }, { g.box[3] + 12, g.box[4] + 12 } },
      type = "electric-pole", force = f.force })) do
      if p.electric_network_id == g.net then
        starts[#starts + 1] = { x = p.position.x, y = p.position.y, name = p.name, reach = p.prototype.max_wire_distance, ent = p }
      end
    end
    if #starts == 0 then return nil, "aucun poteau de l'ile trouve pres des machines" end
  else
    new = true
    local mb = g.mbox
    starts[1] = { x = (mb[1] + mb[3]) / 2, y = (mb[2] + mb[4]) / 2 }
  end
  local s, t, d = R.best_pair(starts, targets, m)
  if not s then return nil, string.format("aucune paire de poteaux a moins de %d tuiles", m) end
  local pole = (not new and P.wire(s.name)) and s.name or M.DEFAULT_POLE
  local proto = game.entity_prototypes[pole]
  local new_reach = wire_of(pole) or 9
  local reach = R.chain_reach(not new and s.reach or nil, t.reach, new_reach)
  if not new and d <= reach + 1e-6 then
    -- les deux réseaux sont à portée de fil : pas de poteau à poser, un fil (moteur réel : connect_neighbour)
    local ok = s.ent.connect_neighbour(t.ent)
    return nil, ok and "fil" or "fil refuse par le moteur"
  end
  local spec = { key = g.key, kind = g.kind, pole = pole, reach = reach, big = proto ~= nil and proto.tile_width >= 2,
    target = { x = t.x, y = t.y }, dist = d }
  if new then
    spec.start = { new = true }
    spec.cands = {}
    for i, c in ipairs(R.ring_tiles(g.mbox, t)) do
      if i > 12 then break end
      spec.cands[#spec.cands + 1] = { x = c.x, y = c.y }
    end
  else
    spec.start = { x = s.x, y = s.y }
  end
  return spec
end

---------------------------------------------------------------------------------------------------
-- Fin de relevé : suivi des raccordements ouverts, décisions
---------------------------------------------------------------------------------------------------
local function note(st, f, tick, key, text)
  if st.said[key] == text then return end
  st.said[key] = text
  say(f, tick, text)
end

local function finish_cycle(api, f, surface, b, st, c, tick)
  -- 1. raccordements ouverts
  for _, key in ipairs(sorted_keys(st.open)) do
    local q = b.projects[st.open[key]]
    if not q then
      st.open[key] = nil
    elseif q.state == "fini" then
      st.n.finis = st.n.finis + 1
      say(f, tick, string.format("groupe %s : raccordement fini (projet %d, %d poteau(x), %d fil(s) tire(s))", key, q.id, #q.ents, q.wired or 0))
      st.open[key] = nil
    elseif q.state == "refuse" or q.abandoned then
      st.n.refuses = st.n.refuses + 1
      say(f, tick, string.format("groupe %s : raccordement refuse (projet %d : %s)", key, q.id, tostring(q.reason)))
      st.open[key] = nil
    end
  end
  -- 2. groupes du relevé
  local groups = R.groups(c.obs)
  local present = {}
  for _, g in ipairs(groups) do
    present[g.key] = true
    st.seen[g.key] = (st.seen[g.key] or 0) + 1
  end
  for _, key in ipairs(sorted_keys(st.seen)) do
    if not present[key] then
      if st.tries[key] then
        st.n.repares = st.n.repares + 1
        say(f, tick, string.format("groupe %s : plus de machine sans courant (%d raccordement(s) tente(s))", key, st.tries[key]))
      end
      st.seen[key], st.tries[key], st.said[key], st.last_try[key] = nil, nil, nil, nil
    end
  end
  local open_total = #sorted_keys(st.open)
  local ile, sans = 0, 0
  for _, o in ipairs(c.obs) do if o.kind == "ile" then ile = ile + 1 else sans = sans + 1 end end
  if (#c.obs > 0 or open_total > 0) and (tick >= (st.log_next or 0) or #groups ~= (st.last_groups or 0)) then
    st.log_next = tick + R.LOG_EVERY
    say(f, tick, string.format("releve : %d machine(s) des modules finis, %d sans courant (ile %d, sous aucun poteau %d) en %d groupe(s) ; "
      .. "%d reseau(x) alimente(s) ; raccordements ouverts %d, demandes %d, finis %d, refuses %d, groupes repares %d",
      c.machines, #c.obs, ile, sans, #groups, c.n_live, open_total, st.n.demandes, st.n.finis, st.n.refuses, st.n.repares))
  end
  st.last_groups = #groups
  -- 3. décisions (au plus un raccordement demandé par relevé)
  local asked = false
  for idx, g in ipairs(groups) do
    if idx > DECIDE_MAX then break end
    local last = st.last_try[g.key]
    local inp = { has_live = c.n_live > 0, open = st.open[g.key] ~= nil, open_total = open_total, seen = st.seen[g.key],
      tries = st.tries[g.key] or 0, since_try = last and (tick - last) or R.RETRY_AFTER }
    if inp.has_live and not inp.open then
      inp.lost = lost_near(f, surface, b, g)
      if inp.lost == 0 then inp.pending = pending_near(b, g) end
      if inp.lost == 0 and (inp.pending or 0) == 0 and (inp.seen or 0) >= R.CONFIRM then
        local foe = surface.find_nearest_enemy({ position = { x = g.x, y = g.y }, max_distance = R.ENEMY_R, force = f.force })
        inp.enemies = foe and 1 or 0
      end
    end
    local action, why = R.decide(inp)
    if action == "relier" and asked then action, why = "attendre", "un raccordement par releve" end
    -- relecture au moment d'agir : le relevé s'étale sur plusieurs passes et le moteur renumérote un réseau qui se coupe ou se
    -- joint ; un numéro périmé gâcherait un essai (R.MAX_TRIES) sur un groupe déjà alimenté ou sur un départ introuvable
    local live = c.live
    if action == "relier" then
      live = live_networks(f, surface)
      local m = surface.find_entities_filtered({ position = { g.x, g.y }, radius = 0.5, force = f.force, type = ELEC_TYPES, limit = 1 })[1]
      local net = m and m.electric_network_id
      if not m then action, why = "attendre", "machine introuvable a la relecture"
      elseif net and live[net] then action, why = "attendre", "alimentee a la relecture"
      elseif g.kind == "ile" and not net then action, why = "attendre", "ile sans poteau a la relecture"
      elseif g.kind == "ile" then g.net = net end
    end
    if action == "relier" then
      asked = true
      local spec, err = ends_of(f, surface, g, live)
      if (st.tries[g.key] or 0) >= R.MAX_TRIES then st.tries[g.key] = R.MAX_TRIES - 1 end -- essai de plus après R.RETRY_AFTER
      st.tries[g.key] = (st.tries[g.key] or 0) + 1
      st.last_try[g.key] = tick
      if spec then
        local id = api.request(f, { raccord = spec, prio = api.prio, domain = "infrastructures" })
        if id then
          st.open[g.key] = id
          st.n.demandes = st.n.demandes + 1
          open_total = open_total + 1
          st.said[g.key] = nil
          say(f, tick, string.format("groupe %s (%s, %d machine(s), projet(s) %s) : raccordement demande (projet %d), %s vers le poteau alimente "
            .. "(%.0f, %.0f) a %.0f tuiles, poteau %s de portee %g (essai %d/%d)", g.key, g.kind, g.n, table.concat(g.pids, ","), id,
            spec.start.new and "poteau neuf contre la machine" or string.format("du poteau de l'ile (%.0f, %.0f)", spec.start.x, spec.start.y),
            spec.target.x, spec.target.y, spec.dist, spec.pole, spec.reach, st.tries[g.key], R.MAX_TRIES))
        end
      elseif err == "fil" then
        st.n.fils = (st.n.fils or 0) + 1
        say(f, tick, string.format("groupe %s (%s, %d machine(s)) : poteaux a portee, fil tire directement", g.key, g.kind, g.n))
      else
        note(st, f, tick, g.key, string.format("groupe %s (%s, %d machine(s)) : pas de raccordement : %s (essai %d/%d)", g.key, g.kind, g.n,
          tostring(err), st.tries[g.key], R.MAX_TRIES))
      end
    else
      note(st, f, tick, g.key, string.format("groupe %s (%s, %d machine(s), projet(s) %s) : %s : %s", g.key, g.kind, g.n,
        table.concat(g.pids, ","), action, why))
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Pas d'une équipe
---------------------------------------------------------------------------------------------------
--- api = { request = Build.request, prio = priorité des projets de raccordement } (build.lua n'est pas requis ici).
function Ra.step(api, f, surface, tick)
  local b = f.build
  if not b then return end
  if b.opts and b.opts.raccord == false then return end -- interrupteur D'ESSAI (remote fo-ia1d set_option) : témoin des bancs
  local st = b.raccord
  if not st then
    st = { next = tick + R.PERIOD, seen = {}, tries = {}, last_try = {}, open = {}, said = {}, log_next = 0, last_groups = 0,
      n = { demandes = 0, finis = 0, refuses = 0, repares = 0, fils = 0 } }
    b.raccord = st
  end
  st.last_try = st.last_try or {} -- (état d'un premier relevé de ce lot sans ce champ)
  local c = st.cyc
  if not c then
    if tick < st.next then return end
    st.next = tick + R.PERIOD
    -- rien à relever tant que la centrale n'est pas finie (b.plant) : [FO-RESEAU] et la construction s'en chargent
    local pp = b.plant and b.projects[b.plant]
    if not (pp and pp.state == "fini") then return end
    st.cyc = start_cycle(f, surface, b)
    return
  end
  for _ = 1, R.UNITS_PER_PULSE do
    local u = c.units[c.i]
    if not u then break end
    c.i = c.i + 1
    scan_unit(f, surface, b, c, u)
  end
  if c.i > #c.units then
    st.cyc = nil
    finish_cycle(api, f, surface, b, st, c, tick)
  end
end

return Ra
