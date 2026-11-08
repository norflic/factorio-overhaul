--[[
  Lot FOREUSES-THERMIQUES, partie C : le réseau qui tombe (fo-logs/2026-11-05_FOREUSES-TH/C_CRITERES.md). Micro-banc en moteur réel
  (2 500 ticks, règle du lead : moins de 2 500 ticks avant tout banc long).
  Monde du micro-scénario foreuses-chaine : votre équipe, un gisement de fer de rayon 9 à 48 tuiles du QG, un réseau alimenté par une
  interface d'énergie près du QG ; au tick W0, l'avant-poste de fer est bâti (8 thermiques) ; le remplacement sur place les passe à
  l'électrique (2 par pensée, chaîne de poteaux). Réglage du repli par le remote de banc : wait 300, hold 600, une passe par pensée,
  2 par passe.
    - tick CUT : l'interface d'énergie est retirée (le réseau ne produit plus rien) ;
    - tick RESTORE : elle est reposée (le courant revient).
  Relevé toutes les 30 ticks entre CUT et CHECK : thermiques et électriques du gisement (positions), état du repli (remote repli_state).
  Règle allumée (foreuses-panne) :
    - au moins 2 électriques avant la coupure, et AUCUN repli avant elle (réseau alimenté ; défaut vu au banc du 8/11 sur b964c9b1) ;
    - AUCUNE électrique posée entre la coupure et le retour du courant (pose suspendue par o.dark_units, lead 8/11) ;
    - signal (électriques sans courant comptées) à la première pensée après la coupure ;
    - aucun repli avant le début de la panne + wait ; au moins 2 replis avant le retour du courant ; ces thermiques TRAVAILLENT, avec du
      combustible, juste avant le retour du courant ;
    - aucune place repliée n'est remplacée de nouveau avant son repli + hold ; après le retour du courant, au moins une électrique de
      nouveau ; chaque électrique dépose dans un récepteur.
  Règle éteinte (foreuses-panne-temoin) : aucune thermique ne revient, les électriques restent sans courant jusqu'au retour du courant.
  Journal [FO-FOREUSES-PANNE(-TEMOIN)] ; ligne RESULTAT en clé=valeur.
]]

local W0 = 120
local CUT = 900
local RESTORE = 1560
local CHECK = 2450
local WAIT, HOLD, EVERY, PER = 300, 600, 300, 2
local STEP = 30

local function sorted_keys(t)
  local k = {}
  for x in pairs(t or {}) do k[#k + 1] = x end
  table.sort(k)
  return k
end

return function(rule, diag)
  local TAG = "FOREUSES-PANNE" .. (diag and "-DIAG" or "") .. (rule and "" or "-TEMOIN")

  local function survey(ctx, st)
    local s = ctx.surface()
    local area = { { st.cc.x - 16, st.cc.y - 16 }, { st.cc.x + 17, st.cc.y + 17 } }
    return s.find_entities_filtered({ area = area, name = "burner-mining-drill", force = "player" }),
      s.find_entities_filtered({ area = area, name = "electric-mining-drill", force = "player" })
  end
  local function key_of(e) return string.format("%.1f:%.1f", e.position.x, e.position.y) end

  local function place_source(ctx, st)
    local s = ctx.surface()
    local eei = s.create_entity({ name = "electric-energy-interface", position = st.eei_pos, force = "player" })
    if eei then
      eei.power_production = 1e7 / 60
      eei.electric_buffer_size = 1e7
    end
    st.eei = eei
    return eei
  end

  return {
    description = "FOREUSES-THERMIQUES partie C : repli thermique quand le reseau tombe, regle " .. (rule and "ALLUMEE" or "ETEINTE (temoin)"),
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
      st.appear, st.gone, st.seen_burn = {}, {}, {}
      st.min_elec = nil
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
      if not st.oid then return end
      -- diagnostic (foreuses-panne-diag) : électriques de l'avant-poste (numéro, position, reliée, au travail, dans un récepteur, statut)
      -- et état du repli, toutes les STEP ticks jusqu'à CUT + 300
      if diag and t % STEP == 0 and t <= CUT + 300 then
        local r = ctx.remote("fo-ia1", "swap_outposts", "player")
        ctx.log(string.format("[FO-%s] tick %d electriques %s | %s", TAG, t, r and table.concat(r.list, " ; ") or "nil",
          tostring(ctx.remote("fo-ia1", "repli_state", "player"))))
      end
      if t == CUT then
        local burn, elec = survey(ctx, st)
        st.e_cut, st.b_cut = #elec, #burn
        st.elec_cut = {}
        for _, d in ipairs(elec) do st.elec_cut[key_of(d)] = true end
        for _, b in ipairs(burn) do st.seen_burn[key_of(b)] = true end
        -- banc du 8/11 (b964c9b1) : 2 replis AVANT la coupure (électriques juste posées, mémoire par avant-poste) ; contrôlé désormais
        local rs = ctx.remote("fo-ia1", "repli_state", "player") or ""
        st.replis_cut = tonumber(rs:match("replis=(%d+)") or "-1")
        if st.eei and st.eei.valid then st.eei.destroy() end
        ctx.log(string.format("[FO-%s] coupure au tick %d : %d electrique(s), %d thermique(s)", TAG, t, #elec, #burn))
        return
      end
      if t == RESTORE then
        place_source(ctx, st)
        ctx.log(string.format("[FO-%s] courant rendu au tick %d (interface %s)", TAG, t, tostring(st.eei ~= nil)))
      end
      if t < CUT or t > CHECK or (t - CUT) % STEP ~= 0 then return end
      local burn, elec = survey(ctx, st)
      -- thermiques revenues (absentes à la coupure) : tick d'apparition ; puis de disparition (remplacées de nouveau)
      local here = {}
      for _, b in ipairs(burn) do
        local k = key_of(b)
        here[k] = b
        if not st.seen_burn[k] and not st.appear[k] then st.appear[k] = t end
      end
      for _, k in ipairs(sorted_keys(st.appear)) do
        if not here[k] and not st.gone[k] then st.gone[k] = t end
      end
      if t == RESTORE - STEP * 2 then -- juste avant le retour du courant
        local working, fueled, n = 0, 0, 0
        for _, k in ipairs(sorted_keys(st.appear)) do
          local b = here[k]
          if b then
            n = n + 1
            if b.status == defines.entity_status.working then working = working + 1 end
            local fi = b.get_fuel_inventory()
            if fi and fi.get_item_count("coal") > 0 then fueled = fueled + 1 end
          end
        end
        local dark = 0
        for _, d in ipairs(elec) do if d.status == defines.entity_status.no_power then dark = dark + 1 end end
        st.pre = { n = n, working = working, fueled = fueled, elec = #elec, dark = dark }
      end
      if t > CUT and not st.signal then
        local rs = ctx.remote("fo-ia1", "repli_state", "player") or ""
        local un, since = rs:match("[= ]" .. st.oid .. ":%d+:(%d+):(%-?%d+)")
        if un and tonumber(un) > 0 then st.signal, st.since = t, tonumber(since) end
      end
      st.min_elec = math.min(st.min_elec or #elec, #elec)
      -- (lead, 8/11) électriques POSÉES par le remplacement entre la coupure et le retour du courant (absentes à la coupure)
      if t > CUT and t < RESTORE then
        for _, d in ipairs(elec) do
          local k = key_of(d)
          if not st.elec_cut[k] then
            st.elec_cut[k] = true
            st.posed_dark = (st.posed_dark or 0) + 1
          end
        end
      end
      if t >= RESTORE and #elec > (st.min_elec or 0) and not st.back then st.back = t end
    end,

    finish = function(ctx)
      local st = ctx.state()
      if not st.oid then
        ctx.check(false, "la construction a eu lieu", "tick " .. tostring(W0))
        return
      end
      local burn, elec = survey(ctx, st)
      local into = 0
      for _, d in ipairs(elec) do
        local tg = d.drop_target
        if tg and tg.valid and (tg.type == "furnace" or tg.type == "container") then into = into + 1 end
      end
      local first, n_app, early = nil, 0, 0
      local reswap = 0
      for _, k in ipairs(sorted_keys(st.appear)) do
        n_app = n_app + 1
        local a = st.appear[k]
        if not first or a < first then first = a end
        if a < RESTORE and st.gone[k] then
          reswap = reswap + 1
          if st.gone[k] - a < HOLD - STEP then early = early + 1 end
        end
      end
      local rs = ctx.remote("fo-ia1", "repli_state", "player")
      local pre = st.pre or {}
      ctx.log(string.format("[FO-%s] RESULTAT regle=%s electriques_coupure=%d replis_avant_coupure=%s posees_pendant_coupure=%d signal=%s debut_panne=%s premier_repli=%s replis_vus=%d avant_retour=%d travaillent=%d avec_combustible=%d electriques_sans_courant=%d/%d reremplacees=%d trop_tot=%d electrique_de_nouveau=%s electriques_fin=%d dans_recepteur=%d thermiques_fin=%d repli=[%s]",
        TAG, rule and "oui" or "non", st.e_cut or -1, tostring(st.replis_cut), st.posed_dark or 0, tostring(st.signal), tostring(st.since), tostring(first), n_app, pre.n or -1,
        pre.working or -1, pre.fueled or -1, pre.dark or -1, pre.elec or -1, reswap, early, tostring(st.back), #elec, into, #burn, tostring(rs)))
      ctx.check((st.e_cut or 0) >= 2, "au moins 2 electriques avant la coupure", tostring(st.e_cut))
      ctx.check(st.replis_cut == 0, "aucun repli avant la coupure (reseau alimente)", tostring(st.replis_cut))
      if rule then
        ctx.check((st.posed_dark or 0) == 0, "aucune electrique posee entre la coupure et le retour du courant", tostring(st.posed_dark or 0))
      end
      if rule then
        ctx.check(st.signal ~= nil and st.signal - CUT <= 300 + STEP, "C1 signal a la premiere pensee apres la coupure", tostring(st.signal))
        ctx.check(first ~= nil and st.since ~= nil and first >= st.since + WAIT, "C1 aucun repli avant le debut de la panne + wait",
          tostring(first) .. " / " .. tostring(st.since))
        ctx.check((pre.n or 0) >= 2, "C2 au moins 2 replis avant le retour du courant", tostring(pre.n))
        ctx.check((pre.n or 0) > 0 and pre.working == pre.n and pre.fueled == pre.n, "C2 les thermiques revenues travaillent, avec du combustible",
          string.format("%s/%s/%s", tostring(pre.working), tostring(pre.fueled), tostring(pre.n)))
        ctx.check(early == 0, "C6 aucune place repliee remplacee de nouveau avant son repli + hold", tostring(early))
        ctx.check(st.back ~= nil and reswap >= 1, "C6 apres le retour du courant, remplacement de nouveau", tostring(st.back) .. " " .. reswap)
        ctx.check(#elec > 0 and into == #elec, "chaque electrique depose dans un recepteur", into .. "/" .. #elec)
      else
        ctx.check(n_app == 0, "temoin : aucune thermique ne revient", tostring(n_app))
        ctx.check((pre.elec or 0) >= 2 and pre.dark == pre.elec, "temoin : les electriques restent sans courant jusqu'au retour du courant",
          tostring(pre.dark) .. "/" .. tostring(pre.elec))
      end
    end,
  }
end
