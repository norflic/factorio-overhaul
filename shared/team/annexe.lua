--[[
  ANNEXES DU QG (lot COFFRE) : règles PURES (aucune API Factorio) ; l'exécution est script/team/stock.lua.

  Le coffre du QG d'une équipe a un nombre de cases fini. Plein, aucun ouvrier ne peut plus y déposer. Des coffres
  supplémentaires (annexes) se posent donc autour du QG dès que les cases se remplissent (T.annex, shared/team/config.lua),
  et l'excédent du coffre du QG y est rangé, par piles entières, avant qu'il soit plein.

    A.fill(used, size)                     remplissage 0..1 ;
    A.wanted(used, size, n_annex, have)    coffres à FABRIQUER ou à avoir en main : 0 tant que le total QG + annexes est sous
                                           T.annex.grow_at (ou que le maximum d'annexes est atteint), sinon T.annex.want moins
                                           ceux déjà en main ;
    A.need_chest(used, size, n_annex)      vrai quand il faut POSER un coffre maintenant ;
    A.park_plan(contents, stack_of, size, used, room)
                                           ce qu'on range : liste { { objet, nombre } } de piles ENTIÈRES, les objets qui
                                           prennent le plus de cases d'abord, une pile au moins laissée au QG
                                           (T.annex.keep), jusqu'à revenir à T.annex.park_to, dans la limite de `room`
                                           cases libres aux annexes ; vide sous T.annex.park_at.

  Déterminisme : objets triés par cases prises puis par nom (aucune décision selon l'ordre de pairs).
]]

local T = require("shared.team.config")

local A = {}

function A.fill(used, size)
  if not size or size <= 0 then return 1 end
  return (used or 0) / size
end

function A.need_chest(used, size, n_annex)
  if (n_annex or 0) >= T.annex.max then return false end
  return A.fill(used, size) >= T.annex.grow_at
end

function A.wanted(used, size, n_annex, have)
  if not A.need_chest(used, size, n_annex) then return 0 end
  return math.max(0, T.annex.want - (have or 0))
end

function A.park_plan(contents, stack_of, size, used, room)
  local out = {}
  if (used or 0) < T.annex.park_at * size or (room or 0) <= 0 then return out end
  local rows = {}
  for name, n in pairs(contents or {}) do
    local stack = math.max(1, stack_of[name] or 1)
    local whole = math.floor((n - T.annex.keep * stack) / stack)
    if whole > 0 then rows[#rows + 1] = { name = name, stack = stack, whole = whole, slots = math.ceil(n / stack) } end
  end
  table.sort(rows, function(a, b)
    if a.slots ~= b.slots then return a.slots > b.slots end
    return a.name < b.name
  end)
  local to_free = used - math.floor(T.annex.park_to * size)
  for _, r in ipairs(rows) do
    if to_free <= 0 or room <= 0 then break end
    local k = math.min(r.whole, to_free, room)
    out[#out + 1] = { r.name, k * r.stack }
    to_free, room = to_free - k, room - k
  end
  return out
end

return A
