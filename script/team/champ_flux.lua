--[[
  Lot CHAMP (suite, corr-champ2) : application en moteur d'un passage du flux d'un champ (règle pure : shared/team/champ_flux.lua). Les coffres
  de sortie des bandes sont vidés vers le stock du QG et les coffres de combustible remplis depuis lui, PAR SCRIPT, sans PNJ (abstraction
  logistique, à valider par le Directeur Créatif). Aucun objet perdu : ce que le stock ne prend pas reste dans le coffre de sortie, ce que le
  coffre de combustible ne prend pas retourne au stock.
  Seule dépendance : la règle pure (le banc champ-banc charge ce module sans le reste du mod).
]]

local Fx = require("shared.team.champ_flux")

local M = {}

local function chest_at(surface, name, p)
  local e = surface.find_entity(name, { p.x, p.y })
  return (e and e.valid) and e or nil
end

local function sorted_names(c)
  local out = {}
  for k in pairs(c) do out[#out + 1] = k end
  table.sort(out)
  return out
end

--- Un passage. outs, quais : positions { x, y } (quais : + item, le combustible) des coffres `chest` ; stock = { count(item), remove(item, n),
--- insert(item, n) } ; fuel_item : combustible du stock. Rend (objets rapatriés, combustible donné).
function M.apply(surface, chest, outs, quais, fuel_item, stock, cfg)
  local oe, ol = {}, {}
  for i, p in ipairs(outs or {}) do
    local e = chest_at(surface, chest, p)
    if e then
      oe[i] = e
      ol[#ol + 1] = { id = i, n = e.get_inventory(defines.inventory.chest).get_item_count() }
    end
  end
  local qe, ql = {}, {}
  for i, p in ipairs(quais or {}) do
    local e = chest_at(surface, chest, p)
    if e then
      qe[i] = e
      ql[#ql + 1] = { id = i, n = e.get_item_count(p.item or fuel_item) }
    end
  end
  local plan = Fx.plan(ol, ql, stock.count(fuel_item), cfg)
  local moved, given = 0, 0
  for _, t in ipairs(plan.take) do
    local e, left = oe[t[1]], t[2]
    local inv = e.get_inventory(defines.inventory.chest)
    for _, name in ipairs(sorted_names(inv.get_contents())) do
      if left <= 0 then break end
      local got = inv.remove({ name = name, count = left })
      if got > 0 then
        local put = stock.insert(name, got)
        if put < got then inv.insert({ name = name, count = got - put }) end -- le stock est plein : le reste attend dans le coffre
        moved, left = moved + put, left - got
      end
    end
  end
  for _, g in ipairs(plan.give) do
    local e = qe[g[1]]
    local got = stock.remove(fuel_item, g[2])
    if got > 0 then
      local put = e.insert({ name = fuel_item, count = got })
      if put < got then stock.insert(fuel_item, got - put) end
      given = given + put
    end
  end
  return moved, given
end

return M
