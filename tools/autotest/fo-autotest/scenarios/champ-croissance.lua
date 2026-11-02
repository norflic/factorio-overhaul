--[[
  Lot CHAMP (retour du DC du 2/11, points 1, 2, 3, 12, 13, 14) : la partie de dc-croissance, SANS images, jugée sur
  fo-logs/2026-11-02_CHAMP/CRITERES.md, avec un relevé de ce que le DC voit sur les gisements, toutes les 7,5 min :
    - foreuses de chaque minerai : électriques / à combustion (part électrique) ;
    - gisements exploités (composantes de tuiles de minerai touchées par une foreuse de l'équipe) : tuiles, part couverte par une foreuse
      électrique, part couverte par une foreuse quelconque ;
    - minerai immobile : foreuses électriques bloquées en sortie (statut « place dans la destination »), tapis portant du minerai, dont
      pleins (4 objets par voie) ;
    - fours : en marche, sans entrée, sortie pleine, sans combustible, autres ;
    - plaques de fer et de cuivre produites depuis le relevé précédent (par minute), rapport cuivre / fer.
  Le relevé ne lit que le moteur (aucune interface du mod) : le même scénario sert de témoin sur `main`.
  Lancement : banc.py --graine <N> --qui CHAMP -- 216000 champ-croissance <source>. Journal : [FO-CHAMP-MESURE].
]]
local CHECK = 210000
local EVERY = 27000
local base = require("scenarios/dc_evolution_common")(CHECK)

local ORES = { "iron-ore", "copper-ore", "coal", "stone" }
local PLATES = { "iron-plate", "copper-plate" }
local MIN_TILES = 50 -- gisements plus petits : ignorés
local last = {}      -- [force] = { tick, [plaque] = cumul }

local function key(x, y) return x * 65536 + y end

local function teams()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  return ok and rows or {}
end

local function is_electric(e)
  return e.prototype.electric_energy_source_prototype ~= nil
end

--- Tuiles minées par la foreuse `d` (zone de minage du prototype).
local function mined(d, out)
  local r = d.prototype.mining_drill_radius or 1
  local p = d.position
  for x = math.floor(p.x - r + 0.01), math.ceil(p.x + r - 0.01) - 1 do
    for y = math.floor(p.y - r + 0.01), math.ceil(p.y + r - 0.01) - 1 do out[key(x, y)] = true end
  end
end

--- Gisements de `ore` touchés par les foreuses `drills` : composantes 8-connexes (trous d'une tuile tolérés) des tuiles de minerai.
local function deposits(s, ore, drills)
  local any, elec = {}, {}
  local x0, y0, x1, y1
  for _, d in ipairs(drills) do
    mined(d, any)
    if is_electric(d) then mined(d, elec) end
    local p = d.position
    x0, y0 = math.min(x0 or p.x, p.x), math.min(y0 or p.y, p.y)
    x1, y1 = math.max(x1 or p.x, p.x), math.max(y1 or p.y, p.y)
  end
  if not x0 then return {} end
  local R = 120
  local tiles = {}
  for _, r in ipairs(s.find_entities_filtered({ area = { { x0 - R, y0 - R }, { x1 + R, y1 + R } }, name = ore, type = "resource" })) do
    tiles[key(math.floor(r.position.x), math.floor(r.position.y))] = { math.floor(r.position.x), math.floor(r.position.y) }
  end
  local seen, out = {}, {}
  local seeds = {}
  for _, d in ipairs(drills) do
    local p = d.position
    seeds[#seeds + 1] = { math.floor(p.x), math.floor(p.y) }
  end
  for _, sd in ipairs(seeds) do
    local start
    for dx = -2, 2 do
      for dy = -2, 2 do
        local k = key(sd[1] + dx, sd[2] + dy)
        if not start and tiles[k] and not seen[k] then start = k end
      end
    end
    if start then
      local q, h, n, cov, cove = { start }, 1, 0, 0, 0
      seen[start] = true
      local sx, sy = 0, 0
      while h <= #q do
        local k = q[h]; h = h + 1
        local t = tiles[k]
        n = n + 1
        sx, sy = sx + t[1], sy + t[2]
        if any[k] then cov = cov + 1 end
        if elec[k] then cove = cove + 1 end
        for dx = -2, 2 do
          for dy = -2, 2 do
            local k2 = key(t[1] + dx, t[2] + dy)
            if tiles[k2] and not seen[k2] then seen[k2] = true; q[#q + 1] = k2 end
          end
        end
      end
      if n >= MIN_TILES then
        out[#out + 1] = { x = math.floor(sx / n), y = math.floor(sy / n), n = n, cov = cov, cove = cove }
      end
    end
  end
  return out
end

local function pct(a, b) return b > 0 and math.floor(100 * a / b + 0.5) or 0 end

local ORE_SET = {}
for _, o in ipairs(ORES) do ORE_SET[o] = true end

local function measure(ctx, tick)
  local s = ctx.surface()
  local minute = tick / 3600
  for _, row in ipairs(teams()) do
    local force = row.force
    local by_ore, parts = {}, {}
    local stuck, elec_n = 0, 0
    for _, d in ipairs(s.find_entities_filtered({ type = "mining-drill", force = force })) do
      local t = d.mining_target
      local ore = t and t.valid and t.name or "?"
      by_ore[ore] = by_ore[ore] or { e = 0, b = 0, list = {} }
      local o = by_ore[ore]
      if is_electric(d) then
        o.e = o.e + 1
        elec_n = elec_n + 1
        if d.status == defines.entity_status.waiting_for_space_in_destination then stuck = stuck + 1 end
      else
        o.b = o.b + 1
      end
      o.list[#o.list + 1] = d
    end
    local drills_txt, dep_txt = {}, {}
    for _, ore in ipairs(ORES) do
      local o = by_ore[ore]
      if o then
        drills_txt[#drills_txt + 1] = string.format("%s %d/%d (%d%% elec)", ore, o.e, o.b, pct(o.e, o.e + o.b))
        for _, dp in ipairs(deposits(s, ore, o.list)) do
          dep_txt[#dep_txt + 1] = string.format("%s@%d,%d %d tuiles elec %d%% tout %d%%", ore, dp.x, dp.y, dp.n, pct(dp.cove, dp.n), pct(dp.cov, dp.n))
        end
      end
    end
    local belts, full = 0, 0
    for _, b in ipairs(s.find_entities_filtered({ type = "transport-belt", force = force })) do
      local ore_here, lanes_full = false, 0
      for i = 1, 2 do
        local tl = b.get_transport_line(i)
        local c = tl.get_contents()
        for name in pairs(c) do if ORE_SET[name] then ore_here = true end end
        if tl.get_item_count() >= 4 then lanes_full = lanes_full + 1 end
      end
      if ore_here then
        belts = belts + 1
        if lanes_full == 2 then full = full + 1 end
      end
    end
    local fw, fi, fo, ff, fx = 0, 0, 0, 0, 0
    for _, fu in ipairs(s.find_entities_filtered({ type = "furnace", force = force })) do
      local st = fu.status
      if st == defines.entity_status.working then fw = fw + 1
      elseif st == defines.entity_status.no_ingredients then fi = fi + 1
      elseif st == defines.entity_status.full_output then fo = fo + 1
      elseif st == defines.entity_status.no_fuel then ff = ff + 1
      else fx = fx + 1 end
    end
    local f = game.forces[force]
    local prev = last[force]
    local rates = {}
    if f then
      local now = { tick = tick }
      for _, it in ipairs(PLATES) do now[it] = f.item_production_statistics.get_input_count(it) end
      for _, it in ipairs(PLATES) do
        rates[it] = (prev and tick > prev.tick) and (now[it] - prev[it]) * 3600 / (tick - prev.tick) or nil
      end
      last[force] = now
    end
    local ir, cr = rates["iron-plate"], rates["copper-plate"]
    ctx.log(string.format("[FO-CHAMP-MESURE] minute %.1f | %s | foreuses %s | gisements [%s] | figees %d/%d electriques | tapis minerai %d pleins %d | fours marche %d sans_entree %d sortie_pleine %d sans_combustible %d autre %d | fer %s/min cuivre %s/min rapport %s",
      minute, row.key, #drills_txt > 0 and table.concat(drills_txt, ", ") or "aucune", table.concat(dep_txt, " ; "), stuck, elec_n,
      belts, full, fw, fi, fo, ff, fx, ir and string.format("%.0f", ir) or "-", cr and string.format("%.0f", cr) or "-",
      (ir and cr and ir > 0) and string.format("%.2f", cr / ir) or "-"))
  end
end

local tick1 = base.tick
base.description = "CHAMP : partie de dc-croissance sans images, releve des gisements toutes les 7,5 min"
base.tick = function(ctx, e)
  tick1(ctx, e)
  if e.tick > 0 and e.tick <= CHECK and (e.tick % EVERY == 0 or e.tick == CHECK) then measure(ctx, e.tick) end
end
return base
