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
    "bloque"       : (lot BRIQUES) un four est à sortie PLEINE d'un autre objet que celui qu'il fond (4 fours chargés de pierre,
                     une plaque d'acier restée en sortie : arrêtés pour toujours, 50 min sans une brique) ; la tournée vide les
                     sorties, le four repart ;
    "partage"      : (lot BRIQUES) un produit demandé, dont l'entrée attend au coffre, n'a AUCUN four, alors qu'aucun four n'est
                     vide et qu'un four d'une autre entrée peut lui être repris (C.releases). Constat mesuré (graine 271828182,
                     banc BRIQUES) : les fours complétés au tiers de leur pile par la demande d'acier ne se vidaient jamais, la
                     brique du centre n'avait jamais de four (stock de briques constant 35 à 50 min, pierre 2 000 à 10 000).
  Sinon "fours-occupes" (du minerai attend mais tous les fours sont chargés) ou "rien".
    C.ready_products(smelt, inputs, stock)  produits demandés dont l'entrée attend au coffre
    C.releases(furnaces, smelt, inputs, stock)  indices des fours à vider pour servir un produit sans four (lot BRIQUES)
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

-- Entrées DEMANDÉES : { [entrée] = demande totale (en produits) } des produits demandés dont l'entrée attend au coffre
-- (`stock` absent : l'entrée est supposée là).
local function wanted_inputs(smelt, inputs, stock)
  local out = {}
  for _, p in ipairs(sorted_keys(smelt)) do
    local inp = inputs and inputs[p]
    local n = (smelt and smelt[p]) or 0
    if inp and n > 0 and (stock == nil or (stock[inp[1]] or 0) >= inp[2]) then out[inp[1]] = (out[inp[1]] or 0) + n end
  end
  return out
end

--- Lot BRIQUES : les fours à VIDER pour que chaque produit demandé sans four en reçoive un. `furnaces` = liste dans l'ordre de
--- la fonderie de { item = entrée portée (absent : four vide ou bloqué, donc libre), count = quantité } ; `smelt` = { [produit] =
--- demande } ; `inputs` = { [produit] = { entrée, quantité } } ; `stock` = { [entrée] = quantité disponible } (absent : présente).
--- Rend la liste (croissante) des indices de fours à vider. Un seul four par produit sans four, jamais le dernier four d'une
--- entrée encore demandée ; le donneur est un four d'une entrée non demandée d'abord, puis celui de l'entrée qui a le plus de
--- fours, puis le moins chargé, puis le premier. Rien quand un four est libre (la charge ordinaire le sert).
function C.releases(furnaces, smelt, inputs, stock)
  local want = wanted_inputs(smelt, inputs, stock)
  local holds, free = {}, 0
  for _, f in ipairs(furnaces or {}) do
    if f.item then holds[f.item] = (holds[f.item] or 0) + 1 else free = free + 1 end
  end
  if free > 0 then return {} end
  local starved = {}
  for _, item in ipairs(sorted_keys(want)) do
    if (holds[item] or 0) == 0 then starved[#starved + 1] = item end
  end
  table.sort(starved, function(a, b)
    if want[a] ~= want[b] then return want[a] > want[b] end
    return a < b
  end)
  local used, out = {}, {}
  for _ = 1, #starved do
    local best, bk
    for i, f in ipairs(furnaces) do
      if not used[i] and f.item and (not want[f.item] or holds[f.item] >= 2) then
        local k1 = want[f.item] and 1 or 0
        local k2 = -holds[f.item]
        local k3 = f.count or 0
        if not best or k1 < bk[1] or (k1 == bk[1] and (k2 < bk[2] or (k2 == bk[2] and k3 < bk[3]))) then
          best, bk = i, { k1, k2, k3 }
        end
      end
    end
    if not best then break end
    used[best] = true
    holds[furnaces[best].item] = holds[furnaces[best].item] - 1
    out[#out + 1] = best
  end
  table.sort(out)
  return out
end

--- a = { smelt, inputs, stock, output, fuel_low, fuel_stock, free, loads, collect_min, blocked, furnaces }
---   blocked : fours à sortie pleine (nil : aucun) ; furnaces : descripteurs des fours pour C.releases (nil : pas de partage)
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
  if (a.blocked or 0) > 0 then return true, "bloque", kept end
  if a.furnaces and next(kept) ~= nil and next(C.releases(a.furnaces, kept, inputs, stock)) ~= nil then return true, "partage", kept end
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

--- Retire du plan les tournées « smelt » inutiles. ctx = { inputs, stock, output, fuel_low, fuel_stock, free, loads, collect_min, blocked, furnaces }.
--- Rend (tâches, retirées). Les autres tâches passent sans copie ; une tournée gardée est copiée (la tâche du plan n'est pas
--- modifiée) avec les seuls produits dont l'entrée est au coffre.
function C.filter_tasks(tasks, ctx)
  local out, dropped = {}, 0
  for _, t in ipairs(tasks or {}) do
    if t.kind == "smelt" then
      local worth, _, kept = C.smelt_worth({ smelt = t.smelt, inputs = ctx.inputs, stock = ctx.stock, output = ctx.output,
        fuel_low = ctx.fuel_low, fuel_stock = ctx.fuel_stock, free = ctx.free, loads = ctx.loads, collect_min = ctx.collect_min,
        blocked = ctx.blocked, furnaces = ctx.furnaces })
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
