--[[
  EFFONDREMENT, banc comparé de la PARADE DU KIT OFFERT (décision du lead, 7/11 vers 19 h 05) : recrue au kit offert contre recrue
  payée, et temps de remontée du fer de votre équipe sous son effectif de départ (demande du lead, 7/11 vers 19 h 25 : comparé à
  0102eb36, d'avant le retrait du minage d'urgence pour le kit). Critères ÉCRITS AVANT : fo-logs/2026-11-05_EFFONDREMENT/CRITERES.md,
  « Banc comparé de la parade du kit ».
  Mise en place (comme recrue-gratuite) : effectif de départ 12, coffre d'équipe sans fer, sans pierre, sans pistolet ; cuivre 500,
  charbon 200, 194 chargeurs.
    tick 120 : 3 minerais de fer dans chacune des 10 victimes, puis 10 PNJ de départ (kit offert) tués ; S1 au tick 150 ;
    120 à 3 120 : campeur (chaque recrue nouvelle reçoit 2 minerais, meurt 600 ticks après son apparition) ; fer au coffre relevé
      toutes les 300 ticks (MESURE, hors bilan) ; S2 au tick 3 120 ;
    3 120 : 2 000 plaques de fer et 5 pistolets au coffre ; la première recrue vue à 13 personnages ou plus (payée : recrue de
      croissance) meurt 300 ticks après son apparition ; S3 : son corps.
  temoin = true : le kit RESTE dans les corps (0102eb36, avant la parade).
  Lancement (par la file) : banc.py --out <archive> --qui EFFONDREMENT -- 9600 recrue-kit <source> (recrue-kit-temoin sur 0102eb36).
]]

local KILL, S1_AT, CAMP_END = 120, 150, 3120
local CHECK = 9500
local PAID_MAX = 9000
local START, LEFT = 12, 2
local GUN, AMMO, ORE = "pistol", "firearm-magazine", "iron-ore"

local function chest_of(ctx)
  return ctx.surface().find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
end

local function team(ctx)
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key == "player" then return r end
  end
  return nil
end

--- PNJ de votre équipe (personnages de la force du joueur sans joueur), triés par numéro d'unité, toute la surface.
local function workers(ctx)
  local list = {}
  for _, c in ipairs(ctx.surface().find_entities_filtered({ type = "character", force = "player" })) do
    if c.valid and not c.player then list[#list + 1] = c end
  end
  table.sort(list, function(a, b) return (a.unit_number or 0) < (b.unit_number or 0) end)
  return list
end

--- Corps morts dans [t0, t1] : { n, gun, ammo, ore, per = { {gun, ammo, ore} } }.
local function corpses(ctx, t0, t1)
  local out = { n = 0, gun = 0, ammo = 0, ore = 0, per = {} }
  for _, c in ipairs(ctx.surface().find_entities_filtered({ type = "character-corpse" })) do
    local td = c.valid and c.character_corpse_tick_of_death
    if td and td >= t0 and td <= t1 then
      local inv = c.get_inventory(defines.inventory.character_corpse)
      local g, a, o = inv.get_item_count(GUN), inv.get_item_count(AMMO), inv.get_item_count(ORE)
      out.n, out.gun, out.ammo, out.ore = out.n + 1, out.gun + g, out.ammo + a, out.ore + o
      out.per[#out.per + 1] = { g, a, o }
    end
  end
  return out
end

local function text(c)
  return string.format("%d corps, pistolets %d, chargeurs %d, minerai %d", c.n, c.gun, c.ammo, c.ore)
end

local function iron_in(inv)
  return inv.get_item_count(ORE), inv.get_item_count("iron-plate")
end

return function(temoin)
  local TAG = temoin and "RECRUE-KIT-TEMOIN" or "RECRUE-KIT"
  return {
    description = "EFFONDREMENT : kit offert retire du corps (recrue de depart et recrue gratuite) contre recrue payee ; fer sous l'effectif de depart" ..
      (temoin and " (temoin 0102eb36 : kit laisse)" or ""),
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local st = ctx.state()
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", START) == START, "effectif de depart " .. START)
      local s = ctx.surface()
      local c0 = game.forces.player.get_spawn_position(s)
      local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
      local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      if not chest then return end
      local inv = chest.get_inventory(defines.inventory.chest)
      for _, it in ipairs({ "iron-plate", ORE, "stone", GUN, "iron-gear-wheel" }) do inv.remove({ name = it, count = 100000 }) end
      inv.insert({ name = "copper-plate", count = 500 })
      inv.insert({ name = "coal", count = 200 })
      inv.insert({ name = AMMO, count = 194 })
      local r = team(ctx)
      ctx.check(r ~= nil and r.n == START, "equipe creee a " .. START .. " PNJ", tostring(r and r.n))
      st.ok = true
      st.seen, st.kills, st.camp_dead = {}, 0, 0
      st.iron_first, st.iron_series = nil, {}
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.ok then return end
      local t = e.tick
      local chest = chest_of(ctx)
      if not chest then return end
      local inv = chest.get_inventory(defines.inventory.chest)
      if t == KILL then
        for _, it in ipairs({ "iron-plate", ORE, GUN }) do inv.remove({ name = it, count = 100000 }) end
        local list = workers(ctx)
        st.initial = {}
        for _, c in ipairs(list) do st.initial[c.unit_number or 0] = true end
        local killed = 0
        for i = #list, LEFT + 1, -1 do
          list[i].get_main_inventory().insert({ name = ORE, count = 3 })
          list[i].die()
          killed = killed + 1
        end
        st.killed, st.n0 = killed, #list - killed
        ctx.log(string.format("[FO-%s] mise a mort au tick %d : %d PNJ tues (3 minerais chacun), effectif %d", TAG, t, killed, st.n0))
        return
      end
      if t == S1_AT then
        st.s1 = corpses(ctx, KILL, KILL)
        ctx.log(string.format("[FO-%s] S1 (morts au tick %d) : %s", TAG, KILL, text(st.s1)))
      end
      -- campeur : chaque recrue nouvelle reçoit 2 minerais et meurt 600 ticks après son apparition
      if t > KILL and t < CAMP_END then
        for _, c in ipairs(workers(ctx)) do
          local u = c.unit_number or 0
          if not st.initial[u] then
            if not st.seen[u] then
              st.seen[u] = t
            elseif t - st.seen[u] >= 600 then
              c.get_main_inventory().insert({ name = ORE, count = 2 })
              c.die()
              st.kills = st.kills + 1
              ctx.log(string.format("[FO-%s] campeur : recrue %d tuee au tick %d (%d ticks apres son apparition)", TAG, u, t, t - st.seen[u]))
            end
          end
        end
      end
      -- fer au coffre sous l'effectif de départ (MESURE)
      if t > KILL and t <= CAMP_END and (t - KILL) % 300 == 0 then
        local o, pl = iron_in(inv)
        st.iron_series[#st.iron_series + 1] = string.format("+%d:%d/%d", t - KILL, o, pl)
        if not st.iron_first and o + pl > 0 then st.iron_first = t - KILL end
        if t == CAMP_END then st.iron_end = { ore = o, plate = pl } end
      end
      if t == CAMP_END then
        -- le minerai posé par le banc dans les recrues tuées est dans leurs corps, pas au coffre : il ne compte pas
        st.s2 = corpses(ctx, KILL + 1, CAMP_END)
        ctx.log(string.format("[FO-%s] S2 (recrues du campeur, %d tuee(s)) : %s", TAG, st.kills, text(st.s2)))
        ctx.log(string.format("[FO-%s] FER sous l'effectif de depart (minerai/plaques au coffre, toutes les 300 ticks) : %s ; premier fer a +%s ticks ; fin %s/%s",
          TAG, table.concat(st.iron_series, " "), tostring(st.iron_first), tostring(st.iron_end and st.iron_end.ore), tostring(st.iron_end and st.iron_end.plate)))
        inv.insert({ name = "iron-plate", count = 2000 })
        inv.insert({ name = GUN, count = 5 })
        st.after = {}
        for _, c in ipairs(workers(ctx)) do st.after[c.unit_number or 0] = true end
      end
      -- recrue payée : la première vue à 13 personnages ou plus meurt 300 ticks après son apparition
      if t > CAMP_END and not st.paid_dead then
        local list = workers(ctx)
        if not st.paid and #list >= START + 1 then
          -- les recrues gratuites qui rendent l'effectif de 12 sont dans st.after (vues à 12 personnages ou moins) : la nouvelle à 13 est
          -- la recrue de croissance, payée (plus grand numéro d'unité hors de st.after)
          local best = nil
          for _, c in ipairs(list) do
            local u = c.unit_number or 0
            if not st.after[u] and (not best or u > best) then best = u end
          end
          if best then
            st.paid = { unit = best, at = t, n = #list }
            ctx.log(string.format("[FO-%s] recrue payee vue au tick %d : unite %d, %d personnages", TAG, t, best, #list))
          end
        end
        if st.paid and t - st.paid.at >= 300 then
          for _, c in ipairs(list) do
            if (c.unit_number or 0) == st.paid.unit then
              st.paid_dead = t
              c.die()
              ctx.log(string.format("[FO-%s] recrue payee %d tuee au tick %d", TAG, st.paid.unit, t))
            end
          end
          if not st.paid_dead then st.paid_dead = -1 end
        end
      end
      if st.paid_dead and st.paid_dead > 0 and t == st.paid_dead + 30 then
        st.s3 = corpses(ctx, st.paid_dead, st.paid_dead)
        ctx.log(string.format("[FO-%s] S3 (recrue payee) : %s", TAG, text(st.s3)))
      end
      -- après S2, les recrues gratuites qui rendent l'effectif ne sont pas des recrues payées : elles entrent dans st.after à leur arrivée
      if t > CAMP_END and not st.paid then
        local list = workers(ctx)
        if #list <= START then
          for _, c in ipairs(list) do st.after[c.unit_number or 0] = true end
        end
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      ctx.check(st.killed == START - LEFT and st.n0 == LEFT, "10 PNJ tues au tick 120, il en reste 2",
        string.format("%s tues, effectif %s", tostring(st.killed), tostring(st.n0)))
      local s1, s2, s3 = st.s1 or { n = 0, gun = 0, ammo = 0, ore = 0, per = {} }, st.s2 or { n = 0, gun = 0, ammo = 0, ore = 0, per = {} }, st.s3
      local ore_each = true
      for _, x in ipairs(s2.per) do if x[3] < 2 then ore_each = false end end
      if temoin then
        ctx.check(s1.n == 10 and s1.gun == 10 and s1.ammo == 100 and s1.ore >= 30,
          "temoin S1 : 10 corps, le kit y RESTE (10 pistolets, 100 chargeurs), au moins 30 minerais", text(s1))
        ctx.check(s2.n >= 1 and s2.gun == s2.n and s2.ammo == 10 * s2.n and ore_each,
          "temoin S2 : au moins 1 recrue du campeur ; le kit RESTE dans ses corps ; au moins 2 minerais par corps", text(s2))
      else
        ctx.check(s1.n == 10 and s1.gun == 0 and s1.ammo == 0 and s1.ore >= 30,
          "S1 : 10 corps, ni pistolet ni chargeur, au moins 30 minerais (cargaison gardee)", text(s1))
        ctx.check(s2.n >= 1 and s2.gun == 0 and s2.ammo == 0 and ore_each,
          "S2 : au moins 1 recrue gratuite du campeur ; ni pistolet ni chargeur dans ses corps ; au moins 2 minerais par corps", text(s2))
      end
      ctx.check(st.paid ~= nil and st.paid.at <= PAID_MAX, "une recrue payee (13 personnages ou plus) avant le tick " .. PAID_MAX,
        st.paid and string.format("tick %d, unite %d", st.paid.at, st.paid.unit) or "aucune")
      ctx.check(s3 ~= nil and s3.n == 1 and s3.gun == 1 and s3.ammo >= 10, "S3 : le corps de la recrue payee garde pistolet 1 et au moins 10 chargeurs",
        s3 and text(s3) or "pas de releve")
      ctx.log(string.format("[FO-%s] RESULTAT S1 {%s} S2 {%s} S3 {%s} campeur %d ; fer premier +%s fin %s/%s", TAG, text(s1), text(s2),
        s3 and text(s3) or "-", st.kills or 0, tostring(st.iron_first), tostring(st.iron_end and st.iron_end.ore), tostring(st.iron_end and st.iron_end.plate)))
    end,
  }
end
