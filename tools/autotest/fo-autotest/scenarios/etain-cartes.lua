--[[
  Scénario GREFFÉ « etain-cartes » (lot AMELIO-RESSOURCES, piste ÉTAIN, 30/10) : la cassitérite et la carte imprimée
  (chaîne A d'X3, âge 4) en moteur réel. Lancement :
    py -3.9 -B tools/autotest/banc.py --out <archive> --qui amelio-ressources -- 1500 etain-cartes <source>
  1. Prototypes : cassitérite (basic-solid, minage 1 s, produit fo-cassiterite), objets, résine, imprimante ; technologie.
  2. Les 2 gisements garantis à 120-350 tuiles (fo-monde, on_init), sans sol posé, sans arbre.
  3. Foreuses électrique et à combustible sur la cassitérite.
  4. Chaque recette dans SA machine, ingrédients par script : étain (four), résine (usine chimique : éthylène, huile
     lourde), stratifié (usine chimique), carte (imprimante, acide sulfurique), circuit avancé sur carte (assembleur).
]]

local MONDE = "fo-monde"
local CX, CY = 3600, 3740
local T_SITE, CHECK = 2, 1400

local function by_key(list, key)
  for _, d in ipairs(list or {}) do if d.key == key then return d end end
end
local function in_inv(e) return e.get_inventory(defines.inventory.assembling_machine_input) end

local CHAINE = {
  { k = "tin", machine = "electric-furnace", items = { { "fo-cassiterite", 20 } } },
  { k = "epoxy", machine = "chemical-plant", recipe = "fo-epoxy-resin", fluids = { { "fo-ethylene", 100 }, { "heavy-oil", 50 } } },
  { k = "lam", machine = "chemical-plant", recipe = "fo-copper-clad-laminate", items = { { "copper-plate", 8 }, { "fo-glass", 4 } },
    fluids = { { "fo-epoxy-resin", 100 } } },
  { k = "pcb", machine = "fo-circuit-printer", recipe = "fo-printed-circuit-board", items = { { "fo-copper-clad-laminate", 4 }, { "fo-tin-plate", 4 } },
    fluids = { { "sulfuric-acid", 40 } } },
  { k = "adv", machine = "assembling-machine-2", recipe = "fo-pcb-advanced-circuit",
    items = { { "fo-printed-circuit-board", 3 }, { "electronic-circuit", 12 }, { "plastic-bar", 12 }, { "copper-cable", 6 } } },
}

return {
  description = "etain-cartes : cassiterite garantie, etain, resine, stratifie, carte imprimee, circuit avance sur carte",
  check_tick = CHECK,
  shots_delay = 200,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    local miss = {}
    for _, n in ipairs({ "fo-cassiterite", "fo-tin-plate", "fo-copper-clad-laminate", "fo-printed-circuit-board", "fo-circuit-printer" }) do
      if not game.item_prototypes[n] then miss[#miss + 1] = n end
    end
    if not game.fluid_prototypes["fo-epoxy-resin"] then miss[#miss + 1] = "fo-epoxy-resin" end
    if not game.entity_prototypes["fo-cassiterite"] then miss[#miss + 1] = "entite fo-cassiterite" end
    ctx.check(#miss == 0, "prototypes de l'etain presents", #miss > 0 and table.concat(miss, ", ") or nil)
    local p = game.entity_prototypes["fo-cassiterite"]
    ctx.check(p and p.resource_category == "basic-solid" and p.mineable_properties.products[1].name == "fo-cassiterite"
      and p.mineable_properties.mining_time == 1 and game.autoplace_control_prototypes["fo-cassiterite"] ~= nil,
      "cassiterite : basic-solid, minage 1 s, produit fo-cassiterite, reglage de carte")
    local f = game.forces.player
    for _, t in ipairs({ "fo-glassworks", "fo-flaring", "fo-steam-cracking", "fo-printed-circuits" }) do
      if f.technologies[t] then f.technologies[t].researched = true end
    end
    local closed = {}
    for _, r in ipairs({ "fo-tin-plate", "fo-epoxy-resin", "fo-copper-clad-laminate", "fo-circuit-printer", "fo-printed-circuit-board",
      "fo-pcb-advanced-circuit" }) do
      if not (f.recipes[r] and f.recipes[r].enabled) then closed[#closed + 1] = r end
    end
    ctx.check(#closed == 0, "technologie Circuits imprimes : 6 recettes ouvertes", #closed > 0 and table.concat(closed, ", ") or nil)
    ctx.check(f.recipes["advanced-circuit"] ~= nil and #f.recipes["advanced-circuit"].ingredients == 3,
      "la recette vanilla du circuit avance est intacte (variante a cote)")

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
    ctx.check(placed == #CHAINE, "5 machines posees avec leur recette", #bad > 0 and table.concat(bad, ", ") or nil)
    ctx.power(CX - 8, CY + 8)
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick ~= T_SITE then return end
    local spec = by_key(ctx.remote(MONDE, "specs"), "cassiterite")
    local d = by_key(ctx.remote(MONDE, "status").done, "cassiterite")
    local sites = d and d.sites or {}
    ctx.check(spec and d and d.ok and d.phase == "init" and #sites == 2, "2 gisements de cassiterite garantis poses a on_init",
      #sites > 0 and string.format("(%d, %d) a %.1f", sites[1].x, sites[1].y, sites[1].dist) or "absent")
    if not (spec and #sites == 2) then return end
    local bad, posed, trees = {}, 0, 0
    for i, site in ipairs(sites) do
      posed = posed + (site.tiles or 0) - (site.filled or 0)
      local ore = s.find_entities_filtered({ name = "fo-cassiterite", position = { site.x + 0.5, site.y + 0.5 }, radius = spec.core_radius + 1.5 })
      local amt = 0
      for _, r in ipairs(ore) do amt = amt + r.amount end
      if not (#ore == site.entities and amt >= spec.min_total and site.dist >= spec.dmin and site.dist <= spec.dmax) then
        bad[#bad + 1] = string.format("site %d : %d entites, %d, %.1f", i, #ore, amt, site.dist)
      end
      trees = trees + s.count_entities_filtered({ position = { site.x + 0.5, site.y + 0.5 }, radius = spec.core_radius, type = { "tree", "simple-entity" } })
    end
    ctx.check(#bad == 0 and posed == 0 and trees == 0, "2 gisements complets a 120-350 tuiles, aucun sol pose, aucun arbre",
      #bad > 0 and table.concat(bad, " ; ") or string.format("sol pose %d, arbres %d", posed, trees))
    local c1 = sites[1]
    ctx.power(c1.x, c1.y)
    st.ed = s.create_entity({ name = "electric-mining-drill", position = { c1.x - 2.5, c1.y + 0.5 }, force = "player", direction = defines.direction.north })
    st.bd = s.create_entity({ name = "burner-mining-drill", position = { c1.x + 3, c1.y + 1 }, force = "player", direction = defines.direction.north })
    if st.ed then st.ed_chest = s.create_entity({ name = "iron-chest", position = st.ed.drop_position, force = "player" }) end
    if st.bd then
      st.bd_chest = s.create_entity({ name = "iron-chest", position = st.bd.drop_position, force = "player" })
      st.bd.insert({ name = "coal", count = 20 })
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local m = st.m or {}
    local ed = st.ed_chest and st.ed_chest.valid and st.ed_chest.get_item_count("fo-cassiterite") or 0
    local bd = st.bd_chest and st.bd_chest.valid and st.bd_chest.get_item_count("fo-cassiterite") or 0
    ctx.check(ed >= 4 and bd >= 1, "foreuses electrique et a combustible : cassiterite minee", ed .. " et " .. bd)
    local tin = m.tin and m.tin.valid and m.tin.get_inventory(defines.inventory.furnace_result).get_item_count("fo-tin-plate") or 0
    ctx.check(tin >= 3, "four electrique : plaque d'etain", tin)
    local function done(k) return m[k] and m[k].valid and m[k].products_finished or 0 end
    ctx.check(done("epoxy") >= 2, "usine chimique : resine epoxy (ethylene, huile lourde)", done("epoxy"))
    ctx.check(done("lam") >= 2, "usine chimique : stratifie cuivre (cuivre, verre, resine)", done("lam"))
    ctx.check(done("pcb") >= 2, "imprimante de circuits : carte imprimee (stratifie, etain, acide)", done("pcb"))
    ctx.check(done("adv") >= 2, "assembleur : circuit avance sur carte imprimee (variante)", done("adv"))
  end,

  shots = function(ctx, add)
    add("chaine-etain-z1-jour", CX, CY + 4, 1, 0, { aa = false })
  end,
}
