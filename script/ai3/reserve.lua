--[[
  Lot INDUSTRIE I1 (RESERVE) : accès runtime au besoin évalué (règle pure : shared/ai3/reserve.lua). Le réglage de carte
  fo-war-industrie (settings/industrie.lua, runtime-global) est le réglage MAÎTRE du lot INDUSTRIE : éteint, le mod joue comme avant.
  Le cerveau (shared/ai3/cerveau.lua, C.think) écrit `f.team.ia3.noyau` à chaque pensée ; la capitalisation (script/ai3/capitalisation.lua)
  et la réserve de croissance de votre équipe (script/team/team.lua) le lisent à la pensée suivante.
]]

local Rs = require("shared.ai3.reserve")

local Rsv = {}

Rsv.SETTING = "fo-war-industrie"

function Rsv.on()
  local ok, s = pcall(function() return settings.global[Rsv.SETTING] end)
  return ok and s ~= nil and s.value == true
end

--- Entrée de la capitalisation d'une équipe : { free, covered, parts, missing } ou nil (réglage éteint, besoin absent ou périmé).
function Rsv.input(f, tick)
  if not Rsv.on() then return nil end
  local st = f and f.team and f.team.ia3
  return Rs.input(st and st.noyau, tick)
end

--- Le besoin évalué est-il couvert par le stock ? (La réserve de fer de croissance de votre équipe ne s'applique plus alors.)
function Rsv.covered(f, tick)
  if not Rsv.on() then return false end
  local st = f and f.team and f.team.ia3
  return Rs.covered(st and st.noyau, tick)
end

return Rsv
