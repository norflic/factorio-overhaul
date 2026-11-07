-- Lot EXPERIMENTAUX-PUISSANCE (7/11), DIAGNOSTIC : quelle recherche fait générer la carte (11 à 25 ms aux ticks 11 et 31 d'xp-zone depuis
-- la recherche par secteurs, absent de la 0.6.56) ? 500 ticks, sur la géométrie du second site d'xp-zone (zone de 90 tuiles autour de
-- (12050, 4600), terrain préparé sur 70 + 10 tuiles seulement) :
--   tick 100 : recherche par RAYON (comme la 0.6.56) ;   tick 300 : recherche par CARRÉS de 32 tuiles (comme les secteurs).
-- Lire mapGenerator dans benchmark-stdout (pics_zone.py) : une génération après le tick 300 seulement accuse la recherche par carrés.
local X, Y = 12000, 4600
local CX = X + 50
local R = 70
local ZONE = 90

return {
  description = "EXPERIMENTAUX-PUISSANCE : diagnostic de la generation de carte (rayon au tick 100, carres au tick 300)",
  check_tick = 480,

  init = function(ctx)
    ctx.prepare_area(X - 20, Y - R - 10, CX + R + 10, Y + R + 10, "dry-dirt")
  end,

  tick = function(ctx, e)
    local s = ctx.surface()
    local st = ctx.state()
    if e.tick == 99 or e.tick == 299 or e.tick == 499 then
      -- chunks du carré englobant de la zone que le moteur dit générés (is_chunk_generated), avant chaque recherche et à la fin
      local n, g = 0, 0
      for cx = math.floor((CX - ZONE) / 32), math.floor((CX + ZONE) / 32) do
        for cy = math.floor((Y - ZONE) / 32), math.floor((Y + ZONE) / 32) do
          n = n + 1
          if s.is_chunk_generated({ x = cx, y = cy }) then g = g + 1 end
        end
      end
      st["gen" .. e.tick] = g
      ctx.log(string.format("tick %d : %d chunks generes sur %d", e.tick, g, n))
    end
    if e.tick == 100 then
      st.n_rayon = #s.find_entities_filtered({ position = { CX, Y }, radius = ZONE, force = "enemy" })
      ctx.log("tick 100 : recherche par rayon, " .. st.n_rayon)
    elseif e.tick == 300 then
      local n, k = 0, 0
      for x0 = CX - ZONE, CX + ZONE - 1, 32 do
        for y0 = Y - ZONE, Y + ZONE - 1, 32 do
          n = n + #s.find_entities_filtered({ area = { { x0, y0 }, { x0 + 32, y0 + 32 } }, force = "enemy" })
          k = k + 1
        end
      end
      st.n_carres = n
      ctx.log(string.format("tick 300 : recherche par %d carres, %d", k, n))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.n_rayon ~= nil and st.n_carres ~= nil, "les deux recherches ont tourne", string.format("%s / %s", tostring(st.n_rayon), tostring(st.n_carres)))
    ctx.log(string.format("chunks generes : %s avant le rayon, %s apres le rayon, %s apres les carres", tostring(st.gen99), tostring(st.gen299),
      tostring(st.gen499)))
  end,
}
