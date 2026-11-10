-- Lot POLISSAGE-2 (10/11), au banc « content », en moteur réel : les cinq tourelles électriques refaites (tête d'UNE direction,
-- lueur pulsée, faisceau parti de l'émetteur : prototypes/batiments_visuels.lua) se chargent et TIRENT. Chacune, alimentée, a sa
-- cible immobile (béhémoth inactif, 3 000 PV) à 9 tuiles au sud (au-delà de la portée minimale de 6 du Bastion IV) ; la mesure est leur propre damage_dealt (une voisine ne la fausse
-- pas). Rangée espacée de 24 tuiles, une source invisible au centre de la zone (poteau de portée 64).
local TOURELLES = { "fo-bastion-2", "fo-bastion-3", "fo-bastion-4", "fo-tesla-turret", "fo-heavy-laser-turret" }

return {
  setup = function(ctx)
    ctx.prepare_zone("grass-1")
    local z, s = ctx.zone, ctx.surface()
    local tir, cible = game.create_force("fo-bat-tir"), game.create_force("fo-bat-cible")
    tir.set_cease_fire(cible, false)
    cible.set_cease_fire(tir, false)
    for _, other in ipairs({ "enemy", "player" }) do
      for _, f in ipairs({ tir, cible }) do
        f.set_cease_fire(other, true)
        game.forces[other].set_cease_fire(f, true)
      end
    end
    ctx.power((z.x0 + z.x1) / 2, z.y0 + 60, tir)
    local st = ctx.state()
    st.rows = {}
    for i, name in ipairs(TOURELLES) do
      local x, y = z.x0 + 12 + 24 * (i - 1), z.y0 + 30
      local t = game.entity_prototypes[name] and s.create_entity({ name = name, position = { x, y }, force = tir })
      local u = s.create_entity({ name = "behemoth-biter", position = { x, y + 9 }, force = cible })
      if u then u.active = false end
      st.rows[i] = { name = name, turret = t, target = u }
      ctx.check(t ~= nil and u ~= nil, name .. " : tourelle et cible posees")
    end
  end,

  verify = function(ctx)
    for _, r in ipairs(ctx.state().rows or {}) do
      local t = r.turret
      local dealt = t and t.valid and t.damage_dealt or 0
      ctx.check(dealt > 0, r.name .. " (tete d'une direction, faisceau de l'emetteur) : tire et blesse sa cible", string.format("%.0f degats", dealt))
    end
  end,
}
