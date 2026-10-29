--[[
  Lot INTEG-ECONOMIE (D5) : « sécuriser le site proche ». PUR (aucune API Factorio, aucun nom d'objet : les ressources sont des
  chaînes opaques), testé hors jeu par tests/integ_economie_test.lua.

  Le signal `f.site_blocked[ressource]` (script/faction/sites.lua, lot SITE-PROCHE) est posé tant qu'un site PROCHE d'une ressource est
  bloqué (perdu, écarté, hostile) ET que des sites plus lointains de la même ressource sont suspendus à cause de lui : la faction
  attend ce site plutôt que de partir loin. Avant ce lot personne ne lisait ce signal (constat de la relecture d'intégration de la
  0.6.17) : le site proche restait bloqué sans que rien ne le rende sûr, et la production qui en dépend attendait la fin de
  l'échéance. Réaction minimale : le site bloqué devient un lieu à COUVRIR par le front (shared/team/front.lua, lieu de type
  « couverture » : F.COVER_WANT tourelles à portée, posées quand aucun ennemi n'est à F.CALM_R tuiles). Le front respecte ses
  propres règles (plafond d'équipe, fer au-delà du plancher, priorité : la production d'abord, la défense juste après).
]]
local S = {}

S.MAX = 2 -- lieux de sécurisation suivis au plus (ressources les plus proches du QG d'abord)

--- blocked : { [ressource] = { x, y, d_blocked, until_tick, n } } (le signal de sites.lua) ; tick : le tick courant.
--- Rend { { key, x, y, n, resource } } triés par distance au QG croissante puis par ressource, au plus S.MAX ; key = "bloque:" .. ressource
--- (jamais une clé de cellule du front, qui sont des coordonnées).
function S.covers(blocked, tick)
  local list = {}
  local keys = {}
  for k in pairs(blocked or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, res in ipairs(keys) do
    local s = blocked[res]
    if type(s) == "table" and type(s.x) == "number" and type(s.y) == "number" and (s.until_tick or 0) > (tick or 0)
      and (s.n or 0) > 0 then
      list[#list + 1] = { key = "bloque:" .. tostring(res), x = s.x, y = s.y, n = 1, resource = res, d = s.d_blocked or 0 }
    end
  end
  table.sort(list, function(a, b)
    if a.d ~= b.d then return a.d < b.d end
    return a.resource < b.resource
  end)
  while #list > S.MAX do list[#list] = nil end
  for _, c in ipairs(list) do c.d = nil end
  return list
end

return S
