--[[
  Lot X10-GEL, branchement USINES, palier A : le JEU (pas comptable appliqué au monde, gel, réveil, guet, relevé en tranches,
  événements). Découverte et registre : script/faction/gel_usines.lua. Règles pures : shared/faction/gel.lua (zone et réveil),
  shared/faction/gel_compta.lua (comptabilité). fo-logs/2026-11-07_X10/L1_CRITERES.md §3.

  Écrit au monde : `active` des machines de l'îlot ; contenu des coffres et des sorties de four (insert), de la source d'un four du
  QG (remove) ; combustible (inventaire, braise, objet qui brûle) ; quantité des gisements (amount, deplete à 0) ; statistiques de la
  force (on_flow) ; products_finished ; pollution (surface.pollute). Jamais crafting_progress, mining_progress, bonus_progress.
  Coût borné : Gu.STEP, Gu.SCAN_PER_TICK, Gu.OWED_PER_TICK, Gel.WRITES (écritures `active` par tick).
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local Profiler = require("script.core.profiler")
local G = require("shared.faction.gel")
local Gc = require("shared.faction.gel_compta")
local Gel = require("script.faction.gel")
local Gu = require("script.faction.gel_usines")
local Commander = require("script.faction.commander") -- Commander.army_out (S10) ; requis au chargement, après commander

local Gj = {}

-- Flux des statistiques, sommés par force et par objet dans le tick, versés à la fin du tick (local : vidé à chaque tick).
local flows, flows_order = {}, {}

local function add_flow(force, n, c)
  if c == 0 then return end
  local t = flows[force]
  if not t then t = {}; flows[force] = t; flows_order[#flows_order + 1] = force end
  t[n] = (t[n] or 0) + c
end

local function flush_flows()
  for _, force in ipairs(flows_order) do
    local fo = game.forces[force]
    local st = fo and fo.item_production_statistics
    if st then
      local t = flows[force]
      for _, n in ipairs(Gc.sorted_names(t)) do st.on_flow(n, t[n]) end
    end
    flows[force] = nil
  end
  flows_order = {}
end

local function stats(fid)
  local u = Gu.U()
  u.stats[fid] = u.stats[fid] or { refus = {}, figes = 0, reveils = 0, produits = {}, pertes = 0 }
  return u.stats[fid]
end

---------------------------------------------------------------------------------------------------
-- Frontière et application d'un pas
---------------------------------------------------------------------------------------------------
--- Recette d'un four du QG relue à sa source (un seul objet dans la source) ; garde la dernière si la source est vide.
local function refresh_recipe(I, m, src_items)
  local names = Gc.sorted_names(src_items)
  local recipe = names[1] and Gu.book()[names[1]]
  if not recipe then
    if not I.recipe_ok then m.ing, m.out = { { "?", 1 } }, { { "?", 1 } } end
    return
  end
  local e = I.machines[1]
  m.ing, m.out = recipe.ing, recipe.out
  m.rate = (e.crafting_speed or 1) / (recipe.time * 60)
  m.jpc = (m.power or 0) / m.rate
  m.fpc = m.jpc / m.eff
  I.recipe_ok = true
end

local function inv_of(I, pid)
  local e, kind = I.pool_ent[pid], I.pool_kind[pid]
  if not (e and e.valid) then return nil end
  if kind == "coffre" then return e.get_inventory(defines.inventory.chest) end
  if kind == "sortie" then return e.get_output_inventory() end
  return e.get_inventory(defines.inventory.furnace_source)
end

local function frontier(I, dt)
  local il = I.il
  local fr = { pools = {}, fuel = {}, sat = 1 }
  if I.dyn then
    local src = inv_of(I, "s" .. I.machines[1].unit_number)
    local items = src and src.get_contents() or {}
    refresh_recipe(I, il.machines[1], items)
    fr.pools["s" .. I.machines[1].unit_number] = { items = items, space = {} }
  end
  for _, m in ipairs(il.machines) do
    if m.kind == "drill" then
      local need, have = math.ceil(m.rate * dt) + 2, 0 -- seuls les gisements nécessaires au pas sont relus
      for _, pid in ipairs(m.res) do
        if have >= need then break end
        local r = I.res[pid]
        if r and r.valid then
          local a = r.amount
          fr.pools[pid] = { items = {}, space = {}, amount = a }
          have = have + a
        end
      end
    else
      for _, ref in ipairs(m.dst) do
        if ref.k == "pool" and not fr.pools[ref.id] then
          local inv = inv_of(I, ref.id)
          local items, space = {}, {}
          for _, it in ipairs(m.out) do
            local n = it[1]
            items[n] = inv and inv.get_item_count(n) or 0
            space[n] = inv and inv.get_insertable_count(n) or 0
          end
          fr.pools[ref.id] = { items = items, space = space }
        end
      end
    end
    for _, ref in ipairs(m.dst) do
      if ref.k == "pool" and I.pool_kind[ref.id] == "coffre" and not fr.pools[ref.id] then
        local inv = inv_of(I, ref.id)
        local n = I.pool_item[ref.id]
        fr.pools[ref.id] = { items = { [n] = inv and inv.get_item_count(n) or 0 }, space = { [n] = inv and inv.get_insertable_count(n) or 0 } }
      end
    end
    if m.energy == "burner" then
      local e = I.fuel_ent[m.fuel]
      local b = e and e.valid and e.burner
      local items = {}
      if b then
        local c = b.inventory.get_contents()
        for _, n in ipairs(il.fnames) do items[n] = c[n] or 0 end
      end
      fr.fuel[m.fuel] = { items = items, rem = b and b.remaining_burning_fuel or 0 }
    end
  end
  return fr
end

local function apply(I, res, frozen)
  local f = State.by_force(I.force)
  local fid = I.fid
  for _, pid in ipairs(Gc.sorted_names(res.take)) do
    local inv = inv_of(I, pid)
    for _, n in ipairs(Gc.sorted_names(res.take[pid])) do
      local c = res.take[pid][n]
      local got = inv and c > 0 and inv.remove({ name = n, count = c }) or 0
      if got < c then stats(fid).pertes = stats(fid).pertes + (c - got) end
    end
  end
  for _, pid in ipairs(Gc.sorted_names(res.put)) do
    local inv = inv_of(I, pid)
    for _, n in ipairs(Gc.sorted_names(res.put[pid])) do
      local c = res.put[pid][n]
      local put = inv and c > 0 and inv.insert({ name = n, count = c }) or 0
      if put < c then
        stats(fid).pertes = stats(fid).pertes + (c - put)
        res.produced[n] = (res.produced[n] or 0) - (c - put) -- compté seulement ce qui existe
      end
    end
  end
  for _, pid in ipairs(Gc.sorted_names(res.mined)) do
    local r = I.res[pid]
    if r and r.valid then
      local left = r.amount - res.mined[pid]
      if left <= 0 then r.deplete() else r.amount = left end
    end
  end
  for _, pid in ipairs(Gc.sorted_names(res.fuel)) do
    local e = I.fuel_ent[pid]
    local b = e and e.valid and e.burner
    if b then
      local u = res.fuel[pid]
      for _, n in ipairs(Gc.sorted_names(u.items)) do if u.items[n] > 0 then b.inventory.remove({ name = n, count = u.items[n] }) end end
      if u.burning then b.currently_burning = game.item_prototypes[u.burning] end -- LuaItemPrototype, comme le moteur le rend
      if b.currently_burning then b.remaining_burning_fuel = u.rem end
    end
  end
  for _, n in ipairs(Gc.sorted_names(res.produced)) do add_flow(I.force, n, res.produced[n]) end
  for _, n in ipairs(Gc.sorted_names(res.consumed)) do add_flow(I.force, n, -res.consumed[n]) end
  local st = stats(fid)
  for _, e in ipairs(I.machines) do
    if e.valid then
      local k = res.crafts[e.unit_number] or 0
      if k > 0 and e.type ~= "mining-drill" then e.products_finished = e.products_finished + k end
      if frozen then Gel.set_status(e, res.status[e.unit_number]) end
    end
  end
  for _, n in ipairs({ "iron-plate", "copper-plate", "steel-plate", "stone-brick" }) do
    if (res.produced[n] or 0) > 0 then st.produits[n] = (st.produits[n] or 0) + res.produced[n] end
  end
  if res.pollution > 0 then
    local s = game.surfaces[I.surface]
    if s then s.pollute(I.pos, res.pollution) end
  end
  Gc.commit(I.acc, res)
  return f
end

--- L'îlot figé est-il encore celui qu'on a relevé (entités valides et inactives, cibles des foreuses inchangées) ?
local function still_same(I)
  for _, e in ipairs(I.machines) do
    if not e.valid then return false, "mort" end
    if e.active then return false, "reactive" end
    local t = I.targets[e.unit_number]
    if t then
      local dt = e.drop_target
      if not (dt and dt.valid and dt.unit_number == t) then return false, "cible" end
    end
  end
  return true
end

local function step(I, tick, dt, frozen)
  if dt <= 0 then return end
  local fr = frontier(I, dt)
  local res = Gc.step(I.il, fr, I.acc, dt)
  if res then apply(I, res, frozen) end
  I.last = tick
end

---------------------------------------------------------------------------------------------------
-- Gel et réveil
---------------------------------------------------------------------------------------------------
local function freeze(I, tick)
  local n = #I.machines
  if Gel.spend(tick, n) < n then return false end -- reporté au guet suivant (le budget du tick est pris)
  local g = Gel.state()
  for _, e in ipairs(I.machines) do
    if e.valid then
      local s = e.status
      e.active = false
      g.vstatus[e.unit_number] = s
    end
  end
  g.n_frozen = g.n_frozen + n
  I.st.frozen, I.last = true, tick
  Gc.reset(I.acc)
  local u = Gu.U()
  u.slots[I.slot] = u.slots[I.slot] or {}
  local list = u.slots[I.slot]
  list[#list + 1] = I.id
  table.sort(list)
  stats(I.fid).figes = stats(I.fid).figes + 1
  return true
end

local function wake(I, tick, cause)
  local u = Gu.U()
  local g = Gel.state()
  for _, e in ipairs(I.machines) do if e.valid then e.active = true end end
  for _, un in ipairs(I.units) do g.vstatus[un] = nil end
  g.n_frozen = math.max(0, g.n_frozen - #I.machines)
  I.st.frozen, I.pending = false, nil
  if u.slots[I.slot] then
    for i = #u.slots[I.slot], 1, -1 do if u.slots[I.slot][i] == I.id then table.remove(u.slots[I.slot], i) end end
  end
  if tick > I.last and not I.dirty then
    I.owed = tick - I.last -- pas dû jusqu'au tick du réveil, payé dans les ticks suivants (Gu.OWED_PER_TICK)
    u.owed[#u.owed + 1] = I.id
  else
    Gc.reset(I.acc)
  end
  I.last = tick
  local s = stats(I.fid)
  s.reveils = s.reveils + 1
  s.cause = cause
end

--- Réveil dans le budget du tick ; sinon en file (u.pend, dans l'ordre), servie aux ticks suivants.
local function want_wake(I, tick, cause)
  local u = Gu.U()
  if not I.pending and Gel.spend(tick, #I.machines) >= #I.machines then wake(I, tick, cause) return true end
  if not I.pending then
    I.pending = cause
    u.pend[#u.pend + 1] = I.id
  end
  return false
end

local function copy_list(t)
  local o = {}
  for i = 1, #(t or {}) do o[i] = t[i] end
  return o
end

---------------------------------------------------------------------------------------------------
-- Relevé des candidats, en tranches (Gu.SCAN_PER_TICK par tick, toutes factions)
---------------------------------------------------------------------------------------------------
local function start_scan(fid, f, tick)
  local u = Gu.U()
  -- les îlots ÉVEILLÉS de la faction sont retirés et relevés à neuf (un îlot figé est gardé : ses pas le contrôlent)
  for _, id in ipairs(copy_list(u.ids_f[fid])) do
    local I = u.ilots[id]
    if I and not I.st.frozen and not I.owed and not I.pending then Gu.unregister(I) end
  end
  local q = {}
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    for _, d in ipairs(f.outposts[oid].drill_list or {}) do if d.valid then q[#q + 1] = { k = "d", e = d } end end
  end
  for _, s in ipairs(f.smelters or {}) do if s.valid then q[#q + 1] = { k = "s", e = s } end end
  u.scan[fid] = { q = q, pos = 1, next_at = tick + Gu.RESCAN }
  stats(fid).refus = {}
end

local function scan_tick(tick, war)
  local u = Gu.U()
  local budget = Gu.SCAN_PER_TICK
  for _, fid in ipairs(State.alive()) do
    if budget <= 0 then return end
    local f = war.factions[fid]
    if f and not f.is_player and f.hq and f.hq.valid then
      local sc = u.scan[fid]
      if not sc or (sc.pos > #sc.q and tick >= sc.next_at) then start_scan(fid, f, tick); sc = u.scan[fid] end
      while sc.pos <= #sc.q and budget > 0 do
        local c = sc.q[sc.pos]
        sc.pos, budget = sc.pos + 1, budget - 1
        local e = c.e
        if e.valid and e.unit_number and not u.by_unit[e.unit_number] then
          Profiler.start("gel:releve")
          local I, why
          if c.k == "d" then I, why = Gu.discover_pair(f, e.surface, e) else I, why = Gu.discover_four(f, e.surface, e) end
          if I then
            local taken = false
            for _, m in ipairs(I.machines) do if u.by_unit[m.unit_number] then taken = true end end
            if not taken then Gu.register(fid, I, tick) end
          else
            local r = stats(fid).refus
            r[why] = (r[why] or 0) + 1
          end
          Profiler.stop("gel:releve")
        end
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Guet (Gel.GUET ticks) : LA règle commune pour tous les îlots d'une faction
---------------------------------------------------------------------------------------------------
local function bilan(f, fid, tick)
  local u = Gu.U()
  local n, fz, ents = 0, 0, 0
  for _, id in ipairs(u.ids_f[fid] or {}) do
    local I = u.ilots[id]
    n = n + 1
    if I.st.frozen then fz = fz + 1; ents = ents + #I.machines end
  end
  local s = stats(fid)
  local parts, prod = {}, {}
  for _, k in ipairs(Gc.sorted_names(s.refus)) do parts[#parts + 1] = k .. "=" .. s.refus[k] end
  for _, k in ipairs(Gc.sorted_names(s.produits)) do prod[#prod + 1] = k .. "=" .. s.produits[k] end
  Gel.say("bilan:" .. tostring(f.key), string.format("%s : %d ilot(s), %d fige(s), %d machine(s) figee(s) ; refus [%s] ; produits comptes [%s] ; reveils %d (derniere cause %s) ; pertes %d a %.1f min",
    tostring(f.key), n, fz, ents, table.concat(parts, " "), table.concat(prod, " "), s.reveils, tostring(s.cause), s.pertes, tick / 3600))
end

--- LA règle commune pour les îlots d'un groupe (une faction, ou un groupe de banc) ; s = entrées de la règle.
local function guet_group(fid, key, s, tick)
  local u = Gu.U()
  local ids = u.ids_f[fid]
  if not (ids and #ids > 0) then return end
  local posts = {}
  for _, id in ipairs(ids) do
    local I = u.ilots[id]
    posts[#posts + 1] = { id = id, st = I.st, boxes = I.boxes, unfit = I.dirty or ((I.owed or I.pending) and "en cours") or nil }
  end
  local woke, cause = 0, nil
  for _, a in ipairs(G.decide_all(posts, s, Gu.faction_box(fid), tick)) do
    local I = u.ilots[a.id]
    if a.action == "fige" then
      if not I.dirty then freeze(I, tick) end
    elseif not I.pending then
      want_wake(I, tick, a.cause)
      woke, cause = woke + 1, a.cause
    end
  end
  if woke > 0 then Gel.say("reveil:" .. key, string.format("%s : %d ilot(s) reveille(s) (%s) a %.1f min", key, woke, tostring(cause), tick / 3600)) end
  for _, id in ipairs(copy_list(ids)) do
    local I = u.ilots[id]
    if I and I.dirty and not I.st.frozen and not I.pending and not I.owed then Gu.unregister(I) end
  end
end

local function guet(tick)
  local war = State.war()
  local u = Gu.U()
  if not u then return end
  Profiler.start("gel:guet")
  local surface = (war and war.surface) or 1
  local players = Gel.players(surface)
  if war and war.active and war.factions then
    for _, fid in ipairs(State.alive()) do
      local f = war.factions[fid]
      if f then
        local s = Gel.input(f, players, (Commander.army_out(f)))
        if not Gu.ON or not (f.hq and f.hq.valid) then s.off = true end
        guet_group(fid, tostring(f.key), s, tick)
        if tick % (5 * 3600) == 0 and u.ids_f[fid] then bilan(f, fid, tick) end
      end
    end
  end
  -- groupes de banc (interface « fo-gel », script/faction/gel_banc.lua) : causes posées par le banc, jamais par une faction
  for _, name in ipairs(Gc.sorted_names(u.bancs)) do
    local b = u.bancs[name]
    local s = { players = b.players or players, threatened_until = b.threatened_until, attack_t = b.attack_t, lost_t = b.lost_t,
      base_alert = b.base_alert, army_out = b.army_out or false, off = (not Gu.ON) or not Gel.on() }
    guet_group("banc:" .. name, "banc:" .. name, s, tick)
  end
  Profiler.stop("gel:guet")
end

---------------------------------------------------------------------------------------------------
-- Chaque tick : réveils en file, pas du créneau, pas dus, relevé ; flux des statistiques versés
---------------------------------------------------------------------------------------------------
local function each_tick(tick)
  local g = Gel.state()
  local u = g and g.u
  if not u then return end
  Profiler.start("gel:pas")
  while #u.pend > 0 do
    local I = u.ilots[u.pend[1]]
    if I and I.pending then
      if Gel.spend(tick, #I.machines) < #I.machines then break end
      wake(I, tick, I.pending)
    end
    table.remove(u.pend, 1)
  end
  local list = u.slots[tick % Gu.STEP]
  if list then
    for _, id in ipairs(copy_list(list)) do
      local I = u.ilots[id]
      if I and I.st.frozen and not I.dirty then
        local ok, why = still_same(I)
        if ok then step(I, tick, tick - I.last, true) else I.dirty = why end
      end
    end
  end
  local n = 0
  while #u.owed > 0 and n < Gu.OWED_PER_TICK do
    local I = u.ilots[table.remove(u.owed, 1)]
    if I and I.owed and not I.st.frozen then
      if not I.dirty then step(I, tick, I.owed, false) end
      Gc.reset(I.acc)
      I.owed = nil
    end
    n = n + 1
  end
  Profiler.stop("gel:pas")
  local war = State.war()
  if war and war.active and war.factions and Gu.ON and Gel.on() then scan_tick(tick, war) end
  flush_flows()
end

Events.on_nth_tick(1, function(e) each_tick(e.tick) end)
Events.on_nth_tick(G.GUET, function(e) guet(e.tick) end)

---------------------------------------------------------------------------------------------------
-- Événements : un bâtiment posé, retiré ou mort près d'un îlot le marque « à relire »
---------------------------------------------------------------------------------------------------
local function touch(entity, why)
  if not (entity and entity.valid) then return end
  local g = Gel.state()
  local u = g and g.u
  if not u then return end
  local p = entity.position
  local list = u.cells[State.chunk_key(math.floor(p.x / 32), math.floor(p.y / 32))]
  if not list then return end
  for _, id in ipairs(list) do
    local I = u.ilots[id]
    if I and not I.dirty and p.x >= I.box.x0 and p.x <= I.box.x1 and p.y >= I.box.y0 and p.y <= I.box.y1 then I.dirty = why end
  end
end

Events.on(defines.events.on_built_entity, function(e) touch(e.created_entity, "pose") end)
Events.on(defines.events.on_robot_built_entity, function(e) touch(e.created_entity, "pose") end)
Events.on(defines.events.script_raised_built, function(e) touch(e.entity, "pose") end)
Events.on(defines.events.script_raised_revive, function(e) touch(e.entity, "pose") end)
Events.on(defines.events.on_player_mined_entity, function(e) touch(e.entity, "retrait") end)
Events.on(defines.events.on_robot_mined_entity, function(e) touch(e.entity, "retrait") end)
Events.on(defines.events.script_raised_destroy, function(e) touch(e.entity, "retrait") end)
Events.on_died(function(e) touch(e.entity, "mort") end, { types = { "mining-drill", "furnace", "container", "logistic-container", "inserter",
  "transport-belt", "underground-belt", "splitter", "loader", "assembling-machine" }, ennemi = false })

-- Données changées : tout ce qui est figé est réveillé, le registre est refait au relevé suivant (rien de figé qu'une version ne connaît plus).
Events.on_configuration_changed(function()
  local g = Gel.state()
  if not (g and g.u) then return end
  for _, id in ipairs(State.sorted_keys(g.u.ilots)) do
    local I = g.u.ilots[id]
    if I.st.frozen then for _, e in ipairs(I.machines) do if e.valid then e.active = true end end end
  end
  g.u, g.vstatus, g.n_frozen = nil, {}, 0
  Gu.reset_caches()
end)

Gj.freeze, Gj.wake, Gj.step, Gj.frontier, Gj.still_same, Gj.guet, Gj.each_tick, Gj.touch = freeze, wake, step, frontier, still_same, guet, each_tick, touch
return Gj
