-- Scénario greffé du lot TENUE (2/11) : les STATISTIQUES DE POLLUTION du moteur (game.pollution_statistics) disent-elles ce que les nids
-- absorbent ? (la prévision ne voit que les nids CONNUS : 0 nid connu = aucune vague prévue, alors que les vagues reçues passent de 640 à
-- 41 000 PV en 20 min ; si les statistiques donnent l'absorption des nids sans qu'on les ait vus, la prévision peut s'en servir « comme le
-- joueur » qui ouvre la fenêtre des statistiques de pollution.)
--   & "<racine>\fo-autotest.bat" nopause 1500 tenue-pollution "<source>"
-- Pose un nid (biter-spawner) et un pollueur virtuel (surface.pollute chaque seconde), puis journalise toutes les 300 ticks les clés de
-- input_counts / output_counts et les débits par minute lus par get_flow_count : « [FO-TENUE-POLL] t=<tick> ... ».
local X0, Y0 = 3200, 3200

local function dump(tag)
  local ps = game.pollution_statistics
  local ent, sor = {}, {}
  for k, v in pairs(ps.input_counts) do ent[#ent + 1] = k .. "=" .. string.format("%.1f", v) end
  for k, v in pairs(ps.output_counts) do sor[#sor + 1] = k .. "=" .. string.format("%.1f", v) end
  table.sort(ent)
  table.sort(sor)
  local fl = {}
  for _, k in ipairs({ "biter-spawner", "spitter-spawner" }) do
    local ok, v = pcall(function() return ps.get_flow_count({ name = k, input = false, precision_index = defines.flow_precision_index.one_minute }) end)
    fl[#fl + 1] = k .. "/min=" .. (ok and string.format("%.2f", v) or "ERREUR")
  end
  log(string.format("[FO-TENUE-POLL] %s t=%d total_surface=%.1f | ENTREES %s | SORTIES %s | FLUX %s", tag, game.tick,
    game.surfaces[1].get_total_pollution(), table.concat(ent, " "), table.concat(sor, " "), table.concat(fl, " ")))
end

return {
  description = "TENUE-POLLUTION : statistiques de pollution du moteur et absorption d'un nid",
  base = nil,
  check_tick = 1400,

  init = function(ctx)
    local s = ctx.surface()
    ctx.prepare_area(X0 - 40, Y0 - 40, X0 + 40, Y0 + 40, "grass-1")
    game.map_settings.enemy_expansion.enabled = false
    local st = ctx.state()
    st.nest = s.create_entity({ name = "biter-spawner", position = { X0 + 20, Y0 }, force = "enemy" })
    ctx.check(st.nest ~= nil, "nid pose", st.nest and "oui" or "non")
  end,

  tick = function(ctx, e)
    local t = game.tick
    if t % 60 == 0 and t <= 1200 then game.surfaces[1].pollute({ X0, Y0 }, 600) end
    if t % 300 == 0 and t > 0 then dump("mesure") end
  end,

  finish = function(ctx)
    local st = ctx.state()
    dump("fin")
    ctx.check(st.nest and st.nest.valid, "nid toujours la", "")
  end,
}
