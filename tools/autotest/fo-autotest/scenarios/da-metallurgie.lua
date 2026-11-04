-- Scénario greffé du lot DA-METALLURGIE (4/11) : les bâtiments de métallurgie avec leurs vraies images, EN MARCHE, à côté de leur
-- équivalent vanilla, de jour et de nuit ; le pylône haute tension dans ses 4 directions, fils posés.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui DA-METALLURGIE -- 400 da-metallurgie <source>              (contrôles)
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache" --qui DA-METALLURGIE -- 400 da-metallurgie <source>
-- Chaque machine : recette posée, ingrédients (objets et fluides) mis par script, combustible pour les machines à combustible,
-- alimentation invisible du mod de test pour les électriques ; elle TRAVAILLE (lueur, lumière au sol, fumée). Pylônes : un centre
-- relié à l'est, au sud et au sud-est, chacun prend sa direction. Journal : [FO-DA-METALLURGIE].

local X0, Y0 = 4200, 3000
local SITES = {
  { name = "fo-blast-furnace", size = 4, recipe = "fo-blast-furnace-steel", fuel = true,
    vanilla = { name = "steel-furnace", size = 2, inputs = { { "iron-ore", 50 } }, fuel = true } },
  { name = "fo-coke-oven", size = 3, recipe = "fo-coke", fuel = true,
    vanilla = { name = "assembling-machine-1", size = 3, recipe = "iron-gear-wheel", inputs = { { "iron-plate", 60 } } } },
  { name = "fo-kroll-reactor", size = 4, recipe = "fo-kroll-reduction",
    vanilla = { name = "centrifuge", size = 3, recipe = "uranium-processing", inputs = { { "uranium-ore", 40 } } } },
  { name = "fo-ore-concentrator", size = 2, recipe = "fo-ilmenite-concentrate",
    vanilla = { name = "assembling-machine-1", size = 3, recipe = "iron-gear-wheel", inputs = { { "iron-plate", 60 } } } },
  { name = "fo-reduction-cell", size = 4, recipe = "fo-hall-heroult",
    vanilla = { name = "electric-furnace", size = 3, inputs = { { "iron-ore", 50 } } } },
}

local function remplir(m, recipe, fois)
  local inv = m.get_inventory(defines.inventory.assembling_machine_input)
  for _, g in ipairs(game.recipe_prototypes[recipe].ingredients) do
    if g.type == "fluid" then
      m.insert_fluid({ name = g.name, amount = math.min(1000, g.amount * fois) })
    else
      inv.insert({ name = g.name, count = g.amount * fois })
    end
  end
end

local function combustible(m)
  local f = m.get_fuel_inventory()
  if f then f.insert({ name = "coal", count = 50 }) end
end

return {
  description = "DA-METALLURGIE : machines de metallurgie en marche a cote du vanilla, pylone HT en 4 directions, jour et nuit",
  base = nil,
  check_tick = 300,
  shots_delay = 320,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.sites = {}
    ctx.prepare_area(X0 - 12, Y0 - 16, X0 + 110, Y0 + 60, "concrete")
    game.map_settings.enemy_expansion.enabled = false
    game.forces.enemy.set_cease_fire("player", true)
    game.forces.player.set_cease_fire("enemy", true)
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 150, Y0 - 150 }, { X0 + 260, Y0 + 220 } } })) do
      en.destroy()
    end
    local src = ctx.power(X0 + 50, Y0 + 20)
    ctx.check(src ~= nil, "alimentation invisible du mod de test", src and "posee" or "prototypes absents")
    local force = game.forces.player
    local x = X0
    for _, f in ipairs(SITES) do
      local h = f.size / 2
      local vx = x + f.vanilla.size / 2
      local px, py = vx + f.vanilla.size / 2 + 2 + h, Y0 + 12
      local v = s.create_entity({ name = f.vanilla.name, position = { vx, py + h - f.vanilla.size / 2 }, force = force })
      if v then
        if f.vanilla.recipe then v.set_recipe(f.vanilla.recipe) end
        for _, it in ipairs(f.vanilla.inputs or {}) do v.insert({ name = it[1], count = it[2] }) end
        if f.vanilla.fuel then combustible(v) end
      end
      local m = s.create_entity({ name = f.name, position = { px, py }, force = force })
      if game.recipe_prototypes[f.recipe] then
        force.recipes[f.recipe].enabled = true
        m.set_recipe(f.recipe)
        remplir(m, f.recipe, 4)
      end
      if f.fuel then combustible(m) end
      st.sites[#st.sites + 1] = { f = f, m = m, v = v, x = px, y = py, vx = vx, side = f.size }
      x = px + h + 6
    end
    -- pylônes : un centre relié à l'est, au sud et au sud-est ; un grand poteau vanilla à côté du centre
    local cx, cy = X0 + 20, Y0 + 34
    st.poteaux = {}
    for i, d in ipairs({ { 0, 0 }, { 18, 0 }, { 0, 16 }, { 13, 13 } }) do
      st.poteaux[i] = s.create_entity({ name = "fo-ht-pylon", position = { cx + d[1], cy + d[2] }, force = force })
    end
    for i = 2, 4 do
      if st.poteaux[1] and st.poteaux[i] then st.poteaux[1].connect_neighbour(st.poteaux[i]) end
    end
    st.van_poteau = s.create_entity({ name = "big-electric-pole", position = { cx - 5, cy }, force = force })
    st.cx, st.cy = cx, cy
  end,

  -- les machines rapides (concentrateur : 30 minerais par seconde ; Kroll) videraient leurs entrées avant le contrôle : toutes les
  -- 20 ticks, entrées regarnies, sorties vidées, combustible remis (sur les vanilla aussi)
  tick = function(ctx, e)
    if e.tick % 20 ~= 0 then return end
    local st = ctx.state()
    for _, c in ipairs(st.sites or {}) do
      if c.m and c.m.valid then
        local out = c.m.get_inventory(defines.inventory.assembling_machine_output)
        if out then out.clear() end
        if c.m.get_recipe() then remplir(c.m, c.m.get_recipe().name, 2) end
        if c.f.fuel then combustible(c.m) end
      end
      if c.v and c.v.valid then
        local out = c.v.get_output_inventory()
        if out then out.clear() end
        for _, it in ipairs(c.f.vanilla.inputs or {}) do c.v.insert({ name = it[1], count = it[2] }) end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    for _, c in ipairs(st.sites) do
      local p = c.m.prototype
      ctx.check(c.m and c.m.valid and c.m.is_crafting(), c.f.name .. " : en marche", string.format("statut %s", tostring(c.m.status)))
      ctx.check(p.drawing_box ~= nil and math.abs(p.collision_box.right_bottom.x - (c.side / 2 - 0.3)) < 0.01,
        c.f.name .. " : boite de collision de l'emprise inchangee", string.format("collision %.2f, emprise %d", p.collision_box.right_bottom.x, c.side))
    end
    local relies = 0
    for i = 2, 4 do
      local q = st.poteaux[i]
      if q and q.valid and #q.neighbours.copper >= 1 then relies = relies + 1 end
    end
    ctx.check(relies == 3, "pylones : 3 relies au centre par un fil de cuivre", relies .. " sur 3")
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local L = { "nom\tx\ty\tzoom\tnuit" }
    for _, c in ipairs(st.sites) do
      local cx = (c.vx + c.x) / 2
      local cy = c.y - c.side * 0.45
      local w = math.ceil((c.x - c.vx + c.side + 8) * 32)
      local h = math.ceil((c.side * 1.8 + 6) * 32)
      for _, nuit in ipairs({ false, true }) do
        local nm = string.format("%s-z1-%s", c.f.name, nuit and "nuit" or "jour")
        add(nm, cx, cy, 1, nuit and 0.5 or 0, { res = { w, h }, info = false, aa = true })
        L[#L + 1] = string.format("%s\t%.2f\t%.2f\t1\t%d", nm, cx, cy, nuit and 1 or 0)
      end
      add(c.f.name .. "-z2-jour", c.x, cy, 2, 0, { res = { math.ceil((c.side + 4) * 64), math.ceil((c.side * 1.8 + 5) * 64) }, info = false, aa = true })
    end
    for _, nuit in ipairs({ false, true }) do
      local nm = "pylones-z1-" .. (nuit and "nuit" or "jour")
      add(nm, st.cx + 7, st.cy + 4, 1, nuit and 0.5 or 0, { res = { 960, 800 }, info = false, aa = true })
      L[#L + 1] = string.format("%s\t%.2f\t%.2f\t1\t%d", nm, st.cx + 7, st.cy + 4, nuit and 1 or 0)
    end
    add("pylone-centre-z2-jour", st.cx - 2, st.cy - 3, 2, 0, { res = { 900, 800 }, info = false, aa = true })
    game.write_file("fo-shots/da-metallurgie-sites.tsv", table.concat(L, "\n") .. "\n", false)
  end,
}
