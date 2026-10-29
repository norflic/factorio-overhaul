--[[
  CHAÎNE « mine à la main -> fonte -> dépôt » des équipes de PNJ (lot MAINS-CHAINE, 29/10) : PUR (aucune API Factorio, aucun
  nom d'objet : les entrées de fonderie arrivent en DONNÉES, T.smelter_inputs).

  Constat mesuré (fo-logs\2026-10-29_NUIT\MAINS\CRITERES.md §Cause, 4 graines, relevés [FO-FONCTION] chaine) :
    * aucun PNJ ne garde de minerai (médiane 0, jamais 50 ou plus) et le dépôt au coffre n'est jamais refusé (depot_refuse = 0) :
      l'hypothèse « inventaire gardé / coffre plein » est RÉFUTÉE ;
    * 40 % des tournées « smelt » repartent À VIDE (811 sur 2 019), et 100 % pendant 30 min sur la graine 1618033988 (350 tournées,
      huit PNJ au chômage, 0 minerai : le minage est refusé pour danger) : le planificateur demande une fonte dès qu'il existe un
      four, sans regarder si du minerai attend, si un four est libre, si une sortie est à vider ou un four à ravitailler ;
    * le travail de fond (shared/team/fond.lua) mine à la main chaque ressource A TOUR DE RÔLE, même celle dont le stock libre
      atteint déjà la cible (écart 0) : le minerai s'entasse au coffre (20261020 : 118 -> 389 en 20 min de coupure, cible 200).

  Deux règles, toutes deux « ne pas faire ce qui ne sert à rien » ; elles ne créent aucune tâche :
    C.smelt_worth(a)      -> vrai si une tournée de fonderie a quelque chose à faire (voir plus bas) ;
    C.filter_tasks(tasks, ctx) -> les tâches du plan sans les tournées « smelt » à vide ; une tournée utile garde seulement
                            les produits dont le minerai est au coffre ;
    C.mine_candidates(list)    -> les ressources à miner à la main : un MINERAI dont le stock couvre sa cible (écart 0) est écarté
                            tant qu'une autre ressource est en manque (jamais plus d'inactifs : le travail va à ce qui manque).
  Déterminisme : listes triées, aucun `pairs` dans une décision.
]]

local C = {}

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Produits de `smelt` ({ [produit] = n }) dont le minerai attend au stock : `inputs[produit] = { entrée, quantité par produit }`,
--- `stock[entrée]` = quantité libre. Rend { [produit] = n } (copie, ordre sans importance).
function C.ready_products(smelt, inputs, stock)
  local out = {}
  for _, p in ipairs(sorted_keys(smelt)) do
    local inp = inputs and inputs[p]
    if inp and ((stock and stock[inp[1]]) or 0) >= inp[2] then out[p] = smelt[p] end
  end
  return out
end

--- Une tournée de fonderie est utile si, au choix : (a) du minerai attend pour un produit demandé ET un four peut le recevoir
--- (`free` nil = inconnu : on suppose qu'un four est libre ; 0 : tous occupés) ; (b) une sortie de four attend d'être vidée ;
--- (c) un four manque de combustible.
--- a = { smelt, inputs, stock, output, fuel_low, free } ; rend (utile, raison, produits_gardés).
function C.smelt_worth(a)
  local kept = C.ready_products(a.smelt, a.inputs, a.stock)
  if (a.output or 0) > 0 then return true, "sortie", kept end
  if a.fuel_low then return true, "combustible", kept end
  if next(kept) ~= nil and (a.free == nil or a.free > 0) then return true, "minerai", kept end
  if next(kept) ~= nil then return false, "fours-occupes", kept end
  return false, "rien", kept
end

--- Retire du plan les tournées « smelt » à vide. ctx = { inputs, stock, output, fuel_low, free }. Rend (tâches, retirées).
--- Les autres tâches passent sans copie ; une tournée gardée est copiée (la tâche du plan n'est pas modifiée) avec les seuls
--- produits dont le minerai est au coffre.
function C.filter_tasks(tasks, ctx)
  local out, dropped = {}, 0
  for _, t in ipairs(tasks or {}) do
    if t.kind == "smelt" then
      local worth, _, kept = C.smelt_worth({ smelt = t.smelt, inputs = ctx.inputs, stock = ctx.stock, output = ctx.output,
        fuel_low = ctx.fuel_low, free = ctx.free })
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

--- Candidats au minage à la main du travail de fond : `list` = { { res, gap, i, ore } ... } (gap 0 : stock >= cible ; ore :
--- vrai pour un minerai que la fonderie doit fondre). Un minerai en écart 0 est écarté si une autre ressource a un écart > 0 ;
--- si rien ne manque, la liste est rendue telle quelle (comportement d'avant : le travail de fond ne devient pas du chômage).
function C.mine_candidates(list)
  local need = false
  for _, m in ipairs(list) do
    if m.gap > 0 then need = true break end
  end
  if not need then return list end
  local out = {}
  for _, m in ipairs(list) do
    if not (m.ore and m.gap <= 0) then out[#out + 1] = m end
  end
  return out
end

return C
