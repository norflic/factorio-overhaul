-- Lot EXPERIMENTAUX-PUISSANCE (7/11), 700 ticks, sans images : SÉQUELLES du QCM-7/11 (« durer 1 heure, se résorber ») en moteur réel, sur une
-- durée de trace RACCOURCIE à 300 ticks par le banc (remote fo-xp trace_ticks ; en jeu : Ech.TRACE_TICKS, 1 h).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui XP-PUISSANCE -- 700 xp-sequelles <source>
-- Au tick 60, un cratère de rayon 6 sur de l'herbe, avec dedans : un carré de béton (sol de joueur), une case d'eau, une tourelle. Au tick 200,
-- un second cratère chevauche le premier (échéance repoussée pour la partie commune). Contrôles :
--   tick 100 : sol de cratère posé sur l'herbe, béton et eau intacts, tourelle toujours là ;
--   tick 420 : la partie du premier cratère hors du second est rendue (herbe), la partie commune est encore cratère ;
--   tick 620 : tout est rendu à l'herbe d'origine ; béton et eau intacts ; registre vide.
local X, Y = 16000, 6000
local CHECK = 620

local function tile(s, x, y) return s.get_tile(x, y).name end

return {
  description = "EXPERIMENTAUX-PUISSANCE : cratere pose puis resorbe (duree raccourcie), sols de joueur et eau respectes",
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    ctx.prepare_area(X - 20, Y - 20, X + 30, Y + 20, "grass-1")
    s.set_tiles({ { name = "concrete", position = { X + 2, Y + 2 } }, { name = "concrete", position = { X + 3, Y + 2 } } }, true)
    s.set_tiles({ { name = "water", position = { X - 3, Y - 3 } } }, true)
    st.tourelle = s.create_entity({ name = "gun-turret", position = { X - 1, Y + 3 }, force = "player" })
    remote.call("fo-xp", "trace_ticks", 300)
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    local t = e.tick
    if t == 60 then remote.call("fo-xp", "cratere", X + 0.5, Y + 0.5, 6) end
    if t == 200 then remote.call("fo-xp", "cratere", X + 8.5, Y + 0.5, 6) end
    if t == 100 then
      st.c100 = { herbe = tile(s, X, Y), beton = tile(s, X + 2, Y + 2), eau = tile(s, X - 3, Y - 3), ouest = tile(s, X - 5, Y) }
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
  end,
}
