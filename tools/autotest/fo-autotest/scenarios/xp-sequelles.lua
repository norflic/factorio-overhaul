-- Lot EXPERIMENTAUX-PUISSANCE (7/11), 700 ticks, sans images : SÉQUELLES du QCM-7/11 (« durer 1 heure, se résorber ») en moteur réel, sur une
-- durée de trace RACCOURCIE à 300 ticks par le banc (remote fo-xp trace_ticks ; en jeu : Ech.TRACE_TICKS, 1 h).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui XP-PUISSANCE -- 700 xp-sequelles <source>
-- Au tick 60, un cratère de rayon 6 sur de l'herbe, avec dedans : un carré de béton (sol de joueur), une case d'eau, une tourelle. Au tick 200,
-- un second cratère chevauche le premier (échéance repoussée pour la partie commune). Contrôles :
--   tick 100 : sol de cratère posé sur l'herbe, béton et eau intacts, tourelle toujours là ;
--   tick 420 : la partie du premier cratère hors du second est rendue (herbe), la partie commune est encore cratère ;
--   tick 620 : tout est rendu à l'herbe d'origine ; béton et eau intacts ; registre vide.
-- Au BORD D'UN LAC (revue-0657, réserve sur set_tiles et la correction des tuiles) : au tick 60, un troisième cratère de rayon 6 à cheval sur
-- la rive d'un lac de 11 × 21 tuiles. Contrôles : aucune tuile d'eau perdue ni gagnée (posé, puis rendu), sol de cratère sur la rive,
-- herbe voisine hors du cratère intacte, tout rendu à la fin.
local X, Y = 16000, 6000
local LAC = { x0 = X + 40, x1 = X + 50, y0 = Y - 10, y1 = Y + 10 } -- tuiles d'eau, bornes comprises
local function eaux(s) return s.count_tiles_filtered({ area = { { LAC.x0 - 5, LAC.y0 - 5 }, { LAC.x1 + 6, LAC.y1 + 6 } }, name = "water" }) end
local CHECK = 620

local function tile(s, x, y) return s.get_tile(x, y).name end

return {
  description = "EXPERIMENTAUX-PUISSANCE : cratere pose puis resorbe (duree raccourcie), sols de joueur et eau respectes",
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    ctx.prepare_area(X - 20, Y - 20, X + 60, Y + 20, "grass-1")
    local lac = {}
    for x = LAC.x0, LAC.x1 do for y = LAC.y0, LAC.y1 do lac[#lac + 1] = { name = "water", position = { x, y } } end end
    s.set_tiles(lac, true) -- l'eau AVANT les entités (F135)
    st.eau0 = eaux(s)
    s.set_tiles({ { name = "concrete", position = { X + 2, Y + 2 } }, { name = "concrete", position = { X + 3, Y + 2 } } }, true)
    s.set_tiles({ { name = "water", position = { X - 3, Y - 3 } } }, true)
    st.tourelle = s.create_entity({ name = "gun-turret", position = { X - 1, Y + 3 }, force = "player" })
    remote.call("fo-xp", "trace_ticks", 300)
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    local t = e.tick
    if t == 60 then
      remote.call("fo-xp", "cratere", X + 0.5, Y + 0.5, 6)
      remote.call("fo-xp", "cratere", LAC.x0 - 1.5, Y + 0.5, 6) -- à cheval sur la rive ouest du lac
    end
    if t == 200 then remote.call("fo-xp", "cratere", X + 8.5, Y + 0.5, 6) end
    if t == 100 then
      st.c100 = { herbe = tile(s, X, Y), beton = tile(s, X + 2, Y + 2), eau = tile(s, X - 3, Y - 3), ouest = tile(s, X - 5, Y) }
      st.l100 = { eau = eaux(s), rive = tile(s, LAC.x0 - 2, Y), dans = tile(s, LAC.x0 + 1, Y), voisin = tile(s, LAC.x0 - 2, Y + 9) }
    end
    if t == 420 then
      st.c420 = { ouest = tile(s, X - 5, Y), commun = tile(s, X + 4, Y) }
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local c = st.c100 or {}
    ctx.check(c.herbe == "nuclear-ground" and c.ouest == "nuclear-ground", "tick 100 : sol de cratere pose", tostring(c.herbe) .. " / " .. tostring(c.ouest))
    ctx.check(c.beton == "concrete" and c.eau == "water", "tick 100 : beton du joueur et eau intacts", tostring(c.beton) .. " / " .. tostring(c.eau))
    ctx.check(st.tourelle and st.tourelle.valid, "la tourelle dans le cratere n'est pas retiree")
    local d = st.c420 or {}
    ctx.check(d.ouest == "grass-1" and d.commun == "nuclear-ground", "tick 420 : partie propre au 1er cratere rendue, partie commune encore cratere",
      tostring(d.ouest) .. " / " .. tostring(d.commun))
    local reste = s.count_tiles_filtered({ area = { { X - 10, Y - 10 }, { X + 20, Y + 10 } }, name = "nuclear-ground" })
    ctx.check(reste == 0 and tile(s, X + 4, Y) == "grass-1", "tick 620 : tout est rendu a l'herbe", reste .. " tuile(s) de cratere")
    ctx.check(tile(s, X + 2, Y + 2) == "concrete" and tile(s, X - 3, Y - 3) == "water", "tick 620 : beton et eau toujours intacts")
    local l = st.l100 or {}
    ctx.check(st.eau0 == 231 and l.eau == st.eau0 and l.rive == "nuclear-ground" and l.dans == "water" and l.voisin == "grass-1",
      "bord du lac, tick 100 : cratere sur la rive, aucune tuile d'eau perdue ni gagnee, herbe voisine hors du cratere intacte",
      string.format("eau %s -> %s, rive %s, dans le lac %s, voisin %s", tostring(st.eau0), tostring(l.eau), tostring(l.rive), tostring(l.dans), tostring(l.voisin)))
    local reste_lac = s.count_tiles_filtered({ area = { { LAC.x0 - 10, LAC.y0 - 5 }, { LAC.x1 + 6, LAC.y1 + 6 } }, name = "nuclear-ground" })
    ctx.check(eaux(s) == st.eau0 and reste_lac == 0 and tile(s, LAC.x0 - 2, Y) == "grass-1",
      "bord du lac, tick 620 : rive rendue a l'herbe, lac intact", string.format("eau %d, cratere %d, rive %s", eaux(s), reste_lac, tile(s, LAC.x0 - 2, Y)))
  end,
}
