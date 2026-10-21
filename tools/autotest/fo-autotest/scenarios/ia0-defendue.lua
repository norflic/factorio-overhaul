--[[
  Lot IA0b (OBJECTIFS.md C4) : une base témoin DÉFENDUE par 3 tourelles approvisionnées (défense estimée 24)
  est attaquée ET touchée en « Normal ». Avant IA0b, la campagne pure montrait qu'une telle base n'était
  jamais attaquée en tech 0 (BALANCE_SHEET §10 bis) ; le moteur simulé (ancien code, 2 factions) ne
  l'attaquait qu'à 43,7 min.
  Lancement : « 216000 ia0-defendue » dans <racine>\fo-autotest-params.txt (60 min).
  Journal : [FO-IA0-DEFENDUE] (contrôles, BILAN) et [FO-PVP] (lignes du mod : siege, dissuasion, attaque avec
  besoin et tech, declaration).
  Réussite : BILAN sans ECHEC, ET une ligne « [FO-PVP] attaque tick T <faction> -> joueur : ... defense
  estimee 24 » (ou plus) avec T ≥ fin de grâce de cette faction (Écarlate : 72000), la base témoin touchée
  APRÈS T.
  NON DISCRIMINANT (vérificateur IA0b, moteur simulé) : le code du lot IA0 passe aussi ce scénario (mêmes
  contrôles, 9 attaques). Les factions atteignent la tech 2 vers 20 min (E21) et 3 tourelles ne lient plus la
  règle de force. Il prouve qu'une base défendue est attaquée et touchée en moteur réel, pas l'effet du lot :
  la preuve discriminante est ia0-defendue-forte (à lancer aussi sur main, témoin négatif).
]]
local C = require("scenarios/ia0_common")

local TURRETS = 3

return {
  description = "IA0b : PvP en Normal, base temoin defendue par 3 tourelles attaquee et touchee (60 min)",
  base = nil,
  check_tick = 215000,

  init = function(ctx)
    C.build_base(ctx, TURRETS)
    C.start_war(ctx, "normal")
  end,

  tick = function(ctx, e) C.poll(ctx, e, 60) end,

  finish = function(ctx)
    C.check_defended(ctx, "normal", TURRETS)
  end,
}
