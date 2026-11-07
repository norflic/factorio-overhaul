--[[
  Lot VIDEO L4, branchement (INTEGRATION_VIDEO.md étape 9) : la colle entre le plan directeur (script/team/build.lua, quai_tasks et
  out_tasks) et la règle pure des quotas (shared/team/quotas.lua, Qt). Requise au CHARGEMENT par build.lua dans un champ de sa table
  (`Build.Quotas`) : le bloc principal de build.lua est à 199 locales sur 200, aucune locale de plus n'y tient.

  Ce qui change :
    - out_tasks : le seuil de collecte d'un coffre de sortie ne dépasse jamais la moitié de sa capacité sous le quota (Qt.COLLECT_PM) ;
      une sortie arrêtée par le quota reste donc toujours collectée (sinon interblocage) ;
    - quai_tasks : un module dont les sorties atteignent 90 % du quota (Qt.FULL_PM) n'est plus ALIMENTÉ (V27 : ses ingrédients restent
      pour les autres) ; la COLLECTE n'est jamais retenue ; une entrée se remplit d'une minute d'ingrédients (V25), refaite sous la
      moitié, au lieu de QUAI_LOW et QUAI_FILL ; au moins une pile par voyage (nos PNJ portent par voyages, la vidéo a des tapis).
  Sans quota (projet de site sans débit déclaré, projet planifié avant 0.6.59, module à plusieurs produits, aucun coffre de sortie
  bâti) : l'ancienne règle, à l'identique.
  Le quota est gardé dans le projet (p.quota, p.quota_key : sérialisables, aucune fonction) et recalculé quand le nombre de coffres
  ou leurs cases ouvertes changent. La pile d'un objet est lue aux prototypes (game.item_prototypes), jamais écrite ici ; aucun nom
  d'objet ni de coffre (anti-échelle de tests/iag_test.lua §8 bis).
]]

local Qt = require("shared.team.quotas")

local Qg = {}
Qg.Qt = Qt

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function stack(it)
  local pr = game.item_prototypes[it]
  return pr and pr.stack_size or nil
end

--- Quota du projet p : `slots` = cases ouvertes d'un coffre de sortie (sous sa barre), `in_slots` = cases d'un coffre d'entrée,
--- `collect_at` = seuil de collecte de l'appelant. Rend la table de Qt.quotas, ou nil (pas de quota : ancienne règle).
function Qg.of(p, slots, in_slots, collect_at)
  if type(p.outflow) ~= "table" or type(slots) ~= "number" or slots < 1 or #(p.outs or {}) == 0 then return nil end
  local key = string.format("%d:%d:%d:%d:%d", #p.outs, #(p.quais or {}), slots, in_slots or slots, collect_at or 0)
  if p.quota_key == key then return p.quota or nil end
  local products = 0
  for _, k in ipairs(sorted_keys(p.outflow)) do
    if (p.outflow[k] or 0) > 0 and stack(k) then products = products + 1 end
  end
  local q = false
  if products == 1 then -- un seul produit en coffre : chaque coffre de sortie le porte (plusieurs : bloc de mall, sa barre est Id.barre)
    local outs, ins = {}, {}
    for i = 1, #p.outs do outs[i] = {} end
    for i, c in ipairs(p.quais or {}) do ins[i] = { item = c.item } end
    -- une pile au moins par voyage d'alimentation (supposé, à mesurer sur [FO-ACTIF] : une minute de charbon d'un four, c'est 3 objets)
    q = Qt.quotas(p.outflow, p.inflow, outs, ins, { stack = stack, slots = slots, in_slots = in_slots, collect_at = collect_at, lot_min = stack })
  end
  p.quota, p.quota_key = q, key
  return q or nil
end

--- Seuil de collecte du coffre de sortie i : celui de l'appelant (`base`), borné par le quota.
function Qg.collect_at(q, i, base)
  local o = q and q.outs and q.outs[i]
  if o and o.collect_at then return math.min(base, o.collect_at) end
  return base
end

--- Le module peut-il être alimenté ? Toujours vrai sans quota.
function Qg.feed_ok(q, counts)
  if not q then return true end
  return Qt.feed_ok(q, counts)
end

--- Remplissage du coffre d'entrée i (n objets au coffre, `have` au stock) : une minute d'ingrédients sous le quota, sinon l'ancienne
--- règle (sous `low`, jusqu'à `fill`). Rend { due, count }.
function Qg.refill(q, i, n, have, low, fill)
  local qin = q and q.ins and q.ins[i]
  if qin and not qin.free then return Qt.refill(qin, n, have) end
  local due = n < low and have > 0
  return { due = due, count = due and math.min(fill - n, have) or 0 }
end

return Qg
