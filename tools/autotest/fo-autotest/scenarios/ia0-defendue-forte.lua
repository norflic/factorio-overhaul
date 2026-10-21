--[[
  Lot IA0b (OBJECTIFS.md C4), preuve DISCRIMINANTE (facultative) : en « Normal », une base témoin défendue par
  12 tourelles approvisionnées (défense estimée 96) est attaquée par le conquérant et par au moins 2 factions.
  Pourquoi 12 : en moteur réel, Écarlate atteint la tech 2 vers 20 min (E21) ; ses soldats valent alors 4,5
  fusiliers et 3 tourelles ne lient plus la règle de force, même avec l'ancien code (ia0-defendue n'est donc
  pas discriminant). Avec 12 tourelles, l'ANCIEN code exigeait 28 soldats envoyés (1,3 × 96 / 4,54) et se
  repliait sur la rivale après 3 min : moteur simulé, 60 min, 4 factions : 2 attaques (Azur seulement),
  Écarlate déclarée à 20 min et 0 attaque. Nouveau code : 15 (0,9 × 0,75 × 96 / 4,54), siège de 20 min au plus.
  Lancement : « 216000 ia0-defendue-forte » (60 min). Journal : [FO-IA0-DEFENDUE-FORTE] et [FO-PVP].
  Réussite : BILAN sans ECHEC.
  Seul contrôle discriminant (vérificateur IA0b) : « le conquerant (Ecarlate) attaque la base defendue » (code
  IA0 en moteur simulé : Écarlate 0 attaque ; « au moins 2 factions » passe aussi avec l'ancien code). À
  lancer AUSSI sur main (code IA0) comme TÉMOIN NÉGATIF en moteur réel : l'échec attendu de ce contrôle sur
  main prouve que le scénario discrimine.
]]
local C = require("scenarios/ia0_common")

local TURRETS = 12

return {
  description = "IA0b : PvP en Normal, base temoin defendue par 12 tourelles attaquee par le conquerant (60 min)",
  base = nil,
  check_tick = 215000,

  init = function(ctx)
    C.build_base(ctx, TURRETS)
    C.start_war(ctx, "normal")
  end,

  tick = function(ctx, e) C.poll(ctx, e, 60) end,

  finish = function(ctx)
    local st = ctx.state()
    C.check_defended(ctx, "normal", TURRETS)
    local scarlet = st.factions and st.factions.scarlet
    ctx.check(scarlet ~= nil and (scarlet.attacks or 0) >= 1, "le conquerant (Ecarlate) attaque la base defendue",
      scarlet and scarlet.attacks or "aucun releve")
    local n, keys = 0, {}
    for k in pairs(st.factions or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do if (st.factions[k].attacks or 0) > 0 then n = n + 1 end end
    ctx.check(n >= 2, "au moins 2 factions attaquent la base defendue", n .. " sur " .. #keys)
  end,
}
