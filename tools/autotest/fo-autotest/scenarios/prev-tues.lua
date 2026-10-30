--[[
  Lot PREVISION-CALIB (30/10) : banc COURT en moteur réel de la vague reçue mesurée par les unités TUÉES (crochet
  on_entity_died de script/ai3/prevision.lua). Un relevé par minute ne voit presque jamais une vague que les tourelles tuent en
  quelques secondes (partie verif-guide 0.6.24 : 8 vagues sur 18 « reçues » sans aucune unité vue) ; la calibration compte
  désormais ce que l'équipe a tué près de ses sites.
  Déroulé (2 factions) :
    - tick 120 : relevé de la première faction (calme) ;
    - tick 130 : 12 petits déchiqueteurs posés à 22 tuiles de son QG (ses 4 tourelles les tuent) ;
    - tick 700 : relevé : des unités tuées près du QG, attaque en cours (aucune vue au contact : déjà mortes) ;
    - tick 760 : relevé : fin de l'attaque, fait de calibration avec la vague reçue = PV tués.
  Lancement : `py -3.9 -B tools/autotest/banc.py --out <archive> --qui PREVISION-CALIB -- 1000 prev-tues <source>`.
  Journal : [FO-PREV-TUES].
]]

local N = 12

return {
  description = "PREVISION-CALIB : vague recue mesuree par les unites tuees (moteur reel)",
  check_tick = 900,

  init = function(ctx)
    local ok = ctx.call("war_start", 2, 10, 3, 260)
    ctx.check(ok == true, "guerre lancee (2 factions)", tostring(ok))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == 120 then
      local list = ctx.remote("fo-prevision", "teams")
      local t1 = list and list[1]
      if not t1 then return end
      st.key, st.hx, st.hy = t1.key, t1.x, t1.y
      st.calm = ctx.remote("fo-prevision", "relook", st.key)
    elseif e.tick == 130 and st.key then
      st.made, st.hp = 0, 0
      for i = 1, N do
        local p = s.find_non_colliding_position("small-biter", { st.hx + (i - N / 2) * 2, st.hy - 22 }, 8, 0.5)
        local u = p and s.create_entity({ name = "small-biter", position = p, force = "enemy" })
        if u then
          st.made = st.made + 1
          st.hp = st.hp + u.prototype.max_health
        end
      end
      ctx.log(string.format("tick 130 : %d petit(s) dechiqueteur(s) a 22 tuiles du QG de %s (%d PV)", st.made, st.key, st.hp))
    elseif e.tick == 700 and st.key then
      st.alive = s.count_entities_filtered({ position = { st.hx, st.hy }, radius = 60, type = "unit", force = "enemy" })
      st.mid = ctx.remote("fo-prevision", "relook", st.key)
    elseif e.tick == 760 and st.key then
      st.fin = ctx.remote("fo-prevision", "relook", st.key)
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check((st.made or 0) >= N / 2, "unites posees pres du QG", tostring(st.made) .. " sur " .. N)
    ctx.check(st.alive == 0, "les tourelles du QG les ont tuees avant le releve", tostring(st.alive) .. " vivante(s)")
    local evs = st.fin and st.fin.cal_last
    local ev = nil
    for _, x in ipairs(evs or {}) do if x.key == "qg" then ev = x end end
    ctx.check(ev ~= nil, "fait de calibration au QG a la fin de l'attaque", ev and (ev.kind .. ", recue " .. tostring(ev.recv)) or "aucun")
    ctx.check(ev and (ev.seen or 0) == 0 and (ev.killed or 0) > 0,
      "attaque mesuree par les unites TUEES (aucune vue au contact au releve)",
      ev and string.format("vue %s, tuee %s, pertes %s", tostring(ev.seen), tostring(ev.killed), tostring(ev.lost)) or "")
    ctx.check(ev and math.abs((ev.killed or 0) - (st.hp or 0)) < 1,
      "PV tues = PV des unites posees", ev and string.format("%s contre %s", tostring(ev.killed), tostring(st.hp)) or "")
  end,
}
