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
require("script.faction.gel_etat") -- état du lot déclaré (namespace « gel ») et branché sur Gel.state
local Gu = require("script.faction.gel_usines")
local Commander = require("script.faction.commander") -- Commander.army_out (S10) ; requis au chargement, après commander

local Gj = {}

-- Flux des statistiques, sommés par force et par objet dans le tick, versés à la fin du tick (local : vidé à chaque tick). Produits
-- (entrée, on_flow positif) et consommés (sortie, on_flow négatif) sont tenus À PART : un même objet produit et consommé dans le tick
-- (minerai d'une foreuse fondu par son four, pas dus de plusieurs îlots au réveil) ne s'annule pas (défaut du micro-banc A de
-- 13dc9822 : statistiques de minerai de A à 56 contre 80 pour la jumelle).
local flows, flows_order = {}, {}

local function add_flow(force, n, c)
  if c == 0 then return end
  local t = flows[force]
  if not t then t = { p = {}, c = {} }; flows[force] = t; flows_order[#flows_order + 1] = force end
  if c > 0 then t.p[n] = (t.p[n] or 0) + c else t.c[n] = (t.c[n] or 0) - c end
end

local function flush_flows()
  for _, force in ipairs(flows_order) do
    local fo = game.forces[force]
    local st = fo and fo.item_production_statistics
    if st then
      local t = flows[force]
      for _, n in ipairs(Gc.sorted_names(t.p)) do st.on_flow(n, t.p[n]) end
      for _, n in ipairs(Gc.sorted_names(t.c)) do st.on_flow(n, -t.c[n]) end
    end
    flows[force] = nil
  end
  for i = #flows_order, 1, -1 do flows_order[i] = nil end -- vidée sur place : aucune table neuve par tick dans un local de module (F403)
end

local function stats(fid)
  local u = Gu.U()
  u.stats[fid] = u.stats[fid] or { refus = {}, figes = 0, reveils = 0, produits = {}, pertes = 0 }
  return u.stats[fid]
end

---------------------------------------------------------------------------------------------------
-- Frontière et application d'un pas
---------------------------------------------------------------------------------------------------
--- Recette d'un four du QG relue à sa source (un seul objet dans la source). Source vide, ou objet sans recette de four : la dernière
--- recette est GARDÉE (connue dès le relevé, discover_four) ; le pas n'y trouve pas son ingrédient et ne fabrique rien, comme le moteur
--- (C19, 8/11 : plus de recette fictive « ? »).
local function refresh_recipe(I, m, src_items)
  local names = Gc.sorted_names(src_items)
  local recipe = names[1] and Gu.book()[names[1]]
  if not recipe then return end
  local e = I.machines[1]
  m.ing, m.out = recipe.ing, recipe.out
  m.rate = (e.crafting_speed or 1) / (recipe.time * 60)
  m.jpc = (m.power or 0) / m.rate
  m.fpc = m.jpc / m.eff
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
  -- produits comptés au bilan [FO-GEL] : tout ce que le pas a produit (aucun nom d'objet en dur : règle anti-échelle d'IA-G, §8 bis)
  for _, n in ipairs(Gc.sorted_names(res.produced)) do
    if res.produced[n] > 0 then st.produits[n] = (st.produits[n] or 0) + res.produced[n] end
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
      local dt = Gu.target_of(e)
      if not (dt and dt.unit_number == t) then return false, "cible" end
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
  Gc.restore(I.acc) -- repart de la fraction mise de côté au dernier réveil (Gc.bank)
  local u = Gu.U()
  u.slots[I.slot] = u.slots[I.slot] or {}
  local list = u.slots[I.slot]
  list[#list + 1] = I.id
  table.sort(list)
  stats(I.fid).figes = stats(I.fid).figes + 1
  return true
end

--- Option (ii) du lead (8/11) : après Gc.bank, la fraction mise de côté de chaque FOREUSE est rendue au moteur par sa progression
--- (mining_progress) et sa progression de productivité (bonus_mining_progress), en unités de mining_time de la cible (Gc.progress_write ;
--- fait moteur x10-gel-progres). Ce qui dépasse la plage reste de côté (Gc.restore le reprend au gel suivant). Les fours gardent la seule
--- mise de côté : crafting_progress n'est jamais écrit (F83, F84).
local function write_progress(I)
  local st = I.acc
  local bf, bp = st.bank_frac, st.bank_pfrac
  if not (bf or bp) then return end
  local ents = {}
  for _, e in ipairs(I.machines) do if e.valid then ents[e.unit_number] = e end end
  for _, m in ipairs(I.il.machines) do
    local e = m.kind == "drill" and ents[m.id]
    local tgt = e and e.mining_target
    if tgt and tgt.valid then
      local mt = tgt.prototype.mineable_properties.mining_time
      local f = bf and bf[m.id]
      if f and f > 0 then
        local p, rest = Gc.progress_write(e.mining_progress, f, mt)
        e.mining_progress = p
        bf[m.id] = (rest > 0) and rest or nil
      end
      local pf = bp and bp[m.id]
      local n = m.out and m.out[1] and m.out[1][1]
      local q = pf and n and pf[n]
      if q and q > 0 then
        local whole = math.floor(q)
        local p, rest = Gc.progress_write(e.bonus_mining_progress, q - whole, mt)
        e.bonus_mining_progress = p
        local left = whole + rest
        pf[n] = (left > 0) and left or nil
      end
    end
  end
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
  elseif I.dirty then
    Gc.reset(I.acc) -- îlot à relire : il sera refait, sa fraction est perdue (au plus 1 par machine)
  else
    Gc.bank(I.acc)
    write_progress(I)
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

--- Relevé d'un groupe (faction, ou groupe de banc à candidats) dans le budget du tick ; rend le budget restant.
local function scan_one(u, fid, f, tick, budget)
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
  return budget
end

--- Relevé du tick : factions vivantes (guerre en cours), puis groupes de banc à candidats (interface « fo-gel » candidats, scène
--- x10-gel-echelle, C20' b : leurs refus et leurs îlots éveillés sont relevés de nouveau toutes les Gu.RESCAN ticks, comme ceux d'une
--- faction ; aucune partie ordinaire n'a de groupe de banc). Un seul budget, Gu.SCAN_PER_TICK, pour tous.
local function scan_tick(tick, war)
  local u = Gu.U()
  local budget = Gu.SCAN_PER_TICK
  if war and war.active and war.factions then
    for _, fid in ipairs(State.alive()) do
      if budget <= 0 then return end
      local f = war.factions[fid]
      if f and not f.is_player and f.hq and f.hq.valid then budget = scan_one(u, fid, f, tick, budget) end
    end
  end
  if u.bancs and next(u.bancs) then
    for _, name in ipairs(Gc.sorted_names(u.bancs)) do
      if budget <= 0 then return end
      local b = u.bancs[name]
      if b.cands then budget = scan_one(u, "banc:" .. name, b.cands, tick, budget) end
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

-- Liste des postes d'un guet : vidée sur place à chaque guet (aucune table neuve par tick dans un local de module, F403). Le poste
-- d'un îlot (I.post) est gardé dans l'îlot et réutilisé : seul son champ `unfit` change d'un guet à l'autre.
local POSTS = {}
local MENAGE = {}

--- Poste de la règle commune pour un îlot (créé une fois, réutilisé ; I.st et I.boxes sont ceux de l'îlot).
local function post_of(I)
  local p = I.post
  if not p then
    p = { id = I.id, st = I.st, boxes = I.boxes }
    I.post = p
  end
  p.unfit = I.dirty or ((I.owed or I.pending) and "en cours") or nil
  return p
end

--- LA règle commune pour les îlots d'un groupe (une faction, ou un groupe de banc) ; s = entrées de la règle.
--- C19 (8/11, décision du lead) : quand la faction est loin et calme (G.skip_quiet), les îlots figés sans entrée propre ne sont PAS
--- relus (ils n'auraient ni action ni écriture d'état) : seuls les îlots éveillés, à relire ou en cours sont décidés. Gj.TOUS (bancs
--- hors jeu seulement) force la décision de tous les îlots, pour prouver l'équivalence.
local function guet_group(fid, key, s, tick)
  local u = Gu.U()
  local ids = u.ids_f[fid]
  if not (ids and #ids > 0) then return end
  Profiler.fcount("gel:ilots", #ids)
  Profiler.fstart("gel:g:regle")
  local fbox = Gu.faction_box(fid)
  local skip = (not Gj.TOUS) and G.skip_quiet(s, fbox, tick)
  for i = #POSTS, 1, -1 do POSTS[i] = nil end
  for i = #MENAGE, 1, -1 do MENAGE[i] = nil end
  for _, id in ipairs(ids) do
    local I = u.ilots[id]
    local p = post_of(I)
    if not (skip and G.quiet(p)) then POSTS[#POSTS + 1] = p end
    if I.dirty and not I.st.frozen and not I.pending and not I.owed then MENAGE[#MENAGE + 1] = id end
  end
  Profiler.fcount("gel:decides", #POSTS)
  local acts = G.decide_all(POSTS, s, fbox, tick)
  Profiler.fstop("gel:g:regle")
  Profiler.fstart("gel:g:actions")
  local woke, cause = 0, nil
  for _, a in ipairs(acts) do
    local I = u.ilots[a.id]
    if a.action == "fige" then
      if not I.dirty and freeze(I, tick) then Profiler.fcount("gel:geles", #I.machines) end
    elseif not I.pending then
      want_wake(I, tick, a.cause)
      woke, cause = woke + 1, a.cause
      -- figé à relire réveillé tout de suite (sans pas dû) : retiré dans ce guet, comme avant
      if I.dirty and not I.st.frozen and not I.pending and not I.owed then MENAGE[#MENAGE + 1] = a.id end
    end
  end
  Profiler.fstop("gel:g:actions")
  if woke > 0 then Gel.say("reveil:" .. key, string.format("%s : %d ilot(s) reveille(s) (%s) a %.1f min", key, woke, tostring(cause), tick / 3600)) end
  -- îlots à relire, éveillés et soldés : retirés du registre (relevés de nouveau au prochain passage du relevé) ; condition relue ici.
  Profiler.fstart("gel:g:menage")
  for _, id in ipairs(MENAGE) do
    local I = u.ilots[id]
    if I and I.dirty and not I.st.frozen and not I.pending and not I.owed then Gu.unregister(I) end
  end
  Profiler.fstop("gel:g:menage")
end

--- Entrées de la règle pour une faction. « armée dehors » n'est PAS une cause de réveil des USINES (décision du lead, 8/11 : la
--- production d'un avant-poste ne dépend pas de l'armée ; « attaque » et « menace » couvrent une attaque qui reviendrait ; mesure :
--- 447 -> 221 machines figées en 8 000 ticks sur la partie du DC) : army_out = faux. Les garnisons la gardent (gel_garnisons.lua).
local function input_usines(f, players)
  Profiler.fstart("gel:g:entrees")
  local s = Gel.input(f, players, false)
  if not Gu.ON or not (f.hq and f.hq.valid) then s.off = true end
  Profiler.fstop("gel:g:entrees")
  return s
end

local function guet_faction(u, f, fid, players, tick)
  guet_group(fid, tostring(f.key), input_usines(f, players), tick)
  -- bilan toutes les 5 min de jeu : au guet de la faction qui suit le multiple de 18 000 ticks (18 000 est un multiple de G.GUET)
  if (tick - tick % G.GUET) % (5 * 3600) == 0 and u.ids_f[fid] then bilan(f, fid, tick) end
end

--- Guet du tick : la faction dont c'est le tick (G.guet_of), ou le guet COMMUN (tick 0 de la période) : factions sans tick propre,
--- factions disparues, groupes de banc. Chaque faction est guettée une fois par période de G.GUET ticks.
local function guet(tick)
  local who = G.guet_of(tick % G.GUET, "usines")
  if who == nil then return end
  local u = Gu.U()
  if not u then return end
  local war = State.war()
  local live = war and war.active and war.factions
  local f = (who ~= "commun") and live and war.factions[who] or nil
  if who ~= "commun" and not (f and not f.eliminated) then return end -- aucune faction à ce tick : rien (ni joueurs lus, ni portée)
  Profiler.start("gel:guet")
  local players = Gel.players((war and war.surface) or 1)
  if who ~= "commun" then
    guet_faction(u, f, who, players, tick)
  else
    local seen = {}
    if live then
      for _, fid in ipairs(State.alive()) do
        seen[fid] = true
        local f = war.factions[fid]
        if f and G.slot(fid, "usines") == nil then guet_faction(u, f, fid, players, tick) end -- sans tick propre (aucune en partie)
      end
    end
    -- Faction ANÉANTIE (f.eliminated : hors de State.alive) ou guerre arrêtée : ses îlots ne sont plus guettés, donc tout ce qui est
    -- figé est réveillé ici, une fois (relecture de revue-s, 8/11 : sans cela, ses foreuses et ses fours restaient figés pour
    -- toujours).
    local gone = {}
    for k in next, u.ids_f do
      if type(k) == "number" and not seen[k] then gone[#gone + 1] = k end
    end
    table.sort(gone)
    for _, fid in ipairs(gone) do
      local n = 0
      for _, id in ipairs(copy_list(u.ids_f[fid])) do
        local I = u.ilots[id]
        if I and I.st.frozen and not I.pending then
          want_wake(I, tick, "faction disparue")
          n = n + 1
        elseif I and not I.st.frozen and not I.pending and not I.owed then
          Gu.unregister(I) -- réveillé et soldé : retiré du registre (la faction n'est plus relevée)
        end
      end
      if #(u.ids_f[fid] or {}) == 0 then u.ids_f[fid] = nil end
      if n > 0 then Gel.say("reveil:" .. tostring(fid), string.format("faction %s disparue (aneantie ou guerre arretee) : %d ilot(s) reveille(s) a %.1f min", tostring(fid), n, tick / 3600)) end
    end
    -- groupes de banc (interface « fo-gel », script/faction/gel_banc.lua) : causes posées par le banc, jamais par une faction
    for _, name in ipairs(Gc.sorted_names(u.bancs)) do
      local b = u.bancs[name]
      local s = { players = b.players or players, threatened_until = b.threatened_until, attack_t = b.attack_t, lost_t = b.lost_t,
        base_alert = b.base_alert, army_out = b.army_out or false, off = (not Gu.ON) or not Gel.on() }
      guet_group("banc:" .. name, "banc:" .. name, s, tick)
    end
  end
  Profiler.stop("gel:guet")
end

---------------------------------------------------------------------------------------------------
-- Chaque tick : réveils en file, pas du créneau, pas dus, relevé ; flux des statistiques versés
---------------------------------------------------------------------------------------------------
local function each_tick(tick)
  local g = Gel.state()
  local u = g and g.u
  if not u then
    guet(tick) -- registre créé par le premier guet (Gu.U), comme avant l'étalement
    return
  end
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
      if I.dirty then Gc.reset(I.acc) else Gc.bank(I.acc); write_progress(I) end -- fraction du gel rendue au moteur (foreuses) ou mise de côté
      I.owed = nil
    end
    n = n + 1
  end
  Profiler.stop("gel:pas")
  if Gu.ON and Gel.on() then scan_tick(tick, State.war()) end
  guet(tick) -- guet étalé : une faction par tick pair de la période (G.guet_of), le guet commun au tick 0
  flush_flows()
end

Events.on_nth_tick(1, function(e) each_tick(e.tick) end)

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
  local inside_frozen = false
  for _, id in ipairs(list) do
    local I = u.ilots[id]
    if I and p.x >= I.box.x0 and p.x <= I.box.x1 and p.y >= I.box.y0 and p.y <= I.box.y1 then
      if not I.dirty then I.dirty = why end
      if I.st.frozen then inside_frozen = true end
    end
  end
  -- Remplaçant d'une machine figée (niveau : Levels.swap, fast_replace, raise_built) : s'il hérite de active = false, plus rien ne le
  -- réveillerait (wake ne connaît que l'ancienne entité) ; rendu actif tout de suite (relecture de revue-s, 8/11).
  if why == "pose" and inside_frozen and entity.active == false then entity.active = true end
end

Events.on(defines.events.on_built_entity, function(e) touch(e.created_entity, "pose") end)
Events.on(defines.events.on_robot_built_entity, function(e) touch(e.created_entity, "pose") end)
Events.on(defines.events.script_raised_built, function(e) touch(e.entity, "pose") end)
Events.on(defines.events.script_raised_revive, function(e) touch(e.entity, "pose") end)
Events.on(defines.events.on_player_mined_entity, function(e) touch(e.entity, "retrait") end)
Events.on(defines.events.on_robot_mined_entity, function(e) touch(e.entity, "retrait") end)
Events.on(defines.events.script_raised_destroy, function(e) touch(e.entity, "retrait") end)
-- Intérêt déclaré à l'aiguillage des morts (lot MORTS ; recensé par tests/morts_test.lua) : une pièce d'îlot ou un voisin qui le
-- change, jamais la force « enemy ».
Gj.DIED_TYPES = { "mining-drill", "furnace", "container", "logistic-container", "inserter", "transport-belt", "underground-belt", "splitter",
  "loader", "assembling-machine" }
Events.on_died(function(e) touch(e.entity, "mort") end, { types = Gj.DIED_TYPES, ennemi = false })

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

Gj.write_progress = write_progress
Gj.freeze, Gj.wake, Gj.step, Gj.frontier, Gj.still_same, Gj.guet, Gj.each_tick, Gj.touch = freeze, wake, step, frontier, still_same, guet, each_tick, touch
return Gj
