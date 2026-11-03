-- Banc hors jeu du lot CALCUL-V2 (30/10) : le SCRIPT du centre modulaire (script/compute/compute.lua) sur un moteur
-- simulé minimal (centres, inventaire de modules, compagnons) : migration d'une sauvegarde 0.6.27 (centres v1 sur une
-- recette à baie usée), fenêtre de mesure contre la règle pure, puissance écrite au compagnon, part de recherche.
-- Le moteur réel est prouvé par les scénarios calcul-modulaire et calcul-v2-migration (double source).
-- Lancement : lua5.2 tests/compute_v2_script_test.lua

package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local function check(cond, label, detail)
  if cond then pass = pass + 1 else
    fail = fail + 1
    print("ECHEC : " .. label .. (detail and (" (" .. tostring(detail) .. ")") or ""))
  end
end
local function section(t) print("== " .. t) end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-9) end

---------------------------------------------------------------------------------------------------
-- Moteur simulé minimal
---------------------------------------------------------------------------------------------------
defines = setmetatable({}, { __index = function(t, k)
  local sub = setmetatable({}, { __index = function(_, k2) return k .. "." .. k2 end })
  rawset(t, k, sub)
  return sub
end })
remote = { add_interface = function() end, interfaces = {} }
local LOGS = {}
log = function(s) LOGS[#LOGS + 1] = s end

local Cr = require("shared.content.compute_rack")

local next_unit = 100
local world = { entities = {}, spilled = {} }

local function inventory(size)
  local inv = { items = {}, size = size }
  function inv.insert(st)
    local used = 0
    for _, n in pairs(inv.items) do used = used + n end
    local put = math.min(st.count, size - used)
    if put > 0 then inv.items[st.name] = (inv.items[st.name] or 0) + put end
    return put
  end
  function inv.get_contents() local c = {} for k, v in pairs(inv.items) do c[k] = v end return c end
  return inv
end

local surface = { index = 1 }
local force = { name = "player", valid = true, laboratory_speed_modifier = 0 }

local function center(name, recipe, returned, water)
  next_unit = next_unit + 1
  local e = { name = name, unit_number = next_unit, valid = true, position = { x = next_unit, y = 0 }, surface = surface,
              force = force, products_finished = 0, crafting_progress = 0, crafting_speed = 1, recipe = recipe,
              returned = returned or {}, water = water or 0, inv = inventory(Cr.CENTERS[name].slots) }
  function e.get_recipe() return e.recipe and { name = e.recipe, energy = (e.recipe:find("^fo%-compute") and 300 or 10) } or nil end
  function e.set_recipe(n) e.recipe = n; local r = e.returned; e.returned = {}; e.water = 0; return r end
  function e.get_module_inventory() return e.inv end
  function e.get_fluid_count(n) return n == "water" and e.water or 0 end
  function e.destroy() e.valid = false end
  world.entities[#world.entities + 1] = e
  return e
end

local function companion_at(name, pos)
  next_unit = next_unit + 1
  local p = { name = name, unit_number = next_unit, valid = true, position = pos, energy = 0, electric_buffer_size = 1,
              power_usage = 0, destructible = true }
  function p.destroy() p.valid = false end
  world.entities[#world.entities + 1] = p
  return p
end

function surface.find_entities_filtered(t)
  local names = {}
  if type(t.name) == "table" then for _, n in ipairs(t.name) do names[n] = true end else names[t.name] = true end
  local out = {}
  for _, e in ipairs(world.entities) do
    if e.valid and names[e.name] and (not t.position or (e.position.x == t.position.x and e.position.y == t.position.y)) then
      out[#out + 1] = e
      if t.limit and #out >= t.limit then break end
    end
  end
  return out
end
function surface.create_entity(t) return companion_at(t.name, t.position) end
function surface.spill_item_stack(pos, st) world.spilled[#world.spilled + 1] = { pos = pos, name = st.name, count = st.count } end

game = { surfaces = { surface }, forces = { player = force }, connected_players = {} }
global = { fo = { compute = { units = {}, by = {}, forces = {}, last_tick = nil } } }  -- espace « compute » d'une 0.6.27

local Compute = require("script.compute.compute")
local S = global.fo.compute

---------------------------------------------------------------------------------------------------
section("1. Sauvegarde 0.6.27 : centres v1 sur une recette à baie usée")
---------------------------------------------------------------------------------------------------
local c1 = center("fo-data-center", "fo-compute-classic", { ["fo-server-blade"] = 2 }, 2400)
local c2 = center("fo-data-center", "fo-compute-accelerated", { ["fo-gpu-blade"] = 8 }, 3000)
local c3 = center("fo-data-center", "fo-compute-quantum", { ["fo-quantum-processor"] = 1 }, 1000)
local c4 = center("fo-data-center", "fo-dc-chilled-water", {}, 0)
c4.inv.insert({ name = "fo-server-blade", count = 1 })
local orphan = companion_at("fo-data-center-power", { x = -50, y = -50 })
-- part de recherche posée par la v1 (+0,2) sur une base des technologies de 0,5
S.forces.player = { rate = 100, bonus = 0.2, centers = 3 }
force.laboratory_speed_modifier = 0.7

Compute.rescan(true)
check(c1.recipe == "fo-dc-chilled-water" and c2.recipe == "fo-dc-chilled-water" and c3.recipe == "fo-dc-chilled-water",
  "centres v1 passés au refroidissement à l'eau glacée")
check(c4.recipe == "fo-dc-chilled-water" and c4.inv.items["fo-server-blade"] == 1, "centre déjà v2 : intact")
check(c1.inv.items["fo-server-blade"] == 2, "2 baies CPU rendues : dans les emplacements du centre")
check(c2.inv.items["fo-gpu-blade"] == 6, "8 baies GPU rendues : 6 dans les emplacements (plein)")
local spilled = {}
for _, s in ipairs(world.spilled) do spilled[s.name] = (spilled[s.name] or 0) + s.count end
check(spilled["fo-gpu-blade"] == 2 and spilled["fo-quantum-processor"] == 1,
  "surplus au sol, rien de perdu (2 baies GPU, 1 processeur quantique)")
local m = S.migrated
check(m.centers == 3 and m.racks_in == 8 and m.spilled == 3 and near(m.water_lost, 6400), "bilan de migration : 3 centres, 8 baies posées, 3 au sol, 6 400 eau perdue",
  string.format("%d, %d, %d, %.0f", m.centers, m.racks_in, m.spilled, m.water_lost))
local comps = surface.find_entities_filtered({ name = { "fo-data-center-power", "fo-data-center-2-power" } })
check(#comps == 4 and not orphan.valid, "un compagnon par centre (4), l'orphelin retiré", #comps)
check(#S.units == 4 and S.units[1] < S.units[4], "centres suivis, liste triée")

---------------------------------------------------------------------------------------------------
section("2. Fenêtres : calcul = règle pure, puissance écrite au compagnon, part de recherche")
---------------------------------------------------------------------------------------------------
Compute.window(60) -- première fenêtre : durée inconnue, rien n'est compté
check(near(force.laboratory_speed_modifier, 0.5, 1e-12) and S.forces.player.bonus == 0, "première fenêtre : part v1 retirée exactement, base 0,5 gardée",
  force.laboratory_speed_modifier)
-- c1 : 2 CPU, sans mémoire → f_mem 0 ; on ajoute une baie de mémoire et un refroidissement
c1.inv.insert({ name = "fo-memory-rack", count = 1 })
c1.inv.insert({ name = "fo-cooling-rack", count = 1 })
-- tous les compagnons alimentés (tampon plein), recettes en marche à pleine vitesse sur 60 ticks
for _, c in ipairs({ c1, c2, c3, c4 }) do
  c.products_finished = 0; c.crafting_progress = 0.1
end
local function feed(full)
  for _, e in ipairs(world.entities) do
    if e.valid and e.name:find("%-power$") then e.energy = full and e.electric_buffer_size or 0 end
  end
end
feed(true)
Compute.window(120)
local function expect(c, r)
  local counts = Cr.counts(c.inv.get_contents())
  return Cr.evaluate(counts, "fo-dc-chilled-water", r, 1, c.name)
end
-- la part r : prev (0 à la fenêtre 60, progress 0) → 0,1 fabrication d'une recette de 10 s en 60 ticks = 1
local want = 0
for _, c in ipairs({ c1, c2, c3, c4 }) do want = want + expect(c, 1).compute end
local st = Compute.state("player")
check(near(st.rate, want, 1e-6), string.format("calcul de la force = somme de la règle pure (%.1f)", want), st.rate)
check(near(st.bonus, Cr.lab_bonus(want), 1e-12) and near(force.laboratory_speed_modifier, 0.5 + Cr.lab_bonus(want), 1e-12),
  "vitesse de recherche = base 0,5 + bonus du calcul", force.laboratory_speed_modifier)
local ev1 = Compute.center(c1)
check(ev1 and near(ev1.compute, expect(c1, 1).compute, 1e-9) and ev1.limit ~= nil, "centre 1 : évaluation gardée pour l'interface")
local p1 = surface.find_entities_filtered({ name = "fo-data-center-power", position = c1.position })[1]
check(p1 and near(p1.power_usage, (ev1.kw - 300) * 1000 / 60, 1e-6) and p1.electric_buffer_size == p1.power_usage,
  "compagnon : power_usage = kW des baies (J/tick), tampon = 1 tick", p1 and p1.power_usage)
-- sans courant : compagnons vides → aucun calcul, part retirée
c1.crafting_progress = 0.2; c2.crafting_progress = 0.2; c3.crafting_progress = 0.2; c4.crafting_progress = 0.2
feed(false)
Compute.window(180)
check(Compute.state("player").rate == 0 and near(force.laboratory_speed_modifier, 0.5, 1e-12),
  "sans courant : 0 unité/s, vitesse revenue exactement à la base", Compute.state("player").rate)
-- centre retiré : compagnon retiré à la fenêtre suivante
c4.valid = false
feed(true)
Compute.window(240)
local alive = 0
for _, e in ipairs(world.entities) do if e.valid and e.name == "fo-data-center-power" then alive = alive + 1 end end
check(#S.units == 3 and alive == 3, "centre disparu : retiré de la liste, son compagnon détruit", alive)

---------------------------------------------------------------------------------------------------
section("2 bis. Migration UNE fois : on_configuration_changed (correctif du 3/11)")
---------------------------------------------------------------------------------------------------
do
  local MOD = "factorio-overhaul"
  local function d(old) return { mod_changes = { [MOD] = { old_version = old, new_version = "0.6.42" } } } end
  check(Cr.v1_migration_due(d("0.6.27"), MOD) and Cr.v1_migration_due(d("0.6.28"), MOD), "versions 0.6.27 et 0.6.28 : migration due")
  check(Cr.v1_migration_due(d("0.5.99"), MOD), "version antérieure (0.5.99) : due")
  check(not Cr.v1_migration_due(d("0.6.29"), MOD) and not Cr.v1_migration_due(d("0.6.41"), MOD) and not Cr.v1_migration_due(d("1.0.0"), MOD),
    "0.6.29, 0.6.41, 1.0.0 : non due")
  check(not Cr.v1_migration_due({ mod_changes = {} }, MOD) and not Cr.v1_migration_due({}, MOD) and not Cr.v1_migration_due(nil, MOD),
    "contenu changé sans montée de version (mod_changes vide, F130) : non due")
  check(not Cr.v1_migration_due(d(nil), MOD) and not Cr.v1_migration_due(d("n'importe quoi"), MOD), "version d'origine absente ou illisible : non due")
  check(not Cr.v1_migration_due({ mod_changes = { autre = { old_version = "0.1.0" } } }, MOD), "un autre mod qui change : non due")

  -- le défaut : un centre sur une recette v1 encore valide, à une configuration changée SANS montée de version, reste intact
  local c = center("fo-data-center", "fo-compute-accelerated", { ["fo-gpu-blade"] = 3 }, 3000)
  Compute.on_config({ mod_changes = {} })
  check(c.recipe == "fo-compute-accelerated" and (c.inv.items["fo-gpu-blade"] or 0) == 0 and c.water == 3000,
    "configuration changée sans montée de version : centre sur recette v1 intact (recette, baies, eau)")
  Compute.on_config(d("0.6.41"))
  check(c.recipe == "fo-compute-accelerated" and c.water == 3000, "montée depuis 0.6.41 : centre intact")
  -- une sauvegarde 0.6.28 : converti, UNE fois (le second passage ne touche plus rien)
  Compute.on_config(d("0.6.28"))
  check(c.recipe == "fo-dc-chilled-water" and c.inv.items["fo-gpu-blade"] == 3 and c.water == 0, "montée depuis 0.6.28 : centre converti, baies rendues dans ses emplacements")
  local n0 = S.migrated.centers
  c.inv.items["fo-gpu-blade"] = 0
  Compute.on_config(d("0.6.28"))
  check(S.migrated.centers == n0 and c.recipe == "fo-dc-chilled-water", "second passage : plus rien à convertir (idempotent)")
end

---------------------------------------------------------------------------------------------------
section("3. Mutants")
---------------------------------------------------------------------------------------------------
do
  -- recette de migration v1 (rien ne change) : les baies resteraient en entrée, le centre ne calculerait rien
  local save = Compute.MIGRATION_RECIPE
  local c = center("fo-data-center", "fo-compute-classic", { ["fo-server-blade"] = 1 }, 0)
  Compute.MIGRATION_RECIPE = "fo-compute-classic"
  Compute.rescan(true)
  check(c.inv.items["fo-server-blade"] == 1 and c.recipe == "fo-compute-classic",
    "témoin du mutant : la migration pose la baie, mais le centre reste sur la v1 (le banc calcul-v2-migration le voit)")
  Compute.MIGRATION_RECIPE = save
  -- mutant : migration due à CHAQUE changement de configuration (le défaut d'origine) -> le centre v1 intact serait converti
  local due = Cr.v1_migration_due
  Cr.v1_migration_due = function() return true end
  local k = center("fo-data-center", "fo-compute-quantum", {}, 6000)
  Compute.on_config({ mod_changes = {} })
  check(k.recipe == "fo-dc-chilled-water", "témoin du mutant : migration à chaque configuration -> le centre v1 est converti (vu par la section 2 bis)")
  Cr.v1_migration_due = due
  k.recipe = "fo-compute-quantum"
  Compute.on_config({ mod_changes = {} })
  check(k.recipe == "fo-compute-quantum", "règle rétablie : même centre intact")
  -- satisfaction non lue (e = 1 toujours) : le calcul ne tomberait pas sans courant
  local sat = Cr.satisfaction
  Cr.satisfaction = function() return 1 end
  feed(false)
  for _, x in ipairs({ c1, c2, c3 }) do x.crafting_progress = x.crafting_progress + 0.1 end
  Compute.window(300)
  Compute.window(360)
  check(Compute.state("player").rate > 0, "mutant refusé : satisfaction ignorée → du calcul sans courant (vu par la section 2)")
  Cr.satisfaction = sat
end

print(string.format("[CALCUL-V2-SCRIPT] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
