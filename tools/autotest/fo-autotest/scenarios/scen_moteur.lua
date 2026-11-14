--[[
  s43 scen-moteur : CÂBLAGE EN JEU des scénarios en boucle fermée (format et évaluation : shared/scenarios/format.lua).
  Greffon d'une ligne par scénario : scenarios/scen-<nom>.lua = return require("scenarios/scen_moteur")("<id>")
  (<id> = nom du fichier shared/scenarios/<id>.lua). Banc : banc.py ... -- <F.ticks> scen-<nom> <source>.

  Chaque minute m (tick m * 3600, 1 <= m <= duree_min) : (1) actions de mise en scène de la minute, (2) relevé de chaque
  équipe jugée (fo-ia1 « teams » + moteur), (3) verdict des attendus de la minute. Lignes [FO-SCEN] (format.lua).
  Banc de MESURE et de MISE EN SCÈNE : aucune décision du cerveau n'est touchée ; seules les actions déclarées écrivent dans
  la partie (retrait d'objets, unités ennemies, entités posées ou détruites).
]]

local F = require("__factorio-overhaul__/shared/scenarios/format")

local MIN = F.TICKS_PAR_MIN
local BIG = 2 ^ 31

return function(id)
  local S = require("__factorio-overhaul__/shared/scenarios/" .. id)
  local err = F.valider(S)
  if err then error("shared/scenarios/" .. id .. ".lua : " .. err) end
  local R = S.rayon_qg or 80

  local function hq_of(surface, force)
    return surface.find_entities_filtered({ name = "fo-faction-hq", force = force, limit = 1 })[1]
      or surface.find_entities_filtered({ name = "fo-team-chest", force = force, limit = 1 })[1]
  end

  --- QG et coffres de la force dans le rayon (QG d'abord, puis par position).
  local function chests(surface, force, hq)
    local list = { hq }
    local found = surface.find_entities_filtered({ force = force, type = { "container", "logistic-container" },
      position = hq.position, radius = R })
    table.sort(found, function(a, b)
      if a.position.x ~= b.position.x then return a.position.x < b.position.x end
      return a.position.y < b.position.y
    end)
    for _, e in ipairs(found) do if e.unit_number ~= hq.unit_number then list[#list + 1] = e end end
    return list
  end

  local function by_pos(a, b)
    if a.position.x ~= b.position.x then return a.position.x < b.position.x end
    if a.position.y ~= b.position.y then return a.position.y < b.position.y end
    return (a.unit_number or 0) < (b.unit_number or 0)
  end

  -- Actions de mise en scène : rendent ok, détail.
  local ACT = {}

  function ACT.vider_coffres(a, surface, team, hq)
    local parts = {}
    for _, item in ipairs(a.objets) do
      if not game.item_prototypes[item] then return false, "objet inconnu " .. item end
      local left, removed = a.quantite or BIG, 0
      for _, c in ipairs(chests(surface, team.force, hq)) do
        if left <= 0 then break end
        local n = c.remove_item({ name = item, count = math.min(left, BIG) })
        removed, left = removed + n, left - n
      end
      parts[#parts + 1] = item .. " -" .. removed
    end
    return true, table.concat(parts, ", ")
  end

  function ACT.attaque(a, surface, team, hq, rank, nteams)
    local ang = (rank - 1) * 2 * math.pi / math.max(1, nteams) + 0.7
    local c = { x = hq.position.x + a.distance * math.cos(ang), y = hq.position.y + a.distance * math.sin(ang) }
    local group = surface.create_unit_group({ position = c, force = "enemy" })
    local parts, total = {}, 0
    for _, u in ipairs(a.unites) do
      local name, n = u[1], u[2]
      local p = game.entity_prototypes[name]
      if not (p and p.type == "unit") then return false, "unite inconnue " .. tostring(name) end
      local made = 0
      for _ = 1, n do
        local pos = surface.find_non_colliding_position(name, c, 30, 0.5)
        local e = pos and surface.create_entity({ name = name, position = pos, force = "enemy" })
        if e then group.add_member(e); made = made + 1 end
      end
      parts[#parts + 1] = name .. " x" .. made
      total = total + made
    end
    group.set_command({ type = defines.command.attack_area, destination = hq.position, radius = a.rayon or 16,
      distraction = defines.distraction.by_enemy })
    return total > 0, table.concat(parts, ", ") .. string.format(" depuis (%.0f, %.0f)", c.x, c.y)
  end

  function ACT.poser(a, surface, team, hq)
    if not game.entity_prototypes[a.entite] then return false, "entite inconnue " .. a.entite end
    local force = (a.force == nil or a.force == "equipe") and team.force or a.force
    local made = 0
    for _ = 1, a.n or 1 do
      local pos = surface.find_non_colliding_position(a.entite, { hq.position.x + (a.dx or 0), hq.position.y + (a.dy or 0) }, 30, 1)
      if pos and surface.create_entity({ name = a.entite, position = pos, force = force, raise_built = true }) then made = made + 1 end
    end
    return made > 0, a.entite .. " x" .. made
  end

  function ACT.detruire(a, surface, team, hq)
    local q = { force = team.force, position = hq.position, radius = R }
    if a.nom then q.name = a.nom else q.type = a.type end
    local list = {}
    for _, e in ipairs(surface.find_entities_filtered(q)) do if e.unit_number ~= hq.unit_number then list[#list + 1] = e end end
    table.sort(list, by_pos)
    local k = F.a_detruire(a, #list)
    for i = 1, k do if list[i].valid then list[i].die("enemy") end end
    return true, string.format("%s %d/%d", a.nom or a.type, k, #list)
  end

  -- s43 scen-raid : escouade d'une faction rivale sur l'avant-poste le plus éloigné de l'équipe (F.cible_raid).
  local TURRET_TYPES = { "ammo-turret", "electric-turret", "fluid-turret" }
  function ACT.raid(a, surface, team, hq)
    local name = "fo-" .. a.attaquant .. "-" .. a.soldat
    local proto = game.entity_prototypes[name]
    if not (proto and proto.type == "unit") then return false, "unite inconnue " .. name end
    local aforce = "fo-" .. a.attaquant
    if not game.forces[aforce] then return false, "force inconnue " .. aforce end
    if aforce == team.force then return false, "l'equipe ne s'attaque pas elle-meme" end
    local pts = {}
    for _, d in ipairs(surface.find_entities_filtered({ type = "mining-drill", force = team.force })) do
      pts[#pts + 1] = { x = d.position.x, y = d.position.y }
    end
    local hp = hq.position
    local site, dist = F.cible_raid(pts, { x = hp.x, y = hp.y }, a.loin_min)
    if not site then return false, string.format("aucun avant-poste a %d tuiles du QG (foreuse la plus loin : %s)", a.loin_min or 40,
      dist and string.format("%.0f", dist) or "aucune") end
    local ux, uy = (site.x - hp.x) / dist, (site.y - hp.y) / dist
    local off = a.distance or 28
    local c = { x = site.x + ux * off, y = site.y + uy * off }
    local units = {}
    for i = 1, a.n do
      local w = (i - (a.n + 1) / 2) * 1.5
      local pos = surface.find_non_colliding_position(name, { c.x - uy * w, c.y + ux * w }, 10, 0.5)
      local u = pos and surface.create_entity({ name = name, position = pos, force = aforce })
      if u then
        u.set_command({ type = defines.command.attack_area, destination = site, radius = 20, distraction = defines.distraction.by_enemy })
        units[#units + 1] = u
      end
    end
    team.st.raid = team.st.raid or {}
    team.st.raid[team.key] = { site = site, units = units }
    return #units > 0, string.format("%s x%d sur l'avant-poste (%.0f, %.0f), %.0f tuiles du QG", name, #units, site.x, site.y, dist)
  end

  local function releve_raid(surface, team, r, rd)
    r.site_foreuses = surface.count_entities_filtered({ type = "mining-drill", force = team.force, position = rd.site, radius = 30 })
    r.site_tourelles = surface.count_entities_filtered({ type = TURRET_TYPES, force = team.force, position = rd.site, radius = 30 })
    r.site_unites = surface.count_entities_filtered({ type = "unit", force = team.force, position = rd.site, radius = 40 })
    local alive = 0
    for _, u in ipairs(rd.units) do if u.valid then alive = alive + 1 end end
    r.raid_vivants = alive
    local stt = remote.interfaces["fo-ia3k"] and remote.call("fo-ia3k", "status", team.key)
    local da = (stt and stt.stats and stt.stats.dact) or {}
    r.alertes_site, r.site_envoyees, r.site_refusees = da.site_alerts or 0, da.site_sent or 0, da.site_refused or 0
  end

  -- s43 scen-energie : combustible = objet dont le prototype a une valeur de combustion (aucun nom)
  local FUEL = {}
  local function is_fuel(name)
    if FUEL[name] == nil then
      local p = game.item_prototypes[name]
      FUEL[name] = (p and (p.fuel_value or 0) > 0) or false
    end
    return FUEL[name]
  end
  local function strip(inv)
    if not (inv and inv.valid) then return 0 end
    local names, n = {}, 0
    for name in pairs(inv.get_contents()) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do if is_fuel(name) then n = n + inv.remove({ name = name, count = inv.get_item_count(name) }) end end
    return n
  end
  local function belt_fuel(b, take)
    local n = 0
    for i = 1, b.get_max_transport_line_index() do
      local line = b.get_transport_line(i)
      local names = {}
      for name in pairs(line.get_contents()) do names[#names + 1] = name end
      table.sort(names)
      for _, name in ipairs(names) do
        if is_fuel(name) then n = n + (take and line.remove_item({ name = name, count = line.get_item_count(name) }) or line.get_item_count(name)) end
      end
    end
    return n
  end

  function ACT.assecher_centrale(a, surface, team)
    local r = a.rayon or 6
    local boilers = surface.find_entities_filtered({ force = team.force, type = "boiler" })
    table.sort(boilers, by_pos)
    if #boilers == 0 then return false, "aucune chaudiere" end
    local removed, seen, cand = 0, {}, {}
    for _, bo in ipairs(boilers) do
      removed = removed + strip(bo.get_fuel_inventory())
      if bo.burner then bo.burner.remaining_burning_fuel = 0 end
      local near = surface.find_entities_filtered({ force = team.force, position = bo.position, radius = 2 * r,
        type = { "container", "logistic-container", "inserter", "transport-belt", "underground-belt", "splitter" } })
      table.sort(near, by_pos)
      for _, e in ipairs(near) do
        local dx, dy = e.position.x - bo.position.x, e.position.y - bo.position.y
        local d2 = dx * dx + dy * dy
        if e.type == "container" or e.type == "logistic-container" then
          if d2 <= r * r and not seen[e.unit_number] then seen[e.unit_number] = true; removed = removed + strip(e.get_inventory(defines.inventory.chest)) end
        elseif e.type == "inserter" then
          local h = e.held_stack
          if d2 <= r * r and h and h.valid_for_read and is_fuel(h.name) then removed = removed + h.count; h.clear() end
        elseif not seen[e.unit_number] then
          seen[e.unit_number] = true
          if belt_fuel(e, false) > 0 and e.type == "transport-belt" then cand[#cand + 1] = { e = e, d = d2 } end
          removed = removed + belt_fuel(e, true)
        end
      end
    end
    table.sort(cand, function(x, y) if x.d ~= y.d then return x.d < y.d end return by_pos(x.e, y.e) end)
    local cut = 0
    for i = 1, math.min(a.tapis_coupes or 2, #cand) do if cand[i].e.valid then cand[i].e.destroy(); cut = cut + 1 end end
    return true, string.format("chaudieres %d, combustible retire %d, tapis porteurs %d, coupes %d", #boilers, removed, #cand, cut)
  end

  local CONSUMERS = { "assembling-machine", "furnace", "lab", "mining-drill", "radar", "inserter", "electric-turret", "pump", "roboport", "beacon" }
  local function energie(surface, force, r)
    local en, buf = 0, 0
    for _, e in ipairs(surface.find_entities_filtered({ force = force, type = CONSUMERS })) do
      local ok, b = pcall(function() return e.electric_buffer_size end)
      if ok and b and b > 0 then buf = buf + b; en = en + math.min(e.energy or 0, b) end
    end
    r.elec_sat = buf > 0 and en / buf or nil
    local kw = 0
    for _, g in ipairs(surface.find_entities_filtered({ force = force, type = "generator" })) do
      kw = kw + (g.energy_generated_last_tick or 0) * 60 / 1000
    end
    r.elec_kw = kw
    local n, dry = 0, 0
    for _, bo in ipairs(surface.find_entities_filtered({ force = force, type = "boiler" })) do
      n = n + 1
      local inv = bo.get_fuel_inventory()
      if inv and inv.is_empty() and ((bo.burner and bo.burner.remaining_burning_fuel) or 0) <= 0 then dry = dry + 1 end
    end
    r.chaudieres, r.chaudieres_a_sec = n, dry
  end

  local function releve(surface, team, hq, row)
    local r = {}
    local rd = team.st and team.st.raid and team.st.raid[team.key]
    if rd then releve_raid(surface, team, r, rd) end
    energie(surface, team.force, r)
    local force = game.forces[team.force]
    for _, item in ipairs(S.suivre or {}) do
      local n = 0
      if hq then for _, c in ipairs(chests(surface, team.force, hq)) do n = n + c.get_item_count(item) end end
      r["stock:" .. item] = n
      r["prod:" .. item] = force and force.item_production_statistics.get_input_count(item) or 0
    end
    if hq then
      local t, vides = 0, 0
      for _, e in ipairs(surface.find_entities_filtered({ force = team.force, type = "ammo-turret", position = hq.position, radius = R })) do
        t = t + 1
        local inv = e.get_inventory(defines.inventory.turret_ammo)
        if inv and inv.is_empty() then vides = vides + 1 end
      end
      r.tourelles, r.tourelles_vides = t, vides
      r.ennemis_proches = surface.count_entities_filtered({ force = "enemy", type = "unit", position = hq.position, radius = R })
      local mh = hq.prototype.max_health or 0
      r.qg_vie = mh > 0 and hq.health / mh or 1
    else
      r.qg_vie = 0
    end
    if row then
      r.pnj = row.n or 0
      r.pnj_inactifs = row.last and row.last.idle or 0
      r.avant_postes = row.outposts or 0
      r.pnj_perdus = row.lost or 0
    end
    return r
  end

  local function minute(ctx, m)
    local st = ctx.state()
    st.rel = st.rel or {}
    st.counts = st.counts or { OK = 0, ECHEC = 0, ["EN ATTENTE"] = 0 }
    local surface = ctx.surface()
    local rows, by_key = {}, {}
    if ctx.has("fo-ia1", "teams") then rows = ctx.remote("fo-ia1", "teams") end
    local keys = {}
    for _, row in ipairs(rows) do by_key[row.key] = row; keys[#keys + 1] = row.key end
    -- équipes jugées : fixées au premier relevé (une équipe éliminée ensuite reste jugée, QG à 0)
    if not st.keys then
      st.keys, st.force = F.equipes(S, keys), {}
      for _, k in ipairs(st.keys) do st.force[k] = by_key[k].force end
      log(string.format("%s %s equipes jugees : %s", F.TAG, S.nom, table.concat(st.keys, ", ")))
    end
    local actions = F.actions_a(S, m)
    for rank, k in ipairs(st.keys) do
      local team = { key = k, force = st.force[k], st = st } -- st : état du banc (action raid, s43 scen-raid)
      local hq = hq_of(surface, team.force)
      for _, a in ipairs(actions) do
        local ok, detail
        if hq then
          local okc, o, d = pcall(ACT[a.action], a, surface, team, hq, rank, #st.keys)
          if okc then ok, detail = o, d else ok, detail = false, "erreur Lua " .. tostring(o) end
        else
          ok, detail = false, "QG absent"
        end
        log(F.ligne_action(S, m, a.action, k, ok, detail))
      end
      st.rel[k] = st.rel[k] or {}
      local okr, r = pcall(releve, surface, team, hq, by_key[k])
      if not okr then
        st.erreur = tostring(r)
        log(F.TAG .. " " .. S.nom .. " ERREUR releve " .. tostring(r))
        r = { qg_vie = hq and 1 or 0 }
      end
      st.rel[k][m] = r
      F.deriver(st.rel[k], m, S.suivre)
      log(F.ligne_releve(S, m, k, r))
    end
    for _, att in ipairs(F.attendus_a(S, m)) do
      for _, k in ipairs(st.keys) do
        local etat, obs, cible = F.juger(att.predicat, st.rel[k])
        st.counts[etat] = st.counts[etat] + 1
        log(F.ligne_attendu(S, m, att, k, etat, obs, cible))
      end
    end
  end

  return {
    description = S.description.fr .. " (scenario en boucle fermee, shared/scenarios/" .. id .. ".lua)",
    base = S.base or "partie",
    check_tick = S.duree_min * MIN + 300,

    tick = function(ctx, e)
      if e.tick > 0 and e.tick % MIN == 0 then
        local m = e.tick / MIN
        if m <= S.duree_min then
          local ok, er = pcall(minute, ctx, m)
          if not ok then ctx.state().erreur = tostring(er); log(F.TAG .. " " .. S.nom .. " ERREUR " .. tostring(er)) end
        end
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local c = st.counts or { OK = 0, ECHEC = 0, ["EN ATTENTE"] = 0 }
      log(string.format("%s %s BILAN : %d OK, %d ECHEC, %d EN ATTENTE", F.TAG, S.nom, c.OK, c.ECHEC, c["EN ATTENTE"]))
      ctx.check(st.erreur == nil, "aucune erreur Lua dans le moteur de scenarios", st.erreur or "")
      ctx.check(st.keys ~= nil and #st.keys > 0, "au moins une equipe jugee", st.keys and #st.keys or 0)
    end,
  }
end
