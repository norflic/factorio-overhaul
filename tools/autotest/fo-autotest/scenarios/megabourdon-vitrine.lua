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
