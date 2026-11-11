-- Lot MEGA-BOURDON (11/11) : le Méga-Bourdon en jeu, à côté du Bourdon : descente, casemates qui tirent sur une base ennemie (orbes, impacts,
-- lueurs, de jour et de nuit), vol (ancres levées) et nouvelle pose. Le Glas automatique est coupé (muet) pour juger les casemates seules.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache --ticks 2700" --qui MEGA -- 2700 megabourdon-vitrine <source>
local C = require("scenarios/bourdon_commun")

local Y = 3000
-- lot ART-MEGA2 : le Méga-Bourdon est 2,2 fois plus grand (B.MEGA.ECHELLE, échelle de ses feuilles) : le Bourdon s'écarte au-delà de ses
-- ancres (67 tuiles), les vues du Méga-Bourdon reculent et montent d'autant.
local K = 2.2
local XM, XB = 4000, 4120 -- Méga-Bourdon, Bourdon (côte à côte)
local ALLER = 1500         -- le Méga-Bourdon part vers l'est
local XM2 = XM + 45
-- Lot MEGA-BALISTIQUE : un ESSAIM COMPACT (3 x 3, à 2 tuiles d'écart) de la plus forte unité d'essaim (la plus grande santé parmi les
-- unités des nids, titans exclus, lue dans les prototypes), posé à ESSAIM_D tuiles au sud de la cloche au tick ESSAIM : un seul tir
-- doit le nettoyer (les 9 meurent au même tick).
local ESSAIM, ESSAIM_D = 1000, 16

local PLAN = {}
local function vue(tick, nom, x, y, zoom, res, nuit)
  PLAN[#PLAN + 1] = { tick = tick, nom = nom, x = x, y = y, zoom = zoom, res = res, nuit = nuit }
end
for _, t in ipairs({ 150, 300 }) do vue(t, string.format("descente-t%04d", t), XM, Y - 24 * K, 0.35 / K, { 1600, 1400 }) end
vue(430, "pose", XM, Y - 20 * K, 0.4 / K, { 1600, 1500 })
for k = 0, 7 do vue(470 + k * 30, string.format("casemates-t%04d", 470 + k * 30), XM, Y - 40, 0.3, { 1600, 1400 }) end
vue(760, "casemates-nuit", XM, Y - 40, 0.3, { 1600, 1400 }, true)
vue(800, "detail-casemate", XM - 16, Y - 60, 0.8, { 1600, 1000 })
vue(860, "cote-a-cote", (XM + XB) / 2, Y - 50, 0.19, { 1600, 1000 })
for _, t in ipairs({ 1540, 1640, 1800, 2000 }) do vue(t, string.format("vol-t%04d", t), XM + 22, Y - 18 * K, 0.35 / K, { 1600, 1300 }) end
vue(2600, "repose", XM2, Y - 18 * K, 0.4 / K, { 1600, 1400 })
table.sort(PLAN, function(a, b) return a.tick < b.tick end)

return {
  description = "MEGA-BOURDON : descente, casemates qui tirent, côte à côte avec le Bourdon, vol, repose",
  check_tick = 2650,
  shots_delay = PLAN[1].tick,

  init = function(ctx)
    local st = ctx.state()
    C.forces()
    C.site(ctx, XM, Y, 88)
    -- le Bourdon de comparaison : terrain nu, sans base ennemie autour (il est muet)
    ctx.prepare_area(XB - 30, Y - 50, XB + 30, Y + 30, "dry-dirt")
    st.mega = remote.call("fo-bourdon", "descendre", "player", XM, Y, 1, "mega")
    st.bourdon = remote.call("fo-bourdon", "descendre", "player", XB, Y, 1)
    ctx.check(st.mega ~= nil, "le Méga-Bourdon descend")
    ctx.check(st.bourdon ~= nil, "le Bourdon descend")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    if t == 2 then
      remote.call("fo-bourdon", "muet", st.mega, true)
      remote.call("fo-bourdon", "muet", st.bourdon, true)
    end
    if t == ESSAIM then
      local nom, pv = nil, -1
      for _, sp in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "unit-spawner" } })) do
        for _, ru in ipairs(sp.result_units or {}) do
          local u = game.entity_prototypes[ru.unit]
          if u and ru.unit:sub(1, 9) ~= "fo-titan-" and (u.max_health or 0) > pv then nom, pv = ru.unit, u.max_health end
        end
      end
      local s = ctx.surface()
      local ess = { nom = nom, pv = pv, ids = {}, t = t, tirs = (remote.call("fo-bourdon", "etat", st.mega) or {}).tirs or 0 }
      for i = -1, 1 do
        for j = -1, 1 do
          local u = nom and s.create_entity({ name = nom, position = { XM + 2 * i, Y + ESSAIM_D + 2 * j }, force = "enemy" })
          if u then ess.ids[#ess.ids + 1] = u end
        end
      end
      st.essaim = ess
    end
    local ess = st.essaim
    if ess and not ess.fin then
      local vivants = 0
      for _, u in ipairs(ess.ids) do if u.valid then vivants = vivants + 1 end end
      if vivants < #ess.ids and not ess.premier then ess.premier = t end
      if vivants == 0 then
        ess.fin = t
        ess.tirs_fin = (remote.call("fo-bourdon", "etat", st.mega) or {}).tirs or 0
      end
    end
    if t == 1400 then st.tirs_avant = (remote.call("fo-bourdon", "etat", st.mega) or {}).tirs or 0 end
    if t == ALLER then ctx.check(remote.call("fo-bourdon", "aller", st.mega, XM2, Y) == true, "ordre de vol") end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local m = remote.call("fo-bourdon", "etat", st.mega)
    local b = remote.call("fo-bourdon", "etat", st.bourdon)
    ctx.check(m ~= nil and m.variante == "mega", "variante du Méga-Bourdon", m and m.variante or "absent")
    ctx.check(b ~= nil and b.variante == "bourdon", "variante du Bourdon", b and b.variante or "absent")
    ctx.check(m ~= nil and (st.tirs_avant or 0) > 0, "les casemates ont tiré avant le vol", tostring(st.tirs_avant))
    ctx.check(m ~= nil and m.glas == false, "le Glas est resté muet")
    ctx.check(m ~= nil and math.abs(m.x - XM2) < 3, "le Méga-Bourdon est arrivé", m and string.format("%.1f", m.x) or "absent")
    local ess = st.essaim or {}
    ctx.check(ess.ids and #ess.ids == 9, "essaim compact posé (9 unités)", ess.ids and tostring(#ess.ids) or "absent")
    ctx.check(ess.fin ~= nil, "l'essaim compact est détruit", ess.fin and tostring(ess.fin - ess.t) or "survivants")
    ctx.check(ess.fin ~= nil and ess.premier == ess.fin, "un seul tir nettoie l'essaim (les 9 meurent au même tick)",
      tostring(ess.premier) .. " / " .. tostring(ess.fin))
    ctx.log(string.format("[FO-MEGA-VITRINE] essaim : %d x %s (%s PV), premier mort a +%s ticks, dernier a +%s ticks, tirs partis entre la pose et la fin : %s",
      ess.ids and #ess.ids or 0, tostring(ess.nom), tostring(ess.pv), tostring(ess.premier and ess.premier - ess.t), tostring(ess.fin and ess.fin - ess.t),
      tostring(ess.tirs_fin and ess.tirs_fin - ess.tirs)))
    local s = ctx.surface()
    local restes = #s.find_entities_filtered({ force = C.CIBLE, area = { { XM - 36, Y - 36 }, { XM + 36, Y + 36 } } })
    ctx.log(string.format("[FO-MEGA-VITRINE] tirs %d (avant le vol %d), sante %.0f, phase %s, ancres %d ; Bourdon : phase %s ; batiments ennemis restants a 36 tuiles : %d",
      m and m.tirs or -1, st.tirs_avant or -1, m and m.sante or -1, m and m.phase or "?", m and m.ancres or -1, b and b.phase or "?", restes))
  end,

  shots = function(ctx, add)
    for i, p in ipairs(PLAN) do
      local suivant = PLAN[i + 1]
      add(p.nom, p.x, p.y, p.zoom, p.nuit and 0.5 or 0, { res = p.res, cadence = suivant and math.max(1, suivant.tick - p.tick) or nil, aa = true })
    end
  end,
}
