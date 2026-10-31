-- Lot EQUILIBRE (relecture) : au banc « content », en moteur réel : les 12 paliers et 6 familles se chargent, les statistiques
-- du niveau 30 sont celles de la règle × 1,15, et un laser de niveau 30 TUE au-delà des 24 tuiles du faisceau vanilla
-- (cible à 33 tuiles ; témoin : un laser de niveau 1, portée 24, n'y touche pas). Forces à part : `content` met le joueur
-- en cessez-le-feu avec « enemy ».
local E = require("__factorio-overhaul__/shared/content/enemies")

local function near(a, b) return a and math.abs(a - b) <= 0.01 * b end

return {
  setup = function(ctx)
    ctx.prepare_zone("grass-1")
    local z, s = ctx.zone, ctx.surface()
    local tir, cible = game.create_force("fo-eq-tir"), game.create_force("fo-eq-cible")
    tir.set_cease_fire(cible, false)
    cible.set_cease_fire(tir, false)
    local st = ctx.state()
    st.rows = {}
    for i, name in ipairs({ "fo-lvl-laser-30", "laser-turret" }) do
      local y = z.y0 + 15 + (i - 1) * 55
      local t = s.create_entity({ name = name, position = { z.x0 + 10, y }, force = tir })
      local w = s.create_entity({ name = "small-worm-turret", position = { z.x0 + 43, y }, force = cible })
      ctx.power(z.x0 + 10, y + 8, tir)
      st.rows[i] = { turret = t, worm = w, health = w and w.health }
      ctx.check(t ~= nil and w ~= nil, name .. " et sa cible posees a 33 tuiles")
    end
  end,

  verify = function(ctx)
    local p = game.entity_prototypes
    local miss, n = {}, 0
    local function need(name)
      n = n + 1
      if not p[name] then miss[#miss + 1] = name end
    end
    for tier = 1, E.TIERS do
      need(E.worm_name(tier))
      for _, kind in ipairs({ "biter", "spitter" }) do
        need(E.unit_name(kind, tier))
        for _, fam in ipairs(E.FAMILY_ORDER) do need(E.unit_name(kind, tier, fam)) end
      end
    end
    for _, fam in ipairs(E.FAMILY_ORDER) do need(E.nest_name(fam)) end
    ctx.check(E.TIERS == 12 and #E.FAMILY_ORDER == 6 and #miss == 0, "12 paliers, 6 familles, vers et nids charges", n .. " noms, manquants : " .. table.concat(miss, " "))
    local nest = p[E.nest_name("toxic")]
    ctx.check(nest and #nest.result_units == 24, "nid toxique : 24 unites (12 paliers x 2)", nest and #nest.result_units)

    local l30, g30 = p["fo-lvl-laser-30"], p["fo-lvl-gun-30"]
    ctx.check(l30 and near(l30.max_health, 1000 * 1.15 ^ 29), "laser 30 : vie x 1,15 par niveau", l30 and l30.max_health)
    ctx.check(g30 and near(g30.max_health, 400 * 1.15 ^ 29), "mitrailleuse 30 : vie x 1,15 par niveau", g30 and g30.max_health)
    ctx.check(l30 and l30.attack_parameters.range > 35, "laser 30 : portee", l30 and l30.attack_parameters.range)
    for _, c in ipairs({ { "fo-lvl-furnace-30", "crafting_speed", 2 }, { "fo-lvl-assembler-30", "crafting_speed", 0.75 }, { "fo-lvl-drill-30", "mining_speed", 0.5 } }) do
      local v = p[c[1]] and p[c[1]][c[2]]
      ctx.check(near(v, c[3] * 1.15 ^ 29), c[1] .. " : vitesse x 1,15 par niveau", v)
    end

    local rows = ctx.state().rows
    ctx.check(rows[1].worm and not rows[1].worm.valid, "laser 30 : cible a 33 tuiles detruite (au-dela des 24 du faisceau vanilla)")
    ctx.check(rows[2].worm and rows[2].worm.valid and rows[2].worm.health == rows[2].health, "temoin laser 1 (portee 24) : cible intacte")
  end,
}
