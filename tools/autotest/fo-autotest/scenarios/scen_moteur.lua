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

  local function releve(surface, team, hq, row)
    local r = {}
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
      local team = { key = k, force = st.force[k] }
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
