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
  Sans quota (projet de site sans débit déclaré, projet planifié avant 0.6.59, aucun coffre de sortie bâti) : l'ancienne règle, à
  l'identique.
  Lot VIDEO-COUVERTURE 3 (C11, C3.2) : un module à PLUSIEURS produits (bloc de mall, chaîne à co-produit) a lui aussi un quota : chaque coffre de
  sortie porte tous les produits à pile connue, et la barre du coffre se PARTAGE en parts par produit (Qt.share : 10 min du débit de chacun, ramenées
  aux cases ouvertes sans jamais priver un produit de sa première case). La barre, la collecte (au plus la moitié de la capacité) et le verdict
  « sortie pleine » (90 %) se lisent sur le TOTAL du coffre : le compte par produit n'est pas relevé (build.lua passe le total) et une collecte
  qui n'attend que la moitié du TOTAL ne peut pas être contournée par un produit seul à 90 % de sa part.
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
-- Lot TV-FLUX (C11) : réglage de carte ALLUMÉ par défaut (settings/flux.lua) ; absent (moteur simulé des tests) = éteint.
Qg.PIECES_SETTING = "fo-war-quotas-pieces"
function Qg.pieces_on()
  local ok, v = pcall(function() return settings.global[Qg.PIECES_SETTING].value end)
  return ok and v == true
end

--- Part de machines posées d'un projet : (posées, prévues) quand des machines à recette MANQUENT et que le réglage est allumé, sinon nil.
function Qg.pieces(p)
  if not Qg.pieces_on() then return nil end
  local num, den = Qt.pieces(p.ents)
  if den <= 0 or num >= den then return nil end
  return num, den
end

function Qg.of(p, slots, in_slots, collect_at)
  if type(p.outflow) ~= "table" or type(slots) ~= "number" or slots < 1 or #(p.outs or {}) == 0 then return nil end
  local num, den = Qg.pieces(p)
  local key = string.format("%d:%d:%d:%d:%d%s", #p.outs, #(p.quais or {}), slots, in_slots or slots, collect_at or 0,
    num and string.format(":p%d/%d", num, den) or "")
  if p.quota_key == key then return p.quota or nil end
  -- Lot TV-FLUX (C11) : le débit pris en compte suit les machines posées (une ligne [FO-QUOTAS] par changement de part)
  local outflow, inflow = p.outflow, p.inflow
  local share = num and string.format("%d/%d", num, den) or "tout"
  if (p.quota_share or "tout") ~= share then
    if num then
      log(string.format("[FO-QUOTAS] projet %s : %d machine(s) a recette posee(s) sur %d prevue(s) : debits nominaux x %s", tostring(p.id), num, den, share))
    else
      log(string.format("[FO-QUOTAS] projet %s : toutes les machines a recette sont posees : debits nominaux", tostring(p.id)))
    end
  end
  p.quota_share = share
  if num then outflow, inflow = Qt.scale(outflow, num, den), Qt.scale(inflow, num, den) end
  local products = {}
  for _, k in ipairs(sorted_keys(outflow)) do
    if (outflow[k] or 0) > 0 and stack(k) then products[#products + 1] = k end
  end
  local q = false
  if #products >= 1 then -- chaque coffre de sortie porte tous les produits à pile connue (un seul : le cas d'avant, à l'identique)
    local outs, ins = {}, {}
    for i = 1, #p.outs do
      local items = {}
      if #products > 1 then for j, k in ipairs(products) do items[j] = k end end
      outs[i] = (#products > 1) and { items = items } or {}
    end
    for i, c in ipairs(p.quais or {}) do ins[i] = { item = c.item } end
    -- une pile au moins par voyage d'alimentation (supposé, à mesurer sur [FO-ACTIF] : une minute de charbon d'un four, c'est 3 objets)
    q = Qt.quotas(outflow, inflow, outs, ins, { stack = stack, slots = slots, in_slots = in_slots, collect_at = collect_at, lot_min = stack })
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
