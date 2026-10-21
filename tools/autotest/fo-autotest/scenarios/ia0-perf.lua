--[[
  Lot IA0, critère C4-5 (budget A1) dans les conditions d'E21 : base « default » (4 factions, 50 compagnons),
  mais en « Normal » (les factions deviennent hostiles aux compagnons du joueur après leur grâce : combats
  fortuits compris). Lancement ÉPINGLÉ (F30) : « 216000 ia0-perf » (60 min, comme E21).
  Lecture : analyze.py --spikes (moyenne, p99 ; comparer à E21), portées « pvp:scan » et « faction:attack »
  du profileur. Ce scénario suppose que le scénario intégré « default » reste comparable à E21, donc en
  « Paisible » (diff proposé pour control.lua : pvp = "peaceful" dans default, stress, noexp, peace, parked,
  waves, pteam) ; il impose ici « Normal » après la préparation (la grâce part alors de ce changement).
  Journal : [FO-IA0-PERF].
]]
local C = require("scenarios/ia0_common")

return {
  description = "IA0 : budget A1 avec PvP en Normal, 4 factions + 50 compagnons (60 min, comparable a E21)",
  base = "default",
  check_tick = 215000,

  init = function(ctx)
    local ok = ctx.remote("fo-pvp", "set_difficulty", "normal")
    ctx.check(ok == true, "difficulte Normal imposee apres la preparation de default")
  end,

  tick = function(ctx, e) C.poll(ctx, e, 3600) end,

  finish = function(ctx)
    local st = ctx.state()
    C.check_level(ctx, "normal")
    ctx.log(string.format("declarations %d, attaques contre le joueur %d, pertes du joueur %d",
      st.declared_total or 0, st.attacks_total or 0, st.losses or 0))
  end,
}
