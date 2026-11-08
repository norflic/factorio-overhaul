--[[
  Lot X10-GEL : DÉCLARATION de l'état du lot (namespace « gel » du stockage) et accès pour script/faction/gel.lua (Gel.bind_state).
  Requis au chargement par les branchements (gel_usines.lua, gel_usines_jeu.lua, gel_garnisons.lua, gel_banc.lua), jamais par un
  simple lecteur de Gel.status : un lecteur seul ne tire ni le stockage ni ses abonnements (8/11 : extension_fer_moteur,
  rebuild_avant_poste, reparation_test).
  État : { vstatus = { [unit] = statut comptable }, n_frozen, logs = { [clé] = n }, u = registre des usines, gar = garnisons }.
]]
local Storage = require("script.core.storage")
local Gel = require("script.faction.gel")

Storage.declare("gel", function()
  return { vstatus = {}, n_frozen = 0, logs = {}, u = nil }
end)

Gel.bind_state(function()
  local fo = Storage.raw()
  return fo and fo.gel
end)

return {}
