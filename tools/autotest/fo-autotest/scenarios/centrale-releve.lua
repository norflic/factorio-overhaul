--[[
  Lot CENTRALE-RELEVE : la partie etape1-guide telle quelle ; une fois la centrale de VOTRE équipe finie et au plus tôt à 12 min (fer au
  coffre), le scénario tue (die, force « enemy ») UNE chaudière et UNE pompe d'eau de votre équipe, puis relève chaque minute ce qui se tient
  à leurs places (même nom, même force) : la centrale doit être reconstruite. Contrôle : chaudière ET pompe revenues avant la fin.
  Lancement : banc.py --out <archive> --graine 2507543475 --qui CENTRALE-RELEVE -- 230000 centrale-releve <source>
  Journal : [FO-CENTRALE-RELEVE] (une ligne à la mort, une par minute ensuite, une au retour de chaque pièce).
]]
local base = require("scenarios/etape1-guide")
local TAG = "[FO-CENTRALE-RELEVE] "
local MIN = 3600
local T_MIN = 12 * MIN
local tick0, finish0 = base.tick, base.finish
base.description = "CENTRALE-RELEVE : " .. tostring(base.description or "etape1-guide") .. ", chaudiere et pompe tuees a 12 min"

local function back(s, p)
  local e = s.find_entities_filtered({ name = p.name, position = { p.x, p.y }, radius = 0.6, force = "player", limit = 1 })[1]
  return e ~= nil and e.valid
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  local st = ctx.state()
  local s = ctx.surface()
  if not st.killed then
    if e.tick < T_MIN or e.tick % 300 ~= 0 then return end
    local okp, status = pcall(remote.call, "fo-ia3e", "status", "player")
    if not (okp and status and status.plant_state == "fini") then return end
    local pump = s.find_entities_filtered({ type = "offshore-pump", force = "player", limit = 1 })[1]
    if not pump then return end
    local boiler = s.find_entities_filtered({ type = "boiler", force = "player", position = pump.position, radius = 12, limit = 1 })[1]
    if not boiler then return end
    st.killed = e.tick
    st.parts = {}
    local enemy = game.forces["enemy"]
    for _, ent in ipairs({ boiler, pump }) do
      local p = { name = ent.name, x = ent.position.x, y = ent.position.y }
      if ent.die(enemy) then st.parts[#st.parts + 1] = p end
    end
    log(TAG .. string.format("a %.1f min : %d piece(s) tuee(s) : %s en (%.1f, %.1f), %s en (%.1f, %.1f)", e.tick / MIN, #st.parts,
      boiler.valid and boiler.name or "boiler", st.parts[1] and st.parts[1].x or 0, st.parts[1] and st.parts[1].y or 0,
      "offshore-pump", st.parts[2] and st.parts[2].x or 0, st.parts[2] and st.parts[2].y or 0))
    return
  end
  if e.tick % MIN ~= 0 then return end
  local row = {}
  for _, p in ipairs(st.parts or {}) do
    local ok = back(s, p)
    if ok and not p.back then
      p.back = e.tick
      log(TAG .. string.format("%s revenu en (%.1f, %.1f) a %.1f min, %.1f min apres sa mort", p.name, p.x, p.y, e.tick / MIN,
        (e.tick - st.killed) / MIN))
    end
    row[#row + 1] = p.name .. "=" .. (ok and "debout" or "absent")
  end
  local fer
  for _, r in ipairs(remote.call("fo-ia1", "teams") or {}) do if r.key == "player" then fer = r.iron end end
  log(TAG .. string.format("minute %d | %s | fer %s", e.tick / MIN, table.concat(row, " "), tostring(fer)))
end

base.finish = function(ctx)
  if finish0 then finish0(ctx) end
  local st = ctx.state()
  ctx.check(st.killed ~= nil, "chaudiere et pompe de votre equipe tuees")
  for _, p in ipairs(st.parts or {}) do
    ctx.check(p.back ~= nil, p.name .. " reconstruit(e) avant la fin", p.back and string.format("%.1f min", p.back / MIN) or "absent")
  end
end

return base
