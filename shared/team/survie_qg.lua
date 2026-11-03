--[[
  Lot S1 SURVIE (retour du DC du 31/10 : sur trois factions, « deux détruites à 1 h 30 » ; il veut des bases qui se développent à l'infini,
  et une base morte ne grandit plus ; principe du DC : « réparer + protéger puis améliorer »). PUR (aucune API Factorio, aucun nom
  d'objet : l'appelant, script/team/survie_qg.lua, passe des nombres). Testé hors jeu : tests/s1_survie_test.lua (avec mutants).

  Mesures (fo-logs/2026-11-01_INTEG-0632/partie, 0.6.32, Écarlate, QG détruit à 79,9 min par de petits cracheurs) :
    * fer au coffre 0 à 31 de 15 min à la mort, mode survie-pénurie (« production d'abord ») du 42,3 min à la mort : le plancher de fer
      de la défense (T.defend_iron_floor = 150) n'était jamais atteint, aucun chargeur ne se fabriquait ;
    * la défense prévue comptait TOUTE tourelle du rayon (7 tourelles, 4 018 PV) sans lire leurs munitions : elles sont tombées
      devant des vagues de 1 506 à 2 055 PV ; la prévision ne voyait aucune vague (45 « RATÉ », pollution reçue 0/min, aucun nid
      rattaché) et n'ouvrait « préparer » qu'à 1 min du contact ;
    * le QG d'une faction ne voulait que 0 ou 2 tourelles (shared/team/front.lua, F.hq_post) : jamais plus à mesure que les vagues
      grossissaient.

  Règle (Sq.peril), évaluée à chaque pensée de l'équipe :
    MENACE   la plus grosse vague REÇUE dans les Sq.WINDOW derniers ticks (au QG ; ailleurs, pour Sq.ELSEWHERE_PCT %), faits relevés par
             la calibration de la prévision (Pv.threat_waves) : une mémoire, pas une prévision.
    DÉFENSE  la valeur des tourelles du QG ARMÉES (chargées au moins au seuil bas), une tourelle vide valant 0.
    PÉRIL    la menace d'au moins Sq.MIN_THREAT PV dépasse la défense armée / Sq.COVER_PCT % ; sortie quand la défense armée atteint
             la menace × Sq.COVER_PCT × Sq.EXIT_PCT % (hystérésis : pas de clignotement).
  Ce que le péril change (chaque effet a son lecteur nommé dans RAPPORT.md) :
    1. la PRIORITÉ : la défense du QG passe avant la production, même en mode survie-pénurie (shared/team/priorite.lua, `peril`) ;
    2. les PLANCHERS de fer et de cuivre de la défense du QG tombent à Sq.FLOOR_* (le plancher ordinaire n'était jamais atteint) ;
    3. le QG VEUT les tourelles qui couvrent la menace (Sq.peril().want, au plus `cap`) et les tourelles du QG vides sont remplies
       avec le stock de chargeurs même incomplet (planificateur, groupe « hq »).
  BORNÉ : le péril cesse dès que la défense armée couvre la menace mémorisée ; la menace elle-même s'éteint après Sq.WINDOW ticks sans
  vague reçue. Le coût maximal est celui de `cap` tourelles armées : pas un trou sans fond, la croissance reprend ensuite.

  Perte du coffre de votre équipe (Sq.chest_fate) : détruit par l'ennemi, il est reposé si l'équipe a encore des PNJ ; sinon (ou après
  Sq.CHEST_MAX reposes en Sq.CHEST_WINDOW), l'équipe prend fin comme avant. Retiré par le joueur (mine, script) : fin, comme avant.

  Déterminisme : entiers, aucune horloge mesurée, aucun hasard, aucun `pairs` décisionnel.
]]

local Sq = {}

Sq.WINDOW = 30 * 3600       -- mémoire de la menace : 30 min (comme F.HQ_MEMORY, shared/team/front.lua)
Sq.MIN_THREAT = 300         -- PV : une vague plus petite que cela n'ouvre pas le péril (une quinzaine d'unités moyennes). SUPPOSÉ
Sq.COVER_PCT = 125          -- % : la défense armée visée vaut 1,25 × la menace mémorisée. SUPPOSÉ (marge de la prévision : Pc.MARGE 110 %)
Sq.EXIT_PCT = 110           -- % de la cible : sortie du péril (hystérésis)
Sq.ELSEWHERE_PCT = 50       -- % : une vague reçue ailleurs qu'au QG compte à moitié pour le QG (le QG est le siège). SUPPOSÉ
Sq.FLOOR_IRON = 60          -- plaques de fer gardées pour les recrues en péril (T.defend_iron_floor = 150 sinon ; comme F.FLOOR_IRON)
Sq.FLOOR_COPPER = 10        -- plaques de cuivre gardées en péril (T.defend_copper_floor = 30 sinon ; comme F.FLOOR_COPPER)
Sq.REFILL_MIN = 5           -- chargeurs par tourelle vide en dessous desquels un remplissage partiel ne part pas
Sq.SITE_HIT = 150           -- PV reçus en 30 min à un avant-poste à partir desquels on le protège avant de l'agrandir ou de le refaire. SUPPOSÉ (une dizaine d'unités)
Sq.PV_PER_MAG = 40          -- PV d'unités tuées par un chargeur de base (10 balles de 5 : 50 de dégâts, moins le surplus). SUPPOSÉ
Sq.CHEST_MAX = 3            -- reposes du coffre en Sq.CHEST_WINDOW au plus
Sq.CHEST_WINDOW = 30 * 3600

local function num(x)
  if type(x) ~= "number" or x ~= x or x < 0 then return 0 end
  return x
end

local function ceil(x) return math.ceil(x - 1e-9) end

--- Poids d'une tourelle en ‰ selon ses munitions : 0 si vide, 1000 au seuil bas ou au-dessus, proportionnel entre les deux.
--- `ammo` : chargeurs dans la tourelle ; `low` : seuil bas (T.turret_ammo_low).
function Sq.armed_share(ammo, low)
  ammo, low = num(ammo), num(low)
  if ammo <= 0 then return 0 end
  if low <= 0 or ammo >= low then return 1000 end
  return math.floor(1000 * ammo / low)
end

--- La menace mémorisée du QG. waves = { { t = tick, pv = PV reçus, hq = vrai si reçus au QG } } (la mémoire de la calibration, ordre
--- d'arrivée). Rend les PV : max(vague au QG, Sq.ELSEWHERE_PCT % de la plus grosse ailleurs) dans la fenêtre.
function Sq.threat(waves, tick)
  local at_hq, elsewhere = 0, 0
  for _, w in ipairs(waves or {}) do
    if w.t and tick >= w.t and tick - w.t <= Sq.WINDOW then
      local pv = num(w.pv)
      if w.hq then
        if pv > at_hq then at_hq = pv end
      elseif pv > elsewhere then
        elsewhere = pv
      end
    end
  end
  local other = math.floor(elsewhere * Sq.ELSEWHERE_PCT / 100)
  return at_hq > other and at_hq or other
end

--- La plus grosse vague reçue n'importe où dans la fenêtre (même format que Sq.threat).
function Sq.threat_any(waves, tick)
  local best = 0
  for _, w in ipairs(waves or {}) do
    if w.t and tick >= w.t and tick - w.t <= Sq.WINDOW and num(w.pv) > best then best = num(w.pv) end
  end
  return best
end

--- Un avant-poste de ressource doit-il être PROTÉGÉ avant d'être agrandi ou refait ? a = { hit (PV reçus à ce site dans la fenêtre),
--- turrets (tourelles du site), wanted (tourelles voulues) }. Vrai tant que des vagues le touchent et qu'il lui manque des tourelles.
function Sq.protect_first(a)
  a = a or {}
  return num(a.hit) >= Sq.SITE_HIT and num(a.turrets) < num(a.wanted)
end

--- Réserve de chargeurs au coffre calculée sur la menace (dès les premières vagues) : ceil(menace / Sq.PV_PER_MAG), au plus `per_turret`
--- chargeurs par tourelle de l'équipe. 0 sous Sq.SITE_HIT ou sans tourelle. a = { threat, turrets, per_turret }.
function Sq.ammo_reserve(a)
  a = a or {}
  local threat, turrets, per = num(a.threat), num(a.turrets), num(a.per_turret)
  if threat < Sq.SITE_HIT or turrets <= 0 or per <= 0 then return 0 end
  local n = ceil(threat / Sq.PV_PER_MAG)
  local cap = turrets * per
  return n < cap and n or cap
end

--- Le péril. a = { threat (PV), armed_value (PV des tourelles armées du QG), turret_value (PV d'une tourelle de plus, armée),
--- turrets (tourelles du QG), armed (dont armées), cap (tourelles au plus au QG), was (péril retenu à la pensée d'avant) }.
--- Rend { peril, cause = "menace" | "munitions" | nil, need (PV visés), gap (PV qui manquent), want (tourelles voulues au QG),
--- fresh (tourelles de plus à poser), refill (tourelles à remplir), full (la cible dépasse ce que `cap` tourelles couvrent) }.
function Sq.peril(a)
  a = a or {}
  local threat, value, armed_value = num(a.threat), num(a.turret_value), num(a.armed_value)
  local turrets, armed = num(a.turrets), num(a.armed)
  if armed > turrets then armed = turrets end
  local cap = num(a.cap)
  local out = { peril = false, need = 0, gap = 0, want = turrets, fresh = 0, refill = 0, full = false }
  if threat < Sq.MIN_THREAT or value <= 0 then return out end
  local need = math.floor(threat * Sq.COVER_PCT / 100)
  out.need = need
  local limit = a.was and math.floor(need * Sq.EXIT_PCT / 100) or need
  if armed_value >= limit then return out end
  out.peril = true
  out.gap = need - armed_value
  -- Des tourelles sont là et leur nombre couvrirait la menace si elles étaient chargées : la cause est le chargeur, pas la tourelle.
  out.cause = (turrets > armed and turrets * value >= need) and "munitions" or "menace"
  local want = ceil(need / value)
  if cap > 0 and want > cap then
    want = cap
    out.full = true
  end
  if want < turrets then want = turrets end
  out.want = want
  out.fresh = want - turrets
  out.refill = turrets - armed
  return out
end

--- Plancher de fer et de cuivre de la défense du QG : réduit en péril. Rend fer, cuivre, réduit.
function Sq.floors(peril, base_iron, base_copper)
  if peril then
    return math.min(num(base_iron), Sq.FLOOR_IRON), math.min(num(base_copper), Sq.FLOOR_COPPER), true
  end
  return num(base_iron), num(base_copper), false
end

--- Remplissage des tourelles du QG avec le stock de chargeurs. low = tourelles sous le seuil bas, target = chargeurs voulus par tourelle,
--- stock = chargeurs au coffre, peril = vrai en péril. Rend le nombre de chargeurs à prendre (0 : rien). Hors péril, la règle d'avant :
--- tout ou rien (le stock couvre low × target). En péril, un stock d'au moins low × Sq.REFILL_MIN part tel quel.
function Sq.refill_take(low, target, stock, peril)
  low, target, stock = num(low), num(target), num(stock)
  local full = low * target
  if low <= 0 then return 0 end
  if stock >= full then return full end
  if peril and stock >= low * Sq.REFILL_MIN then return stock end
  return 0
end

--- Que devient l'équipe du joueur quand son coffre disparaît ? a = { killed (vrai : détruit par l'ennemi), workers, soldiers,
--- recent = nombre de reposes dans Sq.CHEST_WINDOW }. Rend "poser" (un coffre neuf à la même place) ou "fin" avec la cause.
function Sq.chest_fate(a)
  a = a or {}
  if not a.killed then return "fin", "retire par le joueur ou par script" end
  if num(a.workers) + num(a.soldiers) <= 0 then return "fin", "aucun PNJ vivant" end
  if num(a.recent) >= Sq.CHEST_MAX then return "fin", "trop de coffres perdus en peu de temps" end
  return "poser", "des PNJ vivants"
end

--[[
  Lot QGSURVIE (3/11) : l'INTERBLOCAGE du fer de votre équipe (verif-guide 1618033988, 0.6.42 à 0.6.45 ; fo-logs/2026-11-03_QGSURVIE/RAPPORT.md).
  Mesuré (0.6.45, INTEG-0645 et INTEG-0645F) : la bande -48 du champ de fer (colonne à tapis, 584 entités, 442 tapis, 27 foreuses électriques
  manquants à 15 min) réserve et fait fabriquer ses pièces de 14 à 35 min, fer au coffre entre 3 et 264 ; bâtie, elle ne rend rien (foreuses
  figées ou sans courant, fours sans entrée, de 40 à 60 min). La pile ne la retient pas : elle produit du fer, matière qui manque
  (PileRt.porte). Quand une vague emporte les tourelles du QG (INTEG-0645 : 47,7 min, 5 tourelles armées tombées), le coffre est à 0 :
  ni tourelle, ni pompe, ni recrue ne se refont, et l'équipe finit à 1 PNJ (0.6.41, fonderie à coffres de 253 entités : 5 136 plaques à 43 min).

  Règle 1 (Sq.qg_reserve, Sq.module_held) : un module NEUF de production (bande, ligne : jamais une reconstruction) ne prend rien au coffre
  et ne fait rien fabriquer tant que le fer au coffre est sous la RÉSERVE DU QG : le plancher de la défense (gardé aux recrues) plus le
  fer de Sq.RESERVE_TURRETS tourelles armées de Sq.RESERVE_MAGS chargeurs (« réparer + protéger puis améliorer », principe du DC). Ce
  n'est pas la réserve de recrues supprimée le 29/10 (FE.reserve) : rien n'est retenu aux recrues ni à la défense, seulement aux modules neufs.
  Règle 2 (Sq.recruit_hold) : votre équipe ne recrute pas pendant que le QG n'a AUCUNE tourelle armée ET que des unités ennemies sont à
  portée du coffre (la recrue naît au coffre et y meurt : CHARBON3, sans-main 1618033988, 112 PNJ perdus, environ 10 par minute), sauf
  s'il ne reste aucun PNJ (sans lui, personne ne repose les tourelles).
]]
Sq.RESERVE_TURRETS = 2      -- tourelles du QG que la réserve doit pouvoir refaire et armer (le QG en péril en voulait 2 après sa chute, 47,7 min). SUPPOSÉ
Sq.RESERVE_MAGS = 10        -- chargeurs par tourelle de la réserve (au-dessus du seuil bas T.turret_ammo_low = 8). SUPPOSÉ
Sq.HOLD_MIN_WORKERS = 1     -- sous cet effectif, la recrue part quand même (il faut quelqu'un pour reposer les tourelles)

--- Réserve de fer du QG. a = { floor (plancher de fer de la défense), turret_iron (fer d'une tourelle), mag_iron (fer d'un chargeur) }.
function Sq.qg_reserve(a)
  a = a or {}
  return ceil(num(a.floor) + Sq.RESERVE_TURRETS * (num(a.turret_iron) + Sq.RESERVE_MAGS * num(a.mag_iron)))
end

--- Un module neuf de production est-il retenu ? a = { iron (fer au coffre), reserve (Sq.qg_reserve), rebuild (reconstruction) }.
function Sq.module_held(a)
  a = a or {}
  if a.rebuild then return false end
  return num(a.iron) < num(a.reserve)
end

--- La recrue de votre équipe est-elle retenue ? a = { armed (tourelles armées du QG), threat (unités ennemies à portée du coffre), workers }.
function Sq.recruit_hold(a)
  a = a or {}
  if num(a.armed) > 0 or not a.threat then return false end
  return num(a.workers) >= Sq.HOLD_MIN_WORKERS
end

return Sq
