--[[
  Lot PLANDIR (T2) : les bras de la centrale passent de la combustion à l'électrique dès que la centrale produit, et
  reviennent à la combustion si la centrale s'éteint à sec (règles pures : shared/team/bras.lua). Remplacement sur place
  (create_entity fast_replace, F39 : même groupe « inserter »), entrée du plan RENOMMÉE pour que find_real (recherche par
  nom) et le ravivage voient le bras réel.
  Un bras électrique vient du coffre de l'équipe (Stock) ; sans bras au coffre, la centrale reste à combustion.
]]
local Stock = require("script.team.stock")
local B = require("shared.team.bras")
local M = require("shared.team.modules")

local PA = {}

local function real_of(surface, e, force)
  local found = surface.find_entity(e.name, { e.x, e.y })
  if found and found.valid and found.force.name == force then return found end
  return nil
end

--- Remplace sur place le bras réel `real` par `name` ; rend la nouvelle entité ou nil.
local function swap(surface, real, name, force)
  local pos, dir = real.position, real.direction
  return surface.create_entity({ name = name, position = pos, direction = dir, force = force, fast_replace = true,
    spill = false, raise_built = true })
end

--- Débit de charbon (objets/s) que porte un bras de cette entrée : le quai porte la centrale entière, un bras de chaudière
--- la moitié d'une chaudière.
local function need_of(e, nboilers)
  local per_boiler = M.BASE.boiler.burner_kw / M.COAL_J
  if e.role == "quai-bras" then return per_boiler * nboilers end
  return per_boiler / 2
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

--- Diagnostic d'une centrale sans courant (journal, 8 lignes au plus par équipe) : charbon des coffres de quai, combustible et
--- vapeur des chaudières, statut des bras. Lecture seule.
local function snapshot(f, surface, p, st, tag, tick)
  st.snaps = (st.snaps or 0) + 1
  if st.snaps > 8 then return end
  local parts = {}
  for _, q in ipairs(p.quais or {}) do
    local c = surface.find_entities_filtered({ position = { q.x, q.y }, radius = 0.4, name = "iron-chest", force = f.force, limit = 1 })[1]
    parts[#parts + 1] = string.format("coffre(%s)=%d", tostring(q.item), c and c.get_item_count(q.item) or -1)
  end
  for _, e in ipairs(p.ents) do
    if e.name == "boiler" then
      local r = real_of(surface, e, f.force)
      if r then
        local inv = r.get_fuel_inventory()
        local fb = r.fluidbox
        local steam = 0
        for i = 1, #fb do local fl = fb[i]; if fl and fl.name == "steam" then steam = steam + fl.amount end end
        parts[#parts + 1] = string.format("chaudiere combustible=%d vapeur=%.0f statut=%s", inv and inv.get_item_count() or -1, steam, status_name(r))
      end
    elseif e.name == "steam-engine" then
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

--- Bras à combustion de la centrale de l'équipe `f` encore à remplacer (nil : pas de centrale planifiée ou refusée).
function PA.burners(f)
  local b = f.build
  local p = b and b.plant and b.projects[b.plant]
  if not p or p.state == "refuse" then return nil end
  local n = 0
  for _, e in ipairs(p.ents) do if e.name == M.BURNER_ARM then n = n + 1 end end
  if n == 0 and #p.ents == 0 then n = 3 end -- pas encore planifiée : deux bras de chaudière et celui du quai
  return n
end

--- Lot PLANDIR : bras électriques à FABRIQUER d'avance pour la centrale, { nom, manque } ou nil. `usable(nom)` : le livre de
--- la main sait le faire ou il est au coffre ; `stock` : le coffre. Le bras est celui que PA.step posera.
function PA.demand(f, usable, stock)
  local n = PA.burners(f)
  if not n then return nil end
  local name = M.electric_arm(usable, 0)
  if not name then return nil end
  local miss = B.arms_missing(f.build.plant_arms, n, stock[name] or 0)
  if miss <= 0 then return nil end
  return { name, miss }
end

--- Relevé de la centrale d'une équipe (projet `p` fini) : f.build.plant_arms porte l'état de B.
function PA.step(f, surface, p, tick)
  local b = f.build
  b.plant_arms = b.plant_arms or B.new()
  local st = b.plant_arms
  if tick < (st.next or 0) then return end
  st.next = tick + B.EVERY
  local power, dry, nboilers = 0, false, 0
  local arms = {}
  for _, e in ipairs(p.ents) do
    if e.name == "steam-engine" then
      local r = real_of(surface, e, f.force)
      if r then power = power + (r.energy_generated_last_tick or 0) end
    elseif e.name == "boiler" then
      local r = real_of(surface, e, f.force)
      if r then
        nboilers = nboilers + 1
        local inv = r.get_fuel_inventory()
        if inv and inv.is_empty() and ((r.burner and r.burner.remaining_burning_fuel) or 0) <= 0 then dry = true end
      end
    elseif e.name == M.BURNER_ARM or e.was_burner then
      arms[#arms + 1] = e
    end
  end
  if #arms == 0 or nboilers == 0 then return end
  local avail = 0
  for _, name in ipairs(M.ELECTRIC_ARMS) do avail = avail + Stock.count(f, name) end
  local action = B.observe(st, { power = power, dry = dry, arms = avail }, tick)
  if st.mode == "electric" and power <= 0 and not action then snapshot(f, surface, p, st, "electrique, sans courant", tick) end
  if not action then return end
  if action == "revert" then snapshot(f, surface, p, st, "avant le retour", tick) end
  local done = 0
  if action == "upgrade" then
    for _, e in ipairs(arms) do
      if e.name == M.BURNER_ARM then
        local name = M.electric_arm(function(n) return Stock.count(f, n) > 0 end, need_of(e, nboilers))
        local r = name and real_of(surface, e, f.force)
        if r and Stock.remove(f, name, 1) == 1 then
          local new = swap(surface, r, name, f.force)
          if new and new.valid then
            e.was_burner, e.name, e.item = true, name, name
            done = done + 1
          else
            Stock.insert(f, name, 1)
          end
        end
      end
    end
  else
    for _, e in ipairs(arms) do
      if e.was_burner then
        local r = real_of(surface, e, f.force)
        if r then
          local new = swap(surface, r, M.BURNER_ARM, f.force)
          if new and new.valid then
            local fuel = new.get_fuel_inventory()
            if fuel and Stock.count(f, "coal") >= 2 then fuel.insert({ name = "coal", count = Stock.remove(f, "coal", 2) }) end
            e.name, e.item, e.was_burner = M.BURNER_ARM, M.BURNER_ARM, nil
            done = done + 1
          end
        end
      end
    end
  end
  B.applied(st, action, done, tick)
  log(string.format("[FO-PLANDIR] %s : centrale, bras %s : %d remplace(s) sur %d (puissance %.0f, chaudiere a sec %s, %d bras au coffre, 1er courant a %.1f min) a %.1f min",
    f.key or "player", action == "upgrade" and "ELECTRIQUES" or "RETOUR a la combustion", done, #arms, power,
    tostring(dry), avail, (st.first_power or tick) / 3600, tick / 3600))
end

return PA
