--[[
  RÉSERVE DE GISEMENTS (lot s42 reroutage, priorité 2, chantier 4.1 du DC : « l'IA explore trop peu »). Lua PUR.

  Constat (partie du DC du 13/11, 0.7.96, 4 h 15) : l'équipe du joueur n'a envoyé AUCUN éclaireur après son tour de fondation (0 à
  2,8 min) : 16 lignes [FO-IA3F] en tout. Les deux déclencheurs de l'exploration ne voient pas le besoin à venir :
    - la demande « site » (script/ai3/exploration.lua, auto_requests) n'existe que si f.site_needs[res] > 0, posé seulement quand AUCUN
      avant-poste de la ressource ne peut plus grandir (script/team/poles.lua) : on cherche quand c'est déjà trop tard ;
    - la veille (reconnaissance au rayon croissant) exclut l'équipe du joueur (`not f.is_player`).
  La règle écrite au-dessus de `f.site_needs = needs` (script/team/team.lua : « une réserve d'un site par type déjà exploité, pour
  l'expansion suivante ») n'a jamais été câblée.

  RÈGLE : besoin à venir d'une ressource EXPLOITÉE (au moins un avant-poste) = un gisement de réserve. Réserve = sites retenus par la
  prospection + gisements CONNUS (carte de l'équipe) dont le centre est hors de la boîte lue par chaque avant-poste de la ressource
  (rayon `radius` : celui où le plan du champ lit le gisement, donnée de script/team/champ.lua) : un morceau du gisement exploité ne
  compte pas. Réserve nulle : exploration demandée (raison « reserve ») ; réserve rétablie : la demande se ferme.
  Aucun nom de ressource : tout arrive en données. Déterminisme : listes triées, aucun `pairs`.
]]

local Rg = {}

--- in = { resources = { noms triés }, outposts = { [res] = { { x, y } } }, known = { [res] = { { x, y } } }, prospects = { [res] = n },
--- radius }. Rend { { res, outposts, prospects, known, spare } } pour chaque ressource exploitée, dans l'ordre de `resources`.
function Rg.bilan(input)
  local out = {}
  local r2 = (input.radius or 0) * (input.radius or 0)
  for _, res in ipairs(input.resources or {}) do
    local ops = (input.outposts or {})[res] or {}
    if #ops > 0 then
      local spare = 0
      local known = (input.known or {})[res] or {}
      for _, d in ipairs(known) do
        local far = true
        for _, o in ipairs(ops) do
          local dx, dy = d.x - o.x, d.y - o.y
          if dx * dx + dy * dy <= r2 then far = false; break end
        end
        if far then spare = spare + 1 end
      end
      local pr = (input.prospects or {})[res] or 0
      out[#out + 1] = { res = res, outposts = #ops, prospects = pr, known = #known, spare = spare + pr }
    end
  end
  return out
end

--- Ressources exploitées sans gisement de réserve (ordre de `resources`).
function Rg.wanted(input)
  local out = {}
  for _, b in ipairs(Rg.bilan(input)) do
    if b.spare == 0 then out[#out + 1] = b.res end
  end
  return out
end

return Rg
