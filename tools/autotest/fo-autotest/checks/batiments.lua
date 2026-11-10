-- Lot POLISSAGE-2 (10/11), au banc « content », en moteur réel : les cinq tourelles électriques refaites (tête d'UNE direction,
-- lueur pulsée, faisceau parti de l'émetteur : prototypes/batiments_visuels.lua) se chargent et TIRENT. Chacune, alimentée, a sa
-- cible immobile (béhémoth inactif, 3 000 PV) à 9 tuiles au sud (au-delà de la portée minimale de 6 du Bastion IV) ; la mesure est leur propre damage_dealt (une voisine ne la fausse
-- pas). Rangée espacée de 24 tuiles, une source invisible au centre de la zone (poteau de portée 64).
-- Lot POLISSAGE-3 (10/11) : les quatre tourelles à MUNITIONS refaites (tête tournante à 64 directions lue en bandes, origine des
-- projectiles lue du modèle) se chargent, TOURNENT vers leur cible et TIRENT : seconde rangée 45 tuiles plus au sud (hors de portée des
-- électriques), munitions de leur catégorie lues au prototype, cible au-delà de la portée minimale (canon 5, mortier 14).
local TOURELLES = { "fo-bastion-2", "fo-bastion-3", "fo-bastion-4", "fo-tesla-turret", "fo-heavy-laser-turret" }
local MUNITIONS = { "fo-bastion-1", "fo-heavy-gun-turret", "fo-cannon-turret", "fo-mortar-turret" }
-- Lot MURS-ACIDE (10/11) : le pulvérisateur d'acide refait (socle à direction, tête tournante à 64 directions, origine du jet lue du
-- modèle) : troisième rangée, tourné vers le sud (sa tête ne tourne que d'un tiers de tour autour du socle), fluide de son attaque lu au
-- prototype et versé dans sa boîte à fluide, cible au sud au-delà de sa portée minimale.
local FLUIDES = { "fo-acid-sprayer" }

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
    st.mun = {}
    for i, name in ipairs(MUNITIONS) do
      local x, y = z.x0 + 16 + 30 * (i - 1), z.y0 + 75
      local t = game.entity_prototypes[name] and s.create_entity({ name = name, position = { x, y }, force = tir })
      local mn = t and t.prototype.attack_parameters and t.prototype.attack_parameters.min_range or 0
      local u = s.create_entity({ name = "behemoth-biter", position = { x + 4, y + math.max(9, mn + 4) }, force = cible })
      if u then u.active = false end
      local am = nil   -- première munition (ordre des noms) de la catégorie de la tourelle, lue aux prototypes
      if t then
        local cat = t.prototype.attack_parameters.ammo_categories and t.prototype.attack_parameters.ammo_categories[1]
        local noms = {}
        for n, it in pairs(game.item_prototypes) do
          if it.type == "ammo" then
            local at = it.get_ammo_type("turret") or it.get_ammo_type()
            if at and at.category == cat then noms[#noms + 1] = n end
          end
        end
        table.sort(noms)
        am = noms[1]
        if am then t.insert({ name = am, count = 20 }) end
      end
      st.mun[i] = { name = name, turret = t, target = u, ammo = am }
      ctx.check(t ~= nil and u ~= nil and am ~= nil, name .. " : tourelle a munitions, cible et munition " .. tostring(am))
    end
    st.fl = {}
    for i, name in ipairs(FLUIDES) do
      local x, y = z.x0 + 20 + 30 * (i - 1), z.y0 + 120
      local p = game.entity_prototypes[name]
      local t = p and s.create_entity({ name = name, position = { x, y }, direction = defines.direction.south, force = tir })
      local ap = p and p.attack_parameters
      local mn = ap and ap.min_range or 0
      local u = s.create_entity({ name = "behemoth-biter", position = { x, y + math.max(9, mn + 5) }, force = cible })
      if u then u.active = false end
      local fl = ap and ap.fluids and ap.fluids[1] and ap.fluids[1].type
      if t and fl then t.fluidbox[1] = { name = fl, amount = 100 } end
      st.fl[i] = { name = name, turret = t, target = u, fluid = fl }
      ctx.check(t ~= nil and u ~= nil and fl ~= nil, name .. " : tourelle a fluide, cible et fluide " .. tostring(fl))
    end
  end,

  verify = function(ctx)
    for _, r in ipairs(ctx.state().rows or {}) do
      local t = r.turret
      local dealt = t and t.valid and t.damage_dealt or 0
      ctx.check(dealt > 0, r.name .. " (tete d'une direction, faisceau de l'emetteur) : tire et blesse sa cible", string.format("%.0f degats", dealt))
    end
    for _, r in ipairs(ctx.state().mun or {}) do
      local t = r.turret
      local dealt = t and t.valid and t.damage_dealt or 0
      ctx.check(dealt > 0, r.name .. " (tete tournante a 64 directions, origine des projectiles du modele) : tourne, tire et blesse sa cible",
        string.format("%.0f degats, munition %s", dealt, tostring(r.ammo)))
    end
    for _, r in ipairs(ctx.state().fl or {}) do
      local t = r.turret
      local dealt = t and t.valid and t.damage_dealt or 0
      ctx.check(dealt > 0, r.name .. " (socle a direction, tete tournante a 64 directions, jet du modele) : tire et blesse sa cible",
        string.format("%.0f degats, fluide %s", dealt, tostring(r.fluid)))
    end
  end,
}
