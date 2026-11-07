--[[
  Lot FOREUSES-THERMIQUES, RÉSERVE D'AMORÇAGE du combustible (décision du lead, 7/11 vers 19 h 10 : exception de SÛRETÉ à « Remplacer au
  fur et à mesure », dite au DC, qui peut la refuser). Interblocage évité : réseau tombé → foreuses de charbon électriques arrêtées →
  centrale sans charbon → réseau mort. Un avant-poste de COMBUSTIBLE garde ses K dernières thermiques ; K = S.coal_reserve (règle pure,
  shared/team/foreuse_swap.lua) sur les DONNÉES lues ici.

  Lecteurs : le remplacement sur place (script/team/foreuse_swap.lua) ; le balayage et le retrait à sec du champ
  (script/team/migration_champ.lua). Module LÉGER (aucun module du jeu au-delà des données et de la règle pure) : le champ s'en sert
  sans tirer l'exécutant des foreuses ni ses dépendances.
]]

local T = require("shared.team.config")
local M = require("shared.team.modules")
local S = require("shared.team.foreuse_swap")

local Ra = {}

--- L'avant-poste extrait-il le COMBUSTIBLE des brûleurs et des chaudières ? (ressource ou produit = T.fuel : la règle du minerai critique de
--- migration_champ, `spec.resource == T.fuel`, et le charbon brut des avant-postes à coffre.)
function Ra.fuel_outpost(o)
  local sp = o and o.kind and T.outposts[o.kind]
  return sp ~= nil and (sp.resource == T.fuel or sp.product == T.fuel)
end

--- Thermiques gardées par avant-poste de combustible (S.coal_reserve). Chaudière : la plus puissante des centrales du plan directeur de
--- l'équipe (première partie « centrale », comme le bilan du charbon de build.lua ; une chaudière boit de l'eau et brûle), sinon celle des
--- données de base ; thermique : cadence au prototype (productivité de la force comprise) et combustion aux données ; combustible : valeur
--- de l'objet. Rend keep et la donnée lue (journal).
function Ra.keep(f)
  local boiler_kw = 0
  local b = f and f.build
  for _, id in ipairs(b and b.order or {}) do
    local p = b.projects and b.projects[id]
    if p and p.parts and p.parts[1] and p.parts[1].kind == "centrale" then
      for _, e in ipairs(p.ents or {}) do
        local sp = M.spec(e.name)
        if sp and sp.water and sp.burner_kw and sp.burner_kw > boiler_kw then boiler_kw = sp.burner_kw end
      end
    end
  end
  if boiler_kw <= 0 and M.BASE and M.BASE.boiler then boiler_kw = M.BASE.boiler.burner_kw or 0 end
  local fuel_kind
  for _, k in ipairs(T.OUTPOST_ORDER) do if not fuel_kind and Ra.fuel_outpost({ kind = k }) then fuel_kind = k end end
  local dp = game.entity_prototypes[T.DRILL]
  local rp = fuel_kind and game.entity_prototypes[T.outposts[fuel_kind].resource]
  local mt = rp and rp.mineable_properties and rp.mineable_properties.mining_time
  local force = game.forces and f and game.forces[f.force]
  local prod = force and force.mining_drill_productivity_bonus or 0
  local rate = (dp and dp.mining_speed and mt and mt > 0) and dp.mining_speed / mt * (1 + prod) or nil
  local dsp = M.spec(T.DRILL)
  local ip = game.item_prototypes and game.item_prototypes[T.fuel]
  local d = { boiler_kw = boiler_kw, fuel_kj = (ip and ip.fuel_value and ip.fuel_value > 0) and ip.fuel_value / 1000 or M.COAL_J,
    drill_rate = rate, drill_kw = dsp and dsp.burner_kw }
  return S.coal_reserve(d), d
end

return Ra
