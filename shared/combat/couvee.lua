--[[
  s43 MEGA-BOURDON (tranche 2, 14/11) : plafond de la cascade des couvées (Lua pur, testable hors jeu).
  Une unité « couvée » libère à sa mort E.families.brood.brood unités du palier inférieur, couvées elles aussi : sur 12 paliers, une
  couvée du dernier palier tuée génération après génération par une arme de zone (Méga-Bourdon, banc megabourdon-salve du 13/11)
  donnait 8 192 unités en vie puis 8 192 morts dans le même tick : 24 s de gel pour 30 ticks.
  Règle : les naissances passent par une FILE ; au plus BUDGET_TICK naissances par tick (toutes surfaces, dans l'ordre d'arrivée) ;
  la file garde au plus ATTENTE_MAX naissances : au-delà, la naissance est abandonnée (comptée). Hors de ces bornes (petits combats),
  rien ne change : 2 enfants par mort, au plus un tick de retard.
]]
local Cv = {}

Cv.BUDGET_TICK = 32    -- naissances par tick (2 enfants : 16 couvées tuées dans le même tick naissent sans attendre)
Cv.ATTENTE_MAX = 512   -- naissances en attente au plus (16 ticks de budget)

--- Nouvelle file vide.
function Cv.file() return { l = {}, tete = 1, abandons = 0 } end

--- Taille de la file (naissances en attente).
function Cv.taille(f) return #f.l - f.tete + 1 end

--- Ajoute une naissance n (table opaque) ; rend true si elle est gardée, false si elle est abandonnée (file pleine).
function Cv.ajouter(f, n, max)
  if Cv.taille(f) >= (max or Cv.ATTENTE_MAX) then
    f.abandons = f.abandons + 1
    return false
  end
  f.l[#f.l + 1] = n
  return true
end

--- Retire et rend, dans l'ordre d'arrivée, au plus `budget` naissances (liste). La file se compacte quand elle est vide.
function Cv.tranche(f, budget)
  local o = {}
  budget = budget or Cv.BUDGET_TICK
  while #o < budget and f.tete <= #f.l do
    o[#o + 1] = f.l[f.tete] -- pas de trou dans la liste (# reste défini) : elle se vide d'un coup quand la tête la dépasse
    f.tete = f.tete + 1
  end
  if f.tete > #f.l then
    f.l, f.tete = {}, 1
  elseif f.tete > Cv.ATTENTE_MAX then -- file jamais vide : on recopie le reste (la liste ne grandit pas sans fin)
    local r = {}
    for i = f.tete, #f.l do r[#r + 1] = f.l[i] end
    f.l, f.tete = r, 1
  end
  return o
end

return Cv
