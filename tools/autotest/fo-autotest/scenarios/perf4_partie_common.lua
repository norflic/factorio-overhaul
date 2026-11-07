--[[
  Lot PERF4 (5/11, le DC : « des freezes ou des ralentissements [...] une demi-seconde [...] très périodique [...] c'est vraiment
  le mod ») : la SAUVEGARDE du DC rejouée telle quelle (banc.py --sauvegarde, variable FO_SAVE de fo-autotest.bat : aucune
  création de carte). Le scénario ne change RIEN à la partie : ni réglage, ni coffre, ni guerre ; il règle seulement le
  profileur du mod et écrit le tick de départ (« [FO-PERF4] debut tick D », lu par tools/autotest/perf3.py pour ramener les
  lignes du benchmark aux ticks du jeu). Le mod de test est AJOUTÉ à la partie : son on_init tourne au chargement (étalon
  [FO-CALIB] au tick % 600, rapport du banc au tick % 3600, comme pour toute carte de banc). Nom de scénario dans KIT_EGAL du
  mod de test : pas de réglage « kit généreux » posé sur la partie du DC.
  MODE :
    "off"    : profileur ÉTEINT (le temps que voit le DC) ;
    "prof"   : profileur ordinaire et fin (totaux par minute dans le rapport du banc) ;
    "detail" : profileur ordinaire + fin + DÉTAIL PAR TICK ([FO-PERF3-T] : durée de chaque portée, avec sa mère) : QUI coûte à
               chaque pic. Plus lent : jamais pour une mesure de temps.
  Lancement (PC sans jeu du DC, sans Blender) :
    py -3.9 -B tools/autotest/banc.py --seul --qui PERF4 --sauvegarde "<racine>\fo-logs\2026-11-05_PARTIE-DC-ESSAI\autosave1-2121.zip"
       --out <archive> -- 36000 perf4-partie <source>          (puis perf4-partie-detail)
  Lecture : PYTHONUTF8=1 py -3.9 -B tools/autotest/perf3.py <archive off> --detail <archive detail> --seuil 16
]]
return function(MODE)
  local S = {
    description = "PERF4 : sauvegarde du DC rejouee telle quelle, profileur " .. MODE,
    check_tick = -1, -- fixé à l'init (tick de la sauvegarde + 600) : la partie ne commence pas au tick 0
  }
  S.init = function(ctx)
    local t = game.tick
    S.check_tick = t + 600
    local st = ctx.state()
    st.debut = t
    local mods = {}
    for name, v in pairs(script.active_mods) do mods[#mods + 1] = name .. " " .. v end
    table.sort(mods)
    log(string.format("[FO-PERF4] debut tick %d (%.1f min de jeu) ; mode %s ; mods : %s", t, t / 3600, MODE, table.concat(mods, ", ")))
    if MODE == "off" then
      ctx.call("profiler", false, false)
    elseif MODE == "prof" then
      ctx.call("profiler", true, true)
    elseif MODE == "detail" then
      ctx.call("profiler", true, "detail")
    end
    ctx.check(t > 0, "partie chargee depuis une sauvegarde (tick de depart > 0)", t)
  end
  S.tick = nil -- aucun relevé : la partie du DC n'a pas de mod de test qui lit l'état du jeu
  S.finish = function(ctx)
    local poi = ctx.call("points_of_interest")
    ctx.check(poi ~= nil, "interface du mod lisible apres 600 ticks", poi and #poi.factions)
    if poi then ctx.log(string.format("factions vivantes : %d", #poi.factions)) end
  end
  return S
end
