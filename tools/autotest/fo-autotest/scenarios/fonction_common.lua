--[[
  Lot MESURES (28/10) : indicateurs FONCTIONNELS d'une base, lus sur le moteur, pour une force (votre équipe ou une
  faction), à ajouter à un scénario de partie (etape1-guide). Contre-mesure aux comptes de présence (« 54 fours ») :
  un four posé vaut 1 ; ici on lit ce qu'il a produit, son état, qui le nourrit. Aucune lecture n'entre dans un BILAN
  (docs/PORTES_MESURES.md : aucun seuil avant d'avoir vu les distributions). Rien n'est écrit dans la partie.

  Usage dans un scénario (état persistant `st` = ctx.state()) :
    local Fn = require("scenarios/fonction_common")
    Fn.sample_all(st, surface, forces, tick)            -- tous les Fn.SAMPLE ticks (1 800 = 30 s)
    Fn.report_all(st, surface, forces, minute, tick, rows) -- à chaque fenêtre (10 min) : journalise et roule la fenêtre
  `forces` = { { key = "player", force = "player" }, { key = "scarlet", force = "fo-scarlet" }, ... } ;
  `rows` = rendu de remote.call("fo-ia1", "teams") (facultatif : palier de recherche et inactifs « du mod »).

  Lignes (grep « \[FO-FONCTION\] ») : « [FO-FONCTION] <genre> minute N | <clé> | k=v k=v … », valeurs sans espace.
  Genres : prod, fours, statut, elec, tapis, tourelles, corps, dormants, tech, parite (docs/PORTES_MESURES.md :
  ce que chacun prouve et ne prouve pas ; lecture : tools/autotest/fonction_mesures.py).
  Définitions retenues :
   - « alimenté » (four) : une foreuse y dépose (drop_target), ou un bras y dépose depuis un tapis, ou depuis un coffre
     lui-même alimenté par une foreuse/un bras (un niveau) : classe auto ; bras depuis un coffre non alimenté ou autre
     entité : classe coffre ; aucun alimenteur : classe main (posé et servi à la main) ;
   - four « actif 50 % » : sa production de la fenêtre (products_finished × énergie de la recette ÷ 3,2 s, en
     équivalents-plaque) atteint la moitié de sa cadence nominale (crafting_speed ÷ 3,2 s) sur la durée où il a été vu ;
   - tapis « utile » : lui-même ou un tapis en aval est la cible de prise d'un bras (remontée depuis les prises) ;
   - corps « inerte » : même position (< 1 tuile) qu'au relevé précédent, sans miner ni fabriquer.
  Limites : relevés toutes les 30 s (un état de moins de 30 s échappe) ; products_finished ne voit que les machines
  (pas les objets fabriqués à la main par un PNJ, F319) ; entités détruites en cours de fenêtre non comptées.
]]

local F = {}

F.TAG = "[FO-FONCTION] "
F.SAMPLE = 1800      -- ticks entre deux relevés d'état (30 s)
F.FULL_BELT = 7      -- objets sur une tuile de tapis (max 8) à partir desquels elle est « pleine »
F.NOMINAL_S = 3.2    -- énergie de la recette de référence (plaque) : cadence nominale = crafting_speed / 3,2 par s
F.MIN_SAMPLES = 3    -- relevés minimum pour qu'un four compte dans la population productive
F.INACTIVE_SHARE = 0.2 -- une machine « inactive » travaille au plus cette part de ses relevés (>= 5 relevés)

local MACHINE_TYPES = { "furnace", "mining-drill", "inserter", "assembling-machine", "lab", "ammo-turret", "generator",
  "boiler" }
local BELT_TYPES = { "transport-belt", "underground-belt", "splitter" }
local BELT_SET = { ["transport-belt"] = true, ["underground-belt"] = true, ["splitter"] = true }
local CHEST_SET = { container = true, ["logistic-container"] = true }
local TRACK = { four = true, foreuse_elec = true, foreuse_comb = true, assembleur = true, labo = true }
local BAD_POWER = { no_power = true, not_plugged_in_electric_network = true, low_power = true }
local IN_ITEMS = { "iron-plate", "copper-plate", "stone-brick", "steel-plate", "iron-ore", "copper-ore", "coal", "stone",
  "iron-gear-wheel", "electronic-circuit" }
local PACKS = { "automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack",
  "production-science-pack", "utility-science-pack", "space-science-pack" }
local CLASSES = { "four", "foreuse_elec", "foreuse_comb", "pompe", "bras_elec", "bras_therm", "assembleur", "labo",
  "tourelle", "generateur", "chaudiere" }

---------------------------------------------------------------------------------------------------
-- Outils purs (testés hors jeu)
---------------------------------------------------------------------------------------------------

--- Médiane d'une liste de nombres (moyenne des deux du milieu si pair) ; nil si vide.
function F.median(list)
  local v = {}
  for _, x in ipairs(list) do v[#v + 1] = x end
  if #v == 0 then return nil end
  table.sort(v)
  local n = #v
  if n % 2 == 1 then return v[(n + 1) / 2] end
  return (v[n / 2] + v[n / 2 + 1]) / 2
end

--- Classe d'alimentation d'un four d'après le tableau des alimenteurs (voir F.feeders) : "auto", "coffre" ou "main".
function F.feed_class(feeders, un)
  local c = feeders[un]
  if c == "foreuse" or c == "tapis" or c == "coffre_alimente" then return "auto" end
  if c == "coffre" or c == "autre" then return "coffre" end
  return "main"
end

local status_names
local function status_table()
  if not status_names then
    status_names = {}
    for name, v in pairs(defines.entity_status) do status_names[v] = name end
  end
  return status_names
end

local function status_name(e)
  local s = e.status
  return s and status_table()[s] or "aucun"
end

local function f1(x) return string.format("%.1f", x) end
local function f2(x) return string.format("%.2f", x) end

local function class_of(e)
  local t = e.type
  if t == "furnace" then return "four"
  elseif t == "mining-drill" then
    if e.name:find("pumpjack", 1, true) then return "pompe" end
    return e.prototype.electric_energy_source_prototype and "foreuse_elec" or "foreuse_comb"
  elseif t == "inserter" then
    return e.prototype.electric_energy_source_prototype and "bras_elec" or "bras_therm"
  elseif t == "assembling-machine" then return "assembleur"
  elseif t == "lab" then return "labo"
  elseif t == "ammo-turret" then return "tourelle"
  elseif t == "generator" then return "generateur"
  elseif t == "boiler" then return "chaudiere" end
  return nil
end

local function recipe_energy(e)
  local ok, r = pcall(function() return e.previous_recipe end)
  if ok and r and r.energy and r.energy > 0 then return r.energy end
  return F.NOMINAL_S
end

---------------------------------------------------------------------------------------------------
-- État par force
---------------------------------------------------------------------------------------------------

local function K_of(st, key)
  st.fn = st.fn or { forces = {} }
  local K = st.fn.forces[key]
  if not K then
    K = { win0 = nil, nsamp = 0, hist = {}, ent = {}, kw_sum = 0, kw_n = 0, body = {},
      bcls = { mine = 0, fabrique = 0, marche = 0, inerte = 0 }, prod0 = {}, out0 = {}, idle0 = nil }
    st.fn.forces[key] = K
  end
  return K
end

local function researched(force)
  local n = 0
  local f = game.forces[force]
  if not f then return 0 end
  for _, tc in pairs(f.technologies) do if tc.researched then n = n + 1 end end
  return n
end
F.researched = researched

local function stats_snapshot(force)
  local snap_in, snap_out = {}, {}
  local f = game.forces[force]
  if not f then return snap_in, snap_out end
  local fs = f.item_production_statistics
  for _, it in ipairs(IN_ITEMS) do snap_in[it] = fs.get_input_count(it) end
  for _, it in ipairs(PACKS) do
    snap_in[it] = fs.get_input_count(it)
    snap_out[it] = fs.get_output_count(it)
  end
  return snap_in, snap_out
end

--- Fixe la base de la fenêtre au premier appel où la force existe (les factions naissent après le tick 0).
local function init_force(K, force, tick, row)
  if K.win0 then return true end
  if not game.forces[force] then return false end
  K.win0 = tick
  K.prod0, K.out0 = stats_snapshot(force)
  K.tech0 = researched(force)
  K.idle0 = { n = row and row.n_sum or 0, idle = row and row.idle_sum or 0 }
  return true
end

---------------------------------------------------------------------------------------------------
-- Relevé d'état (toutes les F.SAMPLE ticks)
---------------------------------------------------------------------------------------------------

function F.sample(st, s, key, force, tick, row)
  local K = K_of(st, key)
  if not init_force(K, force, tick, row) then return end
  K.nsamp = K.nsamp + 1
  local kw = 0
  for _, e in ipairs(s.find_entities_filtered({ force = force, type = MACHINE_TYPES })) do
    local cls = class_of(e)
    if cls then
      local sn = status_name(e)
      local h = K.hist[cls]
      if not h then h = { _n = 0 } K.hist[cls] = h end
      h._n = h._n + 1
      h[sn] = (h[sn] or 0) + 1
      if TRACK[cls] then
        local ec = K.ent[cls]
        if not ec then ec = {} K.ent[cls] = ec end
        local r = ec[e.unit_number]
        if not r then
          r = { t0 = tick, ns = 0, ws = 0 }
          if cls == "four" or cls == "assembleur" then r.pf0 = e.products_finished end
          ec[e.unit_number] = r
        end
        r.ns = r.ns + 1
        if sn == "working" then r.ws = r.ws + 1 end
        r.t = tick
      end
      if cls == "generateur" then kw = kw + (e.energy_generated_last_tick or 0) * 60 / 1000 end
    end
  end
  K.kw_sum, K.kw_n = K.kw_sum + kw, K.kw_n + 1
  -- corps des PNJ (hors personnage connecté d'un joueur)
  for _, c in ipairs(s.find_entities_filtered({ force = force, type = "character" })) do
    if not c.player then
      local un = c.unit_number
      local p = K.body[un]
      local x, y = c.position.x, c.position.y
      if p then
        local bc
        if c.mining_state and c.mining_state.mining then bc = "mine"
        elseif c.crafting_queue_size > 0 then bc = "fabrique"
        elseif (x - p.x) ^ 2 + (y - p.y) ^ 2 >= 1 then bc = "marche"
        else bc = "inerte" end
        K.bcls[bc] = K.bcls[bc] + 1
      end
      K.body[un] = { x = x, y = y, t = tick }
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Alimenteurs structurels et tapis
---------------------------------------------------------------------------------------------------

--- Table unit_number de la cible -> "foreuse" | "tapis" | "coffre_alimente" | "coffre" | "autre", d'après les foreuses
--- (drop_target) et les bras (drop_target, pickup_target) de la force. Rend aussi l'ensemble des tapis visés par une prise.
function F.feeders(s, force)
  local out, picks = {}, {}
  local rank = { foreuse = 1, tapis = 2, coffre_alimente = 3, coffre = 4, autre = 5 }
  local function put(un, c)
    if not out[un] or rank[c] < rank[out[un]] then out[un] = c end
  end
  local ins = {}
  for _, e in ipairs(s.find_entities_filtered({ force = force, type = { "inserter", "mining-drill" } })) do
    local t = e.drop_target
    if e.type == "mining-drill" then
      if t and t.valid and t.unit_number then put(t.unit_number, "foreuse") end
    else
      local pt = e.pickup_target
      if pt and pt.valid and pt.unit_number and BELT_SET[pt.type] then picks[pt.unit_number] = true end
      if t and t.valid and t.unit_number and pt and pt.valid then ins[#ins + 1] = { t = t, pt = pt } end
    end
  end
  for _, r in ipairs(ins) do
    local un, pt = r.t.unit_number, r.pt
    if BELT_SET[pt.type] then put(un, "tapis")
    elseif not CHEST_SET[pt.type] then put(un, "autre") end
  end
  -- coffres : alimentés si une foreuse ou un bras sur tapis y dépose (résolu après les autres, indépendant de l'ordre)
  local fed = {}
  for un, c in pairs(out) do if c == "foreuse" or c == "tapis" then fed[un] = true end end
  for _, r in ipairs(ins) do
    local un, pt = r.t.unit_number, r.pt
    if CHEST_SET[pt.type] then put(un, fed[pt.unit_number] and "coffre_alimente" or "coffre") end
  end
  return out, picks
end

--- Tapis de la force : { belts, utiles, pleines, pleines_inutiles, terminaux, terminaux_pleins_inutiles, vides }.
function F.belts(s, force, picks)
  local idx, list = {}, s.find_entities_filtered({ force = force, type = BELT_TYPES })
  local belts = 0
  for _, e in ipairs(list) do
    local un = e.unit_number
    local rec = { ins = {}, outs = 0, type = e.type }
    local bn = e.belt_neighbours
    if bn then
      for _, n in ipairs(bn.inputs or {}) do if n.valid and n.unit_number then rec.ins[#rec.ins + 1] = n.unit_number end end
      rec.outs = #(bn.outputs or {})
    end
    if e.type == "underground-belt" and e.belt_to_ground_type == "output" then
      local pair = e.neighbours
      if pair and pair.valid and pair.unit_number then rec.ins[#rec.ins + 1] = pair.unit_number end
    end
    if e.type == "transport-belt" then
      belts = belts + 1
      rec.items = e.get_transport_line(1).get_item_count() + e.get_transport_line(2).get_item_count()
    end
    idx[un] = rec
  end
  -- remontée depuis les prises
  local useful, stack = {}, {}
  for un in pairs(picks) do
    if idx[un] and not useful[un] then useful[un] = true stack[#stack + 1] = un end
  end
  while #stack > 0 do
    local un = table.remove(stack)
    for _, i in ipairs(idx[un].ins) do
      if idx[i] and not useful[i] then useful[i] = true stack[#stack + 1] = i end
    end
  end
  local R = { belts = belts, utiles = 0, pleines = 0, pleines_inutiles = 0, terminaux = 0, terminaux_pleins_inutiles = 0,
    vides = 0 }
  for un, rec in pairs(idx) do
    if rec.items then
      local full = rec.items >= F.FULL_BELT
      if useful[un] then R.utiles = R.utiles + 1 end
      if full then
        R.pleines = R.pleines + 1
        if not useful[un] then R.pleines_inutiles = R.pleines_inutiles + 1 end
      end
      if rec.items == 0 then R.vides = R.vides + 1 end
      if rec.outs == 0 then
        R.terminaux = R.terminaux + 1
        if full and not picks[un] then R.terminaux_pleins_inutiles = R.terminaux_pleins_inutiles + 1 end
      end
    end
  end
  return R
end

---------------------------------------------------------------------------------------------------
-- Stock non posé (coffre + annexes + corps)
---------------------------------------------------------------------------------------------------

local function stock_cat(name)
  if name:find("furnace", 1, true) then return "fours" end
  if name:find("drill", 1, true) and not name:find("pumpjack", 1, true) then return "foreuses" end
  if name:find("assembl", 1, true) then return "assembleurs" end
  if name == "lab" or name:find("^fo%-lvl%-lab") then return "labos" end
  if name:find("inserter", 1, true) then return "bras" end
  return nil
end

local function add_inv(tot, inv)
  if not inv then return end
  for name, n in pairs(inv.get_contents()) do
    local c = stock_cat(name)
    if c then tot[c] = (tot[c] or 0) + n end
  end
end

local function stock_of(s, force)
  local chest, bodies = {}, {}
  local anchor = s.find_entities_filtered({ name = { "fo-faction-hq", "fo-team-chest" }, force = force, limit = 1 })[1]
  if anchor then
    add_inv(chest, anchor.get_inventory(defines.inventory.chest))
    local p = anchor.position
    for _, e in ipairs(s.find_entities_filtered({ area = { { p.x - 8, p.y + 3 }, { p.x + 16, p.y + 22 } }, force = force,
      name = { "iron-chest", "wooden-chest" } })) do
      add_inv(chest, e.get_inventory(defines.inventory.chest))
    end
  end
  for _, c in ipairs(s.find_entities_filtered({ force = force, type = "character" })) do
    if not c.player then add_inv(bodies, c.get_main_inventory()) end
  end
  return chest, bodies
end

---------------------------------------------------------------------------------------------------
-- Rapport d'une force (fin de fenêtre)
---------------------------------------------------------------------------------------------------

local function hist_line(K, cls)
  local h = K.hist[cls]
  if not h or h._n == 0 then return nil end
  local names = {}
  for k in pairs(h) do if k ~= "_n" then names[#names + 1] = k end end
  table.sort(names)
  local parts = {}
  for _, k in ipairs(names) do parts[#parts + 1] = k .. "=" .. h[k] end
  return table.concat(parts, " ")
end

local function share_working(K, cls)
  local h = K.hist[cls]
  if not h or h._n == 0 then return 0 end
  return (h.working or 0) / h._n
end

local function logl(kind, minute, key, body)
  log(F.TAG .. string.format("%s minute %d | %s | %s", kind, minute, key, body))
end

--- Rapport de la fenêtre qui se termine ; rend la table M des valeurs de parité.
function F.report(st, s, key, force, minute, tick, row)
  local K = K_of(st, key)
  if not init_force(K, force, tick, row) then return { key = key, morte = 1, pnj = 0 } end
  local win_s = math.max(1, (tick - K.win0) / 60)
  local win_min = win_s / 60
  local M = { key = key }

  local all = s.find_entities_filtered({ force = force, type = MACHINE_TYPES })
  local by = {}
  for _, c in ipairs(CLASSES) do by[c] = {} end
  for _, e in ipairs(all) do
    local c = class_of(e)
    if c then by[c][#by[c] + 1] = e end
  end

  -- corps
  local bodies = 0
  for _, c in ipairs(s.find_entities_filtered({ force = force, type = "character" })) do
    if not c.player then bodies = bodies + 1 end
  end
  M.pnj = bodies
  M.morte = (bodies == 0) and 1 or 0

  -- production de la force (statistiques du moteur : machines seulement, F319)
  local pin, pout = stats_snapshot(force)
  local function d_in(it) return (pin[it] or 0) - (K.prod0[it] or 0) end
  local function d_out(it) return (pout[it] or 0) - (K.out0[it] or 0) end
  local plaques = d_in("iron-plate") + d_in("copper-plate") + d_in("stone-brick")
  local acier = d_in("steel-plate")
  local fab, conso = 0, 0
  for _, p in ipairs(PACKS) do fab = fab + d_in(p) conso = conso + d_out(p) end
  M.plaques_min = plaques / win_min
  M.acier_min = acier / win_min
  M.eq_stats_min = (plaques + 5 * acier) / win_min
  logl("prod", minute, key, string.format(
    "fenetre=%s pnj=%d morte=%d plaques_min=%s fer_min=%s cuivre_min=%s brique_min=%s acier_min=%s ore_fer_min=%s"
    .. " ore_cuivre_min=%s charbon_min=%s pierre_min=%s engrenages_min=%s circuits_min=%s packs_fab=%d packs_conso=%d",
    f1(win_min), bodies, M.morte, f1(M.plaques_min), f1(d_in("iron-plate") / win_min), f1(d_in("copper-plate") / win_min),
    f1(d_in("stone-brick") / win_min), f1(M.acier_min), f1(d_in("iron-ore") / win_min), f1(d_in("copper-ore") / win_min),
    f1(d_in("coal") / win_min), f1(d_in("stone") / win_min), f1(d_in("iron-gear-wheel") / win_min),
    f1(d_in("electronic-circuit") / win_min), fab, conso))

  -- fours : production par machine, alimenteurs
  local feeders, picks = F.feeders(s, force)
  local G = {}
  for _, g in ipairs({ "auto", "coffre", "main" }) do
    G[g] = { n = 0, pop = 0, prod = 0, a50 = 0, ws = 0, ns = 0, eq = 0, nom = 0 }
  end
  local cap_min, jeunes, fe_by = 0, 0, { foreuse = 0, tapis = 0, coffre_alimente = 0, coffre = 0, autre = 0, aucun = 0 }
  local ft = K.ent.four or {}
  for _, e in ipairs(by.four) do
    local g = G[F.feed_class(feeders, e.unit_number)]
    local fc = feeders[e.unit_number] or "aucun"
    fe_by[fc] = fe_by[fc] + 1
    g.n = g.n + 1
    local cs = e.crafting_speed or 1
    cap_min = cap_min + 60 * cs / F.NOMINAL_S
    local r = ft[e.unit_number]
    if r and r.ns >= F.MIN_SAMPLES then
      local en = recipe_energy(e)
      local pf = e.products_finished
      local dlt = pf - (r.pf0 or pf)
      local expo = math.max(1, (tick - r.t0) / 60)
      local eq = dlt * en / F.NOMINAL_S
      local nom = cs / F.NOMINAL_S * expo
      g.pop, g.eq, g.nom = g.pop + 1, g.eq + eq, g.nom + nom
      if dlt > 0 then g.prod = g.prod + 1 end
      if eq >= 0.5 * nom then g.a50 = g.a50 + 1 end
      g.ws, g.ns = g.ws + r.ws, g.ns + r.ns
    else
      jeunes = jeunes + 1
    end
  end
  local nf = #by.four
  local function gs(g, fld) return G[g][fld] end
  logl("fours", minute, key, string.format(
    "n=%d jeunes=%d cap_min=%s foreuse=%d tapis=%d coffre_alimente=%d coffre=%d autre=%d aucun=%d"
    .. " n_auto=%d n_coffre=%d n_main=%d pop_auto=%d pop_coffre=%d pop_main=%d prod_auto=%d prod_coffre=%d prod_main=%d"
    .. " a50_auto=%d a50_coffre=%d a50_main=%d ws_auto=%d ws_coffre=%d ws_main=%d ns_auto=%d ns_coffre=%d ns_main=%d"
    .. " eq_auto=%s eq_coffre=%s eq_main=%s nom_auto=%s nom_coffre=%s nom_main=%s",
    nf, jeunes, f1(cap_min), fe_by.foreuse, fe_by.tapis, fe_by.coffre_alimente, fe_by.coffre, fe_by.autre, fe_by.aucun,
    gs("auto", "n"), gs("coffre", "n"), gs("main", "n"), gs("auto", "pop"), gs("coffre", "pop"), gs("main", "pop"),
    gs("auto", "prod"), gs("coffre", "prod"), gs("main", "prod"), gs("auto", "a50"), gs("coffre", "a50"), gs("main", "a50"),
    gs("auto", "ws"), gs("coffre", "ws"), gs("main", "ws"), gs("auto", "ns"), gs("coffre", "ns"), gs("main", "ns"),
    f1(gs("auto", "eq")), f1(gs("coffre", "eq")), f1(gs("main", "eq")),
    f1(gs("auto", "nom")), f1(gs("coffre", "nom")), f1(gs("main", "nom"))))
  M.fours_n = nf
  M.fours_a50 = G.auto.a50 + G.coffre.a50 + G.main.a50
  M.fours_auto = G.auto.n
  M.fours_prod_eq = (G.auto.eq + G.coffre.eq + G.main.eq) / win_min

  -- assembleurs : avec recette, ayant produit
  local asm_r, asm_p = 0, 0
  local at = K.ent.assembleur or {}
  for _, e in ipairs(by.assembleur) do
    if e.get_recipe() then asm_r = asm_r + 1 end
    local r = at[e.unit_number]
    if r and r.pf0 and e.products_finished > r.pf0 then asm_p = asm_p + 1 end
  end

  -- statuts échantillonnés
  for _, c in ipairs(CLASSES) do
    local line = hist_line(K, c)
    if line then
      logl("statut", minute, key, string.format("classe=%s n=%d samples=%d %s", c, #by[c], K.hist[c]._n, line))
    end
  end

  -- électricité
  local gnets, kw_now = {}, 0
  for _, e in ipairs(by.generateur) do
    local id = e.electric_network_id
    if id then gnets[id] = true end
    kw_now = kw_now + (e.energy_generated_last_tick or 0) * 60 / 1000
  end
  local n_gnets = 0
  for _ in pairs(gnets) do n_gnets = n_gnets + 1 end
  local pnets, poles, poles_gen = {}, 0, 0
  for _, p in ipairs(s.find_entities_filtered({ force = force, type = "electric-pole" })) do
    poles = poles + 1
    local id = p.electric_network_id
    if id then
      pnets[id] = true
      if gnets[id] then poles_gen = poles_gen + 1 end
    end
  end
  local n_pnets = 0
  for _ in pairs(pnets) do n_pnets = n_pnets + 1 end
  local kw_moy = K.kw_n > 0 and K.kw_sum / K.kw_n or 0
  local cons = {}
  for _, cls in ipairs({ "foreuse_elec", "bras_elec", "assembleur", "labo" }) do
    local pose, inn, ok = 0, 0, 0
    for _, e in ipairs(by[cls]) do
      pose = pose + 1
      local id = e.electric_network_id
      if id and gnets[id] then
        inn = inn + 1
        if not BAD_POWER[status_name(e)] and e.status ~= nil then ok = ok + 1 end
      end
    end
    cons[#cons + 1] = string.format("%s_pose=%d %s_reseau=%d %s_alimentes=%d", cls, pose, cls, inn, cls, ok)
  end
  local fe_el = 0
  for _, e in ipairs(by.four) do if e.prototype.electric_energy_source_prototype then fe_el = fe_el + 1 end end
  logl("elec", minute, key, string.format(
    "kw_moy=%s kw_now=%s generateurs=%d chaudieres=%d poteaux=%d poteaux_reseau_gen=%d reseaux_poteaux=%d reseaux_gen=%d"
    .. " fours_elec=%d %s", f1(kw_moy), f1(kw_now), #by.generateur, #by.chaudiere, poles, poles_gen, n_pnets, n_gnets,
    fe_el, table.concat(cons, " ")))
  M.kw_moy = kw_moy
  M.poteaux_gen = poles_gen

  -- bras : cibles
  local ins_ok, ins_n = 0, 0
  for _, cls in ipairs({ "bras_elec", "bras_therm" }) do
    for _, e in ipairs(by[cls]) do
      ins_n = ins_n + 1
      local a, b = e.pickup_target, e.drop_target
      if a and a.valid and b and b.valid then ins_ok = ins_ok + 1 end
    end
  end
  logl("bras", minute, key, string.format("elec=%d therm=%d avec_cibles=%d", #by.bras_elec, #by.bras_therm, ins_ok))

  -- tapis
  local B = F.belts(s, force, picks)
  logl("tapis", minute, key, string.format(
    "tapis=%d utiles=%d pleines=%d pleines_inutiles=%d vides=%d terminaux=%d terminaux_pleins_inutiles=%d",
    B.belts, B.utiles, B.pleines, B.pleines_inutiles, B.vides, B.terminaux, B.terminaux_pleins_inutiles))

  -- tourelles : munitions réelles
  local t0, t1, t2, tot = 0, 0, 0, 0
  for _, e in ipairs(by.tourelle) do
    local inv = e.get_inventory(defines.inventory.turret_ammo)
    local n = inv and inv.get_item_count() or 0
    tot = tot + n
    if n == 0 then t0 = t0 + 1 elseif n < 5 then t1 = t1 + 1 else t2 = t2 + 1 end
  end
  logl("tourelles", minute, key, string.format("n=%d vides=%d faibles=%d armees=%d munitions=%d", #by.tourelle, t0, t1, t2, tot))

  -- corps des PNJ : état observé aux relevés ; inactifs du mod à côté
  local bc = K.bcls
  local bn = bc.mine + bc.fabrique + bc.marche + bc.inerte
  local idle_mod = -1
  if row and K.idle0 then
    local dn = (row.n_sum or 0) - K.idle0.n
    if dn > 0 then idle_mod = 100 * ((row.idle_sum or 0) - K.idle0.idle) / dn end
  end
  logl("corps", minute, key, string.format("corps=%d relevés=%d mine=%d fabrique=%d marche=%d inerte=%d inactifs_mod_pct=%s",
    bodies, bn, bc.mine, bc.fabrique, bc.marche, bc.inerte, f1(idle_mod)))
  M.inerte_pct = bn > 0 and 100 * bc.inerte / bn or -1

  -- dormants : stock non posé + capital posé inactif
  local chest, body = stock_of(s, force)
  local function inact(cls, list)
    local pop, bad = 0, 0
    local ec = K.ent[cls] or {}
    for _, e in ipairs(list) do
      local r = ec[e.unit_number]
      if r and r.ns >= 5 then
        pop = pop + 1
        if r.ws / r.ns <= F.INACTIVE_SHARE then bad = bad + 1 end
      end
    end
    return bad, pop
  end
  local ib_f, ip_f = inact("four", by.four)
  local ib_e, ip_e = inact("foreuse_elec", by.foreuse_elec)
  local ib_c, ip_c = inact("foreuse_comb", by.foreuse_comb)
  local ib_a, ip_a = inact("assembleur", by.assembleur)
  logl("dormants", minute, key, string.format(
    "stock_coffre_fours=%d stock_coffre_foreuses=%d stock_coffre_assembleurs=%d stock_coffre_labos=%d stock_coffre_bras=%d"
    .. " stock_corps_fours=%d stock_corps_foreuses=%d stock_corps_assembleurs=%d stock_corps_labos=%d stock_corps_bras=%d"
    .. " inactifs_fours=%d/%d inactifs_foreuses_elec=%d/%d inactifs_foreuses_comb=%d/%d inactifs_assembleurs=%d/%d"
    .. " assembleurs_recette=%d assembleurs_produit=%d",
    chest.fours or 0, chest.foreuses or 0, chest.assembleurs or 0, chest.labos or 0, chest.bras or 0,
    body.fours or 0, body.foreuses or 0, body.assembleurs or 0, body.labos or 0, body.bras or 0,
    ib_f, ip_f, ib_e, ip_e, ib_c, ip_c, ib_a, ip_a, asm_r, asm_p))

  -- recherche : même fonction pour toutes les forces
  local techs = researched(force)
  M.techs_fait = techs - (K.tech0 or 0)
  logl("tech", minute, key, string.format("researched=%d depuis_debut=%d palier_mod=%s packs_conso=%d packs_fab=%d",
    techs, M.techs_fait, row and tostring(row.tech) or "-", conso, fab))

  -- valeurs de parité
  M.fe_working = #by.foreuse_elec * share_working(K, "foreuse_elec")
  M.bras_elec_working = #by.bras_elec * share_working(K, "bras_elec")
  M.foreuses_elec = #by.foreuse_elec
  M.bras_elec = #by.bras_elec
  M.tapis_utiles = B.utiles
  M.assembleurs_produit = asm_p
  M.packs_fab = fab

  -- roule la fenêtre
  for _, cls in ipairs({ "four", "foreuse_elec", "foreuse_comb", "assembleur", "labo" }) do
    local ec = K.ent[cls]
    if ec then
      local alive = {}
      for _, e in ipairs(by[cls]) do alive[e.unit_number] = true end
      for un, r in pairs(ec) do
        if not alive[un] then ec[un] = nil
        else r.t0, r.ns, r.ws = tick, 0, 0 end
      end
      if cls == "four" or cls == "assembleur" then
        for _, e in ipairs(by[cls]) do
          local r = ec[e.unit_number]
          if r then r.pf0 = e.products_finished end
        end
      end
    end
  end
  for un, p in pairs(K.body) do if p.t < tick - 2 * F.SAMPLE then K.body[un] = nil end end
  K.hist, K.nsamp, K.kw_sum, K.kw_n = {}, 0, 0, 0
  K.bcls = { mine = 0, fabrique = 0, marche = 0, inerte = 0 }
  K.prod0, K.out0 = pin, pout
  K.idle0 = { n = row and row.n_sum or 0, idle = row and row.idle_sum or 0 }
  K.win0 = tick
  return M
end

---------------------------------------------------------------------------------------------------
-- Parité : joueur contre la MÉDIANE des factions vivantes (équipe morte ou faction morte exclue)
---------------------------------------------------------------------------------------------------

F.PARITY = { "plaques_min", "eq_stats_min", "fours_a50", "fours_auto", "fe_working", "bras_elec_working", "kw_moy",
  "tapis_utiles", "techs_fait", "assembleurs_produit", "packs_fab", "poteaux_gen" }

--- ms = { [clé] = M } ; rend les lignes (aussi journalisées) { indicateur, joueur, med, min, max, nviv, joueur_vivant }.
function F.parity(minute, ms, keys)
  local rows = {}
  local pm = ms.player
  for _, ind in ipairs(F.PARITY) do
    local vals = {}
    for _, k in ipairs(keys) do
      local m = ms[k]
      if k ~= "player" and m and m.morte == 0 and m[ind] then vals[#vals + 1] = m[ind] end
    end
    local med = F.median(vals)
    table.sort(vals)
    local r = { ind = ind, joueur = pm and pm[ind] or nil, med = med, min = vals[1], max = vals[#vals], nviv = #vals,
      joueur_vivant = (pm and pm.morte == 0) and 1 or 0 }
    rows[#rows + 1] = r
    log(F.TAG .. string.format("parite minute %d | %s | joueur=%s mediane=%s min=%s max=%s nviv=%d joueur_vivant=%d", minute,
      ind, r.joueur and f2(r.joueur) or "-", med and f2(med) or "-", vals[1] and f2(vals[1]) or "-",
      vals[#vals] and f2(vals[#vals]) or "-", #vals, r.joueur_vivant))
  end
  return rows
end

---------------------------------------------------------------------------------------------------
-- Enchaînement pour un scénario
---------------------------------------------------------------------------------------------------

local function row_of(rows, key)
  for _, r in ipairs(rows or {}) do if r.key == key then return r end end
  return nil
end

function F.sample_all(st, s, forces, tick, rows)
  for _, f in ipairs(forces) do F.sample(st, s, f.key, f.force, tick, row_of(rows, f.key)) end
end

function F.report_all(st, s, forces, minute, tick, rows)
  local ms, keys = {}, {}
  for _, f in ipairs(forces) do
    ms[f.key] = F.report(st, s, f.key, f.force, minute, tick, row_of(rows, f.key))
    keys[#keys + 1] = f.key
  end
  F.parity(minute, ms, keys)
  return ms
end

return F
