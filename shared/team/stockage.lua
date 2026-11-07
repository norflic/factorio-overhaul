--[[
  Lot STOCKAGE, essai 2 (remarque du DC du 5/11, essai 0.6.53 à 177 min : « les coffres restent des coffres en fer et pas en acier [...] il y a
  visiblement une limite en fait de coffres posés de stockage [...] les ressources se posent par terre [...] Il n'y a pas d'utilisation logique
  infinie de coffres »). PUR : aucune API Factorio, aucun nom d'objet (les coffres sont des RANGS d'une échelle donnée par l'appelant). Testé hors
  jeu : tests/stockage_test.lua.

  Mesuré dans la partie du DC (fo-logs/2026-11-05_PARTIE-DC-ESSAI/factorio-current-2032.log) : 45 annexes à 129,5 min (1 053 / 1 504 cases),
  puis AUCUNE pose pendant 42 min alors que 194 à 234 coffres en fer étaient en main (journal [FO-IA3E], champ « main ») ; à 172 min, 43 annexes
  et 1 472 / 1 472 cases (100 %). La règle d'avant borne les annexes à UN bloc de 48 places (T.annex.max, A.capacity) et ne pose que des coffres en
  fer ou en bois (T.annex.kinds) ; une place occupée par un autre bâtiment est sautée, le stock reste bloqué.

  Règle (Sg.decide), quand il faut de la place (même déclencheur qu'avant : A.need_chest sans le plafond, ou dépôt refusé) :
    1. une place libre et un coffre en main : POSER le plus grand coffre en main ;
    2. plus de place libre, un coffre en main plus grand que le plus petit coffre posé : AMÉLIORER ce coffre (fer -> acier, bois -> fer) ;
    3. plus de place libre, rien à améliorer : ouvrir un ANNEAU de plus (Sg.ring_slots : le même bloc, plus loin du QG), jusqu'à Sg.MAX_RINGS ;
    4. aucun coffre en main : FABRIQUER le plus grand coffre fabricable.
  Le stock n'a plus de plafond fixe : Sg.MAX_RINGS anneaux de A.capacity places chacun (5 anneaux = 240 coffres, 11 520 cases en acier).
  Déterminisme : entiers, aucun hasard, aucune horloge, aucun `pairs`.
]]

local T = require("shared.team.config")
local A = require("shared.team.annexe")

local Sg = {}

Sg.MAX_RINGS = 5     -- anneaux au plus (sécurité : 5 x 48 places). SUPPOSÉ ; le DC veut un stock sans limite logique
Sg.RING_STEP = 8     -- tuiles entre deux anneaux (le bloc d'avant va de 5 à 11 tuiles : 7 de profondeur + 1 d'allée)

local function num(x)
  if type(x) ~= "number" or x ~= x or x < 0 then return 0 end
  return x
end

--- Places de l'anneau `ring` (1 = le bloc d'avant, A.slots) pour un coffre de w × h tuiles, face sy : le même bloc décalé de
--- (ring - 1) x Sg.RING_STEP tuiles vers l'extérieur. { { dx, dy } }, de la plus proche à la plus lointaine.
function Sg.ring_slots(sy, w, h, ring)
  ring = math.max(1, math.floor(num(ring)))
  local base = A.slots(sy, w, h)
  if ring == 1 then return base end
  sy = (sy or 1) < 0 and -1 or 1
  local shift = (ring - 1) * Sg.RING_STEP
  local out = {}
  for i, p in ipairs(base) do out[i] = { p[1], p[2] + sy * shift } end
  return out
end

--- Places de tous les anneaux ouverts (1..rings).
function Sg.capacity(sy, w, h, rings)
  local n = 0
  for r = 1, math.max(1, math.floor(num(rings))) do n = n + #Sg.ring_slots(sy, w, h, r) end
  return n
end

--- Le plus grand coffre (rang le plus petit de l'échelle) dont la liste `ok` dit vrai (ok[k] nombre > 0 ou booléen vrai) ; nil sinon.
local function best(ladder, ok)
  for k = 1, #ladder do
    local v = ok and ok[k]
    if v == true or (type(v) == "number" and v > 0) then return k end
  end
  return nil
end

--- Le plus PETIT coffre posé (rang le plus grand de l'échelle) : annexes = { [rang] = nombre posé }.
local function smallest(ladder, annexes)
  for k = #ladder, 1, -1 do
    if num(annexes and annexes[k]) > 0 then return k end
  end
  return nil
end

--- Que faire maintenant ? c = { used, size (cases), n (annexes), free_places (places libres des anneaux ouverts), early (dépôt refusé ou stock
--- à T.annex.early_at depuis 5 min), hand = { [rang] = coffres en main }, annexes = { [rang] = posés }, rings (anneaux ouverts, 1 par
--- défaut), makeable = { [rang] = vrai si fabricable } } ; ladder = { { slots }, ... } du plus grand au plus petit. Rend l'action IMMÉDIATE et le
--- rang : "poser", k | "ameliorer", k (vers le rang k) | "anneau" | "fabriquer", k | "rien". De la place TOUT DE SUITE avec ce qui est en main ;
--- le meilleur coffre se fabrique en parallèle (Sg.craft).
function Sg.decide(c, ladder)
  c = c or {}
  ladder = ladder or {}
  if not (c.early == true or A.fill(c.used, c.size) >= T.annex.grow_at) then return "rien" end
  local k_hand = best(ladder, c.hand)
  if not k_hand then
    local k_make = best(ladder, c.makeable)
    if k_make then return "fabriquer", k_make end
    return "rien"
  end
  if num(c.free_places) > 0 then return "poser", k_hand end
  local s = smallest(ladder, c.annexes)
  if s and k_hand < s then return "ameliorer", k_hand end
  if math.max(1, math.floor(num(c.rings))) < Sg.MAX_RINGS then return "anneau" end
  return "rien"
end

--- Coffre à FABRIQUER en parallèle (rang), ou nil : le plus grand fabricable s'il est plus grand que le meilleur en main (ou si rien en main) et
--- plus grand que le plus petit posé (sinon il n'apporterait rien) ; seulement quand il faut de la place (même déclencheur que Sg.decide).
function Sg.craft(c, ladder)
  c = c or {}
  ladder = ladder or {}
  if not (c.early == true or A.fill(c.used, c.size) >= T.annex.grow_at) then return nil end
  local k_make = best(ladder, c.makeable)
  if not k_make then return nil end
  local k_hand = best(ladder, c.hand)
  if k_hand and k_hand <= k_make then return nil end
  local s = smallest(ladder, c.annexes)
  if s and k_make >= s and num(c.free_places) <= 0 then return nil end
  return k_make
end

return Sg
