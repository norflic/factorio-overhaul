--[[
  Lot IA0b (OBJECTIFS.md C4) : en « Impitoyable », une base témoin DÉFENDUE par 6 tourelles approvisionnées
  (défense estimée 48) est attaquée ET touchée, plus tôt qu'en Normal (grâce d'Écarlate : 6,7 min). Avant
  IA0b, la campagne pure montrait qu'un conquérant n'attaquait jamais 3 tourelles en tech 0, à aucun niveau.
  Lancement : « 144000 ia0-defendue-impitoyable » (40 min). Journal : [FO-IA0-DEFENDUE-IMPITOYABLE] et
  [FO-PVP] (siege, assaut coordonne ouvert, attaque ... (assaut coordonne)).
  Réussite : BILAN sans ECHEC. L'assaut coordonné (attaques jointes) est journalisé, sans être exigé : il
  dépend du calendrier des 4 factions en moteur réel (voir la ligne « total : ... jointes »).
]]
local C = require("scenarios/ia0_common")

local TURRETS = 6

return {
  description = "IA0b : PvP en Impitoyable, base temoin defendue par 6 tourelles attaquee et touchee (40 min)",
  base = nil,
  check_tick = 143000,

  init = function(ctx)
    C.build_base(ctx, TURRETS)
    C.start_war(ctx, "merciless")
  end,

  tick = function(ctx, e) C.poll(ctx, e, 60) end,

  finish = function(ctx)
    local st = ctx.state()
    C.check_defended(ctx, "merciless", TURRETS)
    -- Plus tôt qu'en Normal : la 1re attaque part avant la fin de la grâce Normal du conquérant (20 min).
    ctx.check(st.first_attack ~= nil and st.first_attack < 72000, "1re attaque avant 20 min (grace Normal du conquerant)",
      tostring(st.first_attack))
  end,
}
