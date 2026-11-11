--[[
  Lot MAIN-INVENTAIRE (retour du DC du 31/10, points 4 et 5) : règles PURES du minage à la main.
    0. La pioche existe-t-elle encore ? (Mi.gone) : plus après l'ère électrique de l'équipe (lot PURGE-MINE).
    1. Mine-t-on à la main ? (Mi.hand_verdict) : jamais quand le stock (coffre du QG + annexes) couvre déjà la tâche ;
       jamais de combustible à la main quand un coffre en a (constat : 3e à 7e heure, minage de charbon seul, coffres garnis).
       Le mode survie reste exempté (il minait déjà faute de tout), comme les crises injectées par les bancs. Une tâche qui porte
       un VRAI manque (a.short : le demandeur l'a mesuré contre le stock libre) passe aussi : count n'est qu'une fournée, un projet
       de 500 pierres ne doit pas rester bloqué à 100 en coffre.
    2. Inventaire plein (Mi.inventory_action) : on dépose l'utile au coffre puis on revient finir, au lieu de laisser le
       moteur lâcher le minerai au sol ; au plus Mi.TRIPS_MAX voyages par tâche.
    3. Service des fours au QG (Mi.keep_working) : après une perte ou une fuite, le rappel des PNJ ne retire pas ceux qui
       servent les fours du QG (charbon, sortie, relance), à moins de Mi.SERVICE_R tuiles du coffre.
    4. Minerai au sol (Mi.pick_plan) : quelles piles ramasser autour du mineur, les plus proches d'abord, jamais plus que
       la place restante ni Mi.PICK_MAX.
  Lua pur, aucun nom d'objet du jeu : l'appelant dit si la ressource est le combustible.
]]

local Mi = {}

Mi.STOCK_MIN = 50    -- stock d'une ressource qui suffit à une tâche de minage, au plus bas
Mi.COVER = 2         -- la tâche est couverte quand le stock vaut COVER fois son nombre d'objets (hors combustible)
Mi.FUEL_MIN = 100    -- combustible : plus de minage à la main dès que les coffres en ont autant
Mi.ROOM_MIN = 20     -- place libre en dessous de laquelle on va déposer avant de miner plus
Mi.TRIPS_MAX = 3     -- voyages de dépôt au plus par tâche de minage
Mi.PICK_RADIUS = 12  -- rayon de ramassage autour du mineur, en tuiles
Mi.PICK_MAX = 400    -- minerai ramassé au plus par fin de minage
Mi.PICK_LIMIT = 256  -- piles au sol examinées au plus
Mi.SERVICE_R = 30    -- tuiles du QG : le service des fours y reste prioritaire après une attaque
Mi.SERVICE_KINDS = { smelt = true, smelters = true } -- tâches de fonte au QG (types de tâche, pas des objets)

local function num(v) return type(v) == "number" and v or 0 end

--- a = { stock = objets en coffre, count = fournée de la tâche, fuel = bool, survie = bool, crisis = bool, short = manque mesuré par le demandeur }.
--- Rend ok (miner à la main), raison ("survie" | "crise" | "manque" | "stock"). Ne juge que le démarrage : après l'ère électrique, la tâche
--- n'arrive plus jusqu'ici (Mi.gone).
function Mi.hand_verdict(a)
  if a.crisis then return true, "crise" end
  if a.survie then return true, "survie" end
  if num(a.short) > 0 then return true, "manque" end
  local need
  if a.fuel then
    need = Mi.FUEL_MIN
  else
    need = math.max(Mi.STOCK_MIN, Mi.COVER * num(a.count))
  end
  if num(a.stock) >= need then return false, "stock" end
  return true, "manque"
end

--- Lot PURGE-MINE (DC, 11/11 13 h 55 : « supprime la tâche kind == "mine" de la file de sélection dès que la technologie des foreuses
--- électriques est débloquée ou craftable ») : la tâche `t` sort-elle de la file de sélection ? Oui pour un minage LIBRE (pas encore pris)
--- d'un objet que la foreuse électrique extrait (`drillable(objet)`, lu aux prototypes par l'appelant), dès que l'ère électrique de l'équipe
--- est datée (`era`, tick ; nil avant). Seul cas gardé : le démarrage, où la pioche est le seul moyen d'extraire. Le bois des arbres n'est
--- pas extractible par la foreuse : il reste.
function Mi.gone(t, era, drillable)
  return era ~= nil and t.kind == "mine" and t.worker == nil and drillable(t.resource) == true
end

--- a = { room = place pour l'objet, got = déjà miné dans cette étape, count = demandé, trips = voyages faits }.
--- Rend "finish" | "continue" | "deposit".
function Mi.inventory_action(a)
  local remaining = num(a.count) - num(a.got)
  if remaining <= 0 then return "finish" end
  if num(a.room) >= math.min(Mi.ROOM_MIN, remaining) then return "continue" end
  if num(a.trips) >= Mi.TRIPS_MAX then return "finish" end
  return "deposit"
end

--- stacks = { { i = indice de l'appelant, n = taille de la pile, d2 = distance au carré, x =, y = } }, room = place libre.
--- Rend la liste des indices à ramasser, dans l'ordre : piles entières, les plus proches d'abord (égalité : x, y, i),
--- tant que la place et Mi.PICK_MAX le permettent. Ne modifie pas `stacks`.
function Mi.pick_plan(stacks, room)
  local list = {}
  for k, s in ipairs(stacks or {}) do
    if num(s.n) > 0 then list[#list + 1] = s end
    if k >= Mi.PICK_LIMIT then break end
  end
  table.sort(list, function(a, b)
    if a.d2 ~= b.d2 then return a.d2 < b.d2 end
    if a.x ~= b.x then return a.x < b.x end
    if a.y ~= b.y then return a.y < b.y end
    return a.i < b.i
  end)
  local left, total, out = num(room), 0, {}
  for _, s in ipairs(list) do
    if s.n <= left and total + s.n <= Mi.PICK_MAX then
      out[#out + 1] = s.i
      left = left - s.n
      total = total + s.n
    end
  end
  return out, total
end

--- Le rappel (perte d'un PNJ, fuite d'un autre) laisse-t-il ce PNJ à sa tâche ? kind = type de la tâche, d2_hq = distance
--- au carré entre le PNJ et le coffre du QG.
function Mi.keep_working(kind, d2_hq)
  return Mi.SERVICE_KINDS[kind] == true and num(d2_hq) <= Mi.SERVICE_R * Mi.SERVICE_R
end

return Mi
