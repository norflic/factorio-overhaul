--[[
  Lot CENTRALE-GARDE, mesure (A) PROVOQUÉE et déterministe : la partie du guide (comme etape1-guide) ; à 30 min, pour chaque équipe qui a une
  centrale FINIE (chaudière, machine à vapeur et pompe sur la carte), un groupe de 8 small-biter est posé à 26 tuiles à l'ouest de la
  chaudière et reçoit l'ordre d'attaquer la zone de la centrale. À +5 min, pour chaque équipe : pièces de centrale vivantes avant / après,
  tourelles à moins de 25 tuiles (armées) avant / après, biters restants. « Centrale vivante » = les trois sortes de pièces présentes.
  Joué avec le code du lot et avec le témoin (main) : la différence est le lot.
  Lancement : banc.py --out <archive> --graine <g> --qui PLANDIR -- 127000 centrale-assaut <source>
  Journal : [FO-CENTRALE-ASSAUT].
]]

local base = require("scenarios/verif_guide_common")(30)
local TAG = "[FO-CENTRALE-ASSAUT] "
local init0, tick0 = base.init, base.tick
local MIN = 3600
local T_ATTACK, T_MEASURE = 30 * MIN, 35 * MIN
local N_BITERS, OFFSET, TURRET_R = 8, 26, 25

base.description = "CENTRALE-GARDE : assaut provoque (8 small-biter a 30 min) sur chaque centrale finie"
base.check_tick = T_MEASURE + 600

base.init = function(ctx)
  local a = ctx.call("war_setting", "fo-war-ia3e", true)
  ctx.check(a == true, "reglage fo-war-ia3e allume", tostring(a))
  local b = ctx.call("war_setting", "fo-war-capi", true)
  ctx.check(b == true, "reglage fo-war-capi allume", tostring(b))
  if init0 then init0(ctx) end
end

local TURRETS = { "ammo-turret", "electric-turret", "fluid-turret" }

local function forces_list()
  local out = { { key = "player", force = "player" } }
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    if row.key ~= "player" then out[#out + 1] = { key = row.key, force = row.force } end
  end
  return out
end

local function pieces(s, force)
  local boiler = s.find_entities_filtered({ type = "boiler", force = force })
  local engine = s.find_entities_filtered({ type = "generator", force = force })
  local pump = s.find_entities_filtered({ type = "offshore-pump", force = force })
  return boiler, engine, pump
end

local function turrets_near(s, force, pos)
  local armed, total = 0, 0
  for _, t in ipairs(s.find_entities_filtered({ position = pos, radius = TURRET_R, force = force, type = TURRETS })) do
    total = total + 1
    local inv = t.get_inventory(defines.inventory.turret_ammo)
    if inv and inv.get_item_count() >= 8 then armed = armed + 1 end
  end
  return armed, total
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  local st = ctx.state()
  local s = ctx.surface()
  st.assaut = st.assaut or {}
  if e.tick == T_ATTACK then
    for _, fr in ipairs(forces_list()) do
      local boiler, engine, pump = pieces(s, fr.force)
      local rec = { key = fr.key, force = fr.force, fini = (#boiler >= 1 and #engine >= 1 and #pump >= 1) }
      if rec.fini then
        local c = boiler[1].position
        rec.pos = { x = c.x, y = c.y }
        rec.before = { #boiler, #engine, #pump }
        rec.tur0_armed, rec.tur0 = turrets_near(s, fr.force, c)
        local units = {}
        for i = 1, N_BITERS do
          local spot = s.find_non_colliding_position("small-biter", { c.x - OFFSET, c.y + (i - 4.5) * 1.5 }, 6, 0.5)
          local u = spot and s.create_entity({ name = "small-biter", position = spot, force = "enemy" })
          if u then
            u.set_command({ type = defines.command.attack_area, destination = c, radius = 24,
              distraction = defines.distraction.by_enemy })
            units[#units + 1] = u
          end
        end
        rec.units = units
        rec.sent = #units
      end
      st.assaut[#st.assaut + 1] = rec
      log(TAG .. string.format("a 30 min | %s | centrale finie %s | pieces %s | tourelles <%d tuiles : armees %s sur %s | biters lances %s",
        fr.key, tostring(rec.fini), rec.before and table.concat(rec.before, "/") or "-", TURRET_R,
        tostring(rec.tur0_armed or "-"), tostring(rec.tur0 or "-"), tostring(rec.sent or "-")))
    end
  elseif e.tick == T_MEASURE then
    for _, rec in ipairs(st.assaut) do
      if rec.fini then
        local boiler, engine, pump = pieces(s, rec.force)
        rec.after = { #boiler, #engine, #pump }
        rec.tur1_armed, rec.tur1 = turrets_near(s, rec.force, rec.pos)
        local alive = 0
        for _, u in ipairs(rec.units) do if u.valid then alive = alive + 1 end end
        rec.biters_left = alive
        rec.vivante = (#boiler >= 1 and #engine >= 1 and #pump >= 1)
        log(TAG .. string.format("a 35 min | %s | centrale vivante %s | pieces avant %s apres %s | tourelles armees %s -> %s (totales %s -> %s) | biters restants %d sur %d",
          rec.key, tostring(rec.vivante), table.concat(rec.before, "/"), table.concat(rec.after, "/"), tostring(rec.tur0_armed),
          tostring(rec.tur1_armed), tostring(rec.tur0), tostring(rec.tur1), alive, rec.sent))
        rec.units = nil
      end
    end
  end
end

base.finish = function(ctx)
  local st = ctx.state()
  local n_fini, n_vivante = 0, 0
  for _, rec in ipairs(st.assaut or {}) do
    if rec.fini then
      n_fini = n_fini + 1
      if rec.vivante then n_vivante = n_vivante + 1 end
    end
  end
  ctx.check(st.assaut ~= nil and #st.assaut >= 1, "l'assaut a eu lieu a 30 min")
  ctx.check(n_fini >= 1, "au moins une equipe avait une centrale finie a 30 min", tostring(n_fini))
  log(TAG .. string.format("BILAN assaut : %d centrale(s) finie(s) attaquee(s), %d vivante(s) a +5 min", n_fini, n_vivante))
end

return base
