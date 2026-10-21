-- Exemple de CONTRÔLE GREFFÉ au banc « content » (format : tools/autotest/README.md), listé dans
-- checks/index.lua. Il vérifie aussi l'outil lui-même : l'alimentation invisible de la vitrine fonctionne.
return {
  setup = function(ctx) -- pendant la préparation du banc (on_init), après le socle
    ctx.prepare_zone("grass-1") -- zone réservée à ce greffon : ctx.zone = { x0, y0, x1, y1 }
    local z = ctx.zone
    local t = ctx.surface().create_entity({ name = "laser-turret", position = { z.x0 + 10, z.y0 + 10 }, force = "player" })
    ctx.power(z.x0 + 10, z.y0 + 10)
    ctx.state().turret = t and t.position
    ctx.check(t ~= nil, "tourelle laser posee dans la zone du greffon")
  end,

  verify = function(ctx) -- au tick de vérification du banc (3 000), avant son BILAN
    local p = ctx.state().turret
    local t = p and ctx.surface().find_entity("laser-turret", p)
    ctx.check(t and t.energy > 0, "tourelle laser alimentee sans poteau visible", t and string.format("%.0f J", t.energy))
  end,

  shots = function(ctx, add) -- facultatif : ajouté à la galerie « content » (préfixe greffon-exemple-)
    local p = ctx.state().turret
    if p then add("tourelle-laser", p.x, p.y - 0.5, 2, 0) end
  end,
}
