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
  if not action then return end
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
  log(string.format("[FO-PLANDIR] %s : centrale, bras %s : %d remplace(s) sur %d (puissance %.0f, chaudiere a sec %s, %d bras au coffre) a %.1f min",
    f.key or "player", action == "upgrade" and "ELECTRIQUES" or "RETOUR a la combustion", done, #arms, power,
    tostring(dry), avail, tick / 3600))
end

return PA
