--[[
  Lot IA0, critère C4-3 en moteur réel (complément) : en « Difficile », la 1re attaque contre la base témoin
  part après la grâce de Difficile (Écarlate : 12 min = 43200 ticks), donc plus tôt qu'en Normal.
  Lancement : « 144000 ia0-difficile » (40 min). Journal : [FO-IA0-DIFFICILE]. Comparer le tick de la
  1re attaque à celui de ia0-normal (même carte, même graine).
]]
local C = require("scenarios/ia0_common")

return {
  description = "IA0 : PvP en Difficile, 1re attaque plus tot qu'en Normal (40 min)",
  base = nil,
  check_tick = 143000,

  init = function(ctx)
    C.build_base(ctx)
    C.start_war(ctx, "hard")
  end,

  tick = function(ctx, e) C.poll(ctx, e, 60) end,

  finish = function(ctx)
    local st = ctx.state()
    C.check_level(ctx, "hard")
    local early, keys = {}, {}
    for k in pairs(st.factions or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local r = st.factions[k]
      if r.first_attack and r.grace_end and r.first_attack < r.grace_end then early[#early + 1] = k .. "@" .. r.first_attack end
    end
    ctx.check(#early == 0, "aucune attaque contre le joueur avant la fin de la grace", table.concat(early, ", "))
    ctx.check(st.first_attack ~= nil, "au moins une attaque contre le joueur", st.first_key and (st.first_key .. " au tick " .. st.first_attack) or "aucune")
    ctx.log("1re attaque (a comparer a ia0-normal) : " .. tostring(st.first_attack) .. " " .. tostring(st.first_key))
  end,
}
