-- Demande du DC (31/10, 21 h) : « lancez une partie, analysez leur evolution, verifiez par image leur avancee ».
-- La partie du guide dans les reglages du retour du 31/10 (3 factions, 30 ouvriers), 2 h, session AVEC images :
-- banc.py --captures --visuel="--ticks 436000 --timeout 28800" --qui <lot> -- 436000 dc-evolution <source>
-- Lot REGARD : ligne [FO-REGARD] toutes les 5 min (tools/autotest/regard.py).
-- Toutes les 15 min, pour votre equipe et chaque faction : vue large de la base, gros plan du QG, ligne [FO-EVOL].
-- Les controles du guide (2 factions, 4 ouvriers) ne valent pas ici : le bilan dit seulement si la partie est allee au bout.
return function(CHECK)
local base = require("scenarios/verif_guide_common")(30)
local EVERY, SPEED = 54000, 8
local TYPES = { "assembling-machine", "furnace", "mining-drill", "lab", "boiler", "generator", "ammo-turret",
  "electric-turret", "container", "transport-belt", "inserter", "electric-pole", "wall" }
local PLATES = { "iron-plate", "copper-plate", "steel-plate", "electronic-circuit", "stone-brick" }
local CORE = { "assembling-machine", "furnace", "mining-drill", "lab", "boiler", "generator", "ammo-turret" }

local function teams()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  return ok and rows or {}
end

--- Centre et zoom de la vue large : boite des batiments de production de la force, plafonnee a 500 tuiles.
local function wide_view(s, force, center)
  local x0, y0, x1, y1
  for _, e in ipairs(s.find_entities_filtered({ force = force, type = CORE })) do
    local p = e.position
    if not x0 then x0, y0, x1, y1 = p.x, p.y, p.x, p.y end
    if p.x < x0 then x0 = p.x end
    if p.y < y0 then y0 = p.y end
    if p.x > x1 then x1 = p.x end
    if p.y > y1 then y1 = p.y end
  end
  if not x0 then return center, 0.5, 0, 0 end
  local w, h = x1 - x0 + 40, y1 - y0 + 40
  local px = math.max(w / 1920, h / 1080) * 32 -- tuiles par 32 px d'ecran
  local zoom = math.max(0.12, math.min(0.6, 1 / px))
  return { x = (x0 + x1) / 2, y = (y0 + y1) / 2 }, zoom, x1 - x0, y1 - y0
end

local function hq_position(s, row)
  local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = row.force, limit = 1 })[1]
  if hq and hq.valid then return hq.position end
  return game.forces.player.get_spawn_position(s)
end

---------------------------------------------------------------------------------------------------
-- Lot REGARD (retour du DC du 2/11 : « Vous auriez dû le voir ») : ce que le DC VOIT, toutes les 5 min de jeu, par force.
-- Lignes [FO-REGARD] <genre> min=.. force=.. cle=valeur ... lues par tools/autotest/regard.py. Genres : R (stocks, flux, minage
-- a la main, defense, age, PNJ), F (fours), C (courant), G (un gisement exploite), T (tapis), TACHE et COUT (cout du releve).
-- Le releve est fait en TACHES (une par tick, file dans l'etat du banc, descripteurs sans fonction) pour rester petit par tick ;
-- le cout mesure (profileur du moteur) est ecrit en [FO-REGARD] TACHE (premier releve) et [FO-REGARD] COUT (chaque releve).
-- Limite de l'API 1.1 : un tapis n'expose PAS la position de ses objets ; « minerai fige » = minerai sur des cases de tapis
-- BOUCHEES (voie pleine de minerai, 4 objets) dont le contenu est identique a celui du releve precedent (« stable 5 min »)
-- et du releve d'avant (« stable 10 min »). Un tapis plein qui avance a plein debit est lui aussi « bouche » : le chiffre est un
-- MAJORANT, a lire avec les fours (en marche 24/24 + tapis bouche = fonderie trop petite).
---------------------------------------------------------------------------------------------------
local RG_EVERY, RG_SLICE, RG_PNJ_EVERY, RG_IMMOBILE = 18000, 500, 1800, 7200
local RG_STOCK = { "iron-plate", "copper-plate", "coal", "stone", "iron-ore", "copper-ore", "steel-plate", "stone-brick" }
local RG_FLOW = { "iron-ore", "copper-ore", "coal", "stone", "iron-plate", "copper-plate", "steel-plate", "stone-brick" }
local RG_TURRETS = { "ammo-turret", "electric-turret", "fluid-turret" }
local RG_CONSUMERS = { "inserter", "mining-drill", "assembling-machine", "lab" }
local RG_HALF = { { 1, 0 }, { 2, 0 }, { -2, 1 }, { -1, 1 }, { 0, 1 }, { 1, 1 }, { 2, 1 }, { -2, 2 }, { -1, 2 }, { 0, 2 }, { 1, 2 }, { 2, 2 } }
local RG_BLOCK = { "mining-drill", "furnace", "transport-belt", "wall", "container", "assembling-machine", "ammo-turret",
  "electric-turret", "inserter", "boiler", "generator", "lab", "electric-pole", "pipe", "pipe-to-ground" }
local RG_SCAN = { "mining-drill", "furnace", "transport-belt", "underground-belt", "ammo-turret", "electric-turret", "fluid-turret",
  "inserter", "assembling-machine", "lab", "boiler", "generator", "electric-pole" }
local RG_STATUS = {}
for name, v in pairs(defines.entity_status) do RG_STATUS[v] = name end
local rg_elec_cache = {}
local rg_acc = {} -- profileurs cumules par force (hors global : un objet moteur ne se range pas dans l'etat)

local function rg_state(ctx)
  local st = ctx.state()
  st.rg = st.rg or { queue = {}, head = 1, prev = {}, pnj = {}, clusters = {}, belts = {}, bsig = {}, tcur = {}, ents = {}, n = 0 }
  return st.rg
end

local function rg_min(tick) return math.floor(tick / 3600) end
local function rg_i(x) return math.floor((x or 0) + 0.5) end
local function rg_f1(x) return string.format("%.1f", x or 0) end
local function rg_key(ix, iy) return (ix + 40000) * 80000 + (iy + 40000) end

local function rg_status(e)
  local ok, v = pcall(function() return e.status end)
  return (ok and v and RG_STATUS[v]) or "aucun"
end

local function rg_is_elec(name)
  local v = rg_elec_cache[name]
  if v == nil then
    local proto = game.entity_prototypes[name]
    v = (proto and proto.electric_energy_source_prototype ~= nil) and true or false
    rg_elec_cache[name] = v
  end
  return v
end

--- Entites de la force rangees par type par la tache SCAN (UN parcours de la carte par force et par releve : l'appel
--- find_entities_filtered coute environ 5 ms de parcours de chunks, quel que soit le filtre), validees a la lecture.
local function rg_ents(rg, fname, types)
  local out, by = {}, rg.ents[fname] or {}
  if type(types) == "string" then types = { types } end
  for _, ty in ipairs(types) do
    for _, e in ipairs(by[ty] or {}) do
      if e.valid then out[#out + 1] = e end
    end
  end
  return out
end

--- Objets des coffres autour du QG (coffre du QG et annexes : bloc de 22 tuiles au plus).
local function rg_stock(s, fname, center)
  local out = {}
  for _, it in ipairs(RG_STOCK) do out[it] = 0 end
  for _, c in ipairs(s.find_entities_filtered({ type = { "container", "logistic-container" }, force = fname, position = center, radius = 26 })) do
    if c.valid then
      for _, it in ipairs(RG_STOCK) do out[it] = out[it] + c.get_item_count(it) end
    end
  end
  return out
end

local function rg_kv(t, names, fmt)
  local parts = {}
  for _, k in ipairs(names) do parts[#parts + 1] = k .. "=" .. (fmt and fmt(t[k]) or tostring(t[k] or 0)) end
  return table.concat(parts, " ")
end

--- Echantillon des PNJ (toutes les 30 s) : position et date depuis laquelle chacun n'a pas bouge de plus de 0,7 tuile.
local function rg_sample_pnj(ctx, tick)
  local rg, s = rg_state(ctx), ctx.surface()
  local names = {}
  for name in pairs(game.forces) do
    if name == "player" or name:sub(1, 3) == "fo-" then names[#names + 1] = name end
  end
  table.sort(names)
  for _, fname in ipairs(names) do
    local cur, old = {}, rg.pnj[fname] or {}
    for _, c in ipairs(s.find_entities_filtered({ type = "character", force = fname })) do
      local un, p = c.unit_number, c.position
      local o = old[un]
      if o and (p.x - o.x) ^ 2 + (p.y - o.y) ^ 2 <= 0.5 then
        cur[un] = o
      else
        cur[un] = { x = p.x, y = p.y, since = tick }
      end
    end
    rg.pnj[fname] = cur
  end
end

local RG_TASKS = {}

--- SCAN : toutes les entites utiles de la force, par type.
RG_TASKS.SCAN = function(ctx, rg, t, tick)
  local by = {}
  for _, e in ipairs(ctx.surface().find_entities_filtered({ type = RG_SCAN, force = t.f })) do
    local list = by[e.type]
    if not list then
      list = {}
      by[e.type] = list
    end
    list[#list + 1] = e
  end
  rg.ents[t.f] = by
end

--- R : stocks, flux de la force (statistiques de production), minage a la main, defense, age, PNJ.
RG_TASKS.R = function(ctx, rg, t, tick)
  local s, row, fname = ctx.surface(), t.row, t.f
  local force = game.forces[fname]
  local hq = hq_position(s, { force = fname })
  local prev = rg.prev[fname] or { tick = 0, flow = {}, mined = 0 }
  local dt_min = math.max((tick - prev.tick) / 3600, 0.01)
  local flow, rate = {}, {}
  for _, it in ipairs(RG_FLOW) do
    flow[it] = force.item_production_statistics.get_input_count(it)
    rate[it] = (flow[it] - (prev.flow[it] or 0)) / dt_min
  end
  local stock = rg_stock(s, fname, hq)
  local tur, near = 0, 0
  for _, e in ipairs(rg_ents(rg, fname, RG_TURRETS)) do
    tur = tur + 1
    local p = e.position
    if (p.x - hq.x) ^ 2 + (p.y - hq.y) ^ 2 <= 225 then near = near + 1 end
  end
  local dry = 0
  for _, e in ipairs(rg_ents(rg, fname, "mining-drill")) do
    if not e.mining_target and not (e.prototype.resource_categories or {})["basic-fluid"] then dry = dry + 1 end
  end
  local age = -1
  local okl, ls = pcall(ctx.call, "levels_status", fname)
  if okl and type(ls) == "table" and ls.cc_level then age = ls.cc_level end
  -- PNJ immobiles depuis 2 min, dont ceux entoures de batiments (coinces)
  local immo, stuck, where = 0, 0, {}
  local tr = rg.pnj[fname] or {}
  local uns = {}
  for un in pairs(tr) do uns[#uns + 1] = un end
  table.sort(uns)
  for _, un in ipairs(uns) do
    local o = tr[un]
    if tick - o.since >= RG_IMMOBILE then
      immo = immo + 1
      if s.count_entities_filtered({ position = { x = o.x, y = o.y }, radius = 1.8, type = RG_BLOCK }) >= 4 then
        stuck = stuck + 1
        if #where < 3 then where[#where + 1] = rg_i(o.x) .. "," .. rg_i(o.y) end
      end
    end
  end
  ctx.log(string.format(
    "[FO-REGARD] R min=%d force=%s cle=%s n=%d max=%d soldats=%d tech=%d age=%d perdus=%d mine_main=%d mine_main_tot=%d "
      .. "stock_fer=%d stock {%s} flux_min {%s} tourelles=%d tourelles_qg=%d avant_postes=%d defendus=%d foreuses_sans_cible=%d "
      .. "immobiles=%d coinces=%d coinces_pos=%s",
    rg_min(tick), fname, tostring(row.key), row.n or 0, row.max or 0, row.soldiers or 0, row.tech or 0, age, row.lost or 0,
    (row.mined or 0) - prev.mined, row.mined or 0, row.iron or 0, rg_kv(stock, RG_STOCK), rg_kv(rate, RG_FLOW, rg_f1), tur, near,
    row.outposts or 0, row.outposts_defended or 0, dry, immo, stuck, #where > 0 and table.concat(where, ";") or "-"))
  rg.prev[fname] = { tick = tick, flow = flow, mined = row.mined or 0 }
end

--- F : fours (etats), plaques qui dorment dans leurs sorties.
RG_TASKS.F = function(ctx, rg, t, tick)
  local cnt, all, idle, n = {}, { ["iron-plate"] = 0, ["copper-plate"] = 0, ["steel-plate"] = 0, ["stone-brick"] = 0 }, {}, 0
  for k in pairs(all) do idle[k] = 0 end
  for _, e in ipairs(rg_ents(rg, t.f, "furnace")) do
    n = n + 1
    local sn = rg_status(e)
    cnt[sn] = (cnt[sn] or 0) + 1
    local inv = e.get_output_inventory()
    if inv then
      for name, c in pairs(inv.get_contents()) do
        if all[name] then
          all[name] = all[name] + c
          if sn ~= "working" then idle[name] = idle[name] + c end
        end
      end
    end
  end
  ctx.log(string.format(
    "[FO-REGARD] F min=%d force=%s fours=%d marche=%d sans_entree=%d sortie_pleine=%d sans_combustible=%d fer_sorties=%d cuivre_sorties=%d "
      .. "fer_dort=%d cuivre_dort=%d acier_dort=%d brique_dort=%d",
    rg_min(tick), t.f, n, cnt.working or 0, (cnt.no_ingredients or 0) + (cnt.item_ingredient_shortage or 0), cnt.full_output or 0,
    cnt.no_fuel or 0, all["iron-plate"], all["copper-plate"], idle["iron-plate"], idle["copper-plate"], idle["steel-plate"],
    idle["stone-brick"]))
end

--- C : courant (production, capacite, consommateurs sans courant, chaudieres sans combustible).
RG_TASKS.C = function(ctx, rg, t, tick)
  local cons, cut, low = 0, 0, 0
  for _, e in ipairs(rg_ents(rg, t.f, RG_CONSUMERS)) do
    if rg_is_elec(e.name) then
      cons = cons + 1
      local sn = rg_status(e)
      if sn == "no_power" then cut = cut + 1 elseif sn == "low_power" then low = low + 1 end
    end
  end
  local boilers, nofuel = 0, 0
  for _, e in ipairs(rg_ents(rg, t.f, "boiler")) do
    boilers = boilers + 1
    if rg_status(e) == "no_fuel" then nofuel = nofuel + 1 end
  end
  local gens, working, prod, cap = 0, 0, 0, 0
  for _, e in ipairs(rg_ents(rg, t.f, "generator")) do
    gens = gens + 1
    if rg_status(e) == "working" then working = working + 1 end
    prod = prod + e.energy_generated_last_tick * 60
    local okc, mx = pcall(function() return e.prototype.max_energy_production end)
    cap = cap + (okc and mx or 0) * 60
  end
  -- Statistiques des reseaux (un poteau par reseau) : energie produite et consommee depuis le releve precedent.
  local nets, e_in, e_out, seen = 0, 0, 0, {}
  for _, p in ipairs(rg_ents(rg, t.f, "electric-pole")) do
    local id = p.electric_network_id
    if id and not seen[id] then
      seen[id] = true
      nets = nets + 1
      local okn, st = pcall(function() return p.electric_network_statistics end)
      if okn and st then
        for _, v in pairs(st.input_counts) do e_in = e_in + v end
        for _, v in pairs(st.output_counts) do e_out = e_out + v end
      end
    end
  end
  local pk = t.f .. "#elec"
  local prev = rg.prev[pk] or { tick = 0, e_in = 0, e_out = 0 }
  local sec = math.max((tick - prev.tick) / 60, 1)
  rg.prev[pk] = { tick = tick, e_in = e_in, e_out = e_out }
  ctx.log(string.format(
    "[FO-REGARD] C min=%d force=%s consommateurs=%d sans_courant=%d courant_faible=%d chaudieres=%d chaudieres_sans_combustible=%d "
      .. "generateurs=%d generateurs_en_marche=%d prod_kw=%d capacite_kw=%d reseaux=%d reseau_prod_kw=%d reseau_conso_kw=%d",
    rg_min(tick), t.f, cons, cut, low, boilers, nofuel, gens, working, rg_i(prod / 1000), rg_i(cap / 1000), nets,
    rg_i(math.max(e_in - prev.e_in, 0) / sec / 1000), rg_i(math.max(e_out - prev.e_out, 0) / sec / 1000)))
  -- lot ENERGIE4 (diagnostic, ne change rien au jeu) : les consommateurs sans courant par reseau, depuis combien de temps, ou.
  rg.nop = rg.nop or {}
  rg.nop[t.f] = rg.nop[t.f] or {}
  local nop = rg.nop[t.f]
  local seen, groups, ids = {}, {}, {}
  for _, e in ipairs(rg_ents(rg, t.f, RG_CONSUMERS)) do
    if rg_is_elec(e.name) and rg_status(e) == "no_power" then
      local un = e.unit_number
      seen[un] = true
      nop[un] = nop[un] or tick
      local id = e.electric_network_id or -1
      local g = groups[id]
      if not g then
        g = { n = 0, old = 0, names = {}, x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9, poles = 0, gens = 0, first = tick }
        groups[id] = g
        ids[#ids + 1] = id
      end
      g.n = g.n + 1
      if tick - nop[un] >= 36000 then g.old = g.old + 1 end
      if nop[un] < g.first then g.first = nop[un] end
      g.names[e.name] = (g.names[e.name] or 0) + 1
      local p = e.position
      g.x0, g.y0, g.x1, g.y1 = math.min(g.x0, p.x), math.min(g.y0, p.y), math.max(g.x1, p.x), math.max(g.y1, p.y)
    end
  end
  for un in pairs(nop) do if not seen[un] then nop[un] = nil end end
  table.sort(ids)
  local live = {}
  for _, e in ipairs(rg_ents(rg, t.f, "generator")) do if e.electric_network_id then live[e.electric_network_id] = true end end
  local lp = {}
  for _, p in ipairs(rg_ents(rg, t.f, "electric-pole")) do
    local g = groups[p.electric_network_id or -2]
    if g then g.poles = g.poles + 1 end
    if live[p.electric_network_id or -2] then lp[#lp + 1] = p.position end
  end
  for _, e in ipairs(rg_ents(rg, t.f, "generator")) do
    local g = groups[e.electric_network_id or -2]
    if g then g.gens = g.gens + 1 end
  end
  for _, id in ipairs(ids) do
    local g = groups[id]
    local cx, cy, best = (g.x0 + g.x1) / 2, (g.y0 + g.y1) / 2, 1e9
    for _, q in ipairs(lp) do
      local d = math.sqrt((q.x - cx) ^ 2 + (q.y - cy) ^ 2)
      if d < best then best = d end
    end
    g.gap = best
    local nm = {}
    for k in pairs(g.names) do nm[#nm + 1] = k end
    table.sort(nm)
    for i, k in ipairs(nm) do nm[i] = k .. "=" .. g.names[k] end
    ctx.log(string.format("[FO-REGARD] N min=%d force=%s reseau=%d sans_courant=%d depuis10min=%d premier_min=%.1f poteaux=%d generateurs=%d ecart_reseau_vivant=%.0f "
      .. "boite=%d,%d..%d,%d noms={%s}", rg_min(tick), t.f, id, g.n, g.old, g.first / 3600, g.poles, g.gens, g.gap,
      rg_i(g.x0), rg_i(g.y0), rg_i(g.x1), rg_i(g.y1), table.concat(nm, " ")))
  end
end

--- G0 : foreuses de la force, regroupees en grappes (cellules de 32 tuiles, voisines a 2 cellules) par minerai ;
--- rend une tache G par grappe.
RG_TASKS.G0 = function(ctx, rg, t, tick)
  local by_res = {}
  for _, e in ipairs(rg_ents(rg, t.f, "mining-drill")) do
    local tgt = e.mining_target
    if tgt and tgt.valid and tgt.prototype.resource_category ~= "basic-fluid" then
      local p, tp = e.position, tgt.position
      local list = by_res[tgt.name]
      if not list then
        list = {}
        by_res[tgt.name] = list
      end
      list[#list + 1] = { x = p.x, y = p.y, tx = math.floor(tp.x), ty = math.floor(tp.y), r = e.prototype.mining_drill_radius or 0.99,
        elec = rg_is_elec(e.name), st = rg_status(e) }
    end
  end
  local resnames = {}
  for name in pairs(by_res) do resnames[#resnames + 1] = name end
  table.sort(resnames)
  local clusters = {}
  for _, rn in ipairs(resnames) do
    local cells = {}
    for _, d in ipairs(by_res[rn]) do
      local cx, cy = math.floor(d.x / 32), math.floor(d.y / 32)
      local k = rg_key(cx, cy)
      local c = cells[k]
      if not c then
        c = { cx = cx, cy = cy, drills = {} }
        cells[k] = c
      end
      c.drills[#c.drills + 1] = d
    end
    local keys = {}
    for k in pairs(cells) do keys[#keys + 1] = k end
    table.sort(keys)
    local seen = {}
    for _, k0 in ipairs(keys) do
      if not seen[k0] then
        seen[k0] = true
        local g = { res = rn, drills = {}, x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9 }
        local stack = { k0 }
        while #stack > 0 do
          local c = cells[table.remove(stack)]
          for _, d in ipairs(c.drills) do
            g.drills[#g.drills + 1] = d
            if d.x < g.x0 then g.x0 = d.x end
            if d.y < g.y0 then g.y0 = d.y end
            if d.x > g.x1 then g.x1 = d.x end
            if d.y > g.y1 then g.y1 = d.y end
          end
          for dx = -2, 2 do
            for dy = -2, 2 do
              local k2 = rg_key(c.cx + dx, c.cy + dy)
              if cells[k2] and not seen[k2] then
                seen[k2] = true
                stack[#stack + 1] = k2
              end
            end
          end
        end
        clusters[#clusters + 1] = g
      end
    end
  end
  rg.clusters[t.f] = clusters
  local tasks = {}
  for i = 1, #clusters do tasks[#tasks + 1] = { k = "G", f = t.f, idx = i } end
  return tasks
end

--- G : un groupe de foreuses -> gisements exploites (composantes connexes des tuiles de minerai, trou tolere de 2 tuiles).
RG_TASKS.G = function(ctx, rg, t, tick)
  local cl = rg.clusters[t.f][t.idx]
  local M = 45
  local ax0, ay0, ax1, ay1 = cl.x0 - M, cl.y0 - M, cl.x1 + M, cl.y1 + M
  local res = ctx.surface().find_entities_filtered({ area = { { ax0, ay0 }, { ax1, ay1 } }, name = cl.res })
  local parent, tx, ty, amt, idx = {}, {}, {}, {}, {}
  for i, e in ipairs(res) do
    local p = e.position
    tx[i], ty[i], parent[i], amt[i] = math.floor(p.x), math.floor(p.y), i, e.amount
    idx[rg_key(tx[i], ty[i])] = i
  end
  local function find(i)
    while parent[i] ~= i do
      parent[i] = parent[parent[i]]
      i = parent[i]
    end
    return i
  end
  for i = 1, #res do
    for _, o in ipairs(RG_HALF) do
      local j = idx[rg_key(tx[i] + o[1], ty[i] + o[2])]
      if j then
        local a, b = find(i), find(j)
        if a ~= b then parent[a] = b end
      end
    end
  end
  -- Zones de minage : tuiles couvertes par une foreuse electrique, par une thermique
  local cov_e, cov_t = {}, {}
  for _, d in ipairs(cl.drills) do
    local into = d.elec and cov_e or cov_t
    for ix = math.floor(d.x - d.r), math.floor(d.x + d.r) do
      if math.abs(ix + 0.5 - d.x) <= d.r then
        for iy = math.floor(d.y - d.r), math.floor(d.y + d.r) do
          if math.abs(iy + 0.5 - d.y) <= d.r then
            local j = idx[rg_key(ix, iy)]
            if j then into[j] = true end
          end
        end
      end
    end
  end
  local comp = {}
  local function get(root)
    local c = comp[root]
    if not c then
      c = { n = 0, amount = 0, sx = 0, sy = 0, ce = 0, ct = 0, cany = 0, de = 0, dt = 0, we = 0, wt = 0, nf = 0, fe = 0, ft = 0, np = 0,
        cut = false }
      comp[root] = c
    end
    return c
  end
  local lost = 0
  for _, d in ipairs(cl.drills) do
    local j = idx[rg_key(d.tx, d.ty)]
    if j then
      local c = get(find(j))
      if d.elec then
        c.de = c.de + 1
        if d.st == "working" then c.we = c.we + 1 end
        if d.st == "waiting_for_space_in_destination" then c.fe = c.fe + 1 end
        if d.st == "no_power" or d.st == "low_power" then c.np = c.np + 1 end
      else
        c.dt = c.dt + 1
        if d.st == "working" then c.wt = c.wt + 1 end
        if d.st == "waiting_for_space_in_destination" then c.ft = c.ft + 1 end
        if d.st == "no_fuel" then c.nf = c.nf + 1 end
      end
    else
      lost = lost + 1
    end
  end
  local roots = {}
  for root in pairs(comp) do roots[#roots + 1] = root end
  for j = 1, #res do
    local c = comp[find(j)]
    if c then
      c.n, c.amount, c.sx, c.sy = c.n + 1, c.amount + amt[j], c.sx + tx[j], c.sy + ty[j]
      if cov_e[j] then c.ce = c.ce + 1 end
      if cov_t[j] then c.ct = c.ct + 1 end
      if cov_e[j] or cov_t[j] then c.cany = c.cany + 1 end
      if tx[j] <= ax0 + 2 or ty[j] <= ay0 + 2 or tx[j] >= ax1 - 2 or ty[j] >= ay1 - 2 then c.cut = true end
    end
  end
  table.sort(roots, function(a, b)
    if comp[a].n ~= comp[b].n then return comp[a].n > comp[b].n end
    return a < b
  end)
  for _, root in ipairs(roots) do
    local c = comp[root]
    if c.n > 0 then
      ctx.log(string.format(
        "[FO-REGARD] G min=%d force=%s res=%s c=%d,%d tuiles=%d reste=%d couv_e=%d couv_t=%d couv=%d "
          .. "de=%d dt=%d de_marche=%d dt_marche=%d dt_sans_comb=%d de_pleine=%d dt_pleine=%d de_sans_courant=%d tronque=%d",
        rg_min(tick), t.f, cl.res, rg_i(c.sx / c.n), rg_i(c.sy / c.n), c.n, c.amount, c.ce, c.ct, c.cany, c.de, c.dt, c.we, c.wt,
        c.nf, c.fe, c.ft, c.np, c.cut and 1 or 0))
    end
  end
  if lost > 0 then
    ctx.log(string.format("[FO-REGARD] G min=%d force=%s res=%s hors_releve foreuses=%d", rg_min(tick), t.f, cl.res, lost))
  end
end

--- TC : liste des tapis de la force ; rend une tache TS par tranche de RG_SLICE tapis.
RG_TASKS.TC = function(ctx, rg, t, tick)
  local list = rg_ents(rg, t.f, { "transport-belt", "underground-belt" })
  rg.belts[t.f] = list
  rg.tcur[t.f] = { n = 0, ore = 0, full = 0, ore_full = 0, f1 = 0, ore_f1 = 0, f2 = 0, ore_f2 = 0, sig = {}, fig = {} }
  local tasks = {}
  for from = 1, math.max(#list, 1), RG_SLICE do tasks[#tasks + 1] = { k = "TS", f = t.f, from = from } end
  return tasks
end

local function rg_is_ore(name) return name:sub(-4) == "-ore" or name == "coal" or name == "stone" end

--- TS : une tranche de tapis ; a la derniere, ecrit la ligne T et range les signatures pour le releve suivant.
RG_TASKS.TS = function(ctx, rg, t, tick)
  local list, cur = rg.belts[t.f] or {}, rg.tcur[t.f]
  local old = rg.bsig[t.f] or { sig = {}, fig = {} }
  local last = math.min(t.from + RG_SLICE - 1, #list)
  for i = t.from, last do
    local b = list[i]
    if b.valid then
      cur.n = cur.n + 1
      local ore, fullore, parts = 0, false, {}
      for li = 1, 2 do
        local lane_ore = 0
        for name, c in pairs(b.get_transport_line(li).get_contents()) do
          if rg_is_ore(name) then
            lane_ore = lane_ore + c
            parts[#parts + 1] = li .. name .. c
          end
        end
        ore = ore + lane_ore
        if lane_ore >= 4 then fullore = true end
      end
      if ore > 0 then
        cur.ore = cur.ore + ore
        local p = b.position
        local id, sig = rg_key(math.floor(p.x), math.floor(p.y)), table.concat(parts, ",")
        cur.sig[id] = sig
        if fullore then
          cur.full, cur.ore_full = cur.full + 1, cur.ore_full + ore
          if old.sig[id] == sig then
            cur.f1, cur.ore_f1 = cur.f1 + 1, cur.ore_f1 + ore
            cur.fig[id] = true
            if old.fig[id] then cur.f2, cur.ore_f2 = cur.f2 + 1, cur.ore_f2 + ore end
          end
        end
      end
    end
  end
  if last >= #list then
    ctx.log(string.format(
      "[FO-REGARD] T min=%d force=%s tapis=%d minerai_sur_tapis=%d cases_bouchees=%d minerai_bouche=%d cases_figees5=%d minerai_fige5=%d "
        .. "cases_figees10=%d minerai_fige10=%d precedent=%d",
      rg_min(tick), t.f, cur.n, cur.ore, cur.full, cur.ore_full, cur.f1, cur.ore_f1, cur.f2, cur.ore_f2, rg.bsig[t.f] and 1 or 0))
    rg.bsig[t.f] = { sig = cur.sig, fig = cur.fig }
    rg.belts[t.f], rg.tcur[t.f] = nil, nil
  end
end

--- Lance un releve : une file de taches par force, dans l'ordre des equipes.
local function rg_start(ctx, tick)
  local rg = rg_state(ctx)
  rg.n = rg.n + 1
  for _, row in ipairs(teams()) do
    for _, k in ipairs({ "SCAN", "R", "F", "C", "G0", "TC" }) do
      rg.queue[#rg.queue + 1] = { k = k, f = row.force, row = k == "R" and row or nil, first = rg.n == 1, t0 = tick }
    end
    rg.queue[#rg.queue + 1] = { k = "COUT", f = row.force, t0 = tick }
  end
end

--- Une tache par tick au plus (profileur autour de chaque tache ; le cumul par force est ecrit en fin de releve).
local function rg_step(ctx)
  local rg = rg_state(ctx)
  local task = rg.queue[rg.head]
  if not task then
    if rg.head > 1 then rg.queue, rg.head = {}, 1 end
    return
  end
  rg.head = rg.head + 1
  if task.k == "COUT" then
    if rg_acc[task.f] then
      log({ "", ctx.tag, " [FO-REGARD] COUT min=", tostring(rg_min(task.t0)), " force=", task.f, " total ", rg_acc[task.f] })
      rg_acc[task.f] = nil
    end
    rg.ents[task.f] = nil
    return
  end
  local p = game.create_profiler()
  local ok, more = pcall(RG_TASKS[task.k], ctx, rg, task, task.t0)
  p.stop()
  if not ok then
    ctx.log("[FO-REGARD] ERREUR tache " .. task.k .. " " .. task.f .. " : " .. tostring(more))
    more = nil
  end
  if task.first then log({ "", ctx.tag, " [FO-REGARD] TACHE force=", task.f, " k=", task.k, " ", p }) end
  if rg_acc[task.f] then rg_acc[task.f].add(p) else rg_acc[task.f] = p end
  if type(more) == "table" then
    for i = #more, 1, -1 do
      more[i].t0, more[i].first = task.t0, task.first
      table.insert(rg.queue, rg.head, more[i])
    end
  end
end

local function checkpoint(ctx, tick)
  local s, p = ctx.surface(), game.connected_players[1]
  local minute = math.floor(tick / 3600)
  for _, row in ipairs(teams()) do
    local force = game.forces[row.force]
    local parts = {}
    for _, t in ipairs(TYPES) do
      parts[#parts + 1] = t .. "=" .. s.count_entities_filtered({ type = t, force = row.force })
    end
    local made = {}
    if force then
      for _, it in ipairs(PLATES) do
        made[#made + 1] = it .. "=" .. force.item_production_statistics.get_input_count(it)
      end
    end
    local center, zoom, w, h = wide_view(s, row.force, hq_position(s, row))
    ctx.log(string.format("[FO-EVOL] minute %d | %s | n=%d emprise=%dx%d | %s | produit %s", minute, row.key, row.n or -1, w, h,
      table.concat(parts, " "), table.concat(made, " ")))
    if p then
      for _, v in ipairs({ { "large", center, zoom }, { "qg", hq_position(s, row), 0.5 } }) do
        game.take_screenshot({ path = string.format("fo-shots/evol-%03dmin-%s-%s.png", minute, row.key, v[1]), player = p,
          surface = s, position = v[2], zoom = v[3], resolution = { 1920, 1080 }, daytime = 0, force_render = true,
          show_entity_info = true, allow_in_replay = true })
      end
    end
  end
end

local init0, tick0 = base.init, base.tick
base.description = "DC : partie de 2 h, 3 factions, 30 ouvriers, captures toutes les 15 min"
base.check_tick = CHECK
base.shots_delay = CHECK + 2000
base.init = function(ctx)
  init0(ctx)
  ctx.check(ctx.remote("factorio-overhaul", "war_setting", "fo-war-factions", 3) == 3, "3 factions")
end
-- Le joueur de la session : sans personnage, comme les bancs sans images. Avec lui, la 1re partie s'est figee a la minute 13,9
-- (biters a 28 tuiles de lui, plus aucune ligne de journal, processus au repos ; mort du personnage : cause supposee, non prouvee).
local function ghost_player()
  local p = game.connected_players[1]
  if p and p.character then
    p.character.destroy()
    p.set_controller({ type = defines.controllers.spectator })
  end
end
base.tick = function(ctx, e)
  if e.tick % 600 == 0 then
    ghost_player()
    game.speed = e.tick < CHECK and SPEED or 1 -- 2 h de jeu a x1 = 2 h de PC
  end
  tick0(ctx, e)
  if e.tick > 0 and e.tick % EVERY == 0 and e.tick <= CHECK then checkpoint(ctx, e.tick) end
  -- Lot REGARD : echantillon des PNJ toutes les 30 s, releve toutes les 5 min, une tache par tick.
  if e.tick % RG_PNJ_EVERY == 0 then rg_sample_pnj(ctx, e.tick) end
  if e.tick > 0 and e.tick % RG_EVERY == 0 then rg_start(ctx, e.tick) end
  rg_step(ctx)
end
base.shots = function(ctx, add)
  local s = ctx.surface()
  for _, row in ipairs(teams()) do
    local q = hq_position(s, row)
    add("evol-fin-" .. row.key, q.x, q.y, 0.5, 0)
  end
end
base.finish = function(ctx)
  local poi = ctx.call("points_of_interest")
  ctx.log("factions vivantes a la fin : " .. #poi.factions)
  ctx.check(true, "partie allee jusqu'au controle de 2 h", #poi.factions)
end
return base
end
