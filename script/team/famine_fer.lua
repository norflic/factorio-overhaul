--[[
  FAMINE-FER, partie moteur (règle pure : shared/team/famine_cle.lua). Lit l'état de la migration de l'avant-poste (f.migration), l'état du projet de sa
  bande (f.build) et le manque de sa matière par rapport au besoin (f.team.ia3.starved, écrit par la pensée) ; ne modifie rien.
  Lecteurs : script/faction/outposts.lua (Outposts.extend : l'extension thermique reste permise), script/team/team.lua (la vue de l'équipe ne
  marque pas l'avant-poste « plein » : le cerveau peut lui commander l'extension).
]]
local T = require("shared.team.config")
local Fam = require("shared.team.famine_cle")

local Famine = {}

--- L'extension thermique de l'avant-poste `o` (plaque clé seulement) reste-t-elle permise malgré sa migration en cours ?
function Famine.open(f, o)
  if not (f and o and o.migr == "en cours") then return false end
  local spec = T.outposts[o.kind]
  if not (spec and spec.product == T.outposts.iron.product) then return false end
  local sv = f.team and f.team.ia3 and f.team.ia3.starved
  local starved = sv ~= nil and (sv[spec.product] == true or sv[spec.resource] == true)
  local ms = f.migration
  local st = ms and ms.o and ms.o[o.id]
  local p = st and st.pid and f.build and f.build.projects and f.build.projects[st.pid]
  return Fam.open({ starved = starved, migr = o.migr, stage = st and st.stage, retired = st and st.retired, project = p and p.state })
end

return Famine
