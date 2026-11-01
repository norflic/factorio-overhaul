-- Scénario greffé du lot US-V1 (1/11) : LES 4 USINES DE ROBOTS en jeu, avec leurs vraies images, EN MARCHE, de jour et de nuit, et leurs bras.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui USV1 -- 400 rb-usines <source>                    (contrôles, sans images)
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache" --qui USV1 -- 400 rb-usines <source>
-- Une usine par site, alimentée (source invisible du mod de test), recette de son premier robot, ingrédients posés par script : elle
-- TRAVAILLE (lueur, lumière, vapeur de l'atelier). Un bras au milieu de chacun des 4 côtés et un au coin nord-ouest de la rangée nord : le
-- bras doit viser l'usine (drop_target ou pickup_target) et l'image ne doit pas le cacher. Captures : chaque usine à côté d'un assembleur 3
-- vanilla, zoom 1 et zoom 2, jour et nuit ; 2 usines à l'arrêt, pour voir la lueur éteinte. Journal : [FO-RB-USINES].

local X0, Y0 = 3200, 3000
local USINES = {
  { name = "fo-robot-workshop", size = 3, recipe = "fo-robot-make-steam-trotter" },
  { name = "fo-robotics-bay", size = 5, recipe = "fo-robot-make-needle" },
  { name = "fo-robot-dock", size = 7, recipe = "fo-robot-make-trowel" },
  { name = "fo-robot-gantry", size = 11, recipe = "fo-robot-make-toroid" },
}

return {
  description = "US-V1 : les 4 usines de robots en marche, images, bras sur les 4 cotes, jour et nuit",
  base = nil,
  check_tick = 300,
  shots_delay = 320,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.sites = {}
    ctx.prepare_area(X0 - 12, Y0 - 12, X0 + 90, Y0 + 50, "concrete")
    game.map_settings.enemy_expansion.enabled = false
    game.forces.enemy.set_cease_fire("player", true)
    game.forces.player.set_cease_fire("enemy", true)
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 150, Y0 - 150 }, { X0 + 220, Y0 + 220 } } })) do
      en.destroy()
    end
    local src = ctx.power(X0 + 30, Y0 + 40)
    ctx.check(src ~= nil, "alimentation invisible du mod de test", src and "posee" or "prototypes absents")
    local force = game.forces.player
    local x = X0
    for _, f in ipairs(USINES) do
      local h = f.size / 2
      local px, py = x + h + 8, Y0 + 12
      local m = s.create_entity({ name = f.name, position = { px, py }, force = force })
      force.recipes[f.recipe].enabled = true
      m.set_recipe(f.recipe)
      for _, g in ipairs(game.recipe_prototypes[f.recipe].ingredients) do m.insert({ name = g.name, count = g.amount * 2 }) end
      local v = s.create_entity({ name = "assembling-machine-3", position = { px - h - 3.5, py + h - 1.5 }, force = force })
      local bras = {}
      for _, d in ipairs({ { 0, -h - 0.5 }, { h + 0.5, 0 }, { 0, h + 0.5 }, { -h - 0.5, 0 } }) do
        local dir = (d[2] < 0 and defines.direction.south) or (d[1] > 0 and defines.direction.west)
          or (d[2] > 0 and defines.direction.north) or defines.direction.east
        bras[#bras + 1] = s.create_entity({ name = "fast-inserter", position = { px + d[1], py + d[2] }, direction = dir, force = force })
      end
      st.sites[#st.sites + 1] = { f = f, m = m, v = v, bras = bras, x = px, y = py, side = f.size }
      x = x + f.size + 14
    end
    -- 2 témoins à l'arrêt : sans recette, la lueur doit rester éteinte
    for i, nm in ipairs({ "fo-robot-workshop", "fo-robot-dock" }) do
      st.arret = st.arret or {}
      st.arret[i] = s.create_entity({ name = nm, position = { X0 + 8 + (i - 1) * 12, Y0 + 34 }, force = force })
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    for _, c in ipairs(st.sites) do
      local vises = 0
      for _, b in ipairs(c.bras) do
        if b and b.valid and (b.drop_target == c.m or b.pickup_target == c.m) then vises = vises + 1 end
      end
      ctx.check(c.m and c.m.valid and c.m.is_crafting(), c.f.name .. " : en marche", string.format("statut %s", tostring(c.m.status)))
      ctx.check(vises == 4, c.f.name .. " : les 4 bras des 4 cotes visent l'usine", vises .. " sur 4")
      local p = c.m.prototype
      ctx.check(p.drawing_box ~= nil and p.collision_box.right_bottom.x > c.side / 2 - 0.4, c.f.name .. " : boites a l'echelle de l'emprise",
        string.format("collision %.2f, emprise %d", p.collision_box.right_bottom.x, c.side))
    end
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    for _, c in ipairs(st.sites) do
      local cx = c.x - 2
      local cy = c.y - c.side * 0.35
      local w, h = math.ceil((c.side + 11) * 32), math.ceil((c.side * 1.6 + 7) * 32)
      for _, nuit in ipairs({ false, true }) do
        add(string.format("%s-z1-%s", c.f.name, nuit and "nuit" or "jour"), cx, cy, 1, nuit and 0.5 or 0, { res = { w, h }, info = false, aa = true })
      end
      add(c.f.name .. "-z2-jour", c.x, cy, 2, 0, { res = { math.ceil((c.side + 5) * 64), math.ceil((c.side * 1.6 + 6) * 64) }, info = false, aa = true })
    end
    add("arret-z1", X0 + 14, Y0 + 32, 1, 0, { res = { 800, 480 }, info = false, aa = true })
  end,
}
