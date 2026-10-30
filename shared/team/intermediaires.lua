--[[
  Lot MAIN-ET-INTERMEDIAIRES (demandes D09 et D10 du DC, 28/10 vers 14 h 45, en jouant la 0.6.5) : REGLE PURE (aucune API
  Factorio, aucun nom d'objet du jeu : les objets sont des clés opaques passées par l'appelant, script/team/intermediaires.lua).

  D09 « les compagnons ont miné des ressources de fer par terre » alors que le fer sort : un PNJ ne mine pas À LA MAIN une
       ressource dont la production des MACHINES de l'équipe (fours de la fonderie, foreuses de la ligne) est déjà « en
       quantité », sauf en mode survie (shared/team/survie.lua : pénurie durable ET équipe paralysée).
       « En quantité » (I.hand_useless) : le débit des machines, part de la main retirée, vaut au moins I.MARGINAL PNJ au
       minage à la main (I.HAND_RATE unités par minute chacun) : un PNJ de plus ajouterait au plus 1 / I.MARGINAL du débit.
       HYSTÉRÉSIS : coupé à I.MARGINAL × I.HAND_RATE, repris sous I.OFF fois ce seuil (pas de clignotement d'une minute à
       l'autre).
  D10 « il faut pas tomber dans l'ultra maximisation (engrenages qui prennent tout le fer) » : un objet FABRIQUÉ D'AVANCE par
       un module de l'équipe nourri depuis le coffre (quai d'entrée rempli de plaques par les PNJ) a un PLAFOND de stock
       proportionnel au besoin réel (I.cap) ; au-delà, le module n'est plus nourri (ses quais d'entrée ne sont plus remplis,
       ses matières ne sont plus fabriquées pour lui) jusqu'à ce que le stock retombe sous I.RESUME fois le plafond.
       Plafond = max(I.MIN_STOCK, consommation mesurée par minute × I.HORIZON) + demande des tâches ouvertes + quais d'entrée
       des modules qui le consomment (I.FEED chacun) + réserve de fond voulue pour cet objet.

  Déterminisme : aucune table parcourue par `pairs` dans une décision, aucun hasard, aucun temps mesuré (débits par minute
  de jeu). Les seuils sont des CHOIX, non mesurés en partie (RAPPORT du lot).
]]

local I = {}

-- D09
I.HAND_RATE = 30   -- unités par minute d'un PNJ au minage à la main, trajets compris (lot MAINS, moteur réel 28/10 : 0,5 par seconde)
I.MARGINAL = 4     -- le débit des machines vaut au moins 4 PNJ : coupé à 120 par minute
I.OFF = 0.5        -- repris sous la moitié du seuil (60 par minute)

-- D10
I.HORIZON = 10     -- minutes de consommation mesurée gardées d'avance (fenêtre de l'automatisation, A.WINDOW)
I.MIN_STOCK = 100  -- plancher du plafond (un objet que rien ne consomme encore aux statistiques)
I.FEED = 200       -- par module qui consomme l'objet (= Auto.FEED_STOCK de script/ai3/automatisation.lua : stock voulu au coffre pour ses quais)
I.RESUME = 0.5     -- module de nouveau nourri quand le stock retombe sous la moitié du plafond

local function num(x)
  if type(x) ~= "number" or x ~= x then return 0 end
  return x
end

---------------------------------------------------------------------------------------------------
-- D09
---------------------------------------------------------------------------------------------------
--- Débit des MACHINES d'un produit, en produits par minute, part de la main retirée. a = { stat = RESSOURCE extraite par minute
--- aux statistiques de la force (foreuses ; nil : non lisible ou force partagée avec le joueur humain), modules = produits par
--- minute mesurés aux modules finis de l'équipe, hand_miners = PNJ qui minent cette ressource à la main en ce moment, per_ore =
--- produits par unité de ressource (1 sans fonte) }.
--- La RESSOURCE est lue, pas la plaque : les fours du QG fondent aussi le minerai miné à la main (sinon la coupure
--- s'entretiendrait elle-même) ; et si le moteur compte le minage à la main d'un PNJ (non établi), cette part
--- (hand_miners × I.HAND_RATE) est retirée.
function I.machine_flow(a)
  local per = a.per_ore ~= nil and num(a.per_ore) or 1
  local stat = a.stat ~= nil and math.max(0, num(a.stat) - num(a.hand_miners) * I.HAND_RATE) * per or 0
  return math.max(stat, math.max(0, num(a.modules)))
end

--- Le minage à la main de cette ressource est-il inutile ? prev = décision précédente (hystérésis), a = { flow = débit des
--- machines (I.machine_flow), survie = mode survie de l'équipe }.
function I.hand_useless(prev, a)
  if a.survie then return false end
  local th = I.MARGINAL * I.HAND_RATE
  if prev then th = th * I.OFF end
  return num(a.flow) >= th
end

--- Une tâche de minage à la main est-elle exemptée (survie, crise injectée par un banc) ? Lue sur sa clé.
function I.exempt_key(key)
  if type(key) ~= "string" then return false end
  return key:sub(1, 7) == "survie:" or key:sub(1, 6) == "crise:"
end

---------------------------------------------------------------------------------------------------
-- D10
---------------------------------------------------------------------------------------------------
--- Plafond de stock d'un objet fabriqué d'avance. a = { cons = consommation mesurée par minute, demand = objets réservés par
--- les tâches ouvertes, feeders = modules finis qui le prennent à leurs quais d'entrée, reserve = réserve de fond voulue }.
function I.cap(a)
  local base = math.max(I.MIN_STOCK, math.ceil(math.max(0, num(a.cons)) * I.HORIZON))
  return base + math.max(0, math.floor(num(a.demand))) + math.max(0, math.floor(num(a.feeders))) * I.FEED
    + math.max(0, math.floor(num(a.reserve)))
end

--- Le module de cet objet est-il au-dessus de son plafond (ne plus le nourrir) ? prev = décision précédente (hystérésis).
function I.over(prev, have, cap)
  have, cap = num(have), num(cap)
  if prev then return have > math.floor(cap * I.RESUME) end
  return have >= cap
end

return I
