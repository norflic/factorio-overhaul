-- Sonde du lot RB-FLUIDE (1/11) : pourquoi une faction ne fabrique-t-elle aucun robot ? Une faction a fait les recherches d'une partie a 45 min
-- (de quoi construire le petrole), SANS la technologie des robots ; le banc ne decide rien. On lit les lignes [FO-ROBOTS] « attente » du mod.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui RB-FLUIDE -- 7300 rb-fluide-sonde <source>
local TECHS = { "automation", "logistic-science-pack", "steel-processing", "military-science-pack", "engine", "electronics", "fast-inserter",
  "automation-2", "fluid-handling", "oil-processing", "sulfur-processing", "plastics", "advanced-electronics", "chemical-science-pack" }

return {
  description = "RB-FLUIDE : sonde des causes d'attente des robots d'une faction (technologie des robots NON donnee)",
  base = nil,
  check_tick = 7200,

  init = function(ctx)
    ctx.check(ctx.remote("fo-pvp", "set_difficulty", "peaceful") == true, "difficulte Paisible")
    ctx.check(ctx.call("war_start", 2, 100) == true, "guerre lancee : 2 factions")
    ctx.check(ctx.call("war_fund", 20000) == 2, "2 factions financees")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == 400 then
      local rows = ctx.remote("fo-ia1", "teams") or {}
      for _, r in ipairs(rows) do
        if r.key ~= "player" and not st.force then st.force, st.key = r.force, r.key end
      end
      local f = game.forces[st.force]
      for _, t in ipairs(TECHS) do f.technologies[t].researched = true end
      ctx.check(not f.technologies["fo-robot-automata"].researched and f.technologies["engine"].researched,
        st.key .. " : recherches de 45 min faites, technologie des robots NON faite")
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local v = st.key and ctx.remote("fo-robots-faction", "view", st.key)
    ctx.log(string.format("fin : ateliers %s, points de robots %s", tostring(v and v.workshops), tostring(v and v.robots)))
    ctx.check(true, "sonde ecrite (voir les lignes [FO-ROBOTS] attente)")
  end,
}
