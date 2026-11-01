-- Lot RB-V1 (1/11) : LES FEUILLES DE JEU d'un robot, vues en moteur. Commun aux scénarios rb-galerie-<robot> (rb-galerie : le Trotte-Vapeur).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache" --qui RBV1 -- 400 rb-galerie-levite <source>
-- Une unité par direction de marche (16), partie du centre d'une roue, en marche vers l'extérieur ; à l'est, une ligne d'un robot par
-- propriétaire (couleur de la peinture) qui tire sur 3 vers inactifs. Géant : 1 araignée à l'arrêt, 1 en marche par autopilote, canon servi par le mod.
-- Images : roue au zoom 1 et 2, ligne au zoom 2.

local X0, Y0 = 1500, 1500
local OWNERS = { "player", "scarlet", "azure", "emerald", "amber" }
local R0, DEST = 4, 40
local LX = X0 + 44

return function(ROBOT, geant, shots_res)
  local RES = shots_res or { 1800, 1800 }
  return {
    description = "RB-V1 : feuilles de jeu de " .. ROBOT,
    base = nil,
    check_tick = 300,
    shots_delay = 60,

    init = function(ctx)
      local s = ctx.surface()
      local st = ctx.state()
      ctx.prepare_area(X0 - 30, Y0 - 30, LX + 26, Y0 + 30, "concrete")
      game.map_settings.enemy_expansion.enabled = false
      for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 150, Y0 - 150 }, { LX + 150, Y0 + 150 } } })) do
        en.destroy()
      end
      st.roue, st.ligne, st.vers = {}, {}, {}
      if geant then
        local a = s.create_entity({ name = "fo-robot-player-" .. ROBOT, position = { X0, Y0 + 6 }, force = "player" })
        local b = s.create_entity({ name = "fo-robot-player-" .. ROBOT, position = { LX - 6, Y0 + 6 }, force = "player" })
        if b then b.autopilot_destination = { LX + 30, Y0 + 6 } end
        st.geants = { a, b }
        ctx.check(a ~= nil and b ~= nil, "2 geants poses", "")
        return
      end
      for k = 0, 15 do
        local a = 2 * math.pi * k / 16
        local dx, dy = math.sin(a), -math.cos(a)
        local u = s.create_entity({ name = "fo-robot-player-" .. ROBOT, position = { X0 + R0 * dx, Y0 + R0 * dy }, force = "player" })
        if u then
          u.set_command({ type = defines.command.go_to_location, destination = { X0 + DEST * dx, Y0 + DEST * dy }, distraction = defines.distraction.none,
            radius = 1 })
        end
        st.roue[k + 1] = { u = u, dx = dx, dy = dy, k = k }
      end
      for i, o in ipairs(OWNERS) do
        st.ligne[i] = s.create_entity({ name = "fo-robot-" .. o .. "-" .. ROBOT, position = { LX, Y0 - 10 + 5 * (i - 1) }, force = "player" })
      end
      for i = 1, 3 do
        local w = s.create_entity({ name = "behemoth-worm-turret", position = { LX + 16, Y0 - 6 + 6 * (i - 1) }, force = "enemy" })
        if w then w.active = false end
        st.vers[i] = w
      end
      local n = 0
      for _, c in ipairs(st.roue) do if c.u then n = n + 1 end end
      ctx.check(n == 16, "16 unites de la roue", n .. " / 16")
      local m = 0
      for i = 1, #OWNERS do if st.ligne[i] then m = m + 1 end end
      ctx.check(m == #OWNERS, "un robot par proprietaire", m .. " / " .. #OWNERS)
    end,

    finish = function(ctx)
      local st = ctx.state()
      if geant then
        local g = st.geants[2]
        ctx.check(g and g.valid and g.position.x > LX, "le geant marche", g and g.valid and string.format("x = %.1f, depart %.1f", g.position.x, LX - 6) or "absent")
        return
      end
      local bons, mini, maxi, maxe = 0, 1e9, 0, 0
      for _, c in ipairs(st.roue) do
        if c.u and c.u.valid then
          local px, py = c.u.position.x - X0, c.u.position.y - Y0
          local r = px * c.dx + py * c.dy
          local ecart = math.abs(px * c.dy - py * c.dx)
          mini, maxi = math.min(mini, r), math.max(maxi, r)
          maxe = math.max(maxe, ecart)
          if r > R0 + 10 then bons = bons + 1 end -- a avancé dans sa direction : le chemin et la séparation écartent de la droite (écart rapporté)
        end
      end
      ctx.check(bons == 16, "les 16 unites marchent dans leur direction", string.format("%d / 16, rayon %.1f a %.1f, ecart lateral max %.1f", bons, mini, maxi, maxe))
      local degats = 0
      for _, w in ipairs(st.vers) do
        if w.valid then degats = degats + (w.prototype.max_health - w.health) else degats = degats + 750 end
      end
      ctx.check(degats > 0 or ROBOT == "bellwether", "la ligne tire (animation de tir ; la Cloche ne tire pas)", string.format("%.0f PV retires aux vers", degats))
    end,

    shots = function(ctx, add)
      if geant then
        add("geant-z1-a", X0 + 8, Y0, 1, 0, { res = { 1400, 1000 }, info = false, aa = false })
        add("geant-repos-z2", X0, Y0 + 1, 2, 0, { res = { 1400, 1600 }, info = false, aa = false })
        add("geant-marche-a", LX + 8, Y0 + 1, 1, 0, { res = { 1400, 1000 }, info = false, aa = false })
        add("geant-marche-b", LX + 16, Y0 + 1, 1, 0, { res = { 1400, 1000 }, info = false, aa = false })
        add("geant-marche-c", LX + 24, Y0 + 1, 1, 0, { res = { 1400, 1000 }, info = false, aa = false })
        return
      end
      add("roue-z1-a", X0, Y0, 1, 0, { res = { 1400, 1400 }, info = false, aa = false })
      add("roue-z2-a", X0, Y0, 2, 0, { res = RES, info = false, aa = false })
      add("ligne-z2-a", LX, Y0, 2, 0, { res = { 1000, 1400 }, info = false, aa = false })
      add("ligne-z2-nuit", LX, Y0, 2, 0.5, { res = { 1000, 1400 }, info = false, aa = false })
    end,
  }
end
