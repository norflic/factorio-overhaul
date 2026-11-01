--[[
  Lot C3 EXTENSION, point 4 (ÎLOTS ; PLAN INDUSTRIE §3 « Espace » et D4 : « le treillis grandit au-delà du mur, en îlots »).
  Règle PURE (aucune API du jeu, aucun nom d'objet ; tests/ilots_croissance_test.lua) lue par script/team/build.lua (Build.space_step).

  Constat (AUDIT_PLAFONDS n°11 et 12) : une fois l'enceinte demandée, Build.grow plafonnait le rayon à celui de l'enceinte (b.enc.r) et
  Build.can_grow rendait faux : « rayon 4 fige », 18 lots écartés, emprise 177 x 229 puis 177 x 241 de 60 à 105 min (Emerald), 87 x 177
  de 75 à 119 min (Azure, rayon 5 atteint). Les lots restés dehors du contour serré étaient marqués `out` pour toujours.

  Règle (le mur ne bouge pas : les bornes serrées sont figées, shared/team/enceinte.lua) :
    - OUVERTURE : l'enceinte principale est COMPLÈTE (Ic.open) ; les lots entièrement dehors du contour (I.outside) cessent d'être `out` et
      peuvent recevoir un module : ce sont des ÎLOTS (shared/team/ilots.lua : mur et tourelles, script/team/ilots.lua) ;
    - PORTE (Ic.gate) : on n'ouvre pas de nouvel îlot tant que les îlots déjà retenus ne sont pas DÉFENDUS (mur complet, tourelles voulues
      posées), qu'un chantier de l'enceinte est en cours ou que l'équipe est menacée ; porte fermée, les lots libres dehors redeviennent
      `out` (réversible : un lot déjà pris n'est jamais touché) ;
    - CROISSANCE (Ic.grow_due) : porte ouverte, moins de Ic.GROW_FREE_MIN lots libres, peu de chantiers, rayon maximal non atteint : le
      treillis grandit d'un anneau (Build.grow, au-delà de b.enc.r) ;
    - NOMBRE (Ic.max_islands) : I.MAX îlots à 8 PNJ, un de plus par Ic.WORKERS_PER_ISLAND PNJ, Ic.ISLANDS_MAX au plus ; le plafond de
      tourelles des îlots suit (Ic.team_turrets).

  Déterminisme : listes triées par l'appelant, entiers, aucun `pairs`.
]]

local I = require("shared.team.ilots")

local Ic = {}

Ic.GROW_FREE_MIN = 3          -- lots libres (hors `out`) sous lesquels le treillis grandit (shared/team/enceinte.lua, E.GROW_FREE_MIN)
Ic.BUSY_MAX = 2               -- chantiers en cours au plus pour grandir (E.BUSY_MAX)
Ic.UNWALLED_MAX = 0           -- îlots sans mur complet tolérés avant d'en ouvrir un autre
Ic.UNGUARDED_MAX = 0          -- îlots sous leur cible de tourelles tolérés avant d'en ouvrir un autre
Ic.OUTSIDE_BUSY_MAX = 1       -- chantiers (projets non finis) sur des lots dehors du mur tolérés : un îlot à la fois, pas dix modules épars
Ic.WORKERS_PER_ISLAND = 10    -- un îlot de plus par 10 PNJ au-delà de 0 (4 + 30 / 10 = 7 à 30 PNJ)
Ic.ISLANDS_MAX = 10
Ic.TURRETS_PER_ISLAND = 2     -- plafond d'équipe des tourelles des îlots : au moins I.TEAM_MAX, 2 par îlot sinon

--- L'enceinte principale permet-elle des îlots ? enc = { bounds (contour serré figé), complete }.
function Ic.open(enc)
  return enc ~= nil and enc.bounds ~= nil and enc.complete == true
end

--- Îlots retenus au plus : I.MAX (4), un de plus par Ic.WORKERS_PER_ISLAND PNJ, Ic.ISLANDS_MAX au plus.
function Ic.max_islands(workers)
  local n = I.MAX + math.floor(math.max(0, workers or 0) / Ic.WORKERS_PER_ISLAND)
  if n > Ic.ISLANDS_MAX then n = Ic.ISLANDS_MAX end
  return n
end

--- Plafond d'équipe des tourelles des îlots (I.plan_turrets, paramètre `cap`).
function Ic.team_turrets(n_islands)
  local c = Ic.TURRETS_PER_ISLAND * math.max(0, n_islands or 0)
  return c > I.TEAM_MAX and c or I.TEAM_MAX
end

--- La porte des îlots : peut-on en ouvrir un nouveau ? info = { islands, max, unwalled, unguarded, threatened, main_busy, outside_busy }.
--- Rend (vrai) ou (faux, raison). `unwalled` : îlots retenus dont le mur n'est pas complet ; `unguarded` : îlots sous leur cible de
--- tourelles ; `main_busy` : un segment de l'enceinte principale est en cours ; `outside_busy` : projets non finis sur des lots dehors du mur.
function Ic.gate(info)
  if info.threatened then return false, "menace" end
  if info.main_busy then return false, "enceinte en cours" end
  if (info.outside_busy or 0) > Ic.OUTSIDE_BUSY_MAX then return false, "chantier hors du mur" end
  if (info.unwalled or 0) > Ic.UNWALLED_MAX then return false, "ilot sans mur" end
  if (info.unguarded or 0) > Ic.UNGUARDED_MAX then return false, "ilot sans tourelles" end
  if (info.islands or 0) >= (info.max or Ic.max_islands(0)) then return false, "plafond d'ilots" end
  return true
end

--- Le treillis doit-il grandir d'un anneau au-delà du mur ? info = { radius, rmax, pending (évaluations en file), free (lots libres
--- utilisables, hors `out`), busy, done } + les champs de Ic.gate. Rend (vrai) ou (faux, raison).
function Ic.grow_due(info)
  local ok, why = Ic.gate(info)
  if not ok then return false, why end
  if info.radius >= info.rmax then return false, "rayon maximal" end
  if (info.pending or 0) > 0 then return false, "evaluation en cours" end
  if (info.free or 0) >= Ic.GROW_FREE_MIN then return false, "place libre" end
  if (info.busy or 0) > Ic.BUSY_MAX then return false, "chantiers en cours" end
  if (info.done or 0) < 1 then return false, "rien de fini" end
  return true
end

--- Chantiers (lots pris par un projet non fini, hors mur de l'enceinte : `busy`) entièrement dehors du contour : la porte les compte.
function Ic.count_busy(lots, bounds)
  local n = 0
  if not bounds then return n end
  for _, l in ipairs(lots or {}) do
    if l.busy and I.outside(bounds, { x0 = l.x0, y0 = l.y0, x1 = l.x1, y1 = l.y1 }) then n = n + 1 end
  end
  return n
end

--- Lots à rendre ou à retirer au drapeau `out`, selon la porte. lots = { { k, out (vrai/faux), used (pris par un projet), free (libre
--- ou à défricher), x0, y0, x1, y1 } … } dans l'ordre des clés ; bounds = contour serré { x0, y0, x1, y1 } des tuiles du mur (incluses).
--- Porte ouverte : tout lot `out` entièrement dehors (I.outside) est rendu. Porte fermée : tout lot libre, entièrement dehors, non pris
--- et non `out` est écarté de nouveau. Rend (rendus, écartés) : listes de clés.
function Ic.release(lots, bounds, gate_ok)
  local freed, parked = {}, {}
  if not bounds then return freed, parked end
  for _, l in ipairs(lots or {}) do
    if I.outside(bounds, { x0 = l.x0, y0 = l.y0, x1 = l.x1, y1 = l.y1 }) then
      if gate_ok then
        if l.out then freed[#freed + 1] = l.k end
      elseif not l.out and l.free and not l.used then
        parked[#parked + 1] = l.k
      end
    end
  end
  return freed, parked
end

return Ic
