--[[
  Lot joueur-parite (14/11) : journal [FO-PARITE-JOUEUR]. Règle PURE (aucune API Factorio) : met en regard votre équipe et la
  moyenne des factions vivantes sur les mêmes grandeurs (PNJ, avant-postes, foreuses posées, fours de l'équipe, recherches faites).
  Lecture seule : aucune décision ne lit ce journal. Runtime : script/team/parite_joueur.lua.

  rows = { { key = "amber", workers = n, outposts = n, drills = n, smelters = n, techs = n }, ... } (votre équipe : key = "player").
]]

local P = {}

P.FIELDS = { "workers", "outposts", "drills", "smelters", "techs" }

--- Moyenne des factions (toutes les lignes sauf « player »), arrondie au dixième ; nil sans faction.
function P.average(rows)
  local sum, n = {}, 0
  for _, r in ipairs(rows or {}) do
    if r.key ~= "player" then
      n = n + 1
      for _, k in ipairs(P.FIELDS) do sum[k] = (sum[k] or 0) + (r[k] or 0) end
    end
  end
  if n == 0 then return nil end
  local out = { n = n }
  for _, k in ipairs(P.FIELDS) do out[k] = math.floor((sum[k] or 0) * 10 / n + 0.5) / 10 end
  return out
end

local function fmt(r)
  local parts = {}
  for _, k in ipairs(P.FIELDS) do parts[#parts + 1] = k .. "=" .. tostring(r[k] or 0) end
  return table.concat(parts, " ")
end

--- Ligne du journal, ou nil sans votre équipe.
function P.line(rows, minute)
  local me
  for _, r in ipairs(rows or {}) do if r.key == "player" then me = r end end
  if not me then return nil end
  local avg = P.average(rows)
  return string.format("[FO-PARITE-JOUEUR] minute %d | votre equipe %s | moyenne de %d faction(s) %s", math.floor(minute or 0),
    fmt(me), avg and avg.n or 0, avg and fmt(avg) or "-")
end

return P
