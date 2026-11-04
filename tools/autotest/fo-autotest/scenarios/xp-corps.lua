-- Lot EXPERIMENTAUX (3/11), palier 2 : essais E-XP1 et E-XP2 de FAISABILITE, SUR LA COPIE JETABLE SEULEMENT
-- (py -3.9 tools/autotest/xp/jetable.py --dest <neuf> ; sur le mod livré, le scénario se refuse : « prototypes d'essai absents »).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache --ticks 2500" --qui EXPERIMENTAUX -- 2500 xp-corps "<copie>"
-- E-XP1 : un torse de 50 tuiles PORTÉ PAR LE PROTOTYPE (spider-vehicle, graphics_set.animation, 1 direction) ; la position sort de l'écran
--   (au sud de 2, 16 et 31 tuiles, à l'est, à l'ouest, au zoom 0,2) : le torse reste-t-il dessiné ? (images, à regarder) ; le bâtiment
--   sous le torse se clique-t-il ? (joueur de la session, update_selected_entity).
-- E-XP2 : 4 pattes de géant SANS image (part_length 15) et 4 pattes du Bourdon : un trajet de 160 tuiles à travers un lac, un mur, une
--   rangée de machines et des falaises : arrivée, temps, vitesse.
local X1, X2, Y = 12000, 12400, 3000
local DEST = 160
local CHECK = 2450

local PLAN = {}
local function vue(tick, nom, x, y, zoom, res)
  PLAN[#PLAN + 1] = { tick = tick, nom = nom, x = x, y = y, zoom = zoom, res = res or { 1600, 900 } }
end
vue(200, "exp1-reference", X1, Y - 22, 0.5, { 1800, 1800 })
vue(205, "exp1-sud-31", X1, Y - 45, 1)
vue(210, "exp1-sud-16", X1, Y - 30, 1)
vue(215, "exp1-sud-02", X1, Y - 16, 1)
vue(220, "exp1-ouest-17", X1 + 42, Y - 25, 1)
vue(225, "exp1-est-17", X1 - 42, Y - 25, 1)
vue(230, "exp1-nord-haut", X1, Y - 70, 1)
vue(235, "exp1-z02-loin", X1, Y - 90, 0.2)
for k, t in ipairs({ 400, 800, 1200, 1600, 2000 }) do
  vue(t, string.format("exp2-trajet-%d", k), X2 + DEST / 2, Y + 30, 0.25, { 1800, 1200 })
end
-- la session avec images s'arrête à la dernière capture (i1) : une dernière vue APRÈS le contrôle, pour que le BILAN s'écrive
vue(CHECK + 20, "exp2-fin", X2 + DEST / 2, Y + 30, 0.25, { 1800, 1200 })

local function dist(e, x, y)
  local dx, dy = e.position.x - x, e.position.y - y
  return math.sqrt(dx * dx + dy * dy)
end

return {
  description = "EXPERIMENTAUX : E-XP1 (torse porte par le prototype, hors ecran) et E-XP2 (pattes sans image)",
  check_tick = CHECK,
  shots_delay = PLAN[1].tick,

  init = function(ctx)
    local st = ctx.state()
    if not (game.entity_prototypes["fo-xp-essai-torse"] and game.entity_prototypes["fo-xp-essai-geant"]) then
      ctx.fail("prototypes d'essai absents (copie jetable seulement : tools/autotest/xp/jetable.py)")
      return
    end
    game.map_settings.enemy_expansion.enabled = false
    local s = ctx.surface()
    ctx.prepare_area(X1 - 80, Y - 120, X1 + 80, Y + 30, "dry-dirt")
    ctx.prepare_area(X2 - 30, Y - 40, X2 + DEST + 40, Y + 120, "dry-dirt")
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X1 - 200, Y - 200 }, { X2 + 300, Y + 300 } } })) do en.destroy() end
    -- E-XP1 : le torse, un laboratoire SOUS lui (au milieu du corps à l'écran), des repères vanilla à côté
    st.torse = s.create_entity({ name = "fo-xp-essai-torse", position = { X1, Y }, force = "player" })
    st.lab = s.create_entity({ name = "lab", position = { X1 + 0.5, Y - 19.5 }, force = "player" })
    s.create_entity({ name = "rocket-silo", position = { X1 - 40, Y - 4 }, force = "player" })
    s.create_entity({ name = "gun-turret", position = { X1 + 30, Y }, force = "player" })
    ctx.check(st.torse ~= nil, "E-XP1 : le torse se pose", st.torse and st.torse.name or "refuse")
    -- E-XP2 : obstacles sur les deux routes (Y et Y + 80)
    local tiles = {}
    for x = X2 + 40, X2 + 69 do
      for y = Y - 30, Y + 110 do tiles[#tiles + 1] = { name = "water", position = { x, y } } end
    end
    s.set_tiles(tiles)
    for y = Y - 25, Y + 105 do s.create_entity({ name = "stone-wall", position = { X2 + 90.5, y + 0.5 }, force = "player" }) end
    for y = Y - 24, Y + 104, 4 do s.create_entity({ name = "assembling-machine-2", position = { X2 + 110.5, y + 0.5 }, force = "player" }) end
    for k = 0, 8 do
      s.create_entity({ name = "cliff", position = { X2 + 128, Y - 16 + k * 4 }, cliff_orientation = "north-to-south" })
      s.create_entity({ name = "cliff", position = { X2 + 128, Y + 64 + k * 4 }, cliff_orientation = "north-to-south" })
    end
    st.geant = s.create_entity({ name = "fo-xp-essai-geant", position = { X2, Y }, force = "player" })
    st.petit = s.create_entity({ name = "fo-xp-essai-torse", position = { X2, Y + 80 }, force = "player" })
    ctx.check(st.geant ~= nil and st.petit ~= nil, "E-XP2 : les deux araignees se posent")
    st.arrive = {}
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    if not st.geant then return end
    if t == 60 then
      for _, k in ipairs({ "geant", "petit" }) do
        local sp = st[k]
        if sp and sp.valid then
          sp.autopilot_destination = { X2 + DEST, sp.position.y }
          st[k .. "_y"] = sp.position.y
        end
      end
    end
    if t > 60 then
      for _, k in ipairs({ "geant", "petit" }) do
        local sp = st[k]
        if sp and sp.valid and not st.arrive[k] and dist(sp, X2 + DEST, st[k .. "_y"]) < 4 then
          st.arrive[k] = t
          ctx.log(string.format("E-XP2 %s arrive au tick %d : %.3f tuile/tick", k, t, DEST / (t - 60)))
        end
      end
      if t % 300 == 0 then
        for _, k in ipairs({ "geant", "petit" }) do
          local sp = st[k]
          if sp and sp.valid then ctx.log(string.format("E-XP2 %s t%d en (%.1f, %.1f)", k, t, sp.position.x - X2, sp.position.y - Y)) end
        end
      end
    end
    -- E-XP1 : clic sur le bâtiment sous le torse (joueur de la session avec images)
    local p = game.players[1]
    if t == 300 and p then
      p.teleport({ X1, Y + 40 })
      p.update_selected_entity({ X1 + 0.5, Y - 19.5 })
      local sel = p.selected
      ctx.check(sel and sel.name == "lab", "E-XP1 : le batiment sous le torse se clique", sel and sel.name or "rien")
      for _, q in ipairs({ { 0.2, 0.2 }, { 1, -1 }, { -9, -4 }, { -9, -14 }, { -9, -30 }, { 15, -40 } }) do
        p.update_selected_entity({ X1 + q[1], Y + q[2] })
        ctx.log(string.format("E-XP1 selection en (%g, %g) : %s", q[1], q[2], p.selected and p.selected.name or "rien"))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.geant then return end
    for _, k in ipairs({ "geant", "petit" }) do
      local a = st.arrive[k]
      ctx.check(a ~= nil, "E-XP2 " .. k .. " : arrive a travers lac, mur, machines et falaises, sans coincer",
        a and string.format("tick %d, %.3f tuile/tick", a, DEST / (a - 60)) or "pas arrive")
    end
    local legs = ctx.surface().count_entities_filtered({ type = "spider-leg", area = { { X1 - 300, Y - 300 }, { X2 + 400, Y + 300 } } })
    ctx.log(string.format("E-XP2 entites de pattes sur la zone : %d (3 araignees x 4)", legs))
  end,

  shots = function(ctx, add)
    for i, p in ipairs(PLAN) do
      local suivant = PLAN[i + 1]
      add(p.nom, p.x, p.y, p.zoom, 0, { res = p.res, cadence = suivant and math.max(1, suivant.tick - p.tick) or nil, aa = true })
    end
  end,
}
