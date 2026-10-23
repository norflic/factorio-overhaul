-- Scénario greffé (lot A2, correction, 24/10) : EFFET VISIBLE de « linear-mip-level » sur l'atlas [icon] (F125).
--   $env:FO_VISUAL_ARGS = '--quality normal'; & "<racine>\fo-captures.bat" a2-icones "<source>"; $env:FO_VISUAL_ARGS = $null
-- Pose des tourelles chargées (mitrailleuse vanilla et niveaux 3, 16 et 30), des coffres garnis d'objets et des
-- assembleurs, puis capture en mode Alt (icônes de munitions, de contenu, de recette : toutes dans l'atlas [icon]) à
-- des zooms qui tombent ENTRE deux niveaux de mipmap (0,3 ; 0,45 ; 0,7 ; 1,3), pour comparer pixel à pixel deux copies
-- du mod dont l'atlas [icon] a, ou n'a pas, le drapeau (même contenu d'icônes, rangement différent).

local X0, Y0 = 6000, -2400

return {
  description = "A2 : effet visible de linear-mip-level sur l'atlas [icon] (mode Alt, zooms entre mipmaps)",
  base = nil,
  check_tick = 120,
  shots_delay = 60,

  init = function(ctx)
    local s = ctx.surface()
    ctx.prepare_area(X0 - 30, Y0 - 30, X0 + 30, Y0 + 30, "concrete")
    local n = 0
    local noms = { "gun-turret", "fo-lvl-gun-3", "fo-lvl-gun-16", "fo-lvl-gun-30" }
    for i, nm in ipairs(noms) do
      if game.entity_prototypes[nm] then
        local t = s.create_entity({ name = nm, position = { X0 - 18 + i * 8, Y0 - 8 }, force = "player" })
        if t then
          t.insert({ name = "firearm-magazine", count = 10 })
          n = n + 1
        end
      end
    end
    local objets = { "iron-plate", "copper-cable", "electronic-circuit", "firearm-magazine", "gun-turret", "stone-wall",
      "transport-belt", "inserter" }
    for i, it in ipairs(objets) do
      local c = s.create_entity({ name = "wooden-chest", position = { X0 - 8 + i * 2, Y0 + 2 }, force = "player" })
      if c then c.insert({ name = it, count = 5 }) n = n + 1 end
    end
    for i, r in ipairs({ "iron-gear-wheel", "electronic-circuit", "firearm-magazine" }) do
      local a = s.create_entity({ name = "assembling-machine-2", position = { X0 - 8 + i * 5, Y0 + 7 }, force = "player" })
      if a then a.set_recipe(r) n = n + 1 end
    end
    ctx.power(X0, Y0)
    ctx.check(n == 4 + 8 + 3, "scene posee (4 tourelles, 8 coffres, 3 assembleurs)", n)
  end,

  finish = function(ctx)
    ctx.check(true, "fin", nil)
  end,

  shots = function(ctx, add)
    for _, z in ipairs({ 0.3, 0.45, 0.7, 1.3 }) do
      add(string.format("icones-z%03d", math.floor(z * 100 + 0.5)), X0, Y0, z, 0, { res = { 960, 640 } })
    end
  end,
}
