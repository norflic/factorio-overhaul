--[[
  Lot PLANDIR : moniteur de la centrale à vapeur d'une équipe (journal seulement, rien n'est modifié).

  Décision du 28/10 (lead, après mesures en moteur réel) : les bras qui nourrissent les chaudières RESTENT à combustion. Un bras
  électrique sur une chaudière est un blackout en attente : au moindre creux (démarrage, charge au-delà de la production, coffre de
  charbon vide un instant), le bras s'arrête faute de courant, la chaudière s'éteint et la centrale ne repart jamais. Passés à
  l'électrique, les bras de la centrale la tuaient en 1,5 à 3,5 min dans 6 cas sur 6 (archives 2026-10-28_PLANDIR). Un bras à
  combustion se recharge seul avec le charbon qu'il déplace. Ce qui manque est le charbon du quai (mesuré : coffre à 0, 123456789, 32,7 min) : lot quai-charge, branche quai-charge.
]]
local M = require("shared.team.modules")
local T = require("shared.team.config")
local Stock = require("script.team.stock")
local Bras = require("shared.team.bras_retour")

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

--- Remplace sur place le bras réel `real` par `name` ; rend la nouvelle entité ou nil.
local function swap(surface, real, name, force)
  return surface.create_entity({ name = name, position = real.position, direction = real.direction, force = force,
    fast_replace = true, spill = false, raise_built = true })
end

--- Migration (versions 0.6.5 à 0.6.7 : bras de centrale passés à l'électrique) : les bras marqués `was_burner` repassent à
--- combustion, avec du combustible du coffre (règle pure : shared/team/bras_retour.lua). Repris à chaque relevé tant qu'il en
--- reste (bras réel introuvable, pas de place). Rend le nombre de bras repassés.
local function restore(f, surface, p, tick)
  local todo = Bras.to_restore(p.ents, M.BURNER_ARM)
  if #todo == 0 then return 0 end
  local done = 0
  for _, i in ipairs(todo) do
    local e = p.ents[i]
    local r = real_of(surface, e, f.force)
    if r then
      local new = swap(surface, r, M.BURNER_ARM, f.force)
      if new and new.valid then
        local fuel = new.get_fuel_inventory()
        if fuel and Stock.count(f, T.fuel) >= T.fuel_per_burner then
          fuel.insert({ name = T.fuel, count = Stock.remove(f, T.fuel, T.fuel_per_burner) })
        end
        Bras.restored(e, M.BURNER_ARM)
        done = done + 1
      end
    end
  end
  log(string.format("[FO-PLANDIR] %s : centrale, %d bras electrique(s) remis a la combustion (%d a remettre) a %.1f min",
    f.key or "player", done, #todo, tick / 3600))
  return done
end

--- Banc seulement (remote fo-ia1d) : reproduit la conversion des versions 0.6.5 à 0.6.7 (bras de la centrale passés au bras
--- électrique le plus lent de portée 1, entrée marquée `was_burner`), pour prouver la migration. Rend le nombre de bras convertis.
function PA.legacy_electric(f, surface)
  local b = f.build
  local p = b and b.plant and b.projects[b.plant]
  if not (p and p.state == "fini") then return 0 end
  local name = M.ELECTRIC_ARM
  local done = 0
  for _, e in ipairs(p.ents) do
    if e.name == M.BURNER_ARM then
      local r = real_of(surface, e, f.force)
      local new = r and swap(surface, r, name, f.force)
      if new and new.valid then e.name, e.item, e.was_burner = name, name, true; done = done + 1 end
    end
  end
  return done
end

--- Relevé de la centrale (projet `p` fini), toutes les 5 s : premier courant et pannes (journal).
PA.EVERY = 300
function PA.step(f, surface, p, tick)
  local b = f.build
  b.plant_watch = b.plant_watch or { snaps = 0 }
  local st = b.plant_watch
  if tick < (st.next or 0) then return end
  st.next = tick + PA.EVERY
  restore(f, surface, p, tick)
  local power, dry = 0, false
  for _, e in ipairs(p.ents) do
    local sp = M.spec(e.name) or {}
    if sp.power_out then
      local r = real_of(surface, e, f.force)
      if r then power = power + (r.energy_generated_last_tick or 0) end
    elseif sp.water then
      local r = real_of(surface, e, f.force)
      if r then
        local inv = r.get_fuel_inventory()
        if inv and inv.is_empty() and ((r.burner and r.burner.remaining_burning_fuel) or 0) <= 0 then dry = true end
      end
    end
  end
  if power > 0 and not st.first_power then
    st.first_power = tick
    log(string.format("[FO-PLANDIR] %s : centrale, 1er courant a %.1f min (puissance %.0f J/tick)", f.key or "player", tick / 3600, power))
  end
  if st.first_power and power <= 0 and dry and not st.was_dry then
    snapshot(f, surface, p, st, "centrale a sec", tick)
  end
  st.was_dry = dry and power <= 0
end

return PA
