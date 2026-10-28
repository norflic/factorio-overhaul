--[[
  Lot ENERGIE, côté RUNTIME : relevé de la source d'énergie d'une équipe. Aux minutes 10, 30 et 60, journal [FO-ENERGIE] : le
  choix de la règle pure (shared/ai3/generation.lua) parmi les sources que l'exécutant sait poser (gabarits), et les
  générateurs des PROTOTYPES du moteur (types de Rg.POWER_TYPES) avec leur puissance nominale, leur objet de pose, et la raison
  de leur écart (« pas de gabarit de pose », « objets impossibles : technologie… »). Aucun nom d'objet : tout est lu au moteur.
  Lecture seule (le choix ne pose rien : seule la vapeur a un gabarit de pose ; solaire et nucléaire sont écartés avec raison).
]]
local A = require("shared.ai3.automatiser")
local G = require("shared.ai3.generation")
local Rg = require("shared.ai3.reglages")

local E = {}
E.MINUTES = { [10] = true, [30] = true, [60] = true }

local function prototypes(book, stock)
  local out = {}
  for _, ty in ipairs(Rg.POWER_TYPES) do
    local protos = game.get_filtered_entity_prototypes({ { filter = "type", type = ty } })
    local names = {}
    for name in pairs(protos) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
      local p = protos[name]
      local item = p.items_to_place_this and p.items_to_place_this[1]
      local missing = {}
      if item and not (book:handcraftable(item.name) or (stock[item.name] or 0) > 0) then missing[1] = item.name end
      local kw = (p.max_energy_production or 0) * 60 / 1000
      out[#out + 1] = { name = name, kind = ty, kw = kw, cost = item and { { item.name, item.count or 1 } } or nil,
        template = false, missing = missing }
    end
  end
  return out
end

--- Journal [FO-ENERGIE] d'une équipe aux minutes de E.MINUTES (une fois chacune).
function E.survey(f, st, book, stock, tick)
  local m = math.floor(tick / 3600)
  if not E.MINUTES[m] then return end
  st.energie_done = st.energie_done or {}
  if st.energie_done[m] then return end
  st.energie_done[m] = true
  local cands = A.power_candidates()
  for _, c in ipairs(prototypes(book, stock)) do cands[#cands + 1] = c end
  local res = G.choose(cands)
  log(string.format("[FO-ENERGIE] %s minute %d : %s", f.key or "player", m, G.describe(res)))
end

return E
