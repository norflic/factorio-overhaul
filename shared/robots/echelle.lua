--[[
  Lot EXPERIMENTAUX-PUISSANCE (5/11) : règle d'échelle des unités expérimentales PAR ÂGE. Lua pur (testé par tests/echelle_test.lua).
  Décisions du DC (QCM-5/11-XP, 21 h 35, OBJECTIFS §4) : « mouche » à 4 âges de moins ; tenir 3 min sous 10 déchiqueteurs de SON âge ;
  5 salves pour tuer un déchiqueteur de son âge ; frapper tout ce qui est ennemi, jusqu'à la fin ; zone « +15 par âge » ; cratère et sol
  brûlé. Décision du lead : la même règle vaut pour le Bourdon et les géants de robotsjeu (l'attaque du Bourdon reste telle quelle).

  E1 résistance d'écart d'âge : sur tous les types de dégâts, part FIXE = le coup d'une mitrailleuse de l'âge A − ECART (le moteur ne
     connaît pas l'âge du tireur ; la force d'un coup croît de × 1,32 par âge, une part fixe filtre donc par âge), part en % = POURCENT.
  E2 PV : tenir SURVIE_S secondes sous MEUTE déchiqueteurs du palier de son âge, avec E1 (le soin des géants s'ajoute : marge).
  E3 salve : chaque cible de la zone prend un coup PLEIN qui, après la résistance du déchiqueteur du palier de son âge à ce type de dégâts,
     vaut PV / SALVES ; zone R(A) = PAS_ZONE × (A − AGE_ZONE0) pour A ≥ 10 (15 à l'âge 10, 90 à l'âge 15).
  E4 trace : cratère de rayon R(A) / 6 au point visé (2,5 à l'âge 10, 15 à l'âge 15).
  COÛT : une recherche d'entités par salve, cibles rangées par anneau de distance (ordre fixe), au plus PLAFOND par salve, dégâts par TRANCHES de
     TRANCHE entités par tick ; une salve de zone au plus toutes les CADENCE_ZONE ticks.

  SUPPOSÉ (à confirmer en jeu) : le palier des déchiqueteurs de l'âge A est A − DECALAGE_PALIER (âge 15 ↔ palier 12) ; la meilleure munition
  vanilla d'un âge est le chargeur perforant jusqu'à l'âge 8, l'uranium ensuite.
]]

local D = require("shared.tirs.degats")
local E = require("shared.content.enemies")

local Ech = {}

Ech.ECART = 4
Ech.POURCENT = 50
Ech.SURVIE_S = 180
Ech.MEUTE = 10
Ech.SALVES = 5
Ech.PAS_ZONE = 15
Ech.AGE_ZONE0 = 9
Ech.AGE_ZONE_MIN = 10
Ech.DECALAGE_PALIER = 3
Ech.CRATERE_PART = 6
Ech.TRANCHE = 120
Ech.ANNEAU = 3
Ech.PLAFOND = 4000
Ech.CADENCE_ZONE = 180

--- Types de dégâts couverts par la résistance d'écart d'âge (ordre fixe).
Ech.TYPES = { "physical", "impact", "explosion", "fire", "acid", "poison", "laser", "electric" }

--- Déchiqueteurs vanilla 1.1.91 (data/base/prototypes/entity/enemies.lua) : PV, morsure, cadence (ticks), résistances { fixe, % }.
Ech.VANILLA = {
  { pv = 15, morsure = 7, cadence = 35, res = {} },
  { pv = 75, morsure = 15, cadence = 35, res = { physical = { 4, 10 }, explosion = { 0, 10 } } },
  { pv = 375, morsure = 30, cadence = 35, res = { physical = { 8, 10 }, explosion = { 0, 10 } } },
  { pv = 3000, morsure = 90, cadence = 50, res = { physical = { 12, 10 }, explosion = { 12, 10 } } },
}

--- Formule de dégâts du moteur : d = coup − fixe ; si d < 1, d = 1 / (2 − d) ; puis × (1 − % / 100).
function Ech.apres(coup, fixe, pct)
  local d = coup - (fixe or 0)
  if d < 1 then d = 1 / (2 - d) end
  return d * (1 - (pct or 0) / 100)
end

--- Palier des déchiqueteurs de l'âge A (SUPPOSÉ).
function Ech.palier(age)
  return math.max(1, math.min(E.TIERS, age - Ech.DECALAGE_PALIER))
end

--- Déchiqueteur ordinaire (sans famille) d'un palier : { pv, morsure, cadence, res = { [type] = { fixe, % } } }, comme
--- prototypes/enemies.lua (paliers 5 et plus : le béhémoth × E.new_tiers, résistances + resist en fixe et en %, plafond 95 %,
--- physique, explosion et acide ajoutés).
function Ech.dechiqueteur(p)
  if p <= E.VANILLA_TIERS then return Ech.VANILLA[p] end
  local b, nt = Ech.VANILLA[E.VANILLA_TIERS], E.new_tiers[p]
  local res = {}
  for _, t in ipairs(Ech.TYPES) do
    local r = b.res[t]
    if r then
      res[t] = { r[1] + nt.resist, math.min(95, r[2] + nt.resist) }
    elseif t == "physical" or t == "explosion" or t == "acid" then
      res[t] = { nt.resist, math.min(95, nt.resist) }
    end
  end
  return { pv = b.pv * nt.hp, morsure = b.morsure * nt.damage, cadence = b.cadence, res = res }
end

--- Meilleure munition vanilla d'un âge (SUPPOSÉ) : dégâts d'une balle.
function Ech.munition(a)
  return a <= 8 and 8 or 24
end

--- Coup d'une mitrailleuse du mod à l'âge a (son plus haut niveau, 2 × a), meilleure munition : 0 avant l'âge 1.
function Ech.coup_tourelle(a)
  if a < 1 then return 0 end
  return Ech.munition(a) * D.par_niveau[math.min(30, 2 * a)]
end

--- E1 : part fixe de la résistance d'écart d'âge d'une unité d'âge A.
function Ech.fixe(age)
  return Ech.coup_tourelle(age - Ech.ECART)
end

--- E1 : résistances du prototype (liste, ordre de Ech.TYPES), fixe arrondi au dixième.
function Ech.resistances(age)
  local f = math.floor(Ech.fixe(age) * 10 + 0.5) / 10
  local out = {}
  for _, t in ipairs(Ech.TYPES) do out[#out + 1] = { type = t, decrease = f, percent = Ech.POURCENT } end
  return out
end

--- DPS reçu de MEUTE déchiqueteurs du palier de l'âge A, avec la résistance E1 (morsure physique).
function Ech.dps_meute(age)
  local b = Ech.dechiqueteur(Ech.palier(age))
  return Ech.MEUTE * (60 / b.cadence) * Ech.apres(b.morsure, Ech.fixe(age), Ech.POURCENT)
end

--- E2 : PV d'une unité d'âge A (arrondis à la centaine au-dessus).
function Ech.pv(age)
  return math.ceil(Ech.SURVIE_S * Ech.dps_meute(age) / 100) * 100
end

--- E3 : coup d'une salve sur une cible, AVANT résistance, pour un type de dégâts : après la résistance du déchiqueteur du palier de
--- l'âge A, il vaut PV / SALVES. nil si ce déchiqueteur est immunisé (100 %).
function Ech.salve(age, dtype)
  local b = Ech.dechiqueteur(Ech.palier(age))
  local r = b.res[dtype] or { 0, 0 }
  if r[2] >= 100 then return nil end
  local net = b.pv / Ech.SALVES
  return math.ceil(net / (1 - r[2] / 100) + r[1])
end

--- E3 : rayon de la zone d'une salve (nil avant l'âge 10 : les petits gardent leur forme).
function Ech.rayon(age)
  if age < Ech.AGE_ZONE_MIN then return nil end
  return Ech.PAS_ZONE * (age - Ech.AGE_ZONE0)
end

--- E4 : rayon du cratère au point visé (nil avant l'âge 10).
function Ech.cratere(age)
  local r = Ech.rayon(age)
  if not r then return nil end
  return r / Ech.CRATERE_PART
end

--- Coût : cibles d'une salve rangées par ANNEAU de distance (largeur Ech.ANNEAU tuiles, du centre vers le bord : l'onde se voit), dans un
--- anneau dans l'ordre d'entrée (celui de la recherche du moteur, le même sur toutes les machines) ; au plus PLAFOND. Rangement en temps
--- linéaire, sans tri par comparaison (moteur simulé : un tri complet de 7 000 cibles coûtait 17 ms en un tick, tests/echelle_cout.lua).
--- `cands` : { x, y, ... } ; rend une NOUVELLE liste (la table d'entrée n'est pas touchée).
function Ech.plan(cands, center)
  local rings, top = {}, 0
  for _, c in ipairs(cands) do
    local dx, dy = c.x - center.x, c.y - center.y
    local k = math.floor(math.sqrt(dx * dx + dy * dy) / Ech.ANNEAU) + 1 -- sqrt est exactement arrondie (IEEE 754) : même anneau partout
    local r = rings[k]
    if not r then r = {}; rings[k] = r end
    r[#r + 1] = c
    if k > top then top = k end
  end
  local out = {}
  for k = 1, top do
    local r = rings[k]
    if r then
      for _, c in ipairs(r) do
        if #out >= Ech.PLAFOND then return out end
        out[#out + 1] = c
      end
    end
  end
  return out
end

--- Coût : nombre de ticks pour traiter n cibles par tranches.
function Ech.ticks(n)
  return math.ceil(n / Ech.TRANCHE)
end

--- Tranche k (1, 2, …) d'une liste : indices de début et de fin (fin < début : rien).
function Ech.tranche(k, n)
  local a = (k - 1) * Ech.TRANCHE + 1
  return a, math.min(n, k * Ech.TRANCHE)
end

return Ech
