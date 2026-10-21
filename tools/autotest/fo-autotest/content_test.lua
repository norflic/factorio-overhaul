--[[
  Banc de CONTENU en moteur réel (scénario "content") : chaque élément ajouté par le mod est fabriqué, posé,
  alimenté ou combattu dans le vrai jeu, et son effet est mesuré. Lignes [FO-CONTENT] OK / ECHEC, puis un
  bilan. Les valeurs attendues viennent des fichiers de données du mod (shared/), jamais d'une copie.

  Déroulé : T.start() pendant on_init (--create), puis T.on_tick() pendant le benchmark (la sauvegarde est
  rechargée : tout état durable vit dans global.content).
  Isolement : les cibles appartiennent à une force de test ("fo-test-target") ; joueur et biters naturels
  sont en cessez-le-feu pour que la faune locale ne fausse pas les mesures.
]]

local M = require("__factorio-overhaul__/shared/content/modules")
local E = require("__factorio-overhaul__/shared/content/enemies")
local W = require("__factorio-overhaul__/shared/content/world")
local LV = require("__factorio-overhaul__/shared/levels/config")
local Greffons = require("greffons")

local T = {}

local CHECK_TICK = 3000 -- 50 s de jeu

local function R()
  global.content_results = global.content_results or { ok = 0, fail = 0, failed = {} }
  return global.content_results
end

local function ok(name, detail)
  local r = R()
  r.ok = r.ok + 1
  log("[FO-CONTENT] OK     " .. name .. (detail and (" : " .. detail) or ""))
end

local function fail(name, detail)
  local r = R()
  r.fail = r.fail + 1
  r.failed[#r.failed + 1] = name
  log("[FO-CONTENT] ECHEC  " .. name .. (detail and (" : " .. detail) or ""))
end

local function check(cond, name, detail)
  if cond then ok(name, detail) else fail(name, detail) end
end

-- Contrôles GREFFÉS (checks/index.lua) : chargés ici, au chargement du mod (F24), comptés dans le BILAN.
Greffons.load_checks({ ok = ok, fail = fail })

---------------------------------------------------------------------------------------------------
-- Terrain : zone plate et dégagée ; électricité par sous-stations placées dans les allées
---------------------------------------------------------------------------------------------------
local function prepare_area(s, x0, y0, x1, y1, tile)
  for cx = math.floor(x0 / 32), math.floor((x1 - 1) / 32) do
    for cy = math.floor(y0 / 32), math.floor((y1 - 1) / 32) do
      s.request_to_generate_chunks({ x = cx * 32 + 16, y = cy * 32 + 16 }, 0)
    end
  end
  s.force_generate_chunk_requests()
  for _, e in ipairs(s.find_entities_filtered({ area = { { x0, y0 }, { x1, y1 } } })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
  local tiles = {}
  for x = x0, x1 - 1 do
    for y = y0, y1 - 1 do tiles[#tiles + 1] = { name = tile or "refined-concrete", position = { x, y } } end
  end
  s.set_tiles(tiles)
end

local function energy_interface(s, x, y)
  local eei = s.create_entity({ name = "electric-energy-interface", position = { x, y }, force = "player" })
  eei.electric_buffer_size = 1e12
  eei.power_production = 1e10 -- J/tick (600 GW)
  eei.energy = 1e12
  return eei
end

-- Sous-stations (portée 18, zone 18×18) en grille à partir de (x0, y0) : les machines sont posées tous les
-- 6 tuiles avec des allées de 3 tuiles alignées sur cette grille, donc aucun chevauchement.
local function power_grid(s, x0, y0, x1, y1)
  local prev_col = {}
  for x = x0, x1, 18 do
    local col, above = {}, nil
    for y = y0, y1, 18 do
      local p = s.create_entity({ name = "substation", position = { x, y }, force = "player" })
      if above then p.connect_neighbour(above) end
      if prev_col[#col + 1] then p.connect_neighbour(prev_col[#col + 1]) end
      col[#col + 1] = p
      above = p
    end
    prev_col = col
  end
  energy_interface(s, x0 + 6, y0)
end

---------------------------------------------------------------------------------------------------
-- Technologies : chaque recette du mod est débloquée par une recherche, et tout se débloque
---------------------------------------------------------------------------------------------------
local function test_techs()
  local force = game.forces.player
  local unlocked_by = {}
  local count = 0
  for name, tech in pairs(game.technology_prototypes) do
    if name:find("^fo%-") then count = count + 1 end
    for _, eff in ipairs(tech.effects) do
      if eff.type == "unlock-recipe" then unlocked_by[eff.recipe] = name end
    end
  end
  check(count > 0, "technologies du mod presentes", count .. " technologies")
  local free, orphan = {}, {}
  -- Le coffre d'équipe est disponible dès le départ (décision session 4 : les compagnons du joueur
  -- travaillent dès la première minute, comme les équipes IA).
  -- Session 5 : le centre de commandement (hôtel de ville des niveaux) aussi.
  local START = { ["fo-team-chest"] = true, ["fo-command-center"] = true }
  for name, rec in pairs(force.recipes) do
    if name:find("^fo%-") and not START[name] then
      if rec.enabled then free[#free + 1] = name end
      if not unlocked_by[name] then orphan[#orphan + 1] = name end
    end
  end
  check(force.recipes["fo-team-chest"] and force.recipes["fo-team-chest"].enabled, "coffre d'equipe disponible des le depart")
  table.sort(free)
  table.sort(orphan)
  check(#orphan == 0, "technologies : chaque recette du mod a une recherche qui la debloque",
    #orphan > 0 and ("sans recherche : " .. table.concat(orphan, ", ")) or nil)
  check(force.recipes["fo-command-center"] and force.recipes["fo-command-center"].enabled, "centre de commandement disponible des le depart")
  check(#free == 0, "technologies : aucune recette du mod disponible sans recherche (hors coffre d'equipe et centre)",
    #free > 0 and ("disponibles d'emblee : " .. table.concat(free, ", ")) or nil)

  force.research_all_technologies()
  local missing = {}
  for name, rec in pairs(force.recipes) do
    if name:find("^fo%-") and not rec.enabled then missing[#missing + 1] = name end
  end
  table.sort(missing)
  check(#missing == 0, "technologies : toutes les recettes du mod debloquees apres recherche",
    #missing > 0 and table.concat(missing, ", ") or nil)
end

---------------------------------------------------------------------------------------------------
-- Recettes : chaque recette du mod tourne dans la bonne machine
---------------------------------------------------------------------------------------------------
local MACHINE = {
  ["crafting"] = "assembling-machine-3", ["advanced-crafting"] = "assembling-machine-3",
  ["crafting-with-fluid"] = "assembling-machine-3", ["smelting"] = "electric-furnace",
  ["chemistry"] = "chemical-plant", ["oil-processing"] = "oil-refinery",
}

local function setup_recipes(s, S)
  local names = {}
  for name in pairs(game.recipe_prototypes) do
    if name:find("^fo%-") then names[#names + 1] = name end
  end
  table.sort(names)
  S.recipes = {}
  local i = 0
  for _, name in ipairs(names) do
    local r = game.recipe_prototypes[name]
    local mname = MACHINE[r.category]
    if not mname then
      fail("recette " .. name, "categorie sans machine de test : " .. r.category)
    else
      local x = S.rx0 + (i % 12) * 6
      local y = S.ry0 + math.floor(i / 12) * 6
      i = i + 1
      local m = s.create_entity({ name = mname, position = { x, y }, force = "player" })
      if not m then
        fail("recette " .. name, "machine non posee")
      else
        if m.type ~= "furnace" then m.set_recipe(name) end
        for _, ing in ipairs(r.ingredients) do
          if ing.type == "fluid" then
            m.insert_fluid({ name = ing.name, amount = math.min(ing.amount * 4, 200) })
          else
            m.insert({ name = ing.name, count = ing.amount * 4 })
          end
        end
        S.recipes[#S.recipes + 1] = { name = name, machine = m, energy = r.energy }
      end
    end
  end
end

local function verify_recipes(S)
  for _, rec in ipairs(S.recipes) do
    local m = rec.machine
    local r = game.recipe_prototypes[rec.name]
    local produced = 0
    for _, p in ipairs(r.products) do
      if p.type == "fluid" then
        produced = produced + m.get_fluid_count(p.name)
      else
        produced = produced + m.get_output_inventory().get_item_count(p.name)
      end
    end
    local progress = m.crafting_progress or 0
    if produced > 0 then
      ok("recette " .. rec.name, string.format("%g produit(s) en %d s", produced, CHECK_TICK / 60))
    elseif progress > 0 then
      ok("recette " .. rec.name, string.format("en cours (%.0f %% d'une fabrication de %g s)", progress * 100, rec.energy))
    else
      fail("recette " .. rec.name, "rien produit, statut " .. tostring(m.status))
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Modules : effets lus sur une machine équipée de 4 modules identiques
---------------------------------------------------------------------------------------------------
local function floor80(v) return math.max(v, -0.8) end

local function setup_modules(s, S)
  S.modules = {}
  local i = 0
  for _, fam in ipairs(M.ORDER) do
    for k = 1, M.TIERS do
      local name = M.name(fam, k)
      local x = S.mx0 + (i % 10) * 6
      local y = S.my0 + math.floor(i / 10) * 6
      i = i + 1
      local m = s.create_entity({ name = "assembling-machine-3", position = { x, y }, force = "player" })
      m.set_recipe("iron-gear-wheel")
      m.insert({ name = "iron-plate", count = 100 })
      local inserted = m.get_module_inventory().insert({ name = name, count = 4 })
      S.modules[#S.modules + 1] = { fam = fam, k = k, name = name, machine = m, inserted = inserted }
    end
  end
end

local function verify_modules(S)
  for _, md in ipairs(S.modules) do
    local e = M.families[md.fam].effects
    local function sum(key) return (e[key] and e[key][md.k] or 0) * 4 end
    local m = md.machine
    local want = {
      speed = floor80(sum("speed")),
      prod = math.max(0, sum("productivity")),
      cons = floor80(sum("consumption")),
      poll = floor80(sum("pollution")),
    }
    local got = { speed = m.speed_bonus, prod = m.productivity_bonus, cons = m.consumption_bonus, poll = m.pollution_bonus }
    local good = md.inserted == 4
    for key, v in pairs(want) do
      if math.abs(got[key] - v) > 0.011 then good = false end
    end
    check(good, "module " .. md.name, string.format(
      "%d inseres | vitesse %+.2f (att. %+.2f) | productivite %+.2f (att. %+.2f) | conso %+.2f (att. %+.2f) | pollution %+.2f (att. %+.2f)",
      md.inserted, got.speed, want.speed, got.prod, want.prod, got.cons, want.cons, got.poll, want.poll))
  end
  local lim = game.item_prototypes[M.name("productivity", M.TIERS)].limitations
  local set = {}
  for _, r in pairs(lim) do set[r] = true end
  check(set["fo-tungsten-plate"] and set["iron-gear-wheel"] and not set["fo-heavy-gun-turret"] and not set["fo-armored-wall"],
    "productivite : limitation (tungstene oui, produits finis non)", #lim .. " recettes autorisees")
end

---------------------------------------------------------------------------------------------------
-- Combat : dégâts par seconde sur une cible immobile, par arme et munition
---------------------------------------------------------------------------------------------------
local DUELS = {
  -- { cle, tourelle, munition (objet) ou "fluid:<nom>", cible }
  { "standard/behemoth", "gun-turret", "firearm-magazine", "behemoth-biter" },
  { "perforant/behemoth", "gun-turret", "piercing-rounds-magazine", "behemoth-biter" },
  { "tungstene/behemoth", "gun-turret", "fo-tungsten-rounds-magazine", "behemoth-biter" },
  { "explosif/behemoth", "gun-turret", "fo-explosive-rounds-magazine", "behemoth-biter" },
  { "incendiaire/behemoth", "gun-turret", "fo-incendiary-rounds-magazine", "behemoth-biter" },
  { "plasma/behemoth", "gun-turret", "fo-plasma-rounds-magazine", "behemoth-biter" },
  { "perforant/blinde", "gun-turret", "piercing-rounds-magazine", "fo-armored-behemoth-biter" },
  { "tungstene/blinde", "gun-turret", "fo-tungsten-rounds-magazine", "fo-armored-behemoth-biter" },
  { "laser/blinde", "laser-turret", nil, "fo-armored-behemoth-biter" },
  { "incendiaire/igne", "gun-turret", "fo-incendiary-rounds-magazine", "fo-pyro-behemoth-biter" },
  { "tourelle lourde perforant/behemoth", "fo-heavy-gun-turret", "piercing-rounds-magazine", "behemoth-biter" },
  { "laser/behemoth", "laser-turret", nil, "behemoth-biter" },
  { "laser lourd/behemoth", "fo-heavy-laser-turret", nil, "behemoth-biter" },
  { "laser/foudroyant", "laser-turret", nil, "fo-storm-behemoth-biter" },
  -- Cible de 3 000 PV : sur un big (375 PV, tué en 1,5 s) la mise en route du jet domine la mesure et
  -- masque l'écart de carburant (moteur réel : méthane 237 PV/s contre pétrole léger 245 PV/s).
  { "lance-flammes petrole leger/behemoth", "flamethrower-turret", "fluid:light-oil", "behemoth-biter" },
  { "lance-flammes methane/behemoth", "flamethrower-turret", "fluid:fo-methane", "behemoth-biter" },
  { "tourelle lourde tungstene/colossal", "fo-heavy-gun-turret", "fo-tungsten-rounds-magazine", "fo-colossal-biter" },
  -- Session 4 : nouvelles familles d'armes. { ..., distance, nombre de cibles (groupe serré) }
  { "canon obus/blinde", "fo-cannon-turret", "cannon-shell", "fo-armored-behemoth-biter", 14 },
  { "canon tungstene/blinde", "fo-cannon-turret", "fo-tungsten-cannon-shell", "fo-armored-behemoth-biter", 14 },
  { "mortier/groupe couvee", "fo-mortar-turret", "fo-mortar-shell", "fo-brood-big-biter", 26, 6 },
  { "mitrailleuse perforant/groupe couvee", "gun-turret", "piercing-rounds-magazine", "fo-brood-big-biter", 12, 6 },
  { "arc/groupe couvee", "fo-tesla-turret", nil, "fo-brood-big-biter", 12, 6 },
  { "arc/groupe foudroyant", "fo-tesla-turret", nil, "fo-storm-big-biter", 12, 6 },
  { "acide/igne", "fo-acid-sprayer", "fluid:sulfuric-acid", "fo-pyro-behemoth-biter", 12 },
  -- Référence du contre « acide » : les ignés sont IMMUNISÉS au feu, aucun dégât attendu.
  { "lance-flammes/igne", "flamethrower-turret", "fluid:light-oil", "fo-pyro-behemoth-biter", 12, immune = true },
}

-- Armes portatives : un corps armé (sans joueur) tire sur une cible immobile.
local HANDHELD = {
  { "fusil a rail/ligne de 4", "fo-railgun", "fo-rail-slug", "behemoth-biter", 20, 4 },
  { "mitraillette perforant/ligne de 4", "submachine-gun", "piercing-rounds-magazine", "behemoth-biter", 14, 4 },
  { "lance-grenades/groupe", "fo-grenade-launcher", "fo-launcher-grenade", "big-biter", 16, 5 },
  { "arc portatif/groupe", "fo-arc-gun", "fo-arc-cell", "big-biter", 10, 5 },
}

local function setup_duels(s, S)
  S.duels = {}
  local target_force = game.forces["fo-test-target"] or game.create_force("fo-test-target")
  for i, d in ipairs(DUELS) do
    local x = S.dx0 + (i - 1) * 80
    local y = S.dy
    s.create_entity({ name = "substation", position = { x, y + 8 }, force = "player" })
    energy_interface(s, x + 4, y + 8)
    -- Les lance-flammes sont orientés et ne tirent que dans un cône : on les tourne vers la cible (est).
    local t = s.create_entity({ name = d[2], position = { x, y }, force = "player", direction = defines.direction.east })
    local fluid
    if d[3] and d[3]:find("^fluid:") then
      fluid = d[3]:sub(7)
      local n = t.insert_fluid({ name = fluid, amount = 100 })
      if n <= 0 then fail("combat " .. d[1], "fluide refuse par la tourelle : " .. fluid) end
    elseif d[3] then
      t.insert({ name = d[3], count = 100 })
    end
    local dist, n = d[5] or 12, d[6] or 1
    local targets, max = {}, 0
    for k = 1, n do
      -- Groupe serré (en grappe autour du point visé)
      local ox, oy = ((k - 1) % 3 - 1) * 1.6, (math.floor((k - 1) / 3) - 0.5) * 1.6
      if n == 1 then ox, oy = 0, 0 end
      local target = s.create_entity({ name = d[4], position = { x + dist + ox, y + oy }, force = target_force })
      target.active = false
      targets[#targets + 1] = target
      max = max + target.health
    end
    S.duels[i] = { key = d[1], turret = t, fluid = fluid, targets = targets, max = max, killed_at = nil, hp = max, kills = 0, immune = d.immune }
  end
  -- Armes portatives
  for j, h in ipairs(HANDHELD) do
    local i = #DUELS + j
    local x = S.dx0 + (i - 1) * 80
    local y = S.dy
    local body = s.create_entity({ name = "fo-companion", position = { x, y }, force = "player" })
    body.get_inventory(defines.inventory.character_guns).insert({ name = h[2], count = 1 })
    body.get_inventory(defines.inventory.character_ammo).insert({ name = h[3], count = 200 })
    local targets, max = {}, 0
    for k = 1, h[6] do
      -- En ligne pour le fusil à rail, en grappe pour les armes de zone.
      local line = h[2] == "fo-railgun" or h[2] == "submachine-gun"
      local pos = line and { x + h[5] + (k - 1) * 2.5, y }
        or { x + h[5] + ((k - 1) % 3 - 1) * 1.4, y + (math.floor((k - 1) / 3) - 0.5) * 1.4 }
      local target = s.create_entity({ name = h[4], position = pos, force = target_force })
      target.active = false
      targets[#targets + 1] = target
      max = max + target.health
    end
    S.duels[i] = { key = h[1], body = body, aim = { x = x + h[5], y = y }, targets = targets, max = max, killed_at = nil, hp = max, kills = 0 }
  end
  S.duel_start = game.tick
end

local function tick_duels(S, tick)
  for _, d in ipairs(S.duels) do
    if not d.killed_at then
      local hp, alive = 0, 0
      for _, t in ipairs(d.targets) do
        if t.valid then
          hp = hp + t.health
          alive = alive + 1
        end
      end
      d.hp = hp
      d.kills = #d.targets - alive
      if alive == 0 then d.killed_at = tick end
    end
    if d.body and d.body.valid and not d.killed_at then
      -- Tir dirigé sur le premier ennemi vivant (le corps n'a pas de joueur pour viser).
      local aim = d.aim
      for _, t in ipairs(d.targets) do
        if t.valid then aim = t.position break end
      end
      d.body.shooting_state = { state = defines.shooting.shooting_enemies, position = aim }
    end
    if d.fluid and (tick % 60) == 0 and d.turret.valid and d.turret.get_fluid_count(d.fluid) < 50 then
      d.turret.insert_fluid({ name = d.fluid, amount = 50 })
    end
  end
end

local function verify_duels(S)
  local dps = {}
  for _, d in ipairs(S.duels) do
    local t = ((d.killed_at or CHECK_TICK) - S.duel_start) / 60
    local dealt = d.max - d.hp
    dps[d.key] = dealt / math.max(t, 1 / 60)
    local n = #d.targets
    local detail = d.killed_at and string.format("%s tuee(s) en %.1f s (%.0f PV, %.0f PV/s)", n > 1 and (n .. " cibles") or "cible", t, d.max, dps[d.key])
      or string.format("%d/%d cible(s) tuee(s), %.0f / %.0f PV restants apres %.0f s (%.0f PV/s)", d.kills, n, d.hp, d.max, t, dps[d.key])
    if d.immune then
      check(dealt == 0, "combat " .. d.key .. " (cible immunisee : aucun degat attendu)", detail)
    else
      check(dealt > 0, "combat " .. d.key, detail)
    end
  end
  local function better(a, b, label)
    if dps[a] and dps[b] then check(dps[a] > dps[b], label, string.format("%.0f PV/s contre %.0f PV/s", dps[a], dps[b])) end
  end
  better("tungstene/behemoth", "perforant/behemoth", "tungstene plus efficace que perforant")
  better("tungstene/blinde", "perforant/blinde", "tungstene perce mieux les blindes")
  better("laser/blinde", "perforant/blinde", "laser contre les blindes (leur faiblesse)")
  better("incendiaire/behemoth", "incendiaire/igne", "les ignes resistent a l'incendiaire")
  better("tourelle lourde perforant/behemoth", "perforant/behemoth", "tourelle lourde plus efficace")
  better("laser lourd/behemoth", "laser/behemoth", "laser lourd plus efficace")
  better("laser/behemoth", "laser/foudroyant", "les foudroyants resistent au laser")
  better("lance-flammes methane/behemoth", "lance-flammes petrole leger/behemoth", "methane brule mieux que le petrole leger")
  better("plasma/behemoth", "tungstene/behemoth", "plasma plus efficace que tungstene")
  better("canon tungstene/blinde", "canon obus/blinde", "obus en tungstene meilleurs contre les blindes")
  better("canon obus/blinde", "perforant/blinde", "le canon bat la mitrailleuse contre les blindes")
  better("mortier/groupe couvee", "mitrailleuse perforant/groupe couvee", "le mortier nettoie un groupe mieux que la mitrailleuse")
  better("arc/groupe couvee", "arc/groupe foudroyant", "les foudroyants resistent a l'arc")
  better("acide/igne", "lance-flammes/igne", "l'acide vient a bout des ignes (immunises au feu)")
  better("fusil a rail/ligne de 4", "mitraillette perforant/ligne de 4", "le fusil a rail transperce une ligne")
end

---------------------------------------------------------------------------------------------------
-- Déchiqueteurs, vers, nids : création, PV, courbes d'apparition, mécaniques de mort
---------------------------------------------------------------------------------------------------
local function setup_enemies(s, S)
  local target_force = game.forces["fo-test-target"]
  local names = {}
  for name, p in pairs(game.entity_prototypes) do
    if name:find("^fo%-") and (p.type == "unit" or p.type == "turret" or p.type == "unit-spawner") then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  local n_ok, bad = 0, {}
  for i, name in ipairs(names) do
    local x = S.ex0 + ((i - 1) % 20) * 8
    local y = S.ey0 + math.floor((i - 1) / 20) * 8
    local e = s.create_entity({ name = name, position = { x, y }, force = target_force })
    if e and e.valid and math.abs(e.health - game.entity_prototypes[name].max_health) < 1 then
      e.active = false
      n_ok = n_ok + 1
    else
      bad[#bad + 1] = name
    end
  end
  check(#bad == 0, "ennemis : chaque unite, ver et nid se cree avec ses PV",
    n_ok .. " / " .. #names .. (#bad > 0 and (" ; " .. table.concat(bad, ", ")) or ""))

  -- Courbes d'apparition : les 8 paliers dans les nids vanilla et dans chaque nid de famille
  local function spawner_has(spawner, list)
    local set, miss = {}, {}
    for _, ru in pairs(game.entity_prototypes[spawner].result_units) do set[ru.unit] = true end
    for _, u in ipairs(list) do if not set[u] then miss[#miss + 1] = u end end
    check(#miss == 0, "nid " .. spawner .. " : les " .. #list .. " unites attendues apparaissent",
      #miss > 0 and ("manquent " .. table.concat(miss, ", ")) or nil)
  end
  local biters, spitters = {}, {}
  for tier = 1, E.TIERS do
    biters[#biters + 1] = E.unit_name("biter", tier)
    spitters[#spitters + 1] = E.unit_name("spitter", tier)
  end
  spawner_has("biter-spawner", biters)
  spawner_has("spitter-spawner", spitters)
  for _, fam in ipairs(E.FAMILY_ORDER) do
    local list = {}
    for tier = 1, E.TIERS do
      list[#list + 1] = E.unit_name("biter", tier, fam)
      list[#list + 1] = E.unit_name("spitter", tier, fam)
    end
    spawner_has(E.nest_name(fam), list)
  end

  -- Mort ignée -> feu ; mort couvée -> enfants du palier inférieur
  local base_y = S.ey0 + 8 * (math.floor((#names - 1) / 20) + 3)
  local pyro = s.create_entity({ name = E.unit_name("biter", 3, "pyro"), position = { S.ex0, base_y }, force = target_force })
  S.pyro_pos = pyro.position
  pyro.die()
  local brood = s.create_entity({ name = E.unit_name("biter", 3, "brood"), position = { S.ex0 + 40, base_y }, force = target_force })
  S.brood_pos = brood.position
  brood.die()
  -- Nid de famille vivant (force des biters) : produit-il des défenseurs ?
  S.nest = s.create_entity({ name = E.nest_name("armored"), position = { S.ex0 + 100, base_y + 10 }, force = "enemy" })
end

local function verify_enemy_deaths(s, S)
  local fires = s.count_entities_filtered({ position = S.pyro_pos, radius = 4, name = "fire-flame" })
  check(fires > 0, "famille ignee : le sol s'embrase a la mort", fires .. " flamme(s)")
  local child = E.brood_child("biter", 3)
  local kids = s.count_entities_filtered({ position = S.brood_pos, radius = 6, name = child })
  check(kids == E.families.brood.brood, "famille couvee : enfants a la mort", kids .. " " .. child)
end

local function verify_nest(s, S)
  local n = S.nest.valid and s.count_entities_filtered({ position = S.nest.position, radius = 30, type = "unit", force = "enemy" }) or 0
  check(n > 0, "nid de famille : produit des defenseurs", n .. " unite(s) en " .. (CHECK_TICK / 60) .. " s")
end

---------------------------------------------------------------------------------------------------
-- Murs : PV et encaissement face au mur de pierre
---------------------------------------------------------------------------------------------------
local function test_walls(s, S)
  local hp = {}
  for i, name in ipairs({ "stone-wall", "fo-reinforced-wall", "fo-armored-wall" }) do
    local w = s.create_entity({ name = name, position = { S.wx0 + i * 3, S.wy }, force = "player" })
    local before = w.health
    w.damage(300, "enemy", "physical")
    local after_phys = w.health
    w.health = before
    w.damage(300, "enemy", "explosion")
    hp[name] = { max = before, phys = before - after_phys, expl = before - w.health }
  end
  local s0, s1, s2 = hp["stone-wall"], hp["fo-reinforced-wall"], hp["fo-armored-wall"]
  check(s1.max > s0.max and s2.max > s1.max, "murs : PV croissants", string.format("%d / %d / %d", s0.max, s1.max, s2.max))
  check(s2.phys < s1.phys and s1.phys < s0.phys, "murs : resistance physique croissante",
    string.format("300 degats -> pierre -%.0f, renforce -%.0f, blinde -%.0f", s0.phys, s1.phys, s2.phys))
  check(s2.expl < s1.expl and s1.expl < s0.expl, "murs : resistance aux explosions croissante",
    string.format("300 degats -> pierre -%.0f, renforce -%.0f, blinde -%.0f", s0.expl, s1.expl, s2.expl))
end

---------------------------------------------------------------------------------------------------
-- Niveaux (session 5) : prototypes, statistiques croissantes, bonus de recherche, chantiers réels,
-- galerie des 10 niveaux de chaque famille pour la revue visuelle.
---------------------------------------------------------------------------------------------------
local function proto_stat(p, key)
  if key == "max_health" then return p.max_health end
  if key == "damage_modifier" then return p.attack_parameters and p.attack_parameters.damage_modifier end
  if key == "range" then return p.attack_parameters and p.attack_parameters.range end
  if key == "mining_speed" then return p.mining_speed end
  if key == "crafting_speed" then return p.crafting_speed end
  if key == "energy_usage" then return p.energy_usage end
  if key == "inventory_size" then return p.get_inventory_size(defines.inventory.chest) end
  if key == "rotation_speed" then return nil end
end

local function test_level_prototypes()
  local missing, bad_item = {}, {}
  for _, f in ipairs(LV.families) do
    local prev = {}
    local growing = true
    local detail = {}
    for n = 1, LV.MAX do
      local name = LV.name(f, n)
      local p = game.entity_prototypes[name]
      if not p then
        missing[#missing + 1] = name
      else
        local item = game.item_prototypes[name]
        if not (item and item.place_result and item.place_result.name == name) then bad_item[#bad_item + 1] = name end
        if p.mineable_properties.products[1].name ~= name then bad_item[#bad_item + 1] = name .. " (minage)" end
        for _, st in ipairs(f.stats) do
          local key = st.path[#st.path]
          local v = proto_stat(p, key)
          if v then
            if prev[key] and not (v > prev[key]) then growing = false end
            prev[key] = v
            if n == 1 or n == LV.MAX then detail[#detail + 1] = key .. "=" .. string.format("%.3g", v) end
          end
        end
      end
    end
    check(growing, "niveaux " .. f.key .. " : statistiques strictement croissantes de 1 a 10", table.concat(detail, " "))
  end
  check(#missing == 0, "niveaux : 70 prototypes presents", #missing > 0 and table.concat(missing, ", ") or nil)
  check(#bad_item == 0, "niveaux : chaque niveau a son objet (pose et minage rendent le meme niveau)",
    #bad_item > 0 and table.concat(bad_item, ", ") or nil)
  local force = game.forces.player
  local m1, m10 = force.get_turret_attack_modifier("gun-turret"), force.get_turret_attack_modifier(LV.name(LV.by_key.gun, 10))
  check(m1 > 0 and math.abs(m1 - m10) < 1e-6, "niveaux : bonus de recherche des tourelles herites",
    string.format("mitrailleuse %.2f, niveau 10 %.2f", m1, m10))
end

local function stock(inv, family, n, times)
  for _, c in ipairs(LV.cost(family, n)) do inv.insert({ name = c[1], count = c[2] * (times or 1) }) end
end

local function at(s, name, x, y)
  return s.find_entity(name, { x, y })
end

local function setup_levels(s, S)
  test_level_prototypes()
  local x0, y0 = S.lx0, S.ly0
  local call = function(fn, ...) return remote.call("factorio-overhaul", fn, ...) end
  -- Chantiers accélérés ×20 (10 s → 0,5 s) pour tenir dans le banc.
  call("levels_time_factor", 0.05)
  local cc = s.create_entity({ name = "fo-command-center", position = { x0 + 2, y0 + 2 }, force = "player", raise_built = true })
  local inv = cc.get_inventory(defines.inventory.chest)
  local G, C, A, Wl = LV.by_key.gun, LV.by_key.command, LV.by_key.assembler, LV.by_key.wall
  stock(inv, G, 2, 1)
  stock(inv, G, 3, 1)
  stock(inv, C, 2, 1)
  stock(inv, A, 2, 1)
  stock(inv, Wl, 2, 5)
  inv.insert({ name = "iron-chest", count = 7 })
  S.lv = { cc_pos = cc.position, chest_marker = inv.get_item_count("iron-chest") }
  check(call("levels_status", "player").cc_level == 1, "niveaux : centre de commandement niveau 1 enregistre")
  -- Second centre refusé (un seul par force).
  local cc2 = s.create_entity({ name = "fo-command-center", position = { x0 + 12, y0 + 2 }, force = "player", raise_built = true })
  -- (le gestionnaire « construit » le retire pendant create_entity, qui renvoie alors nil)
  check(not (cc2 and cc2.valid) and at(s, "fo-command-center", x0 + 12, y0 + 2) == nil,
    "niveaux : un seul centre de commandement par force")
  -- Tourelle A : endommagée, 25 chargeurs ; chantier vers le niveau 2.
  local ga = s.create_entity({ name = "gun-turret", position = { x0 + 20, y0 + 2 }, force = "player" })
  ga.insert({ name = "firearm-magazine", count = 25 })
  ga.health = ga.prototype.max_health / 2
  local r = call("levels_upgrade", ga)
  check(r.ok and r.reason == "started", "niveaux : chantier lance (paye par le centre)", tostring(r.reason))
  check(ga.valid and ga.active == false, "niveaux : tourelle hors service pendant le chantier")
  S.lv.ga = ga.position
  -- Tourelle B : refusée, le seul ouvrier est occupé.
  local gb = s.create_entity({ name = "gun-turret", position = { x0 + 24, y0 + 2 }, force = "player" })
  r = call("levels_upgrade", gb)
  check(not r.ok and r.reason == "no-builder", "niveaux : un seul ouvrier au centre niveau 1", tostring(r.reason))
  -- Tourelle C, posée directement au niveau 2 : refusée, centre trop bas.
  local gc = s.create_entity({ name = LV.name(G, 2), position = { x0 + 28, y0 + 2 }, force = "player" })
  r = call("levels_upgrade", gc)
  check(not r.ok and r.reason == "cc-too-low", "niveaux : niveau 3 refuse avec un centre niveau 1", tostring(r.reason))
  S.lv.gc = gc.position
  -- Murs : rangée de 5, instantanée.
  -- (positions au CENTRE des tuiles : find_entity sur un coin de tuile ne trouve pas un mur 1×1)
  for i = 0, 4 do s.create_entity({ name = "stone-wall", position = { x0 + 34.5 + i, y0 + 2.5 }, force = "player" }) end
  local nw = call("levels_row", at(s, "stone-wall", x0 + 36.5, y0 + 2.5))
  local all = 0
  for i = 0, 4 do if at(s, LV.name(Wl, 2), x0 + 34.5 + i, y0 + 2.5) then all = all + 1 end end
  check(nw == 5 and all == 5, "niveaux : rangee de 5 murs amelioree instantanement", nw .. " / " .. all)
  -- Machine d'assemblage avec recette et ingrédients : préparée pour le chantier suivant.
  local am = s.create_entity({ name = "assembling-machine-2", position = { x0 + 44, y0 + 2 }, force = "player" })
  am.set_recipe("iron-gear-wheel")
  am.insert({ name = "iron-plate", count = 40 })
  S.lv.am = am.position
  power_grid(s, x0 + 41, y0 - 1, x0 + 47, y0 + 5)
  S.lv.phase = 1

  -- Galerie : les 10 niveaux de chaque famille, une rangée par famille.
  local gx, gy = S.gx0, S.gy0
  S.gallery = {}
  local gaps = {}
  local row_y = gy
  for _, f in ipairs(LV.families) do
    local step = (f.key == "wall") and 5 or (f.size + 3)
    local y = row_y + f.size / 2
    for n = 1, LV.MAX do
      local x = gx + (n - 1) * step + f.size / 2
      if f.key == "wall" then
        for k = -1, 1 do s.create_entity({ name = LV.name(f, n), position = { x + k, y }, force = "player" }) end
      else
        if f.key == "drill" then
          for dx = -1, 1 do for dy = -1, 1 do s.create_entity({ name = "iron-ore", position = { x + dx, y + dy }, amount = 5000 }) end end
        end
        s.create_entity({ name = LV.name(f, n), position = { x, y }, force = "player", raise_built = false })
      end
    end
    S.gallery[#S.gallery + 1] = { key = f.key, x1 = gx + f.size / 2, step = step, y = y, size = f.size }
    gaps[#gaps + 1] = row_y + f.size + 2
    row_y = row_y + f.size + 4
  end
  -- Courant : petits poteaux dans les allées entre les rangées (sprite discret ; les sous-stations
  -- masquaient la galerie sur les captures). Portée 2,5 : l'allée de 4 tuiles couvre les deux rangées.
  local prev_row
  for _, gy_ in ipairs(gaps) do
    local row = {}
    for x = gx + 0.5, gx + 75, 5 do
      local p = s.create_entity({ name = "small-electric-pole", position = { x, gy_ - 0.5 }, force = "player" })
      if row[#row] then p.connect_neighbour(row[#row]) end
      if prev_row and #row == 0 then p.connect_neighbour(prev_row[1]) end
      row[#row + 1] = p
    end
    prev_row = row
  end
  energy_interface(s, gx - 1, gaps[1])
end

local function tick_levels(s, S, tick)
  local L = S.lv
  if not L then return end
  local call = function(fn, ...) return remote.call("factorio-overhaul", fn, ...) end
  local G, C, A = LV.by_key.gun, LV.by_key.command, LV.by_key.assembler
  if L.phase == 1 and tick == 300 then
    local g2 = at(s, LV.name(G, 2), L.ga.x, L.ga.y)
    check(g2 ~= nil, "niveaux : tourelle remplacee par le niveau 2 au meme endroit")
    if g2 then
      local ammo = g2.get_inventory(defines.inventory.turret_ammo).get_item_count("firearm-magazine")
      check(ammo == 25, "niveaux : munitions conservees", ammo .. " chargeurs")
      check(math.abs(g2.get_health_ratio() - 0.5) < 0.01, "niveaux : sante conservee en proportion",
        string.format("%.0f / %.0f PV", g2.health, g2.prototype.max_health))
      check(g2.active, "niveaux : tourelle niveau 2 en service")
    end
    local st = call("levels_status", "player")
    check(st.busy == 0 and st.upgrades == 1, "niveaux : ouvrier libere apres le chantier", "occupes " .. st.busy)
    local cc = at(s, "fo-command-center", L.cc_pos.x, L.cc_pos.y)
    local r = call("levels_upgrade", cc)
    check(r.ok and r.reason == "started", "niveaux : chantier du centre lance", tostring(r.reason))
    L.phase = 2
  elseif L.phase == 2 and tick == 600 then
    local cc = at(s, LV.name(C, 2), L.cc_pos.x, L.cc_pos.y)
    local st = call("levels_status", "player")
    check(cc ~= nil and st.cc_level == 2, "niveaux : centre de commandement niveau 2", "niveau " .. st.cc_level)
    if cc then
      local n = cc.get_inventory(defines.inventory.chest).get_item_count("iron-chest")
      check(n == L.chest_marker, "niveaux : le stock du centre suit le remplacement", n .. " coffres")
    end
    local am = at(s, "assembling-machine-2", L.am.x, L.am.y)
    local r = call("levels_upgrade", am)
    check(r.ok and r.reason == "started", "niveaux : chantier de la machine d'assemblage lance", tostring(r.reason))
    local gc = at(s, LV.name(G, 2), L.gc.x, L.gc.y)
    r = call("levels_upgrade", gc)
    check(not r.ok and r.reason == "no-builder", "niveaux : centre niveau 2 = toujours 1 ouvrier", tostring(r.reason))
    L.phase = 3
  elseif L.phase == 3 and tick == 900 then
    local am = at(s, LV.name(A, 2), L.am.x, L.am.y)
    check(am ~= nil, "niveaux : machine d'assemblage niveau 2")
    if am then
      local rec = am.get_recipe()
      check(rec and rec.name == "iron-gear-wheel", "niveaux : recette conservee", rec and rec.name or "aucune")
      local plates = am.get_inventory(defines.inventory.assembling_machine_input).get_item_count("iron-plate")
      local gears = am.get_inventory(defines.inventory.assembling_machine_output).get_item_count("iron-gear-wheel")
      check(plates + 2 * gears >= 38, "niveaux : contenu conserve (plaques et engrenages)", plates .. " plaques, " .. gears .. " engrenages")
    end
    local gc = at(s, LV.name(G, 2), L.gc.x, L.gc.y)
    local r = call("levels_upgrade", gc)
    check(r.ok and r.reason == "started", "niveaux : niveau 3 autorise avec un centre niveau 2", tostring(r.reason))
    L.phase = 4
  elseif L.phase == 4 and tick == 1500 then
    check(at(s, LV.name(G, 3), L.gc.x, L.gc.y) ~= nil, "niveaux : tourelle niveau 3")
    local st = call("levels_status", "player")
    check(st.fallback == 0, "niveaux : remplacement rapide du moteur (aucun secours manuel)", st.upgrades .. " chantiers, " .. st.instant .. " instantanes")
    L.phase = 5
  end
end

---------------------------------------------------------------------------------------------------
-- Monde : minerai dur, puits de méthane, carburant cristal, dangers de biome
---------------------------------------------------------------------------------------------------
local function ore_patch(s, name, cx, cy)
  for dx = -3, 3 do
    for dy = -3, 3 do s.create_entity({ name = name, position = { cx + dx, cy + dy }, amount = 5000 }) end
  end
end

local function setup_world(s, S)
  local x0, y = S.ox0, S.oy
  -- Tungstène : la foreuse électrique le mine, la foreuse à charbon non (minerai dur)
  ore_patch(s, "fo-tungsten-ore", x0, y)
  local ed = s.create_entity({ name = "electric-mining-drill", position = { x0 + 0.5, y + 0.5 }, force = "player", direction = defines.direction.north })
  S.ed_chest = s.create_entity({ name = "wooden-chest", position = ed.drop_position, force = "player" })
  ore_patch(s, "fo-tungsten-ore", x0 + 20, y)
  local bd = s.create_entity({ name = "burner-mining-drill", position = { x0 + 20, y }, force = "player", direction = defines.direction.north })
  bd.insert({ name = "coal", count = 20 })
  S.bd = bd
  S.bd_chest = s.create_entity({ name = "wooden-chest", position = bd.drop_position, force = "player" })
  -- Cristal de résonance : minable à la foreuse à charbon (minerai normal)
  ore_patch(s, "fo-resonance-crystal", x0 + 40, y + 20)
  local cd = s.create_entity({ name = "burner-mining-drill", position = { x0 + 40, y + 20 }, force = "player", direction = defines.direction.north })
  cd.insert({ name = "coal", count = 20 })
  S.cd_chest = s.create_entity({ name = "wooden-chest", position = cd.drop_position, force = "player" })
  -- Méthane : pompe sur un puits
  s.create_entity({ name = "fo-methane", position = { x0 + 40.5, y + 0.5 }, amount = 300000 })
  S.pump = s.create_entity({ name = "pumpjack", position = { x0 + 40.5, y + 0.5 }, force = "player" })
  -- Cristal : carburant de véhicule
  local car = s.create_entity({ name = "car", position = { x0 + 60, y }, force = "player" })
  local n = car.get_fuel_inventory().insert({ name = "fo-resonance-crystal", count = 10 })
  local proto = game.item_prototypes["fo-resonance-crystal"]
  local fuel = W.resources.crystal.fuel
  check(n == 10 and math.abs(proto.fuel_acceleration_multiplier - fuel.acceleration) < 0.01
    and math.abs(proto.fuel_top_speed_multiplier - fuel.top_speed) < 0.01,
    "cristal : carburant de vehicule", string.format("%d inseres, acceleration x%.2f, vitesse x%.2f",
      n, proto.fuel_acceleration_multiplier, proto.fuel_top_speed_multiplier))
  -- Dangers : un compagnon immobilisé sur le marais, un autre (blessé) sur la plaine de cristal
  local created = remote.call("factorio-overhaul", "companions_spawn", 2, 1)
  local comps = s.find_entities_filtered({ name = "fo-companion" })
  if created == 2 and #comps >= 2 then
    local spots = { { tile = "fo-toxic-marsh", x = x0 + 90 }, { tile = "fo-crystal-flats", x = x0 + 120 } }
    S.hazard = {}
    for i = 1, 2 do
      local tiles = {}
      for dx = -8, 8 do for dy = -8, 8 do tiles[#tiles + 1] = { name = spots[i].tile, position = { spots[i].x + dx, y + dy } } end end
      s.set_tiles(tiles)
      local c = comps[i]
      c.teleport({ spots[i].x, y })
      c.active = false
      if i == 2 then c.damage(150, "enemy", "physical") end
      S.hazard[i] = { entity = c, h0 = c.health, tile = spots[i].tile }
    end
  else
    fail("dangers de biome", "compagnons non crees (" .. tostring(created) .. ")")
  end
end

local function verify_world(S)
  local n = S.ed_chest.get_item_count("fo-tungsten-ore")
  check(n > 0, "tungstene : la foreuse electrique le mine", n .. " minerai(s)")
  n = S.bd_chest.get_item_count("fo-tungsten-ore")
  check(n == 0, "tungstene : la foreuse a charbon ne le mine pas", n .. " minerai(s), statut " .. tostring(S.bd.status))
  n = S.cd_chest.get_item_count("fo-resonance-crystal")
  check(n > 0, "cristal : minable a la foreuse a charbon", n .. " cristal(aux)")
  local m = S.pump.get_fluid_count("fo-methane")
  check(m > 0, "methane : extrait par une pompe", string.format("%.0f unites en %d s", m, CHECK_TICK / 60))
  if S.hazard then
    local marsh, crystal = S.hazard[1], S.hazard[2]
    if marsh.entity.valid then
      check(marsh.entity.health < marsh.h0, "marais toxique : empoisonne", string.format("%.0f -> %.0f PV", marsh.h0, marsh.entity.health))
    else
      ok("marais toxique : empoisonne", "compagnon mort du poison")
    end
    check(crystal.entity.valid and crystal.entity.health > crystal.h0, "plaine de cristal : soigne",
      crystal.entity.valid and string.format("%.0f -> %.0f PV", crystal.h0, crystal.entity.health) or "compagnon disparu")
  end
end

---------------------------------------------------------------------------------------------------
-- Orchestration
---------------------------------------------------------------------------------------------------
function T.start()
  local s = game.surfaces[1]
  local S = {}
  global.content = S
  game.forces.player.set_cease_fire("enemy", true)
  game.forces.enemy.set_cease_fire("player", true)
  local target_force = game.forces["fo-test-target"] or game.create_force("fo-test-target")
  game.forces.enemy.set_cease_fire(target_force, true)
  target_force.set_cease_fire("enemy", true)
  -- Allées alignées sur les sous-stations : machines aux positions base + 6k, sous-stations à base + 3 + 18j.
  S.rx0, S.ry0 = 304, -396           -- recettes (12 par rangée)
  S.mx0, S.my0 = 304, -306           -- modules (10 par rangée, 3 rangées)
  S.dx0, S.dy = 300, -160            -- duels (une ligne, 80 tuiles entre deux duels)
  S.ex0, S.ey0 = 300, -100           -- ennemis
  S.wx0, S.wy = 300, 60              -- murs
  S.ox0, S.oy = 340, 60              -- monde
  S.lx0, S.ly0 = 300, 120            -- niveaux : chantiers (session 5)
  S.gx0, S.gy0 = 300, 140            -- niveaux : galerie
  prepare_area(s, 290, -410, 390, -270)
  power_grid(s, 307, -393, 390, -270)
  prepare_area(s, 290, -180, 300 + (#DUELS + #HANDHELD) * 80, -140)
  prepare_area(s, 290, -110, 480, 40)
  prepare_area(s, 290, 40, 500, 100)
  power_grid(s, 299, 49, 500, 100)
  -- Niveaux : sol d'herbe (les socles de béton se verraient mal sur du béton).
  prepare_area(s, 290, 110, 400, 210, "grass-1")
  test_techs()
  setup_recipes(s, S)
  setup_modules(s, S)
  setup_duels(s, S)
  setup_enemies(s, S)
  test_walls(s, S)
  setup_world(s, S)
  setup_levels(s, S)
  Greffons.content_setup()
  log("[FO-CONTENT] installation terminee, verification a " .. CHECK_TICK .. " ticks")
end

function T.on_tick(e)
  local S = global.content
  if not S then return end
  if S.duels then tick_duels(S, e.tick) end
  local s = game.surfaces[1]
  tick_levels(s, S, e.tick)
  Greffons.content_tick(e)
  if e.tick == 5 then
    verify_enemy_deaths(s, S)
  elseif e.tick == CHECK_TICK then
    verify_modules(S)
    verify_recipes(S)
    verify_duels(S)
    verify_nest(s, S)
    verify_world(S)
    Greffons.content_verify()
    local r = R()
    log(string.format("[FO-CONTENT] BILAN : %d OK, %d ECHEC(S)%s", r.ok, r.fail,
      #r.failed > 0 and (" : " .. table.concat(r.failed, " | ")) or ""))
    global.content = nil
  end
end

return T
