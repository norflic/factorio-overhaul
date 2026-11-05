--[[
  Lot PERF3 (5/11, demande du DC : « vitesse fois dix », pas de gel ni de ralentissement en début de partie) : la partie
  du DC telle qu'ageblocage-dc la rejoue (graine 717152950 ; réglages de sa partie : 4 factions, 8 ouvriers, 30 soldats,
  Impitoyable ; coffre d'équipe garni comme verif-guide), SANS aucun relevé par minute du banc : la partie du DC n'a pas
  de mod de test qui lit l'état du jeu, et ces relevés (find_entities_filtered sur toute la force, interfaces de lecture)
  font des pics au tick % 3600 qui ne sont pas ceux du mod. Restent ceux de control.lua du mod de test : étalon
  [FO-CALIB] au tick % 600 (environ 2 ms, chronométré, soustrait par tools/autotest/perf3.py) et rapport du banc au
  tick % 3600.
  MODE :
    "off"    : profileur ÉTEINT (temps vu par le DC ; aucune ligne [FO-TRACE]) ;
    "prof"   : profileur ordinaire (portées des événements, des voies et des sous-systèmes ; totaux par minute) ;
    "detail" : profileur ordinaire + fin + DÉTAIL PAR TICK (une ligne [FO-PERF3-T] par tick : durée de chaque portée
               dans ce tick, avec sa portée mère) : attribution des pics. Plus lent (journal) : jamais pour une mesure de
               temps, seulement pour savoir QUI coûte à un tick donné (mêmes décisions : le profileur ne décide de rien).
  Lancement : py -3.9 -B tools/autotest/banc.py --seul --graine 717152950 --qui PERF3 --out <archive> -- 216000 perf3-dc <source>
  (perf3-dc-prof, perf3-dc-detail). Lecture : PYTHONUTF8=1 py -3.9 -B tools/autotest/perf3.py <archive> [--detail <archive detail>].
]]
return function(MODE)
  local base = require("scenarios/verif_guide_common")(8)
  local S = {
    description = "PERF3 : partie du DC (4 factions, 8 ouvriers, Impitoyable), sans releve, profileur " .. MODE,
    check_tick = 214000,
  }
  S.init = function(ctx)
    base.init(ctx) -- réglages du guide, profileur allumé, coffre d'équipe garni (comme ageblocage-dc)
    ctx.check(ctx.remote("factorio-overhaul", "war_setting", "fo-war-factions", 4) == 4, "4 factions (reglage du DC)")
    ctx.check(ctx.remote("fo-pvp", "set_difficulty", "merciless") == true, "difficulte Impitoyable (reglage du DC)")
    if MODE == "off" then
      ctx.call("profiler", false)
    elseif MODE == "detail" then
      ctx.call("profiler", true, "detail")
    end
  end
  S.tick = nil -- aucun relevé
  S.finish = function(ctx)
    local poi = ctx.call("points_of_interest")
    ctx.check(poi ~= nil and #poi.factions >= 1, "au moins une faction vivante a 59 min", poi and #poi.factions)
    ctx.check(ctx.call("team_status") ~= nil, "equipe du joueur active")
  end
  return S
end
