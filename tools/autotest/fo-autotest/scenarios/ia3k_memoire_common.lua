--[[
  Lot IA3-k (C5, C6, B5) : le CAS DU DC (Écarlate, partie du 26/10 : 26 PNJ tués en 41 min, presque tous en tournée
  « service » entre 87 et 103 tuiles du QG, par les mêmes petits déchiqueteurs et vers). Moteur réel, carte naturelle.
  Guerre de 2 factions (30 soldats, 8 ouvriers). Dès qu'Écarlate a un avant-poste entre 60 et 180 tuiles de son QG
  (contrôle toutes les 600 ticks, au plus tard au tick 72 000), un NID est posé à 70 % du chemin QG -> avant-poste : un
  nid de déchiqueteurs, un petit et un moyen ver, 4 petits déchiqueteurs. Puis une heure de jeu.
  Mesures (toutes les 600 ticks, morts lues sur la carte de l'équipe : interface « fo-ia3k », marquées même réglage
  éteint) : morts d'ouvriers d'Écarlate à moins de 48 tuiles du nid ; pour toute mort, morts de la même équipe à moins de
  32 tuiles dans l'heure (règle « au plus 2 au même endroit ») ; tournées vers l'avant-poste (tâches « service » réussies) ;
  décisions de la porte, escortes, nettoyages. Témoin : opts.temoin = réglage éteint.
]]

local C = {}

local KEY = "scarlet"
local FIND_UNTIL = 72000
local HOUR = 216000

local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

function C.scenario(opts)
  local CHECK = FIND_UNTIL + HOUR + 600
  return {
    description = opts.description,
    check_tick = CHECK,

    init = function(ctx)
      local st = ctx.state()
      local v = ctx.call("war_setting", "fo-war-ia3-comportement", not opts.temoin)
      ctx.check(v == (not opts.temoin), "reglage fo-war-ia3-comportement " .. (opts.temoin and "eteint (temoin)" or "allume"), tostring(v))
      local ok = ctx.call("war_start", 2, 30, 8)
      ctx.check(ok == true, "guerre lancee : 2 factions, 30 soldats, 8 ouvriers", tostring(ok))
      ctx.call("profiler", true)
      st.deaths, st.seen_d = {}, {}
    end,

    tick = function(ctx, e)
      local t = e.tick
      local st = ctx.state()
      if t % 600 ~= 0 or t == 0 then return end
      local s = ctx.surface()
      -- Pose du nid sur la route d'un avant-poste d'Écarlate.
      if not st.nest and t <= FIND_UNTIL then
        local poi = ctx.call("points_of_interest")
        for _, f in ipairs(poi.factions or {}) do
          if f.key == KEY then
            local best, bd
            for _, o in ipairs(f.outposts) do
              local dd = math.sqrt(d2(o.pos, f.hq))
              if dd >= 60 and dd <= 180 and (not bd or dd < bd) then best, bd = o, dd end
            end
            if not best and t % 6000 == 0 then
              local ds = {}
              for _, o in ipairs(f.outposts) do ds[#ds + 1] = string.format("%s %.0f", o.kind, math.sqrt(d2(o.pos, f.hq))) end
              ctx.log(string.format("tick %d : pas encore d'avant-poste d'Ecarlate a 60-180 tuiles (%s)", t, #ds > 0 and table.concat(ds, ", ") or "aucun"))
            end
            if best then
              local at = { x = f.hq.x + (best.pos.x - f.hq.x) * 0.7, y = f.hq.y + (best.pos.y - f.hq.y) * 0.7 }
              local placed = {}
              for _, m in ipairs({ { "biter-spawner", 0, 0 }, { "small-worm-turret", -6, 4 }, { "medium-worm-turret", 6, -4 },
                { "small-biter", -4, -6 }, { "small-biter", 4, 6 }, { "small-biter", -8, 0 }, { "small-biter", 8, 0 } }) do
                local p = s.find_non_colliding_position(m[1], { x = at.x + m[2], y = at.y + m[3] }, 12, 0.5)
                local en = p and s.create_entity({ name = m[1], position = p, force = "enemy" })
                if en then placed[#placed + 1] = m[1] end
              end
              st.nest = { x = at.x, y = at.y, t = t, outpost = { x = best.pos.x, y = best.pos.y }, hq = f.hq, d = bd, n = #placed }
              ctx.log(string.format("nid pose au tick %d en (%d, %d) : %d entites, a %.0f tuiles du QG d'Ecarlate (%d, %d), sur la route de l'avant-poste %s en (%d, %d) a %.0f tuiles",
                t, math.floor(at.x), math.floor(at.y), #placed, math.sqrt(d2(at, f.hq)), math.floor(f.hq.x), math.floor(f.hq.y), best.kind,
                math.floor(best.pos.x), math.floor(best.pos.y), bd))
            end
          end
        end
      end
      -- Morts (carte de l'équipe : positions et dates).
      local dg = ctx.remote("fo-ia3k", "danger", KEY)
      for _, d in ipairs((dg and dg.deaths) or {}) do
        local k = string.format("%d:%d:%d", d.t, math.floor(d.x), math.floor(d.y))
        if not st.seen_d[k] then
          st.seen_d[k] = true
          st.deaths[#st.deaths + 1] = { x = d.x, y = d.y, t = d.t }
        end
      end
      if st.nest and t % 18000 == 0 then
        local stv = ctx.remote("fo-ia3k", "status", KEY)
        local near = 0
        for _, d in ipairs(st.deaths) do if d.t >= st.nest.t and d2(d, st.nest) <= 48 * 48 then near = near + 1 end end
        local sv = stv and stv.stats or {}
        local nests = s.count_entities_filtered({ position = st.nest, radius = 30, type = "unit-spawner", force = "enemy" })
        local worms = s.count_entities_filtered({ position = st.nest, radius = 30, type = "turret", force = "enemy" })
        ctx.log(string.format("minute %d : morts pres du nid %d (toutes %d) ; porte %s ; escortes pretes %d ; nettoyages %d (lances %d) ; nid encore la %d, vers %d",
          math.floor(t / 3600), near, #st.deaths, (function() local o = {} for _, k in ipairs({ "go", "escort", "wait" }) do o[#o + 1] = k .. "=" .. tostring((sv.gate or {})[k] or 0) end return table.concat(o, " ") end)(),
          sv.escort_ready or 0, sv.cleared or 0, sv.clear_ops or 0, nests, worms))
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local s = ctx.surface()
      ctx.check(st.nest ~= nil, "nid pose sur la route d'un avant-poste d'Ecarlate a 60-180 tuiles", st.nest and st.nest.t or "jamais")
      if not st.nest then return end
      local t0 = st.nest.t
      local near, all = 0, 0
      for _, d in ipairs(st.deaths) do
        if d.t >= t0 and d.t <= t0 + HOUR then
          all = all + 1
          if d2(d, st.nest) <= 48 * 48 then near = near + 1 end
        end
      end
      -- Règle de l'heure : pour chaque mort, morts à moins de 32 tuiles dans l'heure qui suit.
      local worst = 0
      for _, d in ipairs(st.deaths) do
        local n = 0
        for _, x in ipairs(st.deaths) do
          if x.t >= d.t and x.t < d.t + HOUR and d2(x, d) <= 32 * 32 then n = n + 1 end
        end
        if n > worst then worst = n end
      end
      local stv = ctx.remote("fo-ia3k", "status", KEY)
      local sv = stv and stv.stats or {}
      local teams = ctx.remote("fo-ia1", "teams") or {}
      local lost, tours = "?", "?"
      for _, r in ipairs(teams) do
        if r.key == KEY then
          lost = r.lost_enemy
          -- Économie d'Écarlate (comparer au témoin : la prudence ne doit pas étrangler la faction).
          ctx.log(string.format("FAIT economie d'Ecarlate a la fin : livre fer %d, cuivre %d, charbon %d ; avant-postes %d ; soldats %d ; recrues %d ; PNJ %d ; perdus %d (dont ennemis %d)",
            r.delivered["iron-plate"] or 0, r.delivered["copper-plate"] or 0, r.delivered["coal"] or 0, r.outposts or 0, r.soldiers or 0,
            r.recruited or 0, r.n or 0, r.lost or 0, r.lost_enemy or 0))
        end
      end
      local nests = s.count_entities_filtered({ position = st.nest, radius = 30, type = "unit-spawner", force = "enemy" })
      local sold = stv and stv.soldiers
      ctx.log(string.format("FAIT une heure apres le nid : %d mort(s) d'ouvriers d'Ecarlate a moins de 48 tuiles du nid, %d en tout ; au plus %d au meme endroit (32 tuiles) dans une heure ; tues par les ennemis (partie) %s",
        near, all, worst, tostring(lost)))
      ctx.log(string.format("FAIT porte : go %s, escorte %s, attente %s ; escortes pretes %s ; nettoyages lances %s, finis %s ; nid encore la : %d ; soldats (passages) : %s",
        tostring((sv.gate or {}).go), tostring((sv.gate or {}).escort), tostring((sv.gate or {}).wait), tostring(sv.escort_ready),
        tostring(sv.clear_ops), tostring(sv.cleared), nests,
        sold and string.format("total %d, sans ordre %d, repos %d, groupes %d, egares %d", sold.total, sold.idle, sold.rest, sold.group, sold.far or 0) or "-"))
      if opts.temoin then
        ctx.check(true, string.format("temoin (sans le lot) : %d mort(s) pres du nid en une heure, au plus %d au meme endroit (mesure)", near, worst))
      else
        ctx.check(worst <= 2, "C5 : au plus 2 morts au meme endroit par heure (equipe Ecarlate)", worst)
        ctx.check(near <= 2, "C5 : au plus 2 morts d'ouvriers pres du nid dans l'heure", near)
      end
    end,
  }
end

return C
