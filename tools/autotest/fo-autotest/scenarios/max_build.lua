--[[
  Lot CARTE-MAX : fabrique les scénarios etape1-max (partie de 120 min, captures) et etape1-max-court (micro-banc de 3 000 ticks).
  La partie est celle de etape1-guide (mêmes réglages, mêmes relevés [FO-ETAPE1-GUIDE] et [FO-FONCTION], code RÉUTILISÉ) sur une
  carte aux gisements au maximum (scenarios/max_common.lua).

  Captures (session avec images seulement ; opts.photo_ticks), POUR CHAQUE ÉQUIPE (votre équipe, puis chaque faction) :
    carte-max-<équipe>-m<minute>-vue.png   : vue d'ensemble autour du QG (2 400 x 1 350 px, zoom 0,25 : 300 x 169 tuiles) ;
    carte-max-<équipe>-m<minute>-champ.png : le plus grand champ de foreuses de l'équipe (1 600 x 900 px, zoom 0,35 : 143 x 80
                                             tuiles), cherché dans une fenêtre de 3 x 3 cases de 24 tuiles.
  Une ligne [FO-CARTE-MAX] « champ » dit à chaque fois où, et combien de foreuses (en jeu, sans images aussi).
]]

local C = require("scenarios/max_common")

local floor = math.floor
local CELL = 24

local function ckey(cx, cy) return (cx + 5000) * 10000 + (cy + 5000) end

--- Plus grand champ de foreuses d'une force : fenêtre 3 x 3 cases de CELL tuiles qui en contient le plus. Rend
--- { n, x, y, total } (centre de gravité des foreuses de la fenêtre) ou nil sans foreuse.
local function best_field(s, force)
  local drills = s.find_entities_filtered({ force = force, type = "mining-drill" })
  if #drills == 0 then return nil end
  local cnt, sx, sy, keys = {}, {}, {}, {}
  for _, d in ipairs(drills) do
    local cx, cy = floor(d.position.x / CELL), floor(d.position.y / CELL)
    local k = ckey(cx, cy)
    if not cnt[k] then cnt[k], sx[k], sy[k] = 0, 0, 0; keys[#keys + 1] = k end
    cnt[k], sx[k], sy[k] = cnt[k] + 1, sx[k] + d.position.x, sy[k] + d.position.y
  end
  table.sort(keys)
  local best
  for _, k in ipairs(keys) do
    local cx, cy = floor(k / 10000) - 5000, k % 10000 - 5000
    local n, x, y = 0, 0, 0
    for dx = -1, 1 do
      for dy = -1, 1 do
        local kk = ckey(cx + dx, cy + dy)
        if cnt[kk] then n, x, y = n + cnt[kk], x + sx[kk], y + sy[kk] end
      end
    end
    if not best or n > best.n then best = { n = n, x = x / n, y = y / n, total = #drills } end
  end
  return best
end

local function snap(s, name, x, y, zoom, res)
  local player = game.connected_players[1]
  if not player then return end
  game.take_screenshot({ player = player, surface = s, position = { x, y }, resolution = res, zoom = zoom,
    path = "fo-shots/carte-max-" .. name .. ".png", show_entity_info = true, anti_alias = true, daytime = 0,
    allow_in_replay = true, force_render = true })
  log(C.TAG .. string.format("capture carte-max-%s (%.1f, %.1f) zoom %.2f", name, x, y, zoom))
end

local function force_of(s, key)
  if key == "equipe" then return "player" end
  return "fo-" .. key
end

--- opts : description, check_tick, releve_at, photo_ticks (liste de ticks), fmin, shots (vrai : captures de fin du guide),
--- shots_delay.
return function(opts)
  local guide = require("scenarios/etape1-guide")
  local base = {}
  for k, v in pairs(guide) do base[k] = v end
  local tick0, init0 = guide.tick, guide.init
  local photos = {}
  for _, t in ipairs(opts.photo_ticks or {}) do photos[t] = true end

  base.description = opts.description
  base.check_tick = opts.check_tick

  base.init = function(ctx)
    C.apply(ctx, ctx.state())
    if init0 then init0(ctx) end
  end

  base.tick = function(ctx, e)
    if tick0 then tick0(ctx, e) end
    local st = ctx.state()
    if e.tick >= opts.releve_at and e.tick % 300 == 0 and e.tick < opts.releve_at + 2400 and not st.releve_done then
      st.releve_done = C.releve(ctx, st) or false
      if not st.releve_done then ctx.log(C.TAG .. "releve : aucun QG au tick " .. e.tick) end
    end
    if photos[e.tick] then
      local s = ctx.surface()
      local minute = floor(e.tick / 3600)
      for _, p in ipairs(C.sites(s)) do
        local f = best_field(s, force_of(s, p.key))
        if f then
          log(C.TAG .. string.format("champ minute %d | %s | %d foreuses autour de (%.0f, %.0f) sur %d au total", minute, p.key,
            f.n, f.x, f.y, f.total))
        else
          log(C.TAG .. string.format("champ minute %d | %s | aucune foreuse", minute, p.key))
        end
        if #game.connected_players > 0 then
          snap(s, string.format("%s-m%03d-vue", p.key, minute), p.x, p.y, 0.25, { 2400, 1350 })
          if f then snap(s, string.format("%s-m%03d-champ", p.key, minute), f.x, f.y, 0.35, { 1600, 900 }) end
        end
      end
    end
  end

  base.finish = function(ctx) C.checks(ctx, ctx.state(), opts.fmin or 3) end

  if opts.shots then
    base.shots_delay = opts.shots_delay
  else
    base.shots, base.shots_delay = nil, nil
  end
  return base
end
