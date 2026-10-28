--[[
  LOT MAINS : « les PNJ travaillent à la main ce que les machines fournissent » (constat du DC, 28/10 : « des compagnons
  (autonomes) ont miné des ressources de fer par terre […] sachant qu'on a du fer qui sort » ; « ils prennent des minerais
  de fer par terre et ils les mettent dans des fours à côté, je ne comprends pas »). PUR (aucune API Factorio).

  1. MESURE (Mains.label, Mains.add, Mains.format) : chaque tâche terminée est rangée sous une étiquette « genre:détail »
     (suffixe « + » pour le travail de FOND), avec ses PNJ-secondes et ses unités. Les noms viennent de la tâche (ressource,
     plaques fondues, produit de l'avant-poste), jamais d'une liste écrite ici.
]]

local M = {}

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end
M.sorted_keys = sorted_keys

--- Étiquette d'une tâche : « genre », « genre:détail » ; « + » en fin pour le travail de fond. `product_of(outpost)` rend le
--- produit de l'avant-poste d'une tournée (nil : sans détail).
function M.label(task, product_of, saturated_of)
  local k = task.kind or "?"
  local detail
  if k == "mine" then
    detail = task.resource
  elseif k == "smelt" then
    local ks = sorted_keys(task.smelt)
    detail = #ks > 0 and table.concat(ks, "/") or "vide"
  elseif k == "service" then
    detail = product_of and product_of(task.outpost) or nil
  elseif k == "craft" then
    detail = task.item
  elseif k == "extend" or k == "build" then
    detail = task.outpost_kind
  end
  local lab = detail and (k .. ":" .. tostring(detail)) or k
  if task.fond then
    lab = lab .. "+"
  else
    -- origine hors fond : premier segment de la clé quand ce n'est pas le genre (« manque:mine:… », « crise:mine:… »)
    local first = type(task.key) == "string" and task.key:match("^([^:]+):") or nil
    if first and first ~= k then lab = lab .. "@" .. first end
  end
  -- « #sat » : la matière que la tâche fournit était SATURÉE (stock au-delà de plusieurs fois le besoin) à sa fin
  if saturated_of and saturated_of(task) then lab = lab .. "#sat" end
  return lab
end

--- Unités d'une tâche (minerai à miner, plaques à fondre, objets à fabriquer) ; 0 sinon.
function M.units(task)
  if task.kind == "mine" or task.kind == "craft" then return task.count or 0 end
  if task.kind == "smelt" then
    local n = 0
    for _, p in ipairs(sorted_keys(task.smelt)) do n = n + (task.smelt[p] or 0) end
    return n
  end
  return 0
end

--- Range une tâche terminée dans `acc` (étiquette -> { ok, ko, secs, units }). `secs` : PNJ-secondes depuis la prise.
function M.add(acc, label, ok, secs, units)
  local a = acc[label]
  if not a then a = { ok = 0, ko = 0, secs = 0, units = 0 }; acc[label] = a end
  if ok then a.ok = a.ok + 1; a.units = a.units + (units or 0) else a.ko = a.ko + 1 end
  a.secs = a.secs + math.max(0, secs or 0)
end

--- Texte « étiquette=ok/ko secs unités » dans l'ordre des étiquettes (lisible au journal).
function M.format(acc)
  local out = {}
  for _, lab in ipairs(sorted_keys(acc)) do
    local a = acc[lab]
    out[#out + 1] = string.format("%s=%d/%d,%ds,%du", lab, a.ok, a.ko, math.floor(a.secs + 0.5), a.units)
  end
  return table.concat(out, " ")
end

---------------------------------------------------------------------------------------------------
-- 2. RÈGLE : quand le travail À LA MAIN de FOND d'une matière est inutile
---------------------------------------------------------------------------------------------------
--[[
  Le travail de fond (shared/team/fond.lua : miner à la main, fondre au QG) est l'« investissement par défaut » d'un PNJ sans
  tâche. Il n'a de sens que si la matière MANQUE à l'équipe. Elle ne manque pas (le fond s'en abstient) quand, sur la foi
  des mesures du cerveau :
    « sature »  son stock dépasse plusieurs fois le besoin prévu (shared/ai3/buts.lua, B.saturated) ;
    « module »  un module fini la livre (shared/ai3/cerveau.lua, covered) ET le débit mesuré couvre le besoin (comme « debit », sans
                la marge sur le minage à la main : un module à demi-régime ne couvre pas une équipe qui manque) ;
    « debit »   le débit AUTOMATIQUE mesuré couvre le besoin ET écrase le travail à la main : sur la fenêtre, (production des
                machines − ce que les PNJ ont miné à la main) × M.COVER_MIN minutes ≥ le besoin prévu (manque compris : le
                besoin du cerveau est « ce qu'il va consommer + ce qui manque »), et ce débit vaut au moins M.MARGINAL PNJ
                au minage à la main (un PNJ de plus ajouterait au plus 1/M.MARGINAL du débit des machines : sans cela, au
                début de partie, quand le premier avant-poste ne livre que 30 par minute, le minage à la main reste le
                moyen de démarrer). Le rendement d'un PNJ est MESURÉ (minage réussi : unités ÷ secondes), M.HAND_RATE sans
                mesure.
  Une matière SANS machine (débit nul ou mesure trop courte, M.MIN_SAMPLES minutes) n'est jamais couverte : le travail à la
  main en est la source. Les tâches d'URGENCE du cerveau (hors fond : planificateur, manque de plaques, matière sans avant-
  poste) ne passent pas par cette règle.

  Chaînes (M.chains, déduites des données de l'exécutant) : un avant-poste dont le produit se fond au QG à partir de sa
  ressource (plaque <- minerai) ; un produit brut sans fonte (produit = ressource). Une plaque couverte retire le minage
  de son minerai ET la fonte de fond de la plaque ; un produit brut couvert retire son minage. Les noms viennent des
  tables de l'exécutant, jamais d'ici.

  M.reason(item, c) -> "sature" | "module" | "debit" | nil
    c = { saturated = {[objet]=vrai}, modules = {[objet]=vrai}, need = {[objet]=n} (besoin prévu, manque et plancher
          compris), flow = {[objet] = {rate = débit automatique par minute, n = minutes mesurées}},
          hand = {[objet] = unités par minute d'UN PNJ au minage à la main (mesuré)},
          stock = {[objet] = stock de l'équipe} (facultatif ; « module » et « debit » exigent stock >= besoin quand il est donné) }
  M.skips(chains, c) -> mine_skip {[ressource]=raison}, smelt_skip {[plaque]=raison}
]]
M.COVER_MIN = 10    -- minutes : le débit automatique doit livrer le besoin prévu en une fenêtre (A.WINDOW de l'automatisation)
M.MIN_SAMPLES = 3   -- minutes de mesure au moins avant de déclarer « debit »
M.MARGINAL = 4      -- le débit automatique vaut au moins 4 PNJ au minage à la main (un de plus : au plus 25 % de gain)
M.HAND_RATE = 30    -- unités par minute d'un PNJ au minage à la main sans mesure (moteur réel, 28/10 : 0,5 par seconde, trajets compris)
M.HAND_MIN_SECS = 120 -- secondes de minage réussi avant de se fier à la mesure

--- Chaînes d'approvisionnement à la main, tirées des tables de l'exécutant (shared/team/config.lua passé en `T`).
function M.chains(T)
  local out = {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local spec = T.outposts[kind]
    local input = T.smelter_inputs and T.smelter_inputs[spec.product]
    out[#out + 1] = { kind = kind, product = spec.product, resource = spec.resource,
      smelted = input ~= nil and input[1] == spec.resource }
  end
  return out
end

--- Débit automatique moyen par minute sur les derniers échantillons { {total=, hand=}, ... } (le plus récent en dernier) :
--- production des machines moins minage à la main, jamais négatif. Rend le débit et le nombre de minutes retenues.
function M.auto_flow(samples)
  local n = #samples
  if n == 0 then return 0, 0 end
  local first = math.max(1, n - M.COVER_MIN + 1)
  local sum, k = 0, 0
  for i = first, n do
    local s = samples[i]
    sum = sum + math.max(0, (s.total or 0) - (s.hand or 0))
    k = k + 1
  end
  return sum / k, k
end

function M.reason(item, c)
  if c.saturated and c.saturated[item] then return "sature" end
  local fl = c.flow and c.flow[item]
  local hand = (c.hand and c.hand[item]) or M.HAND_RATE
  -- Le débit automatique mesuré livre le besoin prévu sur la fenêtre (mesure assez longue, débit non nul).
  -- ET le stock de l'équipe atteint déjà ce besoin (c.stock) : sinon la demande est bridée par la pénurie, le « besoin » prévu
  -- la sous-estime et des PNJ attendraient la matière les bras ballants (Azure, 20 à 25 min : fer à 0, 63 à 69 % d'inactifs).
  local need = (c.need and c.need[item]) or 0
  local delivers = fl and (fl.n or 0) >= M.MIN_SAMPLES and (fl.rate or 0) > 0
    and fl.rate * M.COVER_MIN >= need
    and (c.stock == nil or (c.stock[item] or 0) >= need)
  -- « module » : un module fini la livre ET son débit mesuré livre le besoin (un module qui tourne à moitié de sa cible ne
  -- couvre pas une équipe qui manque : mesuré au moteur réel, la faction Azure restait sans fer et ses PNJ sans travail).
  if c.modules and c.modules[item] and delivers then return "module" end
  if delivers and fl.rate >= M.MARGINAL * hand then return "debit" end
  return nil
end

--- Rendement mesuré d'un PNJ au minage à la main (unités par minute) : `units` ramassées en `secs` PNJ-secondes de minage
--- réussi ; nil tant que la mesure est trop courte.
function M.hand_rate(units, secs)
  if (secs or 0) < M.HAND_MIN_SECS then return nil end
  return 60 * (units or 0) / secs
end

function M.skips(chains, c)
  local mine, smelt = {}, {}
  for _, ch in ipairs(chains) do
    local why = M.reason(ch.product, c)
    if why then
      mine[ch.resource] = why
      if ch.smelted then smelt[ch.product] = why end
    end
  end
  return mine, smelt
end

return M
