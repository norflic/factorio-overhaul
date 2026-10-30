--[[
  Scénario GREFFÉ « quartz-puces » (lot X3-MINERAIS, 30/10) : le quartz filonien et la fonderie de puces d'X3 (chaîne A,
  âge 10) en moteur réel. Lancement :
    py -3.9 -B tools/autotest/banc.py --out <archive> --qui x3-minerais -- 3000 quartz-puces <source>
  1. Prototypes : quartz filonien (basic-solid, minage 3 s, AUCUN autoplace ni réglage de carte), objets, résine, machines.
  2. La fonderie de puces et ses prérequis (fermeture complète) : les 10 recettes ouvertes ; chaque ingrédient de chaque recette
     du lot a une recette ouverte qui le produit (ou c'est l'eau, ou le quartz miné).
  3. Les 2 veines garanties à 400-800 tuiles (fo-monde, on_init), sur un disque de plaine de cristal, d'environ 200 000.
  4. Foreuse électrique sur une veine : quartz miné.
  5. Chaque recette du lot fabrique dans sa machine (four à arc, tireuse, taillerie, usine chimique, salle blanche,
     assembleur, lithographe) : creuset, lingot, 40 tranches sciées, résine photosensible, photomasque, laser à cristal,
     tranches gravées, processeur gravé.
]]

local MONDE = "fo-monde"
local CX, CY = 3600, -3900
local T_SITE, CHECK = 2, 2700

local function by_key(list, key)
  for _, d in ipairs(list or {}) do if d.key == key then return d end end
end
local function in_inv(e) return e.get_inventory(defines.inventory.assembling_machine_input) end
local function out_count(e, n) return e.get_inventory(defines.inventory.assembling_machine_output).get_item_count(n) end

-- Une machine par recette, nourrie à la main (pas de chaîne : chaque recette se prouve seule).
local CHAINE = {
  { k = "creuset", machine = "fo-arc-furnace", recipe = "fo-quartz-crucible", items = { { "fo-vein-quartz", 24 } }, out = "fo-quartz-crucible", min = 2 },
  { k = "lingot", machine = "fo-crystal-puller", recipe = "fo-silicon-ingot",
    items = { { "fo-pure-silicon", 20 }, { "fo-quartz-crucible", 2 } }, out = "fo-silicon-ingot", min = 1 },
  { k = "scie", machine = "fo-lapidary", recipe = "fo-wafer-sawing",
    items = { { "fo-silicon-ingot", 2 }, { "fo-crystal-powder", 4 } }, fluids = { { "water", 200 } }, out = "fo-silicon-wafer", min = 40 },
  { k = "resine", machine = "chemical-plant", recipe = "fo-photoresist",
    items = { { "sulfur", 5 } }, fluids = { { "fo-epoxy-resin", 100 }, { "light-oil", 100 } }, fluid_out = "fo-photoresist", min = 20 },
  { k = "masque", machine = "fo-cleanroom", recipe = "fo-photomask",
    items = { { "fo-glass", 6 }, { "fo-tungsten-plate", 3 }, { "advanced-circuit", 3 } }, out = "fo-photomask", min = 1 },
  { k = "laser", machine = "assembling-machine-2", recipe = "fo-crystal-laser",
    items = { { "fo-cut-crystal", 2 }, { "fo-resonance-lens", 4 }, { "fo-coil", 4 }, { "fo-aluminium-plate", 2 } }, out = "fo-crystal-laser", min = 1 },
  { k = "litho", machine = "fo-crystal-lithograph", recipe = "fo-etched-wafer",
    items = { { "fo-silicon-wafer", 30 }, { "fo-photomask", 3 } }, fluids = { { "fo-photoresist", 30 }, { "sulfuric-acid", 60 } },
    out = "fo-etched-wafer", min = 10 },
  { k = "processeur", machine = "fo-cleanroom", recipe = "fo-etched-processor",
    items = { { "fo-etched-wafer", 8 }, { "fo-printed-circuit-board", 8 }, { "electronic-circuit", 40 }, { "advanced-circuit", 4 } },
    out = "processing-unit", min = 2 },
}
local UNLOCKS = { "fo-quartz-crucible", "fo-crystal-puller", "fo-silicon-ingot", "fo-wafer-sawing", "fo-photoresist", "fo-photomask",
  "fo-crystal-laser", "fo-crystal-lithograph", "fo-etched-wafer", "fo-etched-processor" }
local RAW = { ["water"] = true, ["fo-vein-quartz"] = true }

--- Recherche une technologie et TOUTE sa fermeture de prérequis (noms triés : déterministe).
local function research_closure(f, name, seen)
  if seen[name] then return end
  seen[name] = true
  local t = f.technologies[name]
  if not t then return end
  local pre = {}
  for n in pairs(t.prerequisites) do pre[#pre + 1] = n end
  table.sort(pre)
  for _, n in ipairs(pre) do research_closure(f, n, seen) end
  t.researched = true
end

return {
  description = "quartz-puces : quartz filonien garanti, fonderie de puces (creuset, lingot, tranches sciees, lithographie, processeur grave)",
  check_tick = CHECK,
  shots_delay = 200,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    local miss = {}
    for _, n in ipairs({ "fo-vein-quartz", "fo-quartz-crucible", "fo-silicon-ingot", "fo-photomask", "fo-etched-wafer", "fo-crystal-laser",
                         "fo-crystal-puller", "fo-crystal-lithograph" }) do
      if not game.item_prototypes[n] then miss[#miss + 1] = n end
    end
    if not game.fluid_prototypes["fo-photoresist"] then miss[#miss + 1] = "fluide fo-photoresist" end
    if not game.entity_prototypes["fo-vein-quartz"] then miss[#miss + 1] = "entite fo-vein-quartz" end
    ctx.check(#miss == 0, "prototypes du quartz et de la fonderie de puces presents", #miss > 0 and table.concat(miss, ", ") or nil)
    local p = game.entity_prototypes["fo-vein-quartz"]
    ctx.check(p and p.resource_category == "basic-solid" and p.mineable_properties.products[1].name == "fo-vein-quartz"
      and p.mineable_properties.mining_time == 3 and p.autoplace_specification == nil and game.autoplace_control_prototypes["fo-vein-quartz"] == nil,
      "quartz : basic-solid, minage 3 s, produit fo-vein-quartz, AUCUN autoplace ni reglage de carte")
    local li = game.entity_prototypes["fo-crystal-lithograph"]
    local pu = game.entity_prototypes["fo-crystal-puller"]
    ctx.check(li and pu and li.crafting_categories["fo-lithography"] and pu.crafting_categories["fo-crystal-pulling"]
      and #li.fluidbox_prototypes == 2 and #pu.fluidbox_prototypes == 0
      and math.abs((li.collision_box.right_bottom.x - li.collision_box.left_top.x) - 3.4) < 0.05,
      "lithographe 4 x 4 a 2 entrees de fluide, tireuse sans fluide (X3)")

    local f = game.forces.player
    research_closure(f, "fo-chip-foundry", {})
    local closed = {}
    for _, r in ipairs(UNLOCKS) do if not (f.recipes[r] and f.recipes[r].enabled) then closed[#closed + 1] = r end end
    ctx.check(#closed == 0, "fonderie de puces : les 10 recettes ouvertes", #closed > 0 and table.concat(closed, ", ") or nil)
    -- Fermeture : chaque ingrédient a une recette OUVERTE qui le produit, avec la seule fonderie et ses prérequis.
    local makes = {}
    local names = {}
    for n in pairs(f.recipes) do names[#names + 1] = n end
    table.sort(names)
    for _, n in ipairs(names) do
      local r = f.recipes[n]
      if r.enabled then for _, pr in ipairs(r.products) do makes[pr.name] = true end end
    end
    local orphan = {}
    for _, rn in ipairs(UNLOCKS) do
      for _, ing in ipairs(game.recipe_prototypes[rn].ingredients) do
        if not (makes[ing.name] or RAW[ing.name]) then orphan[#orphan + 1] = rn .. ":" .. ing.name end
      end
    end
    ctx.check(#orphan == 0, "chaque ingredient du lot est fabricable avec la fonderie et ses prerequis",
      #orphan > 0 and table.concat(orphan, ", ") or nil)

    ctx.prepare_area(CX - 50, CY - 20, CX + 80, CY + 30, "grass-1")
    for _, e in ipairs(s.find_entities_filtered({ area = { { CX - 150, CY - 150 }, { CX + 150, CY + 150 } }, force = "enemy" })) do e.destroy() end
    st.m = {}
    local placed, bad = 0, {}
    for i, ch in ipairs(CHAINE) do
      local e = s.create_entity({ name = ch.machine, position = { CX - 30 + (i - 1) * 7, CY }, force = "player", raise_built = true })
      if e then
        e.set_recipe(ch.recipe)
        local inv = in_inv(e)
        for _, it in ipairs(ch.items or {}) do inv.insert({ name = it[1], count = it[2] }) end
        for _, fl in ipairs(ch.fluids or {}) do e.insert_fluid({ name = fl[1], amount = fl[2] }) end
        local fuel = e.get_fuel_inventory()
        if fuel then fuel.insert({ name = "coal", count = 20 }) end
        st.m[ch.k] = e
        if e.get_recipe() and e.get_recipe().name == ch.recipe then placed = placed + 1 else bad[#bad + 1] = ch.k end
      else
        bad[#bad + 1] = ch.k
      end
    end
    ctx.check(placed == #CHAINE, #CHAINE .. " machines posees avec leur recette", #bad > 0 and table.concat(bad, ", ") or nil)
    ctx.power(CX - 20, CY + 6)
    ctx.power(CX + 10, CY + 6)
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick ~= T_SITE then return end
    local spec = by_key(ctx.remote(MONDE, "specs"), "quartz")
    local d = by_key(ctx.remote(MONDE, "status").done, "quartz")
    local sites = d and d.sites or {}
    ctx.check(spec and d and d.ok and d.phase == "init" and #sites == 2, "2 veines de quartz garanties posees a on_init",
      #sites > 0 and string.format("(%d, %d) a %.1f", sites[1].x, sites[1].y, sites[1].dist) or "absent")
    if not (spec and #sites == 2) then return end
    local bad = {}
    for i, site in ipairs(sites) do
      local ore = s.find_entities_filtered({ name = "fo-vein-quartz", position = { site.x + 0.5, site.y + 0.5 }, radius = spec.core_radius + 1.5 })
      local amt, wrong = 0, 0
      for _, r in ipairs(ore) do
        amt = amt + r.amount
        if s.get_tile(math.floor(r.position.x), math.floor(r.position.y)).name ~= "fo-crystal-flats" then wrong = wrong + 1 end
      end
      if not (#ore == site.entities and amt >= 1.5 * spec.min_total and wrong == 0 and site.dist >= spec.dmin and site.dist <= spec.dmax) then
        bad[#bad + 1] = string.format("site %d : %d entites, %d, %d hors plaine, %.1f", i, #ore, amt, wrong, site.dist)
      end
    end
    ctx.check(#bad == 0, "2 veines completes (>= 195 000) a 400-800 tuiles, sur la plaine de cristal",
      #bad > 0 and table.concat(bad, " ; ") or string.format("%.0f et %.0f tuiles", sites[1].dist, sites[2].dist))
    local c1 = sites[1]
    ctx.power(c1.x, c1.y)
    st.ed = s.create_entity({ name = "electric-mining-drill", position = { c1.x - 2.5, c1.y + 0.5 }, force = "player", direction = defines.direction.north })
    if st.ed then st.ed_chest = s.create_entity({ name = "iron-chest", position = st.ed.drop_position, force = "player" }) end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local m = st.m or {}
    local ed = st.ed_chest and st.ed_chest.valid and st.ed_chest.get_item_count("fo-vein-quartz") or 0
    ctx.check(ed >= 2, "foreuse electrique : quartz mine", ed)
    local bad = {}
    for _, ch in ipairs(CHAINE) do
      local e = m[ch.k]
      local done = e and e.valid and e.products_finished or 0
      local got
      if ch.fluid_out then
        got = e and e.valid and e.get_fluid_count(ch.fluid_out) or 0
      else
        got = e and e.valid and out_count(e, ch.out) or 0
      end
      if not (done >= 1 and got >= ch.min) then bad[#bad + 1] = string.format("%s : %d fabrication(s), %s %s", ch.k, done, tostring(got), ch.out or ch.fluid_out) end
    end
    ctx.check(#bad == 0, "chaque recette du lot fabrique dans sa machine (creuset, lingot, 40 tranches, resine, masque, laser, gravure, processeur)",
      #bad > 0 and table.concat(bad, " ; ") or nil)
  end,

  shots = function(ctx, add)
    add("fonderie-puces-z1-jour", CX - 5, CY + 4, 1, 0, { aa = false })
    -- Veines garanties sur la graine des bancs (20261020) : (714, 343) et (-574, 241) ; cristal de résonance garanti en
    -- (33, 273), pour comparer les deux minerais de la plaine (jour et nuit).
    add("quartz-veine-z1-jour", 714.5, 343.5, 1, 0, { aa = false })
    add("quartz-veine-z2-jour", 714.5, 343.5, 2, 0, { aa = false })
    add("quartz-veine-z1-nuit", 714.5, 343.5, 1, 0.5, { aa = false })
    add("quartz-veine2-z1-jour", -573.5, 241.5, 1, 0, { aa = false })
    add("cristal-site-z1-jour", 33.5, 273.5, 1, 0, { aa = false })
    add("cristal-site-z1-nuit", 33.5, 273.5, 1, 0.5, { aa = false })
  end,
}
