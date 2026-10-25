--[[
  Lot IA3-0, expérience E181 (docs/IA3_CERVEAU.md §4.3, §4.6 ; revue m5, m6) : le RÉFLEXE DE LA TOURELLE d'un PNJ.
  Un personnage d'une force sans joueur (« ia3-pnj ») porte 2 mitrailleuses, 40 chargeurs et 5 grenades. Au tick 30,
  8 petits biters naissent à 40 tuiles à l'est et reçoivent l'ordre de l'attaquer. Toutes les 30 ticks, le PNJ cherche
  les ennemis à 24 tuiles (`find_enemy_units`) ; au premier contact il pose une tourelle entre lui et la menace
  (`can_place_entity`, puis `create_entity{raise_built = true}` comme `script/faction/outposts.lua`), la remplit de
  20 chargeurs pris dans son inventaire. Mesures : refus de pose (dont sur la case d'un biter), délai détection →
  premiers dégâts, morts. Menace partie (aucun ennemi à 40 tuiles pendant 10 s) : la tourelle est REPRISE par
  `LuaEntity.mine{inventory = inventaire du PNJ, force = false}` ; on compte ce qui revient (tourelle, chargeurs).
  Témoin au calme (50 tuiles à l'ouest) : reprise dans un inventaire PLEIN (attendu : refus, tourelle en place), puis
  dans un inventaire libre. Grenade : un projectile « grenade » créé par script vers 4 biters immobiles à 45 tuiles au
  sud ; on compte les morts.
  Lancement : `fo-autotest.bat nopause 2500 ia3-tourelle <source>`. Journal : [FO-IA3-TOURELLE].
]]

local X, Y = 216.5, 216.5
local SCAN = 30
local DETECT_R = 24
local CALM_R = 40
local CALM_TICKS = 600
local BITERS = 8
local GREN_GROUP = 4
local GREN_TICK = 240

local function count_items(inv, name) return inv and inv.valid and inv.get_item_count(name) or 0 end

local function unit_dir(dx, dy)
  -- direction par composantes (aucune trigonométrie) : signe de la composante dominante, l'autre réduite.
  local ax, ay = math.abs(dx), math.abs(dy)
  if ax < 1e-6 and ay < 1e-6 then return 1, 0 end
  local m = ax > ay and ax or ay
  return dx / m, dy / m
end

local function find_char(ctx)
  local st = ctx.state()
  if not st.ch then return nil end
  for _, c in ipairs(ctx.surface().find_entities_filtered({ name = "character", force = "ia3-pnj" })) do
    if c.valid and c.unit_number == st.ch then return c end
  end
  return nil
end

local function find_turret(ctx, pos, name)
  if not pos then return nil end
  local t = ctx.surface().find_entities_filtered({ position = pos, radius = 0.6, force = "ia3-pnj", type = "ammo-turret" })
  return t[1]
end

local function alive_near(s, pos, r, name)
  return s.count_entities_filtered({ position = pos, radius = r, name = name, force = "enemy" })
end

return {
  description = "E181 : reflexe de la tourelle d'un PNJ (pose pres de biters, tir, reprise par mine, grenade par script)",
  check_tick = 2400,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(X - 64, Y - 24, X + 64, Y + 56, "grass-1")
    local f = game.create_force("ia3-pnj")
    st.hostile = tostring(not f.get_friend("enemy") and not f.get_cease_fire("enemy") and not game.forces.enemy.get_cease_fire(f))
    local ch = s.create_entity({ name = "character", position = { X, Y }, force = f })
    ctx.check(ch ~= nil, "PNJ (personnage d'une force sans joueur) cree")
    if not ch then return end
    st.ch = ch.unit_number
    local inv = ch.get_main_inventory()
    inv.insert({ name = "gun-turret", count = 2 })
    inv.insert({ name = "firearm-magazine", count = 40 })
    inv.insert({ name = "grenade", count = 5 })
    st.inv0 = string.format("tourelles %d, chargeurs %d, grenades %d", count_items(inv, "gun-turret"),
      count_items(inv, "firearm-magazine"), count_items(inv, "grenade"))
    local t2 = s.create_entity({ name = "gun-turret", position = { X - 50, Y }, force = f, raise_built = true })
    if t2 and t2.valid then
      t2.insert({ name = "firearm-magazine", count = 10 })
      st.t2 = { x = t2.position.x, y = t2.position.y }
      st.t2name = t2.name
    end
    ctx.check(st.t2 ~= nil, "tourelle temoin posee par script (raise_built), au calme", st.t2name)
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    local t = e.tick
    local f = game.forces["ia3-pnj"]
    if not f then return end
    local ch = find_char(ctx)
    if not ch and st.ch and not st.ch_dead then st.ch_dead = t end

    -- Biters : 8 attaquants à l'est, 4 immobiles au sud (cible de la grenade).
    if t >= 30 and not st.spawned then
      st.spawned = t
      local group = s.create_unit_group({ position = { X + 40, Y }, force = "enemy" })
      local n = 0
      for i = 1, BITERS do
        local p = s.find_non_colliding_position("small-biter", { X + 40, Y - 4 + i }, 6, 0.5)
        local b = p and s.create_entity({ name = "small-biter", position = p, force = "enemy" })
        if b then group.add_member(b); n = n + 1 end
      end
      st.biters = n
      if ch then group.set_command({ type = defines.command.attack, target = ch, distraction = defines.distraction.by_enemy }) end
      local m = 0
      for i = 1, GREN_GROUP do
        local p = s.find_non_colliding_position("small-biter", { X - 2 + i, Y + 45 }, 4, 0.5)
        local b = p and s.create_entity({ name = "small-biter", position = p, force = "enemy" })
        if b then
          b.set_command({ type = defines.command.stop, ticks_to_wait = 3600, distraction = defines.distraction.none })
          m = m + 1
        end
      end
      st.idle = m
    end

    -- Témoin au calme : reprise dans un inventaire plein, puis libre.
    if t == 100 and st.t2 then
      local t2 = find_turret(ctx, st.t2)
      if t2 then
        local full = game.create_inventory(1)
        full.insert({ name = "stone", count = 50 })
        st.t2_full_ok = tostring(t2.mine({ inventory = full, force = false }))
        st.t2_full_valid = tostring(t2.valid)
        full.destroy()
        if t2.valid then
          local room = game.create_inventory(10)
          st.t2_room_ok = tostring(t2.mine({ inventory = room, force = false }))
          st.t2_room_valid = tostring(t2.valid)
          st.t2_back = count_items(room, "gun-turret")
          st.t2_ammo = count_items(room, "firearm-magazine")
          room.destroy()
        end
      end
    end

    -- Grenade lancée par script vers le groupe immobile.
    if t == GREN_TICK and st.spawned then
      local idle = s.find_entities_filtered({ position = { X, Y + 45 }, radius = 8, name = "small-biter", force = "enemy" })
      local cx, cy = 0, 0
      for _, b in ipairs(idle) do cx = cx + b.position.x; cy = cy + b.position.y end
      if #idle > 0 then
        cx, cy = cx / #idle, cy / #idle
        st.gren_before = #idle
        st.gren_target = { x = cx, y = cy }
        local ok, proj = pcall(function()
          return s.create_entity({ name = "grenade", position = { X, Y + 30 }, target = { cx, cy }, speed = 0.3, force = f,
            source = ch })
        end)
        st.gren_created = ok and proj ~= nil and "oui" or ("non : " .. tostring(proj))
        if ok and proj and ch then ch.get_main_inventory().remove({ name = "grenade", count = 1 }) end
      end
    end
    if st.gren_target and t == GREN_TICK + 120 then
      st.gren_after = alive_near(s, st.gren_target, 8, "small-biter")
    end

    if not ch then return end
    local inv = ch.get_main_inventory()

    -- Réflexe : regard toutes les 30 ticks pendant l'expédition.
    if t % SCAN == 0 and st.spawned and not st.placed then
      local enemies = s.find_enemy_units(ch.position, DETECT_R, f)
      if #enemies > 0 then
        st.detect = st.detect or t
        local near, nd
        for _, u in ipairs(enemies) do
          local dx, dy = u.position.x - ch.position.x, u.position.y - ch.position.y
          local d = dx * dx + dy * dy
          if not nd or d < nd then near, nd = u, d end
        end
        st.detect_dist = math.floor(math.sqrt(nd) * 10 + 0.5) / 10
        st.on_biter = tostring(s.can_place_entity({ name = "gun-turret", position = near.position, force = f }))
        local ux, uy = unit_dir(near.position.x - ch.position.x, near.position.y - ch.position.y)
        local refused, pos = 0, nil
        for _, k in ipairs({ 3, 4, 5 }) do
          for _, lat in ipairs({ 0, 2, -2 }) do
            local p = { x = math.floor(ch.position.x + ux * k - uy * lat) + 0.5, y = math.floor(ch.position.y + uy * k + ux * lat) + 0.5 }
            if not pos then
              if s.can_place_entity({ name = "gun-turret", position = p, force = f }) then pos = p else refused = refused + 1 end
            end
          end
        end
        st.refused = refused
        if pos then
          local tur = s.create_entity({ name = "gun-turret", position = pos, force = f, raise_built = true })
          if tur and tur.valid then
            inv.remove({ name = "gun-turret", count = 1 })
            local put = tur.insert({ name = "firearm-magazine", count = 20 })
            inv.remove({ name = "firearm-magazine", count = put })
            st.placed = t
            st.tpos = { x = tur.position.x, y = tur.position.y }
            st.tname = tur.name
            st.tput = put
          else
            st.place_fail = "create_entity a rendu nil (raise_built)"
          end
        end
      end
    end

    -- Premiers dégâts de la tourelle posée.
    if st.placed and not st.first_dmg then
      local tur = find_turret(ctx, st.tpos)
      if tur and tur.damage_dealt and tur.damage_dealt > 0 then st.first_dmg = t end
    end

    -- Menace partie : reprise.
    if st.placed and not st.mined and t % SCAN == 0 then
      if #s.find_enemy_units(ch.position, CALM_R, f) == 0 then
        st.calm_since = st.calm_since or t
      else
        st.calm_since = nil
      end
      if st.calm_since and t - st.calm_since >= CALM_TICKS then
        local tur = find_turret(ctx, st.tpos)
        if tur then
          st.kills = tur.kills
          st.dealt = math.floor(tur.damage_dealt)
          st.t_health = math.floor(tur.health)
          local ammo_in = tur.get_inventory(defines.inventory.turret_ammo).get_item_count("firearm-magazine")
          local before_t, before_a = count_items(inv, "gun-turret"), count_items(inv, "firearm-magazine")
          st.mine_ok = tostring(tur.mine({ inventory = inv, force = false }))
          st.mine_valid = tostring(tur.valid)
          st.mine_turret = count_items(inv, "gun-turret") - before_t
          st.mine_ammo = count_items(inv, "firearm-magazine") - before_a
          st.ammo_in = ammo_in
          st.mined = t
        else
          st.mined = t
          st.mine_ok = "tourelle introuvable (detruite ?)"
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local ch = find_char(ctx)
    ctx.log("FAIT force sans joueur hostile aux biters par defaut : " .. tostring(st.hostile))
    ctx.log("FAIT inventaire de depart du PNJ : " .. tostring(st.inv0))
    ctx.log(string.format("FAIT biters : %s attaquants nes au tick %s, %s immobiles ; detection au tick %s a %s tuiles",
      tostring(st.biters), tostring(st.spawned), tostring(st.idle), tostring(st.detect), tostring(st.detect_dist)))
    ctx.log(string.format("FAIT can_place_entity sur la case du biter le plus proche : %s ; cases refusees avant la pose : %s",
      tostring(st.on_biter), tostring(st.refused)))
    ctx.log(string.format("FAIT tourelle posee au tick %s (%s, %s chargeurs) ; premiers degats au tick %s (delai detection -> degats %s ticks) ; %s",
      tostring(st.placed), tostring(st.tname), tostring(st.tput), tostring(st.first_dmg),
      (st.first_dmg and st.detect) and tostring(st.first_dmg - st.detect) or "?", tostring(st.place_fail or "")))
    ctx.log(string.format("FAIT reprise au tick %s : mine = %s, tourelle encore la %s ; revenus : tourelle %s, chargeurs %s (chargeurs dans la tourelle avant : %s) ; tues %s, degats %s, sante %s",
      tostring(st.mined), tostring(st.mine_ok), tostring(st.mine_valid), tostring(st.mine_turret), tostring(st.mine_ammo),
      tostring(st.ammo_in), tostring(st.kills), tostring(st.dealt), tostring(st.t_health)))
    ctx.log(string.format("FAIT temoin : inventaire plein -> mine = %s, tourelle en place %s ; inventaire libre -> mine = %s, tourelle en place %s, revenus tourelle %s chargeurs %s",
      tostring(st.t2_full_ok), tostring(st.t2_full_valid), tostring(st.t2_room_ok), tostring(st.t2_room_valid),
      tostring(st.t2_back), tostring(st.t2_ammo)))
    ctx.log(string.format("FAIT grenade par script : creee %s ; biters immobiles a 8 tuiles de la cible %s -> %s",
      tostring(st.gren_created), tostring(st.gren_before), tostring(st.gren_after)))
    ctx.log(string.format("FAIT PNJ vivant a la fin : %s (mort au tick %s) ; biters attaquants restants a 60 tuiles : %d",
      tostring(ch ~= nil), tostring(st.ch_dead), alive_near(s, { x = X, y = Y }, 60, "small-biter") - (st.gren_after or 0)))
    ctx.check(st.detect ~= nil, "les biters sont vus par find_enemy_units (24 tuiles)", st.detect)
    ctx.check(st.placed ~= nil and st.placed - st.detect <= 1, "tourelle posee dans le meme regard que la detection", st.placed)
    ctx.check(st.first_dmg ~= nil and st.first_dmg - st.detect <= 120, "premiers degats moins de 2 s apres la detection",
      st.first_dmg and (st.first_dmg - st.detect) or "jamais")
    ctx.check(st.mine_ok == "true" and st.mine_turret == 1, "reprise par mine : la tourelle revient dans l'inventaire du PNJ",
      tostring(st.mine_ok) .. " / " .. tostring(st.mine_turret))
    ctx.check(st.ammo_in and st.mine_ammo == st.ammo_in, "reprise : les chargeurs restants reviennent aussi",
      tostring(st.mine_ammo) .. " sur " .. tostring(st.ammo_in))
    ctx.check(st.t2_full_ok == "false" and st.t2_full_valid == "true", "inventaire plein : mine refuse et la tourelle reste")
    ctx.check(st.t2_room_ok == "true" and st.t2_back == 1 and st.t2_ammo == 10, "inventaire libre : tourelle et 10 chargeurs reviennent")
  end,
}
