--[[
  Lot INSTRUMENT-CENTRALE : essai de la ligne [FO-CENTRALE-MORT] en moteur réel. Une fois la centrale de VOTRE équipe finie, le
  scénario pose une tourelle armée à 8 tuiles de la chaudière, puis tue (die, force « enemy ») la chaudière, une machine à vapeur et la
  pompe : trois lignes [FO-CENTRALE-MORT] attendues, dont la tourelle armée comptée à moins de 25 tuiles. Sert à PROUVER que
  l'abonnement lit l'événement sans erreur ; les parties de jugement ne tuent rien.
  Lancement : banc.py --out <archive> --graine 123456789 --qui PLANDIR -- 24300 centrale-mort-essai <source>
]]

local base = require("scenarios/verif_guide_common")(30)
local TAG = "[FO-CENTRALE-MORT-ESSAI] "
local init0, tick0 = base.init, base.tick

base.description = "INSTRUMENT-CENTRALE : essai de la ligne de mort des pieces de centrale"
base.check_tick = 24000

base.init = function(ctx)
  local a = ctx.call("war_setting", "fo-war-ia3e", true)
  ctx.check(a == true, "reglage fo-war-ia3e allume", tostring(a))
  local b = ctx.call("war_setting", "fo-war-capi", true)
  ctx.check(b == true, "reglage fo-war-capi allume", tostring(b))
  if init0 then init0(ctx) end
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  local st = ctx.state()
  if st.killed or e.tick % 300 ~= 0 or e.tick < 6000 then return end
  local s = ctx.surface()
  local okp, status = pcall(remote.call, "fo-ia3e", "status", "player")
  if not (okp and status and status.plant_state == "fini") then return end
  local boiler = s.find_entities_filtered({ type = "boiler", force = "player", limit = 1 })[1]
  local engine = s.find_entities_filtered({ type = "generator", force = "player", limit = 1 })[1]
  local pump = s.find_entities_filtered({ type = "offshore-pump", force = "player", limit = 1 })[1]
  if not (boiler and engine and pump) then return end
  st.killed = true
  local spot = s.find_non_colliding_position("gun-turret", { boiler.position.x + 8, boiler.position.y + 8 }, 12, 1)
  local turret = spot and s.create_entity({ name = "gun-turret", position = spot, force = "player" })
  if turret then turret.insert({ name = "firearm-magazine", count = 10 }) end
  st.turret = turret ~= nil
  local enemy = game.forces["enemy"]
  local n = 0
  for _, ent in ipairs({ boiler, engine, pump }) do
    if ent.valid and ent.die(enemy) then n = n + 1 end
  end
  st.deaths = n
  log(TAG .. string.format("a %.1f min : tourelle posee %s, %d piece(s) tuee(s)", e.tick / 3600, tostring(st.turret), n))
end

base.finish = function(ctx)
  local st = ctx.state()
  ctx.check(st.killed == true, "la centrale a ete finie puis tuee avant la fin")
  ctx.check((st.deaths or 0) == 3, "trois pieces tuees (chaudiere, machine, pompe)", tostring(st.deaths))
  ctx.check(st.turret == true, "la tourelle armee a ete posee")
end

return base
