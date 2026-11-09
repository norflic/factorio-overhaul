--[[
  Lot REINVESTIR-FER : RUNTIME. Matière brute d'un avant-poste de chaque type (ses foreuses thermiques et ses fours ou coffres), lue au livre de
  recettes : le coût que le remboursement de shared/ai3/reinvestir.lua compare au débit. Aucun nom d'objet : T.DRILL, T.outposts[type].sink et le
  nombre de foreuses viennent de shared/team/config.lua. Mis en cache par équipe (le livre ne change pas en cours de partie) : jamais dans `global`.
]]
local T = require("shared.team.config")

local Rr = {}
local CACHE = {}

--- { [type d'avant-poste] = total de matière brute } ou nil sans livre.
function Rr.cost(f, book)
  if not (book and book.raw_cost) then return nil end
  local key = f.key or "player"
  if CACHE[key] then return CACHE[key] end
  local out = {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local spec = T.outposts[kind]
    local raw = book:raw_cost({ { T.DRILL, spec.drills }, { spec.sink, spec.drills } })
    local total = 0
    for _, name in ipairs((function() local ks = {} for k in next, raw do ks[#ks + 1] = k end table.sort(ks) return ks end)()) do
      total = total + (raw[name] or 0)
    end
    out[kind] = total
  end
  CACHE[key] = out
  return out
end

return Rr
