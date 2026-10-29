--[[
  Lot CENTRALE-GARDE, preuve « la garde n'insiste pas » : la partie du guide ; à 45 min, TOUTES les pièces de centrale (chaudières, machines à
  vapeur, pompes) de chaque équipe sont détruites (die, force « enemy ») et jamais reconstruites (main ne reconstruit pas). Jusqu'à 60 min, la
  garde ne doit plus poser de tourelle autour des ruines : on compte les tourelles de chaque équipe à moins de 25 tuiles des ruines à 45 min
  (juste avant) et à 60 min. Le lot sans le correctif (0b8b924) remplace des tourelles à l'infini autour des ruines.
  Lancement : banc.py --out <archive> --graine <g> --qui PLANDIR -- 217000 centrale-ruine <source>
  Journal : [FO-CENTRALE-RUINE] ; les poses sont aussi dans [FO-CENTRALE-GARDE] (lignes « pose de ... » après 45 min).
]]

local base = require("scenarios/verif_guide_common")(30)
local TAG = "[FO-CENTRALE-RUINE] "
local init0, tick0 = base.init, base.tick
local MIN = 3600
local T_KILL, T_END = 45 * MIN, 60 * MIN
local TURRET_R = 25
local TURRETS = { "ammo-turret", "electric-turret", "fluid-turret" }

base.description = "CENTRALE-GARDE : centrales detruites a 45 min, la garde n'insiste pas jusqu'a 60 min"
base.check_tick = T_END + 600

base.init = function(ctx)
  local a = ctx.call("war_setting", "fo-war-ia3e", true)
  ctx.check(a == true, "reglage fo-war-ia3e allume", tostring(a))
  local b = ctx.call("war_setting", "fo-war-capi", true)
  ctx.check(b == true, "reglage fo-war-capi allume", tostring(b))
  if init0 then init0(ctx) end
end

local function forces_list()
  local out = { { key = "player", force = "player" } }
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    if row.key ~= "player" then out[#out + 1] = { key = row.key, force = row.force } end
  end
  return out
end

local function turrets_near(s, force, pos)
  return s.count_entities_filtered({ position = pos, radius = TURRET_R, force = force, type = TURRETS })
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  local st = ctx.state()
  local s = ctx.surface()
  st.ruine = st.ruine or {}
  if e.tick == T_KILL then
    local enemy = game.forces["enemy"]
    for _, fr in ipairs(forces_list()) do
      local rec = { key = fr.key, force = fr.force, killed = 0 }
      local pump
      for _, ty in ipairs({ "boiler", "generator", "offshore-pump" }) do
        for _, ent in ipairs(s.find_entities_filtered({ type = ty, force = fr.force })) do
          if ent.valid then
            if ty == "offshore-pump" and not pump then pump = { x = ent.position.x, y = ent.position.y } end
            if rec.killed == 0 and not rec.pos then rec.pos = { x = ent.position.x, y = ent.position.y } end
            if ent.die(enemy) then rec.killed = rec.killed + 1 end
          end
        end
      end
      if rec.pos then rec.tur0 = turrets_near(s, fr.force, rec.pos) end
      st.ruine[#st.ruine + 1] = rec
      log(TAG .. string.format("a 45 min | %s | pieces detruites %d | tourelles <%d tuiles des ruines %s", fr.key, rec.killed, TURRET_R, tostring(rec.tur0 or "-")))
    end
  elseif e.tick == T_END then
    for _, rec in ipairs(st.ruine) do
      if rec.pos then rec.tur1 = turrets_near(s, rec.force, rec.pos) end
      log(TAG .. string.format("a 60 min | %s | tourelles <%d tuiles des ruines %s -> %s", rec.key, TURRET_R, tostring(rec.tur0 or "-"), tostring(rec.tur1 or "-")))
    end
  end
end

base.finish = function(ctx)
  local st = ctx.state()
  local n = 0
  for _, rec in ipairs(st.ruine or {}) do if rec.killed > 0 then n = n + 1 end end
  ctx.check(n >= 1, "au moins une centrale detruite a 45 min", tostring(n))
  log(TAG .. string.format("BILAN : %d centrale(s) detruite(s)", n))
end

return base
