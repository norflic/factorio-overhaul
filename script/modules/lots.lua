--[[
  RECETTES PAR LOTS en jeu (lot MOD-2, décision D-15 du Directeur Créatif, Q-M2 a).

  Règle (Lua pur) : shared/content/recipe_lots.lua. Prototypes : prototypes/lots.lua (lots × 10 et × 100, cachés).
  Ici : la BASCULE d'une machine d'assemblage entre sa recette et ses lots, selon sa vitesse.

  - Décision (Lots.consider) : appelée par le suivi des modules (script/modules/mult.lua) à chaque passage du balayage
    tournant (voie « modmult »), à la pose, à l'amélioration de niveau, à l'interface ouverte ou fermée, au
    copier-coller ; vitesse relue (crafting_speed : modules, balise de complément et balises du joueur, mise à jour
    dans le même tick, E151) ; lot choisi en ENTIERS avec hystérésis (montée au-delà de 60 /s, descente sous 45 /s).
  - Bascule (Lots.switch) : set_recipe. Moteur réel (E151) : le moteur GARDE l'entrée et la sortie quand la nouvelle
    recette a les mêmes objets, ne rend que les ingrédients de la fabrication en cours ; ces objets sont reversés
    (entrée, sinon sortie), le reste attend dans une RÉSERVE de la machine ; le fluide de la fabrication en cours est
    détruit par le moteur : il est reversé dans sa boîte (capacité = 2 × la recette, E151), le fluide qu'une boîte
    plus petite ne garde pas va aussi en réserve ; la progression de productivité est reportée (lots entiers rendus en
    produits, reste en fraction).
  - Réserve : voie « modlots » (30 ticks) qui reverse dans la machine ce qui y entre ; machine démontée : la réserve
    va dans l'inventaire du démonteur (buffer de l'événement) ; détruite : renversée au pied ; agrandie : suit la
    nouvelle machine.
  - Recettes activées : un lot est actif pour une force quand sa recette de base l'est (aucune technologie touchée ;
    synchronisation aux recherches, à la mise à jour du mod, à la création d'une force) : les plans et le
    copier-coller d'une machine en lot fonctionnent.
  - Déterminisme : listes triées, entiers dans la décision, aucun temps mesuré, rien dans global que des données.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local Scheduler = require("script.core.scheduler")
local Levels = require("script.levels.levels")
local R = require("shared.content.recipe_lots")

local Lots = {}

Lots.LANE = "modlots"
Lots.PERIOD = 10          -- ticks : réserve reversée au plus tard 1/6 s après qu'il y a de la place (peu de machines)

Storage.declare("modlots", function()
  return {
    pend = {},            -- [numéro de la machine] = { e = entité, items = { {name, count} }, fluids = { {name, amount, temperature} } }
    stats = { up = 0, down = 0, refunded = 0, pending_items = 0, pending_fluid = 0, given = 0, spilled = 0,
      fluid_refund = 0, fluid_lost = 0, bonus_items = 0, synced = 0 },
  }
end)

local function S() return Storage.ns("modlots") end

---------------------------------------------------------------------------------------------------
-- Cache LOCAL des lots (refait depuis les prototypes : identique sur tous les clients)
---------------------------------------------------------------------------------------------------
local INFO      -- [nom de recette] = { base = nom, k = lot } ou false
local BASES     -- [base] = { sizes = {1, 10, 100}, names = { [k] = nom }, energy_ms = durée de base }
local BASE_LIST -- bases triées

local function build()
  INFO, BASES, BASE_LIST = {}, {}, {}
  local protos = game.recipe_prototypes
  local names = {}
  for name in pairs(protos) do
    if R.is_lot(name) then names[#names + 1] = name end
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local base, k = R.parse(name)
    if protos[base] then
      local b = BASES[base]
      if not b then
        b = { sizes = { 1 }, names = { [1] = base }, energy_ms = math.max(1, R.milli(protos[base].energy)) }
        BASES[base] = b
        BASE_LIST[#BASE_LIST + 1] = base
      end
      b.sizes[#b.sizes + 1] = k
      b.names[k] = name
      INFO[name] = { base = base, k = k }
    end
  end
  table.sort(BASE_LIST)
  for _, base in ipairs(BASE_LIST) do
    table.sort(BASES[base].sizes)
    INFO[base] = { base = base, k = 1 }
  end
end

local function info_of(name)
  if not INFO then build() end
  local i = INFO[name]
  if i == nil then return nil end
  return i
end

--- Lot d'une recette (bancs) : base, k ; nil si la recette n'a pas de lots.
function Lots.info(name)
  local i = name and info_of(name)
  if not i then return nil end
  return i.base, i.k
end

---------------------------------------------------------------------------------------------------
-- Activation des lots pour une force
---------------------------------------------------------------------------------------------------
local function sync_base(force, base)
  local b = BASES[base]
  local br = force.recipes[base]
  if not (b and br) then return 0 end
  local en = br.enabled
  local n = 0
  for _, k in ipairs(b.sizes) do
    if k > 1 then
      local r = force.recipes[b.names[k]]
      if r and r.enabled ~= en then
        r.enabled = en
        n = n + 1
      end
    end
  end
  return n
end

function Lots.sync_force(force)
  if not (force and force.valid) then return 0 end
  if not INFO then build() end
  local n = 0
  for _, base in ipairs(BASE_LIST) do n = n + sync_base(force, base) end
  S().stats.synced = S().stats.synced + n
  return n
end

local function sync_all()
  local forces = {}
  for _, f in pairs(game.forces) do forces[#forces + 1] = f end
  table.sort(forces, function(a, b) return a.index < b.index end)
  local n = 0
  for _, f in ipairs(forces) do n = n + Lots.sync_force(f) end
  return n
end

local function on_research(e)
  local tech = e.research
  if not (tech and tech.valid) then return end
  if not INFO then build() end
  for _, eff in ipairs(tech.effects or {}) do
    if eff.type == "unlock-recipe" and BASES[eff.recipe] then sync_base(tech.force, eff.recipe) end
  end
end
Events.on(defines.events.on_research_finished, on_research)
Events.on(defines.events.on_research_reversed, on_research)
Events.on(defines.events.on_technology_effects_reset, function(e) Lots.sync_force(e.force) end)
Events.on(defines.events.on_force_reset, function(e) Lots.sync_force(e.force) end)
Events.on(defines.events.on_force_created, function(e) Lots.sync_force(e.force) end)

---------------------------------------------------------------------------------------------------
-- Réserve d'une machine
---------------------------------------------------------------------------------------------------
local function add_item(list, name, count)
  if count <= 0 then return end
  for _, it in ipairs(list) do
    if it.name == name then
      it.count = it.count + count
      return
    end
  end
  list[#list + 1] = { name = name, count = count }
  table.sort(list, function(a, b) return a.name < b.name end)
end

local function add_fluid(list, name, amount, temperature)
  if amount <= 0 then return end
  for _, f in ipairs(list) do
    if f.name == name then
      -- Température : moyenne pondérée (même règle qu'un mélange du moteur).
      local tot = f.amount + amount
      if temperature and f.temperature then f.temperature = (f.temperature * f.amount + temperature * amount) / tot end
      f.amount = tot
      return
    end
  end
  list[#list + 1] = { name = name, amount = amount, temperature = temperature }
  table.sort(list, function(a, b) return a.name < b.name end)
end

local function reserve(e)
  local st = S()
  local u = e.unit_number
  local p = st.pend[u]
  if not p then
    p = { e = e, items = {}, fluids = {} }
    st.pend[u] = p
    Scheduler.add(Lots.LANE, u)
  end
  p.e = e
  return p
end

--- Ingrédient / produit de la recette courante ?
local function role(recipe, name, typ)
  if not recipe then return nil end
  for _, i in ipairs(recipe.ingredients) do if i.name == name and (i.type or "item") == typ then return "in" end end
  for _, p in ipairs(recipe.products) do if p.name == name and (p.type or "item") == typ then return "out" end end
  return nil
end

--- Verse des objets dans la machine (entrée si ingrédient, sortie si produit). Renvoie le nombre versé.
local function put_item(e, recipe, name, count)
  local r = role(recipe, name, "item")
  local put = 0
  if r == "in" then
    put = e.get_inventory(defines.inventory.assembling_machine_input).insert({ name = name, count = count })
  end
  if put < count and r then
    put = put + e.get_output_inventory().insert({ name = name, count = count - put })
  end
  return put
end

--- Ajoute du fluide dans une boîte de la machine qui tient ce fluide (contenu ou filtre). Renvoie la quantité versée.
local function put_fluid(e, name, amount, temperature)
  local fb = e.fluidbox
  local put = 0
  for i = 1, #fb do
    if amount - put <= 1e-9 then break end
    local cur = fb[i]
    local filter = fb.get_filter(i)
    local ok = (cur and cur.name == name) or (not cur and filter and filter.name == name)
    if ok then
      local cap = fb.get_capacity(i)
      local have = cur and cur.amount or 0
      local room = cap - have
      if room > 0 then
        local add = math.min(room, amount - put)
        local temp = temperature
        if cur and cur.temperature and temperature then temp = (cur.temperature * have + temperature * add) / (have + add) end
        fb[i] = { name = name, amount = have + add, temperature = temp or (cur and cur.temperature) }
        put = put + add
      end
    end
  end
  return put
end

--- Reverse la réserve d'une machine. Renvoie true si elle est vide.
local function drain(p)
  local e = p.e
  if not (e and e.valid) then return true end
  local recipe = e.get_recipe()
  local keep = {}
  for _, it in ipairs(p.items) do
    local put = put_item(e, recipe, it.name, it.count)
    if put < it.count then keep[#keep + 1] = { name = it.name, count = it.count - put } end
  end
  p.items = keep
  local keepf = {}
  for _, f in ipairs(p.fluids) do
    local put = put_fluid(e, f.name, f.amount, f.temperature)
    if f.amount - put > 1e-6 then keepf[#keepf + 1] = { name = f.name, amount = f.amount - put, temperature = f.temperature } end
  end
  p.fluids = keepf
  return #p.items == 0 and #p.fluids == 0
end

Scheduler.define_lane(Lots.LANE, Lots.PERIOD, function(unit)
  local st = S()
  local p = st.pend[unit]
  if not p then
    Scheduler.remove(Lots.LANE, unit)
    return
  end
  if drain(p) then
    st.pend[unit] = nil
    Scheduler.remove(Lots.LANE, unit)
  end
end)

--- Réserve d'une machine qui disparaît : rendue au démonteur (buffer) ou renversée au pied.
local function release(unit, buffer, entity)
  local st = S()
  local p = st.pend[unit]
  if not p then return end
  st.pend[unit] = nil
  Scheduler.remove(Lots.LANE, unit)
  local e = entity or p.e
  for _, it in ipairs(p.items) do
    local put = 0
    if buffer and buffer.valid then put = buffer.insert({ name = it.name, count = it.count }) end
    st.stats.given = st.stats.given + put
    if put < it.count and e and e.valid then
      e.surface.spill_item_stack(e.position, { name = it.name, count = it.count - put }, true, e.force, false)
      st.stats.spilled = st.stats.spilled + it.count - put
    end
  end
  for _, f in ipairs(p.fluids) do st.stats.fluid_lost = st.stats.fluid_lost + f.amount end
end

---------------------------------------------------------------------------------------------------
-- Bascule
---------------------------------------------------------------------------------------------------
local function fluid_totals(e)
  local t = {}
  local fb = e.fluidbox
  for i = 1, #fb do
    local f = fb[i]
    if f then
      local cur = t[f.name]
      if cur then
        cur.amount = cur.amount + f.amount
      else
        t[f.name] = { amount = f.amount, temperature = f.temperature }
      end
    end
  end
  return t
end

--- Les objets rendus par set_recipe sont-ils EXACTEMENT les ingrédients (objets) d'une fabrication de `old` ?
--- (moteur réel, E151 : 2 plaques pour l'engrenage, 20 au lot 10, 5 briques + 1 minerai pour le béton). Et ses
--- produits sont-ils sûrs (quantité fixe, sans probabilité) ?
local function one_craft(ret, old)
  if not old then return false end
  local want, n = {}, 0
  for _, i in ipairs(old.ingredients) do
    if i.type ~= "fluid" then
      want[i.name] = (want[i.name] or 0) + i.amount
      n = n + 1
    end
  end
  local m = 0
  for name, count in pairs(ret) do
    if want[name] ~= count then return false end
    m = m + 1
  end
  if m ~= n then return false end
  for _, pr in ipairs(old.products) do
    if not pr.amount or (pr.probability and pr.probability ~= 1) then return false end
  end
  return true
end

local function give_item(e, recipe, name, count, st)
  local put = put_item(e, recipe, name, count)
  if put < count then
    local p = reserve(e)
    add_item(p.items, name, count - put)
    st.stats.pending_items = st.stats.pending_items + count - put
  end
end

local function give_fluid(e, name, amount, temperature, st)
  local put = put_fluid(e, name, amount, temperature)
  if amount - put > 1e-6 then
    local p = reserve(e)
    add_fluid(p.fluids, name, amount - put, temperature)
    st.stats.pending_fluid = st.stats.pending_fluid + amount - put
  end
end

--- Passe la machine `e` de sa recette (lot k_old) au lot k_new (même base). Renvoie true si elle a basculé.
---
--- Moteur réel (E151) : set_recipe garde l'entrée et la sortie (mêmes objets) et ne rend que les ingrédients (objets)
--- de la fabrication EN COURS ; ses fluides sont détruits ; une boîte plus petite (lot inférieur) est tronquée. Une
--- entrée déjà à sa limite refuse tout ajout par script (écriture directe du compte comprise, E151 passe 4) : rendre les
--- ingrédients pourrait les laisser en attente tant que les bras la tiennent pleine. La fabrication en cours est donc
--- ACHEVÉE par le script : ses produits (lot k_old) vont dans la sortie, sa part de productivité dans la barre ; les
--- ingrédients rendus sont ceux qu'elle avait déjà pris. Avance accordée : au plus la fin d'UNE fabrication du lot
--- k_old. Cas non reconnu (objets rendus différents d'une fabrication, produit aléatoire) : ingrédients reversés.
--- Ce qui n'entre pas (sortie pleine, boîte tronquée) attend dans la réserve de la machine.
function Lots.switch(e, base, k_old, k_new)
  local b = BASES[base]
  local to = b and b.names[k_new]
  if not to then return false end
  local st = S()
  local old = e.get_recipe()
  local fr = e.force.recipes[to]
  if fr and not fr.enabled and e.force.recipes[base] and e.force.recipes[base].enabled then fr.enabled = true end
  local bonus = e.bonus_progress or 0
  local pbonus = e.productivity_bonus or 0
  local fluids_before = fluid_totals(e)
  local ret = e.set_recipe(to) or {}
  local recipe = e.get_recipe()
  local units = bonus * k_old / k_new
  if next(ret) ~= nil then
    if one_craft(ret, old) then
      -- Fabrication en cours achevée : produits du lot k_old, part de productivité.
      st.stats.finished = (st.stats.finished or 0) + 1
      for _, pr in ipairs(old.products) do
        if (pr.type or "item") == "fluid" then
          give_fluid(e, pr.name, pr.amount, pr.temperature, st)
        else
          give_item(e, recipe, pr.name, pr.amount, st)
          st.stats.finished_items = (st.stats.finished_items or 0) + pr.amount
        end
      end
      units = (bonus + pbonus) * k_old / k_new
    else
      -- Cas non reconnu : ingrédients rendus reversés (entrée, sinon réserve) ; fluides de la fabrication reversés.
      local names = {}
      for name in pairs(ret) do names[#names + 1] = name end
      table.sort(names)
      for _, name in ipairs(names) do
        st.stats.refunded = st.stats.refunded + ret[name]
        give_item(e, recipe, name, ret[name], st)
      end
      for _, i in ipairs(old and old.ingredients or {}) do
        if i.type == "fluid" then
          local tb = fluids_before[i.name]
          st.stats.fluid_refund = st.stats.fluid_refund + i.amount
          give_fluid(e, i.name, i.amount, tb and tb.temperature, st)
        end
      end
    end
  end
  -- Fluides que la boîte n'a pas gardés (boîte plus petite au lot inférieur).
  local after = fluid_totals(e)
  local fnames = {}
  for name in pairs(fluids_before) do fnames[#fnames + 1] = name end
  table.sort(fnames)
  for _, name in ipairs(fnames) do
    local was = fluids_before[name]
    local now = after[name] and after[name].amount or 0
    if was.amount - now > 1e-6 then give_fluid(e, name, was.amount - now, was.temperature, st) end
  end
  -- Productivité : barre exprimée en fabrications du lot k_new ; fabrications entières rendues en produits.
  if units > 0 then
    local whole = math.floor(units)
    if whole > 0 and recipe then
      for _, pr in ipairs(recipe.products) do
        if pr.amount and (pr.type or "item") == "item" then
          st.stats.bonus_items = st.stats.bonus_items + pr.amount * whole
          give_item(e, recipe, pr.name, pr.amount * whole, st)
        elseif pr.amount then
          give_fluid(e, pr.name, pr.amount * whole, pr.temperature, st)
        end
      end
    end
    e.bonus_progress = units - whole
  end
  if k_new > k_old then st.stats.up = st.stats.up + 1 else st.stats.down = st.stats.down + 1 end
  return true
end

--- Lot voulu pour la machine `e` (machine d'assemblage) ; bascule si besoin. Renvoie le lot courant (après bascule)
--- et la base, ou nil si la recette n'a pas de lots.
function Lots.consider(e)
  if not (e and e.valid and e.type == "assembling-machine") then return nil end
  local recipe = e.get_recipe()
  if not recipe then return nil end
  local i = info_of(recipe.name)
  if not i then return nil end
  local b = BASES[i.base]
  local speed_m = R.milli(e.crafting_speed)
  local want = R.choose(i.k, speed_m, b.energy_ms, b.sizes)
  if want ~= i.k then
    Lots.switch(e, i.base, i.k, want)
    return want, i.base
  end
  return i.k, i.base
end

--- Texte du panneau « Modules (multipliés) » : { clé, paramètres… } ou nil (recette sans lots).
function Lots.panel_line(e)
  if not (e and e.valid and e.type == "assembling-machine") then return nil end
  local recipe = e.get_recipe()
  local i = recipe and info_of(recipe.name)
  if not i then return nil end
  local b = BASES[i.base]
  local speed_m = R.milli(e.crafting_speed)
  local rate = R.rate_cents(i.k, speed_m, b.energy_ms)       -- fabrications (lots) par seconde voulues, centièmes
  local whole = math.floor(rate / 100)
  local frac = string.format("%02d", rate - whole * 100)
  local crafts = math.floor(rate * i.k / 100 + 0.5)          -- fabrications de la recette de base par seconde
  if rate > R.CAP * 100 and i.k == b.sizes[#b.sizes] then
    return { "fo-lots.panel-lot-cap", tostring(i.k), tostring(crafts) }
  end
  if i.k == 1 then return { "fo-lots.panel-lot-1", tostring(whole), frac } end
  return { "fo-lots.panel-lot", tostring(i.k), tostring(whole), frac, tostring(crafts) }
end

---------------------------------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------------------------------
-- Machine SANS emplacement de modules (non suivie par mult.lua) posée ou collée avec une recette en lot (plan,
-- copier-coller) : son lot est choisi une fois.
local function untracked(e)
  if not (e and e.valid and e.type == "assembling-machine") then return false end
  local inv = e.get_module_inventory()
  return not (inv and #inv > 0)
end

local function on_built(ev)
  local e = ev.created_entity or ev.entity
  if untracked(e) then Lots.consider(e) end
end
Events.on(defines.events.on_built_entity, on_built)
Events.on(defines.events.on_robot_built_entity, on_built)
Events.on(defines.events.script_raised_built, on_built)
Events.on(defines.events.script_raised_revive, on_built)
Events.on(defines.events.on_entity_settings_pasted, function(ev)
  if untracked(ev.destination) then Lots.consider(ev.destination) end
end)

local function on_mined(ev)
  local e = ev.entity
  if e and e.valid and e.unit_number then release(e.unit_number, ev.buffer, e) end
end
Events.on(defines.events.on_player_mined_entity, on_mined)
Events.on(defines.events.on_robot_mined_entity, on_mined)
local function on_gone(ev)
  local e = ev.entity
  if e and e.valid and e.unit_number then release(e.unit_number, nil, e) end
end
Events.on(defines.events.on_entity_died, on_gone)
Events.on(defines.events.script_raised_destroy, on_gone)

-- Amélioration de niveau : la réserve suit la nouvelle machine.
table.insert(Levels.on_replaced, function(old_unit, new)
  local st = S()
  local p = old_unit and st.pend[old_unit]
  if not p then return end
  st.pend[old_unit] = nil
  Scheduler.remove(Lots.LANE, old_unit)
  if new and new.valid and new.unit_number then
    local q = reserve(new)
    for _, it in ipairs(p.items) do add_item(q.items, it.name, it.count) end
    for _, f in ipairs(p.fluids) do add_fluid(q.fluids, f.name, f.amount, f.temperature) end
  end
end)

Events.on_init(function()
  build()
  sync_all()
end)

Events.on_configuration_changed(function()
  build()
  local n = sync_all()
  log("[FO-LOTS] mise à jour : " .. #BASE_LIST .. " recette(s) à lots, " .. n .. " lot(s) activé(s) ou désactivé(s)")
end)

Events.on_load(function()
  INFO, BASES, BASE_LIST = nil, nil, nil
end)

---------------------------------------------------------------------------------------------------
-- Interface pour les bancs (lecture, et bascule demandée ; aucune décision de jeu)
---------------------------------------------------------------------------------------------------
remote.add_interface("fo-lots", {
  --- Lot d'une machine : { base, k, pending = { items, fluids } } ou nil.
  state = function(e)
    if not (e and e.valid) then return nil end
    local recipe = e.get_recipe and e.get_recipe()
    local base, k = Lots.info(recipe and recipe.name)
    local p = e.unit_number and S().pend[e.unit_number]
    return { base = base, k = k, recipe = recipe and recipe.name, speed = e.crafting_speed,
      pending = p and { items = p.items, fluids = p.fluids } or nil }
  end,
  consider = function(e) return Lots.consider(e) end,
  --- Bascule imposée au lot k (mesure du coût d'une bascule seule) ; la décision suivante peut la défaire.
  switch_to = function(e, k)
    if not (e and e.valid and e.type == "assembling-machine") then return false end
    local recipe = e.get_recipe()
    local i = recipe and info_of(recipe.name)
    if not i or i.k == k then return false end
    return Lots.switch(e, i.base, i.k, k)
  end,
  stats = function()
    local out = {}
    for k, v in pairs(S().stats) do out[k] = v end
    out.lane = Scheduler.count(Lots.LANE)
    return out
  end,
  sync = function() return sync_all() end,
  bases = function()
    if not INFO then build() end
    return #BASE_LIST
  end,
})

return Lots
