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
  Lot TV-QUOTAS (C11, « sans modules, recalculer les quotas ») : le gabarit chiffre ses débits SANS module. Qg.measure relève, toutes les
  Qt.MEASURE_TICKS ticks, la vitesse et la productivité RÉELLES des machines posées du projet (bonus du moteur : modules posés par les PNJ
  ou le joueur, balise cachée comprise) ; Qt.ratios en tire un rapport de sortie et un rapport d'entrée (p.qm_out, p.qm_in, ‰ entiers,
  sérialisables) que Qg.of applique aux débits avant de calculer le quota. Le rapport entre dans la clé du quota : modules posés ou RETIRÉS,
  le quota est recalculé (et la barre des coffres refaite par script/ai3/industrie.lua, qui lit la clé). Sans module : clé et quota d'avant,
  à l'identique. Journal : [FO-QUOTA-MODULES] (une ligne par changement de rapport, au plus Qg.LOGS par force).
]]

local Qt = require("shared.team.quotas")

local Qg = {}
Qg.Qt = Qt
Qg.LOGS = 60 -- lignes [FO-QUOTA-MODULES] au plus par force
local MACHINE_TYPES = { ["assembling-machine"] = true, furnace = true, ["mining-drill"] = true }
local TYPE_OF = {} -- mémo des types de prototypes (données statiques : rien dans global)

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

local function type_of(name)
  local t = TYPE_OF[name]
  if t == nil then
    local pr = game.entity_prototypes and game.entity_prototypes[name]
    t = pr and pr.type or false
    TYPE_OF[name] = t
  end
  return t
end

local function pm(x) return math.floor((type(x) == "number" and x or 0) * 1000 + 0.5) end

--- Lot TV-QUOTAS (C11) : relève les machines posées du projet p (p.ents) et pose p.qm_out, p.qm_in (‰ ; nil = ancienne règle). Au plus une
--- fois par Qt.MEASURE_TICKS ticks et par projet (p.qm_tick). Rend vrai si le rapport a changé (le quota sera recalculé par Qg.of).
function Qg.measure(f, p, surface)
  if not Qt.MODULES_RATIO or type(p.outflow) ~= "table" or type(p.ents) ~= "table" or not surface then return false end
  local now = game.tick or 0
  if p.qm_tick and now >= p.qm_tick and now - p.qm_tick < Qt.MEASURE_TICKS then return false end
  p.qm_tick = now
  local ms = {}
  for _, e in ipairs(p.ents) do
    if MACHINE_TYPES[type_of(e.name)] then
      local ent = surface.find_entity(e.name, { e.x, e.y })
      if not ent then -- machine montée d'un niveau depuis la planification (autre nom, même centre) : le type et la force suffisent
        ent = surface.find_entities_filtered({ area = { { e.x - 0.1, e.y - 0.1 }, { e.x + 0.1, e.y + 0.1 } }, type = type_of(e.name), force = f.force, limit = 1 })[1]
      end
      if ent and ent.valid and ent.force.name == f.force then
        ms[#ms + 1] = { speed_pm = pm(ent.speed_bonus), prod_pm = pm(ent.productivity_bonus) }
      end
    end
  end
  local po, pi, n = Qt.ratios(ms)
  local was_o, was_i = p.qm_out or 1000, p.qm_in or 1000
  p.qm_out, p.qm_in = (po ~= 1000) and po or nil, (pi ~= 1000) and pi or nil
  if po == was_o and pi == was_i then return false end
  local st = f.build and f.build.stats
  if type(log) == "function" and st and (st.qm_logs or 0) < Qg.LOGS then
    st.qm_logs = (st.qm_logs or 0) + 1
    log(string.format("[FO-QUOTA-MODULES] %s : projet %s, %d machine(s) relevee(s) : sortie x%.2f (avant x%.2f), entree x%.2f (avant x%.2f) -> quota recalcule",
      tostring(f.key or f.force), tostring(p.id), n, po / 1000, was_o / 1000, pi / 1000, was_i / 1000))
  end
  return true
end

--- Quota du projet p : `slots` = cases ouvertes d'un coffre de sortie (sous sa barre), `in_slots` = cases d'un coffre d'entrée,
--- `collect_at` = seuil de collecte de l'appelant. Rend la table de Qt.quotas, ou nil (pas de quota : ancienne règle).
function Qg.of(p, slots, in_slots, collect_at)
  if type(p.outflow) ~= "table" or type(slots) ~= "number" or slots < 1 or #(p.outs or {}) == 0 then return nil end
  local key = string.format("%d:%d:%d:%d:%d", #p.outs, #(p.quais or {}), slots, in_slots or slots, collect_at or 0)
  local ro, ri = Qt.MODULES_RATIO and p.qm_out or nil, Qt.MODULES_RATIO and p.qm_in or nil
  if ro or ri then key = key .. string.format(":m%d:%d", ro or 1000, ri or 1000) end -- sans module : la clé d'avant, à l'identique
  if p.quota_key == key then return p.quota or nil end
  local products = {}
  for _, k in ipairs(sorted_keys(p.outflow)) do
    if (p.outflow[k] or 0) > 0 and stack(k) then products[#products + 1] = k end
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
    local outflow, inflow = p.outflow, p.inflow
    if ro or ri then outflow, inflow = Qt.scaled(outflow, ro or 1000), Qt.scaled(inflow, ri or 1000) end -- lot TV-QUOTAS (C11)
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
