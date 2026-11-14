--[[
  SITE SATURÉ (lot s45 charbon-colonie). Lua PUR.
  Avant : script/team/poles.lua ne demandait un site de plus d'un type d'avant-poste que si l'équipe dépassait son effectif de
  départ (`full`). Un gisement de départ minuscule ou coincé (charbon) saturait donc sans qu'aucun second site ne soit cherché :
  les fours et la centrale restaient remplis à la main.
  RÈGLE : un type EXPLOITÉ (au moins un avant-poste) dont aucun avant-poste ne peut plus grandir, sans site connu, demande un
  site de plus même sous l'effectif de départ ; un type non exploité garde l'ancienne garde (`full`). Hors `prudent` toujours.
  Aucun nom de ressource : tout arrive en données.
]]
local Ss = {}

--- in = { full, prudent, exploited (n avant-postes du type), growable (bool), sites (n sites connus) } -> bool
function Ss.wants_site(i)
  if i.prudent or i.growable or (i.sites or 0) > 0 then return false end
  if i.full then return true end
  return (i.exploited or 0) > 0
end

return Ss
