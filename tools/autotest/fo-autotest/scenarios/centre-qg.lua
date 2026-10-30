--[[
  Lot PD-CENTREQG (D20) : le QG d'une faction est son centre de commandement (script/faction/centre_qg.lua), moteur réel.
  Deux modes, choisis tout seuls :
    - NORMAL (`banc.py ... -- 700 centre-qg <source>`) : la guerre (2 factions) est lancée par la source du lot ; chaque QG
      naît avec son centre de niveau 1 ;
    - MIGRATION (même commande avec `--creation <source 0.6.18>`) : la guerre est lancée par 0.6.18 (aucun centre), la
      sauvegarde est rechargée par la source du lot : on_configuration_changed pose un centre par QG ; contrôle : même
      corps de QG (numéro d'unité) et même coffre qu'à la création.
  Contrôles (tick 100) : centre de niveau 1 relié à chaque QG, indestructible (dégâts refusés par le moteur) et non minable ;
  (tick 150) amélioration du centre de la faction 1 par le chemin de CAPITAL (coffre du QG garni du coût, bâtiments à
  niveaux qui bloqueraient la condition Q16 retirés) : niveau 2, nouveau centre relié et reverrouillé ; (tick 300) QG de la
  faction 2 détruit ; (tick 320) faction éliminée et son centre retiré. Journal : [FO-CENTRE-QG-BANC].
]]

local IFACE = "fo-centre-qg"
local LEVELLED_TYPES = { "ammo-turret", "electric-turret", "wall", "gate", "furnace", "assembling-machine", "mining-drill" }

local function contents_text(inv)
  if not inv then return "?" end
  local c = inv.get_contents()
  local names = {}
  for n in pairs(c) do names[#names + 1] = n end
  table.sort(names)
  local parts = {}
  for _, n in ipairs(names) do parts[#parts + 1] = n .. "=" .. c[n] end
  return table.concat(parts, ",")
end

local function hqs(s)
  local out = {}
  for _, e in ipairs(s.find_entities_filtered({ name = "fo-faction-hq" })) do
    out[#out + 1] = { force = e.force.name, unit = e.unit_number, chest = contents_text(e.get_inventory(defines.inventory.chest)) }
  end
  table.sort(out, function(a, b) return a.force < b.force end)
  return out
end

local function status()
  if not remote.interfaces[IFACE] then return {} end
  return remote.call(IFACE, "status") or {}
end

script.on_configuration_changed(function(data)
  local c = data.mod_changes and data.mod_changes["factorio-overhaul"]
  global.cqg_config = { tick = game.tick, old = c and c.old_version, new = c and c.new_version,
    hqs = hqs(game.surfaces[1]) }
  log("[FO-CENTRE-QG-BANC] on_configuration_changed (tick " .. game.tick .. ") : factorio-overhaul " .. tostring(c and c.old_version)
    .. " -> " .. tostring(c and c.new_version))
end)

return {
  description = "PD-CENTREQG : le QG d'une faction est son centre de commandement (pose, amelioration, elimination, migration)",
  check_tick = 330,

  init = function(ctx)
    local st = ctx.state()
    st.version_create = script.active_mods["factorio-overhaul"]
    st.migration = remote.interfaces[IFACE] == nil
    local started = ctx.call("war_start", 2, 5, 4)
    st.started = started
    st.hqs_create = hqs(ctx.surface())
    ctx.log("creation : factorio-overhaul " .. tostring(st.version_create) .. ", mode " .. (st.migration and "MIGRATION" or "NORMAL")
      .. ", guerre " .. tostring(started) .. ", QG " .. #st.hqs_create)
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == 1 then
      -- Corps et coffres après le chargement (migration par on_configuration_changed OU par la veille du tick 0).
      st.hqs_load = hqs(s)
      st.version_load = script.active_mods["factorio-overhaul"]
    elseif e.tick == 100 then
      st.s100 = status()
      st.dmg = {}
      for _, r in ipairs(st.s100) do
        local c = r.centre and s.find_entities_filtered({ force = r.force, name = r.name })[1]
        if c then
          local h0 = c.health
          local dealt = c.damage(500, "enemy", "physical")
          st.dmg[#st.dmg + 1] = { key = r.key, dealt = dealt, same = c.health == h0, valid = c.valid }
        end
      end
      ctx.log("tick 100 : " .. serpent.line(st.s100))
    elseif e.tick == 150 and st.s100 and st.s100[1] then
      local r = st.s100[1]
      -- Condition Q16 : les bâtiments à niveaux de la faction (tourelles, fours…) bloqueraient le passage 1 -> 2.
      local removed = 0
      for _, x in ipairs(s.find_entities_filtered({ force = r.force, type = LEVELLED_TYPES })) do
        x.destroy()
        removed = removed + 1
      end
      local pv = remote.call(IFACE, "preview", r.key) or {}
      local hq = s.find_entities_filtered({ force = r.force, name = "fo-faction-hq" })[1]
      local put = 0
      for _, c in ipairs(pv.cost or {}) do put = put + hq.insert({ name = c[1], count = c[2] }) end
      st.chest_before = contents_text(hq.get_inventory(defines.inventory.chest))
      local ok, why = remote.call(IFACE, "upgrade", r.key)
      st.up = { ok = ok, why = why, removed = removed, put = put, pv_reason = pv.reason }
      st.s150 = status()
      st.chest_after = contents_text(hq.get_inventory(defines.inventory.chest))
      ctx.log(string.format("tick 150 : %d batiment(s) a niveaux retires, apercu %s, cout verse %d, amelioration %s (%s) ; %s",
        removed, tostring(pv.reason), put, tostring(ok), tostring(why), serpent.line(st.s150)))
    elseif e.tick == 300 and st.s100 and st.s100[2] then
      local hq = s.find_entities_filtered({ force = st.s100[2].force, name = "fo-faction-hq" })[1]
      if hq then hq.die("enemy") end
    elseif e.tick == 320 and st.s100 and st.s100[2] then
      local r = st.s100[2]
      st.after_kill = { hq = s.count_entities_filtered({ force = r.force, name = "fo-faction-hq" }),
        centres = r.name and s.count_entities_filtered({ force = r.force, name = r.name }) or -1, status = status() }
      ctx.log("tick 320 : " .. serpent.line(st.after_kill))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.started == true, "guerre lancee a la creation (" .. tostring(st.version_create) .. ")", tostring(st.started))
    if st.migration then
      local cfg = global.cqg_config
      -- Version montée (0.6.18 -> 0.6.19, comme à l'intégration) : on_configuration_changed est exigé. Version inchangée :
      -- le moteur ne l'appelle PAS toujours (observé ici le 30/10, contre F130) ; la veille du tick 0 relie alors le centre.
      if st.version_load ~= st.version_create then
        ctx.check(cfg ~= nil, "MIGRATION " .. tostring(st.version_create) .. " -> " .. tostring(st.version_load)
          .. " : on_configuration_changed vu au chargement",
          cfg and (tostring(cfg.old) .. " -> " .. tostring(cfg.new) .. " au tick " .. cfg.tick) or "aucun")
      else
        ctx.log("MIGRATION a version egale (" .. tostring(st.version_load) .. ") : on_configuration_changed "
          .. (cfg and "vu" or "NON appele (filet : veille du tick 0)") .. " (hors bilan)")
      end
      local load = st.hqs_load or {}
      local same = #load == #(st.hqs_create or {}) and #load == 2
      for i, h in ipairs(st.hqs_create or {}) do
        local g = load[i]
        if not (g and g.unit == h.unit and g.chest == h.chest) then same = false end
      end
      ctx.check(same, "MIGRATION : memes corps de QG (numero d'unite) et memes coffres qu'a la creation (tick 1)",
        serpent.line({ avant = st.hqs_create, apres = load }))
    end
    local s100 = st.s100 or {}
    ctx.check(#s100 == 2, "2 factions vivantes au tick 100", #s100)
    for _, r in ipairs(s100) do
      ctx.check(r.centre ~= nil and r.linked == r.centre and r.level == 1,
        r.key .. " : centre de commandement de niveau 1 relie au QG", serpent.line(r))
      ctx.check(r.destructible == false and r.minable == false, r.key .. " : centre lie indestructible et non minable", serpent.line(r))
    end
    for _, d in ipairs(st.dmg or {}) do
      ctx.check(d.valid and d.same, d.key .. " : 500 degats refuses par le moteur (sante inchangee)", serpent.line(d))
    end
    local up = st.up or {}
    ctx.check(up.ok == true, "amelioration du centre lie de la faction 1 (chemin de CAPITAL, coffre du QG)", serpent.line(up))
    local r1 = st.s150 and st.s150[1]
    ctx.check(r1 ~= nil and r1.level == 2 and r1.linked == r1.centre and r1.destructible == false and r1.minable == false
      and s100[1] and r1.centre ~= s100[1].centre, "niveau 2 : nouveau centre relie au QG et reverrouille", serpent.line(r1))
    ctx.check(st.chest_before ~= st.chest_after, "cout preleve au coffre du QG", tostring(st.chest_after))
    local k = st.after_kill or {}
    local still = false
    for _, r in ipairs(k.status or {}) do if s100[2] and r.key == s100[2].key then still = true end end
    ctx.check(k.hq == 0 and k.centres == 0 and not still, "QG de la faction 2 detruit : faction eliminee, centre lie retire",
      serpent.line(k))
  end,
}
