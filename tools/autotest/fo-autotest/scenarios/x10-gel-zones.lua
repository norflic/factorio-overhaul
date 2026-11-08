--[[
  Lot X10-GEL, MESURE (4) du lead (8/11) avant de choisir pour les garnisons : LuaSurface.find_enemy_units contre la recherche
  actuelle du guet (count_entities_filtered{type = Ga.MOBILE, force = ennemis, limit = 1}), dans les MÊMES zones (remote « fo-gel »,
  zones : QG, amas de tourelles, postes hors du cercle du QG), chronométrées, avec le nombre d'entités vues par chacune.
    py -3.9 -B tools/autotest/banc.py --seul --qui X10-GEL --sauvegarde "<racine>\fo-logs\2026-11-05_PARTIE-DC-ESSAI\autosave1-2121.zip"
       --out <archive> -- 600 x10-gel-zones <source>
  Profileur du mod ÉTEINT (seules les recherches du scénario sont chronométrées, par LuaProfiler, une par appel, cumulées par sorte de
  zone). Tous les 20 ticks de t0 + 100 à t0 + 560 (24 relevés), pour chaque faction vivante, chaque zone : les deux recherches, dans un
  ordre qui alterne d'un relevé à l'autre. Une zone « amas » est une boîte : find_enemy_units y prend le cercle CIRCONSCRIT (centre de la
  boîte, demi-diagonale), plus grand. Comptes (hors chrono) : toutes les entités mobiles ennemies de la zone (sans limit), les unités
  seules (type « unit »), et ce que rend find_enemy_units.
  Seuil du lead : find_enemy_units à moins de 10 µs en moyenne -> voie 4 ; sinon voie 2 (tour de rôle des amas).
]]

local KINDS = { "qg", "amas", "poste" }

local S = {
  description = "X10-GEL : find_enemy_units contre la recherche du guet des garnisons, memes zones, chronometrees",
  check_tick = -1,
}

local function acc(st, kind)
  local a = st.acc[kind]
  if not a then
    a = { n = 0, cnt = game.create_profiler(true), find = game.create_profiler(true), all = 0, units = 0, found = 0, miss = 0, extra = 0,
      nonunit = 0 }
    st.acc[kind] = a
  end
  return a
end

S.init = function(ctx)
  local t = game.tick
  S.check_tick = t + 590
  local st = ctx.state()
  st.t0, st.acc, st.round = t, {}, 0
  ctx.call("profiler", false, false)
  log(string.format("[FO-PERF4] debut tick %d (%.1f min de jeu) ; mode off ; X10-GEL zones", t, t / 3600))
  ctx.check(t > 0, "partie chargee depuis une sauvegarde (tick de depart > 0)", t)
end

S.tick = function(ctx, e)
  local st = ctx.state()
  if not st.t0 then return end
  local dt = e.tick - st.t0
  if dt < 100 or dt > 560 or dt % 20 ~= 0 then return end
  st.round = st.round + 1
  for fid = 1, 9 do
    local z = ctx.remote("fo-gel", "zones", fid)
    if z then
      local surface = game.surfaces[z.surface]
      for _, zone in ipairs(z.zones) do
        local a = acc(st, zone.kind)
        local q = { type = z.mobile, force = z.enemies, limit = 1 }
        local center, radius
        if zone.area then
          q.area = zone.area
          local x0, y0, x1, y1 = zone.area[1][1], zone.area[1][2], zone.area[2][1], zone.area[2][2]
          center = { x = (x0 + x1) / 2, y = (y0 + y1) / 2 }
          radius = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2) / 2
        else
          q.position, q.radius = zone.position, zone.radius
          center, radius = zone.position, zone.radius
        end
        local list
        local function timed_count()
          local m = game.create_profiler()
          surface.count_entities_filtered(q)
          m.stop()
          a.cnt.add(m)
        end
        local function timed_find()
          local m = game.create_profiler()
          list = surface.find_enemy_units(center, radius, z.force)
          m.stop()
          a.find.add(m)
        end
        if st.round % 2 == 0 then timed_count(); timed_find() else timed_find(); timed_count() end
        a.n = a.n + 1
        -- comptes, hors chrono
        local qa = { type = z.mobile, force = z.enemies, area = q.area, position = q.position, radius = q.radius }
        local all = surface.count_entities_filtered(qa)
        qa.type = "unit"
        local units = surface.count_entities_filtered(qa)
        a.all, a.units, a.found = a.all + all, a.units + units, a.found + #list
        a.nonunit = a.nonunit + (all - units)
        if zone.area then
          if #list < units then a.miss = a.miss + 1 end -- le cercle circonscrit contient la boîte : jamais moins d'unités
          if #list > units then a.extra = a.extra + 1 end
        elseif #list ~= units then
          if #list < units then a.miss = a.miss + 1 else a.extra = a.extra + 1 end
        end
      end
    end
  end
end

S.finish = function(ctx)
  local st = ctx.state()
  local total_n = 0
  for _, kind in ipairs(KINDS) do
    local a = st.acc[kind]
    if a and a.n > 0 then
      total_n = total_n + a.n
      local ac, af = game.create_profiler(true), game.create_profiler(true)
      ac.add(a.cnt); ac.divide(a.n)
      af.add(a.find); af.divide(a.n)
      log({ "", "[FO-X10-ZONES] ", kind, " : ", tostring(a.n), " zone(s) lue(s) ; recherche actuelle (moyenne) ", ac, " ; find_enemy_units (moyenne) ", af,
        " ; cumuls ", a.cnt, " et ", a.find })
      log(string.format("[FO-X10-ZONES] %s : entites mobiles ennemies vues %d (dont %d non-unites : personnages, vehicules), unites %d, rendues par find_enemy_units %d ; zones ou find voit MOINS d'unites : %d, plus : %d",
        kind, a.all, a.nonunit, a.units, a.found, a.miss, a.extra))
    end
  end
  ctx.check(total_n > 0, "zones lues (" .. total_n .. ")", total_n)
  local cm = 0
  for _, kind in ipairs(KINDS) do local a = st.acc[kind]; if a and kind ~= "amas" then cm = cm + a.miss end end
  ctx.check(cm == 0, "cercles (QG, postes) : find_enemy_units ne voit jamais moins d'unites que la recherche actuelle", cm)
end

return S
