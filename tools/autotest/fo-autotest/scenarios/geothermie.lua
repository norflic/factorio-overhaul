--[[
  Scénario GREFFÉ « geothermie » (lot AMELIO-RESSOURCES, piste GÉOTHERMIE, 30/10) : la fumerolle de l'âge 5 (X0) en moteur
  réel. Lancement :
    py -3.9 -B tools/autotest/banc.py --out <archive> --qui amelio-ressources -- 1200 geothermie <source>
  1. Prototypes : fumerolle (fluide infini, catégorie fo-fumarole, 200 gaz par cycle), gaz volcanique, capteur ; technologie.
  2. Les 2 fumerolles garanties sur un disque de cendres à 250-600 tuiles (fo-monde, on_init).
  3. Un capteur géothermique sur une fumerolle garantie : il capte du gaz (le chevalet vanilla ne la capte pas).
  4. Séparation à l'usine chimique : vapeur à 165 °C et soufre ; la vapeur fait tourner une machine à vapeur ; torchère.
]]

local MONDE = "fo-monde"
local CX, CY = -3600, -3740
local T_SITE, CHECK = 2, 1100

local function by_key(list, key)
  for _, d in ipairs(list or {}) do if d.key == key then return d end end
end

return {
  description = "geothermie : fumerolles garanties, capteur geothermique, vapeur a 165 C et soufre, machine a vapeur, torchere",
  check_tick = CHECK,
  shots_delay = 200,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    local res = game.entity_prototypes["fo-fumarole"]
    local gas = game.fluid_prototypes["fo-volcanic-gas"]
    local tap = game.entity_prototypes["fo-geothermal-tap"]
    ctx.check(res and gas and tap and game.item_prototypes["fo-geothermal-tap"], "prototypes de la geothermie presents")
    local prod = res and res.mineable_properties.products[1]
    ctx.check(res and res.resource_category == "fo-fumarole" and res.infinite_resource and prod and prod.name == "fo-volcanic-gas"
      and (prod.amount or prod.amount_max) == 200 and game.autoplace_control_prototypes["fo-fumarole"] ~= nil,
      "fumerolle : fluide infini, categorie propre, 200 gaz par cycle, reglage de carte")
    ctx.check(tap and tap.resource_categories["fo-fumarole"] and not tap.resource_categories["basic-fluid"]
      and not game.entity_prototypes["pumpjack"].resource_categories["fo-fumarole"]
      and math.abs(tap.max_energy_usage * 60 - 3e5) < 1,
      "capteur : seul a capter la fumerolle (pas le chevalet), 300 kW")
    local f = game.forces.player
    for _, t in ipairs({ "fo-tungsten-processing", "fo-crushing", "fo-glassworks", "fo-flaring", "fo-geothermal" }) do
      if f.technologies[t] then f.technologies[t].researched = true end
    end
    local closed = {}
    for _, r in ipairs({ "fo-geothermal-tap", "fo-volcanic-gas-separation", "fo-flare-volcanic-gas" }) do
      if not (f.recipes[r] and f.recipes[r].enabled) then closed[#closed + 1] = r end
    end
    ctx.check(#closed == 0, "technologie Geothermie : 3 recettes ouvertes", #closed > 0 and table.concat(closed, ", ") or nil)

    ctx.prepare_area(CX - 30, CY - 20, CX + 95, CY + 20, "grass-1")
    for _, e in ipairs(s.find_entities_filtered({ area = { { CX - 150, CY - 150 }, { CX + 150, CY + 150 } }, force = "enemy" })) do e.destroy() end
    st.sep = s.create_entity({ name = "chemical-plant", position = { CX - 10, CY }, force = "player", raise_built = true })
    if st.sep then
      st.sep.set_recipe("fo-volcanic-gas-separation")
      st.sep.insert_fluid({ name = "fo-volcanic-gas", amount = 200 })
    end
    st.flare = s.create_entity({ name = "fo-flare-stack", position = { CX, CY }, force = "player", raise_built = true })
    if st.flare then
      if st.flare.type == "assembling-machine" then st.flare.set_recipe("fo-flare-volcanic-gas") end
      st.flare.insert_fluid({ name = "fo-volcanic-gas", amount = 200 })
    end
    -- Réseau ISOLÉ, à 90 tuiles de la source de test : la machine à vapeur seule alimente un assembleur (75 kW).
    st.engine = s.create_entity({ name = "steam-engine", position = { CX + 80, CY }, force = "player", direction = defines.direction.north })
    if st.engine then st.engine.insert_fluid({ name = "steam", amount = 200, temperature = 165 }) end
    s.create_entity({ name = "small-electric-pole", position = { CX + 83, CY + 3 }, force = "player" })
    st.load = s.create_entity({ name = "assembling-machine-1", position = { CX + 86, CY + 3 }, force = "player" })
    if st.load then st.load.set_recipe("iron-gear-wheel"); st.load.insert({ name = "iron-plate", count = 100 }) end
    ctx.check(st.sep and st.flare and st.engine and st.sep.get_recipe() and st.sep.get_recipe().name == "fo-volcanic-gas-separation",
      "usine chimique (separation), torchere et machine a vapeur posees")
    ctx.power(CX - 10, CY + 8)
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick ~= T_SITE then return end
    local spec = by_key(ctx.remote(MONDE, "specs"), "fumarole")
    local d = by_key(ctx.remote(MONDE, "status").done, "fumarole")
    local sites = d and d.sites or {}
    ctx.check(spec and d and d.ok and d.phase == "init" and #sites == 1, "fumerolles garanties posees a on_init (un site)",
      #sites > 0 and string.format("(%d, %d) a %.1f", sites[1].x, sites[1].y, sites[1].dist) or "absent")
    if not (spec and #sites == 1) then return end
    local c1 = sites[1]
    local wells = s.find_entities_filtered({ name = "fo-fumarole", position = { c1.x + 0.5, c1.y + 0.5 }, radius = spec.core_radius + 2 })
    local ash = s.count_tiles_filtered({ position = { c1.x + 0.5, c1.y + 0.5 }, radius = 3, name = "fo-volcanic-ash" })
    ctx.check(#wells == 2 and c1.dist >= spec.dmin and c1.dist <= spec.dmax and ash > 0,
      "2 fumerolles a 250-600 tuiles, sur les cendres", #wells .. " puits, cendres " .. ash)
    if #wells == 0 then return end
    local w = wells[1]
    st.well_pos = { w.position.x, w.position.y }
    ctx.power(w.position.x + 4, w.position.y + 4)
    st.tap = s.create_entity({ name = "fo-geothermal-tap", position = w.position, force = "player", direction = defines.direction.north })
    -- un chevalet vanilla sur la seconde fumerolle : il ne doit rien capter (catégorie propre)
    if wells[2] then
      st.pump = s.create_entity({ name = "pumpjack", position = wells[2].position, force = "player", direction = defines.direction.north })
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local tap = st.tap
    local g = 0
    if tap and tap.valid then
      for i = 1, #tap.fluidbox do
        local fb = tap.fluidbox[i]
        if fb and fb.name == "fo-volcanic-gas" then g = g + fb.amount end
      end
    end
    ctx.check(tap and tap.valid and g > 0 and tap.mining_target and tap.mining_target.name == "fo-fumarole",
      "capteur geothermique sur la fumerolle : gaz volcanique capte", string.format("%.0f", g))
    ctx.check(st.pump == nil or not st.pump.valid or st.pump.mining_target == nil,
      "le chevalet vanilla ne capte pas la fumerolle", st.pump and st.pump.valid and tostring(st.pump.mining_target and st.pump.mining_target.name) or "absent")
    local sep = st.sep
    local steam, temp, sulfur = 0, 0, 0
    if sep and sep.valid then
      for i = 1, #sep.fluidbox do
        local fb = sep.fluidbox[i]
        if fb and fb.name == "steam" then steam = steam + fb.amount; temp = fb.temperature end
      end
      sulfur = sep.get_inventory(defines.inventory.assembling_machine_output).get_item_count("sulfur")
    end
    ctx.check(sep and sep.valid and sep.products_finished >= 2 and steam > 0 and math.abs(temp - 165) < 0.5 and sulfur >= 2,
      "usine chimique : vapeur a 165 C et soufre", string.format("%d fabrications, vapeur %.0f a %.0f C, soufre %d",
        sep and sep.valid and sep.products_finished or 0, steam, temp, sulfur))
    local fl = st.flare
    ctx.check(fl and fl.valid and fl.products_finished >= 1, "torchere : gaz volcanique brule", fl and fl.valid and fl.products_finished or 0)
    local en = st.engine
    local ld = st.load
    ctx.check(en and en.valid and ld and ld.valid and ld.products_finished >= 1,
      "machine a vapeur : la vapeur a 165 C alimente seule un assembleur", ld and ld.valid and ld.products_finished or 0)
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    if st.well_pos then add("capteur-z1-jour", st.well_pos[1], st.well_pos[2], 1, 0, { aa = false }) end
    add("chaine-geothermie-z1-jour", CX, CY, 1, 0, { aa = false })
  end,
}
