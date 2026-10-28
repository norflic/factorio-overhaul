--[[
  Étalement des créneaux d'une voie de l'ordonnanceur (lot OUTILLAGE, 28/10). Lua PUR (aucun moteur).

  Problème (mesuré dans fo-logs\2026-10-28_ETAPE1, tools/autotest/gels.py) : l'ordonnanceur donne aux ids d'une voie des
  créneaux CONSÉCUTIFS (1, 2, 3...). Les pensées des factions (période 300) tombent donc aux ticks 0, 1, 2, 3 de chaque
  période, avec celle de votre équipe : une rafale de 4 pensées de 9 à 22 ms, puis 296 ticks creux. À x10 c'est le jeu qui
  « ralentit puis réaccélère » toutes les 0,5 s. Et tout ce qui est périodique DANS une pensée (une fois par minute, par
  10 minutes) s'empile sur les mêmes ticks (168 à 314 ms aux multiples de 36 000 ticks).

  Règle : l'id de rang r (0, 1, 2...) prend le créneau de la suite de van der Corput en base 2 (miroir binaire du rang) :
  0, 1/2, 1/4, 3/4, 1/8, 5/8... de la période. Pour n ids, les écarts entre créneaux voisins ne prennent que DEUX valeurs,
  P / 2^k et P / 2^(k+1) (k = partie entière de log2 n) : jamais plus du double de l'écart idéal P / n, et exactement
  l'idéal quand n est une puissance de 2. Sans état (le rang suffit) : mêmes créneaux chez tous les clients.

  Une voie à nombreux ids (compagnons, lots, modules : des centaines) garde le tourniquet d'origine, parfaitement équilibré :
  l'étalement est choisi voie par voie (Scheduler.define_lane, option spread).
]]

local Etalement = {}

local BITS = 16
local TOUR = 2 ^ BITS -- 65536

--- Miroir binaire du rang sur 16 bits, en entier (0 .. 65535) ; arithmétique entière, pas d'opérateur de bits (Lua 5.2).
function Etalement.miroir(rang)
  local r = math.floor(rang) % TOUR
  local m = 0
  for _ = 1, BITS do
    m = m * 2 + r % 2
    r = (r - r % 2) / 2
  end
  return m
end

--- Décalage (0 .. periode - 1) du rang r dans une période de `periode` ticks : plancher de miroir / 65536 x période.
function Etalement.decalage(rang, periode)
  return math.floor(Etalement.miroir(rang) * periode / TOUR)
end

--- Créneau (1 .. periode) de l'id de rang r ; `phase` (défaut 0) tourne toute la voie.
function Etalement.creneau(rang, periode, phase)
  return (Etalement.decalage(rang, periode) + (phase or 0)) % periode + 1
end

return Etalement
