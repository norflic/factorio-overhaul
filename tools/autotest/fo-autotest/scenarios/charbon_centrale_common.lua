--[[
  Lot COMBUSTIBLE-CENTRALE (levier a, 9/11) : MICRO-BANC en moteur réel. Mesure du défaut : le coffre du QG n'a PLUS de charbon, la centrale
  (coffre de quai -> inserter à combustion -> chaudière -> machine à vapeur -> 4 radars) est à sec, et un avant-poste de charbon à 40 tuiles tient
  300 charbons dans chacun de ses coffres de sortie. Avant le levier, Cc.refill rend `short` (« coffre du QG sans charbon ») : aucune tâche, la
  centrale reste à sec. Avec lui, un PNJ prend au tampon et remplit le coffre de la centrale (tâche urgente, programme take_depot).
  Tout est RÉEL sauf deux accessoires du banc, déclarés : la fourniture d'eau de la chaudière (l'amenée de tuyaux n'est pas l'objet) et le
  projet de centrale (fo-ia1d bench_plant : pièces réelles, coffre de quai déclaré). Critères lus en FONCTION :
    - charbon reçu par le coffre de la centrale (sauts positifs du compteur du coffre), premier reçu (secondes) ;
    - secondes où la chaudière est « no_fuel » sous charge (échantillon toutes les 10 ticks) ; secondes de courant produit ;
    - charbon restant au tampon (il garde Cc.BUFFER_KEEP) ; charbon du coffre du QG (doit rester 0 : sinon un PNJ a miné à la main).
  Variante témoin (`temoin`) : la règle est COUPÉE (remote fo-ia1d set_option no_tampon) : comportement avant le levier.
  Lancement : banc.py --out <archive> --qui combustible -- 4800 charbon-centrale <source>   (témoin : charbon-centrale-temoin)
  Journal : [FO-CHARBON-CENTRALE-BANC] ; ligne RESULTAT en clé=valeur ; BILAN automatique.
]]

local MIN = 3600
local T0 = 60
local WINDOW = 4600
local CHECK = T0 + WINDOW + 100
local STEP = 10
local PER_SINK = 300

local function patch(s, name, c, r, amount)
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

return function(rule)
  local TAG = "[FO-CHARBON-CENTRALE-BANC" .. (rule and "" or "-TEMOIN") .. "] "
  return {
    description = "COMBUSTIBLE-CENTRALE levier a : coffre du QG sans charbon, centrale a sec, tampon d'un avant-poste de charbon, regle "
      .. (rule and "ALLUMEE" or "COUPEE (temoin)"),
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local s = ctx.surface()
      local st = ctx.state()
      ctx.prepare_area(-90, -70, 100, 60, "grass-1")
      ctx.check(ctx.call("war_setting", "fo-war-ia3e", false) == false, "reglage fo-war-ia3e coupe (le banc est le cerveau)")
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
      local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      if not chest then return end
      chest.insert({ name = "iron-plate", count = 2000 }) -- AUCUN charbon au QG
      st.hq = chest
      ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 4 }) == true, "plan directeur active")
      if not rule then
        ctx.check(ctx.remote("fo-ia1d", "set_option", "player", "no_tampon", true) == true, "regle du tampon COUPEE (temoin)")
      end
      -- gisement + avant-poste de charbon a 40 tuiles a l'ouest
      local cc = { x = -40, y = 8 }
      local n_c = patch(s, "coal", cc, 9, 20000)
      local o = ctx.remote("fo-ia1", "bench_outpost", "player", "coal", cc.x, cc.y)
      ctx.check(o ~= nil and o.drills >= 3 and o.sinks >= 1, "avant-poste de charbon pose", o and string.format("%d foreuse(s), %d coffre(s) de sortie, gisement %d tuiles", o.drills, o.sinks, n_c) or "nil")
      st.cc = cc
      -- centrale reelle : chaudiere (nord), machine a vapeur au nord d'elle, coffre de quai + inserter a combustion au sud, 4 radars de charge
      local bx, by = 30.5, -20
      local boiler = s.create_entity({ name = "boiler", position = { bx, by }, direction = defines.direction.north, force = "player" })
      local engine = s.create_entity({ name = "steam-engine", position = { bx, by - 3.5 }, direction = defines.direction.north, force = "player" })
      local quai = s.create_entity({ name = "iron-chest", position = { bx, by + 2.5 }, force = "player" })
      local ins = s.create_entity({ name = "burner-inserter", position = { bx, by + 1.5 }, direction = defines.direction.north, force = "player" })
      local pole = s.create_entity({ name = "medium-electric-pole", position = { bx + 3, by - 3.5 }, force = "player" })
      local radars = 0
      for _, off in ipairs({ { 7, -3.5 }, { 7, -7.5 }, { 7, 0.5 }, { 3, -7.5 } }) do
        if s.create_entity({ name = "radar", position = { bx + off[1], by + off[2] }, force = "player" }) then radars = radars + 1 end
      end
      ctx.check(boiler and engine and quai and ins and pole and radars == 4, "centrale reelle posee (chaudiere, machine, coffre, inserter, poteau, 4 radars)",
        string.format("%s %s %s %s %s %d", tostring(boiler ~= nil), tostring(engine ~= nil), tostring(quai ~= nil), tostring(ins ~= nil), tostring(pole ~= nil), radars))
      if not (boiler and engine and quai and ins) then return end
      -- le banc ne s'occupe pas de la geometrie de l'inserter : ramassage au coffre, depot a la chaudiere
      ins.pickup_position = { bx, by + 2.5 }
      ins.drop_position = { bx, by + 0.5 }
      ins.insert({ name = "coal", count = 1 }) -- amorce de l'inserter a combustion
      quai.insert({ name = "coal", count = 8 })
      st.boiler, st.engine, st.quai = boiler, engine, quai
      local id = ctx.remote("fo-ia1d", "bench_plant", "player", {
        { name = "boiler", x = boiler.position.x, y = boiler.position.y },
        { name = "steam-engine", x = engine.position.x, y = engine.position.y },
      }, "steam", { { x = quai.position.x, y = quai.position.y, item = "coal" } })
      ctx.check(id ~= nil, "projet de centrale (pieces reelles) declare", tostring(id))
      st.pid = id
      st.q_prev, st.recv, st.first_recv, st.dry, st.power, st.samples, st.hq_coal_max = 0, 0, nil, 0, 0, 0, 0
      boiler.fluidbox[1] = { name = "water", amount = 200 }
      st.ready = true
      ctx.log(TAG .. string.format("depart : QG sans charbon, centrale en (%.1f, %.1f), coffre de quai a 8 charbons, avant-poste %s en (%d, %d)", bx, by, tostring(o and o.id), cc.x, cc.y))
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.ready then return end
      local t = e.tick
      if t % 30 == 0 and st.boiler.valid then st.boiler.fluidbox[1] = { name = "water", amount = 200 } end -- accessoire declare : l'eau
      if t == 1 then
        -- charbon des coffres de sortie de l'avant-poste : l'etat du DC (des centaines de charbons que la tournee n'a pas ramasses)
        st.sinks = ctx.surface().find_entities_filtered({ name = "iron-chest", force = "player", position = st.cc, radius = 18 })
        for _, c in ipairs(st.sinks) do
          local inv = c.get_inventory(defines.inventory.chest)
          inv.clear()
          inv.insert({ name = "coal", count = PER_SINK })
        end
        st.sink0 = #st.sinks * PER_SINK
        ctx.log(TAG .. string.format("tick 1 : %d coffre(s) de sortie a %d charbons (tampon %d)", #st.sinks, PER_SINK, st.sink0))
      end
      if t < T0 or t > T0 + WINDOW or t % STEP ~= 0 then return end
      st.samples = st.samples + 1
      local n = st.quai.valid and st.quai.get_item_count("coal") or 0
      if n - st.q_prev >= 10 then
        st.recv = st.recv + (n - st.q_prev)
        if not st.first_recv then st.first_recv = t end
      end
      st.q_prev = n
      if st.boiler.valid and st.boiler.status == defines.entity_status.no_fuel then st.dry = st.dry + 1 end
      if st.engine.valid and st.engine.energy_generated_last_tick > 0 then st.power = st.power + 1 end
      local hqc = st.hq.valid and st.hq.get_item_count("coal") or 0
      if hqc > st.hq_coal_max then st.hq_coal_max = hqc end
      if (t - T0) % MIN == 0 then
        local sink = 0
        for _, c in ipairs(st.sinks or {}) do if c.valid then sink = sink + c.get_item_count("coal") end end
        ctx.log(TAG .. string.format("minute %d | coffre de la centrale %d | recu %d | chaudiere a sec %.0f s | courant %.0f s | tampon %d | QG %d",
          math.floor((t - T0) / MIN), n, st.recv, st.dry * STEP / 60, st.power * STEP / 60, sink, hqc))
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      if not st.ready then
        ctx.check(false, "le banc est pret", "init incomplet")
        return
      end
      local sink = 0
      for _, c in ipairs(st.sinks or {}) do if c.valid then sink = sink + c.get_item_count("coal") end end
      local n = st.quai.valid and st.quai.get_item_count("coal") or 0
      ctx.log(TAG .. string.format("RESULTAT regle=%s recu=%d premier_s=%.1f chaudiere_a_sec_s=%.1f courant_s=%.1f coffre_fin=%d tampon_depart=%d tampon_fin=%d qg_charbon_max=%d echantillons=%d",
        rule and "allumee" or "coupee", st.recv, st.first_recv and (st.first_recv - T0) / 60 or -1, st.dry * STEP / 60, st.power * STEP / 60, n, st.sink0 or 0, sink,
        st.hq_coal_max, st.samples))
      ctx.check(st.samples >= WINDOW / STEP - 2, "la fenetre complete est echantillonnee", tostring(st.samples))
      ctx.check(st.hq_coal_max == 0, "le coffre du QG est reste SANS charbon (aucun PNJ n'y a rapporte de charbon)", tostring(st.hq_coal_max))
      if rule then
        ctx.check(st.recv >= 100, "le coffre de la centrale a RECU du charbon du tampon", tostring(st.recv))
        ctx.check(sink >= 60 * #st.sinks - 1 and sink < (st.sink0 or 0), "le tampon a fourni du charbon et en garde pour ses bruleurs", string.format("%d -> %d", st.sink0 or 0, sink))
        ctx.check(st.dry * STEP / 60 < 60, "la chaudiere n'est pas restee a sec plus d'une minute", string.format("%.1f s", st.dry * STEP / 60))
      else
        ctx.check(st.recv == 0, "(temoin) le coffre de la centrale n'a rien recu", tostring(st.recv))
        ctx.check(st.dry * STEP / 60 > 60, "(temoin) la chaudiere reste a sec", string.format("%.1f s", st.dry * STEP / 60))
      end
    end,
  }
end
