--[[
  Lot EXPERIMENTAUX-PUISSANCE : PROPORTION de vie gardée dans les sauvegardes existantes (demande du lead du 6/11 : « conserve la
  PROPORTION de vie (santé × nouveau max / ancien max), sinon un géant à 100 % passe à 0,7 % »).

  Les maxima de PV des unités suivies (10 expérimentaux, 3 géants de robotsjeu, Bourdon) sont notés dans le stockage (`pv_max`, espace
  « experimentaux ») à la création de la partie et à chaque changement de configuration. Au changement de configuration, toute entité de
  ces prototypes dont le maximum a changé reçoit Ech.vie_gardee(vie, ancien, nouveau). Une sauvegarde d'avant la table prend comme anciens
  maxima ceux de la version d'avant la règle d'échelle (ANCIENS : lus dans les données de 38ee70e1, essai 0.6.53).
  Déterminisme : noms en liste triée, surfaces triées par nom ; aucun `pairs` décisionnel.
]]

local Events = require("script.core.events")
local K = require("script.robots.experimentaux_commun")
local Ech = require("shared.robots.echelle")
local Xp = require("shared.robots.experimentaux")
local Ro = require("shared.content.robots")

local V = {}

--- Maxima de PV d'avant la règle d'échelle (38ee70e1 : shared/robots/experimentaux.lua Xp.stats, shared/content/robots.lua, prototypes/bourdon.lua).
V.ANCIENS = {
  ["fo-xp-mat-foudre"] = 8197, ["fo-xp-geode"] = 4204, ["fo-xp-sarracenie"] = 23001, ["fo-xp-demi-vie"] = 36200, ["fo-xp-veilleuse"] = 418661,
  ["fo-xp-cairn"] = 129285, ["fo-xp-stylet"] = 188547, ["fo-xp-trombe"] = 498544, ["fo-xp-ixion"] = 834000, ["fo-xp-tournesol"] = 1870000,
  ["fo-robot-player-toroid"] = 834000, ["fo-robot-player-heliast"] = 1870000, ["fo-robot-player-crowned"] = 2660000,
  ["fo-bourdon"] = 60000,
}

--- Noms suivis, triés.
function V.noms()
  local out = {}
  for _, r in ipairs(Xp.ROBOTS) do out[#out + 1] = r.name end
  for _, r in ipairs(Xp.GEANTS) do out[#out + 1] = r.name end
  for _, r in ipairs(Ro.giants()) do out[#out + 1] = Ro.unit_name(Ro.PLAYER_OWNER, r.id) end
  out[#out + 1] = "fo-bourdon"
  table.sort(out)
  return out
end

local function maxima()
  local m = {}
  for _, n in ipairs(V.noms()) do
    local p = game.entity_prototypes[n]
    if p then m[n] = p.max_health end
  end
  return m
end

local function surfaces()
  local out = {}
  for _, s in pairs(game.surfaces) do out[#out + 1] = s end -- trié juste après
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

--- Applique la proportion de vie aux entités dont le maximum a changé ; rend le nombre d'entités ajustées.
function V.migrer()
  local s = K.S()
  if not s then return 0 end
  local anciens = s.pv_max or V.ANCIENS
  local nouveaux = maxima()
  local n = 0
  local surf = surfaces()
  for _, nom in ipairs(V.noms()) do
    local a, b = anciens[nom], nouveaux[nom]
    if a and b and a ~= b then
      for _, su in ipairs(surf) do
        for _, e in ipairs(su.find_entities_filtered({ name = nom })) do
          if e.valid and e.health then
            e.health = Ech.vie_gardee(e.health, a, b)
            n = n + 1
          end
        end
      end
      log(string.format("[FO-ECHELLE-VIE] %s : maximum %d -> %d, proportion de vie gardee", nom, a, b))
    end
  end
  s.pv_max = nouveaux
  if n > 0 then log(string.format("[FO-ECHELLE-VIE] %d entite(s) ajustee(s)", n)) end
  return n
end

Events.on_init(function()
  local s = K.S()
  if s then s.pv_max = maxima() end
end)
Events.on_configuration_changed(function() V.migrer() end)

return V
