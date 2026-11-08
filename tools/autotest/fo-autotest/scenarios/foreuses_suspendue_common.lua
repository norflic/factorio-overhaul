--[[
  Lot FOREUSES-THERMIQUES, partie C (lead, 8/11, lot de la 0.6.64) : un banc qui DÉPARTAGE la suspension de la pose (fdc2855e). Sur
  foreuses-panne, le témoin aussi ne posait rien pendant la coupure (aucune thermique candidate à ce moment) : le contrôle ne prouvait rien
  en moteur réel. Ici, la coupure tombe TÔT, quand des thermiques candidates restent libres :
    - monde de foreuses-panne (votre équipe, gisement de fer à 48 tuiles, interface d'énergie, avant-poste de 8 thermiques au tick W0) ;
    - coupure (interface retirée) au premier relevé (toutes les STEP ticks) où au moins 2 électriques sont posées ET au travail ;
    - courant rendu DARK ticks plus tard ; wait du repli (1 200) plus long que la coupure : aucun repli, seule la pose est en jeu.
  Après une coupure, producing() lit encore le flux de la DERNIÈRE MINUTE : sans la suspension, le remplacement pose de nouvelles
  électriques sur le réseau mort.
  Règle allumée (foreuses-suspendue) : AUCUNE électrique posée entre la coupure et le retour ; électriques sans courant vues par le repli
  (signal) ; aucun repli ; après le retour, la pose reprend (au moins une électrique de plus).
  Règle éteinte (foreuses-suspendue-temoin, comportement d'avant fdc2855e) : le remplacement POSE au moins une électrique pendant la coupure.
  Journal [FO-FOREUSES-SUSPENDUE(-TEMOIN)] ; ligne RESULTAT en clé=valeur. Lancement : banc.py --qui AP-ELEC -- 2100 foreuses-suspendue <source>.
]]

local W0 = 120
local STEP = 30
local DARK = 660
local CUT_LATEST = 1200 -- sans 2 électriques au travail à ce tick, le banc échoue (« coupure faite »)
local CHECK = 2000
local WAIT, HOLD, EVERY, PER = 1200, 600, 300, 2

return function(rule)
  local TAG = "FOREUSES-SUSPENDUE" .. (rule and "" or "-TEMOIN")

  local function survey(ctx, st)
    local s = ctx.surface()
    local area = { { st.cc.x - 16, st.cc.y - 16 }, { st.cc.x + 17, st.cc.y + 17 } }
    return s.find_entities_filtered({ area = area, name = "burner-mining-drill", force = "player" }),
      s.find_entities_filtered({ area = area, name = "electric-mining-drill", force = "player" })
  end
  local function key_of(e) return string.format("%.1f:%.1f", e.position.x, e.position.y) end

  local function place_source(ctx, st)
    local eei = ctx.surface().create_entity({ name = "electric-energy-interface", position = st.eei_pos, force = "player" })
    if eei then
      eei.power_production = 1e7 / 60
      eei.electric_buffer_size = 1e7
    end
    st.eei = eei
    return eei
  end

  local function repli_of(ctx, st)
    local rs = ctx.remote("fo-ia1", "repli_state", "player") or ""
    local done = tonumber(rs:match("replis=(%d+)") or "-1")
    local un = rs:match("[= ]" .. tostring(st.oid) .. ":%d+:(%d+):%-?%d+")
    return done, tonumber(un or "0"), rs
  end

  return {
    description = "FOREUSES-THERMIQUES partie C : pose suspendue pendant une coupure, regle " .. (rule and "ALLUMEE" or "ETEINTE (temoin)"),
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local st = ctx.state()
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 4) == 4, "effectif de depart 4")
      local s = ctx.surface()
      local c0 = game.forces.player.get_spawn_position(s)
      local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
      local hq = { x = math.floor(p.x) + 0.5, y = math.floor(p.y) + 0.5 }
      local cc = { x = math.floor(hq.x) + 48, y = math.floor(hq.y) }
      ctx.prepare_area(hq.x - 6, cc.y - 30, cc.x + 30, cc.y + 30, "grass-1")
      for dx = -9, 9 do
        for dy = -9, 9 do
          if dx * dx + dy * dy <= 81 then s.create_entity({ name = "iron-ore", position = { cc.x + dx, cc.y + dy }, amount = 20000 }) end
        end
      end
      local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      if not chest then return end
      local inv = chest.get_inventory(defines.inventory.chest)
      inv.insert({ name = "iron-plate", count = 200 })
      inv.insert({ name = "coal", count = 200 })
      inv.insert({ name = "electric-mining-drill", count = 12 })
      inv.insert({ name = "small-electric-pole", count = 40 })
      local ex, ey = math.floor(hq.x) + 6, math.floor(hq.y) - 8
      st.eei_pos = { x = ex + 1, y = ey + 1 }
      st.cc, st.hq = cc, hq
      ctx.check(place_source(ctx, st) ~= nil, "interface d'energie posee")
      local src = s.create_entity({ name = "small-electric-pole", position = { ex + 3.5, ey + 1.5 }, force = "player" })
      ctx.check(src ~= nil and ctx.remote("fo-ia1", "bench_own", "player", src) == true, "poteau source pose et enregistre a votre equipe")
      local radar = s.create_entity({ name = "radar", position = { ex + 5.5, ey + 1.5 }, force = "player" })
      ctx.check(radar ~= nil, "consommateur (radar) sur le reseau de la source")
      local cfg = ctx.remote("fo-ia1", "set_repli", "player", rule, WAIT, HOLD, EVERY, PER)
      ctx.check(cfg ~= nil and cfg:find("on=" .. tostring(rule), 1, true) ~= nil, "reglage du repli : " .. tostring(cfg))
      st.acc = { x = cc.x - 10 + 0.5, y = cc.y + 0.5 }
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.cc then return end
      local t = e.tick
      if t == W0 then
        local o = ctx.remote("fo-ia1", "bench_outpost", "player", "iron", st.cc.x, st.cc.y, st.acc.x, st.acc.y)
        ctx.check(o ~= nil, "avant-poste de fer pose, acces ecrit", o and (o.drills .. " foreuse(s)") or "nil")
        st.oid = o and o.id
        return
      end
      if not st.oid or t % STEP ~= 0 or t > CHECK then return end
      local burn, elec = survey(ctx, st)
      if not st.cut then
        if t > CUT_LATEST then return end
        local working = 0
        for _, d in ipairs(elec) do if d.status == defines.entity_status.working then working = working + 1 end end
        if #elec >= 2 and working == #elec then
          st.cut, st.restore = t, t + DARK
          st.e_cut, st.b_cut, st.known = #elec, #burn, {}
          for _, d in ipairs(elec) do st.known[key_of(d)] = true end
          st.replis_cut = repli_of(ctx, st)
          if st.eei and st.eei.valid then st.eei.destroy() end
          ctx.log(string.format("[FO-%s] coupure au tick %d : %d electrique(s) au travail, %d thermique(s) [%s]", TAG, t, #elec, #burn,
            tostring(ctx.remote("fo-ia1", "swap_state", "player"))))
        end
        return
      end
      if t == st.restore then
        place_source(ctx, st)
        ctx.log(string.format("[FO-%s] courant rendu au tick %d (interface %s)", TAG, t, tostring(st.eei ~= nil)))
      end
      local new = 0
      for _, d in ipairs(elec) do
        local k = key_of(d)
        if not st.known[k] then
          st.known[k] = true
          new = new + 1
        end
      end
      if t < st.restore then
        st.posed_dark = (st.posed_dark or 0) + new
        local _, un = repli_of(ctx, st)
        if un > 0 and not st.signal then st.signal = t end
      elseif new > 0 then
        st.posed_after = (st.posed_after or 0) + new
        st.back = st.back or t
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      ctx.check(st.oid ~= nil, "la construction a eu lieu", "tick " .. tostring(W0))
      ctx.check(st.cut ~= nil, "coupure faite (au moins 2 electriques au travail avant le tick " .. CUT_LATEST .. ")", tostring(st.cut))
      if not st.cut then return end
      local done, _, rs = repli_of(ctx, st)
      local burn, elec = survey(ctx, st)
      ctx.log(string.format("[FO-%s] RESULTAT regle=%s coupure=%d retour=%d electriques_coupure=%d thermiques_coupure=%d posees_pendant_coupure=%d signal=%s posees_apres_retour=%d premiere_apres_retour=%s replis=%d electriques_fin=%d thermiques_fin=%d repli=[%s]",
        TAG, rule and "oui" or "non", st.cut, st.restore, st.e_cut, st.b_cut, st.posed_dark or 0, tostring(st.signal), st.posed_after or 0,
        tostring(st.back), done, #elec, #burn, tostring(rs)))
      ctx.check(st.b_cut >= 2, "des thermiques restent a remplacer au moment de la coupure", tostring(st.b_cut))
      ctx.check(st.replis_cut == 0 and done == 0, "aucun repli (wait plus long que la coupure)", tostring(st.replis_cut) .. " " .. tostring(done))
      if rule then
        ctx.check((st.posed_dark or 0) == 0, "regle : AUCUNE electrique posee entre la coupure et le retour du courant", tostring(st.posed_dark or 0))
        ctx.check(st.signal ~= nil and st.signal - st.cut <= 300 + STEP, "regle : electriques sans courant vues par le repli a la pensee suivante",
          tostring(st.signal))
        ctx.check((st.posed_after or 0) >= 1, "regle : la pose reprend apres le retour du courant", tostring(st.posed_after or 0))
      else
        ctx.check((st.posed_dark or 0) >= 1, "temoin : le remplacement POSE des electriques sur le reseau mort (le defaut se reproduit)",
          tostring(st.posed_dark or 0))
      end
    end,
  }
end
