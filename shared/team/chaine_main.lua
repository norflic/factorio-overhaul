--[[
  TOURNÉE DE FONTE UTILE (lot FOURS, 29/10) : PUR (aucune API Factorio, aucun nom d'objet : les entrées de fonderie arrivent en
  DONNÉES, T.smelter_inputs). Remarque 13 du DC (D-26) : « minage à la main sans fonte quand l'électricité est coupée (les
  workers minent le fer à la main, le laissent non fondu...) ».

  Constat mesuré (fo-logs\2026-10-29_NUIT\MAINS\RAPPORT.md, 4 graines) : l'hypothèse « le PNJ garde le minerai » est réfutée
  (minerai porté médian 0, dépôt jamais refusé) ; en revanche 40 % des tournées « smelt » repartaient À VIDE (811 sur 2 019), et
  100 % pendant 30 min sur la graine 1618033988 : le planificateur demande une fonte dès qu'il existe un four, sans regarder si
  du minerai attend, si un four peut le recevoir, si une sortie vaut le déplacement ou si le charbon existe pour ravitailler.
  Et, depuis la charge à la pile (shared/team/charge_four.lua), repasser tant que les fours sont chargés ne sert à rien.

  Une tournée de fonderie est utile si, au choix :
    "sortie"       : au moins K plaques attendent en sortie (K = collect_min, abaissé à la demande quand elle est plus petite) ;
    "combustible"  : un four manque de combustible ET le coffre en a ;
    "minerai"      : du minerai attend pour un produit demandé ET un four est libre (entrée vide ou bloquée) ;
    "complement"   : un four tombé au tiers de sa pile porte une entrée dont le coffre a au moins une fabrication (une entrée
                     qui est elle-même un produit de fonte, l'acier d'après la plaque, n'est complétée que pour une demande).
  Sinon "fours-occupes" (du minerai attend mais tous les fours sont chargés) ou "rien".
    C.ready_products(smelt, inputs, stock)  produits demandés dont l'entrée attend au coffre
    C.smelt_worth(a)                        -> (utile, raison, produits_gardés)
    C.filter_tasks(tasks, ctx)              les tâches du plan sans les tournées « smelt » inutiles
  Déterminisme : listes triées, aucun `pairs` dans une décision.
]]

local C = {}

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Produits de `smelt` ({ [produit] = n }) dont l'entrée attend au stock : `inputs[produit] = { entrée, quantité par produit }`,
--- `stock[entrée]` = quantité libre. Rend { [produit] = n } (copie).
function C.ready_products(smelt, inputs, stock)
  local out = {}
  for _, p in ipairs(sorted_keys(smelt)) do
    local inp = inputs and inputs[p]
    if inp and ((stock and stock[inp[1]]) or 0) >= inp[2] then out[p] = smelt[p] end
  end
  return out
end

-- Plus petite quantité d'entrée par fabrication pour `item` (nil : l'objet n'est l'entrée d'aucun produit).
local function ratio_of(inputs, item)
  local best
  for _, p in ipairs(sorted_keys(inputs)) do
    local inp = inputs[p]
    if inp[1] == item and (not best or inp[2] < best) then best = inp[2] end
  end
  return best
end

-- L'entrée `item` est-elle demandée (un produit qui la consomme figure à la demande) ?
local function demanded(smelt, inputs, item)
  for _, p in ipairs(sorted_keys(smelt)) do
    local inp = inputs and inputs[p]
    if inp and inp[1] == item and (smelt[p] or 0) > 0 then return true end
  end
  return false
end

--- a = { smelt, inputs, stock, output, fuel_low, fuel_stock, free, loads, collect_min }
---   output : plaques en sortie des fours ; fuel_low : un four manque de combustible ; fuel_stock : combustible libre au coffre
---   (nil = inconnu : on suppose qu'il y en a) ; free : fours libres (nil = inconnu : on suppose qu'un four est libre) ;
---   loads : { [entrée] = nombre de fours tombés au tiers de leur pile avec cette entrée } (nil : aucun) ; collect_min : seuil
---   de sortie (nil : 1).
--- Rend (utile, raison, produits_gardés).
function C.smelt_worth(a)
  local inputs, stock, smelt = a.inputs, a.stock, a.smelt or {}
  local kept = C.ready_products(smelt, inputs, stock)
  local threshold = a.collect_min or 1
  local total = 0
  for _, p in ipairs(sorted_keys(smelt)) do total = total + (smelt[p] or 0) end
  if total > 0 and total < threshold then threshold = total end
  if threshold < 1 then threshold = 1 end
  if (a.output or 0) >= threshold then return true, "sortie", kept end
  if a.fuel_low and (a.fuel_stock == nil or a.fuel_stock >= 1) then return true, "combustible", kept end
  if next(kept) ~= nil and (a.free == nil or a.free > 0) then return true, "minerai", kept end
  for _, item in ipairs(sorted_keys(a.loads)) do
    local n = a.loads[item]
    local ratio = ratio_of(inputs, item)
    if n and n > 0 and ratio and ((stock and stock[item]) or 0) >= ratio
      and (not (inputs and inputs[item]) or demanded(smelt, inputs, item)) then
      return true, "complement", kept
    end
  end
  if next(kept) ~= nil then return false, "fours-occupes", kept end
  return false, "rien", kept
end

--- Retire du plan les tournées « smelt » inutiles. ctx = { inputs, stock, output, fuel_low, fuel_stock, free, loads, collect_min }.
--- Rend (tâches, retirées). Les autres tâches passent sans copie ; une tournée gardée est copiée (la tâche du plan n'est pas
--- modifiée) avec les seuls produits dont l'entrée est au coffre.
function C.filter_tasks(tasks, ctx)
  local out, dropped = {}, 0
  for _, t in ipairs(tasks or {}) do
    if t.kind == "smelt" then
      local worth, _, kept = C.smelt_worth({ smelt = t.smelt, inputs = ctx.inputs, stock = ctx.stock, output = ctx.output,
        fuel_low = ctx.fuel_low, fuel_stock = ctx.fuel_stock, free = ctx.free, loads = ctx.loads, collect_min = ctx.collect_min })
      if worth then
        local c = {}
        for _, k in ipairs(sorted_keys(t)) do c[k] = t[k] end
        c.smelt = kept
        out[#out + 1] = c
      else
        dropped = dropped + 1
      end
    else
      out[#out + 1] = t
    end
  end
  return out, dropped
end

return C
