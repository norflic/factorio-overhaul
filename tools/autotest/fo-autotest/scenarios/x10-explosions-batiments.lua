--[[
  Lot X10, Q5b (7/11) : explosions de mort des BÂTIMENTS recréées par script près d'un joueur seulement. Critères figés :
  fo-logs\2026-11-07_X10\Q5b_CRITERES_2026-11-07.md (B3 et B4). Joué sur la sauvegarde du DC, même source, avec et sans le
  lot (sans = les deux require du lot retirés) ; les journaux se comparent ligne à ligne. Nom dans KIT_EGAL.
  B4, identité : huit bâtiments (force player) posés puis tués par die() à l'est du joueur, à 10 tuiles l'un de l'autre :
  assembleur 1, tapis, bras, petit poteau, petite lampe, mur de pierre, coffre en bois, un assembleur à niveaux du mod.
  Après chaque die(), dans le même tick (+0) puis à chaque tick jusqu'à +60 : toute entité de type explosion dans un
  rayon de 4 tuiles du point de la mort (nom, premier tick vu, écart de position), et le reste (corpse : nom, tick).
  B3, règle (avec le lot seulement) : un assembleur 1 tué à 200 tuiles (créée), à 300 tuiles (rien, reste présent), à 300
  tuiles avec actif = false (créée) ; compteurs de « fo-explosions-mort » lus juste avant et juste après die().
]]

local S = {
  description = "X10 Q5b : identite de l'explosion de mort des batiments (moment, point, nom), avec et sans le lot",
  check_tick = -1,
}
local SUIVI = 60
local FIN = 330
local REGLE = {
  { nom = "BORD", t = 240, dx = 200, attendu = "crees" },
  { nom = "LOIN", t = 250, dx = 300, attendu = "loin" },
  { nom = "TEMOIN", t = 260, dx = 300, dy = 8, attendu = "crees", temoin = true },
}

local function assembleur_niveau()
  local noms = {}
  for name in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "assembling-machine" } })) do
    if name:find("^fo%-") and name:find("assembler%-%d+$") then noms[#noms + 1] = name end
  end
  table.sort(noms)
  return noms[1]
end

S.init = function(ctx)
  local t = game.tick
  S.check_tick = t + FIN
  local st = ctx.state()
  st.debut, st.suivis, st.fini, st.regle = t, {}, {}, {}
  ctx.call("profiler", false, false)
  local p = game.connected_players[1]
  ctx.check(p ~= nil, "un joueur connecte (le personnage du DC)", #game.connected_players)
  if not p then return end
  st.px, st.py, st.s = p.position.x, p.position.y, p.surface.index
  local noms = { "assembling-machine-1", "transport-belt", "inserter", "small-electric-pole", "small-lamp", "stone-wall",
    "wooden-chest", assembleur_niveau() }
  st.etapes = {}
  for i, n in ipairs(noms) do st.etapes[i] = { nom = n, t = 30 + 20 * (i - 1), dx = 12 + 10 * (i - 1) } end
  st.lot = remote.interfaces["fo-explosions-mort"] ~= nil
  ctx.log("lot Q5/Q5b (interface fo-explosions-mort) : " .. (st.lot and "PRESENT" or "absent (base)")
    .. " ; assembleur a niveaux : " .. tostring(noms[8]))
  local surf = p.surface
  for _, r in ipairs(REGLE) do surf.request_to_generate_chunks({ st.px + r.dx, st.py + (r.dy or 0) }, 1) end
  surf.force_generate_chunk_requests()
end

local function scruter(st, sv, tick)
  local surf = game.surfaces[st.s]
  local k = tick - sv.tick
  for _, x in ipairs(surf.find_entities_filtered({ type = "explosion", position = { sv.x, sv.y }, radius = 4 })) do
    if not sv.vus[x.name] then
      sv.vus[x.name] = true
      sv.lignes[#sv.lignes + 1] = string.format("explosion %s vue a +%d, ecart (%.4f, %.4f)", x.name, k,
        x.position.x - sv.x, x.position.y - sv.y)
    end
  end
  if not sv.reste then
    for _, x in ipairs(surf.find_entities_filtered({ type = "corpse", position = { sv.x, sv.y }, radius = 2 })) do
      sv.reste = string.format("reste %s vu a +%d, ecart (%.4f, %.4f)", x.name, k, x.position.x - sv.x, x.position.y - sv.y)
      break
    end
  end
end

local function poser(surf, nom, x, y)
  local pos = surf.find_non_colliding_position(nom, { x, y }, 10, 1)
  return pos and surf.create_entity({ name = nom, position = pos, force = "player" })
end

S.tick = function(ctx, e)
  local st = ctx.state()
  if not st.debut or not st.px then return end
  local rel = e.tick - st.debut
  if rel == 10 and st.lot then ctx.remote("fo-explosions-mort", "releve") end
  local surf = game.surfaces[st.s]
  for _, et in ipairs(st.etapes) do
    if rel == et.t then
      local b = et.nom and poser(surf, et.nom, st.px + et.dx, st.py)
      ctx.check(b ~= nil, "batiment pose (" .. tostring(et.nom) .. ")")
      if b then
        local sv = { nom = et.nom, x = b.position.x, y = b.position.y, tick = e.tick, vus = {}, lignes = {} }
        ctx.log(string.format("%s : mort en (%.4f, %.4f) au tick %d", et.nom, sv.x, sv.y, e.tick))
        b.die()
        scruter(st, sv, e.tick)
        st.suivis[#st.suivis + 1] = sv
      end
    end
  end
  if st.lot then
    for _, r in ipairs(REGLE) do
      if rel == r.t then
        local b = poser(surf, "assembling-machine-1", st.px + r.dx, st.py + (r.dy or 0))
        if not b then
          ctx.check(false, "B3 " .. r.nom .. " : assembleur pose")
        else
          if r.temoin then ctx.remote("fo-explosions-mort", "actif", false) end
          local a = ctx.remote("fo-explosions-mort", "stats")
          local mx, my = b.position.x, b.position.y
          b.die()
          local z = ctx.remote("fo-explosions-mort", "stats")
          if r.temoin then ctx.remote("fo-explosions-mort", "actif", true) end
          local restes = #surf.find_entities_filtered({ type = "corpse", position = { mx, my }, radius = 2 })
          local dc, dl = z.crees - a.crees, z.loin - a.loin
          local dist = math.max(math.abs(mx - st.px), math.abs(my - st.py))
          ctx.log(string.format("B3 %s : mort a %.1f tuiles du joueur ; pendant die() : crees %+d, loin %+d, sans point %+d ; restes %d",
            r.nom, dist, dc, dl, z.sans_point - a.sans_point, restes))
          if r.attendu == "crees" then
            ctx.check(dc == 1 and dl == 0, "B3 " .. r.nom .. " : explosion recreee pendant die()", string.format("crees %+d loin %+d", dc, dl))
          else
            ctx.check(dc == 0 and dl == 1 and restes >= 1, "B3 " .. r.nom .. " : rien de cree, reste present",
              string.format("crees %+d loin %+d restes %d", dc, dl, restes))
          end
          st.regle[#st.regle + 1] = r.nom
        end
      end
    end
  end
  for i = #st.suivis, 1, -1 do
    local sv = st.suivis[i]
    if e.tick > sv.tick then scruter(st, sv, e.tick) end
    if e.tick - sv.tick >= SUIVI then
      for _, l in ipairs(sv.lignes) do ctx.log(string.format("%s : %s", sv.nom, l)) end
      ctx.log(string.format("%s : %s ; %d explosion(s) differente(s)", sv.nom, sv.reste or "aucun reste vu", #sv.lignes))
      st.fini[#st.fini + 1] = sv.nom
      table.remove(st.suivis, i)
    end
  end
end

S.finish = function(ctx)
  local st = ctx.state()
  ctx.check(st.fini and #st.fini == 8, "morts de batiments suivies (B4)", st.fini and #st.fini or 0)
  if st.lot then
    ctx.check(#st.regle == #REGLE, "B3 : morts de la regle jouees", #st.regle .. " / " .. #REGLE)
    local s = ctx.remote("fo-explosions-mort", "stats")
    ctx.log(string.format("fo-explosions-mort : crees %d, loin %d, sans point %d, ratees %d", s.crees, s.loin, s.sans_point, s.ratees))
  end
end

return S
