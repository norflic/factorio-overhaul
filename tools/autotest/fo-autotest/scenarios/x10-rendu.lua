--[[
  Lot X10, M2 (7/11) : RENDU de la partie du DC. Ce que coûte l'IMAGE, que --benchmark ne compte pas. Session AVEC images
  sur la SAUVEGARDE du DC (banc.py --sauvegarde ... --captures --visuel="--window hd --measure --pcores --ticks 8700"),
  permise par le DC le 7/11 à 17 h 55 (« Oui, captures permises »).
  La sauvegarde est rejouée telle quelle (nom dans KIT_EGAL de control.lua : aucun réglage du mod posé), vitesse du jeu
  remise à 10 (celle de la sauvegarde du DC), profileur du mod éteint, ligne « [FO-PERF4] debut tick D » (perf3.py).
  Trois PHASES devant la vue du joueur (le personnage du DC, dans sa base), chacune chronométrée par un LuaProfiler
  (temps RÉEL, pour la mesure seulement, jamais pour une décision) au même format que d4-geant, lu par vram.py :
      [FO-X10-RENDU] PHASE debut <vue> tick <t> zoom <z> daytime <d>
      [FO-X10-RENDU] PHASE fin <vue> tick <t> ticks <n> Duration: <ms>ms
  UPS réel de la phase = n ÷ (ms ÷ 1000) ; ×N atteint = UPS ÷ 60. Images : perf-stats.csv du jeu (visual_session.py
  --measure, F206). Puis UNE capture à la position du joueur (le pilote exige un marqueur et une image lisible).
]]

local PHASES = {
  { name = "vue-dc-z1", from = 300, to = 2700, zoom = 1.0 },
  { name = "vue-dc-z05", from = 3000, to = 5400, zoom = 0.5 },
  { name = "vue-dc-z03", from = 5700, to = 8100, zoom = 0.3 },
}
local VITESSE = 10
local FIN = 8200 -- BILAN (après la dernière phase, avant les captures)
local PROF -- chronomètre de la phase en cours : local au chargement, jamais dans global (aucune sauvegarde pendant le banc)

local S = {
  description = "X10 M2 : rendu de la partie du DC, 3 vues chronometrees a vitesse 10",
  check_tick = -1, -- fixé à l'init : tick de la sauvegarde + FIN
  shots_delay = 8400,
}

S.init = function(ctx)
  local t = game.tick
  S.check_tick = t + FIN
  local st = ctx.state()
  st.debut, st.mesurees = t, 0
  local mods = {}
  for name, v in pairs(script.active_mods) do mods[#mods + 1] = name .. " " .. v end
  table.sort(mods)
  log(string.format("[FO-PERF4] debut tick %d (%.1f min de jeu) ; mode x10-rendu ; mods : %s", t, t / 3600, table.concat(mods, ", ")))
  ctx.call("profiler", false, false)
  ctx.log(string.format("vitesse de la sauvegarde %.2f, remise a %d", game.speed, VITESSE))
  game.speed = VITESSE
  ctx.check(t > 0, "partie chargee depuis une sauvegarde (tick de depart > 0)", t)
end

S.tick = function(ctx, e)
  local st = ctx.state()
  if not st.debut then return end
  local rel = e.tick - st.debut
  for i = 1, #PHASES do
    local ph = PHASES[i]
    if rel == ph.from then
      local player = game.connected_players[1]
      if not player then
        ctx.log("PHASE " .. ph.name .. " : aucun joueur connecte, phase sautee")
        return
      end
      player.zoom = ph.zoom
      local res = player.display_resolution
      ctx.log(string.format("VUE %s : joueur %s en (%.1f, %.1f), fenetre %dx%d, vitesse %.2f", ph.name, player.name,
        player.position.x, player.position.y, res.width, res.height, game.speed))
      ctx.log(string.format("PHASE debut %s tick %d zoom %.2f daytime %.2f", ph.name, e.tick, ph.zoom, player.surface.daytime))
      st.phase, st.phase_tick = i, e.tick
      PROF = game.create_profiler()
    elseif rel == ph.to and st.phase == i and PROF then
      PROF.stop()
      log({ "", ctx.tag, " PHASE fin ", ph.name, " tick ", tostring(e.tick), " ticks ", tostring(e.tick - st.phase_tick), " ", PROF })
      PROF, st.phase = nil, nil
      st.mesurees = st.mesurees + 1
    end
  end
end

S.finish = function(ctx)
  local st = ctx.state()
  ctx.check(st.mesurees == #PHASES, "phases chronometrees", st.mesurees .. " / " .. #PHASES)
  ctx.check(#game.connected_players == 1, "un joueur connecte (la vue du DC)", #game.connected_players)
end

S.shots = function(ctx, add)
  local p = game.connected_players[1]
  local pos = p and p.position or { x = 0, y = 0 }
  add("x10-rendu-vue-dc", pos.x, pos.y, 0.5, nil, {})
end

return S
