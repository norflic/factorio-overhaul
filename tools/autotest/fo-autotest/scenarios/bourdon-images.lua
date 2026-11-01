-- Lot BOURDON (1er/11) : le Bourdon sur de vraies bases, DANS LE TEMPS : Le Glas en 9 instants à 3 zooms et de nuit, la descente, le vol, les ancres, et l'essai E-XP1
-- (position hors de l'écran : la cloche reste-t-elle affichée ? le bâtiment dessous reste-t-il cliquable ?).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache --ticks 3600" --qui BOURDON -- 3600 bourdon-images <source>
local C = require("scenarios/bourdon_commun")

local Y = 3000
local SITES = { A = 4000, B = 4400, Z = 4800, N = 5200, E = 5600 }
local FRAPPE = { A = 620, B = 1000, Z = 1400, N = 1800 }
local INSTANTS = { -60, -12, 3, 16, 30, 48, 72, 100, 240, 420 }
local ALLER = 2500

local PLAN = {}
local function vue(tick, nom, x, y, zoom, res, nuit)
  PLAN[#PLAN + 1] = { tick = tick, nom = nom, x = x, y = y, zoom = zoom, res = res, nuit = nuit }
end

-- 3 zooms : tout le rayon et plus, le zoom 1 du jeu, très dézoomé
for _, d in ipairs(INSTANTS) do
  vue(FRAPPE.A + d, string.format("glas-z05-t%+04d", d), SITES.A, Y - 16, 0.5, { 2400, 1800 })
  vue(FRAPPE.B + d, string.format("glas-z1-t%+04d", d), SITES.B, Y - 12, 1, { 2400, 1700 })
  vue(FRAPPE.Z + d, string.format("glas-z02-t%+04d", d), SITES.Z, Y - 8, 0.2, { 1600, 1000 })
end
for _, d in ipairs({ -12, 3, 30, 72, 240 }) do
  vue(FRAPPE.N + d, string.format("glas-nuit-t%+04d", d), SITES.N, Y - 16, 0.5, { 2400, 1800 }, true)
end
-- la descente
for _, t in ipairs({ 40, 140, 240, 296, 320, 345, 372 }) do
  vue(t, string.format("descente-t%03d", t), SITES.E, Y - 24, 0.4, { 1800, 1500 })
end
-- E-XP1 : la position sort de l'écran (vues de 1600 × 900 à zoom 1 : 50 × 28 tuiles)
vue(2300, "cull-reference", SITES.E, Y - 22, 0.5, { 1800, 1800 })
vue(2305, "cull-sud-31", SITES.E, Y - 45, 1, { 1600, 900 })
vue(2310, "cull-sud-16", SITES.E, Y - 30, 1, { 1600, 900 })
vue(2315, "cull-sud-02", SITES.E, Y - 16, 1, { 1600, 900 })
vue(2320, "cull-ouest-17", SITES.E + 42, Y - 25, 1, { 1600, 900 })
vue(2325, "cull-est-17", SITES.E - 42, Y - 25, 1, { 1600, 900 })
vue(2330, "cull-ombre-seule", SITES.E + 62, Y - 5, 1, { 1600, 900 })
vue(2335, "cull-ancre-avant", SITES.E, Y + 24, 1, { 1600, 900 })
vue(2340, "cull-z02-loin", SITES.E, Y - 90, 0.2, { 1600, 900 })
-- le vol : les ancres remontent, la cloche part, retombent à l'arrivée
for _, t in ipairs({ 2520, 2560, 2600, 2700, 2800 }) do
  vue(t, string.format("vol-t%04d", t), SITES.E + (t >= 2700 and 30 or 0), Y - 18, 0.6, { 2000, 1600 })
end
for k = 0, 15 do
  vue(2860 + k * 15, string.format("pose-t%04d", 2860 + k * 15), SITES.E + 60, Y - 14, 0.6, { 2000, 1600 })
end
table.sort(PLAN, function(a, b) return a.tick < b.tick end)

return {
  description = "BOURDON : Glas dans le temps, 3 zooms et nuit, vol, descente, E-XP1",
  check_tick = 3400,
  shots_delay = PLAN[1].tick,

  init = function(ctx)
    local st = ctx.state()
    C.forces()
    st.ids = {}
    local noms = { "A", "B", "Z", "N", "E" }
    for _, k in ipairs(noms) do
      C.site(ctx, SITES[k], Y, 88)
    end
    local s = ctx.surface()
    -- un peu de vos bâtiments, sur la route de l'onde : ils restent debout
    for dx = -30, 30, 15 do
      s.create_entity({ name = "lab", position = { SITES.A + dx + 0.5, Y + 34.5 }, force = "player" })
    end
    for _, k in ipairs(noms) do
      st.ids[k] = remote.call("fo-bourdon", "descendre", "player", SITES[k], Y)
    end
    -- un labo sous la cloche : le clic doit le prendre, pas elle
    for _, t in ipairs(s.find_entities_filtered({ area = { { SITES.E - 4, Y - 24 }, { SITES.E + 4, Y - 16 } } })) do t.destroy() end
    st.labo = s.create_entity({ name = "lab", position = { SITES.E + 0.5, Y - 19.5 }, force = "player" })
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    if t == 400 then
      for _, k in ipairs({ "A", "B", "Z", "N", "E" }) do remote.call("fo-bourdon", "muet", st.ids[k], true) end
    end
    for _, k in ipairs({ "A", "B", "Z", "N" }) do
      if t == FRAPPE[k] - 70 then
        remote.call("fo-bourdon", "recharge_zero", st.ids[k])
        ctx.check(remote.call("fo-bourdon", "glas", st.ids[k], SITES[k] + 30, Y - 10) == true, "Glas " .. k)
      end
    end
    if t == 2290 then
      local p = game.players[1]
      if p then
        p.teleport({ SITES.E, Y + 50 })
        p.update_selected_entity({ SITES.E + 0.5, Y - 19.5 })
        local sel = p.selected
        ctx.check(sel and sel.name == "lab", "le clic prend le batiment sous la cloche", sel and sel.name or "rien")
        for _, q in ipairs({ { 0.2, 0.2 }, { 1, -1 }, { -9, -4 }, { -9, -14 }, { -9, -30 } }) do
          p.update_selected_entity({ SITES.E + q[1], Y + q[2] })
          sel = p.selected
          ctx.log(string.format("selection en (%g, %g) : %s", q[1], q[2], sel and sel.name or "rien"))
        end
      else
        ctx.log("pas de joueur : selection non jouee")
      end
    end
    if t == ALLER then remote.call("fo-bourdon", "aller", st.ids.E, SITES.E + 60, Y) end
  end,

  finish = function(ctx)
    local st = ctx.state()
    for _, k in ipairs({ "A", "B", "Z", "N", "E" }) do
      local b = remote.call("fo-bourdon", "etat", st.ids[k])
      ctx.log(string.format("site %s : phase %s, compte %d, %d touches, %d tues, %d ancres", k, b.phase, b.compte, b.touches, b.tues, b.ancres))
    end
  end,

  shots = function(ctx, add)
    for i, p in ipairs(PLAN) do
      local suivant = PLAN[i + 1]
      add(p.nom, p.x, p.y, p.zoom, p.nuit and 0.5 or 0, { res = p.res, cadence = suivant and math.max(1, suivant.tick - p.tick) or nil, aa = true })
    end
  end,
}
