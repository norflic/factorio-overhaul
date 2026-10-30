--[[
  Scénario GREFFÉ « zinc-laiton » (lot AMELIO-RESSOURCES, piste ZINC, 30/10) : la blende et le laiton (X3, âge 3) en
  moteur réel. Lancement :
    py -3.9 -B tools/autotest/banc.py --out <archive> --qui amelio-ressources -- 1500 zinc-laiton <source>
  1. Prototypes : blende (basic-solid, minage 1 s, produit fo-sphalerite), zinc, laiton ; la verrerie débloque les 3 recettes.
  2. Les 2 gisements garantis à 150-400 tuiles (fo-monde, on_init), sans sol posé, sans arbre.
  3. Foreuse électrique sur la blende.
  4. Cornue à zinc (four à coke, combustible), laiton (haut fourneau, combustible), manomètre à tube de Bourdon (assembleur).
]]

local MONDE = "fo-monde"
local CX, CY = 3600, -3740
local T_SITE, CHECK = 2, 1400

local function by_key(list, key)
  for _, d in ipairs(list or {}) do if d.key == key then return d end end
end
local function in_inv(e) return e.get_inventory(defines.inventory.assembling_machine_input) end
local function out_count(e, n) return e.get_inventory(defines.inventory.assembling_machine_output).get_item_count(n) end

local CHAINE = {
  { k = "zinc", machine = "fo-coke-oven", recipe = "fo-zinc-retort", items = { { "fo-sphalerite", 16 }, { "coal", 4 } } },
  { k = "brass", machine = "fo-blast-furnace", recipe = "fo-brass", items = { { "copper-plate", 8 }, { "fo-zinc-plate", 4 } } },
  { k = "mano", machine = "assembling-machine-2", recipe = "fo-manometer-brass",
    items = { { "fo-glass", 8 }, { "iron-gear-wheel", 8 }, { "fo-brass", 4 } } },
}

return {
  description = "zinc-laiton : blende garantie, cornue a zinc, laiton, manometre a tube de Bourdon",
  check_tick = CHECK,
  shots_delay = 200,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    local miss = {}
    for _, n in ipairs({ "fo-sphalerite", "fo-zinc-plate", "fo-brass" }) do
      if not game.item_prototypes[n] then miss[#miss + 1] = n end
    end
    if not game.entity_prototypes["fo-sphalerite"] then miss[#miss + 1] = "entite fo-sphalerite" end
    ctx.check(#miss == 0, "prototypes du zinc presents", #miss > 0 and table.concat(miss, ", ") or nil)
    local p = game.entity_prototypes["fo-sphalerite"]
    ctx.check(p and p.resource_category == "basic-solid" and p.mineable_properties.products[1].name == "fo-sphalerite"
      and p.mineable_properties.mining_time == 1 and game.autoplace_control_prototypes["fo-sphalerite"] ~= nil,
      "blende : basic-solid, minage 1 s, produit fo-sphalerite, reglage de carte")
    local f = game.forces.player
    for _, t in ipairs({ "fo-coking", "fo-blast-furnace", "fo-crushing", "fo-glassworks" }) do
      if f.technologies[t] then f.technologies[t].researched = true end
    end
    local closed = {}
    for _, r in ipairs({ "fo-zinc-retort", "fo-brass", "fo-manometer-brass", "fo-manometer" }) do
      if not (f.recipes[r] and f.recipes[r].enabled) then closed[#closed + 1] = r end
    end
    ctx.check(#closed == 0, "verrerie : cornue, laiton, manometre a tube de Bourdon (et manometre d'X0) ouverts",
      #closed > 0 and table.concat(closed, ", ") or nil)

    ctx.prepare_area(CX - 50, CY - 20, CX + 80, CY + 30, "grass-1")
    for _, e in ipairs(s.find_entities_filtered({ area = { { CX - 150, CY - 150 }, { CX + 150, CY + 150 } }, force = "enemy" })) do e.destroy() end
    st.m = {}
    local placed, bad = 0, {}
    for i, ch in ipairs(CHAINE) do
      local e = s.create_entity({ name = ch.machine, position = { CX - 30 + (i - 1) * 9, CY }, force = "player", raise_built = true })
      if e then
        e.set_recipe(ch.recipe)
        local inv = in_inv(e)
        for _, it in ipairs(ch.items or {}) do inv.insert({ name = it[1], count = it[2] }) end
        for _, fl in ipairs(ch.fluids or {}) do e.insert_fluid({ name = fl[1], amount = fl[2] }) end
        -- le concasseur d'X0 brûle du combustible (BURN) : charbon dans son foyer
        local fuel = e.get_fuel_inventory()
        if fuel then fuel.insert({ name = "coal", count = 20 }) end
        st.m[ch.k] = e
        if e.get_recipe() and e.get_recipe().name == ch.recipe then placed = placed + 1 else bad[#bad + 1] = ch.k end
      else
        bad[#bad + 1] = ch.k
      end
    end
    ctx.check(placed == #CHAINE, "3 machines posees avec leur recette", #bad > 0 and table.concat(bad, ", ") or nil)
    ctx.power(CX - 12, CY + 8)
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick ~= T_SITE then return end
    local spec = by_key(ctx.remote(MONDE, "specs"), "sphalerite")
    local d = by_key(ctx.remote(MONDE, "status").done, "sphalerite")
    local sites = d and d.sites or {}
    ctx.check(spec and d and d.ok and d.phase == "init" and #sites == 2, "2 gisements de blende garantis poses a on_init",
      #sites > 0 and string.format("(%d, %d) a %.1f", sites[1].x, sites[1].y, sites[1].dist) or "absent")
    if not (spec and #sites == 2) then return end
    local bad, posed, trees = {}, 0, 0
    for i, site in ipairs(sites) do
      posed = posed + (site.tiles or 0) - (site.filled or 0)
      local ore = s.find_entities_filtered({ name = "fo-sphalerite", position = { site.x + 0.5, site.y + 0.5 }, radius = spec.core_radius + 1.5 })
      local amt = 0
      for _, r in ipairs(ore) do amt = amt + r.amount end
      if not (#ore == site.entities and amt >= spec.min_total and site.dist >= spec.dmin and site.dist <= spec.dmax) then
        bad[#bad + 1] = string.format("site %d : %d entites, %d, %.1f", i, #ore, amt, site.dist)
      end
      trees = trees + s.count_entities_filtered({ position = { site.x + 0.5, site.y + 0.5 }, radius = spec.core_radius, type = { "tree", "simple-entity" } })
    end
    ctx.check(#bad == 0 and posed == 0 and trees == 0, "2 gisements complets a 150-400 tuiles, aucun sol pose, aucun arbre",
      #bad > 0 and table.concat(bad, " ; ") or string.format("sol pose %d, arbres %d", posed, trees))
    local c1 = sites[1]
    ctx.power(c1.x, c1.y)
    st.ed = s.create_entity({ name = "electric-mining-drill", position = { c1.x - 2.5, c1.y + 0.5 }, force = "player", direction = defines.direction.north })
    if st.ed then st.ed_chest = s.create_entity({ name = "iron-chest", position = st.ed.drop_position, force = "player" }) end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local m = st.m or {}
    local ed = st.ed_chest and st.ed_chest.valid and st.ed_chest.get_item_count("fo-sphalerite") or 0
    ctx.check(ed >= 4, "foreuse electrique : blende minee", ed)
    local function done(k) return m[k] and m[k].valid and m[k].products_finished or 0 end
    ctx.check(done("zinc") >= 2 and out_count(m.zinc, "fo-zinc-plate") >= 4 and out_count(m.zinc, "fo-slag") >= 2,
      "four a coke : cornue a zinc (zinc et laitier)", done("zinc"))
    ctx.check(done("brass") >= 2 and out_count(m.brass, "fo-brass") >= 6, "haut fourneau : laiton", done("brass"))
    ctx.check(done("mano") >= 2 and out_count(m.mano, "fo-manometer") >= 4, "assembleur : manometre a tube de Bourdon (2 par laiton)", done("mano"))
  end,

  shots = function(ctx, add)
    add("chaine-zinc-z1-jour", CX - 12, CY + 4, 1, 0, { aa = false })
  end,
}
