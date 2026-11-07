--[[
  Lot POULS (7/11, fo-logs\2026-11-07_POULS\CRITERES.md) : JETON du tick pour les relevés lourds du pouls du chantier
  (script/team/build.lua, Build.PULSE). Au plus UN par tick, toutes équipes confondues : une bande du relevé du réseau
  (script/team/reseau_vivant.lua) ou un début de relevé du raccordement (script/team/raccord.lua). Qui le trouve pris remet son travail
  à la passe suivante. MESURÉ avant ce lot sur la sauvegarde du DC : bp:reseau 153 ms et bp:raccord 99 ms au même tick (935405).

  Table LOCALE (jamais dans global) : elle ne vaut que pendant le tick où elle est prise. Le premier preneur d'un tick ne dépend que de
  l'ordre des appels (équipes dans l'ordre de Build, puis Rv avant Ra) : déterministe, et identique après un chargement (un tick ne
  s'interrompt pas par une sauvegarde).
]]

local J = {}

local held = -1

--- Vrai si le jeton du tick `tick` était libre (il est alors pris) ; faux s'il est déjà pris à ce tick.
function J.take(tick)
  if held == tick then return false end
  held = tick
  return true
end

--- Bancs hors jeu seulement : rend le jeton (nouvelle partie simulée).
function J.reset() held = -1 end

return J
