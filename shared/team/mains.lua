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

return M
