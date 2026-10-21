--[[
  Lot IA0, critère C4-4 (cas négatif) : en « Paisible », la base témoin n'est jamais attaquée.
  Lancement : « 216000 ia0-paisible » (60 min). Journal : [FO-IA0-PAISIBLE].
]]
local C = require("scenarios/ia0_common")

return {
  description = "IA0 : PvP en Paisible, base temoin jamais attaquee (60 min)",
  base = nil,
  check_tick = 215000,

  init = function(ctx)
    C.build_base(ctx)
    C.start_war(ctx, "peaceful")
  end,

  tick = function(ctx, e) C.poll(ctx, e, 60) end,

  finish = function(ctx)
    local st = ctx.state()
    C.check_level(ctx, "peaceful")
    ctx.check(st.attacks_total == 0 and st.first_attack == nil, "aucune attaque contre le joueur", st.attacks_total)
    ctx.check(st.declared_total == 0, "aucune declaration de guerre", st.declared_total)
    ctx.check((st.losses or 0) == 0, "aucune perte du joueur causee par une faction", st.losses)
    local alive, touched, total = C.base_state(ctx)
    ctx.check(alive == total and touched == 0, "base temoin intacte", string.format("%d/%d, touches %d", alive, total, touched))
    local all = true
    for name, force in pairs(game.forces) do
      if name:find("^fo%-") and name ~= "fo-horde" then
        if not (force.get_cease_fire(game.forces.player) and game.forces.player.get_cease_fire(force)) then all = false end
      end
    end
    ctx.check(all, "cessez-le-feu intact avec toutes les factions")
    local sent = 0
    for _, r in pairs(st.factions or {}) do sent = sent + (r.sent_total or 0) end
    ctx.check(sent > 0, "les factions se battent entre elles (soldats envoyes)", sent)
  end,
}
