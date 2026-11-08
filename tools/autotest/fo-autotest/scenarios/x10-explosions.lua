--[[
  Lot X10, Q5 (7/11) : IDENTITÉ près du joueur de l'explosion de mort recréée par script (lead : « même entité
  d'explosion, au même point ; le moteur vanilla la crée-t-il à die() ou avec un délai ? »). Joué deux fois sur la
  sauvegarde du DC, même source, avec et sans le lot (base : require du lot retirés) ; les journaux se comparent ligne à
  ligne. Nom dans KIT_EGAL.
  Critères figés : fo-logs6-11-07_X10\Q5_CRITERES_2026-11-07.md (C6 et C8).
  C8, identité : quatre morts par die() à 12 tuiles à l'est du joueur, une à la fois : « small-biter » (vanilla, explosion
  vide « small-biter-die »), le premier soldat « fo-scarlet-* » (« blood-explosion-big »), la première unité « fo-robot-* »
  (« explosion » ou « big-explosion », animée), un ver « small-worm-turret » (« small-worm-die »). Après chaque die(), dans
  le même tick (+0) puis à chaque tick jusqu'à +25 : toute entité de type explosion dans un rayon de 1,5 tuile du point de
  la mort est notée (nom, premier tick vu, écart de position, orientation si lisible), et le cadavre (premier tick vu).
  C6, règle (avec le lot seulement) : small-biter tué à 200 tuiles (créée), à 300 tuiles (rien, cadavre), à 300 tuiles
  avec actif = false (créée) ; compteurs de « fo-explosions-mort » lus juste avant et juste après die().
]]

local S = {
  description = "X10 Q5 : identite de l'explosion de mort recreee (moment, point, nom), avec et sans le lot",
  check_tick = -1,
}
local SUIVI = 25    -- unités
local SUIVI_VER = 200 -- vers : mort animée (F157 : 13 ticks pour les tourelles)
local FIN = 400
local REGLE = { -- C6 (avec le lot) : t relatif, distance à l'est, attendu
  { nom = "BORD", t = 190, dx = 200, attendu = "crees" },
  { nom = "LOIN", t = 200, dx = 300, attendu = "loin" },
  { nom = "TEMOIN", t = 210, dx = 300, dy = 6, attendu = "crees", temoin = true },
}

local function choisir()
  local noms = {}
  for name in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "unit" } })) do noms[#noms + 1] = name end
  table.sort(noms)
  local soldat, robot
  for _, n in ipairs(noms) do
    if not soldat and n:find("^fo%-scarlet%-") then soldat = n end
    if not robot and n:find("^fo%-robot%-") then robot = n end
  end
  return { { cle = "biter", nom = "small-biter", t = 30 }, { cle = "soldat", nom = soldat, t = 70 }, { cle = "robot", nom = robot, t = 110 },
    { cle = "ver", nom = "small-worm-turret", t = 150, suivi = SUIVI_VER } }
end

S.init = function(ctx)
  local t = game.tick
  S.check_tick = t + FIN
  local st = ctx.state()
  st.debut, st.suivis, st.fini = t, {}, {}
  ctx.call("profiler", false, false)
  local p = game.connected_players[1]
  ctx.check(p ~= nil, "un joueur connecte (le personnage du DC)", #game.connected_players)
  if not p then return end
  st.px, st.py, st.s = p.position.x, p.position.y, p.surface.index
  st.etapes = choisir()
  local lot = remote.interfaces["fo-explosions-mort"] ~= nil
  st.lot = lot
  ctx.log("lot Q5 (interface fo-explosions-mort) : " .. (lot and "PRESENT" or "absent (base)"))
  local surf = p.surface
  for _, r in ipairs(REGLE) do surf.request_to_generate_chunks({ st.px + r.dx, st.py + (r.dy or 0) }, 1) end
  surf.force_generate_chunk_requests()
  st.regle = {}
end

local function scruter(ctx, st, sv, tick)
  local surf = game.surfaces[st.s]
  local k = tick - sv.tick
  for _, x in ipairs(surf.find_entities_filtered({ type = "explosion", position = { sv.x, sv.y }, radius = 3 })) do
    local cle = x.name
    if not sv.vus[cle] then
      sv.vus[cle] = true
      local ok, o = pcall(function() return x.orientation end) -- lisible sur certains types seulement
      sv.lignes[#sv.lignes + 1] = string.format("explosion %s vue a +%d, ecart (%.4f, %.4f), orientation %s", cle, k,
        x.position.x - sv.x, x.position.y - sv.y, ok and string.format("%.3f", o) or "illisible")
    end
  end
  if not sv.corps then
    local c = surf.find_entities_filtered({ type = "corpse", position = { sv.x, sv.y }, radius = 1.5 })
    for _, x in ipairs(c) do
      if x.name:find(sv.unite, 1, true) or x.name:find("remnants", 1, true) or x.name:find("corpse", 1, true) then
        sv.corps = string.format("cadavre %s vu a +%d", x.name, k)
        break
      end
    end
  end
end

S.tick = function(ctx, e)
  local st = ctx.state()
  if not st.debut or not st.px then return end
  local rel = e.tick - st.debut
  if rel == 10 and st.lot then ctx.remote("fo-explosions-mort", "releve") end
  for _, et in ipairs(st.etapes) do
    if rel == et.t then
      if not et.nom then
        ctx.log(et.cle .. " : aucun prototype trouve, etape sautee")
      else
        local surf = game.surfaces[st.s]
        local pos = surf.find_non_colliding_position(et.nom, { st.px + 12 + 6 * (et.t - 30) / 40, st.py }, 8, 0.5)
        local u = pos and surf.create_entity({ name = et.nom, position = pos, force = "enemy" })
        ctx.check(u ~= nil, et.cle .. " : unite posee (" .. et.nom .. ")")
        if u then
          local sv = { cle = et.cle, unite = et.nom, x = u.position.x, y = u.position.y, tick = e.tick, vus = {}, lignes = {},
            suivi = et.suivi or SUIVI }
          ctx.log(string.format("%s (%s) : mort en (%.4f, %.4f) au tick %d", et.cle, et.nom, sv.x, sv.y, e.tick))
          u.die()
          scruter(ctx, st, sv, e.tick) -- +0 : dans le même tick, juste après die()
          st.suivis[#st.suivis + 1] = sv
        end
      end
    end
  end
  if st.lot then
    for _, r in ipairs(REGLE) do
      if rel == r.t then
        local surf = game.surfaces[st.s]
        local pos = surf.find_non_colliding_position("small-biter", { st.px + r.dx, st.py + (r.dy or 0) }, 8, 0.5)
        local u = pos and surf.create_entity({ name = "small-biter", position = pos, force = "enemy" })
        if not u then
          ctx.check(false, "C6 " .. r.nom .. " : biter pose")
        else
          if r.temoin then ctx.remote("fo-explosions-mort", "actif", false) end
          local a = ctx.remote("fo-explosions-mort", "stats")
          local mx, my = u.position.x, u.position.y
          u.die()
          local b = ctx.remote("fo-explosions-mort", "stats")
          if r.temoin then ctx.remote("fo-explosions-mort", "actif", true) end
          local corps = #surf.find_entities_filtered({ type = "corpse", position = { mx, my }, radius = 1.5 })
          local dc, dl = b.crees - a.crees, b.loin - a.loin
          local dist = math.max(math.abs(mx - st.px), math.abs(my - st.py))
          ctx.log(string.format("C6 %s : mort a %.1f tuiles du joueur ; pendant die() : crees %+d, loin %+d, sans point %+d ; cadavres %d",
            r.nom, dist, dc, dl, b.sans_point - a.sans_point, corps))
          if r.attendu == "crees" then
            ctx.check(dc == 1 and dl == 0, "C6 " .. r.nom .. " : explosion recreee pendant die()", string.format("crees %+d loin %+d", dc, dl))
          else
            ctx.check(dc == 0 and dl == 1 and corps >= 1, "C6 " .. r.nom .. " : rien de cree, cadavre present",
              string.format("crees %+d loin %+d cadavres %d", dc, dl, corps))
          end
          st.regle[#st.regle + 1] = r.nom
        end
      end
    end
  end
  for i = #st.suivis, 1, -1 do
    local sv = st.suivis[i]
    if e.tick > sv.tick then scruter(ctx, st, sv, e.tick) end
    if e.tick - sv.tick >= sv.suivi then
      for _, l in ipairs(sv.lignes) do ctx.log(string.format("%s (%s) : %s", sv.cle, sv.unite, l)) end
      ctx.log(string.format("%s (%s) : %s ; %d explosion(s) differente(s)", sv.cle, sv.unite, sv.corps or "aucun cadavre vu", #sv.lignes))
      ctx.check(#sv.lignes >= 1, sv.cle .. " : au moins une explosion vue au point de la mort", #sv.lignes)
      st.fini[#st.fini + 1] = sv.cle
      table.remove(st.suivis, i)
    end
  end
end

S.finish = function(ctx)
  local st = ctx.state()
  ctx.check(st.fini and #st.fini >= 3, "morts suivies (C8)", st.fini and #st.fini or 0)
  if st.lot then
    ctx.check(#st.regle == #REGLE, "C6 : morts de la regle jouees", #st.regle .. " / " .. #REGLE)
    local s = ctx.remote("fo-explosions-mort", "stats")
    ctx.log(string.format("fo-explosions-mort : crees %d, loin %d, sans point %d, ratees %d", s.crees, s.loin, s.sans_point, s.ratees))
  end
end

return S
