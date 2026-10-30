--[[
  Scénario GREFFÉ « bauxite-alu » (lot AMELIO-RESSOURCES, piste BAUXITE, 30/10) : la bauxite et l'aluminium (chaîne C
  d'X3, âge 6) et le pylône haute tension (X0) en moteur réel. Lancement :
    py -3.9 -B tools/autotest/banc.py --out <archive> --qui amelio-ressources -- 1500 bauxite-alu <source>
  1. Prototypes : bauxite (basic-solid, minage 1 s, produit fo-bauxite), objets, cuve, pylône ; technologies.
  2. Les 3 gisements garantis à 300-600 tuiles (fo-monde, on_init), sans sol posé, sans arbre.
  3. Foreuse électrique sur la bauxite.
  4. Chaque recette dans SA machine, ingrédients par script : alumine (usine chimique : bauxite, pierre, eau), ciment de
     boue rouge (concasseur), fer de la boue rouge (four à arc), aluminium (cuve), pylône aluminium-acier (assembleur).
  5. Pylône : fil de 64 tuiles (deux pylônes à 60 se relient, à 70 non).
]]

local MONDE = "fo-monde"
local CX, CY = -3600, 3740
local T_SITE, CHECK = 2, 1400

local function by_key(list, key)
  for _, d in ipairs(list or {}) do if d.key == key then return d end end
end
local function in_inv(e) return e.get_inventory(defines.inventory.assembling_machine_input) end
local function out_count(e, n) return e.get_inventory(defines.inventory.assembling_machine_output).get_item_count(n) end

local CHAINE = {
  { k = "sinter", machine = "chemical-plant", recipe = "fo-lime-sinter-alumina", items = { { "fo-bauxite", 20 }, { "stone", 4 } },
    fluids = { { "water", 100 } } },
  { k = "cement", machine = "fo-crusher", recipe = "fo-red-mud-cement", items = { { "fo-red-mud", 6 }, { "stone", 3 } } },
  { k = "iron", machine = "fo-arc-furnace", recipe = "fo-red-mud-iron", items = { { "fo-red-mud", 12 }, { "fo-graphite", 3 } } },
  { k = "alu", machine = "fo-reduction-cell", recipe = "fo-hall-heroult", items = { { "fo-alumina", 12 }, { "fo-graphite", 3 } } },
  { k = "pylon", machine = "assembling-machine-2", recipe = "fo-ht-pylon-aluminium",
    items = { { "steel-plate", 12 }, { "fo-aluminium-plate", 4 }, { "fo-coil", 4 } } },
}

return {
  description = "bauxite-alu : bauxite garantie, alumine, boue rouge (ciment, fer), aluminium, pylone haute tension",
  check_tick = CHECK,
  shots_delay = 200,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    local miss = {}
    for _, n in ipairs({ "fo-bauxite", "fo-alumina", "fo-red-mud", "fo-aluminium-plate", "fo-reduction-cell", "fo-ht-pylon" }) do
      if not game.item_prototypes[n] then miss[#miss + 1] = n end
    end
    for _, n in ipairs({ "fo-bauxite", "fo-reduction-cell", "fo-ht-pylon" }) do
      if not game.entity_prototypes[n] then miss[#miss + 1] = "entite " .. n end
    end
    ctx.check(#miss == 0, "prototypes de l'aluminium presents", #miss > 0 and table.concat(miss, ", ") or nil)
    local p = game.entity_prototypes["fo-bauxite"]
    ctx.check(p and p.resource_category == "basic-solid" and p.mineable_properties.products[1].name == "fo-bauxite"
      and p.mineable_properties.mining_time == 1 and game.autoplace_control_prototypes["fo-bauxite"] ~= nil,
      "bauxite : basic-solid, minage 1 s, produit fo-bauxite, reglage de carte")
    local c = game.entity_prototypes["fo-reduction-cell"]
    ctx.check(c and c.crafting_categories["fo-fused-salt-electrolysis"] and math.abs(c.max_energy_usage * 60 - 6e6) < 1
      and math.abs(c.collision_box.right_bottom.x - 1.7) < 0.01,
      "cuve : electrolyse ignee, 6 MW, 4 x 4", c and string.format("%.0f W", c.max_energy_usage * 60) or "absente")
    local py = game.entity_prototypes["fo-ht-pylon"]
    ctx.check(py and py.max_wire_distance == 64 and py.supply_area_distance == 0.5, "pylone : fil de 64, alimentation 0,5",
      py and (py.max_wire_distance .. " / " .. py.supply_area_distance) or "absent")
    local f = game.forces.player
    for _, t in ipairs({ "fo-coking", "fo-crushing", "fo-arc-smelting", "fo-electrical-steel", "fo-high-voltage", "fo-aluminium" }) do
      if f.technologies[t] then f.technologies[t].researched = true end
    end
    local closed = {}
    for _, r in ipairs({ "fo-ht-pylon", "fo-reduction-cell", "fo-lime-sinter-alumina", "fo-red-mud-cement", "fo-red-mud-iron",
      "fo-hall-heroult", "fo-ht-pylon-aluminium" }) do
      if not (f.recipes[r] and f.recipes[r].enabled) then closed[#closed + 1] = r end
    end
    ctx.check(#closed == 0, "technologies Haute tension et Aluminium : 7 recettes ouvertes", #closed > 0 and table.concat(closed, ", ") or nil)

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
        st.m[ch.k] = e
        if e.get_recipe() and e.get_recipe().name == ch.recipe then placed = placed + 1 else bad[#bad + 1] = ch.k end
      else
        bad[#bad + 1] = ch.k
      end
    end
    ctx.check(placed == #CHAINE, "5 machines posees avec leur recette", #bad > 0 and table.concat(bad, ", ") or nil)
    ctx.power(CX - 12, CY + 8)
    -- Pylônes : à 60 tuiles ils se relient (fil de 64), à 70 non.
    local a = s.create_entity({ name = "fo-ht-pylon", position = { CX + 20, CY + 20 }, force = "player" })
    local b = s.create_entity({ name = "fo-ht-pylon", position = { CX + 80, CY + 20 }, force = "player" })
    local c2 = s.create_entity({ name = "fo-ht-pylon", position = { CX + 20, CY - 50 }, force = "player" })
    local ok60 = a and b and (a.connect_neighbour(b) or #a.neighbours.copper > 0)
    local ok70 = a and c2 and a.connect_neighbour(c2)
    ctx.check(ok60 and not ok70, "pylones : relies a 60 tuiles, pas a 70", tostring(ok60) .. " / " .. tostring(ok70))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick ~= T_SITE then return end
    local spec = by_key(ctx.remote(MONDE, "specs"), "bauxite")
    local d = by_key(ctx.remote(MONDE, "status").done, "bauxite")
    local sites = d and d.sites or {}
    ctx.check(spec and d and d.ok and d.phase == "init" and #sites == 3, "3 gisements de bauxite garantis poses a on_init",
      #sites > 0 and string.format("(%d, %d) a %.1f", sites[1].x, sites[1].y, sites[1].dist) or "absent")
    if not (spec and #sites == 3) then return end
    local bad, posed, trees = {}, 0, 0
    for i, site in ipairs(sites) do
      posed = posed + (site.tiles or 0) - (site.filled or 0)
      local ore = s.find_entities_filtered({ name = "fo-bauxite", position = { site.x + 0.5, site.y + 0.5 }, radius = spec.core_radius + 1.5 })
      local amt = 0
      for _, r in ipairs(ore) do amt = amt + r.amount end
      if not (#ore == site.entities and amt >= spec.min_total and site.dist >= spec.dmin and site.dist <= spec.dmax) then
        bad[#bad + 1] = string.format("site %d : %d entites, %d, %.1f", i, #ore, amt, site.dist)
      end
      trees = trees + s.count_entities_filtered({ position = { site.x + 0.5, site.y + 0.5 }, radius = spec.core_radius, type = { "tree", "simple-entity" } })
    end
    ctx.check(#bad == 0 and posed == 0 and trees == 0, "3 gisements complets a 300-600 tuiles, aucun sol pose, aucun arbre",
      #bad > 0 and table.concat(bad, " ; ") or string.format("sol pose %d, arbres %d", posed, trees))
    local c1 = sites[1]
    ctx.power(c1.x, c1.y)
    st.ed = s.create_entity({ name = "electric-mining-drill", position = { c1.x - 2.5, c1.y + 0.5 }, force = "player", direction = defines.direction.north })
    if st.ed then st.ed_chest = s.create_entity({ name = "iron-chest", position = st.ed.drop_position, force = "player" }) end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local m = st.m or {}
    local ed = st.ed_chest and st.ed_chest.valid and st.ed_chest.get_item_count("fo-bauxite") or 0
    ctx.check(ed >= 4, "foreuse electrique : bauxite minee", ed)
    local function done(k) return m[k] and m[k].valid and m[k].products_finished or 0 end
    ctx.check(done("sinter") >= 2 and out_count(m.sinter, "fo-alumina") >= 4 and out_count(m.sinter, "fo-red-mud") >= 4,
      "usine chimique : alumine et boue rouge (bauxite, pierre, eau)", done("sinter"))
    ctx.check(done("cement") >= 2 and out_count(m.cement, "fo-cement") >= 4, "concasseur : ciment de boue rouge", done("cement"))
    ctx.check(done("iron") >= 2 and out_count(m.iron, "iron-plate") >= 4 and out_count(m.iron, "fo-slag") >= 2,
      "four a arc : fer et laitier de la boue rouge", done("iron"))
    ctx.check(done("alu") >= 2 and out_count(m.alu, "fo-aluminium-plate") >= 4, "cuve d'electrolyse ignee : plaques d'aluminium", done("alu"))
    ctx.check(done("pylon") >= 2 and out_count(m.pylon, "fo-ht-pylon") >= 2, "assembleur : pylone a conducteur aluminium-acier", done("pylon"))
  end,

  shots = function(ctx, add)
    add("chaine-bauxite-z1-jour", CX - 12, CY + 4, 1, 0, { aa = false })
  end,
}
