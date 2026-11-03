--[[
  Lot NAV2 (3/11, dernière tâche) : une tâche dont le but est injoignable est-elle reprise sans fin par le PNJ libre du QG ?
  Diagnostic (rejeu du témoin, branche diag-nav2) : le PNJ « enfermé » ne l'est pas ; ses BUTS sont injoignables et la tâche ratée revient
  toutes les 30 s. Banc CIBLÉ : votre équipe de 8 PNJ ; un avant-poste de charbon (pose réelle) sur un ÎLOT (anneau d'eau de 8 à 12 tuiles
  autour) : sa tournée échoue toujours ; foreuses à sec ; 400 charbons au QG. Fenêtre de 10 min (tick 60) : échecs « chemin » et tâches
  réussies de l'équipe (ligne d'état du mod). Règle « délai croissant » allumée (nav2-repli) ou coupée (nav2-repli-temoin).
]]
local MIN = 3600
local W0 = 60
local WINDOW = 10 * MIN
local CHECK = W0 + WINDOW + 100

local function status()
  local ok, line = pcall(remote.call, "factorio-overhaul", "team_status")
  if not ok or type(line) ~= "string" then return 0, 0, 0 end
  local fails = tonumber(line:match("echecs {[^}]-chemin:(%d+)") or "0") or 0
  local done, failed = 0, 0
  local ts = line:match("taches ok/echec {([^}]*)}") or ""
  for a, b in ts:gmatch("(%d+)/(%d+)") do done = done + tonumber(a) failed = failed + tonumber(b) end
  return fails, done, failed
end

return function(rule)
  local TAG = "[FO-NAV2-REPLI" .. (rule and "]" or "-TEMOIN]")
  return {
    description = "NAV2 : tournee vers un avant-poste sur un ilot (but injoignable), regle " .. (rule and "ALLUMEE" or "COUPEE (temoin)"),
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local st = ctx.state()
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
      local s = ctx.surface()
      local c0 = game.forces.player.get_spawn_position(s)
      local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
      local hq = { x = math.floor(p.x) + 0.5, y = math.floor(p.y) + 0.5 }
      local cc = { x = math.floor(hq.x) + 48, y = math.floor(hq.y) }
      ctx.prepare_area(cc.x - 30, cc.y - 30, cc.x + 30, cc.y + 30, "grass-1")
      for dx = -5, 5 do
        for dy = -5, 5 do
          if dx * dx + dy * dy <= 25 then s.create_entity({ name = "coal", position = { cc.x + dx, cc.y + dy }, amount = 20000 }) end
        end
      end
      local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      if not chest then return end
      local inv = chest.get_inventory(defines.inventory.chest)
      inv.insert({ name = "iron-plate", count = 200 })
      inv.insert({ name = "coal", count = 400 })
      ctx.check(ctx.remote("fo-ia1", "set_regle_repli", "player", rule) == rule, "interrupteur de la regle : " .. (rule and "allumee" or "coupee"))
      local o = ctx.remote("fo-ia1", "bench_outpost", "player", "coal", cc.x, cc.y)
      ctx.check(o ~= nil, "avant-poste de charbon pose", o and (o.drills .. " foreuse(s)") or "nil")
      local tiles = {}
      for dx = -12, 12 do
        for dy = -12, 12 do
          local d2 = dx * dx + dy * dy
          if d2 >= 64 and d2 <= 144 then tiles[#tiles + 1] = { name = "water", position = { cc.x + dx, cc.y + dy } } end
        end
      end
      s.set_tiles(tiles)
      st.cc = cc
      ctx.log(string.format("%s depart : avant-poste sur un ilot en (%d, %d), anneau d'eau de %d tuiles", TAG, cc.x, cc.y, #tiles))
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.cc then return end
      local t = e.tick
      if t == W0 then
        st.f0, st.d0, st.x0 = status()
        st.t0 = t
      end
      if st.t0 and t > W0 and (t - W0) % (2 * MIN) == 0 and t <= W0 + WINDOW then
        local f1, d1 = status()
        ctx.log(string.format("%s minute %d | echecs chemin %d | taches reussies %d", TAG, (t - W0) / MIN, f1 - st.f0, d1 - st.d0))
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      if not st.t0 then ctx.check(false, "la fenetre a commence") return end
      local f1, d1, x1 = status()
      ctx.log(string.format("%s RESULTAT echecs_chemin=%d taches_reussies=%d taches_ratees=%d", TAG, f1 - st.f0, d1 - st.d0, x1 - st.x0))
      ctx.check(f1 - st.f0 >= 1, "le but est bien injoignable (au moins un echec de chemin)", tostring(f1 - st.f0))
    end,
  }
end
