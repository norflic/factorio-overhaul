--- Lot CHARBON-CAPACITE (F485, 0.6.86) : bilan du combustible du planificateur, cadences LUES AUX DONNÉES.
---
--- Avant : shared/team/planner.lua comparait la production des avant-postes de charbon à la consommation des brûleurs avec des
--- cadences en dur (0,25 charbon/s par foreuse, 0,0375 brûlé par foreuse, 0,0225 par four de pierre) et reconnaissait l'avant-poste
--- de combustible par son NOM (o.kind == "coal"), le four par son nom (spec.sink == "stone-furnace").
--- Ici : cadence d'extraction = vitesse de minage de la foreuse / temps de minage de la ressource du combustible ; brûlé =
--- puissance du brûleur / valeur calorifique du combustible ; avant-poste de combustible = celui dont le PRODUIT est le combustible ;
--- un puits (sink) brûle s'il a un brûleur dans la table des machines. Règle pure : la table des machines (M.spec), la valeur du
--- combustible (kJ) et le temps de minage sont passés par l'appelant.
local Bc = {}

Bc.MARGIN = 1.4 -- marge du bilan (inchangée) : un avant-poste de combustible de plus sous 40 % de marge

--- Cadences par entité, depuis les données. d = { spec = fonction(nom) -> { speed, burner_kw }, drill = nom de la foreuse,
--- fuel_kj = valeur calorifique du combustible (kJ), mining_time = temps de minage de la ressource du combustible (s) }.
--- Rend { drill_out, drill_burn, burn_of = fonction(nom) -> charbon/s } ou nil, raison.
function Bc.rates(d)
  if type(d) ~= "table" or type(d.spec) ~= "function" then return nil, "pas de table des machines" end
  local ds = d.spec(d.drill)
  if not ds or not ds.speed then return nil, "foreuse inconnue : " .. tostring(d.drill) end
  if not d.fuel_kj or d.fuel_kj <= 0 then return nil, "combustible sans valeur calorifique" end
  if not d.mining_time or d.mining_time <= 0 then return nil, "temps de minage inconnu" end
  local fuel_kj, spec = d.fuel_kj, d.spec
  local function burn_of(name)
    local s = name and spec(name)
    return (s and s.burner_kw and s.burner_kw > 0) and s.burner_kw / fuel_kj or 0
  end
  return { drill_out = ds.speed / d.mining_time, drill_burn = burn_of(d.drill), burn_of = burn_of }
end

--- Bilan : production et brûlé des avant-postes (liste { kind, drills }), des fours de fonderie (n) et du plan directeur (charbon/s).
--- cfg = T.outposts (kind -> { product, sink }), fuel = nom du combustible.
function Bc.balance(outposts, cfg, fuel, r, smelters, smelter_name, build_burn)
  local coal_rate, burn_rate = 0, 0
  for _, o in ipairs(outposts) do
    local spec = cfg[o.kind]
    if spec and spec.product == fuel then coal_rate = coal_rate + o.drills * r.drill_out end
    burn_rate = burn_rate + o.drills * r.drill_burn + o.drills * r.burn_of(spec and spec.sink)
  end
  burn_rate = burn_rate + (smelters or 0) * r.burn_of(smelter_name) + (build_burn or 0)
  return coal_rate, burn_rate
end

function Bc.need_more(coal_rate, burn_rate) return coal_rate < Bc.MARGIN * burn_rate end

return Bc
