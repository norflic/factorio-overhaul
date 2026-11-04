-- Scénario greffé du lot DA-ENERGIE (4/11) : la PISCINE D'ENTREPOSAGE, le DÉPÔT GÉOLOGIQUE et l'AMPLIFICATEUR DE RÉSONANCE
-- avec leurs vraies images, EN MARCHE, de jour et de nuit, chacun à côté du sprite vanilla qu'il remplace.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui DA-ENERGIE -- 400 da-energie <source>                 (contrôles)
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache" --qui DA-ENERGIE -- 400 da-energie <source>
-- Piscine : recette du refroidissement, 10 cellules usées : elle TRAVAILLE (pont polaire qui tourne, lueur Tcherenkov). Dépôt :
-- colis vitrifiés insérés. Amplificateur : alimenté, 3 modules de vitesse, un assembleur 2 à portée qui doit recevoir l'effet.
-- Réacteur à sels fondus : combustible, chauffé à 800 °C par script. Capteur géothermique : 4 directions sur fumerolles,
-- sortie vidée par un tuyau infini, chevalet vanilla à côté. Témoins vanilla : assembleur 2, coffre d'acier, balise, réacteur. Captures : zoom 1 jour et nuit, zoom 2 jour ; 2 témoins À L'ARRÊT
-- (piscine sans recette, amplificateur sans module) pour voir la lueur éteinte. Journal : [FO-DA-ENERGIE].

local X0, Y0 = 3200, 3000
local SITES = {
  { name = "fo-cooling-pool", size = 4, vanilla = "assembling-machine-2", vsize = 3 },
  { name = "fo-geological-repository", size = 6, vanilla = "steel-chest", vsize = 1 },
  { name = "fo-resonance-amplifier", size = 3, vanilla = "beacon", vsize = 3 },
  { name = "fo-molten-salt-reactor", size = 5, vanilla = "nuclear-reactor", vsize = 5 },
}
-- capteur géothermique : une base par direction, raccord aux positions du chevalet vanilla (tuiles, repère du jeu)
local SORTIES = { north = { 1, -2 }, east = { 2, -1 }, south = { -1, 2 }, west = { -2, 1 } }
local DIRS = { "north", "east", "south", "west" }

return {
  description = "DA-ENERGIE : piscine, depot geologique, amplificateur de resonance en marche, a cote du vanilla, jour et nuit",
  base = nil,
  check_tick = 300,
  shots_delay = 320,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.sites = {}
    ctx.prepare_area(X0 - 12, Y0 - 12, X0 + 80, Y0 + 50, "concrete")
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
    for _, f in ipairs(SITES) do
      local h = f.size / 2
      local px, py = x + h + 6, Y0 + 12
      local m = s.create_entity({ name = f.name, position = { px, py }, force = force })
      local vh = f.vsize / 2
      local v = s.create_entity({ name = f.vanilla, position = { px - h - vh - 2, py + h - vh }, force = force })
      st.sites[#st.sites + 1] = { f = f, m = m, v = v, x = px, y = py, side = f.size }
      x = x + f.size + f.vsize + 12
    end
    local pool, depot, amp = st.sites[1].m, st.sites[2].m, st.sites[3].m
    if pool then
      force.recipes["fo-spent-fuel-cooling"].enabled = true
      pool.set_recipe("fo-spent-fuel-cooling")
      pool.insert({ name = "used-up-uranium-fuel-cell", count = 20 })
    end
    if depot then st.depot_mis = depot.insert({ name = "fo-vitrified-waste", count = 40 }) end
    if amp then
      local inv = amp.get_module_inventory()
      st.modules = inv and inv.insert({ name = "speed-module", count = 3 }) or 0
      -- assembleur 2 à portée (portée 3) : il doit recevoir l'effet de l'amplificateur
      local a = st.sites[3]
      st.cible = s.create_entity({ name = "assembling-machine-2", position = { a.x, a.y + a.side / 2 + 2 }, force = force })
      if st.cible then
        st.cible.set_recipe("iron-gear-wheel")
        st.cible.insert({ name = "iron-plate", count = 200 })
      end
    end
    -- témoins à l'arrêt : piscine sans recette, amplificateur sans module (la source du mod de test couvre toute la zone)
    st.arret = {
      s.create_entity({ name = "fo-cooling-pool", position = { X0 + 8, Y0 + 32 }, force = force }),
      s.create_entity({ name = "fo-resonance-amplifier", position = { X0 + 16, Y0 + 32 }, force = force }),
    }
    -- réacteurs (sel et vanilla) : combustible, puis CHAUFFÉS par script (heat_picture visible au tick 300)
    local msr, vr = st.sites[4].m, st.sites[4].v
    if msr then msr.insert({ name = "fo-thorium-salt-cell", count = 2 }); msr.temperature = 800 end
    if vr then vr.insert({ name = "uranium-fuel-cell", count = 2 }); vr.temperature = 800 end
    -- capteurs géothermiques (4 directions) sur fumerolles, sortie vidée par un tuyau infini ; chevalet vanilla (sud)
    st.taps = {}
    local ty = Y0 + 44
    for i, d in ipairs(DIRS) do
      local px, py = X0 + 6.5 + (i - 1) * 6, ty + 0.5
      s.create_entity({ name = "fo-fumarole", position = { px, py }, amount = 600000 })
      local t = s.create_entity({ name = "fo-geothermal-tap", position = { px, py }, direction = defines.direction[d], force = force })
      local o = SORTIES[d]
      local ip = s.create_entity({ name = "infinity-pipe", position = { px + o[1], py + o[2] }, force = force })
      if ip then ip.set_infinity_pipe_filter({ name = "fo-volcanic-gas", percentage = 0, mode = "exactly" }) end
      st.taps[#st.taps + 1] = { d = d, m = t, x = px, y = py }
    end
    do
      local px, py = X0 + 6.5 + 4 * 6 + 1, ty + 0.5
      s.create_entity({ name = "crude-oil", position = { px, py }, amount = 600000 })
      st.pumpjack = s.create_entity({ name = "pumpjack", position = { px, py }, direction = defines.direction.south, force = force })
      local ip = s.create_entity({ name = "infinity-pipe", position = { px - 1, py + 2 }, force = force })
      if ip then ip.set_infinity_pipe_filter({ name = "crude-oil", percentage = 0, mode = "exactly" }) end
    end
    local poses = 0
    for _, c in ipairs(st.sites) do if c.m and c.v then poses = poses + 1 end end
    for _, t in ipairs(st.taps) do if t.m then poses = poses + 1 end end
    ctx.check(poses == 8, "8 batiments poses (4 a cote de leur temoin vanilla, capteur dans les 4 directions)", poses .. " / 8")
  end,

  finish = function(ctx)
    local st = ctx.state()
    local pool, depot, amp = st.sites[1].m, st.sites[2].m, st.sites[3].m
    ctx.check(pool and pool.valid and pool.is_crafting(), "piscine : en marche (refroidissement des cellules)",
      pool and pool.valid and ("statut " .. tostring(pool.status)) or "absente")
    ctx.check(depot and depot.valid and st.depot_mis == 40 and depot.get_inventory(defines.inventory.chest).get_item_count("fo-vitrified-waste") == 40,
      "depot : 40 colis vitrifies ranges (200 cases)", tostring(st.depot_mis))
    local eff = st.cible and st.cible.valid and st.cible.effects
    local vit = eff and eff.speed and eff.speed.bonus or 0
    ctx.check(amp and amp.valid and st.modules == 3 and vit > 0, "amplificateur : 3 modules, effet recu par l'assembleur a portee",
      string.format("modules %s, bonus de vitesse %.3f", tostring(st.modules), vit))
    local msr = st.sites[4].m
    ctx.check(msr and msr.valid and msr.temperature > 500 and msr.status == defines.entity_status.working,
      "reacteur a sels fondus : en marche et chaud (heat_picture)", msr and msr.valid and
      string.format("statut %s, %.0f degres", tostring(msr.status), msr.temperature) or "absent")
    local mines, det = 0, {}
    for _, t in ipairs(st.taps) do
      local ok = t.m and t.m.valid and t.m.status == defines.entity_status.working
      if ok then mines = mines + 1 end
      det[#det + 1] = t.d .. " " .. (t.m and t.m.valid and tostring(t.m.status) or "absent")
    end
    ctx.check(mines == 4, "capteur geothermique : capte dans les 4 directions (raccord au tuyau)", table.concat(det, ", "))
    for _, c in ipairs(st.sites) do
      local p = c.m and c.m.valid and c.m.prototype
      ctx.check(p and p.drawing_box ~= nil and math.abs(p.collision_box.right_bottom.x - (c.side / 2 - 0.3)) < 0.01,
        c.f.name .. " : boites inchangees (collision a l'emprise - 0,3), boite de dessin posee",
        p and string.format("collision %.2f, emprise %d", p.collision_box.right_bottom.x, c.side) or "absent")
    end
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    for _, c in ipairs(st.sites) do
      local vs = c.f.vsize
      local cx = c.x - (vs + 2) / 2
      local cy = c.y - c.side * 0.3
      local w, h = math.ceil((c.side + vs + 8) * 32), math.ceil((c.side * 1.7 + 6) * 32)
      for _, nuit in ipairs({ false, true }) do
        add(string.format("%s-z1-%s", c.f.name, nuit and "nuit" or "jour"), cx, cy, 1, nuit and 0.5 or 0, { res = { w, h }, info = false, aa = true })
      end
      add(c.f.name .. "-z2-jour", c.x, cy, 2, 0, { res = { math.ceil((c.side + 5) * 64), math.ceil((c.side * 1.7 + 6) * 64) }, info = false, aa = true })
    end
    local ty = Y0 + 44.5
    for _, nuit in ipairs({ false, true }) do
      add("fo-geothermal-tap-4dir-z1-" .. (nuit and "nuit" or "jour"), X0 + 18, ty - 1, 1, nuit and 0.5 or 0, { res = { 1120, 352 }, info = false, aa = true })
    end
    add("fo-geothermal-tap-sud-z2-jour", X0 + 21, ty - 1, 2, 0, { res = { 1100, 520 }, info = false, aa = true })
    add("arret-z1-jour", X0 + 12, Y0 + 31, 1, 0, { res = { 640, 384 }, info = false, aa = true })
    add("arret-z1-nuit", X0 + 12, Y0 + 31, 1, 0.5, { res = { 640, 384 }, info = false, aa = true })
  end,
}
