--[[
  Lot CORR-SOLDATS, garde-fou : etape1-guide (216 300 ticks, la partie du guide) + un releve des expeditions des soldats inactifs toutes les
  10 minutes, par faction : [FO-SOLDATS-GUIDE] minute N | cle | offense=.. nettoyages=.. retraites=.. soldats=.. pres_du_QG=..
  opts.sans : la regle est coupee des que la guerre existe (war_option soldats_offensive = false) : temoin A/A' sur le meme code.
]]
return function(opts)
  local base = require("scenarios/etape1-guide")
  local tick0 = base.tick
  local TAG = "[FO-SOLDATS-GUIDE] "
  base.description = (base.description or "") .. (opts.sans and " + SOLDATS regle coupee" or " + SOLDATS releves")
  base.tick = function(ctx, e)
    if tick0 then tick0(ctx, e) end
    local st = ctx.state()
    if opts.sans and not st.soldats_cut and e.tick % 60 == 0 then
      if ctx.call("war_option", "soldats_offensive", false) == true then
        st.soldats_cut = e.tick
        ctx.log(TAG .. "regle coupee au tick " .. e.tick)
      end
    end
    if e.tick > 0 and e.tick % 36000 == 0 then
      local s = ctx.surface()
      for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
        if row.key ~= "player" then
          local v = remote.call("fo-ia3k", "status", row.key)
          local sv = v and v.stats or {}
          local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = row.force, limit = 1 })[1]
          local n = #s.find_entities_filtered({ force = row.force, type = "unit" })
          local near = hq and #s.find_entities_filtered({ position = hq.position, radius = 45, force = row.force, type = "unit" }) or 0
          log(TAG .. string.format("minute %d | %s | offense=%d nettoyages=%d retraites=%d soldats=%d pres_du_QG=%d", e.tick / 3600, row.key,
            sv.offense_ops or 0, sv.clear_ops or 0, sv.retreats or 0, n, near))
        end
      end
    end
  end
  return base
end
