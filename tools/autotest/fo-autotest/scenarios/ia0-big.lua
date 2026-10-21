--[[
  Lot IA0, critère C4-5 (budget A1) dans le PIRE cas du repérage : une grosse base du joueur répartie sur
  31 secteurs de 64 × 64 tuiles autour du départ, environ 5 000 entités du joueur (convoyeurs, bras,
  poteaux, murs) et seulement 2 installations par secteur : le comptage (count_entities_filtered, limite 64)
  n'a jamais de sortie anticipée et examine toutes les entités du secteur.
  Lancement ÉPINGLÉ (F30) : « 144000 ia0-big » (40 min, Normal). Lecture :
    - portées du profileur « pvp:scan » et « faction:attack » dans les rapports par minute
      ([FO-AUTOTEST] ===== minute N ..., lignes « pvp:scan | total ... | moyenne/tick ... ») ;
    - python tools/autotest/analyze.py "<racine>\fo-autotest" --spikes : moyenne et p99 du temps script.
  Attendu : pvp:scan < 0,02 ms/tick en moyenne (estimation non mesurée : 0,01 à 0,02 ms) et A1 tenu
  (≤ 1,5 ms/tick en moyenne, p99 ≤ 2 ms). Journal : [FO-IA0-BIG].
]]
local C = require("scenarios/ia0_common")

local SECTOR = 64

local function fill_sector(s, x0, y0)
  local n = 0
  local function put(name, x, y)
    if s.create_entity({ name = name, position = { x0 + x + 0.5, y0 + y + 0.5 }, force = "player" }) then n = n + 1 end
  end
  for _, row in ipairs({ 6, 12, 18, 24 }) do
    for i = 4, 33 do put("transport-belt", i, row) end   -- 120 convoyeurs
  end
  for i = 4, 42, 2 do put("inserter", i, 32) end          -- 20 bras
  for i = 4, 58, 6 do put("small-electric-pole", i, 40) end -- 10 poteaux
  for i = 4, 13 do put("stone-wall", i, 48) end            -- 10 murs
  -- 2 installations seulement (le secteur est une cible : sector_min = 2)
  if s.create_entity({ name = "assembling-machine-1", position = { x0 + 52.5, y0 + 8.5 }, force = "player" }) then n = n + 1 end
  if s.create_entity({ name = "assembling-machine-1", position = { x0 + 52.5, y0 + 20.5 }, force = "player" }) then n = n + 1 end
  return n
end

return {
  description = "IA0 : cout du reperage PvP sur une grosse base dense (31 secteurs, ~5 000 entites, 40 min)",
  base = nil,
  check_tick = 143000,

  init = function(ctx)
    local s = ctx.surface()
    local c = game.forces.player.get_spawn_position(s)
    local hx, hy = math.floor(c.x / SECTOR), math.floor(c.y / SECTOR)
    local total, sectors = 0, 0
    for sy = hy - 2, hy + 1 do
      for sx = hx - 4, hx + 3 do
        if not (sx == hx and sy == hy) then
          local x0, y0 = sx * SECTOR, sy * SECTOR
          ctx.prepare_area(x0, y0, x0 + SECTOR - 1, y0 + SECTOR - 1, "grass-1")
          total = total + fill_sector(s, x0, y0)
          sectors = sectors + 1
        end
      end
    end
    local st = ctx.state()
    st.entities, st.sectors = total, sectors
    ctx.check(total >= 4500, "grosse base posee", string.format("%d entites du joueur sur %d secteurs", total, sectors))
    C.start_war(ctx, "normal")
  end,

  tick = function(ctx, e) C.poll(ctx, e, 3600) end, -- relevé par minute seulement : temps script mesuré

  finish = function(ctx)
    local st = ctx.state()
    C.check_level(ctx, "normal")
    local s = ctx.remote("fo-pvp", "status")
    ctx.check(s.score >= 25, "secteurs de la grosse base reperes comme cibles", s.score .. " / " .. tostring(st.sectors))
    ctx.check(s.sweeps >= 5, "balayages complets du disque (4 min chacun)", s.sweeps)
    ctx.log("lire pvp:scan et faction:attack dans le dernier rapport du profileur, puis analyze.py --spikes")
  end,
}
