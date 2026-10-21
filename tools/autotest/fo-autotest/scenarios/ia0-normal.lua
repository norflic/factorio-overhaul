--[[
  Lot IA0, critère C4-4 (cas positif) : une base témoin du joueur est attaquée en « Normal » APRÈS le délai
  de grâce. Lancement : « 216000 ia0-normal » dans <racine>\fo-autotest-params.txt (60 min, comme E21 :
  en E21 la 1re attaque entre factions arrive à 15,8 min ; Écarlate peut avoir vidé sa garnison sur une
  rivale juste avant sa grâce de 20 min, puis devoir reconstituer 13 soldats et marcher ~500 tuiles).
  Journal : [FO-IA0-NORMAL] (contrôles, BILAN) et [FO-PVP] (lignes du mod : préavis, déclaration, attaque).
  Réussite : BILAN sans ECHEC, ET une ligne « [FO-PVP] attaque tick T <faction> -> joueur » avec T ≥ fin de
  grâce de cette faction (Écarlate : 72000), la base témoin touchée APRÈS T (le drapeau « pertes > 0 » seul
  ne suffit pas : un groupe en route vers une rivale peut croiser la tourelle).
]]
local C = require("scenarios/ia0_common")

return {
  description = "IA0 : PvP en Normal, base temoin attaquee apres la grace (60 min)",
  base = nil,
  check_tick = 215000,

  init = function(ctx)
    C.build_base(ctx)
    C.start_war(ctx, "normal")
  end,

  tick = function(ctx, e) C.poll(ctx, e, 60) end,

  finish = function(ctx)
    local st = ctx.state()
    C.check_level(ctx, "normal")
    -- Aucune attaque contre le joueur avant la fin de la grâce de la faction qui attaque.
    local early, keys = {}, {}
    for k in pairs(st.factions or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local r = st.factions[k]
      if r.first_attack and r.grace_end and r.first_attack < r.grace_end then early[#early + 1] = k .. "@" .. r.first_attack end
      if r.declared_at and r.grace_end then
        ctx.check(r.declared_at >= r.grace_end, k .. " : declaration apres sa grace", r.declared_at .. " >= " .. r.grace_end)
      end
    end
    ctx.check(#early == 0, "aucune attaque contre le joueur avant la fin de la grace", table.concat(early, ", "))
    ctx.check(st.first_attack ~= nil, "au moins une attaque contre le joueur", st.first_key and (st.first_key .. " au tick " .. st.first_attack) or "aucune")
    local r = st.first_key and st.factions[st.first_key]
    local t = r and r.first_target
    local near = false
    if t and st.center then
      local dx, dy = t.x - st.center.x, t.y - st.center.y
      near = dx * dx + dy * dy <= 48 * 48
    end
    ctx.check(near, "la 1re attaque vise la base temoin (cible a moins de 48 tuiles)", t and string.format("(%d, %d)", t.x, t.y) or "cible inconnue")
    ctx.check(st.base_hit ~= nil and st.first_attack ~= nil and st.base_hit > st.first_attack,
      "base temoin touchee apres la 1re attaque (batiment detruit ou endommage)", tostring(st.base_hit))
    ctx.check((st.losses or 0) >= 1, "pertes du joueur causees par une faction", st.losses)
  end,
}
