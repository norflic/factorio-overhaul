--[[
  Lot FLUX-VOIE (retour du DC du 2/11 sur 0.6.34, point 15 : « deux rangées de charbon [...] le fer ne peut pas descendre »).
  Scan des TAPIS en moteur réel : joue la partie d'ia1-build (plaine, 132 000 ticks : fonderies de fer et de cuivre alimentées par
  foreuses et quais de charbon) et, toutes les 3 600 ticks, lit les deux voies de chaque tapis de l'équipe. Journalise :
    - les tapis dont les DEUX voies portent du charbon ;
    - les tapis dont une voie MÊLE charbon et minerai ;
    - pour chacun, les bras et coffres voisins (à 3 tuiles), avec ce qu'ils prennent et où ils déposent.
  Les compteurs sont écrits « [FO-FLUX-VOIE] ... » ; les contrôles du banc d'origine restent joués (BILAN du scénario de base).
  Lancement : banc.py ... -- 132000 flux-voie <source>
]]
local base = require("scenarios/ia1_build_common")("plaine")

local EVERY, FIRST = 3600, 3600
local ORES = { ["iron-ore"] = true, ["copper-ore"] = true, ["stone"] = true }
local AREA = { { -170, -170 }, { 170, 170 } }

local function lanes_of(belt)
  local out = {}
  for i = 1, 2 do
    local ok, c = pcall(function() return belt.get_transport_line(i).get_contents() end)
    out[i] = ok and c or {}
  end
  return out
end

local function show(c)
  local k, parts = {}, {}
  for n in pairs(c) do k[#k + 1] = n end
  table.sort(k)
  for _, n in ipairs(k) do parts[#parts + 1] = n .. "=" .. c[n] end
  return #parts > 0 and table.concat(parts, ",") or "-"
end

local function has_ore(c) for n in pairs(c) do if ORES[n] then return true end end return false end

local function neighbours(s, p)
  local parts = {}
  local list = s.find_entities_filtered({ area = { { p.x - 3, p.y - 3 }, { p.x + 3, p.y + 3 } }, type = { "inserter", "container", "mining-drill" }, force = "player" })
  table.sort(list, function(a, b) if a.position.x ~= b.position.x then return a.position.x < b.position.x end return a.position.y < b.position.y end)
  for _, e in ipairs(list) do
    if e.type == "inserter" then
      local pt = e.pickup_target
      local dt = e.drop_target
      parts[#parts + 1] = string.format("%s(%g,%g) prend %s%s depose %s", e.name, e.position.x, e.position.y,
        pt and pt.name or "?", pt and pt.type == "container" and ("[" .. show(pt.get_inventory(defines.inventory.chest).get_contents()) .. "]") or "",
        dt and dt.name or "sol")
    elseif e.type == "container" then
      parts[#parts + 1] = string.format("coffre(%g,%g)[%s]", e.position.x, e.position.y, show(e.get_inventory(defines.inventory.chest).get_contents()))
    else
      parts[#parts + 1] = string.format("foreuse(%g,%g)", e.position.x, e.position.y)
    end
  end
  return table.concat(parts, " ; ")
end

local function scan(ctx, tick)
  local s = ctx.surface()
  local st = ctx.state()
  st.flux = st.flux or { seen = {}, logged = 0 }
  local fx = st.flux
  local n, both, mixed, coal_lane, ore_lane, headmix = 0, 0, 0, 0, 0, 0
  fx.feed, fx.feed2, fx.c1, fx.c2, fx.o1, fx.o2 = 0, 0, 0, 0, 0, 0
  local list = s.find_entities_filtered({ area = AREA, type = "transport-belt", force = "player" })
  table.sort(list, function(a, b) if a.position.x ~= b.position.x then return a.position.x < b.position.x end return a.position.y < b.position.y end)
  for _, b in ipairs(list) do
    n = n + 1
    local l = lanes_of(b)
    local c1, c2 = (l[1].coal or 0) > 0, (l[2].coal or 0) > 0
    local m1, m2 = c1 and has_ore(l[1]), c2 and has_ore(l[2])
    if c1 or c2 then coal_lane = coal_lane + 1 end
    if has_ore(l[1]) or has_ore(l[2]) then ore_lane = ore_lane + 1 end
    local kind
    if m1 or m2 then mixed = mixed + 1; kind = "voie MIXTE charbon/minerai" end
    if c1 and c2 then both = both + 1 end
    if (c1 or c2) and (has_ore(l[1]) or has_ore(l[2])) then headmix = headmix + 1 end
    -- tapis d'alimentation d'un four : un bras voisin qui depose dans un four et prend sur ce tapis
    local feeds = false
    for _, i in ipairs(s.find_entities_filtered({ area = { { b.position.x - 1.6, b.position.y - 1.6 }, { b.position.x + 1.6, b.position.y + 1.6 } }, type = "inserter", force = "player" })) do
      local dt = i.drop_target
      if dt and dt.type == "furnace" then feeds = true break end
    end
    if feeds then
      fx.feed = (fx.feed or 0) + 1
      for v = 1, 2 do
        if (l[v].coal or 0) > 0 then fx["c" .. v] = (fx["c" .. v] or 0) + 1 end
        if has_ore(l[v]) then fx["o" .. v] = (fx["o" .. v] or 0) + 1 end
      end
      if c1 and c2 then fx.feed2 = (fx.feed2 or 0) + 1; kind = (kind and (kind .. " + ") or "") .. "2 voies de charbon sur un tapis de fonderie" end
    end
    if kind then
      local key = b.position.x .. ":" .. b.position.y .. ":" .. kind
      if not fx.seen[key] and fx.logged < 60 then
        fx.seen[key] = true
        fx.logged = fx.logged + 1
        ctx.log(string.format("[FO-FLUX-VOIE] tick %d, tapis (%g,%g) dir %d : %s | voie1 %s | voie2 %s | voisins : %s", tick, b.position.x, b.position.y,
          b.direction, kind, show(l[1]), show(l[2]), neighbours(s, b.position)))
      end
    end
  end
  ctx.log(string.format("[FO-FLUX-VOIE] tick %d : %d tapis, charbon sur >= 1 voie %d, minerai %d, charbon ET minerai sur le meme tapis %d, charbon sur les 2 voies %d, voie MIXTE %d | tapis de fonderie %d : voie1 charbon %d minerai %d, voie2 charbon %d minerai %d, 2 voies de charbon %d",
    tick, n, coal_lane, ore_lane, headmix, both, mixed, fx.feed, fx.c1, fx.o1, fx.c2, fx.o2, fx.feed2))
  fx.last = { n = n, both = both, mixed = mixed }
end

local tick0, finish0 = base.tick, base.finish
base.description = "FLUX-VOIE : scan des tapis (charbon sur les 2 voies) pendant la partie d'ia1-build-plaine"
base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  local t = game.tick
  if t >= FIRST and t % EVERY == 0 then scan(ctx, t) end
end
base.finish = function(ctx)
  scan(ctx, game.tick)
  local fx = ctx.state().flux
  ctx.check(fx ~= nil, "scan des tapis fait")
  ctx.log(string.format("[FO-FLUX-VOIE] FIN : tapis a 2 voies de charbon %d, voies mixtes %d (dernier scan)", fx and fx.last.both or -1, fx and fx.last.mixed or -1))
  if finish0 then finish0(ctx) end
end
return base
