--[[
  Scénario GREFFÉ « r3-galene » (lot AMELIO-RESSOURCES, 30/10) : la galène (âge 9), le plomb et la chaîne du thorium
  (âge 12) en moteur réel.

  Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui amelio-ressources -- 3300 r3-galene <source>
  (contrôle final au tick 3 100 : la recette du réacteur dure 60 s à la vitesse 1,25 de l'assembleur 3, 2 880 ticks)

  1. Prototypes (noms de X0) : galène (basic-solid, minage 1 s, produit fo-galena, finie), objets, réacteur, combustible ;
     recettes ouvertes par les 3 technologies.
  2. Les 2 GISEMENTS DE GALÈNE garantis (fo-monde, on_init) : à 300-600 tuiles, >= min_total chacun, SANS sol de biome
     posé, sans arbre sur le minerai ; aucune galène naturelle à moins de 280 tuiles du départ (masque de distance).
  3. Une foreuse électrique ET une foreuse à combustible minent la galène du site 1.
  4. Chaque recette dans SA machine, ingrédients mis PAR SCRIPT : plomb (four), blindage plombé (assembleur), grillage
     (four à arc, oxygène), cellule de sel au thorium (usine chimique), retraitement du sel usé (centrifugeuse), RÉACTEUR
     (assembleur 3).
  5. Le réacteur à sels fondus brûle une cellule et chauffe (160 MW).
]]

local MONDE = "fo-monde"

local CX, CY = 3600, 3740
local T_SITE, CHECK = 2, 3100

local function by_key(list, key)
  for _, d in ipairs(list or {}) do if d.key == key then return d end end
end
local function in_inv(e) return e.get_inventory(defines.inventory.assembling_machine_input) end
local function out_inv(e) return e.get_inventory(defines.inventory.assembling_machine_output) end

local CHAINE = {
  { k = "lead", machine = "electric-furnace", items = { { "fo-galena", 20 } } },
  { k = "shield", machine = "assembling-machine-2", recipe = "fo-lead-shielding", items = { { "fo-lead-plate", 9 }, { "steel-plate", 3 } } },
  { k = "roast", machine = "fo-arc-furnace", recipe = "fo-galena-roasting", items = { { "fo-galena", 12 } }, fluids = { { "fo-oxygen", 60 } } },
  { k = "cell", machine = "chemical-plant", recipe = "fo-thorium-salt-cell",
    items = { { "fo-thorium-oxide", 8 }, { "uranium-235", 2 } }, fluids = { { "fo-chlorine", 40 } } },
  { k = "repro", machine = "centrifuge", recipe = "fo-salt-reprocessing", items = { { "fo-spent-salt", 4 } } },
  { k = "reactor", machine = "assembling-machine-3", recipe = "fo-molten-salt-reactor",
    items = { { "fo-lead-shielding", 200 }, { "fo-titanium-plate", 10 }, { "processing-unit", 50 }, { "concrete", 100 } } },
}

return {
  description = "r3-galene : galene garantie loin du depart, plomb, blindage, grillage, chaine du thorium, reacteur a sels fondus",
  check_tick = CHECK,
  shots_delay = 300,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    local need = { { "entity", "fo-galena" }, { "item", "fo-galena" }, { "item", "fo-lead-plate" }, { "item", "fo-lead-shielding" },
      { "item", "fo-thorium-salt-cell" }, { "item", "fo-spent-salt" }, { "entity", "fo-molten-salt-reactor" },
      { "item", "fo-molten-salt-reactor" } }
    local miss = {}
    for _, n in ipairs(need) do
      local t = n[1] == "entity" and game.entity_prototypes or game.item_prototypes
      if not t[n[2]] then miss[#miss + 1] = n[2] end
    end
    ctx.check(#miss == 0, "prototypes du plomb et du thorium presents", #miss > 0 and table.concat(miss, ", ") or nil)
    local p = game.entity_prototypes["fo-galena"]
    ctx.check(p and p.resource_category == "basic-solid" and p.mineable_properties.products[1].name == "fo-galena"
      and p.mineable_properties.mining_time == 1 and not p.infinite_resource and game.autoplace_control_prototypes["fo-galena"] ~= nil,
      "galene : basic-solid, minage 1 s, produit fo-galena, gisement fini, reglage de carte")
    local cell = game.item_prototypes["fo-thorium-salt-cell"]
    ctx.check(cell and cell.fuel_category == "fo-thorium" and math.abs(cell.fuel_value - 32e9) < 1
      and cell.burnt_result and cell.burnt_result.name == "fo-spent-salt",
      "cellule de sel au thorium : 32 GJ, categorie fo-thorium, reste sel use", cell and cell.fuel_value)
    local rp = game.entity_prototypes["fo-molten-salt-reactor"]
    ctx.check(rp and rp.type == "reactor" and math.abs(rp.max_energy_usage * 60 - 160e6) < 1 and rp.neighbour_bonus == 0
      and rp.burner_prototype and rp.burner_prototype.fuel_categories["fo-thorium"],
      "reacteur a sels fondus : 160 MW, voisinage 0, brule fo-thorium", rp and rp.max_energy_usage * 60)
    local f = game.forces.player
    for _, t in ipairs({ "fo-titanium-processing", "fo-cryostat", "fo-superconductors", "fo-lead-processing", "fo-galena-roasting", "fo-thorium" }) do
      f.technologies[t].researched = true
    end
    local closed = {}
    for _, r in ipairs({ "fo-lead-plate", "fo-lead-shielding", "fo-galena-roasting", "fo-thorium-salt-cell", "fo-salt-reprocessing",
      "fo-molten-salt-reactor" }) do
      if not (f.recipes[r] and f.recipes[r].enabled) then closed[#closed + 1] = r end
    end
    ctx.check(#closed == 0, "technologies plomb, grillage, thorium : 6 recettes ouvertes", #closed > 0 and table.concat(closed, ", ") or nil)

    ctx.prepare_area(CX - 50, CY - 20, CX + 50, CY + 30, "grass-1")
    for _, e in ipairs(s.find_entities_filtered({ area = { { CX - 150, CY - 150 }, { CX + 150, CY + 150 } }, force = "enemy" })) do e.destroy() end
    st.m = {}
    local placed, bad = 0, {}
    for i, c in ipairs(CHAINE) do
      local e = s.create_entity({ name = c.machine, position = { CX - 30 + (i - 1) * 9 + 0.5, CY + 0.5 }, force = "player", raise_built = true })
      if e then
        if c.recipe then e.set_recipe(c.recipe) end
        local inv = c.recipe and in_inv(e) or e.get_inventory(defines.inventory.furnace_source)
        for _, it in ipairs(c.items or {}) do inv.insert({ name = it[1], count = it[2] }) end
        for _, fl in ipairs(c.fluids or {}) do e.insert_fluid({ name = fl[1], amount = fl[2] }) end
        st.m[c.k] = e
        if (not c.recipe) or (e.get_recipe() and e.get_recipe().name == c.recipe) then placed = placed + 1 else bad[#bad + 1] = c.k end
      else
        bad[#bad + 1] = c.k
      end
    end
    ctx.check(placed == #CHAINE, "6 machines posees avec leur recette (ingredients mis par script)", #bad > 0 and table.concat(bad, ", ") or nil)
    ctx.power(CX - 8, CY + 8)
    st.reactor = s.create_entity({ name = "fo-molten-salt-reactor", position = { CX + 30, CY + 20 }, force = "player", raise_built = true })
    if st.reactor then st.reactor.insert({ name = "fo-thorium-salt-cell", count = 1 }) end
    ctx.check(st.reactor ~= nil, "reacteur a sels fondus pose, une cellule chargee")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick ~= T_SITE then return end
    local spec = by_key(ctx.remote(MONDE, "specs"), "galena")
    local d = by_key(ctx.remote(MONDE, "status").done, "galena")
    local sites = d and d.sites or {}
    ctx.check(spec and d and d.ok and d.phase == "init" and #sites == 2, "2 gisements de galene garantis poses a on_init (fo-monde)",
      #sites > 0 and string.format("(%d, %d) a %.1f ; %s", sites[1].x, sites[1].y, sites[1].dist,
        sites[2] and string.format("(%d, %d) a %.1f", sites[2].x, sites[2].y, sites[2].dist) or "pas de 2e") or "absent")
    if not (spec and #sites == 2) then return end
    st.sites = { { x = sites[1].x, y = sites[1].y }, { x = sites[2].x, y = sites[2].y } }
    local bad, trees, total, posed, n_ent = {}, 0, 0, 0, 0
    local names, order = {}, {}
    for i, site in ipairs(sites) do
      posed = posed + (site.tiles or 0) - (site.filled or 0)
      n_ent = n_ent + site.entities
      local c = { site.x + 0.5, site.y + 0.5 }
      local ore = s.find_entities_filtered({ name = "fo-galena", position = c, radius = spec.core_radius + 1.5 })
      local amt = 0
      for _, r in ipairs(ore) do
        amt = amt + r.amount
        local tn = s.get_tile(math.floor(r.position.x), math.floor(r.position.y)).name
        if not names[tn] then names[tn] = 0; order[#order + 1] = tn end
        names[tn] = names[tn] + 1
      end
      total = total + amt
      if not (#ore == site.entities and amt == site.total and amt >= spec.min_total and site.dist >= spec.dmin and site.dist <= spec.dmax) then
        bad[#bad + 1] = string.format("site %d : %d entites, %d, distance %.1f", i, #ore, amt, site.dist)
      end
      trees = trees + s.count_entities_filtered({ position = c, radius = spec.core_radius, type = { "tree", "simple-entity" } })
    end
    ctx.check(#bad == 0, "2 gisements complets (>= min_total chacun) a 300-600 tuiles",
      #bad > 0 and table.concat(bad, " ; ") or string.format("%d galenes en tout", total))
    -- 1er banc (30/10, 0 h 10) : 298 tuiles « fo-* » sous le minerai, mais ce sont les biomes NATURELS du lieu (la garantie
    -- n'en pose aucun) : le contrôle juste est le rapport de la garantie (tuiles posées hors eau comblée = 0).
    table.sort(order)
    local parts = {}
    for _, tn in ipairs(order) do parts[#parts + 1] = tn .. " " .. names[tn] end
    ctx.check(posed == 0, "aucun sol pose par la garantie sous la galene (ressource sans biome ; sol naturel garde)",
      posed .. " ; sols sous le minerai : " .. table.concat(parts, ", "))
    ctx.check(trees == 0, "aucun arbre ni rocher sur le minerai", trees)
    local spawn = game.forces.player.get_spawn_position(s)
    local nearby = s.count_entities_filtered({ name = "fo-galena", position = spawn, radius = 280 })
    local natural = s.count_entities_filtered({ name = "fo-galena" }) - n_ent
    ctx.check(nearby == 0, "aucune galene a moins de 280 tuiles du depart (masque de distance de l'autoplace)",
      string.format("%d ; galene naturelle generee ailleurs : %d tuiles", nearby, natural))
    local c1 = sites[1]
    ctx.power(c1.x, c1.y)
    st.ed = s.create_entity({ name = "electric-mining-drill", position = { c1.x - 2.5, c1.y + 0.5 }, force = "player", direction = defines.direction.north })
    st.bd = s.create_entity({ name = "burner-mining-drill", position = { c1.x + 3, c1.y + 1 }, force = "player", direction = defines.direction.north })
    if st.ed then st.ed_chest = s.create_entity({ name = "iron-chest", position = st.ed.drop_position, force = "player" }) end
    if st.bd then
      st.bd_chest = s.create_entity({ name = "iron-chest", position = st.bd.drop_position, force = "player" })
      st.bd.insert({ name = "coal", count = 20 })
    end
    ctx.check(st.ed and st.bd and st.ed_chest and st.bd_chest, "foreuse electrique et foreuse a combustible posees sur la galene")
  end,

  finish = function(ctx)
    local st = ctx.state()
    local m = st.m or {}
    local ed = st.ed_chest and st.ed_chest.valid and st.ed_chest.get_item_count("fo-galena") or 0
    local bd = st.bd_chest and st.bd_chest.valid and st.bd_chest.get_item_count("fo-galena") or 0
    ctx.check(ed >= 4, "la foreuse electrique mine la galene du site garanti", ed .. " minerais")
    ctx.check(bd >= 1, "la foreuse a combustible la mine aussi (basic-solid)", bd .. " minerais")
    local lead = m.lead and m.lead.valid and m.lead.get_inventory(defines.inventory.furnace_result).get_item_count("fo-lead-plate") or 0
    ctx.check(lead >= 3, "four electrique : la galene donne la plaque de plomb (recette de four)", lead)
    local function done(k) return m[k] and m[k].valid and m[k].products_finished or 0 end
    ctx.check(done("shield") >= 2, "assembleur : blindage plombe (3 plombs + 1 acier)", done("shield"))
    ctx.check(done("roast") >= 2 and out_inv(m.roast).get_item_count("sulfur") >= 2,
      "four a arc : grillage de la galene a l'oxygene -> plomb + soufre", done("roast"))
    ctx.check(done("cell") >= 1, "usine chimique : cellule de sel au thorium (oxyde de thorium, U-235, chlore)", done("cell"))
    ctx.check(done("repro") >= 1 and out_inv(m.repro).get_item_count("fo-thorium-oxide") >= 1,
      "centrifugeuse : retraitement du sel use -> oxyde de thorium + U-238", done("repro"))
    ctx.check(done("reactor") >= 1, "assembleur 3 : REACTEUR A SELS FONDUS (200 blindages plombes)", done("reactor"))
    local r = st.reactor
    local burning = r and r.valid and r.burner and r.burner.currently_burning
    local temp = r and r.valid and r.temperature or 0
    ctx.check(burning and burning.name == "fo-thorium-salt-cell" and temp > 100,
      "le reacteur brule la cellule et chauffe", string.format("%.0f degres", temp))
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local opt = { aa = false }
    if st.sites then
      add("galene-garantie-z05-jour", st.sites[1].x + 0.5, st.sites[1].y + 0.5, 0.5, 0, opt)
      add("galene-garantie-z1-jour", st.sites[1].x + 0.5, st.sites[1].y + 0.5, 1, 0, opt)
      add("galene-garantie-z2-jour", st.sites[1].x + 0.5, st.sites[1].y + 0.5, 2, 0, opt)
      add("galene-garantie-z1-nuit", st.sites[1].x + 0.5, st.sites[1].y + 0.5, 1, 0.5, opt)
    end
    add("chaine-z1-jour", CX, CY + 4, 1, 0, opt)
    add("reacteur-z2-jour", CX + 30, CY + 20, 2, 0, opt)
  end,
}
