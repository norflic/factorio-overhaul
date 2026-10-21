--[[
  Lot IA0b (OBJECTIFS.md C4) : en « Impitoyable », une base témoin DÉFENDUE par 6 tourelles approvisionnées
  (défense estimée 48) est attaquée ET touchée, plus tôt qu'en Normal (grâce d'Écarlate : 6,7 min). Avant
  IA0b, la campagne pure montrait qu'un conquérant n'attaquait jamais 3 tourelles en tech 0, à aucun niveau.
  Lancement : « 144000 ia0-defendue-impitoyable » (40 min). Journal : [FO-IA0-DEFENDUE-IMPITOYABLE] et
  [FO-PVP] (siege, assaut coordonne ouvert, attaque ... (assaut coordonne)).
  Réussite : BILAN sans ECHEC. Correction IA0b (vérificateur) : l'assaut coordonné est EXIGÉ (au moins une
  fenêtre ouverte et au moins une attaque jointe, contre la cible de la fenêtre) ; c'est le seul contrôle
  discriminant de ce scénario (le code du lot IA0 n'a ni fenêtre ni jointe ; ses autres contrôles passent
  aussi avec l'ancien code en moteur simulé). En moteur réel, il dépend du calendrier des 4 factions : un
  échec de ce seul contrôle se lit « assaut coordonné non prouvé en moteur réel », pas « base non attaquée ».
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
    -- Assaut coordonné (lot IA0b) : une fenêtre ouverte par une attaque prête, et au moins une attaque jointe.
    ctx.check((st.rallies or 0) >= 1, "assaut coordonne : au moins une fenetre ouverte", tostring(st.rallies or 0))
    local joins = 0
    for _, k in ipairs({ "amber", "azure", "emerald", "scarlet" }) do
      local r = st.factions and st.factions[k]
      joins = joins + (r and r.joins or 0)
    end
    ctx.check(joins >= 1, "assaut coordonne : au moins une attaque jointe", tostring(joins))
  end,
}
