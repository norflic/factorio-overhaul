-- Diagnostic (lot CENTRALE, focus Azure) : etape1-guide + suivi des soldats des factions toutes les 5 s entre 3 et 15 min :
-- effectif, position moyenne par rapport au QG, sante minimale, ennemis (biters, vers, nids) a moins de 60 tuiles du QG et des soldats.
-- Ligne : [FO-SOLDATS] tick N | <faction> | soldats=.. dist_qg_moy=.. dist_qg_max=.. sante_min=.. | ennemis<=40 du QG : .. | <=60 des soldats : ..
local base = require("scenarios/etape1-guide")
local tick0 = base.tick
local TAG = "[FO-SOLDATS] "
base.description = (base.description or "") .. " + suivi des soldats"

local function factions()
  local out = {}
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    if row.key ~= "player" then out[#out + 1] = row end
  end
  return out
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  if e.tick < 10800 or e.tick > 54000 or e.tick % 300 ~= 0 then return end
  local s = ctx.surface()
  for _, r in ipairs(factions()) do
    local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = r.force, limit = 1 })[1]
    if hq then
      local us = s.find_entities_filtered({ type = "unit", force = r.force })
      local sum, mx, hmin = 0, 0, 1
      local cx, cy = 0, 0
      for _, u in ipairs(us) do
        local d = math.sqrt((u.position.x - hq.position.x) ^ 2 + (u.position.y - hq.position.y) ^ 2)
        sum, mx = sum + d, math.max(mx, d)
        cx, cy = cx + u.position.x, cy + u.position.y
        hmin = math.min(hmin, u.health / math.max(1, u.prototype.max_health))
      end
      local n = #us
      local en_hq = s.find_entities_filtered({ position = hq.position, radius = 40, force = "enemy" })
      local nb, nw, ns = 0, 0, 0
      for _, x in ipairs(en_hq) do
        if x.type == "unit" then nb = nb + 1 elseif x.type == "turret" then nw = nw + 1 elseif x.type == "unit-spawner" then ns = ns + 1 end
      end
      local near = "-"
      if n > 0 then
        local en2 = s.find_entities_filtered({ position = { cx / n, cy / n }, radius = 60, force = "enemy" })
        local a, b, c = 0, 0, 0
        for _, x in ipairs(en2) do
          if x.type == "unit" then a = a + 1 elseif x.type == "turret" then b = b + 1 elseif x.type == "unit-spawner" then c = c + 1 end
        end
        near = string.format("biters %d vers %d nids %d centre (%.0f,%.0f)", a, b, c, cx / n, cy / n)
      end
      log(TAG .. string.format("tick %d | %s | hq (%.0f,%.0f) soldats=%d dist_qg_moy=%.0f dist_qg_max=%.0f sante_min=%.2f | ennemis<=40 du QG : biters %d vers %d nids %d | <=60 des soldats : %s",
        e.tick, r.key, hq.position.x, hq.position.y, n, n > 0 and sum / n or 0, mx, hmin, nb, nw, ns, near))
    end
  end
end
return base
