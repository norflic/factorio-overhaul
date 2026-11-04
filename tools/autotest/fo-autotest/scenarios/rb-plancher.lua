-- Lot ROBOTS-JEU (3/11) : MISE AU NET des 12 robots au PLANCHER (F205 : une image paraît d'abord floue puis nette, par pas de 130 ticks).
-- Images seulement, réglages du plancher :
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--quality normal --video-memory low --texture-compression low-quality"
--      --qui ROBOTS-JEU -- 200 rb-plancher <source>
--   py -3.9 -B tools/autotest/robots/rb_plancher_images.py <archive>/fo-shots
-- Les 12 robots du joueur, FIGÉS (active = false : la même image d'une prise à l'autre, seule la mise au net change) : 9 terrestres en
-- haut, 3 géants en bas ; une vue au zoom 1 et une au zoom 2 (terrestres), prises PRISES fois à 130 ticks d'écart (cadence de shots.lua :
-- une capture toutes les 10 ticks ; 12 captures « pas » de 32 × 32 px entre deux instants, comme a4-socle).
local X0, Y0 = 4200, 3000
local TERRESTRES = { "steam-trotter", "scalehide", "coiler", "needle", "bellwether", "chamfer", "trowel", "finback", "levite" }
local GEANTS = { "toroid", "heliast", "crowned" }
local PRISES, PAS = 6, 12

return {
  description = "ROBOTS-JEU : mise au net des 12 robots au plancher (images)",
  check_tick = 60,
  shots_delay = 60,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(X0 - 40, Y0 - 25, X0 + 40, Y0 + 30, "concrete")
    game.map_settings.enemy_expansion.enabled = false
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 150, Y0 - 150 }, { X0 + 150, Y0 + 150 } } })) do en.destroy() end
    st.n = 0
    for i, id in ipairs(TERRESTRES) do
      local u = s.create_entity({ name = "fo-robot-player-" .. id, position = { X0 - 20 + 5 * (i - 1), Y0 - 8 }, force = "player" })
      if u then u.active = false; st.n = st.n + 1 end
    end
    for i, id in ipairs(GEANTS) do
      local g = s.create_entity({ name = "fo-robot-player-" .. id, position = { X0 - 16 + 16 * (i - 1), Y0 + 10 }, force = "player" })
      if g then g.active = false; st.n = st.n + 1 end
    end
  end,

  finish = function(ctx)
    ctx.check(ctx.state().n == 12, "12 robots poses", tostring(ctx.state().n) .. " / 12")
  end,

  shots = function(ctx, add)
    for t = 0, PRISES - 1 do
      add(string.format("tous-z1-t%d", t), X0, Y0 + 1, 1, 0, { res = { 1600, 1280 }, info = false, aa = false })
      add(string.format("terrestres-z2-t%d", t), X0, Y0 - 9, 2, 0, { res = { 1600, 512 }, info = false, aa = false })
      if t < PRISES - 1 then
        for k = 1, PAS do add(string.format("pas-t%d-%02d", t, k), X0 - 38, Y0 + 28, 1, 0, { res = { 32, 32 }, info = false, aa = false }) end
      end
    end
  end,
}
