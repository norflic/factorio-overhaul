-- Scénario greffé du lot TIRS (27/10) : COÛT des tirs habillés dans une défense DENSE (mesure K10, --seul).
--   banc.py --seul --qui TIRS -- 6000 tirs-cout <source>      puis  python tools/autotest/analyze.py <archive>
--   « avant » : le MÊME scénario sur une copie de main sans le lot (le mod n'a pas l'interface fo-tirs : rien n'est
--   habillé, aucun événement n'est levé) ; « après » : la branche du lot.
-- 80 mitrailleuses (20 par âge témoin : niveaux 2, 9, 19, 29), chacune face à un ver géant ENNEMI à 11 tuiles au nord
-- (cessez-le-feu de l'ennemi ; ver recréé s'il meurt), rangées à 100 tuiles d'écart ; tir continu du tick 30 à la fin.
-- 80 tourelles × 10 tirs/s = 13,3 tirs par tick ; avec la probabilité 0,5 des chargeurs, environ 6,7 événements par tick,
-- au-dessus du plafond de 6 tirs habillés par tick (le plafond travaille).
-- Contrôles (au tick CHECK) : 80 tourelles posées, toutes ont tiré ; compteurs du mod (s'il a l'interface).

local X0, Y0 = 3200, 2600
local NIVEAUX = { 2, 9, 19, 29 }
local PAR_RANGEE, PAS_RANGEE, DIST = 20, 100, 11
local T_MUN, CHECK = 30, 5800
local MUN = "firearm-magazine"

return {
  description = "TIRS : cout des tirs habilles, defense dense de 80 mitrailleuses (4 ages temoins) en tir continu",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.pret = false
    game.map_settings.enemy_expansion.enabled = false
    game.forces.player.set_cease_fire("enemy", false)
    game.forces.enemy.set_cease_fire("player", true)
    st.t = {}
    for r, n in ipairs(NIVEAUX) do
      local y = Y0 + (r - 1) * PAS_RANGEE
      local pas = math.ceil(n / 2) <= 3 and 3 or (n <= 18 and 5 or 7)
      ctx.prepare_area(X0 - 10, y - DIST - 10, X0 + PAR_RANGEE * pas + 10, y + 10, "grass-1")
      for _, e in ipairs(s.find_entities_filtered({ force = "enemy",
          area = { { X0 - 60, y - 70 }, { X0 + PAR_RANGEE * pas + 60, y + 40 } } })) do
        e.destroy()
      end
      for i = 1, PAR_RANGEE do
        local x = X0 + (i - 1) * pas
        local t = s.create_entity({ name = "fo-lvl-gun-" .. n, position = { x, y }, force = "player" })
        st.t[#st.t + 1] = { t = t, cx = x, cy = y - DIST - math.floor(pas / 2) }
      end
    end
    local poses = 0
    for _, c in ipairs(st.t) do if c.t then poses = poses + 1 end end
    ctx.check(poses == #NIVEAUX * PAR_RANGEE, "tourelles posees", poses .. " / " .. #NIVEAUX * PAR_RANGEE)
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local s = ctx.surface()
    if e.tick == T_MUN then
      for _, c in ipairs(st.t) do
        if c.t and c.t.valid then
          c.t.insert({ name = MUN, count = 200 })
          c.mun0 = c.t.get_inventory(defines.inventory.turret_ammo).get_item_count(MUN)
        end
      end
    end
    -- cibles : recréées une fois toutes les 30 ticks (coût du banc identique avant et après)
    if e.tick >= 20 and e.tick % 30 == 20 then
      for _, c in ipairs(st.t) do
        if not (c.ver and c.ver.valid) then
          c.ver = s.create_entity({ name = "behemoth-worm-turret", position = { c.cx, c.cy }, force = "enemy" })
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    local tire, tirs = 0, 0
    for _, c in ipairs(st.t) do
      local mun = c.t and c.t.valid and c.t.get_inventory(defines.inventory.turret_ammo).get_item_count(MUN)
      if c.mun0 and mun and c.mun0 > mun then
        tire = tire + 1
        tirs = tirs + (c.mun0 - mun) * 10
      end
    end
    ctx.log(string.format("tirs (chargeurs x 10, a 10 pres par tourelle) : %d en %d ticks, %.2f par tick", tirs,
      CHECK - T_MUN, tirs / (CHECK - T_MUN)))
    ctx.check(tire == #st.t, "toutes les tourelles ont tire", tire .. " / " .. #st.t)
    if ctx.has("fo-tirs", "stats") then
      local stats = ctx.remote("fo-tirs", "stats")
      local l, ev, hab, pl = {}, 0, 0, 0
      for _, a in ipairs(stats.ages) do
        ev, hab, pl = ev + a.evts, hab + a.habilles, pl + a.plafond
        l[#l + 1] = string.format("age %d : %d evts, %d habilles, %d plafond, %d crees", a.age, a.evts, a.habilles,
          a.plafond, a.crees)
      end
      ctx.log("compteurs du lot : " .. table.concat(l, " ; ") .. string.format(
        " ; total %d evenements (%.2f par tick), %d habilles (%.2f par tick), %d refus du plafond", ev,
        ev / CHECK, hab, hab / CHECK, pl))
      ctx.check(hab > 0, "tirs habilles (branche du lot)", hab)
    else
      ctx.log("interface fo-tirs absente : mod sans le lot (temoin « avant »)")
      ctx.check(true, "temoin sans le lot", "fo-tirs absente")
    end
  end,
}
