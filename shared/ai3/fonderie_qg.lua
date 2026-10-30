--[[
  FONDERIE-QG (lot PD-FONDERIEQG, demande D77 de l'inventaire de la vague 9). PUR : aucune API Factorio, aucun nom d'objet
  (règle anti-échelle d'IA-G, tests/iag_test.lua §8) : les plaques et leurs entrées arrivent en DONNÉES (shared/team/config.lua,
  T.smelter_inputs, par la situation du cerveau), la couverture par les modules finis arrive du runtime (st.covered, lot IA3-e).

  Le DC (28/10, 14 h 45) : « une giga surface de fours, ils ont pas le temps de les nourrir […] il faudrait splitter » ;
  (29/10, 14 h) « ils remplissent les fours dans la base […] C'est possible en début de partie de faire comme ça, c'est même
  d'ailleurs plutôt recommandé […] mais très vite il faut automatiser ça. Il faut automatiser les fours ».

  Ce que faisait le code : la fonderie du QG (fours JOINTIFS garnis à la main, T.hq_rows.smelter) grandit par vagues
  (shared/ai3/bras.lua, Br.smelters) jusqu'à la moitié de l'effectif, et jusqu'à Br.SMELT_HARD fours quand du minerai attend
  au coffre, même quand une ligne à tapis du plan directeur (module « fonderie » fini, débit mesuré) fond déjà cette plaque :
  les PNJ restent occupés à nourrir des fours à la main.

  Règle :
    1. une plaque COUVERTE par un module fini (st.covered[plaque], débit mesuré ≥ la moitié du débit visé) ne fait plus
       grandir la fonderie du QG : son manque et son minerai au coffre sont le travail de la ligne (elle grandit avec ses
       foreuses, lot FONDERIE-DYNAMIQUE) ;
    2. dès qu'UNE plaque est fondue par une ligne à tapis, la fonderie nourrie à la main est BORNÉE à `keep` fours, plus
       Br.SMELT_STEP par plaque NON couverte qui manque durablement (elle garde de quoi rattraper un manque que la ligne ne
       couvre pas encore) ; jamais au-delà de la borne d'avant ;
    3. rien n'est démonté : un four déjà posé au-delà de la borne reste et sert (aucune perte) ; seule la croissance
       s'arrête. Une ligne qui tombe (courant coupé : débit mesuré nul) rend la plaque NON couverte : la borne se relâche
       d'elle-même (repli sur la main).

  FQ.automated(inputs, covered)            -> plaques de la fonderie fondues par une ligne à tapis (ordre des entrées).
  FQ.open_short(inputs, covered, st, n)    -> plaques NON couvertes qui manquent durablement (st.short, st.short_n ≥ n).
  FQ.limit(max, keep, n_auto, n_open, step)-> borne de la fonderie du QG, raison (nil : pas de borne nouvelle).

  Déterminisme : listes données triées par l'appelant, entiers, aucun pairs, aucun hasard, aucun temps mesuré.
]]
local FQ = {}

-- Fours gardés à la fonderie du QG quand l'automatisation fond déjà une plaque : la fonderie de base d'une faction (main
-- 0.6.1 : 4 fours ; B.SMELTERS_WANT) ; l'acier et les briques y restent faits à la main.
FQ.KEEP = 4

--- Plaques de `inputs` ({ { plaque, entrée, quantité }, ... }, triée) que couvre un module fini (`covered[plaque]` vrai).
function FQ.automated(inputs, covered)
  local out = {}
  if type(covered) ~= "table" then return out end
  for _, it in ipairs(inputs or {}) do
    if covered[it[1]] then out[#out + 1] = it[1] end
  end
  return out
end

--- Plaques NON couvertes dont le manque dure (st.short[plaque] > 0 depuis au moins `grow_thinks` pensées).
function FQ.open_short(inputs, covered, st, grow_thinks)
  local n = 0
  covered = type(covered) == "table" and covered or {}
  for _, it in ipairs(inputs or {}) do
    local plate = it[1]
    if not covered[plate] and ((st and st.short or {})[plate] or 0) > 0
      and ((st and st.short_n or {})[plate] or 0) >= (grow_thinks or 0) then
      n = n + 1
    end
  end
  return n
end

--- Borne de la fonderie nourrie à la main. `max` : la borne d'avant (effectif, minerai au coffre) ; `keep` : fours gardés
--- (FQ.KEEP par défaut) ; `n_auto` : plaques fondues par une ligne ; `n_open` : plaques non couvertes en manque durable ;
--- `step` : fours de plus par plaque ouverte. Rend la borne et sa raison ("automatisee"), ou `max`, nil sans automatisation.
function FQ.limit(max, keep, n_auto, n_open, step)
  max = max or 0
  if (n_auto or 0) <= 0 then return max, nil end
  local lim = (keep or FQ.KEEP) + (step or 0) * math.max(0, n_open or 0)
  if lim >= max then return max, nil end
  return lim, "automatisee"
end

return FQ
