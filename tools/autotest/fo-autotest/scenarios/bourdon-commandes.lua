-- Lot BOURDON (1er/11), session AVEC joueur (--captures) : /fo-bourdon, télécommande en main, /fo-glas vers l'ennemi le plus proche, trop loin : elle y va, rappel, /fo-bourdon retirer.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--ticks 2500" --qui BOURDON -- 2500 bourdon-commandes <source>
local C = require("scenarios/bourdon_commun")

local X, Y = 7000, 3000

return {
  description = "BOURDON : les commandes de demonstration, par un joueur",
  check_tick = 2300,
  shots_delay = 2400,

  init = function(ctx)
    C.forces()
    ctx.prepare_area(X - 30, Y - 30, X + 170, Y + 30, "dry-dirt")
    local s = ctx.surface()
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X - 150, Y - 150 }, { X + 300, Y + 150 } } })) do en.destroy() end
    ctx.state().cible = s.create_entity({ name = "gun-turret", position = { X + 90, Y }, force = C.CIBLE })
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    local p = game.players[1]
    if not p or not p.character then return end
    if not st.ok_joueur and t >= 10 then
      st.ok_joueur = t
      p.teleport({ X, Y })
      st.t0 = t
      st.id = remote.call("fo-bourdon", "commande_bourdon", p.index)
      ctx.check(st.id ~= nil, "/fo-bourdon : la cloche descend", tostring(st.id))
      local c = p.cursor_stack
      ctx.check(c and c.valid_for_read and c.name == "spidertron-remote", "la telecommande est en main", c and c.valid_for_read and c.name or "rien")
      local ok, lie = pcall(function() return c.connected_entity end)
      ctx.check(ok and lie and lie.name == "fo-bourdon", "la telecommande est liee a la cloche", ok and (lie and lie.name or "rien") or tostring(lie))
    end
    if not st.t0 then return end
    local d = t - st.t0
    if d % 200 == 0 then
      local b = remote.call("fo-bourdon", "etat", st.id)
      ctx.log(string.format("t+%d : %s", d, b and string.format("%s (%.0f, %.0f) glas %d, %d tues", b.phase, b.x, b.y, b.compte, b.tues) or "absent"))
    end
    if d == 500 then
      local b = remote.call("fo-bourdon", "etat", st.id)
      ctx.check(b.phase == "pose", "posee a t+500", b.phase)
      remote.call("fo-bourdon", "commande_glas", p.index)
      -- l'ennemi le plus proche est à 90 tuiles : elle y va d'abord
    end
    if d == 510 then
      local b = remote.call("fo-bourdon", "etat", st.id)
      ctx.check(b.phase == "leve", "/fo-glas, cible lointaine : elle leve ses ancres", b.phase)
    end
    if d > 510 and d % 20 == 0 and not st.detruit then
      local b = remote.call("fo-bourdon", "etat", st.id)
      if b and b.compte >= 1 and b.tues > 0 then
        st.detruit = d
        ctx.ok("arrivee, elle sonne : l'ennemi le plus proche prend le coup", b.tues .. " tues, t+" .. d .. string.format(", cloche en (%.0f, %.0f)", b.x, b.y))
        remote.call("fo-bourdon", "muet", st.id, true)
      end
    end
    if st.detruit and not st.rappel and d >= st.detruit + 60 then
      st.rappel = d
      remote.call("fo-bourdon", "commande_bourdon", p.index)
      local b = remote.call("fo-bourdon", "etat", st.id)
      ctx.log("rappel : phase " .. b.phase)
    end
    if st.rappel and not st.rendre and d >= st.rappel + 150 then
      st.rendre = d
      local b = remote.call("fo-bourdon", "etat", st.id)
      ctx.check(b.phase == "vol" or b.phase == "leve", "le rappel la fait repartir", b.phase)
      remote.call("fo-bourdon", "commande_bourdon", p.index, "retirer")
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.detruit ~= nil, "le Glas a touche l'ennemi", tostring(st.detruit))
    ctx.check(st.rendre ~= nil and remote.call("fo-bourdon", "etat", st.id) == nil, "/fo-bourdon retirer : partie", tostring(st.rendre))
  end,

  shots = function(ctx, add)
    add("fin", X + 100, Y - 8, 0.5, 0, { res = { 1600, 1000 } })
  end,
}
