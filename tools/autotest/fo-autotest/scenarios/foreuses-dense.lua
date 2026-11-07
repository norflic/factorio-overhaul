--[[
  Lot FOREUSES-THERMIQUES, revue du lead (7/11, B2) : COÛT du remplacement sur place (portée tt:foswap du profileur) sur un avant-poste
  DENSE de votre équipe (au moins 171 foreuses à combustion, comme le plus gros de la partie du DC). Même mise en place que foreuses-chaine
  (interface d'énergie, radar, petit poteau source), gisement de fer de rayon 34 ; au tick W0, l'avant-poste est bâti puis agrandi
  (bench_extend) jusqu'à 171 foreuses au moins ; le coffre porte 12 foreuses électriques et 60 petits poteaux. Profileur fin allumé à
  W0 + 60, rapport du banc au journal à la fin (12 passes de remplacement : 3 600 ticks).
  MESURE : à lancer SEUL sur le PC (banc.py --seul), avant et après le correctif B2 :
    py -3.9 -B tools/autotest/banc.py --seul --out <archive> --qui FOREUSES-TH -- 4000 foreuses-dense <source>
  Lecture : ligne « tt:foswap | total … | moyenne/tick … » du rapport [FO-AUTOTEST] ===== FOREUSES-DENSE (passes : RESULTAT).
]]

local W0 = 120
local PROF = W0 + 60
local CHECK = PROF + 3600
local WANT = 171

return {
  description = "FOREUSES-THERMIQUES (B2) : cout du remplacement sur un avant-poste de 171 foreuses",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 4) == 4, "effectif de depart 4")
    local s = ctx.surface()
    local c0 = game.forces.player.get_spawn_position(s)
    local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
    local hq = { x = math.floor(p.x) + 0.5, y = math.floor(p.y) + 0.5 }
    local cc = { x = math.floor(hq.x) + 70, y = math.floor(hq.y) }
    ctx.prepare_area(hq.x - 6, cc.y - 50, cc.x + 50, cc.y + 50, "grass-1")
    local n_ore = 0
    for dx = -34, 34 do
      for dy = -34, 34 do
        if dx * dx + dy * dy <= 34 * 34 then
          s.create_entity({ name = "iron-ore", position = { cc.x + dx, cc.y + dy }, amount = 20000 })
          n_ore = n_ore + 1
        end
      end
    end
    local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose", string.format("gisement de fer %d tuiles en (%d, %d)", n_ore, cc.x, cc.y))
    if not chest then return end
    local inv = chest.get_inventory(defines.inventory.chest)
    inv.insert({ name = "iron-plate", count = 200 })
    inv.insert({ name = "coal", count = 200 })
    inv.insert({ name = "electric-mining-drill", count = 12 })
    inv.insert({ name = "small-electric-pole", count = 60 })
    local ex, ey = math.floor(hq.x) + 6, math.floor(hq.y) - 8
    local eei = s.create_entity({ name = "electric-energy-interface", position = { ex + 1, ey + 1 }, force = "player" })
    if eei then
      eei.power_production = 1e7 / 60
      eei.electric_buffer_size = 1e7
    end
    local src = s.create_entity({ name = "small-electric-pole", position = { ex + 3.5, ey + 1.5 }, force = "player" })
    s.create_entity({ name = "radar", position = { ex + 5.5, ey + 1.5 }, force = "player" })
    ctx.check(eei ~= nil and src ~= nil, "reseau source pose (interface, poteau, radar)")
    -- revue (4) : seul un poteau de l'équipe sert de source ; une source d'avant la revue (mesure « avant » de B2) n'a pas ce remote
    if remote.interfaces["fo-ia1"] and remote.interfaces["fo-ia1"].bench_own then
      ctx.check(src ~= nil and ctx.remote("fo-ia1", "bench_own", "player", src) == true, "poteau source enregistre a votre equipe (revue (4))")
    end
    st.cc, st.hq, st.src = cc, hq, src
    st.acc = { x = cc.x - 35 + 0.5, y = cc.y + 0.5 }
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.cc then return end
    if e.tick == W0 then
      local o = ctx.remote("fo-ia1", "bench_outpost", "player", "iron", st.cc.x, st.cc.y, st.acc.x, st.acc.y)
      ctx.check(o ~= nil, "avant-poste de fer pose", o and (o.drills .. " foreuse(s)") or "nil")
      if not o then return end
      local drills = o.drills
      for _ = 1, 4 do
        if (drills or 0) >= WANT then break end
        local n = ctx.remote("fo-ia1", "bench_extend", "player", o.id, 20)
        if not n or n == drills then break end
        drills = n
      end
      st.oid, st.drills = o.id, drills
      ctx.log(string.format("[FO-FOREUSES-DENSE] W0 : avant-poste %d, %d foreuse(s) a combustion", o.id, drills or 0))
    elseif e.tick == PROF then
      ctx.call("profiler", true, true)
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check((st.drills or 0) >= WANT, "avant-poste dense : au moins 171 foreuses a combustion", tostring(st.drills))
    ctx.call("log_report", "FOREUSES-DENSE")
    local r = ctx.remote("fo-ia1", "swap_outposts", "player")
    ctx.log(string.format("[FO-FOREUSES-DENSE] RESULTAT foreuses_W0=%d passes=%d fin=[thermiques=%s electriques=%s] swap=[%s]", st.drills or 0,
      math.floor((CHECK - PROF) / 300), r and tostring(r.burners) or "?", r and tostring(r.electrics) or "?",
      tostring(ctx.remote("fo-ia1", "swap_state", "player"))))
  end,
}
