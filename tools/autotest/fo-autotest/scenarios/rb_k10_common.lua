-- Lot RB-4 GAMME (1/11) : générateur commun des scénarios rb-k10 (mesure K10 : coût par tick d'une armée de 510 robots).
--   vide  : la même carte, aucune unité (référence) ;
--   armee : 5 forces d'âge 15, chacune 4 Cloches + 98 robots de 1 point (Trotte-Vapeur et Bobineur), soit 510 unités dont 20 Cloches ;
--           toutes les 600 ticks les 5 armées marchent d'un point à l'autre (40 tuiles), toutes les 300 ticks 60 robots par force sont
--           blessés de moitié (les Cloches soignent). Aucun ennemi.
-- Mesure : « Performed N updates in X ms » du banc lancé avec --seul (tools/autotest/analyze.py), armee moins vide. Le scénario ne mesure
-- rien lui-même : il compte les robots vivants au tick de fin. Journal : [FO-RB-K10].
local C = require("scenarios/rb0_common")

local X0, Y0 = 10000, 10000
local FORCES = 5

local function R(ctx, fn, ...) return ctx.remote("fo-robots", fn, ...) end

return function(mode)
  return {
    description = "RB-4 K10 : cout par tick, mode " .. mode,
    base = nil,
    check_tick = 2900,

    init = function(ctx)
      local st = ctx.state()
      st.pret = false
      local s = ctx.surface()
      game.map_settings.enemy_expansion.enabled = false
      ctx.prepare_area(X0 - 60, Y0 - 100, X0 + 700, Y0 + 100, "grass-1")
      C.sans_ennemis(s, X0 - 80, Y0 - 120, X0 + 720, Y0 + 120)
      st.forces, st.units = {}, {}
      if mode == "armee" then
        if not C.exige(ctx, { "fo-robot-player-steam-trotter", "fo-robot-player-coiler", "fo-robot-player-bellwether" }, "robots") then return end
        ctx.call("war_setting", "fo-war-robots-cap", 600)
        for k = 1, FORCES do
          local name = "rb-k" .. k
          C.force(name)
          R(ctx, "set_age", name, 15)
          local cx = X0 + 130 * (k - 1)
          st.forces[k] = { name = name, cx = cx, list = {} }
          for i = 1, 102 do
            local id = (i <= 4) and "bellwether" or ((i % 2 == 0) and "steam-trotter" or "coiler")
            local col, row = (i - 1) % 10, math.floor((i - 1) / 10)
            local un = R(ctx, "spawn", name, id, cx + col * 2.5, Y0 + row * 2.5)
            if un then st.forces[k].list[#st.forces[k].list + 1] = un end
          end
        end
      end
      local n = 0
      for _, f in ipairs(st.forces) do n = n + #f.list end
      ctx.log(string.format("mode %s : %d robot(s) poses (demande %d)", mode, n, mode == "armee" and FORCES * 102 or 0))
      st.pret = true
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.pret or mode ~= "armee" then return end
      local t = e.tick
      if t >= 60 and (t - 60) % 600 == 0 then
        local alt = ((t - 60) / 600) % 2
        for _, f in ipairs(st.forces) do
          R(ctx, "order", f.name, "move", f.cx + 12 + alt * 40, Y0 + 12, { x = f.cx + 12, y = Y0 + 12, radius = 200 }, 2)
        end
      end
      if t >= 100 and (t - 100) % 300 == 0 then
        for _, f in ipairs(st.forces) do
          for i = 5, 64 do if f.list[i] then R(ctx, "hurt", f.list[i], 0.5) end end
        end
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      if not st.pret then return end
      local vivants, soins = 0, nil
      for _, f in ipairs(st.forces) do
        local etat = R(ctx, "state", f.name)
        vivants = vivants + (etat and #etat.units or 0)
      end
      if mode == "armee" then
        soins = ctx.remote("fo-robots-soutien", "stats")
        ctx.check(vivants == FORCES * 102 and R(ctx, "check") == true, "510 robots vivants, registre coherent",
          string.format("%d vivants, soins %s PV en %s impulsions", vivants, tostring(soins and soins.heal_hp), tostring(soins and soins.healed)))
      end
      ctx.log(string.format("[FO-RB-K10] mode %s : %d robot(s) vivant(s)", mode, vivants))
    end,
  }
end
