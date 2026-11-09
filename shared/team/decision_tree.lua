--[[
  ARBRE DE DÉCISION ÉCHELONNÉ (directive du DC du 9/11) : « arbre de décision échelonné Early / Mid / Late sous forme de TABLES DE RÈGLES
  concises [...] chaque nœud a une branche else de repli (zéro blocage) ; EXCLUSION MUTUELLE et meilleur choix disponible : interdit de
  poser un choix obsolète si une alternative moderne DORT AU COFFRE [...] ; FALLBACK pragmatique : si la machine optimale manque, poser
  la basique tout de suite et marquer le composant pour un rétrofit ultérieur. »
  PUR : aucune API Factorio, aucun nom d'objet ni de technologie (les options sont des étiquettes opaques ; stocks, seuils et signaux
  arrivent en DONNÉES de l'appelant). Testé hors jeu par tests/decision_tree_test.lua (mutants compris).

  Trois tables de règles, chacune avec son else :
    (a) Dt.phase(s)            : "early" | "mid" | "late". Late si les trois stocks du mall atteignent Dt.CFG ; mid si la centrale est
                                 finie et saine ET la foreuse électrique obtenable ; sinon early. Toujours une valeur.
    (b) Dt.best(options, stock): meilleure option DISPONIBLE d'une liste ordonnée (la plus efficiente d'abord) : la première au stock,
                                 sinon la première fabricable, sinon la dernière (repli, jamais nil sur une liste non vide) ; `retrofit`
                                 vrai quand une option plus efficiente existe et n'a pas été retenue (à remplacer plus tard).
    (c) Dt.thermal_allowed(i)  : une paire thermique est-elle encore permise ? Non dès que la phase n'est plus early ET que des foreuses
                                 électriques dorment au coffre ; sinon oui (la règle d'avant, E.thermal de shared/team/electrique.lua,
                                 tranche sur res_live, poteaux, centrale...).
  Déterminisme : listes parcourues par ipairs, aucun `pairs`, aucun temps mesuré, aucune fonction dans `global`.
]]

local Dt = {}

--- Seuils du mall qui font la phase LATE (nombres du DC, 9/11 : « 30 machines, 200 tapis, 100 bras ») : compteurs GÉNÉRIQUES fournis par
--- l'appelant (objets du stock dont l'entité posée est une machine de fabrication, un tapis, un bras : lus aux prototypes, jamais par nom).
Dt.CFG = { machines = 30, belts = 200, inserters = 100 }

local function num(x)
  if type(x) ~= "number" or x ~= x or x == math.huge or x == -math.huge then return nil end
  return x
end

--- (a) s = { plant_ok (centrale finie ET saine), elec_drill (foreuse électrique au stock ou fabricable), stock = { machines, belts,
--- inserters } (compteurs du mall), seuils (table aux mêmes clés que Dt.CFG ; absente : Dt.CFG) }. Rend (phase, cause).
--- Late ne regarde que le mall : trois stocks pleins prouvent une base qui tourne (la centrale et l'électrique sont derrière).
--- Mid exige LES DEUX signaux (une centrale sans foreuse électrique, ou l'inverse, reste early : rien d'électrique ne peut se poser).
function Dt.phase(s, cfg)
  s = s or {}
  local th = s.seuils or cfg or Dt.CFG
  local st = s.stock or {}
  local machines, belts, inserters = num(st.machines) or 0, num(st.belts) or 0, num(st.inserters) or 0
  if machines >= (num(th.machines) or Dt.CFG.machines) and belts >= (num(th.belts) or Dt.CFG.belts)
    and inserters >= (num(th.inserters) or Dt.CFG.inserters) then
    return "late", string.format("mall plein (%d machines, %d tapis, %d bras)", machines, belts, inserters)
  end
  if s.plant_ok == true and s.elec_drill == true then
    return "mid", "centrale finie et saine, foreuse electrique obtenable"
  end
  return "early", (s.plant_ok == true) and "foreuse electrique pas obtenable" or "aucune centrale finie et saine"
end

--- Une option est-elle au stock ? `in_stock` de l'option d'abord, sinon `stock[name]` (table facultative { [name] = n }).
local function held(o, stock)
  local k = num(o.in_stock)
  if k == nil and type(stock) == "table" and o.name ~= nil then k = num(stock[o.name]) end
  return (k or 0) > 0
end

--- (b) options = liste ORDONNÉE du plus efficient au moins efficient : { { name, in_stock = n, craftable = bool } } ; stock facultatif
--- (voir `held`). Rend (option retenue, retrofit, cause) :
---   1. la PREMIÈRE option au stock gagne (filtre anti-aberration : jamais une option moins efficiente qu'une option qui dort au coffre) ;
---   2. sinon la première fabricable maintenant ;
---   3. sinon la DERNIÈRE (repli pragmatique : la basique se pose tout de suite, jamais nil sur une liste non vide).
--- `retrofit` : vrai dès que l'option retenue n'est pas la première de la liste (une plus efficiente existe, ni au stock ni retenue :
--- le composant est à marquer pour un remplacement ultérieur). Liste vide : nil, false (l'appelant n'avait rien à poser).
function Dt.best(options, stock)
  options = options or {}
  local n = #options
  if n == 0 then return nil, false, "aucune option" end
  local pick, why = nil, nil
  for i = 1, n do
    if held(options[i], stock) then pick, why = i, "au stock" break end
  end
  if not pick then
    for i = 1, n do
      if options[i].craftable == true then pick, why = i, "fabricable maintenant" break end
    end
  end
  if not pick then pick, why = n, "repli : derniere option, posee tout de suite" end
  return options[pick], pick > 1, why
end

--- (c) i = { phase (Dt.phase ; absente : "early", la règle d'avant seule), elec_drill_stock (foreuses électriques AU COFFRE), res_live
--- (électriques qui tournent sur la ressource ; informatif, E.thermal tranche dessus), famine (plaque clé en famine, F434 ; informatif) }.
--- Rend (permise, cause). FAUX dès que phase ~= "early" ET elec_drill_stock > 0 : des électriques dorment, la thermique est interdite
--- quelle que soit la ressource (exclusion mutuelle du DC). Sinon VRAI : la règle d'avant décide.
--- CHOIX DOCUMENTÉ : la famine de la plaque clé (F434) ne rouvre PAS la thermique quand des électriques dorment : la bande électrique
--- payée par le stock dormant (F435) prend le relais, et poser une thermique à côté d'une électrique qui dort serait l'aberration visée.
--- Pour la même raison, l'effondrement d'extraction (DEFENSE-AP, E.collapsed) ne la rouvre pas non plus tant que le coffre en tient.
function Dt.thermal_allowed(i)
  i = i or {}
  local phase = i.phase or "early"
  local sleeping = num(i.elec_drill_stock) or 0
  if phase ~= "early" and sleeping > 0 then
    return false, string.format("%d foreuse(s) electrique(s) dorment au coffre : thermique interdite (arbre de decision, phase %s)",
      math.floor(sleeping), tostring(phase))
  end
  if phase == "early" then return true, "phase early : la regle d'avant decide" end
  return true, "aucune foreuse electrique au coffre : la regle d'avant decide"
end

return Dt
