--[[
  Lot AGES, côté RUNTIME : libellé localisé d'un objectif d'équipe (règle pure : shared/team/objectif.lua). Utilisé par la
  fenêtre « Équipe et factions », la ligne d'objectif de Team.goal_text et le journal de l'équipe : aucune clé de traduction
  inconnue (« Unknown key: fo-team.goal-ia3-alim-assembling-machine-2 », retour du DC du 2/11, point 8).
  Lecture seule ; jamais appelé à on_load.
]]

local Obj = require("shared.team.objectif")
local Ld = require("shared.levels.config")

local M = {}

local function item_name(name)
  local p = game.item_prototypes[name]
  return p and p.localised_name or name
end

local function entity_name(fam)
  for _, f in ipairs(Ld.families) do
    if f.key == fam then
      local p = game.entity_prototypes[f.base]
      return p and p.localised_name or fam
    end
  end
  return fam
end

local function arg_of(a)
  if a.kind == "item" then return item_name(a.v) end
  if a.kind == "outpost" then
    if Obj.OUTPOSTS[a.v] then return { "fo-team.outpost-" .. a.v } end
    return a.v
  end
  if a.kind == "entity" then return entity_name(a.v) end
  return a.v
end

--- Objectif -> chaîne localisée « fo-team.goal-<id> » avec ses paramètres.
function M.name(goal)
  local d = Obj.describe(goal)
  local out = { "fo-team.goal-" .. d.id }
  for _, a in ipairs(d.args) do out[#out + 1] = arg_of(a) end
  return out
end

return M
