--[[
  Lot X10, GAIN de Q5 et Q5b (critères figés : fo-logs\2026-11-07_X10\Q5_CRITERES_2026-11-07.md, C7 ;
  Q5b_CRITERES_2026-11-07.md, B5). Sauvegarde du DC (banc.py --sauvegarde), le joueur connecté reste chez lui. Deux noms,
  même source, seul change le réglage du lot :
      x10-gain-morts-a : fo-explosions-mort.actif(false), explosions partout (comme vanilla) ;
      x10-gain-morts-b : fo-explosions-mort.actif(true), la règle (rien à plus de 224 tuiles du joueur).
  Les deux scènes sont à plus de 500 tuiles du joueur (est) :
    A (Q5, unités) : 24 mitrailleuses armées derrière un mur, 3 vagues de 60 biters (30 petits, 20 moyens, 10 gros) aux
      ticks relatifs 300, 900 et 1 500 ; fenêtre mesurée [300, 2 100[.
    B (Q5b, bâtiments) : un bloc sans défense de bâtiments « player-creation » (assembleurs, bras, tapis, poteaux, murs),
      attaqué par 80 biters (40 moyens, 40 gros) au tick relatif 2 100 ; fenêtre mesurée [2 100, 3 300[.
  Lecture : moteur-outils\x10_gain_lecture.py (wholeUpdate, particleUpdate, scriptUpdate par fenêtre, A contre B).
  Le journal donne les morts de chaque scène (on_entity_died n'est pas lu : le décompte vient des entités restantes) et
  les compteurs de fo-explosions-mort. La partie est rejouée à l'identique entre A et B (F238) : seules les explosions
  changent, et elles ne touchent pas au jeu.
]]

local DX = 700        -- tuiles à l'est du joueur (scène A) ; la scène B est 160 tuiles plus au sud
local DYB = 160
local WAVES = { 300, 900, 1500 }
local WAVE = { { "small-biter", 30 }, { "medium-biter", 20 }, { "big-biter", 10 } }
local ATTAQUE_B = 2100
local GROUPE_B = { { "medium-biter", 40 }, { "big-biter", 40 } }
local FIN = 3300

return function(name, actif)
  local S = {
    description = "X10 gain de Q5/Q5b : combats et bloc detruit a plus de 500 tuiles du joueur, fo-explosions-mort.actif = "
      .. tostring(actif),
    check_tick = -1,
  }

  -- Événements de la fenêtre (amendement du 8/11, AMENDEMENT_Q5_2026-11-08.md, point b) : morts vues par le lot
  -- (créées + loin + sans point) et effets script des autres lots (tirs des chargeurs : fo-tirs, évts par âge + autres).
  local function compte(ctx)
    local m, t = -1, -1
    if remote.interfaces["fo-explosions-mort"] then
      local z = ctx.remote("fo-explosions-mort", "stats")
      m = z.crees + z.loin + z.sans_point
    end
    if remote.interfaces["fo-tirs"] then
      local s = ctx.remote("fo-tirs", "stats")
      t = s.autres or 0
      for _, a in ipairs(s.ages or {}) do t = t + (a.evts or 0) end
    end
    return { morts = m, tirs = t }
  end

  local function journal_fenetre(ctx, st, nom, rel)
    local c = compte(ctx)
    local d = st.borne
    if d then
      ctx.log(string.format("FENETRE %s [%d, %d[ : %d ticks, morts vues par le lot %d, effets script d'autres lots %d", nom, d.rel, rel,
        rel - d.rel, c.morts - d.morts, c.tirs - d.tirs))
    end
    st.borne = { rel = rel, morts = c.morts, tirs = c.tirs }
  end

  local function force(n)
    return game.forces[n] or game.create_force(n)
  end

  local function ligne(s, xa, ya)
    local f = force("fo-x10-ligne")
    game.forces.enemy.set_cease_fire(f, false)
    f.set_cease_fire(game.forces.enemy, false)
    local n = 0
    for row = 0, 1 do
      for k = 0, 11 do
        local t = s.create_entity({ name = "gun-turret", position = { xa - row * 3, ya - 18 + k * 3 }, force = f })
        if t then
          t.insert({ name = "firearm-magazine", count = 20 })
          n = n + 1
        end
      end
    end
    for y = -24, 24 do s.create_entity({ name = "stone-wall", position = { xa + 4.5, ya + y + 0.5 }, force = f }) end
    return n
  end

  local function bloc(s, xb, yb)
    local f = force("fo-x10-bloc")
    game.forces.enemy.set_cease_fire(f, false)
    local n = 0
    for i = 0, 7 do
      for j = 0, 7 do
        local x, y = xb + i * 6, yb + j * 6
        local e = s.create_entity({ name = "assembling-machine-1", position = { x + 1.5, y + 1.5 }, force = f })
        if e then n = n + 1 end
        for _, q in ipairs({ { "inserter", 3.5, 1.5 }, { "transport-belt", 4.5, 0.5 }, { "transport-belt", 4.5, 1.5 },
          { "transport-belt", 4.5, 2.5 }, { "small-electric-pole", 3.5, 3.5 }, { "stone-wall", 0.5, 4.5 },
          { "stone-wall", 1.5, 4.5 }, { "stone-wall", 2.5, 4.5 } }) do
          if s.create_entity({ name = q[1], position = { x + q[2], y + q[3] }, force = f }) then n = n + 1 end
        end
      end
    end
    return n
  end

  S.init = function(ctx)
    local t = game.tick
    S.check_tick = t + FIN
    local st = ctx.state()
    st.debut = t
    log(string.format("[FO-PERF4] debut tick %d (%.1f min de jeu) ; mode %s", t, t / 3600, name))
    ctx.call("profiler", false, false)
    local p = game.connected_players[1]
    ctx.check(t > 0 and p ~= nil, "sauvegarde du DC, un joueur connecte", #game.connected_players)
    if not p then return end
    local s = p.surface
    st.px, st.py = p.position.x, p.position.y
    local xa, ya = math.floor(st.px + DX), math.floor(st.py)
    local xb, yb = xa - 20, ya + DYB
    st.xa, st.ya, st.xb, st.yb = xa, ya, xb, yb
    -- même préparation dans A et B (hors des fenêtres mesurées)
    ctx.prepare_area(xa - 40, ya - 50, xa + 90, ya + 50, "dry-dirt")
    ctx.prepare_area(xb - 20, yb - 20, xb + 70, yb + 70, "dry-dirt")
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { xa - 150, ya - 150 }, { xa + 250, yb + 200 } } })) do
      en.destroy()
    end
    st.tourelles = ligne(s, xa, ya)
    st.batiments = bloc(s, xb, yb)
    ctx.log(string.format("scene A en (%d, %d) : %d tourelles ; scene B en (%d, %d) : %d batiments ; joueur en (%.1f, %.1f)",
      xa, ya, st.tourelles, xb, yb, st.batiments, st.px, st.py))
    ctx.check(st.tourelles == 24 and st.batiments >= 500, "scenes posees", st.tourelles .. " tourelles, " .. st.batiments .. " batiments")
  end

  S.tick = function(ctx, e)
    local st = ctx.state()
    if not st.debut or not st.xa then return end
    local rel = e.tick - st.debut
    local s = game.surfaces[1]
    if rel == 10 then
      if remote.interfaces["fo-explosions-mort"] then
        ctx.remote("fo-explosions-mort", "releve")
        ctx.remote("fo-explosions-mort", "actif", actif)
        local z = ctx.remote("fo-explosions-mort", "stats")
        st.z0 = z
        ctx.log(string.format("fo-explosions-mort : actif %s, joueurs releves %d", tostring(z.actif), z.joueurs))
        ctx.check(z.actif == actif and z.joueurs >= 1, "reglage pose et releve fait", tostring(z.actif))
      else
        ctx.check(false, "interface fo-explosions-mort presente (lot Q5)")
      end
    end
    if rel == WAVES[1] then journal_fenetre(ctx, st, "debut", rel) end
    if rel == ATTAQUE_B then journal_fenetre(ctx, st, "A", rel) end
    for _, w in ipairs(WAVES) do
      if rel == w then
        local grp = s.create_unit_group({ position = { st.xa + 40, st.ya }, force = "enemy" })
        for _, spec in ipairs(WAVE) do
          for i = 1, spec[2] do
            local pos = s.find_non_colliding_position(spec[1], { st.xa + 40 + (i % 6) * 2, st.ya - 12 + (i % 13) * 2 }, 10, 0.5)
            local u = pos and s.create_entity({ name = spec[1], position = pos, force = "enemy" })
            if u then grp.add_member(u) end
          end
        end
        grp.set_command({ type = defines.command.attack_area, destination = { st.xa, st.ya }, radius = 30,
          distraction = defines.distraction.by_anything })
      end
    end
    if rel == ATTAQUE_B then
      st.restants_a = s.count_entities_filtered({ force = "enemy", type = "unit", area = { { st.xa - 60, st.ya - 60 }, { st.xa + 100, st.ya + 60 } } })
      local grp = s.create_unit_group({ position = { st.xb + 90, st.yb + 24 }, force = "enemy" })
      for _, spec in ipairs(GROUPE_B) do
        for i = 1, spec[2] do
          local pos = s.find_non_colliding_position(spec[1], { st.xb + 90 + (i % 5) * 2, st.yb + (i % 20) * 2 }, 10, 0.5)
          local u = pos and s.create_entity({ name = spec[1], position = pos, force = "enemy" })
          if u then grp.add_member(u) end
        end
      end
      grp.set_command({ type = defines.command.attack_area, destination = { st.xb + 24, st.yb + 24 }, radius = 40,
        distraction = defines.distraction.by_anything })
    end
  end

  S.finish = function(ctx)
    local st = ctx.state()
    if not st.xa then return end
    journal_fenetre(ctx, st, "B", game.tick - st.debut)
    local s = game.surfaces[1]
    local restants_b = s.count_entities_filtered({ force = "fo-x10-bloc", area = { { st.xb - 20, st.yb - 20 }, { st.xb + 70, st.yb + 70 } } })
    ctx.log(string.format("scene A : biters encore en vie a la fin de la fenetre A : %s ; scene B : %d batiments detruits sur %d",
      tostring(st.restants_a), st.batiments - restants_b, st.batiments))
    ctx.check(st.batiments - restants_b > 0, "scene B : des batiments detruits", st.batiments - restants_b)
    if st.z0 then
      local z = ctx.remote("fo-explosions-mort", "stats")
      ctx.log(string.format("fo-explosions-mort depuis le tick +10 : crees %+d, loin %+d, sans point %+d, ratees %+d", z.crees - st.z0.crees,
        z.loin - st.z0.loin, z.sans_point - st.z0.sans_point, z.ratees - st.z0.ratees))
      ctx.check(z.ratees == st.z0.ratees, "aucune explosion ratee")
    end
  end

  return S
end
