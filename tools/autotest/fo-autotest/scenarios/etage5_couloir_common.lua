--[[
  Lot ÉTAGE 5 (5/11, règle de méthode du lead : le défaut reproduit dans un micro-scénario avant tout banc long) : un PNJ muré par sa propre
  équipe à l'accès d'un avant-poste de charbon.
  Défaut mesuré (fo-logs/2026-11-04_ETAGE4/RAPPORT.md §4) : Écarlate, graine 20261020, PNJ coincé en (187, −499) de 25 à 50 min, cerné par
  les agrandissements de l'avant-poste de charbon n° 1 (24 foreuses en paires jointives) ; Émeraude, graine 123456789, même forme avec le
  champ vapeur en plus.
  Banc CIBLÉ en moteur réel (3 900 ticks) : votre équipe, un gisement de charbon de rayon 9 à 48 tuiles du QG ; au tick W0, un PNJ se tient
  au point d'accès (côté QG, sur le gisement, là où se tiendrait le bâtisseur), l'avant-poste est bâti (Outposts.build, accès écrit) puis
  agrandi 20 fois (Outposts.extend : pose réelle, crochet Outposts.reserved). Mesures, par remplissage des tuiles libres (obstacles
  player-layer sauf ce qui bouge, comme la règle NAV2) depuis le bord d'un rectangle autour du champ : l'accès est-il atteignable ? la tuile
  du PNJ l'est-elle (PNJ muré) ? Relevés à W0 et à la fin ; journal [FO-NAV-ACCES] (une tournée le lit) ; foreuses posées (couverture).
  Couloir allumé (etage5-couloir) : accès ouvert, PNJ libre. Couloir coupé (etage5-couloir-temoin : comportement d'avant) : le défaut doit
  se REPRODUIRE (accès fermé, PNJ muré) ; sinon le témoin échoue, le micro-scénario ne prouve rien.
  Journal [FO-ETAGE5-COULOIR(-TEMOIN)] ; ligne RESULTAT en clé=valeur.
]]

local W0 = 120
local CHECK = 3800
local HALF = 20 -- demi-côté du rectangle de remplissage autour du gisement (gisement de rayon 9, agrandissements sur le minerai)
local MOVING = { character = true, unit = true, car = true, ["spider-vehicle"] = true, gate = true }

local function tkey(x, y) return x .. "," .. y end

--- Tuiles atteignables depuis le bord du rectangle (4-voisinage) ; une tuile est bloquée si la boîte d'un obstacle player-layer qui ne bouge pas
--- la recouvre au sens strict.
local function reach(s, cc)
  local x0, y0, x1, y1 = cc.x - HALF, cc.y - HALF, cc.x + HALF, cc.y + HALF
  local bl = {}
  for _, e in ipairs(s.find_entities_filtered({ area = { { x0, y0 }, { x1 + 1, y1 + 1 } }, collision_mask = "player-layer" })) do
    if e.valid and not MOVING[e.type] then
      local bb = e.bounding_box
      for tx = math.floor(bb.left_top.x + 0.01), math.ceil(bb.right_bottom.x - 0.01) - 1 do
        for ty = math.floor(bb.left_top.y + 0.01), math.ceil(bb.right_bottom.y - 0.01) - 1 do bl[tkey(tx, ty)] = true end
      end
    end
  end
  local seen, list = {}, {}
  local function push(x, y)
    local k = tkey(x, y)
    if seen[k] or bl[k] then return end
    seen[k] = true
    list[#list + 1] = { x, y }
  end
  for x = x0, x1 do push(x, y0) push(x, y1) end
  for y = y0 + 1, y1 - 1 do push(x0, y) push(x1, y) end
  local i = 1
  while i <= #list do
    local c = list[i]
    i = i + 1
    for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
      local nx, ny = c[1] + d[1], c[2] + d[2]
      if nx >= x0 and nx <= x1 and ny >= y0 and ny <= y1 then push(nx, ny) end
    end
  end
  return function(p) return seen[tkey(math.floor(p.x), math.floor(p.y))] == true end, #list
end

return function(rule)
  local TAG = "ETAGE5-COULOIR" .. (rule and "" or "-TEMOIN")
  return {
    description = "ETAGE 5 : PNJ a l'acces d'un avant-poste de charbon agrandi, couloir " .. (rule and "ALLUME" or "COUPE (temoin)"),
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
      inv.insert({ name = "coal", count = 200 })
      local v = ctx.remote("fo-ia1", "set_regle_couloir", "player", rule)
      ctx.check(v == rule, "interrupteur du couloir : " .. (rule and "allume" or "coupe"), tostring(v))
      -- accès côté QG, sur le gisement (bord ouest, à 6 tuiles du centre), au centre d'une tuile
      st.cc, st.hq, st.acc = cc, hq, { x = cc.x - 6 + 0.5, y = cc.y + 0.5 }
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.cc or e.tick ~= W0 then return end
      local s = ctx.surface()
      local chars = s.find_entities_filtered({ type = "character", force = "player" })
      table.sort(chars, function(a, b) return (a.unit_number or 0) < (b.unit_number or 0) end)
      local npc = chars[1]
      ctx.check(npc ~= nil, "un PNJ de l'equipe", tostring(#chars) .. " personnage(s)")
      if not npc then return end
      npc.teleport(st.acc)
      local o = ctx.remote("fo-ia1", "bench_outpost", "player", "coal", st.cc.x, st.cc.y, st.acc.x, st.acc.y)
      ctx.check(o ~= nil, "avant-poste de charbon pose, acces ecrit", o and (o.drills .. " foreuse(s)") or "nil")
      if not o then return end
      local drills = ctx.remote("fo-ia1", "bench_extend", "player", o.id, 20)
      st.npc, st.oid, st.drills = npc, o.id, drills or 0
      local ok_at, reached = reach(s, st.cc)
      st.acc_w0, st.npc_w0 = ok_at(st.acc), ok_at(npc.position)
      st.npc_p0 = { x = npc.position.x, y = npc.position.y }
      ctx.log(string.format("[FO-%s] W0 : avant-poste %d, %d foreuse(s) apres 20 agrandissements ; PNJ %d en (%.1f, %.1f) ; acces (%.1f, %.1f) %s ; PNJ %s ; %d tuile(s) atteignable(s)",
        TAG, o.id, st.drills, npc.unit_number or 0, npc.position.x, npc.position.y, st.acc.x, st.acc.y, st.acc_w0 and "OUVERT" or "FERME",
        st.npc_w0 and "LIBRE" or "MURE", reached))
    end,

    finish = function(ctx)
      local st = ctx.state()
      if st.acc_w0 == nil then
        ctx.check(false, "la construction a eu lieu", "tick " .. tostring(W0))
        return
      end
      local s = ctx.surface()
      local ok_at = reach(s, st.cc)
      local acc_end = ok_at(st.acc)
      local npc_ok = st.npc and st.npc.valid
      local npc_end = npc_ok and ok_at(st.npc.position) or nil
      local moved = npc_ok and ((st.npc.position.x - st.npc_p0.x) ^ 2 + (st.npc.position.y - st.npc_p0.y) ^ 2) ^ 0.5 or -1
      ctx.log(string.format("[FO-%s] RESULTAT couloir=%s foreuses=%d acces_W0=%s pnj_W0=%s acces_fin=%s pnj_fin=%s pnj_deplace=%.1f",
        TAG, rule and "oui" or "non", st.drills or 0, st.acc_w0 and "ouvert" or "ferme", st.npc_w0 and "libre" or "mure",
        acc_end and "ouvert" or "ferme", npc_end == nil and "?" or (npc_end and "libre" or "mure"), moved))
      ctx.check((st.drills or 0) >= 20, "champ agrandi (au moins 20 foreuses)", tostring(st.drills))
      if rule then
        ctx.check(st.acc_w0 == true and acc_end == true, "couloir : acces ouvert apres les agrandissements et a la fin")
        ctx.check(st.npc_w0 == true and npc_end ~= false, "couloir : PNJ jamais mure")
      else
        ctx.check(st.acc_w0 == false or st.npc_w0 == false, "temoin : le defaut se reproduit (acces ferme ou PNJ mure)",
          string.format("acces %s, PNJ %s", tostring(st.acc_w0), tostring(st.npc_w0)))
      end
    end,
  }
end
