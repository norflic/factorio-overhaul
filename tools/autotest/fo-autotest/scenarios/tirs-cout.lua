-- Scénario greffé du lot TIRS (27/10 ; ronde 4) : COÛT des tirs habillés dans une défense DENSE, en trois PHASES
-- A / B / A dans la même partie (habillage allumé, éteint, rallumé : fo-tirs.actif) pour séparer le coût de
-- l'ÉVÉNEMENT (moteur, sans plafond : toute tourelle à balles) du coût de l'HABILLAGE (plafonné), et compter les
-- habillages par âge (équité du quota).
--   banc.py [--seul] --qui TIRS -- 6700 tirs-cout <source>      puis  py -3.9 -B tools/autotest/tirs_cout.py <archive>
--   « main » : le MÊME scénario sur une copie de main sans le lot (aucun événement : bras « sans le lot »).
-- 80 mitrailleuses (16 par âge témoin : niveaux 2, 9, 15, 19, 29), chacune face à un ver géant ENNEMI à 11 tuiles au
-- nord (cessez-le-feu de l'ennemi ; ver recréé s'il meurt), en 5 rangées à 100 tuiles d'écart ; tir continu.
-- Sans --seul, les temps ne valent rien (F30, interdit n° 4) : seuls les compteurs comptent.

local X0, Y0 = 3200, 2600
local NIVEAUX = { 2, 9, 15, 19, 29 }
local PAR_RANGEE, PAS_RANGEE, DIST = 16, 100, 11
local T_MUN = 30
-- phases : [debut, fin) et habillage allumé ?
local PHASES = { { "A1", 600, 2600, true }, { "B", 2600, 4600, false }, { "A2", 4600, 6600, true } }
local CHECK = 6600
local MUN = "firearm-magazine"

local function copie_stats(ctx)
  if not ctx.has("fo-tirs", "stats") then return nil end
  local s = ctx.remote("fo-tirs", "stats")
  local out = { autres = s.autres, ages = {} }
  for _, a in ipairs(s.ages) do out.ages[#out.ages + 1] = a end
  return out
end

return {
  description = "TIRS : cout des tirs habilles, defense dense de 80 mitrailleuses (5 ages temoins), phases A/B/A",
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
      local pas = math.ceil(n / 2) <= 3 and 3 or (n <= 12 and 4 or (n <= 18 and 5 or 7))
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
    st.instant = {}
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
    -- cibles : recréées une fois toutes les 30 ticks (coût du banc identique dans toutes les phases)
    if e.tick >= 20 and e.tick % 30 == 20 then
      for _, c in ipairs(st.t) do
        if not (c.ver and c.ver.valid) then
          c.ver = s.create_entity({ name = "behemoth-worm-turret", position = { c.cx, c.cy }, force = "enemy" })
        end
      end
    end
    -- phases : au début de chaque phase, l'habillage est allumé ou éteint et les compteurs relevés
    for _, ph in ipairs(PHASES) do
      if e.tick == ph[2] then
        if ctx.has("fo-tirs", "actif") then ctx.remote("fo-tirs", "actif", ph[4]) end
        st.instant[ph[1]] = copie_stats(ctx) or false
        ctx.log(string.format("PHASE\t%s\tdebut=%d\tfin=%d\tactif=%s", ph[1], ph[2], ph[3], tostring(ph[4])))
      end
    end
    if e.tick == CHECK - 1 then st.instant.fin = copie_stats(ctx) or false end
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
    if not ctx.has("fo-tirs", "stats") then
      ctx.log("interface fo-tirs absente : mod sans le lot (bras « sans le lot »)")
      ctx.check(true, "bras sans le lot", "fo-tirs absente")
      return
    end
    -- compteurs par phase (différence des relevés)
    local bornes = { "A1", "B", "A2", "fin" }
    local hab_a, hab_b = 0, 0
    for i = 1, 3 do
      local a, b = st.instant[bornes[i]], st.instant[bornes[i + 1]]
      local ph = PHASES[i]
      local l, ev, hab, ref = {}, 0, 0, 0
      for k, x in ipairs(b.ages) do
        local y = a.ages[k]
        local d = { evts = x.evts - y.evts, hab = x.habilles - y.habilles, quota = x.quota - y.quota,
          plafond = x.plafond - y.plafond, part = x.part - y.part }
        ev, hab, ref = ev + d.evts, hab + d.hab, ref + d.quota + d.plafond
        l[#l + 1] = string.format("age %d : %d evts, %d habilles (%.3f des evts), refus part %d quota %d plafond %d", x.age,
          d.evts, d.hab, d.evts > 0 and d.hab / d.evts or 0, d.part, d.quota, d.plafond)
      end
      local n = ph[3] - ph[2]
      ctx.log(string.format("COMPTEURS\t%s\tactif=%s\tticks=%d\tevenements=%d\t(%.3f/tick)\thabilles=%d\t(%.3f/tick)\t"
        .. "refus quota+plafond=%d\tautres=%d\t%s", ph[1], tostring(ph[4]), n, ev, ev / n, hab, hab / n, ref,
        b.autres - a.autres, table.concat(l, " ; ")))
      if ph[4] then hab_a = hab_a + hab else hab_b = hab_b + hab end
    end
    ctx.check(hab_a > 0 and hab_b == 0, "phases A habillees, phase B sans habillage (evenement seul)",
      "A " .. hab_a .. ", B " .. hab_b)
  end,
}
