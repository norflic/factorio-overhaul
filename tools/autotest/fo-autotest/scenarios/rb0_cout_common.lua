-- Lot RB-0 (31/10), essai E9 (coût par tick) : générateur commun des scénarios rb0-cout-*.
-- Même carte plate et mêmes ticks pour tous ; seule la population change (mode) :
--   vide : rien ; u60 : 60 unités rb0-u-09 qui font des allers-retours de 30 tuiles ; s1 : 20 rb0-spider-1 (allers-retours
--   de 30 tuiles) ; s5 : 20 rb0-spider-5 ; s5t : 20 rb0-spider-5 qui TIRENT en continu (ils ont 100 obus, une couronne de 8
--   tourelles ennemies sans munitions est reposée autour de chacun toutes les 300 ticks).
-- Mesure : « Performed N updates in X ms » du banc lancé avec --seul (tools/autotest/analyze.py), comparée à `vide`.
-- Le scénario ne mesure rien lui-même : il compte les entités vivantes au tick de fin (BILAN).
local C = require("scenarios/rb0_common")

local X0, Y0 = 10000, 10000

local MODES = {
  vide = { nom = nil, n = 0 },
  u60 = { nom = "rb0-u-09", n = 60, unite = true, pas = 8, colonnes = 10 },
  s1 = { nom = "rb0-spider-1", n = 20, pas = 40, colonnes = 5 },
  s5 = { nom = "rb0-spider-5", n = 20, pas = 100, colonnes = 5 },
  s5t = { nom = "rb0-spider-5", n = 20, pas = 100, colonnes = 5, tir = true },
}

return function(mode)
  local M = MODES[mode]
  local TAG = "cout-" .. mode
  return {
    description = "RB-0 E9 cout par tick : mode " .. mode,
    base = nil,
    check_tick = 2900,

    init = function(ctx)
      local st = ctx.state()
      st.pret = false
      local s = ctx.surface()
      if M.nom and not C.exige(ctx, { M.nom }, M.nom) then return end
      C.force("rb0")
      game.map_settings.enemy_expansion.enabled = false
      -- zone commune à tous les modes (pavée même pour « vide » : même génération de chunks)
      ctx.prepare_area(X0 - 60, Y0 - 60, X0 + 560, Y0 + 460, "grass-1")
      C.sans_ennemis(s, X0 - 80, Y0 - 80, X0 + 580, Y0 + 480)
      st.ents = {}
      for i = 1, M.n do
        local cx = (i - 1) % M.colonnes
        local cy = math.floor((i - 1) / M.colonnes)
        local x, y = X0 + cx * M.pas + 50, Y0 + cy * M.pas + 50
        local e = s.create_entity({ name = M.nom, position = { x, y }, force = "rb0" })
        local r = { e = e, x = x, y = y, vague = 0 }
        if e and M.tir then
          e.vehicle_automatic_targeting_parameters = { auto_target_without_gunner = true, auto_target_with_gunner = true }
          e.get_inventory(defines.inventory.spider_ammo).insert({ name = "rb0-shell", count = 100 })
        end
        st.ents[#st.ents + 1] = r
      end
      ctx.log("mode " .. mode .. " : " .. #st.ents .. " entites posees (demande " .. M.n .. ")")
      st.pret = true
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.pret or M.n == 0 then return end
      local t = e.tick
      local s = ctx.surface()
      if t >= 60 and (t - 60) % 300 == 0 then
        local sens = (((t - 60) / 300) % 2 == 0) and 1 or 0
        for _, r in ipairs(st.ents) do
          if r.e and r.e.valid then
            local dest = { x = r.x + 30 * sens, y = r.y }
            if M.unite then
              r.e.set_command({ type = defines.command.go_to_location, destination = dest, radius = 1, distraction = defines.distraction.none })
            else
              r.e.autopilot_destination = nil
              r.e.add_autopilot_destination(dest)
            end
            if M.tir then
              for k = 1, 8 do
                local a = k * 0.785
                s.create_entity({ name = "gun-turret", position = { math.floor(r.x + 15 * math.cos(a)), math.floor(r.y + 15 * math.sin(a)) }, force = "enemy" })
              end
            end
          end
        end
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      if not st.pret then return end
      local vivants = 0
      for _, r in ipairs(st.ents) do if r.e and r.e.valid then vivants = vivants + 1 end end
      ctx.check(vivants == M.n, "E9 cout " .. mode .. " : toutes les entites vivantes a la fin", vivants .. " / " .. M.n)
    end,
  }
end
