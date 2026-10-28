--[[
  Lot PLANDIR : moniteur de la centrale à vapeur d'une équipe (journal seulement, rien n'est modifié).

  Décision du 28/10 (lead, après mesures en moteur réel) : les bras qui nourrissent les chaudières RESTENT à combustion. Un bras
  électrique sur une chaudière est un blackout en attente : au moindre creux (démarrage, charge au-delà de la production, coffre de
  charbon vide un instant), le bras s'arrête faute de courant, la chaudière s'éteint et la centrale ne repart jamais. Passés à
  l'électrique, les bras de la centrale la tuaient en 1,5 à 3,5 min dans 6 cas sur 6 (archives 2026-10-28_PLANDIR). Un bras à
  combustion se recharge seul avec le charbon qu'il déplace. Seul le charbon du quai manque : voir docs, approvisionnement par tapis.
]]
local M = require("shared.team.modules")
local C = require("shared.team.centrale")

local PA = {}

local function real_of(surface, e, force)
  local found = surface.find_entity(e.name, { e.x, e.y })
  if found and found.valid and found.force.name == force then return found end
  return nil
end

local STATUS_NAME = nil
local function status_name(r)
  if not STATUS_NAME then
    STATUS_NAME = {}
    for k, v in pairs(defines.entity_status) do STATUS_NAME[v] = k end
  end
  local st = r.status
  return st and STATUS_NAME[st] or "?"
end

--- Diagnostic d'une centrale sans courant (journal, 8 lignes au plus par équipe, à chaque nouvelle panne) : charbon des coffres de quai, combustible et
--- vapeur des chaudières, statut des bras. Lecture seule.
local function snapshot(f, surface, p, st, tag, tick)
  st.snaps = (st.snaps or 0) + 1
  if st.snaps > 8 then return end
  local parts = {}
  for _, q in ipairs(p.quais or {}) do
    local c = surface.find_entities_filtered({ position = { q.x, q.y }, radius = 0.4, type = "container", force = f.force, limit = 1 })[1]
    parts[#parts + 1] = string.format("coffre(%s)=%d", tostring(q.item), c and c.get_item_count(q.item) or -1)
  end
  for _, e in ipairs(p.ents) do
    if (M.spec(e.name) or {}).water ~= nil then
      local r = real_of(surface, e, f.force)
      if r then
        local inv = r.get_fuel_inventory()
        local fb = r.fluidbox
        local steam = 0
        for i = 1, #fb do local fl = fb[i]; if fl and fl.name == "steam" then steam = steam + fl.amount end end
        parts[#parts + 1] = string.format("chaudiere combustible=%d vapeur=%.0f statut=%s", inv and inv.get_item_count() or -1, steam, status_name(r))
      end
    elseif (M.spec(e.name) or {}).power_out ~= nil then
      local r = real_of(surface, e, f.force)
      if r then parts[#parts + 1] = string.format("machine statut=%s", status_name(r)) end
    elseif e.was_burner or e.name == M.BURNER_ARM then
      local r = real_of(surface, e, f.force)
      if r then parts[#parts + 1] = string.format("bras %s/%s statut=%s", e.name, tostring(e.role), status_name(r)) end
    end
  end
  log(string.format("[FO-PLANDIR] %s : centrale, diagnostic (%s) a %.1f min : %s", f.key or "player", tag, tick / 3600,
    table.concat(parts, " ; ")))
end

--- Relevé de TOUTES les centrales finies de l'équipe, toutes les 5 s : premier courant, pannes (journal), saturation
--- (f.build.plant_watch.saturated, lu par script/ai3/automatisation.lua qui demande une centrale de plus).
PA.EVERY = 300
function PA.step_all(f, surface, tick)
  local b = f.build
  b.plant_watch = b.plant_watch or { snaps = 0 }
  local st = b.plant_watch
  if tick < (st.next or 0) then return end
  st.next = tick + PA.EVERY
  local power, capacity, boilers, done, pending = 0, 0, 0, 0, 0
  local first_dry = false
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and p.spec and p.spec.gen == "steam" then
      if p.state == "fini" then
        done = done + 1
        for _, e in ipairs(p.ents) do
          local sp = M.spec(e.name) or {}
          if sp.power_out then
            capacity = capacity + (M.spec(e.name).power_out or 0) * 1000 / 60
            local r = real_of(surface, e, f.force)
            if r then power = power + (r.energy_generated_last_tick or 0) end
          elseif sp.water then
            boilers = boilers + 1
            local r = real_of(surface, e, f.force)
            if r and pid == b.plant then
              local inv = r.get_fuel_inventory()
              if inv and inv.is_empty() and ((r.burner and r.burner.remaining_burning_fuel) or 0) <= 0 then first_dry = true end
            end
          end
        end
      elseif p.state ~= "refuse" then
        pending = pending + 1
      end
    end
  end
  st.done, st.pending, st.boilers, st.capacity, st.power = done, pending, boilers, capacity, power
  if power > 0 and not st.first_power then
    st.first_power = tick
    log(string.format("[FO-PLANDIR] %s : centrale, 1er courant a %.1f min (puissance %.0f J/tick)", f.key or "player", tick / 3600, power))
  end
  local was = st.saturated
  C.observe(st, power, capacity)
  if st.saturated and not was then
    log(string.format("[FO-PLANDIR] %s : centrale saturee a %.1f min (%.0f J/tick sur %.0f, %d chaudiere(s), %d centrale(s))",
      f.key or "player", tick / 3600, power, capacity, boilers, done))
  end
  local pp = b.plant and b.projects[b.plant]
  if pp and pp.state == "fini" and st.first_power and power <= 0 and first_dry and not st.was_dry then
    snapshot(f, surface, pp, st, "centrale a sec", tick)
  end
  st.was_dry = first_dry and power <= 0
end

return PA
