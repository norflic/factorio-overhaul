--[[
  CHARGE D'UN FOUR par un PNJ (lot FOURS, 29/10) : PUR (aucune API Factorio, aucun nom d'objet ; tailles de pile et quantités
  d'entrée arrivent en DONNÉES). Remarque 12 du DC (D-26) : « quand un agent refill un four, en charbon ou en ressource à
  fondre, en mettre un max pour éviter de passer toutes les 2 minutes ». Avant : 10 fabrications au plus, et seulement dans un
  four VIDE (10 minerais = 32 s de fonte : un passage toutes les 2 minutes ou moins pour un seul four).

  Règle : la case d'entrée du four se remplit jusqu'à SA PILE (le plafond est la pile, 50 minerais dans un four de pierre), un
  four est complété dès qu'il est tombé au tiers de sa pile (K.needs_load), et le porteur prend au coffre de quoi remplir tous
  les fours à charger dans la limite d'une part du stock (K.carry) : jamais la moitié du coffre en plaques pour de l'acier.
    K.slot_cap(stack, ratio)        capacité de la case : la pile, au multiple de `ratio` (entrée d'une fabrication) inférieur
    K.needs_load(present, cap)      vrai si le four est au tiers de sa capacité ou moins
    K.room(present, stack, ratio)   place à remplir (0 si le four n'est pas à charger)
    K.carry(a)                      quantité à prendre au coffre
    K.split(avail, rooms, ratio)    répartition à égalité entre les fours (liste de quantités, multiples de `ratio`)
  Déterminisme : aucune table parcourue par pairs.
]]

local K = {}

K.RELOAD_NUM, K.RELOAD_DEN = 1, 3 -- un four est complété quand il est tombé au tiers de sa capacité
K.FLOOR_CRAFTS = 10               -- fabrications par four à charger toujours permises (le plancher de la recharge de main)
K.SHARE_NUM, K.SHARE_DEN = 1, 2   -- part du stock libre qu'une tournée peut emporter au-delà du plancher

local function floor(x) return x - x % 1 end

local function norm_ratio(ratio)
  if ratio and ratio >= 1 then return floor(ratio) end
  return 1
end

function K.slot_cap(stack, ratio)
  ratio = norm_ratio(ratio)
  stack = floor(stack or 0)
  local cap = stack - stack % ratio
  if cap < ratio then cap = ratio end
  return cap
end

function K.needs_load(present, cap)
  return (present or 0) * K.RELOAD_DEN <= cap * K.RELOAD_NUM
end

function K.room(present, stack, ratio)
  local cap = K.slot_cap(stack, ratio)
  present = present or 0
  if not K.needs_load(present, cap) then return 0 end
  local r = cap - present
  return r > 0 and r or 0
end

--- a = { room = place totale des fours à charger, stock = stock libre de l'objet, ratio, loads = nombre de fours à charger,
---       demand_crafts = fabrications demandées (nil : pas de borne par la demande) }.
--- Rend la quantité à prendre au coffre : multiple de `ratio`, au plus la place, au plus le stock, au plus le plancher ou la
--- part du stock (le plus grand des deux), au plus la demande quand elle borne.
function K.carry(a)
  local ratio = norm_ratio(a.ratio)
  local room, stock = a.room or 0, a.stock or 0
  if room <= 0 or stock <= 0 then return 0 end
  local share = floor(stock * K.SHARE_NUM / K.SHARE_DEN)
  local floor_items = K.FLOOR_CRAFTS * ratio * (a.loads or 1)
  local n = room
  if stock < n then n = stock end
  local cap = floor_items > share and floor_items or share
  if cap < n then n = cap end
  if a.demand_crafts then
    local d = floor(a.demand_crafts) * ratio
    if d < n then n = d end
  end
  n = n - n % ratio
  return n > 0 and n or 0
end

--- Répartition de `avail` objets entre des fours dont la place est `rooms` (liste, dans l'ordre) : chacun reçoit sa part
--- égale du reste, au multiple de `ratio` inférieur, au plus sa place ; quand il y a moins d'une fabrication par four restant,
--- les premiers fours reçoivent une fabrication chacun. Rend une liste de quantités de même longueur que `rooms`.
function K.split(avail, rooms, ratio)
  ratio = norm_ratio(ratio)
  local out = {}
  local left = avail - avail % ratio
  local count = #rooms
  for i = 1, count do
    local remaining = count - i + 1
    local share = floor(left / remaining)
    share = share - share % ratio
    if share < ratio then share = ratio end
    local n = rooms[i]
    if share < n then n = share end
    if left < n then n = left end
    n = n - n % ratio
    if n < 0 then n = 0 end
    out[i] = n
    left = left - n
  end
  return out
end

return K
