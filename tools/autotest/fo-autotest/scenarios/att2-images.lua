-- Lot DESIGN-ATTAQUES (5/11, nuit) : les 5 GRANDES ATTAQUES des géants, en images, sur de vraies bases ennemies ALIMENTÉES (machines, tapis,
-- poteaux moyens reliés en cuivre, lampes, une source d'énergie) ; un bâtiment de la force du géant DANS chaque zone (il doit rester debout,
-- sans falaise ni lave dessous). Le repère : le Glas du Bourdon sur la même base, au même zoom (site 7). Jour jusqu'au tick 3 000, puis
-- nuit : une 2e Surtension (la base s'éteint), le lac de lave et la spirale de nuit.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache --ticks 4500" --qui DESIGN-ATTAQUES -- 4500 att2-images <source>
local C = require("scenarios/att2_commun")
local Y = 3000
local SITES = {
  { id = "cairn", x = 6000, lance = 300 },
  { id = "stylet", x = 6400, lance = 620 },
  { id = "trombe", x = 6800, lance = 950 },
  { id = "ixion", x = 7300, lance = 1700 },
  { id = "tournesol", x = 7900, lance = 2050 },
  { id = "cairn", x = 8500, lance = 3150, nuit = true },
  { id = "bourdon", x = 9100, lance = 2700 },
}
local NUIT = 3000
-- Le marqueur de fin de shots.lua tombe à la dernière capture (4 330) + 10 + 1 + 60 (FLUSH) = 4 401 : il faut AU MOINS 4 402 ticks de budget
-- (passage du 7/11 à 4 400 : code 7, « session fermée avant la fin sans marqueur », 92 captures et BILAN quand même). Jouer à 4 500.
local CONTROLE = 4320

local PLAN = {}
local function vue(tick, nom, x, y, zoom, nuit, res)
  PLAN[#PLAN + 1] = { tick = tick, nom = nom, x = x, y = y, zoom = zoom, nuit = nuit, res = res or { 1600, 1100 } }
end
local CHARGE = C.CHARGE
local INSTANTS = {
  cairn = { -45, 3, 10, 20, 30, 40, 46, 50, 54, 70, 120, 200 },
  stylet = { -40, 2, 30, 60, 90, 118, 140, 240 },
  trombe = { -50, 20, 100, 200, 300, 400, 500, 600, 660 },
  ixion = { -60, 10, 30, 41, 50, 65, 85, 110, 200, 400 },
  tournesol = { -140, -70, -5, 30, 120, 240, 360, 480, 600, 655, 662, 680, 760 },
  bourdon = { -30, 3, 16, 30, 48, 72, 100, 240 },
}
for k, s in ipairs(SITES) do
  local R = C.rayon_base(s.id)
  local z = 1600 / (32 * (2 * R + 36))
  local frappe = s.lance + CHARGE[s.id]
  local tag = s.nuit and (s.id .. "-nuit") or s.id
  -- « avant » (demande du 7/11, 19 h 55) : la base intacte et en marche, juste avant que le géant n'arrive (il est posé au lancement)
  vue(s.lance - 20, string.format("%d-%s-avant", k, tag), s.x, Y - 6, z, s.nuit)
  for _, d in ipairs(INSTANTS[s.id]) do
    vue(frappe + d, string.format("%d-%s-t%+04d", k, tag, d), s.x, Y - 6, z, s.nuit)
  end
  if not s.nuit and s.id ~= "bourdon" then
    vue(frappe + 50, string.format("%d-%s-z1-t+050", k, tag), s.x - 6, Y - 4, 0.9, false, { 1600, 1000 })
    vue(frappe + 52, string.format("%d-%s-dezoom-t+052", k, tag), s.x - 20, Y - 10, 0.12, false, { 1600, 1000 })
  end
end
-- séquelles : après le passage
vue(1100, "s-stylet-sillage", 6400, Y - 6, 0.36)
vue(1102, "s-stylet-sillage-z1", 6380, Y, 0.9, false, { 1600, 1000 })
vue(1720, "s-trombe-couloir", 6800, Y - 6, 0.28)
vue(2600, "s-ixion-lac", 7300, Y - 6, 0.3)
vue(2602, "s-ixion-lac-z1", 7300, Y - 6, 0.9, false, { 1600, 1000 })
vue(2950, "s-tournesol-spirale-chaude", 7900, Y - 6, 0.22)
vue(2952, "s-tournesol-spirale-dezoom", 7900, Y - 6, 0.08)
vue(3500, "s-ixion-lac-nuit", 7300, Y - 6, 0.3, true)
vue(3520, "s-tournesol-spirale-nuit", 7900, Y - 6, 0.22, true)
vue(4330, "s-ixion-lac-refroidit-nuit", 7300, Y - 6, 0.3, true)
table.sort(PLAN, function(a, b) return a.tick < b.tick end)

return {
  description = "DESIGN-ATTAQUES : les 5 grandes attaques des geants (et le Glas en repere), en images, jour et nuit",
  check_tick = CONTROLE,
  shots_delay = PLAN[1].tick,

  init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    s.always_day = false
    s.freeze_daytime = true
    s.daytime = 0
    C.forces()
    remote.call("fo-att2", "journal", true)
    st.sites = {}
    for k, site in ipairs(SITES) do
      -- géant posé au lancement seulement (C.poser) : sa 1re attaque ne touche pas la base « avant »
      local ss = C.site(ctx, k, site.id, site.x, Y, true)
      st.sites[k] = ss
      ctx.log(string.format("site %d %s : %d poteaux", k, site.id, ss.poles))
    end
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    local s = ctx.surface()
    if t == NUIT then s.daytime = 0.5 end
    for k, site in ipairs(SITES) do
      local ss = st.sites[k]
      if site.id == "bourdon" then
        if t == 400 then remote.call("fo-bourdon", "muet", ss.b, true) end
        if t == site.lance then
          remote.call("fo-bourdon", "recharge_zero", ss.b)
          ctx.check(remote.call("fo-bourdon", "glas", ss.b, site.x + 20, Y - 5) == true, "bourdon (site 7) : Glas (repere)")
        end
      elseif t == site.lance then
        local g = C.poser(s, ss)
        ctx.check(g ~= nil and g.valid, string.format("%s (site %d) : geant pose", site.id, k))
        local okl, why = remote.call("fo-att2", "lancer", g, site.x + 0.5, Y + 0.5, true)
        ctx.check(okl == true, string.format("%s (site %d) : grande attaque lancee", site.id, k), tostring(why))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local stats = remote.call("fo-att2", "stats")
    for k, ss in ipairs(st.sites) do
      if ss.ami then
        ctx.check(ss.ami.valid and ss.ami.health == ss.ami.prototype.max_health, string.format("%s (site %d) : le batiment ami dans la zone est intact", ss.id, k))
      end
      local x = stats[ss.id] or {}
      ctx.log(string.format("%s : salves %d, cibles %d, tues %d, degats %.0f, falaises %d, poteaux %d, foudres %d, tuiles %d, rochers %d, feux %d, max ops %d",
        ss.id, x.salves or 0, x.cibles or 0, x.tues or 0, x.degats or 0, x.falaises or 0, x.poteaux or 0, x.foudres or 0, x.tuiles or 0,
        x.rochers or 0, x.feux or 0, x.max_ops or 0))
    end
    ctx.check(((stats.cairn or {}).poteaux or 0) >= 40, "cairn : la surtension a grille le reseau")
    ctx.check(((stats.stylet or {}).feux or 0) >= 20, "stylet : le balayage a mis le feu sur son passage")
    ctx.check(((stats.trombe or {}).rochers or 0) >= 1, "trombe : rochers sur le couloir")
    ctx.check(((stats.ixion or {}).tuiles or 0) >= 500, "ixion : lac de lave")
    ctx.check(((stats.tournesol or {}).tuiles or 0) >= 800, "tournesol : spirale de verre")
  end,

  shots = function(ctx, add)
    for i, p in ipairs(PLAN) do
      local suivant = PLAN[i + 1]
      add(p.nom, p.x, p.y, p.zoom, p.nuit and 0.5 or 0, { res = p.res, cadence = suivant and math.max(1, suivant.tick - p.tick) or nil, aa = true })
    end
  end,
}
