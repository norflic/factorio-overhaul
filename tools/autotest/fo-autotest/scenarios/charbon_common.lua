--[[
  Lot CHARBON-MAIN (3/11) : retour du DC, partie de 2 h 30 : « 35 foreuses thermique qui ne sont plus alimentées, des milliers de charbons
  réunis dans les coffres (de ces mêmes foreuses) et ils minent à la main juste à côté comme des débiles pour récupérer du charbon ?! ».

  Banc CIBLÉ en moteur réel : votre équipe de 8 PNJ, coffre du QG SANS charbon (minerai de fer et 4 fours au QG : le charbon manque),
  un gisement de charbon à 40 tuiles où l'équipe a 3 avant-postes de charbon (12 foreuses à combustion, coffres de sortie), TOUTES À SEC,
  et 300 charbons dans chaque coffre de sortie. Fenêtre de 5 min à partir du tick 60, échantillon toutes les 10 ticks :
    - foreuses de ces avant-postes qui ont reçu du combustible (au moins une fois) ; foreuses à sec à la fin ;
    - échantillons où un PNJ de l'équipe mine du charbon à la main (mining_state + entité sélectionnée = la ressource) ;
    - charbon des coffres de sortie (pris par les tournées).
  État posé au tick 1 (avant la première tâche des PNJ). Règle « sorties d'abord » allumée (charbon-banc) ou coupée (charbon-banc-temoin : comportement de 0.6.41). Journal [FO-CHARBON-BANC
  (-TEMOIN)] ; ligne RESULTAT en clé=valeur. Lancement : banc.py --qui CHARBONMAIN -- 19000 charbon-banc <source>.
]]

local MIN = 3600
local W0 = 60 -- l'état du DC est posé à l'init (avant toute tâche des PNJ) ; la fenêtre part au tick 60
local WINDOW = 5 * MIN
local CHECK = W0 + WINDOW + 100
local STEP = 10
local PER_CHEST = 300

local function patch(s, name, c, r, amount)
  for _, e in ipairs(s.find_entities_filtered({ position = c, radius = r + 3 })) do
    if e.valid and e.type ~= "character" and e.name ~= "fo-team-chest" then e.destroy() end
  end
  local n = 0
  for dx = -r, r do
    for dy = -r, r do
      if dx * dx + dy * dy <= r * r then
        s.create_entity({ name = name, position = { c.x + dx, c.y + dy }, amount = amount })
        n = n + 1
      end
    end
  end
  return n
end

local function chest_of(ctx)
  return ctx.surface().find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
end

return function(rule)
  local TAG = "CHARBON-BANC" .. (rule and "" or "-TEMOIN")
  return {
    description = string.format("CHARBON-MAIN : foreuses de charbon a sec, coffres de sortie pleins, regle %s", rule and "ALLUMEE" or "COUPEE (temoin)"),
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local st = ctx.state()
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
      local s = ctx.surface()
      local c0 = game.forces.player.get_spawn_position(s)
      local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
      local hq = { x = math.floor(p.x) + 0.5, y = math.floor(p.y) + 0.5 }
      local cc = { x = math.floor(hq.x) + 40, y = math.floor(hq.y) }
      local n_c = patch(s, "coal", cc, 9, 20000)
      local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose", string.format("gisement de charbon %d tuiles en (%d, %d)", n_c, cc.x, cc.y))
      if not chest then return end
      local inv = chest.get_inventory(defines.inventory.chest)
      inv.insert({ name = "iron-ore", count = 600 })
      inv.insert({ name = "iron-plate", count = 200 })
      local v = ctx.remote("fo-ia1", "set_regle_sorties", "player", rule)
      ctx.check(v == rule, "interrupteur de la regle : " .. (rule and "allumee" or "coupee"), tostring(v))
      local placed = ctx.remote("fo-ia1", "bench_smelters", "player", 4)
      ctx.check(placed == 4, "4 fours poses au QG", tostring(placed))
      -- les fours du QG partent sans charbon : le charbon MANQUE au coffre comme chez le DC
      for _, e in ipairs(s.find_entities_filtered({ name = "stone-furnace", force = "player", position = chest.position, radius = 30 })) do
        e.get_fuel_inventory().clear()
      end
      st.ids = {}
      local drills = 0
      for _, off in ipairs({ { -5, -4 }, { 4, -4 }, { 0, 5 } }) do
        local o = ctx.remote("fo-ia1", "bench_outpost", "player", "coal", cc.x + off[1], cc.y + off[2])
        if o then
          st.ids[#st.ids + 1] = o.id
          drills = drills + o.drills
        end
      end
      ctx.check(#st.ids == 3 and drills >= 9, "3 avant-postes de charbon poses", string.format("%d avant-poste(s), %d foreuse(s)", #st.ids, drills))
      st.hq, st.cc = { x = chest.position.x, y = chest.position.y }, cc
      st.t0 = nil
      ctx.log(string.format("[FO-%s] depart : coffre en %.1f,%.1f ; gisement %d tuiles ; avant-postes %s ; foreuses %d", TAG, hq.x, hq.y, n_c,
        table.concat(st.ids, ","), drills))
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.hq then return end
      local s = ctx.surface()
      local t = e.tick
      if t == 1 then
        -- foreuses À SEC et coffres de sortie garnis (état du DC), avant que les PNJ prennent leur première tâche (banc-lot1 : un minage
        -- programmé AVANT le remplissage des coffres, au tick 540, finissait dans la fenêtre)
        st.drills, st.chests = {}, {}
        for _, d in ipairs(s.find_entities_filtered({ name = "burner-mining-drill", force = "player", position = st.cc, radius = 16 })) do
          d.get_fuel_inventory().clear()
          if d.burner and d.burner.currently_burning then d.burner.remaining_burning_fuel = 0 end
          st.drills[#st.drills + 1] = { e = d, fed = false }
        end
        for _, c in ipairs(s.find_entities_filtered({ name = "iron-chest", force = "player", position = st.cc, radius = 18 })) do
          local inv = c.get_inventory(defines.inventory.chest)
          inv.clear()
          inv.insert({ name = "coal", count = PER_CHEST })
          st.chests[#st.chests + 1] = c
        end
        local chest = chest_of(ctx)
        if chest then chest.get_inventory(defines.inventory.chest).remove({ name = "coal", count = 100000 }) end
        st.coal0 = #st.chests * PER_CHEST
        st.hand, st.hand_any, st.samples = 0, {}, 0
        ctx.log(string.format("[FO-%s] etat de depart : %d foreuse(s) a sec, %d coffre(s) de sortie a %d charbons, coffre du QG sans charbon",
          TAG, #st.drills, #st.chests, PER_CHEST))
      end
      if t == W0 then st.t0 = t end
      if not st.t0 or t > W0 + WINDOW or t % STEP ~= 0 then return end
      st.samples = st.samples + 1
      for _, d in ipairs(st.drills) do
        if not d.fed and d.e.valid and d.e.get_fuel_inventory().get_item_count() > 0 then
          d.fed = true
          d.at = t
        end
      end
      -- minage à la main du charbon : le PNJ mine (mining_state, posé par le mod à chaque pensée) une position du gisement, ou l'entité
      -- sélectionnée est le charbon (un minage qui ne rend rien, « got=0 » du journal [FO-MINAGE], compte aussi)
      for _, c in ipairs(s.find_entities_filtered({ type = "character", force = "player" })) do
        local ms = c.valid and c.mining_state
        local sel = c.selected
        local mp = ms and ms.mining and ms.position
        local on_patch = mp and (mp.x - st.cc.x) ^ 2 + (mp.y - st.cc.y) ^ 2 <= 12 * 12
        if ms and ms.mining and (on_patch or (sel and sel.valid and sel.type == "resource" and sel.name == "coal")) then
          st.hand = st.hand + 1
          st.hand_any[c.unit_number or 0] = true
        end
      end
      if (t - W0) % MIN == 0 then
        local fed, coal = 0, 0
        for _, d in ipairs(st.drills) do if d.fed then fed = fed + 1 end end
        for _, c in ipairs(st.chests) do if c.valid then coal = coal + c.get_inventory(defines.inventory.chest).get_item_count("coal") end end
        ctx.log(string.format("[FO-%s] minute %d | foreuses ravitaillees %d/%d | charbon des coffres de sortie %d | echantillons de minage du charbon a la main %d",
          TAG, math.floor((t - W0) / MIN), fed, #st.drills, coal, st.hand))
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
      local miners = 0
      for _ in pairs(st.hand_any) do miners = miners + 1 end
      ctx.log(string.format("[FO-%s] RESULTAT foreuses=%d ravitaillees=%d a_sec_fin=%d premier_s=%.0f charbon_coffres_depart=%d charbon_coffres_fin=%d echantillons_main=%d mineurs_main=%d echantillons=%d",
        TAG, #st.drills, fed, dry, first and (first - W0) / 60 or -1, st.coal0 or 0, coal, st.hand, miners, st.samples))
      ctx.check(#st.drills >= 9, "foreuses suivies", tostring(#st.drills))
      ctx.check(st.samples >= WINDOW / STEP - 2, "la fenetre complete est echantillonnee", tostring(st.samples))
      if rule then
        ctx.check(fed == #st.drills, "toutes les foreuses ravitaillees en 5 min depuis leurs coffres", string.format("%d/%d", fed, #st.drills))
        ctx.check(st.hand == 0, "personne ne mine le charbon a la main", string.format("%d echantillon(s), %d PNJ", st.hand, miners))
      end
    end,
  }
end
