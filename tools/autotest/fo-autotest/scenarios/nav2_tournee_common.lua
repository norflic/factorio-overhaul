--[[
  Lot NAV2 (3/11) : la tournée atteint-elle un avant-poste DENSE dont le point d'accès est dans une poche fermée par le champ ?
  Défaut (lot CHARBON-MAIN, partie lot-271828182) : Écarlate, 29 foreuses de charbon à sec, 2 265 charbons dans les sorties, tournée en
  « chemin introuvable (no_path) » 90 fois. Cause mesurée (nav2-marge) : le but de la marche est dans une poche du champ.

  Banc CIBLÉ en moteur réel : votre équipe de 8 PNJ, coffre du QG SANS charbon, un gisement de charbon de rayon 9 à 48 tuiles où l'équipe
  a UN avant-poste agrandi jusqu'au plein (pose réelle : Outposts.build puis Outposts.extend), point d'accès au centre du gisement (dans
  le champ), foreuses À SEC, 300 charbons dans chaque coffre de sortie. Fenêtre de 5 min à partir du tick 60, échantillon toutes les
  10 ticks : foreuses ravitaillées au moins une fois, foreuses à sec à la fin, charbon pris dans les sorties, refus de chemin
  « inaccessible » du service de chemins (compteur fail_other). Règle « accès atteignable » allumée (nav2-tournee) ou coupée
  (nav2-tournee-temoin : 0.6.42). Journal [FO-NAV2-TOURNEE(-TEMOIN)] ; ligne RESULTAT en clé=valeur.
]]

local MIN = 3600
local W0 = 60
local WINDOW = 5 * MIN
local CHECK = W0 + WINDOW + 100
local STEP = 10
local PER_CHEST = 300

local function chest_of(ctx)
  return ctx.surface().find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
end

local function fail_other(ctx)
  local ok, p = pcall(ctx.remote, "fo-ia1", "path")
  return ok and p and p.fail_other or 0
end

return function(rule)
  local TAG = "NAV2-TOURNEE" .. (rule and "" or "-TEMOIN")
  return {
    description = "NAV2 : tournee vers un avant-poste dense, acces dans le champ, regle " .. (rule and "ALLUMEE" or "COUPEE (temoin)"),
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local st = ctx.state()
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
      local s = ctx.surface()
      local c0 = game.forces.player.get_spawn_position(s)
      local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
      local hq = { x = math.floor(p.x) + 0.5, y = math.floor(p.y) + 0.5 }
      local cc = { x = math.floor(hq.x) + 48, y = math.floor(hq.y) }
      ctx.prepare_area(cc.x - 30, cc.y - 30, cc.x + 30, cc.y + 30, "grass-1")
      local n_c = 0
      for dx = -9, 9 do
        for dy = -9, 9 do
          if dx * dx + dy * dy <= 81 then
            s.create_entity({ name = "coal", position = { cc.x + dx, cc.y + dy }, amount = 20000 })
            n_c = n_c + 1
          end
        end
      end
      local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose", string.format("gisement %d tuiles en (%d, %d)", n_c, cc.x, cc.y))
      if not chest then return end
      local inv = chest.get_inventory(defines.inventory.chest)
      inv.insert({ name = "iron-plate", count = 200 })
      local v = ctx.remote("fo-ia1", "set_regle_acces", "player", rule)
      ctx.check(v == rule, "interrupteur de la regle : " .. (rule and "allumee" or "coupee"), tostring(v))
      local o = ctx.remote("fo-ia1", "bench_outpost", "player", "coal", cc.x, cc.y)
      ctx.check(o ~= nil, "avant-poste de charbon pose", o and (o.drills .. " foreuse(s)") or "nil")
      if not o then return end
      local drills = ctx.remote("fo-ia1", "bench_extend", "player", o.id, 20)
      ctx.check((drills or 0) >= 30, "champ dense (agrandi jusqu'au plein)", tostring(drills) .. " foreuse(s)")
      st.cc, st.oid, st.hq = cc, o.id, { x = chest.position.x, y = chest.position.y }
      ctx.log(string.format("[FO-%s] depart : coffre en %.1f,%.1f ; gisement %d tuiles en (%d, %d) ; avant-poste %d, %d foreuse(s) ; acces au centre",
        TAG, hq.x, hq.y, n_c, cc.x, cc.y, o.id, drills or 0))
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.cc then return end
      local s = ctx.surface()
      local t = e.tick
      if t == 1 then
        st.drills, st.chests = {}, {}
        for _, d in ipairs(s.find_entities_filtered({ name = "burner-mining-drill", force = "player", position = st.cc, radius = 16 })) do
          d.get_fuel_inventory().clear()
          if d.burner and d.burner.currently_burning then d.burner.remaining_burning_fuel = 0 end
          st.drills[#st.drills + 1] = { e = d, fed = false }
        end
        for _, c in ipairs(s.find_entities_filtered({ name = "iron-chest", force = "player", position = st.cc, radius = 18 })) do
          local ci = c.get_inventory(defines.inventory.chest)
          ci.clear()
          ci.insert({ name = "coal", count = PER_CHEST })
          st.chests[#st.chests + 1] = c
        end
        local chest = chest_of(ctx)
        if chest then chest.get_inventory(defines.inventory.chest).remove({ name = "coal", count = 100000 }) end
        st.coal0 = #st.chests * PER_CHEST
        ctx.log(string.format("[FO-%s] etat de depart : %d foreuse(s) a sec, %d coffre(s) de sortie a %d charbons, coffre du QG sans charbon",
          TAG, #st.drills, #st.chests, PER_CHEST))
      end
      if t == W0 then
        st.t0 = t
        st.fail0 = fail_other(ctx)
      end
      if not st.t0 or t > W0 + WINDOW or t % STEP ~= 0 then return end
      for _, d in ipairs(st.drills) do
        if not d.fed and d.e.valid and d.e.get_fuel_inventory().get_item_count() > 0 then
          d.fed = true
          d.at = t
        end
      end
      if (t - W0) % MIN == 0 then
        local fed, coal = 0, 0
        for _, d in ipairs(st.drills) do if d.fed then fed = fed + 1 end end
        for _, c in ipairs(st.chests) do if c.valid then coal = coal + c.get_inventory(defines.inventory.chest).get_item_count("coal") end end
        ctx.log(string.format("[FO-%s] minute %d | foreuses ravitaillees %d/%d | charbon des coffres de sortie %d | refus inaccessible %d",
          TAG, math.floor((t - W0) / MIN), fed, #st.drills, coal, fail_other(ctx) - (st.fail0 or 0)))
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      if not st.t0 then
        ctx.check(false, "la fenetre a commence", "tick " .. tostring(CHECK))
        return
      end
      local fed, dry, first = 0, 0, nil
      for _, d in ipairs(st.drills) do
        if d.fed then
          fed = fed + 1
          if not first or d.at < first then first = d.at end
        end
        if d.e.valid and d.e.get_fuel_inventory().get_item_count() == 0 then dry = dry + 1 end
      end
      local coal = 0
      for _, c in ipairs(st.chests) do if c.valid then coal = coal + c.get_inventory(defines.inventory.chest).get_item_count("coal") end end
      local nf = fail_other(ctx) - (st.fail0 or 0)
      ctx.log(string.format("[FO-%s] RESULTAT foreuses=%d ravitaillees=%d a_sec_fin=%d premier_s=%.0f charbon_coffres_depart=%d charbon_coffres_fin=%d refus_inaccessible=%d",
        TAG, #st.drills, fed, dry, first and (first - W0) / 60 or -1, st.coal0 or 0, coal, nf))
      ctx.check(#st.drills >= 30, "foreuses suivies", tostring(#st.drills))
      if rule then
        ctx.check(fed * 10 >= #st.drills * 9, "au moins 90 % des foreuses ravitaillees en 5 min", string.format("%d/%d", fed, #st.drills))
        ctx.check(coal < (st.coal0 or 0), "du charbon pris dans les sorties", string.format("%d -> %d", st.coal0 or 0, coal))
      end
    end,
  }
end
