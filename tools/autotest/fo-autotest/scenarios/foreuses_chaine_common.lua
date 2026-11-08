--[[
  Lot FOREUSES-THERMIQUES (décision du DC par QCM, 5/11 20 h 47 : « Remplacer au fur et à mesure » : les thermiques remplacées une à une par
  des électriques AVEC LEUR POTEAU). Micro-scénario (règle du lead : le défaut reproduit en moins de 5 000 ticks avant tout banc long).
  Défaut mesuré (partie du DC, 0.6.53, fo-logs/2026-11-05_PARTIE-DC-ESSAI) : le remplacement sur place exigeait un poteau alimenté DÉJÀ là ;
  5 remplacements en 150 min, 201 thermiques de fer, 0 électrique de fer.
  Banc CIBLÉ en moteur réel (3 800 ticks) : votre équipe, un gisement de fer de rayon 9 à 48 tuiles du QG, un réseau alimenté (interface
  d'énergie et un petit poteau) près du QG, à 31 tuiles et plus des foreuses ; au tick W0, l'avant-poste de fer est bâti (Outposts.build,
  accès écrit côté QG : son couloir existe) puis agrandi 2 fois ; le coffre porte 12 foreuses électriques et 40 petits poteaux (pas
  d'attente de fabrication). Mesures à la fin : foreuses électriques et thermiques de l'avant-poste, électriques sur le réseau de la source,
  petits poteaux posés, poteaux sur une tuile de couloir (remote couloirs).
  Règle allumée (foreuses-chaine) : des électriques remplacent les thermiques avec leur chaîne, toutes sur le réseau de la source, aucun
  poteau sur le couloir. Règle coupée (foreuses-chaine-temoin, comportement de 0.6.53) : le défaut doit se REPRODUIRE (aucune électrique).
  Journal [FO-FOREUSES-CHAINE(-TEMOIN)] ; ligne RESULTAT en clé=valeur.
]]

local W0 = 120
local CHECK = 3700

return function(rule)
  local TAG = "FOREUSES-CHAINE" .. (rule and "" or "-TEMOIN")
  return {
    description = "FOREUSES-THERMIQUES : remplacement sur place avec chaine de poteaux, regle " .. (rule and "ALLUMEE" or "COUPEE (temoin)"),
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
      local n_ore = 0
      for dx = -9, 9 do
        for dy = -9, 9 do
          if dx * dx + dy * dy <= 81 then
            s.create_entity({ name = "iron-ore", position = { cc.x + dx, cc.y + dy }, amount = 20000 })
            n_ore = n_ore + 1
          end
        end
      end
      local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose", string.format("gisement de fer %d tuiles en (%d, %d)", n_ore, cc.x, cc.y))
      if not chest then return end
      local inv = chest.get_inventory(defines.inventory.chest)
      inv.insert({ name = "iron-plate", count = 200 })
      inv.insert({ name = "coal", count = 200 })
      inv.insert({ name = "electric-mining-drill", count = 12 })
      inv.insert({ name = "small-electric-pole", count = 40 })
      -- réseau alimenté près du QG : interface d'énergie (2 × 2) et un petit poteau qui la touche
      local ex, ey = math.floor(hq.x) + 6, math.floor(hq.y) - 8
      local eei = s.create_entity({ name = "electric-energy-interface", position = { ex + 1, ey + 1 }, force = "player" })
      ctx.check(eei ~= nil, "interface d'energie posee")
      if eei then
        eei.power_production = 1e7 / 60
        eei.electric_buffer_size = 1e7
      end
      local src = s.create_entity({ name = "small-electric-pole", position = { ex + 3.5, ey + 1.5 }, force = "player" })
      ctx.check(src ~= nil, "poteau source pose")
      -- revue du lead (4), 7/11 : seul un poteau de l'ÉQUIPE sert de source (votre équipe partage la force du joueur)
      ctx.check(src ~= nil and ctx.remote("fo-ia1", "bench_own", "player", src) == true, "poteau source enregistre a votre equipe")
      -- un consommateur sur le réseau (radar, 300 kW) : sans charge, l'interface ne produit rien et le réseau n'est pas « alimenté »
      -- (statistiques de flux nulles : producing() de script/team/foreuse_swap.lua), comme une centrale sans machine branchée
      local radar = s.create_entity({ name = "radar", position = { ex + 5.5, ey + 1.5 }, force = "player" })
      ctx.check(radar ~= nil, "consommateur (radar) sur le reseau de la source")
      local v = ctx.remote("fo-ia1", "set_regle_chaine", "player", rule)
      ctx.check(v == rule, "regle de la chaine : " .. (rule and "allumee" or "coupee"), tostring(v))
      st.cc, st.hq, st.src = cc, hq, src
      st.acc = { x = cc.x - 10 + 0.5, y = cc.y + 0.5 } -- accès côté QG, au bord ouest du gisement
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.cc or e.tick ~= W0 then return end
      local o = ctx.remote("fo-ia1", "bench_outpost", "player", "iron", st.cc.x, st.cc.y, st.acc.x, st.acc.y)
      ctx.check(o ~= nil, "avant-poste de fer pose, acces ecrit", o and (o.drills .. " foreuse(s)") or "nil")
      if not o then return end
      local drills = ctx.remote("fo-ia1", "bench_extend", "player", o.id, 2)
      st.oid, st.burners_w0 = o.id, drills or o.drills
      local d = (st.src and st.src.valid) and math.sqrt((st.src.position.x - st.cc.x) ^ 2 + (st.src.position.y - st.cc.y) ^ 2) or -1
      ctx.log(string.format("[FO-%s] W0 : avant-poste %d, %d foreuse(s) thermique(s) ; poteau source a %.1f tuiles du centre du gisement",
        TAG, o.id, st.burners_w0 or 0, d))
    end,

    finish = function(ctx)
      local st = ctx.state()
      if not st.oid then
        ctx.check(false, "la construction a eu lieu", "tick " .. tostring(W0))
        return
      end
      local s = ctx.surface()
      local area = { { st.cc.x - 16, st.cc.y - 16 }, { st.cc.x + 17, st.cc.y + 17 } }
      local elec = s.find_entities_filtered({ area = area, name = "electric-mining-drill", force = "player" })
      local burn = s.find_entities_filtered({ area = area, name = "burner-mining-drill", force = "player" })
      local net = st.src and st.src.valid and st.src.electric_network_id or nil
      local on_net, into = 0, 0
      for _, d in ipairs(elec) do
        if net and d.electric_network_id == net then on_net = on_net + 1 end
        -- revue du lead (7/11, B1) : chaque électrique dépose dans un récepteur (four ou coffre), jamais au sol
        local t = d.drop_target
        if t and t.valid and (t.type == "furnace" or t.type == "container") then
          into = into + 1
        else
          ctx.log(string.format("[FO-%s] electrique en (%.1f, %.1f) direction %d SANS recepteur (depot en (%.2f, %.2f))", TAG, d.position.x,
            d.position.y, d.direction, d.drop_position.x, d.drop_position.y))
        end
      end
      local poles = s.find_entities_filtered({ area = { { st.hq.x - 10, st.cc.y - 30 }, { st.cc.x + 20, st.cc.y + 30 } }, name = "small-electric-pole",
        force = "player" })
      local placed = #poles - 1 -- moins la source
      local on_cor = ctx.remote("fo-ia1", "couloir_hits", "player", "small-electric-pole")
      local sw = ctx.remote("fo-ia1", "swap_state", "player")
      local min = (CHECK - W0) / 3600
      ctx.log(string.format("[FO-%s] RESULTAT regle=%s thermiques_W0=%d electriques=%d sur_reseau=%d dans_recepteur=%d thermiques_fin=%d poteaux_poses=%d poteaux_sur_couloir=%s rythme=%.1f/min swap=[%s]",
        TAG, rule and "oui" or "non", st.burners_w0 or 0, #elec, on_net, into, #burn, placed, tostring(on_cor), #elec / min, tostring(sw)))
      if rule then
        ctx.check(#elec >= 6, "regle : au moins 6 electriques remplacent les thermiques en 1 min", tostring(#elec))
        ctx.check(#elec > 0 and on_net == #elec, "regle : toutes les electriques sont sur le reseau de la source", on_net .. "/" .. #elec)
        ctx.check(#elec > 0 and into == #elec, "regle (B1) : chaque electrique depose dans un recepteur", into .. "/" .. #elec)
        ctx.check(placed >= 3, "regle : chaine de poteaux posee (au moins 3 petits poteaux)", tostring(placed))
        ctx.check(on_cor == nil or on_cor == 0, "regle : aucun poteau sur un couloir d'acces", tostring(on_cor))
      else
        ctx.check(#elec == 0, "temoin : le defaut se reproduit (aucune electrique sans poteau deja la)", tostring(#elec))
      end
    end,
  }
end
