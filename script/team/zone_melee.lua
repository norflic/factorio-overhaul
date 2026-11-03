--[[
  Lot MELANGE2 : lecture de la zone d'une foreuse au moteur, module LÉGER (règle pure : shared/team/melange.lua). Il ne requiert que la
  règle pure : script/faction/outposts.lua (paires thermiques) peut le charger sans cycle, ce que script/team/melange.lua (qui requiert
  script/team/champ.lua, donc build.lua, donc outposts.lua) ne permettait pas.
  Lecture seule : aucune entité posée, retirée ni modifiée.
]]
local Mel = require("shared.team.melange")

local Z = {}

local CAT = {} -- mémoire LOCALE (prototypes seulement)
--- Catégorie de ressource d'un prototype (faux si ce n'est pas une ressource).
function Z.category(name)
  local c = CAT[name]
  if c == nil then
    local pp = game.entity_prototypes[name]
    c = pp and pp.resource_category or false
    CAT[name] = c
  end
  return c
end

--- Ressources minables dans la zone d'une foreuse du prototype `pr` posée au centre (x, y) : verdict, étrangers { { nom, tuiles } }.
function Z.zone_at(surface, pr, x, y, res)
  local rad = pr.mining_drill_radius or 0
  local cats = pr.resource_categories or {}
  local found, idx = {}, {}
  for _, r in ipairs(surface.find_entities_filtered({ area = { { x - rad, y - rad }, { x + rad, y + rad } }, type = "resource" })) do
    if r.valid and Mel.in_zone(r.position.x - x, r.position.y - y, rad) then
      local c = Z.category(r.name)
      if c and cats[c] then
        if not idx[r.name] then idx[r.name] = #found + 1; found[#found + 1] = { r.name, 0 } end
        found[idx[r.name]][2] = found[idx[r.name]][2] + 1
      end
    end
  end
  return Mel.zone_verdict(found, { [res] = true })
end

--- Zone d'une foreuse du prototype NOMMÉ `name` : "ok" | "melange", étrangers. Prototype ou ressource inconnus : "ok" (rien à juger).
function Z.verdict(surface, name, x, y, res)
  local pr = game.entity_prototypes[name]
  if not (pr and res) then return "ok", {} end
  return Z.zone_at(surface, pr, x, y, res)
end

return Z
