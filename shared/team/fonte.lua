--[[
  FONDERIES (retour du DC du 29/10, 1 h 30 de partie sur 0.6.13) : équilibre entre le débit d'entrée d'une fonderie et le
  nombre de ses fours. PUR : aucune API Factorio, aucun nom d'objet (les débits arrivent en DONNÉES : tests/iag_test.lua §8).

  Le DC : « les fours sont arrêtés parce que l'input est trop faible ou trop fort » ; « s'il y a trop d'input, on rajoute des
  fours ; s'il n'y en a pas assez, on en enlève quelques-uns ou on rajoute des foreuses ».

  Fonte.furnaces_wanted(input, capacity, max)  ->  nombre de fours qui absorbent `input` (objets/s), un four en traitant
                                                  `capacity` ; borné par `max` (emprise du gabarit).
  Fonte.balance(s)                             ->  décision { action, furnaces, drills, wanted, input, capacity } ; s :
      input         débit d'entrée réel (objets/s) : foreuses actives × débit d'une foreuse ;
      capacity      objets/s absorbés par UN four (vitesse ÷ temps de la recette) ;
      furnaces      fours en place ; max_furnaces : plafond de l'emprise du gabarit ;
      drills        foreuses actives ; drill_rate : objets/s d'une foreuse ; max_drills : plafond du gisement ou du lot.
  Actions : "equilibre", "ajouter_fours" (trop d'entrée, la place existe), "retirer_foreuses" (trop d'entrée, plus de place
  pour des fours : on réduit l'entrée au plafond de l'emprise), "ajouter_foreuses" (fours en trop, des foreuses sont
  possibles), "retirer_fours" (fours en trop, plus de foreuses possibles), "sans_entree", "invalide".
]]
local F = {}

local EPS = 1e-9

local function ceil_eps(x) return math.ceil(x - EPS) end

function F.furnaces_wanted(input, capacity, max)
  if type(input) ~= "number" or type(capacity) ~= "number" or input <= 0 or capacity <= 0 then return 0 end
  local n = ceil_eps(input / capacity)
  if type(max) == "number" and n > max then n = max end
  return math.max(0, n)
end

function F.balance(s)
  local cap, input = s.capacity or 0, s.input or 0
  local out = { action = "invalide", input = input, capacity = cap, furnaces = s.furnaces or 0, drills = s.drills or 0, wanted = 0 }
  if cap <= 0 or (s.max_furnaces or 0) <= 0 then return out end
  if input <= 0 then out.action = "sans_entree" return out end
  local max_f = s.max_furnaces
  local raw = ceil_eps(input / cap)
  local have = s.furnaces or 0
  out.wanted = math.min(raw, max_f)
  if raw > max_f then
    -- trop d'entrée pour l'emprise : les fours au plafond, l'entrée ramenée à ce qu'ils absorbent
    out.furnaces = max_f
    local dr = s.drill_rate or 0
    if dr > 0 then
      out.drills = math.max(0, math.min(s.drills or 0, math.floor(max_f * cap / dr + EPS)))
    end
    out.action = "retirer_foreuses"
    return out
  end
  if raw > have then out.action, out.furnaces = "ajouter_fours", raw return out end
  if raw == have then out.action = "equilibre" return out end
  -- fours en trop : des foreuses d'abord (on exploite le gisement), sinon on retire des fours
  local dr, md = s.drill_rate or 0, s.max_drills or 0
  if dr > 0 then
    local need = ceil_eps(have * cap / dr)
    if need <= md then out.action, out.drills = "ajouter_foreuses", math.max(need, s.drills or 0) return out end
  end
  out.action = "retirer_fours"
  out.furnaces = F.furnaces_wanted(math.max(input, md * dr), cap, max_f)
  return out
end

return F
