--[[
  Lot REINVESTIR-FER (9/11, feu vert de l'orchestrateur sur le diagnostic de la sonde de fer) : le ressort exponentiel du fer.
  Mesuré (sonde-fer 2baf7bf4, 3 graines, 3 équipes, avant 15 min) : les foreuses sur le fer sont toutes en marche, le minerai sorti égale les
  plaques fondues, le débit vaut exactement 15 minerais par minute par foreuse thermique ; le coffre est à 0 ; le premier maillon qui limite
  est le NOMBRE de foreuses : 8 puis 16 (un avant-poste = 8) jusqu'à 15 min, jamais un 3e avant-poste de fer. La cible de capacité passe à 2
  une fois le fer et le charbon à 75 %, puis ne monte que sur un manque durable (6 pensées, 100 objets ; shared/ai3/buts.lua, B.targets).
  Or une foreuse thermique (environ 9 plaques) se rembourse en 36 s : un avant-poste de 8 foreuses coûte moins d'une minute de sa propre sortie.

  Règle (Rv.decide, PURE : aucun nom d'objet, des nombres de l'appelant) : la cible de capacité du fer monte d'UN avant-poste, sans attendre
  6 pensées, quand
    1. le fer manque : stock de la plaque sous le plancher du besoin (a.have < a.floor) ;
    2. toute la capacité visée est posée et en marche : a.cap >= a.tg, rien en cours (a.pending = 0), et aucun avant-poste de ce type n'a un
       brûleur à sec, un réceptacle plein ou un manque de combustible (a.outs) ;
    3. le réinvestissement se paie au remboursement : coût d'un avant-poste ÷ son débit (a.drills x Rv.DRILL_PER_MIN par minute) <= Rv.HORIZON_MIN ;
    4. garde-fous : aucun avant-poste de ce type n'est tombé (a.cap >= la plus grande capacité vue, a.maxcap) ; aucun site sous menace (avant-poste
       dangereux, où un PNJ est mort, à protéger, sans ses tourelles, équipe menacée) ; borne Rv.MAX avant-postes ; au plus une hausse toutes les
       Rv.EVERY ticks (a.last).
  Déterminisme : nombres, aucune horloge (le tick vient de l'appelant), aucun `pairs`.
]]

local Rv = {}

Rv.DRILL_PER_MIN = 15  -- plaques (minerai) par minute par foreuse thermique : MESURÉ par la sonde (8 foreuses = 120/min, 16 = 240/min)
Rv.HORIZON_MIN = 5     -- remboursement accepté (minutes) : un avant-poste de fer se rembourse en moins d'une minute
Rv.MAX = 4             -- avant-postes visés au plus par cette règle (les autres règles de B.targets montent au-delà, jusqu'à B.GROW_MAX)
Rv.EVERY = 3600        -- ticks entre deux hausses (le temps de bâtir : la cible suivante attend la capacité posée de toute façon)

--- a = { have, floor, tg, cap, pending, max (borne de l'appelant), outs = { { drills, dry, stuck, fuel_low, unsafe, lethal, protect, turrets_lacking } },
---   maxcap (plus grande capacité vue), cost (plaques d'un avant-poste), drills (foreuses d'un avant-poste), threatened, undefended (n), tick, last }.
--- Rend (monter, raison).
function Rv.decide(a)
  a = a or {}
  local tg, cap = a.tg or 0, a.cap or 0
  local limit = math.min(a.max or Rv.MAX, Rv.MAX)
  if tg >= limit then return false, "borne" end
  if (a.have or 0) >= (a.floor or 0) then return false, "le fer ne manque pas" end
  if (a.pending or 0) > 0 then return false, "avant-poste en cours" end
  if cap + 1e-9 < tg then return false, "capacite visee pas posee" end
  if cap + 1e-9 < (a.maxcap or 0) then return false, "avant-poste tombe" end
  if a.threatened or (a.undefended or 0) > 0 then return false, "menace" end
  if #(a.outs or {}) == 0 then return false, "aucun avant-poste" end
  for _, o in ipairs(a.outs) do
    if (o.dry or 0) > 0 or (o.stuck or 0) > 0 or o.fuel_low then return false, "foreuse pas en marche" end
    if o.unsafe or o.lethal or o.protect then return false, "site sous menace" end
  end
  local rate = (a.drills or 0) * Rv.DRILL_PER_MIN
  if rate <= 0 or (a.cost or math.huge) / rate > Rv.HORIZON_MIN then return false, "remboursement trop long" end
  if a.last ~= nil and (a.tick or 0) - a.last < Rv.EVERY then return false, "trop tot" end
  return true, "remboursement " .. string.format("%.1f", (a.cost or 0) / rate) .. " min"
end

return Rv
