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
      local dr_elec, dr_work, am_work = 0, 0, 0
      for _, d in ipairs(s.find_entities_filtered({ force = r.force, type = "mining-drill" })) do
        if d.prototype.electric_energy_source_prototype then
          dr_elec = dr_elec + 1
          if d.status == defines.entity_status.working then dr_work = dr_work + 1 end
        end
      end
      for _, a in ipairs(s.find_entities_filtered({ force = r.force, type = { "assembling-machine", "lab" } })) do
        if a.status == defines.entity_status.working then am_work = am_work + 1 end
      end
      log(TAG .. string.format("reseau minute %d | %s | generateurs=%d reseaux=%d poteaux_total=%d poteaux_sur_reseau_centrale=%d plus_loin_poteau_de_ligne=%.0f kW_produits=%.0f"
        .. " chaudieres=%d travaillent=%d sans_combustible=%d charbon_en_chaudiere=%d foreuses_elec=%d foreuses_elec_travaillent=%d machines_travaillent=%d",
        e.tick / MIN, r.key, #gens, n, #poles, on, far, kw, #boilers, bo_ok, bo_dry, fuel, dr_elec, dr_work, am_work))
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
