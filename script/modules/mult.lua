--[[
  Modules MULTIPLICATIFS en jeu (lot MOD-1, décision D-15 du Directeur Créatif, 24/10).

  Règle et calcul : shared/content/module_mult.lua (Lua pur, testé hors jeu). Ici : la vie de la BALISE CACHÉE
  (MOD-0, F192) qui porte, pour une machine, le complément entre le produit voulu et la somme que fait le moteur.

  - Machines suivies : assembleur, four, foreuse, laboratoire, silo, si elles ont des emplacements de modules. La
    balise n'existe QUE si le complément n'est pas nul (une machine sans module, ou à un seul module, n'en a pas).
  - Pose et retrait : construction (joueur, robot, script avec raise_built, résurrection), amélioration de niveau
    (crochet Levels.on_replaced), démontage, mort, destruction par script (raise_destroy) ; une balise orpheline au
    centre d'une machine posée est retirée à la pose (remplacement rapide du moteur, sans événement pour l'ancienne).
  - Recalcul : interface de la machine ouverte ou fermée, Ctrl+clic (transfert rapide), copier-coller de réglages,
    et BALAYAGE TOURNANT (voie de l'ordonnanceur) : les robots livrent des modules sans AUCUN événement (MOD-0, F194).
    Une signature des modules (comptes par nom, entiers exacts) évite tout recalcul quand rien n'a changé.
  - Coût borné : la voie traite chaque machine une fois par période ; la période double (300, 600, 1 200… ticks)
    dès qu'il y aurait plus de MAX_PER_TICK machines par tick.
  - Migration : on_configuration_changed recense toutes les machines des surfaces (parties d'avant MOD-1, modules
    déjà posés) et recalcule tout (les effets des modules ont pu changer), retire les balises orphelines.
  - Déterminisme : listes triées ou rendues par le moteur, aucun pairs dans une décision, entiers seulement, aucun
    temps mesuré ; rien dans global que des données (entités, nombres, tables).
  - Ce que voit le joueur : un panneau à droite de l'interface de la machine (gui.relative) donne les facteurs
    MULTIPLIÉS de vitesse, d'énergie et de productivité de ses modules (productivité multipliée depuis le lot MOD-3,
    décision D-17 ; au plafond, l'énergie garde l'écart, Q-M5 B).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local Scheduler = require("script.core.scheduler")
local Levels = require("script.levels.levels")
local MM = require("shared.content.module_mult")
-- Lot MOD-2 : recettes par lots au-delà de 60 fabrications par seconde (décision prise à chaque relecture d'une machine).
local Lots = require("script.modules.lots")

local Mult = {}

Mult.LANE = "modmult"
Mult.BASE_PERIOD = 300   -- ticks : une machine est relue au plus tard 5 s après une livraison par robots
Mult.MAX_PER_TICK = 40   -- au-delà, la période double (coût par tick borné)
Mult.PLAYER_PERIOD = 30  -- ticks : machine ouverte par un joueur relue (modules glissés à la main, interface ouverte)
--- Force de la balise cachée : celle de la machine (une balise d'une autre force n'est pas prouvée en moteur réel).
Mult.TYPES = { "assembling-machine", "furnace", "mining-drill", "lab", "rocket-silo" }
local TYPE_SET = {}
for _, t in ipairs(Mult.TYPES) do TYPE_SET[t] = true end

local RELATIVE = {
  ["assembling-machine"] = "assembling_machine_gui",
  furnace = "furnace_gui",
  ["mining-drill"] = "mining_drill_gui",
  lab = "lab_gui",
  ["rocket-silo"] = "rocket_silo_gui",
}

Storage.declare("modmult", function()
  return {
    rec = {},     -- [numéro de la machine] = { e, b, sig, c, t, empty }
    owner = {},   -- [numéro de la balise] = numéro de la machine
    stats = { tracked = 0, refreshed = 0, beacons_made = 0, beacons_removed = 0, orphans = 0, migrated = 0 },
  }
end)

local function S() return Storage.ns("modmult") end

---------------------------------------------------------------------------------------------------
-- Effets des modules en centièmes (cache LOCAL, refait depuis les prototypes : identique sur tous les clients)
---------------------------------------------------------------------------------------------------
local NAMES      -- noms des modules (hors modules cachés de complément), triés
local CENTS      -- [nom] = { speed = e, consumption = e, productivity = e }
local INDEX      -- [nom] = rang dans NAMES
local DIGITS = 10
local RADIX = 35 -- un compte par nom ≤ 34 emplacements : 35^10 < 2^53, signature exacte

local function build_cache()
  NAMES, CENTS, INDEX = {}, {}, {}
  local protos = game.get_filtered_item_prototypes({ { filter = "type", type = "module" } })
  for name in pairs(protos) do
    if name:sub(1, #MM.PREFIX) ~= MM.PREFIX then NAMES[#NAMES + 1] = name end
  end
  table.sort(NAMES)
  for i, name in ipairs(NAMES) do
    INDEX[name] = i
    local eff = protos[name].module_effects or {}
    local c = {}
    for _, effect in ipairs(MM.EFFECTS) do
      local v = eff[effect] and eff[effect].bonus
      if v then
        local x = MM.runtime_cents(v)
        if x ~= 0 then c[effect] = x end
      end
    end
    CENTS[name] = c
  end
end

--- Effets (centièmes) d'un module tels que le script les compte (pour les bancs).
function Mult.cents_of(name)
  if not NAMES then build_cache() end
  return CENTS[name]
end

---------------------------------------------------------------------------------------------------
-- Signature et recalcul
---------------------------------------------------------------------------------------------------
--- Signature des modules d'un inventaire : comptes par nom en base 35, DIGITS noms par nombre (entiers exacts).
--- Renvoie la table des nombres, le total d'objets et les contenus.
local function signature(inv)
  local contents = inv.get_contents()
  local sig = {}
  local total = 0
  for i = 1, #NAMES do
    local n = contents[NAMES[i]]
    if n then
      local j = math.floor((i - 1) / DIGITS) + 1
      sig[j] = (sig[j] or 0) + n * RADIX ^ ((i - 1) % DIGITS)
      total = total + n
    end
  end
  return sig, total, contents
end

local function same_sig(a, b)
  if not a or not b then return false end
  local n = math.max(#NAMES, 1)
  for j = 1, math.floor((n - 1) / DIGITS) + 1 do
    if (a[j] or 0) ~= (b[j] or 0) then return false end
  end
  return true
end

local function destroy_beacon(rec)
  local b = rec.b
  if b and b.valid then
    local st = S()
    if b.unit_number then st.owner[b.unit_number] = nil end
    b.destroy()
    st.stats.beacons_removed = st.stats.beacons_removed + 1
  end
  rec.b = nil
end

--- Écrit les modules cachés voulus dans la balise de la machine (créée au besoin, au centre de la machine).
local function apply(rec, unit, names)
  if #names == 0 then
    destroy_beacon(rec)
    return
  end
  local e = rec.e
  local b = rec.b
  if not (b and b.valid) then
    b = e.surface.create_entity({ name = MM.BEACON, position = e.position, force = e.force,
      create_build_effect_smoke = false })
    if not b then return end
    b.destructible = false
    rec.b = b
    local st = S()
    if b.unit_number then st.owner[b.unit_number] = unit end
    st.stats.beacons_made = st.stats.beacons_made + 1
  end
  local inv = b.get_module_inventory()
  inv.clear()
  for _, nm in ipairs(names) do inv.insert({ name = nm, count = 1 }) end
end

--- Recalcule la machine si ses modules ont changé (ou si force). Renvoie true si quelque chose a été réécrit.
local function check(rec, unit, force)
  local e = rec.e
  local inv = e.get_module_inventory()
  if not inv then return false end
  if not force and rec.empty and inv.get_item_count() == 0 then return false end
  local sig, total, contents = signature(inv)
  if not force and same_sig(sig, rec.sig) and (not rec.need or (rec.b and rec.b.valid)) then return false end
  -- Liste des modules (ordre des noms triés : le produit exact ne dépend pas de l'ordre, F : module_mult.lua).
  local mods = {}
  for i = 1, #NAMES do
    local name = NAMES[i]
    local n = contents[name]
    if n then
      local c = CENTS[name]
      for _ = 1, n do mods[#mods + 1] = c end
    end
  end
  local comp = MM.complements(mods)
  local names = MM.beacon_modules(comp)
  apply(rec, unit, names)
  rec.sig = sig
  rec.empty = total == 0
  rec.need = #names > 0
  rec.c = { speed = comp.speed.c, consumption = comp.consumption.c, productivity = comp.productivity.c }
  rec.t = { speed = comp.speed.t, consumption = comp.consumption.t, productivity = comp.productivity.t, n = total,
    gap = comp.consumption.gap or nil }
  S().stats.refreshed = S().stats.refreshed + 1
  return true
end

---------------------------------------------------------------------------------------------------
-- Suivi des machines
---------------------------------------------------------------------------------------------------
local function capable(e)
  if not (e and e.valid and TYPE_SET[e.type] and e.unit_number) then return false end
  local inv = e.get_module_inventory()
  return inv ~= nil and #inv > 0
end

--- Balises cachées au centre de la machine dont le propriétaire n'existe plus (remplacement rapide du moteur :
--- l'ancienne machine disparaît sans événement) : retirées.
local function clear_orphans(e, unit)
  local st = S()
  local p = e.position
  local found = e.surface.find_entities_filtered({ name = MM.BEACON,
    area = { { p.x - 0.25, p.y - 0.25 }, { p.x + 0.25, p.y + 0.25 } } })
  for _, b in ipairs(found) do
    local owner = b.unit_number and st.owner[b.unit_number]
    local orec = owner and st.rec[owner]
    if owner ~= unit and not (orec and orec.e and orec.e.valid) then
      if owner then st.owner[b.unit_number] = nil end
      if orec then orec.b = nil end
      b.destroy()
      st.stats.orphans = st.stats.orphans + 1
    end
  end
end

function Mult.untrack(unit)
  if not unit then return end
  local st = S()
  local rec = st.rec[unit]
  if rec then
    destroy_beacon(rec)
    st.rec[unit] = nil
    st.stats.tracked = st.stats.tracked - 1
  end
  Scheduler.remove(Mult.LANE, unit)
end

--- Suit une machine (si elle a des emplacements de modules) et la calcule tout de suite.
function Mult.track(e)
  if not capable(e) then return nil end
  if not NAMES then build_cache() end
  local st = S()
  local unit = e.unit_number
  local rec = st.rec[unit]
  if not rec then
    rec = { e = e }
    st.rec[unit] = rec
    st.stats.tracked = st.stats.tracked + 1
  end
  rec.e = e
  clear_orphans(e, unit)
  Scheduler.add(Mult.LANE, unit)
  check(rec, unit, true)
  Lots.consider(e)
  return rec
end

--- Recalcule une machine suivie (forcé). Renvoie l'enregistrement, ou nil.
function Mult.refresh(e, force)
  if not (e and e.valid and e.unit_number) then return nil end
  local rec = S().rec[e.unit_number]
  if not rec then return Mult.track(e) end
  if not NAMES then build_cache() end
  check(rec, e.unit_number, force)
  Lots.consider(e)
  return rec
end

local function period()
  local n = Scheduler.count(Mult.LANE)
  local p = Mult.BASE_PERIOD
  while n > p * Mult.MAX_PER_TICK do p = p * 2 end
  return p
end

Scheduler.define_lane(Mult.LANE, period, function(unit)
  local st = S()
  local rec = st.rec[unit]
  if not rec then
    Scheduler.remove(Mult.LANE, unit)
    return
  end
  if not (rec.e and rec.e.valid) then
    Mult.untrack(unit)
    return
  end
  if not NAMES then build_cache() end
  check(rec, unit, false)
  Lots.consider(rec.e)
end)

---------------------------------------------------------------------------------------------------
-- Panneau du joueur (interface de la machine)
---------------------------------------------------------------------------------------------------
local function line_params(t)
  local whole = math.floor(t / 100)
  return tostring(whole), string.format("%02d", t - whole * 100), MM.bonus_text(t)
end

local function panel_for(player, etype)
  local rel = RELATIVE[etype]
  if not rel then return nil end
  local name = "fo_mm_panel_" .. rel
  local root = player.gui.relative
  local f = root[name]
  if not f then
    f = root.add({ type = "frame", name = name, direction = "vertical", caption = { "fo-mm.panel-title" },
      anchor = { gui = defines.relative_gui_type[rel], position = defines.relative_gui_position.right } })
    f.add({ type = "label", name = "speed" })
    f.add({ type = "label", name = "energy" })
    f.add({ type = "label", name = "prod" })
    f.add({ type = "label", name = "cap" })
    local note = f.add({ type = "label", name = "note", caption = { "fo-mm.panel-note" } })
    note.style.single_line = false
    note.style.maximal_width = 220
  end
  -- Lot MOD-2 : ligne des recettes par lots (ajoutée aussi à un panneau créé avant MOD-2).
  if not f.lots then
    local l = f.add({ type = "label", name = "lots", tooltip = { "fo-lots.panel-lot-tooltip" } })
    l.style.single_line = false
    l.style.maximal_width = 220
  end
  return f
end

local function update_panel(player, e)
  if not (player and player.valid and e and e.valid) then return end
  local f = panel_for(player, e.type)
  if not f then return end
  -- Le panneau est ancré au TYPE d'interface (toutes les machines de ce type) : caché pour une machine sans
  -- emplacement de module (four en acier…), sinon il montrerait les chiffres de la machine ouverte avant.
  if not capable(e) then
    f.visible = false
    return
  end
  f.visible = true
  local rec = S().rec[e.unit_number]
  local t = rec and rec.t or { speed = 100, consumption = 100, productivity = 100, n = 0 }
  local a, b, c = line_params(t.speed)
  f.speed.caption = { "fo-mm.panel-speed", a, b, c }
  a, b, c = line_params(t.consumption)
  f.energy.caption = { "fo-mm.panel-energy", a, b, c }
  local pb = (t.productivity or 100) - 100
  f.prod.caption = { MM.PRODUCTIVITY_MULTIPLIES and "fo-mm.panel-prod-mult" or "fo-mm.panel-prod-add",
    (pb >= 0 and "+" or "") .. pb }
  -- Lot MOD-3 (D-17) : productivité multipliée, plafond compris ; au plafond, l'énergie garde l'écart (Q-M5 B).
  local capped = t.speed >= MM.MAX_T or t.consumption >= MM.MAX_T or (t.productivity or 100) >= MM.MAX_T
  f.cap.caption = capped and { t.gap and "fo-mm.panel-cap-gap" or "fo-mm.panel-cap" } or ""
  f.cap.visible = capped
  f.speed.tooltip = { "fo-mm.panel-tooltip", tostring(t.n or 0) }
  local lot = Lots.panel_line(e)
  f.lots.caption = lot or ""
  f.lots.visible = lot ~= nil
end
Mult.update_panel = update_panel

---------------------------------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------------------------------
local function on_built(e)
  local ent = e.created_entity or e.entity
  if ent and ent.valid and TYPE_SET[ent.type] then Mult.track(ent) end
end
Events.on(defines.events.on_built_entity, on_built)
Events.on(defines.events.on_robot_built_entity, on_built)
Events.on(defines.events.script_raised_built, on_built)
Events.on(defines.events.script_raised_revive, on_built)

local function on_removed(e)
  local ent = e.entity
  if ent and ent.valid and TYPE_SET[ent.type] and ent.unit_number then Mult.untrack(ent.unit_number) end
end
Events.on(defines.events.on_player_mined_entity, on_removed)
Events.on(defines.events.on_robot_mined_entity, on_removed)
Events.on(defines.events.on_entity_died, on_removed)
Events.on(defines.events.script_raised_destroy, on_removed)

-- Agrandissement par script : modules versés AVANT les ingrédients (Levels.transfer) ; la balise de complément est
-- posée aussitôt, pour que la machine ait déjà sa vitesse multipliée quand son entrée est remplie.
table.insert(Levels.on_modules_moved, function(new)
  if new and new.valid and TYPE_SET[new.type] then Mult.track(new) end
end)

-- Amélioration de niveau (remplacement par le moteur ou par script) : la nouvelle machine reprend les modules.
table.insert(Levels.on_replaced, function(old_unit, new)
  Mult.untrack(old_unit)
  if new and new.valid and TYPE_SET[new.type] then Mult.track(new) end
end)

local function on_gui(e)
  local ent = e.entity
  if not (ent and ent.valid and TYPE_SET[ent.type]) then return end
  Mult.refresh(ent, false)
  local player = game.get_player(e.player_index)
  update_panel(player, ent)
end
Events.on(defines.events.on_gui_opened, on_gui)
Events.on(defines.events.on_gui_closed, on_gui)

Events.on(defines.events.on_player_fast_transferred, function(e)
  local ent = e.entity
  if ent and ent.valid and TYPE_SET[ent.type] then Mult.refresh(ent, false) end
end)

Events.on(defines.events.on_entity_settings_pasted, function(e)
  local ent = e.destination
  if ent and ent.valid and TYPE_SET[ent.type] then Mult.refresh(ent, false) end
end)

-- Machine ouverte par un joueur : modules glissés à la main pendant que l'interface est ouverte.
Events.on_nth_tick(Mult.PLAYER_PERIOD, function()
  for _, player in ipairs(game.connected_players) do
    local ent = player.opened
    if ent and player.opened_gui_type == defines.gui_type.entity and ent.valid and TYPE_SET[ent.type] then
      local rec = Mult.refresh(ent, false)
      if rec then update_panel(player, ent) end
    end
  end
end)

---------------------------------------------------------------------------------------------------
-- Migration : parties existantes (modules déjà posés), effets des modules changés
---------------------------------------------------------------------------------------------------
function Mult.migrate()
  NAMES = nil
  build_cache()
  local st = S()
  local surfaces, seen = {}, {}
  for _, s in pairs(game.surfaces) do
    if not seen[s.index] then
      seen[s.index] = true
      surfaces[#surfaces + 1] = s
    end
  end
  table.sort(surfaces, function(a, b) return a.index < b.index end)
  local tracked, beacons = 0, 0
  for _, s in ipairs(surfaces) do
    for _, e in ipairs(s.find_entities_filtered({ type = Mult.TYPES })) do
      local rec = Mult.track(e)
      if rec then
        tracked = tracked + 1
        if rec.need then beacons = beacons + 1 end
      end
    end
    -- Balises sans machine suivie (ancienne version, machine disparue) : retirées.
    for _, b in ipairs(s.find_entities_filtered({ name = MM.BEACON })) do
      local owner = b.unit_number and st.owner[b.unit_number]
      local orec = owner and st.rec[owner]
      if not (orec and orec.b == b and orec.e and orec.e.valid) then
        if owner then st.owner[b.unit_number] = nil end
        b.destroy()
        st.stats.orphans = st.stats.orphans + 1
      end
    end
  end
  st.stats.migrated = st.stats.migrated + 1
  log("[FO-MODMULT] mise à jour : " .. tracked .. " machine(s) à modules suivie(s), " .. beacons
    .. " balise(s) de complément, " .. st.stats.orphans .. " orpheline(s) retirée(s) en tout")
  return tracked, beacons
end

Events.on_configuration_changed(function()
  Mult.migrate()
end)

Events.on_load(function()
  NAMES = nil
end)

---------------------------------------------------------------------------------------------------
-- Interface pour les bancs (lecture et recalcul ; aucune décision de jeu)
---------------------------------------------------------------------------------------------------
remote.add_interface("fo-modules", {
  --- État d'une machine : { tracked, beacon, c = {…}, t = {…}, modules } ou nil.
  state = function(e)
    if not (e and e.valid and e.unit_number) then return nil end
    local rec = S().rec[e.unit_number]
    if not rec then return { tracked = false } end
    local names = {}
    if rec.b and rec.b.valid then
      local inv = rec.b.get_module_inventory()
      for i = 1, #inv do
        if inv[i].valid_for_read then names[#names + 1] = inv[i].name end
      end
    end
    return { tracked = true, beacon = rec.b and rec.b.valid and rec.b or nil, c = rec.c, t = rec.t, modules = names }
  end,
  refresh = function(e, force) local rec = Mult.refresh(e, force ~= false) return rec ~= nil end,
  track = function(e) return Mult.track(e) ~= nil end,
  stats = function()
    local st = S()
    local out = {}
    for k, v in pairs(st.stats) do out[k] = v end
    out.lane = Scheduler.count(Mult.LANE)
    out.period = period()
    return out
  end,
  --- Relit toutes les machines suivies (coût d'un balayage complet, banc).
  sweep_all = function()
    if not NAMES then build_cache() end
    local st = S()
    local units = {}
    for unit in pairs(st.rec) do units[#units + 1] = unit end
    table.sort(units)
    local changed = 0
    for _, unit in ipairs(units) do
      local rec = st.rec[unit]
      if rec.e and rec.e.valid and check(rec, unit, false) then changed = changed + 1 end
    end
    return #units, changed
  end,
  cents = function(name) return Mult.cents_of(name) end,
  migrate = function() return Mult.migrate() end,
})

return Mult
