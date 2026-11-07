--[[
  Lot X10, Q5 (7/11) : morts habillées par script, en MOTEUR RÉEL sur la sauvegarde du DC (banc.py --sauvegarde ; un
  joueur connecté existe en --benchmark sur une sauvegarde : le personnage du DC, immobile). Nom dans KIT_EGAL.
  Au tick D (init) : relevé des joueurs tout de suite (interface « fo-morts »). Puis, un biter « small-biter » (force enemy)
  posé et tué par die() à chaque étape, à l'est du joueur :
      D + 30  PRES   à  12 tuiles  -> explosion recréée (crees + 1)
      D + 40  BORD   à 200 tuiles  -> recréée (encore dans la vue du DC en 4K au zoom 0,3)
      D + 50  LOIN   à 300 tuiles  -> rien (loin + 1) ; le cadavre reste
      D + 60  TEMOIN à 300 tuiles, réglage actif = false -> recréée (comme le moteur), puis actif = true
  Les compteurs sont lus juste avant et juste après die() (même tick) : l'écart est celui de CETTE mort si l'effet est levé
  pendant die() ; sinon le contrôle le dit (écart nul) et le bilan de fin compte tout. L'entité d'explosion est cherchée
  au point de la mort dans le même tick (une explosion vide vit environ 1 tick : contrôle indicatif, hors bilan).
]]

local S = {
  description = "X10 Q5 : explosions de mort recreees pres d'un joueur seulement (sauvegarde du DC)",
  check_tick = -1, -- fixé à l'init
}

local ETAPES = {
  { nom = "PRES", t = 30, dx = 12, attendu = "crees" },
  { nom = "BORD", t = 40, dx = 200, attendu = "crees" },
  { nom = "LOIN", t = 50, dx = 300, attendu = "loin" },
  { nom = "TEMOIN", t = 60, dx = 300, dy = 6, attendu = "crees", temoin = true },
}
local FIN = 120

local function stats(ctx) return ctx.remote("fo-morts", "stats") end

S.init = function(ctx)
  local t = game.tick
  S.check_tick = t + FIN
  local st = ctx.state()
  st.debut, st.res = t, {}
  log(string.format("[FO-PERF4] debut tick %d (%.1f min de jeu) ; mode x10-morts", t, t / 3600))
  ctx.call("profiler", false, false)
  ctx.check(t > 0, "partie chargee depuis une sauvegarde (tick de depart > 0)", t)
  local p = game.connected_players[1]
  ctx.check(p ~= nil, "un joueur connecte (le personnage du DC)", #game.connected_players)
  if not p then return end
  st.px, st.py, st.s = p.position.x, p.position.y, p.surface.index
  -- chunks des points lointains générés d'abord (la carte du DC les a sans doute ; sinon create_entity échoue)
  local surf = p.surface
  for _, e in ipairs(ETAPES) do
    surf.request_to_generate_chunks({ st.px + e.dx, st.py + (e.dy or 0) }, 1)
  end
  surf.force_generate_chunk_requests()
  ctx.remote("fo-morts", "releve")
  local s0 = stats(ctx)
  ctx.log(string.format("joueur %s en (%.1f, %.1f) surface %d ; fo-morts : actif %s, joueurs releves %d, crees %d, loin %d",
    p.name, st.px, st.py, st.s, tostring(s0.actif), s0.joueurs, s0.crees, s0.loin))
  ctx.check(s0.actif == true and s0.joueurs >= 1, "releve fait, regle active", s0.joueurs)
  st.s0 = s0
end

S.tick = function(ctx, e)
  local st = ctx.state()
  if not st.debut or not st.px then return end
  local rel = e.tick - st.debut
  for _, et in ipairs(ETAPES) do
    if rel == et.t then
      local surf = game.surfaces[st.s]
      local want = { st.px + et.dx, st.py + (et.dy or 0) }
      local pos = surf.find_non_colliding_position("small-biter", want, 8, 0.5)
      if not pos then
        ctx.check(false, et.nom .. " : place pour le biter", string.format("(%.0f, %.0f)", want[1], want[2]))
        return
      end
      local u = surf.create_entity({ name = "small-biter", position = pos, force = "enemy" })
      if not u then
        ctx.check(false, et.nom .. " : biter pose", string.format("(%.1f, %.1f)", pos.x, pos.y))
        return
      end
      if et.temoin then ctx.remote("fo-morts", "actif", false) end
      local a = stats(ctx)
      local mx, my = u.position.x, u.position.y
      u.die()
      local b = stats(ctx)
      local vues = #surf.find_entities_filtered({ name = "small-biter-die", position = { mx, my }, radius = 2 })
      local corps = #surf.find_entities_filtered({ type = "corpse", position = { mx, my }, radius = 2 })
      if et.temoin then ctx.remote("fo-morts", "actif", true) end
      local dc, dl, ds = b.crees - a.crees, b.loin - a.loin, b.sans_point - a.sans_point
      local dist = math.max(math.abs(mx - st.px), math.abs(my - st.py))
      ctx.log(string.format("%s : mort en (%.1f, %.1f), %.1f tuiles du joueur (Tchebychev) ; pendant die() : crees %+d, loin %+d, "
        .. "sans point %+d ; entite d'explosion vue au point : %d ; cadavres au point : %d", et.nom, mx, my, dist, dc, dl, ds, vues, corps))
      st.res[#st.res + 1] = { nom = et.nom, dc = dc, dl = dl, ds = ds, vues = vues, corps = corps, dist = dist }
      if et.attendu == "crees" then
        ctx.check(dc == 1 and dl == 0 and ds == 0, et.nom .. " : explosion recreee pendant die()", string.format("crees %+d loin %+d", dc, dl))
      else
        ctx.check(dc == 0 and dl == 1 and ds == 0, et.nom .. " : aucune explosion (loin) pendant die()", string.format("crees %+d loin %+d", dc, dl))
        ctx.check(corps >= 1, et.nom .. " : le cadavre reste", corps)
      end
    end
  end
end

S.finish = function(ctx)
  local st = ctx.state()
  if not st.s0 then return end
  local s1 = stats(ctx)
  ctx.check(#st.res == #ETAPES, "etapes jouees", #st.res .. " / " .. #ETAPES)
  ctx.check(s1.actif == true, "regle active a la fin (temoin rendu)")
  ctx.check(s1.ratees == st.s0.ratees, "aucune explosion ratee", s1.ratees - st.s0.ratees)
  ctx.log(string.format("fin : depuis l'init, crees %+d, loin %+d, sans point %+d (morts de la partie comprises)",
    s1.crees - st.s0.crees, s1.loin - st.s0.loin, s1.sans_point - st.s0.sans_point))
end

return S
