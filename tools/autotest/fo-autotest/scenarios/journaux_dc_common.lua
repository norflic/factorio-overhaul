--[[
  Lot JOURNAUX-DC (30/10) : banc COURT des journaux et du message de fin de guerre, en moteur réel.
  3 factions (10 soldats, 4 ouvriers : nombre écrit au lancement), un coffre d'équipe du joueur, puis :
    tick 120  réglage fo-war-workers écrit par script            -> [FO-REGLAGES] changement de fo-war-workers
    tick 300  QG de la 1re faction (forces triées) tué par les biters -> [FO-ANEANTI] cause biters, 2 vivantes
    tick 400  QG de la 2e faction tué par : les biters (« neutre ») ou la 3e faction (« victoire »)
              -> message « seule faction encore debout » (neutre) ou « remporte la guerre » (victoire)
    tick 500  coffre d'équipe tué par les biters                   -> [FO-PTEAM] perdu
  Les lignes de journal sont relues APRÈS le banc (grep de benchmark.log) : un scénario ne lit pas le journal.
  Lancement : banc.py --qui JOURNAUX-DC -- 700 journaux-dc <source> (et journaux-dc-victoire).
]]

return function(variant)
  local function hqs(s)
    local list = s.find_entities_filtered({ name = "fo-faction-hq" })
    table.sort(list, function(a, b) return a.force.name < b.force.name end)
    return list
  end
  local function alive_count(ctx)
    local n = 0
    for _, f in ipairs(ctx.remote("fo-pvp", "status").factions or {}) do if not f.eliminated then n = n + 1 end end
    return n
  end

  return {
    description = "JOURNAUX-DC : chute des QG (" .. variant .. "), reglages, equipe du joueur",
    base = nil,
    check_tick = 600,

    init = function(ctx)
      local started = ctx.call("war_start", 3, 10, 4)
      ctx.check(started == true, "guerre lancee : 3 factions, 10 soldats, 4 ouvriers", tostring(started))
      local s = ctx.surface()
      local c = game.forces.player.get_spawn_position(s)
      local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
      local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
      if chest then chest.insert({ name = "iron-plate", count = 200 }) end
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      local st = ctx.state()
      st.chest = chest and chest.position
      st.hqs = #hqs(s)
      ctx.check(st.hqs == 3, "3 QG de faction poses", st.hqs)
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      local s = ctx.surface()
      if e.tick == 120 then
        st.workers = ctx.call("war_setting", "fo-war-workers", 12)
      elseif e.tick == 300 then
        local l = hqs(s)
        st.first = l[1] and l[1].force.name
        if l[1] then l[1].die(game.forces.enemy) end
      elseif e.tick == 310 then
        st.alive1 = alive_count(ctx)
      elseif e.tick == 400 then
        local l = hqs(s)
        st.second, st.third = l[1] and l[1].force.name, l[2] and l[2].force.name
        if l[1] and l[2] then
          l[1].die(variant == "victoire" and l[2].force or game.forces.enemy)
        end
      elseif e.tick == 410 then
        st.alive2 = alive_count(ctx)
      elseif e.tick == 500 then
        local chest = st.chest and s.find_entity("fo-team-chest", st.chest)
        st.chest_found = chest ~= nil
        if chest then chest.die(game.forces.enemy) end
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local s = ctx.surface()
      ctx.check(st.workers == 12, "reglage fo-war-workers ecrit par script (journal [FO-REGLAGES] attendu)", tostring(st.workers))
      ctx.check(st.alive1 == 2, "1re chute (" .. tostring(st.first) .. ", biters) : 2 factions vivantes", tostring(st.alive1))
      ctx.check(st.alive2 == 1, "2e chute (" .. tostring(st.second) .. ", " .. variant .. ") : 1 faction vivante (" ..
        tostring(st.third) .. ")", tostring(st.alive2))
      ctx.check(st.chest_found == true, "coffre d'equipe trouve au tick 500")
      ctx.check(s.count_entities_filtered({ name = "fo-team-chest" }) == 0, "coffre d'equipe detruit")
    end,
  }
end
