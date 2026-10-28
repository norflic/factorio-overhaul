-- Lot CENTRALE : etape1-guide (même partie, mêmes relevés) + un relevé de la CONNEXION ÉLECTRIQUE de chaque faction toutes
-- les 5 min : générateurs, réseaux électriques distincts qui portent un générateur ou un poteau de la faction, poteaux sur le
-- réseau du premier générateur, puissance produite au dernier tick (« la centrale est reliée au treillis et produit »).
-- Ligne : [FO-CENTRALE] reseau minute N | <faction> | generateurs=.. reseaux=.. poteaux_total=.. poteaux_sur_reseau_centrale=..
--         plus_loin_poteau_de_ligne=.. kW_produits=..
local base = require("scenarios/etape1-guide")
local tick0 = base.tick
local MIN = 3600
local TAG = "[FO-CENTRALE] "

base.description = (base.description or "") .. " + relevé de la connexion électrique des centrales"

local function factions()
  local out = {}
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    if row.key ~= "player" then out[#out + 1] = row end
  end
  return out
end


-- Diagnostic des reseaux electriques d'une faction (a 30, 45 et 60 min) : par reseau, poteaux, generateurs, foreuses electriques
-- (avec leur etat), boite englobante ; puis, pour chaque reseau sans generateur qui porte des foreuses, la plus courte distance
-- de ses poteaux a un poteau du reseau du generateur et le plus proche poteau du reseau du generateur.
local function net_diag(s, r, minute)
  local nets = {}
  local function net(id) nets[id] = nets[id] or { poles = {}, gens = 0, drills = 0, nopow = 0, work = 0, x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9 } return nets[id] end
  for _, p in ipairs(s.find_entities_filtered({ force = r.force, type = "electric-pole" })) do
    local n = net(p.electric_network_id or -1)
    n.poles[#n.poles + 1] = p.position
    n.x0, n.y0 = math.min(n.x0, p.position.x), math.min(n.y0, p.position.y)
    n.x1, n.y1 = math.max(n.x1, p.position.x), math.max(n.y1, p.position.y)
  end
  for _, g in ipairs(s.find_entities_filtered({ force = r.force, type = "generator" })) do net(g.electric_network_id or -1).gens = net(g.electric_network_id or -1).gens + 1 end
  for _, d in ipairs(s.find_entities_filtered({ force = r.force, type = "mining-drill" })) do
    if d.prototype.electric_energy_source_prototype then
      local n = net(d.electric_network_id or -1)
      n.drills = n.drills + 1
      if d.status == defines.entity_status.working then n.work = n.work + 1
      elseif d.status == defines.entity_status.no_power or d.status == defines.entity_status.low_power then n.nopow = n.nopow + 1 end
    end
  end
  -- etats des foreuses electriques de la faction (noms du moteur) : pourquoi elles ne travaillent pas
  local hist, names = {}, {}
  local sname = {}
  for k, v in pairs(defines.entity_status) do sname[v] = k end
  for _, d in ipairs(s.find_entities_filtered({ force = r.force, type = "mining-drill" })) do
    if d.prototype.electric_energy_source_prototype then
      local k = sname[d.status] or tostring(d.status)
      hist[k] = (hist[k] or 0) + 1
    end
  end
  for k in pairs(hist) do names[#names + 1] = k end
  table.sort(names)
  local hs = {}
  for _, k in ipairs(names) do hs[#hs + 1] = k .. "=" .. hist[k] end
  log(TAG .. string.format("etats foreuses minute %d | %s | %s", minute, r.key, table.concat(hs, " ")))
  local ids = {}
  for id in pairs(nets) do ids[#ids + 1] = id end
  table.sort(ids)
  local gen_net
  for _, id in ipairs(ids) do if nets[id].gens > 0 then gen_net = id end end
  for _, id in ipairs(ids) do
    local n = nets[id]
    local extra = ""
    if gen_net and id ~= gen_net and n.drills > 0 then
      local best, bp, bq = 1e9
      for _, a in ipairs(n.poles) do
        for _, b in ipairs(nets[gen_net].poles) do
          local d = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
          if d < best then best, bp, bq = d, a, b end
        end
      end
      if bp then extra = string.format(" | plus court ecart au reseau du generateur %.1f tuiles entre (%.1f,%.1f) et (%.1f,%.1f)", best, bp.x, bp.y, bq.x, bq.y) end
    end
    log(TAG .. string.format("composante minute %d | %s | reseau %d%s | poteaux=%d generateurs=%d foreuses_elec=%d en_marche=%d sans_courant=%d | boite (%.0f,%.0f)-(%.0f,%.0f)%s",
      minute, r.key, id, id == gen_net and " [GENERATEUR]" or "", #n.poles, n.gens, n.drills, n.work, n.nopow, n.x0, n.y0, n.x1, n.y1, extra))
  end
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  -- chantiers des factions toutes les 2 min (diagnostic : état, entités posées, ce qui reste et pourquoi)
  if e.tick > 0 and e.tick % (2 * MIN) == 0 then
    for _, r in ipairs(factions()) do
      local okr, rep = pcall(remote.call, "fo-ia1d", "report", r.key)
      if okr and rep then
        for _, pr in ipairs(rep.projects or {}) do
          if pr.state ~= "fini" and pr.state ~= "refuse" then
            local ub = {}
            for i, u in ipairs(pr.unbuilt or {}) do
              if i <= 4 then ub[#ub + 1] = string.format("%s@%d,%d f%d npc%d stock%d tache %s age%ds cd%ds", u.name, u.x, u.y, u.fails, u.npc, u.have or -1,
                tostring(u.task), u.age or -1, u.cd or 0) end
            end
            log(TAG .. string.format("chantier minute %d | %s | #%s %s %s (%d/%d) obst %d/%d | non poses %s", e.tick / MIN, r.key,
              tostring(pr.id), tostring(pr.state), tostring(pr.reason), pr.built or 0, pr.total or 0,
              pr.open_obstacles or 0, pr.obstacles or 0, table.concat(ub, "; ")))
          end
        end
      end
    end
  end
  if e.tick == 30 * MIN or e.tick == 45 * MIN or e.tick == 60 * MIN then
    for _, r in ipairs(factions()) do net_diag(ctx.surface(), r, e.tick / MIN) end
  end
  if e.tick > 0 and e.tick % (5 * MIN) == 0 then
    local s = ctx.surface()
    for _, r in ipairs(factions()) do
      local gens = s.find_entities_filtered({ force = r.force, type = "generator" })
      local poles = s.find_entities_filtered({ force = r.force, type = "electric-pole" })
      local nets, first = {}, nil
      local kw = 0
      for _, g in ipairs(gens) do
        nets[g.electric_network_id or -1] = true
        first = first or g.electric_network_id
        kw = kw + (g.energy_generated_last_tick or 0) * 60 / 1000
      end
      local on, far = 0, 0
      local gx, gy
      if gens[1] then gx, gy = gens[1].position.x, gens[1].position.y end
      for _, p in ipairs(poles) do
        nets[p.electric_network_id or -1] = true
        if first and p.electric_network_id == first then
          on = on + 1
          if gx then far = math.max(far, math.sqrt((p.position.x - gx) ^ 2 + (p.position.y - gy) ^ 2)) end
        end
      end
      local n = 0
      for _ in pairs(nets) do n = n + 1 end
      -- chaudières : combustible (charbon livré à la centrale) et état ; consommateurs : foreuses électriques et machines
      -- qui travaillent (« l'électricité est CONSOMMÉE »)
      local fuel, bo_ok, bo_dry, boilers = 0, 0, 0, s.find_entities_filtered({ force = r.force, type = "boiler" })
      for _, bo in ipairs(boilers) do
        local inv = bo.get_fuel_inventory()
        if inv then fuel = fuel + inv.get_item_count() end
        if bo.status == defines.entity_status.working then bo_ok = bo_ok + 1
        elseif bo.status == defines.entity_status.no_fuel then bo_dry = bo_dry + 1 end
      end
      local dr_elec, dr_work, am_work, dr_nopow = 0, 0, 0, 0
      for _, d in ipairs(s.find_entities_filtered({ force = r.force, type = "mining-drill" })) do
        if d.prototype.electric_energy_source_prototype then
          dr_elec = dr_elec + 1
          if d.status == defines.entity_status.working then dr_work = dr_work + 1
          elseif d.status == defines.entity_status.no_power or d.status == defines.entity_status.low_power then dr_nopow = dr_nopow + 1 end
        end
      end
      for _, a in ipairs(s.find_entities_filtered({ force = r.force, type = { "assembling-machine", "lab" } })) do
        if a.status == defines.entity_status.working then am_work = am_work + 1 end
      end
      log(TAG .. string.format("reseau minute %d | %s | generateurs=%d reseaux=%d poteaux_total=%d poteaux_sur_reseau_centrale=%d plus_loin_poteau_de_ligne=%.0f kW_produits=%.0f"
        .. " chaudieres=%d travaillent=%d sans_combustible=%d charbon_en_chaudiere=%d foreuses_elec=%d foreuses_elec_travaillent=%d machines_travaillent=%d foreuses_elec_sans_courant=%d",
        e.tick / MIN, r.key, #gens, n, #poles, on, far, kw, #boilers, bo_ok, bo_dry, fuel, dr_elec, dr_work, am_work, dr_nopow))
      -- ravitaillement des quais (centrale lointaine : le charbon part du coffre du QG à pied) : objets remplis aux quais, objets
      -- collectés, contenu des quais d'entrée de la centrale
      local okq, rq = pcall(remote.call, "fo-ia1d", "report", r.key)
      if okq and rq then
        local qs = {}
        for _, pr in ipairs(rq.projects or {}) do
          if pr.parts and pr.parts[1] and pr.parts[1].kind == "centrale" then
            for _, q in ipairs(pr.quais or {}) do qs[#qs + 1] = string.format("%s=%d", q.item, q.count) end
          end
        end
        log(TAG .. string.format("quais minute %d | %s | remplis=%d collectes=%d | quais de la centrale : %s", e.tick / MIN, r.key,
          rq.filled or 0, rq.collected or 0, table.concat(qs, " ")))
        log(TAG .. string.format("taches minute %d | %s | ok/echec {%s} | raisons d'echec {%s}", e.tick / MIN, r.key,
          tostring(rq.task_stats), tostring(rq.fail_reasons)))
      end
    end
  end
end

return base
