--[[
  Lot FLUX-VOIE : scan des tapis d'alimentation des FOURS pendant la partie du DC (dc_evolution_common : 3 factions, 30 ouvriers, réglages
  du guide), 216 000 ticks. Toutes les 18 000 ticks (5 min de jeu), pour chaque four-cible d'un bras (inserter dont drop_target est un
  four), lit les deux voies du tapis où le bras prend. Anomalie cherchée : « 2 voies de charbon » sur un tapis qui nourrit des fours
  (le fer ne peut plus descendre), ou une voie qui MÊLE charbon et minerai. Journal : [FO-FLUX-VOIE] avec force, position, voisins.
  Lancement : banc.py --qui <lot> -- 216600 flux-voie-dc <source>
]]
local base = require("scenarios/dc_evolution_common")(216000)

local EVERY, FIRST = 18000, 18000
local ORES = { ["iron-ore"] = true, ["copper-ore"] = true, ["stone"] = true }

local function show(c)
  local k, parts = {}, {}
  for n in pairs(c) do k[#k + 1] = n end
  table.sort(k)
  for _, n in ipairs(k) do parts[#parts + 1] = n .. "=" .. c[n] end
  return #parts > 0 and table.concat(parts, ",") or "-"
end
local function has_ore(c) for n in pairs(c) do if ORES[n] then return true end end return false end

local function scan(ctx, tick)
  local s = ctx.surface()
  local st = ctx.state()
  st.flux = st.flux or { seen = {}, logged = 0 }
  local fx = st.flux
  local belts, order = {}, {}
  local ins = s.find_entities_filtered({ type = "inserter" })
  table.sort(ins, function(a, b) return (a.unit_number or 0) < (b.unit_number or 0) end)
  for _, i in ipairs(ins) do
    local dt, pt = i.drop_target, i.pickup_target
    if dt and dt.valid and dt.type == "furnace" and pt and pt.valid and pt.type == "transport-belt" and not belts[pt.unit_number] then
      belts[pt.unit_number] = { belt = pt, inserter = i }
      order[#order + 1] = pt.unit_number
    end
  end
  table.sort(order)
  local per = {}
  local n, both, mixed = 0, 0, 0
  for _, u in ipairs(order) do
    local b = belts[u].belt
    if b.valid then
      n = n + 1
      local l1, l2 = b.get_transport_line(1).get_contents(), b.get_transport_line(2).get_contents()
      local c1, c2 = (l1.coal or 0) > 0, (l2.coal or 0) > 0
      local m1, m2 = c1 and has_ore(l1), c2 and has_ore(l2)
      local fn = b.force.name
      per[fn] = per[fn] or { n = 0, both = 0, mixed = 0 }
      per[fn].n = per[fn].n + 1
      local kind
      if c1 and c2 then both = both + 1; per[fn].both = per[fn].both + 1; kind = "2 voies de charbon" end
      if m1 or m2 then mixed = mixed + 1; per[fn].mixed = per[fn].mixed + 1; kind = (kind and (kind .. " + ") or "") .. "voie mixte" end
      if kind then
        local key = b.position.x .. ":" .. b.position.y .. ":" .. kind
        if not fx.seen[key] and fx.logged < 80 then
          fx.seen[key] = true
          fx.logged = fx.logged + 1
          ctx.log(string.format("[FO-FLUX-VOIE] tick %d, %s, tapis (%g,%g) dir %d : %s | voie1 %s | voie2 %s", tick, fn, b.position.x, b.position.y,
            b.direction, kind, show(l1), show(l2)))
        end
      end
    end
  end
  local fns = {}
  for fn in pairs(per) do fns[#fns + 1] = fn end
  table.sort(fns)
  local parts = {}
  for _, fn in ipairs(fns) do parts[#parts + 1] = string.format("%s %d (2 voies de charbon %d, mixtes %d)", fn, per[fn].n, per[fn].both, per[fn].mixed) end
  ctx.log(string.format("[FO-FLUX-VOIE] tick %d : %d tapis de fours, 2 voies de charbon %d, voies mixtes %d | %s", tick, n, both, mixed, table.concat(parts, " ; ")))
  fx.last = { n = n, both = both, mixed = mixed }
end

local tick0, finish0 = base.tick, base.finish
base.description = "FLUX-VOIE-DC : scan des tapis de fours pendant la partie du DC (216 000 ticks)"
base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  if e.tick >= FIRST and e.tick % EVERY == 0 then scan(ctx, e.tick) end
end
base.finish = function(ctx)
  scan(ctx, game.tick)
  if finish0 then finish0(ctx) end
end
return base
