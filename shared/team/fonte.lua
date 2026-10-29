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

--[[
  LIGNE DYNAMIQUE (lot FONDERIE-DYNAMIQUE, arbitrage du DC du 29/10 au soir) : « la fonderie grandit en fonction du nombre de
  foreuses qu'elle a en input, donc dynamiquement, ni 2, ni 4, ni 8, mais dynamique ».

  Le plan réserve la place de la ligne entière (rangées de fours et paires de foreuses que le gisement porte, Ligne.rows_wanted
  sans budget) ; seules les pièces voulues MAINTENANT sont posées. Une rangée = 2 fours (un de chaque côté du tapis) et leurs bras ;
  une paire = 2 foreuses. Une UNITÉ de budget = une rangée avec sa paire de foreuses (T.ligne.row_cost plaques).

  Fonte.initial(s) -> rows, pairs, why     taille de départ (au plan) ; s : rows_max (rangées réservées), pairs_max (paires
                                           planifiées), drill_rate, cap (objets/s d'UN four), budget (unités payables, nil : sans borne).
  Fonte.step(s)    -> { action, rows, pairs, furnaces, want, why }
                                           pas de croissance d'une ligne bâtie (lu au moteur) ; s : input (objets/s des foreuses qui
                                           PRODUISENT), cap, rows (rangées posées), rows_max, drills (foreuses qui produisent),
                                           drill_rate, pairs (paires posées), pairs_max, budget (unités, nil : sans borne),
                                           step_rows, step_pairs (rangées / paires au plus par pas).
  Actions de Fonte.step : "ajouter_fours" (rows > 0 : l'entrée dépasse les fours), "ajouter_foreuses" (pairs > 0 : des fours
  attendent du minerai, ou la ligne est juste et des paires réservées restent : la ligne va vers sa taille prévue), "budget"
  (croissance voulue, stock insuffisant ; want = pièces voulues), "plein" (toutes les rangées réservées sont posées), "sans_minerai"
  (fours en trop et plus aucune foreuse à poser : jamais de nouveaux fours), "equilibre" (ligne entière, à l'équilibre), "invalide".
  JAMAIS de retrait : une ligne ne rétrécit pas (les fours en trop attendent le minerai).
]]
local function clamp_int(x, lo, hi)
  x = math.floor((x or lo) + EPS)
  if x < lo then return lo end
  if hi and x > hi then return hi end
  return x
end

function F.initial(s)
  local rmax = clamp_int(s.rows_max or 1, 1)
  local pmax = clamp_int(s.pairs_max or 0, 0)
  local units = s.budget and clamp_int(s.budget, 1) or math.huge -- au moins une unité : une ligne sans rangée n'existe pas
  local pairs = math.min(pmax, units)
  local fed = math.ceil(F.furnaces_wanted(2 * pairs * (s.drill_rate or 0), s.cap or 0, 2 * rmax) / 2 - EPS)
  local rows = math.max(1, math.min(fed, rmax))
  local why = "foreuses"
  if rows > units then rows, why = math.max(1, units), "budget" end
  if pairs < pmax then why = "budget" end
  return rows, pairs, why
end

function F.step(s)
  local out = { action = "invalide", rows = 0, pairs = 0, furnaces = 0, want = 0 }
  local rows, rmax = clamp_int(s.rows or 0, 0), clamp_int(s.rows_max or 0, 0)
  local pairs, pmax = clamp_int(s.pairs or 0, 0), clamp_int(s.pairs_max or 0, 0)
  local cap, dr = s.cap or 0, s.drill_rate or 0
  if cap <= 0 or rmax <= 0 or rows < 1 then return out end
  if rows > rmax then rows = rmax end
  if pairs > pmax then pmax = pairs end
  local left = pmax - pairs
  local budget = s.budget and clamp_int(s.budget, 0) or math.huge
  local step_r, step_p = clamp_int(s.step_rows or 1, 1), clamp_int(s.step_pairs or 1, 1)
  local drills = math.max(0, s.drills or 0)
  local dec = F.balance({ input = s.input or 0, capacity = cap, furnaces = 2 * rows, max_furnaces = 2 * rmax, drills = drills,
    drill_rate = dr, max_drills = drills + 2 * left })
  out.furnaces = dec.wanted
  if dec.action == "invalide" then return out end
  if dec.action == "ajouter_fours" or dec.action == "retirer_foreuses" then
    -- l'entrée dépasse les fours posés : des rangées au bout de la ligne (place réservée), jamais au-delà
    local add = math.min(rmax, math.ceil(dec.wanted / 2 - EPS)) - rows
    if add <= 0 then out.action = "plein" return out end
    add = math.min(add, step_r)
    out.want = add
    if budget < 1 then out.action = "budget" return out end
    out.action, out.rows = "ajouter_fours", math.min(add, budget)
    return out
  end
  -- fours en trop, ligne juste ou aucune entrée : des foreuses réservées s'il en reste, sinon RIEN (pas de nouveaux fours)
  if left <= 0 then
    out.action = (dec.action == "equilibre") and "equilibre" or "sans_minerai"
    return out
  end
  -- croissance d'une ligne juste : seulement si la ligne RÉSERVÉE entière a encore de la capacité libre (sinon la paire de plus
  -- n'aurait aucun four où aller : elle attendrait sur le tapis)
  if dec.action == "equilibre" and drills * dr >= 2 * rmax * cap - EPS then out.action = "equilibre" return out end
  local add = 1 -- croissance : la ligne va vers sa taille prévue, une paire à la fois au moins
  if dec.action == "ajouter_foreuses" and dr > 0 then add = math.max(1, math.ceil(((dec.drills or 0) - drills) / 2 - EPS)) end
  if dec.action == "retirer_fours" or dec.action == "sans_entree" then
    add = math.max(1, math.ceil((2 * rows * cap / math.max(dr, EPS) - drills) / 2 - EPS))
  end
  add = math.min(add, left, step_p)
  out.want = add
  if budget < 1 then out.action = "budget" return out end
  out.action, out.pairs = "ajouter_foreuses", math.min(add, budget)
  return out
end

return F
